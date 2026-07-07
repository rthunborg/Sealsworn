# Generator Soft-Lock and Fairness Batch — MVP Readiness Ledger

> **Story:** 10.3 (Generator Soft-Lock and Fairness Batch Checks) · **Epic:** 10 (Playtest Tuning and MVP Readiness)
> **Type:** Generator-safety / readiness batch-check artifact (the generator-fairness analog of 10.1's
> device-tiers/performance-budgets plan + 10.2's seed-regression-suite readiness — BATCH + REPORT the two
> EXISTING per-candidate validators over a seed sample under one threshold contract, state the MVP-readiness
> sample target, record the current-vs-target gap + any fairness finding for the readiness gate; touch no
> simulation).
> **Status:** authored 2026-07-07 · protects the canonical **FR36** (generation validates against
> unfair/soft-locked layouts) + **FR58** (Darkness "no unavoidable damage from unseen space") across a Small +
> Medium seed sample under **NFR13** (deterministic-under-seeded-execution); feeds the **10.6** MVP Readiness Gate.

## 1. Purpose and Scope

Epics 1–11 shipped strong PER-CANDIDATE fairness/soft-lock validation grown story-by-story: Story 3.6 built the
comprehensive `LevelValidator` (reachability / no-soft-lock / legal placement / reachable rewards / readability /
safe-first-reveal, wired into `LevelGenerator.generate`'s bounded deterministic retry); Story 7.6 added
`DarknessFairnessQuery` (the FR58 affinity-fairness guardrail at the Darkness-reduced radius). What the project
never had is a **single headless BATCH harness** that runs those existing checks over a SAMPLE of Small + Medium
seeds (and each level's affinity), reports a per-seed PASS/FAIL with compact `seed + phase + reason` (+ `affinity`)
diagnostics, applies the zero-tolerance + ≤ 1% bounded-retry-exhaustion readiness THRESHOLDS, flags out-of-threshold
recipes/rules/retry-limits for tuning, and preserves + tags every failing seed for reproduction. Story 10.3 builds
that harness + this ledger.

**In scope (what 10.3 delivers):**

1. The batch harness `godot/tests/integration/test_generator_fairness_batch.gd` — drives the shared Small + Medium
   seed catalog through the REAL `LevelGenerator.generate` + `LevelValidator` path (plus a direct
   `LevelValidator.validate` re-run over the reconstructed candidate) AND the `DarknessFairnessQuery.check_board`
   fairness half over each level's affinity, under one uniform `seed + phase + reason` (+ `affinity`) failure
   contract, with a forced-failure shape test + the AUTHENTIC Darkness FR58 finding path. It REUSES the two
   canonical validators — it does NOT fork a parallel soft-lock/fairness algorithm.
2. The optional report driver `godot/tools/dump_generator_fairness_report.gd` — the human-eyeball / reproduction
   companion that prints `[PASS|FAIL] recipe / seed: <validation verdict> | <affinity fairness verdict>` across the
   batch (tools/-gated, excluded from every export preset, print-only, no `user://` artifact, no progression).
3. This readiness ledger — the `50 Small / 50 Medium` MVP-readiness sample target stated verbatim + the
   current-vs-target (5-of-50) gap + the affinity-coverage note + **the honest Darkness FR58 fairness finding** +
   the 10.6 gate handoff.

**Out of scope (explicitly NOT this story):** any change to a generator / layout algorithm / `LevelValidator`
check-order or codes / `DarknessFairnessQuery` predicate or reasons / `GenerationResult` phase vocabulary /
`MAX_GENERATION_ATTEMPTS` / RNG stream / `RunSnapshot`/`ProfileSnapshot`/`SettingsSnapshot` schema / save key / any
generator/route/finale seed-regression fingerprint SOURCE or its pinned values / view model / content definition.
The full headless suite stays green + behaviorally byte-identical; this story adds a read-only batch harness + a
tools/ report driver + this planning doc. It implements NO affinity-driven GENERATION modifier (DEFERRED — the
affinity is assigned POST-generation onto an affinity-blind board), does NOT realize the Flooded electric chain
(that `_placeholder` is **10.7**'s item), and does NOT implement 10.6's gate decision.

## 2. The Two Validators Batched (AC1, AC2) — the single canonical sources REUSED

The harness CALLS each validator and ASSERTS its verdict over the batch. Where it needs the built candidate to feed
`LevelValidator`, it reconstructs it from the `LevelGenerator.generate` payload the SAME way
`test_seed_batch_regression.gd::_terrain_fingerprint_from_payload` does (row-major terrain from the board snapshot
cells) plus `BoardState.try_from_snapshot(payload.board)` for the entity-aware board + `payload.rewards` for the
reward markers — no second candidate shape, no second flood/LoS. This is the strongest form of the 3.7/4.2 / 10.2
"no second pinning path" discipline (a second reachability/fairness algorithm that can silently diverge from the
shipped validator is the #1 review risk on this story).

| Concern | Canonical validator (REUSED) | Batch assertion |
|---|---|---|
| Reachability / soft-lock / legal placement / reachable rewards / readability / safe first reveal | `godot/scripts/generation/level/level_validator.gd` — `validate(candidate)`; `check_order()` fixed; `phase_for_code(code)` → `pathing`/`enemies`/`validation` | Per seed: `generate` succeeded + `validated == true` + `attempts == 1`; direct `validate(candidate)` returns `ActionResult.ok` (every soft-lock/placement/reward/first-reveal code individually clear). |
| Affinity / Darkness fairness (FR58) | `godot/scripts/generation/level/darkness_fairness_query.gd` — `check_board(board, affinity_id, repository, seed, entrance)`; reduced radius `DarknessVisibilityLayer.DARKNESS_REDUCED_LINE_OF_SIGHT_RADIUS == 2`, floor 1; stable reasons `entrance_on_hazard`/`entity_on_entrance`/`darkness_unseen_hazard`/`invalid_darkness_candidate` | Per level, over the DARKNESS affinity + every baseline affinity (`AffinityRepository.BASELINE_AFFINITY_IDS`): a verdict is recorded; neutral/non-Darkness → `not_a_darkness_level`; a fair Darkness board PASSES; a reachable hazard unseen at the reduced radius FAILS `darkness_unseen_hazard` (tagged by affinity + seed + phase). |

Both validators are PURE (draw no RNG, mutate nothing); the harness draws no gameplay RNG beyond what
`LevelGenerator.generate` + `RunOrchestrator.assign_affinity` already draw per seed. It re-pins NO terrain
fingerprint (the fairness half only READS validator verdicts).

## 3. The Readiness Threshold Model (AC3, AC4)

- **Zero-tolerance classes (AC4), stated verbatim:** 0 soft-locks (`soft_lock_detected`), 0 mandatory class/item
  gates (`required_gate_present`), 0 unreachable mandatory exits (`unreachable_exit`), 0 unreachable intended
  mandatory rewards (`unreachable_reward`), 0 unavoidable untelegraphed first-reveal punishments
  (`unsafe_first_reveal` at the baseline radius **+ the `darkness_unseen_hazard` FR58 half at the Darkness-reduced
  radius**), plus 0 illegal placement (`illegal_enemy_placement`, a solvability precondition). The harness STATES
  these as `ZERO_TOLERANCE_CODES` and asserts ZERO across the sample from ACTUAL live runs.
- **Bounded-retry exhaustion ≤ 1% per recipe batch (AC4):** `LevelGenerator.generate` retries up to
  `MAX_GENERATION_ATTEMPTS == 8` deterministically-perturbed candidates; a seed that exhausts all 8 returns a
  structured error with `attempts == 8`. The harness counts exhaustions / batch size per recipe (`MAX_RETRY_EXHAUSTION_RATE == 0.01`).
- **Failure-rate → tuning flag (AC3):** when the rate exceeds threshold, the harness names the recipe
  (`small_combat_basic` / `medium_combat_basic`), the failing validation rule (the `LevelValidator` code /
  `DarknessFairnessQuery` reduced-radius predicate), or the retry limit (`MAX_GENERATION_ATTEMPTS`) — actionable,
  compact.
- **Failing-seed preservation (AC3/AC4):** every failing seed is preserved as DATA (kept + annotated with the
  failing phase/reason/recipe [+ affinity + hazard cell for the fairness half] so it is reproducible; never silently
  discarded). Proven by BOTH the forced always-fail seam (retry-exhaustion path) AND the authentic Darkness FR58
  finding path.

### Current-catalog verdict (from ACTUAL live runs)

| Class | Small (`small_combat_basic`) | Medium (`medium_combat_basic`) | Meets zero-tolerance? |
|---|---|---|---|
| Soft-lock / gate / unreachable-exit / unreachable-reward / illegal-placement / base unsafe-first-reveal | 0 failures (all pass `LevelValidator` on unperturbed attempt 0, `attempts == 1`) | 0 failures (same) | **YES** — met by construction |
| Bounded-retry exhaustion | 0% | 0% | **YES** |
| **FR58 `darkness_unseen_hazard` (Darkness affinity)** | **0 failures** (Small boards are all-FLOOR) | **2 failures — seeds 4004 + 5005** | **NO (Medium)** — see §4 |

## 4. ⭐ Honest Darkness FR58 Finding (the real 10.6-gate readiness signal)

**The Dev-Notes premise "v0 generated boards are all-FLOOR" holds for the Small recipe but is FALSE for Medium.**
The Medium generator's tactical-wrinkle phase (`hazard` wrinkle kind, realized as `Terrain.HAZARD` — the 3.4
contract; it is part of the pinned Medium terrain fingerprint, not a runtime affinity stamp) bakes HAZARD cells into
some seeds. The batch surfaced this live:

| Recipe / seed | Generated HAZARD cell(s) | Base `LevelValidator` (radius 4) | Darkness `DarknessFairnessQuery` (reduced radius 2) |
|---|---|---|---|
| `medium_combat_basic` / 4004 | (9, 4) | PASS (fair at baseline radius — hazard not on entrance, seen at radius 4) | **FAIL `darkness_unseen_hazard`** — the hazard is reachable but unseen from the entrance at radius 2 |
| `medium_combat_basic` / 5005 | (10, 2), (12, 2) | PASS | **FAIL `darkness_unseen_hazard`** |
| `small_combat_basic` / all 5 | none (all-FLOOR) | PASS | PASS |
| `medium_combat_basic` / 1001, 2002, 3003 | none | PASS | PASS |

**What this means (and does NOT mean):**

- It is a **real fairness gap under the Darkness affinity**, exactly the FR58 risk 7.6 anticipated: "if Darkness
  REDUCES the radius, a damage source that WAS seen at radius 4 may be UNSEEN at the reduced radius — re-opening
  exactly the 'unavoidable damage from unseen space' FR58 forbids." The batch harness surfacing it IS the harness
  doing its job. This is the generator-fairness analog of a readiness signal, NOT a harness bug and NOT a base
  soft-lock (the levels are perfectly fair at the baseline radius).
- The `DarknessFairnessQuery` v0 predicate is a STATIC check from the ENTRANCE only (it does not simulate the hero's
  moving reduced-radius LoS as they advance). It fails LOUD on the conservative side: "at spawn, is every reachable
  hazard visible at the reduced radius?" For Medium 4004/5005 under Darkness, no. Whether such a hazard is "truly
  unavoidable" under live moving-LoS play is precisely the nuance the v0 predicate deliberately does not model — so
  the conservative FAIL is correct behavior for a fairness guardrail.
- **The batch does NOT fabricate a passing verdict.** The story explicitly forbids that ("Do NOT fabricate coverage
  you did not run; do NOT silently pass a sub-target sample as if it met the readiness bar"). The base generation
  zero-tolerance classes ARE met; the FR58 Darkness half is NOT met for the current Medium catalog, and the harness
  records it honestly.

**Owning action (the 10.6 gate decides; NOT 10.3's call).** Options for the 10.6 MVP Readiness Gate:

1. **Tune the generator** so a Medium `hazard` wrinkle can never land reachable-but-unseen at the Darkness-reduced
   radius (e.g. constrain hazard placement to within the reduced-radius-visible region, or gate the `hazard`
   wrinkle out of the Medium recipe when a level could be Darkness). This is an affinity-aware GENERATION change —
   it would re-pin the affected Medium terrain fingerprints in ITS OWN PR (the deferred generation-modifier /
   affinity-into-generation story owns that; 10.3 must not perturb fingerprints).
2. **Strengthen the fairness predicate** to model moving reduced-radius LoS (walk the reachable region, confirm each
   hazard is seen from SOME reachable cell before it can be stepped on) — a 7.6-predicate enhancement, if live
   moving-LoS is deemed the fair contract.
3. **Accept as a documented readiness LIMITATION** — the affinity is assigned POST-generation and Darkness is 1 of 5
   affinities, so any given Medium level is Darkness only a fraction of runs; 10.6 may judge the honestly-surfaced,
   telegraphed-on-approach hazard an acceptable v0 limitation (with the finding recorded here).

10.3's deliverable is the harness that SURFACES + PRESERVES + FLAGS this; the fix/de-scope is 10.6's decision. The
harness asserts the finding is present (fails LOUD if a future generator change silently makes Medium all-FLOOR, so
this ledger is re-verified rather than the gap silently closing).

## 5. MVP-Readiness Seed-Sample Target (AC4) and the Current-vs-Target Gap

The FINAL target is stated verbatim from the coordination with 10.2's AC2 (the two harnesses share the generation
seed catalog). **A smaller pre-MVP sample is TEMPORARY and cannot pass final MVP readiness without an approved
de-scope — that decision belongs to the 10.6 gate, not to 10.3.** The "current" column is the sample the batch
harness ACTUALLY drives (read live from `BATCH_SEEDS` × `BATCH_RECIPES` — never a fabricated count).

| Dimension | Target | Current sample | Status | Owning action |
|---|---|---|---|---|
| Small level seeds | 50 | 5 (seeds 1001/2002/3003/4004/5005) | **temporary (5 of 50)** | a COORDINATED generation-sample expansion across the three Epic-10 harnesses (10.1 level-load, 10.2 regression, 10.3 fairness) via `tools/dump_seed_batch_report.gd`, OR an approved 10.6 de-scope |
| Medium level seeds | 50 | 5 (seeds 1001/2002/3003/4004/5005) | **temporary (5 of 50)** | same as Small — expand together (do NOT expand the shared catalog in isolation) OR 10.6 de-scope |
| Affinity fairness coverage | each implemented affinity checked | all 4 implemented (`scorched`, `flooded_conductive`, `cursed`, `darkness`) + neutral `none` checked over a batch level; Darkness (the only reduced-radius affinity) checked over EVERY batch level | **MET (coverage)** — every implemented affinity's fairness verdict is asserted | none for coverage; the Darkness-half FR58 FINDING (§4) is the 10.6 item |

**Why the sub-target sample is an availability gap, not a blocker (the 10.1/10.2 honest-scope posture):** AC1/AC4
are dischargeable WITHOUT reaching 50/50 in one pass — the batch runs the FULL current approved catalog (all 5+5
pass the GENERATION zero-tolerance classes by construction), STATES the 50/50 target, and records the sub-target
sample as an explicit temporary gap gated at 10.6. Every verdict came from an ACTUAL live run through the real
validators over the real generate payload — none is hand-typed to hit a count.

**Do NOT expand the shared generation seed catalog in isolation.** The 10.1 level-load harness + the 10.2
regression suite BOTH pin `[1001,2002,3003,4004,5005]` for both recipes; the 10.2 ledger §3 records that a
generation-sample expansion toward 50/50 must be a COORDINATED pass across all three Epic-10 harnesses. 10.3
RESPECTS that: it draws the SAME 5+5 for the terrain-affecting batch (re-pinning NO terrain fingerprint — the
fairness harness only reads validator verdicts), and records the coordinated-expansion intent here.

## 6. Determinism / Generation Invariants Respected

This readiness/batch-check story moves NONE of the pinned invariants — it PROVES they hold: the 7 named RNG streams
(`map` / `level` / `combat` / `loot` / `rewards` / `events` / `cosmetic`), zero new RNG draw sites, the
`LevelValidator` `check_order()` + 8 stable codes + `phase_for_code`, the `DarknessFairnessQuery` 4 reasons +
reduced-radius predicate, the `GenerationResult` 11 `PHASE_*`, `MAX_GENERATION_ATTEMPTS == 8` + the
attempt-0-unperturbed invariant, the 23-key `RunSnapshot` gate, every generator/route/finale fingerprint SOURCE +
its pinned values, and the default deterministic generation paths stay byte-identical. The harness + the report
driver are read-only over the generation domain, draw no gameplay RNG beyond what the exercised systems already
draw, and mutate no domain/save state. The full headless suite stays green (184 baseline at 10.2 close → 185 with
this story's one new passing batch test).

## 7. Epic-10 Gate Handoff and Cross-References

- **10.6 (MVP Readiness Gate and Playable-Build Preservation).** Consumes the batch harness + its threshold verdict
  + this sample-gap ledger + **the Darkness FR58 finding (§4)**. 10.6 decides: (a) per still-temporary sub-target
  sample, "acceptable documented readiness LIMITATION" vs "must discharge via a coordinated generation-sample
  expansion before MVP-readiness passes"; and (b) how to resolve the Darkness `darkness_unseen_hazard` finding on
  Medium 4004/5005 (tune the generator / strengthen the predicate / accept as a documented limitation — §4). A
  sub-target sample AND a non-zero FR58 finding both mean final MVP readiness cannot pass on those axes without an
  approved 10.6 decision — that is the gate's call, not 10.3's.
- **10.2 (Headless Seed Regression Suite).** Shares the `[1001,2002,3003,4004,5005]` Small/Medium seed catalog; the
  10.2 ledger `seed-regression-suite-readiness.md` §3/§7 records the coordinated-expansion intent. 10.3 keeps its
  generation seed catalog COMPATIBLE (draws the same 5+5) so the two harnesses agree on seeds.
- **10.1 (Device Tiers and Performance Budgets).** Its `device-tiers-and-performance-budgets.md` §7 records the
  shared level-load seed sample + the 10.3 fairness-batch coordination; this doc is the reciprocal
  generator-fairness readiness artifact.
- **10.7 (Asset/Audio-placeholder and UX Readiness Gate).** Owns the Flooded / Conductive `_placeholder` electric-
  interaction resolution. 10.3's batch REFLECTS the Flooded fairness verdict (`not_a_darkness_level` — Flooded is
  not a reduced-radius affinity, so it has no FR58 unseen-hazard risk to re-assert), but does NOT realize the live
  water/electric chain and does NOT resolve the placeholder — that is 10.7's call.
- **The affinity-driven GENERATION modifier stays DEFERRED** to a separate later generation-modifier story (NOT
  10.3's). 10.3 runs the fairness batch over levels whose affinity is assigned POST-generation onto an
  affinity-blind generated board (the shipped v0 posture); it does NOT wire affinity into
  `RewardOfferBuilder`/reward tables/`EntityRewardPlacer`/the generator (doing so would perturb the seed-regression
  fingerprints this batch protects). If a later story bakes affinity into generation, IT re-pins the affected
  fingerprints in ITS PR.

## 8. Change Log

| Date | Version | Change | Author |
|---|---|---|---|
| 2026-07-07 | 1.0 | Initial authoring — batch harness over the shared Small+Medium seed catalog COMPOSING the two existing validators (`LevelValidator` 3.6, `DarknessFairnessQuery` 7.6) under one `seed + phase + reason` (+ `affinity`) contract (reuse-not-fork, no second flood/LoS); the AC4 zero-tolerance + ≤ 1% retry-exhaustion thresholds stated + applied (base generation classes MET by construction); the forced-failure + authentic-finding flag-and-preserve paths; the `50/50` sample target + 5-of-50 gap (shared-catalog coordination, no isolated expansion); **the honest Darkness FR58 `darkness_unseen_hazard` finding on Medium seeds 4004+5005 (the real 10.6-gate readiness signal — the generated Medium `hazard` wrinkles are unseen at the Darkness-reduced radius; the Dev-Notes "all-FLOOR" premise holds for Small only)**; the tools/-gated report driver. Protects FR36 + FR58 under NFR13; feeds 10.6. | Story 10.3 (dev agent) |
