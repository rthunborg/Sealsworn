# Epic 2 — Auto-GDS retro notes

Signal-only scratchpad for later Epic 2 stories and the epic retrospective.

## Story 2-5-adaptive-layout-profiles
- [Phase 5 — dev-story] `godot` resolves only as `C:\Users\Rasmus\bin\godot.cmd` via PowerShell; the Bash tool's PATH/`where` can't find it — run the headless test command through `powershell.exe -NoProfile -Command`.
- [Phase 5 — dev-story] `TacticalBoardViewModel.to_dictionary()` gained a top-level `layout` key (additive, defaults `{}`); any later consumer enumerating exact keys must account for it.

## Story 2-6-accessibility-and-tactical-readability-baseline
- [Phase 5 — dev-story] `TacticalBoardViewModel.to_dictionary()` now returns 16 keys (added `accessibility`, defaults `{}`) — the exact sorted-key assertion in `test_tactical_board_view_model.gd` tracks this; any future slot addition must bump it intentionally (continues the 15→16 pattern).
- [Phase 5 — dev-story] `feedback_preview` vs `feedback_committed` is the new committed-action feedback contract (parallel optional audio ids + audio-absent visual/textual equivalence); later cue work should respect this distinction, not collapse it.
- [Phase 5 — dev-story] `AttackPreviewContractMatrix` fixture is the canonical driver for the color-independence / cue audit — reuse it when adding cue vocabulary so new previews can't ship without an accessibility mapping.

## Story 2-7-between-level-save-snapshot-foundation
- [Phase 3 — create-story] A between-level `RunSnapshot` embeds the Epic 1 `TacticalSnapshot` in `level_state`, so `RunSnapshot.rng_streams` and the embedded tactical `rng_streams` coexist — story names the run-level one as the between-level authority. Story 2.8's resume flow must decide which RNG snapshot wins on restore; revisit if it surfaces ambiguity.
- [Phase 5 — dev-story] The save format silently lost 64-bit RNG `state` precision through `JSON.stringify`/`parse_string` (JSON numbers are doubles); `RngStreamSet.try_restore` also rejected JSON-parsed floats. Fixed by string-encoding `root_seed`/stream `state` (read-tolerant of old numeric form). Latent determinism/resume bug Story 1.5 missed by round-tripping native dicts, not real JSON. Rule for Story 2.8 + future save work: always JSON-round-trip snapshots in tests, and string-encode any large int64 save field.
