import '../../core/subject/active_subject.dart';

// The SWE card-type value constants, re-exported so type comparisons across the
// app use one hyphenated source of truth (no camelCase-vs-hyphen mistypes).
export '../../core/subject/software_interviews.dart'
    show
        kTypeFlashcard,
        kTypeInterviewQuestion,
        kTypeAlgorithm,
        kTypeSystemDesign,
        kTypeBehavioral;

/// A card's `type:` is the raw frontmatter string naming its **flow** — e.g.
/// `flashcard`, `interview-question`, `algorithm`, `system-design`, `behavioral`,
/// or a subject's own `conversation`. A file whose `type:` matches no configured
/// flow is not an Onyx card and is skipped by the indexer (how `_meta/` files and
/// ordinary notes are ignored). All behavior for a type — scheduling,
/// quizzability, practice-track, display — comes from the active subject's
/// `FlowSpec` (see lib/core/subject/), not a hardcoded enum (task #30c Phase 4).

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

/// A card's lifecycle. New cards from an inflow — AI-generation, an imported deck,
/// or an upstream deck update — enter as [draft]: excluded from FSRS scheduling AND
/// from every readiness denominator until the user promotes them through the review
/// gate (self-test-then-promote). Cards you authored, or indexed from your own
/// folder, are [active]. Absent or unknown `status:` frontmatter defaults to
/// [active], so every existing card is unaffected. See docs/content-creation.md §3
/// and ADR-0003.
enum CardStatus {
  active('active'),
  draft('draft');

  const CardStatus(this.value);

  final String value;

  static CardStatus fromString(String? raw) {
    for (final status in CardStatus.values) {
      if (status.value == raw) return status;
    }
    return CardStatus.active;
  }
}

/// Section headings that hold study REFERENCE code rather than a recall target.
/// Kept in the card but never quizzed (reconstruct code from the approach, don't
/// memorize it verbatim — see docs/learning-science.md), and expanded by default
/// in the full-card view since they're the reason to open it.
const implementationHeadings = <String>{
  'implementation',
  'implementation notes',
  'code',
  'solution',
  'reference implementation',
};

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
    this.subjectId = '',
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
    this.dependsOn = const [],
    this.priority = Priority.normal,
    this.estMinutes,
    this.status = CardStatus.active,
    this.deckId = '',
  });

  /// UUID v4 from frontmatter — the stable primary key across filename renames.
  final String id;

  /// The raw `type:` frontmatter value (the flow id). Behavior comes from the
  /// active subject's `FlowSpec` for it.
  final String type;

  /// The id of the subject that owns this card — the config for the vault subtree
  /// it lives in (task #30d). Empty means "unspecified", resolved as the primary
  /// subject. In a single-subject vault this is that one subject's id, so nothing
  /// downstream changes. Card behavior (flow, quizzability, readiness) will resolve
  /// against `registry[subjectId]` rather than a global (M2).
  final String subjectId;

  /// Whether this card belongs to a separate paced practice track (its flow
  /// schedules as two-clock/mock) rather than the spaced concept deck. Excluded
  /// from the review/learn queues and the recall-coverage denominator; feeds
  /// readiness via applied-transfer. Derived from this card's own subject config
  /// (task #30d); single-subject vaults resolve to the one active subject.
  bool get isPracticeTrack => subjectFor(subjectId).isPracticeTrackType(type);

  /// Whether this is an *approach-only* applied card (its [overview] is a problem
  /// statement and the study UI offers practice instead of plain recall) rather
  /// than a recall fact. Config-driven (invariant #2) via this card's own subject,
  /// replacing scattered `type == 'interview-question'` checks. Single-subject
  /// vaults resolve to the one active subject.
  bool get isApproachCard => subjectFor(subjectId).isApproachType(type);

  /// This card's lifecycle status. [CardStatus.draft] cards are excluded from all
  /// scheduling and every readiness denominator until promoted through the review
  /// gate (see [isDraft], [CardStatus]); absent `status:` defaults to active.
  final CardStatus status;

  /// The deck this card belongs to — reserved for the permissioned deck registry
  /// so a pulled deck's cards can't collide with local FSRS state. Empty = the
  /// local/default deck. The SRS join-key migration to `(deckId, cardId,
  /// sectionSlug)` is deferred to the registry unit; today this is a
  /// carried-but-unused seam (ADR-0003; docs/registry-and-sync.md §3).
  final String deckId;

  /// Whether this is an unpromoted draft (excluded from scheduling + readiness).
  bool get isDraft => status == CardStatus.draft;

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

  /// Optional `est_minutes:` frontmatter override for the daily-plan time budget
  /// (per practice unit). Null → the plan falls back to its per-track default
  /// (e.g. algorithm difficulty, or the review/learn/system-design constants).
  final double? estMinutes;

  /// Concept ids this card/flow depends on (`depends-on:` frontmatter) — the
  /// prerequisites gating engine (dependency_gating.dart) resolves against
  /// competence. Empty = ungated.
  final List<String> dependsOn;

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
