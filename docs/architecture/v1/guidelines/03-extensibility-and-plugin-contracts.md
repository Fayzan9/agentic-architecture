# Guidelines — Extensibility & Plugin Contracts

**Status:** v1 guidelines — pre-implementation
**Reads with:** `scaling-and-operations.md` §1 (Registry), `v1/03-tools-and-mcp.md` §4 (MCP Registry prior art), `01-guiding-philosophy.md` §3 (ports-and-adapters)

## 1. The microkernel pattern — the general shape behind every long-lived extensible system

Source: [Plugin Extension Architecture](https://commons-os.github.io/patterns/plugin-extension-architecture/).

The pattern behind systems that stay extensible for years (VS Code, Terraform, Kubernetes CRDs/operators) is the **microkernel architecture**: a minimal core handles only the main loop, basic services, and plugin lifecycle — all actual capability lives in plugins loaded against a stable, explicitly versioned interface. The stated principle: "the core system must expose clear and stable extension points... versioned to ensure backward compatibility as the application evolves."

**Three mechanisms make this durable, not just extensible at launch — all three matter, not just the interface itself:**

1. **Discovery/registration is decoupled from the core.** Plugins are found via directory scanning, config, or a dynamic registry, then registered with a central plugin registry that manages instantiation/lifecycle — the core never needs to know about a specific plugin at build time.
2. **Versioning is a first-class contract, not an afterthought.** An interface version must remain stable for a reasonable period, and a plugin should be able to detect a too-old/incompatible core version and degrade gracefully rather than crash.
3. **Isolation prevents cascading failure.** One plugin's failure or a version mismatch must not take down the core or sibling plugins.

**This is not a new pattern to introduce — it's already the shape of this project's existing design, and this section exists to make that explicit so future additions follow it deliberately rather than by accident:**

| Microkernel concept | This project's equivalent | Already specified in |
|---|---|---|
| Plugin | A registered worker, a registered MCP tool, a registered model provider (once §5 of `01-guiding-philosophy.md`'s capability registry is built) | — |
| Stable, versioned interface | The MCP protocol's capability negotiation (`v1/03-tools-and-mcp.md` §1); the Registry entry schema (`scaling-and-operations.md` §1) | `scaling-and-operations.md` §2 (versioning) |
| Decoupled discovery/registration | The Registry itself | `scaling-and-operations.md` §1 |
| Isolation preventing cascading failure | Per-worker circuit breaking | `scaling-and-operations.md` §3b |

**The discipline this section actually adds:** every new capability added to this system — a new worker, a new tool, a new model provider — must go through the Registry's plugin contract, with no exceptions made "just this once" for convenience. A worker wired directly into orchestrator code, bypassing the Registry, is a microkernel violation that will be paid for the next time that worker needs to change independently.

## 2. Architecture Decision Records — the memory this project needs given how fast the field moves

Source: Michael Nygard's original 2011 post, [Documenting Architecture Decisions](http://thinkrelevance.com/blog/2011/11/15/documenting-architecture-decisions), [adr.github.io](https://adr.github.io/).

> "A new person coming on to a project may be perplexed, baffled, delighted, or infuriated by some past decision."

An ADR is a short, **immutable** record of one significant decision: context, the decision, and its consequences. The purpose is specifically to prevent two failure modes that matter more in a fast-moving field than a slow one: re-litigating a settled decision without knowing what it cost to reach, and accidentally reversing a decision because nobody remembers it was deliberate.

**Required practice for this project:** every decision already recorded in `docs/architecture/` (ADK-as-orchestrator, MCP-as-glue, microVM-tier sandboxing for the coding worker, the tenant-isolation posture, etc.) should eventually be backed by a short ADR at the point it was made — this document set has been *acting* as informal ADRs throughout; formalizing this practice going forward means every future significant decision (adopting a new agent framework, replacing MCP with something else, changing the orchestrator SDK) gets its own dated, immutable record rather than a silent edit to an existing doc.

**Template to adopt:**

```markdown
# ADR-NNN: <short decision title>

**Date:** YYYY-MM-DD
**Status:** proposed | accepted | superseded by ADR-XXX

## Context
What situation/problem forced this decision? What constraints applied at the time?

## Options considered
Briefly, what alternatives were weighed, and why were they not chosen?

## Decision
What was decided.

## Consequences
What does this make easier? What does it make harder? What did we accept as a tradeoff?
```

**Critical rule, stated because it's easy to get wrong under time pressure:** when a past decision is later reversed (e.g., swapping the orchestrator SDK), write a **new** ADR that supersedes the old one — do not edit the old ADR to make it look like the new decision was there all along. The point of an ADR is to preserve the historical reasoning, including reasoning that later turned out to be wrong; erasing it defeats the entire purpose in exactly the scenario (fast-changing field, frequent reconsideration) where it matters most.

## 3. Build vs. buy — a layered framework, not a single yes/no

Source: [Lyzr — Build vs Buy Agentic AI: A CTO's 2026 Framework](https://www.lyzr.ai/blog/build-vs-buy-agentic-ai/).

The stated framing: "the real skill is knowing which layers create your competitive edge and which are just plumbing everyone needs." Six stack layers, each with its own build/buy answer rather than one global policy:

| Layer | Default call | Why |
|---|---|---|
| **Foundation models** | **Buy** (a "settled question for 95% of companies") | Not a source of differentiation; already the reason this project vendors three SDKs to *use* models rather than train them |
| **Integrations to internal/proprietary systems** | **Build, always** | "No vendor knows your internal systems like you do" — this is genuinely this project's own work, not commodity |
| **Orchestration/agent framework layer** | **Hybrid** — adopt a framework (this project already has: ADK), build custom only where the *routing/decomposition logic itself* is proprietary | The framework mechanics (how tool calls execute, how sessions persist) are commodity; this project's specific routing decisions (`v1/02-agents-and-orchestration.md`) are not |
| **Retrieval/context infrastructure** | **Lean build**, per the sharper claim below | This is called out as the actual differentiator — see below |
| **Eval/testing infrastructure** | **Buy the generic tooling, build the eval *content*** | The harness (ADK's eval module) is commodity; the actual eval sets/rubrics specific to this project's domain are not |
| **Observability/guardrails** | **Buy where possible** (OTel-compatible tooling) | Standardizing on OTel GenAI conventions (`v1/09` §1) is itself the "buy the plumbing" choice |
| **Governance/compliance** | **Buy where a standard exists, build only what's genuinely proprietary** | Compliance logging shape is largely standardized (`v1/09` §3's IETF draft) |

**The sharper, more important claim from this same research, worth stating as this project's own operating belief:** since foundation models are commoditizing fast, **the actual sustainable moat is the "context layer"** — proprietary retrieval/RAG architecture, domain-specific eval/fine-tuning data, and tight feedback loops (`v1/05-evaluation-and-feedback-loops.md`) — not the orchestration mechanics. This argues for continuing to adopt orchestration frameworks readily (as this project already does with ADK, OpenAI's SDK, Claude's SDK) and reserving genuine build effort for retrieval quality and the feedback-loop infrastructure specifically, rather than being tempted to build a custom orchestration engine "to be safe."

**Caveat on the cost figures in this space:** build-vs-buy sources in this domain are often vendor-flavored (cost figures like "$100K–$500K+ to build" typically come from vendors selling the "buy" side). Treat specific dollar figures as directional, not precise — but the **layer-by-layer commodity test itself** is a sound, reusable heuristic independent of who's making the argument.

## 4. What this means concretely for onboarding a new agent framework or model

When a new agent framework, model, or protocol emerges (and given the pace of this field, one will), the process is:

1. **Classify it against the layer table in §3.** Is it competing at the commodity orchestration layer (treat like a fourth possible SDK, evaluate via the capability registry pattern), or does it offer something in the context/retrieval layer specifically (worth deeper build investment)?
2. **Write an ADR (§2) proposing adoption**, including what it would replace or complement, and what the fitness functions (`01-guiding-philosophy.md` §2) say about whether the current choice is actually underperforming — don't adopt something new just because it's new.
3. **Prototype behind the existing plugin contract** (§1) — a new worker framework should be addable as a new registered worker without touching orchestrator code, exactly as the microkernel pattern requires. If it can't be added this way, that's a signal the plugin contract itself needs revisiting (a real, earned reason per the Rule of Three, `01-guiding-philosophy.md` §4) — not that the new framework should bypass the contract.
4. **Run it through the same walking-skeleton → eval-harness → regression-gate loop** (`02-build-order-and-methodology.md` §5) as any other new capability before it carries real traffic.

## Sources

- [Plugin Extension Architecture — commons-os.github.io](https://commons-os.github.io/patterns/plugin-extension-architecture/)
- [Michael Nygard — Documenting Architecture Decisions](http://thinkrelevance.com/blog/2011/11/15/documenting-architecture-decisions) · [adr.github.io](https://adr.github.io/)
- [Lyzr — Build vs Buy Agentic AI: A CTO's 2026 Framework](https://www.lyzr.ai/blog/build-vs-buy-agentic-ai/)
