---
baseline_commit: 3508181a37c2d7833ea73e522e73b90852ea590f
---

# Story 10.2: Headless Seed Regression Suite

Status: review

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a player,
I want common seeds and tactical flows to remain stable,
so that fixes do not break determinism or core gameplay.

## Story Type & Scope Boundary (READ FIRST)

**This is a REGRESSION-CONSOLIDATION / READINESS story — the seed-determinism analog of Story 10.1
(the device-tiers + performance-budgets planning-plus-harness story), NOT a gameplay-feature story.**
The project already has strong PER-SYSTEM seed-regression coverage scattered across the suite (the 3.7
Small+Medium batch, the 4.2 route fixtures, the 9.5 finale chain, the 2.8 interrupted==uninterrupted
proof, the reward/affinity per-seed determinism tests). What it has NEVER had is a **single
CONSOLIDATED headless seed regression harness that reports one deterministic fingerprint + pass/fail
per fixture across ALL six named systems (tactical, generation, route, reward/passive, affinity, boss)
with a stated seed-sample size per system, a compact `seed + system + phase + reason` failure report,
and an explicit "current sample vs the MVP-readiness target sample" gap ledger.** Story 10.2 is the
paper-plus-harness that builds it: a consolidated regression driver/suite that COMPOSES the existing
per-system regression paths (it does NOT re-derive a second fingerprint format), records the pause/resume
determinism proof, and records every sub-target sample as a `temporary sample → approved de-scope or a
sample-expansion pass` availability gap the 10.6 readiness gate consumes.

- **This is not a domain/tactical/save/RNG/content story.** Do NOT change any gameplay command, event,
  RNG stream, `RunSnapshot`/`ProfileSnapshot`/`SettingsSnapshot` schema, save key, generator/route/finale
  fingerprint, view model, or content definition. The full headless suite (**183 PASS / 0 `^FAIL`** at
  10.1 close — the Epic-11 baseline of 182 plus the one `test_performance_budget_report.gd` 10.1 added)
  must stay green and byte-for-byte behaviorally unchanged. This story ADDS a regression harness + (if it
  genuinely earns its place) a consolidated report driver + a harness-contract test; it does NOT perturb
  the simulation. Any new test ASSERTS deterministic fingerprints of the EXISTING systems (which are
  already deterministic), never introduces new gameplay.
- **REUSE the existing regression infrastructure — do NOT fork a parallel fingerprint format or a
  parallel catalog.** The Epic-11 retro's explicit Epic-10 direction (retro §7 point 5 / T-series) is to
  EXTEND the existing harnesses, not author parallel ones. The per-system fingerprints ALREADY have a
  single canonical source each (e.g. `SmallLevelLayoutGenerator.fingerprint`, `RouteGenerator.fingerprint`,
  the finale composite in `test_finale_seed_regression.gd`). A consolidated suite must call those SAME
  sources; a second fingerprint format that can silently diverge from the pinned per-system value is a
  review miss (the same "no second pinning path" discipline the 3.7 batch and 4.2 route tests enforce
  with their `_..._agree_with_generate_layout` / `_fingerprint_helper_cross_checks_live_route`
  cross-checks).
- **The full MVP-readiness seed-sample sizes (AC2) are a HONEST-SCOPE decision, not an auto-expand
  mandate.** AC2 states the FINAL target sample (≥25 tactical, 50 Small, 50 Medium, 20 route, 20
  reward/passive, 10 per implemented affinity, 10 boss) AND states that "any smaller pre-MVP sample is
  marked as temporary and cannot pass final MVP readiness without approved de-scope." The current
  on-disk fixtures are FAR below that (Small 5 / Medium 5 / route 8 / boss 5 / reward+affinity per-seed
  spot checks). The correct autonomous outcome mirrors 10.1's "measure what you can, record honest gaps":
  the dev agent may EXPAND the seed samples toward the target where doing so is a mechanical
  seed-list-plus-fingerprint-pin extension of an existing harness (cheap, high-value, no gameplay risk),
  and MUST record every sub-target sample as an explicit `temporary sample (N of TARGET) → owning action
  (a sample-expansion pass, or an approved de-scope at the 10.6 gate)` note. Do NOT fabricate coverage
  you did not actually run; do NOT silently pass a sub-target sample as if it met the readiness bar; do
  NOT block on reaching every target if the expansion is genuinely large — record the gap and hand it to
  10.6.
- **Determinism / save invariants are the thing this suite PROTECTS — it must leave them byte-identical.**
  7 named RNG streams (`map`/`level`/`combat`/`loot`/`rewards`/`events`/`cosmetic`), ZERO new RNG draw
  sites, the 23-key `RunSnapshot` gate at 23, `ProfileSnapshot`/`SettingsSnapshot` `SCHEMA_VERSION == 1`,
  every generator/route/finale fingerprint byte-identical, the DEFAULT deterministic paths byte-identical.
  A regression suite that MOVED any of these would be self-defeating. Any harness code is read-only over
  the domain and draws no gameplay RNG.

## Acceptance Criteria

Sourced verbatim from `epics.md` (Epic 10, Story 10.2). Four AC groups (Given/When/Then + And):

1. **Consolidated per-fixture fingerprint + pass/fail across all six systems (AC1).** GIVEN approved seed
   fixtures exist for **tactical, generation, route, reward, affinity, and boss** flows, WHEN the headless
   seed regression suite runs, THEN **each fixture reports deterministic fingerprints and pass/fail
   status**, AND **failures include seed, system, phase, and reason**.

2. **Final MVP-readiness seed sample sizes + the temporary-sample gate (AC2).** GIVEN final MVP readiness
   seed coverage is selected, WHEN seed sample sizes are reviewed, THEN the suite includes **at least 25
   tactical command/board fixtures, 50 Small level seeds, 50 Medium level seeds, 20 route seeds, 20
   reward/passive seeds, 10 seeds per implemented affinity, and 10 boss/finale seeds**, AND **any smaller
   pre-MVP sample is marked as temporary and cannot pass final MVP readiness without approved de-scope**.

3. **Pause/resume determinism in simulation (AC3).** GIVEN RNG stream state is snapshotted during tests,
   WHEN a run is **paused and resumed in simulation**, THEN **subsequent outcomes match the uninterrupted
   run**, AND **cosmetic stream usage does not change gameplay outcomes**.

4. **Intentional-change discipline: no silent drift (AC4).** GIVEN the suite is run in development, WHEN
   **any deterministic fixture changes intentionally**, THEN **fixture updates require an explicit
   expected-output update**, AND **accidental drift is visible**.

### AC Verification (how "done" is checked)

- **AC1** — a consolidated regression surface exists that, for EACH of the six named systems, drives its
  approved seed fixtures and emits (a) a deterministic fingerprint per fixture (from the system's SINGLE
  canonical fingerprint source, NOT a re-derived second format) and (b) a per-fixture pass/fail; and every
  failure path carries the four-field report `seed + system + phase + reason` (compact — never a grid/raw
  dump). "System" here spans all six: tactical (command/board), generation (Small/Medium level layout),
  route (`map`-stream route), reward/passive (rewards-stream offer), affinity (`map`-stream assignment per
  implemented affinity), boss (the finale chain). A system with no fingerprint+pass/fail path, or a
  failure that omits any of the four fields, = AC1 not met. NOTE the six systems already have per-system
  regression tests — AC1 is met by CONSOLIDATING/covering them under one reporting contract (a suite that
  runs them all + a driver that reports them uniformly), not by rebuilding each.
- **AC2** — the target sample sizes are STATED (the seven numbers verbatim) and the suite's ACTUAL sample
  per system is recorded against each target; where the actual sample is below target, it is EXPLICITLY
  marked `temporary (N of TARGET)` with an owning follow-up, and the suite/doc states that a sub-target
  sample cannot pass final MVP readiness without an approved de-scope (the 10.6 gate owns that decision).
  A missing target number, a sub-target sample presented as if it met the bar, or a fabricated
  never-actually-run sample = AC2 not met. (Expanding a sample toward target is allowed and encouraged
  where mechanical; NOT reaching every target is acceptable ONLY as a recorded temporary-sample gap.)
- **AC3** — the suite includes (or covers, via the existing 2.8 `test_resume_flow.gd` path it consolidates)
  a pause-and-resume-in-simulation proof: a run saved → restored through the real save/resume path → given
  the identical remaining command sequence reproduces byte-identical final domain snapshot + ordered event
  log + gameplay RNG stream states as the uninterrupted path, with a FIRST-divergence locator (event index
  / stream name, not a bare boolean); AND a cosmetic-stream-independence assertion (interleaving `cosmetic`
  draws does not change any gameplay-stream outcome). A pause/resume proof that reports only a boolean, or
  omits the cosmetic-independence check, = AC3 not met.
- **AC4** — every pinned fingerprint the suite asserts carries the DELIBERATE-UPDATE contract in its
  header/comment (change ONLY with an intentional generator/system change re-pinned in the SAME PR via the
  matching `tools/dump_*` regenerator; NEVER hand-edited to silence a drift), the assert message on a
  regression names the failing fixture + the regenerator to re-pin, and an accidental (un-re-pinned) change
  makes the suite FAIL loudly (visible drift). A fixture whose expected output can be silently mutated
  without a red test, or an assert that omits the re-pin instruction, = AC4 not met.

## Tasks / Subtasks

- [x] **Task 1 — Inventory the existing per-system regression coverage + its single fingerprint sources (AC1, AC4)**
  - [x] Read the six existing per-system regression surfaces and confirm each system's SINGLE canonical
        fingerprint source before writing any consolidation (a second format is a review miss):
        - **Generation (Small/Medium):** `godot/tests/unit/generation/test_seed_batch_regression.gd`
          (the 3.7 FULL-`LevelGenerator.generate` batch over the approved Small+Medium catalog +
          `_catalog_fingerprints_agree_with_generate_layout` cross-check) and
          `test_small_level_layout_seed_regression.gd` / `test_medium_level_layout_seed_regression.gd`
          (the layout-level pins). Fingerprint source: `SmallLevelLayoutGenerator.fingerprint` /
          `MediumLevelLayoutGenerator.fingerprint`. Regenerator tools:
          `tools/dump_seed_batch_report.gd`, `dump_small_layout_fingerprints.gd`,
          `dump_medium_layout_fingerprints.gd`.
        - **Route:** `test_route_generation_seed_regression.gd` (the 4.2 pins + the
          `_fingerprint_helper_cross_checks_live_route` cross-check). Source: `RouteGenerator.fingerprint`.
          Regenerator: `tools/dump_route_fingerprints.gd`.
        - **Boss/finale:** `godot/tests/integration/finale/test_finale_seed_regression.gd` (the 9.5
          composite setup/phase/telegraph/victory/defeat chain — an INLINE catalog, deliberately NOT a
          `tools/dump_*` because the arena is fixed + the AI is ZERO-RNG, so there is no layout
          fingerprint to dump — the "fingerprint" is a live composite cross-checked for reproducibility).
        - **Reward/passive:** `godot/tests/unit/run/test_reward_offer_generate.gd` (the per-seed
          deterministic 3-choice passive / gold offer through the `rewards` stream).
        - **Affinity:** `godot/tests/unit/run/test_affinity_assignment.gd` (the per-seed deterministic
          `map`-stream assignment; the implemented affinities are Scorched / Flooded-Conductive / Cursed /
          Darkness per FR56).
        - **Tactical (command/board):** the command/board determinism is proven across the Epic-1 command
          tests + `test_board_state.gd` / `test_board_fixtures.gd` + the 2.8 interrupted==uninterrupted
          proof; the tactical "fixture" for a consolidated seed suite is a deterministic command/board
          sequence whose applied-event log + board snapshot fingerprint reproduces per seed (compose the
          `BoardFixtureFactory` boards + committed `DomainEvent`s, the 2.8 pattern — do NOT invent a new
          tactical scenario format).
  - [x] Record, per system, the CURRENT sample size on disk (generation Small 5 / Medium 5; route 8; boss
        5; reward + affinity per-seed spot checks) — this is the baseline for the AC2 gap ledger.

- [x] **Task 2 — Build the consolidated regression suite + uniform four-field report (AC1)**
  - [x] Author a consolidated headless suite (a new `test_*.gd` under `godot/tests/integration/` — an
        integration-level cross-system regression is the right home; the finale suite already lives under
        `tests/integration/finale/`) that drives EACH of the six systems' approved fixtures and asserts
        (a) a deterministic fingerprint per fixture (calling the system's canonical source) and (b) a
        per-fixture pass/fail, with EVERY failure assert carrying `seed=%d system=%s phase=%s reason=%s`
        (the 3.7 / 9.5 failure-report shape, generalized to name the SYSTEM). Include a FORCED-failure
        shape test (the `_failure_report_shape_carries_...` precedent) so the harness can never silently
        pass a regression.
  - [x] Where a system's regression already fully lives in its own test file (route, finale), the
        consolidated suite may COMPOSE/invoke that coverage or assert the same canonical fingerprints
        rather than duplicate the pins — the goal is one reporting contract across all six, NOT a copy of
        every pinned value into a second file that can drift. If the consolidated suite re-pins any value,
        it MUST cross-check against the live per-system source in the same test (the "no second pinning
        path" discipline) so the consolidated pin can never silently disagree with the per-system fixture.
  - [x] OPTIONAL headless report driver (only if it genuinely earns its place, the 10.1 discipline): a
        `tools/dump_seed_regression_report.gd` `extends SceneTree` (the `dump_*` precedent —
        `dump_seed_batch_report.gd` is the closest sibling) that prints the consolidated
        `[PASS|FAIL] system / seed: fingerprint` report across all six systems for eyeballing / re-pinning.
        NOT auto-discovered, excluded from every export preset (the `tools/**` exclude_filter), grants no
        progression, writes no `user://` artifact (print-only). Do not add if the consolidated test already
        gives full coverage and no re-pin driver is needed.

- [x] **Task 3 — Sample-size target + temporary-sample gap ledger (AC2)**
  - [x] STATE the seven MVP-readiness target sample sizes verbatim (≥25 tactical, 50 Small, 50 Medium,
        20 route, 20 reward/passive, 10 per implemented affinity, 10 boss/finale). Record them in the
        suite header AND (the durable readiness artifact) as a short section — either extend the 10.1
        readiness doc (`_bmad-output/planning-artifacts/device-tiers-and-performance-budgets.md` already
        records the 10.2 handoff at its §7 gate-handoff) or author a sibling
        `_bmad-output/planning-artifacts/`-level regression-suite readiness note. The 10.6 gate consumes
        whichever you pick — make the linkage self-documenting (the 11.1 / 10.1 precedent).
  - [x] EXPAND the seed samples toward target where the expansion is a mechanical seed-list-plus-pin
        extension of an existing harness and is genuinely low-risk (e.g. adding more approved Small/Medium
        seeds via `dump_seed_batch_report.gd`, more route seeds via `dump_route_fingerprints.gd`, more
        boss seeds to the finale catalog, more reward/affinity per-seed cases). Each newly pinned value
        must be regenerated from the live `tools/dump_*` output (NOT hand-typed) and carry the
        DELIBERATE-UPDATE header. For preserved bland/unfair seeds, keep + annotate them (the 3.7 AC4
        preserved-catalog discipline) rather than discard.
  - [x] For every system whose ACTUAL sample is below its target, record an explicit
        `temporary sample (N of TARGET) → owning action` note (a later sample-expansion pass, or an
        approved de-scope at the 10.6 gate). State plainly that a sub-target sample CANNOT pass final MVP
        readiness without an approved de-scope — that decision belongs to 10.6, not 10.2. Do NOT fabricate
        a sample you did not run; do NOT silently present a sub-target sample as meeting the bar.

- [x] **Task 4 — Pause/resume determinism + cosmetic independence (AC3)**
  - [x] Cover the pause-and-resume-in-simulation proof: the 2.8 `test_resume_flow.gd`
        (`godot/tests/integration/save/test_resume_flow.gd`) ALREADY proves interrupted==uninterrupted
        (board snapshot + ordered event log + gameplay RNG stream states + next-draw reproduction, with a
        FIRST-divergence locator for both event index and stream name) over a REAL `SaveRepository` JSON
        write→read + `RunResumeService.resume`. The consolidated suite must ensure this proof is part of
        the readiness regression set (invoke/compose it or assert the same guarantees across the seed
        sample) — do NOT re-invent the interrupted==uninterrupted harness; it exists and is the canonical
        one. If you assert it across additional seeds, reuse `RngStreamSet.to_snapshot()`/`try_restore` +
        the `_first_divergent_*` locators, not a new comparator.
  - [x] Assert the cosmetic-stream-independence half of AC3 explicitly: interleaving `cosmetic`-stream
        draws before/around a gameplay draw does NOT change the gameplay-stream outcome (the Story 1.4
        AC2 guarantee — `test_rng_stream_set.gd` already proves per-stream isolation; the readiness suite
        should state/assert this for the pause/resume path so "cosmetic usage does not change gameplay
        outcomes" is covered, not assumed).

- [x] **Task 5 — Intentional-change discipline + no-silent-drift guarantee (AC4)**
  - [x] Every pinned fingerprint the consolidated suite asserts carries the DELIBERATE-UPDATE contract in
        its header (change ONLY with an intentional system change re-pinned in the SAME PR via the matching
        `tools/dump_*`; NEVER hand-edited to silence a drift — verbatim to the 3.7 / 4.2 test headers). The
        regression assert message names the failing fixture + the exact regenerator tool to re-pin. Confirm
        an accidental (un-re-pinned) change makes the suite FAIL loudly (visible drift) — the whole point
        of the suite.
  - [x] Do NOT re-pin any EXISTING fingerprint unless you INTENTIONALLY changed a generator/system (you
        should not — this is a regression/readiness story that touches no generator); if a pin appears to
        drift, that is a BUG to investigate, not a value to update. The suite must reproduce every existing
        per-system fingerprint byte-identically.

- [x] **Task 6 — Cross-check, invariant re-verification, and gate handoff (AC1–AC4)**
  - [x] Run the full headless suite via PowerShell (the `godot` binary is NOT on the Bash/`where` PATH —
        it resolves via `C:\Users\Rasmus\bin\godot.cmd` / the console binary):
        `godot --headless --path C:\Sealsworn\godot --scene res://tests/headless/test_runner.tscn
        --quit-after 10`. Apply the false-PASS grep guard: grep the RAW runner output; the SIX documented
        stderr negatives (int64-overflow ×2, malformed-JSON ×3, `invalid_node_type` ×1) still PASS and
        MUST NOT be mis-cited as a regression. The suite outcome must stay green (the 10.1-close baseline
        of **183 PASS / 0 `^FAIL`** plus this story's own new passing regression test(s)).
  - [x] Verify NO determinism/save invariant moved: `run_snapshot.gd` (23-key gate stays 23),
        `rng_stream_set.gd` (`required_streams()` == 7), `profile_snapshot.gd` / `settings_snapshot.gd`
        (`SCHEMA_VERSION == 1`), every existing `tools/dump_*` UNTOUCHED, every level/route/finale
        fingerprint byte-identical, the DEFAULT deterministic paths byte-identical. Confirm `git diff
        --check` is clean and no production `godot/` gameplay/save/RNG/content file was touched (only new
        test(s) + an optional `tools/` report driver + the readiness note/section).
  - [x] Record the gate handoff: the consolidated suite + its sample-size gap ledger is a direct input to
        **10.6 (MVP Readiness Gate)** — 10.6 decides whether a still-temporary sub-target sample is an
        acceptable documented readiness LIMITATION or a hard blocker. Cross-reference 10.3 (Generator
        Soft-Lock and Fairness Batch Checks — the sibling generator-batch story that runs the fairness
        half over Small/Medium seeds; keep the seed catalogs compatible so the two harnesses share seeds).
        Do NOT implement 10.3's or 10.6's content here.

## Dev Notes

### What this story is (and is not)

Epics 1–11 shipped a complete, headless, deterministic domain with per-system seed-regression coverage
grown story-by-story: the 3.7 Small+Medium batch (the first full-`generate` pin), the 4.2 route fixtures
(the first `map`-stream pin), the 9.5 finale chain (the boss composite), the 2.8
interrupted==uninterrupted proof, and the reward/affinity per-seed determinism spot checks. Story 10.1
then added the performance-measurement harness. What the project has NEVER had is a **single CONSOLIDATED
seed regression suite** that reports one uniform `fingerprint + pass/fail + seed/system/phase/reason`
contract across all six named systems, states the MVP-readiness seed-sample sizes, and records the
current-vs-target sample gap for the readiness gate. **Story 10.2 is the paper-plus-harness that closes
that gap** — the seed-determinism analog of 10.1.

The single most important discipline (mirroring 10.1 and the 3.7/4.2 "no second pinning path"
cross-checks): **CONSOLIDATE and COVER the existing deterministic systems under one reporting contract;
do NOT fork a parallel fingerprint format, and do NOT silently expand into a gameplay change.** The
simulation is untouched; the systems are already deterministic; this story proves and reports that
determinism uniformly and records the honest sample-size gap.

### The sample-size reality (why sub-target samples are availability gaps, not blockers)

- AC2 was written to be dischargeable WITHOUT reaching every target in one pass: it names the FINAL target
  sample AND explicitly says "any smaller pre-MVP sample is marked as temporary and cannot pass final MVP
  readiness without approved de-scope." So a legitimate autonomous outcome is: STATE the seven targets,
  EXPAND the samples toward target where the expansion is a mechanical seed-list-plus-pin extension of an
  existing harness (cheap, high-value, zero gameplay risk), and record every still-sub-target sample as an
  explicit `temporary (N of TARGET) → sample-expansion pass / 10.6 de-scope decision` note.
- This is the SAME honesty posture 10.1 used for physical-device numbers (record the gap against an owner
  rather than fabricate the measurement). The gate story (10.6) is where the project decides whether a
  still-open sample gap is an acceptable documented readiness LIMITATION or must be discharged by a
  sample-expansion pass before MVP-readiness passes. 10.2's job is to make each gap explicit +
  dischargeable + to move the samples meaningfully toward target where mechanical, not to force every
  target in one story.
- **Do NOT fabricate coverage.** A pinned fingerprint must come from an ACTUAL live run through the
  system's canonical source (regenerated via the matching `tools/dump_*`), never hand-typed to hit a
  count. A sub-target sample presented as if it met the bar is an AC2 failure. **Do NOT stop and ask a
  human** — the story is completable and valuable via the consolidated suite + the honest gap ledger +
  whatever mechanical expansion is low-risk.

### Existing regression infrastructure to REUSE (do not reinvent)

Read these before authoring the consolidated suite; the pinned facts are load-bearing (a suite that forks
a parallel fingerprint format or duplicates a catalog into a second silently-drifting file is a review
miss):

| System | Canonical regression surface | Fingerprint source / regenerator | Current sample |
|---|---|---|---|
| Generation (Small/Medium) | `godot/tests/unit/generation/test_seed_batch_regression.gd` (full-`generate` batch + `_catalog_fingerprints_agree_with_generate_layout`); `test_small_level_layout_seed_regression.gd` / `test_medium_level_layout_seed_regression.gd` (layout pins) | `SmallLevelLayoutGenerator.fingerprint` / `MediumLevelLayoutGenerator.fingerprint`; `tools/dump_seed_batch_report.gd`, `dump_small_layout_fingerprints.gd`, `dump_medium_layout_fingerprints.gd` | 5 Small + 5 Medium (seeds 1001/2002/3003/4004/5005) |
| Route | `godot/tests/unit/generation/test_route_generation_seed_regression.gd` (+ `_fingerprint_helper_cross_checks_live_route`) | `RouteGenerator.fingerprint`; `tools/dump_route_fingerprints.gd` | 8 route seeds |
| Boss/finale | `godot/tests/integration/finale/test_finale_seed_regression.gd` (the 9.5 composite setup/phase/telegraph/victory/defeat chain — INLINE catalog, no `dump_*` because the arena is fixed + the AI is ZERO-RNG) | live composite cross-checked for reproducibility (no layout fingerprint) | 5 boss seeds (4242/1/7777/9e18/314159) |
| Reward/passive | `godot/tests/unit/run/test_reward_offer_generate.gd` (per-seed deterministic 3-choice passive / gold offer via the `rewards` stream) | `RewardOfferBuilder`/offer payload determinism (per-seed byte-identical) | per-seed spot checks |
| Affinity | `godot/tests/unit/run/test_affinity_assignment.gd` (per-seed deterministic `map`-stream assignment) | `RunOrchestrator.assign_affinity` reproducibility (implemented affinities: Scorched / Flooded-Conductive / Cursed / Darkness, FR56) | per-seed spot checks |
| Tactical (command/board) | Epic-1 command tests + `test_board_state.gd` / `test_board_fixtures.gd` + the 2.8 `test_resume_flow.gd` applied-event-log + board-snapshot determinism | `BoardState.to_snapshot()` + the ordered applied-`DomainEvent` log (compose `BoardFixtureFactory` boards + committed events — the 2.8 pattern) | (proved across command tests; no consolidated seed catalog yet) |
| Pause/resume + RNG | `godot/tests/integration/save/test_resume_flow.gd` (2.8 interrupted==uninterrupted; board + event log + RNG snapshot + next-draw + first-divergence locators); `godot/tests/unit/core/test_rng_stream_set.gd` (per-stream isolation + snapshot/restore) | `RngStreamSet.to_snapshot()` / `try_restore` / `required_streams()`; the `_first_divergent_event_index` / `_first_divergent_rng_stream` helpers | canonical — reuse as-is |

### The "no second fingerprint format" discipline (the crux of AC1/AC4)

- Every one of the six systems ALREADY has a single canonical fingerprint/determinism source. The
  consolidated suite must CALL those sources. The 3.7 batch and 4.2 route tests both enforce this with an
  explicit cross-check (`_catalog_fingerprints_agree_with_generate_layout` /
  `_fingerprint_helper_cross_checks_live_route`) proving there is "no second pinning path that can
  silently diverge." Apply the same: if the consolidated suite pins any value, it cross-checks that value
  against the live per-system source IN THE SAME TEST. A parallel fingerprint format is the single most
  likely review miss on this story.
- The finale is the one system with no layout fingerprint (fixed arena + ZERO-RNG AI) — its "fingerprint"
  is a live COMPOSITE of the deterministic setup/phase/telegraph/victory/defeat records computed and
  cross-checked for reproducibility (`test_finale_seed_regression.gd`). Consolidate it by
  invoking/asserting that same composite, not by inventing a new one.

### JSON int→float footgun (retro §9-1 — a ratified epic convention)

For ANY event/snapshot JSON round-trip in a fingerprint or determinism assertion, assert the SURVIVING
TYPED fields after `JSON.parse_string` (e.g. `int(parsed.final_hp) == 0`, `String(parsed.outcome) ==
"victory"`), NEVER a nested byte-identical re-stringify of a parsed object — JSON coerces all numbers to
doubles, so a naive re-stringify can spuriously "diverge" on an int-vs-float transport artifact that is
NOT a real regression. The 2.8 `test_resume_flow.gd` handles this by normalizing BOTH logs through the
same JSON round-trip (`_json_normalized`) before comparing; the 9.5 finale suite handles it by asserting
surviving typed fields. Follow whichever the surface calls for; do NOT introduce a comparison that trips
the footgun.

### Retro forward-prep folded in (Epic-11 retro → Epic-10, this story's slice)

Epic 11 is the most recently closed epic; its retrospective (`epic-11-retro-2026-07-06.md`) forward
sections (§7 "Next-Epic Preview — Epic 10", §8 Action Items, §9 Readiness, §10) are the epic-transition
prep for Epic 10. Story 10.1's Dev Notes already distilled these; the items that bear on THIS story:

- **Reuse harnesses, don't rebuild (retro §7 point 5 / Action T-series).** The retro's explicit direction
  for Epic 10's measurement/REGRESSION stories is to EXTEND the existing harnesses (the `tools/dump_*`
  surveys, the 9.5 batch model, the 3.7 batch, the 4.2 route fixtures, `LocalTimingRecorder`,
  `Epic1MicroCombatScenario`) rather than author parallel ones. 10.2's consolidated suite composes the
  existing per-system regression surfaces above — do NOT fork a new fingerprint/reporting primitive.
- **Every determinism/save invariant Epic 10 audits is intact and must stay so (retro §7 point 3, §9).**
  7 named RNG streams, ZERO new RNG draw sites, the 23-key `RunSnapshot` gate at 23,
  `ProfileSnapshot`/`SettingsSnapshot` `SCHEMA_VERSION == 1`, every generator/route/finale fingerprint
  byte-identical, the DEFAULT deterministic paths byte-identical, the suite green. 10.2 is a
  regression/readiness story — it MUST NOT move any of these; it PROVES they hold. Any harness code is
  read-only and draws no gameplay RNG.
- **NO "fail-loud gate/check on a new table → register/extend it" heads-up applies to THIS story.** That
  Epic-transition head-up concerns CODE stories that add events / content families / save keys (the
  `expected_ids` exhaustiveness pins, the schema-key gates). 10.2 adds none of that — no new event, no
  `expected_ids` pin, no schema key, no fingerprint INTENTIONALLY changed. Do NOT go looking for a table
  to extend or a fail-loud gate to register. (Recorded so the dev agent doesn't hunt for one, per the
  discipline 10.1/11.1 used.)
- **Status-hygiene finalize step is orchestrator-owned, not 10.2's (retro §7 point 6 / Action P1/P2).**
  The atomic finalize (story `Status:` + the `sprint-status.yaml` entry + any doc commit as one unit with
  the merge) is the orchestrator's git/finalize scope; the delegate never runs git. On disk at authoring
  time `sprint-status.yaml` shows `10-1-...: done` and `10-2-...: backlog` — this story creation flips
  10-2 to `ready-for-dev`; the dev/finalize flow owns the rest.
- **The "playable" framing + the deferred tap-loop (retro §7 point 1, §10) is 10.4/10.6/Epic-12
  territory, NOT 10.2's.** 10.2 is a HEADLESS seed-regression suite — it measures determinism of the
  domain/generation/boss systems under the existing deterministic (auto-resolve / scripted) paths. It does
  NOT need the interactive tap-loop or a winnable hero path (those gate 10.4's hands-on sessions + 10.6's
  "die or win" loop gate via Epic 12, per the 2026-07-07 sprint change). Recorded so 10.2 is not blocked
  on an Epic-12 prerequisite it does not have. (10.2 is one of the three Epic-10 stories — 10.1/10.2/10.3
  — explicitly INDEPENDENT of Epics 11 & 12 per the epics.md sequencing notes.)

### Epic-10 in-epic constraint surfaced by 10.1 (the immediately-prior story)

From `_bmad-output/auto-gds/retro-notes/epic-10.md` (§ Story 10.1): `export_presets.cfg` on disk carries
THREE presets — Windows (`preset.0`), Android (`preset.1`), AND an iOS scaffold (`preset.2`,
`runnable=false`, empty signing/icons) — NOT just Windows+Android as some Dev Notes assumed. All three
share the identical `exclude_filter` excluding `tools/**`, `tests/**`, and `**/test_*.gd`. **Load-bearing
for THIS story:** any `tools/dump_seed_regression_report.gd` report driver + any `test_*.gd` the story
adds is PROVABLY excluded from every export preset (it cannot ship in a production build) — the same AC5
evidence 10.1 relied on, and the reason a `tools/` report driver + a `tests/` regression suite are the
correct homes for this readiness work. iOS packaging remains a deferred availability gap (macOS/Xcode),
irrelevant to 10.2's headless scope but noted so the export-filter fact is cited correctly.

### Deferred-work overlaps (folded in — only entries touching THIS story's surface)

From `_bmad-output/implementation-artifacts/deferred-work.md` (a project-wide ledger; most entries are out
of scope). Checked every open entry against 10.2's seed-regression / determinism-suite / fingerprint
surface:

- **NONE of the open deferred-work entries overlap this story's subject.** The open ledger items are all
  live-layer / content / save-shape / affinity work: the Necromancer/Shadeblade class-kit + its two
  profile-aware follow-ons (`hero_select_presenter` profile-awareness, `re_derive_kit`); the live
  discovery/echo/Seal-Fragment source; the live in-node board / pending-fight save + the seated
  Cursed-affinity rule-source re-derive-on-resume; the run-level event store + `outcome_or_cause` (the
  empty-events `RunSummary.build(run, [])` consequence); the Flooded `_placeholder` electric interaction
  (an Epic-10 readiness item, but owned by **10.7**'s asset/UX gate); the affinity-driven GENERATION
  modifier; the G4 settings view model (PARKED); the `OutpostRenderView` / `class_unlock_options` render
  efficiency. NONE concerns seed-regression coverage, deterministic fingerprints, sample sizes, or the
  pause/resume determinism proof.
- **Do NOT reopen or pre-empt any of them.** In particular, none of the open live-in-node-save /
  affinity-generation-modifier items changes any EXISTING deterministic fingerprint — they are FUTURE work
  behind unchanged fingerprints, so they do not affect 10.2's regression pins. Recorded here only to state
  the non-overlap explicitly (the "identify only the overlapping deferrals" discipline the create-story
  mandate requires). If a later story DOES change a generator (e.g. the affinity-driven generation
  modifier), IT re-pins the affected fingerprints in ITS PR via the DELIBERATE-UPDATE contract this suite
  enforces — that is the suite working as designed, not a 10.2 obligation.
- **Cross-story sample compatibility (NOT a deferral — a coordination note):** Story 10.3 (Generator
  Soft-Lock and Fairness Batch Checks) runs the fairness half over a batch of Small/Medium seeds, and
  Story 10.1's performance harness draws level-load over `[1001,2002,3003,4004,5005] × {small,medium}`.
  Keep 10.2's generation seed catalog COMPATIBLE with those (share the approved seeds where possible) so
  the three Epic-10 harnesses agree on the same seed set — the 10.1 doc §7 already records this
  compatibility intent for the level-load sample.

### Numbering caveat (avoid the wrong FR/NFR)

- 10.2's determinism grounding is the canonical implementation **NFR13** (`epics.md` line 190 —
  "Gameplay-affecting systems must be deterministic under seeded execution") and the Additional-Requirement
  seed-regression mandate ("Headless simulation should support seed regression runs, bot playtests, batch
  difficulty simulations"). The Epic-10 FR coverage is **FR30** (successful run-length target validated
  during MVP tuning) + **FR70** (playable-build preservation across readiness gates) — but 10.2's concrete
  deliverable is the seed-regression SUITE that protects NFR13 across the six systems, feeding the 10.6
  gate. Cite the canonical `epics.md` numbering; do NOT conflate with any design-time GDD NFR numbering.

### Project Structure Notes

- **Primary output location(s):**
  - The consolidated regression suite: a new `test_*.gd` under `godot/tests/integration/` (an
    integration-level cross-system regression is the right home; the finale suite already lives under
    `godot/tests/integration/finale/`). The headless runner auto-discovers `test_*.gd` under
    `res://tests/unit` and `res://tests/integration` only.
  - OPTIONAL report driver: `godot/tools/dump_seed_regression_report.gd` (the `dump_*` `SceneTree`
    precedent) — only if a re-pin / eyeball driver genuinely earns its place. NOT auto-discovered,
    excluded from every export preset (`tools/**`), print-only (no `user://` artifact, no progression).
  - Sample-size targets + gap ledger: a short section extending the 10.1 readiness doc
    (`_bmad-output/planning-artifacts/device-tiers-and-performance-budgets.md`) OR a sibling
    `_bmad-output/planning-artifacts/`-level regression-suite readiness note — the durable artifact the
    10.6 gate consumes. A planning artifact, NOT under `godot/`.
- **Do NOT touch:** any gameplay command / event / RNG stream / `RunSnapshot`/`ProfileSnapshot`/
  `SettingsSnapshot` schema / save key / generator or route or finale fingerprint SOURCE / view model /
  content definition; the existing per-system regression FIXTURES' pinned values (reproduce them
  byte-identically — a drift is a bug, not a re-pin); `prototype/` (frozen validation evidence); `_bmad/`
  (installer-managed). The suite READS these; it does not change them.
- **Naming/organization:** follow the project-context Code Organization rules — `tests/` and `tools/` are
  the correct homes for regression + report code; `snake_case` files, `PascalCase` classes,
  `UPPER_SNAKE_CASE` constants. Test files begin with `test_`; a `tools/` driver `extends SceneTree`.

### Project Context Rules

Extracted from `project-context.md` / `AGENTS.md` (the canonical rulebooks). The rules that bear on THIS
story:

- **Determinism is project-context law (NFR13; § Determinism / RNG rules).** "Gameplay-affecting systems
  must be deterministic under seeded execution." "Use named RNG streams for gameplay-affecting
  randomness" — the 7 streams (`map`/`level`/`combat`/`loot`/`rewards`/`events`/`cosmetic`); cosmetic
  randomness must not affect outcomes/rewards/achievements/progression. This suite PROVES those
  guarantees across the six systems and the pause/resume path.
- **Headless simulation is render/audio/scene-free (NFR14; § Testing / Headless rules).** "Headless
  simulation must run without rendering, audio, UI scenes, presentation nodes, or scene-tree-only state."
  Every regression fixture runs headlessly; no `SceneTree`/render/device dependency in the test (the
  `tools/` driver is a dev/CI `SceneTree` script, not a test and not shipped).
- **Actionable, compact diagnostics — never a raw dump (§ generator-validation discipline).** Generator
  validation "must report seed, phase, reason, and compact diagnostics — NEVER a full … dump." Apply the
  same to the regression report: `seed + system + phase + reason`, compact, actionable; NEVER a grid/board
  dump.
- **Save-truth boundary + versioned snapshots (NFR15/NFR16; § Save rules).** Save truth is versioned
  domain snapshots (the 23-key `RunSnapshot`, `ProfileSnapshot`/`SettingsSnapshot` `SCHEMA_VERSION == 1`),
  never serialized scene nodes; persistence flows through repositories. The pause/resume proof uses the
  REAL `SaveRepository` JSON transport + `RunResumeService.resume` (the 2.8 path) — do NOT read a
  presentation/combat log as source truth.
- **No cloud/telemetry/live-service dependency (NFR11; § Platform & Build rules).** The regression suite +
  any report driver stay local; no runtime telemetry/cloud call. Local print/report only. Debug/report
  tooling is `tools/`-gated and excluded from every export preset (the 10.1 AC5 evidence).
- **Deterministic-fixture DELIBERATE-UPDATE contract (the 3.7/4.2/9.5 ratified convention).** Pinned
  fingerprints change ONLY with an intentional system change re-pinned in the SAME PR via the matching
  `tools/dump_*`; NEVER hand-edited to silence a drift; the regression assert names the failing fixture +
  the regenerator. This is the AC4 contract and a codebase-wide convention every regression test already
  follows — mirror it verbatim.
- **Godot / testing (§ Testing rules).** Run the full suite via PowerShell (the `godot` binary is NOT on
  the Bash/`where` PATH — it resolves via `C:\Users\Rasmus\bin\godot.cmd` / the console binary):
  `godot --headless --path C:\Sealsworn\godot --scene res://tests/headless/test_runner.tscn
  --quit-after 10`. Apply the false-PASS grep guard: the SIX documented stderr negatives (int64-overflow
  ×2, malformed-JSON ×3, `invalid_node_type` ×1) still PASS and must not be mis-cited as a regression.
  This story must not change the suite outcome (**183 PASS / 0 `^FAIL`** at 10.1 close) beyond adding its
  own passing regression test(s).

### References

- **Story source (verbatim ACs):** `_bmad-output/planning-artifacts/epics.md` — Epic 10 §"Story 10.2:
  Headless Seed Regression Suite" (lines ~2402–2428). Epic 10 section header + sequencing notes (10.1–10.3
  independent of Epics 11/12): lines ~2361–2367. Epic 10 List entry + implementation notes (validates
  cross-cutting NFRs, headless seed runs, milestone gates): lines ~485–491.
- **Canonical NFRs / requirements (`epics.md`):** NFR13 (line 190 — deterministic under seeded execution
  — the CORE guarantee this suite protects), NFR14 (192 — headless render/audio/scene-free), NFR11 (186 —
  no cloud/live-service), NFR15/NFR16 (194/196 — versioned snapshot save truth + repositories); the
  Additional-Requirement seed-regression / batch-simulation mandate (lines ~228–229). FR30 (line 303 —
  Epic-10 run-length target) + FR70 (383 — Epic-10 playable-build preservation) are the Epic-10 FR
  coverage this readiness story sits under.
- **Existing per-system regression surfaces (READ before authoring the consolidated suite):**
  `godot/tests/unit/generation/test_seed_batch_regression.gd` (3.7 full-`generate` Small+Medium batch +
  the `_catalog_fingerprints_agree_with_generate_layout` no-second-path cross-check + the
  `_failure_report_shape_carries_seed_recipe_phase_reason` forced-failure shape),
  `test_small_level_layout_seed_regression.gd` / `test_medium_level_layout_seed_regression.gd` (layout
  pins), `godot/tests/unit/generation/test_route_generation_seed_regression.gd` (4.2 route pins + the
  `_fingerprint_helper_cross_checks_live_route` cross-check),
  `godot/tests/integration/finale/test_finale_seed_regression.gd` (9.5 boss composite chain + the int→float
  footgun handling), `godot/tests/unit/run/test_reward_offer_generate.gd` (rewards-stream per-seed
  determinism), `godot/tests/unit/run/test_affinity_assignment.gd` (`map`-stream per-seed affinity
  determinism), `godot/tests/integration/save/test_resume_flow.gd` (2.8 interrupted==uninterrupted proof +
  the `_first_divergent_event_index` / `_first_divergent_rng_stream` locators + `_json_normalized`),
  `godot/tests/unit/core/test_rng_stream_set.gd` (per-stream isolation + snapshot/restore + cosmetic
  independence).
- **Fingerprint sources + regenerators:** `godot/scripts/generation/level/small_level_layout_generator.gd`
  (`fingerprint`), `medium_level_layout_generator.gd` (`fingerprint`),
  `godot/scripts/generation/route/route_generator.gd` (`fingerprint`, `route_from_result`),
  `godot/scripts/core/state/rng_stream_set.gd` (`required_streams()` == 7, `to_snapshot`/`try_restore`);
  regenerators `godot/tools/dump_seed_batch_report.gd`, `dump_small_layout_fingerprints.gd`,
  `dump_medium_layout_fingerprints.gd`, `dump_route_fingerprints.gd`.
- **Prior-story precedent (the readiness-plus-harness analog — the closest sibling):**
  `_bmad-output/implementation-artifacts/10-1-device-tiers-and-performance-budgets.md` (the
  measure-what-you-can + record-honest-gaps + reuse-not-rebuild + build-profile/`tools`-gated harness
  discipline; its §7 records the 10.2 gate handoff + the shared level-load seed sample). The 10.1 doc:
  `_bmad-output/planning-artifacts/device-tiers-and-performance-budgets.md`.
- **Epic-11 retro (forward prep for Epic 10 — the epic-transition heads-ups):**
  `_bmad-output/implementation-artifacts/epic-11-retro-2026-07-06.md` §7 (reuse harnesses; invariants
  intact; the deferred tap-loop is 10.4/10.6/Epic-12, not 10.1/10.2/10.3), §8 (Action items — P1/P2 status
  hygiene are orchestrator-owned; T-series reuse existing harnesses), §9 (Readiness — every invariant
  held), §10 (planning drift — none of which blocks 10.2).
- **Epic-10 in-epic retro note (the immediately-prior story's surfaced constraint):**
  `_bmad-output/auto-gds/retro-notes/epic-10.md` § Story 10.1 (the three-preset `export_presets.cfg` with
  the identical `tools/**`+`tests/**`+`**/test_*.gd` exclude_filter — the AC-evidence that a `tools/`
  driver + `tests/` suite provably cannot ship).
- **Deferred-work ledger (checked for overlap — NONE overlaps this story's surface):**
  `_bmad-output/implementation-artifacts/deferred-work.md` (all open items are
  live-layer/content/save-shape/affinity, behind UNCHANGED fingerprints; the Flooded `_placeholder` → 10.7,
  the affinity-generation modifier → a later generation story — neither changes an existing regression pin
  in 10.2's scope).
- **Sibling Epic-10 readiness stories the suite feeds/coordinates with:** Story 10.3 (Generator Soft-Lock
  and Fairness Batch Checks — shares the Small/Medium seed catalog; the fairness half over the same seeds)
  and Story 10.6 (MVP Readiness Gate — consumes the consolidated suite + the sample-size gap ledger; owns
  the temporary-sample de-scope decision), `epics.md` lines ~2430–2456 / ~2530–2569.

## Dev Agent Record

### Context Reference

- Story file: `_bmad-output/implementation-artifacts/10-2-headless-seed-regression-suite.md` (this file — the
  comprehensive context the create-story step produced).
- Durable readiness artifact authored by this story: `_bmad-output/planning-artifacts/seed-regression-suite-readiness.md`.

### Agent Model Used

Opus 4.8 (1M context) — `claude-opus-4-8[1m]` (auto-gds dev-story delegate).

### Debug Log References

- Baseline full-suite run before any change: **183 PASS / 0 `^FAIL`**, "Headless tests passed." (the 10.1-close baseline).
- One RED iteration: the first consolidated-suite draft had a GDScript parse error — `String(seed_value)` where
  `seed_value` is an `int` (`No constructor of "String" matches the signature "String(int)"`). Fixed to
  `str(seed_value)`. No other parse issues.
- Final full-suite run: **184 PASS / 0 `^FAIL`**, "Headless tests passed." (183 baseline + the 1 new
  `test_seed_regression_suite.gd`). False-PASS grep guard applied: exactly the SIX documented stderr negatives
  present (int64-overflow ×2, malformed-JSON ×3, `invalid_node_type` ×1) — no new stderr errors from this story.
- Report driver run (`tools/dump_seed_regression_report.gd`): clean `[PASS] system / seed: fingerprint` across
  all six systems; generation/route fingerprints in the report match the pinned catalogs byte-for-byte.
- `git diff --check`: clean (only a harmless LF→CRLF line-ending warning on the story `.md`).

### Completion Notes List

- **AC1 (consolidated fingerprint + pass/fail across all six systems).** New
  `godot/tests/integration/test_seed_regression_suite.gd` drives EACH of the six systems (tactical, generation,
  route, reward/passive, affinity, boss) and asserts (a) a deterministic fingerprint from the system's SINGLE
  canonical source and (b) per-fixture pass/fail, with EVERY failure assert carrying
  `seed=%d system=%s phase=%s reason=%s` (compact, no grid dump). A forced-failure shape test
  (`_failure_report_shape_carries_seed_system_phase_reason`) proves the harness can never silently pass a regression.
- **NO second fingerprint format (the crux).** The suite REUSES the per-system fixtures' EXACT pinned constants
  by importing them (`test_seed_batch_regression.gd::APPROVED_SEED_CATALOG`,
  `test_route_generation_seed_regression.gd::APPROVED_FINGERPRINTS`,
  `test_finale_seed_regression.gd::APPROVED_BOSS_SEED_CATALOG`) — there is literally no second copy that can
  drift. It also invokes each per-system regression test in `_consolidated_pins_agree_with_live_canonical_sources`
  so the consolidated coverage is cross-checked against the live canonical sources.
- **AC2 (sample targets + honest gap ledger).** The seven MVP-readiness targets are stated verbatim in the suite
  header constant `MVP_READINESS_TARGETS` + asserted in `_mvp_readiness_targets_are_stated_and_current_sample_is_honest`,
  and recorded in the durable ledger `_bmad-output/planning-artifacts/seed-regression-suite-readiness.md` (§3).
  **Route was EXPANDED 8 → 20 (target MET)** — a mechanical seed-list-plus-pin extension in the canonical route
  fixture, every new value regenerated from `tools/dump_route_fingerprints.gd` (never hand-typed); the original 8
  pins are byte-identical (an ADD, not a re-pin). All other systems are recorded as explicit
  `temporary (N of TARGET) → owning action` gaps for the 10.6 gate. Generation Small/Medium are DELIBERATELY held
  at the shared `[1001,2002,3003,4004,5005]` catalog (compatible with the 10.1 level-load harness + the 10.3
  fairness batch — expanding in isolation would desync the three Epic-10 harnesses; the ledger records this as the
  coordinated call).
- **AC3 (pause/resume + cosmetic independence).** `_pause_resume_reproduces_uninterrupted_run_across_seed_sample`
  proves interrupted==uninterrupted over the REAL `SaveRepository` JSON write/read + `RunResumeService.resume`
  across `[424242,1,7777,2026,314159]` (board snapshot + ordered event log + gameplay RNG stream states +
  next-draw reproduction, with first-divergence locators for both event index and stream name — not a bare
  boolean). It reuses the 2.8 harness shape (no new comparator) and the canonical 2.8 `test_resume_flow.gd` is
  ALSO covered via the cross-check. `_cosmetic_stream_draws_do_not_change_gameplay_outcomes` proves interleaving
  `cosmetic` draws changes no gameplay-stream value or snapshot across `[24680,1,7777,2026]`.
- **AC4 (deliberate-update / no silent drift).** Each regression assert names the failing fixture + the exact
  regenerator to re-pin; because the suite reuses the per-system pins, a re-pin lands in ONE place and the suite
  follows. `_deliberate_update_contract_is_recorded` asserts the regenerator tools exist. An accidental
  (un-re-pinned) generator change makes the suite FAIL loudly (the fingerprint asserts are the tripwire).
- **Report driver.** `godot/tools/dump_seed_regression_report.gd` (`extends SceneTree`, tools/-gated, excluded
  from every export preset, print-only, no `user://` artifact, no progression) prints the consolidated
  `[PASS|FAIL] system / seed: fingerprint` report for eyeballing / re-pinning. It earns its place as the human
  companion to the suite (the closest sibling `dump_seed_batch_report.gd` covers only generation).
- **Invariants intact.** Touched NO production `godot/` gameplay/save/RNG/content source: the changes are the new
  test suite + the route-fixture sample expansion + the new/updated `tools/` drivers + the planning docs. The 7
  RNG streams, 23-key `RunSnapshot` gate, `SCHEMA_VERSION == 1`, and every generator/route/finale fingerprint
  SOURCE are byte-identical; the suite PROVES they hold.
- **Reconciliation note (Task 3 vs Task 6 phrasing).** Task 6's "every existing `tools/dump_*` UNTOUCHED" is in
  tension with Task 3's explicit sanction to expand "more route seeds via `dump_route_fingerprints.gd`." Task 3
  (the more specific instruction for the route expansion) governs: `dump_route_fingerprints.gd` was intentionally
  extended (8 → 20 seed list) to regenerate the authoritative route pins. This is the sanctioned mechanical
  expansion, not a drift; the other three `dump_*` tools are untouched.

### File List

- `godot/tests/integration/test_seed_regression_suite.gd` (NEW) — the consolidated six-system seed-regression suite.
- `godot/tools/dump_seed_regression_report.gd` (NEW) — the tools/-gated consolidated report driver.
- `_bmad-output/planning-artifacts/seed-regression-suite-readiness.md` (NEW) — the MVP-readiness sample ledger + 10.6 handoff.
- `godot/tests/unit/generation/test_route_generation_seed_regression.gd` (MODIFIED) — route sample expanded 8 → 20 (canonical route pin location; the 12 new values regenerated from the dump tool; original 8 unchanged).
- `godot/tools/dump_route_fingerprints.gd` (MODIFIED) — seed list expanded 8 → 20 to regenerate the authoritative route fingerprints.
- `_bmad-output/planning-artifacts/device-tiers-and-performance-budgets.md` (MODIFIED) — §7 reciprocal cross-reference noting 10.2 shipped + holds generation at the shared catalog.
- `_bmad-output/implementation-artifacts/sprint-status.yaml` (MODIFIED) — `10-2` → in-progress → review; `last_updated` refreshed.

## Change Log

| Date | Change |
|---|---|
| 2026-07-07 | Story 10.2 context created (create-story). Consolidated-headless-seed-regression-suite scope framed as the seed-determinism analog of 10.1: CONSOLIDATE + report the six existing per-system deterministic surfaces (tactical/generation/route/reward/affinity/boss) under one `fingerprint + pass/fail + seed/system/phase/reason` contract, cover the 2.8 pause/resume interrupted==uninterrupted proof + cosmetic independence, state the AC2 MVP-readiness sample targets and record the current-vs-target sample gap as a 10.6-owned honest-scope ledger, enforce the ratified DELIBERATE-UPDATE no-silent-drift + no-second-fingerprint-format + int→float-footgun conventions, and leave every determinism/save invariant (7 RNG streams, 23-key RunSnapshot, SCHEMA_VERSION==1, all fingerprints) byte-identical. Status → ready-for-dev. |
| 2026-07-07 | Story 10.2 implemented (dev-story). NEW consolidated suite `godot/tests/integration/test_seed_regression_suite.gd` drives all six systems under one `fingerprint + pass/fail + seed/system/phase/reason` contract (reusing each system's SINGLE canonical source + the per-system pinned catalogs by IMPORT — no second format), a forced-failure shape test, the pause/resume-in-simulation proof across a seed sample (real SaveRepository + RunResumeService, first-divergence locators), and cosmetic-stream independence. AC2: route sample EXPANDED 8 → 20 (target MET, regenerated via `dump_route_fingerprints.gd`, original 8 unchanged); all other systems recorded as explicit temporary-sample gaps in the NEW readiness ledger `_bmad-output/planning-artifacts/seed-regression-suite-readiness.md` (10.6-owned). NEW tools/-gated report driver `godot/tools/dump_seed_regression_report.gd`. No production gameplay/save/RNG/content source touched; every determinism/save invariant byte-identical. Full suite 183 → 184 PASS / 0 `^FAIL`. Status → review. |
