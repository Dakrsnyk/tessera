"""Assembles pub/livraison-pubs-2026/ (chantier 19.5) from the renders of pub/film2026.

    python -X utf8 scripts/ad2/package_delivery.py [--move]

01_Ad_Main ... 08_Ad_Short : <lang>/<film>-<format>-<lang>.mp4 (copied, or moved with --move) and <lang>/thumbs/ (the
middle still of each shot is not a thumbnail: the thumbnail is the hero shot picked by THUMB_SHOT below).
09_Static_Visuals : <lang>/<format>/<film>-<shot>.png from the control stills (pub/film2026/s1<lang>/stills) + captions.
10_Source_Files : the Remotion project (sources only), the specifications, the audio and render scripts, the storyboards.
"""
import argparse
import glob
import os
import re
import shutil

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
FILM = os.path.join(REPO, "pub", "film2026")
OUT = os.path.join(REPO, "pub", "livraison-pubs-2026")
FOLDERS = {
    "main": "01_Ad_Main", "nutrition": "02_Ad_Nutrition", "fitness": "03_Ad_Fitness", "lifestyle": "04_Ad_Lifestyle",
    "widgets": "05_Ad_Widgets", "finance": "06_Ad_Finance", "organisation": "07_Ad_Organization",
    "short1": "08_Ad_Short", "short2": "08_Ad_Short", "short3": "08_Ad_Short",
}
FORMATS = ["9x16", "1x1", "4x5", "16x9"]
LANGS = ["en", "fr"]
THUMB_INDEX = 1  # the 2nd shot of each film: the first image of the app (the 1st is the opening line)


def stills(lang, film, fmt):
    files = glob.glob(os.path.join(FILM, f"s1{lang}", "stills", f"{film}-{fmt}-{lang}-f*.png"))
    return sorted(files, key=lambda p: int(re.search(r"-f(\d+)\.png$", p).group(1)))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--move", action="store_true")
    a = ap.parse_args()
    put = shutil.move if a.move else shutil.copy2
    missing = []
    for film, folder in FOLDERS.items():
        for lang in LANGS:
            d = os.path.join(OUT, folder, lang)
            os.makedirs(os.path.join(d, "thumbs"), exist_ok=True)
            for fmt in FORMATS:
                mp4 = os.path.join(FILM, folder, f"{film}-{fmt}-{lang}.mp4")
                if os.path.exists(mp4):
                    put(mp4, os.path.join(d, os.path.basename(mp4)))
                else:
                    missing.append(os.path.basename(mp4))
                st = stills(lang, film, fmt)
                if st:
                    shutil.copy2(st[min(THUMB_INDEX, len(st) - 1)], os.path.join(d, "thumbs", f"{film}-{fmt}-{lang}.png"))
                    sv = os.path.join(OUT, "09_Static_Visuals", lang, fmt)
                    os.makedirs(sv, exist_ok=True)
                    for i, p in enumerate(st):
                        shutil.copy2(p, os.path.join(sv, f"{film}-{i + 1:02d}.png"))
    src = os.path.join(OUT, "10_Source_Files")
    os.makedirs(src, exist_ok=True)
    for rel, name in [("scripts/ad2/film/src", "remotion-src"), ("scripts/ad3/spec", "voice-specs"), ("docs/memoire/campagne-2026", "storyboards-et-faits")]:
        dst = os.path.join(src, name)
        shutil.rmtree(dst, ignore_errors=True)
        shutil.copytree(os.path.join(REPO, rel), dst)
    scripts = os.path.join(src, "scripts")
    os.makedirs(scripts, exist_ok=True)
    for f in glob.glob(os.path.join(REPO, "scripts", "ad2", "*.py")) + glob.glob(os.path.join(REPO, "scripts", "ad2", "*.json")):
        shutil.copy2(f, scripts)
    for lang in LANGS:
        mixes = glob.glob(os.path.join(FILM, "audio", lang, "mix-*.wav"))
        os.makedirs(os.path.join(src, "audio-mixes", lang), exist_ok=True)
        for m in mixes:
            shutil.copy2(m, os.path.join(src, "audio-mixes", lang))
    shutil.copy2(os.path.join(REPO, "docs", "memoire", "campagne-2026", "Legendes-et-CTA.md"), os.path.join(OUT, "09_Static_Visuals", "Legendes-et-CTA.md"))
    print("missing videos:", missing or "none")


if __name__ == "__main__":
    main()
