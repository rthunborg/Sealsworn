---
project_name: 'Sealsworn'
user_name: 'Rasmus'
date: '2026-06-26'
sections_completed:
  - technology_stack
  - engine_rules
  - performance_rules
  - organization_rules
  - testing_rules
  - platform_rules
  - anti_patterns
  - save_serialization_rules
  - presentation_view_model_rules
  - settings_rules
  - generation_rules
  - run_progression_rules
  - class_kit_rules
  - rules_kernel_rules
status: 'complete'
rule_count: 214
optimized_for_llm: true
architecture: '_bmad-output/game-architecture.md'
refreshed_after: 'epic-5'
---

# Project Context for AI Agents

This file contains critical rules and patterns that AI agents must follow when implementing game code in this project. Keep it lean, specific, and focused on mistakes agents might otherwise make.

Canonical location: root `project-context.md`. Do not create duplicate project context files under `_bmad-output/`; duplicate context risks stale or conflicting agent instructions.

---

## Core Direction

Sealsworn is a mobile-first, desktop-playable, turn-based dark fantasy roguelite RPG. The player controls one hero through seeded, forward-only procedural levels with fog of war, tactical positioning, weapon-shaped basic attacks, risk/reward routing, loot, passive rule-benders, and meta progression.

Story spine:

> The Labyrinth was not built to keep heroes out. It was built to keep something in.

Design guardrails:

- Game loop first: the game must be fun for players who ignore all lore.
- Story is optional discovery, not required reading.
- Cutscenes and control-loss narrative moments should be skippable.
- Tone is dark medieval fantasy with a cosmic horror undercurrent.
- Ancient containment technology should read as relic-magic or Wardenwork, not science fiction.
- Meta progression expands variety and knowledge more than raw power.
- Passives are awakened memories, oaths, scars, relic echoes, forbidden instincts, or broken protocols.
- Affinities are failed containment protocols and safety measures.
- MVP scope must prove the complete rough roguelite loop before content sprawl.

## Technology Stack & Versions

- Production engine: Godot 4.6.3 stable standard build.
- Primary language: typed GDScript.
- Production project root: `C:/Sealsworn/godot/`.
- Target platforms: iOS/Android mobile and tablet first; Windows desktop/laptop parity.
- MVP mode: offline-first single-player. No accounts, multiplayer, cloud saves, leaderboards, or live-service dependency.
- Prototype: `prototype/` is React/Vite/TypeScript validation evidence only. Production Godot code must not depend on prototype source.
- AI tooling: GoPeak Godot MCP and Context7 are selected once the Godot project exists; Rasmus also has premium access to Codex, Claude, Claude Design, Google Stitch, Google Gemini, and related tools.
- Do not use Godot .NET/C# for MVP. Use the standard GDScript build unless architecture is explicitly revised.
- Project shape (post-Epic 2): main scene is `res://scenes/app/boot.tscn`; viewport is 1080x1920 portrait; renderer is Mobile; `stretch/mode=canvas_items`, `aspect=expand`.
- Registered autoloads (unchanged through Epic 5): `GameSession`, `SceneManager`, `SaveManager`, `AudioManager`, `SettingsManager`, `Diagnostics`. Keep them thin; they delegate gameplay decisions to domain services. Generation, run-progression, AND the Epic-5 class/kit/passive layer added NO new autoload — `LevelGenerator`/`ManualSeedLoader`/`RouteGenerator`, every run-domain command, `RunOrchestrator`, the six content repositories, and the `RulesResolver` are pure `RefCounted` services/DTOs called directly (the rules resolver is seated ON the `RunState`, never on a global). `SaveManager` gained thin route-position delegators (`autosave_route_position`, `resume_route_position` -> `RunResumeService`) but owns no run logic.
- Static-content storage (through Epic 5): `godot/data/source/` and `godot/data/resources/` are STILL EMPTY. Every definition (enemies, weapons, supports, level recipes, AND the Epic-5 classes + starting passives) is a code constant authored as a baseline `_baseline_definitions()` array on its repository, registered through the `ContentRepository` boundary — there is NO `.tres`/JSON content pipeline yet, and Epic 5 added none (`ClassDefinition`/`PassiveDefinition` are typed `Resource`s built from code-constant baselines on `ClassRepository`/`PassiveRepository`, not authored `.tres` files). The JSON-source -> typed-Resource mirror is a later (Epic 6) decision; do not introduce it early. The `data/` roots are still asserted as required structure by `test_project_structure.gd`.
- `godot` is NOT on the Bash/`where` PATH on this machine; it resolves only as `C:\Users\Rasmus\bin\godot.cmd` via PowerShell. Run the headless test command through PowerShell (`powershell.exe -NoProfile -Command ...`), not the Bash tool's PATH lookup.

## Critical Implementation Rules

### Engine-Specific Rules

- Use typed GDScript for gameplay, tooling, UI presenters, and tests.
- Godot scenes, `Control` nodes, audio, VFX, and animation are presentation. They must not own authoritative tactical state.
- The scene-independent domain model owns tactical truth: board state, entities, turns, RNG, rules, saves, and run progression.
- Presentation observes domain state/events and submits commands through a command bridge.
- Use Godot signals for presentation/UI feedback, not for hidden domain control flow.
- Keep autoloads thin. Acceptable autoloads: `GameSession`, `SceneManager`, `SaveManager`, `AudioManager`, `SettingsManager`, `Diagnostics`. They delegate gameplay decisions to domain services (e.g. `SaveManager.resume_run()` delegates to `RunResumeService`; `SettingsManager` delegates to `SettingsRepository`/`SettingsApplyService`).
- Do not serialize scene nodes as save-game truth. Save versioned domain snapshots only.
- Use custom Godot `Resource` assets for typed editor/runtime definitions, mirrored from JSON/CSV source data when useful.
- Use the Mobile renderer first; keep Compatibility as fallback if low-end device testing demands it.

### Determinism & Simulation Rules

- Gameplay actions are commands. Commands validate before mutation and return `ActionResult`.
- Successful commands emit deterministic past-tense `DomainEvent` records.
- Domain events drive state changes, presentation, replay, logs, saves, tests, and future analytics.
- Use named RNG streams derived from the root seed: `map`, `level`, `combat`, `loot`, `rewards`, `events`, and `cosmetic`.
- Gameplay-affecting randomness must use its assigned stream. Cosmetic-only randomness cannot affect outcomes, rewards, unlocks, or progression.
- Headless simulation is a first-class target. It must run without rendering, audio, UI scenes, presentation nodes, or scene-tree-only state.
- Manual seed/debug runs may support replay, practice, and debugging, but they must not grant meta progression unless explicitly allowed.

### Rules, AI, and Generation Rules

- Use the Sealsworn rules kernel for passives, items, affinities, curses, classes, bosses, Consume/Destroy choices, and tactical rule-benders.
- Rules use explicit trigger windows, conditions, targets, operations, durations, stacking, conflict handling, and stable resolver ordering.
- Rule-driven outcomes must be explainable in player/debug language.
- Procedural generation runs in phases: route, recipe, layout, pathing, blockers, hazards, enemies, rewards, affinity rules, validation, final snapshot. The phase vocabulary is fixed in `GenerationResult.PHASE_*`; a failure reports the failing phase.
- Generator validation failures must report seed, phase, reason, and compact diagnostics (counts/coords/ratios) — NEVER a full terrain-grid dump. See the dedicated Procedural Generation section below for the full Epic-3 contract.
- Enemy AI uses state/phase-constrained utility scoring over valid tactical actions.
- Every AI decision must be explainable with top score, chosen action, and major reasons.
- Shared tactical query services handle pathfinding, line of sight, threat maps, valid moves, attack previews, and tile scoring.

### Save, Snapshot & Serialization Rules (hardened in Epic 2)

- Snapshots are pure reads. Composing or restoring a snapshot (`RunSnapshot.from_between_level`, `RunResumeService.resume`, `*.to_snapshot`, `try_restore`) must consume NO RNG draws, execute NO commands, advance NO turns, and mutate neither the source domain state nor the save file.
- JSON numbers are IEEE-754 doubles (52-bit mantissa). Any save field that can exceed 2^53 — notably the RNG `root_seed` and each per-stream `state` — MUST be string-encoded (decimal string) in `to_snapshot()`, or `JSON.stringify`/`parse_string` silently truncates it and breaks resume determinism. Restore must read-tolerate the legacy numeric form (int or integral float) AND the string form. Small bounded fields (per-stream `seed` <= 2^31, `draw_index`) may stay numeric.
- ALWAYS JSON-round-trip snapshots in tests (`JSON.stringify` then `parse_string`), never assert only on native dictionaries. A latent int64 precision/resume bug survived Epic 1 precisely because tests round-tripped native dicts instead of real JSON.
- Restore exposes NO partial corrupt state. Each restore step propagates the FIRST validator's structured error verbatim and returns ZERO restored domain objects on failure (the "no partial corrupt state becomes active" guarantee). Restore order for a run: read repository -> strict embedded `TacticalSnapshot.parse` -> `BoardState.try_from_snapshot` -> `RngStreamSet.try_restore`.
- Route an embedded tactical payload through the STRICT `TacticalSnapshot.parse`, never the lenient run-level `RunSnapshot.parse`. Run-level parse is intentionally forward-compatible for run fields; trusting it for the tactical payload could "restore" a corrupt board into a broken shape.
- Compose, do not fork. The between-level save embeds the Epic 1 `TacticalSnapshot` under `level_state["tactical_snapshot"]` (`RunSnapshot.TACTICAL_SNAPSHOT_KEY`). Do NOT flatten tactical board/turn/telegraph/event fields onto the run save or invent a parallel scene-owned tactical save format.
- RNG authority on resume is the run-level `RunSnapshot.rng_streams`. At a between-level boundary it equals the embedded tactical `rng_streams` by construction (both written from one `streams.to_snapshot()` read); a test asserts that equality. Restore the run-level streams as the live gameplay streams.
- Repositories own atomic writes: write to `<path>.tmp`, then backup/replace via `DirAccess.rename_absolute` with `<path>.bak` rollback. Run autosave is `user://run_autosave.json` (`SaveRepository`); settings are `user://settings.json` (`SettingsRepository`). The two files and their repositories are strictly independent — neither reads, writes, truncates, or renames the other.
- Read errors are structured `ActionResult` codes (`save_not_found`, `save_open_failed`, `save_parse_failed`, `unsupported_save_schema`, `invalid_tactical_snapshot`, `invalid_rng_snapshot`), not exceptions. Schema-version changes need migration tests.
- Exercising the real parse-failure path emits one expected `ERROR: Parse JSON failed` line to stderr (Godot's `JSON.parse_string` on deliberate non-JSON bytes). The test still passes and the runner exits 0 — do NOT read that stderr diagnostic as a suite failure.

### Procedural Level Generation Rules (Epic 3)

The level generator (`scripts/generation/level/`) is a scene-free, deterministic, repository-fed pipeline. v0 ships Small (fixed 8x8, `small_combat_basic`) and Medium (fixed 14x12, `medium_combat_basic`) recipes only; Large/Huge are deferred (FR39).

- LEVEL = PURE FUNCTION OF `(root_seed, recipe)`. A generated candidate is fully determined by the seed, the resolved recipe, and the `level`-stream start state. Same `(seed, recipe)` -> byte-identical layout AND identical final `GenerationResult` (same attempt count, same payload or same error). This invariant is non-negotiable and is the foundation of seed regression, manual-seed replay, and bounded retry.
- ALL layout-affecting randomness draws through `GenerationRequest.draw_layout_int` / `draw_layout_float`, which route EXCLUSIVELY through `RngStreamSet.STREAM_LEVEL`. Generators and placers NEVER call `randi()`/`randf()`, NEVER construct a `RandomNumberGenerator`, and NEVER touch another stream. The `rewards`/`loot` streams are RESERVED for runtime reward/loot resolution (Epic 6), NOT generation placement.
- The seed is `GenerationRequest.root_seed`, surfaced via `request.level_seed()` (v0: identity). There is no bare `request.seed`. On a SUCCESS `GenerationResult` the seed lives in `payload.level_seed` (a String) and `result.seed` is `""`; `result.seed` is populated only on the ERROR path. Read `payload.level_seed` on success — this split is a known wart (deferred) that has cost real test bugs.
- FIXED DRAW ORDER (both generators are siblings; reordering or inserting a draw silently changes every pinned fixture): (1) blocker count, (2) blocker positions, (3) wrinkle kinds, (4) wrinkle positions, (5) enemy count, (6/7) enemy position+kind interleaved per enemy, (8) reward count, (9) reward positions. Every count draw fires even when its band collapses to one value, so the stream advances identically across recipes. Positions use a rejection-free SHRINKING CANDIDATE POOL (row-major order, picked cell removed) shared across blockers/wrinkles/enemies/rewards, so nothing ever collides and the reserved central corridor + entrance + exit + WALL cells are pre-excluded.
- Entrance/exit are deterministic (NOT seed-randomized) cells on a reserved blocker-free central corridor row; seed-to-seed divergence comes from interior blockers/wrinkles/placement. This fairness-by-construction is coupled to the fixed even-height footprint; a future jittered size must re-establish the reserved-corridor invariant and re-pin fingerprints.
- BOUNDED DETERMINISTIC RETRY (`LevelGenerator`): a rejected candidate is re-attempted up to `MAX_GENERATION_ATTEMPTS` (8) with a per-attempt seed mix. ATTEMPT 0 USES THE UNPERTURBED `level_seed()` EXACTLY (`_attempt_seed(seed, 0) == seed`) — this preserves the pinned terrain fingerprints and all 3.2-3.5 layout/placement tests with NO re-pin. This is the hard invariant. The cap keeps the worst case inside the NFR4 < 3s budget. Unrecoverable errors (missing/empty enemy repo, structural input/recipe error) short-circuit to attempts=1 instead of burning all 8.
- `LevelValidator` is the COMPREHENSIVE, SIZE-AGNOSTIC, PURE-QUERY validator run on every built candidate. It draws NO RNG, runs NO commands, mutates nothing (same purity contract as snapshots) — wiring it in must keep the `level`-stream draw-count assertions green. It reuses the Medium generator's `validate_readability` (one canonical readability bound) and the placer's reward check, strengthening reward reachability to be ENTITY-AWARE for mandatory rewards. Checks run in the FIXED `check_order()`; the first failure short-circuits with a stable lower-snake code mapped to a phase via `LevelValidator.phase_for_code()`. Diagnostics are compact counts/coords, never a grid dump.
- SAFE-FIRST-REVEAL v0 SEMANTIC (ratified, NOT a silent weakening): the check rejects only the entrance cell being HAZARD or occupied by an entity. A threat merely ADJACENT to the entrance is PERMITTED (seen on spawn within LoS radius 4, FR5; engaged by choice). A `Chebyshev<=1` enemy guard was deliberately REJECTED — it would fail fair baseline candidates and force attempt-0 re-rolls that drift the pinned fingerprints.
- ENTITY OCCUPANCY on built board snapshots (CORRECTED contract — the opposite of an earlier note): `build_board_snapshot` MUST set the matching `occupant_id` on each blocking entity's cell, mirroring `BoardState.to_snapshot()`. `try_from_snapshot` records the cell occupant, strips the cell to `""`, then cross-checks it against blocking entities and REJECTS a blocking entity whose cell carried `""` (`invalid_cell_occupant`). Entity-aware reachability reads occupancy from the ENTITY list (`board.entities()`), never the stripped cell field.
- Built board snapshots are validated through the STRICT `BoardState.try_from_snapshot` (validate-then-reject, never coerce; the Story 1.3 precedent). A malformed cell is a generator bug — surface the validator error, don't fix the snapshot. The emitted payload is PURE serializable data (board snapshot dict + entrance/exit/blockers + `rewards` markers + size_class/recipe_id/level_seed) that survives a JSON round-trip; never put the live `BoardState`/`RefCounted` in the payload.
- `recipe.wall_density` is INTENTIONALLY INERT in v0 for BOTH generators — the `blocker_budget_min..max` band is the authoritative count bound (honoring density would clamp to a constant count and kill AC1 divergence). The Medium AC2 `excessive_blockage` ratio (`MAX_INTERIOR_WALL_RATIO = 0.35`) is the independent readability backstop, not derived from `wall_density`. Touching this field's effect requires widening the band AND re-pinning Small + Medium fingerprints deliberately.
- Tactical wrinkles (`TacticalWrinklePlacer`, shared) draw kinds from the recipe allowlist filtered to the v0-realizable subset (`choke_point`/`blocker_cluster`/`flank_route`/`hazard`) realized as WALL/HAZARD terrain. HAZARD is board-valid, WALKABLE, and sight-TRANSPARENT (only WALL blocks occupancy/LOS) — never make HAZARD block movement; its danger is the rules kernel's job. `door`/`affinity_placeholder`/`enemy_formation`/`reward_behind_danger`/`risky_side_branch` are NOT realized as terrain in v0.
- Enemies + rewards (`EntityRewardPlacer`, shared) are placed deterministically from the residual pool. ENEMIES become board entities (`TacticalEntityState`, `entity_type = ENEMY`) resolved THROUGH `EnemyRepository` (a null/empty repo with a positive enemy budget is a structured error, never a silent no-placement); the enemy kind set is the canonical `PLACEMENT_ENEMY_ORDER`, independent of registration order. REWARDS are abstract payload markers (`{x, y, optional}`), NOT board entities — there is no reward entity type and v0 adds none. There is NO `RewardTableDefinition` in v0; reward-placement rules live on `LevelRecipeDefinition`; concrete loot tables/repository are Epic 6.
- `Array[Dictionary]` does NOT survive `ActionResult` metadata deep-copy — it returns as a plain `Array` and crashes a strict re-typed receiver. Receive metadata-carried dictionary lists (enemies, rewards, wrinkles) as untyped `Array`.
- `ManualSeedLoader` (Story 3.7) is a THIN pure-domain parse+orchestration service over the COMPLETE `LevelGenerator.generate(...)` pipeline — it re-authors NO generation/validation/retry and persists nothing. `parse_seed` accepts a plain int or a decimal String/StringName, normalizes a negative-decoding signed-int64 seed to non-negative via `NON_NEGATIVE_MASK` (`& 0x7fffffffffffffff`) at the loader boundary (do NOT relax `GenerationRequest.validate()`'s `root_seed >= 0` rule), and REJECTS empty / non-decimal / out-of-int64-range / float seeds with stable codes (`empty_seed`/`non_integer_seed`/`unsupported_seed_type`). A float is rejected even if integral. Manual-seed results ALWAYS carry `is_manual_seed: true` + `meta_progression_eligible: false` (the existing `RunSnapshot` vocabulary); never re-introduce the dropped `manual_seed_eligible_for_progression` key (test-pinned absent). The actual meta gate is Epic 8.
- SEED REGRESSION is the tripwire. `*_seed_regression.gd` tests pin a compact TERRAIN fingerprint (dimensions + row-major terrain + entrance + exit) per approved seed; `test_seed_batch_regression.gd` is the `generate`-level harness driving the approved-seed catalog (inline in that test — bland/unfair seeds are KEPT + annotated, not deleted) and cross-checks that the full-`generate` terrain agrees with the `generate_layout` fingerprint (the two pinning paths can never silently diverge). Fingerprints change ONLY via an intentional generator/recipe change re-pinned in the SAME PR — regenerate with `tools/dump_small_layout_fingerprints.gd` / `dump_medium_layout_fingerprints.gd` / `dump_seed_batch_report.gd`, never edit a value to make a drifting test pass.

### Run Progression & Route Rules (Epic 4)

Epic 4 added the scene-free run-progression layer that turns a seed into one playable start-to-end run over a generated route. It REUSES Epic 1-3 contracts (events, snapshots, the level pipeline, the save bridge) — do not fork parallel formats.

- DOMAIN vs GENERATION vs COMMANDS placement (load-bearing): the run-progression MODEL — `RunState` (phase machine + transition table), `RouteState` (forward-only node graph), `RouteNode` (stable hyphenated ids) — plus the `RunOrchestrator` driver live in `scripts/run/`. Route GENERATION (`RouteGenerator`, `RouteValidator`) lives separately under `scripts/generation/route/`. Run-domain COMMANDS (`RouteAdvanceCommand`, `NodeEnterCommand`, `NodeExitCommand`, `NodeResolvePlaceholderCommand`, `RunStartCommand`) live with the tactical commands under `scripts/core/commands/`, extending `game_command.gd` — NOT under `scripts/run/`. Keep these three homes distinct.
- RUN-COMMAND IDIOM (4.3 ratified, followed by 4.4/4.5; honor it for any new run command): a run command takes the live `RunState` DIRECTLY as its `validate(state)`/`execute(state)` arg — no `RunActionContext` wrapper for a single-field context. The run domain has NO event sequencer (BoardState owns the tactical one); the CALLER supplies the run-level `sequence_id` via the constructor (default 1), and `validate()` rejects `sequence_id <= 0` FIRST (`invalid_event_sequence_id`) so a success path can never emit an event its own validator would reject. Validate-then-mutate: on any rejection return a structured `ActionResult.error` with ZERO events and a byte-identical no-mutation `RunState`. Build the success event only AFTER every (infallible) transition succeeds.
- RUN-COMMAND ERROR MODEL: ONE stable top-level error code per failure class; the precise machine-readable reason goes in `metadata` (e.g. `ineligible_route_choice` + `reason: unknown_node|not_linked|hidden_node|cleared_node|is_current_node`). Route node ids are HYPHENATED (`node-1-0`) — NEVER embed a hyphenated id in an error code. (Note: `GenerationRequest.node_id` validates lower_snake and rejects hyphens, so node entry derives a lower_snake request id from the hyphenated node id — don't pass the raw id through.)
- `RunStartCommand` is the ONE exception to the take-a-`RunState` idiom (Option A): the run does not exist yet, so it takes `(root_seed, is_manual_seed, sequence_id)` in its CONSTRUCTOR, its `state` arg is UNUSED (accepts null), and `execute` BUILDS and returns the live `RunState` in `result.metadata["run"]`. It is the FIRST/ONLY `run_started` emitter. An event-emitting action MUST be a `GameCommand` returning `ActionResult` (a plain service was rejected for the emitting path) so `run_started` rides the same validate/execute/no-mutation contract.
- `RouteGenerator` (`scripts/generation/route/`) is a seeded, deterministic, scene-free generator that draws the `map` stream EXCLUSIVELY to build a forward-only layered DAG of 8-12 NON-boss nodes plus exactly ONE terminal boss inside a `RouteState`. ROUTE = pure function of `root_seed` (same seed -> byte-identical route). It returns a `GenerationResult` (`PHASE_ROUTE`) whose serializable `payload.route_state` rehydrates the live `RouteState` via `RouteGenerator.route_from_result(...)` — the payload carries the snapshot dict, NOT a live `RefCounted` (mirror the level pipeline; consumers rebuild the `RouteState`). `INTERIOR_COLUMN_COUNT = 6` (not 7) is LOAD-BEARING for the "≥1 branch point per seed" guarantee. Route DEPTH is CONSTANT at 8 tiers for every seed (boss always at depth 7); the [8,12] variation lives entirely in column WIDTH, never route length — seed-varied depth is an Epic-10 pacing follow-up, not a v0 bug.
- ROUTE SEED REGRESSION is the tripwire (same discipline as level fingerprints): `tools/dump_route_fingerprints.gd` pins per-seed route fingerprints (count|id:type@depth|edges|boss). Any column-count/band/draw-order change MUST re-verify the branch-point + forward-only + full-reachability invariants and re-pin in the SAME change — never edit a value to make a drifting test pass. The fingerprint currently excludes `clues`/`reveal_state` (an Epic-10 clue-tuning follow-up may extend it).
- REVEAL-ON-ARRIVAL is the soft-lock-prevention invariant: the generator marks only depths 0-1 `REVEAL_REVEALED` (everything deeper HIDDEN). `RouteState.eligible_choice_ids()`/`is_eligible_choice()` is the reveal-gated, cleared-excluded forward filter (added in 4.3; 4.1's raw `available_choice_ids()` does NOT gate reveal). `RouteAdvanceCommand` MUST reveal the arrived node's direct forward neighbors (HIDDEN -> REVEALED, monotonic) on every commit, or the run soft-locks after the first choice. Any advance/entry path keeps reveal in lockstep with commitment.
- CLEARED-SET LOCKSTEP (a 4.4 cross-command gotcha): `RouteAdvanceCommand` appends the LEFT node to `cleared_node_ids` on advance; `NodeExitCommand` clears the CURRENT node on exit; `NodeResolvePlaceholderCommand` clears the boss on resolve. `RouteState.validate()` rejects `duplicate_cleared_node`, so the advance's left-node clear is IDEMPOTENT (guarded on existing membership) to survive the enter->exit->advance sequence. Do NOT shuffle clear/reveal responsibilities between commands or double-clear a node.
- NODE-TYPE RESOLUTION (4.5): `combat`/`elite_combat` are real level entry/exit (`NodeEnterCommand` builds + returns a validated `GenerationRequest`, draws ZERO RNG, does NOT run `LevelGenerator`; the orchestrator runs generation). `shop`/`reforge`/`gambling`/`event`/`secret` resolve as NO-OP placeholders via `NodeResolvePlaceholderCommand` (emit `node_placeholder_resolved`, `resolution = placeholder_completed`); `boss` resolves as a placeholder run-END (emit `node_placeholder_resolved` + `run_completed`, `outcome = boss_placeholder`). These are TRACKED MVP placeholders to be REPLACED at the SAME node boundary by their owning epic (shop/reforge Epic 6/7, gambling/event/secret Epic 7, real boss level Epic 9) — the replacing epic must NOT change the route model, node types, or the `run_completed` event, only the pre-completion behavior. There is NO reward/currency entity or `RewardTableDefinition` in v0.
- `RunOrchestrator` (`scripts/run/`) is the THIN scene-free type-dispatch start-to-end driver (NOT a Node/autoload/scene). It threads ONE `RunState` + one run-level `RngStreamSet` + a monotonic run-level `sequence_id` through the loop, SEQUENCING the existing 4.3/4.4/4.5 commands UNCHANGED (it owns no gameplay decision a command does not). It owns the run-level sequence counter (advancing past every emitted event so ids stay unique) and is the ONLY 4.x site that runs `LevelGenerator.generate(...)` — reading `payload.level_seed` on success, NEVER `result.seed`. v0 combat is AUTO-RESOLVED (level generated successfully -> node cleared); there is no real tactical play loop wired into the headless orchestrator yet (a later HUD concern). The boss path STOPS (no exit/advance) — the run ENDS.
- KNOWN v0 LIMITATION — the orchestrator's run-level `RngStreamSet` is INERT: nothing draws run-affecting RNG through it in v0 (route generation draws `map` inside `RunStartCommand`; `LevelGenerator.generate` mints its OWN `level` stream from `request.level_seed()` == `root_seed`). Determinism still holds (everything keys off `root_seed`). When Epic 6/7/9 introduce real run-affecting RNG (combat resolution, rewards, event rolls), those draws MUST be routed through the orchestrator's `streams` (and `LevelGenerator.generate` must accept an injected run-level `RngStreamSet`), or the route-position save will persist a stream disconnected from where draws happen and break interrupted==uninterrupted determinism.
- RUN-PHASE PERSISTENCE: the run phase is serialized as `run_phase` NESTED inside the existing `route_state` payload (`RunState.RUN_PHASE_KEY`), DELIBERATELY not a new top-level `RunSnapshot` key — this keeps the pinned 23-key no-surprise gate green. NEVER flatten new top-level run keys onto `RunSnapshot`; nest run-progression fields under `route_state`. A phaseless `route_state` payload resumes as `PHASE_NEW_RUN` (ratified default). `RunState.try_from_run_snapshot_fields` prefers/cross-checks the canonical top-level `current_route_node_id` and fail-loud-rejects a conflicting nested pointer (`route_node_pointer_conflict`).
- BOARD-FREE ROUTE-POSITION SAVE/RESUME (4.6) — COMPOSE, DO NOT FORK: a between-NODE route choice has NO live `BoardState`, so the board-centric `RunSnapshot.from_between_level` (which requires a board + embeds a strict `TacticalSnapshot`) does not fit. `RunSnapshot.from_route_position(run, streams)` REUSES the existing 4.1 bridge (`run.to_run_snapshot_fields()` for the run/route fields with nested `run_phase`; `streams.to_snapshot()` for `rng_streams`), leaves `level_state` EMPTY, and adds NO new top-level key (the 23-key gate stays green). Restore is `RunResumeService.resume_route_position` reading those fields back through `RunState.try_from_run_snapshot_fields` + `RngStreamSet.try_restore`. The compose side AND the resume side BOTH cross-check that the run's `root_seed` equals `rng_streams.root_seed` (`route_position_seed_mismatch`) so a mis-wired/hand-edited save with divergent seeds fails loud, not silently. The orchestrator composes the route-position snapshot AFTER the advance (parked on a FRESH unresolved node), and `run_to_completion` hands it to an optional save callback (commands stay save-free); a no-op guard skips re-resolving an already-cleared parked node on resume.
- RUN EVENT LIFECYCLE: `run_started` (4.1-wired, FIRST emitted by `RunStartCommand` in 4.6) and `run_completed` (4.5, emitted at the boss boundary) bracket a run. New run-domain events are SYSTEM events (no actor), appended to the END of the event enum (never renumbered) so the snapshot/event schema stays back-compatible, and wired end-to-end (factory + payload validator + stable-id map + round-trip + malformed tests). `run_started.node_count` is the route's bounded [8,12] NON-boss count carried as a RAW JSON integer (a bounded count, NOT a seed — do NOT decimal-string encode it). `run_started.root_seed` IS decimal-string encoded (int64-safe).
- SEED-STRING VALIDATOR IDIOM (3.7, ratified epic-wide): ANY validator for an int64 seed string carried in a payload MUST adopt the lossless/canonicalize check, NOT bare `is_valid_int()` (which silently accepts out-of-int64 strings that `to_int()` saturates/wraps). `DomainEvent._has_decimal_string_payload` now ports the 3.7 idiom as PRIVATE STATIC helpers local to `domain_event.gd` (`_decimal_string_round_trips_losslessly` / `_canonical_decimal_string`, NOT a cross-call to `ManualSeedLoader`): after `is_valid_int()` it requires `_canonical_decimal_string(text) == str(text.to_int())`, rejecting an out-of-range decimal string with `invalid_event_payload`. Reuse this pattern for any new seed-string payload field.

### Classes, Starting Kits & Rules Kernel (Epic 5)

Epic 5 added the hero-class content layer, the per-class starting kit, and the FIRST (minimal, explanation-only) rules kernel that seats class passives on the run. It REUSES every prior contract — the `ContentRepository` boundary, the typed-`Resource` definition + `validate()` discipline, the run-command idiom, the 23-key `RunSnapshot` gate, the named-RNG rule — and forks NO parallel format. v0 starting passives are EXPLANATION-ONLY; the felt-in-combat effect engine is Epic 6.

- CONTENT-ACCESSOR NAMING — `get_class` IS A RESERVED `Object` METHOD: defining `ClassRepository.get_class(id)` is a HARD GDScript PARSE ERROR (collides with the native `Object.get_class()`). The canonical class accessor is `ClassRepository.get_class_definition(class_id)` — ALWAYS call that, NEVER `get_class`. Any future `get_<thing>` content accessor MUST avoid reserved `Object` method names (`get_class`, `get_script`, `get_meta`, etc.); the sibling repos use collision-free names (`get_passive`, `get_weapon`, `get_support`, `get_enemy`). A false-PASS guard earned its keep here: a reserved-name collision compile-failed test files yet one still printed `PASS` — caught only by grepping raw run output for `SCRIPT ERROR|Parse Error`, never the summary line. Keep that grep as a standing gate for every new content/test file.
- CLASS CONTENT (`scripts/content/`): `ClassDefinition` (typed `Resource`) carries `class_id` (lower_snake), `display_name`, `lock_state` (`selectable`/`locked`, FR42/FR43), `unlock_hint`, the starting kit fields (`starting_weapon_id`, `starting_support_id`, `baseline_hp`), and the two passive-id forward references (`class_passive_id`, `equipment_synergy_passive_id`). `validate()` requires the kit + passive fields ONLY for a SELECTABLE class (a LOCKED class needs only a non-empty `unlock_hint`) — the spec-flagged asymmetry that a LOCKED class may carry a malformed/absent kit is HARMLESS in v0 (locked classes never start a run). v0 baselines: Warrior/Pyromancer/Ranger SELECTABLE, Necromancer/Shadeblade LOCKED. Equipment + passive ids on the definition are SHAPE-validated (lower_snake) only — `ClassDefinition.validate()` resolves them against NO repository.
- STARTING KIT (`scripts/run/starting_kit.gd`): `StartingKit` is a scene-free `RefCounted` BY-ID value object (`class_id`, resolved `weapon_id`/`support_id`, `baseline_hp`, the two passive ids) recorded on `RunState.starting_kit`. It owns no truth beyond the recorded kit, submits no commands, draws no RNG, and instantiates NO tactical board player (the live tactical loop is a later concern). It mirrors the exact-key `to_dictionary()` discipline (the `TacticalBoardViewModel`/`HeroSelectViewModel` precedent — its `DICTIONARY_KEYS` set is pinned by `test_starting_kit.gd`; a key never silently appears/vanishes). `support_id == &"none"` is the REAL baseline `SUPPORT_NONE` (Ranger's no-support kit) — it RESOLVES and is a VALID support; NEVER treat `none` as a missing item (doing so falsely fails the Ranger run-start). `baseline_hp` is a small bounded int (NOT a seed — no int64/decimal-string encoding).
- RUN-START IS THREE SEQUENTIAL FAIL-CLOSED CONTENT GATES: `RunStartCommand` resolves a NON-empty selected class through, in order, (1) the CLASS gate (`get_class_definition` -> reject `unknown_class` / `class_not_selectable`), (2) the KIT gate (`WeaponRepository.get_weapon` + `SupportRepository.get_support` -> reject `unknown_starting_weapon` / `unknown_starting_support`), (3) the PASSIVE gate (`PassiveRepository.get_passive` for BOTH passive ids -> reject `unknown_class_passive` / `unknown_equipment_synergy_passive`). Each gate resolves in `validate()` (a pure read — no mutation, no event, no RNG) and the offending id rides `metadata`, never the error code. `execute()` records in order: `selected_class_id` (after `new_run` + the `NEW_RUN -> ACTIVE_ROUTE` transition) -> `starting_kit` -> seat the `RulesResolver` — validate-then-mutate with ZERO partial state on any reject. An EMPTY class id SKIPS the whole block (the back-compat "no class chosen" run stays byte-identical). A new starting-content type follows this same resolve-in-validate / record-in-execute shape. The new repo params are LAST on `RunStartCommand.new(...)` / injected on `RunOrchestrator` (`start(root_seed, is_manual_seed, class_id)`); every existing call site is preserved.
- MINIMAL RULES KERNEL (`scripts/rules/`): `RuleTrigger` (`triggers/`) is the SINGLE SOURCE OF TRUTH for the FIXED ten-window vocabulary (`run_started`, `level_entered`, `turn_started`, `before_move`, `after_move`, `before_attack`, `damage_calculated`, `enemy_killed`, `reward_offered`, `level_completed`) + `is_valid_window(...)`; a passive can never declare a window outside it. Do NOT add, rename, or renumber a window (a later epic wires combat HOOK sites against these exact ids). `RulesResolver` (`resolver/`) is a PURE-READ service (like a snapshot / `LevelValidator`): `register_passive` (registration order == stable resolution order), `resolve(window)`, `explain(window)` — it draws NO RNG, runs NO commands, mutates no tactical state. `scripts/rules/{conditions,operations}` are INTENTIONALLY EMPTY scaffolding — the `RuleCondition`/`RuleTarget`/`RuleOperation` evaluation model, stacking/conflict/duration, and the combat hook sites that FIRE these windows are Epic 6. Do NOT author them early.
- PASSIVES ARE EXPLANATION-ONLY IN v0 (FR44/FR45): `PassiveDefinition` (typed `Resource`) carries `passive_id`, `display_name`, `passive_kind` (`class`/`equipment_synergy`), `trigger_windows` (each validated against the fixed `RuleTrigger` vocabulary, at least one required), and a player/debug-readable `explanation`. It DELIBERATELY has NO active-skill field, NO level/cooldown/activation, NO RNG, and NO effect/operation/amount model (AC3 forbids any active-skill concept; the per-effect operation is Epic 6). A registered passive surfaces with its `explanation` when its window resolves — it does NOT yet mutate any HP/movement/damage number. The six v0 baseline passives (`PassiveRepository._baseline_definitions()`) MUST EXACTLY MATCH the class baselines' passive ids or a class start fails closed at the passive gate; the broader 20-30 MVP passive POOL (FR46) is Epic 6 — do NOT author it here. `RunStartCommand` registers the class passive FIRST, then the equipment-synergy passive (the documented stable order).
- ROUTE-POSITION SAVE PERSISTS CLASS-ID ONLY; RE-DERIVE KIT + RESOLVER ON RESTORE: `RunState.to_run_snapshot_fields()` NESTS `selected_class_id` inside the `route_state` payload (`RunState.SELECTED_CLASS_ID_KEY`, the SAME mechanism as `run_phase`) — adding NO new top-level `RunSnapshot` key (the pinned 23-key gate stays green). `starting_kit` AND `rules_resolver` are LIVE `RefCounted` services (the 4.6 inert-`RngStreamSet` precedent) and are DELIBERATELY NOT serialized — absent from `to_run_snapshot_fields()`; a route-position save carries the class id ONLY. On restore `try_from_run_snapshot_fields` reads the class id back lenient (default `&""` for a pre-5.3 save) and reconstructs a `RunState` with `starting_kit == null` AND `rules_resolver == null` BY DESIGN. ANY resumer (an Epic-6+ live tactical resume) that needs the kit or resolver AFTER a route-position resume MUST RE-DERIVE BOTH from the restored `selected_class_id` via the canonical deterministic pure helpers `ClassStartSummaryViewModel.re_derive_kit(class_id)` / `re_derive_resolver(class_id)` (re-derive the kit -> resolve the two passive ids through the baseline `PassiveRepository` -> rebuild the resolver registering the class passive FIRST then the equipment-synergy passive — byte-equal to a fresh `RunStartCommand` start). `selected_class_id`/`starting_kit` DO ride the FULL `to_dictionary()`/`try_from_dictionary` (lenient-read) so copied/round-tripped runs preserve them; `rules_resolver` rides only as a `copy()` reference (immutable content), never serialized.
- CLASS-START SURFACE IS A SCENE-FREE PROJECTION (`scripts/ui/view_models/`): `HeroSelectViewModel` (5.2) and `ClassStartSummaryViewModel` (5.5) are `RefCounted` view-model projections with EXACT pinned key contracts (`SUMMARY_KEYS` / `ENTRY_KEYS`) — NOT `Control`s, Nodes, or `.tscn` scenes (the FR47/FR68 hero-select/HUD scenes are a later HUD story; UI-scene-last holds). They read `display_name` through `get_class_definition` (never the reserved `get_class`), surface passive EXPLANATIONS (the class passive then the equipment-synergy passive, the resolver's stable order) via the run's seated `rules_resolver` as the single source of truth, and introduce NO active-skill key (FR45). They mutate no combat number (v0 passives are explanation-only) and draw no RNG.
- DUPLICATE-ID LAST-WRITE-WINS IS UNGUARDED ACROSS ALL SIX CONTENT REPOSITORIES (open cross-cutting hardening item, human-ratified `[Review][Defer]`): `class_repository.gd`, `enemy_repository.gd`, `level_recipe_repository.gd`, `weapon_repository.gd`, `support_repository.gd`, `passive_repository.gd` all inherit `ContentRepository`'s last-write-wins behavior — `register_*` overwrites by `(type, id)` while `*_ids()` keeps only the FIRST insertion, so a duplicate id makes the id-list and the resolver (`get_*`) disagree about the canonical definition SILENTLY, with no error. Harmless today (baseline ids are distinct code constants) but a latent fail-QUIET trap once content moves to a JSON/data pipeline, conflicting with the fail-closed/fail-loud rule. Do NOT fork ONE repo to fail-loud (parity was explicitly preserved). The ratified fix is ONE cross-cutting hardening story making all six repositories fail-loud (reject with a structured reason, or `push_error`) on a duplicate id, with tests. Until then, author distinct ids and do not rely on `*_ids()`/`get_*` agreeing on a duplicate.

### Presentation, View-Model & Accessibility Rules (Epic 2)

- Presentation reads domain via semantic view models and submits commands through the command bridge (`scripts/ui/command_bridge/`). View models never own domain truth; they project it.
- `TacticalBoardViewModel.to_dictionary()` has an EXACT sorted-key contract pinned by `test_tactical_board_view_model.gd` (16 keys post-Epic-2, including `layout` and `accessibility`, each defaulting to `{}`). Adding a slot must intentionally bump that assertion — never let a key appear or vanish silently.
- Adaptive layout is a testable SEMANTIC profile first: `TacticalLayoutProfile` plus the sanitized `TacticalBoardViewModel.layout` slot prove the contract scene-free. Build the `Control`/scene presenter (`scripts/ui/presenters/`, `scenes/ui/layouts/<profile>/`) only in a later HUD story. Touch targets stay >= 44px; slots that cannot fit honestly report `reachable: false` rather than overflowing.
- Accessibility is color-INDEPENDENT and audio-absent-equivalent: every committed-action cue must have a visual + textual equivalent that holds with audio off. Preserve the `feedback_preview` (pre-commit, attack-only) vs `feedback_committed` (post-result) distinction; do not collapse them. `AttackPreviewContractMatrix` (`tests/fixtures/tactical/`) is the canonical driver for the color-independence / cue audit — extend it when adding cue vocabulary so no preview ships without an accessibility mapping.
- `TacticalAccessibilityModel` is NOT a settings store; it derives cues from tactical state. Settings holds only the boolean preference (`colorblind_safe`, `high_contrast`) and hands it to this layer at the presenter boundary.

### Settings & Preferences Rules (Epic 2)

- Settings are SAFE preferences only: text scale, master volume / mute, an input-scheme preference, and presentation-hint accessibility toggles. They persist to their own `user://settings.json` via `SettingsRepository` and are NEVER folded into the run autosave or any tactical/RNG/progression state. Future preference work belongs in `scripts/settings/`.
- Loading settings must NEVER hard-block the player at boot. Read policy: missing file (first launch) -> `defaults()` as SUCCESS; unreadable/malformed JSON -> `defaults()` as SUCCESS with a `recovered` diagnostic; schema-version mismatch -> structured `unsupported_settings_schema` error (incompatible build, surfaced not silently overwritten). `SettingsManager._ready()` catches errors and keeps in-memory defaults.
- `SettingsSnapshot.parse` is strict-on-schema, lenient-on-fields: every field is coerced/clamped to named bounds/defaulted; each field's sanitization lives in exactly one helper. Reuse the canonical `TacticalTextScale` clamp rather than writing a second one. Small bounded floats (volume dB) round-trip exactly through JSON; no int64-string encoding needed there.
- Immediate-apply is presentation-only (`SettingsApplyService`): it drives the audio Master bus and surfaces a clamped text-scale presenter hint. Applying ANY preference must leave board/RNG snapshots byte-identical — no command, no RNG draw, no tactical/reward/progression mutation. Guard a missing audio Master bus so headless apply never crashes.
- DIFFICULTY IS A HARD NON-GOAL. Sealsworn has NO player-selectable difficulty tiers. No setting (and nothing in `PREFERENCE_KEYS`) may scale enemy stats, HP, damage, reward rates, RNG, or run length. MVP difficulty comes from run depth, enemy patterns, affinity pressure, elite nodes, risk rewards, attrition, and boss prep; post-MVP challenge is explicit variant/trial/oath content, never a generic difficulty ladder. A regression test enforces the absence of difficulty keys — do not add one.

### Performance Rules

- Generated level load target: under 3 seconds for MVP.
- UI preview and selection response target: under 100ms.
- Target stable 60 FPS where feasible; 30 FPS is acceptable on lower-end mobile if input remains responsive.
- Phone-sized combat readability is a first-order requirement, not polish.
- Avoid per-frame work in nodes that can update through events, signals, or explicit refresh calls.
- Cache node references with `@onready`; do not call `get_node()` in hot loops.
- Use static typing in GDScript hot paths.
- Preload only critical shared assets. Load screens/levels by scene boundary. Add threaded loading for heavier art/audio later.
- Define and measure low/mid/high mobile device tiers before production planning.

### Code Organization Rules

- Production Godot files live under `godot/`. Do not mix production implementation into `prototype/`.
- Use the architecture-defined roots: `scripts/`, `scenes/`, `assets/`, `data/`, `tests/`, `tools/`.
- Organize scripts by domain: `core`, `tactical`, `rules`, `generation`, `ai`, `content`, `save`, `settings`, `run`, `ui`, `platform`, `diagnostics`, `utils`. Autoload scripts live in `scripts/autoloads/`.
- Keep `scripts/tactical/`, `scripts/rules/`, `scripts/generation/`, `scripts/ai/`, `scripts/save/`, `scripts/settings/`, and `scripts/run/` independent of scene nodes for authoritative/data logic (they are `RefCounted` services + DTOs, not Nodes). The `run` domain holds the run-progression MODEL (`RunState` phase machine, `RouteState` graph, `RouteNode`) AND the thin scene-free `RunOrchestrator` start-to-end driver; route *generation* (`RouteGenerator`, `RouteValidator`) lives separately under `scripts/generation/route/`, and the run-domain COMMANDS live under `scripts/core/commands/` with the tactical commands (Epic 4).
- UI logic lives in `scripts/ui/view_models/` (semantic view models like `TacticalBoardViewModel`, `TacticalLayoutProfile`, `TacticalAccessibilityModel`), `scripts/ui/command_bridge/`, and `scripts/ui/presenters/`; layout scenes live in `scenes/ui/layouts/`.
- Player-preference code lives in `scripts/settings/` (`SettingsSnapshot`, `SettingsRepository`, `SettingsApplyService`). NEVER fold preferences into the run snapshot or any tactical/save state.
- Static content source lives in `data/source/`; typed Godot resource mirrors live in `data/resources/`.
- Editable asset source files, prompts, provenance, and reviews live in `asset_sources/`, not `godot/assets/`.
- Runtime-ready art/audio/fonts/shaders live in `godot/assets/`.

### Naming Rules

- Folders and files use `snake_case`.
- GDScript files use `snake_case.gd`: `attack_command.gd`.
- Scene files use `snake_case.tscn`: `gameplay_shell.tscn`.
- Resource files use `snake_case.tres`: `shadow_ambusher_enemy.tres`.
- Test files use `test_*.gd`: `test_attack_command.gd`.
- Classes use `PascalCase`: `AttackCommand`, `EnemyDefinition`.
- Functions and variables use `snake_case`.
- Constants use `UPPER_SNAKE_CASE`.
- Signals use past-tense/event-style `snake_case`: `damage_applied`, `passive_triggered`.
- Commands use imperative names: `MoveCommand`, `AttackCommand`, `ConsumePassiveCommand`.
- Events use past-tense names: `DamageAppliedEvent`, `TileRevealedEvent`.
- Definitions use `*Definition`; snapshots use `*Snapshot`; results use `*Result`.
- Stable content IDs use lower snake case: `shadow_ambusher`, `iron_sword`, `darkness_affinity`.

### Testing Rules

- Every command needs a unit test for valid execution and invalid/no-mutation cases.
- Rules resolver behavior needs tests for trigger timing, ordering, stacking, conflict handling, and explanation output.
- Generator phases need fixtures or seed regression tests.
- Save snapshots need migration tests for every schema change.
- AI behavior families need tests that verify chosen action and explanation reasons.
- Repository layers need tests or checks preventing direct gameplay file access.
- UI command integration tests should verify view models and command bridge behavior without making UI own domain truth.
- Headless simulation tests must run without rendering, audio, UI scenes, or presentation nodes.
- The headless runner (`tests/headless/test_runner.gd`) auto-discovers and sorts `test_*.gd` under `res://tests/unit` and `res://tests/integration` only; it exits with the failure count. Put new tests there (mirroring the domain), not under `tests/headless` or `tests/fixtures`. Run the full suite via PowerShell: `godot --headless --path C:\Sealsworn\godot --scene res://tests/headless/test_runner.tscn --quit-after 10`.
- Save/snapshot tests MUST exercise a real JSON round-trip (`JSON.stringify` -> `parse_string`), not just native-dict equality; assert that restored RNG streams reproduce the exact next draw. Cover malformed-input rejection paths and assert no partial state is exposed on failure.
- Human playtests remain required for feel, readability, frustration, and excitement.

### Platform & Build Rules

- Preserve native mobile packaging path from the start.
- Android exports require Android Studio, Android SDK, and JDK setup.
- iOS exports require macOS and Xcode when iOS packaging begins.
- Commit `project.godot` and `export_presets.cfg` once the Godot project exists.
- Use versioned export presets and local scripted builds early; add CI after vertical slice.
- Use build-profile flags plus pre-export validation and manual release checklist.
- Debug/cheat tools must be disabled or inert in production builds.
- Test content and experimental assets cannot ship unless explicitly approved for production.
- Platform services stay local/no-op for MVP behind interfaces such as `TelemetrySink`, `SaveSyncProvider`, `AchievementProvider`, and `CrashReporter`.

### Static Content & Asset Rules

- Content may be human-authored or AI-assisted during development, but never dynamically generated by AI at runtime.
- Procedural generation may only select from approved static definitions during play.
- Static content must pass schema validation, semantic validation, applicable simulation/rules smoke tests, and final human approval before production use.
- Human review decides whether an item, passive, enemy, affinity, level recipe, or reward table belongs in Sealsworn.
- Track AI-assisted assets with tool, prompt, date, source references, license/provenance notes, editable source path, runtime export path, and approval status.
- Asset statuses: `exploration`, `placeholder`, `approved_reference`, `production`, `deprecated`.
- Placeholder assets include `_placeholder` in filenames.

### Critical Don't-Miss Rules

- Do not make Godot scene nodes authoritative for tactical state.
- Do not use one global RNG for gameplay.
- Do not call non-seeded randomness for combat, loot, rewards, map, level, event, unlock, or progression outcomes.
- Do not serialize scene nodes into saves.
- Do not access files directly from gameplay systems; use repositories.
- Do not put gameplay decision logic in autoloads.
- Do not let UI mutate domain state directly.
- Do not use the React prototype as production architecture.
- Do not add cloud services, accounts, multiplayer, or telemetry dependencies to MVP gameplay.
- Do not accept generated/AI-assisted content into production without validation and human approval.
- Do not let debug/manual-seed actions grant progression unless explicitly approved by release policy.
- Do not start implementation with UI-heavy scenes before the domain model, commands/events, RNG streams, and tactical board tests exist.
- Do not persist a full-64-bit save field (RNG `root_seed`/`state`) as a raw JSON number; string-encode it or lose precision beyond 2^53.
- Do not fold player preferences into the run save, and do not let `SettingsRepository` touch the run autosave (or vice versa).
- Do not add any player-selectable difficulty tier or any setting that scales enemy stats/HP/damage/rewards/RNG/run length (hard non-goal).
- Do not let a snapshot compose/restore consume RNG draws or mutate source state; keep it a pure read.
- Do not activate partial restored state on a validation failure; propagate the first error and return nothing.
- Do not change `TacticalBoardViewModel.to_dictionary()`'s key set without intentionally updating its exact sorted-key assertion.
- Do not draw generation randomness from anything but the `level` stream via `GenerationRequest.draw_layout_int/float`, and do not reorder or insert layout draws — the fixed draw order is pinned by seed-regression fingerprints.
- Do not perturb attempt 0 of the bounded retry; it must reproduce the unperturbed `level_seed()` layout (the no-re-pin fingerprint invariant).
- Do not let a generator/validator draw RNG, run commands, or mutate state during validation — `LevelValidator` is a pure read like a snapshot.
- Do not make HAZARD terrain block movement or LOS, and do not model reward/hazard danger in generation (only WALL blocks; danger is the rules kernel's job).
- Do not read `result.seed` on a successful `GenerationResult` (it is `""`); read `payload.level_seed`.
- Do not emit a blocking entity whose board-snapshot cell lacks the matching `occupant_id`, and do not read occupancy from the stripped cell field — use `board.entities()`.
- Do not re-type a metadata-carried list as `Array[Dictionary]` (it survives deep-copy only as a plain `Array`).
- Do not add a `RewardTableDefinition`, a reward/player entity type, or a JSON-source content pipeline in the generation layer (all deferred); do not let a manual-seed load report meta-progression eligibility or relax the non-negative seed rule.
- Do not silently edit a pinned seed-regression fingerprint to make a test pass; re-pin intentionally via the dump tools in the same change (this includes the `tools/dump_route_fingerprints.gd` route fingerprints).
- Do not add a new top-level `RunSnapshot` key for run-progression state; nest it under `route_state` (the pinned 23-key gate). Do not flatten `run_phase` to top level.
- Do not draw run-affecting RNG from anything but the `map` stream (route generation) or the `level` stream (level generation through the orchestrator); do not bypass the run-level `RngStreamSet` when real run RNG is added in Epic 6/7/9.
- Do not put a run-domain command under `scripts/run/` (commands live in `scripts/core/commands/`), and do not give a run command a `RunActionContext` wrapper — it takes the `RunState` directly. Do not let a run command emit an event with `sequence_id <= 0` (reject it first).
- Do not embed a hyphenated route node id in an error code; carry the precise reason in metadata (one stable top-level code per failure class). Do not pass a hyphenated node id where a lower_snake `GenerationRequest.node_id` is required.
- Do not break reveal-on-arrival: every route advance/entry must reveal the arrived node's forward neighbors, or the run soft-locks. Do not double-clear a node — keep the advance's left-node clear idempotent and the clear/reveal responsibilities split across the existing commands.
- Do not fork a parallel route-position save format; reuse `RunSnapshot.from_route_position` over the 4.1 bridge (board-free, empty `level_state`) and keep the run-seed == `rng_streams.root_seed` cross-check on BOTH compose and resume.
- Do not re-create, rename, or duplicate the 4.5 `run_completed` event; later epics CONSUME it and swap only the placeholder's pre-completion behavior at the same node boundary. Do not renumber the event enum (append new SYSTEM events at the end).
- Do not validate an int64 seed string in any payload with bare `is_valid_int()`; use the lossless canonicalize check (the 3.7 idiom now in `DomainEvent._has_decimal_string_payload`). Do not decimal-string-encode `run_started.node_count` (it is a bounded count, not a seed).
- Do not call `ClassRepository.get_class(id)` — it collides with the reserved native `Object.get_class()` and is a hard parse error; the accessor is `get_class_definition(id)`. Do not name any new content accessor after a reserved `Object` method.
- Do not treat `StartingKit`/class `support_id == &"none"` as a missing item — it is the real baseline `SUPPORT_NONE` (Ranger), resolves, and is a valid support; treating it as missing falsely fails the Ranger run-start.
- Do not skip or reorder the three sequential `RunStartCommand` content gates (class -> kit -> passive); resolve each in `validate()` (pure read), record/seat in `execute()` after the prior gate, leave ZERO partial state on a reject, and carry the offending id in metadata (never in the lower_snake error code). Do not break the empty-class back-compat path (it skips the whole block).
- Do not add, rename, or renumber a `RuleTrigger` window — the fixed ten-window vocabulary is the single source of truth a later epic wires combat hook sites against. Do not author anything in `scripts/rules/{conditions,operations}` (empty Epic-6 scaffolding); do not let the `RulesResolver` draw RNG, run commands, or mutate tactical state (it is a pure read).
- Do not give `PassiveDefinition` an active-skill / cooldown / activation / RNG / effect-amount field (AC3 forbids active skills; v0 passives are explanation-only — the per-effect operation is Epic 6). Do not author the broader 20-30 passive pool yet, and keep the six baseline passive ids EXACTLY matching the class baselines or a class start fails closed.
- Do not serialize `starting_kit` or `rules_resolver` into any save (they are live re-derivable services, null-by-design on restore); a route-position save persists `selected_class_id` ONLY, nested under `route_state` (never a new top-level `RunSnapshot` key). A resumer that needs the kit/resolver MUST re-derive BOTH from the restored class id via `ClassStartSummaryViewModel.re_derive_kit`/`re_derive_resolver` (class passive registered first, then equipment-synergy).
- Do not fail-loud-fork ONE content repository on a duplicate id while leaving the other five last-write-wins — the duplicate-id guard is a single cross-cutting hardening story across ALL SIX repos (parity preserved). Until then, author distinct content ids and do not rely on `*_ids()` and `get_*` agreeing for a duplicate id.
- Do not build a `Control`/`.tscn` hero-select or class-start HUD scene yet — the class-identity surface is a scene-free `RefCounted` view-model projection (`HeroSelectViewModel`/`ClassStartSummaryViewModel`) with an exact pinned key set; the real scenes are a later HUD story (UI-scene-last).

---

## Usage Guidelines

For AI agents:

- Read this file before implementing any Sealsworn game code.
- Read `_bmad-output/game-architecture.md` before touching architecture-sensitive systems.
- Treat root `project-context.md` as the only canonical project-context file.
- Follow all rules exactly. When in doubt, choose the more restrictive interpretation.
- If a task conflicts with this file, surface the conflict before implementing.
- Update this file only when the project architecture or implementation conventions intentionally change.

For humans:

- Keep this file lean and focused on rules agents might miss.
- Update when the engine, folder structure, patterns, or platform targets change.
- Remove rules that become obvious or obsolete.
- Treat `_bmad-output/game-architecture.md` as the full source of truth and this file as the compact agent handoff.

Last Updated: 2026-06-26 (refreshed after Epic 5: classes & starting kits — the `scripts/content/` class layer (`ClassDefinition` + fail-closed `ClassRepository`, accessor `get_class_definition` NOT the reserved `get_class`) + the by-id `StartingKit` value object recorded on `RunState`; the FIRST minimal rules kernel under `scripts/rules/` (`RuleTrigger` fixed ten-window vocabulary, pure-read `RulesResolver`, `PassiveDefinition`/`PassiveRepository`) with v0 starting passives EXPLANATION-ONLY and `scripts/rules/{conditions,operations}` intentionally empty Epic-6 scaffolding; `RunStartCommand`'s three sequential fail-closed content gates class -> kit -> passive; the route-position save persisting class-id-only (kit + resolver re-derived null-by-design on restore via `ClassStartSummaryViewModel.re_derive_kit`/`re_derive_resolver`, the pinned 23-key `RunSnapshot` gate unchanged); the scene-free `HeroSelectViewModel`/`ClassStartSummaryViewModel` projections; and the open cross-cutting duplicate-id last-write-wins hardening item across all six content repositories. No new autoload; `data/source` + `data/resources` still empty — classes/passives are code-constant baselines through the `ContentRepository` boundary. Full headless suite green: "Headless tests passed.")
