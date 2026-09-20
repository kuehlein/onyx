/// Data types for the permissioned deck registry (docs/registry-and-sync.md §3-4).
///
/// A deck is a **file tree** — a set of files with their relative paths preserved
/// — not a bag of parsed cards. Preserving the paths is what carries the
/// exporter's vault STRUCTURE to the importer (a history vault's `people/`,
/// `places/`, `battles/` layout survives the transfer), which serves the
/// second-brain goal, not just flashcard content.
///
/// The overriding invariant is **"scheduling never travels"** (S8 / T4): a pulled
/// deck carries **content only** — files + metadata + license — and structurally
/// CANNOT carry SRS state or review history (there is no such field to travel in;
/// SRS lives in the local DB). Pulled cards enter as drafts and read as fresh
/// (see `importDeck`).
///
/// [DeckSummary] is the lightweight listing row; [DeckManifest] + [DeckFile] are
/// the full pulled payload. `fromJson`/`toJson` let a future real HTTP client
/// parse the wire format; the in-dev [FakeRegistryClient] builds them in code.
library;

/// One row in the registry's deck list — enough to show a browsable entry without
/// pulling the whole payload. `cardCount` is a size fact only (no downloads /
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

  /// Number of files in the deck — shown as a plain size fact.
  final int cardCount;

  /// Optional one-line description for the listing.
  final String? description;
}

/// One file in a deck payload: its path RELATIVE to the deck root plus the raw
/// file text (frontmatter + body), carried **verbatim**. The relative path is
/// what preserves the exporter's folder structure on the other side; verbatim
/// content keeps non-card files (notes, later) intact too.
class DeckFile {
  const DeckFile({required this.path, required this.content});

  /// Relative POSIX path within the deck, e.g. `people/caesar.md`.
  final String path;

  /// Raw file text (frontmatter + body). No SRS/review data — that isn't in
  /// files, so scheduling can't travel here.
  final String content;

  factory DeckFile.fromJson(Map<String, dynamic> json) => DeckFile(
        path: json['path'] as String,
        content: json['content'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {'path': path, 'content': content};
}

/// The full pulled payload: identity, optional license, and the deck's [files] as
/// a structure-preserving tree. **Content only** — no srs_state/reviews field,
/// enforcing "scheduling never travels" at the type level.
class DeckManifest {
  const DeckManifest({
    required this.deckId,
    required this.name,
    required this.author,
    required this.files,
    this.license,
  });

  final String deckId;
  final String name;
  final String author;

  /// SPDX-style license id or short label, or null. The attribution/license seam
  /// (§4.5) is reserved now; enforcement is deferred.
  final String? license;

  /// The deck's files, each with a deck-relative path (structure preserved).
  final List<DeckFile> files;

  /// Parses the wire JSON a real [RegistryClient] would receive. Tolerant of a
  /// missing `files`/`license` (defaults: empty list / null).
  factory DeckManifest.fromJson(Map<String, dynamic> json) => DeckManifest(
        deckId: json['deckId'] as String,
        name: json['name'] as String,
        author: json['author'] as String,
        license: json['license'] as String?,
        files: [
          for (final f in (json['files'] as List? ?? const []))
            DeckFile.fromJson(f as Map<String, dynamic>),
        ],
      );

  Map<String, dynamic> toJson() => {
        'deckId': deckId,
        'name': name,
        'author': author,
        if (license != null) 'license': license,
        'files': [for (final f in files) f.toJson()],
      };
}
