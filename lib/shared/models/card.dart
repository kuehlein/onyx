/// The two card types Onyx indexes from the vault. A file whose frontmatter
/// `type` is neither of these is not an Onyx card and is skipped by the indexer
/// (this is how `_meta/` files and ordinary vault notes are ignored).
enum CardType {
  flashcard('flashcard'),
  interviewQuestion('interview-question');

  const CardType(this.value);

  /// The exact string written in frontmatter.
  final String value;

  static CardType? fromString(String? raw) {
    for (final type in CardType.values) {
      if (type.value == raw) return type;
    }
    return null;
  }
}

/// Author-assigned trust level, set during card verification. Guides how much to
/// rely on a card before cross-checking it against its Resources links.
enum Confidence {
  high('high'),
  medium('medium'),
  low('low');

  const Confidence(this.value);

  final String value;

  static Confidence? fromString(String? raw) {
    for (final confidence in Confidence.values) {
      if (confidence.value == raw) return confidence;
    }
    return null;
  }
}

/// How hard to retain a card's material, mapped to an FSRS **desired retention**
/// target. Interview-critical material is reviewed more often (higher retention)
/// than nice-to-know material. The band is deliberately narrow — retention above
/// ~0.95 makes review counts explode for marginal gain, and the whole point is
/// lost if everything is marked `high`, so `normal` is the default.
enum Priority {
  high('high', 0.93),
  normal('normal', 0.90),
  low('low', 0.85);

  const Priority(this.value, this.desiredRetention);

  final String value;
  final double desiredRetention;

  static Priority? fromString(String? raw) {
    for (final p in Priority.values) {
      if (p.value == raw) return p;
    }
    return null;
  }
}

/// One H2 section of a card. Each *quizzable* section is an independent SRS
/// unit, scheduled by its `(cardId, slug)` pair — see `srs_state` in the schema.
class CardSection {
  const CardSection({
    required this.heading,
    required this.slug,
    required this.content,
    required this.quizzable,
  });

  /// Original H2 heading text, e.g. `"Time & Space Complexity"`.
  final String heading;

  /// Stable identifier derived from [heading]: lowercased, with each run of
  /// non-alphanumeric characters collapsed to a single hyphen, e.g.
  /// `"time-space-complexity"`. This is the `section_slug` used throughout
  /// SQLite, so it must stay stable across app runs.
  final String slug;

  /// The section's markdown body (everything under the heading, heading
  /// excluded), with surrounding blank lines trimmed.
  final String content;

  /// Whether this section is scheduled for review. False for blocklisted
  /// sections (Related, Resources, …) and for non-primary sections of an
  /// interview question (only `## Approach` is quizzed by default).
  final bool quizzable;
}

/// A parsed vault card. This is the in-memory representation of a single `.md`
/// file; the vault remains the source of truth and this is never persisted as
/// content (only derived metadata goes to SQLite's `card_cache`).
///
/// Note: this type is named `Card`, which collides with Material's `Card`
/// widget. UI files that need both should `hide Card` on the Material import
/// (we rarely need the widget) or import this model with a prefix.
class Card {
  const Card({
    required this.id,
    required this.type,
    required this.title,
    required this.overview,
    required this.tags,
    required this.tiers,
    required this.sections,
    required this.wikilinks,
    required this.filePath,
    this.created,
    this.confidence,
    this.quizOverride,
    this.category,
    this.difficulty,
    this.frequency,
    this.practiceUrl,
    this.source,
    this.domains = const [],
    this.concepts = const [],
    this.priority = Priority.normal,
  });

  /// UUID v4 from frontmatter — the stable primary key across filename renames.
  final String id;
  final CardType type;

  /// H1 title text.
  final String title;

  /// Pre-H2 body. For an interview question this is the problem statement shown
  /// as front-side context; for a concept card it's the principle-first
  /// overview. May be empty.
  final String overview;

  final List<String> tags;

  /// Per-domain tier map, e.g. `{"ds-a": 2, "system-design": 1}`.
  final Map<String, int> tiers;

  final List<CardSection> sections;

  /// De-duplicated outbound wikilink targets (filenames without `.md`), in first
  /// appearance order.
  final List<String> wikilinks;

  /// Path of the source file, relative to the vault root.
  final String filePath;

  final DateTime? created;
  final Confidence? confidence;

  /// Explicit `quiz:` frontmatter override — a list of section slugs to quiz.
  /// Null when absent; when present it fully determines which sections quiz.
  final List<String>? quizOverride;

  // ── interview-question-only metadata (null/empty for concept cards) ────────
  final String? category;
  final String? difficulty;
  final String? frequency;

  /// URL opened (skippably) after a Good/Easy grade on an interview question.
  final String? practiceUrl;
  final String? source;
  final List<String> domains;

  /// Filenames (without `.md`) of concept cards this question draws on.
  final List<String> concepts;

  /// Retention priority → FSRS desired-retention target. Defaults to normal.
  final Priority priority;

  /// The domain tag (first tag by convention), or null if untagged.
  String? get domain => tags.isNotEmpty ? tags.first : null;

  /// Sections actually scheduled for review.
  Iterable<CardSection> get quizzableSections =>
      sections.where((section) => section.quizzable);
}

/// Thrown when a file has a valid card `type` but is missing its `id`. The
/// indexer counts these (surfaced in Settings) and skips them — they are cards
/// that just need a UUID added.
class MissingCardIdException implements Exception {
  const MissingCardIdException(this.filePath);
  final String filePath;

  @override
  String toString() => 'MissingCardIdException: no `id` field in $filePath';
}

/// Thrown when a file is a card (valid type + id) but is structurally invalid,
/// e.g. it has no H1 title.
class MalformedCardException implements Exception {
  const MalformedCardException(this.filePath, this.reason);
  final String filePath;
  final String reason;

  @override
  String toString() => 'MalformedCardException: $reason ($filePath)';
}
