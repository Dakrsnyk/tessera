"""Mixage son d'une pub de la campagne 2026-11 (une pub par mini-app + vidéos générales) : musique Pixabay, voix off
Kokoro (vo.py), sons d'interface. Tout est décrit dans un JSON ; sortie WAV 48 kHz stéréo, -14 LUFS, crête -1 dBFS.

    ~/ardane-tools/venv/Scripts/python.exe scripts/ad2/campaign_mix.py <config.json>

config.json :
{
  "length": 34.5,                       # durée du film (s)
  "out": "C:/.../public/campaign/nutrition/mix.wav",
  "music": {"file": "....mp3", "start": 12.0,   # seconde du morceau jouée à t = 0 du film
            "tempo": 1.0,                       # facteur atempo (1 = intact ; 120/124 pour ramener 124 à 120 BPM)
            "fade_in": 0.3, "fade_out": 1.8,    # fondus (s) ; la musique finit à `length`
            "gain_db": 0, "duck_db": -9},       # gain ; baisse sous la voix (s'il y a des voix)
  "vo": [{"file": ".../nutrition-N1.wav", "at": 2.4}, ...],   # voix posées à `at` (s)
  "sfx": [{"name": "tap", "at": 3.2}, {"name": "whoosh", "at": 10.0}, ...]   # tap, check, whoosh, swoosh, glass, logo
}
Les sons : tap (toucher d'écran), check (coche), whoosh (souffle 0,3 s), swoosh (souffle 0,6 s), glass (note de verre),
logo (signature Ardane ré5 + la5, la même que les autres pubs).
"""
import json
import os
import subprocess
import sys

import numpy as np
import pyloudnorm as pyln
import soundfile as sf

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import mix as M
import synth as S
from synth import SR, db, fm_glass, note, reverb


def load(path, tempo=1.0, start=0.0):
    af = f"atempo={tempo:.5f}" if abs(tempo - 1) > 1e-4 else "anull"
    raw = subprocess.run(
        ["ffmpeg", "-v", "error", "-ss", f"{max(0.0, start):.3f}", "-i", path, "-af", af, "-ac", "2", "-ar", str(SR), "-f", "f32le", "-"],
        capture_output=True, check=True,
    ).stdout
    return np.frombuffer(raw, np.float32).reshape(-1, 2).astype(np.float64)


def place(track, sound, at, gain=1.0):
    if sound.ndim == 1:
        sound = np.stack([sound, sound], axis=1)
    i = int(round(at * SR))
    if i < 0:
        sound, i = sound[-i:], 0
    end = min(len(track), i + len(sound))
    if end > i:
        track[i:end] += sound[: end - i] * gain


def sfx_sound(name):
    if name == "tap":
        return M.tap_pulse(), db(-8)
    if name == "check":
        return S.cue_check(), db(-10)
    if name == "whoosh":
        return M.whoosh(0.3, 1000, 6000, seed=61), db(-17)
    if name == "swoosh":
        return M.whoosh(0.6, 600, 4000, seed=7), db(-18)
    if name == "glass":
        return reverb(fm_glass(note("A5"), index=2.0, decay=0.8), 2.0, 0.3), db(-16)
    if name == "logo":
        a = reverb(fm_glass(note("D5"), seconds=1.0, index=4.0, decay=0.32), 3.0, 0.3)
        b = reverb(fm_glass(note("A5"), index=4.0, decay=1.6), 3.0, 0.3)
        out = np.zeros((len(b) + int(0.5 * SR), 2))
        place(out, a, 0)
        place(out, b, 0.5)
        return out, db(-12)
    raise SystemExit(f"son inconnu : {name}")


def main():
    cfg = json.load(open(sys.argv[1], encoding="utf-8"))
    L = float(cfg["length"])
    n = int(round(L * SR))
    t = np.arange(n) / SR
    meter = pyln.Meter(SR)

    voice = np.zeros((n, 2))
    for v in cfg.get("vo", []):
        x, sr = sf.read(v["file"], dtype="float64")
        if x.ndim == 1:
            x = np.stack([x, x], axis=1)
        if sr != SR:
            idx = np.arange(0, len(x), sr / SR)
            x = np.stack([np.interp(idx, np.arange(len(x)), x[:, c]) for c in range(2)], axis=1)
        place(voice, x, float(v["at"]), db(v.get("gain_db", 0)))
    has_voice = np.max(np.abs(voice)) > 0

    m = cfg["music"]
    x = load(m["file"], m.get("tempo", 1.0), m.get("start", 0.0))
    music = np.zeros((n, 2))
    music[: min(n, len(x))] = x[:n]
    fi, fo = m.get("fade_in", 0.3), m.get("fade_out", 1.8)
    env = np.interp(t, [0, fi, max(fi, L - fo - 0.3), L - 0.3, L], [0, 1, 1, 0, 0])
    if has_voice:
        # baisse sous la voix : enveloppe de la voix lissée (attaque 80 ms, relâche 400 ms)
        lvl = np.abs(voice).max(axis=1) > db(-40)
        k = int(0.08 * SR)
        on = np.convolve(lvl.astype(float), np.ones(k) / k, "same") > 0
        r = int(0.4 * SR)
        hold = np.convolve(on.astype(float), np.ones(r), "full")[:n] > 0
        g = np.where(hold, db(m.get("duck_db", -9)), 1.0)
        a = int(0.06 * SR)
        g = np.convolve(g, np.ones(a) / a, "same")
        env = env * g
    music *= env[:, None] * db(m.get("gain_db", 0))
    if np.max(np.abs(music)) > 0:
        music = pyln.normalize.loudness(music, meter.integrated_loudness(music), -17.0 if has_voice else -15.0)
    if has_voice:
        voice = pyln.normalize.loudness(voice, meter.integrated_loudness(voice), -15.0)

    fx = np.zeros((n, 2))
    for s in cfg.get("sfx", []):
        snd, gain = sfx_sound(s["name"])
        place(fx, snd, float(s["at"]), gain * db(s.get("gain_db", 0)))

    mixdown = music + voice + fx * db(-4)
    mixdown = pyln.normalize.loudness(mixdown, meter.integrated_loudness(mixdown), -14.0)
    mixdown = np.tanh(mixdown / db(-1)) * db(-1)
    os.makedirs(os.path.dirname(cfg["out"]), exist_ok=True)
    sf.write(cfg["out"], mixdown.astype(np.float32), SR, subtype="PCM_24")
    print(cfg["out"], f"{L:.2f} s", f"{meter.integrated_loudness(mixdown):.1f} LUFS", "voix" if has_voice else "sans voix")


if __name__ == "__main__":
    main()
