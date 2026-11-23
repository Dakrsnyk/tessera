"""The « ding » of Ardane for the end of a rest between two sets: the two glass notes of the ads' close
(D5, then A5 half a second later: `cue_close` of scripts/ad2/synth.py), short and dry enough for a
notification. Writes Shared/Sounds/ardane-ding.wav (mono, 48 kHz, 16-bit PCM: a format iOS plays for a
notification and for a system sound; under 30 s).

    ~/ardane-tools/venv/Scripts/python.exe scripts/sound/rest_ding.py
"""
import os
import sys

import numpy as np
import soundfile as sf

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, os.path.join(ROOT, "scripts", "ad2"))
from synth import SR, fm_glass, note, reverb  # noqa: E402

SECONDS = 2.4
GAP = 0.5  # the eighth rest of the close: f60 -> f90 at 60 fps


def ding():
    track = np.zeros(int(SECONDS * SR))
    for start, name in ((0.0, "D5"), (GAP, "A5")):
        tone = fm_glass(note(name), seconds=SECONDS - start, decay=1.1)
        i = int(start * SR)
        track[i:i + len(tone)] += tone
    track = reverb(track, 1.6, 0.25).mean(axis=1)
    # Soft 3 ms attack, then a fade over the last 0.5 s so the file ends in silence.
    attack = int(0.003 * SR)
    track[:attack] *= np.linspace(0, 1, attack)
    fade = int(0.5 * SR)
    track[-fade:] *= np.linspace(1, 0, fade) ** 2
    return track * (0.89 / np.abs(track).max())  # peak at -1 dBFS


if __name__ == "__main__":
    out = os.path.join(ROOT, "Shared", "Sounds", "ardane-ding.wav")
    os.makedirs(os.path.dirname(out), exist_ok=True)
    sf.write(out, ding(), SR, subtype="PCM_16")
    print(out, f"{os.path.getsize(out) / 1024:.0f} KB")
