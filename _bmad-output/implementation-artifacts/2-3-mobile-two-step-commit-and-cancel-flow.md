---
baseline_commit: 39f594c1e577da0ab3cacba6ab6b9e7d82801ca2
created: 2026-06-08
source_story_key: 2-3-mobile-two-step-commit-and-cancel-flow
---

# Story 2.3: Mobile Two-Step Commit and Cancel Flow

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a mobile player,
I want attacks to require deliberate confirmation by default,
so that mis-taps do not accidentally advance enemies and level systems.

## Acceptance Criteria

1. Given the player taps a visible enemy for the first time, when attack preview is available, then the UI enters attack preview mode and no attack command is submitted yet.
2. Given the same target is tapped again or a clear confirm action is pressed, when the preview remains valid, then an `AttackCommand` is submitted through the command bridge and enemy and level systems advance only after command success.
3. Given the player taps a different tile, presses cancel, or the target becomes invalid, when the preview mode is cleared, then no attack command is submitted and tactical state remains unchanged.

## Tasks / Subtasks

- [x] 2.3.1 Confirm the Epic 2 boundary and add failing tests first. (AC: 1-3)
  - [x] Verify `sprint-status.yaml` has `epic-1: done`, Stories 2.1 and 2.2 `done`, and this story `ready-for-dev` before implementation starts.
  - [x] Confirm the working tree is clean or that any dirty files are intentional user work; preserve unrelated changes.
  - [x] Add a focused test file such as `godot/tests/unit/ui/test_tactical_attack_commit_flow.gd` before implementation.
  - [x] Use `TacticalSnapshot.from_domain()` around every first-tap preview, cancel, target switch, and invalidation case to prove no board, turn, RNG, pending telegraph, or event-log mutation.
  - [x] Reuse `BoardFixtureFactory.micro_combat_board()` and existing attack preview fixtures before adding new fixtures.
- [x] 2.3.2 Define a scene-free attack commit flow state contract. (AC: 1, 3)
  - [x] Add a narrow typed GDScript `RefCounted` helper under `godot/scripts/ui/view_models/`, such as `tactical_attack_commit_flow.gd` or `tactical_commit_flow_state.gd`.
  - [x] Keep the flow state as copied value data only: `String`, `StringName`, `int`, `bool`, `float`, `Vector2i`, `Array`, and `Dictionary` copies.
  - [x] Do not expose `BoardState`, `TacticalActionContext`, `TacticalEntityState`, `ActionResult`, command instances, `WeaponDefinition`, `SupportDefinition`, `Resource`, `Node`, or `Control` in presenter-facing dictionaries.
  - [x] Represent mode explicitly, for example `mode: "none"` or `mode: "attack_preview"`.
  - [x] Track enough value metadata to recognize the pending attack preview: `actor_id`, `target_cell`, `target_entity_id`, `weapon_id`, `preview`, `confirm_available`, `cancel_available`, and stable `reason` or `cue_ids`.
  - [x] Provide `to_dictionary()` or equivalent stable output with deep-copied nested arrays/dictionaries.
- [x] 2.3.3 Implement first-target tap as preview-only behavior. (AC: 1)
  - [x] On the first visible enemy tap, build the attack preview by reusing `TacticalAttackPreview.from_query()` and the existing `AttackPreviewQuery` path.
  - [x] Enter attack preview mode only when the preview target is available and commit-capable.
  - [x] Do not call `TacticalCommandBridge.execute_intent()`, `AttackCommand.execute()`, enemy turn resolution, level-system advancement, or gameplay RNG during first-tap preview.
  - [x] Return action availability where confirm is available only for a valid pending attack preview and cancel is available while attack preview mode is active.
  - [x] Preserve Story 2.2 preview fields, cue ids, warnings, blocker state, expected deterministic damage, and invalid reasons.
- [x] 2.3.4 Implement same-target second tap and explicit confirm as the only default attack commit paths. (AC: 2)
  - [x] When attack preview mode is active, detect a same-target second tap by matching current actor, target cell, target entity id, and weapon id.
  - [x] Revalidate the preview immediately before command submission; if it is no longer valid, clear or downgrade the preview without submitting a command.
  - [x] Submit committed attacks through `TacticalCommandBridge.execute_intent(context, intent)` or through the bridge's existing build-then-execute path.
  - [x] Preserve command bridge semantics: validation/conversion can be inspected without mutation, and mutation occurs only through typed command execution.
  - [x] Ensure successful commit returns or exposes the `ActionResult` needed by the caller to advance enemy and level systems.
  - [x] Add a test that pairs a successful committed attack result with `EnemyTurnResolver.resolve_after_player_action()` and proves enemy advancement occurs only after the successful command result.
  - [x] Add a negative test where a failed or unavailable command result does not advance enemies or level systems.
- [x] 2.3.5 Implement cancel, target switch, mode switch, and invalidation clearing. (AC: 3)
  - [x] A cancel action clears attack preview mode and returns no command result.
  - [x] Tapping a different attackable enemy starts a fresh attack preview or replaces the pending preview without submitting the previous attack.
  - [x] Tapping a different non-attack tile, selecting movement/inspect mode, or changing actor/mode clears attack preview mode without submitting an attack.
  - [x] If the pending target becomes dead, hidden, friendly, out of range, blocked, wrong-phase, wrong-actor, or otherwise invalid, clear the pending commit path and keep command submission unavailable.
  - [x] Ensure clearing preview mode leaves tactical board state, turn state, RNG streams, pending telegraphs, and event log unchanged.
- [x] 2.3.6 Integrate with board view-model action availability without taking tactical truth into UI scenes. (AC: 1-3)
  - [x] Update `TacticalActionAvailability.from_preview()` or add a flow-aware companion so cancel is available in pending attack preview mode and unavailable outside it.
  - [x] Keep confirm availability tied to `commit_available` plus active pending preview mode, not merely any attack-looking dictionary.
  - [x] Keep `TacticalBoardViewModel` presenter output sanitized and copied if it receives the new commit-flow state or preview-mode metadata.
  - [x] Do not add tactical HUD scenes, touch gesture handlers, mobile layout profiles, final audio/VFX, or production art in this story.
  - [x] Keep desktop parity possible by modeling the flow as semantic intents, not by binding logic directly to touch-only event classes.
- [x] 2.3.7 Cover the required two-step, cancel, and no-mutation cases. (AC: 1-3)
  - [x] First tap on visible valid enemy enters attack preview mode, exposes confirm/cancel availability, and submits no command.
  - [x] Same-target second tap submits exactly one `AttackCommand` through the command bridge.
  - [x] Explicit confirm submits exactly one `AttackCommand` through the command bridge.
  - [x] Cancel clears the pending preview and submits no command.
  - [x] Different target clears or replaces the pending preview and submits no command.
  - [x] Different non-attack tile clears pending attack preview and submits no command.
  - [x] Target invalidation clears or disables commit and submits no command.
  - [x] Returned dictionaries contain no raw domain objects, command instances, resources, nodes, controls, or mutable repository internals.
- [x] 2.3.8 Keep records and validation current. (AC: 1-3)
  - [x] Run `godot --version`.
  - [x] Run `godot --headless --path C:\Sealsworn\godot --scene res://tests/headless/test_runner.tscn --quit-after 10`.
  - [x] Run `git diff --check`.
  - [x] Update this story's Dev Agent Record, Completion Notes, File List, and Change Log with actual implementation work.
  - [x] Keep `sprint-status.yaml` synchronized with this story status.

### Review Findings

- [x] [Review][Patch] Full-context invalidations can still reach the command bridge [godot/scripts/ui/view_models/tactical_attack_commit_flow.gd:52]
- [x] [Review][Patch] Confirm/cancel availability trusts stale flow metadata and can mask invalid reasons [godot/scripts/ui/view_models/tactical_action_availability.gd:20]
- [x] [Review][Patch] Presenter availability overrides can bypass confirm/cancel flow gates [godot/scripts/ui/view_models/tactical_board_view_model.gd:149]
- [x] [Review][Patch] Refreshing a changed target can clear the flow with reason `valid` [godot/scripts/ui/view_models/tactical_attack_commit_flow.gd:100]
- [x] [Review][Patch] Required invalidation cases are not covered by tests [godot/tests/unit/ui/test_tactical_attack_commit_flow.gd:179]

## Dev Notes

### Pre-Implementation Gate

This is the third Epic 2 implementation story. Story creation found:

- Current branch: `codex/epic-2`
- Baseline commit: `39f594c1e577da0ab3cacba6ab6b9e7d82801ca2`
- Working tree: clean at story creation time
- `epic-1: done`
- Story 2.1: `done`
- Story 2.2: `done`
- Story 2.3: `backlog` before this file was created

Before implementing, confirm the local tree is still clean or that any dirty files are intentional user work. Preserve unrelated changes. If Story 2.1 or Story 2.2 is no longer done, stop and restore that boundary before adding two-step attack commit behavior.

### Scope Boundary

This story creates the mobile-default attack commit state and cancel flow. It should make deliberate attack confirmation testable without building a polished tactical HUD.

In scope:

- Scene-free attack preview mode state for first-tap attacks.
- Same-target second tap and explicit confirm as the default attack commit paths.
- Cancel, target switch, mode switch, and invalidation clearing.
- Command submission through the existing tactical command bridge.
- Tests proving preview/cancel/target switch do not mutate tactical state.
- Tests proving enemy advancement is reachable only from successful committed command results.

Out of scope:

- Movement two-step commit redesign unless required to keep action availability coherent.
- Tactical HUD scenes, final touch gesture handlers, inspect panels, zoom mapping, layout profiles, orientation profiles, settings UI, save/resume UI, final audio/VFX, animation, production art, or asset-source metadata.
- Runtime AI-generated content, cloud services, multiplayer, telemetry, Godot .NET/C#, or scene-owned gameplay truth.

### Current Repository Baseline

Story 2.2 implemented the preview contracts this story should build on:

- `TacticalPreviewView` stores copied preview values and returns stable `to_dictionary()` output.
- `TacticalMovementPreview.from_query()` builds scene-free movement preview dictionaries from `TacticalMovementQuery.validate_target()`.
- `TacticalAttackPreview.from_query()` builds scene-free attack preview dictionaries from `AttackPreviewQuery.preview_target_cell()`.
- Attack previews include `kind`, `available`, `reason`, `actor_id`, `target_cell`, `target_entity_id`, `target_valid`, `commit_available`, `commit_reason`, `cue_ids`, and `metadata`.
- Attack metadata includes weapon reach, targeting shape, distance, line cells, blocker cells, blocker state, expected deterministic damage, effects, warnings, and explanation.
- `TacticalBoardViewModel.from_domain()` accepts normalized preview dictionaries and sanitizes nested arrays/dictionaries.
- `TacticalActionAvailability.from_preview()` currently enables `move`, `attack`, and `confirm` from `commit_available`; `inspect` remains available; `cancel` is still unavailable.

Existing command and turn flow facts:

- `TacticalCommandBridge.build_command()` supports `move`, `attack`, and `inspect` intents and validates without command execution.
- `TacticalCommandBridge.execute_intent()` delegates to the typed command's `execute(context)` only after conversion succeeds.
- `AttackCommand.validate()` wraps `AttackPreviewQuery` metadata and checks turn phase, actor, weapon, and support definitions.
- `AttackCommand.execute()` performs damage/status/knockback mutation, emits deterministic past-tense events, may consume named combat RNG streams, and sets `metadata["advances_turn"] = true`.
- `EnemyTurnResolver.resolve_after_player_action(context, player_result)` returns immediately unless the supplied successful result metadata has `advances_turn = true`.
- UI state should not own enemy AI or level-system truth; it should expose the committed command result so the gameplay shell can invoke enemy/level advancement after success.

### Design Intent

The GDD calls out mis-taps as costly because every committed action advances enemies and level systems. The mobile default must therefore be:

- First tap on visible enemy: preview only.
- Same-target second tap: commit if preview remains valid.
- Clear confirm action: commit if preview remains valid.
- Cancel, different target, different tile, invalidation, or mode switch: clear or replace preview without committing.

Previews should remain visually and semantically distinct from committed actions. This story owns the state and data contract; later scene/UI stories can map touch, mouse, controller, or keyboard input into the semantic intents.

### Latest Godot 4.6 Input Notes

Official Godot 4.6 docs identify `InputEventScreenTouch` as the touch press/release event class with `pressed`, `position`, `index`, `double_tap`, and `canceled` properties: https://docs.godotengine.org/en/4.6/classes/class_inputeventscreentouch.html

Official Godot 4.6 docs identify `InputEventMouseButton` as the mouse button press/release event class with `pressed`, `button_index`, `double_click`, and `canceled` properties: https://docs.godotengine.org/en/4.6/classes/class_inputeventmousebutton.html

Use those classes only in later presenter/input mapping code if needed. The Story 2.3 implementation should prefer semantic intents and scene-free tests so mobile touch and desktop click parity share the same commit rules.

### Existing Files To Reuse Or Preserve

| Path | Current State | This Story Changes | Preserve |
|---|---|---|---|
| `godot/scripts/ui/view_models/tactical_attack_preview.gd` | Builds copied attack preview DTOs from `AttackPreviewQuery`. | Reuse for first-tap and revalidation previews. | No command execution, no RNG draws, no domain object exposure. |
| `godot/scripts/ui/view_models/tactical_preview_view.gd` | Sanitizes copied preview dictionaries. | Reuse for commit-flow state dictionaries if practical. | Stable value-only output and deep-copy behavior. |
| `godot/scripts/ui/view_models/tactical_action_availability.gd` | Derives move/attack/confirm availability from preview commit availability; cancel unavailable. | Add or route flow-aware cancel availability for active attack preview mode. | Inspect remains metadata-only; no mutation. |
| `godot/scripts/ui/view_models/tactical_board_view_model.gd` | Builds copied board view dictionaries and normalized preview slot. | Accept commit-flow preview metadata only if needed by presenters/tests. | Hidden/memory visibility boundaries, no raw domain objects, deterministic row-major/id sorting. |
| `godot/scripts/ui/command_bridge/tactical_command_bridge.gd` | Converts and executes semantic intents through typed commands. | Prefer reuse; add confirm/cancel helpers only if they stay semantic and validation-friendly. | Command conversion remains distinct from preview data; command objects are not exposed to presenters. |
| `godot/scripts/core/commands/attack_command.gd` | Validates by preview query and mutates only on `execute()`. | No expected change. Tests should prove it runs only on commit. | Events, RNG, HP mutation, and turn advancement stay command-owned. |
| `godot/scripts/tactical/turns/enemy_turn_resolver.gd` | Advances enemies after successful player results with `advances_turn`. | Reuse in tests to prove advancement is post-command only. | UI flow state does not own enemy resolution. |
| `godot/scripts/save/snapshots/tactical_snapshot.gd` | Snapshot/no-mutation proof tool. | Use in tests. | Snapshot remains domain-only and scene-free. |
| `godot/tests/unit/ui/test_tactical_preview_view_models.gd` | Story 2.2 preview DTO contract tests. | Update only if cancel/confirm availability expectations become flow-aware. | Existing preview no-mutation and sanitation coverage must remain green. |
| `godot/tests/unit/ui/test_tactical_command_bridge.gd` | Bridge conversion and execution tests. | Add narrow integration assertions only if needed. | Bridge metadata stripping and validation behavior remain stable. |
| `godot/tests/fixtures/tactical/board_fixture_factory.gd` | Movement, attack preview, enemy turn, outcome, and micro-combat fixtures. | Reuse first; add only small fixtures when necessary. | Deterministic fixtures and baseline combat setup. |

### Recommended New Files

Use these names unless implementation discovers a clearer local pattern:

- `godot/scripts/ui/view_models/tactical_attack_commit_flow.gd`
- `godot/tests/unit/ui/test_tactical_attack_commit_flow.gd`

If result objects are needed, add one small value object such as `godot/scripts/ui/view_models/tactical_commit_flow_result.gd`. Avoid spreading flow behavior across presenters or scenes.

### Suggested Commit Flow Contract

The exact public shape can be adjusted to match the implementation, but tests should assert stable value-only output resembling:

```gdscript
{
	"mode": "attack_preview",
	"actor_id": "hero",
	"target_cell": {"x": 2, "y": 1},
	"target_entity_id": "enemy_1",
	"weapon_id": "sword",
	"preview": attack_preview_dictionary,
	"confirm_available": true,
	"cancel_available": true,
	"submitted": false,
	"result_reason": "preview_ready",
	"cue_ids": ["attack_preview_valid", "commit_available", "cancel_available"]
}
```

For a committed same-target second tap or confirm, presenter-facing output may identify submission and expose a sanitized result summary, but it must not expose raw `ActionResult`, command instances, events, resources, or domain objects. Keep the raw command result on the non-presenter path if the gameplay shell needs it for enemy/level advancement.

### Implementation Guardrails

- Do not implement attack commit as an input-event double tap. The rule is "same target tapped again or confirm", not Godot's `double_tap` or `double_click` flags.
- Do not rely on screen position in the flow state. Presenters should translate `InputEventScreenTouch.position` or `InputEventMouseButton` clicks into semantic target-cell intents before calling this logic.
- Do not consume RNG, apply damage, append combat events, resolve enemies, or advance level systems during preview, cancel, target switch, or invalidation.
- Revalidate before commit to close stale-preview paths.
- If the target changes to another valid enemy, starting a fresh preview is acceptable; submitting the old attack is not.
- If the target changes to a non-attack tile, clearing pending attack preview is acceptable; submitting an attack is not.
- Keep invalid reasons stable lower-snake ids so UI can localize or map them later.
- Keep all headless tests free of rendering, audio, UI scenes, presentation nodes, and scene-tree-only state.

### Testing Notes

Minimum focused tests:

- `first_enemy_tap_enters_preview_without_command_or_mutation`
- `same_target_second_tap_commits_once_through_bridge`
- `confirm_commits_once_when_preview_is_still_valid`
- `cancel_clears_preview_without_command_or_mutation`
- `different_enemy_replaces_preview_without_committing_previous_target`
- `different_tile_clears_preview_without_command_or_mutation`
- `invalidated_target_disables_or_clears_commit_without_command`
- `failed_commit_result_does_not_advance_enemy_turn`
- `successful_commit_result_allows_enemy_turn_resolver_to_advance`
- `presenter_dictionary_contains_only_safe_values`

Use explicit snapshots before and after non-commit actions. For commit tests, assert mutation is absent until the commit path executes and then assert mutation is attributable to the command result and downstream resolver only.

## Dev Agent Record

### Agent Model Used

Codex GPT-5

### Debug Log References

- Created story from `_bmad-output/planning-artifacts/epics.md`, `_bmad-output/planning-artifacts/gdds/gdd-Game-2026-05-31/gdd.md`, `_bmad-output/planning-artifacts/gdds/gdd-Game-2026-05-31/epics.md`, `_bmad-output/planning-artifacts/epic-2-sprint-plan-2026-06-07.md`, `project-context.md`, and `_bmad-output/game-architecture.md`.
- Confirmed current Godot input event classes against official Godot 4.6 documentation.
- 2026-06-08: Confirmed Epic 2 boundary in `sprint-status.yaml`, branch `codex/epic-2`, and preserved existing `baseline_commit`.
- 2026-06-08: Added Story 2.3 failing test coverage first; red run failed on missing `tactical_attack_commit_flow.gd` / result contract before implementation.
- 2026-06-08: Implemented scene-free attack commit flow and flow-aware action availability.
- 2026-06-08: Validated with `godot --version`, headless test runner, and `git diff --check`.
- 2026-06-08: Applied review patches for full-context invalidation, stale flow gating, presenter override clamping, target-change refresh reasons, and expanded invalidation coverage.

### Completion Notes

- Added `TacticalAttackCommitFlow` as a scene-free, value-only attack preview/confirm/cancel state helper.
- Added `TacticalAttackCommitFlowResult` so successful commits can expose raw `ActionResult` to gameplay shell code while presenter dictionaries stay sanitized.
- Reused `TacticalAttackPreview.from_query()` and `TacticalCommandBridge.execute_intent()` so first taps preview without mutation and committed attacks still mutate only through typed command execution.
- Updated action availability and board view-model output so attack confirm/cancel require active pending attack-preview flow metadata; movement confirm behavior remains intact.
- Added focused tests for first tap, same-target second tap, explicit confirm, cancel, target switch, non-attack tile clear, invalidation clear, failed commit/no enemy advancement, successful commit/enemy advancement, and presenter-safe dictionaries.
- Review patches now require matching flow metadata before confirm/cancel availability, prevent unavailable full-context commits from producing command results, and cover dead, hidden, friendly, out-of-range, blocked, wrong-phase, and wrong-actor invalidations.

### File List

- `_bmad-output/implementation-artifacts/2-3-mobile-two-step-commit-and-cancel-flow.md`
- `_bmad-output/implementation-artifacts/sprint-status.yaml`
- `godot/scripts/ui/view_models/tactical_attack_commit_flow.gd`
- `godot/scripts/ui/view_models/tactical_attack_commit_flow_result.gd`
- `godot/scripts/ui/view_models/tactical_action_availability.gd`
- `godot/scripts/ui/view_models/tactical_board_view_model.gd`
- `godot/tests/unit/ui/test_tactical_attack_commit_flow.gd`
- `godot/tests/unit/ui/test_tactical_board_view_model.gd`
- `godot/tests/unit/ui/test_tactical_preview_view_models.gd`

### Change Log

- 2026-06-08: Created Story 2.3 and set implementation tracking status to `ready-for-dev`.
- 2026-06-08: Implemented mobile two-step attack commit and cancel flow; status set to `review`.
- 2026-06-08: Applied review patches and set status to `done`.
