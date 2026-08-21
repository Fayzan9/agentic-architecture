# v1 — Caching

**Status:** v1 design — pre-implementation
**Reads with:** `06-memory-state-and-storage.md`, `09-observability-audit-cost-and-ratelimiting.md` §2 (cost tracking must account for cache separately)

## 1. Two distinct kinds of caching — do not conflate them

This project needs both, but they solve different problems and fail in different ways:

| | Prompt caching | Semantic caching |
|---|---|---|
| **What's cached** | The processing of a stable prefix (system prompt, tool definitions, long context) | The entire response, keyed by similarity to a past query |
| **Matches on** | Exact prefix match | Embedding similarity (approximate) |
| **Failure mode if wrong** | None — it's exact, so a miss just means no discount, never a wrong answer | Can return a confidently wrong answer with no built-in signal it degraded |
| **Use for this project** | Every worker call with a stable system prompt / tool schema / large repeated context | Only where the risk of a stale/wrong-but-plausible cached answer is acceptable — see §3 |

## 2. Prompt caching — mechanics and rules

Source: [Anthropic prompt caching docs](https://platform.claude.com/docs/en/docs/build-with-claude/prompt-caching).

- Caches a **stable prefix** so it doesn't need reprocessing on every call — directly applicable to the orchestrator's and every worker's system prompt, tool definitions, and any large repeated context (e.g., a coding worker's repository context that doesn't change turn to turn).
- **Two modes:** automatic (single `cache_control` marker at the top of the request, auto-advances as the conversation grows) or explicit breakpoints (up to 4, for fine-grained control over exactly what's cached).
- **Minimum cacheable length varies by model (512–4096 tokens)** — a short system prompt below this threshold silently doesn't cache at all. Check this against each worker's actual prompt length before assuming caching is active.
- **TTL:** 5-minute default (refreshed free on reuse, resets the clock on every hit) or 1-hour extended (2x the write cost, worth it for workers with sparser call patterns than every 5 minutes).
- **Pricing:** 5-min cache writes cost 1.25x base input; 1-hour writes cost 2x; cache **reads** cost ~0.1x base input (~90% discount) — this is the number that makes stable-prefix caching worth doing by default, not an edge-case optimization.
- **Invalidation cascades — the rule most likely to be silently broken:** changing `tools` invalidates the entire cache (system + messages); changing `system` invalidates system + messages; per-message changes (images, `tool_choice`) invalidate only messages downstream of that change. **Direct consequence:** if a worker's tool list is regenerated per-request (e.g., because the Registry lookup in `scaling-and-operations.md` §1 returns a slightly different tool set each time due to non-deterministic ordering or timestamp-bearing descriptions), caching silently breaks on every call. The Registry's tool-list output must be **stable and deterministically ordered** for a given worker/version, or prompt caching for that worker is effectively disabled without anyone noticing.
- **Placement rule:** put the cache breakpoint on the **last prefix block that's identical across requests.** A breakpoint placed on content that changes every call (a timestamp, per-request user data) makes caching useless — the breakpoint must sit strictly before any per-request-varying content.

**Required practice for this project:** every worker's harness spec (`04-agent-harness-and-sandboxing.md` §4) should note where its cache breakpoint sits and confirm its system-prompt+tools block is both above the minimum token threshold and stable across calls (Registry output included).

## 3. Semantic caching — use narrowly, with explicit safety metrics

Sources: [Portkey — Semantic Caching Thresholds](https://portkey.ai/blog/semantic-caching-thresholds/), [PyImageSearch — Semantic Caching for LLMs: TTLs, Confidence, and Cache Safety](https://pyimagesearch.com/2026/05/04/semantic-caching-for-llms-ttls-confidence-and-cache-safety/), [TianPan.co — Semantic Caching Cost Tier](https://tianpan.co/blog/2026-04-10-semantic-caching-llm-production).

**Documented failure modes, taken as hard warnings, not caveats:**

- A bad semantic-cache hit returns a wrong answer with full confidence (HTTP 200) — there's no built-in signal that it degraded. This is categorically different from a cache miss, which just costs more, not wrong.
- If a hallucinated response is ever cached, **every future similar query inherits the same error** — the cache amplifies a mistake rather than merely saving cost on a correct one.
- **Threshold is a hard, unavoidable tradeoff:** a 0.95 similarity threshold misses valid paraphrases (low hit rate, safer); 0.85 catches more paraphrases but lets more wrong-answer hits through (higher hit rate, riskier). There is no threshold that avoids this tradeoff — pick a value on purpose, per use case, not by copying a default from documentation.
- **One TTL doesn't fit all answer types.** Stable/reference-style answers (pricing, FAQ-type content) can tolerate hours-to-days TTLs; volatile answers need much shorter TTLs. A single global TTL setting for semantic cache entries will be wrong for at least one class of query.
- **Embedding-model upgrades silently invalidate the entire cache** — old and new embedding similarity scores aren't comparable, so swapping the embedding model without a corresponding cache flush produces silently incorrect similarity judgments across the whole cache, not just degraded quality.

**Required practice for this project:**

- Restrict semantic caching to specific, deliberately chosen use cases where a wrong-but-plausible cached answer is an acceptable risk (e.g., FAQ-style or reference lookups within a worker) — **do not** apply it as a general response cache across the orchestrator or any worker that takes consequential actions (anything that writes, executes code, or spends money on a tenant's behalf must never be served from a semantic cache).
- Version-tie every semantic cache entry to the embedding model version used to create it; treat an embedding-model upgrade as requiring a cache flush, not a background migration.
- Track the safety metrics recommended in research as first-class dashboards, not an afterthought: **stale-answer rate, incorrect-hit rate, manual override rate, high-risk-bypass rate** (how often a query that should have bypassed the cache due to risk classification didn't).

## 4. Tool/retrieval result caching

Distinct from both of the above: caching the *output of a tool call* (e.g., a lookup against a slow external API) rather than the model's response. This should follow the same exact-match-preferred bias as prompt caching where possible (cache by exact tool-call arguments, with an explicit TTL appropriate to how fast the underlying data changes) — avoid semantic similarity matching for tool results specifically, since a tool result feeds directly into an agent's next action, and an approximately-similar-but-wrong tool result is exactly the kind of silent failure mode semantic caching is documented to produce.

## 5. Cost accounting must treat cache reads/writes as distinct token fields

This connects directly to `09-observability-audit-cost-and-ratelimiting.md` §2: cache reads and cache writes must be tracked as **separate fields** from regular input/output tokens in cost accounting (`prompt_cached_tokens`, `prompt_cache_creation_tokens`), not folded into a single token count — otherwise cost dashboards will misattribute the ~90% discount on cache reads and the 1.25x–2x premium on cache writes, producing an inaccurate picture of what's actually expensive in the system.

## Sources

- [Anthropic prompt caching docs](https://platform.claude.com/docs/en/docs/build-with-claude/prompt-caching)
- [Portkey — Semantic Caching Thresholds](https://portkey.ai/blog/semantic-caching-thresholds/)
- [PyImageSearch — Semantic Caching for LLMs: TTLs, Confidence, and Cache Safety](https://pyimagesearch.com/2026/05/04/semantic-caching-for-llms-ttls-confidence-and-cache-safety/)
- [TianPan.co — Semantic Caching Cost Tier](https://tianpan.co/blog/2026-04-10-semantic-caching-llm-production)
- [Preto.ai on semantic caching pitfalls](https://preto.ai/)
