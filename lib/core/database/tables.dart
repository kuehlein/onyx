import 'package:drift/drift.dart';

// Schema mirrors docs/architecture.md. SQLite holds only derived / app-specific
// data — never card content, which lives in the vault. Timestamps are stored as
// unix seconds (drift's default DateTime encoding), matching the INTEGER columns
// documented in the architecture.

/// FSRS state per `(cardId, sectionSlug)` pair — each quizzable section has its
/// own forgetting curve.
class SrsStates extends Table {
  TextColumn get cardId => text()();
  TextColumn get sectionSlug => text()();
  RealColumn get stability => real().withDefault(const Constant(0))();
  RealColumn get difficulty => real().withDefault(const Constant(5))();
  DateTimeColumn get dueAt => dateTime()();
  DateTimeColumn get lastReview => dateTime().nullable()();
  IntColumn get reviewCount => integer().withDefault(const Constant(0))();

  @override
  Set<Column<Object>> get primaryKey => {cardId, sectionSlug};
}

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

/// Key/value app preferences (vault bookmark, settings).
class Preferences extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column<Object>> get primaryKey => {key};
}
