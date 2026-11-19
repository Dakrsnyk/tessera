"""Fond d'écran de la pub IRL Fitness (v3, 2026-11-19) : noir, lueur rouge discrète, haltère en fin trait rouge au centre,
fin cadre rouge arrondi. 1206 x 2622 (géométrie des captures du kit). Dessiné à 2x puis réduit (traits lissés).

Usage : python scripts/ad2/irl_wall.py <sortie.png>
"""
import math
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

W, H, K = 1206, 2622, 2
RED = (229, 56, 59)


def main(out):
    w, h = W * K, H * K
    y, x = np.mgrid[0:h, 0:w].astype(np.float32)
    # fond : noir bleuté très sombre, lueur rouge au centre bas
    d = np.sqrt(((x - w * 0.5) / (w * 0.75)) ** 2 + ((y - h * 0.66) / (h * 0.40)) ** 2)
    glow = np.clip(1 - d, 0, 1) ** 2.2
    base = np.stack([10 + 70 * glow, 9 + 6 * glow, 11 + 8 * glow], axis=-1)
    img = Image.fromarray(base.clip(0, 255).astype(np.uint8), "RGB")

    lines = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    g = ImageDraw.Draw(lines)
    lw = 3 * K
    # fin cadre rouge arrondi, en retrait du bord
    m = 34 * K
    g.rounded_rectangle([m, m, w - m, h - m], radius=150 * K, outline=RED + (170,), width=2 * K)

    # haltère vue de face, inclinée, sous les widgets (l'écran d'accueil de la pub n'a pas d'apps : noFill), au-dessus du Dock
    cx, cy, ang = w * 0.5, h * 0.675, math.radians(-24)

    def rot(px, py):
        return (cx + px * math.cos(ang) - py * math.sin(ang), cy + px * math.sin(ang) + py * math.cos(ang))

    def rect(x0, y0, x1, y1, r):
        # rectangle arrondi tourné : polyligne fermée
        pts = []
        for (ax, ay, a0) in ((x1 - r, y0 + r, -90), (x1 - r, y1 - r, 0), (x0 + r, y1 - r, 90), (x0 + r, y0 + r, 180)):
            for t in range(0, 91, 6):
                a = math.radians(a0 + t)
                pts.append(rot(ax + r * math.cos(a), ay + r * math.sin(a)))
        g.line(pts + [pts[0]], fill=RED + (255,), width=lw, joint="curve")

    s = K * 0.74
    rect(-330 * s, -16 * s, 330 * s, 16 * s, 10 * s)  # barre
    for side in (-1, 1):
        rect(side * 360 * s - 22 * s, -70 * s, side * 360 * s + 22 * s, 70 * s, 10 * s)  # butée
        rect(side * 420 * s - 30 * s, -190 * s, side * 420 * s + 30 * s, 190 * s, 18 * s)  # grand disque
        rect(side * 490 * s - 26 * s, -150 * s, side * 490 * s + 26 * s, 150 * s, 16 * s)  # disque moyen
        rect(side * 548 * s - 18 * s, -100 * s, side * 548 * s + 18 * s, 100 * s, 12 * s)  # petit disque
    halo = lines.filter(ImageFilter.GaussianBlur(14 * K))
    img = img.convert("RGBA")
    img.alpha_composite(halo)
    img.alpha_composite(halo)
    img.alpha_composite(lines)
    img = img.convert("RGB").resize((W, H), Image.LANCZOS)
    # grain léger contre les bandes du dégradé
    n = np.random.default_rng(3).normal(0, 2.2, (H, W, 1))
    img = Image.fromarray((np.asarray(img, np.float32) + n).clip(0, 255).astype(np.uint8))
    img.save(out)
    print(out, img.size)


if __name__ == "__main__":
    main(sys.argv[1])
