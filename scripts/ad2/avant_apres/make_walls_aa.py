"""Fonds d'écran neufs de la pub « Voici ton téléphone… et voici le mien » (avant / après), 1206 x 2622, procéduraux
(aucune image de tiers). Un fond par écran « après » : Volt (sport), Glacier (organisation), Marine et or (finance).

    ~/ardane-tools/dl-venv/Scripts/python.exe scripts/ad2/avant_apres/make_walls_aa.py   # écrit dans ~/ardane-tools/film/public/avantapres
"""
import os

import numpy as np
from PIL import Image, ImageFilter

W, H = 1206, 2622
OUT = os.path.join(os.path.expanduser("~"), "ardane-tools", "film", "public", "avantapres")
yy, xx = np.mgrid[0:H, 0:W].astype(np.float64)
U, V = xx / W, yy / H


def rgb(h):
    return np.array([int(h[i:i + 2], 16) for i in (0, 2, 4)], dtype=np.float64) / 255.0


def noise(scale, seed):
    small = np.random.default_rng(seed).random((max(2, int(H / scale)), max(2, int(W / scale))))
    im = Image.fromarray((small * 255).astype(np.uint8)).resize((W, H), Image.BICUBIC).filter(ImageFilter.GaussianBlur(scale / 3))
    return np.asarray(im, dtype=np.float64) / 255.0


def gradient(stops):
    """stops: [(v, hex)] from top to bottom."""
    img = np.zeros((H, W, 3))
    vs = [s[0] for s in stops]
    for c in range(3):
        img[..., c] = np.interp(V, vs, [rgb(s[1])[c] for s in stops])
    return img


def ribbon(center, amp, freq, phase, width, warp, tilt=0.0):
    """Soft band along y = center + amp sin(2 pi (freq x + phase)) + tilt (x - 0.5); returns 0..1."""
    y = center + amp * np.sin(2 * np.pi * (freq * U + phase)) + tilt * (U - 0.5) + warp
    d = (V - y) / width
    return np.exp(-d * d)


def finish(img, seed, grain=0.012):
    img = img + np.random.default_rng(seed).normal(0, grain, img.shape)
    return Image.fromarray((np.clip(img, 0, 1) * 255).astype(np.uint8))


def volt():
    img = gradient([(0, "0B0C0A"), (0.55, "10120D"), (1, "070806")])
    warp = (noise(500, 3) - 0.5) * 0.08
    lime = rgb("C6FF00")
    for (c, a, f, p, w, k, t) in [(0.86, 0.04, 0.6, 0.1, 0.020, 0.85, -0.36), (0.89, 0.05, 0.5, 0.3, 0.055, 0.30, -0.34),
                                   (0.30, 0.04, 0.7, 0.6, 0.012, 0.35, -0.38), (0.33, 0.05, 0.5, 0.8, 0.07, 0.12, -0.36)]:
        g = ribbon(c, a, f, p, w, warp, t)[..., None]
        img = img + g * k * lime
    glow = np.exp(-(((U - 0.15) / 0.5) ** 2 + ((V - 0.86) / 0.18) ** 2))[..., None]
    img = img + glow * 0.10 * lime
    return finish(img, 11)


def glacier():
    img = gradient([(0, "9CC2EA"), (0.35, "79A6DA"), (0.7, "5585BE"), (1, "335F96")])
    warp = (noise(420, 5) - 0.5) * 0.10 + (noise(160, 6) - 0.5) * 0.03
    white = rgb("FFFFFF")
    lav = rgb("C9C3F2")
    for (c, a, f, p, w, k, t, col) in [(0.24, 0.06, 0.45, 0.0, 0.05, 0.45, 0.20, white), (0.47, 0.05, 0.55, 0.4, 0.035, 0.32, 0.18, white),
                                        (0.62, 0.07, 0.40, 0.7, 0.08, 0.22, 0.22, lav), (0.83, 0.05, 0.5, 0.2, 0.03, 0.28, 0.16, white)]:
        g = ribbon(c, a, f, p, w, warp, t)[..., None]
        img = img * (1 - g * k) + col * g * k
    return finish(img, 12, 0.008)


def marine():
    img = gradient([(0, "071427"), (0.5, "0A1B33"), (1, "040A16")])
    warp = (noise(520, 8) - 0.5) * 0.09 + (noise(200, 9) - 0.5) * 0.02
    gold = rgb("E5B567")
    navy_hi = rgb("1E3A63")
    for (c, a, f, p, w, k, t, col) in [(0.36, 0.07, 0.42, 0.15, 0.10, 0.55, -0.25, navy_hi), (0.38, 0.07, 0.42, 0.15, 0.011, 0.85, -0.25, gold),
                                        (0.80, 0.06, 0.38, 0.55, 0.12, 0.45, -0.20, navy_hi), (0.765, 0.06, 0.38, 0.55, 0.009, 0.75, -0.20, gold),
                                        (0.58, 0.05, 0.5, 0.9, 0.006, 0.35, -0.22, gold)]:
        g = ribbon(c, a, f, p, w, warp, t)[..., None]
        img = img * (1 - g * k) + col * g * k if col is gold else img + g * k * col
    return finish(img, 13, 0.01)


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    for name, fn in [("wall-aa-volt", volt), ("wall-aa-glacier", glacier), ("wall-aa-marine", marine)]:
        im = fn()
        im = im.filter(ImageFilter.GaussianBlur(1.2))
        im.save(os.path.join(OUT, name + ".png"))
        print("ok", name)
