# Story 14.11: UI Theme and Semantic Layout

Status: review

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a player,
I want a consistent visual theme and layout across screens,
so that the game looks intentional on any window size.

## Context & Why This Story Exists

Epic 14 ("Playable & Presentable") is the **second pre-ship backlog epic**, added 2026-07-16 after an agent-driven desktop playtest found the built MVP is **not honestly finishable** and **does not look intentional** (`playtest-sessions/agent-playtest-2026-07-16.md`; `sprint-change-proposal-2026-07-16.md`). Story 14.11 is the **LAST story of Band 2 and of the whole epic** — the presentation capstone, landing after 14.8 (hero-select rebuild, F13), 14.9 (outpost cleanup, F14), and 14.10 (player HUD + range highlights, F9/F10). It was deliberately sequenced **last** so it themes the surfaces the earlier Band-2 stories built (the sprint change: *"The theme story is deliberately last so it themes the [rebuilt screens]"*).

It closes findings **F15** and **F16** (`sprint-change-proposal-2026-07-16.md` line 30, scope row line 146):

> **F16 — no UI theme** (default Godot Control styling everywhere, the generated Recraft frame kit unused); **F15 — the board renders in a huge dead gray zone** / layout does not scale to the window.
> Scope row 14.11: "Import the **Recraft frame kit** SVGs + build & apply a **`Theme`** (StyleBoxes/fonts/spacing) + the semantic **`TacticalLayoutProfile`** region plan **across screens** — folds the two 13.2 overlay defers | FR68, **NFR9** | Presentation/theme; imports + commits the SVG sidecars (the 13.1 art-import discipline); ≥44px targets + honest `reachable:false`; no domain change."

**This story is PRESENTATION + THEME + SCENE/UI-RESOURCE ONLY. It makes NO domain / command / event / RNG / save change and re-pins NOTHING.** Unlike every prior Band-2 story it DOES edit `.tscn` scenes, adds a `Theme` resource, and imports art (F16 is a theme story) — but the scope note holds: **engine project settings, input maps, and save formats stay OUT OF BOUNDS.** There is **no vetoable D-decision unique to 14.11** (D1/D2 → 14.1, D3/D6 → 14.5, D4 → 14.4, D5 → 14.7).

This story **folds four earlier deferrals into its ACs** (the epics AC + the sprint scope annotation are explicit): the **13.2 R1 reward-overlay hardcoded geometry + missing ScrollContainer** and the **13.2 R2 passive-confirm raw `passive_content_id`** (both epics-AC-folded), plus the two **14.10 review defers earmarked to 14.11** — the unconsumed `turn_is_player`/`has_hud` seam fields and the fixed-pixel HUD cosmetics.

### ⭐ THE CRUX — 14.11 IS the Theme + semantic-layout story; it FINISHES what 14.8/14.9/14.10 left as "built-in Controls, no Theme" (read before Task 1)

Four boundaries define this story. Get them wrong and you either overreach into out-of-bounds settings or leave the epic's "look intentional" promise unmet:

1. **BUILD + APPLY the Theme, don't touch project settings.** All six screen scene roots are `Control` (`HeroSelect`, `RouteMap`, `RunEnd`, `Outpost`, `TacticalBoard`, `GameplayShell` — verified). A Godot `Theme` set on a Control root **propagates to all its descendants**, so the **in-bounds way to apply the theme "across screens" is to assign the Theme resource to each scene root's `theme` property** (a `.tscn` / UI-resource edit — expected by the scope note). Do **NOT** set the project-wide `gui/theme/custom` in `project.godot` — that is an **engine project setting (OUT OF BOUNDS)**. Per-scene-root assignment is also more testable: the `test_run_flow_scenes_load.gd` compile guardrail loads every scene, so a broken theme-resource reference is caught automatically.

2. **The frame kit exists and MUST be imported (the 13.1/14.8 discipline).** The Recraft kit is real and in-repo at `asset_sources/icons/ui/{button_plate,panel_frame,modal_frame}.svg` (2048² SVGs; AC1's premise holds — NOT a missing-asset blocker). It is **source-side only** — it is NOT yet under `godot/`. Task 1 copies it into the Godot project at the manifest's declared runtime path **`godot/assets/ui/`**, imports it (generating `*.svg.import` sidecars via a separate `--headless --import` run — the `--scene` test run does NOT emit sidecars), and **commits the `.svg.import` sidecars** (the 13.1 art-import discipline; the in-repo precedent is `godot/assets/art/ui/icons/icon_placeholder.svg.import`, `importer="texture"` → `CompressedTexture2D`). The `asset-manifest.md` `ui.*` rows (lines 99-109) are `planned ☐` precisely because this is the story that assembles them in-engine — update them + the runtime export path per the AGENTS.md asset-provenance discipline.

3. **This story FOLDS the two 13.2 reward-overlay defers — it is the ONLY story that touches the reward overlay in Band 2.** 14.10 was explicitly told NOT to touch the reward overlay because these are 14.11's: (a) the **hardcoded overlay geometry** (`_ensure_reward_overlay` full-rect Panel + fixed 24px `MarginContainer` insets + a plain `VBoxContainer` with **NO `ScrollContainer`**) → replace with semantic-region sizing + a **`ScrollContainer`** so the passive 3-choice modal cannot push the ≥44px targets off a small viewport (folds `deferred-work.md:97`); (b) the **passive-confirm step rendering the raw snake_case `passive_content_id`** ("Confirm Consume of `warrior_unbreakable_guard`?") → render the evocative **`display_name`** the choice list already showed (folds `deferred-work.md:106`).

4. **This story CONSUMES-OR-TRIMS the 14.10 seam spares and FOLDS the 14.10 fixed-pixel cosmetics into the Theme.** The 14.10 review left two Low defers **owned by 14.11** (`deferred-work.md:1504`, `:1512`): the `TacticalHudView` `turn_is_player`/`has_hud` keys the presenter never consumes (consume `turn_is_player` as the themed turn-indicator emphasis hook, optionally `has_hud` to hide the HUD on a runless render — **or trim them**, honoring the 14.3 "seams expose only what the presenter consumes" rule), and the fixed-pixel HUD cosmetics (`_build_hud_controls`/`_add_hud_label`: turn font `22`, HP-bar height `10.0`, VBox `separation` `2`) → **fold into the shared Theme** (the story's own 14.10↔14.11 boundary assigned them here).

### The load-bearing architecture reality (read before Task 1)

- **The live combat surface is `godot/scripts/ui/presenters/tactical_board_presenter.gd`** (the scene-root script of `godot/scenes/game/tactical_board.tscn`, a `Control`). This is the **correct file** — the 14.1 retro flagged that stories mis-named `gameplay_shell_presenter.gd`/`tactical_board_grid.gd`; the live board surface is `tactical_board_presenter.gd`. `tactical_board_grid.gd` is the thin DRAW Control (it replays an op list); all render/fit DECISIONS live in tested `RefCounted` seams.
- **The semantic layout seam is `godot/scripts/ui/view_models/tactical_layout_profile.gd`** (`TacticalLayoutProfile`, RefCounted, scene-free). It classifies an injected viewport → a stable profile id + a value-only region plan (`board`/`preview`/`confirm_cancel`/`inspect`/`status`/`log_or_outcome`) + `control_slots` reachability (`DEFAULT_MINIMUM_TOUCH_TARGET == Vector2(44,44)`; `_region_is_reachable` returns `reachable: false` for a slot under 44px or outside content). **AC2's "layout/region decisions stay on the pinned `TacticalLayoutProfile` seam (verified without a SceneTree)" means: any NEW region/reachability decision goes in (or extends) this seam with a unit test — never as untested presenter scene math.**
- **The board fit is `godot/scripts/ui/view_models/tactical_board_grid_fit.gd`** (`TacticalBoardGridFit`, RefCounted). The presenter fits the grid via `TacticalBoardGridFit.from_region(width, height, rect)` → `fit.available()` → `fit.to_zoom_state(region_size)` in `_render_board_grid()` (`tactical_board_presenter.gd:1115-1151`), sizing the grid from `_board_region_size(layout)` (1157-1162, which prefers the live `_board_panel.size`). **The board already fits its region — but there is NO resize handler** (grep-confirmed: no `NOTIFICATION_RESIZED` / `size_changed` / `_process` in the presenter). `_layout_profile()` (308-315) reads `get_viewport_rect().size` fresh **only when `render()` is called** (on a turn/state change). So on a window resize the board panel resizes but the draw op list stays STALE (drawn at the old cell size) until the next state change — that is the F15 "dead gray zone / doesn't re-scale" gap AC2 calls out.
- **The reward overlay** lives entirely in `tactical_board_presenter.gd`: `render_reward()` (1544), `_ensure_reward_overlay()` (1562, the hardcoded geometry), `_build_generic_reward_ui()` (1588), `_build_passive_reward_ui()` (1618), `_build_passive_confirm_ui()` (1641, the raw-id line at 1644), `_passive_choice_text()` (1688), `_reward_button()` (1710, already ≥44px), `_add_reward_label()` (1718, header font 22). The projection is `RewardHudViewModel.project(offer)` (`godot/scripts/ui/view_models/reward_hud_view_model.gd`); each passive choice already carries `modal.display_name` (and `label = modal.display_name` for a passive — line 147) — **that is the source for the passive-confirm display-name fix.**
- **The HUD** (14.10) lives in `tactical_board_presenter.gd`: `_build_hud_controls()` (888, the fixed cosmetics), `_add_hud_label()` (922), populated from the `TacticalHudView` seam (`godot/scripts/ui/view_models/tactical_hud_view.gd`, the pinned 12-key `VIEW_KEYS` incl. `turn_is_player`/`has_hud`).
- **The route-map display-name sites** are in `godot/scripts/ui/presenters/route_map_presenter.gd`: the pattern `BOSS_DISPLAY_NAME if node_type == RouteNode.TYPE_BOSS else _display_type(node_type)` is **duplicated** at line 135 (the "You are here" line) and line 184 (`_node_label`). The 14.6 retro (§14-6) earmarked to 14.11: *"a single `_display_name(node_type)` helper (boss→const, else `_display_type`) would close all sites at once; do this in the 14.11 theme pass before more name sites appear."*

## Acceptance Criteria

**AC1 — A Godot `Theme` (imported frame kit) styles buttons, panels, and modals across every screen (F16; FR68; NFR9)**
Given the generated Recraft UI frame kit exists in the repo (`asset_sources/icons/ui/button_plate.svg`, `panel_frame.svg`, `modal_frame.svg`)
When a UI theme is applied
Then the kit is **imported into `godot/assets/ui/`** (with its `*.svg.import` sidecars committed — the 13.1 discipline) and a Godot **`Theme`** (StyleBoxes / fonts / spacing) styles **buttons, panels, and modals across screens** — **no default-Godot unstyled `Control` surfaces outside the board** (the Theme is assigned on each screen scene's root `Control`, propagating to descendants; NOT via the out-of-bounds `project.godot` default-theme setting)
And the theme is **presentation only** (no domain / save / RNG change), **degrading gracefully if a kit texture is unresolved** (a null-texture StyleBox draws nothing rather than crashing; the scenes + theme still load — the compile guardrail stays green)
And the **fixed-pixel HUD cosmetics (14.10) fold into the Theme** (the turn-label font, the HP-bar height, the HUD spacing become theme font-sizes/constants, not hardcoded per-widget overrides) and the reward-overlay header font likewise reads from the Theme.

**AC2 — Semantic layout across screens: board scales, reachable ≥44px targets, reward overlay scrolls, passive-confirm shows the display name (F15; FR68; NFR9)**
Given the screens (hero select, route map, tactical HUD, reward/passive overlay, run summary, outpost)
When they lay out on varying window sizes
Then they honor the semantic `TacticalLayoutProfile` region plan — **the board scales to the available space** (no huge dead gray zone; **a resize re-renders scale sensibly** via an event-driven single re-render that re-fits the grid through the existing `TacticalBoardGridFit` — NEVER a per-frame `_process` poll), and reachable targets stay **≥44px** with honest **`reachable: false`** when a region cannot fit (§14.1)
And the **reward-overlay hardcoded geometry is replaced with the semantic region plan + a `ScrollContainer`** so the passive 3-choice modal cannot push targets off a small viewport (folds the 13.2 R1 defer, `deferred-work.md:97`), and the **passive-confirm step renders the evocative `display_name`, not the raw `passive_content_id`** (folds the 13.2 R2 defer, `deferred-work.md:106`)
And the **14.10 `turn_is_player`/`has_hud` seam spares are consumed** (the themed turn indicator reads `turn_is_player`; `has_hud` optionally gates the HUD box) **or trimmed** (honoring the 14.3 "seams expose only what the presenter consumes" rule), and any snake_case node/id display is unified through the single 14.6 `_display_name(node_type)` helper (route map) so no raw snake_case reaches the player.

**AC3 — Pinned-contract posture: no domain/save/RNG change, layout decisions on the `TacticalLayoutProfile` seam (no SceneTree), every fingerprint byte-identical**
Given the pinned contracts
When this story lands
Then **no domain / command / event / RNG / save contract changes**, the **layout/region decisions stay on the pinned `TacticalLayoutProfile` seam** (any new region/reachability logic is unit-tested in a `RefCounted` seam — **no SceneTree presenter test**; the scenes + theme are verified by construction + the `test_run_flow_scenes_load.gd` compile guardrail), and **every pinned fingerprint stays byte-identical** (the 16-key `TacticalBoardViewModel` gate stays 16, the 11-key `RunHudViewModel` gate stays 11, the 12-key `TacticalHudView` gate stays 12 *unless a key is deliberately trimmed*, the 23-key `RunSnapshot` gate stays 23, `ProfileSnapshot`/`SettingsSnapshot` `SCHEMA_VERSION == 1`, the 7 named RNG streams unchanged, no new event/enum value, no new autoload, no new RNG draw site, no re-pinned combat/generation/route/finale fingerprint)
And **14.11 re-pins NOTHING** and touches **no `project.godot` project setting, no input map, no save format.**

## Tasks / Subtasks

- [x] **Task 1 — Import the Recraft frame kit + build the `Theme` resource (AC1, AC3)**
  - [x] Copy `asset_sources/icons/ui/{button_plate,panel_frame,modal_frame}.svg` into **`godot/assets/ui/`** (the manifest's declared runtime path). Run **`godot --headless --import`** (separately from the test run) to generate the three `*.svg.import` sidecars; **commit the sidecars** (the 13.1 discipline). Verify the SVGs import as `CompressedTexture2D` (the `icon_placeholder.svg.import` precedent). Consider an SVG import `scale` only if memory matters — nine-patch scaling handles UI sizing regardless.
  - [x] Create a `Theme` resource (recommended `godot/assets/ui/sealsworn_theme.tres`). Populate:
    - **`Button`** StyleBoxes from `button_plate.svg` (a `StyleBoxTexture` with nine-patch `texture_margin_*` so the plate stretches without corner distortion) for `normal`/`hover`/`pressed`/`disabled`, honoring ≥44px content.
    - **`Panel` / `PanelContainer`** from `panel_frame.svg` (nine-patch `StyleBoxTexture`).
    - A distinct **modal** StyleBox from `modal_frame.svg` for the reward/passive overlay Panel.
    - **Fonts / font sizes** as theme defaults + named type sizes — **fold in the 14.10 turn-label font `22`, the reward header font `22`**, and set a `default_font_size` so no screen shows raw default Godot text sizing.
    - **Constants/spacing** — fold the HUD VBox `separation`, the reward box separation, and comparable spacing into theme constants.
  - [x] **Graceful degradation:** the Theme + every scene must still `load()` if a kit texture is unresolved (a `StyleBoxTexture` with a null texture draws nothing — no crash). Do NOT let a missing texture hard-break the theme resource; keep the scenes green under the compile guardrail.
  - [x] Update `asset_sources/asset-manifest.md` `ui.*` rows (99-109) from `planned ☐` to built + record the `godot/assets/ui/` runtime export path (the AGENTS.md asset-provenance/approval discipline).

- [x] **Task 2 — Apply the Theme across every screen (AC1, AC3)**
  - [x] Assign the Theme to each screen scene root's `theme` property (a `.tscn` edit): `hero_select.tscn`, `route_map.tscn`, `run_end.tscn`, `outpost.tscn`, `tactical_board.tscn`, `gameplay_shell.tscn` (the six `Control` roots). The theme propagates to descendants — no per-widget re-theming needed for the common controls.
  - [x] Sweep the earmarked hardcoded per-widget cosmetics that the Theme now owns — the **14.10 HUD cosmetics** (`_build_hud_controls`/`_add_hud_label`: turn font `22`, HP-bar height `10.0`, VBox `separation` `2`) and the **reward header font `22`** (`_add_reward_label`) — replacing them with theme-driven sizing (`deferred-work.md:1512`). Leave semantic, meaning-bearing overrides that encode state (e.g. a selection-border `StyleBoxFlat`, a turn-indicator emphasis) where they still read best, but no surface should look like raw default Godot.
  - [x] Do **NOT** set `project.godot` `gui/theme/custom` (out-of-bounds project setting). Do **NOT** touch input maps or save formats.

- [x] **Task 3 — Board scales to the window + a resize re-renders (AC2, AC3, the 14.3 inheritance)**
  - [x] Add an **event-driven** resize→re-render so the board re-fits when the window changes: connect the viewport `size_changed` (or the root `Control`'s `resized`) to a single `render()`/board-refit call. **NEVER a `_process`/`_physics_process` poll** (the 14.3 "one draw pass per render, never per-frame" rule this epic ratified). Coalesce with `call_deferred` if a drag fires many events; each event drives one existing render pass (the same path a turn takes), re-fitting the grid through `TacticalBoardGridFit`.
  - [x] Verify the board **fills its region sensibly** (no huge dead gray zone). The fit/region decision is the seam's job: if a large-window dead-margin reads poorly, the lever is `TacticalBoardGridFit`/`TacticalLayoutProfile` (seam-tested), NOT ad-hoc presenter geometry. Keep the ≥44px control slots + honest `reachable: false` degrade intact.

- [x] **Task 4 — Reward overlay: semantic geometry + `ScrollContainer` + passive-confirm `display_name` (AC2, AC3 — folds 13.2 R1 + R2)**
  - [x] Replace `_ensure_reward_overlay()`'s hardcoded geometry (full-rect Panel + fixed 24px `MarginContainer` + plain `VBoxContainer`) with **semantic-region sizing** (size/position from the `TacticalLayoutProfile` content area, not fixed pixels) and wrap the reward `VBoxContainer` in a **`ScrollContainer`** so the passive 3-choice modal (≈6 lines × 3 choices + per-choice Consume/Destroy rows) **scrolls** rather than pushing the ≥44px buttons off the bottom on a small viewport (`deferred-work.md:97`). The overlay Panel takes the `modal_frame` theme StyleBox. Keep the mouse-filter STOP capture (the overlay blocks board input while up) and the `_clear_reward_box` rebuild discipline.
  - [x] Fix the passive-confirm to render the **`display_name`**: thread the `RewardHudViewModel` projection into `_build_passive_confirm_ui` and resolve the armed `passive_content_id` → its projected `display_name` (each passive choice already exposes `modal.display_name` / `label`). Put the lookup in a **pure, testable helper on the `RewardHudViewModel` seam** (e.g. `display_name_for(projection, content_id) -> String`, fail-closed to the raw id if absent) — not untested presenter math (`deferred-work.md:106`). The confirm prompt reads "Confirm Consume of **<Evocative Name>**?", matching the choice list.

- [x] **Task 5 — Consume-or-trim the 14.10 seam spares + unify the route-map display name (AC2, AC3 — folds the 14.10 defers + the 14.6 heuristic)**
  - [x] Resolve the 14.10 `turn_is_player`/`has_hud` defer (`deferred-work.md:1504`): **consume** `turn_is_player` as the themed turn-indicator emphasis (e.g. a themed highlight when it is the player's turn) and optionally `has_hud` to hide the HUD box on a runless render — **OR trim** the unused key(s) from `TacticalHudView.VIEW_KEYS` + its test (honoring the 14.3 "expose only what the presenter consumes" rule). If you trim, the 12-key gate becomes the trimmed count in BOTH the seam and `test_tactical_hud_view.gd` — this is the ONE sanctioned key-set change and it is a deliberate trim, not a drift.
  - [x] Apply the 14.6 single-helper heuristic (§14-6): extract one `_display_name(node_type)` helper in `route_map_presenter.gd` (`return BOSS_DISPLAY_NAME if node_type == RouteNode.TYPE_BOSS else _display_type(node_type)`) and call it at BOTH duplicated sites (line 135 "You are here" + line 184 `_node_label`). Behavior-preserving (both sites already produce identical output) — low-risk consolidation that keeps future name sites consistent. Existing `test_route_map_view_model.gd` stays green.

- [x] **Task 6 — Seam tests + gates held + suite green (AC1, AC2, AC3)**
  - [x] Add a scene-free unit test for the passive-confirm display-name resolver (mirror the `RewardHudViewModel` test style): armed `content_id` → its projected `display_name`; fail-closed to the raw id when the id is absent from the projection; no live handle leaked.
  - [x] If any NEW region/reachability decision was added for the reward overlay or the board scaling, unit-test it in the `RefCounted` seam (`TacticalLayoutProfile`/`TacticalBoardGridFit`). If the overlay just reuses the existing `content_area` + a `ScrollContainer` (no new pure decision), no new layout-seam test is needed.
  - [x] The Theme resource + the scene `theme` wiring are verified **by construction** + the `test_run_flow_scenes_load.gd` compile guardrail (it loads all six presenter scripts + all nine scenes — a broken theme reference or scene edit fails it). Do NOT add a SceneTree presenter test.
  - [x] **`.gd.uid` + `.svg.import` discipline:** run `godot --headless --import` separately; commit the `*.svg.import` sidecars (3 frames) and any new `*.gd.uid` sidecars (new seam helper/tests). The `--scene` test run does not emit sidecars (§14-8).
  - [x] Confirm **no domain/RNG/save/project-setting change**: `project.godot` (no `gui/theme/custom`, no input map), `RunSnapshot` (23-key / `SCHEMA_VERSION == 1`), `RngStreamSet` (7 streams), `DomainEvent`, `TacticalBoardViewModel` (16 keys), `RunHudViewModel` (11 keys), the queries — all byte-untouched. No new autoload, event, or RNG draw site.
  - [x] Run the FULL headless suite (mandatory command below). Baseline **205 PASS files** (post-14.10); expect **≥205** (a new resolver test file pushes ≥206; a key-trim removes none). False-PASS guard `SCRIPT ERROR|Parse Error|^FAIL` on the RAW output = the exactly-6 documented stderr negatives, ZERO new, none referencing a 14.11 file. `git diff --check` clean.

## Dev Notes

### What is ALREADY SHIPPED (reuse / theme — do NOT rebuild)

- **`TacticalLayoutProfile`** (`tactical_layout_profile.gd`, 2.5) — the scene-free semantic region plan + `_control_slot`/`_region_is_reachable` reachability (`DEFAULT_MINIMUM_TOUCH_TARGET == Vector2(44,44)`). The pinned seam AC2's layout decisions must ride. Do NOT re-derive geometry in the presenter.
- **`TacticalBoardGridFit`** (`tactical_board_grid_fit.gd`) — the board cell-fit seam (`from_region`/`available`/`to_zoom_state`). The board already fits its region through it; Task 3 only adds the resize→re-render trigger.
- **`RewardHudViewModel`** (`reward_hud_view_model.gd`, 13.2) — `project(offer)` → `has_offer` + `choices[]` (each with `content_id`, `label`, `modal.display_name`, the full MODAL_KEYS). The **source for the passive-confirm `display_name`** — reuse it; add only a pure resolver helper. Its `REWARD_KEYS`/`CHOICE_KEYS` gates stay unchanged.
- **`TacticalHudView`** (`tactical_hud_view.gd`, 14.10) — the 12-key HUD seam. `turn_is_player`/`has_hud` are the two 14.11-owned spares (consume or trim). Do NOT re-derive HP/gold/bag (there is no run-level HP field — that is why `RunHudViewModel` exists; the 11.1 mis-source trap).
- **The board scenes/presenters** (14.1-14.10) — `tactical_board_presenter.gd` is the live surface (NOT `gameplay_shell_presenter.gd`/`tactical_board_grid.gd`). The HUD, range highlights, reward overlay, and confirm/cancel controls are all built here; 14.11 themes + re-lays them, it does not rebuild them.
- **`route_map_presenter.gd`** (14.6) — `BOSS_DISPLAY_NAME` const + `_display_type` + `_node_label`; the two duplicated boss-vs-type sites are the 14.6 consolidation target.

### The Theme approach — nine-patch StyleBoxes from the 2048² kit, assigned per scene root

The three SVGs are large square frame plates → use them as **`StyleBoxTexture` nine-patch** entries (set `texture_margin_left/right/top/bottom` so only the borders stretch; the center tiles/stretches). `button_plate` → `Button` states; `panel_frame` → `Panel`/`PanelContainer`; `modal_frame` → the reward overlay Panel. Set the Theme's `default_font`/`default_font_size` + named type font sizes (folding the 14.10 font `22`s) and constants (folding the spacings). Assign the finished `.tres` to each of the six `Control` scene roots (`theme` property). Because a Control's theme cascades to children, this styles the whole screen from one assignment — the clean, in-bounds, compile-guardrail-covered path. **Do not** reach for `project.godot`'s default-theme setting (out of bounds).

### The reward-overlay fold (13.2 R1 + R2) — the ONLY reward-overlay touch in Band 2

14.10 was told to leave the reward overlay alone precisely so 14.11 owns it. The two folds:
- **R1 geometry + scroll** (`deferred-work.md:97`): `_ensure_reward_overlay` currently hardcodes a full-rect Panel + fixed 24px margins + a scroll-less VBox → replace with content-area sizing + a `ScrollContainer`. The ≥44px `_reward_button` minimum is already set; the ScrollContainer is what guarantees "targets reachable on every layout profile" for the tall passive modal.
- **R2 display_name** (`deferred-work.md:106`): `_build_passive_confirm_ui` shows `content_id` (line 1644) → resolve the projected `display_name`. Keep it a pure seam helper + test (AC3's "assertable logic in RefCounted seams").

### NFR9 — the non-color channel stays mandatory (do not regress)

Theming must not remove the shape/pattern/text channels the Band-2 stories added: the HUD text labels + HP-bar length, the move-range ring vs attack-range corner-tick shapes + legend, the word turn indicator ("Your Turn"/"Enemy Turn"), the passive arm/confirm label change + Cancel, the selection border + "✓ Selected" marker. A StyleBox is a color/texture layer ON TOP of these — never a replacement. A themed turn indicator that emphasizes `turn_is_player` must still carry the word label, not a bare color swatch.

### Deferred-work overlaps folded in (and the ONE to leave deferred)

- **13.2 R1 reward-overlay hardcoded geometry + ScrollContainer (`deferred-work.md:97`) → FOLDED (Task 4).** Mark it **RESOLVED by 14.11** in `deferred-work.md` on completion.
- **13.2 R2 passive-confirm raw `passive_content_id` (`deferred-work.md:106`) → FOLDED (Task 4).** Mark **RESOLVED by 14.11**.
- **14.10 `turn_is_player`/`has_hud` unconsumed spares (`deferred-work.md:1504`) → FOLDED (Task 5, consume or trim).** Mark **RESOLVED by 14.11**.
- **14.10 fixed-pixel HUD cosmetics (`deferred-work.md:1512`) → FOLDED (Tasks 1-2, into the Theme).** Mark **RESOLVED by 14.11**.
- **14.6 single `_display_name(node_type)` helper (retro §14-6, earmarked to 14.11) → FOLDED (Task 5).**
- **13.2 R1 `_inspect_facts_from` untested presenter transform (`deferred-work.md:98`) → LEAVE DEFERRED (default).** It is optional hardening in the SAME presenter, owned by "a later board-polish / test-hardening pass". 14.11 has no AC requiring it. Extract into a tiny `RefCounted` seam + test ONLY if you are already refactoring the inspect region for another reason — otherwise leave it deferred (do not expand scope).
- **The Band-1/2 on-device human-playtest defer (standing across 14.1-14.10) → EXTENDED and now DUE.** 14.11 is the epic's LAST story — the themed screens are automated-green (compile guardrail + seam tests) but human-unverified (no SceneTree test). Add to the on-device checklist: every screen looks themed (framed buttons/panels/modals, no raw default Godot surfaces); the board fills the window and re-scales on resize (no dead gray zone); the reward/passive modal scrolls and keeps ≥44px targets reachable on a small viewport; the passive-confirm shows the evocative name; no snake_case reaches any player label. This is the Band-2 close gate — confirm the on-device playtest happens.

### Epic-14 constraints inherited (retro-notes/epic-14.md + the sprint change)

- **One draw pass per render, never per-frame `_process` (§14-3):** the Task-3 resize handler is EVENT-DRIVEN (a single render per resize event), never a poll loop.
- **Render from the bound session, not empty presenter state (§14-3 systemic):** if you touch any live render path, source it from the bound session/run (the 14.2/14.3/14.10 precedent) — do not source a live slot from empty presenter state.
- **Seams expose only what the presenter consumes (§14-3):** this is exactly why `turn_is_player`/`has_hud` are a consume-or-trim decision. Whatever you keep, the presenter must consume it.
- **EXACT files (§14-1 "wrong files" precision):** the live board surface is `tactical_board_presenter.gd`; the semantic layout seam is `tactical_layout_profile.gd`.
- **`str(...)` not eager `String(nullable)` in assert messages (§14-1);** keep the false-PASS grep guard standing (the 6 documented stderr negatives: int64-overflow ×2 [`test_domain_event.gd:146` + `test_manual_seed_loader.gd:153`], malformed-JSON ×3, `invalid_node_type` ×1).
- **One display-name helper closes all sites (§14-6):** the route-map `_display_name` consolidation + the passive-confirm `display_name` are the two applications this story owes.
- **`.gd.uid` via `--headless --import` (§14-8)** + the same `--import` run for the new `.svg.import` art sidecars; commit both.
- **Difficulty stays a hard non-goal; 14.11 re-pins nothing; no new autoload; the scenes are verified by construction + the compile guardrail.**

### Anti-patterns to avoid (this story specifically)

- **Do NOT set `project.godot` `gui/theme/custom`, edit any input map, or touch a save format** — all out of bounds. Assign the Theme on each scene ROOT `Control`.
- **Do NOT skip the `.svg.import` commit** — import via `--headless --import` and commit the three sidecars (the 13.1 discipline). A theme referencing an un-imported texture would fail to draw.
- **Do NOT add a `_process`/per-frame resize poll** — event-driven single re-render only (§14-3).
- **Do NOT hand-format geometry in the presenter for the reward overlay or board** — size from the `TacticalLayoutProfile` seam; put any new region decision in the seam with a test (AC3).
- **Do NOT render the raw `passive_content_id` (or any snake_case id) to the player** — resolve the `display_name`; unify the route-map name via the single helper.
- **Do NOT re-implement HUD/reward/highlight DATA** — 14.11 themes + re-lays the shipped surfaces; it does not re-derive HP/gold/bag/choices.
- **Do NOT add a board-VM key** — the 16-key `TacticalBoardViewModel` gate holds; the HUD/reward/highlights stay SEPARATE read surfaces.
- **Do NOT rely on color alone for any state** (NFR9) — the Theme adds texture/color ON TOP of the existing text/shape channels; keep them.
- **Do NOT add a SceneTree presenter test** — decisions go in `RefCounted` seams; the scenes are verified by construction + the compile guardrail.
- **Do NOT touch any domain/command/event/RNG/save file** — presentation/theme/scene only; re-pin NOTHING.
- **Keep the false-PASS grep guard standing** — grep the RAW runner output for `SCRIPT ERROR|Parse Error|^FAIL`; exactly the 6 documented negatives; ZERO new. Never trust the summary PASS line alone.

## Project Structure Notes

- **Files touched (production):**
  - NEW art: `godot/assets/ui/{button_plate,panel_frame,modal_frame}.svg` (+ their `*.svg.import` sidecars) — copied from `asset_sources/icons/ui/`.
  - NEW resource: a `Theme` `.tres` (recommended `godot/assets/ui/sealsworn_theme.tres`).
  - MODIFIED scenes (`.tscn` — theme assignment on the root `Control`): `hero_select.tscn`, `route_map.tscn`, `run_end.tscn`, `outpost.tscn`, `tactical_board.tscn`, `gameplay_shell.tscn`.
  - MODIFIED presenters: `tactical_board_presenter.gd` (reward-overlay geometry + ScrollContainer + passive-confirm display_name; the resize→re-render hookup; fold the HUD/reward fixed cosmetics into the theme; consume-or-trim `turn_is_player`/`has_hud`) and `route_map_presenter.gd` (the single `_display_name` helper). Possibly small touches to `hero_select_presenter.gd`/`outpost_presenter.gd`/`run_end_presenter.gd` only to remove now-theme-owned hardcoded overrides.
  - MODIFIED seams (pure, testable): `reward_hud_view_model.gd` (add the `display_name_for` resolver) and/or `tactical_hud_view.gd` (only if trimming a key). `tactical_layout_profile.gd`/`tactical_board_grid_fit.gd` only if a new region/fit decision is added.
  - MODIFIED docs: `asset_sources/asset-manifest.md` `ui.*` rows (provenance/approval discipline).
- **Tests:** a new scene-free unit test for the display-name resolver under `godot/tests/unit/ui/`; extend the relevant seam test if a key is trimmed or a region decision added. No new SceneTree test — the scenes stay verified by construction + `godot/tests/unit/ui/test_run_flow_scenes_load.gd`.
- **Out of bounds:** `project.godot` (project settings / input map), any `scripts/tactical|rules|generation|ai|save|core` file, any save format. The board queries + domain are byte-untouched.

## Project Context Rules

Extracted from `project-context.md` (canonical rulebook) and the architecture (`_bmad-output/game-architecture.md`):

- **Domain owns truth; presentation observes + submits commands (NFR14/NFR15; hard architecture rule).** 14.11 is theme + layout over the shipped view-models/presenters; the UI owns no tactical/run truth and mutates nothing.
- **Save truth = versioned domain snapshots (NFR15).** No save change: the 23-key `RunSnapshot` gate stays 23; `ProfileSnapshot`/`SettingsSnapshot` `SCHEMA_VERSION == 1`; no serialized presentation/theme state.
- **Named RNG only; deterministic under seed (NFR13).** 14.11 draws ZERO RNG; the 7 named streams are unchanged, unreordered.
- **Assertable logic lives in scene-free `RefCounted` seams** with pinned exact-key sets (no SceneTree presenter tests — verify by construction + the compile guardrail). No new autoload.
- **Adaptive UI via view models, presenters, layout profiles, and a command bridge (additional requirement).** The board + reward overlay honor the `TacticalLayoutProfile` region plan + control-slot reachability (≥44px, honest `reachable: false`); the theme is a Godot `Theme` resource on the Control roots.
- **Color-independence (NFR9).** The Theme layers texture/color on top of the existing text/shape channels; every HUD/turn/highlight/reward state keeps a non-color channel.
- **Static content + AI-assisted assets pass validation + human approval; track provenance (AI/asset rules).** The Recraft frame kit is source-approved (in-repo); record the runtime export path + built status in `asset-manifest.md`. Placeholder assets stay marked/separate (NFR18) — degrade gracefully if a kit texture is unresolved.
- **Difficulty is a hard non-goal.** 14.11 changes no enemy/HP/damage/reward/run-length number.
- **Every generator/route/finale/combat seed-regression fingerprint stays byte-identical** (14.11 touches only `scripts/ui/`, `scenes/`, `assets/ui/`). **14.11 re-pins NOTHING** (including the 14.1-re-pinned combat replay at seed 24680 and the seed-1337 Medium seer proof, untouched).
- **Headless suite stays green** (205 PASS baseline post-14.10; expect ≥205; false-PASS grep `SCRIPT ERROR|Parse Error|^FAIL` clean beyond the 6 documented negatives).

### Mandatory test command (must pass before this story moves to review/done)

```
godot --headless --path C:\Sealsworn\godot --scene res://tests/headless/test_runner.tscn --quit-after 10
```

`godot` is not on the Bash/`where` PATH; run via PowerShell (`C:\Users\Rasmus\bin\godot.cmd`, or the standalone `C:/Users/Rasmus/Godot_v4.6.3-stable_win64.exe/Godot_v4.6.3-stable_win64_console.exe`). Apply the false-PASS grep guard `SCRIPT ERROR|Parse Error|^FAIL` on the RAW output (never trust the summary PASS line alone). The runner auto-discovers `test_*.gd` under `res://tests/unit` and `res://tests/integration` only. Baseline **205 PASS files** (post-14.10); expect **≥205**, ZERO new stderr negatives beyond the 6 documented. Run `godot --headless --import` separately to emit the new `*.svg.import` (3 frames) + any new `*.gd.uid` sidecars before committing.

### References

- `_bmad-output/planning-artifacts/epics.md#Epic 14: Playable & Presentable` — Story 14.11 ACs (body lines 3207-3227, which fold the 13.2 R1/R2 defers); the Band-2 demarcation (Epic List entry lines 521-527); FR68/NFR9 (lines 158, 182).
- `_bmad-output/planning-artifacts/sprint-change-proposal-2026-07-16.md` — **F15/F16** the no-theme / dead-gray-board finding (line 30); the **14.11 scope row** (line 146); the "theme story deliberately last" note (lines 84-86); the folded-defer ownership map (lines 165 → 14.11).
- `_bmad-output/auto-gds/retro-notes/epic-14.md` — **§14-6** the single `_display_name(node_type)` helper heuristic earmarked to 14.11; **§14-3** the one-draw-per-render / render-from-session / seams-expose-only-consumed rules; **§14-1** the "wrong files" precision (`tactical_board_presenter.gd`) + `str(...)`-not-`String(nullable)` + the false-PASS grep; **§14-8** the `.gd.uid`/import discipline; **§14-10** the seam-key-vs-consumption tension (`turn_is_player`/`has_hud`) reconciled here.
- `_bmad-output/implementation-artifacts/deferred-work.md` — line **97** (13.2 R1 reward-overlay geometry + ScrollContainer → FOLD), line **106** (13.2 R2 passive-confirm `display_name` → FOLD), line **1504** (14.10 `turn_is_player`/`has_hud` → consume/trim), line **1512** (14.10 fixed-pixel HUD cosmetics → Theme), line **98** (13.2 R1 `_inspect_facts_from` → LEAVE DEFERRED), plus the standing Band-1/2 on-device human-playtest defer (extended + now due at Band-2 close).
- `_bmad-output/implementation-artifacts/14-10-player-hud-and-range-highlights.md` — the ratified Band-2 presentation story shape (RefCounted seams, no-SceneTree test, verify-by-construction, `.gd.uid` discipline) and the explicit 14.10↔14.11 theme boundary this story now delivers on.
- `asset_sources/asset-manifest.md` — the UI frames section (lines 96-109): the frame kit `icons/ui/{button_plate,panel_frame,modal_frame}.svg`, the `ui.*` `planned ☐` rows, the `godot/assets/ui/` runtime path 14.11 builds.
- Source files (read before implementing):
  - `godot/scripts/ui/presenters/tactical_board_presenter.gd` — `_layout_profile` (308-315, viewport→profile, no resize handler); `_render_board_grid` (1115-1151) + `_board_region_size` (1157-1162, the fit); `_build_hud_controls`/`_add_hud_label` (888-928, the 14.10 fixed cosmetics); `render_reward` (1544) + `_ensure_reward_overlay` (1562-1583, hardcoded geometry) + `_build_passive_reward_ui` (1618) + `_build_passive_confirm_ui` (1641-1650, raw-id at 1644) + `_add_reward_label` (1718-1724, header font 22) + `_reward_button` (1710, ≥44px).
  - `godot/scripts/ui/view_models/tactical_layout_profile.gd` — the region plan + `_control_slot`/`_region_is_reachable` (231-270); `DEFAULT_MINIMUM_TOUCH_TARGET` (33). The pinned layout seam.
  - `godot/scripts/ui/view_models/tactical_board_grid_fit.gd` — the board cell-fit seam (Task 3's re-fit lever).
  - `godot/scripts/ui/view_models/reward_hud_view_model.gd` — `project` (84) + `CHOICE_KEYS` (61) + the per-choice `modal.display_name`/`label` (147). The passive-confirm display-name source.
  - `godot/scripts/ui/view_models/tactical_hud_view.gd` — `VIEW_KEYS` (39-52) incl. `turn_is_player` (82) + `has_hud` (72); the 14.6 centralized turn-label map (54-100). Consume or trim the two spares.
  - `godot/scripts/ui/presenters/route_map_presenter.gd` — `BOSS_DISPLAY_NAME` (37); the duplicated boss-vs-type sites at 135 + 184; `_display_type` (191-194). The 14.6 `_display_name` consolidation.
  - Scenes (theme assignment): `godot/scenes/ui/{hero_select,route_map,run_end,outpost}.tscn`, `godot/scenes/game/{tactical_board,gameplay_shell}.tscn` — all `Control` roots.
  - `godot/assets/art/ui/icons/icon_placeholder.svg.import` — the `.svg.import` precedent (`importer="texture"` → `CompressedTexture2D`).
  - Tests: `godot/tests/unit/ui/test_run_flow_scenes_load.gd` (the compile guardrail — loads every scene + presenter; backstops the theme wiring); `godot/tests/unit/ui/test_reward_hud_view_model.gd` (the resolver-test style to mirror).

## Dev Agent Record

### Agent Model Used

Story context by Claude Opus 4.8 (gds-create-story). Implementation by Claude Opus 4.8 (gds-dev-story).

### Debug Log References

- Baseline suite (pre-change): **205 PASS**, exit 0, false-PASS guard `SCRIPT ERROR|Parse Error|^FAIL` = 0, the 6 documented stderr `ERROR:` negatives present unchanged (int64-overflow ×2, `invalid_node_type` ×1, malformed-JSON ×3).
- `godot --headless --import` (separate run) generated the 3 `*.svg.import` sidecars (`importer="texture"` → `CompressedTexture2D`) + the tool `build_sealsworn_theme.gd.uid`.
- Theme generated via `godot --headless --script res://tools/build_sealsworn_theme.gd` → `godot/assets/ui/sealsworn_theme.tres` (guaranteed-valid; the repo's first `.tres`).
- Theme-wiring checkpoint (after the 6 `.tscn` edits, before code edits): **205 PASS**, guard 0, `test_run_flow_scenes_load.gd` green (it loads all six themed scenes + the theme + kit textures).
- Final suite (all changes): **205 PASS**, exit 0, guard 0; the 6 documented negatives unchanged, ZERO new, none referencing a 14.11 file; `git diff --check` clean. Kept 205 files (the resolver test extends the existing `test_reward_hud_view_model.gd` rather than adding a file — still ≥205).

### Completion Notes List

- **AC1 (Theme built + applied, F16/FR68/NFR9):** Imported the Recraft kit into `godot/assets/ui/` and assembled `sealsworn_theme.tres` — nine-slice `StyleBoxTexture` skins for `Button` (all 5 states) + `Panel`/`PanelContainer` (border frames, `draw_center=false`, so the existing dark app bg + light font stay readable — the plates carry a white bg) + a distinct opaque `RewardOverlay` modal frame from the dark `modal_frame`. Applied **per scene-root** on all six `Control` roots via the `.tscn` `theme` property (NOT `project.godot` `gui/theme/custom`). Folded the 14.10/13.2 fixed-pixel cosmetics into the Theme: turn font `22` → `HudTurnLabel`/`HudTurnLabelActive`; reward header `22` → `RewardHeader`; HUD `separation 2` → `HudBox`; reward `separation 8` → `RewardBox`; HP-bar height `10` → `HudHpBar` `bar_height` constant; `default_font_size=16`. Graceful degradation: a null kit texture yields a null-texture StyleBox (draws nothing, no crash); the HP-bar height read has a safe fallback const.
- **AC2 (semantic layout, F15/FR68/NFR9):** Task 3 adds an EVENT-DRIVEN resize→re-render (`get_viewport().size_changed` → coalesced `call_deferred` → `_relayout_regions()` + `render()` + reward re-position) — never a `_process` poll — so the board re-fits its resized region through the existing `TacticalBoardGridFit` (closing the F15 stale-panel gap). Reward overlay rebuilt as a full-rect scrim + a content_area-sized centered modal + a `ScrollContainer` (folds 13.2 R1). Passive-confirm now renders the evocative `display_name` via the new `RewardHudViewModel.display_name_for` resolver (folds 13.2 R2). Consumed `turn_is_player` (themed active-turn variation, word retained) + `has_hud` (hide the HUD on a runless render). Route-map name unified through the single `_display_name(node_type)` helper (folds the 14.6 heuristic).
- **AC3 (pinned posture, re-pins nothing):** No domain/command/event/RNG/save/project-setting file touched — only `scripts/ui/`, `scenes/`, `assets/ui/`, `tools/`, docs. The 12-key `TacticalHudView` gate stays 12 (consumed, not trimmed). No new board-VM key, autoload, event, or RNG draw. `RewardHudViewModel` `REWARD_KEYS`/`CHOICE_KEYS` unchanged (the resolver is a read helper). Every generator/route/finale/combat fingerprint byte-untouched. `project.godot` unmodified.
- **Layout-seam tests:** No NEW region/reachability decision was added — the reward overlay reuses the existing `content_area` + a `ScrollContainer` and the board re-fit reuses `TacticalBoardGridFit` — so per the story no new layout-seam test is needed. The Theme + scene wiring are verified by construction + the `test_run_flow_scenes_load.gd` compile guardrail (no SceneTree presenter test).
- **Deferred:** `_inspect_facts_from` untested transform (13.2 R1, `deferred-work.md:98`) intentionally LEFT DEFERRED (out of 14.11 scope). The standing Band-1/2 on-device human visual pass is now DUE (Band-2 close gate) — the themed screens are automated-green but human-unverified; the manifest `ui.*` `Approved` ☐ awaits it.
- **Deviations:** (1) The resolver test extends the existing `test_reward_hud_view_model.gd` rather than adding a new file (still ≥205; the seam's test belongs with the seam). (2) A one-shot generator tool `tools/build_sealsworn_theme.gd` is kept (repo `tools/` precedent) for guaranteed-valid theme assembly + regeneration provenance; it is not auto-discovered by the runner. (3) Did not add a `baseline_commit` frontmatter (delegate does not run git; the orchestrator owns pipeline/baseline). (4) Nine-patch texture margins (button 20 / panel 24 / modal 96, in 2048² space) are reasonable defaults — visual fidelity is tunable in the deferred on-device pass, not gated by the verify-by-construction suite.

### File List

**New (art + resource + tool):**
- `godot/assets/ui/button_plate.svg` (+ `.svg.import`)
- `godot/assets/ui/panel_frame.svg` (+ `.svg.import`)
- `godot/assets/ui/modal_frame.svg` (+ `.svg.import`)
- `godot/assets/ui/sealsworn_theme.tres`
- `godot/tools/build_sealsworn_theme.gd` (+ `.gd.uid`)

**Modified (scenes — theme assignment on the root Control):**
- `godot/scenes/ui/hero_select.tscn`
- `godot/scenes/ui/route_map.tscn`
- `godot/scenes/ui/run_end.tscn`
- `godot/scenes/ui/outpost.tscn`
- `godot/scenes/game/tactical_board.tscn`
- `godot/scenes/game/gameplay_shell.tscn`

**Modified (presenters + seam + test + docs):**
- `godot/scripts/ui/presenters/tactical_board_presenter.gd` (resize→re-render; reward overlay geometry + ScrollContainer + modal stylebox + passive-confirm display_name; fold HUD/reward cosmetics into the Theme; consume `turn_is_player`/`has_hud`)
- `godot/scripts/ui/view_models/reward_hud_view_model.gd` (new pure `display_name_for` resolver)
- `godot/scripts/ui/presenters/route_map_presenter.gd` (single `_display_name(node_type)` helper at both boss-vs-type sites)
- `godot/tests/unit/ui/test_reward_hud_view_model.gd` (resolver test)
- `asset_sources/asset-manifest.md` (`ui.*` rows → built + frame-kit/theme rows)
- `_bmad-output/implementation-artifacts/deferred-work.md` (4 items marked RESOLVED by 14.11)

### Change Log

- 2026-07-19 — Implemented Story 14.11 (UI Theme + semantic layout). Built + applied the shared Godot `Theme` from the Recraft frame kit across the six screen roots; added event-driven board resize re-render; reworked the reward overlay to content-area geometry + `ScrollContainer` + modal frame + evocative passive-confirm name; consumed the 14.10 `turn_is_player`/`has_hud` seam spares; unified the route-map display name. Folded 4 deferred items (13.2 R1/R2, 14.10 spares/cosmetics). No domain/RNG/save/project-setting change; suite 205 PASS. Status → review.

### Review Findings

**Round 1 of 3**

**Verdict: Approve** — Critical 0 / High 0 / Med 0 / Low 2; 0 open `[Review][Decision]`. Primary adversarial `gds-code-review` of the branch diff vs base `story/14-10-player-hud-and-range-highlights` (merge-base `5685127`). Suite INDEPENDENTLY re-run on the review head: **205 PASS / 0 `^FAIL`** (exit 0; false-PASS guard `SCRIPT ERROR|Parse Error|^FAIL` clean; exactly the 6 documented stderr `ERROR:` negatives reproduced — int64-overflow ×2 / malformed-JSON ×3 / `invalid_node_type` ×1, ZERO new, NONE referencing a 14.11 file; `git diff --check` clean).

**Scope verified clean.** The diff is exactly the story's declared surface: six `.tscn` roots (each adds ONLY a `load_steps` bump + one Theme `ext_resource` + the `theme = ExtResource(...)` line — NO node-tree surgery), `godot/assets/ui/` (3 real 2048² SVGs + 3 `importer="texture"` → `CompressedTexture2D` `.svg.import` sidecars + `sealsworn_theme.tres`), the `tools/build_sealsworn_theme.gd` (+`.gd.uid`) generator, two presenters, the `RewardHudViewModel` resolver, and one test. `project.godot` / input maps / save formats / all `scripts/{tactical,rules,generation,ai,save,core}` files are UNTOUCHED (not in the diff). No new domain/RNG/save `preload`.

**ACs verified TRUE against source.** AC1 — Theme `.tres` skins `Button` (5 states) + `Panel`/`PanelContainer` (nine-patch `StyleBoxTexture`) + a distinct opaque `RewardOverlay` modal frame, assigned per scene-root (NOT via `project.godot` `gui/theme/custom`); the 14.10/13.2 fixed-pixel cosmetics (turn font 22, reward header 22, HUD sep 2, reward sep 8, HP-bar height 10) fold into Theme variations; graceful degradation holds (null-texture StyleBox + `HUD_HP_BAR_FALLBACK_HEIGHT == 10 ==` the Theme's `HudHpBar/bar_height`, so no observable discrepancy). AC2 — resize is EVENT-DRIVEN (`viewport.size_changed` → `_resize_pending`-coalesced `call_deferred("_apply_resize")` → `_relayout_regions()` + `render()`); grep-confirmed NO `_process`/`_physics_process` definition (every hit is an explanatory comment); the region panels re-flow and their anchored children (Wait BOTTOM_WIDE, Confirm/Cancel TOP_WIDE, HUD FULL_RECT) re-flow with them, and `render()` re-fits the grid via the existing `TacticalBoardGridFit` — the F15 stale-panel gap is genuinely closed end-to-end. Reward overlay = full-rect scrim (mouse STOP) → content-area-sized centered modal → `ScrollContainer` → `_reward_box`; passive-confirm resolves `RewardHudViewModel.display_name_for` (pure, fail-closed, unit-tested). `turn_is_player`/`has_hud` CONSUMED (themed active-turn emphasis with the word retained per NFR9; `has_hud` hides the HUD on a runless render — `has_hud == has_run`, so live combat is unaffected). Route-map `_display_name(node_type)` unifies both boss-vs-type sites (behavior-preserving). AC3 — 12-key `TacticalHudView` gate held (consumed, NOT trimmed); `RewardHudViewModel` `REWARD_KEYS`/`CHOICE_KEYS` unchanged (resolver is a read helper); no new autoload/event/RNG draw; asset provenance tracked in `asset-manifest.md` (`built`; `Approved ☐` legitimately awaits the on-device pass). The 4 folded defers (13.2 R1/R2, 14.10 spares/cosmetics) are correctly marked RESOLVED-by-14.11 in `deferred-work.md`; `_inspect_facts_from` correctly LEFT deferred.

- [ ] [Review][Defer] (Low, from code review of 14-11, 2026-07-19) — The `Button` Theme skins are visually IDENTICAL across all five states (`normal`/`hover`/`pressed`/`disabled`/`focus` each use `button_plate.svg`, `texture_margin 20`, `draw_center=false`), so themed buttons show NO hover/pressed/disabled visual feedback — a subtle interaction-legibility regression vs Godot's built-in default theme, which differentiates those states. NFR9 non-color channels (text label + ≥44px target) stay intact, so this is presentation polish only, not a functional/AC defect (AC1 requires a StyleBox per state, which exists; it does not require them to differ). Story deviation #4 explicitly defers nine-patch/visual fidelity to the on-device pass. Owner: fold into the standing Band-1/2 on-device visual pass — differentiate pressed/hover/disabled via distinct plates or a `modulate`/border shift.
- [ ] [Review][Defer] (Low, from code review of 14-11, 2026-07-19) — `_position_reward_modal` (`tactical_board_presenter.gd`) derives the modal rect from the pinned `TacticalLayoutProfile.content_area` (correct) but then applies presenter-side magic-number caps (`cw*0.9`/`ch*0.85`, floors `320`/`240`) that are untested presenter geometry. Bounded (never exceeds `content_area`; a degenerate viewport falls back to the full scrim rect) and non-correctness-affecting (target reachability is guaranteed by the `ScrollContainer` + the ≥44px `_reward_button` minimum, not by these caps), but mildly at odds with AC3's "layout decisions on the pinned seam, unit-tested in a `RefCounted` seam" discipline — the same posture that keeps `_inspect_facts_from` on the deferred-hardening list. Optional hardening: lift the modal-size policy into a tested seam (e.g. a `TacticalLayoutProfile.modal_rect(...)`) if the reward region is revisited. Not blocking.
