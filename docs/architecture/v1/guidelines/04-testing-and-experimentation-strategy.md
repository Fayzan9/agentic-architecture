# Guidelines — Testing & Experimentation Strategy

**Status:** v1 guidelines — pre-implementation
**Reads with:** `v1/05-evaluation-and-feedback-loops.md` (the eval *subsystem*; this doc is the *testing practice/discipline* layered on top of it), `02-build-order-and-methodology.md` §2 (eval-driven development order)

## 1. The testing pyramid, adapted for agents

Sources: [LangWatch — The Agent Testing Pyramid](https://langwatch.ai/blog/the-agent-testing-pyramid-a-mental-model-for-trustworthy-agents), [Block Engineering — Testing Pyramid for AI Agents](https://engineering.block.xyz/blog/testing-pyramid-for-ai-agents).

Four layers, cheapest/fastest at the base, most expensive/slowest at the top — **each with a different cadence and a different question it answers**, which is the detail most teams get wrong by treating all agent testing as one undifferentiated thing:

| Layer | Answers | Method | Cadence |
|---|---|---|---|
| **Deterministic foundations** | "Did we write correct software?" (not "is the agent good?") | Traditional unit tests with **mocked** LLM providers — retry logic, tool schema validation, max-turn limits, delegation logic | Every commit/PR |
| **Reproducible reality** | "Does the interaction flow correctly?" | Record/replay real LLM and MCP tool-call interactions deterministically — validates tool-call *sequences*, not exact output text | Every PR, in CI |
| **Probabilistic performance** | "Is the agent actually good?" | Structured benchmarks over a frozen golden set; success rate across multiple runs; **LLM-as-judge with rubrics, 3 runs + majority voting** for subjective judgments (not a single judge call — directly reinforces the judge-calibration concern in `v1/05` §2) | On-demand or per-PR, **deliberately not continuous** — live-LLM tests in CI are explicitly called out as "too costly and unstable" for tight per-commit loops |
| **Red-team / canary / live** | "Is it still good in the real world, including against adversarial input?" | Adversarial/jailbreak testing; production trace replay; live-traffic evaluation | Continuous in production, human-reviewed "when it matters," not on a fixed schedule |

**Ownership pattern:** PMs/domain owners define specs → developers implement → tooling auto-generates test cases from specs, where feasible. This division matters for a multi-worker system specifically — the person who understands what the coding worker *should* do is not necessarily the person implementing its harness, and the spec-to-test generation step is what keeps those two roles from drifting apart.

**Direct mapping onto this project's existing components:** the "deterministic foundations" and "reproducible reality" layers are new testing infrastructure this project needs to build explicitly (they're not the same as the eval suite in `v1/05`). The "probabilistic performance" layer **is** `v1/05-evaluation-and-feedback-loops.md`'s trajectory/rubric eval system. The "red-team/canary/live" layer **is** `v1/05` §4's shadow/canary rollout plus a red-team/adversarial-testing practice this project should add explicitly — adversarial testing against tool-result prompt injection (`v1/03-tools-and-mcp.md` §3) is a natural fit here, since that's exactly the kind of thing static eval sets don't reliably catch.

## 2. Experiment tracking — version prompts like code, don't over-tool early

Source: [Hamel Husain — Evals FAQ](https://hamel.dev/blog/posts/evals-faq/), [Braintrust — Best Prompt Versioning Tools 2025](https://www.braintrust.dev/articles/best-prompt-versioning-tools-2025), [AIUniverse — experiment tracking platform comparison](https://www.aiuniverse.xyz/top-10-experiment-tracking-platforms-features-pros-cons-comparison/).

**Core guidance:** version and manage prompts in **Git**, not a separate prompt-management UI — and prefer running experiments through a notebook/script with real Python entry points into the actual agent (full tools/context/harness) over an isolated prompt playground, so experiments reflect how the system actually behaves in production, not an artificial subset stripped of its real context.

**Track eval results as data over time**, outside the CI system itself (a lightweight results log or a simple dataset store), so trend analysis across weeks/months doesn't require re-running or archaeology through CI history.

**Team-size-appropriate tooling — an explicit anti-over-engineering rule:** a full LLMOps platform (Weights & Biases Weave, MLflow, Comet) is called "overkill" below a certain team size and traffic volume. Small teams get by with lightweight tools — Git for prompt versioning plus a simple eval-results log, or a one-line-integration tool. **Adopt heavier experiment-tracking infrastructure only once there's already ML infrastructure it plugs into, not as a first step** — this is the same Rule-of-Three-flavored discipline from `01-guiding-philosophy.md` §4 applied to tooling choice specifically: don't buy/build the heavy version of a tool before the light version has actually become insufficient.

## 3. Stage-gate criteria — graduation from experiment to production is a numeric event

Source: [FutureAGI — Definitive Guide to AI Agent Evaluation 2026](https://futureagi.com/blog/definitive-guide-ai-agent-evaluation-2026/), [DZone — Shipping Production-Grade AI Agents](https://dzone.com/refcardz/shipping-production-grade-ai-agents).

**Concrete example thresholds** (illustrative starting points, to be recalibrated against this project's own eval data, not copied verbatim as universal constants): task success **>80%**, safety-refusal rate **<3%** of completable tasks, **p95 latency within SLA** — a combined accuracy + safety + efficiency bar, not a single quality score in isolation.

**Two rules worth adopting as explicit policy, because they prevent a specific, common failure mode:**

1. **Success criteria are locked at brief/spec sign-off**, with mid-build redefinition allowed only once, and only with written rationale (an ADR per `03-extensibility-and-plugin-contracts.md` §2 is the natural vehicle). This exists specifically to prevent goalpost-moving — quietly redefining "success" partway through so a mediocre result can be called a pass.
2. **Promotion is a numeric event** — a gate-checklist score crossing an agreed threshold — not a subjective "feels ready" call. This directly operationalizes the eval-harness-first discipline from `02-build-order-and-methodology.md` §2: if the harness was built before the capability, the promotion decision is just "does it pass," not a judgment call requiring debate.

## 4. Documented anti-patterns — a checklist, because these are the failures that actually happen

Sources: [MachineLearningMastery — Building AI Agents: Anti-Patterns to Avoid](https://machinelearningmastery.com/building-ai-agents-here-are-some-anti-patterns-to-avoid/), [DigitalApplied — Prompt Engineering Anti-Patterns](https://www.digitalapplied.com/blog/prompt-engineering-anti-patterns-10-mistakes-2026).

- [ ] **Happy-path/demo-grade testing only.** Personal/ad hoc testing covers less than 10% of the real input space by one estimate; the large majority of production issues come from scenarios nobody happened to try by hand. Structured eval sets (§1, `v1/05`) exist specifically because manual spot-checking systematically under-samples the failure space.
- [ ] **Prompt scope creep.** A prompt that grows weekly to patch each newly discovered failure, with nothing ever removed, until it's thousands of tokens evaluated in full on every request — a maintainability *and* cost anti-pattern (compounds directly with the prompt-caching invalidation concern in `v1/07-caching.md` §2, since a constantly-changing prompt breaks cache stability too). Prompts need periodic pruning/refactoring as a scheduled activity, not just accretion.
- [ ] **Rule enforcement in the wrong layer.** "If a rule must hold, enforce it in the system, not in the prompt." This directly validates the deterministic-guardrail requirement already specified in `v1/04-agent-harness-and-sandboxing.md` Component 5 — a rule stated only as a prompt instruction is not actually enforced, and testing should specifically probe whether a rule can be talked around, not just whether the model follows it under normal conditions.
- [ ] **Instruction-example contradiction.** Three or more contradictions between a prompt's stated rules and its own few-shot examples is called a near-certain source of regressions, regardless of current eval performance — worth an explicit lint/review pass on any prompt before it ships, not just eval scores.
- [ ] **Eval-set overfitting.** Tuning a prompt until it beats a small, static eval set, without the production-failure feedback loop (`v1/05-evaluation-and-feedback-loops.md` §3) actually feeding new failures back into that same set. A static eval set that never grows from real production failures becomes a target to game rather than a genuine quality bar over time.

## 5. Summary — what to actually build, and in what order relative to §1–§4

Given `02-build-order-and-methodology.md`'s "eval harness before capability" rule, the practical build order for the testing infrastructure itself:

1. Deterministic unit tests with mocked providers — cheap, build immediately, every commit.
2. Record/replay tests for tool-call sequences — build alongside the first real MCP integration, since this is what actually validates the orchestrator↔worker contract (`v1/03-tools-and-mcp.md`).
3. The rubric/trajectory eval suite (`v1/05`) — build before the first real capability ships, per the eval-driven-development order.
4. Red-team/adversarial testing — add once there's a real attack surface worth probing (i.e., once tool-result content can plausibly come from untrusted sources), not before.
5. Experiment tracking tooling — start with Git + a simple results log; do not adopt a full LLMOps platform until team size/volume genuinely outgrows that (§2).

## Sources

- [LangWatch — The Agent Testing Pyramid](https://langwatch.ai/blog/the-agent-testing-pyramid-a-mental-model-for-trustworthy-agents) · [Block Engineering — Testing Pyramid for AI Agents](https://engineering.block.xyz/blog/testing-pyramid-for-ai-agents)
- [Hamel Husain — Evals FAQ](https://hamel.dev/blog/posts/evals-faq/) · [Braintrust — Best Prompt Versioning Tools 2025](https://www.braintrust.dev/articles/best-prompt-versioning-tools-2025)
- [FutureAGI — Definitive Guide to AI Agent Evaluation 2026](https://futureagi.com/blog/definitive-guide-ai-agent-evaluation-2026/) · [DZone — Shipping Production-Grade AI Agents](https://dzone.com/refcardz/shipping-production-grade-ai-agents)
- [MachineLearningMastery — AI Agent Anti-Patterns](https://machinelearningmastery.com/building-ai-agents-here-are-some-anti-patterns-to-avoid/) · [DigitalApplied — Prompt Engineering Anti-Patterns](https://www.digitalapplied.com/blog/prompt-engineering-anti-patterns-10-mistakes-2026)
