# Headless Seed Regression Suite — MVP Readiness Ledger

> **Story:** 10.2 (Headless Seed Regression Suite) · **Epic:** 10 (Playtest Tuning and MVP Readiness)
> **Type:** Regression-consolidation / readiness artifact (the seed-determinism analog of 10.1's
> device-tiers/performance-budgets plan — consolidate + report the existing per-system deterministic
> surfaces under one contract, state the MVP-readiness sample targets, record the current-vs-target gap for
> the readiness gate; touch no simulation).
> **Status:** authored 2026-07-07 · protects the canonical **NFR13** (deterministic-under-seeded-execution)
> across the six named systems; feeds the **10.6** MVP Readiness Gate.

## 1. Purpose and Scope

Epics 1–11 grew strong PER-SYSTEM seed-regression coverage story-by-story (the 3.7 Small+Medium generate
batch, the 4.2 route fixtures, the 9.5 finale chain, the 2.8 interrupted==uninterrupted proof, the
reward/affinity per-seed determinism spot checks). What the project never had is a **single CONSOLIDATED
headless seed regression surface** that reports one uniform `fingerprint + pass/fail + seed/system/phase/reason`
contract across all six named systems (tactical, generation, route, reward/passive, affinity, boss), covers
the pause/resume-in-simulation proof + cosmetic-stream independence, states the MVP-readiness seed-sample
sizes, and records the current-vs-target sample gap for the readiness gate. Story 10.2 builds that surface.

**In scope (what 10.2 delivers):**

1. The consolidated regression suite `godot/tests/integration/test_seed_regression_suite.gd` — drives each of
   the six systems' approved fixtures under one uniform four-field failure contract, calling each system's
   SINGLE canonical fingerprint/determinism source (no second format), plus a forced-failure shape test.
2. The pause/resume-in-simulation determinism proof (over the real `SaveRepository` + `RunResumeService`,
   with first-divergence locators) asserted across a seed sample, plus the cosmetic-stream-independence
   assertion — both consolidated into the readiness regression set.
3. The optional report driver `godot/tools/dump_seed_regression_report.gd` — the human-eyeball / re-pin
   companion that prints `[PASS|FAIL] system / seed: fingerprint` across all six systems (tools/-gated,
   excluded from every export preset, print-only).
4. This readiness ledger — the seven MVP-readiness sample-size targets stated verbatim + the current-vs-target
   gap per system + the 10.6 gate handoff.

**Out of scope (explicitly NOT this story):** any change to a gameplay command, event, RNG stream,
`RunSnapshot` / `ProfileSnapshot` / `SettingsSnapshot` schema, save key, generator / route / finale
fingerprint SOURCE, view model, or content definition. The full headless suite stays green and behaviorally
byte-identical; this story adds a read-only regression suite + a tools/ report driver + this planning doc.
It does NOT implement 10.3's fairness-batch content or 10.6's gate decision.

## 2. The Six Systems and Their Single Canonical Fingerprint Sources (AC1)

The consolidated suite CALLS each system's canonical source and, where that system already pins values in its
own fixture, REUSES that fixture's exact pinned constant (imported, not copied) so there is no second pinning
path that can silently diverge — the strongest form of the 3.7 / 4.2 "no second pinning path" cross-check.

| System | Canonical source / determinism surface | Pinned catalog reused | Regenerator |
|---|---|---|---|
| Generation (Small/Medium) | `SmallLevelLayoutGenerator.fingerprint` / `MediumLevelLayoutGenerator.fingerprint` | `test_seed_batch_regression.gd::APPROVED_SEED_CATALOG` | `tools/dump_seed_batch_report.gd`, `dump_small_layout_fingerprints.gd`, `dump_medium_layout_fingerprints.gd` |
| Route | `RouteGenerator.fingerprint` | `test_route_generation_seed_regression.gd::APPROVED_FINGERPRINTS` | `tools/dump_route_fingerprints.gd` |
| Boss/finale | live setup composite (fixed arena + ZERO-RNG AI — no layout fingerprint) | `test_finale_seed_regression.gd::APPROVED_BOSS_SEED_CATALOG` | inline catalog (no `dump_*` — arena fixed, AI ZERO-RNG) |
| Reward/passive | per-seed offer payload via `RunOrchestrator.generate_reward_offer` / `generate_passive_reward_offer` (`rewards` stream) | suite's `REWARD_SEED_SAMPLE` (per-seed determinism) | n/a (per-seed determinism, not a pinned fingerprint) |
| Affinity | selected id via `RunOrchestrator.assign_affinity` (`map` stream; implemented affinities Scorched / Flooded-Conductive / Cursed / Darkness per FR56) | suite's `AFFINITY_SEED_SAMPLE` (per-seed determinism) | n/a (per-seed determinism) |
| Tactical (command/board) | `BoardState.to_snapshot()` + ordered applied-`DomainEvent` log composite (the 2.8 pattern) | suite's tactical seed sample (per-seed determinism) | n/a (per-seed determinism) |

The pause/resume proof reuses `test_resume_flow.gd`'s canonical harness shape (`RngStreamSet.to_snapshot()` /
`try_restore` + the `_first_divergent_event_index` / `_first_divergent_rng_stream` locators + `_json_normalized`),
asserted across a seed sample. Cosmetic independence reuses the Story 1.4 per-stream isolation guarantee.

## 3. MVP-Readiness Seed-Sample Targets (AC2) and the Current-vs-Target Gap Ledger

The seven FINAL target sample sizes are stated verbatim from AC2. **Story 10.8 (2026-07-07) DISCHARGED every
headless-mechanical sample target** via a coordinated additive expansion (see the Status column). The "current"
column is the sample the consolidated suite ACTUALLY drives (read live from the imported catalogs + the suite's
own samples — never a fabricated count; the honest-sample assertion asserts each MET target live).

| System | AC2 target | Current sample | Status | Owning action |
|---|---|---|---|---|
| Tactical command/board | ≥ 25 fixtures | **25** fixtures (`TACTICAL_SEED_SAMPLE` in the consolidated suite) + the broad Epic-1 command/board test corpus | **MET** (Story 10.8, 2026-07-07 — grown 8 → 25 per-seed command/board fixtures; per-seed determinism, no pinned-fingerprint format so no re-pin) | none |
| Small level seeds | 50 | **50** (original 1001/2002/3003/4004/5005 + 45 appended) | **MET** (Story 10.8, 2026-07-07 — COORDINATED 5 → 50 across the three Epic-10 harnesses via `tools/dump_small_layout_fingerprints.gd`/`dump_seed_batch_report.gd`; original 5 pins byte-identical) | none |
| Medium level seeds | 50 | **50** (original 1001/2002/3003/4004/5005 + 45 appended) | **MET** (Story 10.8, 2026-07-07 — COORDINATED 5 → 50 via `tools/dump_medium_layout_fingerprints.gd`/`dump_seed_batch_report.gd`; original 5 pins byte-identical) | none |
| Route seeds | 20 | **20** (the original 8 + 12 added by 10.2) | **MET** | none — reached target via the 10.2 mechanical expansion in `test_route_generation_seed_regression.gd` |
| Reward/passive seeds | 20 | **20** (8 historical + 12 appended) | **MET** (Story 10.8, 2026-07-07 — grown 8 → 20 per-seed cases in `REWARD_SEED_SAMPLE`) | none |
| Per implemented affinity | 10 each | **10 each** on Scorched / Flooded-Conductive / Cursed / Darkness (a curated 40-seed `AFFINITY_SEED_SAMPLE`; per-affinity membership documented in `AFFINITY_SEED_BY_AFFINITY` + proven live) | **MET** (Story 10.8, 2026-07-07 — targeted-seed search; `_affinity_sample_lands_ten_on_each_implemented_affinity` proves each implemented affinity gets ≥ 10 live-verified seeds, incl. Flooded-Conductive + Darkness) | none |
| Boss/finale seeds | 10 | **10** (original 4242/1/7777/9e18/314159 + 2026/777/88888/271828/999999937) | **MET** (Story 10.8, 2026-07-07 — grown 5 → 10 in `test_finale_seed_regression.gd::APPROVED_BOSS_SEED_CATALOG`, annotated per the preserved-catalog discipline; no dump tool — fixed arena + ZERO-RNG AI, composites from live runs) | none |

**All headless-mechanical sample targets are now MET (Story 10.8, 2026-07-07).** The remaining readiness gaps
are the **G1–G7 physical-device sample passes** (sustained on-device FPS, real-touch latency, iOS packaging,
etc.) — those are NOT sample-size gaps and stay **10.6-owned** (they require physical hardware a headless run
cannot exercise). Every count in the table is read LIVE from the catalog by the suite's honest-sample assertion,
so a silently-shrunk sample fails LOUD. Every pinned value came from an ACTUAL live run / sanctioned dump —
none is hand-typed to hit a count.

**Generation Small/Medium were held at 5 through 10.2, then expanded to 50 by 10.8 (the coordinated call):** the
10.1 level-load harness + the 10.3 fairness batch BOTH draw the shared catalog; expanding generation in isolation
would desync the three Epic-10 harnesses. Story 10.8 performed the correct COORDINATED 5 → 50 expansion across all
three (`tools/dump_performance_budgets.gd::LEVEL_LOAD_SEEDS`, `test_seed_batch_regression.gd::APPROVED_SEED_CATALOG`
imported by this suite, `test_generator_fairness_batch.gd::BATCH_SEEDS`), regenerated ONLY via the sanctioned
`tools/dump_*` drivers AFTER 10.8's moving-LoS predicate change so the fairness verdicts are final, with the
original 5+5 pins byte-identical.

## 4. Pause/Resume Determinism + Cosmetic Independence (AC3)

- **Pause/resume-in-simulation:** a run is saved → restored through the REAL `SaveRepository` JSON write/read +
  `RunResumeService.resume` → given the identical remaining command sequence, it reproduces the byte-identical
  final board snapshot + ordered event log + gameplay RNG stream states as the uninterrupted path. Divergence
  is reported by a FIRST-divergence locator (event index / stream name), never a bare boolean, and the
  strongest proof (both paths reproduce the exact next draw on every stream) is asserted. The consolidated
  suite runs this across the seed sample `[424242, 1, 7777, 2026, 314159]` and also COVERS the canonical 2.8
  `test_resume_flow.gd` proof by invoking it in the cross-check (§2). No new comparator is introduced.
- **Cosmetic-stream independence:** interleaving `cosmetic`-stream draws around a gameplay draw does NOT change
  any gameplay-stream outcome (the Story 1.4 AC2 guarantee). The suite asserts identical gameplay-stream VALUES
  and gameplay-stream SNAPSHOTS with-vs-without interleaved cosmetic draws, across `[24680, 1, 7777, 2026]`.

## 5. Intentional-Change Discipline / No Silent Drift (AC4)

- Every pinned fingerprint the suite asserts carries the DELIBERATE-UPDATE contract: it changes ONLY with an
  INTENTIONAL generator/system change re-pinned in the SAME PR via the matching `tools/dump_*`; it is NEVER
  hand-edited to silence a drift. Because the suite REUSES the per-system fixtures' pinned constants, a re-pin
  lands in ONE place (the per-system fixture) and the consolidated suite follows automatically — it cannot
  disagree.
- Each regression assert names the failing fixture + the exact regenerator to re-pin (e.g. "re-pin via
  `tools/dump_route_fingerprints.gd` + `test_route_generation_seed_regression.gd` ONLY if intentional"). An
  accidental (un-re-pinned) generator change makes the suite FAIL loudly (visible drift) — the whole point.
- The forced-failure shape test proves the harness reports `seed + system + phase + reason` on a failure
  (never silently passes a regression).

## 6. Determinism / Save Invariants Respected

This regression/readiness story moves NONE of the pinned invariants — it PROVES they hold: the 7 named RNG
streams (`map` / `level` / `combat` / `loot` / `rewards` / `events` / `cosmetic`), zero new RNG draw sites,
the 23-key `RunSnapshot` gate, `ProfileSnapshot` / `SettingsSnapshot` `SCHEMA_VERSION == 1`, every
generator/route/finale fingerprint SOURCE, and the default deterministic paths stay byte-identical. The suite
+ the report driver are read-only over the domain, draw no gameplay RNG beyond what the exercised systems
already draw, and mutate no domain/save state. The full headless suite stays green (183 baseline → 184 with
this story's one new passing suite; the route fixture expansion 8 → 20 stays green with the original 8 pins
byte-identical).

## 7. Epic-10 Gate Handoff and Cross-References

- **10.6 (MVP Readiness Gate and Playable-Build Preservation).** Consumes the consolidated suite + this
  sample-size gap ledger (§3). **As of Story 10.8 (2026-07-07) every headless-mechanical sample target is MET**
  (tactical 25, Small 50, Medium 50, route 20, reward 20, per-affinity 10-each, boss 10), so 10.6 no longer
  decides these — it VERIFIES them. 10.6's residual sample surface is the **G1–G7 physical-device passes** (not
  sample-size gaps — they need hardware). See `sprint-change-proposal-2026-07-07-fr58.md`.
- **10.3 (Generator Soft-Lock and Fairness Batch Checks).** Runs the fairness half over a batch of Small/Medium
  seeds. 10.2 keeps its generation seed catalog COMPATIBLE (the shared `[1001,2002,3003,4004,5005]` set) so the
  two harnesses agree on seeds; a coordinated generation-sample expansion (toward the 50/50 target) should
  extend all three Epic-10 harnesses (10.1 level-load, 10.2 regression, 10.3 fairness) together. (10.3 shipped
  2026-07-07 — `godot/tests/integration/test_generator_fairness_batch.gd` + the ledger
  `generator-fairness-batch-readiness.md`; it draws the SAME 5+5 catalog, re-pins NO terrain fingerprint, and
  surfaced a Darkness FR58 `darkness_unseen_hazard` finding on Medium seeds 4004+5005 — see that ledger §4.)
- **10.1 (Device Tiers and Performance Budgets).** Its §7 records the shared level-load seed sample and the
  10.2 handoff; this doc is the reciprocal seed-determinism readiness artifact.

## 8. Change Log

| Date | Version | Change | Author |
|---|---|---|---|
| 2026-07-07 | 1.0 | Initial authoring — consolidated seed-regression suite across the six named systems under one `fingerprint + pass/fail + seed/system/phase/reason` contract (reusing each system's single canonical source + the per-system pinned catalogs, no second format); pause/resume-in-simulation proof + cosmetic independence consolidated; the seven MVP-readiness sample targets stated + the current-vs-target gap ledger recorded (route reached target via the 8→20 expansion; the rest recorded as temporary gaps for the 10.6 gate); the DELIBERATE-UPDATE / no-silent-drift discipline; the tools/-gated report driver. Protects NFR13; feeds 10.6. | Story 10.2 (dev agent) |
| 2026-07-07 | 1.1 | **Story 10.8 — §3 gap table DISCHARGED for every headless-mechanical target** via a coordinated additive expansion (AFTER 10.8's Part-A moving-LoS predicate change so verdicts are final): tactical 8→25 (`TACTICAL_SEED_SAMPLE`), Small 5→50 + Medium 5→50 (COORDINATED across the three Epic-10 harnesses via the sanctioned `tools/dump_*` drivers, original 5+5 pins byte-identical), reward 8→20 (`REWARD_SEED_SAMPLE`), per-affinity mixed-8 → 10-each on all four implemented affinities (curated `AFFINITY_SEED_SAMPLE` + `AFFINITY_SEED_BY_AFFINITY`, proven live by `_affinity_sample_lands_ten_on_each_implemented_affinity`), boss 5→10 (`APPROVED_BOSS_SEED_CATALOG`); route already 20/20 (untouched). The honest-sample assertion flipped from "temporary ≥ 5" tripwires to the DISCHARGED targets read live. The remaining G1–G7 physical-device gaps stay 10.6-owned. | Story 10.8 (dev agent) |
