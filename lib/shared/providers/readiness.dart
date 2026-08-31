import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/interview/critic.dart';
import '../../core/interview/transfer.dart';
import '../../core/readiness/ladder.dart';
import '../../core/readiness/pace.dart';
import '../../core/readiness/readiness.dart';
import '../../core/readiness/target.dart';
import '../../core/readiness/target_service.dart';
import 'clock.dart';
import 'interview.dart';
import 'settings.dart';
import 'srs.dart';
import 'vault.dart';

part 'readiness.g.dart';

/// Per-domain transfer estimates from applied (mock-interview) attempts, plus
/// whether any applied evidence exists at all. When it does, the dashboard
/// graduates from knowledge-base to interview readiness and every in-scope
/// domain is transfer-gated — evidence-less domains fall back to the pessimistic
/// prior, so they're honestly capped rather than credited for unproven transfer.
@riverpod
Future<({Map<String, TransferEstimate> byDomain, bool interview})>
    appliedTransfer(Ref ref) async {
  final index = await ref.watch(vaultIndexProvider.future);
  final repo = ref.watch(appliedRepositoryProvider);
  final now = (await ref.watch(clockProvider.future)).now();
  // Bound the query to a year; older attempts are recency-decayed to ~nil anyway.
  final attempts =
      await repo.attempts(since: now.subtract(const Duration(days: 365)));

  final domains = <String>{
    for (final c in index.cards)
      if (c.domain != null) c.domain!,
  };
  final samples = <String, List<AppliedSample>>{};
  for (final a in attempts) {
    final d = a.domain;
    if (d == null || !domains.contains(d)) continue;
    final ageDays = now.difference(a.occurredAt).inHours / 24.0;
    samples.putIfAbsent(d, () => []).add(AppliedSample(
          // Reconciled coach+critic score (mean) when a second opinion exists.
          score: effectiveApplied01(a.appliedScore, a.verifierScore),
          novel: a.novel,
          ageDays: ageDays < 0 ? 0 : ageDays,
        ));
  }
  return (
    byDomain: {
      for (final d in domains) d: computeTransfer(samples[d] ?? const []),
    },
    interview: attempts.isNotEmpty,
  );
}

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
  final applied = await ref.watch(appliedTransferProvider.future);
  final stabilityByKey = {
    for (final e in states.byKey.entries) e.key: e.value.stability,
  };
  return computeReadinessForTarget(
    cards: index.cards,
    stabilityByKey: stabilityByKey,
    target: target,
    transferByDomain: applied.interview ? applied.byDomain : null,
  );
}

/// Where the current knowledge base sits on the level×company ladder relative
/// to the chosen goal — the "you are here vs. aiming here" gauge. Recomputes
/// from the same cards + FSRS stability, scored against every rung.
@riverpod
Future<LadderPosition> readinessLadderPosition(Ref ref) async {
  final index = await ref.watch(vaultIndexProvider.future);
  final states = await ref.watch(srsStatesProvider.future);
  final target = await ref.watch(readinessTargetControllerProvider.future);
  final applied = await ref.watch(appliedTransferProvider.future);
  final stabilityByKey = {
    for (final e in states.byKey.entries) e.key: e.value.stability,
  };
  return computeLadderPosition(
    cards: index.cards,
    stabilityByKey: stabilityByKey,
    target: target,
    transferByDomain: applied.interview ? applied.byDomain : null,
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
  final today = (await ref.watch(clockProvider.future)).today();
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
