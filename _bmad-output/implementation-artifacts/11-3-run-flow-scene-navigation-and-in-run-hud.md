---
baseline_commit: d98d72c9f70b353ea6446729278896d18da00ab1
---

# Story 11.3: Run Flow Scene Navigation and In-Run HUD

Status: in-progress

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a player,
I want to move through a whole descent on screen — from launch to class select to levels to the run's end,
so that the roguelite loop is something I play rather than something tests prove.

## Story Type & Scope Boundary (READ FIRST)

**This IS a CODE story — the FIRST SCENE / UI-presentation story of Epic 11, and effectively of the whole
project.** Every earlier story deferred the `.tscn` / `Control` / presenter / `SceneManager`-navigation layer
behind "a later run-flow / HUD story." Epic 11 is that story-set; **11.3 is its scene-navigation + in-run-HUD
half.** 11.2 shipped the scene-free live DOMAIN wiring (`LiveCombatResolver` + the additive `RunOrchestrator`
live methods) that makes a live fight decide a node and a live hero-death end a run; **11.3 puts a real
on-screen shell on top of it** — the app-flow that walks launch → hero select → route map → tactical board
per node → run-end return, and the in-run HUD that renders run context (HP, node progress, gold,
inventory/passives) alongside the tactical board.

**11.3 is where the "playable hands-off" line is crossed for the pre-boss descent** (Epic-9 retro Insight 7,
D3): 11.2 reached "provable in an integration test"; 11.3 reaches "a human plays it on screen."

- **The as-built starting point (verify by reading — it is nearly bare):**
  - `SceneManager` (`godot/scripts/autoloads/scene_manager.gd`) is an **8-line** thin
    `get_tree().change_scene_to_file(...)` wrapper with a single `current_scene_path` field. It has NO
    named-route table, NO run-context handoff, NO `RunEndOutcome.next_destination` routing.
  - There are only **4 `.tscn` files** in the whole repo: `scenes/app/boot.tscn` (→ `BootController` →
    changes to `main.tscn`), `scenes/app/main.tscn` (instances `gameplay_shell.tscn`),
    `scenes/game/gameplay_shell.tscn` (**empty `Node2D`**), `scenes/game/tactical_board.tscn` (**empty
    `Node2D`**). `main_scene = res://scenes/app/boot.tscn`.
  - There is exactly **one** presenter: `godot/scripts/ui/presenters/boot_controller.gd`. No HUD presenter, no
    hero-select scene, no route-map scene, no run-summary/outpost scene exists.
  - The **view-model + command-bridge layer is COMPLETE and stable** (Epics 2/5/6/7/8 shipped 24 view models
    + the command bridge — enumerated in the seam map below). 11.3 does NOT rebuild any of them; it BUILDS the
    scenes/presenters that READ them and SUBMITS intent through the bridge.

- **What 11.3 delivers (four AC groups):**
  1. **App-flow scene navigation (AC1)** — `SceneManager` (extended, not forked) drives **launch → hero
     select → route map → tactical board per node → run-end return**, following `RunEndOutcome.next_destination`
     and the existing view-model contracts. **No scene owns tactical truth** — every scene READS a view
     model and SUBMITS a command-bridge intent; the domain (`RunOrchestrator` + the Epic-1..9 commands) owns
     all state.
  2. **In-run tactical HUD + live node play (AC2)** — the tactical board scene hosts a generated level in the
     live run flow; movement/attack previews, the two-step commit, inspect, the passive-reward modal, and
     reward-pickup flows work **through the existing Epic-2/6 presentation contracts**; and the in-run HUD's
     `status` region presents **run context (HP, node progress, gold, inventory/passives access) per the 11.1
     appendix §1.3 (Contract gap G1)**. **G1 (the in-run HUD run-context projection) and G2 (the route/run-map
     view model) are 11.3's to resolve** (11.1 recorded them, resolved neither).
  3. **On-screen resume + recovery (AC3)** — quit-and-resume mid-run continues from the persisted snapshot
     through real screens, with the save/resume recovery states (§13 of the appendix) reachable on screen;
     **resumed outcomes match uninterrupted play (NFR13)**.
  4. **Four-layout reach + rule invariance (AC4)** — the full flow is exercised on phone-portrait AND desktop
     with primary actions reachable + readable (FR66, NFR7), and **layout changes never alter tactical rules**.

- **What 11.3 does NOT do (hard scope fences — do not cross):**
  - **No live affinity call sites / affinity VFX** (that is **11.4**). 11.3's live combat runs a plain
    generated level exactly as 11.2's live loop does (`assign_affinity` stays un-wired). The HUD/inspect may
    render the `AffinityViewModel` / `DarknessReadView` READ surfaces where the domain already exposes them,
    but 11.3 does NOT wire the Epic-7 affinity EFFECTS onto the live board and does NOT author affinity board
    treatments — that is 11.4's remit (appendix §15, §14.3).
  - **No outpost SCENE, no reveal RENDERS, no meta-spend.** The outpost scene + the first-death/first-victory
    reveal renders + the summary↔profile coupling (G3) are **11.5**; the meta-spend / unlock application is
    **11.6**. 11.3's run-end return NAVIGATES to the outpost destination (`next_destination == outpost`) but
    the polished outpost scene itself is 11.5's; a minimal placeholder run-end landing is acceptable so long
    as it does not pre-empt or duplicate 11.5's `OutpostViewModel`-bound scene (see "The 11.5 handoff seam"
    below). Do NOT build the outpost dashboard, the reveal beats, or the deferred named-space tiles here.
  - **No new save key, no schema bump, no new RNG stream, no new fingerprint, no new event.** The 23-key
    `RunSnapshot` gate stays 23; `ProfileSnapshot.SCHEMA_VERSION == 1`; `SettingsSnapshot.SCHEMA_VERSION == 1`;
    the 7 named RNG streams (`map`/`level`/`combat`/`loot`/`rewards`/`events`/`cosmetic`) are untouched; every
    pinned level/route/arena/finale seed-regression fingerprint stays byte-identical; the `DomainEvent.Type`
    enum tail is UNCHANGED (a scene reads/submits — it does not mint domain events). If you believe a new
    event/key is needed, STOP — it almost certainly is not (a scene is presentation).
  - **No new DOMAIN surface, no new command, no rule change.** 11.3 binds to EXISTING pinned view-model keys
    and EXISTING command-bridge intents / orchestrator methods. The ONLY new non-scene code 11.3 may add are
    the two thin PRESENTATION read-projections the appendix pre-authorized: **G1** (the in-run HUD
    run-context projection) and **G2** (the route/run-map view model) — both are fail-closed RefCounted read
    surfaces over EXISTING domain state (they compute nothing gameplay-affecting, mint no event, consume no
    RNG, mutate nothing). Everything else is `.tscn` + `Control` presenter wiring.
  - **No selectable difficulty ladder anywhere** (the ratified hard non-goal; appendix §12.3). The settings
    surface (if 11.3 renders any) MUST NOT present a difficulty selector.

## Acceptance Criteria

Sourced verbatim from `epics.md` (Epic 11, Story 11.3, lines ~2646-2672). Four AC groups (Given/When/Then + And):

1. **App-flow scene navigation (AC1).** GIVEN the game launches, WHEN I start a run, THEN `SceneManager`
   drives launch → hero select → route map → tactical board per node → run-end return — AND navigation
   follows `RunEndOutcome.next_destination` and the existing view-model contracts, with no scene owning
   tactical truth.

2. **In-run HUD + live node play (AC2).** GIVEN I play a combat node, WHEN the tactical board hosts a
   generated level in-run, THEN movement/attack previews, two-step commit, inspect, the passive reward modal,
   and reward pickup flows work through the existing Epic 2/6 presentation contracts — AND the in-run HUD
   presents run context (HP, node progress, gold, inventory/passives access) per the 11.1 appendix.

3. **On-screen resume + recovery (AC3).** GIVEN I quit and resume mid-run, WHEN the resume flow runs at a
   between-level boundary, THEN the run continues from the persisted snapshot with save/resume recovery
   states reachable through real screens — AND resumed outcomes match uninterrupted play (NFR13).

4. **Four-layout reach + rule invariance (AC4).** GIVEN phone portrait and desktop layouts, WHEN the full
   flow is exercised on both, THEN primary actions remain reachable and readable (FR66, NFR7) — AND layout
   changes never alter tactical rules.

### AC Verification (how "done" is checked)

- **AC1** — `SceneManager` (extended) exposes a named-flow transition path that walks the five stages in
  order and routes the run-end transition off `RunEndOutcome.next_destination` (the pinned
  `RUN_END_DESTINATION_OUTPOST == "outpost"` marker), NOT a hardcoded scene string per call site. Each scene
  reads its bound view model (`HeroSelectViewModel` for hero select, the G2 route projection for the map, the
  `TacticalBoardViewModel` + G1 for the board/HUD) and submits intent through `TacticalCommandBridge` /
  `OutpostViewModel.start_run_request` / the orchestrator's live methods — a scene NEVER mutates `BoardState`
  / `RunState` directly. Verified by: (a) a headless test over the extended `SceneManager` flow-routing logic
  (the route table + the `next_destination`→destination mapping, exercised WITHOUT a live `SceneTree` where
  possible — see "Testability reality" below); (b) a code-level audit that no `godot/scenes/**` or
  `godot/scripts/ui/presenters/**` node calls a mutating command/board API outside the bridge/orchestrator.
- **AC2** — the tactical board scene, hosting a live-generated combat node, drives real player commands
  through `TacticalCommandBridge.build_command(context, intent)` (move/attack/inspect) with the two-step
  attack commit (`TacticalAttackCommitFlow`) and the passive-reward modal (`PassiveRewardModalViewModel` +
  `PassiveRewardCommitFlow`), all rendering the EXISTING pinned VM slots — NOT a parallel presentation path.
  The HUD `status` region renders the **G1 run-context projection** (hero HP, node progress along the route,
  gold, inventory/passives access) composed from the domain sources the appendix §16 G1 row names (hero HP
  from the hero `TacticalEntityState` on the board / class `StartingKit.baseline_hp`; node progress from
  `RouteState.cleared_node_ids` + node count; gold from `RiskEconomyState.gold`; inventory/consumed-passive
  surfaces). A headless test proves the G1 projection reads the correct pinned fields fail-closed; the scene
  wiring is verified by construction (it reads the projection, never scene state).
- **AC3** — a run saved at a between-level boundary (`SaveManager.autosave_route_position` /
  `autosave_between_level`) resumes through `SaveManager.resume_route_position` / `resume_run` on screen; the
  seven structured recovery codes (`save_not_found`, `save_open_failed`, `save_parse_failed`,
  `unsupported_save_schema`, `invalid_tactical_snapshot`/`missing_tactical_snapshot`, `invalid_rng_snapshot`)
  each map to a clear on-screen message + a retry/fresh-start affordance (appendix §13.3). The
  resume/restore path consumes NO RNG, executes NO command, advances NO turn (the snapshot-purity contract);
  a headless resume-invariant test proves interrupted==uninterrupted parity holds through the resume seam the
  scene drives (extend the EXISTING resume tests — do not rebuild them).
- **AC4** — the flow is exercised (headlessly for the data/routing layer; and the scenes honor the semantic
  `TacticalLayoutProfile` region plan, never hardcoded geometry) on `phone_portrait` AND `desktop`: the board
  stays the dominant region, primary actions stay ≥44×44 reachable, and NO gameplay rule / RNG / turn state /
  preview legality / outcome changes with the profile (the `TacticalLayoutProfile` + `TacticalTextScale`
  guarantees). Full headless suite green (`godot --headless … test_runner.tscn`), false-PASS grep clean beyond
  the 6 documented negatives; `git diff --check` clean. `RunSnapshot` 23-key gate == 23;
  `ProfileSnapshot`/`SettingsSnapshot` `SCHEMA_VERSION == 1`; `RngStreamSet.required_streams()` == 7; every
  `tools/dump_*` seed-regression fingerprint byte-identical; `domain_event.gd` unchanged (no new event).

## Tasks / Subtasks

- [x] **Task 1 — App-flow scene navigation via SceneManager (AC1)**
  - [x] EXTEND `SceneManager` (`godot/scripts/autoloads/scene_manager.gd`) — keep it a thin autoload — with a
        **named flow-transition surface**: a route table mapping the flow stages (launch/boot → hero_select →
        route_map → tactical_board → run_end) to their `.tscn` paths, and a `next_destination`→destination
        transition (the run-end return routes off `RunEndOutcome.next_destination`, the pinned
        `RUN_END_DESTINATION_OUTPOST` marker, NOT a hardcoded string at the call site). Do NOT put gameplay
        decisions in `SceneManager` — it navigates; it owns no tactical/run truth. It reads the destination
        the DOMAIN reports (via `GameSession` / the orchestrator result) and changes scene.
  - [x] Build the scene set (all under `godot/scenes/` per project structure): a **hero-select scene**
        (`scenes/ui/`), a **route-map scene** (`scenes/ui/`), and a real **tactical board scene**
        (`scenes/game/tactical_board.tscn` — replace the empty `Node2D` placeholder) + a **gameplay shell**
        (`scenes/game/gameplay_shell.tscn` — replace the empty placeholder) that hosts the board + HUD. Each
        scene gets a presenter under `godot/scripts/ui/presenters/` that READS its bound view model and
        SUBMITS intent through the bridge/orchestrator — NEVER mutates domain state.
  - [x] Wire the launch→hero-select→route-map→board→run-end walk: boot enters hero select; a confirmed class
        selection hands a `class_id` to the run start (`OutpostViewModel.start_run_request` / a fresh
        `RunOrchestrator.start(root_seed, is_manual_seed, class_id)` — the AUTHORITATIVE fail-closed start,
        appendix §6.2/§7.2); the route map presents the eligible choices (G2, Task 3) and reports the picked
        node; entering a combat/elite node loads the tactical board scene for the live node; a live node
        outcome advances the flow (victory → next route choice; the run-end return routes to the outpost
        destination). The scene layer SEQUENCES the orchestrator's live methods — it adds no new run logic.
  - [x] **The composition seam 11.3 INHERITS from 11.2 (do NOT rediscover it — 11.2's review surfaced it):**
        11.2 left the LIVE pre-boss path (`run_to_completion_live` / `resolve_current_node_live` /
        `resolve_combat_node_live`) and the boss auto-play (`auto_play_full_run`, which drives the DEFAULT
        fingerprint-preserving `run_to_completion`) **intentionally un-composed** — there is NO single domain
        entry point that plays live combat nodes AND then plays the boss to a run-END. **Composing them into
        one hands-off start→boss→victory play flow is 11.3's concern** (the human-acknowledged 2026-07-05
        decision). 11.3 composes them at the SCENE/orchestration layer: the flow drives live combat nodes
        node-by-node (`resolve_current_node_live` / a per-node live resolve) up to the boss terminus
        (`boss_encounter_pending()`), then drives the live boss fight (the `BossTurnResolver` loop on the
        arena board — the same seam `auto_play_boss_fight` uses, or a scene-driven equivalent) to
        `resolve_boss_victory()`. Preserve the fingerprint-safety posture: the DEFAULT `run_to_completion` (the
        v0 auto-resolve pre-boss) stays available for non-live simulation; the LIVE flow is the on-screen
        path. Read 11.2's `run_orchestrator.gd` live-method region + `test_finale_full_run.gd` before wiring.
  - [x] **The hero loadout is DRIVER-SUPPLIED (11.2's documented boundary, inherited).** 11.2's live methods
        take `hero_hp` / `hero_weapon_id` (defaulting to `LiveCombatResolver.DEFAULT_HERO_HP` /
        `DEFAULT_HERO_WEAPON == &"sword"`) because the class-kit → combat-loadout wiring is a LATER story. For
        11.3's on-screen play, the hero HP/weapon are still driver-supplied from the class start (read the
        selected class's `StartingKit` where the seam allows) — 11.3 does NOT build a new class-kit→loadout
        system. A robustness note for the retro: the scripted focus-fire hero is deterministic but NOT
        universally-winning across arbitrary seeds (a mutually-unreachable straggler fails loud —
        `live_combat_did_not_resolve`); the on-screen player DRIVES the hero via taps (the command bridge), so
        the human replaces the scripted driver for live play — but any auto-play / smoke path must use
        VERIFIED seeds (the approved-seed-catalog discipline, seed 4242 canonical for the finale).

- [x] **Task 2 — In-run tactical HUD + the G1 run-context projection (AC2)**
  - [x] Build the tactical board rendering + control bands from `TacticalBoardViewModel.to_dictionary()` (the
        pinned top-level keys: `width, height, cells, occupants, selected_cell, selected_entity_id, preview,
        commit_flow, inspect, zoom, action_availability, turn, outcome, event_log_summary, layout,
        accessibility`). Honor the **region → slot map** (appendix §1.2): `board`←cells/occupants/zoom,
        `preview`←preview, `confirm_cancel`←commit_flow/action_availability, `inspect`←inspect, `status`←turn +
        G1, `log_or_outcome`←event_log_summary/outcome. The scene reads the VM's pinned keys ONLY (a key
        outside the pinned set is an AC2 violation — the 11.1 exact-key-projection discipline).
  - [x] Wire player intent through **`TacticalCommandBridge.build_command(context, intent)`** (intents
        `move`/`attack`/`inspect`; any other id → `unsupported_intent`, disabled). Render the **two-step
        attack commit** via `TacticalAttackCommitFlow` (a first tap ARMS `attack_preview`; a second tap on the
        same target/weapon/actor CONFIRMS; `cancel()` clears with zero mutation). The `confirm_cancel` region
        binds `commit_flow.confirm_available`/`.cancel_available` (flow-gated). Movement commits via a `move`
        bridge intent (a symmetric move-confirm is a 11.3 presentation choice, NOT a required new VM —
        appendix §2.2 note / §16.1 non-gap).
  - [x] Render the **preview-vs-committed distinction with the non-color channels** (appendix §2.3): bind
        `feedback_preview` (channels `[shape, label]`) vs `feedback_committed` (channels `[pattern, label,
        text]`) from the `accessibility.feedback` slot so the distinction survives with audio muted (NFR9).
        Render inspect visibility tiers (`inspect_visible`/`inspect_memory`/`inspect_hidden_unexplored`) and
        telegraph cues from the `accessibility.cues` catalog — the scene MAPS the emitted `cue_ids` to
        visuals, it invents no new reasons/cues.
  - [x] Render the **passive-reward modal** (`PassiveRewardModalViewModel` pinned `MODAL_KEYS` + the two-step
        `PassiveRewardCommitFlow` arm/confirm/cancel/dismiss) and the reward-pickup flow through the EXISTING
        Epic-6 contracts. `icon` is an id/placeholder STRING (11.4 supplies the art) — do NOT treat it as a
        texture path.
  - [x] **Resolve Contract gap G1 — the in-run HUD run-context projection** (appendix §1.3, §16 G1; owned by
        11.3). Add a thin fail-closed RefCounted read surface (name it e.g. `RunHudViewModel` under
        `godot/scripts/ui/view_models/`) that AGGREGATES the run-level context the tactical board VM does NOT
        carry, from the EXISTING domain sources: **hero HP** (during a level: the hero `TacticalEntityState`
        HP on the board; baseline from the class `StartingKit.baseline_hp` — note there is **NO** run-level HP
        field on `RunState`, which is WHY a projection is needed), **node progress**
        (`RouteState.cleared_node_ids` count vs total `RouteState.nodes()`), **gold** (`RiskEconomyState.gold`),
        **inventory / consumed-passive access** (the run inventory / consumed-passive surfaces). It pins an
        exact key set, projects a `has_*`-style gate for the absent/empty state, mints NO event, consumes NO
        RNG, mutates NOTHING. The HUD `status` region composes the tactical VM's `turn` slot with this G1
        read — it NEVER reaches into scene state for run context.
  - [x] Give the G1 projection a headless unit test (`godot/tests/unit/ui/`): assert it reads the correct
        pinned fields from a composed domain fixture, fail-closes on null/absent inputs (empty projection, not
        a crash), and leaks no live handle into the domain (a returned field mutation never perturbs source).

- [x] **Task 3 — The route-map scene + the G2 route view model (AC1, AC2)**
  - [x] **Resolve Contract gap G2 — the route/run-map view model** (appendix §5.2, §16 G2; owned by 11.3).
        Today the run map would read `RouteState` / `RouteNode` DIRECTLY (there is NO dedicated route VIEW
        model). Add a thin fail-closed RefCounted route projection (name it e.g. `RouteMapViewModel` under
        `godot/scripts/ui/view_models/`) that projects, from the pinned route reads: `current_node_id`,
        `cleared_node_ids`, the SELECTION-legal `eligible_choice_ids()` (known + `REVEAL_REVEALED` + not
        cleared — NOT the looser `available_choice_ids()`), and per-node `type` (`RouteNode.TYPE_*`),
        `reveal_state` (`REVEAL_HIDDEN`/`REVEALED`/`CLEARED`), `depth`, `outgoing_link_ids`, and `clues`
        (`CLUE_*`). It owns NO route truth (the commit of a chosen node is the EXISTING route-advance command
        the flow submits — the map presents choices and reports the pick).
  - [x] Build the route-map scene from the G2 projection: present the current node + eligible choices with
        their clue chips + cleared history; node TYPE via icon + label (not color-only), reveal state via
        pattern + label (appendix §5.4). Report the picked node to the flow; the flow submits the
        route-advance command through the orchestrator.
  - [x] Give the G2 projection a headless unit test (`godot/tests/unit/ui/`): assert it projects
        `eligible_choice_ids()` (not `available_*`), the pinned node fields, the reveal-state vocabulary, and
        fail-closes on an empty/terminal route (no crash).

- [x] **Task 4 — On-screen resume + recovery states (AC3)**
  - [x] Wire the between-level resume path to real screens: `SaveManager.resume_route_position(save_path)` /
        `SaveManager.resume_run(save_path)` (the route delegators → `RunResumeService`) drive a resume from
        the persisted snapshot; the autosave entry points (`autosave_route_position` / `autosave_between_level`)
        fire at the between-node/between-level boundary the flow already reaches. The scene reads the
        structured `ActionResult` code — NOT stderr — as truth (a parse-failure emits one expected `ERROR:
        Parse JSON failed` line and still returns a structured error).
  - [x] Map each of the seven structured recovery codes to a clear on-screen message + a recovery affordance
        (retry / start fresh), per appendix §13.3: `save_not_found`, `save_open_failed`, `save_parse_failed`,
        `unsupported_save_schema`, `invalid_tactical_snapshot`/`missing_tactical_snapshot`,
        `invalid_rng_snapshot`. On failure NO partial state becomes active (the "no partial corrupt state"
        guarantee — the restore exposes zero restored objects). The profile-recovery surface at the outpost
        destination is 11.5's; 11.3 handles the RUN save/resume recovery on the run-flow side (§13.1 splits
        11.3 = run-resume path, 11.5 = outpost recovery surface).
  - [x] **The resume invariant (NFR13) the scene MUST respect:** a recovery screen may present a message + a
        retry/fresh-start choice, but it must NOT itself perturb the restored run (consume RNG, run a command,
        advance a turn). The domain does the restore; the screen renders the `ActionResult` and offers the
        choice. EXTEND the existing resume-invariant coverage (`test_run_resume_service.gd` /
        `test_between_level_save.gd`) to prove interrupted==uninterrupted holds through the seam the scene
        drives — do NOT rebuild the resume domain.

- [x] **Task 5 — Four-layout reach + rule-invariance (AC4)**
  - [x] Every scene honors the **semantic `TacticalLayoutProfile` region plan** (the testable source of truth)
        rather than hardcoding geometry: inject the real viewport/safe-area, read the profile, and lay out the
        region vocabulary (`board`/`preview`/`confirm_cancel`/`inspect`/`status`/`log_or_outcome`) per profile
        (`phone_portrait` stacked / `phone_landscape` side-rail / `tablet`/`desktop` comfortable). The board
        stays the dominant region on every profile; primary actions stay ≥44×44
        (`DEFAULT_MINIMUM_TOUCH_TARGET`). The invalid-viewport fallback (`layout.available: false` → portrait
        stacked) is honored, not re-derived.
  - [x] Honor the accessibility contract (appendix §0.5, §14.2): every critical meaning carries a non-color
        channel from the `TacticalAccessibilityModel` vocabulary; text respects the `TacticalTextScale` clamp
        `[0.85, 2.0]` (default 1.0) driven by `SettingsSnapshot.text_scale`. Changing the scale/profile NEVER
        alters board/RNG/turn/preview legality/outcome/log.
  - [x] Prove rule-invariance across profiles at the TESTABLE layer: extend the existing scene-free layout
        coverage (`test_tactical_layout_profiles.gd` / the `TacticalBoardViewModel.layout` slot) to assert the
        same board/preview/commit-flow/inspect/action-availability contract holds byte-identically across a
        `phone_portrait`→`desktop` profile change (the Story 2.5 pattern — feed the contracts through the VM
        across profile changes; state is preserved, rules unchanged). The `.tscn` geometry itself is verified
        by construction against the semantic plan.

- [x] **Task 6 — Invariants regression + full-suite green (AC4)**
  - [x] Re-verify every durable invariant is unmoved: the 23-key `RunSnapshot` gate (`test_run_snapshot.gd`),
        `ProfileSnapshot.SCHEMA_VERSION == 1` (`test_profile_snapshot.gd`), `SettingsSnapshot.SCHEMA_VERSION ==
        1` (`test_settings_snapshot.gd`), `RngStreamSet.required_streams()` == 7 (`test_rng_stream_set.gd`),
        the `DomainEvent.Type` enum tail UNCHANGED (`test_domain_event.gd` — a scene mints no event).
  - [x] Re-run every seed-regression fingerprint suite + confirm byte-identical (small/medium level, route,
        seed batch, finale). 11.3 is scene/presentation + two READ-ONLY view-model projections — it MUST NOT
        move any fingerprint. The `tools/dump_*` files stay untouched.
  - [x] Run the FULL headless suite via PowerShell (the `godot` binary is not on the Bash PATH — see Project
        Context Rules): `godot --headless --path C:\Sealsworn\godot --scene
        res://tests/headless/test_runner.tscn --quit-after 10`. Apply the false-PASS grep guard (the only
        acceptable stderr `ERROR:` lines are the 6 documented negatives: int64-overflow ×2, malformed-JSON ×3,
        `invalid_node_type` ×1 — plus any NEW documented negative-path test 11.3 adds, of which it should add
        none on the domain side). Run `git diff --check`.

- [x] **Task 7 — Update the deferred-work ledger + tracking (AC4, hygiene)**
  - [x] In `deferred-work.md` (new 11.3 entry): mark **RESOLVED** — Contract gap **G1** (the in-run HUD
        run-context projection) and **G2** (the route/run-map view model) from the 11.1 appendix; and the
        **polished-HUD-scene deferral carried from Story 2.5** (the `Control`/scene presenter under
        `godot/scripts/ui/presenters/` + `godot/scenes/ui/layouts/<profile>/` "left for a later story that
        grows the polished HUD" — 11.3 IS that story for the run-flow HUD). RE-RECORD still-open: the live
        AFFINITY call sites + affinity board treatment (11.4), the outpost SCENE + reveal RENDER + G3
        summary↔profile coupling (11.5), the meta-SPEND / unlock APPLICATION (11.6), the live in-node board /
        pending-fight SAVE (a later in-node-save story — 11.3's in-node fight state stays EPHEMERAL; the
        23-key gate stays 23), and **G4** (the settings view model — owner is the settings-scene owner, 11.3
        or 11.5; if 11.3 does NOT build a settings scene, leave G4 parked, do not resolve it). Note the
        originating story/date. Do NOT reopen or re-defer items unrelated to this story's surface.

## Dev Notes

### What this story is (and is not)

Epics 1-9 shipped a COMPLETE headless deterministic domain; **11.1** designed every run-flow screen on paper
(the UX appendix with pinned contracts + the G1-G4 gap ledger); **11.2** wired the scene-free LIVE domain
(the live combat loop + the live hero-death source + the boss-victory production call site) — but there is
**no on-screen shell**: `SceneManager` is a thin `change_scene_to_file` wrapper, the gameplay/board scenes
are empty `Node2D` placeholders, and the only presenter is `boot_controller.gd`. **11.3 builds the run-flow
scene navigation + the in-run HUD on top of the finished view-model/command-bridge/live-domain layer** — it
is the FIRST real scene-presentation story, and it is where the pre-boss descent becomes something a human
plays on screen.

**The single most important rule: this is PRESENTATION. Scenes OBSERVE domain state through view models and
SUBMIT player intent through the command bridge; they own ZERO tactical/run truth** (`project-context.md`;
architecture "Presentation observes domain state/events and submits commands through a command bridge").
11.3 does NOT rebuild the domain, does NOT add a command, does NOT mint an event, does NOT touch a save
key/RNG stream/fingerprint. The ONLY non-scene code it adds are the two thin READ-ONLY view-model
projections the appendix pre-authorized (G1 run-HUD context; G2 route map) — both fail-closed, both over
EXISTING domain state.

**Read the actual source before wiring — a wrong method/constant/pinned-key name is the primary
review-cycle cause.** The 11.1 Round-1 review caught exactly this class of error (an HP field mis-sourced on
`RunState`; a `range` vs `weapon_reach` key mix-up). The Epic-11 retro §"Story 11-1" Phase-7 note names it:
"dense internally-cross-referenced spec docs need a final resolve-every-§N sweep; field-source attributions
deserve pinned-key rigor" — cite the EXACT as-built method/const/key names, verified against source.

### The composition seam 11.3 INHERITS from 11.2 (the crux — do not rediscover)

**This is the single most load-bearing cross-story constraint for 11.3, surfaced explicitly by 11.2's
review + the Epic-11 retro-notes.** 11.2 shipped the live pieces but left two of them INTENTIONALLY
un-composed:

- `run_to_completion_live` / `resolve_current_node_live` / `resolve_combat_node_live`
  (`run_orchestrator.gd:1030`/`:906`/`:945`) drive LIVE combat nodes but STOP at the boss-setup terminus
  (`run_to_completion_live` returns `boss_encounter_started`) — they do NOT chain into the boss fight.
- `auto_play_full_run` (`:1188`) reaches the boss VICTORY but deliberately drives the DEFAULT
  `run_to_completion` (v0-auto-resolved pre-boss combat) to keep every route/reward/finale fingerprint
  byte-identical (documented at the method). So the LIVE pre-boss path and the boss auto-play are
  intentionally un-composed in 11.2.

**Composing them into one hands-off start→boss→victory play flow is 11.3's concern** — the human-acknowledged
2026-07-05 scope boundary (Epic-11 retro §"Story 11-2" Phase-7; `deferred-work.md` 11.2 review
`[Review][Decision]`). 11.3 composes them at the SCENE/orchestration layer, not by forking a new domain
method: the on-screen flow drives live combat nodes node-by-node up to `boss_encounter_pending()`, then drives
the live boss fight on the arena board (the `BossTurnResolver` loop + `resolve_boss_victory()` — the same seam
`auto_play_boss_fight` (`:1087`) uses) to the run-end. The pre-boss fingerprint-safety posture stays: the
DEFAULT `run_to_completion` (the v0 auto-resolve) remains the non-live simulation path; the LIVE flow is the
on-screen path. **11.2's boss auto-play adopted the resolver's validate-then-reject discipline (the two Round-1
fail-closed hardenings on `place_entity_for_setup` + arena-key validation) — 11.3's scene-driven boss/board
placement seams MUST adopt the same fail-closed discipline from the start** (Epic-11 retro §"Story 11-2":
"new orchestrator seams should adopt it from the start").

### The seam map (the exact as-built pieces 11.3 binds to) — READ THE SOURCE

Read each before wiring; the method signatures / pinned key sets / constants are load-bearing. Absolute paths
are under `C:\Sealsworn\godot\`.

| Seam | Existing contract (method / pinned keys / const) | Path | Load-bearing detail |
|---|---|---|---|
| **Scene navigation autoload (EXTEND, keep thin)** | `SceneManager.change_scene(scene_path) -> Error`; `var current_scene_path` | `scripts/autoloads/scene_manager.gd` | 8 lines today — a bare `get_tree().change_scene_to_file`. Extend with a named route table + a `RunEndOutcome.next_destination`→destination transition. It navigates; it owns no run/tactical truth. |
| **Run-end destination (the AC1 routing signal)** | `RunEndOutcome` pinned `DICTIONARY_KEYS = [phase, outcome_or_cause, next_destination, meta_progression_eligible]`; `next_destination` is ALWAYS `RUN_END_DESTINATION_OUTPOST == "outpost"` for a terminal run | `scripts/run/run_end_outcome.gd` | The run-end return routes off `next_destination`. `COMPLETED_OUTCOMES` distinguishes victory/completion from a failure cause. A non-terminal run yields `next_destination == ""`. |
| **Run seed authority (launch handoff)** | `GameSession.configure_seed(root_seed)` / `get_root_seed()` / `rng_snapshot()` / `restore_rng_snapshot(...)`; autoload | `scripts/autoloads/game_session.gd` | The thin run-seed autoload. The launch flow configures the seed; the orchestrator threads the RNG. |
| **Run start (AUTHORITATIVE fail-closed)** | `RunOrchestrator.start(root_seed: int, is_manual_seed := false, class_id := &"") -> ActionResult`; `.run: RunState` is the public run handle | `scripts/run/run_orchestrator.gd:185`, `:100` | The class-picker's confirm hands a `class_id` here (or via `OutpostViewModel.start_run_request`). A mis-enabled confirm CANNOT start a locked run — the command re-validates fail-closed. Read `run.route` for the route state. |
| **Live pre-boss node play (11.2 — INHERIT)** | `resolve_current_node_live(hero_hp, hero_weapon_id) -> ActionResult`; `resolve_combat_node_live(node, hero_hp, hero_weapon_id)`; `run_to_completion_live(...)` | `scripts/run/run_orchestrator.gd:906`/`:945`/`:1030` | Defaults `hero_hp = LiveCombatResolver.DEFAULT_HERO_HP`, `hero_weapon_id = DEFAULT_HERO_WEAPON (&"sword")`. `run_to_completion_live` STOPS at the boss terminus (`boss_encounter_started`) — 11.3 composes the boss fight after it. |
| **Boss terminus + arena (11.2/9.1)** | `boss_encounter_pending() -> bool`; `boss_arena_payload() -> Dictionary` (arena `board_snapshot` + `boss_slot` + `entrance`) | `scripts/run/run_orchestrator.gd:894`/`:890` | The live flow resumes from here to drive the boss fight. `auto_play_boss_fight(:1087)` is the reference composition (both-sides-simulated); a scene-driven boss loop mirrors its seam + its fail-closed placement discipline. |
| **Boss victory continuation (production call site)** | `resolve_boss_victory() -> ActionResult` — clears the boss node + `resolve_run_end(&"victory")` | `scripts/run/run_orchestrator.gd:813` | The live boss fight ends here on boss 0 HP. `RUN_COMPLETED_OUTCOME_VICTORY == "victory"`. |
| **Run-end resolution (death + completion)** | `resolve_run_end(outcome: StringName) -> ActionResult` → `CompleteRunCommand`; `RUN_FAILED_CAUSES = [hero_death, level_defeat, boss_defeat, abandoned]` | `scripts/run/run_orchestrator.gd:770` | A live hero-death auto-fires this (11.2 AC2). The scene NAVIGATES on the `RunEndOutcome` it returns; it does not re-decide the run. |
| **Tactical board VM (the HUD's board surface)** | `TacticalBoardViewModel.to_dictionary()` — pinned top-level keys (see §1.2) incl. `layout`, `accessibility`, `action_availability`, `turn`, `outcome`, `event_log_summary`; `from_domain(context)` / `from_domain(null)` → empty VM | `scripts/ui/view_models/tactical_board_view_model.gd` | Composes the whole board. `from_domain(null)` yields a zero-cell VM — the HUD renders an empty board, not a crash. Region→slot map in appendix §1.2. |
| **Command bridge (player intent → command)** | `TacticalCommandBridge.build_command(context, intent) -> CommandBridgeResult`; intents `move`/`attack`/`inspect` (else `unsupported_intent`) | `scripts/ui/command_bridge/tactical_command_bridge.gd` | The SCENE's tap-submission seam. Validates before mutation; returns `command_ready`/`disabled_result`/`metadata_only`. The scene reads availability; it does not execute directly. |
| **Two-step attack commit** | `TacticalAttackCommitFlow.to_dictionary()` = `{mode, actor_id, target_cell, target_entity_id, weapon_id, preview, confirm_available, cancel_available, reason, cue_ids}`; `tap_attack_target` / `confirm_attack` / `cancel` / the guarded clears | `scripts/ui/view_models/tactical_attack_commit_flow.gd` | `mode` is `"none"`/`"attack_preview"`. First tap ARMS; second tap on SAME target/weapon/actor CONFIRMS; `cancel()` = zero mutation. `confirm_cancel` region binds `.confirm_available`/`.cancel_available`. |
| **Preview read surfaces** | `TacticalMovementPreview.from_query(...)` (metadata `path`/`movement_cost`/`movement_budget`); `TacticalAttackPreview.from_query(...)` (metadata key is `weapon_reach`, NOT `range`) | `scripts/ui/view_models/tactical_movement_preview.gd`, `tactical_attack_preview.gd` | The preview-VM metadata uses `weapon_reach`; `range` is the DISTINCT command-bridge attack-metadata key — do NOT conflate (the 11.1 review caught this). Land in the VM `preview` slot. |
| **Inspect view** | `TacticalInspectView.from_context(context, target_cell, options)` — fields incl. `visibility_state`, `cell`, `occupant`, `movement`, `attack_preview`, `hazards`, `telegraphs`, `cue_ids` | `scripts/ui/view_models/tactical_inspect_view.gd` | FR12 coverage. Visibility tiers `inspect_visible`/`inspect_memory`/`inspect_hidden_unexplored` each carry a non-color channel. |
| **Passive-reward modal** | `PassiveRewardModalViewModel` pinned `MODAL_KEYS = [has_passive, passive_id, icon, display_name, flavor, exact_mechanical_effects, consume_text, destroy_text, has_unknown_consequences, consequences_text]` + `PassiveRewardCommitFlow` (arm_consume/arm_destroy/confirm/cancel/dismiss) | `scripts/ui/view_models/passive_reward_modal_view_model.gd`, `passive_reward_commit_flow.gd` | FR55 upside+downside shown before accept. `icon` is an id STRING (11.4 supplies art). Non-passive input → `has_passive: false` (fail-closed). |
| **Layout profile (region plan — testable truth)** | `TacticalLayoutProfile.to_dictionary()` = `profile_id`, `regions` (`board`/`preview`/`confirm_cancel`/`inspect`/`status`/`log_or_outcome`), `control_slots`, `minimum_touch_target`, `density`, `spacing`, `board_priority`; `DEFAULT_MINIMUM_TOUCH_TARGET = Vector2(44,44)`; `PROFILE_*` ids | `scripts/ui/view_models/tactical_layout_profile.gd` | Scenes inject a real viewport/safe-area + read the profile; they do NOT re-derive geometry. Invalid viewport → `available:false` → portrait stacked. |
| **Accessibility model (non-color cues)** | `TacticalAccessibilityModel.to_dictionary()` = `cues`, `feedback`, `text_scale`, `color_independent:true`; `CHANNEL_*` = `[shape, icon, label, pattern, text]`; `feedback_preview` `[shape,label]` vs `feedback_committed` `[pattern,label,text]` | `scripts/ui/view_models/tactical_accessibility_model.gd` | The preview-vs-committed distinction survives audio-muted (the `feedback` slot marks `visual_available:true`). The scene MAPS cue_ids to visuals; invents none. |
| **Text scale** | `TacticalTextScale` clamp `[MIN 0.85, MAX 2.0]` default 1.0; hints `label_scale_hint`/`spacing_hint`/`minimum_label_height`; driven by `SettingsSnapshot.text_scale` | `scripts/ui/view_models/tactical_text_scale.gd` | Value-only presenter hints; constructs no fonts. Changing scale never alters gameplay. |
| **Hero select VM (class picker)** | `HeroSelectViewModel` per-entry `ENTRY_KEYS = [class_id, display_name, selectable, unlock_hint]`; `classes()` / `is_class_selectable(id)` / `selectable_class_ids()` / `locked_class_ids()` | `scripts/ui/view_models/hero_select_view_model.gd` | Roster in `ClassRepository.class_ids()` order (warrior/pyromancer/ranger selectable; necromancer/shadeblade locked). The authoritative gate is `RunStartCommand`; the grey-out is a UX layer on top. |
| **Route reads (G2 source — no VM today)** | `RouteState.current_node_id` / `cleared_node_ids` / `nodes()` / `node_by_id(id)` / `eligible_choice_ids()`; `RouteNode.type` (`TYPE_*`) / `reveal_state` (`REVEAL_*`) / `depth` / `outgoing_link_ids` / `clues` (`CLUE_*`) | `scripts/run/route_state.gd`, `route_node.gd` | The map presents `eligible_choice_ids()` (NOT the looser `available_choice_ids()`). **G2: 11.3 adds a thin route projection over these.** |
| **Outpost VM (start-another-descent seam)** | `OutpostViewModel.start_run_request(root_seed, is_manual_seed?, class_id?) -> Dictionary` (pinned `START_REQUEST_KEYS`); `can_start_run()`; `_init(profile, run_summary, first_death_beat, class_repository, recovery_state)` | `scripts/ui/view_models/outpost_view_model.gd:332`/`:320`/`:198` | The start seam produces a REQUEST value; the CALLER hands it to a FRESH `RunOrchestrator.start`. **The polished outpost SCENE is 11.5** — 11.3 only NAVIGATES to the outpost destination; do not build the dashboard. |
| **G1 source — hero HP / node / gold / inventory** | hero HP: hero `TacticalEntityState` on the board / `StartingKit.baseline_hp` (NO run-level HP on `RunState`); node progress: `RouteState.cleared_node_ids` + node count; gold: `RiskEconomyState.gold`; inventory/consumed-passive surfaces | see the appendix §16 G1 row | **G1: 11.3 adds a thin run-HUD projection aggregating these for the `status` region.** No single run-HUD projection exists today. |
| **Save/resume (run side — AC3)** | `SaveManager.resume_run(save_path)` / `resume_route_position(save_path)` / `autosave_route_position(snapshot, path)` / `autosave_between_level(snapshot, path)` → `RunResumeService`; returns a structured `ActionResult` code | `scripts/autoloads/save_manager.gd:32`/`:50`/`:42`/`:23` | The 7 recovery codes map to §13.3 screens. Read the `ActionResult` code as truth, NOT stderr. NO partial state on failure. The resume path consumes NO RNG / runs NO command / advances NO turn. |
| **The reference presenter (the only one today)** | `BootController` (`Control`) → `_ready()` → `call_deferred("_enter_main_scene")` → `SceneManager.change_scene(MAIN_SCENE_PATH)` | `scripts/ui/presenters/boot_controller.gd` | The pattern: a `Control` presenter that guards `has_node("/root/SceneManager")`, drives navigation via the autoload, and logs via `Diagnostics`. New presenters follow this shape. |
| **The reference live-combat driver (11.2)** | `LiveCombatResolver` — the scene-free live combat driver + `DEFAULT_HERO_HP` / `DEFAULT_HERO_WEAPON (&"sword")` / `drive_hero_step_against(...)` | `scripts/run/live_combat_resolver.gd` | The headless driver the SCENE replaces with tap-submitted commands for live play. The scene drives the SAME context (`TacticalActionContext` + `EnemyTurnResolver` + `CombatOutcomeEvaluator`); the human is the hero driver. |

### The G1 / G2 projections 11.3 owns (the appendix pre-authorized these — resolve them here)

The 11.1 appendix §16 recorded four contract gaps and resolved none. **G1 and G2 are 11.3's** (G3 → 11.5;
G4 → the settings-scene owner, 11.3 or 11.5). Build BOTH as thin fail-closed RefCounted READ surfaces under
`godot/scripts/ui/view_models/` — they aggregate/project EXISTING domain state for the scenes, mint no event,
consume no RNG, mutate nothing, and pin an exact key set with a `has_*`-style absent-state gate:

- **G1 — in-run HUD run-context projection** (the HUD `status` region; appendix §1.3, §16 G1). Aggregates
  **hero HP** (hero `TacticalEntityState` HP during a level / `StartingKit.baseline_hp` baseline — there is NO
  run-level HP field on `RunState`, which is WHY this projection exists), **node progress**
  (`RouteState.cleared_node_ids` count vs `RouteState.nodes()` total), **gold** (`RiskEconomyState.gold`), and
  **inventory / consumed-passive access** (the run inventory / consumed-passive surfaces). The HUD composes the
  tactical VM's `turn` slot with this G1 read — NEVER scene state.
- **G2 — route/run-map view model** (the route-map scene; appendix §5.2, §16 G2). Projects `current_node_id`,
  `cleared_node_ids`, `eligible_choice_ids()` (the SELECTION-legal set — NOT `available_choice_ids()`), and
  per-node `type`/`reveal_state`/`depth`/`outgoing_link_ids`/`clues`. Owns no route truth (the node commit is
  the existing route-advance command the flow submits).

Both get a headless unit test proving the pinned-field reads, the fail-closed absent-state, and no
live-handle leak into the domain.

### Testability reality (READ — the harness is scene-free; plan tests accordingly)

**The headless test harness (`godot/tests/headless/test_runner.gd`) instantiates each test via `script.new()`
and calls `.run()` — it does NOT run tests inside a `SceneTree` with `add_child` / `await get_tree()`.** The
whole 168-test suite is scene-free `RefCounted` domain/VM tests. There is NO `SceneTree`-based test-runner,
NO `ui_commands` integration test today (the dir is empty), and the `unit/ui/` tests all exercise view models
directly (never a `Control`/`.tscn`). This is the SAME reality Story 2.5's deferred-work entry names: the
`Control`/scene presenter was deferred precisely "to keep tactical layout decisions in a testable semantic
profile first."

**Consequence for 11.3's test strategy** (this is a real constraint, fold it into the plan — do not pretend
`.tscn` files are unit-testable by this harness):

- The **TESTABLE layer** is: (a) the G1 + G2 view-model projections (headless unit tests, `unit/ui/`); (b) the
  extended `SceneManager` flow-routing LOGIC that can be exercised without a live `SceneTree` — pull the
  route-table lookup + the `RunEndOutcome.next_destination`→destination mapping into a testable pure
  method/helper (a `RefCounted` route resolver the autoload delegates to) so it can be unit-tested with
  `script.new()`; (c) the layout/accessibility rule-invariance across profiles (extend
  `test_tactical_layout_profiles.gd` + the `TacticalBoardViewModel.layout` slot, the Story 2.5 pattern); (d)
  the resume-invariant through the seam the scene drives (extend `test_run_resume_service.gd` /
  `test_between_level_save.gd`).
- The **`.tscn` + `Control` presenter wiring itself is verified by CONSTRUCTION** against the semantic
  contracts (it reads pinned VM keys, submits bridge intents, honors the region plan) + the AC1 code-audit
  (no scene node mutates domain state outside the bridge/orchestrator). Do NOT claim a `SceneTree` unit test
  the harness cannot run; if a lightweight headless smoke that instantiates a presenter's DATA path (without a
  full scene tree) adds value, keep it scene-free and additive. **Prefer to push logic OUT of the `.tscn` into
  testable RefCounted seams** (the whole architecture bias) so the untestable surface is minimal glue.

### Previous-story intelligence & the Epic-11 retro-notes (the constraints 11.3 inherits)

- **11.2 (immediately prior, DONE) is 11.3's foundation.** It shipped the live combat loop + live hero-death
  source + boss-victory production call site (`LiveCombatResolver`, the additive `RunOrchestrator` live
  methods). Its Dev Agent Record + review are the definitive guide to the live seam. The three things 11.3
  MUST inherit knowingly:
  1. **The un-composed live-pre-boss vs boss-auto-play seam** (the crux above) — composing them is 11.3's job.
  2. **The driver-supplied hero loadout** — `hero_hp`/`hero_weapon_id` are caller-supplied; the class-kit→
     loadout wiring is a LATER story; the on-screen human drives the hero via taps.
  3. **The fail-closed placement discipline** — 11.2's boss-arena placement seams adopted validate-then-reject
     (the two Round-1 hardenings); 11.3's scene-driven board/boss placement seams adopt it from the start.
- **Epic-11 retro-notes (`_bmad-output/auto-gds/retro-notes/epic-11.md`) — the constraints ratified by earlier
  stories that bind 11.3:**
  - §"Story 11-1" Phase-7: **resolve every §N cross-ref against the section map; field-source attributions
    deserve pinned-key rigor.** 11.3 cites MANY appendix §N sections + MANY pinned VM keys — verify each §N
    and each key/field against the appendix + the as-built source before relying on it (the 11.1 review's
    hero-HP-on-`RunState` mis-source is the exact trap; the G1 row here already corrects it: HP is on the
    board entity / `StartingKit`, NOT `RunState`).
  - §"Story 11-2" Phase-5: **the scripted live-combat hero is deterministic but not universally-winning**; a
    mutually-unreachable straggler fails loud. For on-screen play the human is the driver, but any auto-play /
    smoke uses VERIFIED seeds (seed 4242 canonical). A universally-winning hands-off run needs a stronger hero
    driver or class-kit→loadout wiring — NOT 11.3's to build.
  - §"Story 11-2" Phase-5: **the run-level SYSTEM event stream (reserved high base) stays DISTINCT from the
    tactical board-event id space** (mixing them produced a real duplicate id). 11.3 does not merge streams
    (it reads/renders), but if the scene-driven boss composition interleaves fight + run-end events, keep the
    two id spaces distinct exactly as `auto_play_boss_fight` does (`BOSS_FIGHT_SEQUENCE_BASE = 100000` for the
    run-level SYSTEM stream; the arena board's own counter for board events).
  - §"Story 11-2" Phase-7: **11.3 MUST know the live pre-boss path and the boss auto-play are intentionally
    un-composed — composing them is 11.3's concern; new orchestrator seams adopt the validate-then-reject
    discipline from the start.** (Re-stated because it is the single most important inherited constraint.)
- **The 11.1 appendix is 11.3's design spec.** Every screen 11.3 builds has a settled paper design in
  `ux-appendix-run-flow.md`: HUD §1, preview/confirm §2, inspect §3, passive modal §4, run map §5, hero select
  §6, save/resume recovery §13, the layout+accessibility pass §14, the affinity read §15 (11.4 applies the
  treatment; 11.3 may surface the READ surface). The outpost §7, run summary §8, and the reveal beats §9/§10
  are 11.5's — do not build them. Honor the appendix's exact-key-projection + fail-closed + non-color-channel
  + four-layout contracts as the testable sources of truth.

### Deferred-work overlaps folded in (ONLY entries touching this story's surface)

From `_bmad-output/implementation-artifacts/deferred-work.md` (a project-wide ledger — most entries are out of
scope). The entries that overlap 11.3's surface, folded in above; do NOT reopen unrelated items:

- **The polished-HUD-scene deferral (from Story 2.5, ledger ~1033-1041):** "A `Control`/scene presenter under
  `godot/scripts/ui/presenters/` and `godot/scenes/ui/layouts/<profile>/` is left for a later story that
  grows the polished HUD … keep tactical layout decisions in a testable semantic profile first." **11.3 IS
  that later story for the run-flow HUD.** It builds the `Control` presenters + the profile-aware HUD scenes
  ON TOP of the already-testable `TacticalLayoutProfile` semantic plan (which stays the source of truth — the
  scene honors it, does not replace it). Task 7 marks this RESOLVED for the run-flow HUD.
- **Contract gaps G1 + G2 (from 11.1's appendix §16):** the in-run HUD run-context projection (G1) and the
  route/run-map view model (G2) — **11.3 resolves both** (Tasks 2 + 3). Task 7 marks them RESOLVED.
- **The 11.2 splits re-carried as still-open (NOT 11.3's, except where noted):** the live AFFINITY call sites
  + affinity board treatment → **11.4** (11.3's live combat runs a plain generated level; `assign_affinity`
  stays un-wired); the outpost SCENE + reveal RENDER + the G3 Oath-Shard summary↔profile coupling → **11.5**;
  the meta-SPEND / unlock APPLICATION → **11.6**; the live in-node board / pending-fight SAVE → a later
  in-node-save story (11.3's in-node fight state stays EPHEMERAL — the 23-key `RunSnapshot` gate stays 23).
- **G4 (the settings view model, appendix §16):** owned by "the settings-scene owner (11.3 or 11.5 per the
  eventual scene split)." 11.3 does NOT commit to building the settings scene; if it does not, G4 stays parked
  (do not resolve it). If 11.3 renders any settings surface, it MUST NOT present a difficulty selector (the
  ratified non-goal, §12.3) and reads `SettingsSnapshot` through `SettingsManager` (the frozen
  `SCHEMA_VERSION == 1`, no new store).

### Project Structure Notes

- **Where the code goes (project-context "File Placement"):** UI scenes go under `godot/scenes/ui/`; gameplay
  shell + board scenes under `godot/scenes/game/`. Presenters/view models under `godot/scripts/ui/` (presenters
  in `scripts/ui/presenters/`, the G1/G2 view-model projections in `scripts/ui/view_models/`). The `SceneManager`
  autoload stays in `scripts/autoloads/`. Tests under `godot/tests/` mirroring the domain (VM projection tests
  in `tests/unit/ui/`; resume-invariant in `tests/integration/save/` or `tests/unit/save/`; layout in
  `tests/unit/ui/test_tactical_layout_profiles.gd`).
- **`SceneManager` / presenters may OBSERVE domain state + SUBMIT commands but MUST NOT mutate tactical state
  directly** (`project-context.md` "scenes/ and scripts/ui/ may observe domain state and submit commands but
  must not mutate tactical state directly"). The presenters read view models + submit bridge intents /
  orchestrator methods; the domain (`RunOrchestrator` + the commands) owns all state. The G1/G2 projections
  are READ-ONLY (they compute nothing gameplay-affecting).
- **Keep `SceneManager` a THIN autoload.** It navigates + routes off the domain-reported destination; it owns no
  gameplay decision. Pull any testable routing logic into a `RefCounted` helper the autoload delegates to (so
  the scene-free harness can test it).
- **Do NOT modify** `prototype/` (frozen), `_bmad/` (installer-managed), the `.agents/` legacy skills, or the
  pinned seed-regression fingerprint files (`tools/dump_*`). 11.3 is scene/presentation + two read-only
  projections — it MUST move no fingerprint.
- **The empty placeholder scenes are 11.3's to fill:** `scenes/game/gameplay_shell.tscn` +
  `scenes/game/tactical_board.tscn` are empty `Node2D`s today — replace them with the real board/HUD scenes.
  `scenes/app/boot.tscn` → `main.tscn` boot chain stays (extend `main.tscn` / the flow so it enters hero
  select rather than the empty gameplay shell, or route boot → hero select via `SceneManager`).

### Project Context Rules

Extracted from `project-context.md` (the canonical rulebook — refreshed after Epic 9). The rules that bear on
THIS story:

- **Domain-first, scene-free authority (the #1 rule for 11.3).** "Godot scenes, `Control` nodes, audio, VFX,
  and animation are presentation. They must not own authoritative tactical state." Every 11.3 scene READS a
  view model + SUBMITS a command-bridge/orchestrator intent; NONE owns run/tactical truth. A scene may not
  consume gameplay RNG, execute a command outside the bridge, or advance a turn as a side effect of rendering
  (the NFR13 resume/determinism invariant).
- **Presentation observes via view models + submits via the command bridge.** UI observes domain state through
  view models / read surfaces and submits player intent through the command bridge. 11.3 binds only to pinned
  VM keys + bridge intents; a key outside the pinned set is an AC2 violation (the exact-key-projection
  discipline).
- **Determinism / interrupted==uninterrupted (NFR13).** Resumed outcomes match uninterrupted play. The
  resume/restore path the scene drives consumes NO RNG, executes NO command, advances NO turn, mutates neither
  the source state nor the save file (the snapshot-purity contract). AC3 proves this holds through the seam.
- **The 23-key `RunSnapshot` gate / no new save key.** 11.3's in-node board / pending fight state is
  EPHEMERAL (not persisted) — a mid-encounter save is a LATER in-node-save story (out of scope). The 23-key
  gate stays 23; `ProfileSnapshot`/`SettingsSnapshot` `SCHEMA_VERSION == 1`; the 7 named RNG streams frozen.
- **Append-only `DomainEvent.Type` — but 11.3 adds NONE.** A scene reads/submits; it mints no domain event. The
  enum tail is UNCHANGED; `domain_event.gd` has ZERO diff.
- **Difficulty is a HARD non-goal.** No selectable difficulty ladder anywhere (a regression test enforces the
  absence on `SettingsSnapshot`). If 11.3 renders a settings surface, NO difficulty selector.
- **Color-independence + scalable text (NFR8/NFR9).** Every critical meaning carries a non-color channel from
  the `TacticalAccessibilityModel` vocabulary (`shape`/`icon`/`label`/`pattern`/`text`); text respects the
  `TacticalTextScale` clamp `[0.85, 2.0]`. The preview-vs-committed distinction (§2.3) is the load-bearing
  non-color requirement.
- **Four-layout without rule changes (FR66/NFR7).** Phone portrait / phone landscape / tablet / desktop share
  ONE tactical experience; scenes honor the semantic `TacticalLayoutProfile` region plan (the testable source
  of truth) rather than hardcoding geometry; orientation/profile changes NEVER alter rules.
- **No cloud/accounts/multiplayer/telemetry, no Godot .NET/C#** (unless the architecture is explicitly revised
  — it is not). 11.3 is offline-first typed GDScript on Godot 4.6.3, mobile-first with desktop parity.
- **Godot / testing.** Godot 4.6.3 stable, typed GDScript. New systems get a test location before
  implementation. The FULL headless suite is the gate (168 PASS at 11.2 close — 11.3 may GROW it with the
  G1/G2/layout/resume tests): run via PowerShell (the `godot` binary is not on the Bash PATH):
  `godot --headless --path C:\Sealsworn\godot --scene res://tests/headless/test_runner.tscn --quit-after 10`
  (or the Bash-reachable binary `C:/Users/Rasmus/Godot_v4.6.3-stable_win64.exe/Godot_v4.6.3-stable_win64_console.exe`).
  Apply the false-PASS grep guard (the only acceptable stderr `ERROR:` lines are the 6 documented negatives:
  int64-overflow ×2, malformed-JSON ×3, `invalid_node_type` ×1). Run `git diff --check`.

### References

- **Story source (verbatim ACs):** `_bmad-output/planning-artifacts/epics.md` — Epic 11 §"Story 11.3: Run Flow
  Scene Navigation and In-Run HUD" (lines ~2646-2672). Epic 11 List entry + implementation notes: lines
  ~489-495 (consumes the Epic-2 tactical presentation contracts, the 8.6 `OutpostViewModel`, the 9.3
  `BossTurnResolver` live loop, 9.5 `resolve_boss_victory()`). The 2026-07-04 Epic-11-insertion traceability:
  lines ~403-405; FR32 as-built note: line ~307; FR68 flow expansion + the UI-frame list: `gdd.md` 599 / FR68
  (epics.md 158).
- **The design spec (11.1 appendix — 11.3's screen-by-screen contract):**
  `_bmad-output/planning-artifacts/ux-appendix-run-flow.md` — HUD §1 (+ the G1 run-context need §1.3), preview/
  confirm §2 (the `weapon_reach` vs `range` warning §2.2), inspect §3, passive modal §4, run map §5 (+ the G2
  route-VM need §5.2), hero select §6, save/resume recovery §13 (the run side is 11.3, §13.1), the layout+
  accessibility pass §14, the affinity read §15, the contract-gap ledger §16 (G1+G2 owned by 11.3; G3→11.5;
  G4→settings-scene owner), the handoff summary §17.
- **The immediately-prior story (the live-seam foundation, DONE):**
  `_bmad-output/implementation-artifacts/11-2-live-combat-loop-and-hero-death-source.md` — the live-method
  region + the un-composed-seam `[Review][Decision]` (Round 1) + the driver-supplied-hero / fail-closed-
  placement / distinct-id-space notes in its Completion Notes + Review Findings. Its deliverable
  `godot/scripts/run/live_combat_resolver.gd` + the additive `RunOrchestrator` live methods.
- **FR/NFR text (`epics.md` inventory):** FR1 (24 — full loop), FR31 (85 — defeat the Larval Avatar), FR32 (87
  — hero death → outpost, the live loss the HUD renders), FR55 (132 — clear cursed-reward upside/downside),
  FR66 (154 — four-layout without rule changes), FR68 (158 — the UI-flow roster), NFR7 (179 — readable on
  phone), NFR8 (181 — scalable text), NFR9 (182 — colorblind-safe/no-color-only), NFR13 (190 — deterministic
  under seeded execution), NFR14 (192 — headless without rendering/UI). FR12 (46 — inspect coverage).
- **Existing source (READ before wiring — all under `godot/`):**
  `scripts/autoloads/scene_manager.gd` (the 8-line thin nav to EXTEND);
  `scripts/autoloads/game_session.gd` (`configure_seed`/`rng_snapshot`);
  `scripts/autoloads/save_manager.gd` (`resume_run`:32 / `resume_route_position`:50 / `autosave_*`:23/:42);
  `scripts/ui/presenters/boot_controller.gd` (the ONLY presenter — the pattern to follow);
  `scripts/run/run_orchestrator.gd` (`start`:185, `.run`:100, the live methods `resolve_current_node_live`:906
  / `resolve_combat_node_live`:945 / `run_to_completion_live`:1030 / `auto_play_boss_fight`:1087 /
  `auto_play_full_run`:1188, `boss_encounter_pending`:894 / `boss_arena_payload`:890, `resolve_run_end`:770 /
  `resolve_boss_victory`:813);
  `scripts/run/run_end_outcome.gd` (`DICTIONARY_KEYS` + `next_destination` == outpost);
  `scripts/run/route_state.gd` + `route_node.gd` (the G2 source — `eligible_choice_ids()` / `TYPE_*` /
  `REVEAL_*` / `CLUE_*`);
  `scripts/run/risk_economy_state.gd` (`gold` — the G1 gold source) + `scripts/run/inventory_state.gd` (the G1
  inventory source);
  `scripts/ui/view_models/tactical_board_view_model.gd` (the HUD board surface + the region→slot map),
  `tactical_command_bridge.gd` (`build_command`), `tactical_attack_commit_flow.gd`,
  `tactical_movement_preview.gd` / `tactical_attack_preview.gd` (the `weapon_reach` metadata key),
  `tactical_inspect_view.gd`, `passive_reward_modal_view_model.gd` / `passive_reward_commit_flow.gd`,
  `tactical_layout_profile.gd` (the region plan + `DEFAULT_MINIMUM_TOUCH_TARGET`),
  `tactical_accessibility_model.gd` (`feedback_preview`/`feedback_committed` + `CHANNEL_*`),
  `tactical_text_scale.gd`, `hero_select_view_model.gd` (`ENTRY_KEYS`), `outpost_view_model.gd`
  (`start_run_request`:332 / `_init`:198 / `can_start_run`:320);
  `scripts/run/starting_kit.gd` (`baseline_hp` — the G1 hero-HP baseline);
  `scripts/run/live_combat_resolver.gd` (`DEFAULT_HERO_HP`/`DEFAULT_HERO_WEAPON`/`drive_hero_step_against`).
- **The tests to EXTEND (do not rebuild):** `godot/tests/headless/test_runner.gd` (the scene-free harness —
  understand it runs `script.new().run()`, NO `SceneTree`); `godot/tests/unit/ui/test_tactical_layout_profiles.gd`
  + `test_tactical_board_view_model.gd` (extend for the profile rule-invariance, the Story 2.5 pattern);
  `godot/tests/unit/save/test_run_resume_service.gd` + `godot/tests/integration/save/test_between_level_save.gd`
  (extend for the AC3 resume invariant through the scene-driven seam). NEW: G1/G2 projection unit tests under
  `godot/tests/unit/ui/`.
- **Auto-gds Epic-11 retro-notes (epic-wide inherited constraints):** `_bmad-output/auto-gds/retro-notes/
  epic-11.md` — §"Story 11-1" (resolve-every-§N + field-source pinned-key rigor), §"Story 11-2" (the scripted
  hero is not universally-winning; the run-level SYSTEM vs board-event id spaces stay distinct; **11.3 MUST
  compose the un-composed live-pre-boss + boss-auto-play seam; new orchestrator seams adopt validate-then-
  reject from the start**).
- **Deferred-work ledger (overlapping entries):** `_bmad-output/implementation-artifacts/deferred-work.md` —
  the polished-HUD-scene deferral (from 2.5, ~1033-1041); the 11.2 splits (the live affinity call sites →
  11.4; the outpost render + G3 → 11.5; the meta-spend → 11.6; the live in-node save → a later story;
  ~10-15/~25); the 11.1 gap ledger (G1/G2 → 11.3; G4 → settings-scene owner).
- **Testing command + Godot binary:** `CLAUDE.md` (the full-suite command) + the user memory note
  `godot-headless-test-binary-path` (the `godot` binary is not on the Bash PATH — run the suite via the
  PowerShell `godot` command or `C:/Users/Rasmus/Godot_v4.6.3-stable_win64.exe/Godot_v4.6.3-stable_win64_console.exe`;
  apply the false-PASS grep guard).

## Dev Agent Record

### Agent Model Used

Opus 4.8 (1M context) — `claude-opus-4-8[1m]` (auto-gds dev-story delegate)

### Debug Log References

- Full headless suite (canonical PowerShell command `godot --headless --path C:\Sealsworn\godot --scene res://tests/headless/test_runner.tscn --quit-after 10`): **175 PASS / 0 `^FAIL` / 0 SCRIPT ERROR**, "Headless tests passed.", exit 0 (baseline was 168; 11.3 added 7 new tests). False-PASS grep clean — exactly the 6 documented negatives (int64-overflow ×2, malformed-JSON ×3, `invalid_node_type` ×1); NO new negative-path noise.
- `git diff --check` clean (only benign LF→CRLF Windows line-ending warnings).
- Invariant source files (`domain_event.gd`, `run_snapshot.gd`, `rng_stream_set.gd`, every `tools/dump_*`) confirmed UNTOUCHED via `git status`/`git diff --stat`; the finale + level + route seed-regression suites pass (byte-identical fingerprints).
- Composition-seam probe: the `RunFlowController` hands-off flow (live pre-boss walk via `run_to_completion_live` → `auto_play_boss_fight` → `resolve_boss_victory()`) reaches `boss_victory` on the verified finale seed 4242 with the `LiveCombatResolver.DEFAULT_HERO_HP` (60) live-combat loadout. NOTE: the class `StartingKit.baseline_hp` (warrior 18) is a balance number, NOT a viable live-combat driver HP — threading it makes the scripted hero die; the live-combat driver therefore uses the resolver default HP while the G1 HUD *displays* the class baseline between levels (two distinct concerns; documented in `run_flow_controller.gd`).

### Completion Notes List

- **Task 1 (AC1) — app-flow scene navigation.** Extended the thin `SceneManager` with `go_to_stage(stage)` + `route_after_run_end(next_destination)`, both delegating to the new testable `RunFlowRouter` (the named flow-stage→`.tscn` route table + the `RunEndOutcome.next_destination`→stage mapping, pulled into a `RefCounted` so the scene-free harness can unit-test the routing LOGIC). Built the scene-free `RunFlowController` that COMPOSES the 11.2-inherited live-pre-boss + boss-auto-play seam into one hands-off start→boss→victory flow (drives `run_to_completion_live` to the boss terminus, then `auto_play_boss_fight` to `resolve_boss_victory()`) — NEVER touching the DEFAULT fingerprint-preserving `run_to_completion`; the scene-driven boss placement reuses `auto_play_boss_fight`'s fail-closed validate-then-reject discipline. Built the six presenters + scenes for the launch→hero-select→route-map→board→run-end walk (boot routes to hero select; hero-select confirm hands a `class_id` to `RunFlowController.start`; the route map reports the picked node → `RunOrchestrator.advance_to`; the board resolves the live node; a run-end routes off `next_destination`). The live run-flow handle is held across scene changes on a thin `GameSession` field.
- **Task 2 (AC2) — in-run HUD + G1.** The `tactical_board_presenter` renders `TacticalBoardViewModel.to_dictionary()` into the region→slot map (board/preview/confirm_cancel/inspect/status/log_or_outcome), wires the two-step attack commit via `TacticalAttackCommitFlow`, move/attack/inspect via `TacticalCommandBridge`, the passive-reward modal via `PassiveRewardModalViewModel`, and the accessibility feedback via `TacticalAccessibilityModel` — all the EXISTING Epic-2/6 contracts, pinned keys only. Resolved **G1**: `RunHudViewModel` aggregates hero HP (board entity / `StartingKit.baseline_hp` baseline), node progress (`RouteState`), gold (`RiskEconomyState`), inventory occupancy (`InventoryState`) — fail-closed, exact-key, no-live-handle; unit-tested. The status region composes the VM `turn` slot with the G1 read.
- **Task 3 (AC1/AC2) — route map + G2.** Resolved **G2**: `RouteMapViewModel` projects `current_node_id`/`cleared_node_ids`/`eligible_choice_ids()` (the reveal-gated selection-legal set — NOT `available_choice_ids()`) + per-node fields; unit-tested (incl. the eligible-vs-available discipline). The `route_map_presenter` renders node TYPE via icon+label and reveal state via a pattern marker (non-color channels) and reports the pick to `RunOrchestrator.advance_to`.
- **Task 4 (AC3) — on-screen resume + recovery.** The `save_recovery_presenter` drives `SaveManager.resume_route_position` and maps the structured `ActionResult` code (NOT stderr) to a message + retry/fresh-start affordance via the new testable `RunResumeRecoveryView` (all seven §13.3 codes, unit-tested, fail-closed on an unknown code). On success it seats the restored run via `RunOrchestrator.start_from` (no RNG/command/turn). Extended the EXISTING `test_run_route_position_save.gd` with a proof that interrupted==uninterrupted holds through the SaveManager AUTOLOAD delegators the scene drives (autosave→resume→start_from) AND that the resume consumes NO RNG (a next-draw peek).
- **Task 5 (AC4) — four-layout + rule invariance.** Every presenter builds geometry from the semantic `TacticalLayoutProfile` (injected viewport), never hardcoded pixels; primary actions are ≥44×44. Added `test_run_flow_layout_invariance.gd`: the board VM's rule-bearing slots are byte-identical across a `phone_portrait`→`desktop` change (only `layout` differs), the G1 HUD read is profile- AND text-scale-invariant, and the board stays dominant + controls reachable on both profiles.
- **Task 6 (AC4) — invariants regression.** 23-key `RunSnapshot` gate, `ProfileSnapshot`/`SettingsSnapshot` `SCHEMA_VERSION == 1`, `RngStreamSet.required_streams()` == 7, the `DomainEvent.Type` enum tail, and every seed-regression fingerprint all verified unmoved (the tests pass + the source files are untouched). Full suite green; false-PASS grep clean.
- **Task 7 — ledger + tracking.** `deferred-work.md` new 11.3 entry marks G1/G2 + the Story-2.5 polished-HUD deferral + the 11.2 composition seam RESOLVED, and re-records the still-open splits (11.4 affinity, 11.5 outpost render/G3, 11.6 meta-spend, the later in-node save, G4 parked). Sprint status + story status updated.
- **Testability reality honored:** the `.tscn`/Control wiring is verified BY CONSTRUCTION (a scene-load compile guardrail — `test_run_flow_scenes_load.gd` — proves every presenter compiles + every scene loads) + the AC1 read-only-projection discipline. The TESTABLE logic (G1/G2/recovery projections, the router, the composed controller flow, the layout invariance, the SaveManager resume invariant) is unit-tested. No SceneTree test is claimed (the harness is scene-free).
- **No breaking change.** No public interface removed/renamed, no config key/schema/CLI change, no migration step. `GameSession` gained additive `run_flow()`/`set_run_flow()`/`clear_run_flow()` accessors + a private handle field (thin, non-gameplay); `SceneManager` gained additive `go_to_stage`/`route_after_run_end` (the bare `change_scene` is unchanged); `BootController` now routes to the hero-select stage instead of the empty gameplay shell (a behavior change to the boot destination, not an interface change).

### File List

**New — production:**
- `godot/scripts/ui/flow/run_flow_router.gd` (AC1 — route table + next_destination mapping)
- `godot/scripts/ui/flow/run_flow_controller.gd` (AC1 — composed live-pre-boss + boss-auto-play flow sequencer)
- `godot/scripts/ui/view_models/run_hud_view_model.gd` (AC2 — G1 in-run HUD run-context projection)
- `godot/scripts/ui/view_models/route_map_view_model.gd` (AC1/AC2 — G2 route/run-map view model)
- `godot/scripts/ui/view_models/run_resume_recovery_view.gd` (AC3 — resume recovery-code mapping)
- `godot/scripts/ui/presenters/hero_select_presenter.gd`
- `godot/scripts/ui/presenters/route_map_presenter.gd`
- `godot/scripts/ui/presenters/tactical_board_presenter.gd`
- `godot/scripts/ui/presenters/gameplay_shell_presenter.gd`
- `godot/scripts/ui/presenters/run_end_presenter.gd`
- `godot/scripts/ui/presenters/save_recovery_presenter.gd`
- `godot/scenes/ui/hero_select.tscn`
- `godot/scenes/ui/route_map.tscn`
- `godot/scenes/ui/run_end.tscn`
- `godot/scenes/ui/save_recovery.tscn`

**New — tests:**
- `godot/tests/unit/ui/test_run_flow_router.gd`
- `godot/tests/unit/run/test_run_flow_controller.gd`
- `godot/tests/unit/ui/test_run_hud_view_model.gd`
- `godot/tests/unit/ui/test_route_map_view_model.gd`
- `godot/tests/unit/ui/test_run_resume_recovery_view.gd`
- `godot/tests/unit/ui/test_run_flow_layout_invariance.gd`
- `godot/tests/unit/ui/test_run_flow_scenes_load.gd`

**Modified:**
- `godot/scripts/autoloads/scene_manager.gd` (additive named-flow surface)
- `godot/scripts/autoloads/game_session.gd` (additive run-flow handle)
- `godot/scripts/ui/presenters/boot_controller.gd` (route to hero-select stage)
- `godot/scenes/game/gameplay_shell.tscn` (empty `Node2D` → real shell + presenter)
- `godot/scenes/game/tactical_board.tscn` (empty `Node2D` → real board + presenter)
- `godot/tests/unit/save/test_run_route_position_save.gd` (extended — SaveManager-delegated resume invariant)
- `_bmad-output/implementation-artifacts/deferred-work.md` (11.3 entry)
- `_bmad-output/implementation-artifacts/sprint-status.yaml` (status)

### Change Log

- 2026-07-05 — Story 11.3 implemented (auto-gds dev-story). Built the run-flow scene navigation (extended `SceneManager` + `RunFlowRouter` + `RunFlowController`), the in-run tactical HUD (the board presenter + the G1 `RunHudViewModel`), the route-map scene + the G2 `RouteMapViewModel`, on-screen resume + recovery (the `RunResumeRecoveryView` + the save-recovery presenter, extending the resume-invariant coverage), and four-layout reach + rule-invariance (the layout-invariance test). Composed the 11.2-inherited live-pre-boss + boss-auto-play seam into one hands-off flow (proven on seed 4242). No fingerprint moved; no save key/RNG stream/event added. Full headless suite green (175 PASS / 0 FAIL). Status → review.

### Review Findings

**Round 1 of 3** — code review (auto-gds primary review, 2026-07-05). Verdict: **Changes Requested**. Scope: the branch diff vs `main` (28 files, +2502/-9 under `godot/`) with this story as the spec. Calibration honored the testability-reality note (scene surface not SceneTree-unit-testable; logic steered into RefCounted seams — the review did NOT demand SceneTree tests). Independently re-verified: full headless suite **175 PASS / 0 `^FAIL` / 0 SCRIPT ERROR** ("Headless tests passed."), false-PASS grep clean beyond the 6 documented negatives (int64-overflow ×2, malformed-JSON ×3, `invalid_node_type` ×1); `git diff --check` clean; `domain_event.gd` / `run_snapshot.gd` / `rng_stream_set.gd` / every `tools/dump_*` / `profile_snapshot.gd` / `settings_snapshot.gd` UNTOUCHED (23-key gate, schema versions, 7 RNG streams, event-enum tail, seed fingerprints all provably unmoved). Every domain method / pinned VM key / field-source the new code binds to was verified against as-built source (the appendix §N / pinned-key rigor the retro demands) — all resolve; the G1/G2/recovery projections are exact-key, fail-closed, no-live-handle, and well unit-tested (incl. the load-bearing G2 eligible-vs-available discipline and the AC3 SaveManager-delegated resume/no-RNG invariant). Findings below.

- [x] [Review][Patch] **H1 (High) — the on-screen flow skips (auto-clears) the depth-0 opening combat node of every descent; AC1/AC2 "tactical board per node" is not met for the first node.** `RunStartCommand` parks `current_node_id` on `route.nodes()[0].id` — the depth-0 node, which `RouteGenerator` GUARANTEES is always a `combat` node ("a fair, legible run opener") — with `cleared_node_ids` empty (`run_orchestrator.gd`→`run_start_command.gd:266-267`; `route_generator.gd:350`). But the on-screen path never resolves it: `hero_select_presenter._on_confirm_pressed` navigates straight to `route_map` (`hero_select_presenter.gd:114`), and `route_map_presenter._render_map` only checks `boss_encounter_pending()` / `is_terminal()` before presenting `eligible_choice_ids()` (the depth-1 successors) — it has NO "the current node is an unresolved combat node → go play it" branch (`route_map_presenter.gd:64-95`). Picking a depth-1 choice calls `advance_to(choice)`, and `RouteAdvanceCommand` "seals the path behind the hero: the LEFT node moves to cleared_node_ids + REVEAL_CLEARED" (`route_advance_command.gd:111-123`) — so the unplayed depth-0 combat node is marked cleared without ever hosting a board. This DIVERGES from the domain's own live driver `run_to_completion_live`, which resolves-current-THEN-advances (`run_orchestrator.gd:1036-1047`); the divergence is invisible to the suite because the ONLY test of the walk (`test_run_flow_controller.gd`) drives `play_hands_off_to_run_end` → `run_to_completion_live` (resolve-then-advance), never the presenters' advance-then-resolve. Fix: the route-map (or the flow controller the presenters share) must resolve/play the current node when it is an unresolved live node before offering the next choices (e.g. on route-map entry, if `current_node_id` is a not-yet-cleared combat/elite node, route to the board to play it — mirroring the `run_to_completion_live` resolve-then-advance order), and add a headless test over the shared sequencing seam that asserts the depth-0 node is resolved (not silently cleared) on the on-screen path.
  - **RESOLVED (Round 1, 2026-07-05).** Added the SHARED SEQUENCING SEAM `RunFlowController.current_node_needs_board()` (`run_flow_controller.gd`) — a pure fail-closed query that returns true when the run is parked on an UNRESOLVED live node (a combat/elite node not yet in `cleared_node_ids`, and NOT the boss terminus), centralizing the "which nodes are hosted on a board" decision on the new shared const `LIVE_BOARD_NODE_TYPES = [combat, elite_combat]`. `route_map_presenter._render_map` now consults this seam AFTER the boss/terminal checks and BEFORE offering `eligible_choice_ids()`: an unresolved current node routes to the `tactical_board` stage (the shell plays it via the existing `resolve_combat_node_live` on entry, then returns to the map with the node cleared + successors revealed) — exactly the `run_to_completion_live` resolve-then-advance order, so the depth-0 opener is HOSTED on a board, never silently sealed by an advance. Added the headless test over the shared seam (`test_run_flow_controller.gd` — `_current_node_needs_board_gates_the_depth_0_opener`): on a fresh finale-seed run it asserts the depth-0 node is a still-uncleared combat opener that the seam FLAGS for the board, then that a live play (`resolve_combat_node_live` → `live_combat_victory`) is what clears it (NodeExitCommand on victory) and clears the seam — plus a fail-closed case off an unstarted run. Full suite green.
- [x] [Review][Patch] **M1 (Med) — `gameplay_shell_presenter` swallows a boss-fight error and soft-locks the shell.** In `_drive_current_stage` the boss-terminus branch calls `auto_play_boss_fight(flow.hero_hp())` then UNCONDITIONALLY `_render_between_levels` + `_route_to_run_end`, never checking `boss.is_error()` (`gameplay_shell_presenter.gd:56-60`) — unlike the combat-node branch, which checks `resolved.is_error()` and logs (`:72-76`). `auto_play_boss_fight` returns an ERROR (not a terminal run) when the bounded round loop fails to progress (`run_orchestrator.gd:1140-1142`) — a real possibility the story itself flags ("the scripted hero is deterministic but NOT universally-winning"). On that error the run is non-terminal, so `run_end_outcome()` yields `has_ended == false` / `next_destination == ""` and `SceneManager.route_after_run_end("")` no-ops (`ERR_DOES_NOT_EXIST`) → the player is stuck on the gameplay shell with no navigation and no `Diagnostics` breadcrumb. Fix: check `boss.is_error()`, log via `Diagnostics` (as the combat branch does), and surface a recoverable dead-end (e.g. route to the run-end/recovery surface) rather than a silent no-op.
  - **RESOLVED (Round 1, 2026-07-05).** The boss-terminus branch now checks `boss.is_error()` (mirroring the combat-node branch): on an error it logs `gameplay_shell_boss_fight_failed` with the `error_code` via `Diagnostics`, then routes to a recoverable dead-end via the new `_route_to_dead_end` helper (`gameplay_shell_presenter.gd`). Because the run is non-terminal on a boss-fight error, `route_after_run_end` would no-op — so the dead-end helper navigates DIRECTLY to the `run_end` stage, whose presenter already handles a non-ended run gracefully ("No completed run." + a "Return to the Outpost" affordance that boots back to hero select with the run-flow handle cleared). The player is never soft-locked and always has a breadcrumb + a way out. Fail-loud recovery, not a false claim the run ended. (The presenter branch itself is a `Control`/scene surface — verified by construction per the story's testability-reality note; the seam mirrors the already-tested combat-branch error handling.)
- [x] [Review][Decision] **L1 (Low) — `scenes/game/tactical_board.tscn` is filled but is dead as a navigation target.** `RunFlowRouter` maps the `tactical_board` stage to `gameplay_shell.tscn` (`run_flow_router.gd:45`), and the shell instantiates `TacticalBoardPresenter.new()` in code (`gameplay_shell_presenter.gd:37-40`) rather than instancing `tactical_board.tscn`; the `.tscn` is only ever touched by the compile guardrail. Harmless (the presenter is exercised via the shell), but the filled scene is redundant with its in-code instantiation — decide whether the shell should instance the scene (single source of the board scene) or whether `tactical_board.tscn` should be dropped. Human call (design intent).
  - **RESOLVED (Round 1, 2026-07-05) — human direction: instance the scene.** `gameplay_shell_presenter._build_board_presenter` now INSTANCES `scenes/game/tactical_board.tscn` (`TacticalBoardScene.instantiate() as Control` — the `.tscn`'s `Control` root carries the `TacticalBoardPresenter` script + its full-rect anchors) instead of `TacticalBoardPresenter.new()`. The `.tscn` is now the SINGLE SOURCE of the board surface (no longer dead as a nav target); the instanced root exposes the same `bind_live_state`/`render` seam the shell drives. The scene-load compile guardrail (`test_run_flow_scenes_load.gd`) keeps covering the `.tscn`. Presentation-only wiring — no domain/VM/fingerprint change. Full suite green.
- [x] [Review][Decision] **L2 (Low) — `gameplay_shell.tscn` is a `Node2D` hosting a `Control` board presenter as a child.** The shell `extends Node2D` and adds a `Control` (`TacticalBoardPresenter`, itself building `Panel`/`Label` children) directly under it (`gameplay_shell_presenter.gd:1,37-40`). `Control` nodes do not participate in layout / anchor resolution under a bare `Node2D` parent (no `Control`/`CanvasLayer` ancestor to size against). Unverifiable by the scene-free harness, but a real UI-layout risk when the shell is actually rendered on device. Human call (out of the testable surface; flag for the first on-device smoke).
  - **RESOLVED (Round 1, 2026-07-05) — human direction: re-root the shell to a Control.** `gameplay_shell.tscn`'s root is now a `Control` (full-rect: `layout_mode = 3`, `anchors_preset = 15`, `anchor_right/bottom = 1.0`, `grow_horizontal/vertical = 2`) and `gameplay_shell_presenter.gd` now `extends Control` (no `Node2D`-specific transform/position API was used, so the change is transparent). The board `Control` (instanced per L1) now resolves its full-rect anchors against a real `Control` ancestor on device, giving proper layout/anchor resolution. `main.tscn` instances the shell under a plain `Node` root, so a full-rect `Control` sizes to the viewport as intended. Presentation-only re-root — no domain/VM/fingerprint change; the scene-load compile guardrail still passes. Full suite green.
- [x] [Review][Decision] **L3 (Low) — on-screen live nodes are AUTO-RESOLVED by the shell, so the human tap-loop is wired but not the actual on-screen driver.** The board presenter exposes the interactive seam (`submit_move` / `tap_attack` two-step commit / `inspect_cell` — the EXISTING Epic-2/6 contracts, correctly wired), but the shell drives each node via `resolve_combat_node_live` / `auto_play_boss_fight` with the driver HP (`gameplay_shell_presenter.gd:57,71,89`), i.e. it auto-plays the fight rather than awaiting taps. The story documents this as the headless testability stand-in for the tap loop, and it is consistent with "verified by construction," but AC2's interactive commit and the story's stated "a human plays it on screen" bar are only PARTIALLY met — the board is shown, the fight is not actually played by the human. Human call: accept as the 11.3 scope line (the tap-driven live loop as a follow-up) or require the shell to hand control to the tap loop for combat nodes. Related to but distinct from H1 (H1 is the concrete first-node-skip defect; L3 is the broader interactive-vs-auto scope question).
  - **RESOLVED (Round 1, 2026-07-05) — human direction: accept auto-resolve as the 11.3 scope line (no code change).** Auto-resolve stands as 11.3's scope boundary: the interactive tap seam is wired and correct, and driving it from real taps (a human PLAYS the fight rather than watching it auto-resolve) is an explicit FOLLOW-UP, not a 11.3 deliverable. Recorded as a deferred-work entry under the existing `## Deferred from: code review of 11-3-...` heading in `_bmad-output/implementation-artifacts/deferred-work.md`: **"hand on-screen combat control to the wired tap-loop (human-played live nodes)"** — noted to pair naturally with 11.4's live board treatment (the live board becomes the interactive on-screen surface once affinity effects/board treatments land on it). No code change for this item; distinct from the already-patched H1 first-node-skip defect.

No `[Review][Defer]` findings — the still-open items (11.4 affinity, 11.5 outpost render/G3, 11.6 meta-spend, the later in-node save, G4) are the story's already-acknowledged scope splits, correctly re-recorded in `deferred-work.md` by Task 7 (not new deferrals from this review).

**Round 2 of 3** — code review (auto-gds Round-2 adversarial re-review, independent model @ full reasoning depth, 2026-07-06). Verdict: **Changes Requested** (one new Medium patch; all Round-1 resolutions verified in place). Scope: the branch diff vs `main` (28 files, +2626/-9 under `godot/`) with this story as the spec; calibrated to the testability-reality note (scene surface not SceneTree-unit-testable — no SceneTree tests demanded; logic verified in the RefCounted seams). Independently re-verified the gate: full headless suite **175 PASS / 0 `^FAIL` / 0 SCRIPT ERROR** ("Headless tests passed."), false-PASS grep clean beyond exactly the 6 documented negatives (int64-overflow ×2, `invalid_node_type` ×1, malformed-JSON/"Parse JSON failed" ×3); `git diff --check` clean; and the durable-invariant SOURCE files (`domain_event.gd`, `run_snapshot.gd`, `rng_stream_set.gd`, `profile_snapshot.gd`, `settings_snapshot.gd`, every `tools/dump_*`, and the whole `scripts/core`/`scripts/tactical`/`data` tree) have a PROVABLY EMPTY diff vs `main` — so the 23-key gate, both `SCHEMA_VERSION == 1`s, the 7 RNG streams, the `DomainEvent.Type` enum tail, and every seed fingerprint cannot have moved (the corresponding regression tests also pass). Every load-bearing method/const/pinned-key the new code binds to was re-checked against as-built source (`TacticalBoardViewModel.from_domain` 3-arg, `RouteState.node_count()`/`eligible_choice_ids()`, `InventoryState.size()`/`.capacity`, `RunOrchestrator.advance_to`/`start_from`/`resolve_combat_node_live`/`boss_encounter_pending`/`auto_play_boss_fight`, `SaveManager.resume_route_position()` default-arg, `RouteNode.TYPE_*`, the `RunState` properties) — all resolve EXCEPT the one below.

**Round-1 resolution verification (all confirmed in place):**
- **H1 — VERIFIED.** `RunFlowController.current_node_needs_board()` is a pure fail-closed seam over `LIVE_BOARD_NODE_TYPES = [combat, elite_combat]` (boss terminus excluded, consulted via `boss_encounter_pending()` first); `route_map_presenter._render_map` consults it AFTER the boss/terminal checks and BEFORE offering `eligible_choice_ids()`, routing an unresolved current node to the `tactical_board` stage. The regression test `_current_node_needs_board_gates_the_depth_0_opener` proves the depth-0 combat opener is FLAGGED for the board on a fresh finale-seed run and is cleared ONLY by a live `resolve_combat_node_live` → `live_combat_victory` (NodeExitCommand), never silently sealed by an advance; plus a fail-closed off-a-run case. Traced the resolve-then-advance ordering end-to-end (map→board→victory→back-to-map with the node now cleared and the seam cleared) — correct. The recommitted-from-disk (775dda8) work is complete: the seam, the presenter consult, and the test are all present and the suite is green.
- **M1 — VERIFIED.** `gameplay_shell_presenter._drive_current_stage` boss-terminus branch now checks `boss.is_error()`, logs `gameplay_shell_boss_fight_failed` (with `error_code`) via `Diagnostics`, and routes to a recoverable dead-end (`_route_to_dead_end` → `run_end` stage directly, since a non-terminal run makes `route_after_run_end("")` a no-op). The `run_end_presenter` handles the non-ended run ("No completed run." + a "Return to the Outpost" affordance). No silent soft-lock; mirrors the already-tested combat-branch error handling.
- **L1 — VERIFIED.** `gameplay_shell_presenter._build_board_presenter` instances `scenes/game/tactical_board.tscn` (`TacticalBoardScene.instantiate() as Control`); the `.tscn` root is a full-rect `Control` carrying `TacticalBoardPresenter`. The scene is the single source of the board surface and is covered by the scene-load guardrail.
- **L2 — VERIFIED.** `scenes/game/tactical_board.tscn` and `scenes/game/gameplay_shell.tscn` roots are both `type="Control"` with `layout_mode = 3` / `anchors_preset = 15` / `anchor_right = anchor_bottom = 1.0` / `grow_* = 2`; `gameplay_shell_presenter` `extends Control`. The board Control now resolves its full-rect anchors against a real Control ancestor.
- **L3 — VERIFIED (accepted, no code change).** The shell auto-resolves live nodes (`resolve_combat_node_live` / `auto_play_boss_fight`) while the tap seam (`submit_move`/`tap_attack`/`inspect_cell`) is wired; the tap-loop handoff is deferred and recorded in `deferred-work.md`. Confirmed the deferral is present and paired with 11.4.

- [x] [Review][Patch] **M2 (Med) — the in-run HUD text scale is hardcoded to `1.0`; `SettingsSnapshot.text_scale` never reaches the run-flow HUD (AC4 "text respects the `TacticalTextScale` clamp driven by `SettingsSnapshot.text_scale`" is not met on device).** `gameplay_shell_presenter._text_scale()` (`gameplay_shell_presenter.gd:160-165`) probes `SettingsManager.has_method("current_text_scale")` and calls `settings.current_text_scale()` — but **no `current_text_scale` method exists anywhere in the codebase** (the ONLY reference is this presenter's own probe; grep-confirmed). `SettingsManager` exposes `current() -> SettingsSnapshot` (`settings_manager.gd:31`) and `SettingsSnapshot.text_scale` is the real field (`settings_snapshot.gd:52`, a clamped float). So the guard is permanently false and `_text_scale()` ALWAYS returns the hardcoded `1.0`, which the shell threads into every `bind_live_state(...)` call → the board/HUD text scale ignores the player's saved `text_scale` preference on the run-flow HUD. This is precisely the wrong-method-name class the story's Dev Notes flag as "the primary review-cycle cause." It is NON-blocking-critical (fail-safe fallback to a valid default; no crash/soft-lock; the rule-invariance half of AC4 is proven; the value-plumbing INTO the VM via `TacticalTextScale.from_value(_text_scale)` is correct — only the SOURCE read is dead), but it silently defeats a named AC4 / NFR8 (scalable text) clause on device. Note: the `deferred-work.md` 11.3 dev entry's G4 line asserting "the `tactical_board_presenter` reads `SettingsSnapshot.text_scale` via a guarded `SettingsManager` method" is inaccurate on both counts (it is the `gameplay_shell_presenter`, and the guarded method does not exist so nothing is read). **Fix (unambiguous, one line):** replace the dead probe with `return TacticalTextScale.from_value(SettingsManager.current().text_scale).scale` (or read `SettingsManager.current().text_scale` and let the existing `TacticalTextScale.from_value(...)` clamp it), keeping the `has_node("/root/SettingsManager")` guard + the `1.0` fallback. Verified by construction (the corrected call binds to `SettingsManager.current()` / `SettingsSnapshot.text_scale`, both as-built); optionally add a scene-free unit assertion that `TacticalTextScale.from_value(SettingsSnapshot.defaults().text_scale)` clamps as expected (the source read itself is a `Control` concern).
  - **RESOLVED (Round 2, 2026-07-06).** Replaced the dead `has_method("current_text_scale")` probe in `gameplay_shell_presenter._text_scale()` with a real read of `SettingsManager.current().text_scale` (the as-built `SettingsManager.current() -> SettingsSnapshot` + `SettingsSnapshot.text_scale` clamped float), routed through the canonical `TacticalTextScale.from_value(...).to_dictionary().get("scale", 1.0)` clamp seam — the SAME seam `settings_snapshot._sanitize_text_scale` uses (the reviewer's literal `.scale` accessor does NOT exist as a public property on `TacticalTextScale`; every codebase call site reads the clamped value via `to_dictionary().get("scale")`, so this is the compile-correct equivalent of the reviewer's intent). Added the `TacticalTextScale` preload to the presenter. Kept the `has_node("/root/SettingsManager")` guard (+ a null-snapshot guard) and the `1.0` fallback. The saved `SettingsSnapshot.text_scale` now threads through every `bind_live_state(...)` into the board/HUD, meeting the AC4/NFR8 scalable-text clause on device. Corrected the inaccurate `deferred-work.md` G4 line (now names `gameplay_shell_presenter._text_scale()` reading via `SettingsManager.current()`, not a non-existent guarded method on `tactical_board_presenter`). Added a scene-free regression guard to `test_run_flow_layout_invariance.gd` (`_settings_text_scale_reaches_the_hud_clamp`): the default `SettingsSnapshot.text_scale` resolves 1.0 through the clamp seam, a SAVED 1.5 is DELIVERED (not collapsed to 1.0 — the exact M2 defect), and an out-of-range value clamps to MAX — so a re-deadened source read would fail the "saved scale delivered" assertion. The presenter method itself is a `Control` surface (verified by construction per the testability-reality note). Full headless suite green (175 PASS / 0 `^FAIL` / 0 SCRIPT ERROR — the guard is a new method inside the existing `test_run_flow_layout_invariance.gd`, so the file count is unchanged); false-PASS grep clean beyond the 6 documented negatives; `git diff --check` clean.
- [ ] [Review][Defer] **L4 (Low, → the existing L3 tap-loop follow-up) — the shell never renders the LIVE board on a combat node; the in-run board is only ever shown empty.** `resolve_combat_node_live` returns terminal-only metadata: on VICTORY (`run_orchestrator.gd:1012-1021`) and on DEFEAT (`:993-1004`) the metadata carries `resolution`/`outcome`/`rounds`/`level_seed`/… but NO `"board"` key. Yet `gameplay_shell_presenter._drive_current_stage` reads `var live_board = resolved.metadata.get("board")` then `if live_board is BoardState: _render_live_board(...)` (`gameplay_shell_presenter.gd:95-97`) — so `get("board")` is always `null`, `_render_live_board` is NEVER reached for a combat node, and only `_render_between_levels(run)` (a NULL board → the empty-board VM) ever renders. The board VM's `from_domain(null)` empty-board path is correct-by-design (no crash), so the in-run "board hosts a generated level" surface is effectively blank on the on-screen combat path today. This is a direct consequence of the L3-accepted AUTO-RESOLVE scope line (the shell auto-plays to a terminal outcome rather than hosting an interactive fight that would hold the live board between taps), so it is NOT a new blocking defect — it becomes actionable exactly when the deferred tap-loop handoff lands (the shell will drive the live board through the tap seam and hold it across taps). Recorded here and copied to `deferred-work.md` under the existing 11-3 review heading, cross-referenced to the L3 "hand on-screen combat control to the wired tap-loop" deferral (same follow-up; pairs with 11.4). No 11.3 code change required. (If a cheap interim render is desired without the tap loop, `resolve_combat_node_live` could surface the terminal `board` in its metadata for the shell to render a static end-of-fight board — but that touches the domain method's return shape and is out of 11.3's presentation scope.)
