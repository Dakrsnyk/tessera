"""Fonds d'écran neufs de la pub principale (V5) restylée au niveau de la pub avant / après, 1206 x 2622, procéduraux
(aucune image de tiers). Teintes volontairement différentes de la pub avant / après (pas de vert fluo, bleu glacier,
marine et or, rose ni émeraude). Un fond par écran d'accueil de la fin : Ivory, Indigo, Clay, Neon night, Bronze, Aurora.

    ~/ardane-tools/venv/Scripts/python.exe scripts/ad2/make_walls_main.py   # écrit dans ~/ardane-tools/film/public/mainpub
"""
import os
import sys

import numpy as np
from PIL import ImageFilter

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "avant_apres"))
from make_walls_aa import U, V, finish, gradient, noise, rgb, ribbon  # noqa: E402

OUT = os.path.join(os.path.expanduser("~"), "ardane-tools", "film", "public", "mainpub")


def layer(img, bands, warp, mode="mix"):
    for (c, a, f, p, w, k, t, col) in bands:
        g = ribbon(c, a, f, p, w, warp, t)[..., None]
        img = img * (1 - g * k) + rgb(col) * g * k if mode == "mix" else img + g * k * rgb(col)
    return img


def ivory():
    img = gradient([(0, "F7F1E7"), (0.45, "EEDFCB"), (1, "D8BE9C")])
    warp = (noise(480, 41) - 0.5) * 0.10 + (noise(170, 42) - 0.5) * 0.03
    img = layer(img, [(0.22, 0.06, 0.40, 0.1, 0.07, 0.45, -0.16, "FFFFFF"), (0.46, 0.05, 0.48, 0.5, 0.03, 0.30, -0.14, "F2C79E"),
                      (0.70, 0.07, 0.36, 0.8, 0.10, 0.30, -0.18, "FFFFFF"), (0.88, 0.05, 0.44, 0.3, 0.025, 0.30, -0.12, "E9A97A")], warp)
    return finish(img, 43, 0.007)


def indigo():
    img = gradient([(0, "0C0E26"), (0.5, "17164A"), (1, "07081A")])
    warp = (noise(500, 51) - 0.5) * 0.09 + (noise(190, 52) - 0.5) * 0.02
    img = layer(img, [(0.34, 0.07, 0.40, 0.2, 0.12, 0.55, -0.22, "2E2A7A"), (0.78, 0.06, 0.36, 0.6, 0.13, 0.50, -0.18, "2A2470")], warp, "add")
    img = layer(img, [(0.355, 0.07, 0.40, 0.2, 0.010, 0.70, -0.22, "B9A8FF"), (0.765, 0.06, 0.36, 0.6, 0.008, 0.60, -0.18, "8FB0FF"),
                      (0.56, 0.04, 0.5, 0.9, 0.006, 0.30, -0.20, "B9A8FF")], warp)
    return finish(img, 53, 0.01)


def clay():
    img = gradient([(0, "EAD6C4"), (0.45, "D9AE92"), (1, "B97C5E")])
    warp = (noise(460, 61) - 0.5) * 0.10 + (noise(160, 62) - 0.5) * 0.03
    img = layer(img, [(0.25, 0.06, 0.42, 0.3, 0.06, 0.40, 0.18, "F6E9DC"), (0.50, 0.05, 0.50, 0.7, 0.03, 0.30, 0.15, "FFF6EE"),
                      (0.72, 0.07, 0.38, 0.1, 0.09, 0.28, 0.20, "A9634A"), (0.90, 0.05, 0.46, 0.5, 0.025, 0.30, 0.14, "F6E9DC")], warp)
    return finish(img, 63, 0.008)


def neon_night():
    img = gradient([(0, "08040F"), (0.5, "150A26"), (1, "05030B")])
    warp = (noise(500, 71) - 0.5) * 0.09 + (noise(190, 72) - 0.5) * 0.02
    img = layer(img, [(0.30, 0.07, 0.42, 0.15, 0.11, 0.45, 0.24, "3A0F4A"), (0.80, 0.06, 0.38, 0.55, 0.12, 0.40, 0.20, "1A1450")], warp, "add")
    img = layer(img, [(0.315, 0.07, 0.42, 0.15, 0.009, 0.85, 0.24, "FF3DB8"), (0.785, 0.06, 0.38, 0.55, 0.008, 0.70, 0.20, "5CE1FF"),
                      (0.55, 0.04, 0.5, 0.9, 0.005, 0.35, 0.22, "FF3DB8")], warp)
    return finish(img, 73, 0.01)


def bronze():
    img = gradient([(0, "0B0A09"), (0.5, "17130F"), (1, "070605")])
    warp = (noise(520, 81) - 0.5) * 0.09 + (noise(200, 82) - 0.5) * 0.02
    img = layer(img, [(0.33, 0.07, 0.40, 0.25, 0.12, 0.55, -0.20, "3A2A1A"), (0.79, 0.06, 0.36, 0.65, 0.13, 0.50, -0.16, "33251A")], warp, "add")
    img = layer(img, [(0.345, 0.07, 0.40, 0.25, 0.010, 0.75, -0.20, "D3AE78"), (0.775, 0.06, 0.36, 0.65, 0.008, 0.60, -0.16, "B88C55"),
                      (0.57, 0.04, 0.5, 0.95, 0.005, 0.30, -0.18, "D3AE78")], warp)
    return finish(img, 83, 0.01)


def aurora():
    img = gradient([(0, "04101A"), (0.5, "072238"), (1, "030D16")])
    warp = (noise(480, 91) - 0.5) * 0.12 + (noise(170, 92) - 0.5) * 0.03
    img = layer(img, [(0.28, 0.08, 0.36, 0.1, 0.10, 0.50, 0.26, "1E8C9C"), (0.36, 0.07, 0.44, 0.5, 0.14, 0.35, 0.22, "2C4FB0"),
                      (0.74, 0.07, 0.34, 0.7, 0.12, 0.40, 0.18, "1C7F9A")], warp, "add")
    img = layer(img, [(0.29, 0.08, 0.36, 0.1, 0.010, 0.55, 0.26, "7FF0E6"), (0.735, 0.07, 0.34, 0.7, 0.008, 0.45, 0.18, "8FB8FF")], warp)
    return finish(img, 93, 0.01)


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    for name, fn in [("wall-mp-ivory", ivory), ("wall-mp-indigo", indigo), ("wall-mp-clay", clay), ("wall-mp-neon", neon_night), ("wall-mp-bronze", bronze), ("wall-mp-aurora", aurora)]:
        fn().filter(ImageFilter.GaussianBlur(1.2)).save(os.path.join(OUT, name + ".png"))
        print("ok", name)
