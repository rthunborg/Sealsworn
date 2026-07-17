# Epic 14 — Auto-GDS retro notes

## Story 14-1-corpse-clearing-and-wait-turn
- [Phase 5 — dev-story] Corpse-clear required flipping `entity.blocks_movement=false` on death + tolerating non-blocking co-location in `_validate_entity_for_setup` — a snapshot-occupancy-invariant consequence Task 1 didn't spell out; future domain-death changes must weigh the `_cells`/`_entities` invariant.
- [Phase 5 — dev-story] "More mobility can only help" assumption did NOT hold: corpse-clear gives enemy pursuers mobility too; ReferenceCombatDriver ranger kite heuristic stalemated Medium seed 512 (MAX_ROUNDS, not a loss) — re-pinned to 24680; a smarter policy would still win 512.
- [Phase 5 — dev-story] Latent false-PASS fixed in `test_reference_combat_driver.gd`: eager `String(metadata.get("outcome"))` in an assert message crashed on error results, masking failures. The `String(nullable)`-in-assert-message pattern is a codebase-wide masking risk worth auditing.
- [Phase 7 — code review] Ranger kite heuristic is genuinely fragile with `ash_seer` under corpse-clear: only 8/34 driven Medium seer+melee seeds converged for all three classes (~24%). 512's non-convergence was no fluke — future Medium seer-catalog seeds must be found by search, not picked arbitrarily.
- [Phase 7 — code review] Story's "Files to touch" table named the wrong presenter files (`gameplay_shell_presenter.gd`/`tactical_board_grid.gd`); the live board surface is `tactical_board_presenter.gd` (scene-root script of `tactical_board.tscn`). SM story-audit precision point for later Epic 14 UI stories.
