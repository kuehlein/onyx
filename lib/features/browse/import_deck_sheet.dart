import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/registry/deck.dart';
import '../../core/registry/import_deck.dart';
import '../../shared/design/context_x.dart';
import '../../shared/providers/registry.dart';
import '../../shared/providers/vault.dart';
import '../../shared/widgets/sheet_header.dart';

/// Opens the "Import a deck" sheet (design-system §4.9). Pulls a shared deck from
/// the registry seam and writes its cards into the study folder as drafts.
Future<void> showImportDeckSheet(BuildContext context) {
  return showOnyxSheet<void>(
    context,
    builder: (_) => const _ImportDeckSheet(),
  );
}

class _ImportDeckSheet extends ConsumerStatefulWidget {
  const _ImportDeckSheet();

  @override
  ConsumerState<_ImportDeckSheet> createState() => _ImportDeckSheetState();
}

class _ImportDeckSheetState extends ConsumerState<_ImportDeckSheet> {
  /// The deckId currently being pulled/written (disables the list + shows a
  /// spinner on that row), or null when idle.
  String? _importing;

  Future<void> _import(DeckSummary summary) async {
    if (_importing != null) return;
    final source = ref.read(vaultSourceProvider);
    if (source == null) return; // guarded: no folder configured
    setState(() => _importing = summary.deckId);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      final client = ref.read(registryClientProvider);
      final manifest = await client.getDeck(summary.deckId);
      final count = await importDeck(source, manifest);
      ref.invalidate(vaultIndexProvider);
      navigator.maybePop();
      messenger.showSnackBar(
        SnackBar(
          content: Text('Imported $count '
              '${count == 1 ? 'card' : 'cards'} from ${summary.name} as drafts.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _importing = null);
      messenger.showSnackBar(
        SnackBar(content: Text("Couldn't import ${summary.name}: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasFolder = ref.watch(vaultSourceProvider) != null;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SheetHeader(
          title: 'Import a deck',
          icon: Icons.download_outlined,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              hasFolder
                  ? 'Pull a shared deck into your folder. Its cards arrive as '
                      'drafts you review before they count.'
                  : 'Set up a study folder first, then you can pull shared decks '
                      'into it.',
              style: context.text.bodyMedium?.copyWith(
                color: context.colors.onSurfaceVariant,
                height: 1.4,
              ),
            ),
          ),
        ),
        if (hasFolder) _DeckList(importing: _importing, onImport: _import),
      ],
    );
  }
}

/// The registry listing as plain [ListTile]s. Kept deliberately simple (no
/// AnimatedSize / indeterminate chrome that could hang a widget-test pump).
class _DeckList extends ConsumerWidget {
  const _DeckList({required this.importing, required this.onImport});

  final String? importing;
  final Future<void> Function(DeckSummary) onImport;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final decksAsync = ref.watch(deckListProvider);
    return decksAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Text(
          "Couldn't reach the deck registry: $e",
          style: context.text.bodyMedium?.copyWith(color: context.colors.error),
        ),
      ),
      data: (decks) {
        if (decks.isEmpty) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Text(
              'No decks are available to import yet.',
              style: context.text.bodyMedium
                  ?.copyWith(color: context.colors.onSurfaceVariant),
            ),
          );
        }
        return Flexible(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.only(bottom: 12),
            children: [
              for (final deck in decks)
                ListTile(
                  leading: const Icon(Icons.style_outlined),
                  title: Text(deck.name),
                  subtitle: Text(
                    '${deck.cardCount} '
                    '${deck.cardCount == 1 ? 'card' : 'cards'} · ${deck.author}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: importing == deck.deckId
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.download_outlined),
                  // Disable every row while any import is running.
                  enabled: importing == null,
                  onTap: () => onImport(deck),
                ),
            ],
          ),
        );
      },
    );
  }
}
