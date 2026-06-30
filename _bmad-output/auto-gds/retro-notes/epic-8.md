# Epic 8 — Auto-GDS retro notes

Signal-only scratchpad for later Epic 8 stories and the epic retrospective. One terse bullet per
genuinely reusable signal; routine success recaps are omitted.

## Story 8-1-run-completion-and-return-to-outpost-flow
- [Phase 3 — create-story] 8-1 is the FIRST story to drive `RunState.PHASE_FAILED` (reachable in the transition table since Epic 4 but never triggered — combat auto-resolves to success) and adds the first run-level `run_failed` event; the new event WILL trip the Story-7.1 `expected_ids` exhaustiveness gate (`test_domain_event.gd`) by design — register it in the same change (the exact epic-transition heads-up from the Epic-7 retro's Action T3).
