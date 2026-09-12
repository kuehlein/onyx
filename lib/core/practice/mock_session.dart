import '../ai/claude_service.dart';
import '../ai/coach.dart' show CoachMessage, CoachRole;
import '../ai/coach_update_chat.dart' show coachChatTurns;
import 'mock_grader.dart';

/// Shared lifecycle for an "AI mock" practice session (system design, behavioral,
/// …): a hard-coded opener → interviewer turns → on End, an interviewer debrief +
/// an adversarial grader panel over the cold transcript, then a post-mock tutor
/// chat. The track-specific bits (which prompts, which rubric, what to record on a
/// grade) are supplied by the caller; the mechanics live here so every mock track
/// shares one engine. State is driven through [read]/[write] closures so a Riverpod
/// Notifier can delegate without a shared base class.
enum MockPhase { intro, running, grading, done }

/// How much the interviewer helps — scaffolding that fades with demonstrated
/// competence (avoiding the expertise-reversal effect). Shared across mock tracks.
/// [coaching] steps in when the candidate is stuck; [realistic] is hands-off. An
/// explicit request for help is always honoured in either mode.
enum SupportMode { coaching, realistic }

class MockSessionState {
  const MockSessionState({
    this.phase = MockPhase.intro,
    this.messages = const [],
    this.busy = false,
    this.error,
    this.grade,
  });

  final MockPhase phase;
  final List<CoachMessage> messages;
  final bool busy;
  final String? error;

  /// The reconciled grade after the session ends (null until graded).
  final MockGrade? grade;

  MockSessionState copyWith({
    MockPhase? phase,
    List<CoachMessage>? messages,
    bool? busy,
    String? error,
    bool clearError = false,
    MockGrade? grade,
  }) =>
      MockSessionState(
        phase: phase ?? this.phase,
        messages: messages ?? this.messages,
        busy: busy ?? this.busy,
        error: clearError ? null : (error ?? this.error),
        grade: grade ?? this.grade,
      );
}

/// Anthropic turns must start with the candidate; the hard-coded opener is a
/// UI-only assistant message, so drop leading assistant turns for the API.
List<({String role, String content})> mockApiTurns(
        List<CoachMessage> history) =>
    coachChatTurns(
        history.skipWhile((m) => m.role == CoachRole.assistant).toList());

/// Render the conversation into a Candidate/Interviewer transcript for the grader.
String mockTranscript(List<CoachMessage> messages) {
  final b = StringBuffer();
  for (final m in messages) {
    final who = m.role == CoachRole.user ? 'Candidate' : 'Interviewer';
    b.writeln('$who: ${m.text}');
  }
  return b.toString();
}

/// Begin the interview with a terse hard-coded [openerText] (no generation, and it
/// doesn't leak what the candidate should elicit). No-op unless in [MockPhase.intro].
MockSessionState mockStart(MockSessionState s, String openerText) {
  if (s.phase != MockPhase.intro) return s;
  return s.copyWith(
    phase: MockPhase.running,
    messages: [CoachMessage(CoachRole.assistant, openerText)],
    clearError: true,
  );
}

/// Send the candidate's turn: interviewer while [MockPhase.running], tutor once
/// [MockPhase.done]. No-op otherwise, when busy, or on empty input.
Future<void> mockSend({
  required ClaudeService claude,
  required String model,
  required String text,
  required MockSessionState Function() read,
  required void Function(MockSessionState) write,
  required String runningSystem,
  required String doneSystem,
  int runningMaxTokens = 700,
  int doneMaxTokens = 600,
}) async {
  final s = read();
  final trimmed = text.trim();
  if (trimmed.isEmpty || s.busy) return;
  if (s.phase != MockPhase.running && s.phase != MockPhase.done) return;
  final running = s.phase == MockPhase.running;
  final history = [...s.messages, CoachMessage(CoachRole.user, trimmed)];
  write(s.copyWith(messages: history, busy: true, clearError: true));
  await _respond(
    claude: claude,
    model: model,
    system: running ? runningSystem : doneSystem,
    maxTokens: running ? runningMaxTokens : doneMaxTokens,
    read: read,
    write: write,
    history: history,
  );
}

Future<void> _respond({
  required ClaudeService claude,
  required String model,
  required String system,
  required int maxTokens,
  required MockSessionState Function() read,
  required void Function(MockSessionState) write,
  required List<CoachMessage> history,
}) async {
  try {
    final raw = await claude.chat(
      system: system,
      model: model,
      maxTokens: maxTokens,
      messages: mockApiTurns(history),
    );
    write(read().copyWith(
      messages: [...history, CoachMessage(CoachRole.assistant, raw.trim())],
      busy: false,
    ));
  } on ClaudeException catch (e) {
    write(read().copyWith(busy: false, error: e.message));
  } catch (e) {
    write(read().copyWith(busy: false, error: 'Something went wrong: $e'));
  }
}

/// End the interview: an interviewer debrief (teaching, non-blocking), then an
/// adversarial grader panel over the cold transcript. On a reconciled grade,
/// [onGraded] records it (applied attempt + spaced-recurrence advance — track
/// specific). No-op unless in [MockPhase.running].
Future<void> mockEndAndGrade({
  required ClaudeService claude,
  required String model,
  required int panelSize,
  required MockSessionState Function() read,
  required void Function(MockSessionState) write,
  required String interviewerSystem,
  required String graderSystem,
  required Set<String> dimensions,
  required Future<void> Function(MockGrade grade) onGraded,
  String debriefPrompt = "That's time. Please give me your honest debrief.",
  int debriefMaxTokens = 700,
}) async {
  final s0 = read();
  if (s0.busy || s0.phase != MockPhase.running) return;

  // 1) Interviewer debrief (teaching), shown to the candidate. Non-blocking.
  final history = [
    ...s0.messages,
    CoachMessage(CoachRole.user, debriefPrompt),
  ];
  write(s0.copyWith(phase: MockPhase.grading, messages: history, busy: true));
  try {
    final raw = await claude.chat(
      system: interviewerSystem,
      model: model,
      maxTokens: debriefMaxTokens,
      messages: mockApiTurns(history),
    );
    write(read().copyWith(
        messages: [...history, CoachMessage(CoachRole.assistant, raw.trim())]));
  } catch (_) {
    // A failed debrief shouldn't block grading; carry on with what we have.
  }

  // 2) Adversarial grader panel over the cold transcript (the honest number).
  final reconciled = await runAdversarialPanel(
    claude: claude,
    model: model,
    panelSize: panelSize,
    graderSystem: graderSystem,
    transcript: mockTranscript(read().messages),
    dimensions: dimensions,
  );
  MockGrade? finalGrade;
  if (reconciled != null) {
    finalGrade = reconciled.grade;
    await onGraded(finalGrade);
  }
  write(read().copyWith(phase: MockPhase.done, busy: false, grade: finalGrade));
}
