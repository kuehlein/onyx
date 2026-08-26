import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/database/database.dart';

part 'database.g.dart';

/// The app-wide SQLite database, kept alive for the process lifetime and closed
/// when the provider is disposed (e.g. at the end of a test).
@Riverpod(keepAlive: true)
AppDatabase appDatabase(Ref ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
}
