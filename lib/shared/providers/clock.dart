import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/clock.dart';
import '../../core/dev.dart';
import 'settings.dart';

part 'clock.g.dart';

/// The dev-only clock offset in days, persisted so a fast-forward survives
/// restarts. Always 0 in release builds.
@Riverpod(keepAlive: true)
class DevClockOffset extends _$DevClockOffset {
  static const prefKey = 'dev_clock_offset_days';

  @override
  Future<int> build() async {
    if (!isDevDataMode) return 0;
    final raw = await ref.read(preferencesRepositoryProvider).get(prefKey);
    return int.tryParse(raw ?? '') ?? 0;
  }

  Future<void> advance(int days) async {
    final next = (state.asData?.value ?? 0) + days;
    await _save(next);
  }

  Future<void> reset() => _save(0);

  Future<void> _save(int days) async {
    await ref.read(preferencesRepositoryProvider).set(prefKey, '$days');
    state = AsyncData(days);
  }
}

/// The clock everything time-gated should read. Real wall clock in release;
/// wall-clock-plus-dev-offset in debug builds.
@riverpod
Future<Clock> clock(Ref ref) async {
  if (!isDevDataMode) return Clock.real;
  final days = await ref.watch(devClockOffsetProvider.future);
  return Clock(Duration(days: days));
}

/// Dev-only counter of how many simulated "days of study" have been seeded, so
/// the seeding action is cumulative (tap to build a week of progress and watch
/// the dashboard evolve). Reset by "Reset local progress". Always 0 in release.
@Riverpod(keepAlive: true)
class DevSimDay extends _$DevSimDay {
  static const prefKey = 'dev_sim_day';

  @override
  Future<int> build() async {
    if (!isDevDataMode) return 0;
    final raw = await ref.read(preferencesRepositoryProvider).get(prefKey);
    return int.tryParse(raw ?? '') ?? 0;
  }

  Future<void> set(int day) async {
    await ref.read(preferencesRepositoryProvider).set(prefKey, '$day');
    state = AsyncData(day);
  }

  Future<void> reset() => set(0);
}
