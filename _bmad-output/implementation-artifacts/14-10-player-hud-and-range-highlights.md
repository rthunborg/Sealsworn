# Story 14.10: Player HUD and Range Highlights

Status: review

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a player,
I want a real HUD and move/attack range highlights,
so that I can read my state and plan a turn without decoding debug strings.

## Context & Why This Story Exists

Epic 14 ("Playable & Presentable") is the **second pre-ship backlog epic**, added 2026-07-16 after an agent-driven desktop playtest found the built MVP is **not honestly finishable** and **does not look intentional** (`playtest-sessions/agent-playtest-2026-07-16.md`; `sprint-change-proposal-2026-07-16.md`). Story 14.10 is the **THIRD story of Band 2** ("looks intentional" — presentation), landing after 14.8 (hero-select rebuild, F13) and 14.9 (outpost cleanup, F14), and before 14.11 (UI theme + semantic layout, F15/F16).

It closes findings **F9** and **F10** (`sprint-change-proposal-2026-07-16.md` lines 28-29; scope row line 145):

> **F9 — a debug HUD** (raw `Confirm:false Cancel:false (mode none)`, snake_case cue ids, pipe-separated stat dumps) with **F10 — no affordances** (no range highlights, no turn indicator, no end-turn button).
> Scope row 14.10: "Replace the debug HUD with a styled **player HUD** (HP/gold/bag/turn; **display names, not snake_case ids**) + **move-range + attack-range highlights** + a turn indicator | FR68, FR12, NFR9 | Presentation over `RunHudViewModel`/`TacticalBoardViewModel`; the 16-key board-VM gate held; range highlights read the existing move/attack-preview queries; no domain change."

**This story is PRESENTATION-ONLY over shipped, pinned view-model contracts — it makes NO domain / command / event / RNG / save change and re-pins NOTHING.** It is the same ratified Band-2 shape as 14.9 / 14.8 / 14.5 / 14.3 / 14.2: additive presentation reading pinned VMs, the assertable render decisions in scene-free `RefCounted` seams with pinned key sets, the board presenter verified by construction + the compile guardrail. There is **no vetoable D-decision unique to 14.10** (D1/D2 are 14.1, D3/D6 are 14.5, D4 is 14.4, D5 is 14.7).

### ⭐ THE CRUX — 14.10 REUSES the shipped VMs; it INHERITS 14.3's animation reconciliation; it does NOT do 14.11's theme work (read before Task 1)

Three boundaries define this story. Get them wrong and you will duplicate shipped work or overreach into 14.11:

1. **REUSE the shipped `RunHudViewModel` — do NOT re-implement HUD data.** The in-run HUD run-context (hero HP, gold, node progress, backpack occupancy, selected class id) is ALREADY projected by `RunHudViewModel.from_run(run, board)` (`godot/scripts/ui/view_models/run_hud_view_model.gd`, the pinned 11-key `DICTIONARY_KEYS`, shipped by 11.3). The presenter already calls it in `_status_text()` (`tactical_board_presenter.gd:382-394`). 14.10's job is to render that data as **styled legible elements with human display names**, NOT to re-derive HP/gold/bag. The turn/phase comes from the board VM's existing `turn` slot (`TacticalBoardViewModel` `turn` → `TacticalTurnState.to_dictionary()`). **The 16-key board-VM gate holds: highlights are a SEPARATE read surface, never a new board-VM key** (exactly as `RunHudViewModel` and `LiveAffinityReadModel` compose alongside the board VM, not inside it).

2. **INHERIT 14.3's animation/perf reconciliation (the retro's explicit instruction to this story).** The epic-14 retro (`retro-notes/epic-14.md` §14-3) ruled: *"AC2 introduces the FIRST animation in Epic 14, colliding with the perf rule 'one draw pass per render, never per-frame in `_process`.' Steered to bounded self-terminating tweens / transient overlay nodes + detach-safety guards; **Band-2 HUD work (14.10) should inherit that reconciliation.**"* Concretely: **the range highlights must be computed ONCE per `render()` (on a turn/state change) and drawn in the SAME single board op-list pass — NEVER recomputed in a per-frame `_process` loop.** If you add any animated emphasis (a pulse), it MUST be a **bounded, self-terminating, node-bound tween** on a transient overlay that tolerates a mid-flight grid detach (the 14.3 `_animate_hit`/`_animate_telegraph` pattern + the node-bound-tween slide pattern — a fight-ending grid free must kill the tween before any callback touches a freed node). Static highlights need no tween at all — they ride the one-draw-per-render op list like 14.2's armed-target outline.

3. **14.10 does the STRUCTURAL/SEMANTIC HUD; 14.11 does the visual THEME.** 14.10 replaces the debug string with **real built-in `Control`/`Label`/`Panel`/bar elements + display names + the semantic region plan + non-color channels** — using built-in affordances, NOT the Recraft art kit and NOT a Godot `Theme` (that is 14.11, the same 14.8/14.9 boundary). Do NOT import art, do NOT build StyleBoxes. **Two 13.2 deferrals belong to 14.11, NOT 14.10** (see "Deferred-work overlaps" below): the reward-overlay hardcoded geometry (13.2 R1) and the passive-confirm `display_name` (13.2 R2). Do NOT touch the reward overlay in this story.

### The load-bearing architecture reality (read before Task 1)

The live combat surface is **`godot/scripts/ui/presenters/tactical_board_presenter.gd`** (a `Control` scene-root script of `tactical_board.tscn`). This is the **correct file** — the 14.1 retro flagged that stories mis-named `gameplay_shell_presenter.gd` / `tactical_board_grid.gd`; the live board surface is `tactical_board_presenter.gd`. `tactical_board_grid.gd` is the thin DRAW Control (it just replays an op list); all render/hit-test/routing DECISIONS live in tested `RefCounted` seams — that is where 14.10's new logic goes.

- **The debug HUD to replace** is `_status_text()` (`tactical_board_presenter.gd:382-394`): the pipe-separated `"%s | Node %d/%d | Gold %d | Bag %d/%d | Turn %s | %s"` dump rendered into the `status` region via `_set_region_text("status", ...)` (`render()` line 360). The `Turn %s` field is the raw snake_case phase id (`player_planning`) — an F9 "snake_case ids" leak.
- **The `Confirm:false Cancel:false (mode none)` string** (`_confirm_cancel_text()`, line 432) is **already suppressed on the LIVE path** — `render()` sets `confirm_cancel` to `""` when a session is bound (lines 350-351). The live F9 offenders that REMAIN are the `_status_text` pipe-dump, the `Turn player_planning` snake_case, and the inspect region's raw `Cues: <snake_case list>` (`_inspect_text()`, lines 445-456). Those are 14.10's sweep targets.
- **The board draw** happens in `_build_board_draw_ops()` (`tactical_board_presenter.gd:991-1075`), a single ordered op list replayed once per render. 14.2's armed-target highlight (lines 1057-1065) is the exact pattern to mirror for range highlights: additive outline ops on cell rects, guarded by `_cell_rect` returning a zero-size rect for an unavailable/geometry-less cell (a safe no-op, never a fabricated cell).
- **Discrete HUD controls** are built the 14.1/14.2 way: `_build_wait_control()` (line 696) and `_build_confirm_cancel_controls()` (line 729) build child `Button`/container nodes into a region panel in `_build_regions()` (line 242) and toggle/populate them in `render()`. 14.10 builds its HUD elements the same way (into the `status` region), honoring `custom_minimum_size = Vector2(44, 44)` for any interactive target.
- **The live inputs** are bound by `bind_interactive_session()` (line 556): `_session` (the `InteractiveCombatSession`), `_board = session.board()`, `_turn_state = session.turn_state()`, `_run`. The session also exposes `hero_weapon() -> WeaponDefinition` (line 233) and `HERO_ID` (`:= LiveCombatResolver.HERO_ID`, line 75) — the sources the attack-range highlight needs. **Source the highlights from the bound live session, not empty presenter state** (the 14.3 systemic: render() must read the live session's board/turn/actor, exactly as 14.2 sourced `preview` and 14.3 sourced `event_log_summary` from the session).

## Acceptance Criteria

**AC1 — A styled player HUD with display names, replacing the debug readout (F9; FR68; NFR9)**
Given a live combat node is on screen
When the HUD renders
Then it shows a **styled player HUD** — HP, gold, backpack, and turn/phase as **legible discrete elements** (real `Label`/`Panel`/bar Controls, not a single pipe-joined string), **replacing the debug readout** (no `Confirm:false Cancel:false (mode none)`, no pipe-separated stat dump), and **all cue/label text uses human display names, not snake_case ids** (the turn/phase renders as a human turn label like "Your Turn"/"Enemy Turn", never `player_planning`; any player-facing cue-id list is mapped to human text or removed from the player label — NFR9 non-color text channel throughout)
And it **reads the existing `RunHudViewModel`/`TacticalBoardViewModel`** (the **16-key board VM gate holds** — no new board-VM key; the display names resolve from the projected view models / a `RefCounted` render-decision seam, **not raw domain ids** hand-formatted in the presenter).

**AC2 — Move-range + attack-range highlights + a clear turn indicator (F10; FR12; NFR9)**
Given it is the player's turn
When a unit/action is active
Then the board shows **move-range and attack-range highlights** (reading the **existing** `TacticalMovementQuery` / `AttackPreviewQuery` move/attack-preview queries — **no new query**) and a **clear turn indicator**, each communicated by **shape/pattern/label, not color alone** (NFR9); interactive targets stay **≥44px** and a HUD slot that cannot fit reports `reachable: false` (via the existing `TacticalLayoutProfile` control-slot reachability) **rather than overflowing**
And the **highlights are pure reads** (no domain mutation, no RNG draw, no new query type), computed **once per render** and drawn in the single board op-list pass — **never a per-frame `_process` recompute** (the inherited 14.3 reconciliation).

**AC3 — Pinned-contract posture: no domain change, decisions on `RefCounted` seams, verified by construction**
Given the pinned contracts
When this story lands
Then **no domain command / RNG / save contract changes**, the **HUD/highlight projection logic lives in `RefCounted` seams with pinned key sets** (unit-tested — **no SceneTree presenter test**; the board scene is verified by construction + the `test_run_flow_scenes_load.gd` compile guardrail), and **every pinned fingerprint stays byte-identical** (the 16-key `TacticalBoardViewModel` gate stays 16, the 11-key `RunHudViewModel` gate stays 11, the 23-key `RunSnapshot` gate stays 23, `ProfileSnapshot.SCHEMA_VERSION == 1`, the 7 named RNG streams unchanged, no new event/enum value, no new autoload, no new RNG draw site, no re-pinned combat/generation/route/finale fingerprint)
And **14.10 re-pins NOTHING.**

## Tasks / Subtasks

- [x] **Task 1 — The styled HUD render-decision seam (display names, not snake_case) (AC1, AC3)**
  - [x] Add a scene-free `RefCounted` HUD render-decision seam (`godot/scripts/ui/view_models/tactical_hud_view.gd`, class `TacticalHudView`) — a **pure read** that composes `RunHudViewModel.to_dictionary()` (HP/gold/bag/nodes/class) with the board VM's `turn` slot and **resolves human display names**, exposing a **pinned exact-key set** (`VIEW_KEYS`, 12 keys) and a fail-closed `has_hud`/`has_hp` gate. Keys: `has_hud`, `hp_current`, `hp_max`, `has_hp`, `gold`, `bag_count`, `bag_capacity`, `nodes_cleared`, `nodes_total`, `turn_label`, `turn_is_player`, `class_display_name`. Mints NO event, draws NO RNG, mutates NOTHING, fresh plain-data dict each call.
  - [x] Centralized the **turn-phase → display-name map** as seam consts + `turn_label_for()` (ONE mapping): `player_planning` → "Your Turn", `player_resolving`/`enemy_planning`/`enemy_resolving` → "Enemy Turn", `environment_resolving` → "Hazards Resolving", unknown/empty → the neutral `TURN_LABEL_NONE` ("—"). Reads `turn.phase` (compared to `TacticalTurnState.PHASE_*`); **never renders `player_planning`.**
  - [x] Resolves the class `display_name` via `ClassStartSummaryViewModel.summarize(run).display_name` (the class-repository display-name path) — never the raw `selected_class_id`; empty for an identity-absent run. The affinity badge (`_affinity_badge_text`) is preserved unchanged in the HUD.
  - [x] **Fail-closed:** a null run projects the empty HUD fact (`has_hud == false`, zeroed fields, `TURN_LABEL_NONE`) — the same pinned key set for present and absent (pinned by test).

- [x] **Task 2 — Render the styled HUD into the status region + turn indicator (AC1, AC2)**
  - [x] Replaced `_status_text()`'s pipe-dump with **discrete HUD elements** built into the `status` region panel the 14.1/14.2 way (`_build_hud_controls`): a prominent turn-indicator Label (larger font), an HP Label + a `ProgressBar` (length/shape channel), gold / bag / node Labels, a class Label, the affinity badge Label, and a highlight legend Label. Populated in `render()` from the Task-1 seam via `_populate_hud`. Each a non-color text/shape channel (NFR9).
  - [x] The turn indicator reads the human `turn_label` ("Your Turn" / "Enemy Turn" / "Hazards Resolving") — the F10 "no turn indicator" fix. The 14.1 Wait/End-Turn button is NOT rebuilt; the indicator complements it.
  - [x] **Honors the semantic region plan** — the HUD lives in the `status` control slot; `_status_slot_reachable(layout)` reads the existing `control_slots["status"].reachable` (the `_region_is_reachable` contract). A non-reachable slot degrades to a compact single-line fallback (`_compact_hud_text`) in the base label; the status panel sets `clip_contents = true` so the discrete HUD clips rather than overflowing. No hardcoded geometry.
  - [x] Swept the F9 `Cues: <snake_case list>` leak from `_inspect_text` (dropped the raw cue-id list; kept the meaningful hazard/conductive/pathing danger counts). Bounded to the player-facing inspect label.

- [x] **Task 3 — The range-highlight seam (move-range + attack-range, existing queries only) (AC2, AC3)**
  - [x] Added `godot/scripts/ui/view_models/tactical_range_highlight_view.gd`, class `TacticalRangeHighlightView` — a **pure read** over the live board + actor + weapon + turn. Pinned keys (`VIEW_KEYS`): `has_highlights`, `move_cells` (Array of `{x,y}`), `attack_cells` (Array of `{x,y}`), `reason`. Fresh plain-data dicts. (Dropped the recommended `actor_cell` key — unused by the presenter draw, honoring the 14.3 "seams expose only what the presenter consumes" rule.)
  - [x] **Move-range:** reuses `TacticalMovementQuery.validate_target(board, actor_id, cell, budget)` (`DEFAULT_MOVEMENT_BUDGET == 3`, matching the live move budget) per candidate, collecting the `valid` cells. Candidates pre-filtered to the Manhattan budget window. No new query type.
  - [x] **Attack-range:** reuses `AttackPreviewQuery.preview_target_cell(board, actor_id, occupant_cell, weapon)` over the board occupants, collecting the `legal: true` cells. A corpse returns `dead_target`/`missing_target` and is EXCLUDED (asserted). No new query type.
  - [x] **Fail-closed + turn-gated:** highlights compute ONLY when `turn.phase == player_planning` and the hero is alive; otherwise `has_highlights == false` + empty sets + an honest `reason`. Pure (no mutation, no RNG) — asserted via a pre/post board snapshot compare.
  - [x] Sources the actor id from `InteractiveCombatSession.HERO_ID`, the weapon from `session.hero_weapon()`, the board from `session.board()` (`_range_highlights` in the presenter).

- [x] **Task 4 — Draw the highlights in the single board op-list pass (AC2, NFR9, the 14.3 inheritance)**
  - [x] In `_build_board_draw_ops()`, after composing the Task-3 read ONCE per render, appends **additive SHAPE-distinct ops** (`_range_highlight_ops`): move-range = a single thin inset outline (a ring); attack-range = four L-shaped corner ticks (`_corner_tick_ops`) — distinct from both the move ring and the 14.2 armed double outline. `_cell_rect` zero-size guard skips fog/off-board cells. A HUD legend Label names the two shapes.
  - [x] **Computed once per render, drawn in the SAME single op list** — NO `_process` recompute, NO per-frame redraw. The highlight set is cached in `_last_highlights` so the bounded 14.3 slide-redraw (`_refresh_board_ops`) re-issues the SAME overlay (no recompute). No tween added (static highlights).
  - [x] Draw-only overlay on already-hit-testable cells — adds NO new tap target and does not change cell size (the 13.1 hit-test is unchanged).

- [x] **Task 5 — Seam tests + determinism/save gates held + suite green (AC1, AC2, AC3)**
  - [x] Added scene-free unit tests: `godot/tests/unit/ui/test_tactical_hud_view.gd` and `godot/tests/unit/ui/test_tactical_range_highlight_view.gd` (mirror `test_run_hud_view_model.gd`). Cover: HUD exact key set (present == absent); the turn-phase → display-name map for EVERY `Phase` value + the no-snake_case-leak guard; fail-closed empty on null run; pure-copy no-live-handle; class display-name resolves (non-empty, != raw id). Range: move-range == `TacticalMovementQuery` legal set (budget 3); attack-range == `AttackPreviewQuery` legal set; corpse excluded; empty + reason when not player-turn / hero-dead / null-board; the pre/post board-snapshot no-mutation assertion; exact key set.
  - [x] No eager `String(nullable)` in assert messages (uses `%s`/`String(...)` on non-null values only).
  - [x] The presenter changes are verified **by construction** + the `test_run_flow_scenes_load.gd` compile guardrail (GREEN — it loads `tactical_board.tscn` + compiles `tactical_board_presenter.gd`). No SceneTree presenter test added.
  - [x] **`.gd.uid` discipline:** ran `--headless --import` separately; all four new `*.gd.uid` sidecars generated (the 2 seams + the 2 tests).
  - [x] Confirmed **no domain/RNG/save change**: production files touched = `tactical_board_presenter.gd` + the two new `RefCounted` seams (+ the two new tests). `TacticalBoardViewModel` (16 keys), `RunHudViewModel` (11 keys), `TacticalTurnState`, `TacticalMovementQuery`/`AttackPreviewQuery` (READ-only), `RunSnapshot` (23-key / `SCHEMA_VERSION == 1`), `RngStreamSet` (7 streams), `DomainEvent` — all byte-untouched. No new autoload, event, or RNG draw site.
  - [x] Ran the FULL headless suite: **205 PASS files / 0 FAIL** ("Headless tests passed.", exit 0). False-PASS guard `SCRIPT ERROR|Parse Error|^FAIL` = **0**; exactly the 6 documented stderr negatives (int64-overflow ×2, malformed-JSON ×3, `invalid_node_type` ×1), ZERO new, none referencing a 14.10 file. Both new seam tests GREEN; the compile guardrail GREEN.

## Dev Notes

### The exact files — the 14.1 "wrong files to touch" precision applied to 14.10

The live combat surface is **`godot/scenes/game/tactical_board.tscn`** (a thin `Control`+script scene root) + **`godot/scripts/ui/presenters/tactical_board_presenter.gd`** (the scene-root script — the live board surface, NOT `gameplay_shell_presenter.gd` and NOT `tactical_board_grid.gd`, which is just the op-list DRAW Control). The `.tscn` need not change — the HUD elements + highlights are code-built into the existing region panels / the op list. The new **render/projection DECISIONS live in `RefCounted` seams** under `godot/scripts/ui/view_models/` (the `HeroSelectRenderView`/`OutpostRenderView`/`RunHudViewModel` neighborhood).

### What is ALREADY SHIPPED (reuse, do NOT rebuild)

- **`RunHudViewModel`** (`run_hud_view_model.gd`, 11.3) — the HP/gold/bag/node-progress/class projection. Already called at `tactical_board_presenter._status_text():383`. **Reuse it verbatim for the HUD data.** Its 11-key `DICTIONARY_KEYS` gate stays 11 (do not add a key).
- **`TacticalBoardViewModel.turn`** slot (`tactical_board_view_model.gd:78`) — the turn/phase (from `TacticalTurnState.to_dictionary()`: `turn_number`, `phase` snake_case, `active_actor_id`). Read `turn.phase` and map it to a display name in the new seam. The 16-key board VM `to_dictionary()` gate stays 16.
- **`TacticalMovementQuery.validate_target`** (`tactical_movement_query.gd:17`) — the move-preview query; returns `ActionResult.ok` with `reason: "valid"` for a legal move within budget. Pure read. **The move-range source.**
- **`AttackPreviewQuery.preview_target_cell`** (`attack_preview_query.gd:11`) — the attack-preview query; returns `legal: true` for a legal target, and `dead_target`/`friendly_target`/`out_of_range`/`not_aligned`/`blocked_line`/`not_visible`/`missing_target` for the rejects. Pure read. **The attack-range source.**
- **`TacticalLayoutProfile`** (`tactical_layout_profile.gd`) — the semantic region plan (`board`/`preview`/`confirm_cancel`/`inspect`/`status`/`log_or_outcome`) + the `_control_slot` reachability (`DEFAULT_MINIMUM_TOUCH_TARGET == Vector2(44,44)`, `_region_is_reachable` reports `reachable: false` when a slot is under 44px or outside content). **Honor it; do not re-derive geometry.**
- **`InteractiveCombatSession`** — `board()` (217), `turn_state()` (221), `hero_weapon()` (233), `HERO_ID` (75). **The live sources for the highlights.**
- **The 14.2 armed-target highlight** (`_build_board_draw_ops:1057-1065`) — the exact additive-outline-on-cell-rect pattern to mirror for the range highlights (with the same `_cell_rect` zero-size guard).
- **The 14.1/14.2 discrete-control build pattern** (`_build_wait_control:696`, `_build_confirm_cancel_controls:729`) — the way to build the HUD `Label`/bar elements into the `status` region.

### The range-highlight approach — existing queries only, once per render (AC2 + the 14.3 inheritance)

AC2 is explicit: *"reading the existing move/attack-preview queries"* and *"no new query"*. So the seam **reuses** `TacticalMovementQuery`/`AttackPreviewQuery` per candidate cell to decide legality — it does NOT add a new domain traversal/query type and does NOT do its own BFS. Pre-filtering candidates to the budget/range window is a valid cheapness optimization (the existing query still makes the final legality call). The cost (per-cell query over a small 8×8..14×12 board) is acceptable **because it runs once per `render()` (a turn/state change), not per frame** — which is precisely the 14.3 "one draw pass per render, never per-frame `_process`" rule this story was told to inherit. Draw the resulting cell sets as additive ops in the SAME op list. Do NOT stand up a `_process` loop, a per-frame timer, or a recompute-every-frame path.

### NFR9 — the non-color channel is mandatory (the trap)

Every HUD state and every highlight MUST carry a **shape/pattern/label** channel, never color alone (project-context §14 / NFR9):
- HUD: text labels carry HP `N/M`, gold, `bag N/M`, node `N/M`, and the human turn label — text is a valid non-color channel. The HP bar adds a length/shape channel.
- Move-range vs attack-range: use **two visually distinct outline/pattern SHAPES** (e.g. dashed vs double outline, or edge-tick vs corner-tick) so a colorblind player distinguishes them, plus a short legend/label. Do not rely on "blue = move, red = attack".
- The turn indicator: the word "Your Turn"/"Enemy Turn" is the non-color channel — never a bare color swatch.

### The 14.10 ↔ 14.11 boundary — 14.10 is STRUCTURE + display names, NOT the Theme

**Do NOT import art or build a Godot `Theme` in 14.10.** Story **14.11 (UI Theme and Semantic Layout)** owns: the Recraft UI frame kit (`asset_sources/icons/ui/button_plate.svg`, `panel_frame.svg`, `modal_frame.svg`) + `*.import` sidecars, a Godot `Theme` (StyleBoxes/fonts/spacing) across ALL screens (including this HUD), the full cross-screen semantic layout (board-scales-to-window, resize re-render), AND two folded 13.2 deferrals — the **reward-overlay hardcoded geometry → semantic region plan + scroll** (13.2 R1) and the **passive-confirm `display_name`** (13.2 R2). 14.10 uses **built-in `Control`/`Label`/`Panel`/bar affordances + text labels** (the 14.8/14.9 posture), touches ONLY the live-combat HUD + board highlights, and **does NOT touch the reward overlay** (`_build_generic_reward_ui`/`_build_passive_reward_ui`/`_build_passive_confirm_ui`) — that is 14.11's geometry+display_name work. This keeps 14.10 additive (no `*.import` sidecar; only the two new `.gd.uid` sidecars for the new seams/tests) and prevents a 14.10/14.11 overlap.

### Deferred-work overlaps folded in (only those that touch 14.10's area)

- **The 13.2 R1 "reward overlay hardcoded geometry" defer (`deferred-work.md:97`) — belongs to 14.11, NOT 14.10.** The epics AC for 14.11 explicitly folds it ("the reward-overlay hardcoded geometry is replaced with the semantic region plan + a scroll affordance"). Do NOT touch the reward overlay in 14.10.
- **The 13.2 R2 "passive-confirm renders raw `passive_content_id`" defer (`deferred-work.md:106`) — belongs to 14.11, NOT 14.10.** The epics AC for 14.11 explicitly folds it ("the passive-confirm step renders the evocative `display_name`, not the raw `passive_content_id`"). 14.10's "display names, not snake_case ids" scope is the **HUD/turn-indicator/inspect** labels, NOT the reward/passive modal. Do NOT re-implement the reward modal here.
- **The 13.2 R1 "`_inspect_facts_from` untested presenter transform" defer (`deferred-work.md:98`) — OPTIONAL, default LEAVE DEFERRED.** It sits in the same presenter (`_inspect_facts_from`, the inspect-fact-shape transform). Extracting it into a tiny `RefCounted` seam + test is optional hardening (the "assertable logic in RefCounted seams" rule), owner "a later board-polish / test-hardening pass". If (and only if) you are already refactoring the inspect region for the F9 `Cues:` snake_case sweep, you MAY opportunistically extract it — but it is NOT required by any AC; leave it deferred if in doubt (do not expand scope).
- **The Band-1/2 on-device human-playtest defer (`14-5`/`14-9` `[Review][Defer]`) — EXTENDED by 14.10.** The HUD + highlights are automated-green (seam tests + compile guardrail) but the on-screen legibility, real range-highlight readability, and turn-indicator clarity are human-unverified (no SceneTree test). Add to the on-device playtest checklist: the HUD shows HP/gold/bag/turn as legible non-debug elements; no `player_planning`/snake_case in any player label; move-range and attack-range highlights are visible and distinguishable without color on a physical display; the turn indicator clearly reads whose turn it is; the HUD does not overflow a small viewport.

### Epic-14 constraints inherited (retro-notes/epic-14.md + the sprint change)

- **INHERIT the 14.3 animation/perf reconciliation (the retro's explicit instruction to 14.10):** bounded self-terminating tweens / transient overlays with detach-safety; the node-bound-tween pattern; **one draw pass per render, never per-frame `_process`.** Range highlights are computed once per render, drawn in the single op list; any pulse is a bounded node-bound tween that tolerates a mid-flight grid detach. (§14-3.)
- **Render from the bound session, not empty presenter state (14.3 systemic):** source the HUD (`RunHudViewModel.from_run(_run, _board)`) and the highlights from the LIVE session's board/turn/actor, exactly as 14.2 sourced `preview` and 14.3 sourced `event_log_summary`. A live VM slot must never be sourced from empty presenter state. (§14-3.)
- **Seams expose only what the presenter consumes (14.3):** the new HUD/highlight seams surface only the fields the presenter draws — no forward-looking dead output (re-add fields when a real consumer lands). (§14-3.)
- **EXACT files (14.1 "wrong files" precision):** the live board surface is `tactical_board_presenter.gd` (NOT `gameplay_shell_presenter.gd`/`tactical_board_grid.gd`). (§14-1.)
- **`str(...)` not eager `String(nullable)` in assert messages (14.1);** the false-PASS grep guard stays standing (exactly the 6 documented stderr negatives — int64-overflow ×1 `test_manual_seed_loader.gd:153` + ×1 `test_domain_event.gd:146`, malformed-JSON ×3, `invalid_node_type` ×1). (§14-1/§14-4.)
- **One display-name helper closes all sites (14.6 heuristic):** centralize the turn-phase → display-name map (and any id → display-name) as a single seam const/helper, not scattered presenter literals. (§14-6.)
- **A corpse tap routes to INSPECT, not attack (14.2):** `AttackPreviewQuery` returns `dead_target` for a corpse → excluded from `attack_cells`; do not highlight a corpse as an attack target. (§14-2.)
- **`.gd.uid` via `--headless --import` (14.8):** the `--scene` test run does NOT emit `.gd.uid` for new `.gd` files — run `--headless --import` separately and commit the sidecars. (§14-8.)
- **EPIC-LEVEL RISK (14.4/14.5/14.8/14.9 retro):** Band-2 presentation stories defer their user-facing verification to the pending on-device playtest — 14.10's HUD/highlights are automated-green but human-unverified. Confirm the on-device playtest happens before Band 2 closes. (§14-4.)
- **Difficulty stays a hard non-goal; 14.10 re-pins nothing; no new autoload; the scene is verified by construction + the compile guardrail.**

### Anti-patterns to avoid (this story specifically)

- **Do NOT re-implement the HUD data** — `RunHudViewModel` ships HP/gold/bag/nodes/class; 14.10 renders + display-names it. Do not re-derive HP or read `RunState` HP directly (there is no run-level HP field — that is exactly why `RunHudViewModel` exists; the 11.1 hero-HP-mis-source trap).
- **Do NOT add a board-VM key** — the 16-key `TacticalBoardViewModel.to_dictionary()` gate holds. Highlights + HUD compose as SEPARATE read surfaces (the `RunHudViewModel`/`LiveAffinityReadModel` precedent), never a new board-VM key.
- **Do NOT add a new domain query** — the highlights reuse `TacticalMovementQuery`/`AttackPreviewQuery`. No new BFS, no new traversal, no `_process` recompute.
- **Do NOT render any snake_case id to the player** — `player_planning`, `warrior`, cue ids like `layout_profile_desktop` must map to human display names in the seam, or be dropped from player-facing labels.
- **Do NOT hardcode HUD geometry** — honor the `TacticalLayoutProfile` region plan + control-slot reachability (≥44px, `reachable: false` degrades, never overflows). The full cross-screen layout is 14.11.
- **Do NOT import art or build a Godot `Theme`** — that is 14.11. Built-in `Control`/`Label`/`Panel`/bar + text labels only.
- **Do NOT touch the reward overlay** (`_build_generic_reward_ui`/`_build_passive_*`) — the reward-geometry + passive-confirm display_name are 14.11 (the 13.2 R1/R2 defers).
- **Do NOT add a per-frame `_process` recompute/redraw** — the 14.3 rule; compute once per render, draw in the single op list.
- **Do NOT touch any domain/command/event/RNG/save file** — 14.10 is presentation-only. The 16-key board VM gate, the 11-key HUD gate, the 23-key `RunSnapshot` gate, `SCHEMA_VERSION == 1`, the 7 named streams — all byte-identical. 14.10 re-pins NOTHING.
- **Do NOT rely on color alone** for any HUD state or highlight (NFR9) — text/shape/pattern is the non-color channel.
- **Do NOT add a SceneTree presenter test** — decisions go in the `RefCounted` seams (unit-tested); the presenter is verified by construction + the compile guardrail.
- **Keep the false-PASS grep guard standing** — grep the RAW runner output for `SCRIPT ERROR|Parse Error|^FAIL`; exactly the 6 documented stderr negatives; ZERO new. Never trust the summary PASS line alone.

## Project Structure Notes

- **Files touched (production):** `godot/scripts/ui/presenters/tactical_board_presenter.gd` (replace the `_status_text` pipe-dump with styled discrete HUD elements + the turn indicator; sweep the `Turn <phase>` + inspect `Cues:` snake_case leaks; append the move/attack range-highlight ops in `_build_board_draw_ops`, mirroring the 14.2 armed-target overlay) + **two new `RefCounted` seams** under `godot/scripts/ui/view_models/` (recommended `tactical_hud_view.gd` + `tactical_range_highlight_view.gd`). The board `.tscn` need not change (code-built HUD + op-list draw).
- **Tests:** two new scene-free unit tests under `godot/tests/unit/ui/` (recommended `test_tactical_hud_view.gd` + `test_tactical_range_highlight_view.gd`, mirroring `test_run_hud_view_model.gd`). No new SceneTree test — the board scene stays verified by construction + `godot/tests/unit/ui/test_run_flow_scenes_load.gd` (the compile guardrail that loads the board scene).
- **Assertable render/projection decisions live in the scene-free `RefCounted` seams** (unit-tested); the presenter is thin glue verified by construction (the 14.2/14.3/14.5/14.8/14.9 posture). The two new `.gd` seams + two new `.gd` tests each need their `.gd.uid` sidecar generated + committed via `--headless --import` (the 13.1/14.8 discipline). **14.10 adds no art / no `*.import`.**
- `scripts/tactical/`, `scripts/rules/`, generation/route/finale/combat/save files — all untouched (the queries are READ-only). No domain/command/event/save/RNG change.

## Project Context Rules

Extracted from `project-context.md` (canonical rulebook) and the architecture (`_bmad-output/game-architecture.md`):

- **Domain owns truth; presentation observes + submits commands (NFR14/NFR15; hard architecture rule).** The HUD + highlights are pure reads over the live session's board/turn/run through `RunHudViewModel` + the two new `RefCounted` seams; the UI owns no tactical/run truth and mutates nothing. The board queries (`TacticalMovementQuery`/`AttackPreviewQuery`) are read-only and consume no gameplay RNG (project-context: attack preview emits no events, consumes no gameplay RNG, does not mutate).
- **Save truth = versioned domain snapshots (NFR15).** No save change: the 23-key `RunSnapshot` gate stays 23; `ProfileSnapshot`/`SettingsSnapshot` `SCHEMA_VERSION == 1`; no new field, no serialized presentation state.
- **Named RNG only; deterministic under seed (NFR13).** 14.10 draws ZERO RNG (the seams + queries are pure reads). The 7 named streams (`map, level, combat, loot, rewards, events, cosmetic`) are unchanged, unreordered.
- **Assertable logic lives in scene-free `RefCounted` seams** with pinned exact-key sets (no SceneTree presenter tests — verify by construction + the compile guardrail). No new autoload. Seams expose only what the presenter consumes (the 14.3 rule).
- **Headless simulation must not depend on rendering/UI/scene-tree state (NFR14).** The new seams are RefCounted and headless-testable; the queries they call are already headless.
- **Color-independence (NFR9).** Every HUD state (HP/gold/bag/turn) and every highlight (move-range/attack-range) carries a text/shape/pattern channel, not color alone; the turn indicator is a word label; the two range channels use distinct shapes + a legend.
- **Adaptive UI via view models, presenters, layout profiles, and a command bridge (additional requirement).** The HUD honors the `TacticalLayoutProfile` region plan + control-slot reachability (≥44px, honest `reachable: false`), not hardcoded geometry.
- **Difficulty is a hard non-goal.** 14.10 changes no enemy/HP/damage/reward/run-length number.
- **Every generator/route/finale/combat seed-regression fingerprint stays byte-identical** (14.10 touches only `scripts/ui/`; the board queries are read-only). **14.10 re-pins NOTHING** (including the 14.1-re-pinned combat replay at seed 24680, untouched).
- **Headless suite stays green** (203 PASS baseline post-14.9; expect ≥205 PASS after the 2 new test files; false-PASS grep `SCRIPT ERROR|Parse Error|^FAIL` clean beyond the 6 documented negatives).

### Mandatory test command (must pass before this story moves to review/done)

```
godot --headless --path C:\Sealsworn\godot --scene res://tests/headless/test_runner.tscn --quit-after 10
```

`godot` is not on the Bash/`where` PATH; run via PowerShell (`C:\Users\Rasmus\bin\godot.cmd`, or the standalone `C:/Users/Rasmus/Godot_v4.6.3-stable_win64.exe/Godot_v4.6.3-stable_win64_console.exe`). Apply the false-PASS grep guard `SCRIPT ERROR|Parse Error|^FAIL` on the RAW output (never trust the summary PASS line alone). The runner auto-discovers `test_*.gd` under `res://tests/unit` and `res://tests/integration` only. Baseline **203 PASS files** (post-14.9); expect **≥205 PASS** (2 new seam-test files), ZERO new stderr negatives beyond the 6 documented. Run `godot --headless --import` separately to emit the new `.gd.uid` sidecars before committing.

### References

- `_bmad-output/planning-artifacts/epics.md#Epic 14: Playable & Presentable` — Story 14.10 ACs (body lines 3185-3205); the Band-2 demarcation (Epic List entry lines 521-527); FR68/FR12/NFR9 (lines 158, 267, 182); the 14.11 boundary (body lines 3207-3227, which folds the 13.2 R1/R2 defers).
- `_bmad-output/planning-artifacts/sprint-change-proposal-2026-07-16.md` — **F9/F10** the debug-HUD / no-affordances finding (lines 28-29); the **14.10 scope row** (line 145); the Band-2 list (line 84).
- `_bmad-output/auto-gds/retro-notes/epic-14.md` — **§14-3 (the reconciliation 14.10 is told to inherit):** bounded self-terminating tweens / transient overlays with detach-safety, the node-bound-tween slide pattern, "one draw pass per render, never per-frame `_process`", render-from-session systemic, seams-expose-only-consumed; **§14-1** the "wrong files to touch" precision (`tactical_board_presenter.gd`) + `str(...)`-not-`String(nullable)` + the false-PASS grep; **§14-2** the corpse-tap-is-inspect note; **§14-6** the single `_display_name` helper heuristic; **§14-4** the stderr-negative attribution + the Band-1/2 human-verification-deferred epic risk; **§14-8** the `.gd.uid`-via-`--import` discipline.
- `_bmad-output/implementation-artifacts/14-9-outpost-screen-cleanup.md` — the ratified Band-2 presentation-only story shape (RefCounted render seam, no-SceneTree test, verify-by-construction, `.gd.uid` discipline, the 14.10/14.11 theme boundary).
- `_bmad-output/implementation-artifacts/deferred-work.md` — the 13.2 R1 reward-overlay-geometry (line 97 → 14.11); the 13.2 R2 passive-confirm-`display_name` (line 106 → 14.11); the 13.2 R1 `_inspect_facts_from` untested-transform (line 98, optional/leave-deferred); the Band-1/2 on-device human-playtest defer (extended by 14.10).
- Source files (read before implementing):
  - `godot/scripts/ui/presenters/tactical_board_presenter.gd` — `render()` (304-376); `_status_text` (382-394, the pipe-dump to replace) + `_affinity_badge_text` (400-413, already display-name-resolved — do not regress); `_confirm_cancel_text` (432-439, already suppressed live at 350-351); `_inspect_text` (445-456, the `Cues:` snake_case leak); `_build_regions` (242-270); `_build_wait_control` (696-709) + `_build_confirm_cancel_controls` (729-754, the discrete-control build pattern); `_build_board_draw_ops` (991-1075, the op list; the 14.2 armed-target overlay at 1057-1065 to mirror); `_cell_rect` (1117-1131, the zero-size guard); `_hp_bar_ops` (1158-1175, the grayscale HP-bar channel); `bind_interactive_session` (556-577, the live sources).
  - `godot/scripts/ui/view_models/run_hud_view_model.gd` — `DICTIONARY_KEYS` (45-57, the 11-key gate — UNCHANGED); `from_run` (74-111); `_find_hero` (116-125). REUSE for HUD data.
  - `godot/scripts/ui/view_models/tactical_board_view_model.gd` — `to_dictionary` (33-51, the 16-key gate — UNCHANGED); the `turn` slot (78, → `TacticalTurnState.to_dictionary()`).
  - `godot/scripts/tactical/turns/tactical_turn_state.gd` — `Phase` enum (6-12); the snake_case `PHASE_*` consts (14-19); `to_dictionary` (35-40, `phase` = snake_case); `id_for_phase` (75-88). Map to display names in the new seam.
  - `godot/scripts/tactical/movement/tactical_movement_query.gd` — `validate_target` (17-67, `reason: "valid"`); `DEFAULT_MOVEMENT_BUDGET == 3` (9). The move-range source (READ-only).
  - `godot/scripts/tactical/targeting/attack_preview_query.gd` — `preview_target_cell` (11-99, `legal: true`); the reject reasons incl. `dead_target` (49-50, corpse) / `friendly_target` / `out_of_range` / `not_aligned` / `blocked_line`. The attack-range source (READ-only).
  - `godot/scripts/ui/view_models/tactical_layout_profile.gd` — `_REGION_NAMES` (44-51, incl. `status`); `DEFAULT_MINIMUM_TOUCH_TARGET == Vector2(44,44)` (33); `_control_slot`/`_region_is_reachable` (241-257, the `reachable: false` contract). Honor it.
  - `godot/scripts/run/interactive_combat_session.gd` — `board()` (217), `turn_state()` (221), `hero_weapon()` (233), `HERO_ID` (75). The live highlight sources.
  - Tests: `godot/tests/unit/ui/test_run_hud_view_model.gd` (the `EXPECTED_KEYS` exact-key + fail-closed + pure-copy pattern to mirror); `godot/tests/unit/ui/test_run_flow_scenes_load.gd` (the compile guardrail, loads the board scene).

## Dev Agent Record

### Agent Model Used

Story context by Claude Opus 4.8 (gds-create-story). Implementation by Claude Opus 4.8 (gds-dev-story).

### Debug Log References

- Full headless suite (mandatory command): **205 PASS files / 0 FAIL**, "Headless tests passed.", exit 0. False-PASS guard `SCRIPT ERROR|Parse Error|^FAIL` = 0; exactly the 6 documented stderr negatives (int64-overflow ×2, malformed-JSON ×3, `invalid_node_type` ×1), ZERO new. Baseline 203 + 2 new seam-test files = 205.
- `--headless --import` run generated the 4 new `*.gd.uid` sidecars (`TacticalHudView` + `TacticalRangeHighlightView` registered as global classes; no parse error).

### Completion Notes List

- **Presentation-only, re-pins NOTHING.** No domain/command/event/RNG/save file touched. The 16-key `TacticalBoardViewModel`, 11-key `RunHudViewModel`, `TacticalTurnState`, and both queries are byte-untouched; highlights + HUD compose as SEPARATE read surfaces (no new board-VM key). The `RunHudViewModel` preload was removed from the presenter (its HUD read now lives inside the `TacticalHudView` seam — the presenter no longer references it directly).
- **Turn-label mapping (design decision, per story spec):** `player_resolving` is grouped WITH the enemy phases → "Enemy Turn" (the player's planning window is over once an action resolves), matching the story's explicit map and the highlight gate (highlights only on `player_planning`). Neutral/unknown → `TURN_LABEL_NONE` ("—").
- **`class_display_name` INCLUDED** (the story lists it as optional) via `ClassStartSummaryViewModel.summarize(run).display_name` — the sanctioned class-repository display-name path; fail-closed empty when the run has no class identity. Costs one baseline `ClassRepository` build per render (once per turn/state change, not per frame — acceptable).
- **`actor_cell` key DROPPED** from the range seam's recommended key set — the presenter draws only `move_cells`/`attack_cells`, so exposing `actor_cell` would be dead output (the 14.3 "seams expose only what the presenter consumes" rule). Final range keys: `has_highlights`, `move_cells`, `attack_cells`, `reason`.
- **NFR9 non-color channels:** move-range = single inset outline ring; attack-range = four L-shaped corner ticks (distinct from the move ring AND the 14.2 armed double outline); a HUD legend Label ("Move: outline / Attack: corner ticks") names the two shapes; the turn indicator is a WORD label; HP carries "N/M" text beside the ProgressBar length.
- **Reachability degrade:** the `status` panel sets `clip_contents = true` (a HUD that outgrows a short band clips, never overflows onto neighbouring regions); a non-reachable status slot falls back to a compact single-line HUD string in the base label. Both paths are display-name-safe.
- **Human-verification deferred (extends the standing Band-1/2 on-device defer):** the HUD legibility, the real range-highlight readability/distinguishability without color, the turn-indicator clarity, and the small-viewport no-overflow are automated-green (seam tests + compile guardrail) but human-unverified (no SceneTree presenter test). Confirm on the pending physical-device playtest before Band 2 closes.

### File List

- `godot/scripts/ui/view_models/tactical_hud_view.gd` (NEW) — the styled player-HUD render-decision seam (+ `.gd.uid`).
- `godot/scripts/ui/view_models/tactical_range_highlight_view.gd` (NEW) — the move/attack range-highlight seam (+ `.gd.uid`).
- `godot/scripts/ui/presenters/tactical_board_presenter.gd` (MODIFIED) — replaced the `_status_text` pipe-dump with the discrete styled HUD (`_build_hud_controls`/`_render_hud`/`_populate_hud`/`_compact_hud_text`/`_status_slot_reachable`/`_hp_text`); added the range-highlight compute + draw (`_range_highlights`/`_range_highlight_ops`/`_corner_tick_ops`, threaded through `_render_board_grid`/`_build_board_draw_ops`/`_refresh_board_ops` via `_last_highlights`); swept the F9 `Cues:` snake_case leak from `_inspect_text`; removed the now-dead `RunHudViewModel` preload; added the highlight color consts + the HUD control member vars.
- `godot/tests/unit/ui/test_tactical_hud_view.gd` (NEW) — the HUD seam unit test (+ `.gd.uid`).
- `godot/tests/unit/ui/test_tactical_range_highlight_view.gd` (NEW) — the range-highlight seam unit test (+ `.gd.uid`).
