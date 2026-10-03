import 'package:drift/drift.dart';

// Schema mirrors docs/architecture.md. SQLite holds only derived / app-specific
// data — never card content, which lives in the vault. Timestamps are stored as
// unix seconds (drift's default DateTime encoding), matching the INTEGER columns
// documented in the architecture.

/// Full, append-only review log; never deleted. Used for activity analysis and
/// FSRS optimization.
class Reviews extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get cardId => text()();
  TextColumn get sectionSlug => text()();
  DateTimeColumn get reviewedAt => dateTime()();

  /// FSRS grade: 1=Again, 2=Hard, 3=Good, 4=Easy.
  IntColumn get grade => integer()();
  RealColumn get stability => real()();
  RealColumn get difficulty => real()();
  RealColumn get elapsedDays => real()();
}

/// Graph edge cache (wikilinks), rebuilt whenever the vault is re-indexed.
class CardLinks extends Table {
  TextColumn get fromCard => text()();
  TextColumn get toCard => text()();

  @override
  Set<Column<Object>> get primaryKey => {fromCard, toCard};
}

/// Activity log for future AI analysis.
class ActivityLog extends Table {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get occurredAt => dateTime()();

  /// e.g. 'session_start', 'review', 'browse', 'ai_query'.
  TextColumn get eventType => text()();
  TextColumn get cardId => text().nullable()();
  TextColumn get sectionSlug => text().nullable()();

  /// JSON blob for event-specific data.
  TextColumn get metadata => text().nullable()();
}

/// Card metadata cache — rebuilt on vault re-index, never the source of truth.
/// Enables fast readiness/browse queries without re-parsing every markdown file.
class CardCache extends Table {
  TextColumn get cardId => text()();
  TextColumn get title => text()();

  /// 'flashcard' | 'interview-question'.
  TextColumn get cardType => text()();

  /// JSON array, e.g. `["ds-a","bst","tree"]`.
  TextColumn get tags => text()();

  /// JSON object, e.g. `{"ds-a":2,"system-design":1}`.
  TextColumn get tiers => text()();

  // interview-question-only columns (null for concept cards).
  TextColumn get category => text().nullable()();
  TextColumn get difficulty => text().nullable()();
  TextColumn get frequency => text().nullable()();
  TextColumn get practiceUrl => text().nullable()();

  TextColumn get filePath => text()();
  DateTimeColumn get indexedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {cardId};
}

/// Persisted coach conversations, keyed by `(cardId, sectionSlug)`. Local-only
/// by design: this table is NOT part of the vault snapshot, so it survives a
/// restore-from-vault (which only touches srs_state / reviews) but is
/// intentionally lost on reinstall. `sectionSlug` is null for a whole-card
/// (browse) chat.
///
/// Row class renamed to avoid colliding with the domain `CoachMessage` in
/// `core/ai/coach.dart`.
@DataClassName('CoachMessageRow')
class CoachMessages extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get cardId => text()();
  TextColumn get sectionSlug => text().nullable()();

  /// 'user' | 'assistant'.
  TextColumn get role => text()();
  TextColumn get body => text()();

  /// Which coach surface owns this row (a [CoachKind] name): 'coach' (general /
  /// browse), 'tutor' (Learn first-exposure), or 'examiner' (Review / mock). Lets
  /// a tutor and an examiner transcript share a `(cardId, sectionSlug)` without
  /// clearing or interleaving each other (n0015). Legacy rows default to 'coach'.
  TextColumn get kind => text().withDefault(const Constant('coach'))();

  /// Advisory grade (1–4) offered on an assistant turn; null otherwise.
  IntColumn get suggestedGrade => integer().nullable()();
  DateTimeColumn get createdAt => dateTime()();
}

/// Phase B: applied / mock-interview attempts — the signal FSRS recall can't
/// capture (problem-solving, transfer, communication). One row per attempt,
/// produced by the interview coach's structured assessment (and later external
/// practice self-reports). Kept SEPARATE from `reviews`: the human's FSRS grade
/// drives scheduling; this AI-derived applied score only feeds readiness.
///
/// The rubric is stored as a JSON map (dimension → 1–5) rather than fixed
/// columns so the dimensions can vary by subject (see the generalization goal).
class AppliedAttempts extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get cardId => text()();
  TextColumn get sectionSlug => text().nullable()();
  TextColumn get domain => text().nullable()();
  DateTimeColumn get occurredAt => dateTime()();

  /// Overall applied performance, 0–100.
  IntColumn get appliedScore => integer()();

  /// JSON object of rubric scores, e.g. `{"correctness":4,"communication":3}`.
  TextColumn get rubric => text().withDefault(const Constant('{}'))();

  /// Whether the probe was a novel/transfer problem (the truest signal).
  BoolColumn get novel => boolean().withDefault(const Constant(false))();

  /// Hints leaned on (0 = fully unaided).
  IntColumn get hintLevel => integer().withDefault(const Constant(0))();

  /// Where it came from: 'interview-coach' | 'practice' | 'external'.
  TextColumn get source => text()();
  TextColumn get note => text().nullable()();

  /// Adversarial second-opinion score (0–100), null until a critic pass runs.
  IntColumn get verifierScore => integer().nullable()();

  /// Whether the applied score survived the critic (null = not yet checked).
  BoolColumn get verified => boolean().nullable()();
}

/// Unified study-state record (ADR-0024 — #155): the SOLE study-state store,
/// collapsing the former FSRS recall clock and expanding-interval practice clock
/// into ONE table keyed `(cardId, dataSlug)`, **deck/config-free**, so a card
/// reused across decks keeps one shared schedule (advance-anywhere) while
/// genuinely-different practice (recall vs explain) keeps independent schedules.
///
/// `kind` is the scheduling-model discriminator ('recall' | 'practice'; see
/// [StudyKind]). The payload columns are nullable **per kind** — an acceptable
/// *storage* form for the kind-tagged payload; the *model* is a common core
/// (cardId, dataSlug, kind, dueAt, lastActivityAt, activityCount) + one payload
/// (recall: stability/difficulty/fsrsState/step; practice: intervalDays, with the
/// streak kept in `activityCount`). The per-kind DOMAIN types the app reads are
/// `RecallState`/`PracticeState` (see `study_state_model.dart`).
///
/// Created at schema v3; the two legacy tables were dropped at v4 (slice 7). A
/// `status` column (retain-but-detach, #158) is deferred to its consumer.
///
/// The generated row class is named `StudyStateRow` (not the default `StudyState`)
/// so it never collides with the per-kind DOMAIN types `RecallState`/`PracticeState`
/// that `loadStates` decodes it into (ADR-0024 §2 — the flat nullable row is the
/// *storage* form; the model is core + one payload). Mirrors `CoachMessageRow`.
@DataClassName('StudyStateRow')
class StudyStates extends Table {
  TextColumn get cardId => text()();

  /// `aspect + mode` (ADR-0024 §1): the section slug for recall; a namespaced slug
  /// for practice (see `studyDataSlug`). NEVER carries the deck/config — that is
  /// the advance-anywhere invariant.
  TextColumn get dataSlug => text()();

  /// Scheduling-model discriminator: 'recall' (FSRS) | 'practice' (expanding).
  TextColumn get kind => text()();

  // --- common core ---
  DateTimeColumn get dueAt => dateTime()();
  DateTimeColumn get lastActivityAt => dateTime().nullable()();
  IntColumn get activityCount => integer().withDefault(const Constant(0))();

  // --- recall (FSRS) payload; null for practice rows ---
  RealColumn get stability => real().nullable()();
  RealColumn get difficulty => real().nullable()();

  /// FSRS learning state: 1=learning, 2=review, 3=relearning (see fsrs State).
  /// Named `fsrsState` to avoid confusion with the core record's lifecycle.
  IntColumn get fsrsState => integer().nullable()();

  /// FSRS learning/relearning step index; null once the card reaches review.
  IntColumn get step => integer().nullable()();

  // --- practice (expanding-interval) payload; null for recall rows ---
  IntColumn get intervalDays => integer().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {cardId, dataSlug};
}

/// Key/value app preferences (vault bookmark, settings).
class Preferences extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column<Object>> get primaryKey => {key};
}
