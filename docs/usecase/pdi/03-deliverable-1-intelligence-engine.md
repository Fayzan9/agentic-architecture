# PDI — Deliverable #1: Intelligence Engine

**What this is, in the source specification's own words:** "an analytical engine with predefined fields capturing plan census and operational data."
**What this explicitly is NOT:** a plan document assessment (that's Deliverable #2, see `04-`), and not a general-purpose document repository.

**In plain terms:** before you can assess anything, you need to know what you're looking at — which documents belong to which plan, which one is the current controlling version, what the regulatory filings independently say, and what facts simply aren't written down anywhere and have to be asked. Deliverable #1 is the layer that builds that foundation, once, for every plan — so Deliverable #2 (and every future thing built on top of this platform) can be built on structured facts instead of re-reading raw PDFs from scratch every time.

## The business workflow, step by step

```
 D1-S1                D1-S2                 D1-S3              D1-S4
 Document          →  Document family    →  Form 5500       →  Related documents
 acquisition &        resolution             ingestion &         (ASA, stop-loss
 ingestion             (match docs to           matching           policy, vendor
 (get every PD/          one plan,                (attach the        agreements)
 SPD/wrap/amend-         resolve which            plan's own          — captured &
 ment into the           document is              regulatory           categorized,
 system, OCR'd,          "controlling"            filing data)         not deeply
 quality-scored)         as of a date)                                 parsed yet
      │                     │                        │                    │
      └─────────────────────┴────────────┬───────────┴────────────────────┘
                                          ▼
                                     D1-S5
                              Implementation intake
                          (a short human questionnaire
                           for facts no document can
                           reveal — e.g., is this plan
                              actually level-funded?)
                                          │
                                          ▼
                                     D1-S6
                        Classification extraction engine
                    (the core: every plan gets a full profile —
                   every field has a VALUE + a SOURCE + a CONFIDENCE
                          SCORE + a CITATION to the exact language)
                                          │
                                          ▼
                                     D1-S7
                             Human-in-the-loop review
                     (low-confidence or conflicting fields go to
                      a person; corrections become training data
                              for improving the engine)
                                          │
                                          ▼
                                     D1-S8
                            Plan Intelligence data store
                  (the permanent, versioned record — every value
                     traceable back to exactly where it came from,
                       and to what was known "as of" any past date)
                                          │
                                          ▼
                                     D1-S9
                          Intelligence Engine Dashboard
                (book-of-business analytics: demographics, vendor
                  stats, language trends, opportunity analysis —
                   the "we reviewed 150 of your plans" sales tool)
```

## Step-by-step business detail

### D1-S1 — Get every document into the system

Every governing document (Plan Document, SPD, wrap document, amendment) is pulled in from wherever it currently lives — the company's document repository, its plan-document-authoring platform (for documents natively built there, treated as the highest-fidelity source), or ad-hoc email attachments from the implementation/onboarding team. Documents get OCR'd where needed (with page-position information preserved, since every future citation depends on knowing exactly where on the page a piece of language sits), and each one is quality-checked and classified by type. **A stale, superseded document (e.g., a five-year-old standalone SPD that's since been replaced by a combined document) must be flagged as stale, not silently used as if it were current.**

### D1-S2 — Figure out which documents belong together, and which one actually controls

This is one of the most important steps in the whole system, and it exists because of a subtle but critical business risk: **plan documents get amended, sometimes multiple times a year, and an assessment run against only the base document is simply wrong if a relevant amendment changed the language being checked.** This step groups every document into a "plan family" (one employer, one specific plan, one plan year) and builds a **"controlling stack"** — the base document plus every amendment, ordered by effective date, so the system always knows exactly which piece of language is legally in force as of any given assessment date. It also catches structural problems on its own — like a standalone SPD that disagrees with the main plan document, or two documents that both claim to be "the current one" — and these conflicts are **treated as sellable findings**, not quietly fixed and hidden.

### D1-S3 — Cross-check against the plan's public regulatory filing

Every ERISA plan files an annual Form 5500 with the Department of Labor — and this filing is **public data**, not something only the employer has access to. It independently confirms the plan's funding arrangement, discloses who the stop-loss carrier is, discloses which vendors get paid what, and gives participant headcounts useful for sizing an opportunity. When the filing disagrees with what the documents themselves say (e.g., the documents describe a self-funded plan, but the filing shows something else), that disagreement gets flagged for a human to resolve rather than silently picking one source over the other.

### D1-S4 — Collect the surrounding contracts, for later use

The TPA services contract, the stop-loss policy, and other vendor agreements get pulled in and categorized the same way — but in this first version, they're not deeply analyzed line-by-line the way the plan document itself is, **except for the stop-loss policy's headline terms** (carrier, deductible, whether claims are counted on a paid-basis or incurred-basis, key exclusions) — because those specific facts feed directly into the Stop-Loss Gap check in Deliverable #2. **A real, acknowledged limitation:** many clients simply won't have a stop-loss policy on file yet, so this part of the pipeline is explicitly designed to degrade gracefully rather than block anything else.

### D1-S5 — Ask a human for the facts no document can reveal

Some genuinely important facts are **not derivable from any paper at all** — most notably, whether a plan that looks self-funded is actually a level-funded arrangement, or whether a particular TPA is quietly using a specialty pharmacy vendor. A short (intentionally under ~15 questions) questionnaire captures exactly these facts from whoever handled that client's implementation. An unanswered question is treated as a real, visible "Unknown — pending" state, never silently guessed at or defaulted.

### D1-S6 — Build the actual plan profile (the heart of Deliverable #1)

This is where every plan gets scored against a standardized set of business-relevant attributes, grouped into categories: plan & document basics, funding & implementation facts, out-of-network/subrogation/PACE language quality flags, network & plan design shape, clinical carve-outs (dialysis, transplant, specialty drugs, gene therapy, behavioral health), vendor relationships, and regulatory-filing attributes. **The one non-negotiable rule governing every single field:** it must come with a **value, a source (which document/filing/human answer it came from), a confidence score, and a citation to the exact language relied on.** This is what makes the resulting dashboard something the company can stand behind in front of a client, rather than an unverifiable black-box output. When two sources disagree (say, the documents imply one funding type and the regulatory filing shows another), a documented precedence rule decides which one wins by default — but the disagreement itself is always visible, never hidden by silently picking a winner.

### D1-S7 — Human review of anything uncertain

Any field that came back below its confidence threshold, or where sources disagreed, or where it wasn't clear which plan a document even belonged to, goes into a review queue. A reviewer sees the extracted value alongside the actual quoted language it came from, and can accept or correct it with minimal effort. **Every correction becomes labeled training data** feeding back into improving the extraction engine over time — and the target operational standard is under 10 minutes of review time per plan once the system is mature. If one particular field keeps needing correction, that's treated as a signal the extraction logic (or the definition of that field itself) needs to be fixed, not that reviewers need to work harder.

### D1-S8 — The permanent record

Every plan's full profile — its documents, its attribute values, their sources and confidence and citations — lives in a permanent, versioned store. The specific business requirement driving this: **you must always be able to answer "what did we actually know when a given report went out,"** even if the underlying facts have since changed (a new amendment came in, a field got corrected). This is what everything in Deliverable #2 and the future Deliverables #3/#4 are built on top of.

### D1-S9 — The dashboard, and the actual sales use case

Once enough plans have gone through this pipeline, the data rolls up into book-of-business-level views: what percentage of plans are self-funded vs. level-funded vs. using reference-based pricing; which vendors show up most often across the whole book; what percentage of plans have outdated subrogation language, weak out-of-network language, or missing NSA protections; and which specific plans look like strong candidates for which of the company's paid services. **This is the literal mechanism behind the "we reviewed 150 of your plans and found X% have a specific problem" sales pitch** described in the vision document (`01-vision-and-strategy.md`) — and every single number on that dashboard has to be traceable back down to the specific plans and the specific cited language behind it. A stated design discipline worth calling out explicitly: **every percentage must state its denominator** (e.g., "of the 112 plans that actually have a subrogation provision on file"), and plans where a fact is simply unknown are excluded from the percentage and shown separately — inflating a number by quietly ignoring the unknowns is explicitly called out as exactly the kind of claim a sophisticated client or broker would catch and use against the company's credibility.

## Sources

- Internal document: "PDI Workflow Specification," Section 4 (Deliverable #1 — Intelligence Engine Workflow, steps D1-S1 through D1-S9)
- Internal document: "Plan Intelligence Initiative," Deliverable #1 section (Phase 1 & Phase 8)
