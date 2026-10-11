"""Original music and sound effects for the Tessera campaign (synthesized, royalty free).

    python3 synth.py <out dir>

Music: 100 BPM (bar = 2.4 s), warm minimal electronic: pad, pluck arpeggio, sub bass, soft kick,
clap, hats. Each film has its own arrangement on the same grid, so cuts land on beats.
SFX: tap, snap (a tile clicking into place), whoosh, chime, lock, rise, impact.
"""
import sys, os, json
import numpy as np
from scipy.signal import butter, sosfilt, fftconvolve
import wave

SR = 48000
BPM = 100.0
BEAT = 60.0 / BPM
BAR = BEAT * 4
rng = np.random.default_rng(7)


def write_wav(path, x):
    x = np.clip(x, -1, 1)
    if x.ndim == 1:
        x = np.stack([x, x], axis=1)
    data = (x * 32767).astype(np.int16)
    with wave.open(path, "wb") as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())


def t_(dur):
    return np.arange(int(dur * SR)) / SR


def lp(x, f, order=2):
    return sosfilt(butter(order, min(f, SR / 2 - 100), "low", fs=SR, output="sos"), x, axis=0)


def hp(x, f, order=2):
    return sosfilt(butter(order, f, "high", fs=SR, output="sos"), x, axis=0)


def bp(x, lo, hi, order=2):
    return sosfilt(butter(order, [lo, min(hi, SR / 2 - 100)], "band", fs=SR, output="sos"), x, axis=0)


def midi(n):
    return 440.0 * 2 ** ((n - 69) / 12)


def env_adsr(n, a, d, s, r, sustain_len):
    a_n, d_n, r_n = int(a * SR), int(d * SR), int(r * SR)
    s_n = max(0, int(sustain_len * SR) - a_n - d_n)
    e = np.concatenate([
        np.linspace(0, 1, max(a_n, 1), endpoint=False),
        np.linspace(1, s, max(d_n, 1), endpoint=False),
        np.full(s_n, s),
        np.linspace(s, 0, max(r_n, 1)),
    ])
    if len(e) < n:
        e = np.concatenate([e, np.zeros(n - len(e))])
    return e[:n]


def make_ir(seconds=2.2, decay=3.2, bright=6000):
    n = int(seconds * SR)
    t = np.arange(n) / SR
    ir = rng.standard_normal((n, 2)) * np.exp(-decay * t)[:, None]
    ir = lp(ir, bright)
    ir[: int(0.012 * SR)] *= np.linspace(0, 1, int(0.012 * SR))[:, None]
    return ir / np.sqrt(np.sum(ir ** 2))


IR = make_ir()


def reverb(x, wet=0.22):
    if x.ndim == 1:
        x = np.stack([x, x], axis=1)
    y = np.stack([fftconvolve(x[:, 0], IR[:, 0])[: len(x)], fftconvolve(x[:, 1], IR[:, 1])[: len(x)]], axis=1)
    return x * (1 - wet) + y * wet * 2.2


def place(buf, sig, at):
    i = int(at * SR)
    if i >= len(buf):
        return
    sig = sig[: len(buf) - i]
    if sig.ndim == 1 and buf.ndim == 2:
        sig = np.stack([sig, sig], axis=1)
    buf[i:i + len(sig)] += sig


# ---------------------------------------------------------------- instruments

def kick(vel=1.0):
    t = t_(0.45)
    f = 46 + 110 * np.exp(-t * 28)
    ph = 2 * np.pi * np.cumsum(f) / SR
    body = np.sin(ph) * np.exp(-t * 7.5)
    click = hp(rng.standard_normal(len(t)) * np.exp(-t * 400), 2500) * 0.25
    return (body * 0.32 + click * 0.7) * vel


def clap(vel=1.0):
    t = t_(0.35)
    n = rng.standard_normal(len(t))
    e = np.zeros(len(t))
    for k, off in enumerate([0, 0.011, 0.022]):
        i = int(off * SR)
        e[i:] += np.exp(-(t[: len(t) - i]) * (180 if k < 2 else 22))
    return bp(n * e, 900, 5200) * 0.42 * vel


def hat(open_=False, vel=1.0):
    t = t_(0.25 if open_ else 0.06)
    n = rng.standard_normal(len(t)) * np.exp(-t * (14 if open_ else 70))
    return hp(n, 7500, 4) * 0.2 * vel


def bass(note, dur):
    t = t_(dur + 0.08)
    f = midi(note)
    x = np.sin(2 * np.pi * f * t) + 0.25 * np.sin(4 * np.pi * f * t) + 0.08 * np.sin(6 * np.pi * f * t)
    x = np.tanh(1.6 * x) / np.tanh(1.6)
    return hp(lp(x, 380), 38) * env_adsr(len(t), 0.008, 0.18, 0.75, 0.08, dur) * 0.11


def supersaw(f, t, voices=7, spread=0.14):
    x = np.zeros(len(t))
    for v in range(voices):
        det = (v - (voices - 1) / 2) / ((voices - 1) / 2) * spread
        fv = f * 2 ** (det / 12)
        ph = rng.random()
        x += 2 * ((fv * t + ph) % 1.0) - 1
    return x / voices


def pad(notes, dur, bright=1400):
    t = t_(dur + 1.2)
    l = np.zeros(len(t)); r = np.zeros(len(t))
    for i, n in enumerate(notes):
        s1 = supersaw(midi(n), t)
        s2 = supersaw(midi(n) * 1.0015, t)
        l += s1; r += s2
    lfo = 1 + 0.25 * np.sin(2 * np.pi * 0.18 * t)
    x = np.stack([l, r], axis=1) / len(notes)
    x = hp(lp(x, bright, 2), 140)
    x = lp(x, bright * 1.2, 2) * lfo[:, None]
    e = env_adsr(len(t), 0.7, 0.4, 0.85, 1.1, dur)
    return x * e[:, None] * 0.55


def pluck(note, vel=1.0):
    t = t_(0.7)
    f = midi(note)
    x = 0.6 * (2 * ((f * t) % 1.0) - 1) + 0.4 * np.sign(np.sin(2 * np.pi * f * t))
    # Filter that closes quickly: render in two bands and crossfade.
    bright = lp(x, 5200); dark = lp(x, 700)
    k = np.exp(-t * 14)
    y = bright * k + dark * (1 - k)
    return y * np.exp(-t * 6.5) * 0.5 * vel


def delay(x, time, feedback=0.35, mix=0.3):
    if x.ndim == 1:
        x = np.stack([x, x], axis=1)
    d = int(time * SR)
    y = x.copy()
    out = x.copy()
    gain = mix
    for k in range(1, 5):
        sh = np.zeros_like(x)
        if d * k < len(x):
            sh[d * k:] = x[: len(x) - d * k]
        # Ping-pong: odd repeats left, even right.
        side = np.array([1.0, 0.35]) if k % 2 else np.array([0.35, 1.0])
        out += sh * gain * side
        gain *= feedback
    return out


def riser(dur):
    t = t_(dur)
    n = rng.standard_normal(len(t))
    out = np.zeros(len(t))
    steps = 24
    for k in range(steps):
        a, b = int(k * len(t) / steps), int((k + 1) * len(t) / steps)
        f = 400 * (12 ** (k / steps))
        seg = bp(n[max(0, a - 2000):b], f, f * 2.2)[-(b - a):]
        out[a:b] = seg
    return out * np.linspace(0, 1, len(t)) ** 2 * 0.35


def impact():
    t = t_(2.6)
    boom = np.sin(2 * np.pi * (38 + 60 * np.exp(-t * 9)) * t) * np.exp(-t * 2.2)
    crash = lp(hp(rng.standard_normal(len(t)), 300), 6000) * np.exp(-t * 3.0) * 0.35
    return reverb(boom * 0.9 + crash, 0.3)


# ---------------------------------------------------------------- arrangement

# Fmaj7 – G6 – Em7 – Am7 (two beats on the last chord's upper voices).
CHORDS = [
    (41, [53, 57, 60, 64]),
    (43, [55, 59, 62, 64]),
    (40, [52, 55, 59, 62]),
    (45, [57, 60, 64, 67]),
]
ARP = [0, 2, 3, 1, 2, 3, 1, 2]


def render_track(sections, total, impact_at=None, out_tail=True):
    """sections: list of (bars, level). Levels: 0 pad only, 1 pad+pluck, 2 +hats+bass,
    3 full (kick, clap), 4 full with open hats. A riser leads into each section of level >= 3."""
    n = int((total + 3) * SR)
    music = np.zeros((n, 2)); drums = np.zeros((n, 2)); bassbus = np.zeros(n)
    kicks = []
    bar_i = 0
    t0 = 0.0
    prev = 0
    for bars, level in sections:
        if level >= 3 and prev < 3 and t0 >= BAR:
            place(music, np.stack([riser(BAR)] * 2, axis=1), t0 - BAR)
        for b in range(bars):
            root, notes = CHORDS[bar_i % 4]
            start = t0 + b * BAR
            place(music, pad(notes, BAR, 1100 if level < 2 else 1600), start)
            if level >= 1:
                arp = np.zeros(int((BAR + 1) * SR))
                for k in range(8):
                    nn = notes[ARP[k]] + 12
                    place(arp, pluck(nn, 0.85 if k % 2 else 1.0), k * BEAT / 2)
                place(music, delay(arp, BEAT * 0.75, 0.38, 0.28), start)
            if level >= 2:
                for k in range(4):
                    place(bassbus, bass(root, BEAT * 0.9), start + k * BEAT)
                for k in range(8):
                    place(drums, hat(False, 0.7 if k % 2 == 0 else 1.0), start + k * BEAT / 2 + (0.018 if k % 2 else 0))
            if level >= 3:
                for k in range(4):
                    place(drums, kick(), start + k * BEAT)
                    kicks.append(start + k * BEAT)
                for k in (1, 3):
                    place(drums, clap(), start + k * BEAT)
            if level >= 4:
                for k in range(4):
                    place(drums, hat(True, 0.6), start + k * BEAT + BEAT / 2)
        bar_i += bars
        t0 += bars * BAR
        prev = level
    # Sidechain: the music and bass breathe with the kick.
    duck = np.ones(n)
    for k in kicks:
        i = int(k * SR); m = int(0.28 * SR)
        seg = 1 - 0.55 * np.exp(-np.arange(m) / SR * 12)
        duck[i:i + m] = np.minimum(duck[i:i + m], seg[: len(duck[i:i + m])])
    music = reverb(music, 0.2) * duck[:, None]
    bassbus = bassbus * duck
    mix = music + drums + np.stack([bassbus, bassbus], axis=1)
    if impact_at is not None:
        place(mix, impact() * 0.8, impact_at)
    mix = mix[: int(total * SR)]
    # Fade out the last 1.2 s.
    f = int(min(1.2, total / 4) * SR)
    mix[-f:] *= np.linspace(1, 0, f)[:, None] ** 1.5
    return master(mix)


def master(x, target_rms=0.13):
    x = hp(x, 30)
    # Gentle glue compression on the RMS envelope.
    rms = np.sqrt(lp(np.mean(x ** 2, axis=1), 3, 1).clip(1e-9))
    ref = np.percentile(rms[rms > 1e-4], 90) if np.any(rms > 1e-4) else 1.0
    # Upward and downward: sections far below the loudest are lifted (up to +9 dB), peaks tamed.
    gain = np.clip((ref / rms) ** 0.45, 0.6, 2.8)
    x = x * gain[:, None]
    cur = np.sqrt(np.mean(x ** 2))
    x = x * (target_rms / max(cur, 1e-6))
    x = np.tanh(x * 1.1) / np.tanh(1.1)
    return x / max(1e-6, np.max(np.abs(x))) * 0.89


# ---------------------------------------------------------------- sound effects

def sfx_tap():
    t = t_(0.09)
    tone = np.sin(2 * np.pi * 1850 * t) * np.exp(-t * 90)
    click = hp(rng.standard_normal(len(t)) * np.exp(-t * 600), 3000) * 0.5
    return reverb((tone * 0.5 + click) * 0.5, 0.12)


def sfx_snap():
    t = t_(0.25)
    knock = np.sin(2 * np.pi * (520 + 300 * np.exp(-t * 60)) * t) * np.exp(-t * 38)
    click = bp(rng.standard_normal(len(t)) * np.exp(-t * 300), 1500, 7000) * 0.6
    return reverb((knock * 0.7 + click) * 0.55, 0.15)


def sfx_whoosh(dur=0.7):
    t = t_(dur)
    n = rng.standard_normal(len(t))
    out = np.zeros(len(t)); steps = 20
    for k in range(steps):
        a, b = int(k * len(t) / steps), int((k + 1) * len(t) / steps)
        x = k / steps
        f = 300 + 3500 * np.sin(np.pi * x) ** 2
        out[a:b] = bp(n[max(0, a - 1500):b], f, f * 1.8)[-(b - a):]
    env = np.sin(np.pi * np.linspace(0, 1, len(t))) ** 1.5
    st = np.stack([out * env * np.linspace(1.2, 0.6, len(t)), out * env * np.linspace(0.6, 1.2, len(t))], axis=1)
    return st * 0.45


def sfx_chime():
    t = t_(1.6)
    x = np.zeros(len(t))
    for f, a, d in [(1318.5, 0.5, 3.0), (1975.5, 0.35, 3.6), (2637, 0.18, 4.5)]:
        x += a * np.sin(2 * np.pi * f * t) * np.exp(-t * d)
    second = np.zeros(len(t)); off = int(0.11 * SR)
    for f, a, d in [(1760, 0.45, 3.0), (2637, 0.25, 3.8)]:
        second[off:] += a * np.sin(2 * np.pi * f * t[: len(t) - off]) * np.exp(-t[: len(t) - off] * d)
    return reverb((x + second) * 0.32, 0.3)


def sfx_lock():
    t = t_(0.12)
    a = hp(rng.standard_normal(len(t)) * np.exp(-t * 250), 1200) * 0.6
    b = np.sin(2 * np.pi * 420 * t) * np.exp(-t * 80) * 0.5
    return reverb((a + b) * 0.5, 0.1)


def sfx_rise(dur=1.2):
    return np.stack([riser(dur)] * 2, axis=1) * 1.4


if __name__ == "__main__":
    out = sys.argv[1] if len(sys.argv) > 1 else "."
    os.makedirs(out, exist_ok=True)
    for name, fn in [("tap", sfx_tap), ("snap", sfx_snap), ("whoosh", sfx_whoosh), ("chime", sfx_chime),
                     ("lock", sfx_lock), ("rise", sfx_rise), ("impact", impact)]:
        write_wav(os.path.join(out, f"sfx-{name}.wav"), fn())
    if len(sys.argv) > 2:
        spec = json.loads(open(sys.argv[2]).read())
        for name, s in spec.items():
            x = render_track([tuple(v) for v in s["sections"]], s["total"], s.get("impact"))
            write_wav(os.path.join(out, f"music-{name}.wav"), x)
            print(name, round(len(x) / SR, 2), "s")
