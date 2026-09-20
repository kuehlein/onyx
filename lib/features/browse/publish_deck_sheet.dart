// Material's `Card` collides with our domain `Card` model.
import 'package:flutter/material.dart' hide Card;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/registry/publish_deck.dart';
import '../../shared/design/onyx_design.dart';
import '../../shared/models/card.dart';
import '../../shared/providers/registry.dart';
import '../../shared/providers/vault.dart';
import '../../shared/widgets/sheet_header.dart';

/// Opens the "Publish a deck" sheet — export a folder of your own cards to the
/// deck registry (the maintainer / push side; registry-and-sync.md §4). The deck
/// travels as a structure-preserving file tree, content-only (scheduling never
/// travels). Reached only where [sharingReachableProvider] is true.
Future<void> showPublishDeckSheet(BuildContext context) =>
    showOnyxSheet<void>(context, builder: (_) => const _PublishDeckSheet());

class _PublishDeckSheet extends ConsumerStatefulWidget {
  const _PublishDeckSheet();

  @override
  ConsumerState<_PublishDeckSheet> createState() => _PublishDeckSheetState();
}

class _PublishDeckSheetState extends ConsumerState<_PublishDeckSheet> {
  /// Selected export folder; '' = the whole study folder.
  String _folder = '';
  final _name = TextEditingController();
  final _author = TextEditingController();
  final _license = TextEditingController(text: 'CC0-1.0');
  bool _publishing = false;

  @override
  void dispose() {
    _name.dispose();
    _author.dispose();
    _license.dispose();
    super.dispose();
  }

  Future<void> _publish(List<Card> cards) async {
    final source = ref.read(vaultSourceProvider);
    final name = _name.text.trim();
    if (source == null || name.isEmpty || _publishing) return;
    setState(() => _publishing = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      final manifest = await buildFolderDeck(
        source: source,
        cards: cards,
        folder: _folder,
        deckId: _slugify(name),
        name: name,
        author: _author.text.trim().isEmpty ? 'Me' : _author.text.trim(),
        license: _license.text.trim().isEmpty ? null : _license.text.trim(),
      );
      if (manifest.files.isEmpty) {
        setState(() => _publishing = false);
        messenger.showSnackBar(const SnackBar(
            content: Text('That folder has no cards to publish.')));
        return;
      }
      final issue = deckPayloadIssue(manifest);
      if (issue != null) {
        setState(() => _publishing = false);
        messenger.showSnackBar(SnackBar(content: Text(issue)));
        return;
      }
      await ref.read(registryClientProvider).publishDeck(manifest);
      navigator.maybePop();
      messenger.showSnackBar(SnackBar(
          content: Text('Published "$name" '
              '(${manifest.files.length} '
              '${manifest.files.length == 1 ? 'card' : 'cards'}).')));
    } catch (e) {
      if (!mounted) return;
      setState(() => _publishing = false);
      messenger.showSnackBar(SnackBar(content: Text("Couldn't publish: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    final source = ref.watch(vaultSourceProvider);
    final indexAsync = ref.watch(vaultIndexProvider);
    // Your own material only — drafts (unreviewed inflows) aren't yours to share.
    final cards = [
      for (final c in indexAsync.asData?.value.cards ?? const <Card>[])
        if (!c.isDraft) c,
    ];
    final folders = publishableFolders(cards);
    final canPublish =
        source != null && !_publishing && _name.text.trim().isNotEmpty;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SheetHeader(title: 'Publish a deck', icon: Icons.upload_outlined),
        Padding(
          padding:
              const EdgeInsets.fromLTRB(Dim.space5, 0, Dim.space5, Dim.space4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                source == null
                    ? 'Set up a study folder first, then you can publish a deck.'
                    : cards.isEmpty
                        ? "You don't have any cards to publish yet."
                        : 'Share a folder of your cards. Only content travels — '
                            'your review progress never does.',
                style: context.text.bodyMedium?.copyWith(
                    color: context.colors.onSurfaceVariant, height: 1.4),
              ),
              if (source != null && cards.isNotEmpty) ...[
                const SizedBox(height: Dim.space4),
                DropdownButtonFormField<String>(
                  initialValue: _folder,
                  decoration: const InputDecoration(labelText: 'Folder'),
                  items: [
                    const DropdownMenuItem(
                        value: '', child: Text('Whole study folder')),
                    for (final f in folders)
                      DropdownMenuItem(value: f, child: Text(f)),
                  ],
                  onChanged: _publishing
                      ? null
                      : (v) => setState(() => _folder = v ?? ''),
                ),
                const SizedBox(height: Dim.space3),
                TextField(
                  controller: _name,
                  enabled: !_publishing,
                  decoration: const InputDecoration(labelText: 'Deck name'),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: Dim.space3),
                TextField(
                  controller: _author,
                  enabled: !_publishing,
                  decoration: const InputDecoration(
                      labelText: 'Author', hintText: 'Optional'),
                ),
                const SizedBox(height: Dim.space3),
                TextField(
                  controller: _license,
                  enabled: !_publishing,
                  decoration: const InputDecoration(
                      labelText: 'License', hintText: 'Optional'),
                ),
                const SizedBox(height: Dim.space5),
                FilledButton.icon(
                  onPressed: canPublish ? () => _publish(cards) : null,
                  icon: _publishing
                      ? const SizedBox(
                          width: Dim.iconSm,
                          height: Dim.iconSm,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.upload_outlined, size: Dim.iconMd),
                  label: Text(_publishing ? 'Publishing…' : 'Publish'),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Lowercase, non-alphanumerics → single hyphen, trimmed — a stable deckId from
/// the deck name. (Matches `CardParser.slugify`.)
String _slugify(String value) => value
    .toLowerCase()
    .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
    .replaceAll(RegExp(r'^-+|-+$'), '');
