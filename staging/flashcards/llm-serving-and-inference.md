---
id: llm-serving-and-inference
type: flashcard
tags:
  - system-design
  - ai-infra
  - llm-serving
  - performance
tiers:
  system-design: 3
created: 2026-09-10
confidence: high
priority: normal
---

# LLM Serving & Inference

Serving a transformer LLM means running **autoregressive decoding**: the model emits one token at a time, each conditioned on all prior tokens, so decoding is inherently sequential. Almost every serving behavior — latency shape, memory pressure, batching strategy — falls out of two facts: the work splits into a parallel **[prefill](_meta/glossary.md#prefill)** phase and a serial **[decode](_meta/glossary.md#decode)** phase, and the **[KV cache](_meta/glossary.md#kv-cache)** trades GPU memory for avoiding recomputation.

> [!tip] Recognition
> Cues that these concerns bite: "self-host an open-weight model," "reduce cost per token / GPU utilization," "why is the first token slow but streaming smooth," "context window too big for the GPU," "[TTFT](_meta/glossary.md#ttft) vs tokens/sec SLO," "batch size vs latency," "the model doesn't fit on one GPU," or "we're memory-bound not compute-bound." Also any mention of vLLM, TensorRT-LLM, [PagedAttention](_meta/glossary.md#pagedattention), quantization, or [speculative decoding](_meta/glossary.md#speculative-decoding).

## When to Use

**Problem signals that these serving concerns apply:**
- You are **self-hosting** an open-weight model (Llama, Qwen, Mixtral) on your own GPUs rather than calling a hosted API — you now own batching, memory, and latency tuning.
- The system has a per-token or per-request latency SLO (chatbot, code assistant, streaming UI) and you must reason about TTFT vs steady-state throughput.
- Cost per million tokens or GPU utilization is a design axis (large-scale inference where GPU-hours dominate spend).
- The prompt/context is large (RAG with many retrieved chunks, long documents, agent scratchpads) so KV-cache memory governs max context and batch size.
- The model is too big for a single GPU's VRAM, forcing [tensor](_meta/glossary.md#tensor-parallelism)/pipeline parallelism.

**Prefer self-hosted serving reasoning over just "call the API" when:**
- Over a **hosted API**: you need data residency/privacy, a fine-tuned or open-weight model, predictable cost at high volume, or control over latency percentiles. The API hides all of this; at scale or under compliance constraints you must own it.
- Over **naive one-request-per-GPU**: GPUs are massively parallel; serving one request at a time wastes >90% of compute. [Continuous batching](_meta/glossary.md#continuous-batching) is how you actually get throughput.

**Do not over-engineer when:**
- Low, bursty volume with no privacy constraint → just call a hosted API; DIY serving is not worth the ops cost.
- The bottleneck is retrieval quality or prompt design, not throughput → fix [[rag-retrieval-augmented-generation]] first; serving tuning won't help a bad-context system.

## Key Properties

**Prefill vs decode (the split that explains everything):**

| Phase | What it does | Bottleneck | Parallelism |
|---|---|---|---|
| **Prefill** | Process the entire prompt in one forward pass, populate the KV cache | **Compute-bound** (big matmuls over all prompt tokens at once) | Fully parallel across prompt tokens |
| **Decode** | Generate output tokens one at a time, each a single-token forward pass | **Memory-bandwidth-bound** (must stream all weights + KV cache per token, tiny compute) | Serial across output tokens |

Consequence: **TTFT** (time-to-first-token) is dominated by prefill and scales with prompt length; **[TPOT](_meta/glossary.md#tpot)/ITL** (time-per-output-token / inter-token latency) is dominated by decode and is roughly constant per token but limited by memory bandwidth, not FLOPs.

**KV cache:**
- Caches the per-token key and value tensors from every attention layer so each new token attends over the stored cache instead of recomputing all previous tokens — turns per-step cost from O(n²) recompute into O(n) attention against cache.
- It is the **dominant GPU-memory consumer at inference** alongside weights, and it grows linearly with (sequence length × batch size × layers × hidden size). This is *the* reason context length and batch size are memory-bounded: you run out of VRAM for the KV cache long before you run out of compute.
- Rough size: `2 (K+V) × layers × kv_heads × head_dim × seq_len × batch × dtype_bytes`.

**Continuous / in-flight batching (vLLM-style):**
- Naive **static batching** waits to assemble a fixed batch, runs all requests to completion together, and pads to the longest sequence — short requests are held hostage by long ones and the GPU idles between batches.
- **Continuous (in-flight) batching** schedules at the token/iteration level: finished sequences leave the batch immediately and new requests join mid-flight. This keeps the GPU saturated and can lift throughput several-fold with better tail latency.

**PagedAttention:**
- Manages the KV cache in fixed-size **blocks (pages)** like OS virtual memory instead of one contiguous per-request allocation. Eliminates internal fragmentation and over-reservation (you don't pre-allocate for max possible length), so far more requests fit in VRAM — and enables prefix/KV sharing across requests with a common prompt.

**Cost/perf levers:**
- **Quantization** (INT8 / FP8 / 4-bit like GPTQ/AWQ): stores weights (and sometimes KV cache/activations) in fewer bits. Cuts memory and, because decode is bandwidth-bound, often speeds up decode — at some quality cost.
- **Tensor / pipeline parallelism**: shard one model across GPUs when it doesn't fit. Tensor parallelism splits each layer's matrices across GPUs (heavy inter-GPU communication, needs fast interconnect like NVLink); pipeline parallelism splits layers into stages across GPUs (introduces pipeline bubbles).
- **Speculative decoding**: a small cheap **draft model** proposes several tokens ahead; the big **target model** verifies them in one parallel forward pass, accepting the longest correct prefix. Speeds up memory-bound decode with *identical* output distribution when done correctly — pure latency win, no quality change.

## Common Pitfalls

- **Ignoring KV-cache memory when sizing context/batch.** Teams budget VRAM for weights only, then OOM under real traffic because the KV cache for concurrent long-context requests dwarfs expectations. Always size `weights + peak KV cache + activation overhead`.
- **Optimizing throughput and wrecking TTFT.** Cranking batch size and letting prefill and many decodes contend maximizes tokens/sec but pushes first-token latency past the SLO. Interactive UX cares about TTFT + ITL; batch offline jobs care about throughput. Optimize for the right one (some servers separate/prioritize prefill vs decode to protect TTFT).
- **The quantization quality cliff.** 8-bit and FP8 are usually near-lossless; aggressive 4-bit (or quantizing the KV cache) can degrade reasoning/long-context quality sharply and non-uniformly. Always eval on your task, not just perplexity — the drop is often invisible until a hard prompt.
- **Assuming decode is compute-bound.** It isn't; it's memory-bandwidth-bound. Buying more FLOPs won't speed single-request generation — reducing bytes moved (quantization, speculative decoding, better batching) will.
- **Padding-heavy static batching.** Mixing a 4k-token and a 50-token request in a padded static batch wastes almost all the work on padding. Use continuous batching.
- **No admission control / backpressure.** Unbounded queuing under load blows up KV-cache memory and tail latency. Apply [backpressure](_meta/glossary.md#backpressure) and reject/queue past capacity rather than OOM-crash.

## Trade-offs

**Throughput vs latency (the central tension):**

| Bigger batch | Smaller batch |
|---|---|
| Higher tokens/sec, better GPU utilization, lower cost/token | Lower TTFT and per-request latency |
| Worse per-request latency, higher p99 | Wasted GPU, higher cost/token |
| Right for offline/bulk (embeddings, batch summarization) | Right for interactive (chat, autocomplete) |

**Quantization levels:**

| Precision | Memory vs FP16 | Quality | Typical use |
|---|---|---|---|
| FP16/BF16 | 1× (baseline) | Reference | Quality-critical serving |
| FP8 / INT8 | ~0.5× | Near-lossless usually | Default cost/quality sweet spot |
| 4-bit (GPTQ/AWQ) | ~0.25× | Small-to-noticeable drop; task-dependent | Fit bigger model on smaller GPU |
| KV-cache quant | Shrinks per-token cache | Can hurt long-context | Extend context/batch under memory pressure |

**Parallelism choice:** tensor parallel = lower latency but demands high-bandwidth interconnect (NVLink); pipeline parallel = cheaper interconnect but pipeline bubbles and higher latency. Prefer tensor parallel within a node, pipeline across nodes.

## Implementation Notes

Reference sketch of the prefill/decode loop with a KV cache — not quizzed.

```
# One request
kv = empty_cache()

# PREFILL: whole prompt in parallel, compute-bound
logits, kv = model.forward(prompt_tokens, kv)   # fills KV for all prompt positions
next = sample(logits[-1])                        # <- TTFT measured here
emit(next)

# DECODE: one token at a time, memory-bandwidth-bound
while next != EOS and len < max_tokens:
    logits, kv = model.forward([next], kv)       # single-token step, attends over kv
    next = sample(logits[-1])
    emit(next)                                    # inter-token latency = ITL/TPOT
```

Continuous batching schedules many such requests at the *iteration* level: each engine step advances every in-flight request by one token, admits new requests after their prefill, and evicts finished ones — with PagedAttention allocating KV in shared fixed-size blocks rather than one contiguous buffer per request.

## Resources

- [vLLM: Easy, Fast, and Cheap LLM Serving with PagedAttention](https://blog.vllm.ai/2023/06/20/vllm.html)
- Kwon et al., *Efficient Memory Management for LLM Serving with PagedAttention* (SOSP 2023)
- Yu et al., *Orca: A Distributed Serving System for Transformer-Based Generative Models* (OSDI 2022) — continuous batching
- Leviathan et al., *Fast Inference from Transformers via Speculative Decoding* (2023)
- [NVIDIA TensorRT-LLM documentation](https://nvidia.github.io/TensorRT-LLM/)

## Related

- [[rag-retrieval-augmented-generation]]
- [[caching-strategies]]
- [[backpressure-and-bulkhead]]
- [[agentic-ai-patterns]]
