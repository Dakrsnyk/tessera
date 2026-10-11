"""Where each widget and dock icon sits in the hero Home Screens of the ad kit, measured on the pictures
themselves (masked template matching), so a layer can lift out of its exact slot.

    python -X utf8 kit_layout.py <kit export dir> <out.json>

For each universe (setup-hero-<id>.json + home-hero-<id>.png): the wallpaper, the home widgets with their
rectangle in Home pixels (1206 × 2622, scale 3), and the dock icons with theirs.
"""
import json
import os
import sys

import numpy as np
from PIL import Image
from scipy.signal import fftconvolve

UNIVERSES = ["aurore", "espace", "etudes", "neon", "graphite", "crepuscule"]
WALLS = {"aurora": "wall-aurora.png", "midnight": "wall-midnight.png", "paper": "wall-paper.png",
         "synthwave": "wall-synthwave.png", "graphite": "wall-graphite.png", "sunset": "wall-sunset.png"}


def gray(img):
    a = np.asarray(img.convert("RGBA"), dtype=np.float64) / 255
    return a[..., :3].mean(axis=2), a[..., 3]


def find(home, piece, scale, region=None):
    """Top-left of `piece` (RGBA, drawn at `scale` px/pt) in `home` (scale 3): masked SSD, coarse then fine."""
    w, h = piece.size
    piece = piece.resize((round(w * 3 / scale), round(h * 3 / scale)), Image.LANCZOS)
    k = 4
    hg, _ = gray(home.resize((home.width // k, home.height // k), Image.BOX))
    small = piece.resize((max(1, piece.width // k), max(1, piece.height // k)), Image.BOX)
    tg, tm = gray(small)
    tm = (tm > 0.9).astype(float)

    def ssd(I, T, M):
        flip = lambda x: x[::-1, ::-1]
        a = fftconvolve(I ** 2, flip(M), mode="valid")
        b = fftconvolve(I, flip(M * T), mode="valid")
        return a - 2 * b + (M * T ** 2).sum()

    score = ssd(hg, tg, tm)
    y, x = np.unravel_index(np.argmin(score), score.shape)
    # Refine at full resolution around the coarse hit.
    hgf, _ = gray(home)
    tgf, tmf = gray(piece)
    tmf = (tmf > 0.9).astype(float)
    best, pos = None, (x * k, y * k)
    for yy in range(max(0, y * k - 6), y * k + 7):
        for xx in range(max(0, x * k - 6), x * k + 7):
            win = hgf[yy:yy + piece.height, xx:xx + piece.width]
            if win.shape != tgf.shape:
                continue
            s = (tmf * (win - tgf) ** 2).sum()
            if best is None or s < best:
                best, pos = s, (xx, yy)
    err = best / max(1, tmf.sum())
    return [int(pos[0]), int(pos[1]), piece.width, piece.height], float(err)


def main():
    root, out = sys.argv[1:3]
    layout = {}
    for u in UNIVERSES:
        home = Image.open(os.path.join(root, f"home-hero-{u}.png"))
        meta = json.load(open(os.path.join(root, f"setup-hero-{u}.json"), encoding="utf-8"))
        entry = {"home": f"home-hero-{u}.png", "wall": WALLS.get(meta["wallpaper"]), "widgets": [], "dock": []}
        for w in meta["widgets"]:
            if w["place"] != "home":
                continue
            rect, err = find(home, Image.open(os.path.join(root, w["file"])), w["scale"])
            entry["widgets"].append({"file": w["file"], "kind": w["kind"], "family": w["family"], "rect": rect, "err": round(err, 5)})
        icons_meta = os.path.join(root, f"icons-{u}.json")
        if os.path.exists(icons_meta):
            for ic in json.load(open(icons_meta, encoding="utf-8"))["icons"]:
                if ic["place"] != "dock":
                    continue
                rect, err = find(home, Image.open(os.path.join(root, ic["file"])), 4)
                entry["dock"].append({"file": ic["file"], "rect": rect, "err": round(err, 5)})
        layout[u] = entry
        print(u, [(w["kind"], w["rect"], w["err"]) for w in entry["widgets"]], len(entry["dock"]), "dock icons")
    json.dump(layout, open(out, "w", encoding="utf-8"), indent=1)


if __name__ == "__main__":
    main()
