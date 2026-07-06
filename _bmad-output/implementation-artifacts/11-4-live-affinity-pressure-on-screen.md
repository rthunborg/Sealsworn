---
baseline_commit: b5edc5e
---

# Story 11.4: Live Affinity Pressure On Screen

Status: review

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a player,
I want affinity levels to feel different and dangerous in real play,
so that Scorched, Flooded, Cursed, and Darkness change my tactical choices, not just visuals.

## Story Type & Scope Boundary (READ FIRST)

**This IS a CODE story — the AFFINITY LIVE-WIRING + on-screen-treatment story of Epic 11.** Every affinity
story from Epic 7 (7.4 assignment, 7.5 Scorched/Flooded/Cursed effects, 7.6 Darkness) built its effect as a
**BOARD-SCOPED, CALLER-DRIVEN** pure-domain surface and PARKED the "enter node → instantiate a live board →
apply the affinity → play turns" **call site** behind "a later HUD/run-flow / live-tactical-loop story." 11.2
built that live loop (`LiveCombatResolver` + the additive `RunOrchestrator` live methods) but ran a **plain**
generated level (`assign_affinity` stays un-wired). 11.3 built the on-screen shell + HUD but likewise ran a
plain level (hard scope fence: "No live affinity call sites / affinity VFX — that is 11.4"). **11.4 is that
story: it gives the Epic-7 affinity EFFECTS their FIRST LIVE CALL SITES on the live board, and surfaces the
affinity + its rule on the board/HUD/inspect so the player reads the danger before and during play.**

- **The as-built starting point (verify by reading — the effect surfaces already EXIST, un-called):**
  - **Assignment** — `RunOrchestrator.assign_affinity(node, stream_name)` (`run_orchestrator.gd:691`) draws ONE
    `map`-stream roll, records the selected id on `RunState.assigned_affinities[node_id]`, fail-closes on
    unseated/null-node/empty-repo/unknown-id. **CALLER-DRIVEN — NOT wired into any resolve path today.**
    `assigned_affinity_for(node_id)` (`:739`) reads it back (`none` when unassigned).
  - **Scorched / Flooded / Cursed effects** — `AffinityEffectResolver`
    (`scripts/rules/operations/affinity_effect_resolver.gd`): `resolve_board_plan(board, id, repo)` (pure
    plan — hazard/conductive/pathing cells + cues + explanation), `apply_board_effects(board, id, repo)`
    (stamps Scorched `Terrain.HAZARD` cells; Flooded/Cursed/Darkness/neutral mutate nothing), and the static
    `cursed_affinity_rule_source(id, repo)` (a `CurseDefinition` the caller seats on the run's `RulesResolver`).
  - **Scorched DoT tick** — `AffinityHazardDamageCommand` (`scripts/core/commands/affinity_hazard_damage_command.gd`):
    a validated board command, actor==target, fixed `DEFAULT_HAZARD_AMOUNT = 2`, `damage_type = burning`,
    emits the EXISTING `DAMAGE_APPLIED` event, ZERO RNG, validate-then-mutate. Rejects
    `target_not_in_hazard` if the entity is not on a HAZARD cell.
  - **Darkness effect** — `DarknessVisibilityLayer` (`scripts/tactical/fog/darkness_visibility_layer.gd`):
    `is_darkness(id, repo)`, `reduced_radius_for(...)` (authored 4→2, floor 1), `calculate_visible_cells(...)`
    (reuses `TacticalVisibilityQuery` at the reduced radius), `visible_facts_for_cell(...)` (additive
    memory-uncertainty annotation on the `memory` state only).
  - **Darkness fairness authority** — `DarknessFairnessQuery` (`scripts/generation/level/darkness_fairness_query.gd`):
    `check_board(board, id, repo, seed, entrance)` — re-asserts "no unavoidable damage from unseen space" at the
    reduced radius; fails loud with `fairness_reason` + `seed` + `phase`. Non-Darkness → legal `not_applicable`.
  - **Read surfaces** — `AffinityViewModel.project_affinity(id)` (pinned `MODAL_KEYS`), `DarknessReadView.project_darkness(id)`
    (pinned `MODAL_KEYS`), `AffinityPreviewQuery.preview_board(board, id, repo)` (the explainability surface;
    reads the SAME resolver plan so preview can never disagree with the applied effect).
  - **Live combat seam (11.2 — where the affinity must be wired)** — `RunOrchestrator.resolve_combat_node_live(node, hero_hp, hero_weapon_id)`
    (`run_orchestrator.gd:945`) restores a **plain** `BoardState` from `generation.payload["board"]` and drives
    `LiveCombatResolver.new(...).resolve(...)` — it does NOT assign an affinity, stamp Scorched hazard cells,
    seat a Cursed rule source, or reduce Darkness LoS. **This is 11.4's primary call site.**
  - **On-screen shell (11.3)** — `gameplay_shell_presenter.gd` AUTO-RESOLVES each live node (L3/L4 scope line);
    `tactical_board_presenter.gd` renders `TacticalBoardViewModel` slots + the G1 `RunHudViewModel` into the
    region panels. **Neither surfaces any affinity today** (the board VM has no affinity slot).
  - **Assets (already merged to `main`, referenced via `visual_tags` — do NOT re-author):**
    `godot/assets/tiles/affinities/affinity.scorched.png`, `affinity.flooded.png`, `affinity.cursed.png`,
    `affinity.darkness.png`. All 5 affinity accessibility cues already live in
    `TacticalAccessibilityModel._CUE_CATALOG` (3 from 7.5, 2 from 7.6), each with a non-color channel.

- **What 11.4 delivers (three AC groups):**
  1. **Live affinity call sites (AC1)** — a live level that carries an affinity applies the Epic-7 effects on
     the live board: **Darkness** visibility/memory pressure (reduced LoS + uncertain memory), **Scorched**
     damage-over-time (hazard cells stamped + the DoT tick fires for an entity that lingers), **Cursed**
     rule-source (seated on the run's `RulesResolver`), **Flooded** per its ratified MVP placeholder posture
     (conductive-danger + pathing-pressure marks, the `_placeholder` electric interaction UNCHANGED). Live
     effects **match the headless-proven deterministic behavior** (FR57) — the live path CALLS the existing
     surfaces; it does NOT fork a parallel effect.
  2. **On-screen affinity read + treatment (AC2)** — the board/HUD present the approved affinity treatment +
     readability cues so the affinity and its rule are **visible before and during play** (FR55), and
     telegraphed danger stays **inspectable through the existing inspect flow** (FR12, FR58) — the affinity
     hazard/danger cells and their non-color cues surface on the board and via the inspect read.
  3. **Darkness fairness on the live path (AC3)** — the 7.6 fairness guardrails hold on the live board (no
     unavoidable damage from unseen space), and the **`DarknessFairnessQuery` remains the single authority the
     HUD reflects** — the HUD reads the fairness verdict; it does not re-derive one.

- **What 11.4 does NOT do (hard scope fences — do not cross):**
  - **No new affinity CONTENT, no new effect, no new fairness rule.** Every effect/read surface ALREADY exists
    (enumerated above). 11.4 WIRES the call sites + surfaces the reads; it does NOT author a new
    `AffinityDefinition`, a new `tactical_rules` marker, a new hazard model, a new Darkness radius, or a new
    cue. If you believe a new effect is needed, STOP — it is 7.5/7.6's already-shipped surface you must CALL.
  - **No live water/electric interaction.** Flooded stays its **ratified MVP placeholder** — the deterministic
    conductive-danger + pathing-pressure MARKS surface (data-only, the `_placeholder` cue/visual/explanation
    ids UNCHANGED). Realizing the live electric chain is the **Epic-10 readiness item**, NOT 11.4. Do NOT
    replace the placeholder or drop its `_placeholder` marker.
  - **No new save key, no schema bump, no new RNG stream, no new fingerprint, no new event.** The 23-key
    `RunSnapshot` gate stays 23; `ProfileSnapshot`/`SettingsSnapshot` `SCHEMA_VERSION == 1`; the 7 named RNG
    streams (`map`/`level`/`combat`/`loot`/`rewards`/`events`/`cosmetic`) are untouched; every pinned
    level/route/arena/finale seed-regression fingerprint stays byte-identical; the `DomainEvent.Type` enum tail
    is UNCHANGED (Scorched DoT REUSES `DAMAGE_APPLIED`; the reduced-radius visible set REUSES the existing
    visibility path; NO affinity event exists or is added). The affinity is LIVE re-derivable from
    `(assigned affinity, board)`; the assigned id already rides the `RunSnapshot.affinities` mirror (7.4).
  - **No difficulty knob.** An affinity effect is authored, bounded tactical PRESSURE surfaced HONESTLY (hazard
    cells, a fixed DoT amount, a bounded reduced radius, a conductive mark) — NEVER a hidden multiplier scaling
    enemy stats/HP/damage/rewards/RNG/run length (the ratified HARD non-goal).
  - **No outpost scene / reveal render / meta-spend** (11.5 / 11.6). No affinity-driven GENERATION modifier
    ("enter a cursed node for better reward odds" / reward-odds / elite-rate / spawn changes) — that is the
    separate later generation-modifier story; 11.4 applies TACTICAL affinity pressure on a built board, it does
    NOT wire an affinity into `RewardOfferBuilder`/reward tables/`EntityRewardPlacer`.

## Acceptance Criteria

Sourced verbatim from `epics.md` (Epic 11, Story 11.4, lines ~2674-2695). Three AC groups (Given/When/Then + And):

1. **Live affinity call sites (AC1).** GIVEN a run level carries an affinity, WHEN the level is played live,
   THEN the Epic-7 affinity effects receive their first live call sites (Darkness visibility/memory pressure,
   Scorched damage-over-time, Cursed rule-source, Flooded per its ratified MVP placeholder posture) — AND live
   effects match the headless-proven deterministic behavior (FR57).

2. **On-screen affinity read + treatment (AC2).** GIVEN an affinity is active, WHEN the board and HUD present
   it, THEN the approved affinity treatments and readability cues make the affinity and its rule visible before
   and during play (FR55) — AND telegraphed danger remains inspectable through the existing inspect flow (FR12,
   FR58).

3. **Darkness fairness on the live path (AC3).** GIVEN Darkness is active in live play, WHEN fairness
   invariants are exercised on the live path, THEN the 7.6 fairness guardrails hold (no unavoidable damage from
   unseen space) — AND the darkness fairness queries remain the single authority the HUD reflects.

### AC Verification (how "done" is checked)

- **AC1** — a live combat/elite node that has an assigned affinity applies the effect on the live board through
  the EXISTING surfaces, and a headless test proves each effect matches its 7.5/7.6 headless behavior on a
  VERIFIED seed:
  - **Assignment call site:** the live resolve path calls `assign_affinity(node)` (or reads
    `assigned_affinity_for(node.id)`) so the live board carries the node's affinity. The assignment draws
    EXCLUSIVELY through the run-level `streams` on `map` (NEVER `randi`/`randf`), so it is a pure deterministic
    function of `(root_seed, route position)`. It fires ONCE per node (an assign-if-absent guard — see the
    7.4-carried idempotency note) so a re-drive never re-rolls the affinity.
  - **Scorched:** `AffinityEffectResolver.apply_board_effects(board, scorched, repo)` stamps the hazard cells
    onto the live board BEFORE the fight; `AffinityHazardDamageCommand` fires the DoT for an entity that ends a
    turn on a HAZARD cell — a `DAMAGE_APPLIED(damage_type=burning, weapon_id=scorched_hazard)` event with the
    fixed amount, ZERO RNG.
  - **Darkness:** the live visible set is computed via `DarknessVisibilityLayer.calculate_visible_cells(...)`
    at the reduced radius (not the baseline query directly), and `visible_facts_for_cell(...)` annotates
    `memory`-state cells as uncertain — proven to match the 7.6 reduced-radius + memory-uncertainty behavior.
  - **Cursed:** `AffinityEffectResolver.cursed_affinity_rule_source(cursed, repo)` is seated on the run's
    `RulesResolver` (`register_curse`) so the kernel resolves + explains the Cursed pressure via `explain(window)`.
  - **Flooded:** the conductive-danger + pathing-pressure MARKS surface via `resolve_board_plan` /
    `AffinityPreviewQuery.preview_board`; the `_placeholder` electric interaction stays UNCHANGED (a test
    asserts the `_placeholder` cue/visual ids are still present + distinct-from-final).
  - Determinism (FR57): a fixed seed produces a byte-identical live-affinity outcome (same effect cells + same
    events + same reduced radius); the live effect CALLS the same resolver plan the headless tests pin.
- **AC2** — the tactical board + HUD surface the affinity: the affinity id/display-name/rule + the
  affinity-affected cells + their non-color cues render on the board/HUD, and the inspect flow surfaces the
  affinity hazard/danger + telegraphed danger on an inspected cell (through the EXISTING `TacticalInspectView`
  `hazards`/`telegraphs`/`cue_ids` fields + the `AffinityPreviewQuery` cells — NOT a parallel inspect path).
  The affinity treatment binds the approved `visual_tags` / `affinity.*.png` assets (an id/tag hook, not a new
  art author). Every affinity's critical danger is non-color (the cue catalog channels). Verified by: (a) a
  headless test over the affinity read/preview surfaces the board reads (the affinity VM + `AffinityPreviewQuery`
  + `DarknessReadView` cell/cue projections); (b) a code-level audit that the affinity render/inspect reads the
  existing pinned surfaces + submits nothing (a read-only presentation binding, no domain mutation).
- **AC3** — a live Darkness node runs `DarknessFairnessQuery.check_board(board, darkness, repo, seed, entrance)`
  on the live board (a fair board PASSES by construction — v0 generated boards are all-FLOOR; a Scorched-stamped
  Darkness board is fairness-checked at the reduced radius), and the HUD reflects the fairness verdict the query
  returns (it does not compute its own). A headless test proves the fairness check runs on the live path and the
  HUD read is the query's verdict (the single-authority contract). The check consumes NO RNG, runs NO command,
  advances NO turn.
- **AC-wide (invariants)** — full headless suite green (`godot --headless … test_runner.tscn`), false-PASS grep
  clean beyond the 6 documented negatives; `git diff --check` clean. `RunSnapshot` 23-key gate == 23;
  `ProfileSnapshot`/`SettingsSnapshot` `SCHEMA_VERSION == 1`; `RngStreamSet.required_streams()` == 7; every
  `tools/dump_*` seed-regression fingerprint byte-identical; `domain_event.gd` UNCHANGED (no new event).

## Tasks / Subtasks

- [x] **Task 1 — Wire the affinity assignment + effect application into the live combat node (AC1)**
  - [x] In the live combat resolve path (`RunOrchestrator.resolve_combat_node_live`, `run_orchestrator.gd:945`,
        after `NodeEnterCommand` + `LevelGenerator.generate` succeed and BEFORE
        `LiveCombatResolver.new(...).resolve(...)` at `:968`), **assign the node's affinity ONCE** (call
        `assign_affinity(node)` if `assigned_affinity_for(node.id)` is neutral/absent — the assign-if-absent
        guard the 7.4 review deferred to "the later run-flow / per-node-assign story"; that is 11.4). The
        assignment draws through the run-level `streams` on the `map` stream — do NOT re-roll on a re-drive
        (idempotency). Read the resolved affinity id back via `assigned_affinity_for(node.id)`.
  - [x] **Apply the board effects to the LIVE board** the resolver plays on. The seam: the live board is
        restored INSIDE `LiveCombatResolver.resolve` today from `payload["board"]`. Two acceptable shapes —
        pick the one that keeps `LiveCombatResolver` scene-free + the fingerprints unmoved: (a) pass the
        assigned affinity id into a NEW optional `LiveCombatResolver.resolve(..., affinity_id, affinity_repo)`
        parameter (defaulting to neutral `none` — so the EXISTING 11.2/11.3 callers stay byte-identical) and
        apply `AffinityEffectResolver.apply_board_effects(board, affinity_id, repo)` on the restored board
        before the hero is placed; OR (b) apply the effect in the orchestrator on the board the resolver
        returns. **Scorched** stamps `Terrain.HAZARD` cells (the ONLY board mutation); **Flooded/Cursed/Darkness/neutral**
        stamp nothing (their effects are data/kernel/visibility, not terrain). Adopt the fail-closed
        validate-then-reject discipline (a rejected stamp aborts with ZERO partial mutation — `apply_board_effects`
        already does this; surface its error). Preserve the FR58 fairness: hazard cells are only ever eligible
        FLOOR + UNOCCUPIED cells (never a spawn cell — the resolver guarantees this by construction).
  - [x] **Scorched DoT tick on the live board (AC1):** wire `AffinityHazardDamageCommand` so an entity that
        ENDS a turn on a Scorched HAZARD cell takes the fixed `burning` DoT (a `DAMAGE_APPLIED` event, ZERO
        RNG). The tick is environmental (actor==target). Decide the tick cadence at a per-turn boundary in the
        live loop (e.g. after the hero's move/attack resolves + after each enemy that occupies a hazard cell) —
        keep it deterministic + fairness-safe (the hazard is SEEN + avoidable; the command rejects
        `target_not_in_hazard` for a non-hazard cell, so a non-Scorched board never ticks). A live hero death
        BY the DoT flows through the EXISTING `CombatOutcomeEvaluator` → `STATE_DEFEAT` → the 11.2 hero-death
        source (do NOT add a parallel death path).
  - [x] **Darkness on the live board (AC1):** compute the live visible set via
        `DarknessVisibilityLayer.calculate_visible_cells(query, board, origin, darkness, repo)` at the reduced
        radius (the LoS the hero sees under Darkness) rather than the baseline `TacticalVisibilityQuery` radius,
        and surface `visible_facts_for_cell(...)` for the memory-uncertainty read. NOTE: `LiveCombatResolver`
        currently marks the whole board `visible = true` (headless full-vis — fog does not decide the outcome);
        for a Darkness level the affinity's visibility PRESSURE is what the HUD/inspect reads (the reduced
        radius + memory uncertainty) — wire the Darkness visibility read for the HUD/inspect surface (AC2/AC3),
        keeping the CombatOutcomeEvaluator's HP-only terminal check unchanged.
  - [x] **Cursed on the live run (AC1):** seat `AffinityEffectResolver.cursed_affinity_rule_source(cursed, repo)`
        on the run's live `RulesResolver` — `RunState.rules_resolver` (`run_state.gd:94`) is the seam; call
        `run.rules_resolver.register_curse(rule_source)` (`rules_resolver.gd:53`) so the kernel resolves +
        explains the Cursed pressure (v0 is RESOLVE+EXPLAIN — it surfaces + explains via `explain(LEVEL_ENTERED)`,
        it does NOT mutate a live combat HP/damage number). This is a NEW seating call site (the only existing
        `register_curse` callers are the cursed-REWARD path — `accept_cursed_reward_command.gd` — NOT an affinity
        path). The economy-side curse-count penalty applies through the EXISTING 7.1 `RiskEconomyState` API if
        the story wires it — verify against 7.5's contract; do NOT invent a new penalty. **A seated Cursed rule
        source must be RE-DERIVED on a route-position resume** — `RunState.rules_resolver` is explicitly "live
        re-derivable, not serialized" (`run_state.gd:516`), so a resumed Cursed level must re-seat the rule
        source (the 7.5-carried
        obligation — the affinity id is recoverable from the persisted `RunSnapshot.affinities` mirror /
        re-derivable from the seed; the `RulesResolver` is deliberately not serialized). If 11.4 wires the live
        resume of a seated Cursed level, re-derive the rule source on resume; if not, RE-RECORD the obligation.
  - [x] **Flooded on the live board (AC1):** surface the conductive-danger + pathing-pressure MARKS via
        `resolve_board_plan` / `AffinityPreviewQuery.preview_board` (data-only — NOT terrain). The
        `_placeholder` electric interaction stays UNCHANGED (do NOT realize the live water/electric chain — the
        Epic-10 readiness item). Keep the `affinity_conductive_danger_placeholder` cue + the
        `affinity_conductive_danger_placeholder_vfx` visual id distinct-from-final.
  - [x] **Determinism guard (AC1/FR57):** the live affinity path draws gameplay RNG ONLY through the run-level
        `RngStreamSet` (the assignment on `map`; the DoT/effects are ZERO-RNG) — NEVER `randi`/`randf`/a fresh
        `RandomNumberGenerator`. A test asserts a fixed seed produces a byte-identical live-affinity outcome
        (same effect cells + same events + same reduced radius) and that a neutral `none` level is byte-identical
        to today's plain live combat (the 11.2/11.3 fingerprints + live-combat tests stay green).

- [x] **Task 2 — Surface the affinity on the board + HUD + inspect (AC2)**
  - [x] **Affinity read on the HUD/board:** surface the active affinity's id/display-name/rule +
        affinity-affected cells + non-color cues on the on-screen surface. Bind the EXISTING read surfaces —
        `AffinityViewModel.project_affinity(id)` (pinned `MODAL_KEYS = has_affinity, affinity_id, display_name,
        explanation, is_neutral, tactical_rules, visual_tags`), `DarknessReadView.project_darkness(id)` (pinned
        `MODAL_KEYS = has_darkness, affinity_id, baseline_radius, reduced_radius, memory_uncertain, explanation,
        cue_ids`), and `AffinityPreviewQuery.preview_board(board, id, repo)` (the affinity-affected cells + cues
        + explanation). The board surface reads these; it does NOT reach into scene state or mutate the board.
        Decide how the affinity read reaches the presenter: either a thin RefCounted aggregation the board
        presenter reads (mirroring 11.3's G1 `RunHudViewModel` posture — fail-closed, exact-key, no live-handle
        leak, mints no event, consumes no RNG) OR by reading the existing per-affinity VMs directly in the
        presenter. **Do NOT add a new key to `TacticalBoardViewModel`'s pinned top-level set** (the board VM's
        exact-key discipline — a key outside the pinned set is an AC2 violation); if an aggregation is added it
        is a SEPARATE read surface the HUD `status`/`log_or_outcome` region composes, exactly like G1.
  - [x] **Approved treatment binding:** bind the approved affinity treatment assets via the `visual_tags` /
        `affinity.*.png` id hooks (`affinity.scorched.png` / `affinity.flooded.png` / `affinity.cursed.png` /
        `affinity.darkness.png`, already merged to `main`). `icon`/`visual_tags` are id/tag STRINGS the
        presenter maps to the asset — do NOT author new art, do NOT treat a tag as a texture path outside the
        approved kit. The affinity + its rule must read BEFORE play (a badge/label on the board/HUD) and DURING
        play (the affected cells + cues). Every critical affinity meaning carries a non-color channel (the
        `TacticalAccessibilityModel._CUE_CATALOG` channels: Scorched icon/label/text, conductive shape/label/text,
        pathing pattern/label, Darkness-reduced icon/label/text, Darkness-memory pattern/label/text).
  - [x] **Inspect surfaces the affinity danger (AC2 — FR12/FR58):** the affinity hazard/danger + telegraphed
        danger must be inspectable through the EXISTING inspect flow. `TacticalInspectView.from_context(...)`
        already exposes `hazards`, `telegraphs`, `cue_ids`, `visibility_state`; the inspected cell's affinity
        pressure (a Scorched HAZARD cell / a Flooded conductive/pathing mark / a Darkness memory-uncertain cell)
        surfaces through these fields + the `AffinityPreviewQuery`/`DarknessReadView` cue reads — the scene MAPS
        the emitted cue_ids to visuals, it invents no new reason/cue. Do NOT fork a parallel affinity-inspect
        path.
  - [x] **Render neutral fail-closed:** a neutral `none` level (or an unresolved affinity id) surfaces the
        legal empty read (`has_affinity: false` / `has_darkness: false` / an empty-effect preview) — the HUD
        renders "no affinity" rather than a crash or a half-badge (the read surfaces already fail-close; the
        presenter branches on the `has_*` gate).

- [x] **Task 3 — Darkness fairness on the live path + the HUD single-authority (AC3)**
  - [x] **Run the fairness check on the live Darkness board:** in the live Darkness path, run
        `DarknessFairnessQuery.check_board(board, darkness, repo, seed, entrance)` on the live board (the seed
        is the level seed String from `generation.payload["level_seed"]`; the entrance is
        `generation.payload["entrance"]`). A fair board PASSES (v0 generated boards are all-FLOOR → no unseen
        hazard by construction; a Scorched-stamped Darkness board is re-checked at the reduced radius). A
        `darkness_fairness_violation` (fail-loud with `fairness_reason` + `seed` + `phase`) is a hard
        run-progression error — surface it structurally + STOP (no partial progression), mirroring
        `live_combat_failed` (`run_orchestrator.gd:978`). The check consumes NO RNG, runs NO command, advances
        NO turn (the pure-query contract).
  - [x] **The HUD reflects the query's verdict (the single-authority contract):** the HUD/inspect surface reads
        the `DarknessFairnessQuery` verdict (the pass report's reduced_radius + hazard counts / the failure's
        fairness_reason) — it does NOT compute its own fairness. The darkness fairness query stays the SINGLE
        authority the HUD reflects (AC3 second half). Keep `DarknessVisibilityLayer` + `DarknessFairnessQuery`
        the SAME sources the 7.6 tests pin — the live path CALLS them; it does not re-implement the radius/LoS
        reasoning.
  - [x] **Fairness on the live path is tested:** a headless test drives a live Darkness node (a verified seed)
        through the fairness check + asserts (a) a fair board passes on the live path, (b) an intentionally
        unfair Darkness board (a hand-built candidate with a reachable-but-unseen HAZARD at the reduced radius)
        fails loud with the stable `darkness_fairness_reason` + seed + phase, and (c) the HUD read equals the
        query verdict (the single-authority assertion). Extend the existing 7.6 fairness coverage
        (`test_darkness_fairness.gd`) rather than rebuilding it.

- [x] **Task 4 — Render the live board on-screen on a combat node (L3/L4 follow-up — pairs with 11.4)**
  - [x] The 11.3 Round-1 L3 + Round-2 L4 deferrals (both explicitly "pairs with Story 11.4") noted the shell
        AUTO-RESOLVES each live node and NEVER renders the live board on a combat node (`resolve_combat_node_live`
        returns terminal-only metadata with NO `"board"` key, so `gameplay_shell_presenter._drive_current_stage`
        only ever renders the empty between-levels VM). 11.4's live board treatment is the natural point to hold
        + render the live board across the fight. **Wire the shell to render the live affinity board on a combat
        node** so the affinity treatment/cues/hazard cells are actually visible on screen (the L4 fix): either
        (a) the live resolve path returns the live board (add a `"board": board` key to the victory/defeat
        metadata — verify it does not perturb any existing consumer / fingerprint) and the shell renders it, OR
        (b) the shell hosts the interactive tap-loop that holds the live board across taps (the L3 handoff).
        **Prefer the minimal option that surfaces the affinity board on screen** (rendering the live board with
        the affinity treatment is the AC2 on-screen requirement); the full auto-resolve→tap-loop handoff is a
        larger concern that MAY stay deferred if the affinity board renders correctly under auto-resolve.
        Whichever you pick, `tactical_board_presenter` reads the affinity surface (Task 2) so the board shows
        the affinity + its cells.
  - [x] **Boss arena affinity (decide + record):** the boss fight runs on a DISTINCT arena board
        (`auto_play_boss_fight`, `run_orchestrator.gd:1087` — restored from `boss_arena_payload()`, NOT a
        generated combat level). The MVP boss node's affinity treatment is OUT of the AC1 combat-node scope (the
        ACs say "a run level carries an affinity" — the pre-boss combat/elite levels). Decide whether the boss
        arena carries an affinity in 11.4; if NOT, record it as knowingly-parked (the arena is a fixed finale
        stage, not an affinity-assigned generated level). Do NOT silently apply an affinity to the boss arena
        without a decision.

- [x] **Task 5 — Invariants regression + full-suite green (AC-wide)**
  - [x] Re-verify every durable invariant is unmoved: the 23-key `RunSnapshot` gate (`test_run_snapshot.gd`),
        `ProfileSnapshot.SCHEMA_VERSION == 1` (`test_profile_snapshot.gd`), `SettingsSnapshot.SCHEMA_VERSION == 1`
        (`test_settings_snapshot.gd`), `RngStreamSet.required_streams()` == 7 (`test_rng_stream_set.gd`), the
        `DomainEvent.Type` enum tail UNCHANGED (`test_domain_event.gd` — Scorched DoT reuses `DAMAGE_APPLIED`;
        NO new event). The affinity is LIVE re-derivable — NO new save key.
  - [x] Re-run every seed-regression fingerprint suite + confirm byte-identical (small/medium level, route,
        seed batch, finale). 11.4 applies affinity effects POST-generation on a built board (Scorched stamps a
        built board; Flooded/Cursed/Darkness mutate no terrain) — the GENERATOR stays affinity-blind, so every
        `tools/dump_*` fingerprint stays byte-identical. The `WRINKLE_AFFINITY_PLACEHOLDER` stays INERT (no
        affinity baked into generated terrain — that WOULD move fingerprints). The DEFAULT `run_to_completion`
        (v0 auto-resolve) + the neutral-`none` live path stay byte-identical.
  - [x] Run the FULL headless suite via PowerShell (the `godot` binary is not on the Bash PATH — see Project
        Context Rules): `godot --headless --path C:\Sealsworn\godot --scene res://tests/headless/test_runner.tscn
        --quit-after 10`. Apply the false-PASS grep guard (the only acceptable stderr `ERROR:` lines are the 6
        documented negatives: int64-overflow ×2, malformed-JSON ×3, `invalid_node_type` ×1 — plus any NEW
        documented negative-path test 11.4 adds, e.g. a `darkness_fairness_violation` forcing case, which must
        be documented). Run `git diff --check`.

- [x] **Task 6 — Update the deferred-work ledger + tracking (AC-wide, hygiene)**
  - [x] In `deferred-work.md` (new 11.4 entry): mark **RESOLVED** — the **live AFFINITY call sites + affinity
        board treatment** (the fence carried across Epics 5/6/7 as "the later HUD/run-flow / live-tactical-loop
        story," re-recorded by 11.2 + 11.3); the **7.4 `assign_affinity` once-per-node idempotency guard** (the
        7.4-review-deferred "later run-flow / per-node-assign story" — 11.4 wires the per-node assign call site
        and MUST decide the assign-if-absent guard); and the **11.3 L3 (hand combat control to the tap-loop) +
        L4 (render the live board on a combat node)** deferrals to the extent 11.4 addresses them (render the
        affinity live board on screen). RE-RECORD still-open: the **Flooded `_placeholder` electric interaction**
        (Epic-10 readiness item — replace/de-scope/block; NOT 11.4's to realize), the **seated Cursed-affinity
        rule-source re-derive-on-resume** obligation (if 11.4 does not wire the live Cursed resume), the
        **affinity-driven GENERATION modifier** ("enter a cursed node for better reward odds" / reward-odds /
        elite-rate — the separate later generation-modifier story), the **outpost SCENE + reveal RENDER + G3**
        (11.5), the **meta-SPEND / unlock APPLICATION** (11.6), and the **boss-arena affinity** decision if
        parked. Note the originating story/date. Do NOT reopen or re-defer items unrelated to this story's
        surface.

## Dev Notes

### What this story is (and is not)

Epic 7 shipped every affinity EFFECT as a **board-scoped, caller-driven, headless-testable** pure-domain
surface — Scorched/Flooded/Cursed via 7.5 (`AffinityEffectResolver` + `AffinityHazardDamageCommand` +
`AffinityPreviewQuery`), Darkness via 7.6 (`DarknessVisibilityLayer` + `DarknessFairnessQuery` +
`DarknessReadView`), assignment via 7.4 (`assign_affinity` + `AffinityViewModel`) — and DELIBERATELY parked the
LIVE call site behind "a later HUD/run-flow / live-tactical-loop story." 11.2 built the live loop but ran a
plain level. 11.3 built the on-screen shell/HUD but ran a plain level (hard fence: "No live affinity call sites
— that is 11.4"). **11.4 is the affinity live-wiring story: it gives those effects their FIRST LIVE CALL SITES
on the live board, and it surfaces the affinity + rule on the board/HUD/inspect so the player reads the danger.**

**The single most important rule: WIRE THE EXISTING SURFACES; do not fork a parallel affinity path.** Every
effect, read, and fairness surface already exists (enumerated in the seam map). 11.4 CALLS them from the live
combat node + surfaces the reads on the on-screen board — it authors NO new affinity content, NO new effect, NO
new fairness rule, NO new event, NO new save key. Read the actual source before wiring — a wrong
method/constant/pinned-key name is the primary review-cycle cause (the 11.1 Round-1 review caught an HP field
mis-sourced on `RunState` + a `range` vs `weapon_reach` key mix-up; the 11.3 Round-2 review caught a dead
`has_method("current_text_scale")` probe that read as "wired"). Cite the EXACT as-built method/const/key names,
verified against source; grep every probed method name against source before trusting a guarded-accessor claim.

### The primary call site (the crux — read the source)

`RunOrchestrator.resolve_combat_node_live(node, hero_hp, hero_weapon_id)` (`run_orchestrator.gd:945`) is where
the affinity must be wired:
- `:949` `NodeEnterCommand` → `:955` `LevelGenerator.generate(request, recipe_repo, enemy_repo)` → **[here:
  assign + apply the affinity]** → `:968` `LiveCombatResolver.new(_enemy_repository).resolve(payload["board"],
  payload["entrance"], streams, hero_hp, hero_weapon_id)` → a terminal `CombatOutcomeState`.
- The resolver restores a **plain** `BoardState` from `payload["board"]` and drives the fight — it does NOT
  apply any affinity. 11.4 assigns the affinity (`assign_affinity(node)` if absent), applies the board effect
  (`AffinityEffectResolver.apply_board_effects`), seats the Cursed rule source, wires the Darkness reduced-LoS
  read, and fires the Scorched DoT tick — all through the EXISTING surfaces, all drawing RNG ONLY through the
  run-level `streams` on `map` (assignment) or ZERO RNG (effects).
- The 11.2/11.3 fingerprint-safety posture is load-bearing: a **neutral `none`** level must stay byte-identical
  to today's plain live combat (default the new affinity parameter to `none`; the existing callers + the
  live-combat / finale fingerprints stay green). The Scorched hazard is STAMPED onto a built board POST-generation
  — the GENERATOR stays affinity-blind (`WRINKLE_AFFINITY_PLACEHOLDER` stays INERT), so no seed-regression
  fingerprint moves.

### The seam map (the exact as-built pieces 11.4 binds to) — READ THE SOURCE

Read each before wiring; the method signatures / pinned key sets / constants are load-bearing. Absolute paths
are under `C:\Sealsworn\godot\`.

| Seam | Existing contract (method / pinned keys / const) | Path | Load-bearing detail |
|---|---|---|---|
| **Affinity assignment (the live call site's first step)** | `RunOrchestrator.assign_affinity(node, stream_name=STREAM_MAP) -> ActionResult` (records on `RunState.assigned_affinities[node_id]`); `assigned_affinity_for(node_id) -> StringName` (reads back; `none` when unassigned); `affinity_repository() -> AffinityRepository` | `scripts/run/run_orchestrator.gd:691`/`:739`/`:745` | Draws ONE `map`-stream roll (NEVER randi/randf). CALLER-DRIVEN — un-wired today. **No once-per-node guard yet** (7.4 review deferred it to "the later per-node-assign story" — that is 11.4; add an assign-if-absent guard). Fail-closed: `no_active_run`/`invalid_affinity_node`/`no_affinities_available`/`unknown_affinity`. |
| **Scorched/Flooded/Cursed effect resolver (pure plan + board mutation)** | `AffinityEffectResolver.resolve_board_plan(board, id, repo) -> Dictionary` (pure plan: `scorched_hazard_cells`/`conductive_danger_cells`/`pathing_pressure_cells`/`cues`/`explanation`/`has_effects`); `apply_board_effects(board, id, repo) -> ActionResult` (stamps Scorched HAZARD; others mutate nothing; validate-then-mutate, no partial); static `cursed_affinity_rule_source(id, repo) -> CurseDefinition` | `scripts/rules/operations/affinity_effect_resolver.gd` | The plan is the SINGLE source of "which cells" both the mutation AND the preview consume — preview can never disagree. Neutral/unknown/Cursed/Darkness → empty plan. Flooded conductive cue is the `_placeholder` id (Epic-10 readiness). |
| **Scorched DoT tick command (the live burning damage)** | `AffinityHazardDamageCommand.new(target_entity_id, hazard_amount=2)` over a `BoardState` → emits `DAMAGE_APPLIED(damage_type=burning, weapon_id=scorched_hazard)`; rejects `target_not_in_hazard` for a non-HAZARD cell | `scripts/core/commands/affinity_hazard_damage_command.gd` | actor==target (environmental DoT). ZERO RNG. `DEFAULT_HAZARD_AMOUNT = 2` (fixed authored content, NOT a difficulty scalar). validate-then-mutate; the DAMAGE_APPLIED payload is round-trip-safe. A live hero death by DoT flows through the EXISTING outcome evaluator → the 11.2 death source. |
| **Darkness visibility/memory layer** | `DarknessVisibilityLayer`: `is_darkness(id, repo) -> bool`; `reduced_radius_for(id, repo, baseline=4) -> int` (authored 4→2, floor 1); `calculate_visible_cells(query, board, origin, id, repo) -> ActionResult` (reuses `TacticalVisibilityQuery` at the reduced radius); `visible_facts_for_cell(query, board, cell, id, repo) -> ActionResult` (additive memory-uncertain annotation on `memory` state only) | `scripts/tactical/fog/darkness_visibility_layer.gd` | REUSES the existing LoS query — no parallel algorithm, no new event (a smaller `visible_cells` via the existing path). Cues `affinity_darkness_reduced_visibility`/`affinity_darkness_memory_uncertain` (FINAL ids). Fail-safe: a dropped marker disables the effect, no crash. |
| **Darkness fairness authority (AC3 single source)** | `DarknessFairnessQuery.check_board(board, id, repo, seed, entrance=Vector2i(-1,-1)) -> ActionResult` — PASS `{darkness_fairness_applicable, reduced_radius, hazard_count, reachable_seen_hazard_count}`; FAIL `darkness_fairness_violation` with `{fairness_reason, seed, phase, ...}`; non-Darkness → legal `not_applicable`; reasons `entrance_on_hazard`/`entity_on_entrance`/`darkness_unseen_hazard`/`invalid_darkness_candidate`; `phase_for_reason(reason)` | `scripts/generation/level/darkness_fairness_query.gd` | PURE query (no RNG/command/turn). v0 generated boards all-FLOOR → PASS by construction. The HUD REFLECTS this verdict (single authority — AC3). The seed is the level seed String (int64 decimal-string discipline). |
| **Affinity read VM (the on-screen affinity + rule)** | `AffinityViewModel.project_affinity(id) -> Dictionary` pinned `MODAL_KEYS = [has_affinity, affinity_id, display_name, explanation, is_neutral, tactical_rules, visual_tags]`; each rule pinned `RULE_KEYS = [rule_id, description]` | `scripts/ui/view_models/affinity_view_model.gd` | RECORD-ONLY descriptive data (NOT executed). `visual_tags` are the art/cue hooks 11.4 binds. Fail-closed: null/unresolved → `has_affinity: false`. Sibling of `CursedRewardViewModel`/`EventViewModel`. |
| **Darkness read VM (the reduced-radius + memory read)** | `DarknessReadView.project_darkness(id) -> Dictionary` pinned `MODAL_KEYS = [has_darkness, affinity_id, baseline_radius, reduced_radius, memory_uncertain, explanation, cue_ids]` | `scripts/ui/view_models/darkness_read_view.gd` | For Darkness: reduced+baseline radius (delta), `memory_uncertain: true`, the honest GDD-guardrail explanation, the 2 FINAL cue ids. Non-Darkness → `has_darkness: false`, `reduced==baseline`, empty cue_ids. Fail-closed. |
| **Affinity preview query (the explainability surface — affected cells)** | `AffinityPreviewQuery.preview_board(board, id, repo) -> ActionResult` → `{has_effects, hazard_cells, conductive_danger_cells, pathing_pressure_cells, warnings, cues, cue_ids, explanation}` | `scripts/tactical/targeting/affinity_preview_query.gd` | PURE read of the SAME `resolve_board_plan` — preview never disagrees with the applied effect. The board/inspect surfaces the affected cells + cues from here. Null board → `invalid_affinity_preview`; neutral/unknown/Cursed/Darkness → legal empty-effect preview. |
| **Affinity repository (validated content)** | `AffinityRepository.create_baseline_repository()`; `get_affinity(id) -> AffinityDefinition` (null on miss); `tactical_rules_for(id) -> Array` (empty for `none`/unknown, fail-safe); `BASELINE_AFFINITY_IDS = [scorched, flooded_conductive, cursed, darkness, none]` | `scripts/content/repositories/affinity_repository.gd` | `AffinityDefinition.AFFINITY_NONE == &"none"`. The orchestrator already holds one (`affinity_repository()`); reuse it — do NOT build a second. |
| **Accessibility cue catalog (the non-color channels — already carries all 5 affinity cues)** | `TacticalAccessibilityModel._CUE_CATALOG`: `affinity_scorched_hazard` [icon,label,text]/danger; `affinity_conductive_danger_placeholder` [shape,label,text]/danger; `affinity_pathing_pressure` [pattern,label]/warning; `affinity_darkness_reduced_visibility` [icon,label,text]/warning; `affinity_darkness_memory_uncertain` [pattern,label,text]/warning | `scripts/ui/view_models/tactical_accessibility_model.gd` | The canonical color-independence audit iterates ALL catalog cues — the 5 affinity cues are already covered. The scene MAPS these cue ids to visuals; it invents no new cue. |
| **Inspect view (FR12/FR58 — the affinity danger read)** | `TacticalInspectView.from_context(context, target_cell, options)` — fields incl. `visibility_state`, `cell`, `occupant`, `movement`, `attack_preview`, `hazards`, `telegraphs`, `cue_ids` | `scripts/ui/view_models/tactical_inspect_view.gd` | The affinity hazard/danger surfaces through `hazards`/`telegraphs`/`cue_ids` + the affinity preview cells. Visibility tiers `inspect_visible`/`inspect_memory`/`inspect_hidden_unexplored` each carry a non-color channel. Do NOT fork a parallel affinity-inspect path. |
| **Live combat resolver (the seam — restores the plain board)** | `LiveCombatResolver.resolve(board_snapshot, entrance, streams, hero_hp=60, hero_weapon_id=&"sword") -> ActionResult` (restores board, places hero at entrance, scripted focus-fire loop, full-vis, terminal outcome); `drive_hero_step_against(...)`; `DEFAULT_HERO_HP=60`, `DEFAULT_HERO_WEAPON=&"sword"` | `scripts/run/live_combat_resolver.gd` | Marks the whole board `visible=true` (headless full-vis — fog does not decide the HP-only outcome). 11.4 either extends `resolve(...)` with an optional `affinity_id`/`repo` (defaulting to neutral, keeping existing callers byte-identical) + applies the effect on the restored board, OR applies in the orchestrator. Keep it scene-free RefCounted (NO get_tree/get_node/autoload). |
| **Live combat node resolve (11.2 — the orchestrator call site)** | `RunOrchestrator.resolve_combat_node_live(node, hero_hp, hero_weapon_id) -> ActionResult` (`:945`); `resolve_current_node_live(...)` (`:906`); `run_to_completion_live(...)` (`:1030`) | `scripts/run/run_orchestrator.gd` | The place 11.4 assigns+applies the affinity (between `LevelGenerator.generate` and `LiveCombatResolver.resolve`). A live DEFEAT auto-fires `resolve_run_end(&"hero_death")` (the 11.2 source); a `live_combat_failed`-style hard error STOPS with no partial progression — mirror it for a fairness violation. |
| **On-screen board presenter (11.3 — renders the board VM slots + G1)** | `tactical_board_presenter.gd` — reads `TacticalBoardViewModel.to_dictionary()` pinned slots + `RunHudViewModel` (G1) into the region panels; `bind_live_state(board, turn_state, run, text_scale)`; `render()`; the tap seam `submit_move`/`tap_attack`/`inspect_cell` | `scripts/ui/presenters/tactical_board_presenter.gd` | 11.4 adds the affinity read to the render (Task 2) — a SEPARATE read surface the region composes (do NOT add a key to the board VM's pinned set). The presenter reads pinned surfaces + submits nothing new. |
| **On-screen shell (11.3 — auto-resolves, never renders the live board on combat)** | `gameplay_shell_presenter.gd` — `_drive_current_stage()` auto-resolves each live node; `_render_live_board(board, run)` only fires when `resolved.metadata.get("board") is BoardState` (always false for a combat node today — L4) | `scripts/ui/presenters/gameplay_shell_presenter.gd` | The L3/L4 deferrals (both "pairs with 11.4"): the combat node never renders the live board. Task 4 wires the affinity live board to render on screen (return the `"board"` in the live-node metadata OR host the tap-loop). |
| **Boss arena live path (a DISTINCT board — decide affinity scope)** | `RunOrchestrator.auto_play_boss_fight(hero_hp, hero_weapon_id) -> ActionResult` (`:1087`) — restores the arena from `boss_arena_payload()`, NOT a generated combat level | `scripts/run/run_orchestrator.gd` | The boss arena is a fixed finale stage (not affinity-assigned). Task 4 decides + records whether the boss arena carries an affinity (default: NO — out of the AC1 "run level carries an affinity" combat-node scope). Adopts the fail-closed placement discipline already in place. |

### Deferred-work overlaps folded in (ONLY entries touching this story's surface)

From `_bmad-output/implementation-artifacts/deferred-work.md` (a project-wide ledger — most entries are out of
scope). The entries that overlap 11.4's surface, folded in above; do NOT reopen unrelated items:

- **The live AFFINITY call sites + affinity board treatment (RESOLVED by 11.4).** The fence carried across
  Epics 5/6/7 as "the later HUD/run-flow / live-tactical-loop story" (7.5 dev-line-9, 7.6 dev-line-616) +
  re-recorded by 11.2 (`dev of 11-2` line ~46: "11.2's live combat runs a plain generated level;
  Darkness/Scorched/Cursed/Flooded on the live board is 11.4") + 11.3 (`dev of 11-3` line ~26: "11.3 wires NO
  Epic-7 affinity EFFECTS onto the live board and authors NO affinity board treatments — that is 11.4"). **11.4
  wires the call sites + the board treatment** — the exact wording of the parked residual: "When the live
  tactical-play loop lands, it CALLS this resolver per affected level (apply the board effects, tick the
  Scorched DoT command for an entity in a hazard cell, seat the Cursed rule source, surface the preview)" (7.5)
  + "CALLS this layer per Darkness level (compute the reduced visible set via
  `DarknessVisibilityLayer.calculate_visible_cells`, surface the memory uncertainty via `visible_facts_for_cell`,
  run `DarknessFairnessQuery.check_board`)" (7.6). Do EXACTLY this.
- **The 7.4 `assign_affinity` once-per-node idempotency guard (RESOLVED by 11.4).** The 7.4 Round-1 review
  deferred it (deferred-work ~line 660): "`RunOrchestrator.assign_affinity` has no once-per-node idempotency
  guard … the later story that wires the real per-node assignment call site should DECIDE on an assign-if-absent
  (once-per-node) guard so a double-assign cannot silently re-roll a node's affinity." **11.4 IS that story** —
  add the assign-if-absent guard (assign only when `assigned_affinity_for(node.id)` is neutral/absent).
- **The 11.3 L3 (hand on-screen combat control to the wired tap-loop) + L4 (render the live board on a combat
  node) deferrals — BOTH "pairs with Story 11.4."** L3 (deferred-work line ~8): the board presenter exposes the
  interactive tap seam but the shell auto-resolves; handing control to the tap-loop "pairs naturally with 11.4's
  live board treatment (the live board becomes the interactive on-screen surface once affinity effects/board
  treatments land on it)." L4 (line ~11): `resolve_combat_node_live` returns terminal-only metadata with NO
  `"board"` key, so the shell only ever renders the empty between-levels VM on a combat node; "it becomes
  actionable exactly when the tap-loop handoff lands." **11.4 addresses the L4 half** (render the live affinity
  board on screen — the AC2 on-screen requirement) at minimum; the full L3 auto-resolve→tap-loop handoff MAY
  stay deferred if the affinity board renders correctly under auto-resolve (record the disposition).
- **The Flooded `_placeholder` electric interaction (STILL OPEN — Epic-10 readiness, NOT 11.4's).** 7.5
  deferred-work (~line 630): "AC4 requires each Flooded placeholder to be either replaced with a concrete
  water/electric interaction, explicitly de-scoped as non-production MVP behavior, or block readiness." 11.4
  surfaces the deterministic conductive-danger + pathing-pressure MARKS live (the ratified MVP posture); it does
  NOT realize the live electric chain (the Epic-10 readiness item). Keep the `_placeholder` cue/visual/explanation
  ids distinct-from-final; RE-RECORD the readiness obligation.
- **The seated Cursed-affinity rule-source re-derive-on-resume (STILL OPEN unless 11.4 wires the live Cursed
  resume).** 7.5 deferred-work (~line 629): "When a later story actually wires the per-node 'enter affected
  level → seat the Cursed rule source' call site AND an in-node/live save, the seated Cursed-affinity rule
  source must be RE-DERIVED on resume (the affinity id is recoverable from the persisted `RunSnapshot.affinities`
  mirror / re-derivable from the seed)." **11.4 wires the seating call site** — if it also wires the live resume
  of a seated Cursed level, re-derive the rule source on resume; if not, RE-RECORD the obligation for the later
  in-node-save story (the assigned affinity + the between-node resume already re-derive; the seated resolver is
  the live, deliberately-not-serialized service).
- **The affinity-driven GENERATION modifier (STILL OPEN — a SEPARATE later story, NOT 11.4's).** 7.5/7.6
  deferred-work (~lines 618/632): "the GDD 'enter a cursed node for better reward odds' + ANY system that READS
  an assigned affinity / a 7.3 `risk_flag` and ALTERS generation (reward odds / elite rates / spawn) remains the
  later generation-modifier story." 11.4 applies TACTICAL affinity pressure on a built board; it does NOT wire
  an affinity into `RewardOfferBuilder`/reward tables/`EntityRewardPlacer`. Knowingly left parked.
- **NOT 11.4's to resolve (leave parked — 11.5/11.6):** the outpost SCENE + reveal RENDER + the G3
  summary↔profile coupling → 11.5; the meta-SPEND / unlock APPLICATION → 11.6; the live in-node board /
  pending-fight SAVE → a later in-node-save story (11.4's in-node fight + affinity state stays EPHEMERAL /
  re-derivable; the 23-key `RunSnapshot` gate stays 23).

### The 11.1 UX appendix contract (11.4's design spec for the affinity read screen)

The 11.1 UX appendix (`_bmad-output/planning-artifacts/ux-appendix-run-flow.md`) §15 is the settled paper
design for the affinity read; §14.3 pins the treatment baseline. Honor them:
- **§15 Affinity read (the surface 11.4 owns for build):** binds `AffinityViewModel` (pinned `MODAL_KEYS`
  incl. `tactical_rules` RECORD-ONLY + `visual_tags` the art/cue hooks) + `DarknessReadView` (pinned `MODAL_KEYS`
  incl. `reduced_radius`/`baseline_radius` delta + `memory_uncertain` + the 2 FINAL cue ids). States: Neutral
  (`is_neutral: true` / `has_darkness: false`) / Scorched-Flooded-Cursed (`tactical_rules` + `visual_tags`
  shown; the affinity danger cues each carry a non-color channel) / Darkness (reduced radius + memory
  uncertainty via the 2 cues). **Every affinity's critical danger information is non-color** — "the affinity
  read is a core NFR9 surface."
- **§14.3 Visual-treatment baseline (references — NOT authored here):** the approved affinity treatments
  already merged to `main` (`affinity.scorched.png`/`affinity.flooded.png`/`affinity.cursed.png`/`affinity.darkness.png`)
  are the board-affinity visual baseline; the Recraft UI-frame kit is the frame baseline. 11.4 APPLIES these via
  the `visual_tags`/`icon`-id hooks the view models already expose — NO new art, NO new asset.
- **§1.5 / §3.4 HUD + inspect:** the HUD (§1) + inspect (§3) surface the affinity read; the memory-tier `pattern`
  channel + the telegraph `pattern`/`icon` channels are the load-bearing non-color cues.

### Epic-11 retro-notes (the constraints ratified by earlier stories that bind 11.4)

From `_bmad-output/auto-gds/retro-notes/epic-11.md` — the epic-wide gotchas + conventions:
- **The scene-free headless harness (§"Story 11-3" Phase-3):** the test runner instantiates each test via
  `script.new().run()` — NO `SceneTree`, no `add_child`, no `await get_tree()`. The whole suite is scene-free
  RefCounted domain/VM tests. **Steer 11.4's testable logic into RefCounted seams** (the affinity read
  aggregation, the live-affinity resolve path, the fairness-on-live-path check, the Scorched-DoT-on-live-board
  behavior — all headless-unit-testable via `script.new()`); the `.tscn`/`Control` affinity render itself is
  verified BY CONSTRUCTION + a code audit. Do NOT claim a `SceneTree` unit test the harness cannot run.
- **Pinned-key / source-verification rigor (§"Story 11-1" Phase-7, §"Story 11-3" Phase-7):** cite the EXACT
  as-built method/const/key names, verified against source; a dead `has_method` probe silently no-ops and reads
  as "wired" (M2: a probe for a non-existent method left the HUD text scale hardcoded 1.0) — GREP the probed
  method name against source before trusting a guarded-accessor claim. When a presenter re-implements a
  sequencing the domain already encodes, test the SHARED seam, not just the domain driver.
- **The run-level SYSTEM vs board-event id spaces stay DISTINCT (§"Story 11-2" Phase-5):** mixing them produced
  a real duplicate id. 11.4 mostly reads/renders + applies effects (the Scorched DoT emits a board `DAMAGE_APPLIED`
  event on the board's own id space via `board.next_sequence_id()` — correct); if 11.4 interleaves any run-level
  SYSTEM stream with board events, keep the two id spaces distinct exactly as `auto_play_boss_fight` does
  (`BOSS_FIGHT_SEQUENCE_BASE = 100000` for the run-level SYSTEM stream; the board's own counter for board events).
- **Validate-then-reject on new orchestrator seams (§"Story 11-2" Phase-7):** 11.2's boss-arena placement
  adopted validate-then-reject (the 2 Round-1 fail-closed hardenings) — 11.4's affinity apply/DoT/fairness seams
  adopt the same fail-closed discipline from the start (`apply_board_effects` already aborts with zero partial
  mutation on a rejected stamp; `AffinityHazardDamageCommand` validates before mutate; a fairness violation
  STOPS with no partial progression).
- **The scripted live hero is deterministic but not universally-winning; verified-seed discipline (§"Story
  11-2"/11-3 Phase-5):** any auto-play / smoke path uses VERIFIED seeds (the approved-seed-catalog discipline;
  seed 4242 canonical for the finale). An affinity that makes a level harder (Scorched DoT / Darkness reduced
  LoS) must NOT make the scripted focus-fire driver fail loud on a previously-winning seed — pick affinity test
  seeds that reach a real terminal outcome (or drive the fight with a loadout that survives the DoT); a
  mutually-unreachable straggler or a DoT-death is a fail-loud, not a fabricated outcome.
- **`StartingKit.baseline_hp` is a BALANCE number, NOT the live driver HP (§"Story 11-3" Phase-5):** the live
  driver uses `LiveCombatResolver.DEFAULT_HERO_HP (60)`; the G1 HUD displays the class baseline between levels
  (two distinct concerns). The Scorched DoT ticks the LIVE board hero (HP 60 driver) — do NOT confuse it with
  the class baseline the HUD shows.

### Project Structure Notes

- **Where the code goes (project-context "File Placement"):** the live affinity WIRING belongs in the `run`
  domain (`godot/scripts/run/` — the orchestrator call site + any `LiveCombatResolver` extension), since it
  SEQUENCES existing commands/resolvers and owns no gameplay decision a command doesn't. The affinity EFFECT
  surfaces stay where they are (`scripts/rules/operations/`, `scripts/tactical/fog/`,
  `scripts/generation/level/`, `scripts/tactical/targeting/`, `scripts/core/commands/`) — do NOT move them. Any
  new affinity READ aggregation for the HUD goes under `scripts/ui/view_models/` (the G1/G2 posture); the
  presenter binding goes in `scripts/ui/presenters/`. Tests under `godot/tests/` mirroring the domain
  (live-affinity resolve + fairness-on-live-path under `tests/unit/run/` or `tests/integration/`; the affinity
  read/preview VM tests under `tests/unit/ui/` or `tests/unit/tactical/`).
- **`RunOrchestrator` + `LiveCombatResolver` are scene-free `RefCounted` domain services (NOT Node/autoload/scene)**
  — keep them so. The live affinity wiring must have NO `get_tree`/`get_node`, register no autoload, add no
  scene. It draws RNG ONLY via the run-level `RngStreamSet` (`map` for assignment; ZERO for effects) — NEVER
  `randi`/`randf`.
- **`scenes/` and `scripts/ui/` may OBSERVE domain state + SUBMIT commands but MUST NOT mutate tactical state
  directly.** The affinity render reads the existing pinned surfaces + submits nothing new; the effect APPLY is
  a DOMAIN operation (in the run/orchestrator layer), not a scene mutation.
- **Do NOT modify** `prototype/` (frozen), `_bmad/` (installer-managed), the `.agents/` legacy skills, the
  approved affinity assets (already merged), or the pinned seed-regression fingerprint files (`tools/dump_*`).
  11.4 applies effects POST-generation on a built board + surfaces reads — it MUST move no fingerprint.
- **The `data/source`/`data/resources` dirs stay EMPTY** (the affinity content is the 7.4 code constant — no
  JSON/.tres pipeline; Epics 6/7 added none). `scripts/rules/conditions/` stays EMPTY (no condition primitive —
  the affinity dispatch is a direct per-affinity branch).

### Project Context Rules

Extracted from `project-context.md` (the canonical rulebook — refreshed after Epic 9). The rules that bear on
THIS story:

- **Domain-first, scene-free authority.** "Godot scenes, `Control` nodes, audio, VFX, and animation are
  presentation. They must not own authoritative tactical state." The affinity EFFECT apply is DOMAIN logic (a
  board mutation / a rules-kernel seat / a visibility read); the SCENE renders the affinity READ + treatment.
  The render reads/submits through the existing surfaces, never mutates domain state.
- **Named-RNG rule (line ~96).** Gameplay-affecting randomness uses its assigned stream: affinity ASSIGNMENT →
  the `map` stream (already the assign draw). The affinity EFFECTS are ZERO-RNG (Scorched DoT fixed amount,
  Darkness fixed reduced radius, Flooded deterministic marks, Cursed resolve+explain). NEVER `randi`/`randf`/a
  fresh `RandomNumberGenerator`. 11.4 adds NO new stream (the 7 streams are frozen) and NO new draw SITE on the
  non-live / neutral path (a `none` level draws no affinity effect).
- **Determinism / interrupted==uninterrupted (NFR13, lines ~114/~120).** Snapshots are pure reads (consume NO
  RNG, execute NO command, advance NO turn). The affinity is LIVE re-derivable from `(assigned affinity, board)`
  — both recoverable (the affinity rides the `RunSnapshot.affinities` mirror + is seed-re-derivable; the board
  is the tactical snapshot). 11.4 adds NO new persisted affinity state; a resumed Darkness level re-derives the
  reduced radius from the restored/re-derived assigned affinity. A fixed seed is byte-deterministic end-to-end
  (FR57).
- **The 23-key `RunSnapshot` gate (lines ~374/~394).** Do NOT add a new top-level `RunSnapshot` key for
  live-affinity / in-node state. The reduced radius + memory flag + the Scorched hazard cells + the seated
  Cursed rule source are LIVE re-derivable, NOT new persisted state (the "distorted memory" is a READ annotation,
  the hazard is stamped POST-generation on a built board, the rule source is re-derivable). The 23-key gate stays
  23.
- **`ProfileSnapshot`/`SettingsSnapshot` `SCHEMA_VERSION == 1`.** 11.4 records off no new profile/settings field,
  forces no migration.
- **Append-only `DomainEvent.Type` — but 11.4 adds NONE.** The Scorched DoT REUSES `DAMAGE_APPLIED`; the reduced
  visible set REUSES the existing visibility path (a smaller `visible_cells`); there is NO affinity event. The
  enum tail is UNCHANGED; `domain_event.gd` has ZERO diff. IF you believe a new event is needed, STOP — the
  affinity vocabulary is a query/effect concern that reuses existing events.
- **Difficulty is a HARD non-goal (line ~267).** An affinity effect is authored, bounded tactical PRESSURE
  (hazard cells, a fixed DoT amount, a bounded reduced radius, a conductive mark, a curse penalty) surfaced
  HONESTLY — NEVER a hidden multiplier scaling enemy stats/HP/damage/rewards/RNG/run length. The Scorched DoT
  amount + the Darkness reduced radius are AUTHORED CONTENT, not scalars. MVP difficulty comes from run depth,
  enemy patterns, **affinity pressure**, elite nodes, risk rewards, attrition, boss prep — affinity pressure IS
  a listed MVP difficulty source, applied deterministically.
- **Do NOT auto-wire the caller-driven orchestrator methods into the DEFAULT loop (lines ~392/~404).**
  `generate_reward_offer` / `generate_event_offer` stay caller-driven — 11.4's live affinity wiring is on the
  LIVE combat path (`resolve_combat_node_live`), NOT the DEFAULT `run_to_completion` (which stays byte-identical
  / fingerprint-safe). `assign_affinity` becomes wired on the LIVE path only; the neutral `none` default keeps
  the non-affinity path byte-identical.
- **Color-independence + scalable text (NFR8/NFR9).** Every critical affinity meaning carries a non-color
  channel from the `TacticalAccessibilityModel` vocabulary (`shape`/`icon`/`label`/`pattern`/`text`) — the 5
  affinity cues already do. The affinity read is a core NFR9 surface. Text respects the `TacticalTextScale`
  clamp `[0.85, 2.0]`.
- **No cloud/accounts/multiplayer/telemetry, no Godot .NET/C#** (unless the architecture is explicitly revised —
  it is not). 11.4 is offline-first typed GDScript on Godot 4.6.3, mobile-first with desktop parity.
- **Godot / testing.** Godot 4.6.3 stable, typed GDScript. Every command gets valid + invalid/no-mutation
  tests; new systems get a test location before implementation. The FULL headless suite is the gate (175 PASS at
  11.3 close — 11.4 may GROW it with the live-affinity + fairness-on-live-path + affinity-read tests): run via
  PowerShell (the `godot` binary is not on the Bash PATH): `godot --headless --path C:\Sealsworn\godot --scene
  res://tests/headless/test_runner.tscn --quit-after 10` (or the Bash-reachable binary
  `C:/Users/Rasmus/Godot_v4.6.3-stable_win64.exe/Godot_v4.6.3-stable_win64_console.exe`). Apply the false-PASS
  grep guard (the only acceptable stderr `ERROR:` lines are the 6 documented negatives: int64-overflow ×2,
  malformed-JSON ×3, `invalid_node_type` ×1 — plus any NEW documented negative-path test, e.g. a
  `darkness_fairness_violation` forcing case). Run `git diff --check`.

### References

- **Story source (verbatim ACs):** `_bmad-output/planning-artifacts/epics.md` — Epic 11 §"Story 11.4: Live
  Affinity Pressure On Screen" (lines ~2674-2695). Epic 11 List entry + implementation notes: lines ~489-495.
  The 2026-07-04 Epic-11-insertion traceability (11.4 = "live affinity call sites + HUD/VFX"): lines ~403-405.
  FR56/FR57/FR58 (affinities alter tactical choices; Darkness fairness): lines ~134-138. FR55 (clear
  cursed/corrupted reward tradeoffs): line ~132. FR12 (inspect surfaces hazard notes + telegraphed danger): line
  ~46.
- **The 11.1 UX appendix (11.4's design spec):** `_bmad-output/planning-artifacts/ux-appendix-run-flow.md` §15
  (the affinity read — the surface 11.4 owns for build; `AffinityViewModel` + `DarknessReadView` pinned keys +
  states), §14.3 (the approved affinity treatment + Recraft UI-frame baseline — references, not authored), §1
  (HUD surfaces the affinity read), §3 (inspect surfaces the affinity danger).
- **The immediately-prior story (foundation):** `_bmad-output/implementation-artifacts/11-3-run-flow-scene-navigation-and-in-run-hud.md`
  (DONE) — the on-screen shell + HUD + the tap-seam board presenter 11.4 renders the affinity onto; its hard
  fence "No live affinity call sites / affinity VFX — that is 11.4" + the L3/L4 deferrals that pair with 11.4.
  `11-2-live-combat-loop-and-hero-death-source.md` (DONE) — the live combat loop + `LiveCombatResolver` + the
  live methods 11.4 wires the affinity into (the plain-level boundary "Darkness/Scorched/Cursed/Flooded on the
  live board is 11.4").
- **The Epic-7 affinity stories (the effects 11.4 gives live call sites):** 7.4 (assignment + read VM), 7.5
  (Scorched/Flooded/Cursed effects), 7.6 (Darkness + fairness) — their dev + review notes in `deferred-work.md`
  (`Tracked from: dev of 7-4/7-5/7-6`; `Deferred from: code review of 7-4/7-5/7-6`) name the parked live call
  site EXACTLY.
- **FR/NFR text (`epics.md` inventory):** FR55 (132), FR56 (134), FR57 (136 — affinities alter tactical choices,
  not only visuals), FR58 (138 — Darkness uncertainty without unavoidable unseen damage), FR12 (46 — inspect),
  NFR8 (180 — scalable text), NFR9 (182 — colorblind-safe, not color alone), NFR13 (190 — deterministic under
  seeded execution), NFR14 (192 — headless without rendering/UI).
- **Existing source (READ before wiring — all under `godot/`):**
  `scripts/run/run_orchestrator.gd` (`resolve_combat_node_live`:945, `assign_affinity`:691,
  `assigned_affinity_for`:739, `affinity_repository`:745, `auto_play_boss_fight`:1087, `run_to_completion_live`:1030);
  `scripts/run/live_combat_resolver.gd` (`resolve`:139, `DEFAULT_HERO_HP`:64, the full-vis marking:170-172);
  `scripts/rules/operations/affinity_effect_resolver.gd` (`resolve_board_plan`:98, `apply_board_effects`:125,
  `cursed_affinity_rule_source`:175, the `_placeholder` cue const:79);
  `scripts/core/commands/affinity_hazard_damage_command.gd` (`DEFAULT_HAZARD_AMOUNT`:49, `validate`:60, `execute`:96);
  `scripts/tactical/fog/darkness_visibility_layer.gd` (`is_darkness`:95, `reduced_radius_for`:105,
  `calculate_visible_cells`:122, `visible_facts_for_cell`:145);
  `scripts/generation/level/darkness_fairness_query.gd` (`check_board`:104, the reason consts:64-67, `phase_for_reason`:87);
  `scripts/tactical/targeting/affinity_preview_query.gd` (`preview_board`:31);
  `scripts/ui/view_models/affinity_view_model.gd` (`project_affinity`:64, `MODAL_KEYS`:37, `RULE_KEYS`:49);
  `scripts/ui/view_models/darkness_read_view.gd` (`project_darkness`:67, `MODAL_KEYS`:40);
  `scripts/content/repositories/affinity_repository.gd` (`create_baseline_repository`:54, `BASELINE_AFFINITY_IDS`:36);
  `scripts/ui/view_models/tactical_accessibility_model.gd` (the 5 affinity cue catalog entries:78-87);
  `scripts/ui/view_models/tactical_inspect_view.gd` (the `hazards`/`telegraphs`/`cue_ids` fields);
  `scripts/ui/presenters/tactical_board_presenter.gd` (the board VM render + tap seam);
  `scripts/ui/presenters/gameplay_shell_presenter.gd` (`_drive_current_stage`:53, `_render_live_board`:126 — the L4 seam).
- **The test suites to EXTEND (do not rebuild):** the 7.5 affinity-effect suites (`test_affinity_effect_resolver.gd`,
  `test_affinity_scorched_effects.gd`, `test_affinity_preview_query.gd`), the 7.6 Darkness suites
  (`test_darkness_visibility.gd`, `test_darkness_memory_uncertainty.gd`, `test_darkness_fairness.gd`,
  `test_darkness_read_view.gd`), the 11.2 live-combat suites (`test_live_combat_resolver.gd`,
  `test_live_run_flow.gd`, `test_finale_full_run.gd`), the 11.3 run-flow suites (`test_run_flow_controller.gd`,
  `test_run_hud_view_model.gd`) — extend with the live-affinity call-site + fairness-on-live-path + affinity-read
  coverage. The seed-regression suites (`test_small_level_layout_seed_regression.gd` /
  `test_medium_level_layout_seed_regression.gd` / `test_route_generation_seed_regression.gd` /
  `test_seed_batch_regression.gd` / `test_finale_seed_regression.gd`) MUST stay byte-identical.
- **Deferred-work ledger (overlapping entries):** `_bmad-output/implementation-artifacts/deferred-work.md`
  (the live-affinity call-site fence: `dev of 11-3` ~26 / `dev of 11-2` ~46 / `dev of 7-5` ~631 / `dev of 7-6`
  ~616; the 7.4 assign-idempotency guard ~660; the 11.3 L3/L4 deferrals ~8/~11; the Flooded `_placeholder`
  readiness item ~630; the seated-Cursed re-derive ~629; the generation-modifier defer ~618/~632).
- **Auto-gds Epic-11 retro-notes (epic-wide constraints):** `_bmad-output/auto-gds/retro-notes/epic-11.md`
  §"Story 11-1"/"11-2"/"11-3" — the scene-free harness, pinned-key/source-verification rigor, the run-level
  SYSTEM vs board-event id spaces, validate-then-reject on new orchestrator seams, verified-seed discipline
  (seed 4242), `StartingKit.baseline_hp` is a balance number not the live driver HP.

## Dev Agent Record

### Agent Model Used

Opus 4.8 (1M context) — `claude-opus-4-8[1m]` (auto-gds dev-story delegate).

### Debug Log References

- Full headless suite: `godot --headless --path C:\Sealsworn\godot --scene res://tests/headless/test_runner.tscn --quit-after 10` → **177 PASS / 0 `^FAIL`**, "Headless tests passed.", exit 0 (up from 175 at 11.3 close — 11.4 added `test_live_affinity_flow.gd` + `test_live_affinity_read_model.gd`, and extended `test_live_combat_resolver.gd`).
- False-PASS grep guard on stderr: exactly the 6 documented negatives (int64-overflow ×2, malformed-JSON ×3, `invalid_node_type` ×1) — ZERO new stderr errors from 11.4 (the Scorched DoT / affinity apply / fairness check / Cursed seating are clean; a benign DoT validate-reject never leaks to stderr).
- `git diff --check` clean.
- Pre-implementation probes (scratchpad, removed): confirmed the Scorched DoT fires on every verified seed (4242/99/1001/2002/3003 — 6-10 burning events each, all still reach a real victory); a neutral `none` + repo call is BYTE-IDENTICAL to the plain 11.2/11.3 call (same rounds, identical event log); Scorched is byte-deterministic + draws ZERO RNG; the orchestrator wiring seats the Cursed rule source + runs Darkness fairness + stamps Scorched hazards end-to-end.

### Completion Notes List

- **Task 1 (live affinity call sites).** `LiveCombatResolver.resolve(...)` gained optional `affinity_id` (default `AffinityDefinition.AFFINITY_NONE`) + `affinity_repository` (default null) params. When set, it applies `AffinityEffectResolver.apply_board_effects` on the restored board BEFORE hero placement (Scorched stamps HAZARD; others stamp nothing) and ticks the Scorched burning DoT (`AffinityHazardDamageCommand`, ZERO-RNG) for any entity that ENDS a turn on a HAZARD cell — the hero after its own action (short-circuiting the turn on a DoT death so the enemy phase never runs at a corpse), the enemies after the enemy phase, and the boxed-in hero in the stuck-fallback path. A `_scorched_hazard_active` flag gates the tick so the neutral / non-Scorched path is byte-identical (the tick loop is never even entered). The orchestrator (`resolve_combat_node_live`) assigns the node's affinity once (assign-if-absent), seats the cursed-affinity rule source on `run.rules_resolver` (creating one if null, idempotent), and passes the affinity into the resolver.
- **Task 2 (on-screen read + treatment).** New `LiveAffinityReadModel` (`scripts/ui/view_models/live_affinity_read_model.gd`) — a fail-closed, exact-key, no-live-handle RefCounted aggregation (the G1 posture) composing `AffinityViewModel` + `DarknessReadView` + `AffinityPreviewQuery` + reflecting the fairness verdict. `tactical_board_presenter` reads it into the status (affinity badge — id/display-name/rule count, +Darkness sight delta, +`[fair]`) + inspect (affinity danger — hazard/conductive/pathing cell counts + the non-color cue ids) regions. **No key added to `TacticalBoardViewModel`'s pinned set** (a separate read surface, exactly like G1). The `visual_tags` (the treatment art/cue hooks) ride the read; the presenter surfaces them without authoring art.
- **Task 3 (Darkness fairness on the live path).** `resolve_combat_node_live` runs `DarknessFairnessQuery.check_board` on the built board via the new `_check_darkness_fairness_live` helper (Darkness-only; a neutral affinity is not-applicable). A `darkness_fairness_violation` is surfaced structurally (the query's `fairness_reason` + `seed` + `phase` carried verbatim) and STOPS with no partial progression (mirroring `live_combat_failed`). The pass verdict is surfaced as `darkness_fairness` in the resolve metadata + reflected by the read model + HUD (the single-authority contract — the HUD never re-derives fairness).
- **Task 4 (render the live board on a combat node).** `resolve_combat_node_live` now returns `"board"` + `"affinity_id"` + `"darkness_fairness"` in the victory/defeat metadata; `gameplay_shell_presenter` renders the live affinity board (`_render_live_board` threads the affinity id + fairness verdict to the board presenter). Adding `"board"` perturbs no existing consumer (the shell is the only reader; every test reads metadata via `.get(...)`, not exact-key). **Boss-arena affinity: knowingly PARKED (NO affinity on the fixed finale arena)** — recorded in deferred-work.
- **Task 5 (invariants).** 177 PASS / 0 FAIL; every invariant/fingerprint suite green (RunSnapshot 23-key, RngStreamSet 7 streams, DomainEvent enum, ProfileSnapshot/SettingsSnapshot schema, all 3 layout seed-regressions, seed-batch, finale seed-regression + full run). `domain_event.gd` / `run_snapshot.gd` / `rng_stream_set.gd` / `tools/dump_*` have ZERO diff. The neutral live path + the DEFAULT `run_to_completion` are byte-identical (tested).
- **Task 6 (ledger).** `deferred-work.md` 11.4 entry: RESOLVED the live-affinity call sites + treatment, the 7.4 assign-idempotency guard, the 11.3 L4 render; RE-RECORDED the Flooded `_placeholder` (Epic-10), the seated-Cursed re-derive-on-resume, the affinity-generation modifier, 11.5/11.6; recorded the boss-arena-no-affinity + Cursed-resolve+explain-only + L3-tap-loop-deferred decisions.
- **Key decision — Scorched DoT cadence.** Each entity ticks once per round at the END of its own action (hero after its move/attack; enemies after the enemy phase). A DoT hero-death short-circuits the turn immediately (the outer `CombatOutcomeEvaluator` reads the 0-HP board → STATE_DEFEAT, the 11.2 death source — no parallel death path, and the enemy AI is never driven at a dead hero). Fairness-safe (the hazard is seen + avoidable; the command rejects a non-hazard cell), deterministic, ZERO-RNG.
- **Key decision — the Darkness live effect is a READ, not a combat mutation.** Per the story, the reduced visible set + memory uncertainty are surfaced for the HUD/inspect (via `DarknessReadView` in the read model); the `CombatOutcomeEvaluator`'s HP-only terminal check is unchanged (`LiveCombatResolver` keeps its headless full-vis so fog never decides the outcome). Darkness's live PRESSURE on the board is the reduced-radius + memory read the HUD shows + the fairness guarantee.

### File List

Modified:
- `godot/scripts/run/live_combat_resolver.gd` — optional `affinity_id`/`affinity_repository` params on `resolve`; Scorched board-effect apply + burning DoT tick (`_tick_scorched_dot` / `_tick_scorched_dot_enemies`); DoT-death short-circuit.
- `godot/scripts/run/run_orchestrator.gd` — `resolve_combat_node_live` assigns the affinity once, runs Darkness fairness (`_check_darkness_fairness_live`), seats the cursed-affinity rule source (`_seat_cursed_affinity_rule_source`), passes the affinity into the resolver, surfaces `board`/`affinity_id`/`darkness_fairness` in the metadata; new preloads (`AffinityEffectResolver`, `DarknessFairnessQuery`, `DarknessVisibilityLayer`, `RulesResolver`).
- `godot/scripts/ui/presenters/tactical_board_presenter.gd` — binds the affinity id + fairness verdict; composes `LiveAffinityReadModel` into the status (badge) + inspect (affinity danger) regions.
- `godot/scripts/ui/presenters/gameplay_shell_presenter.gd` — renders the live affinity board on a combat node (`_render_live_board` threads the affinity id + fairness verdict; `_fairness_from` extracts the verdict).
- `godot/tests/unit/run/test_live_combat_resolver.gd` — Scorched-on-live-board tests (stamp + DoT + determinism + zero-RNG + DoT-death + neutral byte-identity + non-Scorched no-op).

New:
- `godot/scripts/ui/view_models/live_affinity_read_model.gd` — the in-run affinity read aggregation (AC2).
- `godot/tests/unit/run/test_live_affinity_flow.gd` — the live affinity call site on the run flow (assign-if-absent idempotency, Scorched stamp, Cursed seating, Darkness fairness + HUD single-authority, DEFAULT run byte-identity).
- `godot/tests/unit/ui/test_live_affinity_read_model.gd` — the read model exact-key + fail-closed + Scorched/Darkness reads + fairness reflection + purity.

### Review Findings

**Round 1 of 3**

Reviewer: auto-gds code-review delegate (Opus 4.8, `gds-code-review` adversarial layers: Blind Hunter + Edge Case Hunter + Acceptance Auditor). Date: 2026-07-06. Scope: branch `story/11-4-live-affinity-pressure-on-screen` diff vs `main` (merge-base `0294891`), `godot/` only (8 files: 4 production sources, 1 new read-model VM, 3 tests). Independently re-ran the full headless suite.

**Verdict: Approve.** No Critical, no High. AC1/AC2/AC3 are met and demonstrably wired to the EXISTING Epic-7 surfaces (no fork). Determinism/fingerprint posture is sound and provably intact. The findings below are 1 Med + 3 Low, all `[Review][Decision]` (a human call) — none blocking.

Gate re-run (independent, this review — `Godot_v4.6.3-stable_win64_console.exe`): **177 PASS / 0 `^FAIL`**, "Headless tests passed.", exit 0. False-PASS grep guard clean: exactly the 6 documented stderr negatives (int64-overflow ×2, malformed-JSON ×3, `invalid_node_type` ×1) — ZERO new/undocumented stderr negatives from 11.4 (the fairness-violation forcing test asserts on the ActionResult, it does not push an ERROR to stderr). `git diff --check` clean. Invariant/fingerprint files (`domain_event.gd`, `run_snapshot.gd`, `rng_stream_set.gd`, every `tools/dump_*`) have ZERO diff vs main — the 23-key `RunSnapshot` gate, `SCHEMA_VERSION == 1`, the 7-stream set, the `DomainEvent.Type` enum tail, and every level/route/finale seed-regression fingerprint are structurally unmoved.

Source-verification (every load-bearing name grepped against source — no dead `has_method` probe, the trap that bit 11.3 Round-2): `registered_curse_ids()` (`rules_resolver.gd:109`), `apply_board_effects` returns `stamped_hazard_cells` (`affinity_effect_resolver.gd:163`), `AffinityHazardDamageCommand.new(entity_id)` single-arg (`:54`), `cursed_affinity_rule_source` → curse_id `curse_affinity_cursed` (`:184` — distinct from any reward curse_id, so the seat-idempotency guard cannot cross-contaminate with `accept_cursed_reward_command.gd`), `AFFINITY_DARKNESS`/`AFFINITY_NONE`/`DARKNESS_REDUCED_LINE_OF_SIGHT_RADIUS`, `try_from_snapshot`/`has_cells`/`entities`/`get_entity`/`get_cell`, `EntityType.ENEMY`/`is_dead`/`entity_type`/`position` — ALL confirmed real. The one `has_method` occurrence in the diff scope (`gameplay_shell_presenter.gd:175`) is a COMMENT documenting the removed 11.3 M2 dead probe, not a live probe.

Positive confirmations of the prompt's scrutiny targets:
- **Determinism / fingerprint preservation** — the live affinity path is opt-in (`resolve_combat_node_live` is reached ONLY via `resolve_current_node_live`/`run_to_completion_live`; the DEFAULT `run_to_completion` at `run_orchestrator.gd:304` never calls it). Neutral-`none` live path proven byte-identical at the event-dict level (`test_live_combat_resolver.gd::_neutral_affinity_is_byte_identical_to_the_plain_live_combat`). The only NEW RNG draw is the assign-if-absent `map`-stream roll (`assign_affinity`), gated so a re-drive never re-rolls; the Scorched effect + DoT draw ZERO RNG (proven: the injected stream snapshot is unchanged after a Scorched resolve).
- **Scorched DoT ordering/short-circuit** — each entity ticks once per round at the end of its own action (hero after its move/attack; enemies after the enemy phase); a hero DoT-death short-circuits BEFORE the enemy phase and flows through the outer `_evaluate` → `CombatOutcomeEvaluator` → `STATE_DEFEAT` (the 11.2 death source — no parallel path). DoT events append to the accumulator `event_log` (returned in the terminal metadata at `live_combat_resolver.gd:235`), so the short-circuit's return payload is immaterial. Verified by `_scorched_dot_kills_a_lingering_hero_through_the_board_death_source`.
- **Assign-if-absent idempotency** — `resolve_combat_node_live` assigns only when `assigned_affinity_for(node.id) == AFFINITY_NONE`; a re-drive reads the recorded id back. Verified the `map` stream is not drawn a second time (`_pre_assigned_node_is_not_re_rolled_on_a_re_drive`).
- **Cursed rule-source seat idempotency** — guarded by `registered_curse_ids().has(rule_source.curse_id)`; the affinity curse_id (`curse_affinity_cursed`) is disjoint from the reward-path curse_ids (derived from `cursed_reward_id`), so a run that took a cursed reward AND entered a cursed node seats both. Verified no double-seat on re-drive.
- **Darkness-fairness single authority** — `DarknessFairnessQuery.check_board` runs on the live board; its verdict is carried verbatim through orchestrator metadata → shell `_fairness_from` → `bind_live_state` → `LiveAffinityReadModel.fairness` → the badge. The read model constructs NO `DarknessFairnessQuery` (it reflects, never re-derives). A violation STOPS `resolve_combat_node_live` (mirrors `live_combat_failed`, no partial progression).
- **Fail-closed `LiveAffinityReadModel`** — pure (no RNG, no mutation, fresh-copy each call), exact-key pinned (present == absent == unknown key set), neutral/unknown id → `has_affinity: false`. The Scorched-DoT fairness holds (hazard cells are eligible FLOOR + UNOCCUPIED — no entity burns on its spawn cell; `affinity_effect_resolver.gd:236-248`).

Findings (all `[Review][Decision]` — a human call; none block Approve):

- [x] [Review][Decision] **M1 (Med) — the live-path Darkness fairness VIOLATION propagation is untested.** Task 3 subtask (c) asked for a live-path test that an intentionally-unfair Darkness board fails loud with `fairness_reason` + `seed` + `phase`. The query-level violation IS proven (`test_darkness_fairness.gd::_unseen_hazard_at_reduced_radius_fails_loud`, `darkness_fairness_violation` / `REASON_UNSEEN_HAZARD`), but the orchestrator seam — `_check_darkness_fairness_live` restoring the board, carrying the query's failure metadata (+ `node_id`/`node_type`), and `resolve_combat_node_live` doing `if fairness.is_error(): return fairness` (the STOP) — is exercised by NO test; only the fair-pass live case is covered (`test_live_affinity_flow.gd::_darkness_node_runs_the_fairness_check_and_reflects_the_verdict`). Mitigation (why it is Med, not High): v0 generated boards are all-FLOOR by construction, so a REAL live Darkness node cannot produce an unfair board through the actual `LevelGenerator` — the STOP path is structurally unreachable via the real generator, so this is a coverage gap on unreachable-in-practice wiring, not a live defect. Recommendation: add a targeted test that injects a hand-built unfair Darkness board through `_check_darkness_fairness_live` (or a thin generation stub) to prove the STOP + verbatim-metadata propagation, OR accept as-is given the unreachability and the 7.6 query-level proof. Human decision.
  - **RESOLVED (2026-07-06) — added the live-path fairness-violation test.** `test_live_affinity_flow.gd::_darkness_fairness_violation_on_the_live_path_stops_with_no_partial_progression` injects a hand-built unfair Darkness board (a reachable HAZARD unseen at the reduced radius) through `_check_darkness_fairness_live` and asserts the STOP (`darkness_fairness_violation` + verbatim `fairness_reason`/`seed`/`phase` + the orchestrator-attached `node_id`/`node_type`) with NO partial progression (no node cleared, ZERO `map` RNG consumed).

- [x] [Review][Decision] **L1 (Low) — `_scorched_hazard_active` is derived from the stamped-DIFF, not the plan.** In `live_combat_resolver.gd::resolve`, the flag is `not stamped_hazard_cells.is_empty()`. `apply_board_effects` skips (`continue`, no append to `stamped`) any target cell that is ALREADY `Terrain.HAZARD` (`affinity_effect_resolver.gd:154-155`), so a board whose Scorched cells were already stamped would yield an empty `stamped` and silently disable the DoT despite live hazard cells. Unreachable in the current call path (the board is freshly restored all-FLOOR from `payload["board"]` per `resolve()` call, so the first stamp always produces a non-empty diff), but a latent fragility if `resolve` is ever handed a pre-stamped board or the restore is memoized. Recommendation: derive the flag from the plan's `scorched_hazard_cells` non-empty (or the preview `has_effects` for the Scorched id) rather than the mutation diff, OR document the "fresh all-FLOOR board" precondition on `resolve`. Human decision.
  - **RESOLVED (2026-07-06) — derive the flag from the affinity effect PLAN.** `live_combat_resolver.gd::resolve` now computes `resolver.resolve_board_plan(...)` and sets `_scorched_hazard_active = not plan.scorched_hazard_cells.is_empty()` (the plan lists every Scorched hazard cell, including already-HAZARD ones), then applies the effect via the same resolver. The hidden fresh-all-FLOOR-board precondition is gone — a pre-stamped/memoized Scorched board still ticks. Neutral/non-Scorched byte-identity is unchanged (empty plan → flag stays false → the tick loop is never entered).

- [x] [Review][Decision] **L2 (Low) — the DEFAULT-path "byte-identical" test compares two post-11.4 runs, not a pre-11.4 baseline.** `test_live_affinity_flow.gd::_neutral_default_run_to_completion_is_byte_identical_to_a_second_run` asserts two fresh DEFAULT `run_to_completion` runs of the same seed produce identical stream snapshots — that proves determinism/repeatability, not non-regression vs main. The ACTUAL fingerprint-safety guard is the pinned `tools/dump_*` seed-regression suites (independently re-run green this review, zero diff vs main), so the invariant IS protected; the finding is that the in-test assertion string overstates what this specific test demonstrates. Cosmetic/documentation nit — no code change required. Human decision (accept the wording, or reword to "deterministic/repeatable" and rely on the seed-regression suites for the non-regression claim).
  - **RESOLVED (2026-07-06) — reworded the test to claim repeatability, not byte-identity vs main.** The test is renamed `_neutral_default_run_to_completion_is_repeatable`; its comment + assertion strings now state it proves DETERMINISM/REPEATABILITY across two same-seed runs in this build and explicitly name the pinned `tools/dump_*` seed-regression suites as the non-regression-vs-main guard.

- [x] [Review][Decision] **L3 (Low) — the presenter builds a second baseline `AffinityRepository` per render.** `tactical_board_presenter.render()` calls `LiveAffinityReadModel.new()` with no repo argument, so it constructs a fresh `AffinityRepository.create_baseline_repository()` on every render (per node, not per frame — cheap here). The orchestrator already owns one (`_affinity_repository`); the presentation layer does not reuse the run's repository. Functionally correct (the baseline content is identical and immutable) and low-cost, but inconsistent with the "share the ONE repository" note in the read model's own `_init`. Recommendation: thread the run's repository (or a shared baseline) into the read model at bind time, OR accept the per-render baseline as a negligible presentation-layer cost. Human decision.
  - **RESOLVED (2026-07-06) — ACCEPTED as negligible (human-accepted), no code change.** The per-render baseline build is trivial (per node, not per frame; the baseline content is identical + immutable) and keeps the read model pure (no run/repo handle leaked into the presentation layer). Kept as-is by design.

Deferrals: this review opened NO new `[Review][Defer]` items — every still-open cross-story residual (the Flooded `_placeholder` electric interaction → Epic-10; the seated-Cursed re-derive-on-resume → later in-node-save story; the affinity-driven GENERATION modifier → later story; the outpost/meta-spend → 11.5/11.6; the boss-arena-no-affinity, Cursed-resolve+explain-only, and full L3 tap-loop → recorded decisions) is already in the ledger under the `dev of 11-4` entry (unchanged by this review). The count copied to the ledger's `code review of 11-4` heading is therefore zero (heading created for traceability with an explicit none note).

**Round 2 of 3**

Reviewer: auto-gds code-review delegate (Opus 4.8, `claude-opus-4-8[1m]` — a SECOND, independent adversarial model pass: Blind Hunter + Edge Case Hunter + Acceptance Auditor). Date: 2026-07-06. Scope: branch `story/11-4-live-affinity-pressure-on-screen` diff vs `main` (merge-base `0294891`), `godot/` only (8 files: 4 production sources, 1 new read-model VM, 3 tests). Charter: verify the four Round-1 resolutions (M1/L1/L2/L3) landed correctly + hunt for anything Round 1 missed. Independently re-ran the full headless suite.

**Verdict: Approve.** No Critical, no High. All four Round-1 resolutions are VERIFIED IN PLACE. AC1/AC2/AC3 remain met and wired to the EXISTING Epic-7 surfaces (no fork). This pass adds 1 Low `[Review][Decision]` (a test-coverage observation on the L1 refactor's own protected path) — non-blocking.

Gate re-run (independent, this review — `Godot_v4.6.3-stable_win64_console.exe`): **177 PASS / 0 `^FAIL`**, "Headless tests passed.", exit 0. False-PASS grep guard clean: exactly the 6 documented stderr negatives (int64-overflow ×2, `invalid_node_type` ×1, malformed-JSON ×3) — ZERO new/undocumented stderr negatives (the M1 fairness-violation test asserts on the ActionResult, it pushes no ERROR to stderr). `git diff --check` clean. Invariant/fingerprint files (`domain_event.gd`, `run_snapshot.gd`, `rng_stream_set.gd`, every `tools/dump_*`) have ZERO diff vs main (empty diff-stat) — the 23-key `RunSnapshot` gate, `SCHEMA_VERSION == 1`, the 7-stream set, the `DomainEvent.Type` enum tail, and every level/route/finale seed-regression fingerprint are structurally unmoved.

Round-1 resolution verification (each confirmed against source + test):
- **M1 (VERIFIED)** — `test_live_affinity_flow.gd::_darkness_fairness_violation_on_the_live_path_stops_with_no_partial_progression` (:153) injects a hand-built unfair Darkness board (a reachable HAZARD at (8,6), distance 7, unseen at the reduced radius 2) through `_check_darkness_fairness_live` and asserts the STOP (`darkness_fairness_violation` + verbatim `fairness_reason`==`darkness_unseen_hazard`/`seed`/`phase` + the orchestrator-attached `node_id`/`node_type`) with NO partial progression (`cleared_node_ids` unchanged, ZERO `map` RNG consumed). Note: the test drives the private `_check_darkness_fairness_live` helper directly rather than the whole `resolve_combat_node_live` path, so the enclosing `if fairness.is_error(): return fairness` STOP is code-audit-verified (trivially visible in the diff) rather than test-exercised — an acceptable calibration given the STOP path is structurally unreachable through the real all-FLOOR v0 generator (Round-1 mitigation).
- **L1 (VERIFIED, sound)** — `live_combat_resolver.gd::resolve` now sets `_scorched_hazard_active = not plan.scorched_hazard_cells.is_empty()` from `resolver.resolve_board_plan(...)`, computed on the pre-apply board. **The prompt's flagged subtlety — is the Scorched cell set genuinely stamp-invariant? — is CONFIRMED YES**: `AffinityEffectResolver._eligible_effect_cells` (:276-286) includes cells whose terrain is `FLOOR` OR already `HAZARD` (:279), and `_scorched_hazard_cells` (:241-248) filters that set by a fixed even-parity predicate. Stamping a FLOOR cell to HAZARD therefore does NOT change the plan's membership — a pre-stamped/memoized Scorched board yields the identical `scorched_hazard_cells` set. The hidden fresh-all-FLOOR precondition is genuinely gone (the resolver's own :271-273 comment documents the idempotency intent). Neutral/non-Scorched still yields an empty plan → flag stays false → the tick loop is never entered (byte-identity preserved, proven by `_non_scorched_affinity_stamps_no_terrain_and_ticks_no_dot` + `_neutral_affinity_is_byte_identical_to_the_plain_live_combat`).
- **L2 (VERIFIED)** — the test is renamed `_neutral_default_run_to_completion_is_repeatable` (:194); its comment + assertion strings now claim DETERMINISM/REPEATABILITY across two same-seed runs in this build and explicitly name the pinned `tools/dump_*` seed-regression suites (small/medium layout, route, seed-batch, finale) as the non-regression-vs-main guard. The overstated "byte-identical vs main" wording is gone.
- **L3 (VERIFIED accepted, no change)** — `tactical_board_presenter.render()` (:135) still constructs `LiveAffinityReadModel.new()` with no repo arg (a fresh baseline per render, per node not per frame); documented as a knowingly-accepted negligible presentation-layer cost that keeps the read model pure (no run/repo handle leaked into presentation). No code change, consistent with the human-accepted disposition.

Independent scrutiny of the prompt's core-surface targets (all confirmed — no new defect):
- **Determinism / fingerprint preservation** — the live affinity path is opt-in (`resolve_combat_node_live` reached ONLY via `resolve_current_node_live`/`run_to_completion_live`; the DEFAULT `run_to_completion` never calls it). The ONLY new RNG draw is the gated assign-if-absent `map`-stream roll (`assign_affinity` at :712, `streams.rand_int` — never `randi`/`randf`); the Scorched effect + DoT draw ZERO RNG (proven: the injected stream snapshot is unchanged after a Scorched resolve). Neutral-`none` live path byte-identical at the event-dict level.
- **Scorched DoT ordering/short-circuit** — each entity ticks once per round at the end of its own action (hero after its move/attack via `_tick_scorched_dot`; enemies after the enemy phase via `_tick_scorched_dot_enemies`); a hero DoT-death short-circuits BEFORE the enemy phase (return `command_result.events`) and flows through the outer `_evaluate` → `CombatOutcomeEvaluator` → `STATE_DEFEAT` (the 11.2 death source). The DoT event is appended to the accumulator `event_log` (returned in the terminal metadata) so the short-circuit's return payload is immaterial. `_tick_scorched_dot_enemies` iterates a `board.entities()` snapshot copy and re-fetches each entity via `get_entity` + `is_dead()` guard, so a mid-iteration DoT death cannot stale-crash. The stuck-fallback `_resolve_enemy_phase_only` also ticks the hero (its turn end) before the enemy phase, with the same death short-circuit — fairness parity.
- **assign-if-absent + Cursed-seat idempotency** — `resolve_combat_node_live` assigns only when `assigned_affinity_for(node.id) == AFFINITY_NONE`; a node records exactly ONE id (`assigned_affinities[node.id]`, :729), so Darkness and Scorched are mutually exclusive per node. Cursed seating is guarded by `registered_curse_ids().has(rule_source.curse_id)`; the affinity curse_id `curse_affinity_cursed` (built as `curse_` + `affinity_cursed`) is disjoint from the reward-path curse_ids, so a run that took a cursed reward AND entered a cursed node seats both without cross-contamination. Both re-drive idempotencies test-proven.
- **Darkness-fairness single authority** — `DarknessFairnessQuery.check_board` runs on the live board (restored from the pre-stamp `payload["board"]`, correct since a Darkness node stamps no Scorched terrain); the verdict is carried verbatim through orchestrator metadata → shell `_fairness_from` → `bind_live_state` → `LiveAffinityReadModel.fairness` (reflected, never re-derived — the read model constructs NO `DarknessFairnessQuery`) → the `[fair]` badge. A violation STOPS `resolve_combat_node_live`.
- **LiveAffinityReadModel fail-closed posture** — every method name the model + presenters probe was GREPPED against source and is real (no dead `has_method` probe — the 11.3 M2/Round-1-verified trap): `project_affinity`/`project_darkness` (exact pinned `MODAL_KEYS`), `preview_board` (metadata keys `has_effects`/`hazard_cells`/`conductive_danger_cells`/`pathing_pressure_cells`/`cue_ids`/`cues`/`explanation`), `AffinityHazardDamageCommand.new(entity_id)` single-arg ctor, `board.entity_at`/`get_entity`/`get_cell`/`has_cells`/`entities`/`try_from_snapshot`/`set_cell_terrain_for_setup`, `TacticalEntityState.EntityType.ENEMY`/`is_dead`/`entity_type`/`position`/`entity_id`, `BoardCell.is_occupied`/`Terrain.HAZARD`, `registered_curse_ids`/`register_curse`/`explain`, `run.rules_resolver`, `DarknessVisibilityLayer.AFFINITY_DARKNESS`/`DARKNESS_REDUCED_LINE_OF_SIGHT_RADIUS`/`CUE_DARKNESS_*`/`STATE_HIDDEN`, `GenerationResult.ok`, `RouteNode.TYPE_COMBAT`/`REVEAL_REVEALED`, `RouteState.node_by_id` — ALL confirmed. The read model's `has_affinity` collapses the neutral `none` case to `false` (`has_affinity AND NOT is_neutral`); exact-key set identical for present/absent/unknown; returns a fresh deep copy each call. No live-handle leak.

Finding (1 Low, `[Review][Decision]` — a human call; does not block Approve):

- [x] [Review][Decision] **L4 (Low) — the L1 refactor's own protected path (a pre-stamped Scorched board still ticking) is asserted by no test.** The Round-1 L1 fix rederived `_scorched_hazard_active` from `resolve_board_plan(...).scorched_hazard_cells` precisely so the DoT still fires when handed a board whose Scorched cells are ALREADY `HAZARD` (the case where `apply_board_effects` returns an empty `stamped` diff). That stamp-invariance is genuinely correct by source (`_eligible_effect_cells` includes `HAZARD` terrain, so the plan lists already-stamped cells — I verified it), but NO test hands `resolve` a pre-stamped Scorched board to prove the flag stays true and the tick fires under exactly the empty-diff condition the refactor targets — every Scorched test (`test_live_combat_resolver.gd`) starts from a freshly-restored all-FLOOR board where the first stamp always produces a non-empty diff, so the old (diff-based) and new (plan-based) implementations are indistinguishable by the current suite. This is the exact companion of the pre-fix Round-1 M1 gap (an unreachable-in-practice path whose wiring is proven by source, not by a test); like M1 it is structurally unreachable via the real per-call fresh-board restore. Recommendation: add a targeted `test_live_combat_resolver` case that calls `resolve` twice on the SAME BoardState instance (or hands a pre-stamped Scorched snapshot) and asserts the second resolve still ticks the burning DoT — proving the plan-derived flag is stamp-invariant — OR accept as-is given the source-verified invariance + structural unreachability (mirroring the L1 human-accepted disposition). Human decision.
  - **RESOLVED (2026-07-06) — added the pre-stamped-board tick test.** `test_live_combat_resolver.gd::_pre_stamped_scorched_board_still_ticks_the_dot` resolves the Scorched corridor once (fresh all-FLOOR → stamps + ticks), then builds the SAME board already Scorched-stamped (restore → `apply_board_effects` → `to_snapshot`), asserts re-applying Scorched to it yields an EMPTY `stamped_hazard_cells` diff (the exact empty-diff condition L1 targets, where the old diff-based flag would go false), and resolves a SECOND time on that pre-stamped snapshot — asserting the burning DoT STILL fires (`scorched_hazard`, fixed 2) because `_scorched_hazard_active` is derived from the plan (already-HAZARD cells stay plan-eligible), proving the flag is stamp-invariant. Full suite green (177 PASS / 0 FAIL / 0 SCRIPT ERROR; 6 documented stderr negatives only; no new negative).

Deferrals: this Round-2 pass opened NO new `[Review][Defer]` items. L4 is a human-decision coverage item held here in the story file, NOT a cross-story deferral. Every still-open cross-story residual remains recorded in the ledger under the `dev of 11-4` entry (unchanged by this review); the count copied to the ledger's `code review of 11-4` heading stays zero.
