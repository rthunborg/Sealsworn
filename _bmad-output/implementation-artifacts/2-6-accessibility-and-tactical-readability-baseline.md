---
baseline_commit: 16edd3f2ea41ac5ec97ca524a1816a6f9d3d046a
created: 2026-06-14
source_story_key: 2-6-accessibility-and-tactical-readability-baseline
---

# Story 2.6: Accessibility and Tactical Readability Baseline

Status: review

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a player,
I want critical tactical information to be readable without relying on color or small text,
so that combat decisions remain clear on phone-sized screens.

## Acceptance Criteria

1. Given danger, valid movement, attack range, blocked line, and telegraphed damage indicators are displayed, when color is removed or altered, then shape, icon, label, pattern, or text still communicates the critical meaning, and no critical tactical information depends on color alone.
2. Given scalable text settings are changed within supported bounds, when tactical HUD, previews, and inspect panels render, then essential labels remain readable and do not overlap controls, and no gameplay rule changes with text scale.
3. Given preview and commit feedback are displayed, when the player compares them, then preview state and committed action state are visually and audibly distinguishable where audio is available, and the distinction is also available without audio.

## Tasks / Subtasks

- [x] 2.6.1 Confirm the Epic 2 boundary and add failing tests first. (AC: 1-3)
  - [x] Verify `sprint-status.yaml` has `epic-1: done`, Stories 2.1-2.5 `done`, and this story `ready-for-dev` before implementation starts.
  - [x] Confirm the working tree is clean or that dirty files are intentional user work; preserve unrelated changes. (The untracked orchestrator-owned `_bmad-output/auto-gds/` directory is expected and is not your change.)
  - [x] Add focused failing tests first, recommended `godot/tests/unit/ui/test_tactical_accessibility_cues.gd`, before any production edit.
  - [x] Reuse `BoardFixtureFactory.micro_combat_board()` and the existing preview/inspect/commit-flow/zoom/layout helpers and `TacticalSnapshot.from_domain()` for no-mutation assertions. Do not invent a new board fixture or a new test framework.
  - [x] Do NOT add final art, final audio assets, production UI frames, a settings UI, a settings persistence subsystem, save/resume UI, or a colorblind-simulation renderer in this story.
- [x] 2.6.2 Define a single scene-free accessibility/readability cue contract. (AC: 1, 3)
  - [x] Add a typed `RefCounted` helper under `godot/scripts/ui/view_models/`, recommended name `tactical_accessibility_model.gd` (alt. `tactical_cue_catalog.gd` if a pure catalog reads clearer locally).
  - [x] Keep output value-only: `String`, `StringName`, `int`, `bool`, `float`, `Array`, and `Dictionary` deep copies. Do NOT expose `BoardState`, command objects, `ActionResult`, `Resource`, `Node`, `Control`, `Theme`, `Font`, callables, or repository internals.
  - [x] Define the authoritative non-color channel for every critical tactical meaning. For each cue id, declare the required redundant channels from this set: `shape`, `icon`, `label`, `pattern`, `text`. AC1 requires at least one non-color channel per critical meaning.
  - [x] Cover at minimum these critical meanings already emitted as cue ids by Epic 2 (do NOT rename them — map onto them): movement validity (`move_preview_valid` / `move_preview_invalid`), attack legality / range (`attack_preview_valid` / `attack_preview_invalid`), blocked line (`attack_preview_blocked_line`), blocker ignored / override (`attack_preview_blocker_ignored`), adjacency warning (`attack_preview_adjacent_warning`), telegraphed danger (`telegraph_pending`, `telegraph_due`, `danger_damage`), inspect visibility tiers (`inspect_visible`, `inspect_memory`, `inspect_hidden_unexplored`), and commit availability (`commit_available` / `commit_unavailable`).
  - [x] Return a stable `kind: "accessibility"` envelope plus a `color_independent: true` assertion field that tests can check, and a stable `reason`/`available` shape consistent with the other view-model helpers.
- [x] 2.6.3 Establish the preview-versus-committed distinction without color and without audio. (AC: 3)
  - [x] AC3 is the main net-new contract: today the commit flow only appends `cancel_available` to the preview's cue ids, and there is no explicit cue distinguishing a previewed action from a committed/executed action.
  - [x] Define explicit stable cue ids for both states, recommended `feedback_preview` (action is previewed/pending) and `feedback_committed` (action was committed/executed), each with a non-color, non-audio channel (e.g. distinct `label`/`text` plus `shape` or `pattern`).
  - [x] Define a parallel audio cue id for each (recommended `audio_feedback_preview`, `audio_feedback_committed`) declared as optional, and assert that every audio cue id has a guaranteed visual/textual equivalent so the distinction survives with audio muted or unavailable. Audio cue ids are placeholders/string ids only; do NOT add audio files, an `AudioStreamPlayer`, or `AudioManager` wiring.
  - [x] Map `feedback_committed` from a successful `TacticalAttackCommitFlowResult` / committed `ActionResult` and `feedback_preview` from active preview / commit-flow `attack_preview` mode. Do not change commit-flow gating, two-step commit rules (Story 2.3), or command execution.
- [x] 2.6.4 Define a scalable-text bounds contract that never changes gameplay rules. (AC: 2)
  - [x] Add a scene-free text-scale model (on the accessibility helper or a small sibling, recommended `tactical_text_scale.gd`) that takes an injected requested scale and clamps it to named bounds (recommended `MIN_TEXT_SCALE`, `MAX_TEXT_SCALE`; default `1.0`).
  - [x] Return clamped scale, the requested scale, a `clamped: bool` flag, and a stable `reason` for out-of-range/malformed input (NaN/inf/zero/negative -> fallback `1.0`).
  - [x] Prove with tests that changing text scale never alters tactical truth: no change to board, RNG streams, turn state, previews' legality, action availability, telegraphs, outcome, or event log. Text scale is presentation/preferences only.
  - [x] Provide enough information for a presenter to keep essential labels readable and non-overlapping (e.g. scaled minimum label sizing / spacing hints), but do NOT build the final HUD layout, fonts, or theme. Reuse `TacticalLayoutProfile.minimum_touch_target`/`spacing` for control geometry; do not duplicate layout geometry here.
- [x] 2.6.5 Integrate accessibility cue/text data with existing view-model output without creating scene-owned state. (AC: 1-3)
  - [x] Prefer adding a sanitized optional `accessibility` slot to `TacticalBoardViewModel.from_domain()` so presenters can consume board, preview, commit-flow, inspect, zoom, layout, and accessibility data together. Default it to `{}` and populate it through the existing `_dictionary_from_options` -> safe-copy path, exactly like `layout` was added in Story 2.5.
  - [x] CRITICAL: `TacticalBoardViewModel.to_dictionary()` currently returns exactly 15 stable top-level keys (Story 2.5 added `layout` as the 15th). `godot/tests/unit/ui/test_tactical_board_view_model.gd` asserts the full sorted key list at the top of `_view_model_exposes_stable_read_only_board_data()`. If you add an `accessibility` key, you MUST update that sorted-key assertion intentionally (it becomes 16 keys) and keep all existing keys/behavior backward-compatible. If you keep accessibility separate from the board VM, document that decision here and add tests proving presenters still receive the same state contracts.
  - [x] Keep `cells`, `occupants`, `selection`, `preview`, `commit_flow`, `inspect`, `zoom`, `action_availability`, `turn`, `outcome`, `event_log_summary`, and `layout` behavior backward-compatible.
  - [x] Accessibility/text-scale recalculation must not call `TacticalCommandBridge.build_command()`/execution, `MoveCommand.execute()`, `AttackCommand.execute()`, `TacticalAttackCommitFlow.confirm_attack()`, enemy turn resolution, level-system advancement, or gameplay RNG.
- [x] 2.6.6 Prove the color-independence audit across the critical tactical surface. (AC: 1)
  - [x] For every critical meaning in 2.6.2, assert at least one of `shape`/`icon`/`label`/`pattern`/`text` is present and non-empty, so meaning survives if color is stripped.
  - [x] Drive the audit from real Epic 2 outputs where practical: build movement previews (valid + invalid), attack previews (valid, blocked-line, adjacency-penalty, blocker-ignored/override), and inspect views (visible, memory, hidden, telegraph pending/due with damage) from `BoardFixtureFactory` and assert each emitted cue id has a registered non-color channel in the accessibility model. This catches a cue that exists in a preview but is missing an accessibility mapping.
  - [x] Assert no critical cue relies on a color token alone (the model must not expose a color-only entry for a critical meaning).
- [x] 2.6.7 Cover scalable text, preview/commit distinction, sanitation, and no-mutation. (AC: 1-3)
  - [x] Text scale clamps to bounds, falls back to `1.0` on malformed input, and never mutates a `TacticalSnapshot.from_domain()` comparison.
  - [x] `feedback_preview` and `feedback_committed` are distinct, each has a non-color visual channel, and each audio cue id has a visual/textual equivalent (assert the distinction holds with audio "absent").
  - [x] Returned accessibility/text dictionaries are deep copies and contain no forbidden raw domain, resource, command, scene, node, theme, font, or callable references (reuse the existing `TacticalPreviewView.safe_*` / board-VM safe-copy path; do not add a fourth duplicate sanitizer — see Previous Story Intelligence).
  - [x] No-mutation: building accessibility/text-scale data does not mutate board, turn state, RNG streams, pending telegraphs, outcome, or event log and does not execute commands.
- [x] 2.6.8 Keep records and validation current. (AC: 1-3)
  - [x] Run `godot --version` (through PowerShell — see Testing Requirements).
  - [x] Run the full headless suite through PowerShell (the bare `godot` is not on the Bash tool PATH; see Testing Requirements).
  - [x] Run `git diff --check`.
  - [x] Update this story's Dev Agent Record, Completion Notes, File List, and Change Log with actual implementation work.
  - [x] Keep `sprint-status.yaml` synchronized with this story status.

## Dev Notes

### Pre-Implementation Gate

This is the sixth Epic 2 implementation story. Story creation found:

- Baseline commit: `16edd3f2ea41ac5ec97ca524a1816a6f9d3d046a`
- Working tree: clean at story creation time (only the untracked orchestrator-owned `_bmad-output/auto-gds/` tree exists, which is not story work)
- `epic-1: done`
- Story 2.1: `done`
- Story 2.2: `done`
- Story 2.3: `done`
- Story 2.4: `done`
- Story 2.5: `done`
- Story 2.6: `backlog` before this file was created

Before implementing, confirm the local tree is still clean or that dirty files are intentional user work. If any Story 2.1-2.5 status has regressed, stop and restore that boundary before adding the accessibility baseline.

### Scope Boundary

This story establishes the accessibility and tactical-readability baseline as scene-free presentation contracts: a single authoritative cue/accessibility model that guarantees critical tactical meaning is communicated without color alone, a scalable-text bounds contract that never changes gameplay rules, and an explicit preview-vs-committed distinction that survives with audio muted or unavailable. Epic 2 has already emitted semantic `cue_ids` from previews, inspect, commit flow, and layout; this story formalizes them into an auditable accessibility contract rather than reinventing them.

In scope:

- A scene-free accessibility/cue model mapping every critical tactical meaning to required non-color channels (`shape`/`icon`/`label`/`pattern`/`text`).
- A scalable-text bounds model (clamp, fallback, no rule changes) as a presentation/preferences contract.
- Explicit `feedback_preview` vs `feedback_committed` cue ids with non-color visual channels and audio cue ids that always have a visual/textual equivalent.
- An optional sanitized `accessibility` slot on `TacticalBoardViewModel`.
- Tests proving color-independence across the real preview/inspect/telegraph surface, text-scale rule invariance, audio-optional distinction, deep-copy sanitation, and no mutation / no command execution.

Out of scope (owned elsewhere — do not build here):

- Final tactical HUD art, icons, fonts, themes, animations, VFX, SFX, and production UI frames.
- The settings model, settings persistence, and settings UI (text-scale value storage, audio volume/mute fields, input-preference fields as saved preferences). **Story 2.9 owns the settings subsystem and the no-difficulty-ladder guardrails.** This story defines the readability/cue *contract* the settings will later drive; it does not store or persist preferences.
- Save/resume UI or persistence. Stories 2.7 and 2.8 own save/resume.
- Layout geometry and touch-target tuning. **Story 2.5 owns `TacticalLayoutProfile`.** Its `minimum_touch_target` (44x44) and `spacing` are conservative constants explicitly handed to this story's broader audit. If the audit requires a stricter touch target, change the named constant in `TacticalLayoutProfile` intentionally and update its tests — do not fork a second touch-target value in the accessibility model.
- Actual colorblind simulation/rendering, audio playback, or `AudioStreamPlayer`/`AudioManager` wiring. Audio is represented as cue ids only.
- Runtime AI-generated content, cloud services, multiplayer, telemetry, Godot .NET/C#, React/Vite production dependencies, or new test frameworks.

### Current Repository Baseline

Stories 2.1-2.5 built the scene-free UI contract this story extends. The cue-id vocabulary already exists and must be reused, not renamed or duplicated:

- `TacticalBoardViewModel.to_dictionary()` returns exactly 15 stable top-level keys: `width`, `height`, `cells`, `occupants`, `selected_cell`, `selected_entity_id`, `preview`, `commit_flow`, `inspect`, `zoom`, `action_availability`, `turn`, `outcome`, `event_log_summary`, and `layout`. `layout` was added in Story 2.5; `test_tactical_board_view_model.gd` asserts the full sorted key list. (Retro: any consumer enumerating exact keys must account for `layout`; adding `accessibility` makes it 16.)
- `TacticalMovementPreview` emits `cue_ids` `move_preview_valid` + `commit_available` (valid) or `move_preview_invalid` + `commit_unavailable` (invalid).
- `TacticalAttackPreview` emits `cue_ids` `attack_preview_valid`/`attack_preview_invalid`, plus conditionally `attack_preview_blocked_line`, `attack_preview_blocker_ignored`, `attack_preview_adjacent_warning`, `preview_effect`, and `commit_available`/`commit_unavailable`. It also exposes `metadata.blocker_state` (`clear`/`blocked`/`ignored`/`unknown`).
- `TacticalInspectView` emits `cue_ids` `inspect_visible`/`inspect_memory`/`inspect_hidden_unexplored`, plus `telegraph_pending`/`telegraph_due` and `danger_damage` for marked-cell telegraphs, and preserves hidden/memory fact boundaries.
- `TacticalAttackCommitFlow` state carries `cue_ids` from the active attack preview and appends `cancel_available` while in `attack_preview` mode. There is currently NO explicit cue separating a previewed action from a committed one — AC3 introduces it.
- `TacticalLayoutProfile` emits `layout_profile_<id>`, `layout_orientation_<id>`, `layout_safe_area_applied`, and `layout_fallback` cue ids and exposes `minimum_touch_target` and `spacing`.
- `TacticalPreviewView` provides the shared `safe_dictionary_copy`/`safe_array_copy`/`safe_value`/`cell_metadata`/`field`/`has_field` helpers used everywhere for sanitization.
- Existing UI production code is still light: `godot/scripts/ui/presenters/boot_controller.gd` is a bootstrap `Control` and must not become tactical/accessibility-state authority.

### Existing Files To Reuse Or Preserve

| Path | Current State | This Story Changes | Preserve |
|---|---|---|---|
| `godot/scripts/ui/view_models/tactical_board_view_model.gd` | 15-key copied board/view-model contract with preview, commit-flow, inspect, zoom, layout, availability, turn, outcome, event-log slots. | Prefer adding a sanitized optional `accessibility` slot via the existing `_dictionary_from_options` -> safe-copy path, or document why accessibility stays separate. | All 15 existing keys, no raw objects, commit-flow gating, deep-copy behavior, deterministic sorting. |
| `godot/scripts/ui/view_models/tactical_movement_preview.gd` | Scene-free movement preview DTO with `cue_ids`. | Read-only source for the color-independence audit. | `cue_ids` names and no-mutation. Do not change preview legality. |
| `godot/scripts/ui/view_models/tactical_attack_preview.gd` | Scene-free attack preview DTO with `cue_ids`, `blocker_state`, warnings, effects. | Read-only source for the audit (blocked-line, adjacency, override cases). | `cue_ids` names, blocker/warning semantics, no command execution or gameplay RNG. |
| `godot/scripts/ui/view_models/tactical_inspect_view.gd` | Scene-free inspect data with visibility-tier and telegraph/danger `cue_ids`. | Read-only source for the audit (telegraph/danger meanings). | Hidden/memory fact boundaries, telegraph cue semantics, no mutation. |
| `godot/scripts/ui/view_models/tactical_attack_commit_flow.gd` | Scene-free two-step attack preview/confirm/cancel flow; appends `cancel_available`. | Read-only source for mapping `feedback_preview`; map `feedback_committed` from a successful commit result. | Same-target/confirm commit remains the only default attack commit path; gating from Story 2.3 unchanged. |
| `godot/scripts/ui/view_models/tactical_attack_commit_flow_result.gd` | Result wrapper for commit-flow submit/confirm. | Read-only source for the committed-action signal. | Result shape; do not change submission semantics. |
| `godot/scripts/ui/view_models/tactical_action_availability.gd` | Derives move/attack/inspect/confirm/cancel availability from preview + commit flow. | Usually no change; tests only if accessibility passes through the board VM. | Layout/accessibility must not enable confirm/cancel or bypass stale-flow protections. |
| `godot/scripts/ui/view_models/tactical_layout_profile.gd` | Scene-free adaptive layout; exposes `minimum_touch_target` (44x44) and `spacing`. | Reuse touch-target/spacing for control geometry; do not duplicate. If a stricter touch target is needed, change the named constant here intentionally and update its tests. | Layout geometry stays the single source of touch-target/spacing truth. |
| `godot/scripts/ui/view_models/tactical_preview_view.gd` | Shared safe copy/normalization helpers. | Reuse for accessibility/text sanitization. | Unsafe object values become `null`; `Vector2i` becomes coordinate dictionaries. |
| `godot/scripts/ui/command_bridge/tactical_command_bridge.gd` | Converts semantic UI intents to typed commands or metadata-only inspect. | No expected change. Tests prove accessibility/text recalculation never calls execution. | Command bridge remains the only UI-to-command boundary. |
| `godot/scripts/ui/presenters/boot_controller.gd` | Simple bootstrap `Control` presenter. | Usually no change. | No tactical/accessibility state ownership. |
| `godot/tests/unit/ui/test_tactical_board_view_model.gd` | Asserts the full 15-key sorted top-level list + sanitation/visibility/no-mutation. | Update the sorted-key assertion intentionally to 16 keys IF an `accessibility` slot is added. | All other behavior remains green. |
| `godot/tests/unit/ui/test_tactical_preview_view_models.gd` | Movement/attack preview DTO + `cue_ids` tests. | Reuse fixtures/patterns for the audit; extend only if needed. | Existing preview cue semantics remain green. |
| `godot/tests/unit/ui/test_tactical_inspect_view.gd` | Inspect/telegraph/visibility-tier tests. | Reuse fixtures for telegraph/danger audit cases. | Existing inspect semantics remain green. |
| `godot/tests/fixtures/tactical/board_fixture_factory.gd` | Tactical fixtures for micro-combat, movement, previews, enemy turns, outcomes, Ash Seer/telegraph cases. | Reuse first; add fixtures only if a specific audit case is missing. | Deterministic setup and existing tests. |

### Recommended New Files

Use these names unless implementation discovers a clearer local pattern:

- `godot/scripts/ui/view_models/tactical_accessibility_model.gd` (the cue/accessibility contract; may also host the preview/commit feedback cue ids)
- `godot/scripts/ui/view_models/tactical_text_scale.gd` (only if the text-scale clamp reads clearer as its own small helper; otherwise keep it on the accessibility model)
- `godot/tests/unit/ui/test_tactical_accessibility_cues.gd`

Avoid adding a new dependency, plugin, autoload, save format, theme system, settings subsystem, or audio subsystem for this story.

### Accessibility Cue Contract

Recommended accessibility model shape (value-only deep copies):

```gdscript
{
	"kind": "accessibility",
	"color_independent": true,
	"available": true,
	"reason": "valid",
	"cues": {
		"move_preview_valid": {"channels": ["shape", "label"], "severity": "info"},
		"move_preview_invalid": {"channels": ["shape", "label"], "severity": "blocked"},
		"attack_preview_valid": {"channels": ["icon", "label"], "severity": "info"},
		"attack_preview_invalid": {"channels": ["icon", "label"], "severity": "blocked"},
		"attack_preview_blocked_line": {"channels": ["pattern", "label", "text"], "severity": "blocked"},
		"attack_preview_blocker_ignored": {"channels": ["icon", "text"], "severity": "info"},
		"attack_preview_adjacent_warning": {"channels": ["icon", "label", "text"], "severity": "warning"},
		"telegraph_pending": {"channels": ["pattern", "label"], "severity": "warning"},
		"telegraph_due": {"channels": ["pattern", "label", "text"], "severity": "danger"},
		"danger_damage": {"channels": ["icon", "label", "text"], "severity": "danger"},
		"inspect_visible": {"channels": ["label"], "severity": "info"},
		"inspect_memory": {"channels": ["pattern", "label"], "severity": "info"},
		"inspect_hidden_unexplored": {"channels": ["pattern", "label"], "severity": "info"},
		"commit_available": {"channels": ["label"], "severity": "info"},
		"commit_unavailable": {"channels": ["label", "text"], "severity": "blocked"},
		"feedback_preview": {"channels": ["shape", "label"], "severity": "info", "audio_cue_id": "audio_feedback_preview"},
		"feedback_committed": {"channels": ["shape", "label", "text"], "severity": "info", "audio_cue_id": "audio_feedback_committed"}
	},
	"text_scale": {"requested": 1.0, "scale": 1.0, "clamped": false, "reason": "valid"}
}
```

Rules:

- Cue ids, channel ids, severity ids, and reasons must be stable lower snake case strings.
- Every cue mapped to a critical tactical meaning MUST list at least one non-color channel from `shape`/`icon`/`label`/`pattern`/`text`. Color is never the only channel for a critical meaning. (`severity` may map to a color in a presenter, but it is additive — never the sole signal.)
- Every entry with an `audio_cue_id` MUST also carry at least one visual/textual channel so the meaning is available with audio muted/absent (AC3).
- The exact cue-id strings must match the strings already emitted by `TacticalMovementPreview`, `TacticalAttackPreview`, `TacticalInspectView`, and `TacticalAttackCommitFlow`. Do not introduce a parallel renamed vocabulary.
- The accessibility model is a presentation contract: it is not save truth, not domain state, not tactical legality, and not a settings store.

### Preview-vs-Committed Distinction Contract

AC3 is the main net-new behavior. Today an attack in `attack_preview` mode carries the preview's `cue_ids` + `cancel_available`, and a committed attack produces a `TacticalAttackCommitFlowResult` / `ActionResult` but no distinct accessibility cue.

- Introduce `feedback_preview` (action previewed/pending) and `feedback_committed` (action committed/executed) as distinct cue ids, each with a non-color visual channel that differs between the two (e.g. different `label`/`text` and a `shape`/`pattern` difference), so a player can tell preview from committed with color stripped.
- Provide parallel optional audio cue ids (`audio_feedback_preview`, `audio_feedback_committed`) and assert each has a guaranteed visual/textual equivalent. With audio absent, the visual/textual distinction must still hold.
- Source mapping: `feedback_preview` from active preview / commit-flow `attack_preview` mode; `feedback_committed` from a successful committed result. Do NOT change two-step commit rules, confirm/cancel gating (Story 2.3), or command execution to produce these cues.

### Scalable Text Contract

- Inject the requested text scale; clamp to named bounds (`MIN_TEXT_SCALE`, `MAX_TEXT_SCALE`, default `1.0`). Malformed input (NaN/inf/zero/negative/non-numeric) falls back to `1.0` with a stable `reason`.
- Return `requested`, `scale`, `clamped`, and `reason`. Provide presenter hints sufficient to keep essential labels readable and non-overlapping (e.g. scaled minimum label sizing and spacing derived from `TacticalLayoutProfile.spacing`), but do not build fonts, theme, or final layout.
- Text scale is presentation/preferences only. Prove with a `TacticalSnapshot.from_domain()` byte-comparison that changing scale never mutates board, RNG, turn, telegraphs, outcome, event log, preview legality, or action availability (AC2: "no gameplay rule changes with text scale").
- Do not persist the scale here; persistence belongs to Story 2.9 settings.

### State / No-Mutation Contract

Accessibility and text-scale recalculation are pure presentation derivations. They must not mutate or replace tactical truth.

Never do these during accessibility/text recalculation:

- Execute move or attack commands or call the command bridge's build/execute path.
- Confirm or cancel attack commit flow unless a user intent says so.
- Resolve enemy turns or level systems.
- Consume gameplay RNG streams.
- Change board visibility, occupants, HP, pending telegraphs, turn phase, event log, save snapshots, rewards, or progression.

### Previous Story Intelligence

Story 2.5 (Adaptive Layout Profiles) directly informs this story:

- Story 2.5 explicitly deferred the broad accessibility/readability audit, scalable-text settings, colorblind-safe indicator audit, and non-color-only pattern pass to THIS story. Its `minimum_touch_target` (44x44) and `spacing` are conservative constants, not final accessibility settings — this story owns the broader audit but layout geometry stays in `TacticalLayoutProfile`.
- Story 2.5 added the `layout` 15th top-level key to `TacticalBoardViewModel` and intentionally updated the stable-key test. Follow the same pattern if you add `accessibility` (it becomes the 16th key) — the stable-key assertion in `test_tactical_board_view_model.gd` is exact and will fail otherwise.
- Story 2.5 Round 2 review flagged that presenter-facing value sanitization is already triplicated across `TacticalPreviewView`, `TacticalBoardViewModel`, and `TacticalLayoutProfile`. Do NOT add a fourth copy: route accessibility/text sanitization through `TacticalPreviewView.safe_*` (or the board VM's existing safe-copy path). A reviewer will flag new duplicated sanitizer logic.

Story 2.4 / 2.3 review lessons that still apply:

- Malformed inputs must preserve concrete, stable reason ids (follow this for malformed text-scale and missing cue mappings — do not collapse to a misleading `valid`).
- Presentation changes (zoom, layout, and now accessibility/text scale) must preserve preview/inspect/commit-flow targets and must never submit commands or advance enemies.
- Confirm/cancel availability is derived only from current matching commit-flow metadata; presenter/accessibility metadata cannot enable confirm/cancel or trust stale presentation state.

### Git Intelligence

Recent commits before this story:

- `c67ee4a Merge pull request #2 from rthunborg/story/2-5-adaptive-layout-profiles`
- `11a0392 chore(story-2-5): finalize (mark done + GDS status)`
- `70dc8e6 docs(story-2-5): pipeline report`
- `a7d204a chore(story-2-5): code review passed`
- `c3b9451 feat(story-2-5): implement adaptive layout profiles`

Actionable patterns:

- Epic 2 consistently adds narrow typed `RefCounted` UI helpers under `godot/scripts/ui/view_models/` and tests-first under `godot/tests/unit/ui/`. Follow that; do not add GUT/GdUnit or any new framework.
- The headless runner auto-discovers `test_*.gd` under `godot/tests/unit` and `godot/tests/integration`; no registry edit is needed.
- Review findings have repeatedly tightened value sanitization, no-mutation assertions, stable reason ids, and flow gating. Treat all four as first-class for the accessibility model.
- ENVIRONMENT (Epic 2 retro): the bare `godot` is resolvable only as `C:\Users\Rasmus\bin\godot.cmd` through PowerShell; the Bash tool's PATH/`where` cannot find it. Run `godot --version` and the headless suite through `powershell.exe -NoProfile -Command`.

### Architecture Compliance

- Follow the Adaptive UI Composition Pattern: domain state/events -> view model -> presenter/layout profile -> user intent -> command bridge -> command/event simulation. The accessibility model and text-scale model are read-only view-model-layer contracts.
- Accessibility cues and text scale are presentation contracts. They are not domain state, commands, save snapshots, tactical legality, settings storage, or scene truth.
- UI presenters and scenes may observe domain state and submit semantic intent; they cannot mutate tactical truth directly.
- Domain state remains scene-independent and authoritative. Successful commands, not accessibility/text recalculation, emit deterministic past-tense `DomainEvent` records.
- Accessibility/text recalculation must not consume gameplay RNG streams.
- Headless tests must run without rendering, audio, UI scenes, presentation nodes, fonts, themes, or scene-tree-only state.
- Critical tactical information must be available without relying on color alone, and audio cues must have visual/textual equivalents (architecture + GDD accessibility baseline).
- Do not add cloud services, accounts, multiplayer, telemetry dependencies, Godot .NET/C#, new test frameworks, audio playback subsystems, or React/Vite production dependencies.

### Library And Framework Requirements

- Required engine: Godot 4.6.3 stable standard build.
- Required language: typed GDScript.
- Use `RefCounted` for the accessibility/text-scale helpers.
- Use `Control`/container scripts only for optional presenter proof; never make them authoritative for tactical or accessibility state. (Optional presenter proof is NOT expected for this story; the contract is provable scene-free.)
- Represent audio as stable string cue ids only; do not add `AudioStreamPlayer`, audio buses, or `AudioManager` wiring.
- Reuse existing preview, inspect, commit-flow, layout, board view-model, and `TacticalPreviewView` helpers instead of duplicating cue vocabulary or sanitization.
- Use the existing custom headless test harness based on `godot/tests/unit/test_case.gd` (extend `res://tests/unit/test_case.gd`, expose `run() -> Dictionary`, return `result()`).

### Latest Technical Information

Official Godot 4.6 sources relevant to a scene-free accessibility/text-scale contract (the helper stays scene-free; these inform future presenter glue only, not this story's headless helpers):

- Godot exposes UI scaling through `Window.content_scale_factor` and the stretch system; user-facing text scaling can later be applied by a presenter. Story 2.6 should keep the text-scale model a pure clamp/contract and must not change gameplay rules from scale. Source: https://docs.godotengine.org/en/4.6/tutorials/rendering/multiple_resolutions.html
- Godot `Theme`/`Font` and `Control` theme overrides are where a presenter would apply scaled label sizes; the headless accessibility model should emit value-only sizing/spacing hints rather than constructing `Theme`/`Font` objects. Source: https://docs.godotengine.org/en/4.6/tutorials/ui/gui_skinning.html
- Godot audio (`AudioStreamPlayer`, audio buses) is presenter/platform glue; this story represents audio cues as ids only and asserts visual/textual equivalence, so muting or missing audio never hides critical meaning. Source: https://docs.godotengine.org/en/4.6/tutorials/audio/audio_buses.html

### Project Structure Notes

- UI-facing accessibility and text-scale contracts belong under `godot/scripts/ui/view_models/`.
- Optional presenter scripts (not expected here) belong under `godot/scripts/ui/presenters/`; optional layout/HUD scenes under `godot/scenes/ui/`.
- Command conversion remains under `godot/scripts/ui/command_bridge/`; tactical legality stays under `godot/scripts/tactical/`. Do not move accessibility logic into command execution or tactical queries.
- Tests mirror domains under `godot/tests/unit/ui/`.
- Production code stays under `godot/`; do not add production dependencies on `prototype/`.
- Root `project-context.md` is canonical. Do not create duplicate project context files under `_bmad-output/`.

### Testing Requirements

Run at minimum (through PowerShell — the bare `godot` is not on the Bash tool PATH; it resolves only as `C:\Users\Rasmus\bin\godot.cmd` via PowerShell):

```powershell
godot --version
godot --headless --path C:\Sealsworn\godot --scene res://tests/headless/test_runner.tscn --quit-after 10
git diff --check
```

If invoking from the Bash tool, wrap the commands, e.g. `powershell.exe -NoProfile -Command "godot --headless --path C:\Sealsworn\godot --scene res://tests/headless/test_runner.tscn --quit-after 10"`.

Expected final result:

- Godot version is `4.6.3.stable.official...` or explicitly compatible with project policy.
- The full headless runner exits with code `0`.
- Existing Epic 1 and Story 2.1-2.5 tests remain green (including the exact board-VM top-level-key assertion, updated intentionally only if an `accessibility` slot is added).
- New accessibility tests prove every critical cue id emitted by movement preview, attack preview (valid/blocked-line/adjacency/override), inspect (visible/memory/hidden/telegraph pending+due/danger), and commit availability has at least one non-color channel registered.
- New tests prove no critical meaning is color-only.
- New tests prove `feedback_preview` and `feedback_committed` are distinct, each has a non-color visual channel, and each audio cue id has a visual/textual equivalent that holds with audio absent.
- New text-scale tests prove clamping to bounds, fallback to `1.0` on malformed input, and that text scale never mutates a `TacticalSnapshot.from_domain()` comparison or changes preview legality / action availability.
- New sanitation tests prove accessibility/text dictionaries are deep copies and contain no raw domain, resource, command, scene, node, theme, font, or callable references.
- New no-mutation tests prove accessibility/text recalculation does not mutate board, turn state, RNG streams, pending telegraphs, outcome, or event log and does not execute commands.
- `git diff --check` reports no whitespace errors.

### Project Context Rules

- Read and follow root `project-context.md` before implementation.
- Read `_bmad-output/game-architecture.md` before architecture-sensitive changes.
- Production code goes under `godot/`; React/Vite `prototype/` remains validation evidence only.
- Production engine is Godot 4.6.3 stable standard; primary language is typed GDScript.
- Target platforms are iOS/Android mobile and tablet first with Windows desktop/laptop parity; phone-sized combat readability is a first-order requirement, not polish.
- MVP is offline-first single-player.
- Scene-independent domain model owns tactical truth; Godot scenes, UI, audio, VFX, and animation mirror domain outcomes and do not own gameplay state.
- Commands validate before mutation and return `ActionResult`; successful commands emit deterministic past-tense `DomainEvent` records.
- Use named RNG streams for gameplay-affecting randomness; presentation/accessibility derivations consume no gameplay RNG.
- Critical tactical information must not rely on color alone; the game must support scalable text (project NFR8/NFR9, GDD accessibility baseline).
- Save versioned domain snapshots only; never serialize scene nodes as save truth.
- Headless simulation must not depend on rendering, audio, UI scenes, presentation nodes, or scene-tree-only state.
- Do not introduce cloud services, accounts, multiplayer, telemetry dependencies, Godot .NET/C#, new test frameworks, audio playback subsystems, or third-party libraries unless the architecture is explicitly revised.
- Preserve user changes and unrelated dirty worktree files.

### References

- [Source: `_bmad-output/planning-artifacts/epics.md` - Epic 2 and Story 2.6 acceptance criteria]
- [Source: `_bmad-output/implementation-artifacts/epic-2-sprint-plan-2026-06-07.md` - Sprint Slice 5 accessibility/settings guardrails and non-color-only indicator list]
- [Source: `_bmad-output/implementation-artifacts/2-5-adaptive-layout-profiles.md` - previous story boundary, layout/touch-target hand-off to 2.6, 15th `layout` key, sanitization-triplication review note]
- [Source: `_bmad-output/implementation-artifacts/2-4-inspect-and-zoom-tactical-information.md` - inspect/telegraph cue semantics and presentation-change no-mutation lessons]
- [Source: `_bmad-output/implementation-artifacts/2-3-mobile-two-step-commit-and-cancel-flow.md` - commit-flow gating that the preview/commit distinction must not weaken]
- [Source: `_bmad-output/auto-gds/retro-notes/epic-2.md` - PowerShell `godot` invocation; `TacticalBoardViewModel.to_dictionary()` `layout` key]
- [Source: `_bmad-output/implementation-artifacts/deferred-work.md` - Story 2.5 layout-geometry defers (degenerate rebalance, wide-short classifier, populated log strip) are layout-owned, not accessibility scope]
- [Source: `project-context.md` - domain ownership, no color-only critical info, scalable text, file placement, testing, no-telemetry/no-audio-subsystem rules]
- [Source: `_bmad-output/game-architecture.md#UI Architecture` - adaptive UI composition layers and accessibility-aware UI structure]
- [Source: `_bmad-output/game-architecture.md#Adaptive UI Composition Pattern` - view model -> presenter/layout profile -> command bridge data flow]
- [Source: `_bmad-output/planning-artifacts/gdds/gdd-Game-2026-05-31/gdd.md#Platform-Specific Details` - accessibility baseline: scalable text, colorblind-safe danger communication, clear icons + labels, no color-only critical information]
- [Source: `godot/scripts/ui/view_models/tactical_board_view_model.gd` - current 15-key board VM contract and safe-copy path]
- [Source: `godot/scripts/ui/view_models/tactical_movement_preview.gd` - movement `cue_ids`]
- [Source: `godot/scripts/ui/view_models/tactical_attack_preview.gd` - attack `cue_ids`, blocker/warning semantics]
- [Source: `godot/scripts/ui/view_models/tactical_inspect_view.gd` - inspect visibility-tier and telegraph/danger `cue_ids`]
- [Source: `godot/scripts/ui/view_models/tactical_attack_commit_flow.gd` - commit-flow state and `cancel_available` cue (no preview/committed distinction yet)]
- [Source: `godot/scripts/ui/view_models/tactical_layout_profile.gd` - `minimum_touch_target`/`spacing` constants owned by Story 2.5]
- [Source: `godot/scripts/ui/view_models/tactical_preview_view.gd` - shared `safe_*` sanitization helpers to reuse]
- [Source: `godot/tests/unit/ui/test_tactical_board_view_model.gd` - exact sorted top-level key assertion to update intentionally]
- [Source: Godot 4.6 multiple resolutions / content scale docs](https://docs.godotengine.org/en/4.6/tutorials/rendering/multiple_resolutions.html)
- [Source: Godot 4.6 GUI skinning (Theme/Font) docs](https://docs.godotengine.org/en/4.6/tutorials/ui/gui_skinning.html)
- [Source: Godot 4.6 audio buses docs](https://docs.godotengine.org/en/4.6/tutorials/audio/audio_buses.html)

## Dev Agent Record

### Agent Model Used

Story context: Claude Opus 4.8 (1M context).

### Implementation Plan

- Add red accessibility tests first: a color-independence audit driven from real movement/attack/inspect outputs, the preview-vs-committed distinction (with audio-absent equivalence), text-scale clamp/fallback + rule invariance, deep-copy/no-forbidden-reference sanitation, and no command submission / no mutation.
- Implement a narrow scene-free `TacticalAccessibilityModel` (and an optional `TacticalTextScale` helper) under `godot/scripts/ui/view_models/`, mapping the existing Epic 2 cue-id vocabulary to required non-color channels and adding the `feedback_preview` / `feedback_committed` cue pair plus their audio-cue equivalents.
- Add an optional sanitized `accessibility` slot to `TacticalBoardViewModel` only if it improves presenter consumption; if added, update the exact top-level-key assertion intentionally. Otherwise keep the model separate and document the boundary.
- Reuse existing preview, inspect, commit-flow, layout, and `TacticalPreviewView` helpers without moving tactical legality, command execution, or settings persistence into accessibility code.

### Debug Log References

- 2026-06-14: Created Story 2.6 implementation guide from Epic 2 source requirements, Epic 2 sprint plan (Sprint Slice 5), root project context, game architecture (UI Architecture + Adaptive UI Composition Pattern), GDD accessibility baseline, Stories 2.1-2.5 implementation notes and review findings, the current UI/view-model cue surface, Epic 2 auto-gds retro notes, and the deferred-work ledger.
- 2026-06-14: Confirmed story-creation baseline: `epic-1: done`, Stories 2.1-2.5 `done`, Story 2.6 `backlog`, baseline commit `16edd3f2ea41ac5ec97ca524a1816a6f9d3d046a`, working tree clean apart from the untracked orchestrator-owned `_bmad-output/auto-gds/` tree. Verified the bare `godot` resolves only as `C:\Users\Rasmus\bin\godot.cmd` through PowerShell (Epic 2 retro), and that `TacticalBoardViewModel.to_dictionary()` returns exactly 15 keys including `layout`, asserted in `test_tactical_board_view_model.gd`.
- 2026-06-14 (dev-story): Re-confirmed the gate at implementation start — `epic-1: done`, Stories 2.1-2.5 `done`, Story 2.6 `ready-for-dev`, working tree clean (`git status --short` empty), `godot --version` = `4.6.3.stable.official.7d41c59c4`. Baseline headless run: all 36 existing test files PASS, exit 0.
- 2026-06-14 (dev-story): TDD red-first. Wrote `test_tactical_accessibility_cues.gd` before any production edit (16 cases), then implemented `TacticalAccessibilityModel`, `TacticalTextScale`, and the board-VM `accessibility` slot until green. Final headless run: 37 test files PASS, exit 0. `git diff --check` clean.

### Completion Notes List

- Story context created and marked ready for development.
- Ultimate context engine analysis completed - comprehensive developer guide created.
- Implemented the accessibility/readability baseline as three scene-free presentation contracts under `godot/scripts/ui/view_models/`:
  - `TacticalAccessibilityModel` (`tactical_accessibility_model.gd`): the authoritative cue catalog mapping every critical Epic 2 cue id (movement, attack, blocked-line, blocker-override, adjacency, telegraph pending/due, danger damage, inspect visibility tiers, commit availability) to required non-color channels (`shape`/`icon`/`label`/`pattern`/`text`) plus a stable `severity`. Returns a value-only envelope `{kind:"accessibility", color_independent:true, available, reason, cues, feedback, text_scale, cue_ids}`. Severity may map to a presenter color but is always additive — every critical cue carries a non-color channel.
  - The net-new AC3 preview-vs-committed distinction lives here as `feedback_preview` (channels `shape`+`label`) and `feedback_committed` (channels `pattern`+`label`+`text`); the channel sets intentionally differ so preview vs committed is distinguishable with color stripped. Each declares a parallel optional `audio_cue_id` (`audio_feedback_preview`/`audio_feedback_committed`) and a `feedback` slot marks `visual_available`/`audio_available` so the distinction holds with audio absent. `feedback_preview` is sourced from active preview / commit-flow `attack_preview` mode; `feedback_committed` from a successful `TacticalAttackCommitFlowResult` dictionary (reads the result; never executes a command).
  - `TacticalTextScale` (`tactical_text_scale.gd`): clamps an injected requested scale to named bounds (`MIN_TEXT_SCALE` 0.85, `MAX_TEXT_SCALE` 2.0, default 1.0), falls back to 1.0 on malformed input (NaN/inf/zero/negative/non-numeric) with a stable `invalid_scale` reason, and emits value-only presenter hints (`label_scale_hint`, `spacing_hint`, `minimum_label_height`) derived from `TacticalLayoutProfile`'s named constants — no forked geometry, no fonts/theme.
- Added the optional sanitized `accessibility` slot to `TacticalBoardViewModel.from_domain()` via the existing `_dictionary_from_options` -> safe-copy path (same pattern as `layout`). It defaults to `{}` and is the 16th stable top-level key; updated the exact sorted-key assertion in `test_tactical_board_view_model.gd` (15 -> 16) and added a default-empty assertion. All 15 prior keys and behaviors remain backward-compatible.
- Reused `TacticalPreviewView.safe_*` for all sanitization (no fourth duplicate sanitizer, per Story 2.5 Round 2 review note). No new fixture, framework, autoload, audio subsystem, settings store, or color-only entry was added.
- Tests prove: color-independence across real movement/attack/inspect/telegraph outputs (audit driven from `AttackPreviewContractMatrix` + `BoardFixtureFactory`), no color-only critical cue, distinct preview/committed feedback with audio-absent equivalence, text-scale clamp/fallback, text-scale rule invariance via `TacticalSnapshot.from_domain()` byte-comparison and unchanged preview legality / action availability, deep-copy + no-forbidden-reference sanitation (including callables), and no command execution / no mutation.

### File List

- `godot/scripts/ui/view_models/tactical_accessibility_model.gd` (new) — scene-free accessibility cue catalog, preview-vs-committed feedback contract, audio-optional equivalence.
- `godot/scripts/ui/view_models/tactical_text_scale.gd` (new) — scene-free scalable-text bounds clamp with fallback and presenter sizing hints.
- `godot/scripts/ui/view_models/tactical_board_view_model.gd` (modified) — added the 16th `accessibility` top-level slot via the existing safe-copy path; all prior keys backward-compatible.
- `godot/tests/unit/ui/test_tactical_accessibility_cues.gd` (new) — full Story 2.6 test surface (16 cases).
- `godot/tests/unit/ui/test_tactical_board_view_model.gd` (modified) — updated the exact sorted-key assertion to 16 keys and asserted `accessibility` defaults to `{}`.

### Change Log

| Date | Change |
|---|---|
| 2026-06-14 | Implemented Story 2.6 accessibility/readability baseline: added `TacticalAccessibilityModel` and `TacticalTextScale` scene-free contracts, the net-new `feedback_preview`/`feedback_committed` color- and audio-independent distinction, and the optional `accessibility` slot (16th key) on `TacticalBoardViewModel`. Added `test_tactical_accessibility_cues.gd` and updated the board-VM key assertion. Full headless suite green (37 files, exit 0); `git diff --check` clean. Status moved ready-for-dev -> review. |
