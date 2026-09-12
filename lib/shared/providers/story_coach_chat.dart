import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/ai/claude_service.dart';
import '../../core/ai/story_coach.dart';
import '../../core/story/story.dart';
import '../../core/story/story_repository.dart';
import 'ai.dart';
import 'clock.dart';
import 'story.dart';

part 'story_coach_chat.g.dart';

/// The career brain-dump conversation: the coach interviews the candidate and
/// drafts STAR+L stories; the candidate saves them to the vault. Ephemeral — a
/// fresh chat each time the capture screen opens.
class StoryCoachChatState {
  const StoryCoachChatState({
    this.messages = const [],
    this.busy = false,
    this.error,
    this.draft,
  });

  final List<CoachMessage> messages;
  final bool busy;
  final String? error;

  /// The latest drafted story the coach has offered (pending a Save tap).
  final StoryDraft? draft;

  bool get isEmpty => messages.isEmpty;

  StoryCoachChatState copyWith({
    List<CoachMessage>? messages,
    bool? busy,
    String? error,
    bool clearError = false,
    StoryDraft? draft,
    bool clearDraft = false,
  }) =>
      StoryCoachChatState(
        messages: messages ?? this.messages,
        busy: busy ?? this.busy,
        error: clearError ? null : (error ?? this.error),
        draft: clearDraft ? null : (draft ?? this.draft),
      );
}

@riverpod
class StoryCoachChat extends _$StoryCoachChat {
  static const _model = ClaudeService.defaultModel;

  @override
  StoryCoachChatState build() => const StoryCoachChatState();

  /// Send the candidate's turn; [system] carries the gap-targeted capture prompt
  /// (built by the screen from current coverage), stable across the conversation.
  Future<void> send(String text, {required String system}) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || state.busy) return;
    final claude = ref.read(claudeServiceProvider);
    if (claude == null) {
      state = state.copyWith(
          error: 'Add your Anthropic API key in Settings to build stories.');
      return;
    }

    final history = [...state.messages, CoachMessage(CoachRole.user, trimmed)];
    state = state.copyWith(messages: history, busy: true, clearError: true);
    try {
      final reply = await claude.chat(
        system: system,
        model: _model,
        maxTokens: 900,
        messages: storyChatTurns(history),
      );
      final parsed = parseStoryReply(reply);
      state = state.copyWith(
        messages: [...history, CoachMessage(CoachRole.assistant, parsed.text)],
        busy: false,
        // Keep the last draft if this turn didn't produce a new one.
        draft: parsed.draft,
      );
    } on ClaudeException catch (e) {
      state = state.copyWith(busy: false, error: e.message);
    } catch (e) {
      state = state.copyWith(busy: false, error: 'Something went wrong: $e');
    }
  }

  /// Save the current draft to the vault as a story note. Returns the saved
  /// [Story] (or null if there was nothing to save / no vault).
  Future<Story?> saveDraft() async {
    final draft = state.draft;
    if (draft == null) return null;
    final repo = ref.read(storyRepositoryProvider);
    if (repo == null) {
      state = state.copyWith(error: 'No vault configured to save into.');
      return null;
    }
    final now = (await ref.read(clockProvider.future)).now();
    final story = draft.toStory(id: storySlug(draft.title), created: now);
    await repo.save(story);
    ref.invalidate(storiesProvider);
    state = state.copyWith(clearDraft: true);
    return story;
  }

  void dismissDraft() => state = state.copyWith(clearDraft: true);
}
