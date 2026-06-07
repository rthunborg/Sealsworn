---
baseline_commit: 3b4034044fc7e9e504624de66947886fec2ba0f8
---

# Story 1.7: Fog, Line of Sight, and Explored Memory

Status: ready-for-dev

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a player,
I want visibility to distinguish unseen space, explored memory, and currently visible tiles,
so that partial information creates fair tactical tension.

## Acceptance Criteria

1. Given the baseline line-of-sight radius is 4 tiles, when visibility is calculated from the player cell, then visible cells within radius and unobstructed line rules are marked currently visible, and cells outside current line of sight are not treated as current tactical truth.
2. Given the player moves to a new cell, when visibility is recalculated, then newly seen cells become explored, and previously explored but currently unseen cells remain marked as explored memory.
3. Given an unexplored tile contains hidden information, when a tactical query asks for player-visible facts, then hidden information is not exposed, and explored memory exposes only last-known non-authoritative display data.
4. Given fog and line-of-sight tests run headlessly, when blockers, radius limits, and movement updates are tested, then the visibility model passes without requiring fog scenes or rendering.
5. Given line-of-sight golden fixtures are loaded, when visibility is calculated around corners, blocker tiles, diagonal paths, and edge cells, then each fixture produces the expected visible, explored-memory, and hidden-cell sets, and fixture failures identify the board, actor cell, blocker rule, and unexpected cells.
6. Given an enemy or target is hidden by fog, when movement, targeting, or attack preview queries player-visible facts, then the target is treated as unavailable or stale according to visibility rules, and command validation can reject hidden targets with the same reason shown by preview.

## Tasks / Subtasks

- [ ] 1.7.1 Add failing headless visibility tests before implementation. (AC: 1, 2, 4, 5)
  - [ ] Add `godot/tests/unit/tactical/test_tactical_visibility_query.gd` using the existing addon-free `TestCase` style.
  - [ ] Cover baseline radius 4 from center and edge/corner origins.
  - [ ] Cover blocker behavior using `BoardCell.blocks_line_of_sight()` with a visible blocker tile and hidden cells beyond it.
  - [ ] Cover diagonal paths and corner cases with stable expected cell sets.
  - [ ] Cover recalculation after a successful `MoveCommand` by executing the move, then explicitly recalculating visibility from the new actor position.
  - [ ] Assert pure visibility calculations emit no events, consume no RNG, and do not mutate the board.
- [ ] 1.7.2 Add a tactical fog/visibility service under the architecture-defined folder. (AC: 1, 2, 4, 5)
  - [ ] Add `godot/scripts/tactical/fog/tactical_visibility_query.gd` with `class_name TacticalVisibilityQuery extends RefCounted`.
  - [ ] Use `Vector2i` grid coordinates, `BoardState`, `BoardCell`, and `TacticalEntityState`; do not introduce scene nodes or presentation state.
  - [ ] Expose `DEFAULT_LINE_OF_SIGHT_RADIUS: int = 4`.
  - [ ] Return deterministic `ActionResult` values with serialized cell arrays sorted by y then x.
  - [ ] Use the existing `BoardCell.blocks_line_of_sight()` boundary instead of duplicating terrain rules.
  - [ ] Keep entities from blocking line of sight for this story; future rules may add entity blockers explicitly.
- [ ] 1.7.3 Define and lock baseline line-of-sight semantics. (AC: 1, 4, 5)
  - [ ] Treat the actor origin as visible and explored.
  - [ ] Candidate cells are in bounds and within radius 4. Use a stable radius metric and lock it in tests; recommended baseline is squared Euclidean distance using `Vector2i.distance_squared_to(origin) <= radius * radius`.
  - [ ] A blocking target cell can be visible if the line reaches it; cells beyond a blocking intermediate cell are not visible.
  - [ ] Do not allow permissive corner peeking through blockers unless a golden fixture explicitly defines that case as visible.
  - [ ] Fixture failures must report board name, actor cell, radius, blocker rule, expected cells, actual cells, missing cells, and extra cells.
- [ ] 1.7.4 Apply visibility through a deterministic domain event boundary. (AC: 1, 2)
  - [ ] Extend `godot/scripts/core/events/domain_event.gd` with `Type.VISIBILITY_UPDATED`, event id `visibility_updated`, and a helper such as `DomainEvent.visibility_updated(sequence_id, actor_id, origin, radius, visible_cells, newly_explored_cells)`.
  - [ ] Extend `BoardState._validate_event()` and `_apply_validated_event()` to validate and apply visibility updates atomically.
  - [ ] Applying the event must clear all current `visible` flags, mark payload `visible_cells` as `visible = true` and `explored = true`, and leave previously explored but now unseen cells as `explored = true`.
  - [ ] Reject malformed visibility payloads, out-of-bounds cells, invalid actors, duplicate cells, empty visible sets, and sequence mismatches without mutating the board.
  - [ ] Use one visibility event per recalculation, not one event per tile.
- [ ] 1.7.5 Add player-visible fact queries that hide authoritative data correctly. (AC: 3, 6)
  - [ ] Add the query on `TacticalVisibilityQuery` or a narrow sibling such as `tactical_visible_fact_query.gd` only if it keeps the API clearer.
  - [ ] Hidden cells (`visible == false` and `explored == false`) return only position and `visibility_state = "hidden"`; do not expose terrain, occupants, HP, faction, hazards, rewards, or current tactical facts.
  - [ ] Explored memory cells (`visible == false` and `explored == true`) return `visibility_state = "memory"`, position, stable terrain/display fields, and `authoritative = false`; do not expose current occupants or entity stats from `BoardCell.occupant_id`.
  - [ ] Current visible cells return `visibility_state = "visible"`, `authoritative = true`, terrain, blockers, occupant id/type/faction/HP where present, and other current tactical facts already stored in domain state.
  - [ ] Add tests proving an enemy on a hidden cell is unavailable and an enemy on an explored-memory cell is stale/non-authoritative.
- [ ] 1.7.6 Preserve movement and snapshot contracts from previous stories. (AC: 2, 4, 6)
  - [ ] Keep `MoveCommand` returning exactly one `entity_moved` event and `ActionResult.metadata["advances_turn"] == true`; do not fold fog recalculation into `MoveCommand` in this story.
  - [ ] Add or update movement-query coverage so a target that is explored but not currently visible is rejected as `invalid_movement` with reason `not_visible`.
  - [ ] Use `TacticalSnapshot.from_domain(board, streams, turn_state.to_dictionary(), [], event_log)` for invalid/no-mutation assertions where commands or event application can fail.
  - [ ] Keep `TacticalSnapshot` visibility-field serialization intact and do not introduce scene, UI, audio, animation, or presentation references.
  - [ ] Do not add attack preview, `AttackCommand`, enemy AI, hazards, Darkness affinity rules, UI fog scenes, animation, audio, save repository wiring, or autoload-owned tactical state.
- [ ] 1.7.7 Extend reusable fixtures for golden line-of-sight cases. (AC: 4, 5)
  - [ ] Extend `godot/tests/fixtures/tactical/board_fixture_factory.gd` with named fixtures for open radius, blockers, corner peeking, diagonal line, edge origin, and movement update memory.
  - [ ] Add helper methods only when they reduce duplication for future targeting and enemy tests.
  - [ ] Keep fixtures deterministic and scene-independent.
  - [ ] Update `godot/tests/unit/tactical/test_board_fixtures.gd` to prove the new fixtures are valid, deterministic, and serialize cleanly.
- [ ] 1.7.8 Run validation and update story records. (AC: 4)
  - [ ] Run `godot --version`.
  - [ ] Run `godot --headless --path C:\Sealsworn\godot --scene res://tests/headless/test_runner.tscn --quit-after 10`.
  - [ ] Run `git diff --check`.
  - [ ] Update this story's Dev Agent Record, File List, Completion Notes, and Change Log with actual implementation work.

## Dev Notes

### Current Repository Baseline

Story creation analysis on 2026-06-07 found a clean worktree and current baseline commit `3b4034044fc7e9e504624de66947886fec2ba0f8`.

Recent commits:

- `3b40340 feat: implement move command validation`
- `d8c5072 feat: complete tactical snapshot boundary`
- `6e11808 fix: complete story 1.4 review patches`
- `b69e765 feat: implement named rng stream foundation`
- `dcf393e feat: complete epic 1 tactical foundations`

Existing baseline facts:

- `BoardCell` already has `explored: bool`, `visible: bool`, and `blocks_line_of_sight()` returning true for wall terrain.
- `BoardState.to_snapshot()` and `BoardState.try_from_snapshot()` already serialize and validate cell visibility and explored memory fields.
- `TacticalSnapshot.from_domain()` already validates board snapshots and rejects scene/UI/audio/animation/presentation references.
- `TacticalMovementQuery.validate_target()` already rejects targets whose `BoardCell.visible` is false with reason `not_visible`.
- `MoveCommand` currently validates movement, emits one `entity_moved` event, applies it through `BoardState.apply_events()`, and does not run fog/line-of-sight recomputation.
- The test runner auto-discovers `test_*.gd` under `godot/tests/unit` and `godot/tests/integration`; no runner change is expected.

### Existing Files To Update Or Preserve

| Path | Current State | This Story Changes | Preserve |
|---|---|---|---|
| `godot/scripts/tactical/fog/tactical_visibility_query.gd` | Does not exist. | Add pure LoS calculation, visibility update-event creation, and visible-fact query behavior. | Must extend `RefCounted`, not `Node`; no scene tree, rendering, audio, UI, or RNG dependency. |
| `godot/scripts/core/events/domain_event.gd` | Supports `run_started`, `board_created`, `rng_stream_advanced`, `command_rejected`, and `entity_moved`. | Add `visibility_updated` event id/helper and strict payload parsing. | Keep existing event ids, movement payload behavior, and strict parse tests. |
| `godot/scripts/tactical/board/board_state.gd` | Applies board-created and entity-moved events, owns cell/entity truth, validates snapshots. | Validate/apply visibility update events atomically. | Do not bypass event sequencing, weaken occupancy validation, or turn UI-facing facts into board truth. |
| `godot/scripts/tactical/board/board_cell.gd` | Stores terrain, occupant id, `explored`, `visible`, and terrain LoS blocker helper. | No required change unless visibility memory needs a tiny stable helper. | Do not add presentation fields or expose current hidden occupants through memory facts. |
| `godot/scripts/tactical/movement/tactical_movement_query.gd` | Pure movement reachability query that requires target `visible`. | Add regression coverage for explored-but-not-visible targets if needed. | Keep movement query pure, cardinal, budgeted, and no-RNG. |
| `godot/scripts/core/commands/move_command.gd` | Successful move emits one `entity_moved` event and turn-advance metadata. | No production change expected. | Do not add fog events to `MoveCommand` or break Story 1.6 event-count tests. |
| `godot/scripts/save/snapshots/tactical_snapshot.gd` | Snapshot DTO for board, turn, pending telegraphs, RNG, and event log. | No production change expected. | Continue using it for no-mutation tests; do not make snapshots own visibility logic. |
| `godot/tests/fixtures/tactical/board_fixture_factory.gd` | Provides reusable board fixtures including line-of-sight blockers. | Add golden LoS fixtures and expected-set helpers. | Keep fixtures deterministic and scene-independent. |
| `godot/tests/unit/tactical/test_tactical_visibility_query.gd` | Does not exist. | Add LoS, recalculation, hidden/memory/visible fact, and purity coverage. | Use existing `TestCase`; do not add GUT/GdUnit. |
| `godot/tests/unit/core/test_domain_event.gd` | Covers event ids and parsing including `entity_moved`. | Add `visibility_updated` serialization/parsing/malformed-payload cases. | Preserve all previous event contracts. |
| `godot/tests/unit/tactical/test_board_state.gd` | Covers board snapshots, occupancy, event application, malformed data. | Add visibility event application/no-mutation cases if this stays the best location. | Preserve Story 1.2, 1.5, and 1.6 board contracts. |
| `godot/tests/unit/tactical/test_board_fixtures.gd` | Verifies existing fixtures are valid and deterministic. | Add fixture validation for new golden LoS fixtures. | Keep deterministic snapshot checks. |

### Visibility Semantics For This Story

- Baseline LoS radius is exactly `4` tiles.
- Visibility calculation is deterministic and scene-independent.
- Use `BoardCell.blocks_line_of_sight()` as the blocker boundary. Current walls block LoS; hazards, entrances, exits, floors, and entities do not block LoS in this story.
- Visibility has three states derived from `BoardCell.visible` and `BoardCell.explored`:
  - Hidden: `visible == false` and `explored == false`.
  - Explored memory: `visible == false` and `explored == true`.
  - Current visible truth: `visible == true`; visible cells must also be `explored == true`.
- Current visible cells can expose authoritative tactical facts.
- Explored memory can expose stable display facts such as position and terrain, but it must not expose current entity occupancy, HP, faction, hidden rewards, hazards not previously known, or any fact that would let UI/AI act on stale information as truth.
- Hidden cells expose no hidden gameplay information.
- Initial visibility for a board can be applied by creating and applying a `visibility_updated` event from the current player position.
- After a move, tests should execute `MoveCommand`, then run the visibility recalculation service against the updated board. A later turn-flow/orchestration story can decide when to chain movement, visibility, enemy turns, and level systems.

### Previous Story Intelligence

Story 1.6 established the movement contract this story must preserve:

- `MoveCommand` validates first, emits one `entity_moved` event only after success, applies through `BoardState.apply_events()`, and returns `advances_turn` metadata.
- Invalid movement returns `ActionResult.error(&"invalid_movement", metadata)`, emits no events, and leaves board, turn state, RNG streams, event log, and tactical snapshot unchanged.
- `TacticalMovementQuery` already treats non-visible targets as invalid with reason `not_visible`; Story 1.7 should make those visibility flags meaningful, not duplicate movement validation.
- `TacticalTurnState` and `TacticalActionContext` are narrow domain primitives for command execution. Do not grow them into full `LevelState`, enemy turn flow, UI mode state, save repository wiring, or autoload gameplay state in this story.

Story 1.5 established the snapshot boundary:

- `TacticalSnapshot.from_domain(board, streams, turn_state, pending_telegraphs, event_log)` validates board and RNG data before exporting.
- Tactical snapshots already include visibility fields and reject scene, UI, audio, animation, presentation, object, and callable references.
- The deferred-work file still contains older board snapshot concerns from Story 1.3. Story 1.5 and Story 1.6 records indicate stricter board/tactical snapshot validation resolved those concerns for current work. Do not treat the old deferred notes as Story 1.7 scope unless a new failing visibility test exposes a current defect.

Story 1.4 established the RNG contract:

- Pure queries and deterministic visibility recalculation must not advance any named RNG stream.
- Visibility has no gameplay randomness in this story.

### Git Intelligence

- Commit `3b40340` completed Story 1.6 and is the immediate implementation baseline. It added `MoveCommand`, `TacticalMovementQuery`, `TacticalTurnState`, `TacticalActionContext`, `entity_moved`, and movement tests.
- Commit `d8c5072` completed the tactical snapshot boundary. Use those snapshot helpers for no-mutation assertions.
- Commit `6e11808` reinforced that failed operations must not partially mutate or desynchronize restore state.
- Commit `b69e765` added named RNG streams; visibility should prove those streams stay unchanged.
- Commit `dcf393e` completed the first tactical foundations; preserve board/result/event tests as the regression baseline.

### Architecture Compliance

- The scene-independent domain model owns tactical truth. Fog and LoS calculation must live under `godot/scripts/tactical/fog/`, not scenes or UI.
- Godot scenes, effects, UI, audio, and animation may later mirror visibility results; they must not own visibility state.
- Visibility state changes should be represented as deterministic domain events so replay, logs, tests, saves, and future presentation can consume the same outcome.
- Tactical query services are the architecture boundary for pathfinding, line of sight, threat maps, valid moves, attack previews, and tile scoring.
- Save truth remains versioned domain snapshots only; never serialize scene nodes or fog presentation nodes.
- Headless tests must run without rendering, audio, UI scenes, presentation nodes, or scene-tree-only state.
- UI-heavy fog scenes, fog VFX, mobile HUD presentation, inspect panels, and attack preview UI are out of scope for this story.

### Library And Framework Requirements

- Required engine: Godot 4.6.3 stable standard build.
- Required language: typed GDScript.
- Use existing custom tests based on `godot/tests/unit/test_case.gd`; do not add GUT, GdUnit, or another test dependency.
- Use `RefCounted` for tactical domain/query classes, not `Node`.
- Use `Vector2i` for grid coordinates and typed arrays/dictionaries where current project style supports them.
- No new third-party library is required for line of sight. Prefer a small deterministic grid algorithm with golden fixtures over physics raycasts or scene queries.

### Latest Technical Information

Official Godot 4.6 documentation checked on 2026-06-07:

- The stable docs are currently the Godot Engine 4.6 documentation branch: https://docs.godotengine.org/en/stable/
- Static typing in GDScript supports typed variables, constants, functions, parameters, return types, arrays, dictionaries, and typed loop variables. Keep new domain code typed and consistent with current files: https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/static_typing.html
- `RefCounted` is the base for reference-counted helper objects and does not need manual `free()` in normal use, making it appropriate for scene-independent tactical services: https://docs.godotengine.org/en/stable/classes/class_refcounted.html
- `Vector2i` is intended for integer 2D grid coordinates and exposes distance helpers such as `distance_squared_to()`, which is useful for radius checks without square-root work: https://docs.godotengine.org/en/stable/classes/class_vector2i.html

### Project Structure Notes

- Fog and visibility domain code belongs under `godot/scripts/tactical/fog/`.
- Generic domain events belong under `godot/scripts/core/events/`.
- Board event application belongs in `godot/scripts/tactical/board/board_state.gd`.
- Tests mirror the domain they cover: visibility tests under `godot/tests/unit/tactical/`, event tests under `godot/tests/unit/core/`, save/snapshot tests under `godot/tests/unit/save/`, and fixture helpers under `godot/tests/fixtures/tactical/`.
- Runtime fog presentation, if added later, belongs under `godot/scenes/effects/fog/` or UI/presenter paths, but it is not part of this story.
- Do not add production code under `prototype/`.
- Root `project-context.md` is canonical. Do not create duplicate project-context files under `_bmad-output/`.
- No standalone UX file exists; this story is domain-first visibility work and does not need UI artifact input.

### Testing Requirements

Run at minimum:

```powershell
godot --version
godot --headless --path C:\Sealsworn\godot --scene res://tests/headless/test_runner.tscn --quit-after 10
git diff --check
```

Expected final result:

- Godot version is `4.6.3.stable.official...` or explicitly compatible with project policy.
- The full headless runner exits with code `0`.
- Existing Story 1.1 through Story 1.6 tests still pass.
- New visibility tests cover radius, blockers, diagonal/corner behavior, edge origins, movement update memory, hidden/memory/visible fact filtering, visibility event serialization/parsing, board event application/replay, unchanged RNG streams, and no-mutation invalid event application.
- No test requires rendered scenes, audio, UI scenes, presentation nodes, external services, or prototype code.

### Project Context Rules

- Read and follow root `project-context.md` before implementation.
- Read `_bmad-output/game-architecture.md` before architecture-sensitive changes.
- Production code goes under `godot/`; React/Vite `prototype/` remains validation evidence only.
- Production engine is Godot 4.6.3 stable standard; primary language is typed GDScript.
- Target platforms are iOS/Android mobile and tablet first with Windows desktop/laptop parity.
- MVP is offline-first single-player.
- Scene-independent domain model owns tactical truth.
- Commands validate before mutation and return `ActionResult`.
- Successful commands emit deterministic past-tense `DomainEvent` records.
- Use named RNG streams for gameplay-affecting randomness.
- Save versioned domain snapshots only; never serialize scene nodes as save truth.
- Headless simulation must not depend on rendering, audio, UI scenes, presentation nodes, or scene-tree-only state.
- Do not introduce cloud services, accounts, multiplayer, telemetry dependencies, or Godot .NET/C# unless the architecture is explicitly revised.
- Preserve user changes and unrelated dirty worktree files.

### References

- [Source: `_bmad-output/planning-artifacts/epics.md` - Story 1.7]
- [Source: `_bmad-output/implementation-artifacts/epic-1-sprint-plan-2026-06-04.md` - Sprint Slice 2]
- [Source: `_bmad-output/implementation-artifacts/1-6-movecommand-with-movement-validation.md` - Previous Story Intelligence]
- [Source: `project-context.md` - Determinism, domain ownership, file placement, and testing rules]
- [Source: `_bmad-output/game-architecture.md` - Core runtime architecture, tactical services, event system, fog/visibility folder mapping, and testing]
- [Source: `_bmad-output/planning-artifacts/gdds/gdd-Game-2026-05-31/gdd.md` - Core turn rules, Position Is Power pillar, controls/input, level design, and Darkness guardrail]
- [Source: Godot 4.6 stable docs](https://docs.godotengine.org/en/stable/)
- [Source: Godot 4.6 static typing docs](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/static_typing.html)
- [Source: Godot 4.6 RefCounted docs](https://docs.godotengine.org/en/stable/classes/class_refcounted.html)
- [Source: Godot 4.6 Vector2i docs](https://docs.godotengine.org/en/stable/classes/class_vector2i.html)

## Dev Agent Record

### Agent Model Used

Codex GPT-5

### Debug Log References

- 2026-06-07: Created Story 1.7 implementation guide from Epic 1 source requirements, Sprint Slice 2, prior story records, root project context, game architecture, GDD requirements, current Godot code/tests, clean git baseline, recent commits, and current Godot 4.6 documentation references.

### Implementation Plan

- Start with failing visibility query, event, visible-fact, fixture, and movement-regression tests.
- Implement the smallest typed `TacticalVisibilityQuery` service under `scripts/tactical/fog/`.
- Extend domain events and board event application for one deterministic `visibility_updated` event per recalculation.
- Add visible-fact filtering that prevents hidden or memory cells from exposing current authoritative information.
- Rerun the full headless suite and `git diff --check`.

### Completion Notes List

### File List

## Change Log

- 2026-06-07: Created Story 1.7 implementation guide and marked it ready for development.
