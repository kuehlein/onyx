import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../dev.dart';
import '../srs/study_state.dart';
import 'tables.dart';

part 'database.g.dart';

@DriftDatabase(
  tables: [
    SrsStates,
    Reviews,
    CardLinks,
    ActivityLog,
    CardCache,
    Preferences,
    CoachMessages,
    AppliedAttempts,
    RecognitionStates,
    StudyStates,
  ],
)
class AppDatabase extends _$AppDatabase {
  /// Production database, backed by a file in the app documents directory.
  AppDatabase() : super(_openConnection());

  /// Injectable executor for tests (e.g. `NativeDatabase.memory()`).
  AppDatabase.withExecutor(super.executor);

  @override
  int get schemaVersion => 3;

  /// Deletes all study progress — schedule, review log, activity, coach chats,
  /// and applied (mock) attempts — while leaving preferences (settings/target)
  /// and the rebuilt card cache intact. Used by the dev-only "Reset local
  /// progress" action.
  Future<void> wipeStudyData() => transaction(() async {
        await delete(srsStates).go();
        await delete(reviews).go();
        await delete(activityLog).go();
        await delete(coachMessages).go();
        await delete(appliedAttempts).go();
        await delete(recognitionStates).go();
        await delete(studyStates).go();
      });

  // Pre-release: this SQLite file is a derived cache — the real study progress
  // lives in the vault snapshot (srs_state / reviews / applied attempts) and is
  // restored on an empty DB, so `onCreate` builds every table fresh. The one
  // `onUpgrade` step below carries an existing local DB forward (coach chats are
  // local-only, not in the vault) rather than forcing a wipe; keep adding narrow
  // steps here as the schema evolves.
  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        onUpgrade: (m, from, to) async {
          // v2 (n0015): a `kind` discriminator on coach_messages so the Learn
          // first-exposure tutor and the Review examiner don't share/clear one
          // transcript on the same (cardId, sectionSlug). Legacy rows → 'coach'.
          if (from < 2) await m.addColumn(coachMessages, coachMessages.kind);
          // v3 (n0024): the unified study-state record. Create `study_states` and
          // backfill it from the two legacy clocks, byte-exact. The old tables
          // stay until the writer/reader flip completes (ADR-0024 slices 4-7).
          if (from < 3) {
            await m.createTable(studyStates);
            await backfillStudyStates();
          }
        },
      );

  /// Copy the two legacy state clocks into the unified [studyStates] (ADR-0024 §4),
  /// **byte-exact**: the FSRS payload migrates verbatim — a fitted forgetting curve
  /// is never re-fit (ADR-0008). Recall rows keep the bare section slug as their
  /// `dataSlug` (so the `reviews` / `applied_attempts` join is preserved); practice
  /// rows are namespaced via [studyDataSlug] so an algorithm card's solve clock
  /// (recall) and explain clock (practice) on the *same* section don't collide on
  /// the `(cardId, dataSlug)` primary key.
  ///
  /// This is a **copy, not a merge**: it insert-or-replaces each legacy row's
  /// unified image keyed by `(cardId, dataSlug)`. Safe to run when `study_states`
  /// is empty or stale — the v2→v3 migration runs it once on a freshly-created
  /// table, and [SnapshotService] re-runs it on restore *after* clearing the
  /// table. Do NOT run it incrementally over live-advanced unified rows: it would
  /// clobber newer state with the stale legacy value.
  Future<void> backfillStudyStates() async {
    final recall = await select(srsStates).get();
    final practice = await select(recognitionStates).get();
    await batch((b) {
      b.insertAll(
        studyStates,
        [
          for (final s in recall)
            StudyStatesCompanion.insert(
              cardId: s.cardId,
              dataSlug: studyDataSlug(s.sectionSlug, StudyKind.recall),
              kind: StudyKind.recall.wire,
              dueAt: s.dueAt,
              lastActivityAt: Value(s.lastReview),
              activityCount: Value(s.reviewCount),
              stability: Value(s.stability),
              difficulty: Value(s.difficulty),
              fsrsState: Value(s.state),
              step: Value(s.step),
            ),
          for (final r in practice)
            StudyStatesCompanion.insert(
              cardId: r.cardId,
              dataSlug: studyDataSlug(r.sectionSlug, StudyKind.practice),
              kind: StudyKind.practice.wire,
              dueAt: r.dueAt,
              lastActivityAt: Value(r.lastExplainedAt),
              activityCount: Value(r.streak),
              intervalDays: Value(r.intervalDays),
            ),
        ],
        mode: InsertMode.insertOrReplace,
      );
    });
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    // Application-support, not documents: onyx.sqlite is a derived cache rebuilt
    // from the vault, so it belongs in app-internal storage (on iOS that keeps
    // it out of the user-visible, iCloud-backed Documents dir). path_provider
    // creates this directory; the documents dir may not exist (e.g. a Linux box
    // with no XDG user-dirs configured).
    final dir = await getApplicationSupportDirectory();
    // Dev builds use a separate file so experimenting never touches the real
    // (release) database on the same machine.
    final name = isDevDataMode ? 'onyx-dev.sqlite' : 'onyx.sqlite';
    final file = File(p.join(dir.path, name));
    return NativeDatabase.createInBackground(file);
  });
}
