---
project: Sealsworn
date: 2026-06-04
scope: Epic 1 only
readiness_status: READY_WITH_GATES
source_epics_file: C:/Sealsworn/_bmad-output/planning-artifacts/epics.md
status_file: C:/Sealsworn/_bmad-output/implementation-artifacts/sprint-status.yaml
---

# Epic 1 Sprint Plan

## Source Inputs

- `C:/Sealsworn/AGENTS.md`
- `C:/Sealsworn/project-context.md`
- `C:/Sealsworn/_bmad-output/game-architecture.md`
- `C:/Sealsworn/_bmad-output/planning-artifacts/epics.md`
- `C:/Sealsworn/_bmad-output/planning-artifacts/implementation-readiness-report-2026-06-04.md`

## Scope Decision

Plan only the domain-first Epic 1 path: Godot setup, headless tests, domain state, commands/events, named RNG streams, tactical board, movement, fog/LoS, attack previews, and initial combat tests.

Do not start UI-heavy scene work in this sprint path. Lightweight UX notes remain a gate before Epic 2 or polished UI work, not a blocker for Epic 1 domain work.

The sprint status file is intentionally Epic 1-only. Parent story traceability stays aligned with `epics.md`; implementation-sized splits below are execution planning slices, not a canonical epic rewrite.

## Execution Guardrails

- Production code stays under `godot/`.
- Typed GDScript is the implementation language.
- Tactical truth lives in scene-independent domain scripts.
- Commands validate before mutation and return `ActionResult`.
- Successful commands emit deterministic past-tense domain events.
- Gameplay-affecting randomness uses named RNG streams only.
- Tests must run headlessly without rendering, audio, UI scenes, presentation nodes, or scene-tree-only state.
- Save/snapshot work serializes domain data only, never scene nodes.
- Existing React/Vite prototype code remains validation evidence only.
- No cloud service, account, multiplayer, telemetry, or Godot .NET/C# dependency is introduced.

## Recommended Sprint Slices

### Sprint Slice 0: Setup Verification

Goal: make the production Godot setup and test harness trustworthy before gameplay work expands.

Parent story:
- Story 1.1: Production Godot Project and Headless Test Harness

Implementation tasks:
- Verify `godot/project.godot` is a Godot 4.6.3 standard GDScript project.
- Verify architecture folders exist under `godot/scripts/` and `godot/tests/`.
- Run or repair one headless smoke test that loads a domain script.
- Record the repeatable headless test command and Windows dev-run command.
- Verify `export_presets.cfg` or tracked setup notes cover Windows and Android scaffolding.
- Record iOS export as deferred until macOS/Xcode access is available.

Exit gate:
- Headless test command is known and at least one domain-only test passes or a precise blocker is recorded.

### Sprint Slice 1: Domain Foundation

Goal: establish board state, results, events, RNG streams, and snapshots before movement or combat rules.

Parent stories:
- Story 1.2: Tactical Domain State and Board Model
- Story 1.3: ActionResult and Domain Event Foundation
- Story 1.4: Named RNG Streams for Deterministic Gameplay
- Story 1.5: Tactical Snapshot Serialization Boundary

Implementation tasks:
- Implement bounded grid, terrain cells, entity placement, occupancy queries, and non-mutating board validation.
- Add reusable board fixtures for `1x1`, edge/corner, blocked, occupied, disconnected, LoS blockers, and deterministic actor placement cases.
- Implement `ActionResult` success/failure shape with stable error codes and ordered events.
- Implement base `DomainEvent` serialization and replay/application tests.
- Implement named streams: `map`, `level`, `combat`, `loot`, `rewards`, `events`, and `cosmetic`.
- Test stream independence, snapshot/restore, invalid stream handling, and cosmetic isolation.
- Implement tactical snapshot export/import for board, entities, HP, turn state, pending telegraphs, visibility fields, and RNG state.
- Use snapshots for no-mutation assertions.

Exit gate:
- Board, result/event, RNG, and snapshot tests pass headlessly with no presentation dependencies.

### Sprint Slice 2: Movement and Visibility

Goal: make tactical positioning and fair partial information work before attacks.

Parent stories:
- Story 1.6: MoveCommand with Movement Validation
- Story 1.7: Fog, Line of Sight, and Explored Memory

Implementation tasks:
- Implement `MoveCommand` with baseline 3-tile movement budget.
- Validate blocked, occupied, out-of-bounds, beyond-budget, invalid-actor, wrong-phase, and unseen-or-unreachable cases.
- Emit `EntityMovedEvent` only after successful validation.
- Preserve snapshot, event log, turn state, board occupancy, and RNG state for invalid movement.
- Implement baseline LoS radius 4.
- Track hidden, explored-memory, and currently-visible tile states.
- Add golden LoS fixtures for corners, blockers, diagonals, edges, and movement updates.
- Ensure visible-fact queries hide unexplored data and expose explored memory only as non-authoritative display data.

Exit gate:
- Movement and visibility tests pass headlessly, including invalid/no-mutation coverage.

### Sprint Slice 3: Attack Preview Split

Goal: make pure, deterministic attack previews before committed attacks exist.

Parent story:
- Story 1.8: Weapon Definitions and Attack Preview Rules

Child implementation slices:
- 1.8a: Weapon Definition Schema and Repository Fixture
- 1.8b: Pure Attack Preview Targeting Core
- 1.8c: Preview Fixtures and AttackCommand Contract Surface

Implementation tasks:
- Define baseline weapon definitions for Sword, Dagger, Spear, Axe, Mace, Bow, Crossbow, Staff, and Wand.
- Expose range, damage, targeting shape, tactical identity, and special override fields through repository or fixtures.
- Implement pure preview queries for range, alignment, blocker rules, visibility, expected base damage, and warnings.
- Implement Wand blocker override and ranged adjacency penalties for Bow and Staff previews.
- Add fixture cases for line, adjacent, ranged, blocked, override, hidden target, and adjacency penalty previews.
- Assert previews emit no events, consume no gameplay RNG, and do not mutate snapshots.
- Define stable preview result fields that `AttackCommand` validation must later match.

Exit gate:
- Repeated previews from the same snapshot return identical results and no gameplay RNG state changes.

### Sprint Slice 4: AttackCommand and Initial Combat Tests

Goal: commit attacks through the command/event path with deterministic damage and no-mutation invalid cases.

Parent story:
- Story 1.9: AttackCommand with Damage Events

Child implementation slices:
- 1.9a: AttackCommand Validation and No-Mutation Harness
- 1.9b: Damage Events and Base Weapon Execution
- 1.9c: Baseline Proc/Support Effects and Combat RNG

Implementation tasks:
- Validate actor, target, turn phase, visibility, range, line/blocker, alive-state, missing target, dead target, and invalid actor cases.
- Emit deterministic attack and damage events only after successful validation.
- Reduce HP through event application, not direct presentation-side mutation.
- Contract-test legal and illegal preview reasons against command validation reasons.
- Add no-mutation tests for tactical snapshot, event log, turn state, and RNG state on every invalid branch.
- Add baseline fixtures for Axe bleed, Mace disorient, Crossbow knockback, Tome bonus damage, Shield armor/block handling where in Epic 1 scope.
- Verify all gameplay proc rolls use the `combat` RNG stream.

Exit gate:
- Initial combat command tests pass headlessly across legal, illegal, preview-contract, and combat-RNG cases.

### Sprint Slice 5: Enemy Turns and Tactical Outcomes

Goal: prove enemy response, damage explanations, and simple win/loss state without polished UI.

Parent stories:
- Story 1.10: Enemy Turn Resolution for Prototype Enemies
- Story 1.11: Combat Outcome, Death/Victory, and Explanation Log

Child implementation slices:
- 1.10a: Enemy Turn Sequencing and Enemy Command Adapter
- 1.10b: Iron Cultist and Gate Brute Melee Behaviors
- 1.10c: Ash Seer Mark and Delayed Detonation
- 1.10d: AI Explanation and Determinism Fixtures
- 1.11a: Outcome Events and Explanation Log
- 1.11b: Domain-First Micro-Combat Smoke Scenario

Implementation tasks:
- Resolve enemy turns only after successful player move or attack commands.
- Route enemy movement, attacks, waits, marks, and detonations through validated commands or a narrow enemy command adapter.
- Implement Iron Cultist approach/adjacent attack behavior.
- Implement Gate Brute melee behavior with heavier body-blocking presence through occupancy rules.
- Implement Ash Seer range-5 LoS mark and delayed detonation if the player remains on the marked tile.
- Emit readable explanation payloads for move, attack, mark, detonation, wait, blocked, damage, victory, and defeat.
- Add deterministic fixtures for movement, attack, mark, wait, blocked, detonation, same-seed action, and same-seed explanation output.
- Implement victory when all enemies are defeated and defeat when player HP reaches zero.
- Create a small domain-first micro-combat scenario with one player, 2-3 prototype enemies, obstacles, fog reveal, at least two weapon shapes, and win/loss outcomes.
- Keep any launch or smoke harness minimal; defer polished tactical UI to Epic 2 after UX notes exist.
- Add local, build-profile-gated timing instrumentation for board queries, LoS updates, command execution, and enemy turns.

Exit gate:
- Epic 1 headless suite passes for board, snapshot, movement, visibility, preview, attack, enemy, RNG, event log, and outcome tests.

## Dependency Order

1. Setup and headless harness.
2. Board state, results/events, RNG, and snapshots.
3. Movement and visibility.
4. Pure attack preview.
5. Attack command and initial combat tests.
6. Enemy turns, outcomes, explanation log, and micro-combat smoke scenario.

## Gates Before Later Work

- Before Epic 2 or polished UI: create lightweight UX notes for tactical HUD, preview/confirm states, inspect panel, passive modal, run map, outpost/meta, run summary, settings, and save/resume recovery.
- Before UI-heavy scenes: confirm domain view models and command bridge contracts can observe domain state and submit commands without owning tactical truth.
- Before MVP readiness claims: execute Epic 10 gates for device tiers, performance, memory/battery, seed sample sizes, accessibility, placeholder replacement/de-scope, and pre-export validation.

## Tracking Summary

- Epic count in this scoped plan: 1
- Parent stories in this scoped plan: 11
- Broad parent stories split for execution: 1.8, 1.9, 1.10, 1.11
- Retrospective entry: `epic-1-retrospective`
- Initial status posture: backlog, because no story-tracking files existed before this planning run
