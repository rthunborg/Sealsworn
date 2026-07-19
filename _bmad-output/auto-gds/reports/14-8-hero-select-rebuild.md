# Auto-GDS report — 14-8-hero-select-rebuild

## Report — 2026-07-19T13:13:00Z (final)

**Story:** `14-8-hero-select-rebuild` (epic 14, story 8) — mid-epic; **first Band-2 story** (user authorized crossing the Band-1 gate with the on-device playtest still pending).
**Branch:** `story/14-8-hero-select-rebuild` (HEAD `38307ab` at report write; finalize commit follows).
**Pipeline status:** clean completion — review loop converged in 1 iteration (Approve, zero Decision items, zero Patch items), non-draft PR stacked on the 14-7 story branch; GDS status flipped to `done`. No halts this story.
**Continues:** (none — first and only report section; single uninterrupted run.)

**Timing:** started 2026-07-19T12:22:16Z; completed 2026-07-19T13:14:00Z — elapsed ~52m (≈48m AI-run, ≈4m idle); 1 session.

**Phases run:** Phase 0–1 (orchestrator — branch stacked on the 14-7 story branch), Phase 3 (create-story, agds-xhigh), Phase 5 (dev-story, agds-xhigh), Phase 7 iteration 1 primary review (agds-xhigh), Phase 9 finalize (orchestrator).
**Skipped:** Phase 2 (project-context exists), Phase 4 (gds-testing-disabled), Phase 6 (gds-testing-disabled), Phase 8 (not last in epic).

**Overrides:** stacked-chain (user-directed): branch/review/PR base = `story/14-7-full-backpack-reward-escape-hatch` (chain 14-8→14-7→…→14-1; PRs #77/#76/#75/#74/#73/#72/#71 unmerged); merge prompt skipped per user session directive (PR left open, `ci_status: none` — repo has no CI workflows).

**Testing:** disabled in V0.

**Code review:** 1 iteration (Round 1 of 3, primary agds-xhigh / Opus 4.8): verdict **Approve** — Critical 0 / High 0 / Medium 0 / Low 3; 0 open `[Review][Decision]`; findings persisted 3 (all `[Review][Defer]`, copied to the ledger). Scrutiny checks verified against source: confirm/seed path and profile-unaware `HeroSelectViewModel.new()` byte-identical (the profile-threading defer stays with the class-kit content story), no `summarize(run)` at hero-select, defensive portrait loading, `support_id "none"` handled, NFR9 non-color selection/locked states, no domain/RNG/save/scene/schema file touched. Suite independently re-run: 203 PASS / 0 FAIL (baseline+1 for the new seam test), guard clean. HITL outcome: continued automatically (protocol conditions met).

**Open questions:** (none. Create-story resolved two scope questions itself: D4 manual-seed ENTRY UI is out of scope — a planning misread, D4 was the shipped 14.4 seed-source decision; and profile-threading is a documented work-around, not a fix.)

**Deferred work:**
1. `KIT_KEYS` const declared but unenforced — no exact-key test pin on the kit sub-dict; harden or drop.
2. Per-selection re-render re-derives kits/resolvers and rebuilds baseline repositories on every tap — negligible for a 5-row menu; note if the seam is ever reused hot.
3. On-device human verification of the rebuilt hero-select surfaces (no SceneTree test — verify-by-construction), extending the standing Band-1 on-device defers.
Ledger: `## Deferred from: code review of 14-8-hero-select-rebuild (2026-07-19)`.

**Planning drift:** (none — not epic-end; but note for the retro: "D4 routes to 14-8" in earlier scope notes was a misread — no Epic-14 story adds a manual-seed entry field.)

**Needs human:** (none blocking — story is `done`.) Optional follow-ups: merge the stacked PR chain #71→…→#77→(this PR) in order, on your own time; the on-device playtest (Band-1 items + now the rebuilt hero-select) remains the epic's outstanding human gate.

**Next:** `14-9-outpost-screen-cleanup` (backlog, Epic 14) — preview only.
