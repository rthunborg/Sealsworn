# Investigation: Desktop playtest — black tactical board + route_map_presenter get_node error

## Hand-off Brief

1. **What happened.** The board is not black by defect — the shipped tactical-board presentation renders the entire board region as ONE summary text label with zero tile/unit visuals and ZERO input handlers, so a human cannot play a fight (Confirmed, `godot/scripts/ui/presenters/tactical_board_presenter.gd:139`); the console `get_node()` error is a separate benign ordering bug in `route_map_presenter._ready` (Confirmed, `godot/scripts/ui/presenters/route_map_presenter.gd:31-32`).
2. **Where the case stands.** Concluded — both symptoms root-caused with High confidence; the board gap is the already-ledgered 12-1 `[Review][Defer]` (pixel→cell hit-testing "owned by a later on-device input story") plus the never-scoped visual tile render; human playtesting of the combat loop is blocked until that story ships.
3. **What's needed next.** Create a story (via sprint planning — sprint-status has no open work) for the live board visual render + pixel→cell tap input; optionally quick-fix the cosmetic route_map error.

## Case Info

| Field            | Value                                                                      |
| ---------------- | -------------------------------------------------------------------------- |
| Ticket           | N/A (first human desktop playtest after Epic 10 close)                     |
| Date opened      | 2026-07-13                                                                 |
| Status           | Concluded                                                                  |
| System           | Windows 11, Godot 4.6.3 stable editor binary, NVIDIA RTX 3070 Ti, Vulkan Forward Mobile |
| Evidence sources | User screenshot (board screen), console snippet (ERROR + backtrace), source code, deferred-work ledger |

## Problem Statement

User launched the game (`boot.tscn` via the desktop editor binary), progressed to a combat board, and reported "it failed very quickly": the board area is black (only debug-style text labels render: "Board 8x8 — 4 occupants", HP/node/affinity status lines), and the console shows `ERROR: Can't use get_node() with absolute paths from outside the active scene tree` at `route_map_presenter.gd:32 _ready`.

## Evidence Inventory

| Source   | Status    | Notes     |
| -------- | --------- | --------- |
| User screenshot | Available | Board screen: 6 text labels render correctly; board area empty/dark |
| Console snippet | Available | Single ERROR at `route_map_presenter.gd:32` in `_ready`; game continued running |
| Source code | Available | All presenters, SceneManager, flow router read |
| Deferred-work ledger | Available | 12-1 `[Review][Defer]` (Low): gesture→cell pixel hit-testing deliberately not implemented |
| 10-6 MVP readiness gate | Available | "10/10 loop steps present"; rows 6/7 qualified integration-proven |

## Findings

### Confirmed

1. **The board region renders as one text label — there are no tile, unit, grid, or sprite visuals at all.** `tactical_board_presenter.gd:139-141` sets the entire "board" region to `"Board %dx%d — %d occupants"`. Each of the 6 semantic regions (`board`, `preview`, `confirm_cancel`, `inspect`, `status`, `log_or_outcome`) is a `Panel` + `Label` pair (`:78-92`). What the user saw IS the complete shipped render — the screen is working as coded.
2. **No input path exists on the board.** `grep` for `_input|gui_input|pressed|Button` over `tactical_board_presenter.gd` and `gameplay_shell_presenter.gd` returns zero hits. Every tap method takes an already-resolved `target_cell: Vector2i` (`interactive_submit_move(target_cell)` `:312`, `interactive_tap_attack(target_cell)` `:323`) — only tests/programmatic callers can drive a fight. A mouse click on the board does nothing.
3. **This gap is ledgered.** `deferred-work.md`, 12-1 entry: "gesture→cell pixel hit-testing … is deliberately NOT implemented in 12.1: no board-geometry hit-test exists today … a later on-device input story owns the pixel→cell hit-test." The presenter's own header comments say "Verified BY CONSTRUCTION" — the testable logic (VM/bridge/session) is unit-tested; the visual/input surface was consciously out of scope.
4. **Hero select and route map DO have working buttons** (`hero_select_presenter.gd:55-79` builds `Button`s with `pressed` handlers) — which is exactly why the user progressed to the board before hitting the wall.
5. **The console error's site**: `route_map_presenter.gd:29-33` — `_ready()` calls `_render_map()` (line 31) and THEN `has_node("/root/Diagnostics")` (line 32).

### Deduced

6. **Console-error mechanism (High confidence).** On a fresh run, the run parks on the unresolved depth-0 opening combat node, so `_render_map()` takes the resolve-then-advance branch and synchronously calls `SceneManager.go_to_stage("tactical_board")` → `get_tree().change_scene_to_file(...)` (`scene_manager.gd:14-28`) **during `route_map_presenter._ready`**. Godot 4's `change_scene_to_file` removes the current scene from the tree immediately (the new scene is added deferred); control then returns to `_ready` line 32, whose `has_node("/root/Diagnostics")` now executes on a node outside the active scene tree → the engine ERROR. **Benign**: navigation succeeded (the screenshot shows the board), only the diagnostics log line was skipped. Chain: fresh run → `_render_map` navigates away mid-`_ready` → line 32 runs out-of-tree.
7. **The game "failing very quickly" is a perception of the presentation gap, not a crash.** The app was alive (labels updating, run state HP 18/18 / Node 0/12 / Darkness affinity correct). The player simply has nothing to see or click on the board.

### Hypothesized

8. *(Refuted)* "Black board = rendering failure (shader/viewport/Darkness fog)." — Status: **Refuted** by Finding 1: no board visuals exist to fail. Darkness sight reduction (4→2) affects the domain visibility model, not the (absent) render.

## Source Code Trace

- **Error origin:** `godot/scripts/ui/presenters/route_map_presenter.gd:32` (`has_node("/root/Diagnostics")` after a mid-`_ready` scene change triggered at `:31` via the resolve-then-advance branch).
- **Trigger:** Fresh run whose current node is an unresolved live (combat/elite/boss) node when route_map enters the tree.
- **Board gap origin:** `godot/scripts/ui/presenters/tactical_board_presenter.gd:139` (text-only board region) + absence of any `_gui_input`/hit-test (whole file; also `gameplay_shell_presenter.gd`).
- **Related:** `godot/scripts/autoloads/scene_manager.gd:14-28`; `_bmad-output/implementation-artifacts/deferred-work.md` (12-1 entry); `_bmad-output/planning-artifacts/mvp-readiness-gate.md` §3 (loop-step qualifiers).

## Final Conclusion

**Confidence: High.** Two independent root causes, both Confirmed:

1. **The board is "black" because no board visual render was ever built** — the tactical board presenter is a text-label read of the view model, and no pixel→cell input mapping exists, so the hands-on combat loop is **not human-playable on desktop today**. The domain-side interactive session, command bridge, and winnability proofs are complete and green; the missing piece is purely the presentation/input layer (the ledgered 12-1 deferral plus a visual tile render that was never scoped as its own story).
2. **The console ERROR is a benign one-line ordering bug** in `route_map_presenter._ready` (diagnostics probe after a synchronous mid-`_ready` scene change). Trivial fix: guard with `is_inside_tree()` or emit the diagnostics line before `_render_map()`.

**Fix direction:** (a) a new story — "live tactical board render + pixel→cell tap input" (tile grid from `TacticalBoardViewModel.cells`/`occupants`, hit-test taps to `Vector2i`, route into the existing `interactive_submit_move`/`interactive_tap_attack` seams — no domain changes needed); (b) a one-line quick fix for the route_map diagnostics guard.

## Reproduction Plan

Launch `boot.tscn` → pick any class → confirm → route map auto-navigates to the board (console ERROR fires here, 100% on fresh runs) → observe the text-only board and that mouse clicks do nothing.
