# ADR 0004 — AI provider seam (BYO-key now, managed tier reserved)

- **Status:** Accepted
- **Date:** 2026-09-17
- **Deciders:** Kyle Uehlein (+ AI-assisted scaffolding)
- **Related:** `docs/product-direction.md` §6 (AI stance), `docs/content-creation.md`
  §2.2, `docs/registry-and-sync.md` §5 (managed infra), `docs/ux-rework-stage1.md`
  P1-1. Code: `lib/core/ai/claude_service.dart`, `lib/core/ai/ai_provider.dart`,
  `lib/shared/providers/ai.dart`. Phase-0 of `docs/roadmap.md`.

## Context

AI was BYO-Anthropic-key only: `ClaudeService` hardcoded the Anthropic endpoint +
an `x-api-key` header, and `claudeServiceProvider` built one iff a key was present.
The product direction is **hybrid but seamed**: a fully key-less core, the user's
own key (v1), and a hosted **"Onyx AI"** managed tier for non-technical users
(reserved — it needs a server + accounts, deferred). Getting a non-technical learner
AI must not require pasting an Anthropic key.

Constraint: `ClaudeService(apiKey:, client:)` is constructed in ~18 test sites and
`ai.dart`. The seam must not churn those.

## Decision

**1. Parameterize the transport, keep BYO-key the default.**
- `ClaudeService`'s primary constructor stays **signature-identical**
  (`{required apiKey, client}`) — BYO-key, device→Anthropic with `x-api-key`. Zero
  blast radius on existing callers/tests. Internally it now holds a generic
  `_endpoint` + `_authHeaders`.
- Add `ClaudeService.managed({baseUrl, token, client})` — device→Onyx proxy with an
  `Authorization: Bearer` header. The proxy fronts the model provider (same Messages
  API shape), so no user key is needed. **Reserved**; unused in v1.

**2. Resolve the active provider explicitly.**
- `enum AiProvider { off, byoKey, managed }` + a **pure** `resolveAiProvider({hasKey,
  managed})` (precedence: managed config → byoKey → off).
- `managedAiConfigProvider` returns `null` in v1 (no server) — the reserved seam.
- `aiProviderProvider` computes the state; `claudeServiceProvider` builds the
  matching transport (off→null, byoKey→`ClaudeService(...)`, managed→`.managed(...)`).
  Its null-when-off contract is **unchanged**, so the ~10 UI gate sites
  (`claudeService != null`) keep working untouched.

**3. Provider-neutral vocabulary.** User-facing surfaces say **"AI," never
"Claude"/"Anthropic"** (leaking a vendor re-privileges it the way "vault" leaked
Obsidian). The ~10 hardcoded "Add your Anthropic API key" strings + the JIT 3-way
chooser sheet (`Onyx AI (coming soon)` · `Use my key` · `Not now`) are a **UI
copy-sweep fill-in** (a separate unit), reading `aiProvider` for the honest state.

## Alternatives considered

- **Rewrite `ClaudeService`'s constructor to take endpoint/headers directly.**
  Rejected — breaks ~18 `ClaudeService(apiKey:)` sites for no gain; the factory adds
  the managed path without churn.
- **A base-URL string knob only.** Rejected — auth differs (`x-api-key` vs
  `Bearer`); a per-transport factory is clearer and type-safe.
- **Do the UI copy sweep + chooser here.** Deferred — it's ~10 widget edits + a new
  sheet (UI fill-in); folding it in would break the one-reviewable-unit rule.

## Consequences

- **Positive:** the managed tier is a one-line factory + a `managedAiConfig`
  provider away — the whole hosted-AI story is unblocked without a server; BYO-key +
  key-less-core behavior is byte-identical; the seam is pure-testable.
- **Trade-offs / follow-ups (not here):** the managed **server** itself (proxy +
  per-account quota + billing + the `quota-exhausted` state — `registry-and-sync.md`
  §5); the **UI copy sweep** ("Anthropic API key" → "AI") + the JIT tier chooser +
  the Settings "AI" 3-state row (`settings-ux.md` §2); wiring `managedAiConfig` to a
  signed-in account (ADR-0002 accounts).

## Validation

- `test/unit/claude_service_test.dart`: `ClaudeService.managed` posts to the given
  `baseUrl` with an `Authorization: Bearer` header and **no** `x-api-key`; the
  existing BYO-key tests (x-api-key + Anthropic endpoint) still pass unchanged.
- `test/unit/ai_provider_test.dart` (pure): `resolveAiProvider` → `off` with no key,
  `byoKey` with a key, `managed` when a config is present (precedence).
- Full suite green (the coach/report/planner provider tests exercise
  `claudeServiceProvider` end-to-end; the null-when-off contract is preserved).
