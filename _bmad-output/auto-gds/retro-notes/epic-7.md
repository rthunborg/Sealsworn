# Epic 7 — Auto-GDS retro notes

Signal-only scratchpad for later Epic-7 stories and the epic retrospective. Append only meaningful
delegate notes (skip routine success recaps).

## Story 7-1-risk-economy-state
- [Phase 3 — create-story] Gold is a `gold_min..gold_max` BAND on `GoldRewardDefinition`, not a fixed amount — Epic 6 never rolled concrete gold. Crediting the wallet needs a GENERATE-time roll through the run-level `rewards` stream (carried on the offer + `reward_resolved` payload) so RESOLVE keeps the Epic-6 zero-new-RNG-on-resolve invariant. A naive "read the amount" approach violates resolve-draws-no-RNG.
- [Phase 5 — dev-story] The GENERATE gold roll is a SECOND draw on the `rewards` stream for a gold offer, so two route-position tests' `draw_index == 1` assertions became `>= 1` (expected — first place an Epic-7 economy mechanic changed Epic-6 reward-stream advancement). Later Epic-7 stories adding GENERATE-time rolls must account for rewards-stream draw-index shifts in existing reward tests.
- [Phase 5 — dev-story] Risk economy persists by NESTING `risk_economy` under the existing `route_state` save key (Option 1) — the 23-key top-level `RunSnapshot` gate COUNT stays 23, reusing the existing `gold`/`corruption` placeholders. Reads are lenient/back-compatible (a pre-7.1 save parses with a default economy derived from `is_manual_seed`); NO migration step. This is the ratified pattern for Epic-7 economy state that must persist (vs Epic-6 off-save inventory).

## Story 7-2-curse-and-corruption-rules
- [Phase 3 — create-story] AC3 ("curse resolves through the rules kernel") sits on the intentionally MINIMAL kernel: `RulesResolver` holds only `PassiveDefinition`s and `scripts/rules/{conditions,operations}` are empty by ratified design. 7-2 pins v0 curse resolution to the EXPLANATION-ONLY bar (same as v0 passives) and explicitly FORBIDS authoring the operation engine — the most likely over-build / review-pushback point. Seating a curse as a rules-kernel rule source (the resolver registry is typed `Array[PassiveDefinition]`) is the highest-risk in-story `[Decision]` for the dev to resolve.
