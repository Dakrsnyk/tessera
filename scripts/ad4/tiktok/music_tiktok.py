"""Upbeat original music of the TikTok / Instagram ads (asked on 2026-11-08: « légèrement plus d'entrain » than the calm
lifestyle score, to catch attention from the first second). 118 BPM, D major (D, B minor, G, A, like the campaign score),
four-on-the-floor kick from the first beat, claps on 2 and 4, off-beat hats, a pumping bass, a bright plucked arpeggio
and a soft pad; a short lift every 8 bars. Everything is synthesised here (no sample, no third-party music).

    ~/ardane-tools/venv/Scripts/python -I -X utf8 scripts/ad4/tiktok/music_tiktok.py [<out.wav>]

Default output: ~/ardane-tools/film/public/tiktok/music-entrain.wav (read by specs.ts, `music`). The loudness is set to the
same average level as lifestyle/music.wav, so the voice keeps the same balance over the music (ducking in the templates).
"""
import os
import sys

import numpy as np
import soundfile as sf

SR = 48000
BPM = 118
BEAT = 60 / BPM
BAR = 4 * BEAT
LEN = 32.0  # longer than every ad; the templates fade it out at their end
OUT = os.path.join(os.path.expanduser("~"), "ardane-tools", "film", "public", "tiktok", "music-entrain.wav")

rng = np.random.default_rng(118)


def hz(name):
    """« D3 », « F#4 » → Hz (A4 = 440)."""
    names = {"C": -9, "D": -7, "E": -5, "F": -4, "G": -2, "A": 0, "B": 2}
    semis = names[name[0]] + (1 if "#" in name else -1 if name[1] == "b" else 0)
    return 440.0 * 2 ** ((semis + 12 * (int(name[-1]) - 4)) / 12)


def t_axis(seconds):
    return np.arange(int(seconds * SR)) / SR


def lowpass(x, cutoff):
    from scipy.signal import lfilter

    a = np.exp(-2 * np.pi * cutoff / SR)
    return lfilter([1 - a], [1, -a], x)


def highpass(x, cutoff):
    return x - lowpass(x, cutoff)


def db(x):
    return 10 ** (x / 20)


def put(track, sound, at, gain=1.0, pan=0.0):
    """Adds a mono or stereo sound at `at` seconds (equal-power pan for mono)."""
    i = int(round(at * SR))
    if i >= len(track):
        return
    if sound.ndim == 1:
        left, right = np.cos((pan + 1) * np.pi / 4), np.sin((pan + 1) * np.pi / 4)
        sound = np.stack([sound * left, sound * right], axis=1) * np.sqrt(2)
    end = min(len(track), i + len(sound))
    track[i:end] += sound[: end - i] * gain


def reverb(x, seconds=1.6, wet=0.25):
    """Short convolution reverb, decorrelated per channel (mono in, stereo out)."""
    n = int(seconds * SR)
    t = np.arange(n) / SR
    size = 1 << int(np.ceil(np.log2(len(x) + n)))
    out = []
    for ch in range(2):
        ir = lowpass(rng.standard_normal(n) * np.exp(-t * 6.9 / seconds), 6000)
        ir /= np.sqrt(np.sum(ir ** 2))
        out.append(np.fft.irfft(np.fft.rfft(x, size) * np.fft.rfft(ir, size), size)[: len(x)])
    return np.stack([x * (1 - wet) + o * wet for o in out], axis=1)


# ------------------------------------------------------------------------------------------------ instruments
def kick():
    t = t_axis(0.42)
    f = 46 + 110 * np.exp(-t / 0.035)  # pitch drop 156 → 46 Hz
    body = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t / 0.16)
    click = highpass(rng.standard_normal(len(t)), 2500) * np.exp(-t / 0.003) * 0.35
    return np.tanh(1.6 * (body + click)) * (1 - np.exp(-t / 0.0015))


def clap():
    t = t_axis(0.35)
    noise = highpass(lowpass(rng.standard_normal(len(t)), 5200), 900)
    env = np.zeros_like(t)
    for k, d in enumerate([0.0, 0.011, 0.022]):  # three hands, then the room
        env += (t >= d) * np.exp(-np.clip(t - d, 0, None) / (0.006 if k < 2 else 0.11))
    return noise * env


def hat(open_=False):
    t = t_axis(0.25 if open_ else 0.06)
    return highpass(rng.standard_normal(len(t)), 7500) * np.exp(-t / (0.07 if open_ else 0.014))


def bass(freq, seconds):
    t = t_axis(seconds)
    saw = 2 * ((freq * t) % 1) - 1
    sq = np.sign(np.sin(2 * np.pi * freq * t))
    # harmonics up to ~900 Hz so the bass line is heard on a phone speaker, a little sine for the weight
    x = np.tanh(1.5 * lowpass(0.6 * saw + 0.4 * sq, 900)) + 0.35 * np.sin(2 * np.pi * freq * t)
    env = (1 - np.exp(-t / 0.004)) * np.exp(-t / 0.22) * np.clip((seconds - t) / 0.02, 0, 1)
    return x * env


def pluck(freq, seconds=0.5):
    t = t_axis(seconds)
    cut = 900 + 5200 * np.exp(-t / 0.06)
    saw = 2 * ((freq * t) % 1) - 1 + 0.5 * (2 * ((freq * 1.004 * t) % 1) - 1)
    # filter sweep: a few fixed low-passes blended by the decaying cutoff
    lo, mid, hi = lowpass(saw, 900), lowpass(saw, 2500), lowpass(saw, 6000)
    w = np.clip((cut - 900) / 5200, 0, 1)
    x = lo * (1 - w) + (mid * 0.5 + hi * 0.5) * w
    return x * (1 - np.exp(-t / 0.002)) * np.exp(-t / 0.16)


def pad(freqs, seconds):
    t = t_axis(seconds)
    out = np.zeros_like(t)
    for f in freqs:
        for cents in (-8, -3, 3, 8):
            ff = f * 2 ** (cents / 1200)
            out += 2 * ((ff * t + rng.random()) % 1) - 1
    out = lowpass(out, 1400)
    env = np.clip(t / 0.25, 0, 1) * np.clip((seconds - t) / 0.4, 0, 1)
    return out * env / (len(freqs) * 4)


def lift(seconds):
    """A short rising noise sweep into the next phrase."""
    t = t_axis(seconds)
    x = rng.standard_normal(len(t))
    y = sum(highpass(lowpass(x, c), c * 0.5) * np.clip((t / seconds - k / 4) * 4, 0, 1) for k, c in enumerate([1500, 3000, 6000, 10000]))
    return y * (t / seconds) ** 2


# ------------------------------------------------------------------------------------------------ score
# One chord per bar: D maj9, B min7, G maj7, A sus → A.
CHORDS = [
    ("D2", ["D4", "F#4", "A4", "E5"], ["D3", "F#3", "A3", "E4"]),
    ("B1", ["B3", "D4", "F#4", "A4"], ["B2", "D3", "F#3", "A3"]),
    ("G1", ["G3", "B3", "D4", "F#4"], ["G2", "B2", "D3", "F#3"]),
    ("A1", ["A3", "D4", "E4", "A4"], ["A2", "C#3", "E3", "A3"]),
]
# Arpeggio order over 16th notes (indexes in the chord tones; 4 = top note an octave up).
ARP = [0, 1, 2, 3, 4, 3, 2, 1, 0, 2, 1, 3, 2, 4, 3, 1]


def main(out):
    n = int(LEN * SR)
    drums = np.zeros((n, 2))
    music = np.zeros((n, 2))  # bass, pad and pluck: pumped by the kick
    bars = int(LEN / BAR) + 1
    K, C = kick(), clap()
    for b in range(bars):
        t0 = b * BAR
        root, arp, chord = CHORDS[b % 4]
        phrase_end = b % 8 == 7
        for beat in range(4):
            tb = t0 + beat * BEAT
            put(drums, K, tb, gain=db(-5))
            if beat in (1, 3):
                put(drums, reverb(C, 0.8, 0.22), tb, gain=db(-6))
            put(drums, hat(open_=True), tb + BEAT / 2, gain=db(-17), pan=0.25)
            for s in (1, 3):  # quiet closed hats on the 16ths around the off-beat
                put(drums, hat(), tb + s * BEAT / 4, gain=db(-25), pan=-0.3)
        # bass: 8th notes on the root, the last two of the bar an octave up (bounce)
        for k in range(8):
            f = hz(root) * (2 if k in (6, 7) else 1)
            put(music, bass(f, BEAT / 2 * 0.92), t0 + k * BEAT / 2, gain=db(-6))
        # pluck arpeggio in 16th notes, slightly to the right; the pad under it, wide
        tones = [hz(x) for x in arp] + [hz(arp[0]) * 2]
        for k, idx in enumerate(ARP):
            put(music, reverb(pluck(tones[idx], 0.4), 1.2, 0.3), t0 + k * BEAT / 4, gain=db(-9 + (2 if k % 4 == 0 else 0)), pan=0.2)
        put(music, reverb(pad([hz(x) for x in chord], BAR + 0.3), 2.0, 0.35), t0, gain=db(-12))
        if phrase_end:
            put(drums, lift(BAR * 0.75), t0 + BAR * 0.25, gain=db(-20))
    # sidechain: bass, pad and pluck duck under each kick, the « pump » of upbeat pop
    t = np.arange(n) / SR
    since = np.mod(t, BEAT)
    pump = 1 - 0.55 * np.exp(-since / 0.09)
    music *= pump[:, None]
    track = drums + music
    track = np.tanh(track * 1.3) / np.tanh(1.3)
    # same average level as lifestyle/music.wav (≈ -15.6 dB RMS over the first 25 s), peak under -1 dBFS
    rms = np.sqrt(np.mean(track[: int(25 * SR)].mean(1) ** 2))
    track *= db(-15.6) / rms
    peak = np.abs(track).max()
    if peak > db(-1):
        track *= db(-1) / peak
    fade = int(0.01 * SR)
    track[:fade] *= np.linspace(0, 1, fade)[:, None]
    os.makedirs(os.path.dirname(out), exist_ok=True)
    sf.write(out, track.astype(np.float32), SR, subtype="FLOAT")
    m = track[: int(25 * SR)].mean(1)
    print(f"{out}: {LEN:.0f} s, {BPM} BPM, RMS {20 * np.log10(np.sqrt(np.mean(m ** 2))):.1f} dB, peak {20 * np.log10(np.abs(track).max()):.1f} dBFS")


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else OUT)
