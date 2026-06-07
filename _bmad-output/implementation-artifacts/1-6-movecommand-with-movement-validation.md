---
baseline_commit: d8c50724d0951445531eaaefe1c15c0123c1d0aa
---

# Story 1.6: MoveCommand with Movement Validation

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a player,
I want to move up to the baseline movement budget through valid cells,
so that tactical positioning is clear, deliberate, and reproducible.

## Acceptance Criteria

1. Given the player has the baseline 3-tile movement budget, when `MoveCommand` targets a reachable valid cell within 3 tiles, then the command succeeds and emits an `EntityMovedEvent`, and the player occupant moves to the target cell.
2. Given a target cell is blocked, occupied by a blocking entity, outside the board, beyond movement budget, selected by an invalid actor id, or requested in the wrong turn phase, when `MoveCommand` executes, then the command returns an invalid movement error, and player position, turn state, board occupancy, tactical snapshot, RNG state, and event log remain unchanged.
3. Given a successful player move is committed, when the command result is returned, then it indicates that enemy and level systems should advance, and the result is suitable for turn-flow handling in a later enemy-resolution story.
4. Given movement validation rejects a target, when the result is presented through debug or UI-facing data, then it can distinguish blocked, occupied, out-of-bounds, beyond-budget, invalid-actor, wrong-phase, and unseen-or-unreachable reasons, and the reason comes from domain validation rather than UI-only logic.
5. Given movement tests run headlessly, when valid movement and each invalid/no-mutation case are tested, then every movement command test passes without presentation dependencies.

## Tasks / Subtasks

- [x] 1.6.1 Add failing headless movement tests before implementation. (AC: 1, 2, 3, 4, 5)
  - [x] Add `godot/tests/unit/core/test_move_command.gd` using the existing addon-free `TestCase` style.
  - [x] Add focused query tests in `godot/tests/unit/tactical/test_tactical_movement_query.gd` if the movement query service has enough behavior to justify separate coverage.
  - [x] Cover a successful player move within 3 orthogonal steps, asserting one `entity_moved` event, stable event payload, changed board occupancy, updated actor position, unchanged RNG stream snapshot, and `ActionResult.metadata["advances_turn"] == true`.
  - [x] Cover invalid movement for wall/terrain-blocked target, occupied target, out-of-bounds target, beyond-budget target, invalid actor id, wrong turn phase, target not currently visible, unreachable/disconnected target, and same-cell no-op.
  - [x] For every invalid case, compare pre/post `TacticalSnapshot.from_domain(board, streams, turn_state.to_dictionary(), [], event_log)` output and assert no board, turn state, RNG, event-log, sequence-id, or occupancy mutation.
  - [x] Assert every invalid result uses `ActionResult.error(&"invalid_movement", metadata)` or a narrower stable lower-snake movement code, with a machine-readable `reason` such as `blocked`, `occupied`, `out_of_bounds`, `beyond_budget`, `invalid_actor`, `wrong_phase`, `not_visible`, `unreachable`, or `same_cell`.
- [x] 1.6.2 Add narrow turn/context domain primitives needed by movement commands. (AC: 2, 3, 4)
  - [x] Add `godot/scripts/tactical/turns/tactical_turn_state.gd` with typed `RefCounted` data for `turn_number`, `phase`, and `active_actor_id`.
  - [x] Define stable phase ids for at least `player_planning`, `player_resolving`, `enemy_planning`, `enemy_resolving`, and `environment_resolving`, matching the architecture's `TurnState` phases.
  - [x] Provide `to_dictionary()` for no-mutation tactical snapshot comparisons and either `copy()` or strict `try_from_dictionary()` if tests need restored turn-state objects.
  - [x] Add `godot/scripts/tactical/tactical_action_context.gd` as a thin wrapper for `BoardState`, `TacticalTurnState`, and `RngStreamSet` so `MoveCommand.execute(state: Variant)` receives one scene-independent object.
  - [x] Do not create full `LevelState`, enemy turn resolution, environment resolution, UI mode state, save repository wiring, or autoload-owned tactical state in this story.
- [x] 1.6.3 Implement a single tactical movement query boundary. (AC: 1, 2, 4)
  - [x] Add `godot/scripts/tactical/movement/tactical_movement_query.gd` or an equivalent tactical-domain path/query service.
  - [x] Use the existing `BoardState`, `BoardCell`, and `TacticalEntityState` APIs for dimensions, terrain, occupancy, actor position, and visibility; do not duplicate board storage.
  - [x] Baseline movement is cardinal/orthogonal, one tile per step, no diagonal movement, no weighted terrain costs, and no rule-bender overrides until later stories.
  - [x] Baseline budget is `3` tiles per committed move action; expose it as a constant on `MoveCommand` or the movement query service.
  - [x] Treat the target as valid only if it is in bounds, currently visible, reachable through passable cells, not blocked by terrain, not occupied by another blocking entity, and within budget.
  - [x] Keep query behavior pure: no board mutation, no turn-state mutation, no event emission, and no RNG calls.
  - [x] If `AStarGrid2D` is used internally, wrap it behind the movement query service, configure it deterministically from `BoardState`, disable diagonals/partial paths, and keep tests asserted against domain results. For the 3-tile budget, a deterministic bounded BFS is acceptable if it preserves stable domain reason codes more clearly.
- [x] 1.6.4 Extend domain event and board application support for movement. (AC: 1, 2)
  - [x] Extend `godot/scripts/core/events/domain_event.gd` with `Type.ENTITY_MOVED`, event id `entity_moved`, and a helper such as `DomainEvent.entity_moved(sequence_id, actor_id, from_cell, to_cell, movement_cost)`.
  - [x] Serialize movement events with stable dictionary payload fields: `from` `{x, y}`, `to` `{x, y}`, `movement_cost`, and `movement_budget`.
  - [x] Update `DomainEvent.try_from_dictionary()` tests so `entity_moved` parses, serializes, and rejects malformed sequence/id/payload data with stable errors.
  - [x] Extend `BoardState._validate_event()` and `_apply_validated_event()` to validate and apply `ENTITY_MOVED` atomically.
  - [x] Event application must confirm sequence id, actor existence, actor current position matches the event `from`, target bounds, target occupancy legality, and target terrain legality before mutation.
  - [x] Event application must update the stored entity position, clear the previous blocking cell occupant, set the target blocking cell occupant, and preserve stable snapshot ordering.
- [x] 1.6.5 Implement `MoveCommand`. (AC: 1, 2, 3, 4)
  - [x] Add `godot/scripts/core/commands/move_command.gd` with `class_name MoveCommand extends GameCommand`.
  - [x] Use typed fields for `actor_id: StringName`, `target_cell: Vector2i`, and an optional `movement_budget: int = 3`.
  - [x] `validate()` must reject invalid context type, invalid actor id, dead actor if encountered, wrong active actor, wrong phase, same-cell movement, unseen target, blocked target, occupied target, out-of-bounds target, unreachable target, and beyond-budget target without mutating anything.
  - [x] `execute()` must call validation first, then create a single `EntityMovedEvent`, apply it through `BoardState.apply_events()`, and return `ActionResult.ok([event], {"advances_turn": true, "movement_cost": cost, "movement_budget": movement_budget})`.
  - [x] Failed movement must return no events and must not advance board sequence ids or RNG stream states.
  - [x] Do not resolve enemies, hazards, fog reveal, line of sight recomputation, animation, audio, UI selection state, or save writes in `MoveCommand`.
- [x] 1.6.6 Preserve previous story contracts while touching shared files. (AC: 1, 2, 5)
  - [x] Keep `CreateBoardCommand` behavior unchanged.
  - [x] Keep `ActionResult` success/error contracts unchanged unless a failing test proves a narrow need.
  - [x] Keep `TacticalSnapshot` scene-reference filtering, deep-copy behavior, strict board/RNG validation, and event-log ordering intact.
  - [x] Keep `BoardFixtureFactory` reusable; add helper methods only when they reduce duplication for movement visibility/path fixtures.
  - [x] Do not weaken Story 1.2 board tests, Story 1.3 event/result tests, Story 1.4 RNG tests, or Story 1.5 snapshot tests.
- [x] 1.6.7 Run validation and update story records. (AC: 5)
  - [x] Run `godot --version`.
  - [x] Run `godot --headless --path C:\Sealsworn\godot --scene res://tests/headless/test_runner.tscn --quit-after 10`.
  - [x] Run `git diff --check`.
  - [x] Update this story's Dev Agent Record, File List, Completion Notes, and Change Log with actual implementation work.

### Review Findings

- [x] [Review][Patch] Sprint status header `# last_updated` did not match canonical `last_updated` after Story 1.6 status update [`_bmad-output/implementation-artifacts/sprint-status.yaml:2`]

## Dev Notes

### Current Repository Baseline

Story creation analysis on 2026-06-06 found a clean worktree and current baseline commit `d8c50724d0951445531eaaefe1c15c0123c1d0aa`.

Recent commits:

- `d8c5072 feat: complete tactical snapshot boundary`
- `6e11808 fix: complete story 1.4 review patches`
- `b69e765 feat: implement named rng stream foundation`
- `dcf393e feat: complete epic 1 tactical foundations`
- `5b8de38 chore: checkpoint epic 1 story 1.1 baseline`

Existing baseline facts:

- `MoveCommand` does not exist yet.
- `DomainEvent` currently supports `run_started`, `board_created`, `rng_stream_advanced`, and `command_rejected`; movement needs a new `entity_moved` id.
- `BoardState._validate_event()` currently applies `BOARD_CREATED` only; movement must extend this event-application boundary rather than mutating board storage directly from the command.
- `BoardState` already exposes `in_bounds()`, `get_cell()`, `can_occupy()`, `occupant_at()`, `entity_at()`, `get_entity()`, `to_snapshot()`, `try_from_snapshot()`, and `validate_snapshot_consistency()`.
- `BoardCell` already exposes `blocks_movement()`, `terrain_blocks_occupancy()`, `blocks_line_of_sight()`, `visible`, and `explored`.
- `TacticalEntityState` already stores `entity_id`, `entity_type`, `faction`, `position`, HP, and `blocks_movement`.
- `TacticalSnapshot.from_domain()` can compare board, turn-state dictionary, pending telegraphs, RNG streams, and event log for no-mutation tests.
- The test runner auto-discovers `test_*.gd` under `godot/tests/unit` and `godot/tests/integration`; no runner change is expected.

### Existing Files To Update Or Preserve

| Path | Current State | This Story Changes | Preserve |
|---|---|---|---|
| `godot/scripts/core/commands/move_command.gd` | Does not exist. | Add validated movement command. | Follow `GameCommand`/`CreateBoardCommand` command-result style. |
| `godot/scripts/tactical/movement/tactical_movement_query.gd` | Does not exist. | Add pure movement reachability/path validation service. | Do not mutate board, turn state, RNG, or presentation state. |
| `godot/scripts/tactical/turns/tactical_turn_state.gd` | Does not exist. | Add narrow phase/active actor data needed for wrong-phase validation. | Do not grow into full `LevelState` or enemy turn resolver. |
| `godot/scripts/tactical/tactical_action_context.gd` | Does not exist. | Add thin one-argument command context for board/turn/RNG. | Context is wiring, not authoritative gameplay logic. |
| `godot/scripts/core/events/domain_event.gd` | Stable generic event record with strict parse and event ids. | Add `entity_moved` id/helper and tests. | Keep deterministic dictionary fields and strict parse behavior. |
| `godot/scripts/tactical/board/board_state.gd` | Authoritative scene-independent board with event sequencing, occupancy, strict snapshot validation, and setup helpers. | Validate/apply movement events atomically. | Do not bypass `apply_events()`, mutate directly from UI, or weaken snapshot validation. |
| `godot/tests/unit/core/test_domain_event.gd` | Covers stable event ids and parsing. | Add `entity_moved` serialization/parsing cases. | Preserve existing id expectations and malformed-event checks. |
| `godot/tests/unit/core/test_move_command.gd` | Does not exist. | Add command valid/invalid/no-mutation tests. | Use `TestCase`; no GUT/GdUnit dependency. |
| `godot/tests/unit/tactical/test_tactical_movement_query.gd` | Does not exist. | Optional focused query service tests. | Keep path/query tests headless and domain-only. |
| `godot/tests/fixtures/tactical/board_fixture_factory.gd` | Reusable board fixtures for board, blockers, occupied, disconnected, LoS blockers, deterministic actors. | Add visible movement fixtures only if useful. | Do not duplicate board setup helpers across tests. |
| `godot/scripts/save/snapshots/tactical_snapshot.gd` | Strict tactical snapshot DTO. | No expected production change. | Use for tests; do not turn snapshots into gameplay owners. |
| `godot/scripts/core/results/action_result.gd` | Stable success/error/events/metadata result shape. | No expected change. | Keep lower-snake error codes and no-events invalid contract. |
| `godot/scripts/core/state/rng_stream_set.gd` | Named RNG stream set and snapshots. | No expected change. | Movement should not consume RNG. |

### Movement Semantics For This Story

- Baseline movement budget is exactly `3` tiles.
- Movement is cardinal/orthogonal only for MVP baseline. Diagonal movement and variable terrain costs are out of scope.
- Each traversed floor/entrance/exit/hazard cell costs `1` unless later rules override it. Hazard damage/effects are out of scope here.
- `BoardCell.Terrain.WALL` blocks occupancy and movement.
- Another blocking entity blocks the target and path.
- Moving into the acting entity's current cell is not a move; reject it as `same_cell` and leave `WaitCommand` or pass/hold behavior for later.
- The target must be currently visible according to the board's existing `BoardCell.visible` flag. Story 1.7 owns LoS/fog recomputation; Story 1.6 only consumes the current visibility flags.
- Unreachable means no valid cardinal path exists through passable cells from actor position to target under current board state.
- Beyond-budget means a valid path exists but its movement cost is greater than the command budget.
- A successful move returns data that future enemy/environment turn flow can consume, but it does not run enemy AI, hazards, fog reveal, or level systems yet.

### Previous Story Intelligence

Story 1.5 established the snapshot boundary this story must use for invalid/no-mutation tests:

- `TacticalSnapshot.from_domain(board, streams, turn_state, pending_telegraphs, event_log)` validates board/RNG data before exporting.
- Tactical snapshots reject scene, UI, audio, animation, presentation, object, and callable references.
- Board snapshots now validate cell containers, entity containers, sequence ids, occupant consistency, and source board storage consistency.
- `BoardState.validate_snapshot_consistency()` should catch mutable `get_cell()` desynchronization before a snapshot is accepted.
- The deferred-work file still lists older board snapshot concerns from Story 1.3, but Story 1.5's completion record says those issues were resolved through stricter board/tactical snapshot validation. Do not treat the old deferred notes as Story 1.6 scope unless new failing movement tests expose a current defect.

Story 1.4 established the RNG contract:

- `RngStreamSet.to_snapshot()` and `try_restore()` preserve root seed, required stream states, and draw indexes.
- Invalid commands and pure queries must not advance gameplay streams.
- Movement has no gameplay randomness in this story.

Story 1.3 established result/event behavior:

- Commands validate before mutation and return `ActionResult`.
- Failed commands expose stable error codes, return zero events, and preserve snapshots.
- Domain event dictionaries use stable event ids instead of raw enum integers.
- Event replay/application should reproduce the command-mutated state.

Story 1.2 established board behavior:

- Board state is scene-independent and authoritative.
- Entities are stored by stable id; blocking entity occupancy is mirrored into `BoardCell.occupant_id`.
- Board snapshots export cells in coordinate order and entities in stable id order.
- Board operations are primitive queries/setup helpers; gameplay mutations should happen through validated commands and applied domain events.

Story 1.1 established the production harness:

- Run tests with `godot --headless --path C:\Sealsworn\godot --scene res://tests/headless/test_runner.tscn --quit-after 10`.
- Keep production code independent from `prototype/`, cloud services, telemetry, accounts, multiplayer, and Godot .NET/C#.

### Git Intelligence

- Commit `d8c5072` completed Story 1.5 and is the immediate implementation baseline. Build on the tactical snapshot/no-mutation helpers from that work.
- Commit `6e11808` fixed RNG review patches, reinforcing that failed operations must not partially mutate or desynchronize restore state.
- Commit `b69e765` added named RNG streams; movement should prove those streams stay unchanged.
- Commit `dcf393e` completed the first tactical foundations; preserve board/result/event tests as the regression baseline.

### Architecture Compliance

- The scene-independent domain model owns tactical truth. `MoveCommand` and movement queries must not depend on scenes, controls, audio, animation, VFX, or autoload-owned gameplay state.
- Commands validate before mutation and return `ActionResult`.
- Successful movement emits deterministic past-tense `EntityMovedEvent` data and applies it through `BoardState.apply_events()`.
- Invalid movement emits no domain events and performs no mutation.
- UI and presentation may later observe movement results, but they must not own movement legality.
- Named RNG streams remain untouched by deterministic movement.
- Tactical snapshots remain save/test DTOs only; they do not own gameplay decisions.
- Headless tests must run without rendering, audio, UI scenes, presentation nodes, or scene-tree-only state.

### Library And Framework Requirements

- Required engine: Godot 4.6.3 stable standard build.
- Required language: typed GDScript.
- Use existing custom tests based on `godot/tests/unit/test_case.gd`; do not add GUT, GdUnit, or another test dependency.
- Use `RefCounted` for domain/query/turn/context classes, not `Node`.
- Use typed arrays/dictionaries where current project style supports them.
- If Godot pathfinding helpers are used, keep them behind `TacticalMovementQuery`; command tests should assert Sealsworn domain behavior, not Godot API internals.

### Latest Technical Information

Official Godot 4.6 documentation checked on 2026-06-06:

- Static typing remains the documented GDScript practice for typed variables, parameters, return values, and typed arrays; keep new domain code typed and consistent with current files.
- `AStarGrid2D` is documented as `RefCounted < Object`, so it can be used in headless domain tests without requiring a scene tree if wrapped carefully.
- `AStarGrid2D.get_id_path(from_id: Vector2i, to_id: Vector2i, allow_partial_path: bool = false)` and `get_point_path(...)` exist in Godot 4.6. If used, disable partial paths for movement validation so an unreachable target does not masquerade as a valid move.
- `AStarGrid2D` can simplify grid pathfinding, but this story's radius-3 orthogonal movement also permits a small deterministic bounded search if it better preserves stable domain reason codes.

### Project Structure Notes

- Core command files belong under `godot/scripts/core/commands/`.
- Generic domain events belong under `godot/scripts/core/events/`.
- Tactical movement/query/turn domain files belong under `godot/scripts/tactical/`.
- Tests mirror the domain they cover: command tests under `godot/tests/unit/core/`, tactical movement query tests under `godot/tests/unit/tactical/`, and fixture helpers under `godot/tests/fixtures/tactical/`.
- Do not add production code under `prototype/`.
- Root `project-context.md` is canonical. Do not create duplicate project-context files under `_bmad-output/`.
- No standalone UX file exists; this story is domain-first movement work and does not need UI artifact input.

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
- Existing Story 1.1 through Story 1.5 tests still pass.
- New movement tests cover valid movement, every invalid/no-mutation case, event serialization/parsing, board event application/replay, unchanged RNG streams, unchanged turn state on invalid movement, and `advances_turn` result metadata on successful movement.
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

- [Source: `_bmad-output/planning-artifacts/epics.md` - Story 1.6]
- [Source: `_bmad-output/implementation-artifacts/epic-1-sprint-plan-2026-06-04.md` - Sprint Slice 2]
- [Source: `_bmad-output/implementation-artifacts/1-5-tactical-snapshot-serialization-boundary.md` - Previous Story Intelligence]
- [Source: `project-context.md` - Commands, events, movement, determinism, file placement, and testing rules]
- [Source: `_bmad-output/game-architecture.md` - Core runtime architecture, turn state, tactical services, command/event simulation, and project structure]
- [Source: `_bmad-output/planning-artifacts/gdds/gdd-Game-2026-05-31/gdd.md` - Core turn rules and Position Is Power pillar]
- [Source: Godot 4.6 static typing docs](https://docs.godotengine.org/en/4.6/tutorials/scripting/gdscript/static_typing.html)
- [Source: Godot 4.6 AStarGrid2D docs](https://docs.godotengine.org/en/4.6/classes/class_astargrid2d.html)

## Dev Agent Record

### Agent Model Used

Codex GPT-5

### Debug Log References

- 2026-06-06: Created Story 1.6 implementation guide from Epic 1 source requirements, Sprint Slice 2, prior story records, root project context, game architecture, GDD requirements, current Godot code/tests, clean git baseline, recent commits, and current Godot 4.6 documentation references.
- 2026-06-07: Activated `gds-dev-story`, preserved existing baseline commit `d8c50724d0951445531eaaefe1c15c0123c1d0aa`, and moved story tracking to `in-progress`.
- 2026-06-07: Added RED movement coverage for command success/replay, invalid no-mutation snapshots, movement query reason codes, `entity_moved` serialization/parsing, and board event application. Initial headless run failed on missing `entity_moved` API/type as expected.
- 2026-06-07: Implemented narrow `TacticalTurnState`, `TacticalActionContext`, deterministic cardinal `TacticalMovementQuery`, `EntityMovedEvent` support, atomic board movement event application, and `MoveCommand`.
- 2026-06-07: Validation passed: `godot --version` reported `4.6.3.stable.official.7d41c59c4`; full headless runner passed; `git diff --check` exited cleanly with only CRLF conversion warnings.
- 2026-06-07: Code review found one patch finding: sprint-status header timestamp mismatch after Story 1.6 status update. Fixed the header to match the canonical `last_updated` value.
- 2026-06-07: Post-review validation passed: `godot --version` reported `4.6.3.stable.official.7d41c59c4`; full headless runner passed; `git diff --check` exited cleanly with only CRLF conversion warnings.

### Implementation Plan

- Start with failing command/event/query tests that prove valid movement and every invalid/no-mutation branch.
- Add the smallest typed turn/context objects needed for movement phase validation.
- Implement movement reachability behind one tactical query service.
- Extend domain events and board event application for `entity_moved`.
- Implement `MoveCommand` through the command/result/event path and rerun the full headless suite.

### Completion Notes List

- Added scene-independent movement command flow with `MoveCommand`, `TacticalActionContext`, and `TacticalTurnState`; successful moves validate first, emit one `entity_moved` event, apply through `BoardState.apply_events()`, and return turn-advance metadata.
- Added a pure `TacticalMovementQuery` using deterministic cardinal BFS for baseline 3-tile movement, stable path metadata, and machine-readable invalid reasons for blocked, occupied, out-of-bounds, beyond-budget, invalid actor, wrong phase, not visible, unreachable, dead actor, invalid context, and same-cell cases.
- Extended `DomainEvent` and `BoardState` for strict `entity_moved` serialization/parsing and atomic board event application that updates entity position and blocking occupancy only after validation.
- Added headless command, query, event, and board-event tests covering valid movement, replay, invalid/no-mutation tactical snapshots, malformed movement payloads, unchanged RNG state, and preservation of existing board/result/event/snapshot contracts.
- Kept Story 1.6 scoped to domain movement only: no enemy resolution, hazards, fog recomputation, UI, animation, audio, save writes, autoload gameplay state, prototype dependency, cloud, telemetry, multiplayer, or Godot .NET/C# changes.
- Resolved the code review patch finding by syncing the sprint-status header timestamp with the canonical `last_updated` field before marking the story done.

### File List

- `_bmad-output/implementation-artifacts/1-6-movecommand-with-movement-validation.md`
- `_bmad-output/implementation-artifacts/sprint-status.yaml`
- `godot/scripts/core/commands/move_command.gd`
- `godot/scripts/core/events/domain_event.gd`
- `godot/scripts/tactical/board/board_state.gd`
- `godot/scripts/tactical/movement/tactical_movement_query.gd`
- `godot/scripts/tactical/tactical_action_context.gd`
- `godot/scripts/tactical/turns/tactical_turn_state.gd`
- `godot/tests/unit/core/test_domain_event.gd`
- `godot/tests/unit/core/test_move_command.gd`
- `godot/tests/unit/tactical/test_board_state.gd`
- `godot/tests/unit/tactical/test_tactical_movement_query.gd`

## Change Log

- 2026-06-06: Created Story 1.6 implementation guide and marked it ready for development.
- 2026-06-07: Implemented MoveCommand movement validation, movement query service, turn/action context primitives, entity movement events, board event application, and headless movement coverage; story marked ready for review.
- 2026-06-07: Resolved code review patch finding and moved Story 1.6 to done.
