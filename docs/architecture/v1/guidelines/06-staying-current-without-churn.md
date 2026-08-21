# Guidelines — Staying Current Without Churn

**Status:** v1 guidelines — pre-implementation
**Reads with:** `01-guiding-philosophy.md` (fitness functions, last-responsible-moment, Rule of Three — this doc turns those into an operating process), `03-extensibility-and-plugin-contracts.md` §4 (the mechanics of onboarding something new)

## 1. The problem this doc solves, precisely

The user's original concern, restated: agent frameworks, models, and protocols are evolving fast, and this project must not end up "in a deep hole" — locked into today's specific choices in a way that makes adopting something genuinely better later expensive or impossible. But the opposite failure — chasing every new framework/model release, rewriting working systems to adopt whatever is newest — is just as damaging, and arguably more common in this specific field given how much hype surrounds new releases. This document is the concrete **process** for deciding when something new is worth adopting, so that decision is never made by either pure inertia or pure hype.

## 2. The standing question to ask before adopting anything new

Every piece of this document set converges on one test. Before adopting a new agent framework, model, protocol, or tool:

> **Does an existing fitness function (`01-guiding-philosophy.md` §2) show the current choice actually failing, or is this adoption driven by novelty alone?**

If a fitness function is failing (a worker's eval scores are stagnant while a competing model's aren't; a framework's plugin contract is straining to support a real, current need), that's the "last responsible moment" signal to act. If no fitness function is failing and the motivation is "this is new and looks better," that's a signal to log interest (see §4) without committing engineering time yet — this is the direct, practical application of the Rule of Three (`01-guiding-philosophy.md` §4): a hypothetical future benefit is not yet a real, counted need.

## 3. A lightweight, scheduled review process — not ad hoc, not constant

Given the pace of this field, "wait until something obviously breaks" is too passive, and "evaluate every announcement" is too expensive. The middle path:

- **A scheduled review cadence** (e.g., quarterly, adjustable to this project's actual pace of change) where new frameworks/models/protocols that emerged since the last review are triaged against the build-vs-buy layer table (`03-extensibility-and-plugin-contracts.md` §3) and the fitness functions (`01-guiding-philosophy.md` §2) — not evaluated in isolation from what's already working.
- **Triage outcomes, explicitly one of three, every time:**
  1. **No action** — noted, no fitness function is failing, revisit at the next cycle.
  2. **Spike** — worth a time-boxed, disposable prototype (`02-build-order-and-methodology.md` §4) to gather real evidence, without committing to adoption.
  3. **Adopt** — a fitness function is genuinely failing and this candidate addresses it; proceed through the onboarding process in `03-extensibility-and-plugin-contracts.md` §4.
- **One champion's enthusiasm is not sufficient for outcome 3.** A single team member being excited about a new framework is a valid reason to trigger outcome 2 (a spike) — it is not, on its own, a reason to rewrite a working system. This is worth stating explicitly because it's the single most common way fast-moving fields end up with churn-driven rewrites that weren't actually justified by a failing fitness function.

## 4. A running log, not a decision each time from scratch

Maintain a simple, low-overhead log (a markdown file or lightweight tracker, not a heavy tool — consistent with the "don't over-tool early" guidance in `04-testing-and-experimentation-strategy.md` §2) of:

- New frameworks/models/protocols noted at each review cycle, with a one-line note on why they were or weren't actioned.
- Any "no action" item that keeps recurring across multiple review cycles — a repeated signal across cycles is itself evidence worth weighing more heavily than a single cycle's assessment, since it suggests sustained rather than momentary relevance.

This log is the practical companion to the ADR practice (`03-extensibility-and-plugin-contracts.md` §2) — ADRs record decisions that were made; this log records the ones that were deliberately *not* made yet, and why, so that reasoning isn't lost either.

## 5. What makes this project specifically well-positioned to do this without much pain

This is worth stating plainly, because it's the payoff for everything specified elsewhere in this document set — the design choices already made are what make "staying current" cheap rather than expensive:

- **The Registry/microkernel plugin contract** (`03-extensibility-and-plugin-contracts.md` §1) means a new worker framework can be prototyped as a new registered plugin without touching the orchestrator, which is most of the cost of "trying something new" in a less disciplined architecture.
- **MCP as the integration protocol** (`v1/03-tools-and-mcp.md`) means a new tool or even a new worker SDK, as long as it can be fronted by an MCP server, slots into the existing contract without inventing a new integration mechanism each time.
- **The capability registry pattern for models** (`01-guiding-philosophy.md` §5) means a new model provider is a data addition (capability declarations + eval scores), not a code change to routing logic.
- **The eval suite** (`v1/05-evaluation-and-feedback-loops.md`) is what turns "does this new thing actually help" from a subjective impression into a measured, comparable answer — which is precisely what makes the triage process in §3 possible to run quickly and honestly rather than devolving into opinion.

The intent of this whole guidelines set is that adopting something genuinely better later should be **cheap because of how this system is built now**, not despite it — and that cheapness is what avoids both failure modes named in `01-guiding-philosophy.md` §1 at once: this project doesn't need to guess right about the future, because the cost of being wrong about any one component is kept low by construction.

## Sources

This document synthesizes the practices already sourced in `01-guiding-philosophy.md`, `02-build-order-and-methodology.md`, and `03-extensibility-and-plugin-contracts.md` into an operating process — see those documents' Sources sections for the underlying external research (evolutionary architecture, Rule of Three, ADRs, build-vs-buy). No new external claims are introduced in this document beyond that synthesis.
