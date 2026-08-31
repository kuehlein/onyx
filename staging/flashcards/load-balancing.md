---
id: 7f3a2c1e-85b4-4d2f-9e6a-1c0d3f8b5a72
type: flashcard
tags:
  - system-design
  - load-balancing
tiers:
  system-design: 1
created: 2026-08-20
confidence: low
priority: normal
---

# Load Balancing

A load balancer distributes incoming traffic across multiple backend servers so that no single server becomes a bottleneck — it is the primary mechanism for achieving horizontal scalability and high availability in distributed systems. It works because the request-response cycle is stateless enough (at the network layer) that any healthy backend can serve any request, given correct session and state handling.

> [!tip] Recognition signal
> "Millions of requests / high [RPS](_meta/glossary.md#rps)", "no single point of failure", "scale horizontally", "zero-downtime deploys", or "handle traffic spikes" all point to a load balancer in front of stateless replicas.

## When to Use

**Problem signals that suggest load balancing:**
- "Design a system that handles millions of requests per day / 10,000 RPS" — single-server throughput ceilings
- "How do you ensure high availability / no single point of failure?" — any mention of uptime [SLA](_meta/glossary.md#sla)s (99.9%, 99.99%)
- "The system needs to scale horizontally" — adding more servers requires a front-door distributor
- "Users are globally distributed" — geographic routing implies regional load balancers
- "The service needs zero-downtime deployments" — rolling deploys drain traffic from individual instances
- "Handle traffic spikes" (e.g., flash sales, viral events) — autoscaling groups need a balancer to register new instances
- Any architecture with multiple replicas of a stateless service (API servers, web servers, microservices)

**Prefer load balancing over alternatives when:**
- Over [DNS](_meta/glossary.md#dns) round-robin: DNS [TTL](_meta/glossary.md#ttl)s commonly range from 300–3600 s (or higher), preventing fast failover because clients cache stale records for minutes to hours; a dedicated [LB](_meta/glossary.md#lb) detects failure in 2–10 s via health checks
- Over client-side load balancing: centralized LBs offload retry/failover logic from every client; appropriate when clients are untrusted (public internet) or heterogeneous
- Over a single powerful server (vertical scaling): horizontal scaling with a load balancer is cheaper beyond a certain size and avoids a single point of failure

**Do not use when:**
- Stateful, connection-pinned protocols with no session affinity strategy → use sticky sessions or move state to a shared store (Redis) before adding a load balancer
- Internal service-to-service calls in a service mesh → use sidecar proxies (Envoy/Istio) with client-side load balancing instead; a central LB adds an unnecessary network hop
- Extremely latency-sensitive paths (sub-millisecond [P99](_meta/glossary.md#p99) targets) → a hardware LB (F5, ASIC-based) or kernel bypass ([DPDK](_meta/glossary.md#dpdk)) may be needed; software LBs add ~0.1–1 ms

## Key Properties

**Layers of operation:**
- **[L4](_meta/glossary.md#l4) (Transport):** Routes [TCP](_meta/glossary.md#tcp)/[UDP](_meta/glossary.md#udp) by [IP](_meta/glossary.md#ip) + port. No HTTP awareness. Lower latency, fewer CPU cycles. Examples: AWS [NLB](_meta/glossary.md#nlb), HAProxy TCP mode.
- **[L7](_meta/glossary.md#l7) (Application):** Inspects HTTP headers, URLs, cookies. Enables path-based routing, header rewrites, A/B testing, WebSocket affinity. Examples: AWS [ALB](_meta/glossary.md#alb), NGINX, Envoy, Traefik.

**Routing algorithms:**
| Algorithm | Best for | Caveat |
|---|---|---|
| Round-robin | Homogeneous backends, uniform request cost | Ignores server load |
| Weighted round-robin | Mixed-capacity backends | Requires manual weight tuning |
| Least connections | Variable-duration requests (file upload, long polls) | Overhead of tracking active connections |
| IP hash | Session affinity without shared state | Uneven distribution if client IPs cluster |
| Random with two choices (Power of Two) | High-throughput, low-overhead | Used in Envoy; not a standard built-in in NGINX |
| Consistent hashing | Caching layers, sharded backends | Complex to implement; see consistent hashing card |

**Health checks:** Active (LB polls `/health` every 5–30 s, 2–3 failures = remove) vs. passive (detect errors in live traffic). Always configure both in production.

**Session affinity (sticky sessions):** LB pins a user to one backend via cookie or IP hash. Enables stateful backends but breaks even distribution and complicates failover — prefer externalizing state to Redis/Memcached.

## Trade-offs

**Horizontal scale vs. operational complexity:**
- Pro: Adding servers behind a LB is fast; AWS autoscaling can register a new instance in 2–5 minutes (instance launch + boot + health check passing)
- Con: Every new layer is a failure domain; the load balancer itself must be made HA (active-active pair or anycast)

**L4 vs. L7:**
- L4: Lower latency (~0.1 ms overhead), simpler config, no TLS termination awareness
- L7: Richer routing (canary deploys, path-based sharding), TLS termination offload, but 2–5× more CPU per connection due to HTTP parsing

**Sticky sessions vs. stateless backends:**
- Sticky sessions let you avoid shared state stores but create hot spots if one user generates disproportionate load, and break on instance failure
- Stateless backends (session in Redis) are more resilient but add a network [RTT](_meta/glossary.md#rtt) (~0.5–2 ms) per request to the cache

**Centralized vs. distributed (service mesh):**
- Centralized LB: single control point, easy to reason about, but a scaling bottleneck itself above ~1 M RPS
- Service mesh (Envoy sidecars): removes the central bottleneck, enables per-service circuit breaking, but adds sidecar CPU overhead (~3–5% per pod)

**Cost:**
- AWS ALB: ~$0.008/[LCU](_meta/glossary.md#lcu)-hour + data processing; NLB: ~$0.006/NLCU-hour — NLB is cheaper for pure throughput; ALB cheaper if you need content-based routing that would otherwise require separate servers

## Implementation Notes

**Typical architecture patterns:**

**Two-tier (edge + internal):**
```
Internet → Edge LB (L7, TLS termination) → Internal LBs (per service) → Pods
```
Edge LB handles SSL offload, [WAF](_meta/glossary.md#waf), DDoS mitigation. Internal LBs do service-level routing. Common in AWS (ALB → NLB → ECS/EKS).

**Global load balancing (GeoDNS + Anycast):**
- GeoDNS returns different A records per region (~100 ms latency savings by routing to nearest region)
- Anycast (used by Cloudflare, AWS Global Accelerator) routes to nearest [PoP](_meta/glossary.md#pop) at the [BGP](_meta/glossary.md#bgp) level — faster failover than DNS TTL allows
- Combine with health checks: if `us-east-1` degrades, GeoDNS or Anycast reroutes to `eu-west-1` in seconds

**Active-active HA for the load balancer itself:**
- Two LB nodes, each advertising the same [VIP](_meta/glossary.md#vip) via [VRRP](_meta/glossary.md#vrrp)/[HSRP](_meta/glossary.md#hsrp)
- On primary failure, secondary takes the VIP within ~1–3 s
- Cloud-managed LBs (ALB, GCP HTTPS LB) handle this transparently — do not manage LB HA yourself in cloud environments

**Autoscaling integration:**
- LB target group registers/deregisters instances on autoscale events
- Set deregistration delay (default 300 s on AWS ALB) to drain in-flight requests before terminating an instance
- Scale-out trigger: CPU > 70% for 2 consecutive minutes; scale-in: CPU < 30% for 10 minutes (asymmetric to avoid flapping)
- Account for instance warm-up time (typically 2–5 minutes on AWS) when sizing scale-out headroom

**Connection draining / graceful shutdown:**
1. Autoscaler marks instance for termination → signals LB to stop routing new requests
2. LB waits for active connections to complete (drain window: 30–300 s)
3. Instance terminates

**TLS termination placement:**
- At the edge LB: simplest, single cert, but traffic between LB and backends is plaintext (acceptable inside a [VPC](_meta/glossary.md#vpc) with network-level controls)
- End-to-end TLS (re-encrypt): LB terminates and re-encrypts to backends; required for compliance (PCI DSS, HIPAA); doubles TLS handshake cost

## Common Pitfalls

- **Thundering herd on backend restart:** when a backend comes up after a crash, the LB immediately routes full traffic before the instance has warmed its in-process caches — use a slow-start mode (Nginx: `slow_start=30s`) to ramp traffic linearly
- **Health check too shallow:** `/health` returns 200 but the DB connection pool is exhausted — health checks should verify critical dependencies, not just process liveness
- **Hitting ALB throughput limits:** AWS ALB is elastic and scales automatically, but at extreme scale (millions of RPS) you may need to request a limit increase via AWS Support or switch to NLB for pure L4 throughput; NLB handles millions of connections with lower per-connection overhead
- **Sticky sessions masking state problems:** relying on stickiness instead of externalizing session state means a single instance failure causes user-visible session loss
- **Asymmetric backend capacity:** round-robin distributing equally to a 32-core and an 8-core instance wastes the small one and overloads the large one — use weighted routing

## Resources

- AWS Application Load Balancer docs: https://docs.aws.amazon.com/elasticloadbalancing/latest/application/
- NGINX load balancing guide: https://docs.nginx.com/nginx/admin-guide/load-balancer/http-load-balancer/
- *Designing Data-Intensive Applications* — Ch. 1 (Reliability, Scalability) for first-principles framing
- *System Design Interview Vol. 1* (Alex Xu) — Ch. 1: Scale From Zero to Millions of Users

## Related

- [[consistent-hashing]]
- [[caching]]
- [[rate-limiting]]
- [[dns]]
- [[microservices]]
- [[scalability]]
