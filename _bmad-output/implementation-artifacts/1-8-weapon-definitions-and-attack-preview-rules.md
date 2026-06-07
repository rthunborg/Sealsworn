---
baseline_commit: d74eff3fa05d0ea12e0134f7ebac568667f77064
---

# Story 1.8: Weapon Definitions and Attack Preview Rules

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a player,
I want weapon-shaped attacks to preview legal targets, expected damage, blockers, and warnings,
so that I can choose attacks deliberately before committing.

## Acceptance Criteria

1. Given baseline weapon definitions exist for Sword, Dagger, Spear, Axe, Mace, Bow, Crossbow, Staff, and Wand, when the content repository or test fixture loads them, then each weapon exposes range, damage, targeting shape, tactical identity, and special override fields, and the definitions are accessible without direct gameplay file access.
2. Given a weapon generally requires straight-line alignment, when attack preview checks a diagonal or blocked target without an override, then the preview reports the target as illegal and includes a stable reason such as `not_aligned` or `blocked_line`.
3. Given a weapon has an explicit override such as Wand ignoring blockers, when attack preview evaluates the target, then the preview applies the override deterministically and explains the override in debug/player-readable terms.
4. Given ranged weapons have adjacency penalties where specified, when the preview targets an adjacent enemy with Bow or Staff, then expected damage and warning text reflect the penalty, and the preview does not mutate tactical state.
5. Given any attack preview is requested, when the preview is calculated, then it emits no domain events, consumes no gameplay RNG draws, and does not mutate tactical state, and repeated previews from the same snapshot return the same result.
6. Given attack preview and later `AttackCommand` validation are evaluated from the same unchanged snapshot, when a legal preview is committed later, then command legality, target, expected base damage, blocker result, and warning reasons can match the preview contract; illegal previews must fail for the same stable reason as command validation.

## Tasks / Subtasks

- [x] 1.8.1 Add failing headless tests for weapon definitions before implementation. (AC: 1)
  - [x] Add unit coverage under `godot/tests/unit/content/` or the nearest existing content test location for all nine baseline weapons.
  - [x] Assert stable lower-snake ids: `sword`, `dagger`, `spear`, `axe`, `mace`, `bow`, `crossbow`, `staff`, `wand`.
  - [x] Assert each definition validates required fields: range, base damage, targeting shape, tactical identity, visibility requirement, blocker behavior, adjacency modifier, and preview effect ids.
  - [x] Assert tactical preview code can receive definitions through a repository/factory boundary and does not read files directly.
- [x] 1.8.2 Implement a typed weapon definition and repository/factory boundary. (AC: 1)
  - [x] Add `godot/scripts/content/definitions/weapon_definition.gd` with `class_name WeaponDefinition extends Resource`.
  - [x] Add a narrow weapon repository/factory under `godot/scripts/content/repositories/` or extend the existing `ContentRepository` without replacing it.
  - [x] Keep the current `ContentRepository` generic registration behavior intact for future content types.
  - [x] Use typed GDScript fields and constants for targeting shapes and modifier ids; do not use ad hoc string literals throughout preview code.
  - [x] If source data is added, place it under `godot/data/source/` and keep file access inside importer/repository code only. Tactical preview logic must not call `FileAccess`.
  - [x] Do not add inventory, equipment slots, support-item state, loot drops, item affixes, or resource mirroring/import automation unless required by the minimal weapon lookup boundary.
- [x] 1.8.3 Implement a shared pure line/targeting helper without duplicating Story 1.7 line-of-sight semantics. (AC: 2, 3, 5)
  - [x] Preferred options: expose a narrow public helper from `TacticalVisibilityQuery`, or extract a shared `TacticalLineQuery` under `godot/scripts/tactical/targeting/` and make visibility/preview use it.
  - [x] Preserve Story 1.7 supercover blocker behavior: wall cells block through `BoardCell.blocks_line_of_sight()`, a blocking target cell can be visible/targetable if rules allow, and cells beyond blocking intermediate cells are blocked.
  - [x] Keep all line helper code scene-independent and pure: no `Node`, physics raycasts, scene tree, rendering, UI, audio, or RNG.
  - [x] If `TacticalVisibilityQuery` is updated, rerun existing visibility tests and preserve visible-fact filtering exactly.
- [x] 1.8.4 Add pure attack preview query logic. (AC: 2, 3, 4, 5, 6)
  - [x] Add `godot/scripts/tactical/targeting/attack_preview_query.gd` with `class_name AttackPreviewQuery extends RefCounted`.
  - [x] Accept `BoardState`, `actor_id`, target cell or target entity id, and explicit `WeaponDefinition`; do not add equipped weapon state to `TacticalEntityState` in this story.
  - [x] Validate in deterministic order: board, weapon, actor, actor alive, target cell bounds, visibility, target occupant, target alive, target faction, alignment, range, blockers, then warnings/effects.
  - [x] Return `ActionResult.error(&"invalid_attack_preview", metadata)` for illegal previews and `ActionResult.ok([], metadata)` for legal previews.
  - [x] Use `metadata["reason"]` for stable reasons such as `valid`, `invalid_board`, `invalid_weapon`, `invalid_actor`, `dead_actor`, `same_cell`, `out_of_bounds`, `not_visible`, `missing_target`, `dead_target`, `friendly_target`, `not_aligned`, `out_of_range`, and `blocked_line`.
  - [x] Legal previews must include stable fields: `legal`, `reason`, `actor_id`, `target_cell`, `target_entity_id`, `weapon_id`, `targeting_shape`, `range`, `distance`, `line_cells`, `blocker_cells`, `blocker_ignored`, `expected_base_damage`, `warnings`, `effects`, and `explanation`.
  - [x] Illegal previews must include enough metadata for UI/debug display without exposing hidden or memory-only target facts.
- [x] 1.8.5 Implement baseline weapon preview semantics. (AC: 1, 2, 3, 4)
  - [x] Sword: range 1, damage 4, adjacent cardinal target, reliable melee identity.
  - [x] Dagger: range 1, damage 2, adjacent cardinal target, low normal damage with future Unseen synergy noted as preview effect text only.
  - [x] Spear: range 2, damage 3, straight line melee reach.
  - [x] Axe: range 1, damage 3, adjacent cardinal target, preview effect `35% bleed if target survives`; do not roll RNG.
  - [x] Mace: range 1, damage 3, adjacent cardinal target, preview effect `35% disorient if target survives`; do not roll RNG.
  - [x] Bow: range 4, damage 3, straight line with LoS/blockers, adjacent penalty warning, deterministic adjacent expected damage of 2 using floor(base * 0.7) with minimum 1.
  - [x] Crossbow: range 3, damage 4, straight line with LoS/blockers, preview effect `knockback 1 if space allows`; do not apply movement.
  - [x] Staff: range 4, damage 4, straight line with LoS/blockers, adjacent penalty warning, deterministic adjacent expected damage of 2 using floor(base * 0.5) with minimum 1.
  - [x] Wand: range 4, damage 2, straight line, ignores terrain/entity blockers, still requires target visibility, and reports `blocker_ignored == true` plus an explanation.
- [x] 1.8.6 Extend tactical fixtures for preview cases. (AC: 2, 3, 4, 5, 6)
  - [x] Extend `godot/tests/fixtures/tactical/board_fixture_factory.gd` or add a focused sibling fixture factory for attack preview boards.
  - [x] Cover legal line targets, adjacent melee targets, ranged targets, blocked targets, diagonal targets, Wand blocker override, hidden target, explored-memory target, friendly target, dead target, and adjacency penalty targets.
  - [x] Keep fixtures deterministic, scene-independent, and compatible with `TacticalSnapshot.from_domain()`.
  - [x] Apply visibility explicitly through Story 1.7 helpers or direct fixture flags where the test purpose is not visibility recalculation.
- [x] 1.8.7 Add purity, no-mutation, and contract tests. (AC: 5, 6)
  - [x] For every preview family, compare `BoardState.to_snapshot()`, `board.next_sequence_id()`, `TacticalSnapshot.from_domain(...)`, and `RngStreamSet.to_snapshot()` before and after preview.
  - [x] Assert preview results contain no domain events and never call `board.apply_event()` or `board.apply_events()`.
  - [x] Add repeated-preview tests proving identical metadata from the same unchanged snapshot.
  - [x] Add a Story 1.9 contract fixture/expected matrix documenting the exact preview reason and expected base damage that `AttackCommand` must reuse later.
  - [x] Do not implement `AttackCommand`, attack/damage domain events, HP mutation, enemy turns, combat RNG proc resolution, UI preview panels, animation, audio, or support item effects in this story.
- [x] 1.8.8 Run validation and update story records. (AC: 1-6)
  - [x] Run `godot --version`.
  - [x] Run `godot --headless --path C:\Sealsworn\godot --scene res://tests/headless/test_runner.tscn --quit-after 10`.
  - [x] Run `git diff --check`.
  - [x] Update this story's Dev Agent Record, File List, Completion Notes, and Change Log with actual implementation work.

### Review Findings

- [x] [Review][Patch] Entity-id previews leak hidden target facts and use a different validation order [`godot/scripts/tactical/targeting/attack_preview_query.gd`:100] — `preview_target_entity()` resolves `board.get_entity(target_entity_id)` and derives position before visibility is established, allowing callers to distinguish hidden existing ids from missing ids and exposing hidden target position in `not_visible` metadata. It also validates target existence before actor state, unlike the story's board/weapon/actor/target validation order.
- [x] [Review][Patch] Target-cell previews trust stale occupant links [`godot/scripts/tactical/targeting/attack_preview_query.gd`:40] — preview resolves the target from `BoardCell.occupant_id` but does not verify the resolved entity still occupies the requested cell, so inconsistent board state can produce a legal preview against the wrong target.
- [x] [Review][Patch] Story 1.9 contract matrix is too narrow [`godot/tests/fixtures/tactical/attack_preview_contract_matrix.gd`:4] — the matrix documents only a small subset of preview reasons and can miss future `AttackCommand` parity drift for hidden, memory, missing, dead, friendly, out-of-range, and related invalid preview families.
- [x] [Review][Patch] Contract matrix silently falls back to an open-lane fixture [`godot/tests/unit/tactical/test_attack_preview_query.gd`:212] — unknown fixture names return `attack_preview_open_lane()`, so future typoed contract cases can exercise the wrong board and still pass accidentally.
- [x] [Review][Patch] Adjacency modifier validation allows contradictory semantics [`godot/scripts/content/definitions/weapon_definition.gd`:78] — `adjacent_ranged_70` and `adjacent_half` validate with any positive multiplier, including values that contradict their ids or turn a penalty into a boost while preview text still says damage is reduced.
- [x] [Review][Patch] Baseline repository creation can hide registration failure [`godot/scripts/content/repositories/weapon_repository.gd`:30] — `create_baseline_repository()` logs a failed baseline registration but still returns a repository, which can leave callers with partial content instead of failing at the repository boundary.

## Dev Notes

### Current Repository Baseline

Story creation analysis on 2026-06-07 found a clean worktree and baseline commit `d74eff3fa05d0ea12e0134f7ebac568667f77064`.

Recent commits:

- `d74eff3 feat: implement fog visibility model`
- `a47dd02 chore: create story 1.7 visibility foundation`
- `3b40340 feat: implement move command validation`
- `d8c5072 feat: complete tactical snapshot boundary`
- `6e11808 fix: complete story 1.4 review patches`

Existing baseline facts:

- `ActionResult` enforces lower-snake stable error codes, deep-copies metadata, and rejects non-`DomainEvent` success events.
- `BoardState` owns cells, entities, event sequence ids, movement event application, and visibility event application.
- `BoardCell.blocks_line_of_sight()` currently returns true only for wall terrain. Use this boundary for preview blockers.
- `TacticalEntityState` contains id, type, faction, position, HP, and movement blocking only. It has no equipment or weapon slot yet; do not add one in this story.
- `TacticalVisibilityQuery` already calculates pure LoS, creates explicit `visibility_updated` events, and filters hidden/memory/visible facts.
- `TacticalMovementQuery` validates visible movement targets without mutating board state; its error style is the local model for preview query errors.
- `RngStreamSet` tracks named streams and draw indexes. Preview must not advance any stream, including `combat`.
- `TacticalSnapshot.from_domain()` is the no-mutation proof helper and rejects scene/UI/audio/animation/presentation references.
- `ContentRepository` exists as a small generic Resource registry under `godot/scripts/content/repositories/content_repository.gd`.
- `godot/data/source/` and `godot/data/resources/` exist but contain no weapon source/resource files yet.

### Existing Files To Update Or Preserve

| Path | Current State | This Story Changes | Preserve |
|---|---|---|---|
| `godot/scripts/content/definitions/weapon_definition.gd` | Does not exist. | Add typed `Resource` definition for weapon preview fields and validation. | No inner-class Resource definitions; use `class_name WeaponDefinition`. |
| `godot/scripts/content/repositories/content_repository.gd` | Generic Resource registry by type/id. | May be extended or wrapped by a weapon-specific repository/factory. | Keep generic behavior and future content-type compatibility. |
| `godot/scripts/tactical/targeting/attack_preview_query.gd` | Does not exist. | Add pure attack preview validation/result metadata. | Must extend `RefCounted`; no scene tree, no event emission, no RNG, no mutation. |
| `godot/scripts/tactical/targeting/tactical_line_query.gd` | Does not exist. | Optional shared line helper if extracting Story 1.7 LoS behavior. | Must preserve visibility tests and use `BoardCell.blocks_line_of_sight()`. |
| `godot/scripts/tactical/fog/tactical_visibility_query.gd` | Pure visibility, event creation, and visible-fact filtering. | Update only if exposing/extracting shared line behavior. | Do not weaken hidden/memory fact filtering or fold preview state into fog. |
| `godot/scripts/tactical/board/board_state.gd` | Applies movement and visibility events; owns tactical truth. | No production change expected for previews. | Preview must not call event application or mutate cells/entities. |
| `godot/scripts/tactical/board/board_cell.gd` | Terrain, occupant, explored/visible flags, blocker helpers. | No production change expected unless a tiny helper avoids duplication. | Wall blocker semantics and snapshot fields stay intact. |
| `godot/scripts/tactical/entities/tactical_entity_state.gd` | Entity id/type/faction/position/HP/blocking only. | No production change expected. | Do not add weapon equipment or attack state in Story 1.8. |
| `godot/tests/fixtures/tactical/board_fixture_factory.gd` | Board, movement, visibility fixtures. | Add or complement with attack-preview fixtures. | Existing Story 1.2-1.7 fixtures must remain deterministic. |
| `godot/tests/unit/tactical/test_tactical_visibility_query.gd` | Locks visibility semantics. | May need updates only if line helper is extracted. | All existing visibility tests must stay green. |

### Weapon Definition Contract

Use the Prototype Baseline v0 values from the GDD:

| Weapon id | Range | Damage | Targeting | Preview details |
|---|---:|---:|---|---|
| `sword` | 1 | 4 | Adjacent cardinal | Reliable melee damage. |
| `dagger` | 1 | 2 | Adjacent cardinal | Future Unseen synergy is descriptive only in this story. |
| `spear` | 2 | 3 | Straight line melee | Reach weapon with safer spacing. |
| `axe` | 1 | 3 | Adjacent cardinal | Preview a 35% bleed-if-survives effect; no RNG roll. |
| `mace` | 1 | 3 | Adjacent cardinal | Preview a 35% disorient-if-survives effect; no RNG roll. |
| `bow` | 4 | 3 | Straight line with blockers | Adjacent target warning; expected damage 2 after -30% penalty. |
| `crossbow` | 3 | 4 | Straight line with blockers | Preview knockback 1 if space allows; do not move target. |
| `staff` | 4 | 4 | Straight line with blockers | Adjacent target warning; expected damage 2 after half-damage penalty. |
| `wand` | 4 | 2 | Straight line, ignores blockers | Ignores walls/entities for line blocking; still requires visibility. |

Damage modifiers for preview are deterministic and integer. Use `floor(base_damage * multiplier)` with minimum 1 unless the implementation explicitly records a different rule in tests and Story 1.9 contract fixtures.

### Attack Preview Semantics

- Preview is a tactical query service, not a command. It validates and explains; it does not mutate.
- All previews require a visible target cell unless a future weapon/rule explicitly says otherwise. Wand ignores blockers, not fog.
- Explored-memory cells are stale display data and must be rejected as `not_visible` for attack targeting.
- Hidden targets must not expose occupant id, HP, faction, terrain details, or other current tactical facts in preview metadata.
- Straight-line targeting means same row or same column. Diagonal targets without an override are `not_aligned`.
- Adjacent melee uses cardinal adjacency for this story so diagonal melee does not bypass the straight-line baseline.
- Range uses grid distance along the attack line for line weapons and cardinal adjacency for adjacent weapons. Do not use Euclidean range for attacks unless a later weapon definition says so.
- Blocker checks use board cell terrain and entity occupancy as line blockers unless the weapon ignores blockers. If an entity blocker or terrain blocker is on an intermediate line cell, the reason is `blocked_line`.
- The target's occupied cell is not a blocker against itself.
- Player-facing warning text can be stored as ids or short strings, but stable machine ids such as `adjacent_ranged_penalty` must drive tests.

### Previous Story Intelligence

Story 1.7 established the visibility contract this story must reuse:

- Visibility is recalculated explicitly through `TacticalVisibilityQuery.create_visibility_updated_event()` and applied through `BoardState`.
- Pure visibility calculations return `ActionResult` metadata, emit no events, consume no RNG, and do not mutate board snapshots.
- `visible_facts_for_cell()` hides all current facts for hidden cells, exposes only non-authoritative stable display data for explored memory, and exposes occupant HP/faction only for visible cells.
- `MoveCommand` still emits exactly one `entity_moved` event and does not fold visibility recalculation into movement.
- If attack preview uses visibility facts, preserve the hidden/memory/current-truth distinction. Do not read `BoardCell.occupant_id` for hidden or memory targets before checking current visibility.

Story 1.6 and earlier established supporting contracts:

- Invalid domain operations must leave board, turn state, RNG streams, event log, and tactical snapshot unchanged.
- Movement queries use deterministic validation order and stable metadata reasons; preview should follow that style.
- Named RNG streams exist, but preview must not draw from them. Axe/Mace proc percentages are preview text/effect metadata only until `AttackCommand` resolves combat.
- Tactical snapshots are versioned domain data only. Do not serialize scenes, resources with file paths, UI nodes, audio, animation, object refs, callables, or presentation strings as save truth.

### Git Intelligence

- Commit `d74eff3` completed Story 1.7 and is the immediate baseline for visibility, hidden target, and no-mutation patterns.
- Commit `3b40340` completed Story 1.6 and provides the local query/command validation style for movement.
- Commit `d8c5072` completed the tactical snapshot boundary. Use `TacticalSnapshot.from_domain()` for purity assertions.
- Commit `6e11808` reinforced strict no-partial-mutation behavior after invalid operations. Treat preview purity as a first-class regression target.

### Architecture Compliance

- The scene-independent domain model owns tactical truth. Attack preview belongs under `godot/scripts/tactical/targeting/` or a narrow combat/targeting split, not scenes or UI.
- Weapon definitions are static content definitions exposed through repository/import boundaries. Gameplay systems must not read JSON/CSV/resources directly.
- Godot scenes, HUDs, VFX, animation, and audio may later mirror preview metadata; they do not own legality, damage, blocker, or warning truth.
- Commands validate before mutation and return `ActionResult`. This story prepares the validation contract for `AttackCommand` but does not implement attack execution.
- Successful commands emit deterministic past-tense domain events. Previews are not commands and must emit no domain events.
- Tactical query services cover pathfinding, line of sight, valid movement, attack previews, threat maps, and tile scoring. Keep preview as a query service.
- Headless simulation must not depend on rendering, audio, UI scenes, presentation nodes, physics raycasts, or scene-tree-only state.
- Save truth remains versioned domain snapshots only. New Resource definitions are content definitions, not save truth.

### Library And Framework Requirements

- Required engine: Godot 4.6.3 stable standard build.
- Required language: typed GDScript.
- Use existing custom tests based on `godot/tests/unit/test_case.gd`; do not add GUT, GdUnit, or another test dependency.
- Use `Resource` for reusable weapon definition data and `RefCounted` for domain/query helpers.
- Use `Vector2i` for grid coordinates and typed arrays/dictionaries where the current project style supports them.
- Do not use Godot physics raycasts, `Node2D`, `Area2D`, collision layers, scenes, or UI controls for attack legality. Those are presentation/runtime helpers later, not authoritative tactical rules.
- Do not introduce new third-party libraries.

### Latest Technical Information

Official sources checked on 2026-06-07:

- Godot 4.6.3 stable is the project policy and the current stable archive entry dated 2026-05-20: https://godotengine.org/download/archive/4.6.3-stable/
- Godot 4.6 static typing supports typed variables, constants, functions, parameters, return values, custom classes via `class_name`, and typed arrays. Keep new scripts typed: https://docs.godotengine.org/en/4.6/tutorials/scripting/gdscript/static_typing.html
- Godot Resources are data containers, and custom Resource scripts should be top-level scripts extending `Resource`, not inner classes, if they may be serialized or edited: https://docs.godotengine.org/en/4.6/tutorials/scripting/resources.html
- `RefCounted` is appropriate for helper/domain objects that do not need node lifecycle; they are reference-counted and normally do not require manual `free()`: https://docs.godotengine.org/en/4.6/classes/class_refcounted.html

### Project Structure Notes

- Weapon definition code belongs under `godot/scripts/content/definitions/`.
- Weapon lookup/repository code belongs under `godot/scripts/content/repositories/`.
- Pure attack preview and targeting helpers belong under `godot/scripts/tactical/targeting/`.
- Combat execution, damage application, and attack/damage events belong to Story 1.9 and should not be added here unless they are impossible to avoid, which would be a story-scope conflict to surface.
- Tests mirror the domain they cover: content definition tests under `godot/tests/unit/content/` if created, targeting tests under `godot/tests/unit/tactical/`, and fixture helpers under `godot/tests/fixtures/tactical/`.
- Runtime attack preview UI, two-step commit UI, mobile confirm controls, inspect panels, animation, and audio are out of scope for Story 1.8.
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
- Existing Story 1.1 through Story 1.7 tests still pass.
- New content tests cover all nine baseline weapons, validation failures, repository lookup, stable ids, targeting shapes, special overrides, and adjacency modifiers.
- New preview tests cover legal line attacks, adjacent melee, ranged attacks, diagonal rejection, out-of-range rejection, blocked-line rejection, Wand blocker override, hidden target rejection, explored-memory rejection, friendly/dead target rejection, Bow/Staff adjacency penalties, no events, no RNG, unchanged board snapshots, unchanged board sequence ids, and repeated-result determinism.
- New contract tests record the exact reason/damage metadata Story 1.9 must reuse for `AttackCommand`.

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
- Use named RNG streams for gameplay-affecting randomness; previews must not consume them.
- Save versioned domain snapshots only; never serialize scene nodes as save truth.
- Headless simulation must not depend on rendering, audio, UI scenes, presentation nodes, or scene-tree-only state.
- Do not introduce cloud services, accounts, multiplayer, telemetry dependencies, Godot .NET/C#, new test frameworks, or third-party libraries unless the architecture is explicitly revised.
- Preserve user changes and unrelated dirty worktree files.

### References

- [Source: `_bmad-output/planning-artifacts/epics.md` - Story 1.8]
- [Source: `_bmad-output/implementation-artifacts/epic-1-sprint-plan-2026-06-04.md` - Sprint Slice 3]
- [Source: `_bmad-output/implementation-artifacts/1-7-fog-line-of-sight-and-explored-memory.md` - Previous Story Intelligence]
- [Source: `project-context.md` - Determinism, domain ownership, file placement, content, and testing rules]
- [Source: `_bmad-output/game-architecture.md` - Content definitions, tactical query services, targeting paths, and implementation patterns]
- [Source: `_bmad-output/planning-artifacts/gdds/gdd-Game-2026-05-31/gdd.md` - Prototype weapon baseline and controls/input preview requirements]
- [Source: Godot 4.6.3 stable archive](https://godotengine.org/download/archive/4.6.3-stable/)
- [Source: Godot 4.6 static typing docs](https://docs.godotengine.org/en/4.6/tutorials/scripting/gdscript/static_typing.html)
- [Source: Godot 4.6 Resource docs](https://docs.godotengine.org/en/4.6/tutorials/scripting/resources.html)
- [Source: Godot 4.6 RefCounted docs](https://docs.godotengine.org/en/4.6/classes/class_refcounted.html)

## Dev Agent Record

### Agent Model Used

Codex GPT-5

### Debug Log References

- 2026-06-07: Created Story 1.8 implementation guide from Epic 1 source requirements, Sprint Slice 3, previous story records, root project context, game architecture, GDD weapon baseline, current Godot code/tests, clean git baseline, recent commits, Context7 Godot 4.6 docs, and official Godot 4.6.3 stable archive/docs references.
- 2026-06-07: Confirmed red content tests failed on missing `WeaponDefinition`/`WeaponRepository`, then implemented the typed definition and repository boundary.
- 2026-06-07: Confirmed red line-helper tests failed on missing `TacticalLineQuery`, then extracted shared supercover/line-blocker logic and reran visibility regressions.
- 2026-06-07: Confirmed red preview tests failed on missing `AttackPreviewQuery`, then implemented pure attack preview validation, metadata, warning/effect output, and no-mutation contract coverage.
- 2026-06-07: Headless test runner passed after implementation: `godot --headless --path C:\Sealsworn\godot --scene res://tests/headless/test_runner.tscn --quit-after 10`.
- 2026-06-07: Required validation passed: `godot --version`, full headless runner, and `git diff --check`.
- 2026-06-07: Code review found 6 patch findings; all were fixed and checked off. Post-patch headless runner passed.

### Implementation Plan

- Start with failing content and targeting tests for all baseline weapon definitions, preview legality, warnings, and purity.
- Add the minimal typed `WeaponDefinition` Resource and repository/factory boundary.
- Add or expose shared line targeting behavior without duplicating Story 1.7 LoS semantics.
- Implement `AttackPreviewQuery` as a pure `RefCounted` tactical query with stable `ActionResult` metadata.
- Extend deterministic fixtures and contract tests for Story 1.9 `AttackCommand`.
- Rerun the full headless suite and `git diff --check`.

### Completion Notes List

- Ultimate context engine analysis completed - comprehensive developer guide created.
- Added baseline weapon definitions for Sword, Dagger, Spear, Axe, Mace, Bow, Crossbow, Staff, and Wand through a typed `WeaponDefinition` Resource and `WeaponRepository` wrapper over the generic `ContentRepository`.
- Extracted pure `TacticalLineQuery` supercover and blocker helpers, and routed `TacticalVisibilityQuery` through the shared helper to preserve Story 1.7 behavior.
- Added pure `AttackPreviewQuery` with explicit `WeaponDefinition` input, stable legality reasons, legal/illegal metadata, Wand blocker override, Bow/Staff adjacency warnings, deterministic effect text, and no event/RNG/state mutation.
- Added deterministic attack-preview fixtures plus Story 1.9 contract matrix tests for preview reason, damage, blocker override, warning, and effect metadata.
- Resolved code review patches by preventing entity-id hidden target fact leaks, enforcing actor-first validation for entity-id previews, rejecting stale target occupant links, expanding Story 1.9 contract cases, removing silent contract fixture fallback, binding adjacency modifier ids to their exact multipliers, and failing closed on invalid repository factory input.

### File List

- `_bmad-output/implementation-artifacts/1-8-weapon-definitions-and-attack-preview-rules.md`
- `_bmad-output/implementation-artifacts/sprint-status.yaml`
- `godot/scripts/content/definitions/weapon_definition.gd`
- `godot/scripts/content/repositories/weapon_repository.gd`
- `godot/scripts/tactical/fog/tactical_visibility_query.gd`
- `godot/scripts/tactical/targeting/attack_preview_query.gd`
- `godot/scripts/tactical/targeting/tactical_line_query.gd`
- `godot/tests/fixtures/tactical/attack_preview_contract_matrix.gd`
- `godot/tests/fixtures/tactical/board_fixture_factory.gd`
- `godot/tests/unit/content/test_weapon_repository.gd`
- `godot/tests/unit/tactical/test_attack_preview_query.gd`
- `godot/tests/unit/tactical/test_tactical_line_query.gd`

## Change Log

- 2026-06-07: Created Story 1.8 implementation guide and marked it ready for development.
- 2026-06-07: Implemented baseline weapon definitions, shared line targeting, pure attack preview query, preview fixtures, purity tests, and Story 1.9 preview contract coverage.
- 2026-06-07: Completed validation and moved Story 1.8 to review.
- 2026-06-07: Addressed all code review patch findings and reran the headless suite.
