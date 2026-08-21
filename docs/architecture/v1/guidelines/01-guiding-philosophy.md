# Guidelines — Guiding Philosophy

**Status:** v1 guidelines — pre-implementation
**Reads with:** `docs/architecture/v1/01-overview-and-principles.md` (the two principles there — earn complexity, isolate by default — are the "what"; this doc is the "how to keep it true as the field moves under you")

## 1. The actual problem this guideline set solves

AI/agent tooling changes faster than most software domains — new frameworks, new model capabilities, new protocols appear on a timescale of months, not years. Two failure modes are both real and both must be designed against simultaneously:

1. **Over-fitting to today's stack** — hardcoding assumptions specific to Google ADK / OpenAI Agents SDK / Claude Agent SDK / MCP so deeply that adopting a genuinely better framework or protocol two years from now requires a rewrite, not a swap.
2. **Over-abstracting against an unknown future** — building elaborate provider-agnostic, framework-agnostic layers *before* there's a second real instance of anything to abstract over, guessing wrong about what actually varies, and ending up with an abstraction that's both wrong and in the way.

This document set exists to resolve that tension with named, sourced methodology rather than instinct.

## 2. Evolutionary architecture — guided change, not unconstrained change

Source: Ford, Parsons, Kua — [*Building Evolutionary Architectures*](https://nealford.com/books/buildingevolutionaryarchitectures.html), [Fitness Functions chapter](https://www.oreilly.com/library/view/building-evolutionary-architectures/9781491986356/ch02.html).

The core mechanism is the **fitness function**: an automated, objective check that verifies an architectural characteristic stays within bounds as the system changes. This is what makes evolution *guided* rather than chaotic — you don't freeze the design against change, and you don't let change happen unchecked either. You instrument the properties that actually matter and let a pipeline enforce them on every change.

**Fitness functions this project should define early, concretely:**

| Fitness function | What it checks | How it's enforced |
|---|---|---|
| "No worker is a hard dependency" | The orchestrator degrades gracefully (per `scaling-and-operations.md` §3) if any one worker is unavailable | Circuit-breaker + chaos test: kill a worker in staging, assert the system still serves other request types |
| "Swapping a model provider doesn't regress eval scores below threshold" | A model swap behind the capability registry (§4 below) passes the same eval suite as the model it replaces | The regression gate (`v1/05-evaluation-and-feedback-loops.md` §5) run against the candidate provider before promotion |
| "Adding a new worker doesn't require orchestrator code changes" | New workers register via the Registry (`scaling-and-operations.md` §1), not via a code diff to the orchestrator | Code review checklist item / lint rule flagging hardcoded worker references outside the Registry client |
| "Tool output stays within the cap regardless of which worker/tool" | Every tool response respects the ~25,000 token cap (`v1/03-tools-and-mcp.md` §2) | Contract test at the MCP tool-execution choke point (`v1/09-observability-audit-cost-and-ratelimiting.md` §5) |

**The companion principle: delay decisions until the "last responsible moment."** Ford's guidance is not "decide late for its own sake" — it's "identify, via fast feedback loops and fitness functions, the point past which delaying a decision starts costing more than deciding wrong would." Concretely for this project: don't pre-decide the long-term vector database (`v1/06-memory-state-and-storage.md` §5 already defers this) until query-volume data exists to decide with; don't pre-build a multi-provider model abstraction until there's a second provider actually in use driving a real requirement. Waiting isn't procrastination here — it's using real information instead of guessing.

## 3. Ports-and-adapters as the core mental model for this system

Source: [Hexagonal architecture (ports and adapters)](https://en.wikipedia.org/wiki/Hexagonal_architecture_(software)), [applied to an LLM service](https://knitish91.medium.com/hexagonal-microservice-architecture-with-an-llm-service-for-credit-engine-cc8e6d21493e), [Ports and Adapters explained](https://journal.optivem.com/p/hexagonal-architecture-ports-and-adapters).

The pattern: core logic defines **ports** — interfaces for what it needs (a model completion, a tool result, a memory lookup). **Adapters** are swappable implementations behind those ports. Dependencies point inward only: the core never imports a specific provider's SDK directly, only the port interface. As one applied source puts it, "the LLM acts as a plug-and-play intelligent adapter connected via well-defined ports... you can upgrade or switch models... without touching the core engine."

**This maps directly onto decisions this project has already made, which is worth stating explicitly — this isn't a new architecture to bolt on, it's already the shape of the existing design:**

- The **Registry** (`scaling-and-operations.md` §1) is the mechanism that resolves a port (a needed capability) to an adapter (a specific registered worker/tool) at runtime.
- **MCP itself** (`v1/03-tools-and-mcp.md` §1) is a port-and-adapter boundary by protocol design — the host never needs to know a server's internal implementation, only its declared tools/capabilities.
- The **infrastructure layer is explicitly the layer expected to keep changing** (model providers, specific worker SDKs, storage backends) — this is precisely why it sits behind the Registry/MCP boundary rather than being reached into directly from orchestration logic.

**What must NOT sit behind a port, to avoid the over-abstraction failure mode:** the orchestrator's own routing/decomposition logic (`v1/02-agents-and-orchestration.md`) is this project's actual differentiated logic — it should not be written as a swappable "adapter" as if it were commodity infrastructure. Ports-and-adapters isolates the *volatile, external* dependencies; it is not a mandate to make everything pluggable, including the parts that are this project's actual value.

## 4. When to abstract — the Rule of Three, applied concretely

Source: Martin Fowler's [Rule of Three](https://en.wikipedia.org/wiki/Rule_of_three_(computer_programming)), [The Problem of Premature Abstraction](https://alissonsteffens.com/blog/premature-abstraction/), [Holden Rehg — Rule of Three](https://holdenrehg.com/blog/2021-09-20_rule-of-three).

**The heuristic:** solve it plainly the first time. Tolerate duplication the second time. Only extract an abstraction the **third** time the same shape recurs. Rationale, stated plainly in the sources: "it's easier to make a good abstraction from duplicated code than it is to refactor the wrong abstraction" — an early abstraction encodes assumptions that are usually wrong, and *locks in* a bad model rather than preventing lock-in, which is the opposite of the intended effect.

**Concrete symptoms of premature abstraction to watch for in this project specifically**, per the sources: extra indirection that obscures what code actually does; configuration/conditional branches added just to make one abstraction serve multiple unrelated callers (e.g., a "generic worker adapter" with special-case branches for each SDK's quirks — a sign the abstraction is wrong, not that it needs more branches); fragility where a change for one consumer silently breaks another.

**Applied rule for this project, stated as policy:** build a genuine abstraction (a model-provider interface, a generalized worker-adapter interface) once you've had to change the same seam **twice for a real reason** — a second model provider actually in production use, a second worker SDK actually needed for a real capability gap — not speculatively ahead of that, and not merely because "a scalable system should have one." This directly reinforces `v1/01-overview-and-principles.md`'s Principle #1 ("complexity must be earned") with a specific, countable trigger instead of a vague judgment call.

## 5. The capability registry pattern — the concrete shape for model/provider abstraction, once it's earned

Source: [Compai Playbook — LLM Provider Abstraction](https://usecompai.com/playbook/18-llm-providers.html), [Vercel AI SDK — Providers and Models](https://ai-sdk.dev/docs/foundations/providers-and-models), [LiteLLM](https://www.getmaxim.ai/articles/top-5-litellm-alternatives-in-2026/).

When the Rule of Three (§4) is actually satisfied for model providers, the recommended shape — not a naive "flatten every provider to one API" abstraction — is a **dated capability registry**, kept separate from agent code:

- Maps **task classes** (not individual agents) to a primary + fallback provider, by declaring the capabilities that task class actually requires (e.g., `[tool_calling, structured_output, vision]`) — not by provider brand preference.
- Selection is by **measured evidence** — eval pass rate, schema-adherence reliability, latency, cost from this project's own eval suite (`v1/05-evaluation-and-feedback-loops.md`) — not by which provider is newest or most hyped.
- **Explicitly excludes model IDs and pricing from the abstracted interface itself** — those change fast and belong in the dated registry data, refreshed at deploy time, never hardcoded into orchestration/routing logic.
- **Tracks failure states explicitly** (`ok` / `blocked-provider` / `failed-validation` / `escalated`) rather than silently degrading to an incompatible model when a capability isn't actually available — a naive abstraction that flattens provider differences away is a leaky one, since providers differ in real capabilities (tool-calling schema strictness, structured-output support, reasoning-trace formats), not just API shape.

**Why this matters for staying adaptable specifically:** a new model provider entering the market is absorbed by adding a registry entry with its measured capability/eval data — not by touching orchestration logic, and not by pretending it's identical to existing providers when it isn't.

**Documented pitfall to design around from the start, if/when this abstraction is built:** LiteLLM (a widely used example of this pattern) hits real architectural limits at scale — Python GIL-bound concurrency degradation under high load — which is a reason to treat any adopted or built abstraction library as a component with its own fitness functions (§2), not an assumed-permanent foundation.

## Sources

- [Building Evolutionary Architectures — fitness functions](https://www.oreilly.com/library/view/building-evolutionary-architectures/9781491986356/ch02.html) · [nealford.com](https://nealford.com/books/buildingevolutionaryarchitectures.html)
- [Hexagonal architecture (Wikipedia)](https://en.wikipedia.org/wiki/Hexagonal_architecture_(software)) · [Hexagonal + LLM example](https://knitish91.medium.com/hexagonal-microservice-architecture-with-an-llm-service-for-credit-engine-cc8e6d21493e) · [Ports and Adapters explained](https://journal.optivem.com/p/hexagonal-architecture-ports-and-adapters)
- [Rule of Three (Wikipedia)](https://en.wikipedia.org/wiki/Rule_of_three_(computer_programming)) · [The Problem of Premature Abstraction](https://alissonsteffens.com/blog/premature-abstraction/) · [Holden Rehg — Rule of Three](https://holdenrehg.com/blog/2021-09-20_rule-of-three)
- [Compai Playbook — LLM Provider Abstraction](https://usecompai.com/playbook/18-llm-providers.html) · [Vercel AI SDK — Providers and Models](https://ai-sdk.dev/docs/foundations/providers-and-models) · [LiteLLM overview/limits](https://www.getmaxim.ai/articles/top-5-litellm-alternatives-in-2026/)
