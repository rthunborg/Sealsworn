---
baseline_commit: 5b8de38478e8c1bdb72978b429ba0cb3b3b41281
---

# Story 1.3: ActionResult and Domain Event Foundation

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a developer,  
I want commands to return structured results and deterministic domain events,  
so that gameplay outcomes can drive tests, logs, saves, replay, and presentation without hidden side effects.

## Acceptance Criteria

1. Given a command succeeds, when it executes against valid domain state, then it returns an `ActionResult` marked successful, and the result includes an ordered list of past-tense `DomainEvent` records.
2. Given a command is invalid, when it fails validation, then it returns an `ActionResult` with a stable error code and no events, and the target domain state remains unchanged by snapshot or state-hash comparison.
3. Given an `ActionResult` contains a success or failure reason, when tests inspect it, then the reason is machine-testable and stable, and player-facing display text can be derived separately without changing command contracts.
4. Given a domain event is emitted, when it is serialized for tests or logs, then it includes deterministic fields needed to understand what happened, and event names use past-tense naming such as `EntityMovedEvent` or `DamageAppliedEvent`.
5. Given events are applied to domain state, when a test replays the same ordered events from the same initial state, then the resulting state matches the original command result.

## Tasks / Subtasks

- [x] 1.3.1 Expand `ActionResult` contract coverage before changing implementation. (AC: 1, 2, 3)
  - [x] Add tests proving success results preserve event order, expose no error code, and deep-copy metadata so callers cannot mutate result context after creation.
  - [x] Add tests proving error results always expose a non-empty stable `StringName` error code, contain no events, and keep diagnostic metadata separate from player-facing text.
  - [x] Add tests proving `ActionResult.ok()` rejects non-`DomainEvent` values without retaining partial event data.
  - [x] Preserve existing callers in save, platform, RNG, board, entity, and command code that use `metadata` for domain objects or values.
- [x] 1.3.2 Harden `DomainEvent` serialization and parsing. (AC: 1, 4)
  - [x] Add `DomainEvent` tests for deterministic dictionary output: stable `event_id`, positive `sequence_id`, stable `actor_id`, and deep-copied payload.
  - [x] Add a validated parse path such as `try_from_dictionary()` returning `ActionResult`; keep `from_dictionary()` as a compatibility wrapper if it remains useful.
  - [x] Reject malformed event dictionaries with stable error codes instead of silently coercing invalid sequence ids, actor ids, or non-dictionary payloads into valid-looking events.
  - [x] Preserve existing `board_created` event behavior and current stable ids; do not serialize raw enum integers as save/log truth.
- [x] 1.3.3 Add command replay and no-mutation contract tests using existing board creation. (AC: 1, 2, 5)
  - [x] Use `CreateBoardCommand` as the first concrete command contract fixture.
  - [x] For a valid board-create command, compare the board snapshot after command execution with a fresh board that applies the returned ordered event list.
  - [x] For invalid create-board cases, compare snapshots before and after execution and assert no events are returned.
  - [x] Add or preserve batch event atomicity tests so failed ordered event application leaves board state unchanged.
- [x] 1.3.4 Make event naming and reason-code rules explicit in tests. (AC: 3, 4)
  - [x] Keep event identifiers stable and past-tense. Current `board_created` is valid; future movement and damage stories should add `entity_moved` and `damage_applied` style ids when they implement those behaviors.
  - [x] Keep `ActionResult` reasons machine-testable through stable codes such as `invalid_board_size`, `board_already_created`, `event_sequence_mismatch`, and `unsupported_board_event`.
  - [x] Do not put localized or player-facing prose into `ActionResult.error_code` or event ids.
  - [x] If display strings are needed for tests, derive them from a separate mapping or metadata field without changing command contracts.
- [x] 1.3.5 Preserve current architecture boundaries while tightening foundation code. (AC: 1, 2, 4, 5)
  - [x] Keep `ActionResult`, `DomainEvent`, and command base scripts under `godot/scripts/core/`.
  - [x] Keep authoritative replay/application logic in domain state, currently `BoardState.apply_event()` / `apply_events()`, not in scenes, autoloads, UI, or presentation nodes.
  - [x] Do not introduce an event bus, UI signal control flow, save-file event log, rules kernel, movement, attack, damage, RNG stream changes, or scene dependencies in this story.
  - [x] Run the full headless suite and record results in the Dev Agent Record before moving the story to review.

### Review Findings

- [x] [Review][Patch] `DomainEvent.try_from_dictionary()` exposes `Variant` instead of the required `ActionResult` contract [godot/scripts/core/events/domain_event.gd:59]
- [x] [Review][Patch] JSON-round-tripped event sequence IDs can be rejected because the parser accepts only `TYPE_INT` [godot/scripts/core/events/domain_event.gd:77]
- [x] [Review][Patch] `board_created` replay can coerce malformed payload dimensions instead of rejecting them deterministically [godot/scripts/tactical/board/board_state.gd:301]
- [x] [Review][Defer] Board snapshot cell parsing still coerces malformed cell fields and lacks a `cells` container type guard [godot/scripts/tactical/board/board_state.gd:176] — deferred, pre-existing
- [x] [Review][Defer] Board entity snapshot restore has unresolved occupant-schema migration and consistency behavior [godot/scripts/tactical/board/board_state.gd:225] — deferred, pre-existing
- [x] [Review][Defer] Mutable `get_cell()` access can bypass new entity occupancy invariants [godot/scripts/tactical/board/board_state.gd:36] — deferred, pre-existing

## Dev Notes

### Current Repository Baseline

Story creation analysis on 2026-06-04 found a passing Godot/domain baseline:

- `godot --version` returned `4.6.3.stable.official.7d41c59c4`.
- `godot --headless --path C:\Sealsworn\godot --scene res://tests/headless/test_runner.tscn --quit-after 10` passed.
- Passing tests included core result/event/RNG/command tests, save tests, project setup tests, integration domain-loading tests, and Story 1.2 tactical board/entity/fixture tests.
- Recent commit history:
  - `5b8de38 chore: checkpoint epic 1 story 1.1 baseline`
  - `016e0b5 chore: checkpoint Sealsworn planning and Godot foundation`
  - `e0e8060 Add Sealsworn architecture and agent context`
  - `7a3e1a3 Initial Sealsworn project`
- `git status --short` was dirty before this story was created because Story 1.2 artifacts and tactical code were present as uncommitted/untracked work. Preserve that work; do not revert, clean, or re-stage unrelated files while implementing Story 1.3.

### Existing Files To Update Or Preserve

| Path | Current State | This Story Changes | Preserve |
|---|---|---|---|
| `godot/scripts/core/results/action_result.gd` | Scene-independent `RefCounted` result with `succeeded`, `error_code`, ordered typed `events`, metadata, `ok()`, `error()`, `is_error()`, and `has_events()`. | Tighten the contract with tests and any small helpers needed for stable machine-testable reasons, event validation, metadata copying, and deterministic inspection. | Do not add player-facing text as the contract. Do not break save/RNG/entity callers that use metadata for returned values. |
| `godot/scripts/core/events/domain_event.gd` | Scene-independent `RefCounted` event shell with enum types, stable event ids, sequence id, actor id, payload, `board_created()`, dictionary serialization, and coercive `from_dictionary()`. | Add validated parsing/serialization coverage, payload copy guarantees, malformed dictionary rejection, and stable event-id naming guidance. | Keep stable ids such as `board_created`. Do not serialize enum integers as durable truth. Do not pre-implement movement, attack, or damage events. |
| `godot/scripts/core/commands/game_command.gd` | Minimal command base returning `ActionResult.error("not_implemented")` from `validate()` and `execute()`. | No expected broad change. Update only if tests need a clearer command contract helper. | Keep commands as `RefCounted` domain objects. Do not make commands depend on scenes, autoload gameplay decisions, UI, audio, or rendering. |
| `godot/scripts/core/commands/create_board_command.gd` | First concrete command. Validates board state and dimensions, emits `DomainEvent.board_created()`, applies events to `BoardState`, and returns `ActionResult.ok([event])`. | Use as the replay/no-mutation command fixture. Adjust only for tightened `ActionResult` or `DomainEvent` contracts. | Preserve validate-before-mutate behavior and existing error codes: `invalid_state_type`, `invalid_board_size`, `board_already_created`. |
| `godot/scripts/tactical/board/board_state.gd` | Applies `BOARD_CREATED`, stages batch event validation on a copy, tracks sequence ids, serializes board/entity state, and rejects unsupported board events. | Add replay/no-mutation tests. Modify only if tightened event parsing or atomicity tests expose a contract gap. | Preserve Story 1.2 board/entity behavior, sorted snapshots, setup-only helpers, and batch atomicity. |
| `godot/tests/unit/core/test_action_result.gd` | Basic success/error/event validation tests. | Expand into full `ActionResult` contract coverage. | Keep addon-free `TestCase` style and `run() -> Dictionary`. |
| `godot/tests/unit/core/test_domain_event.gd` | Basic stable event-id serialization tests. | Expand to validated parsing, deterministic payload copying, malformed event rejection, and naming contract coverage. | Keep tests headless and domain-only. |
| `godot/tests/unit/core/test_create_board_command.gd` | Valid create, invalid no-mutation, and duplicate create tests. | Add command replay parity and stronger snapshot/no-mutation assertions. | Keep CreateBoardCommand as the only concrete command fixture for this story. |
| `godot/tests/unit/tactical/test_board_state.gd` | Includes board event sequence mismatch and batch atomicity coverage plus Story 1.2 board/entity tests. | Preserve and extend only if replay/atomicity coverage belongs better here than in core command tests. | Do not weaken Story 1.2 tests. |
| `godot/scripts/save/snapshots/run_snapshot.gd`, `godot/scripts/save/save_repository.gd`, `godot/scripts/core/state/rng_stream_set.gd`, `godot/scripts/platform/platform_services.gd` | Existing callers use `ActionResult` for parsing, persistence, RNG values, and local/no-op platform services. | No expected feature work. Run tests after any `ActionResult` change to catch compatibility breaks. | Preserve current result metadata behavior and stable error codes. |

### Story Scope Boundaries

This story is foundation hardening for command results and domain events only. Do not implement:

- `MoveCommand`, movement validation, pathfinding, or line of sight.
- Weapon definitions, attack previews, `AttackCommand`, damage events, enemy AI, death/victory, explanation logs, or rules kernel behavior.
- Named RNG stream changes beyond preserving existing `RngStreamSet` tests.
- Save migration/event-log persistence beyond deterministic event dictionaries needed for tests/logs.
- UI scenes, command bridge, presenters, audio, VFX, animation, or Godot signals for domain control flow.
- A broad event-bus or per-event subclass hierarchy unless a small local change is clearly necessary to satisfy the ACs. The existing single `DomainEvent` shell with stable ids is the established baseline.

Invalid commands must return errors with no events. The existing `COMMAND_REJECTED` event id may remain reserved for future diagnostics, but this story must not attach rejection events to invalid command `ActionResult`s unless the architecture is explicitly revised.

### Technical Requirements

- Production code stays under `godot/`.
- Use typed GDScript and `RefCounted` for result, event, and command domain objects.
- Keep all command/result/event tests runnable through the existing custom headless runner; do not add GUT, GdUnit, or another dependency.
- Stable machine contracts use `StringName`/string ids, not localized prose, enum integers, Node paths, ObjectIDs, or scene references.
- Event dictionaries must contain serializable domain data only: stable event id, sequence id, actor id, and JSON-compatible payload data.
- Preserve event order through arrays. Do not rely on dictionary iteration order for gameplay or replay.
- Use deep copies for metadata/payload dictionaries where caller mutation would otherwise corrupt result/event records.
- For invalid command and invalid event-application paths, compare snapshots or deterministic hashes before and after execution.

### Architecture Compliance

- Scene-independent domain model owns tactical truth.
- Gameplay actions validate before mutation and return `ActionResult`.
- Successful commands emit deterministic past-tense `DomainEvent` records.
- Events are the bridge to presentation, logs, saves, replay, tests, and future analytics; presentation remains a consumer, not the owner of gameplay state.
- Godot scenes, UI, audio, VFX, and animation must not own or mutate command/event truth.
- Headless simulation must remain independent of rendering, audio, UI scenes, presentation nodes, and scene-tree-only state.
- Save truth is versioned domain snapshots only; this story may support event serialization for logs/tests, but must not replace snapshot save truth with scene data or ad hoc event persistence.

### Library And Framework Requirements

- Required engine: Godot 4.6.3 stable standard build.
- Required language: typed GDScript.
- Use the existing custom headless test runner and `TestCase` base.
- Use Godot `RefCounted` and serializable Variant data for lightweight domain records.
- Do not use Godot .NET/C#, React/Vite prototype code, cloud services, accounts, multiplayer, telemetry, leaderboards, live-service dependencies, or external test frameworks.

### Latest Technical Information

Official Godot sources checked on 2026-06-04:

- Godot's archive lists `4.6.3-stable` dated 2026-05-20. Continue using 4.6.3 unless the architecture is intentionally revised. [Source: Godot archive](https://godotengine.org/download/archive/)
- Godot 4.6 command-line docs support `--path <directory>`, `--scene <path>`, `--headless`, and `--quit-after`, matching the current headless suite command. [Source: Godot 4.6 command line tutorial](https://docs.godotengine.org/en/4.6/tutorials/editor/command_line_tutorial.html)
- Godot 4.6 `JSON.stringify()` accepts Variant data and defaults `sort_keys` to `true`, which is useful for deterministic test/log strings after event dictionaries are already ordered where order matters. [Source: Godot 4.6 JSON docs](https://docs.godotengine.org/en/4.6/classes/class_json.html)
- Godot 4.6 static typing docs support `class_name` custom classes and typed variables/functions, matching the current domain script style. [Source: Godot 4.6 static typing docs](https://docs.godotengine.org/en/4.6/tutorials/scripting/gdscript/static_typing.html)
- Godot 4.6 docs describe `RefCounted` as reference-counted object support. Keep domain result/event records lightweight and non-Node. [Source: Godot 4.6 RefCounted docs](https://docs.godotengine.org/en/4.6/classes/class_refcounted.html)

### Previous Story Intelligence

Story 1.2 completed the tactical board/entity foundation that this story must preserve:

- `BoardState` now stores deterministic cells and entities, exposes occupancy queries, setup-only terrain/entity helpers, and snapshots board dimensions, visibility/explored state, terrain, occupants, entities, and next sequence id.
- `TacticalEntityState` is a typed `RefCounted` domain object with strict dictionary parsing, validation, copy support, alive/dead queries, and stable entity ids.
- Reusable tactical fixtures exist under `godot/tests/fixtures/tactical/board_fixture_factory.gd`.
- Story 1.2 review patches tightened snapshot restore, strict entity parsing, terrain validation, and wall-over-entity setup. Story 1.3 should follow that same strict-parse/no-silent-coercion posture for `DomainEvent`.
- The existing headless runner discovers `test_*.gd` under `res://tests/unit` and `res://tests/integration`; tests extend `res://tests/unit/test_case.gd` and return `result()`.

Story 1.1 established the Godot skeleton and test harness:

- Keep the production project in `godot/` and independent of `prototype/`.
- Keep tests addon-free unless project policy changes.
- Record final verification commands in the Dev Agent Record.

### Git Intelligence

Recent commits show checkpoint-based project progress rather than a clean committed Story 1.2 baseline. Implement against the current working tree, but preserve unrelated dirty files:

- `5b8de38` is the Story 1.1 checkpoint baseline.
- `016e0b5` is the planning and Godot foundation checkpoint.
- Story 1.2 files are currently dirty/untracked and should be treated as the active baseline because sprint status marks Story 1.2 done.

### Project Structure Notes

- `godot/scripts/core/results/` is the correct home for `ActionResult`.
- `godot/scripts/core/events/` is the correct home for `DomainEvent`.
- `godot/scripts/core/commands/` is the correct home for command base classes and `CreateBoardCommand`.
- Command/event replay state lives in domain model scripts such as `godot/scripts/tactical/board/board_state.gd`.
- Core tests belong under `godot/tests/unit/core/`; board replay details may also use `godot/tests/unit/tactical/` if they exercise board-specific event application.
- No standalone UX file was discovered in planning artifacts. UX is non-blocking for this domain-first story.

### Testing Requirements

Run at minimum:

```powershell
godot --version
godot --headless --path C:\Sealsworn\godot --scene res://tests/headless/test_runner.tscn --quit-after 10
```

Expected final result:

- Godot version is `4.6.3.stable.official...` or otherwise explicitly compatible with project policy.
- Headless runner exits with code `0`.
- Existing Story 1.1 and Story 1.2 tests still pass.
- New Story 1.3 tests cover `ActionResult` success/error invariants, stable reason codes, metadata/event payload copy behavior, invalid event rejection, deterministic event serialization, command success replay parity, and invalid command no-mutation.
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

- [Source: `_bmad-output/planning-artifacts/epics.md` - Story 1.3]
- [Source: `_bmad-output/implementation-artifacts/epic-1-sprint-plan-2026-06-04.md` - Sprint Slice 1]
- [Source: `_bmad-output/implementation-artifacts/1-2-tactical-domain-state-and-board-model.md` - Previous Story Intelligence]
- [Source: `project-context.md` - Critical Implementation Rules, Determinism & Simulation Rules, Testing Rules]
- [Source: `_bmad-output/game-architecture.md` - Command/Event Simulation Pattern, Event System, Error Handling, Consistency Rules]
- [Source: `_bmad-output/planning-artifacts/gdds/gdd-Game-2026-05-31/gdd.md` - Core Turn Rules and Technical Specifications]
- [Source: Godot archive - 4.6.3 stable](https://godotengine.org/download/archive/)
- [Source: Godot 4.6 command line tutorial](https://docs.godotengine.org/en/4.6/tutorials/editor/command_line_tutorial.html)
- [Source: Godot 4.6 JSON docs](https://docs.godotengine.org/en/4.6/classes/class_json.html)
- [Source: Godot 4.6 static typing docs](https://docs.godotengine.org/en/4.6/tutorials/scripting/gdscript/static_typing.html)
- [Source: Godot 4.6 RefCounted docs](https://docs.godotengine.org/en/4.6/classes/class_refcounted.html)

## Dev Agent Record

### Agent Model Used

Codex GPT-5

### Debug Log References

- 2026-06-05: Red test run for 1.3.1: `godot --headless --path C:\Sealsworn\godot --scene res://tests/headless/test_runner.tscn --quit-after 10` failed as expected on empty `ActionResult.error()` code.
- 2026-06-05: Green test run for 1.3.1: `godot --headless --path C:\Sealsworn\godot --scene res://tests/headless/test_runner.tscn --quit-after 10` passed.
- 2026-06-05: Red test run for 1.3.2: `godot --headless --path C:\Sealsworn\godot --scene res://tests/headless/test_runner.tscn --quit-after 10` exposed missing `DomainEvent.try_from_dictionary()` parser.
- 2026-06-05: Green test run for 1.3.2: `godot --headless --path C:\Sealsworn\godot --scene res://tests/headless/test_runner.tscn --quit-after 10` passed.
- 2026-06-05: Contract coverage run for 1.3.3: `godot --headless --path C:\Sealsworn\godot --scene res://tests/headless/test_runner.tscn --quit-after 10` passed; existing command/board implementation satisfied replay and no-mutation assertions.
- 2026-06-05: Red test run for 1.3.4: `godot --headless --path C:\Sealsworn\godot --scene res://tests/headless/test_runner.tscn --quit-after 10` failed as expected on player-facing prose being accepted as an `ActionResult.error_code`.
- 2026-06-05: Green test run for 1.3.4: `godot --headless --path C:\Sealsworn\godot --scene res://tests/headless/test_runner.tscn --quit-after 10` passed.
- 2026-06-05: Boundary scan for 1.3.5: `rg "extends Node|extends Control|signal |emit_signal|EventBus|event_bus|autoload|res://scenes|res://scripts/ui" godot\scripts\core godot\scripts\tactical godot\tests\unit\core godot\tests\unit\tactical` found no new domain scene/UI/event-bus coupling; hits were existing project-structure documentation tests only.
- 2026-06-05: Project context scan for 1.3.5: `rg --files -g project-context.md` returned only root `project-context.md`.
- 2026-06-05: Final version check: `godot --version` returned `4.6.3.stable.official.7d41c59c4`.
- 2026-06-05: Final full headless suite: `godot --headless --path C:\Sealsworn\godot --scene res://tests/headless/test_runner.tscn --quit-after 10` passed.
- 2026-06-05: Completion gate recheck after review status update: no unchecked story task boxes, `git diff --check` exited 0, and `godot --headless --path C:\Sealsworn\godot --scene res://tests/headless/test_runner.tscn --quit-after 10` passed.
- 2026-06-05: Review patch verification: `godot --version` returned `4.6.3.stable.official.7d41c59c4`, `git diff --check` exited 0, and `godot --headless --path C:\Sealsworn\godot --scene res://tests/headless/test_runner.tscn --quit-after 10` passed.

### Implementation Plan

- 1.3.1: Added contract-first tests for `ActionResult` success ordering, stable machine error codes, metadata copying, and invalid event rejection; tightened only empty error-code normalization.
- 1.3.2: Added validated `DomainEvent.try_from_dictionary()` parsing with stable malformed-data error codes while keeping `from_dictionary()` as an unknown-event compatibility wrapper.
- 1.3.3: Added replay parity and invalid/no-mutation tests around `CreateBoardCommand`; no production command changes were required.
- 1.3.4: Locked event ids and reason codes as lower-snake machine contracts, including rejection of player-facing prose in `ActionResult.error_code`.
- 1.3.5: Verified the work stayed under core/domain boundaries, avoided event-bus/UI/save-log/rules/movement/attack scope, and passed the required final headless suite.

### Completion Notes List

- Story context created on 2026-06-04 from Epic 1 source requirements, the Epic 1 sprint plan, prior Story 1.2, root project context, game architecture, GDD tactical requirements, current Godot code, passing baseline tests, and current Godot 4.6 documentation.
- Developer guidance intentionally scopes Story 1.3 to result/event contracts, command replay, serialization validation, and invalid/no-mutation guarantees, excluding movement, attack, RNG stream expansion, rules, UI, and save persistence work.
- Completed 1.3.1 by expanding `ActionResult` tests and normalizing blank error codes to stable `invalid_error_code` while preserving deep-copied metadata behavior for existing callers.
- Completed 1.3.2 by hardening deterministic event dictionaries, payload copy guarantees, validated event parsing, malformed event rejection, and stable `board_created` id behavior.
- Completed 1.3.3 by proving valid `CreateBoardCommand` events replay to the same board snapshot and invalid command/batch paths return no events without mutation.
- Completed 1.3.4 by adding event-id and reason-code tests plus `ActionResult.error()` validation that preserves stable machine codes and rejects prose-style codes.
- Completed 1.3.5 by preserving architecture boundaries and validating the full headless suite on Godot 4.6.3.
- Addressed review findings by typing `DomainEvent.try_from_dictionary()` as `ActionResult`, accepting JSON round-tripped integral numeric event fields, and rejecting malformed `board_created` payload dimensions before replay mutation.

### File List

- `_bmad-output/implementation-artifacts/1-3-actionresult-and-domain-event-foundation.md`
- `_bmad-output/implementation-artifacts/sprint-status.yaml`
- `godot/scripts/core/results/action_result.gd`
- `godot/scripts/core/events/domain_event.gd`
- `godot/tests/unit/core/test_action_result.gd`
- `godot/tests/unit/core/test_create_board_command.gd`
- `godot/tests/unit/core/test_domain_event.gd`
- `godot/tests/unit/tactical/test_board_state.gd`

## Change Log

- 2026-06-04: Created Story 1.3 implementation guide and marked it ready for development.
- 2026-06-05: Completed 1.3.1 `ActionResult` contract hardening with passing headless tests.
- 2026-06-05: Completed 1.3.2 `DomainEvent` serialization and validated parse hardening with passing headless tests.
- 2026-06-05: Completed 1.3.3 command replay/no-mutation coverage with passing headless tests.
- 2026-06-05: Completed 1.3.4 event-id and reason-code contract hardening with passing headless tests.
- 2026-06-05: Completed 1.3.5 boundary validation and moved Story 1.3 to review with passing final headless suite.
- 2026-06-05: Addressed Story 1.3 code review findings and moved Story 1.3 to done.
