---
baseline_commit: 52b694b96ebb6861f83c2006def24e555b31d2a7
---
# Story 15.2: Attack-Preview Damage Correctness

Status: review

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a player,
I want the damage number in the attack preview to match the damage the attack actually deals,
so that I can plan a fight on the one number the game asks me to trust.

## Context & Why This Story Exists

Epic 15 ("Playtest Response") is the **third pre-ship playtest-response epic** (the Epic-13/14 pattern), added 2026-07-24 after a post-Epic-14 agent-driven desktop playtest confirmed the loop is **completable end-to-end for the first time** but surfaced 20 new findings (record `playtest-sessions/agent-playtest-2026-07-20.md`; triage `…-triage.md`; `sprint-change-proposal-2026-07-24.md`). Story 15.1 (Band 1) un-hid the HUD/log; Story 15.2 opens **Band 2 — Correctness & unwired surfaces (15.2–15.7)** and closes finding **F4**.

> **F4 — the previewed damage number lies.** A hero whose loadout grants an attack bonus (the pyromancer's **tome**, which adds +1 to staff/wand attacks) sees an attack preview showing the **weapon-base** number, but the committed attack resolves for **base + 1**. The preview omits the very bonus the game already applies on commit. The proposal's fix line (§ mapping table, row 15-2): *"Fold support-item + consumed-passive bonuses into the preview so shown N == resolved N (range-conditional note for steady-aim)."* Classified **read-model fix; no mutation/RNG; fingerprints byte-identical.**

**Root cause (grep-verified, see "The load-bearing architecture reality").** Story 12.2 intentionally threaded the class off-hand support into live combat: a pyromancer **tome** adds a **deterministic +1** to staff/wand attacks inside `AttackCommand` (`deferred-work.md:221-227` — the seeded AC4 class-path change; the tome bonus draws **no** RNG). But the attack-**preview** read model was never taught about the support: `AttackPreviewQuery.preview_target_cell(board, actor_id, target_cell, weapon)` and `TacticalAttackPreview.from_query(…, weapon)` take **only the weapon**, so the previewed `expected_damage` is weapon-base only. The command adds the tome bonus on commit; the preview never did. **The preview and the resolution compute damage in two places with different awareness — that gap is the bug.**

**This story is a READ-MODEL CORRECTNESS fix. It corrects the PREVIEW to match RESOLUTION — never the reverse.** The `AttackCommand` resolved-damage path (and every event/metadata/RNG it emits) stays **byte-identical**: the attack already deals the right number; only the preview was wrong. This is **presentation/read-model over shipped, pinned domain contracts** — the same ratified posture as the rest of Epic 15: **every seed-regression fingerprint stays byte-identical across all of Epic 15** (proposal §2.1; epics.md Epic-15 sequencing note), difficulty stays a hard non-goal (this story changes **no** number the attack actually deals), no new autoload, assertable logic lives in scene-free `RefCounted` seams. The four ratified Epic-15 design decisions do **NOT** touch this story: **D1 HP-persistence → 15.5, D4 shards-on-death → 15.5, D2 move-confirm → 15.7, D3 class-weighted rewards → 15.6.** Do not pull any of them in.

### ⭐ THE CRUX — thread the ATTACKER support into the preview so `expected_damage` folds the deterministic bonus the command already applies; leave `AttackCommand` and `expected_base_damage` untouched (read before Task 1)

Four boundaries define this story. Get them wrong and you either move a fingerprint (a firing offence in Epic 15) or ship a preview that still lies.

1. **The number the player reads is `preview.metadata.expected_damage`; it must equal the command's `final_damage`.** Today `TacticalAttackPreview.from_query` sets **both** `expected_damage` and `expected_base_damage` to the same weapon-base value. The fix makes them **diverge when a support bonus applies**: `expected_base_damage` **stays** the adjacency-adjusted weapon base (unchanged — see boundary 2); `expected_damage` becomes the **deterministic total** `max(1, adjacency_base + attacker_support_bonus)`, mirroring `AttackCommand`'s deterministic path. The armed-preview panel already displays `expected_damage` (falling back to `expected_base_damage`) — so once `expected_damage` carries the total, the on-screen "Expected damage: N" is correct with **no panel change**.

2. **`expected_base_damage` is load-bearing for `AttackCommand` — do NOT change it.** `AttackCommand.execute` reads `expected_base_damage` from the preview metadata as its `base_damage`, then **independently** adds `_support_bonus_damage()` on top (`attack_command.gd:93-95`). If you fold the support bonus into `expected_base_damage`, the command would **double-count** it and the resolved damage would change (a fingerprint move + a real balance change). Keep `expected_base_damage` = weapon base; add the bonus **only** to `expected_damage`. The `AttackPreviewContractMatrix` fixture and `test_attack_command.gd`'s `expected_base_damage` assertions must stay green unchanged.

3. **Only the ATTACKER support belongs in a hero's own preview; the defender armor/block never applies to the hero's own attack.** On the hero's own attack the class off-hand rides the **attacker** slot (`interactive_combat_session.gd:336-344`), and the **defender** slot is the enemy the hero strikes — **enemies carry no support**, so `defender_support` is null: **zero armor, zero shield-block, no `combat`-stream draw** on a hero attack. The block is RNG and defender-side; it is correctly **absent** from the hero preview. So the hero-preview total is purely deterministic: `max(1, adjacency_base + attacker_support_bonus)`. (The shield's block only fires on **incoming enemy** attacks against a shielded hero — not a surface this story previews.)

4. **This is deterministic and fully headlessly provable — that is this story's strength (and how it differs from 15.1).** Unlike 15.1's verify-by-construction structural fix, preview-equals-resolved is a **pure assertion** you can lock in a headless unit test. AC2 demands exactly that: *"a regression test asserts preview-equals-resolved for each class's starting kit, so a future bonus source cannot silently desynchronize them again."* Write that test; it is the guard-rail the whole story exists to install. (Only the on-**screen** rendering of the corrected number rides the existing panel and is verify-by-construction — a light OSG-1 confirmation, below — but the **correctness** is test-locked.)

### The load-bearing architecture reality (read before Task 1)

The player-facing armed-preview number flows through this exact chain (grep-verified against source):

- **Resolution (the source of truth — DO NOT TOUCH).** `AttackCommand.execute` (`godot/scripts/core/commands/attack_command.gd`): `base_damage = preview.expected_base_damage` (93) → `support_bonus_damage = _support_bonus_damage()` (94; `343-348`: `attacker_support.supports_bonus_for_weapon(weapon_id) ? bonus_damage : 0`) → `damage_before_defense = base + bonus` (95) → `armor_reduction` (96; **0** when `defender_support == null`) → block halving (`98-116`; only when `defender_support` is a `shield`, RNG on `combat`) → `final_damage = max(1, …)` (116). **For a hero attack (defender null): `final_damage = max(1, adjacency_base + attacker_support_bonus)`.** This is the number the preview must match.
- **The preview read model (the file to FIX #1).** `AttackPreviewQuery.preview_target_cell(board, actor_id, target_cell, weapon)` (`godot/scripts/tactical/targeting/attack_preview_query.gd:11-99`) — takes **only weapon**; `_expected_damage(weapon, distance)` (`160-163`) computes the adjacency-adjusted base; returns `expected_base_damage` (95). **No support awareness.** Add an optional `attacker_support` param; keep `expected_base_damage` = base; return a deterministic total.
- **The preview VM (the file to FIX #2).** `TacticalAttackPreview.from_query(board, actor_id, target_cell, weapon)` (`godot/scripts/ui/view_models/tactical_attack_preview.gd:20-68`) maps the query metadata into the VM, setting **both** `expected_damage` and `expected_base_damage` from `expected_base_damage` (`33, 48-49`). Add an optional `attacker_support` param, forward it to the query, and set `expected_damage` = the deterministic total.
- **The commit flow (the file to FIX #3 — where the ARMED preview is stored).** `TacticalAttackCommitFlow` (`godot/scripts/ui/view_models/tactical_attack_commit_flow.gd`). The **arming** tap stores the displayed preview: `tap_attack_target(…, attacker_support, defender_support, …)` (`23-34`) **has** the attacker support but calls `_start_attack_preview(context, actor_id, target_cell, weapon)` (`34`) **without it** → the stored `_state.preview` (`119-132, 157-173`) is built support-blind. **This is the exact bug locus.** Thread `attacker_support` into `_start_attack_preview` (and forward it from `tap_attack_target`). `refresh_or_clear` (`94-116`) and `confirm_attack` (`37-73`) also rebuild the preview — thread it there too for consistency (`confirm_attack` uses the rebuilt preview only for legality gating, not the number; `refresh_or_clear` has **no live caller** — only `test_tactical_attack_commit_flow.gd:228` — so it is belt-and-suspenders, but keep it consistent so a re-arm can never regress the number).
- **The live driver already carries the support (NO change needed here).** `InteractiveCombatSession.tap_attack` (`godot/scripts/run/interactive_combat_session.gd:326-354`) resolves `resolved_attacker_support = attacker_support if attacker_support != null else _loadout_support` (`342`) and passes it to `_commit_flow.tap_attack_target(…, resolved_attacker_support, …)` (`343-344`). `_loadout_support` was seated in `begin(…)` from `flow.hero_support()` (`gameplay_shell_presenter.gd:115` → `run_flow_controller.gd:148-149` → `CombatLoadout.for_run` → the pyromancer's **tome**). The presenter reads the **session's** commit flow for the board VM's `preview` slot (`tactical_board_presenter.gd:413-414, 432, 440, 454`). So once `tap_attack_target → _start_attack_preview → from_query → query` threads the support, the live displayed number is fixed **with no session/presenter/board-VM change.**
- **The panel needs NO change.** `TacticalAttackPreviewPanel.from_board_vm` (`godot/scripts/ui/view_models/tactical_attack_preview_panel.gd:53, 60-61`) already reads `expected_damage` first (fallback `expected_base_damage`) for both the `armed_label` and the "Expected damage: N" line. `expected_damage` is an **existing** metadata key — the fix changes its **value**, not the key set, so **no board-VM / panel key gate moves.**

**Per-class arithmetic (the regression-test targets):**

| Class (starting kit) | Weapon (base, adjacency) | Off-hand (attacker slot) | Preview today | Resolved | After fix |
|---|---|---|---|---|---|
| **Pyromancer** | staff (base **4**, HALF ×0.5 → adjacent **2**) | **tome** (+1 for staff/wand) | 4 ranged / 2 adjacent | **5** ranged / **3** adjacent | preview 5 / 3 == resolved ✓ (**the fix**) |
| **Warrior** | sword (base **4**, melee, no adjacency mod) | **shield** (bonus_damage **0**) | 4 | 4 | preview 4 == resolved ✓ (fix must **not** over-count: shield adds 0) |
| **Ranger** | bow (base **3**, RANGED_70 ×0.7 → adjacent **2**) | **none** (null) | 3 ranged / 2 adjacent | 3 / 2 | preview == resolved ✓ (unchanged) |

(Weapon numbers: `weapon_repository.gd:85-191`; tome: `support_repository.gd:98-105`; kits: `class_repository.gd:90-124`. `_tome_bonus_applies_after_adjacency_modifiers` already pins the **command** side — staff adjacent base 2 + tome 1 = final 3: `test_attack_command.gd:143-157`.)

## Acceptance Criteria

**AC1 — The previewed number equals the resolved number, folding deterministic loadout bonuses; conditional bonuses are labelled, never silently omitted (F4; FR9/FR10; NFR9)**
Given a hero whose loadout or consumed passives grant an attack bonus (a support item such as the **tome**, or a consumed damage passive)
When an attack is armed and the preview renders its expected damage
Then the previewed number (`preview.metadata.expected_damage`, shown by the armed panel as "Expected damage: N" and in `armed_label`) **equals** the damage the committed attack resolves (`AttackCommand` `final_damage`), **including support-item bonuses and consumed-passive bonuses** that resolution actually applies
And a bonus that applies only **conditionally** (for example a range-conditional steady-aim bonus) is either **reflected in the number** for the previewed target **or stated as a labelled condition** (a warning/effect line) — **never silently omitted** (the existing adjacent-ranged penalty already satisfies this pattern: the number is adjacency-adjusted AND a warning line is emitted — do not regress it).

**AC2 — The preview stays a pure read model; resolution is unchanged; a regression test locks preview==resolved for every starting kit (Epic-15 standing constraint; NFR13/NFR15)**
Given the preview is a read model
When the corrected computation lands
Then the preview **draws zero RNG and mutates nothing** (arming and cancelling leave the run byte-identical), and the **resolved-damage path is unchanged** — `AttackCommand`, its events/metadata, and its `combat`-stream draws are **byte-identical** (the preview is corrected to match resolution, not the reverse; `expected_base_damage` and the `AttackPreviewContractMatrix` stay unchanged so the command does not double-count)
And a **regression test asserts preview-equals-resolved for each class's starting kit** (warrior sword+shield, pyromancer staff+tome at both ranged and adjacent distances, ranger bow+none), so a future bonus source cannot silently desynchronize them again.

**AC3 — Pinned-contract posture: read-model only, every fingerprint byte-identical (Epic-15 standing constraint)**
Given the pinned contracts
When this story lands
Then **no domain / command / event / RNG / save contract changes** beyond the read-model preview correction: the 16-key `TacticalBoardViewModel` gate stays 16 (no new board-VM key — `expected_damage` already exists in the preview metadata), the 11-key `TacticalAttackPreviewPanel` `PANEL_KEYS` set is unchanged (value change only), `RunSnapshot` stays 23-key / `SCHEMA_VERSION == 1`, the 7 named RNG streams are unchanged and unreordered, no new event/enum value, no new autoload, no new RNG draw site, and **every pinned combat/generation/route/finale seed-regression fingerprint stays byte-identical** (Epic 15 moves NO fingerprint)
And this story touches **no** `project.godot` project setting, input map, or save format; difficulty stays a hard non-goal (no number the attack actually deals changes).

## Tasks / Subtasks

- [x] **Task 1 — Confirm the desync and pin the fix locus (AC1, AC2)**
  - [x] Read `attack_command.gd` (`93-116`, `343-348`), `attack_preview_query.gd` (`11-99`, `160-163`), `tactical_attack_preview.gd` (`20-68`), `tactical_attack_commit_flow.gd` (`23-34`, `94-132`), and `interactive_combat_session.gd` (`326-354`). Confirm: the command's `final_damage` for a hero attack (defender null) = `max(1, adjacency_base + attacker_support_bonus)`; the preview's `expected_damage`/`expected_base_damage` are weapon-base only; the arming call (`tap_attack_target → _start_attack_preview`) drops the attacker support.
  - [x] Confirm the deterministic total formula the preview must produce mirrors resolution: `max(1, _expected_damage(weapon, distance) + attacker_support_bonus)` where `attacker_support_bonus = (attacker_support != null and attacker_support.supports_bonus_for_weapon(weapon.weapon_id)) ? attacker_support.bonus_damage : 0`. Do not fix yet — pin the cause first (the 14-1 retro P4 "grep the live surface before scoping" habit).

- [x] **Task 2 — Thread the attacker support into the preview computation (AC1, AC2, AC3)**
  - [x] `AttackPreviewQuery.preview_target_cell(...)`: add an optional trailing `attacker_support: SupportDefinition = null` param (default null → **byte-identical** to today's support-blind path). Keep `expected_base_damage` = `_expected_damage(weapon, distance)` (weapon base — UNCHANGED). Compute and return a new deterministic `expected_damage = max(1, expected_base_damage + attacker_support_bonus)` in the success metadata. Validate the support the same fail-open way the command does (a null/non-bonus support contributes 0; do **not** reject on it — the query already validates the weapon). Keep the query **pure, zero-RNG, zero-mutation**. Do not change any error/reason path or any other metadata key (the `AttackPreviewContractMatrix` legality cases must stay green).
  - [x] `TacticalAttackPreview.from_query(...)`: add the optional `attacker_support: SupportDefinition = null` param, forward it to the query, and set `metadata.expected_damage` = the query's total (keep `metadata.expected_base_damage` = base). The VM key set is unchanged (both keys already exist). Keep it a pure projection.
  - [x] **Single-source-of-truth (recommended, only if byte-identical):** if you extract the deterministic-bonus math into one shared pure helper that BOTH the preview and `AttackCommand`'s deterministic portion call, you best satisfy AC2's "a future bonus source cannot silently desynchronize them again." Do this **only** if `AttackCommand`'s resolved output stays byte-identical (same events/metadata/RNG, no fixture moves) — verify with the full suite. If in any doubt, prefer the minimal preview-side fix + the regression test (which is the actual AC2 contract) and leave `AttackCommand` untouched.

- [x] **Task 3 — Thread the support through the commit-flow arming path (AC1)**
  - [x] `TacticalAttackCommitFlow._start_attack_preview(...)`: add the `attacker_support` param and pass it to `TacticalAttackPreview.from_query(...)`. `tap_attack_target(...)` already receives `attacker_support` — forward it into `_start_attack_preview` (line 34). Thread it through `refresh_or_clear(...)` and `confirm_attack(...)` as well so a re-arm/refresh can never regress the number (note: `confirm_attack`'s rebuilt preview is used only for legality gating; `refresh_or_clear` currently has no live caller — thread for consistency and update its one test caller).
  - [x] Confirm the LIVE path needs **no** session/presenter change: `InteractiveCombatSession.tap_attack` already resolves `resolved_attacker_support` (the loadout tome/shield/none) and passes it to `tap_attack_target`; the presenter reads `_session.commit_flow_state()` for the board-VM `preview` slot. Verify the pyromancer's armed preview now shows the tome-boosted number end-to-end (via the session/commit-flow unit path, not a SceneTree test).
  - [x] **Secondary surface — `TacticalInspectView._attack_data` (`tactical_inspect_view.gd:128-142`)** builds an attack preview via `from_query(…, weapon)` **without** support (its `options` carry actor+weapon, not the loadout support). It is FR12 tile-inspection, **outside AC1's "armed preview" scope**. Default: **leave it on the weapon-base figure** (a generic "what this weapon does" read) so you introduce no new contradiction and no fingerprint risk — but add a one-line dev note recording that inspect intentionally shows weapon-base, not the loadout-boosted armed number. Only thread the support into inspect if the inspect `options` already carry the hero support cheaply; do not add a new option plumbing path for it in this story.

- [x] **Task 4 — Regression test: preview == resolved for each starting kit (AC2)**
  - [x] Add a headless regression test (extend `test_attack_command.gd`, or a new `test_*.gd` under `tests/unit/` — if new, run `--headless --import` separately for the `.gd.uid`) that, for **each** MVP class starting kit, builds a surviving-target board, runs `TacticalAttackPreview.from_query(board, hero, cell, weapon, support)` AND `AttackCommand.new(hero, cell, weapon, support, null).execute(context)`, and asserts `preview.metadata.expected_damage == command.metadata.final_damage`:
    - **pyromancer** staff+tome at a **ranged** cell (expected 5) AND an **adjacent** cell (expected 3 — catches the adjacency×tome interaction, the exact `_tome_bonus_applies_after_adjacency_modifiers` numbers);
    - **warrior** sword+shield (expected 4 — proves the fix does NOT over-count: shield adds 0 as attacker support);
    - **ranger** bow+none (expected 3 ranged / 2 adjacent — proves the no-support path is byte-identical).
  - [x] Assert the preview is a **pure read**: `from_query` mutates no board and advances no RNG stream (snapshot the board + streams before/after and assert unchanged); a null/no-bonus support yields `expected_damage == expected_base_damage`. Reuse the existing `attack_command_tome_staff()` / `attack_command_tome_wand()` board fixtures (`board_fixture_factory.gd`) and the `_support(...)`/`SupportRepository.create_baseline_repository()` helpers already used in `test_attack_command.gd` / `test_tactical_preview_view_models.gd`.

- [x] **Task 5 — Update the coupled preview-VM test + gates held + suite green (AC1, AC2, AC3)**
  - [x] `test_tactical_preview_view_models.gd:196-197` currently asserts `expected_damage == expected_base_damage` ("Attack preview should not include execution-only damage outcomes") for the **no-support** contract-matrix cases. Those cases pass **no** support, so `expected_damage` still equals `expected_base_damage` and the assertion **stays green** — but refine the comment to say `expected_damage` now folds **deterministic** loadout bonuses while still excluding **execution-only (RNG/block)** outcomes, and add at least one **support-bearing** case where `expected_damage == expected_base_damage + deterministic_bonus`.
  - [x] Confirm **no gate moved**: `TacticalBoardViewModel` (16 keys), `TacticalAttackPreviewPanel.PANEL_KEYS` (11 keys, value-only change), `RunSnapshot` (23-key / `SCHEMA_VERSION == 1`), `RngStreamSet` (7 streams), `DomainEvent` enum, `project.godot` — all byte-untouched. `AttackCommand`, `attack_preview_contract_matrix.gd`, and every `expected_base_damage` assertion unchanged. No generator/route/finale/combat fingerprint moves.
  - [x] **`.gd.uid` discipline:** if you add any new `.gd` (a new test or helper), run `godot --headless --import` **separately** to emit the `*.gd.uid` sidecar and commit it (the `--scene` test run does not emit it).
  - [x] Run the FULL headless suite (command below). Baseline **205 PASS files**; expect **≥205** (a new test file pushes ≥206; extending an existing test adds none). False-PASS grep guard `SCRIPT ERROR|Parse Error|^FAIL` on the RAW output = exactly the **6 documented** stderr negatives, ZERO new, none referencing a 15.2 file. `git diff --check` clean.

## Dev Notes

### What is ALREADY SHIPPED (reuse / correct — do NOT rebuild)

- **`AttackCommand`** (`attack_command.gd`, Story 1.9 + 12.2) — the resolved-damage authority. `_support_bonus_damage()` (`343-348`) is the deterministic tome bonus (weapon-gated via `supports_bonus_for_weapon`); armor/block (`351-354`, `184-212`) are defender-side and **never** apply to a hero's own attack (enemy = no support). **Leave byte-identical.**
- **`AttackPreviewQuery`** (`attack_preview_query.gd`, Story 1.8) — the pure targeting/damage read. `_expected_damage(weapon, distance)` (`160-163`) already applies the adjacency modifier; `_warning_entries` (`166-178`) already emits the adjacent-ranged penalty warning (the existing "conditional bonus labelled" pattern AC1 references). **Correct #1:** add the optional `attacker_support` param + the deterministic total.
- **`TacticalAttackPreview`** (`tactical_attack_preview.gd`, Story 2.2) — the render projection. **Correct #2:** add the optional `attacker_support` param + set `expected_damage` = total. Both metadata keys already exist.
- **`TacticalAttackCommitFlow`** (`tactical_attack_commit_flow.gd`, Story 14.2) — the two-step arm→confirm flow that stores the displayed preview. **Correct #3:** forward `attacker_support` into `_start_attack_preview`/`refresh_or_clear`/`confirm_attack`.
- **`InteractiveCombatSession`** (`interactive_combat_session.gd`, Story 12.1/12.2) — the live on-screen driver; already seats `_loadout_support` and resolves it into `tap_attack`. **No change needed.**
- **`TacticalAttackPreviewPanel`** (`tactical_attack_preview_panel.gd`, Story 14.2) — already displays `expected_damage`. **No change needed** (value flows through).
- **Fixtures/helpers:** `board_fixture_factory.gd` (`attack_command_tome_staff/wand`, `attack_preview_*`), `AttackPreviewContractMatrix` (`attack_preview_contract_matrix.gd` — legality/base cases, **do not change**), `SupportRepository.create_baseline_repository()` / `_support(...)` helpers.

### The root-cause thesis in one line

Story 12.2 gave `AttackCommand` a deterministic tome bonus but the attack-**preview** read model was never told about the support, so the previewed `expected_damage` is weapon-base while the resolved `final_damage` is base+bonus — the fix threads the ATTACKER support into the preview (`query` + `from_query` + the commit-flow arming call) so `expected_damage` folds the same deterministic bonus resolution already applies, keeping `expected_base_damage`, `AttackCommand`, and every fingerprint byte-identical, and locks it with a preview-equals-resolved regression test per starting kit.

### Scope determinations (read — these prevent over-reach)

- **`ranger_steady_aim` is DESCRIPTION-ONLY; do NOT wire it (or any passive) into damage.** It is the ranger class passive but "settles the shot before an attack" is flavor text (`passive_repository.gd:190-194`); there is **no passive-combat-effect engine** (`scripts/rules/conditions/` is EMPTY; `deferred-work.md:214-219`). So consumed/class passives do **not** modify `AttackCommand` damage today — meaning preview==resolved for the passive case is **automatic** (both count zero). AC1's "consumed-passive bonuses" and the "range-conditional steady-aim" example are **forward-looking guards**: the regression test (AC2) is what catches a future desync. **Building a passive-damage mechanic is OUT OF SCOPE — it would move fingerprints and violate the Epic-15 "no new effect engine / difficulty non-goal / no fingerprint" constraints.** The only live preview-vs-resolved gap today is the **attacker-support (tome)** bonus.
- **The tome is the only live bonus source; the shield is a no-op on the hero's own attack.** The tome (+1 for staff/wand) is the deterministic attacker bonus. The shield (armor 1 / block 0.5 / bonus_damage 0) threaded as the hero's attacker support contributes **0 offensive damage** (`supports_bonus_for_weapon` is false for bonus_damage 0) — the warrior regression case proves the fix does not over-count.
- **Block/armor are defender-side and RNG — correctly absent from the hero preview.** A hero attack has `defender_support == null`, so no armor and no shield-block draw. If a future defender support is ever modeled, its block is conditional/RNG (→ labelled, not baked into the number) and its armor is deterministic (→ reflected) — but that is not this story.

### NFR9 — the non-color channel stays mandatory

The corrected number is **text** ("Expected damage: N" + `armed_label`), already the NFR9 accessible channel — additive over color, never a hue alone. The adjacent-ranged **warning line** must remain (the existing labelled-condition pattern). Do not drop any warning/effect line while correcting the number.

### Epic-14/15 constraints inherited (retro forward items + project-context + the sprint change)

- **Epic 15 moves NO seed-regression fingerprint; difficulty is a hard non-goal.** This story changes no number the attack actually deals — it corrects a read model. Prove it: `AttackCommand`, the 7 streams, and every combat/generation/route/finale fingerprint stay byte-identical (AC3).
- **Read models are pure: zero RNG, zero mutation (project-context; NFR13/NFR15).** The preview query/VM never draw RNG or mutate the board; assert it in the regression test (board + stream snapshots unchanged).
- **Seams expose only what the presenter consumes; assertable logic on scene-free `RefCounted` seams; no SceneTree presenter test (14-3 T3; the ratified verify-by-construction stance).** The fix lives entirely on `RefCounted` seams (`AttackPreviewQuery`, `TacticalAttackPreview`, `TacticalAttackCommitFlow`) — unit-test them; the panel/presenter stay verified by construction + `test_run_flow_scenes_load.gd`.
- **`.gd.uid` via `--headless --import` separately (13-1/14-8); keep the false-PASS grep guard standing (retro P3).** Grep the RAW runner output for `SCRIPT ERROR|Parse Error|^FAIL`; exactly the **6 documented** stderr negatives (int64-overflow ×2 [`test_domain_event.gd:146` + `test_manual_seed_loader.gd:153`], malformed-JSON ×3, `invalid_node_type` ×1); ZERO new. Never trust the summary PASS line alone.
- **Epic-15 retro (15-1) forward note.** 15-1's fix was verify-by-construction (a render symptom with no headless repro), so its behavioral confirmation deferred to OSG-1. **15-2 is different and stronger:** the correctness (preview==resolved) IS headlessly provable and must be test-locked (AC2). Only the on-screen *display* of the corrected number rides the existing panel and is verify-by-construction → a light OSG-1 confirmation (below), not the primary proof.

### Deferred-work overlaps folded in (only those that touch 15.2's area)

- **The 12.2 seeded tome/shield note (`deferred-work.md:221-227`) — this is the SOURCE of the desync, not a defect to re-open.** It records that threading a class support into live combat is the INTENTIONAL AC4 change: the pyromancer tome adds +1 (deterministic, no draw); the warrior shield engages the seeded `shield_block` on incoming enemy attacks only. 15.2 does **not** touch that resolution behavior — it makes the **preview** mirror the tome bonus the note introduced. Do not re-pin or alter any live-combat fixture; none moves (the preview is a read model).
- **The 14-2 round-2 raw-id defer (`deferred-work.md:111`) — OUT OF SCOPE (Story 15.11).** The armed panel surfaces the raw `target_entity_id` ("Target: enemy_iron"). You will be editing the preview/panel data area — **leave the raw-id issue alone**; the player-facing copy pass (kill `enemy_3`/raw-id leaks) is Story 15.11. Do not fold it here.
- **The 14-2 round-1 on-device defer (`deferred-work.md:105`) — 15.2 EXTENDS it.** The armed damage panel's on-screen render is verify-by-construction. 15.2 changes the NUMBER in that panel; its on-screen confirmation joins the OSG-1 checklist (below). Non-blocking; the headless preview-equals-resolved test is the real proof.

### OSG-1 on-device checklist additions (carry forward; not a blocker for this story)

- With a **pyromancer** (staff+tome), arm an attack: the panel's "Expected damage" shows the tome-boosted number (5 at range / 3 adjacent), and the committed hit deals exactly that.
- The adjacent-ranged **warning line** still renders alongside the (adjacency-adjusted) number for staff/bow at distance 1.

### Anti-patterns to avoid (this story specifically)

- **Do NOT change `expected_base_damage`, `AttackCommand`, or any fixture/RNG** — folding the bonus into `expected_base_damage` double-counts it in resolution (a fingerprint + balance move). Add the bonus only to `expected_damage`.
- **Do NOT build a passive-combat-effect engine** to satisfy "consumed-passive bonuses" — none exists today; the regression test is the guard. Wiring passive damage moves fingerprints and breaks the Epic-15 non-goal.
- **Do NOT add a board-VM / panel key, a domain/command/event change, or a new autoload** — `expected_damage` already exists; the 16/11-key and 23-key gates, `SCHEMA_VERSION == 1`, and the 7 streams stay byte-identical.
- **Do NOT draw RNG or mutate in the preview path** — arming/cancelling must leave the run byte-identical (assert it).
- **Do NOT thread a defender support into the hero preview** — a hero attack has no defender support; armor/block do not apply and the block is RNG (would corrupt determinism).
- **Do NOT touch snake_case copy / raw ids, telegraphs, the reward modal, animation, or the weapon-line HUD** — those are Stories 15.11/15.3/15.6/15.8/15.12.
- **Do NOT add a SceneTree presenter test** — decisions go on the `RefCounted` seams (unit-tested); the panel/presenter stay verified by construction + `test_run_flow_scenes_load.gd`.
- **Keep the false-PASS grep guard standing** — grep the RAW output; exactly the 6 documented negatives; ZERO new.

## Project Structure Notes

- **Files touched (production):**
  - `godot/scripts/tactical/targeting/attack_preview_query.gd` — MODIFIED: optional `attacker_support` param on `preview_target_cell` (and `preview_target_entity` if you thread it through); return deterministic `expected_damage` = `max(1, expected_base_damage + attacker_support_bonus)`; keep `expected_base_damage` = weapon base; pure/zero-RNG/zero-mutation.
  - `godot/scripts/ui/view_models/tactical_attack_preview.gd` — MODIFIED: optional `attacker_support` param on `from_query`; forward to the query; set `metadata.expected_damage` = total (keep `expected_base_damage` = base). No key-set change.
  - `godot/scripts/ui/view_models/tactical_attack_commit_flow.gd` — MODIFIED: thread `attacker_support` into `_start_attack_preview` (forwarded from `tap_attack_target`), `refresh_or_clear`, and `confirm_attack`.
  - (Optional) a single shared deterministic-damage helper IF byte-identical — only if `AttackCommand` output stays unchanged.
- **Tests:** ADD a preview-equals-resolved regression test per starting kit (extend `godot/tests/unit/core/test_attack_command.gd` or add a new `tests/unit/` test — run `--headless --import` separately for a new `.gd.uid`). UPDATE `godot/tests/unit/ui/test_tactical_preview_view_models.gd` (refine the `expected_damage`/`expected_base_damage` assertion + add a support-bearing case) and `godot/tests/unit/ui/test_tactical_attack_commit_flow.gd:228` (the `refresh_or_clear` caller signature if you add the param). Extend `test_tactical_attack_preview_panel.gd` only if you assert the boosted number surfaces (value, not key).
- **Out of bounds:** `AttackCommand` resolved path, `attack_preview_contract_matrix.gd`, `project.godot`/input map/save format, any `scripts/{rules,generation,ai,save,core/state}` file, the reward modal, telegraphs, animation, snake_case/raw-id copy, the inspect-view option plumbing. The board queries' domain and every generator/route/finale/combat fixture are byte-untouched.

## Project Context Rules

Extracted from `project-context.md` (canonical rulebook) and the architecture (`_bmad-output/game-architecture.md`):

- **Domain owns truth; presentation observes + submits commands (hard architecture rule; NFR14/NFR15).** 15.2 corrects a read model over the shipped `AttackCommand`; the preview owns no tactical truth and mutates nothing.
- **Gameplay actions validate before mutation and return `ActionResult`; successful commands emit deterministic past-tense events (hard rule).** `AttackCommand` (the source of truth) is untouched; the preview is a pre-command read that must agree with it.
- **Named RNG only; deterministic under seed (NFR13).** The preview draws ZERO RNG; the 7 named streams unchanged; Epic 15 moves NO seed-regression fingerprint.
- **`TacticalBoardViewModel.to_dictionary()` is an EXACT 16-key contract (project-context §pinned gates).** Correcting the `expected_damage` VALUE changes no key — the 16-key gate holds; do not add a key. `PassiveRewardModalViewModel`/board-VM/MODAL_KEYS gates are untouched.
- **Assertable logic lives in scene-free `RefCounted` seams with pinned key sets; no SceneTree presenter tests (verify by construction + the compile guardrail). No new autoload.**
- **Color-independence (NFR9).** The corrected number and any conditional warning stay textual/labelled — additive over color.
- **Difficulty is a hard non-goal.** 15.2 changes no enemy/HP/damage/reward number the game resolves — it fixes what the preview *reports*.
- **Headless suite stays green** (205 PASS baseline post-Epic-14; expect ≥205; false-PASS grep `SCRIPT ERROR|Parse Error|^FAIL` clean beyond the 6 documented negatives).

### Mandatory test command (must pass before this story moves to review/done)

```
godot --headless --path C:\Sealsworn\godot --scene res://tests/headless/test_runner.tscn --quit-after 10
```

`godot` is not on the Bash/`where` PATH; run via PowerShell (`C:\Users\Rasmus\bin\godot.cmd`, or the standalone `C:/Users/Rasmus/Godot_v4.6.3-stable_win64.exe/Godot_v4.6.3-stable_win64_console.exe`). Apply the false-PASS grep guard `SCRIPT ERROR|Parse Error|^FAIL` on the RAW output (never trust the summary PASS line alone). The runner auto-discovers `test_*.gd` under `res://tests/unit` and `res://tests/integration` only. Baseline **205 PASS files**; expect **≥205**, ZERO new stderr negatives beyond the 6 documented. Run `godot --headless --import` separately to emit any new `.gd.uid` sidecars before committing.

## References

- `_bmad-output/planning-artifacts/epics.md#Epic 15: Playtest Response` — Story 15.2 ACs (body lines 3283–3299); the Epic-15 sequencing/fingerprint/decision note (3255); the Band-2 demarcation (3281).
- `_bmad-output/planning-artifacts/sprint-change-proposal-2026-07-24.md` — the F4 → 15-2 map (mapping table row, line 160: "Fold support-item + consumed-passive bonuses…so shown N == resolved N (range-conditional note for steady-aim)"; classified read-model fix, fingerprints byte-identical); the Band-2 list (102); the contract-bounded 15-2 note (52); "difficulty is a hard non-goal" (235); the readable-and-correct goal (241).
- `_bmad-output/implementation-artifacts/deferred-work.md` — the 12.2 seeded tome/shield note (221–227, the SOURCE of the desync); the 14-2 round-2 raw-id defer (111 → Story 15.11, out of scope); the 14-2 round-1 on-device damage-panel defer (105 → OSG-1); the no-passive-effect-engine facts (214–219).
- `_bmad-output/auto-gds/retro-notes/epic-15.md` — 15-1's verify-by-construction note; contrast: 15.2's correctness is headlessly provable and must be test-locked.
- `_bmad-output/implementation-artifacts/15-1-hud-and-log-layout-clip-fix.md` — the ratified Epic-15 presentation/read-model story shape (RefCounted seams, no SceneTree test, `.gd.uid` discipline, false-PASS grep guard, deliberate in-change test updates).
- Source files (read before implementing):
  - `godot/scripts/core/commands/attack_command.gd` — `execute` damage math (`79-176`); `_support_bonus_damage` (`343-348`); armor/block (`184-212`, `351-354`). **Source of truth — DO NOT TOUCH.**
  - `godot/scripts/tactical/targeting/attack_preview_query.gd` — `preview_target_cell` (`11-99`); `_expected_damage` (`160-163`); `_warning_entries` (`166-178`). **Correct #1.**
  - `godot/scripts/ui/view_models/tactical_attack_preview.gd` — `from_query` (`20-68`); `expected_damage`/`expected_base_damage` (`33, 48-49`). **Correct #2.**
  - `godot/scripts/ui/view_models/tactical_attack_commit_flow.gd` — `tap_attack_target` (`23-34`); `confirm_attack` (`37-73`); `refresh_or_clear` (`94-116`); `_start_attack_preview` (`119-132`). **Correct #3 (arming).**
  - `godot/scripts/run/interactive_combat_session.gd` — `begin` support seat (`118-198`); `tap_attack` resolve (`326-354`). **No change.**
  - `godot/scripts/ui/view_models/tactical_attack_preview_panel.gd` — `expected_damage` read (`53, 60-61`); `PANEL_KEYS` (`18-30`). **No change (value flows through).**
  - `godot/scripts/content/repositories/{support,weapon,class}_repository.gd` — tome (`support_repository.gd:98-105`), weapon bases/adjacency (`weapon_repository.gd:85-191`), class kits (`class_repository.gd:90-124`).
  - `godot/scripts/content/definitions/support_definition.gd` — `supports_bonus_for_weapon` (`56-57`); `bonus_damage`/`bonus_weapon_ids`.
  - `godot/tests/unit/core/test_attack_command.gd` — `_tome_bonus_applies_after_adjacency_modifiers` (`143-157`); `_preview_contract_target_legality_reasons_match_command` (`~112-141`); `_command`/`_context` helpers.
  - `godot/tests/unit/tactical/test_attack_preview_query.gd` + `godot/tests/unit/ui/test_tactical_preview_view_models.gd` (`196-197`, the `expected_damage`==`expected_base_damage` assertion to refine) + `godot/tests/fixtures/tactical/attack_preview_contract_matrix.gd` (legality/base cases — unchanged).
  - `godot/tests/unit/ui/test_run_flow_scenes_load.gd` — the compile guardrail (loads the board scene + presenter).

## Dev Agent Record

### Agent Model Used

Story context by Claude Opus 4.8 (gds-create-story). Implementation by Claude Opus 4.8 (gds-dev-story).

### Debug Log References

- Full headless suite: `godot --headless --path C:\Sealsworn\godot --scene res://tests/headless/test_runner.tscn --quit-after 10` → **206 PASS files** (205 baseline + 1 new test file `test_attack_preview_matches_resolution.gd`), `Headless tests passed.`
- False-PASS grep guard `SCRIPT ERROR|Parse Error|^FAIL` on RAW output → 0 hits. Broader `ERROR` scan → exactly the **6 documented** stderr negatives (int64-overflow ×2, `invalid_node_type` ×1 [test_route_node], malformed-JSON ×3 [test_profile_repository + test_settings_repository]), ZERO new, none referencing a 15.2 file.
- `godot --headless --import` run SEPARATELY to emit `test_attack_preview_matches_resolution.gd.uid`. `git diff --check` clean (only benign LF/CRLF notices). Unrelated `--import` churn on three `*.svg.import` files restored (no content change).

### Completion Notes List

- **Root cause fixed as scoped.** Threaded the ATTACKER support through the preview chain — `AttackPreviewQuery.preview_target_cell` → `TacticalAttackPreview.from_query` → `TacticalAttackCommitFlow` arming (`tap_attack_target`→`_start_attack_preview`, plus `confirm_attack`/`refresh_or_clear` for consistency). The query now returns a deterministic `expected_damage = max(1, expected_base_damage + attacker_support_bonus)` mirroring `AttackCommand`'s hero-attack path; `expected_base_damage` (weapon base) is UNCHANGED so the command does not double-count.
- **`AttackCommand` untouched; damage/events/RNG byte-identical.** No shared-helper extraction (the conservative AC2 path): the regression test is the desync guard. The command still calls the query WITHOUT support (bonus 0 → `expected_damage == expected_base_damage == base`), so its `final_damage`, event payloads (`_attack_event_payload`/`_damage_event_payload` use explicit key lists that exclude `expected_damage`), and `combat`-stream draws are unchanged. The live-combat-resolver AC4 event-log fingerprint (the real determinism guard) is byte-identical.
- **Live path needs no session/presenter change** — `InteractiveCombatSession.tap_attack` already resolves `resolved_attacker_support` (the seated loadout tome/shield/none) and passes it to `tap_attack_target`; the panel already reads `expected_damage`. Verified via the commit-flow unit path (no SceneTree test).
- **Inspect stays weapon-base (dev note, per Task 3).** `TacticalInspectView._attack_data` calls `from_query(…, weapon)` with NO support (its `options` carry actor+weapon, not the loadout off-hand) — an intentional generic "what this weapon does" read (FR12, outside AC1's armed-preview scope). `test_tactical_inspect_view.gd:126` (`expected_damage == 3` for bow) stays green because a support-blind query yields `expected_damage == expected_base_damage`. No new option plumbing added.
- **Per-kit arithmetic locked** (preview == resolved): pyromancer staff+tome 5 ranged / 3 adjacent; warrior sword+shield 4 (shield `bonus_damage 0` → no over-count); ranger bow+none 3 ranged / 2 adjacent. Preview purity asserted (board + all 7 RNG streams unchanged across `from_query`).
- **Gates held:** no board-VM / `PANEL_KEYS` / `RunSnapshot` key added (value-only change to the existing `expected_damage` key), `SCHEMA_VERSION == 1`, 7 RNG streams unchanged, no new event/enum/autoload/RNG-draw-site, no `project.godot`/input-map/save-format touch. `AttackPreviewContractMatrix` and every `expected_base_damage` assertion unchanged. `ranger_steady_aim`/passive-effect engine correctly NOT built (out of scope; the regression test is the forward guard).

### File List

- `godot/scripts/tactical/targeting/attack_preview_query.gd` — MODIFIED: optional `attacker_support` param on `preview_target_cell`; new `_attacker_support_bonus()` helper; returns deterministic `expected_damage` (keeps `expected_base_damage` = weapon base; warnings/explanation stay on the base).
- `godot/scripts/ui/view_models/tactical_attack_preview.gd` — MODIFIED: optional `attacker_support` param on `from_query`; forwards to the query; sets VM `metadata.expected_damage` = the query total (fallback to base).
- `godot/scripts/ui/view_models/tactical_attack_commit_flow.gd` — MODIFIED: threads `attacker_support` into `_start_attack_preview` (from `tap_attack_target`), `confirm_attack`, and `refresh_or_clear`.
- `godot/tests/unit/tactical/test_attack_preview_matches_resolution.gd` — ADDED (+ `.gd.uid`): the AC2 preview-equals-resolved regression per starting kit + preview-purity/no-over-count assertions.
- `godot/tests/unit/ui/test_tactical_preview_view_models.gd` — MODIFIED: refined the no-support `expected_damage` comment; added `_attack_preview_folds_deterministic_loadout_bonus()` (support-bearing divergence + no-over-count case).
- `godot/tests/unit/ui/test_tactical_attack_commit_flow.gd` — MODIFIED: updated the one `refresh_or_clear` caller to pass `_support(&"none")`.
- `_bmad-output/implementation-artifacts/sprint-status.yaml` — MODIFIED: `15-2-attack-preview-damage-correctness` → `in-progress` → `review`.

### Change Log

- 2026-08-06 — Story 15.2 implemented (gds-dev-story). Threaded the attacker-support (tome) deterministic bonus into the attack-preview `expected_damage` (query + `from_query` + commit-flow arming) so shown N == resolved N, keeping `AttackCommand`/`expected_base_damage`/every event-log fingerprint byte-identical. Added the preview-equals-resolved regression test per starting kit + a support-bearing preview-VM case. Suite 206 PASS, 0 new stderr negatives. Status → review.
- 2026-08-06 — Story 15.2 context created (gds-create-story). Read-model correctness fix: thread the attacker-support (tome) deterministic bonus into the attack-preview `expected_damage` so shown N == resolved N, keeping `AttackCommand`/`expected_base_damage`/every fingerprint byte-identical; regression test locks preview==resolved per starting kit. Status → ready-for-dev.

### Review Findings

**Round 1 of 3** — `gds-code-review`, 2026-08-06 (Claude Opus 4.8). **Verdict: Approve.** Critical 0 / High 0 / Med 0 / Low 3.

Scope: current branch diff vs base `6e121e9`, production + test code only (`_bmad`/`_bmad-output`/cache/non-code excluded). Reviewed: `attack_preview_query.gd`, `tactical_attack_preview.gd`, `tactical_attack_commit_flow.gd`, `test_attack_preview_matches_resolution.gd` (+`.gd.uid`), `test_tactical_preview_view_models.gd`, `test_tactical_attack_commit_flow.gd`.

Verification: full headless suite re-run independently → **206 PASS / 0 FAIL**; false-PASS guard `SCRIPT ERROR|Parse Error|^FAIL` = 0 hits; broad ERROR scan = exactly the 6 documented stderr negatives (int64-overflow ×2, `invalid_node_type` ×1, malformed-JSON ×3), zero new, none referencing a 15.2 file; `git diff --check` clean; the new `.gd.uid` sidecar is git-tracked.

Correctness (all ACs met):
- **AC1 ✓** — `expected_damage = max(1, expected_base_damage + attacker_support_bonus)` (`attack_preview_query.gd:85-90`) equals the resolved `final_damage` for a hero attack; the adjacency-penalty warning line is preserved (labelled condition intact). The panel reads `expected_damage` first (`tactical_attack_preview_panel.gd:53,60`), so the on-screen number is corrected with no panel change.
- **AC2 ✓** — `AttackPreviewQuery._attacker_support_bonus` (`attack_preview_query.gd:181-186`) is byte-identical logic to `AttackCommand._support_bonus_damage` (`attack_command.gd:343-348`); `AttackCommand` is untouched and passes NO support to its own preview (`attack_command.gd:73`), so the `expected_base_damage` it reads plus all events/RNG are byte-identical. The new regression test locks preview==resolved==hand-computed for all five starting-kit cases (staff+tome 5 ranged / 3 adjacent, sword+shield 4, bow+none 3 ranged / 2 adjacent) and asserts preview purity (board + all 7 RNG streams unchanged).
- **AC3 ✓** — no gate key added (16-key board-VM, 11-key `PANEL_KEYS`, 23-key `RunSnapshot`/`SCHEMA_VERSION 1`, 7 RNG streams), no new event/enum/autoload/RNG-draw-site, `project.godot` untouched (not in diff); every seed-regression/finale/route/generation fingerprint test green.

- [Review][Decision] (Low, informational — no action required) `AttackCommand.validate` returns `preview.metadata`, so the command's result metadata now carries the new passthrough `expected_damage` key (equal to `expected_base_damage`, since the command passes no support). Inert: no test pins the command-metadata key set, it is excluded from every event payload's explicit key list (`_attack_event_payload`/`_damage_event_payload`), and it moves no fingerprint (suite green). Consistent with the command's pre-existing full-metadata passthrough (`attack_command.gd:76,92,161`).
- [Review][Decision] (Low) Armed-preview `warnings`/`explanation` text intentionally reports the weapon BASE, not the tome-boosted total (`attack_preview_query.gd:91,111` + code comment). This is correct for the adjacency warning (it describes the weapon's own adjacency reduction), and the `explanation` string is not rendered by the armed panel (`PANEL_KEYS` excludes it) and matches the committed ENTITY_ATTACKED event (recomputed support-blind). But a pyromancer at adjacent range sees "Expected damage: 3" beside "Adjacent target reduces staff damage from 4 to 2" — the "2" (base) vs shown "3" (base+tome) is a mild clarity nuance. Human call: fold a clarity check into the OSG-1 on-device pass / the 15.11 copy pass; no code change this story.
- [Review][Defer] (Low, forward-guard) `AttackPreviewQuery.preview_target_entity` (`attack_preview_query.gd:115-142`) was left support-blind — it forwards to `preview_target_cell` with no `attacker_support`, and the AC2 regression test guards only `preview_target_cell`/`from_query`. Zero live impact (no production caller today — only `test_attack_preview_query.gd`), but a future armed-preview surface routed through it would silently re-introduce the F4 desync uncaught. Future hardening: thread `attacker_support` through `preview_target_entity`, or assert no armed path uses it. Logged to `deferred-work.md`.
