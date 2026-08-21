# v1 — Evaluation & Feedback Loops

**Status:** v1 design — pre-implementation
**Reads with:** `02-agents-and-orchestration.md` §4 (evaluator-optimizer pattern), `docs/sources/adk-python-reference.md` (ADK's `evaluation/` module)

## 1. Why this is its own subsystem, not a testing afterthought

At this project's scale (many workers, many MCP tools, an orchestrator making dynamic routing decisions), the actual product surface is **agent behavior** — which tools get called, with what arguments, in what sequence — not just final-answer text. Evaluation has to test that surface directly, and feedback has to close the loop from real production behavior back into what gets tested. ADK is the right home for this given it already ships a real evaluation module (`evaluation/agent_evaluator.py`, `eval_set.py`, `metric_evaluator_registry.py`, `rubric_based_evaluator.py`, `multi_turn_trajectory_quality_evaluator.py` — see `docs/sources/adk-python-reference.md`).

## 2. Evaluation methodology

### Start from real errors, not imagined ones

Source: [Hamel Husain — LLM Evals FAQ](https://hamel.dev/blog/posts/evals-faq/). The correct starting point for building an eval suite is **error analysis on real production traces**, not hypothetical failure modes dreamed up in a design doc. Concretely: don't write this project's initial eval set purely from imagined edge cases — instrument production first (`09-observability-audit-cost-and-ratelimiting.md`), sample real traces, find actual failures, and write evaluators for those. This inverts the naive order (build evals → ship → watch for failures); the correct order is closer to (ship instrumented → find real failures → build evals from them → gate future changes).

### Trajectory evaluation, not just final-answer evaluation

Source: [OpenAI — Evaluate agent workflows](https://developers.openai.com/api/docs/guides/agent-evals), [langchain-ai/agentevals](https://github.com/langchain-ai/agentevals). The standard framing for agentic systems now distinguishes:

- **Single-turn/final-answer evals** — grade the final output string. Necessary but insufficient for a multi-worker system.
- **Trajectory evals** — score the whole run: the sequence of tool calls, intermediate messages, routing decisions, not just the final answer.

**Given this project's design (orchestrator making dynamic routing decisions across MCP workers), trajectory evaluation is the primary eval type, final-answer grading is secondary.** A request can produce a correct final answer while having routed to the wrong worker, called a tool with worse-than-ideal arguments, or burned an unjustified amount of cost getting there — final-answer-only grading is blind to all three, and all three are exactly the failure modes this multi-worker architecture introduces. ADK's `multi_turn_trajectory_quality_evaluator.py` and `multi_turn_tool_use_quality_evaluator.py` are the concrete tools for this.

### LLM-as-judge — real, documented pitfalls, not folklore

Sources: [arXiv 2604.23178 — Judging the Judges](https://arxiv.org/pdf/2604.23178), [arXiv 2411.16594 — From Generation to Judgment](https://arxiv.org/pdf/2411.16594), [arXiv 2601.13649 — Fairness or Fluency](https://arxiv.org/pdf/2601.13649). Documented, reproducible biases:

- **Position bias** — a judge's preference shifts based on which answer is presented first/second.
- **Verbosity bias** — judges prefer longer, more authoritative-*sounding* answers over correct-but-terse ones.
- **Self-enhancement/egocentric bias** — a judge model rates outputs from its own model family more favorably.
- **Manipulability** — a judge can be swayed by prompt-injection-style content embedded in the transcript it's judging.

The deeper problem: if the judge itself is unreliable, the entire eval stack rests on an uncertain foundation — this isn't a minor caveat, it's the reason judge design needs its own rigor.

**Required mitigations for this project:**

1. **Rubric-based scoring, not open-ended "rate this 1–10."** Constrain judgment to specific, checkable criteria (did it call the correct worker? did it stay within the tool-output cap? did it avoid an unauthorized action?) rather than holistic quality scores, which is exactly where verbosity/position bias creep in. ADK's `evaluation/rubric_based_evaluator.py` and `rubric_based_multi_turn_trajectory_evaluator.py` are the concrete implementation path — use these as the default judge shape, not a custom open-ended prompt.
2. **Calibrate the judge against human review before trusting it at scale.** A rubric judge's agreement with human raters on a sample should be checked and periodically re-checked — a judge that hasn't been calibrated is not yet trustworthy as a deploy gate.

## 3. Human feedback loop — capture → dataset → gate

Sources: [FutureAGI — User Feedback Loops 2026](https://futureagi.com/blog/integrating-user-feedback-automated-data-layers/), [Microsoft — Beyond thumbs up and thumbs down](https://medium.com/data-science-at-microsoft/beyond-thumbs-up-and-thumbs-down-a-human-centered-approach-to-evaluation-design-for-llm-products-d2df5c821da5).

> Thumbs up/down is not the end state, it's a capture mechanism — the value is in what happens after.

**Required pipeline, as one explicit system, not a UI widget bolted onto a chat interface:**

```
User feedback signal (thumbs, correction, escalation)
        │
        ▼
Stored SEPARATELY from message/conversation content
(a dedicated feedback/annotation table — not appended to chat history,
 which would pollute context and couple storage lifecycles)
        │
        ▼
Aggregated offline into dataset rows
        │
        ▼
Dataset rows become regression checks
        │
        ▼
Regression checks GATE the next deploy of any
prompt / agent config / tool schema / routing logic change
```

**Two feed sources into the same dataset store, not two separate systems:** the eval team's curated hold-out set, and production thumbs/corrections — both should land in one dataset store so regression checks reflect both designed-for cases and real observed failures.

**Caveat, repeated across sources:** thumbs-only feedback is too coarse alone. Nuanced failure modes (wrong worker chosen but plausible-sounding answer, correct answer via a wasteful/expensive path) need structured annotation or correction capture, not just a binary signal. Design the feedback capture UI/API to support at least: binary signal, free-text correction, and (internally) a link to the specific trajectory span (`09-observability-audit-cost-and-ratelimiting.md` §1) that was rated, so a "thumbs down" is traceable to the exact routing/tool-call decision being criticized.

## 4. Production quality-drift monitoring

Sources: [TianPan.co — Shadow/Canary/A-B for LLMs](https://tianpan.co/blog/2026-04-09-llm-gradual-rollout-shadow-canary-ab-testing), [FutureAGI — Shadow Traffic and Canary Deployment](https://futureagi.com/blog/llm-eval-shadow-traffic-canary-2026/).

Passing the offline eval suite is necessary but not sufficient — a change can pass eval and still degrade in production (the eval set doesn't cover everything real traffic does). Two named, complementary patterns:

- **Shadow testing** — production traffic is duplicated (forked at the gateway) to a candidate version with a shared correlation ID; the candidate's outputs are compared against the live version's without affecting the real user. Used to validate a change **before** promotion, with real traffic, at zero user-facing risk.
- **Canary release** — gradual traffic ramp (e.g., 5% → 10% → 25% → 50% → 100%) to the new version, with metrics monitored and **automatic rollback** triggers defined at each stage. Used **during** promotion.

**Required for this project, given it's a multi-worker/multi-MCP system specifically:** drift detectors should run over **tool-call distributions and routing/scenario tags**, not just output-quality scores. A change that shifts which workers get called, or how often a given tool is invoked, for the same class of request, is a behavioral drift signal even if final-answer quality metrics look unchanged — and tool-call behavior is this system's actual product surface (per §1), so it deserves its own drift dashboard, not just an output-quality one.

## 5. Concrete subsystems this project needs to build

| Subsystem | What it does | Built on |
|---|---|---|
| **Trace sampler** | Pulls a sample of real production traces for error analysis (§2) | Observability pipeline, `09-observability-audit-cost-and-ratelimiting.md` §1 |
| **Rubric judge** | Structured, criteria-based scoring — not open-ended | ADK `evaluation/rubric_based_evaluator.py` family |
| **Judge calibration harness** | Periodically checks judge-vs-human agreement on a sample | New — a scheduled eval job comparing judge output to a human-labeled hold-out |
| **Feedback capture API + store** | Captures thumbs/corrections separately from conversation content, linked to trace/span IDs | New dedicated table/store, not appended to session state (`06-memory-state-and-storage.md`) |
| **Regression gate** | Runs the eval set (trajectory + rubric) against any prompt/config/tool-schema/routing change before deploy; blocks on failure | ADK `evaluation/local_eval_service.py`, wired into CI/CD (`10-deployment-and-infrastructure.md`) |
| **Shadow/canary rollout controller** | Forks or ramps traffic to a candidate version, compares metrics, auto-rolls-back on threshold breach | New — sits at the deployment/gateway layer (`10-deployment-and-infrastructure.md`) |
| **Drift dashboard** | Tracks tool-call distribution and routing-tag drift over time, not just quality scores | New — consumes the same trace data as the trace sampler and observability pipeline |

## Sources

- [Hamel Husain — LLM Evals FAQ](https://hamel.dev/blog/posts/evals-faq/)
- [OpenAI — Evaluate agent workflows](https://developers.openai.com/api/docs/guides/agent-evals) · [openai/evals](https://github.com/openai/evals) · [langchain-ai/agentevals](https://github.com/langchain-ai/agentevals)
- [arXiv 2604.23178 — Judging the Judges](https://arxiv.org/pdf/2604.23178) · [arXiv 2411.16594](https://arxiv.org/pdf/2411.16594) · [arXiv 2601.13649](https://arxiv.org/pdf/2601.13649)
- [FutureAGI — Integrating User Feedback](https://futureagi.com/blog/integrating-user-feedback-automated-data-layers/) · [Microsoft — Beyond thumbs up and thumbs down](https://medium.com/data-science-at-microsoft/beyond-thumbs-up-and-thumbs-down-a-human-centered-approach-to-evaluation-design-for-llm-products-d2df5c821da5) · [LangWatch — Thumbs Up/Down](https://langwatch.ai/docs/user-events/thumbs-up-down)
- [TianPan.co — Shadow/Canary/A-B testing for LLMs](https://tianpan.co/blog/2026-04-09-llm-gradual-rollout-shadow-canary-ab-testing) · [FutureAGI — Shadow Traffic and Canary Deployment](https://futureagi.com/blog/llm-eval-shadow-traffic-canary-2026/)
