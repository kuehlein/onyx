import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/ai/card_generation.dart';
import '../../core/ai/claude_service.dart';
import '../../core/vault/generated_cards.dart';
import 'ai.dart';
import 'clock.dart';
import 'vault.dart';

part 'card_generation.g.dart';

/// Thrown when card generation can't run or produced nothing usable. Carries a
/// user-presentable [message]; the sheet shows it inline.
class CardGenerationException implements Exception {
  CardGenerationException(this.message);
  final String message;
  @override
  String toString() => 'CardGenerationException: $message';
}

/// The AI card-generation service (docs/content-creation.md §2.2): takes the
/// learner's pasted notes or named topic, asks a capable model for a small batch
/// of well-formed cards, and writes them into the study folder as local drafts
/// that flow through the existing review gate.
@riverpod
class CardGeneration extends _$CardGeneration {
  /// A capable model for card quality — the same choice as the interview planner
  /// and the mock-interview flows (NOT the Haiku default), because card
  /// formulation is the quality crux.
  static const _model = 'claude-sonnet-4-6';

  @override
  void build() {}

  /// Generate a batch of draft cards from [input] (pasted notes or a topic).
  /// Returns the number of cards written. Throws [CardGenerationException] with a
  /// clear message when AI is off, no folder is configured, or the model
  /// returned nothing usable.
  Future<int> generate(String input) async {
    final text = input.trim();
    if (text.isEmpty) {
      throw CardGenerationException('Paste some notes or name a topic first.');
    }
    // Read every sync dep BEFORE the first await (disposed-element safety).
    final claude = ref.read(claudeServiceProvider);
    if (claude == null) {
      throw CardGenerationException(
          'Add your AI key to generate cards — everything else works without it.');
    }
    final source = ref.read(vaultSourceProvider);
    if (source == null) {
      throw CardGenerationException(
          'Set up a study folder first, then generate cards into it.');
    }

    final today = (await ref.read(clockProvider.future)).today();
    final system = buildCardGenerationSystem(today: today);

    final String raw;
    try {
      raw = await claude.chat(
        system: system,
        model: _model,
        maxTokens: 2000,
        messages: [(role: 'user', content: text)],
      );
    } on ClaudeException catch (e) {
      throw CardGenerationException(e.message);
    }

    final batch = parseCardGenerationReply(raw).batch;
    if (batch == null || batch.cards.isEmpty) {
      throw CardGenerationException(
          "Couldn't generate cards from that — try rephrasing or adding a bit "
          'more detail.');
    }

    final count = await writeGeneratedCards(source, batch, sourceLabel: text);
    // Refresh Browse/study so the new drafts show up — but only if this element
    // is still mounted (a one-shot `generate` can outlive its autodispose
    // notifier across the network await).
    if (ref.mounted) ref.invalidate(vaultIndexProvider);
    return count;
  }
}
