import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/readiness/readiness.dart';
import 'srs.dart';
import 'vault.dart';

part 'readiness.g.dart';

/// Knowledge-base readiness (Phase A), derived from the indexed cards + current
/// FSRS stability. Nothing is stored: it recomputes from `srs_state`, which is
/// already synced to the vault snapshot — so readiness persists across devices
/// for free.
@riverpod
Future<Readiness> readiness(Ref ref) async {
  final index = await ref.watch(vaultIndexProvider.future);
  final states = await ref.watch(srsStatesProvider.future);
  final stabilityByKey = {
    for (final e in states.byKey.entries) e.key: e.value.stability,
  };
  return computeReadiness(cards: index.cards, stabilityByKey: stabilityByKey);
}
