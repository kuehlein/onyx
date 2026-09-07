import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/coach/coach_update.dart';
import 'providers/settings.dart';

/// The load settings the coach can adjust, one per independently-paced track.
/// Shared by the ambient nudge (badge) and the "talk about it" chat so both
/// apply changes the same way.

/// Human label for a coach-adjustable load setting.
String coachSettingLabel(CoachSetting s) => switch (s) {
      CoachSetting.newCardsPerDay => 'New cards/day',
      CoachSetting.algoMin => 'Algorithms/day (fewest)',
      CoachSetting.algoMax => 'Algorithms/day (most)',
    };

/// Apply a signed [delta] to a load [setting] (each notifier clamps to its own
/// range), returning the before/after values for confirmation + undo.
Future<({int before, int after})> applyCoachSetting(
    WidgetRef ref, CoachSetting setting, int delta) async {
  final before = await _read(ref, setting);
  await _set(ref, setting, before + delta);
  return (before: before, after: await _read(ref, setting));
}

/// Set a load [setting] to an absolute [value] — used to undo a change.
Future<void> setCoachSetting(WidgetRef ref, CoachSetting setting, int value) =>
    _set(ref, setting, value);

Future<int> _read(WidgetRef ref, CoachSetting s) => switch (s) {
      CoachSetting.newCardsPerDay => ref.read(newCardLimitProvider.future),
      CoachSetting.algoMin => ref.read(algoDailyMinProvider.future),
      CoachSetting.algoMax => ref.read(algoDailyMaxProvider.future),
    };

Future<void> _set(WidgetRef ref, CoachSetting s, int value) => switch (s) {
      CoachSetting.newCardsPerDay =>
        ref.read(newCardLimitProvider.notifier).set(value),
      CoachSetting.algoMin =>
        ref.read(algoDailyMinProvider.notifier).set(value),
      CoachSetting.algoMax =>
        ref.read(algoDailyMaxProvider.notifier).set(value),
    };
