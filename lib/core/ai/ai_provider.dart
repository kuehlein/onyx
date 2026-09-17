/// How AI is reached (ADR-0004). Onyx is hybrid-but-seamed: a fully key-less core,
/// the user's own key (v1), and a hosted tier reserved for later.
enum AiProvider {
  /// No AI configured — features degrade to an honest "the core still works"
  /// state, never a nag. The default.
  off,

  /// The user's own Anthropic key; the request goes device → Anthropic directly
  /// (local-first). The v1 path.
  byoKey,

  /// The hosted "Onyx AI" tier via the Onyx proxy — no key needed by the user.
  /// **Reserved**: no server exists yet, so the resolver never returns this in v1
  /// (shown as an honest "coming soon" in the UI).
  managed,
}

/// Connection details for the managed "Onyx AI" tier. Null until a server exists
/// (see `managedAiConfigProvider`); reserved seam only.
class ManagedAiConfig {
  const ManagedAiConfig({required this.baseUrl, required this.token});

  /// The Onyx proxy endpoint (same Messages API shape as Anthropic).
  final Uri baseUrl;

  /// The per-account bearer token minted after sign-in.
  final String token;
}

/// Resolves the active [AiProvider]. Precedence: a configured managed tier, then
/// the user's own key, else [AiProvider.off]. In v1 [managed] is always null, so
/// this is byo-key-or-off. The explicit user chooser (Onyx AI / my key / not now)
/// layers on top later; this is the default resolution.
AiProvider resolveAiProvider({
  required bool hasKey,
  ManagedAiConfig? managed,
}) {
  if (managed != null) return AiProvider.managed;
  if (hasKey) return AiProvider.byoKey;
  return AiProvider.off;
}
