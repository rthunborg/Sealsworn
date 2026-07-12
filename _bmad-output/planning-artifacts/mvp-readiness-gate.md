# MVP Readiness Gate and Playable-Build Preservation — Final Epic-10 Gate

> **Story:** 10.6 (MVP Readiness Gate and Playable Build Preservation) · **Epic:** 10 (Playtest Tuning and MVP Readiness)
> **Type:** Readiness / GATE artifact — the final roll-up gate (the direct sibling of 10.1 device-tiers, 10.4
> comprehension checklist, and 10.5 accessibility audit). It VERIFIES the live loop end-to-end, RUNS the full suite
> + pre-export validation, ROLLS UP the four sibling Epic-10 ledgers, and DECIDES each open gap. It touches no
> simulation.
> **Status:** authored 2026-07-10 · discharges **FR70** (playable-build preservation across readiness gates) +
> the **FR30** run-length gate half of the Epic-10 MVP-readiness mandate; consumes the four sibling readiness
> ledgers + the two audit docs.
> **10.6 is NOT the last story of Epic 10** (10-7 follows) — this is a mid-epic readiness story; no epic-end
> retrospective is triggered off it, and Epic 10 is NOT marked done here.

---

## 1. Purpose and Scope

**Purpose.** Epics 1-9 shipped a complete headless deterministic domain; Epic 11 wired the LIVE run-flow scenes +
hands-off loop; Epic 12 wired the INTERACTIVE hands-on tap-loop + a class-armed, winnable hero; the Epic-10 first
tranche (10-1/10-2/10-3/10-8) shipped the readiness measurement + consolidated regression + fairness harnesses;
10-4 shipped the comprehension checklist; 10-5 shipped the accessibility audit. **What the project never had is
the single FINAL MVP-readiness GATE that rolls all of it up** — verifies the loop is complete end-to-end, runs the
suite + pre-export validation, reviews every Epic-10 threshold, and dispositions every open gap for the preserved
build candidate. **Story 10.6 is that gate.** It discharges the FR70 playable-build-preservation + FR30
run-length-validation half of the Epic-10 readiness mandate.

**Scope (what this gate does — and does NOT do).**

- **VERIFY what can be verified now.** The full rough-loop smoke path against the LIVE, hands-on flow (AC1); the
  fresh full-suite run + the documented exceptions (AC2); the pre-export invariants against the SHIPPED evidence
  (AC3); the difficulty non-goal at the contract level (AC4).
- **DECIDE each open gap.** The G1-G7 physical-device gaps + the settings paper-audit gap (appendix §16 G4) + the
  developer-experience/coverage limitations, each dispositioned as "acceptable documented readiness limitation"
  vs "hard blocker", with an owner + target discharge path.
- **ROLL UP the four sibling Epic-10 ledgers** (10.1 device-tiers, 10.2 seed-regression, 10.3 fairness-batch,
  10.4 comprehension) + the two audit docs (10.5 accessibility, the 11.1 UX appendix), and **hand asset / audio /
  placeholder / UX readiness to 10.7** (the dedicated asset/UX gate — 10.6 notes the handoff, does not do 10.7's
  job).
- **PRESERVE a playable-build-candidate record** — build id/commit, suite summary, per-preset producibility,
  known limitations, de-scope notes (FR70).

> **This gate VERIFIES + DECIDES + ROLLS UP; it does NOT build features, fix deferrals, or change production
> code.** No gameplay command / event / RNG stream / `RunSnapshot`/`ProfileSnapshot`/`SettingsSnapshot` schema /
> save key / generator-route-finale fingerprint / seed-regression sample / view model / content definition /
> presenter / `.tscn` is changed. `export_presets.cfg` is READ, not modified. The full headless suite stays green
> and byte-for-byte behaviorally unchanged (**191 PASS / 0 `^FAIL`**, verified fresh in §4). No new test is added
> (see §5.5 — the pre-export/difficulty facts are already covered; a gate story records, it does not re-engineer).

### 1.1 The post-10.8 gate-scope shrink (VERIFY, don't re-decide)

The 2026-07-07 FR58/sample sprint change (Story 10.8) pulled two items OUT of this gate's DECISION surface — 10.6
now **VERIFIES** them rather than deciding them. [Source: `epics.md` §Story 10.6 "Gate-scope note (2026-07-07)";
`sprint-change-proposal-2026-07-07-fr58.md`]

| Item | 10.6 posture | Verified in |
|---|---|---|
| FR58 Darkness fairness (Medium 4004/5005) | **VERIFY** RESOLVED (moving-LoS "seen-before-contact" predicate; 0 generated-board Darkness failures, both recipes) | §7.3 |
| Headless-mechanical seed samples (Small/Medium 50, tactical 25, route 20, reward 20, boss 10, affinity 10-per-affinity) | **VERIFY** every target MET (honest-sample assertions pass live) | §7.2 |

### 1.2 Two DIFFERENT "G4"s — kept distinct throughout this gate

There are two independent gap-numbering schemes that both use the label "G4". This gate keeps them distinct:

- **Device-tiers §6 G4** = *no on-device / windowed render-frame profiler for sustained 60/30 FPS frame stability*
  (NFR6). One of the physical-device **G1-G7** gaps this gate decides (§8). [Source:
  `device-tiers-and-performance-budgets.md` §6]
- **UX appendix §16 G4** = *the settings VIEW MODEL / settings SCENE gap* (PARKED — Epic 11 built no settings
  scene; the outpost has no difficulty selector). The **settings paper-audit gap** (§6.2 / §8). [Source:
  `ux-appendix-run-flow.md` §16; `deferred-work.md` 10-5 review F-3]

The "G1-G7" label always means the device-tiers physical-device set; the settings-VM gap is always written
"appendix §16 G4 (settings)".

---

## 2. The verification reality (why physical-device + human passes are availability gaps, not blockers)

The ACs are dischargeable WITHOUT a physical-device lab, a signed mobile binary, or a human ship-sign-off, because
the loop is LIVE and testable, the suite is runnable, and the pre-export invariants are shipped + tested. The gate
legitimately produces: the per-step loop verification (grounded in the live drivers + the scene-load guardrail
§3), the fresh suite run + exceptions (§4), the pre-export validation (grounded in `test_export_setup.gd` + the
build-profile gating §5), the difficulty-non-goal confirmation (grounded in the regression test §6), the
four-ledger roll-up (§7), the gap-disposition ledger (§8), and the build-candidate manifest (§9).

This is the SAME honesty posture 10.1 used (record each gap against an owner rather than invent data), 10.4 used
(the ≥5 observed sessions → the gate), and 10.5 used (the human-eyes availability gaps → the gate). **10.6 is the
gate those handed their physical-device / human passes to — and its job is to DECIDE each is an acceptable
documented readiness LIMITATION for the offline-first v0 CANDIDATE (with an owner + target), NOT to run the device
lab itself.** The project-context rule that MAKES the human-hands-on-hardware pass a legitimate availability gap:
*"Human playtests remain required for feel, readability, frustration, and excitement"* (§ Testing Rules).

**The preserved build is a v0 CANDIDATE, not the final ship.** The physical-device passes are explicitly a
pre-ship follow-up (§8), not a hard blocker that stops this gate.

---

## 3. AC1 — The loop-completeness gate

**GIVEN all MVP epics have implementation marked complete, WHEN the readiness gate runs, THEN it verifies launch,
start run, choose class, generate or enter levels, fight, collect rewards, make passive choices, die or win, view
summary, and start another descent, AND any missing loop step blocks MVP readiness.**

The loop is now genuinely LIVE (Epic 11) + hands-on (Epic 12), so this is a real verification. For each of the ten
named steps below: the SHIPPED seam that satisfies it + the evidence. Verified via the existing headless
live/auto-play drivers (`RunOrchestrator.run_to_completion_live` / `auto_play_full_run` / `resolve_boss_victory` /
`begin_interactive_combat_node`) + the scene-load compile guardrail (`test_run_flow_scenes_load.gd`) + the finale
integration (`tests/integration/finale/`) — **no loop was rebuilt.**

| # | Loop step | Shipped seam | Evidence | Status |
|---|---|---|---|---|
| 1 | **launch** | `scenes/app/main.tscn` boots → `scenes/ui/hero_select.tscn` (Epic 11); `boot_controller` / `SceneManager` | `test_run_flow_scenes_load.gd` compiles + loads all 9 flow scenes + 8 presenters (a broken scene/presenter fails LOUD) | ✅ present |
| 2 | **start run** | `RunStartCommand` → `RunFlowController` / `RunFlowRouter` → `SceneManager`; the outpost `is_startable` / `start_run_request` seam (`outpost_view_model.gd:162-172`) | `test_live_run_flow.gd`; `test_run_flow_scenes_load.gd`; the run-flow controller drives start | ✅ present |
| 3 | **choose class** | `HeroSelectViewModel` (locked/selectable) + the class-kit → live-combat `CombatLoadout` (Epic 12) over `run.starting_kit` | `test_combat_loadout.gd` (each of warrior/pyromancer/ranger derives its loadout at baseline_hp 18); `test_hero_select_view_model.gd` | ✅ present |
| 4 | **generate or enter levels** | `NodeEnterCommand` + `LevelGenerator.generate` (the route↔level handoff inside `begin_interactive_combat_node` / `resolve_combat_node_live`); `route_map.tscn` | `test_live_run_flow.gd`; `test_seed_regression_suite.gd` + `test_generator_fairness_batch.gd` (generation determinism/fairness); `test_run_flow_scenes_load.gd` | ✅ present |
| 5 | **fight** | The INTERACTIVE tap-loop `InteractiveCombatSession` (one action per tap through `TacticalCommandBridge` / `TacticalAttackCommitFlow`) + the additive `begin_interactive_combat_node` / `finish_interactive_combat_node` seams (Epic 12); the headless auto-resolve `LiveCombatResolver` | `test_interactive_combat_session.gd`; `test_interactive_combat_flow.gd`; `test_live_combat_resolver.gd`; `test_reference_combat_driver.gd` (winnability proof, all 3 classes) | ✅ present |
| 6 | **collect rewards** | Epic-6 reward flow: `RunOrchestrator.generate_reward_offer` / `generate_passive_reward_offer` (`rewards` stream) → `RewardOfferBuilder`; the reward modal data contract | `test_loot_passive_build_smoke_run.gd`; `test_reward_offer.gd`; `test_reward_offer_builder.gd` | ⚠️ present (integration-proven; §3.3) |
| 7 | **make passive choices** | Consume vs Destroy: `ConsumePassiveCommand` / `DestroyPassiveCommand` + `PassiveRewardCommitFlow`; `PassiveRewardModalViewModel` | `test_consume_passive_command.gd`; `test_destroy_passive_command.gd`; `test_passive_reward_modal_view_model.gd` | ⚠️ present (integration-proven; §3.3) |
| 8 | **die or win** | Live hero DEATH → `PHASE_FAILED` via `run_to_completion_live` (`run_orchestrator.gd:1336`); boss VICTORY via `resolve_boss_victory` (`:826`, clears boss node + `resolve_run_end(victory)` → `PHASE_COMPLETED`) driven through the finale chain | `test_finale_full_run.gd` (full run → boss fight → victory/death through the shell); `test_finale_seed_regression.gd`; `test_live_run_flow.gd` | ✅ present |
| 9 | **view summary** | `RunSummary.build(run, ...)` (`run_summary.gd:199`) via `RunEndProfileBridge` (`scripts/ui/flow/run_end_profile_bridge.gd`) → the outpost run-end landing (`run_end.tscn` → `outpost.tscn`) | `test_run_summary.gd`; `test_meta_summary_save_load.gd`; `outpost_view_model.gd:239` builds the summary in the live flow | ⚠️ present but THIN (§3.1) |
| 10 | **start another descent** | The outpost `start_run_request` / `is_startable` seam (`outpost_view_model.gd:162-172`) → a fresh `RunStartCommand` (the loop closes) | `test_outpost_view_model.gd`; `test_live_run_flow.gd` (start → end → start) | ✅ present |

**Every named loop step is PRESENT.** No step is outright MISSING, so **no step BLOCKS MVP readiness** per the AC.
Three steps carry a present-but-qualified callout, each recorded as a known limitation (NOT a block): view summary
is present-but-thin (§3.1); collect rewards + make passive choices are present + integration-proven but
live-HUD-wiring-deferred (§3.3).

### 3.1 The known THIN-step limitation (recorded, not fixed) — the "view summary" step

The "view summary" step is present but the summary's `outcome_or_cause` stays **BLANK** and the passives / loot /
discovery fields are empty in the live flow: `RunEndProfileBridge` builds `RunSummary.build(run, [])` (an empty
event list), so the run-end review conveys the outcome NON-color via the SEPARATE reveal beats
(`FirstDeathNarrativeBeat` / `FirstVictoryRevealBeat`) + `phase` (`PHASE_COMPLETED` / `PHASE_FAILED`), never
`outcome_or_cause`. This is a **THIN-but-present** step (NOT a missing step — so it does NOT block AC1). No
run-level event STORE exists yet.

- **Disposition:** acceptable documented readiness limitation for the v0 candidate (the outcome IS conveyed
  non-color elsewhere; this is a readability-completeness gap, not a broken loop step).
- **Owner:** the run-level event-store / summary-render story (origin 11.5 code review; the F-2 / T4 deferral).
  Until events are threaded, a summary-render MUST key the outcome label off `phase`, not `outcome_or_cause`.
- **Cross-refs:** `accessibility-and-readability-audit.md` §4.11 / §5 F-2; `deferred-work.md` (F-2; T4 run-level
  event store). **NOT wired here.**

### 3.2 The hands-on-device walkthrough is an availability gap (not a block)

A human tapping the full loop on real hardware (the felt, hands-on device walkthrough) is recorded as an
availability gap → the G1-G7 physical-device pass owner (§8). The headless live/auto-play drivers + the scene-load
compile guardrail verify the loop's STRUCTURE + DETERMINISM now; the felt hands-on device pass is the
physical-device dimension, dispositioned in §8 as an acceptable documented limitation for the v0 candidate with a
pre-ship follow-up owner.

### 3.3 The caller-driven / live-HUD-wiring qualifier (recorded, not a block) — "collect rewards" + "make passive choices"

The "collect rewards" (row 6) and "make passive choices" (row 7) steps are genuinely PRESENT in the domain and
INTEGRATION-PROVEN end-to-end — `tests/integration/reward_flow/test_loot_passive_build_smoke_run.gd` clears a real
node, then generates a loot offer + a 3-choice passive offer and resolves EACH disposition through a real command
(`ResolveRewardCommand` / `PickupItemCommand` for loot; `ConsumePassiveCommand` / `DestroyPassiveCommand` for
passives). But that proof is CALLER-DRIVEN: per the harness's own header, "generate is caller-driven, NOT
auto-wired into `run_to_completion`", and the harness "constructs the commands DIRECTLY ... NOT a scene/HUD" — "the
HUD wiring of the commit-intent -> command call site is a later HUD story". So these two steps are integration-proven
in the domain, but NOT yet live-HUD-proven in the played flow — the same present-in-domain / thin-in-live-flow
distinction the view-summary step gets in §3.1 (they are PRESENT, not missing, so they do not BLOCK AC1).

- **Disposition:** acceptable documented readiness limitation for the v0 candidate — the steps are PRESENT +
  integration-proven (not missing → they do NOT block AC1); only the live-HUD/scene wiring is deferred. The overall
  verdict `READY_WITH_GATES` is unchanged.
- **Owner:** the reward/passive live-HUD-wiring story (a later HUD story, per the
  `test_loot_passive_build_smoke_run.gd` header).
- **Cross-refs:** `test_loot_passive_build_smoke_run.gd` header; the §8 gap-ledger row "Reward/passive live-HUD
  wiring". **NOT wired here.**

**AC1 verdict:** MET — every named step verified against its shipped seam + evidence; the present-but-qualified
steps recorded with their owners (view summary thin §3.1; collect rewards + make passive choices caller-driven /
live-HUD-wiring-deferred §3.3); no step missing (nothing blocks readiness); the hands-on-device pass recorded as a
G1-G7 gap.

---

## 4. AC2 — The final validation suite

**GIVEN relevant tests are available, WHEN the final validation suite runs, THEN command, RNG, board, fog, combat,
generation, save/load, passive, risk, meta, boss, and headless seed tests pass or have documented exceptions, AND
exceptions include risk and owner notes.**

### 4.1 The fresh full-suite run (read from the raw runner output — not fabricated)

Run fresh for this gate on the development desktop (Windows 11) at the gate build (§9), via PowerShell:

```
godot --headless --path C:\Sealsworn\godot --scene res://tests/headless/test_runner.tscn --quit-after 10
```

| Metric | Result |
|---|---|
| **PASS count** (`^PASS`) | **191** |
| **FAIL count** (`^FAIL`) | **0** |
| **Runner exit / signal** | exit 0; final line `Headless tests passed.` |
| **False-PASS grep guard** (`SCRIPT ERROR` / `Parse Error` / `^FAIL`) | **0 matches — clean** |
| **Wall-clock** | **~175 s** (2m55s) on this desktop (§4.3) |

The **191 PASS / 0 `^FAIL`** count matches the post-10.5 baseline exactly, confirming this gate changed the suite
by nothing (no test added, no pin moved). The false-PASS guard is clean: the JSON parse errors below are
`Parse JSON failed` (not `Parse Error`) and `ERROR:` (not `SCRIPT ERROR:`), so they do not trip the guard — they
are the documented, expected negatives (§4.2), not regressions.

### 4.2 The AC2 family mapping (each named family → the covering suites)

Every AC2-named test family is covered by shipped suites (a representative, not exhaustive, citation):

| AC2 family | Covering suites (representative) |
|---|---|
| **command** | `tests/unit/core/test_move_command.gd`, `test_attack_command.gd`, `test_node_enter_command.gd`, + the run-domain command tests; `tests/integration/test_epic_1_micro_combat_scenario.gd` |
| **RNG** | `tests/unit/core/test_rng_stream_set.gd` (the 7 named streams); cosmetic-independence + pause/resume determinism in `tests/integration/test_seed_regression_suite.gd` |
| **board** | `tests/unit/tactical/test_board_state.gd` + the `tests/unit/tactical/test_tactical_*` corpus; the board snapshot round-trip |
| **fog** | `tests/unit/tactical/test_tactical_visibility_query.gd` (line-of-sight), `test_darkness_visibility.gd` + `test_darkness_memory_uncertainty.gd` (fog / explored-memory + reduced-radius) |
| **combat** | `tests/unit/core/test_attack_command.gd`, `tests/unit/run/test_live_combat_resolver.gd`, `test_interactive_combat_session.gd`, `test_interactive_combat_flow.gd`, `tests/integration/test_epic_1_micro_combat_scenario.gd` |
| **generation** | `tests/integration/test_seed_regression_suite.gd`, `test_generator_fairness_batch.gd`, the `tests/unit/generation/**` generator + validator tests |
| **save/load** | `tests/integration/save/test_between_level_save.gd`, `test_meta_summary_save_load.gd`, `test_resume_flow.gd`; `tests/unit/save/test_run_snapshot.gd`, `test_save_repository.gd`, `test_run_resume_service.gd`, `test_profile_repository.gd`, `test_settings_repository.gd` |
| **passive** | `tests/unit/core/test_consume_passive_command.gd`, `test_destroy_passive_command.gd`; `tests/unit/ui/test_passive_reward_modal_view_model.gd` |
| **risk** | `tests/unit/run/test_risk_economy_state.gd`, `tests/unit/rules/test_curse_rule_resolution.gd`, `tests/unit/run/test_event_offer.gd` |
| **meta** | `tests/integration/save/test_meta_summary_save_load.gd`; `tests/unit/save/test_meta_award_rules.gd`, `test_unlock_progress_rules.gd`; `tests/unit/ui/test_outpost_view_model.gd` |
| **boss** | `tests/unit/ai/test_boss_ai.gd`, `tests/unit/content/test_boss_definition.gd`, `test_boss_phase_resolver.gd`, `test_boss_repository.gd`; `tests/integration/finale/test_finale_full_run.gd` |
| **headless seed** | `tests/integration/test_seed_regression_suite.gd`, `test_generator_fairness_batch.gd`, `tests/integration/finale/test_finale_seed_regression.gd` |

All families PASS. The consolidated `test_seed_regression_suite.gd` reports one uniform
`fingerprint + seed/system/phase/reason` contract across all six named systems (tactical / generation / route /
reward-passive / affinity / boss) + the pause/resume + cosmetic-independence proofs; `test_generator_fairness_batch.gd`
runs the FR36 soft-lock + FR58 Darkness-fairness half over the 50 Small + 50 Medium catalog.

### 4.3 The documented exceptions — the 6 stderr negatives (EACH with risk + owner)

The runner emits **6 documented stderr negatives** on a green run — these are DELIBERATE fail-path assertions
(malformed-input rejection + int64-overflow boundary + parse-failure `push_error`), NOT regressions. Each is
recorded here with its exact site, its risk, and its owner. All six were observed on this gate build, and the
suite still reports **191 PASS / 0 `^FAIL`** with them present.

| # | Negative (verbatim class) | Origin test (the deliberate fail-path assertion) | Risk | Owner |
|---|---|---|---|---|
| 1 | `int64-overflow` — "Cannot represent 99999999999999999999 as a 64-bit signed integer" (`_has_decimal_string_payload`, `domain_event.gd:2187`) | `tests/unit/core/test_domain_event.gd::_run_started_serializes_and_parses_stable_payload` — the lossless decimal-string-payload boundary | **None** — a deliberate boundary assertion proving the lossless-encoding rejects an out-of-int64 value; no state mutated | Domain-event serialization (pinned; no action) |
| 2 | `int64-overflow` — same message (`parse_seed`, `manual_seed_loader.gd:95`) | `tests/unit/generation/test_manual_seed_loader.gd::_parse_rejects_out_of_int64_range_decimal_string` — the manual-seed out-of-range reject | **None** — deliberate out-of-range seed rejection (structured, no crash) | Manual-seed loader (pinned; no action) |
| 3 | `invalid_node_type` — "RouteNode parse failed: invalid_node_type" (`from_dictionary`, `route_node.gd:173`) | `tests/unit/run/test_route_node.gd::_from_dictionary_returns_null_and_push_errors_on_failure` — the parse-failure `push_error` path | **None** — deliberate parse-failure proving `from_dictionary` returns null + `push_error`s on a bad node type | Route-node parse (pinned; no action) |
| 4 | `malformed-JSON` — "Parse JSON failed... Expected key" (`read_profile`, `profile_repository.gd:97`) | `tests/unit/save/test_profile_repository.gd::_read_of_malformed_json_returns_profile_parse_failed` — the profile recovery path | **None** — deliberate malformed-file recovery → structured `profile_parse_failed`, no partial state | Profile save recovery (pinned; no action) |
| 5 | `malformed-JSON` — "...Expected 'true', 'false', or 'null', got 'this'" (`read_run_snapshot`, `save_repository.gd:70` via `run_resume_service.gd:48`) | `tests/unit/save/test_run_resume_service.gd::_resume_unparseable_bytes_fail_structured` — the resume-of-unparseable-bytes path | **None** — deliberate resume-recovery → structured failure, no partial run activated | Run save/resume recovery (pinned; no action) |
| 6 | `malformed-JSON` — "Parse JSON failed... Expected key" (`read_settings`, `settings_repository.gd:91`) | `tests/unit/settings/test_settings_repository.gd::_read_malformed_file_falls_back_to_defaults_with_diagnostic` — the settings lenient-recovery path | **None** — deliberate malformed-settings → `defaults()` with a `recovered` diagnostic (never a boot block) | Settings recovery (pinned; no action) |

**Stderr-catalog reconcile note (non-gating).** The retro-notes stderr catalog flagged that int64-overflow might
emit ×1 on some build states (vs the catalog's ×2). **On this gate build (§9) int64-overflow emits ×2** (both
site #1 `test_domain_event.gd` AND site #2 `test_manual_seed_loader.gd` fire), so the catalog's ×2 count is EXACT
on the gate head; the ×1 the retro observed does not reproduce here. Total on this build: int64-overflow ×2 +
malformed-JSON ×3 + `invalid_node_type` ×1 = **6**, matching the documented catalog. This is a benign
catalog-vs-build reconcile item, non-gating; **do not "fix" the catalog by changing a test.** [Source: retro-notes
§10-8 Phase 5]

### 4.4 The wall-clock AC guard + the reference-driver harness-perf limitation (recorded)

- **Wall-clock AC guard (the 10.8 precedent):** the full suite completes in **~175 s** on this desktop; a sane
  guard bound is **< 300 s (5 min)** on comparable desktop hardware. A run materially over that bound is a
  developer-experience regression to investigate (not a correctness failure).
- **The reference-driver proof-harness runtime is a known developer-experience limitation.**
  `tests/unit/run/test_reference_combat_driver.gd` runs **~57 s in isolation** (≈ a third of the full-suite
  wall-clock) — the `ReferenceCombatDriver._best_end_cell` → `_relocate_scratch` per-candidate
  `board.to_snapshot()`→`try_from_snapshot()` round-trip, amplified by Story 10.4's Medium/Scorched catalog
  extension (12 full driver runs on 14×12 boards). This is **NOT a correctness defect** (the suite is green; the
  driver is a headless PROOF harness excluded from every export) and **NOT blocking**. Recorded as a readiness
  limitation with an owning follow-up (§8); the fix is OPTIONAL and best left to a dedicated harness-perf pass — a
  gate story records the cost, it does not re-engineer the proof harness. [Source: `deferred-work.md` — 10-4
  review Med + Low]

**AC2 verdict:** MET — the actual fresh run recorded (191 PASS / 0 `^FAIL` / exit 0, read from the raw runner
output); the pass set mapped onto all 12 named families with citations; the 6 documented exceptions each carry a
risk + owner note; a sane wall-clock bound is stated and the reference-driver cost recorded with its owner.

---

## 5. AC3 — Pre-export validation

**GIVEN the MVP build candidate is prepared, WHEN pre-export validation runs, THEN debug/cheat tools are disabled
or inert, prototype dependencies are absent, scene nodes are not save truth, and no cloud/live-service dependency
is introduced, AND the build remains offline-first single-player.**

Each clause below has a concrete PASS read + the SHIPPED evidence, REUSING the shipped tests (not re-implemented).

### 5.1 (a) Debug / cheat / measurement tools are build-profile-gated INERT in release — PASS

- **The three measurement/diagnostics recorders are `OS.is_debug_build()`-gated INERT.** `LocalTimingRecorder`
  (`local_timing_recorder.gd:9`), `BossAttemptDiagnostics` (`boss_attempt_diagnostics.gd:63`), and
  `PerformanceBudgetReport` (`performance_budget_report.gd:70`) each set `enabled = new_enabled and
  OS.is_debug_build()`. In a non-debug (release) export `enabled` is forced false, every `record_*` is a no-op,
  and `records()` stays empty. Proven by `tests/unit/diagnostics/test_performance_budget_report.gd` +
  `test_boss_attempt_diagnostics.gd` (a disabled recorder captures nothing even in the debug headless build).
- **The `tools/**` drivers are excluded from every export preset.** All three presets (Windows `preset.0`,
  Android `preset.1`, iOS `preset.2`) carry the identical `exclude_filter`:
  `addons/**,data/source/**,scenes/debug/**,tests/**,tools/**,**/*_test.gd,**/test_*.gd`. So the report drivers
  (`tools/dump_performance_budgets.gd`, `dump_seed_regression_report.gd`, `dump_generator_fairness_report.gd`) and
  every test are PROVABLY excluded from production export. Asserted by
  `tests/unit/core/test_export_setup.gd::_production_exports_exclude_non_runtime_files` (`tools/**`, `tests/**`,
  `**/test_*.gd`, `data/source/**`, `scenes/debug/**`).
- **No debug overlay / seed / fog / LoS viewer / cheat path is registered in a shipped scene.** The only
  measurement surfaces are the build-profile-gated in-process recorders + the `tools/` report drivers (excluded);
  `scenes/debug/**` is excluded from export and no shipped scene tree wires a cheat/overlay path.

### 5.2 (b) Prototype independence — PASS

No production dependency on `prototype/`.
`test_export_setup.gd::_export_setup_avoids_forbidden_dependencies` asserts the export setup does not reference
`prototype/` (and `test_project_structure.gd` guards the production roots). The React/Vite `prototype/` is frozen
validation evidence only (NFR2).

### 5.3 (c) Save truth = versioned domain snapshots, never scene nodes — PASS

Save truth is versioned domain snapshots: `RunSnapshot` / `ProfileSnapshot` / `SettingsSnapshot`, each with
`SCHEMA_VERSION == 1` (`run_snapshot.gd:12`), and the pinned **23-key `RunSnapshot` no-surprise-key gate** (a new
top-level key must intentionally bump the gate). No scene node is serialized as save truth (the in-node
interactive fight is EPHEMERAL — the 23-key gate stays 23; `interactive_combat_session.gd`). Proven by
`tests/unit/save/test_run_snapshot.gd` (the key-gate + schema + JSON round-trip) + the save integration suites
(§4.2 save/load family).

### 5.4 (d) No cloud / telemetry / multiplayer / live-service dependency — PASS

`PlatformServices` (`scripts/platform/platform_services.gd`) is a **local no-op** with exactly three bare methods:
`record_telemetry` and `unlock_achievement` are empty `pass` bodies, and `sync_save` returns `ActionResult.ok()`
without any network/cloud call. No telemetry sink, cloud call, account, or live-service dependency is wired. The
class defines NO `TelemetrySink` / `SaveSyncProvider` / `AchievementProvider` / `CrashReporter` type OR method —
there is no `CrashReporter` at all; those four names are the **project-context Platform *interface posture*** (the
design-time naming for the seams a future integration would sit behind, echoed in this story's Dev Notes), NOT types
that exist in this code. `test_export_setup.gd::_export_setup_avoids_forbidden_dependencies` additionally asserts the
export setup adds no `telemetry`, `multiplayer`, or `cloud` service (NFR11).

### 5.5 (e) Offline-first single-player — PASS

The MVP is offline-first single-player: no accounts, cloud saves, leaderboards, multiplayer, or live-service
dependency (confirmed by 5.4 + the project posture). Both save files (`user://run_autosave.json`,
`user://profile.json`, `user://settings.json`) are local; nothing phones home.

### 5.6 The pre-release-export checklist (reproduced from device-tiers §5.4 — the actionable release-gate item)

The manual release checklist a producible export must satisfy (project-context Platform rule *"build-profile flags
plus pre-export validation and manual release checklist"*):

- [ ] Confirm `export_presets.cfg` `exclude_filter` still excludes `tools/**`, `tests/**`, and `**/test_*.gd` on
      **every** shipped preset (the harness + tests cannot ship). *(Verified present on all 3 presets at the gate
      build.)*
- [ ] Confirm the release build is a **non-debug** build so every `OS.is_debug_build()`-gated recorder
      (`LocalTimingRecorder`, `BossAttemptDiagnostics`, `PerformanceBudgetReport`) is INERT.
- [ ] Confirm `PlatformServices` is still the local no-op (no telemetry / cloud sink wired).
- [ ] Confirm no debug overlay / seed / fog / LoS viewer / cheat path is registered in the shipped scene tree.

### 5.7 iOS packaging (the G7 pre-export note)

The pre-export `exclude_filter` HOLDS on the iOS preset (`preset.2` carries the identical filter), so the
debug/cheat/test exclusion is proven for iOS too. But `preset.2` is a **scaffold** (`runnable=false`, blank
`app_store_team_id` + `code_sign_identity_debug/release` + icons), and a producible iOS BINARY needs macOS +
Xcode. This is availability gap **G7** (§8) — an acceptable documented limitation for the v0 candidate (the
non-iOS presets carry the identical pre-export invariants).

### 5.8 No new test added (decision)

`test_export_setup.gd` already asserts clauses (a-partial), (b), (d) and the iOS-deferred-without-secrets scaffold;
`test_performance_budget_report.gd` / `test_boss_attempt_diagnostics.gd` prove the build-profile gating; the save
suites prove (c); `test_settings_snapshot.gd` proves the difficulty non-goal (§6). **No genuinely net-new
pre-export invariant is left uncovered**, so — per the story's "reuse, don't reinvent" discipline and the rule
that a gate story must not duplicate an existing assertion — **no new test is added.** Keeping the suite
byte-for-byte at 191 PASS is itself part of this gate's "behaviorally unchanged" invariant. (Contrast 10.5, which
added a test because run-flow cue coverage was genuinely net-new; here it is not.)

**AC3 verdict:** MET — each of the five clauses has a concrete PASS read grounded in shipped evidence; the release
checklist is reproduced as the actionable pre-export gate; iOS packaging recorded as G7.

---

## 6. AC4 — Settings & challenge-scope

**GIVEN MVP readiness includes settings and challenge scope, WHEN the readiness checklist is reviewed, THEN it
verifies settings contain no selectable difficulty ladder and no easy/normal/hard tier, AND post-MVP challenge
ideas remain explicit variants, trials, oaths, or special runs rather than generic difficulty tiers.**

### 6.1 Difficulty non-goal — CONFIRMED at the contract level (regression-enforced) + at the surface level

- **Contract level.** `SettingsSnapshot.PREFERENCE_KEYS` = `text_scale`, `master_volume_db`, `audio_muted`,
  `input_scheme`, `colorblind_safe`, `high_contrast` — **no difficulty key.** The regression test
  `tests/unit/settings/test_settings_snapshot.gd::_difficulty_non_goal_keys_are_absent` enforces the absence: it
  asserts a `FORBIDDEN_DIFFICULTY_KEYS` set (`difficulty`, `difficulty_tier`, `easy`, `normal`, `hard`,
  `challenge_level`, `enemy_scaling`, `damage_multiplier`) is absent from both `PREFERENCE_KEYS` and the
  serialized dictionary, AND that `parse()` **DROPS** an injected `difficulty_tier` / `enemy_scaling` — so a
  future contributor cannot add one silently. No setting scales enemy stats / HP / damage / rewards / RNG / run
  length.
- **Surface level.** The shipped outpost/meta menu presents NO difficulty selector (there is no difficulty control
  to audit), confirmed by the 10.5 accessibility audit §4.10 ("Difficulty non-goal CONFIRMED: the outpost/meta
  menu presents NO difficulty selector"). The UX appendix §12.3 states the negative readiness criterion: *"The
  settings screen MUST NOT present a difficulty selector."*

### 6.2 The settings-SCENE paper-audit gap (appendix §16 G4) — weighed + dispositioned

**No settings VIEW model and no settings SCENE exists yet** (appendix §16 G4, PARKED — Epic 11 built no settings
scene). The settings-screen accessibility is therefore a PAPER audit against the `SettingsSnapshot` contract +
appendix §12.5 (10.5 audit §4.15, finding F-3). The human-eyes readability of the real settings scene cannot be
audited until it is built.

- **Disposition (the gate's call): acceptable documented readiness LIMITATION for the v0 candidate.** The
  difficulty NON-GOAL — the load-bearing settings-scope readiness fact — is confirmed at the CONTRACT level and
  regression-enforced (§6.1), so it does not depend on the scene existing; and there is no settings scene to
  human-audit, so there is no unverified shipped surface. Shipping the offline-first v0 candidate with a
  paper-only settings audit is acceptable.
- **Owner + target discharge path:** the **settings-scene owner (11.3/11.5** per the eventual scene split). When
  the settings scene + (optional) VM are built, the human-eyes settings-scene readability audit (F-3 / ASG-3)
  discharges. **NOT built here; no difficulty knob proposed.**

### 6.3 Post-MVP challenge scope — explicit variant / trial / oath / special-run content

Post-MVP challenge is explicit variant / trial / oath / special-run content, **never a generic difficulty
ladder** (the ratified GDD FR90/FR91/FR93 posture, traced via `epics.md` FR-map → Story 2.9 + 10.6). MVP
difficulty comes from run depth, enemy patterns, affinity pressure, elite nodes, risk rewards, resource attrition,
and boss preparation — never a knob (project-context § Settings Rules; UX appendix §12.3). This gate CONFIRMS the
posture; it never proposes adding a difficulty tier.

**AC4 verdict:** MET — the difficulty non-goal confirmed at the contract level (regression-enforced) + at the
surface level (no selector); the settings-scene paper-audit gap weighed and dispositioned as an acceptable
documented limitation with its owner; the post-MVP challenge scope stated as explicit variant/trial/oath/special-run
content.

---

## 7. Epic-10 threshold roll-up (the four sibling ledgers + the two audits)

The gate ROLLS UP the sibling Epic-10 readiness ledgers/docs — it VERIFIES their verdicts; it does not rebuild
them.

### 7.1 Device / performance / memory / battery — `device-tiers-and-performance-budgets.md` (10.1)

- **4 device tiers** defined (§2): low ~4 GB Android, mid ~6 GB Android/iOS, high flagship, Windows-desktop
  parity — each with a measurement method, per-tier peak-memory budget (≤1.5/2/2.5/2 GB), and battery target
  (≤15% / 30 min).
- **4 MVP performance budgets** (§3.1): level load < 3 s (NFR4), preview response < 100 ms (NFR5), selection
  response < 100 ms (NFR5), stable 60/30 FPS (NFR6).
- **§3.3 measured (headless/desktop): 12 measurements, all PASS with enormous margin** — level load ~4.3-11.4 ms
  vs the 3000 ms budget (> 2985 ms headroom); worst combat-step domain compute (`line_of_sight_update` ~0.52 ms /
  `command_execution` ~1.94 ms) > 98 ms under the 100 ms budget. Windows-desktop-parity headless-measurable
  budgets MET; a strong lower bound for mobile.
- **§6 gaps G1-G7** = the physical-device / on-device measurement set (dispositioned in §8).

### 7.2 Seed determinism — `seed-regression-suite-readiness.md` (10.2, discharged by 10.8) — VERIFY MET

All seven headless-mechanical sample targets are **MET** (Story 10.8, verified live by the suite's honest-sample
assertions in `test_seed_regression_suite.gd`): tactical **25**, Small **50**, Medium **50**, route **20**, reward
**20**, per-implemented-affinity **10 each** (Scorched / Flooded-Conductive / Cursed / Darkness), boss/finale
**10**. The shared Small/Medium 50-seed catalog spans the three Epic-10 harnesses (10.1 level-load, 10.2
regression, 10.3 fairness) — coordinated, in sync; the affinity sample landed exactly 10-per-affinity (regenerated
via the dump tooling, never hand-edited). §4 confirmed this gate re-pins no fingerprint and hand-edits no sample.

### 7.3 Generator fairness — `generator-fairness-batch-readiness.md` (10.3, resolved by 10.8) — VERIFY RESOLVED

- **§4 FR58 `darkness_unseen_hazard` RESOLVED** (Story 10.8): predicate (b) strengthened from static-from-entrance
  to moving reduced-radius LoS "seen-before-contact"; Medium seeds 4004/5005 flip to legitimate PASS; **0
  generated-board Darkness failures, both recipes** (Small + Medium meet the FR58 zero-tolerance bar). Proven by
  `test_generator_fairness_batch.gd` + `test_darkness_fairness.gd` (the flip is documented in-test; a real
  entrance-on-hazard FAIL is retained). The live-gate STOP path (`RunOrchestrator._check_darkness_fairness_live`)
  still proves the hard-gate violation board.
- **§5 50/50 MET** — the batch runs 50 Small + 50 Medium seeds; all PASS the generation zero-tolerance classes by
  construction (`attempts == 1`) + the strengthened Darkness fairness. Every implemented affinity's fairness
  verdict asserted.

### 7.4 Playtest comprehension — `mvp-playtest-comprehension-checklist.md` (10.4) — VERIFY

- The seven comprehension items + the session-record template + the acceptance thresholds are authored; the FR30
  run-length dimension (the AC2 session-length + nodes-cleared overlay) is present. **FR30 run-length**: the
  seeded route is 8-12 nodes → boss (Epic 4; the constant 8-tier route depth measured by the 4.6 pacing survey).
- **Verified headless (NOT gaps):** the `warding_salve` reward-table absence (§8.2 tripwire test
  `test_consumable_reward_frequency.gd`), the OBJECTIVE per-class distinctness (12.2 proof on seed 4242), and the
  Small-neutral + Medium-neutral + Scorched-affinity winnability inputs (the extended reference-driver catalog).
- **Observed-session gaps OSG-1..4** (≥5 human sessions; felt consumable value; felt class distinctness; felt
  pacing) are recorded against the 10.6 gate (§8). The 12.2 Medium/affinity winnability gap is CLOSED (extended).

### 7.5 Accessibility & readability — `accessibility-and-readability-audit.md` (10.5) — VERIFY

- The per-surface four-check audit across the 16-surface roster + the findings table (F-1/F-2/F-3) + the audio-off
  equivalence + the phone reachability/orientation-invariance read are authored; the run-flow cue-coverage fact is
  proven by `test_run_flow_accessibility_coverage.gd` (every affinity/Darkness cue resolves non-color).
- Findings rolled forward: **F-1** Flooded `_placeholder` (→ 10.7, §7.6/§8); **F-2** thin run-summary outcome
  label (→ run-level event-store/summary-render story; the AC1 thin-step §3.1); **F-3** settings paper-audit (→
  settings-scene owner; §6.2/§8). Availability gaps **ASG-1** (human-eyes contrast) / **ASG-2** (phone-hardware
  readability) → the 10.6 gate (§8).

### 7.6 Placeholder / asset / audio / UX readiness — ROLL-UP + HAND OFF to 10.7

10.6 reviews placeholder/asset/audio at a ROLL-UP level only; **10.7 is the DEDICATED asset/audio/placeholder &
UX-readiness gate.** Recorded as 10.7-owned handoffs (NOT resolved here):

- The **Flooded electric-interaction `affinity_conductive_danger_placeholder` (+ `..._vfx`)** — a tracked,
  distinct-from-final MVP placeholder that ALREADY carries a non-color `shape`(+label+text) channel (so the
  conductive danger reads with color stripped even as a placeholder); the full conductive-interaction art/VFX +
  final cue (replace / de-scope / block) is **10.7-owned** (finding F-1). NOT a color-only or missing-cue
  violation.
- The **audio track** — 0 files shipped (a placeholder track), non-gating (nothing is audio-only today; every AC3
  feedback meaning has a visual/textual equivalent per the 10.5 audio-off audit §7). Audio-track readiness is
  **10.7-owned**.

---

## 8. The gap-disposition ledger (each open gap → disposition + owner + target)

Every open gap that touches MVP readiness, with an explicit disposition. **Default disposition (per the
offline-first v0 CANDIDATE scope + the 10.1/10.4/10.5 honesty posture): an acceptable DOCUMENTED readiness
LIMITATION** for the preserved v0 candidate, each with its owning follow-up. A gap is a HARD BLOCKER only if it
makes the loop genuinely unplayable or violates a hard invariant — **none currently does.**

| Gap | What is missing | Disposition | Owner | Target discharge path |
|---|---|---|---|---|
| **G1** | Physical low-tier ~4 GB Android device / emulator (on-device load, FPS, memory, thermal, battery) | Acceptable documented limitation | 10.6 physical-device pass owner | A physical-device measurement pass on a ~4 GB Android device before ship |
| **G2** | Physical mid-tier ~6 GB Android/iOS device | Acceptable documented limitation | 10.6 physical-device pass owner | A physical-device pass on a ~6 GB device before ship |
| **G3** | Physical high-tier flagship device | Acceptable documented limitation | 10.6 physical-device pass owner | A physical-device pass on a current flagship before ship |
| **G4** (device-tiers §6) | On-device / windowed render-frame profiler for sustained 60/30 FPS frame stability (NFR6 — a headless run has no render frame loop) | Acceptable documented limitation | 10.6 physical-device pass owner | An on-device Android/iOS pass + a windowed desktop-parity (`preset.0`) pass sampling `Performance.get_monitor(TIME_FPS)` |
| **G5** | Real-touch preview/selection latency (render-to-glass) — only domain compute is measured headless | Acceptable documented limitation | 10.6 physical-device pass owner | An on-device touch-to-feedback latency pass |
| **G6** | Physical mobile battery / thermal (≤15% / 30 min + thermal-throttling proxy) | Acceptable documented limitation | 10.6 physical-device pass owner | The physical-device 30-minute representative-run pass reading battery % + OS thermal state |
| **G7** | iOS packaging — `preset.2` is a scaffold (`runnable=false`, blank signing + icons); iOS binary needs macOS + Xcode | Acceptable documented limitation | 10.6 / iOS-packaging owner | Complete the iOS export (signing, icons, provisioning) once macOS/Xcode access is available, then the on-device pass |
| **appendix §16 G4 (settings)** | The settings-SCENE human-eyes accessibility audit (paper audit until the scene + optional VM are built); F-3 / ASG-3 | Acceptable documented limitation — difficulty non-goal confirmed at the contract level (regression-enforced); no scene to human-audit | Settings-scene owner (11.3/11.5) | The human-eyes settings-scene readability audit once the settings scene is built |
| **Harness perf** | `ReferenceCombatDriver` proof harness ~57 s in isolation (`_relocate_scratch` per-cell snapshot round-trip) | Acceptable documented limitation (dev-experience; harness excluded from export; suite green) | Reference-driver perf/coverage pass (candidate; NOT committed) | Replace the per-cell snapshot round-trip with an in-place relocate-and-restore (or a lighter positional model) |
| **Determinism coverage** | The reference-driver byte-determinism proof covers only the original Small catalog, not the added Medium/Scorched entries (a coverage-completeness gap; determinism DOES hold in fact) | Acceptable documented limitation (not a correctness defect; suite green) | Same reference-driver harness pass (best fixed with the perf item) | Fold the Medium + Scorched catalogs into the determinism loop (a second run + event-log compare per new seed × class) |
| **Thin run summary** | The "view summary" step's `outcome_or_cause` stays BLANK + empty passives/loot/discovery in the live flow (no run-level event store) — F-2 / T4 | Acceptable documented limitation (thin-but-present step §3.1; outcome conveyed non-color via reveal beats + `phase`) | Run-level event-store / summary-render story (origin 11.5) | Thread a run-level event store; a summary-render keys the outcome label off `phase` until then |
| **Reward/passive live-HUD wiring** | The "collect rewards" + "make passive choices" steps are present + integration-proven (`test_loot_passive_build_smoke_run.gd`, caller-driven) but not yet wired into the live run-flow HUD/scene (generate is caller-driven, not auto-wired into `run_to_completion`; the harness constructs the commands directly, not a scene/HUD) — §3.3 | Acceptable documented limitation (present + integration-proven; not missing → non-blocking) | Reward/passive live-HUD-wiring story (a later HUD story) | Wire the reward + passive-reward modals into the live run-flow HUD/shell |
| **Flooded `_placeholder`** | The full conductive-interaction art/VFX + final cue (F-1) | Acceptable documented limitation (tracked placeholder; non-color channel already present) → HAND OFF | **10.7** (dedicated asset/UX gate) | 10.7 replaces / de-scopes / blocks the placeholder |
| **Observed-session gaps (OSG-1..4)** | ≥5 observed human sessions; felt consumable value; felt class distinctness; felt pacing (10.4) | Acceptable documented limitation (the objective backings are verified headless) | 10.6 observed-playtest pass owner (intersects G1-G7 mobile form factor) | A physical-device observed-playtest pass (≥5 sessions across mobile + desktop) |
| **Human-eyes accessibility (ASG-1/ASG-2)** | Real contrast-ratio + pixel-level non-overlap on a physical display; real portrait/landscape font legibility + thumb-reach (10.5) | Acceptable documented limitation (the CONTRACT-level checks are verified headless) | 10.6 physical-device accessibility pass owner (intersects G1-G7) | A physical-device accessibility pass |

**No gap is classified a HARD BLOCKER.** The live loop is complete + winnable (§3), the suite is green (§4), the
pre-export invariants hold (§5), and the difficulty non-goal is regression-enforced (§6). Every open gap is either
a physical-device / human dimension a headless agent cannot exercise, or a tracked developer-experience /
coverage-completeness / thin-step / placeholder limitation with a named owner + discharge path — each an acceptable
documented readiness limitation for the offline-first **v0 candidate**, with the physical-device + settings-scene +
asset/audio passes as pre-ship follow-ups.

---

## 9. The playable-build-candidate manifest (FR70 — playable-build preservation)

The preserved v0 build-candidate record. FR70's "playable build that can launch and validate a small test loop" is
validated via the green headless suite + the scene-load compile guardrail + (if producible) a desktop launch; a
real on-device launch is the G1-G7 pass.

| Field | Value |
|---|---|
| **Build id / git commit** | `3d59e2565f0c4d724804085a262ea77dae2b2910` (short `3d59e25`, "docs(story-10-6): create story context file") — the head this gate ran against |
| **Engine** | Godot 4.6.3 stable standard build (Mobile renderer), typed GDScript |
| **Test-result summary** | **191 PASS / 0 `^FAIL`**, runner exit 0 (`Headless tests passed.`), false-PASS guard clean, ~175 s wall-clock; 6 documented stderr negatives (int64-overflow ×2, malformed-JSON ×3, `invalid_node_type` ×1 — all deliberate fail-path assertions, §4.3) |
| **Live-loop status** | Complete + winnable (all 10 AC1 steps present; §3); one thin step (view summary, §3.1) + two caller-driven / live-HUD-wiring-deferred steps (collect rewards + make passive choices, §3.3) |
| **Pre-export invariants** | HELD (all 5 AC3 clauses; §5); the release checklist §5.6 is the manual pre-export gate |
| **Difficulty non-goal** | CONFIRMED at the contract level (regression-enforced) + surface level (§6) |

### 9.1 Per-preset producibility

| Preset | Platform | Producible now? | Note |
|---|---|---|---|
| `preset.0` | Windows Desktop MVP (`runnable=true`) | Producible **if** Godot export templates are installed — else an ENVIRONMENT gap (no templates provisioned in this headless environment). The identical `exclude_filter` holds. | The desktop-parity launch is the FR70 "small test loop" validation on desktop |
| `preset.1` | Android MVP (`runnable=false`, `signed=false`) | Needs the Android SDK / JDK / Build-Tools / NDK toolchain (pinned in `README.md`) | An Android debug export + on-device pass is the G1/G2 discharge |
| `preset.2` | iOS MVP (`runnable=false`, blank signing + icons) | **NO** — the G7 scaffold; a producible iOS binary needs macOS + Xcode | G7 (§8); the pre-export `exclude_filter` still holds on the iOS preset |

### 9.2 Known limitations + de-scope notes

- **Known limitations:** the full gap-disposition ledger (§8) — the G1-G7 physical-device passes, the appendix §16
  G4 settings paper-audit, the reference-driver harness-perf + determinism-coverage cost, the thin run summary,
  and the Flooded `_placeholder`.
- **De-scope notes (v0 candidate):** iOS packaging deferred (G7 → macOS/Xcode follow-up); physical-device passes
  deferred (G1-G7 → the physical-device pass owner); the reference-driver harness-perf + Medium/Scorched
  determinism-coverage fix deferred (→ a dedicated harness pass); the thin-summary outcome label deferred (→ the
  run-level event-store / summary-render story); the Flooded `_placeholder` full treatment + audio-track readiness
  handed to 10.7.

---

## 10. Epic-10 gate handoff + the overall MVP-readiness verdict

- **Sibling gate 10.7 (Asset, Audio, Placeholder & UX Readiness Gate).** 10.6 hands 10.7 the asset / audio /
  placeholder roll-up (§7.6) — the Flooded `_placeholder` (F-1) + the 0-file audio track — and does NOT do 10.7's
  job. [`epics.md` §Story 10.7]
- **10.6 is mid-epic; 10-7 follows.** No epic-end retrospective is triggered off this story; Epic 10 is NOT marked
  done here; `epic-10` stays `in-progress`.

### Overall verdict: `READY_WITH_GATES`

The MVP is **READY WITH DOCUMENTED GATES** for the offline-first v0 candidate:

- ✅ the full headless suite is green (191 PASS / 0 `^FAIL`, §4),
- ✅ the live loop is complete + hands-on + winnable (all 10 AC1 steps present, §3),
- ✅ the pre-export invariants hold (debug/cheat inert, prototype-independent, save-truth snapshots, no
  cloud/telemetry, offline-first single-player, §5),
- ✅ the difficulty non-goal is regression-enforced (§6),
- ✅ every Epic-10 threshold is reviewed (§7) and **every open gap is documented with an owner + target discharge
  path** (§8),

with the **physical-device (G1-G7) + settings-scene (appendix §16 G4) + asset/audio (10.7)** passes as recorded
pre-ship follow-ups. This matches the existing `sprint-status.yaml` `readiness_status: READY_WITH_GATES` — the gate
verdict does not change it (it IS "ready with documented gates"), so it is left as-is.

---

## 11. Determinism / save invariants respected

This gate/roll-up story moves NONE of the pinned invariants — it VERIFIES they hold: the 7 named RNG streams
(`map` / `level` / `combat` / `loot` / `rewards` / `events` / `cosmetic`), zero new RNG draw sites, the 23-key
`RunSnapshot` gate, `ProfileSnapshot` / `SettingsSnapshot` `SCHEMA_VERSION == 1`, every generator / route / finale
fingerprint SOURCE + its pinned values, every seed-regression sample, and the default deterministic paths stay
byte-identical. This gate changed NO production `godot/` gameplay / save / RNG / content / generator / view-model /
presenter / scene path and NO `export_presets.cfg` preset; it added NO test (the pre-export/difficulty facts are
already covered, §5.8). The full headless suite stays green + byte-for-byte unchanged (191 PASS → 191 PASS).

---

## 12. References

- **Story source (verbatim ACs):** `_bmad-output/planning-artifacts/epics.md` — Epic 10 §"Story 10.6: MVP
  Readiness Gate and Playable Build Preservation" (incl. the 2026-07-04 Epic-11 + 2026-07-07 Epic-12
  prerequisites and the 2026-07-07 gate-scope note). FR/NFR map: FR70 (playable build preserved across
  milestones), FR30 (8-12 nodes → boss run-length), NFR11 (no cloud/live-service), NFR19 (debug/cheat inert in
  production), NFR2 (no prototype dependency), NFR15 (save = versioned domain snapshots), NFR20 (device
  tiers/measurement/memory/battery), NFR13 (deterministic under seeded execution), NFR1 (Godot 4.6.3 + typed
  GDScript), NFR3 (mobile-first + Windows parity). "GDD FR90/FR91/FR93: no selectable difficulty tiers → Story 2.9
  + 10.6".
- **The four sibling Epic-10 readiness ledgers/docs (rolled up — VERIFIED, not rebuilt):**
  `device-tiers-and-performance-budgets.md` (10.1 — 4 tiers + 4 budgets + §3.3 measured + §6 G1-G7 + §5.4
  pre-export checklist), `seed-regression-suite-readiness.md` (10.2/10.8 — §3 all samples MET),
  `generator-fairness-batch-readiness.md` (10.3/10.8 — §4 FR58 RESOLVED + §5 50/50 MET),
  `mvp-playtest-comprehension-checklist.md` (10.4 — comprehension + FR30 + OSG-1..4),
  `accessibility-and-readability-audit.md` (10.5 — NFR7/8/9 + F-1/F-2/F-3 + ASG-1/ASG-2).
- **The pre-export + difficulty-non-goal evidence (verified, not duplicated):**
  `godot/tests/unit/core/test_export_setup.gd`, `godot/export_presets.cfg` (3 presets + identical `exclude_filter`;
  iOS `preset.2` scaffold = G7), `godot/tests/unit/settings/test_settings_snapshot.gd`
  (`_difficulty_non_goal_keys_are_absent` + `PREFERENCE_KEYS`), `godot/scripts/diagnostics/local_timing_recorder.gd`
  + `boss_attempt_diagnostics.gd` + `performance_budget_report.gd` (the `OS.is_debug_build()` gating),
  `godot/tests/unit/diagnostics/test_performance_budget_report.gd` + `test_boss_attempt_diagnostics.gd`,
  `godot/scripts/platform/platform_services.gd` (the local no-op), `godot/scripts/save/snapshots/run_snapshot.gd`
  (`SCHEMA_VERSION == 1` + the 23-key gate).
- **The live-loop drivers (the AC1 evidence):** `godot/scripts/run/run_orchestrator.gd`
  (`run_to_completion_live:1336` / `auto_play_full_run:1494` / `resolve_boss_victory:826` /
  `begin_interactive_combat_node:1121` / `finish_interactive_combat_node:1225`),
  `godot/scripts/run/interactive_combat_session.gd`, `godot/scripts/run/run_summary.gd` (`build:199`),
  `godot/scripts/ui/flow/run_end_profile_bridge.gd`, `godot/scripts/ui/view_models/outpost_view_model.gd`
  (`is_startable` / `start_run_request`), `godot/tests/unit/ui/test_run_flow_scenes_load.gd` (the scene-load
  compile guardrail), `godot/tests/integration/finale/test_finale_full_run.gd` +
  `test_finale_seed_regression.gd`, the consolidated `godot/tests/integration/test_seed_regression_suite.gd` +
  `test_generator_fairness_batch.gd`.
- **The UX appendix (the settings gap + difficulty non-goal):** `_bmad-output/planning-artifacts/ux-appendix-run-flow.md`
  §16 (Contract Gaps — appendix §16 G4 = settings VM, PARKED; distinct from device-tiers §6 G4 = FPS profiler),
  §12.3 (difficulty non-goal), §12.5 (settings paper-audit backing).
- **Deferred-work ledger (overlapping items dispositioned above, not reopened):**
  `_bmad-output/implementation-artifacts/deferred-work.md` — the G1-G7 physical-device gaps (10.6-owned); the
  settings paper-audit F-3 (appendix §16 G4); the reference-driver perf (10-4 review Med) + Medium/Scorched
  determinism-coverage (10-4 review Low); the thin run summary F-2/T4 (11.5-origin owner); the Flooded
  `_placeholder` F-1 (→ 10.7).
- **Epic-10 retro (constraints folded):** `_bmad-output/auto-gds/retro-notes/epic-10.md` — §10-1 (iOS/G7), §10-2
  (the sole sanctioned edit is the optional additive test), §10-3 (shared catalog), §10-4 (winnability closed),
  §10-8 (is_last_in_epic / stderr catalog / regenerate-samples / grep-sweep).
- **Project rules:** `project-context.md` (§ Readiness/Perf/Seed/Fairness Rules; § Platform & Build Rules; §
  Settings Rules + difficulty non-goal; § Testing Rules; Critical Don't-Miss; the pinned invariants),
  `sprint-status.yaml` (`readiness_status: READY_WITH_GATES`), `CLAUDE.md` / `AGENTS.md`.

---

## 13. Change Log

| Date | Version | Change | Author |
|---|---|---|---|
| 2026-07-10 | 1.0 | Initial authoring — the final Epic-10 MVP-readiness GATE: the AC1 per-step live-loop verification (all 10 steps present; the thin view-summary step recorded, the hands-on-device pass as a gap); the AC2 fresh full-suite run (191 PASS / 0 `^FAIL` / exit 0 / ~175 s, false-PASS guard clean) with the 12-family mapping + the 6 documented stderr negatives (each risk + owner; int64-overflow ×2 on this build) + the wall-clock guard + the reference-driver harness-perf note; the AC3 pre-export validation (5 clauses PASS with shipped evidence + the release checklist + iOS G7); the AC4 settings & challenge-scope (difficulty non-goal contract+surface confirmed, settings paper-audit dispositioned, post-MVP challenge scope); the Epic-10 threshold roll-up (device/perf/seed/fairness/playtest/accessibility + the 10.7 asset/audio/placeholder handoff); the gap-disposition ledger (G1-G7 + appendix §16 G4 settings + harness-perf + determinism-coverage + thin-summary + Flooded placeholder + OSG/ASG — all acceptable documented limitations for the v0 candidate); the playable-build-candidate manifest (commit `3d59e25`, per-preset producibility, de-scope notes); overall verdict `READY_WITH_GATES`. VERIFIES + DECIDES + ROLLS UP; touches no production code; adds no test; the suite stays byte-for-byte green. Discharges FR70 + the FR30 gate half. | Story 10.6 (dev agent) |
| 2026-07-12 | 1.1 | Code-review round-1 response (doc-precision/parity `[Review][Decision]` items). §3 rows 6-7 + new §3.3 + §8 gap-ledger row + §9 manifest line: qualify collect-rewards + make-passive-choices as PRESENT + integration-proven (`test_loot_passive_build_smoke_run.gd`) but caller-driven / live-HUD-wiring-deferred (parity with the view-summary thin step §3.1); verdict `READY_WITH_GATES` unchanged, no step missing. §5.4 softened to describe `platform_services.gd` as its 3 bare no-op methods (`record_telemetry`/`unlock_achievement`/`sync_save`; no `CrashReporter` type or method) with the TelemetrySink/SaveSyncProvider/AchievementProvider/CrashReporter naming attributed to the project-context Platform *interface posture*, not code-level types. No production `godot/` code touched; suite byte-for-byte unchanged (191 PASS / 0 `^FAIL`). | Story 10.6 (dev agent, review response) |
