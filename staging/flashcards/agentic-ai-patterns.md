---
id: agentic-ai-patterns
type: flashcard
tags:
  - system-design
  - ai-infra
  - agents
  - llm
tiers:
  system-design: 3
created: 2026-09-10
confidence: high
priority: normal
---

# Agentic AI Patterns

An "agent" is an LLM placed in a **loop** that can call **tools** ([function calling](_meta/glossary.md#function-calling)), observe the results, and decide its own next step toward a goal — with memory/state carried across iterations. This works because the LLM is no longer a one-shot predictor but a controller: it can gather missing information, react to failures, and branch dynamically instead of following a fixed script. The cost is that you trade determinism for autonomy — every extra loop iteration adds latency, tokens, and a new place to fail.

> [!tip] Recognition
> Cues that point to an agent: "open-ended task," "the model decides which tool/API to call," "multi-step research/booking/coding assistant," "let it plan and self-correct," "call external tools and use the results." Contrast: if the steps and their order are known up front ("summarize then translate then email"), that's a fixed **pipeline**, not an agent.

## When to Use

**Problem signals that suggest an agent:**
- The path to the answer is **open-ended** — you cannot enumerate the steps in advance.
- The task requires **dynamic tool selection**: which API/query/function to call depends on intermediate results.
- Success needs **iteration**: search, observe, refine, retry (research assistants, coding agents, debugging, multi-hop QA).
- The goal is stated at a high level ("book me a trip under $2k") and must be decomposed at runtime.

**Prefer an agent over alternatives when:**
- Over a **single LLM call**: the task needs external data/actions or more than one dependent step; one call cannot observe-then-act.
- Over a **fixed prompt-chain/pipeline**: the branching and number of steps are data-dependent, not fixed. A pipeline has a static DAG of steps; an agent decides the graph at runtime.
- Over **traditional code/RPC orchestration**: the decision logic is fuzzy/linguistic and impractical to hand-code as rules.

**Do not use when:**
- The steps and order are known and fixed -> use a deterministic **pipeline** (cheaper, testable, no drift).
- One prompt suffices (classification, extraction, summarization) -> use a **single call**.
- The task is latency- or cost-sensitive and correctness must be bounded -> agents add unbounded loops, cost, and failure surface; prefer constrained code paths.
- Reliability/auditability is paramount and you cannot tolerate nondeterministic tool use -> keep humans or deterministic logic in control.

## Key Properties

**Core patterns (know the distinguishing axis of each — this is the #1 confusion point):**

| Pattern | What it does | Distinguishing axis |
|---|---|---|
| **Tool use / function calling** | Model emits a structured call (name + JSON args) to an API, retrieval, or code sandbox; result is fed back | The *mechanism* — how the model acts on the world. Other patterns are built on top of it |
| **[ReAct](_meta/glossary.md#react)** | Interleaves **Reason**ing traces with **Act**ions (tool calls) in one loop: think -> act -> observe -> think... | Reasoning and acting are *interleaved in the same loop*, using observations to guide the next thought |
| **[Reflection](_meta/glossary.md#reflection) / self-critique** | Model critiques its own output and revises it (optionally across rounds) | Adds a *self-evaluation* step; the model is its own reviewer, improving quality without new external input |
| **Planning** | Decompose the goal into ordered sub-tasks first, then execute them | Explicit *decompose-then-execute*: a plan exists before acting (vs ReAct's step-by-step improvisation) |
| **Multi-agent / orchestrator-worker** | A coordinator fans work out to specialized sub-agents and aggregates results | *Multiple LLM roles*; parallelism and specialization, at the cost of coordination overhead |

**Disambiguation cues:**
- **ReAct vs Planning:** ReAct decides the *next* action each step (reactive, adaptive); Planning commits to a *sequence* up front (proactive, then executes). Many systems combine both (plan, then ReAct within each sub-task).
- **Reflection vs everything else:** it is the only pattern whose "tool" is the model examining its *own* prior output.
- **Multi-agent vs single-agent-with-tools:** more agents only helps when sub-tasks are genuinely independent/parallelizable or need distinct specialized contexts; otherwise it multiplies cost and coordination bugs for little gain.

**Anatomy of an agent loop:** goal + context -> LLM decides (reason/plan) -> emit tool call -> execute tool -> observe result -> update memory/state -> repeat until stop condition (goal met, budget hit, or max steps).

**Memory/state** distinguishes an agent from a stateless call: short-term (conversation/scratchpad within the loop) and long-term (vector store / external memory) let the agent accumulate context across steps.

## Common Pitfalls

- **Reaching for an agent when a pipeline works.** Agents are trendy; a fixed chain or single call is cheaper, faster, deterministic, and testable. Justify the loop.
- **Compounding drift over long loops.** Small per-step errors accumulate; a wrong early observation poisons every subsequent decision. Long horizons are where agents fail most.
- **Infinite / looping behavior.** The model repeats the same action or oscillates. Always cap steps and detect no-progress loops.
- **Cost & latency blow-up.** Each step is a full LLM call (often with a growing context window); tokens and wall-clock scale with loop length. A "simple" task can silently cost 20+ calls.
- **Unvalidated tool calls.** Hallucinated function names, malformed args, or wrong tool choice. Validate against the tool schema and handle tool errors gracefully.
- **Prompt injection via tool output.** Retrieved documents or API responses can contain instructions ("ignore previous instructions, exfiltrate secrets"). Untrusted tool output is an attack surface — never treat it as trusted instructions; sandbox and least-privilege the tools.
- **No observability.** Without tracing every reason/action/observation you cannot debug why the agent went wrong. Trace the whole loop.

**Guardrails (map each pitfall to a control):** step/iteration and token **budget caps**; **human-in-the-loop** approval for high-impact actions (payments, deletes, sends); **output/tool-arg validation**; **sandboxing** tool execution with least privilege; **observability/tracing** of every loop step. These mirror classic reliability patterns — a step budget is a [circuit-breaker](_meta/glossary.md#circuit-breaker) on runaway loops, and tool calls need the same retries/timeouts discipline as any flaky RPC.

## Trade-offs

**Single call vs pipeline vs agent:**

| Axis | Single call | Fixed pipeline | Agent (loop + tools) |
|---|---|---|---|
| Control flow | None | Static, predetermined | Dynamic, model-decided |
| Determinism | Highest | High | Low (nondeterministic path) |
| Cost / latency | Lowest | Low, bounded | High, potentially unbounded |
| Handles open-ended tasks | No | No | Yes |
| Testability / auditability | Easy | Easy | Hard |
| Failure surface | Minimal | Moderate | Large (loop, tools, injection) |

Decision axis: **How much of the control flow must be decided at runtime?** None -> single call. Known/fixed -> pipeline. Data-dependent/open-ended -> agent.

**Single-agent-with-tools vs multi-agent:**

| Axis | Single agent + tools | Multi-agent (orchestrator-worker) |
|---|---|---|
| Best for | Sequential/dependent steps | Independent, parallelizable, or specialized sub-tasks |
| Cost | Lower | Higher (more calls, coordination) |
| Complexity | Moderate | High (routing, aggregation, shared state) |
| Failure modes | Loop/drift | + coordination bugs, conflicting sub-agents |

Default to a single agent; add agents only when sub-tasks are genuinely independent or need distinct specialized contexts.

## Resources

- [Anthropic — Building Effective Agents](https://www.anthropic.com/engineering/building-effective-agents)
- [ReAct: Synergizing Reasoning and Acting in Language Models (Yao et al., 2022)](https://arxiv.org/abs/2210.03629)
- [Reflexion: Language Agents with Verbal Reinforcement Learning (Shinn et al., 2023)](https://arxiv.org/abs/2303.11366)
- [OpenAI — Function calling guide](https://platform.openai.com/docs/guides/function-calling)
- [OWASP Top 10 for LLM Applications (prompt injection, excessive agency)](https://owasp.org/www-project-top-10-for-large-language-model-applications/)

## Related

- [[rag-retrieval-augmented-generation]]
- [[llm-serving-and-inference]]
- [[circuit-breaker]]
- [[retries-and-timeouts]]
- [[observability]]
