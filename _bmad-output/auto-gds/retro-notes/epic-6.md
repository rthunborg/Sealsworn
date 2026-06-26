# Epic 6 — Auto-GDS retro notes

## Story 6-1-item-loot-and-reward-definitions
- [Phase 3 — create-story] 6.1 is the epic's heaviest, highest-regression story: bundles 8 loot/reward definition+repository families, the item roll-model, the deterministic reward-offer fixture, AND the cross-cutting duplicate-id fail-loud retrofit (changes `ContentRepository.register_definition`, touching all 6 existing repos + `RunStartCommand` content gates). Isolate the retrofit and re-run the full suite first.
