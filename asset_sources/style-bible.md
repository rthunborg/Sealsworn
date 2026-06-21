# Sealsworn — Art & Audio Style Bible (v0)

Status: **v0.** Camera/perspective **confirmed** (Shattered Pixel Dungeon lineage). Encodes the locked-down decisions for MVP asset production.
Source of truth for direction: [`gdd.md` Art & Audio Direction](../_bmad-output/planning-artifacts/gdds/gdd-Game-2026-05-31/gdd.md) and [`gdd.md` Asset Requirements].
Companion files: [`prompt-pack.md`](prompt-pack.md), [`asset-manifest.md`](asset-manifest.md).

---

## 1. Camera & perspective — CONFIRMED

- **Grid:** square, axis-aligned orthographic (NOT isometric diamonds).
- **Floor camera:** high near-top-down, tilted ~30° off straight-down.
- **Characters/enemies/boss:** **front-facing billboard** sprites — upright, drawn from a single front view, standing on their tile. One angle per asset.
- **Walls/props:** slight height extrusion so depth reads; floor stays flat-ish.
- **Lineage reference:** Shattered Pixel Dungeon (primary). Readability references: Wildfrost, Into the Breach.
- **Rejected for MVP:** true isometric (worse mobile readability, worse AI consistency, more authoring effort). 3/4 oblique (A Link to the Past) is the only sanctioned alternative if billboard is rejected.

## 2. Canvas & dimensions — LOCKED v0

| Asset type | Source canvas | Anchor | Notes |
|---|---|---|---|
| Tile / prop | 256×256 | center | seamless edges where tiling |
| Standard character/enemy | 256×384 (1×1.5 tiles) | bottom-center | transparent PNG |
| Large enemy / boss | up to 512×512 | bottom-center | |
| UI icon / passive glyph | SVG (vector) | center | raster fallback 256×256, shown ~48–64px |
| UI frame / panel | as needed | — | prefer 9-slice in Godot; tool supplies corners/borders |

- **Generate at 1024×1024 in-tool, downscale on export.** Never upscale.
- All board assets: **transparent background**, no baked ground shadow (engine adds the contact shadow), consistent scale across a category.

## 3. Lighting — LOCKED v0

- One **global key light: upper-left (~10–11 o'clock, from above).** Never moves.
- Low-key, dark, moody. Add a subtle **rim/back light** so dark subjects separate from dark floors (this is what makes silhouettes read).
- Each actor gets a soft contact shadow (engine-side) so it sits on its tile.
- Hazards / affinities / cosmic elements may emit **local** glow; the global key stays fixed.

## 4. Palette — v0 (tune hexes per-asset)

| Role | Approx hex | Use |
|---|---|---|
| Stone deep | `#1B1E24` | shadows, deep stone |
| Stone mid | `#2C313A` | walls, base material |
| Stone light | `#444B57` | highlights on stone |
| Cold ambient | `#3A4654` | ambient fill, shadow tint |
| Candle amber | `#E8A13C` | torches, mundane light, UI highlight metal |
| Ember orange | `#C75A2B` | fire, danger accent |
| Rust / blood | `#8E2B22` | damage, blood, danger |
| **Eldritch teal (reserved)** | `#5FE0C0` / rim `#7FF3D6` | **cosmic-horror ONLY** |

**Cosmic-horror cue:** eldritch teal-green is reserved exclusively for otherworldly elements — Larval Avatar, Ash Seer's mark, soul-return, containment-failure distortion. Warm = mundane; teal = *wrong*. Keep cosmic horror as undercurrent, not constant spectacle.

### Affinity treatments (each needs a non-color cue — NFR9)

| Affinity | Color | Non-color cue (required) |
|---|---|---|
| Scorched | ember orange `#C75A2B` + char `#14110E` | cracked / glowing-ember texture |
| Flooded/Conductive | electric blue `#2E78C8` + spark `#5BC8F0` | wet sheen + spark arcs |
| Cursed | magenta-violet `#8E3CC0` | corruption veins / creeping rot |
| Darkness | near-black `#0C0E12` | vignette + reduced-visibility fade |

> Keep Cursed (magenta-violet) and Flooded (blue) distinct from the reserved eldritch teal.

## 5. Readability acceptance gate (NFR9 + Story 10.7)

Every asset must pass all three before status → `approved`:
1. **Grayscale test** — meaning survives with color stripped.
2. **Phone-size test** — recognizable at target display px (~48px icons, character at phone board scale).
3. **Silhouette test** — identifiable from shape alone.

Audio parallel: **muting must never remove required info** — every audio cue has a visual/textual equivalent.

## 6. Per-category style notes

- **Playable classes (Warrior/Pyromancer/Ranger):** distinct silhouette per class (heavy/armored, robed/fire, hooded/ranged). Need a portrait (hero-select) AND a board silhouette.
- **Locked classes (Necromancer/Shadeblade):** same silhouette language, rendered as grayed/desaturated "sealed" teaser.
- **Enemies:** Iron Cultist (lean, robed, advancing), Gate Brute (massive, body-blocking bulk), Ash Seer (caster, telegraph posture). Strong distinct shapes — a player must tell them apart instantly.
- **Boss (Larval Avatar):** the marquee cosmic-horror piece; heaviest use of eldritch teal + impossible geometry.
- **Tiles/props:** floor, wall, rubble/blocker, entrance, exit, door + **sealed-door state** (forward-commitment), hazard, reward/object. Readable at a glance; cohesive Labyrinth set.
- **Icons (weapons/support/passives/currency):** bold single emblem, thick outline, dark slate plate with warm metallic highlight, distinct by **shape** first.

## 7. Tool cheat-sheet

**Scenario.gg** — train ONE custom generator (`sealsworn-darkfantasy-v0`) on a curated north-star set; lock a generation template (fixed aspect, neutral background, perspective in prompt); use ControlNet for pose/tile structure; background-remove → upscale on export.

**Recraft** — create ONE custom Style from a few reference glyphs; batch all icons through it; vector output for anything that scales.

## 8. Avoid list (negative direction)

Isometric diamond grid · multiple subjects per asset · baked text/watermarks · busy full-scene backgrounds · photorealism · bright/saturated palettes · low-contrast silhouettes · sci-fi/technology look (Wardenwork is relic-magic, not science fiction) · constant cosmic-horror spectacle.
