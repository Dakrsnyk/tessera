"""Audio of the 2026 campaign (chantier 19.4): the score of each of the 10 films, the SFX on the shots of the
storyboards, the voice (pub/vo2026/<lang>/<film>/, from vo.py / vo_fr.py) and the final mix, one WAV per film
and per language: pub/film2026/audio/<lang>/mix-<film>.wav (48 kHz stereo float, exact length, -14 LUFS).

The music is the original synthesised score (score.py: 120 BPM, D minor -> D major) cut to each film: sections
per storyboard (docs/memoire/campagne-2026/0*.md), a slow rise over the whole film, a riser into the logo, then
0.4 s of silence, then the signature D5 . rest . A5 on the logo and 0.3 s of silence at the very end.

    python -X utf8 audio2026.py music <film> <out.wav>             music stem only
    python -X utf8 audio2026.py mix <lang> <film|all> [--stems]    voice + music + SFX -> pub/film2026/audio/<lang>/
"""
import json
import os
import sys

import numpy as np
import pyloudnorm as pyln
import soundfile as sf
from scipy.signal import resample_poly

import mix as M
from score import score_cut
from synth import SR, db, fm_glass, note, reverb, sub, thump, noise_band

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
SPEC = {l: os.path.join(ROOT, "scripts", "ad3", "spec", f"vo_spec_{l}.json") for l in ("en", "fr")}
VO_DIR = os.path.join(ROOT, "pub", "vo2026")
OUT_DIR = os.path.join(ROOT, "pub", "film2026", "audio")
FPS = 60

# Voice about 12 dB above the music while she speaks (brief: 8 to 19 dB), master -14 LUFS.
MUSIC_BED_LUFS = -23.0   # the score before ducking (voice is at -16 LUFS)
DUCK_DB = -5.0
END_SILENCE = 0.3        # last 0.3 s silent
PRE_LOGO_SILENCE = 0.4   # nothing between the riser and the logo signature

# length, logo (start of the close card), music sections, arp timbre changes, SFX [(s, name, dB, pan)].
# Sections follow the plans of the storyboards; every section ends where the next begins.
FILMS = {
    "main": dict(length=45.0, logo=39.0, sections=[
        ("void", 0, 3.4), ("strata", 3.4, 10.0), ("pulse", 10.0, 17.5), ("design", 17.5, 25.0),
        ("daylight", 25.0, 32.5), ("run", 32.5, 38.6)],
        universes=[(3.4, "aurora"), (7.0, "space"), (17.5, "minimal"), (19.0, "aurora"), (21.0, "neon"), (23.0, "space")],
        sfx=[(0.1, "glassD6", -20, 0), (0.1, "whoosh", -30, 0), (2.9, "split", -26, 0), (4.5, "wake", -32, 0),
             (6.3, "blade", -28, -.6), (7.8, "blade", -28, -.2), (9.3, "blade", -28, .2), (10.8, "blade", -28, .6),
             (12.3, "dock", -18, 0), (12.5, "pull", -28, 0), (13.5, "swipe", -29, 0), (15.0, "swipe", -29, 0),
             (16.5, "swipe", -29, 0), (17.4, "split", -28, 0), (18.4, "blade", -28, -.4), (19.9, "blade", -28, .4),
             (21.4, "blade", -28, -.4), (22.9, "blade", -28, .4), (24.4, "blade", -28, 0), (24.9, "split", -28, 0),
             (26.5, "tick", -27, 0), (27.5, "tick", -27, 0), (28.6, "tap", -14, 0), (28.6, "glassA5", -21, 0),
             (30.0, "blade", -30, 0), (32.4, "pull", -28, 0), (33.7, "dock", -22, -.5), (34.5, "dock", -22, .5),
             (35.3, "dock", -22, -.3), (36.0, "dock", -22, .3), (36.6, "dock", -22, 0), (37.0, "whoosh", -30, 0),
             (42.5, "glassA6", -27, 0)]),
    "nutrition": dict(length=24.0, logo=20.7, sections=[
        ("strata", 0, 7.5), ("pulse", 7.5, 14.0), ("daylight", 14.0, 20.3)],
        universes=[(0, "aurora"), (7.5, "sunset")],
        sfx=[(0.3, "glassD6", -22, 0), (1.6, "swipe", -29, 0), (2.7, "dock", -20, 0), (3.4, "tap", -15, 0),
             (4.6, "glassA5", -24, 0), (6.0, "tap", -15, 0), (7.4, "pull", -29, 0), (10.3, "swipe", -30, 0),
             (13.6, "split", -28, 0), (16.8, "swipe", -29, 0), (17.5, "light", -22, 0), (19.0, "tap", -15, 0),
             (20.0, "whoosh", -30, 0), (22.2, "glassA6", -27, 0)],
        words=("N3", ["D5", "F5", "A5", "C6"])),
    "fitness": dict(length=24.0, logo=20.3, sections=[
        ("pulse", 0, 6.8), ("break", 6.8, 10.6), ("run", 10.6, 19.9)],
        universes=[(0, "sunset"), (10.6, "neon")],
        sfx=[(0.05, "thump", -14, 0), (1.2, "tap", -13, 0), (1.2, "glassA5", -21, 0), (2.5, "tap", -13, 0),
             (3.5, "tap", -12, 0), (3.5, "glassA5", -19, 0), (3.9, "tick", -24, 0), (4.9, "tick", -24, 0),
             (5.9, "tick", -24, 0), (6.6, "pull", -29, 0), (7.3, "thump", -16, 0), (8.0, "tick", -25, 0),
             (9.0, "tick", -25, 0), (9.9, "tap", -12, 0), (9.9, "glassA5", -19, 0), (10.0, "blade", -30, 0),
             (10.8, "dock", -20, 0), (11.4, "thump", -16, 0), (13.6, "swipe", -30, 0), (13.9, "blade", -29, .5),
             (16.7, "split", -28, 0), (17.5, "dock", -22, -.3), (18.0, "dock", -22, .3), (18.5, "dock", -22, 0),
             (22.4, "glassA6", -27, 0)]),
    "organisation": dict(length=24.0, logo=20.0, sections=[
        ("strata", 0, 4.0), ("daylight", 4.0, 15.8), ("pulse", 15.8, 19.6)],
        universes=[(0, "paper"), (4.0, "paper")],
        sfx=[(0.2, "glassD6", -22, 0), (1.0, "swipe", -30, -.4), (2.0, "swipe", -30, .4), (3.0, "swipe", -30, 0),
             (4.6, "whoosh", -31, 0), (5.6, "tap", -14, 0), (5.6, "glassA5", -21, 0), (6.3, "tick", -26, -.4),
             (6.5, "tick", -26, -.3), (6.7, "tick", -26, -.2), (6.9, "tick", -26, -.1), (7.1, "tick", -26, .1),
             (7.3, "tick", -26, .2), (7.5, "tick", -26, .3), (8.5, "dock", -22, -.5), (9.5, "dock", -22, 0),
             (10.5, "dock", -22, .5), (11.2, "swipe", -30, 0), (12.8, "tap", -15, 0), (13.8, "tap", -15, 0),
             (14.6, "glassA5", -21, 0), (15.5, "pull", -29, 0), (17.2, "swipe", -30, 0), (18.4, "split", -29, 0),
             (22.3, "glassA6", -27, 0)]),
    "widgets": dict(length=30.0, logo=26.0, sections=[
        ("void", 0, 1.0), ("strata", 1.0, 6.6), ("design", 6.6, 11.2), ("pulse", 11.2, 20.0),
        ("daylight", 20.0, 23.2), ("run", 23.2, 25.6)],
        universes=[(0, "aurora"), (6.6, "minimal"), (8.1, "aurora"), (9.6, "neon"), (11.2, "sunset"),
                   (15.4, "neon"), (16.9, "paper"), (18.4, "minimal"), (20.0, "space")],
        sfx=[(0.1, "glassD6", -22, 0), (0.1, "whoosh", -30, 0), (3.0, "split", -28, 0), (3.6, "swipe", -29, -.4),
             (4.4, "swipe", -29, 0), (5.2, "swipe", -29, .4), (6.4, "dock", -20, 0), (7.4, "blade", -28, -.4),
             (8.9, "blade", -28, .4), (10.4, "blade", -28, 0), (11.2, "pull", -29, 0), (12.0, "dock", -22, -.5),
             (12.9, "dock", -22, .5), (13.8, "dock", -22, 0), (15.4, "swipe", -29, 0), (16.9, "swipe", -29, 0),
             (18.4, "swipe", -29, 0), (20.0, "split", -28, 0), (23.1, "pull", -28, 0), (24.0, "dock", -22, 0),
             (24.6, "whoosh", -30, 0), (28.2, "glassA6", -27, 0)]),
    "finance": dict(length=19.0, logo=14.8, sections=[("strata", 0, 6.4), ("daylight", 6.4, 14.4)],
        universes=[(0, "aurora"), (6.4, "space")],
        sfx=[(0.3, "glassD6", -22, 0)] + [(0.6 + 0.12 * k, "tick", -30 + 0.4 * k, 0) for k in range(9)] +
            [(1.9, "tap", -17, 0), (3.4, "tap", -15, 0), (3.4, "glassD5", -23, -.3), (4.4, "tap", -15, 0),
             (4.4, "glassF5", -23, 0), (5.4, "tap", -15, 0), (5.4, "glassA5", -22, .3), (6.4, "blade", -28, -.6),
             (7.0, "swipe", -30, 0), (9.4, "dock", -22, -.4), (10.4, "dock", -22, 0), (11.4, "dock", -22, .4),
             (12.2, "split", -28, 0), (13.4, "tap", -15, 0), (17.0, "glassA6", -27, 0)]),
    "lifestyle": dict(length=42.0, logo=38.0, sections=[
        ("void", 0, 3.2), ("strata", 3.2, 11.2), ("daylight", 11.2, 20.8), ("pulse", 20.8, 28.2),
        ("break", 28.2, 33.0), ("run", 33.0, 37.6)],
        universes=[(0, "aurora"), (3.2, "sunset"), (7.0, "aurora")],
        sfx=[(0.1, "glassD6", -22, 0), (0.5, "tick", -26, 0), (1.0, "tick", -26, 0), (3.1, "split", -28, 0),
             (4.5, "swipe", -30, 0), (7.6, "dock", -20, 0), (8.6, "tap", -15, 0), (8.6, "glassA5", -21, 0),
             (10.2, "pull", -29, 0), (11.4, "swipe", -30, 0), (13.5, "swipe", -30, 0), (15.0, "tick", -26, 0),
             (16.4, "whoosh", -30, 0), (20.8, "split", -28, 0), (22.0, "tap", -13, 0), (23.0, "tick", -25, 0),
             (24.0, "tick", -25, 0), (25.0, "tap", -12, 0), (25.0, "glassA5", -19, 0), (26.0, "tick", -25, 0),
             (28.2, "pull", -29, 0), (29.5, "swipe", -30, 0), (31.0, "tick", -26, 0), (31.4, "tap", -15, 0),
             (33.0, "whoosh", -30, 0), (34.2, "dock", -22, -.5), (35.0, "dock", -22, .5), (35.8, "dock", -22, 0),
             (36.4, "dock", -22, .3), (42.0 - 3.0, "glassA6", -27, 0)]),
    "short1": dict(length=8.0, logo=4.4, sections=[("void", 0, 1.0), ("strata", 1.0, 4.0)],
        universes=[(0, "aurora")],
        sfx=[(0.1, "glassD6", -22, 0), (0.1, "whoosh", -30, 0), (1.8, "dock", -20, -.5), (2.2, "dock", -20, .5),
             (2.6, "dock", -20, -.2), (3.0, "dock", -20, .2), (3.3, "whoosh", -30, 0), (6.8, "glassA6", -27, 0)]),
    "short2": dict(length=8.0, logo=5.8, sections=[("void", 0, 0.8), ("strata", 0.8, 3.0), ("design", 3.0, 5.4)],
        universes=[(0, "aurora"), (3.0, "minimal"), (3.7, "aurora"), (4.4, "neon")],
        sfx=[(0.1, "glassD6", -22, 0), (0.1, "whoosh", -30, 0), (2.9, "split", -28, 0), (3.0, "blade", -28, -.4),
             (3.7, "blade", -28, .4), (4.4, "blade", -28, 0), (5.1, "dock", -20, 0), (7.4, "glassA6", -27, 0)]),
    "short3": dict(length=8.0, logo=4.6, sections=[("void", 0, 0.8), ("strata", 0.8, 2.0), ("pulse", 2.0, 4.2)],
        universes=[(0, "aurora"), (2.0, "space"), (3.3, "neon")],
        sfx=[(0.1, "glassD6", -22, 0), (0.1, "whoosh", -30, 0), (0.8, "swipe", -29, 0), (2.0, "swipe", -29, 0),
             (3.3, "swipe", -29, 0), (3.5, "split", -28, 0), (7.0, "glassA6", -27, 0)]),
}
FILM_ORDER = list(FILMS)


# --- Music -----------------------------------------------------------------------------------------
def music_stem(film):
    """The score of a film, stereo, exactly `length` s: sections, rise, riser, silence, signature, end silence."""
    cfg = FILMS[film]
    length, logo = cfg["length"], cfg["logo"]
    pre = logo - PRE_LOGO_SILENCE            # the music before the logo ends here (the riser's peak)
    sections = [{"type": t, "start": a, "end": min(b, pre)} for t, a, b in cfg["sections"]]
    sections[-1]["end"] = pre
    riser = min(1.6, max(0.8, pre * 0.1))
    body = score_cut(pre, sections, universes=cfg["universes"], risers=[(pre, riser)], end_fade=0.0, end_gap=0.0)
    n = int(round(length * SR))
    track = np.zeros((n, 2))
    k = min(len(body), n)
    # Slow rise: -6 dB at the start to 0 dB at 80 % of the pre-logo time (density already grows with the sections).
    rise = db(np.interp(np.arange(k) / SR, [0, pre * 0.8, pre], [-6, 0, 0]))
    track[:k] = body[:k] * rise[:, None]
    # Sub tail through the silence is not wanted: hard zero between the riser peak and the logo (a few ms fade).
    a, b = int(pre * SR), int(logo * SR)
    track[a:b] = 0
    # Signature on the logo: D5, a rest (the glass dies away), A5 over the D major 9 bloom.
    d5 = reverb(fm_glass(note("D5"), seconds=1.0, index=4.0, decay=0.32), 3.0, 0.3)
    a5 = reverb(fm_glass(note("A5"), index=4.0, decay=1.6), 3.0, 0.3)
    from score import pad_layer, CH
    place(track, d5, logo, db(-13))
    place(track, a5, logo + 0.5, db(-13))
    pads = np.zeros((n, 2))
    tail = max(0.5, length - END_SILENCE - (logo + 0.5))
    pad_layer(pads, logo + 0.5, tail, CH["Dmaj9"], db(-15), cutoff=2400, attack=0.08, release=2.6)
    pads = reverb(pads.mean(axis=1), 4.5, 0.3) * 0.9 + pads * 0.1
    track += pads
    place(track, sub(note("D1"), tail, attack=0.05, release=2.5), logo, db(-20))
    place(track, reverb(fm_glass(note("A6"), index=2.0, decay=1.0), 3.0, 0.35), logo + 1.4, db(-27))
    # Everything fades to silence over the last 0.3 s .. 0.3 s of true silence.
    e = int((length - END_SILENCE) * SR)
    f = int(0.45 * SR)
    track[e - f:e] *= np.linspace(1, 0, f)[:, None]
    track[e:] = 0
    return track


def place(track, sound, at, gain=1.0):
    i = int(round(at * SR))
    if sound.ndim == 1:
        sound = np.stack([sound, sound], axis=1)
    end = min(len(track), i + len(sound))
    if end > i:
        track[i:end] += sound[: end - i] * gain


# --- SFX -------------------------------------------------------------------------------------------
def sfx_bank():
    glass = M.glass
    return {
        "whoosh": lambda: M.whoosh(0.8), "split": M.split_sfx, "blade": lambda: M.blade_shimmer(12),
        "pull": M.air_pull, "dock": M.dock_click, "tap": M.tap_pulse, "tick": M.tick,
        "swipe": lambda: M.whoosh(0.3, 1000, 6000, seed=61), "wake": lambda: M.whoosh(1.2, 400, 2500, seed=6)[::-1],
        "light": M.light_on, "thump": lambda: thump(55, 40),
        "glassD6": lambda: glass("D6"), "glassA5": lambda: glass("A5", index=2.5, decay=1.2, wet=0.3),
        "glassA6": lambda: glass("A6", index=2.0, decay=1.0, wet=0.35),
        "glassD5": lambda: glass("D5", index=2.0), "glassF5": lambda: glass("F5", index=2.0),
    }


def sfx_stem(film, lang):
    cfg = FILMS[film]
    bank, cache = sfx_bank(), {}
    n = int(round(cfg["length"] * SR))
    tr = np.zeros((n, 2))
    events = list(cfg["sfx"])
    # Words coloured on screen (nutrition N3: orange, red, yellow, blue): a glass note on each word of the voice.
    if cfg.get("words"):
        line_id, tones = cfg["words"]
        info = json.load(open(os.path.join(VO_DIR, lang, film, f"{film}.json"), encoding="utf-8"))
        for line in info["lines"]:
            if line["id"] == line_id and len(line["words"]) >= 4:
                start = start_of(lang, film, line_id)
                for w, tone in zip(line["words"][:4], tones):
                    events.append((start + w["start"], tone, -23, 0))
    for t, name, gain, pan in events:
        if t >= cfg["logo"] - PRE_LOGO_SILENCE and t < cfg["logo"] + 0.01 and name != "glassD6":
            continue  # nothing in the silence before the logo
        if name in bank:
            snd = cache.setdefault(name, bank[name]())
        else:  # a note name
            snd = cache.setdefault(name, M.glass(name, index=2.0, decay=1.0, wet=0.3))
        snd = snd[:, 0] if snd.ndim == 2 and name not in ("split", "blade") else snd
        left, right = (np.cos((pan + 1) * np.pi / 4), np.sin((pan + 1) * np.pi / 4))
        if snd.ndim == 1:
            snd = np.stack([snd * left, snd * right], axis=1) * np.sqrt(2)
        place(tr, snd, t, db(gain))
    tr[int((cfg["length"] - END_SILENCE) * SR):] = 0
    return tr


# --- Voice -----------------------------------------------------------------------------------------
def start_of(lang, film, line_id):
    spec = json.load(open(SPEC[lang], encoding="utf-8"))
    for chunk in spec["films"][film]["chunks"]:
        for line in chunk:
            if line["id"] == line_id:
                return line["start"]
    raise KeyError(line_id)


def voice_stem(film, lang):
    spec = json.load(open(SPEC[lang], encoding="utf-8"))
    n = int(round(FILMS[film]["length"] * SR))
    tr = np.zeros(n)
    report = []
    for chunk in spec["films"][film]["chunks"]:
        for line in chunk:
            audio, sr = sf.read(os.path.join(VO_DIR, lang, film, f"{film}-{line['id']}.wav"), dtype="float64")
            if audio.ndim > 1:
                audio = audio.mean(axis=1)
            audio = resample_poly(audio, SR, sr) if sr != SR else audio
            i = int(round(line["start"] * SR))
            end = min(n, i + len(audio))
            tr[i:end] += audio[: end - i]
            report.append((line["id"], line["start"], len(audio) / SR, line["max"]))
    meter = pyln.Meter(SR)
    tr = M.voice_chain(tr)
    voiced = tr[np.abs(tr).mean(axis=1) > 1e-4]
    tr *= db(-16 - meter.integrated_loudness(voiced))
    return tr, report


# --- Mix -------------------------------------------------------------------------------------------
def master(music, sfx, voice):
    d = M.duck_envelope(voice)
    gain = 1 - (1 - db(DUCK_DB)) * d
    mid = M.filt(music, "bandpass", [2000, 4000])
    music = music * gain[:, None] - mid * (1 - db(-2.5)) * d[:, None]
    mixdown = music + sfx + voice
    meter = pyln.Meter(SR)
    scale = 1.0
    for _ in range(3):
        mixdown *= db(-14 - meter.integrated_loudness(mixdown))
        mixdown = M.limit(mixdown, db(-1.2))
    return mixdown, music, d


def mix_film(film, lang, stems=False):
    cfg = FILMS[film]
    n = int(round(cfg["length"] * SR))
    music = music_stem(film)
    meter = pyln.Meter(SR)
    music *= db(MUSIC_BED_LUFS - meter.integrated_loudness(music))
    sfx = sfx_stem(film, lang)
    voice, report = voice_stem(film, lang)
    mixdown, music_d, d = master(music, sfx, voice)
    mixdown = mixdown[:n]
    mixdown[int((cfg["length"] - 0.05) * SR):] *= np.linspace(1, 0, n - int((cfg["length"] - 0.05) * SR))[:, None]
    out_dir = os.path.join(OUT_DIR, lang)
    os.makedirs(out_dir, exist_ok=True)
    path = os.path.join(out_dir, f"mix-{film}.wav")
    sf.write(path, mixdown.astype(np.float32), SR, subtype="FLOAT")
    # Measures: voice level above the music while she speaks, loudness, peak.
    active = d > 0.9
    scale_final = mixdown.shape[0] / max(1, n)
    gap = None
    if active.sum() > SR // 2:
        vs, ms = voice[active], music_d[active]
        gap = meter.integrated_loudness(vs) - meter.integrated_loudness(ms)
    lufs = meter.integrated_loudness(mixdown)
    peak = 20 * np.log10(np.abs(mixdown).max() + 1e-12)
    if stems:
        sd = os.path.join(out_dir, "stems", film)
        os.makedirs(sd, exist_ok=True)
        for name, x in (("music", music_d), ("sfx", sfx), ("voice", voice)):
            sf.write(os.path.join(sd, f"{name}.wav"), x.astype(np.float32), SR, subtype="FLOAT")
    over = [(i, round(dur, 2), mx) for i, st, dur, mx in report if dur > mx]
    print(f"{lang} {film}: {len(mixdown) / SR:.3f} s (expected {cfg['length']}), {lufs:.1f} LUFS, peak {peak:.1f} dBFS, "
          f"voice-music {gap if gap is None else round(gap, 1)} dB, over slot: {over or 'none'}")
    return dict(lang=lang, film=film, seconds=len(mixdown) / SR, lufs=lufs, peak=peak, gap=gap, over=over)


if __name__ == "__main__":
    cmd = sys.argv[1]
    if cmd == "music":
        film, out = sys.argv[2:4]
        x = music_stem(film)
        sf.write(out, x.astype(np.float32), SR, subtype="FLOAT")
        print(film, len(x) / SR, "s")
    elif cmd == "mix":
        lang, which = sys.argv[2:4]
        stems = "--stems" in sys.argv
        films = FILM_ORDER if which == "all" else [which]
        results = [mix_film(f, lang, stems) for f in films]
        json.dump(results, open(os.path.join(OUT_DIR, lang, "report.json"), "w"), indent=1)
