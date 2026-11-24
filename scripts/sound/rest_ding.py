"""The « ding » of Ardane for the end of a rest between two sets (2026-11-23, chosen by the CEO from the ads): the
landing of a widget on the Home Screen in the 2026 ads (`install_events` of scripts/ad2/audio_pub26.py), heard twice
as two widgets land, 22 frames apart. One landing is a click (`dock`), a pulse (`tap`) and the glass A6 note
(`glassA6`), with the ads' own instruments (scripts/ad2/mix.py) and their relative levels; the glass keeps the
level validated for the landing (−29 dB), without the −8 dB the ads took off to sit it under the music.

Writes Shared/Sounds/ardane-ding.wav: mono, 44.1 kHz, 16-bit PCM (the safest format for a notification sound),
under 30 s, peak at −1 dBFS.

    ~/ardane-tools/venv/Scripts/python.exe -X utf8 scripts/sound/rest_ding.py
"""
import os
import sys

import numpy as np
import soundfile as sf
from scipy.signal import resample_poly

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, os.path.join(ROOT, "scripts", "ad2"))
import mix as M  # noqa: E402
from synth import SR, db  # noqa: E402  (48 kHz: the instruments' own rate)

FPS = 60
GAP = 22 / FPS          # two landings, 22 frames apart (0.37 s), as in the ad
SECONDS = 1.9
OUT_RATE = 44_100


def mono(x):
    return x.mean(axis=1) if x.ndim == 2 else x


def place(track, sound, at):
    i = int(round(at * SR))
    end = min(len(track), i + len(sound))
    track[i:end] += sound[: end - i]


def ding():
    track = np.zeros(int(SECONDS * SR))
    for j in range(2):
        at = 0.01 + j * GAP
        place(track, mono(M.dock_click()) * db(-17), at)
        place(track, mono(M.tap_pulse()) * db(-15), at)
        place(track, mono(M.glass("A6", index=2.0, decay=1.0, wet=0.35)) * db(-29 + 0.5 * j), at)
    fade = int(0.4 * SR)
    track[-fade:] *= np.linspace(1, 0, fade) ** 2
    out = resample_poly(track, 147, 160)  # 48 kHz -> 44.1 kHz
    return out * (0.89 / np.abs(out).max())


if __name__ == "__main__":
    assert SR == 48_000
    path = os.path.join(ROOT, "Shared", "Sounds", "ardane-ding.wav")
    os.makedirs(os.path.dirname(path), exist_ok=True)
    sf.write(path, ding(), OUT_RATE, subtype="PCM_16")
    print(path, f"{os.path.getsize(path) / 1024:.0f} KB")
