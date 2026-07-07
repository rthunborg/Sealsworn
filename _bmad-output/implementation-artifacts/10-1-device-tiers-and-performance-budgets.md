# Story 10.1: Device Tiers and Performance Budgets

Status: ready-for-dev

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a player,
I want the MVP to remain responsive on target devices,
so that tactical decisions feel deliberate rather than sluggish.

## Story Type & Scope Boundary (READ FIRST)

**This is primarily a READINESS-PLANNING / MEASUREMENT-DEFINITION story — the analog of Story 11.1
(the UX appendix), not a gameplay-feature story.** The single required deliverable is a
**device-tiers + performance-budgets planning document (a markdown artifact)** authored under
`_bmad-output/planning-artifacts/`, PLUS — if it does not already exist in reusable form — a small,
**build-profile-gated, headless-runnable performance-measurement harness** that captures the
headless-measurable budgets (level-load time, preview/selection response, representative-run timing)
and writes an actionable report. This discharges the canonical **NFR20** production-readiness gap
(target device tiers, measurement methods, memory budget, battery/performance expectations must be
defined before production readiness) that the implementation-readiness report flagged as a MANDATORY
Epic-10 gate.

- **This is not a domain/tactical/save/RNG/content story.** Do NOT change any gameplay command,
  event, RNG stream, `RunSnapshot`/`ProfileSnapshot`/`SettingsSnapshot` schema, save key, generator
  fingerprint, view model, or content definition. The full headless suite (**182 PASS / 0 `^FAIL`**
  at Epic-11 close) must stay green and byte-for-byte behaviorally unchanged — this story adds a
  measurement/reporting harness + a planning doc, it does not perturb the simulation. If you add a
  measurement test, it is a NEW `test_*.gd` that ASSERTS on the harness's own contract (records
  shape, budget-comparison logic), not on gameplay outcomes.
- **The physical-device measurement dimension is inherently a HUMAN + HARDWARE action.** A headless
  agent cannot run a build on a physical low/mid/high Android/iOS device or a physical mobile battery,
  and no simulator/emulator/device is provisioned in this environment. The ACs EXPLICITLY allow this:
  each tier "names the physical device, emulator/simulator, or **explicit availability gap** used for
  measurement" (AC2), and battery drain is recorded "when measurement **is available**" (AC4). So the
  correct autonomous outcome is: **define the tiers + the measurement method + the budgets now,
  measure everything the headless/desktop harness CAN measure, and record every physical-device
  measurement as an EXPLICIT `availability gap → owning action (a physical-device measurement pass)`
  note** — do NOT invent fabricated device numbers, and do NOT block. This mirrors how 11.1 recorded
  contract gaps rather than inventing surfaces. (See "The measurement reality" in Dev Notes.)
- **Debug/instrumentation must stay build-profile gated and inert in production.** NFR19 + the
  project-context Platform rule "Debug/cheat tools must be disabled or inert in production builds" is a
  hard AC (AC5). Any instrumentation you enable for measurement must gate on the build profile
  (`OS.is_debug_build()`, the existing `LocalTimingRecorder` precedent) and must be a no-op / absent
  in a release/production export. Do NOT introduce a runtime telemetry dependency, a cloud call, or an
  always-on overlay (NFR11; `PlatformServices.record_telemetry` stays a local no-op).

## Acceptance Criteria

Sourced verbatim from `epics.md` (Epic 10, Story 10.1). Five AC groups (Given/When/Then + And):

1. **Device tiers defined (AC1).** GIVEN production readiness planning begins, WHEN device tiers are
   defined, THEN **low, mid, and high mobile target tiers plus Windows desktop parity expectations are
   documented**, AND **measurement method, memory expectations, and battery/performance notes are
   recorded**.

2. **Tier specifics + named measurement source (AC2).** GIVEN target tiers are documented, WHEN the
   readiness plan is reviewed, THEN **low tier includes a budget Android-class phone/tablet with
   roughly 4 GB RAM, mid tier includes a current-minus-two-years Android or iOS-class device with
   roughly 6 GB RAM, high tier includes a current flagship phone/tablet class device, and Windows
   parity includes an integrated-GPU laptop/desktop target**, AND **each tier names the physical
   device, emulator/simulator, or explicit availability gap used for measurement**.

3. **Performance budgets measured against targets (AC3).** GIVEN performance budgets are measured,
   WHEN generated level load, preview response, selection response, and combat frame stability are
   tested, THEN **results are compared against under-3-second level load, under-100ms preview/selection
   response, and 60 FPS where feasible or 30 FPS acceptable lower-end targets**, AND **failures produce
   actionable diagnostics**.

4. **Memory/battery/thermal over a representative run (AC4).** GIVEN memory, battery, and thermal
   expectations are measured, WHEN a **20-minute representative run or scripted simulation** is
   exercised on each available target tier, THEN **the build must avoid OS memory warnings or
   termination, stay below the recorded per-tier peak-memory budget, and avoid sustained thermal
   throttling or input degradation**, AND **battery drain is recorded with an initial planning target
   of no more than 15 percent over 30 minutes on a comparable physical mobile device when measurement
   is available**.

5. **Debug/instrumentation build-profile gated (AC5).** GIVEN performance tests run, WHEN debug
   overlays or instrumentation are enabled, THEN **they remain build-profile gated**, AND **production
   builds do not expose cheat/debug tools**.

### AC Verification (how "done" is checked)

- **AC1** — the planning doc has a section defining all three mobile tiers + Windows-desktop-parity,
  and each carries a measurement method, a memory expectation, and a battery/performance note. Missing
  any tier or any of the three per-tier notes = AC1 not met.
- **AC2** — each tier states the RAM band (low ~4 GB, mid ~6 GB, high flagship, desktop integrated-GPU
  target verbatim to the AC wording) AND names its measurement source as one of: a concrete physical
  device, a named emulator/simulator, or an explicit `availability gap` note (with the owning
  follow-up action). A tier missing its RAM band or its named source = AC2 not met.
- **AC3** — the doc states the four budget thresholds verbatim (level load < 3 s / NFR4, preview
  response < 100 ms / NFR5, selection response < 100 ms / NFR5, 60 FPS feasible-else-30 FPS / NFR6),
  the harness measures every one that is headless/desktop-measurable and compares to the threshold, and
  a threshold miss emits an actionable diagnostic (system + measured value + budget + delta — NEVER a
  bare "slow"). A budget with no stated threshold, no measurement path, or no failure diagnostic = AC3
  not met.
- **AC4** — the doc defines the 20-minute representative-run protocol (what run, what is sampled: peak
  memory, thermal/throttling proxy, input responsiveness) + the per-tier peak-memory budget + the
  battery target (≤ 15% / 30 min), and records the physical-device battery/thermal/memory measurements
  as `availability gap` notes where no device is provisioned. A missing protocol, missing per-tier
  memory budget, or a fabricated device number = AC4 not met.
- **AC5** — every instrumentation/overlay path the story adds or enables gates on the build profile
  (`OS.is_debug_build()` or the equivalent export-profile flag) and is provably inert/absent in a
  production/release export; the doc states the gating mechanism and the pre-export check that confirms
  no cheat/debug tool ships. An always-on or ungated instrumentation path = AC5 not met.

## Tasks / Subtasks

- [ ] **Task 1 — Create the readiness planning doc and frame it (AC1, AC2)**
  - [ ] Author `_bmad-output/planning-artifacts/device-tiers-and-performance-budgets.md` (a PLANNING
        artifact, NOT under `godot/`). Keep it discoverable and self-documenting; reference it from
        the Epic-10 readiness gate (Story 10.6 MVP readiness gate + 10.7 UX/asset gate consume it —
        neither exists as a file yet; the doc self-documents the linkage the way 11.1's appendix did
        for 10.7).
  - [ ] Open with: purpose (discharges the canonical **NFR20** production-readiness gap the
        implementation-readiness report flagged as a mandatory Epic-10 gate), scope (define tiers +
        measurement method + budgets + representative-run protocol; measure what is headless/desktop
        measurable; record physical-device measurements as availability gaps), and a one-line pointer
        to the project-context Performance rules + `game-architecture.md`.
  - [ ] Define the three mobile tiers + Windows-desktop-parity (AC1/AC2) using the AC wording as the
        floor: **low** = budget Android-class phone/tablet ~4 GB RAM; **mid** = current-minus-two-years
        Android/iOS-class ~6 GB RAM; **high** = current flagship phone/tablet; **desktop parity** =
        integrated-GPU laptop/desktop. For EACH tier record: measurement method, memory expectation,
        battery/performance note, and the named measurement source (physical device / emulator /
        `availability gap`).
  - [ ] State the platform posture: production is Godot 4.6.3 standard GDScript, Mobile renderer,
        iOS/Android-first + Windows parity (NFR1/NFR3); `export_presets.cfg` already exists (Windows +
        Android scaffolding from Story 1.1). iOS packaging remains deferred until macOS/Xcode access
        (project-context Platform rule) — record it as a tier-source gap, not a blocker.

- [ ] **Task 2 — Define the performance budgets + the headless/desktop measurement harness (AC3)**
  - [ ] State the four budget thresholds verbatim to the AC + the project-context Performance rules:
        generated level load < 3 s (NFR4), UI preview response < 100 ms (NFR5), selection response
        < 100 ms (NFR5), stable 60 FPS where feasible / 30 FPS acceptable lower-end (NFR6). Map each to
        the system that produces it (level load → `LevelGenerator.generate`; preview/selection →
        the tactical view-model / command-bridge preview path; frame stability → the live scene under
        `gameplay_shell.tscn` on device).
  - [ ] REUSE the existing instrumentation seam — do NOT author a parallel one. `LocalTimingRecorder`
        (`godot/scripts/diagnostics/local_timing_recorder.gd`) already: gates on `OS.is_debug_build()`
        in `_init`, exposes `begin(label)`/`end(label)`/`records()`, and captures the exact Epic-1
        labels a representative combat run needs (`board_query`, `line_of_sight_update`,
        `command_execution`, `enemy_turn_resolution`, `outcome_evaluation`). `Epic1MicroCombatScenario`
        (`godot/scripts/tactical/scenarios/epic_1_micro_combat_scenario.gd`) already drives a scripted
        combat path with `enable_timing` and returns `timing_records`. Extend/compose these; do not
        reinvent a timing primitive.
  - [ ] Build the headless-measurable measurement path: a build-profile-gated harness (a `tools/`
        `SceneTree` script and/or a diagnostics `RefCounted`) that measures level-load time over a seed
        sample (via `LevelGenerator.generate` wall-clock), the representative-run command/LoS/turn
        timings (via the `LocalTimingRecorder` labels), compares each to its budget, and emits an
        ACTIONABLE report (system + seed/label + measured value + budget + delta + pass/fail). Follow
        the `tools/dump_*` `extends SceneTree` + `print(...)` + `quit()` precedent
        (`dump_run_pacing_survey.gd`, `dump_seed_batch_report.gd`) for the headless report driver.
  - [ ] Record which budgets are headless/desktop-measurable (level load, command/LoS/turn timings,
        desktop wall-clock) vs which require an on-device render/frame profiler (sustained 60/30 FPS
        frame stability, on-device preview/selection latency under real touch). The latter go in the
        doc as `availability gap → physical-device measurement pass` notes — measured numbers only
        where the harness or a desktop run can genuinely produce them.

- [ ] **Task 3 — Representative-run + memory/battery/thermal protocol (AC4)**
  - [ ] Define the 20-minute representative run: the hands-off live run driver Epic 11 shipped
        (`RunOrchestrator.run_to_completion_live` / `auto_play_full_run` on the verified finale seed
        4242, or a scripted-simulation stand-in) is the closest existing "representative run" —
        reference it as the run under measurement; the headless harness exercises the scripted
        simulation, the on-device pass exercises the same flow on hardware. Do NOT build a new gameplay
        loop; compose the existing live driver.
  - [ ] Define the sampled signals + budgets: per-tier peak-memory budget (with the headless/desktop
        `OS.get_static_memory_usage()` / `Performance.get_monitor(...)` proxy noted as the
        instrumentation, gated on build profile), thermal-throttling / sustained-input-degradation
        proxy, and the battery target (≤ 15% over 30 min on a comparable physical mobile device). State
        the pass criteria verbatim (no OS memory warning/termination; below per-tier peak-memory
        budget; no sustained thermal throttling or input degradation).
  - [ ] Record the physical-device memory/battery/thermal measurements as explicit `availability gap`
        notes (no device provisioned here). Provide the exact protocol a later physical-device pass
        follows so the gap is dischargeable without re-designing the method.

- [ ] **Task 4 — Build-profile gating + no-production-cheat-tools guarantee (AC5)**
  - [ ] State the gating mechanism: all measurement instrumentation gates on `OS.is_debug_build()` (the
        `LocalTimingRecorder._init` precedent — `enabled = new_enabled and OS.is_debug_build()`), so it
        is a no-op in a non-debug/release export. Any `tools/` measurement script is a dev/CI driver
        that is NOT wired into a shipped scene or autoload.
  - [ ] Confirm + document the no-production-cheat-tools posture: `PlatformServices`
        (`godot/scripts/platform/platform_services.gd`) stays a local no-op (`record_telemetry` /
        `unlock_achievement` / `sync_save` are inert — NFR11/NFR19); no debug overlay, seed/fog/LoS
        viewer, or cheat path is registered in a production build. Record the pre-export validation
        checklist item (the project-context Platform rule "build-profile flags plus pre-export
        validation and manual release checklist") that verifies this before a release export.
  - [ ] If you add a measurement test, keep it a NEW `test_*.gd` under `tests/unit/diagnostics/` (the
        `test_boss_attempt_diagnostics.gd` precedent) or `tests/unit/tools/` that asserts on the
        harness's records shape + budget-comparison logic — NOT on gameplay outcomes, and NOT requiring
        a `SceneTree`/render/device. The full suite stays green.

- [ ] **Task 5 — Cross-check, gap ledger, and Epic-10 gate handoff (AC1–AC5)**
  - [ ] Consolidate every `availability gap → owning action` note (physical low/mid/high device
        measurement; on-device FPS/latency profiling; physical battery/thermal; iOS packaging) into a
        single "Measurement Availability Gaps" section, each naming the gap, the tier/budget affected,
        and the owning follow-up (a physical-device measurement pass; the 10.6/10.7 readiness gate).
        This is the honest-scope deliverable — the gate story (10.6) decides whether an availability
        gap is an acceptable documented readiness limitation or a hard blocker.
  - [ ] Cross-reference the sibling Epic-10 readiness stories the doc feeds: 10.2 (headless seed
        regression suite — the seed sample the level-load measurement draws over should be compatible),
        10.6 (MVP readiness gate — consumes the tier + budget definitions), 10.7 (asset/audio/UX
        readiness gate — consumes the perf/readability posture). Do NOT implement those stories'
        content here; record the handoff.
  - [ ] Verify the full headless suite is unchanged-green and `git diff --check` is clean; confirm no
        production `godot/` gameplay/save/RNG/content path was touched (only a new `tools/`/diagnostics
        measurement harness + its test + the planning doc).

## Dev Notes

### What this story is (and is not)

Epics 1–11 shipped a complete, headless, deterministic domain, the full scene-free view-model /
command-bridge contracts, AND (Epic 11) the first real on-screen run-flow / HUD / outpost scene layer
with a hands-off-playable live loop. What the project has NEVER had is a **defined set of target device
tiers, a measurement method, and stated performance/memory/battery budgets** — the canonical **NFR20**
gap. The implementation-readiness report (2026-06-04) repeatedly flagged this as the first Epic-10
production-readiness item to close (lines 436, 444, 742, 832, 920, 934, 944, 997). **Story 10.1 is the
paper-plus-harness that closes it**: it authors the device-tiers + performance-budgets planning doc and
the build-profile-gated measurement harness for the budgets a headless/desktop environment can actually
measure, and records everything requiring physical hardware as an explicit availability gap.

The single most important discipline (mirroring 11.1): **measure what CAN be measured now; record
honest gaps for the rest — do NOT fabricate device numbers, and do NOT silently expand into a gameplay
change.** This is a readiness-planning story; the simulation is untouched.

### The measurement reality (why physical-device numbers are availability gaps, not blockers)

- The ACs were written to be dischargeable WITHOUT a full device lab: AC2 explicitly permits "explicit
  availability gap" as a tier's measurement source, and AC4 explicitly conditions the battery number on
  "when measurement is available." So a headless autonomous run legitimately produces: the tier
  definitions, the measurement method, the headless/desktop-measured budgets (level-load time,
  command/LoS/turn timings, desktop wall-clock, static-memory proxy), and an availability-gap ledger for
  the on-device numbers (sustained FPS, real-touch latency, physical battery/thermal, physical low/mid/
  high phones, iOS).
- This is the SAME honesty posture 11.1 used (record the gap against an owner rather than invent the
  surface). The gate story (10.6) is where the project decides whether a still-open availability gap is
  an acceptable documented readiness LIMITATION or must be discharged by a physical-device pass before
  MVP-readiness passes. 10.1's job is to make each gap explicit + dischargeable, not to close all of them.
- **Do NOT stop and ask a human for device access as the primary outcome.** The story is completable and
  valuable without it (the doc + harness + gap ledger). Only escalate to `needs-human` if a required
  deliverable is genuinely un-authorable without an external secret/service — which is not the case here.

### Existing instrumentation to REUSE (do not reinvent)

Read these before authoring the harness; the pinned facts are load-bearing (a harness that forks a
parallel timing primitive or an always-on instrumentation path is a review miss):

| Seam | Path | Load-bearing detail |
|---|---|---|
| `LocalTimingRecorder` | `godot/scripts/diagnostics/local_timing_recorder.gd` | `_init(new_enabled=false)` sets `enabled = new_enabled and OS.is_debug_build()` — build-profile gated BY CONSTRUCTION (the AC5 precedent). `begin(label)`/`end(label)`/`records()`; records `{label, elapsed_usec}`; `enabled=false` makes every method a no-op. This is the canonical measurement primitive — extend/compose it. |
| `Epic1MicroCombatScenario` | `godot/scripts/tactical/scenarios/epic_1_micro_combat_scenario.gd` | Drives a scripted win/loss combat path with `enable_timing`; wraps `board_query`/`line_of_sight_update`/`command_execution`/`enemy_turn_resolution`/`outcome_evaluation` in the recorder and returns `timing_records`. The existing representative combat-timing driver. |
| `tools/dump_*` SceneTree scripts | `godot/tools/dump_run_pacing_survey.gd`, `dump_seed_batch_report.gd`, `dump_route_fingerprints.gd`, etc. | The headless report-driver precedent: `extends SceneTree` + `_init()` runs the survey over a seed list + `print(...)` a compact report + `quit()`. Follow this shape for the level-load / representative-run measurement report driver. NOT a shipped scene/autoload. |
| `RunOrchestrator` live drivers | `godot/scripts/run/run_orchestrator.gd` | `run_to_completion_live` / `auto_play_full_run` / `auto_play_boss_fight` (Epic 11, opt-in) are the closest existing "representative run" the AC4 20-minute protocol measures. The verified finale seed is **4242**. Compose it; do not build a new loop. The DEFAULT `run_to_completion` stays byte-identical — do not perturb it. |
| `PlatformServices` | `godot/scripts/platform/platform_services.gd` | Local no-op interface (`record_telemetry`/`unlock_achievement`/`sync_save` inert) — the NFR11/NFR19 posture the AC5 no-production-telemetry/cheat guarantee rests on. Keep it inert; do not wire a real telemetry sink. |
| `export_presets.cfg` | `godot/export_presets.cfg` | Windows + Android preset scaffolding exists (Story 1.1). The doc references the existing presets + the "build-profile flags + pre-export validation + manual release checklist" rule for the AC5 pre-export check. iOS preset deferred (macOS/Xcode gap). |

### Budgets + their sources (AC3) — stated thresholds are the project-context Performance rules

- **Generated level load < 3 s (NFR4).** Source: `LevelGenerator.generate(...)` (the bounded-retry
  pipeline, worst case ≤ `MAX_GENERATION_ATTEMPTS` = 8, deliberately kept inside the < 3 s budget — see
  the project-context Procedural Generation rules). Headless-measurable via wall-clock over a seed sample.
- **UI preview response < 100 ms (NFR5).** Source: the tactical preview view-models + command bridge
  (`TacticalMovementPreview` / `TacticalAttackPreview` via `TacticalCommandBridge`) — pure reads, no
  RNG. The DOMAIN compute is headless-measurable; the on-device render-to-glass latency is a gap.
- **Selection response < 100 ms (NFR5).** Same surface (selection/inspect intent). Domain compute
  measurable headless; on-device touch-to-feedback latency is a gap.
- **Stable 60 FPS where feasible / 30 FPS acceptable lower-end (NFR6).** Source: the live scene under
  `gameplay_shell.tscn` (Epic 11). Sustained frame stability is an ON-DEVICE render-profiler concern —
  a `availability gap → physical-device measurement pass` note (a headless run has no render frame loop).
- Every measured budget miss must emit an actionable diagnostic: **system + seed/label + measured value
  + budget + delta**, never a bare "slow" (the project-context generator-diagnostics discipline: compact,
  actionable, never a raw dump).

### Retro forward-prep folded in (Epic-11 retro → Epic-10, this story's slice)

Epic 11 is the most recently closed epic; its retrospective (`epic-11-retro-2026-07-06.md`) forward
sections (§7 "Next-Epic Preview — Epic 10", §8 Action Items, §9 Readiness, §10) are the epic-transition
prep for Epic 10. The items that bear on THIS story:

- **Reuse harnesses, don't rebuild (retro §7 point 5 / Action T-series).** The retro's explicit
  direction for Epic 10's measurement/regression stories is to EXTEND the existing harnesses
  (`BossAttemptDiagnostics`, the `tools/dump_*` surveys, the 9.5 batch model, `LocalTimingRecorder`,
  `Epic1MicroCombatScenario`) rather than author parallel ones. 10.1's measurement harness composes the
  existing instrumentation seams above — do not fork a new timing/reporting primitive.
- **Every determinism/save invariant Epic 10 audits is intact and must stay so (retro §7 point 3, §9).**
  7 named RNG streams, ZERO new RNG draw sites, the 23-key `RunSnapshot` gate at 23,
  `ProfileSnapshot`/`SettingsSnapshot` `SCHEMA_VERSION == 1`, every generator/route/finale fingerprint
  byte-identical, the DEFAULT `run_to_completion` byte-identical, the suite at 182 PASS. 10.1 is a
  measurement/doc story — it MUST NOT move any of these. Any measurement instrumentation is read-only
  and build-profile gated; it draws no gameplay RNG and mutates no domain/save state.
- **NO "fail-loud gate/check on a new table → register/extend it" heads-up applies to THIS story.** That
  Epic-transition head-up concerns CODE stories that add events / content families / save keys (the
  `expected_ids` exhaustiveness pins, the schema-key gates). 10.1 adds none of that — no new event, no
  `expected_ids` pin, no schema key, no fingerprint touched. Do NOT go looking for a table to extend or
  a fail-loud gate to register. (Recorded so the dev agent doesn't hunt for one, per the same discipline
  11.1 used.)
- **Status-hygiene finalize step is orchestrator-owned, not 10.1's (retro §7 point 6 / Action P1/P2).**
  The retro's "before the first story of Epic 10" prep includes reconciling 11-6 → `done` + `epic-11:
  done` and keeping the atomic finalize step live so Epic-10 capstones don't lag. That is the
  orchestrator's git/finalize scope, NOT a 10.1 deliverable (the delegate never runs git). On disk at
  authoring time `sprint-status.yaml` already shows `epic-11: done` / all 11-x `done` /
  `epic-11-retrospective: done`, so the P1 reconciliation is already landed — noted so it is not
  re-opened here. 10.1's own finalize follows the same atomic pattern (story `Status:` + the
  `sprint-status.yaml` entry + any doc commit as one unit with the merge).
- **The "playable" framing + the deferred tap-loop (retro §7 point 1, §10) is 10.4/10.6/Epic-12
  territory, NOT 10.1's.** 10.1 measures performance/memory/battery on a representative run driven by the
  existing hands-off live driver (auto-resolve stand-in) — it does NOT need the interactive tap-loop or a
  universally-winning hero path (those gate 10.4's hands-on sessions + 10.6's "die or win" loop gate via
  Epic 12, per the 2026-07-07 sprint change). The auto-resolve representative run is a fully adequate
  measurement subject for tiers/budgets. Recorded so 10.1 is not blocked on an Epic-12 prerequisite it
  does not have.

### Deferred-work overlaps (folded in — only entries touching THIS story's surface)

From `_bmad-output/implementation-artifacts/deferred-work.md` (a project-wide ledger; most entries are
out of scope). Checked every open entry against 10.1's device-tier / performance-budget / instrumentation
surface:

- **NONE of the open deferred-work entries overlap this story's subject.** The open ledger items are all
  live-layer / content / save-shape / affinity work: the Necromancer/Shadeblade class-kit + its two
  profile-aware follow-ons (`hero_select_presenter` profile-awareness, `re_derive_kit`); the live
  discovery/echo/Seal-Fragment source; the in-node board / pending-fight save + Cursed rule-source
  re-derive-on-resume; the run-level event store + `outcome_or_cause`; the Flooded `_placeholder` electric
  interaction (an Epic-10 readiness item, but owned by **10.7**'s asset/UX gate, not 10.1); the
  affinity-driven generation modifier; the G4 settings view model; `OutpostRenderView` render-path
  efficiency; the `warding_salve` reward-table decision (owned by **10.4**). None concerns device tiers,
  performance/memory/battery budgets, or measurement instrumentation.
- **Do NOT reopen or pre-empt any of them.** In particular, the Flooded `_placeholder` (D2) and the
  `warding_salve` table (D1) are Epic-10 readiness items but belong to 10.7 and 10.4 respectively — 10.1
  neither touches nor resolves them. Recorded here only to state the non-overlap explicitly (the same
  "identify only the overlapping deferrals" discipline the create-story mandate requires).

### Numbering caveat (avoid the wrong NFR)

- The implementation-readiness report (`implementation-readiness-report-2026-06-04.md` line 357) prints
  "NFR20: MVP must be offline-first" — that is the design-time GDD NFR numbering. The **canonical
  implementation NFR20** (`epics.md` line 204) is: "Target device tiers, measurement methods, memory
  budget, and battery/performance expectations must be defined before production readiness." THIS story
  discharges the canonical implementation NFR20 (device tiers/measurement), NOT the offline-first GDD
  item. Cite the canonical `epics.md` numbering in the doc.

### Project Structure Notes

- **Primary output location:** `_bmad-output/planning-artifacts/device-tiers-and-performance-budgets.md`
  (a planning artifact, NOT under `godot/`). A readiness/measurement design document; keep it authoritative
  but lightweight (tier table + measurement method + budget table + representative-run protocol + gap
  ledger). Recommended filename is discoverable; if the readiness/create-story globs need a specific
  substring, keep a `readiness`/`perf`/`device` token in the name.
- **Optional harness location (only what is genuinely reusable):** a headless report driver under
  `godot/tools/` (the `dump_*` `SceneTree` precedent) and/or a diagnostics `RefCounted` under
  `godot/scripts/diagnostics/` (the `LocalTimingRecorder` neighbor). Any test goes under
  `godot/tests/unit/diagnostics/` or `godot/tests/unit/tools/` as a `test_*.gd` the headless runner
  auto-discovers. Do NOT add a shipped scene, a new autoload, or an always-on instrumentation node.
- **Do NOT touch:** any gameplay command / event / RNG stream / `RunSnapshot`/`ProfileSnapshot`/
  `SettingsSnapshot` schema / save key / generator or route or finale fingerprint / view model / content
  definition; `prototype/` (frozen validation evidence); `_bmad/` (installer-managed); the existing
  domain/save/RNG source (the harness READS these; it does not change them).
- **Naming/organization:** follow the project-context Code Organization rules — `diagnostics` and `tools`
  are the correct homes for build-profile-gated measurement code; `snake_case` files, `PascalCase`
  classes, `UPPER_SNAKE_CASE` constants.

### Project Context Rules

Extracted from `project-context.md` (the canonical rulebook — refreshed after Epic 11). The rules that
bear on THIS story:

- **Performance targets are project-context law (§ Performance Rules).** Generated level load < 3 s; UI
  preview + selection response < 100 ms; stable 60 FPS where feasible, 30 FPS acceptable lower-end;
  phone-sized readability is first-order (not polish). Explicit rule: "Define and measure low/mid/high
  mobile device tiers before production planning." — this story IS that measurement/definition step.
- **Debug/cheat tools disabled or inert in production (§ Platform & Build Rules).** "Debug/cheat tools
  must be disabled or inert in production builds." "Use build-profile flags plus pre-export validation and
  manual release checklist." The AC5 gating + pre-export check rests on this. `OS.is_debug_build()` is the
  established gate (`LocalTimingRecorder`).
- **No cloud/telemetry/live-service dependency (NFR11; § Platform & Build Rules).** "Platform services stay
  local/no-op for MVP behind interfaces such as `TelemetrySink`, `SaveSyncProvider`, `AchievementProvider`,
  and `CrashReporter`." `PlatformServices` stays inert — measurement must not introduce a runtime
  telemetry/cloud call. Local report files + build-profile-gated in-process instrumentation only.
- **Diagnostics stay scene-free + read-only (§ Code Organization Rules).** "Keep `scripts/...diagnostics/`
  independent of scene nodes for authoritative/data logic (they are `RefCounted` services + DTOs, not
  Nodes)." A measurement `RefCounted` reads timings/memory proxies; it owns no gameplay state and mutates
  nothing.
- **Actionable, compact diagnostics — never a raw dump (§ generator-validation discipline).** Generator
  validation "must report seed, phase, reason, and compact diagnostics (counts/coords/ratios) — NEVER a
  full … dump." Apply the same to the performance report: system + seed/label + measured value + budget +
  delta, actionable, compact.
- **Determinism / save invariants are NOT touched by a measurement/doc story** — but the doc should note
  them as constraints the measurement instrumentation respects: interrupted==uninterrupted / NFR13; the
  23-key `RunSnapshot` gate; `ProfileSnapshot`/`SettingsSnapshot` `SCHEMA_VERSION == 1`; the 7 named RNG
  streams; every pinned fingerprint. The representative-run measurement uses the OPT-IN live driver and
  leaves the DEFAULT deterministic path byte-identical.
- **Godot / testing (§ Testing Rules).** The headless runner auto-discovers `test_*.gd` under
  `res://tests/unit` and `res://tests/integration` only, exits with the failure count. Run the full suite
  via PowerShell (the `godot` binary is NOT on the Bash/`where` PATH — it resolves via
  `C:\Users\Rasmus\bin\godot.cmd` / the console binary): `godot --headless --path C:\Sealsworn\godot
  --scene res://tests/headless/test_runner.tscn --quit-after 10`. Apply the false-PASS grep guard: grep
  the raw runner output; the six documented stderr negatives (int64-overflow ×2, malformed-JSON ×3,
  `invalid_node_type` ×1) still PASS and must not be mis-cited as a regression. This story must not change
  the suite outcome (182 PASS / 0 `^FAIL`) beyond adding its own passing measurement test, if any.

### References

- **Story source (verbatim ACs):** `_bmad-output/planning-artifacts/epics.md` — Epic 10 §"Story 10.1:
  Device Tiers and Performance Budgets" (lines ~2369–2400). Epic 10 section header + sequencing notes:
  lines ~2361–2367. Epic 10 List entry + implementation notes: lines ~485–491.
- **Canonical NFRs (`epics.md` NFR inventory):** NFR4 (line 172 — level load < 3 s), NFR5 (174 — preview/
  selection < 100 ms), NFR6 (176 — 60/30 FPS), NFR7 (178 — phone readability), NFR11 (186 — no accounts/
  cloud/live-service), NFR19 (202 — debug/cheat inert in production), **NFR20 (204 — device tiers,
  measurement methods, memory budget, battery/performance expectations before production readiness — the
  gap THIS story discharges)**. NFR1 (166 — Godot 4.6.3 GDScript), NFR3 (170 — iOS/Android-first + Windows
  parity).
- **Readiness report (the NFR20 gap + the Epic-10 readiness-threshold mandate this story closes):**
  `_bmad-output/planning-artifacts/implementation-readiness-report-2026-06-04.md` lines 436, 444, 742,
  832 ("define measurement method, target device tiers, seed sample sizes, failure thresholds …"), 920,
  934, 944 ("Define Epic 10 readiness thresholds: device tiers, performance measurement methods, memory/
  battery expectations …"), 997. Numbering caveat: line 357's "NFR20" is the design-time GDD item
  (offline-first), NOT the canonical device-tiers NFR20 — cite `epics.md`.
- **Existing instrumentation to reuse (READ before authoring the harness):**
  `godot/scripts/diagnostics/local_timing_recorder.gd` (build-profile-gated timing primitive),
  `godot/scripts/tactical/scenarios/epic_1_micro_combat_scenario.gd` (`enable_timing` representative
  combat driver → `timing_records`), `godot/tools/dump_run_pacing_survey.gd` +
  `godot/tools/dump_seed_batch_report.gd` (the headless `SceneTree` report-driver precedent),
  `godot/scripts/run/run_orchestrator.gd` (`run_to_completion_live`/`auto_play_full_run`, seed 4242 —
  the representative run), `godot/scripts/platform/platform_services.gd` (local-no-op telemetry posture),
  `godot/scripts/diagnostics/boss_attempt_diagnostics.gd` + `godot/tests/unit/diagnostics/
  test_boss_attempt_diagnostics.gd` (the diagnostics-recorder + its unit-test precedent),
  `godot/export_presets.cfg` (Windows + Android preset scaffolding).
- **GDD design grounding:** `_bmad-output/planning-artifacts/gdds/gdd-Game-2026-05-31/gdd.md` — Platform-
  Specific Details + accessibility/performance baseline (558–583). `_bmad-output/game-architecture.md`
  (the full architecture; UI observes view models, scenes own no tactical truth; headless simulation is
  render/audio/scene-free).
- **Epic-11 retro (forward prep for Epic 10 — the epic-transition heads-ups):**
  `_bmad-output/implementation-artifacts/epic-11-retro-2026-07-06.md` §7 (Next-Epic Preview — Epic 10:
  reuse harnesses; invariants intact; the deferred tap-loop is 10.4/10.6/Epic-12, not 10.1), §8 (Action
  items — P1/P2 status hygiene are orchestrator-owned; T-series reuse existing harnesses), §9 (Readiness
  — 182 PASS, every invariant held), §10 (planning drift — the tap-loop sequencing, none of which blocks
  10.1).
- **Deferred-work ledger (checked for overlap — NONE overlaps this story's surface):**
  `_bmad-output/implementation-artifacts/deferred-work.md` (all open items are live-layer/content/save-
  shape/affinity; the Flooded `_placeholder` D2 → 10.7, the `warding_salve` table D1 → 10.4 — 10.1
  touches neither).
- **Prior-story format precedent (the readiness/docs-story analog):**
  `_bmad-output/implementation-artifacts/11-1-run-flow-ux-appendix-and-screen-contracts.md` (the
  docs-plus-gaps discipline: define what you can, record honest gaps against owners, touch no simulation).

## Dev Agent Record

### Agent Model Used

{{agent_model_name_version}}

### Debug Log References

### Completion Notes List

### File List
