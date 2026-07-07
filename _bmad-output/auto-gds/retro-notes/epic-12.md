# Epic 12 — Auto-GDS retro notes

## Story 12-2-class-loadout-and-winnable-hands-on-fights
- [Phase 3 — create-story] Winnability crux: all three class kits are 18 HP and the existing focus-fire `LiveCombatResolver` provably dies at 18 HP on a full live walk (the 11.3 lesson) — AC2 hard-forces a strengthened LoS-aware reference driver, not a trivial HP swap.
- [Phase 3 — create-story] AC4 interaction: threading the warrior `shield` support engages a `shield_block` roll on the `combat` stream in `AttackCommand` — an INTENTIONAL, seeded fixture re-pin on the class path only; neutral default/auto-resolve/generator paths must stay byte-identical. Most likely site for a reviewer to mistake an intentional fingerprint change for a regression.

## Story 12-1-interactive-combat-tap-loop-and-live-board-render
- [Phase 5 — dev-story] On-screen gesture→cell hit-testing is intentionally out of scope for 12-1: the board presenter has no board-geometry hit-test today, so the tap methods (`interactive_submit_move`/`interactive_tap_attack`/`interactive_inspect`) are driver/method-call entry points; the assertable tap-loop logic lives in the unit-tested scene-free `InteractiveCombatSession`. A future input story wires pixel→cell — do not treat the missing hit-test as a 12-2 regression.
