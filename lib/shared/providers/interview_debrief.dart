import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/ai/claude_service.dart';
import '../../core/ai/coach_update_chat.dart'
    show CoachMessage, CoachRole, coachChatTurns;
import '../../core/ai/interview_debrief.dart';
import '../../core/deck/aim.dart';
import '../../core/readiness/target.dart';
import 'ai.dart';
import 'decks.dart';
import 'template.dart';
import 'vault.dart';

part 'interview_debrief.g.dart';

/// The post-interview debrief conversation for one goal: a chat that ends in a
/// proposed [DebriefResult] (outcome + reweights) the learner can apply.
class InterviewDebriefState {
  const InterviewDebriefState({
    this.messages = const [],
    this.result,
    this.busy = false,
    this.error,
  });

  final List<CoachMessage> messages;

  /// The most recently proposed debrief (null until the model emits one).
  final DebriefResult? result;
  final bool busy;
  final String? error;

  bool get isEmpty => messages.isEmpty;

  InterviewDebriefState copyWith({
    List<CoachMessage>? messages,
    DebriefResult? result,
    bool? busy,
    String? error,
    bool clearError = false,
  }) =>
      InterviewDebriefState(
        messages: messages ?? this.messages,
        result: result ?? this.result,
        busy: busy ?? this.busy,
        error: clearError ? null : (error ?? this.error),
      );
}

/// Drives the "how did the interview go? → adjust the plan" chat, keyed by the
/// [Aim.id] being debriefed. Sonnet, since it reasons about the role +
/// deck and emits structured output.
@riverpod
class InterviewDebrief extends _$InterviewDebrief {
  static const _model = 'claude-sonnet-4-6';

  @override
  InterviewDebriefState build(String aimId) => const InterviewDebriefState();

  /// The interview being debriefed — looked up by [aimId] on the active deck's
  /// aims (Phase B).
  Future<Aim?> _aim() async {
    final goal = await ref.read(activeDeckProvider.future);
    for (final iv in goal.aims) {
      if (iv.id == aimId) return iv;
    }
    return null;
  }

  Future<void> send(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || state.busy) return;
    final claude = ref.read(claudeServiceProvider);
    if (claude == null) {
      state = state.copyWith(
          error: 'Add your Anthropic API key in Settings to debrief.');
      return;
    }
    final aim = await _aim();
    if (aim == null) {
      state = state.copyWith(error: 'This interview no longer exists.');
      return;
    }

    final history = [...state.messages, CoachMessage(CoachRole.user, trimmed)];
    state = state.copyWith(messages: history, busy: true, clearError: true);

    try {
      final index = await ref.read(vaultIndexProvider.future);
      // Label the interview by its company (falling back to the AIM's target
      // role, S5) for the prompt's "debriefing for: …" line.
      final goal = await ref.read(activeDeckProvider.future);
      final registry = await ref.read(templateRegistryProvider.future);
      final role = ReadinessTarget.forAim(
              aim, registry.byId(goal.templateId) ?? registry.primary)
          .label;
      final goalLabel =
          aim.companyName.isEmpty ? role : '${aim.companyName} · $role';
      final domains = <String>{
        for (final c in index.cards)
          if (c.domain != null) c.domain!,
      };
      final concepts = <String>{
        for (final c in index.cards) ...c.concepts,
      };
      final freq = deckFrequencySignal(index.cards);
      final system = buildDebriefSystem(
        goalLabel: goalLabel,
        deckDomains: domains.toList(),
        deckConcepts: concepts.toList(),
        highFrequency: freq.high,
        lowFrequency: freq.low,
      );

      final raw = await claude.chat(
        system: system,
        model: _model,
        maxTokens: 1100,
        messages: coachChatTurns(history),
      );
      final parsed = parseDebriefReply(raw);
      if (!ref.mounted) return; // sheet closed mid-reply (autodispose)
      state = state.copyWith(
        messages: [...history, CoachMessage(CoachRole.assistant, parsed.text)],
        result: parsed.result, // keep prior result if this reply has none
        busy: false,
      );
    } on ClaudeException catch (e) {
      state = state.copyWith(busy: false, error: e.message);
    } catch (e) {
      state = state.copyWith(busy: false, error: 'Could not debrief: $e');
    }
  }

  /// Apply the current debrief to the interview: record the outcome, merge the
  /// reweights, append the summary. Returns the updated interview, or null if
  /// there's nothing to apply / the interview is gone.
  Future<Aim?> apply() async {
    final result = state.result;
    if (result == null) return null;
    final goal = await ref.read(activeDeckProvider.future);
    final aim = await _aim();
    if (aim == null) return null;
    final updated = result.applyTo(aim);
    await ref.read(decksProvider.notifier).upsertAim(goal.id, updated);
    return updated;
  }
}
