import 'deck.dart';

/// The app-side seam for the permissioned deck registry
/// (docs/registry-and-sync.md §7.1: "develop against fakes, not a server"). The
/// whole import UX is built against this interface; the in-dev
/// [FakeRegistryClient] serves cards from memory, and a real `HttpRegistryClient`
/// (not built yet) can drop in later behind the same two methods — mirroring how
/// [ClaudeService] fronts BYO-key vs the reserved managed transport.
abstract class RegistryClient {
  /// Lightweight listing of available decks (no card bodies pulled).
  Future<List<DeckSummary>> listDecks();

  /// The full content manifest for [deckId] (cards + metadata, no SRS state).
  Future<DeckManifest> getDeck(String deckId);

  /// Publish (push) a content-only [manifest] to the registry — the maintainer
  /// role (docs/registry-and-sync.md §4). The in-dev fake stores it in memory; a
  /// real client POSTs it. Idempotent by `deckId` (re-publishing replaces).
  Future<void> publishDeck(DeckManifest manifest);
}

/// An in-memory registry with a couple of small, deliberately GENERIC sample
/// decks — the dev/test fake for the registry seam. No network, no server; a
/// future `HttpRegistryClient` replaces this behind [RegistryClient].
///
/// Card ids are deck-prefixed (e.g. `capitals-france`) so an imported card can
/// never collide with a user's own card ids, and each card's body is a real
/// `## ` section that parses cleanly via `CardParser`.
class FakeRegistryClient implements RegistryClient {
  FakeRegistryClient();

  /// Decks published this session via [publishDeck], keyed by `deckId` so a
  /// re-publish replaces. In-memory only — a real server persists; this is the
  /// dev seam, and it lets a publish→pull round-trip run end-to-end offline.
  final Map<String, DeckManifest> _published = {};

  /// Sample decks plus anything published this session (published wins on id).
  Iterable<DeckManifest> get _all =>
      {for (final d in _samples) d.deckId: d, ..._published}.values;

  @override
  Future<List<DeckSummary>> listDecks() async => [
        for (final deck in _all)
          DeckSummary(
            deckId: deck.deckId,
            name: deck.name,
            author: deck.author,
            cardCount: deck.cards.length,
            description: _descriptions[deck.deckId],
          ),
      ];

  @override
  Future<DeckManifest> getDeck(String deckId) async =>
      _published[deckId] ?? _samples.firstWhere((d) => d.deckId == deckId);

  @override
  Future<void> publishDeck(DeckManifest manifest) async =>
      _published[manifest.deckId] = manifest;

  static const _descriptions = <String, String>{
    'world-capitals': 'A handful of country → capital pairs.',
    'spanish-everyday-phrases': 'Common phrases for everyday conversation.',
  };

  static final List<DeckManifest> _samples = [
    const DeckManifest(
      deckId: 'world-capitals',
      name: 'World Capitals',
      author: 'Onyx Samples',
      license: 'CC0-1.0',
      cards: [
        DeckCard(
          id: 'capitals-france',
          type: 'flashcard',
          title: 'France',
          tags: ['geography', 'capitals'],
          body: '## Capital\n\nParis.',
        ),
        DeckCard(
          id: 'capitals-japan',
          type: 'flashcard',
          title: 'Japan',
          tags: ['geography', 'capitals'],
          body: '## Capital\n\nTokyo.',
        ),
        DeckCard(
          id: 'capitals-brazil',
          type: 'flashcard',
          title: 'Brazil',
          tags: ['geography', 'capitals'],
          body: '## Capital\n\nBrasília.',
        ),
        DeckCard(
          id: 'capitals-egypt',
          type: 'flashcard',
          title: 'Egypt',
          tags: ['geography', 'capitals'],
          body: '## Capital\n\nCairo.',
        ),
        DeckCard(
          id: 'capitals-australia',
          type: 'flashcard',
          title: 'Australia',
          tags: ['geography', 'capitals'],
          body: '## Capital\n\nCanberra (not Sydney).',
        ),
      ],
    ),
    const DeckManifest(
      deckId: 'spanish-everyday-phrases',
      name: 'Spanish — Everyday Phrases',
      author: 'Onyx Samples',
      license: 'CC0-1.0',
      cards: [
        DeckCard(
          id: 'phrase-hello',
          type: 'flashcard',
          title: 'Hello',
          tags: ['spanish', 'phrases'],
          body: '## In Spanish\n\nHola.',
        ),
        DeckCard(
          id: 'phrase-thank-you',
          type: 'flashcard',
          title: 'Thank you',
          tags: ['spanish', 'phrases'],
          body: '## In Spanish\n\nGracias.',
        ),
        DeckCard(
          id: 'phrase-please',
          type: 'flashcard',
          title: 'Please',
          tags: ['spanish', 'phrases'],
          body: '## In Spanish\n\nPor favor.',
        ),
        DeckCard(
          id: 'phrase-good-morning',
          type: 'flashcard',
          title: 'Good morning',
          tags: ['spanish', 'phrases'],
          body: '## In Spanish\n\nBuenos días.',
        ),
        DeckCard(
          id: 'phrase-goodbye',
          type: 'flashcard',
          title: 'Goodbye',
          tags: ['spanish', 'phrases'],
          body: '## In Spanish\n\nAdiós.',
        ),
      ],
    ),
  ];
}
