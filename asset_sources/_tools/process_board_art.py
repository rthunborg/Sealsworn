"""
Sealsworn board-art runtime export + readability-gate preview generator.

- Downscales asset_sources masters to runtime px under godot/assets/ (never upscales).
- Builds gate previews under _gate_preview/ (untracked): grayscale + phone-size + silhouette
  montages, and 2x2 seam previews for the repeating floor/wall tiles.

Run from repo root: python asset_sources/_tools/process_board_art.py
"""
import os
from PIL import Image, ImageDraw, ImageFont, ImageOps

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SRC = os.path.join(ROOT, "asset_sources")
RUNTIME = os.path.join(ROOT, "godot", "assets")
PREVIEW = os.path.join(ROOT, "_gate_preview")

# (src_relpath, runtime_relpath, target_w, target_h, label, group)
FIGS_WH = (256, 384)
FIGURES = [
    ("characters/char.warrior.png",            "characters/char.warrior.png",            *FIGS_WH, "Warrior",     "hero"),
    ("characters/char.pyromancer.png",         "characters/char.pyromancer.png",         *FIGS_WH, "Pyromancer",  "hero"),
    ("characters/char.ranger.png",             "characters/char.ranger.png",             *FIGS_WH, "Ranger",      "hero"),
    ("characters/char.necromancer_locked.png", "characters/char.necromancer_locked.png", *FIGS_WH, "Necro(lock)", "locked"),
    ("characters/char.shadeblade_locked.png",  "characters/char.shadeblade_locked.png",  *FIGS_WH, "Shade(lock)", "locked"),
    ("enemies/enemy.iron_cultist.png",         "enemies/enemy.iron_cultist.png",         *FIGS_WH, "Iron Cultist","enemy"),
    ("enemies/enemy.gate_brute.png",           "enemies/enemy.gate_brute.png",           *FIGS_WH, "Gate Brute",  "enemy"),
    ("enemies/enemy.ash_seer.png",             "enemies/enemy.ash_seer.png",             *FIGS_WH, "Ash Seer",    "enemy"),
    ("boss/boss.larval_avatar.png",            "enemies/boss.larval_avatar.png",         512, 512, "Larval Boss", "boss"),
]
TILE_WH = (256, 256)
TILES = [
    ("tiles/tile.floor.png",        "tiles/tile.floor.png",        *TILE_WH, "floor",   "tile"),
    ("tiles/tile.wall.png",         "tiles/tile.wall.png",         *TILE_WH, "wall",    "tile"),
    ("tiles/tile.blocker.png",      "tiles/tile.blocker.png",      *TILE_WH, "blocker", "tile"),
    ("tiles/tile.entrance.png",     "tiles/tile.entrance.png",     *TILE_WH, "entrance","tile"),
    ("tiles/tile.exit.png",         "tiles/tile.exit.png",         *TILE_WH, "exit",    "tile"),
    ("tiles/tile.door.png",         "tiles/tile.door.png",         *TILE_WH, "door",    "tile"),
    ("tiles/tile.door_sealed.png",  "tiles/tile.door_sealed.png",  *TILE_WH, "door_seal","tile"),
    ("tiles/tile.hazard.png",       "tiles/tile.hazard.png",       *TILE_WH, "hazard",  "tile"),
    ("tiles/tile.reward_object.png","tiles/tile.reward_object.png",*TILE_WH, "reward",  "tile"),
    ("affinities/affinity.scorched.png","tiles/affinities/affinity.scorched.png",*TILE_WH,"scorched","aff"),
    ("affinities/affinity.flooded.png", "tiles/affinities/affinity.flooded.png", *TILE_WH,"flooded", "aff"),
    ("affinities/affinity.cursed.png",  "tiles/affinities/affinity.cursed.png",  *TILE_WH,"cursed",  "aff"),
    ("affinities/affinity.darkness.png","tiles/affinities/affinity.darkness.png",*TILE_WH,"darkness","aff"),
]

def font(sz):
    for f in ("arial.ttf", "DejaVuSans.ttf", "DejaVuSans-Bold.ttf"):
        try:
            return ImageFont.truetype(f, sz)
        except Exception:
            pass
    return ImageFont.load_default()

def export(items):
    n = 0
    for src, dst, w, h, *_ in items:
        s = Image.open(os.path.join(SRC, src))
        out = os.path.join(RUNTIME, dst)
        os.makedirs(os.path.dirname(out), exist_ok=True)
        if s.mode == "RGBA" or "transparency" in s.info:
            s = s.convert("RGBA")
            if s.size[0] < w or s.size[1] < h:
                print(f"  WARN upscaling {src} {s.size}->({w},{h})")
            s = s.resize((w, h), Image.LANCZOS)
        else:
            s = s.convert("RGB").resize((w, h), Image.LANCZOS)
        s.save(out)
        n += 1
    return n

def grid(cells, cols, cell_w, cell_h, pad=10, bg=(112, 112, 112), label_h=18):
    rows = (len(cells) + cols - 1) // cols
    W = cols * cell_w + (cols + 1) * pad
    H = rows * (cell_h + label_h) + (rows + 1) * pad
    canvas = Image.new("RGB", (W, H), bg)
    d = ImageDraw.Draw(canvas)
    fnt = font(13)
    for i, (img, label) in enumerate(cells):
        r, c = divmod(i, cols)
        x = pad + c * (cell_w + pad)
        y = pad + r * (cell_h + label_h + pad)
        cx = x + (cell_w - img.size[0]) // 2
        cy = y + (cell_h - img.size[1])  # bottom-align figures
        if img.mode == "RGBA":
            canvas.paste(img, (cx, cy), img)
        else:
            canvas.paste(img, (cx, cy))
        d.text((x, y + cell_h + 2), label, fill=(235, 235, 235), font=fnt)
    return canvas

def fit(img, maxh):
    w, h = img.size
    s = maxh / h
    return img.resize((max(1, int(w * s)), maxh), Image.LANCZOS)

def main():
    os.makedirs(PREVIEW, exist_ok=True)
    print("Exporting runtime PNGs ->", RUNTIME)
    print("  figures:", export(FIGURES), " tiles/aff:", export(TILES))

    # --- Gate: figures grayscale @ phone scale (~120px tall) ---
    gray_cells, sil_cells = [], []
    for src, _, _, _, label, _ in FIGURES:
        im = Image.open(os.path.join(SRC, src)).convert("RGBA")
        small = fit(im, 120)
        # grayscale (preserve alpha)
        g = ImageOps.grayscale(small).convert("RGBA")
        g.putalpha(small.split()[3])
        gray_cells.append((g, label))
        # silhouette: alpha -> black on transparent
        sil = Image.new("RGBA", small.size, (0, 0, 0, 0))
        blk = Image.new("RGBA", small.size, (15, 15, 15, 255))
        sil = Image.composite(blk, sil, small.split()[3])
        sil_cells.append((sil, label))
    grid(gray_cells, 3, 150, 124, bg=(112, 112, 112)).save(os.path.join(PREVIEW, "figures_grayscale_phone.png"))
    grid(sil_cells, 3, 150, 124, bg=(235, 235, 235)).save(os.path.join(PREVIEW, "figures_silhouette.png"))

    # --- Gate: tiles grayscale @ ~72px ---
    tcells = []
    for src, _, _, _, label, _ in TILES:
        im = Image.open(os.path.join(SRC, src)).convert("RGB").resize((72, 72), Image.LANCZOS)
        tcells.append((ImageOps.grayscale(im).convert("RGB"), label))
    grid(tcells, 5, 72, 72, bg=(112, 112, 112)).save(os.path.join(PREVIEW, "tiles_grayscale_phone.png"))

    # --- Seam check: 2x2 of runtime floor/wall ---
    for name in ("tile.floor", "tile.wall"):
        t = Image.open(os.path.join(RUNTIME, "tiles", name + ".png")).convert("RGB")
        m = Image.new("RGB", (t.size[0] * 2, t.size[1] * 2))
        for px in (0, t.size[0]):
            for py in (0, t.size[1]):
                m.paste(t, (px, py))
        m.save(os.path.join(PREVIEW, f"seam_{name}.png"))

    print("Gate previews ->", PREVIEW)

if __name__ == "__main__":
    main()
