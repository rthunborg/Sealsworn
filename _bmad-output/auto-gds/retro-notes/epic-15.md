# Epic 15 — Auto-GDS retro notes

## Story 15-1-hud-and-log-layout-clip-fix
- [Phase 5 — dev-story] The F1 "negative-x" symptom cannot be reproduced headlessly (verify-by-construction has no render pass), so the frame-border mitigation (light band backing replacing the nine-patch on short control bands) is a reasoned structural fix, not a pixel-confirmed one — real confirmation depends on the OSG-1 on-device pass.

## Story 15-2-attack-preview-damage-correctness
- [Phase 3 — create-story] F4 is a direct consequence of Story 12.2 adding a resolution-side damage bonus without updating the paired read model — a "damage computed in two places" desync class. The AC2 regression test (preview == resolved per starting kit) is the new standing guard against it recurring as future bonus sources are added.
