# v1 — Tools & MCP

**Status:** v1 design — pre-implementation
**Reads with:** `docs/architecture/scaling-and-operations.md` §1 (Registry) and §5 (Deployment), `11-security-and-multi-tenancy.md`

## 1. MCP architecture, precisely

Source: [official MCP architecture spec](https://modelcontextprotocol.io/docs/2026-07-28/learn/architecture).

**Host–Client–Server model:**
- A **Host** process (this project's orchestrator, and each worker when it itself calls sub-tools) creates one or more isolated **Clients**.
- Each **Client** holds exactly one stateful session to one **Server**.
- Each **Server** exposes **tools**, **resources**, and **prompts** over that session.
- Wire format: JSON-RPC 2.0.

**The isolation principle that validates this project's existing design:** the spec states servers "should not be able to read the whole conversation, nor 'see into' other servers." This is not just a preference this project chose — it's the protocol's own intended model. It directly confirms the "workers are stateless per invocation" decision already made in `multi-sdk-agentic-architecture.md` §4: the orchestrator (Host) holds full conversation state; each worker (Server, accessed via a Client) receives only what it needs for its specific subtask.

**Capability negotiation:** client and server declare supported features (tool support, resource subscriptions, sampling) during a JSON-RPC handshake at session init. This is the mechanism `scaling-and-operations.md` §2's version-pinning design should build on — capability negotiation is already a first-class part of the protocol, not something to bolt on separately.

**Transports:**

| Transport | Use when | Notes |
|---|---|---|
| **stdio** | Server is local, single-client, trusted, co-located in the same process/host as its caller | Runs with the caller's full privileges — no network isolation. Reserve for genuinely co-located, trusted workers only (per `scaling-and-operations.md` §5's stated rule) |
| **Streamable HTTP / SSE** | Server is remote, serves multiple clients concurrently, is its own independently deployed service | This is the default for this project's worker architecture, since `scaling-and-operations.md` §5 already commits to each worker as its own deployable unit |

## 2. Tool design standard for this project

Source: [Anthropic — Writing Effective Tools for AI Agents](https://www.anthropic.com/engineering/writing-tools-for-agents). These are concrete, evidence-backed rules — adopt them as hard conventions for every tool exposed by every worker's MCP server, not optional style guidance.

### Rule 1: build task-shaped tools, not 1:1 API wrappers

Don't expose three separate CRUD-style tools (`get_availability`, `create_event`, `check_conflicts`) when the actual task is "schedule a meeting." Build one `schedule_event` tool that does the composite work internally. This is a stronger claim than generic "keep tools narrow" advice — it's "consolidate around the workflow the agent actually needs to accomplish," and it directly shapes how each worker's MCP surface should be designed (see `scaling-and-operations.md` §5's "narrowest tool surface needed for its role" — this rule tells you *how* to draw that surface).

### Rule 2: error messages coach the model toward a fix

A tool failure response should suggest what to try next (narrow the query, add a filter, retry with different params) — not return a raw stack trace or bare error code. This composes directly with ADK's `reflect_retry_tool_plugin` (`scaling-and-operations.md` §3a): that plugin feeds structured failure info back to the model for reflection, and it can only reflect usefully if the tool's error message itself is actionable.

### Rule 3: cap and paginate large tool outputs — default to ~25,000 tokens

Anthropic's own tools default to capping responses around 25,000 tokens, with pagination/truncation and sensible defaults rather than dumping unbounded output into context. **Adopt this exact number as this project's own default cap** for any tool response, worker-side, before it's returned to the orchestrator — this is a concrete number worth standardizing rather than leaving per-worker judgment calls.

### Rule 4: namespace every tool by domain — mandatory naming convention

Once many tools coexist across many workers, ambiguous names collide (`search` from three different workers). Anthropic's own guidance: prefix by domain (`asana_search`, not `search`). **This project's mandatory convention:** `<worker>_<verb>_<noun>` for every tool name registered in the Registry (`scaling-and-operations.md` §1) — e.g. `codeworker_run_tests`, `voiceworker_start_session`. This is not optional per-worker style; it's enforced at registry-entry validation time, because tool name collisions across a growing worker fleet are exactly the kind of failure that's invisible until it silently misroutes a call.

### Rule 5: tools should be discoverable on demand, not held statically in context

At scale (many tools across many workers), Anthropic's own guidance is that agents should load tool definitions **on demand** rather than holding the full catalog in every context window. This is a direct argument *for* the Registry-based dynamic lookup design already committed to in `scaling-and-operations.md` §1, straight from Anthropic's own practice — not just an assumption this project made independently.

### Rule 6: evaluation-driven tool iteration

Tools should be tested against real multi-step tasks and refined using eval transcripts, not designed once and left static. This ties tool design directly into the eval pipeline in `05-evaluation-and-feedback-loops.md` — a tool's schema/description is something the regression suite should catch regressions on, same as a prompt.

## 3. MCP-specific security — required reading before building the Registry

Source: [MCP security best practices](https://modelcontextprotocol.io/specification/2025-06-18/architecture). These are protocol-documented vulnerability classes, not generic security advice — each has a direct bearing on a component this project is already planning to build.

### Confused deputy — applies directly to the Registry

If the Registry (`scaling-and-operations.md` §1) also brokers OAuth to third-party APIs on behalf of multiple workers/tenants, and does so as a static-client-ID proxy with per-user consent cookies, an attacker can potentially skip consent and steal auth codes. **Required mitigation, non-negotiable if the Registry ever brokers OAuth:** per-client consent tracking, exact-match `redirect_uri` validation, signed state parameters. If the Registry does *not* broker OAuth (workers each manage their own third-party auth independently), this vulnerability class doesn't apply — but that's a design choice to make explicitly, not assume.

### Token passthrough is explicitly forbidden by the protocol's own guidance

A server must never forward a token it received to a downstream API without validating that token was issued *specifically for that server*. **Direct implication for `scaling-and-operations.md` §4d** (per-tenant credential resolution): workers must not blindly relay a tenant's raw token onward to a third-party API. Each worker boundary must validate/re-mint tokens rather than passing them through — this is now a hard requirement in the credential manager's design, not an optional hardening step.

### Session hijacking

Session IDs must never double as authentication, must be bound to `user_id:session_id`, and must be non-guessable and rotated. This reinforces `scaling-and-operations.md` §4a's rule that tenant ID comes from the authenticated request and is never re-derived from session state alone — session IDs are an identifier, not a credential.

### Scope minimization

Avoid broad/wildcard scopes (`admin:*`); use progressive elevation with per-operation scope challenges, logged with correlation IDs. Directly informs the credential design in `scaling-and-operations.md` §4d: credentials resolved for a worker call should be **call-scoped**, not session-wide — a worker handling one narrow subtask should not hold a credential broader than that subtask needs, even if the tenant's underlying account has broader access.

### Local server / stdio risk

Local (stdio) MCP servers run with the full privileges of their calling process. This is specifically relevant to the Claude Agent SDK coding worker, which runs shell/file tools — if that worker is ever run via stdio rather than as its own isolated remote service, it inherits this risk directly. See `04-agent-harness-and-sandboxing.md` for the sandboxing tier this implies.

## 4. MCP Registry — real-world prior art

Source: [official MCP Registry](https://registry.modelcontextprotocol.io/), [MCP Registry announcement](https://blog.modelcontextprotocol.io/posts/2025-09-08-mcp-registry-preview/), [modelcontextprotocol/registry on GitHub](https://github.com/modelcontextprotocol/registry).

There is now an official community MCP Registry (backed by Anthropic, GitHub, Microsoft, PulseMCP) that acts as a source-of-truth catalog other registries build on. Servers are namespaced via reverse-DNS tied to verified GitHub/domain ownership, specifically to prevent impersonation. **This validates the internal Registry design in `scaling-and-operations.md` §1 as modeled on real, production prior art — not a novel invention.** For this project's internal (non-public) registry, mirror the core ideas that matter at this project's scale:

- **Verified namespace ownership** — even internally, a worker's registered name should be tied to a known owning team/service, not free-text, to prevent accidental (not just malicious) name collisions as the worker fleet grows.
- **Versioned entries** — already specified in `scaling-and-operations.md` §2; the public registry's practice confirms this is standard, not over-engineering.
- Skip the full public-registry feature set (public discoverability, community review) — that's solving a different problem (open ecosystem trust) than this project's internal-only registry needs to solve.

## 5. Summary — what this doc changes/adds to prior decisions

| Prior decision | Refinement from this research |
|---|---|
| Registry-based discovery (`scaling-and-operations.md` §1) | Now grounded in the official MCP Registry's own pattern (verified namespace + versioning); mandate `<worker>_<verb>_<noun>` naming validated at registration |
| Per-tenant credential resolution (`scaling-and-operations.md` §4d) | Now explicitly forbids token passthrough; credentials must be call-scoped, not session-wide |
| Worker MCP surface should be "narrowest needed" (`scaling-and-operations.md` §5) | Now has a concrete method: task-shaped tools (Rule 1), not narrow-for-narrowness'-sake |
| Tool error handling feeding into `reflect_retry_tool_plugin` | Now has a concrete requirement: error messages must be actionable/coaching, not raw errors |
| *(new)* Tool output size | Hard default cap: ~25,000 tokens per tool response, with pagination |
| *(new)* stdio vs. remote transport | stdio only for genuinely co-located, trusted workers; default to Streamable HTTP/SSE otherwise — and stdio workers inherit full-process-privilege risk, relevant to the sandboxed coding worker specifically |
