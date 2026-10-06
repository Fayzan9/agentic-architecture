# PDI (Plan Document Intelligence) — Business Use Case

Business-perspective documentation of **PDI**, a strategic initiative to turn a benefits-consulting company's plan-document review expertise into a standing, AI-enabled intelligence platform. This is written entirely from the business/strategy source documents — **not from any codebase** — with independent external research layered in to separate confirmed industry fact from company-specific framing.

**How this relates to `../assessments/`:** the assessments folder documents four existing, manually-triggered review products (PDA, PDASL, SLGR, ASA). PDI is the same company's next-generation platform — it **subsumes and reformats the ideas behind those products** into one always-on system, feeding a new, concise, upsell-oriented deliverable. Several findings from the real-sample validation work in `../assessments/external_research/` carry forward directly into PDI's own risk profile — see `06-open-questions-and-risks.md`.

## What PDI actually is, in one paragraph

PDI is not one product — it's the combination of two things. First, an **Intelligence Engine** that ingests every governing document, regulatory filing, and manually-known fact for every client plan, and turns each one into a fully-cited, structured profile (a "we know this, here's exactly why we believe it" record for every attribute of every plan). Second, a **5-Page Report Card** built on top of that engine — a concise, human-approved, client-facing review that rates the plan's compliance and cost-containment posture, automatically maps every finding to the company's own paid services as an upsell/cross-sell opportunity, and recommends one of three ways to actually fix what's wrong. The strategic point of the whole thing: turn one-off manual reviews into a compounding, book-of-business-wide intelligence asset that drives sales conversations before a client even asks for help.

## Document index

| # | Doc | Covers |
|---|---|---|
| — | [`01-vision-and-strategy.md`](01-vision-and-strategy.md) | The business "why": the reactive→proactive strategic shift, the five core goals, and where PDI (Deliverables #1+#2) sits inside the larger four-deliverable initiative |
| — | [`02-domain-primer.md`](02-domain-primer.md) | The self-funded/ERISA health-plan concepts PDI has to understand: the document family, Form 5500, stop-loss, subrogation, RBP, PACE, NSA, discretionary authority, and funding types |
| — | [`03-deliverable-1-intelligence-engine.md`](03-deliverable-1-intelligence-engine.md) | Deliverable #1's full workflow (document ingestion → plan matching → Form 5500 cross-check → human intake → classification engine → human review → data store → dashboard), with a business-flow diagram |
| — | [`04-deliverable-2-report-card.md`](04-deliverable-2-report-card.md) | Deliverable #2's full workflow (assessment snapshot → criteria library → compliance review → cost-containment review → service opportunity mapping → stop-loss gap check → remediation recommendation → report assembly → approval → delivery), with a business-flow diagram |
| — | [`05-features-and-functionality-summary.md`](05-features-and-functionality-summary.md) | Every feature across both deliverables, organized by function rather than pipeline order — the quick-reference catalog |
| — | [`06-open-questions-and-risks.md`](06-open-questions-and-risks.md) | The ten explicit open business decisions from the source spec, plus additional risks identified by cross-referencing against the real-sample validation work already done for the existing assessment products |
| — | [`07-external-context-and-market-validation.md`](07-external-context-and-market-validation.md) | Independent research separating confirmed industry fact (Form 5500 as public data, RBP as a real multi-vendor category, discretionary-authority case law) from this company's own strategic framing |

## The two business-flow diagrams, at a glance

**Deliverable #1 (Intelligence Engine):** documents + regulatory filings + human-known facts → a fully-cited plan profile → a book-of-business dashboard. See `03-deliverable-1-intelligence-engine.md` for the full diagram and step-by-step detail.

**Deliverable #2 (Report Card):** a frozen snapshot of one plan's documents → a two-part compliance/cost-containment review → automatic mapping to paid-service opportunities → a remediation recommendation → a five-page, human-approved client report. See `04-deliverable-2-report-card.md` for the full diagram and step-by-step detail.

## The single most important business idea running through everything here

**Every value, finding, rating, and dollar-value claim in this system must trace back to cited language, a filing, or a named human answer — with "Unknown" always a legitimate, visible outcome rather than a silent guess.** This one discipline is what makes the difference between a system a company can defend in front of a client's own broker and lawyer, versus one that quietly erodes trust the first time a client checks a claim against their own document. It shows up in every single deliverable and workflow step documented in this folder.

## Sources

Primary sources for this entire document set:
- "Plan Intelligence Initiative" — Vision · Purpose · Goals · Phased Deliverables (internal strategy document)
- "PDI Workflow Specification — Deliverable #1 Intelligence Engine Dashboard, Deliverable #2 External 5-Page Report Card," Version 1.0, 17 July 2026 (internal functional specification)

Both documents are user-provided source material, not stored in this repository (consistent with the confidentiality handling already established for `../assessments/`) — see each individual document in this folder for section-level citations back to these two sources, plus independent external research cited where used.
