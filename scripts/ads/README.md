# Vidéos pub d'Ardane

Cinq films 9:16 (principal 40 s, 15 s, 8 s, Fitness 20 s, Nutrition 20 s) montés à partir des vrais
écrans de l'app : enregistrements du simulateur par la CI et rendus que l'app dessine elle-même.

1. CI : un commit `[video]` joue `UITests/PromoVideoUITests.swift` en filmant le simulateur
   (`videos/*.mp4` dans le rapport) et rend les pièces de `scripts/ad_assets.txt` (`videos/assets`).
2. `python3 prep.py /tmp/rNNN <assets>` : clips en images 30 i/s, pièces détourées (rendu sur blanc
   puis sur noir), écrans entiers, `clips.json`.
3. `python3 contact_sheet.py <assets> <sortie> fitness 16 34 0.5` : choisir les instants, puis les
   reporter dans `CUTS` (`engine/films.js`), qui dit quelles parties de chaque enregistrement un film joue.
4. `node engine/engine.js main <assets> <sortie> --preview 12.5` : une image pour vérifier.
5. `python3 make.py main <assets> <sortie>` : musique et bruitages (`audio/synth.py`, 100 BPM, une
   mesure = 2,4 s), images, MP4 avec et sans musique, aperçu GIF. `--audio-only` refait seulement le son.
6. `python3 kit/kit.py <dossier des films> <sortie>` : le kit de production en PDF (découpage,
   tournage, prompts IA, inserts, éléments manquants, légendes, calendrier).

Besoins : Node + Playwright (Chromium), ffmpeg, Python avec numpy, scipy et Pillow, polices Inter.
