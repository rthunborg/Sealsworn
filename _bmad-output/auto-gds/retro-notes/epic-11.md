# Epic 11 — Auto-GDS retro notes

## Story 11-1-run-flow-ux-appendix-and-screen-contracts
- [Phase 3 — create-story] Epic-9 retro forward-prep is written for "Epic 10" but Epic 11 was inserted ahead of it (commit 3b699ee); its prep was re-mapped to Epic 11. Action P2 (atomic finalize) folded into the story as an orchestrator-owned reminder; the "fail-loud on new table" heads-up does not apply to docs-only 11.1.
- [Phase 7 — code review] Section-number cross-refs drifted twice in the dense appendix (§0.2→§16, §0.4→§14) despite dev self-verification; dense internally-cross-referenced spec docs need a final "resolve every §N against the section map" sweep before review. Field-source attributions in gap notes deserve the same pinned-key rigor as bindings (Round 1 Med: hero HP mis-sourced on RunState).

## Story 11-2-live-combat-loop-and-hero-death-source
- [Phase 5 — dev-story] The scripted live-combat hero is deterministic but not universally-winning across arbitrary generated seeds (mutually-unreachable straggler hits the round cap → fail-loud); the live loop is the seed-batch/AC-proof driver, not a shipped hands-off game loop. A universally-winning live run needs a stronger hero driver (LoS-aware ranged targeting) or class-kit→combat loadout wiring — the gap between "provable in an integration test" and "playable hands-off".
- [Phase 5 — dev-story] Run-level SYSTEM event stream (reserved high base) must stay distinct from the tactical board-event id space; mixing them produced a real duplicate sequence id — reusable caution for the next stream-merging caller.
