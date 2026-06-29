# Epic 7 — Auto-GDS retro notes

Signal-only scratchpad for later Epic-7 stories and the epic retrospective. Append only meaningful
delegate notes (skip routine success recaps).

## Story 7-1-risk-economy-state
- [Phase 3 — create-story] Gold is a `gold_min..gold_max` BAND on `GoldRewardDefinition`, not a fixed amount — Epic 6 never rolled concrete gold. Crediting the wallet needs a GENERATE-time roll through the run-level `rewards` stream (carried on the offer + `reward_resolved` payload) so RESOLVE keeps the Epic-6 zero-new-RNG-on-resolve invariant. A naive "read the amount" approach violates resolve-draws-no-RNG.
