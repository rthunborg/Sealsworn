# Epic 14 — Auto-GDS retro notes

## Story 14-1-corpse-clearing-and-wait-turn
- [Phase 5 — dev-story] Corpse-clear required flipping `entity.blocks_movement=false` on death + tolerating non-blocking co-location in `_validate_entity_for_setup` — a snapshot-occupancy-invariant consequence Task 1 didn't spell out; future domain-death changes must weigh the `_cells`/`_entities` invariant.
- [Phase 5 — dev-story] "More mobility can only help" assumption did NOT hold: corpse-clear gives enemy pursuers mobility too; ReferenceCombatDriver ranger kite heuristic stalemated Medium seed 512 (MAX_ROUNDS, not a loss) — re-pinned to 24680; a smarter policy would still win 512.
- [Phase 5 — dev-story] Latent false-PASS fixed in `test_reference_combat_driver.gd`: eager `String(metadata.get("outcome"))` in an assert message crashed on error results, masking failures. The `String(nullable)`-in-assert-message pattern is a codebase-wide masking risk worth auditing.
