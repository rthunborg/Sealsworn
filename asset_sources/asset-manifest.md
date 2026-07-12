# Sealsworn — MVP Asset Manifest (v0)

Complete MVP asset inventory and provenance tracker. Satisfies the [Story 10.7](../_bmad-output/planning-artifacts/epics.md) readiness gate and NFR17/NFR18.
Direction: [`style-bible.md`](style-bible.md) · Prompts: [`prompt-pack.md`](prompt-pack.md).

**Status values:** `planned` → `placeholder` → `generated` → `approved` · or `descoped` (approved MVP limitation) · or `blocking` (blocks readiness).
**Per-asset provenance to capture at generation** (append to the row or a sibling `provenance-log.md`): tool, prompt-pack id, seed, date, source ref, license/provenance, approval status. Editable source under `asset_sources/...`, runtime export under `godot/assets/...`.
**Approval = passes the 3-point readability gate** (grayscale · phone-size · silhouette).

Totals (v0): **visual ~92** (5 classes ×2 views, 3 enemies, 1 boss, 4 affinities, 9 tiles, 11 item icons, 30 passive glyphs, 4 currency, 9 UI frames, ~9 overlays/banners) · **SFX 14** · **ambient 7**.

---

## Characters — playable classes (Scenario) — Epic 5
| ID | Asset | Views | Source dir | Runtime path | Status | Approved |
|---|---|---|---|---|---|---|
| char.warrior | Warrior | portrait + board silhouette | asset_sources/characters/char.warrior.png | godot/assets/characters/char.warrior.png | approved | ☑ |
| char.pyromancer | Pyromancer | portrait + board silhouette | asset_sources/characters/char.pyromancer.png | godot/assets/characters/char.pyromancer.png | approved | ☑ |
| char.ranger | Ranger | portrait + board silhouette | asset_sources/characters/char.ranger.png | godot/assets/characters/char.ranger.png | approved | ☑ |

## Characters — locked classes (Scenario) — Epic 5
| ID | Asset | Source dir | Runtime path | Status | Approved |
|---|---|---|---|---|---|
| char.necromancer_locked | Necromancer (sealed) | asset_sources/characters/char.necromancer_locked.png | godot/assets/characters/char.necromancer_locked.png | approved | ☑ |
| char.shadeblade_locked | Shadeblade (sealed) | asset_sources/characters/char.shadeblade_locked.png | godot/assets/characters/char.shadeblade_locked.png | approved | ☑ |

## Enemies (Scenario) — Epic 1 / 3
| ID | Asset | Source dir | Runtime path | Status | Approved |
|---|---|---|---|---|---|
| enemy.iron_cultist | Iron Cultist | asset_sources/enemies/enemy.iron_cultist.png | godot/assets/enemies/enemy.iron_cultist.png | approved | ☑ |
| enemy.gate_brute | Gate Brute | asset_sources/enemies/enemy.gate_brute.png | godot/assets/enemies/enemy.gate_brute.png | approved | ☑ |
| enemy.ash_seer | Ash Seer | asset_sources/enemies/enemy.ash_seer.png | godot/assets/enemies/enemy.ash_seer.png | approved | ☑ |

## Boss (Scenario) — Epic 9
| ID | Asset | Source dir | Runtime path | Status | Approved |
|---|---|---|---|---|---|
| boss.larval_avatar | Larval Avatar | asset_sources/boss/boss.larval_avatar.png | godot/assets/enemies/boss.larval_avatar.png | approved | ☑ |

## Affinity treatments (Scenario) — Epic 7
| ID | Asset | Source dir | Runtime path | Status | Approved |
|---|---|---|---|---|---|
| affinity.scorched | Scorched overlay | asset_sources/affinities/affinity.scorched.png | godot/assets/tiles/affinities/affinity.scorched.png | approved | ☑ |
| affinity.flooded | Flooded/Conductive overlay | asset_sources/affinities/affinity.flooded.png | godot/assets/tiles/affinities/affinity.flooded.png | approved | ☑ |
| affinity.cursed | Cursed overlay | asset_sources/affinities/affinity.cursed.png | godot/assets/tiles/affinities/affinity.cursed.png | approved | ☑ |
| affinity.darkness | Darkness overlay | asset_sources/affinities/affinity.darkness.png | godot/assets/tiles/affinities/affinity.darkness.png | approved | ☑ |

## Tiles & props (Scenario) — Epic 3
| ID | Asset | Source dir | Runtime path | Status | Approved |
|---|---|---|---|---|---|
| tile.floor | Floor | asset_sources/tiles/tile.floor.png | godot/assets/tiles/tile.floor.png | approved | ☑ |
| tile.wall | Wall | asset_sources/tiles/tile.wall.png | godot/assets/tiles/tile.wall.png | approved | ☑ |
| tile.blocker | Rubble / blocker | asset_sources/tiles/tile.blocker.png | godot/assets/tiles/tile.blocker.png | approved | ☑ |
| tile.entrance | Entrance | asset_sources/tiles/tile.entrance.png | godot/assets/tiles/tile.entrance.png | approved | ☑ |
| tile.exit | Exit / stair-down | asset_sources/tiles/tile.exit.png | godot/assets/tiles/tile.exit.png | approved | ☑ |
| tile.door | Door (open state) | asset_sources/tiles/tile.door.png | godot/assets/tiles/tile.door.png · prop: godot/assets/tiles/props/door.png | approved | ☑ |
| tile.door_sealed | Door (sealed, forward-commit) | asset_sources/tiles/tile.door_sealed.png | godot/assets/tiles/tile.door_sealed.png · prop: godot/assets/tiles/props/door_sealed.png | approved | ☑ |
| tile.hazard | Hazard | asset_sources/tiles/tile.hazard.png | godot/assets/tiles/tile.hazard.png | approved | ☑ |
| tile.reward_object | Reward / object | asset_sources/tiles/tile.reward_object.png | godot/assets/tiles/tile.reward_object.png · prop: godot/assets/tiles/props/reward_object.png | approved | ☑ |

## Item icons — weapons (Recraft) — Epic 1 / 6
| ID | Asset | Source dir | Runtime path | Status | Approved |
|---|---|---|---|---|---|
| icon.weapon.sword | Sword | asset_sources/icons/weapons/ | godot/assets/icons/weapons/ | generated | ☐ |
| icon.weapon.dagger | Dagger (curved/kukri — pick #1) | asset_sources/icons/weapons/ | godot/assets/icons/weapons/ | generated | ☐ |
| icon.weapon.spear | Spear | asset_sources/icons/weapons/ | godot/assets/icons/weapons/ | generated | ☐ |
| icon.weapon.axe | Axe | asset_sources/icons/weapons/ | godot/assets/icons/weapons/ | generated | ☐ |
| icon.weapon.mace | Mace | asset_sources/icons/weapons/ | godot/assets/icons/weapons/ | generated | ☐ |
| icon.weapon.bow | Bow | asset_sources/icons/weapons/ | godot/assets/icons/weapons/ | generated | ☐ |
| icon.weapon.crossbow | Crossbow | asset_sources/icons/weapons/ | godot/assets/icons/weapons/ | generated | ☐ |
| icon.weapon.staff | Staff | asset_sources/icons/weapons/ | godot/assets/icons/weapons/ | generated | ☐ |
| icon.weapon.wand | Wand | asset_sources/icons/weapons/ | godot/assets/icons/weapons/ | generated | ☐ |

> **Provenance (all Recraft icons):** tool = Recraft, model = V3 Vector, style = custom `Sealsworn Icons` (built from the steel-sword reference + style-level treatment prompt). Generated 2026-06-21. Prompts/negatives recorded in [`prompt-pack.md`](prompt-pack.md) §B. License: Recraft Pro (commercial). **Approval pending:** export SVG → `asset_sources/icons/weapons/` (by ID), confirm 3-point gate, then check the Approved box. Extra/spare weapon variants kept under `asset_sources/icons/_future/` (non-MVP, NFR18).

## Item icons — support (Recraft) — Epic 6
| ID | Asset | Source dir | Runtime path | Status | Approved |
|---|---|---|---|---|---|
| icon.support.tome | Tome | asset_sources/icons/support/ | godot/assets/icons/support/ | generated | ☐ |
| icon.support.shield | Shield | asset_sources/icons/support/ | godot/assets/icons/support/ | generated | ☐ |

## Passive glyphs (Recraft) — Epic 6 — `icon.passive.001`–`030`
| ID range | Asset | Source dir | Runtime path | Status | Approved |
|---|---|---|---|---|---|
| icon.passive.001–028 | 28 placeholder glyphs (4 archetypes), each mapped to `icon.passive.NNN.svg`. V4.1 Pro Vector; see prompt-pack §B. | asset_sources/icons/passives/ | godot/assets/icons/passives/ | generated | ☐ |

> **Spares:** alternate versions + reusable distinct icons documented in [`icons/_future/UNUSED-ASSETS.md`](icons/_future/UNUSED-ASSETS.md) (NFR18). **Verify on import:** 002 skull, 007 fang, 012 chain, and especially **023 cracked-rune** were picked from multiple takes — swap from `_future/alternates/` if any look off.

## Currency icons (Recraft) — Epic 8
| ID | Asset | Source dir | Runtime path | Status | Approved |
|---|---|---|---|---|---|
| icon.currency.gold | Gold | asset_sources/icons/currency/ | godot/assets/icons/currency/ | generated | ☐ |
| icon.currency.oath_shard | Oath Shard | asset_sources/icons/currency/ | godot/assets/icons/currency/ | generated | ☐ |
| icon.currency.echo | Echo | asset_sources/icons/currency/ | godot/assets/icons/currency/ | generated | ☐ |
| icon.currency.seal_fragment | Seal Fragment | asset_sources/icons/currency/ | godot/assets/icons/currency/ | generated | ☐ |

## UI frames (Recraft + Godot 9-slice) — Epic 2 / 5 / 8
| ID | Asset | Source dir | Runtime path | Status | Approved |
|---|---|---|---|---|---|
| ui.hero_select | Hero select | asset_sources/ui/ | godot/assets/ui/ | planned | ☐ |
| ui.tactical_hud | Tactical HUD | asset_sources/ui/ | godot/assets/ui/ | planned | ☐ |
| ui.preview | Tile/attack preview | asset_sources/ui/ | godot/assets/ui/ | planned | ☐ |
| ui.passive_modal | Passive modal | asset_sources/ui/ | godot/assets/ui/ | planned | ☐ |
| ui.run_map | Run map | asset_sources/ui/ | godot/assets/ui/ | planned | ☐ |
| ui.outpost | Outpost / meta menu | asset_sources/ui/ | godot/assets/ui/ | planned | ☐ |
| ui.run_summary | Run summary | asset_sources/ui/ | godot/assets/ui/ | planned | ☐ |
| ui.settings | Settings | asset_sources/ui/ | godot/assets/ui/ | planned | ☐ |
| ui.save_resume | Save / resume | asset_sources/ui/ | godot/assets/ui/ | planned | ☐ |

> **Frame kit generated:** `icons/ui/{button_plate,panel_frame,modal_frame}.svg` (Recraft). The 9 `ui.*` screens are assembled in Godot (9-slice / StyleBox) from this kit, so those rows stay `planned` until built in-engine.

## Overlays & banners (Recraft) — Epic 2 / 1
| ID | Asset | Source dir | Runtime path | Status | Approved |
|---|---|---|---|---|---|
| overlay.move_range | Movement-range marker | asset_sources/overlays/ | godot/assets/overlays/ | planned | ☐ |
| overlay.attack_range | Attack-range marker | asset_sources/overlays/ | godot/assets/overlays/ | planned | ☐ |
| overlay.blocked_line | Blocked-line marker | asset_sources/overlays/ | godot/assets/overlays/ | planned | ☐ |
| overlay.fog_hidden | Fog: hidden | asset_sources/overlays/ | godot/assets/overlays/ | planned | ☐ |
| overlay.fog_memory | Fog: memory | asset_sources/overlays/ | godot/assets/overlays/ | planned | ☐ |
| overlay.seer_mark | Ash Seer telegraph mark | asset_sources/overlays/ | godot/assets/overlays/ | generated | ☐ |
| banner.victory | Victory banner | asset_sources/overlays/ | godot/assets/overlays/ | generated | ☐ |
| banner.defeat | Defeat banner | asset_sources/overlays/ | godot/assets/overlays/ | generated | ☐ |

> `overlay.move_range`, `attack_range`, `blocked_line`, `fog_hidden`, `fog_memory` are **engine-drawn** flat Godot fills/shaders (NFR9), not Recraft art — they stay `planned` until built in-engine. `seer_mark` + the win/lose banners are the only generated overlay art.

## SFX (tool TBD — ElevenLabs suggested) — cue map per Story 10.7
> **Story 10.7 readiness-gate disposition (AC4):** DE-SCOPED for the v0 candidate as an approved MVP limitation — **NON-GATING** (nothing is audio-only per the 10.5 audio-off audit §7; only the two preview/commit cues even declare an optional audio id, each keeping a non-color visual channel). Owner: a post-MVP audio-production pass. Target: author + import + `approve` the 14 SFX. See `_bmad-output/planning-artifacts/asset-audio-placeholder-ux-readiness-gate.md` §4 (the cue map) + §6.4 (the disposition).

| ID | Cue | Source dir | Runtime path | Status | Approved |
|---|---|---|---|---|---|
| sfx.move | Movement | asset_sources/audio/sfx/ | godot/assets/audio/sfx/ | descoped | ☐ |
| sfx.weapon_hit | Weapon hit | asset_sources/audio/sfx/ | godot/assets/audio/sfx/ | descoped | ☐ |
| sfx.enemy_action | Enemy action | asset_sources/audio/sfx/ | godot/assets/audio/sfx/ | descoped | ☐ |
| sfx.hazard | Hazard | asset_sources/audio/sfx/ | godot/assets/audio/sfx/ | descoped | ☐ |
| sfx.preview | Preview cue | asset_sources/audio/sfx/ | godot/assets/audio/sfx/ | descoped | ☐ |
| sfx.confirm | Confirm cue (distinct from preview) | asset_sources/audio/sfx/ | godot/assets/audio/sfx/ | descoped | ☐ |
| sfx.passive_pickup | Passive pickup | asset_sources/audio/sfx/ | godot/assets/audio/sfx/ | descoped | ☐ |
| sfx.consume | Consume | asset_sources/audio/sfx/ | godot/assets/audio/sfx/ | descoped | ☐ |
| sfx.destroy | Destroy | asset_sources/audio/sfx/ | godot/assets/audio/sfx/ | descoped | ☐ |
| sfx.curse | Curse / corruption | asset_sources/audio/sfx/ | godot/assets/audio/sfx/ | descoped | ☐ |
| sfx.door_seal | Door sealing | asset_sources/audio/sfx/ | godot/assets/audio/sfx/ | descoped | ☐ |
| sfx.death | Death | asset_sources/audio/sfx/ | godot/assets/audio/sfx/ | descoped | ☐ |
| sfx.reward_reveal | Reward reveal | asset_sources/audio/sfx/ | godot/assets/audio/sfx/ | descoped | ☐ |
| sfx.boss_victory | Boss victory | asset_sources/audio/sfx/ | godot/assets/audio/sfx/ | descoped | ☐ |

## Ambient loops (tool TBD — Suno / Stable Audio suggested)
> **Story 10.7 readiness-gate disposition (AC4):** DE-SCOPED for the v0 candidate as an approved MVP limitation — **NON-GATING** (ambient is atmosphere, never a required-information channel; the v0 candidate ships silent). Owner: a post-MVP audio-production pass. Target: author + import + `approve` the 7 ambient loops. See `asset-audio-placeholder-ux-readiness-gate.md` §6.4.

| ID | Loop | Source dir | Runtime path | Status | Approved |
|---|---|---|---|---|---|
| amb.labyrinth | Labyrinth exploration | asset_sources/audio/ambient/ | godot/assets/audio/ambient/ | descoped | ☐ |
| amb.outpost | Outpost / menu | asset_sources/audio/ambient/ | godot/assets/audio/ambient/ | descoped | ☐ |
| amb.scorched | Scorched | asset_sources/audio/ambient/ | godot/assets/audio/ambient/ | descoped | ☐ |
| amb.flooded | Flooded/Conductive | asset_sources/audio/ambient/ | godot/assets/audio/ambient/ | descoped | ☐ |
| amb.cursed | Cursed | asset_sources/audio/ambient/ | godot/assets/audio/ambient/ | descoped | ☐ |
| amb.darkness | Darkness | asset_sources/audio/ambient/ | godot/assets/audio/ambient/ | descoped | ☐ |
| amb.boss | Boss / finale | asset_sources/audio/ambient/ | godot/assets/audio/ambient/ | descoped | ☐ |

---

## Story 10.7 readiness-gate dispositions (AC4)

The Epic-10 Asset/Audio/Placeholder/UX readiness gate (`_bmad-output/planning-artifacts/asset-audio-placeholder-ux-readiness-gate.md`)
dispositions every open placeholder for the offline-first v0 candidate. Summary (full rows in the gate report §6):

| Item | Disposition | Owner | Target |
|---|---|---|---|
| Audio track (14 SFX + 7 ambient, 0 files) | **de-scoped** (approved MVP limitation, non-gating — nothing is audio-only) | post-MVP audio-production pass | author + import + `approve` the SFX + ambient |
| Flooded conductive-interaction art/VFX (`affinity_conductive_danger_placeholder_vfx`; a code-level cue in `affinity_effect_resolver.gd`, no manifest row) | **de-scoped** (approved MVP limitation; the placeholder cue already reads non-color) | a later affinity-effects / conductive-interaction VFX story | replace the `_placeholder` cue/visual ids with FINAL ids + author the conductive art/VFX when the live mechanic ships |
| Generated-but-unapproved icons (weapons ×9, support ×2, passives ×28, currency ×4) | tracked **generated** ☐ (approval pending — NOT descoped; present + intended for v0) | an asset-approval pass | confirm the 3-point gate on import + check the Approved box (`generated → approved`) |
| Planned in-engine UI frames (`ui.*` ×9) + engine-drawn overlays (`overlay.move_range/attack_range/blocked_line/fog_hidden/fog_memory`) | tracked **planned** (assembled/drawn in-engine when scenes build) | the scene stories (11.3 HUD / 11.4 treatment / outpost-summary scene owners) | assemble the frames in-engine from the frame kit; draw the overlays as flat Godot fills/shaders |

None is classified `blocking` — every non-color cue channel is present and the live loop is complete + winnable
(the 10.6 gate §3). The visual roster (classes / enemies / boss / affinities / tiles / props) is `approved` and
passed the 3-point readability gate.

---

## Scenario board art — gate + runtime export (2026-06-22)

All 22 Scenario assets **passed the 3-point readability gate** (grayscale / phone-size / silhouette) — evidence regenerable via `python asset_sources/_tools/process_board_art.py`. Engine = Gemini 3.1 Flash (no custom model); full provenance + CU ledger in [`provenance-log.md`](provenance-log.md).

**Runtime mirror exported** to `godot/assets/` (downscaled from 1K masters, never upscaled): characters/enemies 256×384, boss 512², tiles + affinities 256². Transparent **prop** versions (placeable on any floor/affinity cell) for `reward_object`, `door`, `door_sealed` live under `godot/assets/tiles/props/` (blocker prop skipped — rubble fills the tile so there was no background to remove; use its full tile).

**Deferred to board-renderer time (not done — need the engine's compositing model):**
- Seamless tiling: floor/wall read fine as per-cell textures but are not edge-seamless and repeat visibly — solve with variants or edge-blending alongside the renderer.
- Affinity **overlays**: shipped as full-tile floor variants; true transparent overlays are better done in-engine (recolor/shader over the base floor using each tile's non-color cue) since the cue is fused into the stone.
- `entrance` vs `exit` look alike at tiny grayscale — consider an up/down arrow cue.
