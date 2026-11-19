"""Son de la pub « IRL » Fitness (2026-11-18) : beat trap / phonk sombre à 120 BPM (un temps = 30 images à 60 i/s, la grille
de ~/ardane-tools/film/src/irl/IrlFitness.tsx), sons de l'interface (tap sur « Set done », passages d'écran), signature
Ardane sur la carte finale. Tout est synthétisé ici (aucun son externe). Sortie : public/irl/fitness/mix.wav du projet film,
-14 LUFS, crête -1 dBFS.

Usage : python scripts/ad2/irl_audio.py [dossier_film]   (défaut : ~/ardane-tools/film)
"""
import os
import sys

import numpy as np
import pyloudnorm as pyln
import soundfile as sf

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import mix as M
import synth as S
from synth import SR, db, fm_glass, note, reverb

FPS = 60
BEAT = 0.5  # 120 BPM
LENGTH = 1640 / FPS  # IRL_LENGTH
DROP = 2.0  # fin de l'accroche (4 temps)
END = 1470 / FPS  # carte finale (T.end)
TAP = 40 / FPS  # LockLive : tap à t = 100, l'accroche joue t = 60 + f
SWAPS = [810, 900, 990, 1030, 1070, 1110]  # create, choose, style (3 styles), écran d'accueil
rng = np.random.default_rng(7)


def place(track, sound, at, gain=1.0, pan=0.0):
    i = int(round(at * SR))
    if sound.ndim == 1:
        sound = np.stack([sound * (1 - max(0, pan)), sound * (1 + min(0, pan))], axis=1)
    end = min(len(track), i + len(sound))
    if end > i:
        track[i:end] += sound[: end - i] * gain


def env(n, attack, decay):
    t = np.arange(n) / SR
    return np.minimum(1, t / max(attack, 1e-4)) * np.exp(-t / decay)


def kick():
    n = int(0.42 * SR)
    t = np.arange(n) / SR
    f = 45 + 95 * np.exp(-t / 0.035)
    x = np.sin(2 * np.pi * np.cumsum(f) / SR) * env(n, 0.001, 0.16)
    return np.tanh(2.2 * x) * 0.9


def clap():
    n = int(0.25 * SR)
    x = np.zeros(n)
    for k, off in enumerate((0, 0.011, 0.022)):
        i = int(off * SR)
        b = S.noise_band(0.25 - off, 900, 5200, seed=11 + k)[: n - i]
        x[i:] += b * env(len(b), 0.0005, 0.012 if k < 2 else 0.09)
    return reverb(x / np.max(np.abs(x)), 0.9, 0.18)


def hat(open_=False):
    d = 0.16 if open_ else 0.035
    b = S.noise_band(d + 0.02, 7000, 16000, seed=int(rng.integers(1, 999)))
    return b * env(len(b), 0.0005, d / 3) / (np.max(np.abs(b)) + 1e-9)


def bass808(freq, seconds):
    n = int(seconds * SR)
    t = np.arange(n) / SR
    f = freq * (1 + 0.6 * np.exp(-t / 0.03))
    x = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.minimum(1, t / 0.004) * np.exp(-t / (seconds * 0.7))
    tail = np.minimum(1, (n - np.arange(n)) / (0.02 * SR))
    return np.tanh(1.8 * x) * tail


def bell(freq, seconds=0.5):
    return fm_glass(freq, seconds=seconds, ratio=1.41, index=2.6, decay=0.22)


def score():
    n = int(round(LENGTH * SR))
    tr = np.zeros((n, 2))
    # accroche : nappe sombre (D mineur) et un charleston qui monte, rien de lourd avant le tap
    place(tr, S.pad([note("D3"), note("F3"), note("A3"), note("C4")], DROP + 0.6, attack=0.6, release=0.6, cutoff=900), 0, db(-20))
    for i in range(8):
        place(tr, hat(), i * BEAT / 2, db(-30 + 1.5 * i), pan=0.2)
    place(tr, S.riser(DROP - 0.9), 0.9, db(-22))
    # corps : 4 temps par mesure, du drop jusqu'à 0,5 s avant la carte finale
    stop = END - 0.5
    roots = ["D1", "D1", "A#0", "C1"]
    melody = [("D5", 0), ("F5", 0.75), ("A5", 1.5), ("C6", 2.25), ("A5", 3.0), ("F5", 3.5)]
    bar = 4 * BEAT
    b = 0
    t0 = DROP
    while t0 < stop - 1e-6:
        for k in range(4):
            tk = t0 + k * BEAT
            if tk >= stop:
                break
            if k in (0, 2) or (k == 3 and b % 2 == 1):
                place(tr, kick(), tk + (BEAT / 2 if k == 3 else 0), db(-6))
            if k in (1, 3):
                place(tr, clap(), tk, db(-11))
            for h in range(2):
                place(tr, hat(), tk + h * BEAT / 2, db(-21 if h == 0 else -25), pan=0.25)
        if b % 2 == 1:  # roulement de charleston en triolets de doubles croches à la fin des mesures impaires
            for r in range(6):
                place(tr, hat(), t0 + 3.5 * BEAT + r * BEAT / 6, db(-26 + r), pan=-0.2)
        root = note(roots[b % 4])
        place(tr, bass808(root, 1.4), t0, db(-8))
        place(tr, bass808(root, 0.6), t0 + 1.5 * BEAT, db(-10))
        place(tr, bass808(root * 1.5, 0.5), t0 + 3 * BEAT, db(-11))
        if b >= 1:
            for nm, at in melody:
                if t0 + at * BEAT < stop:
                    place(tr, reverb(bell(note(nm)), 1.8, 0.25), t0 + at * BEAT, db(-21), pan=0.15 if at % 1 else -0.15)
        b += 1
        t0 += bar
    # coupure nette avant la carte finale, puis montée
    a = int((stop - 0.01) * SR)
    tr[a:] *= 0
    place(tr, S.riser(1.6), stop - 1.6, db(-18))
    a = int(stop * SR)
    tr[a : int(END * SR)] = 0
    # signature Ardane (même que les autres pubs : ré5, la5 sur un ré majeur 9)
    place(tr, reverb(fm_glass(note("D5"), seconds=1.0, index=4.0, decay=0.32), 3.0, 0.3), END + 0.1, db(-12))
    place(tr, reverb(fm_glass(note("A5"), index=4.0, decay=1.6), 3.0, 0.3), END + 0.6, db(-12))
    place(tr, S.pad([note("D3"), note("F#3"), note("A3"), note("C#4"), note("E4")], LENGTH - END - 0.6, attack=0.1, release=1.6, cutoff=2400), END + 0.6, db(-16))
    return tr


def sfx():
    n = int(round(LENGTH * SR))
    tr = np.zeros((n, 2))
    place(tr, M.tap_pulse(), TAP, db(-8))
    place(tr, S.cue_check(), TAP + 0.2, db(-10))
    for f in SWAPS:
        place(tr, M.whoosh(0.3, 1000, 6000, seed=61 + f), f / FPS - 0.12, db(-17))
    for f in (300, 600):  # arrivée des écrans de l'app
        place(tr, M.whoosh(0.4, 600, 4000, seed=f), f / FPS - 0.15, db(-19))
    return tr


def main():
    film = sys.argv[1] if len(sys.argv) > 1 else os.path.expanduser("~/ardane-tools/film")
    mixdown = score() + sfx()
    e = int((LENGTH - 0.3) * SR)
    mixdown[e - int(0.4 * SR) : e] *= np.linspace(1, 0, int(0.4 * SR))[:, None]
    mixdown[e:] = 0
    meter = pyln.Meter(SR)
    mixdown = pyln.normalize.loudness(mixdown, meter.integrated_loudness(mixdown), -14.0)
    peak = np.max(np.abs(mixdown))
    if peak > db(-1):
        mixdown *= db(-1) / peak
    out = os.path.join(film, "public", "irl", "fitness", "mix.wav")
    sf.write(out, mixdown.astype(np.float32), SR, subtype="PCM_24")
    print(out, f"{len(mixdown) / SR:.2f} s", f"{meter.integrated_loudness(mixdown):.1f} LUFS", f"crête {20 * np.log10(np.max(np.abs(mixdown))):.1f} dBFS")


if __name__ == "__main__":
    main()
