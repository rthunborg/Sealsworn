# Story 10.3: Generator Soft-Lock and Fairness Batch Checks

Status: ready-for-dev

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a player,
I want generated levels to avoid soft-locks and unfair first reveals,
so that procedural variety remains trustworthy.

## Story Type & Scope Boundary (READ FIRST)

**This is a GENERATOR-SAFETY / READINESS BATCH-CHECK story — the generator-fairness analog of Story 10.2
(the seed-determinism consolidated suite) and Story 10.1 (device tiers + performance budgets), NOT a
gameplay-feature story.** The project ALREADY has strong PER-CANDIDATE fairness/soft-lock validation
(the comprehensive `LevelValidator` from Story 3.6 — reachability, legal placement, no soft-lock, no
required gate, reachable rewards, readability, safe first reveal — wired into `LevelGenerator.generate`'s
bounded-retry success path, PLUS the `DarknessFairnessQuery` from Story 7.6 — the FR58 no-unavoidable-
unseen-damage affinity fairness guardrail). What the project has NEVER had is a **single headless BATCH
harness that runs those existing checks over a SAMPLE of Small + Medium seeds (and each seed's affinity
where applicable), reports a per-seed PASS/FAIL with compact `seed + phase + reason` (+ `affinity` for the
fairness half) diagnostics, applies the zero-tolerance / bounded-retry-exhaustion-≤-1%-per-recipe-batch
readiness THRESHOLDS, flags out-of-threshold recipes/rules/retry-limits for tuning, and PRESERVES + TAGS
every failing seed for reproduction.** Story 10.3 is the paper-plus-harness that builds it: a batch driver
that COMPOSES the existing validators (it does NOT re-derive a second soft-lock/fairness algorithm),
records the current-vs-target seed-sample gap as a 10.6-owned honest-scope ledger, and hands the
readiness verdict to the 10.6 gate.

- **This is not a domain/tactical/save/RNG/content/generator story.** Do NOT change any generator, layout
  algorithm, `LevelValidator` check or its check-order/codes, `DarknessFairnessQuery`, RNG stream,
  `GenerationResult` phase vocabulary, generator/route/finale seed-regression fingerprint, view model, or
  content definition. The full headless suite (**184 PASS / 0 `^FAIL`** at 10.2 close — the 183 baseline
  10.1 left plus 10.2's one new `test_seed_regression_suite.gd`) must stay green and byte-for-byte
  behaviorally unchanged. This story ADDS a batch-fairness harness + (if it genuinely earns its place) a
  `tools/` report driver + a durable readiness ledger; it does NOT perturb the simulation. Any new test
  ASSERTS the verdicts of the EXISTING validators over a seed batch (the validators are already
  deterministic + pure), never introduces new gameplay or a new fairness rule.
- **REUSE the existing validators — do NOT fork a parallel soft-lock/fairness algorithm.** The Epic-11
  retro's explicit Epic-10 direction (retro §7 point 5 / T-series) is to EXTEND the existing harnesses, not
  author parallel ones. `LevelValidator.validate(candidate)` is the SINGLE canonical soft-lock/reachability/
  placement/reward/readability/safe-first-reveal check; `DarknessFairnessQuery.check_board(...)` is the
  SINGLE canonical affinity-fairness check. The batch harness CALLS those. A second reachability flood /
  fairness predicate that can silently diverge from the shipped validator is the single most likely review
  miss on this story (the same "no second pinning path" discipline 10.2 enforced with its
  `_consolidated_pins_agree_with_live_canonical_sources` cross-check, and 3.7/4.2 enforce with their
  fingerprint cross-checks). If the harness needs the built candidate (layout + `BoardState` + rewards) to
  feed `LevelValidator`, it reconstructs it from the `LevelGenerator.generate` payload the SAME way
  `test_seed_batch_regression.gd::_terrain_fingerprint_from_payload` does — it does not hand-build a
  parallel candidate shape.
- **The full MVP-readiness seed-sample size is a HONEST-SCOPE decision, not an auto-expand mandate.** The
  AC1/AC4 batch is written against "a batch of Small and Medium level seeds"; the concrete MVP-readiness
  sample target is the SAME `50 Small / 50 Medium` AC2 target Story 10.2 states (the two harnesses share the
  generation seed catalog — see the coordination note below). The current on-disk approved catalog is FAR
  below that (`[1001,2002,3003,4004,5005]` = 5 Small + 5 Medium, the shared Epic-10 catalog). The correct
  autonomous outcome mirrors 10.1/10.2's "measure what you can, record honest gaps": drive the FULL current
  approved catalog through the batch (all 5+5 PASS by construction — the approved seeds validate on the
  unperturbed attempt 0), state the `50/50` target, and record the sub-target sample as an explicit
  `temporary (5 of 50) → owning action (a coordinated generation-sample expansion, or an approved de-scope at
  the 10.6 gate)` gap. **Do NOT fabricate coverage you did not run; do NOT silently pass a sub-target sample
  as if it met the readiness bar; do NOT stop and ask a human** — the story is completable + valuable via the
  batch harness + the honest gap ledger. **Do NOT expand the generation seed catalog in ISOLATION** — the
  10.1 level-load harness AND the 10.2 regression suite BOTH draw over the shared `[1001,2002,3003,4004,5005]`
  catalog; expanding it here alone would DESYNC the three Epic-10 harnesses. If you drive additional seeds for
  the FAIRNESS batch, do it as an ADDITIVE batch-only sample that does not touch the pinned shared-catalog
  fingerprints (adding fairness seeds re-pins NO terrain fingerprint — the fairness harness only READS
  validator verdicts, it pins no terrain), and record the coordinated-expansion intent in the ledger.
- **The generator is already SAFE — this harness PROVES + REPORTS it; it must leave every generation
  invariant byte-identical.** `LevelValidator` is wired into `LevelGenerator.generate`'s bounded retry
  (`MAX_GENERATION_ATTEMPTS == 8`); the approved seeds pass on attempt 0 (`attempts == 1`), so the
  zero-tolerance thresholds are MET by construction for the current catalog. A batch harness that MOVED any
  generator behavior, changed a validator check, or re-pinned a terrain fingerprint would be self-defeating.
  The harness is read-only over the generation domain and draws no gameplay RNG beyond what
  `LevelGenerator.generate` already draws for each seed.

## Acceptance Criteria

Sourced verbatim from `epics.md` (Epic 10, Story 10.3). Four AC groups (Given/When/Then + And):

1. **Batch generator validation over Small + Medium seeds (AC1).** GIVEN a batch of Small and Medium level
   seeds is selected, WHEN generator validation runs headlessly, THEN **every generated level has
   entrance-to-exit reachability, legal enemy placement, reachable intended rewards, and safe first reveal**,
   AND **failures include compact diagnostics**.

2. **Affinity / Darkness fairness validation over the batch (AC2).** GIVEN Darkness or other affinity
   pressure is active, WHEN fairness validation runs, THEN it **checks that unseen-space damage is avoidable
   and critical danger is inspectable or telegraphed**, AND **failures are tagged by affinity**.

3. **Failure-rate threshold → tuning flag + failing-seed preservation (AC3).** GIVEN generator failure rates
   exceed accepted thresholds, WHEN the report is reviewed, THEN **the relevant recipes, validation rules, or
   retry limits are flagged for tuning**, AND **failing seeds are preserved for reproduction**.

4. **Final zero-tolerance + bounded-retry-exhaustion readiness thresholds (AC4).** GIVEN final generator and
   fairness batches are evaluated, WHEN pass/fail thresholds are applied, THEN **zero soft-locks, zero
   mandatory class/item gates, zero unreachable mandatory exits, zero unreachable intended mandatory rewards,
   and zero unavoidable untelegraphed first-reveal punishments are acceptable**, AND **bounded retry
   exhaustion must stay at or below 1 percent per recipe batch, with every failing seed preserved and tagged
   before readiness can pass**.

### AC Verification (how "done" is checked)

- **AC1** — a headless batch harness drives a SAMPLE of Small + Medium seeds through the REAL generation +
  validation path (`LevelGenerator.generate` with the default `LevelValidator`, OR a reconstruction of the
  built candidate fed to `LevelValidator.validate` — SAME validator either way) and asserts, per seed, that
  the level is fully valid: exit reachable (`unreachable_exit`/`soft_lock_detected` clear), legal placement
  (`illegal_enemy_placement` clear), mandatory rewards reachable (`unreachable_reward` clear), safe first
  reveal (`unsafe_first_reveal` clear). A FAILURE assert carries `seed + phase + reason` (from the
  `GenerationResult` / `LevelValidator` compact diagnostics — counts/coords, NEVER a grid dump). A seed that
  reaches the validator with no PASS/FAIL verdict, or a failure that omits any of the three fields, = AC1 not
  met. NOTE the per-candidate checks already exist in `LevelValidator` — AC1 is met by BATCHING them under
  one reporting contract, not by rebuilding them.
- **AC2** — the harness runs `DarknessFairnessQuery.check_board(...)` over each batch level's ASSIGNED
  affinity (assigned via `RunOrchestrator.assign_affinity` on the `map` stream, the 7.4 contract, OR driven
  directly for a Darkness board) and asserts the FR58 fairness predicate: reachable HAZARD cells unseen at the
  Darkness-reduced radius FAIL `darkness_unseen_hazard`; entrance-on-hazard / entity-on-entrance FAIL; a fair
  board PASSES (`not_a_darkness_level` for neutral/non-Darkness is a legal PASS). A FAILURE carries the
  `affinity` tag (the `affinity_id` + the `fairness_reason` + `seed` + `phase` the query already emits — AC2
  "failures are tagged by affinity"). "critical danger is inspectable or telegraphed" is satisfied by the
  existing surfaces the harness REFLECTS (a reachable hazard MUST be LoS-visible at the reduced radius to
  pass — i.e. seen/inspectable; the accessibility cues `affinity_darkness_reduced_visibility` /
  `affinity_darkness_memory_uncertain` + the Scorched/Flooded cues are the telegraph channel, already
  audited color-independent by `test_tactical_accessibility_cues.gd`) — the harness does not author a new
  telegraph. A batch level whose affinity fairness is unchecked, or a failure that omits the affinity tag, =
  AC2 not met.
- **AC3** — the harness computes a per-recipe-batch FAILURE RATE (validation failures + bounded-retry
  EXHAUSTIONS over the batch) and, when it exceeds the accepted threshold (AC4's zero-tolerance for the fair-
  ness/soft-lock classes; ≤ 1% retry-exhaustion per recipe batch), FLAGS the relevant recipe / validation
  rule / retry limit (`MAX_GENERATION_ATTEMPTS`) for tuning in the report, AND PRESERVES the failing seed(s)
  as DATA (a preserved-seed list, the 3.7 AC4 preserved-catalog discipline — kept + annotated, never silently
  discarded). A harness that detects a threshold breach but names no recipe/rule/retry-limit to tune, or does
  not preserve the failing seed, = AC3 not met. NOTE: for the CURRENT approved catalog the failure rate is 0%
  (every approved seed passes on attempt 0), so AC3 is exercised by a FORCED-failure shape test (an injected
  always-fail / fail-then-pass validator via `LevelGenerator.generate`'s optional 4th `validator` param, the
  3.6 test seam) that proves the threshold→flag→preserve reporting path fires — the harness can never
  silently pass a regression.
- **AC4** — the harness STATES + ASSERTS the zero-tolerance thresholds verbatim (0 soft-locks, 0 mandatory
  class/item gates, 0 unreachable mandatory exits, 0 unreachable intended mandatory rewards, 0 unavoidable
  untelegraphed first-reveal punishments) and the ≤ 1% bounded-retry-exhaustion-per-recipe-batch threshold,
  applies them to the batch, and records (in the durable readiness ledger) that a sub-target seed SAMPLE
  cannot pass FINAL MVP readiness without an approved de-scope (the 10.6 gate owns that decision). Every
  failing seed is preserved + tagged before readiness can pass. A missing threshold statement, a batch that
  passes a threshold breach, or an unpreserved failing seed = AC4 not met. (The current catalog MEETS every
  zero-tolerance threshold by construction; the sample-SIZE gap is the recorded 10.6-owned item, not a
  threshold failure.)

## Tasks / Subtasks

- [ ] **Task 1 — Inventory the existing validators + confirm their single canonical sources (AC1, AC2)**
  - [ ] Read the two existing validation surfaces and confirm each is the SINGLE canonical check before
        writing any batch harness (a second algorithm is a review miss):
        - **Soft-lock / reachability / placement / reward / readability / safe-first-reveal:**
          `godot/scripts/generation/level/level_validator.gd` — `validate(candidate)` returns
          `ActionResult.ok([], {<compact pass report>})` or `ActionResult.error(<stable check code>,
          {<compact diagnostics>})` on the FIRST failing check (fixed `check_order()`:
          `unreachable_exit → illegal_enemy_placement → soft_lock_detected → required_gate_present →
          unreachable_reward → excessive_blockage → unreadable_first_reveal → unsafe_first_reveal`). It is
          PURE (draws no RNG, mutates nothing) and is ALREADY wired into `LevelGenerator.generate`'s
          bounded-retry success path. `phase_for_code(code)` maps each code onto a `GenerationResult` phase
          (`pathing` / `enemies` / `validation`).
        - **Affinity / Darkness fairness (FR58):** `godot/scripts/generation/level/darkness_fairness_query.gd`
          — `check_board(board, affinity_id, repository, seed, entrance)` returns a legal `not_a_darkness_level`
          PASS for neutral/non-Darkness, a compact PASS for a fair Darkness board, or
          `ActionResult.error(&"darkness_fairness_violation", {fairness_reason, seed, phase, ...})` on the
          FIRST violation. Stable reasons: `entrance_on_hazard`, `entity_on_entrance`, `darkness_unseen_hazard`,
          `invalid_darkness_candidate`. It re-asserts safe-first-reveal at the Darkness-REDUCED radius
          (`DarknessVisibilityLayer.DARKNESS_REDUCED_LINE_OF_SIGHT_RADIUS == 2`, floor 1) and fails a reachable
          hazard unseen at that radius. PURE.
  - [ ] Read `godot/tests/unit/generation/test_seed_batch_regression.gd` (the 3.7 FULL-`generate` batch — the
        CLOSEST sibling harness) for the batch-drive pattern (`LevelGenerator.generate` over
        `APPROVED_SEED_CATALOG`, `_terrain_fingerprint_from_payload` candidate reconstruction, the
        `_failure_report_shape_carries_seed_recipe_phase_reason` forced-failure shape). Read
        `godot/tests/unit/run/test_affinity_assignment.gd` for the `assign_affinity` → `map`-stream affinity
        pattern. REUSE these shapes — do NOT invent a new batch-drive or candidate-reconstruction pattern.
  - [ ] Record the CURRENT approved seed catalog on disk (Small 5 / Medium 5 =
        `[1001,2002,3003,4004,5005]` — the SHARED Epic-10 catalog the 10.1 level-load harness + the 10.2
        regression suite both draw over) — this is the baseline for the AC4 sample gap ledger.

- [ ] **Task 2 — Build the batch generator-validation harness + uniform failure report (AC1)**
  - [ ] Author a headless batch harness (a new `test_*.gd` under `godot/tests/integration/` — an
        integration-level cross-system generator-safety batch is the right home; the seed-regression suite +
        finale suite already live under `godot/tests/integration/`) that drives the full approved Small +
        Medium seed catalog through `LevelGenerator.generate(request, recipes, enemies)` (default
        `LevelValidator`) and asserts, per seed: `generation.succeeded == true`, `diagnostics.validated ==
        true`, and (the zero-tolerance evidence) the built level is fully valid. Reconstruct the built
        candidate (layout + `BoardState` + rewards) from the payload and additionally run
        `LevelValidator.validate(candidate)` DIRECTLY over it to assert `ActionResult.ok` (proving the exact
        soft-lock/placement/reward/first-reveal codes are all clear, not just that `generate` succeeded) — the
        SAME validator the pipeline uses (no second algorithm). EVERY failure assert carries
        `seed=%d phase=%s reason=%s` (from `GenerationResult.failed_phase`/`reason` on a generate failure, or
        the `LevelValidator` error code + `phase_for_code` on a direct-validate failure) — compact, NEVER a
        grid/board dump.
  - [ ] Include a FORCED-failure shape test (the `_failure_report_shape_carries_...` precedent) so the harness
        can never silently pass a soft-lock/fairness regression: inject an always-fail validator via
        `LevelGenerator.generate`'s optional 4th `validator` param (the 3.6 test seam) and assert the
        `GenerationResult.error` carries `seed + failed_phase + error_code + reason` + `attempts ==
        MAX_GENERATION_ATTEMPTS` (bounded-retry exhaustion), and that the failing seed is captured for
        preservation.

- [ ] **Task 3 — Add the affinity / Darkness fairness half over the batch (AC2)**
  - [ ] For each batch level, ASSIGN the affinity via `RunOrchestrator.assign_affinity(node)` (the `map`-stream
        7.4 contract) OR drive a Darkness board directly, and run
        `DarknessFairnessQuery.check_board(board, affinity_id, repository, seed, entrance)` over the built
        board. Assert: neutral/non-Darkness returns the legal `not_a_darkness_level` PASS; a fair Darkness
        board PASSES; and (the FR58 heart) a hand-built Darkness candidate carrying a REACHABLE hazard UNSEEN
        at the reduced radius FAILS `darkness_unseen_hazard`, while a hazard SEEN at the reduced radius passes
        ("critical danger is inspectable/telegraphed"). EVERY fairness failure assert carries the AFFINITY TAG
        (`affinity_id` + `fairness_reason` + `seed` + `phase` — AC2 "failures are tagged by affinity"),
        compact, no grid dump.
  - [ ] Cover ALL FOUR implemented affinities in the fairness half where they are relevant (the baseline ids:
        `scorched`, `flooded_conductive`, `cursed`, `darkness`, plus neutral `none` — `AffinityRepository.
        BASELINE_AFFINITY_IDS`). Darkness is the affinity with the reduced-radius fairness risk (the query's
        active branch); Scorched/Flooded/Cursed/neutral return the `not_a_darkness_level` PASS (no reduced
        radius to re-assert) — assert that too so the batch demonstrably ran the fairness check for every
        affinity, not just Darkness. A batch affinity that surfaces in the sample must have its fairness verdict
        asserted (the 10.2 affinity-sample honesty posture — if an affinity never surfaces in the seed sample,
        record it as a `temporary (N of TARGET)` gap, do NOT fabricate a verdict).
  - [ ] REFLECT the query's verdict — do NOT re-derive a second fairness predicate (the `LiveAffinityReadModel`
        11.4 discipline: reflect the `DarknessFairnessQuery` verdict, never compute your own). The harness reads
        `check_board`'s `ActionResult`; it does not re-implement the reachable-hazard-unseen-at-reduced-radius
        flood/LoS.

- [ ] **Task 4 — Failure-rate threshold → tuning flag + failing-seed preservation (AC3, AC4)**
  - [ ] Compute a per-recipe-batch failure rate (validation failures + bounded-retry EXHAUSTIONS over the
        batch). STATE + ASSERT the zero-tolerance thresholds verbatim (0 soft-locks, 0 mandatory class/item
        gates, 0 unreachable mandatory exits, 0 unreachable intended mandatory rewards, 0 unavoidable
        untelegraphed first-reveal punishments) AND the ≤ 1% bounded-retry-exhaustion-per-recipe-batch
        threshold. For the CURRENT approved catalog every threshold is MET (failure rate 0%, `attempts == 1`
        per seed), so the zero-tolerance asserts pass by construction.
  - [ ] Prove the threshold→flag→preserve REPORTING path fires (the forced-failure shape from Task 2): when the
        injected failure drives the rate above threshold, the harness FLAGS the relevant recipe / validation
        rule / retry limit (`MAX_GENERATION_ATTEMPTS`) for tuning in its report AND PRESERVES the failing
        seed(s) as DATA (a preserved-seed list — kept + annotated, the 3.7 preserved-catalog discipline; never
        silently discarded). Assert the preserved-seed record carries the seed + the failing phase/reason +
        the recipe so it is reproducible.

- [ ] **Task 5 — Durable readiness ledger + sample-size gap + 10.6 gate handoff (AC3, AC4)**
  - [ ] Author the durable readiness artifact (a sibling to 10.1's
        `device-tiers-and-performance-budgets.md` + 10.2's `seed-regression-suite-readiness.md`) at
        `_bmad-output/planning-artifacts/generator-fairness-batch-readiness.md`: STATE the zero-tolerance +
        ≤ 1% retry-exhaustion thresholds; STATE the `50 Small / 50 Medium` seed-sample target (shared with
        10.2's AC2); record the CURRENT sample (`[1001,2002,3003,4004,5005]` = 5+5) against target as an
        explicit `temporary (5 of 50) → owning action (a COORDINATED generation-sample expansion across the
        three Epic-10 harnesses, OR an approved de-scope at the 10.6 gate)` gap; state plainly that a
        sub-target sample CANNOT pass final MVP readiness without an approved de-scope (10.6's decision, not
        10.3's); and record the affinity-fairness coverage (which affinities surfaced in the sample vs the
        implemented four) as an honest gap where relevant.
  - [ ] Record the 10.6 gate handoff (the batch harness + its threshold verdict + the sample-gap ledger are a
        direct input to 10.6 — 10.6 decides whether a still-temporary sub-target sample is an acceptable
        documented readiness LIMITATION or a hard blocker) AND the reciprocal cross-references to 10.1
        (`device-tiers-and-performance-budgets.md` §7) + 10.2
        (`seed-regression-suite-readiness.md` §3/§7 — the shared-catalog coordination). Do NOT implement 10.6's
        gate decision here.

- [ ] **Task 6 — OPTIONAL report driver, cross-check, invariant re-verification, and gate handoff (AC1–AC4)**
  - [ ] OPTIONAL headless report driver (only if it genuinely earns its place, the 10.1/10.2 discipline): a
        `godot/tools/dump_generator_fairness_report.gd` `extends SceneTree` (the `dump_*` precedent —
        `dump_seed_batch_report.gd` is the closest sibling; `dump_seed_regression_report.gd` is 10.2's) that
        prints the consolidated `[PASS|FAIL] recipe / seed: <validation verdict> | <affinity fairness verdict>`
        report across the batch for eyeballing / reproduction. NOT auto-discovered, excluded from every export
        preset (the `tools/**` exclude_filter — provably cannot ship, the 10.1 AC5 evidence), grants no
        progression, writes no `user://` artifact (print-only). Do not add if the batch test already gives full
        coverage and no eyeball driver is needed.
  - [ ] Run the full headless suite via PowerShell (the `godot` binary is NOT on the Bash/`where` PATH — it
        resolves via `C:\Users\Rasmus\bin\godot.cmd` / the console binary):
        `godot --headless --path C:\Sealsworn\godot --scene res://tests/headless/test_runner.tscn
        --quit-after 10`. Apply the false-PASS grep guard: grep the RAW runner output; the SIX documented
        stderr negatives (int64-overflow ×2, malformed-JSON ×3, `invalid_node_type` ×1) still PASS and MUST
        NOT be mis-cited as a regression. The suite outcome must stay green (the 10.2-close baseline of
        **184 PASS / 0 `^FAIL`** plus this story's own new passing batch test(s)).
  - [ ] Verify NO generation/validation invariant moved: `level_validator.gd` (`check_order()` unchanged, the
        8 stable codes + `phase_for_code` unchanged), `darkness_fairness_query.gd` (the 4 reasons + the
        reduced-radius predicate unchanged), `generation_result.gd` (the 11 `PHASE_*` unchanged),
        `level_generator.gd` (`MAX_GENERATION_ATTEMPTS == 8`, the bounded-retry contract, attempt-0-unperturbed
        invariant), `rng_stream_set.gd` (`required_streams()` == 7), every existing `tools/dump_*` UNTOUCHED,
        every level/route/finale seed-regression fingerprint byte-identical, the DEFAULT deterministic
        generation paths byte-identical. Confirm `git diff --check` is clean and no production `godot/`
        generator/validator/gameplay/save/RNG/content file was touched (only new test(s) + an optional `tools/`
        report driver + the readiness ledger + the sprint-status/story-doc updates).
  - [ ] Record the gate handoff: the batch harness + its threshold verdict + the sample-size gap ledger is a
        direct input to **10.6 (MVP Readiness Gate)**. Cross-reference 10.2 (shares the Small/Medium seed
        catalog — keep them compatible so the two harnesses agree on seeds) and 10.7 (Asset/Audio/UX readiness
        gate — the Flooded `_placeholder` electric interaction is 10.7's item, NOT 10.3's; the batch reflects
        the Flooded fairness verdict but does not realize the electric chain). Do NOT implement 10.6's or
        10.7's content here.

## Dev Notes

### What this story is (and is not)

Epics 1–11 shipped a complete, headless, deterministic generation pipeline WITH per-candidate fairness/
soft-lock validation grown story-by-story: Story 3.6 built the comprehensive `LevelValidator` (the
reachability/soft-lock/placement/reward/readability/safe-first-reveal capstone, wired into
`LevelGenerator.generate`'s bounded deterministic retry); Story 3.7 added the FULL-`generate` batch
seed-regression harness (`test_seed_batch_regression.gd` over the approved Small+Medium catalog); Story 7.6
added `DarknessFairnessQuery` (the FR58 no-unavoidable-unseen-damage affinity fairness guardrail at the
Darkness-reduced radius). Story 10.1 added the performance-measurement harness; Story 10.2 added the
consolidated seed-regression suite. What the project has NEVER had is a **single BATCH harness that runs the
existing fairness/soft-lock validators over a seed SAMPLE, reports per-seed PASS/FAIL with compact `seed +
phase + reason` (+ `affinity`) diagnostics, applies the zero-tolerance + ≤ 1% retry-exhaustion readiness
THRESHOLDS, flags out-of-threshold recipes/rules/retry-limits for tuning, and preserves + tags every failing
seed for reproduction.** **Story 10.3 is the paper-plus-harness that closes that gap** — the
generator-fairness analog of 10.1 (performance) and 10.2 (seed determinism).

The single most important discipline (mirroring 10.1/10.2 and the 3.7/4.2 "no second pinning path"
cross-checks): **BATCH + REPORT the existing validators under one threshold contract; do NOT fork a parallel
soft-lock/fairness algorithm, and do NOT silently expand into a generator change.** The generator is
untouched; the validators are already deterministic + pure; this story proves + reports their verdicts over a
seed batch, applies the readiness thresholds, and records the honest sample-size gap.

### The two validators to REUSE (do not reinvent) — the crux of the story

| Concern | Canonical validator | Verdict shape | Failure fields |
|---|---|---|---|
| Reachability / soft-lock / legal placement / reachable rewards / readability / safe first reveal | `godot/scripts/generation/level/level_validator.gd` — `validate(candidate)` (candidate = `{layout, board, rewards}`). Wired into `LevelGenerator.generate`'s bounded retry. `check_order()` fixed; `phase_for_code(code)` → `pathing`/`enemies`/`validation`. | `ActionResult.ok([], {compact pass counts})` or `ActionResult.error(<stable code>, {compact diagnostics})` on the FIRST failing check. | code (e.g. `soft_lock_detected`, `unreachable_exit`, `illegal_enemy_placement`, `unreachable_reward`, `unsafe_first_reveal`, `required_gate_present`) + compact diagnostics (counts/coords) + `phase_for_code(code)`. |
| Affinity / Darkness fairness (FR58 no-unavoidable-unseen-damage) | `godot/scripts/generation/level/darkness_fairness_query.gd` — `check_board(board, affinity_id, repository, seed, entrance)`. Re-asserts safe-first-reveal at the Darkness-reduced radius (`DarknessVisibilityLayer.DARKNESS_REDUCED_LINE_OF_SIGHT_RADIUS == 2`, floor 1). | `ActionResult.ok([], {not_a_darkness_level})` for neutral/non-Darkness; compact PASS for a fair Darkness board; `ActionResult.error(&"darkness_fairness_violation", {fairness_reason, seed, phase, ...})` on the FIRST violation. | `fairness_reason` (`entrance_on_hazard` / `entity_on_entrance` / `darkness_unseen_hazard` / `invalid_darkness_candidate`) + `seed` (String) + `phase` (`validation`) + `affinity_id` + compact coords. |

- Both are PURE (draw no RNG, mutate nothing) — the batch harness calling them cannot perturb the generator's
  RNG draw order or any seed-regression fingerprint.
- `LevelValidator` is the COMPREHENSIVE SUPERSET that already subsumes the focused `validate_readability`
  (excessive_blockage / unreachable_exit / unreadable_first_reveal) + the placer's terrain-only
  reward-reachability. Call `LevelValidator.validate` for the full check — do NOT call the focused sub-checks
  separately (you would be re-assembling the superset).
- `DarknessFairnessQuery` is BOARD-SCOPED + CALLER-DRIVEN (runs over a BUILT board POST-generation). The
  generator is affinity-BLIND in v0 (the affinity is assigned POST-generation by the orchestrator, the 7.4
  contract), so a freshly-generated Darkness board is all-FLOOR and PASSES by construction (no hazard → nothing
  unseen can hurt you). The `darkness_unseen_hazard` FAIL branch is driven by a HAND-BUILT Darkness candidate
  carrying a reachable-but-unseen hazard — mirror the 7.6 test's hand-built-candidate pattern to exercise it.

### The candidate-reconstruction pattern (how to feed LevelValidator in the batch)

`LevelValidator.validate` needs `{layout, board, rewards}`. The `LevelGenerator.generate` payload carries the
board snapshot (`payload.board`), entrance/exit, blockers, and `rewards` markers. Reconstruct the candidate
the SAME way `test_seed_batch_regression.gd::_terrain_fingerprint_from_payload` reconstructs the layout, plus
`BoardState.try_from_snapshot(payload.board)` for the entity-aware `board`, and `payload.rewards` for the
reward markers. Do NOT hand-build a parallel candidate shape or a second board — reconstruct from the real
generate payload (the same discipline that keeps the terrain fingerprint byte-identical). NOTE: because
`LevelValidator` is ALREADY run inside `generate` (a successful `generate` means the validator already
passed), the direct `validate(candidate)` re-run in the batch is a BELT-AND-SUSPENDERS assertion that surfaces
the EXACT clear codes — it is not strictly required for correctness, but it is the AC1 evidence that each named
check (soft-lock, placement, reward, first-reveal) is individually clear, not just that `generate` succeeded.

### The threshold model (AC3/AC4 — the readiness verdict)

- **Zero-tolerance classes (AC4):** 0 soft-locks (`soft_lock_detected`), 0 mandatory class/item gates
  (`required_gate_present`), 0 unreachable mandatory exits (`unreachable_exit`), 0 unreachable intended
  mandatory rewards (`unreachable_reward` for `optional == false`), 0 unavoidable untelegraphed first-reveal
  punishments (`unsafe_first_reveal` + the `darkness_unseen_hazard` FR58 half). For the current approved
  catalog these are ALL 0 by construction (the approved seeds pass `LevelValidator` on the unperturbed attempt
  0). A batch level that fails ANY of these = readiness cannot pass (the story STATES this; 10.6 owns the gate).
- **Bounded-retry exhaustion ≤ 1% per recipe batch (AC4):** `LevelGenerator.generate` retries up to
  `MAX_GENERATION_ATTEMPTS == 8` deterministically-perturbed candidates; a seed that exhausts all 8 returns a
  structured `GenerationResult.error` with `attempts == 8`. The batch counts exhaustions / batch size per
  recipe; > 1% flags the recipe / validation rule / retry limit for tuning. For the current catalog the
  exhaustion rate is 0% (every seed passes on attempt 0, `attempts == 1`).
- **Failure-rate → tuning flag (AC3):** when the rate exceeds threshold, name the recipe (`small_combat_basic`
  / `medium_combat_basic`), the failing validation rule (the `LevelValidator` code / `DarknessFairnessQuery`
  reason), or the retry limit (`MAX_GENERATION_ATTEMPTS`) in the report — actionable, compact.
- **Failing-seed preservation (AC3/AC4):** every failing seed is preserved as DATA (a preserved-seed list —
  kept + annotated with its failing phase/reason/recipe, the 3.7 AC4 preserved-catalog discipline; never
  silently discarded) so it is reproducible. For the current 0%-failure catalog, the preservation PATH is
  proven by the forced-failure shape test.

### The sample-size reality (why a sub-target sample is an availability gap, not a blocker)

- AC1/AC4 are dischargeable WITHOUT reaching the full 50/50 target in one pass (the 10.2 posture): the batch
  runs the FULL current approved catalog (5 Small + 5 Medium — all PASS), STATES the 50/50 target, and records
  the sub-target sample as an explicit `temporary (5 of 50) → coordinated expansion / 10.6 de-scope` gap. This
  is the SAME honesty posture 10.1 used for physical-device numbers and 10.2 used for its seed samples.
- **Do NOT expand the shared generation seed catalog in isolation.** The 10.1 level-load harness + the 10.2
  regression suite BOTH pin `[1001,2002,3003,4004,5005]` (the 10.2 ledger §3 records this as the coordinated
  call: "Expanding generation to 50 in isolation would desync the three Epic-10 harnesses; the correct
  expansion is a coordinated pass across all three (10.1 level-load, 10.2 regression, 10.3 fairness) together").
  10.3 RESPECTS that: it may drive an ADDITIVE fairness-only batch sample (which pins NO terrain fingerprint —
  the fairness harness only reads validator verdicts), and it records the coordinated 50/50-expansion intent
  in the ledger for 10.6 to own. Do NOT re-pin any shared-catalog terrain fingerprint.
- **Do NOT fabricate coverage.** A PASS/FAIL verdict must come from an ACTUAL live run through the real
  validator over the real generate payload, never asserted to hit a count. A sub-target sample presented as if
  it met the bar is an AC4 failure. **Do NOT stop and ask a human** — the story is completable + valuable via
  the batch harness + the honest gap ledger.

### Deferred-work overlaps (folded in — only entries touching THIS story's surface)

From `_bmad-output/implementation-artifacts/deferred-work.md` (a project-wide ledger; most entries are out of
scope). Checked every open entry against 10.3's generator-fairness/soft-lock batch surface. The overlapping
ones:

- **The affinity-driven GENERATION modifier is DEFERRED to a SEPARATE later generation-modifier story — NOT
  10.3's.** (deferred-work "dev of 11-4" line 122 + "dev of 7-6" line 744 + "dev of 7-5" line 758 — a
  re-affirmed chain.) 10.3 runs the fairness batch over levels whose affinity is assigned POST-generation onto
  an affinity-BLIND generated board (the shipped v0 posture). It MUST NOT wire an assigned affinity into
  `RewardOfferBuilder` / reward tables / `EntityRewardPlacer` / the generator (the GDD "enter a cursed node for
  better reward odds" / reward-odds / elite-rate / spawn / hazard-baked-into-terrain changes). Doing so would
  (a) be out of scope and (b) PERTURB the seed-regression fingerprints this whole Epic-10 batch protects. The
  batch READS the generator's affinity-blind output + the post-generation fairness verdict; it changes NOTHING
  about how affinity meets generation. If a later generation-modifier story DOES bake affinity into generation,
  IT re-pins the affected fingerprints in ITS PR — that is the regression suite (10.2) working as designed, not
  a 10.3 obligation.
- **The Flooded / Conductive `_placeholder` electric interaction is 10.7's readiness item — NOT 10.3's.**
  (deferred-work "dev of 7-5" line 756 + "dev of 11-4" line 120.) AC4 of Story 7.5 requires the Flooded
  placeholder to be replaced / de-scoped / block readiness; that obligation is owned by **Story 10.7**
  (Asset/Audio-placeholder and UX readiness gate), NOT 10.3. 10.3's fairness batch REFLECTS the Flooded
  affinity's fairness verdict (`DarknessFairnessQuery` returns `not_a_darkness_level` for Flooded — Flooded is
  not a reduced-radius affinity, so it has no FR58 unseen-hazard fairness risk to re-assert), but 10.3 does NOT
  realize the live water/electric chain and does NOT resolve the placeholder — that is 10.7's call. Record the
  reflection; do not reopen the placeholder.
- **NONE of the other open deferred-work entries overlap this story's subject.** The remaining open items are
  live-layer / content / save-shape / meta work (the Necromancer/Shadeblade class kit + its profile-aware
  follow-ons; the live discovery/echo/Seal-Fragment source; the live in-node board / pending-fight save + the
  seated Cursed-affinity rule-source re-derive-on-resume; the run-level event store + `outcome_or_cause`; the
  G4 settings view model; the `OutpostRenderView` render efficiency; the int64-overflow economy ceiling; the
  constant-8-tier route-depth pacing). NONE concerns generator soft-lock/fairness batch validation, the
  zero-tolerance thresholds, or the retry-exhaustion rate. **Do NOT reopen or pre-empt any of them.**

### Retro forward-prep folded in (Epic-11 retro → Epic-10, this story's slice)

Epic 11 is the most recently closed epic; its retrospective (`epic-11-retro-2026-07-06.md`) forward sections
(§7 "Next-Epic Preview — Epic 10", §8 Action Items, §9 Readiness) are the epic-transition prep for Epic 10.
The items that bear on THIS story:

- **Reuse harnesses, don't rebuild (retro §7 point 5 / Action T-series).** The retro's explicit direction for
  Epic 10's measurement/REGRESSION/readiness stories is to EXTEND the existing harnesses (the `tools/dump_*`
  surveys, the 3.7 batch, the 3.6 `LevelValidator`, the 7.6 `DarknessFairnessQuery`, the 4.2 route fixtures)
  rather than author parallel ones. 10.3's batch harness COMPOSES the existing validators — do NOT fork a new
  soft-lock/fairness primitive.
- **Every determinism/generation invariant Epic 10 audits is intact and must stay so (retro §7 point 3, §9).**
  7 named RNG streams, ZERO new RNG draw sites, the 23-key `RunSnapshot` gate at 23,
  `ProfileSnapshot`/`SettingsSnapshot` `SCHEMA_VERSION == 1`, every generator/route/finale fingerprint
  byte-identical, the `LevelValidator` check-order + codes unchanged, the `GenerationResult` phase vocabulary
  unchanged, the DEFAULT deterministic generation paths byte-identical, the suite green. 10.3 is a
  readiness/batch-check story — it MUST NOT move any of these; it PROVES they hold. Any harness code is
  read-only over the generation domain and draws no gameplay RNG beyond what `generate` already draws per seed.
- **NO "fail-loud gate/check on a new table → register/extend it" heads-up applies to THIS story.** That
  Epic-transition head-up concerns CODE stories that add events / content families / save keys. 10.3 adds none
  of that — no new event, no `expected_ids` pin, no schema key, no fingerprint INTENTIONALLY changed, no new
  validator check or fairness reason. Do NOT go looking for a table to extend or a fail-loud gate to register.
  (Recorded so the dev agent doesn't hunt for one, the 10.1/10.2 discipline.)
- **Status-hygiene finalize step is orchestrator-owned, not 10.3's (retro §7 point 6 / Action P1/P2).** The
  atomic finalize (story `Status:` + the `sprint-status.yaml` entry + any doc commit as one unit with the
  merge) is the orchestrator's git/finalize scope; the delegate never runs git. On disk at authoring time
  `sprint-status.yaml` shows `10-2-...: done` and `10-3-...: backlog` — this story creation flips 10-3 to
  `ready-for-dev`; the dev/finalize flow owns the rest.
- **The "playable" framing + the deferred tap-loop (retro §7 point 1, §10) is 10.4/10.6/Epic-12 territory,
  NOT 10.3's.** 10.3 is a HEADLESS generator-safety batch — it validates the DETERMINISTIC generation +
  fairness of the domain under the existing deterministic paths. It does NOT need the interactive tap-loop or a
  winnable hero path (those gate 10.4's hands-on sessions + 10.6's "die or win" loop gate via Epic 12, per the
  2026-07-07 sprint change). 10.3 is one of the three Epic-10 stories — 10.1/10.2/10.3 — explicitly INDEPENDENT
  of Epics 11 & 12 per the `epics.md` sequencing notes (lines ~2365-2367).

### Epic-10 in-epic constraints surfaced by earlier stories (10.1, 10.2)

From `_bmad-output/auto-gds/retro-notes/epic-10.md` + the 10.1/10.2 story files:

- **Export-preset exclusion (10.1 § Story 10.1).** `export_presets.cfg` on disk carries THREE presets —
  Windows (`preset.0`), Android (`preset.1`), AND an iOS scaffold (`preset.2`, `runnable=false`, empty
  signing/icons). All three share the IDENTICAL `exclude_filter` excluding `tools/**`, `tests/**`, and
  `**/test_*.gd`. **Load-bearing for THIS story:** any `tools/dump_generator_fairness_report.gd` report driver +
  any `test_*.gd` the story adds is PROVABLY excluded from every export preset (it cannot ship in a production
  build) — the same AC5 evidence 10.1/10.2 relied on, and the reason a `tools/` report driver + a `tests/`
  batch suite are the correct homes for this readiness work. iOS packaging remains a deferred availability gap
  (macOS/Xcode), irrelevant to 10.3's headless scope but noted so the export-filter fact is cited correctly.
- **Avoid blanket "untouched" clauses that contradict a specific sanctioned edit (10.2 § Story 10.2).** The
  10.2 retro note flags that Task-6 "every `tools/dump_*` UNTOUCHED" phrasing conflicted with Task-3's
  sanctioned route-dump expansion; the specific instruction governed. Applied here: Task 6 says "every existing
  `tools/dump_*` UNTOUCHED" AND Task 6 sanctions a NEW `tools/dump_generator_fairness_report.gd`. These do NOT
  conflict — the NEW driver is an ADD, not an edit to an EXISTING dump tool; the existing four generation dump
  tools + the two route/regression drivers stay byte-identical. Do not read the "untouched" clause as
  forbidding the new sibling driver.
- **Shared Epic-10 seed catalog (10.1 §7, 10.2 §3/§7).** The 10.1 level-load harness + the 10.2 regression
  suite BOTH draw over `[1001,2002,3003,4004,5005] × {small_combat_basic, medium_combat_basic}`; the 10.2
  ledger explicitly records that a generation-sample expansion toward 50/50 must be a COORDINATED pass across
  10.1 (level-load), 10.2 (regression), AND 10.3 (fairness). 10.3 MUST keep its generation seed catalog
  compatible with that shared set (draw the same 5+5 for the terrain-affecting batch), and record the
  coordinated-expansion intent in its ledger — do NOT desync the three harnesses.
- **Current suite baseline is 184 PASS / 0 `^FAIL`** (10.2 close: 183 from 10.1 + the 1 new
  `test_seed_regression_suite.gd`). This story must not change the suite outcome beyond adding its own passing
  batch test(s). The SIX documented stderr negatives (int64-overflow ×2, malformed-JSON ×3, `invalid_node_type`
  ×1) still PASS — apply the false-PASS grep guard.

### Numbering caveat (avoid the wrong FR/NFR)

- 10.3's grounding is the canonical implementation **FR36** (`epics.md` — generation validates against unfair /
  soft-locked layouts: reachability, no soft-lock, no required class/item gate, legal placement, reachable
  rewards, fog/readability, safe first reveal) + **FR58** (the Darkness "no unavoidable damage from unseen
  space" fairness guarantee) + **NFR13** (deterministic under seeded execution — the generation the batch
  re-runs). The Epic-10 FR coverage is **FR30** (run-length target validated during MVP tuning) + **FR70**
  (playable-build preservation across readiness gates) — but 10.3's concrete deliverable is the fairness/
  soft-lock BATCH harness that protects FR36+FR58 across a seed sample, feeding the 10.6 gate. Cite the
  canonical `epics.md` numbering; do NOT conflate with any design-time GDD FR/NFR numbering.

### Project Structure Notes

- **Primary output location(s):**
  - The batch harness: a new `test_*.gd` under `godot/tests/integration/` (an integration-level cross-system
    generator-safety batch is the right home; the seed-regression suite + finale suite already live there). The
    headless runner auto-discovers `test_*.gd` under `res://tests/unit` and `res://tests/integration` only.
  - OPTIONAL report driver: `godot/tools/dump_generator_fairness_report.gd` (the `dump_*` `SceneTree`
    precedent) — only if a reproduction / eyeball driver genuinely earns its place. NOT auto-discovered,
    excluded from every export preset (`tools/**`), print-only (no `user://` artifact, no progression).
  - Durable readiness ledger: `_bmad-output/planning-artifacts/generator-fairness-batch-readiness.md` (the
    durable artifact the 10.6 gate consumes — a sibling to 10.1's `device-tiers-and-performance-budgets.md` +
    10.2's `seed-regression-suite-readiness.md`). A planning artifact, NOT under `godot/`.
- **Do NOT touch:** any generator / layout algorithm / `LevelValidator` check-order or codes /
  `DarknessFairnessQuery` predicate or reasons / `GenerationResult` phase vocabulary / `MAX_GENERATION_ATTEMPTS`
  / RNG stream / `RunSnapshot`/`ProfileSnapshot`/`SettingsSnapshot` schema / save key / any
  generator/route/finale seed-regression fingerprint SOURCE or its pinned catalog values / view model / content
  definition; `prototype/` (frozen validation evidence); `_bmad/` (installer-managed). The batch harness READS
  these; it does not change them. A fingerprint "drift" is a BUG to investigate, not a value to update.
- **Naming/organization:** follow the project-context Code Organization rules — `tests/` and `tools/` are the
  correct homes for batch-check + report code; `snake_case` files, `PascalCase` classes, `UPPER_SNAKE_CASE`
  constants. Test files begin with `test_`; a `tools/` driver `extends SceneTree`.

### Project Context Rules

Extracted from `project-context.md` / `AGENTS.md` (the canonical rulebooks). The rules that bear on THIS story:

- **Generator validation = compact, actionable diagnostics — NEVER a raw dump (§ Procedural Generation rules).**
  "Generator validation failures must report seed, phase, reason, and compact diagnostics (counts/coords/ratios)
  — NEVER a full terrain-grid dump." The batch report MUST carry `seed + phase + reason` (+ `affinity` for the
  fairness half), compact, actionable; NEVER a grid/board dump. Both `LevelValidator` and
  `DarknessFairnessQuery` already emit exactly this shape — REFLECT it.
- **Snapshots / validation are PURE reads (§ Save/Snapshot rules; NFR14).** `LevelValidator.validate` and
  `DarknessFairnessQuery.check_board` draw NO RNG, execute NO commands, mutate nothing. The batch harness
  calling them stays pure over the generation domain — it does not perturb any RNG stream or fingerprint.
- **Determinism is project-context law (NFR13; § Determinism / RNG rules).** "Gameplay-affecting systems must
  be deterministic under seeded execution." The generation the batch re-runs is a pure function of
  `(root_seed, recipe)`; the affinity assignment draws the named `map` stream only. The batch re-runs seeds and
  asserts stable verdicts — it introduces no new randomness.
- **Headless simulation is render/audio/scene-free (NFR14; § Testing / Headless rules).** "Headless simulation
  must run without rendering, audio, UI scenes, presentation nodes, or scene-tree-only state." The batch
  harness runs headlessly; no `SceneTree`/render/device dependency in the TEST (the `tools/` driver is a
  dev/CI `SceneTree` script, not a test and not shipped).
- **No cloud/telemetry/live-service dependency (NFR11; § Platform & Build rules).** The batch harness + any
  report driver stay local; no runtime telemetry/cloud call. Local print/report only. Debug/report tooling is
  `tools/`-gated and excluded from every export preset (the 10.1 AC5 evidence).
- **Difficulty is a HARD non-goal (§ Affinity rules; project-context).** The affinity fairness the batch
  validates is authored, bounded PRESSURE surfaced HONESTLY (the Darkness reduced radius + memory uncertainty;
  the Scorched/Flooded/Cursed marks) — NEVER a hidden multiplier. The batch REFLECTS the fairness verdict; it
  does not tune difficulty, scale stats, or change reward odds (that is the deferred generation-modifier
  story). AC2's "critical danger is inspectable or telegraphed" is satisfied by the EXISTING accessibility cues
  (color-independent, audited by `test_tactical_accessibility_cues.gd`) — do not author a new telegraph.
- **Godot / testing (§ Testing rules).** Run the full suite via PowerShell (the `godot` binary is NOT on the
  Bash/`where` PATH — it resolves via `C:\Users\Rasmus\bin\godot.cmd` / the console binary):
  `godot --headless --path C:\Sealsworn\godot --scene res://tests/headless/test_runner.tscn --quit-after 10`.
  Apply the false-PASS grep guard: the SIX documented stderr negatives (int64-overflow ×2, malformed-JSON ×3,
  `invalid_node_type` ×1) still PASS and must not be mis-cited as a regression. This story must not change the
  suite outcome (**184 PASS / 0 `^FAIL`** at 10.2 close) beyond adding its own passing batch test(s).

### References

- **Story source (verbatim ACs):** `_bmad-output/planning-artifacts/epics.md` — Epic 10 §"Story 10.3:
  Generator Soft-Lock and Fairness Batch Checks" (lines ~2430–2456). Epic 10 section header + sequencing notes
  (10.1–10.3 independent of Epics 11/12): lines ~2361–2367.
- **Canonical FR/NFRs (`epics.md`):** FR36 (generation validates against unfair/soft-locked layouts —
  reachability / no-soft-lock / no-required-gate / legal placement / reachable rewards / fog-readability /
  safe-first-reveal — the CORE guarantee this batch protects; the Story 3.6 validators realize it), FR58 (the
  Darkness "no unavoidable damage from unseen space" fairness — the Story 7.6 `DarknessFairnessQuery` realizes
  it; lines ~1304–1311 / ~1486 in the Story 3.6 / 4.x sections cross-reference the soft-lock/first-reveal
  contract), NFR13 (deterministic under seeded execution), NFR14 (headless render/audio/scene-free), NFR11 (no
  cloud/live-service). FR30 + FR70 are the Epic-10 FR coverage this readiness story sits under.
- **The two validators to REUSE (READ before authoring the batch harness):**
  `godot/scripts/generation/level/level_validator.gd` (the 3.6 comprehensive soft-lock/reachability/placement/
  reward/readability/safe-first-reveal validator — `validate(candidate)`, `check_order()`, `phase_for_code()`);
  `godot/scripts/generation/level/darkness_fairness_query.gd` (the 7.6 FR58 affinity fairness guardrail —
  `check_board(...)`, the 4 stable reasons, the reduced-radius predicate);
  `godot/scripts/generation/level/level_generator.gd` (`generate(request, recipes, enemies, validator=null)` —
  the bounded retry, `MAX_GENERATION_ATTEMPTS == 8`, the optional 4th `validator` test seam, the
  attempt-0-unperturbed invariant); `godot/scripts/generation/level/generation_result.gd` (the 11 `PHASE_*`
  vocabulary + the `succeeded`/`failed_phase`/`reason`/`diagnostics`/`payload` shape);
  `godot/scripts/tactical/fog/darkness_visibility_layer.gd` (`DARKNESS_REDUCED_LINE_OF_SIGHT_RADIUS == 2`, the
  reduced radius the fairness predicate reasons against).
- **The batch-drive + candidate-reconstruction precedent (the CLOSEST sibling harness):**
  `godot/tests/unit/generation/test_seed_batch_regression.gd` (the 3.7 FULL-`generate` Small+Medium batch over
  `APPROVED_SEED_CATALOG` = `[1001,2002,3003,4004,5005]`, the `_terrain_fingerprint_from_payload` candidate
  reconstruction, the `_failure_report_shape_carries_seed_recipe_phase_reason` forced-failure shape, the
  DELIBERATE-UPDATE header) and its regenerator `godot/tools/dump_seed_batch_report.gd`.
- **The affinity-assignment path (for the fairness half):** `godot/tests/unit/run/test_affinity_assignment.gd`
  (the `RunOrchestrator.assign_affinity(node)` → `map`-stream deterministic assignment; `SEED_SAMPLE`
  `[1,7,42,99,2026]`; the `AffinityRepository.BASELINE_AFFINITY_IDS` = `scorched`/`flooded_conductive`/`cursed`/
  `darkness`/`none`); `godot/scripts/run/run_orchestrator.gd::assign_affinity` (line ~702) /
  `assigned_affinity_for` (line ~750); `godot/scripts/content/repositories/affinity_repository.gd`
  (`BASELINE_AFFINITY_IDS`, `create_baseline_repository`).
- **The 7.6 fairness test (the hand-built unseen-hazard pattern for AC2):**
  `godot/tests/unit/generation/test_darkness_fairness.gd` (READ for the hand-built Darkness candidate with a
  reachable-but-unseen hazard that drives `darkness_unseen_hazard`, and the seeded-approved-seed PASS).
- **Prior-story precedent (the readiness-plus-harness analogs — the closest siblings):**
  `_bmad-output/implementation-artifacts/10-2-headless-seed-regression-suite.md` (the consolidated-suite +
  honest-gap-ledger + reuse-not-rebuild + no-second-format + shared-catalog-coordination discipline; its
  readiness ledger `_bmad-output/planning-artifacts/seed-regression-suite-readiness.md` §3/§7 records the
  10.3 coordination) and `_bmad-output/implementation-artifacts/10-1-device-tiers-and-performance-budgets.md`
  (the measure-what-you-can + record-honest-gaps + `tools`-gated harness discipline; its
  `device-tiers-and-performance-budgets.md` §7 records the shared level-load seed sample + the 10.3 fairness
  batch coordination).
- **Epic-11 retro (forward prep for Epic 10 — the epic-transition heads-ups):**
  `_bmad-output/implementation-artifacts/epic-11-retro-2026-07-06.md` §7 (reuse harnesses; invariants intact;
  the deferred tap-loop is 10.4/10.6/Epic-12, not 10.1/10.2/10.3), §8 (Action items — P1/P2 status hygiene are
  orchestrator-owned; T-series reuse existing harnesses), §9 (Readiness — every invariant held).
- **Epic-10 in-epic retro notes (the immediately-prior stories' surfaced constraints):**
  `_bmad-output/auto-gds/retro-notes/epic-10.md` § Story 10.1 (the three-preset `export_presets.cfg` with the
  identical `tools/**`+`tests/**`+`**/test_*.gd` exclude_filter — the AC-evidence that a `tools/` driver +
  `tests/` batch provably cannot ship) + § Story 10.2 (avoid blanket "untouched" clauses that contradict a
  specific sanctioned edit — the new `tools/` driver is an ADD, not an edit to an existing dump tool).
- **Deferred-work ledger (checked for overlap):**
  `_bmad-output/implementation-artifacts/deferred-work.md` — the affinity-driven GENERATION modifier (line 122
  "dev of 11-4" + line 744/758 the "dev of 7-6"/"dev of 7-5" chain — DEFERRED to a later generation-modifier
  story, NOT 10.3's; 10.3 must not wire affinity into generation / reward odds) and the Flooded `_placeholder`
  electric interaction (line 120 "dev of 11-4" + line 756 "dev of 7-5" — owned by **10.7**, not 10.3; 10.3
  reflects the Flooded fairness verdict but does not realize the electric chain). No other open ledger item
  overlaps this story's generator-fairness/soft-lock surface.
- **Sibling Epic-10 stories the batch feeds/coordinates with:** Story 10.2 (Headless Seed Regression Suite —
  shares the `[1001,2002,3003,4004,5005]` Small/Medium seed catalog; keep compatible), Story 10.6 (MVP
  Readiness Gate — consumes the batch harness + the threshold verdict + the sample-size gap ledger; owns the
  temporary-sample de-scope decision), Story 10.7 (Asset/Audio/UX readiness gate — owns the Flooded
  `_placeholder` electric-interaction resolution). `epics.md` lines ~2430–2456 / ~2530–2569 / ~2570+.

## Dev Agent Record

### Context Reference

- Story file: `_bmad-output/implementation-artifacts/10-3-generator-soft-lock-and-fairness-batch-checks.md`
  (this file — the comprehensive context the create-story step produced).
- Durable readiness artifact to author by this story:
  `_bmad-output/planning-artifacts/generator-fairness-batch-readiness.md`.

### Agent Model Used

{{agent_model_name_version}}

### Debug Log References

### Completion Notes List

### File List

## Change Log

| Date | Change |
|---|---|
| 2026-07-07 | Story 10.3 context created (create-story). Generator-soft-lock-and-fairness-batch-checks scope framed as the generator-safety analog of 10.1 (performance) + 10.2 (seed determinism): BATCH the two EXISTING validators (`LevelValidator` from 3.6, `DarknessFairnessQuery` from 7.6) over the shared Small/Medium seed catalog + each level's assigned affinity, report per-seed PASS/FAIL with compact `seed + phase + reason` (+ `affinity`) diagnostics, apply the AC4 zero-tolerance (0 soft-locks / gates / unreachable exits / unreachable mandatory rewards / unavoidable untelegraphed first-reveal punishments) + ≤ 1% bounded-retry-exhaustion-per-recipe-batch thresholds, flag out-of-threshold recipes/rules/retry-limits for tuning, preserve + tag every failing seed, and record the current-vs-target (5-of-50) sample gap as a 10.6-owned honest-scope ledger. REUSE-not-fork the validators (no second soft-lock/fairness algorithm — the #1 review risk); keep the generation seed catalog compatible with the 10.1/10.2 shared `[1001,2002,3003,4004,5005]` set (no isolated expansion → no fingerprint drift); the affinity-driven GENERATION modifier stays DEFERRED (must NOT wire affinity into reward odds/generation); the Flooded `_placeholder` electric interaction is 10.7's, not 10.3's; leave every generation/determinism invariant (7 RNG streams, `LevelValidator` check-order+codes, `DarknessFairnessQuery` reasons, `GenerationResult` phases, `MAX_GENERATION_ATTEMPTS == 8`, 23-key RunSnapshot, all fingerprints) byte-identical. Status → ready-for-dev. |
