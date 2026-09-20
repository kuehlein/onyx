// Material's `Card` widget collides with our domain `Card` model; we render
// with ListTile here, so hide the widget to keep the model unambiguous.
import 'package:flutter/material.dart' hide Card;
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/status_pill.dart';
import '../../shared/widgets/loading_view.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/search/card_filter.dart';
import '../../core/search/card_search.dart';
import '../../core/subject/active_subject.dart';
import '../../core/subject/subject_config.dart';
import '../../shared/design/onyx_design.dart';
import '../../shared/models/card.dart';
import '../../shared/providers/srs.dart';
import '../../shared/providers/vault.dart';
import '../editor/card_editor_screen.dart';
import '../generation/card_generation_sheet.dart';
import 'browse_filters.dart';
import 'import_deck_sheet.dart';

/// Maps a flow's [FlowSpec.iconKey] to a Browse icon (fallback: a generic card).
IconData flowIcon(String? key) => switch (key) {
      'flashcard' => Icons.style_outlined,
      'interview' => Icons.forum_outlined,
      'algorithm' => Icons.terminal_outlined,
      'systemDesign' => Icons.architecture_outlined,
      'behavioral' => Icons.record_voice_over_outlined,
      _ => Icons.style_outlined,
    };

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

  void _removeType(String t) => setState(() => _chipFilter =
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
      appBar: AppBar(
        title: const Text('Browse'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'New card',
            onPressed: () => showCardEditor(context),
          ),
          IconButton(
            icon: const Icon(Icons.auto_awesome_outlined),
            tooltip: 'Generate cards',
            onPressed: () => showCardGenerationSheet(context, ref),
          ),
          IconButton(
            icon: const Icon(Icons.download_outlined),
            tooltip: 'Import a deck',
            onPressed: () => showImportDeckSheet(context),
          ),
        ],
      ),
      body: index.when(
        loading: () => const LoadingView(),
        error: (e, _) => EmptyState(
            icon: Icons.error_outline, title: 'Index error', message: '$e'),
        data: (result) {
          if (result.cards.isEmpty) {
            return const EmptyState(
              icon: Icons.inbox_outlined,
              title: 'No cards indexed',
              message: 'Configure a vault in Settings.',
            );
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
          padding: const EdgeInsets.fromLTRB(
              Dim.space3, Dim.space2, Dim.space2, Dim.space2),
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
              ? const EmptyState(
                  icon: Icons.search_off,
                  title: 'No matches',
                  message: 'No cards match your search and filters.',
                )
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
        border: const OutlineInputBorder(borderRadius: Dim.brCard),
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
  final void Function(String) onRemoveType;
  final void Function(String) onRemoveDomain;
  final void Function(int) onRemoveTier;
  final void Function(MasteryFilter) onRemoveMastery;
  final VoidCallback onClear;

  // Height of the horizontal active-filter chip strip.
  static const _stripHeight = 44.0;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _stripHeight,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: Dim.space3),
        children: [
          for (final t in filter.types)
            _chip(context, activeSubject.flowForType(t)?.displayLabel ?? t,
                () => onRemoveType(t)),
          for (final d in filter.domains)
            _chip(context, d, () => onRemoveDomain(d)),
          for (final t in filter.tiers)
            _chip(context, 'Tier $t', () => onRemoveTier(t)),
          for (final m in filter.mastery)
            _chip(context, m.label, () => onRemoveMastery(m)),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: Dim.space2),
            child: TextButton(onPressed: onClear, child: const Text('Clear')),
          ),
        ],
      ),
    );
  }

  Widget _chip(BuildContext context, String label, VoidCallback onDeleted) =>
      Padding(
        padding: const EdgeInsets.only(
            right: Dim.space2, top: Dim.space1, bottom: Dim.space1),
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
        padding: const EdgeInsets.fromLTRB(
            Dim.space4, Dim.space1, Dim.space4, Dim.space2),
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
    // One flow lookup per tile; icon/hue/label come from its display keys so a
    // card reads the same everywhere (concept deck vs each practice track).
    final flow = activeSubject.flowForType(card.type);
    final color = SubjectColor.forKey(flow?.colorKey);
    final sectionCount = card.quizzableSections.length;

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: color.withValues(alpha: Dim.fill),
        child: Icon(flowIcon(flow?.iconKey), size: 20, color: color),
      ),
      title: Text(card.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      // Lead with the type label so same-titled cards are unambiguous even when
      // the line truncates (e.g. "Algorithm · ds-a" vs "Flashcard · ds-a"). A
      // draft (e.g. an imported deck's card) gets a calm muted pill so it reads
      // as "not counted yet".
      subtitle: Row(
        children: [
          if (card.isDraft) ...[
            const _DraftPill(),
            const SizedBox(width: Dim.space2),
          ],
          Expanded(
            child: Text(
              [
                flow?.displayLabel ?? card.type,
                if (card.domain != null) card.domain!,
                '$sectionCount quizzable',
              ].join(' · '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
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

/// A calm, muted "Draft" marker for cards not yet promoted (excluded from
/// scheduling + readiness). Deliberately low-key (the muted status tone, no
/// bright hue) — it signals "not counted yet", not an alert.
class _DraftPill extends StatelessWidget {
  const _DraftPill();

  @override
  Widget build(BuildContext context) => const StatusPill(
        tone: StatusTone.muted,
        label: 'Draft',
        dense: true,
      );
}
