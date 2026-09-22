/// One-time bridge (task #30d Phase B — aim unification, B5): fold the legacy aim
/// stores — the base [ReadinessTarget] (`onyx-target.json`) + the interview list
/// (`onyx-goals.json`, the old `PrepGoal` file) — into the whole-vault **default**
/// [StudyGoal]. The base target supplies the goal's slots + deadline; each legacy
/// entry becomes an [Aim]. Read-only parse; the caller ([StudyGoals])
/// write-through-persists the folded default so the legacy files fall out of use.
library;

import 'dart:convert';

import '../dev.dart';
import '../util.dart';
import '../readiness/target.dart';
import '../template/deck_template.dart';
import '../vault/vault_source.dart';
import 'study_goal.dart';

/// The whole-vault default goal, enriched from the legacy aim data. Slots/deadline
/// from [baseTarget] (null → the template fallbacks stand); the interviews from
/// [interviews]. With no legacy data this equals `defaultGoalFor(template)`.
StudyGoal migratedDefaultGoal(
  DeckTemplate template, {
  ReadinessTarget? baseTarget,
  List<Aim> interviews = const [],
}) =>
    StudyGoal(
      id: defaultGoalId,
      name: template.id,
      templateId: template.id,
      levelId: baseTarget?.levelId,
      contextId: baseTarget?.contextId,
      trackId: baseTarget?.trackId,
      deadline: baseTarget?.interviewDate,
      interviews: interviews,
    );

/// The dev-gated legacy interview file (mirrors the deleted `GoalsService`'s
/// isolation — desktop testing can't pollute the real synced interviews).
String get _legacyGoalsFile =>
    isDevDataMode ? 'onyx-goals.dev.json' : 'onyx-goals.json';

/// Read + parse the legacy `onyx-goals.json` interviews from the vault. Empty on
/// an absent/malformed file. Used once by the [StudyGoals] migration branch.
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
