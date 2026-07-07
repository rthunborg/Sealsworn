# Epic 12 — Auto-GDS retro notes

## Story 12-1-interactive-combat-tap-loop-and-live-board-render
- [Phase 5 — dev-story] On-screen gesture→cell hit-testing is intentionally out of scope for 12-1: the board presenter has no board-geometry hit-test today, so the tap methods (`interactive_submit_move`/`interactive_tap_attack`/`interactive_inspect`) are driver/method-call entry points; the assertable tap-loop logic lives in the unit-tested scene-free `InteractiveCombatSession`. A future input story wires pixel→cell — do not treat the missing hit-test as a 12-2 regression.
