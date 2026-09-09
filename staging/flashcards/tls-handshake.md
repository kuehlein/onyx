---
id: tls-handshake
type: flashcard
tags:
  - networking
  - security
tiers:
  networking: 2
created: 2026-09-08
confidence: high
priority: normal
---

# TLS Handshake (How HTTPS Works)

The [TLS](_meta/glossary.md#tls) handshake is the negotiation that runs before any application data on an HTTPS connection. It does three things at once: it authenticates the server (via a certificate the client validates against a trust chain), performs an authenticated key exchange (ephemeral Diffie-Hellman, so a future key compromise cannot decrypt past traffic — forward secrecy), and derives the symmetric session keys that encrypt the rest of the connection. The core principle: expensive asymmetric crypto is used *once* to bootstrap cheap symmetric crypto for the bulk data. TLS 1.3 (RFC 8446) completes this in a single round trip because the client optimistically sends its key share in the first message.

> [!tip] Recognition
> Reach for this reasoning when you see: HTTPS/[TCP](_meta/glossary.md#tcp) connection latency dominated by setup, an interviewer asking "what happens before the first byte of a request," certificate/[PKI](_meta/glossary.md#pki) validation errors, "why is the first request to a new host slow," tuning connection reuse / [RTT](_meta/glossary.md#rtt) budgets on intercontinental paths, or a security question about man-in-the-middle interception and forward secrecy.

## When to Use

**Problem signals that make the handshake the thing to reason about:**
- "The first request to a cold connection is slow, later ones are fast" — handshake RTT cost amortized by connection reuse
- "Why can't a passive eavesdropper decrypt captured traffic even if they later steal the private key?" — this is the forward-secrecy property of the ephemeral key exchange
- The design needs server authentication over an untrusted network (public internet, mobile clients)
- Latency budgeting: each handshake RTT is a full network round trip *before* application data flows
- A security review asks how man-in-the-middle is prevented, or how certificates are validated

**Prefer TLS 1.3 over TLS 1.2 when:**
- You control both ends (or can require modern clients) — 1-RTT vs 2-RTT halves setup latency
- You want forward secrecy guaranteed, not optional — 1.3 removes static-RSA key exchange entirely

**Prefer session resumption / 0-RTT over a full handshake when:**
- A client reconnects to a host it recently spoke to — resumption skips the certificate exchange
- BUT only send 0-RTT early data for safe/[idempotent](_meta/glossary.md#idempotency) requests (see Trade-offs)

**Do not reach for handshake-level reasoning when:**
- The question is about *what* is sent (methods, status codes, headers) rather than *how the channel is secured* → that is the HTTP layer, not TLS

**vs. the confusable siblings — pick by what the question is actually about:**

| If the distinguishing signal is… | It's this card, not TLS handshake |
|---|---|
| Request/response semantics: methods, status codes, headers, "what does HTTPS add over HTTP" at the *protocol* level | **http-https** (the handshake is the mechanism HTTPS uses; http-https is the application protocol on top) |
| The math/primitive: key pairs, "why can anyone encrypt but only the holder decrypt," signing vs encrypting | **public-key-cryptography** (TLS *uses* it to authenticate + agree a key; it isn't the primitive itself) |
| Choosing *which kind* of cipher and why (speed, key distribution problem, one-shared-key vs key-pair) | **symmetric-vs-asymmetric-encryption** (TLS's whole point is *combining* both; this card is about the negotiation that switches from one to the other) |

The one-line discriminator: **the TLS handshake is the negotiation phase** that bootstraps a secure channel — it consumes public-key crypto and the symmetric/asymmetric distinction as ingredients, and it is what HTTPS runs before HTTP data. If the question is about an ingredient or the layer above, it's a sibling card.

## Key Properties

**What the handshake establishes (all three, not just encryption):**
- **[Authentication](_meta/glossary.md#authentication)** — the server proves identity with an X.509 certificate; the client verifies the signature chain up to a trusted root certificate authority. Encryption without this is useless: you'd have a private channel to an unknown party.
- **Key agreement** — both sides derive the *same* symmetric key without ever transmitting it, via ephemeral (EC)DHE. Only public key shares cross the wire.
- **Forward secrecy** — because the DH keys are ephemeral (fresh per session), compromising the server's long-term private key later does not decrypt previously recorded sessions.

**TLS 1.3 1-RTT message flow (the load-bearing sequence):**
1. **ClientHello** — client sends supported versions, cipher suites, and its **key_share** (a DH public value) *speculatively*, plus SNI (the hostname it wants, so a server hosting many sites picks the right cert).
2. **ServerHello** — server picks the cipher, returns *its* key_share. Both sides can now compute the shared secret; everything after this point is encrypted.
3. Same flight, now encrypted: **EncryptedExtensions**, **Certificate**, **CertificateVerify** (signature proving the server holds the cert's private key), **Finished**.
4. Client validates the cert chain, sends its **Finished**. Application data can flow — one round trip total.

**Chain of trust:** the leaf cert is signed by an intermediate CA, signed (transitively) by a root CA in the client's trust store. The client walks this chain; a break, expiry, or untrusted root fails the handshake.

## Trade-offs

| | TLS 1.2 | TLS 1.3 (RFC 8446) |
|---|---|---|
| Handshake round trips | 2-RTT | **1-RTT** (0-RTT on resumption) |
| Forward secrecy | Optional (static-RSA suites allowed) | **Mandatory** (ephemeral-only) |
| Post-ServerHello encryption | No — cert visible in clear | Yes — cert and extensions encrypted |
| Legacy/weak ciphers | Present (RC4, CBC, etc.) | Removed |

**Full handshake vs session resumption:**
- Full: authenticates via certificate, costs a round trip + asymmetric signature verification.
- Resumption (PSK from a prior session): skips re-sending/re-verifying the certificate; cheaper, and enables 0-RTT.

**0-RTT early data — the key exam trap:**
- 0-RTT lets a resuming client send application data *in its first message*, before the handshake finishes — saving a round trip.
- It is NOT forward-secret for that early data, and it is **replayable**: an attacker can capture and re-send the encrypted early-data records ([replay attack](_meta/glossary.md#replay-attack)).
- Therefore 0-RTT is only safe for [idempotent](_meta/glossary.md#idempotency) requests (e.g. a GET). Never put a non-idempotent action (charge card, POST an order) in 0-RTT early data.

## Common Pitfalls

- **"TLS just encrypts."** It also *authenticates* the server — dropping certificate validation (e.g. `verify=False`, ignoring cert errors) leaves you encrypting a channel straight to a man-in-the-middle. Encryption without authentication is not security.
- **Sending non-idempotent requests as 0-RTT early data.** The early data is replayable; a replayed "transfer $100" executes twice. Restrict 0-RTT to safe methods.
- **Confusing session key with the server's private key.** The long-term cert key signs/authenticates; it does not encrypt bulk data. Bulk data uses the ephemeral per-session symmetric key. This separation is *why* forward secrecy is possible.
- **Assuming an expired or self-signed cert still "works over HTTPS."** The handshake fails at chain validation before any data flows; there is no partial/encrypted-but-unverified fallback.
- **Ignoring handshake RTT in latency math.** On a 150 ms intercontinental path, a TLS 1.2 2-RTT handshake adds ~300 ms *before* the request. This is why connection reuse, resumption, and TLS 1.3 matter — and why [CDN](_meta/glossary.md#cdn) edge termination near the user is a latency win.
- **Forgetting SNI is sent in the clear (in standard TLS 1.3).** The hostname in ClientHello reveals which site you're visiting to on-path observers; only the rest of the handshake is encrypted. (Encrypted ClientHello / ECH addresses this but is not universally deployed.)

## Implementation Notes

Reference points, not memorization targets:

- **Inspect a live handshake:** `openssl s_client -connect example.com:443 -tls1_3` shows the negotiated version, cipher, and the presented certificate chain.
- **View the cert chain:** `openssl s_client -connect host:443 -showcerts`, or `curl -vI https://host` for a quick verify path.
- **mTLS** (mutual TLS, [mTLS](_meta/glossary.md#mtls)): the server also requests a client certificate — the client sends its own Certificate + CertificateVerify. Used in zero-trust service meshes; operationally heavier (client-side PKI, rotation).
- **Certificate Transparency** (CT): CAs log issued certs to public append-only logs so misissuance is detectable; browsers may require SCTs.
- **Where termination happens** matters: a load balancer / CDN often terminates TLS at the edge, then re-encrypts (or not) to origin. This changes where the private key lives and where plaintext is exposed.

## Resources

- RFC 8446 — TLS 1.3: https://www.rfc-editor.org/rfc/rfc8446
- RFC 8446 §2.3 — 0-RTT Data and anti-replay: https://www.rfc-editor.org/rfc/rfc8446#section-2.3
- High Performance Browser Networking (Grigorik), Ch. 4 (TLS): https://hpbn.co/transport-layer-security-tls/
- Cloudflare — A Detailed Look at RFC 8446 (TLS 1.3): https://blog.cloudflare.com/rfc-8446-aka-tls-1-3/

## Related

- [[http-https]]
- [[tcp]]
- [[dns]]
- [[authentication]]
- [[cdn]]
- [[load-balancing]]
