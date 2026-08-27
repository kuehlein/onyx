// Material's `Card` widget collides with our domain `Card` model; we render
// with ListTile here, so hide the widget to keep the model unambiguous.
import 'package:flutter/material.dart' hide Card;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../shared/models/card.dart';
import '../../shared/providers/vault.dart';

/// Lists every indexed card, grouped by domain (tag). Read-only for now — the
/// detail view and section-level scheduling arrive with the study loop.
class BrowseScreen extends ConsumerWidget {
  const BrowseScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final index = ref.watch(vaultIndexProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Browse')),
      body: index.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _Message('Index error:\n$e'),
        data: (result) {
          if (result.cards.isEmpty) {
            return const _Message(
                'No cards indexed.\nConfigure a vault in Settings.');
          }
          final sorted = [...result.cards]
            ..sort((a, b) => a.title.toLowerCase().compareTo(
                  b.title.toLowerCase(),
                ));
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(vaultIndexProvider),
            child: ListView.separated(
              itemCount: sorted.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) => _CardTile(sorted[i]),
            ),
          );
        },
      ),
    );
  }
}

class _CardTile extends StatelessWidget {
  const _CardTile(this.card);

  final Card card;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isInterview = card.type == CardType.interviewQuestion;
    final sectionCount = card.quizzableSections.length;

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: isInterview
            ? theme.colorScheme.tertiaryContainer
            : theme.colorScheme.primaryContainer,
        child: Icon(
          isInterview ? Icons.forum_outlined : Icons.style_outlined,
          size: 20,
          color: isInterview
              ? theme.colorScheme.onTertiaryContainer
              : theme.colorScheme.onPrimaryContainer,
        ),
      ),
      title: Text(card.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        [
          if (card.domain != null) card.domain!,
          '$sectionCount quizzable',
        ].join(' · '),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: card.tiers.isEmpty
          ? null
          : Chip(
              label:
                  Text('T${card.tiers.values.reduce((a, b) => a < b ? a : b)}'),
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
      onTap: () => context.go('/browse/card/${card.id}'),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(text,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge),
        ),
      );
}
