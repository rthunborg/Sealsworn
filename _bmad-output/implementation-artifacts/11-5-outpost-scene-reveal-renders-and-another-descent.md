# Story 11.5: Outpost Scene, Reveal Renders, and Another Descent

Status: ready-for-dev

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a player,
I want to return to a real outpost after a run — see what happened, read the line, and descend again,
so that the return loop and its story beats are experienced, not implied.

## Story Type & Scope Boundary (READ FIRST)

**This IS a CODE story — the OUTPOST-SCENE + REVEAL-RENDER + run-end↔profile-BRIDGE story of Epic 11.** It is the
counterpart to 11.3 at the *other* end of the loop: 11.3 built the launch→hero-select→route-map→board→run-end
navigation and a **deliberately minimal** run-end landing (`run_end_presenter.gd`) that only shows "the run ended;
return to the outpost" and boots back to hero select. **11.5 replaces that minimal landing with the real outpost
scene bound to `OutpostViewModel`, renders the first-death/first-victory reveal beats + the manual-seed warning,
wires the run-end→profile bridge the live flow is missing, and closes the loop with a working "start another
descent" (FR1 loop closure).**

- **The single most load-bearing as-built fact (VERIFY by reading — the DATA surfaces already EXIST, un-wired to the
  live flow):** every read surface this story renders was SHIPPED by Epic 8/9 as a pure `RefCounted` DTO, but the
  live run flow (11.2/11.3) **never touches the profile, never records the first-death/first-victory latch, and
  never builds a `RunSummary` or an `OutpostViewModel`.** The live `RunOrchestrator.resolve_run_end(...)` transitions
  the run to `PHASE_COMPLETED`/`PHASE_FAILED` and captures the run-end cause/outcome, but it does **NOT** import
  `ProfileRepository`, `RecordFirstDeathCommand`, `RecordFirstVictoryCommand`, `RunSummary`, or `OutpostViewModel`
  (grep-verified: 0 references in `run_orchestrator.gd`). **The run-end→profile→outpost bridge is 11.5's crux — it
  does not exist yet.** 11.3's `run_end_presenter` reads only `RunEndOutcome` (phase/cause/eligibility) off the live
  `RunFlowController`; it builds no summary and no profile.

- **The as-built surfaces 11.5 BINDS to (read the source; do not re-implement):**
  - **`OutpostViewModel`** (`godot/scripts/ui/view_models/outpost_view_model.gd`) — the pure-read outpost assembly
    (Story 8.6). Pinned `DICTIONARY_KEYS = [has_profile, recovery_state, oath_shards, echoes, unlock_progress,
    class_mastery, first_death_recorded, run_summary, class_options, selectable_class_ids, named_spaces,
    first_death_beat, can_start_run]`. Constructor `_init(profile, run_summary, first_death_beat, class_repository,
    recovery_state)`; the recovery static `for_recovery(recovery_code, loaded_profile=null, run_summary=null,
    first_death_beat=null, class_repository=null, is_recoverable=true)`; the start seam
    `start_run_request(request_root_seed:int, request_is_manual_seed:=false, request_class_id:=&"") ->
    {root_seed(decimal-string), is_manual_seed, class_id, is_startable}`. **⭐ NOTE: it embeds `first_death_beat` but
    NOT a first-victory beat** — the 9.4 AC3 render decision explicitly deferred wiring the first-victory reveal onto
    `OutpostViewModel` to "a later UI story" = 11.5 (see the G3/reveal decision below).
  - **`RunSummary`** (`godot/scripts/run/run_summary.gd`) — the pure-read run-summary aggregator (Story 8.2/8.4).
    Pinned `DICTIONARY_KEYS = [has_summary, phase, outcome_or_cause, seed, is_manual_seed, meta_progression_eligible,
    run_scoped, profile_meta, content_unlock, not_yet_supported]`. `run_scoped` = `[nodes_cleared, boss_cleared,
    elite_nodes_cleared, passives_consumed, passives_destroyed, notable_loot, gold, curse_count, corruption]`.
    `profile_meta.oath_shards_earned` STAYS `0` and is named in `not_yet_supported` (the G3 decision below). Built via
    `RunSummary.build(run: RunState, events: Array = [])` — the route/economy facts derive from the terminal
    `RunState`; the passives/loot/discovery lists derive from the SUPPLIED ordered `events` list (v0 has NO run-level
    event store — see the event-sourcing constraint below).
  - **`FirstDeathNarrativeBeat`** (`godot/scripts/run/first_death_narrative_beat.gd`) — pinned `DICTIONARY_KEYS =
    [has_beat, line_id, line, is_skippable]`; `line` resolves `"Good. You remembered how to die."` (const
    `FIRST_DEATH_LINE`, `line_id: "first_death"`). Build via `for_first_death(line_id := DomainEvent.FIRST_DEATH_LINE_ID,
    is_skippable := true)` or `from_event(event)`. A skip/dismiss is STRUCTURALLY a no-op (the DTO owns no truth).
  - **`FirstVictoryRevealBeat`** (`godot/scripts/run/first_victory_reveal_beat.gd`) — the OPPOSITE-phase twin; pinned
    `DICTIONARY_KEYS = [has_beat, line_id, line, is_skippable]`; `line` resolves `"It did not die. It learned the way
    back."` (const `FIRST_VICTORY_LINE`, `line_id: "first_victory"`). Build via `for_first_victory(...)` or
    `from_event(event)`.
  - **The run-end→profile command family (Epic 8/9 — the mutations 11.5's bridge orchestrates):**
    - `RecordFirstDeathCommand` (`godot/scripts/core/commands/record_first_death_command.gd`) — `_init(profile:
      ProfileSnapshot, sequence_id: int)`; `execute(state)` takes the terminal `RunState` as `state`; DEATH-only gate
      (`run.phase == PHASE_FAILED`, else `run_not_failed`); once-only latch (`first_death_already_recorded`); sets
      `profile.first_death_recorded = true`; ELIGIBILITY-INDEPENDENT (a manual-seed first death still records + shows
      the line — the ratified 8.5 Option A).
    - `RecordFirstVictoryCommand` (`godot/scripts/core/commands/record_first_victory_command.gd`) — the twin;
      VICTORY-only gate (`run.phase == PHASE_COMPLETED`, else `run_not_completed`); once-only
      (`first_victory_already_recorded`); sets `profile.first_victory_recorded = true`; ELIGIBILITY-INDEPENDENT
      (Option A). Both reject `sequence_id <= 0` FIRST (`invalid_event_sequence_id`); both mutate the profile
      IN-PLACE on success and return the beat data in `result.metadata`; the CALLER persists via
      `ProfileRepository.write_profile`.
    - `AwardMetaProgressCommand` / `MergeRunDiscoveriesCommand` — the 8.3 award + 8.4 merge. **These are 11.6's SPEND/
      application concern, NOT 11.5's** — see the scope fences. 11.5 may record the first-death/victory latch (a
      NARRATIVE flag, eligibility-independent) but does NOT drive the award/merge GRANT (that is meta progression;
      11.6 owns it end-to-end).
  - **`ProfileRepository`** (`godot/scripts/save/profile_repository.gd`) — `read_profile(save_path :=
    "user://profile.json") -> ActionResult` (returns `profile_not_found` when absent → the CALLER starts
    `ProfileSnapshot.fresh()`; `profile_open_failed`; `profile_parse_failed`; else `ProfileSnapshot.parse(...)` which
    surfaces `unsupported_profile_schema`). `write_profile(snapshot, save_path) -> ActionResult` (atomic
    temp→backup→replace; structured `profile_save_open_failed` / `_backup_remove_failed` / `_backup_failed` /
    `_replace_failed` on failure; a failed write leaves the prior valid profile intact). **⭐ There is NO
    `SaveManager` profile delegator** (project-context: "Epics 8-9 added NO SaveManager profile delegator — the
    caller drives ProfileRepository directly; no live boot-flow wiring exists yet"). 11.5 drives `ProfileRepository`
    directly (the outpost/run-end bridge is the first live profile caller) — decide whether to add a thin
    `SaveManager` profile delegator (mirroring `resume_route_position`) or call the repository directly; do NOT put
    run/profile LOGIC in the autoload (keep it thin).
  - **`ProfileSnapshot`** (`godot/scripts/save/snapshots/profile_snapshot.gd`) — `SCHEMA_VERSION == 1`; carries
    `oath_shards`, `echoes`, `unlock_progress`, `class_mastery`, `first_death_recorded`, `first_victory_recorded`;
    `ProfileSnapshot.fresh(profile_id := "default")` is the fresh/recovery default. **DO NOT bump SCHEMA_VERSION or
    add a key** — both latches already have homes.
  - **The 11.3 scene-flow scaffolding 11.5 EXTENDS (read the source):**
    - `RunFlowController` (`godot/scripts/ui/flow/run_flow_controller.gd`) — exposes `run() -> RunState`,
      `orchestrator() -> RunOrchestrator`, `run_end_outcome() -> Dictionary`, `run_end_stage() -> String`. It does
      NOT today expose a `RunSummary`, a `ProfileSnapshot`, or the first-victory beat — 11.5 adds the bridge (decide:
      extend the controller with a run-end→profile→summary/outpost seam, or add a separate thin outpost-bridge
      surface the outpost presenter drives).
    - `RunFlowRouter` (`godot/scripts/ui/flow/run_flow_router.gd`) — the pure route table. `STAGES = [launch,
      hero_select, route_map, tactical_board, run_end]`; `_STAGE_SCENES` maps each stage to a `.tscn`;
      `_DESTINATION_STAGES = {"outpost": "run_end"}` (the run-end `next_destination == outpost` marker currently
      routes to the minimal `run_end` stage). **⭐ 11.5 must add a real `outpost` stage + scene** and re-point the
      `outpost` destination (and/or the run-end landing) to it. Pinned by `test_run_flow_router.gd` — update the pin.
    - `SceneManager` (`godot/scripts/autoloads/scene_manager.gd`) — thin; `go_to_stage(stage)` +
      `route_after_run_end(next_destination)` DELEGATE to `RunFlowRouter`. Keep it thin.
    - `GameSession` (`godot/scripts/autoloads/game_session.gd`) — holds the live `RunFlowController` handle across
      scene changes (`run_flow()` / `set_run_flow()` / `clear_run_flow()`). The outpost reads the terminal run-flow
      handle to build the summary/outpost, then clears it before a fresh descent.
    - `run_end_presenter.gd` — the MINIMAL 11.3 landing (reads `RunEndOutcome`, "Return to the Outpost" → hero
      select). 11.5 either replaces it with the real outpost scene or repoints navigation so `outpost` lands on the
      new outpost scene. Do not leave two competing "the run ended" surfaces.
    - `RunResumeRecoveryView` (`godot/scripts/ui/view_models/run_resume_recovery_view.gd`) — 11.3's RUN-side resume
      recovery. Its class doc pins the SPLIT: "11.3 handles the RUN save/resume recovery on the run-flow side; the
      PROFILE-recovery surface at the outpost is 11.5's (the `OutpostViewModel.recovery_state`)." **11.5 owns the
      PROFILE-recovery render** (AC3), NOT the run-resume recovery.
    - The pattern presenters 11.5's outpost presenter MIRRORS: `route_map_presenter.gd` / `hero_select_presenter.gd`
      (a `Control` that reads a pinned VM projection, maps fields to non-color visuals, submits intent through the
      existing seam, owns no truth) — follow this posture verbatim.
  - **Approved treatment baseline (already merged to `main`; bind the id/tag hooks, author NO new art):** the Recraft
    UI-frame kit (button/panel/modal) is the frame baseline for the outpost + run summary (appendix §14.3). The
    outpost binds frame/id hooks; 11.4's affinity treatment is the pre-boss board's, not the outpost's.

- **What 11.5 delivers (four AC groups):**
  1. **Outpost scene + start-another-descent (AC1).** A `Control` outpost scene renders the `OutpostViewModel`
     contract (currency totals from `profile.oath_shards`/`echoes`, the four `deferred` named spaces, the embedded
     `run_summary`, `unlock_progress`), and starting another descent works through the
     `start_run_request(...)`/`is_startable` seam → a FRESH `RunOrchestrator.start(...)` (FR1 loop closure).
  2. **Reveal renders (AC2).** The first-death / first-victory beats render as OPTIONAL, skippable/dismissible beats
     (FR61/FR62/FR64/FR65); a skip/dismiss is a pure presentation no-op that NEVER blocks the outpost surface or a
     new descent.
  3. **Profile recovery render (AC3).** The write-failure path uses the loaded-profile `for_recovery(code,
     loaded_profile)` representation (real totals behind a retry banner); the load-failure path uses the
     fresh-profile fallback `for_recovery(code)`; the previously untested loaded-profile + recovery combination gains
     its SCENE-level test (carried Epic-8 T4).
  4. **Oath-Shards-earned coupling decision (AC4) + manual-seed warning.** The G3 summary↔profile coupling decision
     (carried Epic-8 T5 / Epic-9 T4) is MADE and implemented; manual-seed runs show the no-progression warning
     (FR28 surface).

- **What 11.5 does NOT do (hard scope fences — do not cross):**
  - **No meta SPEND / unlock APPLICATION (that is 11.6).** 11.5 DISPLAYS `oath_shards` / `unlock_progress` /
    `class_mastery` and CLOSES the loop with a fresh descent; it does NOT build the spend menu, does NOT run
    `AwardMetaProgressCommand`/`MergeRunDiscoveriesCommand` as a GRANT, and does NOT turn `unlock_progress` into a
    playable-class unlock (the locked-class-hint → selectability flip is 11.6's FR43 concern). The four named spaces
    stay `status: "deferred"` (rendered with an explicit "deferred" marker, never silently omitted). **If a summary/
    outpost cross-read needs the AWARDED Oath-Shard total, read `profile.oath_shards` (already awarded state) — do
    NOT introduce a new award call site here.**
  - **No new save key, no schema bump, no new RNG stream, no new fingerprint, no new event.** The 23-key `RunSnapshot`
    gate stays 23; `ProfileSnapshot`/`SettingsSnapshot` `SCHEMA_VERSION == 1` (both latches already have homes — set
    them, do not add them); the 7 named RNG streams (`map`/`level`/`combat`/`loot`/`rewards`/`events`/`cosmetic`) are
    untouched; every pinned level/route/arena/finale seed-regression fingerprint stays byte-identical; the
    `DomainEvent.Type` enum tail is UNCHANGED (the `first_death_recorded` / `first_victory_recorded` events already
    exist — the record commands REUSE them; NO new event). The outpost/summary/beats are DERIVED reads, not save
    state.
  - **No new domain surface / no new autoload.** Bind the existing pinned surfaces. `OutpostViewModel` /
    `RunSummary` / the beats already exist. If a first-victory reveal needs surfacing on the outpost, prefer the
    minimal seam (compose the `FirstVictoryRevealBeat` alongside, OR add ONE sub-dict to `OutpostViewModel` — see
    AC2 decision); do NOT invent a parallel outpost DTO. No new registered autoload (Epics 8-9 added none; keep
    `SceneManager`/`GameSession`/`SaveManager` thin).
  - **No difficulty knob, no in-run/mid-encounter save.** The manual-seed warning is a presentation READOUT of
    existing `is_manual_seed`/`meta_progression_eligible` flags — no new field (FR28). No mid-encounter save (the
    23-key gate stays 23; the in-node fight state stays ephemeral — the later in-node-save story owns that).
  - **No affinity work (11.4, done).** The pre-boss board's affinity treatment is 11.4's; the outpost has no
    affinity.

## Acceptance Criteria

Sourced verbatim from `epics.md` (Epic 11, Story 11.5, lines ~2697-2723). Four AC groups (Given/When/Then + And):

1. **Outpost scene + another descent (AC1).** GIVEN a run ends in death or victory, WHEN I return to the outpost,
   THEN an outpost scene renders the `OutpostViewModel` contract (currency totals, named spaces, run summary, unlock
   progress) — AND starting another descent works through the `start_run_request`/`is_startable` seam (FR1 loop
   closure).

2. **Reveal renders (AC2).** GIVEN the profile's first death or first victory has just been recorded, WHEN the
   outpost presents the narrative beat, THEN "Good. You remembered how to die." / "It did not die. It learned the way
   back." render as optional, skippable/dismissible beats (FR61, FR62, FR64, FR65) — AND skipping or dismissing is a
   pure presentation no-op that never blocks the outpost surface or a new descent.

3. **Profile recovery render (AC3).** GIVEN a profile load or write failure occurred, WHEN the outpost renders
   recovery, THEN the write-failure path uses the loaded-profile `_init` representation (real totals behind a retry
   banner) and the load-failure path uses the fresh-profile fallback — AND the previously untested loaded-profile +
   recovery combination gains its scene-level test (carried Epic-8 T4).

4. **Oath-Shards-earned coupling + manual-seed warning (AC4).** GIVEN the run summary displays, WHEN "Oath Shards
   earned" is shown, THEN the summary-to-profile coupling decision (carried Epic-8 T5 / Epic-9 T4) is made and
   implemented — display the awarded total on the summary or surface it via the outpost — AND manual-seed runs show
   their no-progression warning (FR28 surface).

### AC Verification (how "done" is checked)

- **AC1 —** an outpost `Control` scene under `godot/scenes/ui/` reads the `OutpostViewModel.to_dictionary()`
  projection and renders: the meta readout (`oath_shards` + `echoes` count as number+label, non-color), the four
  `named_spaces` (each with its `display_name` + an explicit `deferred` marker — icon/label, not color-only), the
  embedded `run_summary` sub-dict (via its own `has_summary` gate), and `unlock_progress` (displayed, not spent). The
  "descend again" affordance (≥44×44) calls `start_run_request(root_seed, is_manual_seed, class_id)` and, on
  `is_startable`, hands the request to a FRESH `RunOrchestrator.start(...)` (via `RunFlowController.start(...)`) — a
  new seed → a new route → a new run (the prior run is NOT reused, structural). Verified by: (a) a headless test that
  the outpost VM projection the scene reads renders every pinned key + the start-request round-trips to a fresh run
  on a verified seed (extend `test_outpost_view_model.gd` / a new `test_run_flow_*` case); (b) the scene-load compile
  guardrail covers the new outpost scene (`test_run_flow_scenes_load.gd`); (c) a code-level audit that the outpost
  presenter READS the pinned VM keys + submits ONLY the start request (a read-only + start-seam binding, no domain
  mutation, no live-handle leak).
- **AC2 —** the outpost renders BOTH beats (first-death via the already-embedded `OutpostViewModel.first_death_beat`
  sub-dict; first-victory via the AC2 decision below) with a Skip/Dismiss affordance (≥44×44, always reachable). The
  render branches on the `has_beat` gate (absent beat → not rendered, nothing blocked). The Skip/Dismiss is
  STRUCTURALLY a no-op: it stops rendering the beat and mutates NOTHING (no command, no flag — the latch is set by
  the record command independently). Verified by: (a) a headless test that a present beat projects `has_beat: true`
  with the correct line + `is_skippable: true`, an absent beat projects `has_beat: false`, and the outpost surface is
  COMPLETE without either beat (the off-critical-path FR64 assertion — the summary/start-descent are reachable with a
  null beat); (b) a code audit that the Skip path submits no command (a pure presentation no-op).
- **AC2 first-victory decision (the 9.4 render defer 11.5 OWNS — pick ONE, record it in Completion Notes):**
  `OutpostViewModel` embeds `first_death_beat` but NOT a first-victory beat (the 9.4 AC3 render `[Decision]`
  explicitly deferred wiring the first-victory reveal onto `OutpostViewModel` to "a later UI story" = 11.5). Two
  acceptable shapes:
  - **Option A (RECOMMENDED — minimal, mirrors the first-death embed):** add ONE `first_victory_beat` sub-dict to
    `OutpostViewModel` (a new constructor arg + a new pinned `DICTIONARY_KEYS` entry — a KEY addition, NOT a schema
    bump; update `test_outpost_view_model.gd`'s pinned-key assertion + all its recovery-mode constructions). This
    keeps the outpost the single embedded reveal surface (both beats ride alongside `run_summary`, symmetric).
  - **Option B:** the outpost presenter composes the `FirstVictoryRevealBeat` DIRECTLY (built from the run-end
    first-victory fact the bridge threads), leaving `OutpostViewModel`'s pinned key set unchanged. Lower blast radius
    on the VM's exact-key pin + recovery tests, but the reveal surface is split (first-death embedded, first-victory
    composed).
  Whichever is chosen, the reveal is OFF THE CRITICAL PATH (FR64): the outpost is complete without it. Do NOT add a
  narrative field to `RunSummary` (8.5/9.4 forbade it — the beats are SEPARATE surfaces).
- **AC3 —** the outpost renders BOTH profile-recovery modes through the EXISTING
  `OutpostViewModel.for_recovery(...)`:
  - **Profile-LOAD failure** (`profile_not_found` / `unsupported_profile_schema` from `ProfileRepository.read_profile
    → ProfileSnapshot.parse`): `for_recovery(code)` (NO loaded profile) → the fresh-profile fallback
    (`has_profile: false`, `oath_shards: 0`, empty homes) + the structured `recovery_state`. The scene shows a fresh
    0-shard outpost with a recovery note.
  - **Profile-WRITE failure** (`profile_save_*` from `write_profile`): the profile was READ fine + the player earned
    REAL progress this session; only the WRITE failed → `for_recovery(code, loaded_profile)` shows the REAL totals
    (`has_profile: true`) BEHIND a retry banner — NOT a misleading 0-shard surface.
  The **scene-level test** (Epic-8 T4 — the "previously untested loaded-profile + recovery combination"): the VM
  path is already unit-tested (`test_outpost_view_model.gd::_write_failure_recovery_with_loaded_profile_shows_real_totals`),
  but no SCENE renders it — add a test that the OUTPOST SCENE/PRESENTER correctly branches on `recovery_state` and
  renders the loaded-profile real-totals-behind-retry surface (vs the fresh fallback), and that the retry affordance
  is reachable. The recovery render consumes NO RNG, runs NO command, mutates nothing (a pure read of the structured
  result — the resume-invariant discipline, mirrored on the profile side).
- **AC4 —** the G3 coupling decision is MADE + implemented (pick ONE, record it in Completion Notes):
  - **Option A (the honest as-is):** the run-summary render reads `RunSummary.profile_meta.oath_shards_earned` (which
    STAYS `0`, named in `not_yet_supported`) and shows an honest "not yet tallied" note; the AWARDED total is shown
    at the OUTPOST level via `OutpostViewModel.oath_shards` (== `profile.oath_shards`). No summary→profile coupling.
  - **Option B:** the run-summary render surfaces the awarded delta via a cross-surface read (the outpost/profile) so
    the summary itself displays the awarded total. This couples the summary render to the profile.
  Either satisfies AC4 as long as the decision is made, implemented, and the surface reads the CORRECT source
  (`profile.oath_shards` for the AWARDED total; `RunSummary.profile_meta.oath_shards_earned` STAYS `0` — do NOT wire
  the summary DTO's field to a non-zero value; that would break the 8.2/8.4 `not_yet_supported` contract + its
  pinned test). The **manual-seed warning** is a presentation READOUT of the EXISTING flags (no new field, FR28):
  when `RunSummary.is_manual_seed` is true (and thus `meta_progression_eligible` is false, lockstep), the summary
  render shows a "manual seed — no meta progression earned" banner (text+icon, not color-only); the outpost's
  start-another-descent affordance surfaces the same warning if a manual seed is being used
  (`start_run_request(...).is_manual_seed`). Verified by: a headless test that a manual-seed terminal run's summary
  reports `is_manual_seed: true` / `meta_progression_eligible: false` and the render surfaces the warning; a
  normal-seed run shows none.
- **AC-wide (the run-end→profile BRIDGE — 11.5's crux):** the live run flow must, at run end, LOAD the profile
  (`ProfileRepository.read_profile` → `ProfileSnapshot.fresh()` on `profile_not_found`), record the appropriate
  latch off the REAL terminal state (`RecordFirstDeathCommand` on a `PHASE_FAILED` run / `RecordFirstVictoryCommand`
  on a `PHASE_COMPLETED` run — each threaded with a `sequence_id > 0` from the run-level cursor), PERSIST the mutated
  profile (`ProfileRepository.write_profile`), and BUILD the outpost surface from the loaded/mutated profile + the
  terminal-run `RunSummary`. On a write failure it uses the loaded-profile recovery path (AC3). The latch record is
  ELIGIBILITY-INDEPENDENT (a manual-seed first death/victory still records the flag + shows the line — the ratified
  Option A). A DTO-only `RunSummary.build(run)` with an EMPTY events list is acceptable for the run-scoped route/
  economy facts (see the event-sourcing constraint) as long as the choice is documented. This bridge is the seam a
  headless test drives end-to-end on a verified seed (a live victory records first-victory + builds the outpost; a
  live death records first-death + builds the outpost).
- **AC-wide (invariants) —** full headless suite green (`godot --headless … test_runner.tscn`), false-PASS grep clean
  beyond the 6 documented negatives (int64-overflow ×2, malformed-JSON ×3, `invalid_node_type` ×1 — plus any NEW
  documented negative 11.5 adds, e.g. a `profile_save_*`/`unsupported_profile_schema` forcing case, which must be
  documented); `git diff --check` clean. `RunSnapshot` 23-key gate == 23; `ProfileSnapshot`/`SettingsSnapshot`
  `SCHEMA_VERSION == 1`; `RngStreamSet.required_streams()` == 7; every `tools/dump_*` seed-regression fingerprint
  byte-identical; `domain_event.gd` UNCHANGED (no new event); the DEFAULT `run_to_completion` (v0 auto-resolve)
  byte-identical.

## Tasks / Subtasks

- [ ] **Task 1 — Wire the run-end → profile bridge (AC-wide crux; AC2/AC4 depend on it)**
  - [ ] At the live run-END (after `RunOrchestrator.resolve_run_end(...)` / `resolve_boss_victory()` drives the
        terminal `RunState`), add the profile bridge the flow is missing. Read the source FIRST: `resolve_run_end`
        (`run_orchestrator.gd:774`) transitions the phase + captures the cause/outcome but touches NO profile. Decide
        the seam: extend `RunFlowController` with a `finalize_run_end()` (loads the profile, records the latch,
        persists, exposes the summary/outpost) OR add a thin `RunEndProfileBridge` RefCounted the run-end/outpost
        presenter drives. Keep the ORCHESTRATOR unchanged if possible (the run-end command family is caller-driven by
        design — 11.5 is a caller, not a new orchestrator method), OR add an additive caller method mirroring the
        8.3/8.4/8.5 caller-driven posture. Do NOT auto-wire the profile into `run_to_completion` (fingerprint safety).
  - [ ] **Load the profile fail-closed:** `ProfileRepository.read_profile()` → on `profile_not_found` start
        `ProfileSnapshot.fresh()`; on `unsupported_profile_schema` route to the AC3 load-failure recovery (do NOT
        overwrite an incompatible profile); on success read the loaded profile verbatim.
  - [ ] **Record the latch off the REAL terminal state (AC2):** a `PHASE_FAILED` run runs `RecordFirstDeathCommand.
        new(profile, sequence_id).execute(run)`; a `PHASE_COMPLETED` run runs `RecordFirstVictoryCommand.new(profile,
        sequence_id).execute(run)`. Thread `sequence_id > 0` from the run-level cursor (the `_next_sequence_id` seam
        the orchestrator threads — do NOT pass a hardcoded 1 that could collide; verify the sequence-id source). A
        subsequent death/victory rejects idempotently (`first_death_already_recorded` / `first_victory_already_
        recorded`) with ZERO mutation — that is EXPECTED, not an error (the beat simply does not re-show). The record
        is ELIGIBILITY-INDEPENDENT (a manual-seed run STILL records + shows the line — Option A).
  - [ ] **Persist the mutated profile:** `ProfileRepository.write_profile(profile)`. On success, build the outpost
        from the (mutated) loaded profile. On a `profile_save_*` write failure, build the outpost via
        `OutpostViewModel.for_recovery(code, loaded_profile)` (AC3 write-failure — real totals behind retry; the
        profile is intact in memory even though the write failed).
  - [ ] **Build the run summary:** `RunSummary.build(run, events)`. Document the `events` source: v0 has NO
        run-level event store (the orchestrator threads sequence ids but does NOT accumulate a run log — grep-verified:
        `run_events`/`board_events` are LOCAL to the boss auto-play, not run-wide). Either collect the run's ordered
        events through the flow (if a collection seam is added) OR build with an EMPTY events list (the route/economy
        run-scoped facts — nodes_cleared/boss_cleared/elite/gold/curse/corruption — derive from the terminal
        `RunState` regardless; only the passives/loot/discovery lists depend on the event list). Record the choice +
        its consequence (an empty-events summary reports empty passives/loot lists — acceptable for v0 or upgrade if
        a collection seam is cheap). Do NOT read a presentation/combat log as source truth (8.2 AC2 forbids it) and
        do NOT add a persisted event-log field to `RunState`/`RunSnapshot` (the 23-key gate stays 23).
  - [ ] **Determinism/purity guard:** the bridge draws ZERO gameplay RNG (`ZERO randi/randf/RandomNumberGenerator`);
        the record commands are ZERO-RNG deterministic flag sets; `RunSummary`/`OutpostViewModel`/the beats are pure
        reads. A test asserts the bridge is byte-deterministic on a fixed seed and mutates only the profile (not the
        run, not the streams, not any fingerprint).

- [ ] **Task 2 — Build the outpost scene + start-another-descent (AC1)**
  - [ ] Add the outpost `Control` scene (`godot/scenes/ui/outpost.tscn`) + its presenter (`godot/scripts/ui/
        presenters/outpost_presenter.gd`, mirroring `route_map_presenter`/`hero_select_presenter`'s posture: read the
        pinned VM projection, map fields to non-color visuals, submit ONLY the start request, own no truth, leak no
        live handle). It READS `OutpostViewModel.to_dictionary()` (built by Task 1's bridge from the terminal-run
        profile + summary).
  - [ ] Render the pinned surface: the meta readout (`oath_shards` + `echoes` count as number+label), the four
        `named_spaces` (each `display_name` + an EXPLICIT `deferred` marker — the visible-exception discipline, icon/
        label not color-only; do NOT silently omit a deferred space), the embedded `run_summary` sub-dict (branch on
        its `has_summary` gate — an empty summary renders "no just-ended run", not a zeroed sheet), and
        `unlock_progress` (DISPLAYED, not spent). The four-layout treatment follows appendix §14 (a scrollable stack
        on phone_portrait → a multi-panel dashboard on desktop); the descend affordance stays ≥44×44 on every
        profile.
  - [ ] Wire the start-another-descent seam (FR1 loop closure): the descend button calls
        `OutpostViewModel.start_run_request(root_seed, is_manual_seed, class_id)`; on `is_startable`, hand the request
        to a FRESH run via `RunFlowController.start(root_seed, is_manual_seed, class_id)` (the authoritative
        fail-closed `RunOrchestrator.start`), clear the terminal run-flow handle (`GameSession.clear_run_flow()` then
        seat the new controller), and navigate to `hero_select`/`route_map` per the fresh flow. A new seed → a new
        route → a new run (the prior run is NOT reused — structural via `RunState.new_run`). Decide where the descend
        seed/class come from (a default/next seed; the outpost may offer a hero re-pick via hero select, or a
        one-tap re-descend) — record the choice; do NOT reuse the terminal run's route.
  - [ ] Route the run-end return to the REAL outpost: update `RunFlowRouter._DESTINATION_STAGES` / `_STAGE_SCENES`
        (and `STAGES`) so the `outpost` destination (or a new `outpost` stage) lands on `outpost.tscn`, NOT the
        minimal `run_end.tscn` landing. Update `test_run_flow_router.gd`'s pinned route table. Decide the fate of the
        minimal `run_end_presenter`/`run_end.tscn`: either repoint the `outpost` destination straight to the outpost
        scene (retiring the minimal landing as a nav target) or keep run_end as a brief "run ended" beat that then
        navigates to the outpost — do NOT leave two competing outpost surfaces.

- [ ] **Task 3 — Render the reveal beats (AC2)**
  - [ ] Render the first-death beat from the already-embedded `OutpostViewModel.first_death_beat` sub-dict (branch on
        `has_beat`); render the first-victory beat per the AC2 decision (Option A: add a `first_victory_beat` sub-dict
        to `OutpostViewModel` + update its pinned-key test + all recovery-mode constructions; Option B: compose
        `FirstVictoryRevealBeat` in the presenter from the run-end first-victory fact). Each beat shows its resolved
        `line` (the FR61/FR62 prose — inherently non-color text) with a Skip/Dismiss control (≥44×44, always
        reachable, never off-screen on phone_portrait).
  - [ ] The Skip/Dismiss is a PURE PRESENTATION NO-OP (FR65): it stops rendering the beat and submits NO command,
        mutates NO flag (the latch was set by the record command in Task 1, independently of the display). There is
        NO "skip command". A code audit + a test confirm the skip path mutates nothing.
  - [ ] OFF THE CRITICAL PATH (FR64): a null/absent/dismissed beat NEVER blocks the outpost surface, the run summary,
        or starting another descent. The outpost renders complete with `has_beat: false` on both beats (a fresh
        profile, or a non-first death/victory). A test asserts the outpost surface + the start-descent affordance are
        reachable with both beats absent.

- [ ] **Task 4 — Profile recovery render + scene-level test (AC3)**
  - [ ] The outpost presenter branches on `OutpostViewModel.recovery_state` ({has_recovery, code, is_recoverable}):
        a healthy real/fresh profile (`has_recovery: false`) renders the normal surface; a recovery surface renders
        a clear message + affordance. Distinguish the two modes: the LOAD-failure fresh fallback (`has_profile:
        false`, 0 shards) shows a fresh 0-shard outpost + a recovery note; the WRITE-failure loaded-profile path
        (`has_profile: true`, real totals) shows the REAL totals BEHIND a retry banner. Each recovery state carries a
        text explanation + an icon (not color-only) so "profile not found" reads differently from "save failed —
        retry" (appendix §13.5). The retry affordance (≥44×44) re-attempts the profile write.
  - [ ] Add the SCENE-LEVEL test (Epic-8 T4 — "the previously untested loaded-profile + recovery combination"): the
        VM path is already unit-tested (`test_outpost_view_model.gd::_write_failure_recovery_with_loaded_profile_
        shows_real_totals`), but no SCENE renders it. Test that the OUTPOST SCENE/PRESENTER correctly branches on
        `recovery_state` + renders the loaded-profile real-totals-behind-retry surface (vs the fresh 0-shard
        fallback). Per the Epic-11 scene-free-harness constraint (below), steer the testable logic into a RefCounted
        seam the harness can run `script.new()` on (do NOT write a SceneTree test) — e.g. a thin outpost-render
        projection/decision the presenter reads, unit-tested for the recovery branch. The recovery render consumes
        NO RNG, runs NO command, mutates nothing.

- [ ] **Task 5 — Oath-Shards-earned coupling decision + manual-seed warning (AC4)**
  - [ ] MAKE + implement the G3 coupling decision (Option A honest-as-is: summary shows "not yet tallied" + the
        outpost shows the AWARDED total via `OutpostViewModel.oath_shards`; OR Option B: the summary render surfaces
        the awarded delta via a cross-surface read). Record the decision + rationale in Completion Notes. The AWARDED
        total source is `profile.oath_shards` (already-awarded state); `RunSummary.profile_meta.oath_shards_earned`
        STAYS `0`/`not_yet_supported` (do NOT wire the DTO field to a non-zero value — it breaks the 8.2/8.4
        `not_yet_supported` contract + `test_run_summary.gd`).
  - [ ] Render the manual-seed warning as a READOUT of EXISTING flags (no new field — FR28): when
        `RunSummary.is_manual_seed` is true (and `meta_progression_eligible` false, lockstep), the summary render
        shows a "manual seed — no meta progression earned" banner (text+icon, not color-only); the outpost's
        start-another-descent affordance surfaces the same warning when a manual seed is used
        (`start_run_request(...).is_manual_seed`). A normal-seed run shows no warning. Tested at the render/decision
        seam.

- [ ] **Task 6 — Invariants regression + full-suite green (AC-wide)**
  - [ ] Re-verify every durable invariant is unmoved: the 23-key `RunSnapshot` gate (`test_run_snapshot.gd`),
        `ProfileSnapshot.SCHEMA_VERSION == 1` (`test_profile_snapshot.gd` — the latches are SET, not added),
        `SettingsSnapshot.SCHEMA_VERSION == 1`, `RngStreamSet.required_streams()` == 7 (`test_rng_stream_set.gd`),
        the `DomainEvent.Type` enum tail UNCHANGED (`test_domain_event.gd` — the record commands REUSE the existing
        `first_death_recorded` / `first_victory_recorded` events; NO new event). The outpost/summary/beats are
        DERIVED reads — NO new save key.
  - [ ] Re-run every seed-regression fingerprint suite + confirm byte-identical (small/medium level, route, seed
        batch, finale). The bridge is a run-END caller (post-terminal); the GENERATOR + the DEFAULT `run_to_completion`
        stay untouched — every `tools/dump_*` fingerprint stays byte-identical.
  - [ ] Run the FULL headless suite via PowerShell (the `godot` binary is not on the Bash PATH — see Project Context
        Rules): `godot --headless --path C:\Sealsworn\godot --scene res://tests/headless/test_runner.tscn
        --quit-after 10`. Apply the false-PASS grep guard (the only acceptable stderr `ERROR:` lines are the 6
        documented negatives: int64-overflow ×2, malformed-JSON ×3, `invalid_node_type` ×1 — plus any NEW documented
        negative 11.5 adds, e.g. a `profile_save_*`/`unsupported_profile_schema`/`profile_parse_failed` forcing case,
        which MUST be documented in the story + the ledger). Run `git diff --check`.

- [ ] **Task 7 — Update the deferred-work ledger + tracking (AC-wide, hygiene)**
  - [ ] In `deferred-work.md` (new 11.5 entry): mark **RESOLVED** — the **outpost SCENE + reveal RENDER** (the fence
        carried across Epics 8/9, re-recorded by 11.2/11.3/11.4 as "the outpost SCENE + reveal RENDER + G3 (11.5)");
        the **first-victory REVEAL RENDER on the outpost** (the 9.4 AC3 render defer — "a later UI story wires the
        reveal onto `OutpostViewModel`"); the **G3 Oath-Shard EARNED-count summary↔profile coupling** (Epic-8 T5 /
        Epic-9 T4 — the coupling decision MADE + implemented); the **Epic-8 T4 loaded-profile + recovery scene-level
        test**; and the **first-death BEAT render on the outpost scene** (8.5/8.6 shipped the beat DATA; 11.5 renders
        it). RE-RECORD still-open (NOT 11.5's): the **meta-SPEND / unlock APPLICATION** (11.6 — the spend menu +
        `unlock_progress` → selectability flip + `AwardMetaProgressCommand`/`MergeRunDiscoveriesCommand` GRANT); the
        **live in-node board / pending-fight SAVE** (a later in-node-save story — the 23-key gate stays 23); **G4 the
        settings view model** (if 11.5 does not build a settings scene, RE-RECORD it PARKED — the settings-scene owner
        is 11.3-or-11.5 per the eventual split; 11.5 may leave it parked). Note the originating story/date. Do NOT
        reopen or re-defer items unrelated to this story's surface.

## Dev Notes

### What this story is (and is not)

Epic 8 shipped the outpost/summary/first-death DATA (`OutpostViewModel` + `RunSummary` + `FirstDeathNarrativeBeat` +
`ProfileRepository`/`ProfileSnapshot` + the run-end command family) as pure `RefCounted` surfaces, and 9.4 added the
first-victory twin — all UI-scene-last, all "a later HUD/boot-flow story renders them." 11.3 built the on-screen
run-flow shell + a MINIMAL run-end landing (`run_end_presenter`, which reads only `RunEndOutcome`). **11.5 is the
outpost-scene story: it renders the `OutpostViewModel` contract on a real scene, renders the two reveal beats + the
manual-seed warning, and — crucially — wires the run-end→profile BRIDGE the live flow is missing (load profile →
record the first-death/victory latch → persist → build the outpost + summary), closing the FR1 loop with a working
"start another descent."**

**The single most important rule: RENDER + WIRE THE EXISTING SURFACES; do not fork a parallel outpost/summary path.**
Every DTO already exists (enumerated in the seam map). Read the ACTUAL source before wiring — a wrong method/
constant/pinned-key name is the primary review-cycle cause (the 11.1 Round-1 review caught an HP field mis-sourced on
`RunState`; the 11.3 Round-2 review caught a dead `has_method("current_text_scale")` probe that read as "wired" but
no-op'd). Cite the EXACT as-built method/const/key names, verified against source; grep every probed method name
against source before trusting a guarded-accessor claim.

### The crux (read the source): the run-end → profile bridge does NOT exist yet

The live run flow (11.2/11.3) drives the run to a terminal `RunState` and emits `run_completed`/`run_failed`, but the
**profile side is entirely unwired**:

- `RunOrchestrator.resolve_run_end(outcome)` (`run_orchestrator.gd:774`) runs `CompleteRunCommand`, captures the
  next-destination + cause/outcome, and returns — it imports NO `ProfileRepository`, NO `RecordFirstDeathCommand`, NO
  `RecordFirstVictoryCommand`, NO `RunSummary`, NO `OutpostViewModel` (grep-verified: 0 references in the whole
  `run_orchestrator.gd`). After a live run ends, **no profile is read, no first-death/victory latch is set, and no
  outpost surface can be built.**
- `RunFlowController` exposes `run()` / `orchestrator()` / `run_end_outcome()` — but NO summary/profile/beat seam.
- `run_end_presenter` reads only `RunEndOutcome` (phase/cause/eligibility) — it builds no summary and no profile.

So 11.5's Task 1 is the load-bearing new work: at the live run-END, LOAD the profile
(`ProfileRepository.read_profile` → `ProfileSnapshot.fresh()` on `profile_not_found`), RECORD the appropriate latch
off the REAL terminal state (`RecordFirstDeathCommand`/`RecordFirstVictoryCommand`, threaded with a `sequence_id > 0`
from the run-level cursor), PERSIST (`ProfileRepository.write_profile`, handling the AC3 write-failure recovery), and
BUILD the outpost + summary from the loaded/mutated profile + the terminal `RunState`. The record commands are
CALLER-DRIVEN by design (the 8.3/8.4/8.5/9.4 posture — "NOT auto-wired into `run_to_completion`; the caller drives
them behind the run-end seam"); 11.5 IS that caller. Keep the orchestrator unchanged (or add ONE additive caller
method); do NOT auto-wire the profile into `run_to_completion` (fingerprint safety — the default v0 auto-resolve must
stay byte-identical).

### The event-sourcing constraint (RunSummary.events)

`RunSummary.build(run, events)` derives its passives/loot/discovery lists from the SUPPLIED ordered `events` list —
but **v0 has NO run-level event store.** The orchestrator threads sequence ids and RETURNS events in each command's
`ActionResult.events`, but does NOT accumulate a run-wide log (the `run_events`/`board_events` accumulators are LOCAL
to `_auto_play_boss_rounds`, the boss auto-play — not run-wide; grep-verified). The 11.3 live flow drives node-by-node
and discards intermediate `ActionResult.events`. So 11.5 must decide: (a) build the summary with an EMPTY events list
(the route/economy run-scoped facts — nodes_cleared/boss_cleared/elite/gold/curse/corruption — still populate from the
terminal `RunState`; only passives_consumed/passives_destroyed/notable_loot/echoes_discovered/unlock_progress come out
empty), OR (b) add a lightweight event-collection seam through the flow (thread the run's ordered events into the
bridge). Option (a) is the minimal, defensible v0 choice (the summary's headline facts — victory/death, nodes
cleared, boss/elite progress, gold/curse/corruption — all populate; the empty passive/loot lists are an honest v0
limitation, NOT a bug). Record the choice. Do NOT read a presentation/combat log as source truth (8.2 AC2 forbids it),
and do NOT add a persisted event-log field to `RunState`/`RunSnapshot` (the 23-key gate stays 23; a persisted summary
is a later save-shape story).

### The G3 decision + the first-victory render decision (the two deferrals 11.5 OWNS + resolves)

The 11.1 appendix (§8.3, §16 G3) and the deferred-work ledger both assign TWO carried decisions to 11.5:

- **G3 — Oath-Shards-earned summary↔profile coupling (carried Epic-8 T5 / Epic-9 T4):** `RunSummary.profile_meta.
  oath_shards_earned` reports `0` (named in `not_yet_supported`); the AWARDED total lives on `profile.oath_shards`
  (surfaced via `OutpostViewModel.oath_shards`). The coupling decision — display the awarded total ON the summary vs
  surface it via the outpost — is 11.5 AC4. Both options are documented in AC4 above; MAKE the call, implement it,
  and record it. The load-bearing constraint: the AWARDED source is `profile.oath_shards`;
  `RunSummary.profile_meta.oath_shards_earned` STAYS `0` (wiring the DTO field non-zero breaks the 8.2/8.4
  `not_yet_supported` pinned contract).
- **First-victory reveal render (the 9.4 AC3 render `[Decision]`):** `OutpostViewModel` embeds `first_death_beat`
  but NOT a first-victory beat — 9.4 explicitly deferred wiring the first-victory reveal onto `OutpostViewModel` to
  "a later UI story" = 11.5. The AC2 decision (Option A: add a `first_victory_beat` sub-dict to `OutpostViewModel`;
  Option B: compose `FirstVictoryRevealBeat` in the presenter) resolves it. Record the call.

### Project Context Rules

Extracted from `project-context.md` (the canonical AI rulebook) — the rules that BIND 11.5's implementation:

- **Presentation observes; it owns no tactical truth.** Godot scenes / `Control` nodes / audio / VFX / animation are
  presentation; the scene-independent domain model owns tactical truth. The outpost scene READS view-model
  projections and SUBMITS intent (the start request) through the existing seam; it never mutates domain/profile state
  directly. Use signals for UI feedback, not hidden domain control flow.
- **Commands validate before mutation and return `ActionResult`; successful commands emit deterministic past-tense
  `DomainEvent` records.** The record commands (`RecordFirstDeathCommand`/`RecordFirstVictoryCommand`) are the ONLY
  profile mutators 11.5 drives; they validate-then-mutate with ZERO events on reject. No new command, no new event.
- **Named RNG streams only; ZERO `randi`/`randf`/`RandomNumberGenerator`.** The bridge + the reads are ZERO-RNG
  deterministic. Cosmetic randomness (none here) must not affect outcomes.
- **Headless simulation is a first-class target; it runs without rendering/audio/UI scenes/presentation nodes/
  scene-tree-only state.** The scene-free headless harness runs `script.new().run()` with NO SceneTree — see the
  scene-free-harness constraint below.
- **Save truth is versioned domain snapshots.** `ProfileSnapshot.SCHEMA_VERSION == 1` (do NOT bump — both latches
  have homes); the 23-key `RunSnapshot` gate stays 23; snapshots are pure reads (composing/restoring consumes no RNG,
  runs no command, advances no turn, mutates neither source nor save file). JSON int64 fields (root_seed) stay
  decimal-string-encoded.
- **Repositories own atomic writes + structured read/write errors.** `ProfileRepository` writes atomically
  (temp→backup→replace) and returns structured codes; read errors are `ActionResult` codes, NOT exceptions; a real
  parse-failure path emits one expected `ERROR: Parse JSON failed` stderr line and STILL returns a structured error
  (read the CODE as truth, not stderr).
- **Autoloads stay thin.** `SceneManager`/`GameSession`/`SaveManager` delegate; they own no run/profile logic. A new
  registered autoload is out of scope (Epics 8-9 added none).
- **Manual seed/debug runs must not grant meta progression (FR28)** — the manual-seed warning is a READOUT of the
  existing eligibility flags; the first-death/victory NARRATIVE latch is eligibility-INDEPENDENT (Option A — a
  narrative flag is not "granting meta progression").
- **Difficulty is a hard non-goal.** No difficulty knob/selector anywhere (the outpost/settings surfaces must not
  present one).
- **Godot binary path (this machine):** `godot` is NOT on the Bash/`where` PATH — it resolves as
  `C:\Users\Rasmus\bin\godot.cmd` via PowerShell. Run the headless suite through PowerShell (`powershell.exe
  -NoProfile -Command ...`), not the Bash tool's PATH lookup. Apply the false-PASS grep guard.

### Epic-11 retro constraints that BIND 11.5 (from `_bmad-output/auto-gds/retro-notes/epic-11.md`)

These are ratified conventions from earlier Epic-11 stories — 11.5 MUST honor them:

- **The scene-free headless harness has NO SceneTree (G1/G2 posture, ratified by 11.3/11.4).** The runner runs
  `script.new().run()` — a `.tscn`/`Control` surface is NOT directly unit-testable by the current runner (11.3's
  finding). Steer ALL testable logic into fail-closed `RefCounted` view-model/projection seams (as 11.3 did with the
  G1 `RunHudViewModel` + G2 `RouteMapViewModel`, and 11.4 with `LiveAffinityReadModel`); verify scene wiring BY
  CONSTRUCTION (the scene-load compile guardrail `test_run_flow_scenes_load.gd` + the read-only-projection
  discipline). **DO NOT write SceneTree tests.** For AC1/AC3's scene-level assertions, put the render DECISION/
  projection in a RefCounted seam the harness can construct + assert (e.g. the outpost render branches on the pinned
  `OutpostViewModel`/`recovery_state` keys — test THAT). Reviewers should not expect SceneTree tests; the AC3
  "scene-level test" is satisfied by a RefCounted render-decision test + the scene-load compile guardrail covering
  `outpost.tscn`.
- **Pinned-key / source-verification rigor (dead `has_method` probes bit this epic TWICE).** Grep every probed
  method/const/key name against source before trusting a guarded-accessor claim (the 11.3 M2 dead
  `has_method("current_text_scale")` probe; the 11.1 `range` vs `weapon_reach` key mix-up). Cite the EXACT as-built
  `OutpostViewModel.DICTIONARY_KEYS` / `RunSummary.DICTIONARY_KEYS` / the beats' `DICTIONARY_KEYS` / `for_recovery`
  signature / `start_run_request` shape — all verified in this story's seam map against source. A key outside a
  pinned set is a contract violation.
- **When a presenter re-implements a sequencing the domain already encodes, test the presenter's shared sequencing
  seam (11.3 H1: the on-screen advance-then-resolve silently diverged from the tested resolve-then-advance driver).**
  11.5's run-end→profile bridge RE-IMPLEMENTS the run-end command SEQUENCING (load → record latch → persist → build
  summary/outpost) at the presenter/flow layer. Test the SHARED bridge seam (a RefCounted `finalize`/bridge method),
  not just the individual commands — so the on-screen order (record-then-build, off the REAL terminal state) is
  proven to match the domain's intended order and never builds the outpost off a stale/un-persisted profile.

### Deferred-work ledger items that OVERLAP 11.5 (from `_bmad-output/implementation-artifacts/deferred-work.md`)

Only the entries whose subject overlaps 11.5's area — folded in so the dev agent addresses or knowingly works around
them (the rest of the ledger is out of scope):

- **[Resolve in 11.5] The outpost SCENE + reveal RENDER + G3** — re-recorded by 11.2/11.3/11.4 (dev-of-11.2 line ~75:
  "Stories 11.5/11.6 The outpost SCENE + reveal RENDER (11.5)"; dev-of-11.3 line ~55: "Story 11.5 The outpost SCENE +
  the reveal RENDERS + the G3 summary↔profile coupling — 11.3's run-end return NAVIGATES to the outpost destination
  (a MINIMAL run-end landing) but the polished `OutpostViewModel`-bound dashboard, the first-death/first-victory
  reveal beats, and the deferred named-space tiles are 11.5's; 11.3's landing does not pre-empt them"; dev-of-11.4
  line ~14). 11.5's Tasks 1-5 discharge this.
- **[Resolve in 11.5] The first-victory REVEAL RENDER on the outpost** (dev-of-9.4 line ~124; review-of-9.4 line
  ~120's AC3 render `[Decision]`): "the DTO + flag + event exist; the outpost-scene render of the reveal (alongside
  the first-death beat) is deferred … a later UI story wires the reveal onto `OutpostViewModel`." AC2 + Task 3
  resolve it (the first-victory render decision).
- **[Resolve in 11.5] The G3 Oath-Shard EARNED-count summary wiring** (review-of-8.6 line ~173; review-of-8.7 line
  ~155; the 8.3 feed line ~427-429): "`RunSummary.profile_meta.oath_shards_earned` stays 0/not-yet-supported;
  coupling the summary to the profile is a bigger design decision … the outpost reads the AWARDED total from
  `profile.oath_shards`." AC4 + Task 5 MAKE + implement the coupling decision.
- **[Resolve in 11.5] The first-death BEAT RENDER on the outpost scene** (dev-of-8.5 line ~235; review-of-8.5 line
  ~194): "8.5 ships only the `FirstDeathNarrativeBeat` DATA + the `first_death_recorded` event; 8.6 owns the outpost
  render + the skip/dismiss control (UI-scene-last)." 8.6 shipped the VM EMBED (`OutpostViewModel.first_death_beat`);
  11.5 renders it on the scene (Task 3). The skip is ALREADY a structural no-op (the DTO is read-only; the flag is
  set independently).
- **[Resolve in 11.5 — the scene-level test] Epic-8 T4: the loaded-profile + recovery combination** (11.5 AC3 verbatim
  + `test_outpost_view_model.gd` line ~589-616): the VM path (`for_recovery(code, loaded_profile)` → real totals
  behind retry) is UNIT-tested, but NO scene renders it. Task 4 adds the scene-level (RefCounted render-decision)
  test.
- **[RE-RECORD still-open — NOT 11.5's] The meta-SPEND / unlock APPLICATION (11.6)** (dev-of-11.3 line ~56;
  review-of-8.7 line ~154): the spend menu + `unlock_progress` → class-selectability flip (FR43) +
  `AwardMetaProgressCommand`/`MergeRunDiscoveriesCommand` GRANT are 11.6's end-to-end scope. 11.5 DISPLAYS the meta
  totals + `unlock_progress`; it does NOT spend or apply. Do NOT reopen or pre-empt this.
- **[RE-RECORD still-open — NOT 11.5's] The live in-node board / pending-fight SAVE** (dev-of-11.3 line ~57): the
  in-node fight state stays ephemeral (the 23-key gate stays 23); a mid-encounter save is a later in-node-save story.
- **[RE-RECORD PARKED — the settings-scene owner is 11.3-or-11.5] G4 — the settings view model** (dev-of-11.3 line
  ~58; appendix §16 G4): 11.3 built no settings scene, so G4 stays PARKED. If 11.5 does not build a settings scene,
  RE-RECORD it PARKED (do NOT silently close it). The outpost/settings surfaces must NOT present a difficulty selector
  (the ratified hard non-goal, appendix §12.3).

### The 11.1 appendix screen contracts 11.5 implements (source of the paper design)

`_bmad-output/planning-artifacts/ux-appendix-run-flow.md` (the settled paper design 11.5 builds against):

- **§7 Outpost / meta menu** — binds `OutpostViewModel.to_dictionary()` (pinned `DICTIONARY_KEYS`). The four named
  spaces all carry `status: "deferred"` in v0 (render each with an explicit "deferred" marker, never silently omit);
  only `descent_stair` maps to a live v0 affordance (start-another-descent). §7.4: a scrollable stack on phone →
  a multi-panel dashboard on desktop; deferred spaces carry a label/icon "coming soon" marker (not color-only);
  descend ≥44×44.
- **§8 Run summary** — binds `RunSummary.to_dictionary()`; §8.3 documents the G3 coupling options (AC4). §8.5:
  outcome (victory vs death) via label+icon (not color-only); the manual-seed warning is a labeled banner, not a
  color tint.
- **§9 First-death reveal** / **§10 First-victory reveal** — bind `FirstDeathNarrativeBeat` / `FirstVictoryRevealBeat`
  (identical pinned shape). §9.3/§10.3: the skip/dismiss is STRUCTURALLY a pure no-op (the flag is set by a SEPARATE
  command); OFF THE CRITICAL PATH (§9.3/FR64 — never blocks the summary/outpost/another descent). §9.5/§10.5: a
  skippable overlay/card; the Skip control ≥44×44 and always reachable; the line is text (inherently non-color); no
  timing/reflex requirement.
- **§11 Manual-seed no-progression warning** — binds `RunSummary.is_manual_seed`/`meta_progression_eligible` +
  `start_run_request(...).is_manual_seed`; adds NO new field (FR28); a labeled banner (text+icon).
- **§13 Save/resume recovery — the PROFILE recovery half** — §13.2 mode 1 (profile-LOAD failure → fresh-profile
  fallback, `for_recovery(code)`) + mode 2 (profile-WRITE failure → real totals behind retry, `for_recovery(code,
  loaded_profile)`). §13.5: each recovery state carries a text explanation + an icon (not color-only); action buttons
  ≥44×44. (The RUN-side resume recovery is 11.3's `RunResumeRecoveryView`; the PROFILE side is 11.5's.)
- **§14 Layout + accessibility** — every screen: four-layout (phone_portrait primary → phone_landscape side-rail →
  tablet → desktop) honoring the semantic `TacticalLayoutProfile` region plan; color-independence (every critical
  meaning carries a non-color channel — shape/icon/label/pattern/text); scalable text (`TacticalTextScale` clamp
  [0.85, 2.0], driven by `SettingsSnapshot.text_scale`; changing scale never alters gameplay).

### Project Structure Notes

- Production Godot code under `godot/`; UI presenters under `godot/scripts/ui/presenters/`; view models under
  `godot/scripts/ui/view_models/`; run domain under `godot/scripts/run/`; save under `godot/scripts/save/`; scenes
  under `godot/scenes/ui/`. Tests mirror the domain under `godot/tests/` (`unit/ui/`, `unit/run/`, `integration/…`).
- New files 11.5 likely adds: `godot/scenes/ui/outpost.tscn`, `godot/scripts/ui/presenters/outpost_presenter.gd`, a
  run-end→profile bridge seam (extend `RunFlowController` OR a new `godot/scripts/ui/flow/run_end_profile_bridge.gd`),
  and tests (`godot/tests/unit/ui/test_outpost_*` render-decision + a run-end→profile bridge test). Update the pinned
  `test_run_flow_router.gd` (new outpost stage/route), `test_run_flow_scenes_load.gd` (new outpost scene), and — if
  Option A for the first-victory embed — `test_outpost_view_model.gd` (the pinned-key set + recovery constructions).
- Naming: `snake_case` files/folders, `PascalCase` classes, `snake_case` funcs/vars/signals, `UPPER_SNAKE_CASE`
  consts. Match the 11.3 presenter posture verbatim.

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Story 11.5] — the 4 ACs (lines ~2697-2723) + the Epic-11
  FR-coverage/implementation notes.
- [Source: _bmad-output/planning-artifacts/ux-appendix-run-flow.md] — §7 (outpost), §8 (run summary + G3 §8.3), §9/§10
  (reveal beats), §11 (manual-seed warning), §13.2 (profile recovery modes), §14 (layout+accessibility), §16 G3.
- [Source: godot/scripts/ui/view_models/outpost_view_model.gd] — pinned `DICTIONARY_KEYS`; `for_recovery`;
  `start_run_request`; embeds `first_death_beat` (NOT first-victory).
- [Source: godot/scripts/run/run_summary.gd] — pinned `DICTIONARY_KEYS`/`RUN_SCOPED_KEYS`; `build(run, events)`;
  `profile_meta.oath_shards_earned == 0` / `not_yet_supported`.
- [Source: godot/scripts/run/first_death_narrative_beat.gd] + [Source: godot/scripts/run/first_victory_reveal_beat.gd]
  — pinned `DICTIONARY_KEYS`; the FR61/FR62 lines; skip is structural.
- [Source: godot/scripts/core/commands/record_first_victory_command.gd] + record_first_death_command.gd — the
  caller-driven latch commands (`_init(profile, sequence_id)`, `execute(terminal RunState)`, eligibility-independent
  Option A).
- [Source: godot/scripts/save/profile_repository.gd] — `read_profile` (`profile_not_found` → fresh) / `write_profile`
  (atomic; `profile_save_*` codes); NO `SaveManager` delegator.
- [Source: godot/scripts/run/run_orchestrator.gd:774,817] — `resolve_run_end` / `resolve_boss_victory` (NO profile/
  summary/outpost references — the bridge is absent).
- [Source: godot/scripts/ui/flow/run_flow_controller.gd] + run_flow_router.gd + scene_manager.gd + game_session.gd —
  the 11.3 scene-flow scaffolding 11.5 extends (the `outpost` destination → `run_end` route to repoint).
- [Source: godot/scripts/ui/presenters/run_end_presenter.gd] — the minimal 11.3 landing 11.5 replaces/repoints.
- [Source: godot/scripts/ui/view_models/run_resume_recovery_view.gd] — the RUN-side resume recovery (the SPLIT: the
  PROFILE recovery is 11.5's).
- [Source: _bmad-output/auto-gds/retro-notes/epic-11.md] — the scene-free-harness / pinned-key / presenter-sequencing
  constraints.
- [Source: _bmad-output/implementation-artifacts/deferred-work.md] — the 11.5-overlapping deferrals (outpost scene +
  reveal + G3 + Epic-8 T4/T5 + Epic-9 T4).
- [Source: project-context.md] — the canonical AI rulebook (presentation/command/RNG/save/repository/autoload rules).

## Dev Agent Record

### Agent Model Used

<!-- populated by dev-story -->

### Debug Log References

### Completion Notes List

### File List
