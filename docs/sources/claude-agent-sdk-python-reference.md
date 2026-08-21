# claude-agent-sdk-python Reference Map

A navigation map for `docs/sources/claude-agent-sdk-python` (a clone of [anthropics/claude-agent-sdk-python](https://github.com/anthropics/claude-agent-sdk-python), Anthropic's official Python SDK for building agents on top of the Claude Code agent harness/CLI).
Read this first to find *where* something lives, instead of re-exploring the repo each time.

This repo is much smaller than google/adk-python or openai-agents-python — it's a thin, focused SDK. There is no separate `docs/` folder; **`README.md` is the primary documentation** (narrative + code samples for every feature), backed by the hosted docs at https://platform.claude.com (Agent SDK section). `examples/` has one runnable script per feature.

- Package root: `docs/sources/claude-agent-sdk-python/src/claude_agent_sdk/`
- Primary docs: `docs/sources/claude-agent-sdk-python/README.md`
- Runnable examples: `docs/sources/claude-agent-sdk-python/examples/`
- Changelog (useful for "what changed recently"): `docs/sources/claude-agent-sdk-python/CHANGELOG.md`

## How to use this file

1. Find the concept/topic below.
2. Jump to the matching `README.md` section (section names given) for narrative + code sample.
3. Go to the listed `src/claude_agent_sdk/` file for the implementation, or `examples/<file>.py` for a runnable end-to-end sample.

---

## Core module map (`src/claude_agent_sdk/`)

| File | What it's for |
|---|---|
| `__init__.py` | Public exports — start here to see the full surface area of the SDK |
| `query.py` | `query()` — one-shot, stateless function for a single prompt/response (simplest entry point). README: "Basic Usage: query()" |
| `client.py` | `ClaudeSDKClient` — stateful, multi-turn client (continues a conversation, supports streaming input, custom tools, hooks). README: "ClaudeSDKClient" |
| `types.py` | All public types: options (`ClaudeAgentOptions`), message types, tool/permission types. README: "Types" |
| `_errors.py` | SDK exception types. README: "Error Handling" |
| `_cli_version.py` | Manages/pins the bundled Claude Code CLI version the SDK shells out to |
| `_internal/client.py`, `_internal/query.py` | Internal implementation backing `client.py`/`query.py` |
| `_internal/transport/subprocess_cli.py` | Transport layer — spawns and talks to the underlying Claude Code CLI subprocess (this SDK is a wrapper around the CLI, not a from-scratch model client) |
| `_internal/sdk_mcp_bridge.py` | Bridges in-process Python tools (`@tool` decorator) into an SDK-hosted MCP server so Claude can call them. README: "Custom Tools (as In-Process SDK MCP Servers)" |
| `_internal/message_parser.py` | Parses CLI stdout stream into typed message objects |
| `_internal/session_store.py`, `session_import.py`, `session_mutations.py`, `session_resume.py`, `session_summary.py`, `sessions.py` | Session persistence: save/resume/import/summarize conversation sessions across process restarts. Pluggable store backends — see `examples/session_stores/` for Postgres/Redis/S3 implementations |
| `_internal/transcript_mirror_batcher.py` | Mirrors/batches transcript writes (for custom session stores) |
| `testing/session_store_conformance.py` | Conformance test suite to validate a custom session store implementation |

## README.md section map

| Section | Covers |
|---|---|
| Installation | `pip install claude-agent-sdk`, requires Claude Code CLI |
| Quick Start | Minimal `query()` example |
| Basic Usage: query() | One-shot querying, with/without options |
| — Using Tools | Enabling built-in Claude Code tools (Read, Write, Bash, etc.) via `allowed_tools` |
| — Working Directory | Setting `cwd` for file/bash tool operations |
| ClaudeSDKClient | Multi-turn stateful client |
| — Custom Tools (SDK MCP Servers) | `@tool` decorator + in-process MCP server, vs external MCP servers, migration guide, mixed server support |
| Hooks | Lifecycle hooks (e.g., pre/post tool use) with example |
| Types | Where to find all public types (`types.py`) |
| Error Handling | Exception hierarchy (`_errors.py`) and how to catch them |
| Available Tools | List of built-in tools exposed to the agent (same tool family as Claude Code) |
| Examples | Pointer to `examples/` directory |
| Migrating from Claude Code SDK | This package's predecessor was called "claude-code-sdk" — rename/migration notes |
| Development / Building Wheels / Release Workflow | Maintainer-facing, not user-facing API docs |

## `examples/` quick index

| File | Demonstrates |
|---|---|
| `quick_start.py` | Minimal working example |
| `agents.py` | Defining/using agents |
| `filesystem_agents.py` | Agent with file system access |
| `tools_option.py`, `tool_permission_callback.py` | Controlling which tools are available / permission callbacks |
| `mcp_calculator.py` | Custom in-process SDK MCP tool example |
| `hooks.py` | Lifecycle hooks |
| `streaming_mode.py`, `streaming_mode_ipython.py`, `streaming_mode_trio.py` | Streaming responses (incl. under IPython / trio event loops) |
| `include_partial_messages.py` | Getting partial/incremental message updates |
| `system_prompt.py` | Customizing the system prompt |
| `setting_sources.py` | Where settings/config are loaded from |
| `max_budget_usd.py` | Capping spend per run |
| `stderr_callback_example.py` | Capturing CLI stderr |
| `plugin_example.py` + `plugins/demo-plugin/` | Claude Code plugin integration |
| `session_stores/` | Custom session store backends: `postgres_session_store.py`, `redis_session_store.py`, `s3_session_store.py` |

## Quick lookup: "I want to..."

| Task | Look at |
|---|---|
| Send one prompt and get a response | `query.py`, README "Basic Usage: query()", `examples/quick_start.py` |
| Have a multi-turn conversation | `client.py` (`ClaudeSDKClient`), README "ClaudeSDKClient" |
| Let the agent read/write files or run shell commands | README "Using Tools" / "Available Tools", `examples/filesystem_agents.py` |
| Add a custom Python-function tool | `@tool` decorator (see `__init__.py` exports), README "Custom Tools", `examples/mcp_calculator.py` |
| Connect an external MCP server instead | README "Custom Tools" → "Mixed Server Support" |
| Hook into tool-use lifecycle (approve/log/modify) | README "Hooks", `examples/hooks.py` |
| Control which tools are allowed | `types.py` (`allowed_tools`), `examples/tools_option.py`, `tool_permission_callback.py` |
| Stream partial output | `examples/streaming_mode.py`, `include_partial_messages.py` |
| Persist/resume sessions across restarts | `_internal/session_store.py`, `session_resume.py`, `examples/session_stores/` |
| Cap cost of a run | `examples/max_budget_usd.py` |
| Handle SDK errors | `_errors.py`, README "Error Handling" |
| Understand what changed in a recent version | `CHANGELOG.md` |

## Notes

- This is a **snapshot** — the clone can drift from upstream. Re-verify against `src/` and `README.md` directly if something referenced here isn't found.
- This SDK **shells out to the Claude Code CLI** (bundled/downloaded, see `_cli_version.py`, `scripts/download_cli.py`) rather than calling the Claude API directly — it's an SDK over the *agent harness*, not a raw model client. If you need direct Messages-API access without the Claude Code tool harness, that's the plain `anthropic` Python SDK (a different package), not this one.
- Package import name: `claude_agent_sdk` (underscore), PyPI/repo name: `claude-agent-sdk-python` (hyphen).
