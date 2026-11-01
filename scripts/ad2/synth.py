"""Instruments of the campaign score, synthesised in code (Concept-THE-OPENING §3.2), and the cues
built from them. 48 kHz stereo float WAV. Timeline: 120 BPM, a beat is 30 frames at 60 fps.

    python -X utf8 synth.py <cue> <out.wav>      cues: opening, lock, close
"""
import sys
import numpy as np
import soundfile as sf

SR = 48000
FPS = 60


def note(name):
    """« D5 », « F#3 » → Hz (A4 = 440)."""
    names = {"C": -9, "D": -7, "E": -5, "F": -4, "G": -2, "A": 0, "B": 2}
    semis = names[name[0]] + (1 if "#" in name else -1 if name[1] == "b" else 0)
    octave = int(name[-1])
    return 440.0 * 2 ** ((semis + 12 * (octave - 4)) / 12)


def t_axis(seconds):
    return np.arange(int(seconds * SR)) / SR


def fm_glass(freq, seconds=2.4, ratio=3.5, index=4.0, index_decay=1.2, decay=1.6):
    """The signature: 2-operator FM, ratio 1:3.5, index 4→0 over 1.2 s, glassy bell tail."""
    t = t_axis(seconds)
    idx = index * np.clip(1 - t / index_decay, 0, 1) ** 2
    env = (1 - np.exp(-t / 0.003)) * np.exp(-t / decay)
    return np.sin(2 * np.pi * freq * t + idx * np.sin(2 * np.pi * freq * ratio * t)) * env


def pad(freqs, seconds, attack=1.5, release=2.0, cutoff=1800.0):
    """6 saws detuned ±7 cents per note plus a sine an octave up, gentle low-pass."""
    t = t_axis(seconds)
    out = np.zeros_like(t)
    rng = np.random.default_rng(7)
    for f in freqs:
        for cents in np.linspace(-7, 7, 6):
            ff = f * 2 ** (cents / 1200)
            phase = rng.random()
            out += 2 * ((ff * t + phase) % 1) - 1
        out += 1.5 * np.sin(2 * np.pi * 2 * f * t)
    out = one_pole_lowpass(out, cutoff)
    env = np.clip(t / attack, 0, 1) * np.clip((seconds - t) / release, 0, 1)
    return out * env / (len(freqs) * 7)


def sub(freq, seconds, attack=0.8, release=1.5):
    t = t_axis(seconds)
    env = np.clip(t / attack, 0, 1) * np.clip((seconds - t) / release, 0, 1)
    return (np.sin(2 * np.pi * freq * t) + 0.25 * np.sin(4 * np.pi * freq * t)) * env


def one_pole_lowpass(x, cutoff):
    a = np.exp(-2 * np.pi * cutoff / SR)
    try:
        from scipy.signal import lfilter
        return lfilter([1 - a], [1, -a], x)
    except ImportError:
        y = np.empty_like(x)
        acc = 0.0
        for i, v in enumerate(x):
            acc = (1 - a) * v + a * acc
            y[i] = acc
        return y


def reverb(x, seconds=3.0, wet=0.3, seed=3):
    """Cheap convolution reverb: exponentially decaying noise, decorrelated per channel."""
    rng = np.random.default_rng(seed)
    n = int(seconds * SR)
    t = np.arange(n) / SR
    out = []
    for ch in range(2):
        ir = rng.standard_normal(n) * np.exp(-t * 6.9 / seconds)
        ir = one_pole_lowpass(ir, 5000.0)
        ir /= np.sqrt(np.sum(ir ** 2))
        size = 1 << int(np.ceil(np.log2(len(x) + n)))
        out.append(np.fft.irfft(np.fft.rfft(x, size) * np.fft.rfft(ir, size), size)[: len(x)])
    return np.stack([x * (1 - wet) + o * wet for o in out], axis=1)


def place(track, sound, frame, gain=1.0, pan=0.0):
    """Adds a mono or stereo sound at an integer frame (exact sample: frame × 800)."""
    i = frame * SR // FPS
    if sound.ndim == 1:
        left, right = np.cos((pan + 1) * np.pi / 4), np.sin((pan + 1) * np.pi / 4)
        sound = np.stack([sound * left, sound * right], axis=1) * np.sqrt(2)
    end = min(len(track), i + len(sound))
    track[i:end] += sound[: end - i] * gain


def db(x):
    return 10 ** (x / 20)


def noise_band(seconds, low, high, seed=1):
    """Band-passed white noise (two one-pole filters): air, whooshes."""
    rng = np.random.default_rng(seed)
    x = rng.standard_normal(int(seconds * SR))
    return one_pole_lowpass(x - one_pole_lowpass(x, low), high)


def envelope(seconds, points):
    """Piecewise-linear envelope from (time s, level) points."""
    t = t_axis(seconds)
    xs, ys = zip(*points)
    return np.interp(t, xs, ys)


def cue_opening():
    """Shots 1–3 of the main film (f0–359, 0–6 s), section A « Void » (bars 1–3).
    f0: sub drone D1 and air bed rise from near silence · f6: the line ignites (FM glass D6 + air whoosh) ·
    f120: the screen wakes (Dm(add9) pad swell) · half-time sub pulse from bar 2 (every 60 frames)."""
    frames = 360
    seconds = frames / FPS
    track = np.zeros((frames * SR // FPS, 2))
    drone = sub(note("D1"), seconds + 1, attack=2.5, release=0.01)[: len(track)]
    place(track, drone, 0, db(-22))
    air = noise_band(seconds, 6000, 12000, seed=4) * envelope(seconds, [(0, 0.2), (2, 0.6), (6, 1)])
    place(track, np.stack([air, np.roll(air, 977)], axis=1), 0, db(-40))
    whoosh = noise_band(0.9, 3000, 8000, seed=5) * envelope(0.9, [(0, 0), (0.12, 1), (0.9, 0)])
    place(track, whoosh, 6, db(-30))
    place(track, reverb(fm_glass(note("D6"), index=3.0, decay=1.4), 3.5, 0.35), 6, db(-20))
    pad_chord = pad([note(n) for n in ("D3", "A3", "E4", "F4")], seconds - 2 + 2.5, attack=1.6, release=0.01)
    place(track, reverb(pad_chord, 4.5, 0.35)[: len(track) - 120 * SR // FPS], 120, db(-22))
    for f in range(120, frames, 60):
        place(track, sub(note("D1"), 0.5, attack=0.01, release=0.42), f, db(-20))
    return track


def fm_wood(freq, seconds=0.12, ratio=1.4, index=2.5):
    """Countdown tick: FM wood, ratio 1:1.4, 30 ms body."""
    t = t_axis(seconds)
    env = (1 - np.exp(-t / 0.001)) * np.exp(-t / 0.03)
    return np.sin(2 * np.pi * freq * t + index * np.exp(-t / 0.02) * np.sin(2 * np.pi * freq * ratio * t)) * env


def thump(freq, ms):
    t = t_axis(ms / 1000 * 3)
    return np.sin(2 * np.pi * freq * t) * np.exp(-t / (ms / 1000)) * (1 - np.exp(-t / 0.002))


def mix(*sounds):
    """Sum of mono sounds of different lengths (the shorter ones padded with silence)."""
    out = np.zeros(max(len(x) for x in sounds))
    for x in sounds:
        out[: len(x)] += x
    return out


def click(freq=4000, ms=4):
    t = t_axis(ms / 1000 * 3)
    return np.sin(2 * np.pi * freq * t) * np.exp(-t / (ms / 1000))


def riser(seconds, low=400, high=8000, seed=9):
    """White noise swept up through a band, plus a saw gliding D3 → D5 at −18 dB, swelling to the end."""
    rng = np.random.default_rng(seed)
    n = int(seconds * SR)
    x = rng.standard_normal(n)
    t = np.arange(n) / SR
    cut = low * (high / low) ** (t / seconds)
    y = np.empty(n)
    acc_lo = acc_hi = 0.0
    for i in range(n):
        a = np.exp(-2 * np.pi * cut[i] / SR)
        acc_lo = (1 - a) * x[i] + a * acc_lo
        b = np.exp(-2 * np.pi * cut[i] * 0.5 / SR)
        acc_hi = (1 - b) * x[i] + b * acc_hi
        y[i] = acc_lo - acc_hi
    f = note("D3") * (note("D5") / note("D3")) ** (t / seconds)
    saw = 2 * ((np.cumsum(f) / SR) % 1) - 1
    swell = (t / seconds) ** 2
    return (y * 3 + saw * db(-18)) * swell


def cue_lock():
    """Shots 11–13 of the main film (f1560–1919, 26–32 s), section D « Break » (bars 14–16), local frames 0–359.
    Drums out: sub and a filtered Bbmaj7 (A7sus4 from bar 16), a wood tick on each real second of the
    countdown (0, 60, 120, 180, 240, then 330 once the rest restarts); f90 lift (air pull, thump at the stop);
    music near-silent 258–270; f270 « Série faite » (haptic thump + glass, the blade's shimmer);
    f324 dock click; riser 300–358 and a one-frame suck before the Split."""
    frames = 360
    seconds = frames / FPS
    track = np.zeros((frames * SR // FPS, 2))
    music = np.zeros_like(track)
    bb = pad([note(n) for n in ("A#2", "D3", "F3", "A3")], 4.0 + 1.5, attack=0.8, release=1.5, cutoff=900)
    a7 = pad([note(n) for n in ("A2", "D3", "E3", "G3")], 2.0 + 1.5, attack=0.4, release=1.2, cutoff=900)
    place(music, reverb(bb, 4.0, 0.4)[: 260 * SR // FPS], 0, db(-21))
    place(music, reverb(a7, 4.0, 0.4), 240, db(-22))
    place(music, sub(note("A#1"), 4.2, attack=0.6, release=0.6), 0, db(-24))
    place(music, sub(note("A1"), 2.0, attack=0.3, release=0.8), 240, db(-24))
    # The designed near-silence before the tap (258–270), music only.
    gate = np.ones(len(music))
    a, b, c = 252 * SR // FPS, 258 * SR // FPS, 274 * SR // FPS
    gate[a:b] = np.linspace(1, 0.06, b - a)
    gate[b:c] = 0.06
    gate[c:c + SR // 4] = np.linspace(0.06, 1, SR // 4)
    track += music * gate[:, None]
    for f in (0, 60, 120, 180, 240, 330):
        place(track, fm_wood(note("A5")), f, db(-24))
    swell = noise_band(0.35, 300, 3000, seed=11)[::-1] * envelope(0.35, [(0, 0), (0.33, 1), (0.35, 0)])
    place(track, swell, 90 - 21, db(-30))
    place(track, thump(55, 40), 126, db(-16))
    place(track, mix(thump(150, 25), click() * db(-24)), 270, db(-12))
    place(track, reverb(fm_glass(note("A5"), index=2.5, decay=1.2), 3.0, 0.3), 270, db(-19))
    shimmer = noise_band(0.25, 4000, 9000, seed=12) * envelope(0.25, [(0, 0), (0.05, 1), (0.25, 0)])
    place(track, np.stack([shimmer * 0.6, shimmer], axis=1), 271, db(-30))
    place(track, mix(np.sin(2 * np.pi * 2000 * t_axis(0.015)) * np.hanning(int(0.015 * SR)), thump(70, 40)), 324, db(-18))
    place(track, riser(58 / FPS), 300, db(-26))
    track[358 * SR // FPS:] = 0
    return track


def cue_close():
    """Shots 24–25 of the main film (f3180–3479), local frames 0–299.
    f60: halves of the « A » open, D(add9) chord + D5 · f90: A5 (the eighth rest is the gap) ·
    f120: CTA bell · silent from f290."""
    frames = 300
    track = np.zeros((frames * SR // FPS, 2))
    tail = (frames - 60) / FPS
    chord = pad([note(n) for n in ("D3", "F#3", "A3", "E4")], tail, attack=0.6, release=2.2)
    place(track, reverb(chord, 4.5, 0.35), 60, db(-20))
    place(track, sub(note("D1"), (frames - 10) / FPS, attack=1.0, release=2.4), 0, db(-24))
    place(track, sub(note("D2"), tail, attack=0.05, release=2.4), 60, db(-26))
    place(track, reverb(fm_glass(note("D5")), 3.0, 0.3), 60, db(-15))
    place(track, reverb(fm_glass(note("A5")), 3.0, 0.3), 90, db(-15))
    place(track, reverb(fm_glass(note("A6"), index=2.0, decay=1.0), 3.0, 0.35), 120, db(-27))
    # Fade to silence by f290.
    fade_from, fade_to = 250 * SR // FPS, 290 * SR // FPS
    track[fade_from:fade_to] *= np.linspace(1, 0, fade_to - fade_from)[:, None]
    track[fade_to:] = 0
    return track


# --- v3 main film (45 s, 2026): hook cues, impact, logo, scan -----------------------------------------
def _norm(x, peak=1.0):
    m = np.abs(x).max()
    return x * (peak / m) if m > 0 else x


def cue_tic(freq=2300):
    """Clock tick of the hook: a dry wood click (tic = high, tac = low)."""
    return _norm(fm_wood(freq, 0.09, ratio=1.4, index=2.0))


def cue_cut(seed=41):
    """Cut whoosh on a beat of the hook: 0.3 s of air that peaks early, with a dry click on the cut."""
    n = int(0.3 * SR)
    air = noise_band(0.3, 900, 7500, seed) * envelope(0.3, [(0, 0), (0.04, 1), (0.3, 0)])
    out = np.zeros(n)
    out += air
    c = click(3200, 3)
    out[: len(c)] += c * 0.8
    return _norm(out)


def cue_notif(freq="E6"):
    """Notification pastille: two glass notes a fifth apart, 0.35 s."""
    a = fm_glass(note(freq), 0.4, index=2.0, decay=0.09)
    b = np.zeros_like(a)
    g = fm_glass(note("B6"), 0.32, index=1.5, decay=0.08)
    k = int(0.07 * SR)
    b[k:k + len(g)] = g[: len(b) - k]
    return _norm(reverb(a + 0.7 * b, 0.8, 0.2).mean(axis=1))


def cue_counter(seconds=1.4, steps=10):
    """Counter 1 -> 10 on « ten »: ten ticks whose pitch and level climb, spacing tightening a little."""
    out = np.zeros(int((seconds + 0.2) * SR))
    for k in range(steps):
        pos = seconds * (k / steps) ** 0.92 if k else 0.0
        f = 700 * (2600 / 700) ** (k / (steps - 1))
        tk = fm_wood(f, 0.08, ratio=1.4, index=2.0) * db(-12 + 12 * k / (steps - 1))
        i = int(pos * SR)
        out[i:i + len(tk)] += tk
    return _norm(out)


def cue_glitch():
    """Digital glitch at the end of the hook: stuttering sample-and-hold noise, 0.14 s, cut dead."""
    rng = np.random.default_rng(77)
    n = int(0.14 * SR)
    out = np.zeros(n)
    pos = 0
    while pos < n:
        ln = int(rng.integers(120, 1100))
        held = np.repeat(rng.standard_normal(max(1, ln // int(rng.integers(8, 40)) + 1)), int(rng.integers(8, 40)))[:ln]
        out[pos:pos + len(held)] += held[: n - pos] * (0.5 + rng.random() * 0.5)
        pos += ln + int(rng.integers(0, 1500)) * int(rng.random() < 0.6)
    buzz = np.sign(np.sin(2 * np.pi * 95 * t_axis(0.14))) * 0.4
    out = out + buzz[:n]
    out[-int(0.004 * SR):] *= np.linspace(1, 0, int(0.004 * SR))
    return _norm(out)


def cue_impact():
    """The suck-in flash: sub drop 110 -> 36 Hz, a noise crash that closes, a sharp crack and a D major shimmer;
    stereo, 3.6 s."""
    seconds = 3.6
    t = t_axis(seconds)
    f = 36 + 74 * np.exp(-t / 0.10)
    boom = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t / 1.0) * (1 - np.exp(-t / 0.002))
    boom += 0.5 * np.sin(2 * np.pi * np.cumsum(2 * f) / SR) * np.exp(-t / 0.3)
    crash = noise_band(seconds, 250, 9000, seed=88) * np.exp(-t / 0.28)
    low = noise_band(seconds, 40, 700, seed=89) * np.exp(-t / 0.7)
    crack = click(2800, 5)
    out = boom * 1.0 + crash * 0.55 + low * 0.6
    out[: len(crack)] += crack * 1.3
    out = np.tanh(out * 1.4)
    shim = np.zeros(len(t))
    for nn, g in (("D5", 1.0), ("F#5", 0.7), ("A5", 0.8), ("D6", 0.5)):
        s = fm_glass(note(nn), seconds - 0.06, index=2.5, decay=1.6)
        shim[0:0 + len(s)] += s * g
    shim = reverb(shim, 3.0, 0.45)
    stereo = np.stack([out, out], axis=1) + shim * 0.22
    return _norm(stereo)


def cue_logo_in():
    """The logo appears (« Meet Ardane »): bright glass sweep up, a D6 and A6 sparkle, a soft low thump; 1.8 s."""
    seconds = 1.8
    t = t_axis(seconds)
    sweep = noise_band(0.5, 2500, 11000, seed=91) * envelope(0.5, [(0, 0), (0.12, 1), (0.5, 0)])
    out = np.zeros(len(t))
    out[: len(sweep)] += sweep * 0.5
    out += thump(65, 60)[: len(t)] if len(thump(65, 60)) >= len(t) else np.pad(thump(65, 60), (0, len(t) - len(thump(65, 60))))
    g = fm_glass(note("D6"), seconds, index=2.5, decay=0.9) * 0.7
    g2 = np.zeros_like(g)
    k = int(0.09 * SR)
    g2[k:] = fm_glass(note("A6"), seconds, index=2.0, decay=0.8)[: len(g) - k] * 0.5
    return _norm(reverb(out + g + g2, 2.5, 0.35).mean(axis=1))


def cue_transition(seconds=1.0):
    """Transition whoosh: air that swells to 55 % of its length then falls away, with a low swell under it."""
    air = noise_band(seconds, 400, 9000, seed=95) * envelope(seconds, [(0, 0), (seconds * 0.55, 1), (seconds, 0)]) ** 1.5
    low = noise_band(seconds, 60, 500, seed=96) * envelope(seconds, [(0, 0), (seconds * 0.5, 1), (seconds, 0)])
    return _norm(air + 0.6 * low)


def cue_check():
    """Check mark: two rising glass notes, quick."""
    a = fm_glass(note("A5"), 0.5, index=2.0, decay=0.12)
    b = np.zeros_like(a)
    g = fm_glass(note("E6"), 0.4, index=2.0, decay=0.25)
    k = int(0.08 * SR)
    b[k:k + len(g)] = g[: len(b) - k]
    return _norm(reverb(a + b, 1.2, 0.25).mean(axis=1))


def cue_barcode():
    """Barcode scan: a burst of dry clicks (the laser line) then a clean 1.9 kHz beep of 90 ms; 0.45 s."""
    out = np.zeros(int(0.45 * SR))
    rng = np.random.default_rng(5)
    for k in range(9):
        c = click(3600 + 200 * k, 2) * (0.5 + rng.random() * 0.4)
        i = int(k * 0.018 * SR)
        out[i:i + len(c)] += c
    t = t_axis(0.09)
    beep = np.sin(2 * np.pi * 1900 * t) * np.hanning(len(t)) ** 0.5
    i = int(0.2 * SR)
    out[i:i + len(beep)] += beep * 0.9
    return _norm(out)


if __name__ == "__main__":
    cue, out = sys.argv[1:3]
    audio = {"opening": cue_opening, "lock": cue_lock, "close": cue_close, "impact": cue_impact, "logo_in": cue_logo_in,
             "glitch": cue_glitch, "barcode": cue_barcode, "check": cue_check}[cue]()
    peak = np.abs(audio).max()
    if peak > db(-1):
        audio *= db(-1) / peak
    sf.write(out, audio.astype(np.float32), SR, subtype="FLOAT")
    print(f"{cue}: {len(audio) / SR:.2f} s, peak {20 * np.log10(np.abs(audio).max() + 1e-12):.1f} dBFS")
