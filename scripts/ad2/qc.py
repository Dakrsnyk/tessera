"""Quality control of a rendered film (Concept-THE-OPENING §7): frame count and rate, near-black frames,
long still runs (where nothing on screen moves), loudness and true peak, and a contact sheet (1 frame/s).

    python -X utf8 qc.py <film.mp4> [<sheet.png>]
    python -X utf8 qc.py <mix.wav> [<expected seconds>]     audio only (campaign mixes)
"""
import itertools
import os
import subprocess
import sys
import tempfile

import numpy as np
import pyloudnorm as pyln
import soundfile as sf
from PIL import Image, ImageChops, ImageStat

FFMPEG_DIR = os.path.join(os.environ.get("LOCALAPPDATA", ""), "Microsoft", "WinGet", "Packages",
                          "Gyan.FFmpeg_Microsoft.Winget.Source_8wekyb3d8bbwe", "ffmpeg-9.0.2-full_build", "bin")


def tool(name):
    path = os.path.join(FFMPEG_DIR, name + ".exe")
    return path if os.path.exists(path) else name


def audio_qc(path, expected=None, target=-14.0):
    """Audio-only control of a mix WAV: exact duration, integrated loudness, peak, trailing silence."""
    audio, sr = sf.read(path)
    meter = pyln.Meter(sr)
    lufs = meter.integrated_loudness(audio)
    up = np.abs(np.repeat(audio, 4, axis=0)).max()
    peak = 20 * np.log10(np.abs(audio).max() + 1e-12)
    loud = np.where(np.abs(audio).max(axis=1) > 1e-3)[0]
    tail = (len(audio) - 1 - loud[-1]) / sr if len(loud) else float("nan")
    seconds = len(audio) / sr
    ok = (expected is None or abs(seconds - expected) < 0.5 / sr + 1e-9) and abs(lufs - target) <= 0.5 and peak <= -1.0
    print(f"{os.path.basename(path)}: {seconds:.4f} s" + (f" (expected {expected})" if expected else "") +
          f" · {lufs:.1f} LUFS · peak {peak:.1f} dBFS (~TP {20 * np.log10(up + 1e-12):.1f}) · silent tail {tail:.2f} s · {'OK' if ok else 'CHECK'}")
    return ok


def main():
    if sys.argv[1].lower().endswith(".wav"):
        # qc.py <mix.wav> [expected seconds]
        sys.exit(0 if audio_qc(sys.argv[1], float(sys.argv[2]) if len(sys.argv) > 2 else None) else 1)
    film = sys.argv[1]
    sheet = sys.argv[2] if len(sys.argv) > 2 else os.path.splitext(film)[0] + "-qc.png"
    probe = subprocess.run([tool("ffprobe"), "-v", "error", "-select_streams", "v", "-show_entries", "stream=nb_frames,r_frame_rate,width,height",
                            "-of", "csv=p=0", film], capture_output=True, text=True).stdout.strip()
    print("video:", probe)
    with tempfile.TemporaryDirectory() as tmp:
        subprocess.run([tool("ffmpeg"), "-hide_banner", "-loglevel", "error", "-i", film, "-vf", "scale=120:213", os.path.join(tmp, "%05d.png")], check=True)
        subprocess.run([tool("ffmpeg"), "-hide_banner", "-loglevel", "error", "-i", film, "-vn", "-ac", "2", "-ar", "48000", os.path.join(tmp, "a.wav")], check=True)
        files = sorted(f for f in os.listdir(tmp) if f.endswith(".png"))
        frames = [Image.open(os.path.join(tmp, f)).convert("L") for f in files]
        diffs = [ImageStat.Stat(ImageChops.difference(frames[i], frames[i + 1])).mean[0] for i in range(len(frames) - 1)]
        still = [i for i, d in enumerate(diffs) if d < 0.12]
        runs = []
        for _, g in itertools.groupby(enumerate(still), lambda p: p[1] - p[0]):
            g = list(g)
            if g[-1][1] - g[0][1] >= 24:
                runs.append((g[0][1], g[-1][1] + 1))
        dark = [i for i, f in enumerate(frames) if ImageStat.Stat(f).mean[0] < 2.0]
        print("frames:", len(frames), "· near-black:", len(dark), (dark[:12] if dark else ""))
        print("still runs ≥ 0.4 s:", [(a, b, f"{(b - a) / 60:.1f}s") for a, b in runs])
        audio, sr = sf.read(os.path.join(tmp, "a.wav"))
        meter = pyln.Meter(sr)
        up = np.abs(np.repeat(audio, 4, axis=0)).max()
        print(f"audio: {len(audio) / sr:.2f} s · {meter.integrated_loudness(audio):.1f} LUFS · peak {20 * np.log10(np.abs(audio).max() + 1e-12):.1f} dBFS (~TP {20 * np.log10(up + 1e-12):.1f})")
        w, h = 120, 213
        picks = list(range(0, len(frames), 60))
        cols = 15
        rows = (len(picks) + cols - 1) // cols
        out = Image.new("RGB", (cols * (w + 2), rows * (h + 2)), (40, 40, 40))
        for k, n in enumerate(picks):
            out.paste(Image.open(os.path.join(tmp, files[n])).convert("RGB"), ((k % cols) * (w + 2), (k // cols) * (h + 2)))
        out.save(sheet)
        print("sheet:", sheet)


if __name__ == "__main__":
    main()
