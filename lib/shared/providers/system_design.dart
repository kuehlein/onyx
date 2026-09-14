import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/ai/claude_service.dart';
import '../../core/ai/system_design_interviewer.dart';
import '../../core/interview/assessment.dart';
import '../../core/interview/system_design_grader.dart';
import '../../core/practice/mock_session.dart';
import '../../core/readiness/target.dart';
import '../../core/srs/recognition.dart';
import '../models/card.dart';
import 'ai.dart';
import 'clock.dart';
import 'interview.dart';
import 'readiness.dart';
import 'srs.dart';
import 'vault.dart';

part 'system_design.g.dart';

/// The recognition-clock section key for a problem's re-mock schedule.
const _recognitionSlug = 'mock';

/// Maps a mock's overall score to a spaced-recurrence outcome for the recognition
/// clock — the same lightweight expanding-interval scheduler the algo track uses.
/// It carries NO readiness weight; it only decides when a problem is due to
/// re-mock. Readiness comes from applied-transfer, separately.
ExplainOutcome scoreToRecurrence(int score) => score >= 70
    ? ExplainOutcome.solid
    : score >= 45
        ? ExplainOutcome.shaky
        : ExplainOutcome.lost;

/// System-design practice problems ordered by **spaced recurrence**: overdue
/// re-mocks first (most overdue first), then never-mocked, then upcoming (soonest
/// due first). A real "what to practice next" — consistent with the rest of the
/// app (browse ALL problems in Browse; this is the scheduled queue).
@riverpod
Future<List<Card>> systemDesignProblems(Ref ref) async {
  final index = await ref.watch(vaultIndexProvider.future);
  final states = await ref.watch(recognitionRepositoryProvider).loadStates();
  final now = (await ref.watch(clockProvider.future)).now();
  final problems = [
    for (final c in index.cards)
      if (c.type == kTypeSystemDesign) c,
  ];
  DateTime? dueOf(Card c) => states['${c.id}::$_recognitionSlug']?.dueAt;
  // 0 = overdue, 1 = never mocked, 2 = upcoming.
  int bucket(Card c) {
    final d = dueOf(c);
    if (d == null) return 1;
    return d.isAfter(now) ? 2 : 0;
  }

  problems.sort((a, b) {
    final ba = bucket(a), bb = bucket(b);
    if (ba != bb) return ba.compareTo(bb);
    final da = dueOf(a), db = dueOf(b);
    if (da != null && db != null) return da.compareTo(db);
    return a.title.compareTo(b.title);
  });
  return problems;
}

/// The due date for a problem's next re-mock, or null if never mocked.
@riverpod
Future<DateTime?> systemDesignDue(Ref ref, String problemId) async {
  final states = await ref.watch(recognitionRepositoryProvider).loadStates();
  return states['$problemId::$_recognitionSlug']?.dueAt;
}

/// Auto support mode from demonstrated competence: **coaching** until the
/// candidate has completed a few mocks AND is scoring decently, then **realistic**
/// (scaffolding fade; avoids the expertise-reversal effect). Overridable per
/// session in the UI.
@riverpod
Future<SdSupportMode> sdAutoSupportMode(Ref ref) async {
  final attempts = await ref
      .watch(appliedRepositoryProvider)
      .attempts(domain: 'system-design');
  final mocks = [
    for (final a in attempts)
      if (a.source == 'sd-practice') a,
  ];
  if (mocks.length < 3) return SdSupportMode.coaching;
  final recent = mocks.take(3).toList();
  final mean =
      recent.map((a) => a.appliedScore).reduce((x, y) => x + y) / recent.length;
  return mean >= 60 ? SdSupportMode.realistic : SdSupportMode.coaching;
}

/// The system-design mock session's phase + state are the shared "AI mock" types.
typedef SdMockPhase = MockPhase;
typedef SdMockState = MockSessionState;

/// Drives one system-design mock interview on the shared mock-session engine
/// (core/practice/mock_session.dart): a terse hard-coded opener, interviewer turns
/// (calibrated by level + support mode), then on End an interviewer debrief plus an
/// adversarial grader **panel** over the cold transcript that records the
/// applied-transfer attempt and advances the spaced-recurrence clock. After the
/// mock the candidate can keep chatting with a tutor to learn. This class supplies
/// only the SD-specific prompts + what to record on a grade. Ephemeral per problem.
@riverpod
class SdMockSession extends _$SdMockSession {
  // Quality-critical path (the interviewer and grader must actually reason about
  // architecture and resist sycophancy), so use a stronger model than the cheap
  // default. The user supplies their own key; mocks are occasional.
  static const _model = 'claude-sonnet-4-6';

  /// How many independent adversarial graders vote on the final score.
  static const _panelSize = 3;

  @override
  SdMockState build(String problemId) => const SdMockState();

  ClaudeService? _claudeOrError() {
    final claude = ref.read(claudeServiceProvider);
    if (claude == null) {
      state = state.copyWith(
          error: 'Add your Anthropic API key in Settings to run a mock.');
    }
    return claude;
  }

  /// Kick off the interview with a terse, hard-coded opener.
  void start({required Card card}) =>
      state = mockStart(state, systemDesignOpeningLine(card));

  /// Send the candidate's turn (interviewer while running, tutor once done).
  Future<void> send(
    String text, {
    required Card card,
    required SeniorityLevel level,
    required CompanyTier company,
    required SdSupportMode support,
  }) async {
    final claude = _claudeOrError();
    if (claude == null) return;
    await mockSend(
      claude: claude,
      model: _model,
      text: text,
      read: () => state,
      write: (s) => state = s,
      runningSystem: buildSystemDesignInterviewerSystem(
          card: card, level: level, company: company, support: support),
      doneSystem: buildSystemDesignTutorSystem(card: card, level: level),
    );
  }

  /// End the interview: interviewer debrief, adversarial grader panel over the
  /// transcript, record the applied attempt (assisted mocks are softer evidence),
  /// and advance the spaced-recurrence clock.
  Future<void> endAndGrade({
    required Card card,
    required SeniorityLevel level,
    required CompanyTier company,
    required SdSupportMode support,
  }) async {
    final claude = _claudeOrError();
    if (claude == null) return;
    await mockEndAndGrade(
      claude: claude,
      model: _model,
      panelSize: _panelSize,
      read: () => state,
      write: (s) => state = s,
      interviewerSystem: buildSystemDesignInterviewerSystem(
          card: card, level: level, company: company, support: support),
      graderSystem: buildSdGraderSystem(card: card, level: level),
      dimensions: systemDesignRubricDimensions.toSet(),
      onGraded: (grade) async {
        final now = (await ref.read(clockProvider.future)).now();
        await ref.read(appliedRepositoryProvider).record(
              cardId: card.id,
              domain: card.domain,
              source: 'sd-practice',
              occurredAt: now,
              assessment: AppliedAssessment(
                appliedScore: grade.appliedScore,
                rubric: grade.rubric,
                // Coaching-mode mocks were assisted → softer evidence
                // (hintLevel>0) so learning reps don't inflate readiness.
                hintLevel: support == SdSupportMode.coaching ? 1 : 0,
                note: grade.note,
              ),
            );
        // Advance the spaced-recurrence clock (schedules the next re-mock).
        await ref.read(recognitionRepositoryProvider).recordExplain(
              cardId: card.id,
              sectionSlug: _recognitionSlug,
              outcome: scoreToRecurrence(grade.appliedScore),
              now: now,
            );
        ref
          ..invalidate(appliedTransferProvider)
          ..invalidate(systemDesignProblemsProvider)
          ..invalidate(systemDesignDueProvider)
          ..invalidate(sdAutoSupportModeProvider);
      },
    );
  }
}
