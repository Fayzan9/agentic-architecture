# PDA & PDASL — External Validation Analysis

**Method:** the business-requirements checklist (`pda/README.md`, `pdasl/README.md`) was checked against (1) independent external research into how the industry actually performs SPD/plan-document compliance review, and (2) **two real, complete client Plan Document Assessment deliverables** (read in full — the actual PDF reports a real reviewer sent to a real client). Client identities are not disclosed in this document; they're referred to as **Client A** and **Client B**.

## 1. What's CORRECT — strongly validated

### The checklist's topic set matches real-world findings closely
Every topic that appeared as an actual flagged finding in the two real client reports maps directly onto a topic name already present in the JSON checklist: Discretionary Authority, Fiduciary Status, Assignment of Benefits, Subrogation, Coordination with Medicare / Medicare Eligible, Essential Health Benefits, Combined Visit Limits for Therapy Services (MHPAEA), Eligibility Considerations, Reinstatement of Coverage/Rehire Provision, Termination of Coverage (Service with Armed Forces), Treatment Plans (MHPAEA), Missing Exclusions, Missing Definitions, and the full slate of Notices topics (HIPAA Privacy, ERISA Rights, NMHPA, WHCRA, GINA, MHPAEA, USERRA). **This is strong, direct evidence that the JSON checklist genuinely is (or very closely mirrors) the actual working checklist used to produce real client deliverables** — not a stale or invented reconstruction.

### The regulatory scope is right
Both real reports check exactly the frameworks the checklist targets: ERISA, ACA, MHPAEA, HIPAA, COBRA, and the No Surprises Act. External research independently confirms this is the correct, standard scope — the Department of Labor itself publishes official self-compliance tools for exactly two of these (a general "Part 7 of ERISA" tool and a dedicated MHPAEA tool), which the checklist's MHPAEA-heavy topic set (visit limits, treatment plans, residential treatment facility criteria, quantitative/non-quantitative treatment limitations) aligns with well.

### "Missing Exclusions" / "Missing Definitions" as a real, named industry concern
External research independently confirms this is a documented, real problem, not an invented checklist category: employers who rely on carrier/TPA-drafted plan documentation often get language that "represents the insurer's best interests," and "exclusions or limitations on benefit coverage" are specifically named as commonly missing or inadequate. Best practice explicitly recommends an independent review of vendor-drafted plan documents rather than accepting them as-is — which is exactly what the PDA product does.

### The three-pillar framing used in real deliverables
Both real reports organize their findings under exactly three headings: **Discretionary Authority**, **Cost-Containment**, and **Federal Law Compliance and Conflicts in the Plan Language** — and both explicitly scope out state-mandated-benefit compliance as **out of scope**. This three-pillar structure isn't explicitly named in the JSON checklist's 13 section names, but it's a real, consistent organizing frame used in the actual deliverable — worth adopting explicitly as a top-level grouping in any rebuild, with the JSON's 13 sections nested underneath it, rather than presenting 13 flat sections to a reader.

## 2. What's a DOUBT or GAP — needs attention before rebuilding

### Real reports do NOT produce one row per checklist topic — they consolidate compliant topics
This is the most important structural finding. The JSON checklist implies (and the current implementation's schema is built around) **one evaluated finding per topic** — 160 separate rows for PDA. **Real deliverables do not read this way.** Both actual reports group multiple compliant topics into a single "No Action Required" summary row per section (e.g., one row lists "Discretionary Authority, Fiduciary Status, General Plan Information" together as "the Plan does a great job of clearly stating the pertinent information" — three checklist topics collapsed into one sentence). Only non-compliant or noteworthy topics get their own individually-detailed row with the full Area for Review / Suggestion / citation.

**Consequence for a rebuild:** the report-generation step needs a **compaction/summarization pass** that groups compliant findings by section into one narrative line, and only expands individual detail for flagged items — this is a real product requirement, not an optional nicety, since it's exactly what every real deliverable actually looks like. A rebuild that emits 160 individual rows regardless of outcome would not match the real product's actual shape.

### Real reviews include bespoke, document-specific analysis that goes beyond a static checklist
Both real reports contain findings that required genuine, document-specific reasoning rather than a lookup against a fixed rule:
- **Numeric threshold checking against current-year regulatory figures** — one report flags an HDHP's deductible amounts as failing to meet "the regulatory threshold for the 2026 plan year," citing the exact current IRS minimum ($1,700 self-only / $3,400 family). This requires knowing the *current* IRS HDHP minimums at the time of review, not a static checklist entry.
- **Novel legal reasoning on a plan-specific provision** — one report contains an extended, multi-paragraph legal analysis of a surrogate-pregnancy exclusion (Pregnancy Discrimination Act interpretation, ACA preventive-care first-dollar coverage interaction, practical enforceability questions) that doesn't map onto a single named checklist topic — it's original analysis of specific plan language.

**Consequence for a rebuild:** treating PDA as a purely static, fixed-checklist review (unlike ASA's documented two-pass Checklist + Additional Observations design) would miss real, expected review behavior. **PDA likely needs its own version of an "Additional Observations" style discovery pass, or at minimum a mechanism to reason about document-specific numeric/legal questions that the static checklist can't anticipate** — this isn't currently described anywhere in `pda/README.md`, and should be added as a design requirement, not assumed away.

### The checklist itself contains content with real expiration dates
One checklist topic — "Extension of Certain Timeframes for Employee Benefit Plans Due to COVID-19" — has rationale text explaining a tolling period that **expired July 10, 2023**. A real client report using this exact topic in 2026 correctly identified the language as obsolete and recommended *removing* it, not adding it — meaning the checklist's own stored rationale can go stale, and the *correct action changes over time* for a fixed topic (first "check this is present," later "check this has been removed"). **This is a concrete, provable case of checklist content aging out of correctness** — worth treating as a canary: if this one topic has already gone stale, others likely will over time (e.g., regulatory citations, dollar thresholds, "recent" law references). A rebuild needs an explicit **checklist content review/refresh cadence**, not a "write once" assumption.

### Regulatory interpretations can be reversed after the checklist is written
One real report notes that a 2024 HIPAA rule on reproductive health privacy was **vacated by a federal court in June 2025**, and that plans still containing the old rule's language should *remove* it to avoid "improper withholding of PHI." This is the same pattern as the COVID-19 item above — a checklist topic whose correct guidance flipped due to external legal developments after the checklist was authored. Reinforces the need for a maintenance loop, not a one-time authoring effort.

## 3. What's a CONFLICT — documented design vs. observed reality

There isn't a sharp conflict between `pda/README.md` and real practice on *content* (the topics are validated, per §1) — the conflict is on **shape and completeness of the review model**:

| Documented model (`pda/README.md`) | Observed real-world practice |
|---|---|
| One evaluated finding per checklist topic (160 rows) | Compliant topics consolidated into grouped summary sentences; only flagged topics get individual rows |
| Purely fixed-checklist, no discovery pass described | Real reports contain bespoke, document-specific legal/numeric analysis not derivable from a static checklist alone |
| No explicit mention of a maintenance/refresh cycle for checklist content | Checklist content has demonstrably gone stale at least twice (COVID-19 tolling, HIPAA reproductive-privacy rule) within the observed sample window |
| No explicit scope boundary stated in the business-requirements doc | Real reports explicitly and consistently state state-mandated-benefit compliance is **out of scope** — this should be added as a stated boundary, not left implicit |

## 4. PDASL-specific notes

No dedicated real client samples exist locally for PDASL specifically (the manual-review samples available are all PDA-only). This means **PDASL's checklist has not been empirically cross-validated against a real deliverable the way PDA's has** — treat the PDASL checklist as validated only by the PDA findings above (since it shares the same engine and prompt family) and by general reasoning, not by direct evidence. This is an explicit gap: if real PDASL samples become available later, they should be read and checked the same way this document checked PDA.

## 5. Summary of required changes to the business-requirements understanding

1. Add the three-pillar (Discretionary Authority / Cost-Containment / Federal Law Compliance) organizing frame as the top-level report structure, with the 13 JSON sections nested under it.
2. Design the report-generation step to consolidate compliant topics into grouped summary lines, not one row per topic regardless of outcome.
3. Add a discovery/"Additional Observations"-equivalent capability to PDA, since real reviews demonstrably go beyond the static checklist for document-specific reasoning (numeric thresholds, novel provision analysis).
4. Add an explicit checklist content maintenance/refresh process — this is not optional, given direct evidence of the checklist going stale within the observed real-world sample window.
5. State the state-mandated-benefit exclusion explicitly as a scope boundary.
6. Flag PDASL as unvalidated by real samples — carry this forward as an open item, not a settled fact.

## Sources

- Direct reading of two real, complete Plan Document Assessment deliverables (Client A, Client B — identities withheld)
- DOL EBSA — Self-Compliance Tool for Part 7 of ERISA (Health Care-Related Provisions)
- DOL EBSA — Self-Compliance Tool for the Mental Health Parity and Addiction Equity Act
- Thomson Reuters Tax & Accounting — guidance on preparing self-insured health plan documents and the risk of relying solely on TPA-drafted documentation
- Conner Strong — "The Elusive Plan Document"
- National Law Review — guidance on comprehensive health plan compliance review
