# Epic 3 — Auto-GDS retro notes

Signal-only scratchpad for later Epic 3 stories and the epic retrospective.

## Story 3-1-generation-requests-results-and-level-recipes
- [Phase 3 — create-story] Epic 3 dir scaffolding already exists on disk (empty scripts/generation/{level,route,validation}, data/{source,resources}/{level_recipes,reward_tables}, data/schemas) and test_project_structure.gd already fail-loud-asserts scripts/generation + data/{source,resources} as required roots — 3.1 files land inside required roots, gate stays green, no structure-test extension needed unless a future story adds a new top-level root.
- [Phase 3 — create-story] No .tres/JSON content exists under godot/data/ yet — all existing definitions (weapons/enemies/support) are code constants; 3.1 follows that convention rather than introducing the JSON-source pipeline early. Story 3.5 owns the standalone RewardTableDefinition/repository decision (3.1 keeps reward-placement rules on LevelRecipeDefinition).
- [Phase 5 — dev-story] GenerationRequest exposes the seed as `root_seed` + `level_seed()` (not a bare `request.seed`) — downstream stories must call `request.level_seed()`. GenerationResult keeps literal architecture field names (failed_phase/error_code/reason/seed).
- [Phase 5 — dev-story] GenerationResult.seed is carried as a String (int64/JSON-truncation rule pre-honored). Stories 3.2-3.7 must verify generated-level seed stability through the real TacticalSnapshot + int64-string RNG transport, never native dicts.
