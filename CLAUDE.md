# CLAUDE.md

## Documentation Sources

This project vendors reference documentation under `docs/sources/`. Each vendored SDK has a matching hand-built `*-reference.md` navigation map (module tree + "I want to..." lookup table) — **start with the reference map**, not the raw source, so you don't have to re-explore each repo every time.

| SDK | Source clone | Reference map |
|---|---|---|
| Google Agent Development Kit (Python) | `docs/sources/adk-python` ([google/adk-python](https://github.com/google/adk-python)) | `docs/sources/adk-python-reference.md` |
| OpenAI Agents SDK (Python) | `docs/sources/openai-agents-python` ([openai/openai-agents-python](https://github.com/openai/openai-agents-python)) | `docs/sources/openai-agents-python-reference.md` |
| Claude Agent SDK (Python) | `docs/sources/claude-agent-sdk-python` ([anthropics/claude-agent-sdk-python](https://github.com/anthropics/claude-agent-sdk-python)) | `docs/sources/claude-agent-sdk-python-reference.md` |

**Whenever we are planning or implementing anything related to agentic architecture (multi-agent systems, tool use, orchestration, agent design patterns, etc.), treat these three vendored SDKs as the source of truth** — not generic or assumed patterns. Workflow:

1. Check the relevant `*-reference.md` map(s) above to locate the module/file that covers the concept.
2. Read the actual source and/or narrative guide there before proposing designs or writing code.
3. If more than one SDK is relevant (e.g. comparing approaches, or the project isn't yet committed to one), consult all applicable maps rather than defaulting to just one.
4. If a reference map seems stale or missing something, verify against the real source and update the map.

## Architecture Decisions

This project's own architecture design (not the vendored SDKs' docs) lives under `docs/architecture/`:

- `docs/architecture/multi-sdk-agentic-architecture.md` — the core decision: Google ADK as orchestrator, Claude Agent SDK and OpenAI Agents SDK as specialist workers, glued by MCP.
- `docs/architecture/scaling-and-operations.md` — deployment, failure handling, and multi-tenancy for that design at scale.
- `docs/architecture/v1/` — the full, detailed, research-grounded v1 architecture (agents/orchestration, tools/MCP, harness/sandboxing, evaluation/feedback, memory/storage, caching, queueing, observability/audit/cost/rate-limiting, deployment, security/multi-tenancy, and a phased build roadmap). **Start with `docs/architecture/v1/README.md`.**
- `docs/architecture/v1/guidelines/` — the methodology for *how* to build/test/evolve the above: evolutionary-architecture principles (fitness functions, when to abstract), staged build order, plugin/extensibility contracts + ADRs, testing/experimentation strategy, progressive rollout, and a process for adopting new agent frameworks/models without churn or lock-in. **Start with `docs/architecture/v1/guidelines/README.md`.**
- `docs/architecture/v1/13-future-facing-ui-builder-readiness.md` — a future no-code/UI agent-builder is explicitly out of v1 scope, but this doc specifies the five cheap-now/expensive-later commitments (config-driven agents, UI-shaped Registry metadata, first-class templates, author-blind permission enforcement, owner-scoped configs) that keep that future additive instead of a rewrite. **Apply these even to agents built by hand today** — treat every config as if a non-technical UI user authored it, not just your own.
- `docs/architecture/v1/legal-rag/` — an applied deep-dive: a research-grounded architecture for a high-accuracy, high-stakes legal-document RAG chatbot, evaluated against a real, already-planned system. Headline finding: even top commercial legal AI products hallucinate on 17–33% of queries despite already using citations — "has citations" is not evidence of safety. **Start with `docs/architecture/v1/legal-rag/README.md`.**

**Before proposing or changing anything about this project's own agentic architecture (not just "how does SDK X work"), read the relevant `docs/architecture/` doc(s) first** — these encode decisions already made (and why), including findings from external research (Anthropic, MCP spec, OpenTelemetry, IETF) that should not be re-derived or contradicted without a clear reason. If a proposal conflicts with a decision in these docs, surface the conflict explicitly rather than silently overriding it.

## Use Cases

Real business context this project's architecture is being designed for/against lives under `docs/usecase/`. This is separate from `docs/architecture/` — these docs capture **what a real business problem is**, extracted from client source material and external research, not what we've decided to build.

- `docs/usecase/assessments/` — four existing, manually-triggered legal/compliance document review products (Plan Document Assessment, Targeted Stop Loss Review, Stop Loss Gap Review, ASA Review) for self-funded employee health plans, plus real-client-sample-validated external research on each. **Start with `docs/usecase/assessments/README.md`.**
- `docs/usecase/pdi/` — the same company's next-generation "Plan Document Intelligence" platform: an always-on intelligence engine plus a concise, upsell-oriented report card, superseding the one-off assessments above. **Start with `docs/usecase/pdi/README.md`.**

**Confidentiality convention already established across `docs/usecase/`:** raw client documents and any vendor/company name tied to the source material are never committed (see each use-case folder's own data-handling notes) — only the extracted business requirements and our own analysis are tracked. Follow this same convention for any new use-case material added later.
