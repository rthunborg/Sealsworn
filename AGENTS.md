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

## Mandatory Story Workflow

- Work from the current story file under `_bmad-output/implementation-artifacts/` and keep `sprint-status.yaml` in sync with the story status.
- Do not move a story to `done` until implementation, tests, code review, review patches, story status, sprint status, and commit cleanup are complete.
- Use `gds-code-review` for stories reaching review. If the review records patch findings, fix them or explicitly leave them as action items before changing status.
- Patch findings that are fixed must be checked off in the story file. Deferred findings must be recorded in `_bmad-output/implementation-artifacts/deferred-work.md` with the originating story/review date.
- After review patches, rerun `godot --headless --path C:\Sealsworn\godot --scene res://tests/headless/test_runner.tscn --quit-after 10` and `git diff --check`.
- When all blocking review findings are resolved, set the story file `Status: done`, update the matching `development_status` entry in `sprint-status.yaml`, and refresh `last_updated`.
- Commit all relevant story, code, test, fixture, and tracking files before starting the next story.
- Before handing off, remove only proven-redundant generated files or temp files, never planning artifacts or story files. Verify `git status --short` is clean.

## Presenting Decisions That Need Human Input

Whenever a decision is escalated to the human — a `[Review][Decision]` finding, an ambiguity that
changes the outcome, a scope or design fork, a `needs-human` stop — present it in **player/user
terms first, code terms second**. The human must be able to make a competent call without reading
the diff. Never reduce a decision to a one-line question, a bare finding title, or a menu of
options with no analysis.

**Investigate before presenting.** Read the actual code paths, content definitions, and data the
decision touches. A decision presentation built only from a reviewer's summary, a story file, or
inference is not acceptable — verify what the code really does, and say which files you checked.

**Required shape for each decision:**

1. **What happens now** — the concrete current behavior, in the order the player/user encounters
   it. Cite the real files and lines (`file.gd:123`).
2. **What that means for the player** — walk a specific in-game scenario end to end. Name the
   actual stakes: what the player sees, loses, gains, can exploit, or misreads. Include what
   silently works as well as what visibly breaks.
3. **Why it is built this way** — the constraint, acceptance criterion, or deliberate trade-off
   that produced the current behavior. Distinguish "required by the AC" from "optional and
   skipped" from "oversight".
4. **Options** — every genuinely viable direction, including keeping the current behavior. For
   each: what changes for the player, rough implementation cost, and what it risks or forecloses.
   Name any dependency the option would pull in (a missing screen, an absent system, a schema
   change).
5. **An unbiased recommendation** — state which option you would pick **and why**, calibrated to
   the scope of the decision: weigh the finding's severity, the story's acceptance criteria, the
   cost of doing it now vs later, and whether a scheduled later story already covers it. Do not
   default to the largest or the smallest option; do not hedge into "either is fine" when the
   evidence favors one. Say plainly when the honest answer is that all options are defensible,
   and give the tie-breaker you would use.

Recommendations are advisory. The human decides; never proceed on a guessed direction, and never
implement a `[Review][Decision]` item that has no chosen direction.

## Before Finishing Work

- Run relevant tests or explain why they could not be run.
- Check that new code follows `project-context.md`.
- Do not introduce cloud services, accounts, multiplayer, telemetry dependencies, or Godot .NET/C# unless the architecture is explicitly revised.
- Preserve user changes and unrelated dirty worktree files.
