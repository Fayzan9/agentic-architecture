# Architecture v1

Detailed, research-grounded design for a scalable multi-SDK agentic system, built on top of the earlier decisions in `docs/architecture/multi-sdk-agentic-architecture.md` and `docs/architecture/scaling-and-operations.md`. Every non-obvious claim in this set is traced to an external, credible source (Anthropic, OpenAI, the MCP spec, OpenTelemetry, IETF, and reputable engineering writing) — see each doc's "Sources" section.

**Start here:** [`01-overview-and-principles.md`](01-overview-and-principles.md) — the layered system diagram and the two principles (earn complexity, isolate by default) that every other doc applies.

**Then, if you're deciding what to build first:** [`12-roadmap-and-build-sequence.md`](12-roadmap-and-build-sequence.md) — this whole set describes the full target shape, but the roadmap is the actual build order. Read it early so the detail in the other docs doesn't read as "build all of this now."

## Document index

| # | Doc | One-line summary |
|---|---|---|
| 01 | [Overview & Principles](01-overview-and-principles.md) | System diagram, guiding principles, scope boundary |
| 02 | [Agents & Orchestration](02-agents-and-orchestration.md) | Workflow vs. autonomous-agent patterns; when multi-agent helps vs. backfires (coding-specific finding) |
| 03 | [Tools & MCP](03-tools-and-mcp.md) | MCP protocol architecture, tool design rules, MCP-specific security (confused deputy, token passthrough) |
| 04 | [Agent Harness & Sandboxing](04-agent-harness-and-sandboxing.md) | The five required harness components; sandbox isolation tiers per worker type |
| 05 | [Evaluation & Feedback Loops](05-evaluation-and-feedback-loops.md) | Trajectory eval, LLM-as-judge pitfalls/mitigations, feedback capture pipeline, drift monitoring |
| 06 | [Memory, State & Storage](06-memory-state-and-storage.md) | Hot/warm/cold memory tiers, vector-store caveats, database choices |
| 07 | [Caching](07-caching.md) | Prompt caching mechanics vs. semantic caching risks |
| 08 | [Queueing & Async Execution](08-queueing-and-async-execution.md) | Sync vs. async, checkpointing, queue technology choice |
| 09 | [Observability, Audit, Cost & Rate Limiting](09-observability-audit-cost-and-ratelimiting.md) | OTel tracing shape, IETF audit-trail schema, two-layer cost budgets, rate-limit gateway |
| 10 | [Deployment & Infrastructure](10-deployment-and-infrastructure.md) | Per-worker deployment shape, autoscaling signal, CI/CD gate placement |
| 11 | [Security & Multi-Tenancy](11-security-and-multi-tenancy.md) | Cross-cutting synthesis — tenant isolation checklist across every other doc |
| 12 | [Roadmap & Build Sequence](12-roadmap-and-build-sequence.md) | Phased build order — what to build first, and what to deliberately defer |
| 13 | [Future-Facing: UI Builder Readiness](13-future-facing-ui-builder-readiness.md) | What must be true *now* (config-driven agents, UI-shaped Registry metadata, first-class templates, author-blind permission enforcement, owner-scoped configs) so a future no-code agent-builder UI is additive, not a rewrite — without building any UI yet |

## Guidelines — how to build this, not just what to build

This README covers **what** the system is. A separate, equally detailed document set covers **how** to build/test/evolve it — methodology for staying adaptable as agent frameworks and models keep changing, without over-abstracting against a guessed-at future: **[`guidelines/`](guidelines/README.md)**. Read it alongside this set, not after — it directly shapes how `02` (agents/orchestration) and `12` (roadmap) should actually be executed.

## Key findings worth knowing before reading further

- **Multi-agent decomposition specifically backfires for coding tasks** (Anthropic's own production finding) — this refines the existing orchestrator→Claude-worker design: hand off whole coherent coding tasks, don't decompose them across multiple calls. See `02` §2.
- **Token passthrough between MCP servers is explicitly forbidden** by the protocol's own security guidance, and containers alone are explicitly insufficient for executing untrusted/LLM-generated code — both are hard requirements, not hardening suggestions. See `03` §3, `04` §3.
- **An audit trail is not the same as a log** — it must capture *why* a decision was made, be hash-chained for tamper-evidence, and be written by a component the agent itself cannot control. See `09` §3.
- **LLM-as-judge has documented, reproducible biases** (position, verbosity, self-enhancement) — mitigated by rubric-based, criteria-constrained scoring, not open-ended quality ratings. See `05` §2.
- **Semantic caching can return a confidently wrong answer with no signal it degraded** — restrict it to deliberately chosen, low-stakes use cases; never use it for anything that writes, executes code, or spends money. See `07` §3.
