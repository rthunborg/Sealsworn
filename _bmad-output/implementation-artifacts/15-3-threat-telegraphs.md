---
baseline_commit: 1d78543
---
# Story 15.3: Threat Telegraphs

Status: ready-for-dev

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a player,
I want to see which tile a marked attack is about to hit,
so that a detonation is something I can dodge rather than something that happens to me.

## Context & Why This Story Exists

Epic 15 ("Playtest Response") is the **third pre-ship playtest-response epic** (the Epic-13/14 pattern), added 2026-07-24 after a post-Epic-14 agent-driven desktop playtest confirmed the loop is **completable end-to-end for the first time** but surfaced 20 new findings (record `playtest-sessions/agent-playtest-2026-07-20.md`; triage `…-triage.md`; `sprint-change-proposal-2026-07-24.md`). Story 15.1 (Band 1) un-hid the HUD/log; Story 15.2 corrected the attack-preview number. Story 15.3 continues **Band 2 — Correctness & unwired surfaces (15.2–15.7)** and closes finding **F5** (the threat-telegraph pair).

> **F5 — a marked detonation is invisible until it hurts you, and its flash lands on the wrong tile.** The Ash Seer marks the player's tile and detonates it a turn later (the shipped `tile_marked` → `marked_tile_detonated` domain pattern), but the board shows **no persistent danger indicator** during the pending window — the only cue is a half-second color pulse at mark time and again at detonation, with nothing on the tile in between, so the danger the domain already telegraphs never reaches the player as something they can act on. And the playtest observed the **detonation flash rendering on the hero's *current* tile while the log correctly placed the detonation on the *previous* (marked) tile** — a presentation anchor bug. The proposal's fix line (§ mapping table, row 15-3): *"Persist the marked-tile telegraph from mark→resolution (shape/glyph, NFR9); anchor the detonation flash to the domain-resolved cell."* Classified **presentation over existing domain events; no domain/RNG change; fingerprints byte-identical.**

**Root cause (grep-verified, see "The load-bearing architecture reality").** The **domain is complete and correct**: `EnemyCommandAdapter._apply_detonation` marks `marked_cell`, resolves `hit = target.position == marked_cell`, and emits a `marked_tile_detonated` event carrying the **authoritative `marked_cell`** (+ `telegraph_id`), plus a `damage_applied` **only on a hit** — and the combat log reads that `marked_cell` verbatim (`combat_explanation_log.gd:74-79`), which is why the **log placed the detonation on the right (previous) tile**. The gap is entirely in **presentation**:

1. **No persistence.** The only marked-tile visual is `TacticalCombatFeedback.plan()` mapping a *new* `tile_marked`/`marked_tile_detonated` event to a **transient** telegraph pulse (`tactical_combat_feedback.gd:95-102`) that the presenter plays once as a 0.5s fade-in/out `ColorRect` (`_animate_telegraph`, `tactical_board_presenter.gd:1234-1243`). Between mark and detonation the marked cell is **bare**. AC1 needs a telegraph that **persists from mark until it resolves**.
2. **Color-only.** `TELEGRAPH_PULSE_COLOR` (`tactical_board_presenter.gd:160`) is a semi-transparent orange fill — a **hue-only** cue with no shape/glyph/label, violating **NFR9** for the persistent danger indicator.
3. **Wrong flash anchor.** The detonation's `damage_applied` payload carries **no cell** (`enemy_command_adapter.gd:283-300`); `TacticalCombatFeedback` resolves that hit's flash cell from the VM `occupants` (the victim's **current** position — `tactical_combat_feedback.gd:76-87`). When the victim's rendered cell differs from `marked_cell`, the **flash lands on the current tile while the log/telegraph correctly show the marked tile** — the exact F5 observation. The authoritative cell is the domain event's `marked_cell`; the flash must anchor there.

**This story is a PRESENTATION + READ-MODEL fix. It corrects and enriches the on-board telegraph over the shipped, pinned domain events — it changes NO domain behavior.** The Ash-Seer / boss telegraph **resolution** (`enemy_command_adapter.gd`, `pending_telegraph_state.gd`, `prototype_enemy_ai.gd`, `boss_command_adapter.gd`, the combat driver + its pinned `ash_seer` replay fixtures) stays **byte-identical**: the domain already marks and detonates the right cell; only the *display* of that domain truth was wrong/absent. This is **presentation over shipped, pinned domain contracts** — the same ratified posture as the rest of Epic 15: **every seed-regression fingerprint stays byte-identical across all of Epic 15** (proposal §2.1; epics.md Epic-15 sequencing note, line 541), difficulty stays a hard non-goal (this story changes **no** number the game resolves), no new autoload, assertable logic lives in scene-free `RefCounted` seams. The four ratified Epic-15 design decisions do **NOT** touch this story: **D1 HP-persistence → 15.5, D4 shards-on-death → 15.5, D2 move-confirm → 15.7, D3 class-weighted rewards → 15.6.** Do not pull any of them in.

### ⭐ THE CRUX — persist the marked-tile telegraph as a SHAPE/glyph derived from the existing event log, and anchor the detonation effect to the domain event's `marked_cell` — all over the existing `event_log_summary` slot, no new board-VM key, no domain touch (read before Task 1)

Four boundaries define this story. Get them wrong and you either move a fingerprint (a firing offence in Epic 15), add a board-VM key, or ship a telegraph that still lies/hides.

1. **The persistent telegraph is a projection of ACTIVE marks over the EXISTING `event_log_summary` slot — not a new domain query, not a new board-VM key.** A mark is **active** from its `tile_marked` event until the matching `marked_tile_detonated` (paired by `telegraph_id`). Project that set from the VM `event_log_summary` array (the **full** fight log — see boundary 4) in a scene-free `RefCounted` seam, exactly as `TacticalCombatFeedback` already reads the same slot. Render a **persistent** on-board glyph on each active marked cell every render, cleared when its detonation appears. The domain `pending_telegraphs` state exists (`pending_telegraph_state.gd`) but **do NOT surface it as a new board-VM slot** — that would add a 17th board-VM key and a new domain query, both forbidden (AC2: "no new domain query"; AC3: the 16-key gate holds).

2. **The persistent telegraph MUST carry a non-color channel (shape / glyph / label), not hue alone (NFR9), and stay legible under every affinity floor and in fog/darkness.** The current orange `ColorRect` pulse is color-only. Draw a distinct **SHAPE** — the ratified precedent is right here in the same op list: the 14.10 range highlights (inset ring / corner ticks — "never hue alone", `tactical_board_presenter.gd:1388-1394`), the `HAZARD_OUTLINE_COLOR` danger outline (`1348-1350`), and the 14.2 armed-target double outline (`1396-1404`). A danger-diamond / bright bordered glyph (optionally a `!` or countdown label) drawn with its own outline reads over the Scorched/Flooded/Cursed/Darkness floor variants and over the fog fill. Render it **regardless of the marked cell's `visibility_state`** (a telegraphed danger is known even if the player has stepped into memory/fog).

3. **The detonation EFFECT anchors to the DOMAIN event's cell (`marked_tile_detonated.marked_cell`), never to a victim occupant position.** The `marked_tile_detonated` telegraph branch already reads `details.marked_cell` (correct). The **damage flash** for the detonation must do the same — today it rides the `damage_applied`→`occupants` path (current victim cell). The detonation-damage entry is distinguishable by its `weapon_id == "ash_seer_detonation"` source marker (the same marker-keying `CombatExplanationLog._is_affinity_hazard_damage` uses for `scorched_hazard`, `combat_explanation_log.gd:107-108`) **or** by pairing it with the same-batch `marked_tile_detonated` (`telegraph_id` / adjacent `sequence_id`). Route the detonation's effect cell to `marked_cell`. **This correctness is headlessly assertable** (a unit test on the seam: given a detonation batch whose victim's `occupants` cell ≠ `marked_cell`, the detonation effect cell == `marked_cell`) — write that test; it is the F5 guard-rail and it simultaneously **closes the 14-3 deferred fixture gap** (below).

4. **`event_log_summary` is the FULL fight log — the projection is reliable across the whole fight.** The presenter sources it from `CombatExplanationLog.new().build_entries(_session.event_log())` (`tactical_board_presenter.gd:429`), and `InteractiveCombatSession.event_log()` returns the full accumulated `_event_log` (appended per event; reset only on `begin()`, `interactive_combat_session.gd:243-244`). The tail-limit to 8 lines is a **separate** display read (`TacticalCombatLogView`), NOT this slot. So a mark placed several turns ago is still present to pair against its detonation. (A seer mark is due `created_turn + 1`, so the active window is ~1 turn regardless — but the projection must not assume a window; pair by `telegraph_id`.)

### The load-bearing architecture reality (read before Task 1)

The marked-tile danger flows through this exact chain (grep-verified against source):

- **The domain (the source of truth — DO NOT TOUCH).** `EnemyCommandAdapter._apply_detonation` (`godot/scripts/tactical/turns/enemy_command_adapter.gd:232-312`): `marked_cell` comes from the pending mark (`254`); `hit = target.position == marked_cell` (`255`); it emits `DomainEvent.marked_tile_detonated(seq, enemy_id, target_id, marked_cell, telegraph_id, outcome, …)` (`259-278`) and, **only on a hit**, a `DomainEvent.damage_applied(seq+1, …)` whose payload is `_damage_payload(&"ash_seer_detonation", …)` — **carrying no cell** (`283-300`). The mark itself is `_apply_mark` → `DomainEvent.tile_marked(seq, enemy_id, target_id, target_cell, telegraph_id, {kind, …})` (`179-229`). Both event builders put `marked_cell` + `telegraph_id` into the payload (`domain_event.gd:983-1022`). The boss uses the **same** `tile_marked`/`marked_tile_detonated` vocabulary under `KIND_LARVAL_AVATAR_TELEGRAPH` (`pending_telegraph_state.gd:8-20`; `boss_command_adapter.gd:123-160`) — so a kind-agnostic projection covers the boss telegraph for free.
- **The log (already correct — the reason the log shows the RIGHT tile).** `CombatExplanationLog.build_entries(events)` (`godot/scripts/tactical/outcomes/combat_explanation_log.gd:6-15`) iterates the **full** event list; the `MARKED_TILE_DETONATED` line reads `event.payload.marked_cell` (`74-79`); each entry's `details` = `event.payload.duplicate(true)` (`101`), so **`details.marked_cell`, `details.telegraph_id`, and `details.weapon_id` are all present** on the log entries the VM carries.
- **The board VM slot the presentation reads (NO new key).** `TacticalBoardViewModel.to_dictionary()` is an **EXACT 16-key contract** (`godot/scripts/ui/view_models/tactical_board_view_model.gd:33-51`): `width, height, cells, occupants, selected_cell, selected_entity_id, preview, commit_flow, inspect, zoom, action_availability, turn, outcome, event_log_summary, layout, accessibility`. The presenter populates `event_log_summary` with the full log (`tactical_board_presenter.gd:422-435`). **The persistent-telegraph projection and the detonation-anchor read both source this existing `event_log_summary` slot (+ `occupants` for any occupant-relative logic) — add NO 17th key.**
- **The presentation gap (the files to FIX).**
  - `godot/scripts/ui/view_models/tactical_combat_feedback.gd` (Story 14.3) — the scene-free plan seam. `plan(event_log_summary, since_sequence_id, occupants)` maps `damage_applied`→a hit flash at the **occupant** cell (`76-94`), and `tile_marked`/`marked_tile_detonated`→a **transient** telegraph entry at `details.marked_cell` (`95-102`). `PLAN_KEYS` (`28-34`). **FIX locus:** anchor the detonation's damage effect to `marked_cell` (boundary 3); and add (here or in a sibling seam) the **active-marked-cell projection** for the persistent overlay (boundary 1). If you add a plan key or a new seam, pin its exact key set with a test (the exact-key discipline).
  - `godot/scripts/ui/presenters/tactical_board_presenter.gd` (13.1/14.3/14.10) — the live board Control. `_play_new_combat_feedback` (`1091-1114`) plays the transient plan; `_animate_telegraph` (`1234-1243`) is the color-only pulse; `_animate_hit` (`1188-1194`) the occupant flash; `_build_board_draw_ops` (`1322-1414`) composes the **one-pass** op list (fog/terrain → occupants → 14.10 range highlights → armed outline). **FIX locus:** draw the **persistent** telegraph glyph as a SHAPE-channel op inside `_build_board_draw_ops` (the 14.10 highlight loop at `1388-1394` is the pattern to mirror), sourced from the projection; keep the (now domain-anchored) detonation flash. **No `_process` poll** — this rides the existing `render()`/one-draw-pass path.
- **The live driver needs NO change.** The presenter already builds the VM with the session's full `event_log_summary` and calls `render()` on every committed action + enemy phase, so once the projection + op are in place the persistent telegraph and the corrected flash appear live with **no session/driver change**.

**The telegraph pattern in one table (the projection targets):**

| Event (in `event_log_summary.details`) | Carries | Presentation today | Presentation after fix |
|---|---|---|---|
| `tile_marked` (`telegraph_id`, `marked_cell`) | authoritative marked cell | one 0.5s orange pulse, then nothing | **persistent shape/glyph** on `marked_cell` from now until its detonation (NFR9) |
| `marked_tile_detonated` (`telegraph_id`, `marked_cell`, `outcome`) | authoritative detonation cell | one 0.5s orange pulse at `marked_cell` | clears the persistent glyph; detonation flash anchored to `marked_cell` |
| `damage_applied` (`weapon_id: ash_seer_detonation`, **no cell**) | victim id only | flash at victim's **current** occupant cell (**the F5 anchor bug**) | flash anchored to the paired detonation's `marked_cell` |
| `damage_applied` (a normal weapon hit) | victim id only | flash at victim's occupant cell (**correct — leave it**) | unchanged |

## Acceptance Criteria

**AC1 — A persistent, non-color, affinity/fog-legible telegraph marks the danger cell from mark until it resolves (F5; FR22/FR69; NFR9)**
Given an enemy marks a tile for a delayed or area attack (the ash-seer detonation pattern; the boss telegraph reuses the same vocabulary)
When the mark is active
Then the marked tile carries a **persistent on-board telegraph from the moment of marking until it resolves** — present on every render during the pending window, not a one-shot pulse — communicated by **shape / glyph / label and not by color alone** (NFR9)
And the telegraph is **legible under every affinity treatment and in darkness/fog** (drawn regardless of the marked cell's `visibility_state`, with its own shape/outline so it reads over the Scorched/Flooded/Cursed/Darkness floor variants and the fog fill), and it **clears when the mark resolves or is cancelled** (the matching `marked_tile_detonated`, hit or avoided).

**AC2 — The detonation effect renders on the domain-resolved cell; the whole telegraph reads from existing events with no new query and no fingerprint move (F5; FR22/FR69; Epic-15 standing constraint)**
Given a detonation resolves on a specific board cell
When the presentation renders its effect
Then the effect renders on **the cell the domain resolved it on** — the flash/effect anchor is `marked_tile_detonated.marked_cell` (the domain event's cell), **verified in a headless test against the domain event's cell even when the victim's current `occupants` cell differs** (closing the observation that a flash appeared on the hero's current tile while the log placed the detonation on the previous tile; the detonation-damage entry is identified by its `ash_seer_detonation` source marker or its paired `marked_tile_detonated`, never a generic occupant lookup)
And the telegraph and its resolution **read from existing domain events** (the VM `event_log_summary` slot — the mark/detonation events already emitted and summarized) with **no new domain query, no new board-VM key, and no fingerprint change** — a normal (non-detonation) `damage_applied` still anchors to the victim's occupant cell (unchanged).

**AC3 — Pinned-contract posture: presentation/read-model only, every fingerprint byte-identical (Epic-15 standing constraint; NFR13/NFR15)**
Given the pinned contracts
When this story lands
Then **no domain / command / event / RNG / save contract changes**: the Ash-Seer + boss telegraph **resolution** (`enemy_command_adapter.gd`, `pending_telegraph_state.gd`, `prototype_enemy_ai.gd`, `boss_command_adapter.gd`, the combat driver and its pinned `ash_seer` replay fixtures) is **byte-identical**, the 16-key `TacticalBoardViewModel` gate stays 16 (no new board-VM key — the projection reads the existing `event_log_summary`), any new/changed seam key set is exact and unit-pinned, `RunSnapshot` stays 23-key / `SCHEMA_VERSION == 1`, the 7 named RNG streams are unchanged and unreordered, no new event/enum value, no new autoload, no new RNG draw site, no `_process`/per-frame poll, and **every pinned combat/generation/route/finale seed-regression fingerprint stays byte-identical** (Epic 15 moves NO fingerprint)
And this story touches **no** `project.godot` project setting, input map, or save format; difficulty stays a hard non-goal (no number the game resolves changes — this corrects and enriches what the board *shows*).

## Tasks / Subtasks

- [ ] **Task 1 — Confirm the domain truth and reproduce the presentation gap; pin the fix loci (AC1, AC2)**
  - [ ] Read `enemy_command_adapter.gd` (`179-312` — mark + detonation, and that the detonation `damage_applied` carries **no cell**, `weapon_id "ash_seer_detonation"`), `domain_event.gd` (`983-1022` — `marked_cell`/`telegraph_id` in both payloads), `combat_explanation_log.gd` (`6-15`, `68-79`, `101` — the full log + `details.marked_cell`/`telegraph_id`/`weapon_id`), `tactical_combat_feedback.gd` (`47-110` — the transient telegraph + occupant-anchored hit), `tactical_board_presenter.gd` (`1091-1114`, `1188-1194`, `1234-1243`, `1322-1414`), and `tactical_board_view_model.gd` (`33-51` — the 16-key gate; the `event_log_summary` slot). Confirm: the domain marks/detonates the right cell; the log reads it correctly; the persistent visual is absent and color-only; the detonation flash resolves via `occupants`.
  - [ ] Confirm `event_log_summary` is the **full** fight log (`tactical_board_presenter.gd:429` → `interactive_combat_session.gd:243-244`), so the active-mark projection is reliable. Do not fix yet — pin the cause first (the 14-1 retro P4 "grep/repro the live surface before scoping" habit both 15-1 and 15-2 cite).

- [ ] **Task 2 — Project the ACTIVE marked cells from the existing event log (AC1, AC2, AC3)**
  - [ ] Add a scene-free `RefCounted` projection (extend `TacticalCombatFeedback` or add a sibling seam, e.g. `TacticalTelegraphOverlay`) that reads the VM `event_log_summary` and returns the SET of currently-active marked cells: a `tile_marked` whose `telegraph_id` has **no** matching `marked_tile_detonated`. Key by `telegraph_id`; carry the `marked_cell` (+ optionally the `due`/`countdown` fields already in the payload for a label). Kind-agnostic (covers both the ash-seer and the boss telegraph). Pure, zero-RNG, zero-mutation; pin its exact output-key set with a unit test (exact-key/fail-closed style).
  - [ ] Confirm the projection needs **no new board-VM key** and **no new domain query** — it consumes the existing `event_log_summary` slot the presenter already populates. Absent/malformed entries are a safe no-op (never a fabricated cell), mirroring `TacticalCombatFeedback._cell_or_null`.

- [ ] **Task 3 — Render the persistent telegraph as a SHAPE-channel op; keep it affinity/fog-legible (AC1, NFR9)**
  - [ ] In `tactical_board_presenter.gd::_build_board_draw_ops`, draw a **persistent** telegraph glyph on each active marked cell every render (mirror the 14.10 range-highlight loop at `1388-1394`): a distinct **shape** (e.g. a danger-diamond / bright bordered marker via `_outline_op` + optional `_fill_op`/glyph), optionally a `!`/countdown **label**, drawn with its own outline so it reads over every affinity floor variant and the fog fill. Draw it **regardless of the cell's `visibility_state`** (a telegraphed danger stays visible in memory/fog). Keep every telegraph op **mouse-IGNORE** (it must never eat a board tap) and route it through the existing `render()` one-draw-pass — **no `_process` poll**.
  - [ ] Decide the transient-pulse fate: the persistent glyph supersedes the mark-time pulse (`_animate_telegraph`); keep a subtle appear/resolve accent if desired, but the **persistent** overlay is the AC1 deliverable. Do not regress the existing hit/death/move feedback.

- [ ] **Task 4 — Anchor the detonation effect to the domain event cell (AC2)**
  - [ ] Make the detonation's damage effect (flash + any number) anchor to the paired `marked_tile_detonated.marked_cell`, NOT the victim's current `occupants` cell. Detect the detonation-damage entry by its `weapon_id == "ash_seer_detonation"` source marker (the `_is_affinity_hazard_damage`-style marker key) **or** by pairing to the same-batch `marked_tile_detonated` (`telegraph_id` / adjacent `sequence_id`). Leave a **normal** `damage_applied` anchored to the occupant cell (unchanged — a direct hit lands on the victim's own cell).
  - [ ] Keep the `marked_tile_detonated` telegraph entry reading `details.marked_cell` (already correct). Confirm the fix needs no session/driver change — the presenter already renders from the session's full `event_log_summary`.

- [ ] **Task 5 — Tests: lock the anchor + the active-mark projection; close the 14-3 detonation fixture gap (AC1, AC2, AC3)**
  - [ ] **Close the carried 14-3 defer (`deferred-work.md:113`).** `test_tactical_combat_feedback.gd` exercises only `tile_marked`; the `marked_tile_detonated`→telegraph branch is unexercised. Add a `marked_tile_detonated` batch entry AND assert the AC2 anchor: given a detonation batch whose victim's `occupants` cell ≠ the event `marked_cell`, the detonation **effect cell == `marked_cell`** (the domain event cell), not the occupant cell. Also assert a **normal** `damage_applied` still anchors to the occupant cell (no regression). Mark the `deferred-work.md:113` item RESOLVED-by-15.3 on completion.
  - [ ] Add a projection test (new/extended seam): a `tile_marked` with no matching detonation → its cell is active; a `tile_marked` followed by its `marked_tile_detonated` (same `telegraph_id`) → cleared; two simultaneous marks → both active and independently cleared; kind-agnostic (a boss-telegraph mark surfaces too); zero mutation of the input. Pin the exact output-key set.
  - [ ] Confirm **no gate moved**: `TacticalBoardViewModel` (16 keys), `TacticalCombatFeedback.PLAN_KEYS` (value/branch change only unless you deliberately add + pin a key), `RunSnapshot` (23-key / `SCHEMA_VERSION == 1`), `RngStreamSet` (7 streams), `DomainEvent` enum, `project.godot` — all byte-untouched. The domain detonation resolution + every generator/route/finale/combat fingerprint unchanged. The presenter still compiles (`test_run_flow_scenes_load.gd`). **No SceneTree presenter test** (the glyph render is verified by construction + the compile guardrail; the on-screen legibility is OSG-1).
  - [ ] **`.gd.uid` discipline:** if you add any new `.gd` (a new seam/test), run `godot --headless --import` **separately** to emit the `*.gd.uid` sidecar and commit it (the `--scene` test run does not emit it).
  - [ ] Run the FULL headless suite (command below). Baseline **206 PASS files** (post-15.2); expect **≥206** (a new seam+test file pushes ≥207; extending an existing test adds none). False-PASS grep guard `SCRIPT ERROR|Parse Error|^FAIL` on the RAW output = exactly the **6 documented** stderr negatives, ZERO new, none referencing a 15.3 file. `git diff --check` clean.

## Dev Notes

### What is ALREADY SHIPPED (reuse / correct — do NOT rebuild)

- **The domain telegraph pattern** (`enemy_command_adapter.gd` `_apply_mark`/`_apply_detonation`, `pending_telegraph_state.gd`, `domain_event.tile_marked`/`marked_tile_detonated`, `boss_command_adapter.gd`, `prototype_enemy_ai.gd`, `boss_ai.gd`) — the mark/due/detonate state machine + events. It marks and detonates the **right cell** and emits the authoritative `marked_cell` + `telegraph_id`. **Leave byte-identical — presentation-only story.**
- **`CombatExplanationLog`** (`combat_explanation_log.gd`, Story 1.11) — builds the **full** fight log with `details = event.payload`, so `event_log_summary` already carries `marked_cell`/`telegraph_id`/`weapon_id`. The `_is_affinity_hazard_damage` **source-marker** pattern (`107-108`) is the precedent for identifying detonation damage by its `weapon_id`. **No change.**
- **`TacticalCombatFeedback`** (`tactical_combat_feedback.gd`, Story 14.3) — the scene-free plan seam already reading `event_log_summary` + `occupants`. **Correct here:** re-anchor the detonation damage to `marked_cell`; add (or house) the active-mark projection. It is the model for "a pure projection over the existing slot" (the ratified 15-2 pattern the retro highlights).
- **`tactical_board_presenter.gd` op-list render** (`_build_board_draw_ops`, 13.1/14.10) — the one-pass draw. The 14.10 range highlights (`1388-1394`), the `HAZARD_OUTLINE_COLOR` danger outline (`1348-1350`), and the 14.2 armed-target double outline (`1396-1404`) are the **SHAPE-channel precedents** to mirror for the persistent glyph. Reuse `_outline_op`/`_fill_op`/`_texture_op`. **No `_process` poll** (the ratified 14-3 "one draw pass per render" rule).
- **`InteractiveCombatSession.event_log()`** (`interactive_combat_session.gd:243-244`) — returns the full accumulated `_event_log`. The live driver already feeds the presenter; **no session/driver change.**

### The root-cause thesis in one line

The domain already marks and detonates the correct cell and the log shows it correctly, but the board renders the danger only as a one-shot **color** pulse (no persistence, no shape → NFR9 fail) and anchors the detonation **flash** to the victim's current occupant cell instead of the domain event's `marked_cell` — so the fix is a **presentation projection over the existing `event_log_summary` slot**: a persistent shape/glyph telegraph on active marked cells (mark→resolution, affinity/fog-legible) plus a detonation effect anchored to `marked_tile_detonated.marked_cell`, adding no board-VM key, no domain query, and no fingerprint, and locked by a headless anchor+projection test that also closes the 14-3 detonation-fixture gap.

### Scope determinations (read — these prevent over-reach)

- **The active-mark projection reads the event log, NOT the domain `pending_telegraphs`.** `pending_telegraph_state.gd` is the domain source of truth, but surfacing it to the VM means a new option + a 17th board-VM key + a new domain query — all forbidden (AC2/AC3). The event-log projection (mark-minus-detonation by `telegraph_id`) is the ratified 15-2 "read from existing domain events / no new query / no fingerprint" pattern and is strictly cleaner. Use it.
- **Kind-agnostic on purpose.** The projection keys on the `tile_marked`/`marked_tile_detonated` event ids, so it covers the **boss** telegraph (`KIND_LARVAL_AVATAR_TELEGRAPH`) as well as the ash-seer mark, for free — do not special-case a kind.
- **Normal hits keep their occupant anchor.** Only the **detonation** damage is a cell effect that must anchor to `marked_cell`; a direct weapon hit lands on the victim's own cell (occupant anchor — unchanged). Distinguish by the `ash_seer_detonation` source marker / the paired detonation event; do not blanket-reroute all `damage_applied`.
- **Do NOT touch the domain, the combat driver, or any ash_seer fixture.** The 14-1 combat-replay re-pin (Medium seed 512→24680 with its `ash_seer` coverage) and every winnability fixture are DOMAIN determinism artifacts; this presentation story moves NO fingerprint and must not touch them (touching them is the Epic-15 firing offence).

### NFR9 — the non-color channel is the point of this story

The whole finding is that a color-only, transient cue failed to reach the player. The persistent telegraph's **primary** channel is shape/glyph (and optionally a text/countdown label) — color is additive, never the sole signal. Verify the glyph reads over each affinity floor variant and the fog fill (its own outline/contrast, not a hue that blends). This mirrors the ratified hazard-outline / range-highlight shape channels already in the op list.

### Epic-14/15 constraints inherited (retro forward items + project-context + the sprint change)

- **Epic 15 moves NO seed-regression fingerprint; difficulty is a hard non-goal.** This story changes no number the game resolves — it corrects/enriches what the board shows. Prove it: the domain detonation resolution, the 7 streams, and every combat/generation/route/finale fingerprint stay byte-identical (AC3).
- **Read models / feedback seams are pure: zero RNG, zero mutation (project-context; NFR13/NFR15).** The projection and the plan seam never draw RNG or mutate; assert the input is unmutated (mirror `test_tactical_combat_feedback.gd::_plan_does_not_mutate_the_input`).
- **Assertable logic on scene-free `RefCounted` seams; no SceneTree presenter test (14-3 T3; the ratified verify-by-construction stance).** The anchor decision + the active-mark projection live on seams and are unit-tested; the glyph render is verified by construction + `test_run_flow_scenes_load.gd`. The on-screen legibility under affinity/darkness is verify-by-construction → OSG-1 (below).
- **One draw pass per render, never `_process` (14-3; project-context.md line 355).** The persistent glyph is drawn in `_build_board_draw_ops`, replayed via the existing `render()` path. No poll.
- **15-1 vs 15-2 retro contrast — apply BOTH.** 15-1's render symptom had no headless repro → verify-by-construction → OSG-1; **15-2 proved that when correctness is headlessly provable you MUST test-lock it.** For 15.3: the **cell-correctness** (the detonation anchor == `marked_cell`; the active-mark set) IS headlessly provable → **test-lock it** (AC2/Task 5). Only the **glyph's on-screen legibility** rides the presenter and is verify-by-construction → the OSG-1 checklist. Do not defer the correctness to OSG-1 as 15-1 had to.
- **15-2 desync-class awareness.** 15-2 fixed "damage computed in two places" with a standing regression test. 15.3's analog: the detonation cell is authoritative in **one** place (the domain `marked_tile_detonated.marked_cell`) but was being **re-derived** in presentation (the occupant lookup); the fix collapses the effect to the single domain authority and the anchor test is the standing guard.
- **`.gd.uid` via `--headless --import` separately (13-1/14-8); keep the false-PASS grep guard standing (retro P3).** Grep the RAW runner output for `SCRIPT ERROR|Parse Error|^FAIL`; exactly the **6 documented** stderr negatives (int64-overflow ×2 [`test_domain_event.gd:146` + `test_manual_seed_loader.gd:153`], malformed-JSON ×3 [`test_profile_repository` + `test_settings_repository`], `invalid_node_type` ×1 [`test_route_node`]); ZERO new. Never trust the summary PASS line alone.

### Deferred-work overlaps folded in (only those that touch 15.3's area)

- **The 14-3 R1 `marked_tile_detonated`→telegraph fixture gap (`deferred-work.md:113`) — 15.3 CLOSES it.** `TacticalCombatFeedback.plan()` maps `marked_tile_detonated`→a telegraph pulse (seam lines 99-102) but `test_tactical_combat_feedback.gd` only exercises `tile_marked`; the detonation→telegraph branch is unexercised. 15.3 is exactly the "next `scripts/ui/` combat-feedback touch" the defer names — add the `marked_tile_detonated` batch coverage AND the AC2 anchor assertion, and mark the item RESOLVED-by-15.3 in `deferred-work.md`.
- **The 14-3 R2 slide-lifecycle + `entry_count` dead-output defers (`deferred-work.md:119-120`) — OUT OF SCOPE.** Movement/slide animation is Story 15.8; the `entry_count` trim is a log-view nicety. Do not fold either here.
- **The standing Band-1/2 on-device human-playtest defer (project-context; retro T1) — 15.3 EXTENDS the OSG-1 checklist.** The glyph's on-screen legibility (below) joins OSG-1; it is not a blocker for this story (the correctness is test-locked).

### OSG-1 on-device checklist additions (carry forward; not a blocker for this story)

- With an **Ash Seer** on the board, when it marks a tile: a **persistent** shape/glyph telegraph appears on that tile and stays until the detonation resolves (not a one-off flash), and it is legible over each affinity floor and when the marked tile is in fog/memory.
- When the mark **detonates**: the effect renders on the **marked** tile (the one the log names), not on the hero's current tile; dodging (stepping off the marked tile) reads as safe.
- The telegraph is distinguishable **without color** (shape/glyph/label), at the 2.0x text scale.

### Anti-patterns to avoid (this story specifically)

- **Do NOT touch the domain detonation resolution, `pending_telegraph_state.gd`, the AI, the combat driver, or any `ash_seer` fixture** — presentation-only; touching them moves a fingerprint (the Epic-15 firing offence). The domain already marks/detonates the right cell.
- **Do NOT add a board-VM key or a domain `pending_telegraphs` VM slot** — the projection reads the existing `event_log_summary`; the 16-key gate stays 16, and "no new domain query" (AC2) holds.
- **Do NOT ship a color-only telegraph** — NFR9 requires shape/glyph/label; color is additive. The persistent glyph must read over every affinity floor + fog.
- **Do NOT anchor the detonation flash to the victim's occupant cell** — anchor to the domain `marked_tile_detonated.marked_cell`; leave normal hits on the occupant cell.
- **Do NOT add a `_process`/per-frame poll** — draw the glyph in the one-pass `_build_board_draw_ops` via the existing `render()` path.
- **Do NOT draw RNG or mutate in the projection/plan path** — assert the input is unmutated.
- **Do NOT build a new telegraph mechanic, countdown timer domain, or effect engine** — the mark/detonation domain is complete; this is presentation over its existing events.
- **Do NOT touch the reward modal (15.6), snake_case/raw-id copy (15.11), movement animation (15.8), quit/resume (15.4), or theme polish (15.10).**
- **Do NOT add a SceneTree presenter test** — decisions on the `RefCounted` seams (unit-tested); the glyph is verified by construction + `test_run_flow_scenes_load.gd`.
- **Keep the false-PASS grep guard standing** — grep the RAW output; exactly the 6 documented negatives; ZERO new.

## Project Structure Notes

- **Files touched (production):**
  - `godot/scripts/ui/view_models/tactical_combat_feedback.gd` — MODIFIED: re-anchor the detonation damage effect to `marked_cell` (identify by `ash_seer_detonation` source marker / paired detonation); house or add the active-marked-cell projection (or add a sibling `RefCounted` seam). Pure/zero-RNG/zero-mutation; exact-key output pinned.
  - (Optional) `godot/scripts/ui/view_models/tactical_telegraph_overlay.gd` — NEW `RefCounted` seam IF you keep the projection separate from `TacticalCombatFeedback` (+ its `.gd.uid`). Scene-free, reads `event_log_summary`, returns the active marked cells.
  - `godot/scripts/ui/presenters/tactical_board_presenter.gd` — MODIFIED: draw the persistent SHAPE/glyph telegraph op in `_build_board_draw_ops` from the projection (mirror the 14.10 highlight loop); render the detonation flash on the domain-anchored cell; retire/keep the transient pulse as chosen. No `.tscn` change (the overlay is code-built into the op list).
- **Tests:** UPDATE `godot/tests/unit/ui/test_tactical_combat_feedback.gd` (add `marked_tile_detonated` coverage + the AC2 anchor assertion + the normal-hit no-regression — closes `deferred-work.md:113`). ADD a projection test (extend the same file or a new `tests/unit/ui/test_*.gd` — run `--headless --import` separately for a new `.gd.uid`). `test_run_flow_scenes_load.gd` stays green (the compile guardrail).
- **Out of bounds:** `enemy_command_adapter.gd`, `pending_telegraph_state.gd`, `prototype_enemy_ai.gd`, `boss_command_adapter.gd`, `boss_ai.gd`, `domain_event.gd`, `combat_explanation_log.gd`, the reference combat driver + every `ash_seer`/winnability fixture, `tactical_board_view_model.gd` (no key add), `project.godot`/input map/save format, any `scripts/{rules,generation,ai,save,core}` file, the reward modal, movement animation, snake_case/raw-id copy. The domain and every generator/route/finale/combat fingerprint are byte-untouched.

## Project Context Rules

Extracted from `project-context.md` (canonical rulebook) and the architecture (`_bmad-output/game-architecture.md`):

- **Domain owns truth; presentation observes + submits commands (hard architecture rule; NFR14/NFR15).** 15.3 renders a read model over the shipped telegraph events; the presentation owns no tactical truth and mutates nothing.
- **Successful commands emit deterministic past-tense events; presentation mirrors them (hard rule).** The mark/detonation events are the single source of truth; the telegraph is a pure projection of them (no re-derivation of the detonation cell).
- **Named RNG only; deterministic under seed (NFR13).** 15.3 draws ZERO RNG; the 7 named streams unchanged; Epic 15 moves NO seed-regression fingerprint.
- **`TacticalBoardViewModel.to_dictionary()` is an EXACT 16-key contract (project-context §pinned gates).** The telegraph reads the existing `event_log_summary` slot — no key added; the 16-key gate holds.
- **Assertable logic lives in scene-free `RefCounted` seams with pinned key sets; no SceneTree presenter tests (verify by construction + the compile guardrail). No new autoload.**
- **Avoid per-frame work; update through events/signals/explicit refresh (project-context.md line 355).** The glyph is drawn in the one-pass `_build_board_draw_ops` via `render()`; no `_process` poll.
- **Color-independence; phone-sized readability is first-order, not polish (NFR9).** The telegraph's shape/glyph/label is the accessible channel; it must read over every affinity floor and fog, at the 2.0x text scale.
- **Difficulty is a hard non-goal.** 15.3 changes no enemy/HP/damage/mark/detonation number the game resolves — it fixes what the board *shows*.
- **Headless suite stays green** (206 PASS baseline post-15.2; expect ≥206; false-PASS grep `SCRIPT ERROR|Parse Error|^FAIL` clean beyond the 6 documented negatives).

### Mandatory test command (must pass before this story moves to review/done)

```
godot --headless --path C:\Sealsworn\godot --scene res://tests/headless/test_runner.tscn --quit-after 10
```

`godot` is not on the Bash/`where` PATH; run via PowerShell (`C:\Users\Rasmus\bin\godot.cmd`, or the standalone `C:/Users/Rasmus/Godot_v4.6.3-stable_win64.exe/Godot_v4.6.3-stable_win64_console.exe`). Apply the false-PASS grep guard `SCRIPT ERROR|Parse Error|^FAIL` on the RAW output (never trust the summary PASS line alone). The runner auto-discovers `test_*.gd` under `res://tests/unit` and `res://tests/integration` only. Baseline **206 PASS files** (post-15.2); expect **≥206**, ZERO new stderr negatives beyond the 6 documented. Run `godot --headless --import` separately to emit any new `.gd.uid` sidecars before committing.

## References

- `_bmad-output/planning-artifacts/epics.md#Epic 15: Playtest Response` — Story 15.3 ACs (body lines 3301–3317); the Epic-15 Epic-List entry + sequencing/fingerprint/decision note (535–541); the Band-2 demarcation (3281).
- `_bmad-output/planning-artifacts/sprint-change-proposal-2026-07-24.md` — the F5 → 15-3 map (mapping table row: persist marked-tile telegraph shape/glyph NFR9 + anchor the detonation flash to the domain cell; classified presentation over existing events, fingerprints byte-identical); the Band-2 list; "difficulty is a hard non-goal"; the readable-and-correct goal.
- `playtest-sessions/agent-playtest-2026-07-20.md` + `…-triage.md` — F5 (marked detonation invisible until it hurts you; flash on current tile vs log on previous tile).
- `_bmad-output/auto-gds/retro-notes/epic-15.md` — 15-1's verify-by-construction note (render symptom with no headless repro → OSG-1); 15-2's contrast (correctness IS headlessly provable → test-lock it) and the "computed/derived in two places" desync class the AC2 test guards.
- `_bmad-output/implementation-artifacts/15-1-hud-and-log-layout-clip-fix.md` + `15-2-attack-preview-damage-correctness.md` — the ratified Epic-15 presentation/read-model story shape (RefCounted seams, no SceneTree test, `.gd.uid` discipline, false-PASS grep guard, deliberate in-change test updates, the exact-key seam discipline).
- `_bmad-output/implementation-artifacts/deferred-work.md` — line 113 (the 14-3 `marked_tile_detonated`→telegraph fixture gap → CLOSED by 15.3); lines 119–120 (14-3 R2 slide/`entry_count` → out of scope, 15.8/log-view).
- Source files (read before implementing):
  - `godot/scripts/tactical/turns/enemy_command_adapter.gd` — `_apply_mark` (`179-229`); `_apply_detonation` (`232-312`, `marked_cell` authoritative, `hit` = on marked cell, detonation `damage_applied` has no cell + `weapon_id "ash_seer_detonation"`). **DOMAIN — DO NOT TOUCH.**
  - `godot/scripts/tactical/turns/pending_telegraph_state.gd` — the pending-mark state machine (source of truth). **DO NOT TOUCH; do NOT surface as a board-VM slot.**
  - `godot/scripts/core/events/domain_event.gd` — `tile_marked` (`983-1000`) / `marked_tile_detonated` (`1003-1022`) payloads (`marked_cell` + `telegraph_id`). **DOMAIN — DO NOT TOUCH.**
  - `godot/scripts/tactical/outcomes/combat_explanation_log.gd` — `build_entries` (full log, `6-15`); `MARKED_TILE_DETONATED`/`TILE_MARKED` lines read `marked_cell` (`68-79`); `details = payload` (`101`); the `_is_affinity_hazard_damage` source-marker precedent (`107-108`). **No change (the read source).**
  - `godot/scripts/ui/view_models/tactical_combat_feedback.gd` — `plan` (`47-110`); the `damage_applied`→occupant hit (`76-94`); the `tile_marked`/`marked_tile_detonated`→transient telegraph (`95-102`); `PLAN_KEYS` (`28-34`). **Correct here (anchor + projection).**
  - `godot/scripts/ui/presenters/tactical_board_presenter.gd` — `_play_new_combat_feedback` (`1091-1114`); `_animate_hit` (`1188-1194`); `_animate_telegraph` (`1234-1243`, color-only); `_transient_cell_rect` (`1249-1261`); `_build_board_draw_ops` (`1322-1414`, the one-pass op list — glyph integration point; 14.10 highlight loop `1388-1394`, HAZARD outline `1348-1350`, armed outline `1396-1404`). **Correct here (persistent glyph + anchored flash).**
  - `godot/scripts/ui/view_models/tactical_board_view_model.gd` — the EXACT 16-key `to_dictionary()` (`33-51`); the `event_log_summary` slot. **No key add.**
  - `godot/scripts/run/interactive_combat_session.gd` — `event_log()` (`243-244`, the full accumulated fight log). **No change.**
  - `godot/tests/unit/ui/test_tactical_combat_feedback.gd` — the feedback-seam coverage to extend (`_batch` currently tests only `tile_marked` at `190-195`; add the detonation coverage + anchor assertion).
  - `godot/tests/unit/ui/test_run_flow_scenes_load.gd` — the compile guardrail (loads the board scene + presenter).

## Dev Agent Record

### Agent Model Used

Story context by Claude Opus 4.8 (gds-create-story).

### Debug Log References

### Completion Notes List

### File List

### Change Log

- 2026-08-07 — Story 15.3 context created (gds-create-story). Presentation + read-model fix over the shipped ash-seer/boss telegraph events: persist a shape/glyph marked-tile telegraph from mark→resolution (NFR9, affinity/fog-legible) projected from the existing `event_log_summary` slot, and anchor the detonation effect to the domain `marked_tile_detonated.marked_cell` (closing the flash-on-current-tile observation); adds NO board-VM key, NO domain query, and keeps every fingerprint byte-identical. Headless test locks the detonation anchor + the active-mark projection and closes the 14-3 `marked_tile_detonated`→telegraph fixture gap (`deferred-work.md:113`). Status → ready-for-dev.
