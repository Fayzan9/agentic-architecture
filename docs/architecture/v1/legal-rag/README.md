# Legal RAG — Industry-Grade Legal Document Chatbot Architecture

Detailed, research-grounded architecture for a high-accuracy RAG (Retrieval-Augmented Generation) chatbot over a large, categorized corpus of legal/governing documents, where a wrong answer carries genuine liability risk. This is not a from-scratch design exercise — it evaluates and extends a **real, already-planned system** in this project's own ecosystem (the "Sophia" chatbot being folded into the PDI platform documented in `../../../usecase/pdi/`).

**Read in this order:**

| # | Doc | What it covers |
|---|---|---|
| 1 | [`01-the-stakes-and-why-naive-rag-fails.md`](01-the-stakes-and-why-naive-rag-fails.md) | Real, external evidence for why this matters: ~1,600 documented court sanctions for AI-fabricated legal citations, a Stanford study finding even top commercial legal AI products hallucinate on 17–33% of queries, and evidence that "reasoning" models are *worse*, not better, at knowing when to abstain |
| 2 | [`02-existing-system-assessment.md`](02-existing-system-assessment.md) | A concrete evaluation of the real, already-planned chat system against this risk picture — what it already gets right (managed hybrid retrieval, code-level visibility filtering, deterministic abstention, categorized feedback, a safety-critical canary test) and what's genuinely missing |
| 3 | [`03-recommended-architecture.md`](03-recommended-architecture.md) | The full recommended design: clause-level chunking, contextual retrieval, metadata/self-querying filters, a deterministic citation-verification layer, evidence-based abstention, and reusing PDI's existing document-supersession logic — with a full pipeline diagram |
| 4 | [`04-evaluation-and-launch-gates.md`](04-evaluation-and-launch-gates.md) | How to evaluate this before and after launch: separated retrieval/generation metrics, golden-set construction, production drift monitoring, and concrete numeric launch gates (99%+ citation validity, 0.90–0.95 faithfulness) |
| 5 | [`05-open-questions-and-decisions-needed.md`](05-open-questions-and-decisions-needed.md) | What's genuinely undecided — including what's deliberately deferred as unearned complexity (GraphRAG, RAPTOR, agentic self-correcting retrieval) per this project's own Rule of Three |

## The one finding that should reframe how this whole problem is approached

**"It has citations" is not evidence of safety.** The Stanford RegLab study is the single most important data point in this entire document set: purpose-built, heavily-funded, retrieval-grounded legal AI products from the largest legal research companies in the world — products that *already* display citations and *already* market themselves as hallucination-resistant — still fabricate or mis-ground answers on 17–33% of real queries. The gap between "has citations" and "citations are actually, verifiably correct" is exactly where this document set's core recommendation (`03-recommended-architecture.md` §2, the deterministic citation-verification layer) is aimed — and it's the single highest-priority addition to the system already being built.

## How this connects to the rest of this project's architecture

- **`../guidelines/01-guiding-philosophy.md`** — the Rule of Three governs what's deliberately deferred in `05-open-questions-and-decisions-needed.md` (GraphRAG, RAPTOR, agentic retrieval loops).
- **`../04-agent-harness-and-sandboxing.md`** — the existing chat system's code-level (not prompt-level) visibility enforcement is a direct, working instance of this project's own established guardrail principle.
- **`../07-caching.md`** — this project's existing prohibition on semantic caching for consequential outputs applies directly and explicitly to legal citation answers.
- **`../../../usecase/pdi/`** — the business context this chatbot lives inside, and the source of the "controlling stack" concept `03-recommended-architecture.md` §4 recommends reusing directly for document-version-aware retrieval rather than solving that problem twice.
- **`../../../usecase/assessments/`** — the same underlying company's existing manual document-review products, which share the exact same "a wrong answer is a real liability" stakes this document set treats as foundational.
