# adk-python Reference Map

A navigation map for `docs/sources/adk-python` (a clone of [google/adk-python](https://github.com/google/adk-python)).
Read this first to find *where* something lives, instead of re-exploring the repo each time.
Full source of truth is still the actual code — this file only points you to it.

- Package root: `docs/sources/adk-python/src/google/adk/`
- Local dev guides (narrative docs, code examples): `docs/sources/adk-python/docs/guides/` — see the "Local Dev Guides" section below.
- Official hosted docs / llms.txt: `docs/sources/adk-python/llms.txt` points to https://adk.dev/ (this repo no longer vendors the full docs site).

## How to use this file

1. Find the concept/topic below (Agents, Tools, Sessions, etc.).
2. Go to the listed file(s) for the concrete implementation.
3. If a "Guide" is listed, read that first — it's narrative/example-driven and faster than reading source.

---

## Top-level entry points

| File | Purpose |
|---|---|
| `src/google/adk/runners.py` | `Runner` / `InMemoryRunner` — executes an agent against a session, yields `Event`s. Guide: `docs/guides/runners/runner/index.md`, `.../runner/live.md` |
| `src/google/adk/version.py` | Package version |
| `src/google/adk/__init__.py` | Public package exports |

## Core module map (`src/google/adk/<module>/`)

| Module | What it's for | Key files |
|---|---|---|
| `agents/` | Agent types & orchestration primitives | `llm_agent.py` (main LLM-driven agent), `base_agent.py`, `sequential_agent.py`, `parallel_agent.py`, `loop_agent.py`, `remote_a2a_agent.py` (call a remote A2A agent), `langgraph_agent.py`, `run_config.py`, `invocation_context.py`, `callback_context.py`. Guides: `docs/guides/agents/llm_agent/{single_turn,task}.md`, `.../managed_agent/index.md`, `.../remote_a2a_agent/task.md`, `.../live_request_queue/index.md` |
| `apps/` | `App` — top-level container binding a root agent + app-wide plugins/config | `app.py`, `compaction.py`. Guide: `docs/guides/apps/app/index.md` |
| `tools/` | All built-in tools + tool base classes (largest module) | `base_tool.py`, `function_tool.py`, `agent_tool.py` (use an agent as a tool), `mcp_tool/` (MCP client/server), `google_search_tool.py`, `bigquery/`, `spanner/`, `bigtable/`, `gcs/`, `pubsub/`, `computer_use/`, `environment/` (file/shell tools), `retrieval/`, `langchain_tool.py`, `crewai_tool.py`, `openapi_tool/`, `long_running_tool.py`, `exit_loop_tool.py`, `transfer_to_agent_tool.py`. Guide: `docs/guides/tools/mcp_tool/agent_to_mcp/index.md` |
| `sessions/` | Conversation session storage & state | `session.py`, `state.py`, `base_session_service.py`, `in_memory_session_service.py`, `database_session_service.py`, `sqlite_session_service.py`, `vertex_ai_session_service.py`. Guides: `docs/guides/sessions/session/index.md`, `.../state/index.md` |
| `memory/` | Long-term memory across sessions | `base_memory_service.py`, `in_memory_memory_service.py`, `vertex_ai_memory_bank_service.py`, `vertex_ai_rag_memory_service.py`. Guide: `docs/guides/memory/memory_service/index.md` |
| `models/` | LLM interface & provider integrations | `base_llm.py`, `registry.py` (name → implementation resolution), `google_llm.py` (Gemini), `anthropic_llm.py` (Claude), `lite_llm.py` (LiteLLM/many providers), `gemma_llm.py`, `apigee_llm.py`, `llm_request.py`, `llm_response.py`. Guide: `docs/guides/models/llm_registry/index.md` |
| `flows/llm_flows/` | The request/response pipeline an `LlmAgent` runs through (planning, tool calls, transfers, compaction, instructions) | `base_llm_flow.py`, `single_flow.py`, `auto_flow.py`, `functions.py` (tool call handling), `agent_transfer.py`, `instructions.py`, `contents.py`, `_nl_planning.py`, `_content_compaction.py` |
| `planners/` | Structured planning/thinking before tool use | `base_planner.py`, `built_in_planner.py`, `plan_re_act_planner.py`. Guide: `docs/guides/planners/planner/index.md` |
| `plugins/` | Cross-cutting hooks into the agent lifecycle | `base_plugin.py`, `plugin_manager.py`, `logging_plugin.py`, `reflect_retry_tool_plugin.py`, `_reflect_retry_model_plugin.py`, `debug_logging_plugin.py`, `save_files_as_artifacts_plugin.py`. Guides: `docs/guides/plugins/reflect_retry_model_plugin/index.md`, `.../reflect_retry_tool_plugin/index.md` |
| `events/` | The `Event` object streamed out of a `Runner` run + workflow node info | `event.py`, `event_actions.py`, `request_input.py` (human-in-the-loop). Guides: `docs/guides/events/event/index.md`, `.../request_input/index.md` |
| `artifacts/` | Binary payload storage (files, images, etc.) outside chat history | `base_artifact_service.py`, `in_memory_artifact_service.py`, `file_artifact_service.py`, `gcs_artifact_service.py`. Guide: `docs/guides/artifacts/artifact_service/index.md` |
| `auth/` | Tool/agent credential handling & OAuth | `auth_credential.py`, `auth_schemes.py`, `credential_manager.py`, `credential_service/`, `exchanger/`, `refresher/`. Guide: `docs/guides/auth/tool_auth/index.md` |
| `code_executors/` | Sandboxes for running model-generated code | `base_code_executor.py`, `unsafe_local_code_executor.py`, `container_code_executor.py`, `gke_code_executor.py`, `vertex_ai_code_executor.py`, `agent_engine_sandbox_code_executor.py`. Guide: `docs/guides/code_executors/code_executor/index.md` |
| `workflow/` | Graph-based orchestration (nodes/edges) as an alternative to agent hierarchies | `_workflow.py`, `_graph.py`, `_node.py`, `_function_node.py`, `_join_node.py`, `_parallel_worker.py`, `_retry_config.py`, `_dynamic_node_scheduler.py`. Guides: `docs/guides/workflow/workflow/index.md`, `.../graph/index.md`, `.../function_node/index.md`, `.../join_node/index.md`, `.../retry_config/index.md`, `.../parallel_worker/index.md`, `.../dynamic_nodes/index.md` |
| `evaluation/` | Agent eval harness: datasets, metrics, LLM-as-judge, simulation | `agent_evaluator.py`, `eval_case.py`, `eval_set.py`, `evaluator.py`, `metric_evaluator_registry.py`, `llm_as_judge.py`, `simulation/` (user simulators) |
| `a2a/` | Agent-to-Agent protocol support (expose/consume agents as A2A) | `agent/`, `executor/` (`a2a_agent_executor.py`), `converters/` (event/part conversion) |
| `cli/` | `adk` command-line tool + local web UI/API server | `cli.py`, `cli_create.py`, `cli_deploy.py`, `cli_eval.py`, `fast_api.py`, `adk_web_server.py`, `agent_loader.py` |
| `skills/` | Reusable "skill" definitions attachable to agents | `models.py`, `prompt.py`, `skill_registry.py` |
| `examples/` | Few-shot example providers for prompts | `base_example_provider.py`, `example.py`, `vertex_ai_example_store.py` |
| `telemetry/` | OpenTelemetry tracing/metrics instrumentation | `tracing.py`, `_metrics.py`, `_instrumentation.py`, `google_cloud.py` |
| `optimization/` | Automated prompt/agent optimization (GEPA) | `agent_optimizer.py`, `gepa_root_agent_optimizer.py`, `simple_prompt_optimizer.py` |
| `integrations/` | Third-party/cloud service integrations | `bigquery/`, `firestore/`, `redis/`, `slack/`, `crewai/`, `langchain/`, `eventarc/`, `cloud_run/`, `daytona/`, `e2b/`, `oci/`, `secret_manager/` |
| `labs/` | Experimental/incubating features | `antigravity/`, `openai/` (`_openai_llm.py`, `_openai_responses_llm.py`) |
| `environment/` | Sandboxed execution environment abstraction | `_base_environment.py`, `_local_environment.py` |
| `errors/` | Shared exception types | `not_found_error.py`, `already_exists_error.py`, `tool_execution_error.py`, `input_validation_error.py` |
| `platform/` | Small OS-level shims (time, uuid, threading, randomness) | `time.py`, `uuid.py`, `thread.py`, `_random.py` |
| `features/` | Internal feature-flag decorator/registry | `_feature_decorator.py`, `_feature_registry.py` |
| `dependencies/` | Optional/soft dependency shims | `vertexai.py`, `rouge_scorer.py` |
| `utils/` | Misc shared helpers (schema, YAML, env, content utils) | `yaml_utils.py`, `env_utils.py`, `content_utils.py`, `instructions_utils.py` |

## Local Dev Guides index (`docs/guides/README.md`)

The repo ships narrative guides under `docs/guides/<topic>/<name>/index.md`. Full current index lives in `docs/guides/README.md` — read that file directly since it may be updated with new guides after this reference was written. As of writing, it covers: Agents (LiveRequestQueue, LlmAgent single-turn/task, ManagedAgent, RemoteA2aAgent), Apps, Artifacts, Auth, Code Executors, Events (Event/NodeInfo, RequestInput), Memory, Models (LLM registry), Planners, Plugins (Reflect & Retry), Runners (incl. live streaming), Sessions (Session/state), Tools (agent-to-MCP), and Workflows (workflow, graph, function node, join node, retry config, parallel worker, dynamic nodes).

## Quick lookup: "I want to..."

| Task | Look at |
|---|---|
| Build a basic single-agent app | `agents/llm_agent.py`, `apps/app.py`, `runners.py` |
| Add a custom tool (Python function) | `tools/function_tool.py`, `tools/base_tool.py` |
| Let one agent call another as a tool | `tools/agent_tool.py` |
| Connect to an MCP server | `tools/mcp_tool/mcp_toolset.py`, `tools/mcp_tool/mcp_tool.py` |
| Expose an agent as an MCP server | `tools/mcp_tool/_agent_to_mcp.py`, guide `docs/guides/tools/mcp_tool/agent_to_mcp/index.md` |
| Multi-agent orchestration (sequential/parallel/loop) | `agents/sequential_agent.py`, `agents/parallel_agent.py`, `agents/loop_agent.py` |
| Graph-based orchestration instead of agent hierarchy | `workflow/_workflow.py`, `workflow/_graph.py`, guide `docs/guides/workflow/workflow/index.md` |
| Persist conversation state | `sessions/base_session_service.py` + a concrete impl (`in_memory_`, `database_`, `sqlite_`, `vertex_ai_`) |
| Cross-session memory / recall | `memory/base_memory_service.py` |
| Store files/images generated during a run | `artifacts/base_artifact_service.py` |
| Swap/add an LLM provider | `models/registry.py`, `models/base_llm.py` |
| Add retry/self-healing on tool or model failures | `plugins/reflect_retry_tool_plugin.py`, `plugins/_reflect_retry_model_plugin.py` |
| Human-in-the-loop / pause for input | `events/request_input.py`, `tools/get_user_choice_tool.py` |
| Sandbox code execution | `code_executors/` (pick backend: local/container/GKE/Vertex) |
| Auth a tool call (OAuth, API key) | `auth/auth_credential.py`, `auth/credential_manager.py`, guide `docs/guides/auth/tool_auth/index.md` |
| Evaluate agent quality | `evaluation/agent_evaluator.py`, `evaluation/eval_set.py` |
| Trace/observe agent runs | `telemetry/tracing.py` |
| Run the `adk` CLI or local web UI | `cli/cli.py`, `cli/fast_api.py`, `cli/adk_web_server.py` |

## Notes

- This is a **snapshot** — the clone can drift from upstream. If something referenced here isn't found, re-check the actual file (`grep`/`find` in `docs/sources/adk-python/src`) rather than trusting this map blindly, and update this file if the structure has changed.
- The single biggest module by file count is `tools/` (integrations for BigQuery, Spanner, Bigtable, GCS, Pub/Sub, computer use, MCP, etc.) — if a tool-related need isn't in the "Quick lookup" table, browse `src/google/adk/tools/` directly.
