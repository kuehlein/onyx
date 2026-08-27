import 'dart:io';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/ai/api_key_store.dart';
import '../../core/ai/claude_service.dart';

part 'ai.g.dart';

/// Secure store for the Anthropic API key.
@Riverpod(keepAlive: true)
ApiKeyStore apiKeyStore(Ref ref) => ApiKeyStore();

/// The active API key (null if none). Reactive: saving/clearing refreshes it and
/// anything that depends on [claudeService].
///
/// Dev override: `ANTHROPIC_API_KEY` in the environment wins. This lets AI be
/// tested on a Linux desktop where the libsecret/keyring service isn't available
/// (on device the iOS Keychain works and this var is unset).
@Riverpod(keepAlive: true)
class ApiKey extends _$ApiKey {
  @override
  Future<String?> build() async {
    final env = Platform.environment['ANTHROPIC_API_KEY'];
    if (env != null && env.isNotEmpty) return env;
    return ref.watch(apiKeyStoreProvider).read();
  }

  Future<void> set(String key) async {
    await ref.read(apiKeyStoreProvider).write(key);
    ref.invalidateSelf();
  }

  Future<void> clear() async {
    await ref.read(apiKeyStoreProvider).delete();
    ref.invalidateSelf();
  }
}

/// A ready-to-use Claude client, or null when no key is set. AI features gate on
/// this being non-null (and degrade gracefully when it is null).
@Riverpod(keepAlive: true)
ClaudeService? claudeService(Ref ref) {
  final key = ref.watch(apiKeyProvider).asData?.value;
  if (key == null || key.isEmpty) return null;
  final service = ClaudeService(apiKey: key);
  ref.onDispose(service.dispose);
  return service;
}
