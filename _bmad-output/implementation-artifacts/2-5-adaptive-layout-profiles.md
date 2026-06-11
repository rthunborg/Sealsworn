---
baseline_commit: a322c8bdbb140b590e55d7a4fd8cf09c3cd35da7
created: 2026-06-08
source_story_key: 2-5-adaptive-layout-profiles
---

# Story 2.5: Adaptive Layout Profiles

Status: ready-for-dev

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a player,
I want tactical controls to adapt to portrait, landscape, tablet, and desktop layouts,
so that the same rules remain comfortable across target devices.

## Acceptance Criteria

1. Given a phone portrait viewport is active, when the tactical HUD is displayed, then primary preview, confirm, cancel, inspect, and status controls are reachable and readable, and the board remains the first visual priority.
2. Given phone landscape, tablet, or desktop-style viewport profiles are active, when layout recalculates, then panels and controls reposition without changing tactical rules, and the same command bridge and view models are reused.
3. Given orientation or viewport size changes during play, when the layout profile changes, then current selection and preview state persist, and no gameplay command is submitted by the layout change.

## Tasks / Subtasks

- [ ] 2.5.1 Confirm the Epic 2 boundary and add failing tests first. (AC: 1-3)
  - [ ] Verify `sprint-status.yaml` has `epic-1: done`, Stories 2.1-2.4 `done`, and this story `ready-for-dev` before implementation starts.
  - [ ] Confirm the working tree is clean or that dirty files are intentional user work; preserve unrelated changes.
  - [ ] Add focused failing tests such as `godot/tests/unit/ui/test_tactical_layout_profiles.gd` before production edits.
  - [ ] Use `BoardFixtureFactory.micro_combat_board()`, current preview/commit-flow/inspect/zoom helpers, and `TacticalSnapshot.from_domain()` for no-mutation assertions.
  - [ ] Do not add final art, final audio, production UI frames, settings UI, save/resume UI, or accessibility-audit UI in this story.
- [ ] 2.5.2 Define a scene-free adaptive layout profile contract. (AC: 1, 2)
  - [ ] Add a typed `RefCounted` helper under `godot/scripts/ui/view_models/`, recommended name `tactical_layout_profile.gd`.
  - [ ] Add a resolver/helper if useful, recommended name `tactical_layout_profile_resolver.gd`, or keep resolver methods on the main layout helper if that is clearer.
  - [ ] Keep output value-only: `String`, `StringName`, `int`, `bool`, `float`, `Vector2`, `Vector2i`, `Rect2i`, `Array`, and `Dictionary` copies.
  - [ ] Presenter-facing dictionaries must normalize coordinates/rects to copied dictionaries; do not expose `BoardState`, command objects, `ActionResult`, `Resource`, `Node`, `Control`, `Window`, `Viewport`, `DisplayServer`, callables, or mutable repository internals.
  - [ ] Return stable profile ids: `phone_portrait`, `phone_landscape`, `tablet`, and `desktop`.
  - [ ] Return stable orientation ids: `portrait`, `landscape`, and `square` if width and height are equal.
- [ ] 2.5.3 Implement deterministic profile selection for v0 target viewports. (AC: 1, 2)
  - [ ] Accept injected `viewport_size`, optional `safe_area`, optional `content_scale`, and optional `platform_hint`; tests must not depend on an actual rendered window.
  - [ ] Recommended v0 classification constants:
    - `phone_portrait`: width < 700 and height >= width.
    - `phone_landscape`: height < 700 and width > height.
    - `desktop`: width >= 1280 and width >= height.
    - `tablet`: all remaining valid tablet-like sizes, especially min dimension >= 700.
  - [ ] Cover fixtures for at least `390x844`, `844x390`, `834x1194`, `1194x834`, and `1440x900`.
  - [ ] Return disabled or fallback profile data with stable reasons for zero, negative, NaN, infinity, or malformed viewport/safe-area values.
  - [ ] Keep thresholds as named constants so later device-tier work can tune them without rewriting tests.
- [ ] 2.5.4 Produce a semantic tactical HUD layout plan for each profile. (AC: 1, 2)
  - [ ] Layout output should include copied regions for `board`, `preview`, `confirm_cancel`, `inspect`, `status`, and `log_or_outcome`.
  - [ ] Phone portrait should prioritize the board as the largest first visual region, with bottom or lower-edge reachable preview/confirm/cancel controls and compact status.
  - [ ] Phone landscape should keep the board central or left-prioritized and move panels/controls to side regions where possible.
  - [ ] Tablet should support a larger board plus side or bottom panels without forcing desktop-only density.
  - [ ] Desktop should use wider space for panels/status/log while reusing the same `TacticalBoardViewModel`, `TacticalCommandBridge`, preview, commit-flow, inspect, and zoom contracts.
  - [ ] Expose `minimum_touch_target` and `spacing` values for control reachability checks. Use conservative constants, not final accessibility settings; Story 2.6 owns the broader readable-text and colorblind audit.
  - [ ] Ensure the plan includes cue ids or reason ids such as `layout_profile_phone_portrait`, `layout_safe_area_applied`, and `layout_fallback`.
- [ ] 2.5.5 Integrate layout data with existing UI view-model output without creating scene-owned gameplay state. (AC: 2, 3)
  - [ ] Prefer adding a sanitized optional `layout` slot to `TacticalBoardViewModel.from_domain()` so presenters can consume board, preview, commit-flow, inspect, zoom, and layout data together.
  - [ ] If the implementation keeps layout separate from `TacticalBoardViewModel`, document that decision in this story and add tests proving presenters still receive the same state contracts.
  - [ ] If top-level board view-model keys change, update `godot/tests/unit/ui/test_tactical_board_view_model.gd` stable-key expectations intentionally.
  - [ ] Keep `selection`, `preview`, `commit_flow`, `inspect`, `zoom`, `action_availability`, `turn`, `outcome`, and `event_log_summary` behavior backward-compatible.
  - [ ] Layout recalculation must not call `TacticalCommandBridge.execute_intent()`, `MoveCommand.execute()`, `AttackCommand.execute()`, `TacticalAttackCommitFlow.confirm_attack()`, enemy turn resolution, level-system advancement, or gameplay RNG.
- [ ] 2.5.6 Preserve current tactical UI state across profile changes. (AC: 3)
  - [ ] Build tests that start with selected cell/entity, active movement preview, active attack preview/commit flow, active inspect target, and zoom focused cell.
  - [ ] Rebuild layout from portrait to landscape, portrait to tablet, and desktop to phone-sized values without mutating board, turn state, RNG streams, pending telegraphs, or event log.
  - [ ] Assert selected cell/entity, preview target, attack commit-flow target, inspect target, zoom focused cell, and action availability remain coherent after layout/profile changes.
  - [ ] Assert attack confirm/cancel remain gated by active matching commit-flow metadata from Story 2.3, not by layout profile or presenter overrides.
  - [ ] Assert layout changes never submit commands and never advance enemies or level systems.
- [ ] 2.5.7 Add minimal scene/presenter hooks only if needed to prove layout profile consumption. (AC: 1, 2)
  - [ ] If scene-level proof is useful, add a lightweight presenter script under `godot/scripts/ui/presenters/` that binds semantic layout regions to existing `Control` containers without tactical state ownership.
  - [ ] If layout scenes are added, place them under `godot/scenes/ui/layouts/phone_portrait/`, `phone_landscape/`, `tablet/`, and `desktop/` as architecture-defined profile locations.
  - [ ] Any scene or presenter added here must consume view-model/layout dictionaries and emit semantic intent only; it must not own board state, selection truth, preview legality, attack commit rules, or command execution.
  - [ ] Do not build polished HUD art or final visual style. Placeholder controls are acceptable only to prove region reachability and state binding.
- [ ] 2.5.8 Cover layout profiles, state preservation, and no-mutation behavior. (AC: 1-3)
  - [ ] Profile resolver returns `phone_portrait` for a `390x844` viewport and keeps board first-priority.
  - [ ] Profile resolver returns `phone_landscape` for a `844x390` viewport and repositions panels/controls without changing view-model or bridge contracts.
  - [ ] Profile resolver returns `tablet` for tablet portrait/landscape fixtures and `desktop` for a desktop-style wide fixture.
  - [ ] Safe-area input shrinks the interactive content area and keeps primary controls inside it.
  - [ ] Malformed viewport, safe area, or content scale values return stable fallback/disabled reasons rather than throwing.
  - [ ] Returned layout dictionaries are deep copies and contain no forbidden raw domain, resource, command, scene, window, viewport, or callable references.
  - [ ] Layout changes preserve active selection, preview, commit flow, inspect, zoom, action availability, and no-mutation snapshots.
- [ ] 2.5.9 Keep records and validation current. (AC: 1-3)
  - [ ] Run `godot --version`.
  - [ ] Run `godot --headless --path C:\Sealsworn\godot --scene res://tests/headless/test_runner.tscn --quit-after 10`.
  - [ ] Run `git diff --check`.
  - [ ] Update this story's Dev Agent Record, Completion Notes, File List, and Change Log with actual implementation work.
  - [ ] Keep `sprint-status.yaml` synchronized with this story status.

## Dev Notes

### Pre-Implementation Gate

This is the fifth Epic 2 implementation story. Story creation found:

- Baseline commit: `a322c8bdbb140b590e55d7a4fd8cf09c3cd35da7`
- Working tree: clean at story creation time
- `epic-1: done`
- Story 2.1: `done`
- Story 2.2: `done`
- Story 2.3: `done`
- Story 2.4: `done`
- Story 2.5: `backlog` before this file was created

Before implementing, confirm the local tree is still clean or that dirty files are intentional user work. If any Story 2.1-2.4 status has regressed, stop and restore that boundary before adding layout profiles.

### Scope Boundary

This story defines adaptive layout profiles and a semantic tactical HUD layout plan. It should make profile changes testable and reusable before polished UI scenes grow around the tactical slice.

In scope:

- Deterministic profile selection for phone portrait, phone landscape, tablet, and desktop-style viewports.
- Value-only layout dictionaries for board, preview, confirm/cancel, inspect, status, and log/outcome regions.
- Safe-area-aware content region calculation from injected values.
- Optional sanitized `layout` slot on `TacticalBoardViewModel`.
- Tests proving layout/profile changes preserve selection, preview, commit flow, inspect, zoom, and action availability without commands or mutation.
- Minimal presenter/scene hooks only if needed to prove consumption of layout profiles.

Out of scope:

- Final tactical HUD art, icons, animations, VFX, SFX, production UI frames, final theme, and final touch gesture mapping.
- Broad accessibility/readability audit, scalable text settings, colorblind-safe indicator audit, or non-color-only pattern pass. Story 2.6 owns those.
- Save/resume UI or persistence. Stories 2.7 and 2.8 own save/resume.
- Settings expansion or difficulty preferences. Story 2.9 owns settings guardrails.
- Runtime AI-generated content, cloud services, multiplayer, telemetry, Godot .NET/C#, React/Vite production dependencies, or new test frameworks.

### Current Repository Baseline

Story 2.4 completed the inspect and zoom tactical information contracts this story must preserve:

- `TacticalBoardViewModel` now returns stable top-level keys: `width`, `height`, `cells`, `occupants`, `selected_cell`, `selected_entity_id`, `preview`, `commit_flow`, `inspect`, `zoom`, `action_availability`, `turn`, `outcome`, and `event_log_summary`.
- `TacticalBoardViewModel.from_domain()` sanitizes presenter-facing `preview`, `commit_flow`, `inspect`, and `zoom` dictionaries and strips raw domain/scene objects.
- `TacticalBoardZoomState` provides scene-free zoom, min/max clamping, screen/cell mapping, `cell_rect()`, and focus-anchored `with_zoom()` behavior.
- `TacticalInspectView` exposes copied inspect data for visible, memory, and hidden cells while preserving hidden-fact boundaries.
- `TacticalAttackCommitFlow` owns scene-free attack preview/confirm/cancel flow state. Confirm/cancel availability is valid only when active flow metadata matches the active attack preview.
- `TacticalActionAvailability.from_preview(preview, commit_flow)` gates attack confirm/cancel through matching commit-flow metadata and keeps inspect available.
- `TacticalCommandBridge` converts semantic move/attack/inspect intents. Inspect is metadata-only; move/attack mutation occurs only through typed command execution.
- Existing UI production code is still light. `godot/scripts/ui/presenters/boot_controller.gd` is a bootstrap `Control` script and should not become tactical state authority.

### Existing Files To Reuse Or Preserve

| Path | Current State | This Story Changes | Preserve |
|---|---|---|---|
| `godot/scripts/ui/view_models/tactical_board_view_model.gd` | Main copied board/view-model contract with preview, commit-flow, inspect, zoom, availability, turn, outcome, and event-log slots. | Prefer adding a sanitized optional `layout` slot, or document why layout remains separate. | Stable visibility boundaries, no raw objects, commit-flow gating, deep-copy behavior, deterministic sorting. |
| `godot/scripts/ui/view_models/tactical_board_zoom_state.gd` | Scene-free zoom and coordinate mapping for board cells. | Reuse for board region/focused-cell tests; do not duplicate screen-to-cell rules in layout code. | Zoom changes do not submit commands, mutate domain state, or clear valid preview/inspect targets. |
| `godot/scripts/ui/view_models/tactical_attack_commit_flow.gd` | Scene-free attack preview mode, confirm, cancel, target switch, and invalidation logic. | Reuse state dictionaries in profile-change preservation tests. | Same-target/confirm commit remains the only default attack commit path. |
| `godot/scripts/ui/view_models/tactical_action_availability.gd` | Derives move/attack/inspect/confirm/cancel availability from preview plus commit flow. | Usually no change except tests if layout is passed through board VM. | Layout must not enable confirm/cancel or bypass stale-flow protections. |
| `godot/scripts/ui/view_models/tactical_inspect_view.gd` | Scene-free inspect data for visible, memory, hidden, telegraphs, movement, attack preview, and hazard placeholders. | Reuse inspect target dictionaries in profile-change tests. | Hidden/current fact boundaries and no mutation. |
| `godot/scripts/ui/view_models/tactical_movement_preview.gd` | Scene-free movement preview DTO. | Reuse in state preservation tests. | No duplicated pathfinding or mutation. |
| `godot/scripts/ui/view_models/tactical_attack_preview.gd` | Scene-free attack preview DTO. | Reuse in state preservation tests. | No command execution or gameplay RNG. |
| `godot/scripts/ui/view_models/tactical_preview_view.gd` | Shared safe copy and normalization helpers. | Reuse for layout dictionary sanitization where practical. | Unsafe object values become `null`; `Vector2i` becomes coordinate dictionaries. |
| `godot/scripts/ui/command_bridge/tactical_command_bridge.gd` | Converts semantic UI intents to typed commands or metadata-only inspect. | No expected change. Tests should prove layout recalculation never calls execution. | Command bridge remains the only UI-to-command boundary. |
| `godot/scripts/ui/presenters/boot_controller.gd` | Simple bootstrap `Control` presenter. | Usually no change. If used, keep it as bootstrap only. | No tactical state ownership. |
| `godot/tests/unit/ui/test_tactical_board_view_model.gd` | Stable keys, sanitation, visibility, and no-mutation tests. | Update intentionally if `layout` is added to board VM. | Existing behavior remains green. |
| `godot/tests/unit/ui/test_tactical_board_zoom_state.gd` | Zoom clamp, mapping, focus, inspect/preview preservation, no-mutation tests. | Reuse patterns and fixtures for profile-change tests. | Existing zoom semantics remain green. |
| `godot/tests/unit/ui/test_tactical_attack_commit_flow.gd` | Two-step attack commit, cancel, target switch, invalidation, and flow-gating tests. | Reuse active flow setup for layout-change tests. | Stale flow must not become confirmable after layout changes. |
| `godot/tests/fixtures/tactical/board_fixture_factory.gd` | Tactical fixtures for micro-combat, movement, previews, enemy turns, outcomes, and Ash Seer cases. | Reuse first; add fixtures only if necessary. | Deterministic setup and existing tests. |

### Recommended New Files

Use these names unless implementation discovers a clearer local pattern:

- `godot/scripts/ui/view_models/tactical_layout_profile.gd`
- `godot/scripts/ui/view_models/tactical_layout_profile_resolver.gd` if resolver logic is clearer as a separate helper
- `godot/tests/unit/ui/test_tactical_layout_profiles.gd`

Optional only if scene-level proof is needed:

- `godot/scripts/ui/presenters/tactical_layout_profile_presenter.gd`
- `godot/scenes/ui/layouts/phone_portrait/`
- `godot/scenes/ui/layouts/phone_landscape/`
- `godot/scenes/ui/layouts/tablet/`
- `godot/scenes/ui/layouts/desktop/`

Avoid adding a new dependency, plugin, autoload, save format, theme system, or settings subsystem for this story.

### Layout Profile Contract

Recommended profile dictionary shape:

```gdscript
{
	"kind": "layout_profile",
	"profile_id": "phone_portrait",
	"orientation": "portrait",
	"viewport_size": {"x": 390.0, "y": 844.0},
	"safe_area": {"x": 0, "y": 0, "width": 390, "height": 844},
	"content_area": {"x": 0, "y": 0, "width": 390, "height": 844},
	"board_priority": "primary",
	"regions": {
		"board": {"x": 0, "y": 0, "width": 390, "height": 520},
		"preview": {"x": 0, "y": 520, "width": 390, "height": 112},
		"confirm_cancel": {"x": 0, "y": 632, "width": 390, "height": 96},
		"inspect": {"x": 0, "y": 728, "width": 390, "height": 72},
		"status": {"x": 0, "y": 800, "width": 390, "height": 44},
		"log_or_outcome": {"x": 0, "y": 0, "width": 0, "height": 0}
	},
	"control_slots": {
		"preview": {"region": "preview", "reachable": true},
		"confirm": {"region": "confirm_cancel", "reachable": true},
		"cancel": {"region": "confirm_cancel", "reachable": true},
		"inspect": {"region": "inspect", "reachable": true},
		"status": {"region": "status", "reachable": true}
	},
	"minimum_touch_target": {"x": 44.0, "y": 44.0},
	"spacing": 8.0,
	"density": "compact",
	"reason": "valid",
	"cue_ids": ["layout_profile_phone_portrait", "layout_safe_area_applied"]
}
```

Rules:

- `profile_id`, `orientation`, `reason`, `density`, region names, and cue ids must be stable lower snake case strings.
- `regions.board` must be the largest first-priority region in `phone_portrait`.
- All primary controls must have a named slot and a region inside `content_area`.
- `safe_area` and `content_area` should be derived from injected values in tests. Actual `DisplayServer` calls belong to presenters or platform glue, not to headless-only helper tests.
- Invalid geometry should return a stable fallback such as `profile_id: "phone_portrait"`, `reason: "fallback_invalid_viewport"`, and `available: false`, or an explicit disabled result. Pick one shape and test it consistently.
- Layout dictionaries are presentation contracts, not save truth and not domain state.

### State Preservation Contract

Layout changes may rebuild layout dictionaries and may rebuild `TacticalBoardViewModel` copies. They must not mutate or replace tactical truth.

Preserve across profile changes:

- `selected_cell`
- `selected_entity_id`
- active movement preview target/path metadata
- active attack preview target and `target_entity_id`
- active `commit_flow` target, weapon id, confirm/cancel gating, and stale-flow protections
- active inspect `target_cell`
- active zoom focused cell and semantic board cell mapping
- `turn` state
- `outcome`
- `event_log_summary`

Never do these during layout/profile recalculation:

- Execute move or attack commands.
- Confirm or cancel attack commit flow unless a user intent says so.
- Resolve enemy turns or level systems.
- Consume gameplay RNG streams.
- Change board visibility, occupants, HP, pending telegraphs, turn phase, event log, save snapshots, rewards, or progression.

### Previous Story Intelligence

Story 2.4 review findings are directly relevant:

- Hidden inspect must not carry nested preview internals. Layout must not make hidden data reachable by moving panels.
- Invalid movement budgets and malformed zoom inputs must preserve concrete reason ids. Layout should follow the same rule for malformed viewports and safe areas.
- Zoom changes preserve preview/inspect targets without command submission. Layout/profile changes must do the same.

Story 2.3 review findings are also relevant:

- Full-context invalidations must clear before command execution.
- Confirm/cancel availability must be derived from current matching commit-flow metadata.
- Presenter overrides cannot enable confirm/cancel without active matching flow.
- Stale target changes need concrete reason ids such as `target_changed`, not misleading `valid`.

The implementation lesson: layout is allowed to reposition controls, but it must not reinterpret tactical legality or trust stale presentation metadata.

### Git Intelligence

Recent commits before this story:

- `a322c8b feat: implement inspect and zoom tactical information`
- `3753756 feat: implement mobile attack commit flow`
- `39f594c feat: add tactical preview presentation contracts`
- `f8cacb4 feat: implement tactical UI command bridge`
- `9ce024d Merge pull request #1 from rthunborg/codex/epic-1`

Actionable patterns:

- Epic 2 code has consistently added narrow typed `RefCounted` UI helpers under `godot/scripts/ui/view_models/`.
- Tests are added first under `godot/tests/unit/ui/` and run through the existing custom headless test harness. Do not add GUT, GdUnit, or another dependency.
- Review findings have repeatedly tightened value sanitization, no-mutation assertions, stable reason ids, and flow gating. Treat these as first-class tests for layout profiles.
- The headless runner auto-discovers `test_*.gd` under `godot/tests/unit` and `godot/tests/integration`; no registry edit is expected.

### Architecture Compliance

- Follow the Adaptive UI Composition Pattern: domain state/events -> view model -> presenter/layout profile -> user intent -> command bridge -> command/event simulation.
- Layout profiles are presentation contracts. They are not domain state, commands, save snapshots, tactical legality, or scene truth.
- Device-specific layout scenes are allowed only if they reuse the same state contracts, view models, and command bridge.
- UI presenters and scenes may observe domain state and submit semantic intent; they cannot mutate tactical truth directly.
- Domain state remains scene-independent and authoritative.
- Successful commands, not layout changes, emit deterministic past-tense `DomainEvent` records.
- Layout/profile changes must not consume gameplay RNG streams.
- Headless tests must run without rendering, audio, UI scenes, presentation nodes, physics raycasts, navigation nodes, or scene-tree-only state unless a separate optional scene-level check is explicitly added.
- Do not add cloud services, accounts, multiplayer, telemetry dependencies, Godot .NET/C#, new test frameworks, or React/Vite production dependencies.

### Library And Framework Requirements

- Required engine: Godot 4.6.3 stable standard build.
- Required language: typed GDScript.
- Use `RefCounted` for layout resolver/value helpers.
- Use `Control`/container scripts only for optional presenter/scene proof; never make them authoritative for tactical state.
- Use `Vector2`, `Vector2i`, and `Rect2i` internally for geometry and copied dictionaries for presenter-facing output.
- Use existing preview, inspect, zoom, board view-model, action availability, and command bridge helpers instead of duplicating tactical query or command logic.
- Use the existing custom headless test harness based on `godot/tests/unit/test_case.gd`.

### Latest Technical Information

Official Godot 4.6 sources checked on 2026-06-08:

- Godot's UI size/anchors documentation describes `Control` anchors and offsets as the basis for controls that move or resize with their parent or viewport. This supports later presenter/scene work, but Story 2.5 should keep tactical layout decisions in a testable semantic profile first. Source: https://docs.godotengine.org/en/4.6/tutorials/ui/size_and_anchors.html
- Godot's `Node.NOTIFICATION_WM_SIZE_CHANGED` is sent when a window is resized, but only the resized `Window` node receives it and it is not propagated to children. Presenter glue should explicitly observe window/viewport changes and rebuild the layout profile; the layout helper should remain scene-free. Source: https://docs.godotengine.org/en/4.6/classes/class_node.html
- Godot's `DisplayServer.get_display_safe_area()` returns the unobscured area where interactive controls should be rendered, is implemented on Android/iOS, and falls back to `screen_get_usable_rect()` elsewhere. Tests should inject safe-area values rather than depending on platform display state. Source: https://docs.godotengine.org/en/4.6/classes/class_displayserver.html
- Godot viewport/canvas transform docs note that the stretch transform participates in resizing/stretching and affects input event coordinates. Story 2.5 should preserve semantic board-cell targets and reuse `TacticalBoardZoomState` for board mapping rather than baking canvas transforms into layout profiles. Source: https://docs.godotengine.org/en/4.6/tutorials/2d/2d_transforms.html
- Godot multiple-resolution docs describe stretch scale and `Window.content_scale_factor`. This can inform future user-facing UI scaling, but Story 2.5 should not create settings or gameplay rule changes from content scale. Source: https://docs.godotengine.org/en/4.6/tutorials/rendering/multiple_resolutions.html

### Project Structure Notes

- UI-facing layout contracts belong under `godot/scripts/ui/view_models/`.
- Optional presenter scripts belong under `godot/scripts/ui/presenters/`.
- Optional layout scenes belong under `godot/scenes/ui/layouts/phone_portrait/`, `phone_landscape/`, `tablet/`, and `desktop/`.
- Command conversion remains under `godot/scripts/ui/command_bridge/`; avoid moving layout authority into command execution.
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
- Existing Epic 1 and Story 2.1-2.4 tests remain green.
- New layout tests prove profile selection for phone portrait, phone landscape, tablet, and desktop fixtures.
- New layout tests prove safe-area handling keeps primary controls inside the content area.
- New layout tests prove malformed geometry returns stable fallback/disabled reasons.
- New state-preservation tests prove selection, preview, commit flow, inspect, zoom, and action availability survive layout/profile changes.
- New no-mutation tests prove layout recalculation does not mutate board, turn state, RNG streams, pending telegraphs, outcome, or event log and does not execute commands.
- New sanitation tests prove layout dictionaries are deep copies and contain no raw domain, resource, command, scene, window, viewport, display server, or callable references.
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

- [Source: `_bmad-output/planning-artifacts/epics.md` - Epic 2 and Story 2.5 acceptance criteria]
- [Source: `_bmad-output/implementation-artifacts/epic-2-sprint-plan-2026-06-07.md` - Sprint Slice 4 inspect, zoom, and layout profile guardrails]
- [Source: `_bmad-output/implementation-artifacts/2-4-inspect-and-zoom-tactical-information.md` - previous story boundary, zoom/inspect contracts, review findings, and files]
- [Source: `_bmad-output/implementation-artifacts/2-3-mobile-two-step-commit-and-cancel-flow.md` - commit-flow state, confirm/cancel gating, and review findings]
- [Source: `_bmad-output/implementation-artifacts/2-2-movement-and-attack-preview-presentation-contracts.md` - preview DTO contracts and no-mutation rules]
- [Source: `_bmad-output/implementation-artifacts/2-1-tactical-view-models-and-command-bridge.md` - UI boundary and command bridge behavior]
- [Source: `project-context.md` - domain ownership, file placement, testing, and no-telemetry rules]
- [Source: `_bmad-output/game-architecture.md` - UI Architecture, Adaptive UI Composition Pattern, project structure, and architectural boundaries]
- [Source: `_bmad-output/planning-artifacts/gdds/gdd-Game-2026-05-31/gdd.md` - platform-specific portrait/landscape/tablet/desktop layout requirements]
- [Source: `godot/scripts/ui/view_models/tactical_board_view_model.gd` - current board VM sanitation and top-level contract]
- [Source: `godot/scripts/ui/view_models/tactical_board_zoom_state.gd` - current zoom and coordinate mapping contract]
- [Source: `godot/scripts/ui/view_models/tactical_attack_commit_flow.gd` - current attack preview mode and confirm/cancel behavior]
- [Source: `godot/scripts/ui/view_models/tactical_action_availability.gd` - current flow-gated action availability]
- [Source: `godot/scripts/ui/command_bridge/tactical_command_bridge.gd` - current command conversion and inspect metadata-only behavior]
- [Source: Godot 4.6 size and anchors docs](https://docs.godotengine.org/en/4.6/tutorials/ui/size_and_anchors.html)
- [Source: Godot 4.6 Node notifications docs](https://docs.godotengine.org/en/4.6/classes/class_node.html)
- [Source: Godot 4.6 DisplayServer docs](https://docs.godotengine.org/en/4.6/classes/class_displayserver.html)
- [Source: Godot 4.6 viewport/canvas transforms docs](https://docs.godotengine.org/en/4.6/tutorials/2d/2d_transforms.html)
- [Source: Godot 4.6 multiple resolutions docs](https://docs.godotengine.org/en/4.6/tutorials/rendering/multiple_resolutions.html)

## Dev Agent Record

### Agent Model Used

GPT-5 Codex

### Implementation Plan

- Add red layout profile tests first for profile classification, safe-area handling, semantic region generation, no forbidden references, state preservation, and no command submission.
- Implement a narrow scene-free layout profile helper under `godot/scripts/ui/view_models/` using injected viewport/safe-area values.
- Add an optional sanitized layout slot to `TacticalBoardViewModel` only if it improves presenter consumption; otherwise keep the layout helper separate and document the boundary.
- Reuse existing preview, commit-flow, inspect, zoom, action availability, and command bridge contracts without moving tactical legality or command execution into layout code.

### Debug Log References

- 2026-06-08: Created Story 2.5 implementation guide from Epic 2 source requirements, Epic 2 sprint plan, root project context, game architecture, GDD platform-specific requirements, Stories 2.1-2.4 implementation notes, current UI/view-model code, recent commits, and official Godot 4.6 documentation.
- 2026-06-08: Confirmed story creation baseline: `epic-1: done`, Stories 2.1-2.4 `done`, Story 2.5 `backlog`, and a clean working tree before story artifact edits.

### Completion Notes List

- Story context created and marked ready for development.
- Ultimate context engine analysis completed - comprehensive developer guide created.

### File List

- `_bmad-output/implementation-artifacts/2-5-adaptive-layout-profiles.md`
- `_bmad-output/implementation-artifacts/sprint-status.yaml`

## Change Log

- 2026-06-08: Created Story 2.5 implementation guide and marked it ready for development.
