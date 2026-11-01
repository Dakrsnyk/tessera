"""Finds, for lines Kokoro reads badly or too slowly, the pace (and pause between sentences) that Whisper
understands and that fits the line's slot; writes the result into vo2026_overrides.json (read by vo.py / vo_fr.py).

    venv/Scripts/python -I -X utf8 vo_tune.py <en|fr> <film> <id> [<id> ...] [--write]

Each candidate is a solo synthesis (the same path as the "solo" override in vo.py / vo_fr.py), checked by ASR.
Cost = 10 x word error rate + 5 if over the slot + 2 x |speed - 0.95| (the natural pace is preferred) +
0.5 if the line is cut short (fewer words heard than written).
"""
import json, os, re, sys, unicodedata
import numpy as np
import soundfile as sf

HERE = os.path.dirname(os.path.abspath(__file__))
lang, film, ids = sys.argv[1], sys.argv[2], [a for a in sys.argv[3:] if not a.startswith("--")]
write = "--write" in sys.argv
spec = json.load(open(os.path.join(HERE, "..", "ad3", "spec", f"vo_spec_{lang}.json"), encoding="utf-8"))
voice, base_speed, brand = spec["voice"], spec.get("speed", 0.95), spec.get("brand", {})
SR = 24000
lines = {l["id"]: l for c in spec["films"][film]["chunks"] for l in c}

from kokoro import KPipeline
pipe = KPipeline(lang_code="a" if lang == "en" else "f", repo_id="hexgrad/Kokoro-82M")
from faster_whisper import WhisperModel
asr = WhisperModel("small.en" if lang == "en" else "small", device="cpu", compute_type="int8",
                   download_root=os.environ.get("ARDANE_HF_CACHE"))


def tts_text(text):
    if lang == "en":
        for word, ipa in brand.items():
            text = re.sub(rf"\b{word}\b", f"[{word}](/{ipa}/)", text)
    return text


def synth(text, speed):
    parts = [r.audio.numpy() for r in pipe(tts_text(text), voice=voice, speed=speed)]
    return np.concatenate(parts) if parts else np.zeros(1)


def trim(audio, floor_db=-50, pad_ms=30):
    hop = SR // 200
    env = np.array([np.abs(audio[i:i + hop]).max() for i in range(0, len(audio), hop)])
    db = 20 * np.log10(env / (env.max() + 1e-12) + 1e-12)
    loud = np.where(db > floor_db)[0]
    if len(loud) == 0:
        return audio
    return audio[max(0, loud[0] * hop - pad_ms * SR // 1000):min(len(audio), (loud[-1] + 1) * hop + pad_ms * SR // 1000)]


def render(text, speed, pause):
    if pause:
        sentences = [t for t in re.split(r"(?<=[.?!])\s+", text) if t]
        gap = np.zeros(int(pause * SR), dtype=np.float32)
        return np.concatenate([x for t in sentences for x in (trim(synth(t, speed)), gap)][:-1])
    return trim(synth(text, speed))


def norm(s):
    s = unicodedata.normalize("NFD", s.lower().replace("’", "'"))
    s = "".join(c for c in s if unicodedata.category(c) != "Mn")
    return re.sub(r"[^a-z0-9 ]", " ", s).split()


def wer(ref_text, hyp_text):
    ref = [w for w in norm(ref_text) if w not in [b.lower() for b in brand]]
    got = [w for w in norm(hyp_text) if not w.startswith("ard") and w != "hardan"]
    d = np.zeros((len(ref) + 1, len(got) + 1), dtype=int)
    d[:, 0] = range(len(ref) + 1); d[0, :] = range(len(got) + 1)
    for i in range(1, len(ref) + 1):
        for j in range(1, len(got) + 1):
            d[i, j] = min(d[i - 1, j] + 1, d[i, j - 1] + 1, d[i - 1, j - 1] + (ref[i - 1] != got[j - 1]))
    return d[-1, -1] / max(1, len(ref)), len(got) < len(ref)


def hear(audio):
    a16 = np.interp(np.arange(0, len(audio), SR / 16000), np.arange(len(audio)), audio).astype(np.float32)
    segs, _ = asr.transcribe(a16, language=lang, beam_size=5)
    return " ".join(s.text.strip() for s in segs)


best_all = {}
for lid in ids:
    line = lines[lid]
    multi = len(re.split(r"(?<=[.?!])\s+", line["text"])) > 1
    results = []
    for speed in (0.85, 0.9, 0.95, 1.0, 1.05, 1.1, 1.15):
        for pause in ([None, 0.2, 0.35] if multi else [None]):
            audio = render(line["text"], speed, pause)
            dur = len(audio) / SR
            hyp = hear(audio)
            w, short = wer(line["text"], hyp)
            cost = 10 * w + (5 if dur > line["max"] else 0) + 2 * abs(speed - 0.95) + (0.5 if short else 0) + (0.1 if pause else 0)
            results.append((cost, speed, pause, dur, w, hyp))
    results.sort(key=lambda r: r[0])
    print(f"== {film} {lid} « {line['text']} » (slot {line['max']} s)")
    for cost, speed, pause, dur, w, hyp in results[:3]:
        print(f"   cost {cost:.2f}  speed {speed}  pause {pause}  {dur:.2f} s  wer {w:.2f}  « {hyp} »")
    cost, speed, pause, dur, w, hyp = results[0]
    best_all[lid] = {"solo": True, "speed": speed, **({"pause": pause} if pause else {})}

print(json.dumps({lang: {film: best_all}}, ensure_ascii=False))
if write:
    path = os.path.join(HERE, "vo2026_overrides.json")
    data = json.load(open(path, encoding="utf-8"))
    data.setdefault(lang, {}).setdefault(film, {}).update(best_all)
    json.dump(data, open(path, "w", encoding="utf-8"), indent=1, ensure_ascii=False)
