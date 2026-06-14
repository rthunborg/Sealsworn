---
created: 2026-06-14
source_story_key: 2-7-between-level-save-snapshot-foundation
baseline_commit: 4e501e8c567f1c554e21efdece83665cd923a875
---

# Story 2.7: Between-Level Save Snapshot Foundation

Status: review

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

- [x] 2.7.1 Confirm the Epic 2 save-slice boundary and write failing tests first. (AC: 1-4)
  - [x] Verify `sprint-status.yaml` has `epic-1: done`, Stories 2.1-2.6 `done`, and this story `ready-for-dev` before implementation starts. If any earlier status regressed, stop and restore the boundary first.
  - [x] Confirm the working tree is clean or that dirty files are intentional user work; preserve unrelated changes. The untracked orchestrator-owned `_bmad-output/auto-gds/` directory is expected and is not your change.
  - [x] Add focused failing tests FIRST, before any production edit. Recommended: extend `godot/tests/unit/save/test_run_snapshot.gd` and `godot/tests/unit/save/test_save_repository.gd`, and add `godot/tests/integration/save/test_between_level_save.gd` (create the `tests/integration/save/` folder if it does not exist).
  - [x] Reuse `BoardFixtureFactory` (e.g. `deterministic_actor_placement()` / `micro_combat_board()`), `RngStreamSet`, `TacticalSnapshot.from_domain()`, `RunSnapshot`, and `SaveRepository`. Do NOT invent a new board fixture, a new snapshot DTO family, or a new test framework.
  - [x] Do NOT build a resume/load UI, a save-slot menu UI, mid-level autosave, settings persistence, profile/meta save files, or `MoveCommand`/`AttackCommand`/level/route gameplay systems in this story. (Resume FLOW and mid-level feasibility are Story 2.8; settings persistence is Story 2.9; route/level systems are Epics 3-4.)
- [x] 2.7.2 Compose the existing tactical snapshot into the between-level run save instead of inventing a parallel format. (AC: 1, 3)
  - [x] Reuse `TacticalSnapshot` (`godot/scripts/save/snapshots/tactical_snapshot.gd`, schema 1, `content_version "mvp-0"`) as the authoritative tactical/level payload. It already serializes `board`, `turn_state`, `pending_telegraphs`, `rng_streams`, and `event_log` and strictly validates board + RNG on parse.
  - [x] Carry the tactical snapshot inside `RunSnapshot.level_state` (`level_state = {"tactical_snapshot": tactical_snapshot.to_dictionary()}` under the stable key `RunSnapshot.TACTICAL_SNAPSHOT_KEY`). Do NOT duplicate the tactical board/turn/telegraph/event fields as new ad hoc top-level run-save keys. (Tested: `_between_level_composes_tactical_snapshot_into_level_state` asserts board/level_state are NOT flattened.)
  - [x] Added the between-level assembly helper `RunSnapshot.from_between_level(board_state, streams, options)` static composer in the save layer. Kept it data-only `RefCounted`/static; tactical truth, turn decisions, and command validation stay outside the save layer.
  - [x] When the run-save is loaded, the embedded tactical snapshot must still pass `TacticalSnapshot.parse()` strict validation. Added `RunSnapshot.try_tactical_snapshot()` and `_between_level_rejects_corrupt_embedded_tactical_snapshot` proving a corrupt embedded tactical snapshot is rejected with `invalid_tactical_snapshot` and exposes no partial state.
- [x] 2.7.3 Confirm and test the AC2 between-level field contract on `RunSnapshot`. (AC: 2)
  - [x] Mapped AC2 terms to the EXISTING fields (no rename, no removed-field reintroduction):
    - schema version -> `schema_version` (`SCHEMA_VERSION = 1`); content version -> `content_version` (`"mvp-0"`).
    - root seed -> `root_seed`; RNG stream states -> `rng_streams` (a `RngStreamSet.to_snapshot()` dictionary).
    - route / current-node state where available -> `route_state`, `current_route_node_id`, `revealed_route_node_ids` (default empty `{}`/`""`/`[]`).
    - player state + level state -> `level_state` (now composing the tactical snapshot per 2.7.2), `turn_state`, `board`.
    - inventory placeholder fields -> `inventory` (default empty `[]`); also `equipment`/`passives`/`curses`/`gold`/`oath_shards`/`corruption`/`affinities`/`meta_progression` stay at empty/nullable defaults.
    - manual-seed eligibility -> the EXISTING split fields `is_manual_seed: bool` and `meta_progression_eligible: bool`.
  - [x] `_between_level_field_contract_round_trips_with_no_surprise_fields` asserts a freshly built between-level `RunSnapshot` round-trips all AC2 fields through `to_dictionary()` -> `parse()`, that future fields stay empty/nullable, that no surprise top-level key appears, and that `manual_seed_eligible_for_progression` stays absent.
  - [x] Did NOT add new gameplay fields; all gameplay fields remain at their existing empty defaults.
- [x] 2.7.4 Add an explicit between-level autosave entry point that writes through `SaveRepository`. (AC: 1, 4)
  - [x] Reused `SaveRepository.write_run_snapshot()` (atomic temp -> backup -> replace + structured errors). No second write path added.
  - [x] Added the thin `SaveManager.autosave_between_level(snapshot: RunSnapshot, save_path := SaveRepository.DEFAULT_RUN_PATH) -> ActionResult` delegating to `repository.write_run_snapshot(snapshot, save_path)`. `SaveManager` stays thin (no schema policy, no tactical truth, no composition).
  - [x] The entry point returns the repository's structured `ActionResult` unchanged (verified by `_save_manager_autosave_between_level_delegates_to_repository`: error_code + metadata preserved, not collapsed to a bool).
  - [x] No command execution, enemy turn resolution, level-system advancement, or gameplay RNG draws on the autosave path (proven by no-mutation assertions in the integration test).
- [x] 2.7.5 Prove the AC4 save-failure contract: structured error, no domain corruption, original file preserved. (AC: 4)
  - [x] `_write_failure_returns_structured_error_without_mutation` forces a temp-open failure (write into a non-existent `user://` directory) and asserts `ActionResult.is_error()` with stable `save_open_failed` + `path`/`open_error` metadata. Temp test paths are cleaned up.
  - [x] Asserted the in-memory `RunSnapshot`, source `BoardState`, and source `RngStreamSet` are unchanged after a failed write (snapshot equality before/after).
  - [x] `_write_failure_preserves_existing_valid_save` writes a valid save, then blocks the temp path with a directory so the next write fails AFTER a canonical valid save exists; asserts the original save file is preserved and reads back the ORIGINAL data (not the failed write). Same proven end-to-end via `SaveManager` in the integration test.
  - [x] Kept all AC4 tests headless and domain/save-only; no scenes/UI/audio/animation nodes.
- [x] 2.7.6 Prove AC1/AC3 no-scene-truth and reuse guarantees with tests. (AC: 1, 3)
  - [x] `_written_save_contains_only_serializable_domain_data` reads the persisted JSON back and asserts only primitives/arrays/dictionaries, no `Object`/`Node`/`Callable`/`RID`, no `res://`/`.tscn`/`.scn`/`.anim`/audio strings, and nothing containing `presentation`. The tactical payload reuses `TacticalSnapshot`'s own serializable filtering.
  - [x] Asserted the between-level save reuses `TacticalSnapshot` (embedded payload parses via `TacticalSnapshot.parse()` after a real write -> read), demonstrating no parallel scene-owned save format (AC3).
  - [x] `_assemble_write_read_reparse_round_trip_preserves_fidelity` proves the full assemble -> write -> read -> reparse round-trip preserves root seed, RNG stream states (seed/state/draw_index per stream, restored losslessly and reproducing the exact next draw), the embedded tactical board, turn state, pending telegraphs, and manual-seed eligibility flags.
- [x] 2.7.7 Run required validation and update story records. (AC: 1-4)
  - [x] Ran `godot --version` through PowerShell -> `4.6.3.stable.official.7d41c59c4`.
  - [x] Ran the full headless suite through PowerShell: 38/38 test scripts PASS, "Headless tests passed.", process exit code 0, no SCRIPT ERROR noise.
  - [x] Ran `git diff --check` -> exit 0 (only informational LF->CRLF line-ending warnings; no whitespace errors).
  - [x] Updated this story's Dev Agent Record, Implementation Plan, Completion Notes, File List, and Change Log with the actual implementation work.
  - [x] Kept `sprint-status.yaml` synchronized with this story status.

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
Implementation: Claude Opus 4.8 (1M context).

### Implementation Plan

- Add red save tests first: (a) `RunSnapshot` round-trip composing a `TacticalSnapshot` dictionary into `level_state` + a corrupt-embedded-tactical reject; (b) the AC2 field contract round-trip; (c) `SaveRepository`/`SaveManager` AC4 forced-write-failure with no domain mutation and original-file preservation; (d) an integration assemble->write->read->reparse round-trip + no-scene-truth serialization assertion.
- Implement the between-level composition by embedding `TacticalSnapshot.to_dictionary()` under a stable `level_state` key (optionally via a thin `RunSnapshot.from_between_level(...)`/`BetweenLevelSave` composer) and add a thin `SaveManager.autosave_between_level(snapshot) -> ActionResult` delegating to the existing `SaveRepository.write_run_snapshot()`.
- Map manual-seed eligibility onto the existing `is_manual_seed` + `meta_progression_eligible` fields; do NOT re-add `manual_seed_eligible_for_progression`.
- Reuse `SaveRepository`'s atomic write + structured errors and `TacticalSnapshot`'s strict validation/serializable filter; do not fork a second writer or sanitizer. Keep save DTOs `RefCounted` and `SaveManager`/`GameSession` thin.

### Debug Log References

- 2026-06-14: Created Story 2.7 implementation guide from Epic 2 source requirements, the Epic 2 sprint plan (Sprint Slice 6), root project context, game architecture (Data Persistence, Error Levels, Data Access Pattern), the GDD save/resume requirements, Story 1.5 (the `TacticalSnapshot` reuse target and "between-level save belongs to Epic 2" deferral), the Epic 2 auto-gds retro notes, the deferred-work ledger, and direct inspection of the existing save layer on disk (`save_repository.gd`, `run_snapshot.gd`, `tactical_snapshot.gd`, `save_manager.gd`, `game_session.gd`, and the current save tests).
- 2026-06-14: Confirmed story-creation baseline: `epic-1: done`, Stories 2.1-2.6 `done`, Story 2.7 `backlog` before this file was created. Confirmed via code read that `SaveRepository`, `RunSnapshot` (with all AC2 fields + `is_manual_seed`/`meta_progression_eligible` split), `SaveManager`, and `TacticalSnapshot` already exist — so this story is composition + a between-level entry point + AC4/AC3 test hardening, not a greenfield save format.
- 2026-06-14 (implementation): Re-verified the boundary before editing (`epic-1: done`, 2.1-2.6 `done`, 2.7 `ready-for-dev`, clean tree) and `godot --version` = `4.6.3.stable.official.7d41c59c4`.
- 2026-06-14 (implementation): DISCOVERED a determinism-breaking save bug via a focused probe BEFORE writing the composition. `RandomNumberGenerator.state` is a full 64-bit signed integer (e.g. `-2661981755910080605`), but Godot `JSON.stringify`/`JSON.parse_string` round-trips numbers as IEEE-754 doubles (52-bit mantissa), truncating `state` (observed `-2661981755910080605` -> `-2661981755910080512`) AND returning all integers as `float`. Because `RngStreamSet.try_restore()` strictly required `is int` for `seed`/`state`/`draw_index`/`root_seed`, the JSON-round-tripped tactical RNG snapshot would have been REJECTED outright by `TacticalSnapshot.parse()` — so AC6 (assemble->write->read->reparse preserving RNG state) was impossible with the pre-existing format. Probed and confirmed: per-stream `seed` is always <= 2^31 (masked by `_derive_seed`'s `& 0x7fffffff`) so it survives JSON; only `state` and `root_seed` (player-supplied) are int64-at-risk.
- 2026-06-14 (implementation): Fix = encode the genuinely-64-bit fields (`RngStreamSet` `root_seed` + per-stream `state`, and `RunSnapshot.root_seed`) as lossless decimal STRINGS in their snapshot output; `try_restore`/`parse` accept int, integral-float (JSON), or valid int-string and reject `"bad"`/arrays/non-integral floats. This keeps `RngStreamSet` the sole owner of its serialization (no parallel save-layer sanitizer) and makes both native-dict and JSON round-trips restore the exact next draw. Verified the malformed-snapshot rejection contract still holds.
- 2026-06-14 (implementation): Followed red-green-refactor: added failing tests first (suite failed to compile on the missing `from_between_level`/`TACTICAL_SNAPSHOT_KEY`/`autosave_between_level` API), then implemented the production helpers to green. Final full headless run: 38/38 PASS, "Headless tests passed.", exit code 0, `git diff --check` exit 0.

### Completion Notes List

- Story context created and marked ready for development.
- Ultimate context engine analysis completed - comprehensive developer guide created.
- Implemented the between-level save foundation by COMPOSITION: added `RunSnapshot.from_between_level(board_state, streams, options)` (static, data-only) which builds the authoritative Epic 1 `TacticalSnapshot` via `TacticalSnapshot.from_domain()` and embeds it under `RunSnapshot.level_state["tactical_snapshot"]` (stable `RunSnapshot.TACTICAL_SNAPSHOT_KEY`). No tactical board/turn/telegraph/event fields are flattened onto the run save; no parallel scene-owned format was invented (AC1/AC3).
- Added `RunSnapshot.try_tactical_snapshot()` (+ `has_tactical_snapshot()`): the run-save `parse()` stays lenient for run-level forward-compat, but the embedded tactical payload is re-validated strictly via `TacticalSnapshot.parse()`, so corrupt/missing tactical data is rejected with a structured error (`invalid_tactical_snapshot` / `missing_tactical_snapshot`) and never activated as partial state (AC3).
- Added the thin `SaveManager.autosave_between_level(snapshot, save_path := SaveRepository.DEFAULT_RUN_PATH)` entry point delegating to the existing atomic `SaveRepository.write_run_snapshot()`; it returns the repository's structured `ActionResult` unchanged (AC1/AC4). `SaveManager`/`GameSession` stay thin; `SaveRepository`, `TacticalSnapshot`, `BoardState`, `GameSession` were reused unchanged.
- Mapped every AC2 field onto the EXISTING `RunSnapshot` fields including the `is_manual_seed` + `meta_progression_eligible` manual-seed split (manual seed -> `meta_progression_eligible = false`); the removed `manual_seed_eligible_for_progression` field stays absent (AC2).
- BREAKING (save serialization, pre-1.0, no released saves): made full-64-bit fields int64-lossless across JSON by encoding `RngStreamSet.to_snapshot()` `root_seed` + per-stream `state`, and `RunSnapshot.to_dictionary()` `root_seed`, as decimal STRINGS. `RngStreamSet.try_restore()` and `RunSnapshot.parse()` accept int, integral-float (JSON), or valid int-string. This was REQUIRED: `RandomNumberGenerator.state` is 64-bit and `JSON.stringify`/`parse_string` truncates it (doubles), which silently broke resume determinism and made AC6's reparse impossible (the old strict `is int` check rejected JSON-parsed floats outright). Per-stream `seed` stays an integer (always <= 2^31). Two existing assertions in `test_rng_stream_set.gd`/`test_run_snapshot.gd` were updated to the int64-safe encoding; all malformed-input rejection contracts are preserved.
- Save assembly is a pure read of domain state: it consumes no RNG draws and mutates nothing (no command execution, enemy-turn resolution, or level/route advancement). Proven by before/after no-mutation assertions on `RunSnapshot`/`BoardState`/`RngStreamSet` for both successful and failed writes.
- AC4 proven: a forced write failure returns a structured `ActionResult.is_error()` (`save_open_failed` + `path`/`open_error`), leaves domain state unchanged, and preserves a pre-existing valid save file intact (verified the original data — not the failed write — reads back). No-scene-truth serialization verified by reading the persisted JSON and asserting primitives/arrays/dictionaries only with no `Object`/`Node`/`Callable`/`RID`/`res://`/scene/audio/animation/presentation references.
- Validation: full headless suite 38/38 PASS, exit code 0; `git diff --check` exit 0. All existing Epic 1 + Story 2.1-2.6 tests remain green (including the "ambiguous manual-seed field absent" assertion and the existing repository round-trip + schema-reject tests).

### File List

- `godot/scripts/save/snapshots/run_snapshot.gd` (modified) — added `TACTICAL_SNAPSHOT_KEY`, `from_between_level()`, `try_tactical_snapshot()`, `has_tactical_snapshot()`, `_domain_event_array()`, `_int64_or_zero()`; encoded `root_seed` as an int64-safe decimal string in `to_dictionary()`/`parse()`; added `BoardState`/`DomainEvent`/`RngStreamSet`/`TacticalSnapshot` preloads.
- `godot/scripts/core/state/rng_stream_set.gd` (modified) — `to_snapshot()` now encodes `root_seed` + per-stream `state` as int64-safe decimal strings; `try_restore()` accepts int/integral-float/int-string for `root_seed`/`state` (and int/integral-float for `seed`/`draw_index`) via new `_int64_from_value()`/`_is_integral_value()` helpers; preserves no-mutation-on-malformed and existing error codes.
- `godot/scripts/autoloads/save_manager.gd` (modified) — added the thin `autosave_between_level(snapshot, save_path)` between-level entry point delegating to `SaveRepository.write_run_snapshot()`.
- `godot/tests/unit/save/test_run_snapshot.gd` (modified) — added between-level composition, AC2 field-contract round-trip, corrupt/missing embedded-tactical reject, manual-seed-no-progression, and full-int64 root-seed round-trip tests; updated the nested RNG `root_seed` assertion to the int64-safe encoding.
- `godot/tests/unit/save/test_save_repository.gd` (modified) — added AC4 forced-write-failure + no-mutation, original-file-preserved, and `SaveManager.autosave_between_level` delegation tests; hardened cleanup to remove a leftover tmp directory.
- `godot/tests/unit/core/test_rng_stream_set.gd` (modified) — added a JSON-round-trip-without-precision-loss regression test; updated the snapshot-format assertions to the int64-safe `state`/`root_seed` string encoding.
- `godot/tests/integration/save/test_between_level_save.gd` (new) — end-to-end assemble -> compose -> write -> read -> reparse round-trip preserving seed/RNG/board/turn fidelity, no-scene-truth serialization inspection, and the AC4 failure-preserves-domain-and-file contract via `SaveManager`.
- `_bmad-output/implementation-artifacts/sprint-status.yaml` (modified) — Story 2.7 status in-progress -> review; `last_updated` refreshed.
- `_bmad-output/implementation-artifacts/2-7-between-level-save-snapshot-foundation.md` (modified) — task checkboxes, Dev Agent Record, File List, Change Log, Status.

### Change Log

| Date | Change |
|---|---|
| 2026-06-14 | Created Story 2.7 implementation guide (between-level save snapshot foundation) and marked it ready for development. |
| 2026-06-14 | Implemented between-level save foundation: `RunSnapshot.from_between_level()` composing the Epic 1 `TacticalSnapshot` into `level_state["tactical_snapshot"]`, `RunSnapshot.try_tactical_snapshot()` strict extraction, and the thin `SaveManager.autosave_between_level()` entry point delegating to the existing atomic `SaveRepository`. |
| 2026-06-14 | Made RNG/run snapshots int64-lossless across JSON (`root_seed` + per-stream `state` encoded as decimal strings; tolerant `try_restore`/`parse`) to fix a determinism-breaking 64-bit precision loss in the save transport that otherwise blocked AC6 reparse. |
| 2026-06-14 | Added AC1-AC4 + AC6 test coverage (composition/reuse, AC2 field contract, corrupt-embedded reject, structured write-failure + no-mutation + original-file-preserved, no-scene-truth serialization, full round-trip) across `test_run_snapshot.gd`, `test_save_repository.gd`, `test_rng_stream_set.gd`, and the new `tests/integration/save/test_between_level_save.gd`. Full headless suite 38/38 PASS, exit 0. Status -> review. |

## Review Findings

**Round 1 of 3**

Code review of the branch diff (`story/2-7-between-level-save-snapshot-foundation` vs `main`) against this story's 4 ACs, on 2026-06-14. Reviewer: Claude Opus 4.8 (1M context), adversarial (Blind Hunter + Edge Case Hunter + Acceptance Auditor).

Verdict: **Approve**. All four ACs are implemented and covered by tests. Full headless suite 38/38 PASS (exit 0); `git diff --check` exit 0. The int64-lossless JSON encoding fix is a genuine, well-reasoned catch (Godot `RandomNumberGenerator.state` is full 64-bit; `JSON.stringify`/`parse_string` round-trips numbers as doubles and would have silently truncated RNG state / returned ints as floats, breaking resume determinism and failing the reparse round-trip). Composition into `RunSnapshot.level_state[TACTICAL_SNAPSHOT_KEY]` reuses the strict Epic 1 `TacticalSnapshot` (no parallel scene-owned format, AC3); the embedded payload is re-validated strictly on extraction; the autosave entry point is thin and returns the repository `ActionResult` unchanged; no-mutation and original-file-preservation are both proven. No Critical/High/Med findings. The items below are non-blocking hardening defers.

- [Review][Defer] (Low) `RngStreamSet.try_restore()` still tolerantly accepts a full-64-bit field (`state`, and `root_seed`) encoded as a raw JSON **float** via `_int64_from_value()`'s `TYPE_FLOAT` branch (`is_equal_approx(v, round(v))`). The production `to_snapshot()` now always emits these as decimal strings, so the live path is safe; but a hand-edited, machine-generated, or future-format save that stored `state` as a number beyond 2^53 would pass the integral-float check and be silently truncated by `int(numeric_value)` — re-introducing exactly the precision loss the fix prevents, this time *accepted* rather than rejected. The float branch is genuinely needed for the small bounded fields (`seed` <= 2^31, `draw_index`), but the unbounded fields (`state`, `root_seed`) arguably should accept only `int` or `String` and reject `float`. Not blocking: no production writer emits numeric `state`, and all malformed-input rejection tests stay green. Consider tightening `state`/`root_seed` to reject `TYPE_FLOAT` (or adding a guard that a finite double whose magnitude exceeds 2^53 is rejected) and add a regression test feeding a too-large numeric `state`.

- [Review][Defer] (Low) The Composition Contract documents that run-level `RunSnapshot.rng_streams` and the embedded tactical `rng_streams` "may both be present; if so, keep them consistent... Do not silently let them disagree without a test." `from_between_level()` does make them equal (both are pure `streams.to_snapshot()` reads at the boundary), but no test asserts `snapshot.rng_streams == <embedded tactical>.rng_streams`. A future refactor that snapshots the two at different points (e.g. after a draw) could let them diverge undetected. Add a one-line equality assertion in `test_run_snapshot.gd::_between_level_composes_tactical_snapshot_into_level_state` (or the integration round-trip) comparing the run-level snapshot to the embedded tactical snapshot's `rng_streams`. Not blocking: behavior is correct today by construction.

- [Review][Defer] (Low) The integration round-trip (`_assemble_write_read_reparse_round_trip_preserves_fidelity`) restores the embedded tactical `rng_streams` and asserts only that the restore *succeeds*; it does not assert the restored tactical streams reproduce the same next draw (the run-level streams get that stronger check, the embedded tactical ones do not). Tighten the embedded-tactical assertion to match the run-level "reproduce exact next draw" check for symmetric determinism coverage. Not blocking: the run-level check plus the shared encoding already exercises the lossless transport.

- [Review][Decision] (informational, no human action required) The Dev Agent Record and Change Log label the round-trip/RNG-fidelity tests "AC6", but this story has only four acceptance criteria (epics.md Story 2.7). "AC6" is an informal internal label for the assemble->write->read->reparse fidelity coverage, not a missing acceptance criterion. Cosmetic; consider renaming to "round-trip fidelity coverage" to avoid confusion in the epic retro. No code impact.
