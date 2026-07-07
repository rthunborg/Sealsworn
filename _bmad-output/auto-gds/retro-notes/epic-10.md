# Epic 10 — Auto-GDS retro notes

## Story 10-1-device-tiers-and-performance-budgets
- [Phase 5 — dev-story] Dev Notes assumed `export_presets.cfg` had only Windows + Android scaffolding; on disk it already carries an iOS preset (`preset.2`) scaffold (`runnable=false`, empty signing/icons). AC5 held regardless — all three presets share the identical `exclude_filter` (excludes `tools/**` + `**/test_*.gd`). iOS packaging remains availability gap G7 for the 10.6 gate.

## Story 10-2-headless-seed-regression-suite
- [Phase 5 — dev-story] Story-context task phrasing conflicted: Task 6 said "every existing `tools/dump_*` UNTOUCHED" while Task 3 explicitly sanctioned expanding route seeds via `dump_route_fingerprints.gd`. Resolved in favor of the specific instruction (Task 3) — the route dump tool was intentionally extended 8→20 seeds, not scope drift. Future story contexts should avoid blanket "untouched" clauses that contradict a specific task's sanctioned edit.
