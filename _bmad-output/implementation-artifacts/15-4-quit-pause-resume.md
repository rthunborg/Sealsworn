---
baseline_commit: 7a2f1b6
---
# Story 15.4: Quit, Pause and Resume

Status: ready-for-dev

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a player,
I want to leave a run and come back to it,
so that a descent survives closing the game.

## Context & Why This Story Exists

Epic 15 ("Playtest Response") is the **third pre-ship playtest-response epic** (the Epic-13/14 pattern), added 2026-07-24 after a post-Epic-14 agent-driven desktop playtest confirmed the loop is **completable end-to-end for the first time** but surfaced 20 new findings (record `playtest-sessions/agent-playtest-2026-07-20.md`; triage `…-triage.md`; `sprint-change-proposal-2026-07-24.md`). Story 15.1 (Band 1) un-hid the HUD/log; 15.2 corrected the attack-preview number; 15.3 made threats telegraph. Story 15.4 continues **Band 2 — Correctness & unwired surfaces (15.2–15.7)** and delivers the **quit / pause / resume** loop: a run the player leaves must survive closing the game and be resumable from a Continue affordance at boot.

> **The finding:** the game has **no way to leave a run and come back to it.** There is no in-game pause/menu on the live board, no Continue at boot, and — critically — **nothing in the live flow ever persists the run's route position.** A player who closes the app loses the descent entirely.

**Root cause (grep-verified — the seams exist but nothing DRIVES them).** Epic 2 (Stories 2.7/2.8) and Story 4.6 shipped a **complete, tested between-node route-position save/resume domain layer**, but Epic 11's live run-flow left the on-screen affordances that would drive it deliberately deferred (the "later HUD/boot-flow story"). The three concrete gaps:

1. **No route-position save is ever written during a live run.** `SaveManager.autosave_route_position(snapshot)` (`save_manager.gd:42`) and `RunOrchestrator.compose_route_position_snapshot()` (`run_orchestrator.gd:383`) exist and are tested, but the ONLY call site of the autosave callback is the **hands-off** `run_to_completion(request_route_position_save_callback)` (`run_orchestrator.gd:313-345`) — the fingerprint-critical auto-resolve driver, **not** the live/interactive flow. The interactive path (`gameplay_shell_presenter.gd` → `run_to_completion_live` / `begin_interactive_combat_node` / `finish_interactive_combat_node`) autosaves **nothing**. On-screen play never persists a resumable position.
2. **No boot Continue.** `BootController._enter_first_flow_stage()` (`boot_controller.gd:19-28`) **unconditionally** goes to `hero_select`. It never checks for a saved run. The `save_recovery_presenter.gd` scene (which already resumes → seats → routes to the route map) is **not reachable** — `RunFlowRouter.STAGES` is `launch / hero_select / route_map / tactical_board / run_end / outpost`, with **no `save_recovery` stage** (`run_flow_router.gd:32-53`).
3. **No new-run-vs-saved-run guard.** `hero_select_presenter._on_confirm_pressed()` (`hero_select_presenter.gd:298-327`) starts a fresh run with no has-saved-run check and no overwrite confirmation; the stale save simply lingers until something overwrites it.

**This story WIRES the on-screen quit/pause/resume affordances on top of the shipped, tested save/resume seams — it is a PRESENTATION + FLOW story that reuses `SaveManager.resume_route_position` / `RunResumeService`, NOT a new save format.** The one correctness sub-task with teeth (see the CRUX) is that a **resumed run must be seated with its class loadout intact** — today it silently is not.

**Cross-story fences (do NOT pull these in — they belong to sibling Epic-15 stories):** **D1 HP-persistence-across-nodes → 15.5** (do NOT add a run-level current-HP field or make HP carry between nodes here); **D4 shards-on-death → 15.5** (do NOT touch `MetaAwardRules`); **D3 class-weighted rewards → 15.6**; **D2 move-confirm → 15.7**. 15.5's AC states "the persisted HP survives a quit/resume (15.4)" — that is 15.5 *depending on* 15.4's resume seam, **not** 15.4 adding HP. Also inherit the Epic-15 standing posture: **Epic 15 moves NO seed-regression fingerprint**, difficulty stays a hard non-goal, no new autoload, assertable logic on scene-free `RefCounted` seams (scenes verified by construction + the compile guardrail).

### ⭐ THE CRUX — wire the quit→save and boot→Continue affordances over the EXISTING `resume_route_position` seam, keep the in-node fight EPHEMERAL (23-key gate stays 23), and re-derive the resumed run's STARTING KIT so the loadout is genuinely intact (read before Task 1)

Five boundaries define this story. Get them wrong and you either move a fingerprint (a firing offence in Epic 15), add a save key, ship a Continue that revives a run with the wrong hero, or a quit that loses the descent.

1. **Reuse the shipped save/resume seams; do NOT re-implement them.** The SAVE is `RunOrchestrator.compose_route_position_snapshot()` → `SaveManager.autosave_route_position(snapshot)` (the board-free route-position write). The RESUME is `SaveManager.resume_route_position()` → `RunResumeService.resume_route_position()` (rebuilds `RunState` + run-level `RngStreamSet`, no partial state, seed cross-check). The RECOVERY mapping is `RunResumeRecoveryView` (the 7 structured codes). The seat is `RunOrchestrator.start_from(run, streams)`. `save_recovery_presenter.gd` **already** chains resume → seat → `GameSession.set_run_flow` → `SceneManager.go_to_stage("route_map")` — reuse it as the Continue landing (make it reachable), do not fork it.

2. **The in-node fight stays EPHEMERAL — resuming lands at the ROUTE POSITION, not mid-fight (AC3; the standing `deferred-work.md:418` constraint).** The pause affordance is reachable from the live board **including mid-fight**, but quitting mid-fight **discards** the ephemeral `InteractiveCombatSession` (`gameplay_shell_presenter.gd:43-44` — "no in-node save"). The composed route-position snapshot captures the run parked on the **current, un-cleared** node; on resume the shell re-enters that node (`resolve_current_node` re-hosts an un-cleared combat node — the `cleared_node_ids` no-op guard only skips CLEARED nodes, `run_orchestrator.gd:261`). **No mid-encounter save, no new save key — the 23-key `RunSnapshot` gate stays 23 and `SCHEMA_VERSION` stays 1.** The mid-encounter-save item **remains deferred** (do NOT reopen it).

3. **⚠ RE-DERIVE THE STARTING KIT ON SEAT/RESUME, or a resumed run silently reverts to the 60 HP / sword driver default.** The route-position save persists `selected_class_id` (it rides inside `route_state` — `run_state.gd:367`) but deliberately **does NOT** persist the full `StartingKit` (`run_snapshot.gd:208`, `run_state.gd:515` — "re-derived from the class id on restore"). BUT no caller re-derives it: `RunResumeService.resume_route_position` rebuilds a `RunState` with `starting_kit == null`, and `RunOrchestrator.start_from` (`run_orchestrator.gd:217-238`) seats it **without** re-deriving. So `CombatLoadout.for_run(run)` (`combat_loadout.gd:70-73`) hits its **null-kit fallback** → `DEFAULT_HERO_HP` (60) + sword + no support. A resumed Warrior/Pyromancer/Ranger would fight at **60 HP with a sword** instead of its class kit (18 HP + class weapon + class support) — **AC2's "run intact" fails.** The fix: re-derive `starting_kit` from the restored `selected_class_id` on the seat/resume path (the same `ClassRepository`/`StartingKit` resolution `RunStartCommand` used at record time — a pure content read, **zero RNG**). This is **headlessly assertable** → **test-lock it** (a resumed run of each MVP class yields the class loadout, not the driver default).

4. **New-run-when-a-saved-run-exists is a DELIBERATE, CONFIRMED choice — never a silent overwrite (AC2).** Add a has-saved-run detection (a file-existence / read check — **additive**, no schema change) and gate the new-run start on a confirm when a save is present. On confirmed new run, **clear the stale save** so a subsequent boot does not offer Continue to a run the player abandoned. A boot with **no** saved run must **not** offer Continue.

5. **Zero domain/save-schema/RNG/fingerprint change (AC3; Epic-15 standing constraint).** No new `RunSnapshot` key, `SCHEMA_VERSION` unchanged, no new `DomainEvent`, no new RNG stream, no new draw site, no new autoload. The kit re-derivation is fingerprint-safe: every pinned fingerprint rides either the pure `run_to_completion` auto-resolve (no board, no kit) or the hands-off `play_hands_off_to_run_end` driver (which uses `DEFAULT_HERO_HP`, **not** the kit — `run_flow_controller.gd:166-173`), so populating `run.starting_kit` on a resumed run touches **no** seed-regression artifact. 15.4 draws **zero gameplay RNG**.

### The load-bearing architecture reality (read before Task 1)

The quit/resume flow rides this exact chain (grep-verified against source):

- **The SAVE side (reuse — already shipped, tested).**
  - `RunOrchestrator.compose_route_position_snapshot()` (`run_orchestrator.gd:383-387`) → `RunSnapshot.from_route_position(run, streams)` (`run_snapshot.gd:217-249`): a **pure read** (no RNG, no mutation) composing the board-free route save from the existing 23-key fields; `level_state` stays empty; a seed cross-check rejects a mismatched save. Covered by `test_run_route_position_save.gd` (compose → resume round-trips the route position + reproduces the next RNG draw).
  - `SaveManager.autosave_route_position(snapshot)` (`save_manager.gd:42-43`) → `SaveRepository.write_run_snapshot` (`save_repository.gd:9-56`): the **atomic** temp→backup→replace write to `user://run_autosave.json` (`DEFAULT_RUN_PATH`). Overwrites any prior save.
- **The RESUME side (reuse — already shipped, tested).**
  - `SaveManager.resume_route_position()` (`save_manager.gd:50-51`) → `RunResumeService.resume_route_position()` (`run_resume_service.gd:101-148`): reads → rebuilds `RunState` via `RunState.try_from_run_snapshot_fields` → restores the run-level `RngStreamSet` → symmetric seed cross-check; **first structured error verbatim, NO partial state.** Covered by `test_run_resume_service.gd` + `test_resume_flow.gd`.
  - `RunResumeRecoveryView` (`run_resume_recovery_view.gd`): maps a resume `ActionResult` to a message + retry/fresh-start affordances for the **7 structured codes** (`save_not_found` / `save_open_failed` / `save_parse_failed` / `unsupported_save_schema` / `invalid_tactical_snapshot` / `missing_tactical_snapshot` / `invalid_rng_snapshot`) + a fail-closed generic. Exact-key `DICTIONARY_KEYS`, pinned by `test_run_resume_recovery_view.gd`.
  - `save_recovery_presenter.gd`: **already** does `resume_route_position` → `RunResumeRecoveryView.from_result` → on success `RunOrchestrator.new().start_from(run, streams)` → `GameSession.set_run_flow(controller)` → `SceneManager.go_to_stage("route_map")`; on failure renders the recovery message + retry/fresh-start. **This IS the Continue landing** — 15.4 makes it reachable (a stage + a boot branch) and adds the kit re-derivation before/at the seat.
- **The FLOW/NAV layer (extend minimally).**
  - `BootController` (`boot_controller.gd`) — currently unconditional `go_to_stage("hero_select")`. **FIX locus:** branch on has-saved-run (a scene-free decision seam) → offer Continue + New Run, else today's behavior.
  - `RunFlowRouter.STAGES` / `_STAGE_SCENES` (`run_flow_router.gd:32-53`) — the pinned stage table. Adding a `save_recovery` (or boot-menu) stage is an **additive, test-pinned** table change (mirror the 11.5 `outpost` append).
  - `SceneManager.go_to_stage` (`scene_manager.gd:21-27`) — thin glue over the router; no logic to add here.
  - `GameSession.set_run_flow / clear_run_flow / run_flow` (`game_session.gd:47-59`) — the run-flow handle across scenes (reuse).
  - `gameplay_shell_presenter.gd` — hosts the live board + HUD; the pause affordance overlay + its quit action live here (the quit ACTION — compose + persist + navigate — behind a scene-free seam).
  - `hero_select_presenter._on_confirm_pressed` (`hero_select_presenter.gd:298-327`) — the new-run start; gate it on the overwrite-confirm + save-clear when a save exists.
- **The LOADOUT read (the CRUX-3 correctness anchor).** `CombatLoadout.for_run(run)` (`combat_loadout.gd:70-73`) reads `run.starting_kit`; a null kit falls open to `LiveCombatResolver.DEFAULT_HERO_HP` (60) / sword / no support. The gameplay shell arms every interactive pre-boss fight from this (`gameplay_shell_presenter.gd:115` via `flow.hero_hp()/hero_weapon_id()/hero_support()`). So a resumed run with a null kit fights wrong. Re-derive the kit on seat.

**The quit/resume flow in one table (the wiring targets):**

| Player action | Today | After 15.4 |
|---|---|---|
| Open pause on the live board | no affordance exists | overlay with **Resume play** + **Quit run** (mid-fight: quitting discards the ephemeral fight) |
| Quit run | impossible | `compose_route_position_snapshot` → `autosave_route_position` → return to the boot/menu surface |
| Boot with a saved run | always → hero select | offer **Continue** (resume → seat → route map, kit re-derived) + **New Run** |
| Boot with no saved run | → hero select | → hero select / New-Run-only menu (no Continue) |
| Start a New Run over a save | silent, stale save lingers | **confirmed** choice → clear the stale save → hero select |
| Resume a Warrior/Pyromancer/Ranger run | 60 HP + sword (null-kit fallback) | the class kit (HP + weapon + support), test-locked |

## Acceptance Criteria

**AC1 — A pause affordance on the live board saves the route position on quit through the existing seam, then returns to the boot/menu surface (FR1/FR28; NFR9)**
Given a run in progress at a route position (between nodes on the map, or mid-fight on the live board)
When the player opens an in-game pause/menu affordance and chooses **Quit run**
Then the run's route position is **saved through the existing Epic-2 save seam** — `RunOrchestrator.compose_route_position_snapshot()` → `SaveManager.autosave_route_position(...)` (reused, **not** re-implemented) — and the player returns to the **boot/menu surface** (the Continue-offering surface, **not** the outpost meta dashboard, which is a completed/failed-run destination)
And the pause affordance is **reachable from the live board** and offers **at minimum Resume-play and Quit-run**, every target ≥44px and readable at the 2.0x text scale (NFR9); quitting **mid-fight discards the ephemeral in-node fight** (the current node stays un-cleared) so the save is a clean route position.

**AC2 — Boot offers Continue for a saved run and restores it INTACT; a new run over a save is a confirmed choice (FR1/FR28)**
Given a saved run exists
When the game boots
Then a **Continue** affordance is offered and, when chosen, restores the run at the **same route position with the run intact** — via `SaveManager.resume_route_position()` → `start_from`, and **the resumed run's class loadout is re-derived from the restored `selected_class_id`** so it is NOT the 60 HP / sword driver default (the route/economy/class survive; **current-HP persistence across nodes is 15.5's D1, out of scope here**)
And a boot with **no** saved run does **not** offer Continue, a **corrupt/unreadable** save surfaces the `RunResumeRecoveryView` recovery message + retry/fresh-start (no partial state becomes active), and **starting a NEW run when a saved run exists is a deliberate, confirmed choice** (a confirm before overwrite) that **clears the stale save**, never a silent overwrite.

**AC3 — Save/flow only: 23-key gate holds, schema unchanged, every fingerprint byte-identical (Epic-15 standing constraint; NFR13/NFR15)**
Given the save contracts
When this story lands
Then the **23-key `RunSnapshot` gate stays 23** and **`SCHEMA_VERSION` is unchanged** (the in-node fight stays **ephemeral** — resuming lands at the route position, not mid-fight; **no new save key, no mid-encounter save**), the route-position save reuses only existing 23 fields (empty `level_state`), any has-saved-run/detection or delete is an **additive file operation** (no schema change), **no new `DomainEvent`, no new RNG stream, no new draw site, no new autoload**, this story draws **zero gameplay RNG**, and **every pinned combat/generation/route/finale seed-regression fingerprint stays byte-identical** (Epic 15 moves NO fingerprint — the kit re-derivation is fingerprint-safe: no pinned artifact reads `run.starting_kit`)
And this story touches **no** `project.godot` project setting, input map, or save format; difficulty stays a hard non-goal.

## Tasks / Subtasks

- [ ] **Task 1 — Confirm the shipped save/resume seams and reproduce the three wiring gaps; pin the fix loci (AC1, AC2, AC3)**
  - [ ] Read `save_manager.gd` (`autosave_route_position` `42-43`, `resume_route_position` `50-51`), `run_resume_service.gd` (`resume_route_position` `101-148`), `run_orchestrator.gd` (`compose_route_position_snapshot` `383-387`, `start_from` `217-238`, the hands-off `run_to_completion` callback `313-345`), `run_snapshot.gd` (the 23-key `to_dictionary` `43-68`, `from_route_position` `217-249`), `run_resume_recovery_view.gd`, `save_recovery_presenter.gd`, `run_flow_router.gd` (`STAGES`/`_STAGE_SCENES` `32-53`), `boot_controller.gd`, `game_session.gd`, `gameplay_shell_presenter.gd` (the ephemeral-fight note `43-44`; the loadout arming `115`), `hero_select_presenter.gd` (`_on_confirm_pressed` `298-327`), and `combat_loadout.gd` (`for_run` null-kit fallback `70-73`). Confirm: the save/resume domain layer is complete and tested; the live flow never autosaves; boot never offers Continue; `start_from` seats a null kit.
  - [ ] Confirm the 23-key `RunSnapshot` gate keys (schema_version, content_version, profile_id, run_id, root_seed, is_manual_seed, meta_progression_eligible, route_state, current_route_node_id, revealed_route_node_ids, level_state, turn_state, rng_streams, board, inventory, equipment, passives, curses, gold, oath_shards, corruption, affinities, meta_progression = 23) and that `SELECTED_CLASS_ID_KEY` rides inside `route_state` (no new top-level key). Do not fix yet — pin the cause first (the retro P4 "grep/repro the live surface before scoping" habit 15-1/15-2/15-3 all cite).

- [ ] **Task 2 — Detect a saved run + decide the boot/menu affordances on a scene-free seam (AC2)**
  - [ ] Add an **additive** has-saved-run detection (e.g. `SaveManager.has_saved_run()` / `SaveRepository.has_run_snapshot()` — a `FileAccess.file_exists(DEFAULT_RUN_PATH)` or read-and-check-`save_not_found`; **no schema change**). Optionally add a `delete_run_snapshot()` file op for the new-run save-clear.
  - [ ] Add a scene-free `RefCounted` boot-decision seam (e.g. `BootMenuViewModel`) that projects, from has-saved-run: `offer_continue`, `offer_new_run`, `new_run_needs_overwrite_confirm`. Pure, zero-RNG, zero-mutation; pin its exact output-key set with a unit test (exact-key/fail-closed style — a false/malformed has-saved-run is a safe "no Continue").

- [ ] **Task 3 — Wire the boot Continue + new-run-overwrite confirm (AC2)**
  - [ ] Branch `BootController` (or a boot-menu presenter/scene reachable via `launch`/`main.tscn`) on the seam: a saved run → present **Continue** (route to the reachable `save_recovery` flow — reuse `save_recovery_presenter`) + **New Run**; no saved run → today's `hero_select` path. Make the resume landing reachable: add a `save_recovery` (or boot-menu) stage to `RunFlowRouter.STAGES`/`_STAGE_SCENES` (additive, test-pinned) **or** drive the resume from the boot presenter directly.
  - [ ] Gate `hero_select_presenter._on_confirm_pressed` (or the boot New-Run path) on the overwrite confirm when a save exists, and **clear the stale save** on a confirmed new run (so a later boot does not offer Continue to an abandoned run). A cold start with no save is unchanged.

- [ ] **Task 4 — Re-derive the resumed run's starting kit so the loadout is intact (AC2 — the CRUX correctness anchor)**
  - [ ] On the seat/resume path, re-derive `run.starting_kit` from the restored `selected_class_id` (the same `ClassRepository`/`StartingKit` resolution `RunStartCommand` used — a pure content read, **zero RNG**) before the resumed run is played. Place it where any restored run is made whole (e.g. in `start_from` with an injected/ default `ClassRepository`, or a dedicated `RefCounted` re-derive seam the resume presenter calls before `set_run_flow`). A run with an empty/legacy `selected_class_id` falls open to the driver default (unchanged — no crash). **Do NOT reopen the `re_derive_kit` profile-awareness defer** (`deferred-work.md:396`): the three resumable v0 classes are statically selectable, so no profile overlay is needed; necromancer/shadeblade carry no kit and cannot run/resume in v0.
  - [ ] Confirm the re-derivation touches **no** pinned fingerprint (no pinned artifact reads `run.starting_kit` — the auto-resolve/ hands-off drivers use the default loadout).

- [ ] **Task 5 — Wire the live-board pause affordance + the quit-save action (AC1)**
  - [ ] Add a pause overlay to `gameplay_shell_presenter.gd` (a mouse-blocking Control, ≥44px targets, 2.0x-legible) offering **Resume play** (dismiss) + **Quit run**. Quit → compose + persist the route position (`compose_route_position_snapshot` → `autosave_route_position`) behind a scene-free seam (so the compose+persist decision is unit-testable), then navigate to the boot/menu surface. Mid-fight: **discard** `_active_session`/`_active_node` (the ephemeral fight) before/while composing — the current node stays un-cleared so the save is a clean route position. Consider reaching the pause from the route map too (both are "in a run").
  - [ ] Confirm the quit save + resume round-trips to the **same route position** (the current, un-cleared node re-enters on resume). Verify the compose/resume round-trip for BOTH a between-node (`ACTIVE_ROUTE`) position **and** a mid-node quit position (the run parked on an entered-but-un-cleared node) — if a mid-node phase does not round-trip cleanly through `from_route_position`/`try_from_run_snapshot_fields`, compose the quit save at the resumable boundary (re-enter the current node) and prove it with a test.

- [ ] **Task 6 — Tests: lock the testable logic; leave the scene render to OSG-1 (AC1, AC2, AC3)**
  - [ ] **Kit-intact on resume (CRUX-3, the highest-value guard):** a route-position save of a started Warrior / Pyromancer / Ranger run → `resume_route_position` → seat → the resumed `CombatLoadout.for_run(run)` yields the **class** loadout (18 HP + class weapon + class support), NOT the 60 HP / sword driver default. (This is 15.2's "test-lock what is headlessly provable" lesson applied to the resume-loadout desync.)
  - [ ] **Boot-menu decision seam:** has-saved-run true → `offer_continue` + `new_run_needs_overwrite_confirm`; false → no Continue; malformed/absent → safe no-Continue. Exact output-key set pinned.
  - [ ] **Quit-save composition:** compose from a live run + persist → `resume_route_position` restores the **same** `current_node_id` / `cleared_node_ids` / route reveals / economy / RNG next-draw (reuse/extend `test_run_route_position_save.gd` patterns); the mid-node quit case re-enters the un-cleared node. Assert the compose is a pure read (input run/streams unmutated; zero RNG).
  - [ ] **New-run-over-save:** a confirmed new run clears the saved run (a subsequent has-saved-run reads false); a cold start with no save is unchanged.
  - [ ] Confirm **no gate moved**: `RunSnapshot` (23-key `to_dictionary`, `SCHEMA_VERSION == 1`), `RngStreamSet` (7 streams), `DomainEvent` enum, `RunResumeRecoveryView.DICTIONARY_KEYS`, `project.godot` — all byte-untouched; every generator/route/finale/combat fingerprint unchanged. The presenters still compile (`test_run_flow_scenes_load.gd`). **No SceneTree presenter test** (the pause overlay + Continue button render are verified by construction + the compile guardrail; on-screen legibility is OSG-1).
  - [ ] **`.gd.uid` discipline:** if you add any new `.gd` (a seam/presenter/test/scene script), run `godot --headless --import` **separately** to emit the `*.gd.uid` sidecar and commit it (the `--scene` test run does not emit it). Commit any new `.tscn` + its `.import` sidecars.
  - [ ] Run the FULL headless suite (command below). Baseline **207 PASS files** (post-15.3); expect **≥207** (each **new** `test_*.gd` FILE bumps the count by one — extending an existing file adds none; the runner reports PASS per test **file**, not per function, per the 15-3 Phase-7 retro note). False-PASS grep guard `SCRIPT ERROR|Parse Error|^FAIL` on the RAW output = exactly the **6 documented** stderr negatives, ZERO new, none referencing a 15.4 file. `git diff --check` clean.

## Dev Notes

### What is ALREADY SHIPPED (reuse / make reachable — do NOT rebuild)

- **The between-node route-position SAVE** (`RunOrchestrator.compose_route_position_snapshot` + `RunSnapshot.from_route_position` + `SaveManager.autosave_route_position` + `SaveRepository.write_run_snapshot` atomic write, Stories 4.6/2.7). Pure read, board-free, reuses the 23 existing fields (empty `level_state`), seed cross-checked, tested by `test_run_route_position_save.gd`. **Reuse verbatim.**
- **The route-position RESUME** (`SaveManager.resume_route_position` → `RunResumeService.resume_route_position`, Stories 4.6/2.8). Rebuilds `RunState` + run-level `RngStreamSet`; first structured error verbatim, NO partial state; symmetric seed cross-check. Tested by `test_run_resume_service.gd` + `test_resume_flow.gd`. **Reuse verbatim.**
- **The RECOVERY mapping** (`RunResumeRecoveryView`, Story 11.3) — the 7 structured codes → message + retry/fresh-start affordances, exact-key `DICTIONARY_KEYS` pinned by `test_run_resume_recovery_view.gd`. **Reuse for the corrupt-save Continue path.**
- **`save_recovery_presenter.gd`** (Story 11.3) — already chains resume → `start_from` → `GameSession.set_run_flow` → `go_to_stage("route_map")`, and renders the recovery surface on failure. **This IS the Continue landing** — make it reachable (a stage + a boot branch) and add the kit re-derivation before/at the seat. Do NOT fork it.
- **`RunOrchestrator.start_from(run, streams)`** (`run_orchestrator.gd:217-238`) — seats a restored, non-terminal, valid run; rejects null/terminal/invalid fail-closed. **Reuse; extend only to re-derive the kit (or re-derive in the caller seam).**
- **`GameSession` run-flow handle** (`set_run_flow` / `clear_run_flow` / `run_flow`) + **`SceneManager.go_to_stage`** + **`RunFlowRouter`** stage table. **Reuse; add at most one additive, test-pinned stage.**
- **`CombatLoadout.for_run`** (`combat_loadout.gd`) — the loadout read the resumed run must feed correctly (the CRUX-3 anchor). **Do not change its fallback; ensure `run.starting_kit` is populated on resume.**

### The root-cause thesis in one line

Sealsworn already has a complete, tested between-node route-position save/resume domain layer, but the on-screen affordances that would drive it were deferred as "a later HUD/boot-flow story" — so nothing ever saves during a live run, boot never offers Continue, and (the one real correctness bug) the seat path never re-derives the resumed run's starting kit, so a Continue'd run silently reverts to the 60 HP / sword driver default; 15.4 is that HUD/boot-flow story: it wires quit→save and boot→Continue over the shipped seams, re-derives the kit so the run is genuinely intact, keeps the in-node fight ephemeral (23-key gate stays 23), and moves no fingerprint.

### Scope determinations (read — these prevent over-reach)

- **Quit lands on the boot/menu surface, NOT the outpost.** The outpost is the **run-END** (completed/failed) destination; a quit run is IN-PROGRESS and must stay resumable. Route quit → the boot/menu (Continue-offering) surface. Do not send a quit to the outpost meta dashboard.
- **Save-on-quit is the required deliverable; a between-node autosave is an OPTIONAL robustness add.** AC1 scopes the save to the explicit pause→quit action. You MAY additionally persist the route position at each route-map return (cheap, reuses the same seam — makes a hard-close survivable too), but if you do, it must stay **additive and off the fingerprint path**: never wire it into the DEFAULT `run_to_completion` auto-resolve (the reward/route/finale fingerprints depend on it). Default recommendation: include a route-map-boundary autosave since it makes "survives closing the game" honest, but keep it out of the hands-off driver.
- **The in-node fight is ephemeral — no mid-encounter save (the `deferred-work.md:418` constraint stands).** Quitting mid-fight discards the session; resume re-enters the un-cleared node. Do NOT add a `RunSnapshot` key, a `TacticalSnapshot` mid-fight embed, or a new save shape. That item **remains deferred** — 15.4 consumes only the "on-screen resume drives `resume_route_position`" half.
- **Re-derive the kit; do NOT persist it.** Keep the save minimal (the 4.6/5.3 decision): the class id survives, the kit re-derives. Populating `run.starting_kit` on resume is a content read, not a new save field.
- **Do NOT add HP persistence or touch `MetaAwardRules`.** D1 (HP carries between nodes) and D4 (shards on death) are **15.5**. A resumed run in 15.4 fights each node from the kit baseline HP (today's behavior); 15.5 later makes current-HP persist AND survive quit/resume over this seam. Adding an HP field here would collide with 15.5's schema-tail work.

### NFR9 / readability — the pause + Continue affordances are first-order, not polish

The pause overlay and the boot Continue/New-Run affordances must be legible at the **2.0x** text scale with **≥44px** targets, and the recovery message (a corrupt save) must read without color alone (the `RunResumeRecoveryView` message is text). The scene render is verified by construction → OSG-1; the DECISIONS behind them are on `RefCounted` seams and unit-tested.

### Epic-14/15 constraints inherited (retro forward items + project-context + the sprint change)

- **Epic 15 moves NO seed-regression fingerprint; difficulty is a hard non-goal.** 15.4 draws zero gameplay RNG and changes no number the game resolves. Prove it: the 7 streams, the 23-key gate, `SCHEMA_VERSION == 1`, and every combat/generation/route/finale fingerprint stay byte-identical (AC3).
- **Assertable logic on scene-free `RefCounted` seams; scenes verified by construction + the compile guardrail; no SceneTree presenter test; no new autoload (11.3/13.x/14.x/15.x ratified posture).** The has-saved-run detection, the boot-menu decision, the quit-save composition, and the kit re-derivation live on seams and are unit-tested; the pause overlay + Continue button render are verified by construction + `test_run_flow_scenes_load.gd`. The on-screen behavior is OSG-1.
- **15-1 vs 15-2 retro contrast — apply BOTH.** 15-1's render/scene symptoms had no headless repro → verify-by-construction → OSG-1; **15-2 proved that when correctness is headlessly provable you MUST test-lock it.** For 15.4: the **quit-save round-trip**, the **kit-intact-on-resume** desync, the **boot-menu decision**, and the **new-run save-clear** ARE headlessly provable → **test-lock them.** Only the pause-overlay / Continue-button on-screen legibility rides the presenter and is verify-by-construction → OSG-1. Do not defer the correctness to OSG-1.
- **15-2 desync-class awareness.** 15-2 fixed "damage computed in two places." 15.4's analog: the resumed loadout is authoritative in **one** place (`selected_class_id` → the re-derived kit) but was being **silently dropped** on the seat path (null kit → driver default). Collapse it to the single authority (re-derive on seat) and the kit-intact test is the standing guard.
- **15-3 Phase-7 retro — the runner reports PASS per test FILE, not per function.** A new `test_*.gd` FILE bumps the count by one; extending an existing file adds none. Set the expected-count guard accordingly (baseline 207 → ≥207).
- **`.gd.uid` via `--headless --import` separately (13-1/14-8); keep the false-PASS grep guard standing (retro P3).** Grep the RAW runner output for `SCRIPT ERROR|Parse Error|^FAIL`; exactly the **6 documented** stderr negatives (int64-overflow ×2 [`test_domain_event.gd` + `test_manual_seed_loader.gd`], malformed-JSON ×3 [`test_profile_repository` + `test_settings_repository`], `invalid_node_type` ×1 [`test_route_node`]); ZERO new. Never trust the summary PASS line alone. Commit any new `.tscn` + `.import` + `.gd.uid` sidecars.

### Deferred-work overlaps folded in (only those that touch 15.4's area)

- **`deferred-work.md:418` / `:506` — "the live in-node board / pending-fight SAVE stays EPHEMERAL; the on-screen resume is the between-node route-position resume the EXISTING `SaveManager.resume_route_position` seam drives; a mid-encounter save is out of scope (the 23-key `RunSnapshot` gate stays 23)."** 15.4 is the story that finally WIRES the on-screen quit + Continue affordances on top of this seam. It **consumes** the "resume drives `resume_route_position`" half but **does NOT** add a mid-encounter save — that item **remains deferred, not reopened** (AC3 keeps the gate at 23 and the in-node fight ephemeral).
- **`deferred-work.md:396-407` — `ClassStartSummaryViewModel.re_derive_kit` profile-awareness (gates on the static `def.is_selectable()`).** This is the RESUME-time kit re-derivation for a profile-UNLOCKED formerly-locked class. It has **zero v0 effect** (necromancer/shadeblade carry no kit, so no unlocked-locked-class run can start or resume). 15.4's kit re-derivation covers the three **statically selectable** MVP classes only — it does **NOT** need the profile overlay and must **NOT** reopen this defer; it stays bundled with the Necromancer/Shadeblade class-kit content story.
- **`deferred-work.md:1518` — the 2-8 `save_open_failed` resume path is untested** (awkward to trigger reliably on Windows/CI). 15.4 touches the resume flow, and `RunResumeRecoveryView` already maps `save_open_failed` → a retry surface. If a deterministic unreadable-file harness is convenient, you MAY close it with a `save_open_failed` no-partial-state case; otherwise it **stays deferred** (do not force it). Not a blocker for 15.4.
- **The standing Band-1/2 on-device human-playtest defer (project-context; retro T1) — 15.4 EXTENDS the OSG-1 checklist** with the pause/quit/Continue on-screen checks below. Not a blocker (the correctness is test-locked).

### OSG-1 on-device checklist additions (carry forward; not a blocker for this story)

- From a live fight and from the route map, a **pause affordance** opens; **Resume play** dismisses it with the fight/position intact; **Quit run** returns to the boot/menu surface.
- After quit, re-launching offers **Continue**, and choosing it drops the player back at the **same route position** with the **same class hero** (the resumed Warrior/Pyromancer/Ranger fights with its class weapon/support, not a sword) and the same gold/shards.
- Booting with **no** saved run shows **no** Continue; starting a **New Run** while a save exists asks for **confirmation** before overwriting.
- A hand-corrupted `user://run_autosave.json` shows the recovery message + **Try Again / Start Fresh**, and never a crash or a half-restored run.
- All pause/boot affordances are ≥44px and legible at the 2.0x text scale.

### Anti-patterns to avoid (this story specifically)

- **Do NOT add a `RunSnapshot` key, bump `SCHEMA_VERSION`, embed a mid-fight `TacticalSnapshot`, or invent a mid-encounter save format** — the in-node fight stays ephemeral; resume lands at the route position; the 23-key gate stays 23.
- **Do NOT re-implement the save/resume domain layer** — reuse `compose_route_position_snapshot` / `autosave_route_position` / `resume_route_position` / `RunResumeService` / `RunResumeRecoveryView` / `save_recovery_presenter`.
- **Do NOT ship a Continue that revives a run with the wrong hero** — re-derive `starting_kit` from `selected_class_id` on the seat/resume path, or `CombatLoadout.for_run` falls open to 60 HP / sword.
- **Do NOT route a quit to the outpost** — the outpost is the run-END destination; a quit run stays resumable at the boot/menu surface.
- **Do NOT wire an autosave into the DEFAULT `run_to_completion` (the hands-off auto-resolve)** — that path owns the reward/route/finale fingerprints. Any autosave rides the live/interactive flow only.
- **Do NOT add HP persistence or touch `MetaAwardRules`** — D1/D4 are Story 15.5; keep 15.4's schema tail clean for 15.5.
- **Do NOT reopen the `re_derive_kit` profile-awareness defer** — v0's resumable classes are statically selectable; necromancer/shadeblade cannot run in v0.
- **Do NOT add a new autoload, a new RNG stream, a new draw site, or a `_process` poll** — the flow rides the existing autoloads and event-driven navigation.
- **Do NOT add a SceneTree presenter test** — decisions on `RefCounted` seams (unit-tested); the pause overlay + Continue render are verified by construction + `test_run_flow_scenes_load.gd`.
- **Keep the false-PASS grep guard standing** — grep the RAW output; exactly the 6 documented negatives; ZERO new.
- **Do NOT touch the reward modal (15.6), snake_case/raw-id copy (15.11), movement animation (15.8), threat telegraphs (15.3, done), or theme polish (15.10).**

## Project Structure Notes

- **Files likely touched (production):**
  - `godot/scripts/ui/presenters/boot_controller.gd` — MODIFIED: branch on has-saved-run → Continue + New Run (else today's `hero_select`). (Or a new boot-menu presenter/scene behind `launch`/`main.tscn`.)
  - `godot/scripts/ui/view_models/boot_menu_view_model.gd` — NEW `RefCounted` seam: has-saved-run → `offer_continue` / `offer_new_run` / `new_run_needs_overwrite_confirm`; exact-key, fail-closed. (+ `.gd.uid`.)
  - `godot/scripts/autoloads/save_manager.gd` **or** `godot/scripts/save/save_repository.gd` — MODIFIED: additive `has_saved_run()` / `has_run_snapshot()` (+ optional `delete_run_snapshot()`); **no schema change**.
  - `godot/scripts/ui/presenters/gameplay_shell_presenter.gd` — MODIFIED: pause overlay (Resume play / Quit run) + the quit action (compose → persist → navigate; discard the ephemeral fight mid-quit).
  - `godot/scripts/ui/flow/quit_run_bridge.gd` (or similar) — NEW `RefCounted` seam housing the quit-save compose+persist decision (so it is unit-testable). (+ `.gd.uid`.) (Optional if you keep it inline, but a seam is the ratified testable-logic posture.)
  - `godot/scripts/run/run_orchestrator.gd` **or** a resume seam — MODIFIED/NEW: re-derive `run.starting_kit` from `selected_class_id` on the seat/resume path (pure content read, zero RNG). Prefer the smallest change that makes any restored run whole.
  - `godot/scripts/ui/presenters/save_recovery_presenter.gd` — MODIFIED (if needed): ensure the kit is re-derived before `set_run_flow`; make it the reachable Continue landing.
  - `godot/scripts/ui/flow/run_flow_router.gd` — MODIFIED (if you add a reachable stage): additive, test-pinned `save_recovery`/boot-menu stage in `STAGES`/`_STAGE_SCENES`.
  - `godot/scripts/ui/presenters/hero_select_presenter.gd` — MODIFIED: gate the new-run start on the overwrite confirm + save-clear when a save exists.
  - (Possibly) `godot/scenes/...` — a boot-menu / pause-overlay `.tscn` (+ `.import`), if you add a scene rather than build the overlay in code.
- **Tests:** ADD `godot/tests/unit/ui/test_boot_menu_view_model.gd` (the decision seam); ADD/EXTEND resume-loadout coverage (the kit-intact-on-resume assertion — new file or extend `test_run_resume_service.gd` / a `tests/unit/run/` test); EXTEND `test_run_route_position_save.gd` for the quit-save composition + mid-node re-enter; ADD the has-saved-run + new-run-save-clear coverage (`tests/unit/save/`). `test_run_flow_scenes_load.gd` stays green (the compile guardrail). Run `--headless --import` separately for any new `.gd.uid`.
- **Out of bounds:** `run_snapshot.gd` schema (no new key, `SCHEMA_VERSION` unchanged), `rng_stream_set.gd` (7 streams), `domain_event.gd` (no new event), the reference combat driver + every winnability/seed-regression fixture, the hands-off `run_to_completion` auto-resolve callback, `MetaAwardRules`, any HP-persistence field (15.5), `project.godot`/input map/save format, the reward modal (15.6), movement animation (15.8), theme polish (15.10), snake_case/raw-id copy (15.11). The domain and every generator/route/finale/combat fingerprint are byte-untouched.

## Project Context Rules

Extracted from `project-context.md` (canonical rulebook) and the architecture (`_bmad-output/game-architecture.md`):

- **Save truth is versioned domain snapshots, never scene nodes (hard rule; NFR15).** 15.4 saves/reads the existing `RunSnapshot` domain snapshot through `SaveRepository`; it serializes no scene node and adds no save key.
- **Domain owns truth; presentation observes + submits commands (hard rule; NFR14).** The pause/boot presenters own no run truth — they read the flow handle and drive the shipped save/resume/seat seams.
- **Gameplay systems use repositories for definitions and persistence (NFR16).** The kit re-derivation resolves through the `ClassRepository`/`SupportRepository` boundary (validated content only), exactly as `RunStartCommand` did.
- **Named RNG only; deterministic under seed (NFR13).** 15.4 draws ZERO RNG; the 7 named streams are restored (not re-seeded) on resume; Epic 15 moves NO seed-regression fingerprint.
- **`RunSnapshot` is a 23-key contract at `SCHEMA_VERSION == 1` (pinned gate).** The route-position save reuses only those fields (empty `level_state`); no key added, schema unchanged.
- **Assertable logic on scene-free `RefCounted` seams with pinned key sets; scenes verified by construction + the compile guardrail; no SceneTree presenter tests; no new autoload.**
- **Color-independence; phone-sized readability is first-order (NFR9).** The pause/boot affordances and the recovery message are text-legible at 2.0x with ≥44px targets.
- **Difficulty is a hard non-goal.** 15.4 changes no number the game resolves — it lets a run be left and resumed.
- **Headless suite stays green** (207 PASS baseline post-15.3; expect ≥207; false-PASS grep `SCRIPT ERROR|Parse Error|^FAIL` clean beyond the 6 documented negatives).

### Mandatory test command (must pass before this story moves to review/done)

```
godot --headless --path C:\Sealsworn\godot --scene res://tests/headless/test_runner.tscn --quit-after 10
```

`godot` is not on the Bash/`where` PATH; run via PowerShell (`C:\Users\Rasmus\bin\godot.cmd`, or the standalone `C:/Users/Rasmus/Godot_v4.6.3-stable_win64.exe/Godot_v4.6.3-stable_win64_console.exe`). Apply the false-PASS grep guard `SCRIPT ERROR|Parse Error|^FAIL` on the RAW output (never trust the summary PASS line alone). The runner auto-discovers `test_*.gd` under `res://tests/unit` and `res://tests/integration` only. Baseline **207 PASS files** (post-15.3); expect **≥207**, ZERO new stderr negatives beyond the 6 documented. Run `godot --headless --import` separately to emit any new `.gd.uid` sidecars (and commit new `.tscn`/`.import`) before committing.

## References

- `_bmad-output/planning-artifacts/epics.md#Epic 15: Playtest Response` — Story 15.4 ACs (body lines 3319–3339); the Epic-15 Epic-List entry + sequencing/fingerprint/decision note (535–541, 3251–3256); the Band-2 demarcation (3281); the sibling-story fences (15.5 D1/D4 at 3341–3369, 15.6 D3 at 3371–3396, 15.7 D2).
- `_bmad-output/planning-artifacts/sprint-change-proposal-2026-07-24.md` — the quit/resume → 15-4 map; the Band-2 list; "Epic 15 moves NO fingerprint"; "difficulty is a hard non-goal"; the readable-and-correct goal.
- `playtest-sessions/agent-playtest-2026-07-20.md` + `…-triage.md` — the "no way to quit and resume a run" finding.
- `_bmad-output/auto-gds/retro-notes/epic-15.md` — 15-1's verify-by-construction note (scene symptom, no headless repro → OSG-1); 15-2's contrast (correctness IS headlessly provable → test-lock it) + the "derived in two places" desync class the kit-intact test guards; 15-3's Phase-7 note (the runner reports PASS per test FILE, not per function).
- `_bmad-output/implementation-artifacts/15-1-…md` + `15-2-…md` + `15-3-threat-telegraphs.md` — the ratified Epic-15 story shape (RefCounted seams, no SceneTree test, `.gd.uid` discipline, false-PASS grep guard, deliberate in-change test updates, exact-key seam discipline).
- `_bmad-output/implementation-artifacts/deferred-work.md` — `:418`/`:506` (in-node fight stays ephemeral; resume = the `resume_route_position` seam; mid-encounter save out of scope → 15.4 consumes the resume half, does NOT reopen the save half); `:396-407` (`re_derive_kit` profile-awareness → do NOT reopen; v0 classes are statically selectable); `:1518` (2-8 `save_open_failed` resume path untested → optional, otherwise stays deferred).
- Source files (read before implementing):
  - `godot/scripts/autoloads/save_manager.gd` — `autosave_route_position` (`42-43`), `resume_route_position` (`50-51`), `autosave_between_level`/`resume_run` (the between-level siblings). **Add the additive has-saved-run/delete delegators here or on the repository.**
  - `godot/scripts/save/run_resume_service.gd` — `resume_route_position` (`101-148`, rebuild + seed cross-check + no-partial-state). **Reuse.**
  - `godot/scripts/run/run_orchestrator.gd` — `compose_route_position_snapshot` (`383-387`), `start_from` (`217-238`, seats a null kit — the CRUX-3 fix locus), the hands-off `run_to_completion` autosave callback (`313-345`, **do NOT wire the live autosave here**).
  - `godot/scripts/save/snapshots/run_snapshot.gd` — the 23-key `to_dictionary` (`43-68`), `from_route_position` (`217-249`), `SCHEMA_VERSION` (`12`). **No key add, schema unchanged.**
  - `godot/scripts/save/save_repository.gd` — `write_run_snapshot` (atomic `9-56`), `read_run_snapshot` (`59-74`), `DEFAULT_RUN_PATH` (`7`). **Add has/delete file ops; no schema change.**
  - `godot/scripts/ui/view_models/run_resume_recovery_view.gd` — the 7 recovery codes + exact-key `DICTIONARY_KEYS`. **Reuse for the corrupt-save Continue path.**
  - `godot/scripts/ui/presenters/save_recovery_presenter.gd` — the existing resume → seat → route_map flow (`76-133`). **Make reachable; add kit re-derivation before `set_run_flow`.**
  - `godot/scripts/ui/presenters/boot_controller.gd` — the unconditional `hero_select` (`19-28`). **Branch on has-saved-run.**
  - `godot/scripts/ui/flow/run_flow_router.gd` — `STAGES`/`_STAGE_SCENES` (`32-53`). **Additive stage only, test-pinned.**
  - `godot/scripts/autoloads/game_session.gd` — `set_run_flow`/`clear_run_flow`/`run_flow` (`47-59`). **Reuse.**
  - `godot/scripts/ui/presenters/gameplay_shell_presenter.gd` — the shell + ephemeral-fight note (`43-44`), the loadout arming (`115`), the between-levels render (`277-281`). **Pause overlay + quit action locus.**
  - `godot/scripts/ui/presenters/hero_select_presenter.gd` — `_on_confirm_pressed` (`298-327`, the new-run start). **Overwrite-confirm + save-clear locus.**
  - `godot/scripts/run/combat_loadout.gd` — `for_run` null-kit fallback (`70-73`). **The CRUX-3 correctness anchor — feed it a re-derived kit.**
  - `godot/scripts/run/run_state.gd` — `selected_class_id` persisted in `route_state` (`367`), `starting_kit` re-derived-on-restore comment (`515`), `try_from_run_snapshot_fields`. **Confirms the class id survives; the kit does not.**
  - `godot/tests/unit/save/test_run_route_position_save.gd` — the compose→resume round-trip patterns to extend for the quit-save + mid-node re-enter.
  - `godot/tests/unit/save/test_run_resume_service.gd` + `godot/tests/integration/save/test_resume_flow.gd` + `godot/tests/unit/ui/test_run_resume_recovery_view.gd` — the resume + recovery coverage to build the kit-intact test alongside.
  - `godot/tests/unit/ui/test_run_flow_scenes_load.gd` — the compile guardrail (loads the flow scenes/presenters).

## Dev Agent Record

### Agent Model Used

Story context by Claude Opus 4.8 (gds-create-story). Implementation by Claude Opus 4.8 (gds-dev-story).

### Debug Log References

_(dev-story fills this in)_

### Completion Notes List

_(dev-story fills this in)_

### File List

_(dev-story fills this in)_

### Change Log

- 2026-08-07 — Story 15.4 context created (gds-create-story). Presentation + flow story that WIRES quit / pause / boot-Continue over the shipped, tested between-node route-position save/resume seams (`compose_route_position_snapshot` → `autosave_route_position`; `resume_route_position` → `start_from`; `RunResumeRecoveryView`; the existing `save_recovery_presenter`). Adds an additive has-saved-run detection + a scene-free boot-menu decision seam + a new-run overwrite-confirm/save-clear + a live-board pause overlay. The one correctness anchor: **re-derive the resumed run's `starting_kit` from `selected_class_id` on the seat path** (grep-verified: `start_from` seats a null kit → `CombatLoadout.for_run` falls open to the 60 HP / sword driver default → "run intact" fails), test-locked. Keeps the in-node fight ephemeral (23-key `RunSnapshot` gate stays 23, `SCHEMA_VERSION == 1`, mid-encounter-save defer NOT reopened), draws zero gameplay RNG, and moves NO fingerprint. HP-persistence (D1) + shards-on-death (D4) fenced to 15.5; the `re_derive_kit` profile-awareness defer NOT reopened (v0 classes are statically selectable). Status → ready-for-dev.

### Review Findings

_(code-review fills this in)_
