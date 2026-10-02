import 'recognition.dart';
import 'srs_scheduler.dart';
import 'study_state.dart';

/// Per-kind scheduling models (ADR-0024 §3) — the single seam that maps a datum's
/// [StudyKind] to its scheduling MODEL. **Config-agnostic:** a scheduler reads only
/// the datum's kind, never the deck/config, so two flows over one datum can never
/// disagree on its model (`kind = f(mode)` is globally fixed).
///
/// The learning-science pass forbids one universal forgetting curve over declarative
/// recall and applied practice (ADR-0020 §3), so there are **two** models, registered
/// here. A new kind adds a scheduler + a [studySchedulerFor] arm — nothing else in
/// the app branches on kind to schedule.
sealed class StudyScheduler {
  StudyKind get kind;
}

/// `recall` → FSRS. A thin marker subtype of [SrsScheduler]: it drops in anywhere an
/// `SrsScheduler` is expected (so the retention/Learn-Easy policy the providers pass
/// to `review` is untouched) while declaring its kind for the registry.
class RecallScheduler extends SrsScheduler implements StudyScheduler {
  RecallScheduler({super.scheduler, super.enableFuzzing, super.learningSteps});

  @override
  StudyKind get kind => StudyKind.recall;
}

/// `practice` → the expanding-interval recognition clock. Wraps [scheduleRecognition].
class PracticeScheduler implements StudyScheduler {
  const PracticeScheduler();

  @override
  StudyKind get kind => StudyKind.practice;

  /// Schedule the next practice from [outcome], the [priorStreak], and [now].
  RecognitionResult schedule({
    required ExplainOutcome outcome,
    required DateTime now,
    int priorStreak = 0,
  }) =>
      scheduleRecognition(outcome: outcome, now: now, priorStreak: priorStreak);
}

/// The registry: a datum's [kind] → its scheduling model. The one place scheduling
/// dispatches on kind; config-agnostic. (Static callers that know their kind use the
/// concrete scheduler directly; this is the seam for kind-dynamic dispatch.)
StudyScheduler studySchedulerFor(StudyKind kind) => switch (kind) {
      StudyKind.recall => RecallScheduler(),
      StudyKind.practice => const PracticeScheduler(),
    };
