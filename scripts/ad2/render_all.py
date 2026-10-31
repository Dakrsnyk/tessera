"""Renders a film of the campaign in a format and a language (Remotion, 60 fps), from ~/ardane-tools/film.

    python -X utf8 scripts/ad2/render_all.py still  <film|all> [--format 4x5|all] [--lang fr|all] [--out NAME]
    python -X utf8 scripts/ad2/render_all.py video  <film|all> [--format 4x5|all] [--lang fr|all] [--out NAME]
    python -X utf8 scripts/ad2/render_all.py scene  <Scene>    [--format ...] [--lang ...] [--frame N]

films: main s30 s15 s8 fitness nutrition perso. Formats: 9x16 1x1 4x5 16x9. Languages: en fr.
- still: one image per segment of the film (at its middle), to check every scene before a full render.
- video: the whole film (H.264, CRF 16, BT.709). LONG: measure with `still` first (see the time per image).
- scene: stills of one scene (a frame, default its last one) for quick checks of layout.
Output: pub/film2026/<OUT>/ (OUT defaults to "default"; pub/ is ignored by Git):
  <film>-<format>-<lang>.mp4 and stills/<film>-<format>-<lang>-f<frame>.png.
The voice-over of a language is public/audio/<lang>/mix-<film>.wav; until it exists the English mix plays (warned).
The sources must be synchronised first: python -X utf8 scripts/ad2/film_sync.py import
"""
import argparse
import json
import os
import subprocess
import sys
import time

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
WORK = os.path.join(os.path.expanduser("~"), "ardane-tools", "film")
CUTS = os.path.join(REPO, "scripts", "ad2", "film", "src", "films", "cuts.json")
COMP = {"main": "MainFilm", "s30": "Film30", "s15": "Film15", "s8": "Film8", "fitness": "FilmFitness", "nutrition": "FilmNutrition", "perso": "FilmPerso"}
SCENE_LENGTH = {"Opening": 360, "Universes": 600, "Studio": 360, "Fitness": 600, "LockScreen": 360, "Nutrition": 600, "Daylight": 90, "Essentials": 360, "Gather": 300, "Close": 300}
FORMATS = ["9x16", "1x1", "4x5", "16x9"]
LANGS = ["en", "fr"]
NPX = "npx.cmd" if os.name == "nt" else "npx"


def run(args):
    r = subprocess.run([NPX, "remotion"] + args, cwd=WORK)
    if r.returncode:
        sys.exit(f"remotion {args[0]} failed ({r.returncode})")


def bundle():
    out = os.path.join(WORK, "out", "bundle")
    subprocess.run([NPX, "remotion", "bundle", "src/index.ts", f"--out-dir={out}"], cwd=WORK, check=True, stdout=subprocess.DEVNULL)
    return out


def audio_lang(film, lang):
    if lang == "en" or os.path.exists(os.path.join(WORK, "public", "audio", lang, f"mix-{film}.wav")):
        return lang
    print(f"  ! no voice-over for {lang} ({film}): the English mix plays")
    return "en"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("mode", choices=["still", "video", "scene"])
    ap.add_argument("target")
    ap.add_argument("--format", default="9x16")
    ap.add_argument("--lang", default="en")
    ap.add_argument("--out", default="default")
    ap.add_argument("--frame", type=int)
    a = ap.parse_args()
    formats = FORMATS if a.format == "all" else [a.format]
    langs = LANGS if a.lang == "all" else [a.lang]
    out_dir = os.path.join(REPO, "pub", "film2026", a.out)
    os.makedirs(os.path.join(out_dir, "stills"), exist_ok=True)
    cuts = json.load(open(CUTS, encoding="utf8"))["films"]
    films = list(COMP) if a.target == "all" else [a.target]
    serve = bundle()
    t0 = time.time()
    count = 0
    for fmt in formats:
        for lang in langs:
            if a.mode == "scene":
                frame = a.frame if a.frame is not None else SCENE_LENGTH[a.target] - 1
                png = os.path.join(out_dir, "stills", f"{a.target}-{fmt}-{lang}-f{frame}.png")
                run(["still", serve, a.target, png, f"--frame={frame}", f"--props={json.dumps({'format': fmt, 'lang': lang})}"])
                count += 1
                continue
            for film in films:
                props = json.dumps({"format": fmt, "lang": lang, "audioLang": audio_lang(film, lang)})
                if a.mode == "still":
                    for seg in cuts[film]["segments"]:
                        length = seg["input"][-1]
                        frame = min(cuts[film]["length"] - 1, seg["at"] + length // 2)
                        png = os.path.join(out_dir, "stills", f"{film}-{fmt}-{lang}-f{frame}.png")
                        run(["still", serve, COMP[film], png, f"--frame={frame}", f"--props={props}"])
                        count += 1
                else:
                    mp4 = os.path.join(out_dir, f"{film}-{fmt}-{lang}.mp4")
                    run(["render", serve, COMP[film], mp4, f"--props={props}", "--image-format=png", "--crf=16", "--color-space=bt709"])
                    count += 1
    print(f"{count} render(s) in {time.time() - t0:.0f} s -> {out_dir}")


if __name__ == "__main__":
    main()
