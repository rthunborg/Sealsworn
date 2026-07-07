# Epic 10 — Auto-GDS retro notes

## Story 10-1-device-tiers-and-performance-budgets
- [Phase 5 — dev-story] Dev Notes assumed `export_presets.cfg` had only Windows + Android scaffolding; on disk it already carries an iOS preset (`preset.2`) scaffold (`runnable=false`, empty signing/icons). AC5 held regardless — all three presets share the identical `exclude_filter` (excludes `tools/**` + `**/test_*.gd`). iOS packaging remains availability gap G7 for the 10.6 gate.

## Story 10-3-generator-soft-lock-and-fairness-batch-checks
- [Phase 3 — create-story] Epic-wide convention: the Small/Medium seed catalog `[1001,2002,3003,4004,5005]` is SHARED by the 10.1 perf harness, 10.2 consolidated regression suite, and 10.3 fairness batch — expand all three together (10.6 gate decides), never desync or re-pin one harness alone.
- [Phase 5 — dev-story] Real FR58 finding: 7.6's `DarknessFairnessQuery` test suite only ever exercised Small (all-FLOOR) seeds, so Medium-recipe baked hazards under Darkness (`darkness_unseen_hazard` on seeds 4004/5005) went undetected until the 10.3 batch. Epic-retro lesson: test the whole recipe×affinity matrix, not just the easy recipe. Also: 10.3's Dev Notes carried the false premise "v0 boards are all-FLOOR" (true only for Small) — verify terrain premises against the Medium wrinkle phase. Resolution (tune generator / strengthen predicate / accept documented limitation) is 10.6-gate-owned, recorded in generator-fairness-batch-readiness.md §4.

## Story 10-2-headless-seed-regression-suite
- [Phase 5 — dev-story] Story-context task phrasing conflicted: Task 6 said "every existing `tools/dump_*` UNTOUCHED" while Task 3 explicitly sanctioned expanding route seeds via `dump_route_fingerprints.gd`. Resolved in favor of the specific instruction (Task 3) — the route dump tool was intentionally extended 8→20 seeds, not scope drift. Future story contexts should avoid blanket "untouched" clauses that contradict a specific task's sanctioned edit.
