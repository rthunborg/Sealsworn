# Story 14.4: Per-Run Seed Variation

Status: ready-for-dev

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a player,
I want each new descent to be a different room,
so that the game has replay variety while tests stay reproducible.

## Context & Why This Story Exists

Epic 14 ("Playable & Presentable") is the **second pre-ship backlog epic**, added 2026-07-16 after an agent-driven desktop playtest found the built MVP is **not honestly finishable** and looks unfinished (`playtest-sessions/agent-playtest-2026-07-16.md`; `sprint-change-proposal-2026-07-16.md`). Story 14.4 is the **fourth story of Band 1** (finishable + readable), landing after 14.1's soft-lock fix, 14.2's visible preview / reject cue, and 14.3's event-log + hit feedback. It closes the **replay-variety** gap:

- **F11 — every "new descent" is the same room.** The playtest booted the game three times and got the **identical board every time**. Root cause: the two live "start a run" call sites each hardcode a **fixed seed 4242**, so board/route/enemy layout never varies. A roguelite whose runs are byte-identical has no replay value (FR26).

**This story is a single, surgical FLOW-LAYER seed-source change — it is the ONE determinism-source change in all of Epic 14.** It does **not** touch `RunStartCommand`, the generation pipeline, any named RNG stream, any draw site, or the save schema. A run remains a **pure deterministic function of its given `root_seed`** — 14.4 only changes **which seed the live new-run caller hands in**: an entropy-derived seed for a normal run (variety), the explicit seed for a manual-seed run (byte-deterministic replay). **Every seed-regression / winnability / finale test passes an EXPLICIT seed directly to the domain and therefore stays byte-identical** — none of them touch the entropy path.

**The root cause (load-bearing — read before Task 1).** There are **TWO** live new-run-with-seed call sites, and **both hardcode seed 4242**:

1. **`godot/scripts/ui/presenters/hero_select_presenter.gd`** — the initial "Begin Descent" confirm. `const DEFAULT_RUN_SEED: int = 4242` (line 21); `_resolve_seed()` (lines 117-123) returns `GameSession.get_root_seed()` if `configured != 0`, **else the fixed `4242`**; `_on_confirm_pressed()` calls `controller.start(seed_value, false, _selected_class_id)` (line 102) — **always `is_manual_seed = false`**.
2. **`godot/scripts/ui/presenters/outpost_presenter.gd`** — the "Descend Again" one-tap re-descend. `const DEFAULT_DESCENT_SEED: int = 4242` (line 34); `_on_descend_pressed()` (line 291) builds a request with `"root_seed": str(DEFAULT_DESCENT_SEED)`, `"is_manual_seed": false` and calls `controller.start(4242, false, "")` (lines 309-313).

D4 (the ratified design decision, `sprint-change-proposal-2026-07-16.md` §3.1) names **"Descend / Descend Again"** explicitly, so **both** sites must route through the new entropy seed source. Fixing only hero-select would leave every re-descend on 4242 (the same-room bug half-persists).

**No save-schema change; no migration test.** `root_seed` is **already** field #5 of the 23-key `RunSnapshot` (`run_snapshot.gd:23`, string-encoded at line 49); `is_manual_seed` is already field #6; `meta_progression_eligible` is already field #7 (`= not is_manual_seed`, `run_snapshot.gd:190`). An entropy seed flows into the EXISTING `root_seed` field exactly like a manual seed does — the snapshot shape is untouched, the **23-key gate stays 23**, `SCHEMA_VERSION` stays `1`, and a saved entropy run round-trips identically to any seeded run. **Do NOT add a snapshot field, do NOT change the schema, and do NOT write a migration test — there is no schema change to migrate.** (This is deliberately called out because the story is "RNG/seed-sensitive" and a dev could over-engineer a schema change that the story explicitly forbids.)

## Acceptance Criteria

**AC1 — Entropy-derived seed at a normal new-run start (F11; FR26)**
Given the player starts a normal (non-manual-seed) run
When the new-run flow caller starts the run — at **both** live sites (the hero-select "Begin Descent" confirm **and** the outpost "Descend Again")
Then it selects an **entropy-derived `root_seed`** (a one-time non-gameplay seed *source* chosen **before** any named stream exists — the seed source, **not** a gameplay draw, so it does not touch the named-RNG rule and does not use any `RngStreamSet` stream), so board/route/enemy layout **varies run to run** (two boots → two different rooms)
And `RunStartCommand` and the generation pipeline are **unchanged** — a run remains a **pure deterministic function of its given `root_seed`** (14.4 changes only which seed is handed in, never how the seed is consumed).

**AC2 — Manual-seed path bypasses entropy and stays deterministic (FR27, FR28, FR29)**
Given a manual-seed run
When an explicit seed is supplied (via the existing `GameSession` configured-seed carrier — a future on-screen seed-entry surface is a **later concern**, see Dev Notes)
Then the manual-seed path **bypasses the entropy source** and reproduces **byte-identically** (FR29), and a manual-seed run still grants **no meta progression** (`is_manual_seed = true` → `meta_progression_eligible = false`, unchanged — FR28)
And **every seed-regression / winnability / finale test — each of which passes an explicit seed directly to the domain — stays byte-identical** (no fingerprint moves), because none of them go through the flow-layer entropy source.

**AC3 — Determinism + save gates held; testable seam (NFR13, NFR15)**
Given the determinism and save gates
When this story lands
Then **no named RNG stream is added or reordered** (`RngStreamSet.required_streams()` stays the 7: `map, level, combat, loot, rewards, events, cosmetic`), **no draw site changes**, and the **23-key `RunSnapshot` gate stays 23** (`SCHEMA_VERSION == 1`; no new save key; no migration)
And the **seed-source selection lives in the flow/caller layer, in a scene-free `RefCounted` seam** (not inside a command, not inside the impure `Control`), testable **without a SceneTree** — the entropy value is **injected** into the pure seam so the seam's decision is deterministic and unit-tested.

## Tasks / Subtasks

- [ ] **Task 1 — The pure seed-source seam (AC1, AC2, AC3)**
  - [ ] Create `godot/scripts/ui/flow/run_seed_source.gd` (recommended `class_name RunSeedSource`, `extends RefCounted`) — a scene-free flow seam beside the other `flow/` bridges (`run_flow_controller.gd`, `run_flow_router.gd`, `run_end_profile_bridge.gd`). A **static, pure** `resolve(configured_seed: int, entropy: int) -> Dictionary` returning a **pinned-key** dict `{ root_seed: int, is_manual_seed: bool }`:
    - **Manual branch** — `configured_seed != 0` → `{ root_seed = configured_seed, is_manual_seed = true }`. Bypass entropy entirely (the injected `entropy` is ignored). This is the FR27/FR28 explicit-seed path: `is_manual_seed = true` makes `RunSnapshot.meta_progression_eligible` false, and a full int64 `configured_seed` is preserved verbatim (no truncation — the seam does not mask the manual seed).
    - **Entropy branch** — `configured_seed == 0` → normalize `entropy` to a **non-negative, non-zero 31-bit seed** and return `{ root_seed = normalized, is_manual_seed = false }`. Recommended normalization: `var s := entropy & 0x7fffffff; if s == 0: s = 1`. Rationale: `RunStartCommand.validate()` rejects `root_seed < 0` (`invalid_run_seed`, `run_start_command.gd:155-159`); `RngStreamSet._derive_seed` masks the base seed to 31 bits anyway (`rng_stream_set.gd:234`), so a 31-bit domain wastes no entropy; `0` is avoided because it is the `GameSession` "unconfigured" sentinel that the manual branch keys off. `is_manual_seed = false` keeps a normal run **meta-eligible** (FR26).
  - [ ] Pin a `RESULT_KEYS` (or equivalent) const `["root_seed", "is_manual_seed"]` and assert it in the test. The seam draws **ZERO RNG** itself (entropy is injected), consults no `RngStreamSet`, reads no autoload, and mutates nothing.
  - [ ] Generate the `.gd.uid` sidecar for the new script (`godot --headless --import`) and commit it (the 13.1 import discipline for new `.gd` global classes).

- [ ] **Task 2 — Wire the hero-select "Begin Descent" caller (AC1, AC2)**
  - [ ] In `hero_select_presenter.gd`, preload the seam (`const RunSeedSource = preload("res://scripts/ui/flow/run_seed_source.gd")`) and replace the `_resolve_seed()` → `controller.start(seed_value, false, ...)` flow with the seam. Gather the configured seed (`GameSession.get_root_seed()` when the autoload is present, else `0`) and a **freshly-read entropy value**, call `RunSeedSource.resolve(configured, entropy)`, then `controller.start(result.root_seed, result.is_manual_seed, _selected_class_id)`.
  - [ ] The entropy read is the **one impure line** and MUST stay in the presenter (not the seam). Recommended: a local `var rng := RandomNumberGenerator.new(); rng.randomize(); return rng.randi()` — a **local** RNG seeded from OS entropy for the one-time pick. It is **NOT** a named gameplay stream and **NOT** the global `randi()`/`randf()`; do not thread any `RngStreamSet` here. **Do NOT** use `int(Time.get_unix_time_from_system())` — its 1-second resolution collides on a rapid re-boot/re-descend and reproduces the same-room bug; `Time.get_ticks_usec()` (microsecond) is an acceptable alternative source if preferred.
  - [ ] **Remove the fixed-seed fallback**: `DEFAULT_RUN_SEED = 4242` must no longer be the normal-run seed. Delete the const (grep confirms it is referenced only inside this presenter) or leave it unused — but the entropy path, not `4242`, is now the default. Preserve everything else: the class-select gate, the `started`/reject branch, the `GameSession.set_run_flow` handoff, the `route_map` navigation.
  - [ ] **Do NOT thread the profile** into `controller.start(...)` — the profile-aware standalone-scene wiring stays deferred to the Necromancer/Shadeblade class-kit story (see Dev Notes / deferred-work overlap). 14.4 changes only the seed + `is_manual_seed` arguments on line 102; the 4th `profile` arg stays absent (null → today's static gate, byte-identical).

- [ ] **Task 3 — Wire the outpost "Descend Again" caller (AC1)**
  - [ ] In `outpost_presenter.gd`, preload the seam and replace the hardcoded `DEFAULT_DESCENT_SEED` in `_on_descend_pressed()` (lines 299-313) with the same seam call. Recommended (uniform with hero-select): `var sm := RunSeedSource.resolve(GameSession.get_root_seed() if has_node("/root/GameSession") else 0, <entropy>)`, then build the request / call `controller.start(sm.root_seed, sm.is_manual_seed, "")`. In v0 `get_root_seed()` is always `0` (nothing configures it live), so the one-tap re-descend takes the **entropy** branch → a genuinely fresh, different room each time — exactly the story intent.
  - [ ] The inline `request` dict keeps its existing keys `{root_seed, is_manual_seed, class_id, is_startable}` (this presenter builds the request inline; it does **not** call the pinned `OutpostViewModel.start_run_request` seam, so the VM `START_REQUEST_KEYS` pin is untouched). Only the `root_seed` **value** (now entropy, decimal-string-encoded) and `is_manual_seed` **value** change. Remove the fixed-seed default use (`DEFAULT_DESCENT_SEED = 4242`); delete the const (referenced only here) or leave it unused.
  - [ ] Preserve the rest of `_on_descend_pressed`: the `is_startable` guard, the empty-class legacy start, the `clear_run_flow` + `set_run_flow` handoff, and the `route_map` navigation.

- [ ] **Task 4 — Seam unit test (AC1, AC2, AC3)**
  - [ ] Add `godot/tests/unit/ui/test_run_seed_source.gd` (beside `test_run_flow_router.gd`). Assert, on `RunSeedSource.resolve(...)`:
    - **Manual bypass:** `resolve(4242, 999999)` → `{ root_seed = 4242, is_manual_seed = true }` (the injected entropy `999999` is **ignored** — prove the manual branch does not consult it).
    - **Manual int64 preserved:** a large explicit seed (e.g. `9223372036854775807` or another >2^53 value) round-trips verbatim with `is_manual_seed = true` (no masking/truncation on the manual path).
    - **Entropy path:** `resolve(0, 12345)` → `{ root_seed = 12345, is_manual_seed = false }`.
    - **Non-negative / non-zero normalization:** `resolve(0, 0)` → `root_seed >= 1`; a negative or >31-bit entropy (e.g. `-1`, or `0x100000000 + 7`) → a **non-negative** `root_seed` (never `< 0`, so `RunStartCommand` never rejects it) and `is_manual_seed = false`.
    - **Variety:** two distinct entropy values (`configured == 0`) yield two **distinct** `root_seed`s.
    - **Pinned key set:** the result dict has exactly `["root_seed", "is_manual_seed"]` (fail loud if a key appears/vanishes).
  - [ ] Use `str(...)` (never eager `String(nullable)`) in assert messages (14.1 retro test-honesty note — eager `String(nullable)` crashes on a null read and masks the real failure).

- [ ] **Task 5 — Determinism / save gates held + suite green (AC2, AC3)**
  - [ ] Confirm **no domain/RNG/save change**: `RunStartCommand`, `RunOrchestrator.start`, `RngStreamSet` (7 streams, `_derive_seed`), `RunSnapshot` (23 keys, `SCHEMA_VERSION == 1`), and every generation/route/finale file are **untouched**. No new `DomainEvent` (enum unchanged), no new named stream, no new draw site, no new autoload. The only production files touched are the new seam + the two presenters.
  - [ ] Confirm the entropy path is **never** reached by a test: grep the suite for a presenter-level `4242` seed assertion (expect **none** — presenters are verified by construction, not SceneTree-tested; no test pins `_resolve_seed`/`_on_descend_pressed` to a fixed seed). If any test does assert a live-presenter seed of `4242`, that is the one place to reconcile — but the expectation is zero.
  - [ ] Confirm every **load-bearing determinism/regression test stays byte-identical** (they all pass explicit seeds — see Dev Notes for the exact list): `test_seed_regression_suite.gd`, `test_route_generation_seed_regression.gd`, `test_small_level_layout_seed_regression.gd`, `test_medium_level_layout_seed_regression.gd`, `test_seed_batch_regression.gd`, `test_generator_fairness_batch.gd`, `test_finale_seed_regression.gd` / `test_finale_full_run.gd`, `test_reference_combat_driver.gd` (the 14.1-re-pinned combat replay at seed **24680** — must NOT move), `test_manual_seed_loader.gd`, `test_run_snapshot.gd` (23-key gate), `test_rng_stream_set.gd`, `test_run_resume_service.gd` (int64 root_seed preservation, line 431).
  - [ ] Run the FULL headless suite (mandatory command below). Grep the raw output for `SCRIPT ERROR|Parse Error|^FAIL` (the false-PASS guard): exactly the **6 documented stderr negatives** (int64-overflow ×2 in `test_manual_seed_loader`, malformed-JSON ×3, `invalid_node_type` ×1), **ZERO new**. Baseline is **200 PASS** (post-14.3); this story adds one seam test → expect **201 PASS**. `git diff --check` clean.

## Dev Notes

### The two live start sites (the only files that change behavior)

Both new-run-with-seed entrypoints hardcode 4242 today; 14.4 routes both through the shared seam.

- **`godot/scripts/ui/presenters/hero_select_presenter.gd`** — `_on_confirm_pressed()` (line 97) → `_resolve_seed()` (117-123) → `controller.start(seed_value, false, _selected_class_id)` (102). `_resolve_seed` returns `GameSession.get_root_seed()` when `configured != 0`, else `DEFAULT_RUN_SEED = 4242`. **The always-`false` `is_manual_seed` is a latent FR28 gap** (a configured explicit seed would currently still be meta-eligible) — 14.4 fixes it by threading `is_manual_seed` from the seam.
- **`godot/scripts/ui/presenters/outpost_presenter.gd`** — `_on_descend_pressed()` (291) builds `{root_seed: str(4242), is_manual_seed: false, class_id: "", is_startable: true}` (299-304) and calls `controller.start(...)` (309-313). Same fixed seed, same always-`false`.

The seed then flows, unchanged, through: `RunFlowController.start(root_seed, is_manual_seed, class_id, profile)` (`run_flow_controller.gd:106`) → `RunOrchestrator.start(...)` (`run_orchestrator.gd:198`) → `RunStartCommand.new(root_seed, is_manual_seed, ...).execute(null)` (199) and `streams = RngStreamSet.new(root_seed)` (203). **None of these change.** They already are a pure function of `(root_seed, is_manual_seed)`.

### Why a normal run is entropy (meta-eligible) and only an explicit seed is manual (no-meta)

FR26 (seeded, varying runs) vs FR27/FR28 (manual seed allowed, but grants no meta progression). The mapping the seam encodes:

- **Normal Descend / Descend Again → entropy seed, `is_manual_seed = false`, meta-eligible.** A normal re-descend from the outpost is a *new different room* and should still earn Oath Shards. Do **NOT** flip a normal entropy re-descend to `is_manual_seed = true` — that would silently make every re-descend non-meta-eligible (an FR28/FR60 regression).
- **Explicit configured/entered seed → that seed verbatim, `is_manual_seed = true`, NOT meta-eligible.** `RunSnapshot` already enforces `meta_progression_eligible = not is_manual_seed` (`run_snapshot.gd:190`); the outpost VM and the 8.3/8.4 award/merge gates already deny a manual-seed run (`deferred-work.md` FR28 lineage). 14.4 just makes the live path *set the flag correctly* for the manual case (today it is hardcoded `false` everywhere).

### The manual-seed ENTRY surface stays a later concern (scope boundary — do NOT over-build)

There is **no live caller of `GameSession.configure_seed(...)`** today (grep: only the definition, `hero_select_presenter._resolve_seed`'s `get_root_seed()` read, and a test). So the manual-seed path is reachable only via the existing `GameSession` configured-seed carrier — there is no on-screen "type a seed" field. **14.4 does NOT build one.** D4 scopes 14.4 to a **"flow-layer seed source only"** change, and both `hero_select_presenter.gd:19-21` and `outpost_presenter.gd:31-32` already comment that "a manual-seed entry is a later concern." AC2 is satisfied by proving the **path** is correct (explicit seed → bypass entropy → `is_manual_seed = true` → no meta → byte-deterministic), which the seam unit test + the existing `test_manual_seed_loader` / seed-regression suites cover. A future on-screen seed-entry widget belongs to the FR27 entry surface (the natural home is 14.8's hero-select rebuild, which reworks that screen) — **adding a text field here would over-scope 14.4 and collide with 14.8.** If you judge a minimal entry field is wanted, treat it as a `[Decision]` and leave the recommended default (no new widget) in place.

### Determinism proof: why EVERY seed-regression / winnability / finale test stays byte-identical

The entropy source is consulted at **exactly one place**: the live normal-new-run start (the two presenters, via the seam). **Every determinism test passes an EXPLICIT seed directly to the domain (`RunStartCommand` / `RouteGenerator` / the generators / the finale fixture), completely bypassing the presenter and the entropy source.** So they are byte-identical by construction. Coexistence, stated plainly: *the approved seed catalogs stay reproducible under their fixed seeds while the live RUN seed varies* — because the catalogs never call the flow-layer entropy source, and the seam unit test injects a FIXED entropy so even it is deterministic.

Load-bearing determinism/regression tests (all explicit-seed; must stay byte-identical):

- `godot/tests/integration/test_seed_regression_suite.gd` — the consolidated 10.2 suite; its own header asserts it "moves NO determinism/save invariant (7 RNG streams, 23-key RunSnapshot, SCHEMA_VERSION==1)". Aggregates the batch/route/finale regressions; drives `REWARD_SEED_SAMPLE` / `TACTICAL_SEED_SAMPLE` (both include 4242) / `AFFINITY_SEED_SAMPLE`.
- `godot/tests/unit/generation/test_route_generation_seed_regression.gd`, `test_small_level_layout_seed_regression.gd`, `test_medium_level_layout_seed_regression.gd`, `test_seed_batch_regression.gd`; `godot/tests/integration/test_generator_fairness_batch.gd` — generation/route LAYOUT fingerprints (14.4 touches no generation code).
- `godot/tests/integration/finale/test_finale_seed_regression.gd`, `test_finale_full_run.gd`, `godot/tests/fixtures/run/finale_run_fixture.gd` — the finale chain (canonical seed 4242).
- `godot/tests/unit/run/test_reference_combat_driver.gd` — the **combat-replay** byte-determinism / winnability proof. **14.1 re-pinned this to Medium seed 24680** (corpse-clearing changed movement legality); 14.4 must NOT move it (14.4 touches no combat/generation code — it holds trivially, but the dev must confirm the fingerprint is byte-identical).
- `godot/tests/unit/generation/test_manual_seed_loader.gd` — the FR27 manual-seed loader (owns 2 of the 6 documented int64-overflow stderr negatives; explicit seeds).
- `godot/tests/unit/save/test_run_snapshot.gd` (the 23-key gate + root_seed decimal-string encoding), `godot/tests/unit/core/test_rng_stream_set.gd` (7 streams, `_derive_seed`, restore), `godot/tests/unit/save/test_run_resume_service.gd` (line 431: GameSession must preserve a full int64 root_seed — no >2^53 truncation).

### Winnability proof vs generator fairness (the one live-behavior consequence worth understanding)

The reference-driver **winnability proof** guarantees a specific approved seed **batch** (`[4242, 8080, 6006, 2048, 512]`, `deferred-work.md`) is winnable by the scripted driver. Today the live game always plays 4242 (a known-winnable seed). After 14.4 the **live human path** plays **arbitrary** entropy seeds — which are NOT in the winnability batch. **This is fine and by design:**

- An arbitrary seed still produces a **fair, non-soft-locked, solvable** level: the generator's Epic-3/10 validation guarantees entrance→exit pathing, legal placement, and a safe first reveal for **all** seeds; 14.1 removed the corpse-block soft-lock and added `WaitCommand` (turns always advance). Fairness is a per-seed generator guarantee, not a per-seed driver proof.
- The **hands-off / reference / auto-resolve drivers** (which DO depend on driver-winnability of a specific seed) are **never** used for live human play — they run on VERIFIED seeds (4242 canonical for the finale) and are exercised only by tests, which pass explicit seeds. 14.4 does not change them.

So: live variety relies on **generator fairness** (holds for every seed); the winnability **proofs** stay on their verified explicit seeds (untouched). Do not conflate the two.

### No approved-catalog seed is added

14.4 varies the **runtime** seed a live player receives; it does **not** add any entry to a pinned test seed catalog. (The 14.1 retro warns that new Medium seer-catalog seeds must be found by search, not picked arbitrarily — that constraint does not bind 14.4, which pins no test seed.)

### Deferred-work overlaps folded in (only the two that touch 14.4's area)

- **The Necromancer/Shadeblade profile-threading defer** (`deferred-work.md`, "Wire `hero_select_presenter.gd`'s standalone scene to be profile-aware … the `controller.start(...)` call (currently `controller.start(seed, false, class_id)` … line 102)"). This defer owns the *4th `profile` argument* of the exact line 102 that 14.4 edits. **14.4 changes only the seed + `is_manual_seed` args and leaves the `profile` arg absent (null → today's static gate).** Do **not** reopen or resolve the profile defer — it stays bundled with the Necromancer/Shadeblade class-kit content story. Just don't let the seed edit accidentally introduce (or block) profile threading.
- **The FR28 manual-seed-no-progression lineage** (8.3 award / 8.4 merge / 8.5 first-death / 9.4 first-victory gates; `RunSnapshot.meta_progression_eligible`). 14.4 must preserve this model exactly: entropy runs stay `is_manual_seed = false` (meta-eligible); only an explicit seed is `is_manual_seed = true` (no meta). The first-death/first-victory narrative latches are eligibility-**independent** (a manual-seed run still shows the line) — 14.4 does not touch those latches, but must not flip a normal run's eligibility.

No other deferred-work item overlaps 14.4 (run-level event store → 14.3/14.5; reward-overlay geometry + passive `display_name` → 14.11; full-backpack escape hatch → 14.7; run-summary outcome label → 14.5 are all out of scope here).

### Epic-14 constraints inherited (retro-notes/epic-14.md + the sprint change)

- **The EXACT files to touch** (the SM "wrong files" precision point from the 14.1 retro): the new-run seed callers are **`hero_select_presenter.gd`** and **`outpost_presenter.gd`**, plus the new seam **`godot/scripts/ui/flow/run_seed_source.gd`** and its test. Do **not** edit `run_flow_controller.gd`, `run_orchestrator.gd`, `run_start_command.gd`, or any generation/save file — the seed flows through them unchanged.
- **14.4 re-pins NOTHING.** 14.1 was the only Epic-14 story permitted to re-pin a fingerprint (its justified combat-replay re-pin to seed 24680). 14.4 is a flow-layer seed-source change over `scripts/ui/` — **every** generator/route/finale/combat seed-regression fingerprint is byte-identical. A moved fingerprint here is a bug.
- **Do NOT use eager `String(nullable)` in assert messages** (14.1 retro: it crashes on a null read and silently masked the 512 winnability regression). Use `str(...)`.
- **Keep the false-PASS grep guard standing** (Epic-13 retro): grep the raw runner output for `SCRIPT ERROR|Parse Error|^FAIL`; never trust the summary PASS line alone. Exactly six documented stderr negatives are expected; ZERO new.
- **Import discipline** (13.1): 14.4 adds **no art**. It adds one `.gd` global class → generate + commit its `*.gd.uid` sidecar in the same change (`godot --headless --import`). Bridges live under `flow/` (the convention).
- **Difficulty is a hard non-goal** — 14.4 changes no enemy stat / HP / damage / reward / run-length number; only which seed the live caller hands in.

### Anti-patterns to avoid (this story specifically)

- **Do NOT change `RunStartCommand`, the generation pipeline, or any named RNG stream.** A run stays a pure function of `(root_seed, is_manual_seed)`. 14.4 changes the *input seed*, never the *consumption* of it.
- **Do NOT add a save-schema field or a migration test.** `root_seed`/`is_manual_seed`/`meta_progression_eligible` already exist in the 23-key `RunSnapshot`; the entropy seed reuses `root_seed`. The gate stays 23; `SCHEMA_VERSION` stays 1.
- **Do NOT put the entropy read inside the seam.** The seam is the pure DECISION (entropy injected); the presenter supplies the one impure OS-entropy line. Otherwise the seam is un-unit-testable (violates AC3).
- **Do NOT draw entropy from a named `RngStreamSet` stream or the global `randi()`/`randf()`.** The seed source is chosen BEFORE any stream exists (streams derive FROM it — circular). Use a local `RandomNumberGenerator.randomize()` (or `Time.get_ticks_usec()`), which is a non-gameplay one-time pick.
- **Do NOT use `int(Time.get_unix_time_from_system())`** as the entropy — second-resolution collisions re-create the same-room bug on rapid re-descend.
- **Do NOT flip a normal entropy run to `is_manual_seed = true`** — it would silently disable meta progression for every normal re-descend (FR28/FR60 regression).
- **Do NOT fix only hero-select.** Both live callers (Descend AND Descend Again) must route through the seam, or re-descends stay on the fixed seed.
- **Do NOT thread the profile into `controller.start(...)`** — that stays the deferred Necromancer/Shadeblade concern; keep the null-profile status quo.
- **Do NOT change `OutpostViewModel.start_run_request` or its pinned `START_REQUEST_KEYS`.** The outpost presenter builds its request inline; only the seed value + `is_manual_seed` value change there.

## Project Structure Notes

- New seam → `godot/scripts/ui/flow/run_seed_source.gd` (beside `run_flow_controller.gd`, `run_flow_router.gd`, `run_end_profile_bridge.gd`, `reward_resolution_bridge.gd` — the flow-layer bridges). Its `.gd.uid` sidecar committed. Test → `godot/tests/unit/ui/test_run_seed_source.gd` (beside `test_run_flow_router.gd`).
- Presenter edits → `godot/scripts/ui/presenters/hero_select_presenter.gd` and `godot/scripts/ui/presenters/outpost_presenter.gd` only.
- Assertable decision logic (the manual-vs-entropy decision, the non-negative/non-zero normalization) lives in the scene-free `RefCounted` seam and is unit-tested. The presenters are thin glue verified by construction + the `test_run_flow_scenes_load.gd` compile guardrail — **no SceneTree presenter test**, and the impure entropy read is not unit-tested (a single thin OS-entropy line).
- No new autoload. `scripts/rules/{conditions,operations}` unchanged. No domain/command/event/save/RNG file is touched.

## Project Context Rules

Extracted from `project-context.md` (canonical rulebook) and the architecture (`_bmad-output/game-architecture.md`):

- **Named RNG only; deterministic under seed (NFR13).** Gameplay randomness uses its assigned named stream; **no fallback global randomness for gameplay outcomes.** The per-run seed **source** is explicitly NOT a gameplay draw (it is the root the streams derive from, chosen before any stream exists — D4), so a local `randomize()`/`Time`-based one-time pick is the sanctioned mechanism and does not violate the named-stream rule. `RngStreamSet.required_streams()` stays the 7 (`map, level, combat, loot, rewards, events, cosmetic`), unchanged, unreordered.
- **Save truth = versioned domain snapshots (NFR15).** The 23-key `RunSnapshot` gate stays 23; `SCHEMA_VERSION == 1`; `root_seed` is the existing int64 decimal-string field; `meta_progression_eligible = not is_manual_seed`. No save change; no migration.
- **Domain owns truth; presentation observes + submits commands.** The seed source is a flow-layer read that hands a value to the authoritative `RunStartCommand`; the UI owns no run truth and the command remains the pure `(root_seed, is_manual_seed)` factory.
- **Runs are seeded and forward-only; manual seed allowed but grants no meta (FR26/FR27/FR28/FR29).** Normal = entropy + meta-eligible; manual = explicit seed + no meta + byte-reproducible.
- **Assertable logic lives in scene-free `RefCounted` seams** (no SceneTree presenter tests — verify by construction + the compile guardrail). No new autoload.
- **Difficulty is a hard non-goal.** No knob that scales enemy stats/HP/damage/rewards/run length.
- **Every generator/route/finale/combat seed-regression fingerprint stays byte-identical** (14.4 touches only the flow-layer seed source + two presenters; no fingerprint can move — including the 14.1-re-pinned combat replay at seed 24680).
- **Headless suite stays green** (200 PASS baseline post-14.3; false-PASS grep `SCRIPT ERROR|Parse Error|^FAIL` clean beyond the 6 documented negatives).

### Mandatory test command (must pass before this story moves to review/done)

```
godot --headless --path C:\Sealsworn\godot --scene res://tests/headless/test_runner.tscn --quit-after 10
```

`godot` is not on the Bash/`where` PATH; run via PowerShell (`C:\Users\Rasmus\bin\godot.cmd`, or the standalone `C:/Users/Rasmus/Godot_v4.6.3-stable_win64.exe/Godot_v4.6.3-stable_win64_console.exe`). Apply the false-PASS grep guard on the raw output. The runner auto-discovers `test_*.gd` under `res://tests/unit` and `res://tests/integration` only.

### References

- `_bmad-output/planning-artifacts/epics.md#Epic 14: Playable & Presentable` — Story 14.4 ACs (body lines 3046-3067); Epic List entry (lines 521-527); Band-1 demarcation (line 2971); FR26/FR27/FR28/FR29 (lines 74-81).
- `_bmad-output/planning-artifacts/sprint-change-proposal-2026-07-16.md` — F11 identical-board (line 23); **D4 per-run seed source** (§3.1, line 106); the 14.4 finding→scope row (line 134: "Flow-layer seed source only; `RunStartCommand`/generation unchanged; all seed-regression tests pass explicit seeds → byte-identical; no named-stream change"); "the ONE determinism source change" framing (line 66).
- `_bmad-output/auto-gds/retro-notes/epic-14.md` — the 14.1 combat-replay re-pin (seed 24680) that 14.4 must not move; the `String(nullable)`-in-assert masking risk; the SM "wrong files to touch" precision point.
- `_bmad-output/implementation-artifacts/deferred-work.md` — the Necromancer/Shadeblade profile-threading defer on `hero_select_presenter.gd` line 102 (14.4 edits the seed args only, leaves `profile` deferred); the FR28 manual-seed-no-progression lineage (8.3/8.4/8.5/9.4); the winnability seed batch `[4242, 8080, 6006, 2048, 512]`.
- `_bmad-output/implementation-artifacts/14-3-combat-event-log-and-hit-feedback.md` — the ratified Epic-14 presentation-only story shape, the RefCounted-seam + pinned-key-set pattern, the false-PASS grep discipline, the 200 PASS baseline.
- Source files (read before implementing):
  - `godot/scripts/ui/presenters/hero_select_presenter.gd` — `DEFAULT_RUN_SEED` (21); `_on_confirm_pressed` (97); `controller.start(seed_value, false, _selected_class_id)` (102); `_resolve_seed` (117-123).
  - `godot/scripts/ui/presenters/outpost_presenter.gd` — `DEFAULT_DESCENT_SEED` (34); `_on_descend_pressed` (291); the inline request (299-304) + `controller.start(...)` (309-313); the `START_REQUEST` note (do not touch the VM seam).
  - `godot/scripts/ui/flow/run_flow_controller.gd` — `start(root_seed, is_manual_seed, class_id, profile)` (106) → `_orchestrator.start(...)`. Unchanged; the seed flows through.
  - `godot/scripts/run/run_orchestrator.gd` — `start(...)` (198-207): `RunStartCommand.new(...).execute(null)` (199), `streams = RngStreamSet.new(root_seed)` (203). Unchanged.
  - `godot/scripts/core/commands/run_start_command.gd` — the pure `(root_seed, is_manual_seed)` factory; `root_seed < 0` reject `invalid_run_seed` (155-159); the run_started event payload (`root_seed`/`is_manual_seed`/`node_count`). Unchanged.
  - `godot/scripts/save/snapshots/run_snapshot.gd` — `root_seed` field #5 (23) string-encoded (49); `is_manual_seed` (24); `meta_progression_eligible = not is_manual_seed` (190); the 23-key `to_dictionary` (43-68); `SCHEMA_VERSION == 1` (12). Unchanged.
  - `godot/scripts/core/state/rng_stream_set.gd` — `required_streams()` (7, lines 23-32); `configure(root_seed)` (35-43); `_derive_seed` 31-bit mask (233-238). Unchanged.
  - `godot/scripts/autoloads/game_session.gd` — `configure_seed` (20) / `get_root_seed` (26, default 0, the configured-seed carrier; no live caller of `configure_seed`).
  - Determinism tests to leave byte-identical: `godot/tests/integration/test_seed_regression_suite.gd`; `godot/tests/integration/finale/test_finale_seed_regression.gd` + `test_finale_full_run.gd`; `godot/tests/unit/generation/test_{route_generation,small_level_layout,medium_level_layout}_seed_regression.gd`, `test_seed_batch_regression.gd`, `test_manual_seed_loader.gd`; `godot/tests/integration/test_generator_fairness_batch.gd`; `godot/tests/unit/run/test_reference_combat_driver.gd` (seed 24680); `godot/tests/unit/save/test_run_snapshot.gd`; `godot/tests/unit/core/test_rng_stream_set.gd`; `godot/tests/unit/save/test_run_resume_service.gd` (line 431).

## Dev Agent Record

### Agent Model Used

Claude Opus 4.8 (gds-create-story)

### Debug Log References

### Completion Notes List

### File List

## Change Log

| Date | Version | Description | Author |
|---|---|---|---|
| 2026-07-18 | 0.1 | Story context created (gds-create-story). Flow-layer per-run seed variation: a pure `RunSeedSource` RefCounted seam (injected entropy → `{root_seed, is_manual_seed}`, 31-bit non-negative non-zero normalization, manual bypass) wired into BOTH live new-run callers (`hero_select_presenter` Descend + `outpost_presenter` Descend Again), replacing the two hardcoded seed-4242 sites. `RunStartCommand`/generation/RNG/save UNCHANGED — a run stays a pure function of its given seed; no schema change (root_seed already field #5 of the 23-key gate; no migration); every seed-regression/winnability/finale test passes explicit seeds → byte-identical (incl. the 14.1 combat replay at seed 24680). Manual-entry UI stays a later concern (D4 / 14.8). Status → ready-for-dev. | Claude Opus 4.8 (gds-create-story) |
