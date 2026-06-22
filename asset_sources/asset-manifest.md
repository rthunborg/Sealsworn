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
| char.warrior | Warrior | portrait + board silhouette | asset_sources/characters/ | godot/assets/characters/ | planned | ☐ |
| char.pyromancer | Pyromancer | portrait + board silhouette | asset_sources/characters/ | godot/assets/characters/ | planned | ☐ |
| char.ranger | Ranger | portrait + board silhouette | asset_sources/characters/ | godot/assets/characters/ | planned | ☐ |

## Characters — locked classes (Scenario) — Epic 5
| ID | Asset | Source dir | Runtime path | Status | Approved |
|---|---|---|---|---|---|
| char.necromancer_locked | Necromancer (sealed) | asset_sources/characters/ | godot/assets/characters/ | planned | ☐ |
| char.shadeblade_locked | Shadeblade (sealed) | asset_sources/characters/ | godot/assets/characters/ | planned | ☐ |

## Enemies (Scenario) — Epic 1 / 3
| ID | Asset | Source dir | Runtime path | Status | Approved |
|---|---|---|---|---|---|
| enemy.iron_cultist | Iron Cultist | asset_sources/enemies/ | godot/assets/enemies/ | planned | ☐ |
| enemy.gate_brute | Gate Brute | asset_sources/enemies/ | godot/assets/enemies/ | planned | ☐ |
| enemy.ash_seer | Ash Seer | asset_sources/enemies/ | godot/assets/enemies/ | planned | ☐ |

## Boss (Scenario) — Epic 9
| ID | Asset | Source dir | Runtime path | Status | Approved |
|---|---|---|---|---|---|
| boss.larval_avatar | Larval Avatar | asset_sources/boss/ | godot/assets/enemies/ | planned | ☐ |

## Affinity treatments (Scenario) — Epic 7
| ID | Asset | Source dir | Runtime path | Status | Approved |
|---|---|---|---|---|---|
| affinity.scorched | Scorched overlay | asset_sources/affinities/ | godot/assets/tiles/affinities/ | planned | ☐ |
| affinity.flooded | Flooded/Conductive overlay | asset_sources/affinities/ | godot/assets/tiles/affinities/ | planned | ☐ |
| affinity.cursed | Cursed overlay | asset_sources/affinities/ | godot/assets/tiles/affinities/ | planned | ☐ |
| affinity.darkness | Darkness overlay | asset_sources/affinities/ | godot/assets/tiles/affinities/ | planned | ☐ |

## Tiles & props (Scenario) — Epic 3
| ID | Asset | Source dir | Runtime path | Status | Approved |
|---|---|---|---|---|---|
| tile.floor | Floor | asset_sources/tiles/ | godot/assets/tiles/ | planned | ☐ |
| tile.wall | Wall | asset_sources/tiles/ | godot/assets/tiles/ | planned | ☐ |
| tile.blocker | Rubble / blocker | asset_sources/tiles/ | godot/assets/tiles/ | planned | ☐ |
| tile.entrance | Entrance | asset_sources/tiles/ | godot/assets/tiles/ | planned | ☐ |
| tile.exit | Exit / stair-down | asset_sources/tiles/ | godot/assets/tiles/ | planned | ☐ |
| tile.door | Door (open state) | asset_sources/tiles/ | godot/assets/tiles/ | planned | ☐ |
| tile.door_sealed | Door (sealed, forward-commit) | asset_sources/tiles/ | godot/assets/tiles/ | planned | ☐ |
| tile.hazard | Hazard | asset_sources/tiles/ | godot/assets/tiles/ | planned | ☐ |
| tile.reward_object | Reward / object | asset_sources/tiles/ | godot/assets/tiles/ | planned | ☐ |

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
| ID | Cue | Source dir | Runtime path | Status | Approved |
|---|---|---|---|---|---|
| sfx.move | Movement | asset_sources/audio/sfx/ | godot/assets/audio/sfx/ | planned | ☐ |
| sfx.weapon_hit | Weapon hit | asset_sources/audio/sfx/ | godot/assets/audio/sfx/ | planned | ☐ |
| sfx.enemy_action | Enemy action | asset_sources/audio/sfx/ | godot/assets/audio/sfx/ | planned | ☐ |
| sfx.hazard | Hazard | asset_sources/audio/sfx/ | godot/assets/audio/sfx/ | planned | ☐ |
| sfx.preview | Preview cue | asset_sources/audio/sfx/ | godot/assets/audio/sfx/ | planned | ☐ |
| sfx.confirm | Confirm cue (distinct from preview) | asset_sources/audio/sfx/ | godot/assets/audio/sfx/ | planned | ☐ |
| sfx.passive_pickup | Passive pickup | asset_sources/audio/sfx/ | godot/assets/audio/sfx/ | planned | ☐ |
| sfx.consume | Consume | asset_sources/audio/sfx/ | godot/assets/audio/sfx/ | planned | ☐ |
| sfx.destroy | Destroy | asset_sources/audio/sfx/ | godot/assets/audio/sfx/ | planned | ☐ |
| sfx.curse | Curse / corruption | asset_sources/audio/sfx/ | godot/assets/audio/sfx/ | planned | ☐ |
| sfx.door_seal | Door sealing | asset_sources/audio/sfx/ | godot/assets/audio/sfx/ | planned | ☐ |
| sfx.death | Death | asset_sources/audio/sfx/ | godot/assets/audio/sfx/ | planned | ☐ |
| sfx.reward_reveal | Reward reveal | asset_sources/audio/sfx/ | godot/assets/audio/sfx/ | planned | ☐ |
| sfx.boss_victory | Boss victory | asset_sources/audio/sfx/ | godot/assets/audio/sfx/ | planned | ☐ |

## Ambient loops (tool TBD — Suno / Stable Audio suggested)
| ID | Loop | Source dir | Runtime path | Status | Approved |
|---|---|---|---|---|---|
| amb.labyrinth | Labyrinth exploration | asset_sources/audio/ambient/ | godot/assets/audio/ambient/ | planned | ☐ |
| amb.outpost | Outpost / menu | asset_sources/audio/ambient/ | godot/assets/audio/ambient/ | planned | ☐ |
| amb.scorched | Scorched | asset_sources/audio/ambient/ | godot/assets/audio/ambient/ | planned | ☐ |
| amb.flooded | Flooded/Conductive | asset_sources/audio/ambient/ | godot/assets/audio/ambient/ | planned | ☐ |
| amb.cursed | Cursed | asset_sources/audio/ambient/ | godot/assets/audio/ambient/ | planned | ☐ |
| amb.darkness | Darkness | asset_sources/audio/ambient/ | godot/assets/audio/ambient/ | planned | ☐ |
| amb.boss | Boss / finale | asset_sources/audio/ambient/ | godot/assets/audio/ambient/ | planned | ☐ |
