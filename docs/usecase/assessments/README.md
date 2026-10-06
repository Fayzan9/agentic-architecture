# Sophia Standalone Reviews — Assessment Business Requirements

Business requirements and reference data for four employee-benefits-plan assessment products. Two kinds of content live here — tracked in git very differently, see the warning below:

1. **Our own written business-requirements docs** (`*/README.md`, `cross-cutting-business-rules.md`) — a pure business-logic extraction: what each assessment checks, why, and what it produces. Deliberately excludes implementation details. Tracked in git normally.
2. **Raw source data** (`*/data/`) — the client-provided checklists (JSON), report templates, reference PDFs, and real client manual-review samples, copied in for local reference when building agents. **Gitignored — never committed.** See "⚠️ Data handling" below.

**This is a from-scratch design, not a port.** The old codebase's implementation (its Python prompt templates, its internal schemas, its LLM-calling logic) is deliberately **not** carried over — only the underlying business data that came from the client (the JSON checklists) and the real-world reference/sample material. The new system's evaluation logic, agent design, and prompts will be authored fresh under this project's own architecture (`docs/architecture/`).

## ⚠️ Data handling — read before touching `*/data/`

**This repository is public on GitHub.** Every `docs/usecase/assessments/*/data/` folder is listed in `.gitignore` and must stay that way — it contains:

- **Real, client-identifying documents**: actual employer plan documents (SPDs), ASA contracts, and manual review write-ups for named clients (see the `manual_reviews/` folder under `pda/` and `asa/`).
- **Vendor-provided proprietary/licensed reference material**: the ASA guide, template, addenda, and troubling-provisions PDFs under `asa/data/reference/`.
- **Client-provided product data**: the JSON checklists themselves.

None of this should ever be pushed to the public remote. If you add new files under any `*/data/` folder, verify they're still ignored with `git check-ignore -v <path>` before staging anything. If you ever need to share this repo's history with someone outside this trust boundary, audit for accidental commits of this data first.

## What Sophia's standalone reviews are

Four related but distinct assessment products, all serving self-funded employer health plans and their advisors/counsel, each answering a different underlying question about a different pair (or single set) of documents:

| Assessment | Question it answers | Document(s) | Folder |
|---|---|---|---|
| **Plan Document Assessment (PDA)** | Is this Plan Document / SPD compliant with a fixed checklist of regulatory and drafting requirements? | Plan Document / SPD | [`pda/`](pda/README.md) |
| **Targeted Stop Loss Review (PDASL)** | On a curated set of known-risky topics, could a mismatch between the Plan and the Stop Loss Policy leave the employer under-reimbursed? | Plan Document + Stop Loss Policy | [`pdasl/`](pdasl/README.md) |
| **Stop Loss Gap Review (SLGR)** | For every topic in a dedicated checklist, does the Stop Loss Policy's language, as written, create a quantifiable financial gap versus what the Plan is obligated to pay? | Plan Document + Stop Loss Policy (+ Amendments/Endorsements) | [`slgr/`](slgr/README.md) |
| **ASA Review** | Is this Administrative Services Agreement complete, risk-balanced, and negotiation-ready for the party we represent? | ASA contract + ASA Guide (+ Template/Addenda/Troubling-Provisions in the target design) | [`asa/`](asa/README.md) |

**[Cross-Cutting Business Rules](cross-cutting-business-rules.md)** — read this too: it captures what's genuinely shared across all four (the finding shape, the evidence-first grounding rule, the manual-review reconciliation/QA process) versus what's deliberately different (severity vocabularies, single- vs. two-document comparison, compliance vs. financial-risk vs. negotiation-materiality judgments) — important for deciding what to build once as shared harness infrastructure versus what needs to stay assessment-specific.

## Folder structure

```
assessments/
├── README.md                          — this file
├── cross-cutting-business-rules.md    — shared rules across all four assessments (tracked)
├── pda/
│   ├── README.md                      — PDA business requirements (tracked)
│   └── data/                          — gitignored
│       ├── plan_document_assessment.json   — the full 13-section, 160-topic checklist (client-provided)
│       ├── templates/pace_review_summary_template.docx
│       └── manual_reviews/            — real client SPDs + gold assessments (3 client samples — real client names on local disk only, gitignored, never exposed publicly)
├── pdasl/
│   ├── README.md                      — PDASL business requirements (tracked)
│   └── data/                          — gitignored
│       └── targeted_stop_loss_review.json  — the 24-topic checklist (client-provided)
├── slgr/
│   ├── README.md                      — SLGR business requirements (tracked)
│   └── data/                          — gitignored
│       ├── stop_loss_gap_review.json       — the 4-section, 50-topic checklist (client-provided)
│       └── templates/Stop Loss Gap Review Template.docx
└── asa/
    ├── README.md                      — ASA business requirements: current + target design (tracked)
    └── data/                          — gitignored
        ├── reference/                      — asa_guide.pdf, asa_template.pdf, asa_addenda.pdf, asa_troubling_provisions.pdf
        ├── templates/asa_review_summary_template.docx
        ├── design/asa_new_implementation.md — the product team's original redesign note (primary source for asa/README.md's target design)
        └── manual_reviews/             — real client ASA contract + gold assessment (1 client sample — real client name on local disk only, gitignored, never exposed publicly)
```

**Deliberately not carried over:** the old codebase's LLM prompt templates and internal shared code (data schemas, prompt constants, the reconciliation/scoring script). Those are the *old implementation* — this project's agents will have their own prompts and evaluation logic, designed fresh under `docs/architecture/`. The `why_this_is_important` / `prompt` / `sample_suggestions` text already summarized into each assessment's `README.md` captures the business rules those old prompts encoded, without carrying the implementation forward.

## How to use this for building new agents

Per this project's architecture (`docs/architecture/v1/13-future-facing-ui-builder-readiness.md`), each of these four assessments is a natural candidate for a **Template** — a pre-vetted, pre-configured bundle (document ingestion + a fixed checklist + evidence-grounding enforcement + a verdict rubric + a report format) that a future builder UI could let someone instantiate and parameterize, without touching the harness/sandbox/deployment machinery underneath. Concretely, when building the first real agent from this material:

1. Start with **one** assessment (per `docs/architecture/v1/12-roadmap-and-build-sequence.md`'s Phase 0 — prove the walking skeleton on one capability before expanding). PDA is the most structurally complete starting point (a real JSON checklist already exists, and the compliance model is simplest).
2. Treat the checklist content — including each topic's `why_this_is_important` / `prompt` / `sample_suggestions` text in the raw JSON files — as **the business rule to satisfy**, not a prompt to reuse verbatim. The JSON's `prompt` field describes *what a compliant answer looks like*; the actual prompt/agent instructions that evaluate it should be authored fresh, under this project's own harness (evidence-grounding, evaluation, audit trail per `docs/architecture/v1/04-agent-harness-and-sandboxing.md` and `09-observability-audit-cost-and-ratelimiting.md`).
3. Use the **real client samples** under each assessment's `data/manual_reviews/` for eval-set construction (`docs/architecture/v1/05-evaluation-and-feedback-loops.md`) — the `documents/` subfolder is the input, the `assessment/` subfolder is the human gold-standard output. This is exactly the kind of real, already-labeled data the eval-driven-development methodology (`docs/architecture/v1/guidelines/02-build-order-and-methodology.md` §2) says to start from, rather than inventing synthetic test cases.
4. Build a **manual-review reconciliation** capability (`cross-cutting-business-rules.md` §4) alongside the assessment itself, not as an afterthought — the old system's version of this is gone (see note above), but the *concept* — compare automated findings against a human analyst's write-up, on the assumption that silence in the human write-up means "compliant" — is a real business requirement worth rebuilding, and it maps directly onto this project's eval/feedback-loop design.
