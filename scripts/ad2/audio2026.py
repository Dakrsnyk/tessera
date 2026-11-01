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

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))  # python -I does not add the script's folder
import mix as M
from score import score_cut
import synth as S
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

# v3main: the 45 s main film of the "v3" cut, English only. 0-5.6 s hook (tension), 5.6-6.4 s total silence,
# impact at 6.4 s, logo appears 7.6 s, widgets 14 s, four words 26.6 s, scan ~29 s, logo/signature at 40.0 s.
# Music: custom tension (music_tension) then score_cut resolving D minor -> D major from 6.0 s (zeroed before 6.4).
_HOOK = [0.6 + 0.5 * k for k in range(10)]  # cuts on every beat of the hook (0.6 .. 5.1)
TIMING_V3 = os.path.join(HERE, "film", "src", "v3", "timing.json")


def v3_sfx():
    """SFX of v3main from film/src/v3/timing.json (frames at 60 fps)."""
    T = json.load(open(TIMING_V3, encoding="utf-8"))
    f = lambda x: x / FPS
    h, ev = T["hook"], []
    for k, m in enumerate(h["momentShots"]):  # a cut whoosh on every moment shot of the hook
        ev.append((f(m["f"]), "cut", -27 + 0.5 * k, 0.5 if k % 2 else -0.5))
    for k, fr in enumerate(h["tick"] + [36 + 15 * i for i in range(0, 10)]):  # tic-tac, louder as the hook goes
        ev.append((f(fr), "tic" if k % 2 == 0 else "tac", -29 + 0.5 * k, 0))
    banners = [206, 224, 240, 262, 280, 296, 308, 318, 326, 332]
    ev += [(f(b), "notif", -27 + 0.5 * k, (-0.5, 0.4, -0.3, 0.6)[k % 4]) for k, b in enumerate(banners)]
    ev.append((f(h["tenCounter"]["from"]), "counter", -22, 0))      # 1 -> 10 on "ten"
    ev.append((f(h["tenCounter"]["slam"]), "tap", -13, 0))          # tile 10 slams
    for g, gain in zip((336, 349, 362, 372, 379), (-17, -34, -36, -36, -36)):
        ev.append((f(g), "glitch", gain, 0))
    ev.append((f(h["impact"]), "impact", -8, 0))                    # exactly 6.4 s
    ev.append((f(T["reveal"]["wordMeet"]), "logo_in", -17, 0))
    ev.append((f(T["reveal"]["screenWake"][0]), "light", -24, 0))   # the screen wakes
    ev.append((f(T["reveal"]["explodeStart"]) - 0.4, "transition", -27, 0))
    ev.append((f(T["personalise"]["wordWidgets"]) - 0.5, "transition", -26, 0))
    ev += [(f(u), "swipe", -29, 0.4 if k % 2 else -0.4) for k, u in enumerate(T["personalise"]["universeChanges"])]
    ev.append((f(T["personalise"]["studioStart"]), "blade", -29, 0))
    ev.append((f(T["personalise"]["premiumPill"][0]), "notif", -26, 0))
    U = T["universes"]
    ev.append((f(U["plateArrivals"][0]) - 0.5, "transition", -25, 0))
    ev += [(f(a), "cut", -25, 0.5 if k % 2 else -0.5) for k, a in enumerate(U["plateArrivals"][1:])]
    ev += [(f(w), "tap", -12, 0) for w in U["burstWordsSlam"]]      # a slam on each word
    ev += [(f(w), "dock", -20, 0) for w in U["burstWordsSlam"]]
    ev += [(f(c), "cut", -26, 0) for c in T["cuts"][5:-1]]
    ev += [(29.0, "barcode", -23, 0), (f(2030), "check", -22, 0), (f(2240), "check", -22, 0)]
    ev.append((f(T["close"]["start"]) - 0.5, "transition", -24, 0))
    return ev


FILMS["v3main"] = dict(length=45.0, logo=40.0, custom="v3", sections=[
        ("strata", 6.0, 14.0), ("daylight", 14.0, 26.0), ("run", 26.0, 39.6)],
    universes=[(6.0, "aurora"), (14.0, "space"), (26.0, "sunset")], sfx=v3_sfx())
TIMING_V4 = os.path.join(HERE, "film", "src", "v4", "timing.json")


def v4_sfx():
    """SFX of v4main from film/src/v4/timing.json (frames at 60 fps)."""
    T = json.load(open(TIMING_V4, encoding="utf-8"))
    f = lambda x: x / FPS
    h, ev = T["hook"], []
    for k, m in enumerate(h["momentShots"]):
        ev.append((f(m["f"]), "cut", -27 + 0.6 * k, 0.5 if k % 2 else -0.5))
    for k, fr in enumerate(h["tick"] + [36 + 22 * i for i in range(0, 14)]):
        ev.append((f(fr), "tic" if k % 2 == 0 else "tac", -29 + 0.4 * k, 0))
    b0, gap = h["bannersStart"], h["bannerGap"]
    banners = [b0 + gap * k for k in range(8)] + [b0 + 160 + 12 * k for k in range(6)]
    banners = [b for b in banners if b < h["silence"]["from"] - 4]
    ev += [(f(b), "notif", -27 + 0.4 * k, (-0.5, 0.4, -0.3, 0.6)[k % 4]) for k, b in enumerate(banners)]
    tc = h["tenCounter"]
    ev.append((f(tc["from"]), "counter", -22, 0))
    ev.append((f(tc["slam"]), "tap", -13, 0))
    for g, gain in zip((432, 445, 458, 468, 475), (-17, -34, -36, -36, -36)):
        ev.append((f(g), "glitch", gain, 0))
    ev.append((f(h["impact"]), "impact", -8, 0))
    R = T["reveal"]
    ev.append((f(R["wordMeet"]), "logo_in", -17, 0))
    ev.append((f(R["screenWake"][0]), "light", -24, 0))
    ev.append((f(R["phoneTurn"][0]), "transition", -27, 0))
    steps = {"nutrition": [(794, "barcode", -23), (846, "tap", -15), (916, "tap", -15), (958, "swipe", -28)],
             "fitness": [(1120, "tap", -15), (1146, "swipe", -29), (1260, "dock", -16), (1318, "tick", -25), (1356, "swipe", -28)],
             "habits": [(1536, "check", -22), (1616, "swipe", -28)],
             "finances": [(1766, "swipe", -29), (1832, "swipe", -29), (1908, "swipe", -28)],
             "planning": [(2020, "tap", -17), (2070, "swipe", -29), (2174, "swipe", -28)]}
    for lst in steps.values():
        for fr, nm, g in lst:
            ev.append((f(fr), nm, g, 0))
    ev += [(f(w), "blade", -29, 0.5 if k % 2 else -0.5) for k, w in enumerate(T["bladeWipes"])]
    ev += [(f(l) - 0.4, "transition", -26, 0) for l in T["links"]]            # whoosh into every link
    ev += [(f(PRE) , "swipe", -27, -0.4 if k % 2 else 0.4) for k, PRE in enumerate(range(2250, 3090, 120))]  # Store scroll / layers
    ev += [(f(2420), "split", -28, 0), (f(2970), "dock", -20, 0)]
    ev += [(f(3090) - 0.4, "transition", -26, 0)]
    ev += [(f(fr), "swipe", -29, 0.4 if k % 2 else -0.4) for k, fr in enumerate((3255, 3420, 3585))]   # glide between home screens
    ev.append((f(3734) - 0.3, "transition", -24, 0))
    return [e for e in ev if e[0] < 67.5]


FILMS["v4main"] = dict(length=67.5, logo=63.5, custom="v3", impact=8.0, silence_from=7.2,
    sections=[("strata", 8.0, 16.0), ("daylight", 16.0, 38.0), ("pulse", 38.0, 52.0), ("run", 52.0, 63.1)],
    universes=[(8.0, "aurora"), (16.0, "space"), (38.0, "sunset"), (52.0, "neon")],
    rise_t=[8.0, 16.0, 38.0, 52.0, 63.1], rise_db=[-7, -5, -3, -1.5, 0], sfx=v4_sfx())
FILM_ORDER = list(FILMS)


# --- Music -----------------------------------------------------------------------------------------
def music_stem(film):
    """The score of a film, stereo, exactly `length` s: sections, rise, riser, silence, signature, end silence."""
    cfg = FILMS[film]
    length, logo = cfg["length"], cfg["logo"]
    if cfg.get("custom") == "v3":
        return music_v3(cfg)
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


# --- v3main music ----------------------------------------------------------------------------------
def music_tension(n, until=5.6):
    """0 .. 5.6 s: heartbeat that speeds up, a dissonant cluster whose filter opens, a high tritone stutter that
    accelerates, a riser that peaks at 5.6 s; everything cut dead at 5.6 s."""
    from score import pad_layer, pluck, add
    tr = np.zeros((n, 2))
    # Heartbeat: sub thump on a double beat, interval 0.5 s -> 0.24 s.
    t = 0.0
    while t < until - 0.1:
        g = db(-12 + 7 * t / until)
        place(tr, thump(52, 70), t, g)
        place(tr, thump(52, 55), t + 0.14, g * 0.6)
        t += 0.5 - 0.26 * (t / until) ** 1.5
    # Dissonant cluster (D, Eb, G#, A, Bb) whose low-pass opens with each second.
    cl = ["D3", "D#3", "G#3", "A3", "A#3"]
    for i, s in enumerate(np.arange(0.0, until, 1.0)):
        d = min(1.0, until - s)
        pad_layer(tr, s, d, cl, db(-22 + 1.4 * i), cutoff=500 + 650 * i, attack=0.4, release=0.5)
    # Tritone stutter (A5 / Eb6) over the last 3.2 s, 8ths -> 16ths -> 32nds.
    t0 = until - 3.2
    t = t0
    j = 0
    while t < until - 0.05:
        f = note("A5") if j % 2 == 0 else note("D#6")
        add(tr, pluck(f, "minimal", 0.25), t, db(-27 + 5 * (t - t0) / (until - t0)), pan=-0.3 if j % 2 else 0.3)
        t += 0.25 - 0.17 * ((t - t0) / (until - t0)) ** 1.2
        j += 1
    # Riser (noise sweep + saw glide) peaking right at 5.6 s.
    place(tr, S.riser(until - 0.4), 0.4, db(-17))
    # Everything dies at 5.6 s (8 ms fade): the glitch SFX is the only sound left.
    a, b = int((until - 0.008) * SR), int(until * SR)
    tr[a:b] *= np.linspace(1, 0, b - a)[:, None]
    tr[b:] = 0
    return tr


def music_v3(cfg):
    import score
    from score import pad_layer, CH
    n = int(round(cfg["length"] * SR))
    pre = cfg["logo"] - PRE_LOGO_SILENCE
    logo = cfg["logo"]
    I = cfg.get("impact", 6.4)
    SIL = cfg.get("silence_from", 5.6)
    sections = [{"type": t, "start": a, "end": min(b, pre)} for t, a, b in cfg["sections"]]
    saved = dict(score.SECTION_CHORDS)
    score.SECTION_CHORDS.update({"strata": ["Dmaj9", "Bbmaj9", "Fmaj9", "Csus4"],
                                 "run": ["Bbmaj9", "Gm9", "A7sus4", "Dmaj9"]})
    try:
        body = score_cut(pre, sections, universes=cfg["universes"], risers=[(pre, 1.6)], end_fade=0.0, end_gap=0.0)
    finally:
        score.SECTION_CHORDS.clear()
        score.SECTION_CHORDS.update(saved)
    track = np.zeros((n, 2))
    k = min(len(body), n)
    # Rise by sections: -7 dB at the impact to 0 dB at the logo.
    rise = db(np.interp(np.arange(k) / SR, cfg.get("rise_t", [I, 14.0, 26.0, pre]), cfg.get("rise_db", [-7, -4, -2, 0])))
    track[:k] = body[:k] * rise[:, None]
    track[: int(I * SR)] = 0          # the section grid starts at 6.0 s, the music at the impact
    track += music_tension(n, SIL)
    # Breath in the silence: a short decaying reverb tail after the cut, then a reversed swell into the impact.
    burst = np.pad(noise_band(0.05, 500, 6000, seed=33) * 0.8, (0, int(0.6 * SR)))
    tail = reverb(burst, 1.4, 1.0)
    tail = tail[: int(0.45 * SR)] * np.linspace(1, 0, int(0.45 * SR))[:, None] ** 2
    place(track, tail, SIL, db(-30))
    swell = reverb(np.pad(noise_band(0.5, 300, 5000, seed=34) * np.hanning(int(0.5 * SR)), (0, int(0.5 * SR))), 1.2, 0.8)
    sw = swell[: int(0.25 * SR)][::-1] * np.linspace(0, 1, int(0.25 * SR))[:, None] ** 2
    place(track, sw, I - 0.25, db(-34))
    # Small low boom just before, with a reversed reverb tail leading into the impact.
    boom = np.pad(thump(46, 140), (0, int(1.0 * SR)))
    rb = reverb(boom, 1.0, 0.9)[: int(0.34 * SR)][::-1] * np.linspace(0, 1, int(0.34 * SR))[:, None] ** 2
    place(track, rb, I - 0.34, db(-22))
    place(track, thump(46, 140), I - 0.08, db(-24))
    from score import kick
    place(track, kick(), I, db(-8))          # the first kick IS the impact
    # Impact on 6.4 s: sub drop, then the D major bloom (the SFX stem carries the crack and the crash).
    place(track, sub(note("D1"), 3.0, attack=0.004, release=2.6), I, db(-14))
    pads = np.zeros((n, 2))
    pad_layer(pads, I, 1.6, CH["Dmaj9"], db(-15), cutoff=3200, attack=0.05, release=1.6)
    track += reverb(pads.mean(axis=1), 3.0, 0.4)
    # Silence before the logo, then the signature D5 . rest . A5 on the logo.
    a, b = int(pre * SR), int(logo * SR)
    track[a:b] = 0
    d5 = reverb(fm_glass(note("D5"), seconds=1.0, index=4.0, decay=0.32), 3.0, 0.3)
    a5 = reverb(fm_glass(note("A5"), index=4.0, decay=1.6), 3.0, 0.3)
    place(track, d5, logo, db(-13))
    place(track, a5, logo + 0.5, db(-13))
    pads = np.zeros((n, 2))
    tail_s = max(0.5, cfg["length"] - END_SILENCE - (logo + 0.5))
    pad_layer(pads, logo + 0.5, tail_s, CH["Dmaj9"], db(-15), cutoff=2400, attack=0.08, release=2.6)
    pads = reverb(pads.mean(axis=1), 4.5, 0.3) * 0.9 + pads * 0.1
    track += pads
    place(track, sub(note("D1"), tail_s, attack=0.05, release=2.5), logo, db(-20))
    place(track, reverb(fm_glass(note("A6"), index=2.0, decay=1.0), 3.0, 0.35), logo + 1.4, db(-27))
    # Soft shimmer of the close (frames 2400-2682), calm from 2664 (44.4 s).
    rng = np.random.default_rng(12)
    for t in np.arange(logo + 0.9, cfg["length"] - 0.6, 0.23):
        nn = ["D6", "F#6", "A6", "E6", "C#7"][int(rng.integers(0, 5))]
        place(track, reverb(np.pad(fm_glass(note(nn), 1.0, index=1.5, decay=0.5), (0, SR)), 2.0, 0.4), t, db(-34 - 6 * max(0.0, t - (cfg["length"] - 1.6))))
    e = int((cfg["length"] - END_SILENCE) * SR)
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
        "tic": lambda: S.cue_tic(2300), "tac": lambda: S.cue_tic(1500), "cut": S.cue_cut, "notif": S.cue_notif,
        "counter": S.cue_counter, "glitch": S.cue_glitch, "impact": S.cue_impact, "logo_in": S.cue_logo_in,
        "transition": S.cue_transition, "check": S.cue_check, "barcode": S.cue_barcode,
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
        snd = snd[:, 0] if snd.ndim == 2 and name not in ("split", "blade", "impact") else snd
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
