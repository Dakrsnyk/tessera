"""Builds one film: music and sound effects on its beat grid, frames from the engine, MP4 for the
networks (1080 × 1920, 30 fps, H.264 High, AAC 48 kHz), with music and with sound effects only.

    python3 make.py <film> <assets dir> <out dir> [--audio-only]
"""
import json, os, subprocess, sys, shutil
import numpy as np
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "audio"))
import synth

film, assets, out = sys.argv[1:4]
os.makedirs(out, exist_ok=True)
spec = json.loads(subprocess.check_output(["node", "-e",
    f"const f=require('{HERE}/engine/films.js')['{film}'];console.log(JSON.stringify({{duration:f.duration,music:f.music,sfx:f.sfx}}))"]))
total = spec["duration"]
music = synth.render_track([tuple(s) for s in spec["music"]["sections"]], total, spec["music"].get("impact"))
n = len(music)
fx = np.zeros((n, 2))
gains = {"tap": 0.5, "snap": 0.55, "whoosh": 0.45, "chime": 0.4, "lock": 0.6, "rise": 0.35, "impact": 0.6}
cache = {}
for name, at in spec["sfx"]:
    if name not in cache:
        cache[name] = {"tap": synth.sfx_tap, "snap": synth.sfx_snap, "whoosh": synth.sfx_whoosh, "chime": synth.sfx_chime,
                       "lock": synth.sfx_lock, "rise": synth.sfx_rise, "impact": synth.impact}[name]()
    s = cache[name]
    if s.ndim == 1: s = np.stack([s, s], axis=1)
    i = int(at * synth.SR)
    if i < n:
        seg = s[: n - i] * gains[name]
        fx[i:i + len(seg)] += seg
mix = music * 0.85 + fx
mix = mix / max(1.0, np.max(np.abs(mix)) / 0.95)
fxonly = fx / max(1e-6, np.max(np.abs(fx))) * 0.7
synth.write_wav(os.path.join(out, "mix.wav"), mix)
synth.write_wav(os.path.join(out, "sfx.wav"), fxonly)

name = {"main": "Ardane-pub-principale-40s", "short": "Ardane-pub-15s", "tiny": "Ardane-pub-8s",
        "fitness": "Ardane-pub-fitness-20s", "nutrition": "Ardane-pub-nutrition-20s"}[film]
enc_audio = ["-c:a", "aac", "-b:a", "192k", "-ar", "48000", "-movflags", "+faststart", "-shortest"]
if "--audio-only" in sys.argv:
    # New sound on the film already rendered: the picture is copied as is.
    for suffix, audio in (("", "mix.wav"), ("-sans-musique", "sfx.wav")):
        src = os.path.join(out, f"{name}{suffix}.mp4"); tmp = src + ".tmp.mp4"
        subprocess.check_call(["ffmpeg", "-hide_banner", "-loglevel", "error", "-y", "-i", src, "-i", os.path.join(out, audio),
                               "-map", "0:v", "-map", "1:a", "-c:v", "copy", *enc_audio, tmp])
        os.replace(tmp, src)
    print(name, "sound redone"); sys.exit(0)
frames = os.path.join(out, "frames")
if os.path.isdir(frames): shutil.rmtree(frames)
env = dict(os.environ, PLAYWRIGHT="/opt/node-tools/node_modules/playwright")
subprocess.check_call(["node", os.path.join(HERE, "engine", "engine.js"), film, assets, frames], env=env)
video = ["-framerate", "30", "-i", os.path.join(frames, "f%05d.jpg")]
enc = ["-c:v", "libx264", "-profile:v", "high", "-preset", "slow", "-crf", "16", "-pix_fmt", "yuv420p", *enc_audio]
for suffix, audio in (("", "mix.wav"), ("-sans-musique", "sfx.wav")):
    subprocess.check_call(["ffmpeg", "-hide_banner", "-loglevel", "error", "-y", *video, "-i", os.path.join(out, audio), *enc,
                           os.path.join(out, f"{name}{suffix}.mp4")])
# A poster frame and a light preview GIF.
subprocess.call(["ffmpeg", "-hide_banner", "-loglevel", "error", "-y", "-i", os.path.join(out, f"{name}.mp4"),
                 "-vf", "fps=10,scale=360:-1:flags=lanczos,split[a][b];[a]palettegen=max_colors=128[p];[b][p]paletteuse",
                 os.path.join(out, f"{name}-apercu.gif")])
shutil.rmtree(frames)
print(name, "done")
