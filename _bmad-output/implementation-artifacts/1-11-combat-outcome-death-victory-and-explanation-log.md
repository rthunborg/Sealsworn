---
baseline_commit: b463b521f03f4be7bec94b4d0dccd9a4a9290ae6
---

# Story 1.11: Combat Outcome, Death/Victory, and Explanation Log

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a player,
I want the tactical slice to report death, victory, and why key combat outcomes happened,
so that I can understand the result of a small test level.

## Acceptance Criteria

1. Given all enemies in the fixed test level are defeated, when combat outcome is evaluated from active outcome state, then the level enters a simple victory state, emits one deterministic `level_victory_reached` domain event, and repeated evaluation does not duplicate victory events.
2. Given the player's HP reaches zero or below, when combat outcome is evaluated from active outcome state, then the level enters a simple defeat state, emits one deterministic `level_defeat_reached` domain event, and the event payload records the cause from the damage, detonation, or last relevant combat event.
3. Given the player and all enemies are defeated in the same resolved sequence, when combat outcome is evaluated, then defeat takes precedence because hero death is the MVP loss condition.
4. Given movement, attack, enemy actions, damage, marks, detonations, waits, blocked actions, and outcomes occur, when the combat explanation log is queried, then it returns ordered player/debug-readable entries derived from domain events and not from presentation-only state.
5. Given the same event log and same board/outcome snapshots are provided, when explanation entries and outcome evaluation are rebuilt, then event ordering, outcome state, cause metadata, and explanation text are reproducible.
6. Given the Epic 1 domain-first micro-combat scenario is launched or run headlessly, when a tester plays or scripted tests exercise it, then it includes one player, 2-3 prototype enemies, obstacles, fog reveal, at least two weapon attack shapes, victory and defeat paths, and enough log output for a tester to explain why they won or lost without reading debug-only internals.
7. Given lightweight development instrumentation is enabled for the micro-combat scenario, when board queries, line-of-sight updates, command execution, enemy turns, and outcome evaluation run, then local timings can be recorded behind a development/build-profile gate and no telemetry, cloud service, gameplay RNG, event ordering, save truth, or production progression is affected.

## Tasks / Subtasks

- [x] 1.11.1 Confirm prerequisites and add failing tests first. (AC: 1-7)
  - [x] Before implementation, verify Story 1.10 is actually implemented, reviewed, and committed or intentionally present in the active working baseline. If enemy turn resolution files/events are absent, implement Story 1.10 first instead of recreating enemy-turn scope here.
  - [x] Verify Story 1.10 tracking is consistent across its story file and `sprint-status.yaml`; current local work indicates Story 1.10 is in progress and must be finished before this story is implemented.
  - [x] Add `godot/tests/unit/tactical/test_combat_outcome_evaluator.gd` for victory, defeat, defeat-precedence, no-duplicate events, invalid/no-mutation cases, replay from pre-outcome state, and cause metadata.
  - [x] Add `godot/tests/unit/tactical/test_combat_explanation_log.gd` for event-derived entries covering movement, attack, damage, enemy mark/detonation/wait/blocked events from Story 1.10, victory, and defeat.
  - [x] Extend `godot/tests/unit/core/test_domain_event.gd` for stable ids, serialization, parser validation, malformed payload rejection, and JSON round trips for outcome events.
  - [x] Extend `godot/tests/unit/tactical/test_board_state.gd` or add focused replay tests proving outcome events advance event sequence consistently without mutating board-owned position/HP data.
  - [x] Extend `godot/tests/fixtures/tactical/board_fixture_factory.gd` with outcome fixtures: all-enemies-dead, player-dead, both-sides-dead, active-combat, and micro-combat boards.
- [x] 1.11.2 Implement a narrow combat outcome state and evaluator. (AC: 1, 2, 3, 5)
  - [x] Add `godot/scripts/tactical/outcomes/combat_outcome_state.gd` as a typed `RefCounted` value object with stable states `active`, `victory`, and `defeat`.
  - [x] Add `godot/scripts/tactical/outcomes/combat_outcome_evaluator.gd` to evaluate `BoardState`, current `CombatOutcomeState`, and recent event-log context.
  - [x] Define victory as at least one living player and zero living enemies.
  - [x] Define defeat as zero living players or the primary hero at `current_hp <= 0`; defeat takes precedence over victory if both are true.
  - [x] Keep dead entities on the board with HP clamped to `0`; do not remove entities or rewrite occupancy as part of outcome evaluation.
  - [x] Make evaluation idempotent: once outcome state is `victory` or `defeat`, later evaluation returns no new events unless a test explicitly resets state.
  - [x] Use `BoardState.next_sequence_id()` for outcome event sequence ids and preserve all-or-nothing validation before mutating outcome state.
- [x] 1.11.3 Extend deterministic domain events for outcomes. (AC: 1, 2, 3, 5)
  - [x] Update `godot/scripts/core/events/domain_event.gd` with stable lower-snake ids `level_victory_reached` and `level_defeat_reached`.
  - [x] Add factory helpers and strict payload validation following the existing single-class `DomainEvent` pattern.
  - [x] Suggested `level_victory_reached` payload fields: `outcome`, `living_player_count`, `remaining_enemy_count`, `defeated_enemy_ids`, `cause_event_sequence_id`, and `explanation`.
  - [x] Suggested `level_defeat_reached` payload fields: `outcome`, `defeated_player_id`, `cause_event_sequence_id`, `cause_event_id`, `source_entity_id`, `damage_type`, `final_damage`, and `explanation`.
  - [x] Update `BoardState` so outcome events are accepted replayable no-op board events that advance sequence ids. Board HP/position/visibility must not change from outcome events.
  - [x] Do not add run-summary, outpost, meta progression, Oath Shards, first-death line display, or boss victory reveal in this story.
- [x] 1.11.4 Implement the combat explanation log mapper. (AC: 4, 5, 6)
  - [x] Add `godot/scripts/tactical/outcomes/combat_explanation_log.gd` as a pure typed `RefCounted` helper that builds serializable explanation entries from `Array[DomainEvent]`.
  - [x] Entries should include at minimum `entry_id`, `sequence_id`, `event_id`, `actor_id`, `summary`, and `details` or equivalent deterministic fields.
  - [x] Cover existing events: `entity_moved`, `visibility_updated`, `entity_attacked`, `damage_applied`, `status_effect_applied`, `entity_knocked_back`, `level_victory_reached`, and `level_defeat_reached`.
  - [x] Cover Story 1.10 enemy events using the actual stable ids implemented there, expected examples being mark, detonation, wait, blocked, and enemy decision/action events.
  - [x] If an unknown future event appears, return a stable generic entry rather than failing the whole log.
  - [x] Keep text concise, deterministic, and suitable for debug/playtest use; localization and polished combat-log UI belong to later UI stories.
  - [x] Do not read Godot nodes, scenes, audio, animation, UI state, or files to create explanations.
- [x] 1.11.5 Add the domain-first Epic 1 micro-combat scenario. (AC: 6)
  - [x] Add `godot/scripts/tactical/scenarios/epic_1_micro_combat_scenario.gd` or the nearest established domain-only location for a deterministic scenario builder/runner.
  - [x] Use one player with baseline 18 HP, 2-3 prototype enemies from Story 1.10, at least one blocker/line-of-sight obstacle, a fog reveal step, and at least two weapon shapes from `WeaponRepository`.
  - [x] Drive player actions through `MoveCommand` and `AttackCommand`; drive enemy responses through the Story 1.10 enemy resolver.
  - [x] Include scripted win and scripted loss paths that produce event logs, explanation entries, and outcome events.
  - [x] Add `godot/tests/integration/test_epic_1_micro_combat_scenario.gd` for the scripted paths and deterministic replay.
  - [x] Keep any launch harness minimal and domain-first. Do not build polished tactical UI, intent UI, audio, VFX, animation, or production scenes here.
- [x] 1.11.6 Add local playtest notes and timing instrumentation. (AC: 6, 7)
  - [x] Create `docs/playtesting/epic-1-micro-combat-notes.md` if it does not exist, or use an existing local playtest-notes path if one has been established.
  - [x] Record tester/date/build or commit, seed/scenario id, weapons used, outcome, whether death/victory was understood, notable confusion, and at least one observed positioning or line-of-sight decision.
  - [x] Add a narrow local timing helper under `godot/scripts/diagnostics/` only if needed; it must be disabled by default, development-gated, and local-only.
  - [x] Timing instrumentation must not emit domain events, change RNG streams, affect command validation, alter event-log ordering, serialize into tactical save truth, or introduce telemetry dependencies.
- [x] 1.11.7 Run validation and update story records. (AC: 1-7)
  - [x] Run `godot --version`.
  - [x] Run `godot --headless --path C:\Sealsworn\godot --scene res://tests/headless/test_runner.tscn --quit-after 10`.
  - [x] Run `git diff --check`.
  - [x] Run `gds-code-review` when implementation reaches review.
  - [x] Update this story's Dev Agent Record, File List, Completion Notes, Review Findings, and Change Log with actual implementation work.
  - [x] After review patches, rerun the headless suite and `git diff --check` before marking the story done.

### Review Findings

- [x] [Review][Patch] Victory cause metadata could point at a later non-causal event if the log contained waits after defeated-enemy damage. Fixed by preferring the latest `damage_applied` event against defeated enemies and adding evaluator coverage.
- [x] [Review][Patch] Local timing instrumentation was caller-gated but not explicitly debug-build gated. Fixed by making `LocalTimingRecorder` enable only when requested and `OS.is_debug_build()` is true.

## Dev Notes

### Pre-Implementation Gate

Story 1.11 is the Epic 1 closeout after enemy turns. Do not implement it until Story 1.10's enemy turn resolver, prototype enemy definitions, Ash Seer pending telegraphs, enemy action events, and explanation metadata exist and pass review.

Current story-creation analysis on 2026-06-07 found active Story 1.10 work in the local tree, including `1-10-enemy-turn-resolution-for-prototype-enemies.md` with `Status: in-progress` and `sprint-status.yaml` now tracking Story 1.10 as `in-progress`. Preserve that work and finish Story 1.10 before implementation. If Story 1.10 has not actually been coded, this story should remain ready-for-dev only.

This story must not absorb Story 1.10 scope. Enemy movement, melee attacks, Ash Seer marks/detonations, enemy AI scoring, and enemy turn sequencing belong to Story 1.10. Story 1.11 consumes those events and closes the loop with outcome state, outcome events, explanation-log mapping, and a domain-first micro-combat scenario.

### Current Repository Baseline

Story creation analysis used baseline commit `b463b521f03f4be7bec94b4d0dccd9a4a9290ae6`.

Dirty worktree observed at story creation included active Story 1.10 tracking/test work:

- `_bmad-output/implementation-artifacts/sprint-status.yaml` is modified.
- `_bmad-output/implementation-artifacts/1-10-enemy-turn-resolution-for-prototype-enemies.md` is untracked.
- `godot/tests/fixtures/tactical/board_fixture_factory.gd`, `godot/tests/unit/core/test_domain_event.gd`, and `godot/tests/unit/save/test_tactical_snapshot.gd` are modified.
- Story 1.10 test additions are present under `godot/tests/unit/ai/`, `godot/tests/unit/content/`, and `godot/tests/unit/tactical/`.

Preserve those existing changes unless Rasmus explicitly asks otherwise.

Existing baseline facts:

- `ActionResult` deep-copies metadata, enforces stable lower-snake error codes, and rejects success events that are not `DomainEvent`.
- `DomainEvent` is a single typed event class with enum values, stable string ids, factory helpers, strict parsing, and payload validation. Follow that pattern before introducing event subclasses.
- `BoardState.apply_events()` stages validation on a copied board before applying to the real board. Outcome events must preserve this all-or-nothing behavior.
- `BoardState` currently applies board creation, movement, visibility, damage, and knockback; attack/status events are accepted replayable no-op board mutations.
- `TacticalEntityState` has id, type, faction, position, HP, max HP, and movement blocking. It has no outcome, equipment, status-state, loot, XP, or presentation fields.
- `TacticalTurnState` tracks turn number, phase, and active actor. Commands return `advances_turn` metadata but do not mutate turn state directly.
- `TacticalActionContext` currently carries `board`, `turn_state`, and `rng_streams`. If Story 1.10 extended it for pending telegraphs or enemy turn context, reuse that extension rather than adding a parallel context.
- `TacticalSnapshot.from_domain()` currently serializes board, turn state, pending telegraphs, RNG streams, and event log. Avoid changing schema for outcome state unless implementation requires save/resume coverage; if schema changes, add migration/parse tests.
- `AttackCommand` emits `entity_attacked` and `damage_applied`, may emit `status_effect_applied` or `entity_knocked_back`, applies events through `BoardState`, and returns `advances_turn`.
- Story 1.9 deliberately did not emit death or victory events. Story 1.11 owns that outcome transition.
- The headless runner auto-discovers `test_*.gd` under `godot/tests/unit` and `godot/tests/integration`; no runner registry edit is expected.

### Existing Files To Update Or Preserve

| Path | Current State | This Story Changes | Preserve |
|---|---|---|---|
| `godot/scripts/core/events/domain_event.gd` | Supports board, movement, visibility, attack, damage, status, and knockback events. | Add victory/defeat outcome events and strict payload validation. | Existing event ids, payload contracts, parser behavior, and malformed-event tests. |
| `godot/scripts/tactical/board/board_state.gd` | Applies board-owned mutations and accepts attack/status no-op events. | Accept outcome events as sequence-advancing no-op board events. | HP, position, occupancy, visibility, staged validation, and sequence mismatch checks. |
| `godot/scripts/tactical/entities/tactical_entity_state.gd` | Entity HP and type/faction state only. | No required change. | Do not add outcome or presentation state to entities. |
| `godot/scripts/tactical/turns/tactical_turn_state.gd` | Turn phase and active actor. | No required change unless Story 1.10 introduced a turn-complete handoff that outcomes must call. | Do not make turn state own victory/defeat logic. |
| `godot/scripts/tactical/tactical_action_context.gd` | Carries board, turn state, and RNG streams. | May pass event log/outcome state only if needed and if Story 1.10 context changes make this natural. | Avoid broad mutable context bags. |
| `godot/scripts/tactical/outcomes/combat_outcome_state.gd` | Does not exist. | Add narrow active/victory/defeat value object. | Keep it tactical-domain only, serializable if snapshotted, and free of scene/UI data. |
| `godot/scripts/tactical/outcomes/combat_outcome_evaluator.gd` | Does not exist. | Add deterministic evaluator that emits outcome events and applies outcome state. | No run-summary, meta progression, boss finale, or outpost flow. |
| `godot/scripts/tactical/outcomes/combat_explanation_log.gd` | Does not exist. | Add pure event-to-entry mapper. | No UI nodes, localization framework, files, audio, animation, or presentation-only data. |
| `godot/scripts/tactical/scenarios/epic_1_micro_combat_scenario.gd` | Does not exist. | Add domain-first scenario builder/runner if this is the cleanest location. | Keep it headless-compatible and deterministic. |
| `godot/scripts/diagnostics/` | Architecture-defined diagnostics path; current autoload diagnostics exists under `scripts/autoloads`. | Add local timing helper only if needed. | Domain logic must not depend on the diagnostics autoload. No telemetry. |
| `godot/tests/fixtures/tactical/board_fixture_factory.gd` | Board, movement, visibility, attack-preview, and attack-command fixtures. | Add outcome and micro-combat fixtures. | Existing deterministic fixtures and helper behavior. |
| `godot/tests/unit/core/test_domain_event.gd` | Event parser/serialization tests. | Add outcome event tests. | Existing event coverage remains green. |
| `godot/tests/unit/tactical/test_board_state.gd` | Board setup/event replay tests. | Add outcome event replay/no-op sequence coverage or focused neighboring tests. | Board mutation semantics. |
| `godot/tests/unit/tactical/test_combat_outcome_evaluator.gd` | Does not exist. | Add outcome evaluator coverage. | Use current `TestCase` harness, no new framework. |
| `godot/tests/unit/tactical/test_combat_explanation_log.gd` | Does not exist. | Add explanation-log coverage. | Deterministic event-derived entries only. |
| `godot/tests/integration/test_epic_1_micro_combat_scenario.gd` | Does not exist. | Add scripted win/loss micro-combat smoke coverage. | No rendering/audio/UI scene dependency. |
| `docs/playtesting/epic-1-micro-combat-notes.md` | Does not exist at story creation. | Add local notes when a human/tester evaluates the scenario. | Keep notes local/offline; no telemetry or account dependency. |

### Outcome Evaluation Contract

- Evaluation is a domain service, not a command submitted by the player. It may return `ActionResult` for consistency, but it should not report `metadata["advances_turn"] == true`.
- Input should be explicit: `BoardState`, current `CombatOutcomeState`, and enough recent `DomainEvent` log context to identify the cause.
- The evaluator must validate before mutation. If validation fails, return `ActionResult.error` with no board, outcome-state, event-log, turn-state, RNG, or pending-telegraph mutation.
- Use `BoardState.next_sequence_id()` for emitted outcome events unless Story 1.10 introduced a more explicit event-log sequence owner. Do not create a second unsynchronized sequence source.
- Apply emitted outcome events through `BoardState.apply_events()` so event replay and sequence checks stay consistent.
- Mutate `CombatOutcomeState` only after event validation/application succeeds.
- If no outcome is reached, return success with no events and state still `active`.
- If outcome is already `victory` or `defeat`, return success with no events and metadata identifying the existing outcome.
- Defeat precedence is mandatory when the player and all enemies are dead in the same evaluated board state.

### Explanation Log Contract

- Explanation entries are derived from domain event dictionaries, not from Godot scenes, UI controls, animations, audio, or ad hoc debug strings.
- Entries must sort by `sequence_id` ascending and keep stable order when multiple events are produced by one command.
- Minimum entry shape should be serializable and testable, for example:

```gdscript
{
	"entry_id": "damage_applied:12",
	"sequence_id": 12,
	"event_id": "damage_applied",
	"actor_id": "hero",
	"summary": "Hero dealt 4 physical damage to enemy_1.",
	"details": {
		"target_entity_id": "enemy_1",
		"hp_before": 10,
		"hp_after": 6,
		"damage_type": "physical"
	}
}
```

- The text can be plain English for Epic 1. Localization, combat-log UI, accessibility presentation, iconography, and player-facing filtering are later UI/story scope.
- Do not leak hidden/memory-only current board facts beyond what the event payload already records. If Story 1.10 separates debug and player-visible metadata, preserve that separation.
- Unknown future event ids should produce stable generic entries so later systems can add events without breaking the log mapper.

### Micro-Combat Scenario Contract

- The scenario is a deterministic tactical-domain smoke path, not a polished scene.
- It should include one player, 2-3 prototype enemies, at least one blocking obstacle, fog reveal, and at least two weapon shapes from the baseline repository.
- Recommended enemies after Story 1.10: one melee pressure enemy plus Ash Seer, with Gate Brute included if the implementation can keep the scripted scenario readable.
- Use existing repositories for weapons/support/enemies. Do not duplicate content tables inside scenario logic.
- Use `MoveCommand`, `AttackCommand`, Story 1.10 enemy turn resolver/adapter, `TacticalVisibilityQuery`, `CombatOutcomeEvaluator`, and `CombatExplanationLog`.
- Scripted tests should verify both a win path and a loss path. Manual tester play can come later through a minimal harness, but the headless scripted scenario must exist for regression.
- Do not add full tactical HUD, touch input, two-step commit UI, animation, audio, VFX, reward flow, run map, outpost, save/resume menu, or production art in this story.

### Previous Story Intelligence

Story 1.10 is the direct prerequisite and should provide:

- Prototype enemy definitions for `iron_cultist`, `gate_brute`, and `ash_seer`.
- Enemy turn sequencing after successful player commands with `metadata["advances_turn"] == true`.
- Enemy actions routed through commands or a narrow adapter.
- Ash Seer pending telegraphs compatible with `TacticalSnapshot.pending_telegraphs`.
- Deterministic enemy action/explanation metadata for movement, attack, mark, detonation, wait, and blocked outcomes.
- Enemy action tests that are reproducible from the same seed and board state.

Story 1.9 established attack execution and damage events:

- `AttackCommand` validates through `AttackPreviewQuery`, emits `entity_attacked` then `damage_applied`, may emit status/knockback events, applies through `BoardState`, and returns `advances_turn`.
- `damage_applied` clamps HP at zero but intentionally does not emit death, victory, or defeat.
- Attack damage and support/proc metadata already include enough data for explanation entries: weapon id, base damage, final damage, damage type, support modifiers, block status, and RNG draws.
- Review patches strengthened proc RNG capture, damage event validation, knockback source validation, preview-contract/no-mutation tests, malformed event tests, and support repository fail-closed behavior. Do not regress those fixes.

Story 1.8 established weapon/preview boundaries:

- `WeaponDefinition` and `WeaponRepository` define all nine baseline weapon identities.
- `AttackPreviewQuery` is pure, deterministic, and player-visible; explanation logs should consume committed events, not re-run previews as truth.

Story 1.7 established visibility/fog boundaries:

- `TacticalVisibilityQuery` creates explicit `visibility_updated` events.
- Hidden and explored-memory cells must not expose current facts to player-facing systems.

Story 1.5 established snapshot/event-log boundaries:

- `TacticalSnapshot.from_domain(board, streams, turn_state, pending_telegraphs, event_log)` is the local proof tool for no-mutation assertions and replayable event logs.
- Save truth must stay serializable domain dictionaries only.

### Git Intelligence

- `b463b52 fix: resolve story 1.9 review findings` updated Story 1.9 records, support repository fail-closed behavior, attack command/event validation, board replay validation, and related tests.
- `4e069df feat: implement attack command damage events` added the core attack/damage/support/knockback implementation and tests.
- `c2cd14f feat: implement weapon attack previews` added weapon definitions, repository boundaries, and preview contracts.
- `d74eff3 feat: implement fog visibility model` added line-of-sight and hidden/memory visibility behavior.
- `3b40340 feat: implement move command validation` is the local model for command validation/no-mutation discipline.

### Architecture Compliance

- Scene-independent domain model owns tactical truth. Outcome state, event logs, and micro-combat scenario logic belong under `godot/scripts/`, not UI scenes.
- Gameplay actions validate before mutation and return `ActionResult`. Outcome evaluation should follow the same validation/no-mutation discipline even if it is not a player command.
- Successful outcomes emit deterministic past-tense `DomainEvent` records.
- Domain events drive state changes, replay, logs, saves, tests, and later presentation.
- Use named RNG streams for gameplay-affecting randomness. This story should not introduce outcome RNG.
- Static content uses repository/import boundaries. Reuse existing weapon/support/enemy definitions.
- Save versioned domain snapshots only; never serialize scene nodes, `Resource` instances, callables, audio paths, animation names, or presentation nodes as save truth.
- Headless simulation must not depend on rendering, audio, UI scenes, presentation nodes, physics raycasts, navigation nodes, or scene-tree-only state.
- Do not introduce cloud services, accounts, multiplayer, telemetry dependencies, Godot .NET/C#, new test frameworks, or third-party libraries.

### Library And Framework Requirements

- Required engine: Godot 4.6.3 stable standard build.
- Required language: typed GDScript.
- Use the existing custom test harness based on `godot/tests/unit/test_case.gd`; do not add GUT, GdUnit, or another test dependency.
- Use `RefCounted` for outcome/log/scenario/domain helpers.
- Use `Resource` only where Story 1.10 content definitions require it. Outcome and explanation helpers should not be resources.
- Use `Vector2i` for grid coordinates and serializable dictionaries/arrays for event payloads, explanation entries, timing records, and test outputs.
- Do not use Godot physics, `Node2D`, `Area2D`, collision layers, scenes, UI controls, animation, audio, or autoload gameplay ownership for outcome evaluation or explanation-log construction.

### Latest Technical Information

Official sources checked on 2026-06-07:

- Godot 4.6.3 stable remains the project-pinned engine version and is listed in the official archive as `4.6.3-stable` dated 2026-05-20: https://godotengine.org/download/archive/4.6.3-stable/
- Godot 4.6 static typing supports typed variables, constants, functions, parameters, return values, custom classes via `class_name`, and typed arrays. Keep new scripts typed: https://docs.godotengine.org/en/4.6/tutorials/scripting/gdscript/static_typing.html
- Godot 4.6 `RefCounted` is appropriate for helper/domain objects that do not need node lifecycle and normally do not require manual `free()`: https://docs.godotengine.org/en/4.6/classes/class_refcounted.html
- Godot 4.6 `Resource` is the base data-container type for reusable content definitions, but outcome/log helpers should remain plain domain helpers unless they are content definitions: https://docs.godotengine.org/en/4.6/classes/class_resource.html
- Godot 4.6 `RandomNumberGenerator` seed/state can reproduce sequences when saved/restored, but Sealsworn gameplay code should continue using `RngStreamSet` rather than ad hoc RNGs: https://docs.godotengine.org/en/4.6/classes/class_randomnumbergenerator.html

### Project Structure Notes

- Outcome state/evaluator/log helpers belong under `godot/scripts/tactical/outcomes/`.
- Domain-first scenario builders belong under `godot/scripts/tactical/scenarios/` unless implementation discovers an existing better tactical-domain location.
- Outcome event extensions stay in `godot/scripts/core/events/domain_event.gd` unless a broader event refactor is explicitly approved.
- Board replay support belongs in `godot/scripts/tactical/board/board_state.gd`.
- Local timing helpers belong under `godot/scripts/diagnostics/` and must not become gameplay authority.
- Tests mirror domains: core event tests under `godot/tests/unit/core/`, outcome/log tests under `godot/tests/unit/tactical/`, scenario tests under `godot/tests/integration/`, and fixtures under `godot/tests/fixtures/tactical/`.
- Playtest notes may live under `docs/playtesting/`; create the folder only when writing the notes.
- Do not add production code under `prototype/`.
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
- Existing Story 1.1 through Story 1.10 tests remain green.
- New event tests cover stable ids, serialization, parsing, malformed payload rejection, and JSON round trips for `level_victory_reached` and `level_defeat_reached`.
- New board replay tests prove outcome events validate sequence ids, advance sequence ids, and do not mutate board HP, position, occupancy, terrain, visibility, or entity presence.
- New outcome tests cover active/no-outcome, victory, defeat, defeat-precedence, idempotent reevaluation, cause metadata, invalid/no-mutation branches, and replay from pre-outcome board/log snapshots.
- New explanation-log tests cover movement, visibility, attack, damage, status/knockback, Story 1.10 enemy events, victory, defeat, unknown events, event ordering, and deterministic text/metadata.
- New micro-combat integration tests cover scripted win and loss paths with domain-only dependencies, at least two weapon shapes, fog reveal, enemy turns, outcome events, explanation entries, and deterministic replay.
- `git diff --check` reports no whitespace errors.

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
- Do not introduce cloud services, accounts, multiplayer, telemetry dependencies, Godot .NET/C#, new test frameworks, or third-party libraries unless the architecture is explicitly revised.
- Preserve user changes and unrelated dirty worktree files.

### References

- [Source: `_bmad-output/planning-artifacts/epics.md` - Story 1.11 and Epic 1 requirements]
- [Source: `_bmad-output/implementation-artifacts/epic-1-sprint-plan-2026-06-04.md` - Sprint Slice 5]
- [Source: `_bmad-output/implementation-artifacts/1-10-enemy-turn-resolution-for-prototype-enemies.md` - Direct prerequisite story context]
- [Source: `_bmad-output/implementation-artifacts/1-9-attackcommand-with-damage-events.md` - Previous completed combat event implementation]
- [Source: `project-context.md` - Determinism, domain ownership, file placement, testing, and no-telemetry rules]
- [Source: `_bmad-output/game-architecture.md` - Command/event simulation, state management, enemy AI, testing, diagnostics, and headless simulation]
- [Source: `_bmad-output/planning-artifacts/gdds/gdd-Game-2026-05-31/gdd.md` - Win/loss, combat readability, enemy baseline, and run-summary intent]
- [Source: Godot 4.6.3 stable archive](https://godotengine.org/download/archive/4.6.3-stable/)
- [Source: Godot 4.6 static typing docs](https://docs.godotengine.org/en/4.6/tutorials/scripting/gdscript/static_typing.html)
- [Source: Godot 4.6 RefCounted docs](https://docs.godotengine.org/en/4.6/classes/class_refcounted.html)
- [Source: Godot 4.6 Resource docs](https://docs.godotengine.org/en/4.6/classes/class_resource.html)
- [Source: Godot 4.6 RandomNumberGenerator docs](https://docs.godotengine.org/en/4.6/classes/class_randomnumbergenerator.html)

## Dev Agent Record

### Agent Model Used

Codex GPT-5

### Debug Log References

- 2026-06-07: Created Story 1.11 implementation guide from Epic 1 source requirements, Sprint Slice 5, Story 1.10 prerequisite context, Story 1.9 completed implementation records, root project context, game architecture, GDD win/loss/readability requirements, current Godot code/tests, recent commits, and official Godot 4.6 documentation.
- 2026-06-07: Verified and committed Story 1.10 prerequisite as `44c2ba9` before starting Story 1.11.
- 2026-06-07: Added red-phase outcome, explanation-log, board replay, and micro-combat scenario tests; initial headless run failed on missing Story 1.11 scenario/outcome scripts as expected.
- 2026-06-07: Implemented outcome domain events, board replay support, `CombatOutcomeState`, `CombatOutcomeEvaluator`, `CombatExplanationLog`, Epic 1 micro-combat scenario, local timing recorder, and playtest notes.
- 2026-06-07: Ran inline `gds-code-review` pass, fixed victory cause selection and debug-build timing gate, and reran validation.

### Completion Notes List

- Added deterministic victory/defeat domain events with strict parsing and board no-op replay.
- Added combat outcome state/evaluator with idempotence, defeat precedence, and cause metadata.
- Added event-derived explanation log covering movement, visibility, attacks, damage, status/knockback, enemy mark/detonation/wait, and outcomes.
- Added domain-first Epic 1 micro-combat win/loss scenario using `MoveCommand`, `AttackCommand`, `EnemyTurnResolver`, `WeaponRepository`, `EnemyRepository`, `TacticalVisibilityQuery`, and outcome/log services.
- Added debug-gated local timing recorder and local playtest notes.
- Validation passed: Godot version, headless suite, and `git diff --check`.

### File List

- `_bmad-output/implementation-artifacts/1-11-combat-outcome-death-victory-and-explanation-log.md`
- `_bmad-output/implementation-artifacts/sprint-status.yaml`
- `docs/playtesting/epic-1-micro-combat-notes.md`
- `godot/scripts/core/events/domain_event.gd`
- `godot/scripts/diagnostics/local_timing_recorder.gd`
- `godot/scripts/tactical/board/board_state.gd`
- `godot/scripts/tactical/outcomes/combat_explanation_log.gd`
- `godot/scripts/tactical/outcomes/combat_outcome_evaluator.gd`
- `godot/scripts/tactical/outcomes/combat_outcome_state.gd`
- `godot/scripts/tactical/scenarios/epic_1_micro_combat_scenario.gd`
- `godot/tests/fixtures/tactical/board_fixture_factory.gd`
- `godot/tests/integration/test_epic_1_micro_combat_scenario.gd`
- `godot/tests/unit/core/test_domain_event.gd`
- `godot/tests/unit/tactical/test_board_state.gd`
- `godot/tests/unit/tactical/test_combat_explanation_log.gd`
- `godot/tests/unit/tactical/test_combat_outcome_evaluator.gd`

## Change Log

- 2026-06-07: Created Story 1.11 implementation guide and marked it ready for development.
- 2026-06-07: Implemented Story 1.11 combat outcome, explanation log, micro-combat scenario, timing notes, tests, and review patches; marked done after validation.
