"""Remixe la pub principale V5 (v5short + v5part2) avec les « ding » plus bas (demande du PDG, 2026-11-12).

Les « ding » sont les notes de verre FM : glass* (et les notes nommées), notif, check, et l'étincelle de logo_in.
Tout le reste (musique, voix, souffles, clics, impacts) est inchangé : même partition, même voix, même mastering.

    ~/ardane-tools/venv/Scripts/python.exe -I -X utf8 scripts/ad2/remix_soft_dings.py <dossier_sortie> [ding_db]

--null : remixe SANS baisser (contrôle : doit redonner les mixages existants).
Écrit <dossier_sortie>/mix-v5short.wav et mix-v5part2.wav (à copier dans ~/ardane-tools/film/public/audio/en/).
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import audio2026 as A  # noqa: E402

# glass* et les notes nommées passent par M.glass (baissé une fois ci-dessous) ; notif et check par synth.fm_glass.
DINGS = {"notif", "check"}
LOGO_DB_SHARE = 0.75  # logo_in a aussi un souffle et un coup sourd : on le baisse un peu moins


def soften(ding_db):
    bank0 = A.sfx_bank

    def bank():
        b = bank0()
        out = {}
        for name, make in b.items():
            if name in DINGS:
                out[name] = (lambda m=make: m() * A.db(ding_db))
            elif name == "logo_in":
                out[name] = (lambda m=make: m() * A.db(ding_db * LOGO_DB_SHARE))
            else:
                out[name] = make
        return out

    A.sfx_bank = bank
    # glass* (sfx_bank lit M.glass à chaque appel) et notes nommées (« D5 », « A6 »… appelées par sfx_stem)
    glass0 = A.M.glass
    A.M.glass = lambda *a, **k: glass0(*a, **k) * A.db(ding_db)


if __name__ == "__main__":
    out = sys.argv[1]
    null = "--null" in sys.argv
    args = [a for a in sys.argv[2:] if not a.startswith("--")]
    ding_db = float(args[0]) if args else -8.0
    if not null:
        soften(ding_db)
    A.OUT_DIR = out
    for film in ("v5short", "v5part2"):
        A.mix_film(film, "en")
    print("dings", "inchangés" if null else f"{ding_db} dB", "->", os.path.join(out, "en"))
