/// A **study goal** — the primitive of the query-lens model (task #30d, see
/// docs/multi-subject-plan.md).
///
/// A goal is a named, configured, scheduled *view* of a set of related cards: a
/// [membership] query selects the cards, a [templateId] names the target
/// vocabulary (a `SubjectConfig`), a target selection + [deadline] set the
/// objective, and a [budgetWeight] + [state] control its slice of the shared daily
/// study time. Readiness is computed per goal over its members (G2). Goals are
/// app-managed state (persisted in `_meta/` by [id]), not vault content.
library;

import '../../shared/models/card.dart';
import '../readiness/target.dart';
import '../subject/subject_config.dart';
import 'membership_query.dart';

export 'membership_query.dart';

/// Where a goal sits in its lifecycle. Only [active] goals draw from the daily
/// budget; [paused] keeps state but drops out of the plan; [graduated] is
/// finished/archived (term churn — e.g. a course completed).
enum GoalState { active, paused, graduated }

/// A configured, query-defined study objective. Immutable; edits produce a copy.
class StudyGoal {
  const StudyGoal({
    required this.id,
    required this.name,
    required this.templateId,
    this.membership = const AllCards(),
    this.levelId,
    this.contextId,
    this.trackId,
    this.deadline,
    this.budgetWeight = 1.0,
    this.state = GoalState.active,
  });

  /// Stable id — the key under which this goal's state persists (`_meta/`).
  final String id;

  /// Human label for the lane/hub.
  final String name;

  /// The template (`SubjectConfig.id`) providing this goal's target dimensions and
  /// flow relevance.
  final String templateId;

  /// The card selector — what makes this goal a lens over the vault.
  final MembershipQuery membership;

  /// Target selection within the template. Null slots fall back to the template's
  /// declared fallbacks (so a goal can be created before the user picks a target).
  final String? levelId;
  final String? contextId;
  final String? trackId;

  /// When the goal is due (interview, exam, debate), or null for an open-ended goal.
  final DateTime? deadline;

  /// Relative share of the daily budget among active goals (renormalized across
  /// the active set; see G4).
  final double budgetWeight;

  final GoalState state;

  bool get isActive => state == GoalState.active;

  /// The member cards of this goal, drawn from [cards].
  Iterable<Card> select(Iterable<Card> cards) =>
      cards.where(membership.matches);

  /// This goal's [ReadinessTarget] — its own level/context/track selection, with
  /// null slots resolved to [template]'s fallbacks, and the [deadline] as the
  /// target's interview date (task #30d, G3a).
  ReadinessTarget toTarget(SubjectConfig template) => ReadinessTarget(
        levelId: levelId ?? template.target.fallbackLevelId,
        contextId: contextId ?? template.target.fallbackContextId,
        trackId: trackId ?? template.target.fallbackTrackId,
        interviewDate: deadline,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'templateId': templateId,
        'membership': membership.toJson(),
        if (levelId != null) 'levelId': levelId,
        if (contextId != null) 'contextId': contextId,
        if (trackId != null) 'trackId': trackId,
        if (deadline != null) 'deadline': deadline!.toIso8601String(),
        'budgetWeight': budgetWeight,
        'state': state.name,
      };

  static StudyGoal fromJson(Map<String, dynamic> m) => StudyGoal(
        id: m['id'] as String,
        name: (m['name'] ?? m['id']) as String,
        templateId: (m['templateId'] ?? '') as String,
        membership: m['membership'] is Map
            ? MembershipQuery.fromJson(
                (m['membership'] as Map).cast<String, dynamic>())
            : const AllCards(),
        levelId: m['levelId'] as String?,
        contextId: m['contextId'] as String?,
        trackId: m['trackId'] as String?,
        deadline: m['deadline'] is String
            ? DateTime.tryParse(m['deadline'] as String)
            : null,
        budgetWeight: (m['budgetWeight'] as num?)?.toDouble() ?? 1.0,
        state: GoalState.values.firstWhere(
          (s) => s.name == m['state'],
          orElse: () => GoalState.active,
        ),
      );

  StudyGoal copyWith({
    String? name,
    String? templateId,
    MembershipQuery? membership,
    String? levelId,
    String? contextId,
    String? trackId,
    DateTime? deadline,
    double? budgetWeight,
    GoalState? state,
  }) =>
      StudyGoal(
        id: id,
        name: name ?? this.name,
        templateId: templateId ?? this.templateId,
        membership: membership ?? this.membership,
        levelId: levelId ?? this.levelId,
        contextId: contextId ?? this.contextId,
        trackId: trackId ?? this.trackId,
        deadline: deadline ?? this.deadline,
        budgetWeight: budgetWeight ?? this.budgetWeight,
        state: state ?? this.state,
      );
}

/// The id of the implicit whole-vault goal that a single-subject vault runs as —
/// the degradation case that keeps behavior identical to pre-#30d.
const defaultGoalId = 'default';

/// The implicit default goal: the whole vault, targeted by [template]. Used until
/// the user defines explicit goals (G3), and always for a single-template vault.
StudyGoal defaultGoalFor(SubjectConfig template) => StudyGoal(
      id: defaultGoalId,
      name: template.id,
      templateId: template.id,
      membership: const AllCards(),
    );
