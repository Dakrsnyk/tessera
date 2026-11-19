"""Bande-son des deux pubs du 2026-11-18 (MainPub26 et WidgetPub26) : voix + musique + bruitages, mixés.

Rien n'est inventé : mêmes moteurs, mêmes réglages que la pub principale validée (main-v5-final6) :
  - voix : Kokoro af_heart, vitesse 1.0, « Ardane » = ar-DAHN (vo.py + vo_spec_pub26.json) ; « Nutrition. » « Fitness. » « Planning. »
    et l'accroche (H1, H2) reprennent les enregistrements validés de v5short, l'outro (C1) celui de v5part2 ;
  - musique : audio2026.music_stem (partition D mineur -> D majeur, 120 BPM) ; pour la Main Pub, la MÊME configuration que v5short
    jusqu'à la fin de l'accroche (0 à 7,43 s identiques) puis la suite de la partition, et la vraie fin de v5part2 sur la carte finale ;
  - bruitages : v5s_sfx pour l'accroche, puis les bruitages de v5s / v5p2 calés sur les plans de timing26.ts ;
  - mixage : audio2026.master (ducking 5 dB, limiteur), « ding » baissés de 8 dB (remix_soft_dings.soften), -14 LUFS.
Pour que l'accroche reste IDENTIQUE à mix-v5short.wav, la Main Pub reprend les gains exacts de v5short (musique, voix, trois étapes
de mastering), puis un petit gain constant après l'accroche (rampe de 2 s) ramène le programme à -14 LUFS.

    ~/ardane-tools/venv/Scripts/python.exe -I -X utf8 scripts/ad2/audio_pub26.py all        # tout refaire
    ... audio_pub26.py voice | calib | main | widget | check
Variables : ARDANE_FILM (projet Remotion, défaut ~/ardane-tools/film), ARDANE_HF_CACHE (modèles Whisper).
Aucune écriture hors de pub/pub26/audio/ et de <ARDANE_FILM>/public/audio/en/ (mix-pub26-main.wav, mix-pub26-widget.wav).
"""
import json
import os
import re
import subprocess
import sys

import numpy as np
import pyloudnorm as pyln
import soundfile as sf
from scipy.signal import resample_poly

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import audio2026 as A  # noqa: E402
import mix as M  # noqa: E402
import remix_soft_dings  # noqa: E402
from synth import SR, db  # noqa: E402

ROOT = A.ROOT
FPS = 60
FILM = os.environ.get("ARDANE_FILM") or os.path.join(os.path.expanduser("~"), "ardane-tools", "film")
OUT = os.path.join(ROOT, "pub", "pub26", "audio")
WORK = os.path.join(OUT, "work")
VO = os.path.join(OUT, "vo")
PUBLIC_EN = os.path.join(FILM, "public", "audio", "en")
DING_DB = -8.0
VOICE_LIFT = -1.6                           # dB: the voice after the hook (changed in the silence between H2 and M0). v1: +1.5 ; v2.3: -1.6 (v2: -1.35 ; -1.25: -13.9 LUFS at best ; -1.5: voice only 10.4 dB over the music ; -1.0: -13.7 LUFS even with the music at -34 dB ; -2.0: the music has to rise, voice only 7 dB above it), the voice now speaks almost all the time and alone would pass -14 LUFS
AFTER_HOOK_CEILING = -1.5                   # dBFS: the limiter ceiling after the hook (hook: -2.8, as v5short)
HOOK_TRIM_FROM, HOOK_TRIM_RAMP = 446 / FPS, 2.0   # the post-hook gain of music and bruitages starts at the end of the hook, over 2 s
OUTRO_OFFSET = 26                           # frames after the close card (validated: v5part2 1056 - 1030)

remix_soft_dings.soften(DING_DB)            # the validated setting (changes the sound bank of audio2026 in this process only)


def f(x):
    return x / FPS


def timing():
    """timing26.ts as JSON (node strips the types): the only source of every duration."""
    ts = os.path.join(FILM, "src", "pub26", "timing26.ts").replace("\\", "/")
    js = f"import * as T from 'file:///{ts}'; console.log(JSON.stringify(T));"
    out = subprocess.run(["node", "--experimental-strip-types", "--no-warnings", "--input-type=module", "-e", js],
                         capture_output=True, text=True, check=True).stdout
    return json.loads(out)


# --------------------------------------------------------------------------------------------- voice
def vo_files(T):
    """(id, start in seconds, wav) of every line of both films."""
    v5s = os.path.join(A.VO_DIR, "en", "v5short")
    p2 = os.path.join(A.VO_DIR, "en", "v5part2", "v5part2-C1.wav")
    validated = {"M2": os.path.join(v5s, "v5short-NA.wav"), "M3": os.path.join(v5s, "v5short-FA.wav"), "M4": os.path.join(v5s, "v5short-PA.wav")}
    main_files = {l["id"]: validated.get(l["id"], os.path.join(VO, f"pub26main-{l['id']}.wav")) for l in T["MAIN_VO"]}
    hs = hook_starts()
    main = [("H1", hs["H1"], os.path.join(v5s, "v5short-H1.wav")), ("H2", hs["H2"], os.path.join(v5s, "v5short-H2.wav"))]
    main += [(l["id"], f(l["at"]), main_files[l["id"]]) for l in T["MAIN_VO"]]
    main.append(("OUTRO", f(T["MAIN"]["close"]["from"] + T["OUTRO_AT"]), p2))
    wid = [(l["id"], f(l["at"]), os.path.join(VO, f"pub26widget-{l['id']}.wav")) for l in T["WIDGET_VO"]]
    wid.append(("OUTRO", f(T["WIDGET"]["close"]["from"] + T["OUTRO_AT"]), p2))
    return main, wid


def hook_starts():
    """Start (s) of the two validated hook lines in v5short (spec of the validated film)."""
    spec = json.load(open(A.SPEC["en"], encoding="utf-8"))
    return {l["id"]: l["start"] for ch in spec["films"]["v5short"]["chunks"] for l in ch}


def load(path):
    a, sr = sf.read(path, dtype="float64")
    a = a.mean(axis=1) if a.ndim > 1 else a
    return resample_poly(a, SR, sr) if sr != SR else a


def voice_stem(lines, n, gain=None):
    """lines: [(id, start s, wav)]. The same chain as audio2026.voice_stem; `gain` (linear) fixes the level, otherwise -16 LUFS."""
    tr = np.zeros(n)
    for _, start, path in lines:
        a = load(path)
        i = int(round(start * SR))
        e = min(n, i + len(a))
        tr[i:e] += a[: e - i]
    tr = M.voice_chain(tr)
    meter = pyln.Meter(SR)
    voiced = tr[np.abs(tr).mean(axis=1) > 1e-4]
    g = db(-16 - meter.integrated_loudness(voiced)) if gain is None else gain
    return tr * g, g


# --------------------------------------------------------------------------------------------- master
def master(music, sfx, voice, ceiling, scales=None, env=None, after_hook_ceiling=None, steps=3):
    """audio2026.master, with the possibility to replay recorded scales (hook identical) and a gain envelope after the hook."""
    d = M.duck_envelope(voice)
    gain = 1 - (1 - db(A.DUCK_DB)) * d
    mid = M.filt(music, "bandpass", [2000, 4000])
    music_d = music * gain[:, None] - mid * (1 - db(-2.5)) * d[:, None]
    if env is not None:                       # the post-hook gain goes to music and bruitages only: the voice keeps the level of the hook
        music_d, sfx = music_d * env[:, None], sfx * env[:, None]
    mixdown = music_d + sfx + voice
    meter = pyln.Meter(SR)
    rec = []
    ceiling_lin = db(ceiling)
    if after_hook_ceiling is not None:         # validated ceiling during the hook, a higher one after it (the hook stays identical)
        t = np.arange(len(mixdown)) / SR
        ceiling_lin = np.where(t < HOOK_TRIM_FROM + 0.1, db(ceiling), db(after_hook_ceiling))
    for k in range(steps):
        s = scales[k] if scales else db(-14 - meter.integrated_loudness(mixdown))
        rec.append(float(s))
        mixdown = M.limit(mixdown * s, ceiling_lin)
    return mixdown, music_d, d, rec


def gap(voice, music_d, d):
    """Voice level above the music while she speaks (audio2026.mix_film's measure; its target is >= 12 dB)."""
    a = d > 0.9
    m = pyln.Meter(SR)
    return m.integrated_loudness(voice[a]) - m.integrated_loudness(music_d[a])


def finish(mixdown, n, seconds):
    mixdown = mixdown[:n].copy()
    k = int((seconds - 0.05) * SR)
    mixdown[k:] *= np.linspace(1, 0, n - k)[:, None]
    return mixdown


# --------------------------------------------------------------------------------------------- calibration on v5short
def calibrate():
    """Re-renders v5short (same chain), checks it against the validated mix-v5short.wav, and records the gains to replay."""
    os.makedirs(WORK, exist_ok=True)
    cfg = A.FILMS["v5short"]
    n = int(round(cfg["length"] * SR))
    music = A.music_stem("v5short")
    sf.write(os.path.join(WORK, "music-v5short.wav"), music[: 12 * SR].astype(np.float32), SR, subtype="FLOAT")
    bed_db = A.MUSIC_BED_LUFS + cfg.get("bed_db", 0) - pyln.Meter(SR).integrated_loudness(music)
    music = music * db(bed_db)
    sfx = A.sfx_stem("v5short", "en")
    spec = json.load(open(A.SPEC["en"], encoding="utf-8"))
    lines = [(l["id"], l["start"], os.path.join(A.VO_DIR, "en", "v5short", f"v5short-{l['id']}.wav"))
             for ch in spec["films"]["v5short"]["chunks"] for l in ch]
    voice, gv = voice_stem(lines, n)
    mixdown, md, dd, rec = master(music, sfx, voice, cfg["ceiling"])
    print(f"calib v5short: voice-music gap {gap(voice, md, dd):.1f} dB")
    mixdown = finish(mixdown, n, cfg["length"])
    ref, _ = sf.read(os.path.join(PUBLIC_EN, "mix-v5short.wav"), dtype="float64")
    m = min(len(ref), len(mixdown))
    err = np.abs(mixdown[:m] - ref[:m]).max()
    hook = int(HOOK_TRIM_FROM * SR)
    print(f"calib v5short: re-render vs validated mix: max abs diff {err:.2e} (full), hook {np.abs(mixdown[:hook] - ref[:hook]).max():.2e}")
    cal = {"bed_db": float(bed_db), "voice_gain": float(gv), "scales": rec, "max_diff_vs_validated": float(err)}
    json.dump(cal, open(os.path.join(WORK, "calib.json"), "w"), indent=1)
    return cal


def get_calib():
    p = os.path.join(WORK, "calib.json")
    return json.load(open(p)) if os.path.exists(p) else calibrate()


# --------------------------------------------------------------------------------------------- sound effects
def finalcard_sfx(T, close_from):
    fc = json.load(open(A.TIMING_V5P2, encoding="utf-8"))["finalCard"]
    s = close_from - fc["from"]
    return [(f(fc["logoGrows"] + s) + 0.02, "logo_in", -20, 0), (f(fc["logoGrows"] + s) + 0.02, "impact", -22, 0),
            (f(fc["wordmark"] + s), "tic", -22, 0), (f(fc["cta"] + s), "tic", -25, 0), (f(fc["tagline"] + s), "glassA6", -29, 0)]


def morph_events(frames):
    out = []
    for k, m in enumerate(frames):
        out += [(f(m), "morph", -22, 0.4 if k % 2 else -0.4), (f(m) + 0.15, "tic", -26, 0)]
    return out


def install_events(home_from, install_at, n_slots):
    """Each widget slides in, then lands (part 2 validated values): the landing is a click, a pop and a soft glass."""
    pans = (-0.4, 0.4, -0.2, 0.2)
    ev = [(f(home_from), "light", -26, 0)]
    for j in range(n_slots):
        st = home_from + install_at + 22 * j
        ev += [(f(st), "swipe", -29, pans[j]), (f(st + 44), "dock", -17, pans[j]), (f(st + 44), "tap", -15, 0),
               (f(st + 44), "glassA6", -29 + 0.5 * j, 0)]
    return ev


def cut_events(frame):
    return [(f(frame) - 0.35, "transition", -26, 0), (f(frame), "dock", -22, 0)]


def swallow_events(frame):
    return [(f(frame) - 1.4, "transition", -27, 0), (f(frame) - 0.55, "pull", -26, 0)]


def main_sfx(T):
    M_, H = T["MAIN"], T["MAIN"]["hook"]["len"]
    ev = [e for e in A.v5s_sfx() if e[0] < f(H)]                      # the hook: exactly the validated events
    homes = M_["homes"]
    ev += morph_events([homes["from"] + m for m in homes["morphAt"]])
    ev += [(f(homes["from"] + homes["len"] - homes["exit"]), "swipe", -27, 0.3)]
    notes = ("glassD5", "glassF5", "glassA5")
    for k, app in enumerate(M_["apps"]["list"]):                      # version 2: several screens per mini-app
        s = app["from"]
        ev += cut_events(s)
        ev += [(f(s + M_["apps"]["titleAt"]), "tic", -21, 0), (f(s + M_["apps"]["titleAt"]), notes[k], -26, 0)]
        for j, st in enumerate(app["steps"]):
            if j > 0 and st["at"] != app["steps"][j - 1]["at"]:           # a new screen: the blade
                ev += [(f(s + st["at"]), "swipe", -29, 0.3 if j % 2 else -0.3)]
            ev += [(f(s + st["hi"][0]), "tic", -31, 0)]
    mk = M_["make"]
    ev += cut_events(mk["from"]) + [(f(mk["from"]) + 0.05, "swipe", -27, 0), (f(mk["from"]) + 0.05, "pull", -29, 0)]
    hf = mk["from"] + mk["homeFrom"]
    ev += install_events(hf, mk["installAt"], 3)
    ev += morph_events([hf + m for m in mk["morphAt"]])
    ev += swallow_events(hf + mk["swallow"][1])
    ev += finalcard_sfx(T, M_["close"]["from"])
    return ev


def widget_sfx(T):
    W = T["WIDGET"]
    ev = [(0.0, "light", -26, 0), (f(W["before"]["len"] - W["before"]["collapse"]), "pull", -29, 0)]
    ev += cut_events(W["after"]["from"])
    ev += morph_events([W["after"]["from"] + m for m in W["after"]["morphAt"]])
    p = W["process"]["from"]
    ev += cut_events(p)
    steps = T["PROCESS"]["steps"]
    for k, st in enumerate(steps):
        ev += [(f(p + st["at"]), "swipe", -28, 0.3 if k % 2 else -0.3), (f(p + st["at"]), "tic", -23 if k < 3 else -21, 0)]
    for sc in T["PROCESS"]["scenes"][1:]:
        ev += [(f(p + sc["start"]), "blade", -29, 0.5)]
    at = {st["id"]: st["at"] for st in steps}
    ev += [(f(p + at["styleAurora"] + 8), "glassA5", -27, 0), (f(p + at["styleNeon"] + 8), "glassD5", -27, 0)]       # Aurora / Neon (With Premium)
    ev += [(f(p + W["process"]["len"] - T["PROCESS"]["squeeze"]) - 0.2, "pull", -26, 0)]
    r = W["result"]
    ev += install_events(r["from"], r["installAt"], 4)
    ev += morph_events([r["from"] + m for m in r["morphAt"]])
    ev += swallow_events(r["from"] + r["swallow"][1])
    ev += finalcard_sfx(T, W["close"]["from"])
    return ev


# --------------------------------------------------------------------------------------------- the two films
def configure(T):
    M_, W = T["MAIN"], T["WIDGET"]
    ceiling = A.FILMS["v5short"]["ceiling"]
    # Main: the SAME first section and rise as v5short up to its first cut (c1), then the score goes on.
    c1, mk, close = f(646), f(M_["make"]["from"]), f(M_["close"]["from"])
    logo = f(M_["close"]["from"] + 4)                    # as v5part2: logo 4 frames after the close card
    pre = logo - A.PRE_LOGO_SILENCE
    A.FILMS["pub26main"] = dict(
        length=M_["total"] / FPS, ceiling=ceiling, logo=logo, custom="v3", impact=402 / FPS, silence_from=366 / FPS,
        sections=[("strata", 6.0, c1), ("daylight", c1, f(M_["apps"]["from"])), ("run", f(M_["apps"]["from"]), mk), ("pulse", mk, pre)],
        universes=[(6.0, "aurora"), (c1, "sunset"), (f(M_["apps"]["from"]), "neon"), (mk, "space")],
        rise_t=[402 / FPS, c1, f(M_["apps"]["from"]), mk, pre], rise_db=[-6, -4, -3, -1.5, 0], sfx=main_sfx(T))
    wl = f(W["close"]["from"] + 4)
    A.FILMS["pub26widget"] = dict(
        length=W["total"] / FPS, ceiling=-2.3, logo=wl,
        sections=[("void", 0, f(W["before"]["len"])), ("strata", f(W["before"]["len"]), f(W["process"]["from"])),
                  ("pulse", f(W["process"]["from"]), f(W["result"]["from"])), ("daylight", f(W["result"]["from"]), wl)],
        universes=[(0, "aurora"), (f(W["process"]["from"]), "sunset"), (f(W["result"]["from"]), "space")], sfx=widget_sfx(T))


def hook_env(n, trim_db, back=None):
    """Gain envelope (smoothstep): 0 dB up to the end of the hook, trim_db after it, back to 0 dB over (back, back + 1 s) (the end card)."""
    t = np.arange(n) / SR
    sm = lambda x: x * x * (3 - 2 * x)
    up = sm(np.clip((t - HOOK_TRIM_FROM) / HOOK_TRIM_RAMP, 0, 1))
    if back is not None:
        up = up * (1 - sm(np.clip((t - back) / 1.0, 0, 1)))
    return db(trim_db * up)


def save_stems(name, music, voice, sfx):
    os.makedirs(OUT, exist_ok=True)
    sf.write(os.path.join(OUT, f"{name}-voix.wav"), voice.astype(np.float32), SR, subtype="FLOAT")
    sf.write(os.path.join(OUT, f"{name}-musique.wav"), music.astype(np.float32), SR, subtype="FLOAT")
    sf.write(os.path.join(OUT, f"{name}-bruitages.wav"), sfx.astype(np.float32), SR, subtype="FLOAT")


def write_mix(name, mixdown, fname):
    os.makedirs(PUBLIC_EN, exist_ok=True)
    os.makedirs(OUT, exist_ok=True)
    for p in (os.path.join(PUBLIC_EN, fname), os.path.join(OUT, fname)):
        sf.write(p, mixdown.astype(np.float32), SR, subtype="FLOAT")
    mp3 = os.path.join(OUT, fname.replace(".wav", ".mp3"))
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", os.path.join(OUT, fname), "-b:a", "192k", mp3], check=True)


def build_main(T):
    cal = get_calib()
    cfg = A.FILMS["pub26main"]
    n = int(round(cfg["length"] * SR))
    meter = pyln.Meter(SR)
    music = A.music_stem("pub26main") * db(cal["bed_db"])               # the gain of v5short (hook identical)
    sfx = A.sfx_stem("pub26main", "en")
    main_lines, _ = vo_files(T)
    voice, _ = voice_stem(main_lines, n, cal["voice_gain"])
    t = np.arange(n) / SR
    x = np.clip((t - 6.5) / 0.8, 0, 1)                                   # 6.5 to 7.3 s: nobody speaks (H2 ends at 4.9 s, M0 « Meet Ardane. » starts at 7.6 s)
    voice = voice * db(VOICE_LIFT * x * x * (3 - 2 * x))[:, None]
    back = cfg["logo"] - A.PRE_LOGO_SILENCE - 1.0              # the gain is back to 0 dB when the silence before the logo begins
    trim, hist = 0.0, []
    for _ in range(10):                                                  # constant post-hook gain giving -14 LUFS (secant: the limiter bends it)
        mixdown, music_d, d, _ = master(music, sfx, voice, cfg["ceiling"], cal["scales"], hook_env(n, trim, back), AFTER_HOOK_CEILING)
        lufs = meter.integrated_loudness(mixdown)
        print(f"main: trim {trim:+.2f} dB -> {lufs:.2f} LUFS")
        hist.append((trim, lufs))
        if abs(lufs + 14) < 0.03:
            break
        if len(hist) == 1:
            trim += -14 - lufs
        else:
            (t0, l0), (t1, l1) = hist[-2], hist[-1]
            slope = (l1 - l0) / (t1 - t0) if abs(t1 - t0) > 1e-6 and (l1 - l0) / (t1 - t0) > 0.05 else 0.5
            trim = t1 + (-14 - l1) / slope
    g = gap(voice, music_d * hook_env(n, trim, back)[:, None], d)
    print(f"main: voice-music gap {g:.1f} dB, post-hook gain {trim:+.2f} dB on music and bruitages")
    mixdown = finish(mixdown, n, cfg["length"])
    save_stems("main", music, voice, sfx)
    write_mix("main", mixdown, "mix-pub26-main.wav")
    json.dump({"post_hook_trim_db": trim}, open(os.path.join(WORK, "main-trim.json"), "w"))
    return mixdown


def build_widget(T):
    cfg = A.FILMS["pub26widget"]
    n = int(round(cfg["length"] * SR))
    meter = pyln.Meter(SR)
    music = A.music_stem("pub26widget")
    music = music * db(A.MUSIC_BED_LUFS - meter.integrated_loudness(music))
    sfx = A.sfx_stem("pub26widget", "en")
    _, wid = vo_files(T)
    voice, _ = voice_stem(wid, n)
    mixdown, music_d, d, _ = master(music, sfx, voice, AFTER_HOOK_CEILING, steps=6)
    print(f"widget: voice-music gap {gap(voice, music_d, d):.1f} dB")
    mixdown = finish(mixdown, n, cfg["length"])
    save_stems("widget", music, voice, sfx)
    write_mix("widget", mixdown, "mix-pub26-widget.wav")
    return mixdown


# --------------------------------------------------------------------------------------------- voice synthesis
def synth_voice():
    py = sys.executable
    env = dict(os.environ, ARDANE_HF_CACHE=os.environ.get("ARDANE_HF_CACHE") or os.path.join(os.path.expanduser("~"), "ardane-tools", "hf_cache"))
    os.makedirs(VO, exist_ok=True)
    for film in ("pub26main", "pub26widget"):
        subprocess.run([py, "-I", "-X", "utf8", os.path.join(HERE, "vo.py"), os.path.join(HERE, "vo_spec_pub26.json"), film, VO], check=True, env=env)


# --------------------------------------------------------------------------------------------- measures
def ffmpeg_loudness(path):
    r = subprocess.run(["ffmpeg", "-hide_banner", "-nostats", "-i", path, "-af", "ebur128=peak=true", "-f", "null", "-"], capture_output=True, text=True).stderr
    summ = r[r.rfind("Summary:"):]
    lufs = float(re.search(r"I:\s+(-?[\d.]+) LUFS", summ).group(1))
    tp = float(re.search(r"Peak:\s+(-?[\d.]+) dBFS", summ).group(1))
    return lufs, tp


def plan_of(T, film, frame):
    if film == "main":
        M_ = T["MAIN"]
        names = [("accroche (hook)", 0, M_["hook"]["len"]), ("Meet Ardane + Homes", M_["homes"]["from"], M_["apps"]["from"])]
        names += [(a["id"].capitalize(), a["from"], a["from"] + a["eff"]) for a in M_["apps"]["list"]]
        names += [("Make everyday your own", M_["make"]["from"], M_["close"]["from"]), ("carte finale", M_["close"]["from"], M_["total"])]
    else:
        W = T["WIDGET"]
        p = W["process"]["from"]
        names = [("iOS avant Ardane", 0, W["before"]["len"]), ("Homes apres", W["after"]["from"], p)]
        sc = T["PROCESS"]["scenes"]
        names += [(f"Process: {c['label']}", p + c["start"], p + (sc[i + 1]["start"] if i + 1 < len(sc) else W["process"]["len"])) for i, c in enumerate(sc)]
        names += [("Resultat (Homes)", W["result"]["from"], W["close"]["from"]), ("carte finale", W["close"]["from"], W["total"])]
    for name, a, b in names:
        if a <= frame < b:
            return name
    return "?"


def transcribe(path):
    from faster_whisper import WhisperModel
    asr = WhisperModel("small.en", device="cpu", compute_type="int8",
                       download_root=os.environ.get("ARDANE_HF_CACHE") or os.path.join(os.path.expanduser("~"), "ardane-tools", "hf_cache"))
    a, sr = sf.read(path, dtype="float32")
    a = a.mean(axis=1)
    a16 = resample_poly(a, 1, 3).astype(np.float32)
    seg, _ = asr.transcribe(a16, word_timestamps=True, language="en", beam_size=5, vad_filter=False)
    return [(w.word.strip(), w.start, w.end) for s in seg for w in s.words]


def check(T):
    meter = pyln.Meter(SR)
    for film, fname, total in (("main", "mix-pub26-main.wav", T["MAIN"]["total"]), ("widget", "mix-pub26-widget.wav", T["WIDGET"]["total"])):
        p = os.path.join(PUBLIC_EN, fname)
        a, sr = sf.read(p, dtype="float64")
        lufs, tp = ffmpeg_loudness(p)
        pk = 20 * np.log10(np.abs(a).max())
        print(f"\n== {fname}: {len(a)} samples @ {sr} Hz = {len(a) / sr:.4f} s (film {total} frames = {total / FPS:.4f} s), {a.shape[1]} ch")
        print(f"   ffmpeg ebur128: {lufs:.1f} LUFS integrated, true peak {tp:.2f} dBTP ; sample peak {pk:.2f} dBFS ; pyloudnorm {meter.integrated_loudness(a):.2f} LUFS")
        main_lines, wid = vo_files(T)
        lines = main_lines if film == "main" else wid
        print("   phrase   start-end (s)   frames        plan")
        for i, st, path in lines:
            dur = sf.info(path).duration
            fr, e = st * FPS, (st + dur) * FPS
            ok = "" if e <= total - 6 else "  ** CUT BY THE END **"
            print(f"   {i:6s} {st:6.2f}-{st + dur:5.2f}   {fr:6.1f}-{e:6.1f}   {plan_of(T, film, int(fr))}{ok}")
        # voice gaps (version 2 target: none over 1.5 s between the end of the hook and the outro), measured on the voice stem itself
        stem, ssr = sf.read(os.path.join(OUT, f"{film}-voix.wav"), dtype="float64")
        env = np.abs(stem.mean(axis=1) if stem.ndim > 1 else stem)
        hop = ssr // 100
        lvl = np.array([env[i:i + hop].max() for i in range(0, len(env) - hop, hop)])
        on = lvl > lvl.max() * 10 ** (-40 / 20)
        t0 = (T["MAIN"]["homes"]["from"] if film == "main" else 0) / FPS
        gaps, run = [], None
        for i, v in enumerate(on):
            t = i / 100
            if not v and run is None:
                run = t
            if v and run is not None:
                if run >= t0 and t - run >= 0.25:
                    gaps.append((run, t))
                run = None
        if run is not None:
            gaps.append((run, len(on) / 100))
        big = [(a, b) for a, b in gaps if b - a > 1.5]
        print("   voice gaps >= 0.25 s after the hook:", ", ".join(f"{a:.2f}-{b:.2f} ({b - a:.2f})" for a, b in gaps))
        print(f"   longest gap before the outro: {max([b - a for a, b in gaps[:-1]] or [0]):.2f} s ; over 1.5 s: {big[:-1] if big and big[-1] == gaps[-1] else big}")
        words = transcribe(p)
        print("   Whisper on the mix:", " ".join(w for w, _, _ in words))
        print("   words:", "; ".join(f"{w}@{s:.2f}" for w, s, _ in words))
        if film == "main":
            ref, rsr = sf.read(os.path.join(PUBLIC_EN, "mix-v5short.wav"), dtype="float64")
            k = 446 * SR // FPS
            x, y = a[:k], ref[:k]
            rms = lambda z: np.sqrt(np.mean(z ** 2))
            corr = np.corrcoef(x.ravel(), y.ravel())[0, 1]
            print(f"   first 7.43 s vs mix-v5short.wav: max abs diff {np.abs(x - y).max():.2e}, RMS diff {20 * np.log10(rms(x - y) / rms(y) + 1e-12):.1f} dB re ref, correlation {corr:.6f}")
            print(f"   (after the hook, 7.43-9.5 s: ref level vs ours) {20 * np.log10(rms(a[k:int(9.5 * SR)]) / rms(ref[k:int(9.5 * SR)])):+.2f} dB")


if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "all"
    T = timing()
    configure(T)
    if cmd in ("voice", "all"):
        synth_voice()
    if cmd == "calib":
        calibrate()
    if cmd in ("main", "all"):
        build_main(T)
    if cmd in ("widget", "all"):
        build_widget(T)
    if cmd in ("check", "all"):
        check(T)
