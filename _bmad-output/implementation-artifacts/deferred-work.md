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
