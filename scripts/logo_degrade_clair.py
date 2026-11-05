"""Variantes de l'icône Ardane avec un dégradé de fond plus clair, forme du « A » reprise pixel par pixel.

Le fond actuel est un dégradé linéaire (ajusté par moindres carrés, écart type ~1 niveau). La couverture du
symbole (alpha, bords lissés compris) est retrouvée en projetant chaque pixel entre le fond et la couleur du
symbole (blanc à gauche, #D6E9FA à droite). Seul le fond change ; il est éclairci dans OKLab (teinte gardée).
"""
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFont

SRC = Path(sys.argv[1])
OUT = Path(sys.argv[2])
OUT.mkdir(parents=True, exist_ok=True)

orig = np.asarray(Image.open(SRC).convert("RGB")).astype(float)
H, W, _ = orig.shape
yy, xx = np.mgrid[0:H, 0:W]
u, v = xx / (W - 1), yy / (H - 1)

# 1. Fond : dégradé linéaire ajusté sur les pixels clairement bleus.
mask_bg = orig[..., 0] < 110
X = np.stack([np.ones(mask_bg.sum()), u[mask_bg], v[mask_bg]], 1)
coef = [np.linalg.lstsq(X, orig[..., c][mask_bg], rcond=None)[0] for c in range(3)]
bg = np.stack([coef[c][0] + coef[c][1] * u + coef[c][2] * v for c in range(3)], -1)

# 2. Couverture du symbole.
sym = np.where((xx < W / 2)[..., None], np.array([255, 255, 255.0]), np.array([0xD6, 0xE9, 0xFA], float))
LINEAR = "--linear" in sys.argv  # le mélange sRGB reproduit mieux l'original


def lin(c):
    c = np.asarray(c, float) / 255
    return np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4) if LINEAR else c


def unlin(c):
    c = np.clip(c, 0, 1)
    return 255 * (np.where(c <= 0.0031308, 12.92 * c, 1.055 * c ** (1 / 2.4) - 0.055) if LINEAR else c)


d = lin(sym) - lin(bg)
alpha = np.clip(((lin(orig) - lin(bg)) * d).sum(-1) / np.maximum((d * d).sum(-1), 1e-9), 0, 1)
alpha[alpha < 0.002] = 0


# 3. OKLab.
def to_lin(c):
    c = c / 255
    return np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)


def to_srgb(c):
    c = np.clip(c, 0, 1)
    return 255 * np.where(c <= 0.0031308, 12.92 * c, 1.055 * c ** (1 / 2.4) - 0.055)


M1 = np.array([[0.4122214708, 0.5363325363, 0.0514459929], [0.2119034982, 0.6806995451, 0.1073969566],
               [0.0883024619, 0.2817188376, 0.6299787005]])
M2 = np.array([[0.2104542553, 0.7936177850, -0.0040720468], [1.9779984951, -2.4285922050, 0.4505937099],
               [0.0259040371, 0.7827717662, -0.8086757660]])


def oklab(rgb):
    lms = np.cbrt(to_lin(rgb) @ M1.T)
    return lms @ M2.T


def from_oklab(lab):
    lms = (lab @ np.linalg.inv(M2).T) ** 3
    return to_srgb(lms @ np.linalg.inv(M1).T)


def lum(rgb):
    lin = to_lin(np.asarray(rgb, float))
    return lin @ np.array([0.2126, 0.7152, 0.0722])


def contrast(a, b):
    la, lb = lum(a), lum(b)
    return (max(la, lb) + 0.05) / (min(la, lb) + 0.05)


bg_lab = oklab(bg)


def hex_rgb(h):
    h = h.lstrip("#")
    return np.array([int(h[i:i + 2], 16) for i in (0, 2, 4)], float)


def make(dl_top=0.0, dl_bottom=None, chroma=1.0, stops=None):
    """Fond éclairci de dl_top en haut à gauche, dl_bottom en bas à droite (même valeur si absent) ; ou, avec
    `stops` [(position 0..1, "#RRGGBB"), ...], un nouveau dégradé interpolé dans OKLab le long du même axe."""
    dl_bottom = dl_top if dl_bottom is None else dl_bottom
    t = np.clip((u * 0.27 + v) / 1.27, 0, 1)[..., None]  # avance le long du dégradé (surtout vertical)
    if stops:
        pos = np.array([p for p, _ in stops])
        labs = np.stack([oklab(hex_rgb(c)[None, None, :])[0, 0] for _, c in stops])
        lab = np.stack([np.interp(t[..., 0], pos, labs[:, k]) for k in range(3)], -1)
    else:
        lab = bg_lab.copy()
        lab[..., :1] += dl_top * (1 - t) + dl_bottom * t
        lab[..., 1:] *= chroma
    new_bg = from_oklab(lab)
    out = unlin(lin(new_bg) * (1 - alpha[..., None]) + lin(sym) * alpha[..., None])
    if RESIDUAL is not None:
        out = out + RESIDUAL  # halos de bord de l'original, reportés tels quels
    return np.clip(np.round(out), 0, 255).astype(np.uint8), new_bg


RESIDUAL = None
RESIDUAL = orig - make(dl_top=0.0)[0].astype(float)

CYAN = "--cyan" in sys.argv
CYAN_VARIANTS = [
    ("0-actuel", "Actuel", dict(dl_top=0.0)),
    ("F-cyan-en-haut", "F · cyan en haut", dict(stops=[(0, "#2EB2E4"), (1, "#1B4A7A")])),
    ("G-cyan-clair", "G · cyan clair", dict(stops=[(0, "#4CC4F0"), (1, "#2A5F96")])),
    ("H-turquoise-bleu-roi", "H · turquoise et bleu roi", dict(stops=[(0, "#17B3D0"), (1, "#1D4E9E")])),
    ("I-cyan-en-bas", "I · bleu vers cyan", dict(stops=[(0, "#3D7FD0"), (1, "#13A0C2")])),
    ("J-cyan-saphir-nuit", "J · cyan, saphir, nuit", dict(stops=[(0, "#33BDEB"), (0.55, "#2A6CB0"), (1, "#183F70")])),
    ("K-touche-de-cyan", "K · touche de cyan", dict(stops=[(0, "#52AEE8"), (1, "#1F5288")])),
]
VARIANTS = CYAN_VARIANTS if CYAN else [
    ("0-actuel", "Actuel", dict(dl_top=0.0)),
    ("A-un-peu-plus-clair", "A · un peu plus clair", dict(dl_top=0.04)),
    ("B-plus-clair", "B · plus clair", dict(dl_top=0.07)),
    ("C-nettement-plus-clair", "C · nettement plus clair", dict(dl_top=0.10)),
    ("D-lumiere-en-haut", "D · lumière en haut", dict(dl_top=0.09, dl_bottom=0.02)),
    ("E-plus-clair-plus-vif", "E · plus clair et plus vif", dict(dl_top=0.06, chroma=1.12)),
]

hexa = lambda c: "#%02X%02X%02X" % tuple(int(round(x)) for x in np.clip(c, 0, 255))
top_sym = (int(0.5 * W), int(0.193 * H))  # haut du « A » : le fond le plus clair qui touche le symbole
rows = []
for slug, name, kw in VARIANTS:
    img, nbg = make(**kw)
    if slug == "0-actuel":
        print("fidélité de la reconstruction : écart max", int(np.abs(img.astype(int) - orig.astype(int)).max()),
              "niveaux, moyen", round(float(np.abs(img.astype(int) - orig.astype(int)).mean()), 3))
    Image.fromarray(img).save(OUT / f"ardane-{slug}-1024.png", optimize=True)
    start, end = nbg[0, 0], nbg[-1, -1]
    near = nbg[top_sym[1], top_sym[0]]
    c_white, c_light = contrast((255, 255, 255), near), contrast((0xD6, 0xE9, 0xFA), near)
    rows.append((slug, name, img, hexa(start), hexa(end), c_white, c_light))
    print(f"{name:28s} {hexa(start)} -> {hexa(end)}  contraste haut du A : blanc {c_white:.2f}:1, bleu pâle {c_light:.2f}:1")


# 4. Planche comparative.
def rounded(img, size):
    s = 4
    big = Image.new("L", (size * s, size * s), 0)
    ImageDraw.Draw(big).rounded_rectangle([0, 0, size * s - 1, size * s - 1], radius=int(0.2237 * size * s), fill=255)
    m = big.resize((size, size), Image.LANCZOS)
    ic = Image.fromarray(img).resize((size, size), Image.LANCZOS)
    ic.putalpha(m)
    return ic


def font(sz, bold=False):
    name = "segoeuib.ttf" if bold else "segoeui.ttf"
    try:
        return ImageFont.truetype(f"C:/Windows/Fonts/{name}", sz)
    except OSError:
        return ImageFont.load_default()


COL, ICON, PAD = 330, 260, 40
sheet_w = PAD * 2 + COL * len(rows)
sheet_h = 790
sheet = Image.new("RGB", (sheet_w, sheet_h), (246, 246, 248))
dr = ImageDraw.Draw(sheet)
dr.text((PAD, 28), "Icône Ardane : même « A », dégradé avec du cyan" if CYAN else "Icône Ardane : même « A », dégradé plus clair", font=font(34, True), fill=(20, 20, 24))
dr.text((PAD, 74), ("Seul le fond change (nouveau dégradé interpolé dans OKLab, même axe). " if CYAN else "Seul le fond change (éclairci dans OKLab, même teinte). ") + "Contraste = haut du « A », là où le fond est le plus clair.",
        font=font(19), fill=(90, 90, 98))
dark = (28, 28, 32)
for i, (slug, name, img, s, e, cw, cl) in enumerate(rows):
    x0 = PAD + i * COL
    sheet.paste(rounded(img, ICON), (x0 + (COL - ICON) // 2 - 10, 130), rounded(img, ICON))
    y = 130 + ICON + 20
    dr.text((x0, y), name, font=font(22, True), fill=(20, 20, 24))
    dr.text((x0, y + 34), f"{s} → {e}", font=font(18), fill=(70, 70, 78))
    dr.text((x0, y + 60), f"blanc {cw:.1f}:1 · bleu pâle {cl:.1f}:1", font=font(18), fill=(70, 70, 78))
    # Petites tailles, sur fond clair puis sombre.
    yb = y + 108
    dr.rounded_rectangle([x0, yb, x0 + COL - 30, yb + 110], radius=18, fill=(255, 255, 255))
    dr.rounded_rectangle([x0, yb + 124, x0 + COL - 30, yb + 234], radius=18, fill=dark)
    for j, size in enumerate((60, 40, 29)):  # tailles réelles d'iOS
        xs = x0 + 18 + j * 96
        for k, base in enumerate((yb, yb + 124)):
            ic = rounded(img, size)
            sheet.paste(ic, (xs + (60 - size) // 2, base + 25 + (60 - size) // 2), ic)
    dr.text((x0, yb + 246), "60 · 40 · 29 px", font=font(16), fill=(120, 120, 128))
sheet.save(OUT / "comparatif.png", optimize=True)
print("écrit :", OUT)
