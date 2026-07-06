---
baseline_commit: 4902fe2ac66ef5d8fa32e92b6bd3c367b93ad852
---

# Story 11.6: Meta Spend and Unlock Application

Status: review

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a player,
I want to spend what I earn and feel meta progress apply,
so that descents feed a shallow but real progression loop.

## Story Type & Scope Boundary (READ FIRST)

**This IS a CODE story — the FINAL story of Epic 11 and the culmination of the cross-run meta layer.** Every prior
meta story (8.3 award, 8.4 merge, 8.5/9.4 latches, 8.6 outpost VM, 8.7 save/load tests, 11.5 outpost SCENE + reveal
render) deliberately deferred the SPEND/APPLICATION half. This story closes it: it AUTHORS the FIRST command(s) that
**spend** the accumulated `profile.oath_shards` (and/or apply an `unlock_progress`-gated effect), persists the spend
through `ProfileRepository`, and wires the **profile → class-selectability** path so an unlock actually changes what
`HeroSelectViewModel` reports (FR43 locked-class-hint → real selectability). It is the "spend what I earn and feel meta
progress apply" half of Epic 11.

- **The single most load-bearing as-built fact (VERIFY by reading — this is the crux + the largest new-code surface):**
  the profile→class-selectability wiring **does not exist yet, by explicit design.** `ClassDefinition.lock_state` is a
  **STATIC content field** (`godot/scripts/content/definitions/class_definition.gd:15`) — Necromancer/Shadeblade are
  hardcoded `LOCK_STATE_LOCKED` in `ClassRepository._baseline_definitions()`
  (`godot/scripts/content/repositories/class_repository.gd:125-136`). `HeroSelectViewModel`
  (`godot/scripts/ui/view_models/hero_select_view_model.gd`) reads `ClassDefinition.is_selectable()` and **reads NO
  profile** — it takes only a `ClassRepository`. `project-context.md` states this verbatim (line 234): *"AC1's 'class
  unlock states restore correctly' [8.7] does NOT mean a profile->class-selectability wiring exists — v0 has NONE
  (`ClassDefinition.lock_state` is STATIC; `HeroSelectViewModel` reads no profile) ... Do NOT build a deferred
  meta-spend/apply system to satisfy [8.7's] AC."* **11.6 IS that deferred meta-spend/apply system** — 8.7 was told NOT
  to build it because it is THIS story. AC2 requires making `unlock_progress` (or a spend) flip a class from
  locked→selectable, flowing **profile → view model** through repositories/view models, **never through scene-owned
  state.** Decide the seam (below); do NOT bolt profile state onto `ClassDefinition` (a static content Resource).

- **The as-built surfaces 11.6 BINDS to / EXTENDS (read the source; do not re-implement or re-award):**
  - **`ProfileSnapshot`** (`godot/scripts/save/snapshots/profile_snapshot.gd`) — the cross-run profile.
    `SCHEMA_VERSION == 1`. Pinned `DICTIONARY_KEYS = [schema_version, content_version, profile_id, oath_shards,
    last_awarded_run_seed, class_mastery, echoes, unlock_progress, first_death_recorded, first_victory_recorded]`.
    `oath_shards` is a **plain bounded non-negative int** (NOT a seed — no decimal-string encoding). `unlock_progress`
    is a `Dictionary` (Seal-Fragment set under `["seal_fragments"]` + `<track>_unlocked` bool flags + the merge marker
    `["_last_merged_run_seed"]`). `class_mastery` is a per-class accumulating-count `Dictionary`. `echoes` is a
    unique-id `Array[String]`. `fresh(profile_id := "default")` is the recovery default; `copy()` deep-copies; `parse`
    rejects `schema_version != 1` with `unsupported_profile_schema`. **DECIDE whether a spend needs a new
    `ProfileSnapshot` field** (e.g. an `oath_shards_spent` ledger or an `applied_unlocks` set). If yes: it is an
    **ADDITIVE field at `SCHEMA_VERSION == 1` reserved-home style** (the 8.5 first_death / 9.4 first_victory precedent —
    lenient-parsed, `DICTIONARY_KEYS` pin updated, NO version bump), reconciled against 8.7's migration matrix (which
    pins `SCHEMA_VERSION == 1` + `schema_version:2 -> unsupported_profile_schema`). AC3 says: *"no schema bump unless
    justified against the 8.7 migration matrix"* — a bump means a real migrate step + a migration test. Prefer additive
    at v1; if a bump is truly justified, do it deliberately with the migration + tests.
  - **The Epic-8/9 run-end profile-mutation command family (the TEMPLATE for a spend command — mirror it VERBATIM):**
    - `AwardMetaProgressCommand` (`godot/scripts/core/commands/award_meta_progress_command.gd`) — awards Oath Shards.
      `_init(new_profile: ProfileSnapshot, new_summary: RunSummary, new_sequence_id: int)`; `execute(state)` takes the
      terminal `RunState` as `state`; TWO GATES (idempotency via `profile.last_awarded_run_seed`; eligibility via
      `run.meta_progression_eligible` → `run_not_meta_eligible`); mutates `profile.oath_shards` in-place; emits
      `oath_shards_awarded`; ZERO RNG; the CALLER persists via `ProfileRepository.write_profile`. **This is the ADD
      side; 11.6 authors the SPEND side (subtract).**
    - `MergeRunDiscoveriesCommand` (`godot/scripts/core/commands/merge_run_discoveries_command.gd`) — merges discoveries
      into `unlock_progress`/`echoes`/`class_mastery`, computes threshold crossings via `UnlockProgressRules.evaluate`,
      emits `profile_progress_merged`. The RECORD-side of unlock state; 11.6 is the APPLY-side (turn recorded
      `unlock_progress` into a live effect).
    - `RecordFirstDeathCommand` / `RecordFirstVictoryCommand` — the latch twins; `_init(profile, sequence_id)`,
      `execute(terminal RunState)`, `sequence_id <= 0` rejected FIRST, validate-then-mutate, ZERO RNG.
    - **THE SHARED IDIOM every command above obeys (`godot/scripts/core/commands/game_command.gd` base — obey it for a
      spend command):** `_init(...)` takes the profile (+ per-command inputs) + a run-level `sequence_id` via the
      CONSTRUCTOR; `validate(state)` rejects `sequence_id <= 0` FIRST (`invalid_event_sequence_id`) so a success path
      can never emit an event its own validator rejects; validate-then-mutate with **ZERO events + a byte-identical
      no-mutation profile on ANY reject**; the event is built **ONLY AFTER** the mutation; **ZERO RNG** (a spend is a
      deterministic arithmetic subtraction / flag set, NOT a roll). ONE stable top-level error code per failure class
      (the precise reason rides `metadata`).
  - **`UnlockProgressRules`** (`godot/scripts/save/unlock_progress_rules.gd`) — the pure ZERO-RNG capped threshold
    calculator. `SEAL_FRAGMENT_THRESHOLDS` (count 1 → `seal_gate_1_unlocked`, count 3 → `seal_gate_2_unlocked`);
    `SEAL_FRAGMENTS_KEY == "seal_fragments"`; `RAW_STAT_UNLOCK_TOKENS` (`damage`/`max_hp`/`maxhp`/`armor`/`crit`/`dodge`)
    + `is_raw_stat_unlock_key(key)` — the AC3/FR95 structural guard that NO produced unlock key is a raw combat stat.
    `evaluate(unlock_progress)` returns `{thresholds_crossed, state}` (a fresh deep copy — does not mutate input). **If
    11.6 adds new unlock content or a spend-unlockable track, EXTEND this pure calculator (declared const config,
    test-pinned) and keep `is_raw_stat_unlock_key` producing NONE — the capped/sparse GDD-FR95 posture (AC2) is
    non-negotiable.**
  - **`MetaAwardRules`** (`godot/scripts/save/meta_award_rules.gd`) — the award-amount calculator (`BASE_AWARD=1`,
    `PER_NODE_AWARD=1`, `MAX_AWARD=5`). If a spend needs a **cost table** (how many Oath Shards an unlock costs), author
    it as a sibling pure const-config calculator (e.g. `MetaSpendRules` under `godot/scripts/save/`), NOT inline in the
    command — mirror the `MetaAwardRules`/`UnlockProgressRules` posture (declared const, test-pinned, ZERO RNG, does not
    scale by difficulty).
  - **`HeroSelectViewModel`** (`godot/scripts/ui/view_models/hero_select_view_model.gd`) — the class roster projection.
    Pinned per-entry `ENTRY_KEYS = [class_id, display_name, selectable, unlock_hint]`. `classes()` → per-class dicts;
    `is_class_selectable(class_id)` → fail-closed pre-gate (unknown → false, locked → false, selectable → true);
    `selectable_class_ids()` / `locked_class_ids()`. **Constructor is `_init(new_class_repository: ClassRepository =
    null)` — it takes ONLY a repository and reads NO profile.** AC2's "hero select reflects the applied unlock" flows
    THROUGH this VM. Decide the profile-aware seam (below) so `is_class_selectable`/`selectable` become
    profile-aware **without** making `ClassDefinition.lock_state` non-static and without adding scene-owned state.
  - **`ClassDefinition`** (`godot/scripts/content/definitions/class_definition.gd`) + **`ClassRepository`**
    (`godot/scripts/content/repositories/class_repository.gd`) — static content. `lock_state ∈ {LOCK_STATE_SELECTABLE
    ("selectable"), LOCK_STATE_LOCKED ("locked")}`; `is_selectable()` returns `lock_state == LOCK_STATE_SELECTABLE`.
    Baseline: warrior/pyromancer/ranger SELECTABLE, necromancer/shadeblade LOCKED with unlock hints. **DO NOT mutate a
    `ClassDefinition`'s `lock_state` at runtime, and DO NOT store profile state on the definition/repository** (a
    definition is approved static content; per `project-context.md`, procedural/runtime code selects from approved
    static content, it does not rewrite it). The unlock-application seam is a **profile-aware OVERLAY** at the view-model
    layer (below), not a content mutation.
  - **`RunStartCommand`** (`godot/scripts/core/commands/run_start_command.gd`, via `RunOrchestrator.start(root_seed,
    is_manual_seed, class_id)`) — the AUTHORITATIVE fail-closed class gate. Its CLASS gate rejects a non-selectable
    class (`class_not_selectable`) reading `ClassDefinition.is_selectable()`. **If AC2 makes a formerly-locked class
    startable, the authoritative start gate must ALSO honor the unlock** (a UI grey-out is a hint layered on top — the
    command re-validates fail-closed). Decide how `RunStartCommand`'s class gate becomes profile-aware in lockstep with
    `HeroSelectViewModel` (both must agree — a mis-enabled confirm cannot start a still-locked class, and a genuinely
    unlocked class must NOT be rejected by the start command). This is the load-bearing symmetry: the VM affordance and
    the authoritative gate read the SAME unlock source.
  - **`ProfileRepository`** (`godot/scripts/save/profile_repository.gd`) — `read_profile(save_path :=
    "user://profile.json") -> ActionResult` (`profile_not_found` → caller starts `ProfileSnapshot.fresh()`;
    `profile_open_failed`; `profile_parse_failed`; else `ProfileSnapshot.parse(...)` surfacing
    `unsupported_profile_schema`). `write_profile(snapshot, save_path) -> ActionResult` (atomic temp→backup→replace;
    `profile_save_open_failed`/`_backup_remove_failed`/`_backup_failed`/`_replace_failed` on failure; a failed write
    leaves the prior valid profile intact). **There is NO `SaveManager` profile delegator** (Epics 8-9 added none; 11.5
    established that the caller drives `ProfileRepository` directly). A spend command does NOT persist itself — the
    CALLER reads → runs the spend command → writes. Reuse the atomic write + structured errors (AC1 "persist through
    `ProfileRepository`").
  - **The 11.5 run-end→outpost bridge + render surfaces 11.6 EXTENDS (read the source — these are the natural seams the
    spend/apply hooks into, per the Epic-11 retro):**
    - **`RunEndProfileBridge`** (`godot/scripts/ui/flow/run_end_profile_bridge.gd`) — the caller-driven RefCounted seam
      that at run-end LOADS the profile → RECORDs the latch → PERSISTs → BUILDs the `OutpostViewModel`. It is the
      **template for a spend caller**: a spend is likewise load-profile → run-spend-command → persist → rebuild the
      outpost surface. It drives `ProfileRepository` directly + threads `orchestrator.next_sequence_id()` for a unique
      `sequence_id > 0`. **⭐ NOTE its `OutpostViewModel.for_recovery(...)` call has 7 positional args including
      `first_victory_beat` — see the positional-arg trap below.** The bridge does NOT spend today (its class-doc scope
      fence: *"it does NOT drive `AwardMetaProgressCommand`/`MergeRunDiscoveriesCommand` (the 11.6 meta-SPEND/GRANT
      concern)"*) — 11.6 is that concern. Decide: a separate `OutpostSpendBridge`/spend-controller seam the outpost
      presenter drives, or extend `RunFlowController` with a spend method — mirror the caller-driven load→command→persist
      posture; keep the orchestrator unchanged (or add ONE additive read-only accessor like 11.5's `next_sequence_id()`).
    - **`OutpostViewModel`** (`godot/scripts/ui/view_models/outpost_view_model.gd`) — the outpost assembly. Pinned
      `DICTIONARY_KEYS = [has_profile, recovery_state, oath_shards, echoes, unlock_progress, class_mastery,
      first_death_recorded, run_summary, class_options, selectable_class_ids, named_spaces, first_death_beat,
      first_victory_beat, can_start_run]`. It DISPLAYS `oath_shards`/`unlock_progress`/`class_mastery`/`class_options`/
      `selectable_class_ids` (read from the profile as source truth). **⭐ POSITIONAL-ARG TRAP (from 11.5, ratified in
      the Epic-11 retro):** `_init(profile, run_summary, first_death_beat, first_victory_beat, class_repository,
      new_recovery_state)` — `first_victory_beat` was inserted at **position 4** in 11.5, shifting `class_repository`→5,
      `new_recovery_state`→6. `for_recovery(recovery_code, loaded_profile=null, run_summary=null, first_death_beat=null,
      class_repository=null, is_recoverable=true, first_victory_beat=null)` — `first_victory_beat` is the TRAILING
      position-7 optional. Any NEW `OutpostViewModel.new(...)`/`.for_recovery(...)` caller 11.6 adds MUST bind these
      positions correctly (and if 11.6 threads the applied-unlock state through the outpost, prefer to display it via
      the EXISTING `unlock_progress`/`class_options`/`selectable_class_ids` keys rather than adding another positional
      arg — every added positional arg re-shifts callers). If a new pinned key is genuinely needed, update
      `test_outpost_view_model.gd`'s pinned-key set + EVERY construction in the test.
    - **`OutpostRenderView`** (`godot/scripts/ui/view_models/outpost_render_view.gd`) — the RefCounted render-decision
      seam the presenter reads (the retro G1/G2 posture: put ALL testable render logic here, NOT in the `Control`). It
      exposes `awarded_oath_shards()`, `named_space_markers()`, `recovery_mode()`, etc. **The spend UI's render
      decisions (can-afford, spend-confirm state, unlock-applied marker, insufficient-shards message) belong HERE as a
      testable RefCounted seam**, not in `outpost_presenter.gd`. `from_view_model(view_model)` builds it from an
      `OutpostViewModel`.
    - **`outpost_presenter.gd`** (`godot/scripts/ui/presenters/outpost_presenter.gd`) — the outpost `Control` scene
      (`godot/scenes/ui/outpost.tscn`). It renders the meta readout, the four `named_spaces` (each with a "coming soon"
      deferred marker), the run summary, the reveal beats, the recovery banner, and the "Descend Again" affordance. **The
      shallow meta menu / spend affordance (AC1, FR59) is the natural add here** — the `seal_table` / `hall_of_oaths`
      named-space tiles are the GDD homes for Seal-Fragment/unlock and Oath-Shard/mastery spend respectively (they carry
      `status: "deferred"` today). It MIRRORS `route_map_presenter`/`hero_select_presenter`: READs a pinned VM/render-view
      projection, MAPs to non-color visuals, SUBMITs intent through an existing seam, OWNs no truth, LEAKs no live
      handle. **A spend button submits a spend REQUEST that a caller (bridge/controller) turns into the validated spend
      command → persist → re-render** — the presenter never mutates the profile directly.
  - **`RunFlowController`** (`godot/scripts/ui/flow/run_flow_controller.gd`) — the scene-free run-flow sequencer.
    Exposes `run()`, `orchestrator()`, `start(root_seed, is_manual_seed, class_id)`, `finalize_run_end(bridge)`. It is
    where a spend-flow seam (if controller-hosted) would live. **`RunOrchestrator.next_sequence_id()`
    (`godot/scripts/run/run_orchestrator.gd:885-886`) is the read-only cursor** a spend command's caller threads for a
    unique `sequence_id > 0` (it does NOT advance the counter — a pure peek).
  - **`DomainEvent`** (`godot/scripts/core/events/domain_event.gd`) — the append-only event vocabulary. **If a spend
    emits a new event** (e.g. `oath_shards_spent` / `unlock_applied`), it is an **APPEND-ONLY SYSTEM event (no actor)**
    wired END-TO-END (see the fail-loud-on-new-event constraint below): add the `Type` enum member at the TAIL (current
    tail is `BOSS_DEFEATED`, enum index 47), a `EVENT_ID_*` const, a factory function, a `_validate_payload_for_event`
    match arm, a `_validate_*_payload` validator (mirror `oath_shards_awarded`'s honest-record arithmetic —
    `before - amount == after` for a spend, non-negative floors), AND the exhaustive `expected_ids` pin in
    `test_domain_event.gd` (or the enum-count assertion fails loud — see below). A spend is DETERMINISTIC (ZERO RNG — no
    `roll`/`draw_index`).
  - **Approved treatment baseline (already merged to `main`; bind id/tag hooks, author NO new art):** the Recraft
    UI-frame kit (button/panel/modal) is the frame baseline for the outpost/meta menu (appendix §14.3). Icons are
    placeholder-id sentinels the modal/menu binds, not textures.

- **What 11.6 delivers (three AC groups — see Acceptance Criteria for verbatim ACs):**
  1. **Spend command(s) + persistence (AC1, FR59).** A validated run-domain spend command (mirroring the Epic-8
     idiom) subtracts `profile.oath_shards` (and/or consumes an unlock resource), emits a deterministic domain event,
     and the caller persists through `ProfileRepository.write_profile`. **Manual-seed-earned progress stays excluded
     end-to-end (FR28)** — but note the eligibility model is on the AWARD side (a manual-seed run never AWARDED shards);
     see the FR28 nuance below.
  2. **Unlock application → class selectability (AC2, FR43/FR95).** An unlock whose requirements are met applies its
     effect so hero select reflects it (locked-class hint → actual selectability), flowing **profile → class
     selectability through repositories/view models, never scene-owned state**, with meta power staying **capped and
     sparse** (FR95 posture — no raw-stat ladder; `is_raw_stat_unlock_key` produces none).
  3. **Save/load + migration + idempotency (AC3).** The profile round-trips the new spend state **additively** (no
     schema bump unless justified against the 8.7 migration matrix), and **idempotency + caller-ordering safety match
     the run-end command family's standards** (a spend command is idempotent-safe / order-safe alongside the
     award/merge/first-death/first-victory markers).

- **What 11.6 does NOT do (hard scope fences — do not cross):**
  - **No re-award / no re-merge.** 11.6 SPENDs what 8.3 awarded + APPLIEs what 8.4 recorded — it does NOT change the
    award amount (`MetaAwardRules`), the award/merge commands, the award/merge idempotency markers, or the discovery
    source. It reads `profile.oath_shards`/`profile.unlock_progress` as accumulated state and consumes/applies them.
  - **No live in-run discovery source.** v0 has NO live path that EMITS a `content_discovered` event during a hands-off
    run (combat auto-resolves; grep-verified: `content_discovered` is referenced in only 3 scripts — `domain_event.gd`
    (the factory), `merge_run_discoveries_command.gd` (the CONSUMER that scans a caller-supplied event list), and
    `run_summary.gd` (the reader) — NO orchestrator/resolver/command PRODUCES it in the live flow) — so `unlock_progress`
    is populated ONLY by a caller-/test-supplied discovery-event list to `MergeRunDiscoveriesCommand`. **Consequence for AC2:** the unlock-application path is exercisable **in tests**
    (seed a profile with `unlock_progress` crossings, or drive a merge with fixture discovery events) and its VM/gate
    wiring is real, but a hands-off live run never earns a Seal Fragment on its own. Do NOT add a live discovery source
    (that is a later story). Prove AC2 by seeding the profile state a merge would have produced.
  - **No new content pipeline / no new content family.** Echo/Seal-Fragment/mastery/unlock content is tracked BY ID
    (no roster/repository; `project-context.md`). If a spend needs a cost/unlock config, it is a **code-constant pure
    calculator** (the `MetaAwardRules`/`UnlockProgressRules` template), NOT a `.tres`/JSON pipeline and NOT a new
    `*Repository`.
  - **No new autoload.** Epics 8-9-11.5 added none. The spend caller drives `ProfileRepository` directly (like 11.5's
    bridge). Keep `SceneManager`/`GameSession`/`SaveManager` thin.
  - **No difficulty knob; no raw-stat unlock.** Meta power is capped/sparse variety/options (FR95) — NEVER a repeatable
    combat stat (`damage`/`max_hp`/`armor`/`crit`/`dodge`). No difficulty selector anywhere.
  - **No `ClassDefinition.lock_state` mutation; no scene-owned unlock state.** The applied-unlock effect is a
    profile-aware overlay at the view-model/gate layer, NOT a mutation of approved static content and NOT a flag on a
    scene/`Control`.
  - **No new RNG stream / no new fingerprint / no run save-shape change.** The 7 named RNG streams stay 7; the 23-key
    `RunSnapshot` gate stays 23 (a spend touches the PROFILE, not `RunSnapshot` — the profile is its OWN
    `ProfileSnapshot`/`ProfileRepository`); every generator/route/finale seed-regression fingerprint stays
    byte-identical (11.6 draws ZERO RNG and touches no generator). A `ProfileSnapshot` field addition is the ONLY save
    surface that MAY change (additively, per AC3).
  - **No in-run/mid-encounter save; no affinity/combat work.** Out of scope (those are 11.4 / a later in-node-save
    story).

## Acceptance Criteria

Sourced verbatim from `epics.md` (Epic 11, Story 11.6, lines ~2725-2746). Three AC groups (Given/When/Then + And):

1. **Spend command(s) + persistence (AC1).** GIVEN the profile holds Oath Shards and unlock progress, WHEN I spend at
   the outpost's shallow meta menu (FR59), THEN spend operations run as validated commands that emit deterministic
   domain events and persist through `ProfileRepository` — AND manual-seed-earned progress remains excluded end-to-end
   (FR28).

2. **Unlock application → class selectability (AC2).** GIVEN an unlock's requirements are met and its effect applied,
   WHEN hero select next renders, THEN the applied unlock is reflected (locked-class hint → actual selectability path
   per FR43), with meta power staying capped and sparse per the ratified GDD FR95 posture — AND the application flows
   profile → class selectability through repositories/view models, never through scene-owned state.

3. **Save/load + migration + idempotency (AC3).** GIVEN spends and applications exist, WHEN save/load and migration
   tests run, THEN profile round-trips cover the new spend state additively (no schema bump unless justified against
   the 8.7 migration matrix) — AND idempotency and caller-ordering safety match the run-end command family's standards.

### AC Verification (how "done" is checked)

- **AC1 —** a run-domain spend command under `godot/scripts/core/commands/` (mirroring `AwardMetaProgressCommand`
  VERBATIM: `_init(profile, ..., sequence_id)`; reject `sequence_id <= 0` FIRST → `invalid_event_sequence_id`;
  validate-then-mutate; ZERO events + byte-identical no-mutation profile on ANY reject; event built ONLY after mutation;
  ZERO RNG). It **fail-closes an unaffordable spend** (insufficient Oath Shards → a stable error, e.g.
  `insufficient_oath_shards`, with the shortfall in `metadata`; ZERO mutation) and, on success, subtracts
  `profile.oath_shards` (and/or consumes the unlock resource) and emits a deterministic event. The CALLER persists via
  `ProfileRepository.write_profile` (the caller-driven load→spend→persist seam — a bridge/controller, mirroring 11.5's
  `RunEndProfileBridge`; the presenter submits a spend REQUEST, not a raw command). Verified by: (a) a unit test that a
  valid spend subtracts the exact amount + emits the event + the profile round-trips; (b) an unaffordable spend rejects
  with the stable code + ZERO mutation + ZERO event; (c) the caller-seam test that load→spend→persist round-trips
  through a throwaway `ProfileRepository` path; (d) FR28 — see the nuance below (a manual-seed run awarded 0 shards, so
  there is nothing manual-seed-earned to spend; assert the award path denied a manual-seed run, and that a spend cannot
  fabricate shards).
- **AC2 —** the profile→class-selectability seam (DECIDE ONE, record it in Completion Notes — see "The AC2 seam
  decision" below). `HeroSelectViewModel` (and the authoritative `RunStartCommand` class gate) become **profile-aware**
  so a class whose unlock requirement is met (via `profile.unlock_progress`/`profile.class_mastery`/a spend) reports
  `selectable: true` (and `is_class_selectable` → true, and `RunStartCommand` no longer rejects it), WITHOUT mutating
  `ClassDefinition.lock_state` and WITHOUT scene-owned state. Meta power is capped/sparse: the unlock flips a VARIETY
  gate (a class becomes selectable), NEVER a raw combat stat — `UnlockProgressRules.is_raw_stat_unlock_key` produces
  none, and any unlock config 11.6 adds is asserted to carry no raw-stat key. Verified by: (a) a unit test that with an
  unlock requirement met, the profile-aware `HeroSelectViewModel` reports the formerly-locked class `selectable: true` +
  `is_class_selectable(class_id) == true`, while a profile WITHOUT the unlock still reports it locked; (b) a test that
  the authoritative `RunStartCommand` (via `RunOrchestrator.start`) STARTS the unlocked class and still REJECTS the
  locked one (fail-closed symmetry — the VM affordance and the gate agree); (c) a structural assertion that no raw-stat
  unlock key is produced (FR95). **Do NOT** satisfy AC2 by mutating a `ClassDefinition` or by reading the profile inside
  a scene.
- **AC3 —** the profile save/load + migration + idempotency:
  - **Additive round-trip:** if 11.6 adds a `ProfileSnapshot` field (spend ledger / applied-unlock set), it rides
    `to_dictionary()`/`parse`/`copy()`/`fresh()` (lenient decode — a pre-11.6 dict defaults it cleanly), the pinned
    `DICTIONARY_KEYS` + `test_profile_snapshot.gd` are updated, and a JSON round-trip test proves it survives
    (`JSON.stringify` → `parse_string`, per the save-testing rule; int-coercion-aware if it's a nested int dict — the
    8.7 lesson). **`SCHEMA_VERSION` stays 1** (additive at v1, reconciled with 8.7's `schema_version:2 ->
    unsupported_profile_schema` pin) UNLESS a bump is truly justified — then a real `migrate` step + a migration test
    (the 8.7 matrix owns the pattern).
  - **Idempotency + caller-ordering:** the spend command is idempotent-safe / order-safe alongside the FOUR existing
    run-end markers (award `last_awarded_run_seed`; merge `unlock_progress["_last_merged_run_seed"]`; first-death
    `first_death_recorded`; first-victory `first_victory_recorded`) — a spend must NOT read/write any of those four, and
    an unlock APPLICATION must be idempotent (re-applying an already-applied unlock is a no-op, not a double-effect — a
    class already selectable stays selectable; a spend already made is not re-charged). **DECIDE the spend idempotency
    mechanism** (a spend is fundamentally different from the run-end markers: it is a PLAYER-INITIATED repeatable action,
    not a once-per-run/once-per-lifetime latch — a player may spend multiple times). The idempotency requirement is
    about **the APPLICATION being idempotent** (applying an unlock twice does not double-unlock) and **the spend command
    being safe under retry** (a persist-failure retry does not double-charge), NOT about blocking a second legitimate
    spend. Record the mechanism. Verified by: an idempotency test (re-apply/retry is a no-op) + a caller-order test (a
    spend interleaved with the award/merge/latch commands leaves each independent and correct) + the additive round-trip
    test.
- **AC-wide (the spend/apply BRIDGE — mirror 11.5's crux):** a caller-driven seam (a spend bridge/controller the
  outpost presenter drives) LOADS the profile (`ProfileRepository.read_profile` → `fresh()` on `profile_not_found`),
  runs the spend/apply command threaded with `orchestrator.next_sequence_id()` (or `1` if no orchestrator — a spend at
  the outpost may have no live run; decide the sequence-id source: a fresh monotonic source, or `1` for the
  no-live-run case, keeping `sequence_id > 0`), PERSISTs via `ProfileRepository.write_profile` (handling a
  `profile_save_*` write failure with the same recovery posture 11.5 uses — real totals behind a retry banner, NEVER a
  silent swallow), and REBUILDs the outpost surface (the meta readout / class options reflect the spend). This bridge is
  the seam a headless test drives end-to-end. Test the SHARED bridge/apply seam (the retro H1 discipline — a presenter
  re-implementing a sequencing the domain encodes must test the shared seam), not just the individual command.
- **AC-wide (invariants) —** full headless suite green (`godot --headless … test_runner.tscn`), false-PASS grep clean
  beyond the 6 documented negatives (int64-overflow ×2, malformed-JSON ×3, `invalid_node_type` ×1 — plus any NEW
  documented negative 11.6 adds, e.g. a `profile_save_*` forcing case, which MUST be documented in the story + the
  ledger); `git diff --check` clean. `RunSnapshot` 23-key gate == 23; `SettingsSnapshot.SCHEMA_VERSION == 1`;
  `RngStreamSet.required_streams()` == 7; every `tools/dump_*` seed-regression fingerprint byte-identical; the DEFAULT
  `run_to_completion` (v0 auto-resolve) byte-identical. `ProfileSnapshot.SCHEMA_VERSION` stays 1 (unless a justified
  bump — then the migration test proves it). `domain_event.gd` changes ONLY if a spend event is added (append-only,
  wired end-to-end incl. `expected_ids`).

## Tasks / Subtasks

- [x] **Task 1 — Author the spend command (AC1; the run-domain mutation)**
  - [x] Add the spend command under `godot/scripts/core/commands/` (e.g. `spend_oath_shards_command.gd` — imperative
        name), extending `game_command.gd`, mirroring `AwardMetaProgressCommand` VERBATIM in shape: `_init(profile,
        <spend inputs>, sequence_id)`; `validate(state)` rejects `sequence_id <= 0` FIRST; validate-then-mutate; ZERO
        events + byte-identical no-mutation profile on ANY reject; event built ONLY after mutation; ZERO RNG. The `state`
        arg: a spend at the outpost is NOT tied to a terminal `RunState` (unlike the award/merge/latch, which take the
        terminal run). DECIDE the `state` contract — the profile + spend inputs are the real context; the `state` arg
        may be unused/null (the `RunStartCommand` "state unused" precedent) or carry a minimal spend-context. Record the
        decision.
  - [x] Fail-close an unaffordable spend: `profile.oath_shards < cost` → a stable error (e.g. `insufficient_oath_shards`)
        with the shortfall in `metadata`, ZERO mutation, ZERO event. On success subtract `profile.oath_shards` (floor at
        0 — a spend never drives a negative total) and record the applied effect (an unlock flag in `unlock_progress`,
        or the new applied-unlock field — see Task 2/3).
  - [x] Cost config: if a spend has a cost, author a pure const-config calculator (`MetaSpendRules` under
        `godot/scripts/save/`, the `MetaAwardRules`/`UnlockProgressRules` template — declared const, test-pinned, ZERO
        RNG, does not scale by difficulty). Do NOT hardcode the cost inline. Keep it capped/sparse (FR95).
  - [x] Emit the spend event (decide: a NEW `oath_shards_spent`/`unlock_applied` SYSTEM event, OR reuse an existing one
        — but the award/merge events are the ADD side and do not fit a SPEND record honestly; a new event is the likely
        correct choice). If new: append at the `DomainEvent.Type` enum TAIL (after `BOSS_DEFEATED`), add the
        `EVENT_ID_*` const + factory + `_validate_payload_for_event` arm + validator (honest-record arithmetic:
        `before - amount == after`, non-negative floors, mirroring `oath_shards_awarded`'s `before + amount == after`),
        wire BOTH id maps, add JSON round-trip + malformed-negative tests, AND **add it to `expected_ids` in
        `test_domain_event.gd`** (the enum-count assertion `expected_ids.size() == Type.size() - 1` FAILS LOUD otherwise
        — see the fail-loud-on-new-event constraint). ZERO RNG (no `roll`/`draw_index`).
  - [x] Unit-test the command: valid spend (subtract + event + profile round-trip), unaffordable reject (stable code +
        ZERO mutation + ZERO event), `sequence_id <= 0` reject.

- [x] **Task 2 — Wire the profile → class-selectability application (AC2; the crux)**
  - [x] DECIDE the AC2 seam (record it — see "The AC2 seam decision"). The likely-minimal shape: make
        `HeroSelectViewModel` **profile-aware** by accepting an optional `ProfileSnapshot` (or an already-derived
        "applied unlocks" set) so `is_selectable`/`is_class_selectable`/`selectable_class_ids` OR each entry's
        `selectable` field consults the profile's applied-unlock state for a formerly-locked class — WITHOUT mutating
        `ClassDefinition.lock_state`. A locked class becomes selectable iff (static `LOCK_STATE_SELECTABLE`) OR (its
        unlock requirement is met on the profile). Keep the pinned `ENTRY_KEYS` unchanged (the `selectable` field's
        VALUE becomes profile-aware; no new key). If a null profile is passed, behavior is byte-identical to today
        (fail-closed default — every existing caller stays correct).
  - [x] Make the AUTHORITATIVE `RunStartCommand` class gate profile-aware in LOCKSTEP (both read the SAME unlock
        source): a genuinely-unlocked class must START (not `class_not_selectable`), and a still-locked class must still
        REJECT. Thread the profile (or the derived applied-unlock set) into `RunStartCommand`/`RunOrchestrator.start`
        the same way. Preserve every existing call site (the profile is optional/last-arg; a null profile → today's
        static behavior). This symmetry is load-bearing: the VM grey-out is a hint; the command is the gate; they must
        agree.
  - [x] Define the unlock→class mapping (which unlock flag / class-mastery count / Seal-Fragment threshold unlocks which
        class). Necromancer/Shadeblade are the two locked classes (FR43). Author it as pure const config (the
        `UnlockProgressRules`/`MetaSpendRules` template) — capped/sparse, NO raw-stat key
        (`is_raw_stat_unlock_key` produces none). Record the mapping.
  - [x] Idempotent application: re-applying an already-met unlock is a no-op (a class already selectable stays
        selectable; the applied-unlock set is a SET — a duplicate add is not a second unlock). Test it.
  - [x] Unit-test AC2: profile-with-unlock → formerly-locked class `selectable: true` + `is_class_selectable == true`;
        profile-without-unlock → still locked; `RunStartCommand` starts the unlocked class + rejects the locked one; no
        raw-stat unlock key produced.

- [x] **Task 3 — Profile save state + migration + idempotency (AC3)**
  - [x] DECIDE whether the spend/applied-unlock state needs a NEW `ProfileSnapshot` field or fits the EXISTING
        `unlock_progress` dict (e.g. an `applied_unlocks` set OR a `oath_shards_spent` ledger under `unlock_progress`,
        mirroring how Seal Fragments live under `unlock_progress["seal_fragments"]` and the merge marker under
        `unlock_progress["_last_merged_run_seed"]` — a namespaced key inside `unlock_progress` merges WITHOUT a schema
        change and WITHOUT touching `DICTIONARY_KEYS`). PREFER the existing-dict home (no `DICTIONARY_KEYS` change, no
        migration) unless a top-level field is genuinely warranted. If a top-level field IS added: additive at
        `SCHEMA_VERSION == 1` (the 8.5/9.4 precedent — lenient decode, pin `DICTIONARY_KEYS` + `test_profile_snapshot.gd`,
        NO version bump), reconciled with the 8.7 migration matrix. Record the decision.
  - [x] JSON round-trip test (`JSON.stringify` → `parse_string`, per the save-testing rule): the spend/applied-unlock
        state survives a real round-trip; int-coercion-aware if it's a nested int-valued dict (the 8.7 `class_mastery`
        lesson — `{"x": 3} != {"x": 3.0}` across JSON). Extend `test_profile_snapshot.gd` +/or
        `test_meta_summary_save_load.gd` (the 8.7 comprehensive matrix).
  - [x] Idempotency + caller-ordering test: the spend command reads/writes NONE of the four run-end markers; a spend
        interleaved with award/merge/first-death/first-victory leaves each independent + correct; a re-applied unlock is
        a no-op; a persist-failure retry does not double-charge (mirror the 11.5 retry semantics — re-read profile →
        re-run idempotently → re-write).

- [x] **Task 4 — Spend/apply bridge + outpost meta-menu render (AC1/AC-wide; the caller seam + the on-screen surface)**
  - [x] Add the caller-driven spend seam (a `RefCounted` bridge/controller mirroring `RunEndProfileBridge`, OR a
        `RunFlowController` method): LOAD the profile (`ProfileRepository.read_profile` → `fresh()` on
        `profile_not_found`) → run the spend/apply command (threaded `sequence_id > 0`) → PERSIST
        (`ProfileRepository.write_profile`, handling `profile_save_*` write failure with the 11.5 real-totals-behind-retry
        recovery) → REBUILD the `OutpostViewModel` so the meta readout / `class_options` / `selectable_class_ids`
        reflect the spend. Draw ZERO RNG; mutate ONLY the profile. Keep the orchestrator unchanged (or add ONE additive
        read-only accessor).
  - [x] Render the shallow meta menu (AC1, FR59) on `outpost_presenter.gd` (the `seal_table`/`hall_of_oaths` named-space
        tiles are the GDD homes): a spend affordance (≥44×44) that shows the cost + can-afford state, submits a spend
        REQUEST to the bridge (not a raw command), and re-renders on success/failure (an unaffordable spend shows the
        insufficient-shards message, fail-loud — never a silent no-op). Put the spend render DECISIONS (can-afford,
        cost, unlock-applied marker, insufficient message) in the `OutpostRenderView` RefCounted seam (the retro G1/G2
        posture — testable without a SceneTree), NOT in the `Control`. Every meaning carries a non-color channel
        (text/icon/label — appendix §14). The `named_spaces` that gain a live spend affordance flip from `deferred` to a
        live status where realized (decide: keep them `deferred` if the spend menu is a distinct surface, or mark the
        realized space live — record it; do NOT silently leave a live affordance marked `deferred`).
  - [x] Update `test_outpost_render_view.gd` (spend render decisions) + `test_run_flow_scenes_load.gd` if a new
        scene/presenter is added; the scene-load compile guardrail covers any new `.tscn`. NO SceneTree test (the
        Epic-11 scene-free-harness constraint — the render DECISION lives in the RefCounted seam).

- [x] **Task 5 — Invariants regression + full-suite green (AC-wide)**
  - [x] Re-verify every durable invariant is unmoved: the 23-key `RunSnapshot` gate (`test_run_snapshot.gd`),
        `SettingsSnapshot.SCHEMA_VERSION == 1`, `RngStreamSet.required_streams()` == 7 (`test_rng_stream_set.gd`); every
        `tools/dump_*` seed-regression fingerprint byte-identical (11.6 touches the PROFILE + view models + presenter —
        the generators + the DEFAULT `run_to_completion` are untouched). `ProfileSnapshot.SCHEMA_VERSION` stays 1
        (unless a justified bump — then the migration test is present + green). If a new event was added,
        `test_domain_event.gd`'s `expected_ids` pin + the enum-count assertion are updated + green.
  - [x] Run the FULL headless suite via PowerShell (the `godot` binary is not on the Bash PATH — see Project Context
        Rules): `godot --headless --path C:\Sealsworn\godot --scene res://tests/headless/test_runner.tscn
        --quit-after 10`. Apply the false-PASS grep guard (`SCRIPT ERROR|Parse Error|^FAIL` + only the 6 documented
        stderr negatives: int64-overflow ×2, malformed-JSON ×3, `invalid_node_type` ×1 — plus any NEW documented
        negative 11.6 adds, e.g. a `profile_save_*` forcing case, which MUST be documented in the story + the ledger).
        Run `git diff --check`.

- [x] **Task 6 — Update the deferred-work ledger + tracking (AC-wide, hygiene)**
  - [x] In `deferred-work.md` (new 11.6 entry): mark **RESOLVED** the **meta-SPEND / unlock APPLICATION** fence (the
        canonical "unlock-SPEND / meta-power APPLICATION" entry carried since Epic 8, re-recorded by
        8.4/8.6/8.7/11.2/11.3/11.4/11.5 as "the meta-SPEND / unlock APPLICATION (11.6)") — 11.6 authors the spend
        command + the profile→class-selectability application (FR43) + the capped/sparse posture (FR95). Note whether the
        live discovery-source residual (v0 has no live Seal-Fragment source) is STILL open (it is — a later story), and
        the 8.7 AC-wording divergence is now realized (the profile→class-selectability wiring 8.7's AC1 was told NOT to
        build now EXISTS). RE-RECORD still-open (NOT 11.6's): the **live in-node board / pending-fight SAVE**; **G4 the
        settings view model** (PARKED); the **run-level event STORE for a full RunSummary**; the **live discovery/echo/
        seal-fragment SOURCE** (no live path earns unlock progress in a hands-off run). Note the originating story/date.
        Do NOT reopen or re-defer items unrelated to this story's surface.

## Dev Notes

### What this story is (and is not)

Epic 8 built the cross-run meta layer's RECORD/AWARD half: `AwardMetaProgressCommand` awards Oath Shards,
`MergeRunDiscoveriesCommand` records unlock progress + class mastery, `UnlockProgressRules` computes threshold
crossings — and every one of them, plus 8.7's save/load tests and 11.5's outpost render, **deliberately deferred the
SPEND/APPLICATION half** to "a later meta-spend story." **11.6 IS that story** — the final story of Epic 11. It authors
the FIRST command that SPENDS `profile.oath_shards` (or consumes an unlock resource), and — the crux — wires the
**profile → class-selectability** path so a met unlock actually flips a class from locked to selectable (FR43), flowing
through repositories/view models, never scene-owned state, with meta power staying capped and sparse (FR95).

**The single most important rule: SPEND/APPLY THE EXISTING ACCUMULATED STATE; do not re-award, do not re-merge, do not
fork a parallel meta path.** The award (`profile.oath_shards`), the merge (`profile.unlock_progress` +
`profile.class_mastery`), and the calculators (`MetaAwardRules`/`UnlockProgressRules`) already exist. 11.6 reads that
accumulated state and CONSUMES/APPLIEs it. Read the ACTUAL source before wiring — a wrong method/const/pinned-key name
is the primary review-cycle cause (the 11.1 Round-1 review caught an HP field mis-sourced on `RunState`; the 11.3
Round-2 review caught a dead `has_method("current_text_scale")` probe that read as "wired" but no-op'd). Cite the EXACT
as-built method/const/key names, verified against source; grep every probed method name against source before trusting a
guarded-accessor claim.

### The crux (read the source): the profile → class-selectability wiring does NOT exist yet — BY DESIGN

`project-context.md` (line 234) states it verbatim: *"AC1's 'class unlock states restore correctly' [Story 8.7] does NOT
mean a profile->class-selectability wiring exists — v0 has NONE (`ClassDefinition.lock_state` is STATIC;
`HeroSelectViewModel` reads no profile). The AC is satisfied by the profile `unlock_progress`/`class_mastery` STATE
round-tripping ... Do NOT build a deferred meta-spend/apply system to satisfy this AC."* — 8.7 was explicitly told NOT
to build the profile→class-selectability wiring because **11.6 owns it.**

Verify by reading:

- `ClassDefinition.lock_state` (`godot/scripts/content/definitions/class_definition.gd:15`) is a static `@export`
  field; `is_selectable()` (`:78`) returns `lock_state == LOCK_STATE_SELECTABLE`. `ClassRepository._baseline_definitions()`
  (`godot/scripts/content/repositories/class_repository.gd:90-137`) hardcodes necromancer/shadeblade as
  `LOCK_STATE_LOCKED`.
- `HeroSelectViewModel` (`godot/scripts/ui/view_models/hero_select_view_model.gd`) — `_init(new_class_repository:
  ClassRepository = null)` (`:44`) takes ONLY a repository; `is_class_selectable`/`selectable`/`selectable_class_ids`
  all read `ClassDefinition.is_selectable()` and read NO profile.
- `RunStartCommand`'s CLASS gate rejects a non-selectable class reading the same static `is_selectable()`.

So 11.6's crux is: make the class-selectability decision **profile-aware** (a locked class becomes selectable iff its
unlock requirement is met on the profile) at the view-model + authoritative-gate layer, WITHOUT mutating the static
`ClassDefinition` and WITHOUT scene-owned state. The two decision sites (`HeroSelectViewModel` and `RunStartCommand`)
must read the SAME unlock source and agree (a mis-enabled confirm cannot start a still-locked class; a genuinely
unlocked class must not be rejected by the start command).

### The AC2 seam decision (DECIDE ONE, record it in Completion Notes)

The profile→class-selectability seam. Two acceptable shapes (both keep `ClassDefinition` static + own no scene state):

- **Option A (RECOMMENDED — profile-aware view model + gate, minimal):** `HeroSelectViewModel` accepts an optional
  `ProfileSnapshot` (or a pre-derived "applied unlocks" set from a pure helper). Its `selectable`/`is_class_selectable`
  consults `static is_selectable()` **OR** the profile's applied-unlock state for that class. `RunStartCommand`'s class
  gate is threaded the same profile/applied-unlock set (a last/optional arg, preserving every call site) so it agrees.
  A null profile → byte-identical static behavior (fail-closed default). A pure helper (e.g. on `UnlockProgressRules` or
  a new `MetaSpendRules`) maps `unlock_progress`/`class_mastery` → the set of unlocked class ids, capped/sparse, NO
  raw-stat key. Pros: minimal blast radius, the `ENTRY_KEYS` pin is unchanged (the `selectable` VALUE becomes
  profile-aware), both decision sites read one source.
- **Option B:** a distinct `ClassUnlockView`/overlay surface that composes the profile + the roster and the outpost/hero
  select reads it. Higher surface area; only choose if Option A's threading is awkward.

Whichever is chosen: the applied-unlock effect flips a VARIETY gate (class selectability), NEVER a raw combat stat
(FR95); `UnlockProgressRules.is_raw_stat_unlock_key` produces none; the mapping (which unlock flag / mastery count /
Seal-Fragment threshold → which class) is pure const config; and the VM affordance + the authoritative gate agree.

### The spend-command shape (mirror the Epic-8 run-end family VERBATIM)

The spend command is a run-domain command mirroring `AwardMetaProgressCommand`/`MergeRunDiscoveriesCommand` (read both
before writing). The shared idiom (`game_command.gd` base): `_init(profile, <spend inputs>, sequence_id)`;
`validate(state)` rejects `sequence_id <= 0` FIRST; validate-then-mutate with ZERO events + a byte-identical no-mutation
profile on ANY reject; the event is built ONLY after the mutation; **ZERO RNG** (a spend is deterministic arithmetic,
not a roll); ONE stable top-level error code per failure class (the precise reason rides `metadata`); the CALLER
persists via `ProfileRepository.write_profile` (the command does not persist itself). Key DIVERGENCES from the run-end
family to decide:

- **The `state` arg:** the award/merge/latch take the TERMINAL `RunState` as `state` (they fire at run-end). A spend
  fires at the OUTPOST, possibly with NO live run — so the `state` arg is likely unused/null (the `RunStartCommand`
  "state unused, context via constructor" precedent) or carries a minimal spend context. The profile + spend inputs are
  the real context (constructor). Record it.
- **Idempotency:** the four run-end markers are once-per-run or once-per-lifetime LATCHES. A spend is a PLAYER-INITIATED
  REPEATABLE action (a player may spend again) — so idempotency is NOT "block a second spend." It is: (a) the
  APPLICATION is idempotent (applying an already-met unlock does not double-unlock; the applied-unlock set is a SET),
  and (b) the command is retry-safe (a persist-failure retry re-reads → re-runs → re-writes without double-charging —
  mirror 11.5's retry semantics). A spend must read/write NONE of the four run-end markers. Record the mechanism.
- **The event:** a new `oath_shards_spent`/`unlock_applied` SYSTEM event is the likely correct choice (the award/merge
  events are the ADD side and cannot honestly record a SUBTRACT). Wire it end-to-end (see the fail-loud constraint).
  Its validator mirrors `oath_shards_awarded`'s honest-record arithmetic at the OPPOSITE sign
  (`oath_shards_before - amount == oath_shards_after`, both non-negative). ZERO RNG (no `roll`/`draw_index`).

### The FR28 nuance (manual-seed exclusion — where it actually lives)

AC1 says "manual-seed-earned progress remains excluded end-to-end (FR28)." The eligibility model is on the AWARD side,
not the spend side: `AwardMetaProgressCommand`/`MergeRunDiscoveriesCommand` DENY a manual-seed run at their
`run_not_meta_eligible` gate (`run.meta_progression_eligible == false`), so a manual-seed run **never awarded any Oath
Shards or merged any unlock progress in the first place** — there is nothing manual-seed-earned to spend. The FR28
guarantee is therefore STRUCTURAL: a spend can only consume `profile.oath_shards` that an ELIGIBLE run awarded, and a
spend command must NOT fabricate or award shards (it only subtracts). The NARRATIVE latches (first-death/first-victory)
are eligibility-INDEPENDENT (Option A) but grant zero currency — irrelevant to spend. Prove FR28 by asserting: (a) the
award/merge path denies a manual-seed run (existing tests cover this — cite them), and (b) the spend command cannot
increase `oath_shards` (it only decreases). Do NOT add a new eligibility gate to the spend command for manual-seed — the
exclusion already happened at award time.

### The event-sourcing / discovery-source constraint (why AC2 is test-proven, not live-earned)

v0 has NO live path that EMITS a `content_discovered` event during a hands-off run (combat auto-resolves; grep-verified:
`content_discovered` appears in only 3 scripts — `domain_event.gd` (factory), `merge_run_discoveries_command.gd`
(consumer), `run_summary.gd` (reader) — and is PRODUCED by nothing in the live flow). `unlock_progress` is populated
ONLY by a caller-/test-supplied discovery-event list handed to `MergeRunDiscoveriesCommand`. **Consequence for
AC2:** the profile→class-selectability wiring is REAL and testable, but a hands-off live run never earns a Seal Fragment
on its own — so prove AC2 by SEEDING the profile state a merge would have produced (a profile whose `unlock_progress`
carries the crossing, or a merge driven with fixture discovery events), then assert the class becomes selectable. Do NOT
add a live discovery source (that is a later story). This is an honest v0 limitation, not a bug — the same posture 11.5
recorded for the empty run-level event store.

### The fail-loud-on-new-event constraint (the retro "new table" heads-up)

If 11.6 adds a spend event, `test_domain_event.gd` (`godot/tests/unit/core/test_domain_event.gd:2861-2941`) is the
tripwire: `expected_ids` pins every `DomainEvent.Type` member's id, and `assert_equal(expected_ids.size(),
DomainEvent.Type.size() - 1, ...)` (`:2937`) plus the per-member loop (`:2939-2941`) FAIL LOUD if a new `Type` member is
added without pinning it in `expected_ids`. So a new event MUST be added to: the `Type` enum TAIL (after `BOSS_DEFEATED`,
enum index 47), a `EVENT_ID_*` const, a factory function, the `_validate_payload_for_event` match, a `_validate_*_payload`
validator, BOTH id maps (`id_for_type`/`type_for_id`), a JSON round-trip test, malformed-negative tests, AND
`expected_ids`. This is the "a gate/check will fail-loud on the new table" heads-up from the Epic-9 retro forward-prep,
realized here. (If 11.6 adds NO new event — e.g. reuses `profile_progress_merged` for the apply and needs no spend
record — this constraint does not apply; but a spend SUBTRACT is not honestly a `profile_progress_merged`.)

### Project Context Rules

Extracted from `project-context.md` (the canonical AI rulebook) — the rules that BIND 11.6's implementation:

- **Presentation observes; it owns no tactical truth.** The outpost/meta-menu scene READS view-model/render-view
  projections and SUBMITS intent (a spend request) through the caller seam; it never mutates the profile directly. Use
  signals for UI feedback, not hidden domain control flow. **The applied-unlock effect is a profile-aware overlay at the
  view-model/gate layer — NOT scene-owned state and NOT a mutation of the static `ClassDefinition`** (procedural/runtime
  code selects from approved static content; it does not rewrite it).
- **Commands validate before mutation and return `ActionResult`; successful commands emit deterministic past-tense
  `DomainEvent` records.** The spend command is a run-domain command (the 4.3/8.3 idiom VERBATIM): validate-then-mutate,
  ZERO events on reject, event ONLY after mutation, ONE stable top-level error code per failure class. A new spend event
  is append-only, wired end-to-end (factory + validator + both id maps + round-trip + malformed + `expected_ids`).
- **Named RNG streams only; ZERO `randi`/`randf`/`RandomNumberGenerator`.** A spend/apply is deterministic arithmetic —
  ZERO RNG (no draw provenance). The 7 named streams stay 7.
- **The profile is its OWN cross-run snapshot + repository + save file** (`ProfileSnapshot`/`ProfileRepository`/
  `user://profile.json`), STRICTLY INDEPENDENT of the run autosave. A spend touches the PROFILE, NOT `RunSnapshot` (the
  23-key gate stays 23). `ProfileSnapshot.SCHEMA_VERSION == 1` — reserve a home in the current schema (additive at v1,
  the 8.5/9.4 precedent) rather than bumping the version; a bump needs a real migrate step + a migration test (the 8.7
  matrix owns the pattern).
- **Repositories own atomic writes + structured read/write errors.** `ProfileRepository` writes atomically
  (temp→backup→replace) and returns structured codes; a failed write leaves the prior valid profile intact; read the
  CODE as truth, not stderr. There is NO `SaveManager` profile delegator — the caller drives `ProfileRepository`
  directly (the 11.5 posture).
- **Autoloads stay thin.** `SceneManager`/`GameSession`/`SaveManager` delegate; they own no run/profile logic. A new
  registered autoload is out of scope (Epics 8-11.5 added none).
- **Manual seed/debug runs must not grant meta progression (FR28)** — structurally enforced at AWARD time (a manual-seed
  run never awarded shards); the spend command does NOT re-gate for manual-seed and does NOT fabricate shards.
- **Meta power is capped and sparse (FR95); difficulty is a hard non-goal.** An unlock flips a VARIETY gate (class
  selectability), NEVER a raw combat stat (`damage`/`max_hp`/`armor`/`crit`/`dodge` — `is_raw_stat_unlock_key` produces
  none). No difficulty selector anywhere. The unlock config does not scale by difficulty.
- **Content is code-constant baselines; no `.tres`/JSON pipeline.** A cost/unlock config is a pure const-config
  calculator (the `MetaAwardRules`/`UnlockProgressRules` template), NOT a new content family or `*Repository`.
- **Save/load tests exercise a real JSON round-trip** (`JSON.stringify` → `parse_string`), int-coercion-aware for nested
  int dicts (the 8.7 `class_mastery` lesson: `{"x": 3} != {"x": 3.0}` across JSON).
- **Godot binary path (this machine):** `godot` is NOT on the Bash/`where` PATH — it resolves as
  `C:\Users\Rasmus\bin\godot.cmd` via PowerShell. Run the headless suite through PowerShell, not the Bash tool's PATH
  lookup. Apply the false-PASS grep guard (`SCRIPT ERROR|Parse Error|^FAIL`).

### Epic-11 retro constraints that BIND 11.6 (from `_bmad-output/auto-gds/retro-notes/epic-11.md`)

Ratified conventions from earlier Epic-11 stories — 11.6 MUST honor them:

- **The scene-free headless harness has NO SceneTree (G1/G2 posture, ratified 11.3/11.4/11.5).** The runner runs
  `script.new().run()` — a `.tscn`/`Control` surface is NOT directly unit-testable. Steer ALL testable spend/apply/render
  logic into fail-closed `RefCounted` seams (the spend command; a spend bridge/controller; the `OutpostRenderView` spend
  render decisions; the profile-aware `HeroSelectViewModel`); verify scene wiring BY CONSTRUCTION (the scene-load compile
  guardrail `test_run_flow_scenes_load.gd` + the read-only-projection discipline). **DO NOT write SceneTree tests.** The
  spend-menu render decisions (can-afford / cost / unlock-applied / insufficient) belong in `OutpostRenderView`, tested
  there.
- **Pinned-key / source-verification rigor (dead `has_method` probes bit this epic TWICE).** Grep every probed
  method/const/key name against source before trusting a guarded-accessor claim (the 11.3 M2 dead
  `has_method("current_text_scale")` probe; the 11.1 `range` vs `weapon_reach` key mix-up). Cite the EXACT as-built
  `ProfileSnapshot.DICTIONARY_KEYS` / `HeroSelectViewModel.ENTRY_KEYS` / `OutpostViewModel.DICTIONARY_KEYS` /
  `UnlockProgressRules.SEAL_FRAGMENT_THRESHOLDS` / `AwardMetaProgressCommand` shape — all verified in this story's seam
  map against source. A key outside a pinned set is a contract violation.
- **The new `RunEndProfileBridge` + outpost presenter/render-view (11.5) are the natural seams the spend/apply hooks
  into.** The spend bridge mirrors `RunEndProfileBridge`'s caller-driven load→command→persist→rebuild posture; the spend
  menu renders on `outpost_presenter.gd` via `OutpostRenderView`. Do NOT fork a parallel outpost/profile path.
- **`OutpostViewModel` gained a `first_victory_beat` positional arg at position 4 in 11.5 — positional callers must
  account for it.** `_init(profile, run_summary, first_death_beat, first_victory_beat, class_repository,
  new_recovery_state)`; `for_recovery(recovery_code, loaded_profile=null, run_summary=null, first_death_beat=null,
  class_repository=null, is_recoverable=true, first_victory_beat=null)`. Any new `OutpostViewModel.new(...)`/
  `.for_recovery(...)` caller 11.6 adds MUST bind these positions correctly. **Prefer to display applied-unlock state via
  the EXISTING `unlock_progress`/`class_options`/`selectable_class_ids` keys** (which already read the profile) rather
  than adding another positional arg — every added positional arg re-shifts callers and re-pins `test_outpost_view_model.gd`.
- **When a presenter re-implements a sequencing the domain already encodes, test the presenter's shared sequencing
  seam (11.3 H1: on-screen advance-then-resolve silently diverged from the tested driver; 11.5's bridge re-implemented
  the run-end command sequencing).** 11.6's spend bridge RE-IMPLEMENTS a load→spend→persist→rebuild sequencing at the
  presenter/flow layer — test the SHARED bridge/apply seam (a RefCounted method), not just the individual command, so the
  on-screen order (spend-then-persist-then-rebuild, off the loaded profile) is proven correct and never rebuilds the
  outpost off a stale/un-persisted profile.

### Deferred-work ledger items that OVERLAP 11.6 (from `_bmad-output/implementation-artifacts/deferred-work.md`)

Only the entries whose subject overlaps 11.6's area — folded in so the dev agent addresses or knowingly works around
them (the rest of the ledger is out of scope):

- **[Resolve in 11.6] The meta-SPEND / unlock APPLICATION** — the canonical "unlock-SPEND / meta-power APPLICATION"
  fence, carried since Epic 8 and re-recorded by EVERY subsequent meta story (dev-of-8.3/8.4 line ~331-333: "8.4 RECORDS
  the unlock STATE flip ... it does NOT spend Oath Shards, apply any stat/passive/class/starting-option from an unlock,
  or build the unlock-spend tree ... a LATER meta-spend story, 8.6+/Epic 9"; review-of-8.6 line ~215; review-of-8.7 line
  ~198: "8.7 tests that the `unlock_progress` + `class_mastery` STATE round-trips; turning that state into a
  playable-class unlock stays deferred"; dev-of-11.2 line ~119; dev-of-11.3 line ~100: "11.3 stops at navigating to the
  outpost destination ... the meta-spend / unlock application is 11.6"; dev-of-11.4 line ~58; dev-of-11.5 line ~38: "the
  spend menu + `unlock_progress` → class-selectability flip (FR43) + `AwardMetaProgressCommand`/`MergeRunDiscoveriesCommand`
  GRANT are 11.6's end-to-end scope"). **11.6's Tasks 1-4 discharge this** (the spend command + the profile→class-selectability
  application + the capped/sparse FR95 posture). Note: 11.5's re-record said 11.6's scope includes driving the
  award/merge GRANT — but 8.3/8.4 already ship + test the award/merge; 11.6's concern is the SPEND + the APPLY (the
  award/merge remain caller-driven at run-end via 11.5's `RunEndProfileBridge`, which is NOT in 11.6's scope to change).
  Interpret "GRANT" as: 11.6 makes the recorded `unlock_progress` ACTUALLY APPLY (class selectability) — it does not
  re-author the award/merge commands.
- **[RE-RECORD still-open — NOT 11.6's] The live discovery / echo / Seal-Fragment SOURCE** — v0 has NO live path that
  emits `content_discovered` during a hands-off run (grep-verified). So a hands-off live run never earns unlock progress
  on its own; 11.6 proves AC2 by seeding the profile state a merge would have produced. A live per-node discovery source
  is a later story (dev-of-8.4 line ~325-330: "v0 has no live combat/content-discovery source that FIRES a
  content_discovered event ... the live per-node discovery CALL SITE + the auto-wire" is deferred). Do NOT add it.
- **[RE-RECORD still-open — NOT 11.6's] The live in-node board / pending-fight SAVE** (dev-of-11.5 line ~39): the
  in-node fight state stays ephemeral (the 23-key gate stays 23); a mid-encounter save is a later in-node-save story.
- **[RE-RECORD still-open — NOT 11.6's] The run-level event STORE for a full RunSummary** (dev-of-11.5 line ~40): 11.5's
  bridge builds `RunSummary.build(run, [])` with an empty events list; a persisted run-level event log is a later
  save-shape story. Unrelated to the spend/apply surface.
- **[RE-RECORD PARKED — the settings-scene owner] G4 — the settings view model** (dev-of-11.3 line ~102; dev-of-11.5
  line ~41; appendix §16 G4): 11.3/11.5 built no settings scene, so G4 stays PARKED. If 11.6 does not build a settings
  scene, RE-RECORD it PARKED. The outpost/meta-menu surfaces must NOT present a difficulty selector (the ratified hard
  non-goal, appendix §12.3).

### The 11.1 appendix screen contract 11.6 implements (source of the paper design)

`_bmad-output/planning-artifacts/ux-appendix-run-flow.md` (the settled paper design 11.6 builds against):

- **§7 Outpost / meta menu** — binds `OutpostViewModel.to_dictionary()` (pinned `DICTIONARY_KEYS`). The four named
  spaces (`memory_archive` → echoes_and_codex, `hall_of_oaths` → oath_shards_and_class_mastery, `seal_table` →
  seal_fragments_and_unlock_progress, `descent_stair` → start_another_descent) all carry `status: "deferred"` in v0.
  **11.6's shallow meta menu is where the `seal_table`/`hall_of_oaths` spaces gain a live spend affordance** (the
  Oath-Shard/Seal-Fragment/unlock spend). §7.4: a scrollable stack on phone → a multi-panel dashboard on desktop;
  deferred spaces carry a label/icon "coming soon" marker (not color-only) — a REALIZED spend space flips from deferred
  to a live affordance (do NOT leave a live affordance marked `deferred`). Meta counts shown as number+label; descend +
  spend affordances ≥44×44.
- **§6 Hero select** — binds `HeroSelectViewModel` (pinned `ENTRY_KEYS = [class_id, display_name, selectable,
  unlock_hint]`). A locked class is distinguishable WITHOUT color (label/icon "locked" marker + `unlock_hint`); the
  authoritative gate is `RunStartCommand`. **11.6 makes `selectable`/the confirm gate profile-aware** so an applied
  unlock flips a class from the greyed-out+hint state to the selectable state (§6.3 "locked-class-focused →
  confirm→start"). The grey-out is a UX affordance layered on the authoritative gate — never the only gate.
- **§14 Layout + accessibility** — every screen: four-layout honoring the semantic `TacticalLayoutProfile` region plan;
  color-independence (every critical meaning carries a non-color channel — shape/icon/label/pattern/text; a spend
  can-afford/insufficient state, an unlock-applied marker, and a cost all carry text+icon, not color); scalable text
  (`TacticalTextScale` clamp `[0.85, 2.0]`, driven by `SettingsSnapshot.text_scale`; changing scale never alters
  gameplay/meta).

### Project Structure Notes

- Production Godot code under `godot/`; run-domain commands under `godot/scripts/core/commands/` (extending
  `game_command.gd`); the cross-run save layer (`ProfileSnapshot`/`ProfileRepository` + the pure `MetaAwardRules`/
  `UnlockProgressRules`/`MetaSpendRules` calculators) under `godot/scripts/save/`; view models under
  `godot/scripts/ui/view_models/`; presenters under `godot/scripts/ui/presenters/`; run flow/bridges under
  `godot/scripts/ui/flow/`; scenes under `godot/scenes/ui/`. Tests mirror the domain under `godot/tests/` (`unit/core/`,
  `unit/save/`, `unit/ui/`, `integration/save/`).
- New files 11.6 likely adds: a spend command
  (`godot/scripts/core/commands/spend_oath_shards_command.gd` or similar), a pure cost/unlock config calculator
  (`godot/scripts/save/meta_spend_rules.gd`, the `MetaAwardRules` template), a spend caller seam (a new
  `godot/scripts/ui/flow/*bridge.gd` OR a `RunFlowController` method), and tests (`godot/tests/unit/core/test_spend_*`,
  `godot/tests/unit/save/test_meta_spend_rules.gd`, updates to `test_hero_select_view_model.gd`,
  `test_run_start_command.gd`, `test_profile_snapshot.gd`, `test_meta_summary_save_load.gd`, `test_outpost_render_view.gd`).
  If a new spend event: update `godot/scripts/core/events/domain_event.gd` + `godot/tests/unit/core/test_domain_event.gd`
  (the `expected_ids` pin). If a new spend scene: `godot/scenes/ui/*.tscn` + `test_run_flow_scenes_load.gd`.
- Naming: `snake_case` files/folders, `PascalCase` classes, `snake_case` funcs/vars/signals, `UPPER_SNAKE_CASE` consts.
  Commands use imperative names (`SpendOathShardsCommand`); events use past-tense (`oath_shards_spent`). Match the
  Epic-8 run-end command + the 11.5 presenter posture verbatim.

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Story 11.6] — the 3 ACs (lines ~2725-2746) + the Epic-11
  FR-coverage/implementation notes (FR59 meta spend/application, FR43 locked-class unlock, FR95 capped/sparse).
- [Source: godot/scripts/save/snapshots/profile_snapshot.gd] — `SCHEMA_VERSION == 1`; pinned `DICTIONARY_KEYS`;
  `oath_shards` (plain int), `unlock_progress`/`class_mastery`/`echoes`; `fresh`/`copy`/`parse`.
- [Source: godot/scripts/core/commands/award_meta_progress_command.gd] + merge_run_discoveries_command.gd — the run-end
  profile-mutation command TEMPLATE (the 4.3/8.3 idiom: `_init(profile, ..., sequence_id)`, reject `sequence_id <= 0`
  first, validate-then-mutate, ZERO RNG, caller persists).
- [Source: godot/scripts/core/commands/game_command.gd] — the `validate`/`execute` base contract.
- [Source: godot/scripts/save/unlock_progress_rules.gd] — the pure ZERO-RNG capped calculator; `SEAL_FRAGMENT_THRESHOLDS`;
  `is_raw_stat_unlock_key` (the FR95 guard); `SEAL_FRAGMENTS_KEY`. [Source: godot/scripts/save/meta_award_rules.gd] —
  the const-config calculator template.
- [Source: godot/scripts/ui/view_models/hero_select_view_model.gd] — pinned `ENTRY_KEYS`; `is_class_selectable`;
  `_init(class_repository)` reads NO profile (the AC2 seam).
- [Source: godot/scripts/content/definitions/class_definition.gd] + repositories/class_repository.gd — static
  `lock_state`; the two locked baselines (necromancer/shadeblade); `is_selectable()`.
- [Source: godot/scripts/core/commands/run_start_command.gd] — the authoritative fail-closed class gate
  (`class_not_selectable`) that must become profile-aware in lockstep with the VM.
- [Source: godot/scripts/save/profile_repository.gd] — `read_profile`/`write_profile` (atomic; `profile_save_*` codes);
  NO `SaveManager` delegator.
- [Source: godot/scripts/ui/flow/run_end_profile_bridge.gd] — the caller-driven load→command→persist→build seam (the
  spend-bridge template); its scope fence excludes the 11.6 spend/GRANT; note the 7-arg `for_recovery` call.
- [Source: godot/scripts/ui/view_models/outpost_view_model.gd] — pinned `DICTIONARY_KEYS`; the `_init` positional-arg
  order (`first_victory_beat` at position 4); `for_recovery` (position-7 `first_victory_beat`); the `unlock_progress`/
  `class_options`/`selectable_class_ids` display keys.
- [Source: godot/scripts/ui/view_models/outpost_render_view.gd] + presenters/outpost_presenter.gd — the render-decision
  seam (where spend render decisions go) + the outpost scene (where the meta menu renders); the `named_spaces` tiles.
- [Source: godot/scripts/ui/flow/run_flow_controller.gd] + godot/scripts/run/run_orchestrator.gd:885-886 — the
  `finalize_run_end(bridge)` seam + `next_sequence_id()` (the unique `sequence_id > 0` cursor).
- [Source: godot/scripts/core/events/domain_event.gd] + godot/tests/unit/core/test_domain_event.gd:2861-2941 — the
  append-only event vocabulary (tail `BOSS_DEFEATED`) + the `expected_ids` fail-loud-on-new-event pin.
- [Source: _bmad-output/planning-artifacts/ux-appendix-run-flow.md] — §6 (hero select), §7 (outpost/meta menu), §14
  (layout+accessibility).
- [Source: _bmad-output/auto-gds/retro-notes/epic-11.md] — the scene-free-harness / pinned-key / presenter-sequencing /
  `RunEndProfileBridge`-seam / `OutpostViewModel`-positional-arg constraints.
- [Source: _bmad-output/implementation-artifacts/deferred-work.md] — the meta-SPEND / unlock APPLICATION fence + the
  live-discovery-source residual.
- [Source: project-context.md] — the canonical AI rulebook, esp. the Epic-8 run-end/meta-profile rules (lines 212-234:
  the profile-is-own-snapshot rule, the capped/sparse `UnlockProgressRules`, the "EFFECT-APPLICATION is a LATER
  meta-spend story" defer at line 226, and the 8.7 AC-wording divergence at line 234 that 11.6 realizes).

## Dev Agent Record

### Agent Model Used

Claude Opus 4.8 (claude-opus-4-8[1m]) — auto-gds dev-story delegate.

### Debug Log References

- Full headless suite (Godot 4.6.3, PowerShell): `godot --headless --path C:\Sealsworn\godot --scene res://tests/headless/test_runner.tscn --quit-after 10` → **"Headless tests passed." / 182 PASS / 0 `^FAIL`**. False-PASS grep (`SCRIPT ERROR|Parse Error|^FAIL`) clean; only the 6 documented stderr negatives (int64-overflow ×2, malformed-JSON ×3, `invalid_node_type` ×1). `git diff --check` clean.
- One iteration fix: `test_meta_summary_save_load._spend_then_persist_round_trips_the_applied_unlock` initially compared `to_dictionary()` byte-identical and tripped the 8.7 int-coercion artifact (`_oath_shards_spent: 3` decodes as `3.0` across JSON). Fixed by asserting the ledger via `MetaSpendRules.oath_shards_spent_in` (int-coercion-aware) + the flag/total individually, mirroring how `class_mastery` is tested.

### Completion Notes List

**Decisions recorded (per the story's DECIDE prompts):**

- **The spend command `state` arg — Option A (unused/null):** a spend fires at the outpost with NO live run, so `SpendOathShardsCommand.validate(_state)/execute(_state)` ignore `state` (accepts null) — the profile + `unlock_id` in the constructor are the real context (the `RunStartCommand` "state unused, context via constructor" precedent).
- **AC2 seam — Option A (profile-aware view model + gate, minimal):** `HeroSelectViewModel` + the authoritative `RunStartCommand` class gate both gained an OPTIONAL trailing `ProfileSnapshot`; a locked class is selectable iff (static `LOCK_STATE_SELECTABLE`) OR (its class id is in `MetaSpendRules.unlocked_class_ids_for(profile.unlock_progress)` — the SINGLE source both read, so they AGREE). The static `ClassDefinition.lock_state` is NEVER mutated (a profile-aware OVERLAY). The pinned `HeroSelectViewModel.ENTRY_KEYS` + `OutpostViewModel.DICTIONARY_KEYS` are UNCHANGED (the `selectable` VALUE becomes profile-aware; `OutpostViewModel` threads its EXISTING `profile` arg into the composed VM — no new positional arg re-shift). A null profile => byte-identical static Story-5.2 behavior. `RunOrchestrator.start` / `RunFlowController.start` gained a matching optional trailing profile arg (fingerprint-safe: the default is unchanged).
- **Unlock→class mapping (pure const `MetaSpendRules.CLASS_UNLOCKS`):** `necromancer` (cost 3 → `necromancer_unlocked`), `shadeblade` (cost 5 → `shadeblade_unlocked`) — the two locked baselines (FR43). Capped/sparse: exactly two variety gates, each a one-time purchase; NO raw-stat key (`UnlockProgressRules.is_raw_stat_unlock_key` produces none — asserted in `test_meta_spend_rules`).
- **Spend-state home — Option: inside the existing `unlock_progress` dict (no new top-level field, no migration).** The `<class>_unlocked` applied-unlock flags + the underscore-namespaced `_oath_shards_spent` ledger live under `unlock_progress` (the seal-fragments / `_last_merged_run_seed` precedent), so `ProfileSnapshot.SCHEMA_VERSION` stays 1, `DICTIONARY_KEYS` is UNCHANGED, and there is NO migration. `profile_snapshot.gd` is UNTOUCHED.
- **Spend idempotency mechanism:** the APPLICATION is idempotent via the applied-unlock flag — re-applying an already-applied unlock rejects `unlock_already_applied` (ZERO charge, ZERO event), which is ALSO the retry-safety (a persist-failure retry re-reads the profile with the flag set + rejects without double-charging). A spend reads/writes NONE of the four run-end markers (`last_awarded_run_seed`, `_last_merged_run_seed`, `first_death_recorded`, `first_victory_recorded`) — proven order-independent in `test_meta_summary_save_load`. A spend is a PLAYER-INITIATED REPEATABLE action: buying a DIFFERENT class unlock is a separate legitimate spend.
- **The new event — `oath_shards_spent` (a NEW SYSTEM event):** the `oath_shards_awarded` counterpart at the OPPOSITE sign (`before - amount == after`, `amount` POSITIVE, both non-negative — a spend never drives a negative total). Wired end-to-end (enum tail after `BOSS_DEFEATED`, `EVENT_ID_*` const, factory, `_validate_payload_for_event` arm + `_validate_oath_shards_spent_payload` validator, both id maps, JSON round-trip + malformed-negative tests, AND the `expected_ids` pin). ZERO RNG.
- **The spend/apply bridge — a NEW `OutpostSpendBridge` (mirroring `RunEndProfileBridge`), NOT a `RunFlowController` method:** load → spend → persist → rebuild off the LOADED profile. Its own monotonic `sequence_id` source (a spend at the outpost has no live run/orchestrator; keeps `sequence_id > 0`). The 11.5 write-failure real-totals-behind-retry recovery. The retro H1 shared-seam test (`test_outpost_spend_bridge`) proves two spends in a row each load the LATEST persisted profile (never a stale one).
- **The named-space status — the spend menu is a DISTINCT surface, the four overview tiles STAY `deferred`:** the shallow meta menu renders as its own "Seal Table — Class Unlocks" section on `outpost_presenter.gd` (the realized live spend surface); the four `named_spaces` overview tiles remain `deferred` markers (not mislabeled — the live affordance is the distinct menu, not the overview tile). The spend render DECISIONS (`class_unlock_options`/`can_spend_unlock`/`has_affordable_unlock` — can-afford/insufficient/applied + cost, all non-color text+icon) live in `OutpostRenderView` (the retro G1/G2 posture — testable without a SceneTree).

**FR28 (verified structural):** the manual-seed exclusion is on the AWARD side (a manual-seed run never awarded shards — `AwardMetaProgressCommand` Gate 2). The spend command does NOT re-gate for manual-seed and CANNOT fabricate shards (it only subtracts) — proven in `test_spend_oath_shards_command._spend_cannot_fabricate_shards_fr28`.

**Known v0 limitation (recorded in `deferred-work.md`):** the baseline `necromancer`/`shadeblade` `ClassDefinition`s carry NO kit, so starting a run with an unlocked baseline locked class would fail `RunStartCommand`'s kit/passive resolution. 11.6's applied-unlock flips their SELECTABILITY (the VM + the authoritative gate honor it — proven with a fixture repo whose locked class carries a valid baseline kit); authoring the real Necromancer/Shadeblade class-kit content is a later content story (the "no new content family" fence).

### File List

**New (production):**
- `godot/scripts/core/commands/spend_oath_shards_command.gd` — the meta-SPEND command (the `AwardMetaProgressCommand` idiom at the opposite sign).
- `godot/scripts/save/meta_spend_rules.gd` — the pure const-config spend calculator (cost table + unlock→flag mapping + the single AC2 seam source `unlocked_class_ids_for`).
- `godot/scripts/ui/flow/outpost_spend_bridge.gd` — the caller-driven load→spend→persist→rebuild bridge (mirrors `RunEndProfileBridge`).

**Modified (production):**
- `godot/scripts/core/events/domain_event.gd` — appended the `oath_shards_spent` SYSTEM event (enum tail, const, factory, validator + match arm, both id maps, `OATH_SHARDS_SPENT_REASONS` allowlist).
- `godot/scripts/ui/view_models/hero_select_view_model.gd` — profile-aware selectability (optional trailing `ProfileSnapshot`; `_class_is_selectable` overlay; `ENTRY_KEYS` unchanged).
- `godot/scripts/core/commands/run_start_command.gd` — profile-aware authoritative class gate (optional trailing `ProfileSnapshot`; `_class_is_selectable` mirrors the VM).
- `godot/scripts/run/run_orchestrator.gd` — `start(...)` gained an optional trailing `profile` arg (threaded into `RunStartCommand`); added the `ProfileSnapshot` preload.
- `godot/scripts/ui/flow/run_flow_controller.gd` — `start(...)` gained an optional trailing `profile` arg (forwarded to the orchestrator).
- `godot/scripts/ui/view_models/outpost_view_model.gd` — composes a PROFILE-AWARE `HeroSelectViewModel` off its existing `profile` arg (no new positional arg; `DICTIONARY_KEYS` unchanged).
- `godot/scripts/ui/view_models/outpost_render_view.gd` — the spend render decisions (`class_unlock_options`/`can_spend_unlock`/`has_affordable_unlock` + the state/note consts).
- `godot/scripts/ui/presenters/outpost_presenter.gd` — the shallow meta menu (the Seal Table spend tiles) + the spend-request handler driving `OutpostSpendBridge`.

**New (tests):**
- `godot/tests/unit/core/test_spend_oath_shards_command.gd`
- `godot/tests/unit/save/test_meta_spend_rules.gd`
- `godot/tests/unit/ui/test_outpost_spend_bridge.gd`

**Modified (tests):**
- `godot/tests/unit/core/test_domain_event.gd` — the `oath_shards_spent` round-trip + malformed tests + the `expected_ids` pin.
- `godot/tests/unit/ui/test_hero_select_view_model.gd` — the profile-aware selectability overlay tests.
- `godot/tests/unit/core/test_run_start_command.gd` — the profile-aware authoritative-gate symmetry tests + the locked-but-runnable fixture.
- `godot/tests/unit/save/test_profile_snapshot.gd` — the spend-state-inside-`unlock_progress` round-trip test.
- `godot/tests/integration/save/test_meta_summary_save_load.gd` — the spend×run-end-markers caller-ordering test + the spend-then-persist end-to-end AC2 round-trip.
- `godot/tests/unit/ui/test_outpost_render_view.gd` — the spend render-decision tests.

**Tracking:**
- `_bmad-output/implementation-artifacts/deferred-work.md` — the 11.6 entry (meta-SPEND / unlock APPLICATION RESOLVED; the still-open residuals RE-RECORDED; the new Necromancer/Shadeblade class-kit content defer).
- `_bmad-output/implementation-artifacts/sprint-status.yaml` — 11.6 → `review`.

### Change Log

- 2026-07-06 — Story 11.6 implemented: the meta-SPEND command + the profile→class-selectability application (FR43) + the capped/sparse posture (FR95) + the outpost shallow meta menu. Status → review.

### Review Findings

**Round 1 of 3**

Primary adversarial code review (2026-07-06, Opus 4.8 delegate). Reviewed the current branch's diff against `main`
(excluding `_bmad`, `_bmad-output/auto-gds`, cache/non-code files) with this story as the spec. Independently re-ran the
full headless suite: **"Headless tests passed." / 182 PASS / 0 `^FAIL`**, false-PASS grep (`SCRIPT ERROR|Parse Error|^FAIL`)
clean, exactly the 6 documented stderr negatives (int64-overflow ×2, malformed-JSON ×3, `invalid_node_type` ×1 — the
`test_outpost_spend_bridge` forced `profile_save_open_failed` produced NO new negative, confirming the silent-code claim);
`git diff --check` clean.

**Verdict: Approve.** Critical 0 / High 0 / Med 0 / Low 2. The implementation is faithful to the story's hard
constraints — all VERIFIED against source:

- **SpendOathShardsCommand validate-then-mutate discipline (VERIFIED):** mirrors `AwardMetaProgressCommand` verbatim at
  the opposite sign. `sequence_id <= 0` rejected FIRST (`invalid_event_sequence_id`); null profile → `invalid_context`;
  `unknown_unlock` / `unlock_already_applied` / `insufficient_oath_shards` all fail-close with ZERO event + a
  byte-identical no-mutation profile (proven by `to_dictionary()` equality across every reject path in
  `test_spend_oath_shards_command.gd`); the event is built ONLY after the mutation; ZERO RNG. Application-idempotency +
  retry-safety ride the `<class>_unlocked` applied-unlock flag (a re-apply rejects `unlock_already_applied`, ZERO charge)
  — the correct mechanism for a player-initiated repeatable action (a second DISTINCT unlock is a separate legitimate
  spend, tested).
- **MetaSpendRules as the SINGLE selectability source (VERIFIED — no second derivation):** grepped all selectability
  derivations. `MetaSpendRules.unlocked_class_ids_for(unlock_progress)` is read by EXACTLY two sites —
  `hero_select_view_model.gd:69` (the overlay VM) and `run_start_command.gd:262` (the authoritative gate) — both routed
  through a `_class_is_selectable(def)` helper that is mirrored VERBATIM (`static OR profile-overlay`). The VM affordance
  and the authoritative start gate therefore agree by construction; the symmetry is proven from both sides
  (`test_hero_select_view_model.gd` + `test_run_start_command.gd::_profile_unlocked_class_starts_locked_class_still_rejects`).
- **Static-content invariant (VERIFIED):** `ClassDefinition.lock_state` is NEVER mutated anywhere; the applied-unlock is
  a profile-aware OVERLAY read at the VM/gate layer. `OutpostViewModel` threads its EXISTING `profile` arg into the
  composed profile-aware VM (no new positional arg; `DICTIONARY_KEYS`/`ENTRY_KEYS` unchanged).
- **`oath_shards_spent` event (VERIFIED end-to-end):** appended at the enum TAIL (`OATH_SHARDS_SPENT`, after
  `BOSS_DEFEATED`); `EVENT_ID_*` const, factory, `_validate_payload_for_event` arm, `_validate_oath_shards_spent_payload`
  validator (honest-record `before - amount == after`, `amount > 0`, non-negative floors — `_is_integral_number` rejects
  bools), both id maps, JSON round-trip + 5 malformed tests, AND the `expected_ids` pin (`test_domain_event.gd:3021`) —
  the fail-loud enum-count tripwire is satisfied. Deterministic past-tense system event (no actor, no roll/draw_index).
- **`unlock_progress` dict storage / no schema bump (VERIFIED):** the `<class>_unlocked` flags + the
  underscore-namespaced `_oath_shards_spent` ledger live INSIDE the existing `unlock_progress` home (the seal-fragments /
  `_last_merged_run_seed` precedent). `profile_snapshot.gd` is UNTOUCHED (`SCHEMA_VERSION == 1`; `DICTIONARY_KEYS`
  unchanged). Round-trip proven with a real `JSON.stringify → parse_string` (`test_profile_snapshot.gd` + the end-to-end
  restart in `test_meta_summary_save_load.gd`), int-coercion-aware for the ledger (the 8.7 lesson). A pre-11.6 profile
  without these keys loads clean (lenient `get(..., default)` reads; the empty-`unlock_progress` cases are tested).
- **Optional-trailing-arg API additions (VERIFIED — no missed callers, no arg-order mistakes):** `HeroSelectViewModel`
  (+`ProfileSnapshot` at pos 2), `RunStartCommand` (+`ProfileSnapshot` at pos 9), `RunOrchestrator.start` /
  `RunFlowController.start` (+`profile` trailing). `RunOrchestrator.start` calls `RunStartCommand.new(seed, manual, seq,
  class_id, null, null, null, null, profile)` — the four nulls map exactly to the class/weapon/support/passive repos and
  `profile` lands in pos 9 (verified against the `_init` signature). Every existing `.start(...)` caller
  (`hero_select_presenter.gd:102`, `outpost_presenter.gd:309`) omits the new arg → the null-profile static path
  (byte-identical). No default changed → fingerprint-safe.
- **FR28 (VERIFIED structural):** `AwardMetaProgressCommand` Gate 2 rejects `run.meta_progression_eligible == false`
  (== `not is_manual_seed`) with `run_not_meta_eligible`, so a manual-seed run NEVER awards shards. The spend command
  only SUBTRACTS and cannot fabricate shards (`test_spend_oath_shards_command._spend_cannot_fabricate_shards_fr28`). No
  redundant manual-seed gate on the spend — correct.
- **Determinism / fingerprints (VERIFIED):** ZERO RNG in the whole spend/apply surface; no generator / `RunSnapshot` /
  `RngStreamSet` / `SettingsSnapshot` touch; the finale + route + level seed-regression suites and the default
  `run_to_completion` are all green and unchanged (the 23-key gate stays 23; 7 streams stay 7).
- **Dead has_method/probe sweep (VERIFIED clean):** no `has_method`/`.call(` probes in any new/modified spend file. The
  `has_node("/root/Diagnostics")` / `has_node("/root/GameSession")` / `has_node("/root/SceneManager")` checks in
  `outpost_presenter.gd` are legitimate optional-autoload presence guards (the established codebase pattern), not dead
  probes.

Findings (both non-blocking):

- [x] [Review][Decision] **The standalone hero-select scene (`hero_select_presenter.gd`) is NOT profile-aware — it builds
  `HeroSelectViewModel.new()` (no profile, line 30) and calls `controller.start(seed, false, class_id)` (no profile,
  line 102).** So a spend-unlocked class would appear locked in the STANDALONE hero-select flow, while the OUTPOST flow
  (the surface 11.6 explicitly chose) correctly reflects it via `OutpostViewModel` → the profile-aware VM (wired +
  tested end-to-end through `OutpostSpendBridge`). This is INTERNALLY CONSISTENT (the standalone scene's VM grey-out and
  its start gate are BOTH static — there is no mis-enabled-confirm hazard) and has ZERO player-visible effect in v0 (the
  two unlockable classes necromancer/shadeblade carry no kit content, so they cannot be started until the class-kit
  content story lands — the already-recorded v0 limitation). AC2's verification is met at the unit level (the
  profile-aware VM + command are proven). But it is a real forward-looking wiring gap: once class-kit content exists, the
  standalone hero-select scene must thread the loaded profile into both the VM and `controller.start(...)` or a genuinely
  unlocked class will read locked there. HUMAN CALL: wire the standalone hero-select scene's profile-awareness now (small:
  load the profile in `hero_select_presenter._ready` and thread it) or defer it to the class-kit content story that first
  makes it observable. Recommended: defer (bundle with the kit content that makes it testable/observable), and record it.
  Resolved 2026-07-06: deferred to the class-kit content story per human direction (recorded as a `[Review][Defer]` entry in `deferred-work.md`).
- [Review][Defer] **`OutpostRenderView.class_unlock_options()` instantiates a fresh
  `ClassRepository.create_baseline_repository()` on every call, and `has_affordable_unlock()` calls
  `class_unlock_options()` (which rebuilds the repo + re-derives the whole option list) just to check a boolean.** A
  minor, non-correctness inefficiency on the outpost render path (a display-name lookup + a roll-up), off the hot
  gameplay loop and drawing ZERO RNG — no functional impact. Consider caching the baseline repository or the derived
  option list on the render view, and having `has_affordable_unlock()` short-circuit without the repo build. Defer as
  cleanup — not worth churn in this story.

**Round 2 of 3**

Secondary independent adversarial code review (2026-07-06, Opus 4.8 delegate, a DIFFERENT model pass than Round 1 for
review diversity). Re-reviewed the current branch's diff against `main` (excluding `_bmad`, `_bmad-output/auto-gds`,
cache/non-code files) with this story as the spec — the ENTIRE core surface re-scrutinized from scratch, not merely a
Round-1 spot-check. Independently re-ran the full headless suite: **"Headless tests passed." / 182 PASS / 0 `^FAIL`**,
false-PASS grep (`SCRIPT ERROR|Parse Error|^FAIL`) clean, EXACTLY the 6 documented stderr negatives enumerated from raw
`^ERROR:` lines (int64-overflow ×2 [lines 58/99], `invalid_node_type` ×1 [line 138], malformed-JSON ×3 [lines
156/165/180]) — the `test_outpost_spend_bridge` forced write-failure (missing-dir path) produced NO new stderr negative
(the silent-structured-code claim re-confirmed at the raw-ERROR level); `git diff --check` clean.

**Verdict: Approve.** Critical 0 / High 0 / Med 0 / Low 1. Open `[Review][Decision]`: 0. No code-change finding.

Round 1 dispositions VERIFIED in place: (a) the standalone hero-select profile-awareness Decision is ticked in the story
(line 875) and recorded as a `[Review][Defer]` in `deferred-work.md` (lines 15-25) bundled with the class-kit content
story — confirmed present, not reopened; (b) the `OutpostRenderView` per-render `ClassRepository` rebuild Defer is
ledgered as cleanup (`deferred-work.md` lines 9-13) — confirmed present, not reopened.

Independent re-verification of the core 11-6 surface (all re-checked against source this round, not inherited from Round
1):
- **SpendOathShardsCommand (VERIFIED):** `sequence_id <= 0` rejected FIRST (`invalid_event_sequence_id`), then null
  profile (`invalid_context`), then `unknown_unlock` (fail-closed on a non-`CLASS_UNLOCKS` id), then
  `unlock_already_applied` (the applied-flag idempotency no-op — ZERO charge/ZERO event, which IS the retry-safety), then
  `insufficient_oath_shards` (shortfall in `metadata`, ZERO mutation, checked BEFORE the subtract so a spend can never
  drive negative). Event built ONLY after mutation; ZERO RNG. `execute` re-calls `validate` first (no
  validate-bypass path). Every reject proven byte-identical via `to_dictionary()` equality in
  `test_spend_oath_shards_command.gd`. Retry-math is net-correct on BOTH branches: write-success → persisted flag →
  retry rejects `unlock_already_applied`; write-failure → flag NOT persisted → retry re-charges against the ORIGINAL
  on-disk balance (a single honest charge, not a double-charge).
- **MetaSpendRules as the SINGLE selectability source (VERIFIED — grepped every `is_selectable`/`unlocked_class_ids_for`/
  `lock_state` in `godot/scripts`):** `unlocked_class_ids_for` has EXACTLY two live readers — `hero_select_view_model.gd:69`
  (the overlay, derived once in `_init`) and `run_start_command.gd:262` (the authoritative gate) — both funnel through a
  VERBATIM-mirrored `_class_is_selectable(def)` (`static is_selectable() OR overlay.has(class_id)`). No third derivation
  exists. `class_start_summary_view_model.gd:176` reads static `is_selectable()` but is NOT a selectability GATE — it is
  `re_derive_kit`, a fail-closed RESUME-time kit re-derivation for a class that ALREADY passed the authoritative gate;
  it is downstream of the same class-kit content gap and is captured as a new Round-2 Defer bundled with that story.
- **Static-content invariant (VERIFIED):** no write to `ClassDefinition.lock_state` anywhere; the applied-unlock is a
  pure profile-read OVERLAY. `OutpostViewModel` threads its EXISTING `resolved_profile` (null → `ProfileSnapshot.fresh()`,
  empty `unlock_progress`) into the composed VM — `DICTIONARY_KEYS`/`ENTRY_KEYS` unchanged; no positional-arg re-shift.
- **`oath_shards_spent` event (VERIFIED end-to-end):** enum TAIL index 48 (`OATH_SHARDS_SPENT` after `BOSS_DEFEATED`),
  `EVENT_ID_*` const, factory, `_validate_payload_for_event` arm, `_validate_oath_shards_spent_payload` (honest-record
  `before - amount == after` AND independent non-negative `after` floor AND `amount > 0` AND allowlisted lower_snake
  `reason`), both id maps, `OATH_SHARDS_SPENT_REASONS` allowlist, AND the `expected_ids` pin + the `expected_ids.size()
  == Type.size() - 1` enum-count tripwire (`test_domain_event.gd:3024/3039`). The `negative_after` malformed test
  (`{before:1, amount:3, after:-2}`) correctly proves the non-negative floor catches a case the arithmetic check alone
  passes. 5 malformed cases + a JSON round-trip + a ZERO-RNG (no roll/draw_index) assertion. Deterministic system event
  (no actor).
- **`unlock_progress` storage / no schema bump (VERIFIED):** `<class>_unlocked` flags + the underscore-namespaced
  `_oath_shards_spent` ledger live inside the existing `unlock_progress` home; `profile_snapshot.gd` UNTOUCHED
  (`SCHEMA_VERSION == 1`, `DICTIONARY_KEYS` unchanged). Real `JSON.stringify → parse_string → ProfileSnapshot.parse`
  round-trip proven (`test_profile_snapshot.gd`) + an end-to-end persist→fresh-repository-restart→reload in
  `test_meta_summary_save_load.gd`; the ledger is int-coercion-aware (`oath_shards_spent_in` handles the JSON
  int→float artifact — the 8.7 `class_mastery` lesson). A pre-11.6 profile lacking these keys reads clean via
  `get(..., default)` (the empty-`unlock_progress` cases are tested).
- **Optional-trailing-arg additions (VERIFIED — no missed callers / no arg-order error):** `HeroSelectViewModel`
  (+profile pos 2), `RunStartCommand` (+profile pos 9 — `RunOrchestrator.start` passes `.new(seed, manual, seq,
  class_id, null, null, null, null, profile)`, the four nulls landing on the class/weapon/support/passive repos, verified
  against the `_init` signature), `RunOrchestrator.start` / `RunFlowController.start` (+trailing profile). Every existing
  `.start(...)` / `HeroSelectViewModel.new(...)` caller omits the new arg → the null-profile static path (byte-identical).
  `RunFlowController.start` uses an UNTYPED `profile = null` pass-through (no `ProfileSnapshot` preload in that file) —
  a deliberate, correct choice (the arg is forwarded to the typed `RunOrchestrator.start`), not a defect.
- **FR28 (VERIFIED structural):** the exclusion lives on the AWARD side (`AwardMetaProgressCommand` Gate 2 denies a
  manual-seed run). The spend ONLY subtracts and cannot fabricate shards (`_spend_cannot_fabricate_shards_fr28` asserts a
  strict decrease). No redundant manual-seed gate on the spend — correct.
- **Determinism / fingerprints (VERIFIED):** ZERO RNG across the whole spend/apply surface; no
  generator/`RunSnapshot`/`RngStreamSet`/`SettingsSnapshot` touch; `run_orchestrator.gd`'s sole change is the additive
  optional `profile` arg (default unchanged → fingerprint-safe). The full suite (incl. every seed-regression + the
  default `run_to_completion`) is green.
- **Caller-ordering / idempotency (VERIFIED):** `test_meta_summary_save_load._spend_interleaved_with_run_end_markers`
  runs award→spend→merge→first-victory vs first-victory→merge→spend→award and asserts IDENTICAL final profiles — the
  strongest AC3 ordering proof. A spend reads/writes none of the four run-end markers (proven).
- **Dead has_method/probe sweep (VERIFIED clean):** no `has_method`/`.call(` probes in any new/modified spend file. The
  `has_node("/root/Diagnostics|GameSession|SceneManager")` checks in `outpost_presenter.gd` (incl. the new
  `_on_spend_pressed` diagnostic) are legitimate optional-autoload presence guards, not dead probes. The presenter
  submits a spend REQUEST to `OutpostSpendBridge.spend(unlock_id)` and rebuilds off the returned persisted outpost — it
  never mutates the profile directly.

Findings (one, non-blocking, new this round):

- [Review][Defer] **`ClassStartSummaryViewModel.re_derive_kit` (`class_start_summary_view_model.gd:176`) gates on the
  STATIC `def.is_selectable()`, so it re-derives `null` for a profile-UNLOCKED formerly-locked class.** This is a sibling
  of the Round-1 standalone-hero-select Defer: it is the RESUME-time kit re-derivation, reached only AFTER a run already
  started with that class. In v0 it has ZERO observable effect (the two unlockable classes necromancer/shadeblade carry
  no kit content, so no unlocked run can start — the already-recorded class-kit content limitation), and it is internally
  consistent (a class with no kit cannot be running to resume). But once the Necromancer/Shadeblade class-kit content
  lands and an unlocked locked-baseline class can genuinely start + be resumed, `re_derive_kit` must become profile-aware
  (or the resume re-derives a null kit for a legitimately-unlocked class). Defer bundled with the SAME class-kit content
  story that owns the standalone-hero-select profile-awareness Defer — it is subsumed by that story's scope, reopens no
  accepted deferral. Not worth churn in this story (no v0 code path reaches it).
