/// Transitional bridge (task #30d Phase B — aim unification, B2): fold the legacy
/// aim stores — the base [ReadinessTarget] (`onyx-target.json`) + the interview
/// [PrepGoal]s (`onyx-goals.json`) — into the whole-vault **default** [StudyGoal].
/// The base target supplies the goal's slots + deadline; each prep goal becomes an
/// [InterviewAim]. Pure + read-only (the old files stay authoritative until B5);
/// nothing loses its interview rounds/outcomes in the cut-over.
library;

import '../readiness/prep_goal.dart';
import '../readiness/target.dart';
import '../subject/subject_config.dart';
import 'study_goal.dart';

/// The whole-vault default goal, enriched from the legacy aim data. Slots/deadline
/// from [baseTarget] (null → the template fallbacks stand); the interviews from
/// [prepGoals]. With no legacy data this equals `defaultGoalFor(template)`.
StudyGoal migratedDefaultGoal(
  SubjectConfig template, {
  ReadinessTarget? baseTarget,
  List<PrepGoal> prepGoals = const [],
}) =>
    StudyGoal(
      id: defaultGoalId,
      name: template.id,
      templateId: template.id,
      levelId: baseTarget?.levelId,
      contextId: baseTarget?.contextId,
      trackId: baseTarget?.trackId,
      deadline: baseTarget?.interviewDate,
      interviews: [for (final g in prepGoals) aimFromPrepGoal(g)],
    );

/// A legacy interview [PrepGoal] → an [InterviewAim]. The goal's level/context/
/// track come from the base target (all interviews share them), so only the
/// interview-specific facets carry over. `effectiveRounds` materializes a
/// single-date goal's synthetic round 1 so its date isn't lost.
InterviewAim aimFromPrepGoal(PrepGoal g) => InterviewAim(
      companyName: g.companyName,
      rounds: g.effectiveRounds,
      active: g.active,
      status: g.status,
      outcome: g.outcome,
      outcomeNotes: g.outcomeNotes,
      domainWeights: g.domainWeights,
      conceptWeights: g.conceptWeights,
      planNotes: g.notes,
    );
