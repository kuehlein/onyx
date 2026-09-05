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
    RecognitionStates,
  ],
)
class AppDatabase extends _$AppDatabase {
  /// Production database, backed by a file in the app documents directory.
  AppDatabase() : super(_openConnection());

  /// Injectable executor for tests (e.g. `NativeDatabase.memory()`).
  AppDatabase.withExecutor(super.executor);

  @override
  int get schemaVersion => 1;

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
      });

  // Pre-release: no databases exist in the wild, and this SQLite file is a
  // derived cache — the real study progress lives in the vault snapshot
  // (srs_state / reviews / applied attempts) and is restored on an empty DB. So
  // there's nothing to migrate: schema v1 just creates every table fresh. Add
  // incremental onUpgrade steps only once there are real users to carry forward.
  @override
  MigrationStrategy get migration =>
      MigrationStrategy(onCreate: (m) => m.createAll());
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
