---
baseline_commit: 4e069df78354b2c990bcbb81aeb0c419d6272fb8
---

# Story 1.10: Enemy Turn Resolution for Prototype Enemies

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a player,
I want enemies to respond after committed actions with readable prototype behaviors,
so that the tactical slice proves melee pressure, body blocking, and telegraphed danger.

## Acceptance Criteria

1. Given the player commits a successful move or attack command, when enemy turn resolution begins, then each alive prototype enemy receives one valid deterministic action opportunity in stable order, and enemy turns do not resolve after invalid player commands or successful commands without `metadata["advances_turn"] == true`.
2. Given an enemy chooses a move, attack, mark, wait, or detonation action, when that action is applied, then it is submitted through the existing validated domain command path or a narrow enemy command adapter that reuses shared query/event/application boundaries, and enemy logic does not mutate `BoardState` directly.
3. Given an Iron Cultist can reach or approach the player, when its turn resolves, then it attacks if cardinally adjacent or advances one legal cardinal step toward the player, and adjacent attacks emit deterministic damage events with physical-damage explanation metadata.
4. Given a Gate Brute occupies the board, when its turn resolves, then it uses the same prototype melee behavior as Iron Cultist with 12 HP and blocking occupancy, and occupancy/event validation prevents it from overlapping other blocking entities.
5. Given an Ash Seer has an unresolved mark, when its later enemy turn resolves, then the mark detonates for 4 physical damage if the player remains on the marked tile, or expires as avoided if the player moved away, and the outcome is recorded in deterministic readable events.
6. Given an Ash Seer has line of sight to the player within range 5 and no unresolved mark consuming its action, when its turn resolves, then it marks the player's current tile for a later enemy turn and records a readable mark event without applying immediate damage.
7. Given enemy AI decisions are tested from the same seed, board state, turn state, content definitions, and pending telegraphs, when resolution is run repeatedly, then chosen actions, scores or reasons, resulting events, pending telegraph state, and explanation payloads are reproducible.
8. Given an enemy cannot move, attack, mark, or detonate, when its opportunity resolves, then it emits or returns a deterministic wait/blocked explanation identifying the reason without mutating board, turn, RNG, event-log, or pending telegraph state incorrectly.

## Tasks / Subtasks

- [x] 1.10.1 Add failing enemy content and turn-resolution tests before implementation. (AC: 1, 3, 4, 7, 8)
  - [x] Add or extend unit tests under `godot/tests/unit/content/` for baseline enemy definitions: `iron_cultist`, `gate_brute`, and `ash_seer`.
  - [x] Add `godot/tests/unit/ai/test_prototype_enemy_ai.gd` or the nearest local equivalent for deterministic action selection.
  - [x] Add `godot/tests/unit/tactical/test_enemy_turn_resolver.gd` for sequencing, command/adapter application, no-turn-after-invalid-player-command, same-seed determinism, and no-mutation invalid/blocked cases.
  - [x] Extend `godot/tests/fixtures/tactical/board_fixture_factory.gd` with enemy-turn boards for adjacent melee, approach, blocked approach, multiple-enemy ordering, Gate Brute blocking, Ash Seer mark, Ash Seer detonation hit, Ash Seer detonation avoided, and Ash Seer no-LoS wait.
- [x] 1.10.2 Add a minimal enemy definition/repository boundary. (AC: 3, 4, 6)
  - [x] Add `godot/scripts/content/definitions/enemy_definition.gd` with `class_name EnemyDefinition extends Resource`.
  - [x] Add `godot/scripts/content/repositories/enemy_repository.gd` or a narrow wrapper over `ContentRepository`.
  - [x] Register stable lower-snake ids `iron_cultist`, `gate_brute`, and `ash_seer` through the repository boundary; gameplay systems must not read files directly.
  - [x] Define Iron Cultist as HP 10, behavior `melee_pressure`, move budget 1, cardinal melee range 1, physical damage 3.
  - [x] Define Gate Brute as HP 12, behavior `melee_pressure`, move budget 1, cardinal melee range 1, physical damage 3, `blocks_movement == true`.
  - [x] Define Ash Seer as HP 8, behavior `seer_mark`, mark range 5, line-of-sight required, delayed detonation damage 4, and no prototype movement unless a test records an explicit local extension.
  - [x] Make repository factories fail closed without partially mutating a provided `ContentRepository` when an invalid definition is encountered.
- [x] 1.10.3 Add shared tactical path/action query support for enemy domain truth. (AC: 2, 3, 4, 8)
  - [x] Extract or add a shared path helper such as `godot/scripts/tactical/movement/tactical_path_query.gd` if reusing `TacticalMovementQuery` would incorrectly require player-visible target cells.
  - [x] Keep player movement validation requiring `BoardCell.visible`; enemy AI pathing must use authoritative board truth and occupancy, not the player's current fog visibility flags.
  - [x] Choose approach targets from legal cardinal cells adjacent to the player, using deterministic shortest-path cost and stable tie-breakers.
  - [x] Do not use physics raycasts, navigation nodes, scenes, UI, audio, or presentation state for enemy legality.
- [x] 1.10.4 Implement enemy decision values and deterministic scoring. (AC: 1, 3, 4, 6, 7, 8)
  - [x] Add narrow `RefCounted` value objects under `godot/scripts/ai/`, such as `AiAction` and `AiDecision`, or an equivalent typed structure following current project style.
  - [x] Score only valid actions allowed by the enemy definition behavior/state.
  - [x] Use deterministic ordering for enemy opportunities, action candidates, and ties; current acceptable enemy order is alive enemy entity id order unless the implementation introduces an explicit initiative field.
  - [x] Do not consume RNG for prototype enemy decisions. If future random tie-breaking is desired, it is out of scope unless architecture adds an AI-specific stream or explicitly assigns an existing stream.
  - [x] Include explanation metadata with `enemy_id`, `enemy_definition_id`, `action_id`, `score`, `reasons`, `target_entity_id` when visible/known to the action, `from_cell`, `to_cell`, and blocked/wait reason where applicable.
- [x] 1.10.5 Implement enemy turn resolver and command adapter. (AC: 1, 2, 3, 4, 7, 8)
  - [x] Add `godot/scripts/tactical/turns/enemy_turn_resolver.gd` as the owner of enemy phase sequencing after successful player actions.
  - [x] Add `godot/scripts/tactical/turns/enemy_command_adapter.gd` or equivalent only if existing `MoveCommand`/`AttackCommand` cannot be reused cleanly.
  - [x] Prefer making `MoveCommand` and `AttackCommand` accept an active enemy actor during `TacticalTurnState.Phase.ENEMY_RESOLVING` through explicit phase-policy tests rather than temporarily faking player phase state.
  - [x] If an adapter emits events directly, it must reuse existing tactical queries, `DomainEvent` factories, `BoardState.apply_events()`, event sequence ids, and no-mutation tests equivalent to command tests.
  - [x] The resolver may mutate `TacticalTurnState` because it owns turn sequencing; individual commands must continue returning `advances_turn` metadata and must not run the whole enemy phase themselves.
  - [x] Invalid player command results, command results without `advances_turn`, dead enemies, invalid enemy definitions, and blocked enemy actions must not partially mutate board, turn state, RNG streams, event log, or pending telegraphs.
- [x] 1.10.6 Implement Iron Cultist and Gate Brute melee behavior. (AC: 3, 4, 7, 8)
  - [x] If cardinally adjacent to the player, attack for 3 physical damage through command/adapter events and include readable explanation metadata.
  - [x] If not adjacent, move one legal cardinal step along the deterministic approach path toward a legal adjacent-to-player cell.
  - [x] If no legal approach path exists, wait with reason `blocked`, `unreachable`, or a narrower stable reason.
  - [x] Preserve Gate Brute as the heavier body-blocking test: HP 12, blocking occupancy, same melee behavior, no overlapping blockers.
  - [x] Do not add deep enemy state machines, intent UI, loot, XP, death/victory outcome flow, or persistent status effects in this story.
- [x] 1.10.7 Implement Ash Seer mark and delayed detonation. (AC: 5, 6, 7, 8)
  - [x] Add past-tense domain events for mark/detonation behavior, for example `tile_marked`, `marked_tile_detonated`, and `enemy_waited`, or equivalent stable lower-snake event ids.
  - [x] Store pending Ash Seer marks in serializable pending telegraph state compatible with `TacticalSnapshot.pending_telegraphs`; no scene nodes, Resources, object refs, callables, animation names, or audio paths.
  - [x] A mark payload must include seer id, target entity id, marked cell, created turn number or sequence id, due turn marker, damage amount, damage type, and explanation text/id.
  - [x] On the Ash Seer's later opportunity, detonate before choosing a new mark. If the player remains on the marked cell, emit deterministic damage events for 4 physical damage; if not, emit an avoided/expired detonation event with no damage.
  - [x] If the Ash Seer has no due mark and has line of sight to the player within range 5, mark the player's current tile and apply no immediate damage.
  - [x] If the Ash Seer has no LoS/range and no due mark, wait with reason `no_line_of_sight`, `out_of_range`, or a narrower stable reason.
- [x] 1.10.8 Extend events, replay, and snapshots only as far as enemy turns require. (AC: 2, 5, 6, 7)
  - [x] Update `godot/scripts/core/events/domain_event.gd` with any new enemy/mark/wait event ids, factories, serialization, parser validation, and malformed-payload tests.
  - [x] Update `BoardState` only for board-owned mutations such as HP/position changes; do not store transient AI decisions or pending marks on board cells unless a future architecture change says board owns those.
  - [x] Add a narrow pending telegraph owner/helper if direct array manipulation would make mark mutation hard to validate.
  - [x] Ensure event replay from a pre-enemy-turn board plus pending telegraph snapshot reproduces the post-resolution board and pending state.
  - [x] Preserve existing attack, movement, visibility, board, RNG, and tactical snapshot tests.
- [x] 1.10.9 Run validation and update story records. (AC: 1-8)
  - [x] Run `godot --version`.
  - [x] Run `godot --headless --path C:\Sealsworn\godot --scene res://tests/headless/test_runner.tscn --quit-after 10`.
  - [x] Run `git diff --check`.
  - [x] Update this story's Dev Agent Record, File List, Completion Notes, and Change Log with actual implementation work.

### Review Findings

- [x] [Review][Patch] Invalid enemy definitions can produce unserializable wait events [godot/scripts/tactical/turns/enemy_command_adapter.gd:247]
- [x] [Review][Patch] Enemy move adapter accepts non-adjacent teleport moves [godot/scripts/tactical/turns/enemy_command_adapter.gd:98]
- [x] [Review][Patch] Ash Seer detonation trusts pending telegraph id without validating due/source/status [godot/scripts/tactical/turns/enemy_command_adapter.gd:176]
- [x] [Review][Patch] Detonation replay accepts hit/avoided outcomes that contradict board state [godot/scripts/tactical/board/board_state.gd:849]
- [x] [Review][Patch] Pending mark state changes are not event-replay owned [godot/scripts/tactical/turns/enemy_command_adapter.gd:159]
- [x] [Review][Patch] Resolver error paths can leave partial enemy-turn mutation [godot/scripts/tactical/turns/enemy_turn_resolver.gd:47]
- [x] [Review][Patch] Resolver can re-enter enemy resolution from non-player phases [godot/scripts/tactical/turns/enemy_turn_resolver.gd:31]

## Dev Notes

### Pre-Implementation Gate

Sprint tracking now marks Story 1.9 as `done`, and the Story 1.9 review findings are checked off in the current worktree. Those review-patch changes are still uncommitted relative to baseline commit `4e069df` at story creation time. Do not revert or overwrite them while implementing Story 1.10.

Before implementing this story, verify the Story 1.9 review patches are preserved and either committed with the Story 1.9 cleanup or intentionally included in the active working baseline. Story 1.10 depends on these fixed behaviors:

- Proc failure RNG is captured in emitted/domain-visible attack result data.
- Damage event parsing rejects missing or contradictory `final_damage` metadata.
- Knockback replay validates source-cell occupancy.
- Attack-command contract tests cover legal target-legality cases.
- Invalid target-legality cases get full no-mutation assertions.
- Malformed attack event tests cover `entity_attacked` and `status_effect_applied`.
- Support repository factory prevalidates/fails closed without partially mutating a provided content repository.

### Current Repository Baseline

Story creation analysis on 2026-06-07 found baseline commit `4e069df78354b2c990bcbb81aeb0c419d6272fb8`. During validation, the worktree was updated with uncommitted Story 1.9 review-patch changes across the Story 1.9 file, attack command/event/board/support code, and related tests. Preserve those changes.

Recent commits:

- `4e069df feat: implement attack command damage events`
- `c2cd14f feat: implement weapon attack previews`
- `d74eff3 feat: implement fog visibility model`
- `a47dd02 chore: create story 1.7 visibility foundation`
- `3b40340 feat: implement move command validation`

Existing baseline facts:

- `MoveCommand` validates actor, phase, visibility, occupancy, pathing, and budget, emits `entity_moved`, applies through `BoardState.apply_events()`, and returns `advances_turn`.
- `AttackCommand` validates through `AttackPreviewQuery`, emits `entity_attacked` and `damage_applied`, can emit `status_effect_applied` or `entity_knocked_back`, applies through `BoardState.apply_events()`, and returns `advances_turn`.
- Both commands currently expect `TacticalTurnState.Phase.PLAYER_PLANNING`; Story 1.10 must add an explicit enemy-resolution policy or adapter rather than faking state implicitly.
- `TacticalTurnState` already defines `PLAYER_PLANNING`, `PLAYER_RESOLVING`, `ENEMY_PLANNING`, `ENEMY_RESOLVING`, and `ENVIRONMENT_RESOLVING`.
- `TacticalActionContext` currently carries only `board`, `turn_state`, and `rng_streams`; pending Ash Seer marks will need a serializable owner or context extension.
- `TacticalSnapshot` already supports `pending_telegraphs: Array[Dictionary]`, which is the intended save/test boundary for Ash Seer marks.
- `BoardState.entities()` returns copies sorted by entity id, which is a suitable deterministic enemy-order source for this prototype unless explicit initiative is added.
- `TacticalEntityState` has no enemy-definition id, behavior id, equipment, status, or AI state field. Avoid hardcoding behavior from entity ids if a minimal definition/repository solves it cleanly.
- `TacticalMovementQuery` is player-command oriented and rejects non-visible targets. Enemy pathing must not accidentally use player fog visibility as an authority gate.
- `AttackPreviewQuery` is player-preview oriented and requires visible targets. Enemy LoS/range checks should use tactical line/domain truth directly where preview visibility semantics do not apply.
- `WeaponRepository` and `SupportRepository` show the current content boundary style.
- The test runner auto-discovers `test_*.gd` under `godot/tests/unit` and `godot/tests/integration`; no runner registry edit is expected.

### Existing Files To Update Or Preserve

| Path | Current State | This Story Changes | Preserve |
|---|---|---|---|
| `godot/scripts/content/definitions/enemy_definition.gd` | Does not exist. | Add minimal typed `Resource` for prototype enemy ids, HP, behavior, damage, range, and movement/mark parameters. | Keep it narrow; no full bestiary, loot, XP, resistances, animation, audio, or art references. |
| `godot/scripts/content/repositories/enemy_repository.gd` | Does not exist. | Add baseline enemy repository/factory over `ContentRepository`. | Fail closed; no direct gameplay file access; no partial mutation of provided content repo on invalid definitions. |
| `godot/scripts/content/repositories/content_repository.gd` | Generic `Resource` registry. | No required change unless a safe transaction helper is needed. | Existing weapon/support behavior and tests. |
| `godot/scripts/tactical/movement/tactical_movement_query.gd` | Pure player movement validation requiring visible target cells. | May extract shared path helper. | Player movement must still reject hidden/memory cells. |
| `godot/scripts/tactical/movement/tactical_path_query.gd` | Does not exist. | Recommended shared authoritative path helper for enemy approach. | Must be domain-only, deterministic, no RNG, no scenes, no UI. |
| `godot/scripts/tactical/turns/tactical_turn_state.gd` | Narrow turn phase and active actor state. | May add helper/policy for valid actor command phases. | Do not make it own AI decisions or board state. |
| `godot/scripts/tactical/turns/enemy_turn_resolver.gd` | Does not exist. | Add enemy phase sequencing after successful player commands. | Resolver owns turn flow; commands remain narrow. |
| `godot/scripts/tactical/turns/enemy_command_adapter.gd` | Does not exist. | Add only if command reuse cannot support enemy phase cleanly. | Must use query/event/application boundaries; no direct board mutation. |
| `godot/scripts/ai/` | Currently absent or unused for production AI. | Add narrow prototype AI decision/action/scoring classes if helpful. | No broad behavior-tree framework or external AI dependency. |
| `godot/scripts/core/commands/move_command.gd` | Player movement command; returns `advances_turn`. | May allow active enemy movement in `ENEMY_RESOLVING` via explicit policy/tests. | Existing player invalid/wrong-phase/no-mutation behavior. |
| `godot/scripts/core/commands/attack_command.gd` | Player attack command with damage events and combat RNG effects. | May allow active enemy attacks in `ENEMY_RESOLVING`, or adapter may reuse event logic. | Existing player attack contracts, support/proc RNG, preview parity. |
| `godot/scripts/core/events/domain_event.gd` | Supports board, movement, visibility, attack, damage, status, and knockback events. | Add mark/detonation/wait/decision events only as needed. | Existing ids, strict parsing, and malformed-payload tests. |
| `godot/scripts/tactical/board/board_state.gd` | Owns cells/entities and applies board-owned events atomically. | May validate/apply new board-owned events if they mutate HP/position. | Do not store AI decisions or presentation state in board. |
| `godot/scripts/save/snapshots/tactical_snapshot.gd` | Snapshot DTO with `pending_telegraphs`. | Use for Ash Seer mark persistence/no-mutation tests; change only if validation requires a narrow extension. | Save truth remains serializable domain dictionaries only. |
| `godot/tests/fixtures/tactical/board_fixture_factory.gd` | Board/movement/visibility/attack fixtures. | Add enemy-turn and Ash Seer fixtures. | Existing fixtures stay deterministic and scene-independent. |
| `godot/tests/unit/core/test_attack_command.gd` | Attack command coverage with known review gaps. | Update only if enemy phase policy touches `AttackCommand`. | Strengthen rather than weaken no-mutation and parity assertions. |
| `godot/tests/unit/core/test_move_command.gd` | Movement command coverage. | Update only if enemy phase policy touches `MoveCommand`. | Existing player command behavior remains green. |
| `godot/tests/unit/core/test_domain_event.gd` | Event parser/serialization tests. | Add new event ids and malformed payload coverage. | Existing event contracts remain green. |
| `godot/tests/unit/tactical/test_board_state.gd` | Board snapshot/event replay tests. | Add board-owned enemy event replay cases if applicable. | All-or-nothing staged event validation. |

### Enemy Definition Contract

Use the Prototype Enemy Baseline from the GDD:

| Enemy id | Role | HP | Prototype behavior |
|---|---:|---:|---|
| `iron_cultist` | melee | 10 | If adjacent, deal 3 physical damage; otherwise advance toward the player. |
| `gate_brute` | melee | 12 | Same prototype melee behavior, but with heavier blocking presence through HP 12 and blocking occupancy. |
| `ash_seer` | caster | 8 | From range 5 with LoS, mark the player's tile, then detonate on a later enemy turn for 4 damage if the player remains there. |

Implementation assumptions to lock in tests:

- Prototype melee enemies move at most 1 cardinal tile per enemy opportunity. No source artifact defines a larger enemy move budget, and one-step movement is the safer readable default for the first tactical slice.
- Prototype enemies use deterministic behavior and do not draw RNG.
- Enemy definitions are content definitions, not save truth. Runtime snapshots should store stable ids/state, not `Resource` instances.
- Do not add inventory, equipment, loot drops, enemy art/audio, enemy intent UI, or status-resistance systems here.

### Enemy Turn Flow Contract

- Enemy resolution begins only from a successful player command result with `metadata["advances_turn"] == true`.
- Invalid player commands must leave enemy turn state untouched and must not opportunistically resolve enemies.
- The resolver should use explicit phase transitions, for example `PLAYER_RESOLVING -> ENEMY_PLANNING -> ENEMY_RESOLVING -> PLAYER_PLANNING`, but exact intermediate mutation belongs in tests.
- Process alive enemies only: `entity_type == ENEMY` and `current_hp > 0`.
- Use stable opportunity order. Current acceptable baseline: sorted entity id order from `BoardState.entities()`.
- Each enemy gets at most one opportunity per enemy phase.
- Dead enemies, invalid definitions, and blocked actions produce deterministic skip/wait/error metadata without partial mutation.
- Enemy movement and attack actions must be represented as domain command results and/or deterministic past-tense events suitable for replay, logs, saves, and later presentation.

### AI And Pathing Rules

- Enemy AI uses board truth, not player UI visibility, to evaluate movement legality and occupancy.
- Fog/visibility is still relevant to player-facing information, but do not let `BoardCell.visible == false` prevent an enemy from acting unless an enemy behavior explicitly uses player-visible state.
- Ash Seer's LoS means tactical line of sight from the seer to the player using `TacticalLineQuery`/board blockers and range 5. It is not the same as "cell is visible to the player."
- Approach behavior should choose a legal cell adjacent to the player, path toward it, and move one step along the chosen path.
- Stable tie-breaking should be specified in tests. Recommended order: highest action priority, highest score, shortest path, lowest serialized candidate cell by y then x, then action id.
- Wait decisions are valid outcomes when an enemy is blocked, unreachable, has no target, has no LoS/range, or has no valid action after scoring.

### Command And Adapter Semantics

- Preferred path: make existing `MoveCommand` and `AttackCommand` support active enemy actors during `ENEMY_RESOLVING` via a small explicit phase policy. This lets enemy actions share command validation and event semantics.
- Acceptable fallback: `EnemyCommandAdapter` may emit events directly only if it reuses shared tactical queries, event factories, `BoardState.apply_events()`, event sequence ids, and no-mutation assertions equivalent to command tests.
- Do not temporarily set the turn state to `PLAYER_PLANNING` to trick commands into accepting enemies. That hides turn-flow bugs.
- Do not let enemy AI mutate `BoardState`, `TacticalTurnState`, pending telegraphs, or RNG streams before validation has succeeded.
- If enemy natural attacks reuse the current `entity_attacked`/`damage_applied` payload shape, use stable lower-snake attack/source ids such as `iron_cultist_melee`, `gate_brute_melee`, and `ash_seer_detonation` and document the temporary schema choice in tests.
- Do not add death, victory, combat outcome state, or persistent explanation log storage here. Story 1.11 owns those outcomes.

### Ash Seer Pending Mark Contract

Represent marks as pending telegraphs compatible with `TacticalSnapshot.pending_telegraphs`.

Recommended pending mark shape:

```gdscript
{
    "telegraph_id": "ash_seer_mark:<seer_id>:<sequence_id>",
    "kind": "ash_seer_mark",
    "source_entity_id": "<seer_id>",
    "target_entity_id": "hero",
    "marked_cell": {"x": 0, "y": 0},
    "created_turn_number": 1,
    "due_turn_number": 2,
    "damage": 4,
    "damage_type": "physical",
    "status": "pending"
}
```

Rules:

- Pending mark state must be copied/validated like snapshot data. No `Resource`, `Node`, callable, object ref, scene path, animation, audio, or presentation-only value is allowed.
- A due mark consumes the Ash Seer's opportunity before it can create a new mark.
- If the target remains on `marked_cell`, detonation emits a mark/detonation event plus a `damage_applied` event.
- If the target moved, detonation emits a deterministic avoided/expired event and removes or marks the pending telegraph as resolved.
- A mark event applies no immediate damage.
- Mark and detonation explanations must be readable enough for Story 1.11's future explanation log to consume.

### Previous Story Intelligence

Story 1.9 established attack execution and damage events:

- `AttackCommand` uses explicit `WeaponDefinition`, optional support definitions, `AttackPreviewQuery`, `DomainEvent.entity_attacked()`, `DomainEvent.damage_applied()`, and `BoardState.apply_events()`.
- Successful attacks return `advances_turn == true`; commands do not mutate `TacticalTurnState`.
- Baseline support/proc effects currently use `RngStreamSet.STREAM_COMBAT`.
- Death, victory, defeat, and explanation-log persistence are not Story 1.9 scope and remain Story 1.11 scope.
- Review patches in the current worktree strengthen proc RNG capture, damage event validation, knockback replay validation, contract/no-mutation coverage, malformed event coverage, and support repository fail-closed behavior. Preserve those fixes because enemy turns build directly on attack and damage events.

Story 1.8 established weapon/targeting/query boundaries:

- `WeaponDefinition` and `WeaponRepository` define all player baseline weapons.
- `AttackPreviewQuery` validates board, weapon, actor, target visibility, target occupant, faction, alignment, range, blockers, warnings, and effects.
- Attack preview is player-visible and pure; enemy LoS/attacks may need lower-level line/path logic because enemy AI should not be blocked by player fog.
- `AttackPreviewContractMatrix` exists for command parity. Story 1.9 review patches added broader legal/invalid coverage; preserve that parity discipline for enemy attacks and adapter tests.

Story 1.7 established visibility/fog boundaries:

- `TacticalVisibilityQuery` is pure until it creates explicit `visibility_updated` events.
- Hidden and memory cells must not expose current occupant facts to player-facing queries.
- Enemy AI can use domain truth, but player/debug explanations must avoid leaking hidden facts when later UI consumes them. In this story's headless tests, include metadata separation where practical.

Story 1.6 established movement and turn primitives:

- `MoveCommand` and `TacticalMovementQuery` are player-command oriented and require visible target cells.
- `TacticalTurnState` and `TacticalActionContext` are intentionally narrow. Extend them only for real enemy-turn needs.
- Invalid commands must preserve board, turn state, RNG streams, event log, pending telegraphs, sequence id, and tactical snapshot.

Story 1.5 established the snapshot boundary:

- `TacticalSnapshot.from_domain(board, streams, turn_state, pending_telegraphs, event_log)` already supports pending telegraph dictionaries.
- Use this for no-mutation assertions and Ash Seer mark persistence checks.
- Save truth is serializable domain data only.

### Git Intelligence

- Commit `4e069df` completed Story 1.9 implementation and is the immediate code baseline for attack/damage event semantics.
- Commit `c2cd14f` completed weapon attack previews and is the source of player attack targeting/query patterns.
- Commit `d74eff3` completed visibility and hidden/memory fact filtering.
- Commit `3b40340` completed movement command validation and is the local model for command no-mutation tests.
- The current worktree includes uncommitted Story 1.9 review-patch artifacts and code changes; preserve them unless the user explicitly asks to change them.

### Architecture Compliance

- Scene-independent domain model owns tactical truth. Enemy AI, turn resolution, pending telegraphs, and enemy content belong under `godot/scripts/`, not scenes or UI.
- Godot scenes, UI, animation, audio, and VFX later mirror enemy outcomes; they do not own enemy decisions or tactical state.
- Gameplay actions validate before mutation and return `ActionResult`.
- Successful enemy actions emit deterministic past-tense domain events.
- Enemy AI must be constrained by enemy behavior/state and produce reproducible decision explanations.
- Use named RNG streams for gameplay-affecting randomness. This story should avoid AI RNG entirely.
- Static content uses definition/repository boundaries. Do not hardcode prototype enemy behavior from entity ids if a minimal `EnemyDefinition` solves it.
- Save versioned domain snapshots only; never serialize scene nodes or `Resource` instances as tactical save truth.
- Headless simulation must not depend on rendering, audio, UI scenes, presentation nodes, physics raycasts, navigation nodes, or scene-tree-only state.

### Library And Framework Requirements

- Required engine: Godot 4.6.3 stable standard build.
- Required language: typed GDScript.
- Use the existing custom test harness based on `godot/tests/unit/test_case.gd`; do not add GUT, GdUnit, or another test dependency.
- Use `Resource` for enemy definition data and `RefCounted` for domain/query/AI/turn helpers.
- Use `Vector2i` for grid coordinates and serializable dictionaries/arrays for event, decision, and pending telegraph payloads.
- Do not use Godot physics, `Node2D`, `Area2D`, collision layers, scenes, UI controls, animation, audio, autoload gameplay ownership, or new third-party libraries for enemy turn logic.

### Latest Technical Information

Official sources checked on 2026-06-07:

- Godot 4.6.3 stable remains the project-pinned engine version and is listed in the official archive as `4.6.3-stable` dated 2026-05-20: https://godotengine.org/download/archive/4.6.3-stable/
- Godot stable docs are currently Godot Engine 4.6 documentation; GDScript static typing supports typed variables, constants, functions, parameters, return values, custom classes via `class_name`, and typed arrays. Keep new scripts typed: https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/static_typing.html
- `RefCounted` is appropriate for helper/domain objects that do not need node lifecycle and normally do not need manual `free()`: https://docs.godotengine.org/en/stable/classes/class_refcounted.html
- `Resource` is the base class for Godot data-container resources and fits reusable content definition scripts: https://docs.godotengine.org/en/stable/classes/class_resource.html
- `RandomNumberGenerator` seed/state can reproduce sequences when saved/restored, but Sealsworn gameplay code should continue using `RngStreamSet` rather than creating ad hoc RNGs: https://docs.godotengine.org/en/stable/classes/class_randomnumbergenerator.html

### Project Structure Notes

- Enemy definitions belong under `godot/scripts/content/definitions/`.
- Enemy repository code belongs under `godot/scripts/content/repositories/`.
- Enemy AI decision/scoring helpers belong under `godot/scripts/ai/`.
- Enemy turn sequencing and adapter code belongs under `godot/scripts/tactical/turns/`.
- Shared pathing helpers belong under `godot/scripts/tactical/movement/` or another tactical query path that matches existing organization.
- Mark/pending telegraph helpers may live under `godot/scripts/tactical/turns/` or a narrow tactical subfolder if introduced; keep them serializable and scene-independent.
- Tests mirror domains: content tests under `godot/tests/unit/content/`, AI tests under `godot/tests/unit/ai/`, tactical turn tests under `godot/tests/unit/tactical/`, core command/event tests under `godot/tests/unit/core/`, and fixtures under `godot/tests/fixtures/tactical/`.
- Runtime enemy scenes, sprites, intent UI, telegraph VFX, animation, audio, combat log UI, death/victory outcome flow, and polished micro-combat scenes are out of scope.
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
- Existing Story 1.1 through Story 1.9 tests remain green, including movement, visibility, preview, attack, board, RNG, save snapshot, content repository, and event parser tests.
- New enemy-definition tests cover stable ids, HP values, role/behavior ids, movement budget, melee damage, Ash Seer mark range/damage, validation failures, repository lookup, generic content registration, and fail-closed factory behavior.
- New path/AI tests cover adjacent attack, one-step approach, blocked approach, deterministic tie-breaking, no-RNG decision behavior, wait reasons, multiple-enemy order, and reproducible explanations.
- New enemy-turn tests cover no enemy resolution after invalid player commands, no resolution when `advances_turn` is absent/false, phase sequencing, command/adapter event application, no direct board mutation, replay from events, no-mutation invalid branches, dead enemy skipping, and stable event sequence ids.
- New Ash Seer tests cover mark creation, pending telegraph serialization, delayed detonation hit, avoided detonation, mark-before-damage ordering, no immediate mark damage, no-LoS/out-of-range wait, and deterministic explanation payloads.
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
- Use named RNG streams for gameplay-affecting randomness; prototype enemy AI should not consume RNG.
- Static content uses JSON/CSV source plus typed Godot Resources through repository/import boundaries.
- Save versioned domain snapshots only; never serialize scene nodes as save truth.
- Headless simulation must not depend on rendering, audio, UI scenes, presentation nodes, or scene-tree-only state.
- Do not introduce cloud services, accounts, multiplayer, telemetry dependencies, Godot .NET/C#, new test frameworks, or third-party libraries unless the architecture is explicitly revised.
- Preserve user changes and unrelated dirty worktree files.

### References

- [Source: `_bmad-output/planning-artifacts/epics.md` - Story 1.10 and Epic 1]
- [Source: `_bmad-output/implementation-artifacts/epic-1-sprint-plan-2026-06-04.md` - Sprint Slice 5]
- [Source: `_bmad-output/implementation-artifacts/1-9-attackcommand-with-damage-events.md` - Previous Story Intelligence and open review findings]
- [Source: `project-context.md` - Determinism, domain ownership, file placement, content, and testing rules]
- [Source: `_bmad-output/game-architecture.md` - Enemy AI and pathfinding, command/event simulation, state management, content boundaries, headless simulation]
- [Source: `_bmad-output/planning-artifacts/gdds/gdd-Game-2026-05-31/gdd.md` - Prototype enemy baseline]
- [Source: Godot 4.6.3 stable archive](https://godotengine.org/download/archive/4.6.3-stable/)
- [Source: Godot 4.6 static typing docs](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/static_typing.html)
- [Source: Godot stable RefCounted docs](https://docs.godotengine.org/en/stable/classes/class_refcounted.html)
- [Source: Godot stable Resource docs](https://docs.godotengine.org/en/stable/classes/class_resource.html)
- [Source: Godot stable RandomNumberGenerator docs](https://docs.godotengine.org/en/stable/classes/class_randomnumbergenerator.html)

## Dev Agent Record

### Agent Model Used

Codex GPT-5

### Debug Log References

- 2026-06-07: Created Story 1.10 implementation guide from Epic 1 source requirements, Sprint Slice 5, Story 1.9 records, root project context, game architecture, GDD enemy baseline, current Godot code/tests, recent commits, and official Godot documentation.
- 2026-06-07: Red-phase tests added for enemy definitions, prototype AI decisions, enemy turn resolution, mark/detonation/wait domain events, pending telegraph snapshots, and enemy-turn board fixtures; initial headless run failed on missing Story 1.10 scripts as expected.
- 2026-06-07: Implemented enemy definition/repository boundary, enemy definition ids on tactical entities, authoritative enemy path query, deterministic prototype enemy AI, enemy command adapter, enemy turn resolver, and Ash Seer pending telegraph handling.
- 2026-06-07: Validation passed with `godot --version`, full headless test runner, and `git diff --check`.
- 2026-06-07: Code review patches fixed adapter validation, pending telegraph replay ownership, detonation replay validation, resolver phase guards, and whole-phase preflight before live mutation; validation passed again.

### Completion Notes List

- Added baseline enemy content for `iron_cultist`, `gate_brute`, and `ash_seer` through `EnemyDefinition` and fail-closed `EnemyRepository`.
- Added deterministic prototype enemy AI and turn resolution for melee attacks, one-step approach movement, blocked waits, Ash Seer marks, hit detonations, and avoided detonations.
- Enemy actions apply through domain events and `BoardState.apply_events()` via a narrow `EnemyCommandAdapter`; AI itself does not mutate board, turn state, RNG, or pending telegraphs.
- Ash Seer marks are stored as serializable pending telegraph dictionaries compatible with `TacticalSnapshot.pending_telegraphs`.
- Review patches added `PendingTelegraphState`, adapter due/source/status checks, one-step movement enforcement, detonation outcome replay validation, resolver phase re-entry rejection, and copied-state enemy-phase preflight before committing events.
- Full headless suite passes: `godot --headless --path C:\Sealsworn\godot --scene res://tests/headless/test_runner.tscn --quit-after 10`.

### File List

- `_bmad-output/implementation-artifacts/1-10-enemy-turn-resolution-for-prototype-enemies.md`
- `_bmad-output/implementation-artifacts/sprint-status.yaml`
- `godot/scripts/ai/ai_action.gd`
- `godot/scripts/ai/ai_decision.gd`
- `godot/scripts/ai/prototype_enemy_ai.gd`
- `godot/scripts/content/definitions/enemy_definition.gd`
- `godot/scripts/content/repositories/enemy_repository.gd`
- `godot/scripts/core/events/domain_event.gd`
- `godot/scripts/tactical/board/board_state.gd`
- `godot/scripts/tactical/entities/tactical_entity_state.gd`
- `godot/scripts/tactical/movement/tactical_path_query.gd`
- `godot/scripts/tactical/tactical_action_context.gd`
- `godot/scripts/tactical/turns/enemy_command_adapter.gd`
- `godot/scripts/tactical/turns/enemy_turn_resolver.gd`
- `godot/scripts/tactical/turns/pending_telegraph_state.gd`
- `godot/tests/fixtures/tactical/board_fixture_factory.gd`
- `godot/tests/unit/ai/test_prototype_enemy_ai.gd`
- `godot/tests/unit/content/test_enemy_repository.gd`
- `godot/tests/unit/core/test_domain_event.gd`
- `godot/tests/unit/save/test_tactical_snapshot.gd`
- `godot/tests/unit/tactical/test_board_state.gd`
- `godot/tests/unit/tactical/test_enemy_turn_resolver.gd`

## Change Log

- 2026-06-07: Created Story 1.10 implementation guide and marked it ready for development.
- 2026-06-07: Implemented deterministic prototype enemy turn resolution, baseline enemy content, Ash Seer telegraphs, event/snapshot support, fixtures, and tests; marked story ready for review.
- 2026-06-07: Applied code review patches, reran validation, and marked story done.
