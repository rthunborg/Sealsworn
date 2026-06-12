---
baseline_commit: f8cacb42381750138e878fe4080229c13b94d2a7
created: 2026-06-07
source_story_key: 2-2-movement-and-attack-preview-presentation-contracts
---

# Story 2.2: Movement and Attack Preview Presentation Contracts

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a player,
I want movement and attack previews to show valid options, warnings, and expected outcomes,
so that I can decide before spending a turn.

## Acceptance Criteria

1. Given a visible reachable tile is selected, when movement preview is requested, then the view model reports path, cost, target validity, and commit availability, and the preview does not mutate turn or board state.
2. Given a visible enemy is selected, when attack preview is requested, then the view model reports weapon reach, line or path, expected damage, effects, blocker state, and warnings, and warnings include adjacency penalties where applicable.
3. Given an invalid target is selected, when preview is requested, then the preview reports a clear invalid reason, and the commit action remains unavailable.

## Tasks / Subtasks

- [x] 2.2.1 Confirm the Epic 2 boundary and add failing tests first. (AC: 1-3)
  - [x] Verify `sprint-status.yaml` has `epic-1: done`, Story 2.1 `done`, and this story `ready-for-dev` before implementation starts.
  - [x] Add `godot/tests/unit/ui/test_tactical_preview_view_models.gd` or an equivalent focused test file for movement and attack preview DTO contracts.
  - [x] Update `godot/tests/unit/ui/test_tactical_board_view_model.gd` only for the board preview slot integration; keep most preview-specific expectations in the new preview tests.
  - [x] Use `BoardFixtureFactory.micro_combat_board()`, movement fixtures, and `AttackPreviewContractMatrix.baseline_cases()` before adding new fixtures.
  - [x] Capture `TacticalSnapshot.from_domain()` before every preview request and assert board, turn state, pending telegraphs, RNG stream snapshots, and event log remain unchanged.
- [x] 2.2.2 Define UI-facing preview DTO value contracts. (AC: 1-3)
  - [x] Add narrow `RefCounted` view-model helpers under `godot/scripts/ui/view_models/`, such as `tactical_preview_view.gd`, `tactical_movement_preview.gd`, and `tactical_attack_preview.gd`, unless one smaller file is clearer.
  - [x] Keep DTOs copied value data only: `String`, `StringName`, `int`, `bool`, `float`, `Vector2i`, `Array`, and `Dictionary` copies.
  - [x] Do not expose `BoardState`, `BoardCell`, `TacticalEntityState`, `TacticalActionContext`, `ActionResult`, command instances, `WeaponDefinition`, `SupportDefinition`, `DomainEvent`, `Node`, `Control`, `Resource`, or mutable repository internals to presenters.
  - [x] Provide stable `to_dictionary()` output and deep-copy nested arrays/dictionaries so presenter edits cannot mutate cached DTOs or domain state.
  - [x] Normalize `StringName` and `Vector2i` values to presenter-safe strings and `{ "x": int, "y": int }` dictionaries.
- [x] 2.2.3 Implement movement preview construction from existing movement validation. (AC: 1, 3)
  - [x] Reuse `TacticalMovementQuery.validate_target()` for movement legality, path, movement cost, budget, and invalid reasons.
  - [x] Do not duplicate pathfinding logic in UI scripts. If a path helper is needed, call existing tactical query code.
  - [x] Movement preview dictionary must include stable top-level fields: `kind: "move"`, `available`, `reason`, `actor_id`, `target_cell`, `target_valid`, `commit_available`, `commit_reason`, `cue_ids`, and `metadata`.
  - [x] Movement `metadata` must include `path`, `movement_cost`, `movement_budget`, and any sanitized invalid target facts available from the query.
  - [x] For valid reachable tiles, `available`, `target_valid`, and `commit_available` are true and `reason` is `valid`.
  - [x] For invalid movement targets, `available` and `commit_available` are false, `reason` matches the query reason, and the DTO does not invent a path.
  - [x] Preserve the known movement reasons: `invalid_board`, `invalid_budget`, `invalid_actor`, `dead_actor`, `same_cell`, `out_of_bounds`, `not_visible`, `blocked`, `occupied`, `unreachable`, and `beyond_budget`.
- [x] 2.2.4 Implement attack preview construction from existing attack preview validation. (AC: 2, 3)
  - [x] Reuse `AttackPreviewQuery.preview_target_cell()` for attack legality, line cells, blocker cells, range, distance, expected base damage, effects, warnings, and explanation.
  - [x] Do not run `AttackCommand.execute()` and do not roll combat RNG while building previews.
  - [x] Attack preview dictionary must include stable top-level fields: `kind: "attack"`, `available`, `reason`, `actor_id`, `target_cell`, `target_entity_id`, `target_valid`, `commit_available`, `commit_reason`, `cue_ids`, and `metadata`.
  - [x] Attack `metadata` must include `weapon_id`, `weapon_reach`, `targeting_shape`, `distance`, `line_cells`, `blocker_cells`, `blocker_state`, `blocker_ignored`, `expected_damage`, `expected_base_damage`, `effects`, `warnings`, and `explanation`.
  - [x] Map blocker state to a stable presenter-facing id: `clear`, `blocked`, `ignored`, or `unknown`.
  - [x] Preserve adjacency warning ids from weapon definitions, especially `adjacent_ranged_penalty` for bow/staff adjacent attacks.
  - [x] Preserve the known attack reasons: `invalid_weapon`, `invalid_actor`, `dead_actor`, `same_cell`, `out_of_bounds`, `not_visible`, `missing_target`, `dead_target`, `friendly_target`, `not_aligned`, `out_of_range`, and `blocked_line`.
  - [x] Keep expected damage as deterministic preview damage. Do not include final shield block, proc, armor, or knockback success outcomes that require command execution or RNG.
- [x] 2.2.5 Integrate previews into the existing board view model and action availability. (AC: 1-3)
  - [x] Update `TacticalBoardViewModel.from_domain()` so the existing `preview` slot accepts and preserves the new normalized preview dictionaries.
  - [x] Update `TacticalActionAvailability.from_preview()` so `move`, `attack`, and `confirm` availability reflect `commit_available` and `commit_reason` from the current preview.
  - [x] Keep `inspect` available as selection/metadata behavior, not as a gameplay command.
  - [x] Keep `cancel` unavailable until Story 2.3 unless a preview DTO explicitly provides a presentational cancel state for future flow. Do not implement cancel behavior in this story.
  - [x] Ensure board view-model key ordering expectations remain deterministic and Story 2.1 no-mutation tests still pass.
- [x] 2.2.6 Add preview cue id contracts without requiring final assets. (AC: 1-3)
  - [x] Add stable cue ids in preview DTOs for valid move preview, invalid move preview, valid attack preview, invalid attack preview, blocked line, adjacency warning, effect preview, commit available, and commit unavailable.
  - [x] Cues are ids and optional text metadata only. Do not add final audio assets, VFX, animation, art, scene nodes, or asset-source metadata in this story.
  - [x] Critical warning information must be exposed as ids plus text or labels, not color-only hints. Story 2.6 owns the broader accessibility audit.
- [x] 2.2.7 Prove deterministic no-mutation behavior. (AC: 1-3)
  - [x] Tests must prove valid and invalid movement previews do not mutate board cells, entity positions, turn phase, active actor, pending telegraphs, RNG streams, or event logs.
  - [x] Tests must prove valid and invalid attack previews do not mutate board cells, HP, turn phase, active actor, pending telegraphs, RNG streams, or event logs.
  - [x] Tests must mutate returned preview dictionaries and prove a second `to_dictionary()` call returns unchanged cached data.
  - [x] Tests must prove preview DTOs contain no raw domain object references, no command instances, no scene nodes, and no content `Resource` objects.
  - [x] Tests must prove invalid preview targets return no commit availability and stable lower-snake reasons.
- [x] 2.2.8 Cover baseline preview cases. (AC: 1-3)
  - [x] Movement cases: valid reachable tile, same cell, out of bounds, hidden/not visible, wall blocked, occupied, unreachable, and beyond movement budget.
  - [x] Attack cases from `AttackPreviewContractMatrix`: sword adjacent, bow adjacent penalty, bow blocked line, wand blocker override, diagonal rejection, out of range, hidden target, memory target, empty target, dead target, and friendly target.
  - [x] Include at least one integration-style test that builds `TacticalBoardViewModel` with a movement preview and an attack preview for the Epic 1 micro-combat fixture.
  - [x] Include a regression that command bridge conversion still strips path/line internals unless the preview-specific contract explicitly supplies them through the view-model preview slot.
- [x] 2.2.9 Keep scope clean and update records. (AC: 1-3)
  - [x] Do not add tactical HUD scenes, touch gesture handlers, mobile two-step commit/cancel state, inspect panels, zoom coordinate mapping, layout profiles, settings UI, save/resume UI, final audio/VFX, or production art.
  - [x] Run `godot --version`.
  - [x] Run `godot --headless --path C:\Sealsworn\godot --scene res://tests/headless/test_runner.tscn --quit-after 10`.
  - [x] Run `git diff --check`.
  - [x] Update this story's Dev Agent Record, Completion Notes, File List, and Change Log with actual implementation work.
  - [x] Keep `sprint-status.yaml` synchronized with this story status.

## Dev Notes

### Pre-Implementation Gate

This is the second Epic 2 implementation story. Story creation found:

- Current branch: `codex/epic-2`
- Baseline commit: `f8cacb42381750138e878fe4080229c13b94d2a7`
- Working tree: clean at story creation time
- `epic-1: done`
- Story 2.1: `done`
- Story 2.2: `backlog` before this file was created

Before implementing, confirm the local tree is still clean or that any dirty files are intentional user work. Preserve unrelated changes. If Story 2.1 is no longer done or if its tests fail, stop and restore that boundary before adding preview contracts.

### Scope Boundary

This story creates presenter-facing preview contracts only. It should make preview data usable by future UI without committing actions or building polished UI scenes.

In scope:

- Movement preview DTOs for path, movement cost, budget, target validity, invalid reason, commit availability, and cue ids.
- Attack preview DTOs for weapon reach, line cells, blocker cells/state, expected deterministic damage, effects, warnings, invalid reason, commit availability, and cue ids.
- Board view-model preview slot integration.
- Action availability normalization for preview-driven move/attack/confirm availability.
- Headless tests for valid, invalid, deterministic, sanitized, and no-mutation preview behavior.

Out of scope:

- Mobile two-step commit, same-target second tap, confirm button behavior, and cancel flow. Story 2.3 owns these.
- Inspect panel content and zoom coordinate mapping. Story 2.4 owns these.
- Layout profiles, orientation behavior, tactical HUD scenes, and presenter composition. Story 2.5 owns these.
- Full accessibility/readability audit and settings. Stories 2.6 and 2.9 own these.
- Save/resume foundation. Stories 2.7 and 2.8 own it.
- Final audio, VFX, animation, production art, UI frames, touch gesture handlers, or scene-owned tactical state.

### Current Repository Baseline

Story 2.1 implemented the UI boundary this story must extend:

- `TacticalBoardViewModel` builds copied presenter-facing board dictionaries from `BoardState`, `TacticalTurnState`, optional outcome state, selection, preview metadata, action availability, and event-log summaries.
- `TacticalBoardViewModel` already sanitizes preview metadata so raw domain objects become `null`, `Vector2i` becomes cell dictionaries, and nested dictionaries/arrays are copied.
- The existing preview slot is minimal: `kind`, `available`, `reason`, and `metadata`.
- `TacticalActionAvailability.from_preview()` currently enables `move` only for available move previews, enables `attack` only for available attack previews, always enables `inspect`, and keeps `confirm`/`cancel` disabled.
- `TacticalCommandBridge.build_command()` supports `move`, `attack`, and `inspect` intents and validates without command execution.
- `TacticalCommandBridge` intentionally strips movement `path`, attack `line_cells`, and attack `blocker_cells` from command conversion metadata. Story 2.2 should expose those through preview DTOs instead of loosening command conversion.
- `TacticalCommandBridge.execute_intent()` delegates to the typed command's `execute(context)` only after conversion; the bridge itself does not mutate tactical state.
- `TacticalSnapshot.from_domain()` is the current no-mutation proof tool for board, turn, pending telegraphs, RNG streams, and event logs.

Relevant Epic 1 preview/query facts:

- `TacticalMovementQuery.validate_target()` already returns movement validity, `movement_cost`, `movement_budget`, and serialized `path` for valid movement without mutating the board.
- `TacticalMovementQuery.validate_target()` returns `invalid_movement` with stable `reason` metadata for invalid board, budget, actor, dead actor, same cell, out of bounds, not visible, blocked, occupied, unreachable, and beyond budget.
- `AttackPreviewQuery.preview_target_cell()` already returns attack legality, target metadata, weapon id, targeting shape, range, distance, line cells, blocker cells, blocker ignored flag, expected base damage, warnings, effects, and explanation without mutating the board or consuming RNG.
- `AttackPreviewQuery.preview_target_cell()` returns `invalid_attack_preview` with stable `reason` metadata for invalid weapon, invalid actor, dead actor, same cell, out of bounds, not visible, missing target, dead target, friendly target, not aligned, out of range, and blocked line.
- `AttackCommand.validate()` wraps `AttackPreviewQuery` metadata and checks turn phase, actor, weapon, and support definitions. `AttackCommand.execute()` is where HP mutation, shield block RNG, weapon proc RNG, knockback events, and event application happen.
- Baseline weapons are provided by `WeaponRepository.create_baseline_repository()` and include sword, dagger, spear, axe, mace, bow, crossbow, staff, and wand.
- `AttackPreviewContractMatrix.baseline_cases()` already lists useful attack preview fixtures, including bow adjacency warning, blocked line, wand blocker override, hidden/memory targets, dead target, and friendly target.

### Existing Files To Reuse Or Preserve

| Path | Current State | This Story Changes | Preserve |
|---|---|---|---|
| `godot/scripts/ui/view_models/tactical_board_view_model.gd` | Builds copied board view dictionaries and minimal preview slot. | Update preview normalization to accept the new movement/attack DTO dictionaries and preserve stable keys. | Hidden/memory visibility boundaries, no raw domain objects, deterministic row-major/id sorting. |
| `godot/scripts/ui/view_models/tactical_action_availability.gd` | Derives move/attack availability from minimal preview kind and available flag. | Read `commit_available` and `commit_reason` from preview DTOs for move/attack/confirm availability. | Inspect remains metadata-only; no command execution or state mutation. |
| `godot/scripts/ui/command_bridge/tactical_command_bridge.gd` | Converts move/attack intents to commands, inspect to metadata; strips path/line internals. | Usually no change. If adding preview intent helpers, keep them validation-only and do not expose command objects as preview data. | Build-command conversion remains separate from preview DTOs; execution delegates only to commands. |
| `godot/scripts/tactical/movement/tactical_movement_query.gd` | Pure movement validation and path metadata. | Reuse as source for movement preview DTOs. | No UI dependency, no scene dependency, no mutation. |
| `godot/scripts/tactical/targeting/attack_preview_query.gd` | Pure attack preview validation and metadata. | Reuse as source for attack preview DTOs. | No command execution, no RNG draws, no HP mutation. |
| `godot/scripts/tactical/targeting/tactical_line_query.gd` | Computes supercover line and blockers for targeting. | Reuse indirectly through `AttackPreviewQuery`; do not duplicate in UI. | Tactical query remains domain-side. |
| `godot/scripts/core/commands/move_command.gd` | Validates movement and mutates only on `execute()`. | No expected change. Tests may compare preview reasons with command validation. | Command remains mutation path. |
| `godot/scripts/core/commands/attack_command.gd` | Validates via preview query, mutates and rolls RNG only on `execute()`. | No expected change. Tests may confirm previews never call execute. | RNG, HP mutation, events, and turn advancement remain command-only. |
| `godot/scripts/save/snapshots/tactical_snapshot.gd` | Snapshot/no-mutation proof tool. | Use in tests. | Snapshot remains domain-only and scene-free. |
| `godot/tests/unit/ui/test_tactical_board_view_model.gd` | Existing Story 2.1 board VM tests. | Add focused preview slot assertions only as needed. | Existing read-only, sanitation, visibility, and no-mutation coverage must remain green. |
| `godot/tests/unit/ui/test_tactical_command_bridge.gd` | Existing Story 2.1 bridge tests. | Keep conversion metadata stripping unless intentionally changed with tests. | Bridge conversion remains distinct from preview presentation. |
| `godot/tests/fixtures/tactical/board_fixture_factory.gd` | Movement, attack preview, enemy turn, outcome, and micro-combat fixtures. | Reuse first; add only small fixtures if preview coverage cannot be expressed with existing ones. | Existing fixtures and deterministic setup. |
| `godot/tests/fixtures/tactical/attack_preview_contract_matrix.gd` | Baseline attack preview cases. | Reuse for attack preview DTO matrix tests. | Expected reason/damage/warning/effect ids stay authoritative. |

### Recommended New Files

Use these names unless implementation discovers a simpler local pattern:

- `godot/scripts/ui/view_models/tactical_preview_view.gd`
- `godot/scripts/ui/view_models/tactical_movement_preview.gd`
- `godot/scripts/ui/view_models/tactical_attack_preview.gd`
- `godot/tests/unit/ui/test_tactical_preview_view_models.gd`

If helper classes create unnecessary fragmentation, merge movement and attack preview building into one preview view-model helper. Keep the observable contract the same: copied values, stable keys, no raw domain internals, no mutation.

### Preview Contract

The board view model's `preview` field should become the stable contract future presenters bind to. Use the same top-level keys for movement and attack where possible.

Common preview fields:

```gdscript
{
	"kind": "move" or "attack",
	"available": true,
	"reason": "valid",
	"actor_id": "hero",
	"target_cell": {"x": 2, "y": 1},
	"target_valid": true,
	"commit_available": true,
	"commit_reason": "valid",
	"cue_ids": ["move_preview_valid", "commit_available"],
	"metadata": {}
}
```

Movement metadata fields:

- `path`: array of `{ "x": int, "y": int }` cells including origin and target for valid previews.
- `movement_cost`: deterministic movement cost from `TacticalMovementQuery`.
- `movement_budget`: budget used for validation, defaulting to `MoveCommand.BASELINE_MOVEMENT_BUDGET`.
- `blocked_reason`: same as `reason` for invalid movement previews, or empty string for valid movement.

Attack metadata fields:

- `weapon_id`
- `weapon_reach`
- `targeting_shape`
- `distance`
- `line_cells`
- `blocker_cells`
- `blocker_state`: `clear`, `blocked`, `ignored`, or `unknown`
- `blocker_ignored`
- `expected_damage`
- `expected_base_damage`
- `effects`
- `warnings`
- `explanation`

Preview DTOs must avoid:

- Command objects or executable callbacks.
- Raw `ActionResult` objects.
- Raw `WeaponDefinition` or `SupportDefinition` resources.
- Hidden current occupant facts or hidden HP/faction facts.
- Final attack outcomes that require execution, such as shield block success, proc success, final damage after RNG, or actual knockback success.
- Scene, presenter, audio, VFX, animation, or save reconstruction data.

### Cue Id Contract

This story may define cue ids so later presenters and audio/VFX systems can bind feedback without reinterpreting raw metadata.

Recommended cue ids:

- `move_preview_valid`
- `move_preview_invalid`
- `attack_preview_valid`
- `attack_preview_invalid`
- `attack_preview_blocked_line`
- `attack_preview_blocker_ignored`
- `attack_preview_adjacent_warning`
- `preview_effect`
- `commit_available`
- `commit_unavailable`

Cue ids should be strings in the DTO, not loaded assets. Do not add audio files, visual effects, animation players, or production art in this story.

### Previous Story Intelligence

Story 2.1 review patches are directly relevant:

- Presenter-facing metadata must be sanitized. The preview DTOs may carry richer path and line data than Story 2.1 allowed, but only as copied dictionaries/arrays.
- Action availability must remain stable for move, attack, inspect, confirm, and cancel even when caller-provided availability is partial.
- Inspect is metadata-only success, not an error and not a command.
- Malformed payloads and partial contexts must return stable disabled results instead of leaking null access errors.
- Occupant summaries must stay tied to visible occupant facts.
- UI boundary tests should cover invalid/no-mutation cases, not only happy paths.

The key lesson is that richer preview data is allowed only because this story defines a sanitized preview contract. Do not reintroduce the raw metadata leak that Story 2.1 review patches removed.

### Git Intelligence

Recent commits before this story:

- `f8cacb4 feat: implement tactical UI command bridge`
- `9ce024d Merge pull request #1 from rthunborg/codex/epic-1`
- `3bde3fb docs: add epic 2 sprint plan`
- `40812e7 feat: implement combat outcome explanation loop`
- `44c2ba9 feat: implement prototype enemy turn resolution`

Actionable patterns:

- Story 2.1 added tests first and used the custom headless runner without adding a third-party test framework.
- Review findings have repeatedly tightened metadata sanitation, no-mutation checks, and stable disabled reasons.
- Command and query code returns lower-snake reason ids through `ActionResult.metadata["reason"]`; preview DTOs should preserve those ids rather than inventing new presentation-only reason text.
- The headless runner auto-discovers `test_*.gd` under `godot/tests/unit` and `godot/tests/integration`; no test registry edit is expected.

### Architecture Compliance

- Follow the Adaptive UI Composition Pattern: domain state/events to view model to presenter/layout profile to user intent to command bridge to command/event simulation.
- UI preview DTOs are read-only presentation contracts. They are not domain state, not save truth, and not commands.
- Scenes and presenters may bind to preview dictionaries; they cannot mutate tactical truth directly.
- Movement and attack preview construction must not consume gameplay RNG streams.
- Movement and attack preview construction must not apply events, change turn phase, move entities, change HP, alter pending telegraphs, or append event-log entries.
- Domain state remains scene-independent and authoritative.
- Successful commands, not preview requests, emit deterministic past-tense `DomainEvent` records.
- Headless tests must run without rendering, audio, UI scenes, presentation nodes, physics raycasts, navigation nodes, or scene-tree-only state.
- Do not add cloud services, accounts, multiplayer, telemetry dependencies, Godot .NET/C#, new test frameworks, or React/Vite production dependencies.

### Library And Framework Requirements

- Required engine: Godot 4.6.3 stable standard build.
- Required language: typed GDScript.
- Use `RefCounted` for preview view-model helpers.
- Use existing `Resource` classes only as input definitions, such as `WeaponDefinition`; never expose those resources directly in presenter-facing preview dictionaries.
- Use `Vector2i` internally for grid coordinates and copied dictionaries for presenter-facing coordinate data.
- Use plain `Dictionary` for copied nested metadata where Godot typing would become brittle. Keep public method parameters and return values typed.
- Do not add GUT, GdUnit, or another test dependency. Use the existing custom test harness based on `godot/tests/unit/test_case.gd`.

### Latest Technical Information

Official sources checked on 2026-06-07:

- Godot's official archive still lists `4.6.3-stable` as the production stable version dated 2026-05-20. Sealsworn remains pinned to Godot 4.6.3 stable standard build. Source: https://godotengine.org/download/archive/4.6.3-stable/
- Godot 4.6 GDScript static typing supports typed variables, constants, functions, parameters, return values, custom classes via `class_name`, typed arrays, and typed dictionaries. Use typed GDScript for preview helpers, while keeping complex presenter metadata as copied dictionaries where that is clearer. Source: https://docs.godotengine.org/en/4.6/tutorials/scripting/gdscript/static_typing.html
- Godot 4.6 input docs describe `InputEventScreenTouch` as touch-click equivalent and `InputEventScreenDrag` as mouse-motion-like. This story should not implement input handlers, but its DTOs should be suitable for later touch and mouse presenters. Source: https://docs.godotengine.org/en/4.6/tutorials/inputs/input_examples.html
- Godot 4.6 `Node` lifecycle and input callbacks are for scene-tree objects. Preview helpers in this story should stay `RefCounted` and scene-free; later presenters can consume them from `Control` or `Node` scripts. Source: https://docs.godotengine.org/en/4.6/classes/class_node.html

### Project Structure Notes

- UI-facing preview contracts belong under `godot/scripts/ui/view_models/`.
- Command conversion remains under `godot/scripts/ui/command_bridge/`; avoid moving preview authority into command execution.
- Tactical legality queries remain under `godot/scripts/tactical/`.
- Tests mirror domains under `godot/tests/unit/ui/`.
- Production code stays under `godot/`; do not add production dependencies on `prototype/`.
- Root `project-context.md` is canonical. Do not create duplicate project context files under `_bmad-output/`.

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
- Existing Epic 1 and Story 2.1 tests remain green.
- New movement preview tests prove valid and invalid previews expose path/cost/reason/commit availability without mutation.
- New attack preview tests prove valid and invalid previews expose line/blockers/damage/effects/warnings/reason/commit availability without mutation.
- New tests prove preview construction does not consume combat RNG or any other gameplay RNG stream.
- New tests prove returned preview dictionaries are deep copies and contain no raw domain or scene references.
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

- [Source: `_bmad-output/planning-artifacts/epics.md` - Epic 2 and Story 2.2 acceptance criteria]
- [Source: `_bmad-output/implementation-artifacts/epic-2-sprint-plan-2026-06-07.md` - Sprint Slice 2 preview presentation contracts]
- [Source: `_bmad-output/implementation-artifacts/2-1-tactical-view-models-and-command-bridge.md` - previous story boundary, review findings, and files]
- [Source: `project-context.md` - domain ownership, file placement, testing, and no-telemetry rules]
- [Source: `_bmad-output/game-architecture.md` - Adaptive UI Composition Pattern, Presentation Binding Pattern, and architectural boundaries]
- [Source: `_bmad-output/planning-artifacts/gdds/gdd-Game-2026-05-31/gdd.md` - movement preview, attack preview, mobile input, and under-100ms preview response requirements]
- [Source: `godot/scripts/ui/view_models/tactical_board_view_model.gd` - current board VM preview slot and sanitation behavior]
- [Source: `godot/scripts/ui/view_models/tactical_action_availability.gd` - current action availability derivation]
- [Source: `godot/scripts/ui/command_bridge/tactical_command_bridge.gd` - current command conversion boundary]
- [Source: `godot/scripts/tactical/movement/tactical_movement_query.gd` - movement validation metadata]
- [Source: `godot/scripts/tactical/targeting/attack_preview_query.gd` - attack preview metadata]
- [Source: `godot/tests/fixtures/tactical/attack_preview_contract_matrix.gd` - baseline attack preview case matrix]
- [Source: Godot 4.6.3 stable archive](https://godotengine.org/download/archive/4.6.3-stable/)
- [Source: Godot 4.6 static typing docs](https://docs.godotengine.org/en/4.6/tutorials/scripting/gdscript/static_typing.html)
- [Source: Godot 4.6 input examples](https://docs.godotengine.org/en/4.6/tutorials/inputs/input_examples.html)
- [Source: Godot 4.6 Node docs](https://docs.godotengine.org/en/4.6/classes/class_node.html)

## Dev Agent Record

### Agent Model Used

GPT-5 Codex

### Debug Log References

- 2026-06-07: Created Story 2.2 implementation guide from Epic 2 source requirements, Epic 2 sprint plan, root project context, game architecture, GDD input/preview requirements, Story 2.1 implementation notes, current Godot UI/query code, recent commits, and official Godot 4.6 documentation.
- 2026-06-08: Confirmed sprint boundary (`epic-1: done`, Story 2.1 `done`, Story 2.2 `ready-for-dev`) before implementation, then moved Story 2.2 to `in-progress`.
- 2026-06-08: Added failing `test_tactical_preview_view_models.gd`; first headless run failed because `tactical_attack_preview.gd` and `tactical_movement_preview.gd` did not exist yet.
- 2026-06-08: Implemented scene-free movement and attack preview DTO helpers using existing tactical query classes, then integrated preview normalization with board view-model and action availability.
- 2026-06-08: Ran `godot --version` and full headless suite; Godot reported `4.6.3.stable.official.7d41c59c4`, and the suite passed.

### Implementation Plan

- Add red tests for the presenter-facing movement/attack preview contract and no-mutation guarantees.
- Build narrow `RefCounted` DTO helpers that copy and normalize existing tactical query metadata without duplicating movement pathfinding or attack line/blocker logic.
- Preserve the Story 2.1 UI boundary by keeping command conversion separate from preview dictionaries and keeping raw domain objects out of presenter-facing data.
- Wire normalized preview dictionaries into `TacticalBoardViewModel` and derive move/attack/confirm availability from `commit_available`.

### Completion Notes List

- Added `TacticalMovementPreview`, `TacticalAttackPreview`, and `TacticalPreviewView` as copied-value, scene-free preview DTO helpers.
- Movement previews now expose valid/invalid reason ids, target/commit availability, path/cost/budget metadata, and stable cue ids without mutating domain state.
- Attack previews now expose weapon reach, targeting shape, line/blocker cells, blocker state, expected deterministic damage, warnings/effects/explanation, target/commit availability, and cue ids without executing attacks or consuming RNG.
- `TacticalBoardViewModel` now preserves normalized preview dictionaries, and `TacticalActionAvailability` enables move/attack/confirm from preview commit availability while keeping inspect available and cancel unavailable.
- Added focused tests covering baseline movement cases, `AttackPreviewContractMatrix` cases, no-mutation snapshots, deep-copy safety, forbidden-reference checks, board VM integration, and command bridge metadata stripping.

### File List

- `_bmad-output/implementation-artifacts/2-2-movement-and-attack-preview-presentation-contracts.md`
- `_bmad-output/implementation-artifacts/sprint-status.yaml`
- `godot/scripts/ui/view_models/tactical_action_availability.gd`
- `godot/scripts/ui/view_models/tactical_attack_preview.gd`
- `godot/scripts/ui/view_models/tactical_board_view_model.gd`
- `godot/scripts/ui/view_models/tactical_movement_preview.gd`
- `godot/scripts/ui/view_models/tactical_preview_view.gd`
- `godot/tests/unit/ui/test_tactical_board_view_model.gd`
- `godot/tests/unit/ui/test_tactical_preview_view_models.gd`

## Change Log

- 2026-06-07: Created Story 2.2 implementation guide and marked it ready for development.
- 2026-06-08: Implemented movement and attack preview presentation contracts, board VM integration, action availability updates, cue ids, and headless tests; story marked ready for review.
