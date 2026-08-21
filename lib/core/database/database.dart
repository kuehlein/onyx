import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'tables.dart';

part 'database.g.dart';

@DriftDatabase(
  tables: [SrsStates, Reviews, CardLinks, ActivityLog, CardCache, Preferences],
)
class AppDatabase extends _$AppDatabase {
  /// Production database, backed by a file in the app documents directory.
  AppDatabase() : super(_openConnection());

  /// Injectable executor for tests (e.g. `NativeDatabase.memory()`).
  AppDatabase.withExecutor(super.executor);

  @override
  int get schemaVersion => 1;
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'onyx.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
