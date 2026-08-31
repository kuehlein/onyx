---
id: 7f3a1c2e-84b5-4d9f-a6e8-1c0b2d3e4f5a
type: flashcard
tags:
  - system-design
  - cdn
  - networking
  - caching
tiers:
  system-design: 1
created: 2026-08-20
confidence: low
priority: normal
---

# Content Delivery Network (CDN)

A [CDN](_meta/glossary.md#cdn) is a geographically distributed network of edge servers that cache and serve content from locations physically close to end users, reducing latency by eliminating round trips to the origin server. It works because network latency scales with physical distance and hop count — serving bytes from 50 km away instead of 5,000 km cuts response time from hundreds of milliseconds to single digits.

> [!tip] Reach for a CDN for static, cacheable content served to a global audience
> Images, video, JS/CSS bundles, media streaming, geographically distributed users. It offloads 80–95% of requests and absorbs traffic spikes at the edge. Skip it for highly personalized or faster-than-[TTL](_meta/glossary.md#ttl) dynamic data.

## When to Use

**Problem signals that suggest a CDN:**
- The system serves static assets: images, videos, JS bundles, CSS, audio files, PDFs
- The problem mentions "global users" or "worldwide availability" or a user base spread across multiple continents
- The interviewer asks how you'd reduce latency for reads at scale
- The system involves media streaming (YouTube, Netflix, Spotify-style)
- You're designing a social platform where profile images, posts with attachments, or feed thumbnails are read far more than written
- Throughput estimates reveal bandwidth that a single origin cluster cannot economically serve (> 1 Gbps sustained)
- The problem mentions "DDoS protection" or "traffic spikes" (CDNs absorb burst traffic at the edge)
- A read-heavy API with relatively stable responses (e.g. public catalog data, sports scores, weather) that could be edge-cached

**Prefer a CDN over alternatives when:**
- Over application-layer caching (Redis/Memcached): user is geographically distributed — in-region application caches still require a cross-ocean [TCP](_meta/glossary.md#tcp) connection; CDN edge nodes serve from within 50 ms of the user
- Over scaling up the origin: CDN offloads 80–95% of requests entirely, making origin capacity a small fraction of what you'd otherwise need; cost per GB served at the edge is typically 2–5x cheaper than origin egress
- Over replicating full origin servers to each region: CDN caches on-demand (no pre-seeding required for most content), simpler operational model, no database replication complexity

**Do not use when:**
- Content is highly personalized and cannot be shared across users → application-layer cache keyed per user, or skip caching
- Data changes faster than your minimum TTL allows (real-time order books, live auction state) → serve directly from origin or use WebSockets/[SSE](_meta/glossary.md#sse)
- Regulatory requirements mandate data not leave a specific jurisdiction → CDN [PoP](_meta/glossary.md#pop) placement may violate data-residency laws; use regional origin clusters with strict geo-routing instead

## Key Properties

| Property | Typical value |
|---|---|
| Edge-to-user latency | 5–50 ms (vs. 100–500 ms cross-continent) |
| Cache hit rate (well-tuned) | 80–95% of requests |
| Origin offload | 85–99% for static assets |
| TTL range | 0 s (bypass) to 1 year (immutable assets) |
| PoP count (major CDNs) | 70–1,000+ cities globally (Fastly ≈70, Cloudflare ≈330+, Akamai ≈1,000+) |

**How a request resolves:**
1. User's [DNS](_meta/glossary.md#dns) query routes to the nearest CDN PoP via Anycast or latency-based DNS.
2. Edge node checks its cache (HIT → respond immediately; MISS → fetch from origin).
3. Edge stores the response and serves subsequent requests until TTL expires.

**Push vs. Pull CDN:**
- **Pull (most common):** Edge fetches from origin on first cache miss; subsequent requests are served from cache. Zero pre-configuration; slight delay on cold start.
- **Push:** Operator explicitly uploads content to edge nodes ahead of demand. Useful for large assets with predictable demand (software releases, video-on-demand libraries).

## Trade-offs

**Latency vs. freshness (the core CDN tension):**
Long TTLs maximize cache hit rate and offload but mean users see stale content after an update. Short TTLs keep content fresh but defeat the purpose of caching. Resolution strategies:
- **Cache-busting via URL versioning:** `/app.a3f9b2.js` — set TTL to 1 year; deploy a new hash on every release. Zero stale-content risk.
- **Surrogate keys / cache tags:** CDN APIs (Cloudflare Cache-Tag, Fastly Surrogate-Key) let you purge a logical group of assets atomically without waiting for TTL.
- **Stale-while-revalidate:** Serve stale content immediately while the edge fetches a fresh copy in the background. Balances freshness and hit rate for semi-dynamic content.

**Cost:**
CDN egress pricing is typically $0.01–0.08/GB (vs. $0.08–0.20/GB from cloud provider origin egress). High cache hit rates are critical to realizing this saving — a 50% hit rate means you pay origin egress prices on half your traffic.

**Single point of failure risk:**
A CDN outage (Fastly June 2021, Akamai July 2021) can take down many sites simultaneously. Mitigations: multi-CDN setup, origin fallback via health checks, or DNS failover.

**Security surface:**
The CDN sits between users and your origin, so it can inspect and terminate [TLS](_meta/glossary.md#tls). This is often desirable (DDoS mitigation, [WAF](_meta/glossary.md#waf), bot detection) but means the CDN provider has access to plaintext traffic. For highly sensitive data, end-to-end encryption or origin-pull with mutual TLS is required.

**Dynamic content:**
Modern CDNs support edge compute (Cloudflare Workers, Lambda@Edge) to execute lightweight logic at PoPs — useful for A/B testing headers, auth token validation, or response personalization without a full origin round trip.

## Implementation Notes

**Architecture pattern — origin shield:**
Add a single designated "shield" PoP between the distributed edge nodes and the origin. All cache misses from edge nodes collapse into requests to the shield, which queries origin only if it too misses. This reduces origin traffic by an additional 60–80% compared to unshielded pull CDN.

```
User → Edge PoP (cache miss) → Shield PoP (cache miss) → Origin
                                              ↑
                    subsequent edge misses hit shield (likely HIT)
```

**Cache-key design decisions (interview talking point):**
The cache key is typically `scheme + host + path + selected query params`. Key mistakes:
- Vary on `User-Agent` → shatters cache into thousands of variants; avoid
- Vary on `Accept-Encoding` → CDN should handle this transparently
- Cache personalized responses without per-user cache isolation (e.g., failing to set `Cache-Control: private` on user-specific endpoints, or letting the CDN cache a `/dashboard` that returns user-specific HTML) → all users share one cached copy; critical security flaw. Fix: set `Cache-Control: private` or `no-store` on any response that is not safe to share across users.

> [!warning] Caching per-user content under a shared key leaks data
> If the CDN caches a user-specific response (e.g. `/dashboard`) without per-user isolation, one user's data is served to everyone. Set `Cache-Control: private` or `no-store` on anything not safe to share.

**Purge strategy comparison:**

| Strategy | Latency to propagation | Use case |
|---|---|---|
| TTL expiry | Up to TTL duration | Tolerant content |
| Tag-based purge | < 1–5 s globally | CMS, product catalog |
| URL purge | < 1 s | Single asset hotfix |
| Wildcard purge | Seconds to minutes | Directory-level invalidation |

**SSL/TLS termination:**
CDN terminates TLS at the edge (reducing TLS handshake RTT for users) and re-establishes a connection to origin. Origin-facing connection can use HTTP over a private network or HTTPS with a CDN-issued certificate. Always require HTTPS on the origin-facing leg in production.

## Common Pitfalls

- **Caching error responses:** A 500 or 404 with a long TTL baked in gets cached and served to users for hours. Explicitly set `Cache-Control: no-store` on error responses, or configure the CDN to never cache 4xx/5xx.
- **Forgetting to set `Vary: Accept-Encoding`** on origin: CDN may serve gzipped content to clients that don't support it, or vice versa.
- **Not purging after deploys:** Deploying new HTML that references old hashed asset URLs works; deploying new HTML without cache busting means users get a stale HTML shell loading new JS — mismatched versions cause runtime errors.
- **Over-relying on CDN for availability:** CDN improves availability but is not a substitute for a resilient origin. If the origin is a single server, CDN only helps until the cache misses.
- **Geo-restriction misconfiguration:** Blocking entire countries at the CDN edge without considering your actual regulatory or business requirements can block legitimate users.

## Resources

- [AWS CloudFront Developer Guide](https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/Introduction.html)
- [Cloudflare Learning — How CDNs Work](https://www.cloudflare.com/learning/cdn/what-is-a-cdn/)
- Alex Xu, *System Design Interview Vol. 1*, Chapter 1 (Scale from Zero to Millions)
- [web.dev — Content delivery networks](https://web.dev/content-delivery-networks/)

## Related

- [[consistent-hashing]]
- [[caching]]
- [[load-balancing]]
- [[dns]]
- [[http]]
