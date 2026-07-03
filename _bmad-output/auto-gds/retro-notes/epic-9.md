# Epic 9 — Auto-GDS retro notes

## Story 9-1-boss-node-transition-and-finale-setup
- [Phase 5 — dev-story] The two full-run integration tests (`test_class_start_smoke_slice`, `test_run_route_position_save`) asserted boss auto-completion; both needed reworking to the new boss-setup terminus — the load-bearing determinism invariant (interrupted == uninterrupted; same final `run.to_dictionary()`) held unchanged at the new terminus.
- [Phase 5 — dev-story] JSON int→float coercion footgun recurred in arena-payload round-trip tests: byte-identity re-`stringify` across a JSON boundary is impossible for nested ints; assert surviving string fields + strict `BoardState` re-validation instead.
- [Phase 3 — create-story] `GenerationRequest.validate()` hard-restricts `size_class` to Small/Medium and `difficulty_band` to `standard` — a boss arena likely does not fit the generic level-request boundary, so 9.1 probably needs a dedicated boss-encounter request DTO (or a deliberately re-pinned size/recipe extension). Flagged as the story's #2 `[Decision]`; worth watching in review if the dev forces the boss through the combat pipeline.
