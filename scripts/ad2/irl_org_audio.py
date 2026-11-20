"""Son de la pub Fitness « organique » n°1 (2026-11-19, 12,5 s, film ~/ardane-tools/film/src/campaign/fitness-org/Film.tsx).

Variante courte d'irl_music.py + irl_audio.py (réglés pour le film de 28 s) : même morceau de la série Fitness (Pixabay
phonk-gym-phonk-620567, 124 BPM ramené à 120), drop du morceau (17,25 s) calé à 2,0 s, accroche en retrait (-5 dB), coupure
nette à 11,0 s puis la signature Ardane (ré5 à 11,1 s, la5 à 11,6 s). Sons d'interface : appui à 5,0 s, coche à 5,5 s.
-14 LUFS, crête sous -1 dBFS. Spec : pub/campagne-2026-11/fitness/organique/spec.json.

Usage : python scripts/ad2/irl_org_audio.py [morceau.mp3] [sortie.wav] [durée_s] [fin_musique_s] [appui_s] [fondu_s] [drop_s] [raccord_s] [drop_après_raccord_s] [départ_s] [tempo_bpm]
  v1 : 12,5 s, fin 11,0 s, appui 5,0 s (défaut) ; v2 : - - 27.5 26.0 ; v3 : - - 28.5 27.0 6.0 ; v4 : - - 29.5 28.0 8.0 1.5 (fondu de 1,5 s) ; v4.1 : - - 29.5 28.0 8.0 1.5 1.25 4.0 2.0 (drop à 1,25 s, raccord à 4,0 s vers le placement de la v4 : abandonné, il s'entendait) ; v4.2 : - - 29.5 28.0 8.0 1.5 2.0 0 2.0 0.2 (abandonné) ; v4.2 : - - 29.75 28.25 1.75,8.75 1.0 0.9875 0 0 0.2 123.6 ; v4.3 : appuis « 2.5,8.75 » (morceau d un seul tenant dès 0,2 s ; le vrai coup du drop arrive 0,18 s après DROP_SRC, mesuré sur les attaques des basses : tempo 123,6 BPM, premier coup de grosse caisse du drop à 17,505 s du morceau : drop_s 0,9875 le met à 1,25 s, grille des temps à 0,25 modulo 0,5 ; le montage suit la grille). La coche suit l'appui de 0,5 s.
"""
import os
import sys

import numpy as np
import pyloudnorm as pyln
import soundfile as sf

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import irl_audio as A
import irl_music as MU
import mix as M
import synth as S
from synth import SR, db, fm_glass, note, reverb

LENGTH = float(sys.argv[3]) if len(sys.argv) > 3 else 750 / 60
HOOK = float(sys.argv[7]) if len(sys.argv) > 7 else 2.0  # moment du drop dans le film (v4.1 : 1,25 s ; le départ du morceau est décalé, pas étiré)
END = float(sys.argv[4]) if len(sys.argv) > 4 else 11.0
# appuis (s) séparés par des virgules (v4.2 : « 1.75,8.75 », écran verrouillé puis widget) ; chaque coche 0,5 s après son appui
TAPS = [float(v) for v in sys.argv[5].split(",")] if len(sys.argv) > 5 else [5.0]
# v4 : fondu de la musique sur FADE s fini à END (sur un temps), la signature posée dessus (ré5 un temps avant END, la5 à END).
FADE = float(sys.argv[6]) if len(sys.argv) > 6 else 0.0
SIG = END - 0.5 if FADE > 0 else END + 0.1
# v4.1 : raccord du morceau (voir main) ; 0 = aucun
SPLICE = float(sys.argv[8]) if len(sys.argv) > 8 else 0.0
DROP_AFTER = float(sys.argv[9]) if len(sys.argv) > 9 else 2.0
START = float(sys.argv[10]) if len(sys.argv) > 10 else 0.0  # v4.2 : départ de la musique (s)
# v4.2 : tempo mesuré sur les attaques des basses du morceau (cohérence de phase sur 16..64 s) : 123,6 BPM, pas 124 ;
# le coup du drop est à 17,44 s du morceau (17,25 s était 0,19 s trop tôt).
TEMPO = float(sys.argv[11]) if len(sys.argv) > 11 else 124.0
DROP_SRC = 17.25


def main():
    home = os.path.expanduser("~/ardane-tools")
    src = sys.argv[1] if len(sys.argv) > 1 and sys.argv[1] != "-" else os.path.join(home, "irl-fitness", "music", "phonk-620567.mp3")
    out = sys.argv[2] if len(sys.argv) > 2 and sys.argv[2] != "-" else os.path.join(home, "film", "public", "campaign", "fitness-org", "mix.wav")
    x = MU.decode(src, TEMPO)
    drop = DROP_SRC * TEMPO / MU.GRID_BPM  # le drop après atempo
    n = int(round(LENGTH * SR))
    music = np.zeros((n, 2))
    t = np.arange(n) / SR

    def placed(drop_at):  # le morceau posé avec son drop à drop_at s du film (décalé, jamais étiré)
        start = int(round((drop - drop_at) * SR))
        y = np.zeros((n, 2))
        k = min(n, len(x) - start)
        y[:k] = x[start : start + k]
        return y

    if SPLICE > 0:
        # v4.1 : drop à HOOK jusqu'au raccord SPLICE (une coupe franche de l'image, sur une barre de mesure du placement
        # d'après), puis le morceau posé comme avant (drop à DROP_AFTER) : la suite garde ses temps sur les coupes.
        # Raccord en fondu enchaîné de 15 ms.
        a_, b_ = placed(HOOK), placed(DROP_AFTER)
        w = np.clip((t - SPLICE) / 0.015, 0, 1)[:, None]
        music[:] = a_ * (1 - w) + b_ * w
    else:
        music[:] = placed(HOOK)
    if START > 0:  # v4.2 : silence jusqu'à START, puis entrée en 40 ms (sans clic)
        music *= np.clip((t - START) / 0.04, 0, 1)[:, None]
    # accroche en retrait, plein volume au drop, coupure nette (10 ms) à 11,0 s
    music *= np.interp(t, [0, HOOK - 0.05, HOOK], [db(-5), db(-5), 1])[:, None]
    if FADE > 0:  # fondu en cosinus, fini sur le temps END
        tail = np.clip((t - (END - FADE)) / FADE, 0, 1)
        music *= (0.5 + 0.5 * np.cos(np.pi * tail))[:, None]
    else:  # coupure nette (10 ms)
        music *= np.interp(t, [END - 0.01, END], [1, 0])[:, None]
    meter = pyln.Meter(SR)
    music = pyln.normalize.loudness(music[: int(END * SR)], meter.integrated_loudness(music[: int(END * SR)]), -15.0)
    music = np.concatenate([music, np.zeros((n - len(music), 2))])

    fx = np.zeros((n, 2))
    for tap in TAPS:
        A.place(fx, M.tap_pulse(), tap, db(-8))
        A.place(fx, S.cue_check(), tap + 0.5, db(-10))
    sig = np.zeros((n, 2))
    A.place(sig, reverb(fm_glass(note("D5"), seconds=1.0, index=4.0, decay=0.32), 3.0, 0.3), SIG, db(-12))
    A.place(sig, reverb(fm_glass(note("A5"), index=4.0, decay=1.6), 3.0, 0.3), SIG + 0.5, db(-12))
    A.place(sig, S.pad([note("D3"), note("F#3"), note("A3"), note("C#4"), note("E4")], LENGTH - SIG - 0.6, attack=0.1, release=0.9, cutoff=2400), SIG + 0.5, db(-16))
    e = int((LENGTH - 0.15) * SR)  # la fin de la signature s'éteint avant la dernière image
    sig[e - int(0.35 * SR) : e] *= np.linspace(1, 0, int(0.35 * SR))[:, None]
    sig[e:] = 0

    mixdown = music + fx * db(-4) + sig * db(4)
    mixdown = pyln.normalize.loudness(mixdown, meter.integrated_loudness(mixdown), -14.0)
    mixdown = np.tanh(mixdown / db(-1.2)) * db(-1.2)  # limiteur doux sous -1 dBFS
    os.makedirs(os.path.dirname(out), exist_ok=True)
    sf.write(out, mixdown.astype(np.float32), SR, subtype="PCM_24")
    print(out, f"{n / SR:.2f} s", f"{meter.integrated_loudness(mixdown):.1f} LUFS", f"crête {20 * np.log10(np.max(np.abs(mixdown))):.2f} dBFS")


if __name__ == "__main__":
    main()
