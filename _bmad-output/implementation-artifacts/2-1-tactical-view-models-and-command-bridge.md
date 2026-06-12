---
baseline_commit: 9ce024d9ca2db206856a226c02e29b12a737b47b
created: 2026-06-07
source_story_key: 2-1-tactical-view-models-and-command-bridge
---

# Story 2.1: Tactical View Models and Command Bridge

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a player,
I want UI interactions to reflect tactical state without directly changing it,
so that previews and commands remain reliable across phone, tablet, and desktop layouts.

## Acceptance Criteria

1. Given the tactical domain state from Epic 1 exists, when a board view model is built, then it exposes read-only cell, occupant, visibility, selected entity, preview, and action availability data, and it does not expose mutable domain internals to UI presenters.
2. Given a player selects a move or attack from UI, when the command bridge converts that intent, then it creates a typed domain command, and only the command execution path can mutate tactical state.
3. Given the command bridge receives an invalid UI intent, when it attempts conversion, then it returns a stable error or disabled action state, and no domain command is executed.
4. Given inspect or selection-only UI intent is received, when the bridge or view-model layer handles it, then selection/inspect-facing data is returned without submitting a gameplay command or advancing the turn.
5. Given returned view-model data is modified by a test or presenter, when the tactical domain state is inspected afterward, then board cells, entities, turn state, RNG streams, pending telegraphs, outcome state, and event log remain unchanged.

## Tasks / Subtasks

- [x] 2.1.1 Confirm Epic 1 closeout baseline and add failing tests first. (AC: 1-5)
  - [x] Verify current `sprint-status.yaml` still has `epic-1: done`, Story 1.10 done, Story 1.11 done, and this story at `ready-for-dev` before implementation starts.
  - [x] Add `godot/tests/unit/ui/test_tactical_board_view_model.gd` for read-only cell/occupant/visibility/selection/preview/action-availability data.
  - [x] Add `godot/tests/unit/ui/test_tactical_command_bridge.gd` for move, attack, inspect, unsupported intent, invalid actor, invalid target, wrong phase, and no-mutation conversion cases.
  - [x] Use `BoardFixtureFactory.micro_combat_board()` and focused movement/attack fixtures instead of inventing new board setup unless a new fixture clearly reduces duplication.
  - [x] Capture pre-action snapshots with `TacticalSnapshot.from_domain()` or equivalent dictionary copies before each no-mutation assertion.
- [x] 2.1.2 Implement tactical view-model value contracts. (AC: 1, 5)
  - [x] Add `godot/scripts/ui/view_models/tactical_board_view_model.gd` as the main UI-facing board contract.
  - [x] Add narrow value helpers if useful: `tactical_cell_view.gd`, `tactical_occupant_view.gd`, `tactical_selection_state.gd`, and `tactical_action_availability.gd`.
  - [x] Keep new view-model/helper scripts as typed `RefCounted` domain-facing UI helpers, not `Node`, `Control`, scene scripts, autoloads, or `Resource` content definitions.
  - [x] Expose value data only: `StringName`, `String`, `int`, `bool`, `Vector2i`, `Array`, and `Dictionary` copies. Do not expose `BoardState`, `BoardCell`, `TacticalEntityState`, `DomainEvent`, `TacticalActionContext`, `Node`, `Control`, or mutable content repository internals to presenters.
  - [x] Include stable `to_dictionary()` or equivalent copy methods that duplicate arrays/dictionaries deeply enough that presenter edits cannot mutate source domain objects.
  - [x] Sort cells row-major and occupants by stable id so presenter output and tests are deterministic.
- [x] 2.1.3 Build the board view model from existing Epic 1 domain services. (AC: 1, 4, 5)
  - [x] Build from explicit inputs such as `BoardState`, `TacticalTurnState`, optional `CombatOutcomeState`, current selection state, optional preview metadata, and optional event-log summary.
  - [x] Use `TacticalVisibilityQuery.visible_facts_for_cell()` or the same visibility rules for hidden, memory, and visible cells.
  - [x] For hidden cells, expose position plus `visibility_state: "hidden"` only. Do not leak terrain, occupant, HP, faction, telegraph, or reward facts.
  - [x] For explored memory cells, expose non-authoritative terrain/memory data only. Do not expose current occupant or current HP from memory cells.
  - [x] For visible cells, expose current occupant summary with id, entity type, faction, position, HP, max HP, alive/dead state, movement blocking, and definition id.
  - [x] Provide selected cell/entity fields without mutating board state. Selection is UI-facing state and must be replaceable by later layout/commit stories.
  - [x] Provide a stable preview slot, even if detailed movement/attack preview DTOs remain minimal until Story 2.2. This story should not implement full preview presentation formatting beyond what is needed to carry existing query metadata safely.
  - [x] Provide action availability fields for move, attack, inspect, confirm, and cancel with stable disabled reasons. Story 2.3 owns full two-step commit behavior.
- [x] 2.1.4 Implement the command bridge as a presentation boundary. (AC: 2, 3, 4)
  - [x] Add `godot/scripts/ui/command_bridge/tactical_command_bridge.gd`.
  - [x] Add `godot/scripts/ui/command_bridge/command_bridge_result.gd` only if `ActionResult` is not a clean fit for returning a command object plus disabled state. If a new result type is added, keep it small and use stable lower-snake error codes.
  - [x] Support at minimum `move`, `attack`, and `inspect` intent ids.
  - [x] Convert valid move intent into `MoveCommand` using explicit `actor_id`, `target_cell`, and optional `movement_budget`.
  - [x] Convert valid attack intent into `AttackCommand` using explicit `actor_id`, `target_cell`, `WeaponDefinition`, and optional attacker/defender `SupportDefinition` values. Do not invent equipment state in this story.
  - [x] For inspect intent, return selection/inspect metadata and no gameplay command. Full inspect panel content belongs to Story 2.4.
  - [x] Validate command availability by calling existing command/query validation before execution. Conversion and validation must not call `execute()`, apply events, consume RNG, advance turns, or mutate board state.
  - [x] If an `execute_intent()` helper is added, it must delegate to the typed command's `execute(context)` method after conversion. The bridge itself must not mutate `BoardState`, `TacticalTurnState`, RNG streams, pending telegraphs, outcome state, or event logs directly.
  - [x] Return stable errors or disabled states for missing target cell, malformed cell payload, missing actor, unsupported intent id, invalid context, invalid weapon, invalid support, wrong turn phase, dead actor, not visible, occupied, blocked, out of range, and blocked line where applicable.
- [x] 2.1.5 Prove no mutable domain internals leak to presenters. (AC: 1, 5)
  - [x] Tests must fail if any view model exposes raw `BoardCell` or `TacticalEntityState` references.
  - [x] Tests must mutate returned view-model dictionaries/arrays and prove the source `BoardState` snapshot is unchanged.
  - [x] Tests must prove command conversion for valid move/attack intent leaves the domain snapshot unchanged until the returned command is executed.
  - [x] Tests must prove invalid and inspect intent paths return no executable gameplay command and preserve board, turn state, RNG stream snapshots, pending telegraphs, outcome state, and event log.
  - [x] Tests must prove executing a valid returned `MoveCommand` or `AttackCommand` mutates only through the existing command/event path and returns the expected `ActionResult` events/metadata.
- [x] 2.1.6 Add integration handoff coverage for later Epic 2 stories. (AC: 1-5)
  - [x] Add a small UI-domain integration test, if unit tests become too fragmented, that builds a view model for the Epic 1 micro-combat board and exercises move, attack, and inspect intents headlessly.
  - [x] Record current stable view-model dictionary keys in tests so Story 2.2 can add detailed preview DTOs without breaking the base boundary.
  - [x] Do not add tactical HUD scenes, touch input scenes, layout profiles, zoom coordinate mapping, audio cues, VFX, animation, production art, settings UI, save/resume UI, or accessibility audit UI in this story.
- [x] 2.1.7 Run validation and update story records. (AC: 1-5)
  - [x] Run `godot --version`.
  - [x] Run `godot --headless --path C:\Sealsworn\godot --scene res://tests/headless/test_runner.tscn --quit-after 10`.
  - [x] Run `git diff --check`.
  - [x] Update this story's Dev Agent Record, Completion Notes, File List, and Change Log with actual implementation work.
  - [x] Keep `sprint-status.yaml` synchronized with this story status.

### Review Findings

- [x] [Review][Patch] Sanitize presenter-facing option metadata [godot/scripts/ui/view_models/tactical_board_view_model.gd]
- [x] [Review][Patch] Normalize supplied action availability so move, attack, inspect, confirm, and cancel remain stable [godot/scripts/ui/view_models/tactical_board_view_model.gd]
- [x] [Review][Patch] Treat valid inspect execution as metadata-only success instead of an error [godot/scripts/ui/command_bridge/tactical_command_bridge.gd]
- [x] [Review][Patch] Return stable disabled results for malformed intent payloads and partial command contexts [godot/scripts/ui/command_bridge/tactical_command_bridge.gd]
- [x] [Review][Patch] Avoid forwarding movement path, attack line, blocker, or raw validation metadata to presenters [godot/scripts/ui/command_bridge/tactical_command_bridge.gd]
- [x] [Review][Patch] Keep occupant summaries tied to visible occupant facts instead of loose entity position scans [godot/scripts/ui/view_models/tactical_board_view_model.gd]
- [x] [Review][Patch] Accept StringName-keyed UI option and coordinate dictionaries consistently [godot/scripts/ui/view_models/tactical_cell_view.gd]
- [x] [Review][Patch] Add missing invalid/no-mutation regression coverage for UI bridge boundaries [godot/tests/unit/ui/test_tactical_command_bridge.gd]

## Dev Notes

### Pre-Implementation Gate

This story is the first Epic 2 implementation story. It starts after Epic 1 has been merged to `main`; story creation pulled `origin/main` by fast-forward and found `epic-1: done` in `sprint-status.yaml`.

Before implementing, confirm the local branch is still based on the current `main` and there is no unrelated dirty work that would be overwritten. Preserve all user changes. If Epic 1 status has regressed or Story 1.10/1.11 closeout is no longer done, stop and fix tracking or complete Epic 1 before implementing Epic 2.

### Scope Boundary

This story creates the UI-facing data and command boundary only. It must not become a polished tactical UI story.

In scope:

- Read-only tactical board/cell/occupant/visibility/selection/action-availability view-model data.
- Minimal preview slot/metadata plumbing needed to carry existing query results safely.
- A command bridge that converts move/attack UI intent into existing typed domain commands.
- Inspect/selection-only intent that returns metadata without submitting gameplay commands.
- Headless tests proving no mutation before command execution and no domain internals exposed.

Out of scope:

- Full movement and attack preview presentation contracts; Story 2.2 owns detailed preview DTOs.
- Mobile two-step commit/cancel flow; Story 2.3 owns preview mode and confirm behavior.
- Inspect panel details, zoom, and coordinate mapping; Story 2.4 owns them.
- Layout profiles, orientation behavior, and tactical HUD scenes; Story 2.5 owns them.
- Accessibility/readability audit UI and settings; Stories 2.6 and 2.9 own them.
- Save/resume foundation; Stories 2.7 and 2.8 own it.
- New equipment, inventory, run-map, reward, class, content, or scene-owned state.

### Current Repository Baseline

Story creation used baseline commit `9ce024d7d4d6154a281f9c93cad9c9d987e85cb2` after pulling latest `main`.

Relevant Epic 1 implementation facts:

- `BoardState` owns tactical board dimensions, cells, entities, sequence ids, event application, snapshots, and staged event validation.
- `BoardCell` stores position, terrain, occupant id, explored, and visible flags.
- `TacticalEntityState` stores entity id, entity type, faction, position, HP, movement blocking, and definition id. It has no presentation state.
- `MoveCommand` validates `TacticalActionContext`, turn phase, active actor, and `TacticalMovementQuery` before emitting `entity_moved`.
- `AttackCommand` validates `TacticalActionContext`, weapon/support definitions, turn phase, active actor, and `AttackPreviewQuery` before emitting attack/damage/status/knockback events.
- `TacticalActionContext` currently carries `board`, `turn_state`, `rng_streams`, and `pending_telegraphs`.
- `TacticalMovementQuery.validate_target()` returns movement cost, budget, and serialized path metadata without mutating the board.
- `AttackPreviewQuery.preview_target_cell()` returns legality, target, weapon, line, blockers, warnings, effects, and expected damage metadata without mutating the board.
- `TacticalVisibilityQuery.visible_facts_for_cell()` already separates hidden, explored memory, and visible authoritative facts.
- `CombatOutcomeState` and `CombatOutcomeEvaluator` now exist from Story 1.11 and should remain domain-only.
- `TacticalSnapshot.from_domain()` serializes board, turn state, pending telegraphs, RNG streams, and event log for no-mutation and replay tests.
- `BoardFixtureFactory.micro_combat_board()` exists as the Epic 1 tactical fixture for Epic 2 view-model tests.
- Existing UI production code is minimal: `godot/scripts/ui/presenters/boot_controller.gd` is a `Control` scene bootstrapper. There are no tactical view models yet.

### Existing Files To Reuse Or Preserve

| Path | Current State | This Story Changes | Preserve |
|---|---|---|---|
| `godot/scripts/tactical/board/board_state.gd` | Authoritative board state and event replay. | Read only through public query/snapshot methods. No expected changes unless a tiny copy helper is clearly necessary. | Board ownership, staged validation, sequence ids, occupancy, visibility, HP mutation rules. |
| `godot/scripts/tactical/board/board_cell.gd` | Domain cell value with terrain, occupant id, explored, and visible flags. | Source for copied cell view data only. | Do not pass raw `BoardCell` to presenters. |
| `godot/scripts/tactical/entities/tactical_entity_state.gd` | Domain entity value with HP, faction, position, type, definition id. | Source for copied occupant view data only. | Do not add UI state or expose raw entity references. |
| `godot/scripts/core/commands/move_command.gd` | Existing typed move command. | Reuse through command bridge. | Validation-before-mutation and `advances_turn` metadata. |
| `godot/scripts/core/commands/attack_command.gd` | Existing typed attack command. | Reuse through command bridge. | Existing preview validation, combat RNG behavior, damage/event payloads. |
| `godot/scripts/tactical/tactical_action_context.gd` | Domain command context. | Pass into bridge validation/execution. | Do not turn it into a broad UI state bag. |
| `godot/scripts/tactical/movement/tactical_movement_query.gd` | Pure movement validation query. | Reuse for action availability if needed. | No mutation/no RNG behavior. |
| `godot/scripts/tactical/targeting/attack_preview_query.gd` | Pure attack preview/validation query. | Reuse for action availability if needed. | No mutation and hidden/memory target guardrails. |
| `godot/scripts/tactical/fog/tactical_visibility_query.gd` | Visibility facts helper. | Reuse to avoid leaking hidden facts. | Hidden and memory cells must stay non-authoritative. |
| `godot/scripts/save/snapshots/tactical_snapshot.gd` | Snapshot/no-mutation proof tool. | Use in tests; do not create UI save truth. | Snapshot remains domain-only and scene-free. |
| `godot/tests/fixtures/tactical/board_fixture_factory.gd` | Existing tactical fixtures including micro-combat board. | Reuse and extend only if necessary. | Existing fixtures and deterministic setup. |
| `godot/scripts/ui/presenters/boot_controller.gd` | Bootstrap `Control` presenter. | No expected change. | Do not add tactical gameplay state to boot presenter. |

### Recommended New Files

Use these names unless implementation discovers a simpler local pattern:

- `godot/scripts/ui/view_models/tactical_board_view_model.gd`
- `godot/scripts/ui/view_models/tactical_cell_view.gd`
- `godot/scripts/ui/view_models/tactical_occupant_view.gd`
- `godot/scripts/ui/view_models/tactical_selection_state.gd`
- `godot/scripts/ui/view_models/tactical_action_availability.gd`
- `godot/scripts/ui/command_bridge/tactical_command_bridge.gd`
- `godot/scripts/ui/command_bridge/command_bridge_result.gd` if needed
- `godot/tests/unit/ui/test_tactical_board_view_model.gd`
- `godot/tests/unit/ui/test_tactical_command_bridge.gd`

If small helper classes would create unnecessary fragmentation, merge them into the main view model, but keep the same contract: copied value data only, stable keys, no raw domain internals.

### View Model Contract

The view model should be a deterministic, presenter-facing snapshot of tactical state, not a live domain object.

Minimum board fields:

- `width`, `height`
- `cells`: stable row-major collection of copied cell views
- `occupants`: stable id-sorted collection of copied visible/current occupant views
- `selected_cell`: nullable copied cell coordinate
- `selected_entity_id`: nullable `StringName` or empty string
- `preview`: stable dictionary with `kind`, `available`, `reason`, and copied metadata. Story 2.2 can extend this.
- `action_availability`: copied action availability dictionary or helper result
- `turn`: copied turn number, phase id, and active actor id if supplied
- `outcome`: copied outcome id/metadata if supplied

Minimum cell view fields:

- `position`
- `visibility_state`: `hidden`, `memory`, or `visible`
- `authoritative`: `false` for hidden/memory, `true` for visible
- `terrain` only when allowed by visibility rules
- `occupant_id` only for visible current facts
- `blocks_line_of_sight`, `terrain_blocks_occupancy`, and similar tactical facts only when allowed by visibility rules

Minimum occupant view fields for visible current occupants:

- `entity_id`, `entity_type`, `faction`, `position`
- `current_hp`, `max_hp`, `is_alive`, `blocks_movement`, `definition_id`

Do not include:

- Raw `BoardState`, `BoardCell`, `TacticalEntityState`, `DomainEvent`, `TacticalActionContext`, scene `Node`, `Control`, animation, audio, or content repository references.
- Hidden current occupants or hidden HP/faction facts.
- Save truth or scene reconstruction data.
- Gameplay RNG draws or command side effects from building the view model.

### Command Bridge Contract

The command bridge turns presenter intent into typed domain commands and optional execution results. It is not gameplay authority.

Recommended intent dictionary shapes:

```gdscript
{
	"intent_id": "move",
	"actor_id": "hero",
	"target_cell": {"x": 2, "y": 3},
	"movement_budget": 3
}
```

```gdscript
{
	"intent_id": "attack",
	"actor_id": "hero",
	"target_cell": {"x": 4, "y": 1},
	"weapon": weapon_definition,
	"attacker_support": null,
	"defender_support": null
}
```

```gdscript
{
	"intent_id": "inspect",
	"target_cell": {"x": 4, "y": 1}
}
```

Recommended result fields:

- `succeeded`
- `disabled`
- `error_code`
- `reason`
- `intent_id`
- `command_id`
- `command`
- `metadata`

Rules:

- `build_command()` or equivalent may validate command availability, but it must not execute the command.
- `execute_intent()` or equivalent may exist, but it must call the command's `execute(context)` method and return that result. It must not apply events itself.
- Invalid conversion must return no command object and no mutation.
- Inspect conversion must return no gameplay command and no mutation.
- Valid conversion must return `MoveCommand` or `AttackCommand` and no mutation until explicit execution.
- Stable error codes must be lower snake case. Suggested codes: `invalid_ui_intent`, `unsupported_intent`, `action_unavailable`, `invalid_command_context`.

### Previous Story Intelligence

Epic 1 established the domain contracts this story must reuse:

- Story 1.7 established fog and explored-memory boundaries. Do not leak hidden current facts in view models.
- Story 1.8 established weapon definitions and pure attack previews. Reuse `AttackPreviewQuery` instead of reimplementing targeting.
- Story 1.9 established `AttackCommand` and damage events. Do not create UI-owned attack mutation.
- Story 1.10 established enemy turn resolution and pending telegraphs. This story should preserve pending telegraph data but not own enemy turn flow.
- Story 1.11 established outcome state, explanation log, and the Epic 1 micro-combat scenario. Reuse the micro-combat fixture as the first Epic 2 view-model proof.

### Git Intelligence

Recent mainline commits before this story:

- `9ce024d Merge pull request #1 from rthunborg/codex/epic-1`
- `3bde3fb docs: add epic 2 sprint plan`
- `40812e7 feat: implement combat outcome explanation loop`
- `44c2ba9 feat: implement prototype enemy turn resolution`
- `b463b52 fix: resolve story 1.9 review findings`

Actionable patterns from recent work:

- Story files include explicit current-baseline notes, file contracts, test requirements, and validation commands.
- Command implementations validate first, apply domain events through `BoardState.apply_events()`, and return `ActionResult`.
- Review patches have repeatedly strengthened no-mutation behavior, validation payloads, and deterministic metadata. Keep that standard for UI boundary tests.
- The headless runner auto-discovers `test_*.gd` under `godot/tests/unit` and `godot/tests/integration`; no registry edit is expected.

### Architecture Compliance

- Follow the Adaptive UI Composition Pattern: domain state/events -> view model -> presenter/layout profile -> user intent -> command bridge -> command/event simulation.
- UI presenters and scenes may observe domain state and submit commands; they cannot mutate tactical truth directly.
- Domain state remains scene-independent and authoritative.
- View models must be read-only copies or value helpers. They are not save snapshots and are not domain authority.
- Commands remain the mutation path. Successful commands emit deterministic past-tense `DomainEvent` records.
- Building view models and converting intent must not consume gameplay RNG streams.
- Headless tests must run without rendering, audio, UI scenes, presentation nodes, physics raycasts, navigation nodes, or scene-tree-only state.
- Do not add cloud services, accounts, multiplayer, telemetry dependencies, Godot .NET/C#, new test frameworks, or React/Vite production dependencies.

### Library And Framework Requirements

- Required engine: Godot 4.6.3 stable standard build.
- Required language: typed GDScript.
- Use `RefCounted` for view-model and command-bridge helper classes.
- Use `Resource` only for existing content definitions such as `WeaponDefinition` and `SupportDefinition`; do not make view models into content resources.
- Use the existing custom headless test harness based on `godot/tests/unit/test_case.gd`; do not add GUT, GdUnit, or another test dependency.
- Use `Vector2i` for grid coordinates internally and copied dictionaries for serialized presenter-facing data where useful.
- Avoid nested generic type declarations Godot does not support. Typed arrays/dictionaries are useful, but keep complex copied metadata as plain `Dictionary` when needed.

### Latest Technical Information

Official sources checked on 2026-06-07:

- Godot's official archive lists `4.6.3-stable` dated 2026-05-20. The archive also lists Godot 4.7 beta builds, but Sealsworn remains pinned to the stable 4.6.3 standard build for production. Source: https://godotengine.org/download/archive/4.6.3-stable/
- Godot 4.6 GDScript static typing supports typed variables, constants, functions, parameters, return values, custom classes through `class_name`, typed arrays, and typed dictionaries. Source: https://docs.godotengine.org/en/4.6/tutorials/scripting/gdscript/static_typing.html
- Godot 4.6 node lifecycle callbacks such as `_ready()` are for scene-tree objects. View models and command bridge helpers in this story should stay outside node lifecycle unless a presenter consumes them later. Source: https://docs.godotengine.org/en/4.6/tutorials/scripting/overridable_functions.html
- Godot 4.6 `Resource` is appropriate for reusable data containers and existing content definitions, not for the tactical view-model copies in this story. Source: https://docs.godotengine.org/en/4.6/classes/class_resource.html

### Project Structure Notes

- UI-facing logic belongs under `godot/scripts/ui/view_models/` and `godot/scripts/ui/command_bridge/`.
- Presenters remain under `godot/scripts/ui/presenters/`; no presenter changes are expected for this story.
- UI scenes belong under `godot/scenes/ui/`, but this story should not need new scenes.
- Tests mirror domains under `godot/tests/unit/ui/`.
- Production code stays under `godot/`; do not add production dependencies on `prototype/`.
- Root `project-context.md` is canonical. Do not create duplicate project-context files under `_bmad-output/`.

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
- Existing Epic 1 tests remain green.
- New view-model tests prove hidden/memory/visible facts are exposed correctly and no raw domain internals are returned.
- New no-mutation tests prove view-model construction, view-model data edits, command conversion, invalid intent, and inspect intent do not mutate board, turn state, RNG streams, pending telegraphs, outcome state, or event log.
- New command bridge tests prove valid move/attack conversion creates `MoveCommand`/`AttackCommand`, and explicit execution mutates only through command results/events.
- `git diff --check` reports no whitespace errors.

### Project Context Rules

- Read and follow root `project-context.md` before implementation.
- Read `_bmad-output/game-architecture.md` before architecture-sensitive changes.
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
- Do not introduce cloud services, accounts, multiplayer, telemetry dependencies, Godot .NET/C#, new test frameworks, or third-party libraries unless the architecture is explicitly revised.
- Preserve user changes and unrelated dirty worktree files.

### References

- [Source: `_bmad-output/planning-artifacts/epics.md` - Epic 2 and Story 2.1 acceptance criteria]
- [Source: `_bmad-output/implementation-artifacts/epic-2-sprint-plan-2026-06-07.md` - Sprint Slice 1 and Epic 2 guardrails]
- [Source: `project-context.md` - Domain ownership, file placement, testing, and no-telemetry rules]
- [Source: `_bmad-output/game-architecture.md` - Adaptive UI Composition Pattern, Presentation Binding Pattern, and architectural boundaries]
- [Source: `_bmad-output/planning-artifacts/gdds/gdd-Game-2026-05-31/gdd.md` - mobile input, preview, inspect, readability, and save/resume requirements]
- [Source: `_bmad-output/implementation-artifacts/1-11-combat-outcome-death-victory-and-explanation-log.md` - Epic 1 closeout and micro-combat fixture context]
- [Source: Godot 4.6.3 stable archive](https://godotengine.org/download/archive/4.6.3-stable/)
- [Source: Godot 4.6 static typing docs](https://docs.godotengine.org/en/4.6/tutorials/scripting/gdscript/static_typing.html)
- [Source: Godot 4.6 node lifecycle docs](https://docs.godotengine.org/en/4.6/tutorials/scripting/overridable_functions.html)
- [Source: Godot 4.6 Resource docs](https://docs.godotengine.org/en/4.6/classes/class_resource.html)

## Dev Agent Record

### Agent Model Used

Codex GPT-5

### Debug Log References

- 2026-06-07: Pulled latest `origin/main` by fast-forward after Epic 1 merge.
- 2026-06-07: Created Story 2.1 implementation guide from Epic 2 source requirements, Epic 2 sprint plan, root project context, game architecture, GDD UX/input requirements, current Epic 1 code/tests, recent commits, and official Godot 4.6 documentation.
- 2026-06-07: Confirmed `sprint-status.yaml` had `epic-1: done`, Story 1.10 done, Story 1.11 done, and Story 2.1 ready-for-dev before implementation.
- 2026-06-07: Added red-phase UI boundary tests and confirmed the headless runner failed on the missing view-model/command-bridge scripts before implementation.
- 2026-06-07: Implemented copied tactical board view models, action availability helpers, command bridge conversion, and command bridge result contracts.
- 2026-06-07: Ran `godot --version`, `godot --headless --path C:\Sealsworn\godot --scene res://tests/headless/test_runner.tscn --quit-after 10`, and `git diff --check`.
- 2026-06-07: Ran `gds-code-review` layers for Story 2.1, fixed patch findings, and reran the full headless test runner.

### Completion Notes List

- Implemented `TacticalBoardViewModel` and value helpers for copied cell, occupant, selection, preview, action availability, turn, outcome, and event-log summary data.
- Reused `TacticalVisibilityQuery.visible_facts_for_cell()` so hidden cells expose only position/state, memory cells remain non-authoritative, and visible cells expose current occupant summaries without leaking raw domain objects.
- Implemented `TacticalCommandBridge` and `CommandBridgeResult` for move, attack, and inspect intents; conversion validates availability without execution, and explicit execution delegates to the returned typed command.
- Added UI unit tests covering stable view-model keys, deep-copy/no-mutation behavior, hidden/memory visibility boundaries, valid move/attack conversion, inspect metadata, invalid intent disabled states, and command-path-only mutation.
- Review patches now sanitize presenter-facing metadata, normalize supplied action availability, return metadata-only success for inspect execution, reject malformed intents and partial contexts, and avoid exposing movement path or attack line/blocker internals before Story 2.2 preview DTOs.

### File List

- `_bmad-output/implementation-artifacts/2-1-tactical-view-models-and-command-bridge.md`
- `_bmad-output/implementation-artifacts/sprint-status.yaml`
- `godot/scripts/ui/command_bridge/command_bridge_result.gd`
- `godot/scripts/ui/command_bridge/tactical_command_bridge.gd`
- `godot/scripts/ui/view_models/tactical_action_availability.gd`
- `godot/scripts/ui/view_models/tactical_board_view_model.gd`
- `godot/scripts/ui/view_models/tactical_cell_view.gd`
- `godot/scripts/ui/view_models/tactical_occupant_view.gd`
- `godot/scripts/ui/view_models/tactical_selection_state.gd`
- `godot/tests/unit/ui/test_tactical_board_view_model.gd`
- `godot/tests/unit/ui/test_tactical_command_bridge.gd`

## Change Log

- 2026-06-07: Created Story 2.1 implementation guide and marked it ready for development.
- 2026-06-07: Implemented tactical view-model and command bridge UI boundary with headless tests; marked ready for review.
- 2026-06-07: Fixed Story 2.1 code-review findings and prepared story for done status.
