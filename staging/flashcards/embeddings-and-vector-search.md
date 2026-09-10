---
id: embeddings-and-vector-search
type: flashcard
tags:
  - system-design
  - ai-infra
  - vector-search
  - embeddings
tiers:
  system-design: 3
created: 2026-09-10
confidence: high
priority: normal
---

# Embeddings & Vector Search

An [embedding](_meta/glossary.md#embedding) maps an item (text, image, user) to a dense vector so that geometric closeness encodes semantic similarity — "king" lands near "queen," not near "kangaroo." [Vector search](_meta/glossary.md#vector-search) then answers "find the k items most similar to this query vector," which powers semantic retrieval, recommendations, dedup, and the retrieval half of RAG. It works because a learned model has already compressed meaning into coordinates, so nearest-neighbor geometry approximates human notions of relatedness.

> [!tip] Recognition
> Reach for this when the requirement is "search by meaning, not exact words": semantic search, "find similar images/products/documents," recommendations ("more like this"), near-duplicate detection, or the retrieval step of a RAG / LLM feature. Signals: paraphrase-tolerant matching, "top-k most similar," [cosine](_meta/glossary.md#cosine-similarity)/dot-product similarity, or an existing embedding model producing 384–3072-dim vectors.

## When to Use

**Problem signals that suggest embeddings + vector search:**
- The query is expressed by *meaning* not exact tokens — paraphrases, synonyms, cross-lingual matches must hit ("how to reset password" should match "recover forgotten login")
- "Find similar X to this X" over items with no natural keyword (images, audio, user-behavior profiles, product SKUs)
- Retrieval feeding an LLM (RAG): fetch the top-k relevant chunks to stuff into the context window
- Recommendations / candidate generation: embed users and items into one space, retrieve nearest items
- Near-duplicate detection, clustering, semantic dedup at scale

**Prefer vector search over alternatives when:**
- Over lexical / [inverted-index](_meta/glossary.md#inverted-index) ([BM25](_meta/glossary.md#bm25)) search: when relevance depends on semantics rather than shared terms. BM25 fails on paraphrase and vocabulary mismatch (query and doc use different words for the same concept); embeddings bridge that gap.
- Over a relational `WHERE` / filter query: when there is no crisp predicate — "similar" is fuzzy and graded, not a boolean match.
- Over training a bespoke classifier: an off-the-shelf embedding model + kNN gives strong zero-shot similarity with no labeled training set.

**Do not use when:**
- Exact-match, IDs, codes, rare tokens, or boolean/range predicates dominate → use lexical / inverted-index or a SQL index instead (vectors are bad at exact string and precise numeric matching).
- Corpus is small (< ~10k–100k vectors) → exact brute-force kNN is simpler, exact, and fast enough; skip an [ANN](_meta/glossary.md#ann) index entirely.
- Requirements need provable exact top-k or strict recall guarantees → ANN trades recall for speed; use exact kNN or lexical search.

## Key Properties

**Similarity metrics — pick to match how the model was trained:**

| Metric | Formula intuition | Use when |
|---|---|---|
| Cosine | angle between vectors; ignores magnitude | text embeddings where length shouldn't matter (the common default) |
| Dot product | cosine × magnitudes | model trained with dot-product objective; magnitude carries signal |
| Euclidean (L2) | straight-line distance | spatial / image features where absolute distance matters |

- **Normalization identity:** if all vectors are L2-normalized (unit length), cosine similarity and dot product rank identically, and Euclidean becomes a monotonic function of cosine. Normalizing up front lets a dot-product index behave like cosine — a common practical trick.

**Exact kNN vs Approximate NN (ANN) — the central trade:**
- **Exact (brute force):** compare the query against every vector. `O(n·d)` per query, exact recall. Fine for small n; linear scan kills you at millions of vectors.
- **ANN:** build an index that returns *most* of the true neighbors in *sublinear* time. You accept slightly-imperfect recall (e.g. 95–99%) to get orders-of-magnitude lower latency and cost at scale. Recall is a *tunable knob*, not a fixed property.

**Dimensionality:** typical models emit 384 (small), 768 (BERT-class), 1536 / 3072 (OpenAI-class). Higher dims capture more nuance but cost more memory, slower distance math, and worsen the curse of dimensionality (distances concentrate, neighbors blur). Some models support *Matryoshka* truncation — safely shortening a vector to trade a little quality for a lot of memory.

**Filtering (metadata + vector):** real queries combine "semantically similar" with "AND tenant=42 AND lang=en." Pre-filtering (restrict candidate set, then search) preserves recall but can be slow/awkward with graph indexes; post-filtering (search, then drop non-matching) is easy but can return too few results when the filter is selective. Mature vector DBs do filtered ANN natively.

## Common Pitfalls

- **Mismatched embedding model between index and query.** You MUST embed the query with the *same model and version* used to build the index — vectors from different models live in incompatible spaces and similarity becomes noise. Re-embedding the whole corpus is required on any model upgrade.
- **Unnormalized vectors with cosine.** Feeding raw (non-unit) vectors to a dot-product index while assuming cosine ranking silently distorts results toward high-magnitude vectors. Normalize, or explicitly use a cosine metric.
- **ANN recall silently low.** ANN degrades quietly — it still returns k results, just the *wrong* ones. Without measuring recall against exact kNN on a sample, you can't tell a 99% index from a 60% one. Always benchmark recall vs. latency when tuning (efSearch / nprobe).
- **Curse of dimensionality / poor chunking.** Over-long or semantically mixed chunks embed into a mushy "average" vector that matches everything weakly. Chunk to coherent units; don't assume higher dims are strictly better.
- **Treating vector search as a database of record.** Vector stores are approximate, memory-hungry indexes — keep the source of truth (and rich metadata) in your primary store; store IDs alongside vectors.
- **Ignoring index build/update cost.** Graph indexes are expensive to build and awkward to update incrementally; forgetting this leads to painful re-index cycles on write-heavy corpora.

## Trade-offs

**ANN index families — disambiguate by the distinguishing axis:**

| Method | Core idea (axis) | Strengths | Weaknesses |
|---|---|---|---|
| **[HNSW](_meta/glossary.md#hnsw)** | *graph* — navigable small-world graph, greedy descent through layers | excellent recall/latency; no training step; the default high-quality choice | high memory (stores graph + full vectors); slow builds; incremental updates/deletes awkward |
| **[IVF](_meta/glossary.md#ivf)** | *partitioning* — cluster vectors, probe only nearest `nprobe` cells | tunable recall/speed via nprobe; lower memory than HNSW; fast build | requires a training/clustering step; recall drops if true neighbor sits in an unprobed cell |
| **[PQ](_meta/glossary.md#product-quantization) / quantization** | *compression* — split vector, quantize sub-vectors to codebook IDs | massive memory savings (often 4–32×); enables billion-scale in RAM | lossy → some recall/precision loss; distances are approximate |
| **IVF + PQ** | partition *and* compress (common combo) | scales to huge corpora on modest RAM | compounds both training need and quantization loss |

*One-line contrast:* **HNSW = graph (recall king, memory-hungry, hard to update); IVF = cluster-probing (tunable, needs training); PQ = vector compression (memory saver, lossy).*

**Lexical vs. semantic vs. hybrid:**

| Approach | Best at | Weak at |
|---|---|---|
| Lexical (BM25 / [inverted-index](_meta/glossary.md#inverted-index)) | exact terms, rare tokens, IDs, codes, names | paraphrase, synonyms, vocabulary mismatch |
| Semantic (vectors) | meaning, paraphrase, cross-lingual, fuzzy "similar" | exact keywords, out-of-vocab identifiers, precise matches |
| **Hybrid (fusion + rerank)** | combines both, usually best overall relevance | more moving parts; needs fusion tuning (e.g. RRF) + optional cross-encoder rerank |

Hybrid typically wins because lexical nails exact/rare tokens that vectors blur, and vectors nail semantics that BM25 misses; fuse candidate lists (Reciprocal Rank Fusion) and optionally rerank the top-N with a cross-encoder.

**Where to run it:**

| Option | Fits when |
|---|---|
| `pgvector` / existing store (Postgres, Elasticsearch, Redis) | modest scale (≲ few M vectors), you want one system, transactional metadata + vectors together, avoid new infra |
| Dedicated vector DB (Milvus, Qdrant, Weaviate, Pinecone) | very large / high-QPS workloads, need advanced filtered ANN, quantization, horizontal sharding, and specialized index tuning |

## Resources

- Malkov & Yashunin, "Efficient and robust approximate nearest neighbor search using Hierarchical Navigable Small World graphs" (HNSW paper)
- Jégou, Douze & Schmid, "Product Quantization for Nearest Neighbor Search"
- [Faiss wiki — Guidelines to choose an index](https://github.com/facebookresearch/faiss/wiki/Guidelines-to-choose-an-index)
- [pgvector documentation](https://github.com/pgvector/pgvector)
- [ANN-Benchmarks — recall/latency comparisons across libraries](https://ann-benchmarks.com/)

## Related

- [[rag-retrieval-augmented-generation]]
- [[search-and-inverted-index]]
- [[consistent-hashing]]
- [[caching-strategies]]
