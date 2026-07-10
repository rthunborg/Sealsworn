# Epic 10 — Auto-GDS retro notes

## Story 10-4-gameplay-comprehension-and-playtest-checklist
- [Phase 5 — dev-story] The 12.2 Medium/affinity winnability gap is now genuinely CLOSED with added coverage (not scoped away): Medium boards are materially harder — the melee warrior frequently hits the round cap, so all-win Medium seeds are relatively rare, and Scorched DoT flips some neutral-winnable seeds to losses (seed 512 wins neutral but loses for 2/3 classes under Scorched). `ReferenceCombatDriver` handles Scorched hazard cells but does not dodge them (mark-dodge only covers seer telegraphs); winnability holds because the commit/kite policy clears fights fast enough to stay ahead of the burn.

## Story 10-8-darkness-fairness-moving-los-and-readiness-sample-expansion
- [Phase 0 — sprint-change] Second "numbered-last-but-executes-earlier" insertion (after the Epic-12 precedent): `story_plan.py` honors sprint-status FILE ORDER for picking (10-8 correctly selected before 12-1) but derives `is_last_in_epic` from NUMBERING — for 10-8 it returns true although Epic 10 execution continues at 10-4 after Epic 12. Orchestrator must override/skip Phase 8 (epic-end) for such insertions; the real Epic 10 close is after 10-7.
- [Phase 3 — create-story] Predicate-semantics changes fan out beyond the obvious sites: four stale static-from-entrance Darkness-FAIL expectations existed but only two were named in the epics.md ACs — `test_live_affinity_flow.gd`'s live-gate violation board and 10.2's honest-sample assertion block were only found by a full-codebase deliberate-update sweep. Convention: when changing a validator/predicate contract, grep-sweep ALL tests/tools/ledgers for baked expectations before scoping ACs.
- [Phase 5 — dev-story] The documented-stderr-negative catalog says "int64-overflow ×2" but the raw runner emits ×1 line on this build (byte-identical to the pre-10.8 baseline, so not a regression) — reconcile the ledger's stderr catalog on a future touch, non-gating.
- [Phase 5 — dev-story] The curated `AFFINITY_SEED_BY_AFFINITY` sample landed exactly 10-per-affinity across 40 seeds with no slack; any future generator/RNG change that shifts an assignment fails loud (by design) — REGENERATE the curated list via the dump tooling, never hand-edit it.

## Story 10-1-device-tiers-and-performance-budgets
- [Phase 5 — dev-story] Dev Notes assumed `export_presets.cfg` had only Windows + Android scaffolding; on disk it already carries an iOS preset (`preset.2`) scaffold (`runnable=false`, empty signing/icons). AC5 held regardless — all three presets share the identical `exclude_filter` (excludes `tools/**` + `**/test_*.gd`). iOS packaging remains availability gap G7 for the 10.6 gate.

## Story 10-3-generator-soft-lock-and-fairness-batch-checks
- [Phase 3 — create-story] Epic-wide convention: the Small/Medium seed catalog `[1001,2002,3003,4004,5005]` is SHARED by the 10.1 perf harness, 10.2 consolidated regression suite, and 10.3 fairness batch — expand all three together (10.6 gate decides), never desync or re-pin one harness alone.
- [Phase 5 — dev-story] Real FR58 finding: 7.6's `DarknessFairnessQuery` test suite only ever exercised Small (all-FLOOR) seeds, so Medium-recipe baked hazards under Darkness (`darkness_unseen_hazard` on seeds 4004/5005) went undetected until the 10.3 batch. Epic-retro lesson: test the whole recipe×affinity matrix, not just the easy recipe. Also: 10.3's Dev Notes carried the false premise "v0 boards are all-FLOOR" (true only for Small) — verify terrain premises against the Medium wrinkle phase. Resolution (tune generator / strengthen predicate / accept documented limitation) is 10.6-gate-owned, recorded in generator-fairness-batch-readiness.md §4.

## Story 10-2-headless-seed-regression-suite
- [Phase 5 — dev-story] Story-context task phrasing conflicted: Task 6 said "every existing `tools/dump_*` UNTOUCHED" while Task 3 explicitly sanctioned expanding route seeds via `dump_route_fingerprints.gd`. Resolved in favor of the specific instruction (Task 3) — the route dump tool was intentionally extended 8→20 seeds, not scope drift. Future story contexts should avoid blanket "untouched" clauses that contradict a specific task's sanctioned edit.

## Story 10-6-mvp-readiness-gate-and-playable-build-preservation
- [Phase 3 — create-story] Naming collision: device-tiers §6 "G4" (on-device FPS-stability profiler, physical-device G1–G7) vs UX-appendix §16 "G4" (settings view-model gap, PARKED) — both 10.6-adjacent, easy to conflate; doc ambiguity persists for 10.7 and the settings-scene story.
