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
