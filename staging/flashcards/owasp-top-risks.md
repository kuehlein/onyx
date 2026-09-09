---
id: owasp-top-risks
type: flashcard
tags:
  - security
tiers:
  security: 2
created: 2026-09-08
confidence: high
priority: normal
---

# OWASP Top Risks

The OWASP Top 10 is a periodically-updated consensus list of the most impactful web-application security risks, meant as an awareness baseline rather than a checklist. Nearly every entry reduces to one principle: **never trust data crossing a trust boundary.** Untrusted input (from the client, another service, or a dependency) must be authorized, validated, and encoded at the boundary where it is used, and every actor should run with the least privilege it needs. Interviews reward naming the *specific defense* per attack class, not reciting the ranking.

> [!tip] Recognition
> Reach for this framing when you see: a user can access another user's resource by changing an ID in the URL (broken access control / IDOR); input is concatenated into a SQL query, shell command, or HTML page; passwords stored with a fast hash or plaintext; a form action that changes state uses only cookie auth (CSRF); a server fetches a URL supplied by the user (SSRF); or a build pulls an unpinned third-party dependency.

## When to Use

Use the Top 10 as a **threat-modeling and review lens**, not a compliance certificate. Walk each data flow and ask "where does untrusted data cross into a place that grants access, runs code, or reveals secrets?" It is the right vocabulary for a design/security-review interview question ("how would you secure this endpoint?"). It is *not* a substitute for a full risk assessment, penetration test, or the more specific OWASP ASVS verification standard.

## Key Properties

**The unifying principles (reconstruct the specific risks from these):**
- **Deny by default + enforce [authorization](_meta/glossary.md#authorization) server-side.** Access control lives on the server for every request, never in the client or hidden UI. This is #1 (Broken Access Control) — the most common and most severe class.
- **Separate code from data.** Injection (SQLi, command, LDAP) happens when input is interpreted as code. Parameterized queries / safe APIs keep the two apart.
- **Encode for the destination context.** XSS is injection into the *browser*; the fix is context-aware output encoding plus a Content Security Policy.
- **Protect data in transit and at rest.** [TLS](_meta/glossary.md#tls) everywhere; slow, [salted](_meta/glossary.md#salt) password hashing (bcrypt/scrypt/Argon2), not [MD5](_meta/glossary.md#md5)/[SHA-256](_meta/glossary.md#sha-256).
- **Least privilege at every boundary,** including outbound: validate/allowlist server-initiated requests to stop SSRF.
- **Trust your supply chain deliberately:** pin and verify dependencies and build artifacts.

## Trade-offs

| Attack | Where it executes | What it abuses | Primary defense |
|---|---|---|---|
| **SQL Injection** | The database engine | Input concatenated into a query | Parameterized queries / prepared statements (not escaping) |
| **XSS** | The victim's **browser** | Untrusted data reflected into a page | Context-aware output encoding + CSP |
| **CSRF** | The victim's browser, but exploits the **server** | The victim's already-authenticated session/cookies | Anti-CSRF token + `SameSite` cookies |
| **SSRF** | The **server** | Server fetching a user-controlled URL | Allowlist outbound destinations; block internal IP ranges |

> [!important] Contrast: XSS vs. CSRF vs. SQLi
> **XSS runs attacker script in the victim's browser** (steals tokens, defaces the page). **CSRF makes the victim's browser send a forged state-changing request that rides their authenticated session** — the attacker never sees the response, they just trigger the action. **SQLi injects into the database query itself.** Mnemonic: XSS = *run script*, CSRF = *ride session*, SQLi = *rewrite query*.

**Contrast vs. [[authentication-vs-authorization]]:** Broken Access Control (#1) is an *authorization* failure (a logged-in user does something they're not permitted to). [Authentication](_meta/glossary.md#authentication) Failures is a separate Top 10 category about *proving identity* (weak passwords, credential stuffing, session fixation). Don't collapse them.

**Contrast vs. [[jwt-and-sessions]]:** That card is about *how* you carry identity between requests (a token vs. server session). The Top 10 is about the *risks* those mechanisms create — e.g. CSRF is largely a cookie-session problem, while a stolen bearer JWT is an authentication/session-handling failure.

## Common Pitfalls

- **Client-side access control only.** Hiding a button or checking a role in JavaScript is not access control; the server must re-check every request. Classic IDOR: `GET /orders/1043` succeeds for another user's order because the server never verifies ownership.
- **Escaping instead of parameterizing** for SQL. Manual escaping is fragile and misses edge cases; use bound parameters. Note: parameterization does **not** protect dynamic identifiers (table/column names) — allowlist those.
- **Confusing XSS and CSRF defenses.** A CSRF token does nothing against XSS, and output encoding does nothing against CSRF. They are different bugs with different fixes.
- **Fast/general-purpose hashes for passwords.** SHA-256 or MD5 (even salted) are too fast — brute-forceable. Use a deliberately slow [KDF](_meta/glossary.md#kdf): bcrypt, scrypt, or Argon2.
- **Treating the ranking as the knowledge.** The order changes each edition (e.g. SSRF was its own #10 in 2021 and was merged into Broken Access Control in 2025); memorizing positions is low value. Memorize the *defense per attack class*.
- **`SameSite` as the only CSRF defense.** `SameSite=Lax/Strict` mitigates most CSRF but has gaps (older browsers, some GET-based flows); pair it with anti-CSRF tokens for state-changing requests.

## Implementation Notes

Reference, not memorize:
- SQLi: use the ORM's parameter binding or the driver's prepared statements; never string-format user input into SQL.
- XSS: rely on the templating engine's auto-escaping; set a strict `Content-Security-Policy` header (e.g. no inline script) as defense-in-depth.
- CSRF: synchronizer-token pattern (framework-provided), plus `Set-Cookie: ...; SameSite=Lax; Secure; HttpOnly`.
- SSRF: resolve and validate the target host against an allowlist; block link-local/private ranges (169.254.0.0/16, 10/8, 127/8, cloud metadata `169.254.169.254`).
- For a deeper verification checklist beyond awareness, use OWASP ASVS.

## Resources

- OWASP Top 10 (current edition, 2025): https://owasp.org/Top10/
- OWASP Cheat Sheet Series (per-defense guidance): https://cheatsheetseries.owasp.org/
- OWASP ASVS (Application Security Verification Standard): https://owasp.org/www-project-application-security-verification-standard/
- MDN — Content Security Policy (CSP): https://developer.mozilla.org/en-US/docs/Web/HTTP/Guides/CSP

## Related

- [[authentication-vs-authorization]]
- [[jwt-and-sessions]]
- [[https-tls]]
- [[input-validation]]
