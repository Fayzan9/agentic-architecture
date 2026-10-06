# External Research & Validation

Independent, externally-sourced research into (1) who The Phia Group is and whether their methodology reflects genuine industry practice, and (2) a detailed, evidence-based analysis of each assessment's business-requirements checklist — validated wherever possible against **real client deliverables**, not just the checklist data or narrative design docs alone.

## Methodology

For each assessment, this research pass:
1. Read the assessment's full reference material (JSON checklists, reference PDFs, templates) directly — not just the summaries in `../{pda,pdasl,slgr,asa}/README.md`.
2. Conducted external research (via web search) into how the self-funded employee benefits industry actually performs this kind of review — law firm guidance, DOL/regulatory publications, trade association (SIIA) material, and general contract-review methodology where relevant.
3. **Where a real client manual-review sample exists locally**, read it in full and cross-checked the checklist/design docs against what a real, finished deliverable actually contains and looks like. This is the strongest form of validation used here — external research confirms a *concept* is sound industry practice, but only a real sample confirms whether *this specific checklist, as written*, produces what clients actually receive.
4. Findings are organized consistently in each document: **what's correct** (validated), **what's a doubt/gap** (needs attention but not necessarily wrong), and **what's a conflict** (a real, demonstrated mismatch between documented design and either external practice or real-world evidence).

**Client identities are never disclosed in these documents** — real samples are referred to generically (Client A, Client B, Client C) even though these documents are tracked in git (unlike the raw sample files themselves, which stay local-only per `../README.md`'s data-handling rules).

## Documents

| Doc | Real sample coverage | Headline finding |
|---|---|---|
| [`phia-group-background.md`](phia-group-background.md) | N/A (company research) | The methodology is independently validated as genuine, mainstream industry practice by an unaffiliated national ERISA law firm — not proprietary or fringe |
| [`pda-and-pdasl-analysis.md`](pda-and-pdasl-analysis.md) | 2 real PDA samples read in full; **PDASL has no dedicated samples — unvalidated** | Real deliverables consolidate compliant topics into grouped summary lines rather than one row per checklist topic, and include bespoke document-specific analysis (e.g., checking actual numbers against current-year IRS thresholds) that goes beyond the static checklist |
| [`slgr-analysis.md`](slgr-analysis.md) | **None — no real SLGR sample exists locally** | "Hard gap / soft gap" is not standardized industry terminology (vendor-specific); this checklist has the least empirical validation of the four and should be prioritized for real-sample cross-checking before being treated as production-ready |
| [`asa-analysis.md`](asa-analysis.md) | 1 real ASA sample read in full (contract + actual reviewer comments) | **The real deliverable is an inline-commented contract markup, not a structured findings table** — this conflicts with both the current implementation's output shape and the target redesign's documented finding schema, and is the single most consequential finding across all four assessments |

## How this changes the "how to use this for building new agents" guidance in `../README.md`

The parent README's guidance to treat the checklist content as "the business rule to satisfy" still holds — but these documents add a layer that must be read before building: **for ASA specifically, the deliverable's actual shape (inline annotation vs. structured report) is an open design decision, not something to infer from the existing schemas.** For SLGR, the checklist's real-world accuracy is unconfirmed and should be the first thing validated with a real sample before investing further build effort. For PDA, the checklist content itself is strongly validated, but the report-generation logic (compaction of compliant findings, a discovery pass for document-specific reasoning, and a content-refresh cadence) needs design work beyond what a literal reading of the checklist would suggest.
