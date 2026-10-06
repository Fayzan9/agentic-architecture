# Cross-Cutting Business Rules — All Assessments

Business logic and conventions shared across **PDA**, **Targeted Stop Loss Review (PDASL)**, **Stop Loss Gap Review (SLGR)**, and **ASA Review**. Read this alongside the per-assessment docs — it exists so shared rules are stated once instead of repeated (and risking drift) in every assessment doc.

## 1. The shared output shape ("Finding")

Every assessment ultimately produces a list of findings with a common core shape, even though field names and a few assessment-specific fields differ:

| Concept | PDA / PDASL field | SLGR field | ASA field (target design) |
|---|---|---|---|
| Which section this belongs to | `title` | `title` | `section_name` |
| Which checklist item | `topic` | `topic` | `topic` / `topic_id` |
| The verdict | `Compliant` (Yes/No/Not Sure) → `model_polarity` (yes/no/unknown) | `gap_assessment` (hard_gap/soft_gap/no_gap/not_sure) | `status` (present/missing/one_sided/relocated/n_a) |
| Quoted evidence | `Cited_Text` / `Plan_Cited_Text` / `Policy_Cited_Text` | `text_in_plan` / `text_in_stop_loss_policy` | `asa_contract_text` |
| Business rationale | `why_this_is_important` | (mostly via `sample_suggestions` worked examples instead) | `guide_or_template_anchor` |
| The recommendation | `Suggestion` | `suggestion` | `suggestion` |
| Severity | *(not scored — PDA/PDASL is binary compliant/non-compliant, not tiered)* | gap tier itself carries the severity (hard > soft > none) | `criticality` (low/medium/high) |
| Page reference | `Page_References` | *(full-document, no page tagging)* | *(not used — contracts aren't paginated the same way)* |

**Design implication for future agents:** these are the same underlying concept (a checklist-driven finding with evidence, a verdict, and a recommendation) expressed with different vocabularies per assessment because each was built independently over time. When building a config-driven agent/workflow layer (per `docs/architecture/v1/13-future-facing-ui-builder-readiness.md`), this is exactly the kind of variance that should be normalized into one canonical `Finding` schema with assessment-specific enums, not four different one-off schemas carried forward as-is.

## 2. The evidence-first / grounding rule (identical across all four assessments)

Every assessment enforces the same non-negotiable rule, worded slightly differently each time it's implemented:

> **A verdict may never be given without evidence.** A compliant/non-compliant/gap verdict requires a verbatim quote from the source document(s), or an explicit statement that the relevant language is absent. Never invent quotes, page numbers, or section names. If the decisive language cannot be found, the verdict must be "Not Sure" / "not_sure" — not a guess.

This rule is reinforced by a **two-pass reviewer → critic pattern** in every assessment that has one implemented (PDA, PDASL, SLGR): a first-pass "reviewer" draft is independently re-verified by a "critic" step whose entire job is to check citation integrity and re-apply the verdict rule before the finding is finalized — never to re-review from scratch. ASA's target design carries the same principle forward as "code owns citation verify."

## 3. Severity / criticality vocabularies (three different scales, by design — not an oversight)

| Assessment | Scale | What it measures |
|---|---|---|
| **PDA / PDASL** | Binary: Compliant / Non-Compliant (+ Not Sure) | Does the Plan satisfy a discrete requirement? No graded severity — a compliance gap is a compliance gap. |
| **SLGR** | Four-tier: Hard Gap / Soft Gap / No Gap / Not Sure | How mechanically certain is the financial exposure — a hard gap is a quantifiable dollar risk, a soft gap is an interpretive risk. |
| **ASA** | Three-tier: Low / Medium / High | How material is the issue to the party's negotiating position — a materiality judgment, not a compliance or financial-mechanism judgment. |

These are **not interchangeable** and should not be collapsed into one universal "severity" scale without care — SLGR's tiers are about reimbursement mechanics specifically (the "reimbursement-impact test"), while ASA's tiers are about negotiation materiality, and PDA's binary is about regulatory/drafting compliance. A future shared schema should keep these as distinct, assessment-typed enums rather than forcing one meaning onto all three.

## 4. Manual-review reconciliation ("gold evaluation") — a QA process shared across PDA, SLGR, and ASA

All three assessments (this pattern is not yet built for PDASL specifically, but shares the same shape) support **reconciling an automated review's output against a human analyst's Manual Review** of the same documents, to measure agreement. This is a real, standing QA capability, not a one-off audit:

- **Input**: the full text of a human analyst's Manual Review write-up (their gold-standard findings) plus the automated review's own findings list.
- **Rule**: a human write-up **only calls out problems** — if a checklist topic is never mentioned in the Manual Review, the reconciliation defaults its "gold" conclusion to **compliant/no-gap**, since silence in a human write-up means no issue was found there. This default-to-compliant-on-silence rule is applied consistently across PDA, SLGR, and ASA.
- **Per-topic comparison**: for every topic the automated review assessed, determine independently (from the Manual Review's own language, not by copying the automated review's conclusion) whether the human reviewer would call it compliant or non-compliant, then compare the two verdicts.
- **Agreement classification**: `match` / `mismatch` / `partial` (used when the automated verdict was "Not Sure"/"unknown") / `not_applicable` (for assessment types without a compliant/non-compliant polarity concept).
- **Missed items**: the reconciliation also surfaces any issue the Manual Review raised that has no counterpart anywhere in the automated review's checklist — i.e., topics the automated review didn't think to ask about at all. This is the mechanism that should feed **ASA's "promote over time" rule** (`asa/README.md`) and, more generally, any assessment's checklist maintenance — a recurring missed item is evidence the fixed checklist itself needs a new topic.

**Business significance:** this reconciliation process is effectively Sophia's built-in **accuracy measurement and continuous-improvement mechanism** against real expert judgment — directly analogous to the "trace sampler → error analysis → eval harness" loop already specified in `docs/architecture/v1/05-evaluation-and-feedback-loops.md` §2 and the "daily human review feeds the regression suite" practice in `docs/architecture/v1/guidelines/02-build-order-and-methodology.md` §3. When rebuilding these assessments as agents under the new architecture, this reconciliation capability should be treated as a first-class requirement, not an optional extra — it's the existing product's own answer to "how do we know the agent is actually right."

## 5. Documents & artifacts, by assessment

| Assessment | Documents required | Optional add-ons |
|---|---|---|
| **PDA** | Plan Document / SPD | — |
| **PDASL** | Plan Document / SPD + Stop Loss Policy | — |
| **SLGR** | Plan Document + Stop Loss Policy | Plan Amendments (multiple), Policy Endorsements (multiple) — later language always controls over the base document |
| **ASA** | ASA contract + ASA Guide (reference material, not the contract itself) | Template, Addenda reference, Troubling Provisions library (target design only — see `asa/README.md`) |

**Amendment/Endorsement handling rule (SLGR, and PDASL where applicable):** if a topic is addressed in an Amendment/Endorsement, that language is controlling and gets consolidated with any surviving base-document language on the same topic. If the Amendment/Endorsement *removes* language the base document had on a topic, the topic is treated as no longer present at all — not as "present in the base document."

## 6. Report deliverable

Every assessment's end product is **two things, not one**: (1) a structured findings list (JSON-serializable, one row per checklist topic/observation) and (2) a formatted **Word (.docx) report** for the client, built to match the visual conventions (columns, colors, highlighting) clients already expect from prior manual/hybrid deliverables. Any agent rebuild should treat both outputs as required — the structured data alone is not the product; the formatted report is what the client actually receives.

## 7. What is genuinely different across the four assessments (don't over-normalize this away)

- **PDA** is single-document, checklist-driven, binary-compliance.
- **PDASL** is the same checklist mechanism as PDA but two-document (Plan vs. Policy), still binary-compliance.
- **SLGR** is two-document but *not* compliance-driven — it's a financial-risk classification (the reimbursement-impact test) with a fundamentally different question being asked, plus a Policy-only analysis mode for topics with no Plan-side counterpart.
- **ASA** is the only one that is not a fixed-topic-per-document-pair review at all today — it's an open-ended, guide-informed legal/operational analysis (moving toward a fixed-checklist-plus-discovery two-pass model, per the target design), and it's the only assessment with an explicit **party perspective** input that changes what counts as a finding.

When designing shared agent/tool infrastructure (per `docs/architecture/v1/13-future-facing-ui-builder-readiness.md`'s Template concept), these four should likely be four distinct **templates** sharing a common harness (document ingestion, evidence-grounding enforcement, reviewer→critic verification, manual-review reconciliation) — not one generic "assessment agent" configured four different ways, since the actual judgment being made (compliance vs. financial-mechanism vs. negotiation-materiality) differs in kind, not just in checklist content.
