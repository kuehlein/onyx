/// Data types for the permissioned deck registry (docs/registry-and-sync.md §3-4).
///
/// The overriding invariant here is **"scheduling never travels"** (S8 / T4): a
/// pulled deck carries **content only** — cards, sections, metadata, license —
/// and structurally CANNOT carry SRS state or review history. There is no
/// `srs_state`/`reviews` field to travel in, so a shared "90%" deck can never lie
/// about *your* readiness. Pulled cards enter the folder as drafts and read as
/// fresh (see `importDeck`).
///
/// [DeckSummary] is the lightweight listing row (browse the registry without
/// pulling every card); [DeckManifest] + [DeckCard] are the full pulled payload.
/// `fromJson`/`toJson` on the payload types let a future real HTTP client parse
/// the wire format; the in-dev [FakeRegistryClient] builds them in code.
library;

/// One row in the registry's deck list — enough to show a browsable entry without
/// pulling the whole manifest. `cardCount` is a size fact only (no downloads /
/// ratings / "N studying" vanity metrics — T9).
class DeckSummary {
  const DeckSummary({
    required this.deckId,
    required this.name,
    required this.author,
    required this.cardCount,
    this.description,
  });

  /// Stable registry identity for the deck; also the `deck:` frontmatter value
  /// stamped onto every pulled card so its FSRS state is namespaced by deck
  /// (`(deckId, cardId, sectionSlug)` — §3.2) and can't collide with local cards.
  final String deckId;
  final String name;
  final String author;

  /// Number of cards in the deck — shown as a plain size fact.
  final int cardCount;

  /// Optional one-line description for the listing.
  final String? description;
}

/// The full pulled payload for a deck: its identity, optional license, and the
/// list of [DeckCard]s. **Content only** — deliberately has NO srs_state/reviews
/// field, enforcing "scheduling never travels" at the type level.
class DeckManifest {
  const DeckManifest({
    required this.deckId,
    required this.name,
    required this.author,
    required this.cards,
    this.license,
  });

  final String deckId;
  final String name;
  final String author;

  /// SPDX-style license id or short label, or null. The attribution/license seam
  /// (§4.5) is reserved now; enforcement is deferred.
  final String? license;

  final List<DeckCard> cards;

  /// Parses the wire JSON a real [RegistryClient] would receive. Tolerant of a
  /// missing `cards`/`license` (defaults: empty list / null).
  factory DeckManifest.fromJson(Map<String, dynamic> json) => DeckManifest(
        deckId: json['deckId'] as String,
        name: json['name'] as String,
        author: json['author'] as String,
        license: json['license'] as String?,
        cards: [
          for (final c in (json['cards'] as List? ?? const []))
            DeckCard.fromJson(c as Map<String, dynamic>),
        ],
      );

  Map<String, dynamic> toJson() => {
        'deckId': deckId,
        'name': name,
        'author': author,
        if (license != null) 'license': license,
        'cards': [for (final c in cards) c.toJson()],
      };
}

/// A single card in a pulled deck. `body` is the markdown that follows the H1
/// title — it includes the `## ` sections. There is intentionally no SRS/review
/// data on this type (scheduling never travels).
class DeckCard {
  const DeckCard({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    this.tags = const [],
  });

  /// The card's id within the deck (deck-prefixed by convention so it can't
  /// collide with a user's own card ids). Written to `id:` frontmatter on import.
  final String id;

  /// The card `type:` — must be a flow the active subject recognizes (e.g.
  /// `flashcard`) or the parser skips the file on re-index.
  final String type;
  final String title;

  /// Recall tags, emitted to the imported card's `tags:` frontmatter.
  final List<String> tags;

  /// Markdown after the H1 (the `## ` sections and any pre-section overview).
  final String body;

  factory DeckCard.fromJson(Map<String, dynamic> json) => DeckCard(
        id: json['id'] as String,
        type: json['type'] as String,
        title: json['title'] as String,
        body: json['body'] as String? ?? '',
        tags: [
          for (final t in (json['tags'] as List? ?? const [])) t.toString(),
        ],
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'title': title,
        'tags': tags,
        'body': body,
      };
}
