/// A **study goal** — the primitive of the query-lens model (task #30d, see
/// docs/multi-subject-plan.md).
///
/// A goal is a named, configured, scheduled *view* of a set of related cards: a
/// [membership] query selects the cards, a [templateId] names the target
/// vocabulary (a `DeckTemplate`), the [aims] carry the objectives (each with its
/// own knobs + date), and a [budgetWeight] + [state] control its slice of the
/// shared daily study time. Readiness is computed per goal over its members (G2).
/// Goals are app-managed state (persisted in `_meta/` by [id]), not vault content.
library;

import '../../shared/models/card.dart';
import '../template/deck_template.dart';
import 'aim.dart';
import 'membership_query.dart';

export 'aim.dart';
export 'membership_query.dart';

/// Where a goal sits in its lifecycle. Only [active] goals draw from the daily
/// budget; [paused] keeps state but drops out of the plan; [graduated] is
/// finished/archived (term churn — e.g. a course completed).
enum DeckState { active, paused, graduated }

/// A configured, query-defined study objective. Immutable; edits produce a copy.
class Deck {
  const Deck({
    required this.id,
    required this.name,
    required this.templateId,
    this.membership = const AllCards(),
    this.budgetWeight = 1.0,
    this.state = DeckState.active,
    this.aims = const [],
  });

  /// Stable id — the key under which this goal's state persists (`_meta/`).
  final String id;

  /// Human label for the lane/hub.
  final String name;

  /// The template (`DeckTemplate.id`) providing this goal's target dimensions and
  /// flow relevance.
  final String templateId;

  /// The card selector — what makes this goal a lens over the vault.
  final MembershipQuery membership;

  /// Relative share of the daily budget among active goals (renormalized across
  /// the active set; see G4).
  final double budgetWeight;

  final DeckState state;

  /// The aims this deck points at — a deck can hold several at once (e.g. Google +
  /// Amazon interviews, or a comp-test + a jury), which the targeting layer blends.
  /// Each aim owns its OWN readiness knobs (difficulty [Aim.levelId] · durability
  /// [Aim.contextId] · emphasis [Aim.trackId]) + date via rounds (S1); the **deck
  /// is a pure lens** with no target slots of its own (n006). Empty → a plain
  /// 0-aim study deck (coverage-only vs the template fallbacks). Persisted under
  /// the legacy `interviews` JSON key for vault back-compat.
  final List<Aim> aims;

  bool get isActive => state == DeckState.active;

  /// The member cards of this goal, drawn from [cards].
  Iterable<Card> select(Iterable<Card> cards) =>
      cards.where(membership.matches);

  /// The soonest upcoming round date across this deck's **live** (active, not-ended)
  /// aims, or null — the deck's effective "deadline" now that dates live on aims
  /// (S5). Used by Home's target-card countdown + the lanes-hub lane subtitle.
  DateTime? soonestAimDate(DateTime today) {
    DateTime? soonest;
    for (final a in aims) {
      if (!a.active || a.status.isEnded) continue;
      final d = a.nextRoundDate(today);
      if (d != null && (soonest == null || d.isBefore(soonest))) soonest = d;
    }
    return soonest;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'templateId': templateId,
        'membership': membership.toJson(),
        'budgetWeight': budgetWeight,
        'state': state.name,
        if (aims.isNotEmpty) 'interviews': [for (final i in aims) i.toJson()],
      };

  static Deck fromJson(Map<String, dynamic> m) {
    // A deck with no usable id is unrecoverable — throw so [DeckStore.load] skips
    // just this entry (not the whole file). Every OTHER read below is type-tolerant
    // (a hand-edited / sync-corrupted `_meta` file must degrade a bad field, not
    // throw and take the deck — or the list — down with it).
    final id = m['id'];
    if (id is! String || id.isEmpty) {
      throw const FormatException('Deck JSON missing a string "id"');
    }
    final rawAims = m['interviews'] is List
        ? [
            for (final e in m['interviews'] as List)
              if (e is Map) Aim.fromJson(e.cast<String, dynamic>()),
          ]
        : const <Aim>[];
    // Fold any legacy deck target slots into the aims at parse time (S5 — the deck
    // is a pure lens now; the slots are read-and-folded, never stored as fields).
    // [_str] treats a wrong type OR an empty string as null. Old files keep the
    // redundant `levelId`/… keys until their next save; ignored on read. Idempotent
    // for already-folded data (see [foldSlotsIntoAims]).
    final aims = foldSlotsIntoAims(
      rawAims,
      levelId: _str(m['levelId']),
      contextId: _str(m['contextId']),
      trackId: _str(m['trackId']),
      deadline: m['deadline'] is String
          ? DateTime.tryParse(m['deadline'] as String)
          : null,
      deckId: id,
    );
    return Deck(
      id: id,
      name: m['name'] is String ? m['name'] as String : id,
      templateId: m['templateId'] is String ? m['templateId'] as String : '',
      membership: m['membership'] is Map
          ? MembershipQuery.fromJson(
              (m['membership'] as Map).cast<String, dynamic>())
          : const AllCards(),
      budgetWeight: m['budgetWeight'] is num
          ? (m['budgetWeight'] as num).toDouble()
          : 1.0,
      state: DeckState.values.firstWhere(
        (s) => s.name == m['state'],
        orElse: () => DeckState.active,
      ),
      aims: aims,
    );
  }

  Deck copyWith({
    String? name,
    String? templateId,
    MembershipQuery? membership,
    double? budgetWeight,
    DeckState? state,
    List<Aim>? aims,
  }) =>
      Deck(
        id: id,
        name: name ?? this.name,
        templateId: templateId ?? this.templateId,
        membership: membership ?? this.membership,
        budgetWeight: budgetWeight ?? this.budgetWeight,
        state: state ?? this.state,
        aims: aims ?? this.aims,
      );
}

/// The id of the implicit whole-vault goal that a single-subject vault runs as —
/// the degradation case that keeps behavior identical to pre-#30d.
const defaultDeckId = 'default';

/// The implicit default goal: the whole vault, targeted by [template]. Used until
/// the user defines explicit goals (G3), and always for a single-template vault.
Deck defaultDeckFor(DeckTemplate template) => Deck(
      id: defaultDeckId,
      name: template.id,
      templateId: template.id,
      membership: const AllCards(),
    );

/// A non-empty string, or null — coerces both a wrong type and an empty string to
/// null, so a hand-edited/corrupted `"levelId": ""` (or a number) doesn't leak a
/// junk slot id into readiness targeting.
String? _str(Object? v) => v is String && v.isNotEmpty ? v : null;

/// Fold a deck's legacy target **slots** (level/context/track/deadline) into its
/// [aims] — the S5 migration, applied at **parse time** ([Deck.fromJson]) and in
/// the legacy first-run migration ([migratedDefaultDeck]) so the deck itself never
/// carries the slots. Each aim's null knob is filled from the deck slot it used to
/// inherit; a round-less aim inherits [deadline] as an explicit round 1; a set of
/// slots with NO aims becomes one coverage aim (`id: 'target'`). **Idempotent:**
/// aims already carrying the slots return unchanged, and with no slots + no
/// deadline the input list is returned as-is (so re-parsing a folded deck is a
/// no-op). [deckId] seeds any synthetic round id.
List<Aim> foldSlotsIntoAims(
  List<Aim> aims, {
  String? levelId,
  String? contextId,
  String? trackId,
  DateTime? deadline,
  required String deckId,
}) {
  final hasSlots = levelId != null || contextId != null || trackId != null;
  if (!hasSlots && deadline == null) return aims; // nothing to preserve

  Aim carry(Aim a) {
    final lv = a.levelId ?? levelId;
    final cx = a.contextId ?? contextId;
    final tk = a.trackId ?? trackId;
    final needRound = a.rounds.isEmpty && deadline != null;
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
                id: '${a.id.isNotEmpty ? a.id : deckId}-r1',
                number: 1,
                date: deadline,
              )
            ]
          : a.rounds,
    );
  }

  if (aims.isEmpty) return [carry(const Aim(id: 'target'))];
  return [for (final a in aims) carry(a)];
}
