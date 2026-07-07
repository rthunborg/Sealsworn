---
baseline_commit: 3ce6e9b159e02600487b49d0d0f69918396b079b
---

# Story 10.8: Darkness Fairness Moving-LoS Predicate and Readiness Sample Expansion

Status: review

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

> **Execution order (2026-07-07, sprint change — `sprint-change-proposal-2026-07-07-fr58.md`):** although
> numbered 10.8 for list continuity in `epics.md`, this story executes **immediately after Story 10.3 and
> BEFORE the Epic 12 block (Story 12.1)**. `sprint-status.yaml` encodes this by placing the `10-8-…` entry
> between `10-3-…` and the `epic-12` block (file order = execution order). The full Epic-10 order is
> `10-1 → 10-2 → 10-3 → 10-8 → 12-1 → 12-2 → 10-4 → 10-5 → 10-6 → 10-7`. **Orchestrator note (retro):**
> `story_plan.py` derives `is_last_in_epic` from NUMBERING, so it will report true for 10-8 even though Epic
> 10 execution continues at 10-4 after Epic 12 — the real Epic-10 close is after 10-7. Do NOT run an epic-end
> (Phase 8) retrospective off this story.

## Story

As a player,
I want Darkness levels to be judged fair by whether I necessarily SEE a hazard before I can reach it (not only
whether I see it from the entrance), and I want the MVP readiness seed samples to actually cover the target
sizes,
so that Darkness+Medium runs are not falsely blocked and the readiness verdict rests on a real sample.

## Story Type & Scope Boundary (READ FIRST)

**This is a READINESS/FAIRNESS story — a scoped strengthening of ONE pure board-scoped query (`DarknessFairnessQuery`
predicate (b)) plus a COORDINATED, ADDITIVE seed-sample expansion across the three Epic-10 readiness harnesses,
NOT a gameplay-feature story and NOT a generator change.** It discharges the two 10.6-gate-owned Decision items
Story 10.3 honestly surfaced and handed forward: (A) the FR58 `darkness_unseen_hazard` finding on Medium seeds
4004/5005, resolved by "strengthen the predicate"; and (B) the sub-target seed samples, discharged by "full
expansion now". Both directions were **pre-decided by the user 2026-07-07** — do NOT re-litigate the options,
implement the chosen ones. After this story, Story 10.6's gate scope shrinks to VERIFYING these two deliverables
plus the physical-device (G1–G7) gaps.

The two parts are ORDERED: **Part A (predicate + its deliberate test updates) lands FIRST, then Part B (sample
expansion)** — the sample expansion regenerates pins and re-classifies fairness verdicts, and those verdicts must
be FINAL (post-Part-A) before any pin/count is written. Doing Part B first would pin verdicts the predicate change
then invalidates.

- **This is NOT a domain/tactical/save/RNG/content/generator story.** Do NOT change any generator, layout
  algorithm, generation pipeline, `LevelValidator` check/check-order/codes, RNG stream, `GenerationResult` phase
  vocabulary, view model, save schema, or content definition. The ONLY production source you touch in Part A is
  `godot/scripts/generation/level/darkness_fairness_query.gd` (predicate (b), strengthened) plus a COMMENT-ONLY fix
  in `godot/scripts/run/run_orchestrator.gd` (`_check_darkness_fairness_live`). Part B touches ONLY test
  fixtures/harness seed catalogs, the sanctioned `tools/dump_*` drivers' seed lists, and the two readiness ledgers.
- **NO affinity-into-generation wiring (the affinity-driven GENERATION modifier stays DEFERRED).** Part A resolves
  FR58 by strengthening the QUERY, deliberately NOT by constraining Medium hazard-wrinkle placement or gating the
  wrinkle out under Darkness (that rejected option-1 is an affinity-aware GENERATION change that would re-pin Medium
  terrain fingerprints and pull affinity into generation). The generator stays affinity-blind; the affinity is
  assigned POST-generation (the 7.4 contract). [Source: `deferred-work.md` — "the affinity-driven GENERATION
  modifier stays deferred"; `generator-fairness-batch-readiness.md` §4 option 1 REJECTED, §7]
- **NO seed-regression fingerprint re-pin FROM Part A.** `DarknessFairnessQuery` is a pure READ over validator/LoS
  verdicts — it pins NO terrain fingerprint. Strengthening it changes no generator output, so NO Small/Medium/route/
  boss fingerprint moves because of Part A. (Part B DOES add NEW pinned fingerprint entries for the 45 additional
  Small + 45 additional Medium seeds — but ONLY additively, via the sanctioned dump tools, with the original 5+5
  pins byte-identical. That is a sanctioned ADDITIVE expansion, not a re-pin of existing values.)
- **The Flooded `_placeholder` electric interaction stays 10.7-owned.** Part B's affinity sample MUST surface
  `flooded_conductive` (its fairness verdict is the legal `not_a_darkness_level` PASS — Flooded is not a
  reduced-radius affinity, so it has no FR58 unseen-hazard risk). Do NOT realize the water/electric chain or resolve
  the placeholder here. [Source: `generator-fairness-batch-readiness.md` §7; `deferred-work.md`]
- **REFLECT/REUSE the canonical query — do NOT fork a second fairness algorithm.** The batch harness + the live
  gate REFLECT `DarknessFairnessQuery.check_board`'s verdict; they do not re-derive the reachable-hazard predicate.
  The strengthened predicate lives in ONE place. This is the same "no second pinning/predicate path" discipline
  10.2/10.3 enforced.

## The Core Insight Part A Formalizes (read before editing the predicate)

The FR58 fairness contract is "no unavoidable damage from unseen space." The v0 predicate (b) currently asks a
**static-from-entrance** question: "at spawn, is every REACHABLE hazard line-of-sight-visible FROM THE ENTRANCE at
the Darkness-reduced radius (2)?" For Medium 4004 (hazard at (9,4)) and 5005 (hazards at (10,2)+(12,2)), those
baked-wrinkle hazards are reachable but sit beyond radius 2 of the entrance, so they are entrance-unseen → the
current predicate FAILS `darkness_unseen_hazard`. That is a *conservative* fail: it never asks whether the hero
would necessarily SEE the hazard as they walk toward it.

The **strengthened (moving reduced-radius LoS / "seen-before-contact")** predicate asks the fair question: "under
stepwise 4-neighbour movement, does the hero necessarily SEE the hazard from some reachable cell BEFORE they can
step onto it?" Under the pinned v0 board facts this is provably true for EVERY reachable hazard:

1. **A hazard is walkable and sight-transparent.** `BoardCell.blocks_line_of_sight()` returns true ONLY for
   `Terrain.WALL` (`godot/scripts/tactical/board/board_cell.gd:33-34`); HAZARD is transparent (the 3.4 contract).
2. **To STEP ONTO a reachable hazard, the hero must first stand on an adjacent (4-neighbour) FLOOR/reachable cell**
   — the "step-from" cell. Reachability itself is a 4-neighbour terrain flood over non-WALL cells
   (`DarknessFairnessQuery._flood_terrain`), so any reachable hazard has at least one reachable 4-neighbour
   step-from cell (the flood arrived via one).
3. **From a step-from cell, the hazard is at Chebyshev/squared distance 1** — within the Darkness-reduced radius 2
   (floor 1), so it is *within radius*.
4. **LoS between two 4-adjacent cells can NEVER be occluded.** `TacticalLineQuery.has_line_of_sight` only inspects
   the INTERIOR cells of the supercover line (`range(1, max(1, line.size() - 1))`,
   `godot/scripts/tactical/targeting/tactical_line_query.gd:63`). For adjacent cells the line is `[origin, target]`
   with NO interior cell, so `blocking_cells` returns empty → `has_line_of_sight == true` unconditionally.

Therefore: **every reachable hazard is necessarily SEEN from its step-from cell before contact.** The strengthened
predicate is not a heuristic — it is a formalization that, given the v0 facts (hazards walkable + sight-transparent,
reduced radius ≥ 1, 4-neighbour movement), makes every *reachable* hazard fair. Medium 4004/5005 flip from
`darkness_unseen_hazard` FAIL to legitimate PASS. The guardrail still fails LOUD for genuinely-unfair configs the
v0 facts do NOT yet include (a sight-BLOCKING hazard, or forced/teleport movement that could drop the hero onto a
hazard without a see-first step) — preserve fail-loud discipline for those so a FUTURE story that adds them re-trips
the guard.

Predicate (a) is UNCHANGED: `entrance_on_hazard` (entrance IS a hazard = forced turn-1 damage, no see-first step
possible) and `entity_on_entrance` still FAIL. The reduced-radius floor (≥ 1), the four stable reason codes, the
`darkness_fairness_violation` top-level error code, the compact-diagnostics discipline, and purity (no RNG / no
command / no mutation) all stay.

## Acceptance Criteria

Sourced verbatim from `epics.md` (Epic 10, Story 10.8). Two parts (A: FR58 predicate; B: sample expansion).

**Part A — FR58 resolution (strengthen the predicate):**

1. **GIVEN** the `DarknessFairnessQuery` predicate (b) `REASON_UNSEEN_HAZARD` currently checks static
   line-of-sight from the ENTRANCE at the Darkness-reduced radius, **WHEN** the predicate is strengthened, **THEN**
   a REACHABLE hazard is fair iff the hero necessarily SEES it before contact under stepwise 4-neighbour movement at
   the Darkness-reduced radius (the v0 facts: hazards are walkable + sight-transparent, so a hazard is visible at
   distance 1 from any step-from cell and occlusion between adjacent cells is impossible — the strengthened check
   formalizes seen-before-contact instead of seen-from-entrance), **AND** predicate (a) entrance checks, the stable
   reason codes (`entrance_on_hazard`/`entity_on_entrance`/`darkness_unseen_hazard`/`invalid_darkness_candidate`),
   purity (no RNG/commands/mutation), compact diagnostics, and fail-loud discipline for genuinely-unfair
   configurations (e.g. future sight-blocking hazards or forced movement) are preserved.

2. **GIVEN** the ratified no-silent-drift contract governs the 10.3 batch expectations, **WHEN** the strengthened
   predicate lands, **THEN** Medium seeds 4004 (hazard at (9,4)) and 5005 (hazards at (10,2)+(12,2)) flip from
   classified `darkness_unseen_hazard` findings to legitimate PASS, and the batch's finding-presence assertions
   (`godot/tests/integration/test_generator_fairness_batch.gd`) plus the fairness-verdict tests
   (`godot/tests/unit/generation/test_darkness_fairness.gd`) are DELIBERATELY updated to match, **AND** a NEW test
   proves the moving-LoS semantics — a hand-built candidate where a hazard is entrance-unseen but necessarily
   seen-before-contact ⇒ PASS, plus a genuinely-unfair configuration that still FAILS `darkness_unseen_hazard`.

3. **GIVEN** `RunOrchestrator._check_darkness_fairness_live` runs the same query on the live board as a HARD
   run-progression gate, and `NodeEnterCommand` maps `elite_combat -> medium_combat_basic` so live runs DO generate
   Medium boards with baked HAZARD wrinkles, **WHEN** the false-premise comment (~lines 1094–1099, "v0 generated
   boards are all-FLOOR") is corrected, **THEN** the comment states that "all-FLOOR" holds only for the Small recipe
   (Medium bakes wrinkle-phase HAZARD cells) and that this check is a hard live progression gate, **AND** the
   resolution is recorded in `generator-fairness-batch-readiness.md` §4 (option "strengthen predicate" chosen by the
   user 2026-07-07), with the note that the predicate strengthening removes the latent false-positive hard-stop on
   live Darkness+Medium runs.

4. **GIVEN** the Epic-10 generation constraints, **WHEN** Part A lands, **THEN** NO generator / generation-pipeline
   change, NO seed-regression fingerprint re-pin from Part A (the query is not fingerprinted), and NO
   affinity-into-generation wiring are introduced.

**Part B — readiness sample expansion (full expansion now):**

5. **GIVEN** the headless-mechanical sample targets recorded in `seed-regression-suite-readiness.md` §3 and
   `generator-fairness-batch-readiness.md`, **WHEN** the samples are expanded, **THEN** generation Small reaches 50,
   Medium reaches 50, tactical reaches 25, reward reaches 20, boss reaches 10, and affinity reaches 10-per-affinity
   (every implemented affinity incl. Flooded-Conductive and Darkness surfaces in the assignment sample, with
   documented per-affinity counts); route already met 20/20 and is untouched.

6. **GIVEN** the ratified epic convention that the shared Small/Medium seed catalog stays in sync across the three
   Epic-10 harnesses, **WHEN** the generation samples are expanded, **THEN** the expansion is COORDINATED across
   10.1 (perf sample where it consumes the shared catalog), 10.2 (consolidated suite catalogs), and 10.3 (fairness
   batch) — never desynced or re-pinned in isolation, **AND** new pins are regenerated ONLY via the existing
   sanctioned `tools/dump_*` drivers, AFTER the Part A predicate change so verdicts are final, with the original
   pinned entries byte-identical (additive expansion, not a re-pin).

7. **GIVEN** full-suite runtime and the false-PASS discipline, **WHEN** the expanded suite runs, **THEN** the full
   headless suite stays under a stated sane wall-clock bound on the dev machine (an explicit AC guard) and the
   false-PASS grep guard discipline is preserved.

8. **GIVEN** the two readiness ledgers record the sample gaps, **WHEN** the targets are discharged, **THEN** both
   ledgers' §3 / gap tables are updated to reflect the discharged targets, **AND** the remaining non-mechanical gaps
   (G1–G7 physical-device passes) stay recorded as 10.6-owned.

9. **GIVEN** determinism and save gates, **WHEN** the whole story lands, **THEN** the 7 named RNG streams, zero new
   RNG draw sites, the 23-key `RunSnapshot` gate, `ProfileSnapshot`/`SettingsSnapshot` `SCHEMA_VERSION == 1`, and
   every non-Part-A fingerprint SOURCE hold, and the default deterministic paths stay byte-identical.

### AC Verification (how "done" is checked)

- **AC1 (predicate strengthened)** — `DarknessFairnessQuery.check_board` predicate (b) no longer FAILS a reachable
  hazard merely because it is entrance-unseen at the reduced radius. The new logic tests seen-before-contact: for
  each REACHABLE hazard, confirm it is LoS-visible at the reduced radius from at least one reachable 4-neighbour
  step-from cell (which is always true under the v0 facts — see "The Core Insight"). Predicate (a) still FAILS
  `entrance_on_hazard` / `entity_on_entrance`; `invalid_darkness_candidate` still guards a missing/empty/malformed
  board; the four `REASON_*` constants keep their exact string values; the method draws no RNG, runs no command, and
  the board-terrain-snapshot before/after is identical (purity). Verified by the updated + new tests below.
- **AC2 (deliberate test updates + new moving-LoS proof)** — in `test_darkness_fairness.gd`: the
  `_unseen_hazard_at_reduced_radius_fails_loud` and the `_unseen_hazard_...` case in the batch that placed a hazard
  "far down an OPEN corridor" now must be re-shaped, because that exact configuration (reachable hazard on an open
  corridor, entrance-unseen at radius 2) is now a legitimate PASS under moving-LoS. The NEW test proves the
  semantics with two cases: (i) a hand-built candidate where a hazard is entrance-unseen BUT necessarily
  seen-before-contact ⇒ PASS (e.g. the old "hazard far down the corridor" board); (ii) a genuinely-unfair
  configuration that still FAILS — since a sight-blocking hazard/forced-movement do not exist in v0, the retained
  FAIL cases are `entrance_on_hazard` and `entity_on_entrance` (predicate (a)), which are the still-valid
  "unavoidable, no see-first-step" configs. Document in the test why the old open-corridor FAIL became a PASS. In
  `test_generator_fairness_batch.gd`: the `medium_darkness_fail_seeds == [4004, 5005]` assertion, the
  `darkness_failure_count > 0` / `small_failures empty` / `final_readiness_fr58_darkness_met == false` assertions,
  and the `_real_darkness_finding_flags_recipe_rule_and_preserves_failing_seeds` test are DELIBERATELY updated: the
  generated-board Darkness fairness classification now yields ZERO failures (Small AND Medium PASS), so the batch's
  honest verdict becomes "generated Darkness boards meet the FR58 zero-tolerance bar." The forced/hand-built
  FAIL-path coverage (predicate (a) + `AlwaysFailValidator`) stays. Keep the finding/preserve MACHINERY exercised by
  a hand-built unfair board (predicate (a) FAIL) so the flag+preserve path is still proven; do NOT delete the
  machinery just because the generated catalog no longer trips it.
- **AC3 (comment fix + ledger record)** — the `_check_darkness_fairness_live` comment (~lines 1094–1099 of
  `run_orchestrator.gd`) is corrected: "all-FLOOR" holds only for the Small recipe; Medium bakes wrinkle-phase
  HAZARD cells; the check is a HARD live progression gate (a `darkness_fairness_violation` stops the run with no
  partial progression); and the strengthened predicate removes the latent false-positive on live Darkness+Medium
  runs. NO behavior change to the gate STRUCTURE (still error → stop). `generator-fairness-batch-readiness.md` §4
  records "strengthen predicate" chosen 2026-07-07 with the latent-false-positive note.
- **AC4 (no generation/affinity/pin change from Part A)** — a `git diff --stat` after Part A touches ONLY
  `darkness_fairness_query.gd`, `run_orchestrator.gd` (comment), the two test files, and the readiness ledger. NO
  generator/pipeline/`LevelValidator`/RNG file; NO fingerprint value changed; NO reward/generator affinity wiring.
- **AC5 (samples reach target)** — read live from each harness's catalog after expansion: Small = 50, Medium = 50
  (in the Small/Medium layout regression fixtures + the shared catalogs), tactical = 25 (the suite's tactical seed
  sample), reward = 20 (`REWARD_SEED_SAMPLE`), boss = 10 (`APPROVED_BOSS_SEED_CATALOG`), affinity = ≥ 10 seeds
  landing on EACH implemented affinity (`AFFINITY_SEED_SAMPLE` grown + per-affinity counts documented). Route stays
  20/20 (`test_route_generation_seed_regression.gd::APPROVED_FINGERPRINTS`), UNCHANGED. Every count read from the
  live catalog — never hand-typed to hit a number.
- **AC6 (coordinated, dump-tool-only, byte-identical originals)** — the shared Small/Medium catalog expands in ALL
  THREE sites that reference it (`tools/dump_performance_budgets.gd::LEVEL_LOAD_SEEDS`;
  `test_seed_batch_regression.gd::APPROVED_SEED_CATALOG` + `tools/dump_seed_batch_report.gd` seed list, imported by
  the 10.2 suite; `test_generator_fairness_batch.gd::BATCH_SEEDS`) to the SAME 50 seeds. New Small/Medium layout
  fingerprint pins are regenerated via `tools/dump_small_layout_fingerprints.gd` /
  `tools/dump_medium_layout_fingerprints.gd` (and the batch cross-check via `tools/dump_seed_batch_report.gd`),
  AFTER Part A. The original 5 pins (1001/2002/3003/4004/5005) in each fixture stay byte-identical. New boss seeds
  regenerated per the inline-catalog discipline (finale has NO dump tool — arena fixed, AI ZERO-RNG — so its new
  entries come from a live run, annotated per the AC4 preserved-catalog discipline).
- **AC7 (wall-clock + false-PASS guard)** — the full headless suite runs green under a STATED wall-clock bound on
  the dev machine (state the observed elapsed + the bound in the Completion Notes; propose a bound with sane
  headroom — the suite must not balloon because it now runs 50+50 generation seeds). The false-PASS grep guard is
  applied: grep the RAW runner output for `^FAIL`; the SIX documented stderr negatives (int64-overflow ×2,
  malformed-JSON ×3, `invalid_node_type` ×1) still PASS and are NOT a regression.
- **AC8 (ledgers updated, physical-device gaps stay)** — `seed-regression-suite-readiness.md` §3 gap table and
  `generator-fairness-batch-readiness.md` §5 are updated: the discharged rows marked MET (with the discharge date +
  the dump-tool provenance). The G1–G7 physical-device gaps stay recorded and 10.6-owned. FR58 §4 records the
  strengthened predicate as the resolution.
- **AC9 (determinism/save invariants hold)** — the 7 named RNG streams
  (`map`/`level`/`combat`/`loot`/`rewards`/`events`/`cosmetic`), zero new RNG draw sites, the 23-key `RunSnapshot`
  gate, `ProfileSnapshot`/`SettingsSnapshot` `SCHEMA_VERSION == 1`, and every non-Part-A fingerprint SOURCE + its
  pinned values (route 20/20; the original Small/Medium 5+5; boss original 5) are byte-identical; the default
  deterministic paths are unchanged. Proven by the green suite (which asserts these) + the byte-identical-originals
  cross-check.

## Tasks / Subtasks

- [x] **Task 1 — Confirm the canonical predicate + its callers + the v0 board facts (Part A / AC1)**
  - [x] Read `godot/scripts/generation/level/darkness_fairness_query.gd` predicate (b), lines 148–187 (the
        `seen_from_entrance` static check to strengthen), predicate (a) 132–146 (entrance checks to PRESERVE), the
        `_flood_terrain` 4-neighbour reachability 217–239, and the `REASON_*` + `_violation` + `check_board`
        signature. Confirmed the four reason strings and the `darkness_fairness_violation` top-level code stay stable.
  - [x] Confirmed the v0 board facts that make moving-LoS provably fair: `BoardCell.blocks_line_of_sight()` is true
        ONLY for `Terrain.WALL` (`godot/scripts/tactical/board/board_cell.gd:33-34`), HAZARD is walkable +
        sight-transparent (3.4); `TacticalLineQuery.blocking_cells` inspects only INTERIOR line cells
        (`tactical_line_query.gd:63` — `range(1, max(1, line.size() - 1))`, empty for adjacent cells), so adjacent
        cells always have LoS; `DarknessVisibilityLayer` reduced radius = 2, floor = 1
        (`darkness_visibility_layer.gd:76-77`, 105–114). Cited in the code comment.
  - [x] Read the two callers to keep working: `RunOrchestrator._check_darkness_fairness_live`
        (`run_orchestrator.gd:1100-1125`, the HARD live gate — a `darkness_fairness_violation` returns error → the
        run STOPS with no partial progression, mirroring `live_combat_failed`) and the batch harness's
        `_classify_darkness_fairness_over_batch` (`test_generator_fairness_batch.gd:262-308`). Both REFLECT
        the query verdict (neither re-derives the predicate) — after Part A they both simply observe the new PASS.

- [x] **Task 2 — Strengthen predicate (b) to moving reduced-radius LoS / seen-before-contact (Part A / AC1)**
  - [x] In `check_board`'s predicate-(b) loop, replaced the `seen_from_entrance` static test with a seen-before-contact
        test via the new `_seen_before_contact(board, hazard, terrain_reachable, radius_squared)` helper: a REACHABLE
        hazard is fair iff there exists at least one reachable 4-neighbour step-from cell from which the hazard is
        LoS-visible at the reduced radius. Used form (b) — the helper WALKS the reachable 4-neighbours and ACTUALLY
        tests `has_line_of_sight` from each (not a hard-coded PASS), so the guard stays genuinely re-trippable for a
        FUTURE sight-blocking hazard / forced-teleport landing. Kept the FIRST-violation return shape with the
        offending `hazard_cell` + compact diagnostics. Scratch-verified: the old far-corridor FAIL board now PASSES
        (reachable_seen=1), the adjacent-hazard board still PASSES, entrance-on-hazard still FAILS, sealed hazard
        still PASSES (reachable_seen=0).
  - [x] PRESERVED unchanged: predicate (a) `entrance_on_hazard` / `entity_on_entrance`; the `invalid_darkness_candidate`
        guards; the `not_a_darkness_level` neutral/non-Darkness PASS; the reduced-radius floor; the four `REASON_*`
        strings; the `darkness_fairness_violation` error code; compact PASS/FAIL diagnostics; purity (no RNG / no
        command / no mutation). Updated the class header comment block so predicate (b) reads "seen-before-contact
        under stepwise movement" with the full v0-facts proof cited. `reachable_seen_hazard_count` / `hazard_count`
        pass-report fields stay meaningful (reachable_seen = reachable hazards proven seen-before-contact).

- [x] **Task 3 — Deliberately update the two test files + add the moving-LoS proof (Part A / AC2)**
  - [x] `godot/tests/unit/generation/test_darkness_fairness.gd`: the existing
        `_unseen_hazard_at_reduced_radius_fails_loud` places a reachable hazard "far down the open corridor"
        (distance 7 > radius 2) and asserts FAIL — under moving-LoS that is now a legitimate PASS. Convert it into
        the NEW moving-LoS proof: assert that an entrance-unseen-but-reachable hazard on an open path PASSES (the
        hero necessarily sees it from the adjacent step-from cell), with a comment explaining the deliberate change
        (was FAIL under static-from-entrance, now PASS under seen-before-contact). KEEP `_hazard_visible_at_reduced_radius_passes`
        (a within-radius hazard still passes), `_entrance_on_hazard_fails_loud`, `_entity_on_entrance_fails_loud`,
        `_sealed_unreachable_hazard_does_not_fail` (unreachable hazard is never a risk — still passes),
        `_neutral_level_is_not_applicable`, `_check_is_pure_no_mutation`. Update `_failure_carries_seed_phase_and_reason`
        so its FAIL board uses a config that STILL fails (an `entrance_on_hazard` / `entity_on_entrance` board, since
        the old far-corridor hazard no longer fails) — keep it proving the failure carries seed + phase + reason +
        the stable `darkness_fairness_violation` code + `phase_for_reason` mapping. Add an explicit
        "genuinely-unfair still FAILS" case (predicate (a): entrance-on-hazard is the v0 unavoidable-no-see-first
        config).
  - [x] `godot/tests/integration/test_generator_fairness_batch.gd`: DELIBERATELY update the generated-board Darkness
        classification expectations now that Medium 4004/5005 PASS. Specifically:
        - `_batch_darkness_fairness_verdict_recorded_for_every_generated_board`: `verdict_count` still == 10; the
          `medium_darkness_fail_seeds` assertion (currently `== [4004, 5005]`) becomes an assertion that the
          generated-board Darkness failures are now EMPTY (all 10 generated boards PASS) — with a comment recording
          the deliberate flip and WHY (moving-LoS predicate; Story 10.8). The per-finding shape assertions stay but
          now iterate an empty set.
        - `_zero_tolerance_and_retry_exhaustion_thresholds_hold_for_the_approved_catalog`: the
          `darkness_failure_count > 0` and `final_readiness_fr58_darkness_met == false` assertions FLIP — the
          generated-catalog Darkness half now MEETS the FR58 zero-tolerance bar (0 failures). Assert
          `darkness_failure_count == 0` and `final_readiness_fr58_darkness_met == true` (comment the deliberate
          change).
        - `_real_darkness_finding_flags_recipe_rule_and_preserves_failing_seeds`: this test required a REAL
          generated Darkness finding to exercise the flag+preserve path. Since generated boards no longer trip it,
          RE-POINT this test to exercise the flag+preserve path via a HAND-BUILT unfair board (predicate (a)
          `entrance_on_hazard`, or the forced `AlwaysFailValidator` seam already present) so the AC3 flag+preserve
          MACHINERY stays proven — OR fold its intent into the forced-seam test
          `_threshold_breach_flags_recipe_rule_retry_limit_and_preserves_failing_seed`. Do NOT delete the
          flag/preserve machinery; keep it exercised.
        - Keep `_batch_fairness_verdict_asserted_for_every_implemented_affinity`,
          `_assigned_affinity_fairness_reflects_the_query_verdict` (Darkness PASS + non-Darkness `not_a_darkness_level`),
          and `_unseen_hazard_fails_and_seen_hazard_passes_reflecting_the_query` — but the FAIL half of the last one
          (hazard far down corridor) must be re-shaped to a config that STILL fails (predicate (a)) since the
          far-corridor hazard now passes.
        - Update the module header comment (lines 429–435, "HONEST FINDING … Medium 4004/5005 FAIL") to record that
          10.8 strengthened the predicate and those seeds now PASS.
  - [x] **CRITICAL — a THIRD stale FAIL test NOT named in the epics.md ACs:**
        `godot/tests/unit/run/test_live_affinity_flow.gd::_darkness_fairness_violation_on_the_live_path_stops_with_no_partial_progression`
        (Story 11.4, lines 153–189) builds `_unfair_darkness_board_snapshot()` (a reachable HAZARD at (8,6),
        distance 7 from the entrance, "unseen from the entrance at the reduced radius", lines 233–262) and asserts
        the live gate returns `darkness_fairness_violation`. Under moving-LoS that board is now a legitimate PASS
        (the hazard is seen from its adjacent step-from cell before contact). DELIBERATELY re-shape
        `_unfair_darkness_board_snapshot()` to a config that STILL fails through the live gate — the cleanest is
        `entrance_on_hazard` (put HAZARD on the entrance cell (1,6)) or `entity_on_entrance` (an entity occupying
        the entrance), i.e. a predicate-(a) violation (the v0 "unavoidable, no see-first-step" config). Keep the
        test's real value: it proves the violation propagates through `_check_darkness_fairness_live` (verbatim
        `fairness_reason` + seed + phase + node id/type, no partial progression, no `map` RNG). Update its inline
        comments (which currently say "reachable HAZARD cell UNSEEN at the reduced radius" and "v0 boards are
        all-FLOOR so the STOP path is structurally unreachable through the real generator") to reflect the new
        predicate + that Medium DOES bake hazards live.
  - [x] Grep the whole repo for ANY other test/tool that pins the old static-from-entrance Darkness FAIL behavior
        on a far/open-path hazard and update it deliberately (the three known sites are the two epics.md-named test
        files + `test_live_affinity_flow.gd`; also update the header comment in
        `godot/tools/dump_generator_fairness_report.gd` lines 3–8, which narrates "the recorded Darkness FR58
        finding on Medium seeds 4004 + 5005" — that finding is resolved after Part A). A silent stale FAIL
        expectation would break the suite.

- [x] **Task 4 — Correct the false-premise comment on the live gate (Part A / AC3)**
  - [x] In `godot/scripts/run/run_orchestrator.gd` `_check_darkness_fairness_live` (the comment block ~lines
        1094–1099), correct "v0 generated boards are all-FLOOR": state that all-FLOOR holds ONLY for the Small
        recipe; the Medium recipe bakes wrinkle-phase `Terrain.HAZARD` cells (`elite_combat -> medium_combat_basic /
        SIZE_MEDIUM` per `NodeEnterCommand.NODE_TYPE_RECIPE`), so live Medium Darkness runs DO produce hazard
        boards; this check is a HARD live progression gate (a `darkness_fairness_violation` stops the run with no
        partial progression); and Story 10.8's strengthened moving-LoS predicate removes the latent false-positive
        hard-stop those boards would have tripped under the static-from-entrance predicate. COMMENT ONLY — do not
        change the gate's structure/behavior (still error → stop). Also correct the mirror comment on
        `resolve_combat_node_live` (~lines 1003–1007) which repeats the "all-FLOOR by construction" premise.

- [x] **Task 5 — Record the FR58 resolution in the fairness ledger (Part A / AC3, AC8)**
  - [x] Edit `_bmad-output/planning-artifacts/generator-fairness-batch-readiness.md` §4: record that the user chose
        option 2 ("strengthen the fairness predicate") on 2026-07-07, that Story 10.8 formalized predicate (b) from
        static-from-entrance to moving reduced-radius LoS (seen-before-contact), that Medium 4004/5005 are now
        legitimate PASS, and that the strengthening removes the latent false-positive HARD-stop on live
        Darkness+Medium runs (`RunOrchestrator._check_darkness_fairness_live`). Keep §4's history intact (the finding
        was real; it is now resolved). Add a Change Log row (§8). Do NOT alter §4's statement that this is NOT a
        generator change and re-pins NO terrain fingerprint.

- [x] **Task 6 — Expand the shared Small/Medium generation catalog to 50/50, coordinated + dump-tool-only (Part B / AC5, AC6)**
  - [x] AFTER Part A is landed + green, pick 45 additional Small + 45 additional Medium seeds (extend the existing
        `[1001,2002,3003,4004,5005]`; use varied, documented seeds — mirror the route expansion's spread style). Add
        the SAME 50-seed list to EVERY shared-catalog site so they never desync:
        `tools/dump_performance_budgets.gd::LEVEL_LOAD_SEEDS` (10.1 perf);
        `godot/tests/unit/generation/test_seed_batch_regression.gd::APPROVED_SEED_CATALOG` (both recipes; the 10.2
        consolidated suite imports this — no second copy) and `tools/dump_seed_batch_report.gd`'s inline seed list
        (line 21); `godot/tests/integration/test_generator_fairness_batch.gd::BATCH_SEEDS` (10.3);
        `godot/tools/dump_generator_fairness_report.gd`'s inline `seeds` list (line 29, the fairness-report driver
        for the batch). Keep all these lists identical — a desync between the batch's `BATCH_SEEDS` and the layout
        fixtures' `APPROVED_FINGERPRINTS` keys would break the batch's cross-check. NOTE the batch's count
        assertions (`verdict_count == BATCH_SEEDS.size() * BATCH_RECIPES.size()`, line 441; `preserved_seeds.size()
        == BATCH_SEEDS.size()`, line 701) are computed from the constants and auto-adjust to the new size — but the
        stale narrative comments "5 Small + 5 Medium = 10" (lines 27, 255, 439, 442) should be refreshed to the new
        catalog size.
  - [x] Regenerate the NEW Small + Medium layout fingerprint pins via the sanctioned dumps:
        `tools/dump_small_layout_fingerprints.gd` → the 45 new entries in
        `test_small_level_layout_seed_regression.gd::APPROVED_FINGERPRINTS`; `tools/dump_medium_layout_fingerprints.gd`
        → the 45 new entries in `test_medium_level_layout_seed_regression.gd::APPROVED_FINGERPRINTS`; the batch
        cross-check pins in `test_seed_batch_regression.gd::APPROVED_SEED_CATALOG` via `tools/dump_seed_batch_report.gd`.
        The ORIGINAL five pins in every fixture MUST stay byte-identical (this is an ADDITIVE expansion — never a
        re-pin of existing values; the divergence cross-check in the batch fixture enforces agreement). Annotate each
        new catalog entry with its AC4 tactical-decision note per the existing preserved-catalog discipline. Add a
        Change Log row to each fixture header documenting the 5→50 expansion + the dump provenance + date.
  - [x] Confirm the 50 Small + 50 Medium generation seeds all PASS `LevelValidator` on the unperturbed attempt 0
        (`attempts == 1`) so the zero-tolerance thresholds still hold by construction. If ANY new seed exhausts the
        bounded retry OR trips a zero-tolerance validator code, STOP and report it as a genuine readiness finding
        (that is a new unwinnable/unfair seed — a `needs-human` balance/threshold decision per the sprint-change
        handoff, NOT something to silently drop). Also confirm the 50 Medium seeds all PASS the (now-strengthened)
        Darkness fairness check — with moving-LoS every reachable-hazard Medium board PASSES, so the batch's
        Darkness-failure set stays empty; if a genuinely unseen-before-contact config somehow appears (it should
        not under v0 facts), that too is a `needs-human` finding.

- [x] **Task 7 — Expand tactical (→25), reward (→20), boss (→10), affinity (→10-per-affinity) (Part B / AC5)**
  - [x] Tactical → 25: grow the consolidated suite's tactical seed sample
        (`test_seed_regression_suite.gd::_tactical_fixtures_report_fingerprint_and_pass_fail`, currently the inline
        8-seed `[1, 7, 42, 99, 2026, 314, 777, 8675309]`) to ≥ 25 deterministic command/board fixtures (per-seed
        determinism, not a pinned fingerprint format — so this is additive seeds, no new pin format). Keep the
        two-run reproducibility + "board actually advanced" assertions.
  - [x] Reward → 20: grow `test_seed_regression_suite.gd::REWARD_SEED_SAMPLE` (currently 8) to 20 per-seed cases
        (per-seed determinism via `RunOrchestrator.generate_reward_offer` / `generate_passive_reward_offer`).
  - [x] Boss → 10: add ≥ 5 more annotated seeds to
        `godot/tests/integration/finale/test_finale_seed_regression.gd::APPROVED_BOSS_SEED_CATALOG` (currently 5:
        4242/1/7777/9e18/314159) to reach 10, each annotated per the AC4 preserved-catalog discipline. Finale has
        NO `dump_*` tool (fixed arena + ZERO-RNG AI), so the composite for each new seed comes from a live run,
        recorded inline. The 10.2 suite iterates this imported catalog — no second copy.
  - [x] Affinity → 10-per-affinity: grow `test_seed_regression_suite.gd::AFFINITY_SEED_SAMPLE` (currently 8 mixed)
        so that at least 10 seeds land on EACH implemented affinity (`scorched`, `flooded_conductive`, `cursed`,
        `darkness`) via `RunOrchestrator.assign_affinity` on the `map` stream — a targeted-seed search per affinity.
        DOCUMENT the per-affinity counts (which seeds map to which affinity) in the suite + the ledger. Flooded-Conductive
        and Darkness MUST both surface with ≥ 10 (the AC calls them out explicitly). Do NOT wire any affinity EFFECT
        into generation — this is a per-seed ASSIGNMENT-determinism sample only.
  - [x] Route: UNCHANGED — `test_route_generation_seed_regression.gd::APPROVED_FINGERPRINTS` is already 20/20 (8
        original + 12 added by 10.2). Confirmed untouched (git diff --stat empty for that file).
  - [x] **DELIBERATELY update the suite's honest-sample assertion block**
        (`test_seed_regression_suite.gd::_mvp_readiness_targets_are_stated_and_current_sample_is_honest`, lines
        654–666): the current `assert_true(small_count >= 5, "... temporary %d of 50 ...")` (+ the medium/boss/
        reward/affinity twins) are phrased as "still-temporary sub-target" tripwires. After the expansion, flip them
        to assert the DISCHARGED targets read live from the catalogs: `small_count == 50`, `medium_count == 50`,
        `boss_count == 10`, `reward_count == 20`, and the tactical fixture count `>= 25`; and update the "still-temporary
        / CANNOT pass final MVP readiness" comment (654–666) to "MET as of 2026-07-07 (Story 10.8) — see the
        readiness ledger." For AFFINITY, `affinity_count = AFFINITY_SEED_SAMPLE.size()` is a flat sample-size proxy —
        grow it and assert both the sample size AND (ideally, a new helper) that ≥ 10 seeds land on EACH implemented
        affinity, so "10-per-affinity" is actually proven, not proxied. Keep the assertions reading LIVE from the
        catalogs (never hand-typed) — that tripwire against a silently-shrunk sample stays.

- [x] **Task 8 — Update both readiness ledgers' gap tables (Part B / AC8)**
  - [x] `seed-regression-suite-readiness.md` §3: mark tactical (25), Small (50), Medium (50), reward (20),
        per-affinity (10-each), boss (10) as MET, each with the discharge date (2026-07-07) + the dump-tool/live
        provenance; route stays MET. Update §5 / §7 / §8 (Change Log) accordingly.
  - [x] `generator-fairness-batch-readiness.md` §5: mark Small (50) + Medium (50) as MET via the coordinated
        expansion, and note the affinity-coverage rows discharged; keep §4 (the FR58 resolution from Task 5). Update
        §8 Change Log.
  - [x] Both ledgers: EXPLICITLY keep the remaining non-mechanical gaps (the G1–G7 physical-device sample passes)
        recorded as 10.6-owned — those are NOT discharged by this story.

- [x] **Task 9 — Full-suite green under a stated wall-clock bound + false-PASS guard + invariant re-verification (AC7, AC9)**
  - [x] Run the full headless suite via the console binary (the `godot` binary is NOT on the Bash/`where` PATH):
        `C:/Users/Rasmus/Godot_v4.6.3-stable_win64.exe/Godot_v4.6.3-stable_win64_console.exe --headless --path
        C:\Sealsworn\godot --scene res://tests/headless/test_runner.tscn --quit-after 10` (or via PowerShell
        `godot` shim). TIME it (wall-clock). Apply the false-PASS grep guard on the RAW output: `^FAIL` count must
        be 0; the SIX documented stderr negatives (int64-overflow ×2, malformed-JSON ×3, `invalid_node_type` ×1)
        still PASS and are NOT a regression. Record the observed elapsed + the proposed sane bound (with headroom
        for 50+50 generation seeds) in the Completion Notes as the explicit AC7 guard.
  - [x] Run `git diff --check` (whitespace/EOL) and confirm it is clean.
  - [x] Re-verify the determinism/save invariants HELD (they are asserted by the suite, but state them in the
        Completion Notes): 7 named RNG streams; zero new RNG draw sites; the 23-key `RunSnapshot` gate;
        `ProfileSnapshot`/`SettingsSnapshot` `SCHEMA_VERSION == 1`; every non-Part-A fingerprint SOURCE + the
        byte-identical original pins (route 20; Small/Medium original 5+5; boss original 5). Confirm the default
        deterministic paths are byte-identical (Part A touches a pure query + a comment; Part B is additive seeds +
        additive pins).

## Dev Notes

### Current state of the files this story touches (READ before editing)

- **`godot/scripts/generation/level/darkness_fairness_query.gd` (Part A — the ONLY predicate change).** Pure
  `RefCounted` board-scoped FR58 fairness query. `check_board(board, affinity_id, repository, seed, entrance)`
  returns `not_a_darkness_level` PASS for neutral/non-Darkness; predicate (a) FAILS `entrance_on_hazard` /
  `entity_on_entrance`; predicate (b) currently FAILS `darkness_unseen_hazard` for a reachable hazard NOT
  LoS-visible FROM THE ENTRANCE at the reduced radius (lines 148–176 — the `seen_from_entrance` test to
  strengthen); `invalid_darkness_candidate` guards a malformed board. Reduced radius = 2 (floor 1) via
  `DarknessVisibilityLayer`. Reachability is a 4-neighbour non-WALL terrain flood (`_flood_terrain`, 217–239). PURE
  (no RNG/command/mutation). The four `REASON_*` consts (64–67) and the `darkness_fairness_violation` error code are
  stable — keep them.
- **`godot/scripts/run/run_orchestrator.gd` (Part A — COMMENT ONLY).** `_check_darkness_fairness_live`
  (1100–1125) runs the SAME query on the live board as a HARD run-progression gate: a `darkness_fairness_violation`
  returns error and the run STOPS with no partial progression (mirrors `live_combat_failed`). The comment at
  1094–1099 falsely says "v0 generated boards are all-FLOOR" — true only for Small. `resolve_combat_node_live`
  (967+) generates the level, assigns the affinity on `map`, runs the fairness gate. `NodeEnterCommand` maps
  `elite_combat -> medium_combat_basic / SIZE_MEDIUM` (`node_enter_command.gd:43-52`), so live elite nodes DO
  generate Medium boards with baked HAZARD wrinkles → the latent false-positive the predicate strengthening removes.
- **`godot/tests/unit/generation/test_darkness_fairness.gd` (Part A — deliberate update + new proof).** 7.6's unit
  suite. Its `_unseen_hazard_at_reduced_radius_fails_loud` + `_failure_carries_seed_phase_and_reason` place a
  reachable hazard far down an OPEN corridor and assert FAIL — that config becomes a legitimate PASS under
  moving-LoS. Re-shape per Task 3.
- **`godot/tests/unit/run/test_live_affinity_flow.gd` (Part A — deliberate update; NOT named in the epics.md ACs).**
  11.4's live-flow suite. `_darkness_fairness_violation_on_the_live_path_stops_with_no_partial_progression`
  (153–189) drives `_unfair_darkness_board_snapshot()` (a hazard at (8,6), distance 7, "unseen from the entrance",
  233–262) through `_check_darkness_fairness_live` and asserts `darkness_fairness_violation`. This far-corridor
  hazard becomes a PASS under moving-LoS → re-shape the fixture to a predicate-(a) FAIL (Task 3). Its sibling
  fair-pass test (a Darkness live node passing by construction) stays valid.
- **`godot/tests/integration/test_generator_fairness_batch.gd` (Part A — deliberate update; Part B — `BATCH_SEEDS`).**
  10.3's batch. `_classify_darkness_fairness_over_batch` (262–308) reflects the query verdict per (recipe, seed).
  The generated-board classification currently asserts `medium_darkness_fail_seeds == [4004,5005]`,
  `darkness_failure_count > 0`, `final_readiness_fr58_darkness_met == false`, and needs a real finding for the
  flag+preserve test — ALL flip/re-point after Part A (Task 3). `BATCH_SEEDS` (63) is one of the three shared-catalog
  sites to expand in Part B.
- **`godot/tests/unit/generation/test_seed_batch_regression.gd` (Part B).** The 3.7 full-`generate` batch;
  `APPROVED_SEED_CATALOG` (54+) holds the shared `[1001,2002,3003,4004,5005]` for both recipes with pinned terrain
  fingerprints + AC4 notes. The 10.2 consolidated suite IMPORTS this constant (no copy). Expand to 50 both recipes.
- **`test_small_level_layout_seed_regression.gd` / `test_medium_level_layout_seed_regression.gd` (Part B — new
  pins).** Per-seed `APPROVED_FINGERPRINTS` dicts (the canonical Small/Medium terrain fingerprint SOURCE the batch
  cross-checks). Small's header explicitly notes Small fingerprints gain extra WALL cells but NEVER a HAZARD — the
  structural reason Small is fair-under-Darkness (no hazard) and Medium is not-static-fair (hazard wrinkles). Add 45
  new entries each via the sanctioned dumps; keep the original 5 byte-identical.
- **`godot/tests/integration/test_seed_regression_suite.gd` (Part B).** The 10.2 consolidated suite. Owns the
  tactical seed sample (inline `[1,7,42,99,2026,314,777,8675309]` in `_tactical_fixtures_...`, →25),
  `REWARD_SEED_SAMPLE` (104, →20), `AFFINITY_SEED_SAMPLE` (105, →10-per-affinity). Imports
  `SeedBatchRegressionTest.APPROVED_SEED_CATALOG`, `FinaleSeedRegressionTest.APPROVED_BOSS_SEED_CATALOG`, and the
  route fingerprints — expanding those upstream fixtures flows through automatically.
- **`godot/tests/integration/finale/test_finale_seed_regression.gd` (Part B — boss →10).** Inline
  `APPROVED_BOSS_SEED_CATALOG` (5 seeds; NO dump tool — fixed arena, ZERO-RNG AI). Add 5 annotated seeds from live
  runs.
- **`tools/dump_performance_budgets.gd` (Part B — shared catalog).** `LEVEL_LOAD_SEEDS` (42) = the shared
  `[1001,2002,3003,4004,5005]`, the 10.1 perf harness's level-load sample. Expand to the same 50.
- **`tools/dump_seed_batch_report.gd` / `tools/dump_small_layout_fingerprints.gd` /
  `tools/dump_medium_layout_fingerprints.gd` (Part B — the sanctioned regenerators).** `tools/**` is excluded from
  every export preset (provably cannot ship). Use these to regenerate the new pins AFTER Part A.

### Why Part A before Part B (do NOT reorder)

Part B expands the fairness batch to 50 Medium seeds and regenerates pins. Under the OLD static-from-entrance
predicate, additional Medium seeds beyond 4004/5005 that also bake entrance-unseen hazards would FAIL
`darkness_unseen_hazard`, and the batch's finding-set/count assertions would have to encode those. The WHOLE POINT
of Part A is that all reachable-hazard Darkness configs become PASS (moving-LoS). So Part A must land first, making
the batch's Darkness-failure set EMPTY, before Part B's 50-seed expansion is classified/pinned. Pinning verdicts or
counts before Part A would encode soon-to-be-invalid expectations. [Source:
`sprint-change-proposal-2026-07-07-fr58.md` §2 Technical impact — "AFTER the Part A predicate change so verdicts are
final"; §4.1 AC group; Change-Nav 6.4]

### Epic-10 conventions ratified by earlier stories (constraints — from the epic retro-notes)

- **[10.3, Phase 3] The shared Small/Medium seed catalog `[1001,2002,3003,4004,5005]` is SHARED by the 10.1 perf
  harness, the 10.2 consolidated regression suite, AND the 10.3 fairness batch — expand all three TOGETHER, never
  desync or re-pin one harness alone.** This story's Part B is exactly that coordinated expansion (the three sites:
  `LEVEL_LOAD_SEEDS`, `APPROVED_SEED_CATALOG`+`BATCH_SEEDS` via the imported constant, and the dump drivers). [Source:
  `_bmad-output/auto-gds/retro-notes/epic-10.md` §10-3]
- **[10.3, Phase 5] The real FR58 finding: 7.6's Darkness suite only ever exercised Small (all-FLOOR) seeds, so
  Medium-recipe baked hazards under Darkness went undetected until the 10.3 batch. Test the whole recipe×affinity
  matrix, not just the easy recipe.** After Part A, this story's expanded 50-Medium fairness classification
  exercises the full Medium recipe under Darkness (all PASS under moving-LoS). The "v0 boards are all-FLOOR" premise
  is TRUE only for Small — the comment fix (Task 4) and the batch header update (Task 3) both correct it. [Source:
  `_bmad-output/auto-gds/retro-notes/epic-10.md` §10-3]
- **[10.2, Phase 5] Avoid blanket "leave everything untouched" clauses that contradict a specific sanctioned
  task.** This story explicitly SANCTIONS editing `darkness_fairness_query.gd` predicate (b), the two test files,
  the shared catalogs, the dump drivers' seed lists, the layout fixtures' new pins, and the two ledgers — those
  sanctioned edits OVERRIDE any generic "keep the harness untouched" reflex. Route regression, generator/pipeline,
  `LevelValidator`, RNG, save schema stay untouched. [Source: `_bmad-output/auto-gds/retro-notes/epic-10.md` §10-2]
- **[10.1, Phase 5] `export_presets.cfg` already carries an iOS preset scaffold; iOS packaging is availability gap
  G7 for the 10.6 gate.** Not this story's concern beyond leaving the G1–G7 physical-device gaps recorded as
  10.6-owned in the ledgers (Task 8). [Source: `_bmad-output/auto-gds/retro-notes/epic-10.md` §10-1]
- **[10.8, Phase 0] `is_last_in_epic` is derived from NUMBERING, so the orchestrator will mis-report 10-8 as the
  Epic-10 close.** The real close is after 10-7; do NOT run an epic-end retrospective off this story. (Orchestrator
  concern — noted for completeness.) [Source: `_bmad-output/auto-gds/retro-notes/epic-10.md` §10-8]

### Deferred-work items that OVERLAP this story (fold in — do NOT reopen unrelated ledger entries)

- **The affinity-driven GENERATION modifier stays DEFERRED (a separate later generation-modifier story).** Part A
  MUST NOT wire affinity into generation (`RewardOfferBuilder` / reward tables / `EntityRewardPlacer` / the
  generator). FR58 is resolved by strengthening the QUERY, not by constraining generation. [Source:
  `deferred-work.md` — the 10.3 review entry + the 11.4 defer bullets; `generator-fairness-batch-readiness.md` §7]
- **The Flooded `_placeholder` electric interaction stays 10.7-owned.** Part B's affinity sample surfaces
  `flooded_conductive` (verdict `not_a_darkness_level`), but this story does NOT realize the water/electric chain or
  resolve the placeholder. [Source: `deferred-work.md`; `generator-fairness-batch-readiness.md` §7]
- **The 10.3 FR58 `darkness_unseen_hazard` finding was recorded as a 10.6-gate readiness signal (NOT a defect, NOT
  a cross-story defer).** This story DISCHARGES it by strengthening the predicate — the established
  per-story-resolution pattern (the ledger records the resolution; no new defer entry needed). The G1–G7
  physical-device gaps stay recorded + 10.6-owned. [Source: `deferred-work.md` — 10.3 review entry]
- Every OTHER deferred-work entry (Necromancer/Shadeblade class-kit, `OutpostRenderView` caching, the 3.1
  `min_tactical_wrinkles < 0` branch, etc.) is OUT of scope — do NOT touch. Do NOT re-open or re-defer them.

### Testing standards

- Headless GDScript tests under `godot/tests/` mirroring the domain (`unit/generation/`, `integration/`,
  `integration/finale/`). Every test file `extends "res://tests/unit/test_case.gd"` and exposes `run() -> Dictionary`
  returning `result()`; assertions via `assert_true` / `assert_equal` / `assert_false` with a descriptive message.
- Deterministic, no rendering/audio/UI dependency. The fairness query + the seed batches are pure/read-only.
- DELIBERATE-UPDATE contract: any pinned fingerprint changes ONLY with an intentional change re-pinned in the SAME
  PR via the matching `tools/dump_*` — never hand-edited to silence a drift. Part B's new pins follow this; Part A
  re-pins NOTHING.
- Full suite (must pass before review/done):
  `godot --headless --path C:\Sealsworn\godot --scene res://tests/headless/test_runner.tscn --quit-after 10`
  (the `godot` binary is not on the Bash PATH — use the PowerShell shim or
  `C:/Users/Rasmus/Godot_v4.6.3-stable_win64.exe/Godot_v4.6.3-stable_win64_console.exe`). Apply the false-PASS grep
  guard (grep raw output for `^FAIL`; the 6 documented stderr negatives still PASS).

### Project Structure Notes

- Production Godot code under `godot/`; the ONLY production edits are `godot/scripts/generation/level/darkness_fairness_query.gd`
  (predicate) and `godot/scripts/run/run_orchestrator.gd` (comment). Tests under `godot/tests/`; `tools/` drivers
  under `godot/tools/`; planning ledgers under `_bmad-output/planning-artifacts/`. No new files strictly required
  (the new moving-LoS proof lives inside the existing `test_darkness_fairness.gd`); adding a dedicated test file is
  acceptable if it reads cleaner, but keep it under `godot/tests/unit/generation/`.
- Naming: `snake_case` files/functions/vars, `PascalCase` classes, `UPPER_SNAKE_CASE` consts. Preserve the existing
  `REASON_*` / `CODE_*` conventions.

### Project Context Rules (from `project-context.md` / `AGENTS.md`)

- Scene-independent domain model owns tactical truth; scenes mirror outcomes. `DarknessFairnessQuery` is a pure
  domain/query surface — keep it scene-free, RNG-free, mutation-free.
- Use named RNG streams for gameplay-affecting randomness; this story adds ZERO RNG draw sites (the query is pure; the
  sample expansion only drives seeds through systems that already draw their existing streams).
- Save versioned domain snapshots only; the 23-key `RunSnapshot` gate + `ProfileSnapshot`/`SettingsSnapshot`
  `SCHEMA_VERSION == 1` are unmoved.
- Static content uses JSON/CSV source + typed Resources through repository boundaries; unchanged here.
- Headless simulation must not depend on rendering/audio/UI; all new/updated tests are headless.
- Do NOT introduce cloud/multiplayer/telemetry/.NET. Preserve unrelated dirty worktree files.
- Update `sprint-status.yaml` in sync with story status; keep `deferred-work.md` discipline (the FR58 item is
  discharged here, not re-deferred).

### References

- [Source: `_bmad-output/planning-artifacts/epics.md#Story 10.8` — the verbatim AC groups (Parts A + B) + the
  execution-order note]
- [Source: `_bmad-output/planning-artifacts/sprint-change-proposal-2026-07-07-fr58.md` — the user-approved
  direction: Part A = "strengthen the predicate", Part B = "full expansion now"; §2 impact incl. "AFTER Part A so
  verdicts are final" + byte-identical originals + wall-clock guard; §5 handoff]
- [Source: `_bmad-output/planning-artifacts/generator-fairness-batch-readiness.md` §4 (the three FR58 options — 10.8
  takes option 2), §5 (50/50 target + 5-of-50 gap + no-isolated-expansion), §7 (10.6 handoff; affinity-into-generation
  + Flooded placeholder deferrals), §8]
- [Source: `_bmad-output/planning-artifacts/seed-regression-suite-readiness.md` §3 (the 7 sample targets: tactical
  25, Small 50, Medium 50, route 20 MET, reward 20, per-affinity 10, boss 10), §5 (DELIBERATE-UPDATE discipline)]
- [Source: `godot/scripts/generation/level/darkness_fairness_query.gd` — predicate (b) lines 148–176 to strengthen;
  predicate (a), reason codes, purity to preserve]
- [Source: `godot/scripts/run/run_orchestrator.gd` `_check_darkness_fairness_live` ~1094–1125 — the hard live gate +
  false "all-FLOOR" premise comment]
- [Source: `godot/scripts/core/commands/node_enter_command.gd:43-52` — `NODE_TYPE_RECIPE` maps `elite_combat ->
  medium_combat_basic / SIZE_MEDIUM`]
- [Source: `godot/scripts/tactical/board/board_cell.gd:33-34` — `blocks_line_of_sight()` true ONLY for WALL (HAZARD
  transparent)]
- [Source: `godot/scripts/tactical/targeting/tactical_line_query.gd:44-76` — `has_line_of_sight` inspects only
  INTERIOR line cells; adjacent cells always have LoS]
- [Source: `godot/scripts/tactical/fog/darkness_visibility_layer.gd:76-77,105-114` — reduced radius 2, floor 1]
- [Source: `godot/tests/unit/generation/test_darkness_fairness.gd` — the 7.6 unit suite to deliberately update +
  extend with the moving-LoS proof]
- [Source: `godot/tests/integration/test_generator_fairness_batch.gd` — the 10.3 batch (`BATCH_SEEDS`,
  `_classify_darkness_fairness_over_batch`, the `[4004,5005]` / `> 0` / `final_readiness_...` assertions to flip)]
- [Source: `godot/tests/unit/run/test_live_affinity_flow.gd:153-262` — the 11.4 live-gate violation test +
  `_unfair_darkness_board_snapshot()`; the THIRD stale static-from-entrance FAIL to deliberately re-shape (Task 3)]
- [Source: `godot/tools/dump_generator_fairness_report.gd:3-8,29` — the fairness-report driver: stale "4004+5005
  finding" narrative to update + its shared 5-seed catalog to expand in Part B]
- [Source: `godot/tests/unit/generation/test_seed_batch_regression.gd::APPROVED_SEED_CATALOG` — shared catalog, both
  recipes, imported by the 10.2 suite]
- [Source: `godot/tests/unit/generation/test_small_level_layout_seed_regression.gd` /
  `test_medium_level_layout_seed_regression.gd` — the per-seed fingerprint SOURCE to expand via the dump tools]
- [Source: `godot/tests/integration/test_seed_regression_suite.gd` — tactical/`REWARD_SEED_SAMPLE`/`AFFINITY_SEED_SAMPLE`
  + the imported per-system catalogs; the honest-sample assertion block `_mvp_readiness_targets_are_stated_and_current_sample_is_honest`
  lines 634–666 to flip from "temporary >= 5" to the discharged targets]
- [Source: `godot/tests/integration/finale/test_finale_seed_regression.gd::APPROVED_BOSS_SEED_CATALOG` — boss →10,
  inline, no dump tool]
- [Source: `godot/tests/unit/generation/test_route_generation_seed_regression.gd::APPROVED_FINGERPRINTS` — route
  20/20 MET, UNCHANGED]
- [Source: `godot/tools/dump_performance_budgets.gd::LEVEL_LOAD_SEEDS` — the 10.1 shared catalog site]
- [Source: `godot/tools/dump_small_layout_fingerprints.gd` / `dump_medium_layout_fingerprints.gd` /
  `dump_seed_batch_report.gd` — the sanctioned regenerators]
- [Source: `_bmad-output/auto-gds/retro-notes/epic-10.md` — §10-1/§10-2/§10-3/§10-8 constraints folded above]
- [Source: `_bmad-output/implementation-artifacts/deferred-work.md` — the overlapping deferrals folded above]
- [Source: `CLAUDE.md` / `AGENTS.md` / `project-context.md` — architecture rules, test command, RNG/save invariants]

## Dev Agent Record

### Agent Model Used

Opus 4.8 (1M context) — model id `claude-opus-4-8[1m]` (auto-gds dev-story delegate).

### Debug Log References

- Baseline full suite (pre-change): 185 PASS, 0 `^FAIL`, ~45s, "Headless tests passed." (6 documented stderr negatives present, runner exit 0).
- Part A full suite (predicate + 3 test files + 2 comments): 185 PASS, 0 FAIL, ~36s.
- Part B generation-expansion full suite (50/50 catalog + fixtures): 185 PASS, 0 FAIL, ~59s.
- Part B tactical/reward/boss/affinity full suite: 185 PASS, 0 FAIL, ~67s.
- FINAL full suite: 185 PASS, 0 `^FAIL`, ~49s wall-clock, "Headless tests passed."
- Scratch verification (predicate flip, removed): far-corridor hazard now PASS (reachable_seen=1); adjacent hazard PASS; entrance-on-hazard FAIL; sealed hazard PASS (reachable_seen=0).
- Scratch probe (50 seeds, removed): all 50 seeds x both recipes validate on attempt 0 (attempts==1, validated) AND pass the strengthened Darkness fairness check — PROBLEMS = 0, no seed duplicates.
- Scratch affinity search (removed): a greedy `map`-stream search yielded exactly 10 seeds per implemented affinity (scorched/flooded_conductive/cursed/darkness) → the curated 40-seed `AFFINITY_SEED_SAMPLE`.
- False-PASS grep guard on FINAL raw output: `^FAIL` = 0; the diagnostic/stderr lines are BYTE-IDENTICAL to baseline (8 lines each, no diff) — no new stderr negatives introduced.
- `git diff --check`: exit 0 (clean; the LF→CRLF advisories are the repo's normal line-ending notes, not whitespace errors).

### Completion Notes List

**Part A — FR58 moving-LoS predicate (landed FIRST, verdicts final before Part B):**
- Strengthened `DarknessFairnessQuery` predicate (b) from static-from-ENTRANCE to MOVING reduced-radius LoS ("seen-before-contact") via a new pure `_seen_before_contact(board, hazard, terrain_reachable, radius_squared)` helper: a reachable hazard is fair iff it is LoS-visible at the reduced radius from at least one reachable 4-neighbour step-from cell. Form (b) — the helper WALKS the reachable 4-neighbours and ACTUALLY tests `has_line_of_sight` (not a hard-coded PASS), so the guard stays genuinely re-trippable for a FUTURE sight-blocking hazard / forced-teleport landing. The class header now carries the full v0-facts proof (HAZARD walkable+sight-transparent; reachable hazard always has a reachable 4-neighbour at squared distance 1 within the floor-1 reduced radius; adjacent-cell LoS unoccludable).
- PRESERVED: predicate (a) `entrance_on_hazard`/`entity_on_entrance`; `invalid_darkness_candidate`; `not_a_darkness_level`; the four `REASON_*` strings; the `darkness_fairness_violation` code; compact diagnostics; purity (no RNG/command/mutation). Re-pinned NOTHING (the query is not fingerprinted).
- Medium 4004/5005 flip from `darkness_unseen_hazard` FAIL to legitimate PASS. Deliberately updated the THREE stale FAIL sites: `test_darkness_fairness.gd` (converted the far-corridor FAIL to a moving-LoS PASS proof + added an explicit predicate-(a) "genuinely-unfair still FAILS" case + re-pointed `_failure_carries_seed_phase_and_reason` to an entrance-on-hazard config); `test_generator_fairness_batch.gd` (the `[4004,5005]` finding set → EMPTY, `darkness_failure_count == 0` + `final_readiness_fr58_darkness_met == true`, re-pointed the flag+preserve test to a hand-built predicate-(a) board, re-shaped the reflect FAIL half); and `test_live_affinity_flow.gd` (re-shaped `_unfair_darkness_board_snapshot()` to HAZARD-on-entrance so the live-gate STOP path stays exercised). Also updated the `dump_generator_fairness_report.gd` narrative.
- Corrected the false "all-FLOOR" premise comment on BOTH `_check_darkness_fairness_live` and `resolve_combat_node_live` in `run_orchestrator.gd` — COMMENT ONLY (the gate STRUCTURE is unchanged: error → stop). The comments now state all-FLOOR holds only for Small, Medium bakes HAZARD wrinkles (elite_combat→medium_combat_basic), this is a HARD live progression gate, and the moving-LoS predicate removes the latent false-positive hard-stop on live Darkness+Medium runs.
- Recorded the resolution in `generator-fairness-batch-readiness.md` §4 (option 2 "strengthen the predicate" chosen 2026-07-07), §3 verdict table (Medium FR58 now 0 failures), and §8 Change Log. History preserved.

**Part B — coordinated additive sample expansion (AFTER Part A, dump-tool-only, byte-identical originals):**
- Shared Small/Medium catalog EXPANDED 5→50 in ALL sites TOGETHER (never desynced): `dump_performance_budgets.gd::LEVEL_LOAD_SEEDS`, `dump_seed_batch_report.gd`, `dump_generator_fairness_report.gd`, `test_seed_batch_regression.gd::APPROVED_SEED_CATALOG` (imported by the 10.2 suite), `test_generator_fairness_batch.gd::BATCH_SEEDS`. New Small+Medium layout pins regenerated via `tools/dump_small_layout_fingerprints.gd` / `dump_medium_layout_fingerprints.gd` (seed lists expanded to 50) and captured directly from their output — never hand-typed. The ORIGINAL 5 pins in each fixture are byte-identical (verified: 1001-4004 have zero removed lines; only a trailing comma was added to 5005; the fingerprint value is unchanged).
- All 50 seeds x both recipes validate on attempt 0 (attempts==1) AND pass the strengthened Darkness fairness check — NO `needs-human` finding. 18 of the 50 Medium seeds carry HAZARD wrinkles, so the moving-LoS predicate is exercised over many real hazard configs (all PASS).
- Consolidated suite expanded: tactical 8→25 (`TACTICAL_SEED_SAMPLE`), reward 8→20 (`REWARD_SEED_SAMPLE`), affinity mixed-8 → 40-seed curated `AFFINITY_SEED_SAMPLE` with documented `AFFINITY_SEED_BY_AFFINITY` (10 seeds each on scorched/flooded_conductive/cursed/darkness) + a new `_affinity_sample_lands_ten_on_each_implemented_affinity` that PROVES the 10-per-affinity target live (Flooded-Conductive + Darkness asserted explicitly). Boss 5→10 in `test_finale_seed_regression.gd::APPROVED_BOSS_SEED_CATALOG` (inline, annotated — no dump tool). Route UNTOUCHED (20/20; git diff --stat empty).
- The honest-sample assertion block flipped from "temporary ≥ 5" tripwires to the DISCHARGED targets read LIVE from the catalogs (`small_count == 50`, `medium_count == 50`, `boss_count == 10`, `reward_count == 20`, `tactical_count >= 25`, `affinity_count >= 40` + per-affinity ≥ 10). Both ledgers' §3/§5 gap tables mark every headless-mechanical target MET (2026-07-07) with dump-tool/live provenance; G1-G7 physical-device gaps stay 10.6-owned.

**AC7 wall-clock guard:** FINAL suite observed ~49s (Part-B runs ranged 36-67s across iterations). **Proposed bound: 180s (3 minutes)** on the dev machine — generous headroom over the ~49-67s observed even with the 50+50 generation seeds, the 100-seed fairness batch, and the 40-seed affinity search, while still catching any future balloon.

**AC9 invariants (asserted by the green suite; re-verified):** the 7 named RNG streams (map/level/combat/loot/rewards/events/cosmetic), ZERO new RNG draw sites (the query is pure; Part B only drives seeds through systems that already draw their existing streams), the 23-key `RunSnapshot` gate, `ProfileSnapshot`/`SettingsSnapshot` `SCHEMA_VERSION == 1`, and every non-Part-A fingerprint SOURCE + its pinned values (route 20/20 untouched; Small/Medium original 5+5 byte-identical; boss original 5 unchanged) HOLD. The default deterministic paths are byte-identical (Part A = a pure query + comments; Part B = additive seeds + additive pins).

**No breaking change.** No public interface, config key, schema, CLI flag, or migration changed. `DarknessFairnessQuery.check_board`'s signature, return shape, reason codes, and top-level error code are all unchanged; the predicate STRENGTHENING only widens the PASS set for reachable non-entrance hazards (a strictly-fairer verdict) — the two callers (the live gate + the batch harness) reflect the verdict and needed no code change (only their now-observed PASS + comment/test updates).

### File List

Production (Part A):
- `godot/scripts/generation/level/darkness_fairness_query.gd` (predicate (b) strengthened to moving reduced-radius LoS + `_seen_before_contact` helper + header proof)
- `godot/scripts/run/run_orchestrator.gd` (COMMENT-ONLY fix on `_check_darkness_fairness_live` + the `resolve_combat_node_live` mirror comment)

Tests (Part A deliberate updates):
- `godot/tests/unit/generation/test_darkness_fairness.gd`
- `godot/tests/integration/test_generator_fairness_batch.gd`
- `godot/tests/unit/run/test_live_affinity_flow.gd`

Tests / fixtures (Part B expansion):
- `godot/tests/unit/generation/test_small_level_layout_seed_regression.gd` (5→50 pins)
- `godot/tests/unit/generation/test_medium_level_layout_seed_regression.gd` (5→50 pins)
- `godot/tests/unit/generation/test_seed_batch_regression.gd` (`APPROVED_SEED_CATALOG` 5→50 per recipe)
- `godot/tests/integration/test_seed_regression_suite.gd` (tactical 25, reward 20, affinity 40 + per-affinity proof, honest-sample flip)
- `godot/tests/integration/finale/test_finale_seed_regression.gd` (boss 5→10)

Tools (Part B — sanctioned dump drivers, tools/-gated, never shipped):
- `godot/tools/dump_small_layout_fingerprints.gd` (seed list 5→50)
- `godot/tools/dump_medium_layout_fingerprints.gd` (seed list 5→50)
- `godot/tools/dump_seed_batch_report.gd` (seed list 5→50)
- `godot/tools/dump_performance_budgets.gd` (`LEVEL_LOAD_SEEDS` 5→50)
- `godot/tools/dump_generator_fairness_report.gd` (seed list 5→50 + narrative update)

Planning / ledgers:
- `_bmad-output/planning-artifacts/generator-fairness-batch-readiness.md` (§3/§4/§5/§7/§8 — FR58 resolution + 50/50 MET)
- `_bmad-output/planning-artifacts/seed-regression-suite-readiness.md` (§3/§7/§8 — all headless-mechanical targets MET)
- `_bmad-output/implementation-artifacts/sprint-status.yaml` (10-8 status → review; last_updated)
- `_bmad-output/implementation-artifacts/10-8-darkness-fairness-moving-los-and-readiness-sample-expansion.md` (this story file)

### Change Log

| Date | Change |
|---|---|
| 2026-07-07 | Story 10.8 implemented (auto-gds dev-story). Part A: strengthened `DarknessFairnessQuery` predicate (b) to moving reduced-radius LoS (seen-before-contact) — Medium 4004/5005 flip to PASS, three stale FAIL sites deliberately updated, a new moving-LoS proof + a retained predicate-(a) FAIL case added, the false "all-FLOOR" premise comments corrected (comment-only), the FR58 resolution recorded in the fairness ledger; NO generator change, NO Part-A fingerprint re-pin, NO affinity-into-generation. Part B: coordinated additive sample expansion (generation Small/Medium 5→50 via the sanctioned dump tools with original pins byte-identical; tactical 8→25; reward 8→20; boss 5→10; affinity mixed-8 → 40 curated with 10-per-implemented-affinity proven live; route untouched at 20/20), both readiness ledgers' gap tables discharged (G1-G7 stay 10.6-owned), the honest-sample assertion flipped to the MET targets. Full suite 185 PASS / 0 FAIL / ~49s; false-PASS guard clean; determinism/save invariants hold. Status → review. |

### Review Findings

**Round 1 of 3**

> Disposition (2026-07-07, review loop): all three `[Review][Decision]` bullets below are Low informational awareness notes the reviewer classified as requiring no change now; ticked as accepted-as-recorded. Revisit triggers are stated inside each bullet (new unfair-damage classes; the 11.4 payload-entrance coupling; a lowered authored Darkness radius).

Adversarial code review (gds-code-review, 2026-07-07, auto-gds delegate). Reviewed the branch diff vs `main`
(15 code/tool/test files) against this story's ACs, with the production validator-semantics change
(`DarknessFairnessQuery` predicate (b)) as the highest-stakes focus. **Verdict: APPROVE.** Critical 0 / High 0 /
Medium 0 / Low 3. The full headless suite was re-run independently by the reviewer: **185 PASS / 0 `^FAIL` /
exit 0 / 49s wall-clock** ("Headless tests passed."), the false-PASS grep guard is clean (0 raw `^FAIL`), and the
documented stderr negatives are unchanged (no new signatures). All three v0-facts underpinning the moving-LoS proof
were verified against source (`board_cell.gd:33-34` WALL-only LoS block; `tactical_line_query.gd:63`
`range(1, max(1, line.size()-1))` empty for adjacent cells; `darkness_visibility_layer.gd:76-77` radius 2 floor 1).
The predicate genuinely walks the reachable 4-neighbours and calls `has_line_of_sight` (not a hard-coded PASS), so
it stays re-trippable; the new proof pair includes a REAL FAIL (`_genuinely_unfair_predicate_a_still_fails_loud`,
entrance-on-hazard). The four deliberate-update sites (7.6 unit, 10.3 batch, 11.4 live gate, 10.2 honest-sample)
are each correct and deliberate — the 11.4 re-shaped violation board still proves the live hard-gate STOP path
(verbatim reason + node context + no partial progression + no `map` RNG) because the entrance is passed explicitly
in the generation payload. Part B originals (Small/Medium 5+5, boss 5, route 20) are byte-identical (only a trailing
comma added after the `5005` pin); the 45+45 new pins came from the sanctioned dump drivers and match the shared
50-seed catalog order in all sites; the `AFFINITY_SEED_BY_AFFINITY` sample lands exactly 10-per-affinity on all four
implemented affinities (scorched/flooded_conductive/cursed/darkness), PROVEN live via `assign_affinity` (not
proxied). No new RNG draw sites, no schema/save-key changes, `run_orchestrator.gd` is provably comment-only.

The Low findings below are informational/no-code-change — all are cases where the crux is already correctly handled
and the note is a forward-looking observation for a FUTURE story. None block review or `done`.

- [x] **[Review][Decision]** (Low) `_seen_before_contact` collapses TWO distinct future-unfair classes under the
      single reason code `darkness_unseen_hazard`: (1) a future sight-BLOCKING hazard that occludes the adjacent LoS,
      and (2) a forced-teleport-only landing with NO reachable 4-neighbour step-from cell. Both make the helper return
      `false` → same `REASON_UNSEEN_HAZARD`. For v0 this is moot (neither class exists). But a future forced-movement
      story would surface a hazard that is perfectly VISIBLE yet still unfair (teleport-reachable), reported as
      "unseen" — a slightly misleading reason string. This is intentional per the code header (which explicitly lists
      both classes under this code). Human call: accept the single-code conflation, or, when such a class is added,
      split a distinct reason (e.g. `darkness_unavoidable_forced_landing`). No change needed now.
      [`godot/scripts/generation/level/darkness_fairness_query.gd:277-289`]
- [x] **[Review][Decision]** (Low) The 11.4 re-shaped `_unfair_darkness_board_snapshot()` no longer contains ANY
      `Terrain.ENTRANCE` cell — the entrance (1,6) is now HAZARD, and the test relies on `_check_darkness_fairness_live`
      resolving the entrance from the `entrance:{x:1,y:6}` field in the generation payload (which it does, correctly).
      This is a pre-existing coupling, not a regression, and it passes today. Flagged only so a future change to how
      the live gate derives the entrance (falling back to the ENTRANCE-terrain scan) would silently turn this FAIL
      into an `invalid_darkness_candidate` rather than the asserted `entrance_on_hazard`. Human awareness only.
      [`godot/tests/unit/run/test_live_affinity_flow.gd:174-262`, `godot/scripts/run/run_orchestrator.gd:1120-1124`]
- [x] **[Review][Decision]** (Low) The `reduced_radius_for` clamp (`max(DARKNESS_RADIUS_FLOOR=1, AUTHORED=2)` = 2)
      means the radius floor is currently never the binding constraint. The moving-LoS proof holds at the floor
      (a 4-neighbour is at squared distance 1 ≤ radius_squared 1), so if a future authored value dropped to the floor
      the predicate would still pass every reachable hazard. Verified correct; recorded so the "radius floor 1" leg of
      the proof is not silently invalidated if the authored radius is ever lowered.
      [`godot/scripts/tactical/fog/darkness_visibility_layer.gd:105-114`]
