import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/ai/claude_service.dart';
import '../../core/ai/coach_update_chat.dart';
import 'ai.dart';

part 'coach_chat.g.dart';

/// The ephemeral "talk about it" conversation behind a coach update. Not
/// persisted — it's a quick, in-the-moment chat; a fresh one starts each time
/// the sheet opens (autodispose, held alive only while the sheet is on screen).
class CoachChatState {
  const CoachChatState(
      {this.messages = const [], this.busy = false, this.error});

  final List<CoachMessage> messages;
  final bool busy;
  final String? error;

  bool get isEmpty => messages.isEmpty;

  CoachChatState copyWith({
    List<CoachMessage>? messages,
    bool? busy,
    String? error,
    bool clearError = false,
  }) =>
      CoachChatState(
        messages: messages ?? this.messages,
        busy: busy ?? this.busy,
        error: clearError ? null : (error ?? this.error),
      );
}

@riverpod
class CoachChat extends _$CoachChat {
  static const _model = ClaudeService.defaultModel;

  @override
  CoachChatState build() => const CoachChatState();

  /// Send the learner's turn and append the strategist's reply. [system] carries
  /// the nudge + numbers (built by the sheet), stable across the conversation.
  Future<void> send(String text, {required String system}) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || state.busy) return;
    final claude = ref.read(claudeServiceProvider);
    if (claude == null) {
      state = state.copyWith(
          error: 'Add your Anthropic API key in Settings to chat.');
      return;
    }

    final history = [
      ...state.messages,
      CoachMessage(CoachRole.user, trimmed),
    ];
    state = state.copyWith(messages: history, busy: true, clearError: true);

    try {
      final reply = await claude.chat(
        system: system,
        model: _model,
        maxTokens: 700,
        messages: coachChatTurns(history),
      );
      state = state.copyWith(
        messages: [...history, CoachMessage(CoachRole.assistant, reply)],
        busy: false,
      );
    } on ClaudeException catch (e) {
      state = state.copyWith(busy: false, error: e.message);
    } catch (e) {
      state = state.copyWith(busy: false, error: 'Something went wrong: $e');
    }
  }
}
