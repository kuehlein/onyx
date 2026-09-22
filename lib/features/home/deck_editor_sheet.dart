import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/deck/deck.dart';
import '../../shared/design/onyx_design.dart';
import '../../shared/providers/decks.dart';
import '../../shared/providers/template.dart';
import '../../shared/widgets/sheet_header.dart';

/// Create or edit a [Deck] (task #30d, G6) — name, template, membership
/// query, deadline, and budget weight, plus graduate/delete for an existing goal.
/// This is the in-app path to defining the concurrent goals the lanes hub shows.
Future<void> showDeckEditor(BuildContext context, {Deck? goal}) =>
    showOnyxSheet<void>(
      context,
      builder: (_) => DeckEditorSheet(goal: goal),
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
        TagMembership(:final tag) => '#$tag',
        FolderMembership(:final path) => '$path/',
        _ => 'Whole vault',
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
  const DeckEditorSheet({super.key, this.goal});

  final Deck? goal;

  @override
  ConsumerState<DeckEditorSheet> createState() => _GoalEditorSheetState();
}

enum _Kind { all, tag, folder }

class _GoalEditorSheetState extends ConsumerState<DeckEditorSheet> {
  late final TextEditingController _name =
      TextEditingController(text: widget.goal?.name ?? '');
  late final TextEditingController _value = TextEditingController(
      text: switch (widget.goal?.membership) {
    TagMembership(:final tag) => tag,
    FolderMembership(:final path) => path,
    _ => '',
  });
  late String? _templateId = widget.goal?.templateId;
  late _Kind _kind = switch (widget.goal?.membership) {
    TagMembership() => _Kind.tag,
    FolderMembership() => _Kind.folder,
    _ => _Kind.all,
  };
  late DateTime? _deadline = widget.goal?.deadline;
  late double _weight = widget.goal?.budgetWeight ?? 1.0;

  @override
  void dispose() {
    _name.dispose();
    _value.dispose();
    super.dispose();
  }

  bool get _valid =>
      _name.text.trim().isNotEmpty &&
      (_kind == _Kind.all || _value.text.trim().isNotEmpty);

  static String _slug(String s) => s
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');

  void _save() {
    final name = _name.text.trim();
    final value = _value.text.trim();
    final membership = switch (_kind) {
      _Kind.all => const AllCards(),
      _Kind.tag => TagMembership(value),
      _Kind.folder => FolderMembership(value),
    };
    final existing = widget.goal;
    // Editing must PRESERVE everything not on this form — the deck's aims and its
    // readiness knobs — via copyWith. Rebuilding a fresh Deck (the old bug) silently
    // wiped them on every edit. Only a brand-new deck is constructed from scratch.
    final deck = existing == null
        ? Deck(
            id: _slug(name).isEmpty ? 'deck' : _slug(name),
            name: name,
            templateId: _templateId ?? '',
            membership: membership,
            deadline: _deadline,
            budgetWeight: _weight,
          )
        : existing.copyWith(
            name: name,
            templateId: _templateId ?? '',
            membership: membership,
            deadline: _deadline,
            budgetWeight: _weight,
          );
    ref.read(decksProvider.notifier).upsert(deck);
    Navigator.of(context).pop();
  }

  Future<void> _pickDeadline() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _deadline ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 6),
    );
    if (picked != null) setState(() => _deadline = picked);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final existing = widget.goal;
    final templates =
        ref.watch(templateRegistryProvider).asData?.value.templates ?? const [];
    _templateId ??= templates.isEmpty ? null : templates.first.id;

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
                ],
                selected: {_kind},
                onSelectionChanged: (s) => setState(() => _kind = s.first),
              ),
              if (_kind != _Kind.all) ...[
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
              const SizedBox(height: Dim.space5),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.event_outlined),
                title: Text(_deadline == null
                    ? 'No deadline'
                    : 'Due ${_deadline!.year}-${_deadline!.month.toString().padLeft(2, '0')}-${_deadline!.day.toString().padLeft(2, '0')}'),
                trailing: _deadline == null
                    ? TextButton(
                        onPressed: _pickDeadline, child: const Text('Set'))
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        tooltip: 'Clear deadline',
                        onPressed: () => setState(() => _deadline = null),
                      ),
                onTap: _pickDeadline,
              ),
              const SizedBox(height: Dim.space2),
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
