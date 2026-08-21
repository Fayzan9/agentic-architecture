# Guidelines

**How to build, test, and evolve this system** — as distinct from `docs/architecture/v1/`, which describes **what** the system is. Where the v1 architecture docs specify subsystems (agents, tools, memory, observability...), this guidelines set specifies the *methodology* applied every time any of those subsystems is built, changed, or replaced — including by technology that doesn't exist yet.

**Read `01-guiding-philosophy.md` first.** It states the core tension this whole set resolves — staying adaptable to a fast-moving field without either over-committing to today's stack or over-abstracting against a guessed-at future — and every other doc here is a concrete application of it.

## Document index

| # | Doc | One-line summary |
|---|---|---|
| 01 | [Guiding Philosophy](01-guiding-philosophy.md) | Evolutionary architecture (fitness functions, last-responsible-moment), ports-and-adapters as this project's mental model, the Rule of Three for when to abstract, the capability-registry pattern for models |
| 02 | [Build Order & Methodology](02-build-order-and-methodology.md) | The reusable loop for building anything new here: walking skeleton → eval harness before capability → Sierra's Development/Release/QA/Testing cycle → treat spikes as disposable |
| 03 | [Extensibility & Plugin Contracts](03-extensibility-and-plugin-contracts.md) | The microkernel/plugin pattern already implicit in this project's Registry; Architecture Decision Records as the memory mechanism; a layered build-vs-buy framework |
| 04 | [Testing & Experimentation Strategy](04-testing-and-experimentation-strategy.md) | The 4-layer testing pyramid for agents (deterministic → replay → eval → red-team/canary), lightweight experiment tracking, numeric stage-gate criteria, a documented anti-pattern checklist |
| 05 | [Progressive Rollout & Change Management](05-progressive-rollout-and-change-management.md) | Prompts/models/configs as versioned, flagged artifacts; canary→A/B→100% with eval gates at every stage, not just at ship; rollback as a one-step flag flip |
| 06 | [Staying Current Without Churn](06-staying-current-without-churn.md) | The scheduled triage process for new frameworks/models: act only when a fitness function actually fails, never on novelty or one person's enthusiasm alone |

## The single idea underneath all six documents

Every document here converges on the same test, applied at a different point in the system's life:

> **Change is justified by a measured, real need — a failing fitness function, a second real instance of a pattern, a genuine gap the current stack can't cover — never by novelty, hype, or speculation about a future that hasn't arrived yet.**

This is what keeps the system flexible *and* keeps it from becoming a moving target that never stabilizes enough to actually ship. The Registry, MCP, and capability-registry patterns already specified in `docs/architecture/` and `docs/architecture/v1/` are what make honoring that test *cheap* — most new things can be tried as a plugin, measured against the eval suite, and adopted or discarded without touching the system's core.
