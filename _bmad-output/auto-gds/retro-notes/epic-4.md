# Epic 4 — Auto-GDS Retro Notes

Signal-only scratchpad for later Epic 4 stories and the epic retrospective. Each bullet is a
constraint, gotcha, or ratified convention surfaced by an earlier story in this epic.

## Story 4-1-run-state-and-route-node-model
- [Phase 3 — create-story] Story directs a NEW `scripts/run/` domain folder for the run-progression model (`RunState`/`RouteState`/`RouteNode`) and adding `run` to the project-context.md code-organization domain list. Architecture specifies the `RunState` machine but maps no directory for the run model (route *generation* → `scripts/generation/route/`, saves → `scripts/save/`). Defensible (mirrors how `settings` was added in Epic 2) but is a genuine convention extension later stories inherit — flag if a different placement is preferred.
