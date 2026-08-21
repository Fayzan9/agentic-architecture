# v1 — Future-Facing: UI Builder Readiness

**Status:** v1 design — pre-implementation
**Scope note:** the UI/no-code builder itself is explicitly **out of scope for v1** (per `12-roadmap-and-build-sequence.md` — nothing here schedules building it now). This document specifies what must be true of the *architecture we do build now* so that adding a UI builder later is an extension, not a rewrite. Everything in this doc is cheap to do now and expensive to retrofit — that asymmetry is the entire justification for including it in v1 despite the UI itself being years away.
**Reads with:** `guidelines/01-guiding-philosophy.md` (Rule of Three — this doc is a deliberate, justified exception, explained in §0), `scaling-and-operations.md` §1 (Registry), `v1/04-agent-harness-and-sandboxing.md` (permission model), `v1/11-security-and-multi-tenancy.md`

## 0. Why this doesn't violate "don't build ahead of need" (Rule of Three)

`guidelines/01-guiding-philosophy.md` §4 warns against speculative generality — abstracting before a second real instance justifies it. This document is not an exception to that rule made carelessly; it's the specific, narrow case the rule itself allows for: **the cost of getting these particular decisions wrong is asymmetric and back-loaded.** A data-model field added now costs minutes. The same field retrofitted after real user data already exists in the old shape costs a migration, a compatibility shim, and risk to live tenants. The five commitments below (§2–§6) are chosen specifically because they're cheap now and expensive later — this is not "build the whole future system speculatively," it's "don't paint yourself into five specific corners that are hard to paint out of."

## 1. The one-sentence version of what changes

> **The only user of this system's "compose an agent" capability today is you, writing configs by hand or via API. Design every layer as if that user were instead a non-technical person operating a UI, tomorrow — because the moment you add that UI, it must be true without any of today's plumbing changing underneath it.**

Concretely: today, when you define a new worker, a new tool, or a new agent template, do it through the same data shapes, the same Registry, and the same pipeline that a future UI would generate configs into and read results out of — never through a shortcut that only works because the author happens to be a trusted engineer typing Python.

## 2. Agents and workflows must be data, validated by a schema — not code, from day one

This is the load-bearing decision. A UI builder can only ever produce **data** (a config object) — it cannot generate arbitrary Python. If today's agents/workflows are defined as hand-written code with no equivalent config representation, there is no "later" where a UI plugs in — the entire execution path would need to be rebuilt to accept data instead of code.

**Required now:**
- Define agent and workflow definitions as **schema-validated config objects** (JSON/YAML), using ADK's existing config-driven agent support (`agent_config.py`, `llm_agent_config.py`, `base_agent_config.py` — per `docs/sources/adk-python-reference.md`) and its workflow graph serialization (`cli/utils/graph_serialization.py`) rather than hand-rolled Python agent definitions, even for the one or two agents built during v1.
- Every "new agent" or "new workflow" created during v1 — even by you, even for internal use — goes in as a config object validated against a schema, not as inline code. **This is the single most important discipline in this document**, because it means the exact same creation path serves a human editing YAML today and a UI generating the identical YAML tomorrow — no parallel path to build later, no migration from code to data.

## 3. The Registry needs UI-shaped metadata now, even with zero UI consumers

`scaling-and-operations.md` §1 already specifies a Registry entry needs `name`, `description`, `connection params`, `auth scheme`, `version`, `owner`. A future builder UI needs to *render* a catalog of capabilities to a non-technical user — which requires metadata that has no purpose for today's API-only/config-file consumer, but is expensive to backfill across every existing entry later.

**Required additions to every Registry entry, now, even though nothing reads them yet:**

| Field | Purpose (for the future UI) | Cost to add now vs. later |
|---|---|---|
| `display_name` | Human-friendly name, distinct from the machine `name` (which follows the `<worker>_<verb>_<noun>` convention, `v1/03-tools-and-mcp.md` §2 — not something you'd show a non-technical user) | Trivial now; requires touching every existing entry later |
| `category`/`tags` | Lets a future catalog UI group/filter capabilities | Trivial now; requires a backfill pass later |
| `user_facing_description` | A plain-language explanation distinct from the technical `description` (which is written *for the orchestrator's LLM*, per `v1/03-tools-and-mcp.md` Rule 1 — a different audience with different needs) | Trivial now; conflating these two descriptions later means rewriting both from scratch to separate them |
| `parameter_schema` (for anything user-configurable) | What a builder UI would render as a form — even today's config-file authors benefit from this being a formal schema rather than free-text docs | Moderate now; a real schema migration later if parameters were previously undocumented/implicit |

**The discipline, stated plainly:** treat every Registry entry as if a designer were about to build a catalog card from it, even though none will for a long time. This costs almost nothing extra per entry today and avoids a full metadata backfill later.

## 4. Templates must be a real, first-class object — not just "an example config"

A non-technical builder-UI user will never compose an agent from primitives (a bare worker + a bare tool + hand-set permissions) — they compose from **templates**: a pre-vetted, pre-configured bundle (a worker choice + a tool set + guardrail settings + sane defaults) that's parameterized for their specific case.

**Required now:** define `Template` as a distinct, versioned object in the config schema (§2) from day one — a template references a base agent/workflow config plus a declared set of user-overridable parameters — even though, in v1, the only "template" that exists is whatever agent you build for internal use, and the only "user" instantiating it is you. This means: **build your own v1 agent as an instance of a template, not as a one-off config** — the discipline of separating "the reusable, vetted shape" from "one specific configured instance of it" is exactly the object model a future builder UI needs, and it costs nothing extra to apply it to a system with one template and one instance versus retrofitting the distinction once there are many of both.

## 5. Every config must be treated as untrusted input to the harness — regardless of who authored it

This is the most consequential requirement in this document, because getting it wrong is a security failure, not just a refactor.

`v1/04-agent-harness-and-sandboxing.md` Component 5 already requires default-deny, tiered permission escalation enforced deterministically, independent of the prompt. **Extend that requirement one level further, now:** the harness's permission/sandbox enforcement must be driven entirely by what a config **declares** (which tools, which capabilities, what sandbox tier its component capabilities require), never by an implicit trust assumption about who wrote the config.

**Why this must be true starting now, not added when the UI ships:** today, you are the only author of every config, so an implicit "configs are trusted because an engineer wrote them" shortcut would work fine and be invisible — nothing would break, no test would catch it, and it would ship. The moment a non-technical end user's UI-composed config enters the same pipeline, that implicit trust assumption becomes a real vulnerability (a user composing an agent that requests a broader sandbox tier or credential scope than their template should allow), and it will be scattered across however much code was written under the old assumption. **The fix costs nothing extra now** (enforce permissions from the config's declared capabilities, not from author identity, from the first config you ever write) **and is a significant, hard-to-fully-audit retrofit later** (finding every place an implicit trust shortcut was taken).

**Concretely:** a worker's sandbox tier, network policy, and credential scope (`v1/04-agent-harness-and-sandboxing.md` §3–§4) must be derived from the capabilities declared in its Registry entry and the config referencing it — never relaxed because "this config only exists internally for now." Every config, including your own, goes through the same enforcement path a future stranger's config would.

## 6. Configs must be tenant/owner-scoped objects from the start

A UI builder implies each user (or team) owns their own composed agents. `v1/11-security-and-multi-tenancy.md` already establishes tenant ID as a first-class dimension threaded through session state, credentials, and Registry lookups — extend this to the config objects themselves.

**Required now:** every agent/workflow/template config (§2, §4) carries an `owner_id`/`tenant_id` field from its very first version, even in a genuinely single-tenant v1 where that field is always the same value. Adding an ownership field to an object model after real configs already exist without one means a migration touching every existing record; including it from the start costs nothing, since a single-tenant system trivially satisfies "every config has an owner" by having one owner.

## 7. What this document explicitly does NOT require building now

To keep this grounded against over-building, stated as plainly as the requirements above:

- **No UI.** Nothing here builds a frontend, a drag-and-drop canvas, or a form renderer. Those stay fully deferred.
- **No multi-tenant infrastructure beyond the schema field.** `v1/11-security-and-multi-tenancy.md` §5's open question (request-level vs. process-level isolation) is unaffected by this document — §6 only asks for the *field* to exist, not for multi-tenant enforcement infrastructure to be built.
- **No general-purpose "anyone can register any capability" self-service flow.** The Registry stays curated/owner-reviewed (`scaling-and-operations.md` §1) — a future builder UI lets users *compose from* the catalog, not add arbitrary new entries to it themselves; that's a distinct, much later, and much higher-risk feature this document does not scope.
- **No template marketplace, sharing, or versioning UI.** §4 asks only for `Template` to exist as a data concept with the config schema supporting it — not for any of the product features that would eventually surround it.

## 8. Summary — the five cheap commitments, and what each protects against later

| # | Commitment | What it prevents later |
|---|---|---|
| 1 | Agents/workflows are schema-validated config objects, not hand-written code | A full rewrite of the execution path to accept UI-generated data |
| 2 | Registry entries carry UI-shaped metadata (`display_name`, `category`, `user_facing_description`, `parameter_schema`) | A metadata backfill across every existing capability |
| 3 | `Template` exists as a first-class, versioned object distinct from an instance | Retrofitting the reusable/instance distinction once many of both exist |
| 4 | Harness permissions are enforced from a config's declared capabilities, never from author-trust assumptions | A security retrofit auditing every implicit-trust shortcut once untrusted end-user configs enter the system |
| 5 | Every config carries an `owner_id`/`tenant_id` from its first version | A schema migration to add ownership once real configs already exist without it |

None of these five require building the UI, a marketplace, or multi-tenant infrastructure — they require making today's one-agent, single-author, single-tenant v1 built on the same data shapes and enforcement rules that a many-agent, many-author, many-tenant future version would need, so that future is additive rather than a rebuild.
