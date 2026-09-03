import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/ai/claude_service.dart';
import '../../core/ai/coach_update_chat.dart'
    show CoachMessage, CoachRole, coachChatTurns;
import '../../core/ai/readiness_report.dart';
import 'ai.dart';

part 'readiness_report_chat.g.dart';

/// The "ask about your report" conversation. Ephemeral (autodispose) — grounded
/// in the current report text, which is passed in per send so the chat always
/// reflects the latest generation. Cheap default model; it's a quick Q&A, not a
/// reasoning-heavy generation.
class ReadinessReportChatState {
  const ReadinessReportChatState(
      {this.messages = const [], this.busy = false, this.error});

  final List<CoachMessage> messages;
  final bool busy;
  final String? error;

  bool get isEmpty => messages.isEmpty;

  ReadinessReportChatState copyWith({
    List<CoachMessage>? messages,
    bool? busy,
    String? error,
    bool clearError = false,
  }) =>
      ReadinessReportChatState(
        messages: messages ?? this.messages,
        busy: busy ?? this.busy,
        error: clearError ? null : (error ?? this.error),
      );
}

@riverpod
class ReadinessReportChat extends _$ReadinessReportChat {
  static const _model = ClaudeService.defaultModel;

  @override
  ReadinessReportChatState build() => const ReadinessReportChatState();

  /// Send the learner's question; [reportText] is the report being discussed
  /// (baked into the system prompt so answers stay consistent with it).
  Future<void> send(String text, {required String reportText}) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || state.busy) return;
    final claude = ref.read(claudeServiceProvider);
    if (claude == null) {
      state = state.copyWith(
          error: 'Add your Anthropic API key in Settings to chat.');
      return;
    }

    final history = [...state.messages, CoachMessage(CoachRole.user, trimmed)];
    state = state.copyWith(messages: history, busy: true, clearError: true);

    try {
      final reply = await claude.chat(
        system: buildReadinessReportChatSystem(reportText),
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
