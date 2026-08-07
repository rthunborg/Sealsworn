# Epic 15 — Auto-GDS retro notes

## Story 15-1-hud-and-log-layout-clip-fix
- [Phase 5 — dev-story] The F1 "negative-x" symptom cannot be reproduced headlessly (verify-by-construction has no render pass), so the frame-border mitigation (light band backing replacing the nine-patch on short control bands) is a reasoned structural fix, not a pixel-confirmed one — real confirmation depends on the OSG-1 on-device pass.

## Story 15-3-threat-telegraphs
- [Phase 5 — dev-story] Deliberate scope call beyond the story's literal "pair by telegraph_id": the projection also clears a mark when its source enemy dies. Grep-verified the domain strands a mark on seer death (a dead enemy returns early in prototype_enemy_ai.gd:28 and no board sweep emits a clearing event), so killing the seer to avoid the blast would otherwise leave a lying "danger" glyph. Satisfies AC1's "or is cancelled" clause via the only cancellation the event log exposes — a pure event-log read, no new query/key/fingerprint.

- [Phase 7 — code review] The headless runner reports PASS per test FILE, not per test function — deleting a test function leaves the count flat. Worth remembering when setting expected-count guards for function-level test edits.

## Story 15-2-attack-preview-damage-correctness
- [Phase 5 — dev-story] Per the story's explicit "return expected_damage in the query success metadata", AttackCommand's transient ActionResult.metadata now also carries a benign expected_damage = base key (the command copies preview metadata). The event-log fingerprint is byte-identical (attack/damage payloads use explicit key lists that exclude it), so AC2/AC3 hold at the events/damage/RNG level — but the query-side-vs-VM-side placement of the fold is the one decision worth an auditor's eye.
- [Phase 3 — create-story] F4 is a direct consequence of Story 12.2 adding a resolution-side damage bonus without updating the paired read model — a "damage computed in two places" desync class. The AC2 regression test (preview == resolved per starting kit) is the new standing guard against it recurring as future bonus sources are added.
