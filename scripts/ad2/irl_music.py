"""Pose un morceau existant (Pixabay Music, licence gratuite commerciale) sur la pub IRL Fitness (v2, 2026-11-19).

Le montage est sur une grille de 120 BPM (un temps = 30 images à 60 i/s). Le morceau est ramené à 120 BPM (atempo, hauteur
conservée), puis décalé pour que son « drop » (la plus forte montée d'énergie, calée sur un temps) tombe à la fin de
l'accroche (2,0 s). Les sons de l'interface d'irl_audio.py (tap, coche, souffles) passent par-dessus, plus bas ; la musique
s'éteint sur les 1,5 dernières secondes de la carte finale. -14 LUFS, crête -1 dBFS.

Usage : python scripts/ad2/irl_music.py <morceau.mp3> <bpm> <sortie.wav> [drop_s]
  bpm : tempo mesuré du morceau ; drop_s : moment du drop dans le morceau (sinon détecté).
"""
import os
import subprocess
import sys

import numpy as np
import pyloudnorm as pyln
import soundfile as sf

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import irl_audio as A
from synth import SR, db

GRID_BPM = 120.0
HOOK = 2.0


def decode(path, tempo):
    """Le morceau en stéréo 48 kHz, ramené de `tempo` à 120 BPM (atempo garde la hauteur)."""
    r = GRID_BPM / tempo
    raw = subprocess.run(["ffmpeg", "-v", "error", "-i", path, "-af", f"atempo={r:.5f}", "-ac", "2", "-ar", str(SR), "-f", "f32le", "-"], capture_output=True, check=True).stdout
    return np.frombuffer(raw, np.float32).reshape(-1, 2).astype(np.float64)


def find_drop(x, limit=45.0):
    """Le temps (déjà à 120 BPM) où l'énergie monte le plus d'une demi-seconde à la suivante, après 3 s, calé sur la grille de 0,5 s
    la plus proche de la phase des attaques."""
    m = x.mean(axis=1)
    w = SR // 4
    n = min(len(m) // w, int(limit * 4))
    e = np.array([10 * np.log10(np.mean(m[i * w : (i + 1) * w] ** 2) + 1e-12) for i in range(n)])
    rise = np.array([e[i : i + 4].mean() - e[max(0, i - 4) : i].mean() if i >= 12 else -99 for i in range(n)])
    t = int(np.argmax(rise)) * 0.25
    # phase des temps : attaques (flux) repliées sur la période de 0,5 s
    hop = 256
    fr = np.lib.stride_tricks.sliding_window_view(m[: int(limit * SR)], 1024)[::hop] * np.hanning(1024)
    S = np.log1p(10 * np.abs(np.fft.rfft(fr, axis=1)))
    o = np.maximum(0, np.diff(S, axis=0)).sum(1)
    ts = np.arange(len(o)) * hop / SR
    ph = np.angle(np.sum(o * np.exp(2j * np.pi * ts / 0.5))) / (2 * np.pi) * 0.5 % 0.5
    return round((t - ph) / 0.5) * 0.5 + ph


def main():
    path, tempo, out = sys.argv[1], float(sys.argv[2]), sys.argv[3]
    x = decode(path, tempo)
    drop = float(sys.argv[4]) * tempo / GRID_BPM if len(sys.argv) > 4 else find_drop(x)
    n = int(round(A.LENGTH * SR))
    start = int(round((drop - HOOK) * SR))
    music = np.zeros((n, 2))
    src = x[max(0, start) :]
    off = max(0, -start)
    k = min(n - off, len(src))
    music[off : off + k] = src[:k]
    # accroche un peu en retrait, puis plein volume au drop ; extinction sur la fin de la carte finale
    t = np.arange(n) / SR
    gain = np.interp(t, [0, HOOK - 0.05, HOOK, A.LENGTH - 1.8, A.LENGTH - 0.3], [db(-5), db(-5), 1, 1, 0])
    music *= gain[:, None]
    meter = pyln.Meter(SR)
    music = pyln.normalize.loudness(music, meter.integrated_loudness(music), -15.0)
    mixdown = music + A.sfx() * db(-4)
    mixdown = pyln.normalize.loudness(mixdown, meter.integrated_loudness(mixdown), -14.0)
    mixdown = np.tanh(mixdown / db(-1)) * db(-1)  # limiteur doux à -1 dBFS
    sf.write(out, mixdown.astype(np.float32), SR, subtype="PCM_24")
    print(out, f"drop du morceau à {drop * GRID_BPM / tempo:.2f} s", f"{meter.integrated_loudness(mixdown):.1f} LUFS")


if __name__ == "__main__":
    main()
