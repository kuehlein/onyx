import '../settings/preferences_repository.dart';
import 'vault_ref.dart';

/// Persists the chosen content-source [VaultRef] in the key/value preferences
/// table (SQLite, not the vault — the ref is device-local config, not study
/// content or progress). See ADR-0002.
class VaultRefStore {
  VaultRefStore(this._prefs);

  final PreferencesRepository _prefs;

  static const _key = 'vault_ref';

  /// The persisted ref, or null if none is saved (or it was cleared/malformed).
  Future<VaultRef?> load() async => VaultRef.decode(await _prefs.get(_key));

  /// Persist [ref] as the current content source.
  Future<void> save(VaultRef ref) => _prefs.set(_key, ref.encode());

  /// Forget the saved ref (stores an empty value, which [load] reads as null —
  /// the preferences table has no delete).
  Future<void> clear() => _prefs.set(_key, '');
}
