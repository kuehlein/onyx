import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/ai/claude_service.dart';
import '../../core/ai/coach_update_chat.dart'
    show CoachMessage, CoachRole, coachChatTurns;
import '../../core/ai/explain_coach.dart';
import '../models/card.dart';
import 'ai.dart';

part 'explain_chat.g.dart';

/// The explain-mode interviewer conversation for one algorithm problem.
/// Ephemeral (autodispose) and isolated per problem key — the coach probes the
/// candidate's verbal walkthrough and may suggest a recognition grade. Grounded
/// in the problem, passed per send so no state has to be threaded in.
class ExplainChatState {
  const ExplainChatState({
    this.messages = const [],
    this.busy = false,
    this.error,
    this.suggestion,
  });

  final List<CoachMessage> messages;
  final bool busy;
  final String? error;

  /// The coach's latest advisory recognition grade, if it offered one.
  final RecognitionSuggestion? suggestion;

  bool get isEmpty => messages.isEmpty;

  ExplainChatState copyWith({
    List<CoachMessage>? messages,
    bool? busy,
    String? error,
    bool clearError = false,
    RecognitionSuggestion? suggestion,
  }) =>
      ExplainChatState(
        messages: messages ?? this.messages,
        busy: busy ?? this.busy,
        error: clearError ? null : (error ?? this.error),
        suggestion: suggestion ?? this.suggestion,
      );
}

@riverpod
class ExplainChat extends _$ExplainChat {
  // A quick verbal Q&A, not a reasoning-heavy generation — cheap model.
  static const _model = ClaudeService.defaultModel;

  @override
  ExplainChatState build(String problemKey) => const ExplainChatState();

  /// Send the candidate's explanation turn; [card]/[section] seed the
  /// interviewer prompt for this problem.
  Future<void> send(
    String text, {
    required Card card,
    required CardSection section,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || state.busy) return;
    final claude = ref.read(claudeServiceProvider);
    if (claude == null) {
      state = state.copyWith(
          error: 'Add your Anthropic API key in Settings to use explain mode.');
      return;
    }

    final history = [...state.messages, CoachMessage(CoachRole.user, trimmed)];
    state = state.copyWith(messages: history, busy: true, clearError: true);

    try {
      final raw = await claude.chat(
        system: buildExplainCoachSystem(card: card, section: section),
        model: _model,
        maxTokens: 600,
        messages: coachChatTurns(history),
      );
      final parsed = parseExplainReply(raw);
      state = state.copyWith(
        messages: [
          ...history,
          CoachMessage(CoachRole.assistant, parsed.text),
        ],
        busy: false,
        suggestion: parsed.suggestion,
      );
    } on ClaudeException catch (e) {
      state = state.copyWith(busy: false, error: e.message);
    } catch (e) {
      state = state.copyWith(busy: false, error: 'Something went wrong: $e');
    }
  }
}
