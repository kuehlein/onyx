import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/deck/deck.dart';
import '../../core/search/card_filter.dart' show parseLens, renderLens;
import '../../shared/design/onyx_design.dart';
import '../../shared/providers/decks.dart';
import '../../shared/providers/template.dart';
import '../../shared/widgets/sheet_header.dart';

/// Create or edit a [Deck] (task #30d, G6) — name, template, membership
/// query, and budget weight, plus graduate/delete for an existing goal.
/// This is the in-app path to defining the concurrent goals the lanes hub shows.
///
/// [initialMembership] pre-fills the lens of a NEW deck (Browse's "save as deck",
/// G3.1) — a complex query lands in the Advanced text field. [note] shows a muted
/// info line above the form (e.g. that a Browse text search isn't part of a lens).
Future<void> showDeckEditor(
  BuildContext context, {
  Deck? goal,
  CardQuery? initialMembership,
  String? note,
}) =>
    showOnyxSheet<void>(
      context,
      builder: (_) => DeckEditorSheet(
        goal: goal,
        initialMembership: initialMembership,
        note: note,
      ),
    );

/// A compact manager for all study goals — tap one to edit, or add a new one.
/// The reachable-from-anywhere entry (Settings) so a single-goal user can define
/// a second goal (which surfaces the lanes hub).
Future<void> showDecksManager(BuildContext context) => showOnyxSheet<void>(
      context,
      builder: (_) => const _GoalsManagerSheet(),
    );

class _GoalsManagerSheet extends ConsumerWidget {
  const _GoalsManagerSheet();

  static String _membership(Deck g) => switch (g.membership) {
        Everything() => 'Whole vault',
        TagIs(:final tag) => '#$tag',
        FolderUnder(:final path) => '$path/',
        _ => renderLens(g.membership), // a complex lens → its query text
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goals = ref.watch(decksProvider).asData?.value ?? const [];
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SheetHeader(title: 'Decks', icon: Icons.flag_outlined),
        SheetScrollBody(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final g in goals)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(g.name),
                  subtitle: Text(
                    '${_membership(g)}'
                    '${g.state == DeckState.paused ? ' · paused' : ''}'
                    '${g.state == DeckState.graduated ? ' · graduated' : ''}',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => showDeckEditor(context, goal: g),
                ),
              const Divider(),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.add_circle_outline),
                title: const Text('New deck'),
                onTap: () => showDeckEditor(context),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class DeckEditorSheet extends ConsumerStatefulWidget {
  const DeckEditorSheet({
    super.key,
    this.goal,
    this.initialMembership,
    this.note,
  });

  final Deck? goal;
  final CardQuery? initialMembership;
  final String? note;

  @override
  ConsumerState<DeckEditorSheet> createState() => _GoalEditorSheetState();
}

/// The lens-builder mode. `all`/`tag`/`folder` are the simple, tap-first defaults;
/// `advanced` reveals the full query text form (ADR-0013 §Addendum, hybrid builder).
enum _Kind { all, tag, folder, advanced }

class _GoalEditorSheetState extends ConsumerState<DeckEditorSheet> {
  // The membership to seed the form from — an existing deck's, a save-as-deck
  // hand-off, or the whole vault.
  late final CardQuery _seed = widget.goal?.membership ??
      widget.initialMembership ??
      CardQuery.everything;
  late final TextEditingController _name =
      TextEditingController(text: widget.goal?.name ?? '');
  late final TextEditingController _value = TextEditingController(
      text: switch (_seed) {
    TagIs(:final tag) => tag,
    FolderUnder(:final path) => path,
    _ => '',
  });
  // A lens the simple radio can't express (And/Or/Not/type/tier/…) opens directly
  // in Advanced, pre-filled with its query text.
  late _Kind _kind = switch (_seed) {
    Everything() => _Kind.all,
    TagIs() => _Kind.tag,
    FolderUnder() => _Kind.folder,
    _ => _Kind.advanced,
  };
  late final TextEditingController _lensText = TextEditingController(
      text: _kind == _Kind.advanced ? renderLens(_seed) : '');
  late String? _templateId = widget.goal?.templateId;
  late double _weight = widget.goal?.budgetWeight ?? 1.0;
  // The existing decks — watched in [build] so a new deck's id can dodge a
  // collision (see [_uniqueId]); reading it unwatched risks an unresolved future.
  List<Deck> _decks = const [];

  @override
  void dispose() {
    _name.dispose();
    _value.dispose();
    _lensText.dispose();
    super.dispose();
  }

  bool get _valid {
    if (_name.text.trim().isEmpty) return false;
    return switch (_kind) {
      _Kind.all => true,
      _Kind.tag || _Kind.folder => _value.text.trim().isNotEmpty,
      _Kind.advanced => _lensText.text.trim().isNotEmpty,
    };
  }

  /// The membership the form currently expresses (before persistence). Advanced
  /// parses the text form; the simple kinds map to a single leaf.
  CardQuery _membershipFor(_Kind kind) => switch (kind) {
        _Kind.all => CardQuery.everything,
        _Kind.tag => TagIs(_value.text.trim()),
        _Kind.folder => FolderUnder(_value.text.trim()),
        _Kind.advanced => parseLens(_lensText.text.trim()),
      };

  static String _slug(String s) => s
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');

  /// A deck id unique among [taken] — `upsert` keys by id, so a colliding slug
  /// would overwrite a different deck. Auto-suffix (`korean`, `korean-2`, …).
  static String _uniqueId(String base, Set<String> taken) {
    final root = base.isEmpty ? 'deck' : base;
    if (!taken.contains(root)) return root;
    var n = 2;
    while (taken.contains('$root-$n')) {
      n++;
    }
    return '$root-$n';
  }

  void _save() {
    final name = _name.text.trim();
    // Belt-and-suspenders: a lens is STRUCTURAL — strip any StateIs (e.g. an
    // `is:due` typed into Advanced), which Deck.select can't evaluate (ADR-0013).
    final membership = stripDynamic(_membershipFor(_kind));
    final existing = widget.goal;
    // Editing must PRESERVE everything not on this form — the deck's aims and its
    // readiness knobs — via copyWith. Rebuilding a fresh Deck (the old bug) silently
    // wiped them on every edit. Only a brand-new deck is constructed from scratch.
    final Deck deck;
    if (existing == null) {
      final taken = {for (final g in _decks) g.id};
      deck = Deck(
        id: _uniqueId(_slug(name), taken),
        name: name,
        templateId: _templateId ?? '',
        membership: membership,
        budgetWeight: _weight,
      );
    } else {
      deck = existing.copyWith(
        name: name,
        templateId: _templateId ?? '',
        membership: membership,
        budgetWeight: _weight,
      );
    }
    ref.read(decksProvider.notifier).upsert(deck);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final existing = widget.goal;
    final templates =
        ref.watch(templateRegistryProvider).asData?.value.templates ?? const [];
    _templateId ??= templates.isEmpty ? null : templates.first.id;
    _decks = ref.watch(decksProvider).asData?.value ?? const [];

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SheetHeader(
          title: existing == null ? 'New deck' : 'Edit deck',
          icon: Icons.flag_outlined,
        ),
        SheetScrollBody(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (widget.note != null) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline,
                        size: Dim.iconSm,
                        color: theme.colorScheme.onSurfaceVariant),
                    const SizedBox(width: Dim.space2),
                    Expanded(
                      child: Text(widget.note!,
                          style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant)),
                    ),
                  ],
                ),
                const SizedBox(height: Dim.space4),
              ],
              TextField(
                controller: _name,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  hintText: 'e.g. Korean, Calculus 101, Saints debate',
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: Dim.space4),
              if (templates.length > 1) ...[
                DropdownButtonFormField<String>(
                  initialValue: _templateId,
                  decoration: const InputDecoration(labelText: 'Template'),
                  items: [
                    for (final t in templates)
                      DropdownMenuItem(value: t.id, child: Text(t.id)),
                  ],
                  onChanged: (v) => setState(() => _templateId = v),
                ),
                const SizedBox(height: Dim.space4),
              ],
              Text('Which cards', style: theme.textTheme.labelLarge),
              const SizedBox(height: Dim.space2),
              SegmentedButton<_Kind>(
                segments: const [
                  ButtonSegment(value: _Kind.all, label: Text('Whole vault')),
                  ButtonSegment(value: _Kind.tag, label: Text('Tag')),
                  ButtonSegment(value: _Kind.folder, label: Text('Folder')),
                  ButtonSegment(value: _Kind.advanced, label: Text('Advanced')),
                ],
                selected: {_kind},
                // Switching to Advanced seeds the text with the simple pick's
                // query form, so nothing is lost revealing the underlying lens.
                onSelectionChanged: (s) => setState(() {
                  final next = s.first;
                  if (next == _Kind.advanced && _lensText.text.trim().isEmpty) {
                    _lensText.text = renderLens(_membershipFor(_kind));
                  }
                  _kind = next;
                }),
              ),
              if (_kind == _Kind.tag || _kind == _Kind.folder) ...[
                const SizedBox(height: Dim.space3),
                TextField(
                  controller: _value,
                  decoration: InputDecoration(
                    labelText: _kind == _Kind.tag ? 'Tag' : 'Folder path',
                    hintText: _kind == _Kind.tag
                        ? 'e.g. intercession (no #)'
                        : 'e.g. Math/Calculus/101',
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ],
              if (_kind == _Kind.advanced) ...[
                const SizedBox(height: Dim.space3),
                TextField(
                  controller: _lensText,
                  maxLines: null,
                  decoration: const InputDecoration(
                    labelText: 'Query',
                    hintText:
                        'e.g. tags:korean OR folder:korean/  -tags:archived',
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: Dim.space1),
                Text(
                  'Operators: tags: · type: · tier: · folder:  ·  '
                  'combine with OR, group with ( ), exclude with -',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
              const SizedBox(height: Dim.space5),
              Text('Share of daily time  ·  ${_weight.toStringAsFixed(1)}×',
                  style: theme.textTheme.labelLarge),
              Slider(
                value: _weight,
                min: 0.5,
                max: 3,
                divisions: 5,
                label: '${_weight.toStringAsFixed(1)}×',
                onChanged: (v) => setState(() => _weight = v),
              ),
              const SizedBox(height: Dim.space3),
              FilledButton(
                onPressed: _valid ? _save : null,
                child: Text(existing == null ? 'Create deck' : 'Save'),
              ),
              if (existing != null) ...[
                const SizedBox(height: Dim.space2),
                Row(
                  children: [
                    Expanded(
                      child: TextButton.icon(
                        icon: const Icon(Icons.check_circle_outline),
                        label: const Text('Graduate'),
                        onPressed: () {
                          ref.read(decksProvider.notifier).upsert(
                              existing.copyWith(state: DeckState.graduated));
                          Navigator.of(context).pop();
                        },
                      ),
                    ),
                    Expanded(
                      child: TextButton.icon(
                        icon: const Icon(Icons.delete_outline),
                        style: TextButton.styleFrom(
                            foregroundColor: theme.colorScheme.error),
                        label: const Text('Delete'),
                        onPressed: () {
                          ref.read(decksProvider.notifier).remove(existing.id);
                          Navigator.of(context).pop();
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
