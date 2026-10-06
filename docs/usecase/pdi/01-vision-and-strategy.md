# PDI — Vision & Business Strategy

**Source:** the vendor's "Plan Intelligence Initiative" strategy document (vision, purpose, goals, phased deliverables). This document explains the *business* motivation — why PDI exists at all, not what it technically does (see `03-` and `04-` for the workflow detail).

## The core strategic shift: reactive → proactive

The stated vision is a deliberate repositioning of the business itself:

> "Historically, our industry has operated reactively. Clients discover problems only after they have already lost money, missed opportunities, or encountered compliance issues... We will use AI to identify where clients and prospects are bleeding before they even know they have been cut."

Today, this company's existing assessment products (the equivalent of what we've documented in `../assessments/` — Plan Document Assessment, Stop Loss Gap Review, ASA Review) are **manual, one-off reviews performed when a client asks for one.** PDI's stated ambition is to turn that same subject-matter expertise into **a standing, AI-enabled intelligence platform** that runs continuously across the entire book of business — not waiting to be asked.

This is also explicitly framed as a **sales-motion change**, not just an operational one: *"Change the sales motion — from selling services to demonstrating problems and providing solutions, backed by data."* The intelligence platform is meant to generate the evidence that starts a sales conversation ("we reviewed 150 of your plans and found X% have a specific problem"), not just fulfill a request that already came in.

## Why this matters as a competitive strategy, not just a product feature

The stated long-term goal is to build **"the industry's largest and most comprehensive plan design intelligence database."** The logic: every plan document this company has ever reviewed contains reusable signal (which language patterns are common, which are risky, which correlate with which outcomes) — and if that signal is captured systematically instead of being locked inside one-off PDF reports, it compounds into a dataset no single competitor doing manual reviews could replicate. This is a data-moat strategy layered on top of a services business, not merely an efficiency automation project.

## The five goals, translated into plain terms

1. **Build the data foundation** — get every plan's governing documents, regulatory filings, and other agreements into one connected, digitized system. Start with a single pilot client, then scale to the whole book of business.
2. **Standardize classification** — agree on one common set of attributes every plan gets categorized against (funding type, vendors, language quality, etc.), so plans become comparable to each other, not just individually reviewed.
3. **Keep client-facing output concise** — a hard cap of five pages, replacing today's long-form assessment reports, validated by a human before anything reaches a client.
4. **Quantify opportunity** — every plan should come with a specific, numbers-backed statement of which of the company's other paid services it's a good candidate for.
5. **Offer remediation paths** — don't just report a problem; offer the client a menu of ways to actually fix it (see `04-deliverable-2-report-card.md` §5 for the three specific pathways).

Two further goals extend beyond PDI itself (into the initiative's other two deliverables, out of scope for this PDI-specific documentation set, but worth knowing about since they share the same underlying platform):
6. **Monitor proactively** — replace the traditional annual review with continuous monitoring of litigation/regulatory change, alerting clients as new risks emerge (Deliverable #3, "Proactive Watch Service").
7. **Automate responses** — auto-draft plan-specific response letters for the Subrogation and PR teams, grounded in that plan's actual language (Deliverable #4, "Custom Letter Generation Chatbot").

## The four deliverables, and where "PDI" actually sits

The initiative is organized into four deliverables, mapped from an original eight-phase blueprint:

| # | Deliverable | Blueprint phase(s) | One-line description |
|---|---|---|---|
| **1** | **Intelligence Engine Dashboard** | Phase 1 & Phase 8 | Ingests and classifies every plan's documents + regulatory filings into a structured, analyzable profile; rolls up into book-of-business analytics |
| **2** | **External 5-Page Report Card** | Phase 2, 3 & 4 | The client-facing deliverable: a concise compliance + cost-containment review, mapped to upsell opportunities, with remediation options |
| 3 | Proactive Watch Service | Phase 5 | Continuous regulatory/litigation monitoring with client alerts |
| 4 | Custom Letter Generation Chatbot | Phase 7 | Auto-drafts case-specific response letters for internal teams |

**"PDI" (Plan Document Intelligence) refers specifically to Deliverables #1 and #2 together** — the data/classification engine and the new report-card product it feeds. Deliverables #3 and #4 are separate, later-phase initiatives that share the same underlying platform but are not part of PDI's own scope as specified. The rest of this document set (`02` through `06`) covers PDI (Deliverables #1 and #2) in full detail.

## The closing framing, worth carrying forward as the one-sentence pitch

> "For decades we have helped clients after they were cut. This initiative allows us to identify where they are bleeding before the injury becomes visible. That is the future state."

## Sources

- Internal document: "Plan Intelligence Initiative" — Vision · Purpose · Goals · Phased Deliverables (undated, referenced as the governing initiative document in the PDI Workflow Specification dated 17 July 2026)
