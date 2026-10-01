/// Key vocabulary for the unified study-state record (ADR-0024).
///
/// One record collapses the two legacy clocks — `SrsStates` (FSRS recall) and
/// `RecognitionStates` (expanding-interval practice) — keyed `(cardId, dataSlug)`,
/// **deck/config-FREE**. Advancing a `(cardId, dataSlug)` anywhere advances it
/// everywhere; the only thing that forks a datum's schedule is the practice
/// **mode**, never the deck or its config. See `study_state_repository.dart` for
/// the reader and `database.dart` for the migration/backfill.
library;

/// The scheduling-model discriminator (ADR-0024 §2). The learning-science pass
/// forbids one universal forgetting curve over declarative recall and applied
/// problem-solving, so there are exactly **two** kinds, each with its own
/// scheduler:
///  * [recall]   — the FSRS clock. Payload: stability, difficulty, fsrsState, step.
///  * [practice] — the expanding-interval clock (the algorithm "explain" clock and
///    the mock-interview recurrence). Payload: intervalDays (+ the streak, stored
///    in the core `activityCount`).
///
/// `kind = f(mode)` is globally fixed, so two flows over one datum can never
/// disagree on its scheduling model.
enum StudyKind {
  recall,
  practice;

  /// The stored/serialized value (stable — persisted in the DB + snapshots).
  String get wire => name;

  static StudyKind fromWire(String value) => StudyKind.values.byName(value);
}

/// The namespace that keeps a practice datum from colliding with the recall datum
/// of the same aspect. A section slug is `slugify`'d to `[a-z0-9-]` (see
/// `CardParser.slugify`), so `':'` can never appear in an aspect — this prefix is
/// collision-proof and unambiguously strippable.
const _practicePrefix = 'recognize:';

/// Compose a `dataSlug` from an aspect (section slug, or a whole-card marker like
/// `'mock'`) and its [kind] — this is the `aspect + mode` of ADR-0024 §1.
///
/// **Recall is the bare default**: `dataSlug == aspect`. That keeps the precious
/// FSRS keys *and* their `Reviews` / `AppliedAttempts` join byte-exact across the
/// migration. The practice clock is namespaced (no external join depends on its
/// key). Today mode↔kind is 1:1, so the namespace derives from [kind]; when a kind
/// grows a second mode, the namespace becomes mode-based (ADR-0024, future).
String studyDataSlug(String aspect, StudyKind kind) =>
    kind == StudyKind.recall ? aspect : '$_practicePrefix$aspect';

/// The aspect (section slug / whole-card marker) carried by a [dataSlug] — the
/// inverse of [studyDataSlug], for rekey/drop by aspect (ADR-0012 edit-identity).
String studyAspect(String dataSlug) => dataSlug.startsWith(_practicePrefix)
    ? dataSlug.substring(_practicePrefix.length)
    : dataSlug;

/// The map key the repositories use: `"$cardId::$dataSlug"`. Note for recall
/// `dataSlug == sectionSlug`, so this is byte-identical to the legacy
/// `SrsRepository` key — letting that repo become a thin adapter without a rekey.
String studyKey(String cardId, String dataSlug) => '$cardId::$dataSlug';
