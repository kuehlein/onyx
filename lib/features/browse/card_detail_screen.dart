// Material's `Card` widget collides with our domain `Card` model.
import 'package:flutter/material.dart' hide Card;
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/models/card.dart';
import '../../shared/providers/vault.dart';

/// Read-only view of a single card: its overview plus each H2 section rendered
/// as Markdown. Reached from Browse; the card is looked up in the live index by
/// id (the stable key), so it survives filename changes.
class CardDetailScreen extends ConsumerWidget {
  const CardDetailScreen({super.key, required this.cardId});

  final String cardId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final index = ref.watch(vaultIndexProvider);

    return index.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: Center(
            child: Text('Index error:\n$e', textAlign: TextAlign.center)),
      ),
      data: (result) {
        Card? card;
        for (final c in result.cards) {
          if (c.id == cardId) {
            card = c;
            break;
          }
        }
        if (card == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Not found')),
            body: const Center(
                child: Text('This card is no longer in the vault.')),
          );
        }
        return _CardDetail(card);
      },
    );
  }
}

class _CardDetail extends StatelessWidget {
  const _CardDetail(this.card);

  final Card card;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isInterview = card.type == CardType.interviewQuestion;

    return Scaffold(
      appBar: AppBar(title: Text(card.title)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              _MetaChip(
                icon: isInterview ? Icons.forum_outlined : Icons.style_outlined,
                label: isInterview ? 'Interview question' : 'Flashcard',
              ),
              if (card.domain != null) _MetaChip(label: card.domain!),
              for (final entry in card.tiers.entries)
                _MetaChip(label: '${entry.key} · T${entry.value}'),
            ],
          ),
          if (card.overview.isNotEmpty) ...[
            const SizedBox(height: 16),
            MarkdownBody(data: card.overview),
          ],
          for (final section in card.sections) ...[
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child:
                      Text(section.heading, style: theme.textTheme.titleMedium),
                ),
                if (section.quizzable)
                  Tooltip(
                    message: 'Scheduled for review',
                    child: Icon(Icons.check_circle_outline,
                        size: 18, color: theme.colorScheme.primary),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            MarkdownBody(data: section.content),
          ],
        ],
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.label, this.icon});

  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: icon == null ? null : Icon(icon, size: 16),
      label: Text(label),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}
