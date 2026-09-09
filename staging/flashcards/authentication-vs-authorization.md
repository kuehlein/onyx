---
id: authentication-vs-authorization
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

# Authentication vs Authorization

Authentication (authN) answers *who are you* — it verifies a claimed identity and produces a **principal** (the authenticated subject). Authorization (authZ) answers *what may you do* — it decides whether that already-established principal is permitted to perform a specific action on a specific resource. The single load-bearing principle: **authN establishes identity once; authZ is enforced on every request, per action, at the resource.** Conflating them, or trusting an identity token as if it were a permission grant, is the root of most real-world access-control breaches (OWASP's #1 category).

> [!tip] Recognition — when this distinction is being tested
> - The interviewer asks "how do you secure this endpoint / this service call?" — you must split the answer into *proving identity* and *checking permission*, not lump them as "auth."
> - "User A can see User B's invoice by changing the ID in the URL" — a pure **authZ** failure (IDOR / broken access control), even though authN worked perfectly.
> - "We put the user's role inside the JWT and trust it" — smells like moving the authZ decision to the client / a spoofable token.
> - Any mention of [RBAC](_meta/glossary.md#rbac), scopes, permissions, ACLs, `403 Forbidden` → authZ. Any mention of passwords, MFA, tokens, sessions, mTLS, `401 Unauthorized` → authN.
> - HTTP status tell: **401 = "I don't know who you are" (authN)**, **403 = "I know who you are, you can't do this" (authZ)**.

## When to Use

This is a *decomposition* card, not a single technique — the skill is correctly splitting a security requirement into the authN half and the authZ half and placing each in the request path.

**Problem signals that you must reason about authN vs authZ separately:**
- "Secure this API" / "add auth to this microservice" → always two questions: how is the caller identified, and how is each call permission-checked.
- "Tenant A must never read Tenant B's data" → authZ (object-level / row-level access control), assuming identity is already known.
- "Only admins can delete" → authZ decision keyed on a role/permission of an authenticated principal.
- "Service-to-service calls inside the mesh" → authN via [mTLS](_meta/glossary.md#mtls) (workload identity) + authZ via policy (which service may call which).
- "Log the user in / support Google sign-in / SSO" → authN (federated identity); SSO does not grant any permissions by itself.

**Map the concept correctly:**
- **AuthN mechanisms:** passwords + MFA, session cookies, bearer tokens ([JWT](_meta/glossary.md#jwt) / opaque), API keys, [mTLS](_meta/glossary.md#mtls) client certs, WebAuthn/passkeys.
- **AuthZ models:** RBAC (role → permissions), [ABAC](_meta/glossary.md#abac) (policy over attributes of subject/resource/environment), ACLs (per-object allow/deny lists), OAuth **scopes** (delegated, coarse-grained permissions).
- **Principals & claims:** authN outputs a *principal* described by **claims** (assertions like `sub`, `roles`, `email`); authZ *consumes* those claims to make a decision. Claims are inputs to authZ, never the decision itself.

**Do not conflate:**
- OAuth 2.0 is a **delegated authorization** framework (it issues access tokens for *scopes*), NOT an authentication protocol. Use **OpenID Connect (OIDC)**, the identity layer on top of OAuth, when you actually need to authenticate a user. Treating a raw OAuth access token as proof of "who logged in" is a classic, exploitable mistake.

## Key Properties

- **AuthN happens once per session/request; authZ happens on every protected operation.** A valid token proves identity but says nothing about whether *this* action is allowed.
- **Principal:** the authenticated entity (user, service, device). **Claims:** signed assertions about the principal carried in the credential.
- **Order in the request path:** identify → (establish principal) → authorize → execute. AuthZ must run *server-side*, at (or just before) the resource, after authN has produced a trusted principal.
- **Two token roles are distinct (OIDC/OAuth):** an **ID token** proves authentication to the *client* (`aud` = client_id, "who logged in"); an **access token** authorizes calls to a *resource server* (`aud` = the API). Never send an ID token to an API as authorization, and never use an access token to establish user identity in the client.
- **RBAC vs ABAC:** RBAC scales by grouping permissions into roles (simple, coarse); ABAC evaluates policy over attributes (e.g. `department == resource.owner_dept AND time in business_hours`) for fine-grained, context-aware decisions. Scopes are a *third*, orthogonal axis: what a *delegated client* may do on the user's behalf.
- **Deny-by-default:** the correct authZ posture — every resource is forbidden unless a rule explicitly permits it (OWASP A01 lists violating this as a top failure).
- **`401` vs `403`:** `401 Unauthorized` = authN missing/invalid (misnamed in the RFC — it's really "unauthenticated"); `403 Forbidden` = authenticated but not permitted (authZ).

## Common Pitfalls

These are real, exploited vulnerability classes — getting them wrong is the difference between a secure and a breached service.

- **Broken Object-Level Authorization (IDOR).** Authenticating the user but then trusting a client-supplied ID (`GET /invoices/{id}`) without checking the principal *owns* that object. This is OWASP **A01: Broken Access Control** (the #1 web risk) and OWASP API #1. Fix: every object access re-checks ownership/tenant against the authenticated principal.
- **Missing function-level authZ.** Hiding an admin button in the UI but leaving the endpoint unprotected — authZ enforced only in the client is no authZ. Enforce on the server for every route.
- **Trusting authN as authZ.** "The token is valid, so let them in" — a valid identity is not permission. Always check *what* the principal may do, not just *that* they are authenticated.
- **JWT `alg: none` bypass.** Some libraries honor an attacker-set `"alg":"none"` header and skip signature verification, accepting forged tokens. Fix: reject `none`; pin an explicit expected algorithm on verify (RFC 8725).
- **JWT algorithm-confusion (RS256 → HS256).** If the verifier reads `alg` from the token, an attacker switches an RSA (`RS256`) token to HMAC (`HS256`) and signs it with the *public* [RSA](_meta/glossary.md#rsa) key — which is public — since [HMAC](_meta/glossary.md#hmac) is symmetric and the server uses that same public key as the shared secret. Fix: never let the library pick the algorithm from the header; allow-list one algorithm/key type, and never accept both symmetric and asymmetric for the same key (RFC 8725).
- **Not validating `aud` / `iss` / `exp`.** A verified signature is not enough — a token minted for a *different* service (wrong `aud`) or a different issuer must be rejected. Failing to check audience lets a token for service X be [replayed](_meta/glossary.md#replay-attack) against service Y.
- **Privilege escalation via client-controlled claims.** Deriving roles/permissions from a token field the user can influence, or reading `role` from a request body. Roles must come from a trusted, server-side source bound to the verified principal.
- **Confused-deputy / over-broad scopes.** Granting a delegated client wider OAuth scopes than the task needs; the client (deputy) can then act beyond intent. Request least-privilege scopes.
- **Weak authN feeding strong authZ.** Perfect RBAC is worthless if identity is spoofable — no MFA, credential stuffing / brute force allowed, session fixation. This is OWASP **A07: Identification and Authentication Failures**.

## Trade-offs

- **Stateless tokens (JWT) vs server-side sessions.** JWTs authorize without a DB lookup (scales horizontally) but are **hard to revoke before `exp`** — a compromised or role-downgraded token stays valid until it expires. Sessions are instantly revocable but require shared session state. Mitigate JWTs with short lifetimes + refresh tokens, or a revocation/deny list (which reintroduces state).
- **RBAC vs ABAC.** RBAC is simple to reason about and audit but suffers **role explosion** as fine-grained needs grow. ABAC is expressive and context-aware but policies are harder to author, test, and audit ("can anyone actually reach this data?"). Many systems combine them (roles as one attribute).
- **Centralized policy (e.g. an authZ service / OPA) vs in-service checks.** Central policy gives consistency and one audit point but adds a network hop and a dependency; in-service checks are fast but drift and duplicate logic.
- **Coarse scopes vs fine permissions.** Coarse OAuth scopes are simple for consent screens but over-grant; fine-grained permissions are safer (least privilege) but multiply consent/management complexity.
- **mTLS vs bearer tokens for service auth.** [mTLS](_meta/glossary.md#mtls) gives strong, mutual, transport-bound identity (no token to steal and replay) but needs a [PKI](_meta/glossary.md#pki)/cert-rotation burden; bearer tokens are easy to propagate but are stealable if not sender-constrained.

## Implementation Notes

**Request path (typical stateless API):**
```
1. Client sends credential:  Authorization: Bearer <access_token>   (or presents mTLS cert)
2. AuthN: verify token signature, then iss, aud, exp/nbf  -> derive principal { sub, roles/scopes }
3. AuthZ: policy check  -> may principal do <action> on <resource>?  (deny by default)
4. Execute, or return 401 (step 2 fails) / 403 (step 3 fails)
```

**JWT verification checklist (order matters):**
- Pin the expected algorithm explicitly; reject `none`; do not read `alg` from the token to select the key (RFC 8725).
- Verify signature against the correct key (asymmetric public key for RS/ES; a real secret for HS).
- Validate `exp` (and `nbf`/`iat` with small clock skew), `iss`, and `aud` == this service.
- Only then trust the claims (`sub`, `scope`/`scp`, `roles`).

**OAuth 2.1 / current best practice (RFC 9700, OAuth 2.1 draft):**
- Use **Authorization Code + [PKCE](_meta/glossary.md#pkce)** for all clients (web, SPA, mobile) — PKCE is now required for every authorization-code client, public *and* confidential.
- The **Implicit grant** (`response_type=token`) and the **Resource Owner Password Credentials** grant are **removed/deprecated** — do not use them (tokens in URL fragments leak; ROPC hands the user's password to the client).
- **Client Credentials** grant for machine-to-machine (no user); **Authorization Code + PKCE** for user-facing.
- Use **OIDC** (adds the `id_token`) when you need to *authenticate a user*; use plain OAuth access tokens only to *authorize* API calls.

**AuthZ code shape (server-side, deny-by-default):**
```python
def get_invoice(principal, invoice_id):
    inv = repo.load(invoice_id)
    # object-level check: principal must own / share tenant — prevents IDOR
    if inv is None or inv.tenant_id != principal.tenant_id:
        raise Forbidden()            # 403
    if "invoices:read" not in principal.scopes:
        raise Forbidden()            # 403
    return inv
```

**Credential storage (authN side):** never store passwords reversibly — use a slow, memory-hard password [KDF](_meta/glossary.md#kdf) (Argon2id / bcrypt / scrypt) with a per-user [salt](_meta/glossary.md#salt). Treat any PII in tokens/claims as sensitive. Serve everything over [TLS](_meta/glossary.md#tls); a [MAC](_meta/glossary.md#mac)/signature on a token proves integrity, not confidentiality.

## Variants

- **RBAC** — roles bundle permissions; assign roles to principals. Simple, auditable, coarse.
- **ABAC** — policy engine evaluates attributes of subject, resource, action, and environment. Fine-grained, context-aware.
- **ReBAC (relationship-based)** — permissions follow graph relationships (e.g. Google Zanzibar / OpenFGA): "can read if `owner` or `member of parent folder`." Scales object-level authZ.
- **ACL** — explicit per-object allow/deny entries. Precise but hard to manage at scale.
- **Delegated authorization (OAuth scopes)** — a third party acts on the user's behalf within granted scopes; orthogonal to the user's own RBAC/ABAC rights.
- **PBAC / policy-as-code** — externalized policy (OPA/Rego, Cedar) evaluated by a central decision point.

## Resources

- OWASP Top 10 A01:2021 Broken Access Control — https://owasp.org/Top10/A01_2021-Broken_Access_Control/
- OWASP Top 10 A07:2021 Identification and Authentication Failures — https://owasp.org/Top10/A07_2021-Identification_and_Authentication_Failures/
- RFC 8725 — JSON Web Token Best Current Practices — https://datatracker.ietf.org/doc/html/rfc8725
- RFC 9700 — Best Current Practice for OAuth 2.0 Security — https://datatracker.ietf.org/doc/html/rfc9700

## Related

- [[jwt]]
- [[oauth2]]
- [[openid-connect]]
- [[mtls]]
- [[session-management]]
- [[http-https]]
