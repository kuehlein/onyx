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
}

/// An in-memory registry with a couple of small, deliberately GENERIC sample
/// decks — the dev/test fake for the registry seam. No network, no server; a
/// future `HttpRegistryClient` replaces this behind [RegistryClient].
///
/// Card ids are deck-prefixed (e.g. `capitals-france`) so an imported card can
/// never collide with a user's own card ids, and each card's body is a real
/// `## ` section that parses cleanly via `CardParser`.
class FakeRegistryClient implements RegistryClient {
  const FakeRegistryClient();

  @override
  Future<List<DeckSummary>> listDecks() async => [
        for (final deck in _decks)
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
      _decks.firstWhere((d) => d.deckId == deckId);

  static const _descriptions = <String, String>{
    'world-capitals': 'A handful of country → capital pairs.',
    'spanish-everyday-phrases': 'Common phrases for everyday conversation.',
  };

  static final List<DeckManifest> _decks = [
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
