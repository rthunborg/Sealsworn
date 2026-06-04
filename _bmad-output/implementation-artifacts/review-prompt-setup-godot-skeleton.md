# Review Prompt: Setup Godot Production Skeleton

Run `bmad-review-adversarial-general` in a separate session with no prior conversation context.

## Review Target

Review the new production Godot skeleton under `C:\Sealsworn\godot`.

## Required Context

- Read `C:\Sealsworn\AGENTS.md`.
- Read `C:\Sealsworn\project-context.md`.
- Read `C:\Sealsworn\_bmad-output\game-architecture.md`, especially Project Structure, State Management, RNG And Determinism, Data Persistence, Testing/Headless Simulation, and Architectural Boundaries.

## Intent

Set up the initial production Godot project skeleton for Sealsworn using Godot 4.6.3 stable standard, typed GDScript, domain-first architecture, named RNG streams, command/result/event flow, versioned save snapshots, and headless tests. Do not touch or review the React prototype except to confirm no production dependency was introduced.

## Changed Files To Review

- `godot/project.godot`
- `godot/export_presets.cfg`
- `godot/.gitignore`
- `godot/README.md`
- `godot/assets/art/ui/icons/icon_placeholder.svg`
- `godot/scenes/app/boot.tscn`
- `godot/scenes/app/main.tscn`
- `godot/scenes/game/gameplay_shell.tscn`
- `godot/scenes/game/tactical_board.tscn`
- `godot/scripts/autoloads/audio_manager.gd`
- `godot/scripts/autoloads/diagnostics.gd`
- `godot/scripts/autoloads/game_session.gd`
- `godot/scripts/autoloads/save_manager.gd`
- `godot/scripts/autoloads/scene_manager.gd`
- `godot/scripts/content/repositories/content_repository.gd`
- `godot/scripts/core/commands/create_board_command.gd`
- `godot/scripts/core/commands/game_command.gd`
- `godot/scripts/core/events/domain_event.gd`
- `godot/scripts/core/results/action_result.gd`
- `godot/scripts/core/state/rng_stream_set.gd`
- `godot/scripts/platform/platform_services.gd`
- `godot/scripts/save/save_repository.gd`
- `godot/scripts/save/snapshots/run_snapshot.gd`
- `godot/scripts/tactical/board/board_cell.gd`
- `godot/scripts/tactical/board/board_state.gd`
- `godot/scripts/ui/presenters/boot_controller.gd`
- `godot/tests/headless/test_runner.gd`
- `godot/tests/headless/test_runner.tscn`
- `godot/tests/unit/test_case.gd`
- `godot/tests/unit/core/test_action_result.gd`
- `godot/tests/unit/core/test_create_board_command.gd`
- `godot/tests/unit/core/test_domain_event.gd`
- `godot/tests/unit/core/test_rng_stream_set.gd`
- `godot/tests/unit/save/test_run_snapshot.gd`
- `godot/tests/unit/save/test_save_repository.gd`
- `godot/tests/unit/tactical/test_board_state.gd`

## Specific Risks To Check

- Godot project config validity for Godot 4.6.3 standard.
- GDScript syntax/type issues, especially global class references and typed arrays.
- Whether any authoritative tactical state leaks into scenes, UI, autoloads, or presentation nodes.
- Whether RNG usage is correctly limited to named streams.
- Whether save/file access is confined to repository boundaries.
- Whether tests are headless-safe and cover valid plus invalid/no-mutation command behavior.
- Whether empty project folders or export preset placeholders create misleading production readiness.

Return findings ordered by severity with file and line references.
