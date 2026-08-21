# v1 — Deployment & Infrastructure

**Status:** v1 design — pre-implementation
**Reads with:** `scaling-and-operations.md` §5 (deployment model decision, carried forward), `04-agent-harness-and-sandboxing.md` §3 (sandbox tiers)

## 1. Deployment unit — confirmed and detailed

`scaling-and-operations.md` §5 already decided: **each worker is its own deployable unit, running as its own MCP server process, independent of the orchestrator's deployment lifecycle.** This document adds the concrete infra pattern that decision implies.

## 2. Autoscaling — scale on concurrency, not CPU

Source: research on LLM/agent workload characteristics (Northflank, Zylos Research infra pieces).

LLM/agent workloads are **I/O-bound** — most of a request's wall-clock time is spent waiting on a model API response or a tool call to a remote service, not consuming CPU. **Direct consequence:** autoscaling this system's orchestrator and workers on CPU utilization (the default for most autoscalers) will systematically under-scale, since CPU stays low even while the service is saturated with in-flight requests waiting on I/O. **Required practice:** scale on **concurrent in-flight requests** (or a proxy metric like open connections / active agent runs) as the primary signal, with CPU/memory as a secondary safety bound only.

## 3. Serverless vs. dedicated — pick per workload shape, not globally

| Workload shape | Recommended | Why |
|---|---|---|
| Bursty, variable load (e.g., orchestrator handling variable user traffic) | Serverless (scale-to-zero) | Cost-efficient for variable load; cold-start cost is the tradeoff (see §4) |
| Sustained, high-throughput (e.g., a heavily-used worker under continuous load) | Dedicated containers | Avoids repeated cold-start cost when load is consistently high enough to keep instances warm anyway |
| Coding worker with sandboxed execution (`04-agent-harness-and-sandboxing.md` §3) | Dedicated, warm-pooled microVM instances | Cold-start cost compounds with sandbox cold-start cost (see §4) — a coding worker is the worst case for naive scale-to-zero |

**This is a per-worker decision, not a system-wide one** — the orchestrator, the voice/realtime worker, and the coding worker plausibly land in different rows of this table, and each worker's Registry entry (`scaling-and-operations.md` §1) should record which deployment shape it uses so operational expectations (cold-start latency, cost profile) are visible without reading its infra config.

## 4. Cold starts — the dominant serverless cost, and how the sandbox design already mitigates it

Cold starts are the main cost of the serverless approach in §3. Two mitigations, both already anticipated elsewhere in this v1 set rather than being new ideas introduced here:

- **Warm replicas** — keep a minimum pool of pre-initialized instances, standard serverless practice.
- **Snapshot-restore** (`04-agent-harness-and-sandboxing.md` §3) — for the coding worker specifically, a Firecracker snapshot resumes in 5–30ms versus ~100–125ms cold boot, and avoids re-initializing a full sandbox (200–500ms) per turn. **This means the coding worker's cold-start problem is really two stacked problems** (service cold start + sandbox cold start) — solving only the service-level one with warm replicas, while still cold-booting a fresh sandbox per request, leaves most of the latency cost on the table. Both layers need warm/snapshot strategies together for this worker specifically.

## 5. Network topology and policy

Per `04-agent-harness-and-sandboxing.md` §3's defense-in-depth requirement: every worker's Registry entry declares a network policy (default-deny egress with an explicit allowlist, or full network access with justification). Infra-level requirement: this policy must be enforced at the network layer (security groups, egress firewall rules, or the sandbox's own network namespace controls), not merely documented — a declared-but-unenforced policy provides no actual protection against the exfiltration risk noted in `04` §3.

## 6. CI/CD — where the eval regression gate actually lives

Connects `05-evaluation-and-feedback-loops.md`'s regression gate to concrete infrastructure: any change to a prompt, agent config, tool schema, or routing logic must run through the eval regression suite (ADK's `evaluation/local_eval_service.py` or equivalent) as a CI step, **blocking merge/deploy on failure** — this is a hard gate, not an advisory check, given the "orchestrator + specialist workers" system's actual product surface is agent behavior (`05` §1), which a normal unit-test suite won't catch regressions in. Shadow/canary rollout (`05` §4) is the deployment-time continuation of this same gate — a change that passes the offline regression suite still goes through gradual traffic ramp with automatic rollback triggers before reaching 100% of traffic.

## 7. Registry and gateway as their own deployed services

Two components specified elsewhere in this v1 set need explicit infra placement, since they're easy to accidentally leave undeployed as "just a library":

- **The Registry** (`scaling-and-operations.md` §1, `03-tools-and-mcp.md` §4) is its own service, independently deployed, with its own availability requirements — if it's down, the orchestrator cannot discover any worker, making it a single point of failure that deserves the same operational rigor (health checks, redundancy) as the orchestrator itself.
- **The model-call gateway** (`09-observability-audit-cost-and-ratelimiting.md` §4, handling provider failover/rate-limiting) is likewise its own deployed layer sitting between the orchestrator/workers and the actual model provider APIs — not logic embedded separately inside each SDK's model-call code, which would defeat the "one choke point" principle from `09` §5.

## 8. Summary — infra inventory for v1

| Component | Deployment shape | Scaling signal | Notes |
|---|---|---|---|
| Orchestrator (ADK) | Dedicated or serverless, depending on traffic pattern | Concurrent in-flight requests | Hosts the "one choke point" call path (`09` §5) |
| Claude Agent SDK worker (coding) | Dedicated, warm-pooled, microVM-sandboxed | Concurrent in-flight requests + sandbox pool depth | Highest isolation tier (`04` §3); needs both service- and sandbox-level warm strategy |
| OpenAI Agents SDK worker (voice/realtime) | Dedicated or serverless | Concurrent in-flight requests / active realtime sessions | Lower isolation tier unless given code-execution tools (`04` §3) |
| Registry service | Dedicated, highly available | Request volume (low — this is a lookup service, not a heavy compute path) | Single point of failure if down — treat availability requirements accordingly |
| Model-call gateway | Dedicated, highly available | Request volume | Hosts provider failover/rate-limiting (`09` §4) |
| Async task queue (Celery/Redis) | Dedicated | Queue depth / worker pool size | Per `08-queueing-and-async-execution.md` §3 |
| Hot-tier store (Redis) | Dedicated, HA | Memory/connection count | Also backs the task queue broker — one Redis deployment serving two purposes is acceptable at v1 scale, split later if contention appears |
| Warm-tier store (Postgres+pgvector or equivalent) | Dedicated, HA | Query volume | Per `06-memory-state-and-storage.md` §5 |
| Audit store | Dedicated, append-only, separate from session state | Write volume | Per `09` §3 — must not share infra with mutable session state |
