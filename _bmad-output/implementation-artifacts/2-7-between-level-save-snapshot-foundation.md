---
created: 2026-06-14
source_story_key: 2-7-between-level-save-snapshot-foundation
---

# Story 2.7: Between-Level Save Snapshot Foundation

Status: ready-for-dev

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a player,
I want the run to save between levels,
so that interruption-friendly sessions do not lose progress.

## Acceptance Criteria

1. Given a level is completed or exited to a between-level boundary, when autosave is requested, then a versioned domain snapshot is written through `SaveRepository`, and no scene nodes are serialized as save truth.
2. Given a save snapshot is created, when its contents are inspected in tests, then it includes schema version, content version, root seed, RNG stream states, route or current-node state where available, player state, inventory placeholder fields, and manual-seed eligibility, and unsupported future fields are absent or explicitly nullable.
3. Given tactical snapshot boundaries were established in Epic 1, when between-level save data is assembled, then the save repository reuses or composes those domain snapshot structures, and save/resume does not invent a parallel scene-owned state format.
4. Given save writing fails, when the repository reports the error, then the game receives a structured save result, and domain state is not corrupted by the failed write.

## Tasks / Subtasks

- [ ] 2.7.1 Confirm the Epic 2 save-slice boundary and write failing tests first. (AC: 1-4)
  - [ ] Verify `sprint-status.yaml` has `epic-1: done`, Stories 2.1-2.6 `done`, and this story `ready-for-dev` before implementation starts. If any earlier status regressed, stop and restore the boundary first.
  - [ ] Confirm the working tree is clean or that dirty files are intentional user work; preserve unrelated changes. The untracked orchestrator-owned `_bmad-output/auto-gds/` directory is expected and is not your change.
  - [ ] Add focused failing tests FIRST, before any production edit. Recommended: extend `godot/tests/unit/save/test_run_snapshot.gd` and `godot/tests/unit/save/test_save_repository.gd`, and add `godot/tests/integration/save/test_between_level_save.gd` (create the `tests/integration/save/` folder if it does not exist).
  - [ ] Reuse `BoardFixtureFactory` (e.g. `deterministic_actor_placement()` / `micro_combat_board()`), `RngStreamSet`, `TacticalSnapshot.from_domain()`, `RunSnapshot`, and `SaveRepository`. Do NOT invent a new board fixture, a new snapshot DTO family, or a new test framework.
  - [ ] Do NOT build a resume/load UI, a save-slot menu UI, mid-level autosave, settings persistence, profile/meta save files, or `MoveCommand`/`AttackCommand`/level/route gameplay systems in this story. (Resume FLOW and mid-level feasibility are Story 2.8; settings persistence is Story 2.9; route/level systems are Epics 3-4.)
- [ ] 2.7.2 Compose the existing tactical snapshot into the between-level run save instead of inventing a parallel format. (AC: 1, 3)
  - [ ] Reuse `TacticalSnapshot` (`godot/scripts/save/snapshots/tactical_snapshot.gd`, schema 1, `content_version "mvp-0"`) as the authoritative tactical/level payload. It already serializes `board`, `turn_state`, `pending_telegraphs`, `rng_streams`, and `event_log` and strictly validates board + RNG on parse.
  - [ ] Carry the tactical snapshot inside `RunSnapshot.level_state` (recommended: `level_state = {"tactical_snapshot": tactical_snapshot.to_dictionary()}` under a stable key such as `tactical_snapshot`), or document and test an equivalent composition. Do NOT duplicate the tactical board/turn/telegraph/event fields as new ad hoc top-level run-save keys.
  - [ ] If you add a between-level assembly helper, put it in the save layer (recommended: a `RunSnapshot.from_between_level(...)` static helper or a small `BetweenLevelSave` composer under `godot/scripts/save/`). Keep it data-only `RefCounted`; do not move tactical truth, turn decisions, or command validation into the save layer, autoloads, scenes, or UI.
  - [ ] When the run-save is loaded, the embedded tactical snapshot must still pass `TacticalSnapshot.parse()` strict validation (board occupant consistency, RNG validity, finite floats, no forbidden references). Add a test proving a corrupt embedded tactical snapshot is rejected with a structured error and no partial state activation.
- [ ] 2.7.3 Confirm and test the AC2 between-level field contract on `RunSnapshot`. (AC: 2)
  - [ ] `RunSnapshot` already exposes the AC2-required fields. Map AC2 terms to the EXISTING fields (do NOT rename or re-add removed fields):
    - schema version -> `schema_version` (`SCHEMA_VERSION = 1`); content version -> `content_version` (`"mvp-0"`).
    - root seed -> `root_seed`; RNG stream states -> `rng_streams` (a `RngStreamSet.to_snapshot()` dictionary).
    - route / current-node state where available -> `route_state`, `current_route_node_id`, `revealed_route_node_ids` (default empty `{}`/`""`/`[]` at this point in the project; route systems arrive in Epic 4).
    - player state + level state -> `level_state` (now composing the tactical snapshot per 2.7.2), `turn_state`, `board`.
    - inventory placeholder fields -> `inventory` (default empty `[]`); also `equipment`/`passives`/`curses`/`gold`/`oath_shards`/`corruption`/`affinities`/`meta_progression` already exist as nullable/empty defaults.
    - manual-seed eligibility -> the EXISTING split fields `is_manual_seed: bool` and `meta_progression_eligible: bool`. (See "Manual-Seed Eligibility Contract" — Story 1.5/RunSnapshot deliberately replaced the ambiguous `manual_seed_eligible_for_progression` field with this two-field split; `test_run_snapshot.gd` asserts the old field MUST NOT reappear.)
  - [ ] Add a test asserting a freshly built between-level `RunSnapshot` round-trips all AC2 fields through `to_dictionary()` -> `parse()` and that unsupported future fields are absent or explicitly empty/nullable (no surprise keys, no non-nullable placeholders that lie about data the MVP does not have yet).
  - [ ] Do NOT add new gameplay fields (real inventory items, route graphs, affinity rules, etc.). They are owned by later epics; keep them as the existing empty defaults.
- [ ] 2.7.4 Add an explicit between-level autosave entry point that writes through `SaveRepository`. (AC: 1, 4)
  - [ ] `SaveRepository.write_run_snapshot()` already performs the atomic temp -> backup -> replace write and returns structured `ActionResult` errors (`save_open_failed`, `save_backup_remove_failed`, `save_backup_failed`, `save_replace_failed`). Reuse it; do NOT add a second write path or a non-atomic writer.
  - [ ] Add a thin between-level autosave entry point. Recommended: a `SaveManager.autosave_between_level(snapshot: RunSnapshot) -> ActionResult` method delegating to `repository.write_run_snapshot(snapshot)`. Keep `SaveManager` a thin autoload that delegates to `SaveRepository`; it must not own snapshot schema policy, tactical truth, or composition logic.
  - [ ] The entry point must return the repository's structured `ActionResult` unchanged (or a thin wrapper preserving `error_code` + metadata). Do not swallow the error or convert it to a bool.
  - [ ] Do NOT call command execution, enemy turn resolution, level-system advancement, or gameplay RNG draws from the autosave path. Saving is a read-only snapshot of existing domain state.
- [ ] 2.7.5 Prove the AC4 save-failure contract: structured error, no domain corruption, original file preserved. (AC: 4)
  - [ ] Add a test that forces a write failure and asserts a structured `ActionResult.is_error()` with a stable `error_code` and diagnostic metadata (e.g. write to an unwritable/`res://` path, or a `.tmp`/`.bak` path that cannot be created/removed). Use a temp `user://` test path and clean it up.
  - [ ] Assert the in-memory `RunSnapshot` (and any source `BoardState`/`RngStreamSet`) is unchanged after a failed write — saving must never mutate domain state.
  - [ ] Assert that when a prior valid save file exists and a new write fails mid-way, the original save file is preserved (the temp/backup dance must not leave the canonical `save_path` destroyed or truncated). This is the architecture "Save Failure -> Preserve original file" requirement.
  - [ ] Keep these tests headless and domain/save-only; do not instantiate scenes, UI, audio, or animation nodes.
- [ ] 2.7.6 Prove AC1/AC3 no-scene-truth and reuse guarantees with tests. (AC: 1, 3)
  - [ ] Assert the written run-save JSON contains only serializable domain data: primitives, arrays, dictionaries — no `Object`/`Node`/`Callable`/`RID`, no `res://` scene/resource paths, no `.tscn`/`.scn`/`.anim`/audio strings, and nothing matching the `TacticalSnapshot` forbidden-reference filter. Reuse the existing `TacticalSnapshot` serializable filtering for the tactical payload rather than writing a parallel sanitizer.
  - [ ] Assert the between-level save reuses `TacticalSnapshot` (the embedded payload parses via `TacticalSnapshot.parse()`), demonstrating no parallel scene-owned save format was invented (AC3).
  - [ ] Assert a full assemble -> write -> read -> reparse round-trip preserves root seed, RNG stream states (seed/state/draw_index per stream), the embedded tactical board, turn state, and manual-seed eligibility flags.
- [ ] 2.7.7 Run required validation and update story records. (AC: 1-4)
  - [ ] Run `godot --version` (through PowerShell — see Testing Requirements).
  - [ ] Run the full headless suite through PowerShell (the bare `godot` is not on the Bash tool PATH; see Testing Requirements).
  - [ ] Run `git diff --check`.
  - [ ] Update this story's Dev Agent Record, Implementation Plan, Completion Notes, File List, and Change Log with the actual implementation work.
  - [ ] Keep `sprint-status.yaml` synchronized with this story status.

## Dev Notes

### Pre-Implementation Gate

This is the seventh Epic 2 implementation story (Sprint Slice 6: Save/Resume Foundation, first of two — Story 2.8 is the resume flow + mid-level feasibility partner). Story-creation analysis on 2026-06-14 found:

- `epic-1: done`; Stories 2.1-2.6 all `done`; Story 2.7 `backlog` before this file was created; Stories 2.8 and 2.9 `backlog`.
- The save layer already exists and is substantially built (see "Current Repository Baseline"). This story is mostly **composition + a between-level entry point + test hardening**, not a greenfield save format.

Before implementing, confirm the local tree is still clean or that dirty files are intentional user work. If any Story 2.1-2.6 status has regressed, stop and restore that boundary before adding the between-level save foundation.

### Scope Boundary

This story establishes the **between-level autosave foundation**: a versioned domain snapshot written through the existing `SaveRepository`, composing the Epic 1 `TacticalSnapshot` into the run-level `RunSnapshot` (no parallel scene-owned format), with the AC2 field contract confirmed and tested, an explicit between-level autosave entry point, and the AC4 structured-failure / no-corruption / original-file-preserved guarantees proven by tests.

In scope:

- Compose `TacticalSnapshot` into the between-level run save (via `RunSnapshot.level_state`) and prove the embedded payload still strictly validates on load.
- Map every AC2 field onto the existing `RunSnapshot` fields (including the `is_manual_seed` + `meta_progression_eligible` split for manual-seed eligibility) and test the round-trip.
- A thin between-level autosave entry point (recommended `SaveManager.autosave_between_level`) that delegates to `SaveRepository.write_run_snapshot()`.
- Tests for structured write-failure errors, no domain mutation on failed write, original-file preservation, no-scene-truth serialization, and the assemble->write->read->reparse round-trip.

Out of scope (owned elsewhere — do not build here):

- **Resume/load FLOW, save-slot/recovery UI, and interrupted-vs-uninterrupted divergence comparison** — Story 2.8 owns the resume flow and the mid-level save/resume feasibility decision (implemented/deferred/limited). This story writes the between-level snapshot; it does not implement the resume path or the divergence harness.
- **Mid-level autosave** — explicitly Story 2.8's feasibility question. Do not add mid-level save triggers here.
- **Settings persistence / profile/meta save files** — Story 2.9 owns the settings subsystem; profile/meta data lives in separate files (architecture Data Persistence). This story writes only the current-run autosave.
- **Real gameplay content fields** — actual inventory items, route graphs, level recipes, affinity rules, classes, loot, and meta-progression content arrive in Epics 3-9. Keep `RunSnapshot`'s gameplay fields at their existing empty/nullable defaults.
- **`MoveCommand`/`AttackCommand`/level state machine/route state machine/fog systems** beyond what already exists. Saving snapshots existing domain state; it does not create new gameplay systems to make the snapshot look fuller.
- **Save migrations beyond schema 1.** If a migration question appears, record it in `_bmad-output/implementation-artifacts/deferred-work.md` unless it blocks this story's ACs.
- Cloud saves, accounts, multiplayer, leaderboards, telemetry, Godot .NET/C#, React/Vite production dependencies, or new test frameworks.

### Current Repository Baseline (READ THIS FIRST — the save layer already exists)

The save layer is already implemented from Epic 1 and earlier. The primary mistake to avoid is **reinventing a save format that already exists**. Reuse and compose; do not duplicate.

- `godot/scripts/save/save_repository.gd` — `SaveRepository extends RefCounted`. `write_run_snapshot(snapshot: RunSnapshot, save_path := "user://run_autosave.json") -> ActionResult` ALREADY does an atomic temp -> remove-stale-backup -> rename-original-to-backup -> rename-temp-to-final -> remove-backup sequence, returning structured errors `save_open_failed`, `save_backup_remove_failed`, `save_backup_failed`, `save_replace_failed`, and rolling the backup back on a failed replace. `read_run_snapshot(save_path) -> ActionResult` returns `save_not_found` / `save_open_failed` / `save_parse_failed` or delegates to `RunSnapshot.parse()`. AC1 and AC4's atomic-write/error machinery are largely DONE — this story reuses them and adds the missing tests + between-level entry point.
- `godot/scripts/save/snapshots/run_snapshot.gd` — `RunSnapshot extends RefCounted`, `SCHEMA_VERSION = 1`, `content_version = "mvp-0"`. Already has every AC2 field: `schema_version`, `content_version`, `profile_id`, `run_id`, `root_seed`, `is_manual_seed`, `meta_progression_eligible`, `route_state`, `current_route_node_id`, `revealed_route_node_ids`, `level_state`, `turn_state`, `rng_streams`, `board`, `inventory`, `equipment`, `passives`, `curses`, `gold`, `oath_shards`, `corruption`, `affinities`, `meta_progression`. `to_dictionary()` deep-copies; `parse()` rejects unsupported schema (`unsupported_save_schema`) and coerces other fields leniently via `_dictionary_or_empty`/`_string_array`/`_dictionary_array`/`int()`/`bool()`.
- `godot/scripts/save/snapshots/tactical_snapshot.gd` — `TacticalSnapshot extends RefCounted`, schema 1, `CONTENT_VERSION "mvp-0"`. `from_domain(board_state, streams, turn_state, pending_telegraphs, event_log) -> ActionResult` and strict `parse(data) -> ActionResult` (all errors are `invalid_tactical_snapshot` with a stable `reason` in metadata). It validates board occupant consistency, RNG validity, rejects non-finite floats, rejects forbidden reference strings (`res://`, `.tscn`/`.scn`/`.anim`/audio, anything containing `presentation`), and canonicalizes the event log via `DomainEvent`. THIS is the Epic 1 tactical snapshot boundary AC3 requires you to reuse.
- `godot/scripts/autoloads/save_manager.gd` — thin `Node` autoload (registered in `project.godot`) that currently exposes `write_run_snapshot()` / `read_run_snapshot()` delegating to a `SaveRepository` instance. Add the between-level entry point here; keep it thin.
- `godot/scripts/autoloads/game_session.gd` — thin `Node` autoload holding `root_seed` + a `RngStreamSet`, with `configure_seed()`, `rng_snapshot()`, and `restore_rng_snapshot()`. It owns seed/RNG session wiring only; it must NOT gain tactical state, snapshot schema policy, or command validation. It is a convenient source of `root_seed` + `rng_snapshot()` for assembling a between-level save.
- `godot/scripts/core/state/rng_stream_set.gd` — named RNG streams (`map`/`level`/`combat`/`loot`/`rewards`/`events`/`cosmetic`); `to_snapshot()` / strict `try_restore()` returning `invalid_rng_snapshot` on malformed input.
- `godot/scripts/tactical/board/board_state.gd` — `BoardState` with `to_snapshot()`, strict `try_from_snapshot()`, `validate_snapshot_consistency()`, sorted cells/entities.
- `godot/tests/unit/save/test_save_repository.gd` — currently covers happy-path write->read round-trip and unsupported-schema rejection. **Missing: write-failure / no-corruption / original-file-preserved tests (AC4).**
- `godot/tests/unit/save/test_run_snapshot.gd` — currently covers schema parse/reject, the explicit `is_manual_seed`/`meta_progression_eligible` flags (and asserts the ambiguous `manual_seed_eligible_for_progression` key is ABSENT), the run-state contract round-trip, and the RNG dictionary round-trip. **Missing: the composed tactical-snapshot-in-`level_state` round-trip and the strict-reject-on-corrupt-embedded-tactical case (AC3).**
- `godot/tests/fixtures/tactical/board_fixture_factory.gd` — reusable board fixtures (`deterministic_actor_placement()`, `micro_combat_board()`, etc.). Reuse for building a real tactical snapshot to embed.
- There is currently **no `LevelSnapshot` class** (the architecture names one aspirationally at line 958, but on disk level data is the `RunSnapshot.level_state` dictionary). Do not create a `LevelSnapshot` class for this story unless a failing test proves the embedded-tactical-in-`level_state` approach is unworkable; if you do, justify it here and keep it a data-only `RefCounted` save DTO.

### Existing Files To Update Or Preserve

| Path | Current State | This Story Changes | Preserve |
|---|---|---|---|
| `godot/scripts/save/snapshots/run_snapshot.gd` | Versioned run-save DTO with all AC2 fields, deep-copy `to_dictionary()`, lenient `parse()`. | Optionally add a thin `from_between_level(...)` assembly helper that embeds a `TacticalSnapshot` dictionary into `level_state`. If you do, prefer composing the tactical snapshot's strict validation on load. | All existing fields/defaults, the `is_manual_seed`+`meta_progression_eligible` split, deep-copy behavior, `unsupported_save_schema` rejection. Do NOT re-add `manual_seed_eligible_for_progression`. |
| `godot/scripts/save/save_repository.gd` | Atomic temp/backup/replace write + structured errors; structured read. | Usually NO change — reuse as-is. Add a narrow change only if an AC4 test proves a real gap (e.g. the original file is not actually preserved on a specific failure). | The atomic write sequence, all `save_*` error codes, the backup rollback, `read_run_snapshot` structured errors. |
| `godot/scripts/save/snapshots/tactical_snapshot.gd` | Strict Epic 1 tactical snapshot DTO (board/turn/telegraphs/rng/event_log) with serializable filtering. | Read-only reuse as the embedded tactical payload + its strict `parse()` validation on load. No change expected. | Strict parse, serializable filtering, forbidden-reference rejection, `from_domain` validation. |
| `godot/scripts/autoloads/save_manager.gd` | Thin autoload delegating write/read to `SaveRepository`. | Add a thin `autosave_between_level(snapshot) -> ActionResult` delegating to the repository. | Thin-autoload posture; no schema policy, no tactical truth, no composition logic here. |
| `godot/scripts/autoloads/game_session.gd` | Thin seed/RNG session wiring. | Usually NO change. May be read for `get_root_seed()`/`rng_snapshot()` when assembling a save. | No gameplay decisions, no tactical state, no snapshot schema ownership. |
| `godot/tests/unit/save/test_run_snapshot.gd` | Schema, flags, run-state, RNG round-trip tests. | Add the composed-tactical-in-`level_state` round-trip test and a corrupt-embedded-tactical reject test. | Existing assertions (including the "ambiguous field absent" assertion) remain green. |
| `godot/tests/unit/save/test_save_repository.gd` | Happy-path write/read + unsupported-schema reject. | Add write-failure / no-mutation / original-file-preserved tests (AC4). | Existing round-trip + schema-reject tests remain green; always clean up `user://` test files. |
| `godot/tests/fixtures/tactical/board_fixture_factory.gd` | Reusable tactical fixtures. | Reuse to build a real `BoardState` + `RngStreamSet` for the embedded snapshot. Add a small helper only if it removes duplication. | Deterministic setup and existing tests. |

### Recommended New Files

Use these names unless implementation discovers a clearer local pattern:

- `godot/tests/integration/save/test_between_level_save.gd` (assemble real domain state -> `TacticalSnapshot.from_domain()` -> embed in `RunSnapshot` -> `SaveRepository.write_run_snapshot()` -> read -> reparse; plus the AC4 failure case end-to-end). Create the `godot/tests/integration/save/` folder if needed; the headless runner auto-discovers `test_*.gd` under `godot/tests/integration`.
- Optionally `godot/scripts/save/between_level_save.gd` OR a `RunSnapshot.from_between_level(...)` static helper — only if a composer reads clearer than assembling the `RunSnapshot` inline in the autosave caller. Keep it a data-only `RefCounted`/static helper in the save layer.

Avoid adding a new save format, a new snapshot DTO family, a `LevelSnapshot` class, a settings subsystem, a resume/load UI, an autoload, a plugin, or any new test framework for this story.

### Composition Contract (AC3 — reuse, do not reinvent)

The single most important architecture constraint: **AC3 requires composing the existing Epic 1 `TacticalSnapshot` into the between-level save, not inventing a parallel scene-owned format.**

Recommended composition:

```gdscript
# Assemble a between-level save from existing domain state.
var tactical_result: ActionResult = TacticalSnapshot.from_domain(board_state, rng_streams, turn_state, pending_telegraphs, event_log)
# (guard tactical_result.is_error())
var tactical: TacticalSnapshot = tactical_result.metadata.get("snapshot")

var snapshot := RunSnapshot.new()
snapshot.root_seed = game_session.get_root_seed()
snapshot.rng_streams = rng_streams.to_snapshot()          # run-level RNG snapshot
snapshot.is_manual_seed = <from session/run config>
snapshot.meta_progression_eligible = not snapshot.is_manual_seed   # manual seed grants no meta progression
snapshot.current_route_node_id = <if available, else "">
snapshot.level_state = {"tactical_snapshot": tactical.to_dictionary()}  # embed, do not flatten
# inventory/equipment/passives/etc. stay at their empty defaults for now

var write_result: ActionResult = SaveManager.autosave_between_level(snapshot)
```

Rules:

- The tactical payload is embedded under a stable key in `level_state` (recommended `tactical_snapshot`). Do NOT copy the tactical board/turn/telegraph/event fields out as new ad hoc top-level run-save keys — that would fork the schema `TacticalSnapshot` already owns.
- On load, re-run `TacticalSnapshot.parse()` against the embedded dictionary so corrupt tactical data is rejected with a structured error (the run-save `parse()` is lenient by design for forward-compat of run-level fields; the tactical payload must stay strict).
- `RunSnapshot.rng_streams` and the embedded tactical `rng_streams` may both be present; if so, keep them consistent and document which is authoritative for the between-level boundary (recommended: the run-level `rng_streams` is the between-level authority; the tactical snapshot's `rng_streams` reflects the in-level stream state at exit). Do not silently let them disagree without a test.
- Snapshots are save truth = versioned domain data only. Never serialize scene nodes, `Control`s, audio, animation, or presentation references (the `TacticalSnapshot` serializable filter already enforces this for the tactical payload; keep run-level additions equally clean).

### Manual-Seed Eligibility Contract (do NOT reintroduce the removed field)

AC2 says the snapshot must include "manual-seed eligibility." The project already settled this:

- `RunSnapshot` represents it as TWO explicit booleans: `is_manual_seed` and `meta_progression_eligible`.
- `test_run_snapshot.gd::_seed_progression_flags_are_explicit()` asserts the ambiguous field `manual_seed_eligible_for_progression` is ABSENT from `to_dictionary()`. Reintroducing it will fail that test and re-open a resolved decision.
- Semantics (architecture + GDD + project-context): manual-seed runs are allowed for replay/debug/share/practice but grant NO meta progression. So a between-level save for a manual-seed run should set `is_manual_seed = true` and `meta_progression_eligible = false`. Enforcement of "manual seed grants no progression" at the meta layer is Epic 8 (FR28) — this story only persists the flags honestly; do not implement progression gating here.

### State / No-Mutation Contract

Writing a save is a pure read of existing domain state. The autosave path must never mutate or replace tactical truth.

Never do these during between-level save assembly or write:

- Execute move or attack commands or call the command bridge build/execute path.
- Resolve enemy turns or advance level/route systems.
- Consume gameplay RNG streams (snapshotting `to_snapshot()` does not draw; do not call `rand_*`).
- Change board visibility, occupants, HP, pending telegraphs, turn phase, event log, rewards, or progression.
- Corrupt or partially overwrite an existing valid save on a failed write (AC4: preserve the original file).

### Previous Story Intelligence

Story 1.5 (Tactical Snapshot Serialization Boundary) is the direct ancestor of this story and defined the reuse target:

- It built `TacticalSnapshot` strict parse/export, serializable-only filtering, board/cell occupant-consistency validation, RNG validation, and deterministic restore/continuation tests. Story 2.7 composes that snapshot; it must not weaken or fork it.
- Story 1.5 review patches hardened: rejecting missing/non-positive `next_sequence_id`, missing/malformed `entities` containers, incompatible `content_version`, source-board cell-key consistency after mutable `get_cell()` edits, non-finite floats, and animation/VFX/presentation resource strings. These guards live in `TacticalSnapshot`/`BoardState`; reuse them, do not duplicate.
- Story 1.5 deliberately did NOT wire tactical snapshots into `SaveRepository`/`SaveManager` ("Between-level save/resume belongs to Epic 2"). **Story 2.7 is where that wiring happens** — but through composition into `RunSnapshot`, keeping save-layer DTOs data-only and autoloads thin.
- Story 1.5 kept `GameSession` as thin seed/RNG/session wiring with no tactical state, snapshot policy, or command validation. Preserve that here.

Epic 1 / earlier review lessons that still apply:

- Failed restores/writes must not desync autoload/session state from domain state (Story 1.4 patch lesson). Apply the equivalent here: a failed save must not mutate `GameSession` RNG, the `BoardState`, or the in-memory `RunSnapshot`.
- Invalid/failure paths need no-mutation assertions against stable snapshots, and structured `ActionResult.error()` with stable lower-snake codes + diagnostic metadata. Treat the AC4 failure path with the same rigor.
- `ActionResult.error()`/`ok()` deep-copy metadata and normalize codes; `DomainEvent.try_from_dictionary()` rejects malformed dicts. Reuse, don't reimplement.

Epic 2 cross-story facts (from earlier Epic 2 stories) that touch save reuse:

- The Epic 2 UI/view-model layer (Stories 2.1-2.6) is presentation-only and is NOT save truth. Do not serialize any view-model output (`TacticalBoardViewModel`, accessibility cues, layout profiles, text-scale hints) into the save — those are derived presentation contracts, not domain state. The save composes domain snapshots (`BoardState`/`RngStreamSet`/`DomainEvent` via `TacticalSnapshot` + `RunSnapshot`) only.

### Git Intelligence

Recent commits before this story:

- `18564ed Merge pull request #3 from rthunborg/story/2-6-accessibility-and-tactical-readability-baseline`
- `8e991be chore(story-2-6): finalize (mark done + GDS status)`
- `cbeceda docs(story-2-6): pipeline report`
- `e7c1d74 chore(story-2-6): code review passed`
- `2dad37e feat(story-2-6): accessibility & tactical-readability baseline cue contract`

Actionable patterns:

- The project consistently uses narrow typed `RefCounted` DTOs under `scripts/save/snapshots/`, thin autoloads under `scripts/autoloads/`, and tests-first under `tests/unit/<domain>/` (with integration tests under `tests/integration/<domain>/`). Follow that; do not add GUT/GdUnit or any new framework.
- The headless runner auto-discovers `test_*.gd` under `godot/tests/unit` and `godot/tests/integration`; no registry edit is needed.
- ENVIRONMENT (Epic 2 retro): the bare `godot` resolves only as `C:\Users\Rasmus\bin\godot.cmd` through PowerShell; the Bash tool's PATH/`where` cannot find it. Run `godot --version` and the headless suite through `powershell.exe -NoProfile -Command`.
- Review findings across the project have repeatedly tightened value sanitization, no-mutation assertions, stable reason ids, and structured error metadata. Treat all four as first-class for the save-failure and composition tests.

### Architecture Compliance

- Save truth is versioned domain snapshots only, written through `SaveRepository`; never serialize scene nodes, `Control`s, audio, animation, or presentation references. [Source: game-architecture.md#Data Persistence]
- Save data should include schema/content version, root seed + named RNG stream states, route/current-node/revealed-route + manual-seed eligibility, level/fog/entity/turn state, inventory/equipment/passives/etc., with player settings and profile/meta in SEPARATE files from the current-run autosave. This story writes the current-run autosave only. [Source: game-architecture.md#Data Persistence]
- Gameplay systems depend on repository contracts, not raw JSON files, so storage can evolve. Go through `SaveRepository`. [Source: game-architecture.md#Data Persistence, #Data Access Pattern]
- Save Failure handling: preserve the original file, report clearly via a structured result, enter a recovery flow. This story delivers the structured result + original-file preservation; the recovery FLOW UI is Story 2.8. [Source: game-architecture.md Error Levels table]
- Thin autoloads (`GameSession`, `SaveManager`) may exist but must delegate gameplay decisions to the domain model and must not own tactical state or schema policy. [Source: game-architecture.md autoload rules; project-context.md]
- `scripts/save/` must not depend on Godot scene nodes for authoritative logic; snapshot DTOs are `RefCounted`. [Source: game-architecture.md system-location rules; project-context.md]
- Named RNG streams remain the only gameplay-affecting randomness; save assembly snapshots their state and consumes no draws. [Source: project-context.md Determinism rules]
- Headless tests run without rendering, audio, UI scenes, presentation nodes, or scene-tree-only state. [Source: project-context.md Testing rules]
- Do not add cloud services, accounts, multiplayer, telemetry, Godot .NET/C#, new test frameworks, or React/Vite production dependencies. [Source: project-context.md Critical Don't-Miss rules]

### Library And Framework Requirements

- Required engine: Godot 4.6.3 stable standard build.
- Required language: typed GDScript.
- Snapshot/composer DTOs use `RefCounted`, not `Node`.
- Reuse `JSON.stringify()`/`JSON.parse_string()` exactly as `SaveRepository` already does for file I/O; production snapshot validation operates on dictionaries + `ActionResult` (use `JSON` directly only in tests that explicitly assert JSON compatibility).
- Use `Dictionary.duplicate(true)`/`Array.duplicate(true)` for deep copies, while keeping nested data serializable (the `TacticalSnapshot` filter rejects `Object`/`Callable`/`RID`/forbidden strings for the tactical payload).
- Use the existing custom headless harness: tests extend `res://tests/unit/test_case.gd`, expose `run() -> Dictionary`, and return `result()`. Do NOT add GUT, GdUnit, or another testing dependency.

### Latest Technical Information

Official Godot 4.6 sources relevant to a between-level JSON save through a repository (these inform file-I/O correctness, not gameplay):

- Godot `FileAccess` write/flush/close and `DirAccess.rename_absolute()`/`remove_absolute()` are the primitives the existing atomic temp->backup->replace write uses; `FileAccess.get_open_error()` gives the structured open error already surfaced in `save_open_failed`. Keep all file I/O inside `SaveRepository`. Source: https://docs.godotengine.org/en/4.6/classes/class_fileaccess.html and https://docs.godotengine.org/en/4.6/classes/class_diraccess.html
- `user://` resolves to the per-user writable data directory and is the correct save location for MVP (never `res://`, which is read-only in exported builds — useful for the AC4 "unwritable path" failure test). Source: https://docs.godotengine.org/en/4.6/tutorials/io/data_paths.html
- Godot `JSON.parse_string()` returns `null` on parse failure (already handled as `save_parse_failed`); `JSON.stringify()` sorts keys and converts numeric Variants to JSON numbers, so strict integer fields must be validated after parse (the tactical snapshot already does this via `_is_integral_number`). Source: https://docs.godotengine.org/en/4.6/classes/class_json.html

### Project Structure Notes

- Save snapshot DTOs and the optional between-level composer belong under `godot/scripts/save/` (snapshots under `godot/scripts/save/snapshots/`).
- The thin between-level autosave entry point belongs on the existing `SaveManager` autoload (`godot/scripts/autoloads/save_manager.gd`).
- Save tests belong under `godot/tests/unit/save/` (DTO/repository unit tests) and `godot/tests/integration/save/` (end-to-end assemble->write->read->reparse).
- Tactical legality stays under `godot/scripts/tactical/`; do not move tactical truth or command validation into the save layer.
- Production code stays under `godot/`; do not add production dependencies on `prototype/`.
- Root `project-context.md` is canonical. Do not create duplicate project context files under `_bmad-output/`.
- No standalone UX file exists; this is a domain/save boundary story and needs no UI artifact input. The resume/load UI is Story 2.8.

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
- All existing Epic 1 and Story 2.1-2.6 tests remain green — including `test_run_snapshot.gd`'s "ambiguous `manual_seed_eligible_for_progression` field absent" assertion and `test_save_repository.gd`'s existing round-trip + schema-reject tests.
- New tests prove the between-level save COMPOSES `TacticalSnapshot` (embedded payload parses via `TacticalSnapshot.parse()`) rather than inventing a parallel format (AC3).
- New tests prove the AC2 field contract: a freshly built between-level `RunSnapshot` round-trips schema/content version, root seed, RNG stream states, route/current-node fields (empty where unavailable), level/turn/board state, inventory placeholder (empty), and the `is_manual_seed`+`meta_progression_eligible` manual-seed eligibility flags through `to_dictionary()`->`parse()`, with no surprise/un-nullable future fields (AC2).
- New tests prove a corrupt embedded tactical snapshot is rejected with a structured error and no partial state activation.
- New tests prove the AC4 failure contract: a forced write failure returns a structured `ActionResult.is_error()` with a stable `error_code` + metadata, leaves the in-memory `RunSnapshot`/`BoardState`/`RngStreamSet` unchanged, and preserves a pre-existing valid save file.
- New tests prove no-scene-truth serialization: the written JSON contains only primitives/arrays/dictionaries and no `Object`/`Node`/`Callable`/`RID`/`res://`/scene/audio/animation/presentation references.
- All save tests clean up their `user://` temp files (`*.json`, `*.json.tmp`, `*.json.bak`).
- `git diff --check` reports no whitespace errors.

### Project Context Rules

- Read and follow root `project-context.md` before implementation.
- Read `_bmad-output/game-architecture.md` before architecture-sensitive changes (Data Persistence, Error Levels, Data Access Pattern).
- Root `project-context.md` is canonical; do not create duplicate project context under `_bmad-output/`.
- Production code goes under `godot/`; React/Vite `prototype/` remains validation evidence only.
- Production engine is Godot 4.6.3 stable standard; primary language is typed GDScript.
- Target platforms are iOS/Android mobile and tablet first with Windows desktop/laptop parity.
- MVP is offline-first single-player. No accounts, cloud saves, multiplayer, leaderboards, or live-service dependency.
- Scene-independent domain model owns tactical truth; Godot scenes, UI, audio, VFX, and animation mirror domain outcomes and do not own gameplay state.
- Commands validate before mutation and return `ActionResult`; successful commands emit deterministic past-tense `DomainEvent` records. Saving consumes no commands and emits no events.
- Use named RNG streams for gameplay-affecting randomness; save assembly snapshots stream state and consumes no draws.
- Save versioned domain snapshots only through `SaveRepository`; never serialize scene nodes as save truth.
- Keep autoloads thin (`SaveManager`, `GameSession`): they delegate to domain/save services and do not own gameplay decisions or schema policy.
- Headless simulation must not depend on rendering, audio, UI scenes, presentation nodes, or scene-tree-only state.
- Do not introduce cloud services, accounts, multiplayer, telemetry dependencies, Godot .NET/C#, new test frameworks, or third-party libraries unless the architecture is explicitly revised.
- Preserve user changes and unrelated dirty worktree files.

### References

- [Source: `_bmad-output/planning-artifacts/epics.md` - Epic 2 and Story 2.7 acceptance criteria]
- [Source: `_bmad-output/implementation-artifacts/epic-2-sprint-plan-2026-06-07.md` - Sprint Slice 6 Save/Resume Foundation tasks and exit gate]
- [Source: `_bmad-output/implementation-artifacts/1-5-tactical-snapshot-serialization-boundary.md` - `TacticalSnapshot` reuse target, strict validation, "between-level save belongs to Epic 2" deferral, thin-`GameSession` posture]
- [Source: `_bmad-output/auto-gds/retro-notes/epic-2.md` - PowerShell `godot` invocation requirement]
- [Source: `_bmad-output/implementation-artifacts/deferred-work.md` - Story 1.3 board-snapshot defers were resolved in Story 1.5; no open save deferral overlaps this story]
- [Source: `project-context.md` - determinism/save/snapshot rules, thin-autoload rule, headless/testing rules, no-telemetry/no-cloud rules]
- [Source: `_bmad-output/game-architecture.md#Data Persistence` - versioned local JSON in `user://`, `SaveRepository` + snapshot DTOs, required save fields, settings/profile in separate files]
- [Source: `_bmad-output/game-architecture.md` Error Levels table - "Save Failure -> Preserve original file, report clearly, enter recovery flow"]
- [Source: `_bmad-output/game-architecture.md#Data Access Pattern` - `save_repository.write_run_snapshot(snapshot)` repository contract]
- [Source: `_bmad-output/planning-artifacts/gdds/gdd-Game-2026-05-31/gdd.md` - required save/resume between levels, manual-seed-no-progression, fog memory/route/inventory persistence]
- [Source: `godot/scripts/save/save_repository.gd` - atomic temp/backup/replace write + structured `save_*` errors + structured read]
- [Source: `godot/scripts/save/snapshots/run_snapshot.gd` - all AC2 fields, `is_manual_seed`+`meta_progression_eligible` split, `level_state` slot, `unsupported_save_schema` rejection]
- [Source: `godot/scripts/save/snapshots/tactical_snapshot.gd` - Epic 1 tactical snapshot to compose; strict `parse()`/`from_domain()`, serializable filtering]
- [Source: `godot/scripts/autoloads/save_manager.gd` - thin autoload to host the between-level autosave entry point]
- [Source: `godot/scripts/autoloads/game_session.gd` - thin seed/RNG session source for `root_seed`/`rng_snapshot()`]
- [Source: `godot/tests/unit/save/test_run_snapshot.gd` - existing field/flag/round-trip assertions to keep green; ambiguous-field-absent assertion]
- [Source: `godot/tests/unit/save/test_save_repository.gd` - existing happy-path + schema-reject tests; missing AC4 failure coverage to add]
- [Source: `godot/tests/fixtures/tactical/board_fixture_factory.gd` - reusable board fixtures for the embedded tactical snapshot]
- [Source: Godot 4.6 FileAccess docs](https://docs.godotengine.org/en/4.6/classes/class_fileaccess.html)
- [Source: Godot 4.6 DirAccess docs](https://docs.godotengine.org/en/4.6/classes/class_diraccess.html)
- [Source: Godot 4.6 data paths (`user://`) docs](https://docs.godotengine.org/en/4.6/tutorials/io/data_paths.html)
- [Source: Godot 4.6 JSON docs](https://docs.godotengine.org/en/4.6/classes/class_json.html)

## Dev Agent Record

### Agent Model Used

Story context: Claude Opus 4.8 (1M context).

### Implementation Plan

- Add red save tests first: (a) `RunSnapshot` round-trip composing a `TacticalSnapshot` dictionary into `level_state` + a corrupt-embedded-tactical reject; (b) the AC2 field contract round-trip; (c) `SaveRepository`/`SaveManager` AC4 forced-write-failure with no domain mutation and original-file preservation; (d) an integration assemble->write->read->reparse round-trip + no-scene-truth serialization assertion.
- Implement the between-level composition by embedding `TacticalSnapshot.to_dictionary()` under a stable `level_state` key (optionally via a thin `RunSnapshot.from_between_level(...)`/`BetweenLevelSave` composer) and add a thin `SaveManager.autosave_between_level(snapshot) -> ActionResult` delegating to the existing `SaveRepository.write_run_snapshot()`.
- Map manual-seed eligibility onto the existing `is_manual_seed` + `meta_progression_eligible` fields; do NOT re-add `manual_seed_eligible_for_progression`.
- Reuse `SaveRepository`'s atomic write + structured errors and `TacticalSnapshot`'s strict validation/serializable filter; do not fork a second writer or sanitizer. Keep save DTOs `RefCounted` and `SaveManager`/`GameSession` thin.

### Debug Log References

- 2026-06-14: Created Story 2.7 implementation guide from Epic 2 source requirements, the Epic 2 sprint plan (Sprint Slice 6), root project context, game architecture (Data Persistence, Error Levels, Data Access Pattern), the GDD save/resume requirements, Story 1.5 (the `TacticalSnapshot` reuse target and "between-level save belongs to Epic 2" deferral), the Epic 2 auto-gds retro notes, the deferred-work ledger, and direct inspection of the existing save layer on disk (`save_repository.gd`, `run_snapshot.gd`, `tactical_snapshot.gd`, `save_manager.gd`, `game_session.gd`, and the current save tests).
- 2026-06-14: Confirmed story-creation baseline: `epic-1: done`, Stories 2.1-2.6 `done`, Story 2.7 `backlog` before this file was created. Confirmed via code read that `SaveRepository`, `RunSnapshot` (with all AC2 fields + `is_manual_seed`/`meta_progression_eligible` split), `SaveManager`, and `TacticalSnapshot` already exist — so this story is composition + a between-level entry point + AC4/AC3 test hardening, not a greenfield save format.

### Completion Notes List

- Story context created and marked ready for development.
- Ultimate context engine analysis completed - comprehensive developer guide created.

### File List

### Change Log

| Date | Change |
|---|---|
| 2026-06-14 | Created Story 2.7 implementation guide (between-level save snapshot foundation) and marked it ready for development. |
