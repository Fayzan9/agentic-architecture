# Legal RAG — Recommended Architecture

Concrete technical recommendations addressing every gap identified in `02-existing-system-assessment.md`, grounded in 2026 external research. Organized by layer, in the order a request actually flows through the system.

## The layered pipeline, at a glance

```
Question (+ conversation history)
        │
        ▼
┌───────────────────────┐
│ 1. RETRIEVAL LAYER     │  hybrid search + reranking + clause-aware chunking
│    (§1)                │  + metadata filtering + version/supersession awareness
└───────────────────────┘
        │  candidate clauses/chunks, each with stable IDs + metadata
        ▼
┌───────────────────────┐
│ 2. VISIBILITY FILTER   │  (already planned, working — persona-based access
│    (existing, keep)    │   control, enforced in code, unchanged)
└───────────────────────┘
        │  allowed chunks only
        ▼
┌───────────────────────┐
│ 3. ABSTENTION GATE     │  evidence-sufficiency check — deterministic,
│    (§3)                │  not model-self-reported
└───────────────────────┘
        │  proceed only if evidence is sufficient
        ▼
┌───────────────────────┐
│ 4. GENERATION          │  model writes an answer with structured citations
│                        │  (clause ID + quoted span), not free-text markers alone
└───────────────────────┘
        │
        ▼
┌───────────────────────┐
│ 5. VERIFICATION LAYER  │  deterministic clause-ID/quote-match check (code)
│    (§2)                │  + entailment check (does the cited text actually
│                        │    support the claim?)
└───────────────────────┘
        │  fails → retry once, then abstain — never hand back an
        │  unverifiable citation
        ▼
   Answer + verified citations, or an explicit "I don't have a
   confident answer" response
```

## 1. Retrieval layer: clause-level, hierarchy-aware, version-aware

### Chunking: move to clause-level units, not fixed-token chunks
Adopt the concrete guidance from 2026 legal-RAG practice directly: chunk at the **clause level**, not by token count. Each unit gets a **stable section-path identifier** (e.g., "12.4," or a plan document's own section numbering) rather than an arbitrary chunk index. This is the single highest-leverage change to the retrieval layer, because it makes the verification step in §2 possible in the first place — you can't verify "does clause 12.4 say X" if the retrieval unit doesn't correspond to an actual, addressable clause.

### Add Anthropic's "contextual retrieval" technique to the indexing step
Before embedding each clause/chunk, prepend a short, LLM-generated sentence of document-level context (which document, which section, what the surrounding provision is about) — so the chunk retains context it would otherwise lose in isolation. This is a genuinely well-evidenced technique: reported to cut retrieval failure rate by up to 67% when combined with hybrid search and reranking. This is a one-time indexing-pipeline change, not a runtime cost.

### Keep and lean into the existing hybrid-search-plus-reranking platform capability
The retrieval platform already being used provides hybrid (semantic + keyword) search and reranking as built-in features — this already clears the 2026 baseline bar and should not be replaced. The recommended additions here (clause-level chunking, contextual retrieval) make that existing capability meaningfully more accurate; they don't require replacing it.

### Add metadata-driven filtering (self-querying retrieval)
Alongside semantic search, retrieval should be able to filter on structured metadata — document type, category, date, and (critically, per §4 below) supersession status — before or alongside the semantic search step. The well-documented pattern for this is a **self-querying retriever**: an LLM parses the user's natural-language question into both a semantic search string and a structured metadata filter automatically, rather than requiring the user to manually specify filters. This is what enables the "navigate by grouping/hierarchy" requirement directly — a question naturally scoped to "our ASA contracts" or "documents from this client" gets that scoping applied as a hard filter, not just hoped-for semantic relevance.

## 2. Verification layer: the single highest-priority addition

This is the layer that's currently missing from the existing plan (per `02-existing-system-assessment.md` §1), and it's the layer most directly responsible for closing the gap between "has citations" and "citations are actually correct" — which is exactly where the Stanford study found even top legal AI vendors failing.

**Two checks, both required, run after generation and before the answer is ever shown to a user:**

1. **Deterministic clause-ID and verbatim-quote check (code, not a model call).** Require the model's structured output to include, per citation: the clause/section ID it's citing, and the exact quoted span of text it's relying on. In code — not by asking another model — verify (a) that clause ID actually exists among the retrieved/allowed chunks, and (b) that the quoted text is an exact (or near-exact, allowing for whitespace) substring match of that clause's real content. **This single check catches the most common and most dangerous failure mode: a fabricated citation that looks structurally correct.**

2. **Entailment verification (a lightweight model or classifier call).** Separately from the exact-match check, verify that the *claim* being made in the answer is actually logically supported by (not just topically adjacent to) the cited text — using a natural-language-inference-style check. This catches the subtler failure mode where a real citation is attached to a claim the citation doesn't actually support (e.g., citing the right clause but overstating or misreading what it says).

**The failure-handling rule, non-negotiable:** if either check fails, the system retries generation once (varying the prompt to point out the specific verification failure), and if it still fails, **the system abstains rather than returning an unverifiable citation to the user.** This directly implements the principle already established in `../09-observability-audit-cost-and-ratelimiting.md`'s "failure must be visible, not just logged" discipline, applied to the single most consequential failure mode this system has.

## 3. Abstention: a deterministic evidence check, not a model's self-report

Given the finding in `01-the-stakes-and-why-naive-rag-fails.md` §3 that reasoning-tuned models are measurably *worse* at correctly recognizing when they don't know something, **do not rely on the model deciding to say "I don't know."** Instead, gate generation on an explicit, code-level evidence-sufficiency check *before* the model is even asked to write an answer:

- Is the reranked relevance score of the top retrieved clause(s) above a defined confidence threshold?
- Did any content survive the visibility filter at all? (Already implemented — keep this.)
- Is there a minimum number of independently-relevant clauses, or is the system relying on a single, weakly-relevant match?

If these checks fail, skip the generation call entirely and return the fixed "I don't have a confident answer" response — exactly the pattern already implemented for the visibility-filter-empty case, extended to cover **retrieval confidence being too low**, not just retrieval returning nothing at all.

## 4. Version/supersession-aware retrieval: reuse PDI's existing concept

Rather than treating this as a new problem to solve from scratch, **directly reuse the "controlling stack" logic PDI's Intelligence Engine already implements** (`../../../usecase/pdi/03-deliverable-1-intelligence-engine.md` §D1-S2) for resolving which document version legally controls a given provision as of a specific date. Concretely:

- Every indexed clause/chunk carries metadata: source document, effective date, and — where applicable — an explicit "superseded by" pointer to whatever later amendment overrides it.
- Retrieval defaults to **excluding superseded content** unless the user's question explicitly asks about historical/prior language (e.g., "what did the old policy say about X").
- This is exactly the pattern named in current academic research as "Controlling Authority Retrieval" and implemented as "VersionRAG" — both frame this as a distinct, necessary retrieval capability specifically because standard retrieval "fails structurally" when correctness depends on knowing whether a document has been superseded, using overruled legal precedent as their own illustrative example. **This project doesn't need to invent this capability — it needs to wire an already-solved internal concept (PDI's controlling stack) into the chat system's retrieval metadata.**

## 5. Hierarchy and navigation: pair the chatbot with an explicit document browser

Per the requirement to let users "navigate the documents... grouping, hierarchy etc" — the recommended pattern, confirmed as standard in enterprise legal-knowledge-management products, is **not to replace conversational Q&A with a browser, but to pair them as complementary entry points into the same indexed corpus.** Concretely:

- A document taxonomy (category, sub-category, client/matter, document type) that a user can browse directly, independent of asking a question.
- Every citation in a chat answer should be a live link into that same browser view, landing exactly at the cited clause — so a user (or, just as importantly, an attorney reviewing the system's output before relying on it) can verify a claim against the real document with one click, not by re-searching.
- Building the taxonomy itself can be LLM-assisted (an LLM classifies each incoming document against a known set of categories) rather than requiring fully manual categorization — a well-documented, viable pattern, especially since this project's document categories are already reasonably well known in advance (the same category structure PDI's own document-type detection already uses, per `../../../usecase/pdi/03-deliverable-1-intelligence-engine.md` §D1-S1).
- **Defer a full knowledge-graph/GraphRAG layer** (multi-hop, cross-document relationship retrieval) unless and until a real, demonstrated need for cross-document synthesis questions emerges — this is exactly the kind of complexity this project's own Rule-of-Three discipline (`../guidelines/01-guiding-philosophy.md` §4) says to earn, not assume up front. Metadata filtering plus a browsable taxonomy likely covers the "navigate/group/hierarchy" requirement adequately for a first version; escalate to a graph structure only if real usage shows a genuine, recurring need for multi-hop cross-document questions the taxonomy-plus-filter approach can't answer.

## 6. What NOT to do, explicitly

- **Do not use semantic caching for legal answers.** This project's own existing guidance (`../07-caching.md` §3) already establishes that semantic caching can return a confidently wrong answer with no signal it degraded, and explicitly says this must never be used for anything consequential. A legal citation answer is exactly the kind of consequential output that rule already covers — this is a direct, existing prohibition, not a new one.
- **Do not assume a bigger or more "reasoning"-capable model solves the accuracy problem on its own.** Per §3, evidence points the other way for abstention specifically — invest in the deterministic verification layer (§2) instead of primarily in model selection.
- **Do not treat "it has citations" as sufficient evidence of safety in any evaluation or demo.** Per `01-the-stakes-and-why-naive-rag-fails.md` §2, this is precisely the false confidence that led to measured 17–33% hallucination rates in commercial legal AI products that also display citations.

## Sources

- Anthropic — Contextual Retrieval technique (cited via 2026 RAG-technique surveys)
- FutureAGI — "How to Build (and Evaluate) a Contract Review RAG Agent in 2026" (clause-level retrieval, deterministic citation verification)
- MongoDB / Elastic / LlamaIndex documentation on self-querying / auto-retrieval patterns
- "Controlling Authority Retrieval" (arXiv 2604.14488); "VersionRAG: Version-Aware RAG for Evolving Documents" (arXiv 2510.08109)
- AbstentionBench (arXiv 2506.09038)
- Sinequa and LawNext Directory — enterprise legal search UX patterns pairing conversational and browse interfaces
- This project's own prior architecture decisions: `../04-agent-harness-and-sandboxing.md`, `../07-caching.md`, `../09-observability-audit-cost-and-ratelimiting.md`, `../guidelines/01-guiding-philosophy.md`
