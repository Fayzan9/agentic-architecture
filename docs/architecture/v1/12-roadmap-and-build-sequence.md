# v1 — Roadmap & Build Sequence

**Status:** v1 design — pre-implementation
**Reads with:** everything. This doc exists to enforce Principle #1 (`01-overview-and-principles.md`): this document set describes the full shape of a scalable system, but building all of it before shipping anything would itself violate the principle it's built on. This is the deliberate answer to "in what order do we actually build this."

## Why sequencing matters more than completeness here

Every doc in this set describes a real, evidence-backed capability. None of them are wrong to eventually have. But Anthropic's own guidance — "consider adding complexity only when it demonstrably improves outcomes" — means the right v1 build is a thin vertical slice through every layer, proven end-to-end, before any single layer is built out to the full depth described in this doc set.

## Phase 0 — Prove the core loop, single worker, no scale concerns yet

**Goal:** one request, through the orchestrator, to exactly one worker, and back — with the minimum viable version of the "one choke point" (`09` §5).

- Orchestrator (ADK) + **one** worker (pick the higher-value one first — likely the Claude Agent SDK coding worker, since that's the harder/more differentiated capability) connected via MCP over stdio (acceptable at this phase per `03-tools-and-mcp.md` §1 — "genuinely co-located" is true when there's only one worker and no deployment independence need yet).
- Hand-wired tool list — **no Registry yet** (`scaling-and-operations.md` §1's discovery problem doesn't exist until there's more than a couple of workers).
- Session state in ADK's in-memory session service — no tenant namespacing yet if this is genuinely single-tenant at this phase.
- Basic tracing (OTel spans per `09` §1) from day one — this is cheap to add early and expensive to retrofit, unlike most of the rest of this list.
- **Explicit exit criterion:** the core orchestrator→worker→response loop works reliably for the primary use case, with real tracing to show it.

## Phase 1 — Add the second worker and the failure-handling basics

**Goal:** prove the multi-worker routing decision (`02-agents-and-orchestration.md`) actually holds up, and that failure doesn't cascade.

- Add the OpenAI Agents SDK worker (voice/realtime, or whichever second capability is actually needed next).
- Move workers to independent deployment (`10-deployment-and-infrastructure.md` §1) — now justified, since there are two workers with plausibly different scaling needs.
- Add per-call timeout + retry (ADK's `reflect_retry_tool_plugin`, `scaling-and-operations.md` §3a) and basic per-worker circuit breaking (§3b) — this is the point where "a worker can be down without taking the system down" starts to matter, because there's now more than one thing that can be down.
- Move to real MCP transport (HTTP/SSE) now that workers are independently deployed (`03-tools-and-mcp.md` §1).
- **Explicit exit criterion:** killing one worker doesn't take down requests routed to the other; a worker timeout produces a visible, actionable failure rather than a hang.

## Phase 2 — Registry, versioning, and the eval regression gate

**Goal:** stop hand-wiring workers into orchestrator code, and stop shipping prompt/config changes without a safety net.

- Build the Registry (`scaling-and-operations.md` §1, `03-tools-and-mcp.md` §4) — justified now because adding a third worker via code change is exactly the pain point the Registry solves, and by this phase there should be a real third capability need or a clear plan for one.
- Enforce the `<worker>_<verb>_<noun>` naming convention and the ~25,000 token output cap (`03-tools-and-mcp.md` §2) at registration time.
- Build the eval regression gate (`05-evaluation-and-feedback-loops.md` §5) — start from real production error analysis (§2 of that doc), not imagined cases, since by this phase there should be real traffic/traces to learn from.
- Wire the regression gate into CI as a blocking check (`10-deployment-and-infrastructure.md` §6).
- **Explicit exit criterion:** a new worker can be added via registry entry, not orchestrator code change; a prompt/config change is blocked from deploying if it regresses the eval suite.

## Phase 3 — Observability, cost, and audit as one shared choke point

**Goal:** build the single call path described in `09-observability-audit-cost-and-ratelimiting.md` §5, rather than four separate bolt-ons.

- Consolidate tracing, rate limiting, cost budget checks, and audit-record emission into one call path inside the orchestrator's harness.
- Stand up the independent audit writer (`09` §3) as its own service, separate from tracing infrastructure, **if any compliance requirement is confirmed to be in scope** — otherwise, a simpler append-only audit log (without the full hash-chain/signature apparatus) is an acceptable interim step, upgraded later if compliance needs it (flag this as a real scope decision to make explicitly, not silently skip).
- Add the two-layer budget enforcement (`09` §2): proxy-level hard cap + in-loop kill switch.
- **Explicit exit criterion:** every request produces one coherent trace showing cost, tool calls, and an audit record, queryable by tenant/worker/version.

## Phase 4 — Caching, async execution, and sandboxing hardening

**Goal:** the performance/cost/isolation layer, once there's enough real traffic and enough coding-worker usage to justify it.

- Prompt caching (`07-caching.md` §2) — cheap to add, do this as soon as the coding/orchestrator prompts are stable enough that the invalidation-cascade rule (tool list changes must be deterministic) is being respected.
- Async task queue (Celery+Redis, `08-queueing-and-async-execution.md` §3) for long-running coding tasks — justified once coding tasks are actually long enough to need it, not before.
- Checkpointing/snapshot-restore for the coding worker's sandbox (`04-agent-harness-and-sandboxing.md` §3, `08` §2) — justified once multi-turn coding sessions against the same working directory are common enough that the re-init cost is measurably hurting latency/cost.
- Upgrade the coding worker's sandbox to microVM tier if it started at a lighter tier during Phase 0–1 for speed of initial build — **this specific upgrade should not be deferred indefinitely** once the coding worker executes any real (non-toy) generated code, per the hard requirement in `04-agent-harness-and-sandboxing.md` §3.
- Semantic caching (`07` §3) — only if a specific, deliberately-chosen use case justifies its documented risk profile; not a default addition.

## Phase 5 — Multi-tenancy and the still-open decisions

**Goal:** only once there's a real second tenant, or a concrete near-term plan for one.

- Thread tenant ID through every layer per the checklist in `11-security-and-multi-tenancy.md` §3 — this is disruptive to retrofit, so do it as soon as multi-tenancy is confirmed to be needed, not after a large amount of single-tenant-assuming code has accumulated.
- Resolve the request-level vs. process-level isolation decision (`11` §5) using real tenant-count and compliance input by this point.
- Add per-tenant Registry filtering, per-tenant quotas, and per-tenant credential scoping together, as one piece of work — they share the same tenant-context plumbing.

## What this sequencing deliberately defers, and why that's fine

- **Kafka/event-streaming** (`08-queueing-and-async-execution.md` §3) — explicitly deferred indefinitely unless a concrete high-throughput multi-consumer streaming need emerges; Celery+Redis is sufficient for everything in this roadmap.
- **A dedicated vector database** (`06-memory-state-and-storage.md` §5) — start with Postgres+pgvector; revisit only against measured query volume/latency data.
- **Shadow/canary rollout infrastructure** (`05-evaluation-and-feedback-loops.md` §4) — valuable, but sequenced after the basic regression gate (Phase 2) is solid; shadow/canary catches what the offline eval suite misses, so it's most valuable once there's a decent offline suite to complement.
- **Judge calibration harness** (`05` §5) — sequenced alongside Phase 2's regression gate, but can start simple (a rubric judge without formal periodic calibration) and add calibration once there's enough judge-vs-human labeled data to calibrate against.

## One-line summary per phase

| Phase | One-line goal |
|---|---|
| 0 | Prove the loop: one orchestrator, one worker, real tracing |
| 1 | Prove multi-worker routing and basic failure isolation |
| 2 | Registry replaces hand-wiring; eval regression gate blocks bad deploys |
| 3 | One shared choke point for tracing, cost, rate-limiting, audit |
| 4 | Caching, async execution, and sandbox hardening for real load |
| 5 | Multi-tenancy, once a real second tenant justifies it |
