// Material's `Card` widget collides with our domain `Card` model; we render
// with ListTile here, so hide the widget to keep the model unambiguous.
import 'package:flutter/material.dart' hide Card;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/search/card_filter.dart';
import '../../core/search/card_search.dart';
import '../../shared/models/card.dart';
import '../../shared/providers/srs.dart';
import '../../shared/providers/vault.dart';
import 'browse_filters.dart';

/// Browse: full-text search + composable filters over the indexed cards.
/// Search and filters combine; power users can also type operators
/// (`tag:`, `type:`, `tier:`, `is:`) — all documented in the help sheet.
class BrowseScreen extends ConsumerStatefulWidget {
  const BrowseScreen({super.key});

  @override
  ConsumerState<BrowseScreen> createState() => _BrowseScreenState();
}

class _BrowseScreenState extends ConsumerState<BrowseScreen> {
  final _controller = TextEditingController();
  String _query = '';
  CardFilter _chipFilter = const CardFilter();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _removeType(CardType t) => setState(() => _chipFilter =
      _chipFilter.copyWith(types: {..._chipFilter.types}..remove(t)));
  void _removeDomain(String d) => setState(() => _chipFilter =
      _chipFilter.copyWith(domains: {..._chipFilter.domains}..remove(d)));
  void _removeTier(int t) => setState(() => _chipFilter =
      _chipFilter.copyWith(tiers: {..._chipFilter.tiers}..remove(t)));
  void _removeMastery(MasteryFilter m) => setState(() => _chipFilter =
      _chipFilter.copyWith(mastery: {..._chipFilter.mastery}..remove(m)));

  @override
  Widget build(BuildContext context) {
    final index = ref.watch(vaultIndexProvider);
    final states = ref.watch(srsStatesProvider).asData?.value;

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
          return _body(result.cards, states);
        },
      ),
    );
  }

  Widget _body(List<Card> allCards, SectionStates? states) {
    final dueByKey = <String, DateTime>{
      if (states != null)
        for (final e in states.byKey.entries) e.key: e.value.dueAt,
    };
    final now = DateTime.now();

    final parsed = parseSearchQuery(_query.trim());
    final effective = _chipFilter.merge(parsed.filter);

    final filtered = [
      for (final c in allCards)
        if (matchesFilter(c, effective, cardMastery(c, dueByKey, now))) c,
    ];
    final List<Card> results;
    if (parsed.text.isEmpty) {
      results = [
        ...filtered
      ]..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    } else {
      results = searchCards(filtered, parsed.text);
    }

    final refining = _query.trim().isNotEmpty || !_chipFilter.isEmpty;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
          child: Row(
            children: [
              Expanded(
                child: _SearchField(
                  controller: _controller,
                  onChanged: (v) => setState(() => _query = v),
                  onClear: () {
                    _controller.clear();
                    setState(() => _query = '');
                  },
                ),
              ),
              _FilterButton(
                count: _chipFilter.activeFacetCount,
                onTap: () async {
                  final next = await showFilterSheet(
                    context,
                    current: _chipFilter,
                    domains: _availableDomains(allCards),
                    tiers: _availableTiers(allCards),
                  );
                  if (next != null) setState(() => _chipFilter = next);
                },
              ),
              IconButton(
                icon: const Icon(Icons.help_outline),
                tooltip: 'Search & filter help',
                onPressed: () => showSearchHelp(context),
              ),
            ],
          ),
        ),
        if (!_chipFilter.isEmpty)
          _ActiveFilters(
            filter: _chipFilter,
            onRemoveType: _removeType,
            onRemoveDomain: _removeDomain,
            onRemoveTier: _removeTier,
            onRemoveMastery: _removeMastery,
            onClear: () => setState(() => _chipFilter = const CardFilter()),
          ),
        if (refining)
          _ResultCount(count: results.length, total: allCards.length),
        Expanded(
          child: results.isEmpty
              ? const _Message('No cards match your search and filters.')
              : RefreshIndicator(
                  onRefresh: () async => ref.invalidate(vaultIndexProvider),
                  child: ListView.separated(
                    itemCount: results.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, i) => _CardTile(results[i]),
                  ),
                ),
        ),
      ],
    );
  }

  List<String> _availableDomains(List<Card> cards) {
    final set = <String>{
      for (final c in cards)
        if (c.domain != null) c.domain!,
    };
    return set.toList()..sort();
  }

  List<int> _availableTiers(List<Card> cards) {
    final set = <int>{for (final c in cards) ...c.tiers.values};
    return set.toList()..sort();
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
    return TextField(
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
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

class _FilterButton extends StatelessWidget {
  const _FilterButton({required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Badge.count(
      count: count,
      isLabelVisible: count > 0,
      child: IconButton(
        icon: const Icon(Icons.tune),
        tooltip: 'Filters',
        onPressed: onTap,
      ),
    );
  }
}

/// The currently-applied chip filters as removable chips, with a "Clear all".
class _ActiveFilters extends StatelessWidget {
  const _ActiveFilters({
    required this.filter,
    required this.onRemoveType,
    required this.onRemoveDomain,
    required this.onRemoveTier,
    required this.onRemoveMastery,
    required this.onClear,
  });

  final CardFilter filter;
  final void Function(CardType) onRemoveType;
  final void Function(String) onRemoveDomain;
  final void Function(int) onRemoveTier;
  final void Function(MasteryFilter) onRemoveMastery;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: [
          for (final t in filter.types)
            _chip(context, t.label, () => onRemoveType(t)),
          for (final d in filter.domains)
            _chip(context, d, () => onRemoveDomain(d)),
          for (final t in filter.tiers)
            _chip(context, 'Tier $t', () => onRemoveTier(t)),
          for (final m in filter.mastery)
            _chip(context, m.label, () => onRemoveMastery(m)),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: TextButton(onPressed: onClear, child: const Text('Clear')),
          ),
        ],
      ),
    );
  }

  Widget _chip(BuildContext context, String label, VoidCallback onDeleted) =>
      Padding(
        padding: const EdgeInsets.only(right: 8, top: 4, bottom: 4),
        child: InputChip(
          label: Text(label),
          onDeleted: onDeleted,
          visualDensity: VisualDensity.compact,
        ),
      );
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
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
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
