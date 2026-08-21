# v1 — Overview & Principles

**Status:** v1 design — pre-implementation
**Supersedes/extends:** `docs/architecture/multi-sdk-agentic-architecture.md`, `docs/architecture/scaling-and-operations.md` (those documents' decisions carry forward; this v1 set fills them out with full subsystem detail and grounds them in external research, not just the vendored SDKs)
**Vendored SDK grounding:** `docs/sources/adk-python-reference.md`, `docs/sources/openai-agents-python-reference.md`, `docs/sources/claude-agent-sdk-python-reference.md`, `docs/sources/adk-comparison.md`

## How to read this v1 set

| Doc | Covers |
|---|---|
| `01-overview-and-principles.md` (this doc) | High-level architecture, guiding principles, layered system diagram |
| `02-agents-and-orchestration.md` | Agent design patterns, orchestrator-workers, when multi-agent helps vs. hurts |
| `03-tools-and-mcp.md` | MCP protocol architecture, tool design standards, MCP-specific security |
| `04-agent-harness-and-sandboxing.md` | The runtime scaffolding around each agent: loop, execution, sandboxing, permissions |
| `05-evaluation-and-feedback-loops.md` | Offline eval, LLM-as-judge, human feedback capture, drift monitoring |
| `06-memory-state-and-storage.md` | Session/conversation state, long-term memory, database choices |
| `07-caching.md` | Prompt caching and semantic caching, with failure modes |
| `08-queueing-and-async-execution.md` | Sync vs. async execution, durable task queues, checkpointing |
| `09-observability-audit-cost-and-ratelimiting.md` | Tracing, audit trail, cost tracking, rate limiting |
| `10-deployment-and-infrastructure.md` | How workers/orchestrator actually get deployed and scaled |
| `11-security-and-multi-tenancy.md` | Cross-cutting security posture and tenant isolation, tying every doc together |
| `12-roadmap-and-build-sequence.md` | What to build first, and in what order, to reach v1 without over-building |

Each doc is self-contained enough to read alone, but they share one system model — described below — and cross-reference each other rather than repeating content.

## Guiding principle #1: complexity must be earned, not assumed

The single most important finding from external research (Anthropic, "Building Effective Agents") is a warning, not a pattern:

> "Consider adding complexity only when it demonstrably improves outcomes... the most successful implementations use simple, composable patterns rather than complex frameworks."

This directly shapes how this v1 set should be *used*, not just what it describes: **this document set describes the full shape of a scalable system so you know what exists and why — it is not a mandate to build all of it before shipping anything.** `12-roadmap-and-build-sequence.md` makes this explicit with a phased build order. If you take one thing from this overview, take this: every subsystem below should be justified by an actual task/scale need you're hitting, not built because "a scalable architecture has one."

This principle also governs the internal shape of the agent system itself, not just the surrounding infra: Anthropic's own production data shows their multi-agent research system used **~15x the tokens** of a single chat interaction, and token usage alone explained 80% of performance variance across their eval. Multi-agent orchestration is a real capability with a real cost — see `02-agents-and-orchestration.md` for exactly when it earns that cost and when it doesn't (their own follow-up guidance found multi-agent decomposition *actively counterproductive* for coding tasks specifically, which is directly relevant to this project's Claude-worker role).

## Guiding principle #2: isolation is the default, not an add-on

Every subsystem in this design defaults to isolated-by-construction rather than shared-by-default-with-checks-added-later:
- MCP servers isolate workers from each other's full context by protocol design, not just convention (`03-tools-and-mcp.md`).
- The agent harness treats the sandbox as the actual trust boundary where an agent touches real systems (`04-agent-harness-and-sandboxing.md`).
- Tenant identity is threaded through every layer from the entry point, never re-derived (`11-security-and-multi-tenancy.md`).
- The audit trail is written by a component independent of the agent process itself, so the agent cannot tamper with the record of its own actions (`09-observability-audit-cost-and-ratelimiting.md`).

## Guiding principle #3: every subsystem needs an owner concept and a failure mode, not just a happy path

Each doc in this set follows the same internal discipline: describe the happy path, then describe **what happens when it fails** (a worker times out, a cache goes stale, a queue backs up, a budget is exceeded) — because at the scale this project targets ("lots of agents or MCPs"), failure is a constant background condition, not an edge case (see `docs/architecture/scaling-and-operations.md` §3, carried forward here).

## System model — the layers

```
┌──────────────────────────────────────────────────────────────────────────┐
│  ENTRY LAYER                                                             │
│  Authenticated request → tenant ID extracted → correlation ID assigned  │
└───────────────────────────────┬──────────────────────────────────────────┘
                                 │
┌───────────────────────────────▼──────────────────────────────────────────┐
│  ORCHESTRATION LAYER  (Google ADK)                                       │
│  - Agent/workflow logic (02) · Session & state ownership (06)           │
│  - Registry-based worker discovery (scaling-and-operations §1)          │
│  - Per-request cost budget + rate-limit enforcement (09)                │
└───────────────────────────────┬──────────────────────────────────────────┘
                                 │  MCP (03)
        ┌────────────────────────┼────────────────────────┐
        ▼                        ▼                        ▼
┌───────────────┐      ┌───────────────────┐    ┌────────────────────┐
│ WORKER: Claude │      │ WORKER: OpenAI     │    │ WORKER: future...  │
│ Agent SDK      │      │ Agents SDK         │    │                     │
│ (coding/file/  │      │ (voice/realtime/   │    │ same harness shape  │
│  shell)        │      │  hosted tools)     │    │                     │
│                │      │                     │    │                     │
│ HARNESS (04):  │      │ HARNESS (04):       │    │ HARNESS (04):        │
│  loop, sandbox,│      │  loop, sandbox,     │    │  loop, sandbox,      │
│  permissions   │      │  permissions        │    │  permissions         │
└───────────────┘      └───────────────────┘    └────────────────────┘
        │                        │                        │
        └────────────────────────┼────────────────────────┘
                                 ▼
┌──────────────────────────────────────────────────────────────────────────┐
│  CROSS-CUTTING LAYERS (apply to every box above, not bolted on after)   │
│  Caching (07) · Queueing/async (08) · Observability/Audit/Cost/         │
│  RateLimit (09) · Deployment/Infra (10) · Security/Multi-tenancy (11)   │
│  Evaluation & Feedback (05) — runs both offline (pre-deploy gate) and   │
│  online (production drift monitoring)                                   │
└──────────────────────────────────────────────────────────────────────────┘
```

## What this system explicitly is not (v1 scope boundary)

To keep this v1 grounded rather than open-ended:
- **Not** a general-purpose agent-building platform for third parties — it's this project's own system, so the "registry" and "harness" concepts are internal infrastructure, not a public product surface (though modeled on public prior art like the official MCP Registry — see `03-tools-and-mcp.md`).
- **Not** committing to fine-tuning or training infrastructure — the feedback loop in `05-evaluation-and-feedback-loops.md` closes into prompt/config/eval-set improvements, not a training pipeline, unless a later decision changes that.
- **Not** deciding request-level vs. process-level tenant isolation here — that remains an explicit open decision needing tenant-count/compliance input, carried forward from `scaling-and-operations.md` §4 and restated in `11-security-and-multi-tenancy.md`.

## Sources referenced across this v1 set

- Anthropic — ["Building Effective Agents"](https://www.anthropic.com/research/building-effective-agents), ["How we built our multi-agent research system"](https://www.engineering.fyi/article/how-we-built-our-multi-agent-research-system), ["When to use multi-agent systems, and when not to"](https://www.claude.com/blog/building-multi-agent-systems-when-and-how-to-use-them), ["Writing Effective Tools for AI Agents"](https://www.anthropic.com/engineering/writing-tools-for-agents), [prompt caching docs](https://platform.claude.com/docs/en/docs/build-with-claude/prompt-caching)
- Model Context Protocol — [official architecture spec](https://modelcontextprotocol.io/docs/2026-07-28/learn/architecture), [security best practices](https://modelcontextprotocol.io/specification/2025-06-18/architecture), [official MCP Registry](https://registry.modelcontextprotocol.io/)
- Agent harness concept — [Endor Labs](https://www.endorlabs.com/learn/what-is-an-agent-harness-the-software-that-turns-a-model-into-an-agent), [boringbot.substack](https://boringbot.substack.com/p/ai-agent-harnesses-explained-architecture)
- Evaluation — [Hamel Husain's Evals FAQ](https://hamel.dev/blog/posts/evals-faq/), [OpenAI agent-eval guide](https://developers.openai.com/api/docs/guides/agent-evals), [langchain-ai/agentevals](https://github.com/langchain-ai/agentevals)
- Observability/cost/audit — [OpenTelemetry GenAI conventions](https://opentelemetry.io/blog/2026/genai-observability/), [Braintrust cost-tracking playbook](https://www.braintrust.dev/articles/how-to-track-llm-costs-2026), [IETF draft-sharif-agent-audit-trail-00](https://datatracker.ietf.org/doc/draft-sharif-agent-audit-trail/)
- Infra — [Redis on AI agent memory](https://redis.io/blog/ai-agent-memory-stateful-systems/), [Northflank on sandboxing AI agents](https://northflank.com/blog/how-to-sandbox-ai-agents), [Portkey on semantic caching](https://portkey.ai/blog/semantic-caching-thresholds/)

Every claim attributed to a source in the docs that follow traces back to this research pass — treat unsourced claims in this v1 set as this project's own design decisions, not external fact.
