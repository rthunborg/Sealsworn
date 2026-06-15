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

## Story 2-8-resume-flow-and-mid-level-save-feasibility
- [Phase 3 — create-story] Latent fragility on the resume path: `GameSession.restore_rng_snapshot()` does `int(snapshot.get("root_seed", ...))` while `RngStreamSet.to_snapshot()` now string-encodes `root_seed`. Works today via GDScript string→int coercion, but would silently truncate a seed > 2^53. One-line hardening worth doing if resume touches that path; not currently broken.
- [Phase 5 — dev-story] Resolved the above on the resume path: `restore_rng_snapshot()` now reads the losslessly-decoded `root_seed` from `try_restore` metadata. New `RunResumeService` (RefCounted) composes existing restore primitives; `SaveManager.resume_run()` is the thin delegation entry.
- [Phase 5 — dev-story] The AC2 `save_parse_failed` test feeds deliberate non-JSON bytes through the real `SaveRepository`, so Godot's `JSON.parse_string` prints one expected `ERROR: Parse JSON failed` line to stderr. The test passes and the runner exits 0 — reviewers must not read this stderr diagnostic as a suite failure; it is the cost of exercising the real-repository parse-failure path.

## Story 2-9-settings-and-difficulty-non-goal-guardrails
- [Phase 5 — dev-story] Contrary to the create-story assumption that no bus config exists, the Master audio bus IS present in headless (loaded from `godot/default_bus_layout.tres`), so the live `AudioServer.get_bus_volume_db`/`is_bus_mute` AC4 assertions actually execute rather than being skipped. The `AudioServer.get_bus_index("Master") >= 0` guard is still kept for portability, but on this project the apply path is genuinely exercised headlessly.
- [Phase 5 — dev-story] Settings persist to their own `user://settings.json` via `SettingsRepository`, strictly isolated from `user://run_autosave.json` (a cross-file no-contamination test asserts settings writes never touch the run autosave). Future preference work belongs in `scripts/settings/`, never folded into the run snapshot.
