# Resume notes — story 15-5-event-node-and-run-summary-wiring

**Written:** 2026-08-18, after the Phase 5 dev-story delegate was killed mid-run by a MONTHLY SPEND LIMIT while updating tests. Its last action was "the D4 lockstep changes — test_meta_award_rules.gd".

## Where the pipeline stands

- Branch `story/15-5-event-node-and-run-summary-wiring`, based on `main` at `cb1279c` (contains merged 15-4).
- Completed phases: 0 (preflight), 1 (branch), 3 (create-story). Phase 5 (dev-story) is **INCOMPLETE**.
- Still to run: finish 5, then 7 (code-review loop) and 9 (finalize/PR). Phase 2 skipped (project-context present), 4/6 skipped (testing disabled in V0), 8 skipped (not last in epic).
- Commits: `a05c4f9` WIP checkpoint (pushed), `82c6c7a` .gd.uid sidecars.

## Diagnostic state — measured, not assumed

Full suite after the import pass: **208 PASS / 3 FAIL** (baseline on main is 211 PASS / 0 FAIL).

The compile cascade seen before the import pass ("Identifier not found: EventOutcomeViewModel") was NOT broken code — the new scripts were created outside the editor so their class names were unregistered and their `.gd.uid` sidecars absent. An `--import` pass fixed it and the sidecars are now committed.

## The 3 remaining failures — all one cause

Every one of the 8 failing assertions still pins the **reversed-away Story-8.3 "a death awards nothing"** behavior. D4's rule change is WORKING (deaths now award 3, 4, 9, 10 where these tests expect 0, 6). AC2 requires `MetaAwardRules` and every test asserting the old behavior be updated **together in the same change** — that lockstep is half-done.

1. `godot/tests/integration/save/test_meta_summary_save_load.gd` — 4 assertions ("A death awards 0 Oath Shards this story", "A death must NOT change the Oath-Shard total", "The award event records the 0 amount", "The withheld-currency total survives the reload").
2. `godot/tests/unit/core/test_award_meta_progress_command.gd` — 3 assertions ("A failed run awards 0 Oath Shards this story", "must not change the Oath-Shard total", "The event records the 0 amount").
3. `godot/tests/unit/ui/test_outpost_render_view.gd` — 1 assertion ("A death earns 0 oath shards this run (honest — a death rewards nothing)").

`godot/tests/unit/save/test_meta_award_rules.gd` was already updated by the dead delegate.

## What else is known UNFINISHED

- Story `Status:` is still `ready-for-dev`; sprint-status still `ready-for-dev`. Tasks/subtasks and the Dev Agent Record are not finalized.
- D5 (Option B — wiring `AwardMetaProgressCommand` at run-end) state is UNVERIFIED. `run_end_profile_bridge.gd` is modified, but the required INTEGRATION coverage (correct accrual on completion + death, manual-seed accrues nothing, no double-award on a re-driven run-end, summary number == profile delta) has not been confirmed to exist.
- D1 (HP persistence) state is UNVERIFIED. `run_state.gd` has 14 `current_hp` references, but the MANDATORY migration/back-compat test (a v1 save with no nested `current_hp` must fail OPEN to full HP, not 0, not a crash) has not been confirmed.
- AC3 event-node outcome surface: `event_outcome_view_model.gd` (150 lines) and `event_node_overlay.gd` exist and now compile; wiring completeness unverified.

## How to resume

Do NOT re-run Phase 5 from scratch — continue from this state. The work on disk is substantial (395+ insertions) and largely correct.

Suite command (NEVER pipe through `tee` — it mangles a backslash path and fakes exit 0):

    C:/Users/Rasmus/Godot_v4.6.3-stable_win64.exe/Godot_v4.6.3-stable_win64_console.exe --headless --path C:/Sealsworn/godot --scene res://tests/headless/test_runner.tscn --quit-after 10

Redirect to a file, read the PASS count and the "Headless tests passed." banner from the captured output, and apply the false-PASS guard (`SCRIPT ERROR|Parse Error|^FAIL` = 0 hits, only the 6 documented pre-existing negatives).
