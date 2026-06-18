# Story 4.1: Run State and Route Node Model

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a player,
I want a run to track route position, current node, and forward progress,
so that individual levels become a coherent descent.

## Acceptance Criteria

Source: `_bmad-output/planning-artifacts/epics.md` → Epic 4 → Story 4.1 (verbatim, with the implementation-grounded detail this story adds).

1. **Run-state initialization (scene-independent).**
   **Given** a new run starts
   **When** run state is initialized
   **Then** it records root seed, manual-seed eligibility, current phase, current node pointer, cleared nodes, and available route choices
   **And** the state exists independently of UI scenes (a plain typed `RefCounted` domain model; no `Node`/`Control`/scene reference).

2. **Route node model.**
   **Given** route nodes are defined
   **When** the route model is loaded
   **Then** each node has id, type, depth, reveal state, outgoing links, and optional clue fields
   **And** node ids are stable for save/resume and test references (a node's id is assigned once and never regenerated; it round-trips through serialization unchanged).

3. **Invalid run-state transition is rejected with no mutation.**
   **Given** run state transitions are requested
   **When** an invalid transition occurs
   **Then** it returns a structured `ActionResult` error (stable lower_snake `error_code` + diagnostic metadata)
   **And** route state remains unchanged (the run-state object and route model are byte-identical before and after the rejected transition — verify with a snapshot/dictionary comparison).

### Acceptance-criteria interpretation notes (read before coding)

- "current phase" = the **`RunState` phase machine** the architecture specifies: `new_run`, `active_route`, `node_resolution`, `completed`, `failed` (architecture State Management §, line 330). Model these as `UPPER_SNAKE_CASE` enum-style `StringName` constants on the run-state class, mirroring `CombatOutcomeState.STATE_*`.
- "current node pointer" = the id of the node currently being resolved (empty/`""` when the run is at a route choice rather than inside a node). Reuse the existing `RunSnapshot.current_route_node_id` field for persistence.
- "cleared nodes" = the set of node ids already completed (for save/resume + no-backtracking later). A stable ordered `Array[String]` of node ids.
- "available route choices" = the ids of the legal next nodes selectable from the current position. This story only **records/derives** them from the route graph; the actual choose-and-commit command is **Story 4.3** (do not build it here).
- "reveal state" per node = one of `hidden` / `revealed` / `cleared` (lower_snake `StringName` constants on the node model). Keep this orthogonal to the run phase.
- **Node ids are caller/fixture-supplied in 4.1, not minted here.** "Stable ids" means a node's id is accepted as-is, validated (non-empty, no whitespace), and preserved verbatim through serialization. Do NOT build a seeded/auto id-generation routine — id minting during route generation is Story 4.2 (and would require the `map` stream, which 4.1 must not touch). Tests construct nodes with explicit literal ids (e.g. `"start"`, `"choice-a"`).
- "optional clue fields" = the tradeoff-hint vocabulary the route choice will surface (e.g. `safer_combat`, `stronger_reward`, `unknown_risk`, `recovery`, `elite_pressure`, `mystery` — drawn from epics Story 4.2 AC4). In 4.1 these are **optional, free-form data fields on the node model** (default empty); 4.2 populates them during generation. Define the field + a couple of canonical clue-tag constants; do not build the clue-generation logic.

## Tasks / Subtasks

- [x] **Task 1 — Create the run domain folder and route node model (AC: #2)**
  - [x] 1.1 Create `godot/scripts/run/` (new domain folder — see Project Structure Notes for the rationale and the project-context update this requires) and `godot/tests/unit/run/`.
  - [x] 1.2 Implement `godot/scripts/run/route_node.gd` (`class_name RouteNode`, `extends RefCounted`): fields `id: String`, `type: StringName`, `depth: int`, `reveal_state: StringName` (default `REVEAL_HIDDEN`), `outgoing_link_ids: Array[String]`, `clues: Array[String]` (optional, default `[]`). Add reveal-state constants `REVEAL_HIDDEN`/`REVEAL_REVEALED`/`REVEAL_CLEARED`.
  - [x] 1.3 Define the MVP node-type constants on `RouteNode` as lower_snake `StringName`s sufficient for this story: `combat`, `elite_combat`, `shop`, `reforge`, `gambling`, `event`, `secret`, `boss` (the epics Story 4.5 MVP node-type set). 4.1 only needs the **vocabulary + validation**; 4.5 owns per-type resolution behavior.
  - [x] 1.4 Add `RouteNode.validate() -> ActionResult`: reject empty/non-lower_snake `type`, unknown `type`, negative `depth`, unknown `reveal_state`, empty/whitespace node `id`, self-referential or duplicate `outgoing_link_ids`. Return a stable lower_snake `error_code` + a `{field: ...}` metadata diagnostic. Mirror the validate-then-reject shape of `LevelRecipeDefinition.validate()` / `CombatOutcomeState.validate()`.
  - [x] 1.5 Add `RouteNode.to_dictionary()` + `static try_from_dictionary(data) -> ActionResult` + `static from_dictionary(data) -> RouteNode` (push_error + null on failure). Match the exact serialization+parse contract style of `CombatOutcomeState` (string-like field guards, `_field`/`_has_field` helpers, `try_*` returns `ActionResult`, `from_*` is the lenient convenience wrapper).
- [x] **Task 2 — Implement the route model / graph container (AC: #2, #3)**
  - [x] 2.1 Implement `godot/scripts/run/route_state.gd` (`class_name RouteState`, `extends RefCounted`): an ordered collection of `RouteNode`s keyed by stable id, plus `current_node_id: String`, `cleared_node_ids: Array[String]`. Provide `node_by_id(id) -> RouteNode`, `available_choice_ids() -> Array[String]` (the outgoing links of the current node that are not already cleared), `has_node(id) -> bool`.
  - [x] 2.2 Add `RouteState.validate() -> ActionResult`: every `outgoing_link_id` must resolve to a known node; `current_node_id` (when non-empty) must be a known node; `cleared_node_ids` must all be known and unique; reject duplicate node ids. Forward-only/no-backtracking edge validation is **Story 4.2** (route generation) — 4.1 validates structural integrity only, not the forward-only graph shape.
  - [x] 2.3 Add `RouteState.to_dictionary()` / `try_from_dictionary` / `from_dictionary` mirroring Task 1.5. Node order MUST be stable (serialize nodes as an ordered `Array[Dictionary]`, not an unordered `Dictionary`, so the round-trip and any future fingerprint are deterministic).
- [x] **Task 3 — Implement the run-state phase machine + transition validation (AC: #1, #3)**
  - [x] 3.1 Implement `godot/scripts/run/run_state.gd` (`class_name RunState`, `extends RefCounted`): fields `phase: StringName` (default `PHASE_NEW_RUN`), `root_seed: int`, `is_manual_seed: bool`, `meta_progression_eligible: bool`, and a `route: RouteState`. Phase constants: `PHASE_NEW_RUN`, `PHASE_ACTIVE_ROUTE`, `PHASE_NODE_RESOLUTION`, `PHASE_COMPLETED`, `PHASE_FAILED` (architecture line 330).
  - [x] 3.2 Implement the transition table as an explicit `can_transition_to(next_phase) -> bool` + `transition_to(next_phase) -> ActionResult` pair (architecture line 1294 pattern: `state.can_transition_to(X)` / `state.transition_to(X)`). Legal edges: `NEW_RUN→ACTIVE_ROUTE`; `ACTIVE_ROUTE→NODE_RESOLUTION`; `NODE_RESOLUTION→ACTIVE_ROUTE` (back to a choice after a node clears) and `NODE_RESOLUTION→COMPLETED`/`→FAILED`; `ACTIVE_ROUTE→FAILED` (abandon/death at a choice); `COMPLETED`/`FAILED` are terminal (no outgoing edges). Any other transition → `ActionResult.error(&"invalid_run_transition", {"from": ..., "to": ...})` and **no field mutation**.
  - [x] 3.3 Add `RunState.is_terminal()` (COMPLETED or FAILED) and `RunState.validate()` (unknown phase → `invalid_run_phase`; delegate route integrity to `RouteState.validate()`). Enforce the manual-seed invariant in `validate()` / at construction: `meta_progression_eligible == not is_manual_seed` (mirror `RunSnapshot.from_between_level`); a manual-seed run is never meta-eligible.
  - [x] 3.4 Add a `RunState.new_run(root_seed, is_manual_seed, route) -> RunState` (or static factory) that produces a fresh run in `PHASE_NEW_RUN` with `meta_progression_eligible = not is_manual_seed`, `current_node_id = ""`, `cleared_node_ids = []`. This is AC1's "new run" entry point. Do NOT draw any RNG here (see Determinism note).
- [x] **Task 4 — Serialization round-trip + RunSnapshot bridge (AC: #1, #2)**
  - [x] 4.1 `RunState.to_dictionary()` / `try_from_dictionary` / `from_dictionary` composing the route + phase + seed/eligibility fields. `root_seed` MUST be string-encoded in the dictionary (`str(root_seed)`) and read back tolerantly (int / integral-float / decimal-string) — copy `RunSnapshot._int64_or_zero` / `RngStreamSet._int64_from_value`. This is the int64/real-JSON rule applied to the run/route snapshot (epic-3 retro Action Item #5).
  - [x] 4.2 Provide the bridge into the existing `RunSnapshot`: a `RunState.to_run_snapshot_fields() -> Dictionary` (or have the persistence side read `RunState`) that populates the ALREADY-EXISTING `RunSnapshot` fields — `root_seed`, `is_manual_seed`, `meta_progression_eligible`, `route_state` (the `RouteState.to_dictionary()` payload), `current_route_node_id`, `revealed_route_node_ids`. Do NOT add a parallel run-save format; `RunSnapshot.route_state` is the home for the route payload (it currently defaults `{}`). See the no-surprise-key gate in Testing.
  - [x] 4.3 If (and only if) you decide a new top-level `RunSnapshot` field is genuinely required for the run phase (e.g. a `run_phase` key rather than nesting phase inside `route_state`), you MUST also extend `_allowed_run_snapshot_keys()` in `godot/tests/unit/save/test_run_snapshot.gd` and bump the no-surprise-key assertion intentionally in the same change. Prefer nesting phase inside the `route_state` payload to avoid touching the pinned top-level key set; if you nest, the existing 23-key gate stays green untouched. Decide explicitly and record the decision in Completion Notes. **DECISION: nested `run_phase` inside the `route_state` payload (see Completion Notes); the 23-key gate stays green untouched.**
- [x] **Task 5 — Domain event for run start (AC: #1) — extend the fail-loud event table**
  - [x] 5.1 `DomainEvent` already reserves `Type.RUN_STARTED` + `EVENT_ID_RUN_STARTED` (`run_started`) in its enum and id maps, but has **no factory, no payload validator, and is not in `_event_requires_actor`**. If this story emits a run-started event (recommended for AC1's "a new run starts"), you MUST extend the event table fail-loud-correctly: add a `DomainEvent.run_started(sequence_id, payload)` factory, add a `_validate_run_started_payload` branch in `_validate_payload_for_event`, and confirm `try_from_dictionary` accepts the new event and a round-trip test passes. `run_started` is a system event (no actor) — leave it OUT of `_event_requires_actor` and assert an empty `actor_id` is accepted.
  - [x] 5.2 Keep the payload minimal and deterministic (e.g. `{root_seed: <string>, is_manual_seed: bool, node_count: int}`); follow the existing payload-validator idioms (`_has_*` helpers, lower_snake string fields). If you judge a domain event unnecessary for 4.1 (the AC says "records … current phase", which the `RunState` object already satisfies), you MAY skip the event — but then do NOT half-wire `RUN_STARTED`; either fully extend the table+tests or leave the reserved enum entry untouched and note the decision. Do not ship a `run_started` enum entry that `try_from_dictionary` would accept with no validator.
- [x] **Task 6 — Tests (AC: #1, #2, #3)** — put all under `godot/tests/unit/run/`, `test_*.gd`, `extends "res://tests/unit/test_case.gd"`.
  - [x] 6.1 `test_route_node.gd`: valid node round-trips; each invalid field (`type`, `depth`, `reveal_state`, empty id, self-link, duplicate links) is rejected with the expected stable code + `field` metadata; unknown node `type` rejected; `from_dictionary` returns null + push_error on failure.
  - [x] 6.2 `test_route_state.gd`: graph integrity validation (dangling link rejected, unknown `current_node_id` rejected, duplicate node id rejected, duplicate/unknown cleared id rejected); `available_choice_ids()` excludes cleared nodes; node order is stable through a real JSON round-trip.
  - [x] 6.3 `test_run_state.gd`: every legal transition succeeds and lands in the right phase; a representative set of illegal transitions each returns `invalid_run_transition` and leaves the `RunState.to_dictionary()` **byte-identical** (capture before/after dicts and `assert_equal`); terminal phases reject all outgoing transitions; the manual-seed invariant holds (`is_manual_seed → not meta_progression_eligible`); `new_run(...)` initializes all AC1 fields and draws no RNG.
  - [x] 6.4 Serialization round-trip MUST use a real `JSON.stringify` → `JSON.parse_string` cycle (not native-dict equality) for `RunState` and `RouteState`, and assert `root_seed` survives a full int64 value (copy the `_root_seed_survives_full_int64_round_trip` pattern from `test_run_snapshot.gd`, e.g. `9223372036854775000`).
  - [x] 6.5 If a `run_started` event is added: `test_domain_event.gd` (or a new `run` test) asserts the factory output round-trips through `to_dictionary` → `try_from_dictionary`, an empty `actor_id` is accepted, and a malformed payload is rejected with `invalid_event_payload`.
  - [x] 6.6 RunSnapshot bridge: extend or add a test asserting `RunState` → `RunSnapshot` fields → `RunSnapshot.parse` round-trips the route payload through `route_state`, and that the no-surprise-key gate (`test_run_snapshot.gd`) still passes (green untouched if you nested phase; intentionally updated if you added a top-level key).
- [x] **Task 7 — Run the full headless suite + diff check (gate before review)**
  - [x] 7.1 Run the full suite via PowerShell (see Testing) and confirm runner exit 0 + "Headless tests passed.".
  - [x] 7.2 Run `git diff --check` (clean) before marking the story for review.

## Dev Notes

### What this story IS (and is NOT)

- **IS:** the scene-independent **run-progression domain model** — a `RunState` phase machine (`new_run → active_route → node_resolution → completed/failed`), a `RouteState` graph container, a `RouteNode` model with stable ids, transition validation that fails structurally with no mutation, and a clean serialization bridge into the existing `RunSnapshot`.
- **IS NOT:** route *generation*. The seeded **8–12 node route generation using the `map` RNG stream + route fingerprints is Story 4.2** under `scripts/generation/route/`. **Do NOT draw any RNG in 4.1** — run-state init and transitions are pure, deterministic functions of their inputs (no `map` draw, no `RngStreamSet` call). The first consumer of the `map` stream is 4.2; 4.1 just defines the structures 4.2 will fill.
- **IS NOT:** route choice/commit (`RouteAdvanceCommand` + route-advanced event + no-backtracking enforcement) — that is **Story 4.3**. 4.1 only *derives/records* `available_choice_ids()`; it does not build the command that commits a choice.
- **IS NOT:** node entry/exit, level-request creation, door-sealed events, or `GenerationResult` consumption — that is **Story 4.4**. 4.1 must not call `LevelGenerator`/`ManualSeedLoader` or read a `GenerationResult`.
- **IS NOT:** MVP node-type resolution behavior or the boss placeholder run-end (**Story 4.5**), nor the start-to-end playable shell + pacing (**Story 4.6**). 4.1 defines the node-type *vocabulary*; 4.5 implements per-type resolution.

Keeping these boundaries tight is the single biggest risk for this story — the epics Story 4.1 AC is deliberately small (a model + a state machine), and the temptation is to pull 4.2/4.3/4.4 work forward. Resist it.

### Architecture patterns and constraints

- **`RunState` is an architecture-specified state machine.** Phases are exactly `new run, active route, node resolution, completed, failed` ([Source: `_bmad-output/game-architecture.md` §State Management, line 330]). Use the explicit `can_transition_to()` / `transition_to()` pattern the architecture prescribes for app/run/level/turn/UI machines ([Source: line 1294]). Avoid "untracked boolean flag piles for major flow" ([Source: line 1300]).
- **Command/result/event discipline.** Gameplay/state actions validate before mutation and return `ActionResult`; successful state changes may emit deterministic past-tense `DomainEvent` records ([Source: `project-context.md` §Determinism & Simulation Rules]). A *rejected* transition returns an `ActionResult` error and emits **zero** events and mutates nothing.
- **Scene-independent domain ownership.** `RunState`/`RouteState`/`RouteNode` are plain typed `RefCounted` DTOs + a state machine, NOT `Node`s. They live under `scripts/run/`, which (like `scripts/tactical`, `scripts/generation`, `scripts/save`) must not depend on scene nodes for authoritative logic ([Source: `project-context.md` §Code Organization Rules; `game-architecture.md` line 975]). `GameSession` (autoload) stays thin and must not own run-phase decisions — it may later hold a reference to the live `RunState`, but the phase logic lives in the domain model.
- **Trigger-window naming.** The architecture's canonical run trigger window is `run_started` ([Source: `game-architecture.md` line 420]) — matching the reserved `DomainEvent.EVENT_ID_RUN_STARTED`. Use that exact id if you emit the event.
- **Save composition, not forking.** Route state, current node, revealed route info, and manual-seed eligibility are already part of the MVP save contract ([Source: `game-architecture.md` lines 361-364]) and already exist as `RunSnapshot` fields (`route_state`, `current_route_node_id`, `revealed_route_node_ids`, `is_manual_seed`, `meta_progression_eligible`). Compose into those — do not invent a parallel run-save format ([Source: `project-context.md` §Save/Snapshot Rules, "Compose, do not fork"]).

### Source tree components to touch

NEW (this story creates them):
- `godot/scripts/run/run_state.gd` — `RunState` phase machine + transition table + validation + serialization.
- `godot/scripts/run/route_state.gd` — `RouteState` graph container + integrity validation + serialization.
- `godot/scripts/run/route_node.gd` — `RouteNode` model + validation + serialization.
- `godot/tests/unit/run/test_run_state.gd`, `test_route_state.gd`, `test_route_node.gd` — and any `run_started` event test.

UPDATE (read before editing — see "Files being modified" below):
- `godot/scripts/core/events/domain_event.gd` — ONLY if you emit `run_started` (add factory + payload validator following the existing idioms).
- `godot/tests/unit/save/test_run_snapshot.gd` — ONLY if you add a new top-level `RunSnapshot` key (extend `_allowed_run_snapshot_keys()` + bump the no-surprise-key assertion). If you nest phase inside `route_state`, leave this file untouched and confirm it stays green.
- `godot/scripts/save/snapshots/run_snapshot.gd` — likely UNCHANGED (the fields you need already exist); touch only if you add a top-level field, and then keep the lenient run-level `parse()` lenient (do NOT add strict route validation into `RunSnapshot.parse` — strict route/phase validation belongs in the run-domain `try_from_dictionary` methods).
- `project-context.md` §Code Organization Rules — add `run` to the domain-folder list (see Project Structure Notes). This is a real, intentional convention change for the new domain; make it as part of this story.

### Files being modified — current state and what to preserve

**`godot/scripts/save/snapshots/run_snapshot.gd` (likely no change, but it is the integration surface):**
- Current state: `RunSnapshot` (schema_version 1) already carries `root_seed` (string-encoded via `str()` / read via `_int64_or_zero`), `is_manual_seed`, `meta_progression_eligible`, `route_state: Dictionary` (defaults `{}`), `current_route_node_id: String`, `revealed_route_node_ids: Array[String]`. `from_between_level(...)` sets `meta_progression_eligible = not is_manual_seed`. `parse()` is the **lenient** run-level parse (only rejects `unsupported_save_schema`); the embedded tactical payload is strictly validated separately via `try_tactical_snapshot()`.
- Preserve: the lenient run-level `parse()` (forward-compat), the int64 string-encoding of `root_seed`, the `from_between_level` composition path, and the absence of the `manual_seed_eligible_for_progression` key.
- This story changes: populates `route_state` with the real `RouteState.to_dictionary()` payload instead of leaving it `{}`. The shape inside `route_state` is owned by `RouteState`'s contract, not by `RunSnapshot.parse`.

**`godot/scripts/core/events/domain_event.gd` (touch only for `run_started`):**
- Current state: `Type.RUN_STARTED` + `EVENT_ID_RUN_STARTED = &"run_started"` exist in the enum and in `id_for_type`/`type_for_id`, so `try_from_dictionary` will currently MAP a `{"event_id":"run_started", ...}` dict to `Type.RUN_STARTED` and fall through `_validate_payload_for_event`'s `_:` arm (returns ok with NO validation) — i.e. an unvalidated event id is already partially live. There is no `run_started` factory.
- What this means for you (epic-3 retro heads-up applied here): the event table is a "fail-loud-on-the-new-table" surface. If you use `run_started`, finish wiring it: add the factory, add a real payload validator branch, and add a round-trip + malformed-payload test. If you do NOT use it, do not add any new partially-wired entry. Follow the exact validator idioms already in the file (`_has_lower_snake_payload`, `_has_nonnegative_integral_payload`, `_has_bool_payload`, etc.).

**`godot/scripts/tactical/outcomes/combat_outcome_state.gd` (DO NOT edit — COPY its shape):**
- This is the canonical small state-machine + serialization precedent in the codebase: `STATE_*` constants, `is_terminal()`, `validate() -> ActionResult`, `apply_*_event(event) -> ActionResult`, `to_dictionary()`, `copy()`, `static try_from_dictionary(data) -> ActionResult`, `static from_dictionary(data)` (push_error + null), and the `_has_field`/`_field`/`_has_string_like_field`/`_invalid` helpers. `RunState`/`RouteState`/`RouteNode` should read like siblings of this file.

### Testing standards summary

- Headless only, no rendering/audio/UI/scene-tree dependency ([Source: `project-context.md` §Testing Rules]). Tests live under `godot/tests/unit/run/` as `test_*.gd` extending `res://tests/unit/test_case.gd` (the runner auto-discovers `tests/unit` + `tests/integration` only).
- **Run the full suite via PowerShell** (`godot` is NOT on the Bash PATH on this machine — it resolves only as `C:\Users\Rasmus\bin\godot.cmd`):
  `powershell.exe -NoProfile -Command "godot --headless --path C:\Sealsworn\godot --scene res://tests/headless/test_runner.tscn --quit-after 10"`
  Expect runner exit 0 and "Headless tests passed." The suite is ~63 `test_*.gd` files and green; keep it green.
- **Real JSON round-trip is mandatory** for every snapshot/serialization test (`JSON.stringify` → `JSON.parse_string`, not native-dict equality). A latent int64 precision bug survived Epic 1 precisely because tests round-tripped native dicts ([Source: `project-context.md` §Save Rules; epic-3 retro Insight #7]).
- **Invalid/no-mutation discipline:** for the rejected-transition AC, capture `to_dictionary()` before and after and assert equality — the same no-mutation pattern Epic 1 commands use.
- `git diff --check` must be clean before review.

### Epic-transition prep folded in from the Epic 3 retrospective (forward-looking items that apply to THIS story)

[Source: `_bmad-output/implementation-artifacts/epic-3-retro-2026-06-17.md` §7 Next Epic Preview, §8 Action Items, §11 Next Steps]

1. **Apply the int64/real-JSON round-trip rule to the run/route snapshot from story one** (retro Next-Steps #5, Action Item carry). DIRECTLY applies: `RunState`/`RouteState` serialization must ride a real `JSON.stringify`/`parse_string` cycle in tests, and `root_seed` stays decimal-string encoded (already true in `RunSnapshot`). Task 4.1 + Task 6.4.
2. **Do NOT reintroduce the dropped `manual_seed_eligible_for_progression` key** — it is test-pinned ABSENT in `test_run_snapshot.gd` (retro §7, "RunSnapshot manual-seed vocabulary"). Use the existing `is_manual_seed` + `meta_progression_eligible` pair. The actual meta gate is Epic 8; 4.1 only records eligibility (manual-seed → not eligible).
3. **The no-surprise-key gate WILL fail-loud if you add a new top-level `RunSnapshot` field — that is expected; register/extend it.** `test_run_snapshot.gd::_between_level_field_contract_round_trips_with_no_surprise_fields` asserts no top-level key outside the pinned 23-key `_allowed_run_snapshot_keys()` set. If you must add one (e.g. `run_phase`), extend that allow-list + bump the assertion intentionally in the same change (the epic-3 "the gate will fail-loud on the new table → register/extend it" heads-up). PREFER nesting the phase inside the `route_state` payload so the gate stays green untouched. Task 4.3.
4. **The `map`-stream seed-regression fingerprint discipline starts at Story 4.2, NOT here.** 4.1 must consume **zero** RNG (no `map` draw). The "establish a `map` fingerprint from route-generation story one" prep is 4.2's, because 4.2 is route-generation story one. If you find yourself reaching for `RngStreamSet` in 4.1, you have crossed into 4.2's scope — stop. (Retro Next-Steps #4.)
5. **`GenerationResult.seed` success-path split — adjacent, but NOT owned by 4.1.** The retro flags closing/documenting the `GenerationResult.seed` success-path wart (seed is `""` on success; real seed is in `payload.level_seed`) as "the first Epic 4 generation-consumer touch" (retro Action Item #3, Next-Steps #3; also `deferred-work.md` 3.7 defer). **4.1 does not consume a `GenerationResult`** (node entry/level-request creation is Story 4.4), so 4.1 must NOT try to fix it and must NOT call generation. Recorded here only so you (a) don't reopen it, and (b) don't accidentally wire generation into 4.1. The owner is Story 4.4 (first node-loader / generation success-path consumer).
6. **No new autoload, library, or external dependency** (retro §7 Technical prerequisites: "none missing"). The autoload set is unchanged through Epic 3 (`GameSession`, `SceneManager`, `SaveManager`, `AudioManager`, `SettingsManager`, `Diagnostics`); `RunState` et al. are pure `RefCounted` services like `LevelGenerator`/`ManualSeedLoader`. Do not register a run autoload in this story.

### Deferred-work ledger overlap (only the items touching this story's surface)

[Source: `_bmad-output/implementation-artifacts/deferred-work.md`]

- **`GenerationResult.seed` success-path split (3.7 defer).** Subject overlaps Epic 4 broadly, but NOT Story 4.1 (4.1 never consumes a `GenerationResult`). Knowingly work AROUND it: do not call generation, do not read `result.seed`. It is Story 4.4's to address. (Covered above as retro item #5.)
- All other open deferrals (3.1–3.6 generator-internal Lows; 2.5/2.6 presentation; 2.7 RNG numeric-`state` tolerance; 2.8 `save_open_failed`; 2.9 schemaless settings) are **out of scope** for 4.1 — they touch the generation layer, the presentation/settings layer, or the save read-error paths, none of which this story implements. Do not reopen or re-defer them.

### Latest technical information

No external library or version research applies. The stack is fixed and stable: **Godot 4.6.3 stable standard build, typed GDScript** ([Source: `project-context.md` §Technology Stack]). No new dependency, no Godot .NET/C#, no cloud/telemetry/multiplayer. This story is pure in-engine typed-GDScript domain code on settled foundations (`ActionResult`, `DomainEvent`, `RngStreamSet`, `RunSnapshot`, `CombatOutcomeState` all exist and are stable).

### Project Structure Notes

- **New domain folder `scripts/run/` (decision + required project-context update).** The architecture specifies a `RunState` machine and a run-progression domain ([Source: `game-architecture.md` §State Management]) but maps no explicit directory for the run-progression *model* (route *generation* maps to `scripts/generation/route/`; saves to `scripts/save/`). Consistent with the project convention "organize scripts by domain" and with how `TurnState`/`CombatOutcomeState` live under their domain (`scripts/tactical/`), the run-progression model gets its own domain folder `godot/scripts/run/` (tests under `godot/tests/unit/run/`). `project-context.md` §Code Organization currently lists domains `core, tactical, rules, generation, ai, content, save, settings, ui, platform, diagnostics, utils` — **add `run` to that list as part of this story** (intentional convention extension, mirroring how `settings` was added in Epic 2). Keep the run domain scene-free like its siblings. The Epic 4 route-*generation* code (Story 4.2) goes in `scripts/generation/route/`, separate from `scripts/run/`.
- `test_project_structure.gd` asserts the architecture folder set exists — adding `scripts/run/` + `tests/unit/run/` will not break it (it asserts required roots are present, not that no extra folder exists). If that assertion is strict about an allow-list, update it intentionally alongside the project-context change; otherwise leave it untouched. Verify by reading the assertion before assuming.
- Naming: classes `PascalCase` (`RunState`, `RouteState`, `RouteNode`); files `snake_case.gd`; constants `UPPER_SNAKE_CASE`; phase/type/reveal ids lower_snake `StringName` for the wire format, `UPPER_SNAKE_CASE` for the constant names that hold them (mirror `CombatOutcomeState.STATE_VICTORY = &"victory"`). Error codes lower_snake with no dashes/dots/spaces (enforced by `ActionResult._is_valid_error_code`).

### Project Context Rules

Extracted from `project-context.md` — the rules that bind THIS story's implementation:

- **Scene-independent domain owns truth.** `RunState`/`RouteState`/`RouteNode` are typed `RefCounted` domain objects; scenes/UI/autoloads never own run-phase truth. UI (a later story) observes via view models and submits commands; it does not mutate run state directly.
- **Commands validate before mutation and return `ActionResult`; successful state changes emit deterministic past-tense `DomainEvent` records.** A rejected transition returns an error result, emits zero events, mutates nothing.
- **Named RNG streams only, via assigned stream — and 4.1 draws NONE.** Do not draw `map` (or any) RNG in run-state init/transitions. The `map` stream's first consumer is route generation (Story 4.2). Never use global `randi()`/`randf()`.
- **Save truth = versioned domain snapshots; compose, don't fork.** Persist run/route via the existing `RunSnapshot` fields. Snapshots are pure reads (no RNG draw, no mutation). `root_seed`/full-int64 fields are decimal-string encoded; read-tolerate int/integral-float/string.
- **Manual-seed runs grant no meta progression** (`is_manual_seed → meta_progression_eligible = false`); never reintroduce `manual_seed_eligible_for_progression`. Meta enforcement itself is Epic 8.
- **Headless tests with a real JSON round-trip; every state path gets valid + invalid/no-mutation coverage.** Keep the full suite green; `git diff --check` clean before review.
- **Do not put gameplay/flow decision logic in autoloads; do not add cloud/telemetry/multiplayer/.NET; do not let debug/manual-seed actions grant progression.**

### References

- [Source: `_bmad-output/planning-artifacts/epics.md` → Epic 4 → Story 4.1 (AC) and Stories 4.2–4.6 (scope boundaries), Story 4.5 (MVP node-type set)]
- [Source: `_bmad-output/game-architecture.md` §State Management line 330 (`RunState` phases), line 1294 (`can_transition_to`/`transition_to`), line 420 (`run_started` trigger window), lines 361-364 (save contract), line 915 (`scripts/generation/route/`), line 975 (scene-free domain rule)]
- [Source: `project-context.md` §Core Direction, §Determinism & Simulation Rules, §Save/Snapshot Rules, §Code Organization Rules, §Naming Rules, §Testing Rules, §Critical Don't-Miss Rules]
- [Source: `_bmad-output/implementation-artifacts/epic-3-retro-2026-06-17.md` §7 Next Epic Preview, §8 Action Items #3/#5, §11 Next Steps #3/#4/#5]
- [Source: `_bmad-output/implementation-artifacts/deferred-work.md` — 3.7 `GenerationResult.seed` defer (adjacent, owned by Story 4.4)]
- [Source: `godot/scripts/save/snapshots/run_snapshot.gd` — existing run/route fields + lenient parse + int64 encoding]
- [Source: `godot/scripts/tactical/outcomes/combat_outcome_state.gd` — state-machine + serialization precedent to mirror]
- [Source: `godot/scripts/core/events/domain_event.gd` — reserved `RUN_STARTED`/`run_started`; factory + validator idioms]
- [Source: `godot/scripts/core/results/action_result.gd` — `ActionResult.ok/error`, lower_snake error-code validation]
- [Source: `godot/scripts/core/state/rng_stream_set.gd` — `STREAM_MAP` (do not use in 4.1), int64 decode helper to copy]
- [Source: `godot/tests/unit/save/test_run_snapshot.gd` — pinned 23-key no-surprise-key gate + int64 round-trip test pattern]

## Dev Agent Record

### Agent Model Used

Opus 4.8 (claude-opus-4-8[1m])

### Debug Log References

- Full headless suite (PowerShell): `godot --headless --path C:\Sealsworn\godot --scene res://tests/headless/test_runner.tscn --quit-after 10` → "Headless tests passed.", runner exit code 0 (all `test_*.gd` PASS, including the three new `tests/unit/run/` files and the extended `test_domain_event.gd`).
- `git diff --check` → clean (only a benign LF→CRLF advisory on the story `.md`, not a whitespace error).
- Three expected/benign stderr lines during the run: (1) `RouteNode parse failed: invalid_node_type` — the deliberate `RouteNode.from_dictionary` null-path test (intentional `push_error`, mirroring `CombatOutcomeState.from_dictionary`); (2)+(3) the two pre-existing `Parse JSON failed` lines from the deliberate malformed-input save/settings tests. None is a suite failure.

### Completion Notes List

- **Scope held tight.** Implemented ONLY the run-progression domain model: `RouteNode` (model + validation + serialization), `RouteState` (graph container + structural integrity + ordered serialization), `RunState` (phase machine + transition table + validation + serialization + RunSnapshot bridge). Drew ZERO RNG (no `map`/`RngStreamSet` touch — that is Story 4.2). Did NOT build route generation (4.2), route choice/commit command (4.3), node entry/exit/level-request (4.4), or per-node-type resolution (4.5). Did NOT register any autoload or wire `GameSession`.
- **Task 4.3 decision (recorded as required): NESTED the run phase inside the `route_state` payload** under the `RunState.RUN_PHASE_KEY` (`run_phase`) key, rather than adding a new top-level `RunSnapshot` key. Consequence: the pinned 23-key `test_run_snapshot.gd::_between_level_field_contract_round_trips_with_no_surprise_fields` gate stays GREEN UNTOUCHED (verified — `test_run_snapshot.gd` and `_allowed_run_snapshot_keys()` were NOT modified). A duplicate of that gate is asserted in `test_run_state.gd::_run_snapshot_no_surprise_key_gate_stays_green` so a future regression that adds a top-level key fails loudly from the run-domain side too.
- **`run_started` domain event fully wired (not half-wired).** Added `DomainEvent.run_started(sequence_id, payload)` factory + `_validate_run_started_payload` branch + a new `_has_decimal_string_payload` helper. Payload is `{root_seed: <decimal-string>, is_manual_seed: bool, node_count: int}`. `run_started` is a SYSTEM event — left OUT of `_event_requires_actor`, and a test asserts an empty `actor_id` is accepted. `root_seed` is carried as the int64-safe decimal-string form (a raw-int `root_seed` is rejected) so the seed survives a JSON round-trip; the validator and a real-JSON round-trip test cover both the happy path and `invalid_event_payload` rejection. NOTE: 4.1 ships the event factory + table wiring + tests; an actual run-start *emission site* (which command/service emits it) arrives with the run-start command in a later Epic 4 story — 4.1 has no command layer yet.
- **Stable node ids accepted, not minted (per AC interpretation).** `RouteNode._is_valid_node_id` accepts a caller/fixture-supplied id verbatim, rejecting only empty/whitespace-containing ids (internal or surrounding). Hyphens are allowed (tests use `"choice-a"`). No seeded id-generation routine was built (that is 4.2).
- **Clue fields** are optional/free-form (`clues: Array[String]`, default `[]`); the canonical tags (`safer_combat`, `stronger_reward`, `unknown_risk`, `recovery`, `elite_pressure`, `mystery`) are defined as constants. Clue *generation* is 4.2.
- **`revealed_route_node_ids` bridge derivation:** `to_run_snapshot_fields()` derives the existing `RunSnapshot.revealed_route_node_ids` field from each node's `reveal_state` (`revealed` OR `cleared`), in stable node order. This keeps the existing field populated without forking a parallel format.
- **project-context.md updated** (intentional convention extension): added `run` to the domain-folder list and to the scene-free-domain independence rule, with a note that route *generation* lives separately under `scripts/generation/route/`. `test_project_structure.gd` uses a required-roots check (not an allow-list), so adding `scripts/run/`+`tests/unit/run/` did not require touching it (confirmed by reading it).
- **No breaking changes to public interfaces.** `RunSnapshot` schema, top-level key set, and `parse()` leniency are unchanged. `DomainEvent` only GAINED a factory/validator for the already-reserved `run_started` id (previously it fell through the no-op `_:` validator arm; now a `run_started` dict requires a valid payload — but no existing code or test constructs a `run_started` dict, so nothing regresses).

### Review Findings

**Round 1 of 3**

Verdict: **Approve** (no Critical/High; all findings Low/observational and non-blocking). Suite green (exit 0), `git diff --check` clean.

- [x] [Review][Decision] `try_from_run_snapshot_fields` defaults a missing/blank `run_phase` to `PHASE_NEW_RUN` while keeping the rest of the run state — choose intended resume semantics. [godot/scripts/run/run_state.gd:217-238] — On a save written by a future emission site, if `route_state.run_phase` is absent (older save, or a hand-rolled payload) the reconstruction silently lands the run in `PHASE_NEW_RUN` even when `current_route_node_id`/`cleared_node_ids` indicate mid-run progress. That is a benign, internally-consistent default for 4.1 (no emission site exists yet, and `validate()` still passes because NEW_RUN is a legal phase), but the "missing phase → NEW_RUN" rule is a save-compat decision that the persistence-consumer story (4.4+) should ratify rather than inherit by accident. No code change required in 4.1; flagging so the resume-path owner decides whether a phaseless route payload should instead be rejected or inferred from progress. Human call — left as a Decision.
  - **DISPOSITION (auto-gds, 2026-06-18):** No 4.1 code change (the reviewer concurs none is required). Deferred to **Story 4.4** (Node Entry and Exit Resolution — the first persistence-consumer that loads run state): its owner must ratify whether a phaseless route payload defaults to `PHASE_NEW_RUN`, is rejected, or infers the phase from progress (`cleared_node_ids`/`current_route_node_id`), and add the corresponding test. Recorded in `deferred-work.md` under this story's heading so Story 4.4's create-story surfaces it. The semantics are deliberately NOT decided now — there is no save writer/reader yet, so the call cannot be made meaningfully until 4.4.
- [x] [Review][Patch] Bridge writes `current_route_node_id` at top level but `try_from_run_snapshot_fields` ignores it, reading the pointer only from the nested `route_state.current_node_id` [godot/scripts/run/run_state.gd:170-177, 217-234] — `to_run_snapshot_fields()` emits the current-node pointer in TWO places: the top-level `current_route_node_id` field (line 175) and inside the `route_state` payload via `RouteState.to_dictionary()` (route_state.gd:136). Reconstruction (`try_from_run_snapshot_fields`) rebuilds `RouteState` from the nested payload only and never consults the top-level field. Today the two are always written from the same source so there is NO data loss, but it is a latent divergence trap: a future writer (or a save migration) that sets only the top-level `current_route_node_id` would be silently dropped on resume. Low severity / not byte-loss now. Suggested hardening: in `try_from_run_snapshot_fields`, if the top-level `current_route_node_id` is present and non-empty, prefer/cross-check it over the nested value (or assert they agree) so the canonical field cannot be silently ignored. Unambiguous fix; classified patch (non-blocking).
  - **RESOLVED (2026-06-18):** `try_from_run_snapshot_fields` now cross-checks the canonical top-level `current_route_node_id` against the nested `route_state.current_node_id`. If the top-level field is present and non-empty it is treated as the source of truth and preferred (so a future writer / save migration that sets ONLY the top-level field survives resume). A non-empty nested pointer that disagrees with the top-level field is a corrupt save and is rejected fail-loud with a new stable code `route_node_pointer_conflict` (a non-string/non-empty top-level value is rejected with `invalid_run_state`). The preferred pointer remains subject to the existing structural known-node check via `validate()`/`RouteState.validate()`. New regression test `test_run_state.gd::_top_level_current_node_pointer_is_honored_on_resume` exercises all three paths: top-level-as-source-of-truth (nested empty), agree, and disagree→`route_node_pointer_conflict`. Full headless suite green (exit 0).
- [x] [Review][Defer] `node_count` in the `run_started` payload is an unbounded `int` that does not round-trip a full int64 through JSON [godot/scripts/core/events/domain_event.gd:65, 424] — `node_count` is validated as a non-negative integral and serialized as a raw JSON number (unlike `root_seed`, which is decimal-string encoded). For the MVP route (8–12 nodes) this is a non-issue, and 4.1 has no emission site, so it cannot bite now. Recorded as a defer because it is a pre-existing class of the same int64/real-JSON concern the project tracks: any count/total that could theoretically exceed 2^53 should follow the decimal-string rule. node_count realistically never will, so this is informational only — owner: whatever story first emits `run_started` (re-confirm node_count stays small). Deferred, pre-existing pattern.
- [x] [Review][Defer] `available_choice_ids()` derives choices purely from `outgoing_link_ids` minus `cleared_node_ids`, with no reveal-state or forward-only filtering [godot/scripts/run/route_state.gd:63-76] — A `hidden` linked node is still surfaced as an available choice, and there is no no-backtracking/forward-only enforcement. This is CORRECT for 4.1 by explicit scope (the story defers forward-only edge validation to 4.2 and choose-and-commit to 4.3, and only asks 4.1 to "record/derive" raw choices). Logged so the 4.3 owner remembers that choice-eligibility filtering (reveal gating, no-backtracking) is NOT yet applied here and must be layered in the commit command. Deferred to Story 4.3 by design — not a 4.1 defect.

**Round 2 of 3** (independent alternate-model adversarial re-review, 2026-06-18)

Verdict: **Approve** (no Critical/High; the Round 1 `[Review][Patch]` fix verified correct AND complete; one NEW Low logged as a forward Defer). Full headless suite green (runner exit 0, "Headless tests passed.", incl. the three `tests/unit/run/` files + the extended `test_domain_event.gd`); the three stderr lines (`RouteNode parse failed: invalid_node_type`, the `99999999999999999999` int64-overflow line from the pre-existing `test_manual_seed_loader.gd`, and the malformed-input save/settings parse lines) are the documented deliberate-negative-test lines, not failures.

- [x] [Review][Patch][VERIFIED-FIXED] Round 1's top-level `current_route_node_id`-ignored-on-resume patch is correct AND complete. `try_from_run_snapshot_fields` (run_state.gd:236-249) now: (a) prefers a present/non-empty top-level pointer as the source of truth (so a future writer / migration that sets ONLY the top-level field survives resume); (b) fail-loud-rejects a non-empty nested pointer that disagrees with a new stable code `route_node_pointer_conflict`; (c) rejects a non-string/non-empty top-level value with `invalid_run_state`. I additionally traced the path Round 1's regression does NOT directly cover — a top-level pointer naming a node ABSENT from the route (nested empty): after line 247 assigns `parsed_route.current_node_id = "ghost"`, the subsequent `run_state.validate()` -> `route.validate()` (route_state.gd:104) catches it with `unknown_current_node`. So the overwritten pointer is always re-validated structurally. Correct. (Minor observation, NOT a finding: there is no *direct* test for the unknown-top-level-pointer sub-path; it is covered transitively by `test_route_state.gd::_unknown_current_node_is_rejected`. No code change warranted.)
- [x] [Review][Defer] (Low) NEW — `DomainEvent._has_decimal_string_payload` validates the `run_started` payload's `root_seed` with `is_valid_int()` only, with NO int64-range/lossless check [godot/scripts/core/events/domain_event.gd:756-762, validator at 417-426]. An out-of-int64 decimal string (e.g. `"99999999999999999999"` or max-int64+1 `"9223372036854775808"`) passes `is_valid_int()` and is therefore ACCEPTED as a valid payload, even though `String.to_int()` saturates/wraps it (empirically confirmed: `"99999999999999999999".to_int() == 9223372036854775807`; `"9223372036854775808".to_int() == -9223372036854775808` — neither round-trips). This is weaker than the project's OWN now-established seed-validation discipline: Story 3.7 added a strict `_decimal_string_round_trips_losslessly` check to `ManualSeedLoader.parse_seed` precisely so an out-of-range seed string is REJECTED rather than silently saturated (manual_seed_loader.gd:88-98, pinned by `test_manual_seed_loader.gd:153`). The new event-payload validator is a seed-validation surface that did not adopt that rule. Why it cannot bite in 4.1: (a) no `run_started` emission site ships in 4.1; (b) the payload `root_seed` is carried as a string and is never decoded to int by any 4.1 code, so nothing is corrupted today — it is a validation-strictness gap, not a data-loss bug; (c) the test only exercises the in-range `"9223372036854775000"`. Pairs with the existing Round 1 `node_count` Defer (same payload, same int64/real-JSON family). Fix (when a story first EMITS `run_started`, or on the next touch of the event-payload validators): tighten `_has_decimal_string_payload` to also require `str(value.to_int()) == <canonicalized value>` (reuse the 3.7 lossless/canonicalize idiom), and add an out-of-range rejection assertion to `_run_started_serializes_and_parses_stable_payload`. Owner: whatever story first emits `run_started`. Not blocking — no AC depends on it; no runtime constructs the payload yet.
- [Review][Decision][CARRIED] The Round 1 `[Review][Decision]` (phaseless `route_state.run_phase` -> `PHASE_NEW_RUN` resume default) remains correctly OPEN as a forward deferral to Story 4.4 (the first persistence-consumer). Round 2 concurs with the disposition: no 4.1 code change is warranted (there is still no save writer/reader, so the call cannot be made meaningfully now), and it is already logged in `deferred-work.md` under this story's heading. Re-stated here only to keep the open-decision count accurate for the round summary; no NEW decision is introduced this round.

NOTE (Round 2 scope confirmation): independently re-verified that `scripts/run/` draws ZERO RNG and has no `Node`/`Control`/`get_tree`/`get_node`/`RngStreamSet`/`STREAM_MAP` usage (only a comment mentions `RngStreamSet`); the `run_started` event is FULLY wired (enum + both id maps + factory + validator branch + correctly absent from `_event_requires_actor`); the 23-key no-surprise-key gate is green untouched and duplicated on the run-domain side; and `RunState._int64_or_zero` is a faithful copy of the pre-existing `RunSnapshot._int64_or_zero` / `RngStreamSet._int64_from_value` (the loose snapshot-decode pattern the story Task 4.1 explicitly directed copying) — that loose decoder is a pre-existing project-wide pattern (already acknowledged in the 3.7 review's `parse_seed` Patch), NOT a 4.1 defect, and is intentionally NOT re-logged.

### File List

NEW:
- `godot/scripts/run/route_node.gd`
- `godot/scripts/run/route_state.gd`
- `godot/scripts/run/run_state.gd`
- `godot/tests/unit/run/test_route_node.gd`
- `godot/tests/unit/run/test_route_state.gd`
- `godot/tests/unit/run/test_run_state.gd`

MODIFIED:
- `godot/scripts/core/events/domain_event.gd` (added `run_started` factory + `_validate_run_started_payload` + `_has_decimal_string_payload`; `run_started` left out of `_event_requires_actor`)
- `godot/tests/unit/core/test_domain_event.gd` (added `_run_started_serializes_and_parses_stable_payload`)
- `project-context.md` (added `run` to the domain-folder list + scene-free-domain rule)
