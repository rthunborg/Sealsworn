---
baseline_commit: 016e0b59d917a4cdbd95d804692d96cb847098df
---

# Story 1.2: Tactical Domain State and Board Model

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a player,  
I want tactical positions, cells, occupants, and combat state to be represented consistently,  
so that every move, attack, and enemy response happens on a reliable board.

## Acceptance Criteria

1. Given a new fixed tactical test level is created in domain state, when the board is initialized, then it contains a bounded grid, terrain cells, a player entity, and optional enemy entities, and the model is stored in scene-independent typed GDScript classes.
2. Given an entity is placed on the board, when occupancy is queried for its cell, then the board returns the occupying entity id, and no two blocking entities can occupy the same cell.
3. Given a cell is outside the board or blocked by terrain, when movement or placement validation queries that cell, then the board reports it as invalid for occupancy, and no domain state is mutated by the query.
4. Given the board model is used by tests, when headless tests exercise initialization, occupancy, and blocked-cell rules, then all cases pass without requiring a scene tree.
5. Given later visibility and save systems will depend on tactical state, when the board model is defined, then it exposes stable fields or interfaces for visibility state, explored memory state, entity snapshots, terrain snapshots, and board dimensions, and those fields are domain data rather than presentation state.
6. Given reusable board fixtures are created, when tests load fixture boards, then fixtures cover at least `1x1`, edge/corner movement, blocked cell, occupied cell, disconnected cells, line-of-sight blockers, and deterministic actor placement, and those fixtures can be reused by movement, visibility, targeting, and enemy tests.
7. Given board operations are queries or primitive state helpers, when movement, attack, enemy, or reward gameplay changes are needed, then they are not performed directly by the board model, and future mutations must happen through validated commands and applied domain events.

## Tasks / Subtasks

- [x] 1.2.1 Add failing board-domain tests for entity placement, terrain blocking, occupancy queries, and no-mutation validation. (AC: 1, 2, 3, 4, 7)
  - [x] Extend `godot/tests/unit/tactical/test_board_state.gd` or add focused tactical unit tests before implementation.
  - [x] Assert a fixed domain board can contain one player and optional enemies without loading scenes, UI, audio, or presentation nodes.
  - [x] Assert out-of-bounds cells, wall cells, and occupied cells return stable validation failures and do not mutate `board.to_snapshot()`.
  - [x] Assert two blocking entities cannot occupy the same cell.
  - [x] Preserve existing board snapshot, event sequence, and batch-atomicity tests.
- [x] 1.2.2 Add a minimal tactical entity state model under the tactical domain. (AC: 1, 2, 5)
  - [x] Create `godot/scripts/tactical/entities/tactical_entity_state.gd`.
  - [x] Use typed GDScript and `RefCounted`; do not extend `Node` or require a scene tree.
  - [x] Include stable serializable fields needed by this story and near-future combat: `entity_id`, `entity_type` or equivalent player/enemy kind, `faction`, `position`, `current_hp`, `max_hp`, `blocks_movement`, and alive/dead query support.
  - [x] Add deterministic `to_dictionary()` and parse/restore support, returning `ActionResult` for invalid entity data when validation can fail.
  - [x] Keep actor behavior, AI scoring, weapon data, effects, passives, and presentation binding out of this story.
- [x] 1.2.3 Extend `BoardState` with entity storage and non-mutating validation/occupancy queries. (AC: 1, 2, 3, 5, 7)
  - [x] Add deterministic entity storage keyed by `entity_id`, with stable ordering when exported in snapshots.
  - [x] Add query helpers such as `has_entity(entity_id)`, `get_entity(entity_id)`, `occupant_at(cell)`, `entity_at(cell)`, and `can_occupy(cell, entity_id := &"")`.
  - [x] Ensure validation queries return `ActionResult` with stable error codes, at minimum covering `cell_out_of_bounds`, `terrain_blocks_occupancy`, `cell_occupied`, `entity_id_already_exists`, and invalid entity data.
  - [x] Ensure validation queries never change board cells, entity dictionaries, event sequence ids, visibility flags, explored flags, or snapshots.
  - [x] Keep gameplay actions out of `BoardState`: no `MoveCommand`, no `AttackCommand`, no enemy turn logic, no reward logic.
- [x] 1.2.4 Add setup-only board helpers for terrain and initial entity placement. (AC: 1, 2, 3, 5, 7)
  - [x] Add narrowly named setup/import helpers, for example `set_cell_terrain_for_setup()` and `place_entity_for_setup()`, or an equivalent validated fixed-level initialization API.
  - [x] Stage validation before mutation so failed terrain/entity setup leaves `board.to_snapshot()` unchanged.
  - [x] Treat `BoardCell.Terrain.WALL` as blocking occupancy and future line-of-sight; keep `FLOOR`, `HAZARD`, `ENTRANCE`, and `EXIT` occupiable unless tests specify otherwise.
  - [x] Store occupancy as domain data, not as a scene-node reference. `occupant_id` must remain a stable id, not a `Node`, `ObjectID`, or runtime instance reference.
  - [x] Do not add procedural generation. Fixed test-level setup may consume deterministic fixture data only.
- [x] 1.2.5 Add reusable board fixtures for later tactical tests. (AC: 4, 6)
  - [x] Create a fixture helper such as `godot/tests/fixtures/tactical/board_fixture_factory.gd`.
  - [x] Provide reusable fixtures for `1x1`, edge/corner, blocked cell, occupied cell, disconnected cells, line-of-sight blockers, and deterministic actor placement.
  - [x] Add headless tests proving fixture boards are valid, deterministic, and scene-independent.
  - [x] Make fixture output reusable by later movement, visibility, targeting, attack, and enemy tests without coupling to UI or gameplay scenes.
- [x] 1.2.6 Preserve snapshot-ready tactical state and full headless validation. (AC: 4, 5)
  - [x] Extend `BoardState.to_snapshot()` and restore/parse paths to include terrain, visibility, explored memory, dimensions, and entity snapshots in deterministic order.
  - [x] Keep existing `BoardCell.to_dictionary()` fields compatible unless a test-driven schema change is required.
  - [x] Add corrupt snapshot tests for duplicate entity ids, entity positions outside board bounds, entities on blocking terrain, and duplicate blocking occupants.
  - [x] Run the full headless suite and record results in the Dev Agent Record before marking tasks complete.

### Review Findings

- [x] [Review][Patch] Snapshot restore does not reconcile cell occupant ids with entity snapshots [`godot/scripts/tactical/board/board_state.gd:210`]
- [x] [Review][Patch] Entity snapshot parsing silently coerces malformed fields into valid-looking data [`godot/scripts/tactical/entities/tactical_entity_state.gd:91`]
- [x] [Review][Patch] Entity validation accepts unsupported numeric entity type values [`godot/scripts/tactical/entities/tactical_entity_state.gd:50`]
- [x] [Review][Patch] Snapshot restore accepts invalid terrain enum values [`godot/scripts/tactical/board/board_state.gd:187`]
- [x] [Review][Patch] Blocking terrain setup ignores non-blocking entities already positioned on the cell [`godot/scripts/tactical/board/board_state.gd:91`]

## Dev Notes

### Current Repository Baseline

Story creation analysis on 2026-06-04 found a passing Godot/domain baseline:

- `godot --version` returned `4.6.3.stable.official.7d41c59c4`.
- `godot --headless --path C:\Sealsworn\godot --scene res://tests/headless/test_runner.tscn --quit-after 10` passed.
- Passing tests included core result/event/RNG/command tests, save tests, project setup tests, integration domain-loading tests, and `res://tests/unit/tactical/test_board_state.gd`.
- Recent commit history:
  - `016e0b5 chore: checkpoint Sealsworn planning and Godot foundation`
  - `e0e8060 Add Sealsworn architecture and agent context`
  - `7a3e1a3 Initial Sealsworn project`
- `git status --short` was already dirty at story creation because Story 1.1 artifacts and tests were present as uncommitted/untracked work. Preserve that work; do not revert or clean unrelated files while implementing Story 1.2.

### Existing Files To Update Or Preserve

| Path | Current State | This Story Changes | Preserve |
|---|---|---|---|
| `godot/scripts/tactical/board/board_state.gd` | Scene-independent `RefCounted` board with width/height, `_cells`, event sequence id, `BOARD_CREATED` event application, stable cell snapshots, bounds checks, and snapshot restore validation. | Extend with entity storage, occupancy queries, setup-only placement/terrain helpers, snapshot entity export/import, and stronger corrupt snapshot validation. | Keep scene-independent. Preserve event batch atomicity, existing `CreateBoardCommand` behavior, stable sorted cell snapshots, and no-mutation invalid paths. |
| `godot/scripts/tactical/board/board_cell.gd` | `RefCounted` cell with `Terrain` enum, position, terrain, `occupant_id`, `explored`, `visible`, `blocks_movement()`, and dictionary conversion. | Add only the terrain/visibility/occupancy helpers needed by board validation, such as line-of-sight blocker query if useful for fixtures. | Keep occupant as stable id data. Do not store scene nodes or presentation references. |
| `godot/scripts/tactical/entities/tactical_entity_state.gd` | Does not exist. | New minimal entity domain state for player/enemy occupants and HP/combat state. | Keep behavior, AI, weapon identity, passives, and presentation out of this class. |
| `godot/tests/unit/tactical/test_board_state.gd` | Covers board creation, bounds checks, board snapshots, event sequence validation, batch atomicity, corrupt cell snapshots, and sorted cell serialization. | Add red/green coverage for terrain blocking, entity placement, occupancy, no-mutation validation, entity snapshots, and corrupt entity snapshots. | Keep existing tests passing; do not weaken existing assertions to make new work easier. |
| `godot/tests/fixtures/tactical/board_fixture_factory.gd` | Does not exist. | New reusable fixture helper for later movement, visibility, targeting, and enemy tests. | Fixtures must be deterministic, headless, and domain-only. |
| `godot/tests/headless/test_runner.gd` | Custom addon-free runner discovers `res://tests/unit` and `res://tests/integration`. | No expected changes. Use the existing runner. | Do not add GUT/GdUnit or another test dependency unless explicitly approved. |
| `godot/scripts/core/results/action_result.gd` | Existing success/error result with stable error codes, ordered events, and metadata. | Use for validation queries and parse/restore failures. | Do not redesign this contract in Story 1.2; Story 1.3 is the broader result/event foundation slice. |
| `godot/scripts/core/events/domain_event.gd` | Existing event shell with `BOARD_CREATED`, RNG, command rejected, serialization, and id mapping. | Avoid broad event redesign. Add setup events only if tests prove they are necessary for board initialization. | Do not pre-implement movement, attack, damage, AI, or reward events in this story. |
| `godot/scripts/core/commands/create_board_command.gd` | Existing validated command for board creation. | Keep working; extend tests only if new board constraints require it. | Do not turn this into a fixed-level generator or gameplay command router. |
| `godot/scripts/save/snapshots/run_snapshot.gd` | Run snapshot already has a `board` dictionary slot for later tactical snapshots. | No expected changes for Story 1.2 unless board snapshot parsing requires a focused compatibility test. | Save repository and migration work belongs to later snapshot/save stories. |

### Story Scope Boundaries

Implement only the tactical board-domain state needed by Story 1.2. Do not implement:

- Movement budgets, pathfinding, reachability, or `MoveCommand`.
- Line-of-sight algorithms, fog reveal updates, or explored-memory propagation beyond storing stable cell fields and blocker fixtures.
- Weapon definitions, attack previews, `AttackCommand`, damage events, enemy AI, rewards, procedural generation, or UI scenes.
- Save repository changes, profile/meta progression, cloud services, telemetry, multiplayer, accounts, or Godot .NET/C#.

The board may expose query and setup/import helpers, but committed gameplay mutations after this story must flow through validated commands and applied domain events.

### Technical Requirements

- Production code stays under `godot/`.
- Use typed GDScript and `RefCounted` for domain model objects.
- Keep `scripts/tactical/` independent of scene nodes, rendering, audio, UI scenes, presentation nodes, and autoload-owned gameplay decisions.
- Use `Vector2i` for tactical cell coordinates, matching current board code.
- Use `StringName` or stable string ids for entity ids and occupant ids. Do not use scene-node references, object instance ids, or generated memory addresses as domain truth.
- Use deterministic ordering in snapshots and tests. Sort cells by coordinate and entities by stable id or coordinate/id tuple.
- Return `ActionResult` for validation and parse failures with stable machine-testable error codes.
- Snapshot dictionaries must contain serializable domain data only.
- Test fixture helpers belong under `godot/tests/fixtures/`; production fixtures or generated content do not belong in `prototype/`.

### Architecture Compliance

- Scene-independent domain model owns tactical truth.
- Godot scenes, UI, audio, VFX, and animation mirror domain outcomes only.
- Commands validate before mutation and return `ActionResult`; this story must not add gameplay mutations that bypass that future command/event path.
- Successful commands emit deterministic past-tense `DomainEvent` records. Existing `CreateBoardCommand` already follows this pattern and must keep passing.
- Save truth is versioned domain snapshots only; never serialize scene nodes.
- Static content and procedural generation are not part of this story.
- Headless simulation must remain runnable without rendering/audio/UI dependencies.

### Library And Framework Requirements

- Required engine: Godot 4.6.3 stable standard build.
- Required language: typed GDScript.
- Use the existing custom headless test runner; do not add GUT, GdUnit, or any new dependency for this story.
- Do not use Godot .NET/C#, React/Vite prototype code, cloud services, accounts, multiplayer, telemetry, leaderboards, or live-service dependencies.

### Latest Technical Information

Official Godot sources checked on 2026-06-04:

- Godot's official archive lists `Godot 4.6.3-stable` dated 2026-05-20. Continue using 4.6.3 unless architecture is explicitly revised. [Source: Godot 4.6.3 archive](https://godotengine.org/download/archive/4.6.3-stable/)
- Godot stable documentation for static typing states that static types can be used on variables, constants, functions, parameters, and return types, and support custom classes via `class_name` or preloads. This supports the existing typed GDScript style. [Source: Godot static typing docs](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/static_typing.html)
- Godot stable documentation identifies `RefCounted` as the base for reference-counted lightweight objects, matching the existing domain model pattern. [Source: Godot RefCounted docs](https://docs.godotengine.org/en/stable/classes/class_refcounted.html)
- Godot 4.6 core type docs describe `Array`, `TypedArray`, `Dictionary`, and `TypedDictionary` as Variant-backed containers. For deterministic snapshots, do not rely on incidental dictionary ordering; sort exported arrays explicitly. [Source: Godot 4.6 core types docs](https://docs.godotengine.org/en/4.6/engine_details/architecture/core_types.html)

### Previous Story Intelligence

Story 1.1 established the production Godot skeleton and the custom headless runner. Build on these patterns:

- Tests extend `res://tests/unit/test_case.gd` and expose a `run() -> Dictionary` method.
- The headless runner auto-discovers `test_*.gd` under `res://tests/unit` and `res://tests/integration`.
- Domain scripts use `class_name`, `extends RefCounted`, explicit type hints, and `res://` preloads.
- Invalid command/event paths are tested with no-mutation assertions.
- `BoardState.apply_events()` stages validation on a copy before mutating, preserving atomicity.
- Story 1.1 completion notes report that the full headless suite passed and no production lint/static-analysis command is configured.

### Project Structure Notes

- `godot/scripts/tactical/board/` already exists and is the correct home for board cells and board state.
- Add tactical entity state under `godot/scripts/tactical/entities/` rather than `scripts/core`, `scripts/ui`, scenes, or autoloads.
- Add fixture helpers under `godot/tests/fixtures/tactical/`; tests that exercise them should live under `godot/tests/unit/tactical/`.
- The root `project-context.md` is canonical. Do not create duplicate project context files under `_bmad-output/`.
- No standalone UX file was discovered in `planning-artifacts`; UX details are non-blocking for this domain-first story.

### Testing Requirements

Run at minimum:

```powershell
godot --version
godot --headless --path C:\Sealsworn\godot --scene res://tests/headless/test_runner.tscn --quit-after 10
```

Expected final result:

- Godot version is `4.6.3.stable.official...` or otherwise explicitly compatible with project policy.
- Headless runner exits with code `0`.
- Existing Story 1.1 tests still pass.
- New Story 1.2 tests cover valid board/entity setup, invalid/no-mutation setup, occupancy queries, blocked terrain, reusable fixtures, entity snapshots, and corrupt snapshot rejection.
- No test requires rendered scenes, audio, UI scenes, presentation nodes, external services, or prototype code.

### Project Context Rules

- Read and follow root `project-context.md` before implementation.
- Read `_bmad-output/game-architecture.md` before architecture-sensitive changes.
- Root `project-context.md` is canonical; do not create duplicate project context under `_bmad-output/`.
- Production code goes under `godot/`; React/Vite `prototype/` remains validation evidence only.
- Production engine is Godot 4.6.3 stable standard; primary language is typed GDScript.
- Target platforms are iOS/Android mobile and tablet first with Windows desktop/laptop parity.
- MVP is offline-first single-player.
- Scene-independent domain model owns tactical truth.
- Godot scenes, UI, audio, VFX, and animation mirror domain outcomes; they do not own gameplay state.
- Commands validate before mutation and return `ActionResult`.
- Successful commands emit deterministic past-tense `DomainEvent` records.
- Use named RNG streams for gameplay-affecting randomness.
- Save versioned domain snapshots only; never serialize scene nodes as save truth.
- Static content uses JSON/CSV source plus typed Godot Resources through repository/import boundaries.
- Headless simulation must not depend on rendering, audio, UI scenes, presentation nodes, or scene-tree-only state.
- Do not introduce cloud services, accounts, multiplayer, telemetry dependencies, or Godot .NET/C# unless architecture is explicitly revised.
- Preserve user changes and unrelated dirty worktree files.

### References

- [Source: `_bmad-output/planning-artifacts/epics.md` - Story 1.2]
- [Source: `_bmad-output/implementation-artifacts/epic-1-sprint-plan-2026-06-04.md` - Sprint Slice 1]
- [Source: `_bmad-output/implementation-artifacts/1-1-production-godot-project-and-headless-test-harness.md` - Previous Story Intelligence]
- [Source: `project-context.md` - Technology Stack, Engine Rules, Determinism Rules, Code Organization, Testing Rules]
- [Source: `_bmad-output/game-architecture.md` - Executive Summary, Architecture Patterns, Headless Simulation Pattern, Consistency Rules]
- [Source: `_bmad-output/planning-artifacts/gdds/gdd-Game-2026-05-31/gdd.md` - Core Turn Rules and tactical readability requirements]
- [Source: Godot 4.6.3 archive](https://godotengine.org/download/archive/4.6.3-stable/)
- [Source: Godot static typing docs](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/static_typing.html)
- [Source: Godot RefCounted docs](https://docs.godotengine.org/en/stable/classes/class_refcounted.html)
- [Source: Godot 4.6 core types docs](https://docs.godotengine.org/en/4.6/engine_details/architecture/core_types.html)

## Dev Agent Record

### Agent Model Used

Codex GPT-5

### Debug Log References

- 2026-06-04: Red-phase headless run failed after adding board/entity tests because `res://scripts/tactical/entities/tactical_entity_state.gd` did not exist yet.
- 2026-06-04: `godot --headless --path C:\Sealsworn\godot --scene res://tests/headless/test_runner.tscn --quit-after 10` passed after implementing tasks 1.2.1-1.2.4.
- 2026-06-04: `godot --headless --path C:\Sealsworn\godot --scene res://tests/headless/test_runner.tscn --quit-after 10` passed after adding reusable board fixtures for task 1.2.5.
- 2026-06-04: `godot --version` returned `4.6.3.stable.official.7d41c59c4`.
- 2026-06-04: `godot --headless --path C:\Sealsworn\godot --scene res://tests/headless/test_runner.tscn --quit-after 10` passed after final snapshot/corrupt snapshot coverage for task 1.2.6.
- 2026-06-04: Code review found five patch issues around snapshot occupancy reconciliation, strict entity parsing, terrain snapshot validation, and non-blocking entity terrain setup.
- 2026-06-04: `godot --version` returned `4.6.3.stable.official.7d41c59c4` during review patch verification.
- 2026-06-04: `godot --headless --path C:\Sealsworn\godot --scene res://tests/headless/test_runner.tscn --quit-after 10` passed after applying all review patches.

### Completion Notes List

- Story context created on 2026-06-04 from Epic 1 source requirements, the Epic 1 sprint plan, prior Story 1.1, root project context, game architecture, GDD tactical requirements, current Godot code, passing baseline tests, and official Godot technical references.
- Developer guidance intentionally scopes Story 1.2 to tactical board/entity/occupancy/domain fixtures and excludes movement, attacks, LoS algorithms, UI, procedural generation, and save repository changes.
- Added red-phase board-domain tests for fixed board setup, entity occupancy, terrain blocking, duplicate blocking occupants, stable error codes, and no-mutation validation.
- Added `TacticalEntityState` as a scene-independent typed `RefCounted` domain model with deterministic dictionary serialization, restore validation, and alive/dead queries.
- Extended `BoardState` with deterministic entity storage, occupancy/entity query helpers, setup-only terrain/entity placement helpers, and entity snapshot export/import.
- Added reusable headless board fixtures for 1x1, edge/corner, blocked, occupied, disconnected, line-of-sight blocker, and deterministic actor-placement boards.
- Added snapshot round-trip and corrupt snapshot rejection coverage for entity state, blocking terrain, visibility, explored memory, dimensions, duplicate entity ids, out-of-bounds entities, and duplicate blocking occupants.
- Review patches applied: snapshot restore now validates terrain and reconciles raw cell occupants with entity snapshots; entity parsing rejects malformed/coerced fields and unsupported numeric types; wall setup rejects any entity already positioned on the target cell.

### File List

- `_bmad-output/implementation-artifacts/1-2-tactical-domain-state-and-board-model.md`
- `_bmad-output/implementation-artifacts/sprint-status.yaml`
- `godot/scripts/tactical/board/board_cell.gd`
- `godot/scripts/tactical/board/board_state.gd`
- `godot/scripts/tactical/entities/tactical_entity_state.gd`
- `godot/tests/fixtures/tactical/board_fixture_factory.gd`
- `godot/tests/unit/tactical/test_board_fixtures.gd`
- `godot/tests/unit/tactical/test_board_state.gd`
- `godot/tests/unit/tactical/test_tactical_entity_state.gd`

## Change Log

- 2026-06-04: Created Story 1.2 implementation guide and marked it ready for development.
- 2026-06-04: Implemented board entity state, occupancy validation, setup helpers, and tactical entity tests for tasks 1.2.1-1.2.4.
- 2026-06-04: Added reusable tactical board fixture factory and fixture validation tests for task 1.2.5.
- 2026-06-04: Completed snapshot-ready tactical state validation and moved Story 1.2 to review.
- 2026-06-04: Applied code review fixes and moved Story 1.2 to done.
