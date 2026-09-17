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

  /// Merge the vault snapshot into local progress; refresh dependents. Returns
  /// the number of sections after the merge. Non-destructive (ADR-0001).
  Future<int> restore() async {
    final restored = await _service()?.restore() ?? 0;
    ref.invalidate(srsStatesProvider);
    ref.invalidate(reviewQueueProvider);
    ref.invalidate(learnQueueProvider);
    return restored;
  }
}

/// Runs once on startup: if the vault holds a snapshot, **merge** it into local
/// progress. The merge is convergent and non-destructive (last-review-wins on
/// keyed state, union on the event logs — ADR-0001), so it is safe to run on
/// every launch against a non-empty DB: it reconciles progress from other devices
/// synced into the folder (fresh install, lost DB, or a second device) without
/// ever dropping local progress. Refreshes the queues afterward so counts reflect it.
@Riverpod(keepAlive: true)
Future<void> startupRestore(Ref ref) async {
  // Resolve any persisted on-device folder ref first (ADR-0002), so the source
  // exists before we merge the snapshot (ADR-0001). Registered before the await;
  // read (not watch) the deps afterward to avoid a disposed-element on re-settle.
  final loaded = ref.watch(loadVaultRefProvider.future);
  await loaded;
  final source = ref.read(vaultSourceProvider);
  if (source == null) return;
  final service = SnapshotService(ref.read(appDatabaseProvider), source);
  if (await service.hasSnapshot()) {
    await service.restore();
    ref.invalidate(srsStatesProvider);
    ref.invalidate(reviewQueueProvider);
    ref.invalidate(learnQueueProvider);
  }
}
