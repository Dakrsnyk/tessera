"""Musique originale de la pub « Voici ton téléphone… et voici le mien » (18 s, 120 BPM, ré majeur), synthétisée en code :
aucun échantillon, aucune musique de tiers, aucun timbre « ding » (ni cloche, ni glockenspiel, ni sinus aigu qui décroît).

Calée sur le montage (30 i/s, une mesure = 2 s = 60 images, voir T dans src/avantapres/Film.tsx) :
  0–4 s    l'iPhone « avant » : motif étouffé, mono, filtré, un peu terne ; souffle qui monte de 3 à 4 s
  4 s      DROP pile à l'arrivée de l'écran Sport : kick, clap, charleston, basse, accords supersaw pompés, arpège pluck
  7–8 s    souffle descendant pendant le morphing des widgets, retombée sur la mesure de 8 s
  10 s     balayage de lumière : nappe de souffle aérien, filtre qui s'ouvre
  14–16 s  montée (roulement de claps, souffle) vers la carte de fin
  16 s     impact, accord final tenu sous le logo, fin propre à 18 s

    ~/ardane-tools/venv/Scripts/python.exe -X utf8 scripts/ad2/avant_apres/music_aa.py   # écrit ~/ardane-tools/film/public/avantapres/music-aa.wav
"""
import os

import numpy as np
import soundfile as sf
from scipy.signal import butter, fftconvolve, sosfilt

SR = 48000
BPM = 120
BEAT = 60 / BPM
BAR = 4 * BEAT
LEN = 18.0
N = int(LEN * SR)
OUT = os.path.join(os.path.expanduser("~"), "ardane-tools", "film", "public", "avantapres", "music-aa.wav")
rng = np.random.default_rng(2026)

PC = {"C": 0, "C#": 1, "D": 2, "D#": 3, "E": 4, "F": 5, "F#": 6, "G": 7, "G#": 8, "A": 9, "A#": 10, "B": 11}


def hz(name):
    """« F#3 » → Hz."""
    return 440.0 * 2 ** ((PC[name[:-1]] + 12 * (int(name[-1]) + 1) - 69) / 12)


def t_of(seconds):
    return np.arange(int(seconds * SR)) / SR


def lp(x, f, order=2):
    return sosfilt(butter(order, min(f, SR / 2 - 100), "low", fs=SR, output="sos"), x, axis=0)


def hp(x, f, order=2):
    return sosfilt(butter(order, f, "high", fs=SR, output="sos"), x, axis=0)


def bp(x, lo, hi, order=2):
    return sosfilt(butter(order, [lo, hi], "band", fs=SR, output="sos"), x, axis=0)


def saw(f, t, phase=0.0):
    return 2 * ((f * t + phase) % 1.0) - 1


def env(t, att, dur, rel):
    e = np.clip(t / max(att, 1e-4), 0, 1)
    e *= np.clip((dur + rel - t) / max(rel, 1e-4), 0, 1)
    return e


def sweep_lp(x, f0, f1, steps=48):
    """Filtre passe-bas qui glisse de f0 à f1 (par blocs, fondus)."""
    out = np.zeros_like(x)
    n = len(x)
    edges = np.linspace(0, n, steps + 1).astype(int)
    for i in range(steps):
        a, b = edges[i], edges[i + 1]
        f = f0 * (f1 / f0) ** (i / max(steps - 1, 1))
        pad = min(a, 2048)
        seg = lp(x[a - pad:b], f)
        out[a:b] = seg[pad:]
    return out


class Track:
    def __init__(self):
        self.L = np.zeros(N)
        self.R = np.zeros(N)

    def add(self, sound, at, gain=1.0, pan=0.0):
        i = int(at * SR)
        if i >= N:
            return
        if sound.ndim == 1:
            l, r = sound * np.sqrt((1 - pan) / 2), sound * np.sqrt((1 + pan) / 2)
        else:
            l, r = sound[:, 0], sound[:, 1]
        m = min(len(l), N - i)
        self.L[i:i + m] += l[:m] * gain
        self.R[i:i + m] += r[:m] * gain

    def stereo(self):
        return np.stack([self.L, self.R], 1)


def reverb(x, seconds=2.2, wet=0.25, seed=5, damp=5000):
    """Réverbe par convolution avec un bruit décroissant (stéréo décorrélée)."""
    r = np.random.default_rng(seed)
    t = t_of(seconds)
    outs = []
    for ch in range(2):
        ir = r.normal(0, 1, len(t)) * np.exp(-t * 6.9 / seconds)
        ir = lp(ir, damp)
        ir /= np.sqrt(np.sum(ir ** 2))
        src = x if x.ndim == 1 else x[:, ch]
        outs.append(fftconvolve(src, ir)[: len(src) + len(t)])
    y = np.stack(outs, 1)
    dry = np.zeros_like(y)
    dry[: len(x)] = (x[:, None] if x.ndim == 1 else x)
    return dry * (1 - wet) + y * wet


# ---------------------------------------------------------------- instruments
def kick(punch=1.0):
    t = t_of(0.45)
    f = 45 + 110 * np.exp(-t * 28)
    ph = 2 * np.pi * np.cumsum(f) / SR
    body = np.sin(ph) * np.exp(-t * 7.5)
    click = hp(rng.normal(0, 1, len(t)), 3000) * np.exp(-t * 400) * 0.25
    return np.tanh((body + click) * 1.6 * punch) * 0.9


def clap():
    t = t_of(0.35)
    n = rng.normal(0, 1, len(t))
    e = np.zeros_like(t)
    for k, d in enumerate([0, 0.011, 0.022]):
        e += np.exp(-np.clip(t - d, 0, None) * 160) * (t >= d) * (0.8 if k < 2 else 1.0)
    e += np.exp(-t * 18) * 0.35
    return bp(n, 900, 5200) * e * 0.8


def hat(open_=False):
    t = t_of(0.22 if open_ else 0.05)
    n = hp(rng.normal(0, 1, len(t)), 7500, 4)
    return n * np.exp(-t * (14 if open_ else 90)) * (0.35 if open_ else 0.28)


def supersaw(notes, dur, cutoff=4200, att=0.01, rel=0.25, voices=7, width=0.8):
    t = t_of(dur + rel)
    L = np.zeros_like(t)
    R = np.zeros_like(t)
    for n in notes:
        f = hz(n)
        for v, cents in enumerate(np.linspace(-14, 14, voices)):
            s = saw(f * 2 ** (cents / 1200), t, rng.random())
            pan = (v / (voices - 1) * 2 - 1) * width
            L += s * np.sqrt((1 - pan) / 2)
            R += s * np.sqrt((1 + pan) / 2)
    e = env(t, att, dur, rel)
    y = np.stack([lp(L, cutoff), lp(R, cutoff)], 1) * e[:, None]
    return y / (len(notes) * voices) * 2.2


def pluck(note, dur=0.22, bright=5200, gain=1.0):
    t = t_of(dur)
    f = hz(note)
    s = 0.6 * saw(f, t) + 0.4 * np.sign(np.sin(2 * np.pi * f * t))
    # filtre qui se ferme vite : un pluck, pas une cloche
    y = np.zeros_like(t)
    blocks = 8
    edges = np.linspace(0, len(t), blocks + 1).astype(int)
    for i in range(blocks):
        a, b = edges[i], edges[i + 1]
        y[a:b] = lp(s[: b], 400 + bright * np.exp(-i * 0.7))[a:b]
    return y * np.exp(-t * 11) * env(t, 0.002, dur - 0.03, 0.03) * 0.5 * gain


def bass(note, dur):
    t = t_of(dur)
    f = hz(note)
    s = np.sin(2 * np.pi * f * t) * 0.8 + lp(saw(f, t), 500) * 0.35
    return np.tanh(s * 1.4) * env(t, 0.004, dur - 0.04, 0.04) * 0.55


def noise_rise(dur, lo=300, hi=9000, gain=0.35):
    t = t_of(dur)
    n = rng.normal(0, 1, len(t))
    y = np.zeros_like(t)
    steps = 40
    edges = np.linspace(0, len(t), steps + 1).astype(int)
    for i in range(steps):
        a, b = edges[i], edges[i + 1]
        c = lo * (hi / lo) ** (i / (steps - 1))
        pad = min(a, 2048)
        y[a:b] = bp(n[a - pad:b], c * 0.7, min(c * 1.4, SR / 2 - 200))[pad:]
    return y * (t / dur) ** 2 * gain


def whoosh(dur=1.0, down=False):
    t = t_of(dur)
    n = rng.normal(0, 1, len(t))
    y = np.zeros_like(t)
    steps = 32
    edges = np.linspace(0, len(t), steps + 1).astype(int)
    for i in range(steps):
        a, b = edges[i], edges[i + 1]
        k = i / (steps - 1)
        c = 6000 * (0.08 ** k) if down else 500 * (12 ** k)
        pad = min(a, 2048)
        y[a:b] = bp(n[a - pad:b], c * 0.6, min(c * 1.6, SR / 2 - 200))[pad:]
    shape = np.sin(np.pi * np.clip(t / dur, 0, 1)) ** 1.5
    return y * shape * 0.5


def impact():
    t = t_of(2.2)
    f = 38 + 60 * np.exp(-t * 10)
    boom = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 2.2)
    crash = lp(hp(rng.normal(0, 1, len(t)), 2500), 11000) * np.exp(-t * 2.8) * 0.22
    return np.tanh(boom * 1.3) * 0.9 + crash


# ---------------------------------------------------------------- partition
def compose():
    drums, music, fx = Track(), Track(), Track()
    duck = np.ones(N)  # sidechain : les accords et la basse se creusent sous chaque kick

    # 0–4 s : l'iPhone « avant » — un motif terne, étouffé, en mono
    dull = ["D4", "A3", "D4", "A3", "E4", "A3", "D4", "A3"]
    for bar in range(2):
        for k, n in enumerate(dull):
            at = bar * BAR + k * BEAT / 2
            music.add(lp(pluck(n, 0.3, bright=900, gain=1.0), 1100), at, 0.55)
        music.add(lp(bass("D2", BAR * 0.95), 300), bar * BAR, 0.35)
    fx.add(noise_rise(1.1, 400, 11000, 0.5), 2.9, 0.9)
    fx.add(whoosh(0.8), 3.25, 0.55)

    # 4–16 s : la partie lumineuse, 6 mesures (accords d'une mesure, ré majeur)
    prog = [
        (["G3", "B3", "D4", "F#4"], "G1", ["G4", "B4", "D5", "F#5"]),
        (["D3", "F#3", "A3", "E4"], "F#1", ["F#4", "A4", "D5", "E5"]),
        (["E3", "G3", "B3", "D4", "F#4"], "E1", ["E4", "G4", "B4", "F#5"]),
        (["B2", "D3", "F#3", "A3"], "B1", ["B4", "D5", "F#5", "A5"]),
        (["G3", "B3", "D4", "F#4"], "G1", ["G4", "B4", "D5", "F#5"]),
        (["A3", "D4", "E4", "A4"], "A1", ["A4", "D5", "E5", "A5"]),
    ]
    start = 4.0
    for b, (chord, root, arp) in enumerate(prog):
        t0 = start + b * BAR
        last = b == len(prog) - 1
        # batterie
        for beat in range(4):
            at = t0 + beat * BEAT
            if last and beat >= 2:
                continue  # la montée remplace le kick avant la fin
            drums.add(kick(), at, 0.95)
            i = int(at * SR)
            d = 1 - 0.65 * np.exp(-np.arange(int(0.25 * SR)) / SR * 14)
            duck[i:i + len(d)] = np.minimum(duck[i:i + len(d)], d[: max(0, min(len(d), N - i))])
            if beat in (1, 3):
                drums.add(clap(), at, 0.7, 0.05)
            drums.add(hat(open_=True), at + BEAT / 2, 0.55, 0.25)
            for s16 in (1, 3):
                drums.add(hat(), at + s16 * BEAT / 4, 0.45, -0.3)
        # accords supersaw, filtre plus ouvert après le balayage de lumière (10 s)
        cut = 3200 if b < 3 else 5200
        music.add(supersaw(chord, BAR - 0.02, cutoff=cut), t0, 0.62)
        # basse en croches sur le contretemps
        for e8 in range(8):
            if last and e8 >= 4:
                break
            note = root if e8 % 2 else root[:-1] + str(int(root[-1]) + 1)
            music.add(bass(note, BEAT / 2 - 0.02), t0 + e8 * BEAT / 2, 0.5 if e8 % 2 else 0.32)
        # arpège pluck en doubles croches, écho en ping-pong
        for s in range(16):
            if last and s >= 8:
                break
            n = arp[(s * 3) % len(arp)] if b % 2 else arp[s % len(arp)]
            p = pluck(n, 0.2, bright=4200 + 600 * (b >= 3))
            at = t0 + s * BEAT / 4
            music.add(p, at, 0.42, -0.35)
            music.add(lp(p, 3000), at + 3 * BEAT / 4, 0.16, 0.6)
            music.add(lp(p, 2200), at + 6 * BEAT / 4, 0.08, -0.6)

    # impact du drop
    fx.add(impact(), 4.0, 0.55)
    # morphing des widgets (7 → 8 s) : souffle descendant, retombée sur 8 s
    fx.add(whoosh(1.0, down=True), 7.05, 0.6)
    fx.add(hat(open_=True), 8.0, 0.8)
    # balayage de lumière (10 s) : nappe aérienne
    air = hp(rng.normal(0, 1, int(2.2 * SR)), 6000) * np.sin(np.pi * np.linspace(0, 1, int(2.2 * SR))) ** 2 * 0.12
    fx.add(reverb(air, 1.5, 0.5), 9.6, 0.8)
    fx.add(whoosh(0.9), 9.6, 0.4)
    # alignement des trois téléphones (13,4 s) : petit souffle
    fx.add(whoosh(0.7), 13.1, 0.35)
    # montée vers la carte de fin : roulement de claps qui accélère + souffle
    rolls = np.concatenate([np.arange(14.0, 15.0, BEAT / 2), np.arange(15.0, 15.5, BEAT / 4), np.arange(15.5, 16.0, BEAT / 8)])
    for k, at in enumerate(rolls):
        drums.add(clap(), at, 0.25 + 0.5 * k / len(rolls), 0.0)
    fx.add(noise_rise(2.0, 300, 12000, 0.55), 14.0, 0.9)
    # 16 s : impact et accord final tenu (ré add9), fin à 18 s
    fx.add(impact(), 16.0, 0.75)
    drums.add(kick(1.2), 16.0, 1.0)
    final = supersaw(["D3", "A3", "D4", "E4", "F#4", "A4"], 1.7, cutoff=4800, att=0.005, rel=0.3)
    tail = np.linspace(1, 0, len(final)) ** 1.2
    music.add(final * tail[:, None], 16.0, 0.8)
    music.add(bass("D1", 1.8) * np.linspace(1, 0, int(1.8 * SR)), 16.0, 0.7)

    mus = music.stereo() * duck[:, None]
    mus = reverb(mus, 1.8, 0.22)[:N]
    fxs = reverb(fx.stereo(), 2.4, 0.3)[:N]
    drm = drums.stereo()
    body = drm * 0.9 + mus * 0.85
    # avant 4 s : son étroit (mono), sans aigus, un peu plus bas — l'iPhone banal ; après : large et brillant.
    # Le souffle de montée (fx) n'est pas filtré : c'est lui qui ouvre vers le drop.
    pre = int(4.0 * SR)
    m = body[:pre].mean(1, keepdims=True)
    body[:pre] = lp(m * np.ones((1, 2)), 2400) * 1.6
    mix = body + fxs * 0.8
    # fondu de fin et mastering : compression douce, plafond -1 dBFS
    fade = np.ones(N)
    fade[-int(0.25 * SR):] = np.linspace(1, 0, int(0.25 * SR))
    mix *= fade[:, None]
    mix = np.tanh(mix * 1.15) / np.tanh(1.15)
    mix *= 10 ** (-1.0 / 20) / np.max(np.abs(mix))
    return mix


if __name__ == "__main__":
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    y = compose()
    sf.write(OUT, y.astype(np.float32), SR, subtype="PCM_24")
    rms = 20 * np.log10(np.sqrt(np.mean(y ** 2)))
    print(f"ok {OUT} {len(y) / SR:.2f} s, RMS {rms:.1f} dB")
