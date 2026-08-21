# openai-agents-python Reference Map

A navigation map for `docs/sources/openai-agents-python` (a clone of [openai/openai-agents-python](https://github.com/openai/openai-agents-python), OpenAI's official Python Agents SDK — successor to "Swarm").
Read this first to find *where* something lives, instead of re-exploring the repo each time.
Full source of truth is still the actual code/docs — this file only points you to it.

- Package root: `docs/sources/openai-agents-python/src/agents/`
- Narrative docs (English): `docs/sources/openai-agents-python/docs/*.md` — also published at https://openai.github.io/openai-agents-python
- Full machine-readable docs dump: `docs/sources/openai-agents-python/docs/llms.txt` and `llms-full.txt`
- API reference (mirrors source, one page per module): `docs/sources/openai-agents-python/docs/ref/`
- Localized docs also exist under `docs/ja/`, `docs/ko/`, `docs/zh/` — ignore unless translation is relevant.

## How to use this file

1. Find the concept/topic below.
2. Go to the listed file(s) in `src/agents/` for the implementation, and/or the matching `docs/*.md` guide for narrative explanation + examples.
3. `docs/ref/<name>.md` is a thin auto-generated API reference page for `src/agents/<name>.py` — read the guide first, the ref page only if you need exact signatures.

---

## Core module map (`src/agents/`)

| File/Dir | What it's for | Guide |
|---|---|---|
| `agent.py`, `_public_agent.py` | `Agent` — the core primitive: instructions, tools, handoffs, model, output type | `docs/agents.md` |
| `run.py`, `run_config.py`, `run_context.py`, `run_state.py` | `Runner.run(...)` — executes an agent loop; `RunConfig`, per-run context, resumable run state | `docs/running_agents.md`, `docs/context.md`, `docs/ref/run_state.md` |
| `run_internal/` | Internal engine: turn loop, tool execution/planning, guardrail enforcement, streaming, session persistence — read only if debugging core loop behavior | `run_loop.py`, `turn_preparation.py`, `tool_execution.py`, `guardrails.py`, `streaming.py`, `session_persistence.py` |
| `result.py`, `items.py`, `stream_events.py` | Run output: `RunResult`, run items (messages/tool calls), streamed event types | `docs/results.md`, `docs/streaming.md` |
| `tool.py`, `tool_context.py`, `decorators.py`, `function_schema.py` | Defining tools: `@function_tool`, hosted tools (web search, code interpreter, computer use), tool call context, auto schema generation from Python function signatures | `docs/tools.md` |
| `tool_guardrails.py`, `guardrail.py` | Input/output/tool guardrails (validation, safety checks) that can halt a run | `docs/guardrails.md` |
| `handoffs/`, `handoff_filters.py` (in `extensions/`) | Agent-to-agent handoff/delegation mechanism | `docs/handoffs.md` |
| `agent_output.py`, `strict_schema.py` | Structured output types + strict JSON schema enforcement | — |
| `model_settings.py`, `models/` | Model config (temperature, etc.) and provider implementations: `openai_provider.py`, `openai_chatcompletions.py`, `openai_responses.py`, `multi_provider.py`, `default_models.py` | `docs/models/index.md`, `docs/models/litellm.md` |
| `extensions/models/` | Non-OpenAI model providers via `any-llm` and LiteLLM | `docs/models/litellm.md` |
| `mcp/` | Model Context Protocol client support — connect agents to MCP servers | `docs/mcp.md`, `manager.py`, `server.py` |
| `memory/` (core) + `extensions/memory/` | Session/conversation memory. Core: `session.py`, `sqlite_session.py`, `openai_conversations_session.py`. Extensions: `redis_session.py`, `sqlalchemy_session.py`, `mongodb_session.py`, `dapr_session.py`, `encrypt_session.py`, `advanced_sqlite_session.py`, `async_sqlite_session.py` | `docs/sessions/index.md`, `docs/sessions/sqlalchemy_session.md`, `docs/sessions/encrypted_session.md`, `docs/sessions/advanced_sqlite_session.md` |
| `sandbox/` + `extensions/sandbox/` | Sandboxed code/tool execution environment (files, shell, snapshots, manifests, Docker/unix-local backends) | `docs/sandbox/guide.md`, `docs/sandbox/clients.md`, `docs/sandbox_agents.md` |
| `sandbox/capabilities/` | Sandbox capability plugins: filesystem, shell, memory, compaction, skills | — |
| `sandbox/memory/` | Sandbox-specific long-running memory (rollouts, phase-based summarization) | `docs/sandbox/memory.md` |
| `computer.py`, `apply_diff.py`, `editor.py` | Computer-use tool + file-editing/diff-apply primitives | `docs/ref/computer.md`, `docs/ref/apply_diff.md`, `docs/ref/editor.md` |
| `realtime/` | Realtime voice/text agent runner (WebSocket-based, low-latency) | `docs/realtime/quickstart.md`, `docs/realtime/guide.md`, `docs/realtime/transport.md` |
| `voice/` + `voice/models/` | Voice pipeline (STT → agent → TTS), OpenAI STT/TTS model wrappers | `docs/voice/quickstart.md`, `docs/voice/pipeline.md`, `docs/voice/tracing.md` |
| `tracing/` | Built-in tracing (spans, traces, processors) for observability/debugging | `docs/tracing.md` |
| `testing/` | Test helpers/fakes for agents and models | `docs/testing.md` |
| `repl.py` | Interactive REPL for quickly chatting with an agent | `docs/repl.md` |
| `usage.py` | Token usage tracking | `docs/usage.md` |
| `prompts.py` | Prompt template helpers | `docs/ref/prompts.md` |
| `exceptions.py`, `retry.py` | Error types; retry policy for model calls | `docs/ref/exceptions.md`, `docs/ref/retry.md` |
| `extensions/visualization.py` | Generate a graph visualization of an agent + its handoffs/tools | `docs/visualization.md` |
| `util/` | Internal helpers (json, async tasks, error tracing, pretty print) — rarely needed directly | — |

## Docs directory quick index (`docs/*.md`)

Top-level narrative guides (English): `index.md` (overview), `quickstart.md`, `agents.md`, `running_agents.md`, `results.md`, `streaming.md`, `tools.md`, `mcp.md`, `handoffs.md`, `multi_agent.md`, `context.md`, `guardrails.md`, `human_in_the_loop.md`, `sessions/index.md`, `models/index.md`, `models/litellm.md`, `realtime/*`, `voice/*`, `sandbox/*`, `sandbox_agents.md`, `tracing.md`, `visualization.md`, `testing.md`, `repl.md`, `usage.md`, `config.md`, `examples.md`, `release.md`.

`docs/ref/` mirrors most `src/agents/*.py` files 1:1 as thin API-reference pages (auto-generated by `docs/scripts/generate_ref_files.py`) — use these for exact signatures once you already understand the concept from the guide.

## Quick lookup: "I want to..."

| Task | Look at |
|---|---|
| Define a basic agent | `src/agents/agent.py`, guide `docs/agents.md` |
| Run an agent and get the result | `src/agents/run.py`, guide `docs/running_agents.md` |
| Add a custom tool from a Python function | `src/agents/decorators.py` (`@function_tool`), `docs/tools.md` |
| Let one agent delegate to another | `src/agents/handoffs/`, `docs/handoffs.md` |
| Connect to an MCP server | `src/agents/mcp/`, `docs/mcp.md` |
| Add safety checks / block bad input-output | `src/agents/guardrail.py`, `src/agents/tool_guardrails.py`, `docs/guardrails.md` |
| Persist conversation across turns | `src/agents/memory/session.py` + a backend (`sqlite_session.py`, `extensions/memory/redis_session.py`, etc.), `docs/sessions/index.md` |
| Use a non-OpenAI model (Claude, local, etc.) | `src/agents/extensions/models/litellm_model.py`, `docs/models/litellm.md` |
| Stream events as the agent runs | `src/agents/stream_events.py`, `docs/streaming.md` |
| Sandbox/execute code or shell commands safely | `src/agents/sandbox/`, `docs/sandbox/guide.md`, `docs/sandbox_agents.md` |
| Build a voice agent | `src/agents/voice/`, `docs/voice/quickstart.md` |
| Build a low-latency realtime agent | `src/agents/realtime/`, `docs/realtime/quickstart.md` |
| Add tracing/observability | `src/agents/tracing/`, `docs/tracing.md` |
| Visualize an agent graph (tools/handoffs) | `src/agents/extensions/visualization.py`, `docs/visualization.md` |
| Human-in-the-loop approval before a tool runs | `docs/human_in_the_loop.md`, `src/agents/run_internal/approvals.py` |
| Migrate from the old `Swarm` framework | `docs/index.md` (mentions lineage); this SDK is the official successor |

## Notes

- This is a **snapshot** — the clone can drift from upstream. Re-verify against `src/` directly if something referenced here isn't found, and update this file if the structure changes.
- The package import name is `agents` (i.e. `from agents import Agent, Runner`), even though the repo/PyPI name is `openai-agents`.
- `run_internal/` and files prefixed with `_` are private implementation details — prefer the public re-exports in `src/agents/__init__.py` when writing code against this SDK.
