---
baseline_commit: 016e0b59d917a4cdbd95d804692d96cb847098df
---

# Story 1.1: Production Godot Project and Headless Test Harness

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a developer,  
I want a production Godot project with domain-first folders and a headless test harness,  
so that the tactical slice can be implemented and verified without scene-owned gameplay state.

## Acceptance Criteria

1. Given the Sealsworn repository has no required dependency on the React/Vite prototype, when the production project is initialized, then a Godot 4.6.3 standard GDScript project exists under `godot/`, and production code does not import or depend on `prototype/`.
2. Given the architecture-defined folder rules, when the project structure is created, then folders exist for `godot/scripts/core`, `godot/scripts/tactical`, `godot/scripts/rules`, `godot/scripts/generation`, `godot/scripts/ai`, `godot/scripts/content`, `godot/scripts/save`, `godot/scripts/ui`, and `godot/tests`, and folder and file naming follows `snake_case`.
3. Given tactical truth must be scene-independent, when the first test suite is run headlessly, then at least one passing test executes without rendering, audio, UI scenes, or presentation nodes, and the test demonstrates that domain scripts can be loaded independently of gameplay scenes.
4. Given every future command needs valid and invalid/no-mutation tests, when the test harness is documented or scripted, then it provides a repeatable command for running relevant Godot tests, and the command is recorded in story notes or project documentation.
5. Given native mobile packaging must remain viable from the first production setup, when Story 1.1 is completed, then `project.godot` exists or is explicitly created as part of setup work, and an initial local build/export plan covers Windows desktop and Android, and iOS export requirements are recorded as deferred until macOS/Xcode access is available.
6. Given export presets depend on local Godot export templates and platform SDKs, when the project setup is committed, then `export_presets.cfg` is either present with non-secret Windows/Android preset scaffolding or a tracked setup note documents exact prerequisites and next action needed to create it, and no cloud service, account, telemetry, or prototype dependency is introduced by build setup.

## Tasks / Subtasks

- [x] 1.1.1 Create or verify `godot/project.godot` for Godot 4.6.3 standard GDScript. (AC: 1, 5)
  - [x] Confirm `godot/project.godot` exists and is a standard GDScript project, not Godot .NET/C#.
  - [x] Confirm the project uses the Mobile renderer and a mobile-first viewport baseline without changing tactical rules.
  - [x] Confirm `run/main_scene` points to a minimal boot/app scene and does not make UI or scene nodes authoritative for tactical truth.
  - [x] Confirm production project files contain no imports or required references to `prototype/`.
- [x] 1.1.2 Create or verify architecture folders and one headless smoke test that loads a domain script. (AC: 2, 3)
  - [x] Verify required domain script roots exist: `godot/scripts/core`, `tactical`, `rules`, `generation`, `ai`, `content`, `save`, `ui`, `platform`, `diagnostics`, and `utils`.
  - [x] Verify required scene/data/test roots exist: `godot/scenes/game`, `godot/scenes/ui`, `godot/assets`, `godot/data/source`, `godot/data/resources`, and `godot/tests`.
  - [x] Verify the headless runner can discover tests under `godot/tests/unit` and `godot/tests/integration`.
  - [x] Ensure at least one smoke/unit test loads a domain script from `godot/scripts/core` or `godot/scripts/tactical` and passes without UI, rendering, audio, or presentation nodes.
- [x] 1.1.3 Record the local headless test command and Windows dev-run command. (AC: 3, 4)
  - [x] Record the headless command in `godot/README.md` or equivalent tracked setup documentation.
  - [x] Record a Windows dev-run command that launches the production project without relying on prototype code.
  - [x] Include the local Godot version command/check used for this setup.
  - [x] Keep commands Windows-friendly because the current development workspace is Windows.
- [x] 1.1.4 Add Android export preset scaffolding or a tracked export-preset setup note with Android Studio, SDK, and JDK prerequisites. (AC: 5, 6)
  - [x] Verify `export_presets.cfg` has non-secret Windows desktop and Android scaffolding, or document the exact missing prerequisites and next action.
  - [x] Verify export filters exclude tests, tools, source-only data, debug scenes, and test scripts from production exports.
  - [x] Record that Android export needs Godot export templates, OpenJDK 17, Android SDK, Android SDK Platform-Tools 35.0.0 or later, Build-Tools 35.0.1, Platform 35, latest command-line tools, CMake 3.10.2.4988404, and NDK r28b unless project policy intentionally updates the pinned setup.
  - [x] Ensure no signing secrets, account requirements, cloud service, telemetry service, multiplayer service, or prototype dependency are added.
- [x] 1.1.5 Record iOS export as deferred until macOS/Xcode setup, without blocking Epic 1 domain implementation. (AC: 5, 6)
  - [x] Verify an iOS preset or setup note records iOS as non-runnable/deferred in the Windows workspace.
  - [x] Record that iOS export requires macOS with Xcode and Godot export templates.
  - [x] Keep iOS signing/team identifiers blank or placeholder-only; do not add secrets or account-specific values.
  - [x] Confirm iOS deferral does not block the headless test harness or Epic 1 domain work.

## Dev Notes

### Current Repository Baseline

The repository already contains a Godot production skeleton and should be reused. Do not recreate the Godot project, replace the test harness wholesale, or introduce a third-party gameplay starter unless a specific verification failure requires a scoped repair.

Current baseline verified during story creation on 2026-06-04:

- `godot --version` returned `4.6.3.stable.official.7d41c59c4`.
- `godot --headless --path C:\Sealsworn\godot --scene res://tests/headless/test_runner.tscn --quit-after 10` passed.
- Passing tests reported:
  - `res://tests/unit/core/test_action_result.gd`
  - `res://tests/unit/core/test_create_board_command.gd`
  - `res://tests/unit/core/test_domain_event.gd`
  - `res://tests/unit/core/test_rng_stream_set.gd`
  - `res://tests/unit/save/test_run_snapshot.gd`
  - `res://tests/unit/save/test_save_repository.gd`
  - `res://tests/unit/tactical/test_board_state.gd`
- `git status --short` was clean before story creation.
- Recent implementation checkpoint: `016e0b5 chore: checkpoint Sealsworn planning and Godot foundation`.

If the dev agent finds the same baseline still passes, the work for this story is mostly verification, documentation repair, and marking tasks complete after the validation gates. If any baseline has drifted, fix only the smallest setup/test/documentation issue needed to satisfy Story 1.1.

### Existing Files To Verify Or Update

| Path | Current State | This Story Changes | Preserve |
|---|---|---|---|
| `godot/project.godot` | Godot 4.6.3 standard config with `run/main_scene="res://scenes/app/boot.tscn"`, Mobile renderer, mobile viewport, icon placeholder, and thin autoloads. | Verify version, standard/GDScript setup, no prototype dependency, and scene-independent domain direction. Repair only if config drifted. | Keep autoloads thin. Do not add gameplay decisions to autoloads. Do not convert to .NET/C#. |
| `godot/export_presets.cfg` | Contains non-secret Windows Desktop MVP, Android MVP, and iOS MVP scaffold presets. Filters include production roots and exclude `addons/**`, `data/source/**`, `scenes/debug/**`, `tests/**`, `tools/**`, and test scripts. | Verify presets or document any missing export prerequisites. Keep Android non-signed and iOS deferred unless local platform prerequisites exist. | No secrets, no accounts, no cloud, no telemetry dependency, no prototype dependency. |
| `godot/README.md` | Records engine/language/target/architecture and the headless test command. It does not yet record a Windows dev-run command. | Add or verify the Windows dev-run command and any setup notes needed for local reproducibility. | Keep concise setup documentation; do not duplicate root `project-context.md`. |
| `godot/tests/headless/test_runner.gd` | Custom addon-free runner discovers `res://tests/unit` and `res://tests/integration`, loads `test_*.gd`, runs `run()`, prints pass/fail, and exits with failure count. | Verify exit-code behavior and scene-independent loading. Repair only if it fails or no longer discovers tests. | Keep headless runner domain/test focused. Do not require rendered scenes, audio, UI, or external services. |
| `godot/tests/headless/test_runner.tscn` | Minimal `Node` scene with `test_runner.gd`. | Verify it runs in headless mode. | Keep it minimal; do not turn this into gameplay presentation. |
| `godot/tests/unit/test_case.gd` | Lightweight assertion base with no external addon requirement. | Keep or extend only as needed for setup smoke tests. | Avoid adding a new test dependency unless explicitly approved or already established by project policy. |
| `godot/scripts/core/results/action_result.gd` and `godot/scripts/core/events/domain_event.gd` | Existing domain scripts loaded by tests. | Use as smoke-test targets if needed; do not expand beyond Story 1.1 setup scope. | Preserve typed GDScript command/event direction for later stories. |
| `godot/scripts/tactical/board/board_state.gd` and `board_cell.gd` | Existing scene-independent board domain scripts already covered by tests. | Use as proof that headless tests can load tactical domain code. Do not broaden tactical behavior in this story. | Preserve domain ownership and no scene-node dependency. |
| `godot/scripts/platform/platform_services.gd` | Local/no-op interface methods for telemetry, achievements, and save sync. | Verify no external service is introduced. If referenced in notes, call out as no-op MVP placeholder only. | Do not add runtime telemetry, cloud save, achievement service, account, or multiplayer integration. |

### Technical Requirements

- Production root is `godot/`; do not put production Godot code in `prototype/`.
- Godot version target is 4.6.3 stable standard, GDScript-first.
- Use typed GDScript for scripts and tests touched by this story.
- Initial project must be a clean custom Godot project, not a third-party gameplay starter.
- Headless tests must run through Godot without rendering, audio, UI scenes, presentation nodes, or scene-tree-only tactical state.
- Test execution must return a non-zero exit code when failures occur.
- Prefer the existing custom headless runner unless there is a concrete failure. Architecture allows GUT or equivalent; the current runner is the equivalent for this setup story.
- Build/export setup is scaffolding only. Do not attempt signed mobile exports in this story unless all local prerequisites already exist and no secrets are needed.

### Architecture Compliance

- Tactical truth belongs in scene-independent domain scripts under `godot/scripts/`, not scenes.
- Godot scenes, `Control` nodes, audio, VFX, animation, and UI are presentation mirrors only.
- Thin autoloads are allowed for `GameSession`, `SceneManager`, `SaveManager`, `AudioManager`, and `Diagnostics`; they must delegate gameplay decisions to domain services.
- Gameplay actions in later stories must be validated commands returning `ActionResult` and successful past-tense `DomainEvent` records.
- Story 1.1 must not implement new gameplay breadth beyond setup, smoke tests, and documentation needed for the harness.
- Static content authoring/source and runtime resource mirrors must keep the `godot/data/source` and `godot/data/resources` boundary.
- Save truth must be versioned domain snapshots only; do not serialize scene nodes.

### Library And Framework Requirements

- Required engine: Godot 4.6.3 stable standard.
- Required language: typed GDScript.
- No Godot .NET/C# dependency for MVP.
- No React/Vite production dependency.
- No cloud services, accounts, multiplayer, telemetry dependency, leaderboards, or live-service setup.
- GoPeak Godot MCP and Context7 are optional AI tooling selected by architecture once the Godot project exists and the local executable path is known. This story does not require adding MCP client configuration unless a local project policy file already expects it.

### Latest Technical Information

Official Godot sources checked on 2026-06-04:

- The Godot archive lists `4.6.3-stable` dated 2026-05-20 and current state stable. Use 4.6.3 unless the architecture is intentionally revised. [Source: Godot archive](https://godotengine.org/download/archive/)
- Godot stable command-line documentation supports `--path <directory>` for a project containing `project.godot`, `--scene <path>` to start a scene, `--quit-after` to stop after a frame count, and `--headless` for headless display/audio driver mode. These support the existing test command. [Source: Godot command line tutorial](https://docs.godotengine.org/en/stable/tutorials/editor/command_line_tutorial.html)
- Android export setup requires export templates plus OpenJDK 17, Android SDK setup via Android Studio or `sdkmanager`, and the current required Android packages listed in the stable docs. Record missing local prerequisites rather than blocking domain work. [Source: Godot Android export docs](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_android.html)
- iOS export must be done from macOS with Xcode installed and Godot export templates. C# iOS export remains experimental, reinforcing the GDScript standard-build decision. [Source: Godot iOS export docs](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_ios.html)

### Project Structure Notes

Current `godot/` structure already includes more than Story 1.1 requires:

- Domain folders: `scripts/core`, `scripts/tactical`, `scripts/rules`, `scripts/generation`, `scripts/ai`, `scripts/content`, `scripts/save`, `scripts/ui`, `scripts/platform`, `scripts/diagnostics`, `scripts/utils`.
- Scene folders: `scenes/app`, `scenes/game`, `scenes/ui`, `scenes/entities`, `scenes/effects`, and `scenes/debug`.
- Data folders: `data/source`, `data/resources`, `data/schemas`, and `data/localization`.
- Test folders: `tests/headless`, `tests/unit`, `tests/integration`, and `tests/fixtures`.
- Asset/tool folders: `assets/` and `tools/`.

Do not delete or flatten existing folders because later stories depend on this architecture map. Empty architecture folders are acceptable placeholders for future stories.

Detected variance: the architecture's early "recommended initial structure" includes some generic folders (`scripts/presentation`, `scripts/resources`, `scripts/systems`), while root `project-context.md` and the later architecture/project structure rules use the current domain-specific roots (`core`, `tactical`, `rules`, `generation`, `ai`, `content`, `save`, `ui`, `platform`, `diagnostics`, `utils`). Prefer the root `project-context.md` and later architecture boundary rules.

### Testing Requirements

Minimum validation for Story 1.1:

```powershell
godot --version
godot --headless --path C:\Sealsworn\godot --scene res://tests/headless/test_runner.tscn --quit-after 10
```

Expected result:

- Godot version is `4.6.3.stable.official...` or otherwise clearly compatible with project policy.
- Headless runner exits with code `0`.
- At least one domain-only test passes.
- No test requires rendered gameplay scenes, audio, UI scenes, presentation nodes, or external services.

Windows development run command to record or verify:

```powershell
godot --path C:\Sealsworn\godot
```

Optional explicit boot scene run:

```powershell
godot --path C:\Sealsworn\godot --scene res://scenes/app/boot.tscn
```

Do not mark this story complete if the headless harness only passes by skipping all tests. Test discovery must find and run actual `test_*.gd` scripts.

### Project Context Rules

- Read and follow root `project-context.md` before implementation.
- Read `_bmad-output/game-architecture.md` before architecture-sensitive changes.
- Root `project-context.md` is canonical; do not create duplicate project context under `_bmad-output/`.
- Production code goes under `godot/`; React/Vite `prototype/` remains validation evidence only.
- Production engine is Godot 4.6.3 stable standard; primary language is typed GDScript.
- Target platforms are iOS/Android mobile and tablet first with Windows desktop/laptop parity.
- MVP is offline-first single-player.
- Scene-independent domain model owns tactical truth.
- Godot scenes, UI, audio, VFX, and animation mirror domain outcomes; they do not own gameplay state.
- Commands validate before mutation and return `ActionResult`.
- Successful commands emit deterministic past-tense `DomainEvent` records.
- Use named RNG streams for gameplay-affecting randomness.
- Save versioned domain snapshots only; never serialize scene nodes as save truth.
- Static content uses JSON/CSV source plus typed Godot Resources through repository/import boundaries.
- Headless simulation must not depend on rendering, audio, UI scenes, presentation nodes, or scene-tree-only state.
- Do not introduce cloud services, accounts, multiplayer, telemetry dependencies, or Godot .NET/C# unless architecture is explicitly revised.
- Preserve user changes and unrelated dirty worktree files.

### References

- [Source: `_bmad-output/planning-artifacts/epics.md` - Story 1.1]
- [Source: `_bmad-output/implementation-artifacts/epic-1-sprint-plan-2026-06-04.md` - Sprint Slice 0]
- [Source: `project-context.md` - Technology Stack, Engine Rules, Testing Rules, Critical Don't-Miss Rules]
- [Source: `_bmad-output/game-architecture.md` - Engine & Framework, Project Initialization, Architectural Boundaries, Development Environment]
- [Source: `_bmad-output/planning-artifacts/gdds/gdd-Game-2026-05-31/gdd.md` - Technical Specifications and Platform-Specific Details]
- [Source: Godot archive - 4.6.3 stable](https://godotengine.org/download/archive/)
- [Source: Godot stable command-line tutorial](https://docs.godotengine.org/en/stable/tutorials/editor/command_line_tutorial.html)
- [Source: Godot stable Android export docs](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_android.html)
- [Source: Godot stable iOS export docs](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_ios.html)

## Dev Agent Record

### Agent Model Used

Codex GPT-5

### Implementation Plan

- Verify existing setup first and repair only drift needed for Story 1.1.
- Add lightweight headless regression coverage for project setup guarantees instead of broadening gameplay scope.
- Keep production Godot code independent from `prototype/`, cloud services, accounts, multiplayer, telemetry, and Godot .NET/C#.

### Debug Log References

- 2026-06-04: Red check: `godot --headless --path C:\Sealsworn\godot --scene res://tests/headless/test_runner.tscn --quit-after 10` failed after intentionally wrong boot-scene expectation in new setup test.
- 2026-06-04: Green check: same headless command passed after correcting expected `run/main_scene` to `res://scenes/app/boot.tscn`.
- 2026-06-04: Red check: headless suite discovered the new integration smoke test and failed on an intentionally wrong `res://scripts/missing_core` folder expectation.
- 2026-06-04: Green check: same headless command passed after correcting the required domain root to `res://scripts/core`.
- 2026-06-04: Red check: headless suite failed `test_setup_documentation.gd` because `godot/README.md` was missing `godot --version` and Windows dev-run commands.
- 2026-06-04: Green check: same headless command passed after documenting the required setup commands.
- 2026-06-04: Red check: headless suite failed `test_export_setup.gd` because `godot/README.md` was missing Android export prerequisites.
- 2026-06-04: Green check: same headless command passed after documenting Android prerequisites and export filter notes.
- 2026-06-04: Red check: headless suite failed `test_export_setup.gd` because `godot/README.md` was missing deferred iOS export notes.
- 2026-06-04: Green check: same headless command passed after documenting iOS deferral, macOS/Xcode requirements, and blank signing guidance.
- 2026-06-04: Final regression: `godot --headless --path C:\Sealsworn\godot --scene res://tests/headless/test_runner.tscn --quit-after 10` passed.
- 2026-06-04: Final version check: `godot --version` returned `4.6.3.stable.official.7d41c59c4`.
- 2026-06-04: Final production dependency scan found no prototype, Godot .NET/C#, cloud, telemetry, or multiplayer service references outside tests/docs.
- 2026-06-04: No production Godot lint/static-analysis command is configured; only `prototype/package.json` was found and was not used.

### Completion Notes List

- Story context created on 2026-06-04. Existing Godot foundation and headless tests were discovered and documented as the baseline to verify or repair.
- Verified `godot/project.godot` as a Godot 4.6 standard GDScript setup with Mobile renderer, 1080x1920 mobile-first viewport, minimal app boot scene, and no prototype/.NET dependency in project config.
- Added a headless project configuration regression test covering the setup guarantees for Story 1.1.
- Verified architecture folder roots with executable headless coverage and added an integration smoke test proving the runner discovers integration tests and can load core/tactical domain scripts without presentation dependencies.
- Documented the Windows-friendly headless test command, `godot --version`, default production dev-run command, and explicit boot-scene dev-run command in `godot/README.md`.
- Verified non-secret Windows and Android export scaffolding, production export exclusions, and Android prerequisite documentation with a headless regression test.
- Recorded iOS export as deferred in the Windows workspace, documented macOS/Xcode and Godot export template requirements, and verified tracked iOS signing/team fields remain blank.
- Completed Story 1.1 definition-of-done checks: all tasks/subtasks are checked, all acceptance criteria are covered, the full headless regression suite passes, and the story is ready for review.

### File List

- `_bmad-output/implementation-artifacts/1-1-production-godot-project-and-headless-test-harness.md`
- `_bmad-output/implementation-artifacts/sprint-status.yaml`
- `godot/README.md`
- `godot/tests/integration/test_headless_domain_loading.gd`
- `godot/tests/unit/core/test_export_setup.gd`
- `godot/tests/unit/core/test_project_configuration.gd`
- `godot/tests/unit/core/test_project_structure.gd`
- `godot/tests/unit/core/test_setup_documentation.gd`

## Change Log

- 2026-06-04: Created Story 1.1 implementation guide from Epic 1 sprint plan, canonical epics, project context, architecture, current Godot files, and official Godot technical references.
- 2026-06-04: Started implementation, captured baseline commit, marked story in progress, and added project configuration regression coverage.
- 2026-06-04: Added architecture-folder and integration-discovery regression coverage for the headless test harness.
- 2026-06-04: Documented local Godot version and Windows run/test commands in the Godot README.
- 2026-06-04: Documented Android export prerequisites and added export setup regression coverage.
- 2026-06-04: Documented iOS export deferral and blank signing guidance.
- 2026-06-04: Completed Story 1.1 validation and marked the story ready for review.
