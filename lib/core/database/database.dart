import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../dev.dart';
import 'tables.dart';

part 'database.g.dart';

@DriftDatabase(
  tables: [
    Reviews,
    CardLinks,
    ActivityLog,
    CardCache,
    Preferences,
    CoachMessages,
    AppliedAttempts,
    StudyStates,
  ],
)
class AppDatabase extends _$AppDatabase {
  /// Production database, backed by a file in the app documents directory.
  AppDatabase() : super(_openConnection());

  /// Injectable executor for tests (e.g. `NativeDatabase.memory()`).
  AppDatabase.withExecutor(super.executor);

  @override
  int get schemaVersion => 4;

  /// Deletes all study progress — schedule, review log, activity, coach chats,
  /// and applied (mock) attempts — while leaving preferences (settings/target)
  /// and the rebuilt card cache intact. Used by the dev-only "Reset local
  /// progress" action.
  Future<void> wipeStudyData() => transaction(() async {
        await delete(reviews).go();
        await delete(activityLog).go();
        await delete(coachMessages).go();
        await delete(appliedAttempts).go();
        await delete(studyStates).go();
      });

  // Pre-release: this SQLite file is a derived cache — the real study progress
  // lives in the vault snapshot (study_states / reviews / applied attempts) and is
  // restored on an empty DB, so `onCreate` builds every table fresh. The
  // `onUpgrade` steps below carry an existing local DB forward (coach chats are
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
          // v3 (n0024): the unified study-state record. Create `study_states`; a
          // v≤3 local DB rebuilds its rows from the vault snapshot's legacy-JSON
          // fold on the next restore (ADR-0024 slice 7 dropped the one-time
          // backfill — no production data to carry).
          if (from < 3) await m.createTable(studyStates);
          // v4 (ADR-0024 slice 7): the legacy clocks are retired — drop them.
          // `deleteTable` emits `DROP TABLE IF EXISTS`, so it's safe whether the
          // table exists (upgraded from v≤3) or not (created fresh at v4).
          if (from < 4) {
            await m.deleteTable('srs_states');
            await m.deleteTable('recognition_states');
          }
        },
      );
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
