# Auto-GDS retro notes — epic 13

## Story 13-1-live-board-render-and-tap-input
- [Phase 3 — create-story] TacticalBoardZoomState (Story 2.4) already implements screen_to_cell/cell_rect and is unit-tested — the 12-1 "no board-geometry hit-test exists" defer and the investigation understate what's built; 13.1 is a wire-_gui_input-into-existing-seams job (render + hit-test glue), not build-from-scratch.
- [Phase 3 — create-story] Open question for dev/review: AC1 lists boss among render targets, but the boss auto-plays (auto_play_boss_fight) and the 12-1 non-goal forbids a boss tap-loop — story defaults to board-source-agnostic render (no crash on boss/null board, boss stays auto-play); the stronger live-boss-board reading is explicitly flagged.
- [Phase 7 — code review] VC convention settled (human decision, Round 1): `*.gd.uid` script-UID sidecars are committed (Godot 4.4+ guidance), never gitignored — 405 committed with 13-1; future import-touching stories must retain them, re-import is now a git-clean no-op.
- [Phase 5 — dev-story] Approved board art existed on disk but had never been imported (no `*.png.import` sidecars) so `load`/`preload` couldn't resolve it; fixed via headless `--import`, committing the sidecars, and loading textures defensively in the presenter (guarded `load()`, never `preload`) so compile guardrails stay green on fresh checkouts. Any future art-consuming story must ensure sidecars are imported + committed.

## Story 13-2-live-reward-and-passive-choice-hud
- [Phase 3 — create-story] The live flow generates zero rewards today, so 13.2's true weight is flow-wiring the reward GENERATE at the interactive-shell post-victory boundary (hands-off driver must stay byte-identical) — an easy story to under-scope as "render-only"; review should confirm the generate is wired.
