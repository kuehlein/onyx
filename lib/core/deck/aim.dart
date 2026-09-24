/// The interview-lifecycle facet of a [Deck] (task #30d Phase B — aim
/// unification). A goal's *target* (level/context/track/deadline) and membership
/// live on the goal itself; this holds only what is **interview-specific**: the
/// company, the ordered rounds, the status/outcome, and AI-plan weight boosts.
/// A null `interview` on a Deck → a plain (non-interview) study goal.
///
/// These types are interview-generic (a screen/onsite loop with outcomes), NOT
/// tied to the SWE target enums — so `Deck` stays template-agnostic.
library;

import '../util.dart';

/// The outcome of an interview (or a single round of one).
enum AimOutcome { pending, passed, failed }

/// Where an interview sits in its lifecycle. [active] loops still have a current
/// upcoming round; the rest are ended and live in the "past" section — kept for
/// the record rather than deleted (archive-by-default).
enum InterviewStatus { active, offer, rejected, withdrawn, archived }

extension InterviewStatusLabel on InterviewStatus {
  String get label => switch (this) {
        InterviewStatus.active => 'Active',
        InterviewStatus.offer => 'Offer',
        InterviewStatus.rejected => "Didn't pass",
        InterviewStatus.withdrawn => 'Withdrew',
        InterviewStatus.archived => 'Archived',
      };

  /// Whether the loop is over (anything but [active]).
  bool get isEnded => this != InterviewStatus.active;
}

/// The kind of interview round.
enum InterviewRoundType {
  screen,
  coding,
  systemDesign,
  behavioral,
  onsite,
  other
}

extension InterviewRoundTypeLabel on InterviewRoundType {
  String get label => switch (this) {
        InterviewRoundType.screen => 'Screen',
        InterviewRoundType.coding => 'Coding',
        InterviewRoundType.systemDesign => 'System design',
        InterviewRoundType.behavioral => 'Behavioral',
        InterviewRoundType.onsite => 'Onsite',
        InterviewRoundType.other => 'Interview',
      };
}

/// One round of an interview loop (a phone screen, a system-design round, …).
class InterviewRound {
  const InterviewRound({
    required this.id,
    required this.number,
    this.type = InterviewRoundType.other,
    this.date,
    this.outcome = AimOutcome.pending,
    this.notes,
  });

  final String id;

  /// 1-based position in the loop.
  final int number;
  final InterviewRoundType type;

  /// When this round is scheduled, or null if not yet set.
  final DateTime? date;
  final AimOutcome outcome;
  final String? notes;

  /// e.g. "Round 2 · System design".
  String get label => 'Round $number · ${type.label}';

  InterviewRound copyWith({
    int? number,
    InterviewRoundType? type,
    Object? date = _unset,
    AimOutcome? outcome,
    Object? notes = _unset,
  }) =>
      InterviewRound(
        id: id,
        number: number ?? this.number,
        type: type ?? this.type,
        date: date == _unset ? this.date : date as DateTime?,
        outcome: outcome ?? this.outcome,
        notes: notes == _unset ? this.notes : notes as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'number': number,
        'type': type.name,
        if (date != null) 'date': _fmtDate(date!),
        'outcome': outcome.name,
        if (notes != null) 'notes': notes,
      };

  static InterviewRound? fromJson(Map<String, dynamic> m) {
    final id = m['id'];
    if (id is! String || id.isEmpty) return null;
    return InterviewRound(
      id: id,
      number: m['number'] is int ? m['number'] as int : 1,
      type: enumByName(InterviewRoundType.values, m['type']) ??
          InterviewRoundType.other,
      date: _parseDate(m['date']),
      outcome:
          enumByName(AimOutcome.values, m['outcome']) ?? AimOutcome.pending,
      notes: m['notes'] is String ? m['notes'] as String : null,
    );
  }
}

/// One interview attached to a [Deck] via `Deck.aims` (a goal can
/// hold several, which the targeting layer blends).
class Aim {
  const Aim({
    this.id = '',
    this.companyName = '',
    this.rounds = const [],
    this.active = true,
    this.status = InterviewStatus.active,
    this.outcome = AimOutcome.pending,
    this.outcomeNotes,
    this.domainWeights = const {},
    this.conceptWeights = const {},
    this.planNotes,
    this.levelId,
    this.contextId,
    this.trackId,
  });

  /// Stable id, unique within the parent goal's [Deck.aims] — the key
  /// the UI upserts/removes/mutes by, and what the debrief flow looks up. Migrated
  /// from the legacy `PrepGoal.id`; empty only on a not-yet-persisted draft.
  final String id;

  /// Free-form company name (e.g. "Google") for display + AI context.
  final String companyName;

  /// Whether this interview currently shapes study (an on/off toggle, distinct
  /// from the lifecycle [status] — a user can mute an active interview).
  final bool active;

  /// The interview loop's rounds, in order. Source of truth for scheduling; the
  /// goal's `deadline` seeds a synthetic round 1 for a legacy single-date goal.
  final List<InterviewRound> rounds;

  /// The interview's lifecycle state.
  final InterviewStatus status;

  final AimOutcome outcome;
  final String? outcomeNotes;

  /// Explicit per-domain / per-concept boosts from an AI plan (on top of the
  /// template's tier/level heuristics).
  final Map<String, double> domainWeights;
  final Map<String, double> conceptWeights;

  /// A short AI-plan summary attached to the interview.
  final String? planNotes;

  /// This aim's own readiness knobs — slot ids on the deck's template: difficulty
  /// [levelId], durability [contextId], domain-emphasis [trackId]. Null → the
  /// template's fallback for that slot. Aims OWN these (the deck/aims model, n006 —
  /// the deck is a pure lens); the date knob is carried by [rounds]. Resolved via
  /// `ReadinessTarget.forAim`.
  final String? levelId;
  final String? contextId;
  final String? trackId;

  /// The one upcoming, not-yet-resolved round — what the learner is prepping for.
  /// [rounds] is the source of truth now (S5c — the deck-level deadline fallback is
  /// gone; the migration folded any deck deadline into an explicit round).
  InterviewRound? currentRound() {
    for (final r in rounds) {
      if (r.outcome == AimOutcome.pending) return r;
    }
    return null;
  }

  /// Resolved rounds, oldest first — the history behind [currentRound].
  List<InterviewRound> pastRounds() => [
        for (final r in rounds)
          if (r.outcome != AimOutcome.pending) r,
      ];

  /// All scheduled round dates (date-only), for calendar flags.
  List<DateTime> roundDates() => [
        for (final r in rounds)
          if (r.date != null)
            DateTime(r.date!.year, r.date!.month, r.date!.day),
      ];

  /// The soonest round on/after [from] (else the earliest scheduled), or null.
  DateTime? nextRoundDate([DateTime? from]) {
    final dates = roundDates()..sort();
    if (dates.isEmpty) return null;
    if (from == null) return dates.first;
    return dates.firstWhere((d) => !d.isBefore(from), orElse: () => dates.last);
  }

  /// Heal stale data: a round dated in the FUTURE can't have a logged result, so
  /// reset any such round to pending. Returns the same instance when clean.
  Aim normalized(DateTime today) {
    if (rounds.isEmpty) return this;
    final t = DateTime(today.year, today.month, today.day);
    var changed = false;
    final fixed = <InterviewRound>[];
    for (final r in rounds) {
      final d = r.date;
      if (d != null &&
          r.outcome != AimOutcome.pending &&
          DateTime(d.year, d.month, d.day).isAfter(t)) {
        fixed.add(r.copyWith(outcome: AimOutcome.pending));
        changed = true;
      } else {
        fixed.add(r);
      }
    }
    return changed ? copyWith(rounds: fixed) : this;
  }

  Aim copyWith({
    String? id,
    String? companyName,
    List<InterviewRound>? rounds,
    bool? active,
    InterviewStatus? status,
    AimOutcome? outcome,
    Object? outcomeNotes = _unset,
    Map<String, double>? domainWeights,
    Map<String, double>? conceptWeights,
    Object? planNotes = _unset,
    Object? levelId = _unset,
    Object? contextId = _unset,
    Object? trackId = _unset,
  }) =>
      Aim(
        id: id ?? this.id,
        companyName: companyName ?? this.companyName,
        rounds: rounds ?? this.rounds,
        active: active ?? this.active,
        status: status ?? this.status,
        outcome: outcome ?? this.outcome,
        outcomeNotes: outcomeNotes == _unset
            ? this.outcomeNotes
            : outcomeNotes as String?,
        domainWeights: domainWeights ?? this.domainWeights,
        conceptWeights: conceptWeights ?? this.conceptWeights,
        planNotes: planNotes == _unset ? this.planNotes : planNotes as String?,
        levelId: levelId == _unset ? this.levelId : levelId as String?,
        contextId: contextId == _unset ? this.contextId : contextId as String?,
        trackId: trackId == _unset ? this.trackId : trackId as String?,
      );

  Map<String, dynamic> toJson() => {
        if (id.isNotEmpty) 'id': id,
        if (companyName.isNotEmpty) 'companyName': companyName,
        if (rounds.isNotEmpty) 'rounds': [for (final r in rounds) r.toJson()],
        'active': active,
        'status': status.name,
        'outcome': outcome.name,
        if (outcomeNotes != null) 'outcomeNotes': outcomeNotes,
        if (domainWeights.isNotEmpty) 'domainWeights': domainWeights,
        if (conceptWeights.isNotEmpty) 'conceptWeights': conceptWeights,
        if (planNotes != null) 'planNotes': planNotes,
        if (levelId != null) 'levelId': levelId,
        if (contextId != null) 'contextId': contextId,
        if (trackId != null) 'trackId': trackId,
      };

  static Aim fromJson(Map<String, dynamic> m) => Aim(
        id: m['id'] is String ? m['id'] as String : '',
        companyName:
            m['companyName'] is String ? m['companyName'] as String : '',
        rounds: _parseRounds(m['rounds']),
        active: m['active'] is bool ? m['active'] as bool : true,
        status: enumByName(InterviewStatus.values, m['status']) ??
            InterviewStatus.active,
        outcome:
            enumByName(AimOutcome.values, m['outcome']) ?? AimOutcome.pending,
        outcomeNotes:
            m['outcomeNotes'] is String ? m['outcomeNotes'] as String : null,
        domainWeights: _weightMap(m['domainWeights']),
        conceptWeights: _weightMap(m['conceptWeights']),
        planNotes: m['planNotes'] is String ? m['planNotes'] as String : null,
        // Non-empty string or null — a wrong type / empty "" is a null slot (it'd
        // otherwise leak a junk id into readiness targeting).
        levelId: _str(m['levelId']),
        contextId: _str(m['contextId']),
        trackId: _str(m['trackId']),
      );
}

const _unset = Object();

String _fmtDate(DateTime d) => '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// A non-empty string, or null — coerces a wrong type or empty "" to null.
String? _str(Object? v) => v is String && v.isNotEmpty ? v : null;

DateTime? _parseDate(Object? v) {
  if (v is! String || v.isEmpty) return null;
  return DateTime.tryParse(v);
}

List<InterviewRound> _parseRounds(Object? v) {
  if (v is! List) return const [];
  return [
    for (final e in v)
      if (e is Map<String, dynamic>) InterviewRound.fromJson(e),
  ].whereType<InterviewRound>().toList();
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
