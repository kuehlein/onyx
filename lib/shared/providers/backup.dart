import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/backup/snapshot.dart';
import 'database.dart';
import 'learn.dart';
import 'srs.dart';
import 'vault.dart';

part 'backup.g.dart';

/// Coordinates progress backup to the vault snapshot. Writes are debounced so a
/// burst of reviews coalesces into one file write; a flush forces it (session
/// end, app background). Restore replaces local progress from the snapshot.
@Riverpod(keepAlive: true)
class Backup extends _$Backup {
  Timer? _debounce;

  @override
  void build() {
    ref.onDispose(() => _debounce?.cancel());
  }

  SnapshotService? _service() {
    final source = ref.read(vaultSourceProvider);
    if (source == null) return null; // no vault -> nothing to back up to
    return SnapshotService(ref.read(appDatabaseProvider), source);
  }

  /// Debounced write — call after each graded review / graduation.
  void schedule() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 2), () {
      unawaited(_service()?.export() ?? Future<void>.value());
    });
  }

  /// Write immediately (session end, app background).
  Future<void> flush() async {
    _debounce?.cancel();
    await _service()?.export();
  }

  /// Replace local progress with the vault snapshot; refresh dependents.
  /// Returns the number of restored sections.
  Future<int> restore() async {
    final restored = await _service()?.restore() ?? 0;
    ref.invalidate(srsStatesProvider);
    ref.invalidate(reviewQueueProvider);
    ref.invalidate(learnQueueProvider);
    return restored;
  }
}

/// Runs once on startup: if the local DB has no progress but the vault holds a
/// snapshot (fresh install / lost database), restore it — never overwriting an
/// existing local DB. Refreshes the queues afterward so counts reflect it.
@Riverpod(keepAlive: true)
Future<void> startupRestore(Ref ref) async {
  final source = ref.watch(vaultSourceProvider);
  if (source == null) return;
  final service = SnapshotService(ref.watch(appDatabaseProvider), source);
  if (await service.isDbEmpty() && await service.hasSnapshot()) {
    await service.restore();
    ref.invalidate(srsStatesProvider);
    ref.invalidate(reviewQueueProvider);
    ref.invalidate(learnQueueProvider);
  }
}
