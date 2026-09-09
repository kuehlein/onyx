---
id: service-discovery
type: flashcard
tags:
  - system-design
  - distributed-systems
tiers:
  system-design: 2
created: 2026-09-08
confidence: high
priority: normal
---

# Service Discovery

Service discovery is the mechanism by which a client finds a *currently healthy* network address for a service whose instances come and go — autoscaling, deploys, crashes, and reschedules mean IPs are not stable and cannot be hardcoded. The core is a **service registry**: instances register on startup (and deregister/expire on shutdown or health-check failure), and callers query the registry instead of a fixed address. Everything else — client-side vs server-side lookup, [DNS](_meta/glossary.md#dns)-based vs API-based, [CP](_meta/glossary.md#cp) vs [AP](_meta/glossary.md#ap) registry — is a variation on that one idea.

> [!tip] Recognition
> Reach for service discovery when the design has an **elastic/dynamic fleet** whose instance addresses change at runtime: "instances autoscale up and down", "how do services find each other in microservices", "pods get rescheduled to new IPs", "how do we route around an unhealthy instance", "avoid hardcoding backend hostnames". The trigger is *membership churn* + *needing a healthy target*, not just load spreading (that's the [load balancer](_meta/glossary.md#lb)'s job, which discovery feeds).

## When to Use

**Problem signals that suggest service discovery:**
- Instances scale in/out or get rescheduled, so their IPs are not known ahead of time ("how does service A call service B when B's pods keep moving?")
- You need to stop sending traffic to a crashed or failing instance automatically (health-check-driven removal)
- A microservices fleet where each service has N replicas and callers must pick a live one
- Blue/green or rolling deploys where the set of valid endpoints changes continuously

**Prefer service discovery over alternatives when:**
- Over a hardcoded IP / static config file: the fleet is dynamic; static config goes stale the moment an instance moves
- Over a single fixed [load balancer](_meta/glossary.md#lb) VIP: you still often use an LB, but *it* needs discovery to know its backend pool; discovery is the registry underneath, not a competitor
- Over plain [DNS](_meta/glossary.md#dns) alone: when you need fast health-based removal and rich metadata (versions, tags, weights) that DNS records can't easily express or update quickly

**Do not use a dedicated registry when:**
- The fleet is small and static (a couple of long-lived hosts) → a config file or DNS record is simpler
- A managed platform already provides it (Kubernetes Services + kube-proxy/CoreDNS, cloud LB target groups) → use the platform's built-in discovery rather than running your own [Consul](https://developer.hashicorp.com/consul)/etcd

## Key Properties

- **Registry = source of truth for membership.** Instances *register* (self-registration on boot, or third-party registration by the platform) and are *deregistered* on shutdown or when they fail health checks. Registrations typically carry a [TTL](_meta/glossary.md#ttl) so a crashed instance that can't deregister still expires.
- **Health checking is what makes it useful.** Discovery without liveness checks just returns addresses, some dead. Checks are active (registry probes the instance: HTTP/TCP/gRPC) or passive (instance heartbeats / TTL renewal). Only *passing* instances are returned.
- **Metadata, not just IPs.** Real registries return tags/weights/versions/zone so callers can filter (e.g. canary, same-AZ routing).
- **The registry is itself a distributed system** with its own consistency stance (see Trade-offs). Its availability is critical: if the registry is down, no one can discover anyone.

## Trade-offs

**Client-side vs server-side discovery** (the primary axis — do not blur these):

| | Client-side discovery | Server-side discovery |
|---|---|---|
| Who queries the registry | The **client** itself | A **[load balancer](_meta/glossary.md#lb) / gateway / proxy** in the path |
| Who picks the instance | Client (LB logic lives in the client library) | The intermediary |
| Client complexity | High — every client embeds a discovery-aware library | Low — client just calls one stable address |
| Extra network hop | No (client talks straight to the instance) | Yes (through the LB/proxy) |
| Language coupling | Library needed per language | Language-agnostic |
| Examples | Netflix Eureka + Ribbon, [gRPC](_meta/glossary.md#grpc) client-side LB | AWS ELB/ALB, k8s Service via kube-proxy, service-mesh sidecar |

- **DNS-based discovery** is the simplest server-side-ish form: instances become A/[AAAA](_meta/glossary.md#aaaa)/SRV records; clients just resolve a name. Cheap and universal, but DNS [TTL](_meta/glossary.md#ttl) caching makes removal of a dead instance *slow*, and plain A records carry no health or weight metadata. Good enough for slow-changing fleets; weak for fast failure removal.
- **Registry consistency ([CP](_meta/glossary.md#cp) vs [AP](_meta/glossary.md#ap)):** a CP registry ([etcd](https://etcd.io/), [ZooKeeper](https://zookeeper.apache.org/), Consul's Raft-backed writes) refuses to serve possibly-stale membership during a partition — favored when the registry backs control-plane decisions (etcd for Kubernetes). An AP-leaning approach (gossip, Eureka) keeps returning cached membership during a partition — favored for discovery itself, where a slightly stale-but-available instance list beats no list at all. For *discovery specifically*, strict [linearizability](_meta/glossary.md#linearizability) is usually not required: fast convergence is enough.

## Common Pitfalls

- **No health checking, or checking the wrong thing.** A registry that only knows "the instance registered once" will happily hand out dead instances. And a shallow TCP-port check can pass while the app is deadlocked — check a real readiness endpoint, not just the socket.
- **Registry as a [single point of failure](_meta/glossary.md#spof).** If every request must hit the registry live, its outage takes down all inter-service calls. Mitigate with client-side caching of the last-known-good list and graceful degradation on registry unavailability.
- **Stale entries from ungraceful shutdown.** An instance that is `kill -9`'d never deregisters; without a [TTL](_meta/glossary.md#ttl)/heartbeat expiry it lingers as a phantom endpoint. Always pair registration with an expiry, not just explicit deregister.
- **DNS TTL caching hides failures.** Clients and OS resolvers cache A records for the TTL; a removed instance can keep receiving traffic until caches expire. Don't rely on DNS alone where fast failover matters.
- **Confusing discovery with adjacent concepts.** Keep the distinguishing question straight for each sibling:
  - **vs load balancing:** discovery answers *"which instances exist and are healthy?"*; the [load balancer](_meta/glossary.md#lb) answers *"which one gets this request?"*. In client-side discovery the client does both; in server-side the LB does both — but they are distinct concerns, and the LB's backend pool is populated *from* discovery.
  - **vs API gateway:** an API gateway is a *north-south edge* concern — one public entry point doing auth, routing, rate limiting, and request aggregation for external clients. Discovery is the *east-west internal* concern of tracking live instances. The gateway is often a *consumer* of discovery (it looks up which backends are healthy), not a substitute for it.
  - **vs DNS:** DNS is one *transport* for discovery (name → address), but it lacks fast health-based removal and rich metadata; a full registry adds liveness, weights, and tags. DNS answers "what address for this name (cached for a [TTL](_meta/glossary.md#ttl))"; discovery answers "which instances are healthy *right now*".

## Implementation Notes

- **Registry options:** Consul (service discovery + health + KV + mesh; Raft for server state, gossip for membership), etcd (Raft, CP, powers Kubernetes), ZooKeeper (Zab consensus, ephemeral znodes that vanish when a session dies — a natural fit for registration). Consul also exposes tunable read consistency: `default` (fast, leader-leased), `consistent` (linearizable, extra round trip), `stale` (any server, lowest latency, may lag).
- **Platform-native (usually the right default):** Kubernetes gives you `Service` objects; CoreDNS resolves `<service>.<namespace>.svc.cluster.local`, kube-proxy or a CNI programs the routing, and readiness probes gate membership — you rarely run a standalone registry.
- **Service mesh** (Istio, Linkerd, Consul Connect) pushes server-side discovery into per-pod sidecar proxies: the app calls localhost, the sidecar does discovery + LB + [mTLS](_meta/glossary.md#mtls). This removes per-language client libraries while keeping client-side-style fine-grained routing.

## Resources

- Chris Richardson, *Microservices Patterns* — Service Discovery patterns: https://microservices.io/patterns/server-side-discovery.html and https://microservices.io/patterns/client-side-discovery.html
- HashiCorp Consul — Consistency model: https://developer.hashicorp.com/consul/docs/concept/consistency
- Kubernetes docs — Service & DNS-based discovery: https://kubernetes.io/docs/concepts/services-networking/service/
- etcd docs — Why etcd (Raft, linearizable): https://etcd.io/docs/latest/learning/why/

## Related

- [[load-balancing]]
- [[health-checks]]
- [[dns]]
- [[cap-theorem]]
- [[microservices]]
- [[service-mesh]]
- [[api-gateway]]
