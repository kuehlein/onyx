import 'package:flutter/material.dart';

import '../../core/search/card_filter.dart';
import '../../shared/models/card.dart';

/// Opens the filter sheet. Returns the chosen filter, or null if dismissed
/// without applying (the caller keeps its current filter).
Future<CardFilter?> showFilterSheet(
  BuildContext context, {
  required CardFilter current,
  required List<String> domains,
  required List<int> tiers,
}) =>
    showModalBottomSheet<CardFilter>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) =>
          _FilterSheet(current: current, domains: domains, tiers: tiers),
    );

class _FilterSheet extends StatefulWidget {
  const _FilterSheet({
    required this.current,
    required this.domains,
    required this.tiers,
  });

  final CardFilter current;
  final List<String> domains;
  final List<int> tiers;

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late Set<CardType> _types = {...widget.current.types};
  late Set<String> _domains = {...widget.current.domains};
  late Set<int> _tiers = {...widget.current.tiers};
  late Set<MasteryFilter> _mastery = {...widget.current.mastery};

  bool get _empty =>
      _types.isEmpty && _domains.isEmpty && _tiers.isEmpty && _mastery.isEmpty;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Filters', style: theme.textTheme.titleLarge),
                const Spacer(),
                TextButton(
                  onPressed: _empty
                      ? null
                      : () => setState(() {
                            _types = {};
                            _domains = {};
                            _tiers = {};
                            _mastery = {};
                          }),
                  child: const Text('Clear all'),
                ),
              ],
            ),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _group<CardType>(
                      'Type',
                      CardType.values,
                      _types,
                      (v) => v.label,
                    ),
                    if (widget.domains.isNotEmpty)
                      _group<String>(
                        'Domain',
                        widget.domains,
                        _domains,
                        (v) => v,
                      ),
                    if (widget.tiers.isNotEmpty)
                      _group<int>(
                        'Tier',
                        widget.tiers,
                        _tiers,
                        (v) => 'T$v',
                      ),
                    _group<MasteryFilter>(
                      'Study state',
                      MasteryFilter.values,
                      _mastery,
                      (v) => v.label,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(CardFilter(
                  types: _types,
                  domains: _domains,
                  tiers: _tiers,
                  mastery: _mastery,
                )),
                child: const Text('Apply'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _group<T>(
    String label,
    List<T> values,
    Set<T> selected,
    String Function(T) labelOf,
  ) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: theme.textTheme.labelLarge
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final v in values)
                FilterChip(
                  label: Text(labelOf(v)),
                  selected: selected.contains(v),
                  onSelected: (on) => setState(() {
                    if (on) {
                      selected.add(v);
                    } else {
                      selected.remove(v);
                    }
                  }),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Opens the search & filter help sheet — documents free-text search, the query
/// operators, and the filter facets. Tucked behind the app-bar "?" so it never
/// obstructs Browse, but roomy enough to actually explain everything.
Future<void> showSearchHelp(BuildContext context) => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _SearchHelpSheet(),
    );

class _SearchHelpSheet extends StatelessWidget {
  const _SearchHelpSheet();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Searching & filtering', style: theme.textTheme.titleLarge),
              const SizedBox(height: 16),
              const _Heading('Type to search'),
              const _Body(
                  'Matches the title, tags, section headings, and body. '
                  'Results are ranked by relevance — a title match beats a '
                  'body match. Multiple words must all match (AND).'),
              const SizedBox(height: 16),
              const _Heading('Power operators'),
              const _Body('Mix these into the search box alongside words:'),
              const SizedBox(height: 8),
              const _Op('tag:ds-a', 'Only this domain (also domain:)'),
              const _Op(
                  'type:interview', 'Interview questions (or type:flashcard)'),
              const _Op('tier:1', 'Cards at this tier (1 = most foundational)'),
              const _Op('is:due', 'Study state: is:new · is:due · is:strong'),
              const SizedBox(height: 10),
              const _Example('trees tag:ds-a is:due'),
              const SizedBox(height: 16),
              const _Heading('Filter button'),
              const _Body(
                  'The ⚙ button offers the same facets as tappable chips — '
                  'Type, Domain, Tier, and Study state. Filters and operators '
                  'combine, and active filters show as chips you can remove.'),
              const SizedBox(height: 16),
              const _Heading('Study state'),
              const _Body('New — not studied yet · Due — ready to review now · '
                  'Strong — reviewed and scheduled ahead.'),
            ],
          ),
        ),
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);
  final String text;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(text,
        style: theme.textTheme.titleSmall
            ?.copyWith(color: theme.colorScheme.primary));
  }
}

class _Body extends StatelessWidget {
  const _Body(this.text);
  final String text;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(text, style: theme.textTheme.bodyMedium),
    );
  }
}

class _Op extends StatelessWidget {
  const _Op(this.code, this.desc);
  final String code;
  final String desc;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Code(code),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(desc, style: theme.textTheme.bodyMedium),
            ),
          ),
        ],
      ),
    );
  }
}

class _Example extends StatelessWidget {
  const _Example(this.code);
  final String code;
  @override
  Widget build(BuildContext context) =>
      Row(children: [const Text('e.g. '), _Code(code)]);
}

class _Code extends StatelessWidget {
  const _Code(this.text);
  final String text;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(text,
          style: theme.textTheme.bodySmall?.copyWith(
              fontFamily: 'monospace', color: theme.colorScheme.onSurface)),
    );
  }
}
