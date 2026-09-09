---
id: observability
type: flashcard
tags:
  - backend
  - observability
tiers:
  backend: 1
created: 2026-09-08
confidence: high
priority: normal
---

# Observability

Observability is the ability to explain a system's internal state from its external outputs — specifically, to answer *new* questions about *why* something is wrong without shipping new code. It rests on three signals (pillars): **logs** (discrete events, ideally structured), **metrics** (numeric time series, cheap and aggregatable), and **traces** (the causal path of a single request across services). The principle: metrics tell you *that* something is wrong and page you; traces tell you *where* in the request path; logs tell you *what* exactly happened at that spot. High cardinality is the currency you spend to ask arbitrary questions — and the thing that bankrupts your metrics backend if spent carelessly.

> [!tip] Recognition — reach for observability design when you hear
> "we can't tell why p99 spiked," "the error is somewhere across 12 microservices," "MTTR is too high / on-call is flying blind," "we need to debug a problem we've never seen before," "how do we correlate logs across services for one request," or "our metrics bill exploded." Any question about *unknown-unknowns* in a distributed system is an observability question, not a monitoring one.
>
> **vs. resilience siblings:** observability only *measures and explains* — it never changes request flow. [Circuit-breaker](_meta/glossary.md#circuit-breaker), [retries/timeouts](_meta/glossary.md#retry-storm), and [rate-limiting](_meta/glossary.md#rate-limiting) *act on* traffic (stop, resend, or shed it); observability is what tells you they are firing. Distinguishing signal: if the pattern makes a control decision it is resilience; if it emits or answers questions about state it is observability.

## When to Use

**Problem signals that call for each pillar:**
- **Reach for metrics when:** you need to alert, you need dashboards/SLOs, you need a cheap always-on signal over *aggregate* behavior ([QPS](_meta/glossary.md#qps), error rate, [P99](_meta/glossary.md#p99) latency, CPU saturation). Metrics are pre-aggregated and constant-cost per series regardless of traffic.
- **Reach for traces when:** a request fans out across services and you must find *which hop* is slow or failing; you need to see the latency waterfall of one request; you're debugging tail latency or a specific failing request ID.
- **Reach for logs when:** you need the exact detail at a point in time — the stack trace, the offending input, the branch taken. Logs answer "what happened *here*," not "what is the shape of the whole system."

**Monitoring vs. observability (the interview distinction):**
- *Monitoring* watches a **predefined** set of failure modes — dashboards and alerts for the known-unknowns you anticipated. Metrics-driven.
- *Observability* lets you ask **arbitrary new questions** post-hoc about unknown-unknowns, by slicing high-dimensional data you didn't pre-aggregate. Observability is a *property of the system's telemetry*; monitoring is an *action* you take with it. Monitoring is a subset use-case of an observable system.

**Pick a method to structure metrics:**
- **RED** (Rate, Errors, Duration) — for **request-driven services** (APIs, [gRPC](_meta/glossary.md#grpc) endpoints, service mesh). Wilkie's per-service adaptation of Google's golden signals. This is the default for microservices.
- **USE** (Utilization, Saturation, Errors) — for **resources** (CPU, memory, disk, network, thread pools, connection pools). Gregg's method; answers "is this resource the bottleneck?"
- **Four Golden Signals** (Latency, Traffic, Errors, Saturation) — Google SRE's minimum-viable set for a user-facing service. RED ≈ the first three from the request side; USE covers saturation from the resource side. They are complementary, not competing.

**Do not reach for:**
- High-cardinality dimensions in metrics (user IDs, request IDs) → use traces/logs with exemplars instead; metrics are the wrong store.
- Logs for aggregate rates you query constantly → derive a metric; scanning logs for a rate is slow and expensive.

## Key Properties

The three signals differ fundamentally in cost model and query shape. This table is the core mental model:

| | Logs | Metrics | Traces |
|---|---|---|---|
| Unit | Discrete timestamped event | Numeric time series (name + labels) | Tree of spans for one request |
| Cost model | Scales with event volume | ~Constant per series; explodes with **cardinality** | Scales with request volume × sampling rate |
| Aggregatable? | Poorly (must scan/index) | Yes — designed for it | Per-request; aggregate only via metrics/exemplars |
| Cardinality tolerance | High (each event unique) | **Low** — the cardinality trap lives here | High (each trace unique) |
| Answers | "What happened exactly?" | "That something is wrong; how much?" | "Where in the path, and in what order?" |
| Typical store | Loki, Elasticsearch | Prometheus, [TSDB](_meta/glossary.md#tsdb) | Jaeger, Tempo |

**Metric types (Prometheus/OTel taxonomy):**
- **Counter** — monotonically increasing; you only ever `inc()`. Query the *rate* of it (`rate(http_requests_total[5m])`), never the raw value. Resets to 0 on restart; `rate()` handles that.
- **Gauge** — a value that goes up and down (queue depth, memory in use, in-flight requests, temperature).
- **Histogram** — samples observations into cumulative buckets (`_bucket{le=...}`) plus `_sum` and `_count`. Percentiles are computed server-side via `histogram_quantile()`. **Buckets are aggregatable across instances** — this is the whole point.
- **Summary** — computes quantiles client-side. Cheaper to query but the quantiles **cannot be aggregated** across instances (you cannot average p99s). Prefer histograms in distributed systems for exactly this reason.

**Structured logs:** emit key-value/JSON (`{"level":"error","trace_id":"...","user_id":123,"latency_ms":812}`), not free-text `printf`. Structure makes logs queryable and, critically, lets you **inject the `trace_id`** so a log line joins to its trace. Always include the trace/span ID in every log line — that correlation is what makes the three pillars one system rather than three silos.

**Traces & spans:**
- A **trace** is a tree of **spans**; each span is one unit of work (an RPC, a DB query, a handler) with a start/end time, a `span_id`, a `parent_span_id`, a shared `trace_id`, plus attributes and events.
- **Context propagation** carries `trace_id` + parent `span_id` across process boundaries so spans in different services join into one trace. Over HTTP this is the **W3C `traceparent`** header.

## Common Pitfalls

- **Cardinality explosion — the #1 metrics outage.** A metric's cost is *one time series per unique label-value combination*. Adding a high-cardinality label — `user_id`, `email`, request ID, full URL path with IDs, unbounded `error_message` — multiplies series count combinatorially and [OOMs](_meta/glossary.md#oom) the TSDB. Rule: metric labels must be **bounded, low-cardinality** enumerations (status code, method, route *template* `/users/{id}` not `/users/42`). Put the unbounded detail in traces/logs.
- **Averaging percentiles.** You cannot average p99 across ten instances to get a global p99 — it is mathematically meaningless. Use histograms and aggregate the *buckets*, then compute the quantile. Summaries silently make this mistake tempting.
- **Averages hide tail latency.** A mean latency of 40ms can hide a p99 of 3s. Always alert on and chart percentiles (p50/p90/p99), not averages. Distinguish latency of *successful* vs *failed* requests — a fast 500 is not "good latency."
- **Broken context propagation.** One service that drops the `traceparent` header (a thread-pool hop that loses context, a message queue with no propagation, a proxy that strips headers) severs the trace into disconnected fragments. Every async boundary and every RPC client must propagate context.
- **Logging unstructured / logging PII.** Free-text logs aren't queryable; and dumping [PII](_meta/glossary.md#pii) or secrets into logs is a compliance breach. Structure and scrub at the emit point.
- **100% trace sampling in prod.** Tracing every request is often prohibitively expensive in storage and overhead; blindly sampling can also drop the *one* error trace you needed. Sample deliberately (see Implementation Notes).
- **Alerting on causes, not symptoms.** Page on user-visible symptoms (SLO burn, error rate, latency), not on every internal cause (high CPU) — cause-based alerts create noise and pager fatigue. (Google SRE.)
- **Three siloed tools.** Logs, metrics, traces in separate systems with no shared IDs force manual correlation during an incident. The value is the *join*: exemplars link a metric spike to a trace; `trace_id` links a trace to its logs.

## Trade-offs

| Decision | Option A | Option B | When to pick |
|---|---|---|---|
| Percentiles | **Histogram** (server-side quantile) | **Summary** (client-side quantile) | Histogram when you aggregate across instances (almost always in distributed systems); Summary only for a single instance where exact quantiles matter |
| Trace sampling | **Head sampling** (decide at trace start) | **Tail sampling** (decide after trace completes) | Head is cheap/simple but blind to outcome; tail keeps all errors/slow traces but needs a stateful collector buffering spans |
| Debugging store | **Metrics** | **Wide events / traces + logs** | Metrics for cheap always-on aggregate alerting; wide high-cardinality events when you must ask unanticipated questions |
| Cost vs. fidelity | Sample aggressively, short retention | Keep everything, long retention | Telemetry can cost as much as the service; budget it like a first-class resource |

**Core tension:** metrics are cheap but low-cardinality (can't answer per-user questions); traces/logs are high-cardinality but expensive at full volume. The art is pushing high-cardinality detail into sampled traces and structured logs while keeping metrics lean and bounded — and stitching them with shared IDs so you can pivot metric → trace → log during an incident.

## Implementation Notes

**W3C `traceparent` header (the propagation format to know):**
```
traceparent: 00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01
             │  │                                │                │
          version         trace-id (16B)     parent span-id (8B)  trace-flags
             00   32 hex chars              16 hex chars          01 = sampled
```
- `tracestate` — optional companion header carrying vendor-specific key-value pairs.
- **Baggage** — a *separate* OTel cross-cutting concern (not a fourth signal): arbitrary user-defined key-values (e.g. `tenant_id`) propagated alongside the trace so downstream services can read business context. Do NOT put secrets/PII in baggage — it travels over the wire to every hop.

**OpenTelemetry (OTel) — the vendor-neutral standard:**
- One set of SDKs/APIs and one wire protocol (**OTLP**) for all three signals; decouples instrumentation from backend, so you can swap Jaeger↔Tempo or Prometheus↔vendor without re-instrumenting.
- Typical pipeline: `App (OTel SDK)  →  OTel Collector  →  backend(s)`. The Collector receives OTLP, batches, samples (tail sampling lives here), transforms, and fans out to multiple exporters.

```yaml
# otel-collector: batch + tail-sample (keep all errors + slow traces, 10% of the rest)
receivers:  { otlp: { protocols: { grpc: {}, http: {} } } }
processors:
  batch: {}
  tail_sampling:
    policies:
      - { name: errors, type: status_code, status_code: { status_codes: [ERROR] } }
      - { name: slow,   type: latency,     latency: { threshold_ms: 500 } }
      - { name: sample-rest, type: probabilistic, probabilistic: { sampling_percentage: 10 } }
exporters:  { otlp/tempo: { endpoint: tempo:4317 }, prometheus: { endpoint: 0.0.0.0:8889 } }
service:
  pipelines:
    traces:  { receivers: [otlp], processors: [tail_sampling, batch], exporters: [otlp/tempo] }
    metrics: { receivers: [otlp], processors: [batch], exporters: [prometheus] }
```

**RED instrumentation for one HTTP endpoint (bounded labels only):**
```
# Counter → Rate + Errors ; Histogram → Duration
http_requests_total{method="GET", route="/users/{id}", status="200"}   # counter
http_request_duration_seconds_bucket{route="/users/{id}", le="0.5"}    # histogram

# PromQL
rate(http_requests_total[5m])                                          # Rate
rate(http_requests_total{status=~"5.."}[5m])                           # Errors
histogram_quantile(0.99, sum by (le) (rate(http_request_duration_seconds_bucket[5m])))  # p99 Duration
```
Note `route` is a **template**, never the raw path — that is what keeps cardinality bounded.

**Correlation glue:** put `trace_id` and `span_id` into every structured log line and expose **exemplars** on histograms so a dashboard spike links straight to an example trace. Shared IDs are what turn three tools into one workflow.

## Variants

- **Wide structured events / "Observability 2.0":** instead of three separate signal stores, emit one very wide, high-cardinality event per request (arbitrary key-values) and derive metrics/traces from it at query time (Honeycomb's model). Optimizes for asking unanticipated questions.
- **eBPF / auto-instrumentation:** capture telemetry from the kernel or via bytecode injection without editing app code — reduces instrumentation toil at the cost of less semantic context.
- **Continuous profiling:** a fourth signal (CPU/memory flame graphs over time) increasingly grouped with the three pillars for cost/performance debugging.
- **Exemplars:** trace IDs attached to specific metric samples — the standardized bridge from a metric bucket to a representative trace.

## Resources

- Google SRE Book — *Monitoring Distributed Systems* (Four Golden Signals): https://sre.google/sre-book/monitoring-distributed-systems/
- OpenTelemetry — Context Propagation & signals overview: https://opentelemetry.io/docs/concepts/context-propagation/
- W3C Trace Context (traceparent/tracestate spec): https://www.w3.org/TR/trace-context/
- Prometheus — Histograms and Summaries (why you can't average quantiles): https://prometheus.io/docs/practices/histograms/

## Related

- [[metrics]]
- [[distributed-tracing]]
- [[structured-logging]]
- [[opentelemetry]]
- [[prometheus]]
- [[microservices]]
- [[sli-slo-sla]]
