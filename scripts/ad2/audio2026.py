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


def hook_sfx(T):
    """Hook + reveal + tease SFX shared by v4main and v5p1 (same opening), from a timing.json dict."""
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
    ev += [(f(w["f"]), "tic", -22, 0) for w in T["tease"]["words"]]            # the four tease marks
    return ev


def v4_sfx():
    """SFX of v4main from film/src/v4/timing.json (frames at 60 fps)."""
    T = json.load(open(TIMING_V4, encoding="utf-8"))
    f = lambda x: x / FPS
    ev = hook_sfx(T)
    steps = [(1078, "barcode", -23), (1130, "tap", -15), (1250, "tap", -15), (1304, "tap", -17), (1362, "swipe", -28),
             (1570, "tap", -15), (1596, "swipe", -29), (1710, "dock", -16), (1768, "tick", -25), (1806, "swipe", -28),
             (1986, "check", -22), (2066, "swipe", -28), (2216, "swipe", -29), (2282, "swipe", -29), (2358, "swipe", -28),
             (2470, "tap", -17), (2520, "swipe", -29), (2624, "swipe", -28)]
    ev += [(f(fr), nm, g, 0) for fr, nm, g in steps]
    quick = set(T["process"]["screens"][k]["f"] for k in range(1, len(T["process"]["screens"]))) | set(T["homes"]["changes"])
    ev += [(f(w), "blade", -29, 0.5 if k % 2 else -0.5) for k, w in enumerate(T["bladeWipes"]) if w not in quick]
    ev += [(f(l) - 0.4, "transition", -26, 0) for l in T["links"]]            # whoosh into every link
    for k, fr in enumerate(sorted(quick)):                                      # Process screens and Home Screen changes: whoosh + tic + accent
        pan = 0.4 if k % 2 else -0.4
        ev += [(f(fr) - 0.05, "cut", -26, pan), (f(fr) + 0.02, "tic", -23, 0), (f(fr), "dock", -22, 0)]
    ev += [(f(T["process"]["words"][1]["f"]), "split", -28, 0), (f(T["process"]["words"][2]["f"]), "glassA5", -26, 0)]
    ev += [(f(T["cuts"][-1]) - 0.4, "transition", -26, 0)]
    ev.append((f(T["close"]["overlapWithHomes"][0]) - 0.3, "transition", -24, 0))
    return [e for e in ev if e[0] < T["length"] / FPS]


FILMS["v4main"] = dict(length=67.0, logo=63.0, custom="v3", impact=8.0, silence_from=7.2,
    sections=[("strata", 8.0, 16.0), ("daylight", 16.0, 45.0), ("pulse", 45.0, 55.0), ("run", 55.0, 62.6)],
    universes=[(8.0, "aurora"), (16.0, "space"), (45.0, "sunset"), (55.0, "neon")],
    rise_t=[8.0, 16.0, 45.0, 55.0, 62.6], rise_db=[-7, -5, -2.5, -1, 0], swell=(12.17, 16.8), accel=(45.0, 55.0), sfx=v4_sfx())
TIMING_V5 = os.path.join(HERE, "film", "src", "v5", "timing.json")


def v5_sfx():
    """SFX of v5p1 (89.5 s, part 1 of the main film) from film/src/v5/timing.json."""
    T = json.load(open(TIMING_V5, encoding="utf-8"))
    f = lambda x: x / FPS
    ev = hook_sfx(T)
    ev += [(f(d), "swipe", -28, 0.3 if k % 2 else -0.3) for k, d in enumerate(T["dips"])]         # screen changes
    ev += [(f(w), "blade", -30, 0.5 if k % 2 else -0.5) for k, w in enumerate(T["bladeWipes"])]
    ev += [(f(c) - 0.4, "transition", -26, 0) for c in T["cuts"][:-1]]                            # between mini-apps
    for m in T["miniapps"]:                                                                        # the name appears with its voice
        ev += [(f(m["nameAt"]), "tic", -21, 0), (f(m["nameAt"]), "glassD5", -26, 0), (f(m["interfaceVisibleAt"]), "light", -26, 0)]
    for h in T["highlights"]:
        ev.append((f(h["from"]), "tic", -31, 0))                                                   # discreet highlight
    sc = T["scans"][0]
    ev += [(f(sc["barcodeEnters"]), "swipe", -27, 0), (f(sc["lineReads"][0]), "barcode", -22, 0),
           (f(sc["ring"]), "tap", -15, 0), (f(sc["ring"]), "glassA5", -24, 0)]
    ev += [(f(1978), "check", -21, 0), (f(1978), "dock", -20, 0)]                                  # added to the day
    ev += [(f(3440), "check", -21, 0), (f(3552), "check", -22, 0), (f(3560), "glassA6", -27, 0)]  # habit ticked, streak kept
    ev += [(f(T["demos"][0]["from"]) - 0.1, "pull", -27, 0)] + [(f(3070 + 32 * k), "tick", -27, 0) for k in range(5)]
    ev += [(f(T["widgetsRise"][0]), "swipe", -25, 0), (f(T["widgetsRise"][0]), "dock", -20, 0), (f(T["widgetsRise"][0]) + 0.1, "glassD6", -26, 0)]
    E = T["end"]
    ev += [(f(E["andMuchMore"]), "logo_in", -20, 0), (f(E["converge"][0]), "transition", -22, 0), (f(E["flash"]), "impact", -15, 0)]
    return [e for e in ev if e[0] < T["length"] / FPS - 0.3]


FILMS["v5p1"] = dict(length=89.5, logo=89.5, custom="v3", impact=8.0, silence_from=7.2, music_end=5302 / 60,
    end_swell=(84.4, 5302 / 60, 89.2), swell=(12.17, 16.8),
    sections=[("strata", 8.0, 16.5), ("daylight", 16.5, 38.0), ("run", 38.0, 55.0), ("design", 55.0, 63.0),
              ("strata", 63.0, 75.0), ("daylight", 75.0, 84.0), ("pulse", 84.0, 89.0)],
    universes=[(8.0, "aurora"), (16.5, "sunset"), (38.0, "neon"), (55.0, "minimal"), (63.0, "space"), (75.0, "aurora"), (84.0, "sunset")],
    rise_t=[8.0, 16.5, 38.0, 55.0, 63.0, 75.0, 84.0, 5302 / 60], rise_db=[-7, -5, -3, -1.5, -3.5, -2.5, -1, 0], sfx=v5_sfx())
TIMING_V5S = os.path.join(HERE, "film", "src", "v5", "short", "timing.json")


def v5s_sfx():
    """SFX of v5short (39.47 s cut of the main film, no Habits) from film/src/v5/short/timing.json."""
    T = json.load(open(TIMING_V5S, encoding="utf-8"))
    f = lambda x: x / FPS
    h, ev = T["hook"], []
    for k, m in enumerate([36, 60, 84, 108, 132]):          # intro words TRAINING / NUTRITION / WIDGETS / FINANCE / PLANNING
        ev.append((f(m), "cut", -27 + 0.6 * k, 0.5 if k % 2 else -0.5))
    for k, fr in enumerate(h["tick"] + [36 + 22 * i for i in range(0, 14)]):
        ev.append((f(fr), "tic" if k % 2 == 0 else "tac", -29 + 0.4 * k, 0))
    b0, gap = h["bannersStart"], h["bannerGap"]
    banners = [b for b in (b0 + gap * k for k in range(14)) if b < h["silence"]["from"] - 4]
    ev += [(f(b), "notif", -27 + 0.4 * k, (-0.5, 0.4, -0.3, 0.6)[k % 4]) for k, b in enumerate(banners)]
    tc = h["tenCounter"]
    ev += [(f(tc["from"]), "counter", -22, 0), (f(tc["slam"]), "tap", -13, 0)]
    for dg, gain in zip((0, 10, 20, 27, 32), (-17, -34, -36, -36, -36)):
        ev.append((f(h["silence"]["from"] + dg), "glitch", gain, 0))
    ev += [(f(h["impact"]), "impact", -8, 0), (f(h["flashPeak"]), "glassD6", -26, 0)]
    ev += [(f(T["voice"]["meet"]), "logo_in", -17, 0), (f(T["voice"]["meet"]) - 0.2, "light", -24, 0)]
    ev += [(f(c) - 0.35, "transition", -26, 0) for c in T["cuts"]]
    ev += [(f(c), "dock", -22, 0) for c in T["cuts"][1:]]
    ev += [(f(d), "swipe", -26, 0.3 if k % 2 else -0.3) for k, d in enumerate(T["dips"])]
    ev += [(f(d), "tap", -18, 0) for d in T["dips"]]
    ev += [(f(w), "blade", -29, 0.5) for w in T["bladeWipes"]]
    for m in T["miniapps"]:
        ev += [(f(m["nameAt"]), "tic", -21, 0), (f(m["nameAt"]), "glassD5", -26, 0), (f(m["interfaceVisibleAt"]), "light", -27, 0)]
    ev += [(f(x["from"]), "tic", -31, 0) for x in T["highlights"]]
    # Photo scan: shutter, flash, corners closing, sweep, "Analyzing", figures counting up, Add to log.
    ps = T["photoScan"]
    ev += [(f(ps["shutterTap"]), "tap", -14, 0), (f(ps["shutterTap"]), "dock", -17, 0),
           (f(ps["flash"]), "light", -22, 0), (f(ps["flash"]), "glassA6", -26, 0)]
    ev += [(f(c), "tic", -26, 0) for c in (ps["cornersClose"][0], 800, ps["cornersClose"][1])]
    ev += [(f(ps["sweep"][0]), "blade", -28, -0.4), (f(ps["sweep"][0]) + 0.5, "blade", -29, 0.4), (f(ps["analyzing"]), "tic", -24, 0)]
    ev += [(f(ps["resultsCount"][0]), "counter_s", -26, 0), (f(ps["addToLog"]), "check", -21, 0), (f(ps["addToLog"]), "dock", -20, 0)]
    sc = T["scans"][0]
    ev += [(f(sc["barcodeEnters"]), "swipe", -27, 0), (f(sc["lineReads"][0]), "barcode", -22, 0),
           (f(sc["ring"]), "tap", -15, 0), (f(sc["ring"]), "glassA5", -24, 0)]
    # Bench: select, open the sheet, then a soft movement texture over the single demo reading.
    bd = T["benchDemo"]
    ev += [(f(bd["tap"]), "tap", -16, 0), (f(bd["expand"][0]), "swipe", -27, 0), (f(bd["expand"][0]), "pull", -29, 0)]
    ev += [(f(bd["demoFrom"] + 30 * k), "tick", -30 - (k % 2), -0.3 if k % 2 else 0.3) for k in range(8)]
    ev += [(f(bd["demoFrom"]), "glassD5", -29, 0), (f(bd["demoFrom"] + 120), "glassA5", -30, 0)]
    E = T["end"]
    ev += [(f(E["andMuchMore"]), "logo_in", -20, 0), (f(E["converge"][0]), "transition", -22, 0), (f(E["flash"]), "impact", -15, 0)]
    return [e for e in ev if e[0] < T["length"] / FPS - 0.3]


_c = [c / FPS for c in (446, 646, 1246, 1786, 2010, 2194)]
FILMS["v5short"] = dict(length=2368 / FPS, ceiling=-2.8, logo=2368 / FPS, custom="v3", impact=402 / FPS, silence_from=366 / FPS,
    music_end=2322 / FPS, end_swell=(2224 / FPS, 2322 / FPS, 2350 / FPS),
    sections=[("strata", 6.0, _c[1]), ("daylight", _c[1], _c[2]), ("run", _c[2], _c[3]), ("strata", _c[3], _c[4]),
              ("daylight", _c[4], _c[5]), ("pulse", _c[5], 38.9)],
    universes=[(6.0, "aurora"), (_c[1], "sunset"), (_c[2], "neon"), (_c[3], "space"), (_c[4], "aurora"), (_c[5], "sunset")],
    rise_t=[402 / FPS, _c[1], _c[2], _c[3], _c[4], _c[5], 2322 / FPS], rise_db=[-6, -4, -2, -3, -2, -1, 0], sfx=v5s_sfx())


TIMING_V5P2 = os.path.join(HERE, "film", "src", "v5", "part2", "timing.json")


def v5p2_sfx():
    """SFX of v5part2 (20 s, studio + home + close) from film/src/v5/part2/timing.json."""
    T = json.load(open(TIMING_V5P2, encoding="utf-8"))
    f = lambda x: x / FPS
    ev = [(0.0, "light", -24, 0), (f(2), "glassD5", -27, 0), (f(T["line"]["opens"]), "tic", -22, 0)]
    for c in T["cuts"][1:3]:
        ev += [(f(c) - 0.35, "transition", -26, 0), (f(c), "dock", -22, 0)]
    for k, ch in enumerate(T["studioStore"]["changes"]):
        ev += [(f(ch["f"]), "swipe", -28, 0.3 if k % 2 else -0.3), (f(ch["f"]), "tic", -23 if k < 2 else -21, 0)]
    ev += [(f(302), "glassA5", -27, 0), (f(332), "glassD5", -27, 0)]                    # Aurora / Neon (With Premium)
    ins = T["installation"]
    ev += [(f(ins["cardIn"][0]), "swipe", -26, 0), (f(ins["cardIn"][0]), "pull", -29, 0)]
    for k, w in enumerate(ins["widgets"]):                                              # fly in, then land with a click and a pop
        ev += [(f(w["f"]), "swipe", -29, (-0.4, 0.4, -0.2, 0.2)[k]), (f(w["lands"]), "dock", -17, (-0.4, 0.4, -0.2, 0.2)[k]),
               (f(w["lands"]), "tap", -15, 0), (f(w["lands"]), "glassA6", -29 + k * 0.5, 0)]
    for k, m in enumerate(T["possibilities"]["morphs"]):
        ev += [(f(m), "morph", -22, 0.4 if k % 2 else -0.4), (f(m) + 0.15, "tic", -26, 0)]
    ev += [(f(866) + 0.1, "glassD6", -20, 0)]                                           # glass
    ev += [(f(a), "tic", -26, 0) for a, b in T["premiumPills"][1:]]
    ev += [(f(1002) - 0.55, "pull", -26, 0), (f(1002) - 1.4, "transition", -27, 0)]    # the Home is drawn into the line
    fc = T["finalCard"]
    ev += [(f(fc["logoGrows"]) + 0.02, "logo_in", -20, 0), (f(fc["logoGrows"]) + 0.02, "impact", -22, 0),
           (f(fc["wordmark"]), "tic", -22, 0), (f(fc["cta"]), "tic", -25, 0), (f(fc["tagline"]), "glassA6", -29, 0)]
    return [e for e in ev if e[0] < T["length"] / FPS - 0.3]


_t = [c / FPS for c in (130, 404)]
FILMS["v5part2"] = dict(length=20.0, ceiling=-2.3, logo=1034 / FPS,
    sections=[("void", 0, _t[0]), ("strata", _t[0], _t[1]), ("pulse", _t[1], 866 / FPS), ("daylight", 866 / FPS, 20.0)],
    universes=[(0, "aurora"), (_t[1], "sunset"), (866 / FPS, "space")], sfx=v5p2_sfx())

# --- Wave 1 library films (5 x 9:16 English: lib-meet, lib-toomany, lib-scan, lib-movement, lib-widgets) -------------
LIB_DIR = os.path.join(ROOT, "pub", "film2026", "lib")


def lib_timing(i):
    return json.load(open(os.path.join(LIB_DIR, i, "timing.json"), encoding="utf-8"))


def _endcard_sfx(T):
    f = lambda x: x / FPS
    ec = T["endCard"]
    return [(f(ec["from"]) - 0.35, "transition", -26, 0), (f(ec["from"]), "dock", -22, 0),
            (f(ec["logoGrows"] + 1), "logo_in", -20, 0), (f(ec["logoGrows"] + 1), "impact", -22, 0),
            (f(ec["wordmark"]), "tic", -22, 0), (f(ec["cta"]), "tic", -25, 0), (f(ec["tagline"]), "glassA6", -29, 0)]


def _hook_from_short():
    """The hook of the main film (identical in v5short and lib-toomany): same constants as v5s_sfx."""
    T = json.load(open(TIMING_V5S, encoding="utf-8"))
    f = lambda x: x / FPS
    h, ev = T["hook"], []
    for k, m in enumerate([36, 60, 84, 108, 132]):
        ev.append((f(m), "cut", -27 + 0.6 * k, 0.5 if k % 2 else -0.5))
    for k, fr in enumerate(h["tick"] + [36 + 22 * i for i in range(0, 14)]):
        ev.append((f(fr), "tic" if k % 2 == 0 else "tac", -29 + 0.4 * k, 0))
    b0, gap = h["bannersStart"], h["bannerGap"]
    banners = [b for b in (b0 + gap * k for k in range(14)) if b < h["silence"]["from"] - 4]
    ev += [(f(b), "notif", -27 + 0.4 * k, (-0.5, 0.4, -0.3, 0.6)[k % 4]) for k, b in enumerate(banners)]
    tc = h["tenCounter"]
    ev += [(f(tc["from"]), "counter", -22, 0), (f(tc["slam"]), "tap", -13, 0)]
    for dg, gain in zip((0, 10, 20, 27, 32), (-17, -34, -36, -36, -36)):
        ev.append((f(h["silence"]["from"] + dg), "glitch", gain, 0))
    ev += [(f(h["impact"]), "impact", -8, 0), (f(h["flashPeak"]), "glassD6", -26, 0)]
    return ev


def lib_sfx(i):
    T = lib_timing(i)
    f = lambda x: x / FPS
    ev = []
    if i == "meet":
        ev += [(0.1, "light", -24, 0), (f(62), "logo_in", -17, 0), (f(T["opening"]["turnDone"]), "light", -26, 0),
               (f(T["voiceLines"][1]["onePlace"]), "tic", -22, 0)]
    elif i == "toomany":
        ev += _hook_from_short()
        ev += [(f(446) - 0.35, "transition", -26, 0), (f(470), "logo_in", -17, 0), (f(470) - 0.2, "light", -24, 0),
               (f(546), "light", -26, 0), (f(612), "tic", -22, 0), (f(670), "swipe", -27, 0)]
    elif i == "scan":
        a = T["app"]
        ps = T["photoScan"]
        ev += [(f(a["interfaceVisibleAt"]), "light", -27, 0), (f(a["nameAt"]), "tic", -21, 0), (f(a["nameAt"]), "glassD5", -26, 0)]
        ev += [(f(ps["shutterTap"]), "tap", -14, 0), (f(ps["shutterTap"]), "dock", -17, 0),
               (f(ps["flash"]), "light", -22, 0), (f(ps["flash"]), "glassA6", -26, 0)]
        ev += [(f(c), "tic", -26, 0) for c in (ps["cornersClose"][0], (ps["cornersClose"][0] + ps["cornersClose"][1]) // 2, ps["cornersClose"][1])]
        ev += [(f(ps["sweep"][0]), "blade", -28, -0.4), (f(ps["sweep"][0]) + 0.5, "blade", -29, 0.4), (f(ps["analyzing"]), "tic", -24, 0)]
        ev += [(f(ps["resultsCount"][0]), "counter_s", -26, 0), (f(ps["addToLog"]), "check", -21, 0), (f(ps["addToLog"]), "dock", -20, 0)]
        ev += [(f(d), "swipe", -26, 0.3 if k % 2 else -0.3) for k, d in enumerate(T["dips"])] + [(f(d), "tap", -18, 0) for d in T["dips"]]
        b = T["barcode"]
        ev += [(f(b["barcodeEnters"]), "swipe", -27, 0), (f(b["lineReads"][0]), "barcode", -22, 0),
               (f(b["ring"]), "tap", -15, 0), (f(b["ring"]), "glassA5", -24, 0)]
        ev += [(f(T["result"]["widgetsRise"]), "swipe", -25, 0), (f(T["result"]["widgetsRise"]), "dock", -20, 0),
               (f(T["result"]["widgetsRise"]) + 0.1, "glassD6", -26, 0)]
    elif i == "movement":
        a, lb, dm = T["app"], T["library"], T["demo"]
        ev += [(f(a["interfaceVisibleAt"]), "light", -27, 0), (f(a["nameAt"]), "tic", -21, 0), (f(a["nameAt"]), "glassD5", -26, 0)]
        ev += [(f(lb["search"][0] + 10 * k), "tic", -28, 0.3 if k % 2 else -0.3) for k in range(9)]          # typing in the search
        ev += [(f(lb["tap"]), "tap", -16, 0), (f(lb["expand"][0]), "swipe", -27, 0), (f(lb["expand"][0]), "pull", -29, 0)]
        ev += [(f(dm["from"] + 30 * k), "tick", -30 - (k % 2), -0.3 if k % 2 else 0.3) for k in range((dm["to"] - dm["from"]) // 30)]
        ev += [(f(lp), "glassD5" if k % 2 == 0 else "glassA5", -29, 0) for k, lp in enumerate(dm["loopPoints"][:-1])]
    elif i == "widgets":
        pr, hm = T["process"], T["home"]
        ev += [(0.0, "light", -24, 0), (f(2), "glassD5", -27, 0)]
        for k, (nm, fr) in enumerate(pr["changes"].items()):
            ev += [(f(fr), "swipe", -28, 0.3 if k % 2 else -0.3), (f(fr), "tic", -23 if k < 2 else -21, 0)]
        ev += [(f(pr["changes"]["styleAurora"]) + 0.05, "glassA5", -27, 0), (f(pr["changes"]["styleNeon"]) + 0.05, "glassD5", -27, 0)]
        ev += [(f(c) - 0.35, "transition", -26, 0) for c in T["cuts"][1:]] + [(f(c), "dock", -22, 0) for c in T["cuts"][1:]]
        for k, w in enumerate(hm["installWidgets"]):
            pan = (-0.4, 0.4, -0.2, 0.2)[k]
            ev += [(f(w), "swipe", -29, pan), (f(w + 44), "dock", -17, pan), (f(w + 44), "tap", -15, 0), (f(w + 44), "glassA6", -29 + k * 0.5, 0)]
        for k, m in enumerate(hm["morphs"]):
            ev += [(f(m), "morph", -22, 0.4 if k % 2 else -0.4), (f(m) + 0.15, "tic", -26, 0)]
        ev += [(f(hm["glassFrom"]) + 0.1, "glassD6", -20, 0)]
        ev += [(f(hm["swallow"][0]) - 0.55, "pull", -26, 0), (f(hm["swallow"][0]) - 1.4, "transition", -27, 0)]
    elif i == "build":
        hm = T["home"]
        ev += [(0.1, "light", -25, 0), (f(hm["installAt"]) - 0.3, "pull", -29, 0)]
        for k, w in enumerate(hm["widgetLandings"]):
            pan = (-0.4, 0.4, -0.2, 0.2)[k]
            ev += [(f(w), "swipe", -29, pan), (f(w + 44), "dock", -17, pan), (f(w + 44), "tap", -15, 0), (f(w + 44), "glassA6", -29 + k * 0.5, 0)]
        ev += [(f(hm["landed"]), "glassD5", -24, 0), (f(hm["nativeIconsMorph"][0]), "morph", -22, 0),
               (f(hm["nativeIconsMorph"][0]) + 0.15, "tic", -26, 0), (f(hm["nativeIconsMorph"][1]), "glassA5", -26, 0)]
        ev += [(f(hm["swallow"][0]) - 0.35, "pull", -26, 0), (f(hm["swallow"][0]) - 1.3, "transition", -27, 0)]
    elif i == "style":
        hm = T["home"]
        ev += [(0.1, "light", -25, 0), (0.12, "glassD5", -27, 0)]
        for k, m in enumerate(hm["morphs"]):
            ev += [(f(m), "morph", -22, 0.4 if k % 2 else -0.4), (f(m) + 0.15, "tic", -26, 0)]
        ev += [(f(c["from"]) + 0.1, "glassA5" if k % 2 else "glassD5", -27, 0) for k, c in enumerate(hm["configs"]) if c.get("premium")]
        ev += [(f(hm["swallow"][0]) - 0.35, "pull", -26, 0), (f(hm["swallow"][0]) - 1.3, "transition", -27, 0)]
    elif i == "apptowidget":
        for sc in T["scenes"]:
            if sc["id"].endswith("App"):
                ev += [(f(sc["from"] + sc["titleAt"]), "tic", -21, 0), (f(sc["from"] + sc["titleAt"]), "glassD5", -26, 0),
                       (f(sc["from"] + sc["titleAt"] - 8), "light", -27, 0),
                       (f(sc["from"] + sc["widgetsRise"]), "swipe", -25, 0), (f(sc["from"] + sc["widgetsRise"]), "dock", -20, 0),
                       (f(sc["from"] + sc["widgetsRise"]) + 0.1, "glassD6", -26, 0)]
            else:
                ev += [(f(l), "dock", -17, -0.3 if k else 0.3) for k, l in enumerate(sc["landings"])]
                ev += [(f(l), "tap", -15, 0) for l in sc["landings"]] + [(f(l), "glassA6", -28, 0) for l in sc["landings"]]
            ev += [(f(sc["swallow"][0]) - 0.2, "pull", -26, 0)]
        ev += [(f(c) - 0.35, "transition", -26, 0) for c in T["cuts"][1:]] + [(f(c), "dock", -22, 0) for c in T["cuts"][1:]]
    elif i == "onescreen":
        hm = T["home"]
        ev += [(0.1, "light", -25, 0)]
        for k, w in enumerate(hm["landings"]):
            pan = (-0.4, 0.4, -0.2, 0.2, 0.0)[k]
            ev += [(f(w["f"]), "swipe", -29, pan), (f(w["lands"]), "dock", -17, pan), (f(w["lands"]), "tap", -15, 0),
                   (f(w["lands"]), ("D5", "F#5", "A5", "D6", "F#6")[k], -24, 0)]
        ev += [(f(hm["swallow"][0]) - 0.35, "pull", -26, 0), (f(hm["swallow"][0]) - 1.3, "transition", -27, 0)]
    elif i == "everything":
        for a in T["apps"]:
            ev += [(f(a["nameAt"]), "tic", -21, 0), (f(a["nameAt"]), "glassD5", -26, 0), (f(a["nameAt"]) - 0.1, "light", -27, 0)]
        ev += [(f(c) - 0.35, "transition", -26, 0) for c in T["cuts"][1:-1]] + [(f(c), "dock", -22, 0) for c in T["cuts"][1:-1]]
        b = T["barcode"]
        ev += [(f(b["barcodeEnters"]), "swipe", -27, 0), (f(b["lineReads"][0]), "barcode", -22, 0), (f(b["lineReads"][1]) + 0.1, "tap", -15, 0),
               (f(b["lineReads"][1]) + 0.1, "glassA5", -24, 0)]
        ev += [(f(204), "check", -21, 0)]                                                     # "Track it."
        bd = T["benchDemo"]
        ev += [(f(bd["tap"]), "tap", -16, 0), (f(bd["expand"][0]), "swipe", -27, 0), (f(bd["expand"][0]), "pull", -29, 0)]
        ev += [(f(bd["demoFrom"] + 30 * k), "tick", -30 - (k % 2), -0.3 if k % 2 else 0.3) for k in range((bd["demoTo"] - bd["demoFrom"]) // 30)]
        ev += [(f(bd["demoFrom"]), "glassD5", -29, 0)]
    ev += _endcard_sfx(T)
    return [e for e in ev if e[0] < T["length"] / FPS - 0.3]


def _lib_cfg(i):
    T = lib_timing(i)
    L = T["length"] / FPS
    lg = T["endCard"]["logoGrows"] / FPS
    base = dict(length=L, ceiling=-2.8, logo=lg, sfx=lib_sfx(i))
    if i == "meet":
        base.update(sections=[("void", 0, 1.0), ("strata", 1.0, 99)], universes=[(0, "aurora")])
    elif i == "toomany":
        base.update(custom="v3", impact=402 / FPS, silence_from=366 / FPS, sections=[("strata", 6.0, 99)], universes=[(6.0, "aurora")])
    elif i == "scan":
        base.update(sections=[("daylight", 0, 99)], universes=[(0, "sunset")])
    elif i == "movement":
        base.update(sections=[("pulse", 0, 99)], universes=[(0, "sunset")])
    elif i == "widgets":
        h = T["home"]
        base.update(sections=[("void", 0, 0.4), ("strata", 0.4, h["from"] / FPS), ("pulse", h["from"] / FPS, h["glassFrom"] / FPS),
                              ("daylight", h["glassFrom"] / FPS, 99)],
                    universes=[(0, "aurora"), (h["from"] / FPS, "sunset"), (h["glassFrom"] / FPS, "space")])
    elif i == "build":
        base.update(sections=[("strata", 0, T["home"]["landed"] / FPS), ("pulse", T["home"]["landed"] / FPS, 99)],
                    universes=[(0, "aurora"), (T["home"]["landed"] / FPS, "sunset")])
    elif i == "style":
        base.update(sections=[("strata", 0, 5.0), ("daylight", 5.0, 99)], universes=[(0, "aurora"), (5.0, "space")])
    elif i == "apptowidget":
        base.update(sections=[("daylight", 0, 350 / FPS), ("strata", 350 / FPS, 99)], universes=[(0, "sunset"), (350 / FPS, "space")])
    elif i == "onescreen":
        base.update(sections=[("pulse", 0, 99)], universes=[(0, "aurora")])
    elif i == "everything":
        base.update(sections=[("daylight", 0, 260 / FPS), ("run", 260 / FPS, 550 / FPS), ("strata", 550 / FPS, 790 / FPS), ("daylight", 790 / FPS, 99)],
                    universes=[(0, "sunset"), (260 / FPS, "neon"), (550 / FPS, "space"), (790 / FPS, "aurora")])
    return base


LIB2 = ("scan", "movement", "everything", "widgets", "build", "style", "apptowidget", "onescreen", "scanproduct", "knoweat",
        "nutrisimple", "nutriday", "buildworkout", "trainsmarter", "journey", "controlday", "knowmoney")
_NOTES = ("D5", "F#5", "A5", "D6", "F#6")


def _hook_sfx(T):
    """Sound design of the 2.5-4 s question hook, one idea per staging (intro.variant): break, align, scan, count..."""
    f = lambda x: x / FPS
    iv = T["intro"]
    v, ws, (s0, s1) = iv["variant"], iv["words"], iv["swallow"]
    ev = [(f(w["f"]), "tic", -28, 0) for w in ws]
    if v == "shatter":
        ev += [(f(24), "glitch", -23, 0), (f(ws[-1]["f"]), "blade", -26, 0.4)]
    elif v == "rep":
        ev += [(f(w["f"]), "tick", -27, 0.3 if k % 2 else -0.3) for k, w in enumerate(ws)]
    elif v == "grid":
        ev += [(f(w["f"]), "notif", -27, 0.5 if k % 2 else -0.5) for k, w in enumerate(ws)]
    elif v == "snap":
        ev += [(f(44), "dock", -19, 0), (f(64), "tap", -14, 0), (f(64), "glassA6", -26, 0)]
    elif v == "phoneGrid":
        ev += [(f(w["f"]), "dock", -24, 0.4 if k % 2 else -0.4) for k, w in enumerate(ws)]
    elif v == "split":
        ev += [(f(24), "split", -26, 0), (f(60), "split", -26, 0)]
    elif v == "flow":
        ev += [(f(w["f"]), "swipe", -29, 0.4 if k % 4 else -0.4) for k, w in enumerate(ws) if k % 2 == 0]
    elif v == "dots":
        ev += [(f(w["f"]), _NOTES[k], -25, 0) for k, w in enumerate(ws[2:7])]
    elif v == "barcode":
        ev += [(f(42), "swipe", -27, 0), (f(ws[-1]["f"]), "barcode", -22, 0)]
    elif v == "ring":
        ev += [(f(24), "pull", -28, 0), (f(ws[-1]["f"]), "glassD5", -24, 0)]
    elif v == "counter":
        txt = iv["text"]
        if txt.startswith("Day"):                                       # Day 1 ... Day 90
            ev += [(f(44), "counter_s", -24, 0), (f(84), "tap", -13, 0)]
        else:                                                           # Meals, goals, macros. Ten taps? Or one place.
            ev += [(f(84), "counter", -23, 0), (f(104), "tap", -13, 0), (f(ws[-1]["f"]), "glassD5", -24, 0)]
    elif v == "words":
        ev += [(f(w["f"]), _NOTES[min(4, k * 5 // len(ws))], -25, 0) for k, w in enumerate(ws)]
    elif v == "clock":                                                  # tic-tac, the pulse tightening
        ev += [(f(k), "tic" if (k - 12) // 15 % 2 == 0 else "tac", -26 + 0.15 * ((k - 12) // 15), 0) for k in range(12, s0, 15)]
    elif v == "rows":
        ev += [(f(w["f"]), "dock", -21, 0.4 if k % 2 else -0.4) for k, w in enumerate(ws)]
    elif v == "rise":
        ev += [(f(24), "pull", -28, 0)] + [(f(w["f"]), _NOTES[min(4, k * 5 // len(ws))], -25, 0) for k, w in enumerate(ws)]
    ev += [(f(s0) - 0.05, "pull", -27, 0)]                                 # the hook is drawn into the line
    return ev


def lib2_sfx(i):
    T = lib_timing(i)
    f = lambda x: x / FPS
    ev = _hook_sfx(T)
    ie = T["introEnd"]
    ev += [(f(ie), "dock", -22, 0), (f(ie) + 0.02, "light", -25, 0)]
    ec = T["endCard"]
    for c in T["cuts"]:
        if c not in (ie, ec["from"]):
            ev += [(f(c) - 0.35, "transition", -26, 0), (f(c), "dock", -22, 0)]
    if "beat" in T:                                                     # the "Ardane." beat
        b = T["beat"]
        ev += [(f(b["logo"]), "logo_in", -17, 0), (f(b["logo"]), "glassD5", -26, 0), (f(b["from"]) - 0.3, "swipe", -27, 0)]
    for v in T["voiceLines"]:
        if v.get("kind") == "name":
            ev += [(f(v["f"]), "tic", -21, 0), (f(v["f"]), "glassD5", -26, 0), (f(v["f"]) - 0.15, "light", -27, 0)]
    ev += [(f(d), "swipe", -26, 0.3 if k % 2 else -0.3) for k, d in enumerate(T.get("dips", []))]
    ev += [(f(d), "tap", -18, 0) for d in T.get("dips", [])]
    ev += [(f(h["from"]), "tic", -31, 0) for h in T.get("highlights", [])]
    ps = T.get("photoScan")
    if ps:
        if "flash" in ps:
            ev += [(f(ps["shutterTap"]), "tap", -14, 0), (f(ps["shutterTap"]), "dock", -17, 0),
                   (f(ps["flash"]), "light", -22, 0), (f(ps["flash"]), "glassA6", -26, 0)]
        else:
            ev += [(f(ps["shutterTap"]), "tap", -14, 0), (f(ps["shutterTap"]), "dock", -17, 0)]
        if "cornersClose" in ps:
            ev += [(f(c), "tic", -26, 0) for c in (ps["cornersClose"][0], (ps["cornersClose"][0] + ps["cornersClose"][1]) // 2, ps["cornersClose"][1])]
        ev += [(f(ps["sweep"][0]), "blade", -28, -0.4), (f(ps["sweep"][0]) + 0.5, "blade", -29, 0.4), (f(ps["analyzing"]), "tic", -24, 0)]
        if "resultsCount" in ps:
            ev += [(f(ps["resultsCount"][0]), "counter_s", -26, 0), (f(ps["addToLog"]), "check", -21, 0), (f(ps["addToLog"]), "dock", -20, 0)]
    b = T.get("barcode") or T.get("scan")
    if b:
        ev += [(f(b["barcodeEnters"]), "swipe", -27, 0), (f(b["lineReads"][0]), "barcode", -22, 0),
               (f(b["lineReads"][1]) + 0.1, "tap", -15, 0), (f(b["lineReads"][1]) + 0.1, "glassA5", -24, 0)]
    if "result" in T:
        wr = T["result"]["widgetsRise"]
        ev += [(f(wr), "swipe", -25, 0), (f(wr), "dock", -20, 0), (f(wr) + 0.1, "glassD6", -26, 0)]
    lb = T.get("library")
    if lb:
        ev += [(f(lb["search"][0] + 10 * k), "tic", -28, 0.3 if k % 2 else -0.3) for k in range((lb["search"][1] - lb["search"][0]) // 10 + 1)]
        ev += [(f(lb["tap"]), "tap", -16, 0), (f(lb["expand"][0]), "swipe", -27, 0), (f(lb["expand"][0]), "pull", -29, 0)]
    dm = T.get("demo") or T.get("benchDemo")
    if dm:
        a0 = dm.get("from", dm.get("demoFrom"))
        a1 = dm.get("to", dm.get("demoTo"))
        ev += [(f(a0 + 30 * k), "tick", -30 - (k % 2), -0.3 if k % 2 else 0.3) for k in range((a1 - a0) // 30)]
        ev += [(f(lp), "glassD5" if k % 2 == 0 else "glassA5", -29, 0) for k, lp in enumerate(dm.get("loopPoints", [a0])[:-1])]
        if "tap" in dm:
            ev += [(f(dm["tap"]), "tap", -16, 0), (f(dm["expand"][0]), "swipe", -27, 0), (f(dm["expand"][0]), "pull", -29, 0)]
    ll = T.get("lockLive")
    if ll:                                                              # Live Activity: a soft pop, a tap, then slow ticks of the rest timer
        ev += [(f(ll["activityPopsUp"]), "tap", -17, 0), (f(ll["activityPopsUp"]), "glassA6", -27, 0), (f(ll["activityPopsUp"]) - 0.1, "swipe", -28, 0),
               (f(ll["setDoneTap"]), "tap", -15, 0), (f(ll["setDoneTap"]), "check", -22, 0)]
        ev += [(f(ll["afterSet"] + 60 * k), "tic", -29, 0) for k in range(4)]
    for k, pl in enumerate(T.get("pills", [])):
        ev += [(f(pl["at"]), "dock", -20, 0), (f(pl["at"]), "glassA6", -27, 0)]
    for a in T.get("apps", []):
        ev += [(f(a["nameAt"]) - 0.1, "light", -27, 0)]
    pr = T.get("process")
    if pr:
        for k, (nm, fr) in enumerate(pr["changes"].items()):
            ev += [(f(fr), "swipe", -28, 0.3 if k % 2 else -0.3), (f(fr), "tic", -23 if k < 2 else -21, 0)]
        ev += [(f(pr["changes"]["styleAurora"]) + 0.05, "glassA5", -27, 0), (f(pr["changes"]["styleNeon"]) + 0.05, "glassD5", -27, 0)]
    if "line" in T and "ignites" in T["line"]:
        ev += [(f(T["line"]["ignites"]), "light", -24, 0)]
    for sc in T.get("scenes", []):                                      # apptowidget
        if sc["id"].endswith("App"):
            wr = sc["swallow"][0] - 52
            ev += [(f(wr), "swipe", -25, 0), (f(wr), "dock", -20, 0), (f(wr) + 0.1, "glassD6", -26, 0)]
        else:
            ev += [(f(l), "dock", -17, -0.3 if k else 0.3) for k, l in enumerate(sc["landings"])]
            ev += [(f(l), "tap", -15, 0) for l in sc["landings"]] + [(f(l), "glassA6", -28, 0) for l in sc["landings"]]
        ev += [(f(sc["swallow"][0]) - 0.2, "pull", -26, 0)]
    for hm in (T.get("home"), T.get("home2")):
        if not hm:
            continue
        lands = []
        if "installWidgets" in hm:
            lands = [(w, w + 44) for w in hm["installWidgets"]]
        elif "widgetLandings" in hm:
            lands = [(w, w + 44) for w in hm["widgetLandings"]]
        elif hm.get("landings") and isinstance(hm["landings"][0], dict):
            lands = [(w["f"], w["lands"]) for w in hm["landings"]]
        elif hm.get("landings") and "scenes" not in T:
            lands = [(w, w + 44) for w in hm["landings"]]
        elif "installAt" in hm and "stagger" in hm:
            n = len(hm.get("widgets", [0, 0])) if hm.get("widgets") else 2
            lands = [(hm["installAt"] + k * hm["stagger"], hm["installAt"] + k * hm["stagger"] + 44) for k in range(n)]
        for k, (a, l) in enumerate(lands):
            pan = (-0.4, 0.4, -0.2, 0.2, 0.0)[k % 5]
            ev += [(f(a), "swipe", -29, pan), (f(l), "dock", -17, pan), (f(l), "tap", -15, 0),
                   (f(l), _NOTES[k % 5] if len(lands) == 5 else "glassA6", -26 if len(lands) == 5 else -29 + k * 0.5, 0)]
        if "landed" in hm:
            ev += [(f(hm["landed"]), "glassD5", -24, 0)]
        if "nativeIconsMorph" in hm:
            ev += [(f(hm["nativeIconsMorph"][0]), "morph", -22, 0), (f(hm["nativeIconsMorph"][0]) + 0.15, "tic", -26, 0),
                   (f(hm["nativeIconsMorph"][1]), "glassA5", -26, 0)]
        native = hm.get("nativeIconsMorph", [None])[0]
        for k, m in enumerate(m_ for m_ in hm.get("morphs", []) if m_ != native):
            ev += [(f(m), "morph", -22, 0.4 if k % 2 else -0.4), (f(m) + 0.15, "tic", -26, 0)]
        for k, st in enumerate(x for x in hm.get("stages", []) if x.get("premium")):   # Premium looks: a glass note
            ev += [(f(st["from"]) + 0.12, _NOTES[k % 5], -26, 0)]
        if "glassFrom" in hm:
            ev += [(f(hm["glassFrom"]) + 0.1, "glassD6", -20, 0)]
        ev += [(f(c["from"]) + 0.1, "glassA5" if k % 2 else "glassD5", -27, 0) for k, c in enumerate(hm.get("configs", []))
               if isinstance(c, dict) and c.get("premium")]
        if "swallow" in hm:
            ev += [(f(hm["swallow"][0]) - 0.35, "pull", -26, 0), (f(hm["swallow"][0]) - 1.3, "transition", -27, 0)]
    ev += _endcard_sfx(T)
    return [e for e in ev if e[0] < T["length"] / FPS - 0.3]


def _lib2_cfg(i):
    T = lib_timing(i)
    s_ = lambda x: x / FPS
    L = T["length"] / FPS
    ie = s_(T["introEnd"])
    ec = T["endCard"]
    base = dict(length=L, ceiling=-2.8, logo=s_(ec["logoGrows"]), sfx=lib2_sfx(i))
    home = T.get("home", {})
    app0 = s_(T["app"]["from"]) if "app" in T else ie
    h0 = s_(home["from"]) if "from" in home else 99
    sec, uni = [("void", 0, ie)], [(0, "aurora")]
    if i == "scan":
        sec += [("daylight", ie, h0), ("pulse", h0, 99)]; uni += [(ie, "sunset")]
    elif i == "movement":
        lk = s_(T["lockLive"]["from"])
        sec += [("pulse", ie, lk), ("strata", lk, h0), ("daylight", h0, 99)]; uni += [(ie, "sunset"), (lk, "aurora")]
    elif i == "everything":
        c = [s_(x) for x in T["cuts"]]
        sec += [("daylight", ie, c[2]), ("run", c[2], c[3]), ("strata", c[3], c[4]), ("daylight", c[4], c[5]), ("pulse", c[5], 99)]
        uni += [(ie, "sunset"), (c[2], "neon"), (c[3], "space"), (c[4], "aurora")]
    elif i == "widgets":
        sec += [("strata", ie, h0), ("pulse", h0, s_(home["glassFrom"])), ("daylight", s_(home["glassFrom"]), 99)]
        uni += [(ie, "aurora"), (h0, "sunset"), (s_(home["glassFrom"]), "space")]
    elif i == "build":
        sec += [("strata", ie, s_(home["landed"])), ("pulse", s_(home["landed"]), 99)]; uni += [(s_(home["landed"]), "sunset")]
    elif i == "style":
        sec += [("strata", ie, s_(home["morphs"][0])), ("daylight", s_(home["morphs"][0]), 99)]; uni += [(s_(home["morphs"][0]), "space")]
    elif i == "apptowidget":
        c = [s_(x) for x in T["cuts"]]
        sec += [("daylight", ie, c[3]), ("strata", c[3], 99)]; uni += [(ie, "sunset"), (c[3], "space")]
    elif i == "onescreen":
        sec += [("pulse", ie, 99)]; uni += [(ie, "aurora")]
    elif i in ("scanproduct", "knoweat", "nutrisimple", "nutriday"):
        sec += [("strata", ie, app0), ("daylight", app0, h0), ("pulse", h0, 99)]; uni += [(ie, "aurora"), (app0, "sunset")]
    elif i == "controlday":   # calm, precise pulse
        sec += [("strata", ie, app0), ("pulse", app0, h0), ("daylight", h0, 99)]; uni += [(ie, "aurora"), (app0, "minimal")]
    elif i == "knowmoney":    # sober daylight
        sec += [("strata", ie, app0), ("daylight", app0, 99)]; uni += [(ie, "aurora"), (app0, "space")]
    else:   # buildworkout, trainsmarter, journey
        sec += [("strata", ie, app0), ("pulse", app0, h0), ("run", h0, 99)]; uni += [(ie, "aurora"), (app0, "neon")]
    base.update(sections=sec, universes=uni)
    return base


for _i in ("meet", "toomany"):
    FILMS["lib-" + _i] = _lib_cfg(_i)
for _i in LIB2:
    FILMS["lib-" + _i] = _lib2_cfg(_i)

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
    pre = cfg.get("music_end", cfg["logo"] - PRE_LOGO_SILENCE)
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
    if cfg.get("swell"):  # a discreet rise under the tease line
        a0, a1 = cfg["swell"]
        sw_ = S.riser(a1 - a0, low=1200, high=9000, seed=21)
        place(track, sw_, a0, db(-33))
    if cfg.get("accel"):  # Process: D major arpeggio that speeds up slightly
        from score import pluck, add as sadd
        a0, a1 = cfg["accel"]
        t, j = a0, 0
        while t < a1 - 0.1:
            fq = note(["D5", "F#5", "A5", "D6", "A5", "F#5"][j % 6])
            sadd(track, pluck(fq, "aurora", 0.3), t, db(-27 + 3 * (t - a0) / (a1 - a0)), pan=-0.3 if j % 2 else 0.3)
            t += 0.25 - 0.07 * ((t - a0) / (a1 - a0))
            j += 1
    if cfg.get("end_swell"):   # part 1 of the main film: no logo card, a swell into the final flash, then fade to black
        return music_end_swell(track, cfg, n)
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


def music_end_swell(track, cfg, n):
    from score import pad_layer, CH
    s0, fl, black = cfg["end_swell"]
    pads = np.zeros((n, 2))
    pad_layer(pads, s0, fl - s0, CH["Dmaj9"], db(-17), cutoff=1400, attack=3.0, release=0.4)
    pad_layer(pads, s0 + 1.5, fl - s0 - 1.5, CH["Dmaj9"], db(-19), cutoff=3000, attack=2.0, release=0.4)
    track += reverb(pads.mean(axis=1), 3.0, 0.35)
    place(track, sub(note("D1"), fl - s0 + 3.0, attack=3.4, release=2.5), s0, db(-19))
    # The flash: D major bloom (glass D5 / A5 / D6), a sub hit, then everything fades to black.
    for nn, dt, g in (("D5", 0.0, -14), ("A5", 0.06, -15), ("D6", 0.12, -17), ("F#6", 0.2, -22)):
        place(track, reverb(np.pad(fm_glass(note(nn), 2.0, index=3.0, decay=1.2), (0, SR)), 3.0, 0.35), fl + dt, db(g))
    place(track, sub(note("D1"), 1.8, attack=0.004, release=1.4), fl, db(-15))
    f0 = int((fl + 0.15) * SR)
    e = int(black * SR)
    track[f0:e] *= np.linspace(1, 0, e - f0)[:, None]
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
        "transition": S.cue_transition, "check": S.cue_check, "barcode": S.cue_barcode, "morph": S.cue_morph, "counter_s": lambda: S.cue_counter(0.7, 8),
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
    if cfg.get("end_swell"):  # let the tails die before the black instead of cutting them
        e = int(cfg["end_swell"][2] * SR)
        nf = int(0.5 * SR)
        tr[e - nf:e] *= np.linspace(1, 0, nf)[:, None]
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
def master(music, sfx, voice, ceiling=-1.2):
    d = M.duck_envelope(voice)
    gain = 1 - (1 - db(DUCK_DB)) * d
    mid = M.filt(music, "bandpass", [2000, 4000])
    music = music * gain[:, None] - mid * (1 - db(-2.5)) * d[:, None]
    mixdown = music + sfx + voice
    meter = pyln.Meter(SR)
    scale = 1.0
    for _ in range(3):
        mixdown *= db(-14 - meter.integrated_loudness(mixdown))
        mixdown = M.limit(mixdown, db(ceiling))
    return mixdown, music, d


def mix_film(film, lang, stems=False):
    cfg = FILMS[film]
    n = int(round(cfg["length"] * SR))
    music = music_stem(film)
    meter = pyln.Meter(SR)
    music *= db(MUSIC_BED_LUFS + cfg.get("bed_db", 0) - meter.integrated_loudness(music))
    sfx = sfx_stem(film, lang)
    voice, report = voice_stem(film, lang)
    mixdown, music_d, d = master(music, sfx, voice, cfg.get("ceiling", -1.2))
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
        results = []
        for f in films:
            r = mix_film(f, lang, stems)
            if "--auto-gap" in sys.argv and r["gap"] is not None and r["gap"] < 12.4:   # voice >= 12 dB above the music
                FILMS[f]["bed_db"] = FILMS[f].get("bed_db", 0) - (12.4 - r["gap"])
                r = mix_film(f, lang, stems)
            results.append(r)
        json.dump(results, open(os.path.join(OUT_DIR, lang, "report.json"), "w"), indent=1)
