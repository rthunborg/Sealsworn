# Sealsworn — Claude Code Project Memory

@AGENTS.md

## Claude Code specifics

- Full test suite (must pass before any story moves to `review` or `done`):
  `godot --headless --path C:\Sealsworn\godot --scene res://tests/headless/test_runner.tscn --quit-after 10`
- BMAD skills for this project live in `.claude/skills/` (`gds-*` game-dev module plus `bmad-*` core). Drive story implementation with `/gds-dev-story`, code review with `/gds-code-review`, story creation with `/gds-create-story`, sprint tracking with `/gds-sprint-status`.
- The canonical epics list is `_bmad-output/planning-artifacts/epics.md` (the file `sprint-status.yaml` declares as its source). The smaller `_bmad-output/planning-artifacts/gdds/gdd-Game-2026-05-31/epics.md` is the earlier design-time breakdown inside the GDD.
- `prototype/` (React/Vite) is frozen validation evidence. Do not modify it and do not make production Godot code depend on it.
- `_bmad/` is installer-managed and gitignored. Never hand-edit it; re-run the BMAD installer to change install answers.
- `.agents/skills/` is the legacy Codex-targeted BMAD skill install. It is not used by Claude Code; do not edit or load skills from it.
