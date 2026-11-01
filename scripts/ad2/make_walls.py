"""Plain wallpapers for the V4 Home Screens (a solid or gradient wallpaper is a normal iPhone setting).

    python -X utf8 scripts/ad2/make_walls.py   # writes wall-wine.png and wall-silver.png (1206 x 2622) in the kit
"""
import os

import numpy as np
from PIL import Image

W, H = 1206, 2622
KIT = os.path.join(os.path.expanduser("~"), "ardane-tools", "film", "public", "kit2026", "en")


def hexrgb(h):
    return np.array([int(h[i:i + 2], 16) for i in (1, 3, 5)], dtype=np.float64)


def wall(top, bottom, halo, halo_strength, halo_at=(0.5, 0.34), halo_r=0.75, seed=1):
    y = np.linspace(0, 1, H)[:, None, None]
    img = hexrgb(top) * (1 - y) + hexrgb(bottom) * y
    img = np.broadcast_to(img, (H, W, 3)).copy()
    yy, xx = np.mgrid[0:H, 0:W]
    d = np.sqrt(((xx / W - halo_at[0]) * W) ** 2 + ((yy / H - halo_at[1]) * H) ** 2) / (H * halo_r)
    g = np.exp(-(d ** 2) * 2.2)[..., None]
    img = img * (1 - g * halo_strength) + hexrgb(halo) * g * halo_strength
    # 1 LSB of noise so the long gradient never bands
    img += np.random.default_rng(seed).normal(0, 0.9, img.shape)
    return Image.fromarray(np.clip(img, 0, 255).astype(np.uint8))


if __name__ == "__main__":
    wall("#2A0A12", "#4A1220", "#7A2433", 0.55, halo_at=(0.5, 0.30)).save(os.path.join(KIT, "wall-wine.png"))
    wall("#E9ECF1", "#C9CED8", "#FFFFFF", 0.7, halo_at=(0.5, 0.28), seed=2).save(os.path.join(KIT, "wall-silver.png"))
    print("ok")
