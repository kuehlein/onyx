import 'dart:io';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/ai/ai_provider.dart';
import '../../core/ai/api_key_store.dart';
import '../../core/ai/claude_service.dart';

part 'ai.g.dart';

/// Secure store for the user's AI (Anthropic) API key.
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

/// Connection details for the managed "Onyx AI" tier, or null until a server
/// exists. Reserved seam (ADR-0004) — v1 always returns null, so AI resolves to
/// BYO-key-or-off. When the hosted tier ships, this yields the signed-in
/// account's proxy URL + token.
@Riverpod(keepAlive: true)
ManagedAiConfig? managedAiConfig(Ref ref) => null;

/// The active [AiProvider] — off / byoKey / managed (ADR-0004). UI reads this to
/// present the honest state; [claudeService] builds the matching transport.
@riverpod
AiProvider aiProvider(Ref ref) {
  final key = ref.watch(apiKeyProvider).asData?.value;
  return resolveAiProvider(
    hasKey: key != null && key.isNotEmpty,
    managed: ref.watch(managedAiConfigProvider),
  );
}

/// A ready-to-use AI client, or null when AI is off. Features gate on this being
/// non-null (and degrade gracefully when it is null).
@Riverpod(keepAlive: true)
ClaudeService? claudeService(Ref ref) {
  switch (ref.watch(aiProviderProvider)) {
    case AiProvider.off:
      return null;
    case AiProvider.byoKey:
      final key = ref.watch(apiKeyProvider).asData?.value;
      if (key == null || key.isEmpty) return null;
      final service = ClaudeService(apiKey: key);
      ref.onDispose(service.dispose);
      return service;
    case AiProvider.managed:
      final cfg = ref.watch(managedAiConfigProvider);
      if (cfg == null) return null;
      final service =
          ClaudeService.managed(baseUrl: cfg.baseUrl, token: cfg.token);
      ref.onDispose(service.dispose);
      return service;
  }
}
