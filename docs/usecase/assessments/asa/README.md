# Administrative Services Agreement (ASA) Review — Business Requirements

**Reference data:** `data/design/asa_new_implementation.md` (gitignored, local only) — the product team's redesign methodology note (target/not yet implemented), captured below alongside the current-state approach because both describe the same business problem at two different points in a redesign; when building new agents, prefer the **target design** unless told otherwise.

## What an ASA is, and what this review does

An **Administrative Services Agreement (ASA / ASO)** is the contract between:

| Party | Typical role |
|---|---|
| **Plan Sponsor** (employer / plan) | Funds claims; usually retains ERISA fiduciary role |
| **Claims Administrator / TPA** | Adjudicates claims, eligibility, reporting, often network/IDR support — **not** the insurer unless structured that way |

In self-funding, the ASA is the operating manual for **who does what, who pays whom, who is a fiduciary, how stop-loss works, and how HIPAA / NSA / CAA duties are split**.

**This is not a PDA-style "Compliant Yes/No" checklist review.** It is benefits-counsel / consulting due diligence, answering:

1. Is the contract **complete** for how this plan will actually run?
2. Is risk **balanced** for the party the review represents?
3. Does language create **ERISA, HIPAA, NSA, stop-loss, or funding** problems?
4. What should be **negotiated / amended** before signature or renewal?

**Client-facing product:** a prioritized negotiation memo — topic, quoted provision, why it matters, recommended change, severity — not a free-form essay per section.

**Input documents:** the ASA contract, plus an ASA reference guide (a PDF or plain text — see "Reference kit" below).

**Perspective is a required input**: every finding is generated from the standpoint of either the **Plan Sponsor** or the **Claims Administrator** — the same clause can be a risk for one and a non-issue (or even a benefit) for the other.

## Reference kit (vendor-provided ASA review assets)

Four reference assets exist and each has a distinct job in the review — a well-built ASA agent should use all four, not just the guide:

| Asset | Role |
|---|---|
| **ASA Guide** (`asa_guide.pdf`) | Section playbook: Purpose → What to Look For → Best Practices → Common Issues → sample fix. This is the review's checklist *structure*. |
| **Template** (`asa_template.pdf`) | Preferred/balanced market language, including `[OPTION]` clauses (e.g. NSA Option 1 vs. 2) — used as *target* language for negotiation, not the only "correct" ASA. |
| **Addenda reference** (`asa_addenda.pdf`) | Expected attachments: fee schedule, CAA disclosure, BAA, COBRA/HIPAA admin, etc. — "addenda review" = are these present and complete? |
| **Troubling Provisions** (`asa_troubling_provisions.pdf`) | A red-flag library of known bad patterns from real carrier ASAs (BCBS, Cigna, Anthem) — pattern-match before inventing new issues. |

```
Contract under review
        ├─► Guide checklist     → completeness + common gaps
        ├─► Template            → "preferred / balanced" comparison
        ├─► Troubling library   → known carrier landmines
        └─► Addenda pack        → required exhibits (BAA, fees, CAA, COBRA…)
```

## Current-state approach (pre-redesign)

- **18 fixed sections**, evaluated as an open-ended legal/operational analysis (not a fixed topic checklist): Preamble and Recitals, Definitions, Financial Arrangements, Responsibilities of the Plan Sponsor, Responsibilities of the Claims Administrator, Claims Processing and Payment, Compliance with Laws and Regulations, Fiduciary Status, Liability Limitations, Confidentiality and Data Security, Termination Provisions, Dispute Resolution, Indemnification, Audit Rights, Performance Guarantees, Recent Regulatory Updates, Miscellaneous Provisions, Addenda — plus a final **Additional Observations** section.
- For each section, the model is given the full ASA contract text and the ASA Guide and asked to identify: conflicting/inconsistent language, vague/ambiguous provisions, unbalanced risk allocation, regulatory compliance gaps, and missing/inadequate safeguards — using the Guide as a **framework**, explicitly not a mandatory checklist.
- Each finding produced: `topic`, `asa_contract_text` (verbatim, or an explicit absence statement), `asa_guide_text` (the relevant guide excerpt), `suggestion` (a multi-part narrative: issue → why it's critical → risk to the party → benefit of fixing it), `criticality` (low/medium/high).
- **Materiality discipline already present in the current prompt**: do not flag a missing provision unless the absence is *materially* problematic; if a concept is covered elsewhere under different wording, acknowledge that and don't recommend redundant language; only recommend additions that address real-world risk, not stylistic preference.
- **Documented weaknesses in this current approach** (from the product team's own redesign note, not a code-implementation detail): the model invents topics rather than following a fixed checklist, so topic coverage drifts run to run; the Guide's structure is often underused; the full contract + guide is stuffed into every section call regardless of relevance; the Template/Addenda/Troubling-Provisions references are largely unused; and suggestions are essay-length rather than negotiation-ready.

## Target design (from the product team's redesign note — apply this when building new agents)

### Two-pass structure: Checklist (Pass A) + Additional Observations (Pass B)

> **Checklist (Pass A)** = systematic coverage of known ASA risks, via a **fixed** per-section item list (not model-invented headings).
> **Additional Observations (Pass B)** = residual, contract-specific risks that survive a high-materiality + no-duplicate filter, run *after* the checklist pass.

**Pass A — fixed checklist:**
- Sections stay a stable map (the same 18-section list above, refined to fold "Scope of Services" explicitly into Claims Administrator responsibilities / Claims Processing rather than leaving it an invisible gap).
- Topics *within* each section become a fixed, durable checklist derived from the Guide's own "What to Look For / Common Issues" content (see example items below) — the model scores each item as `present` / `missing` / `one-sided` / `relocated` / `N/A`, and a finding is only raised when the issue is **material** to the party.

**Example checklist items** (illustrative, not exhaustive — derive the full set from the Guide):
- *Fiduciary Status*: Is there an explicit disclaimer that the TPA is not a fiduciary unless delegated? Does other language (payment methodology, cross-plan offsets) *create* discretion that contradicts that disclaimer? Is optional fiduciary delegation documented correctly?
- *Financial Arrangements*: Are all fees disclosed (including value-based / network-access / PBM-related)? Is the claims funding timeline clear? For stop-loss reimbursement — who receives it, on what timing, and is it credited back to the plan account?
- *Claims / NSA*: Who owns QPA / IDR / open negotiation? Does the contract dump all NSA compliance on the sponsor without a corresponding service/fee?
- *Addenda*: Is the fee schedule present and complete? Is a BAA present and does it cover required HIPAA/HITECH elements? Is a CAA/compensation disclosure present where applicable? Are selected optional exhibits (e.g. COBRA) actually attached?

**Party posture — same clause, different ask:**

| Perspective | Emphasize |
|---|---|
| **Plan Sponsor** | Funding timelines, stop-loss credit, audit rights, overpayment liability, fiduciary clarity, fee transparency (CAA), NSA/IDR control, termination/runout, rebate/value-based fees |
| **Claims Administrator** | Clear eligibility/funding duties of the sponsor, limitation of liability, indemnification for plan-design errors, ability to follow the Plan Document, optional service fees, no open-ended compliance dump without fee |

Every finding answers **"risk to `{party}`"** — never "is this pretty."

**Materiality rules (avoid crying wolf):**

| Absence / deviation | Typical treatment |
|---|---|
| Missing NSA/IDR ownership, funding deadline, stop-loss credit path, BAA, audit rights | Often **high/medium** |
| Style difference from template; clause present under another name | **Not a finding** — note "covered elsewhere" |
| Optional commercial choice (e.g. SBC only if elected) | Clarification / fee discussion, not "violation" |
| Troubling-pattern match (cross-plan offset, void coverage on assignment, rebate for TPA's own benefit) | Flag even if "common in carrier paper" |

**Pass B — Additional Observations:**

- Captures novel, contract-specific, or carrier-idiosyncratic issues **not** on the fixed checklist — the model's residual "is there something dangerous we didn't anticipate?" pass, run only after Pass A is complete.
- **What belongs**: strange fee/rebate/network-access mechanics not covered by the Guide's fee topics; cross-plan offset, silent IP assignment, odd opt-out amendment mechanics; delegation to affiliates with weak sponsor veto; SPD/ASA conflicts unique to this paper; state- or product-specific traps; internal contradictions (e.g. fiduciary disclaimer vs. broad payment discretion).
- **What does NOT belong**: restating a checklist miss under a new name; style/"could be clearer" complaints with no real-world harm; generic ERISA lectures with no quote from *this* contract; optional commercial choices already disclosed as electable; anything that maps to an existing checklist item (**rule: if it maps to a checklist ID, update that row — don't open a new observation**).
- **Guardrails**: a materiality gate (regulatory/financial/operational disruption only — soft preferences get omitted or capped in volume); a dedup gate against Pass A findings (same quote or same risk → drop); a volume cap (e.g. top 5–10 by criticality, more only if genuinely high-severity); an evidence requirement (verbatim provision, or an explicit "absent but material" tied to a concrete expected control); a perspective filter (Plan Sponsor vs. Claims Administrator changes what's worth raising); and a **promotion rule** — if the same observation recurs across many ASAs, it should graduate into the fixed checklist (or the Troubling Provisions library) rather than staying a one-off every time.
- **Criticality for observations uses a stricter bar** than the checklist: **High** = would block signature or clear fiduciary/money/compliance exposure; **Medium** = real negotiation point, ops or enforceability risk; **Low** = clarifying question only. When unsure whether something is a checklist item or an observation, **prefer checklist** if the theme already exists.

### Target finding schema

```json
{
  "section_name": "Financial Arrangements",
  "topic_id": "fin.stop_loss_reimbursement_timing",
  "topic": "Stop-loss reimbursement timing",
  "source": "checklist | additional_observation",
  "status": "present | missing | one_sided | relocated | n_a",
  "asa_contract_text": "verbatim quote or explicit absence statement",
  "guide_or_template_anchor": "optional short best-practice / sample language",
  "suggestion": "short recommendation + why it matters to {party}",
  "criticality": "low | medium | high",
  "why_not_on_checklist": "only for additional_observation"
}
```

**Criticality rubric (shared across Pass A and Pass B):** **High** = regulatory/fiduciary/financial exposure to the party; **Medium** = operational ambiguity or enforceability risk; **Low** = clarification/tidy-up.

### End-to-end review order (why this order, not alphabetical-by-section)

Money and fiduciary issues should never end up buried under "Miscellaneous" — the target process reviews in this order, matching how human counsel actually works a deal:

1. **Deal map** — parties, self-funded vs. insurer language, Plan Document supremacy, services in/out of scope
2. **Money** — fees, funding, stop-loss, overpayments, rebates, value-based charges
3. **Fiduciary & discretion** — disclaimer vs. actual authority
4. **Claims ops** — adjudication standard, appeals/PACE, NSA/IDR, EOBs, subrogation
5. **Compliance wrappers** — BAA/HIPAA, CAA disclosure, gag clause, state items
6. **Exit & enforcement** — termination, runout, records retention, audit, dispute, indemnification, liability caps
7. **Addenda completeness** — fees, BAA, disclosure, selected exhibits
8. **Pass B (Additional Observations)** — residual discovery with materiality + dedup + volume cap

### Redesign principle (the intended split of responsibility)

> Code owns determinism (checklist IDs, absence policy, citation verify, merge keys). AI owns reading the contract and applying party-aware materiality. Do **not** force the PDA's Compliant Yes/No shell onto ASA — the two products answer structurally different questions.

### Success metrics for this redesign (as defined by the product team)

- **Topic coverage stability** — same contract, same run → same checklist item set across repeated runs
- **Citation validity** — non-empty cites substring-match the actual contract text
- **False-positive rate** on "missing" items that are actually present under another name
- **Additional Observation quality** — high percentage material and non-duplicate on spot-check
- **Criticality agreement** vs. human counsel on a small gold set
- **Tokens/latency** vs. today's full-document × 18-section baseline

## Notes

- This document intentionally preserves both the current (pre-redesign) and target shapes because the redesign has not shipped as of this capture — treat the **target design** as the actual business requirement to build against, and the current-state approach as context for what's changing and why.
- Unlike PDA/PDASL/SLGR, ASA has **no JSON topic checklist file today** — the target design's fixed checklist is meant to be *derived from* the Guide PDF, not hand-authored the way PDA's `plan_document_assessment.json` is. Building that derivation (or hand-authoring the checklist once, informed by the Guide) is a prerequisite for implementing Pass A.
