---
project: Sealsworn
date: 2026-06-07
scope: Epic 2 planning
readiness_status: READY_AFTER_EPIC_1_CLOSEOUT
source_epics_file: C:/Sealsworn/_bmad-output/planning-artifacts/epics.md
status_file: C:/Sealsworn/_bmad-output/implementation-artifacts/sprint-status.yaml
---

# Epic 2 Sprint Plan

## Source Inputs

- `C:/Sealsworn/AGENTS.md`
- `C:/Sealsworn/project-context.md`
- `C:/Sealsworn/_bmad-output/game-architecture.md`
- `C:/Sealsworn/_bmad-output/planning-artifacts/epics.md`
- `C:/Sealsworn/_bmad-output/planning-artifacts/gdds/gdd-Game-2026-05-31/gdd.md`
- `C:/Sealsworn/_bmad-output/implementation-artifacts/epic-1-sprint-plan-2026-06-04.md`
- `C:/Sealsworn/_bmad-output/implementation-artifacts/sprint-status.yaml`

## Scope Decision

Plan the Epic 2 path for mobile-first tactical UX, accessibility, and save/resume foundation after Epic 1 combat closeout.

Epic 2 should start from domain-facing contracts, not polished scenes. The first implementation work should expose tactical state through read-only view models and a command bridge, then layer preview, inspect, commit, layout, accessibility, and save/resume behavior on top.

Epic 1 still has active closeout work. Do not mark Epic 2 implementation as started until Story 1.10 is done, Story 1.11 is done, the Epic 1 review workflow is complete, sprint status is current, and the Epic 1 closeout tests pass.

## Execution Guardrails

- Godot scenes, UI, audio, VFX, and animation mirror domain outcomes; they do not own tactical state.
- UI presenters submit intent through a command bridge; only domain commands mutate tactical truth.
- View models expose read-only tactical state, previews, selection state, inspect data, action availability, and settings-facing presentation state.
- Movement and attack previews must remain pure: no events, no turn advance, no gameplay RNG consumption, and no board mutation.
- Two-step attack commit is the mobile default; enemy and level systems advance only after a successful command result.
- Layout and orientation changes never submit gameplay commands and never change tactical rules.
- Accessibility is part of the slice: scalable text, no color-only critical information, and visual/textual equivalents for audio cues.
- Save/resume writes versioned domain snapshots through `SaveRepository`; scene nodes are never save truth.
- Settings are preferences only and must not mutate active tactical truth, RNG state, rewards, progression, or difficulty.
- No accounts, cloud saves, multiplayer, telemetry, live-service dependency, Godot .NET/C#, or React/Vite production dependency.

## Recommended Sprint Slices

### Sprint Slice 0: Epic 1 Closeout Gate

Goal: make sure Epic 2 starts on a stable tactical slice rather than compensating for unfinished combat behavior.

Parent stories:
- Story 1.10: Enemy Turn Resolution for Prototype Enemies
- Story 1.11: Combat Outcome, Death/Victory, and Explanation Log

Implementation tasks:
- Finish Story 1.10 review patches and mark story findings resolved or deferred.
- Implement and review Story 1.11.
- Run the Epic 1 headless suite and `git diff --check`.
- Confirm the tactical slice has stable board, fog, movement, attack preview, attack command, enemy turn, outcome, and explanation-log tests.
- Confirm the micro-combat scenario can be used as the Epic 2 view-model fixture.

Exit gate:
- Epic 1 is marked done or has an explicit approved exception before Epic 2 implementation starts.

### Sprint Slice 1: View Models and Command Bridge

Goal: establish the presentation boundary before any device-specific UI grows around it.

Parent story:
- Story 2.1: Tactical View Models and Command Bridge

Implementation tasks:
- Create read-only tactical board, cell, occupant, visibility, selection, preview, and action availability view-model data.
- Implement a command bridge that converts UI intents into typed domain commands.
- Return stable disabled-action or conversion-error states for invalid UI intent.
- Add tests proving presenters cannot receive mutable domain internals.
- Add no-mutation tests for invalid UI intent and command conversion failures.

Exit gate:
- UI-facing tests can select move/attack/inspect intents and prove all mutation still flows through domain commands.

### Sprint Slice 2: Preview Presentation Contracts

Goal: make movement and attack previews usable through stable UI-facing DTOs before commit flow is implemented.

Parent story:
- Story 2.2: Movement and Attack Preview Presentation Contracts

Implementation tasks:
- Expose movement path, movement cost, target validity, blocked reasons, and commit availability.
- Expose weapon reach, line/path, expected damage, effects, blocker state, warnings, and invalid reasons.
- Preserve preview alignment with the Epic 1 command-validation reasons.
- Add tests that previews are deterministic and do not mutate state or consume gameplay RNG.
- Define cue ids for preview-only versus committed-action feedback without requiring final audio assets.

Exit gate:
- Movement and attack previews can drive UI without invoking command execution.

### Sprint Slice 3: Mobile Commit Safety

Goal: prevent mis-taps from spending turns or advancing enemies.

Parent story:
- Story 2.3: Mobile Two-Step Commit and Cancel Flow

Implementation tasks:
- Implement attack preview mode state for first target tap.
- Submit `AttackCommand` only on same-target second tap or explicit confirm.
- Clear preview mode on cancel, different target, invalidation, or mode switch.
- Add tests proving cancel and target changes do not mutate tactical state.
- Add tests proving enemy turns advance only after successful command results.

Exit gate:
- The mobile default input path requires deliberate confirmation for attacks and has no accidental command path.

### Sprint Slice 4: Inspect, Zoom, and Layout Profiles

Goal: make the tactical slice readable across phone portrait, phone landscape, tablet, and desktop-style layouts.

Parent stories:
- Story 2.4: Inspect and Zoom Tactical Information
- Story 2.5: Adaptive Layout Profiles

Implementation tasks:
- Expose inspect data for tile, terrain, occupant, move cost, attack preview, hazards, and telegraphed danger.
- Keep unexplored hidden facts hidden and explored-memory facts non-authoritative.
- Implement zoom bounds and coordinate mapping tests for board cells.
- Define layout profiles for phone portrait, phone landscape, tablet, and desktop-style viewports.
- Preserve selection and preview state through viewport/orientation changes.
- Add tests or scene-level checks that layout changes do not submit commands.

Exit gate:
- A phone-sized tactical fixture can inspect, zoom, preview, and rotate/reflow without rule changes or accidental commits.

### Sprint Slice 5: Accessibility and Settings Baseline

Goal: make readability and preferences explicit before broader content and UI surface area expands.

Parent stories:
- Story 2.6: Accessibility and Tactical Readability Baseline
- Story 2.9: Settings and Difficulty Non-Goal Guardrails

Implementation tasks:
- Define non-color-only indicators for movement validity, attack range, blocked line, danger, telegraphs, preview, and commit state.
- Add scalable text bounds for tactical HUD, previews, and inspect panels.
- Add audio preference fields and mute/volume behavior as presentation settings only.
- Add input preference fields without changing tactical rules.
- Add guardrail tests or validation preventing easy/normal/hard or generic difficulty ladder fields.
- Add visual/textual equivalents for all critical preview, warning, damage, and reward feedback paths.

Exit gate:
- Essential tactical information remains available without color or audio, and settings cannot alter gameplay truth.

### Sprint Slice 6: Save/Resume Foundation

Goal: make interruption-friendly play reliable before procedural run structure depends on it.

Parent stories:
- Story 2.7: Between-Level Save Snapshot Foundation
- Story 2.8: Resume Flow and Mid-Level Save Feasibility

Implementation tasks:
- Implement `SaveRepository` result types for write, load, validation, corruption, version mismatch, and recovery.
- Write between-level autosaves as versioned domain snapshots in `user://`.
- Include schema version, content version, root seed, named RNG stream states, current node placeholder, player state, inventory placeholders, and manual-seed eligibility.
- Reuse Epic 1 tactical snapshot structures instead of creating a scene-owned save format.
- Restore between-level state and rebuild presentation from domain snapshots.
- Evaluate mid-level save/resume feasibility and record implemented, deferred, or limited status.
- If mid-level save is implemented, add restore tests for fog, entities, pending turn state, event log, and RNG stream state.
- Compare interrupted and uninterrupted command sequences and report first divergent event or RNG stream.

Exit gate:
- Between-level save/resume works through domain snapshots, and mid-level feasibility is explicitly recorded.

## Dependency Order

1. Finish Epic 1 closeout and review patches.
2. Build view models and command bridge.
3. Add movement and attack preview contracts.
4. Add mobile two-step commit and cancel flow.
5. Add inspect, zoom, and adaptive layout profiles.
6. Add accessibility/readability and settings guardrails.
7. Add between-level save/resume foundation and mid-level feasibility decision.

## Gates Before Later Work

- Before Epic 3 generation: Epic 2 must define board readability constraints, zoom/inspect behavior, and save/resume boundaries that generated levels must honor.
- Before UI-heavy scene polish: confirm view models and command bridge are stable enough that scenes remain presentation-only.
- Before production art/audio dependence: placeholder ids and cue ids are enough for Epic 2, but final MVP readiness still requires Story 10.7 asset/audio validation.
- Before settings expansion: keep settings to readability, input, and audio preferences; no generic difficulty selector.

## Asset and Audio Planning Note

Start arranging graphics and sound before Epic 5, with lightweight style exploration during Epic 2 or Epic 3 if schedule allows. Epic 2 benefits from placeholder UI frames, tactical indicators, preview/confirm cue ids, and temporary SFX, but it does not require final production assets.

The first epic that likely needs coordinated external or dedicated asset production is Epic 5, because class selection needs playable class portraits/icons or silhouettes, locked class silhouettes/icons, starting kit identity, and hero-select presentation. Asset pressure increases again in Epic 6 for 20-30 passive icons and item/support/weapon icons, Epic 7 for affinity treatments, Epic 8 for outpost/run-summary UI, and Epic 9 for the Larval Avatar.

Use Epic 10.7 as the formal readiness gate for placeholder replacement, de-scope, approval, provenance, and production asset/audio acceptance.

## Tracking Summary

- Epic count added to scoped planning: 1
- Parent stories in this scoped plan: 9
- First implementation story: `2-1-tactical-view-models-and-command-bridge`
- Retrospective entry: `epic-2-retrospective`
- Initial status posture: backlog, because no Epic 2 story files exist yet
