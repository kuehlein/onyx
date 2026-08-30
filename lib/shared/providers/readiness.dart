import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/readiness/pace.dart';
import '../../core/readiness/readiness.dart';
import '../../core/readiness/target.dart';
import '../../core/readiness/target_service.dart';
import 'settings.dart';
import 'srs.dart';
import 'vault.dart';

part 'readiness.g.dart';

/// The interview being prepared for (level × company × track + optional date).
/// Loaded from the synced vault meta file when present (so it follows the user
/// across devices), falling back to a device-local preferences mirror, then to
/// a sensible default.
@Riverpod(keepAlive: true)
class ReadinessTargetController extends _$ReadinessTargetController {
  static const _prefKey = 'readiness_target';

  @override
  Future<ReadinessTarget> build() async {
    final source = ref.watch(vaultSourceProvider);
    if (source != null) {
      final fromVault = await TargetService(source).load();
      if (fromVault != null) return fromVault;
    }
    final raw = await ref.read(preferencesRepositoryProvider).get(_prefKey);
    return ReadinessTarget.tryDecode(raw) ?? ReadinessTarget.fallback;
  }

  /// Persist a new target: to the vault (for cross-device sync) and to the local
  /// preferences mirror, then update state so the dashboard reflects it at once.
  Future<void> save(ReadinessTarget target) async {
    await ref
        .read(preferencesRepositoryProvider)
        .set(_prefKey, target.encode());
    final source = ref.read(vaultSourceProvider);
    if (source != null) await TargetService(source).save(target);
    state = AsyncData(target);
  }
}

/// Knowledge-base readiness (Phase A), derived from the indexed cards + current
/// FSRS stability, weighted toward the chosen target. Nothing extra is stored:
/// it recomputes from `srs_state` (already synced to the vault snapshot) and the
/// synced target — so readiness persists across devices for free.
@riverpod
Future<Readiness> readiness(Ref ref) async {
  final index = await ref.watch(vaultIndexProvider.future);
  final states = await ref.watch(srsStatesProvider.future);
  final target = await ref.watch(readinessTargetControllerProvider.future);
  final stabilityByKey = {
    for (final e in states.byKey.entries) e.key: e.value.stability,
  };
  final domains = <String>{
    for (final c in index.cards)
      if (c.domain != null) c.domain!,
  };
  return computeReadiness(
    cards: index.cards,
    stabilityByKey: stabilityByKey,
    stabilityTarget: target.stabilityTarget,
    domainWeights: {for (final d in domains) d: domainWeight(target, d)},
  );
}

/// Coverage pace toward the target's interview date, or null when no date is
/// set. Projects from the recent new-sections-per-day rate over a 14-day window.
@riverpod
Future<PaceEstimate?> readinessPace(Ref ref) async {
  final target = await ref.watch(readinessTargetControllerProvider.future);
  final date = target.interviewDate;
  if (date == null) return null;

  final r = await ref.watch(readinessProvider.future);
  final remaining = r.domains.fold(0, (a, d) => a + (d.total - d.studied));

  const window = 14;
  final today = _todayLocal();
  final started = await ref
      .watch(srsRepositoryProvider)
      .sectionsStartedSince(today.subtract(const Duration(days: window)));

  return computePace(
    today: today,
    interviewDate: DateTime(date.year, date.month, date.day),
    remainingSections: remaining,
    recentPerDay: started / window,
  );
}

DateTime _todayLocal() {
  final n = DateTime.now();
  return DateTime(n.year, n.month, n.day);
}
