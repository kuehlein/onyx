import '../database/database.dart';
import 'study_state.dart';

/// The per-kind DOMAIN types for the unified study-state record (ADR-0024 §2).
///
/// The flat `study_states` row ([StudyStateRow]) is the *storage* form — its payload
/// columns are nullable per kind. The *model* is "core + one payload": each concrete
/// type carries the common core PLUS exactly its own kind's payload, and the payload
/// fields are **non-null** — an illegal state (a recall datum with no forgetting
/// curve) is unrepresentable. [SrsRepository.loadStates] / [RecognitionRepository]
/// decode a row into the matching type ONCE, via the `fromRow` factories here, which
/// are the single home for the storage→domain defaults.
///
/// Two independent concrete types, deliberately with **no shared `sealed` base**:
/// nothing holds a mixed-kind collection or switches on kind to reach a field (each
/// `loadStates` filters by kind at the source), so the Dart type *is* the
/// discriminator. The cross-kind uniform handle already exists one layer down — the
/// raw [StudyStateRow] via [StudyStateRepository]. A `sealed` supertype is a
/// non-breaking additive change if a heterogeneous consumer ever appears (e.g. #158).

/// Recall (FSRS) scheduling state for one `(cardId, sectionSlug)` — its own
/// forgetting curve. The FSRS payload (`stability`/`difficulty`/`fsrsState`) is
/// guaranteed non-null.
class RecallState {
  const RecallState({
    required this.cardId,
    required this.sectionSlug,
    required this.dueAt,
    required this.activityCount,
    required this.stability,
    required this.difficulty,
    required this.fsrsState,
    this.lastActivityAt,
    this.step,
  });

  /// Decode a recall [StudyStateRow]. Byte-identical to the retired `SrsRepository`
  /// adapter — the only place the recall storage defaults live.
  factory RecallState.fromRow(StudyStateRow r) => RecallState(
        cardId: r.cardId,
        sectionSlug: studyAspect(r.dataSlug),
        dueAt: r.dueAt,
        lastActivityAt: r.lastActivityAt,
        activityCount: r.activityCount,
        stability: r.stability ?? 0,
        difficulty: r.difficulty ?? 5,
        fsrsState: r.fsrsState ?? 1,
        step: r.step,
      );

  // --- common core ---
  final String cardId;
  final String sectionSlug;
  final DateTime dueAt;
  final DateTime? lastActivityAt;
  final int activityCount;

  // --- recall (FSRS) payload ---
  final double stability;
  final double difficulty;

  /// FSRS learning state: 1=learning, 2=review, 3=relearning.
  final int fsrsState;

  /// FSRS learning/relearning step index; null once the card reaches review.
  final int? step;
}

/// Practice (expanding-interval "explain") scheduling state for one
/// `(cardId, sectionSlug)` — the algorithm explain clock and the mock-interview
/// recurrence. The streak lives in the core `activityCount`.
class PracticeState {
  const PracticeState({
    required this.cardId,
    required this.sectionSlug,
    required this.dueAt,
    required this.activityCount,
    required this.intervalDays,
    this.lastActivityAt,
  });

  /// Decode a practice [StudyStateRow]. Byte-identical to the retired
  /// `RecognitionRepository` adapter — the only place the practice defaults live.
  factory PracticeState.fromRow(StudyStateRow r) => PracticeState(
        cardId: r.cardId,
        sectionSlug: studyAspect(r.dataSlug),
        dueAt: r.dueAt,
        lastActivityAt: r.lastActivityAt,
        activityCount: r.activityCount,
        intervalDays: r.intervalDays ?? 0,
      );

  // --- common core ---
  final String cardId;
  final String sectionSlug;
  final DateTime dueAt;
  final DateTime? lastActivityAt;

  /// Consecutive "solid" explanations (the practice streak); resets to 0 on "lost".
  final int activityCount;

  // --- practice payload ---
  /// Current spacing in days (the last interval applied).
  final int intervalDays;

  /// When this was last explained — derived, centralizing the old adapter's
  /// `lastActivityAt ?? dueAt` default (nothing mutates it independently).
  DateTime get lastExplainedAt => lastActivityAt ?? dueAt;
}
