import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../shared/design/onyx_design.dart';
import '../../shared/providers/decks.dart';
import 'lanes_hub.dart';

/// The **vault-level deck selection** screen (`/decks`; user_stories/deck_selection).
/// The persistent escape hatch from Home — reachable even with a single active deck,
/// so paused decks stay resumable (fixes the "pausing one of two decks strands you"
/// bug) and a single-deck user can always add/switch. A vault-level view, so it
/// deliberately drops the deck-scoped bottom nav (the deck/vault scope split is 1d).
/// Tapping a deck focuses it and returns to its Home.
class DeckSelectionScreen extends ConsumerWidget {
  const DeckSelectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Decks')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: Dim.maxNarrowWidth),
          child: LanesHub(
            showHeader: false,
            onEnter: (deckId) {
              ref.read(focusedDeckProvider.notifier).focus(deckId);
              if (context.mounted) context.pop();
            },
          ),
        ),
      ),
    );
  }
}
