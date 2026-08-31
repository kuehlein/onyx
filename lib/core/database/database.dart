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
    SrsStates,
    Reviews,
    CardLinks,
    ActivityLog,
    CardCache,
    Preferences,
    CoachMessages,
    AppliedAttempts,
  ],
)
class AppDatabase extends _$AppDatabase {
  /// Production database, backed by a file in the app documents directory.
  AppDatabase() : super(_openConnection());

  /// Injectable executor for tests (e.g. `NativeDatabase.memory()`).
  AppDatabase.withExecutor(super.executor);

  @override
  int get schemaVersion => 4;

  /// Deletes all study progress — schedule, review log, activity, and coach
  /// chats — while leaving preferences (settings/target) and the rebuilt card
  /// cache intact. Used by the dev-only "Reset local progress" action.
  Future<void> wipeStudyData() => transaction(() async {
        await delete(srsStates).go();
        await delete(reviews).go();
        await delete(activityLog).go();
        await delete(coachMessages).go();
      });

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        onUpgrade: (m, from, to) async {
          // v2: FSRS learning-state columns on srs_state.
          if (from < 2) {
            await m.addColumn(srsStates, srsStates.state);
            await m.addColumn(srsStates, srsStates.step);
          }
          // v3: persisted coach conversations.
          if (from < 3) {
            await m.createTable(coachMessages);
          }
          // v4: Phase B applied / mock-interview attempts.
          if (from < 4) {
            await m.createTable(appliedAttempts);
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
