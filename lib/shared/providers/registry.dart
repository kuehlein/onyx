import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/registry/deck.dart';
import '../../core/registry/registry_client.dart';

part 'registry.g.dart';

/// The active [RegistryClient] used by the "Import a deck" flow. In-dev this is
/// the [FakeRegistryClient] (in-memory sample decks, no server — the seam per
/// docs/registry-and-sync.md §7.1); a real HTTP client drops in here later.
/// Overridable in tests (`overrideWith`).
@riverpod
RegistryClient registryClient(Ref ref) => FakeRegistryClient();

/// The available decks to import, from the active [registryClient]. The import
/// sheet watches this; `getDeck` (the full pull) is called imperatively on tap.
@riverpod
Future<List<DeckSummary>> deckList(Ref ref) =>
    ref.watch(registryClientProvider).listDecks();
