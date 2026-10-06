# PDI — Deliverable #2: External 5-Page Report Card

**What this is, in the source specification's own words:** the maximum five-page, client-facing output — explicitly **not** a 25-page assessment. Concision is stated as a hard product requirement enforced by the report template and assembly logic itself, "not by hoping the model writes less." Every claim in the report must trace back to cited plan language, and **nothing reaches a client without human approval.**

**In plain terms:** this is PDI's actual deliverable — the thing a client (or their broker) receives. It's built on top of everything Deliverable #1 already figured out about the plan, runs a two-part review, translates the findings into a menu of the company's own paid services the client might need, recommends a way to fix what's wrong, and packages all of it into something genuinely readable in one sitting.

## The business workflow, step by step

```
                              D2-S1
                    Assessment trigger & document
                     set assembly (resolve exactly
                    which document versions are in
                       force as of the review date;
                     freeze that as a "snapshot" so
                        the report is reproducible)
                                  │
                                  ▼
                              D2-S2
                       Criteria library
              (an SME-maintained set of topics + rubrics +
               Strong/Weak/Missing scoring rules + which
                 finding maps to which paid service —
                    tunable without touching code)
                                  │
                  ┌───────────────┴────────────────┐
                  ▼                                 ▼
              D2-S3                              D2-S4
        Part 1: Compliance                Part 2: Cost-Containment
        review (legal/regulatory          & best-practices review
        requirements + drafting           (subrogation strength,
        best practices — Strong /         OON/RBP posture, exclusions,
        Weak / Missing per topic)         clinical carve-outs, stop-loss
                  │                       coordination — same Strong/
                  │                       Weak/Missing mechanics)
                  └───────────────┬────────────────┘
                                  ▼
                              D2-S5
                     Service opportunity mapping
              (every finding → readiness status for each of the
                 company's paid services, with a quantified,
                     evidence-backed opportunity statement)
                                  │
                                  ▼
                         D2-S6 (conditional)
                       Stop-loss gap review
             (only runs if a stop-loss policy is on file —
                compares Plan vs. Policy for coverage gaps)
                                  │
                                  ▼
                              D2-S7
                  Remediation recommendation engine
             (based on how many/how severe the findings are,
               how old the document is, and the client's own
                 situation — recommends ONE of three fix paths)
                                  │
                                  ▼
                              D2-S8
                  Report assembly — the actual 5 pages
             (Executive Summary → Compliance Scorecard →
              Cost-Containment → Service Readiness → Pathways)
                                  │
                                  ▼
                              D2-S9
                    Human-in-the-loop review & approval
               (a person can edit, suppress, or reject anything
               — nothing is delivered without a recorded approval)
                                  │
                                  ▼
                              D2-S10
                     Delivery & intelligence loop-back
              (sent to the client; findings flow back into the
               Deliverable #1 data store, feeding the dashboard
                  and any future re-assessment of this plan)
```

## Step-by-step business detail

### D2-S1 — Decide exactly what's being reviewed, and freeze it

A review is triggered either on demand (someone requests it for one plan) or in bulk (run it across an entire book of business). The system resolves the "controlling stack" of documents Deliverable #1 already built — the base plan document plus whatever amendments are actually in effect as of the specific date being assessed — and confirms the plan's basic classification (especially funding type and ERISA status) is solid before proceeding. The exact set of document versions used gets frozen as an **"assessment snapshot,"** so that months later, the report can always be reproduced exactly as it was originally generated — a genuine accountability requirement, not a technical nicety. **Fully insured plans are explicitly out of scope for this standard review path in this first version**, since most of the findings and paid-service opportunities assume a self-funded arrangement.

### D2-S2 — The criteria library: how the company's own experts stay in control

Rather than the review logic being buried in code that only engineers can change, every topic being checked (its rubric for what counts as Strong/Weak/Missing, how much it's weighted, which paid service it feeds into, and even the exact client-facing wording used to describe a finding) lives in an **admin-configurable library that subject-matter experts own directly.** This is explicitly designed to mirror how the company's *existing* manual assessment process already works today (the same topic → criteria → guidance structure), and it's seeded from real existing internal assets: prior assessment templates, document review checklists, and a topic-coverage spreadsheet the SME team already maintains. **This means the business experts, not engineers, are the ones who decide what "good" plan language looks like — the system is built to be tuned by them going forward, not just once at launch.**

### D2-S3 — Part 1: Compliance review

This is a straightforward legal/regulatory compliance check: does the plan document actually meet ERISA disclosure requirements, follow the federal timing rules for claims and appeals decisions, address the No Surprises Act properly, handle coordination-of-benefits and Medicare correctly, get fiduciary delegation and discretionary authority right, and include the federally-required notices? Every topic gets rated **Strong, Weak, or Missing**, with the exact language relied on quoted and its location cited. A worked example from the specification: a plan whose recent amendment properly adds No Surprises Act emergency-services language rates **Strong**; the same plan's appeals section, which grants discretionary authority but names no delegated claims-review fiduciary and allows only one appeal level, rates **Weak** — with the real-world consequence spelled out plainly: this gap creates a risk that a court would review any denied claim with zero deference to the plan's own decision, and it also blocks the plan from being eligible for the company's delegated-appeals service as currently written.

### D2-S4 — Part 2: Cost-containment & best-practices review

Same Strong/Weak/Missing mechanics, but aimed at money rather than legal compliance — is the plan's language actually protecting the employer's dollars as well as it could? This covers subrogation/recovery-right strength (does the plan actually have the specific legal protections needed to recover money from a third party who caused an injury, or is the language so generic it invites the participant's own attorney to erode the recovery?), out-of-network pricing clarity and balance-billing member protections, the quality of the plan's clinical exclusions and cost-driver carve-outs (dialysis, transplant, specialty drugs, gene therapy), and whether the plan's language actually lines up with what its stop-loss policy will reimburse. **A concrete, worked illustration of "weak" vs. "strong" language for the exact same legal right** shows how directly this drives the dollar-value of the finding: generic subrogation language with no priority-of-recovery protection routinely gets eroded by the participant's own attorney taking a cut before the plan is repaid; specific, properly-drafted language protects the full recovery. The gap between those two versions of the same clause is the actual basis for a quantified claim like "updated language could increase recovery potential by an estimated 20%."

### D2-S5 — Turning findings into an upsell/cross-sell menu

Every finding from Parts 1 and 2 gets automatically translated into a readiness assessment against each of the company's own paid services:

| Service | What determines readiness | Example client-facing statement |
|---|---|---|
| **PACE** (delegated appeals) | Fiduciary delegation, discretionary authority, and appeals-structure findings from Part 1 | *"Based on current language, this plan is pre-approved for PACE implementation"* — or a specific list of what needs to change first |
| **Unwrapped** (out-of-network / balance-billing defense) | Current out-of-network pricing method plus balance-billing exposure and network shape | *"Modern plan design strategies may reduce out-of-network spend by as much as 60%"* |
| **Subrogation upgrade** | The recovery-strength score from Part 2 | *"Updated language could increase recovery potential by an estimated 20%"* |
| **ICE (consulting)** | Any Part 1 compliance finding serious enough to need expert remediation help | A named list of the findings driving the recommendation |
| **Stop-Loss Gap Review** (a specific type of ICE engagement) | Only runs when a stop-loss policy is actually on file — see D2-S6 | Named coverage gaps with a dollar-exposure framing |

**Two business guardrails are called out explicitly here, because a wrong claim in a client-facing document is a real reputational and legal exposure:** first, every quantified number (the "60%," the "20%") needs an agreed, defensible calculation method and carefully hedged wording ("as much as," "estimated") signed off by both the legal and marketing teams before it can appear in front of a client — this isn't a detail to skip. Second, the system has to check its own customer-relationship records first: **a client already using a given service must never be pitched it again as if it were a new opportunity** — and if they're already using it well, that itself becomes a *retention* talking point, not a missed opportunity.

### D2-S6 — Stop-loss gap review (only when the data is available)

Directly comparable to the standalone Stop Loss Gap Review already documented in `../assessments/slgr/` — but here it's explicitly framed as **a conditional add-on, not a guaranteed part of every report**, since many clients simply won't have their stop-loss policy on file. The comparison itself covers the same ground: does the stop-loss deductible actually match the plan's real claims profile, do the two documents define key terms (medical necessity, experimental treatment, usual & customary charges) the same way, does the policy exclude or cap something the plan document promises to cover, and are eligibility rules aligned between the two. **A vivid worked example makes the financial stakes concrete**: a plan document that covers a specific category of expensive gene-therapy treatment, paired with a stop-loss policy that excludes that exact treatment category entirely, means a single such claim (illustratively, several million dollars) would be paid entirely by the employer with **zero** stop-loss reimbursement — a severe, real financial exposure the employer very likely doesn't know it has. When no stop-loss policy is on file at all, the report says exactly that, and offers the review itself as a follow-up service — **the absence of data becomes its own call to action, not just a blank space in the report.**

### D2-S7 — Recommending how to actually fix what's wrong

Rather than just listing problems, the system automatically recommends one of three concrete remediation paths, based on how many issues were found, how severe they are, how old and how patched-together the current document already is, and what's known about the client's own situation and preferences:

| Situation | Recommended path |
|---|---|
| A few, narrow issues (say, only subrogation and No Surprises Act language); the document is otherwise sound and recent | **Option 3 — Targeted Amendments** (lowest disruption) |
| A moderate number of issues; the overall document structure is worth keeping | **Option 1 — Modified (redlined) Plan Document** |
| Many issues, an old base document, or a document that's already been patched by five or more amendments layered on top of each other | **Option 2 — New Plan Document**, built fresh on the company's own document-authoring platform |
| The plan currently uses a proprietary document format belonging to a specific large TPA that can't be rebuilt on the company's platform | Constrained to Options 1 or 3 only — **the system has to know whose paperwork it's actually looking at** before recommending a full rebuild |

A deliberate, explicitly-stated tone discipline governs this whole step: the report is meant to **present options and readiness, not push the client toward a specific decision** — a subtle but important distinction for a document that's simultaneously an upsell tool and something meant to read as objective, trustworthy analysis.

### D2-S8 — Assembling the actual five pages

| Page | Content |
|---|---|
| **1 — Executive Summary** | Who the plan is, its overall health, the top 3–5 findings in plain English, the recommended fix path, and a quick snapshot of service readiness |
| **2 — Compliance Report Card** | The Part 1 findings as a topic-by-topic Strong/Weak/Missing scorecard, with the most important quotes — this is also where a Plan Document/SPD conflict, if one exists, gets surfaced |
| **3 — Cost-Containment & Best Practices** | The Part 2 findings — subrogation strength, out-of-network posture, exclusions, stop-loss alignment |
| **4 — Service Readiness & Opportunity** | The upsell/cross-sell mapping from D2-S5 and the stop-loss gap findings from D2-S6 |
| **5 — Remediation Pathways** | The three options compared side by side for this specific plan, with the recommended one clearly flagged |

If there's more material than fits in the page budget, the **assembly process automatically summarizes** rather than letting the report grow past five pages — the full, unabridged set of findings always still exists underneath as the internal system-of-record; the five-page card is specifically the client-facing artifact, not the whole analysis. The required tone throughout: factual, tied to citations, explicitly not legal advice, with a standard disclaimer.

### D2-S9 — A human has to sign off before anything goes out

A reviewer sees the full draft report alongside the complete underlying finding set, and can edit any rating (with a reason), rewrite client-facing wording, remove a finding entirely, change the recommended remediation path, or reject the whole thing outright. **No report can leave the system without a recorded approval event** — who approved it, when, and against which exact version. Every edit a reviewer makes is captured as structured feedback and becomes the raw material for measuring how often the automated system and a human expert actually agree — a metric the specification calls out as something that should be published per release, with topics that fall below an acceptable agreement rate getting their underlying logic fixed before the system is allowed to run at greater scale on that topic.

### D2-S10 — Delivery, and feeding the whole system's long-term value

Once approved, the report goes out to the client through the normal delivery channel. But the more strategically important thing that happens here is invisible to the client: **the findings, ratings, service opportunities, and chosen remediation path all flow back into the Deliverable #1 data store** — which is exactly what turns a series of individual client reports into the aggregated market-intelligence asset described in the vision document. A later re-assessment (triggered by a new amendment coming in, a meaningful update to the criteria library, or simply a client asking again) produces a new, dated version of the report with a **delta view showing exactly what's changed** since the last one.

## Sources

- Internal document: "PDI Workflow Specification," Section 5 (Deliverable #2 — 5-Page Report Card Workflow, steps D2-S1 through D2-S10)
- Internal document: "Plan Intelligence Initiative," Deliverable #2 section (Blueprint Phases 2, 3 & 4)
