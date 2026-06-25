# Epic 5 — Auto-GDS retro notes

## Story 5-1-class-definition-content-and-repository
- [Phase 3 — create-story] Verified empirically: `scripts/rules/{conditions,operations,resolver,triggers}` are empty scaffolding (0 `.gd` files) and no passive definition/repository exists anywhere. So `class_passive_id`/`equipment_synergy_passive_id` are scoped as lower_snake string-shape forward references resolved later (Epic 6 + Story 5.4) — later stories MUST NOT assume a passive/rules system already wires these.
- [Phase 3 — create-story] Run-start seam kept a by-id class lookup so Story 5.2 EXTENDS `RunStartCommand` rather than forking it. Equipment-id validation is SHAPE-only in 5.1; cross-repository resolution deferred to Story 5.3.
- [Phase 5 — dev-story] `get_class()` is a reserved native `Object` method — defining it is a hard parse error. The class accessor is `ClassRepository.get_class_definition(class_id)`; downstream 5.2/5.3 MUST call that, not the spec-named `get_class(id)`. Any future `get_<thing>` content accessor must avoid reserved `Object` method names.
- [Phase 5 — dev-story] False-PASS guard earned its keep: the `get_class()` collision compile-failed both new test files, yet one still printed `PASS` — caught only by grepping the raw run output for `SCRIPT ERROR|Parse Error`, not the summary line. Keep that grep as a standing gate for every new content/test file.
