import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Stores the Anthropic API key in platform-secure storage — the iOS Keychain
/// on device (libsecret/keyring on Linux desktop). Never written to the vault,
/// the database, or anywhere in the repo.
class ApiKeyStore {
  ApiKeyStore([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const _key = 'anthropic_api_key';

  /// Reads the stored key, or null. Degrades to null if the platform secure
  /// store is unavailable (e.g. no libsecret/keyring on a Linux dev desktop) so
  /// callers see "no key" rather than a hard error — on Linux the
  /// `ANTHROPIC_API_KEY` env fallback is the intended path anyway.
  Future<String?> read() async {
    try {
      return await _storage.read(key: _key);
    } catch (_) {
      return null;
    }
  }

  Future<void> write(String value) => _storage.write(key: _key, value: value);
  Future<void> delete() => _storage.delete(key: _key);
}
