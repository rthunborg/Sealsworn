# Sealsworn Agent Guide

This repository contains the Sealsworn game project and its planning artifacts. Agents working here must treat root `project-context.md` as the compact implementation rulebook and `_bmad-output/game-architecture.md` as the full architecture source of truth.

Do not create duplicate project context files under `_bmad-output/`; root `project-context.md` is the canonical location.

## Required Reading

- Read `project-context.md` before implementing or modifying game code.
- Read `_bmad-output/game-architecture.md` before touching architecture-sensitive systems.
- For design intent, read `_bmad-output/planning-artifacts/gdds/gdd-Game-2026-05-31/gdd.md`.
- For story/feature breakdowns, read `_bmad-output/planning-artifacts/gdds/gdd-Game-2026-05-31/epics.md`.

## Current Production Direction

- Production engine: Godot 4.6.3 stable standard build.
- Primary language: typed GDScript.
- Production project root: `godot/`.
- Target platforms: iOS/Android mobile and tablet first; Windows desktop/laptop parity.
- MVP is offline-first single-player.
- The React/Vite `prototype/` is validation evidence only. Do not make production Godot code depend on it.

## Hard Architecture Rules

- Scene-independent domain model owns tactical truth.
- Godot scenes, UI, audio, VFX, and animation mirror domain outcomes; they do not own gameplay state.
- Gameplay actions are commands that validate before mutation and return `ActionResult`.
- Successful commands emit deterministic past-tense domain events.
- Use named RNG streams for gameplay-affecting randomness.
- Save versioned domain snapshots only; never serialize scene nodes as save truth.
- Static content uses JSON/CSV source plus typed Godot Resources through repository/import boundaries.
- Headless simulation must not depend on rendering, audio, UI scenes, presentation nodes, or scene-tree-only state.

## Implementation Order Bias

When starting implementation, prefer this order:

1. Domain model and core state.
2. Commands, results, and domain events.
3. Named RNG streams.
4. Tactical board model and tests.
5. Rules kernel and generation validation.
6. Save snapshots and repositories.
7. UI presenters, scenes, animation, audio, and polish.

Do not start with UI-heavy scenes before the model, command/event flow, RNG, and tactical board tests exist.

## File Placement

- Production Godot code goes under `godot/`.
- Domain scripts go under `godot/scripts/` by domain: `core`, `tactical`, `rules`, `generation`, `ai`, `content`, `save`, `ui`, `platform`, `diagnostics`, `utils`.
- UI scenes go under `godot/scenes/ui/`; gameplay shell and board scenes go under `godot/scenes/game/`.
- Runtime-ready assets go under `godot/assets/`.
- Editable source assets, prompts, provenance, and reviews go under `asset_sources/`.
- Static content source goes under `godot/data/source/`; resource mirrors go under `godot/data/resources/`.
- Tests go under `godot/tests/`, mirroring the domain they cover.

## Naming

- Folders and files use `snake_case`.
- Classes use `PascalCase`.
- Functions, variables, and signals use `snake_case`.
- Constants use `UPPER_SNAKE_CASE`.
- Commands use names like `AttackCommand`.
- Domain events use names like `DamageAppliedEvent`.
- Definitions use `*Definition`; snapshots use `*Snapshot`; results use `*Result`.

## Testing Expectations

- Every command gets valid and invalid/no-mutation tests.
- Rules need trigger/order/stacking/conflict tests.
- Generator phases need fixtures or seed regression tests.
- Save snapshots need migration tests for schema changes.
- AI decisions need explanation tests.
- Headless tests must run without rendering/audio/UI dependencies.

## AI and Asset Rules

- AI tools may help author or explore content during development, but the game must not call AI to generate runtime content.
- Procedural generation selects from approved static definitions only.
- Content and assets require validation plus human approval before production use.
- Track generated or assisted assets with tool, prompt, date, source, license/provenance, editable source path, runtime export path, and approval status.

## Before Finishing Work

- Run relevant tests or explain why they could not be run.
- Check that new code follows `project-context.md`.
- Do not introduce cloud services, accounts, multiplayer, telemetry dependencies, or Godot .NET/C# unless the architecture is explicitly revised.
- Preserve user changes and unrelated dirty worktree files.
