---
id: object-storage
type: flashcard
tags:
  - system-design
  - storage
  - object-storage
tiers:
  system-design: 2
created: 2026-09-08
confidence: high
priority: normal
---

# Object / Blob Storage

Object storage (S3, GCS, Azure Blob) exposes a flat namespace of immutable objects — each a `key -> blob + metadata` pair — over an HTTP API, not a filesystem. There are no directories and no in-place edits: to "change" an object you overwrite the whole thing. This constraint is what buys the system its defining traits — near-limitless horizontal scale, extreme durability via replication/erasure coding, and low cost — at the price of high per-request latency. Reach for it when you have large, write-once/read-many blobs that don't need transactional access or partial mutation.

> [!tip] Recognition
> Signals that point to object storage: **large binary blobs** (images, video, PDFs, ML datasets, backups, logs); the data is **written once and read many times** with no partial edits; you need **cheap, effectively-unlimited capacity** and **11-nines durability**; the access path is **HTTP(S) / URL**, often fronted by a [CDN](_meta/glossary.md#cdn); or you're building a **data lake** for batch analytics. Contrast: if you need low-latency random reads/writes, POSIX file semantics, or in-place mutation, this is the wrong tool.

> [!warning] Don't confuse with (interference)
> - **vs. CDN:** object storage is the **durable system of record** (the origin). A CDN is an ephemeral **cache** at the edge — it can be wiped and refilled, holds no authoritative copy. Distinguishing signal: "where does the byte *live* forever" = object storage; "how do I serve it *fast* near the user" = CDN.
> - **vs. caching:** a cache trades durability for speed and may evict anything at any time; object storage is the opposite trade — durable and cheap but slow per request. If losing the data is acceptable, it's a cache, not object storage.
> - **vs. storage engines (LSM/B-tree):** storage-engines are the *internal* on-disk structures a database uses to index and query structured rows with low-latency point/range access. Object storage is an *external* service for opaque whole-blob GET/PUT with no indexing or query. Signal: "query by content / secondary index" = storage engine; "fetch the whole file by key" = object storage.

## When to Use

**Problem signals that suggest object storage:**
- "Store user-uploaded photos/videos and serve them globally" — media at scale, read-heavy, CDN-frontable
- "We need somewhere to put nightly database backups / archives" — large, write-once, rarely-read blobs
- "Build a data lake for the analytics team" — dump raw Parquet/JSON, query later with Athena/Spark
- "Host the static assets for our SPA" — HTML/JS/CSS/images behind a CDN
- "Persist artifacts from CI / ML training checkpoints" — big immutable files, cheap retention

**Prefer object storage over alternatives when:**
- Over a **filesystem / block storage (EBS, NFS)**: when you don't need POSIX semantics or in-place edits, and you want independent, elastic scaling of storage from compute — object storage scales to petabytes with no volume to provision
- Over a **database (BLOB column)**: when blobs are large (MB–GB); databases choke on large binaries (bloated backups, buffer-cache pollution). Store the blob in object storage, keep only the URL/key + metadata in the DB
- Over a **CDN alone**: object storage is the durable origin; the CDN is a cache in front of it, not a system of record

**Do not use when:**
- You need **low-latency random access** or many small reads → use a database, cache, or block storage
- You need **partial/in-place updates or appends** → objects are immutable; every edit rewrites the whole object
- You need **transactions, joins, or querying by content** → use a database (or a query engine layered on top for analytics)
- You need **POSIX file semantics** (locking, rename, directory ops) → use a real filesystem / block store

## Key Properties

- **Flat namespace, not a hierarchy.** Keys are opaque strings. `photos/2026/a.jpg` looks like a path but `/` is just a character — there are no real folders; "prefix" listing simulates directories.
- **Immutable objects, whole-object overwrite.** No in-place edits. Writing the same key replaces the entire object (and creates a new version if versioning is on). Treat this as the model. (Narrow modern exception: S3 Express One Zone *directory buckets* support appends — a single-AZ, low-latency niche, not general-purpose S3. Don't design around it in an interview.)
- **Object = blob + metadata.** Each object carries system metadata (size, ETag, content-type) and user-defined key/value metadata; the key maps to both.
- **HTTP API, not a mount.** Access is via REST (`GET`/`PUT`/`DELETE` on a URL), not a network filesystem protocol.
- **Extreme durability, high throughput, NOT low latency.** S3 is designed for 99.999999999% (11 nines) durability via redundancy across devices/AZs; it delivers massive aggregate throughput but per-request latency is tens of ms — optimized for bandwidth, not IOPS.
- **Strong read-after-write consistency.** Since December 2020, S3 returns the latest data on a read immediately after a successful write (including overwrites) and for list operations — no more [eventual-consistency](_meta/glossary.md#eventual-consistency) window. (Historically only new-object PUTs were read-after-write consistent.)

## Trade-offs

Object storage vs. its neighbors — pick by the access pattern, not by "cloud default":

| Dimension | Object storage (S3) | Block storage (EBS) | File storage (NFS/EFS) | Database BLOB |
|---|---|---|---|---|
| Namespace | Flat key -> object | Raw device / volume | POSIX tree | Row/column |
| Mutation | Immutable, whole-object overwrite | In-place, byte-level | In-place, byte-level | In-place |
| Access | HTTP API | Attached to one VM | Mounted, shared | Query engine |
| Scale | ~Unlimited, elastic | Fixed per volume | Large but pricier | Bounded by engine |
| Latency | High (tens of ms) | Very low | Low–moderate | Low |
| Cost/GB | Cheapest | Moderate | Higher | Highest |
| Best for | Blobs, backups, data lake, static assets | Boot/DB disks, low-latency IO | Shared POSIX access | Structured, queryable data |

**Durability vs. latency:** redundancy (erasure coding / cross-AZ replication) is what delivers 11 nines but also why a single object read is slow relative to local disk — the system optimizes for not losing data and for aggregate bandwidth, not for tail latency.

**Cost tiering vs. retrieval cost/time:** lifecycle policies auto-migrate cold objects to cheaper tiers (e.g. Glacier). Storage gets cheaper but retrieval adds latency (minutes–hours) and per-request cost — wrong for anything served on the hot path.

## Common Pitfalls

- **Treating the flat namespace as a filesystem.** There are no directories; listing by prefix is an API scan, not an `ls`. Deep "folder" hierarchies and per-object list-to-check-existence patterns get slow and expensive.
- **Trying to append or edit in place.** Objects are immutable — you must download, modify, and re-upload the whole object. Designs that assume appends (e.g. log files) belong in a log/stream store, not raw objects.
- **Uploading huge objects in a single PUT.** Large objects need multipart upload (upload parts in parallel, then complete); a single PUT is capped (5 GB on S3) and fragile — one network blip fails the whole transfer. Parts also enable retry of just the failed part.
- **Serving private objects by proxying through your app.** Streaming bytes through your servers wastes bandwidth and compute. Use presigned URLs so the client uploads/downloads directly from object storage with time-limited, scoped credentials.
- **Making buckets/objects public by accident.** The classic breach cause. Default to private; grant access via bucket policy / presigned URLs, never blanket public read.
- **Assuming eventual consistency and coding around it.** On S3 that workaround is obsolete since Dec 2020 (strong read-after-write); adding retry/backoff for stale reads is now needless complexity.
- **Hot-key throughput assumptions.** Aggregate throughput is huge, but treat a single object as one endpoint — don't design a system that hammers one key for coordination; use a database or queue for that.

## Implementation Notes

Reference mechanisms (recognize and name these; don't memorize APIs):

- **Multipart upload** — split a large object into parts (S3: 5 MB–5 GB each, last part any size), upload in parallel with retry/resume, then a "complete" call assembles them (max object size 5 TB via multipart). Use for anything over ~100 MB.
- **Presigned URLs** — the server signs a time-limited URL granting a specific client a single `GET` or `PUT` directly against the store, so the app never proxies the bytes. Ideal for browser upload/download.
- **Lifecycle policies** — rules that transition objects to colder/cheaper tiers or expire them after N days (e.g. Standard -> Infrequent Access -> Glacier -> delete).
- **Versioning + object lock** — keep prior versions on overwrite/delete; object lock (WORM) enforces retention for compliance/backups.
- **CDN in front** — point a CDN (CloudFront) at the bucket as origin for static assets/media; the bucket is the durable system of record, the CDN is the cache.
- **Storage classes** — Standard (hot), Infrequent Access, Glacier/Deep Archive (cold, minutes–hours retrieval). Match class to access frequency.

## Resources

- Amazon S3 FAQs (durability, object size, consistency): https://aws.amazon.com/s3/faqs/
- S3 strong read-after-write consistency announcement (Dec 2020): https://aws.amazon.com/about-aws/whats-new/2020/12/amazon-s3-now-delivers-strong-read-after-write-consistency-automatically-for-all-applications
- S3 multipart upload limits: https://docs.aws.amazon.com/AmazonS3/latest/userguide/qfacts.html
- Uploading with multipart upload: https://docs.aws.amazon.com/AmazonS3/latest/userguide/mpuoverview.html

## Related

- [[cdn]]
- [[caching]]
- [[database-indexing]]
- [[sql-vs-nosql]]
- [[sharding]]
