# v1 — Memory, State & Storage

**Status:** v1 design — pre-implementation
**Reads with:** `docs/architecture/multi-sdk-agentic-architecture.md` §4 (state ownership decision), `07-caching.md`, `scaling-and-operations.md` §4b (tenant-namespaced state)

## 1. Three-tier memory model

Sources: [Redis — AI agent memory: stateful systems](https://redis.io/blog/ai-agent-memory-stateful-systems/), [Analytics Vidhya — Memory Systems in AI Agents](https://www.analyticsvidhya.com/blog/2026/04/memory-systems-in-ai-agents/), [Atlan — Agentic AI Memory vs Vector Database](https://atlan.com/know/agentic-ai-memory-vs-vector-database/).

The convergent pattern across sources is a **three-tier model**, not one storage engine trying to serve every access pattern:

| Tier | Contents | Latency need | Typical storage |
|---|---|---|---|
| **Hot** | Full in-context conversation state for the active request/session | Zero-latency, held in the active turn | In-memory / fast KV (Redis) |
| **Warm** | Structured facts/preferences extracted **asynchronously** from conversations — the actual source of truth for recall across sessions | Fast, queryable, but not turn-blocking | Vector store and/or document store |
| **Cold** | Compressed/archived old session logs | Rarely read, cost-optimized | Cheap object/blob storage |

**Mapped onto this project's existing components:** ADK's session service (`sessions/base_session_service.py` + a backend) is the **hot** tier. ADK's memory service (`memory/base_memory_service.py`, `vertex_ai_memory_bank_service.py`) or an equivalent for a non-GCP deployment is the **warm** tier. Cold storage is new — an explicit archival policy for session data past a retention window, feeding into the audit-trail retention requirements (`09-observability-audit-cost-and-ratelimiting.md` §3).

**Why three tiers, not one database:** collapsing hot and warm into one store either makes the hot path slow (querying a large warm store on every turn) or makes the warm store noisy with raw turn-by-turn data it doesn't need. Keep the tiers physically separate, connected by an explicit, asynchronous promotion path (hot → warm), not a shared table.

## 2. Vector stores are not a correctness guarantee — required design consequence

A specific, important caveat from research: **vector databases are stateless with respect to correctness.** They don't know a stored fact was later superseded or contradicted — they just return nearest neighbors by embedding similarity. Retrieval quality also degrades as the corpus grows: more vectors does not mean better recall, it can mean more noise competing for the same top-k slots.

**Required design consequence for this project's warm-tier memory:** the promotion path from hot to warm must include **explicit invalidation/superseding logic**, not just "embed and insert." When a new fact contradicts a previously stored one (e.g., a user's stated preference changes), the warm-tier write path must mark the old entry superseded (a `superseded_by`/`valid_until` field, or an explicit delete), not rely on retrieval-time similarity to "naturally" prefer the newer one — similarity search has no notion of recency or contradiction on its own.

## 3. Three distinct memory *types*, not one blob

Beyond the hot/warm/cold latency-driven split, sources also distinguish memory by **kind**, which should map to different storage engines rather than one undifferentiated store:

- **Episodic/session state** — what happened in this conversation/session (ADK's session service).
- **Semantic/knowledge state** — extracted facts/preferences about a user or tenant, recalled across sessions (ADK's memory service, warm tier).
- **Working/task state** — the current in-progress task's intermediate state (e.g., a multi-step coding task's partial progress) — this is closer to the harness's own loop state (`04-agent-harness-and-sandboxing.md` Component 3) than to either session or long-term memory, and shouldn't be conflated with either. For a long-running or checkpointable task, this is what gets persisted/resumed via the queueing/checkpointing design (`08-queueing-and-async-execution.md`).

## 4. State scoping — tenant is a first-class dimension, not bolted on

Carried forward and made explicit here: ADK's existing `app:`/`user:`/`session:`/`temp:` state prefixes (`sessions/state.py`) need a **tenant** dimension added as another scoping layer, per `scaling-and-operations.md` §4b — every session store backend (database, SQLite, Vertex AI, or a custom one) must partition by tenant ID at the storage layer (separate schema, separate keyspace, or an enforced tenant-ID column checked at the query layer — pick one mechanism and enforce it centrally, not per call site, exactly as already specified in the scaling doc).

## 5. Database technology choices — decision table

| Need | Recommended default | Why |
|---|---|---|
| Hot session state | Redis (or ADK's in-memory/SQLite session backend for early-stage/dev) | Matches the "zero-latency, active-turn" requirement; Redis is also the queueing-layer default (`08`), so it's already in the stack |
| Warm structured memory | A vector store (choice deferred — Vertex AI-native if staying on GCP via ADK's built-in service, otherwise an open option like pgvector/Postgres to avoid adding a whole new database technology just for this) | Needs similarity search; pairing with Postgres via pgvector avoids introducing a dedicated vector-DB service before scale actually demands one — revisit if query volume/latency requires a dedicated engine |
| Cold archival | Object storage (GCS/S3-equivalent) | Cheapest at rest, rarely read, matches audit-retention needs (`09` §3) |
| Audit trail (see `09`) | A separate, append-only, tenant-partitioned store — deliberately **not** the same store as session state | Required by the hash-chained, tamper-evident design in `09` §3 — mixing it with mutable session state would undermine that property |

**Explicit non-decision, flagged for later:** the exact warm-tier vector store product (pgvector vs. a dedicated vector DB vs. Vertex AI Memory Bank if staying GCP-native) is left open pending real query volume/latency data — per principle #1 (`01-overview-and-principles.md`), don't provision a dedicated vector database before there's a measured need past what Postgres+pgvector can serve.

## Sources

- [Redis — AI agent memory: stateful systems](https://redis.io/blog/ai-agent-memory-stateful-systems/)
- [Analytics Vidhya — Memory Systems in AI Agents](https://www.analyticsvidhya.com/blog/2026/04/memory-systems-in-ai-agents/)
- [Atlan — Agentic AI Memory vs Vector Database](https://atlan.com/know/agentic-ai-memory-vs-vector-database/)
