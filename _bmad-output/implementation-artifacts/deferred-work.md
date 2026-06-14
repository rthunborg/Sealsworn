## Deferred from: code review of 2-6-accessibility-and-tactical-readability-baseline (2026-06-14)

- [Review][Defer] The `feedback_preview` false-positive guard (`kind == "attack"`) in `TacticalAccessibilityModel._preview_active_from_options()` has no regression test. `_feedback_maps_from_active_preview_and_committed_result` only exercises an attack-mode `commit_flow` and a committed result; no test passes a valid *movement* preview into `from_state({"preview": <move_preview>})` to assert `feedback_preview` stays inactive. The guard is correct today (movement previews carry `commit_available` but `kind == "move"`), but a future refactor could silently start activating `feedback_preview` for movement with no test to catch it. Add a case: build a valid movement preview via `TacticalMovementPreview.from_query(...)`, pass it as `preview`, assert `feedback.preview.active == false` and `feedback_preview` absent from `cue_ids`. Not blocking — current behavior verified correct by inspection. (Originating review: code review of 2-6, Round 1, 2026-06-14.)

## Deferred from: code review of 2-5-adaptive-layout-profiles (2026-06-13)

- [Review][Defer] Degenerate stacked-layout rebalance branch in `TacticalLayoutProfile._build_stacked_layout()` is untested. When a safe-area-shrunk content area is too short to fit board + four control bands + optional log strip, recomputed `control_height` can fall below the 44px minimum touch target. Behavior stays consistent (slots honestly report `reachable: false`, no crash) but no regression test covers it. Add a fixture with an extreme content-area shrink asserting either controls stay ≥ touch target + inside content, or slots report `reachable: false`. Not blocking for v0 — real target viewports do not reach this branch. (Originating review: Round 1, 2026-06-13.)
- [Review][Defer] v0 profile classifier (`TacticalLayoutProfile._profile_id_for()`) maps any `height < 700 and width > height` viewport to `phone_landscape` regardless of width, so large-but-short desktop windows (e.g. `1300x650`) get the compact phone side-rail layout with no distinguishing cue. Matches documented v0 thresholds and passes all five AC fixtures, but is a latent surprise for unusual desktop sizes. Defer to later device-tier threshold tuning (story keeps thresholds as named constants for exactly this); consider a width ceiling on `phone_landscape` or a `layout_low_height_desktop` cue. (Originating review: Round 1, 2026-06-13.)
- [Review][Defer] Populated `log_or_outcome` region (only non-empty on `tablet`/`desktop` profiles) is never asserted to stay inside `content_area` by any committed test — the safe-area test only exercises the `390x844` phone fixture, where `log_or_outcome` is empty, and the region is not a primary control so the reachability helper skips it. Behavior is correct by construction and was verified with a throwaway tablet+desktop offset-safe-area probe (passed), but the persisted suite leaves it uncovered. Add a tablet (and/or desktop) fixture with an offset safe area asserting the populated `log_or_outcome` strip stays inside the content area; could be combined with the rebalance-branch coverage defer above into one short-content + offset-safe-area regression test. Not blocking for v0. (Originating review: Round 2, 2026-06-13.)

## Deferred from: 2-5-adaptive-layout-profiles (2026-06-13)

- Optional scene/presenter proof (Story 2.5.7) was intentionally not built. The adaptive layout
  contract is fully proven scene-free through `TacticalLayoutProfile` plus the sanitized
  `TacticalBoardViewModel.layout` slot, and state preservation is proven by feeding board,
  preview, commit-flow, inspect, zoom, and action-availability contracts through
  `TacticalBoardViewModel.from_domain()` across profile changes in headless tests. A
  `Control`/scene presenter under `godot/scripts/ui/presenters/` and
  `godot/scenes/ui/layouts/<profile>/` is left for a later story that grows the polished HUD,
  per the architecture guidance to keep tactical layout decisions in a testable semantic
  profile first (Story 2.5 Dev Notes "Latest Technical Information").

## Deferred from: code review of 1-3-actionresult-and-domain-event-foundation (2026-06-05)

- Board snapshot cell parsing still coerces malformed cell fields and lacks a `cells` container type guard. `BoardState.try_from_snapshot()` assigns `cells` directly to a typed `Array`, while `BoardCell.from_dictionary()` coerces missing or malformed position, terrain, visibility, and explored values before validation can reject the corrupt snapshot.
- Board entity snapshot restore has unresolved occupant-schema migration and consistency behavior. Cell-only occupant snapshots from the earlier board format now fail without a schema migration, while snapshots with entities but missing matching cell occupants can be accepted and restored into a different shape.
- Mutable `get_cell()` access can bypass new entity occupancy invariants. External callers can mutate the stored `BoardCell.occupant_id` directly and desynchronize `_cells` from `_entities`; deciding whether to return read-only copies or add setup-only mutators belongs with the board snapshot/domain API cleanup.
