"""The score of the main film, « Seam » (Concept-THE-OPENING §3.1–3.2): 120 BPM, D minor → D major,
29 bars = 58.0 s = 3480 frames. Bar n starts at frame (n − 1) × 120; a beat is 30 frames, an eighth 15.
Music only (the SFX and the voice are mixed by mix.py, which ducks this stem under the voice).

    python -X utf8 score.py <out.wav>
"""
import sys

import numpy as np
import soundfile as sf
from scipy.signal import butter, sosfilt

from synth import SR, db, fm_glass, note, one_pole_lowpass, reverb, riser, sub

BARS = 29
LENGTH = BARS * 2.0
BEAT = 0.5


def bar(n, beat=0.0):
    """Start of bar n (1-based) plus beats, in seconds."""
    return (n - 1) * 2.0 + beat * BEAT


def t_axis(seconds):
    return np.arange(int(round(seconds * SR))) / SR


def add(track, sound, at, gain=1.0, pan=0.0):
    i = int(round(at * SR))
    if i >= len(track):
        return
    if sound.ndim == 1:
        left, right = np.cos((pan + 1) * np.pi / 4), np.sin((pan + 1) * np.pi / 4)
        sound = np.stack([sound * left, sound * right], axis=1) * np.sqrt(2)
    end = min(len(track), i + len(sound))
    track[i:end] += sound[: end - i] * gain


def filt(x, kind, freq, order=2):
    sos = butter(order, freq, btype=kind, fs=SR, output="sos")
    return sosfilt(sos, x, axis=0)


# --- Chords (voicings) ---------------------------------------------------------------------------
CH = {
    "Dadd9": ["D3", "A3", "E4", "F4"],
    "Dm9": ["D3", "F3", "A3", "C4", "E4"],
    "Bbmaj7": ["A#2", "D3", "F3", "A3"],
    "Fmaj7/A": ["A2", "F3", "A3", "C4", "E4"],
    "Cadd9": ["C3", "G3", "D4", "E4"],
    "A7sus4": ["A2", "D3", "E3", "G3"],
    "Gm9": ["G2", "A#2", "D3", "F3", "A3"],
    "Fmaj9": ["F2", "A2", "C3", "E3", "G3"],
    "C/E": ["E2", "G2", "C3", "E3", "G3"],
    "Bbmaj7#11": ["A#2", "D3", "F3", "A3", "E4"],
    "Csus4": ["C3", "F3", "G3", "C4"],
    "C": ["C3", "E3", "G3", "C4"],
    "Bbmaj9": ["A#2", "D3", "F3", "A3", "C4"],
    "Dmaj9": ["D3", "F#3", "A3", "E4"],
}
ROOT = {k: v[0] for k, v in CH.items()}
ROOT.update({"Fmaj7/A": "F2", "C/E": "C3", "Dadd9": "D2"})

# (start bar, length in bars, chord): the harmony of §3.1.
PROGRESSION = [
    (1, 3, "Dadd9"),
    (4, 1, "Dm9"), (5, 1, "Bbmaj7"), (6, 1, "Fmaj7/A"), (7, 1, "Cadd9"), (8, 0.5, "Dm9"), (8.5, 0.5, "A7sus4"),
    (9, 1, "Dm9"), (10, 1, "Bbmaj7"), (11, 1, "Gm9"), (12, 1, "A7sus4"), (13, 1, "Dm9"),
    (14, 2, "Bbmaj7"), (16, 1, "A7sus4"),
    (17, 1, "Fmaj9"), (18, 1, "C/E"), (19, 1, "Dm9"), (20, 1, "Bbmaj7#11"), (21, 0.5, "Csus4"), (21.5, 0.5, "C"),
    (22, 1, "Dm9"), (23, 1, "Bbmaj7"), (24, 1, "Csus4"),
    (25, 1, "Bbmaj9"), (26, 0.5, "Gm9"), (26.5, 0.5, "A7sus4"), (27, 1, "Bbmaj9"), (28, 2, "Dmaj9"),
]


def chord_at(seconds):
    for start, length, name in PROGRESSION:
        if bar(start) <= seconds < bar(start) + length * 2.0:
            return name
    return PROGRESSION[-1][2]


# --- Instruments ---------------------------------------------------------------------------------
def saw_stack(freq, seconds, detune=7, voices=6, seed=0):
    t = t_axis(seconds)
    rng = np.random.default_rng(seed)
    out = np.zeros_like(t)
    for cents in np.linspace(-detune, detune, voices):
        f = freq * 2 ** (cents / 1200)
        out += 2 * ((f * t + rng.random()) % 1) - 1
    return out / voices


def pad_layer(track, start, seconds, notes, gain, cutoff=1800.0, attack=0.5, release=1.2):
    """6 detuned saws per note plus a sine an octave up, low-passed; overlaps the next chord by its release."""
    total = seconds + release
    t = t_axis(total)
    x = np.zeros_like(t)
    for i, n in enumerate(notes):
        f = note(n)
        x += saw_stack(f, total, seed=i)
        x += 0.5 * np.sin(2 * np.pi * 2 * f * t)
    x = one_pole_lowpass(one_pole_lowpass(x, cutoff), cutoff * 1.4)
    env = np.clip(t / attack, 0, 1) * np.clip((total - t) / release, 0, 1)
    add(track, x * env / len(notes), start, gain)


def pluck(freq, timbre, seconds=0.6):
    """8th-note arp voice, A 2 ms / D 180 ms / S 0; its timbre is the universe on screen (§3.1)."""
    t = t_axis(seconds)
    env = (1 - np.exp(-t / 0.002)) * np.exp(-t / 0.18)
    if timbre == "aurora":  # soft FM
        y = np.sin(2 * np.pi * freq * t + 1.5 * np.exp(-t / 0.15) * np.sin(2 * np.pi * 2 * freq * t))
    elif timbre == "space":  # sine bell
        y = np.sin(2 * np.pi * freq * t) + 0.35 * np.sin(2 * np.pi * 2.76 * freq * t) * np.exp(-t / 0.12)
        env = (1 - np.exp(-t / 0.002)) * np.exp(-t / 0.35)
    elif timbre == "paper":  # felt pluck
        tri = 2 * np.abs(2 * ((freq * t) % 1) - 1) - 1
        y = one_pole_lowpass(tri, 1400) * 1.6
        env = (1 - np.exp(-t / 0.004)) * np.exp(-t / 0.12)
    elif timbre == "neon":  # supersaw through a closing low-pass
        y = saw_stack(freq, seconds, detune=14, voices=5)
        y = one_pole_lowpass(y, 2600) * 1.3
    elif timbre == "minimal":  # pure square
        y = np.sign(np.sin(2 * np.pi * freq * t)) * 0.5
        y = one_pole_lowpass(y, 2400)
    else:  # sunset, warm FM
        y = np.sin(2 * np.pi * freq * t + 2.5 * np.exp(-t / 0.25) * np.sin(2 * np.pi * freq * t))
    return y * env


def kick():
    t = t_axis(0.5)
    f = 48 + (150 - 48) * np.exp(-t / 0.02)
    body = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t / 0.38 * 2.5)
    clk = np.sin(2 * np.pi * 3000 * t) * np.exp(-t / 0.004) * 0.3
    return body + clk


def snap(seed=0):
    rng = np.random.default_rng(seed)
    t = t_axis(0.25)
    out = np.zeros_like(t)
    for k in range(3):
        burst = rng.standard_normal(len(t)) * np.exp(-np.clip(t - k * 0.01, 0, None) / 0.004) * (t >= k * 0.01)
        out += burst
    out += rng.standard_normal(len(t)) * np.exp(-t / 0.12) * 0.35
    return filt(out, "bandpass", [900, 1600]) * 2.2


def rim(seed=0):
    rng = np.random.default_rng(seed)
    t = t_axis(0.08)
    return filt(rng.standard_normal(len(t)) * np.exp(-t / 0.01), "bandpass", [1800, 2600]) * 2.5


def hat(velocity, seed=0):
    rng = np.random.default_rng(seed)
    t = t_axis(0.06)
    return filt(rng.standard_normal(len(t)) * np.exp(-t / 0.025 * 2), "highpass", 8000) * velocity


def bass_note(freq, seconds):
    t = t_axis(seconds)
    x = saw_stack(freq, seconds, detune=4, voices=2) * 0.6 + np.sin(2 * np.pi * freq / 2 * t) * 0.8
    env = (1 - np.exp(-t / 0.004)) * np.exp(-t / 0.22)
    return one_pole_lowpass(one_pole_lowpass(x, 400), 400) * env


# --- The score -----------------------------------------------------------------------------------
def score():
    n = int(LENGTH * SR)
    pads = np.zeros((n, 2))
    arp = np.zeros((n, 2))
    drums = np.zeros((n, 2))
    bass = np.zeros((n, 2))
    low = np.zeros((n, 2))
    fx = np.zeros((n, 2))

    # A « Void » (bars 1–3): sub drone and air, half-time sub pulse from bar 2, pad swell bar 3.
    t = t_axis(6.0)
    drone = (np.sin(2 * np.pi * note("D1") * t) + 0.25 * np.sin(4 * np.pi * note("D1") * t)) * np.clip(t / 2.5, 0, 1)
    add(low, drone, 0, db(-20))
    rng = np.random.default_rng(4)
    air = filt(rng.standard_normal(n), "bandpass", [6000, 12000]) * np.interp(np.arange(n) / SR, [0, 2, 6, 16, 17], [0.2, 0.6, 1, 0.6, 0])
    add(fx, np.stack([air, np.roll(air, 977)], axis=1), 0, db(-42))
    for k in range(4):
        add(low, sub(note("D1"), 0.5, attack=0.01, release=0.42), bar(2) + k * 2 * BEAT, db(-18))
    pad_layer(pads, bar(3), 2.0, CH["Dadd9"], db(-17), cutoff=1200, attack=1.5)

    # B « Strata » (bars 4–8): pad and the arp whose timbre is the universe on screen. No kick.
    # C « Pulse » (9–13), E « Daylight » (17–21), F « Run » (22–24): pads go on.
    for start, length, name in PROGRESSION:
        if start < 4 or name == "Dmaj9":
            continue
        cutoff = 900 if 14 <= start < 17 else 1800 if start < 17 else 2400
        gain = db(-20) if 14 <= start < 17 else db(-18)
        pad_layer(pads, bar(start), length * 2.0, CH[name], gain, cutoff=cutoff, attack=0.35, release=0.9)

    universes = [(6.0, "aurora"), (9.0, "space"), (10.0, "paper"), (11.0, "neon"), (12.0, "minimal"), (13.0, "sunset")]

    def timbre_at(s):
        name = "aurora"
        for at, u in universes:
            if s >= at:
                name = u
        return name

    def arp_run(first_bar, last_bar, octave_up=0, gain=db(-22), timbre=None):
        pattern = [0, 1, 2, 3, 4, 3, 2, 1]
        for b in range(first_bar, last_bar + 1):
            for k in range(8):
                s = bar(b, k * 0.5)
                tones = sorted(note(x) * (2 if note(x) < note("A3") else 1) for x in CH[chord_at(s)])
                tones = [f * 2 ** octave_up for f in tones] + [tones[0] * 2 * 2 ** octave_up]
                f = tones[pattern[k] % len(tones)]
                v = pluck(f, timbre or timbre_at(s))
                add(arp, v, s, gain, pan=-0.35 if k % 2 == 0 else 0.35)

    arp_run(4, 8)
    arp_run(9, 13, gain=db(-25), timbre="sunset")
    arp_run(17, 21, octave_up=1, gain=db(-24), timbre="space")
    arp_run(22, 24, octave_up=1, gain=db(-25), timbre="sunset")
    # Ping-pong delay 3/16 (0.375 s), 25 % feedback.
    d = int(0.375 * SR)
    echo = np.zeros_like(arp)
    src = arp.copy()
    for k in range(1, 5):
        shifted = np.zeros_like(arp)
        shifted[d * k:] = src[: -d * k]
        if k % 2:
            shifted = shifted[:, ::-1]
        echo += shifted * 0.25 ** k
    arp += echo

    # Drums and bass: C full (kick 1 & 3, snap 2 & 4, 16th hats), E lighter (rim, 8th hats), F full.
    kicks = []

    def groove(first_bar, last_bar, back="snap", hats16=True):
        vel = [1.0, 0.45, 0.7, 0.45]
        for b in range(first_bar, last_bar + 1):
            for beat in range(4):
                s = bar(b, beat)
                if beat in (0, 2):
                    add(drums, kick(), s, db(-9))
                    kicks.append(s)
                else:
                    add(drums, snap(b * 4 + beat) if back == "snap" else rim(b * 4 + beat), s, db(-16) if back == "snap" else db(-20))
                for h in range(4 if hats16 else 2):
                    step = 0.25 if hats16 else 0.5
                    add(drums, hat(vel[h] if hats16 else 0.7, b * 16 + beat * 4 + h), s + h * step * BEAT, db(-26), pan=0.25)
            root = note(ROOT[chord_at(bar(b))])
            while root > note("D3"):
                root /= 2
            for k in range(8):
                add(bass, bass_note(root * (2 if k % 2 else 1), 0.3), bar(b, k * 0.5), db(-17))

    groove(9, 13)
    groove(17, 21, back="rim", hats16=False)
    groove(22, 24)
    # Three accents of F (Money, Week, Habits) on 42, 44, 46 s.
    for s in (bar(22), bar(23), bar(24)):
        rng = np.random.default_rng(int(s))
        crash = filt(rng.standard_normal(int(1.2 * SR)) * np.exp(-t_axis(1.2) / 0.35), "highpass", 3000)
        add(drums, crash, s, db(-24))
        add(low, sub(note("D1"), 0.8, attack=0.005, release=0.7), s, db(-16))

    # Sidechain: pads and bass duck under each kick (−4 dB pads, −6 dB bass), release 150 ms.
    duck = np.ones(n)
    tt = np.arange(int(0.4 * SR)) / SR
    shape = np.exp(-tt / 0.15)
    for s in kicks:
        i = int(s * SR)
        seg = duck[i:i + len(shape)]
        np.minimum(seg, 1 - shape[: len(seg)], out=seg)
    pads *= (1 - (1 - db(-4)) * (1 - duck))[:, None]
    bass *= (1 - (1 - db(-6)) * (1 - duck))[:, None]

    # Risers into 16 s (2 beats), 32 s and 52 s, each ending in a one-beat « suck » before the hit.
    add(fx, riser(1.0), bar(8, 2), db(-24))
    add(fx, riser(0.97), bar(16, 2), db(-26))
    add(fx, riser(1.75), bar(26), db(-22))

    # E: the bell motif on the downbeats of Daylight.
    for b, nn in zip(range(17, 22), ["A5", "G5", "F5", "E5", "G5"]):
        add(fx, reverb(fm_glass(note(nn), index=2.0, decay=1.4), 3.0, 0.35), bar(b), db(-27))

    # G « Gather → Logo » (25–29): pad opens, reverse swell into the merge (52 s), Picardy D major (54 s).
    pad_layer(pads, bar(25), 4.0, CH["Bbmaj9"], db(-16), cutoff=2600, attack=1.2, release=0.6)
    pad_layer(pads, bar(26, 2), 1.0, CH["A7sus4"], db(-17), cutoff=2600, attack=0.3, release=0.4)
    pad_layer(pads, bar(27), 2.0, CH["Bbmaj9"], db(-15), cutoff=3000, attack=0.05, release=0.8)
    hit = np.zeros(int(1.6 * SR))
    th = t_axis(1.6)
    hit += np.sin(2 * np.pi * np.cumsum(60 * (0.5 ** (th / 1.5))) / SR) * np.exp(-th / 0.9)
    rng = np.random.default_rng(52)
    hit += one_pole_lowpass(rng.standard_normal(len(th)), 2000) * np.exp(-th / 0.25) * 0.6
    add(low, hit, bar(27), db(-10))
    pad_layer(pads, bar(28), 3.83, CH["Dmaj9"], db(-15), cutoff=2400, attack=0.08, release=2.6)
    add(low, sub(note("D1"), 3.8, attack=0.05, release=2.5), bar(28), db(-20))

    pads = reverb(pads.mean(axis=1), 4.5, 0.3) * 0.9 + pads * 0.1
    mix = pads + arp + drums + bass + low + fx
    # One-beat sucks before the hits of 16 s, 32 s and 52 s; silence from f3470 (57.83 s).
    for s in (16.0, 32.0, 52.0):
        a, b = int((s - 0.06) * SR), int(s * SR)
        mix[a:b] *= np.linspace(1, 0, b - a)[:, None]
    end = int(3470 / 60 * SR)
    fade = int(0.6 * SR)
    mix[end - fade:end] *= np.linspace(1, 0, fade)[:, None]
    mix[end:] = 0
    return mix


if __name__ == "__main__":
    out = sys.argv[1]
    audio = score()
    import pyloudnorm as pyln
    meter = pyln.Meter(SR)
    loud = meter.integrated_loudness(audio)
    # The bed sits around −20 LUFS before mix.py ducks it under the voice (−24 to −22 there).
    audio *= db(-20 - loud)
    peak = np.abs(audio).max()
    if peak > db(-1):
        audio *= db(-1) / peak
    sf.write(out, audio.astype(np.float32), SR, subtype="FLOAT")
    print(f"score: {len(audio) / SR:.2f} s, {loud:.1f} → {meter.integrated_loudness(audio):.1f} LUFS, peak {20 * np.log10(np.abs(audio).max()):.1f} dBFS")


# --- Scores of the cut-downs ---------------------------------------------------------------------
# Built from the sections of src/films/cuts.json (seconds, any length): the same instruments and harmony
# as the main film, each section in its own colour, the arp's timbre following the universes on screen.
SECTION_CHORDS = {
    "void": ["Dadd9"],
    "strata": ["Dm9", "Bbmaj7", "Fmaj7/A", "Cadd9"],
    "pulse": ["Dm9", "Bbmaj7", "Gm9", "A7sus4"],
    "break": ["Bbmaj7", "Bbmaj7", "A7sus4"],
    "daylight": ["Fmaj9", "C/E", "Dm9", "Bbmaj7#11", "Csus4"],
    "run": ["Dm9", "Bbmaj7", "Csus4"],
    "gather": ["Bbmaj9", "Gm9", "A7sus4"],
    "logo": ["Dmaj9"],
}


def score_cut(length, sections, universes=(), hits=(), risers=(), logo_at=None, ticks=()):
    """`sections`: [{type, start, end}] in seconds. `universes`: [(seconds, timbre)] for the strata arp.
    `hits`: seconds of the merge-like peaks (sub drop + noise, a one-beat suck before). `risers`: seconds
    where a riser ends (one beat of suck before when it is a hit). `logo_at`: the D major Picardy."""
    n = int(round(length * SR))
    pads = np.zeros((n, 2))
    arp = np.zeros((n, 2))
    drums = np.zeros((n, 2))
    bass = np.zeros((n, 2))
    low = np.zeros((n, 2))
    fx = np.zeros((n, 2))
    kicks = []

    def chords_of(sec):
        names = SECTION_CHORDS[sec["type"]]
        out = []
        t = sec["start"]
        k = 0
        while t < sec["end"] - 1e-6:
            dur = min(2.0, sec["end"] - t)
            name = names[-1] if (sec["type"] == "break" and sec["end"] - t <= 2.0) else names[k % len(names)]
            if sec["type"] in ("void", "logo"):
                dur = sec["end"] - t
                name = names[0]
            out.append((t, dur, name))
            t += dur
            k += 1
        return out

    progression = [c for sec in sections for c in chords_of(sec)]

    def chord_at(s):
        for t, d, name in progression:
            if t <= s < t + d:
                return name
        return progression[-1][2]

    def timbre_at(s):
        name = "aurora"
        for at, u in universes:
            if s >= at:
                name = u
        return name

    pattern = [0, 1, 2, 3, 4, 3, 2, 1]

    def arp_run(t0, t1, octave_up=0, gain=db(-23), timbre=None):
        s = np.ceil(t0 / 0.25) * 0.25
        k = int(round(s / 0.25))
        while s < t1 - 0.05:
            tones = sorted(note(x) * (2 if note(x) < note("A3") else 1) for x in CH[chord_at(s)])
            tones = [f * 2 ** octave_up for f in tones] + [tones[0] * 2 * 2 ** octave_up]
            f = tones[pattern[k % 8] % len(tones)]
            add(arp, pluck(f, timbre or timbre_at(s)), s, gain, pan=-0.35 if k % 2 == 0 else 0.35)
            s += 0.25
            k += 1

    def groove(t0, t1, back="snap", hats16=True):
        vel = [1.0, 0.45, 0.7, 0.45]
        b = np.ceil(t0 / BEAT) * BEAT
        while b < t1 - 0.05:
            beat = int(round(b / BEAT)) % 4
            if beat in (0, 2):
                add(drums, kick(), b, db(-9))
                kicks.append(b)
            else:
                add(drums, snap(int(b * 4)) if back == "snap" else rim(int(b * 4)), b, db(-16) if back == "snap" else db(-20))
            for h in range(4 if hats16 else 2):
                step = 0.25 if hats16 else 0.5
                add(drums, hat(vel[h] if hats16 else 0.7, int(b * 16) + h), b + h * step * BEAT, db(-26), pan=0.25)
            root = note(ROOT[chord_at(b)])
            while root > note("D3"):
                root /= 2
            for e in range(2):
                add(bass, bass_note(root * (2 if e % 2 else 1), 0.3), b + e * 0.25, db(-17))
            b += BEAT

    for sec in sections:
        t0, t1, kind = sec["start"], sec["end"], sec["type"]
        for t, d, name in chords_of(sec):
            if kind == "void":
                continue
            cutoff = {"break": 900, "daylight": 2400, "gather": 2600, "logo": 2400}.get(kind, 1800)
            gain = {"break": db(-20), "gather": db(-16), "logo": db(-15)}.get(kind, db(-18))
            release = 2.6 if kind == "logo" else 0.9
            pad_layer(pads, t, d, CH[name], gain, cutoff=cutoff, attack=0.35 if kind != "logo" else 0.08, release=release)
        if kind == "void":
            tt = t_axis(t1 - t0)
            drone = (np.sin(2 * np.pi * note("D1") * tt) + 0.25 * np.sin(4 * np.pi * note("D1") * tt)) * np.clip(tt / 2.0, 0, 1)
            add(low, drone, t0, db(-20))
            p = t0 + 2.0
            while p < t1 - 0.2:
                add(low, sub(note("D1"), 0.5, attack=0.01, release=0.42), p, db(-18))
                p += 1.0
            if t1 - t0 > 2.5:
                pad_layer(pads, max(t0, t1 - 2.0), min(2.0, t1 - t0), CH["Dadd9"], db(-17), cutoff=1200, attack=1.5)
        elif kind == "strata":
            arp_run(t0, t1)
        elif kind == "pulse":
            groove(t0, t1)
            arp_run(t0, t1, gain=db(-25), timbre="sunset")
        elif kind == "break":
            add(low, sub(note("A#1"), t1 - t0, attack=0.6, release=0.6), t0, db(-24))
        elif kind == "daylight":
            groove(t0, t1, back="rim", hats16=False)
            arp_run(t0, t1, octave_up=1, gain=db(-24), timbre="space")
            bell_notes = ["A5", "G5", "F5", "E5", "G5"]
            b = np.ceil(t0 / 2.0) * 2.0
            k = 0
            while b < t1 - 0.5:
                add(fx, reverb(fm_glass(note(bell_notes[k % 5]), index=2.0, decay=1.4), 3.0, 0.35), b, db(-27))
                b += 2.0
                k += 1
        elif kind == "run":
            groove(t0, t1)
            arp_run(t0, t1, octave_up=1, gain=db(-25), timbre="sunset")
        elif kind == "logo":
            add(low, sub(note("D1"), t1 - t0, attack=0.05, release=2.5), t0, db(-20))

    for h in hits:
        hit = np.zeros(int(1.6 * SR))
        th = t_axis(1.6)
        hit += np.sin(2 * np.pi * np.cumsum(60 * (0.5 ** (th / 1.5))) / SR) * np.exp(-th / 0.9)
        rng = np.random.default_rng(int(h * 100))
        hit += one_pole_lowpass(rng.standard_normal(len(th)), 2000) * np.exp(-th / 0.25) * 0.6
        add(low, hit, h, db(-10))
    for end, dur in risers:
        add(fx, riser(dur), end - dur, db(-24))

    duck = np.ones(n)
    tt = np.arange(int(0.4 * SR)) / SR
    shape = np.exp(-tt / 0.15)
    for s in kicks:
        i = int(s * SR)
        seg = duck[i:i + len(shape)]
        np.minimum(seg, 1 - shape[: len(seg)], out=seg)
    pads *= (1 - (1 - db(-4)) * (1 - duck))[:, None]
    bass *= (1 - (1 - db(-6)) * (1 - duck))[:, None]
    d = int(0.375 * SR)
    echo = np.zeros_like(arp)
    for k in range(1, 5):
        shifted = np.zeros_like(arp)
        shifted[d * k:] = arp[: -d * k]
        if k % 2:
            shifted = shifted[:, ::-1]
        echo += shifted * 0.25 ** k
    arp += echo
    pads = reverb(pads.mean(axis=1), 4.5, 0.3) * 0.9 + pads * 0.1
    mixd = pads + arp + drums + bass + low + fx
    for s in [h for h in hits] + [e for e, _ in risers]:
        a, b = int((s - 0.06) * SR), int(s * SR)
        if 0 < a < b <= n:
            mixd[a:b] *= np.linspace(1, 0, b - a)[:, None]
    end = n - int(0.12 * SR)
    fade = int(0.6 * SR)
    mixd[end - fade:end] *= np.linspace(1, 0, fade)[:, None]
    mixd[end:] = 0
    return mixd
