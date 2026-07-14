# Auto-GDS retro notes — epic 13

## Story 13-1-live-board-render-and-tap-input
- [Phase 3 — create-story] TacticalBoardZoomState (Story 2.4) already implements screen_to_cell/cell_rect and is unit-tested — the 12-1 "no board-geometry hit-test exists" defer and the investigation understate what's built; 13.1 is a wire-_gui_input-into-existing-seams job (render + hit-test glue), not build-from-scratch.
- [Phase 3 — create-story] Open question for dev/review: AC1 lists boss among render targets, but the boss auto-plays (auto_play_boss_fight) and the 12-1 non-goal forbids a boss tap-loop — story defaults to board-source-agnostic render (no crash on boss/null board, boss stays auto-play); the stronger live-boss-board reading is explicitly flagged.
- [Phase 5 — dev-story] Approved board art existed on disk but had never been imported (no `*.png.import` sidecars) so `load`/`preload` couldn't resolve it; fixed via headless `--import`, committing the sidecars, and loading textures defensively in the presenter (guarded `load()`, never `preload`) so compile guardrails stay green on fresh checkouts. Any future art-consuming story must ensure sidecars are imported + committed.
