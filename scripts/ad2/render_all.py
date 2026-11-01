"""Renders the 10 films of the 2026 campaign in a format and a language (Remotion, 60 fps), from ~/ardane-tools/film.

    python -X utf8 scripts/ad2/render_all.py still  <film|all> [--format 4x5|all] [--lang fr|all] [--out NAME]
    python -X utf8 scripts/ad2/render_all.py video  <film|all> [--format 4x5|all] [--lang fr|all] [--out NAME]
    python -X utf8 scripts/ad2/render_all.py index      # list the captures of public/kit and public/kit2026 (src/ad26/available.json)
    python -X utf8 scripts/ad2/render_all.py check      # names of captures the shots ask for and no kit has yet

films: main nutrition fitness lifestyle widgets finance organisation short1 short2 short3.
Compositions: FilmMain FilmNutrition2 FilmFitness2 FilmLifestyle FilmWidgets FilmFinance FilmOrganisation FilmShort1/2/3.
Formats: 9x16 1x1 4x5 16x9. Languages: en fr.
- still: one image per shot of the storyboard (at its middle), to check every shot before a full render.
- video: the whole film (H.264, CRF 16, BT.709, 60 fps). LONG: measure with `still` first (time per image).
Output: pub/film2026/<OUT>/ (OUT defaults to the delivery folder of the film: 01_Ad_Main ... 08_Ad_Short; use
`--out check` for control renders; pub/ is ignored by Git): <film>-<format>-<lang>.mp4 and stills/<film>-<format>-<lang>-f<frame>.png.
The voice-over of a language is public/audio/<lang>/mix-<film>.wav (mixed by audio2026.py: pub/film2026/audio/<lang>/);
until it exists the film renders silent (warned).
The sources must be synchronised first: python -X utf8 scripts/ad2/film_sync.py import
"""
import argparse
import json
import os
import re
import subprocess
import sys
import time

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
WORK = os.path.join(os.path.expanduser("~"), "ardane-tools", "film")
SRC = os.path.join(REPO, "scripts", "ad2", "film", "src")
FILMS_TSX = os.path.join(SRC, "ad26", "films.tsx")
# film -> (composition, frames, delivery folder); the frames are those of the storyboards (60 fps).
FILMS = {
    "main": ("FilmMain", 2700, "01_Ad_Main"),
    "nutrition": ("FilmNutrition2", 1440, "02_Ad_Nutrition"),
    "fitness": ("FilmFitness2", 1440, "03_Ad_Fitness"),
    "lifestyle": ("FilmLifestyle", 2520, "04_Ad_Lifestyle"),
    "widgets": ("FilmWidgets", 1800, "05_Ad_Widgets"),
    "finance": ("FilmFinance", 1140, "06_Ad_Finance"),
    "organisation": ("FilmOrganisation", 1440, "07_Ad_Organization"),
    "short1": ("FilmShort1", 480, "08_Ad_Short"),
    "short2": ("FilmShort2", 480, "08_Ad_Short"),
    "short3": ("FilmShort3", 480, "08_Ad_Short"),
}
FUNC = {"widgets": "widgetsFilm"}
FORMATS = ["9x16", "1x1", "4x5", "16x9"]
LANGS = ["en", "fr"]
NPX = "npx.cmd" if os.name == "nt" else "npx"


def shots(film):
    """(start, length) in frames of each shot of a film, read from ad26/films.tsx (the [start s, length s, <element>] rows)."""
    text = open(FILMS_TSX, encoding="utf8").read()
    name = FUNC.get(film, film)
    m = re.search(r"const %s = \(\): Shot\[\] =>(.*?)(?=\nconst \w+ = \(\): Shot\[\]|\nconst SHOTS)" % name, text, re.S)
    rows = re.findall(r"\[\s*([\d.]+),\s*([\d.]+),\s*(?:<|profile\()", m.group(1))
    return [(round(float(a) * 60), round(float(b) * 60)) for a, b in rows]


def index_kit():
    """Writes src/ad26/available.json (what exists in public/kit and public/kit2026/<lang>) in the repo and in the work folder."""
    pub = os.path.join(WORK, "public")

    def names(d):
        return sorted(f[:-4] for f in os.listdir(d) if f.endswith(".png")) if os.path.isdir(d) else []

    data = {"kit": names(os.path.join(pub, "kit")), "kit2026": {l: names(os.path.join(pub, "kit2026", l)) for l in ("fr", "en")}}
    for root in (SRC, os.path.join(WORK, "src")):
        os.makedirs(os.path.join(root, "ad26"), exist_ok=True)
        json.dump(data, open(os.path.join(root, "ad26", "available.json"), "w"))
    return data


def check_assets():
    """Capture names asked by ad26/*.tsx (string literals of kit-like names) that no kit has: to capture."""
    data = index_kit()
    have = set(data["kit"]) | set(data["kit2026"]["fr"]) | set(data["kit2026"]["en"])
    asked = set()
    for fn in os.listdir(os.path.join(SRC, "ad26")):
        if fn.endswith(".tsx"):
            t = open(os.path.join(SRC, "ad26", fn), encoding="utf8").read()
            asked |= set(re.findall(r'(?:name|wall|lock|scr)(?:=|:|\()\s*\{?"([a-zA-Z0-9-]+)"', t))
            asked |= set(re.findall(r'\bscr\("([a-zA-Z0-9-]+)"\)', t))
            asked |= set(re.findall(r'name: "([a-zA-Z0-9-]+)"', t))
    asked = {a for a in asked if re.match(r"^(app|home|lock|scan|studio|macros|calories|nextSet|budgetLeft|priorities|weekView|timetable|habits|habitStreak|todaysWorkout|trainingStreak|upNext|spendingByCategory|quickSpend|quickFood|wall|myday|mywidgets|nutrition|live|icons|setup|demo)", a)}
    for a in sorted(asked - have):
        print("missing:", a)
    new = {l: len(data["kit2026"][l]) for l in ("fr", "en")}
    print(f"{len(asked)} names asked, {len(asked - have)} missing; kit2026: {new}")


def run(args):
    r = subprocess.run([NPX, "remotion"] + args, cwd=WORK)
    if r.returncode:
        sys.exit(f"remotion {args[0]} failed ({r.returncode})")


def bundle():
    out = os.path.join(WORK, "out", "bundle")
    subprocess.run([NPX, "remotion", "bundle", "src/index.ts", f"--out-dir={out}"], cwd=WORK, check=True, stdout=subprocess.DEVNULL)
    return out


def audio_for(film, lang):
    """audio props of a render: (audioLang, audio?)."""
    if os.path.exists(os.path.join(WORK, "public", "audio", lang, f"mix-{film}.wav")):
        return lang, True
    print(f"  ! no voice-over for {lang} ({film}): silent render")
    return lang, False


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("mode", choices=["still", "video", "index", "check"])
    ap.add_argument("target", nargs="?", default="all")
    ap.add_argument("--format", default="9x16")
    ap.add_argument("--lang", default="en")
    ap.add_argument("--out", default=None)
    ap.add_argument("--shot", type=int, help="still: only this shot (0-based)")
    a = ap.parse_args()
    if a.mode == "index":
        d = index_kit()
        print(f"{len(d['kit'])} old-kit captures, kit2026: " + ", ".join(f"{l} {len(v)}" for l, v in d["kit2026"].items()))
        return
    if a.mode == "check":
        check_assets()
        return
    index_kit()
    formats = FORMATS if a.format == "all" else [a.format]
    langs = LANGS if a.lang == "all" else [a.lang]
    films = list(FILMS) if a.target == "all" else [a.target]
    serve = bundle()
    t0 = time.time()
    count = 0
    for film in films:
        comp, frames, folder = FILMS[film]
        out_dir = os.path.join(REPO, "pub", "film2026", a.out or folder)
        os.makedirs(os.path.join(out_dir, "stills"), exist_ok=True)
        for fmt in formats:
            for lang in langs:
                audio_lang, has_audio = audio_for(film, lang)
                if a.mode == "still":
                    props = json.dumps({"format": fmt, "lang": lang, "audioLang": audio_lang, "audio": False})
                    for i, (start, length) in enumerate(shots(film)):
                        if a.shot is not None and i != a.shot:
                            continue
                        frame = min(frames - 1, start + length // 2)
                        png = os.path.join(out_dir, "stills", f"{film}-{fmt}-{lang}-f{frame}.png")
                        run(["still", serve, comp, png, f"--frame={frame}", f"--props={props}"])
                        count += 1
                else:
                    props = json.dumps({"format": fmt, "lang": lang, "audioLang": audio_lang, "audio": has_audio})
                    mp4 = os.path.join(out_dir, f"{film}-{fmt}-{lang}.mp4")
                    run(["render", serve, comp, mp4, f"--props={props}", "--image-format=png", "--crf=16", "--color-space=bt709"])
                    count += 1
    print(f"{count} render(s) in {time.time() - t0:.0f} s")


if __name__ == "__main__":
    main()
