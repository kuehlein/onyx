// Material's `Card` widget collides with our domain `Card` model; we render
// with ListTile here, so hide the widget to keep the model unambiguous.
import 'package:flutter/material.dart' hide Card;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/search/card_search.dart';
import '../../shared/models/card.dart';
import '../../shared/providers/vault.dart';

/// Lists every indexed card with a full-text search box. With no query, cards
/// are listed alphabetically; with a query, they're filtered and ranked by
/// relevance (title > tags/headings > body).
class BrowseScreen extends ConsumerStatefulWidget {
  const BrowseScreen({super.key});

  @override
  ConsumerState<BrowseScreen> createState() => _BrowseScreenState();
}

class _BrowseScreenState extends ConsumerState<BrowseScreen> {
  final _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
          final query = _query.trim();
          final List<Card> cards;
          if (query.isEmpty) {
            cards = [...result.cards]..sort((a, b) =>
                a.title.toLowerCase().compareTo(b.title.toLowerCase()));
          } else {
            cards = searchCards(result.cards, query);
          }

          return Column(
            children: [
              _SearchField(
                controller: _controller,
                onChanged: (v) => setState(() => _query = v),
                onClear: () {
                  _controller.clear();
                  setState(() => _query = '');
                },
              ),
              if (query.isNotEmpty)
                _ResultCount(count: cards.length, total: result.cards.length),
              Expanded(
                child: cards.isEmpty
                    ? _Message('No cards match “$query”.')
                    : RefreshIndicator(
                        onRefresh: () async =>
                            ref.invalidate(vaultIndexProvider),
                        child: ListView.separated(
                          itemCount: cards.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, i) => _CardTile(cards[i]),
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: 'Search cards…',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: controller.text.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: 'Clear',
                  onPressed: onClear,
                ),
          isDense: true,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}

class _ResultCount extends StatelessWidget {
  const _ResultCount({required this.count, required this.total});

  final int count;
  final int total;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        child: Text(
          '$count of $total ${total == 1 ? 'card' : 'cards'}',
          style: theme.textTheme.labelMedium
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
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
