# PDI — Features & Functionality Summary

A consolidated catalog of PDI's actual features, pulled out of the step-by-step workflow narratives in `03-` and `04-` and organized by function rather than by pipeline order. Use this as a quick reference; use `03-` and `04-` for the full business reasoning behind each one.

## 1. Document handling

- Multi-source ingestion: pulls documents from the company's document repository, its own plan-document-authoring platform (treated as highest-fidelity when present), and ad-hoc uploads.
- OCR with page-position preservation (citations depend on knowing exactly where language sits).
- Per-page quality/confidence scoring; rejects or flags unreadable, incomplete, or password-protected files.
- Document-type detection (Plan Document vs. SPD vs. combined vs. wrap vs. amendment vs. not-a-governing-document at all).
- Staleness detection — a superseded document is flagged, not silently treated as current.
- Handles documents ranging from single-page amendments to 150+ page full plan documents through the same pipeline.

## 2. Plan/document matching & version control

- Entity resolution across documents with fuzzy name matching (the same employer may appear under slightly different legal names across documents), with human confirmation for ambiguous merges.
- "Controlling stack" resolution — determines which document (base plan document or a specific amendment) actually governs a given provision **as of any specific date**, not just "the latest one."
- Conflict detection between documents in the same family (a standalone SPD disagreeing with the plan document, two documents both claiming to be current, an amendment referencing a section that doesn't exist).
- Conflicts are treated as findings to report, not defects to silently resolve.

## 3. Regulatory-filing integration

- Ingests Form 5500 filings (client-provided or pulled from the DOL's public bulk data).
- Parses Schedule A (insurance contracts/stop-loss carrier) and Schedule C (paid service providers) where available.
- Cross-validates filing data against document-derived facts, routing disagreements to human review rather than silently trusting one source.
- Treats filing data as "as of the filing year," never as more current than the actual documents or a direct human answer.

## 4. Human-sourced facts (implementation intake)

- A short, structured questionnaire capturing facts no document can reveal (e.g., true funding type for a level-funded plan, use of a specialty pharmacy vendor).
- Answers are versioned/dated and attributed to a named source.
- "Unknown, pending intake" is a legitimate, visible state — never silently defaulted.

## 5. The classification/extraction engine

- Populates a standardized attribute framework for every plan, grouped into: plan/document basics, funding & implementation, methodology & language-quality flags, network & plan design, clinical carve-outs, vendor relationships, and regulatory-filing attributes.
- **Every single field carries four things: a value, a source, a confidence score, and a citation** to the exact language relied on.
- Documented source-precedence rules for when sources disagree (draft rule: controlling documents > implementation intake > Form 5500 for plan-design facts; intake takes priority over documents for purely operational facts).
- Field-class-specific confidence thresholds (a funding-type misclassification is treated as far more costly than a misread broker name, and is held to a stricter bar).
- Re-runnable extraction — a new amendment or a framework definition change triggers re-extraction of only the affected fields, with prior values preserved as history.

## 6. Human-in-the-loop (HITL) review

- A review queue for any field below its confidence threshold, any source conflict, or any ambiguous entity match.
- Reviewers see the extracted value in context alongside the actual cited language and can accept or correct in one action.
- Every correction becomes labeled data feeding an ongoing improvement/evaluation loop.
- Per-field agreement-rate tracking used as a release/scale-out gate — a field that consistently needs correction signals a design problem, not a reviewer-effort problem.
- Target operational efficiency: under 10 minutes of reviewer time per plan at steady state.

## 7. Persistent data store

- A permanent, versioned record: Client → Plan → Document Family → Document (with version/type/dates) → Attribute Value (with source, confidence, citation, and full history).
- Point-in-time queryability — "what did we know when a given report actually went out" must always be answerable.

## 8. The analytics dashboard

- Book-of-business views: plan demographics (funding-type mix, network types), vendor statistics (most common carriers/vendors), language-quality trends (e.g., percentage of plans with outdated subrogation or missing NSA language), and opportunity analysis (which plans are strong candidates for which paid service).
- Every aggregate number states its denominator explicitly, and plans with an unknown value are excluded from percentages and shown separately rather than silently dropped in a way that would inflate the result.
- Designed from day one to scale from a single pilot client up to a full broker/TPA book, and eventually an industry-wide view, without needing to be redesigned later.

## 9. The criteria library (the SME control surface)

- An admin-configurable library of review topics, each with: which review part it belongs to (compliance vs. cost-containment), a Strong/Weak/Missing rubric, a weight, a link to which paid service it feeds into, and pre-approved client-facing phrasing.
- Owned and directly editable by the company's own subject-matter experts, not locked inside code — mirrors how the existing manual review process already works today.
- Seeded from the company's own existing assessment templates, checklists, and topic-coverage references rather than built from scratch.

## 10. The two-part review engine

- **Compliance review**: legal/regulatory requirements and internal best-practice drafting standards, rated per topic.
- **Cost-containment & best-practices review**: subrogation strength, out-of-network pricing posture, exclusion/carve-out quality, stop-loss language alignment — same rating mechanics, different subject matter.
- Deterministic controls on the underlying model calls (fixed model settings, structured output per rated criterion, per-criterion test cases in an evaluation set) to keep ratings consistent across repeated runs.
- Every rating comes with the cited language, its location, and a short, client-safe rationale.

## 11. Service opportunity mapping (the monetization layer)

- Every finding automatically maps to a readiness status (eligible / eligible with modifications / not eligible) for each of the company's paid services.
- Quantified opportunity statements, using pre-approved, carefully hedged language ("as much as," "estimated") signed off by legal and marketing before ever reaching a client.
- Mandatory cross-check against existing customer relationships — a client already using a service is never pitched it as new; strong existing usage becomes a retention message instead.

## 12. Conditional stop-loss gap review

- Runs only when a stop-loss policy is actually on file for that plan.
- Compares deductible levels against the plan's actual claims profile, checks key-term definition alignment, and checks for coverage/eligibility mismatches between the plan document and the policy.
- When no policy is on file, the report states that plainly and offers the review itself as a follow-up, rather than leaving a silent gap in the report.

## 13. Remediation recommendation engine

- Automatically recommends one of three fix pathways (targeted amendments / redlined modification of the existing document / a full new document on the company's own authoring platform) based on issue count, issue severity, document age/structure, and known client context.
- Explicitly constrained by real-world facts the system already knows — e.g., a plan built on a specific large TPA's proprietary document format is restricted to the two lower-disruption options, since a full rebuild isn't feasible for that document type.
- Deliberately designed to present options and readiness rather than push a client toward one specific decision.

## 14. Report assembly

- Fixed five-page template with hard length budgets per section; overflow is automatically summarized rather than allowed to grow the report.
- The full, unabridged finding set always remains available internally as the system of record — the five-page card is specifically the external artifact.
- Fixed tone requirements: factual, citation-anchored, explicitly not legal advice, with a standard disclaimer.

## 15. Approval & delivery

- No report can be delivered without a recorded human approval event (who, when, against which exact version).
- Reviewers can edit ratings, rewrite wording, suppress a finding, change the recommended pathway, or reject the report outright — each action is captured as structured feedback.
- Approval freezes the report against its underlying document/attribute snapshot, so it stays reproducible indefinitely.
- Re-assessment is triggered by a new amendment, a meaningful criteria-library change, or a client request, and produces a new report version with an explicit "what changed since last time" delta view.

## 16. Cross-cutting platform requirements (apply to everything above)

- **Provenance**: every value, finding, rating, and quantified claim must trace to cited language, a filing, or a named human input — no unexplained claims anywhere in the system.
- **PHI handling**: screened out at the point of ingestion; the intelligence store, reports, and evaluation sets are designed to be PHI-free.
- **Confidence & unknowns**: "Unknown" is a first-class, visible value everywhere in the system, never silently defaulted; HITL routing is threshold-driven and tunable per field/criterion class.
- **Versioning & reproducibility**: documents, the attribute framework, the criteria library, and every report are all versioned; any past report must be exactly reproducible from its own snapshot.
- **Evaluation**: a maintained "golden set" of correct answers per extraction field and per review criterion, seeded from real outputs and human corrections, with a regression check gating any change to the criteria library or the underlying prompts.
- **Access & audit**: role-based access separating the client-facing report, the internal full finding set, and the admin criteria library, with a full audit trail on every human review action and approval.

## Sources

- Internal document: "PDI Workflow Specification," Sections 3–7 (End-to-End View, Deliverable #1, Deliverable #2, Cross-Cutting Requirements, Core Entity Sketch)
