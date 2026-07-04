---
baseline_commit: ddf36629e11b1aa14a323fd1a3d9e3593fc9b178
---

# Story 11.1: Run-Flow UX Appendix and Screen Contracts

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a player,
I want the MVP's screens to follow deliberate, readable designs,
so that the run flow communicates tactical and meta information clearly on phone and desktop.

## Story Type & Scope Boundary (READ FIRST)

**This is a DOCUMENTATION / UX-DESIGN story, not a code story.** The single deliverable is a
**lightweight UX appendix (a markdown document)** authored under `_bmad-output/planning-artifacts/`.

- **No production Godot code, no `.tscn` scenes, no `.gd` scripts, no tests, no save schema, no RNG,
  no content changes.** The headless suite (166 PASS at Epic-9 close) is untouched by this story.
- **No new domain surfaces.** The appendix MAPS each screen to the EXISTING view-model /
  command-bridge contracts. It MUST NOT invent view models, DTOs, commands, events, or fields. Where
  a screen needs something the contracts do not yet expose, the appendix records that as an EXPLICIT
  "contract gap → owning story" note (see AC2) — it does not silently expand scope by "designing in" a
  new surface.
- **Prerequisite discharge.** This appendix is the "lightweight UX appendix" the implementation-readiness
  report flagged as MANDATORY before UI-heavy scene work (see References), and it is the input Story 10.7
  AC5 (UX readiness gate) consumes. It unblocks the scene-building stories 11.3 (run-flow scenes + HUD)
  and 11.5 (outpost scene + reveal renders).
- **The appendix is a specification the LATER stories implement.** 11.1 designs the screens on paper;
  11.2/11.3/11.4/11.5/11.6 build them. Keep the appendix authoritative-but-lightweight: screen intent,
  regions, states, the exact contract each region binds to, layout coverage, and accessibility rules —
  NOT pixel comps, not final art, not a component library.

## Acceptance Criteria

Sourced verbatim from `epics.md` (Epic 11, Story 11.1). Three AC groups (Given/When/Then + And):

1. **Screen coverage (AC1).** GIVEN UI-heavy scene implementation is about to begin, WHEN the
   lightweight UX appendix is authored under planning artifacts, THEN it covers **tactical HUD,
   preview/confirm states, inspect panel, passive modal, run map, outpost/meta menu, run summary,
   settings, and save/resume recovery states**, AND it additionally covers the **first-death and
   first-victory reveal moments** with their **skip/dismiss affordances** and the **manual-seed
   no-progression warning surface**.

2. **Contract mapping (AC2).** GIVEN the appendix is authored, WHEN each screen section is reviewed,
   THEN it maps to the existing view-model/command-bridge contracts (**tactical view models,
   reward/passive modal contract, `HeroSelectViewModel`, `OutpostViewModel`, `RunSummary`, narrative
   beat DTOs**) **without inventing new domain surfaces**, AND any contract gap it identifies is
   **recorded as an explicit note for the owning story** rather than silently expanded scope.

3. **Layout & accessibility coverage (AC3).** GIVEN the appendix exists, WHEN layout coverage is
   reviewed, THEN **phone portrait, phone landscape, tablet, and desktop-style layouts** are addressed
   for each screen (FR66), AND **critical information avoids color-only meaning and supports scalable
   text** (NFR8, NFR9).

### AC Verification (how "done" is checked — no test suite for a docs story)

- **AC1** — every screen in the roster below has a section in the appendix, PLUS the two reveal beats
  (with skip/dismiss) PLUS the manual-seed no-progression warning surface. Missing any one = AC1 not met.
- **AC2** — every screen section names the exact existing contract(s) it binds to (class + the pinned
  key/method it reads), and every gap is written as a `Contract gap → <owning story>` note. A screen that
  references an invented/undefined surface = AC2 not met.
- **AC3** — every screen section addresses all four layout profiles (`phone_portrait`, `phone_landscape`,
  `tablet`, `desktop`) and states its color-independence + scalable-text handling. A screen missing a
  layout or a color-only cue = AC3 not met.

## Tasks / Subtasks

- [x] **Task 1 — Create the appendix file and frame it (AC1, AC2, AC3)**
  - [x] Author `_bmad-output/planning-artifacts/ux-appendix-run-flow.md` (recommended filename; if you
        prefer, `ux-run-flow-appendix.md` — keep it discoverable by the `*ux*.md` glob the create-story /
        readiness workflows use, and reference it from Story 10.7's UX-prerequisite check). — DONE: file
        authored + verified discoverable by the `{planning_artifacts}/*ux*.md` glob. Story 10.7 does NOT yet
        exist as a file (Epic-10 §10.4–10.7 execute AFTER Epic 11 per the 2026-07-04 sprint change), so the
        appendix self-documents the 10.7 AC5 linkage (§0.1); 10.7 cites it when authored.
  - [x] Open with: purpose (the readiness prerequisite it discharges + the 10.7 AC5 input it feeds),
        scope (lightweight — screen intent + regions + states + contract bindings + layout + accessibility;
        NOT pixel comps or final art), and a one-line pointer to `game-architecture.md` (UI observes view
        models through the command bridge; scenes own no tactical truth). — DONE: §0.1–§0.3.
  - [x] State the four target layout profiles up front using the EXISTING stable ids so every screen
        section can reference them: `phone_portrait`, `phone_landscape`, `tablet`, `desktop`
        (`TacticalLayoutProfile.PROFILE_*` — do NOT invent new profile names). — DONE: §0.4.
  - [x] State the accessibility contract up front (color-independence + scalable text) by referencing the
        EXISTING vocabulary: non-color channels `shape`/`icon`/`label`/`pattern`/`text` and severities
        `info`/`warning`/`blocked`/`danger` (`TacticalAccessibilityModel`), and the clamped text-scale bound
        (`TacticalTextScale`). Every screen inherits this; per-screen sections only note deviations/specifics. — DONE: §0.5.

- [x] **Task 2 — Tactical HUD + preview/confirm states + inspect panel sections (AC1, AC2, AC3)**
  - [x] Tactical HUD: bind to `TacticalBoardViewModel.to_dictionary()` (composes `board` + `layout` +
        `accessibility` slots) and the `TacticalLayoutProfile` region plan (`board`, `preview`,
        `confirm_cancel`, `inspect`, `status`, `log_or_outcome`). Document the in-run HUD context 11.3
        needs (HP, node progress, gold, inventory/passives access) — see Contract Gap G1 for HP/node/gold. — DONE: §1 (region→slot map in §1.2; G1 in §1.3).
  - [x] Preview/confirm states: bind to the command bridge intents `move` / `attack` / `inspect`
        (`TacticalCommandBridge`), the two-step attack commit (`TacticalAttackCommitFlow`), and the
        preview view models (`TacticalMovementPreview`, `TacticalAttackPreview`, `TacticalPreviewView`).
        Document the preview-vs-committed distinction cues (`feedback_preview` / `feedback_committed`, each
        with a non-color channel so it survives with audio muted). — DONE: §2 (bridge §2.2; distinction §2.3).
  - [x] Inspect panel: bind to `TacticalInspectView` + the bridge `inspect` intent; cover FR12 fields
        (tile, terrain, occupant, move cost, attack preview, hazard notes, telegraphed danger) and the
        three visibility tiers (`inspect_visible` / `inspect_memory` / `inspect_hidden_unexplored`). — DONE: §3 (FR12 fields + tiers §3.2).

- [x] **Task 3 — Passive modal + run map + hero-select sections (AC1, AC2, AC3)**
  - [x] Passive modal: bind to `PassiveRewardModalViewModel` (pinned `MODAL_KEYS`: `has_passive`,
        `display_name`, `flavor`, `exact_mechanical_effects`, `consume_text`, `destroy_text`,
        `has_unknown_consequences`, `consequences_text`) + the Consume/Destroy two-step commit
        (`PassiveRewardCommitFlow`). Note FR55 (clear upside/downside before acceptance) and that `icon`
        is an id/placeholder string, not art. — DONE: §4 (full MODAL_KEYS + two-step §4.2; icon-as-id §4.2).
  - [x] Run map: bind to the route read surface (`RouteState` / `RouteNode`; node types via
        `RouteNode.TYPE_*`). If no dedicated route VIEW model exists, record it as Contract Gap G2 for the
        owning story (11.3) — do NOT design a new route view model here. — DONE: §5 (RouteState/RouteNode §5.2; G2).
  - [x] Hero select: bind to `HeroSelectViewModel` (pinned `ENTRY_KEYS`: `class_id`, `display_name`,
        `selectable`, `unlock_hint`) + `is_class_selectable()`. Note locked-class grey-out + unlock hint,
        and that the authoritative gate is `RunStartCommand` (a mis-enabled confirm cannot start a locked run). — DONE: §6 (ENTRY_KEYS + is_class_selectable §6.2; RunStartCommand gate §6.2).

- [x] **Task 4 — Outpost/meta menu + run summary + reveal beats + manual-seed warning (AC1, AC2, AC3)**
  - [x] Outpost/meta menu: bind to `OutpostViewModel.to_dictionary()` (pinned `DICTIONARY_KEYS`) — the
        four named spaces (`memory_archive`, `hall_of_oaths`, `seal_table`, `descent_stair`, each marked
        `deferred` in v0), the aggregated meta readout (`oath_shards` read from the PROFILE, `echoes`,
        `unlock_progress`, `class_mastery`, `first_death_recorded`), the embedded `run_summary` /
        `first_death_beat` sub-dicts, and the start-another-descent affordance
        (`start_run_request()` → `is_startable`). Document the recovery surface (see Task 5). — DONE: §7 (DICTIONARY_KEYS + named spaces + start seam §7.2; recovery cross-ref §13).
  - [x] Run summary: bind to `RunSummary.to_dictionary()` (pinned `DICTIONARY_KEYS` + `RUN_SCOPED_KEYS`)
        — cause of death/victory (`outcome_or_cause`), nodes cleared, boss/elite progress, passives
        consumed/destroyed, notable loot, gold/curse/corruption, seed, manual-seed flag. Cover the FR60
        GDD field list. Record the "Oath Shards earned" display as Contract Gap G3 (the summary reports
        `oath_shards_earned == 0` / `not_yet_supported`; the AWARDED total lives on the profile — the
        coupling decision is owned by Story 11.5, NOT designed-resolved here). — DONE: §8 (all pinned sub-dicts §8.2; G3 both options §8.3).
  - [x] First-death reveal moment: bind to `FirstDeathNarrativeBeat` (`has_beat`, `line`, `is_skippable`)
        — line "Good. You remembered how to die." (FR61). Document the skip/dismiss affordance as a PURE
        presentation no-op (dismiss mutates nothing; the flag is set independently by
        `RecordFirstDeathCommand`) and that it is OFF the critical path (never blocks the outpost/another
        descent) (FR64, FR65). — DONE: §9 (line verbatim + pure-no-op §9.3 + off-critical-path §9.3).
  - [x] First-victory reveal moment: bind to `FirstVictoryRevealBeat` (`has_beat`, `line`, `is_skippable`)
        — line "It did not die. It learned the way back." (FR62). Same skip/dismiss no-op + off-critical-path
        posture, opposite terminal phase. — DONE: §10 (line verbatim + §10.3 twin posture).
  - [x] Manual-seed no-progression warning surface: bind to the eligibility flags already on the read
        surfaces (`RunSummary.is_manual_seed` / `meta_progression_eligible`;
        `OutpostViewModel.start_run_request().is_manual_seed`). Document WHERE the warning renders (run
        summary + outpost) and that it is a READOUT of existing flags — no new field (FR28). — DONE: §11 (flags + render locations + no-new-field §11.2).

- [x] **Task 5 — Settings + save/resume recovery states sections (AC1, AC2, AC3)**
  - [x] Settings screen: bind to `SettingsSnapshot` / `SettingsManager` / `SettingsApplyService` /
        `SettingsRepository`. There is NO dedicated settings VIEW model — record that as Contract Gap G4
        for the owning story (the settings scene reads the snapshot directly, or a thin projection is
        added by the owning story). Include the ratified difficulty NON-GOAL guardrail: NO selectable
        difficulty ladder appears in MVP (negative readiness criterion) — settings must not present one. — DONE: §12 (PREFERENCE_KEYS + G4 §12.2; difficulty non-goal §12.3).
  - [x] Save/resume recovery states: cover the between-level resume flow surfaces and the structured
        recovery states the screens must render — the run save/resume path (`SaveManager` route delegators
        → `RunResumeService`; structured `ActionResult` codes: `save_not_found`, `save_parse_failed`,
        `unsupported_save_schema`, `invalid_tactical_snapshot`, `invalid_rng_snapshot`) AND the profile
        recovery surface on the outpost (`OutpostViewModel.recovery_state` {`has_recovery`, `code`,
        `is_recoverable`} + the loaded-profile-behind-retry-banner vs fresh-profile-fallback distinction).
        Note NFR13 (resumed outcomes match uninterrupted play) as the invariant these screens must respect. — DONE: §13 (SaveManager→RunResumeService codes §13.2; both profile-recovery modes §13.2; NFR13 §13.4).

- [x] **Task 6 — Layout + accessibility coverage pass across ALL screens (AC3)**
  - [x] For EACH screen section, add the four-layout treatment: `phone_portrait` (primary), `phone_landscape`
        (side-rail per `TacticalLayoutProfile._build_side_rail_layout`), `tablet`, `desktop` (comfortable
        density; wider panels). Emphasize the board stays the dominant/readable region and primary actions
        stay reachable (min touch target 44×44) on the compact profiles (FR66, NFR7). — DONE: §14.1 global pass + each screen's layout subsection.
  - [x] For EACH screen section, state the color-independence handling (every critical meaning carries a
        non-color channel from the `TacticalAccessibilityModel` vocabulary) and scalable-text handling
        (respects the `TacticalTextScale` clamp; labels+icons where needed) (NFR8, NFR9). — DONE: §14.2 global pass (per-screen cue table) + each screen's accessibility subsection.
  - [x] Cross-check the affinity/inspect visual cues against the APPROVED affinity treatments already in the
        repo (`godot/assets/tiles/affinities/affinity.{scorched,flooded,cursed,darkness}.png`) and the
        Recraft UI-frame kit (button/panel/modal) — the appendix references these as the visual treatment
        baseline for 11.4; it does NOT author new art. — DONE: §14.3 (all four affinity PNGs verified present in repo; Recraft frame kit; §15 affinity read).

- [x] **Task 7 — Contract-gap ledger + owning-story handoff (AC2)**
  - [x] Consolidate every `Contract gap → <owning story>` note into a single "Contract Gaps" section at
        the end of the appendix (G1..Gn), each naming the gap, the screen(s) affected, and the owning
        Epic-11 story. This is the AC2 deliverable that keeps scope explicit (see the seed list G1–G4 in
        Dev Notes; add any further gaps you find during authoring). — DONE: §16 ledger (G1–G4); no further gaps found (§16 note); non-gaps recorded §16.1.
  - [x] Do NOT resolve the gaps in this story. Recording them IS the work; the owning stories implement them. — DONE: §16 records only; resolves none.

## Dev Notes

### What this story is (and is not)

The prior work (Epics 1–9) shipped a complete, headless, deterministic domain + a full set of
scene-free **view-model / read-surface / command-bridge contracts** — but ZERO gameplay scenes beyond
`boot.tscn` / `main.tscn` / `gameplay_shell.tscn` / `tactical_board.tscn`. Epic 11 wires the live layer
on top of those contracts. **Story 11.1 is the paper design that precedes the scene work** — it is the
"lightweight UX appendix" the readiness report made mandatory before UI-heavy scenes, and it is Story
10.7 AC5's input. Author it as a markdown document under `planning-artifacts/`; touch no code.

The single most important rule: **map to the EXISTING contracts; never invent domain surfaces.** Every
screen already has a scene-free contract to bind to (enumerated below with pinned keys). Where a screen
needs data the contracts don't expose, write a `Contract gap → owning story` note (AC2) — do not design a
new view model, DTO, command, event, or field into the appendix.

### The screen roster (AC1) and its exact contract bindings (AC2)

Read the actual source before writing each section — the pinned key sets are load-bearing (a section
that cites a wrong/absent key is an AC2 miss). Absolute paths:

| Screen (AC1) | Binds to (existing contract) | Path | Load-bearing detail |
|---|---|---|---|
| Tactical HUD | `TacticalBoardViewModel` (composes `board`/`layout`/`accessibility`) + `TacticalLayoutProfile` regions | `godot/scripts/ui/view_models/tactical_board_view_model.gd`, `.../tactical_layout_profile.gd` | Regions: `board`, `preview`, `confirm_cancel`, `inspect`, `status`, `log_or_outcome`. HP/node/gold = Gap G1. |
| Preview/confirm states | command bridge `move`/`attack`/`inspect` + `TacticalAttackCommitFlow` + preview VMs | `.../command_bridge/tactical_command_bridge.gd`, `.../view_models/tactical_attack_commit_flow.gd`, `.../tactical_attack_preview.gd`, `.../tactical_movement_preview.gd` | Two-step commit; `feedback_preview`/`feedback_committed` cues each carry a non-color channel. |
| Inspect panel | `TacticalInspectView` + bridge `inspect` | `.../view_models/tactical_inspect_view.gd` | FR12 fields; tiers `inspect_visible`/`inspect_memory`/`inspect_hidden_unexplored`. |
| Passive modal | `PassiveRewardModalViewModel` + `PassiveRewardCommitFlow` | `.../view_models/passive_reward_modal_view_model.gd`, `.../passive_reward_commit_flow.gd` | `MODAL_KEYS` pinned; `icon` is an id string, not art; FR55 upside/downside. |
| Run map | `RouteState` / `RouteNode` (no route VM today) | `godot/scripts/run/route_state.gd`, `.../route_node.gd` | Node types `RouteNode.TYPE_*`. No route VM = Gap G2. |
| Hero select | `HeroSelectViewModel` | `.../view_models/hero_select_view_model.gd` | `ENTRY_KEYS` pinned; locked grey-out + `unlock_hint`; authoritative gate is `RunStartCommand`. |
| Outpost/meta menu | `OutpostViewModel` | `.../view_models/outpost_view_model.gd` | `DICTIONARY_KEYS` pinned; 4 named spaces all `deferred`; `oath_shards` read from PROFILE; `start_run_request()`→`is_startable`; `recovery_state`. |
| Run summary | `RunSummary` | `godot/scripts/run/run_summary.gd` | `DICTIONARY_KEYS`+`RUN_SCOPED_KEYS` pinned; FR60 fields; `oath_shards_earned==0`/`not_yet_supported` = Gap G3. |
| Settings | `SettingsSnapshot` / `SettingsManager` / `SettingsApplyService` | `godot/scripts/settings/settings_snapshot.gd`, `godot/scripts/autoloads/settings_manager.gd` | No settings VM = Gap G4; NO selectable difficulty ladder (negative criterion). |
| Save/resume recovery | `SaveManager`→`RunResumeService` + `OutpostViewModel.recovery_state` | `godot/scripts/autoloads/save_manager.gd` (route delegators), outpost VM | Structured `ActionResult` codes; profile retry-banner vs fresh-fallback; NFR13. |
| First-death reveal | `FirstDeathNarrativeBeat` | `godot/scripts/run/first_death_narrative_beat.gd` | `has_beat`/`line`/`is_skippable`; "Good. You remembered how to die." (FR61); skip = pure no-op; off critical path. |
| First-victory reveal | `FirstVictoryRevealBeat` | `godot/scripts/run/first_victory_reveal_beat.gd` | `has_beat`/`line`/`is_skippable`; "It did not die. It learned the way back." (FR62); skip = pure no-op; off critical path. |
| Manual-seed warning | eligibility flags on `RunSummary` / `OutpostViewModel` | (as above) | `is_manual_seed` / `meta_progression_eligible`; readout of existing flags only (FR28). No new field. |
| Affinity read (supports HUD/inspect, feeds 11.4) | `AffinityViewModel` + `DarknessReadView` | `.../view_models/affinity_view_model.gd`, `.../darkness_read_view.gd` | `MODAL_KEYS` pinned; `tactical_rules` are RECORD-ONLY descriptive data; approved treatments already in repo. |

The GDD's own UI-frame list (`gdd.md` line 599) is essentially this roster: "hero select, tactical HUD,
tile/attack preview, passive modal, run map, outpost/meta menu, run summary, settings, and save/resume."
FR68 (`epics.md` line 158) enumerates the same set. Use them as the completeness cross-check for AC1.

### Layout coverage (AC3, FR66, NFR7)

`TacticalLayoutProfile` (`.../view_models/tactical_layout_profile.gd`) already defines EXACTLY the four
target profiles with stable ids — reuse them, do not invent names:
- `PROFILE_PHONE_PORTRAIT` = `"phone_portrait"` (primary mobile mode; stacked layout, board dominant on top).
- `PROFILE_PHONE_LANDSCAPE` = `"phone_landscape"` (side-rail layout: board left, controls in a right rail).
- `PROFILE_TABLET` = `"tablet"` (comfortable density, stacked + optional `log_or_outcome` strip).
- `PROFILE_DESKTOP` = `"desktop"` (comfortable density, wider panels, mouse/keyboard parity).

Region vocabulary (per profile) is fixed: `board`, `preview`, `confirm_cancel`, `inspect`, `status`,
`log_or_outcome`. Min touch target is 44×44 (`DEFAULT_MINIMUM_TOUCH_TARGET`). The GDD platform rules
(`gdd.md` 558–575): portrait is the main phone mode; landscape is the same tactical experience with more
space (NOT a separate mode); the board stays readable and uncluttered; orientation changes never alter
rules. The appendix must address all four profiles for EVERY screen (not just the tactical HUD).

### Accessibility coverage (AC3, NFR8, NFR9)

`TacticalAccessibilityModel` (`.../view_models/tactical_accessibility_model.gd`) is the codified
color-independence contract — reuse its vocabulary:
- Non-color channels: `shape`, `icon`, `label`, `pattern`, `text`. **Every critical meaning must carry at
  least one** (color is additive only, never the sole signal).
- Severities: `info`, `warning`, `blocked`, `danger` (a presenter MAY map severity→color, but additively).
- Scalable text: `TacticalTextScale` clamps a requested scale (`.../view_models/tactical_text_scale.gd`).
The GDD accessibility baseline (`gdd.md` 576–583): scalable text; colorblind-safe danger; icons + labels
where needed; no reflex/timing; skippable narrative; all critical tactical info available without color.

### Reveal beats + skip/dismiss + manual-seed warning (AC1)

- Both beat DTOs (`FirstDeathNarrativeBeat`, `FirstVictoryRevealBeat`) are PURE reads: `has_beat` gates a
  present beat; `is_skippable` is true for a present v0 beat; the display `line` is resolved by-id. **A
  skip/dismiss is STRUCTURALLY a pure presentation no-op** — the narrative FLAG is set by a separate
  command (`RecordFirstDeathCommand` / `RecordFirstVictoryCommand`), so dismissing renders nothing further
  and mutates nothing (FR65). The beat is OFF the critical path: a null/absent/dismissed beat NEVER blocks
  the run summary, the outpost surface, or starting another descent (FR64). Document these as the
  appendix's skip/dismiss affordance spec, not as behavior to change.
- Manual-seed no-progression warning: the eligibility is already carried as flags
  (`RunSummary.is_manual_seed` / `.meta_progression_eligible`; `OutpostViewModel.start_run_request()
  .is_manual_seed`). The warning is a READOUT surface (render on run summary + outpost). No new field —
  the appendix specifies where/how it renders (FR28).

### Contract-gap seed list (AC2) — record these; the owning stories resolve them

These are gaps ALREADY known from the codebase + the deferred-work ledger. The appendix must record them
as explicit owning-story notes (add any further gaps you find while authoring):

- **G1 — In-run HUD run context (HP, node progress, gold, inventory/passives access).** The tactical HUD
  needs run-level context (hero HP, node progress along the route, gold, inventory/passive access) that is
  NOT on `TacticalBoardViewModel` (which is board+layout+accessibility only). Story 11.3 AC2 requires the
  HUD present this "per the 11.1 appendix." Record the gap and the fields needed; do not design the surface.
  Owning story: **11.3**.
- **G2 — Route/run-map view model.** No dedicated route VIEW model exists; the run map reads `RouteState`/
  `RouteNode` directly today. Record the gap (a thin route projection may be added by the owning story).
  Owning story: **11.3**.
- **G3 — "Oath Shards earned" summary↔profile coupling.** `RunSummary.profile_meta.oath_shards_earned`
  stays `0` / `not_yet_supported`; the AWARDED total lives on `profile.oath_shards` and is surfaced via
  `OutpostViewModel.oath_shards`. The coupling decision (display the awarded total on the summary vs surface
  it via the outpost) is a deliberate deferral carried Epic-8 T5 / Epic-9 T4 and is owned by Story 11.5
  AC4 — the appendix DOCUMENTS both display options and flags the decision, it does NOT resolve it.
  Owning story: **11.5**.
- **G4 — Settings view model.** No settings VIEW model exists; the settings scene reads `SettingsSnapshot`
  directly. Record the gap (the owning story reads the snapshot or adds a thin projection). Owning story:
  the settings-scene owner (11.3 or 11.5 per the eventual scene split).

### Previous-story intelligence & Epic-9 forward prep (folded in)

- **This is the FIRST story of Epic 11** (inserted 2026-07-04 ahead of Epic 10 via
  `sprint-change-proposal-2026-07-04.md`; commit `3b699ee`). Epic 9 is the epic that closed immediately
  before it, so Epic 9's retro forward-prep applies to Epic 11 (the retro's "Epic 10 preparation" wording
  predates the insertion — re-map it to Epic 11). Relevant carried items now landing in Epic 11:
  - The "run-flow/HUD + outpost-scene story" the Epic-9 retro named the single largest deferred body IS
    Epic 11. 11.1 (this story) is its lead-off UX-appendix step; the felt-on-screen work is 11.2–11.6.
  - Epic-9 retro Action **P2 — atomic finalize step** is in force from 11.1 onward: at finalize, the story
    `Status:`, the `sprint-status.yaml` `development_status` entry, and any ledger/tracking commits move to
    `done` as ONE unit with the merge (a merged PR with a `review` status must be impossible). *(Finalize is
    the orchestrator's job, not the dev agent's — flagged so it is not dropped for the FIFTH-running-plus
    capstone-lag reason.)*
  - The Epic-9 retro's "built-and-proven-but-not-yet-felt-on-screen" body (affinities, meta, finale) is
    exactly what Epic 11 makes felt. 11.1 is paper-only, so it does not touch that code — but the appendix
    it produces is the design the later stories build against, so keep its contract bindings faithful to the
    as-built read surfaces (they are complete and stable per the retro's readiness table).
- **No fail-loud gate/table extension applies to THIS story.** The Epic-9 retro heads-up about "a gate/check
  will fail-loud on the new table → that is expected, register/extend it" concerns CODE stories that add
  events / content families / save keys (11.2 territory). 11.1 adds none of that — no exhaustiveness gate,
  no `expected_ids` pin, no schema key, no fingerprint is touched. Note this so the dev agent does not go
  looking for a table to extend.

### Deferred-work overlaps folded in (only entries touching this story's surface)

From `_bmad-output/implementation-artifacts/deferred-work.md` — the ledger is project-wide; only these
overlap the screens this appendix specifies. They are folded in above as gaps/notes; do NOT reopen or
re-defer unrelated items:
- **The Oath-Shard EARNED-count summary wiring** (deferred-work lines ~56/74/194) → Gap **G3** (owned by 11.5).
- **The first-victory reveal RENDER on the outpost + first-death beat render** (lines ~25/98/146) → the
  reveal-beat screen sections (owned by 11.5 for the render; 11.1 specs the skip/dismiss + off-critical-path
  design).
- **The `OutpostViewModel` navigation / outpost `.tscn` + start-another-descent wiring** (line ~521) → the
  outpost/meta-menu section (owned by 11.5). The DATA contract exists; the appendix designs the screen the
  navigation lands on.
- **The polished HUD `Control`/scene under `godot/scenes/ui/layouts/<profile>/`** (lines ~995–1003) was left
  "for a later story that grows the polished HUD" — that later story is Epic 11 (11.3). The appendix's
  per-profile HUD layout is the design input for it. The semantic `TacticalLayoutProfile` is the testable
  source of truth the scenes must honor (do not re-derive layout in scenes).

### Project Structure Notes

- **Output location:** `_bmad-output/planning-artifacts/ux-appendix-run-flow.md` (a planning artifact, NOT
  under `godot/`). It is a design document; it is not code and not a story file. Keep it lightweight.
- **Naming:** use a `*ux*.md` filename so the create-story / readiness discovery globs (`{planning_artifacts}
  /*ux*.md`) find it, and so Story 10.7's UX-prerequisite check can cite it.
- **No production code paths are touched.** Do NOT create anything under `godot/scripts/`, `godot/scenes/`,
  or `godot/tests/`. The scene files (`scenes/ui/`, `scenes/game/`) are the LATER stories' deliverables.
- **Do not modify** `prototype/` (frozen validation evidence), `_bmad/` (installer-managed), or the
  existing view-model/DTO source (this story reads them, does not change them).

### Project Context Rules

Extracted from `project-context.md` (the canonical rulebook — refreshed after Epic 9). The rules that bear
on THIS story:

- **UI-scene-last, domain-first.** "Godot scenes, `Control` nodes, audio, VFX, and animation are
  presentation. They must not own authoritative tactical state." "Presentation observes domain state/events
  and submits commands through a command bridge." Every view model this appendix maps to is explicitly a
  RefCounted DTO that is "NOT a Control, NOT a Node, NOT a .tscn." The appendix must preserve that boundary:
  screens read view models / submit intents through the command bridge; they own no tactical truth.
- **Exact-key projection discipline.** Every read surface pins an exact key set (`DICTIONARY_KEYS` /
  `MODAL_KEYS` / `ENTRY_KEYS` / `RUN_SCOPED_KEYS`) — "a key never silently appears/vanishes." The appendix
  binds screens to these pinned keys; it must not assume a key that isn't in the set (that would be an AC2
  invented-surface violation).
- **Fail-closed reads.** Read surfaces project a fail-closed empty fact (`has_summary` / `has_beat` /
  `has_affinity` / `has_profile` false) rather than crash. The appendix should specify the empty/absent
  presentation state for each screen (e.g. a fresh outpost with no just-ended run; an absent reveal beat).
- **No new autoload / no new domain surface.** Epics 8–9 added NO new autoload and drove the outpost/boss
  data as caller-driven read surfaces. 11.1 adds nothing at all (docs only) — reinforce that the appendix
  is a spec, and the surfaces it names already exist.
- **Difficulty non-goal (settings guardrail).** The project ships NO selectable difficulty ladder in MVP.
  The settings section MUST reflect this (a negative readiness criterion the readiness report calls out).
- **Determinism / save invariants are NOT touched by a docs story** — but the appendix should note them as
  constraints the LATER scene stories respect (interrupted==uninterrupted / NFR13; the 23-key `RunSnapshot`
  gate; `ProfileSnapshot.SCHEMA_VERSION == 1`; the 7 named RNG streams; every pinned fingerprint). This
  keeps the design honest about what the scene wiring may not perturb.
- **Godot / testing:** N/A for this story (no code, no test). The full headless suite command remains the
  gate for the CODE stories (11.2+), run via PowerShell (the `godot` binary is not on the Bash PATH). This
  story changes no test outcome.

### References

- **Story source (verbatim ACs):** `_bmad-output/planning-artifacts/epics.md` — Epic 11 §"Story 11.1:
  Run-Flow UX Appendix and Screen Contracts" (lines ~2593–2616). Epic 11 List entry + implementation notes:
  lines ~489–495. Epic 11 section header: lines ~2587–2591.
- **Sprint change (Epic 11 insertion + numbering rationale + 11.1 prerequisite framing):**
  `_bmad-output/planning-artifacts/sprint-change-proposal-2026-07-04.md` (§4.6 Story 11.1;
  §1 item 8 "the lightweight UX appendix required before UI-heavy scene work").
- **Readiness patch note (the MANDATORY UX-appendix prerequisite this story discharges + the 9-screen
  list):** `_bmad-output/planning-artifacts/implementation-readiness-report-2026-06-04.md` lines 746–747
  ("Before implementing polished tactical scenes, create at least lightweight UX artifacts for tactical
  HUD, preview/confirm states, inspect panel, passive modal, run map, outpost/meta, run summary, settings,
  and save/resume recovery."), 919, 940, 995 (Story 10.7 makes it mandatory before UI-heavy scene production).
- **FR/NFR text (`epics.md` FR/NFR inventory):** FR1 (line 24 — full loop), FR12 (46 — inspect fields),
  FR28 (78 — manual-seed no meta), FR55 (132 — cursed reward upside/downside), FR57 (136 — affinities alter
  choices), FR58 (138 — Darkness uncertainty w/o unavoidable damage), FR61 (144 — first-death line), FR62
  (146 — first-victory reveal), FR64 (150 — optional story), FR65 (152 — skippable narrative), FR66 (154 —
  four layouts), FR68 (158 — the UI-flow roster), NFR7 (178 — readable on phone), NFR8 (180 — scalable
  text), NFR9 (182 — colorblind-safe / no color-only).
- **GDD design grounding:** `_bmad-output/planning-artifacts/gdds/gdd-Game-2026-05-31/gdd.md` — Controls &
  Input (178–190), Permadeath/Run-summary field list = FR60 (300–314), Art Style (516–532), Platform-Specific
  Details + accessibility baseline (558–583), Asset Requirements incl. the UI-frame list (585–601).
- **Existing contract source (READ before writing each section):** all under `godot/scripts/`:
  `ui/view_models/tactical_board_view_model.gd`, `.../tactical_layout_profile.gd`,
  `.../tactical_accessibility_model.gd`, `.../tactical_text_scale.gd`, `.../tactical_inspect_view.gd`,
  `.../tactical_attack_commit_flow.gd`, `.../tactical_attack_preview.gd`, `.../tactical_movement_preview.gd`,
  `.../hero_select_view_model.gd`, `.../passive_reward_modal_view_model.gd`, `.../passive_reward_commit_flow.gd`,
  `.../affinity_view_model.gd`, `.../darkness_read_view.gd`, `.../outpost_view_model.gd`;
  `ui/command_bridge/tactical_command_bridge.gd`; `run/run_summary.gd`, `run/run_end_outcome.gd`,
  `run/first_death_narrative_beat.gd`, `run/first_victory_reveal_beat.gd`, `run/route_state.gd`,
  `run/route_node.gd`; `settings/settings_snapshot.gd`; `autoloads/settings_manager.gd`,
  `autoloads/save_manager.gd`.
- **Approved visual treatments (reference, not authored here):**
  `godot/assets/tiles/affinities/affinity.{scorched,flooded,cursed,darkness}.png` + the Recraft UI-frame
  kit (button/panel/modal) — already merged to `main`.
- **Deferred-work ledger (overlapping entries):**
  `_bmad-output/implementation-artifacts/deferred-work.md` (G3 lines ~56/74/194; reveal render ~25/98/146;
  outpost navigation ~521; polished HUD scene ~995–1003).
- **Epic-9 retro (forward prep — re-mapped to Epic 11):**
  `_bmad-output/implementation-artifacts/epic-9-retro-2026-07-04.md` §7, §8 (Action P2 atomic finalize; T1
  the run-flow/HUD + outpost story = Epic 11), §10.

## Review Findings

**Round 1 of 3**

Adversarial code review (auto-gds delegate, Opus 4.8 [1m], 2026-07-04). This is a DOCUMENTATION / UX-design
story; the deliverable under review is `_bmad-output/planning-artifacts/ux-appendix-run-flow.md` (plus the
story-file + `sprint-status.yaml` bookkeeping). Review dimensions: contract accuracy against the actual
GDScript source (pinned key sets, class/view-model/command-bridge/method names, constant values, verbatim
narrative lines), AC1/AC2/AC3 coverage, internal consistency, and invented-surface errors. No production
`godot/` code, scene, test, save-schema, RNG, or content was touched (verified) — the headless suite is
unaffected.

**Verdict: Approve** — 0 Critical / 0 High / 1 Med / 2 Low. The appendix's contract bindings are accurate:
every pinned key set, method signature, constant, and narrative line spot-checked against source matches
(details below). AC1 (roster + 2 reveal beats + manual-seed warning), AC2 (per-screen pinned-key bindings +
G1–G4 gap ledger, no invented surface), and AC3 (four profiles + color-independence + scalable text) are all
met. The three findings are localized accuracy/navigation fixes to the appendix; none blocks the paper design
or the downstream scene stories.

Contract-accuracy verification performed (all MATCH source unless flagged in a finding): `TacticalBoardViewModel`
top-level projection keys (§1.2); `TacticalLayoutProfile.PROFILE_*` ids + region vocabulary + `DEFAULT_MINIMUM_TOUCH_TARGET
= Vector2(44,44)` (§0.4/§14); `TacticalAccessibilityModel` `CHANNEL_*`/`SEVERITY_*` + the two feedback cues +
`affinity_scorched_hazard`/`affinity_pathing_pressure` + Darkness cues (§0.5/§2.3/§3/§15); `TacticalTextScale`
`[0.85, 2.0]` default `1.0` (§0.5/§12); `TacticalInspectView.from_context` fields + visibility-tier cues (§3.2);
`TacticalCommandBridge.build_command` intents `move`/`attack`/`inspect` + `unsupported_intent` + result kinds
(§2.2); `TacticalAttackCommitFlow.to_dictionary()` state + methods + `MODE_*` (§2.2); `TacticalMovementPreview`/
`TacticalAttackPreview` shapes + cue ids (§2.2); `PassiveRewardModalViewModel.MODAL_KEYS` (10 keys incl.
`passive_id`) + `PassiveRewardCommitFlow.to_dictionary()`/methods (§4.2); `HeroSelectViewModel.ENTRY_KEYS` +
`is_class_selectable` + `ClassRepository.BASELINE_CLASS_IDS` order `warrior/pyromancer/ranger/necromancer/shadeblade`
(§6.2); `OutpostViewModel.DICTIONARY_KEYS` (13) + `RECOVERY_STATE_KEYS` + `NAMED_SPACE_KEYS` + `NAMED_SPACES`
(4 spaces, all `deferred`, `maps_to` values) + `START_REQUEST_KEYS` + both `for_recovery` modes (§7.2/§13.2);
`RunSummary.DICTIONARY_KEYS`/`RUN_SCOPED_KEYS`/`PROFILE_META_KEYS`/`CONTENT_UNLOCK_KEYS` + `not_yet_supported`
names `oath_shards_earned` (§8.2); `FirstDeathNarrativeBeat`/`FirstVictoryRevealBeat` `DICTIONARY_KEYS`
(`has_beat/line_id/line/is_skippable`) + both lines VERBATIM ("Good. You remembered how to die." / "It did not
die. It learned the way back.") (§9.2/§10.2); `RouteState` methods + `eligible_choice_ids` vs `available_choice_ids`
distinction + `RouteNode.TYPE_*`/`REVEAL_*`/`CLUE_*` (§5.2); `SettingsSnapshot.PREFERENCE_KEYS` + `[-60,0]` dB +
`INPUT_SCHEMES` + `SCHEMA_VERSION==1` + difficulty-non-goal regression test (§12); `SaveManager` route delegators
→ `RunResumeService` structured codes `save_not_found/save_open_failed/save_parse_failed/unsupported_save_schema/
invalid_tactical_snapshot/missing_tactical_snapshot/invalid_rng_snapshot` (§13.2); `AffinityViewModel.MODAL_KEYS`/
`RULE_KEYS` + `DarknessReadView.MODAL_KEYS` + the two Darkness cue-id constants (§15.2); the 7 RNG streams
`map/level/combat/loot/rewards/events/cosmetic` + `RunSnapshot.SCHEMA_VERSION==1` (§0.6); all four affinity PNGs
present in `godot/assets/tiles/affinities/` (§0/§14.3); no move commit-flow VM exists — the §16.1 non-gap is
correct.

- [x] **[Review][Patch] (Med) Gap G1 mis-sources hero HP on `RunState` — no such field exists.** §1.3 and the
  §16 ledger (G1 row) attribute the HUD's needed hero-HP field to "hero HP (from `RunState`)". Verified against
  `godot/scripts/run/run_state.gd`: `RunState` carries `phase, root_seed, is_manual_seed, meta_progression_eligible,
  route, selected_class_id, starting_kit, rules_resolver, inventory, pending_reward_offer, risk_economy,
  pending_event_offer, assigned_affinities` — there is **no** live hero-HP field. Hero HP is a tactical-board
  concept (the hero `TacticalEntityState`'s HP during a level) with `baseline_hp` on the class `StartingKit`; it
  is not a run-level `RunState` field. The gap itself (no run-HUD projection aggregates HP/node/gold/inventory
  for the `status` region) is real and correctly recorded as owned by 11.3 — only the parenthetical field-source
  for HP is wrong, and it would send the 11.3 implementer to the wrong surface. Fix: correct the HP source in
  §1.3 and the §16 G1 row (e.g. "hero HP — sourced during a level from the hero `TacticalEntityState` on the
  board / `baseline_hp` on the class `StartingKit`; there is no run-level HP field, which is part of why a run-HUD
  projection is needed"). The node-progress (`RouteState.cleared_node_ids` + node count) and gold
  (`RiskEconomyState.gold`) sources in the same note were verified correct.

- [x] **[Review][Patch] (Low) §2.2 attributes a `range` key to `TacticalAttackPreview` metadata; the actual key
  is `weapon_reach`.** §2.2 (attack preview line) lists `metadata:{weapon_id, targeting_shape, range, distance,
  blocker_state, ...}`. Verified against `godot/scripts/ui/view_models/tactical_attack_preview.gd`: the metadata
  dict key is `weapon_reach` (`"weapon_reach": weapon_reach`), not `range`. `range` appears only in the
  command-bridge attack metadata (`TacticalCommandBridge._command_metadata` copies `range` from the attack-command
  validation), which is a different surface than the preview VM `§2.2` names. Fix: change `range` → `weapon_reach`
  in the §2.2 attack-preview metadata enumeration (or note that `range` is the command-bridge metadata key while
  `weapon_reach` is the preview-VM metadata key). The remaining metadata keys listed (`weapon_id, targeting_shape,
  distance, blocker_state, blocker_ignored, expected_base_damage, warnings, effects, explanation`) were verified
  present.

- [x] **[Review][Patch] (Low) §0.2 points to "§14" for the contract-gap note location; the ledger is §16.** §0.2
  reads "records it as an explicit `Contract gap → <owning story>` note (see §14) and does not design the missing
  surface." §14 is the layout + accessibility coverage pass; the contract-gap ledger is **§16** (and §0.7's roster
  table + §16 itself both correctly reference §16). Fix: change "(see §14)" → "(see §16)" in §0.2. Internal
  navigation only — no contract-accuracy impact.

No `[Review][Defer]` items (nothing punted to the cross-story ledger). No `[Review][Decision]` items (no human
call required). All three findings are self-contained appendix edits the story owner can apply directly.

**Round 2 of 3**

Second independent adversarial pass (auto-gds delegate, Opus 4.8 [1m], 2026-07-04) — model-diverse re-review of the
same deliverable (`_bmad-output/planning-artifacts/ux-appendix-run-flow.md`). Two objectives: (1) verify the Round 1
fixes landed correctly in place, (2) hunt for anything the Round 1 pass missed. Every contract binding in the appendix
was re-verified directly against the as-built GDScript source (not trusting Round 1's verification), and the diff was
confirmed to touch ZERO production `godot/` code (diff-stat: only the appendix + this story file + `deferred-work.md`
+ `sprint-status.yaml` + `auto-gds/retro-notes/epic-11.md` changed).

**Verdict: Approve** — 0 Critical / 0 High / 0 Med / 1 Low (new). The appendix remains accurate and complete; the
sole new finding is a single mis-targeted internal section cross-reference (same class as the Round 1 §0.2 fix, a
different instance Round 1 did not catch). It has no contract-accuracy impact and does not block the downstream scene
stories.

**Round 1 fixes — all THREE verified in place and substantiated by source:**
- **G1 hero-HP source (Med, Round 1):** VERIFIED. `godot/scripts/run/run_state.gd` (re-read) carries no run-level HP
  field (its fields: `phase, root_seed, is_manual_seed, meta_progression_eligible, route, selected_class_id,
  starting_kit, rules_resolver, inventory, pending_reward_offer, risk_economy, pending_event_offer,
  assigned_affinities`). Appendix §1.3 + §16 G1 now correctly source hero HP from the hero `TacticalEntityState` /
  `StartingKit.baseline_hp` (confirmed `var baseline_hp: int = 0` at `starting_kit.gd:37`) and state "there is NO
  run-level HP field on `RunState`". Gold source `RiskEconomyState.gold` confirmed (`risk_economy_state.gd:51`); node
  progress `RouteState.cleared_node_ids` confirmed.
- **weapon_reach metadata key (Low, Round 1):** VERIFIED. `tactical_attack_preview.gd:40-41` emits `"weapon_reach":
  weapon_reach` in the preview-VM metadata dict; appendix §2.2 now lists `weapon_reach` and correctly disambiguates it
  from the command-bridge `range` key. The distinction is doubly confirmed: `tactical_command_bridge.gd:338` copies
  `range` in the ATTACK command metadata — a genuinely distinct surface. The Round 1 fix's disambiguation note is
  precisely correct.
- **§16 cross-ref (Low, Round 1):** VERIFIED. §0.2 (line 29) now reads "(see §16)"; §16 is the Contract-Gap ledger.

**Independent contract re-verification (all MATCH source; superset of Round 1's list, re-read from scratch):**
`TacticalBoardViewModel.to_dictionary()` 16 top-level keys in order (§1.2); `TacticalLayoutProfile` `PROFILE_*` ids +
`_REGION_NAMES` + `DEFAULT_MINIMUM_TOUCH_TARGET = Vector2(44,44)` + `PHONE_MAX_DIMENSION 700` + `DESKTOP_MIN_WIDTH 1280`
+ `_build_stacked_layout`/`_build_side_rail_layout` + `available:false` fallback (§0.4/§14); `TacticalAccessibilityModel`
`CHANNEL_*`/`SEVERITY_*` + `CUE_FEEDBACK_PREVIEW [shape,label]` + `CUE_FEEDBACK_COMMITTED [pattern,label,text]` +
affinity/Darkness cue ids (§0.5/§2.3/§15); `TacticalInspectView.from_context` 14-field `to_dictionary()` + visibility
tiers + telegraph fields (§3.2); `TacticalCommandBridge.build_command` intents `move`/`attack`/`inspect` +
`unsupported_intent` + `command_ready`/`disabled_result`/`metadata_only` (§2.2); `TacticalAttackCommitFlow`
`to_dictionary()` 10-key state + `MODE_*` + all 6 flow methods + `preview_ready`/`cancelled` reasons (§2.2);
`TacticalMovementPreview`/`TacticalAttackPreview` shapes + cue ids (§2.2); `PassiveRewardModalViewModel.MODAL_KEYS` (10
keys incl. `passive_id`) + `icon` as `String(definition.icon)` (§4.2); `PassiveRewardCommitFlow.to_dictionary()` 5 keys +
`arm_consume`/`arm_destroy`/`confirm`/`cancel`/`dismiss` + `dismissed` reason (§4.2); `HeroSelectViewModel.ENTRY_KEYS` +
`is_class_selectable` + class order `warrior/pyromancer/ranger/necromancer/shadeblade` (§6.2); `OutpostViewModel`
`DICTIONARY_KEYS` (13) + `RECOVERY_STATE_KEYS` + `NAMED_SPACE_KEYS` + `NAMED_SPACES` (4, all `deferred`, `maps_to`) +
`START_REQUEST_KEYS` + both `for_recovery` modes + `can_start_run()==true` (§7.2/§13.2); `RunSummary` `DICTIONARY_KEYS`
(10)/`RUN_SCOPED_KEYS` (9)/`PROFILE_META_KEYS`/`CONTENT_UNLOCK_KEYS`/`NOT_YET_SUPPORTED_FIELDS` + `oath_shards_earned`
(§8.2); the `outcome_or_cause` example value `victory` confirmed real (`run_end_outcome.gd:81`
`RUN_COMPLETED_OUTCOME_VICTORY`; `run_orchestrator.gd:767` `resolve_run_end(&"victory")`); `FirstDeathNarrativeBeat`/
`FirstVictoryRevealBeat` `DICTIONARY_KEYS` (`has_beat/line_id/line/is_skippable`) + both lines VERBATIM + `LINE_BY_ID`
keys `first_death`/`first_victory` (§9.2/§10.2); `RouteState` `eligible_choice_ids` (reveal-gated) vs
`available_choice_ids` (looser) + `RouteNode.TYPE_*`/`REVEAL_*`/`CLUE_*` (§5.2); `SettingsSnapshot.PREFERENCE_KEYS` (6)
+ `[-60,0]` dB + `INPUT_SCHEMES` + `SCHEMA_VERSION==1` + difficulty-non-goal regression-test comment (§12);
`RunResumeService` EXISTS (`godot/scripts/save/run_resume_service.gd`) + `SaveManager` delegators `resume_run`/
`resume_route_position`/`autosave_route_position`/`autosave_between_level` (`save_manager.gd:23-51`) + all 7 structured
codes `save_not_found/save_open_failed/save_parse_failed/unsupported_save_schema/invalid_tactical_snapshot/
missing_tactical_snapshot/invalid_rng_snapshot` (§13.2); `AffinityViewModel.MODAL_KEYS`/`RULE_KEYS` +
`DarknessReadView.MODAL_KEYS` + the two Darkness cue-id constants (§15.2). AC1 (roster + 2 reveal beats + manual-seed
warning), AC2 (per-screen pinned-key bindings + G1–G4 ledger, no invented surface), AC3 (four profiles +
color-independence + scalable text) all re-confirmed met.

- [x] **[Review][Patch] (Low) §0.4 layout-convention callout mis-targets §13; the layout+accessibility pass is §14.**
  §0.4 (line 75) reads: "unless a screen section states otherwise, its four-layout treatment follows **§13** (the
  global layout+accessibility pass)." Verified against the appendix's own section map: **§13 is "Save/resume recovery
  states"**; the global layout+accessibility pass is **§14** ("Layout + accessibility coverage pass (ALL screens —
  AC3)"). The parenthetical "(the global layout+accessibility pass)" is verbatim §14's role, confirming §13 is a typo
  for §14. Every other per-screen layout reference in the appendix correctly targets §14 (lines 217, 301, 351, 460,
  972) — only this one convention callout is wrong, and it is the most load-bearing cross-ref because all 13 screen
  sections defer their layout treatment to it. This is the SAME CLASS of navigation-reference defect as the Round 1
  §0.2 finding (a mis-numbered "see §N"), a different instance Round 1 did not catch. Fix: change "follows §13" →
  "follows §14" in §0.4 (line 75). Internal navigation only — no contract-accuracy impact; the self-labelling
  parenthetical lets a reader recover, so Low.

No `[Review][Defer]` items (nothing punted to the cross-story ledger). No `[Review][Decision]` items (no human call
required). The single new finding is a one-word appendix edit (§13 → §14) the story owner can apply directly. All
Round 1 fixes are confirmed in place; the appendix's contract fidelity is intact under a second, independent,
model-diverse pass.

## Dev Agent Record

### Agent Model Used

Opus 4.8 (claude-opus-4-8[1m])

### Debug Log References

- No code, tests, or headless-suite runs apply to this docs-only story (Story Type & Scope Boundary:
  "No production Godot code … no tests"). The headless suite (166 PASS at Epic-9 close) is untouched.
- Contract-verification method: every pinned key set cited in the appendix was read directly from source
  before authoring (the "read the actual source before writing each section" Dev-Notes mandate). Verified
  files: `tactical_board_view_model.gd`, `tactical_layout_profile.gd`, `tactical_accessibility_model.gd`,
  `tactical_text_scale.gd`, `tactical_inspect_view.gd`, `tactical_attack_commit_flow.gd`,
  `tactical_command_bridge.gd`, `tactical_attack_preview.gd`, `tactical_movement_preview.gd`,
  `passive_reward_modal_view_model.gd`, `passive_reward_commit_flow.gd`, `hero_select_view_model.gd`,
  `outpost_view_model.gd`, `run_summary.gd`, `run_end_outcome.gd`, `first_death_narrative_beat.gd`,
  `first_victory_reveal_beat.gd`, `route_state.gd`, `route_node.gd`, `settings_snapshot.gd`,
  `save_manager.gd` (route delegators), `run_resume_service.gd` (structured codes), `affinity_view_model.gd`,
  `darkness_read_view.gd`. Both narrative lines confirmed verbatim; the four affinity treatment PNGs
  confirmed present in `godot/assets/tiles/affinities/`.

### Completion Notes List

- Single deliverable authored: `_bmad-output/planning-artifacts/ux-appendix-run-flow.md` (18 sections,
  §0–§17). Discoverable by the `{planning_artifacts}/*ux*.md` glob (verified).
- **AC1 met:** every roster screen has a section — §1 tactical HUD, §2 preview/confirm, §3 inspect, §4
  passive modal, §5 run map, §6 hero select, §7 outpost/meta, §8 run summary, §12 settings, §13 save/resume
  recovery — PLUS §9 first-death reveal + §10 first-victory reveal (both with skip/dismiss) + §11 manual-seed
  no-progression warning.
- **AC2 met:** each screen section names the exact existing contract(s) + the pinned key/method it binds to
  (no invented surface); the four seed gaps are recorded as `Contract gap → owning story` notes and
  consolidated in the §16 ledger (G1 HUD run-context→11.3, G2 route VM→11.3, G3 Oath-Shards summary↔profile
  coupling→11.5, G4 settings VM→settings-scene owner). No further gaps found during authoring; §16.1 records
  two explicit NON-gaps (no move commit-flow VM; no fail-loud table to extend for 11.1) so the scene stories
  don't hunt for them.
- **AC3 met:** §14 addresses all four layout profiles (`phone_portrait`/`phone_landscape`/`tablet`/`desktop`
  via the existing `TacticalLayoutProfile.PROFILE_*` ids) + color-independence (the `shape`/`icon`/`label`/
  `pattern`/`text` vocabulary) + scalable text (the `TacticalTextScale [0.85, 2.0]` clamp) for every screen;
  each per-screen section also carries its own layout+accessibility subsection.
- Scope held: ZERO production code / scenes / tests / save schema / RNG / content touched. The appendix maps
  to EXISTING pinned surfaces only; it invents no view model, DTO, command, event, or field.
- Story 10.7 does NOT yet exist as a file (Epic-10 §10.4–10.7 execute AFTER Epic 11 per the 2026-07-04 sprint
  change), so the Task-1 "reference from Story 10.7's UX-prerequisite check" subtask is satisfied by the
  appendix self-documenting the 10.7 AC5 linkage (§0.1); 10.7 will cite the appendix when authored. No 10.7
  file was created (out of scope for this docs story, and creating a not-yet-scheduled story would be an
  invention).

### File List

- `_bmad-output/planning-artifacts/ux-appendix-run-flow.md` (NEW — the UX appendix; the story's single deliverable)
- `_bmad-output/implementation-artifacts/11-1-run-flow-ux-appendix-and-screen-contracts.md` (MODIFIED — frontmatter `baseline_commit`, tasks/subtasks checked, Dev Agent Record, Change Log, Status)
- `_bmad-output/implementation-artifacts/sprint-status.yaml` (MODIFIED — story status ready-for-dev → in-progress → review; `last_updated`)

### Change Log

| Date | Change |
|---|---|
| 2026-07-04 | Authored the run-flow UX appendix (`ux-appendix-run-flow.md`) — 13 screen sections + 2 reveal beats + manual-seed warning + the four-layout/accessibility pass + affinity read + the G1–G4 contract-gap ledger, all bound to existing pinned view-model/read-surface/command-bridge contracts (no new domain surface). Marked all Tasks 1–7 complete; moved story to review. |
