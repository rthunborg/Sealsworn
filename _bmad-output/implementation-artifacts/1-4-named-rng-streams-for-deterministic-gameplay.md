---
baseline_commit: dcf393e4c15a93a219a36023b4550b091a6f3fca
---

# Story 1.4: Named RNG Streams for Deterministic Gameplay

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a developer,
I want named RNG streams derived from a root seed,
so that gameplay-affecting randomness remains reproducible and isolated by system.

## Acceptance Criteria

1. Given a root seed is provided, when the RNG service is initialized, then it creates named streams for `map`, `level`, `combat`, `loot`, `rewards`, `events`, and `cosmetic`, and each gameplay stream produces deterministic values for the same root seed.
2. Given a combat roll uses the `combat` stream, when unrelated `cosmetic` rolls are made before the combat roll, then the combat roll result is unchanged, and gameplay outcome determinism is preserved.
3. Given an RNG stream advances, when its state is snapshotted and restored, then subsequent rolls match the original stream sequence, and tests verify at least one stream restoration case.
4. Given gameplay code requests randomness, when the requested stream name is missing or invalid, then the RNG service returns a deterministic error path, and no fallback global randomness is used for gameplay outcomes.
5. Given a gameplay-affecting RNG draw occurs, when the draw result affects combat, rewards, generation, events, or progression, then the stream name, stream state or draw index, and consumer context are available for diagnostics or replay tests, and draw auditability does not require presentation state.
6. Given the same root seed, same initial snapshot, and same command sequence are used, when the sequence is executed twice, then final domain snapshots, ordered domain events, and gameplay RNG stream states match exactly, and cosmetic stream draws do not change that equality.

## Tasks / Subtasks

- [x] 1.4.1 Expand failing RNG stream contract tests before changing implementation. (AC: 1, 2, 4)
  - [x] Extend `godot/tests/unit/core/test_rng_stream_set.gd` rather than creating a parallel RNG test suite.
  - [x] Assert `RngStreamSet.required_streams()` returns exactly `map`, `level`, `combat`, `loot`, `rewards`, `events`, and `cosmetic` in stable order.
  - [x] Assert every required stream exists after initialization and produces the same first and second values for the same root seed.
  - [x] Assert different streams are isolated: advancing `map`, `level`, `loot`, `rewards`, `events`, or `cosmetic` must not advance `combat`.
  - [x] Assert unknown, empty, or misspelled stream ids return stable error codes and leave the full RNG snapshot unchanged.
  - [x] Preserve the existing `rand_int()`, `rand_float()`, `try_rand_int()`, and `try_rand_float()` call surface unless tests prove a narrow compatible extension is required.
- [x] 1.4.2 Add deterministic draw audit metadata without presentation dependencies. (AC: 5, 6)
  - [x] Track a per-stream `draw_index` or equivalent deterministic counter for every successful stream draw.
  - [x] Extend successful draw result metadata to include at minimum: `value`, `stream_name`, `draw_index`, `state_before`, `state_after`, `draw_type`, and `consumer_context`.
  - [x] Allow callers to pass optional `consumer_context: Dictionary = {}` to draw methods, keeping existing callers source-compatible.
  - [x] Deep-copy consumer context in result metadata so later caller mutation cannot rewrite diagnostics.
  - [x] Keep audit data serializable domain data only; no `Node`, `ObjectID`, `Callable`, scene path, UI, audio, animation, or presentation references.
  - [x] Do not turn standalone RNG draws into board-applied gameplay events. `DomainEvent.RNG_STREAM_ADVANCED` may remain stable for future diagnostics, but this story should not make `BoardState` apply RNG events.
- [x] 1.4.3 Harden RNG snapshot and restore behavior. (AC: 3, 5, 6)
  - [x] Include root seed and every named stream's `seed`, `state`, and `draw_index` in `RngStreamSet.to_snapshot()`.
  - [x] Add a validated restore path such as `try_restore(snapshot: Dictionary) -> ActionResult` or an equivalent `try_from_snapshot()` contract.
  - [x] Preserve the existing `restore(snapshot)` compatibility wrapper if other code still calls it, but route it through the validated path.
  - [x] Reject malformed snapshots with stable error codes, covering missing `streams`, missing required stream entries, non-dictionary stream state, invalid seed/state values, and invalid draw indexes.
  - [x] Stage restore validation before mutation so failed restores leave the previous RNG snapshot unchanged.
  - [x] Add at least one restoration test per gameplay stream family that proves the next roll after restore matches the uninterrupted stream.
- [x] 1.4.4 Prevent hidden randomness and invalid draw fallbacks. (AC: 2, 4, 5)
  - [x] Validate integer draw ranges before mutating stream state; invalid ranges should return a stable error such as `invalid_rng_range` and leave snapshots unchanged.
  - [x] Confirm unknown-stream errors return no draw audit that could be mistaken for a successful gameplay draw.
  - [x] Scan production scripts for direct gameplay randomness with `rg "RandomNumberGenerator|randomize\\(|randi\\(|randf\\(|rand_from_seed" godot\\scripts` and record the result in the Dev Agent Record.
  - [x] Keep direct `RandomNumberGenerator` ownership inside `RngStreamSet` only for gameplay-affecting randomness. Cosmetic presentation code may later use non-authoritative randomness only if it cannot affect tactical outcomes, rewards, unlocks, progression, or save truth.
- [x] 1.4.5 Add deterministic replay and cosmetic-isolation fixtures. (AC: 2, 5, 6)
  - [x] Add a headless fixture that runs the same deterministic sequence of gameplay draws twice from the same root seed and initial RNG snapshot.
  - [x] Assert result values, draw audit metadata, gameplay stream snapshots, and ordered `ActionResult.events` arrays match exactly across both runs.
  - [x] Add the same fixture with extra `cosmetic` draws inserted before or between gameplay draws; assert gameplay stream snapshots and gameplay draw values still match the no-cosmetic path.
  - [x] If standalone RNG draws intentionally return empty event arrays, assert they remain empty and document that future movement, attack, reward, generation, and event commands must emit their own gameplay outcome events.
  - [x] Do not implement movement, attack, loot, reward selection, generation, run events, or progression logic in this story.
- [x] 1.4.6 Preserve save/autoload boundaries and full validation. (AC: 3, 4, 6)
  - [x] Keep `GameSession` thin if touched: it may configure and expose RNG snapshots, but it must not own gameplay decisions or stream assignment policy.
  - [x] Update `RunSnapshot` tests only if the RNG snapshot schema requires stronger `rng_streams` round-trip coverage now; broader tactical snapshot work belongs to Story 1.5.
  - [x] Run `godot --version` and the full headless suite before marking tasks complete.
  - [x] Run `git diff --check` before moving the story to review.

### Review Findings

- [x] [Review][Decision][Dismissed] Choose how to handle pre-draw-index RNG snapshots under schema 1 - dismissed during review: there are no production saves or real legacy snapshots yet, and Story 1.4 intentionally makes missing `draw_index` invalid for the new RNG audit contract.
- [x] [Review][Patch] Failed RNG restore can desync `GameSession` seed from stream state [`godot/scripts/autoloads/game_session.gd:24`]
- [x] [Review][Patch] `git diff --check` fails on trailing whitespace in this story file [`_bmad-output/implementation-artifacts/1-4-named-rng-streams-for-deterministic-gameplay.md:13`]
- [x] [Review][Patch] Cyclic `consumer_context` can recurse after RNG state mutates [`godot/scripts/core/state/rng_stream_set.gd:153`]

## Dev Notes

### Current Repository Baseline

Story creation analysis on 2026-06-05 found a clean, passing domain baseline:

- `git status --short` returned clean before this story file was created.
- Recent commits:
  - `dcf393e feat: complete epic 1 tactical foundations`
  - `5b8de38 chore: checkpoint epic 1 story 1.1 baseline`
  - `016e0b5 chore: checkpoint Sealsworn planning and Godot foundation`
- Existing RNG implementation already lives at `godot/scripts/core/state/rng_stream_set.gd`.
- Existing RNG tests already live at `godot/tests/unit/core/test_rng_stream_set.gd`.
- Current `RngStreamSet` already provides:
  - Required stream constants for `map`, `level`, `combat`, `loot`, `rewards`, `events`, and `cosmetic`.
  - `required_streams()`, `configure(root_seed)`, `has_stream()`, `rand_int()`, `rand_float()`, `try_rand_int()`, `try_rand_float()`, `to_snapshot()`, and `restore()`.
  - Stable unknown-stream error code `unknown_rng_stream`.
  - Root-seed-derived per-stream `RandomNumberGenerator` instances.
- Current tests already cover same-seed replay for some streams, cosmetic isolation for combat, one rewards-stream restore case, and unknown-stream no-mutation.

The developer should extend this existing implementation. Do not create a second RNG service, global singleton RNG, gameplay utility random helper, or direct random-call wrapper outside `RngStreamSet`.

### Existing Files To Update Or Preserve

| Path | Current State | This Story Changes | Preserve |
|---|---|---|---|
| `godot/scripts/core/state/rng_stream_set.gd` | Scene-independent `RefCounted` RNG stream set with required stream constants, root seed configuration, `RandomNumberGenerator` instances, basic draw methods, snapshot seed/state export, and permissive restore. | Add draw indexes/audit metadata, strict snapshot restore, invalid range handling, full stream coverage, and deterministic replay helpers as needed. | Keep it domain-only and source-compatible for existing callers. Do not add scene, autoload decision logic, UI, audio, generation, combat, reward, or save repository responsibilities. |
| `godot/tests/unit/core/test_rng_stream_set.gd` | Covers partial same-seed replay, cosmetic isolation, one snapshot restore case, and unknown stream no-mutation. | Expand into complete Story 1.4 contract coverage before implementation changes. | Keep addon-free `TestCase` style and `run() -> Dictionary`. Do not weaken existing assertions. |
| `godot/scripts/autoloads/game_session.gd` | Thin `Node` autoload wrapping root seed configuration and RNG snapshot/restore. | Touch only if the new validated restore contract requires a compatibility update. | Keep autoload thin. It must not choose gameplay streams, perform gameplay draws, or own tactical decisions. |
| `godot/scripts/save/snapshots/run_snapshot.gd` | Versioned run snapshot DTO with `root_seed` and `rng_streams` dictionary fields. | No expected production change unless stronger RNG snapshot schema round-trip tests expose a narrow DTO compatibility issue. | Save truth remains versioned domain snapshots only. Do not implement broader save migration; Story 1.5 and later save stories own that. |
| `godot/tests/unit/save/test_run_snapshot.gd` | Verifies schema parse, seed/progression flags, and broad run-state round trip. | Add focused RNG stream dictionary round-trip coverage only if needed by snapshot schema changes. | Do not broaden into tactical snapshot serialization or save repository behavior. |
| `godot/scripts/core/events/domain_event.gd` | Contains stable `RNG_STREAM_ADVANCED` event id and strict event parsing from Story 1.3. | No expected change. Add an RNG event helper only if tests prove standalone RNG draw results must expose events; prefer metadata audit for this story. | Do not make `BoardState` apply RNG events. Do not replace gameplay command outcome events with RNG diagnostic events. |
| `godot/tests/unit/core/test_domain_event.gd` | Verifies stable event ids, including `rng_stream_advanced`. | No expected change unless a narrow RNG event helper is added. | Keep strict parse/no-silent-coercion posture from Story 1.3. |

### Story Scope Boundaries

Implement only the named RNG stream foundation and tests needed by Story 1.4. Do not implement:

- Movement, pathfinding, line of sight, fog reveal updates, attack preview, `MoveCommand`, or `AttackCommand`.
- Weapon procs, damage variance, bleed/disorient, knockback, shield block, enemy AI, rewards, loot, procedural generation, run map events, or progression grants.
- A new rules kernel, event bus, telemetry system, analytics sink, UI command bridge, presentation diagnostics overlay, or debug UI.
- Save migration, tactical snapshot schema, mid-level save/resume, profile/meta snapshots, or save repository changes beyond focused RNG stream dictionary compatibility.
- Godot .NET/C#, React/Vite production dependencies, cloud services, accounts, multiplayer, leaderboards, or live-service dependencies.

If a future system will need randomness, this story should only make the stream service ready for it. The future system must still call the correct stream and emit its own gameplay events through its command path.

### Technical Requirements

- Production code stays under `godot/`.
- Use typed GDScript and `RefCounted` for domain RNG code.
- Keep gameplay-affecting RNG deterministic under the pinned Godot 4.6.3 standard build.
- Required streams are exactly `map`, `level`, `combat`, `loot`, `rewards`, `events`, and `cosmetic`.
- Gameplay stream assignments:
  - `map`: forward-only route structure.
  - `level`: tactical layouts, blockers, hazards, entrances, exits.
  - `combat`: combat procs and damage variance if used.
  - `loot`: item and drop rolls.
  - `rewards`: post-combat and node reward offers.
  - `events`: run events, curses, affinity incidents, and similar systems.
  - `cosmetic`: non-authoritative presentation variance only.
- Snapshot data must be serializable domain data: root seed, stream name, stream seed, stream state, and draw index/counter.
- Do not rely on dictionary iteration order for deterministic behavior. Iterate `required_streams()` or another explicit stable list.
- Unknown stream, invalid stream, malformed snapshot, and invalid range paths must return `ActionResult.error()` with stable lower-snake error codes and no state mutation.
- Draw audit metadata must be diagnostic/replay data, not player-facing text.
- Cosmetic stream usage must never affect tactical outcomes, rewards, unlocks, progression, or gameplay stream states.

### Architecture Compliance

- The scene-independent domain model owns tactical truth and deterministic gameplay state.
- Named RNG streams are derived from a root seed to prevent one extra roll in an unrelated system from changing combat, rewards, or generation.
- Gameplay-affecting random calls must use their assigned stream. No global fallback random calls are allowed for gameplay.
- Save snapshots must include root seed and named RNG stream states; this story prepares that boundary without implementing broader save/resume flow.
- Headless simulation and tests must not depend on rendering, audio, UI scenes, presentation nodes, or scene-tree-only state.
- `GameSession` may remain a thin autoload wrapper but must delegate deterministic behavior to domain services.
- Presentation-only randomness is allowed later only when it cannot affect gameplay outcomes or saved/progression state.

### Library And Framework Requirements

- Required engine: Godot 4.6.3 stable standard build.
- Required language: typed GDScript.
- Use Godot `RandomNumberGenerator` only inside `RngStreamSet` for gameplay-affecting random draws.
- Use the existing custom headless runner and `TestCase` base. Do not add GUT, GdUnit, or another test dependency for this story.
- Do not use OS/time randomness, `randomize()`, global `randi()`/`randf()`, or ad hoc seed derivation for gameplay outcomes.
- Do not introduce new third-party dependencies.

### Latest Technical Information

Official Godot sources checked on 2026-06-05:

- Godot's official archive provides `Godot 4.6.3-stable`. Continue using 4.6.3 unless the architecture is intentionally revised. [Source: Godot 4.6.3 archive](https://godotengine.org/download/archive/4.6.3-stable/)
- Godot `RandomNumberGenerator` exposes `seed` and `state` properties. Store both for stream snapshots when replaying from an advanced stream state. [Source: Godot RandomNumberGenerator docs](https://docs.godotengine.org/en/stable/classes/class_randomnumbergenerator.html)
- Godot static typing supports typed variables, function parameters, return values, and `class_name` custom classes, matching the current domain script style. [Source: Godot static typing docs](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/static_typing.html)

Implementation note: Godot's RNG algorithm is an engine implementation detail. Sealsworn's reproducibility target is within the pinned Godot 4.6.3 production baseline. Do not promise cross-engine-version identical sequences unless a future architecture revision adds a custom RNG algorithm.

### Previous Story Intelligence

Story 1.3 established strict command/result/event contracts that Story 1.4 must preserve:

- `ActionResult.error()` normalizes invalid/blank error codes to stable machine-readable lower-snake ids.
- `ActionResult.ok()` rejects non-`DomainEvent` values and deep-copies metadata.
- `DomainEvent.try_from_dictionary()` rejects malformed dictionaries rather than silently coercing invalid data.
- Existing tests use the addon-free custom runner, extend `res://tests/unit/test_case.gd`, and return `result()`.
- Invalid paths require no-mutation assertions against snapshots or stable state dictionaries.

Story 1.2 established strict tactical snapshot and board patterns that matter for RNG restore:

- Validation should be staged before mutation.
- Snapshot export should use deterministic ordering.
- Do not let permissive parsing silently turn malformed data into valid-looking domain state.

Story 1.1 established the production harness:

- Run tests with `godot --headless --path C:\Sealsworn\godot --scene res://tests/headless/test_runner.tscn --quit-after 10`.
- Keep the project independent from `prototype/`, cloud services, telemetry, accounts, multiplayer, and Godot .NET/C#.

### Deferred Work Awareness

Existing deferred findings from Story 1.3 concern board snapshot parsing, board occupant migration/consistency, and mutable `get_cell()` access. They are not RNG story scope. Do not fix or rewrite board snapshot internals here unless an RNG test directly exposes a new regression.

### Git Intelligence

Recent commit `dcf393e feat: complete epic 1 tactical foundations` indicates Stories 1.1 through 1.3 have been completed and committed. Work from the clean current tree. Preserve any unrelated user changes if the tree becomes dirty while implementing.

### Project Structure Notes

- `godot/scripts/core/state/` is the correct home for `RngStreamSet`.
- Core RNG tests belong under `godot/tests/unit/core/`.
- Save DTO compatibility tests, if needed, belong under `godot/tests/unit/save/`.
- Do not move RNG code into `scripts/tactical`, `scripts/generation`, `scripts/save`, `scripts/autoloads`, scenes, or UI folders.
- Root `project-context.md` is canonical. Do not create a duplicate project context file under `_bmad-output/`.
- No standalone UX file exists; that is non-blocking for this domain-first RNG story.

### Testing Requirements

Run at minimum:

```powershell
godot --version
godot --headless --path C:\Sealsworn\godot --scene res://tests/headless/test_runner.tscn --quit-after 10
git diff --check
```

Expected final result:

- Godot version is `4.6.3.stable.official...` or otherwise explicitly compatible with project policy.
- Headless runner exits with code `0`.
- Existing Story 1.1, 1.2, and 1.3 tests still pass.
- New Story 1.4 tests cover required streams, same-seed determinism, stream isolation, cosmetic isolation, snapshot/restore with draw indexes, strict malformed restore rejection, unknown/invalid stream no-mutation, invalid range no-mutation, draw audit metadata, and deterministic replay fixtures.
- No test requires rendered scenes, audio, UI scenes, presentation nodes, external services, or prototype code.

### Project Context Rules

- Read and follow root `project-context.md` before implementation.
- Read `_bmad-output/game-architecture.md` before architecture-sensitive changes.
- Root `project-context.md` is canonical; do not create duplicate project context under `_bmad-output/`.
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
- Do not introduce cloud services, accounts, multiplayer, telemetry dependencies, or Godot .NET/C# unless the architecture is explicitly revised.
- Preserve user changes and unrelated dirty worktree files.

### References

- [Source: `_bmad-output/planning-artifacts/epics.md` - Story 1.4]
- [Source: `_bmad-output/implementation-artifacts/epic-1-sprint-plan-2026-06-04.md` - Sprint Slice 1]
- [Source: `_bmad-output/implementation-artifacts/1-3-actionresult-and-domain-event-foundation.md` - Previous Story Intelligence]
- [Source: `_bmad-output/implementation-artifacts/deferred-work.md` - Deferred board work not in RNG scope]
- [Source: `project-context.md` - Determinism & Simulation Rules, Testing Rules, Critical Don't-Miss Rules]
- [Source: `_bmad-output/game-architecture.md` - RNG And Determinism, Data Persistence, Testing/Headless Simulation]
- [Source: `_bmad-output/planning-artifacts/gdds/gdd-Game-2026-05-31/gdd.md` - Procedural Generation determinism and manual seed rules]
- [Source: Godot 4.6.3 archive](https://godotengine.org/download/archive/4.6.3-stable/)
- [Source: Godot RandomNumberGenerator docs](https://docs.godotengine.org/en/stable/classes/class_randomnumbergenerator.html)
- [Source: Godot static typing docs](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/static_typing.html)

## Dev Agent Record

### Agent Model Used

Codex GPT-5

### Debug Log References

- 2026-06-05: Review patches applied: `GameSession.restore_rng_snapshot()` now honors failed restore results, cyclic RNG consumer contexts fail before state mutation, and story trailing whitespace was removed; required validation passed.
- 2026-06-05: Added focused `RunSnapshot` RNG stream dictionary round-trip coverage; headless suite passed.
- 2026-06-05: Final validation passed: `godot --version` returned `4.6.3.stable.official.7d41c59c4`; full headless suite passed; `git diff --check` exited 0 with line-ending warnings only.
- 2026-06-05: Added deterministic gameplay RNG replay and cosmetic-isolation fixtures; headless suite passed.
- 2026-06-05: Added `invalid_rng_range` no-mutation handling and confirmed unknown/invalid errors do not emit draw audit metadata; headless suite passed.
- 2026-06-05: Direct randomness scan `rg "RandomNumberGenerator|randomize\\(|randi\\(|randf\\(|rand_from_seed" godot\\scripts` found matches only in `godot/scripts/core/state/rng_stream_set.gd`.
- 2026-06-05: Hardened RNG snapshots and restore validation with `try_restore()`; headless suite passed.
- 2026-06-05: Added audited draw metadata and per-stream draw indexes to `RngStreamSet`; headless suite passed.
- 2026-06-05: Expanded Story 1.4 RNG stream contract coverage in `godot/tests/unit/core/test_rng_stream_set.gd`; headless suite passed, confirming the existing stream isolation implementation already satisfied task 1.4.1.

### Implementation Plan

- Expand the existing RNG test suite task-by-task, then update `RngStreamSet` only where the new contract requires stricter audit, snapshot, restore, or error behavior.
- Keep RNG logic domain-only in `godot/scripts/core/state/rng_stream_set.gd`; avoid presentation nodes, gameplay commands, and broader save migration scope.

### Completion Notes List

- Completed task 1.4.6 by preserving the autoload boundary, adding focused `RunSnapshot.rng_streams` round-trip coverage for the stronger RNG snapshot dictionary, and passing required Godot version, headless suite, and diff validation.
- Completed task 1.4.5 by adding replay fixtures that compare gameplay draw values, audited metadata, gameplay-only stream snapshots, and ordered empty `ActionResult.events` arrays across identical and cosmetic-noisy runs. Future gameplay commands remain responsible for emitting their own outcome events.
- Completed task 1.4.4 by validating integer ranges before state mutation, returning `invalid_rng_range`, keeping unknown/invalid errors separate from successful draw audit metadata, and verifying no production script outside `RngStreamSet` owns direct gameplay randomness.
- Completed task 1.4.3 by adding `draw_index` to stream snapshots, introducing staged `try_restore()` validation, preserving the `restore()` wrapper, rejecting malformed snapshots with `invalid_rng_snapshot`, and testing restore replay for every required stream.
- Completed task 1.4.2 by adding optional `consumer_context` arguments, per-stream draw indexes, state-before/state-after audit fields, draw type, serializable context filtering, and deep-copy protection for successful RNG draw metadata.
- Completed task 1.4.1 by extending the existing RNG test suite for required stream ordering, same-seed replay, stream existence, combat isolation from unrelated streams, and invalid stream no-mutation behavior. The expanded tests pass against the current implementation.
- Story context created on 2026-06-05 from Epic 1 source requirements, the Epic 1 sprint plan, prior Story 1.3, root project context, game architecture, GDD determinism requirements, current Godot RNG code/tests, clean git baseline, and official Godot technical references.
- Developer guidance intentionally scopes Story 1.4 to named RNG stream determinism, draw audit metadata, snapshot/restore validation, invalid/no-mutation behavior, and headless replay fixtures.

### File List

- `_bmad-output/implementation-artifacts/1-4-named-rng-streams-for-deterministic-gameplay.md`
- `_bmad-output/implementation-artifacts/sprint-status.yaml`
- `godot/scripts/core/state/rng_stream_set.gd`
- `godot/tests/unit/core/test_rng_stream_set.gd`
- `godot/tests/unit/save/test_run_snapshot.gd`

## Change Log

- 2026-06-05: Implemented Story 1.4 named RNG stream determinism, audit metadata, strict snapshot/restore validation, invalid range handling, replay fixtures, save DTO coverage, and moved story to review.
- 2026-06-05: Created Story 1.4 implementation guide and marked it ready for development.
