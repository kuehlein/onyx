---
id: search-and-inverted-index
type: flashcard
tags:
  - system-design
  - databases
tiers:
  system-design: 2
created: 2026-09-08
confidence: high
priority: normal
---

# Search and the Inverted Index

Full-text search is powered by the [inverted index](_meta/glossary.md#inverted-index): a map from each *term* to the posting list of documents (and positions) containing it — the inverse of a document→terms mapping. The principle: a B-tree index answers "does this column equal/start-with X"; an inverted index answers "which documents mention word X", ranked by how *relevant* each is. Getting there requires an analysis pipeline (tokenize + normalize) applied identically at index time and query time, plus a relevance function (BM25) to order the matches. Engines like Elasticsearch/OpenSearch build this on Apache Lucene: sharded, distributed, and near-real-time — deliberately trading strong consistency for search throughput.

> [!tip] Recognition
> Reach for a search engine + inverted index when you see: **free-text / keyword search over documents** ("search articles by content"), **relevance ranking** ("best matches first", not just filtering), **typo-tolerance / fuzzy / autocomplete**, **faceted navigation** (filter counts by category/brand/price), or **multi-field text search** that a `WHERE ... LIKE '%term%'` scan can't serve at scale. The tell that it is NOT a plain DB index: you need *ranking* and *word-level* matching, not exact-column lookups.

> [!warning] Don't confuse with the sibling index/storage cards
> - **vs. `database-indexing`:** that card is about *access-path* indexes (B-tree/hash) that answer "find the row(s) where `col = X` / `col BETWEEN …`" and return whole rows — exact/range lookups on **structured columns**, no notion of relevance. The inverted index answers "which *documents* mention **word** X, ranked by relevance" — the distinguishing signal is **ranked, word-level, full-text matching**, not exact-column retrieval.
> - **vs. `storage-engines`:** that card explains the physical write path (B-tree vs [LSM](_meta/glossary.md#lsm)-tree). Beware the false friend — an LSM-tree *also* uses **immutable segments + compaction**, exactly like Lucene here. But storage-engines is about *how any table durably persists and reads back rows*; the inverted index is a *derived, query-side data structure for text relevance* sitting on top of (and rebuilt from) whatever storage engine holds the source of truth. Same "immutable segment" mechanic, completely different job.

## When to Use

**Problem signals that suggest a search engine / inverted index:**
- "Users type keywords and expect the most relevant documents first" — ranking, not just filtering
- "Search must tolerate typos / stemming / synonyms" ("run" matches "running")
- "We need autocomplete / did-you-mean / highlighting of matched terms"
- "Faceted search: show result counts per category, then let users drill down"
- "Search the full text of millions of documents / logs / products" where `LIKE '%x%'` full-scans

**Prefer a search engine over alternatives when:**
- Over `WHERE col LIKE '%term%'`: a leading-wildcard `LIKE` can't use a B-tree index and full-scans; it also has no relevance ranking, no stemming, no typo-tolerance
- Over a Postgres `GIN`/`tsvector` full-text index: use the DB's built-in FTS when search is a *secondary* feature on modest data and you want to avoid running a second system; move to Elasticsearch/OpenSearch when you need scale, richer relevance tuning, faceting, or fuzzy/autocomplete
- Over a vector database: use lexical (keyword) search when queries are exact-term/keyword-driven; use vector/semantic search for meaning-based similarity. Modern systems often combine both (hybrid search)

**Do not use when:**
- You need exact-match lookups or strong read-after-write consistency on the primary record → keep the source of truth in an [OLTP](_meta/glossary.md#oltp) database; the search index is a derived, eventually-consistent copy
- Data is small and search is trivial → DB `LIKE`/FTS is simpler than operating a cluster
- You're tempted to use it as your primary datastore → it is not strongly consistent and not a system of record

## Key Properties

- **Inverted index structure:** `term → posting list` of doc IDs; positions are stored too, which is what enables *phrase* queries ("new york" as adjacent words) and proximity search. This is the inverse of a forward index (doc → its terms).
- **Analysis pipeline (index time AND query time):** raw text → **tokenize** (split into terms) → **normalize** (lowercase, remove punctuation, **stem** "running"→"run", apply synonyms/stopwords). The *same analyzer* must run on the query, or the query terms won't match the indexed terms. This symmetry is the single most important invariant.
- **Relevance ranking = BM25 (default since Elasticsearch 5.0 / Lucene 6, 2016).** BM25 scores a doc from three signals: term frequency in the doc (with diminishing returns), inverse document frequency (rare terms weigh more), and document length normalization (long docs don't win by mere size). It superseded classic TF-IDF as the default.
- **Segment-based, near-real-time:** Lucene writes immutable segments; a newly indexed doc is not searchable until a **refresh** exposes a new segment. Default `refresh_interval` is ~1s (only on indices searched in the last 30s), so there is a small indexing→visible lag — hence "near-real-time," not real-time.
- **Sharded + replicated:** an index is split into shards for horizontal scale and replicated for availability; a query scatters to all shards and gathers/merges the ranked results.

## Trade-offs

| Concern | DB `LIKE` / B-tree | DB full-text (GIN/tsvector) | Search engine (Elasticsearch/OpenSearch) |
|---|---|---|---|
| Keyword/phrase relevance ranking | None (boolean match only) | Basic (`ts_rank`) | BM25, tunable, first-class |
| Typo/fuzzy, synonyms, stemming | No (stemming absent) | Stemming yes; fuzzy limited | Yes (fuzzy, synonyms, analyzers) |
| Faceting / aggregations | Manual `GROUP BY` | Manual | Native, fast |
| Consistency | Strong (same DB) | Strong (same DB) | Near-real-time, eventually consistent |
| Operational cost | None (already there) | Low (same DB) | High (separate cluster to run + sync) |
| Scale of full-text corpus | Poor (`%term%` scans) | Moderate | Designed for it |

- **Consistency vs. search performance:** immutable segments + periodic refresh give fast indexing and fast search but mean writes are visible only after refresh, and the index lags the source DB.
- **Second system to keep in sync:** the search index is a *derived* store. You must stream changes from the primary DB into it — typically via Change Data Capture ([CDC](_meta/glossary.md#change-data-capture)) tailing the [WAL](_meta/glossary.md#wal), or an outbox — to avoid dual-write inconsistency.
- **Analyzer choices are baked in at index time:** changing the analyzer (e.g. adding a synonym set or switching stemmer) usually requires **reindexing** the whole corpus.

## Common Pitfalls

- **Mismatched index-time and query-time analyzers.** If you stem/lowercase at index time but not at query time (or use different analyzers), queries silently return nothing. The analyzer must be symmetric.
- **Treating the search engine as source of truth.** It's near-real-time and not strongly consistent; a crash/reindex can lose or reorder data. Keep the authoritative copy in a database and rebuild the index from it.
- **Dual writes.** Writing to the DB and the search index in application code creates drift when one write fails. Use CDC or a transactional outbox so the index is derived from the committed DB state.
- **Expecting instant visibility.** New docs aren't searchable until the next refresh (~1s default). Force-refreshing per write to "fix" this destroys indexing throughput — design for the lag instead.
- **Over-sharding.** Each shard is a full Lucene index with fixed overhead; too many shards for the data volume wastes heap and slows scatter-gather. Size shards to the data, don't default to many.
- **Deep pagination (`from`/`size` for page 10,000).** Scatter-gather makes deep offsets expensive (each shard must return `from+size`); use `search_after` / a scroll/point-in-time cursor for deep paging.

## Implementation Notes

- **Analyzer** (Elasticsearch): a mapping defines per-field analyzers, e.g. a `standard` analyzer (tokenize + lowercase) plus a stemmer and synonym filter. Use `keyword` type for exact-match/faceting fields (no analysis) vs `text` for full-text.
- **Fuzzy / typo tolerance:** `fuzziness: AUTO` on a match query allows edits within a Levenshtein (edit-distance) bound; autocomplete is typically an edge-ngram analyzer or the completion suggester, not fuzzy match.
- **Faceting:** implemented via aggregations (`terms` aggregation for counts per category), run alongside the query.
- **Keeping in sync with the DB:** stream row changes via Debezium/Kafka Connect ([CDC](_meta/glossary.md#change-data-capture)) or a transactional outbox into the index; do a full reindex when analyzers or mappings change.
- **Relevance tuning:** BM25 exposes `k1` (term-frequency saturation, ES default 1.2) and `b` (length normalization, default 0.75); field boosting and function-score adjust ranking.

## Resources

- Elastic — Near real-time search: https://www.elastic.co/docs/manage-data/data-store/near-real-time-search
- Elastic Blog — Practical BM25 (Part 2, the algorithm): https://www.elastic.co/blog/practical-bm25-part-2-the-bm25-algorithm-and-its-variables
- Apache Lucene — Index file formats / segments: https://lucene.apache.org/core/9_0_0/core/org/apache/lucene/codecs/lucene90/package-summary.html
- Kleppmann, *Designing Data-Intensive Applications*, Ch. 3 (full-text search & fuzzy indexes) and Ch. 11 (derived data / keeping systems in sync)

## Related

- [[database-indexing]]
- [[sql-vs-nosql]]
- [[change-data-capture]]
- [[caching]]
- [[sharding]]
