import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/ai/claude_service.dart';
import '../../core/ai/flow_grader.dart';
import '../../core/interview/assessment.dart';
import '../../core/practice/mock_session.dart';
import '../../core/subject/flow_prompt.dart';
import '../models/card.dart';
import 'ai.dart';
import 'clock.dart';
import 'interview.dart';
import 'practice_plan.dart';
import 'readiness.dart';
import 'srs.dart';
import 'system_design.dart' show scoreToRecurrence;

part 'flow_runner.g.dart';

/// The recognition-clock section key for a config-flow card's re-practice schedule
/// (shared with every mock flow — see system_design.dart / behavioral.dart).
const _recognitionSlug = 'mock';

/// Drives one **config-driven** practice flow (task #30, "G2b") on the shared
/// mock-session engine (core/practice/mock_session.dart) — the GENERIC sibling of
/// [SdMockSession]/[BehavioralMockSession] for vault-authored flows (e.g. a Korean
/// `conversation` flow with `scheduling: mock`). The interlocutor + grader personas
/// come from the vault `skill` file (assembled by [assembleFlowPrompt] /
/// [buildFlowGraderSystem]); this class only wires the engine and records what a
/// grade means (an applied-transfer attempt + a spaced-recurrence advance).
///
/// Deliberately free of vault I/O: the caller (the future screen) loads the
/// [skill] text with `loadFlowSkill` and computes the covered-knowledge [frontier]
/// from the card's `depends-on` competence, then passes both in — so this Notifier
/// is trivially testable. Ephemeral per card id.
@riverpod
class FlowRunnerSession extends _$FlowRunnerSession {
  // Quality-critical path (the interlocutor must stay on-task and the grader must
  // resist sycophancy), so use a stronger model than the cheap default. The user
  // supplies their own key; mocks are occasional.
  static const _model = 'claude-sonnet-4-6';

  /// How many independent adversarial graders vote on the final score.
  static const _panelSize = 3;

  @override
  MockSessionState build(String cardId) => const MockSessionState();

  ClaudeService? _claudeOrError() {
    final claude = ref.read(claudeServiceProvider);
    if (claude == null) {
      state = state.copyWith(
          error: 'Add your Anthropic API key in Settings to run a mock.');
    }
    return claude;
  }

  /// Kick off the session with a terse, generic opener that doesn't leak the
  /// answer (the vault skill owns the actual scenario/persona).
  void start({
    required Card card,
    required String skill,
    required Set<String> frontier,
  }) =>
      state = mockStart(state, "Whenever you're ready — go ahead.");

  /// Send the learner's turn (the vault interlocutor while running, the tutor once
  /// done). [skill]/[frontier] are supplied by the caller (no vault I/O here).
  Future<void> send(
    String text, {
    required Card card,
    required String skill,
    required Set<String> frontier,
  }) async {
    final claude = _claudeOrError();
    if (claude == null) return;
    await mockSend(
      claude: claude,
      model: _model,
      text: text,
      read: () => state,
      write: (s) => state = s,
      runningSystem: assembleFlowPrompt(
          skill: skill, problem: card.overview, frontier: frontier),
      doneSystem: buildFlowTutorSystem(skill: skill, frontier: frontier),
    );
  }

  /// End the session: an interlocutor debrief, an adversarial grader panel over
  /// the cold transcript, record the applied attempt, and advance the
  /// spaced-recurrence clock (schedules the next re-practice).
  Future<void> endAndGrade({
    required Card card,
    required String skill,
    required Set<String> frontier,
  }) async {
    final claude = _claudeOrError();
    if (claude == null) return;
    await mockEndAndGrade(
      claude: claude,
      model: _model,
      panelSize: _panelSize,
      read: () => state,
      write: (s) => state = s,
      interviewerSystem: assembleFlowPrompt(
          skill: skill, problem: card.overview, frontier: frontier),
      graderSystem: buildFlowGraderSystem(
          skill: skill, problem: card.overview, frontier: frontier),
      dimensions: flowRubricDimensions.toSet(),
      onGraded: (grade) async {
        final now = (await ref.read(clockProvider.future)).now();
        await ref.read(appliedRepositoryProvider).record(
              cardId: card.id,
              domain: card.domain,
              source: card.type,
              occurredAt: now,
              assessment: AppliedAssessment(
                appliedScore: grade.appliedScore,
                rubric: grade.rubric,
                hintLevel: 0,
                note: grade.note,
              ),
            );
        // Advance the spaced-recurrence clock (schedules the next re-practice).
        await ref.read(recognitionRepositoryProvider).recordExplain(
              cardId: card.id,
              sectionSlug: _recognitionSlug,
              outcome: scoreToRecurrence(grade.appliedScore),
              now: now,
            );
        ref
          ..invalidate(appliedTransferProvider)
          ..invalidate(practiceAvailabilityProvider);
      },
    );
  }
}
