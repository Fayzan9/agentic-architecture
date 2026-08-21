# v1 — Queueing & Async Execution

**Status:** v1 design — pre-implementation
**Reads with:** `04-agent-harness-and-sandboxing.md` §3 (snapshot-restore ties into checkpointing), `10-deployment-and-infrastructure.md`

## 1. When to go async vs. stay synchronous

Sources: [Ranjan Kumar — Why Asynchronous Processing/Queues are the Backbone of Agentic AI](https://ranjankumar.in/why-asynchronous-processing-queues-are-the-backbone-of-agentic-ai), [Zylos Research — Event-Driven Architecture for AI Agent Systems](https://zylos.ai/research/2026-03-02-event-driven-architecture-ai-agent-systems/).

**Default rule:** synchronous request/response is fine for short, single-turn, single-worker calls where the user is actively waiting for a fast answer. Route to an async task queue instead when any of these hold:

- The task is **long-running** (a multi-step coding task that could take minutes, not seconds).
- The task involves **fan-out** to multiple workers whose results need to be gathered (an orchestrator-workers dynamic decomposition per `02-agents-and-orchestration.md` §2).
- The task requires a **human-in-the-loop pause** (`04-agent-harness-and-sandboxing.md` Component 5's escalation path, or an explicit approval step) — the request can't stay open on a synchronous connection while waiting on a human.

**Why this matters specifically for this project:** holding a synchronous connection open for a multi-minute Claude worker coding task (or a paused-for-approval flow) ties up server resources and is fragile against client-side or gateway timeouts. Moving that class of work to a durable async queue decouples "the user's request was accepted" from "the work is still running," and makes the harness's own turn-loop timeout (`04` Component 1) an internal concern rather than something the user-facing connection has to survive.

## 2. Checkpointing / durable execution — required, not optional, for long-running tasks

Both sources call out checkpointing specifically for agents, not as a generic distributed-systems nicety: pause/resume, time-travel debugging, and surviving process restarts mid-task. **For this project, this is a required capability the moment a task is routed to the async path (§1), not an optional enhancement:**

- A long-running Claude worker coding task must be able to persist its working/task-state (`06-memory-state-and-storage.md` §3) at defined checkpoints, so a worker process restart (deploy, crash, autoscale-down) doesn't lose an in-progress task — it resumes from the last checkpoint.
- This connects directly to the sandbox snapshot-restore design (`04-agent-harness-and-sandboxing.md` §3): a Firecracker snapshot at a task checkpoint captures both the task's logical state (via the queue/DB) and its execution environment state (via the sandbox snapshot) together — treat these as one checkpoint operation, not two independently-timed ones that could drift out of sync.
- Human-in-the-loop pauses are a special case of checkpoint: the task's state is persisted, execution suspends, and resumption is triggered by an external event (human approval) rather than a timer or retry.

## 3. Queue technology — pick by actual need, not by defaulting to the most powerful option

Multiple sources explicitly warn against **"the Kafka trap"** — reaching for the most powerful/complex streaming platform by default when the actual need is simpler background-job offloading. Documented tradeoffs:

| Technology | Best fit | Why |
|---|---|---|
| **Kafka** | High-throughput event streams, many independent consumers, need for replay/long retention of the event log | Overkill for straightforward task-offloading between services — brings operational complexity (partitioning, consumer groups, retention tuning) this project shouldn't take on until there's a concrete high-throughput streaming need |
| **RabbitMQ / Azure Service Bus** | Ordered task queuing with routing/priority semantics | A reasonable middle ground if ordering guarantees matter more than raw throughput |
| **Redis + BullMQ** | Simpler background job offloading between services | Explicitly recommended over Kafka when the actual requirement is "run this task in the background and track its status," which is most of this project's async needs — and Redis is already in this project's stack as the hot-tier session store (`06-memory-state-and-storage.md` §5), so this avoids introducing a second infrastructure dependency |
| **Celery** | Python-based distributed task queue | The default choice for a Python-based worker fleet (which this project is, given all three vendored SDKs are Python) — handles retries, worker scaling, and result persistence natively, overlapping usefully with the retry/circuit-breaker design already specified (`scaling-and-operations.md` §3) |

**Decision for this project's v1:** default to **Celery with a Redis broker** (or Redis+BullMQ if a non-Celery task-queue library fits the codebase better) for the async task path, given the Python-based worker fleet and Redis already being adopted for hot-tier state. **Do not adopt Kafka for v1** — revisit only if a concrete requirement emerges for high-throughput event streaming with multiple independent consumers replaying the same event log, which is a different problem than "run this agent task in the background."

## 4. What goes on the queue, concretely, for this project

| Queued unit of work | Triggers | Checkpoint needed? |
|---|---|---|
| A long-running Claude worker coding task | Orchestrator routes a coding subtask expected to exceed a synchronous-timeout threshold | Yes — sandbox snapshot + task state (§2) |
| A human-in-the-loop approval wait | A harness permission escalation (`04` Component 5) requires human sign-off | Yes — suspend, resume on external event |
| A multi-worker fan-out (orchestrator-workers dynamic decomposition) | Orchestrator decides a request needs multiple independent worker calls gathered together | Partial — track completion state per sub-call, not necessarily a full sandbox checkpoint per sub-call |
| A shadow-test replay (`05-evaluation-and-feedback-loops.md` §4) | Production trace forked to a candidate version for comparison | No — fire-and-compare, not resumable |
| Warm-tier memory promotion (`06-memory-state-and-storage.md` §1) | Async extraction of structured facts from a completed session | No — idempotent background job, safe to just retry from scratch on failure |

## 5. Failure handling for queued work

This composes with, rather than replaces, the failure-handling policy already specified in `scaling-and-operations.md` §3: a queued task that fails mid-execution should surface through the same reflect-and-retry / circuit-breaker mechanisms, with one addition specific to async work — **a queued task's failure must be visible to whatever is waiting on its result** (a user polling status, or another part of the system waiting on the fan-out in the table above), not just logged and silently retried indefinitely. Define a max-retry-then-surface-as-failed policy per queued-work type, consistent with the "failure must be visible to the model, not just logged" principle already established for tool calls.

## Sources

- [Ranjan Kumar — Why Asynchronous Processing/Queues are the Backbone of Agentic AI](https://ranjankumar.in/why-asynchronous-processing-queues-are-the-backbone-of-agentic-ai)
- [Zylos Research — Event-Driven Architecture for AI Agent Systems](https://zylos.ai/research/2026-03-02-event-driven-architecture-ai-agent-systems/)
