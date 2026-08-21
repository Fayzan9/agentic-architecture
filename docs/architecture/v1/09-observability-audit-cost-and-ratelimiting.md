# v1 — Observability, Audit Trail, Cost Tracking & Rate Limiting

**Status:** v1 design — pre-implementation
**Reads with:** `scaling-and-operations.md` §6 (observability at scale, carried forward and made concrete here), `03-tools-and-mcp.md` §3 (security findings that inform audit fields)

This is the densest doc in the v1 set because these four concerns share one substrate: every MCP tool call and every model call the system makes. Get the tracing shape right once, and audit, cost, and rate-limiting all attach to it rather than needing separate instrumentation paths.

## 1. Tracing — OpenTelemetry GenAI semantic conventions

Source: [OpenTelemetry GenAI observability blog](https://opentelemetry.io/blog/2026/genai-observability/), [Greptime — OTel GenAI + MCP](https://greptime.com/blogs/2026-05-09-opentelemetry-genai-semantic-conventions), [John Hodge — state of OTel GenAI conventions](https://john-hodge.com/blog/opentelemetry-genai-semantic-conventions/).

**Status caveat, important:** as of the research pass for this document, `gen_ai.*` conventions are still in **Development status** — no attribute is marked Stable. The conventions were also recently spun out of the main semantic-conventions repo into their own (`open-telemetry/semantic-conventions-genai`), with a version bump that **dropped old attribute names**. **Required practice:** pin a specific convention version and isolate all `gen_ai.*` attribute strings behind a single internal mapping layer in this project's tracing code — never hardcode them inline at every call site — so a future convention version bump is a one-file change, not a grep-and-replace across the codebase.

**Trace structure to adopt:**

```
invoke_agent (top-level span, one per orchestrator request)
 ├── chat (one per LLM call — orchestrator's own model calls)
 ├── execute_tool (one per MCP tool call to a worker)
 │     └── [worker's own internal spans, if the worker propagates trace context]
 ├── execute_tool (another worker call)
 └── chat (a follow-up orchestrator model call)
```

**Core attributes (per the convention):** `gen_ai.request.model`, `gen_ai.usage.input_tokens`, `gen_ai.usage.output_tokens`, `gen_ai.response.finish_reasons`, and — only when content-recording is explicitly enabled, given the sensitivity — `gen_ai.input.messages` / `gen_ai.output.messages` / `gen_ai.system_instructions`.

**Extensions specific to this project, added as custom attributes on `execute_tool` spans (the convention has no official MCP-specific or agent-to-agent guidance yet, so this project extends rather than violates it):**

- `tenant_id` — every span, for the per-tenant filtering required by multi-tenancy (`11-security-and-multi-tenancy.md`).
- `worker_version` — the Registry version (`scaling-and-operations.md` §2) of the worker handling this call, so a failure/latency spike can be filtered to the exact version that caused it.
- `mcp_server_destination` — which registered worker/MCP server this call went to (mirroring ADK's own existing practice of tagging MCP destination IDs on tracing spans, per `docs/sources/adk-python-reference.md`'s telemetry module).

## 2. Cost tracking

Source: [Braintrust — How to track LLM costs (2026)](https://www.braintrust.dev/articles/how-to-track-llm-costs-2026).

### Tag every model call at creation time

Every model call should be tagged, at the moment it's made (not reconstructed later from logs), with: `user_id`, `customer_id`/`tenant_id`, `feature`, `deployment`, `prompt_version`, and `agent_run_id` (a single ID grouping every call within one multi-step agent execution, spanning the orchestrator and every worker it delegated to). This turns cost/quality investigation into a metadata query, not log-parsing after the fact.

### Track cache-related token fields separately

Per `07-caching.md` §5: `prompt_tokens`, `completion_tokens`, `prompt_cached_tokens`, `prompt_cache_creation_tokens` must be distinct fields, not folded together — cache reads are ~90% cheaper and cache writes carry a premium, and conflating them misrepresents where cost actually comes from.

### Budget enforcement — two distinct mechanisms, at two distinct layers, plus a third non-blocking layer

This is the single most actionable, concrete finding from research on this topic, and directly extends `scaling-and-operations.md` §7's brief mention of per-request budgets:

| Layer | Mechanism | Why it must be here and not elsewhere |
|---|---|---|
| **Proxy/middleware, before the request reaches the model** | Hard cap, checked against a fast counter (Redis, to avoid a DB hit per request) | "Blocking at the LLM call is too late — input tokens are already billed" by the time a post-hoc check could catch it. This is the layer that prevents a request from starting when the tenant/user is already over budget. |
| **Inside the agent's own loop (the harness, per `04-agent-harness-and-sandboxing.md` Component 1)** | A kill switch monitoring token count, tool-call count, retry count, and span depth **mid-run** | A runaway loop must be stopped while it is still executing — the proxy layer doesn't see the agent's internal loop state, so it cannot catch a single request that spirals into an unbounded number of internal tool calls after already being admitted. This is exactly the explicit-stopping-condition requirement from `04` Component 1, now given a concrete enforcement mechanism. |
| **Soft alerts** | Post-request, diagnostic only, non-blocking | Surfaces spend anomalies for review without interrupting a request — this is the layer for "notify someone," not "stop something." |

**Required cost rollups, in priority order (per Braintrust's recommendation):** per-user-per-day, per-feature-request, **per-agent-run** (specifically compare p50 vs. p99 — a fat tail here is the signature of loop/runaway behavior, not just natural variance), per-successful-eval (quality-adjusted — a cheap-but-wrong run is not actually cheap), per-customer/tenant.

## 3. Audit trail — a dedicated, tamper-evident subsystem

Source: [IETF draft-sharif-agent-audit-trail-00](https://datatracker.ietf.org/doc/draft-sharif-agent-audit-trail/), [Collibra — AI audit trails: what to log and how](https://www.collibra.com/blog/ai-audit-trails-what-to-log-for-models-and-agents-and-how-a-command-center-captures-it).

**This is the strongest, most concrete finding from the entire research pass** — an active IETF draft explicitly mapped to EU AI Act, SOC 2, ISO/IEC 42001, and PCI DSS v4.0.1 logging requirements, with a ready-to-adopt JSON record schema:

### Required fields (mandatory per the draft)

| Field | Purpose |
|---|---|
| `record_id` | UUIDv4, unique per audit record |
| `timestamp` | RFC 3339 |
| `agent_id` / `agent_version` | Which worker/orchestrator version performed the action — ties directly to Registry versioning (`scaling-and-operations.md` §2) |
| `session_id` | Correlates to the session/tenant context (`06-memory-state-and-storage.md` §4) |
| `action_type` | Controlled vocabulary: `tool_call` / `decision` / `delegation` / `escalation` / `error` |
| `action_detail` | Type-specific subfields — see below |
| `outcome` | `success` / `failure` / `timeout` / `denied` / `escalated` |
| `trust_level` | L0–L4 — maps naturally onto this project's permission tiers (`04-agent-harness-and-sandboxing.md` Component 5) |
| `record_phase` | `pre` / `post` / `concurrent` execution |
| `parent_record_id` | Links a record to the action that caused it — builds the causal chain of an agent run |
| `prev_hash` | SHA-256, hash-chained to the previous record — **tamper-evidence**, not just append-only logging |

### Recommended fields

`signature` (ECDSA P-256, for non-repudiation), `risk_score` (0.0–1.0), `model_id`, `input_hash`/`output_hash` (hash rather than store raw content — privacy-preserving by construction), `deny_reasons`, `recording_component` (identifies which system component wrote this record).

### `action_detail` subfields, mapped directly onto this project's own action types

- **`tool_call`** → `tool_name`, `parameters_hash`, `tool_server`, `authorization` — this is exactly the shape of every orchestrator→worker MCP call.
- **`decision`** → `decision_type`, `confidence`, `reasoning_hash`, `policy_ref` — the orchestrator's routing decisions (`02-agents-and-orchestration.md` §3) are exactly this.
- **`delegation`** → `delegate_agent_id`, `task_description_hash`, `constraints` — maps directly onto the orchestrator handing a task to a worker.

### The requirement that changes this project's architecture, not just its logging code

> An audit trail differs from a log in that it must capture *why* a decision was made — the reasoning/policy trail — not just *that* an event occurred.

And: the `recording_component` field exists specifically to support **an independent audit writer, separate from the agent process itself, so the agent cannot tamper with the record of its own actions.**

**Required consequence for this project's architecture:** the audit subsystem must be its **own service with its own write path**, not a side effect of tracing spans (§1) even though the two overlap heavily in content. Concretely: every `execute_tool` span (§1) and every orchestrator routing `decision` should emit a corresponding audit record via a path the agent/worker process does not control the final write to (e.g., the audit writer runs as a separate process/service that receives events, computes the hash chain, and is the only writer to the audit store) — this is a meaningfully stronger bar than "send everything to the observability vendor," and is required if any compliance regime (EU AI Act, SOC 2, healthcare-adjacent, financial) is in scope for this project, flagged explicitly since it isn't yet confirmed which regimes apply.

**Storage note (ties to `06-memory-state-and-storage.md` §5):** the audit store is deliberately separate from session state — a mutable session store cannot host a hash-chained, tamper-evident log without undermining the tamper-evidence property.

## 4. Rate limiting

Sources: [Maxim — Managing LLM Traffic: Rate Limits](https://www.getmaxim.ai/articles/managing-llm-traffic-understanding-and-applying-rate-limits/), [TrueFoundry — LLM Failover & Load Balancing](https://www.truefoundry.com/blog/llm-failover-load-balancing-provider-outages).

### Provider-facing rate limits (outbound, this system calling model providers)

- Standard approach: **exponential backoff with jitter**, honoring the provider's own rate-limit headers (`Retry-After`, `x-ratelimit-*`) rather than guessing a retry interval. Naive immediate retry on a 429 causes thundering-herd amplification of the exact overload condition being escaped — this is a documented anti-pattern, not a theoretical risk.
- Production pattern: an **AI gateway layer** doing multi-key load balancing and automatic multi-provider failover, so a 429 on one key/provider is absorbed transparently by retrying on a different key or provider — "the calling application does not have to know about rate limits at all." Each fallback provider must get **its own full retry budget**, not a shared counter — otherwise a failover inherits the primary's already-exhausted retry budget and fails immediately, defeating the point of failover.
- **Direct implication for this project's multi-provider model usage** (Google ADK's model registry already supports Gemini/Claude/Gemma/LiteLLM per `docs/sources/adk-comparison.md` §7): the gateway/failover layer should sit at the model-call boundary inside the orchestrator's harness, not be reimplemented per worker — one gateway, all workers' model calls route through it.

### Agent-to-tool rate limiting (this project's actual novel surface — MCP calls, not just model API calls)

The documented guidance here is **centralized governance at the tool-connection layer** — specifically to prevent a runaway agent loop from generating uncontrolled tool-call volume/cost. **This is the same boundary as the Registry/circuit-breaker design already specified** (`scaling-and-operations.md` §1, §3b) — the addition from this research is that rate limiting belongs at that exact boundary too, not as a separate system: every MCP call from the orchestrator to a worker should pass through one choke point that enforces (a) the circuit breaker (existing), (b) a per-worker and per-tenant rate limit (new), and (c) the cost budget check (§2) — three checks, one choke point, not three independently-built gates that could drift out of sync with each other.

## 5. Summary — the one choke point this whole document argues for

Every finding in this document points at the same architectural conclusion: **there should be exactly one call path every MCP tool call and every model call passes through**, inside the orchestrator's harness, that in one place: opens the tracing span (§1), checks the rate limit and circuit breaker (§4, `scaling-and-operations.md` §3b), checks the cost budget (§2), executes the call, and emits the audit record (§3) on completion. Building this as four separate bolt-on systems risks exactly the kind of drift (one path instrumented, another forgotten) that defeats the purpose of all four — build it once, as this project's single most important piece of shared infrastructure.

## Sources

- [OpenTelemetry GenAI observability blog](https://opentelemetry.io/blog/2026/genai-observability/) · [Greptime — OTel GenAI + MCP](https://greptime.com/blogs/2026-05-09-opentelemetry-genai-semantic-conventions) · [John Hodge — state of OTel GenAI conventions](https://john-hodge.com/blog/opentelemetry-genai-semantic-conventions/)
- [Braintrust — How to track LLM costs (2026)](https://www.braintrust.dev/articles/how-to-track-llm-costs-2026)
- [Maxim — Managing LLM Traffic: Rate Limits](https://www.getmaxim.ai/articles/managing-llm-traffic-understanding-and-applying-rate-limits/) · [TrueFoundry — LLM Failover & Load Balancing](https://www.truefoundry.com/blog/llm-failover-load-balancing-provider-outages)
- [IETF draft-sharif-agent-audit-trail-00](https://datatracker.ietf.org/doc/draft-sharif-agent-audit-trail/) · [Collibra — AI audit trails](https://www.collibra.com/blog/ai-audit-trails-what-to-log-for-models-and-agents-and-how-a-command-center-captures-it)
