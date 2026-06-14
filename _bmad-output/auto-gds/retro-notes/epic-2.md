# Epic 2 — Auto-GDS retro notes

Signal-only scratchpad for later Epic 2 stories and the epic retrospective.

## Story 2-5-adaptive-layout-profiles
- [Phase 5 — dev-story] `godot` resolves only as `C:\Users\Rasmus\bin\godot.cmd` via PowerShell; the Bash tool's PATH/`where` can't find it — run the headless test command through `powershell.exe -NoProfile -Command`.
- [Phase 5 — dev-story] `TacticalBoardViewModel.to_dictionary()` gained a top-level `layout` key (additive, defaults `{}`); any later consumer enumerating exact keys must account for it.
