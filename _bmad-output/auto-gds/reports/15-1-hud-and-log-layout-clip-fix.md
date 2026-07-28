# Auto-GDS pipeline report — 15-1-hud-and-log-layout-clip-fix

## Report — 2026-07-28T07:26:52Z (final)

**Story:** `15-1-hud-and-log-layout-clip-fix` (epic 15, story 1) — first-in-epic.
**Branch:** `story/15-1-hud-and-log-layout-clip-fix` (HEAD `71421d0`).
**Pipeline status:** clean completion.
**Continues:** (none — first run).

**Timing:** started 2026-07-25T13:54:35Z; completed 2026-07-28T07:26:52Z — elapsed 65h 32m (≈1h 15m AI-run, ≈64h 17m human/idle wait). Two delegate runs were terminated mid-flight by an API monthly-spend-limit error and re-run; the long elapsed is wall-clock across that gap, not work.

**Phases run:** Phase 0 (preflight), Phase 1 (branch), Phase 3 (create-story — `agds-xhigh`), Phase 5 (dev-story — `agds-xhigh`), Phase 7 (code-review loop — `agds-xhigh`), Phase 9 (finalize).
**Skipped:** Phase 2 (project-context bootstrap — `project-context.md` already present at the repo root), Phase 4 / Phase 6 / Phase 7 Tail (GDS testing placeholders — `gds-testing-disabled`), Phase 8 (epic-end — not last in epic; 15-1 of 12).

**Overrides:** none.

**Testing:** disabled in V0 (no GDS testing steps ran). The project's own headless suite ran inside the dev phase: baseline 205 PASS → RED confirmed on the updated layout test → GREEN at **205 PASS / 0 FAIL**, compile guardrail `test_run_flow_scenes_load.gd` PASS, false-PASS grep guard (`SCRIPT ERROR|Parse Error|^FAIL`) clean, `git diff --check` clean.

**Code review:** 1 iteration. Iteration 1 (primary, `agds-xhigh`): **Approve** — Critical 0 / High 0 / Medium 0 / Low 5. Converged on the first pass, so no fix iteration and no alternate-model secondary pass ran. Of the 5 Low findings, 0 were `[Review][Patch]`: 2 are `[Review][Decision]` OSG-1 on-device validation obligations (no code change available to implement) and 3 are `[Review][Defer]` entries logged to the cross-story ledger. Persistence verified with `review_findings.py` (`reconciled: true`, 5 findings, 3 deferrals). HITL halt outcome: **continued** to finalize. No external-review changes were made, so no post-halt re-review ran.

**Open questions:**
1. AC2's newest-line "live tail" rides on Godot `Label` `VERTICAL_ALIGNMENT_BOTTOM` clipping the *oldest* lines on overflow, and is verify-by-construction only. OSG-1 must explicitly confirm "newest log line visible, oldest clipped" at both 1.0x and 2.0x text scale — a version quirk clipping the wrong end would silently reproduce the exact F2 symptom this story exists to fix.
2. The HUD is a bounded band plus a vertical `ScrollContainer`, so on smaller windows the affinity badge and highlight legend may sit below the fold. OSG-1 must validate that HP and the turn indicator are above the fold and that the scroll affordance is discoverable in-combat; if key HUD facts fall below the fold, bounce to `gds-correct-course`.

**Deferred work:**
1. On-screen human legibility (574/774/984 wide × portrait/landscape/mid-fight-resize × 1.0x/2.0x scale) remains verify-by-construction only — carried to the OSG-1 on-device checklist.
2. The side-rail (phone_landscape) bands lost their per-band ≥44px reachability floor (now `unit = area.size.y / 6` with no `maxf`); a landscape content height below ~264px drops preview/confirm/inspect/log below reachable — device-tier layout tuning.
3. The stacked band fractions sum to exactly 0.50, an undocumented coupling: nudging any constant, or a stacked viewport below ~489px content height, triggers the proportional scale-down and can shrink `status` below the `2×44` the new `_assert_status_region_holds_hud` pins — add a documenting comment and a sum-≤0.5 assertion during device-tier tuning.
4. The light `_control_band_backing()` replaced the heavy 24px nine-patch frame only on the `status` and `log_or_outcome` bands; `preview`/`confirm_cancel`/`inspect` still carry the full frame — Story 15.10 (Theme & Layout Polish) framing-consistency pass.

**Planning drift:** (none — not epic-end).

**⚠️ Needs human:** (none blocking). The story is `done`; the two Open questions above are OSG-1 obligations that gate the *human* readability sign-off, not this story's completion.

**Next:** `15-2-attack-preview-damage-correctness` (Band 2 — Correctness), per `story_plan.py`. Preview only — not started.
