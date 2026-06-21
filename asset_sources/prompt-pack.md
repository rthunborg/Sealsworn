# Sealsworn — Prompt Pack (v0)

Copy-paste prompt templates for **Scenario.gg** (board/world art) and **Recraft** (UI/symbolic art).
Constraints derive from [`style-bible.md`](style-bible.md). IDs match [`asset-manifest.md`](asset-manifest.md).

How to use: paste the **STYLE PREFIX** for the tool, append the per-asset line, and apply the shared **NEGATIVE**. Lock seeds once a look is approved so you can reproduce/iterate.

---

## A. SCENARIO.GG — board / world art

**STYLE PREFIX (paste before every prompt):**
> dark medieval fantasy, stylized painterly 2.5D, grim cosmic-horror undercurrent, square orthographic grid game, high top-down camera ~30°, single front-facing character billboard, strong readable silhouette, rim-lit to separate from dark background, key light upper-left, low-key moody lighting, cold desaturated stone palette with warm candlelight accents, clean edges, mobile-readable, centered subject, plain dark neutral background for clean cutout, consistent scale, high detail

**NEGATIVE (all Scenario prompts):**
> isometric, diamond grid, multiple characters, text, watermark, UI, busy background, full environment scene, photorealistic, bright saturated colors, blurry, low-contrast silhouette, cropped limbs, extra limbs, sci-fi, technology

### Playable classes — portrait + board silhouette
- `char.warrior` — heavily armored melee warrior, steel plate, large weapon, broad heavy silhouette, grim resolve
- `char.pyromancer` — robed fire-caster, embers and ash, warm glow at hands, lean mystic silhouette
- `char.ranger` — hooded archer, leather and cloak, bow, agile lean silhouette

### Locked classes — sealed/teaser (desaturated, grayed)
- `char.necromancer_locked` — robed death-caster silhouette, **sealed/desaturated grey, faint eldritch teal seal**, "locked" feel
- `char.shadeblade_locked` — agile shadow-assassin silhouette, **sealed/desaturated grey, faint eldritch teal seal**

### Enemies — must be instantly distinguishable
- `enemy.iron_cultist` — lean robed cultist, iron mask, advancing posture, physical-threat read
- `enemy.gate_brute` — massive hulking brute, body-blocking bulk, heavy stance, immovable read
- `enemy.ash_seer` — gaunt caster, raised hand mid-telegraph, **eldritch teal glow** marking power

### Boss
- `boss.larval_avatar` — cosmic-horror larval entity, impossible geometry, **heavy eldritch teal**, containment-failure dread, marquee centerpiece, larger scale

### Tiles & props (256×256, seamless where tiling)
- `tile.floor` — dark fantasy dungeon stone floor tile, subtle wear, top-down
- `tile.wall` — stone Labyrinth wall, slight height extrusion, top-down
- `tile.blocker` — rubble / broken pillar blocker prop
- `tile.entrance` — level entrance marker tile, subtle inviting cue
- `tile.exit` — level exit / stair-down tile, clear directional read
- `tile.door` — heavy iron-bound door, openable state
- `tile.door_sealed` — same door **sealed shut, faint eldritch teal seal glow** (forward-commitment)
- `tile.hazard` — generic hazard tile, danger read, warm warning glow
- `tile.reward_object` — reward chest / object on tile, inviting highlight

### Affinity overlays (recolor/effect layers over base tiles)
- `affinity.scorched` — scorched ember overlay, cracked glowing char, orange
- `affinity.flooded` — flooded conductive overlay, wet sheen + spark arcs, electric blue
- `affinity.cursed` — cursed corruption overlay, creeping rot veins, magenta-violet
- `affinity.darkness` — darkness overlay, near-black vignette, reduced-visibility fade

---

## B. RECRAFT — UI / symbolic art

**STYLE PREFIX (paste before every prompt):**
> dark fantasy game UI icon, single centered emblem, bold readable silhouette, thick clean outline, dark slate plate background, warm metallic highlight, subtle grim texture, flat with slight depth, high contrast, distinct by shape (colorblind-safe), even padding, vector

**NEGATIVE (all Recraft prompts):**
> photorealistic, busy, paragraph text, multiple objects, thin faint lines, low contrast, gradient overload, drop-shadow clutter, sci-fi

### Weapon icons (9)
- `icon.weapon.sword` — straight knightly sword
- `icon.weapon.dagger` — short curved dagger
- `icon.weapon.spear` — long thrusting spear
- `icon.weapon.axe` — heavy battle axe
- `icon.weapon.mace` — spiked flanged mace
- `icon.weapon.bow` — recurve war bow
- `icon.weapon.crossbow` — mechanical crossbow
- `icon.weapon.staff` — arcane wooden staff with focus stone
- `icon.weapon.wand` — short relic wand, faint glow

### Support items (2)
- `icon.support.tome` — closed arcane tome, clasp
- `icon.support.shield` — heater shield, iron rim

### Currency (4)
- `icon.currency.gold` — gold coin stack
- `icon.currency.oath_shard` — fractured oath shard, faint eldritch teal
- `icon.currency.echo` — wisp/echo mote
- `icon.currency.seal_fragment` — broken seal fragment, relic-magic

### Passive glyphs — 20–30 (templates; exact designs await Epic 6)
Use one base template; vary the central symbol. Four archetypes to cover the GDD's pillars (including 3–5 "weird rule-benders"):
- **Offense** (`icon.passive.NNN`) — jagged/spiked/bladed central symbol
- **Defense** — shield / aegis / ward central symbol
- **Utility** — eye / rune / hourglass / key central symbol
- **Rule-bender (weird)** — broken, inverted, or paradoxical symbol, faint eldritch teal accent
> Generate ~30 distinct central symbols on the shared plate so they read as one set. Map specific passives to glyphs when Epic 6 designs them.

### UI frames / overlays
- `ui.*` frames — ornate dark-stone panel frame, iron corners, candle-warm trim. **Recommend:** generate decorative corner/border pieces and assemble as 9-slice in Godot rather than fixed-size full panels.
- `overlay.move_range` / `overlay.attack_range` / `overlay.blocked_line` — flat tile-highlight markers, distinct by shape+pattern (not color alone)
- `overlay.fog_hidden` / `overlay.fog_memory` — fog states: hidden (opaque) vs memory (desaturated/dimmed)
- `overlay.seer_mark` — telegraph marker, **eldritch teal**, clearly "danger here next turn"
- `banner.victory` / `banner.defeat` — outcome banner treatments

---

## C. Audio (tool TBD — ElevenLabs SFX / Suno or Stable Audio suggested)

Not Scenario/Recraft, but tracked for the Story 10.7 cue map. Brief generation cues:
- **SFX:** crisp tactical feedback first. Preview = soft/neutral; confirm = decisive — must be audibly distinct. Door-seal = heavy ominous. Cosmic events (Seer mark, soul-return, boss victory) carry the eldritch tone.
- **Ambient loops:** dark medieval foundation + restrained cosmic unease; must never overpower tactical readability. One per: Labyrinth, outpost, Scorched, Flooded, Cursed, Darkness, boss/finale.
