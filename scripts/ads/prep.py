"""Turns the CI report (videos/*.mp4, videos/assets/*.png) into the films' assets:
clips/<scene>/%04d.jpg (30 fps), stills/<name>.png (whole screens), pieces/<name>.png (elements cut
out by difference matting: rendered on white then on black), clips.json (frame counts).

    python3 prep.py <report dir> <assets dir>
"""
import glob, json, os, subprocess, sys
import numpy as np
from PIL import Image

report, assets = sys.argv[1:3]
SCENES = {"testVideoLaunch": "launch", "testVideoMonQuotidien": "quotidien", "testVideoPlanning": "planning",
          "testVideoFitness": "fitness", "testVideoNutrition": "nutrition", "testVideoStudio": "studio",
          "testVideoFinances": "finances", "testVideoStore": "store", "testVideoIcons": "icons"}
os.makedirs(assets, exist_ok=True)
info = json.load(open(os.path.join(assets, "clips.json"))) if os.path.exists(os.path.join(assets, "clips.json")) else {"counts": {}, "start": {}}
for test, scene in ([] if "--pieces-only" in sys.argv else SCENES.items()):
    src = os.path.join(report, "videos", test + ".mp4")
    if not os.path.exists(src):
        print("missing", test); continue
    dst = os.path.join(assets, "clips", scene); os.makedirs(dst, exist_ok=True)
    for f in glob.glob(os.path.join(dst, "*.jpg")): os.remove(f)
    subprocess.check_call(["ffmpeg", "-hide_banner", "-loglevel", "error", "-y", "-i", src, "-vf", "fps=30,scale=1206:-2:flags=lanczos", "-q:v", "2", os.path.join(dst, "%04d.jpg")])
    info["counts"][scene] = len(glob.glob(os.path.join(dst, "*.jpg")))
    info["start"].setdefault(scene, 0)
json.dump(info, open(os.path.join(assets, "clips.json"), "w"), indent=1)

pieces = os.path.join(assets, "pieces"); stills = os.path.join(assets, "stills")
os.makedirs(pieces, exist_ok=True); os.makedirs(stills, exist_ok=True)
for f in glob.glob(os.path.join(report, "videos", "assets", "*.png")):
    name = os.path.basename(f)[:-4]
    if name.endswith("-black"): continue
    if name.endswith("-white"):
        base = name[:-6]
        w = np.asarray(Image.open(f).convert("RGB")).astype(np.float32)
        b = np.asarray(Image.open(f[:-10] + "-black.png").convert("RGB")).astype(np.float32)
        a = 1 - np.clip((w - b).max(axis=2) / 255.0, 0, 1)
        # The simulator's screen around the piece: its Dynamic Island (black on both grounds) and
        # the last rows are not part of it.
        a[:200] = 0; a[-6:] = 0
        a[a < 0.05] = 0  # the faint ground left around a piece
        rgb = np.where(a[..., None] > 0.004, np.clip(b / np.maximum(a[..., None], 1e-3), 0, 255), 0)
        img = Image.fromarray(np.dstack([rgb, a * 255]).astype(np.uint8), "RGBA")
        box = Image.fromarray((a * 255).astype(np.uint8)).point(lambda v: 255 if v > 6 else 0).getbbox()
        if box:
            m = 40
            img = img.crop((max(0, box[0] - m), max(0, box[1] - m), min(img.width, box[2] + m), min(img.height, box[3] + m)))
        img.save(os.path.join(pieces, base + ".png"))
    else:
        Image.open(f).convert("RGB").save(os.path.join(stills, name + ".png"))
print(json.dumps(info["counts"]))
print("pieces:", sorted(os.listdir(pieces)))
print("stills:", sorted(os.listdir(stills)))
