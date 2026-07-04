# Epic 9 — Auto-GDS retro notes

## Story 9-5-finale-regression-and-run-length-tuning-hooks
- [Phase 3 — create-story] Latent integration trap: the live 9.4 victory chain drives `PHASE_COMPLETED` but never clears the boss route node, so `RunSummary.boss_cleared` reads false after a live victory unless the full-run integration clears it — flagged as AC2's load-bearing `[Decision]` (recommended: clear the boss node on victory, mirroring the placeholder command's idempotent `REVEAL_CLEARED` + `cleared_node_ids` discipline).

## Story 9-4-boss-victory-and-first-victory-reveal
- [Phase 3 — create-story] The `ProfileSnapshot` schema pin is the sharpest 9.4 trap: no `first_victory_recorded` home was pre-reserved, so the field must be added at `SCHEMA_VERSION == 1` (additive) with the `DICTIONARY_KEYS` test pin updated but NO version bump — a bump silently breaks 8.7's already-green migration tests.
- [Phase 5 — dev-story] Knowing split: 9.4 wired the boss-defeat→run-victory call site (the long-parked run-end auto-wire, VICTORY direction) but deliberately left the hero-DEATH live source deferred — the death half of that seam is now the last un-wired run-end path.
- [Phase 3 — create-story] The 9.3 sequence-id seam contract comes due in 9.4: thread the orchestrator's shared `_next_sequence_id` through `resolve_phase_transitions(..., sequence_id_base)` and forbid the board-baseline fallback when merging interleaved boss-action / phase-change / boss-defeated / run-victory streams; review should check duplicate sequence ids can't arise.

## Story 9-3-boss-actions-telegraphs-and-ai-decisions
- [Phase 5 — dev-story] `PendingTelegraphState._apply_tile_marked` silently HARDCODED `kind: ash_seer_mark` and dropped all non-schema payload keys — a latent trap for any second telegraph source. Generalized in 9.3 to read the kind + preserve optional descriptive keys (needed for the boss ability name to survive onto the resolved-damage event). The one non-obvious cross-cutting change to a shared 9.2/Epic-1 file.

- [Phase 7 — code review] `boss_phase_changed` log sequence-ids in `BossTurnResolver.resolve_phase_transitions` read `board.next_sequence_id()` without advancing it (fine for 9.3's non-board-applied system events, but the id space is shared with `resolve_boss_turn`'s board events). For 9.4: when the live run-to-completion loop merges both event streams into one append-only log, reserve/derive phase-change ids from a shared monotonic counter to avoid duplicate sequence ids.

## Story 9-2-larval-avatar-definition-and-phases
- [Phase 3 — create-story] 9.2's central architectural pivot: the boss must be a validated content DEFINITION, not a live board entity — `TacticalEntityState.validate()` requires `max_hp > 0`, which is why 9.1 kept the boss as an off-board `boss_slot` marker (`is_placeholder: true`). A live boss entity or turn-loop wiring in 9.2 is scope leak into the 9.3/9.4 live-loop seam; flag in review.

## Story 9-1-boss-node-transition-and-finale-setup
- [Phase 5 — dev-story] The two full-run integration tests (`test_class_start_smoke_slice`, `test_run_route_position_save`) asserted boss auto-completion; both needed reworking to the new boss-setup terminus — the load-bearing determinism invariant (interrupted == uninterrupted; same final `run.to_dictionary()`) held unchanged at the new terminus.
- [Phase 5 — dev-story] JSON int→float coercion footgun recurred in arena-payload round-trip tests: byte-identity re-`stringify` across a JSON boundary is impossible for nested ints; assert surviving string fields + strict `BoardState` re-validation instead.
- [Phase 3 — create-story] `GenerationRequest.validate()` hard-restricts `size_class` to Small/Medium and `difficulty_band` to `standard` — a boss arena likely does not fit the generic level-request boundary, so 9.1 probably needs a dedicated boss-encounter request DTO (or a deliberately re-pinned size/recipe extension). Flagged as the story's #2 `[Decision]`; worth watching in review if the dev forces the boss through the combat pipeline.
