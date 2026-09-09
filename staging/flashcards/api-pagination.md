---
id: api-pagination
type: flashcard
tags:
  - backend
  - api-design
tiers:
  backend: 2
created: 2026-09-08
confidence: high
priority: normal
---

# API Pagination

Pagination splits a large result set into fetchable chunks. The core design decision is how a page identifies "where to continue": by a numeric position (offset/limit) or by an opaque pointer to the last row seen (cursor/keyset). Offset pages are addressable and jumpable but degrade on deep pages and are unstable under concurrent writes; cursor pages walk a sorted index from the last-seen key, giving stable, index-fast page-after-page traversal at the cost of losing random jump-to-page.

> [!tip] Recognition
> Reach for a **pagination strategy** (not caching/[rate-limiting](_meta/glossary.md#rate-limiting)) when the signal is about *traversing a result set*: "load more / infinite scroll," "the feed jumps or shows duplicates when new posts arrive," "page 5000 of the report is slow," "export all rows without hitting [OOM](_meta/glossary.md#oom)." Choose **cursor** when the list is large, infinite, or real-time-mutating; choose **offset** when the table is small/stable and users need to jump to an arbitrary page number.

## When to Use

**Cursor / keyset — when:**
- Large or unbounded result sets (feeds, timelines, activity logs, event streams)
- Real-time data where rows are inserted/deleted between page loads
- Infinite scroll / "load more" UX (you only ever go forward from where you are)
- Deep traversal or full exports where offset would scan-and-discard millions of rows

**Offset / limit — when:**
- Small, relatively stable datasets (admin tables, settings lists)
- The UI genuinely needs numbered pages or "jump to page N"
- Total count and random access matter more than deep-page performance

**Contrast cue vs. `rest-api-design` (the confusable sibling):** REST design is about resource modeling, HTTP verbs/status codes, and URL structure — the *shape of the whole API*. Pagination is one narrow concern *within* a collection endpoint: how a single list response is chunked and continued. Also distinct from **caching** (avoid recomputing a response) and **rate-limiting** (cap request frequency) — pagination bounds *response size and traversal cost*, not request rate or recomputation.

## Key Properties

**Offset / limit** (`LIMIT 20 OFFSET 40`):
- Page N is directly addressable → jump-to-page and "total pages" are trivial
- Stateless: the client only needs page number + size
- The database must still *read and discard* all OFFSET rows before returning the page

**Cursor / keyset** (`WHERE (sort_key) > :cursor ORDER BY sort_key LIMIT 20`):
- The cursor is an **opaque token encoding the last-seen row's sort key(s)** — not a row count
- Continuation is `WHERE sort_key > cursor`, which **seeks into the index** instead of scanning
- Requires a **stable, unique, ordered** sort key; ties are broken by appending a unique tiebreaker (e.g. `(created_at, id)`)
- Forward traversal only by nature; jump-to-arbitrary-page is not supported

## Time & Space Complexity

| Operation | Offset/limit | Cursor/keyset |
|---|---|---|
| Fetch page at depth D (page size k) | O(D + k) — scans then discards D rows | O(log n + k) — index seek then k rows |
| Jump to arbitrary page | Supported, but cost grows with depth | Not supported |
| Cost of last page in a large set | Worst case (scans ~entire index) | Same as first page |

Deep-offset degradation is the headline fact: `OFFSET 1000000` forces the engine to walk a million index/heap entries only to throw them away. Keyset stays flat because every page is a fresh index range seek.

## Trade-offs

**Stability under concurrent writes:**
- **Offset is unstable.** If a row is inserted or deleted before the current offset between two page fetches, the window shifts — the user **skips an item or sees a duplicate** at the page boundary.
- **Cursor is stable.** Because continuation anchors to a specific sort-key value, inserts/deletes elsewhere don't shift the boundary; you resume exactly after the last row you saw.

**Random access vs. performance:**
- Offset trades deep-page performance and stability for the ability to jump to any page and show a total-page count.
- Cursor trades random access (no "go to page 500," harder total counts) for flat performance and correctness at any depth.

**Client complexity:** offset is trivially client-driven (a page number); cursor requires the server to mint and the client to echo an opaque token, and typically means returning `next_cursor` in the response.

## Common Pitfalls

- **Non-unique sort key breaks keyset.** Paginating by a column with duplicates (e.g. `created_at` alone) can skip or repeat rows at page boundaries where ties straddle the cut. Always include a unique tiebreaker: `ORDER BY created_at, id` and encode both in the cursor.
- **Sort key must match an index.** Keyset's speed guarantee only holds if `(sort columns)` is backed by an index in the same order/direction; otherwise the "seek" becomes a full sort + scan.
- **Deep OFFSET in production.** Offset feels fine in testing on small tables and quietly becomes a latency/CPU sink on page thousands — a classic scaling surprise.
- **Leaking internals in the cursor.** Return the cursor as an opaque, encoded token (e.g. base64), not a raw DB id/offset, so clients can't tamper with it or depend on its structure — and so you can change the underlying scheme later.
- **Unbounded `limit`.** Always clamp page size to a server-side max; an unvalidated `limit=1000000` is effectively no pagination and a DoS vector.
- **Total counts on huge tables.** `COUNT(*)` for "total pages" is itself an expensive full scan at scale; with cursor pagination, prefer omitting exact totals (or use an estimate) rather than forcing a count.

## Implementation Notes

- Typical cursor response shape: `{ "data": [...], "next_cursor": "eyJpZCI6..." , "has_more": true }`; client passes `?cursor=<token>&limit=20` on the next call.
- Keyset SQL pattern (compound key): `WHERE (created_at, id) > (:last_created_at, :last_id) ORDER BY created_at, id LIMIT :k` — row-value comparison keeps it a single index range scan.
- Reference APIs: Stripe uses cursor pagination (`starting_after`/`ending_before` object ids, `limit` 1–100); Slack uses opaque `cursor` tokens returning `next_cursor` in `response_metadata`. GitHub's REST default is page-based (`page`/`per_page`) with `Link` headers, with opaque cursor pagination (`before`/`after`) on only some endpoints — a reminder that one API can offer both styles.

## Resources

- Use The Index, Luke — Paging Through Results (offset vs. keyset): https://use-the-index-luke.com/no-offset
- Stripe API — Pagination: https://docs.stripe.com/api/pagination
- Slack API — Cursor-based pagination: https://api.slack.com/docs/pagination
- GitHub REST API — Using pagination: https://docs.github.com/en/rest/using-the-rest-api/using-pagination-in-the-rest-api

## Related

- [[rest-api-design]]
- [[database-indexing]]
- [[caching]]
- [[rate-limiting]]
- [[sql-vs-nosql]]
