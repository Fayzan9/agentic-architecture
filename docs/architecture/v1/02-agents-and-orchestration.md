# v1 — Agents & Orchestration

**Status:** v1 design — pre-implementation
**Reads with:** `01-overview-and-principles.md`, `docs/architecture/multi-sdk-agentic-architecture.md` (the SDK role-split decision this doc grounds in external research), `04-agent-harness-and-sandboxing.md`

## 1. The building blocks (Anthropic's framework, adopted as this project's vocabulary)

Source: [Anthropic — Building Effective Agents](https://www.anthropic.com/research/building-effective-agents). This project adopts these terms precisely, so "agent" isn't used loosely:

| Term | Definition | Where it shows up here |
|---|---|---|
| **Augmented LLM** | A single model call extended with retrieval, tools, and memory — not yet a multi-step system | The baseline every subtask should be checked against before adding orchestration |
| **Workflow** | A system with **fixed, predefined control flow** between LLM calls | Most of what the orchestrator does day-to-day should be this, not open-ended autonomy |
| **Autonomous agent** | A system where the **LLM itself decides** the control flow, using tool results as ground truth to determine next steps, with explicit stopping conditions | Reserved for genuinely open-ended subtasks (e.g. "investigate and fix this bug" handed to the Claude worker) |

### The five named workflow patterns

1. **Prompt chaining** — sequential decomposition with checkpoints between steps.
2. **Routing** — classify the input, dispatch to the right specialist.
3. **Parallelization** — either *sectioning* (independent subtasks run concurrently) or *voting* (multiple independent attempts at the same task, for reliability).
4. **Orchestrator-workers** — a central LLM **dynamically** decomposes a task and delegates to workers; subtasks aren't predefined at build time (this is the pattern this project's root design already uses).
5. **Evaluator-optimizer** — a generator LLM and a separate evaluator LLM loop until the evaluator is satisfied — this *is* the feedback-loop pattern, formalized (see `05-evaluation-and-feedback-loops.md`).

**Design rule carried into this project:** default to Routing (dispatch to the right worker) for most requests. Reach for Orchestrator-Workers' dynamic decomposition only when the task genuinely can't be classified into one worker up front. Reach for Evaluator-Optimizer explicitly at the points defined in `05-evaluation-and-feedback-loops.md`, not ad hoc.

## 2. Orchestrator-workers pattern — how it applies here

This project's root shape (established in `multi-sdk-agentic-architecture.md`) is literally Anthropic's orchestrator-workers pattern: Google ADK as the orchestrator dynamically routing to Claude Agent SDK and OpenAI Agents SDK workers over MCP. This section adds the **when this helps vs. hurts** analysis that wasn't in the original design doc.

### When orchestrator-workers is worth the cost

Anthropic's own production case study (["How we built our multi-agent research system"](https://www.engineering.fyi/article/how-we-built-our-multi-agent-research-system)) found their orchestrator + 3–5 parallel subagents beat a single agent by 90.2% on their internal research eval — **at ~15x the token cost of one chat turn**. Their stated rule: **multi-agent wins only when the task decomposes into genuinely independent, parallelizable threads.** Three valid criteria, per their follow-up guidance (["When to use multi-agent systems, and when not to"](https://www.claude.com/blog/building-multi-agent-systems-when-and-how-to-use-them)):

- **Context protection** — keeping a large, irrelevant-to-the-main-thread context isolated in a subagent (this is exactly why the voice/realtime split to an OpenAI worker is well-justified: that domain's context has nothing to do with the main orchestration thread).
- **Parallelization** — independent research/work paths that don't need to share intermediate state.
- **Specialization** — a domain genuinely needs different tools/model capabilities (this is exactly why the Claude worker owns coding/file/shell — that's a distinct tool surface, not a decomposition of one task).

### When it actively backfires — the coding-specific friction point

The same follow-up guidance states plainly: **coding tasks are a poor fit for multi-agent decomposition.** Splitting by role ("one agent writes the feature, another writes tests") was found "often counterproductive" in their internal experiments — subagents "spent more tokens on coordination than on actual work," with multi-agent setups running 3–10x the tokens of single-agent for equivalent output on this class of task. Their rule of thumb: **work requiring frequent synchronization or shared context should stay in one agent.**

**Direct implication for this project's design, stated explicitly because it refines the original doc:**

> When the orchestrator hands a coding/file/shell subtask to the Claude Agent SDK worker, hand off the **whole coherent task** ("investigate and fix this bug," "implement this feature end to end") and let that worker run its own internal loop autonomously. Do **not** have the orchestrator further decompose a coding task into sub-steps distributed across multiple calls or multiple workers (e.g., "one call to write the code, a separate call to write tests, a separate call to review it") — the literature says this specific pattern burns tokens on coordination overhead rather than improving output, for this class of task specifically.

This doesn't mean the Claude worker can't use sub-agents *internally* (Claude Code itself supports subagents) — that decision belongs to the worker's own harness, not the orchestrator's routing logic. It means the orchestrator↔worker boundary for coding work should be one coarse-grained delegation, not a chatty back-and-forth.

## 3. Routing logic — how the orchestrator decides where to send a request

Given the role split (`multi-sdk-agentic-architecture.md` §3) and the registry-based discovery model (`scaling-and-operations.md` §1), routing happens in two stages:

1. **Coarse routing (deterministic where possible):** if the request is unambiguously voice/realtime, or unambiguously "operate on this repository," route directly without an extra LLM call to decide — deterministic routing is cheaper and more reliable than asking a model to classify the obvious. Use ADK's own `routing`-equivalent (a lightweight classification step, or even non-LLM heuristics on request metadata) only where the request type isn't self-evident from how it arrived (e.g., API endpoint used, request schema).
2. **Fine routing (LLM-driven, orchestrator-workers pattern):** for requests that could span multiple workers or need decomposition, the orchestrator's LLM plans the delegation dynamically, per the orchestrator-workers pattern — this is where ADK's `LlmAgent` + registry lookup (`scaling-and-operations.md` §1) does the actual work of deciding which registered worker/tool to call.

**Anti-pattern to avoid, given principle #1 (`01-overview-and-principles.md`):** don't reach for stage 2 by default. If a request type is reliably classifiable by cheap, deterministic means (URL path, request schema, an explicit user-selected mode), do that — reserve the LLM-driven dynamic routing for genuinely ambiguous or compound requests. This keeps the common case cheap and fast, and reserves the ~15x-token-cost pattern for when it's actually earning its keep.

## 4. Evaluator-optimizer as the formal shape of quality feedback

Anthropic's fifth pattern — generator + separate evaluator LLM looping until satisfied — is not a separate thing from this project's evaluation subsystem; it **is** the evaluation subsystem's runtime shape when applied mid-task rather than post-hoc. Two distinct applications, both covered in depth in `05-evaluation-and-feedback-loops.md`:

- **Offline/pre-deploy:** generator = the agent under test, evaluator = an LLM-as-judge or rubric evaluator, run against a fixed eval set before any prompt/config change ships.
- **Inline/mid-task (optional, higher cost):** a worker's own output is checked by a second evaluator call before being accepted by the orchestrator — only worth the added latency/cost for high-stakes subtasks (see `05` for the concrete criteria), not applied universally per principle #1.

## 5. Multi-agent system checklist before adding a new worker or decomposition step

Before adding any new agent, worker, or decomposition point to this system, answer these (derived directly from the friction points above — this is not a generic checklist, it's this project's applied version of Anthropic's stated criteria):

- [ ] Does this genuinely need **context protection** (a large context that shouldn't pollute the main thread), **parallelization** (independent work), or **specialization** (a distinct tool/model need)? If none apply, it likely belongs inside an existing worker's own loop, not as a new orchestrator-level split.
- [ ] If this is coding/file/shell work, is it being handed off as **one coherent task**, not decomposed across multiple calls?
- [ ] Have you estimated the token-cost multiplier against a single-agent baseline, and is the quality/capability gain worth it? (Anthropic's own number: ~15x cost for a 90%+ quality gain on a genuinely parallelizable research task — use this as the order-of-magnitude sanity check, not a target.)
- [ ] Does the new worker/step have a registry entry, a version, a health check, and a place in the failure-handling policy (`scaling-and-operations.md` §§1–3)? A new agent that isn't wired into discovery/observability/failure-handling isn't actually production-ready, regardless of how good its prompt is.

## Sources

- [Anthropic — Building Effective Agents](https://www.anthropic.com/research/building-effective-agents)
- [Anthropic — How we built our multi-agent research system](https://www.engineering.fyi/article/how-we-built-our-multi-agent-research-system) (also summarized by [Simon Willison](https://simonwillison.net/2025/Jun/14/multi-agent-research-system/))
- [Claude/Anthropic — When to use multi-agent systems, and when not to](https://www.claude.com/blog/building-multi-agent-systems-when-and-how-to-use-them)
