# Accessibility and Readability Audit — MVP Readiness Pass

> **Story:** 10.5 (Accessibility and Readability Audit) · **Epic:** 10 (Playtest Tuning and MVP Readiness)
> **Type:** Readiness / accessibility-audit artifact (the readability sibling of the 10.1 device-tiers plan, the
> 10.4 comprehension checklist, and the 11.1 UX appendix — author the audit, verify every headless-verifiable
> accessibility fact, record honest availability gaps for the human-eyes-on-hardware rest, touch no simulation).
> **Status:** authored 2026-07-08 · discharges the **NFR7 phone readability / NFR8 scalable text / NFR9
> colorblind-safe (no color-only meaning)** readability half of the Epic-10 MVP-readiness mandate so the **10.6
> readiness gate** consumes a structured accessibility audit + a findings table + a gap ledger, not guesswork.
> **10.5 is NOT the last story of Epic 10** (10-6 / 10-7 follow); this is a mid-epic readiness story — no
> epic-end retrospective is triggered off it.

---

## 1. Purpose and Scope

**Purpose.** This document systematically audits whether critical tactical / run-flow information stays
**ACCESSIBLE** in the MVP build — **colorblind-safe, scalable, non-overlapping, and never color- or audio-only**
— across the full on-screen screen roster. Epics 1-9 shipped a complete headless deterministic domain; Story 2.6
shipped the CODIFIED color-independence + scalable-text accessibility contract (the tactical-HUD cue catalog,
deeply tested); Story 2.9 shipped the persisted accessibility preferences; Epic 11 wired the run-flow scenes
(route map / outpost / run summary / reveal / save-recovery / hero select) and the UX appendix §0.5 / §14 that
binds every screen to that same contract; Epic 12 wired the interactive tap-loop. What the project has **never
had is a single systematic accessibility & readability AUDIT that verifies the contract is complete + honored
across the WHOLE roster and records the gaps.** This artifact is that audit. It discharges the **NFR7 / NFR8 /
NFR9 readability half** of the Epic-10 readiness mandate so the **10.6 readiness gate** rests on a real,
structured accessibility audit rather than guesswork.

**Scope (what this artifact delivers, and the honest boundary).**

1. The **per-surface audit** across the full AC1 surface list PLUS the roster-completeness surfaces (appendix
   §0.7), each recording the **four checks** — colorblind-safe communication, scalable text, non-overlap, no
   color-only meaning — with a concrete pass/fail read and the CONTRACT each rests on (§4, AC1).
2. The consolidated **findings table** (screen | state | issue | severity | disposition/owner) — every FAIL / gap
   recorded with AC1's "screen, state, and issue" (§5, AC1).
3. The **phone portrait/landscape reachability + orientation-invariance** read for the core combat + reward
   flows, backed by the existing layout-invariance evidence, with the physical-device pass recorded as an
   availability gap (§6, AC2).
4. The **audio-off equivalence** audit — with audio muted/unavailable, preview/confirm/warning/damage/reward
   feedback keeps a visual/textual equivalent; no required information is audio-only (§7, AC3).
5. The **headless-verified run-flow cue-coverage fact** — every cue id the run-flow affinity/Darkness read models
   emit resolves in the live accessibility catalog with a non-color channel (§8, AC-support), proven by a new
   passing test.
6. A consolidated **Availability Gaps ledger** (each gap → owning follow-up) and the **10.6 / 10.7 gate handoff**
   (§9, §10).

**Out of scope (explicitly NOT this story).** Any change to a gameplay command, event, RNG stream, `RunSnapshot`
/ `ProfileSnapshot` / `SettingsSnapshot` schema, save key, generator / route / finale fingerprint, view model,
content definition, presenter, or `.tscn`. **The accessibility CONTRACT already exists and is deeply tested —
this audit VERIFIES it, it does NOT rebuild it:** it re-derives no cue catalog, re-implements no sanitizer,
re-writes no presenter, and — critically — **registers no cue and wires no missing label** (findings are RECORDED
against owners, not fixed here). **No difficulty selector, tier, or knob** (a hard non-goal): the settings-screen
audit CONFIRMS the difficulty non-goal holds (no selector to audit) and never proposes adding one. **No
live-service telemetry** (NFR11): an accessibility audit is a local planning artifact — no cloud call, no
account, no always-on sink. The full headless suite stays green and byte-for-byte behaviorally unchanged; the
only sanctioned `godot/` edit is the additive accessibility-readiness-fact test in §8 (a new passing
`test_*.gd`, no existing pin moved — **190 PASS → 191 PASS / 0 `^FAIL`**).

**Grounding.** Read alongside the accessibility contract
(`godot/scripts/ui/view_models/tactical_accessibility_model.gd` — the `_CUE_CATALOG` + the
`channels_for_cue()` / `has_non_color_channel()` audit helpers;
`godot/scripts/ui/view_models/tactical_text_scale.gd` — the `[0.85, 2.0]` clamp;
`godot/scripts/settings/settings_snapshot.gd` — the persisted `text_scale` / `colorblind_safe` /
`high_contrast` preferences) and the run-flow UX appendix
(`_bmad-output/planning-artifacts/ux-appendix-run-flow.md` — §0.5 the contract every screen inherits, §0.7 the
13-screen roster, §14 the global layout+accessibility pass, §15 the affinity read, §16 the contract gaps). The
direct structural precedents are 10.1
(`_bmad-output/planning-artifacts/device-tiers-and-performance-budgets.md`) and 10.4
(`_bmad-output/planning-artifacts/mvp-playtest-comprehension-checklist.md`): define what can be audited, verify
what can be verified now, record honest gaps against owners, touch no simulation.

---

## 2. The measurement reality (why human-eyes-on-hardware checks are availability gaps, not blockers)

A headless autonomous agent **cannot** run a physical-device accessibility lab: it cannot measure a real
contrast ratio on a phone display, cannot confirm real thumb-reach on hardware, and cannot eyeball a colorblind
simulation on a live screen. The ACs were written to be dischargeable **without** such a lab because the
accessibility CONTRACT is codified and testable:

- **Audit now:** the complete per-surface audit (§4), the findings table (§5), the phone-profile reachability
  read grounded in `TacticalLayoutProfile` + the layout-invariance test (§6), the audio-off equivalence grounded
  in the feedback-cue `visual_available` contract (§7).
- **Verify now (headless):** the readiness FACTS the audit rests on — the tactical-HUD color-independence +
  scalable-text + audio-off contract (already proven by the 16-method `test_tactical_accessibility_cues.gd`), and
  the NET-NEW run-flow-roster cue-coverage fact (every affinity/Darkness on-screen cue id resolves in the live
  catalog with a non-color channel; §8, a new passing test).
- **Record as an availability gap:** the human-eyes-on-hardware dimension (a real contrast-ratio measurement on a
  physical phone; real thumb-reach on hardware; a physical portrait/landscape readability pass), each named
  against its owning follow-up (§9).

This is the **same honesty posture** 10.1 used for physical-device measurement and 10.4 used for observed
sessions. The **10.6 readiness gate** is where the project decides whether a still-open human-eyes accessibility
gap is an acceptable documented readiness **limitation** or must be discharged by a real device pass before
MVP-readiness passes. 10.5's job is to make the audit + findings + gaps **explicit and dischargeable** — not to
run the device lab. This is also the project-context rule that MAKES the gap legitimate: *"Human playtests remain
required for feel, readability, frustration, and excitement"* (§ Testing Rules). **Do NOT treat the
physical-device pass as a blocker for authoring this audit** — the audit is completable and valuable without it.

---

## 3. The accessibility contract the audit verifies (READ — not re-derived)

Already exists; the audit VERIFIES it, it does not build it. Every per-surface check in §4 rests on one of these
contract elements. [Source: `tactical_accessibility_model.gd`; `tactical_text_scale.gd`; `settings_snapshot.gd`;
`settings_apply_service.gd`; `ux-appendix-run-flow.md` §0.5 / §14.2]

| Contract element | What it guarantees | Where it lives (the audit READS it) |
|---|---|---|
| **Non-color channel vocabulary** | `shape` / `icon` / `label` / `pattern` / `text` — every critical cue carries ≥1; color is additive-only, never the sole signal (NFR9) | `TacticalAccessibilityModel._CUE_CATALOG` + `CHANNEL_*` consts; audit helpers `channels_for_cue()` / `has_non_color_channel()` |
| **Critical-cue coverage** | movement / attack / inspect / telegraph / commit + the 2 preview-vs-committed feedback cues + the 7.5 affinity cues + the 7.6 Darkness cues each map with a non-color channel | `_CUE_CATALOG` keys; proven by `test_tactical_accessibility_cues.gd` (16 methods) |
| **Scalable text** | requested scale clamped to `[0.85, 2.0]` (default 1.0), malformed → 1.0 with a stable reason, presenter hints (`label_scale_hint` / `spacing_hint` / `minimum_label_height`) for non-overlap; NEVER alters gameplay | `TacticalTextScale`; proven by `_text_scale_change_never_mutates_tactical_truth` + `_text_scale_change_never_alters_preview_legality_or_action_availability` |
| **Audio-off equivalence** | feedback cues keep `visual_available: true` regardless of `audio_available`; the parallel audio cue ids are additive-only (never carry sole meaning) | `TacticalAccessibilityModel._build_feedback` / `_feedback_entry`; proven by `_audio_feedback_cues_always_have_visual_or_textual_equivalents` |
| **Persisted preferences** | `text_scale` / `colorblind_safe` / `high_contrast` are presentation HINTS the presenter maps to the cue layer; `SCHEMA_VERSION == 1`; NO difficulty key | `SettingsSnapshot.PREFERENCE_KEYS` + `SettingsApplyService`; difficulty-absence enforced by a regression test (`test_settings_snapshot.gd`) |
| **Per-screen inheritance** | EVERY run-flow screen inherits §0.5 (non-color + scalable text); §14.2 lists the concrete per-screen non-color treatments | `ux-appendix-run-flow.md` §0.5 / §0.7 / §14.2 / §15 |

The four checks used throughout §4 map to these contract elements:

- **Colorblind-safe communication** → does every critical meaning on the surface carry a non-color channel
  (`has_non_color_channel`), so it reads with color stripped? (NFR9)
- **Scalable text** → does the surface respect the `TacticalTextScale` `[0.85, 2.0]` clamp driven by
  `SettingsSnapshot.text_scale`? (NFR8)
- **Non-overlap** → does the surface use the clamp's presenter hints (`label_scale_hint` / `spacing_hint` /
  `minimum_label_height`) so scaled labels stay readable and non-overlapping? (NFR8, the layout backing)
- **No color-only meaning** → is color additive-only on the surface (never the sole signal for any critical
  meaning)? (NFR9)

---

## 4. Per-surface accessibility audit (AC1)

Each surface below is **already shipped**; the audit OBSERVES it, it does not build it. For each surface the four
checks are recorded with a concrete pass/fail read and the CONTRACT each rests on. A **PASS** is recorded with its
backing (no fabricated failures); a **FAIL / gap** is consolidated into the findings table (§5). The roster equals
appendix §0.7 (the AC1 completeness backbone) = the GDD UI-frame list (`gdd.md` line 599) + FR68.

> **Legend.** ✅ = contract-verified pass · ⚠️ = tracked-placeholder / paper-audit gap (recorded in §5, owner
> named) · 👁 = passes at the contract level; the human-eyes-on-hardware confirmation is an availability gap (§9).

### 4.1 Tactical HUD (§1 · `TacticalBoardViewModel` + `TacticalLayoutProfile`)

The in-run combat screen: fog-aware board dominant, control bands, selection/preview, inspect, run-status,
log/outcome strip.

- **Colorblind-safe:** ✅ Every critical tactical meaning the HUD surfaces is a registered cue in `_CUE_CATALOG`
  with a non-color channel (movement / attack / inspect / telegraph / commit + the 2 feedback cues), proven by
  `test_tactical_accessibility_cues.gd::_every_critical_meaning_has_a_non_color_channel` +
  `_no_critical_cue_relies_on_color_alone`. The board VM carries a sanitized `accessibility` slot with
  `color_independent: true` (`_board_view_model_carries_sanitized_accessibility_slot`).
- **Scalable text:** ✅ The HUD text scale is DRIVEN by `SettingsSnapshot.text_scale` through the
  `TacticalTextScale` clamp (`test_run_flow_layout_invariance.gd::_settings_text_scale_reaches_the_hud_clamp`
  pins the seam: a saved 1.5 is delivered, not collapsed to 1.0; an out-of-clamp value clamps to MAX).
- **Non-overlap:** ✅ The clamp emits `label_scale_hint` / `spacing_hint` / `minimum_label_height`; the layout
  region plan reserves ≥44×44 control bands (§4.10). 👁 The pixel-level "no clipped label at 2.0× on a 390px
  phone" confirmation is a human-eyes gap (ASG-1, §9).
- **No color-only meaning:** ✅ Color is additive-only — severity (`info` / `warning` / `blocked` / `danger`) MAY
  map to color but every cue also carries a non-color channel (the contract's additive-severity guarantee).

### 4.2 Movement / attack previews (§2 · command bridge + preview VMs)

The pending move/attack preview shown before commitment (damage / target / legality).

- **Colorblind-safe:** ✅ `move_preview_valid/invalid` (shape+label), `attack_preview_valid/invalid` (icon+label),
  `attack_preview_blocked_line` (pattern+label+text), `attack_preview_adjacent_warning` (icon+label+text) each
  carry a non-color channel; the REAL cue ids emitted by `TacticalMovementPreview` / `TacticalAttackPreview` all
  map (`_real_movement_preview_cue_ids_all_have_accessibility_mappings` +
  `_real_attack_preview_cue_ids_all_have_accessibility_mappings`).
- **Scalable text:** ✅ Preview text inherits the HUD `TacticalTextScale` clamp; changing scale never alters
  preview legality (`_text_scale_change_never_alters_preview_legality_or_action_availability`).
- **Non-overlap:** ✅ Preview renders in the `preview` region band (≥44×44 per profile). 👁 pixel confirmation
  ASG-1.
- **No color-only meaning:** ✅ Legality (valid vs blocked) reads via shape/icon + label + a `blocked` severity,
  not color.

### 4.3 Preview / commit distinction (§2.3 · `TacticalAttackCommitFlow`)

The load-bearing two-step distinction: a PREVIEWED action vs a COMMITTED one.

- **Colorblind-safe:** ✅ `feedback_preview` (shape+label) and `feedback_committed` (pattern+label+text) carry
  DIFFERENT non-color channel sets, so preview vs committed is distinguishable with color stripped
  (`_preview_and_committed_feedback_are_distinct_without_color`).
- **Scalable text / Non-overlap:** ✅ Inherits the HUD clamp + `confirm_cancel` region.
- **No color-only meaning:** ✅ The distinction is shape-vs-pattern+text (not a color tint). This is a core NFR9
  surface (the two-step commit reads without color and, per §7, without audio).

### 4.4 Inspect panel (§3 · `TacticalInspectView`)

The tap-to-inspect visibility/threat read.

- **Colorblind-safe:** ✅ `inspect_visible` (label), `inspect_memory` (pattern+label), `inspect_hidden_unexplored`
  (pattern+label) carry non-color channels; the real inspect cue ids map, and a `memory` cell reads distinctly
  from a `visible`/`hidden` cell via a pattern (`_real_inspect_and_telegraph_cue_ids_all_have_accessibility_mappings`).
- **Scalable text / Non-overlap:** ✅ Inherits the clamp + the `inspect` region band.
- **No color-only meaning:** ✅ Visibility tiers read via label/pattern, not color.

### 4.5 Hazards / telegraphs (§3.3 · telegraph cues)

The telegraphed-danger read (ash-seer mark → detonation).

- **Colorblind-safe:** ✅ `telegraph_pending` (pattern+label), `telegraph_due` (pattern+label+text),
  `danger_damage` (icon+label+text) carry non-color channels; the pending + due telegraph cue ids map
  (same audit method). A due telegraph escalates via a `danger` severity ADDITIVE to the non-color pattern/text.
- **Scalable text / Non-overlap:** ✅ Inherits the clamp; the danger text renders in the board/inspect region.
- **No color-only meaning:** ✅ Danger reads via pattern/icon + text, not a red-only tint.

### 4.6 Affinities — Scorched / Flooded / Cursed / Darkness (§15 · `LiveAffinityReadModel` + `AffinityViewModel` + `DarknessReadView`)

The on-screen affinity read (a failed containment protocol + its tactical pressure).

- **Colorblind-safe:** ✅ The affinity danger cues each carry a non-color channel: `affinity_scorched_hazard`
  (icon+label+text), `affinity_pathing_pressure` (pattern+label), the 2 Darkness cues
  (`affinity_darkness_reduced_visibility` icon+label+text, `affinity_darkness_memory_uncertain`
  pattern+label+text). **Verified headless by this story across the RUN-FLOW read models** — every cue id
  `LiveAffinityReadModel.cue_ids` + `DarknessReadView.cue_ids` emit resolves in the live catalog with a non-color
  channel (§8; `test_run_flow_accessibility_coverage.gd`). Cursed carries no danger cell cue in v0 (its
  reward-odds effect is a later story); its read is the record-only `tactical_rules` + `visual_tags`.
- **Scalable text / Non-overlap:** ✅ Affinity read text inherits the clamp; the badge/panel scales by profile
  (compact badge on phone, fuller panel on desktop/inspect — §15.3 / §14).
- **No color-only meaning:** ✅ Every affinity's critical danger information is non-color (icon/label/text or
  pattern/label). **⚠️ Tracked-placeholder finding (F-1, §5):** the Flooded `affinity_conductive_danger_placeholder`
  (+ `..._vfx`) cue is a TRACKED, DISTINCT-from-final MVP placeholder — but it ALREADY carries a non-color
  `shape` channel, so even as a placeholder the conductive danger reads with color stripped. Its full treatment
  (replace / de-scope / block) is **owned by 10.7**; the audit records it as a tracked placeholder, NOT a 10.5
  fix.

### 4.7 Passive-reward modal (§4 · `PassiveRewardModalViewModel` + `PassiveRewardCommitFlow`)

The Consume-vs-Destroy passive-reward choice.

- **Colorblind-safe:** ✅ Per §4.4 the modal binds the passive `visual_tags` / icon-id hooks + labeled
  Consume/Destroy actions (label+icon, not color). The Consume-vs-Destroy trade-off reads via text, not a
  color-coded button pair.
- **Scalable text / Non-overlap:** ✅ Modal text respects the clamp (§4.4); the Recraft UI-frame modal baseline
  is the frame (§14.3).
- **No color-only meaning:** ✅ The two options are labeled (power-now vs gamble), not distinguished by color.

### 4.8 Hero select (§6 · `HeroSelectViewModel`)

The class-selection grid; locked vs selectable classes.

- **Colorblind-safe:** ✅ Locked state reads via label/icon + `unlock_hint` text, not color (§6.4). The
  profile-aware selectability (11.6 applied-unlock) flips the label/affordance, not a color.
- **Scalable text / Non-overlap:** ✅ `unlock_hint` + `display_name` respect the clamp; cards ≥44×44, single-column
  on phone / grid on desktop (§6.4).
- **No color-only meaning:** ✅ Locked vs selectable reads via label/icon + hint text.

### 4.9 Route map (§5 · `RouteState` / `RouteNode`)

The between-node run map: node types + reveal state.

- **Colorblind-safe:** ✅ Node type + reveal state read via icon/label + pattern/label (§14.2), not color. The
  scene-free `RouteMapViewModel` (Story 11.3) projects the route reads — per-node `type` via icon+label and
  `reveal_state` via pattern+label (the appendix §5.4 non-color channels); it closes the appendix §16 contract
  gap G2 (which flagged the earlier absence of a dedicated route VM), and it is scene-load verified. Either way
  the node-type/reveal meanings are non-color, so this was never an accessibility gap.
- **Scalable text / Non-overlap:** ✅ Node labels respect the clamp; the route graph is the dominant region per
  profile (§14.1).
- **No color-only meaning:** ✅ Node type (combat / elite / boss / event) + reveal (revealed / hidden) read via
  icon+label / pattern+label.

### 4.10 Outpost / meta menu (§7 · `OutpostViewModel`)

The between-run hub: meta readout, the four named GDD spaces (all `deferred` in v0), embedded run summary + first-death
beat, recovery surface, descend affordance.

- **Colorblind-safe:** ✅ Deferred spaces carry a label/icon "coming soon" marker (not color-only); meta counts
  (Oath Shards, echoes) shown as number + label; the recovery banner uses a distinct text+icon per mode
  (`[!]` write-failure vs `[?]` load-failure — `outpost_presenter._render_recovery_banner`), so the two recovery
  modes read differently without color (§7.4 / §13.5). The Seal-Table spend tiles render can-afford / insufficient
  / applied state as non-color text+icon (11.6 `OutpostRenderView`).
- **Scalable text / Non-overlap:** ✅ Outpost text respects the clamp (§7.4); the descend affordance is
  `DEFAULT_MINIMUM_TOUCH_TARGET` (≥44×44, `_render_descend_affordance`).
- **No color-only meaning:** ✅ Deferred markers, meta counts, recovery modes, and spend states all read via
  text/icon/label. **Difficulty non-goal CONFIRMED:** the outpost/meta menu presents NO difficulty selector (the
  ratified hard non-goal) — there is no difficulty control to audit, and none must be added.

### 4.11 Run summary (§8 · `RunSummary`)

The run-end review sheet: cause of death/victory, nodes cleared, boss/elite progress, passives, loot, economy,
seed, manual-seed flag.

- **Colorblind-safe:** ✅ (partial) The manual-seed warning is a labeled banner (text + `[!]` icon), not a color
  tint (`_render_warning_banner`); run-scoped facts are number+label. **⚠️ Finding F-2 (§5):** appendix §8.5 wants
  "outcome (victory vs death) via label+icon (not color-only)" ON the summary panel, but
  `outpost_presenter._render_run_summary` renders only the honest "not yet tallied" Oath-Shards note + the "No
  just-ended run" branch — it surfaces NO explicit victory/death label. The outcome IS conveyed non-color via the
  SEPARATE reveal beats (§4.12/§4.13) + `phase` (`PHASE_COMPLETED` / `PHASE_FAILED`), never `outcome_or_cause`
  (which stays BLANK until the run-level event store lands). So this is a **readability-completeness gap, not a
  color-only violation** (the outcome is not color-coded — it is simply not labeled on the summary panel itself).
  Owner: the run-level event-store / summary-render story (originating 11.5). NOT wired here.
- **Scalable text / Non-overlap:** ✅ Summary text respects the clamp (§8.5); single stacked column on phone,
  two-column on desktop.
- **No color-only meaning:** ✅ No summary meaning is color-coded; F-2 is a missing LABEL, not a color reliance.

### 4.12 First-death reveal moment (§9 · `FirstDeathNarrativeBeat`)

The one-time first-death narrative beat.

- **Colorblind-safe:** ✅ The beat is heading + line TEXT with a Skip/Dismiss affordance (`_render_reveal_beat`),
  gated on `has_beat` — a pure text surface, no color-coded meaning.
- **Scalable text / Non-overlap:** ✅ Beat text respects the clamp; the Skip/Dismiss button is
  `DEFAULT_MINIMUM_TOUCH_TARGET` (≥44×44), always reachable.
- **No color-only meaning:** ✅ Pure narrative text; the Skip is a pure-presentation no-op (submits no command).

### 4.13 First-victory reveal moment (§10 · `FirstVictoryRevealBeat`)

The one-time first-victory narrative beat.

- **Colorblind-safe / Scalable text / Non-overlap / No color-only:** ✅ Same as §4.12 (a text beat + a ≥44×44
  Skip/Dismiss, gated on `has_beat`). This beat is the primary NON-COLOR victory signal on the outpost (paired
  with `phase`), which is why F-2's missing summary-panel label is a completeness gap rather than a break.

### 4.14 Manual-seed no-progression warning (§11 · eligibility flags on `RunSummary` / `OutpostViewModel`)

The FR60 "manual seed → no meta progression" warning.

- **Colorblind-safe:** ✅ Rendered as a labeled banner (`[!] <line>` text+icon, `_render_warning_banner`), not a
  color tint (§11 / §14.2).
- **Scalable text / Non-overlap:** ✅ Banner text respects the clamp; it is a full-width labeled strip.
- **No color-only meaning:** ✅ The warning is text+icon; `is_manual_seed` / `meta_progression_eligible` drive a
  labeled message, not a color.

### 4.15 Settings (§12 · `SettingsSnapshot` / `SettingsManager` — PAPER audit, gap G4)

The player-preferences surface: text scale, audio volume/mute, input preference, the two accessibility toggles.
**No settings VIEW model and NO settings SCENE exist yet** (contract gap G4, PARKED — the settings-scene owner
is 11.3/11.5 per the eventual scene split). So the settings-screen accessibility is a **PAPER audit against the
`SettingsSnapshot` contract + appendix §12.5**, recorded as a gap → owner (F-3, §5).

- **Colorblind-safe (paper):** ✅ (contract intent, §12.5) Every control labeled (text, not color-only); toggles
  carry an on/off label + icon. The `colorblind_safe` / `high_contrast` toggles are the very controls that drive
  §0.5 everywhere else — so the settings screen must itself honor the current scale/contrast (ironically
  self-referential).
- **Scalable text (paper):** ✅ `SettingsSnapshot.text_scale` is clamped by `TacticalTextScale` to `[0.85, 2.0]`
  (`_sanitize_text_scale`); the settings list must respect the current scale.
- **Non-overlap (paper):** ✅ (contract intent) Controls ≥44×44 (sliders, toggles); single column on phone / a
  wider form on desktop (§12.5).
- **No color-only meaning (paper):** ✅ Every control labeled; toggles carry an on/off label + icon (§12.5).
- **Difficulty non-goal CONFIRMED:** `SettingsSnapshot.PREFERENCE_KEYS` = `text_scale`, `master_volume_db`,
  `audio_muted`, `input_scheme`, `colorblind_safe`, `high_contrast` — NO difficulty key; a regression test
  enforces the absence. The settings screen MUST NOT present a difficulty selector; the audit confirms there is
  none to audit and never proposes adding one.
- **⚠️ Gap F-3 (§5):** the settings audit is a paper audit until the settings SCENE + (optional) VM are built;
  the human-eyes readability of the real settings scene is owed by the settings-scene owner.

### 4.16 Save/resume recovery states (§13 · `SaveManager` → `RunResumeService` + `OutpostViewModel.recovery_state`)

The structured recovery states (missing / corrupt / unsupported-schema save; profile load/write failure).

- **Colorblind-safe:** ✅ Each recovery state carries a text explanation + an icon so "save not found" reads
  differently from "save corrupt" without color (§13.5); the outpost recovery banner uses `[!]` (write-failure)
  vs `[?]` (load-failure) text+icon (`_render_recovery_banner`). The structured `ActionResult` codes
  (`save_not_found` / `save_parse_failed` / `unsupported_save_schema` / `invalid_tactical_snapshot` /
  `invalid_rng_snapshot`) map to distinct labeled messages, not colors.
- **Scalable text / Non-overlap:** ✅ Recovery text respects the clamp; action buttons (retry / start fresh)
  ≥44×44 (§13.5).
- **No color-only meaning:** ✅ Each state = a text message + an icon + a recovery affordance; the code, not a
  color, is the truth the screen renders.

### 4.17 Surface → checks summary

| # | Surface | Colorblind-safe | Scalable text | Non-overlap | No color-only | Backing |
|---|---|---|---|---|---|---|
| 1 | Tactical HUD | ✅ | ✅ | ✅ / 👁 | ✅ | `_CUE_CATALOG`; `test_tactical_accessibility_cues.gd`; layout-invariance seam |
| 2 | Move/attack previews | ✅ | ✅ | ✅ / 👁 | ✅ | real preview cue-id maps; text-scale legality invariance |
| 3 | Preview/commit distinction | ✅ | ✅ | ✅ | ✅ | shape-vs-pattern+text distinct without color |
| 4 | Inspect panel | ✅ | ✅ | ✅ | ✅ | inspect visibility-tier cue maps |
| 5 | Hazards / telegraphs | ✅ | ✅ | ✅ | ✅ | telegraph pending/due/danger cue maps |
| 6 | Affinities (Scorched/Flooded/Cursed/Darkness) | ✅ / ⚠️ F-1 | ✅ | ✅ | ✅ / ⚠️ F-1 | §8 run-flow cue-coverage test; Flooded placeholder tracked |
| 7 | Passive modal | ✅ | ✅ | ✅ | ✅ | §4.4 label+icon; Recraft frame |
| 8 | Hero select | ✅ | ✅ | ✅ | ✅ | §6.4 locked via label/icon+hint |
| 9 | Route map | ✅ | ✅ | ✅ | ✅ | §14.2 node-type/reveal non-color |
| 10 | Outpost / meta menu | ✅ | ✅ | ✅ | ✅ | §7.4; recovery `[!]`/`[?]`; difficulty non-goal confirmed |
| 11 | Run summary | ⚠️ F-2 | ✅ | ✅ | ✅ | §8.5; outcome via reveal-beats+`phase`, no summary-panel label |
| 12 | First-death reveal | ✅ | ✅ | ✅ | ✅ | text beat + ≥44×44 Skip |
| 13 | First-victory reveal | ✅ | ✅ | ✅ | ✅ | text beat + ≥44×44 Skip |
| 14 | Manual-seed warning | ✅ | ✅ | ✅ | ✅ | labeled `[!]` banner |
| 15 | Settings | ⚠️ F-3 (paper) | ✅ (paper) | ✅ (paper) | ✅ (paper) | §12.5 paper audit; G4 no scene/VM; difficulty non-goal confirmed |
| 16 | Save/resume recovery | ✅ | ✅ | ✅ | ✅ | §13.5; distinct code→message+icon |

Every named AC1 surface (tactical HUD, previews, hazards, affinities, telegraphs, passive modal, route map,
outpost, run summary) PLUS the roster-completeness surfaces (inspect, hero select, both reveal beats, manual-seed
warning, settings, save/resume recovery) has a per-surface section with all four checks. Every FAIL / gap is in
§5. **Missing a named surface, missing any of the four checks, or a finding lacking screen/state/issue = AC1 not
met** — none is missing.

---

## 5. Consolidated findings table (AC1 — "failures are recorded with screen, state, and issue")

Every FAIL / gap surfaced by the §4 audit, each with **screen + state + issue + severity + disposition/owner**.
Surfaces that pass cleanly are recorded as PASS in §4 with their backing (no fabricated failures). All three
findings are KNOWN, headless-verifiable readiness items folded from the overlapping deferred-work entries — none
is a 10.5 fix; each is RECORDED against its owner.

| ID | Screen | State | Issue | Severity | Disposition / owner |
|---|---|---|---|---|---|
| **F-1** | Affinity read / inspect (§4.6) | Flooded / Conductive active | The `affinity_conductive_danger_placeholder` (+ `..._vfx`) cue is a TRACKED, distinct-from-final MVP PLACEHOLDER. It ALREADY carries a non-color `shape` channel (so the conductive danger reads with color stripped even as a placeholder), so it is NOT a color-only or missing-cue violation — but the FULL conductive-interaction treatment (art/VFX + final cue) is not shipped. | Low (tracked placeholder; non-color channel present) | **10.7** owns the full treatment (replace / de-scope / block). The audit RECORDS the tracked-placeholder status; it does NOT flip or resolve it. [`deferred-work.md` "Flooded electric-interaction `_placeholder` (Epic-10 readiness, 10-7)"; `project-context.md` line 450] |
| **F-2** | Outpost / run summary (§4.11) | Run-end (victory or death) | The run-summary PANEL surfaces no explicit victory/death outcome LABEL (appendix §8.5 wants "outcome via label+icon"). `outpost_presenter._render_run_summary` renders only the "not yet tallied" note; the outcome IS conveyed non-color via the SEPARATE reveal beats + `phase` (`outcome_or_cause` stays BLANK until the run-level event store lands). A readability-completeness gap, NOT a color-only violation. | Low (off critical path; outcome conveyed elsewhere non-color) | The **run-level event-store / summary-render story** (originating 11.5 code review). Until events are threaded, a summary-render MUST key the label off `phase`, not `outcome_or_cause`. NOT wired here. [`deferred-work.md` code review of 11-5 (Low)] |
| **F-3** | Settings (§4.15) | Any (no scene built) | No settings VIEW model and no settings SCENE exists yet (contract gap G4, PARKED). The settings-screen accessibility is a PAPER audit against the `SettingsSnapshot` contract + appendix §12.5; the human-eyes readability of the real settings scene cannot be audited until it is built. (The difficulty NON-GOAL is confirmed at the contract level — no difficulty key, regression-enforced.) | Med (a whole surface is paper-only until built) | The **settings-scene owner (11.3 or 11.5** per the eventual scene split). The 10.6 gate weighs whether shipping MVP with a paper-only settings audit is acceptable. NOT built here. [`deferred-work.md` "G4 — the settings view model", RE-RECORDED PARKED; appendix §16 G4 / §12.3] |

**No fabricated failures.** Every other audited surface (§4.1-§4.5, §4.7-§4.10, §4.12-§4.14, §4.16) passes the
four checks at the contract level with the backing cited; the only human-eyes residue is the pixel-level
confirmation recorded as availability gap ASG-1 (§9), not a per-surface failure.

---

## 6. Phone portrait/landscape reachability + orientation invariance (AC2)

### 6.1 The phone-profile reachability + readability read (core combat + reward flows)

**GIVEN phone portrait and landscape viewports, WHEN core combat and reward flows are exercised, THEN primary
actions remain reachable and readable.** The audit reads this against `TacticalLayoutProfile` (the four-profile
plan authority) + the two layout tests (the evidence):

- **`phone_portrait` (primary).** Stacked layout — the board (the dominant primary region) on top; the four
  control bands (preview / confirm_cancel / inspect / status) beneath along the lower thumb-reachable edge
  (`TacticalLayoutProfile._build_stacked_layout`). Compact density (8px). **Primary actions stay reachable at
  ≥44×44** — `test_run_flow_layout_invariance.gd::_board_stays_dominant_and_controls_reachable_on_both_profiles`
  asserts on the phone_portrait `[390×844]` profile that the board is the largest region AND every control
  (`preview` / `confirm` / `cancel` / `inspect` / `status`) is `reachable: true` at ≥ the `minimum_touch_target`.
- **`phone_landscape` (same experience, more width).** Side-rail layout — the board on the left; controls in a
  right-side rail (`_build_side_rail_layout`) so panels do not consume full width and the board stays
  central/left. Compact density. The `_region_is_reachable` gate enforces the ≥44×44 minimum on the rail bands.
- **Reward flow reachability:** the passive-reward modal (§4.7), the outpost descend affordance
  (`DEFAULT_MINIMUM_TOUCH_TARGET`, `_render_descend_affordance`), and the reveal-beat Skip/Dismiss
  (`DEFAULT_MINIMUM_TOUCH_TARGET`, `_render_reveal_beat`) are each ≥44×44 and reachable on the compact profiles.
- **Invalid-viewport fallback:** a non-positive / non-finite viewport falls back to `phone_portrait` stacked with
  `available: false` + `reason: fallback_invalid_viewport` (`_build_fallback`) — the compact profile is the safe
  default, so a bad viewport never yields an unreachable layout.
- **Readability:** the primary content region stays the dominant, readable region on every profile
  (`_board_is_largest_region`); text respects the `TacticalTextScale` clamp (§4). 👁 The physical readability
  (real font legibility, real thumb-reach on a device) is availability gap ASG-2 (§9).

### 6.2 Orientation invariance ("orientation changes do not alter tactical rules")

**GIVEN orientation changes, THEN tactical rules are unchanged.** This is proven, NOT re-derived: `test_run_flow_
layout_invariance.gd::_board_contract_is_byte_identical_across_phone_and_desktop` asserts that every rule-bearing
board-VM slot (`cells`, `occupants`, `preview`, `commit_flow`, `inspect`, `action_availability`, `turn`,
`outcome`, `event_log_summary`, `width`, `height`) is **BYTE-IDENTICAL** across a `phone_portrait → desktop`
profile change — only the presentation `layout` slot differs. The same test proves the G1 HUD run-context read is
profile-invariant (`_g1_hud_read_is_profile_invariant`) and that changing `TacticalTextScale` never alters the
board/HUD contract (`_g1_hud_read_is_text_scale_invariant`). `test_tactical_layout_profiles.gd` owns the
four-profile classification plan incl. the invalid-viewport fallback. **Conclusion: layout / orientation / text
scale is presentation; it NEVER alters gameplay rules, RNG, turn, preview legality, or outcome.** (The
portrait↔landscape profile change is exactly the profile change these tests exercise, so the rule-invariance
conclusion carries to orientation.)

### 6.3 The AC2 human-eyes gap

A physical-device phone-hardware pass (real portrait/landscape readability, real thumb-reach) is recorded as
availability gap **ASG-2** (§9) → owned by the **10.6 gate**, intersecting the SAME physical-device G1-G7
constraint 10.1 recorded (the mobile form factor is not available to a headless agent). **Missing the
reachability read, the orientation-invariance statement, or the gap note = AC2 not met** — none is missing.

---

## 7. Audio-off equivalence audit (AC3)

**GIVEN audio is muted or unavailable, WHEN preview / confirm / warning / damage / reward feedback occur, THEN
visual or textual equivalents communicate critical meaning, AND no required information is audio-only.**

### 7.1 The contract fact (verified)

The accessibility contract GUARANTEES audio-off equivalence, and it is proven headless:

- **Feedback cues keep a visual/textual channel regardless of audio.** `TacticalAccessibilityModel._feedback_entry`
  sets `visual_available: not channels.is_empty()` — independent of `audio_available`. Both feedback cues
  (`feedback_preview`, `feedback_committed`) carry non-color visual/textual channels, so the preview-vs-committed
  distinction survives with audio muted or absent. Proven by
  `test_tactical_accessibility_cues.gd::_audio_feedback_cues_always_have_visual_or_textual_equivalents`, which
  additionally builds the model with `{"audio_available": false}` and asserts the muted feedback still marks
  `visual_available: true` for BOTH preview and committed AND keeps them visually distinct.
- **The parallel audio cue ids are additive-only.** `AUDIO_FEEDBACK_PREVIEW` / `AUDIO_FEEDBACK_COMMITTED` are
  declared as OPTIONAL parallel ids; the same test asserts every cue that declares an `audio_cue_id` STILL carries
  a non-color visual/textual channel — so audio NEVER carries sole meaning.
- **Coverage of the five AC3 feedback meanings.** preview → `feedback_preview` (visual); confirm →
  `feedback_committed` (visual); warning → `telegraph_pending` / `attack_preview_adjacent_warning` /
  `affinity_pathing_pressure` (all non-color, no audio id); damage → `danger_damage` / `telegraph_due`
  (non-color, no audio id); reward → the passive modal Consume/Destroy labels + the run-scoped summary facts (§4.7
  / §4.11, text). Only the two preview/commit feedback cues even DECLARE an audio id, and both keep a visual
  channel; the warning/damage/reward meanings carry no audio id at all — they are visual/textual by construction.

### 7.2 Audio is a 0-file placeholder track in v0 (nothing is audio-only today)

Audio is the only pending asset track — **0 files shipped** (a placeholder track), non-gating. So there is no
audio cue that could carry sole meaning even if the contract allowed it. `SettingsApplyService.apply` drives the
audio Master bus (`set_master_volume_db` / `mute_master`) and ECHOES `audio_muted` / `master_volume_db` in
metadata — it executes NO command, draws NO RNG, mutates NO tactical/visual truth (the service's documented
"presentation/preferences ONLY" contract). **Muting is a pure presentation choice that never hides critical
information:** `SettingsSnapshot.audio_muted` toggles the bus, not any gameplay/visual meaning.

### 7.3 Conclusion

**No required information is audio-only.** Every AC3 feedback meaning (preview / confirm / warning / damage /
reward) has a visual/textual equivalent guaranteed by the contract; the two feedback cues' optional audio ids are
additive; audio is a 0-file placeholder track. **No v0 surface violates the "no required information is
audio-only" rule** — there is no audio-only surface to flag. **Missing the equivalence statement, the contract
backing, or the no-audio-only conclusion = AC3 not met** — none is missing.

---

## 8. Headless-verified run-flow cue-coverage fact (AC1 / AC-support)

The tactical-HUD colorblind/scalable/audio-off contract is ALREADY proven by the 16-method
`test_tactical_accessibility_cues.gd` (referenced as the tactical-HUD evidence throughout §4/§7 — NOT duplicated).
What that test does NOT reach is the RUN-FLOW affinity/Darkness on-screen reads. This story adds ONE net-new
passing test that closes exactly that gap:

**`godot/tests/unit/ui/test_run_flow_accessibility_coverage.gd`** (new; homed alongside the 2.6 test) drives the
REAL run-flow read-model projections and asserts the readiness FACT that **every non-color cue id the run-flow
affinity/Darkness read models emit is registered in the LIVE `TacticalAccessibilityModel` catalog with a
non-color channel**:

- `LiveAffinityReadModel.project(&"scorched", board)` surfaces `affinity_scorched_hazard`, and every emitted
  `cue_ids` entry resolves in the live catalog with a non-color channel.
- `DarknessReadView.project_darkness(&"darkness")` surfaces its two FINAL cue ids
  (`affinity_darkness_reduced_visibility`, `affinity_darkness_memory_uncertain`), each resolving non-color.
- The AGGREGATED `LiveAffinityReadModel.project(&"darkness", board).cue_ids` (the composed on-screen surface the
  HUD/inspect binds) resolves entirely non-color.
- A neutral `none` level emits NO cue id (the legal empty read — nothing to audit, a valid state).
- A consolidated assertion that every registered `affinity_*` catalog cue (incl. the tracked Flooded
  conductive-danger PLACEHOLDER) carries a non-color channel and never a `color` channel.
- The `TacticalTextScale` `[0.85, 2.0]` clamp holds (below→MIN, above→MAX, in-bounds pass-through,
  malformed→1.0/`invalid_scale`) for the run-flow roster too.

**DELIBERATE-UPDATE tripwire discipline.** The test reads the LIVE catalog via `channels_for_cue()` /
`has_non_color_channel()` and drives the LIVE read-model projections — NEVER a hand-copied cue list. So a future
story that adds a run-flow cue id WITHOUT a non-color channel (or drops the channel from an emitted cue) makes
this **FAIL LOUD** — which is intended (the roster-coverage assertion is a tripwire a future cue-catalog change
must reconcile). It asserts a readiness FACT, not new gameplay behavior; it executes no command, draws no RNG,
mutates nothing. **Result: the full suite stays green — 190 PASS → 191 PASS / 0 `^FAIL`** (one new PASS line; the
6 documented stderr negatives — int64-overflow ×2, malformed-JSON ×3, `invalid_node_type` ×1 — are unchanged and
are NOT regressions).

---

## 9. Availability Gaps ledger (the honest-scope rest)

Every dimension this headless story cannot discharge, named against the AC it affects and its owning follow-up.
The **10.6 readiness gate decides** whether each is an acceptable documented readiness limitation or a hard
blocker. (These are the human-eyes-on-hardware residue; the CONTRACT-level checks are all verified in §4-§8.)

| Gap | What is missing | AC affected | Owning follow-up |
|---|---|---|---|
| **ASG-1** | A real contrast-ratio measurement + a pixel-level "no clipped/overlapping label at 2.0× on a compact phone" readability confirmation on a physical display (the human-eyes contrast + non-overlap check). The CONTRACT (non-color channels + the clamp's non-overlap hints) is verified; the physical measurement is not. | AC1 (colorblind-safe + non-overlap human-eyes half) | a physical-device accessibility pass, owned by the **10.6 gate** (intersects the 10.1 device G1-G7 physical-device gaps) |
| **ASG-2** | A physical phone-hardware pass — real portrait/landscape font legibility + real thumb-reach on a device. The `TacticalLayoutProfile` ≥44×44 reachability + the byte-identical rule-invariance are verified headless; the felt on-device readability/reach is not. | AC2 (phone reachability + readability human-eyes half) | the physical-device pass owned by the **10.6 gate** (the same G1-G7 mobile-form-factor constraint 10.1 recorded) |
| **F-3 / ASG-3** | The settings-SCENE human-eyes accessibility audit (the settings surface is a PAPER audit until the scene + optional VM are built — gap G4). | AC1 (settings surface) | the **settings-scene owner (11.3/11.5)**; the 10.6 gate weighs shipping MVP with a paper-only settings audit |

**Verified headless in this story (NOT gaps):** the tactical-HUD color-independence + scalable-text + audio-off
contract (§4/§7, the 16-method 2.6 test), the run-flow-roster affinity/Darkness cue coverage (§8, the new test),
the phone-profile ≥44×44 reachability + board dominance + the byte-identical orientation rule-invariance (§6, the
layout-invariance test), and the difficulty-non-goal absence (§4.10/§4.15, the settings regression test).

---

## 10. Sibling Epic-10 gate handoff

This audit **feeds and complements** the other Epic-10 readiness stories; it does NOT implement their content.

- **10.4 (Gameplay comprehension & playtest checklist).** 10.4's §3 comprehension read overlaps the HUD / preview
  / preview-commit / positioning surfaces, but it was a COMPREHENSION read, NOT an accessibility audit — 10.4
  **explicitly deferred the systematic contrast / colorblind / target-size audit to 10.5** (its §12 handoff).
  **This document is that pass** (the systematic four-check per-surface audit + findings table + gap ledger).
- **10.6 (MVP readiness gate & playable-build preservation).** **CONSUMES this audit** — the per-surface audit
  (§4), the findings table (§5), the phone reachability + orientation invariance (§6), the audio-off equivalence
  (§7), the run-flow cue-coverage fact (§8), and the availability gaps (§9). The gate decides whether each ASG gap
  is an acceptable documented readiness limitation or a hard blocker (esp. the physical-device human-eyes
  dimension).
- **10.7 (Asset/audio/placeholder & UX readiness gate).** OWNS the placeholder-asset / audio / UX readiness pass
  — including the **Flooded `affinity_conductive_danger_placeholder` full conductive-interaction treatment**
  (finding F-1) and the audio-track readiness (the 0-file placeholder track). **10.5 records F-1 as a
  tracked-placeholder finding only**; it does NOT resolve it.
- **The run-level event-store / summary-render story** (originating 11.5) owns finding **F-2** (the missing
  summary-panel victory/death label); **the settings-scene owner (11.3/11.5)** owns finding **F-3** (the paper-only
  settings audit, gap G4). 10.5 records both against their owners; it wires neither.

Every other open deferred-work entry (the run-level event STORE itself; the live in-node board save; the
`_relocate_scratch` reference-driver perf cost; the Necromancer/Shadeblade class-kit content; the affinity-driven
GENERATION modifier; the passive-combat-effect engine; the `RunSummary.outcome_or_cause` blank; the
winnability-catalog determinism-coverage gap) is OUT of scope — none is an accessibility/readability finding, and
none is touched, reopened, or re-deferred by this story.

---

## 11. References

- **Story source (verbatim ACs):** `_bmad-output/planning-artifacts/epics.md` — Epic 10 §"Story 10.5:
  Accessibility and Readability Audit" (incl. the 2026-07-04 Epic-11 prerequisite: "the audited surfaces must
  exist as screens first" and the 2026-07-07 note: "audit the tap/preview/commit surfaces Epic 12 adds"). FR/NFR
  map: NFR7 (phone-sized readability), NFR8 (scalable text), NFR9 (colorblind-safe / no color-only) — the three
  readability NFRs this audit validates; FR70 (playable-build preservation), FR9/FR10 (attack preview),
  FR12 (inspect), FR57/FR58 (affinity/Darkness tactical readability), FR69 (combat-log/damage explanation).
- **The accessibility contract (verified, NOT re-derived):**
  `godot/scripts/ui/view_models/tactical_accessibility_model.gd` (the `_CUE_CATALOG` +
  `channels_for_cue()` / `has_non_color_channel()`), `godot/scripts/ui/view_models/tactical_text_scale.gd`
  (the `[0.85, 2.0]` clamp + presenter hints), `godot/scripts/settings/settings_snapshot.gd`
  (`text_scale` / `colorblind_safe` / `high_contrast` + `PREFERENCE_KEYS`),
  `godot/scripts/settings/settings_apply_service.gd` (muting is presentation-only).
- **The audit evidence (referenced, not duplicated):**
  `godot/tests/unit/ui/test_tactical_accessibility_cues.gd` (16 methods — the tactical-HUD colorblind/scalable/
  audio-off proof), `godot/tests/unit/ui/test_run_flow_accessibility_coverage.gd` (NEW — the run-flow-roster
  cue-coverage extension added by this story), `godot/tests/unit/ui/test_run_flow_layout_invariance.gd` +
  `godot/tests/unit/ui/test_tactical_layout_profiles.gd` (the AC2 orientation-invariance + reachability proof),
  `godot/tests/unit/ui/test_run_flow_scenes_load.gd` (the scenes-exist prerequisite),
  `godot/scripts/ui/view_models/live_affinity_read_model.gd` + `darkness_read_view.gd` +
  `affinity_view_model.gd` (the run-flow cue-emitting read models),
  `godot/scripts/ui/presenters/outpost_presenter.gd` (the run-summary / recovery / warning render — F-2 backing).
- **The screen roster + inherited contract (the AC1 backbone):**
  `_bmad-output/planning-artifacts/ux-appendix-run-flow.md` — §0.5 (the contract every screen inherits), §0.7
  (the 13-screen AC1-completeness roster), §14.1-§14.2 (the four-layout + per-screen non-color + scalable-text
  pass), §15 (the affinity read + its non-color cues), §16 (Contract Gaps — G4 settings VM). The per-screen
  §_.5 "Layout & accessibility" subsections (§1.5/§2.3/§3.4/§4.4/§5.4/§6.4/§7.4/§8.5/§9.5/§10.5/§11.4/§12.5/§13.5).
- **Sibling Epic-10 readiness stories (the handoff):**
  `_bmad-output/planning-artifacts/mvp-playtest-comprehension-checklist.md` (10.4 — §12 hands the systematic
  contrast/colorblind/target-size audit to 10.5), Story 10.6 (readiness gate — consumes this audit), Story 10.7
  (asset/audio/placeholder & UX gate — owns the Flooded `_placeholder` full treatment + the audio-track
  readiness).
- **Prior readiness-doc precedents (the structural model):**
  `_bmad-output/planning-artifacts/device-tiers-and-performance-budgets.md` +
  `_bmad-output/implementation-artifacts/10-1-device-tiers-and-performance-budgets.md` (10.1 — docs-plus-gaps,
  verify-what-you-can, honest availability gaps, touch-no-simulation);
  `_bmad-output/implementation-artifacts/11-1-run-flow-ux-appendix-and-screen-contracts.md` (11.1 —
  contract-gaps-against-owners).
- **Overlapping deferred-work items (folded here, not reopened elsewhere):**
  `_bmad-output/implementation-artifacts/deferred-work.md` — the Flooded electric-interaction `_placeholder`
  (F-1, 10.7), the G4 settings view model (F-3, PARKED — the settings-scene owner), the outpost run-summary
  outcome-label gap (F-2, 11-5 code review Low + the run-level event-store / summary-render story).
- **Epic-10 retro (constraints):** `_bmad-output/auto-gds/retro-notes/epic-10.md` — §10-1 (physical-device
  G1-G7), §10-2 (the sole sanctioned edit is the additive readiness test), §10-3/§10-8 (the live-catalog
  tripwire discipline).
- **Project rules:** `CLAUDE.md` / `AGENTS.md` / `project-context.md` (§ Presentation, View-Model &
  Accessibility Rules lines 294-308 / 450 — the single cue registration site; phone-readability line 315;
  difficulty non-goal lines 304-308 / 402; no-telemetry NFR11 lines 374 / 396; human-playtests-required Testing
  rule line 362).
