import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/settings/preferences_repository.dart';
import 'database.dart';

part 'settings.g.dart';

/// Typed access to the key/value preferences table.
@Riverpod(keepAlive: true)
PreferencesRepository preferencesRepository(Ref ref) =>
    PreferencesRepository(ref.watch(appDatabaseProvider));

/// The cap on brand-new sections introduced per day (see [dailyNewRemaining],
/// which subtracts what's already been learned today). Persisted in the
/// preferences table; defaults to 20. Keeping it modest is deliberate — too many
/// new items at once raises cognitive load and hurts retention (see
/// docs/learning-science.md).
@Riverpod(keepAlive: true)
class NewCardLimit extends _$NewCardLimit {
  static const prefKey = 'new_section_limit';
  static const defaultValue = 20;
  static const min = 5;
  static const max = 50;
  static const step = 5;

  @override
  Future<int> build() async {
    final raw = await ref.watch(preferencesRepositoryProvider).get(prefKey);
    return int.tryParse(raw ?? '') ?? defaultValue;
  }

  Future<void> set(int value) async {
    final clamped = value.clamp(min, max);
    await ref.read(preferencesRepositoryProvider).set(prefKey, '$clamped');
    ref.invalidateSelf();
  }
}

/// The daily target for the Algorithms track — how many problems to (re)solve or
/// explain per day. Paces the algo queue so you get a consistent, achievable
/// session instead of "0 some days, a pile on others". Persisted; defaults to 3.
@Riverpod(keepAlive: true)
class AlgoDailyGoal extends _$AlgoDailyGoal {
  static const prefKey = 'algo_daily_goal';
  static const defaultValue = 3;
  static const min = 1;
  static const max = 15;
  static const step = 1;

  @override
  Future<int> build() async {
    final raw = await ref.watch(preferencesRepositoryProvider).get(prefKey);
    return int.tryParse(raw ?? '') ?? defaultValue;
  }

  Future<void> set(int value) async {
    final clamped = value.clamp(min, max);
    await ref.read(preferencesRepositoryProvider).set(prefKey, '$clamped');
    ref.invalidateSelf();
  }
}

/// Gym mode: a between-sets rest timer shown on the review screen, with the
/// coach hidden (review-only). Research-backed — reviewing already-learned
/// material in short bursts during rest is a fine use of time, while new
/// learning and mock interviews need focus you don't have mid-workout.
class GymModeState {
  const GymModeState({required this.enabled, required this.restSeconds});

  final bool enabled;
  final int restSeconds;
}

@Riverpod(keepAlive: true)
class GymMode extends _$GymMode {
  static const _enabledKey = 'gym_mode_enabled';
  static const _restKey = 'gym_rest_seconds';
  static const defaultRest = 60;
  static const minRest = 20;
  static const maxRest = 180;
  static const step = 10;

  @override
  Future<GymModeState> build() async {
    final prefs = ref.watch(preferencesRepositoryProvider);
    final enabled = (await prefs.get(_enabledKey)) == 'true';
    final rest = int.tryParse(await prefs.get(_restKey) ?? '') ?? defaultRest;
    return GymModeState(enabled: enabled, restSeconds: rest);
  }

  Future<void> setEnabled(bool value) async {
    await ref.read(preferencesRepositoryProvider).set(_enabledKey, '$value');
    ref.invalidateSelf();
  }

  Future<void> setRest(int seconds) async {
    final clamped = seconds.clamp(minRest, maxRest);
    await ref.read(preferencesRepositoryProvider).set(_restKey, '$clamped');
    ref.invalidateSelf();
  }
}
