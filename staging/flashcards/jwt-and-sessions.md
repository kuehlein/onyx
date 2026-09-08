---
id: jwt-and-sessions
type: flashcard
tags:
  - security
  - auth
tiers:
  security: 1
created: 2026-09-08
confidence: high
priority: normal
---

# JWT and Sessions

A [JWT](_meta/glossary.md#jwt) is a signed, self-contained credential — `header.payload.signature`, each part base64url-encoded — that lets any service holding the verification key authenticate a request *statelessly*, with no session lookup. That is its whole value proposition and its central weakness: because state lives in the token, not the server, you get horizontal scalability for free but lose the one thing a server-side session gives you cheaply — instant revocation. The signature proves integrity (the claims weren't tampered with), not confidentiality (the payload is readable by anyone). Every real-world JWT decision is a trade against that stateless-vs-revocable axis.

> [!tip] Recognition — interview signals this topic is in play
> - "How do you authenticate requests across a fleet of stateless services / microservices?" — the stateless-verification pitch
> - "How do you log a user out / revoke access immediately?" — the revocation problem, the #1 JWT gotcha
> - "Where do you store the token in a browser?" — cookie-vs-`localStorage`, XSS/CSRF trade
> - "A user's token was stolen — what's your blast radius?" — bearer-token theft + expiry window
> - Any mention of `alg`, `none`, RS256→HS256, or "we verify the token ourselves" — algorithm-confusion territory
> - "Sessions vs tokens, which and why?" — the core design question

## When to Use

**Reach for stateless JWTs when:**
- You have many independent services that must verify identity without a shared session store or a network hop to an auth service — verification is a local signature check
- The token is short-lived and used as an *access* token (minutes, not days), so the no-revocation window is bounded
- You're doing cross-domain / third-party authorization (OAuth 2.x access tokens, OIDC ID tokens) where a self-describing, verifiable credential is the interoperable format

**Prefer server-side sessions when:**
- You need immediate, reliable logout / ban / privilege-change enforcement — a session is deleted server-side and the next request is dead on arrival
- It's a classic first-party web app with a single backend (or a shared session store like Redis is already cheap) — a session cookie is simpler and strictly more revocable
- The auth state changes often (roles, entitlements) — sessions read fresh state every request; a JWT is frozen at issue time until it expires

**Do not use JWTs when:**
- You're tempted to make them long-lived to "avoid re-login" → you've built an unrevocable credential with a huge theft window; use a short access token + rotating refresh token instead
- You need to store sensitive data in them → the payload is *signed, not encrypted*; anyone can base64url-decode it (use JWE / encrypt if you truly must, but prefer keeping [PII](_meta/glossary.md#pii) out entirely)
- A plain opaque random session ID + a lookup would do → don't add cryptographic surface area you don't need

## Key Properties

**Structure (three base64url parts, dot-separated):**
- **Header** — JSON: `{"alg":"RS256","typ":"JWT","kid":"..."}`. `alg` names the signing algorithm; `kid` selects which key (enables rotation).
- **Payload** — JSON claims. Base64url-decodable by anyone — *readable, not secret*.
- **Signature** — computed over `BASE64URL(header) + "." + BASE64URL(payload)` with the signing key (per RFC 7515 JWS). Base64url is the URL-safe alphabet of RFC 4648 §5 with `=` padding stripped.

**Standard registered claims (RFC 7519 §4.1) — all optional but semantically fixed:**

| Claim | Meaning | Verification duty |
|---|---|---|
| `exp` | Expiration time (NumericDate) | Reject if `now ≥ exp` — bounds the theft/revocation window |
| `iat` | Issued at | Detect stale tokens; supports max-age policies |
| `nbf` | Not before | Reject if `now < nbf` |
| `sub` | Subject (the principal) | The "who" — your user id |
| `aud` | Audience (intended recipients) | Reject if *your* service id isn't in `aud` — stops token reuse across services |
| `iss` | Issuer | Reject if not your trusted issuer — pins who minted it |
| `jti` | Unique token id | Enables replay detection and per-token denylisting |

**Signing algorithm families:**
- **HS256 (HMAC-SHA-256)** — symmetric [MAC](_meta/glossary.md#mac) ([HMAC](_meta/glossary.md#hmac), [SHA](_meta/glossary.md#sha)-256). One shared secret both signs and verifies. Simple, fast, but every verifier can also *forge*. Fine within one trust boundary.
- **RS256 (RSA-SHA-256)** — asymmetric. Private key signs; the public key (distributable freely, e.g. via JWKS) only verifies. Use when verifiers are untrusted or numerous. ES256 ([ECDSA](_meta/glossary.md#ecdsa)) is the smaller-key modern equivalent.

## Common Pitfalls

These are real, exploited vulnerabilities — verify against OWASP before shipping any of this.

- **`alg: none` acceptance.** The JWS spec defines an unsecured `"none"` algorithm (empty signature). A library that honors the *token's* `alg` header will accept an unsigned, attacker-forged token. **Fix:** verify with a server-side allow-list of algorithms; never trust `alg` from the token, and never permit `none`.
- **RS256→HS256 algorithm confusion (key confusion).** If your code calls a generic `verify(token, key)` that picks the algorithm from the header, an attacker switches `alg` to `HS256` and signs with your *public* RSA key as the HMAC secret. Since the public key is, well, public, the forgery verifies. **Fix:** pin the exact expected algorithm per key; keep symmetric and asymmetric keys in separate code paths.
- **Missing / unchecked `exp`.** A token with no expiry (or a verifier that ignores it) is a permanent credential — theft is game over forever. **Always set and enforce `exp`; keep access-token lifetimes short (minutes).**
- **Not validating `iss` / `aud`.** Without these, a token minted for service A (or by a different tenant/issuer sharing a key) is replayable against service B. Pin both.
- **Weak / shared HMAC secret.** HS256 with a guessable or short secret is brute-forceable offline (the signed input is fully visible). Use a high-entropy random secret (≥256 bits); never a password. If deriving from a passphrase, stretch with a [KDF](_meta/glossary.md#kdf) like [PBKDF2](_meta/glossary.md#pbkdf2)/Argon2 — but prefer a raw random key.
- **Treating the payload as secret.** Base64url is encoding, not encryption. Putting passwords, PII, or secrets in claims leaks them to anyone who sees the token.
- **`localStorage` storage → XSS exfiltration.** JS-readable storage means any injected script steals the token. Prefer an `HttpOnly` cookie (see Trade-offs).
- **No revocation plan.** Assuming "the token expires eventually" is fine for logout/ban is the classic senior-level miss (see below).

## Trade-offs

**Stateless JWT vs server-side session — the core axis:**

| | Stateless JWT | Server-side session |
|---|---|---|
| Verification | Local signature check, no DB hit | Lookup in session store per request |
| Revocation | **Hard** — valid until `exp` | **Trivial** — delete the record |
| Horizontal scale | No shared state needed | Needs shared/sticky store |
| Auth state freshness | Frozen at issue time | Read fresh every request |
| Payload size | Sent every request, grows with claims | Small opaque id |

**The revocation problem (the crux).** A signed JWT is valid until `exp` no matter what — you can't "unsign" it. Options, none free:
- **Short access-token TTL + refresh tokens** — the standard answer. Access tokens live minutes; a stateful, revocable refresh token mints new ones. Revoking = invalidating the refresh token; worst-case exposure is the short access-token window.
- **Denylist by `jti`** — store revoked token ids until their `exp`. Reintroduces a per-request lookup — you've partially given back statelessness for correctness. Often the right trade.
- **Bump a per-user `token_version`** claim and reject mismatches — forces a lookup of the user's current version.

**Storage: `HttpOnly` cookie vs `localStorage`:**
- **`HttpOnly`, `Secure`, `SameSite` cookie** — invisible to JS, so XSS can't read it. But cookies auto-attach to requests → **CSRF** exposure. Mitigate with `SameSite=Lax/Strict` and/or anti-CSRF tokens. This is the recommended default.
- **`localStorage`** — immune to CSRF (not auto-sent) but fully **XSS-readable**; a single injected script exfiltrates the token. XSS is the more common and more damaging class, so this trade usually loses.
- Net: prefer `HttpOnly` cookie + CSRF defense over `localStorage`. Bearer tokens in an `Authorization` header (common for pure APIs / native apps) sidestep CSRF but push storage security onto the client app.

## Implementation Notes

**Verification checklist (order matters — cheap/structural checks first):**
1. Parse and split into three parts; enforce the expected `alg` from a **server-side allow-list** (ignore the token's `alg` for the *decision*), and never accept `none`.
2. Resolve the key by `kid` (from your JWKS / [KMS](_meta/glossary.md#kms)); verify the signature over `header.payload`.
3. Validate claims: `exp` (not expired), `nbf`/`iat` (time-valid), `iss` (trusted issuer), `aud` (this service).
4. Only then trust `sub` and custom claims.

**Concrete token (decoded):**
```
header:  {"alg":"RS256","typ":"JWT","kid":"2026-09-key1"}
payload: {"sub":"u_8421","iss":"https://auth.example.com",
          "aud":"orders-api","iat":1757308800,"exp":1757309700,
          "jti":"7c9e...","roles":["user"]}
signature: RSASSA(BASE64URL(header)+"."+BASE64URL(payload), privKey)
```

**Access + refresh pattern (the production default):**
- Access token: JWT, RS256, `exp` ~5–15 min, sent as `Authorization: Bearer` or in an `HttpOnly` cookie.
- Refresh token: opaque, random, **stored server-side and revocable**; rotate on every use (OAuth 2.1 requires refresh-token rotation or sender-constraining); detect reuse of a rotated token as theft → revoke the whole family.

**Key management:** publish RS256 public keys at a JWKS endpoint keyed by `kid`; rotate by publishing a new `kid` and retiring the old after the max token lifetime. Guard signing keys in a KMS/HSM. For symmetric HS256, use a ≥256-bit random secret from a secrets manager, scoped to one trust boundary.

**Transport:** always over [TLS](_meta/glossary.md#tls) — the signature stops tampering, not eavesdropping; a bearer token on the wire in cleartext is a stolen credential.

## Variants

- **JWE (RFC 7516)** — encrypted (not just signed) JWT when the payload must be confidential. Different structure (five parts). Prefer keeping secrets out of tokens entirely over reaching for JWE.
- **OIDC ID token vs OAuth access token** — both are commonly JWTs but serve different roles: the ID token authenticates the *user to the client*; the access token authorizes *API calls*. Don't send ID tokens to APIs.
- **PASETO / opaque tokens** — alternatives that sidestep JOSE's algorithm-agility footguns (PASETO fixes the algorithm per version; opaque tokens are just random ids validated by lookup, trading statelessness for trivial revocation).
- **OAuth 2.1 note** — folds in current best practice: the **implicit** and **resource-owner-password (ROPC)** grants are removed, **PKCE** is mandatory for all clients, and refresh tokens must rotate or be sender-constrained.

## Resources

- RFC 7519 — JSON Web Token (JWT): https://www.rfc-editor.org/rfc/rfc7519
- RFC 7515 — JSON Web Signature (JWS): https://www.rfc-editor.org/rfc/rfc7515
- OWASP JSON Web Token Cheat Sheet (attacks + mitigations): https://cheatsheetseries.owasp.org/cheatsheets/JSON_Web_Token_Cheat_Sheet.html
- OWASP Session Management Cheat Sheet: https://cheatsheetseries.owasp.org/cheatsheets/Session_Management_Cheat_Sheet.html

## Related

- [[oauth2-and-oidc]]
- [[session-management]]
- [[xss]]
- [[csrf]]
- [[hmac]]
- [[tls]]
- [[password-hashing]]
