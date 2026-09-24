import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers/settings.dart';

/// The coach's ONE load lever is the vault **daily study budget** (ADR-0011): the
/// engine derives the mix; the user owns the size; the coach has no per-flow knobs.
/// Shared by the ambient nudge, the weekly check-in, and the "talk about it" chat
/// so all three apply a change the same way — always on the user's tap, with undo.

/// Apply a signed [deltaMinutes] to the daily budget (the notifier clamps to its
/// range), returning the before/after values for confirmation + undo.
Future<({int before, int after})> applyBudgetDelta(
    WidgetRef ref, int deltaMinutes) async {
  final before = await ref.read(dailyTargetMinutesProvider.future);
  await ref
      .read(dailyTargetMinutesProvider.notifier)
      .set(before + deltaMinutes);
  return (
    before: before,
    after: await ref.read(dailyTargetMinutesProvider.future)
  );
}

/// Set the daily budget to an absolute [minutes] — used to undo a change.
Future<void> setBudgetMinutes(WidgetRef ref, int minutes) =>
    ref.read(dailyTargetMinutesProvider.notifier).set(minutes);
