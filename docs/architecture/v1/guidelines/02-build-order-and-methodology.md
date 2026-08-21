# Guidelines — Build Order & Methodology

**Status:** v1 guidelines — pre-implementation
**Reads with:** `docs/architecture/v1/12-roadmap-and-build-sequence.md` (that doc is the specific phase plan for *this* system's v1 build; this doc is the *reusable methodology* to apply every time — initial build, a new worker, a new capability — not a one-time plan)

## 1. Start with a walking skeleton, not a real capability

Sources: [Jade Rubick — Steel Threads](https://www.rubick.com/steel-threads/), [Equal Experts MLOps Playbook — Walking Skeleton](https://playbooks.equalexperts.com/mlops-playbook/practices/create-a-walking-skeleton-steel-thread).

A walking skeleton (steel thread) is a minimal but fully functional end-to-end path that proves the wiring works before any real capability exists behind it. For ML/AI specifically, the documented pattern is to deploy a **trivial/stubbed version first** — even one that returns a constant response — behind a feature flag, so the integration and data flow across the whole system is validated before the real intelligence is built.

**Applied to this project, every time a new piece is added (not just at initial build):**

- **First build of the system:** the full path — request → orchestrator → one worker (stubbed to return a fixed response) → back to the user, with tracing already wired (`v1/09-observability-audit-cost-and-ratelimiting.md` §1) — is proven *before* the worker does anything real. This matches `v1/12-roadmap-and-build-sequence.md` Phase 0's exit criterion, restated here as the general practice, not a one-off.
- **Every new worker added later:** the same discipline applies — register it in the Registry with a stub implementation, prove the orchestrator can route to it and handle its (stub) failure, *then* build its real capability behind that already-proven skeleton. This is cheaper insurance against integration bugs than building the real capability first and discovering wiring problems only once it's "done."

## 2. Eval-driven development — the harness comes before the capability, not after

Sources: [Hamel Husain — Evals FAQ](https://hamel.dev/blog/posts/evals-faq/), [Eval-Driven Development pattern](https://ramparte.github.io/agent-building-playbook/patterns/eval-driven-development.html), [DZone — Shipping Production-Grade AI Agents](https://dzone.com/refcardz/shipping-production-grade-ai-agents).

The concrete, recommended order — inverting the naive instinct to build first and figure out testing later:

1. **Observability first.** "You cannot evaluate what you cannot observe." Tracing (`v1/09` §1) goes in with the walking skeleton (§1 above), not after the capability is built.
2. **Error analysis before writing evals.** Manually review real (or, for a brand-new capability with no traffic yet, deliberately simulated) traces to find actual failure patterns. Do not write evals from imagined edge cases dreamed up in a design session — this is the same conclusion `v1/05-evaluation-and-feedback-loops.md` §2 already reached, restated here as the *order of operations* to follow every time, not just at initial build.
3. **Define success criteria, build the eval harness, then implement the capability.** The stated principle: "if you cannot write the eval, you haven't yet defined what the capability should accomplish" — the eval spec becomes the actual functional spec. **"The eval harness should be the first artifact, not the last"** — its ready-date should precede the prototype-freeze date, not follow it.
4. **The eval stack has three co-evolving parts**, not one frozen suite: *what* you evaluate (the agent/capability), *how* you grade (deterministic checks / LLM-as-judge / human review), and *what grounds it* (the dataset). These three should evolve together through the same error-analysis loop (step 2), not be built once and left static.

## 3. A production case study, adopted as this project's own release/QA loop shape

Source: [Sierra — Agent Development Life Cycle](https://sierra.ai/blog/agent-development-life-cycle), [Sierra — Shipping and Scaling AI Agents](https://sierra.ai/blog/shipping-and-scaling-ai-agents).

Sierra's four-stage cycle for production conversational agents, adopted here as this project's own methodology because it's a documented real system, not a theoretical framework:

| Stage | What happens | This project's equivalent |
|---|---|---|
| **Development** | Declarative goals + deterministic guardrails at moments that matter; creativity/flexibility elsewhere, strict enforcement at critical business-logic points | The harness's permission tiers (`v1/04-agent-harness-and-sandboxing.md` Component 5) are exactly the deterministic-guardrail mechanism — this stage is where a new capability's guardrail points get identified, not left to prompt instructions alone |
| **Release** | **Immutable, versioned snapshots** of source + prompts + model + knowledge together, enabling instant rollback and A/B testing | Maps directly onto the Registry's versioning (`scaling-and-operations.md` §2) — extend it to cover prompts and model choice together as one versioned unit per worker, not separately |
| **QA** | **Daily human review** of real conversations by subject-matter experts — generates both improvement signal and regression test data | Feeds the feedback capture pipeline (`v1/05-evaluation-and-feedback-loops.md` §3) — the "daily" cadence is the concrete, adoptable detail: human review should be a standing operational rhythm, not an occasional audit |
| **Testing** | Annotated real conversations become regression tests run against **mocked APIs** — prevents "prompt engineering whack-a-mole" where a fix to one case breaks a previously-fixed one | This is the regression gate (`v1/05` §5, `v1/10-deployment-and-infrastructure.md` §6) — the mocked-API detail matters: regression tests must not depend on live external systems being in a particular state |

**Sierra's own stated regrets — adopted here as things to build earlier than instinct suggests:**

- They wished they'd run a **structured stakeholder-alignment design workshop before building**, not after a prototype existed — for this project, that means the design docs already written (`v1/`, `guidelines/`) should be reviewed with whoever the eventual stakeholders are (even if that's just this project's own team) before the first real capability is built, not retrofitted as documentation after the fact.
- They built their **observability/human-review platform too late** relative to when they actually needed it — direct reinforcement of §1/§2 above: build it with the walking skeleton, not after the first real capability ships.
- They found that **starting with the simplest possible use case (basic Q&A) was the wrong instinct** — the hardest, highest-value journeys delivered the most value, but only once the guardrail/QA/testing scaffolding existed to support that complexity safely. **Applied here:** don't pick the easiest possible first worker capability just because it's easy — pick the one that's actually valuable, and make sure the scaffolding (§1–§3) is in place to support it safely, rather than avoiding complexity by picking a toy first task.

## 4. The prototype-to-production trap — treat spike code as disposable

Sources: [Towards AI — The Agent Prototype Trap](https://pub.towardsai.net/the-agent-prototype-trap-15-things-that-break-when-you-hit-production-ad597c197999), [MLflow — Building Production-Ready AI Agents](https://mlflow.org/articles/building-production-ready-ai-agents-in-2026/).

A well-documented failure pattern: agents that work perfectly in a notebook/demo "collapse when external APIs error out," burn through API budget in the first production days, and are brittle specifically because monolithic prototype designs are "deceptively easy to prototype but brittle in production."

**The concrete transition rule this project adopts:** the point at which prototype/spike code is allowed to become real production code is **when eval infrastructure and observability exist for it** (§1–§2), not when the demo "looks done" or "feels ready." A demo that works in a notebook against a hand-picked example is not evidence of readiness — passing the eval harness (built per §2, before the capability, not after) is.

**Practical consequence:** when exploring a new idea (a new worker capability, a new routing strategy, a new tool), it is fine and expected to write fast, disposable, notebook-style code with no tracing/eval/guardrails — but that code must be treated as explicitly throwaway. The production version is a fresh build against the walking-skeleton + eval-harness discipline above, informed by what the spike learned, not the spike code hardened in place.

## 5. Summary — the reusable loop, for any new piece of this system

```
1. Walking skeleton: wire the new piece end-to-end with a stub, tracing on from day one
2. Error analysis: observe real/simulated traffic through the stub, find real failure shapes
3. Eval harness: define success criteria and build the eval BEFORE building real capability
4. Build the real capability against that harness
5. Release as an immutable, versioned unit (code + prompt + model + config together)
6. Daily human review of real usage feeds the regression suite (not just occasional audits)
7. Every future change to this piece is gated by the regression suite built in step 3/6
```

This loop is what `v1/12-roadmap-and-build-sequence.md`'s phases apply once, at the level of the whole system's v1 build. This document says: apply the same loop every time something new is added after that, not just once.

## Sources

- [Jade Rubick — Steel Threads](https://www.rubick.com/steel-threads/) · [Equal Experts — Walking Skeleton](https://playbooks.equalexperts.com/mlops-playbook/practices/create-a-walking-skeleton-steel-thread)
- [Hamel Husain — Evals FAQ](https://hamel.dev/blog/posts/evals-faq/) · [Eval-Driven Development](https://ramparte.github.io/agent-building-playbook/patterns/eval-driven-development.html) · [DZone — Shipping Production-Grade AI Agents](https://dzone.com/refcardz/shipping-production-grade-ai-agents)
- [Sierra — Agent Development Life Cycle](https://sierra.ai/blog/agent-development-life-cycle) · [Sierra — Shipping and Scaling AI Agents](https://sierra.ai/blog/shipping-and-scaling-ai-agents)
- [Towards AI — The Agent Prototype Trap](https://pub.towardsai.net/the-agent-prototype-trap-15-things-that-break-when-you-hit-production-ad597c197999) · [MLflow — Building Production-Ready AI Agents](https://mlflow.org/articles/building-production-ready-ai-agents-in-2026/)
