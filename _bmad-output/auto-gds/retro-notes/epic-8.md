# Epic 8 — Auto-GDS retro notes

Signal-only scratchpad for later Epic 8 stories and the epic retrospective. One terse bullet per
genuinely reusable signal; routine success recaps are omitted.

## Story 8-1-run-completion-and-return-to-outpost-flow
- [Phase 3 — create-story] 8-1 is the FIRST story to drive `RunState.PHASE_FAILED` (reachable in the transition table since Epic 4 but never triggered — combat auto-resolves to success) and adds the first run-level `run_failed` event; the new event WILL trip the Story-7.1 `expected_ids` exhaustiveness gate (`test_domain_event.gd`) by design — register it in the same change (the exact epic-transition heads-up from the Epic-7 retro's Action T3).
- [Phase 5 — dev-story, resume-verify] The first dev-story delegate died to a CC process exit mid-run; recovery worked (WIP-checkpoint 4861a11 → push → suite diagnostic → resume delegate). Lesson for future resume briefs: diagnose from the runner's actual per-file `FAIL` list, NOT stderr `ERROR:` lines — an `ERROR: Cannot represent … as 64-bit signed integer` (`String.to_int` saturation) in this suite is a benign negative-path `push_error` that still PASSes; my resume brief mis-cited it as a second regression. The real root cause was a single `run_completed` factory leak (`boss_node_id: ""` injected unconditionally) surfacing in two test files.
- [Phase 5 — dev-story] BREAKING (documented): `run_completed` payload no longer always carries `boss_node_id` — boss_placeholder-only now, absent for generic `completed`. Epic 9 boss consumers must guard on presence.

## Story 8-2-run-summary-snapshot
- [Phase 7 — code review] `RunSummary.notable_loot` is single-sourced from `item_gained` events ONLY — all `reward_resolved` events are excluded (REWARD_CATEGORIES = backpack ∪ {gold, passive}; gold/passive were already excluded, backpack now too). A reward→backpack pickup emits both `reward_resolved` and a paired `item_gained`, so 8.6 UI can render `notable_loot` directly WITHOUT further dedup, and 8.3 loot reads see each gained item once.
- [Phase 7 — code review] The review-round-guard counts rounds via standalone bold `**Round N of 3**` headers in the story file; round 3's header initially wrapped "of 3" inside a longer bold run, which would have defeated the counter and silently permitted a 4th automatic round. Keep the round header as its own bold token when appending review entries.
