# v1 — Security & Multi-Tenancy

**Status:** v1 design — pre-implementation
**Reads with:** everything — this doc is a cross-cutting synthesis, not a new subsystem. It restates `scaling-and-operations.md` §4 with the refinements found across `03`, `04`, and `09`, so the full tenant-isolation posture is in one place.

## 1. Why this doc exists separately, even though it's not new content

Security and tenant isolation aren't a subsystem alongside the others — they're a property every other subsystem must have. This doc exists to state that property once, completely, with pointers to where each piece is actually implemented, so it can be checked as a whole rather than trusted to have been handled correctly by each doc independently.

## 2. Tenant identity — the golden thread

Restating `scaling-and-operations.md` §4a with no change, because it's already correct: **tenant ID enters at the orchestrator's entry point, from the authenticated request, and is never re-derived downstream.** It attaches to ADK's `InvocationContext`/`ReadonlyContext` for the whole run. Reinforced by MCP's own security guidance (`03-tools-and-mcp.md` §3): session IDs must never double as authentication and must be bound to `user_id:session_id` — this project's tenant ID is an identity fact carried through context, not something inferred from a session ID.

## 3. Where tenant isolation must be enforced — full checklist across all v1 docs

| Layer | Requirement | Specified in |
|---|---|---|
| Session/hot-tier state | Namespaced by tenant at the storage layer (schema/keyspace/enforced column) | `06-memory-state-and-storage.md` §4 |
| Warm-tier memory | Same namespacing; superseding logic (§2 of `06`) must also respect tenant boundaries — a fact from Tenant A must never be retrievable in Tenant B's similarity search | `06-memory-state-and-storage.md` §1–2 |
| Every MCP call to a worker | Tenant ID carried explicitly in call context, not implied by "whichever session is active" | `scaling-and-operations.md` §4c, `03-tools-and-mcp.md` §3 (session hijacking guidance) |
| Credentials | Resolved per-tenant, per-call-scoped (not session-wide), never cached across tenants, **never passed through raw** to a downstream API | `scaling-and-operations.md` §4d + `03-tools-and-mcp.md` §3's token-passthrough prohibition (this is a hard addition from MCP's own security guidance, not present in the original scaling doc) |
| Sandboxes/artifacts | Tenant-scoped working directory/container/artifact store — never shared across tenants | `scaling-and-operations.md` §4e, `04-agent-harness-and-sandboxing.md` §3 |
| Registry lookups | Filtered by tenant entitlement — an unauthorized worker isn't a routable option at all | `scaling-and-operations.md` §4f |
| Tracing spans | Tagged with `tenant_id` on every span, enabling per-tenant filtering for debugging and for rate-limit/cost enforcement | `09-observability-audit-cost-and-ratelimiting.md` §1 |
| Cost/rate limits | Enforced per-tenant, at the same layer as per-tenant credential resolution | `scaling-and-operations.md` §4d, `09-observability-audit-cost-and-ratelimiting.md` §2, §4 |
| Audit trail | `session_id` field correlates to tenant context; audit records are themselves tenant-partitioned in storage | `09-observability-audit-cost-and-ratelimiting.md` §3 |

## 4. New security requirements this v1 research added beyond the original scaling doc

These are genuinely new, sourced from MCP's own security documentation (`03-tools-and-mcp.md` §3) — not restatements:

1. **Token passthrough is forbidden, not just discouraged.** A worker must validate that any token it holds was issued specifically for it, and must never forward a tenant's raw token to a downstream third-party API. This is now a hard requirement on the credential manager's implementation, not a design preference.
2. **Confused-deputy mitigation is required if the Registry brokers OAuth.** Per-client consent tracking, exact-match `redirect_uri`, signed state parameters — required specifically if/when the Registry acts as an OAuth proxy on behalf of workers. If the Registry never brokers OAuth (each worker manages its own third-party auth), this requirement doesn't apply — but that must be an explicit, documented choice, not an accidental non-decision.
3. **Scope minimization at the call level.** Credentials resolved for a specific worker call must be scoped to that call's actual need, not the tenant's full underlying account access — even where the tenant's own permissions are broader.
4. **stdio-transport workers inherit full-process privilege.** Any worker connected via stdio (only justified for genuinely co-located, trusted cases per `03-tools-and-mcp.md` §1) runs with the same privileges as its caller — this is a reason to prefer remote (HTTP/SSE) transport by default even beyond the deployment-independence argument already made in `scaling-and-operations.md` §5.

## 5. The still-open decision, restated once more, precisely

Carried forward unchanged from `scaling-and-operations.md` §4's "what this document does NOT decide": **request-level isolation (shared fleet, tenant ID threaded through every call — the default recommended posture, and the one this entire v1 design assumes throughout) vs. process-level isolation (dedicated orchestrator+worker fleet per tenant)** remains a capacity/compliance decision requiring input this project doesn't have yet (tenant count, contractual/compliance requirements). If any tenant contractually requires dedicated infrastructure, that tenant specifically gets process-level isolation as a carve-out — this doesn't have to be an all-or-nothing choice across the whole tenant base.

## 6. A note on what "secure" means for this specific system, not security in general

This project's actual differentiated security surface, given everything researched across `03`, `04`, and `09`, is not generic web-app security (auth, input validation, etc. — assumed as table stakes, not detailed here) but specifically:

- **Agent-to-agent/agent-to-tool trust boundaries** (MCP's host-client-server isolation, `03-tools-and-mcp.md` §1) — the model itself is inside the trust boundary in a way a traditional app's business logic isn't, since a prompt injection in tool output is an attacker-controlled input reaching the same reasoning process that decides what to do next.
- **The sandbox as the actual trust boundary for code execution** (`04-agent-harness-and-sandboxing.md` §2–3) — this is where "secure" concretely means microVM-tier isolation for the coding worker, not a policy statement.
- **Tamper-evidence of the record of what the agent did** (`09-observability-audit-cost-and-ratelimiting.md` §3) — a compromised or misbehaving agent shouldn't be able to erase or rewrite its own audit trail, which is why that trail is written by an independent component.

Keep this framing when prioritizing security work for v1: the highest-value security investment for this specific system is the sandbox tier for the coding worker and the independent audit writer — not generic hardening that any web app would also need.
