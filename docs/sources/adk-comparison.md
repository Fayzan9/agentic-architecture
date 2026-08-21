# ADK / Agent SDK Comparison

A detailed, feature-by-feature comparison of the three agent SDKs vendored under `docs/sources/`. Rows are ordered with the **most important/decision-driving features first**, tapering to more niche capabilities. Each cell points to the actual module/file backing that capability, so this doubles as a cross-SDK lookup — pair it with the individual `*-reference.md` files for deeper navigation within one SDK.

| SDK | Source | Reference map |
|---|---|---|
| **Google ADK** | `docs/sources/adk-python` ([google/adk-python](https://github.com/google/adk-python)) | `docs/sources/adk-python-reference.md` |
| **OpenAI Agents SDK** | `docs/sources/openai-agents-python` ([openai/openai-agents-python](https://github.com/openai/openai-agents-python)) | `docs/sources/openai-agents-python-reference.md` |
| **Claude Agent SDK** | `docs/sources/claude-agent-sdk-python` ([anthropics/claude-agent-sdk-python](https://github.com/anthropics/claude-agent-sdk-python)) | `docs/sources/claude-agent-sdk-python-reference.md` |

---

## 1. Core identity & architecture

| Aspect | Google ADK | OpenAI Agents SDK | Claude Agent SDK |
|---|---|---|---|
| **What it fundamentally is** | A full agent *platform*: agents + orchestration + eval + telemetry + CLI, as a native Python framework | A full agent *SDK*: agents + tools + memory + sandbox + voice, as a native Python framework | A thin Python *wrapper* around the Claude Code CLI/agent harness (shells out to a subprocess) |
| **Scale (file count, rough)** | ~680 files — largest, most surface area | ~150+ files — medium, full-featured but leaner | ~25 files — smallest, focused |
| **Core primitive** | `LlmAgent` (+ `BaseAgent` hierarchy) — `agents/llm_agent.py` | `Agent` — `src/agents/agent.py` | No "Agent" object exposed directly — `query()` (one-shot) or `ClaudeSDKClient` (multi-turn) — `src/claude_agent_sdk/query.py`, `client.py` |
| **Execution entry point** | `Runner` / `InMemoryRunner` — `runners.py` | `Runner.run(...)` — `src/agents/run.py` | `query()` / `ClaudeSDKClient.query()` |
| **Underlying model access** | Direct model API calls (Gemini, Claude, etc. via `models/`) | Direct model API calls (OpenAI native, others via LiteLLM/any-llm) | Indirect — goes through the bundled Claude Code CLI, not a raw Messages API call |
| **Language/package name** | `google-adk` → import `google.adk` | `openai-agents` → import `agents` | `claude-agent-sdk` → import `claude_agent_sdk` |
| **Maintainer** | Google | OpenAI (official, successor to "Swarm") | Anthropic (official) |

## 2. Multi-agent orchestration

| Aspect | Google ADK | OpenAI Agents SDK | Claude Agent SDK |
|---|---|---|---|
| **Multi-agent composition** | First-class: `SequentialAgent`, `ParallelAgent`, `LoopAgent` — `agents/sequential_agent.py`, `parallel_agent.py`, `loop_agent.py` | Via **handoffs** — one agent delegates the conversation to another — `src/agents/handoffs/` | Not built in — the SDK drives one agent/session at a time; you'd compose multiple agents yourself at the application layer |
| **Graph-based workflow engine** | Yes — dedicated `workflow/` module: nodes, edges, join nodes, dynamic node scheduling, retry policies — `workflow/_workflow.py`, `_graph.py`, `_join_node.py` | No dedicated graph engine (handoffs are simpler point-to-point) | No |
| **Agent-to-agent protocol (A2A)** | Yes — full `a2a/` module to expose/consume agents over the A2A protocol, incl. `RemoteA2aAgent` | No | No |
| **Agent-as-tool** | Yes — `tools/agent_tool.py` | Yes — agents can be wrapped as tools | Not applicable (no agent abstraction to wrap) |
| **Remote/distributed agents** | Yes — `agents/remote_a2a_agent.py` | No native remote-agent concept | No |

## 3. Tools & integrations

| Aspect | Google ADK | OpenAI Agents SDK | Claude Agent SDK |
|---|---|---|---|
| **Custom function tools** | `@tool` style via `tools/function_tool.py` | `@function_tool` decorator — `src/agents/decorators.py` | `@tool` decorator, exposed via in-process SDK MCP server |
| **Auto schema generation from Python functions** | Yes | Yes — `src/agents/function_schema.py` | Yes (via MCP tool schema) |
| **Built-in/hosted tools** | Extensive first-party integrations: BigQuery, Spanner, Bigtable, GCS, Pub/Sub, Slack, computer use, retrieval (RAG/Vertex/LlamaIndex), OpenAPI, Application Integration — `tools/` (largest module in the repo) | Moderate hosted set: web search, code interpreter, computer use — `computer.py`, plus `apply_diff.py`/`editor.py` for file edits | Inherits the **entire Claude Code tool family** (Read, Write, Edit, Bash, Grep, Glob, WebFetch, etc.) since it wraps the CLI |
| **Third-party framework interop** | LangChain, CrewAI tool wrappers — `tools/langchain_tool.py`, `crewai_tool.py` | Not built in | Not applicable |
| **MCP client support** | Yes — `tools/mcp_tool/mcp_toolset.py` | Yes — `src/agents/mcp/` | Yes — external MCP servers supported, plus in-process bridging |
| **Expose agent AS an MCP server** | Yes — `tools/mcp_tool/_agent_to_mcp.py` | No | Yes — in-process SDK MCP servers (`_internal/sdk_mcp_bridge.py`) |
| **Tool permission / confirmation controls** | Yes — `tools/tool_confirmation.py` | Yes — approvals in run loop (`run_internal/approvals.py`) | Yes — `allowed_tools`, permission callbacks, hooks |

## 4. Memory & state

| Aspect | Google ADK | OpenAI Agents SDK | Claude Agent SDK |
|---|---|---|---|
| **Short-term session/conversation state** | Yes — `sessions/`: in-memory, database, SQLite, Vertex AI backends | Yes — `memory/session.py` + backends: SQLite, Redis, SQLAlchemy, MongoDB, Dapr, encrypted sessions | Yes — pluggable session stores; example backends for Postgres, Redis, S3 in `examples/session_stores/` |
| **Long-term / cross-session memory** | Yes — dedicated `memory/` service, incl. Vertex AI Memory Bank and Vertex AI RAG memory — `memory/vertex_ai_memory_bank_service.py` | Partial — sessions can persist, but no dedicated "recall across sessions" memory service | No dedicated long-term memory service |
| **State scoping (app/user/session/temp)** | Yes — explicit `app:`, `user:`, `temp:` prefixes — `sessions/state.py` | Implicit via run context, no formal scoping prefixes | No formal scoping system |
| **Artifact storage (files/binaries)** | Yes — dedicated `artifacts/` service (in-memory, file, GCS) | Not a separate service | Handled via filesystem tools directly (no artifact-versioning service) |
| **Session resume across process restarts** | Yes | Yes | Yes — explicit resume/import/summary support (`_internal/session_resume.py`, `session_summary.py`) |

## 5. Safety, control & human oversight

| Aspect | Google ADK | OpenAI Agents SDK | Claude Agent SDK |
|---|---|---|---|
| **Guardrails (input/output validation)** | Via the plugin system (custom plugins) | First-class, dedicated concept — `src/agents/guardrail.py`, `tool_guardrails.py` | Via hooks and permission callbacks, not a dedicated "guardrail" concept |
| **Human-in-the-loop / pause for approval** | Yes — `events/request_input.py`, `tools/get_user_choice_tool.py` | Yes — approval flow in the run loop | Yes — hooks (`examples/hooks.py`) |
| **Retry / self-healing on failure** | Yes — dedicated plugins: `reflect_retry_tool_plugin.py`, `_reflect_retry_model_plugin.py` | Yes — `src/agents/retry.py`, model retry runtime | Relies on underlying CLI behavior; no dedicated reflect-and-retry plugin |
| **Cost/budget capping** | Not a dedicated feature | Via usage tracking (`usage.py`) | Yes — explicit budget cap example (`examples/max_budget_usd.py`) |
| **Auth / credential management for tools** | Yes — full `auth/` module: OAuth schemes, credential exchangers/refreshers | Basic, tool-level | Inherits Claude Code's auth model |

## 6. Sandboxing & code execution

| Aspect | Google ADK | OpenAI Agents SDK | Claude Agent SDK |
|---|---|---|---|
| **Sandboxed code execution** | Yes — multiple backends: local (unsafe), container, GKE, Vertex AI, Agent Engine sandbox — `code_executors/` | Yes — Docker and unix-local sandboxes with capability plugins (filesystem, shell, skills, compaction) — `src/agents/sandbox/` | Inherits Claude Code's own execution environment (Bash tool, etc.) — no separate sandbox abstraction in this SDK |
| **Filesystem/shell tool sandboxing** | Via code executor backends | Yes — `sandbox/capabilities/filesystem.py`, `shell.py` | Yes — via Claude Code's native tools, working-directory scoping |

## 7. Models & providers

| Aspect | Google ADK | OpenAI Agents SDK | Claude Agent SDK |
|---|---|---|---|
| **Native model support** | Gemini (`google_llm.py`), Claude (`anthropic_llm.py`), Gemma, Apigee | OpenAI (Chat Completions + Responses API) | Claude only (by design) |
| **Multi-provider support** | Yes — `models/lite_llm.py` (LiteLLM = many providers), plus OpenAI-family (labs) | Yes — `extensions/models/litellm_model.py`, `any_llm_model.py` | No — single-provider SDK |
| **Model registry / resolution** | Yes — `models/registry.py` resolves a model name string to an implementation | Yes — `models/multi_provider.py`, `default_models.py` | Not applicable |

## 8. Observability, evaluation & optimization

| Aspect | Google ADK | OpenAI Agents SDK | Claude Agent SDK |
|---|---|---|---|
| **Tracing/telemetry** | Yes — OpenTelemetry-based, incl. Google Cloud exporter — `telemetry/` | Yes — built-in tracing with pluggable processors — `src/agents/tracing/` | No dedicated tracing module (relies on CLI/host-level logging, stderr callback) |
| **Evaluation framework** | Yes — extensive: eval sets, metrics registry, LLM-as-judge, rubric-based evaluators, user simulation — `evaluation/` | Basic — `testing/` provides fakes/helpers, no formal eval-metrics suite | No |
| **Automated prompt/agent optimization** | Yes — GEPA-based optimizers — `optimization/` | No | No |
| **Visualization** | Yes — `cli/agent_graph.py`, graph visualization utilities | Yes — `extensions/visualization.py` (agent/tool/handoff graph) | No |

## 9. Voice & realtime

| Aspect | Google ADK | OpenAI Agents SDK | Claude Agent SDK |
|---|---|---|---|
| **Realtime streaming (low-latency)** | Yes — `LiveRequestQueue`, live streaming runner support | Yes — dedicated `realtime/` module (WebSocket-based) | Yes — streaming mode for responses (`examples/streaming_mode.py`), but text-based, not voice |
| **Voice pipeline (STT → agent → TTS)** | Not a first-class module | Yes — dedicated `voice/` module with OpenAI STT/TTS wrappers | No |

## 10. Developer experience & tooling

| Aspect | Google ADK | OpenAI Agents SDK | Claude Agent SDK |
|---|---|---|---|
| **CLI** | Yes — full `adk` CLI: create, deploy, eval, local web UI/API server — `cli/` | No dedicated CLI; has an interactive REPL (`repl.py`) | No dedicated CLI (bundles/manages the *Claude Code* CLI internally as its transport) |
| **Local web UI for testing agents** | Yes — `cli/adk_web_server.py`, `fast_api.py` | No | No |
| **Config-driven agent definition (YAML, etc.)** | Yes — `agent_config.py`, `llm_agent_config.py` and per-agent-type configs | Not a primary pattern (code-first) | Not a primary pattern (code-first) |
| **Testing helpers** | Yes, via `evaluation/` and CLI test runner | Yes — `src/agents/testing/` | Yes — `testing/session_store_conformance.py` for custom store validation |
| **Documented example count** | Fewer standalone examples; guides live in `docs/guides/` | Large — `examples/` directory in the main repo (not in this narrower clone's guide docs, but referenced) | Large — one example script per feature in `examples/` |

## Summary: best-fit scenarios

| If you need to... | Best fit |
|---|---|
| Build a large-scale, multi-agent platform with built-in eval, telemetry, and graph orchestration | **Google ADK** |
| Ship a production agent app with solid tools, memory, guardrails, and optional voice/realtime | **OpenAI Agents SDK** |
| Quickly wrap Claude Code's coding/file/shell agent behavior into your own app | **Claude Agent SDK** |
| Need multi-provider model flexibility (Gemini/Claude/OpenAI/local) | **Google ADK** or **OpenAI Agents SDK** (both support LiteLLM-style multi-provider) |
| Need formal agent evaluation (metrics, LLM-as-judge, simulated users) | **Google ADK** (most mature eval suite) |
| Need a built-in local dev web UI to poke at agents | **Google ADK** (only one with this) |

## Notes

- This is a **snapshot** based on the vendored clones under `docs/sources/` at the time this file was written. All three SDKs move fast — re-verify against the actual source/reference maps before relying on a specific capability claim, and update this file if something has changed.
- "Not built in" / "No" does not mean impossible — it means the capability isn't a first-party module in that SDK; it can usually still be built at the application layer.
