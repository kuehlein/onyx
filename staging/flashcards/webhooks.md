---
id: webhooks
type: flashcard
tags:
  - backend
  - api-design
tiers:
  backend: 2
created: 2026-09-08
confidence: high
priority: normal
---

# Webhooks

A webhook is a server-to-server HTTP callback: instead of the consumer repeatedly polling the provider for changes, the provider POSTs an event to a URL the consumer registered, the moment the event happens. It inverts control ("don't call us, we'll call you") to trade polling latency and wasted requests for an always-listening HTTP endpoint the consumer must operate. Because delivery rides on best-effort HTTP with provider-side retries, the model is [at-least-once](_meta/glossary.md#at-least-once-delivery): the consumer is responsible for [idempotency](_meta/glossary.md#idempotency), fast acknowledgement, and authenticating that the request genuinely came from the provider.

> [!tip] Recognition
> Reach for webhooks when you see: "notify us when X happens" / "real-time update from a third party" (Stripe payment succeeded, GitHub push, Twilio SMS delivered); a consumer currently **polling an API on a timer** just to detect changes; a provider offering a "register a callback URL" or "event subscriptions" feature; or a requirement to react to events across an org/company boundary without giving the other side database access.

## When to Use

- **Event-driven notification across a trust/network boundary**, where the *provider* knows when something happens and the *consumer* wants to react promptly — this is the core fit.
- **Replacing polling**: the consumer is hitting a third-party API on an interval to detect changes, wasting requests and adding latency. Webhooks push the change instead.
- **Do NOT use when** both services are inside *your own* infrastructure and you need durability/ordering/fan-out/[backpressure](_meta/glossary.md#backpressure) — use a message queue or event bus instead (a webhook is a raw HTTP POST with no broker to buffer or replay).
- **Do NOT use when** the consumer can't expose a reachable HTTPS endpoint (behind NAT, a mobile client, strict egress-only firewall) — polling or a streaming pull ([SSE](_meta/glossary.md#sse)/WebSocket/long-poll) fits better.

## Key Properties

- **Direction / control inversion**: provider initiates an outbound HTTP POST to the consumer's registered URL. This is the defining trait vs. polling (see contrast below).
- **Delivery semantics = at-least-once**: the provider retries on non-2xx/timeout, so the same event can arrive more than once, out of order, and duplicated. Ordering is NOT guaranteed.
- **Acknowledgement contract**: the consumer signals success by returning a **2xx quickly**; any non-2xx or a timeout is read as failure and triggers a retry.
- **Retry + dead-letter**: providers retry with [exponential backoff](_meta/glossary.md#exponential-backoff) over hours, then stop after N attempts ([dead-letter](_meta/glossary.md#dead-letter-queue) / disable the endpoint). Missed events are recovered by a separate reconciliation/list API, not by the webhook alone.
- **Authenticity via [HMAC](_meta/glossary.md#hmac)**: the request carries a signature = `HMAC(shared_secret, payload)` in a header; the consumer recomputes it to prove the request came from the provider and wasn't tampered with.

## Trade-offs

**vs. Polling** (the consumer pulls on a timer): webhooks give near-real-time delivery and eliminate wasted empty polls, but require the consumer to run a public, always-available, secured HTTP endpoint and to handle retries/duplicates. Polling is simpler and works behind a firewall, at the cost of latency and load. Contrast cue: **who initiates the HTTP call** — provider (webhook) vs. consumer (polling).

**vs. Message queue** (see `[[message-queues]]`): a queue puts a durable **broker in between** producer and consumer, giving buffering, ordered/replayable delivery, backpressure, and consumer-paced pull. A webhook is a direct provider→consumer HTTP POST with **no broker** — if the consumer is down past the retry window, the event is lost (recover via reconciliation). Contrast cue: **is there a broker holding messages?** No = webhook; yes = queue. Common production pattern: webhook handler validates + enqueues onto an internal queue, then returns 2xx.

**vs. Idempotency** (see `[[idempotency]]`): idempotency is the *general property* that reprocessing a request causes no additional effect; a webhook consumer is one *place you must apply* it (dedupe on event id) because delivery is at-least-once. Contrast cue: idempotency is the technique; the webhook is the situation that forces you to use it.

**vs. REST API design** (see `[[rest-api-design]]`): a REST API is a *request/response* interface the consumer *calls* (consumer initiates, expects a synchronous response); a webhook is the *reverse* — the provider calls an endpoint the consumer exposes, fire-and-forget with async retries. Contrast cue: **which side initiates and is a response expected** — consumer pulls a synchronous reply (REST) vs. provider pushes and just wants a 2xx ack (webhook). They compose: you register the callback URL via a REST call, then receive webhooks on it.

## Common Pitfalls

- **Not idempotent → double-processing.** At-least-once means retries and duplicates are normal. Dedupe on the provider's stable event id (persist processed ids, or make the write itself idempotent). Do NOT key dedupe on receipt time or a self-generated id.
- **Doing heavy work before returning 2xx.** Slow handlers cause provider timeouts → spurious retries → duplicate work and eventual endpoint disabling. Validate + persist/enqueue, return 2xx fast, process asynchronously.
- **Trusting the payload without verifying the signature.** The URL is effectively public; anyone can POST to it. Verify the HMAC signature, and use a **constant-time** comparison to avoid timing attacks.
- **Verifying against the parsed/re-serialized body.** HMAC must be computed over the exact **raw bytes** received; JSON re-serialization (reordered keys, whitespace) changes the bytes and breaks verification.
- **No [replay](_meta/glossary.md#replay-attack) protection.** A valid captured request can be resent. Providers include a **timestamp in the signed material** and expect you to reject requests outside a tolerance window (commonly ~5 minutes); pair with event-id dedupe to also block same-timestamp replays.
- **Confusing 2xx with "handled correctly."** Return 2xx only after you've durably accepted the event (e.g. committed to a queue/DB). Returning 2xx and then crashing loses the event with no retry.

## Implementation Notes

- Signature scheme (Stripe-style, worth recognizing): header carries a timestamp `t` and `v1 = HMAC_SHA256(endpoint_secret, "<t>.<raw_body>")`; the consumer recomputes over `t + "." + raw_body`, compares in constant time, and rejects if `|now - t|` exceeds tolerance. Prefer the provider's official SDK verify helper over hand-rolling.
- Return 2xx immediately, enqueue the raw event, and process in a background worker; make the worker's write idempotent on `event.id`.
- Always serve the endpoint over HTTPS; treat the signing secret like any other credential (rotate on leak).

## Resources

- Stripe — Webhooks / signature verification: https://docs.stripe.com/webhooks
- GitHub — Validating webhook deliveries (HMAC): https://docs.github.com/en/webhooks/using-webhooks/validating-webhook-deliveries
- webhooks.fyi — vendor-neutral best-practice reference: https://webhooks.fyi/
- svix — Webhook security best practices: https://docs.svix.com/security

## Related

- [[message-queues]]
- [[idempotency]]
- [[rest-api-design]]
- [[api-authentication]]
