# Guidelines — Progressive Rollout & Change Management

**Status:** v1 guidelines — pre-implementation
**Reads with:** `v1/05-evaluation-and-feedback-loops.md` §4 (shadow/canary at the eval level), `v1/10-deployment-and-infrastructure.md` §6 (CI/CD gate)

## 1. Prompts and agent configs are deployable artifacts — treat them like code, not like copy

Source: [Flagsmith — Progressive Delivery for LLM-Powered Features](https://www.flagsmith.com/blog/progressive-delivery-llm-powered-features).

The concrete, LLM-specific guidance beyond generic feature-flagging: **prompts should be deployed as versioned artifacts alongside code**, selected at runtime via a flag (e.g. `feature_flags.get_feature_value("prompt_version")`) or fetched from a dedicated prompt-management store keyed by the flag's chosen version. This is the same discipline `02-build-order-and-methodology.md` §3 already borrowed from Sierra's "Release" stage (immutable, versioned snapshots of source + prompts + model + knowledge together) — this document adds the *rollout mechanics* on top of that versioning.

**The same mechanism applies uniformly across three kinds of change this project will make repeatedly, not three different processes:**

- Prompt/instruction changes
- Model swaps (including moving a worker to a different provider via the capability registry, `01-guiding-philosophy.md` §5)
- Parameter tuning (temperature, top-p, routing thresholds)

Each goes through the same rollout progression — the mechanism doesn't care which of the three changed, only that *something* about agent behavior changed and needs validating before full exposure.

## 2. Rollout progression — phased, with both product and technical metrics at every stage

**Stated progression:** internal testing → 5% canary → 50% A/B → 100%, with **both** product metrics (engagement, task success) and technical metrics (latency, token cost) monitored at every stage — not quality alone. This is an important refinement on a naive rollout: a model swap that improves eval quality but doubles latency or cost is not simply a win, and the rollout gate must be able to catch that even if the quality-only eval suite (`v1/05`) would pass it.

**"Dark launches"** — sending production traffic to both the current and candidate versions and comparing outputs without exposing the candidate to users — are the recommended way to validate a new model/prompt with real traffic and zero user-facing risk. This is the same concept as the shadow testing already specified in `v1/05-evaluation-and-feedback-loops.md` §4; this document confirms it applies to *every* class of change (prompt, model, parameter), not only to changes framed as "agent behavior."

## 3. The eval suite is the gate at every stage, not just at initial ship

This is the sharper, more specific claim from the research, worth stating as explicit policy: a regression that a manual reviewer would miss — e.g., a more concise prompt causing more "I'm not sure" refusals, a cheaper model subtly worse at a rare tool-call pattern — is exactly what automated evals running **at each rollout stage** are meant to catch. Running the eval suite once, before the 5% canary, and then trusting the rollout to complete unmonitored defeats the purpose: **re-run the relevant slice of the eval suite (or at minimum, the drift-detection checks from `v1/05` §4) at each stage transition** (5%→50%, 50%→100%), not only at the start.

## 4. Rollback is a first-class operation, not an emergency improvisation

Because releases are immutable, versioned units (§1, and `02-build-order-and-methodology.md` §3's Sierra mapping), rollback is simply "point the flag back at the previous version" — this only works if that discipline (never mutate a shipped version in place, always ship a new version) is actually followed. **Concrete rule:** a hotfix to a live prompt/config is itself a new version, deployed through the same flag mechanism — never an in-place edit to what's currently serving traffic, even under incident pressure, because an in-place edit breaks the rollback guarantee for everyone currently on that version.

## 5. Change management checklist — applied at every prompt/model/config change

- [ ] Is this change packaged as a new **immutable version**, not an edit to the currently-live one?
- [ ] Does it go through **internal testing → 5% canary → 50% A/B → 100%**, or is there a specific, documented reason to skip a stage (e.g., a critical security fix)?
- [ ] Are **both** product and technical (latency/cost) metrics being watched at each stage, not just eval quality?
- [ ] Is the relevant eval suite (or drift-detection subset) re-run at each stage transition, not just once at the start?
- [ ] If this is a model swap: has it gone through the capability registry's evidence-based selection (`01-guiding-philosophy.md` §5), not an ad hoc "let's just try the new one" decision?
- [ ] Is rollback a one-step flag flip, confirmed before rollout begins — not something to figure out under incident pressure if the rollout goes wrong?

## Sources

- [Flagsmith — Progressive Delivery for LLM-Powered Features](https://www.flagsmith.com/blog/progressive-delivery-llm-powered-features)
