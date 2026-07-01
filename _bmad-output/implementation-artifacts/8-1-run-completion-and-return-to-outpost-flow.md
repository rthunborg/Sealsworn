# Story 8.1: Run Completion and Return-to-Outpost Flow

Status: review

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a player,
I want death or completion to return me to the last outpost,
so that each run clearly closes and the next descent can begin.

## Acceptance Criteria

(Verbatim from `planning-artifacts/epics.md` lines 2021-2042, Story 8.1; FR32 — "MVP loss condition must be hero death during a level, event, or boss encounter followed by return to the last outpost." The FIRST story of Epic 8 — "Outpost, Meta Progression, and Run Summary." It establishes the run-END resolution layer: a run that DIES enters the FAILED state with a cause, a run that COMPLETES enters the COMPLETED state, BOTH route the next app flow to the outpost, and a double-completion is idempotent / cannot double-grant. Builds DIRECTLY on the Epic-4 run-progression machine — `RunState`'s `PHASE_COMPLETED`/`PHASE_FAILED` phases + transition table already exist; the `run_completed` event already exists (4.5, emitted at the boss boundary with `outcome == "boss_placeholder"`); the `RunOrchestrator` start-to-end driver already auto-resolves combat to success. 8.1 is the FIRST story to actually DRIVE the FAILED path and to make the run-END an explicit, idempotent, outpost-bound boundary. It does NOT yet build the run summary (8.2), the meta profile / Oath-Shard awarding (8.3), or the outpost menu scene (8.6).)

**AC1 — Death enters FAILED, emits a run-failed event with cause, and routes to the outpost**
- **Given** the hero dies during a level, event, or boss encounter
- **When** run completion resolves
- **Then** the run enters failed state and emits a run-failed event with cause
- **And** the next app flow destination is the outpost.

**AC2 — Completion/victory enters COMPLETED, emits a run-completed event, and routes to the outpost**
- **Given** the run reaches a completion or victory path
- **When** run completion resolves
- **Then** the run enters completed state and emits a run-completed event
- **And** the next app flow destination is the outpost.

**AC3 — Re-completing an already-ended run is idempotent / a stable error, and does not double-grant**
- **Given** a run has already completed or failed
- **When** completion is requested again
- **Then** it returns a stable error or idempotent result
- **And** rewards or progression are not granted twice.

## Scope boundary (read FIRST)

This story closes the **RUN-END boundary**: it makes a run that the hero LOSES (death) resolve to `PHASE_FAILED` with an emitted **run-failed event carrying a cause**, makes a run that COMPLETES/wins resolve to `PHASE_COMPLETED` with a **run-completed event**, makes BOTH carry an explicit **"next destination = outpost"** flow signal, and makes a SECOND completion request on an already-ended run **idempotent (or a stable error) that does NOT double-grant**. It is the first half of FR32 (death → return to outpost) and the run-end half of Epic 8's "die or finish a run, return to the last outpost."

**⭐ THE SINGLE MOST IMPORTANT ARCHITECTURAL FACT — the run-END machinery ALREADY EXISTS; 8.1 EXTENDS it, it does NOT reinvent it.** The Epic-4 run-progression model already ships:
- `RunState.PHASE_COMPLETED` + `RunState.PHASE_FAILED` (the two terminal phases) and the transition table that ALREADY allows `ACTIVE_ROUTE → FAILED` and `NODE_RESOLUTION → {COMPLETED, FAILED}` (`RunState._legal_next_phases`, lines 550-565). `is_terminal()` already returns true for both. **`PHASE_FAILED` is reachable in the transition table but NO command drives it yet** — combat auto-resolves to success in the orchestrator, so today a run can only ever reach `COMPLETED` (via the boss). 8.1 is the FIRST story to drive `PHASE_FAILED`.
- `run_completed` (the `DomainEvent.Type.RUN_COMPLETED` event) already exists (4.5) — but it is HARDWIRED to the boss-placeholder path: its payload validator (`_validate_run_completed_payload`, `domain_event.gd` lines 938-952) asserts `outcome` is **value-equal to the exact `boss_placeholder` marker** (`RUN_COMPLETED_OUTCOME_BOSS_PLACEHOLDER`). To satisfy AC2's "completion or victory path" the completion-outcome vocabulary must be BROADENED (add a `victory`/`completed` outcome) WITHOUT breaking the boss boundary the orchestrator + Epic 9 depend on.
- There is **NO run-FAILED event anywhere.** `LEVEL_DEFEAT_REACHED` exists at the TACTICAL/board layer (`combat_outcome_evaluator.gd` / `board_state.gd`) — that is per-LEVEL combat defeat, NOT run-level failure. 8.1 adds the RUN-level failed event (appended at the enum end), carrying a CAUSE.

**`[Decision]` — THE RECOMMENDED DISPOSITION (confirm in Completion Notes):** model run-END resolution as run-domain command(s) following the established **4.3 run-command idiom verbatim** (take the live `RunState` DIRECTLY; reject `sequence_id <= 0` FIRST; validate-then-mutate; ZERO events + byte-identical no-mutation `RunState` on any reject; build the event ONLY after the transition succeeds). The cleanest shape — pick one and record it:
- **(A, RECOMMENDED) A single `CompleteRunCommand`** that takes an explicit OUTCOME (a death cause OR a completion/victory marker) + a `sequence_id`, validates the run is non-terminal and the requested transition is legal, transitions to `FAILED` (death) or `COMPLETED` (completion/victory), and emits the matching `run_failed` / `run_completed` event. A re-completion on an already-terminal run is rejected with a stable `run_already_terminal` code (or returns an idempotent no-op ok carrying the existing terminal outcome — pick one and pin it; AC3 allows either "stable error OR idempotent result"). This unifies both endings behind one validate-then-mutate seam and mirrors `NodeResolvePlaceholderCommand`'s boss path.
- **(B) Two sibling commands** (`FailRunCommand` + a completion path) if a single command's outcome-branching reads worse. Either is acceptable; the load-bearing requirement is the 4.3 idiom + the idempotency guard + the cause/outcome fields + the outpost flow signal.

Whatever you choose: the failed/completed RESOLUTION is a run-domain COMMAND under `godot/scripts/core/commands/` (NOT under `scripts/run/`), and the orchestrator may grow a thin dispatch method (mirroring `_resolve_boss`) that CALLS it — but do NOT auto-wire a death path into `run_to_completion`'s auto-resolve loop in a way that perturbs the existing interrupted==uninterrupted determinism / the v0 combat-auto-resolve posture (there is no live combat that can produce a death yet — see OUT of scope).

**The "next app destination = outpost" flow signal (AC1/AC2 "the next app flow destination is the outpost"):** this is a DOMAIN-level flow fact, NOT a scene transition. v0 has NO outpost scene (8.6 owns it) and NO app-flow state machine wired to scenes. Model the destination as a stable, readable DOMAIN signal — `[Decision]` pick ONE and record it:
- carry a stable `next_destination`/`return_destination` field (value `outpost`, a lower_snake marker constant) on the command's `ActionResult.metadata` AND/OR on the emitted event payload, so a later boot/app-flow layer (8.6) reads it; OR
- a tiny scene-free `RunEndOutcome`/read DTO (mirroring the scene-free view-model pattern) that surfaces `{ phase, outcome_or_cause, next_destination: "outpost", meta_progression_eligible }`.
Do NOT build an app-flow `SceneManager` transition or an outpost `.tscn` (8.6 / UI-scene-last). The destination is a DATA fact the run-end produces; presentation consumes it later.

Do NOT redefine the established patterns — EXTEND them. 8.1 reuses: the `RunState` phase machine + transition table (the `FAILED`/`COMPLETED` edges already exist — drive them, do not add edges unless an AC genuinely needs one; record WHY if you do); the 4.3 run-command idiom; the append-only `DomainEvent.Type` enum + the end-to-end event-wiring discipline (factory + per-event payload validator + both id maps + JSON round-trip + per-field malformed-negative tests + the `expected_ids` exhaustive pin); the existing `run_completed` event (broadened, not replaced); the boss boundary in `NodeResolvePlaceholderCommand._resolve_boss` (Epic 9 swaps the boss's pre-completion behavior at the SAME boundary — do NOT change the boundary, the route model, or the `run_completed` event shape in a way that breaks that contract); the `meta_progression_eligible` / `RiskEconomyState.oath_shard_eligible` run-end facts (READ them for the flow signal — 8.1 does NOT award anything); the 23-key `RunSnapshot` gate; the named-RNG rule (run-end resolution draws ZERO RNG — it is a deterministic phase transition + event, no roll); the difficulty-non-goal guard.

---

### ⭐ AC2: broaden `run_completed.outcome` WITHOUT breaking the boss boundary (the load-bearing extension)

`run_completed` exists but its validator pins `outcome == "boss_placeholder"` (the EXACT value, mirroring `level_victory_reached`'s `outcome == "victory"` value-equality). AC2 needs a run-completed event for a real "completion or victory path." Two clean options — `[Decision]` pick one and record it:
- **(A, RECOMMENDED) ADD a second allowed completion-outcome marker** to the `run_completed` validator (e.g. a `victory` or `completed` lower_snake constant alongside `boss_placeholder`), so the validator accepts an ALLOWLIST of completion outcomes (boss-placeholder OR victory/completed) rather than a single hardcoded value. Add the new outcome as a `const RUN_COMPLETED_OUTCOME_*` in `domain_event.gd` (the lockstep-marker pattern the boss path uses). This keeps the boss path's Epic-9 CONTRACT (`outcome == "boss_placeholder"` + `boss_node_id`) intact — its existing test stays green — and lets 8.1's completion path emit `outcome == "victory"`/`"completed"`. (NOTE: the implemented flow signal additively adds a backward-compatible `next_destination: "outpost"` key to the boss `run_completed` payload — the boss payload is not byte-identical, but the contract surface is; see the AC2 Dev Note correction and the resolved boss-payload `[Review][Decision]`.)
- **(B)** Reuse `boss_placeholder` for 8.1's completion if 8.1's completion IS the boss-resolve path. But AC2 says "completion OR victory path" generically, and FR31/Epic 9 own the real boss VICTORY — so a generic completion outcome distinct from the placeholder is cleaner and forward-compatible. RECOMMENDED: (A).

Either way: do NOT renumber the enum, do NOT change the boss's `boss_placeholder` value, and keep `_validate_run_completed_payload`'s `boss_node_id`/`cleared_node_count` field checks intact (or make them optional for a non-boss completion — record the shape decision; a non-boss completion may not have a `boss_node_id`, so the validator must tolerate its absence for a non-boss outcome WITHOUT weakening the boss path's required fields).

---

### ⭐ AC1: the run-FAILED event + the CAUSE (the brand-new event — append-only, end-to-end, expected-ids pin)

There is no run-failed event. 8.1 adds it (RECOMMENDED id `run_failed`, `DomainEvent.Type.RUN_FAILED`), appended AFTER the current last enum member (`EVENT_RESOLVED`), NEVER renumbered, and wired end-to-end exactly like every Epic-6/7 SYSTEM event:
- factory `DomainEvent.run_failed(sequence_id, payload)` (a SYSTEM event — no actor; defensively normalize/duplicate the payload, mirroring `run_completed`);
- a per-event payload validator (`_validate_run_failed_payload`) asserting the CAUSE field (a stable lower_snake cause code — e.g. `cause` ∈ an allowlist like `hero_death` / `level_defeat` / `boss_defeat` / `abandoned`, OR a free lower_snake cause string; pick the shape and pin the allowlist if you use one) + any other fields (e.g. a `node_id`/`node_type` where the death occurred, hyphenated → plain non-empty string; `cleared_node_count` if you carry it — non-negative integral);
- both id maps (`id_for_type` + `type_for_id`, round-trip);
- the JSON round-trip + per-field malformed-negative tests (the `test_domain_event.gd` per-event test pattern);
- **⭐ the `expected_ids` EXHAUSTIVENESS PIN.** `test_domain_event.gd::_event_identifiers_are_stable_machine_ids` (lines 1947-2005) now asserts `expected_ids.size() == DomainEvent.Type.size() - 1` AND iterates every non-`UNKNOWN` enum member asserting it is a pinned key (the Story-7.1 / retro-T3 hardening). **Appending `RUN_FAILED` (and any other new event) WILL make this gate FAIL LOUD until you add the new member to the `expected_ids` map in the SAME change — THIS IS EXPECTED.** Add `DomainEvent.Type.RUN_FAILED: &"run_failed"` (and any other new event) to that map. This is precisely the epic-transition heads-up: the exhaustiveness gate fires on the new event by design; register it, do not work around it.

The CAUSE (AC1 "a run-failed event with cause"): v0 has no live combat that produces a death (combat auto-resolves to success — OUT of scope to build the live loop). So 8.1's failed path is **caller-driven / command-driven with an EXPLICIT cause** (the caller/command supplies the cause — e.g. a test or a later HUD/run-flow story that owns the live death). Model the cause as a stable, readable marker. Do NOT invent a live-combat death detector in the orchestrator's auto-resolve loop.

---

**IN scope (this story):**
1. **A run-END resolution command (the 4.3 idiom)** — `CompleteRunCommand` (RECOMMENDED single command, outcome-parameterized) OR sibling fail/complete commands under `godot/scripts/core/commands/`. Takes the live `RunState` directly; rejects `sequence_id <= 0` FIRST; validate-then-mutate; ZERO events + byte-identical no-mutation `RunState` on reject; builds the event ONLY after the (legal) phase transition succeeds. Death → `PHASE_FAILED` + `run_failed` (with cause); completion/victory → `PHASE_COMPLETED` + `run_completed` (broadened outcome). Draws ZERO RNG. [Source: `godot/scripts/core/commands/node_resolve_placeholder_command.gd` (the 4.3 idiom + the boss `_resolve_boss` transition+event pattern); `godot/scripts/run/run_state.gd` `transition_to`/`_legal_next_phases`/`is_terminal`]
2. **The `run_failed` SYSTEM event (NEW, appended at the enum end, with CAUSE)** — `DomainEvent.Type.RUN_FAILED` + `run_failed(...)` factory + `_validate_run_failed_payload` + both id maps + the `expected_ids` pin update + JSON round-trip + per-field malformed-negative tests. Carries a stable lower_snake CAUSE (AC1). [Source: `godot/scripts/core/events/domain_event.gd` (the append-only SYSTEM-event pattern — `run_completed` at lines 232-246, `_validate_run_completed_payload` at 938-952, `expected_ids` consumers); `godot/tests/unit/core/test_domain_event.gd` lines 1947-2005 (the exhaustiveness pin to UPDATE)]
3. **Broadened `run_completed.outcome` for a real completion/victory (AC2)** — add a `victory`/`completed` lower_snake outcome marker constant + accept it in `_validate_run_completed_payload` (an allowlist incl. the existing `boss_placeholder`), keeping the boss path byte-identical. Make the boss-specific fields (`boss_node_id`) tolerant for a non-boss completion WITHOUT weakening the boss path. [Source: `godot/scripts/core/events/domain_event.gd` lines 116-121 (the `RUN_COMPLETED_OUTCOME_BOSS_PLACEHOLDER` marker), 232-246, 938-952]
4. **The idempotency / no-double-grant guard (AC3)** — re-resolving an ALREADY-terminal run returns a stable error (e.g. `run_already_terminal`) OR an idempotent no-op ok carrying the existing terminal outcome (pick one; AC3 allows either) — and emits NO second event + mutates NOTHING (so no progression/reward can be granted twice). Mirror the orchestrator's existing `run_already_terminal` guard (`resolve_current_node`, lines 189-190) + the `start_from` `seated_run_terminal` guard. v0 grants nothing yet (awarding is 8.3), so "not granted twice" is structurally satisfied by emitting no second event + no mutation — but build the guard so 8.3's awarding inherits it. [Source: `godot/scripts/run/run_orchestrator.gd` `resolve_current_node` (the terminal guard), `start_from` (the `seated_run_terminal` guard)]
5. **The "next destination = outpost" flow signal (AC1/AC2)** — a stable DOMAIN signal (`next_destination`/`return_destination` = `outpost`, a lower_snake marker) on the command result metadata and/or the emitted event payload, and/or a tiny scene-free `RunEndOutcome` read DTO surfacing `{ phase, outcome_or_cause, next_destination: "outpost", meta_progression_eligible }`. NOT a scene transition, NOT an outpost `.tscn`. [Source: AC1/AC2; the scene-free read-DTO pattern in `godot/scripts/ui/view_models/` (e.g. `affinity_view_model.gd` exact-key discipline)]
6. **(OPTIONAL) A thin orchestrator dispatch hook** — IF it reads cleanly, the orchestrator may grow a method (mirroring `_resolve_boss`) that resolves a run-END through the new command + surfaces the run-failed/run-completed event + outcome + destination for the caller. Do NOT change the existing `_resolve_boss` boss-completion behavior or the boss `run_completed` boundary (Epic 9 depends on it). Do NOT auto-wire a death into `run_to_completion`'s loop (no live death source exists yet). [Source: `godot/scripts/run/run_orchestrator.gd` `_resolve_boss`, `run_completed_event`/`run_completed_outcome`]
7. **Full unit/integration tests** — proving: a death resolution transitions `→ FAILED`, emits `run_failed` with the cause, surfaces `next_destination == outpost` (AC1); a completion/victory resolution transitions `→ COMPLETED`, emits `run_completed` with the broadened outcome, surfaces `next_destination == outpost` (AC2); the boss path's existing `run_completed`/`outcome == boss_placeholder` behavior + its test STAY GREEN (the broadening did not regress the boss); a SECOND resolution on an already-terminal run is the stable-error-OR-idempotent result, emits NO second event, mutates NOTHING (AC3 — assert the run-state byte-identical + zero new events); an illegal transition (e.g. completing from `NEW_RUN`, or failing twice) is rejected with a stable code + ZERO mutation; the command rejects `sequence_id <= 0` FIRST; the new `run_failed` event round-trips through JSON + rejects each malformed field; the **`expected_ids` exhaustiveness pin is UPDATED and green** (the new event is pinned); the run-END resolution draws ZERO RNG (named-stream isolation — no stream advances); the 23-key `RunSnapshot` gate is UNCHANGED; `git diff --check` clean; the false-PASS grep guard clean; EVERY Small/Medium/route seed-regression fingerprint byte-identical (8.1 touches no generation).

**OUT of scope (explicitly later stories / NOT this story — do NOT pull forward):**
- **The RUN SUMMARY snapshot (cause of death/victory, nodes cleared, passives consumed/destroyed, notable loot, Oath Shards earned, Echoes, unlock progress, seed)** → **Story 8.2.** 8.1 emits the run-END EVENT (with cause/outcome) and the terminal phase; it does NOT build the summary aggregation, the summary DTO, or the "derive from domain events" summary source. The `run_failed.cause` + `run_completed.outcome` 8.1 emits are INPUTS the 8.2 summary reads. [Source: `_bmad-output/planning-artifacts/epics.md` Story 8.2; `_bmad-output/auto-gds/retro-notes/epic-7.md` §7 (8-2 owns the run-summary snapshot)]
- **The META PROFILE + Oath-Shard AWARDING + the meta-save shape** → **Story 8.3 (awarding) + 8.7 (meta/summary save-load tests).** 8.1 does NOT award Oath Shards, does NOT create a cross-run meta profile, does NOT build a meta `ProfileSnapshot`/`ProfileRepository`, and does NOT decide the meta-save shape (likely its OWN snapshot, NOT nested under `route_state` — the retro's T2/§7 heads-up). 8.1 READS `meta_progression_eligible` / `RiskEconomyState.oath_shard_eligible` ONLY to populate the flow signal — it grants nothing. The `RunSnapshot.oath_shards` top-level placeholder STAYS 0 (it is the AWARDED count Epic 8.3 owns; v0 awards none — confirmed in `run_snapshot.gd` lines 265-266). This is the project's FIRST persistent cross-run state and the retro flags planning the meta-save shape in 8.2→8.3 BEFORE the award command. [Source: `_bmad-output/auto-gds/retro-notes/epic-7.md` §7 risk 1 + Action T2 (Oath-Shard awarding is the central Epic-8 mutation, crosses the run/meta boundary, plan the meta-save shape early, budget migration from the start); `godot/scripts/save/snapshots/run_snapshot.gd` lines 264-266 (oath_shards is the AWARDED count, left 0 in v0)]
- **The OUTPOST MENU scene / view-model / named outpost spaces (Memory Archive, Hall of Oaths, Seal Table, Gate/Descent Stair) / "start another descent"** → **Story 8.6.** 8.1 produces the DOMAIN flow fact (`next_destination == outpost`); it does NOT build the outpost `.tscn`, the `OutpostViewModel`, the named-space metadata, or the start-another-descent action. UI-scene-last (the SAME residual every Epic 5/6/7 story left). [Source: `_bmad-output/planning-artifacts/epics.md` Story 8.6; `project-context.md` UI-scene-last]
- **The first-death narrative line ("Good. You remembered how to die.") + optional/skippable narrative delivery** → **Story 8.5.** 8.1 emits the run-failed event; it does NOT track the first-death flag, does NOT deliver narrative text, and does NOT build a narrative/skippable surface. Keep narrative off the run-end CRITICAL path (the retro's §7 risk 2: optional narrative must not gate the meta core). [Source: `_bmad-output/planning-artifacts/epics.md` Story 8.5; `_bmad-output/auto-gds/retro-notes/epic-7.md` §7 risk 2]
- **A LIVE tactical play loop / a real combat-death source / wiring a death into the auto-resolve `run_to_completion` loop** — `RunOrchestrator._resolve_combat` AUTO-RESOLVES combat (no live `BoardState`, no turn loop, no HP-reaches-zero detection in the run flow). 8.1's failed path is COMMAND-DRIVEN with an EXPLICIT cause (a caller/test supplies the cause); it does NOT instantiate a live board, does NOT add a turn loop, does NOT auto-detect a death in `run_to_completion`, and does NOT perturb the interrupted==uninterrupted determinism / the v0 combat-auto-resolve posture the whole project preserved. The "play a level → hero HP hits 0 → run fails" live wiring is the later HUD/run-flow / live-tactical-loop story (the now-headline latent debt the Epic-7 retro names — Action T1 — explicitly NOT an Epic-8 dependency). [Source: `_bmad-output/auto-gds/retro-notes/epic-7.md` §7 risk 4 + Action T1 (the live-tactical-loop residual does NOT come due in Epic 8 — keep it parked); `godot/scripts/run/run_orchestrator.gd` `_resolve_combat` (auto-resolve)]
- **Replacing the boss PLACEHOLDER with a real Larval Avatar boss level + the first-VICTORY reveal ("It did not die. It learned the way back.")** → **Epic 9.** 8.1 does NOT build boss content; it broadens the run-completed OUTCOME vocabulary so a real victory CAN emit a non-placeholder outcome, but the real boss level + victory is Epic 9, which reuses the SAME `run_completed` boundary. Do NOT change the boss's `boss_placeholder` outcome value or the boss node boundary. [Source: `_bmad-output/planning-artifacts/epics.md` Epic 9; `godot/scripts/core/commands/node_resolve_placeholder_command.gd` `_resolve_boss` (the boundary Epic 9 reuses)]
- **Manual-seed no-progression ENFORCEMENT in the award path (FR28)** → **Story 8.3** (the actual meta gate). 8.1 READS `meta_progression_eligible` (already lockstep with `is_manual_seed`) for the flow signal but does NOT enforce a manual-seed award denial (there is no awarding yet). [Source: `_bmad-output/planning-artifacts/epics.md` FR28 → Epic 8 (8.3); `godot/scripts/run/risk_economy_state.gd` `oath_shard_eligible` invariant]
- **Persisting any new run-END state into the save snapshot** — the terminal phase already persists (the `run_phase` nested under `route_state`, the 4.3 mechanism; `PHASE_COMPLETED`/`PHASE_FAILED` are valid `run_phase` values). 8.1 adds NO new top-level `RunSnapshot` key (the 23-key gate stays 23) and NO migration. If the run-failed cause / the flow signal needs to survive a save, that is the 8.2/8.7 summary-save concern — 8.1 does NOT expand the route-position save. [Source: `godot/scripts/run/run_state.gd` `RUN_PHASE_KEY` + `to_run_snapshot_fields` (the nested run_phase); `project-context.md` the 23-key gate]
- **NOT overlapping (leave parked — do NOT reopen):** the live-tactical-loop call site + affinity HUD/VFX (Epic-7 retro T1 — explicitly NOT an Epic-8 dependency); the seated-Cursed-rule-source / assigned-affinity re-derive-on-resume obligation (a later in-node-save/live-resume story, retro T5); the 7.4 `assign_affinity` once-per-node idempotency guard (a later per-node-assign/run-flow story, retro T6); the generated-board Darkness-fairness fixtures (a later hazard-in-generated-terrain story, retro T4); the Flooded conductive electric-interaction placeholder (Epic-10 readiness, retro D2); the int64-overflow economy ceiling + the constant-8-tier route-depth pacing (Epic 10); the `warding_salve` reward-table decision (later content / Epic 10, retro D1); the board-snapshot cell-coercion / occupant-schema-migration defers (code review of 1-3). None overlap 8.1's run-END/event area. [Source: `_bmad-output/implementation-artifacts/deferred-work.md` passim; `_bmad-output/auto-gds/retro-notes/epic-7.md` §8 Action Items]

If an AC seems to demand a LIVE combat death loop, re-read: AC1 demands "the hero dies ... the run enters failed state and emits a run-failed event with cause" — a COMMAND that transitions to `FAILED` + emits `run_failed` with an explicit cause satisfies this headlessly WITHOUT a live combat loop (the live death SOURCE is the deferred HUD/run-flow story; 8.1 owns the run-END RESOLUTION + the event). AC2 demands "completion or victory path ... run enters completed state and emits a run-completed event" — broadening `run_completed.outcome` + transitioning to `COMPLETED` satisfies this (the real boss VICTORY is Epic 9, which reuses this boundary). AC3 demands "already completed or failed ... stable error or idempotent result ... not granted twice" — the terminal-state guard + zero-second-event + zero-mutation satisfies this. NONE of the three ACs demands a live tactical play loop, a run summary, an Oath-Shard award, or an outpost scene.

## Tasks / Subtasks

- [x] **Task 1 — The run-END resolution command (the 4.3 run-command idiom) (AC1, AC2, AC3)** — a run-domain `GameCommand` under `godot/scripts/core/commands/`
  - [x] **Resolve the ⭐ command-shape `[Decision]` first (see the scope boundary) and record it in Completion Notes:** a single outcome-parameterized `CompleteRunCommand` (RECOMMENDED) OR sibling fail/complete commands. Whichever: extend `res://scripts/core/commands/game_command.gd`, take the live `RunState` DIRECTLY as the `validate(state)`/`execute(state)` arg (NO `RunActionContext` wrapper — the 4.3 idiom), the CALLER supplies the run-level `sequence_id` via the constructor (default 1).
  - [x] **Validate-then-mutate, `sequence_id <= 0` FIRST (the 4.3 invalid_event_sequence_id guard):** `validate()` rejects `sequence_id <= 0` BEFORE reading/mutating state (so a success path can never emit an event its own validator would reject); then validates the run is a `RunState`, structurally sound (`run.validate()`), and the requested END transition is legal from the current phase. On any rejection: structured `ActionResult.error` with ZERO events and a byte-identical no-mutation `RunState`. Build the success event ONLY after the (legal) `transition_to` succeeds. [Source: `godot/scripts/core/commands/node_resolve_placeholder_command.gd` lines 97-153 (the validate shape) + 211-279 (the boss mutate-then-event ordering)]
  - [x] **Death path → `PHASE_FAILED` + `run_failed` (AC1):** transition `→ PHASE_FAILED` (a legal edge from `ACTIVE_ROUTE` and `NODE_RESOLUTION` — already in `_legal_next_phases`), then emit `run_failed` carrying the CAUSE (supplied by the caller — an explicit lower_snake cause marker). Reject the transition fail-loud (a structured wrong-phase error, ZERO event) if the run is not in a phase that legally reaches `FAILED`.
  - [x] **Completion/victory path → `PHASE_COMPLETED` + `run_completed` (AC2):** transition `→ PHASE_COMPLETED` (legal from `NODE_RESOLUTION`; if the AC's "completion path" can be reached from `ACTIVE_ROUTE`, note that `_legal_next_phases` does NOT currently allow `ACTIVE_ROUTE → COMPLETED` — if 8.1's completion is driven from `ACTIVE_ROUTE`, either route it through `NODE_RESOLUTION` first like the boss does, OR add the edge with a recorded rationale + a transition-table test; PREFER mirroring the boss's `ACTIVE_ROUTE → NODE_RESOLUTION → COMPLETED` two-step to avoid changing the table). Emit `run_completed` with the BROADENED outcome (Task 3). [Source: `godot/scripts/run/run_state.gd` lines 550-565 (`_legal_next_phases`); `node_resolve_placeholder_command.gd` lines 234-252 (the boss two-step transition)]
  - [x] **The "next destination = outpost" flow signal (AC1/AC2):** surface a stable `next_destination`/`return_destination` = `outpost` (a lower_snake marker const) on the command `ActionResult.metadata` and/or the event payload (and/or a tiny scene-free read DTO — Task 5). Record the placement `[Decision]`. NOT a scene transition / `.tscn`.
  - [x] **ZERO RNG (named-RNG rule):** run-END resolution is a deterministic phase transition + event — it draws NO RNG (no `randi`/`randf`/`RandomNumberGenerator`, no stream advance). Assert named-stream isolation in tests (no stream advances).
  - [x] Tests (`godot/tests/unit/core/test_*_command.gd`): death → `FAILED` + `run_failed` + cause + outpost signal; completion → `COMPLETED` + `run_completed` + outpost signal; `sequence_id <= 0` rejected FIRST; an illegal-phase transition rejected with a stable code + ZERO mutation + ZERO events; ZERO RNG drawn.

- [x] **Task 2 — The `run_failed` SYSTEM event (NEW, append-only, with CAUSE) (AC1)** — extend `godot/scripts/core/events/domain_event.gd` end-to-end
  - [x] **Append `RUN_FAILED` AFTER the last enum member (`EVENT_RESOLVED`), NEVER renumber.** Add `const EVENT_ID_RUN_FAILED := &"run_failed"`. [Source: `godot/scripts/core/events/domain_event.gd` lines 6-39 (the enum), 41-72 (the id consts)]
  - [x] **Factory `DomainEvent.run_failed(sequence_id, payload)`** — a SYSTEM event (no actor; `actor_id` stays empty — do NOT add it to `_event_requires_actor`). Defensively normalize/duplicate the payload (mirror `run_completed`, lines 232-246): the CAUSE (a stable lower_snake marker), plus any `node_id`/`node_type` (hyphenated → plain non-empty string) / `cleared_node_count` (non-negative integral) you carry. Decimal-string-encode NOTHING here unless a field can exceed 2^53 (the cause/markers are short strings, counts are bounded — no int64 encoding needed).
  - [x] **Payload validator `_validate_run_failed_payload`** — assert the CAUSE field (lower_snake; if you pin an allowlist of cause codes — e.g. `hero_death`/`level_defeat`/`boss_defeat`/`abandoned` — mirror the `*_CATEGORIES` allowlist-const pattern + pin it by test; otherwise require a non-empty lower_snake cause) + any other carried fields. Wire it into the `validate_payload` match (mirror line 792 `Type.RUN_COMPLETED → _validate_run_completed_payload`). [Source: `godot/scripts/core/events/domain_event.gd` lines 786-813 (the validator dispatch), 938-952 (`_validate_run_completed_payload` as the template)]
  - [x] **Both id maps + round-trip:** add `Type.RUN_FAILED → EVENT_ID_RUN_FAILED` to `id_for_type` (mirror line 1732) AND `EVENT_ID_RUN_FAILED → Type.RUN_FAILED` to `type_for_id` (mirror line 1800), so `id_for_type`/`type_for_id` round-trip.
  - [x] **⭐ UPDATE the `expected_ids` EXHAUSTIVENESS PIN (this WILL fail-loud until you do — by design):** add `DomainEvent.Type.RUN_FAILED: &"run_failed"` to the `expected_ids` map in `test_domain_event.gd::_event_identifiers_are_stable_machine_ids` (lines 1948-1987). The gate `expected_ids.size() == DomainEvent.Type.size() - 1` + the per-member iteration (lines 2001-2005) FAILS until the new member is pinned. Add it; do NOT loosen the assertion. [Source: `godot/tests/unit/core/test_domain_event.gd` lines 1947-2005 (the Story-7.1 / retro-T3 exhaustiveness hardening)]
  - [x] Tests (in `test_domain_event.gd`, mirroring the per-event pattern): `run_failed` constructs with the cause; the payload validator ACCEPTS a well-formed payload and REJECTS each malformed field (an invalid cause, a non-string `node_id`, a negative `cleared_node_count` — the per-field `invalid_event_payload` checks); the event survives a JSON `stringify`→`parse_string` round-trip; `id_for_type`/`type_for_id` round-trip; the `expected_ids` pin is green.

- [x] **Task 3 — Broaden `run_completed.outcome` for a real completion/victory WITHOUT breaking the boss boundary (AC2)** — extend the `run_completed` validator
  - [x] **Resolve the ⭐ outcome `[Decision]` (see the scope boundary) and record it:** add a `victory`/`completed` lower_snake outcome marker (RECOMMENDED a `const RUN_COMPLETED_OUTCOME_VICTORY := &"victory"` or `..._COMPLETED := &"completed"` alongside `RUN_COMPLETED_OUTCOME_BOSS_PLACEHOLDER`, the lockstep-marker pattern). Accept an ALLOWLIST of completion outcomes (boss_placeholder OR victory/completed) in `_validate_run_completed_payload` — do NOT replace the boss value. [Source: `godot/scripts/core/events/domain_event.gd` lines 116-121 (the marker consts), 938-952 (the validator)]
  - [x] **Keep the boss path byte-identical (the load-bearing regression guard):** the boss path emits `outcome == "boss_placeholder"` + `boss_node_id` + `cleared_node_count` (`node_resolve_placeholder_command.gd` `_resolve_boss`). After broadening, the boss event MUST still validate AND its existing test must stay green. For a NON-boss completion (no boss node), make `boss_node_id` TOLERANT (optional/absent) for the non-boss outcome WITHOUT making it optional for the boss outcome (e.g. require `boss_node_id` only when `outcome == boss_placeholder`). Record the field-shape decision. [Source: `godot/scripts/core/commands/node_resolve_placeholder_command.gd` `_resolve_boss` (the boss event); `godot/tests/unit/core/test_domain_event.gd` (the existing run_completed test — keep green)]
  - [x] Tests: a completion/victory `run_completed` with the broadened outcome VALIDATES + round-trips; the boss `run_completed` (`boss_placeholder` + boss fields) STILL validates (the boss regression guard); an unknown/garbage outcome is still REJECTED (the allowlist did not become permissive); the boss command's existing behavior/tests stay green.

- [x] **Task 4 — The idempotency / no-double-grant guard (AC3)** — the already-terminal guard
  - [x] **Re-resolving an ALREADY-terminal run** returns a stable error (RECOMMENDED `run_already_terminal`, mirroring the orchestrator's existing guard) OR an idempotent no-op ok carrying the existing terminal outcome (AC3 allows either — pick one + pin it). It emits NO second event + mutates the `RunState` NOT AT ALL (byte-identical) — so nothing can be granted twice. [Source: `godot/scripts/run/run_orchestrator.gd` lines 189-190 (`run_already_terminal`), 163-167 (`seated_run_terminal`)]
  - [x] **Structurally guarantee "not granted twice" (AC3):** v0 grants no reward/progression at run-END (awarding is 8.3) — so "not granted twice" is satisfied by the no-second-event + no-mutation guard. Build the guard so 8.3's awarding inherits it (the award must run BEHIND this guard, never on a re-completion). Note in Completion Notes that 8.1 has nothing to double-grant yet, but the guard is the seam 8.3 awarding sits behind.
  - [x] Tests: a first death/completion succeeds; a SECOND resolution on the now-terminal run returns the stable-error-OR-idempotent result; the second resolution emits ZERO new events + leaves the `RunState` byte-identical (assert `to_dictionary()` equality before/after the second call); a double-fail and a fail-then-complete are both blocked (terminal is terminal).

- [x] **Task 5 — The run-END read surface / flow signal (AC1/AC2)** — scene-free, optional DTO
  - [x] IF you chose a read DTO for the flow signal (Task 1): a tiny scene-free `RefCounted` (mirror `affinity_view_model.gd`'s exact-key, fail-closed, no-live-handle discipline) surfacing `{ phase, outcome_or_cause, next_destination: "outpost", meta_progression_eligible }` — a PURE read (no mutation, no RNG, no events; repeated reads identical). It READS `run.meta_progression_eligible` / `RiskEconomyState.oath_shard_eligible` for the eligibility field; it does NOT award anything (8.3). [Source: `godot/scripts/ui/view_models/affinity_view_model.gd` (the scene-free read pattern); `godot/scripts/run/risk_economy_state.gd` `oath_shard_eligible`]
  - [x] **Keep the eligibility READ-ONLY:** the flow signal REPORTS `meta_progression_eligible` (already lockstep with `is_manual_seed`); it does NOT compute, grant, or deny an award (FR28 enforcement is 8.3). A manual-seed run's flow signal reports `meta_progression_eligible == false` but 8.1 takes no award action.
  - [x] Tests: the read DTO has an EXACT pinned key set (if you build one); `next_destination == outpost` for BOTH a failed and a completed run; the eligibility field mirrors `meta_progression_eligible` (true for a normal run, false for a manual-seed run); the read is pure (twice → identical).

- [x] **Task 6 — Full headless suite + diff hygiene + the scope-fence + the deferred-work dispositions**
  - [x] Run the FULL headless suite via PowerShell (`godot` is NOT on the Bash PATH — see Project Context Rules). Expect "Headless tests passed.", exit 0, ZERO FAIL. Apply the **false-PASS grep guard** (`SCRIPT ERROR|Parse Error|Compile Error|Failed to load script`) — it must be clean beyond the documented-expected negative-path diagnostics (the int64-overflow `root_seed` boundary x2, `RouteNode parse failed: invalid_node_type`, the save/settings `Parse JSON failed`/`got 'this'`/`Expected key` negatives). Command: `godot --headless --path C:\Sealsworn\godot --scene res://tests/headless/test_runner.tscn --quit-after 10` (or the console binary `C:/Users/Rasmus/Godot_v4.6.3-stable_win64.exe/Godot_v4.6.3-stable_win64_console.exe` with the same args, since `godot` resolves only via PowerShell).
  - [x] `git diff --check` clean (working tree + the baseline..HEAD; ignore the benign LF→CRLF normalization warning on the `.md`).
  - [x] **Confirm the scope fences:** the `DomainEvent.Type` enum is APPEND-ONLY (`RUN_FAILED` appended at the end + wired end-to-end + added to `expected_ids`; NOTHING renumbered); the `run_completed` boss `boss_placeholder` outcome value UNCHANGED + the boss command/test green; `RngStreamSet.required_streams()` UNCHANGED (the 7 streams — run-END draws ZERO RNG, no new stream); the 23-key `RunSnapshot` COUNT STAYS 23 + the no-surprise-key gate UNCHANGED (no new save key — the terminal phase already persists via the nested `run_phase`); `RunSnapshot.oath_shards` STAYS the 0 AWARDED-count placeholder (no awarding — 8.3); `meta_progression_eligible` READ-ONLY (no award/deny — 8.3); the `RunState._legal_next_phases` transition table UNCHANGED unless an AC genuinely needs an edge (record WHY + add a table test if you do — PREFER the boss two-step over a new edge); `RunOrchestrator._resolve_combat`/`run_to_completion`/`_resolve_boss` boss-completion behavior UNCHANGED (no death auto-wired into the auto-resolve loop; the boss boundary Epic 9 reuses is untouched); `scripts/rules/{conditions,operations}` UNCHANGED (run-END is not a rules-kernel concern); `data/source`/`data/resources` STAY EMPTY (no content); no `.tscn`/new asset (UI-scene-last; the outpost scene is 8.6); ZERO `randi`/`randf`/`RandomNumberGenerator` in any new code; **every Small/Medium/route seed-regression fingerprint byte-identical** (8.1 touches no `scripts/generation/`).
  - [x] **Update `deferred-work.md`** with the 8.1 dispositions (mirror the 7-6 entry structure): that the run-summary snapshot (8.2), the Oath-Shard awarding + meta profile + the meta-save shape (8.3/8.7), the outpost menu scene + named spaces + start-another-descent (8.6), and the first-death narrative line (8.5) are DEFERRED to their owning stories; that the LIVE tactical-loop / real combat-death source + auto-wiring a death into `run_to_completion` remain DEFERRED (the retro-T1 live-tactical-loop residual — explicitly NOT an Epic-8 dependency); that 8.1 emits the `run_failed` (with cause) + the broadened `run_completed` outcome + the `next_destination == outpost` flow signal as the run-END boundary INPUTS the 8.2 summary + 8.3 awarding consume; and that `meta_progression_eligible` / `oath_shard_eligible` are READ-ONLY at run-END in 8.1 (the actual meta gate + awarding is 8.3, the project's first persistent cross-run state). Note any new cross-story `[Decision]` (the command shape, the run-failed cause shape, the run-completed outcome shape, the flow-signal placement).
  - [x] Update story Status (→ review), `sprint-status.yaml` (`8-1-run-completion-and-return-to-outpost-flow: review`, refresh `last_updated`), the File List, and Completion Notes (incl. ALL `[Decision]`s — the command shape; the run-failed event + its cause shape/allowlist; the run-completed outcome broadening + the boss-field tolerance shape; the flow-signal placement; whether a read DTO was built; the idempotency-vs-stable-error choice; the transition-table decision if any edge was added). Note that 8.1 OPENS Epic 8 (the run-END boundary) and that the run-summary (8.2) + meta awarding (8.3) build on the events/phase it ships.

## Dev Notes

### The big picture: 8.1 closes the RUN-END boundary — the FIRST story of Epic 8 (run completion → return to outpost)
Epic 8 is "die or finish a run, return to the last outpost, review what happened, receive eligible progress, start another descent." 8.1 is its FOUNDATION: it makes a run END cleanly and route to the outpost. Today the run can only ever reach `COMPLETED` (via the boss placeholder); there is NO death path and NO run-failed event. 8.1 (a) drives the already-existing `PHASE_FAILED` for the first time with a brand-new `run_failed` event carrying a CAUSE (AC1, FR32), (b) broadens the existing `run_completed` event's outcome so a real completion/victory CAN emit (AC2), (c) makes BOTH endings carry a `next_destination == outpost` DOMAIN flow signal, and (d) makes re-completing an already-ended run idempotent / a stable error that cannot double-grant (AC3). It is deliberately NARROW: it ships the run-END EVENTS + PHASE + flow signal that the run SUMMARY (8.2), the meta profile + Oath-Shard AWARDING (8.3), and the OUTPOST menu (8.6) all build on — but it builds none of those. [Source: `_bmad-output/planning-artifacts/epics.md` lines 2017-2042 (Epic 8 intro + Story 8.1 ACs); FR32; the Epic-7 retro §7 "Next-Epic Preview — Epic 8"]

### ⭐ CRITICAL — the run-END machinery EXISTS; EXTEND it (the single most important calibration)
The Epic-4 run-progression model is the seam, and it is ALREADY most of the way there:
- **`RunState` phases + transitions:** `PHASE_COMPLETED` + `PHASE_FAILED` exist (lines 31-35); `is_terminal()` returns true for both (lines 215-216); `_legal_next_phases` ALREADY allows `ACTIVE_ROUTE → FAILED`, `NODE_RESOLUTION → {ACTIVE_ROUTE, COMPLETED, FAILED}` (lines 550-565). `transition_to` validates the edge + mutates `phase` (legal) or returns a structured `invalid_run_transition` + ZERO mutation (illegal) (lines 225-232). So 8.1 DRIVES the existing edges — it does NOT add the `FAILED` edges (they exist). NOTE: `ACTIVE_ROUTE → COMPLETED` is NOT a legal edge today (only `NODE_RESOLUTION → COMPLETED` is) — if 8.1's completion is driven from `ACTIVE_ROUTE`, route it through `NODE_RESOLUTION` first (the boss does exactly this two-step), or add the edge with a recorded rationale + a transition-table test. PREFER the two-step.
- **`run_completed` event:** exists (4.5, `domain_event.gd` lines 232-246) but its validator pins `outcome == "boss_placeholder"` (lines 938-952). 8.1 BROADENS the outcome allowlist (add `victory`/`completed`) — it does NOT create a parallel completed event.
- **`NodeResolvePlaceholderCommand._resolve_boss`** (lines 211-279) is the TEMPLATE: it marks the node cleared, runs the `ACTIVE_ROUTE → NODE_RESOLUTION → COMPLETED` two-step, builds `node_placeholder_resolved` + `run_completed` ONLY after the transitions succeed (mutate-then-event ordering), and returns the outcome + boundary metadata. 8.1's command mirrors this shape (validate-then-mutate, build the event after the transition).
- **The orchestrator's terminal guards** (`resolve_current_node` `run_already_terminal` lines 189-190; `start_from` `seated_run_terminal` lines 163-167) are the AC3 idempotency model to mirror.
Do NOT fork a parallel run-end format, do NOT add a parallel phase/transition system, do NOT duplicate the event-wiring. EXTEND. [Source: `godot/scripts/run/run_state.gd` lines 31-35, 215-232, 550-565; `godot/scripts/core/commands/node_resolve_placeholder_command.gd` lines 211-279; `godot/scripts/run/run_orchestrator.gd` lines 163-190]

### ⭐ THE EXHAUSTIVENESS GATE WILL FAIL-LOUD ON THE NEW EVENT — THIS IS EXPECTED (the epic-transition heads-up)
Story 7.1 hardened the event-id map (the Epic-6 retro T3 / 6.7 Round-1 Low): `test_domain_event.gd::_event_identifiers_are_stable_machine_ids` (lines 1947-2005) now asserts `expected_ids.size() == DomainEvent.Type.size() - 1` AND iterates EVERY non-`UNKNOWN` enum member asserting it is a pinned key in `expected_ids`. **When 8.1 appends `RUN_FAILED` to the enum, this gate FAILS LOUD until you add `DomainEvent.Type.RUN_FAILED: &"run_failed"` to the `expected_ids` map in the SAME change.** This is BY DESIGN — the gate exists precisely to catch a forgotten append. Do NOT loosen the assertion, do NOT skip the test; ADD the new member to the map (and wire the event end-to-end: factory + payload validator + both id maps + round-trip + malformed negatives). The Epic-7 retro explicitly flagged this as the "register/extend the gate on the new table → that is expected" heads-up for Epic 8's first award/completion event. [Source: `godot/tests/unit/core/test_domain_event.gd` lines 1996-2005 (the exhaustiveness pin) + lines 1971-1986 (the Story-6/7 append comments — mirror that comment style for `run_failed`); `_bmad-output/auto-gds/retro-notes/epic-7.md` §6 T3 + §8 Action T3 (the carried event-id-map exhaustiveness hardening)]

### ⭐ AC2 — broaden the completion outcome, keep the boss boundary intact (Epic 9 depends on it)
`run_completed.outcome` is value-pinned to `boss_placeholder`. Epic 9 (the real Larval Avatar boss + first-victory reveal) REUSES this exact `run_completed` boundary — it swaps only the boss's pre-completion behavior (a real boss level + victory) WITHOUT changing the route model, the boss node type, or the `run_completed` event. So 8.1 must broaden the outcome (add `victory`/`completed`) so AC2's "completion or victory path" can emit, WHILE keeping the boss's Epic-9 CONTRACT (event type `run_completed`, `outcome == "boss_placeholder"`, `boss_node_id`) intact so the boss command + its test + the Epic-9 contract all stay green. **CORRECTION (boss-payload decision, ACCEPTED Option A 2026-06-30):** the implementation broadens the `run_completed` factory to default a `next_destination == "outpost"` flow signal (and the validator to require it for BOTH outcomes), so the boss `run_completed` payload is NOT byte-identical — it now ADDITIVELY and backward-compatibly carries `next_destination: "outpost"`. The Epic-9 boss contract surface (event type, `outcome == "boss_placeholder"`, `boss_node_id`) is unchanged, and no consumer asserts the boss payload's exact key set. The clean shape: an outcome ALLOWLIST (boss_placeholder OR victory/completed) in `_validate_run_completed_payload`, with the boss-only field (`boss_node_id`) required ONLY for the boss outcome (tolerant/absent for a non-boss completion). Record the field-shape `[Decision]`. [Source: `godot/scripts/core/commands/node_resolve_placeholder_command.gd` lines 22-27 (the Epic-9-reuses-this-boundary contract) + 264-268 (the boss run_completed payload); `project-context.md` "Do not re-create, rename, or duplicate the 4.5 run_completed event; later epics CONSUME it ... Do not renumber the event enum"]

### AC1 — the run-failed CAUSE: command/caller-driven, NOT a live-combat detector
v0 has NO live combat death (combat auto-resolves to success in `RunOrchestrator._resolve_combat` — building the live loop is OUT of scope, the retro-T1 deferred work). So 8.1's failed path is COMMAND-DRIVEN with an EXPLICIT cause the caller supplies (a test, or the later HUD/run-flow story that owns the live death). The CAUSE is a stable, readable lower_snake marker (e.g. `hero_death`/`level_defeat`/`boss_defeat`/`abandoned` — pick the set + pin it if you allowlist). Do NOT add a death-detection branch to the orchestrator's auto-resolve loop (there is no HP-reaches-zero signal there). The run-failed event + cause is the run-END RESOLUTION; the live death SOURCE is deferred. AC1's three death contexts ("during a level, event, or boss encounter") map to the CAUSE marker (the resolution is the same — transition to FAILED + emit run_failed; the cause distinguishes the context). [Source: `godot/scripts/run/run_orchestrator.gd` `_resolve_combat` (auto-resolve — no death source); `_bmad-output/planning-artifacts/epics.md` FR32 + Story 8.1 AC1]

### AC3 — idempotency = no second event + no mutation (so 8.3 awarding can't double-grant)
AC3: "already completed or failed ... stable error or idempotent result ... rewards or progression are not granted twice." 8.1 grants NOTHING (awarding is 8.3) — so "not granted twice" is structurally satisfied today by the already-terminal guard emitting NO second event + mutating the `RunState` NOT AT ALL. But the guard is load-bearing FORWARD: 8.3's Oath-Shard awarding must run BEHIND this guard so a re-completion never re-awards. Build the guard now (mirror the orchestrator's `run_already_terminal`), assert the run-state byte-identical + zero-new-events on a second call, and note in Completion Notes that 8.3's awarding sits behind it. AC3 allows EITHER a stable error OR an idempotent no-op ok carrying the existing terminal outcome — pick one + pin it. [Source: `godot/scripts/run/run_orchestrator.gd` lines 163-167, 189-190 (the terminal guards); `_bmad-output/auto-gds/retro-notes/epic-7.md` §7 risk 1 (Oath-Shard awarding is the central Epic-8 mutation — 8.1's idempotency guard is the seam it sits behind)]

### The "next destination = outpost" is a DOMAIN flow fact, not a scene transition
AC1/AC2 both end with "the next app flow destination is the outpost." v0 has NO outpost scene (8.6 owns it) and NO scene-wired app-flow machine. Model the destination as a stable DOMAIN signal (a `next_destination`/`return_destination = outpost` lower_snake marker) on the command result and/or the event payload, and/or a scene-free read DTO. A later boot/app-flow + outpost-scene story (8.6) reads it and performs the actual navigation. Do NOT build a `SceneManager` transition or an outpost `.tscn` (UI-scene-last — the SAME residual every Epic 5/6/7 story left). The run-END produces the DATA fact; presentation consumes it later. [Source: AC1/AC2; `project-context.md` "Adaptive UI ... view models, presenters ... UI observes domain state"; the scene-free view-model precedent (`HeroSelectViewModel`/`AffinityViewModel`)]

### The headline Epic-7 → Epic-8 handoff (from the Epic-7 retro §7 + the project-context risk-economy section)
The Epic-7 risk-economy state (7.1) is the run-end INPUT Epic 8 reads — and the handoff is precise:
- `RiskEconomyState.oath_shard_eligible` (run-domain) + `RunState.meta_progression_eligible` (the existing top-level source of truth, lockstep with `is_manual_seed`) are the run-end ELIGIBILITY facts. 8.1 READS them for the flow signal; 8.3 OWNS the awarding off them. 7.1 deliberately tracked Oath-Shard ELIGIBILITY without AWARDING — Epic 8 (8.3) owns the awarding.
- `RunSnapshot.oath_shards` (top-level, line 38) is the AWARDED meta count — deliberately left 0 in v0 (`run_snapshot.gd` lines 264-266: "oath_shards is the AWARDED meta count (Epic 8), NOT the eligibility gate ... v0 awards none"). 8.1 keeps it 0.
- The retro names the meta profile as the project's FIRST persistent cross-run state, and flags planning the meta-save shape (likely its OWN snapshot, NOT nested under `route_state`) in 8.2→8.3 BEFORE the award command, with migration coverage from the start (8.7). 8.1 does NOT touch the meta-save shape — but it should be aware the run-END events/phase it ships are what 8.2's summary + 8.3's awarding read.
- The status-hygiene reflex (retro §7 risk 3 / Action P2): "flip to `done` on review-APPROVE in the same finalize step." 8.1's finalize (the orchestrator's, post-review) should reconcile the status field promptly (three epics running — 5-5/6-7/7-6 — had a final-story status lag). [Source: `_bmad-output/auto-gds/retro-notes/epic-7.md` §7 (dependencies + risks 1-4) + §8 Actions T2/P2; `project-context.md` "RISK-ECONOMY STATE PERSISTS NESTED UNDER route_state" + "oath_shard_eligible is the run-level ELIGIBILITY gate ... the actual meta gate is Epic 8"; `godot/scripts/save/snapshots/run_snapshot.gd` lines 38, 264-266]

### Determinism + named-RNG + no new save state (the epic-wide invariants 8.1 MUST honor)
- DETERMINISM: run-END resolution is a deterministic phase transition + event — same `(run, requested outcome/cause, sequence_id)` → identical result. ZERO RNG.
- NAMED RNG: 8.1 draws NO RNG. `RngStreamSet.required_streams()` is UNCHANGED (the 7 streams — do NOT add one). NEVER `randi`/`randf`/a fresh `RandomNumberGenerator`. Assert named-stream isolation (no stream advances on a run-END resolution). [Source: `godot/scripts/core/state/rng_stream_set.gd`; `project-context.md` named-RNG rule]
- NO NEW SAVE STATE: the terminal phase already persists (the `run_phase` nested under `route_state`, the 4.3 mechanism — `PHASE_COMPLETED`/`PHASE_FAILED` are valid `run_phase` values). 8.1 adds NO new top-level `RunSnapshot` key (the 23-key COUNT stays 23) + NO migration. The run-failed cause / flow signal need not survive a save in 8.1 (the run summary's persistence is 8.2/8.7). [Source: `godot/scripts/run/run_state.gd` `RUN_PHASE_KEY` + `to_run_snapshot_fields`; `project-context.md` the 23-key gate]
- FINGERPRINTS: 8.1 touches NO `scripts/generation/` — every Small/Medium/route seed-regression fingerprint stays byte-identical. [Source: `project-context.md` SEED REGRESSION tripwire]

### Deferred-work items that OVERLAP this story (from `_bmad-output/implementation-artifacts/deferred-work.md`)
- **(OVERLAPS — this story OPENS it) The Oath-Shard awarding + meta profile (Epic 8)** is named as parked in the 7.1/7.3/7.4/7.5/7.6 dev-story notes. 8.1 does NOT award (8.3 owns it) — but 8.1 ships the run-END boundary (phase + events + flow signal) that the awarding sits behind. 8.1's AC3 idempotency guard is the seam 8.3's awarding must run behind (no re-award on re-completion). Record this linkage in `deferred-work.md`.
- **(DO NOT REOPEN — out of this story's scope) The LIVE tactical-play loop / real combat-death source / affinity HUD/VFX (retro T1)** — the now-headline latent debt, explicitly NOT an Epic-8 dependency. 8.1's failed path is command/caller-driven with an explicit cause; it does NOT build the live death source. Knowingly worked around.
- **(DO NOT REOPEN) The seated-Cursed / assigned-affinity re-derive obligation (later in-node-save/live-resume story, retro T5), the 7.4 `assign_affinity` idempotency guard (later run-flow story, retro T6), the generated-board Darkness-fairness fixtures (retro T4), the Flooded electric-interaction placeholder (Epic-10 readiness, retro D2), the int64-overflow economy ceiling + the constant-8-tier route depth (Epic 10), the `warding_salve` table (retro D1), the board-snapshot cell-coercion defers (code review of 1-3)** — none overlap 8.1's run-END/event area. Leave parked. [Source: `_bmad-output/implementation-artifacts/deferred-work.md` passim; `_bmad-output/auto-gds/retro-notes/epic-7.md` §8 Action Items T1/T4/T5/T6 + D1/D2]

### Project Structure Notes

- **New run-END command:** a run-domain `GameCommand` under `godot/scripts/core/commands/` (NOT under `scripts/run/` — run-domain commands live with the tactical commands, the 4.x contract). RECOMMENDED name `complete_run_command.gd` (`CompleteRunCommand`) for the single outcome-parameterized command, OR `fail_run_command.gd` + a completion command if you split. Record the placement/name + WHY in Completion Notes.
- **Extended (read/extend, do NOT fork):** `godot/scripts/core/events/domain_event.gd` (append `RUN_FAILED` + broaden `run_completed`'s outcome — the append-only SYSTEM-event + lockstep-marker discipline); `godot/scripts/run/run_state.gd` (DRIVE the existing `FAILED`/`COMPLETED` transitions via `transition_to`; do NOT add edges unless an AC needs one); `godot/scripts/run/run_orchestrator.gd` (OPTIONAL thin dispatch hook mirroring `_resolve_boss` — do NOT change the boss-completion behavior or the boss boundary).
- **Reused as a template (do NOT modify its boss behavior):** `godot/scripts/core/commands/node_resolve_placeholder_command.gd` (`_resolve_boss` — the mutate-then-event transition+event pattern; the 4.3 validate idiom).
- **Read-only references:** `godot/scripts/run/risk_economy_state.gd` (`oath_shard_eligible`); `godot/scripts/save/snapshots/run_snapshot.gd` (`oath_shards`/`meta_progression_eligible` — confirm 8.1 leaves `oath_shards` at 0); `godot/scripts/ui/view_models/affinity_view_model.gd` (the scene-free read-DTO exact-key pattern if you build a `RunEndOutcome` read).
- **Tests:** mirror the domain — `godot/tests/unit/core/test_complete_run_command.gd` (or the split-command names) for the command; extend `godot/tests/unit/core/test_domain_event.gd` for the `run_failed` event + the broadened `run_completed` outcome + the `expected_ids` pin. Tests extend `res://tests/unit/test_case.gd` and are registered in the headless runner (`res://tests/unit` / `res://tests/integration` auto-discovery). Reuse the existing run-command test fixture style (build a `RunState` via `RunStartCommand`/`new_run` + a generated `RouteState`, parked at a node) from `test_node_resolve_placeholder_command.gd`.
- **Naming:** `snake_case` files, `PascalCase` class names (`CompleteRunCommand`), `UPPER_SNAKE_CASE` constants (`RUN_COMPLETED_OUTCOME_VICTORY`, the cause/destination markers), `*Command` suffix for the command, past-tense event id (`run_failed`). [Source: `project-context.md` Naming Rules + Code Organization Rules]

### Project Context Rules

(Extracted from `project-context.md` — the rules that bind THIS story's implementation domain.)

- **Engine/language:** Godot 4.6.3 stable standard build, typed GDScript. No .NET/C#. Production code under `godot/`. [Technology Stack]
- **Domain owns truth; presentation mirrors:** the scene-independent domain model owns run truth (phase, route, events). The run-END command + the flow signal are PURE DOMAIN — no scene node, no `Control`, no autoload-owned state, no `.tscn`. The outpost destination is a DATA fact; presentation (8.6) consumes it. [Engine-Specific Rules]
- **Commands validate-then-mutate + emit past-tense events; ZERO partial state on reject (the 4.3 run-command idiom):** the run-END command takes `RunState` DIRECTLY (no `RunActionContext` wrapper), rejects `sequence_id <= 0` FIRST, builds the event ONLY after the (legal) transition, returns a byte-identical no-mutation `RunState` + ZERO events on any reject. ONE stable top-level error code per failure class; the precise reason rides metadata. [Determinism & Simulation Rules; Run Progression & Route Rules]
- **Append-only `DomainEvent.Type` enum, wired end-to-end:** `RUN_FAILED` is appended at the enum END (NEVER renumbered) + wired (factory + payload validator + both id maps + JSON round-trip + per-field malformed negatives + the exhaustive `expected_ids` pin). Do NOT re-create/rename/duplicate the `run_completed` event — BROADEN its outcome; later epics (9) CONSUME the boss boundary. [Run Progression & Route Rules: "Do not re-create, rename, or duplicate the 4.5 run_completed event ... Do not renumber the event enum"]
- **Named RNG streams; gameplay randomness draws its assigned stream:** 8.1 draws ZERO RNG; `required_streams()` UNCHANGED; never `randi`/`randf`/a fresh `RandomNumberGenerator`. [Determinism & Simulation Rules]
- **Headless-first:** the run-END command + the flow signal MUST run without rendering/audio/UI scenes/presentation/scene-tree state. [Engine-Specific Rules; NFR14]
- **Save = versioned domain snapshots; the 23-key `RunSnapshot` gate is pinned:** 8.1 adds NO new save key + NO migration (the terminal phase already persists via the nested `run_phase`). Do NOT add a top-level `RunSnapshot` key for run-progression state; nest under `route_state` if anything were needed (nothing is). Snapshots are pure reads. [Save/Snapshot Rules]
- **Manual-seed / meta gate:** a manual-seed run is NEVER meta-eligible (`meta_progression_eligible == not is_manual_seed`, lockstep with `oath_shard_eligible`). 8.1 READS this for the flow signal; the actual meta gate + awarding is Epic 8 (8.3). Do NOT let a manual-seed/debug run grant progression. [Critical Don't-Miss Rules]
- **DIFFICULTY IS A HARD NON-GOAL:** run-END resolution introduces no difficulty knob; the outcome/cause are readable markers, not multipliers. [project-context]
- **Static content is a code constant (no JSON pipeline):** `data/source`/`data/resources` stay EMPTY; no `.tres`/JSON. (8.1 adds no content.) [Technology Stack — Static-content storage]
- **`godot` is NOT on the Bash PATH:** run the headless suite via PowerShell or the console binary `C:/Users/Rasmus/Godot_v4.6.3-stable_win64.exe/Godot_v4.6.3-stable_win64_console.exe`; apply the false-PASS grep guard (grep raw run output for `SCRIPT ERROR|Parse Error|Compile Error|Failed to load script`, never trust the summary PASS line alone). [Technology Stack — last bullet; the standing false-PASS guard]

### References

- [Source: `_bmad-output/planning-artifacts/epics.md` lines 2017-2042 (Epic 8 intro + Story 8.1 user story + ACs) + lines 2044-2204 (Stories 8.2-8.7, the cross-story context that defines what is DEFERRED out of 8.1: 8.2 summary, 8.3 meta/Oath-Shard awards, 8.4 Echoes/Seal-fragments, 8.5 first-death line, 8.6 outpost menu, 8.7 meta/summary save-load tests)]
- [Source: `_bmad-output/planning-artifacts/epics.md` FR32 (death → return to last outpost), FR28 (manual-seed no-progression → Epic 8), FR59/FR60/FR61/FR62 (the broader outpost/summary/narrative/victory context owned by 8.3-8.6 + Epic 9)]
- [Source: `_bmad-output/auto-gds/retro-notes/epic-7.md` (the Epic-7 retrospective) — §7 "Next-Epic Preview — Epic 8" (the dependencies + risks 1-4: Oath-Shard awarding is the central Epic-8 mutation crossing the run/meta boundary; the first-death line is optional and off the critical path; the status-hygiene reflex; the live-tactical-loop residual is NOT an Epic-8 dependency); §6 + §8 Action T3 (the event-id-map exhaustiveness hardening — the gate that fails-loud on a new event); §8 Actions T1/T2/P2/T4/T5/T6/D1/D2 (the carried-forward debt + which items 8.1 must keep parked)]
- [Source: `_bmad-output/implementation-artifacts/deferred-work.md` — the Oath-Shard awarding + meta profile (Epic 8) Untouched notes in the 7.1/7.3/7.4/7.5/7.6 dev-story sections (8.1 opens the boundary it sits behind); the live-tactical-loop / combat-death-source residual (out of scope); the parked items 8.1 must not reopen]
- [Source: `project-context.md` — Run Progression & Route Rules (the run-command idiom, the run-completed boundary, the `_legal_next_phases` table, the nested `run_phase` persistence, "Do not re-create/rename/duplicate run_completed", "Do not renumber the event enum"); Determinism & Simulation Rules; Save/Snapshot Rules (the 23-key gate); the named-RNG rule; the difficulty non-goal; the manual-seed/meta-gate Critical Don't-Miss rules; the headless test command + the `godot`-not-on-PATH note]
- [Source: `godot/scripts/run/run_state.gd` (the phase machine — `PHASE_COMPLETED`/`PHASE_FAILED` lines 31-35, `is_terminal` 215-216, `transition_to` 225-232, `_legal_next_phases` 550-565, `validate` 235-259, the nested `run_phase` via `RUN_PHASE_KEY`/`to_run_snapshot_fields` 356-393 — the terminal transitions to DRIVE)]
- [Source: `godot/scripts/core/commands/node_resolve_placeholder_command.gd` (`_resolve_boss` lines 211-279 — the mutate-then-event two-step transition + the `node_placeholder_resolved` + `run_completed` emit; the 4.3 validate idiom + the `sequence_id <= 0` guard lines 97-153; the Epic-9-reuses-this-boundary contract lines 22-27 — the TEMPLATE to mirror, the boss behavior to NOT change)]
- [Source: `godot/scripts/run/run_orchestrator.gd` (`_resolve_boss` lines 766-783 — the boss completion; the `run_already_terminal` guard lines 189-190 + the `seated_run_terminal` guard 163-167 — the AC3 idempotency model; `run_completed_event`/`run_completed_outcome` accessors; the OPTIONAL dispatch-hook home — do NOT auto-wire a death into `run_to_completion`)]
- [Source: `godot/scripts/core/events/domain_event.gd` (`Type` enum lines 6-39 + the `EVENT_ID_*` consts 41-72 — append `RUN_FAILED` at the end; the `run_completed` factory 232-246 + `_validate_run_completed_payload` 938-952 + the `RUN_COMPLETED_OUTCOME_BOSS_PLACEHOLDER` marker 116-121 — broaden the outcome allowlist; the validator dispatch 786-813; `id_for_type` ~1732 + `type_for_id` ~1800 — both id maps to extend; the SYSTEM-event/no-actor + defensive-payload-normalize discipline)]
- [Source: `godot/tests/unit/core/test_domain_event.gd` lines 1947-2005 (`_event_identifiers_are_stable_machine_ids` — the `expected_ids` map + the EXHAUSTIVENESS PIN `expected_ids.size() == Type.size() - 1` + the per-member iteration; the Story-6/7 append-comment style to mirror for `run_failed`; the per-event JSON-round-trip + malformed-field test pattern to follow)]
- [Source: `godot/scripts/run/risk_economy_state.gd` (`oath_shard_eligible` lines 21-25, 64, 94-105 — the run-end eligibility gate to READ; the GDD manual-seed-never-eligible invariant)]
- [Source: `godot/scripts/save/snapshots/run_snapshot.gd` (the top-level fields incl. `oath_shards` line 38 + `meta_progression_eligible` line 25; `from_route_position` lines 217-283 with the comment lines 264-266 confirming `oath_shards` is the AWARDED count Epic 8.3 owns + left 0 in v0 — 8.1 keeps it 0; the 23-key gate context)]
- [Source: `godot/scripts/ui/view_models/affinity_view_model.gd` (the scene-free read-surface exact-key/fail-closed pattern to mirror if you build a `RunEndOutcome` read DTO)]
- [Source: `_bmad-output/implementation-artifacts/7-6-darkness-fairness-and-memory-pressure.md` (the immediate-predecessor story-file STRUCTURE + the house scope-fence / deferred-work-disposition / Project-Context-Rules format to mirror; the false-PASS grep guard + the headless-command-via-PowerShell discipline)]

## Dev Agent Record

### Agent Model Used

Opus 4.8 (1M context) — auto-gds dev-story delegate. Story implemented across two delegate runs: an
initial `gds-dev-story` delegate that produced the bulk of the code but died to a Claude Code process
exit mid-Phase-5 (WIP-checkpointed at git 4861a11), then a resume-verify continuation that diagnosed +
fixed the two remaining suite failures and finalized the story.

### Debug Log References

- Full headless suite (console binary, `--quit-after 10`): **"Headless tests passed."**, exit code 0,
  142 test files PASS, ZERO FAIL. False-PASS grep guard (`SCRIPT ERROR|Parse Error|Compile Error|Failed
  to load script`) clean.
- The documented-expected negative-path diagnostics remain (non-failing, non-guarded): the int64-overflow
  `root_seed` boundary `ERROR: Cannot represent 99999999999999999999 as a 64-bit signed integer` x2 (a
  benign `String.to_int()` push_error on the pre-existing Story-4.6 out-of-range-seed REJECTION test — the
  value is still correctly rejected; this diagnostic predates 8.1 and is byte-identical to the green
  baseline `_has_decimal_string_payload`, NOT a regression), `RouteNode parse failed: invalid_node_type`,
  and the save/settings `Parse JSON failed`/`got 'this'`/`Expected key` negatives.

### Completion Notes List

**Resume-continuation fix (the 2 checkpoint failures).** The WIP checkpoint had exactly 2 suite failures,
both from a SINGLE root cause: the `DomainEvent.run_completed(...)` factory unconditionally injected
`payload_value["boss_node_id"] = String(payload.get("boss_node_id", ""))`, so EVERY generic (non-boss)
completion payload carried a `boss_node_id: ""` key. That tripped the two `assert_false(...has("boss_node_id"))`
assertions — one in `test_complete_run_command.gd` (the generic-completion path) and one in the new
`_run_completed_completion_outcome_serializes_and_parses` test in `test_domain_event.gd`. **Fix:** made the
factory set `boss_node_id` ONLY when the caller supplies the key (`if payload.has("boss_node_id")`). The
boss path (`NodeResolvePlaceholderCommand._resolve_boss`) always passes `boss_node_id`, so the boss payload
keeps its `boss_node_id` key; a generic completion omits it, so the key is absent (not present-but-empty).
(For the boss payload as a WHOLE: it is NOT byte-identical after 8.1 — it additively gains a backward-compatible
`next_destination: "outpost"` key; only the Epic-9 contract surface — event type, `outcome == "boss_placeholder"`,
`boss_node_id` — is preserved. See the resolved boss-payload `[Review][Decision]`.) The
second "failure" the resume brief flagged (the `to_int` overflow ERROR line in `test_domain_event.gd`) was a
misdiagnosis: `_has_decimal_string_payload` is byte-identical to the green baseline (git-confirmed), the
ERROR is a non-fatal `push_error` from Godot 4.6.3's `String.to_int()` that still returns a saturated value,
the round-trip check correctly rejects the out-of-range seed, and the test's sole real failure was the
shared `boss_node_id` assertion. No change was made to the pre-existing, baseline-green int64 seed validator
(out of scope; it fixes no failure and risks the delicate max-int64 boundary tests).

**[Decision] — Command shape (A, single outcome-parameterized command).** `CompleteRunCommand`
(`godot/scripts/core/commands/complete_run_command.gd`) — one command that takes an explicit `outcome:
StringName` classified at validate time: a death cause (in `DomainEvent.RUN_FAILED_CAUSES`) → `PHASE_FAILED`
+ `run_failed`; the completion marker (`DomainEvent.RUN_COMPLETED_OUTCOME_COMPLETED`) → `PHASE_COMPLETED` +
`run_completed`; anything else → `unknown_run_end_outcome` fail-loud before any mutation. Follows the 4.3
run-command idiom verbatim (takes the live `RunState` directly, rejects `sequence_id <= 0` FIRST, validate-
then-mutate, byte-identical no-mutation + zero events on any reject, builds the event only after the legal
transition). Draws ZERO RNG.

**[Decision] — run_failed event + cause shape (allowlist).** New `DomainEvent.Type.RUN_FAILED` /
`run_failed` SYSTEM event (no actor), appended at the enum END (never renumbered), wired end-to-end (factory
+ `_validate_run_failed_payload` + both id maps + JSON round-trip + per-field malformed negatives + the
`expected_ids` exhaustiveness pin). Cause is a pinned lower_snake ALLOWLIST `RUN_FAILED_CAUSES = [hero_death,
level_defeat, boss_defeat, abandoned]` (mirrors the `*_CATEGORIES` allowlist-const pattern). `node_id` is a
plain hyphen-tolerant string, OPTIONAL/empty-tolerant (an abandoned-at-a-choice run has no node);
`cleared_node_count` is non-negative integral; `next_destination` is value-pinned to the outpost marker.

**[Decision] — run_completed outcome broadening + boss-field tolerance.** Added
`RUN_COMPLETED_OUTCOME_COMPLETED := &"completed"` alongside the untouched `RUN_COMPLETED_OUTCOME_BOSS_PLACEHOLDER`.
`_validate_run_completed_payload` now accepts an ALLOWLIST (boss_placeholder OR completed); a stray/garbage
outcome (e.g. `victory` — deliberately left free for Epic 9's real boss victory) is still rejected.
`boss_node_id` is REQUIRED only for the `boss_placeholder` outcome; for a `completed` outcome it is tolerated
ABSENT (and a present-but-non-string `boss_node_id` is still rejected). The factory now defaults
`next_destination` to the outpost marker, and the validator REQUIRES it for BOTH outcomes — the boss factory
supplies the default automatically, so the boss path's existing test stays green (the boss `run_completed`
now also carries `next_destination == outpost`, defaulted, with no boss-command change).

**[Decision] — Flow-signal placement (all three surfaces).** The `next_destination == outpost` domain flow
fact (FR32) is carried on (1) the command `ActionResult.metadata`, (2) BOTH emitted event payloads
(`run_failed` + `run_completed`), and (3) a scene-free read DTO. NOT a scene transition / `.tscn` (8.6 owns
the outpost scene + navigation). `RUN_END_DESTINATION_OUTPOST := &"outpost"` is the single lower_snake const.

**[Decision] — Read DTO built.** `RunEndOutcome` (`godot/scripts/run/run_end_outcome.gd`, a scene-free
`RefCounted`) with `for_failed(run, cause)` / `for_completed(run, outcome)` builders and a pinned exact-key
`to_dictionary()` = `{has_ended, phase, outcome_or_cause, next_destination, meta_progression_eligible}`
(mirrors the `AffinityViewModel` exact-key, fail-closed, no-live-handle discipline). It READS
`run.meta_progression_eligible` (lockstep with `is_manual_seed`) for the eligibility field — it grants/denies
NOTHING (FR28 enforcement + Oath-Shard awarding are 8.3). A null / non-terminal / wrong-phase run projects the
fail-closed empty fact (`has_ended == false`). Pure read (repeated reads identical, zero RNG, zero events).

**[Decision] — Idempotency = stable error (`run_already_terminal`).** AC3 is satisfied with the stable
`run_already_terminal` error (mirroring `RunOrchestrator.resolve_current_node`'s guard) rather than an
idempotent no-op ok. A re-resolution of an already-terminal run emits ZERO new events + leaves the `RunState`
BYTE-IDENTICAL (asserted via `to_dictionary()` before/after) — so nothing can be granted twice. A double-fail
and a fail-then-complete are both blocked (terminal is terminal). v0 grants nothing at run-END (awarding is
8.3), so "not granted twice" is structurally satisfied today; this guard is the seam 8.3's Oath-Shard
awarding must run BEHIND (the award must never re-fire on a re-completion).

**[Decision] — Transition table UNCHANGED (boss two-step, no new edge).** The completion path drives the
boss's existing `ACTIVE_ROUTE → NODE_RESOLUTION → COMPLETED` two-step from `ACTIVE_ROUTE`, or a single
`NODE_RESOLUTION → COMPLETED` step from `NODE_RESOLUTION`. The death path drives the already-legal
`ACTIVE_ROUTE/NODE_RESOLUTION → FAILED` edges. `RunState._legal_next_phases` is completely untouched — no new
edge added.

**Orchestrator dispatch hook (thin, caller-driven).** `RunOrchestrator.resolve_run_end(outcome)` +
`run_failed_event()` / `run_failed_cause()` / `run_end_destination()` accessors mirror `_resolve_boss`'s
command-dispatch + event-capture shape. It is NOT wired into `run_to_completion` / `_resolve_combat` / the
auto-resolve loop (there is NO live death source in v0 — combat auto-resolves to success), so a death NEVER
auto-fires; the `_resolve_boss` boss-completion behavior + the boss `run_completed` boundary (Epic 9 depends
on it) are untouched.

**Scope fences confirmed.** Enum append-only + `RUN_FAILED` pinned in `expected_ids` (the Story-7.1
exhaustiveness gate `expected_ids.size() == Type.size() - 1` + per-member iteration is green); the boss Epic-9
CONTRACT (event type `run_completed`, `outcome == "boss_placeholder"`, `boss_node_id`) UNCHANGED + boss
command/test green (the boss `run_completed` payload is NOT byte-identical — it additively gains a backward-
compatible `next_destination: "outpost"` key; boss-payload `[Review][Decision]` ACCEPTED Option A 2026-06-30);
`RngStreamSet.required_streams()` UNCHANGED (7
streams, ZERO RNG in new code — grep-confirmed no `randi`/`randf`/`RandomNumberGenerator`); 23-key
`RunSnapshot` UNCHANGED + `oath_shards` stays 0; `meta_progression_eligible` READ-ONLY; rules kernel + data
dirs + scenes/assets untouched; no `.tscn`. 8.1 touches no `scripts/generation/` — seed-regression
fingerprints byte-identical.

**8.1 OPENS Epic 8.** It ships the run-END boundary (the terminal phase + the `run_failed`/broadened
`run_completed` events + the `next_destination == outpost` flow signal) that the run SUMMARY (8.2), the
Oath-Shard awarding + meta profile (8.3), and the outpost menu (8.6) all consume. The `run_failed.cause` +
`run_completed.outcome` are the INPUTS 8.2's summary reads; the AC3 idempotency guard is the seam 8.3's
awarding sits behind. See `deferred-work.md` for the deferred dispositions.

### File List

**New (production):**
- `godot/scripts/core/commands/complete_run_command.gd` — `CompleteRunCommand` (the run-END resolution command).
- `godot/scripts/run/run_end_outcome.gd` — `RunEndOutcome` (the scene-free run-END read DTO / flow signal).

**Modified (production):**
- `godot/scripts/core/events/domain_event.gd` — appended `RUN_FAILED` event (factory + validator + both id
  maps + `EVENT_ID_RUN_FAILED`); added `RUN_FAILED_CAUSES`, `RUN_COMPLETED_OUTCOME_COMPLETED`,
  `RUN_END_DESTINATION_OUTPOST` consts; broadened `_validate_run_completed_payload` (outcome allowlist +
  boss-field tolerance + `next_destination`); made the `run_completed` factory set `boss_node_id` only when
  supplied (the resume fix) + default `next_destination`.
- `godot/scripts/run/run_orchestrator.gd` — added the thin `resolve_run_end(outcome)` dispatch hook +
  `run_failed_event()`/`run_failed_cause()`/`run_end_destination()` accessors + the backing fields.

**New (tests):**
- `godot/tests/unit/core/test_complete_run_command.gd`
- `godot/tests/unit/run/test_run_end_outcome.gd`

**Modified (tests):**
- `godot/tests/unit/core/test_domain_event.gd` — added the run_failed + broadened-run_completed per-event
  tests + the `expected_ids` `RUN_FAILED` pin.
- `godot/tests/unit/run/test_run_orchestrator.gd` — added `resolve_run_end` dispatch-hook coverage.

**Tracking:**
- `_bmad-output/implementation-artifacts/8-1-run-completion-and-return-to-outpost-flow.md` (this file — Status,
  task boxes, Dev Agent Record).
- `_bmad-output/implementation-artifacts/deferred-work.md` (the 8.1 dispositions).
- `_bmad-output/implementation-artifacts/sprint-status.yaml` (`8-1 → review`, `last_updated` refreshed).

## Review Findings

**Round 1 of 3**

Reviewer: gds-code-review (Blind Hunter + Edge Case Hunter + Acceptance Auditor). Target: branch
`story/8-1-run-completion-and-return-to-outpost-flow` diff vs `main`, scope `godot/` (8 files, ~1465 lines).
Spec: this story file. Full headless suite re-verified GREEN at review time (142 files pass / 0 fail; false-PASS
grep guard clean; `git diff --check` clean; zero `randi`/`randf`/`RandomNumberGenerator` in new production code).

**Verdict: APPROVE.** All three ACs are faithfully satisfied and every scope fence holds. AC1 (death →
`PHASE_FAILED` + `run_failed` with an allowlisted cause + `next_destination == outpost`), AC2 (completion →
`PHASE_COMPLETED` + broadened `run_completed` `completed` outcome + outpost signal, from both `ACTIVE_ROUTE` via
the boss two-step and `NODE_RESOLUTION` directly; boss `boss_placeholder` path preserved), and AC3
(`run_already_terminal` stable error, zero second event, byte-identical `RunState`; double-fail + fail-then-complete
both blocked) are all covered by tests. The `DomainEvent.Type` enum stayed append-only with the `expected_ids`
exhaustiveness pin updated; the transition table, `required_streams()`, and the 23-key `RunSnapshot` are untouched.
Severity counts: **Critical 0 / High 0 / Medium 0 / Low 4.** No blocking findings. The single `[Decision]` is a
forward-looking architecture confirmation, not a defect.

- [x] [Review][Decision] Boss `run_completed` payload now carries an added `next_destination == "outpost"` key —
  confirm this is acceptable before Epic 9 builds on the boundary. The story/context framed the boss path as
  "byte-identical," but broadening the `run_completed` factory to default `next_destination` (and the validator to
  REQUIRE it for BOTH outcomes) means the Story-4.5 boss `run_completed` event, emitted by
  `NodeResolvePlaceholderCommand._resolve_boss` (which passes no `next_destination`), now gains
  `next_destination: "outpost"` in its payload. The invariant surface Epic 9 + `project-context.md` name — the
  event TYPE, `outcome == "boss_placeholder"`, and `boss_node_id` — is fully intact; the change is an ADDITIVE,
  backward-compatible payload key consistent with the project's append-only event discipline, and no consumer
  asserts the boss payload's exact key set (verified: `test_node_resolve_placeholder_command.gd` and
  `test_node_type_resolution_walk.gd` assert individual keys + JSON round-trip only, so the suite is green). This
  is flagged only because the deliberate "boss stays byte-identical" wording is now slightly inaccurate — a human
  product/architecture owner should bless the boss event gaining `next_destination` (recommended: ACCEPT; it is
  harmless and forward-consistent) or, if strict byte-identity of the boss event is required, gate
  `next_destination` to the `completed` outcome only and leave the boss payload unchanged. [Evidence:
  `godot/scripts/core/events/domain_event.gd` `run_completed` factory next_destination default + `_validate_run_
  completed_payload` next_destination requirement for both outcomes; `godot/scripts/core/commands/node_resolve_
  placeholder_command.gd:264-268 (boss run_completed passes no next_destination)]
  - **RESOLVED: Option A (accept additive key) per human decision 2026-06-30.** The shared `run_completed`
    factory/validator is kept exactly as implemented: `next_destination` stays present on BOTH the `completed` and
    `boss_placeholder` outcomes (NOT gated to `completed` only). No production behavior changed for this decision —
    the resolution is documentation + test-naming only. The boss `run_completed` event now ADDITIVELY and
    backward-compatibly carries `next_destination: "outpost"`; the Epic-9 boss contract (event type `run_completed`,
    `outcome == "boss_placeholder"`, `boss_node_id`) is unchanged, and no consumer asserts the boss payload's exact
    key set. The "boss stays byte-identical" framing was corrected wherever it appeared (the AC2 Dev Note, the
    Option-A scope-boundary description, the resume-fix + scope-fences Completion Notes, and the two
    `domain_event.gd` code comments on the `run_completed` factory + `_validate_run_completed_payload`). The
    misnamed guard test was renamed to `_boss_run_completed_preserves_epic9_contract_with_additive_next_destination`
    (see the resolved `[Review][Patch]` below), and its assertions reflect the intact Epic-9 identifying triple
    plus the additive `next_destination == "outpost"`.

- [x] [Review][Patch] Misleading test name/comment: `_boss_run_completed_path_stays_unchanged`
  [godot/tests/unit/core/test_complete_run_command.gd:330]. The test asserts the boss `run_completed` now ALSO
  carries `next_destination == "outpost"` (line 349) — i.e. the payload CHANGED (gained a key); only the outcome
  VALUE and `boss_node_id` are unchanged. Reword to "boss outcome value stays boss_placeholder" (or similar) so the
  name does not imply payload byte-identity. Trivial, non-blocking; left as an action item.
  - **RESOLVED 2026-06-30.** Renamed the test (and its section header + docstring) from
    `_boss_run_completed_path_stays_unchanged` to
    `_boss_run_completed_preserves_epic9_contract_with_additive_next_destination` (call site + definition in
    `test_complete_run_command.gd`), so the name no longer implies boss payload byte-identity. The docstring now
    states the Epic-9 contract (event type `run_completed`, `outcome == "boss_placeholder"`, `boss_node_id`) is
    unchanged while the payload ADDITIVELY carries `next_destination == "outpost"`. Assertions unchanged (they
    already pin the Epic-9 identifying triple and the additive outpost destination). This is the same rename the
    resolved boss-payload `[Review][Decision]` above calls for.

- [x] [Review][Defer] `_resolve_completed` two-step transition is not atomic vs the command's own
  "byte-identical no-mutation `RunState` on ANY reject" promise [godot/scripts/core/commands/complete_run_command.gd:200-221]
  — deferred, latent (unreachable today) + shared with the pre-existing boss pattern. If
  `ACTIVE_ROUTE → NODE_RESOLUTION` succeeded but `NODE_RESOLUTION → COMPLETED` then failed, the run would be left
  MUTATED in `NODE_RESOLUTION` (non-terminal) while the command returns `wrong_run_phase` with zero events. Given
  the current `_legal_next_phases` table, once step 1 succeeds step 2 CANNOT fail, so this never fires — but the
  contract is silently broken if the table ever changes. `NodeResolvePlaceholderCommand._resolve_boss` has the
  identical two-step shape (8.1 replicates, does not introduce, the pattern). A cheap future hardening: snapshot
  `phase` before step 1 and restore it on step-2 failure, or assert both edges' legality up front. Not actionable
  now (no reachable failure; fixing only 8.1 would diverge from the boss pattern — address both together if ever).

- [x] [Review][Defer] `RunEndOutcome.for_failed` / `for_completed` do not validate the `cause` / `outcome`
  against the event allowlists [godot/scripts/run/run_end_outcome.gd:78-102] — deferred, low (design-consistency,
  no reachable defect). A caller could project `for_failed(run, &"garbage")` and the DTO would surface
  `outcome_or_cause: "garbage"`, whereas the corresponding `run_failed` EVENT would reject that cause via
  `RUN_FAILED_CAUSES`. The read DTO is a passive projector of already-command-validated markers (in the live flow
  it only ever receives an allowlisted cause/outcome from `CompleteRunCommand`), so there is no reachable
  inconsistency today; the read surface and the strict event validators simply disagree on what a valid marker is
  in principle. If a future consumer builds a `RunEndOutcome` from untrusted input, add an allowlist guard that
  falls back to `_empty()`. Not actionable now.

**Dismissed as noise (not persisted as action items):** mixed outcome-comparison styles in `validate()`
(StringName `.has()` for the death branch vs `String(...)==...` for the completion branch — both correct,
cosmetic); `_validate_run_completed_payload` tolerating a present-but-empty `boss_node_id` on the `completed`
outcome (explicitly documented as tolerated; the command never emits it); `cleared_node_count` unbounded /
no int64 encoding (bounded by construction — nodes-per-run; matches the pre-existing `run_completed` treatment);
`resolve_run_end` sharing `_run_completed_event`/`_run_completed_outcome` capture fields with the boss path (safe —
a terminal run blocks a second resolve); thin `cleared_node_count` coverage at ==1 in the command tests (the
multi-count case is covered by `test_node_resolve_placeholder_command.gd` and `test_node_type_resolution_walk.gd`).
