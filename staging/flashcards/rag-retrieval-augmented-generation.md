---
id: rag-retrieval-augmented-generation
type: flashcard
tags:
  - system-design
  - ai-infra
  - rag
  - llm
tiers:
  system-design: 3
created: 2026-09-10
confidence: high
priority: normal
---

# RAG (Retrieval-Augmented Generation)

[RAG](_meta/glossary.md#rag) grounds an LLM in external knowledge by retrieving relevant documents at query time and injecting them into the prompt, so the model answers from provided evidence instead of its frozen parametric memory. It works because the expensive, hard-to-update part (facts) is moved out of the weights and into a searchable index you can edit cheaply — cutting hallucination, enabling citations, and keeping answers fresh without retraining.

> [!tip] Recognition
> Cues: "answer over our private/internal docs", "cite sources", "the knowledge changes daily/hourly", "the model doesn't know about events after its cutoff", "chatbot over a knowledge base / wiki / support tickets", "reduce hallucination", "we can't afford to fine-tune every time the data changes". Anything that pairs an LLM with a corpus it wasn't trained on.

## When to Use

**Problem signals that suggest RAG:**
- The knowledge is **private, proprietary, or per-tenant** — it was never in the training data and can't be shared
- The knowledge is **large** (millions of docs) — far more than fits in any context window
- The knowledge **changes frequently** — you need to add/update/delete facts without retraining
- **Attribution is required** — the answer must cite which source it came from (compliance, trust, auditability)
- You need to **cut hallucination** on factual questions by constraining the model to retrieved evidence

**Prefer RAG over alternatives when:**
- Over **fine-tuning**: you need up-to-date *facts* and *citations*. Fine-tuning bakes knowledge into weights (stale the moment data changes, no attribution, and models are poor at reliably memorizing facts). Use fine-tuning to change *behavior/format/style/tone*, not to teach facts.
- Over **long-context (paste everything)**: the corpus exceeds the window, or you want to pay for tokens only for the ~k relevant chunks instead of the whole corpus on every call.

**Do not use when:**
- The task needs a change in **behavior, output format, or domain style/jargon**, not new facts → fine-tune instead.
- The relevant knowledge is **small and static** enough to fit comfortably in context → just put it in the prompt (long-context); a retrieval pipeline is unnecessary complexity.
- The base model **already knows the answer** reliably (common, stable public knowledge) → retrieval only adds latency and failure surface.

## Key Properties

- **Two-stage, decoupled system**: a *retriever* (search problem) feeds a *generator* (LLM). Quality is bounded by the weaker stage — perfect generation over the wrong chunks still produces a confident wrong answer.
- **Knowledge lives outside the weights**: update the index (upsert/delete a document) and the next query reflects it immediately — no training run, no redeploy.
- **Grounding enables citations**: because each answer is derived from specific retrieved chunks, you can surface source links and let users verify.
- **Retrieval is approximate**: top-k similarity search returns *plausibly* relevant chunks, not guaranteed-correct ones — the generator must be prompted to say "I don't know" when evidence is absent (otherwise it fills the gap by hallucinating).
- **[Chunking](_meta/glossary.md#chunking) dominates quality**: retrieval operates on chunks, so how you split documents determines what can ever be retrieved as a coherent unit. Bad chunking caps the whole system's ceiling.
- **Hybrid retrieval usually beats pure vector**: combining dense (semantic [embeddings](_meta/glossary.md#embedding)) with sparse/lexical ([BM25](_meta/glossary.md#bm25)-style keyword) matching catches both paraphrases and exact terms (IDs, error codes, names) that embeddings miss.

## Common Pitfalls

- **Confidently wrong on bad retrieval**: if retrieval returns irrelevant or empty chunks, the LLM often answers anyway from parametric memory. Fix: instruct "answer only from context; if not present, say you don't know," and enforce a relevance threshold.
- **Lost-in-the-middle**: LLMs attend most strongly to the *start* and *end* of the context and neglect the middle. Stuffing many chunks buries the best one — [rerank](_meta/glossary.md#reranking) and place the most relevant chunk near the top/bottom, keep k small.
- **Chunk boundaries splitting a fact**: naive fixed-size splits cut a table, sentence, or answer in half so no single chunk is retrievable and coherent. Use overlap and/or semantic/structural chunking.
- **Stale index**: source docs changed but embeddings weren't re-ingested → the system cites outdated facts. Needs an ingestion/refresh pipeline, ideally [change-data-capture](_meta/glossary.md#change-data-capture)-driven.
- **No citations**: generating an answer without carrying source references back to the user destroys the main trust benefit of RAG.
- **Embedding-model mismatch**: query and documents must be embedded with the *same* model; swapping the model invalidates the whole index (must re-embed everything).
- **Evaluating only end-to-end**: measure the two stages separately — *retrieval recall/precision* (did the right chunk come back?) vs *answer faithfulness/groundedness* (is the answer actually supported by the retrieved context, no fabrication?). A drop in either points at a different fix.

## Trade-offs

| Axis | RAG | Fine-tuning | Long-context (stuff it all in) |
|---|---|---|---|
| Best for | Injecting **facts/knowledge** at inference | Changing **behavior/format/style** | **Small, static** knowledge that fits the window |
| Knowledge freshness | Live — edit the index | Stale until retrained | Live — but you resend it every call |
| Update cost | Cheap (upsert a doc) | Expensive (retraining run) | Trivial, but paid per token per request |
| Attribution / citations | Native (per-chunk sources) | None | Possible but not enforced |
| Cost per query | Low (only top-k tokens) | Low inference (cost is upfront) | High ($$ scales with corpus size × every call) |
| Scale of knowledge | Millions of docs | Fixed by training set | Bounded by context window |
| Main failure mode | Bad retrieval → confident wrong answer | Hallucinated/outdated facts | Lost-in-the-middle, token cost, limit overflow |
| Setup complexity | High (pipeline + vector store) | Medium–high (data + training) | Lowest |

**Decision boundary:** *facts that change* → RAG. *Behavior/style/format* → fine-tune. *Small and stable* → long-context. These compose — e.g. fine-tune tone + RAG for facts.

## Implementation Notes

Blocklisted from quiz — reference pipeline sketch.

**Offline ingestion (index build):**
```
for doc in corpus:
    text   = extract(doc)              # parse PDF/HTML/etc.
    chunks = split(text,
                   size=~200-500 tokens,
                   overlap=~10-20%,     # or split on semantic/structural boundaries
                   keep_metadata=True)  # source id, title, section -> for citations
    vecs   = embed(chunks)             # SAME embedding model as query time
    index.upsert(vecs, chunks, metadata)  # vector store: pgvector, Pinecone, Milvus, ...
```

**Online query path:**
```
q_vec        = embed(query)                    # same model as ingestion
candidates   = index.ann_search(q_vec, k=~20)  # approximate NN (HNSW/IVF)
candidates  += bm25_search(query, k=~20)       # optional hybrid / lexical
top_k        = rerank(query, candidates)[:~5]  # optional cross-encoder reranker
prompt       = system_instructions
             + "Answer only from context; cite sources; say 'unknown' if absent."
             + format(top_k, with_citations=True)
             + query
answer       = llm.generate(prompt)            # grounded, attributable
```
- **Tune first**: chunk size/overlap and k dominate quality; add a **reranker** before adding a bigger model.
- **Cache** query embeddings and full answers for repeated questions ([[caching-strategies]]) to cut latency and cost.
- See [[embeddings-and-vector-search]] for the retrieval half ([ANN](_meta/glossary.md#ann), [HNSW](_meta/glossary.md#hnsw) vs [IVF](_meta/glossary.md#ivf), distance metrics).

## Resources

- Lewis et al., 2020 — "Retrieval-Augmented Generation for Knowledge-Intensive NLP Tasks" (original RAG paper): https://arxiv.org/abs/2005.11401
- Liu et al., 2023 — "Lost in the Middle: How Language Models Use Long Contexts": https://arxiv.org/abs/2307.03172
- RAGAS — RAG evaluation framework (faithfulness, answer/context relevance): https://docs.ragas.io/
- Anthropic — Contextual Retrieval (improving chunk quality): https://www.anthropic.com/news/contextual-retrieval
- Pinecone — Retrieval-Augmented Generation guide: https://www.pinecone.io/learn/retrieval-augmented-generation/

## Related

- [[embeddings-and-vector-search]]
- [[llm-serving-and-inference]]
- [[agentic-ai-patterns]]
- [[caching-strategies]]
