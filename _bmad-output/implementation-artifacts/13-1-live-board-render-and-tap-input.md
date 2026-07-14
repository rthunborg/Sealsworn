---
baseline_commit: f35e3f0a761afbb555235889e34e8f86ba8bd2b2
---

# Story 13.1: Live Board Render and Tap Input

Status: review

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a player,
I want the tactical board drawn as a real tile grid I can click,
so that I can fight the battle myself instead of reading a text summary of it.

## Context and Scope Authority

This story was created by the 2026-07-13 sprint change proposal
(`_bmad-output/planning-artifacts/sprint-change-proposal-2026-07-13.md`) that added **Epic 13
(Human-Playable Board)** after the Epic-10 close, when the **first human desktop playtest** found the
hands-on combat loop is *not human-playable*: the tactical board renders as ONE summary text label and no
input path exists. The forensic case file is
`_bmad-output/implementation-artifacts/investigations/desktop-playtest-black-board-investigation.md`
(both symptoms root-caused, High confidence).

**This is a PURE presentation/input story.** The domain layer is complete and green (Epics 1–12; suite
**191 PASS**): `InteractiveCombatSession`, the command bridge, the two-step commit flow, the class-loadout
winnability proofs all shipped and are regression-enforced. Story 12.1 already wired the board presenter's
*interactive tap seams* (`interactive_submit_move` / `interactive_tap_attack` / `interactive_inspect` +
`bind_interactive_session`) — but at the **already-resolved-`Vector2i` level only** (tests/programmatic
callers supply the cell). The 12-1 review explicitly deferred the pixel→cell hit-test to "a later on-device
input story." **This is that story.** It (a) draws the board region as a real tile grid, (b) hit-tests a
click/tap pixel to a board cell and routes it into the EXISTING seams, and (c) fixes the cosmetic
`route_map_presenter.gd:32` diagnostics error.

**Authoritative scope inputs (already folded into this file — do not re-derive):**
- `epics.md` Epic 13 / Story 13.1 (canonical ACs; Epic List line 513–519, body lines 2901–2932).
- The sprint change proposal (issue summary, impact, §3 recommended approach, §5 success criteria).
- The investigation case file (the two root causes + the fix direction).
- The run-flow UX appendix **§14** (layout + accessibility pass; ≥44×44 targets, four-layout, color-independence)
  and **§1.2 / §2 / §3** (`_bmad-output/planning-artifacts/ux-appendix-run-flow.md`) — the region→slot map + the
  two-step tap contract, designed in Story 11.1.
- The deferred-work ledger's **12-1 `[Review][Defer]`** (the pixel→cell hit-test — THE core item this story
  resolves) and the Epic-10 retro §7 pre-ship backlog (this story UNBLOCKS the human-playtest track OSG-1..4 /
  ASG-1/2 / AG-1).
- `project-context.md` — the Epic-11 run-flow-scene-hud rules (lines 256–270), the Epic-12 interactive rules
  (lines 272–281), and the Epic-2 presentation/view-model rules (lines 300–306).

**The one-sentence essence:** the interactive session, the tap seams, the command bridge, AND the pixel↔cell
geometry math (`TacticalBoardZoomState`) ALL already exist and are unit-tested — this story draws a tile grid
from `TacticalBoardViewModel` reads and wires a `_gui_input` hit-test into the existing seams, so a human's
mouse/tap drives the fight the tests already prove works.

**NOT in this story (13.2's scope or an explicit non-goal — see "Explicit Non-Goals"):** the post-fight
reward-offer render + the passive Consume/Destroy modal (13.2); any domain/command/contract change; a new
board-VM key; a boss-arena tap-loop; a move-confirm VM; pan/zoom UI chrome.

## Acceptance Criteria

**AC1 — the board region renders a real tile grid (a pure projection of the VM).**
**Given** a run is parked on a `combat`, `elite_combat`, or `boss` node in the gameplay shell
**When** the node begins
**Then** the board region renders a visible tile grid from `TacticalBoardViewModel` reads — terrain, hero,
enemies, blockers/hazards, fog-of-war/visibility states (`hidden` / `memory` / `visible`), and the level's
affinity treatment (using the approved board art under `godot/assets/`)
**And** the render remains a projection of the domain board — no scene node owns tactical truth, no new
board-VM key is added, and a null board still renders the empty state without crashing (the `_render_between_levels`
`board == null` → zero-cell VM path stays correct-by-design).

**AC2 — a click/tap hit-tests to a cell and routes into the EXISTING seams.**
**Given** the board is rendered and it is the player's turn (a live `InteractiveCombatSession` is bound)
**When** the player clicks/taps inside the board region
**Then** the pixel position hit-tests to a board `Vector2i` cell (reusing `TacticalBoardZoomState.screen_to_cell`;
cells sized to fit the dominant board region, ≥44px effective targets where the board size allows, per UX
appendix §14)
**And** the resolved cell routes into the EXISTING board-presenter seams — `interactive_submit_move`,
`interactive_tap_attack` (first tap PREVIEWS/arms, second confirming tap on the SAME target COMMITS — FR11),
`interactive_inspect` — with NO parallel combat path and NO new command surface
**And** an out-of-bounds / invalid-geometry tap is a safe no-op (the geometry seam's `available: false`), never
a crash or a fabricated cell.

**AC3 — the route_map fresh-run diagnostics error is fixed.**
**Given** the route map navigates to the board on a fresh run
**When** `route_map_presenter._ready` triggers the resolve-then-advance navigation (a synchronous mid-`_ready`
scene change)
**Then** no engine error is printed — the out-of-tree diagnostics probe at `route_map_presenter.gd:32`
(`has_node("/root/Diagnostics")` after `_render_map()` navigated away) is guarded (`is_inside_tree()`) or
reordered (emit the `route_map_ready` line BEFORE `_render_map()`).

**AC4 — testable RefCounted seams; every pinned invariant byte-identical.**
**Given** the headless suite and seed regressions run
**When** this story lands
**Then** all hit-test/geometry decision logic lives in `RefCounted` seams testable without a `SceneTree`
(reuse the tested `TacticalBoardZoomState`; any new fit/geometry helper is a `RefCounted` with a pinned
contract; the `.tscn`/`Control` wiring is verified by construction + the `test_run_flow_scenes_load.gd`
compile guardrail)
**And** the hands-off auto-resolve driver and EVERY pinned fingerprint stay byte-identical; NO new autoload;
NO new RNG draw site; NO new `DomainEvent.Type` member; the 23-key `RunSnapshot` gate stays 23; the 7 named
RNG streams are unchanged; `TacticalBoardViewModel.to_dictionary()` keeps its exact 16-key contract.

## Tasks / Subtasks

- [x] **Task 1 — Draw the board region as a tile grid from the VM (the render half of the L-gap fix).** (AC1)
  - [x] In `tactical_board_presenter.gd`, replace the text-only board-region render
    (`_set_region_text("board", "Board %dx%d — %d occupants" ...)` at `:139-141`) with a real tile-grid Control
    hosted inside the board region Panel. Suggested shape: a dedicated child `Control` under the board Panel
    that draws in `_draw()` via `draw_texture_rect` (ONE draw pass per `render()` — call `queue_redraw()`, do
    NOT draw per-frame in `_process`; project-context perf rule line 322). Keep the other five regions
    (`preview`, `confirm_cancel`, `inspect`, `status`, `log_or_outcome`) rendering exactly as today.
  - [x] Render each cell from `vm.cells` (each is `{position:{x,y}, visibility_state, [terrain], [blocks_line_of_sight],
    [terrain_blocks_occupancy], [occupant_id]}` — see `TacticalCellView.from_visibility_fact`). Map
    `visibility_state`: `hidden` → fog tile (no terrain leak — `hidden` cells expose NO terrain per the VM
    contract); `memory` → dimmed last-known terrain; `visible` → lit terrain. Map `terrain` (int, `BoardCell.Terrain`)
    to the approved tile art (`tile.floor` / `tile.wall` / `tile.blocker` / `tile.hazard` / `tile.entrance` /
    `tile.exit`, etc.). Draw occupants from `vm.occupants` (each is `{entity_id, entity_type, faction, position:{x,y},
    current_hp, max_hp, is_alive, ...}`): the hero (`faction`/`entity_type` = player) uses the class sprite, enemies
    use their `definition_id` sprite. Occupants already come pre-filtered to VISIBLE cells only (see
    `_build_occupant_views`) — do not re-derive visibility.
  - [x] Apply the level's **affinity treatment** as the floor variant using `_affinity_id` (the presenter already
    holds it via `bind_live_state` / `bind_interactive_session`). The 4 approved treatments are full-tile FLOOR
    variants (`godot/assets/tiles/affinities/affinity.{scorched,flooded,cursed,darkness}.png`), NOT transparent
    overlays (manifest note: transparent overlays deferred to board-renderer time — use the full-tile variant for
    v0). A neutral (`none`) level uses the plain `tile.floor`. The affinity id is the SEPARATE
    `LiveAffinityReadModel` surface, NOT a board-VM key — read it from `_affinity_id`, do not add a VM key.
  - [x] Color-independence (NFR9 / §14.2): fog/memory/visible, hero-vs-enemy, and hazard/blocker each carry a
    non-color channel (the art silhouette + a label/pattern), never color alone. The affinity danger cue ids
    already resolve non-color (`LiveAffinityReadModel`); the tile art is silhouette-distinct (passed the 3-point
    grayscale/phone-size/silhouette gate). Respect the `TacticalTextScale` clamp for any label text.
- [x] **Task 2 — Hit-test a tap to a cell and route it into the EXISTING interactive seams (the input half).** (AC2)
  - [x] Add a `_gui_input(event)` handler (or connect the `gui_input` signal) on the board-grid Control. On a
    `InputEventMouseButton` press (left button; Godot's default `emulate_mouse_from_touch` makes this cover mobile
    taps too), take `event.position` (local to the grid Control) and hit-test it to a `Vector2i` via
    `TacticalBoardZoomState.screen_to_cell(position)` — REUSE the tested seam; do NOT write a second pixel→cell
    formula. An `available: false` mapping (out-of-bounds / invalid-geometry / NaN) is a safe no-op (log via
    Diagnostics if useful; never fabricate a cell).
  - [x] Route the resolved cell into the EXISTING presenter seams (they already exist — do NOT add new ones):
    `interactive_submit_move(cell)` for a move tap, `interactive_tap_attack(cell)` for an attack tap (the two-step
    arm→confirm is inside the session's `TacticalAttackCommitFlow` — first tap PREVIEWS, second on the SAME target
    COMMITS), `interactive_inspect(cell)` for inspect. The move-vs-attack routing decision (is the tapped cell a
    reachable empty tile, a valid attack target, or an inspect?) is presentation-flow logic — put the DECISION in a
    `RefCounted` seam (AC4) so it is headlessly testable; the presenter just calls it. A tap on an already-armed
    attack target is the confirming COMMIT; a tap elsewhere clears/re-previews (the session's commit flow already
    handles `clear_for_non_attack_tile` / mode switches).
  - [x] Compute the grid geometry (cell_size + origin) to FIT the board into the dominant board-region rect:
    `cell_size = min(region_w / board_width, region_h / board_height)` (square cells), centered origin. Feed
    `board_width`/`board_height` (from `vm.width`/`vm.height`) + the computed `cell_size`/`origin` +
    `viewport_size` into `TacticalBoardZoomState.from_options({...})`, then use `cell_rect(cell)` to lay out the
    draw and `screen_to_cell(pixel)` to invert taps — the SAME geometry object for draw AND hit-test (so they can
    never disagree). Put this fit computation in a `RefCounted` helper (pure, testable) — NOT inline in the
    presenter — per AC4. Target ≥44px effective cells where board size allows; a large Medium (14×12) board on a
    narrow phone may yield sub-44px raw cells, and that is acceptable for v0 — the two-step attack commit is the
    mis-tap protection (§14), and the existing zoom seam (`TacticalBoardZoomState`, Story 2.4) is the inspect/zoom
    affordance. Full pan/zoom chrome is NOT required by these ACs (non-goal).
- [x] **Task 3 — Fix the route_map fresh-run diagnostics error.** (AC3)
  - [x] In `route_map_presenter.gd` `_ready()` (`:29-33`): the `has_node("/root/Diagnostics")` at `:32` runs AFTER
    `_render_map()` at `:31`, which on a fresh run synchronously navigates away (`SceneManager.go_to_stage("tactical_board")`
    → `change_scene_to_file` removes the current scene from the tree immediately), so `:32` executes out-of-tree →
    the engine ERROR. Fix: EITHER emit the `route_map_ready` diagnostics line BEFORE `_render_map()`, OR guard it
    with `is_inside_tree()`. Prefer emitting before `_render_map()` (the diagnostics intent is "route map entered",
    which is true before the render). The OTHER `has_node("/root/Diagnostics")` calls in this file (`:146`, `:164`,
    inside the `_on_choice_picked` signal handler) are in-tree and fine — do not touch them.
- [x] **Task 4 — Tests: RefCounted seam coverage + the scene compile guardrail.** (AC1, AC2, AC4)
  - [x] Add headless unit tests for the NEW `RefCounted` seams (the grid-fit helper + the tap-routing decision
    seam) under `godot/tests/unit/ui/` (auto-discovered — the runner recursively walks `res://tests/unit` +
    `res://tests/integration`; NO manifest edit). Prove: (a) the fit helper computes square cells that fit the
    region for an 8×8 and a 14×12 board, centered origin; (b) a pixel inside cell `(x,y)` round-trips
    `cell_rect → screen_to_cell → (x,y)` (reuse/extend the existing `test_tactical_board_zoom_state.gd` patterns);
    (c) an out-of-bounds pixel maps to `available: false` (safe no-op); (d) the tap-routing decision returns
    move/attack/inspect/no-op for the right cell states (empty-reachable → move, enemy-on-cell → attack,
    armed-target re-tap → commit).
  - [x] Confirm the existing `test_run_flow_scenes_load.gd` compile guardrail still covers the modified
    `tactical_board_presenter.gd` + `route_map_presenter.gd` + `tactical_board.tscn` (both load with their modified
    scripts — the guardrail is green). Do NOT write a SceneTree test for the presenter (project-context line 260:
    the harness is scene-free; assertable logic lives in RefCounted seams).
  - [x] Prove the invariants hold: `RngStreamSet.required_streams()` still == 7; no new `DomainEvent.Type` member
    (tail `OATH_SHARDS_SPENT`, preceded by `BOSS_DEFEATED` — render/hit-test emit ZERO events); the
    `TacticalBoardViewModel.to_dictionary()` 16-key contract is unchanged (`test_tactical_board_view_model.gd` still
    green — you added no VM key). Reuse the existing invariant tests where possible rather than adding redundant ones.
- [x] **Task 5 — Run the full headless suite + the false-PASS grep guard + `git diff --check`.** (AC4)
  - [x] Run: `godot --headless --path C:\Sealsworn\godot --scene res://tests/headless/test_runner.tscn --quit-after 10`
    via a PowerShell `.ps1` + `-File` (NOT inline `-Command` through Bash — Git Bash expands `$LASTEXITCODE` before
    PowerShell parses it → silent parse failure; Epic-10 retro §8 P3). Expect **≥191 PASS / 0 `^FAIL`** (baseline
    191 + any new seam tests), exit 0.
  - [x] Grep the RAW runner output for `SCRIPT ERROR|Parse Error|^FAIL` — no matches; exactly the 6 documented
    stderr negatives (int64-overflow ×2 / malformed-JSON ×3 / `invalid_node_type` ×1) and ZERO new documented
    negative. `git diff --check` clean.

## Dev Notes

### The exact seam map (READ THESE FILES — they are the whole story)

| File | What it is today | What 13.1 does |
|---|---|---|
| `godot/scripts/ui/presenters/tactical_board_presenter.gd` | The board presenter. Builds six region Panels each with ONE child Label (`_build_regions` `:78-92`). Renders the board region as **text only**: `_set_region_text("board", "Board %dx%d — %d occupants" ...)` at **`:139-141`** — the root cause. ALREADY exposes the LIVE tap seams `interactive_submit_move(target_cell)` `:312`, `interactive_tap_attack(target_cell)` `:323`, `interactive_inspect(target_cell)` `:334`, and `bind_interactive_session(session, run, on_action_committed, affinity_id, fairness)` `:289`. Holds `_board`/`_turn_state`/`_run`/`_affinity_id` (the render inputs) and `_session` (the live fight). It reads `TacticalBoardViewModel.from_domain(_board, _turn_state, {...}).to_dictionary()` `:133-137`. | Replace the `:139` text with a real tile-grid render from `vm.cells`/`vm.occupants` + `_affinity_id`. Add a `_gui_input` hit-test that maps a tap pixel → `Vector2i` and calls the EXISTING `interactive_*` seams. Do NOT add a board-VM key, a new seam method, or a parallel path. |
| `godot/scripts/ui/view_models/tactical_board_zoom_state.gd` | **The pixel↔cell geometry seam — ALREADY BUILT + unit-tested (`test_tactical_board_zoom_state.gd`, Story 2.4).** A `RefCounted` with `screen_to_cell(pixel) -> {available, reason, cell:{x,y}, ...}` (the hit-test, with bounds/geometry/NaN validation), `cell_to_screen(cell)`, and `cell_rect(cell) -> {position, size}` (the per-cell DRAW rect). Handles zoom, origin, cell_size, board_size, out-of-bounds. | **REUSE this — do NOT reinvent the hit-test.** Construct it via `from_options({board_width, board_height, cell_size, origin, viewport_size})` sized to the board region rect; use `cell_rect` to draw and `screen_to_cell` to invert taps. This is the AC4 "hit-test/geometry logic lives in RefCounted seams" — already satisfied by this file; you extend its use, not its math. |
| `godot/scripts/ui/view_models/tactical_board_view_model.gd` | The board VM. `to_dictionary()` `:33-51` yields the pinned 16-key set: `width`, `height`, `cells`, `occupants`, `selected_cell`, `selected_entity_id`, `preview`, `commit_flow`, `inspect`, `zoom`, `action_availability`, `turn`, `outcome`, `event_log_summary`, `layout`, `accessibility`. `_build_cell_views` `:86` composes cells via `TacticalVisibilityQuery` (fog-correct); `_build_occupant_views` `:105` filters to VISIBLE occupied cells. `from_domain(null)` → a zero-cell VM (empty, no crash). | The **render source of truth.** Draw from `cells` (terrain + `visibility_state` + blockers) and `occupants` (hero/enemies + faction + hp). Do NOT add a 17th key (project-context line 303: the 16-key contract is pinned by `test_tactical_board_view_model.gd` — adding a slot must intentionally bump that assertion; you don't need to). |
| `godot/scripts/ui/view_models/tactical_cell_view.gd` / `tactical_occupant_view.gd` | The per-cell / per-occupant read shapes. Cell: `{position:{x,y}, visibility_state}` + (if `memory`/`visible`) `authoritative`/`terrain`/`blocks_line_of_sight`/`terrain_blocks_occupancy` + (if `visible` and occupied) `occupant_id`. `hidden` cells expose NO terrain. Occupant: `{entity_id, entity_type, faction, position:{x,y}, current_hp, max_hp, is_alive, is_dead, blocks_movement, definition_id}`. | The exact fields the tile-grid draw reads. `terrain` is an int (`BoardCell.Terrain`); map it to the tile art. `definition_id` picks the enemy sprite; the hero is the player-faction occupant. |
| `godot/scripts/run/interactive_combat_session.gd` | The scene-free step-driven live fight (12-1/12-2). `board()`/`turn_state()`/`is_terminal()` reads; `submit_move(cell)` / `tap_attack(cell, ...)` / `inspect(cell)` — ONE action per tap through the command bridge + two-step commit flow; runs the enemy phase per committed action. The board presenter's `interactive_*` methods already delegate to these. | You do NOT touch this — you feed its already-wired presenter seams from real taps. The session owns the live board/turn/outcome; the render is a read of `session.board()` (bound via `bind_interactive_session`). |
| `godot/scripts/ui/presenters/gameplay_shell_presenter.gd` | Hosts the board (`tactical_board.tscn` instance `:52`). For a `combat`/`elite_combat` node it calls `begin_interactive_combat_node` → `bind_interactive_session(...)` → `render()` `:138-139`, then AWAITS taps (the committed callback `_on_interactive_action_committed` re-renders + routes on terminal). The BOSS node stays `auto_play_boss_fight` `:74` then `_render_between_levels` (board == null → empty VM). Non-combat nodes resolve in place. | **Unchanged** (or near-unchanged). The tap loop is already wired shell↔session↔board-presenter; this story only makes the board presenter DRAW pixels and RECEIVE clicks. Do not change the shell's node-branch routing, the boss auto-play, or the resolve-then-advance seam. |
| `godot/scripts/ui/presenters/route_map_presenter.gd` | The route-map presenter. `_ready()` `:29-33` calls `_build_layout()` → `_render_map()` `:31` → `has_node("/root/Diagnostics")` `:32`. On a fresh run `_render_map` takes the resolve-then-advance branch (`:83-87`) and synchronously `SceneManager.go_to_stage("tactical_board")` — removing this scene from the tree — so `:32` runs out-of-tree → the benign ERROR. | Fix ONLY the `:32` ordering (Task 3): emit the diagnostics line before `_render_map()` or guard with `is_inside_tree()`. Leave the in-tree Diagnostics calls (`:146`, `:164`) alone. |
| `godot/scenes/game/tactical_board.tscn` | A single `Control` root carrying the `tactical_board_presenter.gd` script (full-rect anchors). No child nodes in the `.tscn` (the presenter builds regions in `_build_regions`). | No `.tscn` edit needed — the grid Control is built in code by the presenter (as the regions already are). The compile guardrail (`test_run_flow_scenes_load.gd`) still covers it. |

### The approved board art (verified on disk 2026-07-13 — all `approved` in `asset_sources/asset-manifest.md`)

The runtime mirrors are present under `godot/assets/` (exported 2026-06-22, downscaled from 1K masters; all
passed the 3-point grayscale/phone-size/silhouette gate). Use these — no new art, no asset generation:

- **Tiles (9, `approved`, 256²):** `godot/assets/tiles/tile.{floor,wall,blocker,entrance,exit,door,door_sealed,hazard,reward_object}.png`.
  Transparent props: `godot/assets/tiles/props/{door,door_sealed,reward_object}.png` (placeable on any floor/affinity cell).
- **Affinity treatments (4, `approved`, 256², full-tile FLOOR variants — NOT transparent overlays):**
  `godot/assets/tiles/affinities/affinity.{scorched,flooded,cursed,darkness}.png`. Keyed by the level's `_affinity_id`.
- **Hero classes (`approved`, 256×384):** `godot/assets/characters/char.{warrior,pyromancer,ranger}.png`
  (+ `char.{necromancer,shadeblade}_locked.png`).
- **Enemies (`approved`, 256×384 / boss 512²):** `godot/assets/enemies/enemy.{iron_cultist,gate_brute,ash_seer}.png`
  + `boss.larval_avatar.png`.

**Manifest "deferred to board-renderer time" notes (this IS board-renderer time — read + honor):**
- **Seamless tiling not solved** — floor/wall are per-cell textures that repeat visibly (not edge-seamless). ACCEPTABLE
  for v0 (visible repeats are fine); true seamless tiling is a later polish pass, not this story.
- **Affinity treatments ship as full-tile floor variants**, not transparent overlays — use the affinity tile AS the
  floor for an affinity level. True transparent recolor/shader overlays are a later in-engine pass.
- **`entrance` vs `exit` look alike at tiny grayscale** — if a cheap non-color cue helps (an up/down arrow glyph),
  it's a nice-to-have, not required.

### Architecture rules this story MUST obey (project-context.md — the load-bearing seam rules)

- **Presentation observes domain state and submits through the command bridge; scenes own NO tactical truth**
  (lines 300–302). The tile grid is a READ of `TacticalBoardViewModel`; taps submit the EXISTING commands via
  the EXISTING `interactive_*` seams (which go through `TacticalCommandBridge`). No scene node is authoritative
  for board/turn/RNG.
- **The board VM key contract is pinned at 16 keys** (line 303, `test_tactical_board_view_model.gd`). Render from
  the existing keys; add NO key. The affinity treatment is the SEPARATE `LiveAffinityReadModel` surface
  (`_affinity_id`), never a board-VM key.
- **"Build the Control/scene presenter … in a later HUD story. Touch targets stay ≥44px; slots that cannot fit
  honestly report `reachable: false` rather than overflowing"** (line 304). **This story IS that later HUD story**
  for the board render. Honor the semantic `TacticalLayoutProfile` region plan (the testable source of truth) —
  the board Panel's rect comes from the profile; never hardcode geometry.
- **The scene-free harness verifies `.tscn`/`Control` BY CONSTRUCTION, not by SceneTree tests** (line 260). Put
  the assertable render/hit-test/tap-routing DECISION logic in `RefCounted` seams and test THOSE; the presenter
  wiring is covered by the `test_run_flow_scenes_load.gd` compile guardrail. **Do NOT trust a prose "it's wired"
  claim about a guarded accessor without grepping the probed method against source** — the 11.3 M2 lesson (a dead
  `has_method("current_text_scale")` probe silently no-op'd and read as wired).
- **Keep autoloads thin; add NO new autoload** (lines 258/274/89). Acceptable autoloads: `GameSession`,
  `SceneManager`, `SaveManager`, `AudioManager`, `SettingsManager`, `Diagnostics`. This story adds none.
- **No per-frame work; update through explicit refresh** (line 322). Draw the grid on `render()` /
  `queue_redraw()`, not in `_process`. Cache node references; don't `get_node()` in a hot loop.
- **Color-independent + audio-absent-equivalent** (lines 305–306, §14.2): every critical meaning (fog tier,
  hero-vs-enemy, hazard/blocker, preview-vs-committed) carries a non-color channel; color is additive only.
  Preserve the `feedback_preview` vs `feedback_committed` distinction (the session's commit flow already encodes it).
- **Runtime art lives under `godot/assets/`; source under `asset_sources/`** (lines 337–338). Preload only critical
  shared assets; load by scene boundary (line 325) — the board tiles are small and may be `preload`ed in the presenter.

### The invariants that MUST stay byte-identical (AC4 — this is a presentation-only story)

- **7 named RNG streams** (`map`/`level`/`combat`/`loot`/`rewards`/`events`/`cosmetic`); `required_streams()` == 7.
  A render + a hit-test draw ZERO RNG — **no new draw site, no `randi`/`randf`, no fresh `RandomNumberGenerator`.**
- **No new `DomainEvent.Type` member.** The enum tail is `OATH_SHARDS_SPENT` (preceded by `BOSS_DEFEATED`);
  rendering and hit-testing emit no events (the session/commands emit the existing move/attack/damage/outcome
  events, unchanged).
- **The 23-key `RunSnapshot` gate stays 23**; `ProfileSnapshot`/`SettingsSnapshot` `SCHEMA_VERSION == 1`; the
  in-node fight stays EPHEMERAL (no in-node save). This story persists nothing.
- **Every generator/route/finale seed-regression fingerprint is byte-identical**, and the hands-off auto-resolve
  driver (`LiveCombatResolver.resolve` / `run_to_completion` / `auto_play_boss_fight`) is untouched. A render
  reads the board; it does not re-drive combat.
- **`TacticalBoardViewModel.to_dictionary()` keeps its exact 16-key contract** (no VM key added).

### UX appendix §14 + §1.2/§2/§3 — the interaction contract (already designed, Story 11.1)

- **Two-step commit (FR11, §2):** first tap PREVIEWS, second confirming tap on the SAME target COMMITS. This is
  ALREADY implemented in the session's `TacticalAttackCommitFlow` (`tap_attack` arms `attack_preview`; a second
  `tap_attack` on the same target/weapon/actor confirms). You wire the tap PIXEL to `interactive_tap_attack(cell)` —
  the two-step is inside. The non-color channels are `feedback_preview` (`[shape, label]`) vs `feedback_committed`
  (`[pattern, label, text]`) in `TacticalAccessibilityModel` (§2.3).
- **≥44×44 targets (§14.1):** the board is the dominant region on every profile; the four control bands
  (`preview`, `confirm_cancel`, `inspect`, `status`) stay ≥44×44 and reachable. Board CELLS target ≥44px effective
  where the board size allows; a large board on a narrow phone may yield smaller raw cells — that's acceptable
  (the two-step commit is the mis-tap protection; the zoom seam is the affordance). Honor the semantic region plan,
  never hardcoded geometry.
- **Move commit note (§2.2 / §16.1 non-gap):** the two-step commit-flow VM is attack-specific; a move commits via a
  `move` bridge intent (a single tap → `interactive_submit_move`). A symmetric two-step move-confirm is a
  presentation-flow CHOICE, NOT a required VM — do NOT invent a move commit-flow VM.
- **§14.3 visual-treatment baseline** explicitly names the approved affinity treatments
  (`godot/assets/tiles/affinities/affinity.*.png`) as the board-affinity baseline "the later stories apply." 11.4
  surfaced only the affinity READ (badge/inspect); applying the treatment to the tile RENDER is genuinely THIS
  story's work.

### Test harness facts

- **Run command (project CLAUDE.md):** `godot --headless --path C:\Sealsworn\godot --scene res://tests/headless/test_runner.tscn --quit-after 10`.
- **`godot` is NOT on the Bash/`where` PATH** — run via PowerShell as `C:\Users\Rasmus\bin\godot.cmd`, OR the binary
  directly: `C:/Users/Rasmus/Godot_v4.6.3-stable_win64.exe/Godot_v4.6.3-stable_win64_console.exe --headless --path
  C:\Sealsworn\godot --scene res://tests/headless/test_runner.tscn --quit-after 10`. **Run via a PowerShell `.ps1`
  + `-File`, NOT inline `-Command` through Bash** (Git Bash expands `$LASTEXITCODE` before PowerShell parses it →
  silent parse failure; Epic-10 retro §8 P3).
- **Test discovery is automatic** — `test_runner.gd` recursively walks `res://tests/unit` + `res://tests/integration`
  and runs every `test_*.gd`. A new test file under those trees needs NO manifest/registration edit.
- **False-PASS guard (standing gate, Epic-10 P3):** grep the RAW runner output for `SCRIPT ERROR|Parse Error|^FAIL`
  — a reserved-name collision / compile failure can still print `PASS` on the summary line. Exactly 6 documented
  stderr negatives are expected (int64-overflow ×2, malformed-JSON ×3, `invalid_node_type` ×1); this story must add
  ZERO new documented negative. Never "fix" the catalog by changing a test.
- **Baseline to preserve: 191 PASS / 0 `^FAIL`** (the post-Epic-10 baseline). This story ADDS tests (the seam
  coverage); new total ≥ 191, 0 `^FAIL`.
- **Test patterns to extend/mirror:** `godot/tests/unit/ui/test_tactical_board_zoom_state.gd` (the pixel↔cell
  geometry — reuse its `screen_to_cell`/`cell_rect` round-trip patterns for the new fit/routing seams),
  `godot/tests/unit/ui/test_tactical_board_view_model.gd` (the 16-key contract — must stay green),
  `godot/tests/unit/ui/test_run_flow_scenes_load.gd` (the by-construction compile guardrail — covers the two
  modified presenters + `tactical_board.tscn`).

### Explicit Non-Goals (13.2's scope, or an explicit boundary — do NOT do here)

- **The post-fight reward-offer render + the passive Consume/Destroy modal — that is Story 13.2.** The board
  presenter already exposes `passive_reward_modal(index)` `:276`; wiring the reward-offer VM + `PassiveRewardCommitFlow`
  into clickable UI (closing the 10-6 gate §3.3 rows-6/7 "later HUD story" item) is 13.2's deliverable. 13.1 ships
  a human-drivable FIGHT; 13.2 ships the human-clickable REWARD it earns.
- **No domain / command / contract / VM change.** No new board-VM key, no new event, no new RNG draw, no new
  command, no new autoload, no save-key change. This is additive presentation + input over pinned contracts.
- **No boss-arena tap-loop.** The boss stays `auto_play_boss_fight` (the 12-1 non-goal, unchanged). AC1's "boss node"
  clause means the tile-grid RENDER code must handle a boss board / the null empty-state without crashing — NOT that
  the boss becomes interactively driven. Today the boss auto-plays then renders the empty between-levels VM; do not
  add a live boss board or a boss tap-loop (out of scope; surface as an open question if the AC1 boss-render intent
  is read more strongly than "don't crash on a boss node").
- **No move commit-flow VM.** A move commits via a single-tap `move` bridge intent (§16.1 non-gap). A symmetric
  two-step move-confirm is optional presentation flow, not a required surface.
- **No pan/zoom UI chrome.** The `TacticalBoardZoomState` seam exists (Story 2.4) and can be leveraged for the
  fit geometry, but building interactive pan/zoom controls is not required by these ACs.
- **No new art / no asset generation.** All board/affinity/character/enemy art is approved + on disk. Seamless
  tiling, transparent affinity overlays, and entrance/exit disambiguation are deferred manifest polish, not this
  story.

### Regression traps (things that will silently break if you are not careful)

- **The empty-board VM is correct-by-design.** `TacticalBoardViewModel.from_domain(null)` → a zero-cell VM (no
  crash). Between levels the board is legitimately null (`_render_between_levels`). Your tile-grid render must draw
  NOTHING (or a clean empty state) for a zero-cell VM — do not crash on `width == 0` / empty `cells`.
- **`hidden` cells expose NO terrain.** Per `TacticalCellView`, only `memory`/`visible` cells carry `terrain`. Do
  not leak terrain/occupant info for `hidden` cells — draw the fog tile only (this is the FR7 fog contract; a leak
  is a fairness bug, not just cosmetic).
- **Draw and hit-test MUST share ONE geometry object.** If the draw uses one cell_size/origin and the hit-test
  another, a tap lands on the wrong cell. Build ONE `TacticalBoardZoomState` per `render()` from the current region
  rect + board dims, and use it for BOTH `cell_rect` (draw) and `screen_to_cell` (tap).
- **Godot's default `emulate_mouse_from_touch` is ON** — a single `_gui_input` handling `InputEventMouseButton`
  covers desktop click AND mobile tap. Do not add a separate touch handler that double-fires.
- **Don't re-derive visibility or occupancy.** `vm.occupants` is already filtered to visible occupied cells;
  `vm.cells` already carries the fog-correct `visibility_state`. Draw what the VM gives you.
- **The route_map fix is ONE line's ordering — don't over-fix.** Only `:32` runs out-of-tree; the `:146`/`:164`
  Diagnostics calls are in-tree. Do not add `is_inside_tree()` guards everywhere or refactor the presenter.
- **Adding a board-VM key to carry render data will break `test_tactical_board_view_model.gd`** (the 16-key pin).
  Render from existing keys + `_affinity_id`; never widen the VM contract for presentation.

### Project Structure Notes

- The tile-grid render + hit-test live inside the EXISTING `tactical_board_presenter.gd` (`godot/scripts/ui/presenters/`).
  New pure seams (the grid-fit helper, the tap-routing decision) go under `godot/scripts/ui/view_models/` as
  `RefCounted` (alongside `tactical_board_zoom_state.gd`), so they are headlessly testable. Tests mirror them under
  `godot/tests/unit/ui/`. No `.tscn` edit (the presenter builds its own children in code). Runtime art is already
  under `godot/assets/`.
- Naming: `snake_case` files/folders, `PascalCase` classes, `snake_case` funcs/vars/signals, `UPPER_SNAKE_CASE`
  consts.

### Project Context Rules

Extracted from `project-context.md` (the canonical rulebook — read it before implementing; when in doubt choose
the more restrictive interpretation):

- **Presentation observes domain state/events and submits commands through a command bridge.** Godot scenes,
  `Control` nodes, audio, VFX, animation are presentation — they must NOT own authoritative tactical state. The
  scene-independent domain model owns tactical truth (board, entities, turns, RNG, rules, saves, run progression).
- **Headless simulation is a first-class target** — it runs without rendering, audio, UI scenes, presentation nodes,
  or scene-tree-only state. Assertable logic lives in `RefCounted` seams; `.tscn`/`Control` wiring is verified by
  construction + the compile guardrail (no SceneTree test). Do NOT trust a prose "wired" claim without grepping the
  probed method name against source (the 11.3 M2 dead-probe lesson).
- **Keep autoloads thin; add no new autoload.** Acceptable autoloads: `GameSession`, `SceneManager`, `SaveManager`,
  `AudioManager`, `SettingsManager`, `Diagnostics`.
- **Do not serialize scene nodes as save truth; save versioned domain snapshots only.** The 23-key `RunSnapshot`
  gate stays 23; the in-node fight state stays EPHEMERAL. This story persists nothing.
- **Difficulty is a hard non-goal** — no difficulty selector/ladder/knob anywhere. This story renders + wires input;
  it changes no balance number.
- **AI tooling (Godot MCP / Context7) is dev-time only** — the game never calls AI to generate runtime content. This
  story authors no content; it wires the existing tactical layer to live input over approved static art.
- **Honesty posture (Epic-10 retro §5/§7):** where an on-device / human-eyes readability dimension cannot be
  verified headlessly (real contrast/legibility on a physical display — ASG-1/2 / AG-1), record it against the
  physical-device observed-playtest pass owner; do NOT claim a human-eyes pass a headless run cannot produce. This
  story UNBLOCKS that pass (OSG-1..4 / ASG-1/2 / AG-1 become testable once a human can drive the board), it does not
  itself close it.

### References

- [Source: `_bmad-output/planning-artifacts/epics.md#Epic 13: Human-Playable Board` (Epic List lines 513–519; Story 13.1 lines 2901–2932)]
- [Source: `_bmad-output/planning-artifacts/sprint-change-proposal-2026-07-13.md` — the playability gap, §2 impact, §3 recommended approach (Story 13.1 render + pixel→cell + route_map guard), §5 success criteria]
- [Source: `_bmad-output/implementation-artifacts/investigations/desktop-playtest-black-board-investigation.md` — the two root causes (text-only render `tactical_board_presenter.gd:139`; no input path; the `route_map_presenter.gd:32` out-of-tree diagnostics), fix direction]
- [Source: `_bmad-output/implementation-artifacts/deferred-work.md#Deferred from: code review of 12-1 …` — the `[Review][Defer]` gesture→cell pixel hit-test (THE core item this story resolves)]
- [Source: `_bmad-output/implementation-artifacts/epic-10-retro-2026-07-12.md#7 Forward Preparation` (pre-ship backlog items 4 [OSG/ASG unblocked] + 8 [reward/passive HUD = 13.2]) + `#8 Action Items` (P3 false-PASS grep + PowerShell `-File`) + the honesty posture]
- [Source: `_bmad-output/planning-artifacts/ux-appendix-run-flow.md#14 Layout + accessibility coverage pass` (≥44×44, four-layout, §14.2 color-independence, §14.3 affinity-treatment baseline) + `#1 Tactical HUD` / `#2 Preview-confirm` / `#16.1 Non-gaps`]
- [Source: `asset_sources/asset-manifest.md` — the approved tiles / 4 affinity treatments / hero + enemy art (ids/status/runtime paths) + the "deferred to board-renderer time" notes; verified on disk under `godot/assets/`]
- [Source: `project-context.md` lines 256–270 (Epic-11 run-flow-scene-hud rules), 272–281 (Epic-12 interactive rules), 300–306 (Epic-2 presentation/view-model rules incl. the 16-key board-VM pin + "later HUD story" board render), 322/325/337–338 (perf + asset placement)]
- [Source: `godot/scripts/ui/presenters/tactical_board_presenter.gd` — the text-only board render `:139`; the existing `interactive_*` seams `:312/:323/:334` + `bind_interactive_session` `:289`]
- [Source: `godot/scripts/ui/view_models/tactical_board_zoom_state.gd` — the REUSE target: `screen_to_cell`/`cell_to_screen`/`cell_rect` (pixel↔cell geometry, already unit-tested in `test_tactical_board_zoom_state.gd`)]
- [Source: `godot/scripts/ui/view_models/tactical_board_view_model.gd` + `tactical_cell_view.gd` + `tactical_occupant_view.gd` — the render source shapes (cells/occupants; the pinned 16-key contract)]
- [Source: `godot/scripts/ui/presenters/gameplay_shell_presenter.gd` — the host wiring (`bind_interactive_session` `:138`; boss auto-play `:74`) — unchanged] and [`godot/scripts/ui/presenters/route_map_presenter.gd:29-33` — the `:32` fix site]
- [Source: `godot/scripts/run/interactive_combat_session.gd` — the live session `board()`/`submit_move`/`tap_attack`/`inspect` (the tap destination) — unchanged]

## Dev Agent Record

### Agent Model Used

Claude Opus 4.8 (claude-opus-4-8[1m]) — gds-dev-story delegate, 2026-07-14.

### Debug Log References

- Full headless suite (post-implementation): **193 PASS / 0 `^FAIL`** (baseline 191 + 2 new seam tests), exit 0.
  False-PASS grep `SCRIPT ERROR|Parse Error|^FAIL` = 0 matches; exactly the 6 documented stderr negatives
  (int64-overflow ×2 / malformed-JSON ×3 / `invalid_node_type` ×1), ZERO new negative. No trailing-whitespace /
  space-indent issues in changed files (`git diff --check` equivalent, run by orchestrator).
- Throwaway SceneTree render smoke (`tools/smoke_board_render.gd`, deleted after use): the real `tactical_board.tscn`
  built 6 regions + the grid, rendered **84 draw ops** from a revealed 6×6 fixture VM with **7 approved-art textures
  loaded** (scorched affinity floor + wall/entrance/exit tiles + warrior/iron_cultist/ash_seer sprites); the tap
  hit-test **round-tripped cell (3,2) → screen center → (3,2)** on the live rendered board; the null/between-levels
  board rendered **0 ops** (safe empty state); zero runtime errors across neutral/affinity/empty/live renders.

### Completion Notes List

- **Implemented (2026-07-14):** the board region now renders a real, tappable tile grid — closing the Epic-13 L-gap
  (text-label board + no input). Two NEW pure `RefCounted` seams carry all AC4 assertable geometry/decision logic:
  `TacticalBoardGridFit` (square-cell centered fit → builds the SHARED `TacticalBoardZoomState` used for BOTH draw
  and hit-test) and `TacticalBoardTapRouter` (cell-state → move/attack/inspect/none intent). A thin
  `tactical_board_grid.gd` Control draws the presenter-built op list and forwards a tap pixel via `cell_tapped`.
  The presenter draws tiles/occupants/affinity-floor from the VM + `_affinity_id`, hit-tests taps via the shared
  geometry, and routes into the EXISTING `interactive_submit_move` / `interactive_tap_attack` / `interactive_inspect`
  seams — NO new command/event/RNG/VM-key/autoload. `route_map_presenter._ready` now emits its diagnostics line
  BEFORE `_render_map()` (AC3 fix).
- **Invariants held (AC4):** no board-VM key added (16-key contract green via `test_tactical_board_view_model.gd`);
  `required_streams()` still 7; `DomainEvent.Type` tail unchanged (render/hit-test emit zero events); render/hit-test
  draw zero RNG; no new autoload. All verified by the existing invariant tests staying green (reused, not duplicated).
- **Color-independence (NFR9/§14.2):** fog = featureless dark fill (no terrain leak), memory = dimmed (brightness)
  modulate, visible = full art; hero-vs-enemy = silhouette-distinct approved sprites + a distinct hero border + a
  per-occupant HP bar (a grayscale-safe length channel); hazards = a bright outline pattern over the silhouette-
  distinct hazard art. All non-color channels hold with color stripped.
- **Asset wiring (needed to render the approved art):** the board art existed on disk but was NEVER imported
  (no `.png.import` sidecars, no `.godot/` cache), so `preload`/`load` of the PNGs could not resolve. Ran a headless
  `--import` to generate the 26 `.import` sidecars (25 tiles/affinities/characters/enemies + 1 icon SVG) so any
  build renders the real art; **removed the 404 unrelated `.gd.uid` script-uid sidecars** the full editor import also
  emitted (churn the project does not track). The presenter loads textures DEFENSIVELY at runtime (guarded `load()`,
  never `preload`) so its script compiles even where the machine-local `.godot/` cache is absent (compile guardrail
  robust on a fresh checkout); an un-imported checkout degrades to flat terrain-colored fallback tiles (never a
  crash / black board).
- **Verified (create-story, 2026-07-13):** Ultimate context engine analysis completed — comprehensive developer guide created.
  Folds in: the Epic 13 / Story 13.1 canonical ACs; the 2026-07-13 sprint change scope; the desktop-playtest
  investigation's two root causes; the 12-1 `[Review][Defer]` pixel→cell hit-test (the core item this story
  resolves); the Epic-10 retro forward items (§7 pre-ship backlog: this story UNBLOCKS OSG/ASG/AG-1; reward/passive
  HUD is 13.2's; §8 P3 false-PASS grep + PowerShell `-File`; the honesty posture); and the UX §14 tap contract. The
  key anti-reinvention find is pinned: the pixel↔cell geometry seam (`TacticalBoardZoomState`) AND the tap seams
  (`interactive_*` + `bind_interactive_session`) already exist and are tested — this story draws the grid + wires a
  `_gui_input` hit-test into them, adding no domain/VM/event/RNG/autoload change.

### File List

**New (production):**
- `godot/scripts/ui/view_models/tactical_board_grid_fit.gd` — pure `RefCounted` grid-fit seam (square cells, centered origin) that builds the shared `TacticalBoardZoomState`.
- `godot/scripts/ui/view_models/tactical_board_tap_router.gd` — pure `RefCounted` tap-routing DECISION seam (cell-state → move/attack/inspect/none).
- `godot/scripts/ui/presenters/tactical_board_grid.gd` — thin tile-grid draw surface + `cell_tapped` forwarder Control.

**New (tests):**
- `godot/tests/unit/ui/test_tactical_board_grid_fit.gd`
- `godot/tests/unit/ui/test_tactical_board_tap_router.gd`

**Modified (production):**
- `godot/scripts/ui/presenters/tactical_board_presenter.gd` — tile-grid render (replaces the text-only board region), tap hit-test + routing into the existing `interactive_*` seams, defensive art texture loading.
- `godot/scripts/ui/presenters/route_map_presenter.gd` — emit the `route_map_ready` diagnostics line before `_render_map()` (AC3 out-of-tree fix).

**Modified (tests):**
- `godot/tests/unit/ui/test_run_flow_scenes_load.gd` — added `tactical_board_grid.gd` to the compile guardrail.

**New (asset import sidecars — wire the approved art so it renders):**
- `godot/assets/**/*.png.import` (25) + `godot/assets/art/ui/icons/icon_placeholder.svg.import` (1) — generated by a headless `--import`. Machine-local `.godot/` cache is gitignored; the 404 unrelated `.gd.uid` script-uid sidecars the import also emitted were removed.

### Change Log

- 2026-07-14 — Story 13.1 implemented: live board tile-grid render + tap hit-test wired into the existing interactive combat seams; `route_map` fresh-run diagnostics fix; approved board art imported. Suite 193 PASS / 0 FAIL. Status → review.
