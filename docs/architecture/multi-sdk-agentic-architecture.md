# Multi-SDK Agentic Architecture

**Status:** Proposed design
**Related references:** `docs/sources/adk-python-reference.md`, `docs/sources/openai-agents-python-reference.md`, `docs/sources/claude-agent-sdk-python-reference.md`, `docs/sources/adk-comparison.md`

## 1. Goal

Build one agentic system that gets the best of all three vendored SDKs instead of committing to a single one, by giving each SDK the role it's actually strongest at rather than treating them as three competing, interchangeable frameworks.

## 2. Decision: Orchestrator + Specialist Workers, glued by MCP

**Pattern:** One orchestrator agent owns planning, sequencing, state, and evaluation. It delegates well-scoped subtasks to specialist worker agents, each exposed as an **MCP server** and called as a tool.

```
                        ┌─────────────────────────────┐
                        │   Google ADK Orchestrator    │
                        │  (root LlmAgent / workflow)  │
                        │  - session/state management │
                        │  - task planning & routing  │
                        │  - evaluation & telemetry    │
                        └───────────────┬─────────────┘
                                        │  MCP tool calls
                    ┌───────────────────┼───────────────────┐
                    │                   │                   │
        ┌───────────▼──────────┐ ┌──────▼───────────┐ ┌─────▼─────────────┐
        │ Claude Agent SDK      │ │ OpenAI Agents SDK │ │ (future workers)  │
        │ worker (MCP server)   │ │ worker (MCP server)│ │ same pattern      │
        │ - coding/file/shell   │ │ - voice/realtime   │ │                    │
        │   heavy subtasks      │ │ - OpenAI-hosted     │ │                    │
        │                       │ │   tools (web search,│ │                    │
        │                       │ │   computer use)     │ │                    │
        └───────────────────────┘ └────────────────────┘ └────────────────────┘
```

### Why this shape, not peer-to-peer (A2A)

A2A is designed for independently-owned agents across organizational/system boundaries calling each other as equals. This system has one owner (one team, one product), so that boundary doesn't exist yet — A2A would add protocol overhead (agent cards, executors, task result aggregation) with no matching need. MCP-as-tool is simpler, and all three SDKs already speak it natively (as MCP clients; ADK and Claude Agent SDK can also run as MCP servers). Revisit A2A only if/when a worker becomes an independently-owned service outside this team's control — see [Section 7](#7-when-to-revisit-this-decision).

### Why ADK as the orchestrator, not OpenAI's or Claude's SDK

Of the three, only Google ADK has the actual "orchestration" primitives: multi-agent sequencing (`SequentialAgent`/`ParallelAgent`/`LoopAgent`), a graph-based workflow engine, a session/state service with formal scoping (`app:`/`user:`/`session:`/`temp:`), and a built-in evaluation framework. OpenAI's SDK has handoffs but no graph/eval layer; Claude's SDK has no multi-agent concept at all — it's explicitly a wrapper around a single agent loop. Full capability breakdown: `docs/sources/adk-comparison.md`.

## 3. Role assignment

| Role | SDK | Why |
|---|---|---|
| **Orchestrator** | Google ADK | Only SDK with multi-agent hierarchy, workflow graph, session/state scoping, and eval framework. Owns the "brain" of the system. |
| **Coding / file / shell worker** | Claude Agent SDK | Purpose-built wrapper around the Claude Code agent loop — best-in-class for "read this codebase, edit files, run commands" tasks. Don't reinvent this tool harness in ADK or OpenAI's SDK. |
| **Voice / realtime / OpenAI-hosted-tools worker** | OpenAI Agents SDK | Only SDK of the three with a dedicated realtime/voice pipeline and OpenAI's hosted tools (web search, computer use, its own sandbox). |
| **Future specialist workers** | Any SDK, or plain code | Same pattern: wrap it as an MCP server, expose a narrow tool surface, let the orchestrator route to it. |

## 4. State & session ownership

Single source of truth for conversation/session state lives in **ADK's session service** (`sessions/base_session_service.py` — pick a concrete backend: in-memory for dev, database/SQLite/Vertex AI for production). Worker agents (Claude, OpenAI) should be treated as **stateless per invocation** from the orchestrator's point of view:

- The orchestrator passes the worker only the context it needs for that specific subtask (not the full conversation history).
- Worker-side session/memory features (Claude Agent SDK's pluggable session stores, OpenAI's `memory/session.py` backends) are used only if a worker needs multi-turn continuity *within its own subtask* (e.g., a multi-step coding session) — not as the system's overall memory.
- This avoids three separate, potentially inconsistent copies of "what has happened in this conversation."

## 5. Tool & credential boundaries

Each worker's MCP server should expose the **narrowest tool surface needed for its role**, not the SDK's full built-in tool set:

- Claude worker: scope to a specific working directory (`cwd`) and `allowed_tools` (e.g. Read/Write/Edit/Bash), per `docs/sources/claude-agent-sdk-python-reference.md` → "Using Tools".
- OpenAI worker: scope to only the hosted tools its role needs (e.g. web search, or computer use) via `model_settings`/tool config, per `docs/sources/openai-agents-python-reference.md` → "Tools & integrations".
- Credentials for each worker (API keys, OAuth) stay local to that worker's process/config — the orchestrator never needs a worker's model API key, only the MCP connection details.

## 6. Observability

ADK's telemetry (`telemetry/tracing.py`, OpenTelemetry-based) should be the top-level trace collector. Each MCP tool call to a worker becomes a span in that trace. Workers' own tracing (OpenAI Agents SDK has a built-in tracing module) can stay enabled for local debugging of that worker, but isn't the system-wide source of truth — avoid needing to stitch together three separate tracing UIs to debug one user request.

## 7. When to revisit this decision

Reconsider the MCP-as-tool approach in favor of A2A peer-to-peer if:

- A worker becomes an **independently-owned service** (separate team, separate deploy lifecycle, possibly separate company) that needs to be called as an equal rather than a tool you control.
- You need **bidirectional handoffs** where a worker itself needs to delegate back up to the orchestrator or across to another worker directly, rather than always reporting back to one root.
- You outgrow a single orchestrator and need multiple orchestrators coordinating with each other.

Reconsider the SDK-to-role assignment if:

- A single SDK is later chosen as the long-term standard for the whole org (reduces operational complexity of running three SDKs' dependency trees/runtimes), in which case revisit whether ADK alone (given its broadest built-in tool/integration set) can absorb the worker roles instead of delegating out.

## 8. Scaling & operations

The questions below turned out to matter a lot once "many agents/MCP servers" is the actual target, so they've been split into their own deep-dive rather than left as open bullets here: **`docs/architecture/scaling-and-operations.md`**. It covers, with concrete decisions:

- Deployment model for workers (independent deployable MCP servers, not in-process)
- Failure handling (per-call retry, per-worker circuit breaking, propagated timeout budgets)
- Multi-tenancy (tenant ID threaded through session state, per-call context, credentials, sandboxes, and registry lookups)
- Discovery at scale (a Registry layer, modeled on ADK's own agent/API/skill registry pattern)
- Versioning of worker tool contracts
- Cost & quota control

Read that document before implementing anything beyond a first proof-of-concept with one or two hand-wired workers — the design above (Section 2) is deliberately simple and will need the patterns in that document layered on before it holds up at real scale.

## 9. Still genuinely open

- Which capabilities need a fallback worker vs. an honest failure — a product/risk call, not an architecture one (see scaling doc §9).
- Tenant count and compliance constraints — needed to finalize request-level vs. process-level tenant isolation (see scaling doc §4).
- Where the registry service itself should live (see scaling doc §9).
