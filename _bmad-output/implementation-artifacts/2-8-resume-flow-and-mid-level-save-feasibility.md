---
created: 2026-06-14
source_story_key: 2-8-resume-flow-and-mid-level-save-feasibility
baseline_commit: 976760c1e960dc8c57b679106b5ceb882585be50
---

# Story 2.8: Resume Flow and Mid-Level Save Feasibility

Status: ready-for-dev

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a player,
I want saved progress to resume reliably,
so that quitting between levels or during a feasibility-tested mid-level point is safe.

## Acceptance Criteria

1. Given a valid between-level save exists, when resume is selected, then domain state is restored from the snapshot, and presentation rebuilds from restored state rather than saved scene nodes.
2. Given an incompatible or corrupted save is loaded, when the save repository validates it, then the load fails with a structured error and recovery path, and no partial corrupt state becomes active.
3. Given mid-level save/resume is desirable but optional for MVP, when feasibility is evaluated against current domain snapshots, then the story records whether mid-level save is implemented, deferred, or limited, and any implemented mid-level save path has at least one restore test for fog, entities, pending turn state, and RNG stream state.
4. Given resume tests compare interrupted and uninterrupted play, when a run is saved, restored, and then given the same command sequence, then final domain snapshots, event logs, and gameplay RNG stream states match the uninterrupted path, and mismatches identify the first divergent event or stream.

## Tasks / Subtasks

- [ ] 2.8.1 Confirm the Epic 2 save/resume boundary and write failing tests FIRST. (AC: 1-4)
  - [ ] Verify in `_bmad-output/implementation-artifacts/sprint-status.yaml` that `epic-1: done`, Stories 2.1-2.7 are `done`, and this story (`2-8-resume-flow-and-mid-level-save-feasibility`) is `ready-for-dev` (it is `backlog` until this file is created, then create-story flips it). If any earlier Epic 1/2 status regressed, STOP and restore the boundary before implementing resume.
  - [ ] Confirm the working tree is clean or that dirty files are intentional user work; preserve unrelated changes. The untracked orchestrator-owned `_bmad-output/auto-gds/` directory is expected and is not your change.
  - [ ] Add focused FAILING tests before any production edit. Recommended: a new `godot/scripts/save/run_resume_service.gd` unit test `godot/tests/unit/save/test_run_resume_service.gd`, and extend the existing `godot/tests/integration/save/test_between_level_save.gd` (or add `godot/tests/integration/save/test_resume_flow.gd`) for the interrupted-vs-uninterrupted divergence comparison (AC4). The headless runner auto-discovers `test_*.gd` under `godot/tests/unit` and `godot/tests/integration`; no registry edit is needed.
  - [ ] Reuse the existing restore primitives — `SaveRepository.read_run_snapshot()`, `RunSnapshot.parse()`, `RunSnapshot.try_tactical_snapshot()`, `BoardState.try_from_snapshot()`, `RngStreamSet.try_restore()`, `GameSession.restore_rng_snapshot()`, and `BoardFixtureFactory`. Do NOT invent a new save format, a new snapshot DTO family, a parallel reader, or a new test framework.
  - [ ] Do NOT build a save-slot/load-menu UI, a settings subsystem, profile/meta save files, `MoveCommand`/`AttackCommand` changes, level/route state machines, or generation systems in this story. (Save-slot UI and route/level systems are Epics 3-4+; settings persistence is Story 2.9; the between-level WRITE path is already Story 2.7.)
- [ ] 2.8.2 Implement a domain-side resume service that restores between-level state from a snapshot. (AC: 1, 2)
  - [ ] Add `godot/scripts/save/run_resume_service.gd` (`RunResumeService extends RefCounted`, data/save-layer only — NOT a `Node`, NOT an autoload, NO scene nodes). It reads a save via `SaveRepository.read_run_snapshot(save_path)`, and on success returns a structured `ActionResult` carrying the restored domain pieces in `metadata` (e.g. `{"run_snapshot": RunSnapshot, "board": BoardState, "rng_streams": RngStreamSet, "tactical_snapshot": TacticalSnapshot}`). It must NOT mutate tactical truth, execute commands, advance turns, or draw RNG.
  - [ ] Restore order inside the service: (1) `read_run_snapshot` → lenient `RunSnapshot.parse()` (already rejects `unsupported_save_schema`); (2) strict `run_snapshot.try_tactical_snapshot()` to get the validated embedded `TacticalSnapshot` (rejects corrupt tactical payload with `invalid_tactical_snapshot` / `missing_tactical_snapshot`); (3) `BoardState.try_from_snapshot(tactical.board)` for the board; (4) `RngStreamSet.new(0).try_restore(run_snapshot.rng_streams)` for the run-level streams. Propagate the FIRST error as a structured `ActionResult.error(...)` and expose NO partial state (do not return `board`/`rng_streams` keys on failure). This is AC2's "no partial corrupt state becomes active" guarantee.
  - [ ] RNG authority decision (REQUIRED by Story 2.7 retro note): the run-level `RunSnapshot.rng_streams` is the authoritative between-level RNG state on resume; the embedded tactical `rng_streams` reflects in-level stream state at level exit. At a between-level boundary they are equal by construction (`from_between_level` writes both from one `streams.to_snapshot()` read). The resume service must restore the RUN-LEVEL streams as the live gameplay streams, and document this in a code comment. Add a test asserting the restored run-level streams equal the restored embedded-tactical streams for a between-level save (closes a Story 2.7 deferred item — see Deferred Work below).
  - [ ] If you wire resume through `GameSession` for session RNG continuity, prefer reusing `GameSession.restore_rng_snapshot(run_snapshot.rng_streams)`. NOTE a latent fragility: `GameSession.restore_rng_snapshot()` does `int(snapshot.get("root_seed", _root_seed))`, but `RngStreamSet.to_snapshot()` now encodes `root_seed` as a decimal STRING (int64-safe). `int("123")` coerces correctly in GDScript today, so this is not broken — but if you touch that line, keep it tolerant of the string encoding (use `RngStreamSet`'s tolerant int64 decode semantics, not a raw cast that could regress on a >2^53 seed). Do not silently break the int64-string contract Story 2.7 established. Keep `GameSession` thin (seed/RNG session wiring only; no tactical state, no schema policy).
- [ ] 2.8.3 Prove AC1 — a valid between-level save restores domain state and presentation rebuilds FROM restored state (not from saved scene nodes). (AC: 1)
  - [ ] Test: assemble real domain state (`BoardFixtureFactory.micro_combat_board()` + `RngStreamSet` with a few draws + turn_state + pending_telegraphs) → `RunSnapshot.from_between_level(...)` → `SaveRepository.write_run_snapshot(..., test_path)` → `RunResumeService.resume(test_path)`. Assert the restored `BoardState` matches the source board snapshot (`restored.to_snapshot() == source.to_snapshot()`), the restored `TacticalSnapshot` preserves turn_state/pending_telegraphs, and `root_seed`/route node round-trip.
  - [ ] AC1 "presentation rebuilds from restored state rather than saved scene nodes": the resume service returns ONLY domain objects (`BoardState`/`RngStreamSet`/`TacticalSnapshot`/`RunSnapshot`) — there is no scene node in the save or the resume output. Assert (or document via the no-scene-truth serialization check already in `test_between_level_save.gd`) that the save and resume payload contain no `Object`/`Node`/`res://`/`.tscn`/audio/presentation references. UI/scene wiring is out of scope; resume yields the domain state a presenter would later observe.
  - [ ] Reuse the JSON write→read path (do NOT resume from a native in-memory dict). Per the Story 2.7 retro rule, resume MUST be exercised through a real `SaveRepository` write→read so the int64/JSON transport is covered.
- [ ] 2.8.4 Prove AC2 — incompatible/corrupted saves fail with a structured error + recovery path, no partial state. (AC: 2)
  - [ ] Test cases (each through `RunResumeService` / `SaveRepository`): (a) missing file → `save_not_found`; (b) non-JSON garbage bytes → `save_parse_failed`; (c) unsupported `schema_version` → `unsupported_save_schema`; (d) valid run-save shell but corrupt embedded tactical payload (e.g. occupant referencing no entity, like `test_run_snapshot.gd::_between_level_rejects_corrupt_embedded_tactical_snapshot`) → `invalid_tactical_snapshot`; (e) valid run-save but malformed `rng_streams` → `invalid_rng_snapshot`.
  - [ ] For every failure assert: `ActionResult.is_error()` with the stable lower-snake `error_code`, diagnostic `metadata` present, and NO partial domain state exposed (`metadata` must not carry a usable `board`/`rng_streams`/`tactical_snapshot` on failure). This is the "recovery path" contract at the domain layer — the structured error is what a recovery UI (later story) consumes. Do not crash, do not `push_error`-and-continue into a half-restored state.
  - [ ] Keep the original save file intact on a failed READ (reads never write). Always clean up `user://` test files (`*.json`, `*.json.tmp`, `*.json.bak`) and any directory artifacts.
- [ ] 2.8.5 Prove AC4 — interrupted vs uninterrupted determinism, reporting the first divergence. (AC: 4)
  - [ ] Build a deterministic command-sequence harness over `BoardState` + `RngStreamSet` (reuse existing commands/events — do NOT invent new gameplay). Path A (uninterrupted): start from initial domain state, apply a fixed ordered sequence of committed actions (or RNG draws + applied `DomainEvent`s) to completion. Path B (interrupted): from the same initial state, take a between-level save partway, `RunResumeService.resume(...)` through a real JSON write→read, then apply the REMAINING identical sequence.
  - [ ] Assert final equality of: (1) board snapshot (`to_snapshot()`), (2) the ordered event log / applied events, (3) gameplay RNG stream states (`to_snapshot()` AND the next-draw reproduction check). On mismatch, the test/helper output must identify the FIRST divergent event index or the first RNG stream whose state differs (do not just assert a bare boolean — the failure message must name the first divergence, per AC4 "mismatches identify the first divergent event or stream").
  - [ ] Tighten the embedded-tactical RNG check to the same "reproduce exact next draw" assertion used for run-level streams (closes a Story 2.7 deferred item — see Deferred Work). This makes the interrupted-path determinism coverage symmetric for run-level and embedded-tactical streams.
- [ ] 2.8.6 Evaluate and RECORD mid-level save/resume feasibility (implemented / deferred / limited). (AC: 3)
  - [ ] Make the feasibility CALL explicitly in this story's Dev Agent Record and Completion Notes: state whether mid-level save is implemented, deferred, or limited for MVP, with a one-paragraph rationale grounded in what the current `TacticalSnapshot` already captures (board + visibility/explored fog memory in `BoardCell` + entities/HP + `turn_state` + `pending_telegraphs` + `rng_streams` + `event_log`). The recommended call is **implemented as feasible OR limited**: the existing `TacticalSnapshot` already serializes everything a mid-level snapshot needs, so a mid-level save is essentially a between-level save taken at an arbitrary turn boundary. The blocker is not the snapshot — it is the absence of a level/turn state machine and a save trigger point (those arrive in Epics 3-4). Pick the call the implementation actually supports and justify it; do not leave it unrecorded.
  - [ ] IF you implement (or partially implement) a mid-level save path, you MUST add at least one restore test covering fog (visibility/explored cell flags), entities (positions/HP/occupancy), pending turn state (`turn_state` mid-turn), and RNG stream state — per AC3 and the Sprint Slice 6 exit gate. The cleanest implementation: assert that `RunSnapshot.from_between_level(...)` / the resume service already round-trips a mid-turn `turn_state` and a non-empty `pending_telegraphs` with mid-combat HP and partial fog, restoring all four faithfully (this reuses the between-level path at a mid-level boundary — no new format). If you record mid-level as DEFERRED, add the deferral to `_bmad-output/implementation-artifacts/deferred-work.md` with this story key + date and the precise reason (e.g. "needs the level/turn state machine from Epic 3-4 to define a mid-level save trigger"); no mid-level restore test is then required, but the AC3 RECORDING is still mandatory.
  - [ ] Do NOT add a mid-level autosave TRIGGER (a hook that fires mid-combat) in this story unless feasibility lands on "implemented" — and even then, keep it a domain/test-level demonstration, not a wired-in scene/turn hook. The trigger-point wiring belongs with the level/turn state machine in later epics.
- [ ] 2.8.7 Run required validation and update story records. (AC: 1-4)
  - [ ] Run through PowerShell (the bare `godot` resolves only as `C:\Users\Rasmus\bin\godot.cmd` via PowerShell; the Bash tool PATH cannot find it): `godot --version`, then `godot --headless --path C:\Sealsworn\godot --scene res://tests/headless/test_runner.tscn --quit-after 10`, then `git diff --check`.
  - [ ] Expect: Godot `4.6.3.stable.official...`; the full headless runner exits code `0`; all prior Epic 1 + Story 2.1-2.7 tests stay green (including `test_run_snapshot.gd`'s "ambiguous `manual_seed_eligible_for_progression` absent" assertion, `test_save_repository.gd`'s round-trip + schema-reject tests, and `test_rng_stream_set.gd`'s int64 JSON round-trip test); `git diff --check` reports no whitespace errors.
  - [ ] Update this story's Dev Agent Record, Completion Notes, File List, Change Log, and Status. Record the AC3 mid-level feasibility CALL explicitly. Keep `sprint-status.yaml` synchronized with this story's status.

## Dev Notes

### Pre-Implementation Gate

This is the eighth Epic 2 implementation story (Sprint Slice 6: Save/Resume Foundation, **second of two** — Story 2.7 built the between-level WRITE path; this story builds the RESUME/READ path and makes the mid-level feasibility call). Story-creation analysis on 2026-06-14 found:

- `epic-1: done`; Stories 2.1-2.7 all `done`; Story 2.8 `backlog` before this file was created; Story 2.9 `backlog`.
- The save WRITE layer and ALL restore primitives already exist (see "Current Repository Baseline"). This story is **a domain-side resume service that composes existing restore primitives + the interrupted-vs-uninterrupted determinism harness + the mid-level feasibility decision** — NOT a new save format and NOT a UI.
- There is currently **no resume/restore-run flow code anywhere** (a project-wide grep for `resume`/`restore_run`/`load_run` finds only `RngStreamSet`). The resume FLOW is the greenfield deliverable; the restore building blocks are all built and tested.

Before implementing, re-confirm the local tree is clean or that dirty files are intentional user work. If any Story 2.1-2.7 status regressed, stop and restore that boundary first.

### Scope Boundary

This story delivers the **between-level resume flow** (restore domain state from a valid save through the existing repository + snapshot DTOs, rebuilding domain — not scene — state), the **structured-failure / no-partial-state recovery contract** on load, the **interrupted-vs-uninterrupted determinism comparison** that names the first divergence, and the **explicit mid-level save/resume feasibility decision** (implemented / deferred / limited) with restore tests if implemented.

In scope:

- A domain/save-layer resume service (`RunResumeService`, `RefCounted`) that reads a save and returns restored `BoardState` / `RngStreamSet` / `TacticalSnapshot` / `RunSnapshot` via a structured `ActionResult`, propagating the first validation error and exposing no partial state.
- AC1 restore round-trip tests (through a real JSON write→read), AC2 corrupt/incompatible-save rejection tests (missing, unparseable, bad schema, corrupt embedded tactical, malformed RNG), AC4 interrupted-vs-uninterrupted determinism with first-divergence reporting.
- The RNG-authority decision on resume (run-level `rng_streams` wins; equals embedded tactical at the boundary) — documented and tested.
- The mid-level feasibility CALL recorded in the story, with restore tests for fog/entities/pending-turn/RNG if implemented or a recorded deferral if not.

Out of scope (owned elsewhere — do not build here):

- **Save-slot / load-menu / recovery UI scenes.** AC1's "presentation rebuilds from restored state" and AC2's "recovery path" are satisfied at the DOMAIN layer: resume yields domain state for a presenter to observe later, and a load failure yields a structured `ActionResult` a recovery UI later consumes. The actual HUD/menu scenes are not built in this domain/save story (no standalone UX file exists; Epic 2 keeps tactical layout in testable semantic profiles/view models per Story 2.5's deferral).
- **The between-level WRITE path** — already delivered by Story 2.7 (`RunSnapshot.from_between_level`, `SaveManager.autosave_between_level`, `SaveRepository.write_run_snapshot`). Reuse; do not re-implement or fork.
- **Settings persistence / profile/meta save files** — Story 2.9 owns settings; profile/meta live in separate files (architecture Data Persistence). This story resumes only the current-run autosave.
- **Real gameplay content** — actual inventory items, route graphs, level recipes, affinity rules, classes, loot, meta-progression arrive in Epics 3-9. Run-save gameplay fields stay at their existing empty/nullable defaults; the determinism harness uses existing tactical commands/events only.
- **Level/route/turn state machines and mid-level save TRIGGERS** — the snapshot can already represent a mid-level state; the missing piece is the state machine + trigger point that arrives in Epics 3-4. Do not build it here; record the feasibility call instead.
- **Save migrations beyond schema 1.** If a migration question appears, record it in `_bmad-output/implementation-artifacts/deferred-work.md` unless it blocks this story's ACs.
- Cloud saves, accounts, multiplayer, leaderboards, telemetry, Godot .NET/C#, React/Vite production dependencies, or new test frameworks.

### Current Repository Baseline (READ THIS FIRST — the WRITE path and all restore primitives already exist)

The save layer is fully built for writing and for low-level restore. The primary mistake to avoid is **reinventing a reader/format that already exists, or building a parallel restore path that bypasses the strict validators**. Compose the existing primitives.

- `godot/scripts/save/save_repository.gd` — `SaveRepository extends RefCounted`. `read_run_snapshot(save_path := "user://run_autosave.json") -> ActionResult` returns `save_not_found` / `save_open_failed` / `save_parse_failed`, or delegates to `RunSnapshot.parse(parsed_dict)`. THIS is the resume entry read. `write_run_snapshot(...)` is the Story 2.7 atomic write (reuse for test setup; do not change).
- `godot/scripts/save/snapshots/run_snapshot.gd` — `RunSnapshot extends RefCounted`, `SCHEMA_VERSION = 1`, `content_version = "mvp-0"`. `parse(data)` is LENIENT for run-level forward-compat (coerces fields, rejects only `unsupported_save_schema`). `try_tactical_snapshot() -> ActionResult` STRICTLY re-validates the embedded tactical payload via `TacticalSnapshot.parse()` (returns `invalid_tactical_snapshot` / `missing_tactical_snapshot`, exposes no partial state). `from_between_level(board_state, streams, options)` is the Story 2.7 composer (reuse for test setup and the mid-level demonstration). `root_seed` is encoded as a decimal STRING in `to_dictionary()` and decoded tolerantly (int / integral-float / int-string) in `parse()` via `_int64_or_zero`.
- `godot/scripts/save/snapshots/tactical_snapshot.gd` — `TacticalSnapshot extends RefCounted`, schema 1, `CONTENT_VERSION "mvp-0"`. Strict `parse(data)` validates board occupant consistency (`BoardState.try_from_snapshot`), RNG validity (`RngStreamSet.try_restore`), rejects non-finite floats / forbidden reference strings (`res://`, `.tscn`/`.scn`/`.anim`/audio, anything containing `presentation`), and canonicalizes `event_log` via `DomainEvent`. The embedded payload carries `board`, `turn_state`, `pending_telegraphs`, `rng_streams`, `event_log`. Resume reuses this strict parse; do not weaken or fork it.
- `godot/scripts/tactical/board/board_state.gd` — `BoardState`. `try_from_snapshot(dict) -> ActionResult` strictly rebuilds the board (dimensions, terrain, cells incl. `visible`/`explored` fog flags, entities, occupancy consistency, `next_sequence_id`); returns `{board: BoardState}` on success. `to_snapshot()` is the canonical comparison surface for determinism tests. `apply_event()` / `apply_events()` apply validated `DomainEvent`s — use these (not direct mutation) to drive the AC4 command-sequence harness.
- `godot/scripts/core/state/rng_stream_set.gd` — named RNG streams. `to_snapshot()` encodes `root_seed` + per-stream `state` as int64-safe decimal STRINGS (per-stream `seed` stays integer, always ≤ 2^31). `try_restore(dict) -> ActionResult` accepts int / integral-float (JSON) / decimal-string for `root_seed`/`state` and int/integral-float for `seed`/`draw_index`; returns `invalid_rng_snapshot` on malformed input and does NOT mutate on failure. Snapshotting consumes NO draws. This is the resume RNG restore.
- `godot/scripts/autoloads/save_manager.gd` — thin `Node` autoload delegating write/read to a `SaveRepository`. It has `write_run_snapshot()`, `read_run_snapshot()`, `autosave_between_level()`. You MAY add a thin `resume_run(save_path)` delegation here that calls `RunResumeService`, but keep `SaveManager` thin (no restore logic of its own; the service owns composition). Adding the service-only and testing it directly is also acceptable.
- `godot/scripts/autoloads/game_session.gd` — thin seed/RNG session wiring: `configure_seed()`, `get_root_seed()`, `rng_snapshot()`, `restore_rng_snapshot(snapshot)`. `restore_rng_snapshot` already delegates to `RngStreamSet.try_restore` then sets `_root_seed = int(snapshot.get("root_seed", _root_seed))`. CAUTION: `root_seed` is now a decimal string in the snapshot; `int("123")` coerces fine today but is fragile for >2^53 (see Task 2.8.2). Keep `GameSession` thin; it owns session RNG continuity only, not tactical state or schema policy.
- `godot/scripts/core/results/action_result.gd` — `ActionResult` (`succeeded`, `is_error()`, `error_code: StringName`, `metadata: Dictionary` deep-copied, events). `ok(events, metadata)` / `error(code, metadata)`. Error codes must be lower-snake (no spaces/dots/colons/dashes). Reuse for every resume result.
- `godot/tests/integration/save/test_between_level_save.gd` — the Story 2.7 end-to-end assemble→write→read→reparse test + no-scene-truth serialization + AC4-write-failure. Extend it (or add a sibling) for the resume round-trip and the interrupted-vs-uninterrupted comparison. The `_is_json_compatible` / `_contains_forbidden_reference` helpers here are reusable for the AC1 no-scene-truth assertion.
- `godot/tests/unit/save/test_run_snapshot.gd` — has `_between_level_rejects_corrupt_embedded_tactical_snapshot` (corrupt occupant → `invalid_tactical_snapshot`; missing → `missing_tactical_snapshot`). Mirror this corruption technique in the resume AC2 tests.
- `godot/tests/fixtures/tactical/board_fixture_factory.gd` — `deterministic_actor_placement()`, `micro_combat_board()`, etc. Reuse to build real source state. Do NOT invent a new board fixture.
- `godot/tests/unit/test_case.gd` — the custom headless harness base. Tests `extends "res://tests/unit/test_case.gd"`, expose `run() -> Dictionary`, call `assert_true/false/equal`, and return `result()`. Do NOT add GUT/GdUnit.

### Existing Files To Update Or Preserve

| Path | Current State | This Story Changes | Preserve |
|---|---|---|---|
| `godot/scripts/save/save_repository.gd` | Atomic write + structured read (`save_not_found`/`save_open_failed`/`save_parse_failed` → `RunSnapshot.parse`). | NO change expected — reuse `read_run_snapshot()` as the resume entry read. | The structured read errors, atomic write, backup rollback. |
| `godot/scripts/save/snapshots/run_snapshot.gd` | Lenient `parse()`, strict `try_tactical_snapshot()`, `from_between_level()`, int64-string `root_seed`. | NO change expected — reuse `parse()` + `try_tactical_snapshot()` for restore. | Lenient run-level parse, strict tactical extraction, `is_manual_seed`+`meta_progression_eligible` split, int64-string encoding, `unsupported_save_schema` rejection. Do NOT re-add `manual_seed_eligible_for_progression`. |
| `godot/scripts/save/snapshots/tactical_snapshot.gd` | Strict Epic 1 tactical DTO with serializable filtering. | Read-only reuse via `RunSnapshot.try_tactical_snapshot()`. No change. | Strict parse, serializable filter, forbidden-reference rejection. |
| `godot/scripts/core/state/rng_stream_set.gd` | int64-safe snapshot/restore, tolerant decode, no-mutation-on-failure. | NO change expected — reuse `try_restore()`. | int64-string encoding, tolerant decode, `invalid_rng_snapshot` codes, no-mutation-on-failure. |
| `godot/scripts/tactical/board/board_state.gd` | Strict `try_from_snapshot()`, `to_snapshot()`, `apply_event(s)`. | Read-only reuse for restore + the determinism harness. No change. | Strict restore, occupant-consistency validation, deterministic sorted cells/entities. |
| `godot/scripts/autoloads/game_session.gd` | Thin seed/RNG wiring incl. `restore_rng_snapshot`. | Optional: if used for resume RNG continuity, keep the `root_seed` decode tolerant of the int64-string encoding (don't regress >2^53). Otherwise NO change. | Thin posture; no tactical state, no schema policy. |
| `godot/scripts/autoloads/save_manager.gd` | Thin write/read/autosave delegations. | Optional thin `resume_run(save_path)` delegation to `RunResumeService`. Keep it thin (no restore logic here). | Thin-autoload posture; structured `ActionResult` returned unchanged. |
| `godot/tests/integration/save/test_between_level_save.gd` | Story 2.7 assemble→write→read→reparse + no-scene-truth + AC4 write-failure. | Extend (or add sibling) for the resume round-trip + interrupted-vs-uninterrupted comparison. | Existing assertions stay green; reuse the JSON-compat / forbidden-ref helpers. |
| `godot/tests/unit/save/test_run_snapshot.gd` | Composition, AC2 field contract, corrupt/missing embedded reject, manual-seed, int64 round-trip. | Optionally add the run-level-equals-embedded-tactical `rng_streams` equality assertion (closes a 2.7 defer) here OR in the resume test. | All existing assertions stay green. |

### Recommended New Files

Use these names unless implementation discovers a clearer local pattern:

- `godot/scripts/save/run_resume_service.gd` — `RunResumeService extends RefCounted`. Composes `SaveRepository.read_run_snapshot` → `RunSnapshot.parse` → `try_tactical_snapshot` → `BoardState.try_from_snapshot` → `RngStreamSet.try_restore`, returning a structured `ActionResult` with restored domain pieces on success and the first error (no partial state) on failure. Data/save-layer only, `RefCounted`, no scene nodes.
- `godot/tests/unit/save/test_run_resume_service.gd` — AC1 restore round-trip + AC2 corrupt/incompatible-save rejection (the five failure cases) + the RNG-authority equality assertion + (if implemented) the mid-level fog/entities/pending-turn/RNG restore test.
- `godot/tests/integration/save/test_resume_flow.gd` (OR extend `test_between_level_save.gd`) — AC4 interrupted-vs-uninterrupted command-sequence comparison with first-divergence reporting, through a real JSON write→read.

Avoid: a new save format, a new snapshot DTO family, a `LevelSnapshot` class, a settings subsystem, a resume/load UI scene, a new autoload, a plugin, a parallel non-strict reader, or any new test framework.

### Resume / Restore Contract (AC1 + AC2 — compose strict primitives, expose no partial state)

The single most important constraint: **resume must route the embedded tactical payload through the STRICT `TacticalSnapshot.parse()` (via `RunSnapshot.try_tactical_snapshot()`), not the lenient run-level `parse()`.** The run-level `parse()` is intentionally lenient for run-field forward-compat; if you trusted it alone, a corrupt board could be "restored" into a broken shape — exactly what AC2 forbids.

Recommended resume composition:

```gdscript
# RunResumeService.resume(save_path) -> ActionResult
var read_result: ActionResult = SaveRepository.new().read_run_snapshot(save_path)
if read_result.is_error():
    return read_result                      # save_not_found / save_open_failed / save_parse_failed / unsupported_save_schema
var run_snapshot: RunSnapshot = read_result.metadata.get("snapshot")

var tactical_result: ActionResult = run_snapshot.try_tactical_snapshot()
if tactical_result.is_error():
    return tactical_result                  # invalid_tactical_snapshot / missing_tactical_snapshot — NO partial state
var tactical: TacticalSnapshot = tactical_result.metadata.get("snapshot")

var board_result: ActionResult = BoardState.try_from_snapshot(tactical.board)
if board_result.is_error():
    return board_result                     # NO partial state
var board: BoardState = board_result.metadata.get("board")

# Run-level rng_streams is the between-level authority (Story 2.7 retro decision).
var streams := RngStreamSet.new(0)
var rng_result: ActionResult = streams.try_restore(run_snapshot.rng_streams)
if rng_result.is_error():
    return rng_result                       # invalid_rng_snapshot — NO partial state

return ActionResult.ok([], {
    "run_snapshot": run_snapshot,
    "tactical_snapshot": tactical,
    "board": board,
    "rng_streams": streams
})
```

Rules:

- Propagate the FIRST error verbatim (stable `error_code` + metadata). On ANY failure, return `ActionResult.error(...)` carrying NO restored domain objects — "no partial corrupt state becomes active" (AC2). Never `push_error`-and-continue past a failed validator.
- Resume is a pure read: it executes no commands, advances no turns, draws no RNG, mutates no source state. `try_restore`/`try_from_snapshot` build NEW objects.
- Run-level `rng_streams` is the authoritative gameplay RNG on resume; the embedded tactical `rng_streams` reflects in-level state at level exit and equals the run-level one at a between-level boundary by construction. Restore the run-level streams as live; assert the equality in a test (Story 2.7 left this untested — close it here).
- Presentation is rebuilt FROM restored domain state (AC1). The resume service returns domain objects only; no scene node is ever serialized or returned. A later UI story binds a presenter/view model to this restored state.

### Determinism Comparison Contract (AC4 — name the first divergence)

AC4 requires that a save → resume → same-remaining-commands path matches the uninterrupted path on final board snapshot, ordered events, and gameplay RNG stream states, AND that a mismatch identifies the FIRST divergent event or stream.

- Use existing committed actions / `DomainEvent`s + `BoardState.apply_event(s)` and existing `RngStreamSet` draws. Do NOT invent new gameplay to make the harness richer.
- Compare three surfaces: board `to_snapshot()` equality, event-log/applied-event-sequence equality, and RNG `to_snapshot()` equality PLUS the next-draw reproduction check (state equality alone is necessary but the next-draw check is the strongest determinism proof, and Story 2.7 established it as the bar).
- The failure message must NAME the first divergence — e.g. iterate the two event sequences and report the first differing index/event id, and iterate the seven streams in `RngStreamSet.required_streams()` order and report the first stream whose `state`/`draw_index` differs. A bare `assert_equal(finalA, finalB)` is insufficient for AC4's "identify the first divergent event or stream"; build a small helper that finds and reports it.
- Run the interrupted path through a real `SaveRepository` write→read (JSON), not a native dict — this is what exercises the int64/JSON transport that Story 2.7's fix protects.

### Mid-Level Feasibility Contract (AC3 — make the call, record it)

AC3 is partly a DECISION-recording requirement. The decision must appear in this story's Dev Agent Record / Completion Notes (implemented / deferred / limited) with rationale.

- Technical reality: the existing `TacticalSnapshot` ALREADY serializes everything a mid-level snapshot needs — board with per-cell `visible`/`explored` fog memory, entities with positions/HP/occupancy, `turn_state` (can hold a mid-turn phase), `pending_telegraphs` (Ash-Seer marks etc.), `rng_streams`, and `event_log`. So a mid-level save is mechanically a between-level save taken at an arbitrary turn boundary; `RunSnapshot.from_between_level(...)` already accepts an arbitrary `turn_state`/`pending_telegraphs`/`event_log`.
- The genuine gap is NOT the snapshot — it is (a) a level/turn state machine that defines WHEN a mid-level save is safe, and (b) a trigger/entry point; both arrive with Epics 3-4. The recommended call is therefore **"limited" (snapshot-feasible now; trigger/state-machine wiring deferred to Epics 3-4) OR "implemented as a demonstrated capability via the between-level path"** — choose the one your tests actually support.
- IF implemented (even as a demonstrated capability), add the AC3-required restore test covering fog + entities + pending turn state + RNG stream state (a mid-turn `turn_state` + non-empty `pending_telegraphs` + mid-combat HP + partial `visible`/`explored` fog, round-tripped and restored faithfully). The Sprint Slice 6 exit gate also lists event log among the restore checks — include it.
- IF deferred, add a precise entry to `_bmad-output/implementation-artifacts/deferred-work.md` (this story key + 2026-06-14 + reason). The recording in the story is still mandatory either way.

### State / No-Mutation Contract

Resuming and comparing are pure reads/restores. They must never mutate source state or corrupt a save.

Never during resume/restore/comparison:

- Execute move/attack commands or the command-bridge execute path AS PART OF RESTORE (the AC4 harness applies commands deliberately AFTER restore, to both paths — that is the test, not the restore service).
- Draw gameplay RNG during restore (`try_restore`/`to_snapshot` do not draw; do not call `rand_*` in the service).
- Mutate the source `BoardState`/`RngStreamSet` when building the snapshot or restoring (build NEW objects).
- Activate any partial state when validation fails (AC2).
- Write to or truncate the save file during a READ (reads never write; the original file stays intact on a failed load).

### Previous Story Intelligence

Story 2.7 (Between-Level Save Snapshot Foundation) is the direct partner and built everything this story reads:

- It added `RunSnapshot.from_between_level()` (compose), `RunSnapshot.try_tactical_snapshot()` (strict extract), and `SaveManager.autosave_between_level()` (thin write entry). Resume composes the inverse path; do not fork these.
- **Critical determinism fix (carry it forward):** Story 2.7 discovered that Godot `RandomNumberGenerator.state` is full 64-bit, but `JSON.stringify`/`parse_string` round-trips numbers as IEEE-754 doubles (52-bit mantissa) — silently truncating `state`/`root_seed` and returning ints as floats. The fix string-encodes `RngStreamSet` `root_seed` + per-stream `state` and `RunSnapshot.root_seed` as decimal strings, with tolerant decode. **RULE for this story:** always JSON-round-trip snapshots in tests (write→read through `SaveRepository`, not native dicts), and never reintroduce a raw numeric cast on a >2^53 save field (watch `GameSession.restore_rng_snapshot`'s `int(...)` on `root_seed`).
- Story 2.7's review left three Low-severity DEFERS that overlap this story's resume/determinism work (see Deferred Work below) — fold the two RNG-equality / next-draw ones in here; the float-tolerance one is optional hardening.
- Story 2.7 kept save DTOs `RefCounted` and `SaveManager`/`GameSession` thin, and proved no-mutation on the write path with before/after snapshot equality. Apply the same posture and rigor to resume: `RunResumeService` is `RefCounted`, autoloads stay thin, and every failure path gets a no-partial-state assertion.

Story 1.5 (Tactical Snapshot Serialization Boundary) is the deeper ancestor: it built `TacticalSnapshot` strict parse/export, serializable-only filtering, board/cell occupant-consistency validation, RNG validation, and deterministic restore/continuation tests. Resume reuses those strict validators; it must not weaken or bypass them.

Epic 1 / earlier review lessons that still apply:

- Failed restores must not desync autoload/session state from domain state (Story 1.4 patch lesson). A failed resume must leave `GameSession` RNG and any source state untouched, and `RngStreamSet.try_restore` already does not mutate on failure — verify it.
- Invalid/failure paths need no-mutation/no-partial-state assertions and structured `ActionResult.error()` with stable lower-snake codes + diagnostic metadata. Treat every AC2 failure branch with that rigor.
- `ActionResult.error()`/`ok()` deep-copy metadata and normalize codes; `DomainEvent.try_from_dictionary()` rejects malformed dicts; reuse, don't reimplement.

Epic 2 cross-story facts (from earlier Epic 2 stories) that touch resume:

- The Epic 2 UI/view-model layer (Stories 2.1-2.6) is presentation-only and is NOT save truth. Do not serialize or "restore" any view-model output (`TacticalBoardViewModel`, accessibility cues, layout profiles, text-scale hints) — those are DERIVED from domain state. Resume restores domain snapshots only; a presenter/view model is rebuilt FROM the restored domain state (AC1), not loaded from the save.
- `TacticalBoardViewModel.to_dictionary()` grew to 16 keys across Stories 2.5/2.6 (added `layout`, `accessibility`); this is presentation-derived and irrelevant to the save — do not let it leak into the save or the resume payload.

### Git Intelligence

Recent commits before this story:

- `a21c5ee Merge pull request #4 from rthunborg/story/2-7-between-level-save-snapshot-foundation`
- `59815ee chore(story-2-7): finalize (mark done + GDS status)`
- `7b03765 docs(story-2-7): pipeline report`
- `723268c chore(story-2-7): code review passed`
- `739da3e feat(story-2-7): between-level autosave snapshot foundation`

Actionable patterns:

- The project consistently uses narrow typed `RefCounted` DTOs/services under `scripts/save/`, thin autoloads under `scripts/autoloads/`, and tests-first under `tests/unit/<domain>/` with integration tests under `tests/integration/<domain>/`. Follow that; do not add GUT/GdUnit or any new framework.
- The headless runner auto-discovers `test_*.gd` under `godot/tests/unit` and `godot/tests/integration`; no registry edit is needed.
- ENVIRONMENT (Epic 2 retro): the bare `godot` resolves only as `C:\Users\Rasmus\bin\godot.cmd` through PowerShell; the Bash tool's PATH/`where` cannot find it. Run `godot --version` and the headless suite through `powershell.exe -NoProfile -Command`.
- Review findings across the project have repeatedly tightened value sanitization, no-mutation/no-partial-state assertions, stable reason ids, and structured error metadata. Treat all four as first-class for the resume-failure and determinism tests.

### Architecture Compliance

- Resume restores versioned domain snapshots through `SaveRepository`; presentation rebuilds from restored domain state, never from saved scene nodes. [Source: game-architecture.md#Data Persistence; epics.md Story 2.8 AC1]
- Save Failure handling: preserve the original file, report clearly via a structured result, enter a recovery flow. Story 2.7 delivered the structured result + original-file preservation on WRITE; this story delivers the structured load error + the domain-side recovery path (the structured `ActionResult` a recovery UI later consumes), and keeps the original file intact on a failed read. [Source: game-architecture.md Error Levels table — "Save Failure → Preserve original file, report clearly, enter recovery flow"]
- Save data the snapshot must carry (already present): schema/content version, root seed + named RNG stream states, route/current-node/revealed-route + manual-seed eligibility, level/fog/entity/turn/pending-turn state, inventory/equipment/passives/etc.; player settings and profile/meta live in SEPARATE files. Resume reads the current-run autosave only. [Source: game-architecture.md#Data Persistence]
- Gameplay systems depend on repository contracts, not raw JSON files; go through `SaveRepository`. [Source: game-architecture.md#Data Persistence, #Data Access Pattern]
- Thin autoloads (`GameSession`, `SaveManager`) may exist but must delegate to the domain/save layer and must not own tactical state or schema policy; the resume service is a `RefCounted` save-layer service. [Source: game-architecture.md autoload rules; project-context.md]
- `scripts/save/` and `scripts/tactical/` must not depend on Godot scene nodes for authoritative logic; the resume service and all snapshot/board DTOs are `RefCounted`. [Source: game-architecture.md system-location rules; project-context.md]
- Named RNG streams remain the only gameplay-affecting randomness; resume restores their state and consumes no draws; determinism under seeded execution is preserved across save/resume. [Source: project-context.md Determinism rules; NFR13]
- Headless tests run without rendering, audio, UI scenes, presentation nodes, or scene-tree-only state. [Source: project-context.md Testing rules]
- Do not add cloud services, accounts, multiplayer, telemetry, Godot .NET/C#, new test frameworks, or React/Vite production dependencies. [Source: project-context.md Critical Don't-Miss rules]

### Library And Framework Requirements

- Required engine: Godot 4.6.3 stable standard build. Required language: typed GDScript.
- The resume service is `RefCounted` (NOT a `Node`, NOT an autoload).
- Reuse `SaveRepository`'s `JSON.parse_string()` read exactly as-is; production restore operates on dictionaries + `ActionResult`. Use `JSON` directly only in tests that explicitly assert JSON compatibility.
- Use `Dictionary.duplicate(true)` / `Array.duplicate(true)` for any defensive copies; the strict validators already reject non-serializable / forbidden values for the tactical payload.
- Use the existing custom headless harness: tests `extends "res://tests/unit/test_case.gd"`, expose `run() -> Dictionary`, return `result()`. Do NOT add GUT, GdUnit, or another testing dependency.

### Latest Technical Information

Official Godot 4.6 sources relevant to reading a between-level JSON save through a repository (these inform file-I/O / parse correctness, not gameplay):

- `FileAccess.file_exists` / `FileAccess.open(..., READ)` and `JSON.parse_string()` are the primitives the existing `read_run_snapshot` uses; `JSON.parse_string()` returns `null` on parse failure (surfaced as `save_parse_failed`). Keep all file I/O inside `SaveRepository`. Source: https://docs.godotengine.org/en/4.6/classes/class_fileaccess.html and https://docs.godotengine.org/en/4.6/classes/class_json.html
- `user://` resolves to the per-user writable data directory and is the save location (never `res://`, read-only in exported builds — useful for the AC2 missing/unreadable test). Source: https://docs.godotengine.org/en/4.6/tutorials/io/data_paths.html
- `JSON.stringify()`/`parse_string()` round-trip numbers as IEEE-754 doubles, so strict integer fields are validated after parse and full-64-bit fields (`state`, `root_seed`) are decimal-string encoded (Story 2.7 fix). Resume tests MUST go through real JSON write→read so this transport is covered. Source: https://docs.godotengine.org/en/4.6/classes/class_json.html
- `RandomNumberGenerator.seed` / `state` restore: setting `state` after `seed` reproduces the exact stream position; `RngStreamSet.try_restore` does this. Source: https://docs.godotengine.org/en/4.6/classes/class_randomnumbergenerator.html

### Project Structure Notes

- The resume service belongs under `godot/scripts/save/` (`run_resume_service.gd`); it composes the existing snapshot DTOs under `godot/scripts/save/snapshots/`.
- Any thin resume delegation belongs on the existing `SaveManager` autoload; session RNG continuity belongs on `GameSession`. Keep both thin.
- Resume/determinism tests belong under `godot/tests/unit/save/` (service unit tests) and `godot/tests/integration/save/` (end-to-end resume + interrupted-vs-uninterrupted comparison).
- Tactical legality / restore stays under `godot/scripts/tactical/`; do not move tactical truth or command validation into the save layer.
- Production code stays under `godot/`; no production dependency on `prototype/`.
- Root `project-context.md` is canonical; do not create duplicate project context files under `_bmad-output/`.
- No standalone UX file exists; this is a domain/save resume story and needs no UI artifact input. The resume/load UI scenes are a later story (Epic 2 keeps tactical layout in testable view models/profiles per Story 2.5's deferral).

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
- All existing Epic 1 and Story 2.1-2.7 tests remain green — including `test_run_snapshot.gd`'s "ambiguous `manual_seed_eligible_for_progression` absent" assertion, `test_save_repository.gd`'s round-trip + schema-reject tests, the Story 2.7 integration round-trip, and `test_rng_stream_set.gd`'s int64 JSON round-trip test.
- AC1: a valid between-level save (written through `SaveRepository`, read through it) restores `BoardState` (incl. fog `visible`/`explored` flags), `TacticalSnapshot` (turn_state, pending_telegraphs), and run-level `RngStreamSet` faithfully; the restored board snapshot equals the source board snapshot; the resume payload contains only domain objects / JSON-compatible data with no scene/audio/presentation references.
- AC2: resume rejects (with stable structured `error_code` + metadata and NO partial restored state) a missing save (`save_not_found`), unparseable bytes (`save_parse_failed`), unsupported schema (`unsupported_save_schema`), a corrupt embedded tactical payload (`invalid_tactical_snapshot`), and malformed RNG streams (`invalid_rng_snapshot`); the original save file is intact after a failed read.
- AC3: the mid-level feasibility CALL (implemented / deferred / limited) is recorded in the Dev Agent Record with rationale; if implemented, a restore test covers fog + entities + pending turn state + RNG stream state (and event log); if deferred, a deferral entry exists in `deferred-work.md`.
- AC4: an interrupted (save→resume→remaining-commands) path matches the uninterrupted path on final board snapshot, ordered events, and gameplay RNG stream states (incl. next-draw reproduction); a deliberately induced mismatch test (or the helper) reports the FIRST divergent event index or RNG stream.
- The run-level `rng_streams` equals the embedded tactical `rng_streams` for a between-level save (RNG-authority equality assertion — closes a Story 2.7 defer).
- All save/resume tests clean up their `user://` temp files (`*.json`, `*.json.tmp`, `*.json.bak`) and any directory artifacts.
- `git diff --check` reports no whitespace errors.

### Project Context Rules

- Read and follow root `project-context.md` before implementation.
- Read `_bmad-output/game-architecture.md` before architecture-sensitive changes (Data Persistence, Error Levels, Data Access Pattern).
- Root `project-context.md` is canonical; do not create duplicate project context under `_bmad-output/`.
- Production code goes under `godot/`; React/Vite `prototype/` remains validation evidence only.
- Production engine is Godot 4.6.3 stable standard; primary language is typed GDScript.
- Target platforms are iOS/Android mobile and tablet first with Windows desktop/laptop parity.
- MVP is offline-first single-player. No accounts, cloud saves, multiplayer, leaderboards, or live-service dependency.
- Scene-independent domain model owns tactical truth; Godot scenes, UI, audio, VFX, and animation mirror domain outcomes and do not own gameplay state. Resume restores domain state; presentation rebuilds FROM it.
- Commands validate before mutation and return `ActionResult`; successful commands emit deterministic past-tense `DomainEvent` records. Resuming consumes no commands and emits no events; the AC4 harness applies commands deliberately after restore.
- Use named RNG streams for gameplay-affecting randomness; resume restores stream state and consumes no draws; determinism is preserved across save/resume.
- Save/restore versioned domain snapshots only through `SaveRepository`; never serialize or restore scene nodes as save truth.
- Keep autoloads thin (`SaveManager`, `GameSession`): they delegate to domain/save services and do not own gameplay decisions or schema policy. The resume service is a `RefCounted` save-layer service.
- Headless simulation must not depend on rendering, audio, UI scenes, presentation nodes, or scene-tree-only state.
- Do not introduce cloud services, accounts, multiplayer, telemetry dependencies, Godot .NET/C#, new test frameworks, or third-party libraries unless the architecture is explicitly revised.
- Preserve user changes and unrelated dirty worktree files.

### Deferred Work Overlapping This Story

These items were consciously deferred by the Story 2.7 code review (2026-06-14) and DIRECTLY overlap this story's resume/determinism area. Address the first two here (they are cheap and squarely in scope); the third is optional hardening.

- **(Fold in — RNG-authority equality)** Story 2.7 review left untested that run-level `RunSnapshot.rng_streams` equals the embedded tactical `rng_streams` for a between-level save (they are equal by construction but no test guards it). Add the equality assertion as part of the resume RNG-authority test (Task 2.8.2). Originating: code review of 2-7, Round 1.
- **(Fold in — symmetric next-draw determinism)** Story 2.7's integration round-trip restored the embedded tactical `rng_streams` and asserted only that restore succeeds, not that the restored tactical streams reproduce the same next draw (the run-level streams got that stronger check). The AC4 determinism harness should restore and exercise both run-level and embedded-tactical streams to the "reproduce exact next draw" bar (Task 2.8.5). Originating: code review of 2-7, Round 1.
- **(Optional hardening — float tolerance for unbounded int64 fields)** `RngStreamSet.try_restore()` still tolerantly accepts `state`/`root_seed` as a raw JSON float via the `TYPE_FLOAT` branch; a hand-edited/future save storing `state` as a number beyond 2^53 would pass the integral-float check and be silently truncated. The live path is safe (production always emits decimal strings), so this is NOT required for this story — only consider tightening `state`/`root_seed` to reject `TYPE_FLOAT` (or reject finite doubles > 2^53) with a regression test if it falls out naturally while touching RNG restore. Do NOT re-open or re-defer it otherwise. Originating: code review of 2-7, Round 1.

All other entries in `_bmad-output/implementation-artifacts/deferred-work.md` (Story 2.5 layout-profile defers, Story 2.6 accessibility defer, Story 1.3 board-snapshot defers — already resolved in Story 1.5) are out of scope for this resume story; do not pull them in.

### References

- [Source: `_bmad-output/planning-artifacts/epics.md` — Epic 2 and Story 2.8 acceptance criteria]
- [Source: `_bmad-output/implementation-artifacts/epic-2-sprint-plan-2026-06-07.md` — Sprint Slice 6 Save/Resume Foundation tasks + exit gate: "Between-level save/resume works through domain snapshots, and mid-level feasibility is explicitly recorded"; "Compare interrupted and uninterrupted command sequences and report first divergent event or RNG stream"; "If mid-level save is implemented, add restore tests for fog, entities, pending turn state, event log, and RNG stream state"]
- [Source: `_bmad-output/implementation-artifacts/2-7-between-level-save-snapshot-foundation.md` — the between-level WRITE path this story reads; `from_between_level`/`try_tactical_snapshot`/`autosave_between_level`; the int64/JSON determinism fix and its "always JSON-round-trip" rule; the three Round-1 deferred items]
- [Source: `_bmad-output/implementation-artifacts/1-5-tactical-snapshot-serialization-boundary.md` — `TacticalSnapshot` strict parse/restore reuse target; deterministic restore/continuation tests]
- [Source: `_bmad-output/auto-gds/retro-notes/epic-2.md` — Story 2.7 note: "Story 2.8's resume flow must decide which RNG snapshot wins on restore"; "always JSON-round-trip snapshots in tests, and string-encode any large int64 save field"; PowerShell `godot` invocation requirement; `TacticalBoardViewModel.to_dictionary()` 16-key presentation-only growth]
- [Source: `_bmad-output/implementation-artifacts/deferred-work.md` — the three Story 2.7 Round-1 resume/determinism defers folded in above]
- [Source: `project-context.md` — determinism/save/snapshot rules, thin-autoload rule, headless/testing rules, no-telemetry/no-cloud rules]
- [Source: `_bmad-output/game-architecture.md#Data Persistence` — versioned local JSON in `user://`, `SaveRepository` + snapshot DTOs, required save fields, settings/profile in separate files, "depend on repository contracts not raw JSON"]
- [Source: `_bmad-output/game-architecture.md` Error Levels table — "Save Failure → Preserve original file, report clearly, enter recovery flow"]
- [Source: `_bmad-output/game-architecture.md#Data Access Pattern` — `save_repository` repository contract]
- [Source: `_bmad-output/planning-artifacts/gdds/gdd-Game-2026-05-31/gdd.md` — required save/resume between levels, desirable mid-level save/resume, manual-seed-no-progression]
- [Source: `godot/scripts/save/save_repository.gd` — `read_run_snapshot` structured read (`save_not_found`/`save_open_failed`/`save_parse_failed` → `RunSnapshot.parse`)]
- [Source: `godot/scripts/save/snapshots/run_snapshot.gd` — lenient `parse()`, strict `try_tactical_snapshot()`, `from_between_level()`, int64-string `root_seed`]
- [Source: `godot/scripts/save/snapshots/tactical_snapshot.gd` — strict Epic 1 tactical restore via `parse()`; serializable filter; forbidden-reference rejection]
- [Source: `godot/scripts/tactical/board/board_state.gd` — `try_from_snapshot()` strict board restore (fog flags, occupancy consistency); `to_snapshot()`; `apply_event(s)`]
- [Source: `godot/scripts/core/state/rng_stream_set.gd` — int64-safe `to_snapshot()`/`try_restore()`, tolerant decode, `invalid_rng_snapshot`, no-mutation-on-failure]
- [Source: `godot/scripts/autoloads/game_session.gd` — thin seed/RNG wiring; `restore_rng_snapshot()` (watch the `int(root_seed)` decode vs int64-string encoding)]
- [Source: `godot/scripts/autoloads/save_manager.gd` — thin write/read/autosave delegations; optional `resume_run` delegation home]
- [Source: `godot/scripts/core/results/action_result.gd` — `ActionResult.ok/error`, `succeeded`/`is_error()`, lower-snake error codes, deep-copied metadata]
- [Source: `godot/tests/integration/save/test_between_level_save.gd` — Story 2.7 round-trip + no-scene-truth + AC4-write-failure to extend; reusable `_is_json_compatible`/`_contains_forbidden_reference` helpers]
- [Source: `godot/tests/unit/save/test_run_snapshot.gd` — `_between_level_rejects_corrupt_embedded_tactical_snapshot` corruption technique to mirror; existing assertions to keep green]
- [Source: `godot/tests/unit/save/test_save_repository.gd` — happy-path + schema-reject + AC4 write-failure tests to keep green]
- [Source: `godot/tests/fixtures/tactical/board_fixture_factory.gd` — reusable board fixtures for source state]
- [Source: `godot/tests/unit/test_case.gd` — custom headless harness base (`run()`/`assert_*`/`result()`); no new test framework]
- [Source: Godot 4.6 FileAccess docs](https://docs.godotengine.org/en/4.6/classes/class_fileaccess.html)
- [Source: Godot 4.6 JSON docs](https://docs.godotengine.org/en/4.6/classes/class_json.html)
- [Source: Godot 4.6 RandomNumberGenerator docs](https://docs.godotengine.org/en/4.6/classes/class_randomnumbergenerator.html)
- [Source: Godot 4.6 data paths (`user://`) docs](https://docs.godotengine.org/en/4.6/tutorials/io/data_paths.html)

## Dev Agent Record

### Agent Model Used

Story context: Claude Opus 4.8 (1M context).

### Implementation Plan

- Add RED resume tests first: (a) `RunResumeService` AC1 restore round-trip through a real `SaveRepository` write→read (board incl. fog flags, tactical turn/telegraphs, run-level RNG restored + reproduces next draw); (b) AC2 five-way corrupt/incompatible-save rejection with stable codes + no partial state + original file intact; (c) the RNG-authority equality assertion (run-level == embedded tactical); (d) AC4 interrupted-vs-uninterrupted determinism harness that reports the first divergent event/stream; (e) if mid-level implemented, a fog/entities/pending-turn/RNG/event-log restore test.
- Implement `godot/scripts/save/run_resume_service.gd` (`RefCounted`) composing `SaveRepository.read_run_snapshot` → `RunSnapshot.parse` → strict `try_tactical_snapshot` → `BoardState.try_from_snapshot` → `RngStreamSet.try_restore`, returning restored domain pieces on success and the first structured error (no partial state) on failure. Restore the run-level `rng_streams` as authoritative; document the decision.
- Optionally add a thin `SaveManager.resume_run(save_path)` delegation; keep `SaveManager`/`GameSession` thin and the int64-string `root_seed` decode tolerant.
- Make and RECORD the mid-level feasibility call (implemented / limited / deferred) with rationale grounded in the existing `TacticalSnapshot` coverage; add the restore test or the `deferred-work.md` entry accordingly.
- Reuse existing primitives/validators and the custom headless harness; do not fork a reader, weaken strict validation, or add a test framework.

### Debug Log References

- 2026-06-14: Created Story 2.8 implementation guide from Epic 2 source requirements, the Epic 2 sprint plan (Sprint Slice 6 tasks + exit gate), root project context, game architecture (Data Persistence, Error Levels, Data Access Pattern), the GDD save/resume requirements, Story 2.7 (the between-level write path + the int64/JSON determinism fix + its three Round-1 defers), Story 1.5 (the `TacticalSnapshot` strict-restore reuse target), the Epic 2 auto-gds retro notes (RNG-authority-on-resume decision, JSON-round-trip rule, PowerShell `godot`), the deferred-work ledger, and direct inspection of the existing save/restore layer on disk (`save_repository.gd`, `run_snapshot.gd`, `tactical_snapshot.gd`, `rng_stream_set.gd`, `board_state.gd`, `game_session.gd`, `save_manager.gd`, `action_result.gd`, and the current save tests). Confirmed via a project-wide grep that NO resume/restore-run flow code exists yet (only `RngStreamSet` matched), so the resume FLOW is greenfield while every restore primitive is already built and tested.

### Completion Notes List

- Story context created and marked ready for development.
- Ultimate context engine analysis completed - comprehensive developer guide created.

### File List

### Change Log

| Date | Change |
|---|---|
| 2026-06-14 | Created Story 2.8 implementation guide (resume flow + mid-level save feasibility) and marked it ready for development. |
