---
id: api-versioning
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

# API Versioning

API versioning is the discipline of evolving a network API's *contract* without breaking clients you no longer control. The governing principle is: **make additive, [backward-compatible](_meta/glossary.md#backward-compatibility) changes the default and reserve a version bump for genuinely breaking changes.** Adding an optional field, a new endpoint, or a new enum value that old clients can ignore requires no version at all; renaming a field, removing one, changing a type, or altering semantics does. When you must break, you run *multiple versions in parallel* behind an explicit deprecation-and-sunset window rather than flipping a switch. This differs from [schema evolution](_meta/glossary.md#schema-evolution) at the serialization layer: same compatibility problem, different altitude (see contrast below).

> [!tip] Recognition
> Reach for a versioning strategy when you see: a **public or third-party-consumed API** whose clients you can't force-upgrade; a proposed change that **removes/renames a field or changes a type or its meaning** (breaking); "old mobile app builds are still in the field for months"; "partners integrated against last year's contract"; or a request like "we need to change the response shape without breaking existing integrations."

## When to Use

- **Version only on a breaking change.** Additive, backward-compatible edits (new optional field, new endpoint, new optional query param, new enum value tolerated by clients) ship on the *same* version — do not bump.
- **Breaking changes** (remove/rename a field, change a field's type or units, tighten validation, change error/status semantics, make an optional param required) require a new version served *alongside* the old one.
- **Public / partner / mobile APIs** need explicit versioning because clients upgrade on their own schedule (or never). Internal APIs behind a single deploy can often evolve with coordinated rollout and skip formal versioning.
- Choose **URI path** (`/v1/`) as the safe default for public REST APIs; choose **header / media-type** when you want stable URLs and control the clients.

## Key Properties

Two mainstream placements for the version selector:

| | URI path (`/v1/users`) | Header / media-type (`Accept: application/vnd.api.v2+json`) |
|---|---|---|
| Visibility | Explicit, obvious in logs/URLs | Hidden in headers |
| HTTP caching / [CDN](_meta/glossary.md#cdn) | Caches cleanly out of the box (distinct URLs) | Needs `Vary: Accept` or caches serve the wrong version |
| Testability | Trivial (paste URL in a browser/curl) | Harder (must set headers) |
| URI cleanliness | Version pollutes every path | Clean, resource-identity-pure URIs |
| Adoption | Most common in practice | REST-purist; less common |

- A third style, **date-based versioning** (`2026-08-26` via header, used by Stripe and GitHub), keeps one URL path and pins each account/request to a dated snapshot — a date sorts cleanly and maps to a changelog entry.
- **Deprecation lifecycle:** signal via the `Deprecation` header (RFC 9745), then the `Sunset` header (RFC 8594) with the HTTP-date of removal; the sunset date MUST NOT precede the deprecation date. Give clients a real window (often months).

## Trade-offs

- **URI path vs. header:** path wins on cache-friendliness, discoverability, and testability (why it dominates in practice); header/media-type wins on URI purity and stable resource identity. Pick path unless you have a specific reason not to.
- **Additive evolution vs. versioning:** additive changes avoid the multiplying cost of maintaining N live versions but constrain you to never break the existing shape; a version bump buys freedom to redesign at the cost of running and testing old + new in parallel.
- **Sunset speed vs. client goodwill:** short windows cut maintenance burden but strand slow-moving clients (long-lived mobile builds, partners); long windows are safer but you carry old code longer.
- **Coarse (whole-API `/v2/`) vs. fine (per-endpoint / per-field) versioning:** coarse is simple to reason about but forces a big-bang migration; fine-grained (date snapshots, feature flags) is smoother for clients but far more complex to implement and test.

## Common Pitfalls

- **Versioning for changes that aren't breaking.** Adding an *optional* field or a new endpoint doesn't break well-behaved clients — bumping the version for it explodes version count needlessly. Reserve bumps for real breaks.
- **Clients that break on additive changes.** The flip side: if consumers reject unknown fields (strict deserializers) or assume a closed enum, even additive changes break them. Design/document clients to *tolerate the unknown* (ignore extra fields, handle new enum values).
- **Never sunsetting.** Shipping `/v2/` but keeping `/v1/` alive forever multiplies maintenance, test surface, and security exposure. Version bumps are worthless without an enforced deprecation + sunset plan.
- **Silent breaking changes within a version.** Changing a field's meaning/units, tightening validation, or altering error semantics *without* a bump is the most dangerous case — clients keep parsing successfully but behave wrong.
- **URL-versioning a header-versioned client (or vice versa) inconsistently**, or forgetting `Vary: Accept` on header-versioned responses — the CDN then serves v1 bytes to a v2 request.

> [!warning] Contrast — API versioning vs. data-encoding / schema evolution
> **Same problem (evolve without breaking consumers), different layer.** Schema evolution (Avro/Protobuf/Thrift) solves compatibility at the **wire/serialization** level — field tags, reader/writer schemas, defaults — so producers and consumers of *encoded bytes* interoperate across versions. API versioning solves it at the **HTTP contract** level — endpoints, status codes, resource shapes, and *how a client selects a version* (path vs. header). Distinguishing signal: schema evolution = "how do I encode/decode across versions"; API versioning = "how does a client request a version and how do I deprecate one."

> [!note] Contrast — vs. rest-api-design
> `rest-api-design` covers *what a good API looks like at a point in time* (resource modeling, verbs, status codes, pagination, [idempotency](_meta/glossary.md#idempotency)). API versioning covers *how that contract changes over time* without breaking existing clients. Distinguishing signal: design = the current contract; versioning = its evolution and deprecation.

## Implementation Notes

- **Path:** route `/v1/...` and `/v2/...` to separate handler sets or a translation layer that upconverts old requests to the new internal model.
- **Header / media-type:** parse `Accept: application/vnd.<vendor>.v2+json` (a vendor MIME type) or a custom `API-Version:` header; always emit `Vary: Accept` so caches key on it.
- **Deprecation signaling:** emit `Deprecation: <http-date | true>` (RFC 9745) and `Sunset: <http-date>` (RFC 8594), plus a `Link` (RFC 8288) with `rel="sunset"` / `rel="deprecation"` pointing to migration docs; return `410 Gone` after the sunset date.
- Publish a changelog and machine-readable diff; instrument per-version usage so you know when it's safe to remove a version.

## Resources

- RFC 8594 — The Sunset HTTP Header Field: https://www.rfc-editor.org/rfc/rfc8594.html
- RFC 9745 — The Deprecation HTTP Response Header Field: https://www.rfc-editor.org/rfc/rfc9745.html
- Stripe API versioning & upgrades: https://docs.stripe.com/api/versioning
- Microsoft REST API Guidelines — Versioning: https://github.com/microsoft/api-guidelines/blob/vNext/Guidelines.md#12-versioning

## Related

- [[rest-api-design]]
- [[data-encoding-schema-evolution]]
- [[backward-forward-compatibility]]
- [[http-https]]
- [[idempotency]]
