"""French voice-over of the Ardane films with Kokoro-82M (Apache-2.0), voice ff_siwis, one WAV per line.

Same pipeline and JSON shape as vo.py (spec: vo_fr_spec.json). Differences: lang_code "f", the
ASR is the multilingual faster-whisper "small" in French, and « Ardane » needs no override: misaki's
espeak French front end already reads it /aʁdˈan/ (ar-DANE). An inline IPA override like the English
one is NOT supported there (the IPA is spelt out letter by letter), and the spellings « Ardanne »,
« Ar-dane », « Ardann » give the same or a worse phoneme string: keep the plain spelling.


Kokoro is weak on very short utterances, so lines are synthesised in chunks (a few lines read as
one text) and cut back into lines at the chunk's longest silences. Each line is checked by ASR
(faster-whisper small.en): text and word timings (for the typography) go to <out>/<film>.json.

    venv312/bin/python -I vo_fr.py <spec.json> <film> <out dir>
    Windows: ~/ardane-tools/venv/Scripts/python -I -X utf8 vo.py ...  (see scripts/ad2/README.md)
"""
import itertools, json, os, re, sys
import numpy as np
import soundfile as sf

spec_path, film, out = sys.argv[1:4]
spec = json.load(open(spec_path, encoding="utf-8"))
cfg = spec["films"][film]
voice = cfg.get("voice", spec.get("voice", "ff_siwis"))
speed = cfg.get("speed", spec.get("speed", 0.95))
brand = spec.get("brand", {})
# Per-line fixes for the 2026 campaign (speed, pause, solo), vo2026_overrides.json: {lang: {film: {id: {...}}}}.
_ov_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "vo2026_overrides.json")
if os.path.exists(_ov_path):
    _ov = json.load(open(_ov_path, encoding="utf-8")).get("fr", {}).get(film, {})
    for _chunk in cfg["chunks"]:
        for _line in _chunk:
            _line.update(_ov.get(_line["id"], {}))
os.makedirs(out, exist_ok=True)
SR = 24000

from kokoro import KPipeline
pipe = KPipeline(lang_code=spec.get("lang", "f"), repo_id="hexgrad/Kokoro-82M")


def tts_text(text):
    # French: the plain spelling is read correctly (see the docstring).
    return text


def synth(text, speed=speed):
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


def pick_cuts(audio, weights):
    """Silent runs that split audio into len(weights) parts: the pauses nearest to where the text
    says the boundaries are (characters read at an even pace), a long pause winning over a near one
    only when it is much longer. Inside a line (« Set done? Tap it… ») a pause can be longer than
    the one between lines: the longest pauses alone cut at the wrong place."""
    runs = [r for r in silences(audio) if r[0] > SR * 0.3 and r[1] < len(audio) - SR * 0.3]
    k = len(weights) - 1
    if len(runs) < k:
        return None
    total, acc, expected = sum(weights), 0, []
    for w in weights[:-1]:
        acc += w
        expected.append(len(audio) * acc / total)
    best, best_score = None, -1
    for combo in itertools.combinations(runs, k):
        score = sum((b - a) / (1 + ((a + b) / 2 - e) ** 2 / (0.12 * len(audio)) ** 2)
                    for (a, b), e in zip(combo, expected))
        if score > best_score:
            best, best_score = combo, score
    return list(best)


def beats(text, pause, spd=speed):
    """A line made of short beats (« Your meals. Your workout. What's due. Your week. »): Kokoro reads
    it in one breath, with no pause to lengthen, so each sentence is synthesised alone and the beats
    are joined by `pause` s of silence (one beat per card on screen)."""
    sentences = [t for t in re.split(r"(?<=[.?!])\s+", text) if t]
    gap = np.zeros(int(pause * SR), dtype=np.float32)
    return np.concatenate([x for t in sentences for x in (trim(synth(t, spd)), gap)][:-1])


lines_out = []
for chunk in cfg["chunks"]:
    ids = [line["id"] for line in chunk]
    text = " ".join(line["text"] for line in chunk)
    audio = synth(text, chunk[0].get("speed", speed))  # "speed" on a line: Kokoro is erratic on short French lines, another pace often fixes it
    pieces = [audio]
    if len(chunk) > 1 and any(line.get("solo") for line in chunk):
        pieces = [synth(line["text"], line.get("speed", speed)) for line in chunk]
    elif len(chunk) > 1:
        cuts = pick_cuts(audio, [len(line["text"]) for line in chunk])
        if cuts:
            bounds = [0] + [(a + b) // 2 for a, b in cuts] + [len(audio)]
            pieces = [audio[bounds[i]:bounds[i + 1]] for i in range(len(chunk))]
        else:
            print("chunk", ids, "could not be split: synthesising its lines one by one")
            pieces = [synth(line["text"], line.get("speed", speed)) for line in chunk]
    for line, piece in zip(chunk, pieces):
        piece = beats(line["text"], line["pause"], line.get("speed", speed)) if line.get("pause") else trim(piece)
        # Fades of 8 ms: no click at the cut.
        n = int(0.008 * SR)
        piece[:n] *= np.linspace(0, 1, n)
        piece[-n:] *= np.linspace(1, 0, n)
        path = os.path.join(out, f"{film}-{line['id']}.wav")
        sf.write(path, piece.astype(np.float32), SR, subtype="FLOAT")
        lines_out.append({**line, "file": path, "duration": round(len(piece) / SR, 3), "fits": bool(len(piece) / SR <= line.get("max", 99))})
        line["fits"] = bool(len(piece) / SR <= line.get("max", 99))
        print(f"{film} {line['id']}: {len(piece) / SR:.2f} s{'' if line['fits'] else '  ** OVER SLOT **'} (slot {line.get('max', '?')} s)  {line['text']}")

# ASR check and word timings.
from faster_whisper import WhisperModel
# ARDANE_HF_CACHE keeps the model (~500 MB) out of the repository.
asr = WhisperModel("small", device="cpu", compute_type="int8",
                   download_root=os.environ.get("ARDANE_HF_CACHE") or os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools", "hf_cache"))
import unicodedata
def norm(s):
    s = unicodedata.normalize("NFD", s.lower().replace("’", "'"))
    s = "".join(c for c in s if unicodedata.category(c) != "Mn")
    return re.sub(r"[^a-z0-9' ]", " ", s).split()
for line in lines_out:
    # Samples at 16 kHz rather than the path: recent PyAV no longer takes faster-whisper's decode arguments.
    audio, sr = sf.read(line["file"], dtype="float32")
    audio16 = np.interp(np.arange(0, len(audio), sr / 16000), np.arange(len(audio)), audio).astype(np.float32)
    segments, _ = asr.transcribe(audio16, word_timestamps=True, language="fr", beam_size=5)
    words = [w for s in segments for w in s.words]
    hyp = " ".join(w.word.strip() for w in words)
    ref = [w for w in norm(line["text"]) if w not in [b.lower() for b in brand]]
    got = [w for w in norm(hyp) if not w.startswith("ard")]  # ASR spells the brand « Ardanne », « Ardenne »…
    # Word error rate without the brand name (what ASR spells « Ardanne », « Ardenne »…).
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
