# Story 14.1: Corpse-Clearing and Wait/Pass-Turn

Status: ready-for-dev

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a player,
I want dead enemies to stop blocking my movement and a way to always pass my turn,
so that I can never get permanently stuck mid-fight with no legal action.

## Context & Why This Story Exists

Epic 14 ("Playable & Presentable") is the **second pre-ship backlog epic**, added 2026-07-16 after an agent-driven desktop playtest found the built MVP is **not honestly finishable** and looks unfinished (`playtest-sessions/agent-playtest-2026-07-16.md`; `sprint-change-proposal-2026-07-16.md`). Story 14.1 is the **first story of Band 1** and fixes the single **guaranteed, unfinishable** defect — finding **F1**: dead enemies keep blocking movement, there is no wait/pass affordance, and the enemy phase only advances on a *successful* player action, so a hero boxed in by corpses + walls with the last enemy out of reach **can never act again** (permanent mid-fight soft-lock). It also fixes **F8** (corpses render as if alive) as a direct consequence of the corpse decal.

This is the FIRST of only two Epic-14 stories that touch the **domain** (the other is 14.7). It is additive over every pinned contract, following the ratified command/event idiom. It is **the only Epic-14 story that may intentionally re-pin a fingerprint** — a justified combat-replay re-pin (see AC3 and Task 5). Every generator/route/finale LAYOUT fingerprint stays byte-identical.

## Acceptance Criteria

**AC1 — Corpse-clearing + decal (F1 core, F8)**
Given an enemy is reduced to 0 HP during a live combat node
When the enemy dies
Then the dead unit is removed from board **occupancy** — its cell becomes **walkable and non-targetable** — and the presentation renders a persistent corpse/loot-marker decal at the death cell (a pure read; no scene node owns the board state)
And a subsequent move onto that cell is legal, and the win condition (zero **living** enemies) is unchanged.

**AC2 — Wait/pass-turn (F1 backstop)**
Given it is the player's turn and the hero has no legal move or attack (boxed in, or by choice)
When the player invokes a Wait/pass-turn affordance
Then a `WaitCommand` (validate-before-mutate, returns `ActionResult`, **zero RNG**, an **append-only tail** domain event) advances the turn and resolves the enemy phase (FR3), so turns can always advance
And a visible Wait/End-Turn control is present in the HUD, and an invalid Wait (not the player's turn) **fails closed with zero mutation**.

**AC3 — Seed-regression + justified combat-replay re-pin**
Given the corpse-clearing change alters combat-time movement legality
When the seed-regression and winnability suites run
Then all generator/route/finale **LAYOUT** fingerprints stay **byte-identical** (corpse handling is combat-time, not generation-time), and the winnability proof still holds for every approved seed
And any combat-replay composite fixture that moves (the reference-driver byte-determinism / auto-resolve replays, if a pinned replay had a post-death corpse-block interaction) is **re-derived and re-pinned in the SAME change** via the dump/regeneration path with the justification recorded — never a silent edit; the `WaitCommand` draws zero RNG and the hands-off/reference drivers do not invoke Wait in the fixtures.

**AC4 — Domain + save contracts**
Given the domain and save contracts
When this story lands
Then no new RNG stream or unnamed draw site is added, the 23-key `RunSnapshot` gate stays 23, the in-node fight stays ephemeral, and the new event is wired **end-to-end** (factory + payload validator + id maps + round-trip + malformed negatives + the exhaustive `expected_ids` pin).

## Tasks / Subtasks

- [ ] **Task 1 — Corpse-clearing in the domain (AC1, AC4)**
  - [ ] In `board_state.gd` `_apply_damage_applied` (line 471), after setting `entity.current_hp = hp_after`: when the entity is now dead (`is_dead()` / `hp_after == 0`) and `entity.blocks_movement`, clear the death cell's `occupant_id` (`get_cell(entity.position).occupant_id = &""`). Keep the entity in `_entities` (hp 0, at its position). Do NOT remove it from `_entities`.
  - [ ] Recommended: apply the clear UNIFORMLY to any dead `blocks_movement` entity (no entity-type branch), not enemy-only. A dead hero ends the fight (defeat is evaluated by HP, and `_validate_level_defeat_reached_event` checks `_entities`/`is_dead`, not `occupant_id`), so releasing its cell is harmless and avoids a special-case branch in the low-level apply handler. (Scope to enemies only if a test asserts a dead hero retains occupancy — unlikely.)
  - [ ] Verify with tests that (a) the death cell is now walkable (`_validate_cell_for_occupancy` / a `MoveCommand` onto it succeeds), (b) the corpse is non-targetable (`AttackPreviewQuery.preview_target_cell` returns `missing_target` because the cell's `occupant_id` is now empty), and (c) the win condition is unchanged (`CombatOutcomeEvaluator` counts via `is_alive()`; `board_state._defeated_enemy_ids()` still lists the dead enemy from `_entities`, so `level_victory_reached`'s `defeated_enemy_ids` payload still matches its validator).
  - [ ] Confirm hazard/DoT deaths are covered: the Scorched DoT and all HP loss flow through `DAMAGE_APPLIED`, so folding corpse-clear into `_apply_damage_applied` covers every death-by-damage path (hero attack, enemy attack, hazard tick).

- [ ] **Task 2 — Persistent corpse decal render (AC1; presentation, pure read; fixes F8)**
  - [ ] The corpse must remain readable AFTER its `occupant_id` is cleared. `tactical_board_view_model.gd` `_build_occupant_views` (line 105) currently drops any entity whose cell `occupant_id != entity.entity_id` — so a cleared corpse would vanish from `occupants`. Extend the builder to ALSO include a dead entity at its own position on a visible cell. `TacticalOccupantView.from_entity` already emits `is_dead`/`is_alive`/`current_hp` — no occupant-shape change is needed.
  - [ ] The presenter (`tactical_board_grid.gd` draw `Control`, reached via `gameplay_shell_presenter.gd`) draws a persistent corpse/loot-marker decal for occupants flagged `is_dead: true`, distinct from a live sprite (fixes F8 "corpses look alive"). Non-color channel (shape/label), NFR9.
  - [ ] Keep the 16-key `TacticalBoardViewModel.to_dictionary()` contract at 16 keys (`occupants` is an existing key; only its CONTENTS change). Intentionally update `test_tactical_board_view_model.gd` to assert dead entities now appear in `occupants` with `is_dead: true` — do not let the occupant set change silently.
  - [ ] Scene wiring is verified by construction + the `test_run_flow_scenes_load.gd` compile guardrail. Do NOT write a SceneTree presenter test.

- [ ] **Task 3 — `WaitCommand` + the new append-only tail domain event (AC2, AC4)**
  - [ ] Create `godot/scripts/core/commands/wait_command.gd`, `extends "res://scripts/core/commands/game_command.gd"`, mirroring `move_command.gd`: `command_id = &"wait"`; `validate(state)` requires a `TacticalActionContext` with required state, a live actor (`actor.is_dead()` → reject `dead_actor`), `turn_state.phase == PLAYER_PLANNING`, and `turn_state.active_actor_id == actor_id` (else `wrong_phase`). `execute` emits the wait event, applies it via `context.board.apply_events([event])`, and returns `ActionResult.ok([event], {"advances_turn": true})`. **Zero RNG.**
  - [ ] Add the new event to `domain_event.gd` end-to-end (recommended id: `hero_waited`, mirroring the existing `enemy_waited`):
    - `Type` enum: append **at the tail** after `OATH_SHARDS_SPENT` (line 48).
    - `EVENT_ID_HERO_WAITED := &"hero_waited"` const (near line 92).
    - A factory `static func hero_waited(sequence_id, actor_id, ...)` mirroring `enemy_waited` (line 1000). Payload carries at minimum a lower_snake `reason` (e.g. `&"voluntary"` / `&"no_legal_action"`).
    - `id_for_type` (line 2356) + `type_for_id` (line 2444): add the new case before the `_:` fallback.
    - `_event_requires_actor` (line 2532): add `or event_type_value == Type.HERO_WAITED` (the hero IS the actor — a non-empty `actor_id` is required, exactly like `ENEMY_WAITED`).
    - `_validate_payload_for_event` dispatch (line 1151) + a `_validate_hero_waited_payload` mirroring `_validate_enemy_waited_payload` (line 2029) — validate the `reason` is lower_snake; keep it minimal (the player wait payload can be simpler than the enemy's).
  - [ ] Board-apply wiring (the event is board-applied so `_next_sequence_id` advances — a non-board-applied wait event would collide sequence ids with the enemy-phase events): add the new `Type.HERO_WAITED` case to `board_state.gd` `_validate_event` (line 378, → a `_validate_hero_waited_event` mirroring `_validate_enemy_waited_event` at line 894) and to `_apply_validated_event` (line 339) as a **no-op `pass`** (like `ENEMY_WAITED`; a wait mutates no board state).
  - [ ] **Register the new event in `test_domain_event.gd` `expected_ids` (line 2960).** This pin asserts `expected_ids.size() == DomainEvent.Type.size() - 1` and iterates every enum member — it **fails loud** the moment you append the enum member until you add the matching `expected_ids` entry. That fail-loud is EXPECTED; extend the pin (do not work around it).

- [ ] **Task 4 — Wire Wait into the live session + HUD (AC2)**
  - [ ] Add a `submit_wait(...)` seam to `interactive_combat_session.gd`, mirroring `submit_move` (line 269): guard `_begun` / `is_terminal()`; execute a `WaitCommand` for `HERO_ID` through the same path; append the event(s) to `_event_log`; call `_resolve_after_committed_action(wait_result)` (line 349) so the enemy phase runs (`EnemyTurnResolver.resolve_after_player_action` reads `advances_turn` from the result — line 50). A wait is a committed action: it advances the turn even with no legal move/attack. An invalid wait fails closed (surfaces the command's reason, zero mutation, no enemy phase).
  - [ ] Add a visible **Wait / End-Turn** control to the combat HUD (`gameplay_shell_presenter.gd` + `tactical_board_grid.gd`/`gameplay_shell.tscn`), routed to `submit_wait`. Target ≥44px, non-color label (NFR9). Keep the styled/full HUD out of scope — the polished player HUD is Story 14.10; 14.1 ships the minimal functional control.

- [ ] **Task 5 — Seed-regression / winnability verification + justified re-pin (AC3)**
  - [ ] Run the FULL headless suite (mandatory command below). Grep the raw output for `SCRIPT ERROR|Parse Error|^FAIL` (the false-PASS guard) — six documented stderr negatives are expected (int64-overflow ×2, malformed-JSON ×3, `invalid_node_type` ×1); ZERO new.
  - [ ] Confirm the **LAYOUT** fingerprints are byte-identical: `test_small_level_layout_seed_regression.gd`, `test_medium_level_layout_seed_regression.gd`, `test_route_generation_seed_regression.gd`, and the finale ARENA layout in `test_finale_seed_regression.gd` (corpse-clear is combat-time — generation/route/arena layout cannot move). The tactical/reward/affinity "fingerprints" in `test_seed_regression_suite.gd` are LIVE two-run determinism proofs (not stored hashes) and stay green (both runs use the new corpse-clear behavior).
  - [ ] For any **combat-replay composite pin** that moves (most likely `test_reference_combat_driver.gd` — its `APPROVED_LIVE_COMBAT_SEED_CATALOG` is an INLINE annotated code const with round-count notes, and the "naive focus-fire `LiveCombatResolver` PROVABLY DIES at 18 HP" tension assertion; less likely the auto-resolve `run_to_completion` fixtures; least likely `test_finale_seed_regression.gd`, a single-entity boss arena where no corpse-block move occurs): confirm the move is a JUSTIFIED corpse-clear consequence (a hero/enemy now legally moves through a vacated cell), **re-verify the winnability proof still holds for every approved seed** (more mobility can only help — never make a winnable seed unwinnable), and **re-pin in the SAME PR** by re-deriving via the dump path (`tools/dump_seed_regression_report.gd` and the sibling `dump_*` tools) or hand-updating the inline catalog annotations, WITH the justification recorded in the Dev Agent Record. **Never silently edit a drifting assertion to make it pass.**
  - [ ] If the "naive focus-fire dies at 18 HP" tension pin no longer holds on its pinned seed (corpse-clear could let the naive driver escape a death it previously took), pick/annotate a seed where the naive driver still provably dies, with the justification recorded — do not delete the tension proof.

- [ ] **Task 6 — Determinism/save gate confirmation (AC4)**
  - [ ] Assert (in tests + the record): `RngStreamSet.required_streams()` stays 7; `WaitCommand` and corpse-clear draw ZERO RNG; the 23-key `RunSnapshot` gate stays 23; the in-node fight stays ephemeral (no new save key; no `SCHEMA_VERSION` bump). Re-run the mandatory suite and `git diff --check` clean.

## Dev Notes

### The two domain changes, precisely

Both changes live in the **tactical/combat** layer and are additive over pinned contracts.

**1. Corpse-clearing = clear the death cell's `occupant_id`; keep the entity in `_entities`.**
- The board is **event-sourced**. Today, when an enemy hits 0 HP, `board_state._apply_damage_applied` (line 471) updates only `current_hp` — it never clears the cell's `occupant_id`. So the dead enemy **still occupies its cell** → movement validation (`_validate_entity_moved_event` at line 559: `target_board_cell.occupant_id != "" → occupied`; `_validate_cell_for_occupancy` at line 1055) rejects moving onto it. **That is the F1 soft-lock.**
- The fix folds corpse-clear into the existing `DAMAGE_APPLIED` apply-handler (no new corpse event needed — the "new event" AC4 wires end-to-end is the Wait event). When `hp_after == 0` and `entity.blocks_movement`, set the death cell's `occupant_id = &""`.
- **Keep the dead entity in `_entities`** (hp 0, at its position). This is load-bearing: (a) `board_state._defeated_enemy_ids()` (line 1200) iterates `_entities` for dead enemies, and the `level_victory_reached` payload + its validator (`_validate_level_victory_reached_event`, line 906) compare against it — removing the entity would break the victory event; (b) the corpse decal is a pure read of the dead entity's position from the board VM (Task 2); (c) the win condition counts via `is_alive()` (`CombatOutcomeEvaluator._living_count`, line 177) so corpses are already excluded — the win condition needs no change.
- **"Non-targetable" comes for free.** `AttackPreviewQuery.preview_target_cell` (line 40) reads the target from `target_board_cell.occupant_id`; once cleared, the cell reads as `missing_target`. (Its existing `dead_target` guard at line 49 becomes a belt-and-suspenders that no longer triggers on a cleared corpse.)
- **This is WHAT moves the combat-replay fixtures (AC3).** After corpse-clear, `board.can_occupy(cell)` succeeds on vacated cells → the reference driver's `_reachable_cells`/`can_occupy` (line 432) expands, and the enemy AI (`EnemyTurnResolver` → `PrototypeEnemyAi`, which moves enemies via `can_occupy`) gains mobility through corpse cells. Any pinned replay whose path previously routed around a corpse will change.

**2. `WaitCommand` = a new tactical command + a new append-only tail event.**
- Mirror `move_command.gd` structurally (`extends game_command.gd`; `validate` → `execute`; `_invalid` helper). Gate: context valid, actor alive, `phase == PLAYER_PLANNING`, `active_actor_id == actor_id`.
- The command is a **committed action** that advances the turn: `execute` returns `advances_turn: true` in metadata, which `EnemyTurnResolver.resolve_after_player_action` (line 50) requires to run the enemy phase. This is the belt-and-suspenders backstop to corpse-clear: corpse-clear restores mobility; Wait guarantees turns advance when the hero is boxed in with no legal move/attack.
- **Board-apply the wait event.** `execute` must apply the event via `context.board.apply_events([event])` (like `MoveCommand`, line 73) so the board's `_next_sequence_id` advances past it. A wait event that is NOT board-applied would carry a `sequence_id` that then collides with the first enemy-phase event — a sequence desync. The board apply is a **no-op** (mirroring `ENEMY_WAITED` in `_apply_validated_event`, line 362) plus a board-level validator (mirroring `_validate_enemy_waited_event`, line 894).
- **The event is wired everywhere (AC4).** Use `enemy_waited` as the verbatim template — it is the closest existing mirror (an actor-bearing tactical wait event). Touch points: `Type` enum tail, `EVENT_ID_*`, factory, `_validate_payload_for_event` dispatch + payload validator, `id_for_type`, `type_for_id`, `_event_requires_actor`, board `_validate_event` + `_apply_validated_event`, and the `test_domain_event.gd` `expected_ids` exhaustiveness pin (line 2960). Add round-trip (`to_dictionary`/`try_from_dictionary`) coverage and malformed-payload negatives.

### Live-session + HUD wiring

- `InteractiveCombatSession` (`scripts/run/interactive_combat_session.gd`) is the scene-free step-driven live-combat driver (one player action per tap). It already exposes `submit_move` / `tap_attack` / `inspect`. Add `submit_wait` mirroring `submit_move`: on a committed wait, append events and call `_resolve_after_committed_action` (line 349), which ticks the Scorched DoT (no-op on neutral boards), runs the enemy phase, and re-evaluates the outcome. The reference/auto-resolve drivers do NOT call Wait (they always synthesize an advancing move/attack), so Wait moves no headless fingerprint by itself.
- The Wait/End-Turn HUD control is presentation only: add it to `gameplay_shell_presenter.gd` (the combat shell presenter that owns the in-run HUD and the interactive board) routing to `submit_wait`. Keep it minimal; the styled HUD + range highlights + turn indicator are Story 14.10.

### Files to touch (current state → change)

| File | Current state | Change |
|---|---|---|
| `godot/scripts/tactical/board/board_state.gd` | `_apply_damage_applied` updates only `current_hp`; dead entities keep `occupant_id` (F1) | Clear death-cell `occupant_id` on 0-HP death; add `HERO_WAITED` board validate + no-op apply cases |
| `godot/scripts/core/commands/wait_command.gd` | does not exist | NEW command mirroring `move_command.gd`; zero RNG; `advances_turn: true` |
| `godot/scripts/core/events/domain_event.gd` | tail enum member `OATH_SHARDS_SPENT`; `enemy_waited` is the mirror | Append `HERO_WAITED` + full end-to-end wiring |
| `godot/scripts/run/interactive_combat_session.gd` | `submit_move`/`tap_attack`/`inspect` seams | Add `submit_wait` → enemy phase via `_resolve_after_committed_action` |
| `godot/scripts/ui/view_models/tactical_board_view_model.gd` | `_build_occupant_views` drops entities whose cell `occupant_id` ≠ id | Include dead entities at their position on visible cells (decal source); keep 16 keys |
| `godot/scripts/ui/presenters/gameplay_shell_presenter.gd`, `godot/scripts/ui/presenters/tactical_board_grid.gd`, `godot/scenes/game/gameplay_shell.tscn` | live tap board + in-run HUD (Epic 13) | Draw the corpse decal for `is_dead` occupants; add the Wait/End-Turn control |
| `test_reference_combat_driver.gd`, `test_seed_regression_suite.gd`, auto-resolve run-flow fixtures | pinned combat-replay composites | Re-pin ONLY the moved pins, justified, in the same PR (AC3) |

Add/extend tests: `test_wait_command.gd` (NEW — valid + wrong-phase/not-active-actor/dead-actor/terminal rejects, zero mutation, `advances_turn`, zero RNG), `test_domain_event.gd` (`expected_ids` + round-trip + malformed negatives + `_event_requires_actor`), `test_board_state.gd` (corpse-clear on death; wait board validate + no-op apply), `test_interactive_combat_session.gd` (`submit_wait` advances turn + runs enemy phase; corpse cell walkable mid-fight), `test_attack_preview_query.gd` (corpse → `missing_target`), `test_combat_outcome_evaluator.gd` (win condition unchanged), `test_tactical_board_view_model.gd` (dead entities surface with `is_dead`; 16-key gate). Tests live under `res://tests/unit` / `res://tests/integration` mirroring the domain.

### Anti-patterns to avoid (this story specifically)

- **Do NOT remove the dead entity from `_entities`** — it breaks the `level_victory_reached` `defeated_enemy_ids` payload and the corpse decal read. Only clear the cell `occupant_id`.
- **Do NOT add a second new event for corpse-clearing.** Fold it into the existing `DAMAGE_APPLIED` apply-handler. The single new event AC4 wires is the Wait event.
- **Do NOT let the WaitCommand skip the board apply** — a non-applied wait event desyncs sequence ids with the enemy phase.
- **Do NOT add a 17th top-level `TacticalBoardViewModel` key** for the corpse — the occupant view already carries `is_dead`/`current_hp`; extend `_build_occupant_views` so corpses stay in the existing `occupants` array. Intentionally bump `test_tactical_board_view_model.gd`, never silently.
- **Do NOT weaken movement/targeting validators** — corpse-clear works through occupancy (`occupant_id`), so `_validate_entity_moved_event`, `_validate_cell_for_occupancy`, and `AttackPreviewQuery` need no logic change.
- **Do NOT silently edit a drifting seed/replay assertion.** A moved combat-replay pin is re-derived via the dump path with a recorded justification, in the same PR; a moved LAYOUT fingerprint means a bug (corpse-clear is combat-time and must NOT touch generation/route/arena layout).
- **Do NOT add a difficulty knob.** Difficulty is a hard non-goal — this story changes no enemy stat / HP / damage / reward / RNG / run-length number.

### Known board-API sharp edge (from `deferred-work.md`)

There is a standing deferral: *"Mutable `get_cell()` access can bypass new entity occupancy invariants — external callers can mutate `BoardCell.occupant_id` directly and desynchronize `_cells` from `_entities`; deciding whether to return read-only copies or add setup-only mutators belongs with the board snapshot/domain API cleanup."* 14.1 clears `occupant_id` **inside the board's own event-apply handler** (`_apply_damage_applied`), which keeps `_cells` and `_entities` consistent (the entity stays in `_entities` at its position; only the cell occupancy is released). Do NOT clear corpse occupancy via an external `get_cell(...).occupant_id = ""` from the presenter/session — that is exactly the desync this deferral warns about. Keep it in the domain apply path. (This story does not resolve the broader board-API cleanup; it just must not depend on the mutable-get_cell path.)

### Epic-13 → Epic-14 transition notes that apply to 14.1

- **This story MAY re-pin combat fingerprints — and that is expected, not a failure** (the one flagged determinism consequence, sprint-change §3.1 D1). Two gates will **fail loud** on the intended behavior change; extend/re-pin them deliberately rather than working around them: (1) `test_domain_event.gd` `expected_ids` fails the moment the `HERO_WAITED` enum member is appended → add the pin entry; (2) any combat-replay composite pin that a corpse-vacated move touches fails → re-derive + re-pin with a recorded justification (AC3). LAYOUT fingerprints must stay byte-identical — a moved layout fingerprint is a real bug.
- **Keep the false-PASS grep guard standing** (Epic-13 retro P3): grep the raw runner output for `SCRIPT ERROR|Parse Error|^FAIL`; never trust the summary PASS line alone. Exactly six documented stderr negatives are expected (int64-overflow ×2, malformed-JSON ×3, `invalid_node_type` ×1); ZERO new.
- **Art-import discipline** (13.1): 14.1 adds no new art (the corpse decal is drawn from existing tile/marker assets or a simple shape). If any new texture is introduced, import it and commit its `*.png.import` sidecar in the same change, and load it via a guarded `load()` (never `preload`). Retain the committed `*.gd.uid` sidecars (a re-import stays a git-clean no-op).
- The hero-death → `PHASE_FAILED` live run-end wiring and the run-end/summary beat are **out of scope** (Story 14.5). 14.1 is combat-time only.

## Project Structure Notes

- Domain command → `godot/scripts/core/commands/` (with `move_command.gd`). Domain event → `godot/scripts/core/events/domain_event.gd`. Board/tactical changes → `godot/scripts/tactical/`. Live session → `godot/scripts/run/`. Board VM (render projection) → `godot/scripts/ui/view_models/`. Presenters/scenes → `godot/scripts/ui/presenters/` + `godot/scenes/game/`. Tests mirror the domain under `godot/tests/unit` and `godot/tests/integration`.
- Assertable decision logic stays in scene-free `RefCounted` seams (the command, the board, the view model, the session). Scene wiring (the decal draw, the Wait control) is verified by construction + the `test_run_flow_scenes_load.gd` compile guardrail — **no SceneTree presenter test**.
- No new autoload. `scripts/rules/conditions/` stays empty; `scripts/rules/operations/` stays one file.

## Project Context Rules

Extracted from `project-context.md` (canonical rulebook; refreshed to the Epic-13 as-built rollup):

- **Domain owns tactical truth; presentation mirrors it.** Scenes/`Control`/audio/VFX/animation own no authoritative state. Presentation observes domain and submits commands through the command bridge; the board VM projects domain state (never owns it).
- **Command idiom:** gameplay actions validate-before-mutate and return `ActionResult` with **zero partial state on reject**. A successful command emits deterministic **past-tense** domain events, **append-only at the enum tail**, wired end-to-end (factory + payload validator + id maps + round-trip + malformed negatives + the `expected_ids` exhaustiveness pin at `test_domain_event.gd:2960`).
- **Named RNG only:** `RngStreamSet.required_streams()` == 7 (`map, level, combat, loot, rewards, events, cosmetic`). This story draws ZERO RNG (no new stream, no new draw site). Cosmetic-only randomness may use `cosmetic` and cannot affect outcomes.
- **Save gates:** the 23-key `RunSnapshot` gate stays 23; `SCHEMA_VERSION == 1`; the **in-node fight is ephemeral** (not saved). Do not add a top-level `RunSnapshot` key; snapshots are pure reads.
- **`TacticalBoardViewModel.to_dictionary()` has an EXACT 16-key contract** pinned by `test_tactical_board_view_model.gd`. Changing a slot must intentionally bump that assertion — never let a key appear/vanish silently. (Here: `occupants` CONTENTS change; the 16 top-level keys hold.)
- **Difficulty is a hard non-goal** — no story adds a knob that scales enemy stats/HP/damage/rewards/RNG/run length.
- **Every generator/route/finale/combat seed-regression fingerprint stays byte-identical EXCEPT the single justified 14.1 combat-replay re-pin (D1)**, re-pinned via the dump tools in the same PR with justification recorded.
- **Assertable logic lives in scene-free `RefCounted` seams** (no SceneTree presenter tests — verify by construction + the compile guardrail). No new autoload. Headless suite stays green (195 PASS baseline; false-PASS grep `SCRIPT ERROR|Parse Error|^FAIL` clean beyond the 6 documented negatives).
- **NFR9 (accessibility):** every cue is color-independent and audio-absent-equivalent (shape/label/text). The corpse decal and the Wait control each carry a non-color channel.

### Mandatory test command (must pass before this story moves to review/done)

```
godot --headless --path C:\Sealsworn\godot --scene res://tests/headless/test_runner.tscn --quit-after 10
```

`godot` is not on the Bash/`where` PATH; run via PowerShell (it resolves as `C:\Users\Rasmus\bin\godot.cmd`, or the standalone `C:/Users/Rasmus/Godot_v4.6.3-stable_win64.exe/Godot_v4.6.3-stable_win64_console.exe`). Apply the false-PASS grep guard on the raw output. The runner auto-discovers `test_*.gd` under `res://tests/unit` and `res://tests/integration` only.

### References

- `_bmad-output/planning-artifacts/epics.md#Epic 14: Playable & Presentable` (Story 14.1 ACs, body lines 2973–2998; Epic List entry lines 521–527) — the D1 combat-replay re-pin note is in-line on 14.1.
- `_bmad-output/planning-artifacts/sprint-change-proposal-2026-07-16.md` §3.1 (D1 corpse handling, D2 turn-advance guarantee), §3.1 "D1's seed-regression implication", §4.1 (14.1 finding→scope map) — the F1 soft-lock analysis + the re-pin discipline.
- `playtest-sessions/agent-playtest-2026-07-16.md` (F1 soft-lock + F8 corpse render — the source defects).
- `_bmad-output/implementation-artifacts/epic-13-retro-2026-07-16.md` §7–§8 (Band-1 sequencing; the false-PASS grep guard P3; the atomic-finalize discipline).
- `_bmad-output/implementation-artifacts/deferred-work.md` (the mutable-`get_cell()` occupancy-invariant sharp edge; the 8.x/9.x live combat-death call-site defer — out of scope, owned by 14.5).
- `project-context.md` — Command/event idiom, 7 RNG streams, 23-key `RunSnapshot` gate, 16-key board VM, the "Live Board Render, Tap Input & Reward HUD (Epic 13)" section, the difficulty non-goal, the headless test command.
- Source templates: `move_command.gd` (command idiom), `game_command.gd` (base), `domain_event.gd` `enemy_waited` (factory line 1000, payload validator line 2029, id maps 2356/2444, `_event_requires_actor` 2532), `board_state.gd` (`_apply_damage_applied` 471, `_validate_enemy_waited_event` 894, `_validate_event` 378, `_apply_validated_event` 339), `interactive_combat_session.gd` (`submit_move` 269, `_resolve_after_committed_action` 349), `enemy_turn_resolver.gd` (`resolve_after_player_action` 40), `attack_preview_query.gd` (targeting via `occupant_id`, 40–50), `combat_outcome_evaluator.gd` (win via `is_alive`), `tactical_board_view_model.gd` (`_build_occupant_views` 105), `tactical_occupant_view.gd` (`is_dead`/`is_alive`), `reference_combat_driver.gd` + `test_reference_combat_driver.gd` (`APPROVED_LIVE_COMBAT_SEED_CATALOG`), `test_domain_event.gd` (`expected_ids` 2960).

## Dev Agent Record

### Agent Model Used

### Debug Log References

### Completion Notes List

### File List
