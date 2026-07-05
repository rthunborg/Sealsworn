---
baseline_commit: 80cb1bb8267f133fd90e8c59a490fc0ce8a2adaa
---

# Story 11.2: Live Combat Loop and Hero Death Source

Status: review

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a player,
I want fights to be played out for real and death to actually end a run,
so that a descent can be won or lost by what happens on the board.

## Story Type & Scope Boundary (READ FIRST)

**This IS a CODE story — the FIRST live-wiring story of Epic 11.** It crosses the single largest deferred
seam in the project: the **live run combat loop + the live hero-death SOURCE**. Every retro from Epic 7
through Epic 9 parked this exact work behind "a later run-flow/HUD story"; Epic 11 is that story, and 11.2
is its combat/run-end half. **11.3 owns the SCENES** (SceneManager navigation, the on-screen tactical HUD);
**11.2 owns the scene-free DOMAIN wiring** that makes a live fight decide a node and a live hero-death end a
run. Keep the split clean: 11.2 adds NO `.tscn`, NO `Control`, NO presenter, NO autoload — it wires the
domain seam the scenes will later drive.

- **What 11.2 delivers (three seams + their forcing tests):**
  1. **Live combat resolution for live nodes** (AC1) — a live combat / elite / boss node in the LIVE run
     flow resolves from real tactical play on the board (player commands through the command bridge; enemy /
     boss turns through the existing `EnemyTurnResolver` / `BossTurnResolver`), NOT the v0
     `_resolve_combat` auto-resolve-to-success. The auto-resolve path MAY remain for explicitly non-live
     simulation (`run_to_completion`'s headless seed-batch use).
  2. **The live hero-death SOURCE** (AC2) — a combat loop that detects the hero at 0 HP mid-encounter and
     auto-fires the run-end resolution (`CompleteRunCommand` with the appropriate `RUN_FAILED_CAUSES` cause,
     driven through `RunOrchestrator.resolve_run_end`) → `PHASE_FAILED` + `next_destination == outpost`,
     making FR32's loss half triggerable LIVE (the first-death latch recordable off the real terminal state).
  3. **The boss-victory production call site + optional full-boss auto-play** (AC3) —
     `RunOrchestrator.resolve_boss_victory()` (built in 9.5, invoked ONLY from tests today) gains its
     production call site; `run_to_completion` can auto-play the full boss fight headlessly (both sides
     simulated) for seed-batch / simulation use.
  4. **Forcing tests for the now-reachable defensive branches** (AC4) — the live path makes previously
     unreachable branches reachable: the `CompleteRunCommand._resolve_completed` step-2 restore, and the
     `NodeResolvePlaceholderCommand._resolve_boss` atomicity TWIN (if a live driver of that branch is added).
     Add the forcing regressions Epic-9 retro **T3** named.

- **What 11.2 does NOT do (hard scope fences — do not cross):**
  - **No scenes / UI.** No `.tscn`, no `Control`, no presenter, no `SceneManager` navigation, no on-screen
    HUD (that is **11.3**). 11.2 is a scene-free domain/orchestrator wiring + tests. The live loop it builds
    is driven by explicit turns / an auto-play driver a headless test exercises — the HUD that renders it is
    11.3's.
  - **No affinity call sites.** Live affinity effects (Darkness/Scorched/Cursed/Flooded on the live board)
    are **11.4**. 11.2's live combat runs a plain generated level (no affinity applied), exactly as the v0
    orchestrator does today (`assign_affinity` stays caller-driven, un-wired).
  - **No new save key, no schema bump, no new RNG stream, no new fingerprint.** The 23-key `RunSnapshot`
    gate stays 23; `ProfileSnapshot.SCHEMA_VERSION == 1`; the 7 named RNG streams
    (`map`/`level`/`combat`/`loot`/`rewards`/`events`/`cosmetic`) are untouched; every pinned
    level/route/arena seed-regression fingerprint stays byte-identical (AC4).
  - **No new event unless genuinely required.** The run-end / victory / death vocabulary already exists
    (`run_failed`, `run_completed` broadened with `victory`, `boss_defeated`, `level_victory_reached`,
    `level_defeat_reached`). Reuse them. If (and only if) a new `DomainEvent.Type` is genuinely needed, append
    it at the enum END and wire it end-to-end (factory + per-event payload validator + BOTH id maps + JSON
    round-trip + malformed-negatives + the exhaustive `expected_ids` pin) — the append-only discipline
    (project-context "Do not renumber the `DomainEvent.Type` enum"). Prefer reuse.
  - **No meta spend / unlock application** (that is **11.6**), **no outpost scene / reveal render** (that is
    **11.5**). 11.2 stops at driving the terminal run state + emitting the run-end events those stories
    consume.

## Acceptance Criteria

Sourced verbatim from `epics.md` (Epic 11, Story 11.2). Four AC groups (Given/When/Then + And):

1. **Live combat resolution (AC1).** GIVEN a run enters a combat, elite combat, or boss node, WHEN the node
   resolves in the live run flow, THEN resolution comes from live tactical play on the board state — player
   commands through the command bridge, enemy and boss turns through the existing turn resolvers — AND the v0
   auto-resolve-to-success placeholder no longer decides live combat outcomes (it may remain for explicitly
   non-live simulation paths).

2. **Live hero-death source (AC2).** GIVEN the hero reaches 0 HP during any live encounter (level or boss),
   WHEN the combat loop detects hero death, THEN it auto-fires the run-end resolution (`CompleteRunCommand`
   with the appropriate failure cause from `RUN_FAILED_CAUSES`) driving `PHASE_FAILED` and
   `next_destination == outpost` — AND FR32's loss condition is triggerable live, with the first-death latch
   recordable off the real terminal state.

3. **Boss-victory production call site (AC3).** GIVEN the Larval Avatar reaches 0 HP in the live flow, WHEN
   the boss victory resolves, THEN `RunOrchestrator.resolve_boss_victory()` gains its production call site
   (boss route node cleared, `resolve_run_end(victory)` driven, first-victory latch recorded via
   `RecordFirstVictoryCommand`) — AND `run_to_completion` can auto-play the full boss fight headlessly (both
   sides simulated) for seed-batch and simulation use.

4. **Invariants + forcing tests (AC4).** GIVEN the live wiring lands, WHEN the headless suite and seed
   regressions run, THEN interrupted==uninterrupted determinism, the 23-key `RunSnapshot` gate,
   `ProfileSnapshot.SCHEMA_VERSION == 1`, the 7 named RNG streams, and every pinned fingerprint hold — AND
   forcing tests are added for defensive branches the live path makes reachable (the `_resolve_completed`
   step-2 restore; the `NodeResolvePlaceholderCommand._resolve_boss` atomicity twin if its branch is driven).

### AC Verification (how "done" is checked)

- **AC1** — a live combat / elite node, entered in the live flow, resolves from real player + enemy turns
  (a driven or auto-played fight to a `CombatOutcomeState` terminal), NOT from `_resolve_combat`'s
  `combat_auto_resolved` return. A win clears + exits the node; the board outcome (`STATE_VICTORY` /
  `STATE_DEFEAT`) — not "level generated OK" — decides the node. The v0 auto-resolve MAY still be reachable
  ONLY for an explicitly-labelled non-live simulation path (name it; do not let it silently decide a live
  fight). A test drives a live combat node to a real board outcome through the run flow.
- **AC2** — a live encounter driven to a hero 0-HP (a `CombatOutcomeState.STATE_DEFEAT` /
  `CombatOutcomeEvaluator` `primary_player_dead`) auto-fires `CompleteRunCommand(&"hero_death")` via
  `resolve_run_end`, leaving `run.phase == PHASE_FAILED`, a `run_failed` event with `cause == hero_death` +
  `next_destination == outpost`, and the run terminal. A test proves `RecordFirstDeathCommand` can then latch
  the first death off that REAL terminal state (not a hand-built failed run).
- **AC3** — a full run auto-played through the shell (`start` → `run_to_completion` auto-playing the boss
  fight to 0 HP → `resolve_boss_victory()`) reaches `PHASE_COMPLETED` with `run_completed` (`outcome ==
  victory`, `next_destination == outpost`), `RunSummary.boss_cleared == true`, and the first-victory latch
  recorded via `RecordFirstVictoryCommand`. The `resolve_boss_victory()` call site is now PRODUCTION (an
  auto-play driver / an orchestrator method), not test-only. `test_finale_full_run.gd` (or its successor)
  proves the auto-play path.
- **AC4** — full headless suite green (`godot --headless … test_runner.tscn`), false-PASS grep clean beyond
  the documented negatives; `git diff --check` clean. `RunSnapshot` 23-key gate == 23;
  `ProfileSnapshot.SCHEMA_VERSION == 1`; `RngStreamSet.required_streams()` unchanged (7 streams); every
  `tools/dump_*` seed-regression fingerprint byte-identical. The `_resolve_completed` step-2-restore forcing
  test exists (a test-only forced step-2 failure asserting the run restores to byte-identical `phase_before`
  — no longer only the observable-invariant assertion `test_complete_run_command.gd` ships today). IF a live
  driver of `NodeResolvePlaceholderCommand._resolve_boss` is added, its atomicity twin is hardened
  (capture+restore `phase_before`, mirroring `_resolve_completed`) with a forcing test; IF that branch is NOT
  driven, record in `deferred-work.md` that the twin stays parked (do not silently drop the T3 item).

## Tasks / Subtasks

- [x] **Task 1 — Live combat resolution for live nodes (AC1)**
  - [x] Build the scene-free **live combat driver** — `LiveCombatResolver` (`godot/scripts/run/live_combat_resolver.gd`),
        the generalized `Epic1MicroCombatScenario`. `RunOrchestrator.resolve_combat_node_live` reuses the EXISTING blocks:
        `NodeEnterCommand` → `LevelGenerator.generate(request, recipe_repo, enemy_repo)` → restore a live `BoardState`
        from `generation.payload["board"]` (the board snapshot; NOT `payload.level_seed`) → place the hero at
        `payload["entrance"]` → a `TacticalActionContext(board, TacticalTurnState, streams, [])` → drive a deterministic
        focus-fire scripted hero (`MoveCommand`/`AttackCommand` on the board) threaded with
        `EnemyTurnResolver.resolve_after_player_action(context, player_result)` → evaluate with
        `CombatOutcomeEvaluator.new(HERO_ID).evaluate(board, CombatOutcomeState, event_log)` until terminal
        (`STATE_VICTORY` / `STATE_DEFEAT`). (The command bridge is the SCENE's tap-submission seam — 11.3; the headless
        driver drives commands directly like `Epic1MicroCombatScenario`.)
  - [x] On a live VICTORY: clear + exit the node exactly as the v0 path does (`NodeExitCommand`), so the run advances
        forward. `resolve_combat_node_live` returns `resolution == live_combat_victory`; the BOARD outcome decides it.
  - [x] On a live DEFEAT: hand off to the hero-death source (Task 2) — do NOT exit the node (a dead hero ends the run).
  - [x] Keep the v0 `_resolve_combat` auto-resolve reachable ONLY on the DEFAULT (non-live) path — `_resolve_combat` /
        `resolve_current_node` / `run_to_completion` are UNCHANGED and still return `combat_auto_resolved`. The live path
        is a SEPARATE `resolve_current_node_live` / `run_to_completion_live` — a live fight is NEVER silently
        auto-resolved. The v0 boundary doc comment on the class was EXTENDED with the 11.2 live-flow boundary.
  - [x] **Determinism guard (AC4):** the live loop draws gameplay RNG ONLY through the run-level `RngStreamSet` on the
        `combat` stream (via `AttackCommand`) — NEVER `randi`/`randf`/a fresh RNG. The DEFAULT sword hero has no proc/
        shield → draws ZERO combat RNG (a test asserts the injected stream set is byte-identical before/after). The
        DEFAULT `run_to_completion` save-stream is byte-identical across two runs (proven). A live combat run is
        byte-deterministic for a fixed seed (`test_live_combat_resolver.gd` — same outcome + rounds + event log).

- [x] **Task 2 — The live hero-death SOURCE (AC2)**
  - [x] Wired the combat-DEFEAT → run-END seam: `resolve_combat_node_live` (Task 1) AND the boss auto-play (Task 3)
        detect the hero at 0 HP (`CombatOutcomeState.STATE_DEFEAT` / `TacticalEntityState.is_dead()`) and AUTO-FIRE
        `RunOrchestrator.resolve_run_end(&"hero_death")` (level/encounter death) → `PHASE_FAILED` + `run_failed` cause
        `hero_death` + `next_destination == outpost`. A hero death DURING the boss fight uses `&"boss_defeat"` (the
        boss-context cause). Both are pre-allowlisted in `DomainEvent.RUN_FAILED_CAUSES` — NO cause added.
  - [x] The death source is AUTO (not caller-supplied): the loop DETECTS 0 HP + FIRES the run-end itself (unlike the
        driven death `test_finale_full_run.gd` uses). This is the SOURCE Epic-9 retro T2 + the deferred-work ledger named.
  - [x] Proved the first-death latch records off the REAL terminal state: `test_live_run_flow.gd` +
        `test_finale_full_run.gd` drive a real live death, then `RecordFirstDeathCommand` on the terminal FAILED run and
        assert `first_death_recorded` flips. The latch command is UNCHANGED.
  - [x] **Idempotency (AC4):** the auto-fire runs BEHIND the `CompleteRunCommand` `run_already_terminal` guard — a
        second `resolve_run_end` on the terminal live-death run is the stable `run_already_terminal` error + byte-
        identical run (proven in `test_live_run_flow.gd`).

- [x] **Task 3 — Boss-victory production call site + full-boss auto-play (AC3)**
  - [x] Gave `RunOrchestrator.resolve_boss_victory()` its PRODUCTION call site: `auto_play_boss_fight` /
        `auto_play_full_run` drive `run_to_completion` to the 9.1 boss-setup terminus (`boss_encounter_pending()`),
        restore the arena `BoardState` from `boss_arena_payload()`, place the live boss (`larval_avatar`, `BossRepository`
        `max_hp`) + the hero, AUTO-PLAY the fight (both sides — `BossTurnResolver.resolve_boss_turn` for the boss; a
        deterministic scripted hero via `LiveCombatResolver.drive_hero_step_against`), thread the SHARED sequence-id
        cursor through `resolve_phase_transitions → detect_boss_defeat → the run-end append`, and on boss defeat call
        `resolve_boss_victory()` (clears the boss node + `resolve_run_end(victory)`).
  - [x] Recorded the first-victory latch off the real victory: `test_finale_full_run.gd::
        _auto_play_records_the_first_victory_latch_off_the_real_victory` drives `RecordFirstVictoryCommand` on the
        terminal COMPLETED auto-played run + asserts `first_victory_recorded`. The command is UNCHANGED.
  - [x] **`run_to_completion` auto-play:** built the auto-play as a SEPARATE opt-in orchestrator driver
        (`auto_play_full_run` — `run_to_completion` to the terminus, then auto-play the boss). The DEFAULT
        `run_to_completion` is UNCHANGED (stops at the boss terminus) — `test_finale_full_run.gd` +
        `test_finale_seed_regression.gd` still pass; the auto-play reproduces the fixed-seed outcome.
  - [x] **Both-sides-simulated (AC3):** the boss auto-play simulates BOTH the boss (`BossTurnResolver`) AND the hero
        (the `LiveCombatResolver` scripted-hit driver against the single boss target). ZERO-new-RNG (the boss AI + phase
        resolver + defeat are ZERO-RNG; the default sword hero draws ZERO combat RNG). The auto-played full run is
        byte-deterministic for a fixed seed (`_auto_played_full_run_is_byte_deterministic` — byte-identical terminal run
        + interleaved fight+run-END event stream).

- [x] **Task 4 — Forcing tests for the now-reachable defensive branches (AC4)**
  - [x] **`CompleteRunCommand._resolve_completed` step-2 restore (Epic-9 retro T3):** added the FORCING test
        `test_complete_run_command.gd::_two_step_completion_restores_phase_on_a_forced_step_two_failure` via a test-only
        `ForcedStepTwoFailureRunState` subclass (`godot/tests/unit/core/support/forced_step_two_failure_run_state.gd`)
        that makes step 2 (`NODE_RESOLUTION → COMPLETED`) reject while step 1 succeeds, DRIVING the restore branch
        (`run.phase = phase_before` at `complete_run_command.gd:243`) and asserting the run RESTORES to byte-identical
        `phase_before` (ACTIVE_ROUTE) — for BOTH `completed` and `victory`. No longer only the observable-invariant test.
  - [x] **`NodeResolvePlaceholderCommand._resolve_boss` atomicity TWIN (Epic-9 retro T3):** 11.2's auto-play uses
        `BossNodeEnterCommand` + `resolve_boss_victory` (which do NOT touch `_resolve_boss`), so the placeholder boss
        branch is NOT driven — the twin STAYS PARKED. RE-RECORDED as still deferred + unreached in `deferred-work.md` (not
        hardened — hardening a branch nothing drives would be a dead defensive change; not silently dropped either).
  - [x] The `RunEndOutcome` allowlist fallback stays directly covered (the 9.4 garbage-marker note) — no new work.

- [x] **Task 5 — Invariants regression + full-suite green (AC4)**
  - [x] Re-verified every durable invariant: the 23-key `RunSnapshot` gate stays 23 (`test_run_snapshot.gd` PASS — NO new
        save key; the in-node fight state is EPHEMERAL); `ProfileSnapshot.SCHEMA_VERSION == 1` (`test_profile_snapshot.gd`
        PASS — NO migration); `RngStreamSet.required_streams()` = the 7 named streams (`test_rng_stream_set.gd` PASS — NO
        new stream); the `DomainEvent.Type` enum tail UNCHANGED (`test_domain_event.gd` PASS — the run-end/victory/death
        vocabulary REUSED, NO new event, so NO `expected_ids` change).
  - [x] Re-ran every seed-regression fingerprint suite + confirmed byte-identical: the Small/Medium level
        (`test_small_level_layout_seed_regression.gd` / `test_medium_level_layout_seed_regression.gd`), the route
        (`test_route_generation_seed_regression.gd`), the seed batch (`test_seed_batch_regression.gd`), the boss/finale
        (`test_finale_seed_regression.gd`) — ALL PASS. ZERO fingerprint moves (the default paths are untouched; the live
        loop is additive/opt-in). `git diff HEAD` on the orchestrator is purely additive (ZERO code-logic deletions;
        only the doc comment was extended); the `tools/dump_*` fingerprint files are untouched.
  - [x] Ran the FULL headless suite: **168 PASS / 0 `^FAIL`**, "Headless tests passed.", exit 0. False-PASS grep clean —
        exactly the 6 documented stderr negatives (int64-overflow ×2, malformed-JSON ×3, `invalid_node_type` ×1), ZERO
        `SCRIPT ERROR`, and 11.2 added NO new negative-path test. `git diff --check` clean.

- [x] **Task 6 — Update the deferred-work ledger + tracking (AC4, hygiene)**
  - [x] In `deferred-work.md` (new 2026-07-05 11.2 entry): marked RESOLVED — the **LIVE combat-death CALL SITE /
        hero-death → `PHASE_FAILED` live SOURCE** (Epics 8-9), the **`resolve_boss_victory()` production call site** (9.5
        Decision), the **`_resolve_completed` step-2 forcing test** (Epic-9 T3). RE-RECORDED still-open — the
        `_resolve_boss` atomicity twin (unreached — stays parked), the HUD/scenes (11.3), the live affinity call sites
        (11.4), the outpost render / meta-spend (11.5/11.6), the live in-node save (a later story). Noted the
        originating story/date.
  - [x] Did NOT reopen or re-defer items unrelated to this story's surface (only the live-combat / hero-death /
        boss-victory / atomicity-twin entries are 11.2's).

## Dev Notes

### What this story is (and is not)

Epics 1-9 shipped a COMPLETE, headless, deterministic domain: a full tactical layer (board, fog, previews,
commands, `EnemyTurnResolver`, the Epic-1 `CombatOutcomeEvaluator`), a full run layer (`RunOrchestrator`
start-to-end driver, the route/node model, `CompleteRunCommand` run-end resolution), and a full boss finale
(the `BossTurnResolver` live turn loop, `resolve_boss_victory()`, the first-victory latch) — but the run
combat is v0-AUTO-RESOLVED (`_resolve_combat` returns `combat_auto_resolved` when the level merely GENERATES
successfully), there is NO live hero-death SOURCE (the death PATH is proven only with DRIVEN deaths), and
`resolve_boss_victory()` has NO production call site (it is invoked only from `test_finale_full_run.gd`).

**11.2 turns the built-and-proven combat/run-end LOGIC into a live SOURCE.** It does not rebuild any of it —
it WIRES the existing pieces into a real fight that decides a node, a real hero-death that ends a run, and a
real boss auto-play that reaches victory. The Epic-9 retro named this precisely (§4 Charlie, §7 risk 1-2, §8
T1/T2/T3): "a player cannot yet play the boss fight hands-off, cannot die to it" — 11.2 is the combat/run-end
half of the story that fixes that. **11.3** adds the SCENES on top; **11.4** the affinity call sites; **11.5**
the outpost/reveal render; **11.6** the meta spend.

The single most important rule: **wire the EXISTING seams; do not fork a parallel combat/run-end path.** Every
piece already exists (enumerated below with pinned method signatures). Read the actual source before wiring —
a wrong method/constant name is the primary review-cycle cause (the 11.1 Round-1 review caught exactly this
class of error: an HP field mis-sourced on `RunState`, a `range` vs `weapon_reach` key mix-up).

### The seam map (the exact as-built pieces 11.2 wires) — READ THE SOURCE

Read each before wiring; the method signatures + constants are load-bearing. Absolute paths:

| Seam | Existing contract (method/const) | Path | Load-bearing detail |
|---|---|---|---|
| **v0 combat auto-resolve (the thing 11.2 replaces for live nodes)** | `RunOrchestrator._resolve_combat(node)` → returns `resolution: "combat_auto_resolved"` on successful generation | `godot/scripts/run/run_orchestrator.gd:875` | Today: `NodeEnterCommand` → `LevelGenerator.generate` → **auto-resolve on success** → `NodeExitCommand`. Read `payload["level_seed"]` on success, NEVER `result.seed` (the 3.7 footgun). The v0 boundary is documented at `run_orchestrator.gd:25-29`. |
| **Node entry (route→level bridge)** | `NodeEnterCommand.new(seq_id).execute(run)` → `metadata["level_request"]` (a `GenerationRequest`); combat set is `NodeEnterCommand.NODE_TYPE_RECIPE` (`combat`→`small_combat_basic`/SIZE_SMALL, `elite_combat`→`medium_combat_basic`/SIZE_MEDIUM) | `godot/scripts/core/commands/node_enter_command.gd` | Draws ZERO RNG (the request is pure; the `level` stream is drawn by generation LATER). Transitions ACTIVE_ROUTE → NODE_RESOLUTION. |
| **Level generation → board** | `LevelGenerator.generate(request, recipe_repo, enemy_repo)` → `GenerationResult`; on success `payload["board"]` is the board snapshot, `payload["level_seed"]` the seed string | `godot/scripts/generation/level/level_generator.gd:66` | Restore a live `BoardState` from `payload["board"]` via `BoardState.try_from_snapshot(...)` (the STRICT parse — the 1.3 validate-then-reject). |
| **Live combat context** | `TacticalActionContext.new(board, turn_state, streams, pending_telegraphs)` | `godot/scripts/tactical/tactical_action_context.gd` | The board + `TacticalTurnState.new(1, Phase.PLAYER_PLANNING, HERO_ID)` + the run-level `RngStreamSet` + an empty `pending_telegraphs`. `has_required_state()` gates the resolvers. |
| **Player intent → command** | `TacticalCommandBridge.build_command(context, intent)` (intents `move`/`attack`/`inspect`); or the commands directly (`MoveCommand.new(actor, cell)`, `AttackCommand.new(actor, cell, weapon)`) | `godot/scripts/ui/command_bridge/tactical_command_bridge.gd`; `scripts/core/commands/move_command.gd`, `attack_command.gd` | The live loop submits player intent; the SCENE (11.3) submits it from taps. For 11.2's headless driver, a scripted/AI hero (like `Epic1MicroCombatScenario`) drives the player commands. |
| **Enemy turns** | `EnemyTurnResolver.new(enemy_repo, HERO_ID).resolve_after_player_action(context, player_result)` | `godot/scripts/tactical/turns/enemy_turn_resolver.gd:29` | Simulate-then-apply; requires the player_result carried `advances_turn: true`. Mirrors the boss resolver's discipline. |
| **Combat outcome (win/loss detection)** | `CombatOutcomeEvaluator.new(HERO_ID).evaluate(board, outcome_state, event_log)` → sets `CombatOutcomeState` to `STATE_VICTORY` / `STATE_DEFEAT`; `primary_player_dead` → defeat, `living_enemy_count == 0` → victory | `godot/scripts/tactical/outcomes/combat_outcome_evaluator.gd:16`; `combat_outcome_state.gd` (`STATE_ACTIVE`/`STATE_VICTORY`/`STATE_DEFEAT`) | This is the HERO-0-HP DETECTION for a level node. A `STATE_DEFEAT` → the hero-death source (AC2). |
| **The reference pattern (a full live combat to outcome)** | `Epic1MicroCombatScenario._run_scripted_path(...)` — the canonical "drive a live combat to win/loss" | `godot/scripts/tactical/scenarios/epic_1_micro_combat_scenario.gd` | READ THIS. It composes `TacticalActionContext` + `EnemyTurnResolver` + `CombatOutcomeEvaluator` exactly the way the live combat driver must. Generalize it for a run node. |
| **Run-end resolution (death + completion)** | `RunOrchestrator.resolve_run_end(outcome)` → `CompleteRunCommand(outcome, seq_id)`; death cause in `RUN_FAILED_CAUSES` → `PHASE_FAILED` + `run_failed`; completion (`completed`/`victory`) → `PHASE_COMPLETED` + `run_completed` | `godot/scripts/run/run_orchestrator.gd:741`; `scripts/core/commands/complete_run_command.gd` | `RUN_FAILED_CAUSES = [hero_death, level_defeat, boss_defeat, abandoned]`. `RUN_END_DESTINATION_OUTPOST = "outpost"`. Draws ZERO RNG. AC3 idempotency: a re-resolution of a terminal run → `run_already_terminal`. |
| **Boss-victory continuation (production call site AC3)** | `RunOrchestrator.resolve_boss_victory()` — clears the boss node (REVEAL_CLEARED + idempotent `cleared_node_ids` append) + `resolve_run_end(&"victory")` | `godot/scripts/run/run_orchestrator.gd:784` | BUILT in 9.5; invoked ONLY from tests today. AC3 gives it a production call site. `RUN_COMPLETED_OUTCOME_VICTORY = "victory"`. |
| **Boss fight loop + defeat detection** | `BossTurnResolver.new(def, BOSS_ID, HERO_ID)`: `.resolve_boss_turn(context)`, `.resolve_phase_transitions(context, prev_phase_idx, seq_base)`, `.detect_boss_defeat(context, seq_base)` → `boss_defeated` when `boss.is_dead()` | `godot/scripts/tactical/turns/boss_turn_resolver.gd` | ZERO RNG. The sequence-id seam: thread the shared cursor `resolve_phase_transitions → detect_boss_defeat → run-end` (see below). `larval_avatar` via `BossRepository.create_baseline_repository().get_boss(BOSS_ID)`. |
| **Boss-setup terminus (the 9.1 park)** | `run_to_completion()` STOPS at the boss setup with `boss_encounter_pending() == true`; `boss_arena_payload()` carries the arena `board_snapshot` + `boss_slot` + `entrance` | `godot/scripts/run/run_orchestrator.gd:271` (loop `break` at `:288`), `:944` (`_resolve_boss`) | The auto-play (AC3) resumes from this terminus, restores the arena board, places the boss + hero, and plays the fight. `FinaleRunFixture.drive_to_boss_terminus(seed)` is the existing entry point. |
| **First-death latch (records off the real death — AC2)** | `RecordFirstDeathCommand.new(seq_id).execute(run)` — death-only gate `run.phase == PHASE_FAILED`, once-only `ProfileSnapshot.first_death_recorded` latch | `godot/scripts/core/commands/record_first_death_command.gd` | UNCHANGED. Eligibility-INDEPENDENT (a manual-seed first death still latches — the ratified 8.5 Option A). |
| **First-victory latch (records off the real victory — AC3)** | `RecordFirstVictoryCommand.new(seq_id).execute(run)` — victory-only gate `run.phase == PHASE_COMPLETED`, once-only `ProfileSnapshot.first_victory_recorded` latch | `godot/scripts/core/commands/record_first_victory_command.gd` | UNCHANGED. Eligibility-INDEPENDENT (mirrors 8.5). |
| **The existing full-run integration harness (extend, don't rebuild)** | `test_finale_full_run.gd` — drives start → `run_to_completion` (boss terminus) → live boss fight (explicit turns) → `resolve_boss_victory()` / driven death → `RunSummary` + `RunEndOutcome` | `godot/tests/integration/finale/test_finale_full_run.gd`; fixture `tests/fixtures/run/finale_run_fixture.gd` | This is the harness 11.2 EXTENDS with (a) an AUTO-PLAYED boss fight (AC3) and (b) an AUTO-FIRED hero-death SOURCE (AC2 — replacing the driven `resolve_run_end(&"hero_death")` at line 152). |

### The two atomicity twins (AC4 forcing tests) — the EXACT shapes

Two structurally-identical two-step transitions, one hardened, one not:

- **`CompleteRunCommand._resolve_completed`** (`complete_run_command.gd:220-249`) — HARDENED. It captures
  `phase_before` (`:222`) and RESTORES it (`run.phase = phase_before`, `:243`) on a step-2 failure. Today the
  restore is UNREACHABLE (both edges always legal), so `test_complete_run_command.gd::
  _two_step_completion_is_atomic_on_a_hypothetical_step_two_failure` asserts only the observable invariant.
  The live victory path (AC3) drives this two-step for real (from ACTIVE_ROUTE). **AC4 Task 4:** add a FORCING
  test that makes step 2 fail and asserts the byte-identical restore.
- **`NodeResolvePlaceholderCommand._resolve_boss`** (`node_resolve_placeholder_command.gd:211-280`) — NOT
  hardened. It runs the same ACTIVE_ROUTE → NODE_RESOLUTION → COMPLETED two-step WITHOUT capturing/restoring
  `phase_before` — so a step-2 failure would leave the run parked in NODE_RESOLUTION (the same theoretical gap
  `_resolve_completed` fixed). **BUT since 9.1 the live boss dispatch is `BossNodeEnterCommand` + (9.5)
  `resolve_boss_victory` — the placeholder boss branch is RETAINED but is NO LONGER the orchestrator's live
  boss path.** So 11.2's recommended live path (the `resolve_boss_victory` continuation) does NOT drive
  `_resolve_boss` → the twin stays UNREACHED. **Recommended: RE-RECORD the twin as still-parked in
  `deferred-work.md` (it is not 11.2's to harden if 11.2 doesn't drive it). Only harden it if you add a live
  driver of the placeholder boss branch.** Do not make a dead defensive change to a branch nothing drives; do
  not silently drop the T3 item.

### The sequence-id seam contract (the boss auto-play MUST honor it)

`BossTurnResolver.resolve_phase_transitions` and `.detect_boss_defeat` emit SYSTEM events (`boss_phase_changed`
/ `boss_defeated`) that they do NOT board-apply — so `context.board`'s `_next_sequence_id` is NOT advanced by
them. A stream-merging caller (the AC3 boss auto-play, interleaving boss-action + phase-change + boss_defeat +
run_completed into ONE ordered run log) MUST reserve the id range: pass an explicit `sequence_id_base >= 0`
(above the run's route-event ids so the interleaved fight ids don't collide with the `run_completed` id the
orchestrator assigns), thread the returned `next_sequence_id_after` cursor through
`resolve_phase_transitions → detect_boss_defeat → the run-end append` — NEVER the board-baseline
`next_sequence_id()` fallback (which reads without advancing → duplicate ids). `test_finale_full_run.gd`
(`_drive_full_run_to_victory`, `fight_base = 100000`) is the WORKING pattern — the auto-play reuses it. Assert
every merged sequence id is unique (the existing `_sequence_ids_are_unique_across_the_interleaved_stream` test).

### Previous-story intelligence & the Epic-9 retro (the debt 11.2 pays down)

- **11.1 (the immediately-prior story) is DONE and is 11.2's design input.** It shipped
  `_bmad-output/planning-artifacts/ux-appendix-run-flow.md` — the run-flow UX appendix with pinned screen
  contracts. **11.2 is a DOMAIN story, not a scene story, so the appendix's SCREEN designs are 11.3/11.5's to
  build** — but two appendix items bear on 11.2's seam:
  - **§1.4 "Combat outcome" state:** the HUD renders the `outcome` slot the domain reports; the appendix
    explicitly notes "Hero DEATH as a run-ender is 11.2." 11.2 makes that `outcome` a REAL run-ender. Keep the
    domain outcome (`STATE_VICTORY`/`STATE_DEFEAT` → run-end) faithful so 11.3's HUD renders a real signal.
  - **§16.1 non-gap "No fail-loud gate/table extension for 11.1 … concerns CODE stories that add events /
    content families / save keys (11.2+ territory)."** This is the heads-up FOR 11.2: IF you add a new
    `DomainEvent.Type`, a gate/check (the `expected_ids` exhaustiveness pin) WILL fail-loud on the new member
    — that is EXPECTED; register/extend it in the same change. 11.2 should PREFER reuse (the run-end/victory/
    death vocabulary already exists) — but if a new event is genuinely needed, this is the discipline.
- **Epic-9 retro T1/T2/T3 (the carried debt 11.2 discharges):**
  - **T1 (HIGH — the run-flow/HUD story, "an effective Epic-10 prerequisite"):** Epic 11 IS T1. 11.2 is its
    combat/run-end half: "wire the auto-played run loop that drives the boss fight inside `run_to_completion`
    (consuming 9.5's `resolve_boss_victory()` continuation + the 9.3 live turn loop), the live hero-DEATH
    SOURCE (a combat loop detecting the hero at 0 HP → `PHASE_FAILED`, WITHOUT perturbing
    interrupted==uninterrupted determinism)." That is verbatim 11.2's AC1/AC2/AC3.
  - **T2 (MED-HIGH — FR32 loss half):** "v0/9.5 resolve the death PATH with a driven death; the live SOURCE
    (auto-firing `CompleteRunCommand` on a mid-fight hero death) is still absent." 11.2 AC2 builds it.
  - **T3 (LOW-MED — forcing tests):** "9.4's `_resolve_completed` step-2-failure restore … and the
    un-hardened `NodeResolvePlaceholderCommand._resolve_boss` two-step atomicity TWIN are all
    unreachable-and-lightly-tested today. When a story makes any reachable (… a live death source …), add the
    forcing regression + (for the twin) mirror 9.4's capture+restore fix. Owner: whichever story makes the
    path reachable (likely T1 for the death source)." That is 11.2 AC4 Task 4.
- **Epic-9 retro Key Insight 2 (the trap to watch):** "when you replace a v0 placeholder with a live path,
  re-audit every DERIVED read that keyed off the placeholder's SIDE EFFECTS." The boss lesson: `boss_cleared`
  derived from the placeholder's boss-node clear, which the live victory (correctly) does not do — so 9.5
  added the `resolve_boss_victory()` reconciliation. **11.2's analogous audit: when the live COMBAT loop
  replaces `_resolve_combat`'s auto-resolve, re-audit what `_resolve_combat`'s side effects were** (it calls
  `NodeExitCommand` → clears the node + returns to ACTIVE_ROUTE; it advances the sequence counter; it returns
  `level_seed`/`recipe_id` diagnostics). The live victory path must preserve the same node-clear + forward
  advance; a live DEFEAT must NOT clear/exit (a dead hero ends the run). Any downstream read that assumed a
  combat node always clears (e.g. `RunSummary.nodes_cleared`) must stay correct.
- **Epic-9 retro Insight 7 ("reachable via the shell + provable in an integration test" ≠ "playable
  hands-off"):** Epic 9 hit the FORMER; 11.2 (+ 11.3) reaches the LATTER for combat/run-end. 11.2 is the
  "auto-play + live death source" step; the human-felt play pass (retro D3) waits for 11.3's scenes.

### Deferred-work overlaps folded in (ONLY entries touching this story's surface)

From `_bmad-output/implementation-artifacts/deferred-work.md` — the ledger is project-wide; these overlap
11.2's seam. Fold them in as above; do NOT reopen unrelated items:

- **The LIVE combat-DEATH CALL SITE / hero-death → `PHASE_FAILED` live SOURCE** (the pre-existing fence,
  re-carried across Epics 8-9; ledger lines ~15, ~66, ~83, ~104, ~146-149, ~532-538). 11.2 AC2 RESOLVES it.
  The fence's exact wording: "v0 has NO live combat death source (combat auto-resolves to success) … the
  `resolve_run_end` hook is deliberately NOT wired into the auto-resolve loop, preserving the
  interrupted==uninterrupted determinism." 11.2 wires the live source WHILE preserving that determinism (the
  live loop is additive / the default non-live path is unchanged).
- **The `NodeResolvePlaceholderCommand._resolve_boss` two-step atomicity TWIN** (ledger lines ~34, ~43,
  ~177). 11.2 AC4 Task 4 either hardens it (IF driven) or re-records it as still-parked (recommended — the
  live path uses `BossNodeEnterCommand`+`resolve_boss_victory`, not the placeholder boss branch).
- **The `_resolve_completed` step-2-failure restore forcing test** (ledger line ~42). 11.2 AC4 Task 4
  RESOLVES it (a forcing test) — the live victory path makes the two-step reachable for real.
- **`resolve_boss_victory()` has no live production call site** (the 9.5 review `[Review][Decision]`, ledger
  line ~13). 11.2 AC3 RESOLVES it (a production call site).
- **The `victory` outcome `[Decision]`** (ledger line ~25): `victory` is a COMPLETION marker in
  `CompleteRunCommand` (NOT a parallel `run_victory` event) — the run-victory IS `run_completed` +
  `outcome == victory`. 11.2 CONSUMES this (do not add a parallel victory event/path).
- **NOT 11.2's to resolve (leave parked — they are 11.4/11.5/11.6):** the live AFFINITY call sites (Darkness/
  Scorched/Cursed/Flooded on the live board) → **11.4** (`assign_affinity` stays un-wired in 11.2's live
  combat); the outpost SCENE + reveal RENDER + the Oath-Shard summary↔profile coupling → **11.5**; the
  meta-SPEND / unlock APPLICATION → **11.6**.

### Project Structure Notes

- **Where the code goes (project-context "Code Organization"):** the live combat driver + the run-end auto-fire
  wiring belong in the `run` domain (`godot/scripts/run/` — alongside `RunOrchestrator`) or as a thin
  orchestrator extension, since they SEQUENCE existing commands/resolvers and own no gameplay decision a
  command doesn't. The tactical building blocks (`EnemyTurnResolver`, `CombatOutcomeEvaluator`,
  `BossTurnResolver`) stay in `scripts/tactical/`; do NOT move them. Tests go under `godot/tests/` mirroring
  the domain: run/orchestrator tests under `tests/unit/run/` (or the existing orchestrator test location) +
  `tests/integration/finale/` for the full-run auto-play (EXTEND `test_finale_full_run.gd`).
- **`RunOrchestrator` is a scene-free `RefCounted` domain service (NOT a Node/autoload/scene)** — keep it so.
  The live loop must have NO `get_tree`/`get_node`, register no autoload, add no scene. It draws RNG ONLY via
  the run-level `RngStreamSet` it already threads (`combat`/`level` streams) — NEVER `randi`/`randf`.
- **Do NOT modify** `prototype/` (frozen), `_bmad/` (installer-managed), the `.agents/` legacy skills, or the
  pinned seed-regression fingerprint files (unless a DELIBERATE re-pin is required in the same change — and it
  must not be, since the default paths are untouched).
- **The auto-play (AC3) is OPT-IN, never the default.** The default `run_to_completion` MUST keep stopping at
  the boss-setup terminus (its current behavior) so `FinaleRunFixture.drive_to_boss_terminus` + the reward/
  route determinism tests + the fingerprints stay green. Add auto-play as a flag/callback/separate driver.

### Project Context Rules

Extracted from `project-context.md` (the canonical rulebook — refreshed after Epic 9). The rules that bear
on THIS story:

- **Domain-first, scene-free authority.** "Godot scenes, `Control` nodes, audio, VFX, and animation are
  presentation. They must not own authoritative tactical state." The live combat loop is DOMAIN logic (a
  `RefCounted` driver over `BoardState`/`TacticalActionContext`) — the SCENE that renders it is 11.3's. The
  loop reads/mutates domain state through commands/resolvers, never through a scene.
- **Named-RNG rule (line ~96).** Gameplay-affecting randomness uses its assigned stream: combat procs → the
  `combat` stream; level generation → the `level` stream (already drawn). NEVER `randi`/`randf`/a fresh
  `RandomNumberGenerator`. The live loop adds NO new stream (the 7 streams are frozen) and NO new draw SITE on
  the non-live path.
- **Determinism / interrupted==uninterrupted (NFR13, lines ~114/~120/~379/~392).** A route-position save
  composed in the (non-live) `run_to_completion` loop must round-trip byte-identically. The live loop must not
  perturb that — the default auto-resolve path's stream advancement is UNCHANGED; the live loop is additive/
  opt-in. Snapshots are pure reads (consume NO RNG, execute NO command, advance NO turn). AC4 proves a fixed
  seed is byte-deterministic end-to-end.
- **The 23-key `RunSnapshot` gate (lines ~374/~394).** Do NOT add a new top-level `RunSnapshot` key for
  live-combat / in-node state. The live in-node board / pending fight state is EPHEMERAL (not persisted); a
  mid-encounter save is explicitly a LATER in-node-save story (out of 11.2 scope). The 23-key gate stays 23.
- **`ProfileSnapshot.SCHEMA_VERSION == 1` (line ~245).** The first-death/first-victory latches are EXISTING
  profile fields; 11.2 records off them, adds no new profile field, forces no migration (8.7's matrix stays
  green).
- **Append-only `DomainEvent.Type` (lines ~251/~399).** The current enum tail is `BOSS_DEFEATED` (index 47).
  PREFER reusing the existing run-end/victory/death/combat-outcome events. IF a new event is genuinely needed,
  append at the enum END + wire end-to-end (factory + payload validator + BOTH id maps + JSON round-trip +
  malformed-negatives + the exhaustive `expected_ids` pin) — the gate fail-loud on the new member is EXPECTED.
- **Difficulty is a HARD non-goal (line ~267).** The live combat / boss auto-play must NOT introduce any
  difficulty knob — it plays the authored content deterministically. The boss stays authored 3-phase escalation.
- **Do NOT auto-wire the caller-driven orchestrator methods into the DEFAULT loop (lines ~392/~404).**
  `generate_reward_offer` / `generate_event_offer` / `assign_affinity` stay caller-driven — the live combat
  loop does NOT auto-fire them (auto-firing perturbs interrupted==uninterrupted determinism + trips the
  `*_pending` guards). 11.2's live combat is a plain generated level (no reward roll, no event offer, no
  affinity) — exactly as the v0 orchestrator combat is today.
- **Godot / testing.** Godot 4.6.3 stable, typed GDScript. Every command gets valid + invalid/no-mutation
  tests; new systems get a test location before implementation. The FULL headless suite is the gate
  (166 PASS at Epic-9 close — 11.2 GROWS it): run via PowerShell (the `godot` binary is not on the Bash PATH):
  `godot --headless --path C:\Sealsworn\godot --scene res://tests/headless/test_runner.tscn --quit-after 10`.
  Apply the false-PASS grep guard (the only acceptable stderr `ERROR:` lines are the documented negatives:
  int64-overflow ×2, malformed-JSON ×3, `invalid_node_type` ×1 — plus any NEW documented negative-path test).
  Run `git diff --check`.

### References

- **Story source (verbatim ACs):** `_bmad-output/planning-artifacts/epics.md` — Epic 11 §"Story 11.2: Live
  Combat Loop and Hero Death Source" (lines ~2618-2644). Epic 11 List entry + implementation notes:
  lines ~489-495. Epic 11 section header + sequencing: lines ~2587-2591. The 2026-07-04 Epic-11-insertion
  traceability: lines ~403-405; FR32 as-built note (the live hero-death trigger lands in 11.2): line ~307.
- **The immediately-prior story (design input):** `_bmad-output/implementation-artifacts/
  11-1-run-flow-ux-appendix-and-screen-contracts.md` (DONE) + its deliverable
  `_bmad-output/planning-artifacts/ux-appendix-run-flow.md` (§1.4 the combat `outcome` state → "Hero DEATH as
  a run-ender is 11.2"; §16.1 the "new event → gate fail-loud is expected for 11.2+" non-gap).
- **The Epic-9 retrospective (the debt 11.2 pays):** `_bmad-output/implementation-artifacts/
  epic-9-retro-2026-07-04.md` §4 (Charlie: the uncalled boss-defeat→victory chain + the missing live
  hero-death source), §7 risks 1-2 (the run-flow/HUD prerequisite; FR32 loss half untriggerable live), §8
  T1/T2/T3 (the carried debt), Key Insights 2 + 7.
- **FR/NFR text (`epics.md` inventory):** FR1 (line 24 — full loop), FR31 (85 — defeat the Larval Avatar),
  FR32 (87 — hero death → return to outpost, the loss half 11.2 makes live), NFR13 (190 — deterministic under
  seeded execution), NFR14 (192 — headless without rendering/UI). FR22/FR23 (66/69 — damage/death/victory +
  enemy turns after committed actions).
- **Existing source (READ before wiring — all under `godot/`):**
  `scripts/run/run_orchestrator.gd` (the seam — `_resolve_combat`:875, `resolve_run_end`:741,
  `resolve_boss_victory`:784, `run_to_completion`:271, `_resolve_boss`:944);
  `scripts/core/commands/complete_run_command.gd` (`_resolve_completed`:220, the step-2 restore:243,
  `RUN_FAILED_CAUSES`, `COMPLETION_OUTCOMES`);
  `scripts/core/commands/node_resolve_placeholder_command.gd` (`_resolve_boss`:211 — the un-hardened twin);
  `scripts/core/commands/node_enter_command.gd` (`NODE_TYPE_RECIPE`, `level_request`);
  `scripts/core/commands/node_exit_command.gd`;
  `scripts/core/commands/record_first_death_command.gd`, `record_first_victory_command.gd`;
  `scripts/generation/level/level_generator.gd` (`generate`:66, `payload["board"]`/`payload["level_seed"]`);
  `scripts/tactical/turns/enemy_turn_resolver.gd` (`resolve_after_player_action`:29);
  `scripts/tactical/turns/boss_turn_resolver.gd` (`resolve_boss_turn`, `resolve_phase_transitions`,
  `detect_boss_defeat` — the sequence-id seam);
  `scripts/tactical/outcomes/combat_outcome_evaluator.gd` (`evaluate`:16 — the hero-0-HP detection),
  `combat_outcome_state.gd` (`STATE_VICTORY`/`STATE_DEFEAT`);
  `scripts/tactical/scenarios/epic_1_micro_combat_scenario.gd` (THE reference live-combat pattern);
  `scripts/core/events/domain_event.gd` (`RUN_FAILED_CAUSES`:170, `RUN_COMPLETED_OUTCOME_VICTORY`:161,
  `RUN_END_DESTINATION_OUTPOST`:182, `FIRST_DEATH_LINE_ID`:216 — the enum tail is `BOSS_DEFEATED`).
- **The test harness to EXTEND (do not rebuild):** `godot/tests/integration/finale/test_finale_full_run.gd`
  (the full-run-through-the-shell integration — extend with auto-play + the auto-fired hero death) +
  `test_finale_seed_regression.gd` + `tests/fixtures/run/finale_run_fixture.gd`
  (`drive_to_boss_terminus`/`boss_arena_board`). The step-2 forcing test extends
  `godot/tests/unit/core/test_complete_run_command.gd`.
- **Deferred-work ledger (overlapping entries):** `_bmad-output/implementation-artifacts/deferred-work.md`
  (the LIVE combat-death SOURCE fence ~15/~66/~83/~104/~146/~532; the `_resolve_boss` twin ~34/~43/~177; the
  `_resolve_completed` step-2 forcing test ~42; the `resolve_boss_victory` call-site Decision ~13; the
  `victory`-outcome Decision ~25).
- **Auto-gds Epic-11 retro-notes (epic-wide constraints from earlier stories):** `_bmad-output/auto-gds/
  retro-notes/epic-11.md` §"Story 11-1" — the two carried notes both bear on 11.2: (Phase-3) the Epic-9
  forward-prep was re-mapped to Epic 11 (11.2 is the first CODE story that inherits the live-loop debt);
  (Phase-7) "dense internally-cross-referenced spec docs need a final resolve-every-§N sweep" + "field-source
  attributions deserve pinned-key rigor" (the class of error to avoid — cite the EXACT as-built method/const
  names, verified against source, not from memory).
- **Testing command + Godot binary:** `CLAUDE.md` (the full-suite command) + the user memory note
  `godot-headless-test-binary-path` (the `godot` binary is not on the Bash PATH — run the suite via
  `C:/Users/Rasmus/Godot_v4.6.3-stable_win64.exe/Godot_v4.6.3-stable_win64_console.exe` from Bash, or the
  PowerShell `godot` command; apply the false-PASS grep guard).

## Dev Agent Record

### Agent Model Used

Opus 4.8 (1M context) — `claude-opus-4-8[1m]`, via the auto-gds `gds-dev-story` delegate.

### Debug Log References

- Baseline suite (pre-change): 166 PASS / 0 FAIL, "Headless tests passed.", the 6 documented stderr negatives only.
- Final suite (post-change): **168 PASS / 0 `^FAIL`**, "Headless tests passed.", exit 0; false-PASS grep clean (int64-overflow ×2, malformed-JSON ×3, `invalid_node_type` ×1, ZERO `SCRIPT ERROR`); `git diff --check` clean.
- Hero-driver tuning probes (scratchpad, not committed): the scripted focus-fire hero is fully DETERMINISTIC for a fixed seed (same outcome + round count every run). Verified winning combat seeds: 4242/99/12345/55/314159 (a strong sword hero clears the generated Small board); a 1-HP dagger hero deterministically LOSES in 2 rounds (the live hero-death source). The boss auto-play kills the boss at round 15 with a 60-HP sword hero comfortably alive (deterministic).

### Completion Notes List

- **Design: wire the EXISTING seams, additive + opt-in.** The whole story is a scene-free DOMAIN wiring — NO `.tscn`/`Control`/presenter/autoload (that is 11.3). `LiveCombatResolver` is the generalized `Epic1MicroCombatScenario`; the `RunOrchestrator` live methods (`resolve_current_node_live` / `resolve_combat_node_live` / `run_to_completion_live` / `auto_play_boss_fight` / `auto_play_full_run`) are ADDITIVE — the DEFAULT `_resolve_combat` / `resolve_current_node` / `run_to_completion` are byte-identical (ZERO code-logic deletions; only the class doc comment was extended). This preserves every seed-regression fingerprint + the interrupted==uninterrupted route-position determinism.
- **The hero loadout is DRIVER-SUPPLIED (a documented scope boundary).** 11.2 wires the run-combat SEAM, not the class-kit → combat loadout (a later story). The scripted hero's HP + weapon are caller-supplied (a strong melee `sword` hero by default — reliable adjacent damage, ZERO combat RNG). A weak/low-HP hero drives a real board DEFEAT (the live hero-death source). This mirrors how `test_finale_full_run.gd` supplies the hero for the boss fight. The hero is placed at the generated level's `entrance` cell (generation places enemies only).
- **Robustness posture (recorded, worth the retro):** the scripted hero (attack-in-range / focus-fire-approach, bounded round cap) is DETERMINISTIC but does NOT win every conceivable generated seed — a genuinely mutually-unreachable straggler (e.g. an ash_seer boxed behind a wall the melee hero can't path to) deterministically hits the cap and `LiveCombatResolver` FAILS LOUD (`live_combat_did_not_resolve` — never a fabricated outcome), which `resolve_combat_node_live` surfaces as `live_combat_failed` (a hard run-progression error, no partial progression). The live-flow tests + the boss auto-play use VERIFIED seeds (4242 canonical), the same approved-seed-catalog discipline the finale suite uses. A future story that needs a universally-winning live run should invest in a stronger hero driver (line-of-sight-aware ranged targeting) or the class-kit loadout wiring — 11.2's live loop is the seed-batch/simulation + AC-proof driver, not yet the shipped hands-off game loop (that is 11.3's HUD pass).
- **Death cause split (documented, both pre-allowlisted):** a live LEVEL/encounter death fires `resolve_run_end(&"hero_death")`; a hero death DURING the boss auto-play fires `resolve_run_end(&"boss_defeat")` (the boss-context cause). Both are in `DomainEvent.RUN_FAILED_CAUSES` — NO cause added.
- **Sequence-id seam (the review-class trap avoided):** the boss auto-play keeps TWO event streams DISTINCT because they live in different id spaces — `run_events` (the run-level SYSTEM stream: `boss_phase_changed` + `boss_defeated` from the reserved `BOSS_FIGHT_SEQUENCE_BASE = 100000`, extended with the `run_completed`/`run_failed` from the orchestrator's own lower counter) is asserted UNIQUE (the seam contract); `board_events` (the hero/boss tactical action events, the arena board's OWN counter) is surfaced separately, NOT mixed into the run-level uniqueness stream. Mixing them was the first cut and produced a real duplicate-id (`id 31 repeated`) — fixed by the split.
- **NO new event / stream / save key / schema bump / fingerprint move.** The run-end/victory/death/combat-outcome vocabulary was REUSED. The 23-key `RunSnapshot` gate stays 23 (in-node fight state is EPHEMERAL); `ProfileSnapshot.SCHEMA_VERSION == 1`; the 7 named RNG streams; the `DomainEvent.Type` enum tail unchanged. All invariant + seed-regression tests PASS.
- **Forcing test (Epic-9 T3 discharged):** the `_resolve_completed` step-2 restore is now DRIVEN via a test-only `ForcedStepTwoFailureRunState` subclass (`super(next_phase)` delegation; the test builds + seats it). The `_resolve_boss` atomicity TWIN stays PARKED (11.2's live path doesn't drive the placeholder boss branch) — re-recorded in `deferred-work.md`, not silently dropped.
- **NOT done (correct scope fences):** no scenes/HUD (11.3), no live affinity call sites (11.4 — `assign_affinity` stays un-wired; the live combat runs a plain generated level), no outpost render / meta-spend (11.5/11.6), no live in-node save.

### File List

**Production (new):**
- `godot/scripts/run/live_combat_resolver.gd` — the scene-free live combat driver (the generalized Epic-1 micro-combat loop + the deterministic scripted hero + the single-target `drive_hero_step_against` the boss auto-play reuses).

**Production (modified):**
- `godot/scripts/run/run_orchestrator.gd` — additive live methods (`resolve_current_node_live`, `resolve_combat_node_live`, `run_to_completion_live`, `auto_play_boss_fight`, `auto_play_full_run`, `_auto_play_boss_rounds`, `_live_hero_weapon`) + the `HERO_ID`/`BOSS_ID`/`BOSS_FIGHT_SEQUENCE_BASE` consts + the tactical/boss/live-combat preloads + the extended V0/live-flow boundary doc comment. The default methods (`_resolve_combat`, `resolve_current_node`, `run_to_completion`, `_resolve_boss`, `resolve_run_end`, `resolve_boss_victory`) are UNCHANGED.

**Tests (new):**
- `godot/tests/unit/run/test_live_combat_resolver.gd` — the LiveCombatResolver unit test (AC1 victory-from-board + AC2 defeat-is-real-hero-death + AC4 byte-determinism + zero-combat-RNG + edge/error paths).
- `godot/tests/unit/run/test_live_run_flow.gd` — the live orchestrator wiring (AC1 live combat node through the run flow + the v0 auto-resolve is unchanged/distinct; AC2 the live hero-death source + the first-death latch off the real terminal state; AC4 idempotency + the default loop is unperturbed).
- `godot/tests/unit/core/support/forced_step_two_failure_run_state.gd` — the test-only RunState subclass for the AC4 step-2-restore forcing test.

**Tests (modified):**
- `godot/tests/integration/finale/test_finale_full_run.gd` — extended with the AC3 auto-play tests (`auto_play_full_run` → `resolve_boss_victory` production call site + `RunSummary.boss_cleared`; the first-victory latch off the real auto-played victory; the auto-played run byte-determinism; the boss-fight hero-death auto-fire; the interleaved sequence-id uniqueness).
- `godot/tests/unit/core/test_complete_run_command.gd` — added the AC4 forcing test (`_two_step_completion_restores_phase_on_a_forced_step_two_failure`) + the `_forced_step_two_run()` helper.

**Tracking:**
- `_bmad-output/implementation-artifacts/deferred-work.md` — the 2026-07-05 11.2 entry (resolved fences + re-recorded still-open splits).
- `_bmad-output/implementation-artifacts/sprint-status.yaml` — story 11-2 → in-progress → review.
- `_bmad-output/implementation-artifacts/11-2-live-combat-loop-and-hero-death-source.md` — this story file (tasks, Dev Agent Record, status).
