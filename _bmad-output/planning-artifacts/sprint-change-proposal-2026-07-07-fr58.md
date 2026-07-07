# Sprint Change Proposal — Story 10.8 Insertion (Darkness Fairness Moving-LoS Predicate and Readiness Sample Expansion)

- **Date:** 2026-07-07
- **Facilitator:** Developer (correct-course workflow, `gds-correct-course`)
- **Requested by:** Rasmus (Project Lead)
- **Trigger artifact:** Story 10.3 Review Findings (two 10.6-gate-owned Decision items) + `generator-fairness-batch-readiness.md` §4 + `seed-regression-suite-readiness.md` §3
- **Mode:** Batch (all edit proposals compiled together; direction pre-decided by the user 2026-07-07)
- **Precedent:** `sprint-change-proposal-2026-07-07.md` (Epic 12 insertion — the file-order-is-execution-order convention this reuses) and `sprint-change-proposal-2026-07-04.md` (Epic 11 insertion — the same additive, no-renumber pattern)

---

## 1. Issue Summary

### Problem statement

Story 10.3 (Generator Soft-Lock and Fairness Batch Checks) shipped its batch harness honestly and, in doing so, surfaced **two forward-owned Decision items** that its own scope explicitly assigned to the 10.6 MVP Readiness Gate rather than resolving in-story:

1. **The FR58 `darkness_unseen_hazard` finding on Medium seeds 4004 + 5005.** The `DarknessFairnessQuery` predicate (b) is a **static-from-entrance** visibility check: "at spawn, is every reachable HAZARD cell line-of-sight-visible at the Darkness-reduced radius (2)?" The Medium generator's tactical-wrinkle phase bakes `Terrain.HAZARD` cells into some seeds (part of the pinned Medium terrain fingerprint), and for 4004 (hazard at (9,4)) and 5005 (hazards at (10,2)+(12,2)) those hazards are reachable but unseen-from-entrance at radius 2 — so a Darkness assignment legitimately FAILS `darkness_unseen_hazard`. The batch classified, flagged, and preserved this honestly. Story 10.3's ledger §4 recorded three owning options (tune the generator / strengthen the predicate / accept as a documented limitation) and handed the decision to 10.6.

2. **The 5-of-50 (and other sub-target) seed-sample gaps.** The consolidated readiness harnesses across 10.1/10.2/10.3 run against a shared `[1001,2002,3003,4004,5005]` Small/Medium catalog (5 of the 50/50 MVP-readiness target) plus sub-target tactical (8/25), reward (8/20), boss (5/10), and affinity (mixed-8 of 10-per-affinity) samples. Route already reached its 20/20 target. Both readiness ledgers recorded these as **temporary availability gaps** gated at 10.6, dischargeable only via a **coordinated** expansion across the three Epic-10 harnesses (never an isolated re-pin), and only via the sanctioned `tools/dump_*` drivers.

### What the user decided (2026-07-07 — the direction, not re-litigated here)

The user elected to **pull both Decision items forward into a single new Story 10.8, executed immediately after 10.3 and before the Epic 12 block (12.1)** — ahead of the Epic 12 hands-on-play milestone — with two specific option selections:

- **Part A (FR58):** choose **"strengthen the predicate"** (option 2 of §4) over generator-tune (option 1) or accept-as-limitation (option 3). Formalize `DarknessFairnessQuery` predicate (b) from static-from-entrance to **moving reduced-radius LoS** ("seen-before-contact") semantics, so the Medium 4004/5005 configurations become legitimate PASS while the guardrail still fails loud for genuinely unfair configurations.
- **Part B (sample expansion):** choose **"full expansion now"** over a partial pass or a defer-to-10.6, discharging every headless-mechanical sample target the two ledgers recorded.

### Why pull forward (rationale, per the user)

Epic 12 is the hands-on-play milestone. Two risks should not ride through it unresolved:

- **A latent live hard-stop.** `RunOrchestrator._check_darkness_fairness_live` runs the *same* `DarknessFairnessQuery` on the live board and surfaces a `darkness_fairness_violation` as a **HARD run-progression error** (no partial progression — the node is neither cleared nor failed). Because `NodeEnterCommand.NODE_TYPE_RECIPE` maps `elite_combat -> medium_combat_basic` (SIZE_MEDIUM), live runs **do** generate Medium boards with baked HAZARD wrinkles. A Darkness + Medium live run that lands on such a board today would trip a latent false-positive hard-stop under the static-from-entrance predicate. The method also carries a false-premise comment ("v0 generated boards are all-FLOOR") that is true only for the Small recipe. Strengthening the predicate is precisely what removes this latent false-positive from the live progression gate before hands-on play stresses it.
- **Sample-gap drift.** Leaving the mechanical sample gaps open lets them accumulate through the Epic 12 work; discharging them now keeps the readiness ledgers honest and shrinks 10.6's residual to the genuinely non-mechanical (physical-device) gaps.

After this change, **10.6's gate scope shrinks** to verifying (a) the strengthened predicate + the discharged samples and (b) the remaining physical-device gaps (G1–G7). Story 12.1 (next in sprint) is untouched apart from execution order (10.8 runs before it).

### Evidence

- Story 10.3 file — Review Findings: two Low/Decision items, both "10.6-gate-owned" by story design (FR58 resolution; 5-of-50 sample expand-vs-descope). Code review verdict Approve, 185 PASS.
- `_bmad-output/auto-gds/reports/10-3-generator-soft-lock-and-fairness-batch-checks.md` — Open questions #1 (FR58 resolution: tune / strengthen / accept) and #2 (5-of-50 coordinated 3-harness expansion or de-scope), both flagged 10.6-gate-owned.
- `generator-fairness-batch-readiness.md` §4 (the three FR58 options; the Medium 4004/5005 hazard cells and their reduced-radius verdicts) and §5 (the 50/50 target + the 5-of-50 gap + the no-isolated-expansion rule).
- `seed-regression-suite-readiness.md` §3 (the seven sample targets: tactical 25, Small 50, Medium 50, route 20 MET, reward 20, per-affinity 10, boss 10) and §5 (the DELIBERATE-UPDATE / no-silent-drift discipline).
- `godot/scripts/generation/level/darkness_fairness_query.gd` predicate (b), lines 148–176 (the static-from-entrance `seen_from_entrance` check to be strengthened; predicate (a) entrance checks and the stable reason codes to be preserved).
- `godot/scripts/run/run_orchestrator.gd` `_check_darkness_fairness_live` (~lines 1094–1119: the hard live-progression gate + the false "all-FLOOR" premise comment).
- `deferred-work.md` — the 10.3 entry records the FR58 finding as a 10.6-gate-owned readiness signal (explicitly NOT a defect and NOT a cross-story defer); the G1–G7 gaps are physical-device / scene-owner items.

### Issue category

**Technical limitation discovered during implementation, resolved by a scoped forward-pull.** Not a defect: the static-from-entrance predicate and the sub-target samples were deliberate, ratified, honestly recorded 10.6-gate hand-offs. The change converts two forward-owned Decision items into one explicit, pulled-forward story ahead of the milestone that would otherwise stress the latent risk.

---

## 2. Impact Analysis

### Epic impact

- **Epic 10** gains one story (10.8), inserted into the execution order immediately after 10.3 and before the Epic-12 block. 10.8 discharges work Epic 10 already assigned to its own 10.6 gate; Epic 10's identity as the tuning/readiness epic is preserved (10.8 is a readiness/fairness story, squarely in-epic — unlike the Epic-12 implementation work, which was given its own epic).
- **Epic 12** is unaffected except for execution order (10.8 runs before 12.1). No Epic-12 story content changes.
- **10.6's gate scope shrinks:** the FR58 resolution and the mechanical sample expansion move out of 10.6's decision surface (they become 10.8's delivered work that 10.6 *verifies*); 10.6 retains the physical-device (G1–G7) gaps and the overall readiness roll-up.
- **No other epics remain** (Epics 1–9 and 11 are `done`; 10.1–10.3 are `done`). Nothing is invalidated; the change is additive allocation plus a scoped predicate strengthening.

### Story impact

- **New:** Story 10.8 (Darkness Fairness Moving-LoS Predicate and Readiness Sample Expansion), positioned in execution order between 10-3 and 12-1.
- **Annotated:** Story 10.6 gains a dated note recording its reduced gate scope; the Epic 10 intro gains a dated sequencing note; a dated traceability note is added.
- **Unchanged:** Stories 10.1–10.5, 10.7, all of Epics 11 and 12, and every done story. Story 12.1 is unchanged apart from running after 10.8.

### Artifact conflicts

| Artifact | Conflict | Resolution |
|---|---|---|
| `epics.md` (canonical) | Epic 10's two 10.6-owned Decision items now have an owning story ahead of Epic 12. | Edits in §4: new Story 10.8 in the Epic 10 section, Epic 10 intro sequencing note, Story 10.6 gate-scope note, 2026-07-07 (FR58) traceability note. |
| `sprint-status.yaml` | Missing 10.8 entry. | Edit in §4.5 (post-approval, checklist 6.4): `10-8-…: backlog` inserted between `10-3-…` and the epic-12 block; `last_updated` refreshed; `scope` extended. |
| `generator-fairness-batch-readiness.md` | §4 records the FR58 decision as open (three options, 10.6-owned); §5 records the 5-of-50 gap. | 10.8 records the resolution (option "strengthen predicate" chosen 2026-07-07) in §4 and marks the discharged targets in §5 — done by **Story 10.8's implementation**, not by this proposal. |
| `seed-regression-suite-readiness.md` | §3 records the sub-target sample gaps. | 10.8 updates §3's gap table to reflect discharged targets (physical-device gaps stay 10.6-owned) — done by **Story 10.8's implementation**. |
| `darkness_fairness_query.gd` | Predicate (b) is static-from-entrance. | Strengthened to moving reduced-radius LoS by Story 10.8 (predicate (a), reason codes, purity, fail-loud discipline all preserved). |
| `run_orchestrator.gd` | False "all-FLOOR" premise comment on a hard live gate. | Comment corrected by Story 10.8 (Medium bakes HAZARD; the gate is a hard live progression stop; the predicate strengthening removes the latent false-positive). No behavior change to the gate's *structure*. |
| GDD | None. Strengthening the predicate directly serves FR58 ("no unavoidable damage from unseen space") and preserves the "seen => fair" principle at the reduced radius. | No edit. |
| `game-architecture.md` | None — the query stays a pure, board-scoped, caller-driven RefCounted check; the generation pipeline, RNG streams, and save gates are untouched. | No edit. |
| `ux-appendix-run-flow.md` | None. | No edit. |
| `deferred-work.md` | The 10.3 FR58 entry and the sample-gap items are 10.6-gate-owned readiness signals, not cross-story defers. | No new defer entry required; 10.8 discharges them in the readiness ledgers (the established per-story-resolution pattern). The G1–G7 physical-device gaps stay recorded and 10.6-owned. |

### Technical impact

- **Part A (predicate + tests):** the strengthened predicate is a `DarknessFairnessQuery` (RefCounted, pure) change plus its unit tests and the 10.3 batch expectations. **Hard constraints carried from Epic 10:** NO generator / generation-pipeline change; NO seed-regression fingerprint re-pin from Part A (the query is not fingerprinted — it only reads validator/LoS verdicts); NO affinity-into-generation wiring. Keep the stable reason codes, predicate (a) entrance checks, purity (no RNG / commands / mutation), compact diagnostics, and fail-loud discipline for genuinely-unfair configurations (future sight-blocking hazards or forced movement).
- **Deliberate test updates (the ratified no-silent-drift contract):** Medium 4004/5005 flip from classified `darkness_unseen_hazard` findings to legitimate PASS. The batch's finding-presence assertions (`test_generator_fairness_batch.gd`) and the fairness-verdict tests (`test_darkness_fairness.gd`) get corresponding deliberate updates, including a NEW test proving the moving-LoS semantics (a hand-built candidate where a hazard is entrance-unseen but necessarily seen-before-contact ⇒ PASS, plus a genuinely-unfair configuration that still FAILS).
- **Part B (sample expansion):** additive, coordinated across the three Epic-10 harnesses (10.1 perf sample where it consumes the shared catalog, 10.2 consolidated suite catalogs, 10.3 fairness batch). The shared Small/Medium seed catalog stays in sync across all three — never desynced or re-pinned in isolation. New pins are regenerated ONLY via the existing sanctioned `tools/dump_*` drivers, and ONLY after the Part A predicate change so verdicts are final. Original pinned entries stay byte-identical (additive expansion, not a re-pin). Targets: generation Small 5→50, Medium 5→50, tactical 8→25, reward 8→20, boss 5→10, affinity mixed-8 → 10-per-affinity (every implemented affinity incl. Flooded-Conductive and Darkness surfaced, with documented per-affinity counts). Route (20/20) untouched.
- **Runtime / discipline guards:** an explicit AC guard keeps the full-suite wall-clock under a sane bound on the dev machine; the false-PASS grep guard discipline is preserved; the 7 named RNG streams, zero new RNG draw sites, the 23-key `RunSnapshot` gate, `ProfileSnapshot`/`SettingsSnapshot` `SCHEMA_VERSION == 1`, and every non-Part-A fingerprint SOURCE are unmoved.

---

## 3. Recommended Approach

**Option 1 — Direct Adjustment (SELECTED): add one story (10.8) inside Epic 10, executed immediately after 10.3 and before the Epic-12 block.** This is the pre-decided direction. It converts two 10.6-gate-owned Decision items into a single explicit, pulled-forward story ahead of the Epic 12 hands-on milestone. Effort: Medium (one implementation story — a scoped predicate strengthening with deliberate test updates + a coordinated additive sample expansion + two readiness-ledger updates + a false-premise comment fix). Risk: Low-Medium — the predicate change is a pure, board-scoped query with a well-characterized before/after (Medium 4004/5005 flip to PASS; genuinely-unfair configs still FAIL), the sample expansion is additive behind sanctioned dump tools with byte-identical original pins, and the whole change touches no generator/RNG/save invariant.

Rejected alternatives:

- **Option 2 — Rollback: NOT VIABLE.** Nothing to revert; Story 10.3 is correct, additive, and complete. The change strengthens a predicate and discharges recorded gaps — it is forward work, not a wrong turn.
- **Option 3 — MVP Review (accept the FR58 limitation + defer the samples to 10.6): VIABLE BUT REJECTED by the user.** This is FR58 option 3 (accept-as-limitation) plus a sample defer. It was explicitly weighed in 10.3's ledger §4 and declined here: leaving the static-from-entrance predicate live keeps the latent false-positive hard-stop on Darkness+Medium runs riding into the Epic 12 hands-on milestone, and leaving the sample gaps open lets them drift. The user chose to resolve both now.
- **Generator-tune for FR58 (option 1 of §4): REJECTED by the user.** Constraining Medium hazard-wrinkle placement (or gating the wrinkle out when a level could be Darkness) is an affinity-aware GENERATION change that would re-pin the affected Medium terrain fingerprints and pull affinity into generation — heavier, and it perturbs the very fingerprints the readiness batch protects. The user chose to strengthen the query instead, which re-pins nothing.
- **A new epic for 10.8 (the Epic-12 shape): REJECTED on shape.** 10.8 is a readiness/fairness story that belongs in Epic 10 (unlike the Epic-12 interactive-combat implementation work, which earned its own epic). A single in-epic story is the right granularity.

### Execution order after this change

`10-1 → 10-2 → 10-3 → 10-8 → 12-1 → 12-2 → 10-4 → 10-5 → 10-6 → 10-7`

Numbering note: 10.8 is appended to Epic 10's story list in `epics.md` (after 10.7) for numbering continuity, but its **execution position is between 10-3 and 12-1** — encoded directly by the `sprint-status.yaml` file order (file order = execution order, the ratified Epic-12 convention) and stated explicitly in the story header and the sequencing note. This mirrors how the Epic-12 block sits between 10-3 and 10-4 in the file while Epic 12 numbers after Epic 11.

### Effort / timeline impact

One story added to the MVP critical path ahead of the Epic-12 block. This is work Epic 10 always owned (its own 10.6 gate carried both Decision items); the change pulls it forward so the latent live hard-stop and the sample gaps are resolved before hands-on play, and shrinks 10.6's residual to the physical-device gaps. No scope is added beyond what 10.6 already assumed.

---

## 4. Detailed Change Proposals

All edits are docs-only planning changes (the implementation lands via the normal story pipeline when 10.8 is developed). Proposals compiled in Batch mode; direction pre-approved by the user 2026-07-07.

### 4.1 `epics.md` — Story 10.8 (append to the Epic 10 section, after Story 10.7, immediately before `## Epic 11`)

```markdown
### Story 10.8: Darkness Fairness Moving-LoS Predicate and Readiness Sample Expansion

> **Execution order (2026-07-07, sprint change):** although numbered 10.8 for list continuity, this
> story executes **immediately after Story 10.3 and before the Epic 12 block (Story 12.1)** — it
> resolves the two 10.6-gate-owned Decision items Story 10.3 surfaced, ahead of the Epic-12 hands-on
> milestone. `sprint-status.yaml` encodes this by placing the `10-8-…` entry between `10-3-…` and the
> `epic-12` block (file order = execution order). See `sprint-change-proposal-2026-07-07-fr58.md`.

As a player,
I want Darkness levels to be judged fair by whether I necessarily SEE a hazard before I can reach it
(not only whether I see it from the entrance), and I want the MVP readiness seed samples to actually
cover the target sizes,
So that Darkness+Medium runs are not falsely blocked and the readiness verdict rests on a real sample.

**Origin:** Story 10.3's genuine FR58 finding — two Decision items its scope assigned to the 10.6 gate:
the `darkness_unseen_hazard` classification on Medium seeds 4004/5005, and the 5-of-50 (+ other
sub-target) seed-sample gaps. The user elected (2026-07-07) to pull both forward: FR58 via "strengthen
the predicate" (`generator-fairness-batch-readiness.md` §4 option 2), and the samples via "full
expansion now". 10.6's gate scope then shrinks to verifying these plus the physical-device gaps (G1–G7).

**Acceptance Criteria:**

**Part A — FR58 resolution (strengthen the predicate):**

**Given** the `DarknessFairnessQuery` predicate (b) `REASON_UNSEEN_HAZARD` currently checks static
line-of-sight from the ENTRANCE at the Darkness-reduced radius
**When** the predicate is strengthened
**Then** a REACHABLE hazard is fair iff the hero necessarily SEES it before contact under stepwise
4-neighbour movement at the Darkness-reduced radius (the v0 facts: hazards are walkable +
sight-transparent, so a hazard is visible at distance 1 from any step-from cell and occlusion between
adjacent cells is impossible — the strengthened check formalizes seen-before-contact instead of
seen-from-entrance)
**And** predicate (a) entrance checks, the stable reason codes
(`entrance_on_hazard`/`entity_on_entrance`/`darkness_unseen_hazard`/`invalid_darkness_candidate`),
purity (no RNG/commands/mutation), compact diagnostics, and fail-loud discipline for genuinely-unfair
configurations (e.g. future sight-blocking hazards or forced movement) are preserved.

**Given** the ratified no-silent-drift contract governs the 10.3 batch expectations
**When** the strengthened predicate lands
**Then** Medium seeds 4004 (hazard at (9,4)) and 5005 (hazards at (10,2)+(12,2)) flip from classified
`darkness_unseen_hazard` findings to legitimate PASS, and the batch's finding-presence assertions
(`godot/tests/integration/test_generator_fairness_batch.gd`) plus the fairness-verdict tests
(`godot/tests/unit/generation/test_darkness_fairness.gd`) are DELIBERATELY updated to match
**And** a NEW test proves the moving-LoS semantics — a hand-built candidate where a hazard is
entrance-unseen but necessarily seen-before-contact ⇒ PASS, plus a genuinely-unfair configuration that
still FAILS `darkness_unseen_hazard`.

**Given** `RunOrchestrator._check_darkness_fairness_live` runs the same query on the live board as a
HARD run-progression gate, and `NodeEnterCommand` maps `elite_combat -> medium_combat_basic` so live
runs DO generate Medium boards with baked HAZARD wrinkles
**When** the false-premise comment (~lines 1094–1099, "v0 generated boards are all-FLOOR") is corrected
**Then** the comment states that "all-FLOOR" holds only for the Small recipe (Medium bakes wrinkle-phase
HAZARD cells) and that this check is a hard live progression gate
**And** the resolution is recorded in `generator-fairness-batch-readiness.md` §4 (option "strengthen
predicate" chosen by the user 2026-07-07), with the note that the predicate strengthening removes the
latent false-positive hard-stop on live Darkness+Medium runs.

**Given** the Epic-10 generation constraints
**When** Part A lands
**Then** NO generator / generation-pipeline change, NO seed-regression fingerprint re-pin from Part A
(the query is not fingerprinted), and NO affinity-into-generation wiring are introduced.

**Part B — readiness sample expansion (full expansion now):**

**Given** the headless-mechanical sample targets recorded in `seed-regression-suite-readiness.md` §3 and
`generator-fairness-batch-readiness.md`
**When** the samples are expanded
**Then** generation Small reaches 50, Medium reaches 50, tactical reaches 25, reward reaches 20, boss
reaches 10, and affinity reaches 10-per-affinity (every implemented affinity incl. Flooded-Conductive
and Darkness surfaces in the assignment sample, with documented per-affinity counts); route already met
20/20 and is untouched.

**Given** the ratified epic convention that the shared Small/Medium seed catalog stays in sync across
the three Epic-10 harnesses
**When** the generation samples are expanded
**Then** the expansion is COORDINATED across 10.1 (perf sample where it consumes the shared catalog),
10.2 (consolidated suite catalogs), and 10.3 (fairness batch) — never desynced or re-pinned in isolation
**And** new pins are regenerated ONLY via the existing sanctioned `tools/dump_*` drivers, AFTER the Part
A predicate change so verdicts are final, with the original pinned entries byte-identical (additive
expansion, not a re-pin).

**Given** full-suite runtime and the false-PASS discipline
**When** the expanded suite runs
**Then** the full headless suite stays under a stated sane wall-clock bound on the dev machine (an
explicit AC guard) and the false-PASS grep guard discipline is preserved.

**Given** the two readiness ledgers record the sample gaps
**When** the targets are discharged
**Then** both ledgers' §3 / gap tables are updated to reflect the discharged targets
**And** the remaining non-mechanical gaps (G1–G7 physical-device passes) stay recorded as 10.6-owned.

**Given** determinism and save gates
**When** the whole story lands
**Then** the 7 named RNG streams, zero new RNG draw sites, the 23-key `RunSnapshot` gate,
`ProfileSnapshot`/`SettingsSnapshot` `SCHEMA_VERSION == 1`, and every non-Part-A fingerprint SOURCE hold,
and the default deterministic paths stay byte-identical.
```

### 4.2 `epics.md` — Epic 10 section intro: add sequencing note (below the 2026-07-07 Epic-12 note, ~line 2367)

```markdown
> **Sequencing note (2026-07-07, sprint change — FR58/sample story):** Story 10.8 (Darkness Fairness
> Moving-LoS Predicate and Readiness Sample Expansion) is inserted and executes **immediately after
> Story 10.3 and before the Epic 12 block** — it pulls forward the two 10.6-gate-owned Decision items
> Story 10.3 surfaced (the FR58 `darkness_unseen_hazard` finding, resolved by strengthening the
> predicate; and the sub-target seed samples, discharged by full expansion) ahead of the Epic-12
> hands-on milestone. Story 10.8 is numbered last in the Epic 10 list for continuity but runs at that
> earlier position (`sprint-status.yaml` file order encodes it). This shrinks Story 10.6's gate scope to
> verifying 10.8's deliverables plus the physical-device gaps (G1–G7).
```

### 4.3 `epics.md` — Story 10.6 header: add gate-scope note (below the existing 2026-07-07 prerequisite)

```markdown
**Gate-scope note (2026-07-07, FR58/sample story):** Story 10.8 pulls the FR58 `darkness_unseen_hazard`
resolution (strengthened moving-LoS predicate) and the headless-mechanical seed-sample expansion out of
this gate's decision surface — 10.6 now VERIFIES those deliverables rather than deciding them. 10.6
retains the physical-device (G1–G7) sample gaps and the overall MVP-readiness roll-up.
```

### 4.4 `epics.md` — dated traceability note (after the 2026-07-07 Epic-12 traceability note, ~line 409)

```markdown
### 2026-07-07 Sprint Change Traceability (Story 10.8 insertion — FR58/sample)

Per `sprint-change-proposal-2026-07-07-fr58.md` (trigger: Story 10.3's two 10.6-gate-owned Decision
items — the FR58 `darkness_unseen_hazard` finding on Medium seeds 4004/5005 and the 5-of-50 sub-target
seed-sample gaps): Story 10.8 (Darkness Fairness Moving-LoS Predicate and Readiness Sample Expansion)
added, executing between Story 10.3 and the Epic 12 block (Story 12.1). Part A strengthens
`DarknessFairnessQuery` predicate (b) from static-from-entrance to moving reduced-radius LoS
(seen-before-contact), flips Medium 4004/5005 to legitimate PASS with deliberate test updates + a new
moving-LoS proof, corrects the false "all-FLOOR" premise comment in
`RunOrchestrator._check_darkness_fairness_live` (a hard live progression gate), and records the
"strengthen predicate" choice in `generator-fairness-batch-readiness.md` §4 — NO generator change, NO
Part-A fingerprint re-pin, NO affinity-into-generation. Part B discharges the headless-mechanical sample
targets (generation Small/Medium 5→50, tactical 8→25, reward 8→20, boss 5→10, affinity mixed-8 →
10-per-affinity; route already 20/20) via a COORDINATED additive expansion across the three Epic-10
harnesses using the sanctioned `tools/dump_*` drivers (original pins byte-identical). Story 10.6's gate
scope shrinks to verifying these plus the physical-device (G1–G7) gaps. Story 12.1 is unchanged apart
from execution order. Epic numbering of existing epics is unchanged by design.
```

### 4.5 `sprint-status.yaml` — insert the 10-8 entry (post-approval; checklist item 6.4)

Inserted BETWEEN the `10-3-…` entry and the `epic-12` block in `development_status` (the file follows
file-order-is-execution-order, so this placement encodes the execution position directly, exactly as the
epic-12 block sits between 10-3 and 10-4). `scope` extended; `last_updated` refreshed:

```yaml
  10-3-generator-soft-lock-and-fairness-batch-checks: done
  # SPRINT CHANGE 2026-07-07 (sprint-change-proposal-2026-07-07-fr58.md):
  # story 10-8 executes BETWEEN 10-3 and the epic-12 block (file order = execution order) —
  # it pulls forward Story 10.3's two 10.6-gate-owned Decision items (the FR58
  # darkness_unseen_hazard finding, resolved by strengthening DarknessFairnessQuery to
  # moving reduced-radius LoS; and the sub-target seed samples, discharged by full expansion)
  # ahead of the Epic-12 hands-on milestone. 10.8 is numbered last in the Epic 10 list for
  # continuity but runs at this earlier position. This shrinks 10.6's gate scope.
  10-8-darkness-fairness-moving-los-and-readiness-sample-expansion: backlog
  # SPRINT CHANGE 2026-07-07 (sprint-change-proposal-2026-07-07.md):
  # epic-12 executes BETWEEN epic-10's 10-3 and 10-4 (file order = execution order) — ...
  epic-12: backlog
```

---

## 5. Implementation Handoff

**Scope classification: MODERATE** — backlog reorganization (one story inserted into the execution order
ahead of an existing epic block) plus docs-only planning edits now; implementation via the normal story
pipeline afterwards. No fundamental replan: GDD, architecture, and UX artifacts are untouched. The
predicate strengthening and sample expansion are substantive but scoped and land as Story 10.8's dev
work, not as this proposal's edits.

| Role | Responsibility |
|---|---|
| **Developer (this session, on approval)** | Apply §4 edits to `epics.md` + `sprint-status.yaml`. (The orchestrator owns git — no commit performed here.) |
| **Scrum Master / auto-gds pipeline** | Execute the revised order: `10-1 → 10-2 → 10-3 → 10-8 → 12-1 → …`. Drive 10.8 through the standard create-story → dev-story → code-review pipeline. `gds-create-story` for 10.8 must pull into context: `darkness_fairness_query.gd` predicate (b), the two test files, `run_orchestrator.gd` `_check_darkness_fairness_live` + the false-premise comment, `NodeEnterCommand.NODE_TYPE_RECIPE`, both readiness ledgers (§3/§4/§5), the shared `tools/dump_*` drivers, and the no-isolated-expansion / DELIBERATE-UPDATE conventions. |
| **Rasmus (Project Lead)** | Pre-approved this proposal's direction (2026-07-07); later ratifies any 10.8 balance/threshold decisions (the moving-LoS fairness contract's edge cases; the stated wall-clock bound; any newly-surfaced unwinnable-under-Darkness seed) surfaced during implementation. |

**Success criteria:**

1. `epics.md` contains Story 10.8 in the Epic 10 section, the Epic 10 intro sequencing note, the Story
   10.6 gate-scope note, and the 2026-07-07 (FR58/sample) traceability note.
2. `sprint-status.yaml` shows the `10-8-…: backlog` entry between `10-3-…` and the `epic-12` block, with
   the sequencing comment, extended `scope`, and a refreshed `last_updated`.
3. The next story consumed by the pipeline after 10-3 is 10-8, and 12-1 is not started before 10-8 is
   `done`.
4. When 10.8 lands (implementation, later): the strengthened predicate flips Medium 4004/5005 to PASS
   with deliberate test updates + a new moving-LoS proof and a preserved genuinely-unfair FAIL; the false
   "all-FLOOR" comment is corrected; the sample targets are discharged via coordinated `tools/dump_*`
   expansion with original pins byte-identical; both readiness ledgers' §3/§4/§5 reflect the discharge;
   the headless suite is green under the stated wall-clock bound with the false-PASS guard clean; and no
   generator/RNG/save invariant or non-Part-A fingerprint moved.

---

## 6. Change-Navigation Checklist Record

| Item | Status | Note |
|---|---|---|
| 1.1 Triggering story | [x] | Story 10.3 (Generator Soft-Lock and Fairness Batch Checks) — its two 10.6-gate-owned Decision items. |
| 1.2 Problem definition | [x] | Technical limitation discovered during implementation (static-from-entrance predicate + sub-target samples), resolved by a scoped forward-pull; statement in §1. |
| 1.3 Evidence | [x] | 10.3 Review Findings + pipeline report open questions; both readiness ledgers §3/§4/§5; the `darkness_fairness_query.gd` predicate (b) source; the `run_orchestrator.gd` live gate + false premise; `NodeEnterCommand.NODE_TYPE_RECIPE`; deferred-work 10.3 entry. |
| 2.1 Current epic viability | [x] | Epic 10 stays viable; 10.8 discharges work its own 10.6 gate owned. 10.1–10.3 done and unaffected. |
| 2.2 Epic-level changes | [x] | Add Story 10.8 inside Epic 10, executed between 10-3 and the epic-12 block. |
| 2.3 Future epics review | [x] | Epic 12 unaffected except execution order; no epics remain beyond Epic 10. |
| 2.4 Invalidation check | [x] | Nothing invalidated; additive allocation + scoped predicate strengthening. |
| 2.5 Order/priority | [x] | New execution order recorded in §3; 10.6 gate scope shrinks. |
| 3.1 GDD/PRD conflict | [x] | None — strengthening the predicate directly serves FR58 and preserves the "seen => fair" principle. |
| 3.2 Architecture conflict | [x] | None — the query stays a pure, board-scoped RefCounted check; generation/RNG/save invariants untouched. |
| 3.3 UI/UX conflict | [x] | None. |
| 3.4 Other artifacts | [x] | sprint-status.yaml edit; the two readiness ledgers updated by Story 10.8's implementation; test files + the two source files updated by 10.8; G1–G7 stay 10.6-owned in deferred-work. |
| 4.1 Direct adjustment | [x] Viable | SELECTED (one in-epic story). Effort Medium / Risk Low-Medium. |
| 4.2 Rollback | [x] Not viable | Nothing to revert; 10.3 is correct and complete. |
| 4.3 MVP review | [x] Viable, rejected | Accept-limitation + defer-samples (FR58 option 3) declined by the user; leaves the latent live hard-stop and sample drift through the Epic-12 milestone. |
| 4.4 Path selected | [x] | Option 1 via Story 10.8 insertion; rationale in §3. Generator-tune (FR58 option 1) and new-epic shape both rejected with reasons. |
| 5.1–5.5 Proposal components | [x] | This document §§1–5. |
| 6.1 Checklist review | [x] | All sections addressed. |
| 6.2 Proposal accuracy | [x] | Cross-checked against the 10.3 story + report, both readiness ledgers, epics.md, sprint-status, the predicate source, and the run_orchestrator live gate. |
| 6.3 User approval | [x] | Direction (pull both Decision items forward as Story 10.8; FR58 = strengthen predicate; samples = full expansion now) decided by Rasmus 2026-07-07; proposal structures that decision. |
| 6.4 sprint-status update | [x] | Applied 2026-07-07 per §4.5 (10-8 entry between 10-3 and the epic-12 block; scope + last_updated refreshed). |
| 6.5 Handoff confirmed | [x] | §5 table. |

**Approval:** Direction approved by Rasmus, 2026-07-07 (both Decision items pulled forward into Story
10.8; FR58 resolved via "strengthen the predicate"; samples via "full expansion now"). This proposal
records and structures that pre-made decision; git is handled by the orchestrator.
