# v1 — Agent Harness & Sandboxing

**Status:** v1 design — pre-implementation
**Reads with:** `02-agents-and-orchestration.md`, `03-tools-and-mcp.md` §3, `10-deployment-and-infrastructure.md`

## 1. What a "harness" is, precisely

Sources: [Endor Labs — What is an agent harness?](https://www.endorlabs.com/learn/what-is-an-agent-harness-the-software-that-turns-a-model-into-an-agent), [boringbot.substack — AI Agent Harnesses Explained](https://boringbot.substack.com/p/ai-agent-harnesses-explained-architecture).

> "A framework gives you building blocks. A harness is a full runtime with opinionated defaults, and it often uses a framework underneath."

The harness is the software scaffolding around a model that turns a stateless model into an actor: tools, memory, sandbox, orchestration loop, and guardrails. This project already has three harnesses, one per worker SDK (each with its own defaults — see `docs/sources/adk-comparison.md`), plus the orchestrator's own harness (ADK). This document specifies the **five components every harness in this system must have**, regardless of which SDK it's built on, so that "lots of agents" doesn't mean "lots of inconsistent runtime behavior."

## 2. The five required components, per harness

### Component 1 — Orchestration loop

A ReAct-style reason → act → observe cycle: the model reasons about what to do, takes an action (usually a tool call), observes the result, and reasons again. Every harness in this system (ADK's `flows/llm_flows/`, OpenAI's `run_internal/run_loop.py`, Claude Agent SDK's `_internal/query.py`/`client.py` wrapping the CLI's own loop) already implements this — the requirement here is **explicit stopping conditions**, per Anthropic's own guidance (`02-agents-and-orchestration.md` §1): every autonomous-agent-mode loop must have a defined termination — max iterations, a success condition, a cost ceiling (`09-observability-audit-cost-and-ratelimiting.md` §2), or a human checkpoint. A loop without an explicit stop condition is not production-ready regardless of how good the prompt is.

### Component 2 — Tool execution

Intercepts model tool calls, executes them against real systems, returns structured observations. MCP (`03-tools-and-mcp.md`) is the standardization of exactly this layer. Requirement for this system: every tool execution passes through the same choke point that (a) enforces the ~25,000 token output cap, (b) attaches the tracing span (`09` §1), (c) is subject to the per-worker circuit breaker (`scaling-and-operations.md` §3b) — i.e., tool execution is never a bare function call bypassing these cross-cutting concerns, even for a worker's "internal" tools that never leave its own process.

### Component 3 — Memory / context management

Actively fights context degradation via compaction/caching rather than just appending indefinitely. ADK has this explicitly (`apps/compaction.py`, `flows/llm_flows/_content_compaction.py`); OpenAI's SDK has compaction sessions (`memory/openai_responses_compaction_session.py`); Claude Agent SDK manages this within the CLI harness it wraps. See `06-memory-state-and-storage.md` for the full memory architecture — this component is where that architecture actually executes, turn by turn.

### Component 4 — Sandboxing (the actual trust boundary)

> The sandbox is where the agent touches real files/shell/APIs/network — it is the trust boundary, not the orchestration loop.

This is the most consequential of the five for this project, because the Claude Agent SDK worker executes shell/file operations by design. See §3 below for the isolation tiers and this project's required tier per worker type.

### Component 5 — Guardrails / permissions

Tiered, **default-deny** escalation (read-only → workspace-write → full access), enforced via **deterministic hooks** at lifecycle checkpoints (before a tool call executes, before a file write) — enforced independent of the prompt, so a prompt injection in tool output cannot talk its way past a permission check. This is the load-bearing distinction: guardrails implemented as "instructions to the model" are not guardrails in this system's sense — they must be enforced in code, at a checkpoint the model cannot reason its way around. Concretely: ADK's `tools/tool_confirmation.py` and plugin hooks, OpenAI's `run_internal/approvals.py`, and Claude Agent SDK's hooks (`examples/hooks.py`, permission callbacks) are the mechanisms — the requirement is that **every worker's permission tier is declared in its Registry entry** (`scaling-and-operations.md` §1), so the orchestrator (and any human reviewing the system) can see each worker's maximum blast radius without reading its source code.

## 3. Sandboxing tiers — required mapping per worker type

Sources: [Northflank — How to sandbox AI agents](https://northflank.com/blog/how-to-sandbox-ai-agents), [Addo Zhang — AI Agent Code Execution Sandboxes: Containers to MicroVMs](https://addozhang.medium.com/ai-agent-code-execution-sandboxes-isolation-from-containers-to-microvms-e80848effea5).

**Isolation tiers, strongest to weakest** — multiple sources state containers alone are explicitly insufficient for executing untrusted/LLM-generated code, because a shared kernel is the actual risk (a container escape reaches the host kernel; a microVM escape does not):

| Tier | Mechanism | Isolation strength | Cold-start cost |
|---|---|---|---|
| **MicroVM** | Firecracker, Kata Containers | Strongest — separate kernel per sandbox, the only tier multiple sources call "production-safe" for untrusted/LLM-generated code | ~100–125ms cold boot; **5–30ms with snapshot-restore** (see below) |
| **gVisor** | User-space kernel syscall interception | Middle — intercepts and mediates syscalls without a full separate kernel | Lower than microVM, higher isolation cost than bare containers |
| **Hardened container** | Namespaces/cgroups + restricted capabilities | Weakest of the three — explicitly called insufficient alone for untrusted code execution | Lowest |

**Required mapping for this project's workers:**

| Worker | What it executes | Required tier |
|---|---|---|
| **Claude Agent SDK (coding/file/shell)** | Shell commands, file writes, potentially LLM-generated code — the highest-risk execution surface in this system | **MicroVM or equivalent**, not "its own container" alone. This is a hard requirement, not a nice-to-have, given the explicit "containers-only is a real gap" finding from research when arbitrary generated code execution is in scope. |
| **OpenAI Agents SDK (voice/realtime/hosted tools)** | Mostly API calls (search, hosted computer-use) rather than arbitrary local code execution | Hardened container is likely sufficient *if* it is not also given a code-execution tool; re-evaluate against the table above the moment it is. |
| **Any future worker that executes generated code** | — | Same rule as the coding worker: default to microVM-tier isolation, don't default to "a container" out of convenience. |

**Snapshot-restore, worth designing in now:** Firecracker's snapshot-restore (pause/resume with preserved memory + filesystem) resumes in 5–30ms versus ~100–125ms cold boot. Cited cost of *not* using this for a multi-turn stateful worker: 200–500ms wasted per turn re-initializing a full sandbox. **Direct implication for the Claude worker:** if a single conversation involves multiple tool-calling turns against the same working directory (the common case for "investigate and fix this bug"), design the sandbox lifecycle around snapshot-restore per session, not a fresh sandbox per tool call — this is both a cost and latency win, not just an optimization for later.

**Defense-in-depth is the stated production baseline, not isolation alone:** isolation boundary + resource limits (CPU/memory/disk caps) + network controls (default-deny egress, explicit allowlist for tools that need network) + permission scoping (Component 5 above) + monitoring, together. A strong sandbox with unrestricted network egress is still a real exposure (e.g., data exfiltration via an allowed outbound call) — the tiers above address *code* isolation, not network policy, which must be specified separately per worker in its Registry entry.

## 4. Per-worker harness specification template

Every worker onboarded into this system should have a harness spec answering these, stored alongside its Registry entry (`scaling-and-operations.md` §1):

- **Loop:** what triggers termination (max turns, cost ceiling, explicit success signal)?
- **Tool execution:** what's the worker's own internal tool surface, and does every tool call pass through the shared choke point (tracing, output cap, circuit breaker)?
- **Memory:** what compaction/context strategy does this worker's SDK use natively, and does it need project-level configuration (e.g., a compaction threshold) beyond the SDK default?
- **Sandbox tier:** per the table in §3 — declared explicitly, not assumed.
- **Permission tier and escalation path:** what can this worker do at its lowest tier, and what triggers escalation to a higher tier (if any)?
- **Network policy:** default-deny egress with an explicit allowlist, or full network access — and why.

## Sources

- [Endor Labs — What is an agent harness?](https://www.endorlabs.com/learn/what-is-an-agent-harness-the-software-that-turns-a-model-into-an-agent)
- [boringbot.substack — AI Agent Harnesses Explained](https://boringbot.substack.com/p/ai-agent-harnesses-explained-architecture)
- [Northflank — How to sandbox AI agents](https://northflank.com/blog/how-to-sandbox-ai-agents)
- [Addo Zhang — AI Agent Code Execution Sandboxes: Containers to MicroVMs](https://addozhang.medium.com/ai-agent-code-execution-sandboxes-isolation-from-containers-to-microvms-e80848effea5)
- [Zylos Research — AI Agent Sandbox & Execution Isolation](https://zylos.ai/research/2026-02-21-ai-agent-sandbox-execution-isolation/)
