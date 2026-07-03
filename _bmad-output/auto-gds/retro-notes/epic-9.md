# Epic 9 — Auto-GDS retro notes

## Story 9-1-boss-node-transition-and-finale-setup
- [Phase 3 — create-story] `GenerationRequest.validate()` hard-restricts `size_class` to Small/Medium and `difficulty_band` to `standard` — a boss arena likely does not fit the generic level-request boundary, so 9.1 probably needs a dedicated boss-encounter request DTO (or a deliberately re-pinned size/recipe extension). Flagged as the story's #2 `[Decision]`; worth watching in review if the dev forces the boss through the combat pipeline.
