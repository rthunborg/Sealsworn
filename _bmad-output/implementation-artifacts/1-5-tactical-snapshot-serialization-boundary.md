---
baseline_commit: 6e118089a2af49d073e3e875960735f3ff46f572
---

# Story 1.5: Tactical Snapshot Serialization Boundary

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a developer,
I want the tactical domain state to round-trip through a lightweight snapshot,
so that deterministic combat, save/resume, and replay requirements are protected before UI save flows exist.

## Acceptance Criteria

1. Given a tactical domain state contains board dimensions, terrain, visibility fields, entities, HP, turn state, pending telegraphs, and named RNG stream states, when a tactical snapshot is exported, then the snapshot contains only serializable domain data, and no scene nodes, UI controls, audio, animation, or presentation references are included.
2. Given a tactical snapshot is imported into a fresh domain state, when the same command is executed from both original and restored state, then the resulting domain snapshots, ordered events, and gameplay RNG stream states match, and the test runs headlessly.
3. Given an invalid, missing-version, or incompatible tactical snapshot is loaded, when snapshot validation runs, then it returns a structured load error, and no partial tactical state becomes active.
4. Given invalid command tests need no-mutation assertions, when a command fails validation, then tests can compare pre-command and post-command tactical snapshots, and failed commands emit zero past-tense domain events.

## Tasks / Subtasks

- [x] 1.5.1 Add failing tactical snapshot DTO tests before implementation. (AC: 1, 3)
  - [x] Create `godot/tests/unit/save/test_tactical_snapshot.gd` using the existing addon-free `TestCase` style.
  - [x] Cover a valid snapshot dictionary with `schema_version`, `content_version`, `board`, `turn_state`, `pending_telegraphs`, `rng_streams`, and `event_log`.
  - [x] Assert export deep-copies nested dictionaries and arrays so caller mutation cannot rewrite stored snapshot data.
  - [x] Assert `to_dictionary()` output is JSON-compatible domain data only: primitives, arrays, and dictionaries; no `Object`, `Node`, `Callable`, `RID`, scene path, UI, audio, animation, or presentation references.
  - [x] Assert missing `schema_version`, unsupported schema version, malformed containers, malformed event log entries, and malformed RNG snapshots return `ActionResult.error(&"invalid_tactical_snapshot", metadata)` or a narrower stable lower-snake error code.
  - [x] Assert failed snapshot parse returns no `snapshot` object in metadata and does not mutate an existing board or RNG object supplied by the test.
- [x] 1.5.2 Implement the tactical snapshot DTO as a save-layer boundary, not a new gameplay state owner. (AC: 1, 3)
  - [x] Add `godot/scripts/save/snapshots/tactical_snapshot.gd` with `class_name TacticalSnapshot extends RefCounted`.
  - [x] Define `SCHEMA_VERSION: int = 1`, `content_version: String = "mvp-0"`, `board: Dictionary`, `turn_state: Dictionary`, `pending_telegraphs: Array[Dictionary]`, `rng_streams: Dictionary`, and `event_log: Array[Dictionary]`.
  - [x] Provide `to_dictionary() -> Dictionary`, `parse(data: Dictionary) -> ActionResult`, and `from_dictionary(data: Dictionary) -> TacticalSnapshot` compatibility wrapper following `RunSnapshot` patterns.
  - [x] Add a construction helper such as `from_domain(board_state: BoardState, rng_streams: RngStreamSet, turn_state: Dictionary = {}, pending_telegraphs: Array[Dictionary] = [], event_log: Array[DomainEvent] = []) -> ActionResult`.
  - [x] In `from_domain`, validate board and RNG snapshots before storing them; do not export a tactical snapshot from a corrupt or desynchronized board.
  - [x] Store event log entries as `DomainEvent.to_dictionary()` output only. Preserve event order exactly.
  - [x] Keep this DTO under `scripts/save/snapshots/`; do not move tactical truth into `scripts/save/`, autoloads, scenes, or UI.
- [x] 1.5.3 Harden board and cell snapshot validation where it is part of the tactical boundary. (AC: 1, 3, 4)
  - [x] Add strict `BoardCell.try_from_dictionary(data: Dictionary) -> ActionResult` and route `BoardCell.from_dictionary()` through it.
  - [x] Reject malformed cell fields instead of coercing them: missing/non-dictionary `position`, missing/non-integral `x` or `y`, non-integral `terrain`, non-string-like `occupant_id`, and non-bool `explored` or `visible`.
  - [x] In `BoardState.try_from_snapshot()`, reject a missing or non-Array `cells` container before assigning it to a typed `Array`.
  - [x] Preserve existing stable ordering of serialized cells by coordinate and entities by id.
  - [x] Resolve the occupant consistency gap from deferred work: every blocking entity must have a matching cell `occupant_id`, every non-empty cell `occupant_id` must refer to a blocking entity at that same position, and non-blocking entities must not occupy cells.
  - [x] Add tests for ghost occupants, misplaced occupants, missing cell occupants for blocking entities, occupant ids on non-blocking entities, duplicate entity ids, duplicate occupied cells, malformed cell fields, and no-mutation on rejected imports.
  - [x] Do not redesign the broader board API unless required to validate or export snapshots safely. If `get_cell()` remains mutable, make tactical snapshot export validate the board before accepting it.
- [x] 1.5.4 Add restore and deterministic continuation coverage. (AC: 2)
  - [x] Use existing fixtures, especially `BoardFixtureFactory.deterministic_actor_placement()`, instead of building parallel board setup helpers.
  - [x] Create a tactical snapshot from a board plus a `RngStreamSet` whose gameplay streams have advanced.
  - [x] Restore the snapshot into a fresh `BoardState` and fresh `RngStreamSet`.
  - [x] Execute the same next command from the original and restored state. With the current baseline, use the existing `CreateBoardCommand` invalid duplicate path or another already-existing command; do not invent `MoveCommand`, `AttackCommand`, or combat systems for this story.
  - [x] Assert final tactical snapshots match, returned ordered events match, failed-command event arrays are empty, and gameplay RNG stream snapshots match.
  - [x] Include at least one successful gameplay RNG draw after restore and assert the original/restored draw values and draw audit metadata match for the same stream and consumer context.
  - [x] Keep the test headless and domain-only; it must not instantiate scenes, UI controls, audio nodes, animation players, or presentation nodes.
- [x] 1.5.5 Use tactical snapshots for invalid/no-mutation test helpers. (AC: 4)
  - [x] Add focused test helper code, either inside `test_tactical_snapshot.gd` or under `godot/tests/fixtures/tactical/`, for comparing tactical snapshots before and after invalid commands.
  - [x] Update the existing invalid `CreateBoardCommand` no-mutation test to prove the top-level tactical snapshot boundary can replace ad hoc board-only snapshot comparison.
  - [x] Keep existing board-specific assertions in place where they document board behavior; do not weaken Story 1.2 or Story 1.3 coverage.
  - [x] Assert failed commands expose no past-tense `DomainEvent` records and do not advance board sequence ids or gameplay RNG stream states.
- [x] 1.5.6 Preserve save/autoload boundaries and add only narrow integration coverage. (AC: 1, 3)
  - [x] Update `godot/tests/unit/save/test_run_snapshot.gd` only if the tactical snapshot dictionary needs focused round-trip coverage through existing `RunSnapshot.board`, `RunSnapshot.turn_state`, or `RunSnapshot.rng_streams` fields.
  - [x] Do not wire tactical snapshots into `SaveRepository` or `SaveManager` yet unless a failing test proves a narrow compatibility issue. Between-level save/resume belongs to Epic 2.
  - [x] If `GameSession` is touched, keep it as thin seed/RNG/session wiring. It must not own tactical state, turn decisions, snapshot schema policy, or command validation.
  - [x] Do not introduce save migrations beyond schema 1 tactical snapshot validation. If a migration question appears, record it as deferred work unless it blocks this story's acceptance criteria.
- [x] 1.5.7 Run required validation and update story records. (AC: 1, 2, 3, 4)
  - [x] Run `godot --version`.
  - [x] Run `godot --headless --path C:\Sealsworn\godot --scene res://tests/headless/test_runner.tscn --quit-after 10`.
  - [x] Run `git diff --check`.
  - [x] Update this story's Dev Agent Record, File List, Completion Notes, and Change Log with actual work completed.

### Review Findings

- [x] [Review][Patch] Board snapshot import accepts missing or non-positive `next_sequence_id` and silently resets event sequencing [godot/scripts/tactical/board/board_state.gd:199]
- [x] [Review][Patch] Board snapshot import can silently accept a missing or malformed `entities` container [godot/scripts/tactical/board/board_state.gd:192]
- [x] [Review][Patch] Tactical snapshot parse accepts incompatible `content_version` values instead of rejecting them [godot/scripts/save/snapshots/tactical_snapshot.gd:44]
- [x] [Review][Patch] Tactical snapshot export validation misses source board cell-key consistency after mutable `get_cell()` edits [godot/scripts/tactical/board/board_state.gd:51]
- [x] [Review][Patch] Tactical snapshot serializable filtering allows non-finite floats that are not stable JSON save data [godot/scripts/save/snapshots/tactical_snapshot.gd:256]
- [x] [Review][Patch] Forbidden-reference filtering misses animation/VFX/presentation resource strings outside the narrow scene/UI/audio path checks [godot/scripts/save/snapshots/tactical_snapshot.gd:285]

## Dev Notes

### Current Repository Baseline

Story creation analysis on 2026-06-05 found a clean domain baseline:

- `git status --short` returned clean before this story file was created.
- Recent commits:
  - `6e11808 fix: complete story 1.4 review patches`
  - `b69e765 feat: implement named rng stream foundation`
  - `dcf393e feat: complete epic 1 tactical foundations`
  - `5b8de38 chore: checkpoint epic 1 story 1.1 baseline`
  - `016e0b5 chore: checkpoint Sealsworn planning and Godot foundation`
- Story 1.5 is the first backlog story in `sprint-status.yaml` and belongs to Sprint Slice 1: Domain Foundation.
- Existing board snapshots already cover dimensions, cells, entity state, HP, visibility fields, occupancy, and sequence id.
- Existing RNG snapshots already cover root seed, required named streams, stream seed/state, and draw index.
- There is no full `LevelState`, `TurnState`, movement command, attack command, fog service, telegraph system, or tactical snapshot DTO yet.

The developer should add the missing top-level tactical snapshot boundary around current board/RNG/domain data. Do not create movement, attack, fog, enemy AI, or save UI to make the test look more complete.

### Existing Files To Update Or Preserve

| Path | Current State | This Story Changes | Preserve |
|---|---|---|---|
| `godot/scripts/save/snapshots/tactical_snapshot.gd` | Does not exist. | Add a versioned tactical snapshot DTO with strict parse/export behavior. | Keep it data-only and scene-independent. It should not become authoritative gameplay state. |
| `godot/tests/unit/save/test_tactical_snapshot.gd` | Does not exist. | Add focused snapshot export/import, validation, no-mutation, and deterministic continuation tests. | Use existing `TestCase` style; no GUT/GdUnit dependency. |
| `godot/scripts/tactical/board/board_state.gd` | Domain board model with `to_snapshot()`, `try_from_snapshot()`, sorted cells/entities, staged event batch validation, and setup-only terrain/entity mutators. | Harden snapshot container validation and occupant consistency as needed for tactical snapshot imports. | Preserve scene independence, stable ordering, no-mutation validation posture, and existing command/event behavior. |
| `godot/scripts/tactical/board/board_cell.gd` | Cell DTO currently serializes position, terrain, occupant id, explored, and visible; `from_dictionary()` currently coerces malformed fields. | Add strict `try_from_dictionary()` and route compatibility wrapper through it. | Preserve cell field names and terrain enum values. Do not add presentation fields. |
| `godot/scripts/tactical/entities/tactical_entity_state.gd` | Entity DTO already has strict `try_from_dictionary()` for id, type, faction, position, HP, max HP, and movement blocking. | No expected change unless occupant validation exposes a narrow entity snapshot gap. | Preserve strict parse/no silent coercion, copy behavior, and supported entity types. |
| `godot/scripts/core/state/rng_stream_set.gd` | Named RNG stream set from Story 1.4 with strict `try_restore()`, snapshots, draw indexes, and audit metadata. | No expected change except narrow compatibility if tactical snapshot tests expose an issue. | Keep direct `RandomNumberGenerator` ownership here only. Do not add global RNG or gameplay stream policy elsewhere. |
| `godot/scripts/save/snapshots/run_snapshot.gd` | Versioned run snapshot DTO with `board`, `turn_state`, and `rng_streams` dictionaries. | Optional focused round-trip coverage only if tactical snapshot data is passed through existing fields. | Do not implement broader save/resume, migrations, repositories, or UI flows. |
| `godot/tests/unit/tactical/test_board_state.gd` | Board tests cover round-trip, invalid events, atomic batches, sorted snapshots, entities, terrain, occupancy, and corrupt entity snapshots. | Add strict cell/container/occupant consistency tests if they belong closer to board behavior than the tactical snapshot test. | Do not remove current assertions or weaken invalid/no-mutation checks. |
| `godot/tests/fixtures/tactical/board_fixture_factory.gd` | Provides reusable board fixtures including `deterministic_actor_placement()`. | Reuse for tactical snapshot tests. Add only small fixture helpers if they reduce duplication. | Do not duplicate board setup logic across test files. |
| `godot/tests/unit/core/test_create_board_command.gd` | Command tests use board snapshots for invalid/no-mutation assertions. | Add one top-level tactical snapshot no-mutation assertion around an invalid command. | Preserve existing board-level behavior assertions and command/event contract checks. |

### Deferred Work That Becomes In Scope

The prior review recorded deferred board snapshot issues. These are in scope only where they directly affect the tactical snapshot serialization boundary:

- Board cell parsing currently coerces malformed cell fields. Story 1.5 must add strict cell snapshot validation.
- `BoardState.try_from_snapshot()` currently lacks a `cells` container type guard before typed assignment. Story 1.5 must reject malformed containers cleanly.
- Occupant consistency is unresolved. Story 1.5 must make blocking entity snapshots and cell `occupant_id` fields agree so importing a snapshot cannot silently change its shape.
- Mutable `get_cell()` can still desynchronize `_cells` and `_entities`. Story 1.5 should make snapshot export validate board consistency before accepting it. A full read-only board API redesign is not required unless validation cannot otherwise be made safe.

### Story Scope Boundaries

Implement only the snapshot boundary needed by Story 1.5. Do not implement:

- `MoveCommand`, pathfinding, movement budgets, line of sight, fog reveal algorithms, tile memory updates, or visibility events.
- `AttackCommand`, weapon definitions, attack preview, damage, death, enemy turns, telegraph resolution, combat log, or victory state.
- Full `LevelState`, `RunState`, tactical UI, command bridge, presentation mappers, save UI, save slots, autosave, or between-level resume flow.
- Save repository migrations, profile/meta saves, cloud saves, accounts, multiplayer, leaderboards, telemetry, or platform sync.
- Godot .NET/C#, React/Vite production dependencies, or new third-party test libraries.

If turn state or pending telegraphs do not have domain classes yet, represent them as strictly validated serializable dictionaries/arrays in `TacticalSnapshot` with schema placeholders. Do not build their full gameplay systems in this story.

### Technical Requirements

- Production code stays under `godot/` and uses typed GDScript.
- Snapshot classes use `RefCounted`, not `Node`, because they are domain/save data.
- `TacticalSnapshot` schema 1 must include:
  - `schema_version: int`
  - `content_version: String`
  - `board: Dictionary`
  - `turn_state: Dictionary`
  - `pending_telegraphs: Array[Dictionary]`
  - `rng_streams: Dictionary`
  - `event_log: Array[Dictionary]`
- Snapshot parse errors must be structured `ActionResult.error()` values with stable lower-snake error codes and diagnostic metadata.
- Failed imports must stage validation before mutation. Do not partially activate a board, RNG stream set, event log, or turn data from an invalid snapshot.
- Use `BoardState.try_from_snapshot()` and `RngStreamSet.try_restore()` as validation gates; do not duplicate their internal validation in `TacticalSnapshot` except for top-level schema/container checks.
- Do not rely on dictionary iteration order for deterministic output. Use current board cell/entity sorting and `RngStreamSet.required_streams()`.
- Deep-copy all accepted snapshot dictionaries and arrays on input and output.
- Event log serialization must use `DomainEvent.to_dictionary()` and parse with `DomainEvent.try_from_dictionary()`.
- JSON round-trip tests should account for Godot JSON's numeric behavior. Where strict integer fields matter, test the parsed dictionary path used by production snapshot parsing, not only stringified JSON.

### Architecture Compliance

- The scene-independent domain model owns tactical truth. The tactical snapshot mirrors domain state for save/resume, replay, and no-mutation tests; it does not own gameplay decisions.
- Commands validate before mutation and return `ActionResult`; failed commands emit zero domain events.
- Successful command outcomes must remain deterministic past-tense `DomainEvent` records. This story should only serialize existing events, not invent new combat/movement events.
- Named RNG streams remain the only gameplay-affecting randomness source. Tactical snapshots store their states; they do not choose stream policy.
- Save truth is versioned domain snapshots only. Never serialize scene nodes, UI controls, audio, animation, or presentation node state.
- Headless tests must run without rendering, audio, UI scenes, presentation nodes, or scene-tree-only state.

### Library And Framework Requirements

- Required engine: Godot 4.6.3 stable standard build.
- Required language: typed GDScript.
- Use the existing custom headless runner and `TestCase` base. Do not add GUT, GdUnit, or another testing dependency.
- Use Godot `Dictionary.duplicate(true)` and `Array.duplicate(true)` where appropriate, while validating that nested data contains only serializable values accepted by this snapshot boundary.
- Use `JSON.stringify()`/`JSON.parse_string()` only in tests that explicitly validate JSON compatibility; production snapshot validation should operate on dictionaries and `ActionResult`.

### Latest Technical Information

Official Godot documentation checked on 2026-06-05:

- Godot static typing supports typed variables, constants, function parameters, and return values. Keep new code typed and consistent with current project style. [Source: Godot static typing docs](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/static_typing.html)
- Godot `JSON.parse_string()` returns `null` on parse failure and does not expose detailed parse errors; use `JSON.parse()` only if custom error handling is needed. [Source: Godot JSON docs](https://docs.godotengine.org/en/stable/classes/class_json.html)
- Godot `JSON.stringify()` defaults to sorted keys and converts numeric Variant values to JSON numbers; strict schema validation should still happen after parsing. [Source: Godot JSON docs](https://docs.godotengine.org/en/stable/classes/class_json.html)
- Godot arrays and dictionaries are reference types. `duplicate(true)` deep-copies nested arrays and dictionaries, but Resources/Objects are still reference data and must be rejected by the snapshot boundary. [Source: Godot Array docs](https://docs.godotengine.org/en/stable/classes/class_array.html)

### Previous Story Intelligence

Story 1.4 established the RNG contract this story must preserve:

- `RngStreamSet.to_snapshot()` includes root seed and every required stream's `seed`, `state`, and `draw_index`.
- `RngStreamSet.try_restore(snapshot)` validates before mutation and returns `invalid_rng_snapshot` on malformed input.
- Unknown streams, invalid ranges, and invalid consumer context return stable errors and leave RNG snapshots unchanged.
- Cosmetic draws must not affect gameplay stream snapshots or deterministic replay equality.

Story 1.3 established strict result/event behavior:

- `ActionResult.error()` normalizes invalid error codes and deep-copies metadata.
- `ActionResult.ok()` rejects non-`DomainEvent` values and deep-copies metadata.
- `DomainEvent.try_from_dictionary()` rejects malformed dictionaries rather than silently coercing invalid data.
- Invalid paths need no-mutation assertions against stable snapshots.

Story 1.2 established tactical board patterns:

- Board state is scene-independent and authoritative.
- `BoardState.to_snapshot()` exports cells in coordinate order and entities by stable id order.
- `BoardState.try_from_snapshot()` stages restore into a fresh board and returns `ActionResult`.
- `TacticalEntityState.try_from_dictionary()` is strict; cell parsing needs to match that posture in this story.

Story 1.1 established the production harness:

- Run tests with `godot --headless --path C:\Sealsworn\godot --scene res://tests/headless/test_runner.tscn --quit-after 10`.
- Keep the project independent from `prototype/`, cloud services, telemetry, accounts, multiplayer, and Godot .NET/C#.

### Git Intelligence

- Commit `6e11808` fixed Story 1.4 review patches in `game_session.gd`, `rng_stream_set.gd`, and RNG tests. That reinforces the rule that failed restores must not desync autoload/session state from domain state.
- Commit `b69e765` implemented the RNG stream foundation and added focused `RunSnapshot` RNG dictionary round-trip coverage. Use the same narrow-save-DTO approach here.
- Commit `dcf393e` completed the first tactical foundation stories. Current board/result/event tests are the baseline and should not be weakened.

### Project Structure Notes

- `godot/scripts/save/snapshots/` is the correct home for `TacticalSnapshot`.
- `godot/tests/unit/save/` is the correct home for tactical snapshot DTO tests.
- Board validation tests may stay in `godot/tests/unit/tactical/test_board_state.gd` if they are primarily board behavior.
- Reusable board fixtures stay under `godot/tests/fixtures/tactical/`.
- Do not add production code under `prototype/`.
- Root `project-context.md` is canonical. Do not create a duplicate under `_bmad-output/`.
- No standalone UX file exists; this story is a domain/save boundary and does not need UI artifact input.

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
- Existing Story 1.1, 1.2, 1.3, and 1.4 tests still pass.
- New tests cover tactical snapshot schema, strict parse failures, serializable-only export, deep-copy behavior, board/cell validation hardening, occupant consistency, RNG restore through the tactical boundary, event-log ordering, deterministic continuation, and invalid-command no-mutation snapshots.
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
- Commands validate before mutation and return `ActionResult`.
- Successful commands emit deterministic past-tense `DomainEvent` records.
- Use named RNG streams for gameplay-affecting randomness.
- Save versioned domain snapshots only; never serialize scene nodes as save truth.
- Headless simulation must not depend on rendering, audio, UI scenes, presentation nodes, or scene-tree-only state.
- Do not introduce cloud services, accounts, multiplayer, telemetry dependencies, or Godot .NET/C# unless the architecture is explicitly revised.
- Preserve user changes and unrelated dirty worktree files.

### References

- [Source: `_bmad-output/planning-artifacts/epics.md` - Story 1.5]
- [Source: `_bmad-output/implementation-artifacts/epic-1-sprint-plan-2026-06-04.md` - Sprint Slice 1]
- [Source: `_bmad-output/implementation-artifacts/1-4-named-rng-streams-for-deterministic-gameplay.md` - Previous Story Intelligence]
- [Source: `_bmad-output/implementation-artifacts/deferred-work.md` - Board snapshot deferred work now relevant to Story 1.5]
- [Source: `project-context.md` - Determinism, save, snapshot, and testing rules]
- [Source: `_bmad-output/game-architecture.md` - Core runtime architecture, RNG and determinism, data persistence, headless simulation, system locations]
- [Source: `_bmad-output/planning-artifacts/gdds/gdd-Game-2026-05-31/gdd.md` - Seed replay, fog memory, telegraphs, and save/resume requirements]
- [Source: Godot static typing docs](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/static_typing.html)
- [Source: Godot JSON docs](https://docs.godotengine.org/en/stable/classes/class_json.html)
- [Source: Godot Array docs](https://docs.godotengine.org/en/stable/classes/class_array.html)

## Dev Agent Record

### Agent Model Used

Codex GPT-5

### Debug Log References

- 2026-06-05: Created Story 1.5 implementation guide from Epic 1 source requirements, Sprint Slice 1, prior story records, deferred review work, root project context, game architecture, GDD requirements, current Godot code/tests, clean git baseline, recent commits, and official Godot technical references.
- 2026-06-05: Activated `gds-dev-story`, captured baseline commit `6e118089a2af49d073e3e875960735f3ff46f572`, and moved story tracking to `in-progress`.
- 2026-06-05: Added RED coverage for tactical snapshot schema/export validation, strict board/cell parsing, deterministic restore continuation, and invalid-command no-mutation snapshots. Initial headless run failed on missing `tactical_snapshot.gd`, as expected.
- 2026-06-05: Implemented `TacticalSnapshot`, strict `BoardCell.try_from_dictionary()`, and hardened `BoardState.try_from_snapshot()` cell/occupant validation.
- 2026-06-05: Headless suite passed after implementation before story record finalization.
- 2026-06-05: Final validation passed: `godot --version` reported `4.6.3.stable.official.7d41c59c4`; full headless runner passed; `git diff --check` exited cleanly with only CRLF conversion warnings.
- 2026-06-06: Applied code review patches for strict board sequence/entity containers, board storage consistency validation, content-version compatibility, non-finite float rejection, and broader resource-reference rejection.
- 2026-06-06: Post-review validation passed: `godot --version` reported `4.6.3.stable.official.7d41c59c4`; full headless runner passed; `git diff --check` exited cleanly with only CRLF conversion warnings.

### Implementation Plan

- Start with failing unit tests for `TacticalSnapshot`, then implement the DTO and strict validation.
- Harden board/cell snapshot validation only where needed for safe tactical snapshot import/export.
- Reuse existing board fixtures, `ActionResult`, `DomainEvent`, `BoardState`, and `RngStreamSet` contracts instead of inventing duplicate systems.

### Completion Notes List

- Added a scene-independent `TacticalSnapshot` save-layer DTO with schema 1, deep-copy export, strict parse validation, serializable-only data filtering, event-log canonicalization, board validation, and RNG validation.
- Hardened board snapshot import by adding strict `BoardCell.try_from_dictionary()`, rejecting malformed `cells` containers before typed assignment, and enforcing snapshot occupant consistency for blocking and non-blocking entities.
- Added headless tests for tactical snapshot JSON-compatible export, invalid schema/container/event/RNG cases, desynchronized board export rejection, restore/continue determinism, gameplay RNG continuation, and invalid-command no-mutation snapshots.
- Updated the existing invalid `CreateBoardCommand` test to compare top-level tactical snapshots while preserving prior board-specific assertions.
- Applied code review patches for schema compatibility and malformed board/source-state rejection without widening the story into save repository, UI, or gameplay command work.
- Kept save/autoload boundaries narrow: no `SaveRepository`, `SaveManager`, `GameSession`, UI, scene, migration, cloud, telemetry, multiplayer, or prototype dependency changes.

### File List

- `_bmad-output/implementation-artifacts/1-5-tactical-snapshot-serialization-boundary.md`
- `_bmad-output/implementation-artifacts/sprint-status.yaml`
- `godot/scripts/save/snapshots/tactical_snapshot.gd`
- `godot/scripts/tactical/board/board_cell.gd`
- `godot/scripts/tactical/board/board_state.gd`
- `godot/tests/unit/save/test_tactical_snapshot.gd`
- `godot/tests/unit/tactical/test_board_state.gd`
- `godot/tests/unit/core/test_create_board_command.gd`

## Change Log

- 2026-06-05: Created Story 1.5 implementation guide and marked it ready for development.
- 2026-06-05: Implemented tactical snapshot serialization boundary, strict board/cell snapshot validation, deterministic restore tests, and invalid-command no-mutation snapshot coverage; story marked ready for review.
- 2026-06-06: Resolved code review patch findings with stricter board/tactical snapshot validation and regression coverage.
