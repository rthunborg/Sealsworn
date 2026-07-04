# Sealsworn Run-Flow UX Appendix and Screen Contracts

_Planning artifact — Story 11.1. Authored 2026-07-04. Lightweight UX specification, NOT pixel comps or final art._

## 0. Purpose, scope, and how to read this document

### 0.1 Purpose (what this discharges and feeds)

This appendix is the **lightweight UX appendix** the implementation-readiness report
(`implementation-readiness-report-2026-06-04.md`, lines 746–747, 919, 940, 995) flagged as
**MANDATORY before UI-heavy tactical scene production**, and it is the input **Story 10.7 AC5 (UX
readiness gate)** consumes. Its job is to make the MVP's run-flow screens designable-on-paper — screen
intent, regions, states, the exact existing contract each region binds to, four-layout coverage, and
accessibility rules — so the later Epic-11 scene stories (11.2–11.6) implement felt-on-screen work
against a settled design, and so the readiness gate can confirm the design exists.

It unblocks the scene-building stories: **11.3** (live run-flow scenes + tactical HUD), **11.4** (visual
treatment / affinity + UI-frame application), and **11.5** (outpost scene + reveal renders).

### 0.2 Scope (deliberately lightweight)

**In scope, per screen:** screen intent; the region breakdown; the meaningful states (including the
fail-closed empty/absent state); the **exact existing contract each region binds to** (class + the
pinned key/method it reads); the four-layout treatment; and the accessibility handling
(color-independence + scalable text).

**Out of scope (owned by later stories):** pixel comps; final art; a component library; new view models,
DTOs, commands, events, or fields. Where a screen needs data the existing contracts do not expose, this
appendix records it as an explicit **`Contract gap → <owning story>`** note (see §16) and does **not**
design the missing surface.

### 0.3 The one architectural rule this appendix obeys

> UI observes domain state through **view models / read surfaces**, and submits player intent through the
> **command bridge**. Scenes, `Control` nodes, audio, VFX, and animation are presentation; **they own no
> tactical truth.** (`_bmad-output/game-architecture.md`; `project-context.md` "Presentation observes
> domain state/events and submits commands through a command bridge.")

Every contract this appendix binds to is a `RefCounted` DTO or read surface — **NOT a `Control`, NOT a
`Node`, NOT a `.tscn`**. A screen READS a view model's pinned-key projection and SUBMITS a command-bridge
intent; it never mutates domain state directly. Every read surface is **fail-closed**: it projects a
`has_*` gate (`has_summary` / `has_beat` / `has_affinity` / `has_profile` / `has_passive` / `has_darkness`
/ `has_ended` / `has_recovery`) rather than crash, so every screen section below specifies its
empty/absent presentation state.

**This story writes ZERO production code.** It touches no `godot/scripts/`, no `godot/scenes/`, no
`godot/tests/`, no save schema, no RNG, no content. The headless suite (166 PASS at Epic-9 close) is
unchanged. The surfaces named here already exist and are stable as-built.

### 0.4 The four target layout profiles (used by EVERY screen section)

Sealsworn ships one tactical experience across four device shapes. This appendix reuses the **existing
stable profile ids** from `TacticalLayoutProfile` (`godot/scripts/ui/view_models/tactical_layout_profile.gd`)
— it invents no new profile names:

| Profile id (const) | Value | Density / spacing | Shape |
|---|---|---|---|
| `PROFILE_PHONE_PORTRAIT` | `"phone_portrait"` | compact / 8px | **Primary mobile mode.** Stacked: board dominant on top, control bands beneath (`_build_stacked_layout`). |
| `PROFILE_PHONE_LANDSCAPE` | `"phone_landscape"` | compact / 8px | **Same tactical experience, more width.** Side-rail: board left, controls in a right rail (`_build_side_rail_layout`). NOT a separate mode. |
| `PROFILE_TABLET` | `"tablet"` | comfortable / 12px | Stacked + an optional `log_or_outcome` strip; comfortable density. |
| `PROFILE_DESKTOP` | `"desktop"` | comfortable / 12px | Wider panels, comfortable density, mouse/keyboard parity. |

Classification thresholds (`PHONE_MAX_DIMENSION = 700`, `DESKTOP_MIN_WIDTH = 1280`) and the
invalid-viewport fallback (`REASON_FALLBACK_INVALID_VIEWPORT` → falls back to `phone_portrait`, `available:
false`) are owned by the profile helper; scenes inject a real viewport/safe-area and read the profile — they
do **not** re-derive layout. The **semantic `TacticalLayoutProfile` region plan is the testable source of
truth the scenes must honor** (do not hardcode geometry in scenes).

**Region vocabulary (fixed, per profile):** `board`, `preview`, `confirm_cancel`, `inspect`, `status`,
`log_or_outcome`. **Minimum touch target: 44×44** (`DEFAULT_MINIMUM_TOUCH_TARGET = Vector2(44, 44)`). The
board stays the dominant, readable region on every profile; orientation changes never alter rules
(`gdd.md` 558–575).

> **Layout convention for this appendix:** unless a screen section states otherwise, its four-layout
> treatment follows §13 (the global layout+accessibility pass). Per-screen sections call out only the
> deviations/specifics that matter for that screen.

### 0.5 The accessibility contract (inherited by EVERY screen)

This appendix reuses the codified color-independence contract from `TacticalAccessibilityModel`
(`godot/scripts/ui/view_models/tactical_accessibility_model.gd`) — it invents no new vocabulary:

- **Non-color channels:** `shape`, `icon`, `label`, `pattern`, `text` (the const `CHANNEL_*` set). **Every
  critical meaning must carry at least one non-color channel.** Color is additive only — never the sole
  signal (NFR9). The model's `has_non_color_channel(cue_id)` / `channels_for_cue(cue_id)` audit helpers
  guarantee each registered cue id already carries a redundant channel.
- **Severities:** `info`, `warning`, `blocked`, `danger` (the const `SEVERITY_*` set). A presenter MAY map
  severity → color, but additively (the meaning still reads with color stripped).
- **Scalable text:** requested scale is clamped by `TacticalTextScale`
  (`godot/scripts/ui/view_models/tactical_text_scale.gd`) to **`[MIN_TEXT_SCALE 0.85, MAX_TEXT_SCALE 2.0]`,
  default `1.0`** (NFR8). It emits value-only presenter hints (`label_scale_hint`, `spacing_hint`,
  `minimum_label_height`); it constructs no fonts/themes. Changing the scale **never** alters board, RNG,
  turn state, preview legality, action availability, telegraphs, outcome, or the event log.
- **Persisted preferences** that drive this at runtime live on `SettingsSnapshot` (`text_scale`,
  `colorblind_safe`, `high_contrast`) — see §12. They are presentation HINTS the presenter maps to the cue
  layer; settings does not own the cue catalog.

Every screen inherits this contract. Per-screen sections note only deviations/specifics (e.g. the
severity of a particular cue, or a screen with no color-coded meaning at all).

### 0.6 Constraints the LATER scene stories must respect (recorded here for honesty)

This is a docs story, so it perturbs none of these — but the scene wiring the appendix feeds must not
break them (`project-context.md`):

- **Determinism / resume invariant (NFR13):** resumed outcomes match uninterrupted play. A scene may not
  consume gameplay RNG, execute a command outside the bridge, or advance a turn as a side effect of
  rendering.
- **Save shape is frozen:** the 23-key `RunSnapshot` gate stays 23; `ProfileSnapshot.SCHEMA_VERSION == 1`;
  `SettingsSnapshot.SCHEMA_VERSION == 1`; the 7 named RNG streams (`map`, `level`, `combat`, `loot`,
  `rewards`, `events`, `cosmetic`); every pinned fingerprint. No screen here adds a save key.
- **Exact-key projection discipline:** every read surface pins an exact key set — a key never silently
  appears/vanishes. This appendix binds only to pinned keys; a screen that references a key outside the
  pinned set is an AC2 violation.
- **No new autoload / no new domain surface.** Epics 8–9 added none; 11.1 adds none.

### 0.7 Screen roster (AC1 completeness checklist)

| # | Screen | Section | Primary contract |
|---|---|---|---|
| 1 | Tactical HUD | §1 | `TacticalBoardViewModel` + `TacticalLayoutProfile` |
| 2 | Preview / confirm states | §2 | command bridge `move`/`attack` + `TacticalAttackCommitFlow` + preview VMs |
| 3 | Inspect panel | §3 | `TacticalInspectView` + bridge `inspect` |
| 4 | Passive modal | §4 | `PassiveRewardModalViewModel` + `PassiveRewardCommitFlow` |
| 5 | Run map | §5 | `RouteState` / `RouteNode` (no route VM today → Gap G2) |
| 6 | Hero select | §6 | `HeroSelectViewModel` |
| 7 | Outpost / meta menu | §7 | `OutpostViewModel` |
| 8 | Run summary | §8 | `RunSummary` |
| 9 | First-death reveal moment | §9 | `FirstDeathNarrativeBeat` |
| 10 | First-victory reveal moment | §10 | `FirstVictoryRevealBeat` |
| 11 | Manual-seed no-progression warning | §11 | eligibility flags on `RunSummary` / `OutpostViewModel` |
| 12 | Settings | §12 | `SettingsSnapshot` / `SettingsManager` (no settings VM → Gap G4) |
| 13 | Save/resume recovery states | §13 | `SaveManager` → `RunResumeService` + `OutpostViewModel.recovery_state` |
| — | Layout + accessibility pass (all screens) | §14 | `TacticalLayoutProfile` + `TacticalAccessibilityModel` |
| — | Affinity read (supports HUD/inspect, feeds 11.4) | §15 | `AffinityViewModel` + `DarknessReadView` |
| — | Contract-gap ledger | §16 | (AC2 deliverable) |

This roster equals the GDD UI-frame list (`gdd.md` line 599: "hero select, tactical HUD, tile/attack
preview, passive modal, run map, outpost/meta menu, run summary, settings, and save/resume") and FR68
(`epics.md` line 158). Missing any one screen, either reveal beat, or the manual-seed warning = AC1 not
met.

---

## 1. Tactical HUD

### 1.1 Intent

The in-run combat screen: the fog-of-war tactical board dominant, with reachable control bands for the
current turn's actions, the selection/preview state, an inspect affordance, run-status context, and a
log/outcome strip. This is where the player spends the bulk of a descent. Owned for build by **11.3**
(HUD) with visual treatment by **11.4**.

### 1.2 Contract binding (AC2)

Binds to **`TacticalBoardViewModel.to_dictionary()`**
(`godot/scripts/ui/view_models/tactical_board_view_model.gd`), which composes the whole board surface. The
projection's exact top-level keys (a key never silently appears/vanishes):

```
width, height, cells, occupants, selected_cell, selected_entity_id,
preview, commit_flow, inspect, zoom, action_availability,
turn, outcome, event_log_summary, layout, accessibility
```

- **`cells`** — per-cell fog-aware view (`TacticalCellView`) with a `visibility_state`; only visible
  occupants appear in **`occupants`** (the VM filters non-visible / mismatched-occupant entities).
- **`layout`** — the injected `TacticalLayoutProfile.to_dictionary()` slot (see §0.4): `profile_id`,
  `regions` (`board`/`preview`/`confirm_cancel`/`inspect`/`status`/`log_or_outcome`), `control_slots`,
  `minimum_touch_target`, `density`, `spacing`, `board_priority`.
- **`accessibility`** — the injected `TacticalAccessibilityModel.to_dictionary()` slot (see §0.5):
  `cues`, `feedback`, `text_scale`, `color_independent: true`.
- **`action_availability`** — per-action `{enabled, reason}` for `move`/`attack`/`inspect`/`confirm`/
  `cancel`; `confirm`/`cancel` are flow-gated (only enabled when the commit flow arms them).
- **`turn`** — `TacticalTurnState.to_dictionary()` (whose turn, turn number).
- **`event_log_summary`** — ordered recent domain-event summaries for the `log_or_outcome` region.

**Region → contract slot map (11.3 builds these `Control`s; the VM feeds them):**

| Region (`TacticalLayoutProfile`) | Reads from `TacticalBoardViewModel` slot | Renders |
|---|---|---|
| `board` | `width`, `height`, `cells`, `occupants`, `selected_cell`, `zoom` | the fog-aware board grid |
| `preview` | `preview` | the pending move/attack preview (see §2) |
| `confirm_cancel` | `commit_flow`, `action_availability.confirm/cancel` | the two-step commit/cancel buttons (see §2) |
| `inspect` | `inspect`, `action_availability.inspect` | the inspect summary / entry point (see §3) |
| `status` | `turn` + **the run-context HUD (Gap G1)** | whose turn + HP/node/gold/inventory access |
| `log_or_outcome` | `event_log_summary`, `outcome` | recent-events log or the combat outcome banner |

### 1.3 In-run run-context HUD (Contract gap G1)

11.3's HUD must present **run-level context** the tactical board does not carry: **hero HP, node progress
along the route, gold, and inventory/passive access**. `TacticalBoardViewModel` is board + layout +
accessibility only — it exposes **none** of these. This is **Contract gap G1** (§16, owned by 11.3): the
fields exist in the domain (**hero HP** — sourced during a level from the hero `TacticalEntityState` on the
board / `baseline_hp` on the class `StartingKit`; there is **no** run-level HP field on `RunState`, which is
part of why a run-HUD projection is needed; `RouteState.cleared_node_ids` + node count for progress;
`RiskEconomyState.gold`; the run inventory / consumed-passive surfaces) but there is **no single run-HUD
projection** aggregating them for the `status` region. This appendix records the need and the field list;
it does **not** design the aggregating surface. Story 11.3 AC2 requires the HUD present this "per the 11.1
appendix" — the seam is: the HUD `status` region composes the tactical VM's `turn` slot with a G1 run-HUD
read (to be added by 11.3), never by reaching into scene state.

### 1.4 States

- **Active turn** — full board + enabled `move`/`attack`/`inspect` per `action_availability`.
- **Preview pending** — `preview` populated; `confirm_cancel` armed (see §2).
- **Not-player turn** — actions report `enabled: false` with a `reason`; the board still renders.
- **Combat outcome** — `outcome` slot populated (win/loss of the encounter); the `log_or_outcome` region
  shows the outcome banner. (Hero DEATH as a run-ender is 11.2; the HUD renders the outcome the domain
  reports.)
- **Empty/degenerate** — `TacticalBoardViewModel.from_domain(null)` yields an empty VM (zero cells); the
  HUD must render an empty board, not crash. Invalid viewport → `layout.available: false` (fallback
  profile) — the HUD falls back to the portrait stacked plan.

### 1.5 Layout & accessibility

Four-layout per §14. Board dominant on all profiles; the four control bands (`preview`, `confirm_cancel`,
`inspect`, `status`) stay ≥44×44 and reachable (the profile guarantees the board stays the largest region
even on short content areas). Accessibility per §0.5 — every board/preview/inspect cue carries a non-color
channel from the `accessibility.cues` catalog; text respects the `accessibility.text_scale` clamp.

---

## 2. Preview / confirm states

### 2.1 Intent

The tile/attack preview and the **deliberate two-step commit** (GDD 184–190: "deliberate two-step commit
on mobile … Mis-taps are especially punishing"). A first tap PREVIEWS; a second, confirming tap COMMITS.
The preview must be visually distinct from a committed action, and that distinction must survive with audio
muted. Owned for build by **11.3**.

### 2.2 Contract binding (AC2)

**Player intent → command bridge.** Submit intents through **`TacticalCommandBridge.build_command(context,
intent)`** (`godot/scripts/ui/command_bridge/tactical_command_bridge.gd`). Supported `intent_id` values:
`move`, `attack`, `inspect` (any other id → `unsupported_intent`, disabled result). A move intent is
`{intent_id: "move", actor_id, target_cell, movement_budget?}`; an attack intent is `{intent_id: "attack",
actor_id, target_cell, weapon, attacker_support?, defender_support?}`. The bridge validates before
mutation and returns a `CommandBridgeResult` (`command_ready` / `disabled_result` / `metadata_only`); the
scene reads availability, it does not execute directly.

**Preview data (read surfaces):**
- **`TacticalMovementPreview.from_query(...)`** → `{kind:"move", available, reason, target_cell,
  commit_available, cue_ids, metadata:{path, movement_cost, movement_budget, blocked_reason}}`. Cue ids:
  `move_preview_valid`/`move_preview_invalid` + `commit_available`/`commit_unavailable`.
- **`TacticalAttackPreview.from_query(...)`** → `{kind:"attack", available, reason, target_entity_id,
  commit_available, cue_ids, metadata:{weapon_id, targeting_shape, weapon_reach, distance, blocker_state,
  blocker_ignored, expected_base_damage, warnings, effects, explanation}}`. (The preview-VM metadata key
  is `weapon_reach`; `range` is the DISTINCT command-bridge attack-metadata key — do not conflate them.)
  Cue ids include
  `attack_preview_valid`/`_invalid`, `attack_preview_blocked_line`, `attack_preview_blocker_ignored`,
  `attack_preview_adjacent_warning`, `commit_available`/`_unavailable`.
- These land in the tactical VM's `preview` slot (§1.2), normalized by
  `TacticalBoardViewModel._preview_from_options`.

**Two-step commit (attack):** **`TacticalAttackCommitFlow`**
(`godot/scripts/ui/view_models/tactical_attack_commit_flow.gd`). Its `to_dictionary()` state:
`{mode, actor_id, target_cell, target_entity_id, weapon_id, preview, confirm_available, cancel_available,
reason, cue_ids}`. `mode` is `"none"` or `"attack_preview"`. Flow methods:
- `tap_attack_target(...)` — a first tap on a valid target ARMS the preview (`mode: attack_preview`,
  `confirm_available: true`, `reason: "preview_ready"`); a second tap on the SAME target/weapon/actor calls
  `confirm_attack(...)` which builds the intent through the bridge and executes it.
- `cancel()` — clears with ZERO mutation (`reason: "cancelled"`).
- `clear_for_non_attack_tile(...)` / `clear_for_mode_switch(...)` / `refresh_or_clear(...)` — the guarded
  clears when the selection changes.

The `confirm_cancel` region binds to `commit_flow.confirm_available` / `.cancel_available`; the tactical
VM flow-gates `action_availability.confirm`/`cancel` so a confirm button cannot enable without an armed
preview.

> **Move commit note:** the two-step commit-flow view model is attack-specific. A move is committed via a
> `move` bridge intent (validated → executed). If 11.3 wants a symmetric two-step confirm for moves (parity
> with attack), that is a presentation-flow choice for 11.3; the appendix does not add a move commit-flow
> VM (no new surface). Recorded as a design note under G1's owner (11.3), not a blocking gap.

### 2.3 Preview-vs-committed distinction (AC — survives audio muted)

Bind to **`TacticalAccessibilityModel`** feedback cues:
- `feedback_preview` (`CUE_FEEDBACK_PREVIEW`) — channels `[shape, label]`, severity `info`, optional audio
  `audio_feedback_preview`.
- `feedback_committed` (`CUE_FEEDBACK_COMMITTED`) — channels `[pattern, label, text]`, severity `info`,
  optional audio `audio_feedback_committed`.

The channel sets **intentionally differ** (preview = dashed/outline shape + label; committed = solid
pattern + confirming text) so a player tells a previewed action from a committed one **with color
stripped**. The model's `feedback` slot marks `visual_available: true` and carries the channels regardless
of `audio_available`, guaranteeing the distinction holds with audio muted or absent (the audio cue is
additive). 11.3 must render both a preview treatment and a committed treatment using these non-color
channels; audio (if present) rides on top.

### 2.4 States

Preview-ready (armed) / committed (executed, success) / invalid-target (`available: false` + `reason`,
`commit_unavailable`) / cancelled (cleared, no mutation) / blocked-line / blocker-ignored /
adjacent-ranged-warning. Each state is a `reason` + `cue_ids` set already emitted by the preview VMs/flow —
the scene maps them to visuals, it invents no new reasons.

### 2.5 Layout & accessibility

`preview` + `confirm_cancel` regions per §14; ≥44×44 confirm/cancel targets (mis-tap protection is the
whole point). Accessibility per §2.3 — the preview/committed distinction is the load-bearing non-color
requirement for this screen.

---

## 3. Inspect panel

### 3.1 Intent

A read-only tile inspector: what is on/at a tile, whether the player can move/attack there, and any
telegraphed danger — across the fog-of-war visibility tiers. Owned for build by **11.3**.

### 3.2 Contract binding (AC2)

Binds to **`TacticalInspectView.from_context(context, target_cell, options)`**
(`godot/scripts/ui/view_models/tactical_inspect_view.gd`) + the bridge **`inspect`** intent (which returns
`metadata_only` selection data, not a mutation). `to_dictionary()` fields:

```
kind:"inspect", available, reason, target_cell, visibility_state, authoritative,
cell, occupant, movement, attack_preview, hazards, telegraphs, cue_ids, metadata
```

**FR12 field coverage (the inspect must surface):** tile position (`target_cell` / `cell.position`),
terrain (`cell`), occupant (`occupant` — a `TacticalOccupantView`, empty `{}` when not visible or empty),
move cost (`movement.movement_cost` via `TacticalMovementPreview`), attack preview
(`attack_preview.metadata.expected_base_damage` + shape/range via `TacticalAttackPreview`), hazard notes
(`hazards`) and telegraphed danger (`telegraphs` — copied telegraph dicts with `due_turn_number`,
`damage`, `status`).

**Visibility tiers (the three inspect cues):**
- `inspect_visible` (`visibility_state: "visible"`) — authoritative live facts (occupant + previews shown).
- `inspect_memory` (`visibility_state: "memory"`) — remembered (last-seen) facts; occupant suppressed,
  attack preview drops `target_entity_id`. Channel `[pattern, label]` marks it as remembered, not live.
- `inspect_hidden_unexplored` (`visibility_state: "hidden"` / out-of-bounds) — unexplored; `available:
  false`, a base disabled inspect.

Each tier is a cue id already registered in `TacticalAccessibilityModel` with a non-color channel (§0.5),
so the tier reads with color stripped.

### 3.3 States

Visible / memory / hidden-unexplored / out-of-bounds / invalid-context (`available: false`, `reason:
"invalid_context"`). Telegraph overlays: `telegraph_pending` (`[pattern, label]`, warning) vs
`telegraph_due` (`[pattern, label, text]`, danger) vs `danger_damage` (`[icon, label, text]`, danger) —
surfaced when a telegraph marks the inspected cell.

### 3.4 Layout & accessibility

`inspect` region per §14 — a compact band on phone, a wider panel on tablet/desktop. On phone_portrait the
inspect panel may present as a bottom sheet over the board when opened; on desktop it can be a persistent
side panel. Accessibility per §0.5; the memory-tier `pattern` channel and the telegraph `pattern`/`icon`
channels are the load-bearing non-color cues here.

---

## 4. Passive modal (cursed reward)

### 4.1 Intent

The awakened-memory / cursed-reward acceptance modal (FR55: the player must understand the clear
upside AND downside before accepting), with a **deliberate two-step Consume/Destroy commit**. Owned for
build by **11.4** (reward/passive modal visual treatment) / consumed by the run-flow when a reward is
offered.

### 4.2 Contract binding (AC2)

Binds to **`PassiveRewardModalViewModel`**
(`godot/scripts/ui/view_models/passive_reward_modal_view_model.gd`). Pinned **`MODAL_KEYS`** (a key never
silently appears/vanishes):

```
has_passive, passive_id, icon, display_name, flavor, exact_mechanical_effects,
consume_text, destroy_text, has_unknown_consequences, consequences_text
```

- `project_offer(offer, index)` / `project_offer_entry(entry)` / `project_passive(content_id)` all project
  the same `MODAL_KEYS` set; a non-passive/unresolved/out-of-range input fail-closes to `has_passive:
  false` (empty fields).
- **FR55 upside/downside:** `exact_mechanical_effects` (the explicit mechanics) + `consume_text` /
  `destroy_text` (what each choice does) + `has_unknown_consequences` / `consequences_text` (the honest
  "unknown downside" surface) MUST all be shown before the choice is accepted.
- **`icon` is an id/placeholder STRING, not art.** The modal binds the id; 11.4 supplies the actual icon
  asset from the approved Recraft UI-frame + icon kit. Do not treat `icon` as a texture path.

**Two-step commit:** **`PassiveRewardCommitFlow`**
(`godot/scripts/ui/view_models/passive_reward_commit_flow.gd`), mirroring the attack two-step. Its
`to_dictionary()`: `{pending_choice, passive_content_id, table_id, confirm_available, cancel_available}`.
Methods:
- `arm_consume(content_id, table_id)` / `arm_destroy(content_id, table_id)` — a first tap ARMS a pending
  choice (`confirm_available: true`); re-arming switches Consume↔Destroy before confirming.
- `confirm()` — a second tap returns the COMMIT-INTENT `{committed: true, choice, passive_content_id,
  table_id}` and clears. (The actual `ConsumePassiveCommand` / `DestroyPassiveCommand` execution is driven
  by the run-flow caller downstream — the flow produces the intent, not the command.)
- `cancel()` — clears, ZERO mutation (`reason: "cancelled"`).
- `dismiss()` — the no-op dismiss (`reason: "dismissed"`); dismissing without choosing executes no command.

### 4.3 States

No-offer (`has_passive: false` → the modal does not present) / offer-present-unarmed / armed-consume /
armed-destroy / committed / cancelled / dismissed. The three-choice offer (`project_offer` at indices 0..2)
presents three passive cards; arming targets one.

### 4.4 Layout & accessibility

Modal centered over the current screen; on phone_portrait it is a full-width sheet, on tablet/desktop a
centered dialog with wider text columns for the mechanical-effects + consequences copy. Consume/Destroy
buttons ≥44×44 with distinct non-color treatment (label + icon; not color-only) — the upside/downside
distinction must read with color stripped (NFR9). Text respects the `TacticalTextScale` clamp — the
mechanical-effects + consequences copy is the longest text on any screen, so scalable text matters most
here.

---

## 5. Run map

### 5.1 Intent

The forward-only route graph: the current node, the revealed reachable choices with their tradeoff clues,
and cleared history. The player chooses the next node here (risk/reward routing). Owned for build by
**11.3**.

### 5.2 Contract binding (AC2)

Binds to the route READ surface **`RouteState`** (`godot/scripts/run/route_state.gd`) + **`RouteNode`**
(`godot/scripts/run/route_node.gd`) directly — **there is no dedicated route VIEW model today**
(**Contract gap G2**, §16, owned by 11.3; a thin route projection MAY be added by the owning story — this
appendix does NOT design one).

Read methods/fields the map binds to:
- `RouteState.current_node_id`, `RouteState.cleared_node_ids`, `RouteState.nodes()`,
  `RouteState.node_by_id(id)`.
- `RouteState.eligible_choice_ids()` — the SELECTION-legal next choices (known + `REVEAL_REVEALED` + not
  cleared). This is the set the map presents as pickable. (`available_choice_ids()` is the looser
  4.1-pinned derivation that surfaces hidden linked nodes by design — the map presents `eligible_*`, not
  `available_*`.)
- `RouteNode.type` — node types from the pinned vocabulary `RouteNode.TYPE_*`: `combat`, `elite_combat`,
  `shop`, `reforge`, `gambling`, `event`, `secret`, `boss`.
- `RouteNode.reveal_state` — `REVEAL_HIDDEN` / `REVEAL_REVEALED` / `REVEAL_CLEARED`.
- `RouteNode.depth`, `RouteNode.outgoing_link_ids`, `RouteNode.clues` — the tradeoff-clue tags
  (`CLUE_SAFER_COMBAT`, `CLUE_STRONGER_REWARD`, `CLUE_UNKNOWN_RISK`, `CLUE_RECOVERY`, `CLUE_ELITE_PRESSURE`,
  `CLUE_MYSTERY`) shown on revealed choices.

The commit of a chosen node is a route-advance command (existing domain command) submitted by the run-flow;
the map presents choices and reports the pick — it owns no route truth.

### 5.3 States

Parked-with-choices (current node set, ≥1 eligible choice) / hidden-linked (a linked node still
`REVEAL_HIDDEN` — shown as an unrevealed slot, not pickable) / cleared-node (history, `REVEAL_CLEARED`) /
boss-ahead (`TYPE_BOSS` node revealed) / no-choices (`current_node_id` empty or no eligible links —
terminal or awaiting resolution). Node-type and reveal-state must each carry a non-color channel (icon +
label per node type; pattern/label for reveal state) so the map reads with color stripped.

### 5.4 Layout & accessibility

The route graph scales across profiles: a vertical scrollable column of depth-ordered nodes on
phone_portrait; a wider branching layout on tablet/desktop. Node touch targets ≥44×44. Node type conveyed
by **icon + label** (not color-only); reveal state by **pattern + label** (revealed vs hidden vs cleared);
clue tags as text/icon chips. Text respects the `TacticalTextScale` clamp.

---

## 6. Hero select

### 6.1 Intent

The class picker: the roster with locked classes greyed-out + an unlock hint, and a confirm that starts a
run only for a selectable class. Owned for build by **11.3** (or the boot-flow scene owner).

### 6.2 Contract binding (AC2)

Binds to **`HeroSelectViewModel`** (`godot/scripts/ui/view_models/hero_select_view_model.gd`). Pinned
per-entry **`ENTRY_KEYS`**:

```
class_id, display_name, selectable, unlock_hint
```

- `classes()` → the roster (one entry per class in `ClassRepository.class_ids()` order: `warrior`,
  `pyromancer`, `ranger`, `necromancer`, `shadeblade` baseline). `selectable` is
  `ClassDefinition.is_selectable()`; `unlock_hint` is non-empty for locked classes, empty for selectable
  ones.
- `is_class_selectable(class_id)` → the fail-closed confirm pre-gate (unknown → false, locked → false,
  selectable → true). The screen uses this to grey out + block a locked/unknown class.
- `selectable_class_ids()` / `locked_class_ids()` → convenience partitions.

**The authoritative gate is `RunStartCommand`** (via `RunOrchestrator.start`): a mis-enabled confirm button
CANNOT start a locked run because the command re-validates the class fail-closed. The screen's grey-out is a
UX affordance layered on top of the authoritative gate — never the only gate.

### 6.3 States

Roster-loaded (mixed selectable/locked) / class-selected (a selectable class highlighted, confirm enabled)
/ locked-class-focused (greyed-out card + `unlock_hint` shown, confirm disabled) / confirm→start (hands a
selected `class_id` to the start seam). A locked card must be distinguishable from a selectable one WITHOUT
color (greyed treatment carries a `label`/`icon` "locked" marker + the `unlock_hint` text, not color
alone).

### 6.4 Layout & accessibility

Class cards in a grid/list scaling by profile: a single-column list on phone_portrait, a multi-column grid
on tablet/desktop. Cards ≥44×44. Locked state via label/icon + hint text (not color-only). `unlock_hint`
and `display_name` respect the `TacticalTextScale` clamp.

---

## 7. Outpost / meta menu

### 7.1 Intent

The between-run hub: the aggregated cross-run meta readout, the four named GDD spaces (all `deferred` in
v0), the just-ended run summary + first-death beat embedded, the recovery surface, and the
start-another-descent affordance. Owned for build by **11.5** (outpost scene + navigation).

### 7.2 Contract binding (AC2)

Binds to **`OutpostViewModel.to_dictionary()`** (`godot/scripts/ui/view_models/outpost_view_model.gd`).
Pinned **`DICTIONARY_KEYS`**:

```
has_profile, recovery_state, oath_shards, echoes, unlock_progress, class_mastery,
first_death_recorded, run_summary, class_options, selectable_class_ids,
named_spaces, first_death_beat, can_start_run
```

- **Meta readout — read from the PROFILE (source truth), not the run summary:** `oath_shards` (the AWARDED
  cross-run total, `== profile.oath_shards`), `echoes`, `unlock_progress` (Seal-Fragment set + threshold
  flags), `class_mastery`, `first_death_recorded`. A fresh/recovery profile → `has_profile: false`, `0`
  Oath Shards, empty homes (still a valid surface).
- **Four named spaces** (`named_spaces`, pinned `NAMED_SPACE_KEYS = space_id, display_name, status,
  maps_to`): `memory_archive` (→ echoes_and_codex), `hall_of_oaths` (→ oath_shards_and_class_mastery),
  `seal_table` (→ seal_fragments_and_unlock_progress), `descent_stair` (→ start_another_descent). **All four
  carry `status: "deferred"` in v0** — the outpost must render each space with an explicit "deferred" marker
  (the visible-exception discipline), never silently omit them. Only `descent_stair` maps to a live v0
  affordance (start-another-descent); the other three are display/deferred placeholders. Do NOT invent
  additional spaces.
- **Embedded sub-dicts:** `run_summary` (the just-ended run's `RunSummary.to_dictionary()`, or the
  fail-closed empty summary — its own `has_summary` gate; see §8) and `first_death_beat` (the
  `FirstDeathNarrativeBeat.to_dictionary()`, or the fail-closed empty beat — its own `has_beat` gate; see
  §9).
- **Start-another-descent seam (AC3):** `start_run_request(root_seed, is_manual_seed?, class_id?)` → pinned
  `START_REQUEST_KEYS = {root_seed (decimal-string int64), is_manual_seed, class_id, is_startable}`. The
  outpost produces a REQUEST value; the CALLER (11.5's boot/HUD layer) hands it to a FRESH
  `RunOrchestrator.start(...)` / `RunStartCommand` (the authoritative fail-closed start). The prior run is
  NOT reused (a new seed → a new route → a new run, by construction). `can_start_run()` reports whether a
  start is possible (always true in v0 — an empty class id is a startable no-class start).
- **Recovery surface:** `recovery_state` (see §13).

### 7.3 States

Returning-with-progress (`has_profile: true`, real totals) / fresh-profile (`has_profile: false`, 0/empty
— brand-new or recovered) / just-ended-run (`run_summary.has_summary: true` rendered) / no-just-ended-run
(fresh session, empty summary) / first-death-beat-present (rendered alongside, off critical path — see §9)
/ recovery-active (`recovery_state.has_recovery: true` — see §13) / ready-to-descend (`can_start_run`).

### 7.4 Layout & accessibility

Hub layout scales: a scrollable stack (meta readout → named spaces → run summary → descend button) on
phone_portrait; a multi-panel dashboard on tablet/desktop. Deferred spaces carry a label/icon "coming soon"
marker (not color-only). Descend affordance ≥44×44. Meta counts (Oath Shards, echoes) shown as
number + label. Text respects the `TacticalTextScale` clamp.

---

## 8. Run summary

### 8.1 Intent

The "review what happened" screen shown at run end: cause of death or victory, nodes cleared, boss/elite
progress, passives consumed/destroyed, notable loot, economy, seed, and the manual-seed flag (FR60). Owned
for build by **11.5** (rendered within/alongside the outpost).

### 8.2 Contract binding (AC2)

Binds to **`RunSummary.to_dictionary()`** (`godot/scripts/run/run_summary.gd`). Pinned top-level
**`DICTIONARY_KEYS`**:

```
has_summary, phase, outcome_or_cause, seed, is_manual_seed, meta_progression_eligible,
run_scoped, profile_meta, content_unlock, not_yet_supported
```

- **Cause of death/victory:** `outcome_or_cause` (a completion outcome e.g. `completed`/`victory`/
  `boss_placeholder`, OR a failure cause e.g. `hero_death`) + `phase` (`completed`/`failed`).
- **`run_scoped`** (pinned `RUN_SCOPED_KEYS`): `nodes_cleared`, `boss_cleared`, `elite_nodes_cleared`,
  `passives_consumed`, `passives_destroyed`, `notable_loot`, `gold`, `curse_count`, `corruption`. Covers
  the FR60 GDD field list (nodes/boss/elite progress, passives consumed & destroyed, notable loot,
  gold/curse/corruption economy).
- **`seed`** (decimal-string-encoded int64 — JSON doubles truncate beyond 2^53) + **`is_manual_seed`** +
  **`meta_progression_eligible`** — the seed and the manual-seed no-progression flag (see §11).
- **`content_unlock`** (pinned `CONTENT_UNLOCK_KEYS`): `echoes_discovered`, `unlock_progress` (derived from
  `content_discovered` events; reported for both eligible and manual-seed runs — the summary REPORTS
  discovery; the merge command GRANTS it).
- **`profile_meta`** (pinned `PROFILE_META_KEYS`): `oath_shards_earned` — **stays `0` / named in
  `not_yet_supported`** (see G3).
- **`not_yet_supported`**: names `oath_shards_earned` — the honest machine-detectable limitation the
  summary surfaces (10.7's readiness pass enumerates it).

### 8.3 "Oath Shards earned" display (Contract gap G3)

`RunSummary.profile_meta.oath_shards_earned` reports `0` and is named in `not_yet_supported` — the AWARDED
total lives on the profile (`profile.oath_shards`, surfaced via `OutpostViewModel.oath_shards`, §7). **The
coupling decision — display the awarded total ON the run summary vs surface it via the outpost — is a
deliberate deferral (carried Epic-8 T5 / Epic-9 T4), owned by Story 11.5 AC4.** This appendix DOCUMENTS both
display options and flags the decision; it does **not** resolve it (**Contract gap G3**, §16):
- Option A: the run-summary screen reads `oath_shards_earned` and shows an honest "not yet tallied" note
  (the current `0`/`not_yet_supported` truth).
- Option B: the run-summary screen reads the awarded delta via the outpost/profile (a cross-surface read
  11.5 wires).

### 8.4 States

Victory-summary (`phase: completed`, a completion `outcome_or_cause`) / death-summary (`phase: failed`, a
failure `outcome_or_cause`) / manual-seed-run (`is_manual_seed: true`, `meta_progression_eligible: false` —
the §11 warning shown) / empty (`has_summary: false` — the fail-closed empty projection, shown when the
outpost opens with no just-ended run; the summary screen presents nothing rather than a zeroed sheet).

### 8.5 Layout & accessibility

A scrollable results sheet: a single stacked column on phone_portrait; a two-column layout (run-scoped
facts | economy/meta) on tablet/desktop. Outcome (victory vs death) conveyed by label + icon (not
color-only). The manual-seed warning (§11) is a labeled banner, not a color tint. Text respects the
`TacticalTextScale` clamp.

---

## 9. First-death reveal moment

### 9.1 Intent

The optional first-death narrative beat — the line **"Good. You remembered how to die."** (FR61) — shown
once, skippable, and never blocking the run summary / outpost / another descent. Owned for build by
**11.5** (the render).

### 9.2 Contract binding (AC2)

Binds to **`FirstDeathNarrativeBeat`** (`godot/scripts/run/first_death_narrative_beat.gd`). Pinned
**`DICTIONARY_KEYS`**:

```
has_beat, line_id, line, is_skippable
```

`has_beat` gates a present beat; `line` resolves to `"Good. You remembered how to die."` (the const
`FIRST_DEATH_LINE`, resolved from `line_id: "first_death"` via `LINE_BY_ID`); `is_skippable: true` for a
present v0 beat. A null/absent/unresolvable input → the fail-closed empty beat (`has_beat: false`).

### 9.3 Skip/dismiss affordance (AC1) — a pure presentation no-op

**The skip/dismiss is STRUCTURALLY a pure presentation no-op** (FR65). The narrative FLAG is set by a
SEPARATE command (`RecordFirstDeathCommand`, the run-end mutation), independently of this read DTO. So
dismissing the reveal simply stops rendering it — it **mutates nothing** (no reward, no unlock, no
tactical state, no flag). There is no "skip command." 11.5 renders the beat with a clear Skip/Dismiss
affordance; the affordance's only effect is to advance presentation.

**Off the critical path (FR64):** a null/absent/dismissed beat NEVER blocks the run summary, the outpost
surface, or starting another descent. The outpost embeds `first_death_beat` alongside `run_summary` but is
complete without it. Ignoring the lore never blocks understanding the run or continuing.

### 9.4 States

Present-first-death (`has_beat: true`, line shown with Skip) / absent (`has_beat: false` — not rendered,
nothing blocked) / dismissed (presentation stops; nothing mutated).

### 9.5 Layout & accessibility

A skippable overlay/card over the terminal-phase screen, on all four profiles; the Skip/Dismiss control
≥44×44 and always reachable (never off-screen on phone_portrait). The line is text (inherently non-color);
respects the `TacticalTextScale` clamp. No timing/reflex requirement (the reveal waits for the player).

---

## 10. First-victory reveal moment

### 10.1 Intent

The opposite-terminal-phase twin of §9: the optional first-victory reveal — the line **"It did not die. It
learned the way back."** (FR62) — shown once on the first victory, skippable, off the critical path. Owned
for build by **11.5** (the render).

### 10.2 Contract binding (AC2)

Binds to **`FirstVictoryRevealBeat`** (`godot/scripts/run/first_victory_reveal_beat.gd`). Pinned
**`DICTIONARY_KEYS`** (identical shape to §9):

```
has_beat, line_id, line, is_skippable
```

`line` resolves to `"It did not die. It learned the way back."` (the const `FIRST_VICTORY_LINE`, resolved
from `line_id: "first_victory"`); `is_skippable: true` for a present v0 beat; fail-closed empty otherwise.

### 10.3 Skip/dismiss affordance + off-critical-path

Identical posture to §9.3 at the opposite phase: the first-victory FLAG is set by
`RecordFirstVictoryCommand` (separately), so a skip/dismiss is a pure presentation no-op that mutates
nothing (FR65), and the beat NEVER blocks the run summary, the outpost RETURN, the rewards, or another
descent (FR64).

### 10.4 States

Present-first-victory (`has_beat: true`, line shown with Skip) / absent (`has_beat: false`) / dismissed
(presentation stops; nothing mutated).

### 10.5 Layout & accessibility

Same as §9.5 — a skippable overlay over the victory-terminal screen, Skip control ≥44×44 and reachable,
text-based line respecting the `TacticalTextScale` clamp, no timing requirement.

---

## 11. Manual-seed no-progression warning surface

### 11.1 Intent

A readout that warns the player a manual/debug-seed run earns **no meta progression** (FR28), rendered
where the run's eligibility is visible: on the run summary and at the outpost. Owned for build by **11.5**
(run summary + outpost render).

### 11.2 Contract binding (AC2) — a readout of EXISTING flags, no new field

Binds to eligibility flags ALREADY carried on the read surfaces — **it adds NO new field** (FR28):
- **`RunSummary.is_manual_seed`** + **`RunSummary.meta_progression_eligible`** (§8.2) — a manual-seed run
  reports `is_manual_seed: true`, `meta_progression_eligible: false` (lockstep).
- **`OutpostViewModel.start_run_request(...).is_manual_seed`** (§7.2) — a start request carries the
  manual-seed flag; a manual-seed start → `meta_progression_eligible == false` via the existing lockstep.

The warning is purely a PRESENTATION READOUT of these flags. When `is_manual_seed` is true (and thus
`meta_progression_eligible` is false), the run summary shows a "manual seed — no meta progression earned"
banner, and the outpost's start-another-descent affordance surfaces the same warning if a manual seed is
being used. No new domain surface, no new flag, no new command.

### 11.3 States

Manual-seed-active (warning shown on run summary + outpost start) / normal-seed (no warning). The warning is
a labeled banner (text + icon), not a color-only cue.

### 11.4 Layout & accessibility

The banner sits within the run-summary sheet (§8.5) and near the outpost descend affordance (§7.4), on all
profiles. It is text + icon (non-color); respects the `TacticalTextScale` clamp.

---

## 12. Settings

### 12.1 Intent

The player-preferences screen: text scale, audio volume/mute, input preference, and the two accessibility
toggles. **No selectable difficulty ladder** (the ratified non-goal). Owned for build by the settings-scene
owner (**11.3 or 11.5** per the eventual scene split).

### 12.2 Contract binding (AC2)

Binds to **`SettingsSnapshot`** (`godot/scripts/settings/settings_snapshot.gd`) via **`SettingsManager`**
(the autoload) → `SettingsApplyService` / `SettingsRepository`. **There is NO dedicated settings VIEW
model** (**Contract gap G4**, §16, owned by the settings-scene owner; the scene reads the snapshot
directly, or the owning story adds a thin projection — this appendix does NOT design one).

Pinned preference surface — **`SettingsSnapshot.PREFERENCE_KEYS`**:

```
text_scale, master_volume_db, audio_muted, input_scheme, colorblind_safe, high_contrast
```

- `text_scale` — clamped by `TacticalTextScale` to `[0.85, 2.0]` (feeds the scalable-text contract, §0.5).
- `master_volume_db` — bounded `[-60.0, 0.0]` dB (0 = unity); `audio_muted` — bool.
- `input_scheme` — one of `auto` / `touch` / `mouse_keyboard` (`INPUT_SCHEMES`; unknown → `auto`).
- `colorblind_safe`, `high_contrast` — presentation HINTS the presenter maps to the §0.5 cue layer
  (settings stores the boolean; it does NOT own the cue catalog).

`SettingsSnapshot.SCHEMA_VERSION == 1`; the scene reads/writes the snapshot through `SettingsManager`, never
a parallel settings store. A change never alters gameplay (the difficulty-non-goal + text-scale
"no-gameplay-rule-changes" guarantees).

### 12.3 Difficulty NON-GOAL guardrail (negative readiness criterion)

**Sealsworn ships NO player-selectable difficulty ladder in MVP** (`gdd.md` 397–405; the readiness report's
negative criterion; `SettingsSnapshot` carries no difficulty key and a regression test enforces the
absence). MVP difficulty comes from run depth, enemy patterns, affinity pressure, elite nodes, risk
rewards, resource attrition, and boss preparation — never a generic difficulty knob. **The settings screen
MUST NOT present a difficulty selector.** Post-MVP challenge is explicit variant content / trials / oaths,
not a slider.

### 12.4 States

Loaded (defaults or persisted) / edited-unsaved (if the scene batches) / applied (persisted through
`SettingsManager`). Malformed persisted file → the snapshot's lenient parse defaults each field (only a
schema-version mismatch hard-fails to `unsupported_settings_schema`); the screen shows defaults, not a
crash.

### 12.5 Layout & accessibility

A settings list scaling by profile (single column on phone; a wider form on desktop). Controls ≥44×44
(sliders, toggles). Every control labeled (text, not color-only); toggles carry an on/off label + icon.
Ironically self-referential: the `text_scale` and `colorblind_safe`/`high_contrast` controls here are what
drive §0.5 everywhere else — so the settings screen must itself honor the current scale.

---

## 13. Save/resume recovery states

### 13.1 Intent

The between-level resume flow and the structured recovery states the screens must render when a save/profile
is missing, corrupt, or on an unsupported schema — so a bad save degrades gracefully, never silently loses
progress, and resumed play matches uninterrupted play (NFR13). Owned for build by **11.3** (run resume path)
/ **11.5** (outpost recovery surface).

### 13.2 Contract binding (AC2)

**Run save/resume path:** **`SaveManager`** route delegators (`godot/scripts/autoloads/save_manager.gd`) →
**`RunResumeService`**:
- `SaveManager.resume_run(save_path)` → `RunResumeService.new().resume(save_path)` (between-level resume).
- `SaveManager.resume_route_position(save_path)` → `RunResumeService.new().resume_route_position(save_path)`
  (between-node route-position resume).
- `SaveManager.autosave_route_position(snapshot, save_path)` / `autosave_between_level(...)` — the autosave
  entry points (thin delegation to the repository's atomic write).

Resume returns a **structured `ActionResult`** — a code, not an exception. The recovery states the screens
must render map to these codes: **`save_not_found`**, **`save_open_failed`**, **`save_parse_failed`**,
**`unsupported_save_schema`**, **`invalid_tactical_snapshot`** (also `missing_tactical_snapshot`),
**`invalid_rng_snapshot`**. On failure NO partial state becomes active (the restore exposes zero restored
objects — the "no partial corrupt state" guarantee). A parse-failure path emits one expected
`ERROR: Parse JSON failed` line to stderr and still returns a structured error — the screen treats the
`ActionResult` code as truth, not stderr.

**Profile recovery surface (outpost):** **`OutpostViewModel.recovery_state`** (§7.2), pinned
**`RECOVERY_STATE_KEYS`**:

```
has_recovery, code, is_recoverable
```

- `has_recovery: false` for a healthy real/fresh profile.
- A recovery surface carries the structured `code` (`unsupported_profile_schema`, or a `profile_save_*`
  write-failure code) + `is_recoverable` (always `true` in v0 — every recovery path has a fresh-profile
  fallback or retry).
- **The two profile-recovery modes the screen must distinguish** (`OutpostViewModel.for_recovery(...)`):
  1. **Profile-LOAD failure** (`profile_not_found` / `unsupported_profile_schema`): no valid loaded
     profile → the surface falls back to `ProfileSnapshot.fresh()` (`has_profile: false`, 0 Oath Shards,
     empty homes) — the honest **fresh-profile fallback**. The screen shows a fresh 0-shard outpost with a
     recovery note.
  2. **Profile-WRITE failure** (`profile_save_*`): the profile was READ fine and the player accumulated
     REAL progress this session; only the WRITE failed → the caller passes the intact loaded profile so the
     surface shows the player's **REAL totals BEHIND a retry banner** (`has_profile: true`), NOT a
     misleading 0-shard surface. The screen shows real totals + a "save failed — retry" affordance.

### 13.3 States

Resume-success (run rebuilt; play continues) / save-not-found (`save_not_found` — no autosave; offer a
fresh start) / save-corrupt (`save_parse_failed` / `invalid_tactical_snapshot` / `invalid_rng_snapshot` —
report + offer fresh start, no partial load) / unsupported-schema (`unsupported_save_schema` — build too
new/old for the save) / profile-load-recovery (fresh-profile fallback, mode 1) / profile-write-recovery
(real totals behind retry banner, mode 2). Each state is a structured code the screen maps to a clear
message + a recovery affordance.

### 13.4 The resume invariant (NFR13) the screens must respect

Resumed outcomes must match uninterrupted play. The resume/restore path consumes NO RNG, executes NO
command, advances NO turn, and mutates neither the source state nor the save file (the snapshot-purity
contract). A recovery screen may present a message and a retry/fresh-start choice, but it must not itself
perturb the restored run — it renders the `ActionResult` and offers the choice; the domain does the restore.

### 13.5 Layout & accessibility

Recovery states present as a clear message + action (retry / start fresh) on all four profiles; the action
buttons ≥44×44. Each state carries a text explanation + an icon (not color-only) so "save not found" reads
differently from "save corrupt" without relying on color. Text respects the `TacticalTextScale` clamp.

---

## 14. Layout + accessibility coverage pass (ALL screens — AC3)

This section states the four-layout + accessibility treatment that EVERY screen section above inherits
(each section calls out only its deviations/specifics). It satisfies AC3 for every screen at once, grounded
in `TacticalLayoutProfile` + `TacticalAccessibilityModel` + `TacticalTextScale`.

### 14.1 The four-layout treatment (FR66, NFR7)

For **every** screen:

- **`phone_portrait` (primary).** Stacked layout: the primary content region dominant on top, control bands
  beneath along the lower (thumb-reachable) edge (`TacticalLayoutProfile._build_stacked_layout`). For the
  tactical HUD the board is that dominant region; for other screens the equivalent primary region (route
  graph, class grid, summary sheet, meta readout) dominates. Compact density (8px spacing). **Primary
  actions stay reachable at ≥44×44** on this compact profile.
- **`phone_landscape` (same experience, more width).** Side-rail layout: the primary region on the left,
  controls relocated to a right-side rail (`_build_side_rail_layout`) so panels do not consume full width
  and the primary region stays central/left. NOT a separate mode — the same tactical experience with more
  space (`gdd.md` 558–575). Compact density.
- **`tablet`.** Stacked layout at comfortable density (12px spacing) with the optional `log_or_outcome`
  strip; wider panels than phone.
- **`desktop`.** Comfortable density, wider panels, mouse/keyboard parity; the primary region stays the
  dominant/readable region.

**Invariant across all four:** the primary content region stays the dominant, readable region; primary
actions stay reachable at ≥44×44 on the compact (phone) profiles; orientation changes never alter rules;
scenes honor the semantic `TacticalLayoutProfile` region plan (the testable source of truth) rather than
re-deriving geometry. The invalid-viewport fallback (`available: false` → portrait stacked) applies to
every screen.

### 14.2 Color-independence + scalable text (NFR8, NFR9)

For **every** screen:

- **Color-independence.** Every critical meaning carries at least one non-color channel from the
  `TacticalAccessibilityModel` vocabulary (`shape`, `icon`, `label`, `pattern`, `text`). Concretely across
  the roster: preview-vs-committed (§2.3, shape vs pattern+text), inspect visibility tiers (§3.2,
  label/pattern), telegraph danger (§3.3, pattern/icon+text), node type + reveal state (§5, icon/label +
  pattern/label), locked class (§6, label/icon + hint text), deferred outpost spaces (§7, label/icon),
  victory-vs-death (§8, label/icon), manual-seed warning (§11, text+icon), settings toggles (§12,
  label+icon), recovery states (§13, text+icon). Color is additive only — never the sole signal. The
  `color_independent: true` flag on the accessibility slot + the model's `has_non_color_channel` audit
  guarantee each registered cue carries a redundant channel.
- **Scalable text.** Every screen respects the `TacticalTextScale` clamp `[0.85, 2.0]` (default `1.0`),
  driven by `SettingsSnapshot.text_scale` (§12). Labels + icons are used where a raw glyph would be
  ambiguous. The clamp's presenter hints (`label_scale_hint`, `spacing_hint`, `minimum_label_height`) keep
  labels readable and non-overlapping without the contract constructing fonts. Changing the scale never
  alters gameplay.

### 14.3 Visual-treatment baseline (references for 11.4 — NOT authored here)

The appendix references, as the visual-treatment baseline the later stories (esp. 11.4) apply — it authors
no new art:

- **Approved affinity treatments** already merged to `main`:
  `godot/assets/tiles/affinities/affinity.scorched.png`, `affinity.flooded.png`, `affinity.cursed.png`,
  `affinity.darkness.png` (all four present in the repo). These are the board-affinity visual baseline the
  HUD/inspect affinity read (§15) surfaces.
- **The Recraft UI-frame kit** (button / panel / modal) already merged to `main` — the frame baseline for
  the passive modal (§4), the outpost (§7), and the run summary (§8).

11.4 applies these to the scenes 11.3/11.5 build; the appendix only pins them as the treatment baseline and
the `visual_tags` / `icon`-id hooks the view models already expose (§4, §15). No new art, no new asset, is
designed here.

---

## 15. Affinity read (supports HUD + inspect; feeds 11.4)

### 15.1 Intent

The affinity badge / inspect surface that communicates a level's affinity (a failed containment protocol)
and, for Darkness, its reduced-visibility + uncertain-memory effect — as READ-ONLY descriptive data. This
supports the HUD (§1) and inspect (§3) and feeds 11.4's visual treatment. Owned for build by **11.4**.

### 15.2 Contract binding (AC2)

- **`AffinityViewModel`** (`godot/scripts/ui/view_models/affinity_view_model.gd`). Pinned **`MODAL_KEYS`**:
  `has_affinity, affinity_id, display_name, explanation, is_neutral, tactical_rules, visual_tags`. Each
  entry in `tactical_rules` is pinned by **`RULE_KEYS = rule_id, description`** — **RECORD-ONLY descriptive
  data, NOT executed** (the effects live in 7.5/7.6). `visual_tags` are the art/cue hooks 11.4 binds. A null
  input → `has_affinity: false` (fail-closed).
- **`DarknessReadView`** (`godot/scripts/ui/view_models/darkness_read_view.gd`). Pinned **`MODAL_KEYS`**:
  `has_darkness, affinity_id, baseline_radius, reduced_radius, memory_uncertain, explanation, cue_ids`. For
  a Darkness level: the reduced LoS radius + baseline (so the reduction reads as a delta),
  `memory_uncertain: true`, the honest GDD-guardrail explanation ("creates uncertainty, never an unavoidable
  ambush"), and the two FINAL non-color cue ids (`affinity_darkness_reduced_visibility`,
  `affinity_darkness_memory_uncertain`). A non-Darkness affinity → the legal no-Darkness-effect projection
  (`has_darkness: false`, `reduced_radius == baseline_radius`, empty `cue_ids`).

### 15.3 States + accessibility

Neutral (`is_neutral: true` / `has_darkness: false`) / Scorched-Flooded-Cursed (`tactical_rules` +
`visual_tags` shown; the affinity danger cues `affinity_scorched_hazard`, `affinity_pathing_pressure` etc.
each carry a non-color channel per §0.5) / Darkness (`has_darkness: true`, reduced radius + memory
uncertainty shown via the two final non-color cues). Every affinity's critical danger information is
non-color (icon/label/text or pattern/label) — the affinity read is a core NFR9 surface. Four-layout per
§14 (a compact badge on phone, a fuller panel on desktop/inspect).

---

## 16. Contract Gaps (AC2 deliverable — record, do not resolve)

Every `Contract gap → <owning story>` note consolidated. These keep scope explicit: the owning stories
implement them; **11.1 records them and resolves none**. G1–G4 are the seed list from the story Dev Notes
(known from the codebase + deferred-work ledger); no further gaps were found during authoring (the roster's
other screens all bind cleanly to existing pinned surfaces).

| Gap | What it is | Screen(s) affected | Owning story |
|---|---|---|---|
| **G1** | **In-run HUD run context.** Hero HP, node progress along the route, gold, and inventory/passive access are NOT on `TacticalBoardViewModel` (board + layout + accessibility only). No single run-HUD projection aggregates them for the HUD `status` region. Fields needed: hero HP (sourced during a level from the hero `TacticalEntityState` on the board / `baseline_hp` on the class `StartingKit`; there is NO run-level HP field on `RunState`), node progress (`RouteState.cleared_node_ids` + node count), gold (`RiskEconomyState.gold`), inventory/passive access (run inventory / consumed-passive surfaces). Record the need + fields; do not design the surface. | Tactical HUD (§1) | **11.3** |
| **G2** | **Route/run-map view model.** No dedicated route VIEW model exists; the run map reads `RouteState` / `RouteNode` directly today. A thin route projection MAY be added by the owning story. Do not design a new route VM here. | Run map (§5) | **11.3** |
| **G3** | **"Oath Shards earned" summary↔profile coupling.** `RunSummary.profile_meta.oath_shards_earned` stays `0` / `not_yet_supported`; the AWARDED total lives on `profile.oath_shards` (surfaced via `OutpostViewModel.oath_shards`). The coupling decision (display the awarded total on the summary vs surface it via the outpost) is a deliberate deferral (Epic-8 T5 / Epic-9 T4). Document both options (§8.3); do not resolve. | Run summary (§8) | **11.5** (AC4) |
| **G4** | **Settings view model.** No settings VIEW model exists; the settings scene reads `SettingsSnapshot` directly (through `SettingsManager`). The owning story reads the snapshot or adds a thin projection. Do not design one here. | Settings (§12) | settings-scene owner (**11.3 or 11.5** per the eventual scene split) |

### 16.1 Non-gaps (recorded so the scene stories do not go looking)

- **No move commit-flow VM.** The two-step commit-flow view model is attack-specific; a move commits via a
  `move` bridge intent. A symmetric move-confirm is a presentation-flow choice for 11.3, not a contract gap
  (see §2.2 note). No new surface is needed.
- **No fail-loud gate/table extension applies to 11.1.** The Epic-9 retro heads-up about "a gate/check will
  fail-loud on the new table" concerns CODE stories that add events / content families / save keys (11.2+
  territory). 11.1 adds no exhaustiveness gate, no `expected_ids` pin, no schema key, no fingerprint — do
  not look for a table to extend here.

---

## 17. Handoff summary

- **11.1 (this story)** designs the run-flow screens on paper: intent, regions, states, exact contract
  bindings, four-layout coverage, and accessibility — all mapped to EXISTING pinned surfaces, inventing no
  domain surface.
- **11.2** builds the live combat loop + hero-death source (the HUD's `outcome` becomes a real run-ender).
- **11.3** builds the run-flow scenes + tactical HUD (resolves G1, G2; possibly G4).
- **11.4** applies the visual treatment (affinity + Recraft UI-frame baseline) to the modal/outpost/summary
  and the affinity read.
- **11.5** builds the outpost scene + the reveal renders (resolves G3; renders the first-death/first-victory
  beats + the manual-seed warning; possibly G4).
- **11.6** completes the run flow per the Epic-11 list.

Every screen here has a settled paper design; the scene stories implement against it, honoring the
semantic `TacticalLayoutProfile` / `TacticalAccessibilityModel` / `TacticalTextScale` contracts as the
testable sources of truth.
