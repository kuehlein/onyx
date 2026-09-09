---
id: oauth2-and-oidc
type: flashcard
tags:
  - security
  - auth
tiers:
  security: 3
created: 2026-09-08
confidence: high
priority: normal
---

# OAuth 2.0 and OpenID Connect

OAuth 2.0 (RFC 6749) is a **delegated [authorization](_meta/glossary.md#authorization)** framework: it lets a user (resource owner) grant a third-party app (client) scoped access to their resources on another service without handing over their password. The core principle is that the client never sees the user's credentials — instead it obtains a short-lived, scoped **access token** from an authorization server and presents it as a bearer credential (RFC 6750) to the resource server. OAuth alone answers *"is this client allowed to do X"*, **not** *"who is this user"*; OpenID Connect (OIDC) layers **[authentication](_meta/glossary.md#authentication)** on top by issuing a signed **[ID token](_meta/glossary.md#jwt)** ([JWT](_meta/glossary.md#jwt)) with verified identity claims. Getting the distinction wrong — using an access token to identify a user — is a classic and dangerous mistake.

> [!tip] Recognition — reach for OAuth2/OIDC when you hear
> - "Let users **sign in with Google/GitHub**" → OIDC (authentication)
> - "Let a third-party app **access a user's data on our API** on their behalf" → OAuth2 authorization code + [PKCE](_meta/glossary.md#pkce)
> - "Our **backend service** needs to call another service's API (no user present)" → Client Credentials
> - "**Single sign-on** across our apps", "delegate access without sharing passwords", "scoped/revocable API tokens"
> - Design red flag in the room: someone proposes putting a **password** in the client, or returning a **token in a URL fragment** — both are deprecated anti-patterns you should flag.
>
> **vs. JWT / sessions:** OAuth2/OIDC is a *delegation & federated-login protocol* (how a client gets tokens from a third party). JWT is just a *token format*, and session-vs-token auth is about *how your own app remembers a logged-in user* — an OIDC ID token often *is* a JWT, but "I use OIDC" ≠ "I use JWT sessions."

## When to Use

**Problem signals for each grant:**
- **Authorization Code + PKCE** — any user-facing app (web app, SPA, mobile, native). The user authenticates at the AS, the client gets a one-time `code` via redirect, then exchanges it server-to-server (or with PKCE) for tokens. This is the default for OAuth 2.1; **PKCE is now required for all clients**, not just public ones.
- **Client Credentials** — machine-to-machine, **no user**. A confidential client authenticates with its own client ID/secret (or [mTLS](_meta/glossary.md#mtls)/private-key JWT) and gets an access token representing itself. Cron jobs, service-to-service calls, backend daemons.
- **OIDC (Auth Code + `openid` scope)** — you need to *authenticate a user* (SSO, "log in with…"). Adds an ID token on top of the OAuth authorization flow.

**Prefer over alternatives when:**
- Over storing the user's password in your app: OAuth exists specifically so the client never sees credentials — you get a scoped, revocable token instead.
- Over rolling your own session/API-key scheme: standardized scopes, expiry, revocation, and federated identity (OIDC) instead of bespoke ACLs.
- Over Client Credentials for user actions: never use Client Credentials to act "as a user" — it carries no user identity and no consent.

**Do not use when:**
- You control both client and server and there is no third party / no delegation → a plain signed session cookie is simpler and avoids token-handling pitfalls.
- You need *authentication* (who is the user) but reach for raw OAuth → you need **OIDC**; an access token is opaque to the client and must never be treated as proof of identity.

## Key Properties

- **Four roles:** resource owner (the user), client (the app requesting access), authorization server (AS — authenticates the user, issues tokens), resource server (the API that accepts access tokens). The AS and resource server are often separate.
- **Access token** — short-lived (minutes–hours) bearer credential presented to the resource server (RFC 6750: `Authorization: Bearer <token>`). May be opaque (introspected via RFC 7662) or a JWT (RFC 9068). Scoped by `scope`. **Meant for the resource server, opaque to the client.**
- **Refresh token** — long-lived credential used only against the AS's token endpoint to mint new access tokens without re-prompting the user. Never sent to resource servers.
- **Scopes** — coarse, space-delimited permission strings (`read:contacts`, `openid`, `email`). Requested by the client, consented by the user, enforced by the resource server.
- **ID token (OIDC)** — a **JWT** the *client* consumes to learn the user's identity. Required claims: `iss`, `sub` (stable, non-reassigned user id), `aud` (MUST contain the client_id), `exp`, `iat`; `nonce` echoes the request nonce; `at_hash` binds it to the access token. This is the only OAuth/OIDC token the client is *supposed* to open and validate.
- **`state`** — opaque CSRF token bound to the user's session, echoed in the redirect. **`nonce`** — OIDC value the AS embeds in the ID token to bind it to this login and prevent [replay](_meta/glossary.md#replay-attack). They defend different links: `state` = the browser callback (CSRF), `nonce` = the ID token (replay), PKCE = the code exchange.

## Common Pitfalls

Security cards live or die here — these are real, exploited vulnerabilities.

- **JWT [algorithm confusion](_meta/glossary.md#algorithm-confusion) (RS256 → HS256).** If verification lets the token pick its own algorithm, an attacker takes the AS's *public* RSA key (from the JWKS endpoint), sets header `alg: HS256`, and signs a forged token using that public key as the HMAC secret — full auth bypass. Also **`alg: none`** (unsigned token accepted). Fix: pin an explicit algorithm **allowlist** server-side (RFC 8725 / JWT BCP); never derive the algorithm from the token header.
- **Not validating ID token claims.** After signature check you MUST verify `iss` (exact match), `aud` (contains your client_id), `exp` (with small clock skew), and `nonce`. Skipping `aud` lets a token minted for *another* client be replayed against yours (token/audience confusion).
- **Using the access token for authentication.** The access token is for the resource server and may be opaque; treating its contents as "who the user is" is a well-known anti-pattern. Use the ID token (or the OIDC UserInfo endpoint) for identity.
- **Open redirect / loose redirect_uri matching.** The AS MUST match `redirect_uri` by **exact string comparison** (OAuth 2.1). Wildcards or substring matches let an attacker steal the authorization code by redirecting to their own URL.
- **Missing `state` → CSRF (login CSRF / code injection).** Without a session-bound `state`, an attacker can splice their own code into a victim's session. PKCE also mitigates code injection; RFC 9700 allows relying on PKCE for this when the AS enforces it.
- **Tokens in the URL / implicit flow leakage.** The implicit grant returned the access token in the URL **fragment**, leaking it via browser history, referrer headers, and logs — this is *why* implicit is dead. Never put tokens in query strings or fragments.
- **Bearer tokens are unbound.** Whoever holds an access token can use it (no proof of possession). Keep them short-lived, use [TLS](_meta/glossary.md#tls) everywhere, and prefer sender-constrained tokens (DPoP / mTLS) for high-value APIs. Never log them.

## Trade-offs

- **Access token lifetime:** short TTL limits blast radius of a leaked token but increases refresh traffic; long TTL is convenient but leaked tokens are usable for longer and revocation of opaque-vs-JWT differs (JWTs can't be individually revoked without a denylist/introspection).
- **JWT (self-contained) vs. opaque + introspection:** JWTs are stateless and fast for the resource server to verify locally, but can't be instantly revoked and expose claims if not encrypted. Opaque tokens allow instant revocation and hide data but add a network hop (RFC 7662 introspection) per request.
- **Refresh token rotation:** rotating (single-use) refresh tokens detect theft (reuse triggers revocation of the family) at the cost of state and edge cases with concurrent/offline clients. OAuth 2.1 deprecates non-rotating bearer refresh tokens — they must be **sender-constrained or rotating**.
- **Scope granularity:** fine-grained scopes give least privilege but explode consent complexity and token size; coarse scopes are simpler but over-grant.

## Implementation Notes

**Authorization Code + PKCE (RFC 7636), the canonical flow:**
1. Client generates a random `code_verifier` (43–128 chars, ≥256 bits entropy) and derives `code_challenge = BASE64URL(SHA256(code_verifier))` with `code_challenge_method=S256`. (`plain` offers no protection — always use S256.)
2. Redirect to AS `/authorize`:
   `?response_type=code&client_id=...&redirect_uri=...&scope=openid%20email&state=<csrf>&nonce=<n>&code_challenge=<c>&code_challenge_method=S256`
3. User authenticates + consents; AS redirects back with `?code=...&state=...`. Client verifies `state` matches.
4. Client POSTs to `/token`: `grant_type=authorization_code&code=...&redirect_uri=...&code_verifier=<v>` (+ client auth if confidential). AS recomputes `SHA256(code_verifier)` and compares to the stored `code_challenge` — this defeats **authorization code interception**, since a stolen code is useless without the verifier.
5. Response: `{ access_token, token_type: "Bearer", expires_in, refresh_token, id_token }`.
6. **OIDC:** validate `id_token` — verify signature against the AS's JWKS (pinned alg allowlist), then `iss`, `aud`==client_id, `exp`, and `nonce`==sent nonce.

**Client Credentials (M2M):**
```
POST /token
grant_type=client_credentials&scope=orders:read
Authorization: Basic base64(client_id:client_secret)   # or private_key_jwt / mTLS
```
Returns an access token only (no refresh token, no ID token — there is no user). Per RFC 9068 the JWT `sub` is the client itself.

**Resource server** (bearer, RFC 6750): read `Authorization: Bearer <token>`, then either verify the JWT locally (JWKS + alg allowlist + `iss`/`aud`/`exp`/scope) or call the AS introspection endpoint for opaque tokens.

## Variants

- **OAuth 2.1** — consolidation draft folding in the security BCP: **removes implicit and ROPC grants**, **requires PKCE** for all auth-code clients, mandates exact redirect_uri matching, and forbids bearer refresh tokens without rotation/sender-constraining.
- **ROPC (Resource Owner Password Credentials)** — deprecated: the client collects the user's password directly, defeating OAuth's whole premise. Only ever a migration crutch.
- **Device Authorization Grant (RFC 8628)** — for input-constrained devices (TVs, CLIs): user completes login on a separate device via a user code.
- **DPoP (RFC 9449) / mTLS-bound tokens** — sender-constrained access tokens (proof of possession) so a stolen bearer token can't be replayed.
- **Token introspection (RFC 7662)** and **JWT access tokens (RFC 9068)** — the two standard ways a resource server validates a token.

## Resources

- OAuth 2.0 — RFC 6749: https://www.rfc-editor.org/rfc/rfc6749
- PKCE — RFC 7636: https://www.rfc-editor.org/rfc/rfc7636
- OAuth 2.0 Security Best Current Practice — RFC 9700 (BCP 240): https://www.rfc-editor.org/rfc/rfc9700
- OpenID Connect Core 1.0: https://openid.net/specs/openid-connect-core-1_0.html
- OWASP JSON Web Token Cheat Sheet: https://cheatsheetseries.owasp.org/cheatsheets/JSON_Web_Token_Cheat_Sheet.html

## Related

- [[jwt]]
- [[tls]]
- [[mtls]]
- [[session-vs-token-auth]]
- [[api-authentication]]
- [[https]]
