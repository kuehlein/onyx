import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/registry/deck.dart';
import '../../core/registry/registry_client.dart';

part 'registry.g.dart';

/// Whether a sharing-capable backend is reachable — the capability gate for the
/// publish / Settings→SHARING UI (registry-and-sync.md §1.2). No registry server
/// exists yet, so in a release build this is false and SHARING is **absent** (a
/// disabled row for a nonexistent capability is the dark pattern settings-ux
/// forbids). Debug builds flip it on so the push flow can be developed + tested
/// against the [FakeRegistryClient]; a real build will gate on an account's
/// `sharing` capability. Reserved seam — mirrors `managedConfig`'s null default.
@riverpod
bool sharingReachable(Ref ref) => kDebugMode;

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
