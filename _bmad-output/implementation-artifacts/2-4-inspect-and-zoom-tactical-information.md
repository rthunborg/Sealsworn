---
baseline_commit: 3753756da9130642cd5c4d45ac391962ec2ef746
created: 2026-06-08
source_story_key: 2-4-inspect-and-zoom-tactical-information
---

# Story 2.4: Inspect and Zoom Tactical Information

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a player,
I want to zoom and inspect cells, occupants, hazards, and telegraphs,
so that tactical information stays readable on every supported device.

## Acceptance Criteria

1. Given the player tap-holds or uses inspect input on a visible or explored cell, when inspect data is requested, then the UI shows available tile, terrain, occupant, move cost, attack preview, hazard, and telegraphed danger information, and hidden unexplored facts remain hidden.
2. Given the board is displayed on phone, tablet, or desktop, when zoom controls are used, then the board scales within defined minimum and maximum limits, and selection, preview, and inspect targets remain aligned with domain cells.
3. Given the player changes zoom during a preview, when the view refreshes, then preview state remains coherent, and no command is committed by zooming.

## Tasks / Subtasks

- [x] 2.4.1 Confirm the Epic 2 boundary and add failing tests first. (AC: 1-3)
  - [x] Verify `sprint-status.yaml` has `epic-1: done`, Stories 2.1-2.3 `done`, and this story `ready-for-dev` before implementation starts.
  - [x] Confirm the working tree is clean or that any dirty files are intentional user work; preserve unrelated changes.
  - [x] Add focused failing tests such as `godot/tests/unit/ui/test_tactical_inspect_view.gd` and `godot/tests/unit/ui/test_tactical_board_zoom_state.gd` before production edits.
  - [x] Use `TacticalSnapshot.from_domain()` around inspect, zoom, and view refresh cases to prove no board, turn, RNG, pending telegraph, or event-log mutation.
  - [x] Reuse `BoardFixtureFactory.micro_combat_board()`, `enemy_turn_ash_seer_mark()`, and existing preview fixtures before adding new fixtures.
- [x] 2.4.2 Define scene-free inspect data contracts. (AC: 1)
  - [x] Add a typed `RefCounted` helper under `godot/scripts/ui/view_models/`, recommended name `tactical_inspect_view.gd`.
  - [x] Keep inspect output as copied value data only: `String`, `StringName`, `int`, `bool`, `float`, `Vector2i`, `Array`, and `Dictionary` copies.
  - [x] Do not expose `BoardState`, `BoardCell`, `TacticalEntityState`, `TacticalActionContext`, `ActionResult`, command instances, `WeaponDefinition`, `SupportDefinition`, `Resource`, `Node`, `Control`, or mutable repository internals to presenters.
  - [x] Use `TacticalVisibilityQuery.visible_facts_for_cell()` as the visibility authority for hidden, memory, and visible cell facts.
  - [x] Return stable top-level fields: `kind: "inspect"`, `available`, `reason`, `target_cell`, `visibility_state`, `authoritative`, `cell`, `occupant`, `movement`, `attack_preview`, `hazards`, `telegraphs`, `cue_ids`, and `metadata`.
  - [x] For hidden unexplored cells, return only copied target/visibility fields plus a stable reason such as `hidden_unexplored`; do not include terrain, occupant, HP, faction, hazards, telegraphs, movement path, or attack target facts.
  - [x] For explored memory cells, expose non-authoritative terrain/memory data only; do not expose current occupant, current HP, faction, or hidden attack target facts.
  - [x] For visible cells, expose current terrain and visible occupant facts using the same allowed fields as `TacticalCellView` and `TacticalOccupantView`.
- [x] 2.4.3 Reuse movement and attack preview DTOs inside inspect data. (AC: 1)
  - [x] If an actor id is supplied, build movement inspect data from `TacticalMovementPreview.from_query()` so move cost, budget, path, and invalid reasons match Story 2.2.
  - [x] If an actor id and weapon are supplied, build attack inspect data from `TacticalAttackPreview.from_query()` so range, line, blockers, expected deterministic damage, warnings, and invalid reasons match Story 2.2.
  - [x] Keep preview data unavailable with stable reasons such as `missing_actor`, `missing_weapon`, `not_visible`, or the query reason when inputs are absent or invalid.
  - [x] Do not duplicate pathfinding, line-of-sight, blocker, range, or damage-preview logic in UI scripts.
  - [x] Do not call `MoveCommand.execute()`, `AttackCommand.execute()`, `TacticalCommandBridge.execute_intent()`, enemy turn resolution, level-system advancement, or gameplay RNG during inspect.
- [x] 2.4.4 Expose telegraphed danger and current hazard placeholders without inventing a hazard system. (AC: 1)
  - [x] Read pending telegraphs from `TacticalActionContext.pending_telegraphs` or an explicit copied `pending_telegraphs` option; do not read scene markers.
  - [x] Expose only telegraphs whose target/marked cell matches the inspected cell and whose cell is visible or explored according to visibility facts.
  - [x] Preserve the current Ash Seer pending mark shape: `telegraph_id`, `kind`, `source_entity_id`, `target_entity_id`, `marked_cell`, `created_turn_number`, `due_turn_number`, `damage`, `damage_type`, and `status`, copied and presenter-safe.
  - [x] Use stable cue ids such as `telegraph_pending`, `telegraph_due`, and `danger_damage`.
  - [x] Keep `hazards` as an empty copied array or explicitly domain-backed hazard entries only. Do not create procedural hazards, affinity hazards, generation rules, or scene-owned hazard truth in this story.
- [x] 2.4.5 Define scene-free zoom and board coordinate mapping contracts. (AC: 2, 3)
  - [x] Add a typed `RefCounted` helper under `godot/scripts/ui/view_models/`, recommended name `tactical_board_zoom_state.gd` or `tactical_board_coordinate_mapper.gd`.
  - [x] Store value-only fields such as `board_width`, `board_height`, `cell_size`, `viewport_size`, `origin`, `zoom`, `min_zoom`, `max_zoom`, and optional `focused_cell`.
  - [x] Clamp zoom to defined min/max limits and expose whether clamping occurred with stable reasons such as `clamped_min`, `clamped_max`, or `valid`.
  - [x] Provide deterministic conversion helpers for `screen_to_cell`, `cell_to_screen`, and `cell_rect` using value math only. Return disabled/out-of-bounds results rather than throwing on malformed input.
  - [x] Preserve alignment after zoom: the same screen target, selected domain cell, preview target cell, and inspect target cell must map to the same `Vector2i` when zoom changes around the declared focus/anchor.
  - [x] Do not add `Camera2D`, `Control`, `CanvasLayer`, gesture recognizers, HUD scenes, layout profiles, or presentation-node state in this story.
- [x] 2.4.6 Integrate inspect and zoom output with the board view-model boundary. (AC: 1-3)
  - [x] Update `TacticalBoardViewModel.from_domain()` to accept sanitized `inspect` and `zoom`/`zoom_state` option dictionaries, or document why standalone helpers are sufficient for this story's presenter contract.
  - [x] If top-level board view-model keys change, update `godot/tests/unit/ui/test_tactical_board_view_model.gd` stable-key expectations intentionally.
  - [x] Keep `selection`, `preview`, `commit_flow`, `action_availability`, `turn`, `outcome`, and `event_log_summary` behavior backward-compatible.
  - [x] Keep confirm/cancel availability gated by Story 2.3 commit-flow metadata. Zoom and inspect must never enable command commit by themselves.
  - [x] Ensure returned inspect/zoom dictionaries are deep copies and contain no raw domain, resource, command, scene, or mutable repository references.
- [x] 2.4.7 Cover inspect, zoom, alignment, and no-mutation cases. (AC: 1-3)
  - [x] Inspect visible terrain cell exposes terrain, movement cost/preview availability, and no hidden facts.
  - [x] Inspect visible occupied enemy cell exposes occupant summary, attack preview metadata, warnings/effects, and commit availability without submitting a command.
  - [x] Inspect explored memory cell exposes non-authoritative terrain and hides current occupant/HP/faction facts.
  - [x] Inspect hidden unexplored cell hides terrain, occupants, hazards, telegraphs, movement path, and attack target facts.
  - [x] Inspect cell with an Ash Seer pending mark exposes copied telegraph danger only when the cell is visible or explored.
  - [x] Inspect dictionaries can be mutated by a test without changing cached view data or domain state.
  - [x] Zoom clamps below minimum and above maximum with stable reasons.
  - [x] Screen-to-cell and cell-to-screen mapping remains aligned for phone, tablet, and desktop-sized viewport values.
  - [x] Changing zoom while attack preview mode is active preserves the pending preview/commit-flow target and submits no command.
  - [x] Changing zoom while an inspect target is active preserves the inspect target and submits no command.
- [x] 2.4.8 Keep records and validation current. (AC: 1-3)
  - [x] Run `godot --version`.
  - [x] Run `godot --headless --path C:\Sealsworn\godot --scene res://tests/headless/test_runner.tscn --quit-after 10`.
  - [x] Run `git diff --check`.
  - [x] Update this story's Dev Agent Record, Completion Notes, File List, and Change Log with actual implementation work.
  - [x] Keep `sprint-status.yaml` synchronized with this story status.

### Review Findings

- [x] [Review][Patch] Hidden inspect still carries preview DTO internals [godot/scripts/ui/view_models/tactical_inspect_view.gd:45]
- [x] [Review][Patch] Invalid movement budgets are converted into valid inspect previews [godot/scripts/ui/view_models/tactical_inspect_view.gd:259]
- [x] [Review][Patch] Malformed zoom inputs can normalize to valid mappings [godot/scripts/ui/view_models/tactical_board_zoom_state.gd:56]

## Dev Notes

### Pre-Implementation Gate

This is the fourth Epic 2 implementation story. Story creation found:

- Current branch: `codex/epic-2`
- Baseline commit: `3753756da9130642cd5c4d45ac391962ec2ef746`
- Working tree: clean at story creation time
- `epic-1: done`
- Story 2.1: `done`
- Story 2.2: `done`
- Story 2.3: `done`
- Story 2.4: `backlog` before this file was created

Before implementing, confirm the local tree is still clean or that any dirty files are intentional user work. Preserve unrelated changes. If Story 2.1, 2.2, or 2.3 is no longer done, stop and restore that boundary before adding inspect and zoom behavior.

### Scope Boundary

This story creates scene-free inspect and zoom contracts for tactical readability. It should make inspect data and zoom/cell mapping testable without building a polished tactical HUD.

In scope:

- Inspect DTOs for visible, explored-memory, and hidden cells.
- Movement/attack preview reuse inside inspect data.
- Pending telegraph danger exposure for known visible/explored cells.
- Hazard placeholder shape only when domain-backed; no new hazard system.
- Zoom state, min/max clamping, and coordinate mapping for phone/tablet/desktop-style viewport values.
- Board view-model integration if needed to carry inspect and zoom dictionaries through the existing UI contract.
- Headless tests for visibility boundaries, no mutation, deep-copy safety, and target alignment through zoom changes.

Out of scope:

- Tactical HUD scenes, final touch/hold gesture handlers, layout profiles, orientation profile scenes, final camera nodes, final audio/VFX, animation, production art, accessibility/readability audit, settings UI, save/resume UI, generation hazards, affinity hazards, or content-authoring changes.
- Runtime AI-generated content, cloud services, multiplayer, telemetry, Godot .NET/C#, React/Vite production dependencies, or new test frameworks.

### Current Repository Baseline

Story 2.3 completed the attack preview commit flow this story must preserve:

- `TacticalAttackCommitFlow` stores scene-free attack preview mode state and submits only on same-target second tap or explicit confirm.
- `TacticalAttackCommitFlow.refresh_or_clear()` revalidates pending attack previews without command submission when the target becomes invalid.
- `TacticalActionAvailability.from_preview(preview, commit_flow)` enables attack confirm/cancel only when commit-flow metadata matches the active attack preview.
- `TacticalBoardViewModel.from_domain()` accepts `preview` and `commit_flow` dictionaries, sanitizes nested values, and clamps presenter-provided confirm/cancel overrides through flow gates.
- Changing zoom or inspect state must not call `TacticalAttackCommitFlow.confirm_attack()`, `TacticalCommandBridge.execute_intent()`, or any command execution path.

Story 2.2 preview facts this story should reuse:

- `TacticalMovementPreview.from_query()` wraps `TacticalMovementQuery.validate_target()` and exposes movement path, cost, budget, target validity, commit availability, cue ids, and stable invalid reasons.
- `TacticalAttackPreview.from_query()` wraps `AttackPreviewQuery.preview_target_cell()` and exposes weapon reach, targeting shape, distance, line cells, blocker cells/state, expected deterministic damage, warnings, effects, explanation, target validity, commit availability, cue ids, and stable invalid reasons.
- Preview DTOs are copied value data and must not mutate board, turn state, pending telegraphs, RNG streams, HP, or event logs.

Story 2.1 UI boundary facts this story should preserve:

- `TacticalBoardViewModel` builds copied presenter-facing board data from `BoardState`, optional `TacticalTurnState`, selection, preview, commit flow, action availability, outcome, and event summaries.
- `TacticalCellView.from_visibility_fact()` exposes hidden cells as position plus visibility only; memory cells as non-authoritative terrain; and visible cells as current terrain plus visible occupant id.
- `TacticalOccupantView.from_entity()` exposes visible occupant summaries with id, entity type, faction, position, HP, alive/dead state, movement blocking, and definition id.
- `TacticalCommandBridge.build_command()` supports `inspect` as metadata-only and returns no gameplay command. Existing inspect metadata is intentionally minimal: target cell, visibility fact, and selection.

### Existing Files To Reuse Or Preserve

| Path | Current State | This Story Changes | Preserve |
|---|---|---|---|
| `godot/scripts/ui/view_models/tactical_board_view_model.gd` | Builds copied board, selection, preview, commit-flow, availability, turn, outcome, and event-summary dictionaries. | Optionally add sanitized `inspect` and `zoom` slots. | Visibility boundaries, stable sorting, deep-copy safety, flow-gated confirm/cancel, no raw domain objects. |
| `godot/scripts/ui/view_models/tactical_cell_view.gd` | Converts `TacticalVisibilityQuery` facts into copied hidden/memory/visible cell views. | Reuse or mirror for inspect `cell` data. | Hidden cells expose no terrain/occupant; memory stays non-authoritative. |
| `godot/scripts/ui/view_models/tactical_occupant_view.gd` | Builds visible occupant summaries from `TacticalEntityState`. | Reuse for visible inspect occupant data. | Do not expose hidden or memory occupants. |
| `godot/scripts/ui/view_models/tactical_movement_preview.gd` | Builds movement preview DTOs from `TacticalMovementQuery`. | Reuse inside inspect movement data. | No duplicated pathfinding; no mutation. |
| `godot/scripts/ui/view_models/tactical_attack_preview.gd` | Builds attack preview DTOs from `AttackPreviewQuery`. | Reuse inside inspect attack data. | No command execution; no RNG; no hidden target leaks. |
| `godot/scripts/ui/view_models/tactical_preview_view.gd` | Shared safe copy/normalization helpers for dictionaries, arrays, `Vector2i`, and primitive values. | Reuse for inspect, telegraph, and zoom dictionaries. | Unsafe object values become `null`. |
| `godot/scripts/ui/view_models/tactical_attack_commit_flow.gd` | Scene-free attack preview/confirm/cancel state. | Reuse in zoom-refresh tests; no expected production change unless a tiny refresh helper is needed. | Zoom/inspect never submit commands or clear valid preview state by accident. |
| `godot/scripts/ui/view_models/tactical_action_availability.gd` | Derives move/attack/inspect/confirm/cancel availability from preview and commit flow. | Usually no change. If changed, keep inspect available and confirm/cancel flow-gated. | Story 2.3 stale-flow and override protections. |
| `godot/scripts/ui/command_bridge/tactical_command_bridge.gd` | Converts move/attack intents to commands; inspect returns metadata-only result. | May delegate inspect metadata to `TacticalInspectView` if that keeps bridge result value-only. | Inspect returns no command, emits no events, consumes no RNG, mutates nothing. |
| `godot/scripts/tactical/fog/tactical_visibility_query.gd` | Authoritative hidden/memory/visible fact source. | Reuse for inspect visibility rules. | Hidden and memory boundaries. |
| `godot/scripts/tactical/turns/pending_telegraph_state.gd` | Validates and applies Ash Seer pending marks as serializable dictionaries. | Reuse shape for copied telegraph inspect output. | Pending telegraph state remains domain/save truth, not scene truth. |
| `godot/scripts/save/snapshots/tactical_snapshot.gd` | Snapshot/no-mutation proof tool. | Use in tests. | Snapshot remains domain-only and scene-free. |
| `godot/tests/unit/ui/test_tactical_board_view_model.gd` | Board VM sanitation, visibility, stable keys, and no-mutation tests. | Update for inspect/zoom slots only if integrated into board VM. | Existing key expectations and boundary tests stay intentional. |
| `godot/tests/unit/ui/test_tactical_preview_view_models.gd` | Movement/attack preview contract tests. | Reuse patterns and fixtures; add inspect tests in a separate file. | Existing preview no-mutation and sanitation coverage must remain green. |
| `godot/tests/unit/ui/test_tactical_attack_commit_flow.gd` | Two-step commit/cancel and no-mutation tests. | Add or reuse zoom-refresh coverage if needed. | Confirm/cancel availability remains flow-gated. |
| `godot/tests/fixtures/tactical/board_fixture_factory.gd` | Existing movement, attack preview, enemy turn, outcome, Ash Seer, and micro-combat fixtures. | Reuse first; add small inspect/zoom fixtures only if necessary. | Deterministic setup and visibility behavior. |

### Recommended New Files

Use these names unless implementation discovers a clearer local pattern:

- `godot/scripts/ui/view_models/tactical_inspect_view.gd`
- `godot/scripts/ui/view_models/tactical_board_zoom_state.gd`
- `godot/tests/unit/ui/test_tactical_inspect_view.gd`
- `godot/tests/unit/ui/test_tactical_board_zoom_state.gd`

If one helper is clearer, combine zoom state and coordinate mapping in a single file. Keep the observable contract value-only, deterministic, and scene-free.

### Inspect Contract

Recommended inspect dictionary shape:

```gdscript
{
	"kind": "inspect",
	"available": true,
	"reason": "visible",
	"target_cell": {"x": 3, "y": 2},
	"visibility_state": "visible",
	"authoritative": true,
	"cell": {
		"position": {"x": 3, "y": 2},
		"visibility_state": "visible",
		"authoritative": true,
		"terrain": 0,
		"blocks_line_of_sight": false,
		"terrain_blocks_occupancy": false,
		"occupant_id": "enemy_iron"
	},
	"occupant": {
		"entity_id": "enemy_iron",
		"entity_type": "enemy",
		"faction": "enemy",
		"position": {"x": 3, "y": 2},
		"current_hp": 10,
		"max_hp": 10,
		"is_alive": true,
		"is_dead": false,
		"blocks_movement": true,
		"definition_id": "iron_cultist"
	},
	"movement": movement_preview_dictionary_or_disabled_summary,
	"attack_preview": attack_preview_dictionary_or_disabled_summary,
	"hazards": [],
	"telegraphs": copied_telegraph_dictionaries,
	"cue_ids": ["inspect_visible", "telegraph_pending"],
	"metadata": {}
}
```

Rules:

- `reason` should be stable lower snake case: `visible`, `memory`, `hidden_unexplored`, `out_of_bounds`, `invalid_context`, `missing_actor`, `missing_weapon`, or the reused query reason.
- `occupant` must be `{}` for hidden and memory cells.
- `movement` and `attack_preview` can use full Story 2.2 preview dictionaries or stable disabled summaries, but must not invent hidden facts.
- `telegraphs` must be copied dictionaries, not references to `context.pending_telegraphs`.
- `hazards` must stay empty until a domain-backed hazard source exists.

### Zoom Contract

Recommended zoom dictionary shape:

```gdscript
{
	"zoom": 1.0,
	"min_zoom": 0.75,
	"max_zoom": 2.0,
	"cell_size": {"x": 64.0, "y": 64.0},
	"viewport_size": {"x": 390.0, "y": 844.0},
	"origin": {"x": 0.0, "y": 0.0},
	"board_size": {"x": 6, "y": 6},
	"focused_cell": {"x": 3, "y": 2},
	"reason": "valid",
	"cue_ids": ["zoom_valid"]
}
```

Rules:

- Keep `zoom` as a scalar in the view-model contract. Later `Camera2D.zoom` can mirror it as `Vector2(zoom, zoom)` if a scene presenter chooses `Camera2D`.
- Use minimum and maximum limits from constants on the helper, not magic values scattered through tests.
- Return out-of-bounds or malformed mapping results as dictionaries with stable reasons; do not throw from UI-facing helpers.
- Do not store `Camera2D`, `Control`, `Viewport`, `CanvasItem`, `Transform2D`, or callable callbacks inside the DTO.
- If later scene code uses Godot transforms, keep transform math in presenters and feed semantic cell targets into this contract.

### Previous Story Intelligence

Story 2.3 review patches are directly relevant:

- Full-context invalidations must clear before command execution; zoom refresh must not bypass that protection.
- Confirm/cancel availability must be derived from current matching commit-flow metadata, not caller-provided optimistic flags.
- Presenter overrides cannot enable confirm/cancel without an active matching flow.
- Refreshing a changed target must report `target_changed`, not a misleading `valid` reason.
- Required invalidation cases must be covered by tests, including dead, hidden, friendly, out-of-range, blocked, wrong phase, and wrong actor paths.

For Story 2.4, the same lesson applies to inspect/zoom: no helper should trust stale preview, inspect, or zoom metadata when that would allow a command-looking state to slip past the command bridge.

### Git Intelligence

Recent commits before this story:

- `3753756 feat: implement mobile attack commit flow`
- `39f594c feat: add tactical preview presentation contracts`
- `f8cacb4 feat: implement tactical UI command bridge`
- `9ce024d Merge pull request #1 from rthunborg/codex/epic-1`
- `3bde3fb docs: add epic 2 sprint plan`

Actionable patterns:

- Epic 2 code has consistently added narrow `RefCounted` view-model helpers under `godot/scripts/ui/view_models/` with focused headless tests under `godot/tests/unit/ui/`.
- Tests are added first and use the custom test harness; do not add GUT, GdUnit, or another dependency.
- Review findings have repeatedly tightened metadata sanitation, flow gating, no-mutation assertions, and stable reason ids. Keep those as first-class test expectations.
- The headless runner auto-discovers `test_*.gd` under `godot/tests/unit` and `godot/tests/integration`; no registry edit is expected.

### Architecture Compliance

- Follow the Adaptive UI Composition Pattern: domain state/events to view model to presenter/layout profile to user intent to command bridge to command/event simulation.
- Inspect and zoom helpers are read-only presentation contracts. They are not domain state, not save snapshots, not commands, and not scene truth.
- UI presenters and scenes may observe inspect/zoom dictionaries; they cannot mutate tactical truth directly.
- Building inspect data and changing zoom must not consume gameplay RNG streams.
- Building inspect data and changing zoom must not apply events, move entities, change HP, alter pending telegraphs, change turn phase, or append event-log entries.
- Domain state remains scene-independent and authoritative.
- Successful commands, not inspect or zoom requests, emit deterministic past-tense `DomainEvent` records.
- Headless tests must run without rendering, audio, UI scenes, presentation nodes, physics raycasts, navigation nodes, or scene-tree-only state.
- Do not add cloud services, accounts, multiplayer, telemetry dependencies, Godot .NET/C#, new test frameworks, or React/Vite production dependencies.

### Library And Framework Requirements

- Required engine: Godot 4.6.3 stable standard build.
- Required language: typed GDScript.
- Use `RefCounted` for inspect and zoom view-model helpers.
- Use existing `Resource` classes only as input definitions, such as `WeaponDefinition`; never expose those resources directly in presenter-facing inspect dictionaries.
- Use `Vector2i` internally for grid coordinates and copied dictionaries for presenter-facing coordinate data.
- Use plain `Dictionary` for copied nested metadata where Godot typing would become brittle. Keep public method parameters and return values typed.
- Do not add GUT, GdUnit, or another test dependency. Use the existing custom test harness based on `godot/tests/unit/test_case.gd`.

### Latest Technical Information

Official sources checked on 2026-06-08:

- Godot's official archive lists `4.6.3-stable` dated 2026-05-20. Sealsworn remains pinned to Godot 4.6.3 stable standard build. Source: https://godotengine.org/download/archive/4.6.3-stable/
- Godot 4.6 `Camera2D.zoom` is a `Vector2`; higher values zoom in, lower values zoom out, and X/Y should generally match unless intentionally stretching the view. Story 2.4 should keep the scene-free contract scalar and let later presenters mirror it to `Vector2(zoom, zoom)`. Source: https://docs.godotengine.org/en/4.6/classes/class_camera2d.html
- Godot 4.6 viewport/canvas transform docs recommend working in canvas coordinates and show `CanvasItem.get_global_transform()` / `get_global_transform_with_canvas()` conversion paths for input mapping. Story 2.4 should keep target selection as semantic cell mapping and leave node/canvas transforms to later presenters. Source: https://docs.godotengine.org/en/4.6/tutorials/2d/2d_transforms.html
- Godot 4.6 input docs route GUI events through `Control._gui_input()` and `gui_input`, with `accept_event()` for consumption. This story should not implement hold gestures or scene input handlers, but its inspect/zoom contracts should be suitable for later touch, mouse, keyboard, and controller presenters. Source: https://docs.godotengine.org/en/4.6/tutorials/inputs/inputevent.html

### Project Structure Notes

- UI-facing inspect and zoom contracts belong under `godot/scripts/ui/view_models/`.
- Command conversion remains under `godot/scripts/ui/command_bridge/`; avoid moving inspect or zoom authority into command execution.
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
- Existing Epic 1 and Story 2.1-2.3 tests remain green.
- New inspect tests prove visible, memory, hidden, occupant, movement, attack preview, hazard placeholder, and pending telegraph cases without mutation.
- New zoom tests prove clamp bounds, coordinate mapping, viewport-size scenarios, preview-state preservation, inspect-target preservation, and no command submission.
- New tests prove returned inspect and zoom dictionaries are deep copies and contain no raw domain, resource, command, scene, or mutable repository references.
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

- [Source: `_bmad-output/planning-artifacts/epics.md` - Epic 2 and Story 2.4 acceptance criteria]
- [Source: `_bmad-output/implementation-artifacts/epic-2-sprint-plan-2026-06-07.md` - Sprint Slice 4 inspect, zoom, and layout guardrails]
- [Source: `_bmad-output/implementation-artifacts/2-3-mobile-two-step-commit-and-cancel-flow.md` - previous story boundary, review findings, and commit-flow contracts]
- [Source: `_bmad-output/implementation-artifacts/2-2-movement-and-attack-preview-presentation-contracts.md` - preview DTO contracts and no-mutation rules]
- [Source: `_bmad-output/implementation-artifacts/2-1-tactical-view-models-and-command-bridge.md` - UI boundary and inspect metadata-only behavior]
- [Source: `project-context.md` - domain ownership, file placement, testing, and no-telemetry rules]
- [Source: `_bmad-output/game-architecture.md` - Adaptive UI Composition Pattern, UI architecture, input, and zoom/inspect requirements]
- [Source: `_bmad-output/planning-artifacts/gdds/gdd-Game-2026-05-31/gdd.md` - controls/input, zoom/inspect, readability, and technical response targets]
- [Source: `godot/scripts/ui/view_models/tactical_board_view_model.gd` - current board VM sanitation and commit-flow handling]
- [Source: `godot/scripts/ui/view_models/tactical_attack_commit_flow.gd` - current attack preview mode and confirm/cancel behavior]
- [Source: `godot/scripts/ui/command_bridge/tactical_command_bridge.gd` - current inspect metadata-only bridge behavior]
- [Source: `godot/scripts/tactical/fog/tactical_visibility_query.gd` - hidden/memory/visible facts]
- [Source: `godot/scripts/tactical/turns/pending_telegraph_state.gd` - pending telegraph dictionary shape]
- [Source: Godot 4.6.3 stable archive](https://godotengine.org/download/archive/4.6.3-stable/)
- [Source: Godot 4.6 Camera2D docs](https://docs.godotengine.org/en/4.6/classes/class_camera2d.html)
- [Source: Godot 4.6 viewport/canvas transforms docs](https://docs.godotengine.org/en/4.6/tutorials/2d/2d_transforms.html)
- [Source: Godot 4.6 InputEvent docs](https://docs.godotengine.org/en/4.6/tutorials/inputs/inputevent.html)

## Dev Agent Record

### Agent Model Used

GPT-5 Codex

### Implementation Plan

- Add red inspect and zoom tests first, using existing fixture factories and `TacticalSnapshot.from_domain()` no-mutation checks.
- Implement `TacticalInspectView` as a scene-free presenter DTO that delegates visibility, movement preview, and attack preview logic to existing domain/query/view-model helpers.
- Implement `TacticalBoardZoomState` as value-only zoom, clamp, and coordinate-mapping state without scene, camera, or input-handler dependencies.
- Extend `TacticalBoardViewModel` with sanitized `inspect` and `zoom` slots while preserving existing selection, preview, commit-flow, availability, turn, outcome, and event-log behavior.

### Debug Log References

- 2026-06-08: Created Story 2.4 implementation guide from Epic 2 source requirements, Epic 2 sprint plan, root project context, game architecture, GDD controls/input requirements, Story 2.1-2.3 implementation notes, current Godot UI/query code, recent commits, and official Godot 4.6 documentation.
- 2026-06-08: Confirmed sprint gate before implementation: `epic-1: done`, Stories 2.1-2.3 `done`, and Story 2.4 `ready-for-dev`; working tree dirty files were limited to story/sprint tracking artifacts from story creation.
- 2026-06-08: Added red tests for inspect and zoom contracts; first headless run failed on missing `tactical_inspect_view.gd` and `tactical_board_zoom_state.gd` before production edits.
- 2026-06-08: Implemented scene-free inspect and zoom view-model helpers, plus sanitized `inspect` and `zoom`/`zoom_state` pass-through in `TacticalBoardViewModel`.
- 2026-06-08: Ran `godot --version` -> `4.6.3.stable.official.7d41c59c4`.
- 2026-06-08: Ran `godot --headless --path C:\Sealsworn\godot --scene res://tests/headless/test_runner.tscn --quit-after 10` -> passed.
- 2026-06-08: Ran `git diff --check` -> passed with Git line-ending normalization warnings only.
- 2026-06-08: Code review found three patch items; fixed hidden inspect disabled previews, invalid movement-budget propagation, and malformed zoom input handling.
- 2026-06-08: Reran `godot --headless --path C:\Sealsworn\godot --scene res://tests/headless/test_runner.tscn --quit-after 10` after review patches -> passed.
- 2026-06-08: Reran `git diff --check` after review patches -> passed with Git line-ending normalization warnings only.

### Completion Notes List

- Added `TacticalInspectView` to expose copied inspect data for visible, memory, and hidden cells without leaking hidden terrain, occupants, HP/faction, telegraphs, movement paths, or attack target facts.
- Reused `TacticalMovementPreview.from_query()` and `TacticalAttackPreview.from_query()` inside inspect data; inspect never executes commands, advances turns, consumes RNG, or mutates telegraphs/event logs.
- Added copied Ash Seer pending telegraph danger output for visible/explored cells and kept hazards as an empty domain-backed placeholder.
- Added `TacticalBoardZoomState` with min/max clamping, stable reasons/cues, deterministic `screen_to_cell`, `cell_to_screen`, `cell_rect`, and focus-anchored zoom alignment.
- Updated `TacticalBoardViewModel` to carry sanitized `inspect` and `zoom` dictionaries while preserving Story 2.3 commit-flow gates for confirm/cancel.
- Added headless tests covering inspect visibility boundaries, preview reuse, telegraphs, deep-copy/reference safety, zoom clamps, viewport mapping, preview/inspect preservation during zoom, and no-mutation snapshots.
- Applied review patches so hidden inspect uses disabled preview summaries without nested path/line metadata, invalid movement budgets preserve the movement query reason, and malformed/non-finite zoom inputs return disabled mapping data.

### File List

- `_bmad-output/implementation-artifacts/2-4-inspect-and-zoom-tactical-information.md`
- `_bmad-output/implementation-artifacts/sprint-status.yaml`
- `godot/scripts/ui/view_models/tactical_board_view_model.gd`
- `godot/scripts/ui/view_models/tactical_board_zoom_state.gd`
- `godot/scripts/ui/view_models/tactical_inspect_view.gd`
- `godot/tests/unit/ui/test_tactical_board_view_model.gd`
- `godot/tests/unit/ui/test_tactical_board_zoom_state.gd`
- `godot/tests/unit/ui/test_tactical_inspect_view.gd`

## Change Log

- 2026-06-08: Created Story 2.4 implementation guide and marked it ready for development.
- 2026-06-08: Implemented inspect and zoom tactical information contracts; added tests and moved story to review.
- 2026-06-08: Applied code review patches, reran validation, and moved story to done.
