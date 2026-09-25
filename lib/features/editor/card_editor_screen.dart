// Material's `Card` widget collides with our domain `Card` model.
import 'package:flutter/material.dart' hide Card;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/vault/card_edit.dart';
import '../../core/vault/card_parser.dart';
import '../../shared/design/onyx_design.dart';
import '../../shared/models/card.dart';
import '../../shared/providers/srs.dart';
import '../../shared/providers/vault.dart';
import '../../shared/widgets/card_markdown.dart';
import '../../shared/widgets/fading_scroll_edges.dart';

/// In-app card creation + editing (task #28). A full-screen form (not a cramped
/// sheet): Title, Body (raw markdown — overview + `## ` sections), and Tags
/// (comma-separated). A Preview toggle renders the result via [CardMarkdown].
///
/// The safety-critical edit path (frontmatter is never lost) lives in
/// `card_edit.dart`; this screen only gathers the title/body/tags and calls
/// [saveCardEdit] / [createCard]. On CREATE a card enters as `active` (trusted);
/// on EDIT the file's frontmatter — including `status` — is preserved, so a draft
/// stays a draft (that's what makes the review gate's Edit work).

/// The learner's choice when an edit renames/removes a studied section.
enum _SectionEdit { keep, reset }

/// Pushes [CardEditorScreen] full-screen. [card] null → create; non-null → edit.
/// [initialTitle] seeds the title on create (e.g. a stub's de-slugged target);
/// [createSlug] forces the new file's stem/id on create (a stub passes the broken
/// link's target so `[[target]]` resolves on re-index). Returns true if saved.
Future<bool> showCardEditor(
  BuildContext context, {
  Card? card,
  String? initialTitle,
  String? createSlug,
}) async {
  final saved = await Navigator.of(context).push<bool>(
    MaterialPageRoute(
      builder: (_) => CardEditorScreen(
          card: card, initialTitle: initialTitle, createSlug: createSlug),
    ),
  );
  return saved ?? false;
}

class CardEditorScreen extends ConsumerStatefulWidget {
  const CardEditorScreen(
      {super.key, this.card, this.initialTitle, this.createSlug});

  /// The card being edited, or null when creating a new one.
  final Card? card;

  /// Seeds the title on create (a stub's de-slugged target).
  final String? initialTitle;

  /// Forces the new file's stem/id on create so a stub's `[[target]]` resolves.
  final String? createSlug;

  @override
  ConsumerState<CardEditorScreen> createState() => _CardEditorScreenState();
}

class _CardEditorScreenState extends ConsumerState<CardEditorScreen> {
  late final TextEditingController _title;
  late final TextEditingController _body;
  late final TextEditingController _tags;

  bool _preview = false;
  bool _saving = false;
  String? _warning;

  bool get _isEdit => widget.card != null;

  @override
  void initState() {
    super.initState();
    final card = widget.card;
    _title =
        TextEditingController(text: card?.title ?? widget.initialTitle ?? '');
    _tags = TextEditingController(text: (card?.tags ?? const []).join(', '));
    // On create, seed a body template so the new card is quizzable out of the
    // box. On edit, seed the raw body sliced from the file (exact round-trip of
    // what the user last wrote), falling back to a rebuild from parsed sections.
    _body = TextEditingController(
      text: _isEdit ? '' : '## Answer\n\n',
    );
    if (_isEdit) _seedBodyFromFile();
  }

  /// Re-reads the card's file and slices the body after the H1 so the editor
  /// shows exactly what's on disk. Falls back to reconstructing from the parsed
  /// overview + sections if the read fails.
  Future<void> _seedBodyFromFile() async {
    final source = ref.read(vaultSourceProvider);
    final card = widget.card!;
    String? body;
    if (source != null) {
      try {
        final raw = await source.readCard(card.filePath);
        body = _bodyAfterH1(raw);
      } catch (_) {
        body = null;
      }
    }
    body ??= _bodyFromCard(card);
    if (mounted) _body.text = body;
  }

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    _tags.dispose();
    super.dispose();
  }

  List<String> get _parsedTags => [
        for (final t in _tags.text.split(','))
          if (t.trim().isNotEmpty) t.trim(),
      ];

  Future<void> _save() async {
    if (_saving) return;
    final title = _title.text.trim();
    final body = _body.text.trim();
    if (title.isEmpty) {
      setState(() => _warning = 'Give the card a title.');
      return;
    }
    // Require at least one `## ` section so the card is quizzable — a titled card
    // with no section can never be scheduled for review.
    if (!_hasSection(body)) {
      setState(() => _warning =
          'Add a ## section (e.g. "## Answer") so it can be quizzed.');
      return;
    }

    final source = ref.read(vaultSourceProvider);
    if (source == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Set up a folder first.')),
      );
      return;
    }

    setState(() {
      _saving = true;
      _warning = null;
    });
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      if (_isEdit) {
        // Keep the FSRS schedule aligned with any renamed/removed studied section
        // BEFORE the file write re-indexes new slugs (ADR-0012 edit-identity).
        if (!await _reconcileSectionEdits(body)) {
          if (mounted) setState(() => _saving = false);
          return; // user cancelled at the keep-vs-reset prompt
        }
        await saveCardEdit(
          source,
          widget.card!.filePath,
          title: title,
          body: body,
          tags: _parsedTags,
        );
        ref.invalidate(srsStatesProvider);
      } else {
        await createCard(source,
            title: title,
            body: body,
            tags: _parsedTags,
            slug: widget.createSlug);
      }
      ref.invalidate(vaultIndexProvider);
      navigator.pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      messenger.showSnackBar(
        SnackBar(content: Text('Could not save the card: $e')),
      );
    }
  }

  Future<void> _delete() async {
    final card = widget.card;
    final source = ref.read(vaultSourceProvider);
    if (card == null || source == null) return;
    // Capture before the dialog + delete awaits so we don't touch `context`
    // across the async gap.
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this card?'),
        content: Text(
          'This removes “${card.title}” from your folder. This can\'t be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(ctx).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await deleteCardFile(source, card.filePath);
      ref.invalidate(vaultIndexProvider);
      navigator.pop(true);
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Could not delete the card: $e')),
      );
    }
  }

  /// Before an edit's file write, keep the FSRS schedule aligned with any renamed
  /// or removed STUDIED section (ADR-0012 edit-identity). Slug-unchanged edits
  /// (typos, body fixes) are silent. On a material change, prompt keep-vs-reset:
  /// KEEP rekeys the schedule across the rename (+ prunes removed orphans); RESET
  /// drops it so the section re-learns. Returns false ONLY if the user cancels
  /// (abort the save) — never a silent reset.
  Future<bool> _reconcileSectionEdits(String body) async {
    final card = widget.card!;
    final delta = sectionSlugDelta(
      [for (final s in card.sections) s.slug],
      [for (final h in _sectionHeadings(body)) CardParser.slugify(h)],
    );
    if (delta.lost.isEmpty) return true; // no slug dropped → silent keep

    final repo = ref.read(srsRepositoryProvider);
    final states = await repo.loadStates();
    bool studied(String slug) => states.containsKey('${card.id}::$slug');
    final lostStudied = [
      for (final s in delta.lost)
        if (studied(s)) s,
    ];
    if (lostStudied.isEmpty) return true; // only unstudied sections changed

    if (!mounted) return false;
    final headingBySlug = {for (final s in card.sections) s.slug: s.heading};
    final choice = await _confirmSectionEdit(
        [for (final s in lostStudied) headingBySlug[s] ?? s]);
    if (choice == null) return false; // cancelled

    if (choice == _SectionEdit.keep) {
      for (final r in delta.renames) {
        if (studied(r.from)) {
          await repo.renameSection(
              cardId: card.id, oldSlug: r.from, newSlug: r.to);
        }
      }
      for (final s in delta.removed) {
        if (studied(s)) await repo.dropSection(cardId: card.id, slug: s);
      }
    } else {
      for (final s in lostStudied) {
        await repo.dropSection(cardId: card.id, slug: s);
      }
    }
    return true;
  }

  /// The keep-vs-reset prompt for a material section edit. Returns [_SectionEdit]
  /// or null (cancel). Keep is the recommended default (a rename usually keeps the
  /// same question); Reset is for when the answer itself changed.
  Future<_SectionEdit?> _confirmSectionEdit(List<String> headings) {
    final list = headings.join('”, “');
    final plural = headings.length == 1 ? '' : 's';
    return showDialog<_SectionEdit>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Keep review history?'),
        content: Text(
          'You renamed or removed section$plural you\'ve studied (“$list”). Keep '
          'their review schedule, or reset it if the answer itself changed?',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, _SectionEdit.reset),
            child: const Text('Reset'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, _SectionEdit.keep),
            child: const Text('Keep'),
          ),
        ],
      ),
    );
  }

  /// The `## ` headings in [body], fence-aware (mirrors [_hasSection]) — the
  /// source of the edit's new section slugs.
  List<String> _sectionHeadings(String body) {
    final fence = RegExp(r'^[ \t]*(```|~~~)');
    final h2 = RegExp(r'^##[ \t]+(.+?)[ \t]*$');
    final out = <String>[];
    var inFence = false;
    for (final line in body.split('\n')) {
      if (fence.hasMatch(line)) {
        inFence = !inFence;
        continue;
      }
      if (!inFence) {
        final m = h2.firstMatch(line);
        if (m != null) out.add(m.group(1)!);
      }
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Edit card' : 'New card'),
        actions: [
          IconButton(
            icon: Icon(
                _preview ? Icons.edit_outlined : Icons.visibility_outlined),
            tooltip: _preview ? 'Edit' : 'Preview',
            onPressed: () => setState(() => _preview = !_preview),
          ),
          TextButton(
            onPressed: _saving ? null : _save,
            child: Text(_saving ? 'Saving…' : 'Save'),
          ),
          if (_isEdit)
            PopupMenuButton<String>(
              onSelected: (v) {
                if (v == 'delete') _delete();
              },
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline,
                          size: Dim.iconMd, color: theme.colorScheme.error),
                      const SizedBox(width: Dim.space3),
                      Text('Delete',
                          style: TextStyle(color: theme.colorScheme.error)),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: Dim.maxContentWidth),
            child: _preview ? _buildPreview(theme) : _buildForm(theme),
          ),
        ),
      ),
    );
  }

  Widget _buildForm(ThemeData theme) {
    return FadingScrollEdges(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
            Dim.space4, Dim.space4, Dim.space4, Dim.space6),
        children: [
          TextField(
            controller: _title,
            textInputAction: TextInputAction.next,
            textCapitalization: TextCapitalization.sentences,
            style: theme.textTheme.titleLarge,
            decoration: const InputDecoration(
              labelText: 'Title',
              hintText: 'What is this card about?',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: Dim.space4),
          TextField(
            controller: _tags,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Tags',
              hintText: 'comma, separated (first is the domain)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: Dim.space4),
          TextField(
            controller: _body,
            minLines: 8,
            maxLines: null,
            keyboardType: TextInputType.multiline,
            textCapitalization: TextCapitalization.sentences,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontFamily: 'monospace',
              fontFamilyFallback: const ['Menlo', 'Consolas', 'Roboto Mono'],
            ),
            decoration: const InputDecoration(
              labelText: 'Body (markdown)',
              hintText: 'Overview, then ## sections to quiz…',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
          ),
          if (_warning != null) ...[
            const SizedBox(height: Dim.space3),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline,
                    size: Dim.iconMd,
                    color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(width: Dim.space2),
                Expanded(
                  child: Text(
                    _warning!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: Dim.space3),
          Text(
            'The title is the recall cue; each ## section is a scheduled review '
            'unit. Sections like Overview, Related, or Resources aren\'t quizzed.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreview(ThemeData theme) {
    final title = _title.text.trim();
    final body = _body.text.trim();
    return FadingScrollEdges(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
            Dim.space4, Dim.space4, Dim.space4, Dim.space6),
        children: [
          Text(
            title.isEmpty ? 'Untitled card' : title,
            style: theme.textTheme.headlineSmall,
          ),
          const SizedBox(height: Dim.space4),
          if (body.isEmpty)
            Text(
              'Nothing to preview yet.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            )
          else
            CardMarkdown(body),
        ],
      ),
    );
  }
}

/// True if [body] has at least one `## ` heading (ignoring ones inside fenced
/// code blocks — mirrors [CardParser]'s fence-aware split so the check agrees
/// with what will actually parse as a quizzable section).
bool _hasSection(String body) {
  final fence = RegExp(r'^[ \t]*(```|~~~)');
  final h2 = RegExp(r'^##[ \t]+(.+?)[ \t]*$');
  var inFence = false;
  for (final line in body.split('\n')) {
    if (fence.hasMatch(line)) {
      inFence = !inFence;
      continue;
    }
    if (!inFence && h2.hasMatch(line)) return true;
  }
  return false;
}

/// The markdown that follows the H1 in [raw], with the frontmatter and the H1
/// line itself stripped — the exact body the user last wrote. Returns null if
/// the file has no H1 (so the caller falls back to a parsed rebuild).
String? _bodyAfterH1(String raw) {
  final fm =
      RegExp(r'^---[ \t]*\r?\n(.*?)\r?\n---[ \t]*\r?\n?(.*)$', dotAll: true);
  final match = fm.firstMatch(raw);
  final afterFrontmatter = match != null ? match.group(2)! : raw;
  final h1 = RegExp(r'^#[ \t]+(.+?)[ \t]*$');
  final lines = afterFrontmatter.split('\n');
  for (var i = 0; i < lines.length; i++) {
    if (h1.hasMatch(lines[i])) {
      return lines.sublist(i + 1).join('\n').trim();
    }
  }
  return null;
}

/// Reconstructs an editable body from a parsed [Card] (overview + each
/// `## heading` + content). The fallback when the raw file can't be read.
String _bodyFromCard(Card card) {
  final buffer = StringBuffer();
  if (card.overview.isNotEmpty) buffer.write(card.overview);
  for (final section in card.sections) {
    if (buffer.isNotEmpty) buffer.write('\n\n');
    buffer
      ..write('## ${section.heading}')
      ..write('\n\n')
      ..write(section.content);
  }
  return buffer.toString();
}
