# Story 7.1: Risk Economy State

Status: ready-for-dev

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a player,
I want gold, healing pressure, curses/corruption, and Oath Shard eligibility to be tracked clearly,
so that risk choices have visible consequences.

## Acceptance Criteria

(Verbatim from `planning-artifacts/epics.md` lines 1867-1888, Story 7.1; FR54.)

**AC1 — Initialization + domain/save presence**
- **Given** a run starts
- **When** risk economy state is initialized
- **Then** it tracks gold, healing resources or availability, curse/corruption state, Oath Shard eligibility, and risk flags
- **And** the fields are part of domain state **and save snapshots**.

**AC2 — Deterministic economy events + explanation log**
- **Given** gold or healing changes
- **When** an economy command or reward outcome resolves
- **Then** deterministic currency or healing events are emitted
- **And** the explanation log records the reason.

**AC3 — Invalid change rejection (no mutation)**
- **Given** invalid economy changes are requested
- **When** validation fails
- **Then** the command returns a stable error
- **And** currency, health, curse, and reward state remain unchanged.

## Scope boundary (read FIRST — this story is STATE + COMMANDS + SAVE, not the full risk economy)

This is the **opening story of Epic 7** and the **headline handoff from Epic 6**: it introduces the live risk-economy domain field that the whole Epic-6 loot/passive layer has been *recording against but not applying* (the retro's HIGH item T1). Keep scope tight to the AC:

**IN scope (this story):**
1. A new `RiskEconomyState` run-domain value object (scene-free `RefCounted`, recorded on `RunState`) tracking **gold**, **healing availability**, **curse/corruption state**, **Oath Shard eligibility**, and **risk flags** — the additive-lenient `RunState` field pattern (the exact 5.3 `starting_kit` / 6.2 `inventory` shape).
2. One (or a small set of) caller-driven run-domain **economy command(s)** that mutate gold/healing through the 4.3 run-command idiom (validate-then-mutate, reject `sequence_id <= 0` first, byte-identical no-mutation on reject), emitting **deterministic** currency/healing `DomainEvent`s carrying the reason (AC2's explanation log).
3. **Wire the gold credit off the EXISTING Epic-6 `reward_resolved` `category == gold` hook** — the one Epic-6 recorded-outcome hook that is purely economic (no curse/event semantics). This makes a gold reward FELT (the wallet rises) instead of merely recorded. This is the central T1 wire-off the retro assigns here.
4. **Persist economy state into the save** (AC1's "and save snapshots") — see the SAVE STRATEGY section below; this is the one scope item that genuinely differs from Epic 6 (inventory/offer were off the route-position save).
5. Full unit tests: command valid/invalid-no-mutation, event factory/validator/round-trip/malformed, save round-trip + migration, determinism.

**OUT of scope (explicitly later Epic-7 stories — do NOT pull forward):**
- **Curse/corruption RULES + cursed-reward tradeoff UX + the cleanse/curse application** → **Story 7.2** (curse/corruption rules, FR55). 7.1 introduces the curse/corruption *state fields + the structural setter/event*, but does NOT author curse trigger windows, the rules-kernel curse resolution, or the cursed-reward view model. (The `passive_destroyed` "cleanse or reduce curse" outcome wiring is 7.2's, not 7.1's.)
- **Risk/reward EVENT CHOICES + the `events`-stream event roll + the "risk flags future systems can query" producers** → **Story 7.3** (FR54). 7.1 introduces the `risk_flags` *container + a structural setter*, but does NOT build the event node, the event definitions, or the `events`-stream draw.
- **Affinity definitions / assignment / tactical effects / Darkness** → **Stories 7.4-7.6** (FR56-FR58). The `RunSnapshot.affinities` placeholder key is NOT 7.1's to populate.
- **Oath Shard AWARDING / meta-profile** → **Epic 8** (FR59). 7.1 tracks Oath-Shard *eligibility* (a run-level flag, the gate that decides whether a finished run MAY award shards) — NOT the award amount, the meta profile, or the outpost. Do NOT introduce a meta-profile snapshot.
- **Live current-HP / the tactical-board damage→HP wiring.** v0 still has NO live tactical play loop in the headless orchestrator (combat auto-resolves). "Healing availability" is a run-economy *resource/charge count*, NOT a live tactical current-HP that combat decrements. Model healing as availability (the AC's exact word: "healing resources **or availability**"), not as a current-HP the board mutates. (Whether a future story unifies `starting_kit.baseline_hp` + a live current-HP is Epic 7/9's; 7.1 does not invent a board-coupled current-HP.)
- The **consumable heal/ward MUTATION off `item_consumed`** and the **Destroy-outcome MUTATION off `passive_destroyed`** — these wire healing/curse-removal off Epic-6 events. They are a natural sibling of item 3, but they touch healing/curse semantics that overlap 7.2 (curse) and need the heal-availability + curse model to be settled first. **Default: defer the `item_consumed`/`passive_destroyed` wiring to the story that owns the consumed effect (7.2 for curse-removal; a heal-availability application may land here IF the heal model is trivially a charge increment — but if it forces any curse coupling, defer it).** Record the chosen disposition in Completion Notes either way (do not silently skip).

If an AC seems to demand a curse RULE or an event ROLL, re-read: AC1 demands the curse/corruption **state** is *tracked* (a field + save), not that curses *trigger* (7.2) or that events *offer* them (7.3).

## Tasks / Subtasks

- [ ] **Task 1 — `RiskEconomyState` run-domain value object (AC1)** — `godot/scripts/run/risk_economy_state.gd`
  - [ ] Create a scene-free `RefCounted` value object mirroring `StartingKit`/`InventoryState` discipline: exact-key `to_dictionary()` (a `DICTIONARY_KEYS` const pinned by test — a key never silently appears/vanishes), lenient `try_from_dictionary` (value object, no reject path — a partial/legacy dict defaults cleanly), deep `copy()`, and a `_init(...)` with EVERY new param defaulted.
  - [ ] Fields (AC1's five categories): `gold: int` (>= 0, default 0), a **healing-availability** representation (e.g. `healing_charges: int` >= 0, default 0 — a resource/charge count, NOT a live current-HP; name it per the "resources or availability" wording), `curse_state` + `corruption_state` (the curse/corruption tracking — keep MINIMAL this story: a count or a small id-list container is fine; do NOT author curse *rules*), `oath_shard_eligible: bool` (the run-level eligibility gate, default derived — see below), and `risk_flags` (a container — a `Dictionary` or `Array[String]` of risk-flag ids; EMPTY in v0, 7.3 populates it via a structural setter).
  - [ ] `gold`/`healing_charges`/curse-corruption counts are **small bounded ints** (NOT seeds — NO int64/decimal-string encoding; the 5.3/6.2 `baseline_hp`/`capacity` precedent). Only RNG `root_seed`/stream `state` need decimal-string encoding.
  - [ ] **Oath-Shard eligibility invariant:** a **manual-seed run is NEVER eligible** (mirror the existing `RunState`/`RunSnapshot` `meta_progression_eligible != not is_manual_seed` invariant — GDD: "Oath Shards: meta currency awarded only after run end and only in eligible non-manual-seed runs"). Default `oath_shard_eligible` to derive from the run's manual-seed flag at init, consistent with `meta_progression_eligible`. Decide + document whether `oath_shard_eligible` is a NEW field or simply an alias/read of the existing `RunState.meta_progression_eligible` (recommend: a thin convenience that does NOT duplicate the source of truth — the existing `meta_progression_eligible` already IS the eligibility gate; if you add a distinct field, keep it in lockstep and assert the invariant in `validate()`). Record this as a `[Decision]` in Completion Notes.
  - [ ] Add a unit test `godot/tests/unit/run/test_risk_economy_state.gd` pinning `DICTIONARY_KEYS`, the lenient decode (partial/absent dict), the deep copy (mutating a copy never perturbs the source), and the eligibility invariant.

- [ ] **Task 2 — Seat `RiskEconomyState` on `RunState` as an additive-lenient field (AC1)** — `godot/scripts/run/run_state.gd`
  - [ ] Add a `var risk_economy: RiskEconomyState` field following the EXACT 6.2 `inventory` pattern: default to a fresh state (or null with a `_risk_economy_or_new()` guard — match whichever the inventory precedent uses; inventory defaults to a fresh empty model, never null). It is **DELIBERATELY NOT a required `validate()` field** (a legacy/pre-7.1 run has no economy and must still validate), new constructor param **LAST**, and it rides `to_dictionary()`/`try_from_dictionary` (the FULL run dict, lenient-read) so a copied/round-tripped run preserves it. `copy()` **deep-copies** it (the curse/risk-flag containers must not be shared by reference — the inventory deep-copy precedent).
  - [ ] Preserve EVERY existing `RunState.new(...)` call site (the new param is last + defaulted). Grep for `RunState.new(` / `run_state.gd").new(` and confirm none break.
  - [ ] Extend `test_run_state.gd` to assert the economy field rides the full run dict round-trip and a pre-7.1 dict (no economy key) parses with the default.

- [ ] **Task 3 — Economy command(s) + deterministic currency/healing events (AC2, AC3)** — `godot/scripts/core/commands/`
  - [ ] Author the run-domain economy command(s) following the 4.3 run-command idiom **VERBATIM** (the `ResolveRewardCommand`/`PickupItemCommand` template): extend `game_command.gd`, take the live `RunState` DIRECTLY (no wrapper), caller supplies `sequence_id` via the constructor (default 1), `validate(state)` rejects `sequence_id <= 0` FIRST (`invalid_event_sequence_id`), validate-then-mutate, ZERO events + byte-identical no-mutation `RunState` on ANY reject, build the event ONLY AFTER the (infallible-once-validated) mutation.
  - [ ] Recommended minimal shape: a single parameterized economy command (e.g. `ApplyEconomyChangeCommand` taking a typed delta — gold delta and/or healing delta + a reason id) OR a tight pair (`CreditGoldCommand` / `ApplyHealingCommand`). Keep it SMALL — one validate-then-mutate path. **AC3 reject cases** to cover with stable error codes (offending value in `metadata`, never in the lower_snake error code): a non-`RunState` context (`invalid_context`, the `ResolveRewardCommand._invalid_context` precedent), a structurally-invalid run, a change that would drive a field below its floor (e.g. gold below 0 / spending more gold than held — a stable code like `insufficient_gold`), and an out-of-range/garbage delta. On every reject: ZERO events, ZERO RNG, byte-identical run.
  - [ ] **Events are DETERMINISTIC** (like `item_gained`/`reward_resolved`/`passive_consumed`/`item_consumed` — NOT `passive_destroyed`). The economy command DRAWS ZERO RNG (a credit/spend/heal is a recorded amount, not a roll). Grep-confirm no `randi`/`randf`/`RandomNumberGenerator` in the new command (the standing named-RNG gate). The event payload carries the **reason** (AC2's explanation-log record) + the before/after amounts (e.g. `gold_before`/`gold_after`/`amount`/`reason`), all as the appropriate bounded-int / lower_snake / non-empty-string payload shapes.
  - [ ] Add unit test(s) `godot/tests/unit/core/test_<economy_command>.gd`: a valid credit/spend/heal (asserts the field changes + the event payload), EACH reject branch (asserts byte-identical no-mutation + ZERO events + the stable code), and a no-RNG assertion (the held state / stream is byte-identical across success + reject; the `test_use_consumable_command.gd` precedent — and cover MULTIPLE reject branches, not just one, per the 6.7 Round-1 Low note).

- [ ] **Task 4 — New SYSTEM event(s) wired end-to-end, append-only (AC2)** — `godot/scripts/core/events/domain_event.gd`
  - [ ] Append the new currency/healing event member(s) at the **END** of the `DomainEvent.Type` enum (after `ITEM_CONSUMED`) — **NEVER renumber** an existing member (the append-only SYSTEM-event discipline; the project-context "Critical Don't-Miss" rule). They are SYSTEM events (no actor — NOT in `_event_requires_actor`).
  - [ ] Wire EVERY touch-point (the 6.x checklist — verified by the existing tests): the `EVENT_ID_*` const, the `static func <event>(sequence_id, payload)` factory (normalize/duplicate the payload defensively), the `_validate_<event>_payload` validator (per-field, fail-loud — the reason is lower_snake or a non-empty string; amounts are non-negative integral; before/after are non-negative integral), the `_validate_payload_for_event` match arm, BOTH id maps (`id_for_type` + `type_for_id`), and the exhaustive `expected_ids` pin in `test_domain_event.gd::_event_identifiers_are_stable_machine_ids`.
  - [ ] Naming: choose past-tense SYSTEM-event ids (e.g. `gold_changed` / `healing_changed`, or `economy_changed` if you unify) — lower_snake, consistent with `reward_resolved`/`item_consumed`. Decide single-vs-split and record in Completion Notes.
  - [ ] **Fold in the retro's T3 hardening (the 6.7 Round-1 Low):** when you touch `expected_ids`, ADD an enum-exhaustiveness assertion tying `expected_ids.size()` to the `DomainEvent.Type` member count (e.g. `expected_ids.size() == Type.size() - 1` for `UNKNOWN`, or iterate the enum asserting each non-`UNKNOWN` member is a key). This closes the silently-un-pinned-future-event gap the retro flagged (T3). This is the natural "first Epic-7 event touches `domain_event.gd`" owner the retro named.
  - [ ] Add per-event tests to `test_domain_event.gd`: a clean round-trip (`to_dictionary` -> `try_from_dictionary`) + per-field malformed-negative rejections (the `_validate_item_consumed_payload` test precedent).

- [ ] **Task 5 — Wire the gold credit off the Epic-6 `reward_resolved` gold hook (AC2 — the T1 wire-off)** — `godot/scripts/core/commands/resolve_reward_command.gd` (and likely `godot/scripts/run/run_orchestrator.gd`)
  - [ ] **CRITICAL — gold is a BAND, not a fixed amount, and RESOLVE must draw ZERO new RNG.** `GoldRewardDefinition` declares an inclusive `gold_min..gold_max` band (`gold_reward_definition.gd:14-15`), NOT a single amount — Epic 6 NEVER rolled the concrete gold (it left gold outcome-record-only). So a wallet credit needs a concrete amount, which means a **roll within the band**. The Epic-6 invariant is iron: **`ResolveRewardCommand` draws ZERO new RNG — the offer was rolled at GENERATE** (`resolve_reward_command.gd:14-18`). Therefore **roll the concrete gold amount at GENERATE time** (in `RunOrchestrator.generate_reward_offer`, alongside the existing offer draw, through the SAME run-level `RngStreamSet` on the `rewards`/`loot` stream — the named-RNG rule + the proven 6.3 T2 threading) and **carry the rolled amount on the stored `RewardOffer` + the `reward_resolved` payload**, so RESOLVE stays purely deterministic (it reads the already-rolled amount and credits it). Do NOT roll gold inside `ResolveRewardCommand` (that would violate the zero-new-RNG-on-resolve invariant) and do NOT credit a band/`gold_max`/fabricated amount.
  - [ ] At GENERATE: when the drawn offer entry's category is `gold`, resolve its `GoldRewardDefinition` through the gold-reward repository, roll `gold_min..gold_max` via `RngStreamSet.rand_int(stream_name, ...)` on the run-level streams (a SECOND draw on the same stream — deterministic + reproducible from the seed/state), and store the rolled `gold_amount` on the `RewardOffer` (add a small additive field to `reward_offer.gd`, mirroring how it already stores `roll`/`draw_index`/`state_after`). A non-gold offer rolls no gold. This is a NEW RNG draw site — route it EXCLUSIVELY through the run-level set on the `rewards`/`loot` stream (NEVER `randi`/`randf`/a new `RandomNumberGenerator`); it advances the same stream the route-position save persists.
  - [ ] At RESOLVE: in `ResolveRewardCommand.execute`, REPLACE the `gold` category no-op (`resolve_reward_command.gd:130-131`) with a deterministic wallet credit into `run.risk_economy` using the `gold_amount` already on the pending offer (ZERO new RNG). Emit the new currency event alongside `reward_resolved` using a DISTINCT `sequence_id` (the `sequence_id + 1` precedent the backpack-pickup branch uses for `item_gained` — `:120`). The passive branch STAYS a no-op (passive Consume/Destroy is 6.5/6.6; curse is 7.2).
  - [ ] Preserve the existing `ResolveRewardCommand` contract exactly: the backpack-category compose-`PickupItemCommand` path, the `inventory_full`-leaves-offer-pending honesty, the offer flip + `reward_resolved`, and the no-double-apply / no-mutation-on-reject guarantees (a re-resolve of a `resolved` offer credits ZERO second gold — the credit rides the SAME validate-then-mutate path so a rejected resolve mutates nothing).
  - [ ] **This is the point where the 4.6 inert-run-level-`RngStreamSet` `LevelGenerator`-injection residual stays parked but the reward-stream half advances again** — the gold roll goes through `RunOrchestrator.streams` (already proven live by 6.3), so no new inert-stream exposure. Update `test_run_route_position_save.gd`'s RNG round-trip if the gold roll changes the persisted stream state at a tested boundary.
  - [ ] Extend `test_resolve_reward_command.gd` + the orchestrator reward tests: a gold reward GENERATES with a rolled `gold_amount` within the band (deterministic for a seed), RESOLVE credits the wallet by exactly that amount + emits the currency event drawing ZERO RNG, a re-resolve credits no second gold, and a backpack/passive reward credits zero gold (unchanged paths). Record the GENERATE-rolls-gold / RESOLVE-credits-deterministically split as a `[Decision]`.
  - [ ] **Alternative (only if the GENERATE-time roll proves too invasive for this story):** keep gold outcome-record-only at the reward path and credit the wallet ONLY via the direct economy command (Task 3), leaving the `reward_resolved` gold wire-off to a dedicated follow-up. This is a weaker close of T1 — prefer the GENERATE-roll path above; if you take this fallback, log it as a `[Decision]` + a NEW `deferred-work.md` entry so the gold-reward→wallet wire-off is not silently dropped.

- [ ] **Task 6 — Persist economy state into the save (AC1 "and save snapshots") + migration** — see SAVE STRATEGY below; `godot/scripts/run/run_state.gd`, `godot/scripts/save/snapshots/run_snapshot.gd` (and `run_resume_service.gd` IF the route-position resume must carry economy)
  - [ ] Populate the economy into the save WITHOUT adding a new top-level `RunSnapshot` key. The `RunSnapshot` ALREADY declares (and the 23-key gate ALREADY pins) the economy keys `gold` / `oath_shards` / `corruption` / `curses` — plus `passives`/`inventory`/`equipment`/`affinities`/`meta_progression`. These are currently inert placeholders defaulted at 0/`[]`/`{}`. See SAVE STRATEGY for the two options and the recommended one.
  - [ ] Add the migration/round-trip coverage the project rules require for ANY save schema change: a JSON round-trip (`JSON.stringify` -> `parse_string`) asserting the economy survives, AND a pre-7.1 (economy-absent) save parses with the default (the lenient-decode / back-compat guarantee). Per the save-rules: "Save snapshots need migration tests for every schema change."
  - [ ] **EXPECTED + REQUIRED:** the two no-surprise-key tests `test_run_snapshot.gd::_between_level_field_contract_round_trips_with_no_surprise_fields` and `test_run_route_position_save.gd::_composed_route_position_snapshot_stays_within_the_23_key_gate` currently assert the economy fields stay at their **empty/zero defaults** (`gold == 0`, `curses == []`, `corruption == 0`, etc.). Populating economy WILL flip those default-value assertions. **UPDATE those assertions DELIBERATELY** to the new populated values — this is the retro's exact heads-up ("the gate will fail-loud on the new table → that is expected, register/extend it"). The **23-key COUNT must stay 23** (do NOT add a top-level key — `_allowed_run_snapshot_keys()` stays the same 23-entry list); only the per-field default-value assertions change.

- [ ] **Task 7 — Full headless suite + diff hygiene**
  - [ ] Run the full headless suite (see Testing Standards). Apply the **false-PASS grep guard**: grep raw runner output for `SCRIPT ERROR|Parse Error|Compile Error` — NEVER trust the summary PASS line alone (the standing gate; a reserved-name / compile break can print PASS).
  - [ ] Run `git diff --check` (clean).
  - [ ] Confirm `scripts/rules/{conditions,operations}` stay EMPTY (0 `.gd`) — 7.1 does NOT build the per-effect operation engine (that is 7.5's call). Confirm no `.tscn`/asset added (UI-scene-last).
  - [ ] Update story Status, sprint-status, and Completion Notes (the dev record + the `[Decision]`s).

## Dev Notes

### The big picture: this is the story that makes Epic 6 FELT
Epic 6 deliberately shipped **OUTCOME-RECORD-ONLY**: gold rewards, Destroy outcomes, and consumable-use all *record* a marker via an event but mutate NO domain field, **because no live wallet/HP/curse field existed**. The retro (Action Item T1, HIGH) names 7.1 as the owner of introducing that field and wiring the gold credit off the existing `reward_resolved` hook. So the headline of 7.1 is: **introduce `RiskEconomyState` + credit gold off `reward_resolved.category == gold`.** Everything else (curse rules, event rolls, affinities) is a later Epic-7 story. [Source: `epic-6-retro-2026-06-29.md` §7 + §8 T1; `project-context.md` "OUTCOME-RECORD-ONLY IS THE EPIC-6 v0 POSTURE"]

### Reuse, do NOT reinvent — the exact precedents to copy
- **The additive-lenient `RunState` field**: copy the 6.2 `inventory` field verbatim (`run_state.gd:83-93` for the field doc, `:117/:129` constructor default, `:225` `to_dictionary`, `:249` deep-copy in `copy()`, `:327` lenient decode in `try_from_dictionary`). `RiskEconomyState` is the next field of exactly that shape. [Source: `godot/scripts/run/run_state.gd`]
- **The value object**: copy `StartingKit`/`InventoryState` — exact-key `to_dictionary()` (`DICTIONARY_KEYS` const pinned by test), lenient `try_from_dictionary` (no reject path), deep `copy()`. Counts are small bounded ints (NO decimal-string encoding). [Source: `godot/scripts/run/starting_kit.gd`, `godot/scripts/run/inventory_state.gd`]
- **The run command**: copy `ResolveRewardCommand`/`PickupItemCommand` — extends `game_command.gd`, takes `RunState` directly, `sequence_id <= 0` rejected FIRST, validate-then-mutate, `_invalid_context` for the not-a-run / invalid-run cases, ZERO events + byte-identical run on reject. [Source: `godot/scripts/core/commands/resolve_reward_command.gd`]
- **The append-only SYSTEM event**: copy the 6.7 `item_consumed` wiring (it is DETERMINISTIC, no RNG provenance — the exact shape for a deterministic economy event). Touch-points: enum end, `EVENT_ID_*`, factory, validator, both id-maps, `expected_ids` pin. [Source: `godot/scripts/core/events/domain_event.gd:321-337` (factory), `:944-961` (validator), `:1523/:1583` (id maps); `godot/tests/unit/core/test_domain_event.gd:1583-1623` (`expected_ids` pin)]
- **The gold hook**: the `gold` category no-op in `ResolveRewardCommand.execute` (`resolve_reward_command.gd:130-131`) is the exact RESOLVE-time replace-point (credit the already-rolled amount, ZERO new RNG). The `item_gained` distinct-`sequence_id + 1` pattern (`:120`) is how to emit a second event with a unique id. The GENERATE-time gold roll goes in `RunOrchestrator.generate_reward_offer` (`run_orchestrator.gd:294-311`) alongside the existing offer draw, stored on the `RewardOffer` (`reward_offer.gd` — add an additive `gold_amount` field next to the existing `roll`/`draw_index`/`state_after`). [Source: `godot/scripts/core/commands/resolve_reward_command.gd`, `godot/scripts/run/run_orchestrator.gd`, `godot/scripts/run/reward_offer.gd`, `godot/scripts/content/definitions/gold_reward_definition.gd`]

### SAVE STRATEGY — the one genuinely-new decision (read carefully)
AC1 requires economy in **save snapshots** — unlike Epic 6, where inventory/offer rode ONLY the full `RunState.to_dictionary()` and were deliberately kept OUT of the route-position save. There are TWO existing save surfaces and TWO ways economy reaches them:

- **The `RunSnapshot` already has the economy top-level keys.** `RunSnapshot` declares `gold: int`, `oath_shards: int`, `corruption: int`, `curses: Array[String]` (plus `passives`/`inventory`/`equipment`/`affinities`/`meta_progression`) — all CURRENTLY inert placeholders defaulted to 0/`[]`/`{}`, all ALREADY inside the pinned **23-key gate** (`run_snapshot.gd:32-40,62-66,97-101`; the 23-key list at `test_run_snapshot.gd:251-261`). So persisting economy does NOT need a new top-level key — populate the EXISTING placeholders. [Source: `godot/scripts/save/snapshots/run_snapshot.gd`]
- **BUT the route-position resume bridge does NOT carry them today.** `RunState.to_run_snapshot_fields()` emits only 6 run/route fields (root_seed, is_manual_seed, meta_progression_eligible, route_state-with-nested-run_phase+selected_class_id, current_route_node_id, revealed_route_node_ids — `run_state.gd:265-294`), and `RunResumeService.resume_route_position` rebuilds the `RunState` from only those same 6 fields (`run_resume_service.gd:110-121`). The top-level `RunSnapshot.gold`/etc. are parsed but NEVER fed back into the restored `RunState`.

**Two implementation options:**
1. **(RECOMMENDED) Nest economy under `route_state`** — the PROVEN `run_phase` (4.3) / `selected_class_id` (5.3) pattern. Add a `RunState.RISK_ECONOMY_KEY` const, nest the economy dict inside the `route_state` payload in `to_run_snapshot_fields()`, and read it back in `try_from_run_snapshot_fields()` (lenient, default empty for a pre-7.1 save). This threads economy through the route-position save/resume **end-to-end** (the way the class id survives a between-node resume), keeps the 23-key gate green untouched (it is nested, not a new top-level key), and is the pattern project-context explicitly ratifies ("nest run-progression fields under `route_state`; never flatten a new top-level `RunSnapshot` key"). The top-level `RunSnapshot.gold`/`curses`/etc. MAY ALSO be populated from the economy (so the snapshot is human-readable + the Epic-8 run-summary can read them), but the **source of truth on resume is the nested copy**. This is the cleanest fit and is what the retro's "compose into existing nested `route_state` mechanism where possible; do not fork a parallel save format" directs.
2. (Alternative) Populate the top-level `RunSnapshot` economy keys AND extend `to_run_snapshot_fields()` + `resume_route_position`'s 6-field bridge to carry them. This uses the existing top-level keys but requires touching the resume bridge's field list. More surface, and it spreads economy across both nested and top-level — prefer option 1.

**Whichever you choose:** the 23-key COUNT stays 23 (no new top-level key), the two no-surprise-key tests' default-value assertions WILL flip and must be updated deliberately (Task 6), and you MUST add the pre-7.1-save-back-compat + JSON-round-trip migration tests. Keep the `route_position_seed_mismatch` cross-check intact (compose + resume). Record the chosen option as a `[Decision]`.

### Named RNG — economy draws ZERO RNG (but mind the inert-stream residual)
A credit/spend/heal is a **recorded amount, not a roll** — the economy command and the gold-credit wire-off draw ZERO RNG (deterministic, like `item_consumed`). Grep-confirm no `randi`/`randf`/`RandomNumberGenerator` in any new command. [Source: project-context "Determinism & Simulation Rules"]

The **4.6 inert run-level `RngStreamSet`** carried deferral (owner Epic 6/7/9) is RELEVANT context but NOT 7.1's to close: Epic 6 closed the *reward-draw* half (reward rolls now thread `RunOrchestrator.streams`); the `LevelGenerator.generate`-injection half and any *new* run-affecting draw remain. **7.1 introduces no new RNG draw site, so it does not bind this** — but the FIRST Epic-7 story to ROLL (likely **7.3** event choices via the `events` stream, or **7.4/7.5** affinity assignment via level-gen) MUST route through `RunOrchestrator.streams`. If 7.1's economy command is ever extended to a *gambling*-style random outcome, that draw MUST go through the named `rewards`/`events` stream via the run-level set — but no AC here requires it. [Source: `deferred-work.md` "code review of 4-6" T2 entry; `epic-6-retro` §7 prep item 4]

### What stays UNTOUCHED (scope fences — confirm in Completion Notes)
- `scripts/rules/{conditions,operations}` stay EMPTY (0 `.gd`). The per-effect operation engine / combat hook sites are 7.5's call (retro T2). Do NOT author them. [Source: `project-context.md`; `epic-6-retro` §8 T2]
- No `RewardOffer` / `RewardTableDefinition` / `RngStreamSet.required_streams()` / generator-fingerprint / route-fingerprint change. No `.tscn`/asset (UI-scene-last — the economy HUD is a later story).
- The append-only event enum: NEVER renumber an existing member; only append at the end.
- Difficulty is a HARD non-goal: nothing in economy state may be a difficulty knob, and no economy field scales enemy stats/run length. [Source: project-context "DIFFICULTY IS A HARD NON-GOAL"]

### Deferred-work items that overlap this story (from `deferred-work.md`)
- **T1 (the Epic-6 outcome-record → felt wire-off, owner Epic 7 / 7.1):** apply the live gold-wallet credit off `reward_resolved`. **Addressed by Task 5** (note: this also requires GENERATE to finally ROLL the concrete gold amount within the `GoldRewardDefinition` band — Epic 6 stored gold by-id only and never rolled it; Task 5 rolls it at GENERATE through the run-level `rewards` stream and credits the rolled amount deterministically at RESOLVE). The heal/ward/burst (off `item_consumed`) and cleanse/curse (off `passive_destroyed`) halves are this same wire-off family — Task 5 does the GOLD half (purely economic); the heal/curse halves default to 7.2 (curse) / the heal-availability disposition noted in the scope boundary. [Source: `deferred-work.md` "Tracked from: dev of 6-6"/"dev of 6-7" NEW-owner-Epic-7 entries; `epic-6-retro` §8 T1]
- **The 4.6 inert run-level `RngStreamSet` (Med, owner Epic 6/7/9):** NOT closed here (7.1 draws no RNG). Flagged so 7.1 does not regress determinism and the later rolling story (7.3/7.4/7.5) owns the `LevelGenerator.generate`-injection half. **Knowingly worked around** (no new draw site). [Source: `deferred-work.md` "code review of 4-6" T2]
- **The event-id-map exhaustiveness pin (6.7 Round-1 Low, owner = next story touching `domain_event.gd` = THIS story):** **Addressed by Task 4** (add the `expected_ids.size()`-vs-enum-count assertion). [Source: `deferred-work.md` "code review of 6-7" Round 1; `epic-6-retro` §8 T3]
- **`GenerationResult.seed` success-path split (Low, owner = next story touching `GenerationResult`):** NOT this story — 7.1 does not touch `GenerationResult`. Leave parked. [Source: `deferred-work.md` "code review of 3-7"]
- **`warding_salve` un-rollable / consumable-frequency tuning (Low, Epic 10):** NOT this story. [Source: `deferred-work.md`]

### Project Structure Notes
- New value object → `godot/scripts/run/risk_economy_state.gd` (the run-progression domain home, alongside `starting_kit.gd`/`inventory_state.gd`).
- New command(s) → `godot/scripts/core/commands/` (run-domain commands live with the tactical commands, NOT under `scripts/run/` — the 4.x ratified placement).
- New event(s) → appended in `godot/scripts/core/events/domain_event.gd`.
- Tests → `godot/tests/unit/run/` (state) + `godot/tests/unit/core/` (command + event) + `godot/tests/unit/save/` (save round-trip/migration), mirroring the domain. The headless runner auto-discovers `test_*.gd` under `res://tests/unit` and `res://tests/integration` only.
- No conflicts with the unified structure; all files land in existing domain folders.

### Project Context Rules (extracted from `project-context.md` — the rules this story's domain MUST follow)
- **Run-command idiom (4.3, ratified):** take `RunState` directly (no `RunActionContext` wrapper); caller supplies `sequence_id`; reject `sequence_id <= 0` FIRST; validate-then-mutate; structured `ActionResult.error` with ZERO events + byte-identical no-mutation on reject; build the success event only AFTER the mutation. ONE stable top-level error code per failure class; the precise reason in `metadata`, never embedded in a lower_snake error code.
- **Additive-lenient `RunState` field:** new field defaults cleanly, is NOT a required `validate()` field, new constructor param LAST, rides the full `to_dictionary()`/`try_from_dictionary` lenient-read; `copy()` deep-copies mutable containers.
- **Save/snapshot:** snapshots are pure reads (NO RNG draw, NO command, NO mutation on compose/restore). Do NOT add a new top-level `RunSnapshot` key for run-progression state — nest under `route_state` (the pinned 23-key gate). ALWAYS JSON-round-trip snapshots in tests (`JSON.stringify` -> `parse_string`). Restore exposes NO partial corrupt state. Schema changes need migration tests. Small bounded ints (gold/healing/curse counts) stay numeric — only RNG `root_seed`/`state` need decimal-string encoding.
- **Named RNG:** gameplay-affecting randomness uses its assigned stream (`rewards`/`events`/...); cosmetic randomness cannot affect outcomes. (Economy draws none.)
- **Events:** successful commands emit deterministic past-tense `DomainEvent` records; new run-domain events are SYSTEM events (no actor) appended at the enum END (never renumbered), wired end-to-end (factory + payload validator + both id maps + round-trip + malformed tests + `expected_ids` pin).
- **Rules kernel:** `scripts/rules/{conditions,operations}` stay EMPTY scaffolding (the per-effect operation engine is later); the `RulesResolver` is a pure read (no RNG, no command, no tactical mutation).
- **Difficulty is a hard non-goal:** no economy field may scale enemy stats/HP/damage/rewards/RNG/run length.
- **Headless:** tests run without rendering/audio/UI scenes/presentation nodes. Run via PowerShell (`godot` is not on the Bash PATH).
- **Naming:** `snake_case` files, `PascalCase` classes (`RiskEconomyState`), `UPPER_SNAKE_CASE` consts, imperative command names, past-tense event names, lower_snake content/marker ids.

### References
- [Source: `_bmad-output/planning-artifacts/epics.md#Story 7.1: Risk Economy State` (lines 1867-1888) — the AC]
- [Source: `_bmad-output/planning-artifacts/epics.md` lines 453-459 — Epic 7 objective + FR54-FR58 + "explicit enough for player understanding and deterministic enough for replay and save/resume"]
- [Source: `_bmad-output/planning-artifacts/gdds/gdd-Game-2026-05-31/gdd.md` lines 443-471 — Economy and Resources: gold/healing/curses/Oath Shards MVP intent + risk examples]
- [Source: `_bmad-output/planning-artifacts/gdds/gdd-Game-2026-05-31/gdd.md` lines 264-281 — meta-currency Oath Shards: awarded only after run end, only in eligible non-manual-seed runs]
- [Source: `_bmad-output/implementation-artifacts/epic-6-retro-2026-06-29.md` §7 (Epic 7 prep), §8 (Action Items T1/T2/T3) — the epic-transition prep folded into this story]
- [Source: `_bmad-output/implementation-artifacts/deferred-work.md` — the overlapping deferrals (T1 wire-off, inert-stream residual, event-id-map exhaustiveness)]
- [Source: `project-context.md` — run-command idiom, additive-lenient field, save/23-key gate, named RNG, append-only events, difficulty non-goal]
- [Source: `godot/scripts/run/run_state.gd`, `godot/scripts/run/inventory_state.gd`, `godot/scripts/run/starting_kit.gd` — the field + value-object precedents]
- [Source: `godot/scripts/core/commands/resolve_reward_command.gd` — the run-command + the gold-hook replace-point]
- [Source: `godot/scripts/core/events/domain_event.gd`, `godot/tests/unit/core/test_domain_event.gd` — the append-only event wiring + the `expected_ids` pin to extend]
- [Source: `godot/scripts/save/snapshots/run_snapshot.gd`, `godot/tests/unit/save/test_run_snapshot.gd`, `godot/tests/unit/save/test_run_route_position_save.gd`, `godot/scripts/save/run_resume_service.gd` — the 23-key gate + the route-position save/resume bridge to extend]

## Dev Agent Record

### Agent Model Used

(to be filled by dev-story)

### Debug Log References

### Completion Notes List

### File List
