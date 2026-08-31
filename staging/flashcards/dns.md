---
id: 7f3a2c1e-9b84-4d56-ae12-0c58f7e63d91
type: flashcard
tags:
  - system-design
  - dns
  - networking
tiers:
  system-design: 1
created: 2026-08-20
confidence: medium
priority: normal
---

# DNS (Domain Name System)

[DNS](_meta/glossary.md#dns) is the distributed, hierarchical naming system that translates human-readable hostnames into [IP](_meta/glossary.md#ip) addresses — it is the internet's phone book, and its recursive resolution model allows billions of mappings to be served globally without any single authority holding the full dataset.

> [!warning] Lower the TTL *before* any planned failover or cutover
> If [TTL](_meta/glossary.md#ttl) is 86 400 s, a change takes up to 24 h to propagate. Drop TTL to 30–60 s hours ahead, and expect stale traffic for up to 2× TTL since some resolvers ignore reductions.

## When to Use

**Problem signals that suggest DNS:**
- Problem asks you to design a globally distributed service where clients need to find the nearest or healthiest endpoint ("route users to the closest data center")
- Interviewer asks how a URL becomes a [TCP](_meta/glossary.md#tcp) connection — DNS is step one
- Problem involves failover, blue/green deployments, or traffic shifting between regions
- Problem mentions canary releases or A/B traffic splitting at the infrastructure level
- Problem involves service discovery within a microservices architecture (internal DNS)
- Any estimation question about web-scale request handling — DNS caching is why servers are not overwhelmed by lookup traffic

**Prefer DNS over alternatives when:**
- Over hardcoded IPs: DNS allows infrastructure to change without client reconfiguration; TTL controls propagation delay
- Over a load balancer alone: DNS-based load balancing (GeoDNS) routes before a packet even reaches your infrastructure, reducing latency for global users
- Over a service mesh alone: DNS is universally supported by every OS, library, and runtime — no sidecar required for basic discovery

**Do not use when:**
- Millisecond-level failover is required → DNS TTL propagation (30 s–5 min typical) is too slow; use a load balancer health check with connection draining instead
- Client-side caching is uncontrollable → aggressive OS/browser DNS caches can ignore TTL, causing stale routing during incidents
- You need session affinity (sticky sessions) → DNS round-robin is stateless; use a layer-4/7 load balancer

## Key Properties

| Property | Typical Value |
|---|---|
| Root name servers | 13 logical roots (hundreds of anycast instances) |
| Recursive resolver cache hit rate | ~80–95% (most queries never reach authoritative servers) |
| Authoritative lookup latency | 10–100 ms round-trip |
| Cached lookup latency | <1 ms (OS resolver cache) |
| TTL range used in practice | 30 s (fast failover) – 86 400 s (stable [CDN](_meta/glossary.md#cdn) assets) |
| DNS record size (typical A record) | ~50–100 bytes |

**Resolution hierarchy (recursive):**
1. Browser/OS cache (TTL-bounded)
2. Recursive resolver (ISP or public: 8.8.8.8, 1.1.1.1)
3. Root nameserver → [TLD](_meta/glossary.md#tld) nameserver (.com, .io)
4. Authoritative nameserver (your zone file)

**Core record types:**
- `A` — hostname → IPv4
- `AAAA` — hostname → IPv6
- `CNAME` — hostname → hostname (canonical alias; cannot be used at zone apex)
- `MX` — mail exchange
- `NS` — delegates a zone to a nameserver
- `TXT` — arbitrary text; used for [SPF](_meta/glossary.md#spf), [DKIM](_meta/glossary.md#dkim), domain verification
- `SOA` — Start of Authority; TTL defaults and zone serial for [AXFR](_meta/glossary.md#axfr)

## Trade-offs

**TTL is the central dial:**

| Short TTL (30–60 s) | Long TTL (3 600–86 400 s) |
|---|---|
| Fast failover / blue-green | High cache hit rate, lower resolver load |
| Higher authoritative query load | Slow propagation during incidents |
| Useful during active migrations | Appropriate for stable, long-lived services |

**DNS-based load balancing vs. layer-7 load balancer:**
- DNS [LB](_meta/glossary.md#lb) is cheaper and globally distributed but cannot detect mid-connection failures; a load balancer can drain connections gracefully
- DNS LB has no session awareness; ELB/[ALB](_meta/glossary.md#alb) can inspect HTTP headers for routing logic

**GeoDNS / Anycast trade-offs:**
- GeoDNS returns different A records per client geography — effective but depends on resolver IP approximating user location (VPN users get wrong region)
- Anycast routes to the topologically nearest instance at the [BGP](_meta/glossary.md#bgp) level — more accurate but requires owning an [AS](_meta/glossary.md#as) and IP block

**Single point of failure risk:**
- Authoritative servers should be in at least two independent providers (e.g., Route 53 + NS1) — a DNS outage makes your entire service unreachable regardless of backend health

**[DNSSEC](_meta/glossary.md#dnssec):**
- Adds cryptographic signing to prevent cache poisoning (Kaminsky attack)
- Increases response size and resolver CPU; adds operational complexity for key rotation
- Required in high-security / government / financial contexts

## Implementation Notes

**Typical architecture patterns:**

*Global traffic management ([GTM](_meta/glossary.md#gtm)):*
- Host authoritative DNS with a managed provider (AWS Route 53, Cloudflare, NS1)
- Use latency-based or geolocation routing policies to return the nearest regional endpoint
- Set TTL to 60 s during deployment windows; raise to 300 s during steady state

*Health-check-gated DNS failover:*
- Route 53 health checks poll endpoints every 10–30 s
- On failure, the DNS record is replaced with a secondary (failover record)
- Client sees the change after its cached TTL expires — plan for up to 2× TTL of stale traffic

*Internal service discovery (microservices):*
- Use a private DNS zone (e.g., `internal.example.com`) via Route 53 Private Hosted Zones or CoreDNS in Kubernetes
- Services register as `service-name.namespace.svc.cluster.local` (Kubernetes DNS convention)
- Sidecars (Envoy/Istio) intercept DNS and add [mTLS](_meta/glossary.md#mtls), retries, and circuit breaking on top

*CDN origin shielding via [CNAME](_meta/glossary.md#cname) chain:*
```
assets.example.com CNAME → d1abc.cloudfront.net → edge POP
```
- Using a CNAME (not A record) lets the CDN update its IPs without requiring your zone change
- CNAME at apex is illegal per [RFC](_meta/glossary.md#rfc) 1034 — use [ALIAS](_meta/glossary.md#alias)/[ANAME](_meta/glossary.md#aname) records (Route 53) or CNAME flattening (Cloudflare) instead

*DNS for blue/green deployments:*
- Blue: `api.example.com` → `10.0.1.5` (current prod)
- Shift: update record to point to green cluster; TTL determines blast radius window
- Lower TTL to 30 s ~1 h before planned cutover to minimize stale-cache exposure

## Common Pitfalls

- **Forgetting TTL pre-lowering:** If TTL is 86 400 s and you need to fail over, you wait up to 24 h for all caches to expire. Always lower TTL hours before a planned change.
- **CNAME at zone apex:** `example.com CNAME something.else.com` is invalid per RFC. Use ALIAS or ANAME records at the apex.
- **Assuming DNS is instantaneous during incidents:** Resolvers are not obligated to honor TTL reductions; some ISP resolvers aggressively cache. Design failover to tolerate partial stale routing.
- **Relying on source IP for GeoDNS:** The resolver IP (not client IP) is used for geo-lookup. [EDNS](_meta/glossary.md#edns) Client Subnet ([ECS](_meta/glossary.md#ecs)) partially addresses this but is opt-in.
- **DNS amplification in DDoS:** Open resolvers can be used to amplify [UDP](_meta/glossary.md#udp) traffic. Authoritative servers should restrict recursion; use rate limiting and anycast to absorb volumetric attacks.

## Resources

- RFC 1034 / RFC 1035 — original DNS specification
- AWS Route 53 Developer Guide: https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/
- Cloudflare DNS learning center: https://www.cloudflare.com/learning/dns/what-is-dns/
- *Designing Data-Intensive Applications* — Chapter 1 (reliability/scalability framing applicable to DNS [SLA](_meta/glossary.md#sla)s)
- *System Design Interview Vol. 1* (Alex Xu) — Chapter 1 introduces DNS in the scale-from-zero walkthrough

## Related

- [[consistent-hashing]]
- [[load-balancing]]
- [[cdn]]
- [[http]]
- [[networking]]
