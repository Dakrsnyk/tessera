"""Voice of the TikTok ads (chantier 19.15): the same voice as the base ads (Kokoro af_heart, speed 1.0, Ardane = ar-DAHN).

    ~/ardane-tools/venv/Scripts/python -I -X utf8 scripts/ad4/tiktok/vo_tiktok.py <ad id> [<ad id> ...]

Reads the lines of each ad in scripts/ad4/tiktok/vo_lines.json, synthesises each line once (cache by text), passes it
through the voice chain of the base ads (scripts/ad2/mix.py: high-pass, presence, 3:1 compression, short room) and writes
  ~/ardane-tools/film/public/tiktok/vo/<id>-<line>.wav   (what Remotion plays)
  scripts/ad4/tiktok/vo/<id>.json                        (each line's length in seconds, read by specs.ts)
"""
import hashlib
import json
import os
import re
import sys

import numpy as np
import soundfile as sf

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
AD2 = os.path.join(ROOT, "scripts", "ad2")
SPEC_EN = os.path.join(ROOT, "scripts", "ad3", "spec", "vo_spec_en.json")
WORK = os.path.join(os.path.expanduser("~"), "ardane-tools", "film", "public", "tiktok", "vo")
CACHE = os.path.join(WORK, "_cache")
SR = 24000


def trim(a, floor_db=-50, pad_ms=30):
    hop = SR // 200
    env = np.array([np.abs(a[k:k + hop]).max() for k in range(0, len(a), hop)])
    dbs = 20 * np.log10(env / (env.max() + 1e-12) + 1e-12)
    loud = np.where(dbs > floor_db)[0]
    if len(loud) == 0:
        return a
    return a[max(0, loud[0] * hop - pad_ms * SR // 1000):min(len(a), (loud[-1] + 1) * hop + pad_ms * SR // 1000)]


def main(ads):
    base = json.load(open(SPEC_EN, encoding="utf-8"))
    voice, brand = base["voice"], base.get("brand", {})
    lines = json.load(open(os.path.join(HERE, "vo_lines.json"), encoding="utf-8"))
    os.makedirs(CACHE, exist_ok=True)
    os.makedirs(os.path.join(HERE, "vo"), exist_ok=True)

    from kokoro import KPipeline
    pipe = KPipeline(lang_code="a", repo_id="hexgrad/Kokoro-82M")
    sys.path.insert(0, AD2)
    import mix as M  # voice_chain of the base ads (works at mix.SR)
    from scipy.signal import resample_poly

    def tts_text(text):
        for w, ipa in brand.items():
            text = re.sub(rf"\b{w}\b", f"[{w}](/{ipa}/)", text)
        return text

    for ad in ads:
        out = {}
        for lid, text in lines[ad].items():
            key = hashlib.md5(f"{voice}|{text}".encode()).hexdigest()[:12]
            raw = os.path.join(CACHE, key + ".wav")
            if not os.path.exists(raw):
                parts = [r.audio.numpy() for r in pipe(tts_text(text), voice=voice, speed=1.0)]
                a = trim(np.concatenate(parts))
                n = int(0.008 * SR)
                a[:n] *= np.linspace(0, 1, n)
                a[-n:] *= np.linspace(1, 0, n)
                sf.write(raw, a.astype(np.float32), SR, subtype="FLOAT")
            a, sr = sf.read(raw, dtype="float64")
            y = M.voice_chain(resample_poly(a, M.SR, sr))
            y = y.mean(1) if y.ndim > 1 else y
            y = y / (np.abs(y).max() + 1e-9) * 0.89  # peak -1 dBFS; the mix in Remotion sets the level
            sf.write(os.path.join(WORK, f"{ad}-{lid}.wav"), y.astype(np.float32), M.SR, subtype="FLOAT")
            out[lid] = round(len(a) / sr, 3)
            print(f"{ad} {lid} {out[lid]:.2f}s  {text}", flush=True)
        json.dump(out, open(os.path.join(HERE, "vo", f"{ad}.json"), "w", encoding="utf-8"), indent=1)


if __name__ == "__main__":
    main(sys.argv[1:])
