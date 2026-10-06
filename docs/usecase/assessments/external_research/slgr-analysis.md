# SLGR — External Validation Analysis

**Method:** the business-requirements checklist (`slgr/README.md`) was checked against independent external research into how the self-funded/stop-loss industry actually performs Plan-vs-Policy gap analysis. **No real client manual-review sample exists locally for SLGR** (unlike PDA and ASA) — this document's findings are based entirely on external research, not empirical validation against a real deliverable. That gap is itself the most important finding of this document — see §3.

## 1. What's CORRECT — externally validated

### "Gap review" is a real, named, recognized industry service — not an invented concept
Independent research confirms "gap review" is offered explicitly as a named service in the stop-loss industry: an absence of alignment between the plan document and stop-loss policy "creates issues that highlight the importance of having a gap review performed," with firms explicitly marketing this as a distinct product to "identify areas of concern and offer suggestions for ways to minimize gaps and the plan's overall liability."

### The core mechanism matches documented industry guidance closely
The reimbursement-impact test (`slgr/README.md`'s core rubric) matches independent industry description of the underlying risk almost exactly: "it is critically important that the group health plan coverage mirrors the stop-loss insurance coverage to ensure that catastrophic claims will be reimbursed." Named real-world mismatch examples in the literature — a stop-loss policy excluding classes the health plan still covers (COBRA enrollees, retirees, domestic partners, disabled/inactive employees), or the plan covering something (e.g., experimental cancer treatment) the policy doesn't — are the same category of mismatch the checklist's Exclusions and Definitions sections target. Reimbursement eligibility is independently described as a **two-part test** (eligible under the Plan *and* covered under the Policy's loss definition) — directly consistent with the checklist's Plan-vs-Policy comparison structure.

### SIIA confirms the structural reason this matters
The Self-Insurance Institute of America's own guidance states the plan document is what determines stop-loss liability, and — notably — that **plan document changes must be approved by the underwriter before inclusion in coverage.** This validates the checklist's Amendment/Endorsement handling logic (later language controls, and an Amendment/Endorsement that removes language means the topic is no longer present) as pointed at the right underlying risk.

## 2. What's a DOUBT — needs a correction, not just a caveat

### "Hard gap" / "soft gap" is NOT standardized industry terminology
This is the most important correction from external research. Despite being central to the entire SLGR business rule (`slgr/README.md`'s core rubric section), **no evidence was found that "hard gap"/"soft gap" is a SIIA-recognized or broadly-used industry classification** — it appears only in materials associated with the one vendor this project's reference data comes from. This does **not** mean the underlying concept is wrong — the distinction between a mechanically-certain reimbursement reduction and an interpretive/wording-risk mismatch is a sound, real risk categorization, and industry sources describe the same underlying phenomenon without using this exact two-tier label. **The correction is narrower than "this is wrong"**: don't present "hard gap/soft gap" as *industry-standard terminology* in any client-facing or regulatory-adjacent output a rebuild produces — it's fine as this project's own internal classification scheme (and a reasonable one), but claims like "this is the industry-standard hard/soft gap framework" would be an overstatement not supported by the research.

### A documented gap category the checklist may be under-covering: run-in/run-out timing misalignment
Independent research names **run-in/run-out timing gaps** as a well-documented, common gap category: a stop-loss policy's run-out period ending before all prior-year claims finish processing, or a coverage gap between an expiring policy and its replacement (common during M&A or plan transitions/carrier changes). Reviewing the checklist's four sections (Claim Provisions, Definitions, Exclusions, Miscellaneous Provisions) against this, there's no topic explicitly named for run-in/run-out timing misalignment specifically — the closest adjacent topics (Notice of Large Claim, Claims Audit) don't squarely cover this. **This is worth confirming directly against the full checklist (not just the topic list captured in `slgr/README.md`) before assuming it's covered** — flagged as an open item to check, not a confirmed gap, since the full topic rationale text wasn't exhaustively cross-referenced against this specific risk category.

### A documented process control the checklist doesn't appear to capture
SIIA's guidance states that **an amendment not formally submitted to and approved by the stop-loss underwriter can itself create a gap, independent of the amendment's actual language.** This is a distinct risk category from anything in the current checklist, which focuses entirely on comparing the *language* of the Plan against the *language* of the Policy — it has no mechanism for checking whether a given amendment was ever actually approved by the carrier in the first place. **This is a real, externally-documented gap in scope**, not just a terminology nitpick: a plan amendment could have perfectly aligned language with the stop-loss policy and still create a reimbursement gap if the carrier never approved it. Worth considering as a new topic/check in a rebuild, even though it requires information (underwriter approval status) that may not be derivable from the documents alone and might need to be an explicit input/question to the reviewer rather than something inferred from text.

## 3. What's a CONFLICT / open risk — the empirical validation gap itself

Unlike PDA and ASA, **there is no real client SLGR sample in this project's local data to check the checklist against.** This means every claim in `slgr/README.md` about the checklist's real-world fidelity rests on:
- The JSON checklist's own internal content (topic names, worked-example `sample_suggestions`) — which is real product data, but unvalidated against an actual finished deliverable.
- General external industry research (this document) — which validates the *concept* of gap review and the general shape of the risk, but cannot confirm whether *this specific* 50-topic checklist, as currently written, produces a real-world-accurate deliverable the way the PDA cross-check did.

**This is the single most important open item for SLGR specifically.** Before treating the SLGR checklist as production-ready, a real client SLGR sample (Plan Document + Stop Loss Policy + the human analyst's actual gap-review write-up) should be sourced and cross-checked the same way this project cross-checked PDA — following the exact methodology in `pda-and-pdasl-analysis.md`. Until that happens, treat SLGR's checklist as **plausible and well-grounded in general industry practice, but not empirically confirmed** the way PDA's is.

## 4. Summary of required changes / open items

1. **Do not describe "hard gap/soft gap" as industry-standard terminology** in any client-facing material — it's this project's own (reasonable) internal classification, sourced from one vendor's practice, not a SIIA or regulator-recognized standard.
2. Check whether run-in/run-out timing misalignment is genuinely covered by an existing checklist topic (full-text review needed, not just the topic-name list) — add a topic if it's missing.
3. Consider adding an underwriter-approval-status check as a new category of finding, distinct from language-comparison gaps — this may require it to be an explicit input rather than something derived from the documents.
4. **Source and cross-validate a real SLGR client sample** before treating this checklist with the same confidence level as PDA's — this is the highest-priority open item in this document.

## Sources

- The Phia Group's own public service description of "gap review" (used only to confirm the service is publicly, explicitly named — not as an authority on methodology correctness)
- SIIA (Self-Insurance Institute of America) — Self-Insured Group Health Plans guidance, including the underwriter-approval requirement for plan document changes
- Lexology — "Stop-Lost: Common Issues That May Cause Gaps in Your Stop-Loss Coverage" (via search snippet — direct source access was blocked; treat as a lead to verify directly if deeper confirmation is needed)
