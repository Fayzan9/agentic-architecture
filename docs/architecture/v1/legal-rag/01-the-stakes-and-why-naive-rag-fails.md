# Legal RAG — The Stakes, and Why Naive RAG Is Not an Option

**Purpose:** before designing anything, establish — with real, external evidence — exactly why "top-5-chunks-and-answer" RAG is unacceptable for a legal-document chatbot, and why even sophisticated-looking mitigations can still fail. This is the risk case the rest of this document set (`02` through `05`) is designed against.

## 1. This is not a hypothetical risk — it's already produced ~1,600 documented court sanctions

A public tracker of AI-hallucination court cases shows **~1,490 court decisions worldwide (1,000+ in the U.S.)** where AI-fabricated legal material was submitted to a court, growing from roughly 200 a year earlier — **1,598 verified cases of AI-fabricated citations in total** as of the most recent count. This is the direct legal-industry successor to the foundational case, *Mata v. Avianca* (S.D.N.Y., 2023): an attorney used ChatGPT for legal research, it fabricated multiple plausible-sounding but entirely nonexistent case citations, and those citations were filed in a real court brief. The presiding judge sanctioned the attorneys under Federal Rule of Civil Procedure 11 for failing to verify their citations before filing — a small monetary penalty, but the case became the reference point cited in bar advisories and continuing-legal-education courses worldwide.

**Penalties have escalated sharply since**, not diminished: a federal appellate court has issued $15,000-per-attorney sanctions; an Oregon federal court issued a **$110,000 sanction** (the largest on record) after two lawyers submitted 23 fabricated citations and 8 invented quotations; a Nebraska attorney was **suspended from practice** in 2026 after filing an appeal brief where 57 of 63 citations were defective, including 20 fully hallucinated cases — he initially denied using AI, then admitted it, and the concealment itself drew a harsher penalty than the original hallucination.

**The pattern worth internalizing directly:** courts explicitly *permit* AI-assisted legal research. The sanctionable act, every time, is **filing unverified AI output** — and attempting to conceal AI involvement makes the consequence worse, not better. This has a direct design implication: whatever this project builds must make verification a structural, automatic part of the pipeline, not something left to the end user's diligence — because the industry's own track record shows relying on human diligence alone has already failed at scale, repeatedly, across a large and growing number of real practitioners.

## 2. Even the best-funded, purpose-built legal AI products still fail at a high rate

This is the finding that should most directly shape how much confidence to place in "we built a RAG system with citations" as a solution on its own. Stanford's RegLab and Institute for Human-Centered AI ran the first preregistered, empirical evaluation of commercial legal AI research tools (Lexis+ AI, Westlaw AI-Assisted Research, and Casetext/Practical Law's AI product), published in the *Journal of Empirical Legal Studies*. The measured results:

- **Lexis+ AI hallucinated or misgrounded on more than 17% of queries.**
- **Westlaw AI-Assisted Research hallucinated on roughly 33% of queries — nearly double.**

This directly contradicts the vendors' own marketing at the time: LexisNexis had claimed "100% hallucination-free linked legal citations," and Casetext had claimed its product "does not make up facts, or 'hallucinate.'" Stanford's own stated conclusion: **"Providers' claims are overstated."**

**The direct implication for this project:** these are not amateur systems — they are purpose-built, heavily-funded, retrieval-grounded legal AI products from the largest legal research companies in the world, and they still fail at a rate that would be considered catastrophic in most other software domains. **"We used RAG with citations" is not, by itself, evidence of safety.** The specific *mechanism* of grounding and verification matters enormously, and that mechanism is exactly what `03-recommended-architecture.md` is built around getting right.

## 3. A counterintuitive and directly relevant finding: "smarter" reasoning models can be *worse* at knowing when to say "I don't know"

A 2026 benchmark specifically designed to test abstention behavior across 20 different scenario types (unanswerable questions, underspecified queries, false premises, outdated information) found that **models generally do not reliably know when *not* to answer** — and, counterintuitively, **reasoning-tuned models perform *worse* at correct abstention, degrading by roughly 24% on average** compared to their non-reasoning base models. The likely cause: reasoning-focused training rewards producing a confident, complete final answer, which actively works against the behavior a legal system most needs when the evidence is thin.

**Direct implication:** do not assume that using a more advanced, "reasoning" model automatically makes a legal chatbot safer against fabrication. If anything, this finding argues for **engineering abstention as a deterministic, code-level gate** (checking retrieval confidence and evidence sufficiency directly) rather than trusting any model — reasoning or not — to reliably decide on its own when it doesn't actually know. See `03-recommended-architecture.md` §3 for how this shapes the abstention design.

## 4. Why this matters specifically for the system already being built in this project

This project already has a real, concrete plan in motion for exactly this kind of system — a chatbot (referred to internally as "Sophia," being folded into the PDI platform documented in `../../../usecase/pdi/`) that answers questions over a large set of the company's own governing legal/plan documents, for both internal staff and external clients, with citations. That system already does several things well by design (a deterministic visibility filter separating what internal vs. external users can see and cite, and a code-level abstention gate when nothing survives that filter) — but **visibility filtering and abstention-on-empty-results are necessary, not sufficient.** Neither of those mechanisms verifies that a *cited* answer's actual claim is genuinely supported by the source text it points to — which is exactly the failure mode responsible for the majority of the real-world cases in §1 and the measured hallucination rates in §2. `02-existing-system-assessment.md` evaluates the real, already-planned system against this full risk picture in detail.

## Sources

- *Mata v. Avianca, Inc.* — Justia case record; Wikipedia summary
- GC AI — AI Hallucination Legal Cases sanctions tracker (2026)
- Norton Rose Fulbright — "AI in Litigation: Update on Gen AI Sanctions in 2026"
- Scientific American — "Why Lawyers Keep Citing Fake Cases Invented by AI"
- Stanford RegLab/HAI empirical study of commercial legal AI hallucination rates, published in the *Journal of Empirical Legal Studies* (coverage via LawSites; paper via arXiv 2405.20362)
- AbstentionBench (arXiv 2506.09038) — large-scale benchmark of LLM abstention behavior across 20 scenario types
- "LLM Abstention as a Prompt-Sensitive Artifact" (arXiv 2507.16199)
