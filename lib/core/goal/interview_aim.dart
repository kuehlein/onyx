/// The interview-lifecycle facet of a [StudyGoal] (task #30d Phase B — aim
/// unification). A goal's *target* (level/context/track/deadline) and membership
/// live on the goal itself; this holds only what is **interview-specific**: the
/// company, the ordered rounds, the status/outcome, and AI-plan weight boosts.
/// A null `interview` on a StudyGoal → a plain (non-interview) study goal.
///
/// These types are interview-generic (a screen/onsite loop with outcomes), NOT
/// tied to the SWE target enums — so `StudyGoal` stays template-agnostic. The
/// legacy `PrepGoal` re-exports them for the not-yet-migrated interview UI.
library;

import '../util.dart';

/// The outcome of an interview (or a single round of one).
enum GoalOutcome { pending, passed, failed }

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
    this.outcome = GoalOutcome.pending,
    this.notes,
  });

  final String id;

  /// 1-based position in the loop.
  final int number;
  final InterviewRoundType type;

  /// When this round is scheduled, or null if not yet set.
  final DateTime? date;
  final GoalOutcome outcome;
  final String? notes;

  /// e.g. "Round 2 · System design".
  String get label => 'Round $number · ${type.label}';

  InterviewRound copyWith({
    int? number,
    InterviewRoundType? type,
    Object? date = _unset,
    GoalOutcome? outcome,
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
          enumByName(GoalOutcome.values, m['outcome']) ?? GoalOutcome.pending,
      notes: m['notes'] is String ? m['notes'] as String : null,
    );
  }
}

/// One interview attached to a [StudyGoal] via `StudyGoal.interviews` (a goal can
/// hold several, which the targeting layer blends).
class InterviewAim {
  const InterviewAim({
    this.companyName = '',
    this.rounds = const [],
    this.active = true,
    this.status = InterviewStatus.active,
    this.outcome = GoalOutcome.pending,
    this.outcomeNotes,
    this.domainWeights = const {},
    this.conceptWeights = const {},
    this.planNotes,
  });

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

  final GoalOutcome outcome;
  final String? outcomeNotes;

  /// Explicit per-domain / per-concept boosts from an AI plan (on top of the
  /// template's tier/level heuristics).
  final Map<String, double> domainWeights;
  final Map<String, double> conceptWeights;

  /// A short AI-plan summary attached to the interview.
  final String? planNotes;

  /// Rounds as the source of truth, migrating the goal's single [deadline] into a
  /// synthetic round 1 when no rounds are stored. [goalId] seeds the round id.
  List<InterviewRound> effectiveRounds(String goalId, DateTime? deadline) =>
      rounds.isNotEmpty
          ? rounds
          : (deadline != null
              ? [InterviewRound(id: '$goalId-r1', number: 1, date: deadline)]
              : const []);

  /// The one upcoming, not-yet-resolved round — what the learner is prepping for.
  InterviewRound? currentRound(String goalId, DateTime? deadline) {
    for (final r in effectiveRounds(goalId, deadline)) {
      if (r.outcome == GoalOutcome.pending) return r;
    }
    return null;
  }

  /// Resolved rounds, oldest first — the history behind [currentRound].
  List<InterviewRound> pastRounds(String goalId, DateTime? deadline) => [
        for (final r in effectiveRounds(goalId, deadline))
          if (r.outcome != GoalOutcome.pending) r,
      ];

  /// All scheduled round dates (date-only), for calendar flags.
  List<DateTime> roundDates(String goalId, DateTime? deadline) => [
        for (final r in effectiveRounds(goalId, deadline))
          if (r.date != null)
            DateTime(r.date!.year, r.date!.month, r.date!.day),
      ];

  /// The soonest round on/after [from] (else the earliest scheduled), or null.
  DateTime? nextRoundDate(String goalId, DateTime? deadline, [DateTime? from]) {
    final dates = roundDates(goalId, deadline)..sort();
    if (dates.isEmpty) return null;
    if (from == null) return dates.first;
    return dates.firstWhere((d) => !d.isBefore(from), orElse: () => dates.last);
  }

  /// Heal stale data: a round dated in the FUTURE can't have a logged result, so
  /// reset any such round to pending. Returns the same instance when clean.
  InterviewAim normalized(DateTime today) {
    if (rounds.isEmpty) return this;
    final t = DateTime(today.year, today.month, today.day);
    var changed = false;
    final fixed = <InterviewRound>[];
    for (final r in rounds) {
      final d = r.date;
      if (d != null &&
          r.outcome != GoalOutcome.pending &&
          DateTime(d.year, d.month, d.day).isAfter(t)) {
        fixed.add(r.copyWith(outcome: GoalOutcome.pending));
        changed = true;
      } else {
        fixed.add(r);
      }
    }
    return changed ? copyWith(rounds: fixed) : this;
  }

  InterviewAim copyWith({
    String? companyName,
    List<InterviewRound>? rounds,
    bool? active,
    InterviewStatus? status,
    GoalOutcome? outcome,
    Object? outcomeNotes = _unset,
    Map<String, double>? domainWeights,
    Map<String, double>? conceptWeights,
    Object? planNotes = _unset,
  }) =>
      InterviewAim(
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
      );

  Map<String, dynamic> toJson() => {
        if (companyName.isNotEmpty) 'companyName': companyName,
        if (rounds.isNotEmpty) 'rounds': [for (final r in rounds) r.toJson()],
        'active': active,
        'status': status.name,
        'outcome': outcome.name,
        if (outcomeNotes != null) 'outcomeNotes': outcomeNotes,
        if (domainWeights.isNotEmpty) 'domainWeights': domainWeights,
        if (conceptWeights.isNotEmpty) 'conceptWeights': conceptWeights,
        if (planNotes != null) 'planNotes': planNotes,
      };

  static InterviewAim fromJson(Map<String, dynamic> m) => InterviewAim(
        companyName:
            m['companyName'] is String ? m['companyName'] as String : '',
        rounds: _parseRounds(m['rounds']),
        active: m['active'] is bool ? m['active'] as bool : true,
        status: enumByName(InterviewStatus.values, m['status']) ??
            InterviewStatus.active,
        outcome:
            enumByName(GoalOutcome.values, m['outcome']) ?? GoalOutcome.pending,
        outcomeNotes:
            m['outcomeNotes'] is String ? m['outcomeNotes'] as String : null,
        domainWeights: _weightMap(m['domainWeights']),
        conceptWeights: _weightMap(m['conceptWeights']),
        planNotes: m['planNotes'] is String ? m['planNotes'] as String : null,
      );
}

const _unset = Object();

String _fmtDate(DateTime d) => '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

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
