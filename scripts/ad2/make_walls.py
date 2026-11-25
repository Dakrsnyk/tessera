"""Plain wallpapers for the V4 Home Screens (a solid or gradient wallpaper is a normal iPhone setting).

    python -X utf8 scripts/ad2/make_walls.py   # writes wall-wine.png, wall-silver.png and wall-mono-photo.png (1206 x 2622) in the kit
"""
import os

import numpy as np
from PIL import Image, ImageFilter

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


def mono_photo(seed=7):
    """A soft black-and-white, photograph-like wallpaper made of procedural folds (no third-party picture): a pale top, a dark
    mass in the middle and a ribbed light fabric at the bottom, softly blurred."""
    rng = np.random.default_rng(seed)
    yy, xx = np.mgrid[0:H, 0:W].astype(np.float64)
    u, v = xx / W, yy / H

    def noise(scale, s):
        small = np.random.default_rng(s).random((max(2, int(H / scale)), max(2, int(W / scale))))
        im = Image.fromarray((small * 255).astype(np.uint8)).resize((W, H), Image.BICUBIC).filter(ImageFilter.GaussianBlur(scale / 3))
        return np.asarray(im, dtype=np.float64) / 255.0

    base = 0.86 - 0.48 * np.clip((v - 0.12) / 0.5, 0, 1) ** 1.2  # pale top fading to a grey mass
    base += 0.34 * np.clip((v - 0.62) / 0.3, 0, 1)  # light fabric at the bottom
    warp = (noise(420, seed) - 0.5) * 0.35 + (noise(180, seed + 1) - 0.5) * 0.12
    folds = 0.5 + 0.5 * np.sin((v * 7.0 + u * 2.2 + warp * 9.0) * np.pi)
    ribs = (folds - 0.5) * 0.30 * np.clip((v - 0.5) / 0.25, 0, 1)
    mass = np.exp(-(((u - 0.8) / 0.42) ** 2 + ((v - 0.47) / 0.17) ** 2)) * 0.5  # dark mass on the right
    img = base + ribs - mass + (noise(300, seed + 2) - 0.5) * 0.16
    img = np.clip(img, 0.05, 0.97)
    img += rng.normal(0, 0.004, img.shape)
    g = (np.clip(img, 0, 1) * 255).astype(np.uint8)
    return Image.fromarray(np.stack([g, g, g], axis=-1)).filter(ImageFilter.GaussianBlur(1.2))


if __name__ == "__main__":
    mono_photo().save(os.path.join(KIT, "wall-mono-photo.png"))
    wall("#2A0610", "#5C0F22", "#B3203E", 0.5, halo_at=(0.5, 0.30), seed=3).save(os.path.join(KIT, "wall-ruby.png"))
    wall("#F1EAFA", "#CDBDE8", "#FFFFFF", 0.75, halo_at=(0.5, 0.28), seed=4).save(os.path.join(KIT, "wall-lavender.png"))
    wall("#2A0A12", "#4A1220", "#7A2433", 0.55, halo_at=(0.5, 0.30)).save(os.path.join(KIT, "wall-wine.png"))
    wall("#E9ECF1", "#C9CED8", "#FFFFFF", 0.7, halo_at=(0.5, 0.28), seed=2).save(os.path.join(KIT, "wall-silver.png"))
    print("ok")
