"""Instruments of the campaign score, synthesised in code (Concept-THE-OPENING §3.2), and the cues
built from them. 48 kHz stereo float WAV. Timeline: 120 BPM, a beat is 30 frames at 60 fps.

    python -X utf8 synth.py <cue> <out.wav>      cues: close
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


if __name__ == "__main__":
    cue, out = sys.argv[1:3]
    audio = {"close": cue_close}[cue]()
    peak = np.abs(audio).max()
    if peak > db(-1):
        audio *= db(-1) / peak
    sf.write(out, audio.astype(np.float32), SR, subtype="FLOAT")
    print(f"{cue}: {len(audio) / SR:.2f} s, peak {20 * np.log10(np.abs(audio).max() + 1e-12):.1f} dBFS")
