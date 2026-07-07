# Device Tiers and Performance Budgets — MVP Readiness Plan

> **Story:** 10.1 (Device Tiers and Performance Budgets) · **Epic:** 10 (Playtest Tuning and MVP Readiness)
> **Type:** Readiness-planning / measurement-definition artifact (the performance analog of the 11.1 UX
> appendix — define what can be measured, record honest availability gaps for the rest, touch no simulation).
> **Status:** authored 2026-07-07 · discharges the canonical **NFR20** production-readiness gap.

## 1. Purpose and Scope

This document discharges the canonical implementation **NFR20** (`epics.md` line 204: *"Target device tiers,
measurement methods, memory budget, and battery/performance expectations must be defined before production
readiness"*) — the first Epic-10 production-readiness item the implementation-readiness report (2026-06-04)
repeatedly flagged as a MANDATORY gate (lines 436, 444, 742, 832, 920, 934, 944, 997).

> **Numbering caveat.** The readiness report's line 357 prints "NFR20: MVP must be offline-first" — that is
> the design-time GDD NFR numbering, NOT this item. This document discharges the **canonical `epics.md`
> NFR20** (device tiers / measurement / memory / battery), and cites the `epics.md` numbering throughout.

**In scope (what this artifact delivers):**

1. The three mobile device tiers (low / mid / high) + Windows-desktop parity, each with a measurement
   method, memory expectation, battery/performance note, and a named measurement source (AC1, AC2).
2. The four MVP performance budgets stated verbatim to the project-context Performance rules, each mapped to
   the system that produces it, plus the build-profile-gated headless/desktop measurement harness that
   measures every budget a headless/desktop environment can genuinely measure and emits an actionable
   diagnostic on a miss (AC3).
3. The 20-minute representative-run protocol + the per-tier peak-memory budget + the thermal/input-
   degradation proxy + the battery target, with the physical-device numbers recorded as explicit
   availability gaps (AC4).
4. The build-profile gating mechanism + the no-production-cheat-tools guarantee + the pre-export validation
   checklist item (AC5).
5. A consolidated "Measurement Availability Gaps" ledger (each gap → owning follow-up) and the Epic-10 gate
   handoff (10.2 / 10.6 / 10.7) — Section 6 and Section 7.

**Out of scope (explicitly NOT this story):** any change to a gameplay command, event, RNG stream,
`RunSnapshot` / `ProfileSnapshot` / `SettingsSnapshot` schema, save key, generator / route / finale
fingerprint, view model, or content definition. The full headless suite stays green and behaviorally
byte-identical; this story adds a read-only measurement/reporting harness + this planning doc.

**Grounding.** Read alongside the project-context **§ Performance Rules** and **§ Platform & Build Rules**
(root `project-context.md`) and the full architecture (`_bmad-output/game-architecture.md` — UI observes
view models; headless simulation is render/audio/scene-free). The measurement harness lives at
`godot/scripts/diagnostics/performance_budget_report.gd` (the budget-comparison seam),
`godot/tools/dump_performance_budgets.gd` (the headless report driver), and
`godot/tests/unit/diagnostics/test_performance_budget_report.gd` (the harness-contract test).

**Platform posture.** Production is Godot 4.6.3 stable standard GDScript, **Mobile renderer**, iOS/Android-
first with Windows desktop/laptop parity (NFR1 / NFR3). `godot/export_presets.cfg` already carries three
presets: **Windows Desktop MVP** (`preset.0`), **Android MVP** (`preset.1`), and an **iOS MVP** scaffold
(`preset.2`, `runnable=false`, empty signing identity + icons — iOS packaging remains deferred until
macOS/Xcode access per the project-context Platform rule; recorded as a tier-source gap in Section 6, not a
blocker). The MVP is offline-first single-player: no accounts, cloud, telemetry, or live-service dependency
(NFR11).

## 2. Device Tiers (AC1, AC2)

Four target profiles. Each row states the tier's device class, the **RAM band verbatim to the AC wording**,
the measurement method, the memory expectation, the battery/performance note, and the **named measurement
source** (a concrete physical device / a named emulator/simulator / an explicit `availability gap` with its
owning follow-up). No device number below is fabricated: where no hardware is provisioned, the source is an
explicit availability gap (AC2 permits this; AC4 conditions battery on "when measurement is available").

### 2.1 Low tier — budget Android-class phone/tablet (~4 GB RAM)

- **Device class / RAM band (AC2):** a **budget Android-class phone or tablet with roughly 4 GB RAM** (e.g.
  an entry Snapdragon 4-series / low-end MediaTek Helio class device on Android 11–13). This is the floor the
  MVP must remain responsive on.
- **Measurement method:** the headless/desktop harness (Section 3) measures the budgets it can (level load,
  representative combat-step compute) as a lower bound; an on-device pass runs the Android debug export from
  `preset.1` and captures the Godot debug monitors (`Performance.get_monitor(TIME_FPS / MEMORY_STATIC /
  RENDER_TOTAL_...)`) plus the OS memory-warning / thermal-state signals during the representative run
  (Section 4).
- **Memory expectation:** **peak-memory budget ≤ 1.5 GB resident** on a ~4 GB device (leaves comfortable
  headroom below the point where Android starts killing background apps / issuing memory warnings). The MVP
  is a single-hero tactical roguelite with a Mobile-renderer 2D board — the static-memory proxy the harness
  reports on desktop is a small fraction of this; the on-device resident figure is the number to confirm.
- **Battery/performance note:** target **stable 30 FPS** (the acceptable lower-end target, NFR6) with
  responsive input; frame stability > peak FPS on this tier. Battery target ≤ 15% over 30 minutes (Section 4)
  — a turn-based game with no continuous physics/AI churn should sit well inside this.
- **Named measurement source:** **`availability gap` → physical-device measurement pass.** No physical
  low-tier Android device or emulator is provisioned in the current (headless CI) environment. Owning
  follow-up: a physical-device pass on a ~4 GB Android device before the 10.6 MVP-readiness gate closes.

### 2.2 Mid tier — current-minus-two-years Android/iOS-class device (~6 GB RAM)

- **Device class / RAM band (AC2):** a **current-minus-two-years Android or iOS-class device with roughly
  6 GB RAM** (e.g. a 2023-era mid-range Android or an iPhone 12/13-class device). The representative "typical
  player" profile.
- **Measurement method:** as low tier; the on-device pass runs the Android `preset.1` export (and, once
  macOS/Xcode access lands, the iOS `preset.2` export) and samples the same Godot monitors + OS signals.
- **Memory expectation:** **peak-memory budget ≤ 2 GB resident** on a ~6 GB device.
- **Battery/performance note:** target **stable 60 FPS where feasible**, gracefully degrading to 30 FPS
  under load with input still responsive (NFR6). Battery target ≤ 15% over 30 minutes.
- **Named measurement source:** **`availability gap` → physical-device measurement pass** (Android now;
  iOS after the macOS/Xcode gap in Section 6 is discharged). No mid-tier device/simulator provisioned here.

### 2.3 High tier — current flagship phone/tablet

- **Device class / RAM band (AC2):** a **current flagship phone or tablet** (e.g. a current Snapdragon
  8-series Android flagship or a current-generation iPhone/iPad). The headroom target — the tier where the
  MVP should hit every budget with margin.
- **Measurement method:** as above; the on-device pass confirms the budgets are met with headroom (the
  flagship is expected to pass trivially; its value is confirming no pathological regression on strong
  hardware and establishing the upper reference).
- **Memory expectation:** **peak-memory budget ≤ 2.5 GB resident** (generous; a flagship has ≥ 8 GB, so
  this is a comfort ceiling, not a constraint).
- **Battery/performance note:** target **stable 60 FPS** with headroom; input latency indistinguishable from
  instant. Battery target ≤ 15% over 30 minutes (expected well inside).
- **Named measurement source:** **`availability gap` → physical-device measurement pass.** No flagship
  device provisioned here.

### 2.4 Windows desktop parity — integrated-GPU laptop/desktop

- **Device class (AC2):** an **integrated-GPU laptop or desktop** (e.g. an Intel Iris Xe / AMD Radeon
  integrated-graphics laptop) — the parity floor that proves the MVP is not secretly depending on a
  discrete GPU. Windows desktop/laptop parity is a first-class MVP target (NFR3).
- **Measurement method:** **directly measurable in this environment.** The headless harness (Section 3) runs
  on the desktop and measures level load + representative combat-step compute against their budgets right
  now; a windowed desktop run of `preset.0` additionally exercises the live scene frame loop (`Performance.
  get_monitor(TIME_FPS)`) for the on-screen frame-stability budget on desktop hardware.
- **Memory expectation:** **peak-memory budget ≤ 2 GB resident** on a typical 8–16 GB laptop. The
  harness's desktop static-memory proxy (`OS.get_static_memory_usage()`) is the headless lower bound; a
  windowed run confirms the resident figure with the renderer active.
- **Battery/performance note:** target **stable 60 FPS** on integrated graphics; on a laptop on battery,
  the same ≤ 15% / 30 min planning target applies as a desktop-parity check.
- **Named measurement source:** **this development/CI desktop (Windows 11)** for the headless-measurable
  budgets — measured, not a gap (see Section 3.3 for the actual numbers). The windowed frame-stability
  sample on integrated GPU is a small `availability gap → windowed desktop measurement pass` (the headless
  runner has no render frame loop).

## 3. Performance Budgets and the Measurement Harness (AC3)

### 3.1 The four budgets (verbatim to project-context § Performance Rules + epics.md NFRs)

| # | Budget (verbatim) | NFR | System that produces it | Headless/desktop-measurable? |
|---|---|---|---|---|
| 1 | **Generated level load < 3 s** | NFR4 | `LevelGenerator.generate(...)` — the bounded-retry pipeline (worst case ≤ `MAX_GENERATION_ATTEMPTS` = 8, kept inside the < 3 s budget by design). | **Yes** — wall-clock over a seed sample. |
| 2 | **UI preview response < 100 ms** | NFR5 | The tactical preview view-models + command bridge (`TacticalMovementPreview` / `TacticalAttackPreview` via `TacticalCommandBridge`) — pure reads, no RNG. | **Domain compute: yes** (the representative combat-step LoS/command timings are the proxy). **On-device render-to-glass latency: gap.** |
| 3 | **Selection response < 100 ms** | NFR5 | Same surface (selection / inspect intent). | **Domain compute: yes.** **On-device touch-to-feedback latency: gap.** |
| 4 | **Stable 60 FPS where feasible / 30 FPS acceptable lower-end** | NFR6 | The live scene under `gameplay_shell.tscn` (Epic 11). | **No (headless)** — sustained frame stability is an on-device / windowed render-profiler concern; a headless run has no render frame loop. **Gap** (Section 6). |

The budgets are encoded once, as constants, in `PerformanceBudgetReport`
(`godot/scripts/diagnostics/performance_budget_report.gd`): `BUDGET_LEVEL_LOAD_MS = 3000`,
`BUDGET_PREVIEW_RESPONSE_MS = 100`, `BUDGET_SELECTION_RESPONSE_MS = 100`, `BUDGET_FRAME_60FPS_MS =
1000/60 ≈ 16.67`, `BUDGET_FRAME_30FPS_MS = 1000/30 ≈ 33.33`. The pass/fail comparison is an **inclusive
ceiling** — a measured value ≤ budget passes; a value strictly over fails.

### 3.2 The harness (reuses the existing instrumentation seams — no parallel primitive)

Per the Epic-11 retro's explicit direction (§7 "reuse harnesses, don't rebuild") and the project-context
diagnostics rules, the harness **composes** the existing build-profile-gated instrumentation rather than
forking a new timing primitive:

- **`PerformanceBudgetReport`** (`scripts/diagnostics/performance_budget_report.gd`) — a build-profile-gated
  `RefCounted` (the `LocalTimingRecorder` / `BossAttemptDiagnostics` sibling; `enabled = new_enabled and
  OS.is_debug_build()`, INERT in a release build). `record_measurement(system, subject, measured_ms,
  budget_ms)` computes `delta_ms` (= measured − budget; negative = headroom) + a pass/fail verdict and
  appends a shape-pinned record (the `RECORD_KEYS` set). `format_diagnostic(record)` emits the **actionable,
  compact** diagnostic — `[PASS|FAIL] system / subject: measured=… budget=… delta=…` — **never a bare
  "slow"** (the project-context generator-diagnostics discipline: system + subject + measured value + budget
  + delta). `has_failures()` / `failure_diagnostics()` surface every miss for a non-zero CI exit. It draws
  ZERO RNG, mutates nothing, adds no save key, and is a pure in-memory observer (no telemetry/network/file).
- **`LocalTimingRecorder`** (`scripts/diagnostics/local_timing_recorder.gd`) — the canonical build-profile-
  gated timing primitive (`begin`/`end`/`records`, `{label, elapsed_usec}`) the representative combat run
  already uses. **Reused, not reinvented.**
- **`Epic1MicroCombatScenario`** (`scripts/tactical/scenarios/epic_1_micro_combat_scenario.gd`) — drives a
  scripted win path with `enable_timing=true`, wrapping `board_query` / `line_of_sight_update` /
  `command_execution` / `enemy_turn_resolution` / `outcome_evaluation` in the recorder and returning
  `timing_records`. The `line_of_sight_update` and `command_execution` labels are the domain-compute proxy
  for the NFR5 preview/selection response.
- **`dump_performance_budgets.gd`** (`godot/tools/`) — the headless report driver (the `dump_*` `SceneTree`
  precedent). It measures `LevelGenerator.generate` wall-clock over the seed sample `[1001, 2002, 3003,
  4004, 5005]` × {`small_combat_basic`, `medium_combat_basic`} and the representative combat-step timings,
  feeds them to `PerformanceBudgetReport`, prints the full report, and exits non-zero on any miss. It is a
  dev/CI driver — NOT auto-discovered by the headless runner, NOT wired into any shipped scene or autoload,
  and excluded from every export preset (Section 5).

Run the report driver:
```
godot --headless --path C:\Sealsworn\godot --script res://tools/dump_performance_budgets.gd
```
(On this machine `godot` resolves via `C:\Users\Rasmus\bin\godot.cmd` through PowerShell.)

### 3.3 Measured results (headless/desktop, 2026-07-07 — real numbers, not fabricated)

Running the driver on the development desktop (Windows 11, this environment) produced **12 measurements, all
PASS**:

- **Level load (NFR4, budget 3000 ms):** `small_combat_basic` seeds measured **~4.3–7.0 ms**;
  `medium_combat_basic` seeds measured **~9.9–11.4 ms** — every seed under budget by **> 2985 ms of
  headroom** (three orders of magnitude inside the budget). All succeeded on attempt 1 (no retry pressure).
- **Representative combat-step domain compute (NFR5 proxy, budget 100 ms):** worst `line_of_sight_update`
  **~0.52 ms**, worst `command_execution` **~1.94 ms** — both **> 98 ms under budget**.

These desktop numbers are the **Windows-desktop-parity headless-measurable budgets, MET with enormous
margin**, and a strong lower bound for the mobile tiers (mobile CPUs are slower, but the absolute compute is
so far inside budget that even a 100× slowdown on the weakest tier stays inside NFR4/NFR5 for the domain
compute). They do NOT substitute for the on-device render/frame/latency numbers (Section 6 gaps).

## 4. Representative Run + Memory / Battery / Thermal Protocol (AC4)

### 4.1 The 20-minute representative run

The representative run under measurement is the **existing hands-off live driver** Epic 11 shipped — do NOT
build a new gameplay loop:

- **Headless / scripted-simulation stand-in:** `RunOrchestrator.auto_play_full_run(...)` (opt-in) drives a
  full run to a run-end (the default combat auto-resolved, then the boss fight auto-played to victory) on the
  **verified finale seed 4242**; `run_to_completion_live(...)` drives the live per-node flow. These are the
  closest existing "representative run" for measurement. The DEFAULT `run_to_completion` stays byte-identical
  — the measurement uses the OPT-IN live/auto-play driver and leaves the deterministic default path untouched.
  For a sustained 20-minute sample the scripted simulation is looped (repeated seeded runs) to hold the
  process under continuous load for the sampling window.
- **On-device pass:** the same flow runs on hardware from the platform export (`preset.1` Android; `preset.0`
  Windows desktop; `preset.2` iOS once available), driven hands-off, for a continuous 20-minute window.

> **Why auto-resolve is an adequate measurement subject (retro §7 point 1 / §10):** the interactive tap-loop
> and a universally-winning hero path are **Epic-12 / 10.4 / 10.6** territory (per the 2026-07-07 sprint
> change), NOT a 10.1 prerequisite. Performance/memory/battery on a representative run are fully measurable
> against the hands-off live driver; 10.1 is not blocked on the interactive loop.

### 4.2 Sampled signals + budgets + pass criteria

During the representative run, sample:

- **Peak memory.** Instrumentation: **`OS.get_static_memory_usage()`** (headless/desktop static proxy) +
  **`Performance.get_monitor(Performance.MEMORY_STATIC)`** and, on device, the OS resident-memory reading.
  All are read-only, build-profile-gated dev instrumentation. **Per-tier peak-memory budget:** low ≤ 1.5 GB,
  mid ≤ 2 GB, high ≤ 2.5 GB, desktop ≤ 2 GB resident (Section 2). **Pass criterion (verbatim AC4):** the
  build must **avoid OS memory warnings or termination** and **stay below the recorded per-tier peak-memory
  budget**.
- **Thermal / sustained-input-degradation proxy.** Instrumentation: on device, the OS thermal-state API
  (Android `PowerManager` thermal status / iOS `ProcessInfo.thermalState`) sampled across the window, plus a
  frame-time-drift check (a rising `Performance.get_monitor(TIME_FPS)` degradation over the 20 minutes is the
  throttling proxy). **Pass criterion (verbatim AC4):** **avoid sustained thermal throttling or input
  degradation** over the run.
- **Battery drain.** Instrumentation: read battery percentage at run start and at 30 minutes on a physical
  device. **Target (verbatim AC4):** **no more than 15% over 30 minutes** on a comparable physical mobile
  device — **recorded when measurement is available.**

### 4.3 Physical-device measurements are availability gaps (not fabricated)

No physical low/mid/high phone, no simulator/emulator, and no physical mobile battery is provisioned in this
environment. Therefore the **peak-memory-on-device, thermal-state, and battery-drain numbers are recorded as
explicit `availability gap → physical-device measurement pass` notes** (Section 6). The protocol above is the
exact method a later physical-device pass follows, so each gap is dischargeable without re-designing the
method. **No device number is invented** — the headless/desktop harness reports only what it can genuinely
measure (Section 3.3), and everything else is an owned gap.

## 5. Build-Profile Gating and No-Production-Cheat-Tools Guarantee (AC5)

### 5.1 Gating mechanism

All measurement instrumentation gates on the build profile via **`OS.is_debug_build()`** — the established
`LocalTimingRecorder._init` precedent (`enabled = new_enabled and OS.is_debug_build()`), reused verbatim by
`PerformanceBudgetReport` and `BossAttemptDiagnostics`. In a non-debug / release export the report is INERT:
`enabled` is forced false, every `record_measurement` is a no-op, and `records()` stays empty. The unit test
`test_performance_budget_report.gd` proves the gate (a disabled report captures nothing even in the debug
headless build).

The `tools/dump_performance_budgets.gd` report driver is a **dev/CI `SceneTree` script**, not wired into any
shipped scene or autoload — it is invoked manually via `--script`. It additionally refuses to run in a
non-debug build (it checks `report.enabled` and exits early), so it is a no-op even if somehow invoked
against a release build.

### 5.2 The harness cannot ship (export-filter evidence)

`godot/export_presets.cfg` — **all three presets** (Windows `preset.0`, Android `preset.1`, iOS `preset.2`)
— carry the identical `exclude_filter`:
```
exclude_filter="addons/**,data/source/**,scenes/debug/**,tests/**,tools/**,**/*_test.gd,**/test_*.gd"
```
So the report driver (`tools/**`) and the harness test (`**/test_*.gd`) are **provably excluded from every
production export**. Only `PerformanceBudgetReport` itself (under `scripts/diagnostics/`) is included in the
export — and it is build-profile-gated INERT in release, invoked by nothing shipped.

### 5.3 No production cheat/debug tools

- **`PlatformServices`** (`scripts/platform/platform_services.gd`) stays a **local no-op**:
  `record_telemetry` / `unlock_achievement` / `sync_save` are inert (NFR11 / NFR19 — no telemetry sink, no
  cloud call, no live-service dependency). The measurement harness introduces **no** runtime telemetry,
  cloud call, or always-on overlay.
- **No debug overlay, seed/fog/LoS viewer, or cheat path is registered in a production build.** The only
  measurement surfaces are the build-profile-gated in-process recorders + the `tools/` report driver
  (excluded from export).

### 5.4 Pre-export validation checklist item (project-context Platform rule)

Per the project-context Platform rule *"build-profile flags plus pre-export validation and manual release
checklist"*, the pre-release-export checklist must include:

- [ ] Confirm `export_presets.cfg` `exclude_filter` still excludes `tools/**`, `tests/**`, and
      `**/test_*.gd` on every shipped preset (the harness + tests cannot ship).
- [ ] Confirm the release build is a **non-debug** build so every `OS.is_debug_build()`-gated recorder
      (`LocalTimingRecorder`, `BossAttemptDiagnostics`, `PerformanceBudgetReport`) is INERT.
- [ ] Confirm `PlatformServices` is still the local no-op (no telemetry/cloud sink wired).
- [ ] Confirm no debug overlay / seed / fog / LoS viewer / cheat path is registered in the shipped scene tree.

## 6. Measurement Availability Gaps (each gap → owning follow-up)

The honest-scope deliverable (mirroring 11.1's contract-gap ledger). Each gap names the gap, the tier/budget
it affects, and the owning follow-up. The **10.6 MVP-readiness gate** decides whether a still-open gap is an
acceptable documented readiness limitation or a hard blocker to discharge before MVP-readiness passes — 10.1's
job is to make each gap explicit and dischargeable, not to close all of them.

| # | Gap | Tier / budget affected | Owning follow-up |
|---|---|---|---|
| G1 | No physical **low-tier ~4 GB Android** device or emulator provisioned. | Low tier (AC2 source); on-device level-load, FPS, memory, thermal, battery. | A physical-device measurement pass on a ~4 GB Android device before 10.6. |
| G2 | No physical **mid-tier ~6 GB Android/iOS** device provisioned. | Mid tier (AC2 source); on-device budgets. | A physical-device measurement pass on a ~6 GB device before 10.6. |
| G3 | No physical **high-tier flagship** device provisioned. | High tier (AC2 source); on-device budgets. | A physical-device measurement pass on a current flagship before 10.6. |
| G4 | No **on-device / windowed render-frame profiler** run for **sustained 60/30 FPS frame stability** (NFR6). A headless run has no render frame loop. | Budget 4 (frame stability), all tiers + desktop parity. | An on-device pass (Android/iOS export) + a windowed desktop-parity pass (`preset.0`) sampling `Performance.get_monitor(TIME_FPS)` over the representative run. |
| G5 | No **real-touch preview/selection latency** (render-to-glass) measurement — only the domain compute is measured headless. | Budgets 2 & 3 (preview/selection response), mobile tiers. | An on-device pass measuring touch-to-feedback latency on hardware. |
| G6 | No **physical mobile battery / thermal** measurement (no device / battery provisioned). | AC4 battery (≤ 15% / 30 min) + thermal-throttling proxy, mobile tiers. | The physical-device 30-minute representative-run pass (Section 4) reading battery % + OS thermal state. |
| G7 | **iOS packaging deferred** — `preset.2` is a scaffold (`runnable=false`, empty signing identity + icons); iOS exports require macOS + Xcode (project-context Platform rule). | iOS-class mid/high tiers (AC2 source, iOS side). | Complete the iOS export (signing identity, icons, provisioning) once macOS/Xcode access is available, then run the on-device pass. |

## 7. Epic-10 Gate Handoff and Cross-References

This document feeds the sibling Epic-10 readiness stories (their content is NOT implemented here — only the
handoff is recorded):

- **10.2 (Headless Seed Regression Suite).** The level-load measurement draws over the seed sample
  `[1001, 2002, 3003, 4004, 5005]` × {`small_combat_basic`, `medium_combat_basic`}, kept **compatible** with
  the approved Small + Medium seed catalog the seed-batch report / regression suite use, so the two harnesses
  agree on which seeds a level-load number is reported for. **10.2 shipped 2026-07-07** — its consolidated
  regression suite (`godot/tests/integration/test_seed_regression_suite.gd`) + sample-size gap ledger
  (`_bmad-output/planning-artifacts/seed-regression-suite-readiness.md`) holds the generation Small/Medium
  sample at the shared `[1001,2002,3003,4004,5005]` catalog (recorded there as a temporary 5-of-50 gap so a
  coordinated generation-sample expansion extends this level-load harness, the 10.2 regression suite, and the
  10.3 fairness batch together).
- **10.6 (MVP Readiness Gate and Playable-Build Preservation).** Consumes the **tier definitions + the four
  budget thresholds + the measured headless/desktop results (Section 3.3) + the availability-gaps ledger
  (Section 6)**. The gate decides, per gap, "acceptable documented readiness limitation" vs "must discharge
  via a physical-device pass first."
- **10.7 (Asset/Audio-Placeholder and UX-Readiness Gate).** Consumes the **perf/readability posture** (the
  NFR6 frame-stability + NFR7 phone-readability framing). The Flooded `_placeholder` electric-interaction
  deferral (deferred-work D2) is a 10.7 asset/UX item, NOT a 10.1 item.

**Determinism / save invariants respected (retro §7 point 3, §9).** This measurement/doc story moves none of
the pinned invariants: the 7 named RNG streams (`map` / `level` / `combat` / `loot` / `rewards` / `events` /
`cosmetic`), zero new RNG draw sites, the 23-key `RunSnapshot` gate, `ProfileSnapshot` / `SettingsSnapshot`
`SCHEMA_VERSION == 1`, every generator/route/finale fingerprint, and the default `run_to_completion` stay
byte-identical. The harness is read-only, build-profile-gated, draws no gameplay RNG, and mutates no
domain/save state. The full headless suite stays green (adding only this story's passing harness-contract
test).

## 8. Change Log

| Date | Version | Change | Author |
|---|---|---|---|
| 2026-07-07 | 1.0 | Initial authoring — device tiers (low/mid/high + Windows parity), four MVP performance budgets, headless/desktop measurement harness + measured results, 20-minute representative-run + memory/battery/thermal protocol, build-profile gating + no-cheat-tools guarantee, availability-gaps ledger, Epic-10 gate handoff. Discharges canonical NFR20. | Story 10.1 (dev agent) |
