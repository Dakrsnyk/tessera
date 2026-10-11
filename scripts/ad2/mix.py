"""Final mix of the main film (Concept-THE-OPENING §3.3–3.4): the score (score.py), the SFX at their frames
(the sync points of the shot list), and the voice at its timecodes (vo_spec.json, takes from vo.py).

- Voice: high-pass 90 Hz, +1.5 dB at 3 kHz, 3:1 compression, plate 0.9 s at 6 %; −16 LUFS.
- Music ducks −6 dB under the voice (−3 dB in the S4 break), attack 30 ms, release 250 ms, 10 ms look-ahead,
  with a −2.5 dB dip at 2–4 kHz while she speaks.
- Master: −14 LUFS integrated, peaks under −1 dBFS. 48 kHz.

    python -X utf8 mix.py <score.wav> <vo dir> <out.wav> [--stems <dir>]
"""
import json
import os
import sys

import numpy as np
import pyloudnorm as pyln
import soundfile as sf
from scipy.signal import butter, resample_poly, sosfilt

from synth import SR, db, fm_glass, mix as mix_mono, noise_band, note, reverb, thump

FPS = 60
LENGTH = 3480 / FPS
HERE = os.path.dirname(os.path.abspath(__file__))


def t_axis(seconds):
    return np.arange(int(round(seconds * SR))) / SR


def filt(x, kind, freq, order=2):
    return sosfilt(butter(order, freq, btype=kind, fs=SR, output="sos"), x, axis=0)


def put(track, sound, frame, gain=1.0, pan=0.0):
    i = int(round(frame / FPS * SR))
    if sound.ndim == 1:
        left, right = np.cos((pan + 1) * np.pi / 4), np.sin((pan + 1) * np.pi / 4)
        sound = np.stack([sound * left, sound * right], axis=1) * np.sqrt(2)
    end = min(len(track), i + len(sound))
    if end > i:
        track[i:end] += sound[: end - i] * gain


# --- SFX (§3.3) ----------------------------------------------------------------------------------
def env(seconds, points):
    xs, ys = zip(*points)
    return np.interp(t_axis(seconds), xs, ys)


def whoosh(seconds=0.8, low=3000, high=8000, seed=5):
    return noise_band(seconds, low, high, seed) * env(seconds, [(0, 0), (seconds * 0.15, 1), (seconds, 0)])


def glass(n, index=3.0, decay=1.4, wet=0.35):
    return reverb(fm_glass(note(n), index=index, decay=decay), 3.0, wet)


def split_sfx():
    """Two noise bursts moving outward, one to each side (0.4 s), mono-safe (each also faint in the other side)."""
    grow = np.linspace(0.5, 1, int(round(0.4 * SR)))
    left = whoosh(0.4, 1500, 7000, seed=21) * grow
    right = whoosh(0.4, 1500, 7000, seed=22) * grow
    return np.stack([left + right * 0.25, right + left * 0.25], axis=1)


def blade_shimmer(seed=12, direction=1):
    """Filtered noise sweep whose pan follows the blade (left → right by default)."""
    s = noise_band(0.3, 4000, 9000, seed) * env(0.3, [(0, 0), (0.05, 1), (0.3, 0)])
    pan = np.linspace(-1, 1, len(s)) * direction
    return np.stack([s * np.cos((pan + 1) * np.pi / 4), s * np.sin((pan + 1) * np.pi / 4)], axis=1) * np.sqrt(2)


def air_pull():
    """Reversed reverb swell, 0.35 s."""
    return noise_band(0.35, 300, 3000, seed=11)[::-1] * env(0.35, [(0, 0), (0.33, 1), (0.35, 0)])


def dock_click():
    c = np.sin(2 * np.pi * 2000 * t_axis(0.015)) * np.hanning(int(round(0.015 * SR)))
    return mix_mono(c, thump(70, 40))


def tap_pulse():
    t = t_axis(0.012)
    return mix_mono(thump(150, 25), np.sin(2 * np.pi * 4000 * t) * np.exp(-t / 0.004) * db(-24))


def tick():
    t = t_axis(0.12)
    f = note("A5")
    return np.sin(2 * np.pi * f * t + 2.5 * np.exp(-t / 0.02) * np.sin(2 * np.pi * f * 1.4 * t)) * (1 - np.exp(-t / 0.001)) * np.exp(-t / 0.03)


def light_on():
    t = t_axis(0.06)
    return mix_mono(np.sin(2 * np.pi * 90 * t) * np.exp(-t / 0.02), whoosh(0.9, 5000, 12000, seed=31) * 0.5)


def main_events():
    """The SFX of the main film: (frame, sound, gain dB, pan), on the sync points of the shot list."""
    ev = []

    def put(_tr, sound, frame, gain=1.0, pan=0.0):
        ev.append((frame, sound, gain, pan))

    tr = None  # the events are placed later, by sfx_track
    # S1
    put(tr, glass("D6"), 6, db(-20))
    put(tr, whoosh(0.9), 6, db(-30))
    put(tr, whoosh(1.2, 400, 2500, seed=6)[::-1], 120 - 70, db(-32))  # screen wake swell
    put(tr, blade_shimmer(13), 180, db(-34))  # light sweep across the glass
    # S2
    put(tr, split_sfx(), 360, db(-26))
    for f in (540, 600, 660, 720, 780):
        put(tr, blade_shimmer(f), f, db(-28))
    put(tr, dock_click(), 840, db(-18))
    # S3
    put(tr, air_pull(), 960 - 21, db(-28))
    put(tr, thump(55, 40), 1008, db(-16))
    put(tr, blade_shimmer(1110), 1110, db(-28))
    put(tr, whoosh(0.3, 800, 4000, seed=41), 1350, db(-32))  # push to the exercise detail
    put(tr, mix_mono(thump(45, 120), glass("D5", index=2.0)[:, 0]), 1410, db(-16))  # the figure steps out
    # S4: the real countdown, a tick per second, on the beats; the lift, the tap, the dock.
    for f in (1560, 1620, 1680, 1740, 1800, 1890):
        put(tr, tick(), f, db(-24))
    put(tr, air_pull(), 1650 - 21, db(-30))
    put(tr, thump(55, 40), 1686, db(-16))
    put(tr, tap_pulse(), 1830, db(-12))
    put(tr, glass("A5", index=2.5, decay=1.2, wet=0.3), 1830, db(-19))
    put(tr, blade_shimmer(1831), 1831, db(-30))
    put(tr, dock_click(), 1890, db(-18))
    # S5
    put(tr, light_on(), 1920, db(-18))
    put(tr, tap_pulse(), 2070, db(-14))
    put(tr, whoosh(0.45, 600, 3000, seed=51), 2100, db(-32))  # app opens from the widget
    put(tr, glass("A5", index=2.0), 2190, db(-20))  # recognition (the app makes no scan sound)
    put(tr, tap_pulse(), 2310, db(-14))
    put(tr, blade_shimmer(2370), 2370, db(-28))
    put(tr, split_sfx(), 2340, db(-28))
    # S6
    put(tr, blade_shimmer(2521, direction=1), 2521, db(-27))  # ledger sweep L → R
    put(tr, whoosh(0.3, 1000, 6000, seed=61), 2700, db(-28))  # page swipe
    put(tr, tap_pulse(), 2790, db(-15))  # habit check
    put(tr, split_sfx(), 2880, db(-28))
    # S7: the merge (four docks, 4 frames apart), the edge turn, the sound logo, the CTA bell.
    for k in range(4):
        put(tr, dock_click(), 3120 + 4 * k, db(-20))
    put(tr, whoosh(0.9, 2000, 7000, seed=71), 3180, db(-30))
    put(tr, glass("D5", index=4.0, decay=1.6, wet=0.3), 3240, db(-15))
    put(tr, glass("A5", index=4.0, decay=1.6, wet=0.3), 3270, db(-15))
    put(tr, glass("A6", index=2.0, decay=1.0, wet=0.35), 3300, db(-27))
    return ev




def sfx_track(events, length_frames):
    tr = np.zeros((int(length_frames / FPS * SR), 2))
    for frame, sound, gain, pan in events:
        put(tr, sound, frame, gain, pan)
    tr[int((length_frames - 10) / FPS * SR):] = 0
    return tr


# --- Voice -----------------------------------------------------------------------------------------
def voice_chain(x):
    x = filt(x, "highpass", 90)
    # +1.5 dB presence around 3 kHz.
    x = x + filt(x, "bandpass", [2200, 4200]) * (db(1.5) - 1)
    # 3:1 compression above −24 dBFS (RMS over 10 ms, attack 5 ms, release 80 ms).
    level = np.sqrt(np.convolve(x ** 2, np.ones(480) / 480, mode="same") + 1e-12)
    over = np.maximum(20 * np.log10(level) + 24, 0)
    gain_db = -over * (1 - 1 / 3)
    smooth = np.empty_like(gain_db)
    acc = 0.0
    att, rel = np.exp(-1 / (0.005 * SR)), np.exp(-1 / (0.08 * SR))
    for i, g in enumerate(gain_db):
        coef = att if g < acc else rel
        acc = coef * acc + (1 - coef) * g
        smooth[i] = acc
    x = x * db(smooth)
    return reverb(x, 0.9, 0.06)


def voice_track(vo_dir, film="main", length=LENGTH):
    spec = json.load(open(os.path.join(HERE, "vo_spec.json"), encoding="utf-8"))
    n = int(length * SR)
    tr = np.zeros(n)
    for chunk in spec["films"][film]["chunks"]:
        for line in chunk:
            audio, sr = sf.read(os.path.join(vo_dir, f"{film}-{line['id']}.wav"), dtype="float64")
            if audio.ndim > 1:
                audio = audio.mean(axis=1)
            audio = resample_poly(audio, SR, sr) if sr != SR else audio
            i = int(round(line["start"] * SR))
            end = min(n, i + len(audio))
            tr[i:end] += audio[: end - i]
    meter = pyln.Meter(SR)
    tr = voice_chain(tr)
    voiced = tr[np.abs(tr).mean(axis=1) > 1e-4]
    tr *= db(-16 - meter.integrated_loudness(voiced))
    return tr


def duck_envelope(voice):
    """1 where she speaks (with 10 ms look-ahead), 0 elsewhere; attack 30 ms, release 250 ms."""
    level = np.sqrt(np.convolve(voice.mean(axis=1) ** 2, np.ones(960) / 960, mode="same"))
    active = (level > db(-45)).astype(float)
    ahead = int(0.01 * SR)
    active = np.concatenate([active[ahead:], np.zeros(ahead)])
    out = np.empty_like(active)
    acc = 0.0
    att, rel = np.exp(-1 / (0.03 * SR)), np.exp(-1 / (0.25 * SR))
    for i, a in enumerate(active):
        coef = att if a > acc else rel
        acc = coef * acc + (1 - coef) * a
        out[i] = acc
    return out


def limit(x, ceiling, lookahead=0.005, release=0.08):
    """Look-ahead peak limiter: the gain falls before each peak (sliding minimum over 5 ms) and recovers
    in 80 ms, so nothing passes the ceiling and nothing clips."""
    from scipy.ndimage import minimum_filter1d
    peak = np.abs(x).max(axis=1)
    need = np.minimum(1.0, ceiling / np.maximum(peak, 1e-9))
    w = int(lookahead * SR)
    need = minimum_filter1d(need, size=2 * w + 1)
    gain = np.empty_like(need)
    acc = 1.0
    rel = np.exp(-1 / (release * SR))
    for i, g in enumerate(need):
        acc = g if g < acc else rel * acc + (1 - rel) * g
        gain[i] = acc
    # Smooth the attack over the look-ahead window so the gain never steps.
    gain = np.convolve(gain, np.ones(w) / w, mode="same")
    return x * np.minimum(gain, need)[:, None]


def master(music, sfx, voice, breaks=()):
    """Ducks the music under the voice (−6 dB, −3 dB in `breaks`, the 2–4 kHz dip), sums, −14 LUFS."""
    n = len(music)
    d = duck_envelope(voice)
    depth = np.full(n, db(-6))
    for a, b in breaks:
        depth[int(a * SR):int(b * SR)] = db(-3)
    gain = 1 - (1 - depth) * d
    mid = filt(music, "bandpass", [2000, 4000])
    music = music * gain[:, None] - mid * (1 - db(-2.5)) * d[:, None]
    mixdown = music + sfx + voice
    meter = pyln.Meter(SR)
    # −14 LUFS with peaks under −1 dBFS: gain, then a look-ahead limiter, three times (the limiter costs a little).
    for _ in range(3):
        mixdown *= db(-14 - meter.integrated_loudness(mixdown))
        mixdown = limit(mixdown, db(-1.2))
    return mixdown, music


# --- Cut-downs (src/films/cuts.json) --------------------------------------------------------------
SCENE_LENGTH = {"Opening": 360, "Universes": 600, "Fitness": 600, "LockScreen": 360, "Nutrition": 600, "Essentials": 360, "Gather": 300, "Close": 300}
SCENE_LENGTH.update({"LineOpen": 270, "MyDay": 660, "FitnessCold": 240, "Build": 360, "StyleCycle": 240, "LockIcon": 180, "FivePhones": 180})
# Peaks (merge-like hits) of the cut-down scenes, in scene frames.
SCENE_HITS = {"Gather": [240], "FivePhones": [165]}
# Universe changes of the scenes that change universes (the strata arp follows them).
SCENE_UNIVERSES = {
    "Universes": [(0, "aurora"), (180, "space"), (240, "paper"), (300, "neon"), (360, "minimal"), (420, "sunset")],
    "LineOpen": [(0, "aurora"), (60, "neon"), (90, "paper"), (120, "sunset")],
    "Build": [(0, "aurora")],
    "StyleCycle": [(0, "sunset"), (60, "space"), (90, "neon"), (120, "paper"), (150, "aurora"), (180, "minimal"), (210, "sunset")],
}


def extra_events(scene, props):
    """SFX of the scenes made for the cut-downs (scene frames), and of props that add a moment."""
    ev = []
    if scene == "LineOpen":
        ev += [(6, glass("D6"), db(-20), 0), (6, whoosh(0.9), db(-30), 0)]
        ev += [(f, blade_shimmer(f), db(-28), 0) for f in (50, 80, 110)]
        ev += [(150 - 21, air_pull(), db(-28), 0), (186, thump(55, 40), db(-16), 0), (270, dock_click(), db(-18), 0)]
    if scene == "MyDay":
        ev += [(6, glass("D6"), db(-21), 0), (6, whoosh(0.9), db(-31), 0)]
        ev += [(f, whoosh(0.5, 600, 3000, seed=f), db(-31), 0) for f in (120, 300, 480)]
        ev += [(624, whoosh(0.9, 2000, 7000, seed=81), db(-30), 0)]
    if scene == "FitnessCold":
        ev += [(0, thump(45, 120), db(-16), 0)]
        ev += [(f, tick(), db(-22), 0) for f in (0, 60, 120, 180)]
        ev += [(f, blade_shimmer(f), db(-29), 0) for f in (30, 90, 150)]
    if scene == "Build":
        ev += [(20, glass("D6"), db(-21), 0), (20, whoosh(0.9), db(-31), 0)]
        ev += [(f, dock_click(), db(-19), 0) for f in (150, 180, 210, 240)]
        ev += [(250 + 6 * i, tap_pulse(), db(-26), 0) for i in range(4)]
    if scene == "StyleCycle":
        ev += [(-21 + 21, air_pull(), db(-30), 0), (36, thump(55, 40), db(-17), 0)]
        ev += [(f - 10, blade_shimmer(f), db(-29), 0) for f in (60, 90, 120, 150, 180, 210)]
        ev += [(240, dock_click(), db(-18), 0)]
    if scene == "LockIcon":
        ev += [(8, whoosh(0.5, 800, 4000, seed=91), db(-30), 0)]
        ev += [(f - 10, blade_shimmer(f), db(-29), 0) for f in (70, 100, 130)]
    if scene == "FivePhones":
        ev += [(100, whoosh(0.9, 1500, 6000, seed=95), db(-29), 0)] + [(165 + 4 * i, dock_click(), db(-20), 0) for i in range(4)]
    if scene == "Fitness" and props.get("tapAt") is not None:
        t = props["tapAt"]
        ev += [(t, tap_pulse(), db(-12), 0), (t, glass("A5", index=2.5, decay=1.2, wet=0.3), db(-20), 0), (t + 1, blade_shimmer(t), db(-30), 0)]
    return ev


def load_cuts():
    for path in (os.path.join(os.path.expanduser("~"), "ardane-tools", "film", "src", "films", "cuts.json"),
                 os.path.join(HERE, "film", "src", "films", "cuts.json")):
        if os.path.exists(path):
            return json.load(open(path, encoding="utf-8"))
    raise SystemExit("cuts.json not found")


def map_scene_frame(seg, local):
    """Output frame of a scene frame inside a segment (inverse of its remap), or None if outside."""
    if not (seg["output"][0] <= local <= seg["output"][-1]):
        return None
    return seg["at"] + float(np.interp(local, seg["output"], seg["input"]))


def cut_plan(film):
    cuts = load_cuts()
    plan = cuts["films"][film]
    starts = cuts["sceneStart"]
    segs = plan["segments"]
    events = []
    by_scene = {}
    for frame, sound, gain, pan in main_events():
        scene = next(k for k, v in starts.items() if v <= frame < v + SCENE_LENGTH[k])
        by_scene.setdefault(scene, []).append((frame - starts[scene], sound, gain, pan))
    for seg in segs:
        for local, sound, gain, pan in by_scene.get(seg["scene"], []) + extra_events(seg["scene"], seg.get("props", {})):
            out = map_scene_frame(seg, local)
            if out is not None:
                events.append((int(round(out)), sound, gain, pan))
    universes = []
    hits = []
    for seg in segs:
        for f, timbre in SCENE_UNIVERSES.get(seg["scene"], []):
            out = map_scene_frame(seg, f) if f > seg["output"][0] else (seg["at"] if f <= seg["output"][0] else None)
            if out is not None:
                universes.append((out / FPS, timbre))
        for f in SCENE_HITS.get(seg["scene"], []):
            out = map_scene_frame(seg, f)
            if out is not None:
                hits.append(out / FPS)
    risers = [(seg["at"] / FPS, 1.0) for seg in segs if seg.get("transition") == "split"] + [(h, 1.75) for h in hits]
    breaks = [(s["start"], s["end"]) for s in plan["music"] if s["type"] == "break"]
    return plan, events, universes, hits, risers, breaks


def main():
    stems = sys.argv[sys.argv.index("--stems") + 1] if "--stems" in sys.argv else None
    if sys.argv[1] == "cut":
        # python mix.py cut <film> <vo dir> <out.wav>
        from score import score_cut
        film, vo_dir, out = sys.argv[2:5]
        plan, events, universes, hits, risers, breaks = cut_plan(film)
        length = plan["length"] / FPS
        music = score_cut(length, plan["music"], universes=universes, hits=hits, risers=risers)
        meter = pyln.Meter(SR)
        music *= db(-20 - meter.integrated_loudness(music))
        voice = voice_track(vo_dir, plan["vo"], length)
        sfx = sfx_track(events, plan["length"])
        mixdown, music = master(music, sfx, voice, breaks)
    else:
        # python mix.py <score.wav> <vo dir> <out.wav>: the main film.
        score_path, vo_dir, out = sys.argv[1:4]
        music, sr = sf.read(score_path, dtype="float64")
        assert sr == SR
        n = int(LENGTH * SR)
        music = np.pad(music, ((0, max(0, n - len(music))), (0, 0)))[:n]
        voice = voice_track(vo_dir)
        sfx = sfx_track(main_events(), 3480)
        mixdown, music = master(music, sfx, voice, breaks=[(26, 32)])
    sf.write(out, mixdown.astype(np.float32), SR, subtype="FLOAT")
    if stems:
        os.makedirs(stems, exist_ok=True)
        for name, x in (("music", music), ("sfx", sfx), ("voice", voice)):
            sf.write(os.path.join(stems, f"{name}.wav"), x.astype(np.float32), SR, subtype="FLOAT")
    meter = pyln.Meter(SR)
    print(f"mix: {len(mixdown) / SR:.2f} s, {meter.integrated_loudness(mixdown):.1f} LUFS, peak {20 * np.log10(np.abs(mixdown).max()):.1f} dBFS")


if __name__ == "__main__":
    main()
