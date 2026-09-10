import 'dart:convert';
import '../util.dart';

import 'target.dart';

/// The outcome of an interview (or a single round of one).
enum GoalOutcome { pending, passed, failed }

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
/// An interview ([PrepGoal]) owns an ordered list of these.
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

/// A single interview-prep goal: a target (company/role/level/track/date) plus
/// optional AI-plan boosts and an outcome. The generalization of the single
/// [ReadinessTarget] — a learner can hold several (Google, Amazon, …), toggle
/// each on/off, and mark outcomes. The targeting layer combines the ACTIVE ones
/// into effective weights + date + per-card desired-retention (see the
/// fsrs-exam-targeting memory: FSRS state stays pure; targeting is a layer on
/// top).
class PrepGoal {
  const PrepGoal({
    required this.id,
    required this.level,
    required this.tier,
    required this.track,
    this.companyName = '',
    this.date,
    this.active = true,
    this.domainWeights = const {},
    this.conceptWeights = const {},
    this.outcome = GoalOutcome.pending,
    this.outcomeNotes,
    this.notes,
    this.rounds = const [],
  });

  final String id;

  /// Free-form company name (e.g. "Google") for display + AI context. May be
  /// empty (the baseline goal migrated from the old single target).
  final String companyName;

  /// Drives the existing [domainWeight] heuristics; a free-form company is
  /// mapped to a tier by the AI/user.
  final CompanyTier tier;
  final SeniorityLevel level;
  final Track track;

  /// The interview date, or null if unscheduled.
  final DateTime? date;

  /// Whether this goal currently shapes study (toggle on/off).
  final bool active;

  /// Explicit per-domain boosts from an AI plan (added on top of the tier/level
  /// heuristics). Empty for the baseline goal.
  final Map<String, double> domainWeights;

  /// Explicit per-concept boosts from an AI plan.
  final Map<String, double> conceptWeights;

  final GoalOutcome outcome;
  final String? outcomeNotes;

  /// A short AI-plan summary attached to the goal.
  final String? notes;

  /// The interview loop's rounds, in order. Source of truth for scheduling; the
  /// top-level [date] is kept as a denormalized "next round" for legacy readers.
  final List<InterviewRound> rounds;

  /// Rounds as the source of truth, migrating a legacy single [date] into a
  /// synthetic round 1 when no rounds are stored.
  List<InterviewRound> get effectiveRounds => rounds.isNotEmpty
      ? rounds
      : (date != null
          ? [InterviewRound(id: '$id-r1', number: 1, date: date)]
          : const []);

  /// All scheduled round dates (date-only), for calendar flags.
  List<DateTime> get roundDates => [
        for (final r in effectiveRounds)
          if (r.date != null)
            DateTime(r.date!.year, r.date!.month, r.date!.day),
      ];

  /// The soonest round on/after [from] (else the earliest scheduled), or null.
  DateTime? nextRoundDate([DateTime? from]) {
    final dates = roundDates..sort();
    if (dates.isEmpty) return null;
    if (from == null) return dates.first;
    return dates.firstWhere((d) => !d.isBefore(from), orElse: () => dates.last);
  }

  /// A human label, e.g. "Google · Senior · Backend" or (no company) the plain
  /// target label "Senior · FAANG · Backend".
  String get label => companyName.isEmpty
      ? '${level.label} · ${tier.label} · ${track.label}'
      : '$companyName · ${level.label} · ${track.label}';

  /// This goal as a [ReadinessTarget] — the adapter the existing readiness/pace/
  /// weighting code consumes (so Phase 0 changes nothing downstream).
  ReadinessTarget toTarget() => ReadinessTarget(
        level: level,
        company: tier,
        track: track,
        interviewDate: date,
      );

  /// Seed a baseline goal from the legacy single [ReadinessTarget].
  factory PrepGoal.fromTarget(ReadinessTarget t, {String id = 'primary'}) =>
      PrepGoal(
        id: id,
        level: t.level,
        tier: t.company,
        track: t.track,
        date: t.interviewDate,
      );

  PrepGoal copyWith({
    String? companyName,
    CompanyTier? tier,
    SeniorityLevel? level,
    Track? track,
    Object? date = _unset,
    bool? active,
    Map<String, double>? domainWeights,
    Map<String, double>? conceptWeights,
    GoalOutcome? outcome,
    Object? outcomeNotes = _unset,
    Object? notes = _unset,
    List<InterviewRound>? rounds,
  }) =>
      PrepGoal(
        id: id,
        companyName: companyName ?? this.companyName,
        tier: tier ?? this.tier,
        level: level ?? this.level,
        track: track ?? this.track,
        date: date == _unset ? this.date : date as DateTime?,
        active: active ?? this.active,
        domainWeights: domainWeights ?? this.domainWeights,
        conceptWeights: conceptWeights ?? this.conceptWeights,
        outcome: outcome ?? this.outcome,
        outcomeNotes: outcomeNotes == _unset
            ? this.outcomeNotes
            : outcomeNotes as String?,
        notes: notes == _unset ? this.notes : notes as String?,
        rounds: rounds ?? this.rounds,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'companyName': companyName,
        'tier': tier.name,
        'level': level.name,
        'track': track.name,
        if (date != null) 'date': _fmtDate(date!),
        'active': active,
        if (domainWeights.isNotEmpty) 'domainWeights': domainWeights,
        if (conceptWeights.isNotEmpty) 'conceptWeights': conceptWeights,
        'outcome': outcome.name,
        if (outcomeNotes != null) 'outcomeNotes': outcomeNotes,
        if (notes != null) 'notes': notes,
        if (rounds.isNotEmpty) 'rounds': [for (final r in rounds) r.toJson()],
      };

  static PrepGoal? fromJson(Map<String, dynamic> m) {
    final id = m['id'];
    if (id is! String || id.isEmpty) return null;
    return PrepGoal(
      id: id,
      companyName: m['companyName'] is String ? m['companyName'] as String : '',
      tier: enumByName(CompanyTier.values, m['tier']) ?? CompanyTier.typical,
      level:
          enumByName(SeniorityLevel.values, m['level']) ?? SeniorityLevel.mid,
      track: enumByName(Track.values, m['track']) ?? Track.general,
      date: _parseDate(m['date']),
      active: m['active'] is bool ? m['active'] as bool : true,
      domainWeights: _weightMap(m['domainWeights']),
      conceptWeights: _weightMap(m['conceptWeights']),
      outcome:
          enumByName(GoalOutcome.values, m['outcome']) ?? GoalOutcome.pending,
      outcomeNotes:
          m['outcomeNotes'] is String ? m['outcomeNotes'] as String : null,
      notes: m['notes'] is String ? m['notes'] as String : null,
      rounds: _parseRounds(m['rounds']),
    );
  }

  /// Encode a list of goals to a JSON string (for persistence).
  static String encodeList(List<PrepGoal> goals) =>
      jsonEncode([for (final g in goals) g.toJson()]);

  /// Decode a list of goals; returns an empty list on any parse failure.
  static List<PrepGoal> decodeList(String? raw) {
    if (raw == null || raw.isEmpty) return const [];
    try {
      final data = jsonDecode(raw);
      if (data is! List) return const [];
      return [
        for (final e in data)
          if (e is Map<String, dynamic>) fromJson(e),
      ].whereType<PrepGoal>().toList();
    } catch (_) {
      return const [];
    }
  }
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
