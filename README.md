# Agentic Architecture

Design and reference documentation for a multi-SDK, scalable agentic system: a Google ADK orchestrator delegating to specialist worker agents (Claude Agent SDK, OpenAI Agents SDK) glued together by MCP.

This repository is a **design/documentation repo** — it doesn't contain application code yet. It exists to think through the architecture, methodology, and guardrails carefully before implementation starts.

## Getting started

After cloning, fetch the vendored SDK source repos referenced throughout these docs:

```bash
./scripts/fetch-docs.sh
```

See `docs/sources/README.md` for details — those SDK clones are intentionally not committed to this repo, so you always get the actual current upstream source rather than a stale copy.

## Layout

```
CLAUDE.md                        — entry point: what to read before working on this project
docs/
  sources/                       — vendored SDK docs + our own reference maps and comparison
    adk-python-reference.md
    openai-agents-python-reference.md
    claude-agent-sdk-python-reference.md
    adk-comparison.md
  architecture/
    multi-sdk-agentic-architecture.md   — the core design decision (orchestrator + workers via MCP)
    scaling-and-operations.md           — deployment, failure handling, multi-tenancy at scale
    v1/                                 — detailed, research-grounded v1 architecture (start at v1/README.md)
      guidelines/                       — methodology: how to build/test/evolve this system (start at guidelines/README.md)
scripts/
  fetch-docs.sh                  — fetches/refreshes the vendored SDK source repos
```

## Where to start reading

1. `CLAUDE.md` — points to everything else and states the working rules for this project.
2. `docs/architecture/v1/README.md` — the detailed v1 architecture, if you want the full picture.
3. `docs/architecture/v1/guidelines/README.md` — the methodology for building it incrementally without over-building or getting locked in.
