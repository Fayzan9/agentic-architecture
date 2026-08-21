# Scaling & Operations — Deep Dive

**Status:** Proposed design
**Builds on:** `docs/architecture/multi-sdk-agentic-architecture.md` (read that first — this document resolves its open questions and extends the design for scale: many agents, many MCP servers, production operations)

This document exists because "lots of agents or MCPs" changes the design problem. At small scale, an orchestrator calling two or three hand-wired MCP tools is fine. At large scale — many worker agents, many MCP servers, possibly added by different people over time — you need: a way to *find* what's available, a way to *survive* a worker failing, a way to *isolate* tenants, and a way to *not blow the budget*. Each is addressed below, grounded in what the vendored SDKs actually provide (`docs/sources/*-reference.md`).

---

## 1. Discovery: a Registry, not hand-wired tool lists

### The problem at scale
The base design (`multi-sdk-agentic-architecture.md`) assumes the orchestrator knows about its workers at build time. That breaks down past a handful of MCP servers — you don't want to hardcode connection params for 30 tools into the orchestrator's source code, and you don't want every new worker to require an orchestrator code change/redeploy.

### The decision: a Registry layer between the orchestrator and workers

Google ADK already has this exact pattern natively — `integrations/agent_registry/`, `integrations/api_registry/`, and `skills/skill_registry.py` (see `docs/sources/adk-python-reference.md`). They implement: a client that queries a registry service for available agents/APIs/skills, resolves each to connection parameters (`SseConnectionParams` / `StdioConnectionParams` / `StreamableHTTPConnectionParams`) and an auth scheme, and wraps the result as an `McpToolset` the orchestrator can call. Adopt the same shape even if you don't use GCP's specific registry service:

```
Orchestrator (ADK)
      │  "what workers/tools exist, and how do I reach them?"
      ▼
 Registry (your own service, or GCP Agent/API Registry if already on GCP)
      │  returns: {name, description, connection params, auth scheme, version}
      ▼
 McpToolset per registered entry  →  actual MCP server (worker)
```

**What the registry entry needs, at minimum, per worker:**

| Field | Purpose |
|---|---|
| `name` / `id` | Stable identifier the orchestrator routes to |
| `description` | What the orchestrator's LLM reads to decide *when* to route here — write this carefully, it's effectively a prompt |
| `connection params` | Where/how to reach it (stdio for local/in-process, SSE/HTTP for remote) |
| `auth scheme` | How to authenticate to it (see §4) |
| `version` | Which version of this worker's tool contract this entry represents (see §2) |
| `owner` | Who to page when it breaks |

**Why this matters at your scale:** new workers get *registered*, not *wired into orchestrator code*. The orchestrator's set of callable tools becomes a runtime lookup, not a compile-time list — this is what lets "lots of agents/MCPs" stay manageable instead of becoming an ever-growing if/else in the orchestrator.

**Build vs. borrow:** if you're not on GCP, don't try to reuse ADK's GCP-specific registry client — reimplement the same *shape* (a lookup service returning connection params + auth + version) against whatever service discovery you already run (Consul, a simple database-backed registry, even a config file for a first version). The value is the pattern, not the specific Google service.

## 2. Versioning: tool contracts will change out from under you

### The problem at scale
With one or two hand-built workers, you'd notice immediately if a tool's input schema changed. With many workers — possibly touched by different people — a worker's MCP tool signature can drift, and the orchestrator (or its cached understanding of the tool) breaks silently, sometimes only for some tenants/requests.

### The decision
- **Version the registry entry, not just the worker's code.** Bump the registry's `version` field on any breaking change to a worker's tool schema (new required param, changed return shape, removed tool). Non-breaking additions (new optional param, new tool alongside old ones) don't require a version bump.
- **The orchestrator pins a version range it was tested against**, not "latest." Treat this like a dependency version constraint — the orchestrator's config declares which worker versions it's compatible with; the registry lookup fails closed (loud error, not silent misroute) if only an incompatible version is available.
- **Deprecate, don't delete.** When a worker's tool contract changes, keep the old version resolvable in the registry for a defined window while the orchestrator side migrates, rather than a hard cutover.
- **Test the contract, not just the behavior.** Each worker should have a schema-conformance test (Claude Agent SDK ships exactly this pattern for session stores: `testing/session_store_conformance.py` — apply the same idea to MCP tool schemas) that runs in CI before a worker's new version is registered.

## 3. Failure handling: assume workers fail, design for partial failure

### The problem at scale
With many workers, *something* is failing at any given moment — that's a statistical certainty at scale, not an edge case. The system needs a policy, not ad hoc handling per call site.

### The decision — a layered policy

**a. Per-call timeout + retry, at the tool-call boundary.**
Every MCP tool call from the orchestrator gets a timeout and a bounded retry count. ADK already has the primitive for this: `plugins/reflect_retry_tool_plugin.py` — it intercepts tool failures, feeds structured failure info back to the LLM for reflection/correction, and retries up to a configurable limit, tracked per-tool via a `ScopedFailureTracker`. Use this plugin (or its pattern, if not on ADK) as the default at the orchestrator level rather than writing bespoke try/except around each worker call.

**b. Circuit breaking per worker, not just per call.**
A single slow/failing worker shouldn't be retried into the ground on every request while also blocking the orchestrator's turn budget. Track consecutive-failure count *per worker* (not just per call); once a worker crosses a threshold, stop routing to it for a cooldown window and either (i) fail that subtask fast with a clear message, or (ii) fall back to an alternate worker if one exists for that capability (see §3d).

**c. Failure must be visible to the model, not just logged.**
The reflect-and-retry pattern's real insight: a tool failure becomes a structured response the LLM sees (error type, details, retry count, "reflection guidance"), so the orchestrator's own reasoning can decide to retry differently, skip the subtask, or ask the user — instead of the failure being invisible until someone reads logs. Carry this principle into any custom failure handling you add outside ADK's plugin too.

**d. Fallback workers are an explicit design choice, not a default.**
Only invest in a fallback path (e.g., a second worker that can also handle "run this shell command") where the cost of *not* completing the subtask is high. For most specialist roles (voice, deep coding tasks) there won't be a real fallback — the honest failure mode is "surface to the user that this subtask couldn't complete," not silently degrading to a worse worker.

**e. Timeout budgets compound — plan for it.**
If the orchestrator calls Worker A which internally calls Worker B, the user-facing timeout is the sum, not the max. With many chained agents this adds up fast. Set an overall per-request deadline at the orchestrator's entry point and have it decrement/propagate down, rather than giving every layer its own independent generous timeout.

## 4. Multi-tenancy: threading tenant identity through everything

*(This resolves the multi-tenancy open question directly — see the earlier conversation where we distinguished "isolating tenants" from "using multiple SDKs together"; this section is about the former, now that the latter is designed.)*

### The problem at scale
Once there are many workers and many MCP servers, tenant isolation has to be enforced at *every hop*, or a single missed hop leaks data/cost/access across tenants. This is the part that's easy to get right for hop #1 and easy to forget by hop #4.

### The decision — tenant ID as a first-class piece of context, not an afterthought

**a. Tenant ID enters at the orchestrator's entry point and is never re-derived downstream.** It comes from the authenticated request (not from user-supplied text/state, which could be tampered with), and is attached to ADK's `InvocationContext`/`ReadonlyContext` for the whole run.

**b. Session state is namespaced by tenant, using ADK's existing scoping.** ADK already has `app:`/`user:`/`session:`/`temp:` state prefixes (`sessions/state.py`). Tenant becomes another layer of that scoping — e.g., session store keys/partitions include tenant ID, so `database_session_service.py`/`sqlite_session_service.py`/etc. are configured to partition by tenant (separate DB schema, separate keyspace, or a tenant-ID column enforced at the query layer — pick one and enforce it in one place, not per call site).

**c. Every MCP call to a worker carries tenant ID explicitly**, as part of the tool-call context, not implied by "whichever session happens to be active." This is what prevents a bug in the orchestrator's routing logic from silently handing Tenant A's data to a worker instance mixed up with Tenant B's session.

**d. Credentials are per-tenant, resolved at call time, never cached across tenants.** ADK's `auth/credential_manager.py` + `credential_service/` is the natural place for this: worker-facing credentials (e.g., a tenant's own BigQuery access, or their OAuth-connected tools) resolve through the credential manager keyed by tenant, not baked into a worker's static config. A worker process should not be able to reuse Tenant A's resolved credential for a Tenant B request.

**e. Sandboxes/artifacts are per-tenant, not shared.** If a worker does code execution or file artifacts (Claude Agent SDK's Bash/file tools, ADK's `code_executors/`, OpenAI's `sandbox/`), the working directory/container/artifact store must be tenant-scoped — a shared temp directory across tenants is a data-leak bug waiting to happen, and needs to be caught in review, not left as a "todo."

**f. Registry lookups (§1) can themselves be tenant-scoped.** Not every tenant necessarily has access to every registered worker (e.g., an enterprise-only worker, or a tenant-specific integration). The registry lookup should filter by what the requesting tenant is entitled to, so an unauthorized worker isn't even a routable option — this is a stronger guarantee than relying on the orchestrator's prompt to "just not" route somewhere it shouldn't.

### What this document does NOT decide
Whether tenants are isolated at the **process level** (one orchestrator+worker fleet per tenant — simplest to reason about, most resource-expensive) or the **request level** (shared fleet, tenant ID threaded through every call, as described above — more efficient, more discipline required) is a capacity/cost decision, not an architecture decision, and depends on tenant count and compliance requirements you haven't specified yet. Default recommendation for a "really big" project: **request-level isolation with the discipline above**, because process-per-tenant stops scaling once tenant count gets large — but flag this explicitly for a decision once you know your tenant count and any compliance constraints (e.g., a tenant contractually requiring dedicated infrastructure would force process-level isolation for that tenant specifically).

## 5. Deployment model for workers

### The decision
**Each worker is its own deployable unit, running as its own MCP server process**, independent of the orchestrator's deployment lifecycle — not in-process function calls bundled into the orchestrator's codebase. Reasons, given the scale implied:

- **Independent scaling.** A voice/realtime worker (OpenAI Agents SDK) and a coding worker (Claude Agent SDK) have completely different load shapes and resource needs (the coding worker may need more CPU/memory for sandboxed execution; the realtime worker needs low-latency network placement). Independent processes let you scale each independently.
- **Independent failure domains.** A crash or memory leak in one worker's process shouldn't take down the orchestrator or unrelated workers — this directly supports the circuit-breaking design in §3b, which assumes a worker *can* be down while the rest of the system stays up.
- **Independent release cadence.** With "lots of agents," different workers will be iterated on by different people at different speeds. Coupling them to one deploy would force lockstep releases, which won't hold up as the number of workers grows.
- **Connection type follows locality.** Use stdio-based MCP connections only for a worker genuinely co-located in the same process/host as its caller (rare at this scale); use SSE/streamable-HTTP MCP connections (as ADK's registry client already models via `SseConnectionParams`/`StreamableHTTPConnectionParams`) for the normal case of a worker running as its own network-reachable service.

### What to standardize across all workers, regardless of SDK
So that "lots of agents/MCPs" doesn't become "lots of bespoke deployment snowflakes":
- One way to health-check a worker (so the registry/circuit-breaker in §1/§3 can tell if it's up before routing).
- One logging/tracing correlation ID format, propagated from the orchestrator's trace (§6) into every worker regardless of which SDK it's built on.
- One way to express a worker's resource limits (timeout, max concurrency) in its registry entry, so the orchestrator's per-call timeout (§3e) has a real number to use instead of a guess.

## 6. Observability at scale

Building on the base document's "ADK telemetry as top-level trace collector": at this scale, a single request may fan out across several workers, so **trace propagation matters more than trace collection**. Concretely:
- Every MCP tool call is a span; the span carries the tenant ID (§4) and worker version (§2) as attributes, so a failure or latency spike can be filtered by tenant or by the exact worker version that caused it. ADK's own tracing already tags MCP calls with a destination-id attribute for this purpose (`telemetry/tracing.py`, `GCP_MCP_SERVER_DESTINATION_ID`) — mirror that pattern for non-GCP workers.
- Don't rely on each SDK's own local tracing (OpenAI Agents SDK's tracing module, etc.) as the system of record — those are useful for a developer debugging one worker in isolation, but the orchestrator's trace is what lets you answer "why did this specific user's request fail," which is the question that actually comes up in production.

## 7. Cost & quota control

Not covered in the base document at all, and it becomes unavoidable once "lots of agents" means many LLM calls fanning out per request:
- **Budget at the orchestrator level, per request.** OpenAI Agents SDK already demonstrates the primitive (`examples/max_budget_usd.py`) — apply the same idea at the orchestrator: a per-request cost ceiling that, once hit, stops spawning further worker calls and returns partial results rather than an unbounded fan-out.
- **Per-tenant quotas**, enforced at the same layer as per-tenant credential resolution (§4d) — otherwise one tenant's runaway usage degrades the shared fleet for everyone.
- **Track cost per worker, not just per request**, so you can see which specialist agent is actually expensive before it's a surprise bill — this is a natural extension of the per-call span in §6 (attach cost as a span attribute).

## 8. Summary of decisions in this document

| Question from the base doc | Resolution |
|---|---|
| Deployment model for workers | Independent deployable units (own MCP server process), not in-process; standardize health-check, tracing correlation, and resource-limit expression across all of them |
| Failure handling | Per-call timeout+retry (ADK's reflect-and-retry plugin pattern) + per-worker circuit breaking + failures surfaced to the model, not just logs + explicit (not default) fallback workers + propagated timeout budgets |
| Multi-tenancy | Tenant ID as first-class context from the entry point onward; namespaced session state, per-call tenant context, per-tenant credentials, per-tenant sandboxes, tenant-filtered registry lookups; request-level isolation recommended by default, process-level flagged as a cost/compliance decision |
| *(new)* Discovery at scale | A Registry layer (ADK's agent/API/skill registry pattern) so workers are looked up at runtime, not hardcoded |
| *(new)* Versioning | Version the registry entry; orchestrator pins compatible version ranges; deprecate-not-delete; schema-conformance tests in CI |
| *(new)* Cost/quota | Per-request budget ceiling; per-tenant quotas; per-worker cost tracking |

## 9. Still open — needs your input, not more research

- **Tenant count and compliance requirements** — needed to actually decide request-level vs. process-level isolation (§4), rather than defaulting.
- **Which capabilities genuinely need a fallback worker** (§3d) — this is a product/risk decision (what's the cost of a subtask failing outright?), not something derivable from the SDKs.
- **Where the registry service itself lives** — a new small service you build, or an existing service-discovery/config system already in use elsewhere in your infrastructure.
