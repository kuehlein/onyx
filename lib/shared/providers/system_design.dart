import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/ai/claude_service.dart';
import '../../core/ai/coach.dart' show CoachMessage, CoachRole;
import '../../core/ai/coach_update_chat.dart' show coachChatTurns;
import '../../core/ai/system_design_interviewer.dart';
import '../../core/interview/assessment.dart';
import '../../core/interview/system_design_grader.dart';
import '../../core/readiness/target.dart';
import '../models/card.dart';
import 'ai.dart';
import 'clock.dart';
import 'interview.dart';
import 'readiness.dart';
import 'vault.dart';

part 'system_design.g.dart';

/// System-design practice problems (the `type: system-design` cards), ordered
/// **weakest-first**: never-mocked problems first, then those mocked longest ago.
/// This is the queue the track surfaces (a mock is long, so cadence is per-week,
/// not per-day — the ordering is what matters, not a hard daily count).
@riverpod
Future<List<Card>> systemDesignProblems(Ref ref) async {
  final index = await ref.watch(vaultIndexProvider.future);
  final problems = [
    for (final c in index.cards)
      if (c.type == CardType.systemDesign) c,
  ];
  final attempts = await ref
      .watch(appliedRepositoryProvider)
      .attempts(); // most recent first
  final lastMock = <String, DateTime>{};
  for (final a in attempts) {
    if (a.source != 'sd-practice') continue;
    lastMock.putIfAbsent(a.cardId, () => a.occurredAt);
  }
  problems.sort((a, b) {
    final la = lastMock[a.id];
    final lb = lastMock[b.id];
    if (la == null && lb == null) return a.title.compareTo(b.title);
    if (la == null) return -1; // never mocked → first
    if (lb == null) return 1;
    return la.compareTo(lb); // oldest mock → first
  });
  return problems;
}

/// One turn's phase of the mock session.
enum SdMockPhase { intro, running, grading, done }

/// Ephemeral state of a single system-design mock interview.
class SdMockState {
  const SdMockState({
    this.phase = SdMockPhase.intro,
    this.messages = const [],
    this.busy = false,
    this.error,
    this.grade,
  });

  final SdMockPhase phase;
  final List<CoachMessage> messages;
  final bool busy;
  final String? error;

  /// The reconciled grade after the session ends (null until graded).
  final SdGrade? grade;

  SdMockState copyWith({
    SdMockPhase? phase,
    List<CoachMessage>? messages,
    bool? busy,
    String? error,
    bool clearError = false,
    SdGrade? grade,
  }) =>
      SdMockState(
        phase: phase ?? this.phase,
        messages: messages ?? this.messages,
        busy: busy ?? this.busy,
        error: clearError ? null : (error ?? this.error),
        grade: grade ?? this.grade,
      );
}

/// Drives one system-design mock interview for a problem: relays turns to the
/// interviewer persona, then on end runs an adversarial grader **panel** over the
/// cold transcript and records the applied-transfer attempt. Ephemeral, keyed by
/// problem id.
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

  /// Kick off the interview: the interviewer gives its opening.
  Future<void> start({
    required Card card,
    required SeniorityLevel level,
    required CompanyTier company,
  }) async {
    if (state.phase != SdMockPhase.intro || state.busy) return;
    final claude = _claudeOrError();
    if (claude == null) return;
    // Anthropic turns must start with the candidate; a short kickoff reads
    // naturally and prompts the interviewer's opener.
    final history = [
      const CoachMessage(CoachRole.user, "I'm ready — let's begin."),
    ];
    state = state.copyWith(
        phase: SdMockPhase.running,
        messages: history,
        busy: true,
        clearError: true);
    await _reply(claude, card, level, company, history);
  }

  /// Send the candidate's turn.
  Future<void> send(
    String text, {
    required Card card,
    required SeniorityLevel level,
    required CompanyTier company,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || state.busy || state.phase != SdMockPhase.running) {
      return;
    }
    final claude = _claudeOrError();
    if (claude == null) return;
    final history = [...state.messages, CoachMessage(CoachRole.user, trimmed)];
    state = state.copyWith(messages: history, busy: true, clearError: true);
    await _reply(claude, card, level, company, history);
  }

  Future<void> _reply(ClaudeService claude, Card card, SeniorityLevel level,
      CompanyTier company, List<CoachMessage> history) async {
    try {
      final raw = await claude.chat(
        system: buildSystemDesignInterviewerSystem(
            card: card, level: level, company: company),
        model: _model,
        maxTokens: 700,
        messages: coachChatTurns(history),
      );
      state = state.copyWith(
        messages: [...history, CoachMessage(CoachRole.assistant, raw.trim())],
        busy: false,
      );
    } on ClaudeException catch (e) {
      state = state.copyWith(busy: false, error: e.message);
    } catch (e) {
      state = state.copyWith(busy: false, error: 'Something went wrong: $e');
    }
  }

  /// End the interview: get the interviewer's debrief, run the adversarial
  /// grader panel over the transcript, and record the applied attempt.
  Future<void> endAndGrade({
    required Card card,
    required SeniorityLevel level,
    required CompanyTier company,
  }) async {
    if (state.busy || state.phase != SdMockPhase.running) return;
    final claude = _claudeOrError();
    if (claude == null) return;

    // 1) Interviewer debrief (teaching), shown to the candidate.
    final history = [
      ...state.messages,
      const CoachMessage(
          CoachRole.user, "That's time. Please give me your honest debrief."),
    ];
    state = state.copyWith(
        phase: SdMockPhase.grading, messages: history, busy: true);
    await _reply(claude, card, level, company, history);

    // 2) Adversarial grader panel over the cold transcript (the honest number).
    final transcript = buildSdGraderTranscript([
      for (final m in state.messages)
        (
          role: m.role == CoachRole.user ? 'user' : 'assistant',
          content: m.text
        ),
    ]);
    final graderSystem = buildSdGraderSystem(card: card, level: level);
    final results = await Future.wait([
      for (var i = 0; i < _panelSize; i++)
        claude
            .chat(
              system: graderSystem,
              model: _model,
              maxTokens: 400,
              messages: [(role: 'user', content: transcript)],
            )
            .then<SdGrade?>(parseSdGrade)
            .catchError((_) => null),
    ]);
    final panel = [
      for (final g in results)
        if (g != null) g,
    ];
    final score01 = reconcilePanel01(panel);

    SdGrade? finalGrade;
    if (score01 != null) {
      // Rubric/note from the panel's median-scoring grade (most representative).
      final sorted = [...panel]
        ..sort((a, b) => a.appliedScore.compareTo(b.appliedScore));
      final median = sorted[sorted.length ~/ 2];
      finalGrade = SdGrade(
        appliedScore: (score01 * 100).round(),
        rubric: median.rubric,
        note: median.note,
      );
      final now = (await ref.read(clockProvider.future)).now();
      await ref.read(appliedRepositoryProvider).record(
            cardId: card.id,
            domain: card.domain,
            source: 'sd-practice',
            occurredAt: now,
            assessment: AppliedAssessment(
              appliedScore: finalGrade.appliedScore,
              rubric: finalGrade.rubric,
              note: finalGrade.note,
            ),
          );
      ref.invalidate(appliedTransferProvider);
      ref.invalidate(systemDesignProblemsProvider);
    }
    state =
        state.copyWith(phase: SdMockPhase.done, busy: false, grade: finalGrade);
  }
}
