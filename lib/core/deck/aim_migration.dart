/// One-time bridge (task #30d Phase B — aim unification, B5): fold the legacy aim
/// stores — the base [ReadinessTarget] (`onyx-target.json`) + the interview list
/// (`onyx-goals.json`, the old `PrepGoal` file) — into the whole-vault **default**
/// [Deck]. The base target supplies the goal's slots + deadline; each legacy
/// entry becomes an [Aim]. Read-only parse; the caller ([Decks])
/// write-through-persists the folded default so the legacy files fall out of use.
library;

import 'dart:convert';

import '../dev.dart';
import '../util.dart';
import '../readiness/target.dart';
import '../template/deck_template.dart';
import '../vault/vault_source.dart';
import 'deck.dart';

/// The whole-vault default deck, enriched from the legacy aim data. Slots/deadline
/// from [baseTarget] (null → the template fallbacks stand); the aims from [aims].
/// With no legacy data this equals `defaultDeckFor(template)`.
Deck migratedDefaultDeck(
  DeckTemplate template, {
  ReadinessTarget? baseTarget,
  List<Aim> aims = const [],
}) =>
    Deck(
      id: defaultDeckId,
      name: template.id,
      templateId: template.id,
      levelId: baseTarget?.levelId,
      contextId: baseTarget?.contextId,
      trackId: baseTarget?.trackId,
      deadline: baseTarget?.interviewDate,
      aims: aims,
    );

/// S5 writer-flip prep (task #101): make each aim carry its OWN knobs + dates
/// explicitly, so the deck's transitional `level/context/track/deadline` slots can
/// be deleted. **Byte-identical** — an aim's null slot is filled from the deck slot
/// it already inherited (`_aimTarget`), and a round-less aim that fell back to the
/// deck [Deck.deadline] gets it as an explicit round 1 (same id/date
/// `effectiveRounds` would have synthesized). A deck with an explicit target
/// (a non-null slot) but NO aims gets one **coverage aim** carrying the slots (dated
/// when there was a deadline), so its target survives slot deletion; a deck that
/// never set a target (no slots, no deadline) is returned unchanged and stays
/// aim-less (0-aim → coverage vs the template fallbacks). Returns the SAME instance
/// when nothing needs folding, so the caller can skip a needless persist.
Deck foldDeckSlotsIntoAims(Deck g) {
  final hasSlots =
      g.levelId != null || g.contextId != null || g.trackId != null;
  if (!hasSlots && g.deadline == null) return g; // nothing to preserve

  Aim carry(Aim a) {
    final lv = a.levelId ?? g.levelId;
    final cx = a.contextId ?? g.contextId;
    final tk = a.trackId ?? g.trackId;
    final needRound = a.rounds.isEmpty && g.deadline != null;
    if (lv == a.levelId && cx == a.contextId && tk == a.trackId && !needRound) {
      return a; // already carries everything — unchanged
    }
    return a.copyWith(
      levelId: lv,
      contextId: cx,
      trackId: tk,
      rounds: needRound
          ? [
              InterviewRound(
                id: '${a.id.isNotEmpty ? a.id : g.id}-r1',
                number: 1,
                date: g.deadline,
              )
            ]
          : a.rounds,
    );
  }

  if (g.aims.isEmpty) {
    // Preserve the explicit target as one coverage aim (dated if there was a
    // deadline). A target-less deck returned above, so we only reach here with
    // something to keep.
    return g.copyWith(aims: [carry(const Aim(id: 'target'))]);
  }
  final folded = [for (final a in g.aims) carry(a)];
  final changed = [
    for (var i = 0; i < folded.length; i++) identical(folded[i], g.aims[i])
  ].any((same) => !same);
  return changed ? g.copyWith(aims: folded) : g;
}

/// The dev-gated legacy interview file (mirrors the deleted `GoalsService`'s
/// isolation — desktop testing can't pollute the real synced interviews).
String get _legacyGoalsFile =>
    isDevDataMode ? 'onyx-goals.dev.json' : 'onyx-goals.json';

/// Read + parse the legacy `onyx-goals.json` interviews from the vault. Empty on
/// an absent/malformed file. Used once by the [Decks] migration branch.
Future<List<Aim>> legacyInterviews(VaultSource source) async =>
    legacyInterviewsFromRaw(await source.readMeta(_legacyGoalsFile));

/// Parse a legacy `onyx-goals.json` string (the old `PrepGoal.toJson` array) into
/// [Aim]s. Pure: on any parse error / non-List → `const []`; entries
/// without a usable id are dropped. The legacy target facets (tier/level/track)
/// are intentionally NOT carried — all interviews share the goal's slots now.
List<Aim> legacyInterviewsFromRaw(String? rawJson) {
  if (rawJson == null || rawJson.isEmpty) return const [];
  try {
    final data = jsonDecode(rawJson);
    if (data is! List) return const [];
    final out = <Aim>[];
    for (final e in data) {
      if (e is! Map) continue;
      final aim = _aimFromLegacy(e.cast<String, dynamic>());
      if (aim != null) out.add(aim);
    }
    return out;
  } catch (_) {
    return const [];
  }
}

/// One legacy interview entry → an [Aim] (null if it has no id). Rounds
/// come from the stored `rounds`; if none and a single `date` parses, a synthetic
/// round 1 preserves that date. The legacy `notes` field maps to `planNotes`.
Aim? _aimFromLegacy(Map<String, dynamic> m) {
  final id = m['id'];
  if (id is! String || id.isEmpty) return null;

  final rounds = <InterviewRound>[];
  final rawRounds = m['rounds'];
  if (rawRounds is List) {
    for (final r in rawRounds) {
      if (r is Map) {
        final round = InterviewRound.fromJson(r.cast<String, dynamic>());
        if (round != null) rounds.add(round);
      }
    }
  }
  final date = _parseDate(m['date']);
  final effectiveRounds = rounds.isNotEmpty
      ? rounds
      : (date != null
          ? [InterviewRound(id: '$id-r1', number: 1, date: date)]
          : const <InterviewRound>[]);

  final active = m['active'] is bool ? m['active'] as bool : true;
  return Aim(
    id: id,
    companyName: m['companyName'] is String ? m['companyName'] as String : '',
    rounds: effectiveRounds,
    active: active,
    status: enumByName(InterviewStatus.values, m['status']) ??
        (active ? InterviewStatus.active : InterviewStatus.archived),
    outcome: enumByName(AimOutcome.values, m['outcome']) ?? AimOutcome.pending,
    outcomeNotes:
        m['outcomeNotes'] is String ? m['outcomeNotes'] as String : null,
    domainWeights: _weightMap(m['domainWeights']),
    conceptWeights: _weightMap(m['conceptWeights']),
    planNotes: m['notes'] is String ? m['notes'] as String : null,
  );
}

DateTime? _parseDate(Object? v) {
  if (v is! String || v.isEmpty) return null;
  return DateTime.tryParse(v);
}

Map<String, double> _weightMap(Object? v) {
  if (v is! Map) return const {};
  final out = <String, double>{};
  for (final e in v.entries) {
    final val = e.value;
    if (val is num) out[e.key.toString()] = val.toDouble();
  }
  return out;
}
