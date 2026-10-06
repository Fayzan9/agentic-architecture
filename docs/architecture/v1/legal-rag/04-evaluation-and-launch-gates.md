# Legal RAG — Evaluation, Monitoring & Launch Gates

Given the stakes established in `01-the-stakes-and-why-naive-rag-fails.md`, evaluation for this system cannot be an afterthought or a single pre-launch checklist — it needs to be a standing discipline, both before launch and continuously in production. This document specifies exactly how, grounded in how production teams actually evaluate high-stakes RAG systems in 2026.

## 1. Split retrieval quality from generation quality — never one blended score

Production RAG evaluation frameworks (RAGAS, TruLens, Arize Phoenix) all separate two genuinely different failure classes, and this project should do the same rather than tracking one combined "quality score":

| Layer | What it measures | Why it must be separate |
|---|---|---|
| **Retrieval metrics** | Context precision (do relevant clauses rank above irrelevant ones?), context recall (was the needed clause actually retrieved at all?) | A retrieval regression can be completely hidden by a generation-quality metric that happens to still score well on the cases it does have good context for |
| **Generation metrics** | Faithfulness (what fraction of claims in the answer are actually supported by the retrieved context?), answer relevancy (does it address the actual question asked?) | A change that makes the model *write better* while quietly retrieving worse context is a real, documented, otherwise-invisible failure pattern |

**Faithfulness specifically should be computed by decomposing the generated answer into individual claims and verifying each one against the retrieved context independently** (the standard RAGAS approach) — not by asking a single "was this answer good?" judge question, which is far too coarse to catch a single fabricated clause buried in an otherwise-correct answer.

## 2. Building the golden evaluation set — start from real errors, not imagined ones

Consistent with this project's own established eval-driven-development methodology (`../guidelines/02-build-order-and-methodology.md` §2), the recommended construction process is:

1. Pull real documents from the actual corpus.
2. Extract genuine facts/clauses from them, and generate realistic questions those facts would answer (synthetic question generation).
3. **Have a human with real subject-matter/legal expertise verify every generated answer and citation** before it's added to the golden set — synthetic generation alone, without human verification, is explicitly not sufficient for a legal-accuracy golden set.
4. Grade retrieval quality with classic information-retrieval metrics (Recall@k, Precision@k, Mean Reciprocal Rank) against human-labeled "this document is actually relevant" judgments — separately from grading generation quality via LLM-as-judge validated against human labels.

**On size:** there's no universal minimum, but a commonly-cited starting point for a CI regression backbone is 50–100 curated cases. The more important discipline, consistent with this project's own principle, is prioritizing **error analysis on real production failures** over hitting an arbitrary target count — the existing chat system's own feedback categories (per `02-existing-system-assessment.md`, already including "wrong-or-missing-citation" and "should-not-have-answered") are exactly the mechanism that should feed real failures into this golden set on an ongoing basis, not just at initial launch.

## 3. Production monitoring — don't stop evaluating once it ships

- **Score every live response for faithfulness against its own retrieved context, in real time**, with alerting when scores drop below threshold — not just relying on a user happening to flag a bad answer.
- **Tie every piece of user feedback to the specific underlying trace** (which retrieval call, which chunks, which generated claim) so a thumbs-down can be traced to a specific failure point, not just logged as a generic negative signal. The existing plan's design (feedback pointing at a specific stored message row, per `02-existing-system-assessment.md`) already supports this — make sure the faithfulness/verification scores from §1–2 above are captured on that same message row so a flagged answer's full diagnostic trail is available immediately.
- **Monitor for semantic drift explicitly tied to corpus changes**, not just on a fixed calendar schedule. A concrete, domain-relevant failure mode: embeddings and retrieval behavior calibrated against an older set of documents and terminology can degrade as new documents or newer regulatory/legal language enter the corpus. Re-indexing and re-running the golden-set evaluation should be an explicit, triggered step whenever a meaningful batch of new or superseded documents is ingested — not something that waits for a scheduled quarterly review.

## 4. Launch and regression gates — the actual numbers to hold this system to

There's no single universal threshold that fits every domain, but 2026 practitioner guidance converges clearly on **stricter, harder gates for compliance-sensitive systems specifically** — and this project should adopt the stricter end of that range given everything established in `01-the-stakes-and-why-naive-rag-fails.md`:

| Gate | Recommended threshold | What happens on failure |
|---|---|---|
| **Faithfulness / groundedness** (per generated answer) | 0.90–0.95 for a compliance-sensitive system (vs. ~0.90 typical for a general assistant) | Below ~0.70–0.80: hard block — return the "no confident answer" fallback, never a low-confidence answer labeled as if it were confident |
| **Citation validity** (the deterministic clause-ID + verbatim-quote check from `03-recommended-architecture.md` §2) | **99%+**, treated as a hard release gate, not a soft target | Any regression below this blocks a release outright — this is the single most consequential metric in the whole system, given `01`'s evidence that citation fabrication is the actual, repeatedly-litigated failure mode |
| **Context recall** on the golden set | Treated as a non-negotiable gate alongside faithfulness | A system failing context recall should not ship regardless of how well it scores on other metrics — a good answer built on missed evidence is still a real risk |

**The stated governing principle, worth adopting explicitly:** faithfulness, citation validity, and context recall are **non-negotiable gates** — a release that regresses any of these should be blocked outright, independent of how well it might score on answer relevancy, response speed, or user-satisfaction ratings. Precision/relevancy-style metrics can tolerate more normal variation between releases; the three gates above cannot.

## 5. Regression testing on every pipeline change

Any change to the retrieval configuration, the chunking strategy, the embedding model, or the generation prompts should automatically run against the frozen golden-set suite before it can ship — retrieval and generation metrics evaluated **independently**, per §1, not blended into one pass/fail number. This is the same discipline already established generally in this project's own guidelines (`../guidelines/05-progressive-rollout-and-change-management.md`), applied here to the specific metrics that matter for this system: a prompt tweak that happens to improve answer fluency while quietly degrading citation validity must be caught by this gate before it ever reaches a user, not discovered after the fact from a client complaint.

## Sources

- RAGAS, TruLens, Arize Phoenix documentation on retrieval vs. generation metric separation and faithfulness computation methodology
- Confident AI — RAG Evaluation Guide
- Hamel Husain — guidance on golden-set construction methodology for RAG evaluation
- QASkills — RAG Regression Testing Guide
- Openlayer — "RAG Evaluation in Production: Groundedness, Faithfulness, Retrieval Quality"
- Galileo — LLM output drift monitoring guidance
- This project's own prior methodology: `../guidelines/02-build-order-and-methodology.md`, `../guidelines/05-progressive-rollout-and-change-management.md`
