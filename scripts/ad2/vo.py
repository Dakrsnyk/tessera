"""English voice-over of the Ardane films with Kokoro-82M (Apache-2.0), one WAV per line.

Kokoro is weak on very short utterances, so lines are synthesised in chunks (a few lines read as
one text) and cut back into lines at the chunk's longest silences. Each line is checked by ASR
(faster-whisper small.en): text and word timings (for the typography) go to <out>/<film>.json.

    venv312/bin/python -I vo.py <spec.json> <film> <out dir>
    Windows: ~/ardane-tools/venv/Scripts/python -I -X utf8 vo.py ...  (see scripts/ad2/README.md)
"""
import json, os, re, sys
import numpy as np
import soundfile as sf

spec_path, film, out = sys.argv[1:4]
spec = json.load(open(spec_path, encoding="utf-8"))
cfg = spec["films"][film]
voice = cfg.get("voice", spec.get("voice", "af_heart"))
speed = cfg.get("speed", spec.get("speed", 0.95))
brand = spec.get("brand", {})
os.makedirs(out, exist_ok=True)
SR = 24000

from kokoro import KPipeline
pipe = KPipeline(lang_code="a", repo_id="hexgrad/Kokoro-82M")


def tts_text(text):
    # « Ardane » said ar-DAHN: misaki's inline IPA override.
    for word, ipa in brand.items():
        text = re.sub(rf"\b{word}\b", f"[{word}](/{ipa}/)", text)
    return text


def synth(text):
    parts = [r.audio.numpy() for r in pipe(tts_text(text), voice=voice, speed=speed)]
    return np.concatenate(parts) if parts else np.zeros(1)


def silences(audio, floor_db=-42, min_ms=110):
    """Silent runs (start, end) in samples, quieter than floor_db below the chunk's peak."""
    hop = SR // 100
    frames = len(audio) // hop
    rms = np.array([np.sqrt(np.mean(audio[i * hop:(i + 1) * hop] ** 2) + 1e-12) for i in range(frames)])
    db = 20 * np.log10(rms / (rms.max() + 1e-12))
    quiet = db < floor_db
    runs, start = [], None
    for i, q in enumerate(quiet):
        if q and start is None:
            start = i
        if (not q or i == len(quiet) - 1) and start is not None:
            end = i if not q else i + 1
            if (end - start) * 10 >= min_ms:
                runs.append((start * hop, end * hop))
            start = None
    return runs


def trim(audio, floor_db=-50, pad_ms=30):
    hop = SR // 200
    env = np.array([np.abs(audio[i:i + hop]).max() for i in range(0, len(audio), hop)])
    db = 20 * np.log10(env / (env.max() + 1e-12) + 1e-12)
    loud = np.where(db > floor_db)[0]
    if len(loud) == 0:
        return audio
    a = max(0, loud[0] * hop - pad_ms * SR // 1000)
    b = min(len(audio), (loud[-1] + 1) * hop + pad_ms * SR // 1000)
    return audio[a:b]


lines_out = []
for chunk in cfg["chunks"]:
    ids = [line["id"] for line in chunk]
    text = " ".join(line["text"] for line in chunk)
    audio = synth(text)
    pieces = [audio]
    if len(chunk) > 1:
        runs = [r for r in silences(audio) if r[0] > SR * 0.3 and r[1] < len(audio) - SR * 0.3]
        # The len-1 longest pauses, back in time order, are the cuts between lines.
        cuts = sorted(sorted(runs, key=lambda r: r[1] - r[0], reverse=True)[:len(chunk) - 1])
        if len(cuts) == len(chunk) - 1:
            bounds = [0] + [(a + b) // 2 for a, b in cuts] + [len(audio)]
            pieces = [audio[bounds[i]:bounds[i + 1]] for i in range(len(chunk))]
        else:
            print("chunk", ids, "could not be split: synthesising its lines one by one")
            pieces = [synth(line["text"]) for line in chunk]
    for line, piece in zip(chunk, pieces):
        piece = trim(piece)
        # Fades of 8 ms: no click at the cut.
        n = int(0.008 * SR)
        piece[:n] *= np.linspace(0, 1, n)
        piece[-n:] *= np.linspace(1, 0, n)
        path = os.path.join(out, f"{film}-{line['id']}.wav")
        sf.write(path, piece.astype(np.float32), SR, subtype="FLOAT")
        lines_out.append({**line, "file": path, "duration": round(len(piece) / SR, 3)})
        print(f"{film} {line['id']}: {len(piece) / SR:.2f} s (slot {line.get('max', '?')} s)  {line['text']}")

# ASR check and word timings.
from faster_whisper import WhisperModel
# ARDANE_HF_CACHE keeps the model (~500 MB) out of the repository (and of the Obsidian vault).
asr = WhisperModel("small.en", device="cpu", compute_type="int8",
                   download_root=os.environ.get("ARDANE_HF_CACHE") or os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools", "hf_cache"))
norm = lambda s: re.sub(r"[^a-z0-9' ]", " ", s.lower()).split()
for line in lines_out:
    # Samples at 16 kHz rather than the path: recent PyAV no longer takes faster-whisper's decode arguments.
    audio, sr = sf.read(line["file"], dtype="float32")
    audio16 = np.interp(np.arange(0, len(audio), sr / 16000), np.arange(len(audio)), audio).astype(np.float32)
    segments, _ = asr.transcribe(audio16, word_timestamps=True, language="en", beam_size=5)
    words = [w for s in segments for w in s.words]
    hyp = " ".join(w.word.strip() for w in words)
    ref = [w for w in norm(line["text"]) if w not in [b.lower() for b in brand]]
    got = [w for w in norm(hyp) if not w.startswith("ard")]
    # Word error rate without the brand name (what ASR spells « Ardaan », « Ardhan »…).
    d = np.zeros((len(ref) + 1, len(got) + 1), dtype=int)
    d[:, 0] = range(len(ref) + 1); d[0, :] = range(len(got) + 1)
    for i in range(1, len(ref) + 1):
        for j in range(1, len(got) + 1):
            d[i, j] = min(d[i - 1, j] + 1, d[i, j - 1] + 1, d[i - 1, j - 1] + (ref[i - 1] != got[j - 1]))
    line["asr"] = hyp
    line["wer"] = round(d[-1, -1] / max(1, len(ref)), 3)
    line["words"] = [{"w": w.word.strip(), "start": round(w.start, 3), "end": round(w.end, 3)} for w in words]
    print(f"ASR {line['id']}: wer {line['wer']}  « {hyp} »")
json.dump({"film": film, "voice": voice, "speed": speed, "sr": SR, "lines": lines_out}, open(os.path.join(out, f"{film}.json"), "w", encoding="utf-8"), indent=1)
