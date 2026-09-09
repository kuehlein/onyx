---
id: sli-slo-and-error-budgets
type: flashcard
tags:
  - backend
  - reliability
  - observability
tiers:
  backend: 2
created: 2026-09-08
confidence: high
priority: normal
---

# SLI, SLO, SLA, Error Budgets

Reliability is not "up or down" — it is a measured, user-facing quality you deliberately target below 100%. An **SLI** is a metric of that quality (e.g. fraction of requests served under 300 ms); an **SLO** is the internal target for an SLI over a window (e.g. 99.9% over 30 days); an **[SLA](_meta/glossary.md#sla)** is an external contract that promises some level to customers, backed by penalties. The gap `1 − SLO` is your **error budget**: a quantified allowance of failure you get to *spend* on shipping features and taking risk. The core principle is that 100% is the wrong target — it is unachievable, users can't tell the difference above the point where their own network dominates, and chasing it freezes all change. So you pick a realistic SLO, measure it with SLIs that reflect what users actually experience, and let the error budget arbitrate the eternal fight between velocity and stability.

> [!tip] Recognition
> Reach for this framing when you hear: "how reliable should this service be?", "the team wants to ship faster but ops wants to freeze deploys", "what do we promise customers vs. what do we hold ourselves to", "when should this page a human at 3am?", or "we're at 100% uptime as our goal." Any tension between release velocity and stability, or any need to turn reliability into a number, is the trigger.

## When to Use

- **Setting a reliability target for a service** — define an SLO on user-facing SLIs (request success rate, latency percentile), not on internal resource metrics like CPU. Machine metrics are for debugging, not for objectives.
- **Adjudicating velocity vs. stability** — when devs want to ship and SRE wants to freeze, the error budget is the neutral referee: budget remaining → ship; budget exhausted → freeze risky changes until it refills.
- **Deciding what should page a human** — alert on *burn rate* of the error budget (symptom-based, user-impacting) instead of on every cause. This is the modern replacement for threshold-per-metric alerting.
- **Committing to a customer contract** — set the SLA looser than your internal SLO so you have headroom to detect and fix problems before you breach the contract and owe penalties.

**Do not** set an SLO at or near 100% (unachievable, no budget to spend), and do not build SLIs from metrics users can't perceive.

## Key Properties

- **SLI = the measurement.** A ratio of good events to valid events, e.g. `successful requests / total requests` or `requests < 300 ms / total`. Good SLIs are user-journey-centric and expressed as a percentage.
- **SLO = the internal target on an SLI, over a window.** "99.9% of requests succeed over a rolling 30 days." Purely internal; no legal force; you can set it aggressively because breaching it only triggers *engineering* action.
- **SLA = the external promise, with consequences.** A contractual guarantee to customers (often with refunds/credits on breach). Deliberately **looser than the SLO** so the SLO acts as an early-warning buffer before the SLA is at risk.
- **Error budget = `1 − SLO`, expressed as tolerated failure.** A 99.9% / 30-day SLO ≈ 0.1% ≈ **43 minutes** of allowed downtime per month. It is a budget you actively spend on releases, experiments, and planned maintenance.
- **Burn rate = how fast you're consuming the budget** relative to the steady-state rate. Burn rate 1 = you'll exactly exhaust the budget by the window's end; burn rate 14.4 = 2% of a 30-day budget gone in 1 hour.

## Trade-offs

| Concept | Audience / owner | Binding force | Where it sits | Trigger on breach |
|---|---|---|---|---|
| **SLI** | Internal (measurement) | None — it's just data | The raw indicator | Feeds SLO/alerting |
| **SLO** | Internal (eng/SRE) | Self-imposed target | Set aggressively | Engineering response (slow/freeze) |
| **SLA** | External (customer) | Contractual, penalties | **Looser** than SLO | Money / legal consequences |
| **Error budget** | Internal (eng + product) | Policy-driven | Derived: `1 − SLO` | Freeze risky changes when exhausted |

- **Tighter SLO ⇒ smaller error budget ⇒ slower shipping.** Each added "nine" is exponentially more expensive and leaves less room to take risks. Choose the loosest SLO users will tolerate.
- **SLA looser than SLO on purpose.** The buffer between them is your reaction time; if SLA = SLO you have zero margin to notice and remediate before owing penalties.

## Common Pitfalls

- **Targeting 100% / "five nines everywhere."** Removes all error budget, halts change, and buys reliability users can't even perceive (their own last-mile network is the bottleneck). Pick a number, not perfection.
- **SLIs on machine metrics, not user experience.** CPU/memory/disk are diagnostic signals, not objectives; a service can be "green" on resources while users see errors. Measure success rate and latency at the user-facing edge.
- **Setting the SLA tighter than (or equal to) the SLO.** Leaves no headroom — the first sustained incident breaches the contract before engineering can react.
- **Averages instead of percentiles for latency.** A healthy mean hides a miserable tail; SLO latency SLIs use p95/[p99](_meta/glossary.md#p99) so the slow-experience minority is counted.
- **Alerting on causes / static thresholds instead of budget burn.** Per-metric threshold alerts are noisy and miss slow burns; multiwindow, multi-burn-rate alerts fire fast on big problems and slowly on small ones, tied directly to user-visible budget consumption.
- **Confusing SLO with SLA in conversation.** The SLO is the number *you* chase; the SLA is the number *the lawyers* wrote. Mixing them leads teams to either over-promise externally or under-target internally.

## vs. Observability

**Observability** is the *capability* to ask arbitrary questions about a system's internal state from its outputs (metrics, logs, traces) — how you debug *why* something broke. **SLI/SLO/error budgets** are the *reliability targets and policy* built on top of that data — how you decide *whether* reliability is acceptable and *what to do about it*. Observability produces the raw telemetry; SLIs select the specific user-facing signals from that telemetry and SLOs turn them into commitments. You need observability to *compute* an SLI, but observability alone sets no target and makes no ship/freeze decision.

## Implementation Notes

- **Multiwindow, multi-burn-rate alerting** (Google SRE Workbook): combine a short and long window that must *both* exceed a burn-rate threshold to fire, cutting false pages while keeping fast detection. Typical tiers for a 30-day budget:
  - Page: burn rate ~**14.4** over 1h (≈2% of budget in an hour)
  - Ticket: burn rate ~**6** over 6h (≈5% of budget)
  - Slow-burn ticket: burn rate ~**1** over 3d (≈10% of budget)
- **Error-budget policy** should be written and agreed in advance: it names concrete actions (e.g. halt feature launches, redirect eng to reliability work) that automatically trigger when the budget is spent, so the freeze decision isn't relitigated per incident.
- Tools: Prometheus + recording rules, Grafana SLO, Google Cloud SLO monitoring, and SLO-as-code generators implement the good/valid-events ratio and burn-rate rules.

## Resources

- Google SRE Book — Service Level Objectives: https://sre.google/sre-book/service-level-objectives/
- Google SRE Workbook — Alerting on SLOs (multiwindow, multi-burn-rate): https://sre.google/workbook/alerting-on-slos/
- Google SRE Workbook — Implementing SLOs: https://sre.google/workbook/implementing-slos/

## Related

- [[observability]]
- [[monitoring-and-metrics]]
- [[incident-response]]
- [[latency-percentiles]]
