import 'dart:convert';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/coach/coach_update.dart' show LoadFeel;
import '../../core/settings/preferences_repository.dart';
import 'database.dart';

part 'settings.g.dart';

/// Typed access to the key/value preferences table.
@Riverpod(keepAlive: true)
PreferencesRepository preferencesRepository(Ref ref) =>
    PreferencesRepository(ref.watch(appDatabaseProvider));

/// The cap on brand-new sections introduced per day (see [dailyNewRemaining],
/// which subtracts what's already been learned today). Persisted in the
/// preferences table; defaults to a deliberately gentle 8 — the start of the
/// recommended ramp (see docs/learning-science.md + the Settings study-load
/// help). Too many new items at once raises cognitive load and hurts retention;
/// the coach ramps this up as retention holds. Step is 1 so the coach's small
/// (+3) nudges land exactly.
@Riverpod(keepAlive: true)
class NewCardLimit extends _$NewCardLimit {
  static const prefKey = 'new_section_limit';
  static const defaultValue = 8;
  static const min = 2;
  static const max = 50;
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

/// The Algorithms track's daily size as a RANGE, paced against both clocks:
/// - [AlgoDailyMin] is the floor — a light or quiet day still gets at least this
///   many, topped up with new problems (and, only if the deck is exhausted, a
///   soonest-due re-solve pulled slightly early) so you're never left with a
///   near-empty session.
/// - [AlgoDailyMax] is the ceiling — the most that's scheduled on a heavy day,
///   so a pile of due re-solves can't blow up into an unsustainable session.
///
/// Bounds are grounded in interview-prep guidance: ~1–2 problems/day is
/// sustainable long-term, 3–4 is intense, 5+ risks burnout and shallow retention
/// (mitigated here by spaced re-solving). See docs/algorithm-track-design.md.
@Riverpod(keepAlive: true)
class AlgoDailyMin extends _$AlgoDailyMin {
  static const prefKey = 'algo_daily_min';
  static const defaultValue = 1; // gentle ramp start (weeks 1–2: 1–2/day)
  static const min = 1;
  static const max = 10;
  static const step = 1;

  @override
  Future<int> build() async {
    final raw = await ref.watch(preferencesRepositoryProvider).get(prefKey);
    return int.tryParse(raw ?? '') ?? defaultValue;
  }

  Future<void> set(int value) async {
    final clamped = value.clamp(min, max);
    await ref.read(preferencesRepositoryProvider).set(prefKey, '$clamped');
    // Keep the ceiling at or above the floor.
    final currentMax = await ref.read(algoDailyMaxProvider.future);
    if (currentMax < clamped) {
      await ref.read(algoDailyMaxProvider.notifier).set(clamped);
    }
    ref.invalidateSelf();
  }
}

/// The daily ceiling for the Algorithms track (see [AlgoDailyMin]).
@Riverpod(keepAlive: true)
class AlgoDailyMax extends _$AlgoDailyMax {
  static const prefKey = 'algo_daily_max';
  static const defaultValue = 2; // gentle ramp start; coach raises it over time
  static const min = 1;
  static const max = 12;
  static const step = 1;

  @override
  Future<int> build() async {
    final raw = await ref.watch(preferencesRepositoryProvider).get(prefKey);
    return int.tryParse(raw ?? '') ?? defaultValue;
  }

  Future<void> set(int value) async {
    final clamped = value.clamp(min, max);
    await ref.read(preferencesRepositoryProvider).set(prefKey, '$clamped');
    // Keep the floor at or below the ceiling.
    final currentMin = await ref.read(algoDailyMinProvider.future);
    if (currentMin > clamped) {
      await ref.read(algoDailyMinProvider.notifier).set(clamped);
    }
    ref.invalidateSelf();
  }
}

/// The opt-in weekly "how's the load feeling?" check-in. Off by default (a
/// recurring prompt can nag; the learner opts in). When on, the coach asks at
/// most weekly on a calm day and factors the answer into its load suggestions.
class LoadCheckInState {
  const LoadCheckInState({
    this.enabled = false,
    this.lastAsked,
    this.feel,
    this.feelAt,
  });

  final bool enabled;
  final DateTime? lastAsked; // last asked or answered (drives weekly cadence)
  final LoadFeel? feel; // most recent answer
  final DateTime? feelAt; // when that answer was given

  Map<String, dynamic> _toJson() => {
        'enabled': enabled,
        'lastAsked': lastAsked?.toIso8601String(),
        'feel': feel?.name,
        'feelAt': feelAt?.toIso8601String(),
      };

  static LoadCheckInState fromRaw(String? raw) {
    if (raw == null || raw.isEmpty) return const LoadCheckInState();
    try {
      final j = jsonDecode(raw) as Map<String, dynamic>;
      LoadFeel? feel;
      for (final f in LoadFeel.values) {
        if (f.name == j['feel']) feel = f;
      }
      DateTime? date(Object? v) => v is String ? DateTime.tryParse(v) : null;
      return LoadCheckInState(
        enabled: j['enabled'] == true,
        lastAsked: date(j['lastAsked']),
        feel: feel,
        feelAt: date(j['feelAt']),
      );
    } catch (_) {
      return const LoadCheckInState();
    }
  }
}

@Riverpod(keepAlive: true)
class LoadCheckIn extends _$LoadCheckIn {
  static const prefKey = 'load_checkin';

  @override
  Future<LoadCheckInState> build() async {
    final raw = await ref.watch(preferencesRepositoryProvider).get(prefKey);
    return LoadCheckInState.fromRaw(raw);
  }

  Future<void> _persist(LoadCheckInState s) async {
    await ref
        .read(preferencesRepositoryProvider)
        .set(prefKey, jsonEncode(s._toJson()));
    state = AsyncData(s);
  }

  LoadCheckInState get _current =>
      state.asData?.value ?? const LoadCheckInState();

  Future<void> setEnabled(bool enabled) async {
    final c = _current;
    await _persist(LoadCheckInState(
      enabled: enabled,
      lastAsked: c.lastAsked,
      feel: c.feel,
      feelAt: c.feelAt,
    ));
  }

  /// Record an answer (also resets the weekly cadence).
  Future<void> record(LoadFeel feel, DateTime now) async => _persist(
        LoadCheckInState(
          enabled: _current.enabled,
          lastAsked: now,
          feel: feel,
          feelAt: now,
        ),
      );

  /// Snooze without answering (asked again in a week).
  Future<void> snooze(DateTime now) async {
    final c = _current;
    await _persist(LoadCheckInState(
      enabled: c.enabled,
      lastAsked: now,
      feel: c.feel,
      feelAt: c.feelAt,
    ));
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
