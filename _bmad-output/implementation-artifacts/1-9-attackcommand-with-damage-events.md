---
baseline_commit: c2cd14fef6ba8a55c9429d62ef04a13086110613
---

# Story 1.9: AttackCommand with Damage Events

Status: review

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a player,
I want committed attacks to apply deterministic damage through validated commands,
so that combat outcomes are fair, testable, and explainable.

## Acceptance Criteria

1. Given an attack preview reports a legal target, when `AttackCommand` is executed for that actor and target from the same unchanged snapshot, then the command succeeds, emits deterministic `entity_attacked` and `damage_applied` domain events, applies those events through `BoardState`, and reduces target HP according to the weapon definition and applicable baseline support/effect rules.
2. Given an attack target is out of range, blocked, not aligned, not visible when visibility is required, missing, dead, friendly, selected by an invalid actor id, selected by a dead actor, requested from an invalid context, or requested in the wrong turn phase, when `AttackCommand` executes, then it returns `ActionResult.error(&"invalid_attack", metadata)` with a stable `metadata["reason"]`, emits no events, and leaves actor state, target state, tactical snapshot, RNG state, event log, board sequence id, and turn state unchanged.
3. Given Axe, Mace, Crossbow, Tome, or Shield baseline rules apply, when a legal attack resolves, then emitted events describe bleed, disorient, knockback, bonus damage, armor, or block outcomes as applicable, and every gameplay-affecting proc/block roll uses only `RngStreamSet.STREAM_COMBAT`.
4. Given attack command tests run headlessly, when valid attacks and invalid/no-mutation cases are tested for baseline weapon shapes and support effects, then all tests pass without UI, animation, audio, scene-tree, physics, or presentation dependencies.
5. Given attack preview and attack execution are contract-tested, when fixture cases cover legal, illegal, blocked, adjacent-penalty, blocker override, hidden-target, memory-target, missing-target, dead-target, friendly-target, wrong-phase, proc, and support-effect attacks, then preview reasons and command validation reasons match for target legality cases, and any expected damage variance is controlled or recorded through the `combat` RNG stream.

## Tasks / Subtasks

- [x] 1.9.1 Add failing headless tests for attack events and damage replay before implementation. (AC: 1, 4)
  - [x] Extend `godot/tests/unit/core/test_domain_event.gd` to lock stable ids, serialization, parsing, payload validation, and malformed-payload rejection for `entity_attacked`, `damage_applied`, `status_effect_applied`, and `entity_knocked_back`.
  - [x] Extend or add board-state tests proving `BoardState.apply_events()` can replay attack events from a copied board and reproduce the command-mutated board snapshot.
  - [x] Assert damage application clamps target HP at `0`, never below `0`, and does not emit death/victory events in this story.
  - [x] Assert event sequence ids are contiguous and continue from `board.next_sequence_id()`.
- [x] 1.9.2 Implement attack/damage domain events and BoardState application. (AC: 1, 3)
  - [x] Update `godot/scripts/core/events/domain_event.gd` using the existing enum/factory/id pattern; do not introduce scene nodes or presentation event buses.
  - [x] Add event factories with stable lower-snake ids: `entity_attacked`, `damage_applied`, `status_effect_applied`, and `entity_knocked_back`.
  - [x] Validate event payloads in `DomainEvent.try_from_dictionary()` using the current strict parser style.
  - [x] Update `godot/scripts/tactical/board/board_state.gd` so `damage_applied` mutates stored HP and `entity_knocked_back` mutates stored target position/occupancy through event application only.
  - [x] Make `entity_attacked` and `status_effect_applied` accepted replayable events that advance sequence ids; they may be no-op board mutations until a persistent effect model exists.
- [x] 1.9.3 Add minimal baseline support definitions for Tome and Shield without adding inventory/equipment state. (AC: 3)
  - [x] Add `godot/scripts/content/definitions/support_definition.gd` with `class_name SupportDefinition extends Resource`.
  - [x] Add `godot/scripts/content/repositories/support_repository.gd` or an equivalent narrow repository wrapper over `ContentRepository`.
  - [x] Register stable lower-snake ids `none`, `tome`, and `shield`.
  - [x] Define Tome as attacker support: Staff and Wand attacks gain `+1` damage after weapon adjacency modifiers.
  - [x] Define Shield as defender support: armor reduces incoming physical damage by `1`; a `50%` combat-stream block halves remaining physical damage using `floor`, with final successful damage minimum `1`.
  - [x] Do not add equipment slots, inventory, loot drops, item affixes, support UI, save schema fields, or runtime file access from gameplay systems.
- [x] 1.9.4 Add failing `AttackCommand` validation and no-mutation tests. (AC: 2, 4, 5)
  - [x] Add `godot/tests/unit/core/test_attack_command.gd`.
  - [x] Construct `AttackCommand` with explicit `actor_id`, `target_cell`, `WeaponDefinition`, optional attacker `SupportDefinition`, and optional defender `SupportDefinition`; use repository fixtures in tests.
  - [x] Validate in deterministic order: context, weapon, support definitions, actor, actor alive, turn phase/active actor, then target legality via `AttackPreviewQuery`.
  - [x] Return `invalid_attack` with reasons such as `invalid_context`, `invalid_weapon`, `invalid_support`, `invalid_actor`, `dead_actor`, `wrong_phase`, `same_cell`, `out_of_bounds`, `not_visible`, `missing_target`, `dead_target`, `friendly_target`, `not_aligned`, `out_of_range`, and `blocked_line`.
  - [x] For every invalid branch, compare `BoardState.to_snapshot()`, `board.next_sequence_id()`, `TacticalSnapshot.from_domain(...)`, `RngStreamSet.to_snapshot()`, turn-state dictionary, and external event-log array before/after.
- [x] 1.9.5 Implement `AttackCommand` base execution through preview metadata. (AC: 1, 2, 4, 5)
  - [x] Add `godot/scripts/core/commands/attack_command.gd` with `class_name AttackCommand extends GameCommand`.
  - [x] Reuse `AttackPreviewQuery` for targeting legality instead of duplicating line, visibility, blocker, range, target, and warning logic.
  - [x] On legal attacks, emit `entity_attacked` first and `damage_applied` second, then call `context.board.apply_events(events)`.
  - [x] Include preview contract fields in `entity_attacked` metadata/payload: actor id, target id, target cell, weapon id, expected base damage, range, distance, line cells, blocker cells, blocker ignored, warnings, effects, and explanation.
  - [x] Return `ActionResult.ok(events, metadata)` with `metadata["advances_turn"] == true`; do not mutate `TacticalTurnState` directly.
- [x] 1.9.6 Implement baseline effect/support resolution and combat RNG coverage. (AC: 1, 3, 4)
  - [x] Axe: if target survives base damage, roll `combat` RNG once; on success emit `status_effect_applied` with effect id `bleed`.
  - [x] Mace: if target survives base damage, roll `combat` RNG once; on success emit `status_effect_applied` with effect id `disorient`.
  - [x] Crossbow: after damage, if target survives and the cell one step directly away from the attacker is in bounds and occupiable, emit `entity_knocked_back`; if blocked or out of bounds, do not move the target and record the blocked outcome in command metadata.
  - [x] Tome: add `+1` damage only for Staff and Wand after adjacency damage modifiers; include support id and bonus amount in `damage_applied` payload.
  - [x] Shield: apply armor and block rules only when defender support is Shield; record armor reduction, block roll metadata, block success, and final damage in `damage_applied` payload.
  - [x] Proc/block RNG metadata must include stream name, draw index, roll value, threshold, and effect id; no non-combat stream may advance.
- [x] 1.9.7 Extend fixtures and preview-contract parity tests. (AC: 2, 3, 5)
  - [x] Extend `godot/tests/fixtures/tactical/board_fixture_factory.gd` with attack-command boards for kill, survive, knockback-open, knockback-blocked, shield-block, shield-no-block, tome-staff, tome-wand, and proc cases.
  - [x] Extend `godot/tests/fixtures/tactical/attack_preview_contract_matrix.gd` only for target-legality parity cases; keep support/effect damage cases in attack-command tests because preview intentionally does not own support/proc execution.
  - [x] Assert each contract target-legality case has the same `metadata["reason"]` from `AttackPreviewQuery` and `AttackCommand`.
  - [x] Assert invalid target-legality command tests do not reveal hidden or explored-memory target facts beyond the preview contract.
- [x] 1.9.8 Run validation and update story records. (AC: 1-5)
  - [x] Run `godot --version`.
  - [x] Run `godot --headless --path C:\Sealsworn\godot --scene res://tests/headless/test_runner.tscn --quit-after 10`.
  - [x] Run `git diff --check`.
  - [x] Update this story's Dev Agent Record, File List, Completion Notes, and Change Log with actual implementation work.

## Dev Notes

### Current Repository Baseline

Story creation analysis on 2026-06-07 found a clean worktree and baseline commit `c2cd14fef6ba8a55c9429d62ef04a13086110613`.

Recent commits:

- `c2cd14f feat: implement weapon attack previews`
- `d74eff3 feat: implement fog visibility model`
- `a47dd02 chore: create story 1.7 visibility foundation`
- `3b40340 feat: implement move command validation`
- `d8c5072 feat: complete tactical snapshot boundary`

Existing baseline facts:

- `ActionResult` enforces stable lower-snake error codes, deep-copies metadata, and rejects non-`DomainEvent` success events.
- `GameCommand` is the base command shape. `MoveCommand` is the local model for context validation, phase checks, command metadata, and no turn-state mutation.
- `TacticalActionContext` currently carries `board`, `turn_state`, and `rng_streams`.
- `DomainEvent` is currently a single typed event class with enum values, stable string ids, factory helpers, strict parsing, and payload validation. Follow that pattern before adding event subclasses.
- `BoardState` currently applies `board_created`, `entity_moved`, and `visibility_updated`. It returns defensive copies from `get_entity()`, so damage must be applied inside `BoardState` against stored entities.
- `BoardState.apply_events()` stages validation on a copied board before applying to the real board. New attack events must preserve this all-or-nothing behavior.
- `TacticalEntityState` has id, type, faction, position, HP, max HP, and movement blocking only. It has no equipment, armor, status, intent, death, or victory fields yet.
- `TacticalTurnState` tracks turn number, phase, and active actor. Commands return `advances_turn` metadata but do not mutate turn state directly.
- `AttackPreviewQuery` already validates board, weapon, actor, target visibility, target occupant, faction, alignment, range, blockers, warnings, and effects. Reuse it for command target legality.
- `AttackPreviewContractMatrix` already records Story 1.9 parity cases for preview reason, base damage, blocker override, warnings, and effect ids.
- `RngStreamSet` has named streams and snapshots. Use `RngStreamSet.STREAM_COMBAT` for all attack proc/block rolls and include draw metadata in command/event payloads.
- `TacticalSnapshot.from_domain()` is the canonical no-mutation proof helper.
- `WeaponDefinition` and `WeaponRepository` provide all nine baseline weapons. Do not recreate weapon data in `AttackCommand`.

### Existing Files To Update Or Preserve

| Path | Current State | This Story Changes | Preserve |
|---|---|---|---|
| `godot/scripts/core/commands/attack_command.gd` | Does not exist. | Add validated attack command. | Extend `GameCommand`; no UI, scene tree, physics, or direct file access. |
| `godot/scripts/core/events/domain_event.gd` | Stable generic event class with factories for board/move/visibility. | Add attack/damage/status/knockback event ids, factories, and payload validation. | Stable serialization for existing events and strict parser behavior. |
| `godot/scripts/tactical/board/board_state.gd` | Applies board, movement, visibility events and owns stored entities. | Apply/replay damage and knockback events; accept attack/status events. | All-or-nothing staged validation; existing movement/visibility tests. |
| `godot/scripts/tactical/entities/tactical_entity_state.gd` | Entity HP exists; no equipment/status fields. | No production change expected unless a tiny helper avoids duplication. | Do not add inventory, equipment, persistent status, death/victory, or UI state. |
| `godot/scripts/tactical/targeting/attack_preview_query.gd` | Pure preview query with stable metadata and no mutation. | No production change expected; command should consume its output. | Hidden/memory fact filtering and preview purity. |
| `godot/scripts/content/definitions/weapon_definition.gd` | Baseline weapon `Resource` definition. | No production change expected. | Weapon ids, damage, adjacency modifiers, and blocker behavior from Story 1.8. |
| `godot/scripts/content/repositories/weapon_repository.gd` | Baseline weapon repository. | No production change expected. | Reuse definitions; do not duplicate weapon tables in command code. |
| `godot/scripts/content/definitions/support_definition.gd` | Does not exist. | Add minimal support `Resource` definition for `none`, `tome`, `shield`. | Keep it narrow; no inventory/equipment system. |
| `godot/scripts/content/repositories/support_repository.gd` | Does not exist. | Add minimal support repository over `ContentRepository`. | Repository boundary only; no direct gameplay file access. |
| `godot/tests/fixtures/tactical/board_fixture_factory.gd` | Board, movement, visibility, and attack-preview fixtures. | Add attack-command combat/effect fixtures. | Existing fixtures remain deterministic and scene-independent. |
| `godot/tests/fixtures/tactical/attack_preview_contract_matrix.gd` | Story 1.9 target legality matrix exists. | Extend only as needed for command parity. | Unknown fixtures must fail closed; no silent fallback. |
| `godot/tests/unit/core/test_attack_command.gd` | Does not exist. | Add command validation, execution, no-mutation, support, proc, and contract tests. | Follow local `TestCase` harness; do not add GUT/GdUnit. |
| `godot/tests/unit/core/test_domain_event.gd` | Covers event serialization/parser for existing events. | Extend for new event types. | Existing event ids remain unchanged. |
| `godot/tests/unit/tactical/test_board_state.gd` | Covers board setup and existing event application. | Extend for damage/knockback replay or add focused tests nearby. | Existing board behavior stays green. |
| `godot/tests/unit/content/test_support_repository.gd` | Does not exist. | Add support definition/repository tests if support definitions are added. | Existing content repository behavior stays intact. |

### AttackCommand Contract

- `AttackCommand` should use an explicit `WeaponDefinition` argument because Story 1.8 deliberately avoided adding equipped weapon state to `TacticalEntityState`.
- Use explicit `SupportDefinition` arguments for attacker and defender support until a later inventory/equipment story adds authoritative equipment state.
- Valid command metadata should include `advances_turn`, `reason`, `actor_id`, `target_entity_id`, `target_cell`, `weapon_id`, `attacker_support_id`, `defender_support_id`, `base_damage`, `support_bonus_damage`, `armor_reduction`, `block_succeeded`, `final_damage`, `rng_draws`, and any knockback/proc outcomes.
- Invalid command metadata must be concise and must not leak hidden target facts. For hidden and explored-memory targets, preserve Story 1.8 behavior: no target entity id, faction, HP, or current truth beyond the requested cell/weapon.
- Target-legality reasons must match `AttackPreviewQuery` after context, weapon, support, actor, and phase pass. Wrong phase and invalid support are command-only reasons and do not need preview parity.
- Do not make `AttackCommand` search repositories or read files. The caller/test fixture supplies definitions.
- Do not mutate `TacticalTurnState`; successful attack returns `advances_turn == true` for the future turn coordinator.

### Damage And Event Semantics

- `entity_attacked` is the committed attack record. It should not mutate board HP or positions.
- `damage_applied` is the HP mutation event. `BoardState` applies it and clamps HP to `0`.
- `status_effect_applied` records a resolved effect such as `bleed` or `disorient`. It can be a board no-op until persistent status state exists.
- `entity_knocked_back` is the position/occupancy mutation event for Crossbow knockback.
- Event payloads should be serializable dictionaries only: no `Resource`, `Node`, callable, object reference, scene path, audio, animation, or presentation strings as save truth.
- Sequence ids must be assigned before applying events and must be contiguous for multi-event attacks.
- `BoardState.apply_events(result.events)` on a board restored from the pre-attack snapshot must reproduce the post-command board snapshot.
- Death, victory, defeat, combat logs, enemy turns, and explanation-log persistence are Story 1.10/1.11 scope. This story may expose explanation strings/metadata on events, but it must not implement outcome state.

### Baseline Combat Rules For This Story

- Use Story 1.8 preview `expected_base_damage` as the weapon damage input.
- Tome bonus applies after adjacency damage modifiers: Staff adjacent preview damage `2` plus Tome becomes `3`; Wand `2` plus Tome becomes `3`.
- Shield armor reduces incoming physical damage by `1`.
- Shield block rolls only from the `combat` stream and, on success, halves post-armor damage using `floor`.
- A successful damaging attack deals at least `1` final damage unless a future immunity rule explicitly changes this.
- Axe and Mace proc rolls are attempted only if the target survives `damage_applied`.
- Axe/Mace proc success threshold is `0.35` using a `combat` stream float roll.
- Crossbow knockback is deterministic and does not use RNG. It applies only if the target survives damage and the destination one cell directly away from the attacker is in bounds and occupiable.
- All baseline attacks are physical for Shield handling until damage types are formalized.

### Previous Story Intelligence

Story 1.8 established the preview and content boundary this story must reuse:

- `WeaponDefinition` and `WeaponRepository` already define Sword, Dagger, Spear, Axe, Mace, Bow, Crossbow, Staff, and Wand.
- `AttackPreviewQuery` returns legal previews as `ActionResult.ok([], metadata)` and illegal previews as `ActionResult.error(&"invalid_attack_preview", metadata)`.
- Preview result fields include target, weapon, range, distance, line cells, blocker cells, blocker override, expected base damage, warnings, effects, and explanation.
- `AttackPreviewContractMatrix` exists specifically so Story 1.9 does not drift from preview legality.
- Preview emits no events, consumes no RNG, and does not mutate board, sequence id, tactical snapshot, or RNG state.
- Review patches fixed hidden entity-id leaks, stale occupant trust, narrow contract coverage, silent fixture fallback, contradictory adjacency modifiers, and partial repository creation. Do not regress these fixes.

Story 1.6 and Story 1.7 established command/query discipline:

- Invalid commands must leave board, turn state, RNG streams, event log, sequence id, and tactical snapshot unchanged.
- Visibility and line blockers are domain queries, not physics raycasts.
- Hidden and explored-memory cells must not expose current target truth.
- Movement commands emit events and apply them through `BoardState`, then return those same events in `ActionResult`.

### Git Intelligence

- Commit `c2cd14f` completed Story 1.8 and is the immediate source of weapon/preview contracts.
- Commit `d74eff3` completed Story 1.7 and is the immediate source of visibility and hidden-target behavior.
- Commit `3b40340` completed Story 1.6 and provides the local command validation/no-mutation style.
- Commit `d8c5072` completed the tactical snapshot boundary. Use `TacticalSnapshot.from_domain()` for invalid attack no-mutation assertions.

### Architecture Compliance

- Scene-independent domain model owns tactical truth. `AttackCommand`, damage events, and support definitions belong under `godot/scripts/`, not scenes or UI.
- Gameplay actions are commands that validate before mutation and return `ActionResult`.
- Successful commands emit deterministic past-tense domain events.
- Domain events drive state changes, replay, logs, saves, tests, and presentation later.
- Gameplay-affecting randomness uses named RNG streams. Combat proc/block rolls must use `combat`; invalid attacks must not advance any stream.
- Static content definitions use repository/import boundaries. Support definitions must not be embedded as ad hoc strings in gameplay logic beyond stable ids/constants.
- Save truth remains versioned domain snapshots only; do not serialize scene nodes, resources, or presentation nodes.
- Headless simulation must not depend on rendering, audio, UI scenes, presentation nodes, physics raycasts, or scene-tree-only state.

### Library And Framework Requirements

- Required engine: Godot 4.6.3 stable standard build.
- Required language: typed GDScript.
- Use the existing custom test harness based on `godot/tests/unit/test_case.gd`; do not add GUT, GdUnit, or another test dependency.
- Use `Resource` for support definition data and `RefCounted` for command/domain helpers.
- Use `Vector2i` for grid coordinates and serializable dictionaries/arrays for event payloads.
- Do not use Godot physics, `Node2D`, `Area2D`, collision layers, scenes, UI controls, animation, audio, or autoload gameplay ownership for attack legality or damage.
- Do not introduce new third-party libraries.

### Latest Technical Information

Official sources checked on 2026-06-07:

- Godot 4.6.3 stable remains the project-pinned engine version and is listed in the official archive as `4.6.3-stable` dated 2026-05-20: https://godotengine.org/download/archive/4.6.3-stable/
- Godot 4.6 GDScript static typing supports typed variables, constants, functions, parameters, return values, and typed arrays. Keep new scripts typed: https://docs.godotengine.org/en/4.6/tutorials/scripting/gdscript/static_typing.html
- Godot 4.6 `RefCounted` is appropriate for domain/helper objects that do not need node lifecycle: https://docs.godotengine.org/en/4.6/classes/class_refcounted.html
- Godot 4.6 `Resource` is the base data-container type for custom content definitions: https://docs.godotengine.org/en/4.6/classes/class_resource.html
- Godot 4.6 `RandomNumberGenerator` exposes seed/state and deterministic draw methods; Sealsworn wraps this through `RngStreamSet`, so gameplay code should not create ad hoc RNGs for combat: https://docs.godotengine.org/en/4.6/classes/class_randomnumbergenerator.html

### Project Structure Notes

- New command code belongs under `godot/scripts/core/commands/`.
- New or updated domain events stay in `godot/scripts/core/events/domain_event.gd` unless a broader event refactor is explicitly approved.
- Board mutation support belongs in `godot/scripts/tactical/board/board_state.gd`.
- Support definitions belong under `godot/scripts/content/definitions/`; repository wrappers belong under `godot/scripts/content/repositories/`.
- Attack-command tests belong under `godot/tests/unit/core/`; content tests under `godot/tests/unit/content/`; board/replay tests under `godot/tests/unit/tactical/`; fixtures under `godot/tests/fixtures/tactical/`.
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
- Existing Story 1.1 through Story 1.8 tests remain green.
- New event tests cover serialization, parsing, payload validation, malformed payload rejection, stable ids, and JSON round-trip compatibility for attack events.
- New board tests cover damage replay, HP clamping, knockback replay, sequence validation, and all-or-nothing event application.
- New support tests cover `none`, `tome`, `shield`, invalid ids/fields, repository lookup, and no direct gameplay file access.
- New attack command tests cover legal base attacks, legal Tome/Shield attacks, Axe/Mace proc success/failure, Crossbow knockback applied/blocked, kill/no-proc cases, preview-contract parity, invalid/no-mutation cases, event replay, and combat RNG isolation.
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

- [Source: `_bmad-output/planning-artifacts/epics.md` - Story 1.9]
- [Source: `_bmad-output/implementation-artifacts/epic-1-sprint-plan-2026-06-04.md` - Sprint Slice 4]
- [Source: `_bmad-output/implementation-artifacts/1-8-weapon-definitions-and-attack-preview-rules.md` - Previous Story Intelligence]
- [Source: `project-context.md` - Determinism, domain ownership, file placement, content, and testing rules]
- [Source: `_bmad-output/game-architecture.md` - Command/event simulation pattern, content boundaries, tactical query services, testing]
- [Source: `_bmad-output/planning-artifacts/gdds/gdd-Game-2026-05-31/gdd.md` - Prototype weapon/support/enemy baseline]
- [Source: Godot 4.6.3 stable archive](https://godotengine.org/download/archive/4.6.3-stable/)
- [Source: Godot 4.6 static typing docs](https://docs.godotengine.org/en/4.6/tutorials/scripting/gdscript/static_typing.html)
- [Source: Godot 4.6 RefCounted docs](https://docs.godotengine.org/en/4.6/classes/class_refcounted.html)
- [Source: Godot 4.6 Resource docs](https://docs.godotengine.org/en/4.6/classes/class_resource.html)
- [Source: Godot 4.6 RandomNumberGenerator docs](https://docs.godotengine.org/en/4.6/classes/class_randomnumbergenerator.html)

## Dev Agent Record

### Agent Model Used

Codex GPT-5

### Debug Log References

- 2026-06-07: Created Story 1.9 implementation guide from Epic 1 source requirements, Sprint Slice 4, Story 1.8 records, root project context, game architecture, GDD weapon/support baseline, current Godot code/tests, clean git baseline, recent commits, and official Godot 4.6 documentation.
- 2026-06-07: Red phase confirmed with missing support and attack command implementation.
- 2026-06-07: Implemented attack event factories/parser validation, BoardState replay handlers, support definitions/repository, and AttackCommand damage/support/proc/knockback resolution.
- 2026-06-07: Headless suite passed after implementation.

### Implementation Plan

- Start with failing event, board replay, support repository, and attack command tests.
- Extend `DomainEvent` and `BoardState` so committed attack events are serializable, replayable, and authoritative.
- Add minimal support definitions for `none`, `tome`, and `shield` without adding inventory/equipment state.
- Implement `AttackCommand` as a typed command that reuses `AttackPreviewQuery` for target legality.
- Resolve damage, Tome/Shield modifiers, Axe/Mace proc rolls, and Crossbow knockback through deterministic events and `combat` RNG.
- Rerun the full headless suite and `git diff --check`.

### Completion Notes List

- Added deterministic `AttackCommand` execution that validates through `AttackPreviewQuery`, emits `entity_attacked` then `damage_applied`, applies events through `BoardState`, and returns `advances_turn` metadata without mutating turn state.
- Added replayable attack-domain events plus BoardState application for damage and knockback; `entity_attacked` and `status_effect_applied` are accepted sequence-advancing no-op board mutations.
- Added minimal `SupportDefinition`/`SupportRepository` baseline for `none`, `tome`, and `shield` without inventory, equipment, UI, save schema, or runtime file access.
- Added Tome, Shield, Axe, Mace, and Crossbow baseline resolution with combat-stream-only RNG metadata for proc/block outcomes.
- Added headless tests for event parsing, board replay, support repository behavior, AttackCommand valid/invalid/no-mutation cases, preview legality parity, support effects, proc RNG, and knockback outcomes.

### File List

- `_bmad-output/implementation-artifacts/1-9-attackcommand-with-damage-events.md`
- `_bmad-output/implementation-artifacts/sprint-status.yaml`
- `godot/scripts/content/definitions/support_definition.gd`
- `godot/scripts/content/repositories/support_repository.gd`
- `godot/scripts/core/commands/attack_command.gd`
- `godot/scripts/core/events/domain_event.gd`
- `godot/scripts/tactical/board/board_state.gd`
- `godot/tests/fixtures/tactical/board_fixture_factory.gd`
- `godot/tests/unit/content/test_support_repository.gd`
- `godot/tests/unit/core/test_attack_command.gd`
- `godot/tests/unit/core/test_domain_event.gd`
- `godot/tests/unit/tactical/test_board_state.gd`

## Change Log

- 2026-06-07: Created Story 1.9 implementation guide and marked it ready for development.
- 2026-06-07: Implemented AttackCommand with damage events, support effects, combat RNG coverage, board replay handlers, fixtures, and headless tests; marked story ready for review.
