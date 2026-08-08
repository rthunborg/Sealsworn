# Resume notes — story 15-4-quit-pause-resume

**Written:** 2026-08-07, after the Phase 5 dev-story delegate died to a session limit ("resets 3:40am Europe/Stockholm") mid-run, and before a user-initiated computer restart.

## Where the pipeline stands

- Branch: `story/15-4-quit-pause-resume`, based on `main` at `d02a91d` (contains merged 15-2 and 15-3).
- Completed phases: 0 (preflight), 1 (branch), 3 (create-story). Phase 5 (dev-story) is **INCOMPLETE**.
- Phases still to run: finish 5, then 7 (code-review loop) and 9 (finalize/PR/merge). Phase 2 skipped (project-context present), 4/6 skipped (testing disabled in V0), 8 skipped (not last in epic).

## What the dead delegate had done (all committed as a WIP checkpoint)

Modified: `save_manager.gd`, `run_orchestrator.gd`, `save_repository.gd`, `run_flow_router.gd`, `boot_controller.gd`, `gameplay_shell_presenter.gd`, `hero_select_presenter.gd`, `route_map_presenter.gd`, plus three test files (`test_run_route_position_save.gd`, `test_save_repository.gd`, `test_run_flow_router.gd`).

New: `starting_kit_deriver.gd`, `quit_run_bridge.gd`, `boot_menu_view_model.gd`, `test_boot_menu_view_model.gd`, `test_quit_run_bridge.gd`.

The `save_repository.gd` / `run_orchestrator.gd` changes are **additive only** (42 insertions, 0 deletions) — no `RunSnapshot` key removed, no `SCHEMA_VERSION` line touched. AC3's 23-key / SCHEMA_VERSION-1 constraint appears intact but is **unverified by a test run**.

## What is known to be UNFINISHED

1. **The suite has never been run against this state.** Treat it as red until proven otherwise. Expected baseline before this story: **207 PASS**.
2. The delegate's last words were: *"Now update the router test to pin the new `boot` and `save_recovery` non-linear scene targets."* — `test_run_flow_router.gd` is modified but that specific pinning may be missing or half-applied. **Check it first.**
3. **No `.gd.uid` sidecars exist** for the five new `.gd` files. Godot generates them on import, so they will appear the first time the suite runs. Project convention requires committing them — do not forget, or the new scripts break for other checkouts.
4. Story file tasks/subtasks are not all ticked; `Status:` is still `ready-for-dev` and sprint-status still shows 15-4 pre-review.

## How to resume

Do **not** re-run Phase 5 from scratch — continue from this state. Delegate to `agds-xhigh` with:
- the story file `_bmad-output/implementation-artifacts/15-4-quit-pause-resume.md`;
- an explicit statement that the work above is already on disk and must not be redone;
- the three unfinished items listed above;
- the mandatory suite command plus the false-PASS grep guard (`SCRIPT ERROR|Parse Error|^FAIL` = 0 hits, exactly 6 documented stderr negatives);
- the AC3 hard constraint (23-key `RunSnapshot`, `SCHEMA_VERSION` 1, no RNG stream change, no fingerprint move) with instructions to stop as `needs-human` rather than violate it.

Suite command:

    C:/Users/Rasmus/Godot_v4.6.3-stable_win64.exe/Godot_v4.6.3-stable_win64_console.exe --headless --path C:\Sealsworn\godot --scene res://tests/headless/test_runner.tscn --quit-after 10

## The correctness anchor this story exists for

`RunOrchestrator.start_from` seats a restored run with `starting_kit == null`, so `CombatLoadout.for_run` falls open to the 60 HP/sword default — a resumed Warrior/Pyromancer/Ranger silently loses its class loadout. The new `starting_kit_deriver.gd` is the intended fix. **The kit-intact test is the thing to verify before this story can be called done**, not the button wiring.
