"""Vraies icônes des apps Apple pour les pubs, découpées dans la vraie capture de l'écran d'accueil du simulateur iOS
(iPhone 16 Pro, étape CI [ios-home], report/ios-home/ios-home-light.png de la branche ci-report). Jamais redessinées.

    ~/ardane-tools/dl-venv/Scripts/python.exe -X utf8 scripts/ad2/avant_apres/apple_icons.py [capture.png]

Écrit ~/ardane-tools/film/public/apple-icons/<Nom>.png (188 x 188, coins arrondis transparents, 2 px rognés pour ne garder
aucun pixel du fond) et ios-home-light-fixed.png (la capture, pile pleine au lieu de « en charge », règle marketing d'Apple).
Les images restent HORS du dépôt (dépôt public : pas d'illustrations d'Apple versionnées).

Les 10 apps disponibles (le simulateur n'a ni Téléphone, ni Appareil photo, ni Musique, ni Horloge, ni App Store) :
Calendar, Photos, Reminders, News, Maps, Health, Wallet, Settings, Safari, Messages.
"""
import os
import sys

import numpy as np
from PIL import Image, ImageDraw

HOME = os.path.expanduser("~")
OUT = os.path.join(HOME, "ardane-tools", "film", "public", "apple-icons")
SRC = sys.argv[1] if len(sys.argv) > 1 else os.path.join(HOME, "ardane-tools", "film", "public", "avantapres", "ios-home-light.png")

S = 188  # côté d'une icône, px @3x (mesuré)
CX = [186.5, 463.5, 741.5, 1019]  # centres des 4 colonnes
BOXES = {
    "Calendar": (CX[0], 874), "Photos": (CX[1], 874), "Reminders": (CX[2], 874), "News": (CX[3], 874),
    "Maps": (CX[0], 1175), "Health": (CX[1], 1175), "Wallet": (CX[2], 1175), "Settings": (CX[3], 1175),
    "Safari": (470.5, 2322), "Messages": (734.5, 2322),  # Dock de 2 icônes, centrées
}


def mask(inset=2):
    k = 4
    m = Image.new("L", (S * k, S * k), 0)
    ImageDraw.Draw(m).rounded_rectangle((inset * k, inset * k, S * k - 1 - inset * k, S * k - 1 - inset * k), radius=int(S * k * 0.2237) - inset * k, fill=255)
    return m.resize((S, S), Image.LANCZOS)


def fix_battery(im):
    """Remplace la pile « en charge » (verte) par une pile pleine blanche, comme le veut Apple dans les pubs."""
    a = np.asarray(im.convert("RGB")).astype(float).copy()
    x0, x1, y0, y1 = 1012, 1110, 70, 128
    L, R = a[y0:y1, x0 - 4:x0 - 1].mean(1), a[y0:y1, x1 + 1:x1 + 4].mean(1)
    for x in range(x0, x1):
        t = (x - x0) / (x1 - x0)
        a[y0:y1, x] = L * (1 - t) + R * t
    out = Image.fromarray(a.clip(0, 255).astype(np.uint8)).convert("RGBA")
    k = 4
    ov = Image.new("RGBA", (120 * k, 60 * k), (0, 0, 0, 0))
    d = ImageDraw.Draw(ov)
    w, w4 = (255, 255, 255, 255), (255, 255, 255, 110)
    d.rounded_rectangle((5 * k, 7 * k, 75 * k, 42 * k), radius=10 * k, outline=w4, width=3 * k)
    d.rounded_rectangle((10 * k, 12 * k, 70 * k, 37 * k), radius=int(6.5 * k), fill=w)
    d.rounded_rectangle((78 * k, 18 * k, int(82.5 * k), 31 * k), radius=2 * k, fill=w4)
    out.alpha_composite(ov.resize((120, 60), Image.LANCZOS), (1015, 72))
    return out.convert("RGB")


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    im = Image.open(SRC).convert("RGBA")
    assert im.size == (1206, 2622), f"capture inattendue {im.size} (iPhone 16 Pro attendu)"
    m = mask()
    for name, (cx, y) in BOXES.items():
        x = int(round(cx - S / 2))
        ic = im.crop((x, y, x + S, y + S))
        ic.putalpha(m)
        ic.save(os.path.join(OUT, f"{name}.png"))
    fix_battery(im).save(os.path.join(OUT, "ios-home-light-fixed.png"))
    print(f"ok {len(BOXES)} icônes dans {OUT}")
