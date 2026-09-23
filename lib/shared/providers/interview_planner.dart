import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/ai/claude_service.dart';
import '../../core/ai/coach_update_chat.dart'
    show CoachMessage, CoachRole, coachChatTurns;
import '../../core/ai/interview_plan.dart';
import '../../core/deck/aim.dart';
import 'ai.dart';
import 'clock.dart';
import 'readiness.dart';
import 'decks.dart';
import 'vault.dart';

part 'interview_planner.g.dart';

/// The interview-planner conversation: a chat that ends in a proposed
/// [InterviewPlan] the learner can accept (→ an active [Aim] on the
/// active study goal).
class InterviewPlannerState {
  const InterviewPlannerState({
    this.messages = const [],
    this.plan,
    this.busy = false,
    this.error,
  });

  final List<CoachMessage> messages;

  /// The most recently proposed plan (null until the model emits one).
  final InterviewPlan? plan;
  final bool busy;
  final String? error;

  bool get isEmpty => messages.isEmpty;

  InterviewPlannerState copyWith({
    List<CoachMessage>? messages,
    InterviewPlan? plan,
    bool clearPlan = false,
    bool? busy,
    String? error,
    bool clearError = false,
  }) =>
      InterviewPlannerState(
        messages: messages ?? this.messages,
        plan: clearPlan ? null : (plan ?? this.plan),
        busy: busy ?? this.busy,
        error: clearError ? null : (error ?? this.error),
      );
}

/// Drives the "describe an interview → get a plan" chat. A capable model
/// (Sonnet) since it reasons about the role + deck and emits structured output.
@riverpod
class InterviewPlanner extends _$InterviewPlanner {
  static const _model = 'claude-sonnet-4-6';

  @override
  InterviewPlannerState build() => const InterviewPlannerState();

  Future<void> send(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || state.busy) return;
    final claude = ref.read(claudeServiceProvider);
    if (claude == null) {
      state = state.copyWith(
          error: 'Add your Anthropic API key in Settings to plan.');
      return;
    }

    final history = [...state.messages, CoachMessage(CoachRole.user, trimmed)];
    state = state.copyWith(messages: history, busy: true, clearError: true);

    try {
      final index = await ref.read(vaultIndexProvider.future);
      final base = await ref.read(activeTargetProvider.future);
      final today = (await ref.read(clockProvider.future)).today();
      final domains = <String>{
        for (final c in index.cards)
          if (c.domain != null) c.domain!,
      };
      final concepts = <String>{
        for (final c in index.cards) ...c.concepts,
      };
      final system = buildInterviewPlannerSystem(
        deckDomains: domains.toList(),
        deckConcepts: concepts.toList(),
        base: base,
        today: today,
      );

      final raw = await claude.chat(
        system: system,
        model: _model,
        maxTokens: 1100,
        messages: coachChatTurns(history),
      );
      final parsed = parseInterviewPlannerReply(raw);
      state = state.copyWith(
        messages: [...history, CoachMessage(CoachRole.assistant, parsed.text)],
        plan: parsed.plan, // keep prior plan if this reply has none
        busy: false,
      );
    } on ClaudeException catch (e) {
      state = state.copyWith(busy: false, error: e.message);
    } catch (e) {
      state = state.copyWith(busy: false, error: 'Could not plan: $e');
    }
  }

  /// Accept the current plan: attach it as an active [Aim] on the active study
  /// goal (which the targeting layer then applies to study). The aim carries its
  /// OWN target knobs + date now (S5 — the deck is a pure lens), so we just append
  /// it; no deck slots to seed. Returns the saved interview, or null if there's no
  /// plan to accept.
  Future<Aim?> accept() async {
    final plan = state.plan;
    if (plan == null) return null;
    final clock = await ref.read(clockProvider.future);
    final now = clock.now();
    // notBefore drops a past date (usually a wrong-year slip) → unscheduled
    // rather than filed in the past.
    final aim = plan.toInterview('goal-${now.microsecondsSinceEpoch}',
        notBefore: clock.today());
    final goal = await ref.read(activeDeckProvider.future);
    await ref
        .read(decksProvider.notifier)
        .upsert(goal.copyWith(aims: [...goal.aims, aim]));
    return aim;
  }
}
