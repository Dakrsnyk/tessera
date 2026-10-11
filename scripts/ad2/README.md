# Campagne v2 : outils locaux

Brief, faits vérifiés et concept : `docs/obsidian/memoire/campagne-v2/`.

## Installation sur le PC Windows (une fois)

Les outils vivent hors du dépôt, dans `%USERPROFILE%\ardane-tools` (le dépôt est aussi le vault Obsidian : pas de milliers de fichiers dedans). Les rendus vont dans `pub/` à la racine du dépôt (ignoré par Git, visible dans Obsidian).

```bash
winget install --id Gyan.FFmpeg -e
mkdir -p ~/ardane-tools && cd ~/ardane-tools
py -3.12 -m venv venv                      # Kokoro ne s'installe pas encore sur Python 3.14
venv/Scripts/python -m pip install torch --index-url https://download.pytorch.org/whl/cpu
venv/Scripts/python -m pip install kokoro soundfile faster-whisper
mkdir render && cd render && npm init -y && npm i playwright && npx playwright install chromium
```

## Voix off

```bash
ARDANE_HF_CACHE=~/ardane-tools/hf_cache ~/ardane-tools/venv/Scripts/python -I -X utf8 \
  scripts/ad2/vo.py scripts/ad2/vo_spec.json main pub/vo
```

Une WAV par ligne et `pub/vo/<film>.json` (durées, transcription, taux d'erreur par mot, minutage des mots pour la typographie). Films : `main`, `s30`, `s15`, `s8`, `fitness`, `nutrition`, `perso`.

Dans `vo_spec.json`, les lignes d'un même groupe (`chunks`) sont lues d'une traite puis recoupées aux pauses les plus proches des frontières attendues (d'après la longueur du texte). `"pause": 0.42` sur une ligne de phrases courtes la synthétise phrase par phrase, reliées par ce silence (Kokoro les enchaîne sinon sans respirer).

La vérification par Whisper se trompe sur les homophones (« Your week » → « You're weak », « Ardane » seul → « are done ») : écouter avant de régénérer.

## Film (Remotion)

Le projet tourne dans `~/ardane-tools/film` (hors du vault : `node_modules` contient des milliers de README qu'Obsidian indexerait) ; ses sources sont versionnées dans `scripts/ad2/film/`.

```bash
python -X utf8 scripts/ad2/film_sync.py import     # dépôt → ~/ardane-tools/film (nouvelle machine), puis npm ci là-bas
python -X utf8 scripts/ad2/film_sync.py export     # ~/ardane-tools/film → dépôt, avant chaque commit
```

Médias générés (non versionnés), à recopier dans `~/ardane-tools/film/public/` : `vo/` (WAV de `pub/vo`), `sfx/` (`synth.py <cue> public/sfx/<cue>.wav`), `kit/` (export `[adkit]`).

- Aperçu : `npx remotion studio` dans `~/ardane-tools/film` (navigateur, défilement image par image).
- Image fixe : `npx remotion still <Composition> out/x.png --frame=N`.
- Vidéo : `npx remotion render <Composition> <sortie.mp4>` (PNG sans perte, H.264 CRF 16, BT.709, 60 i/s).
- Briques : `lib/brand.ts` (palette, courbes, `at(mesure, temps)` : 120 BPM, un temps = 30 images), `Seam` (la ligne), `ArdaneLogo` (géométrie d'`ArdaneHalf`), `SplitText` (texte qui s'ouvre depuis la ligne), `Grain`. Scènes dans `src/scenes/`.
- Son : `synth.py` (verre FM, pad, sub, réverbération par FFT) ; une fonction `cue_<nom>` par plan.

## Kit d'éléments réels

Commit avec le tag `[adkit]` (attendre la fin du run en cours : un push annule le précédent), puis copier aussitôt le dossier `adkit/` de la branche `ci-report` (réécrite à chaque run) :

```bash
git fetch -q origin ci-report && mkdir -p pub/kit && git archive origin/ci-report adkit | tar -x -C pub/kit
```

`shots/` (moments réels des scènes `AdShotsUITests`, copies sans perte dans `attachments/`), `screens/` (écrans et tranches de défilement), `export/` (widgets et pièces en PNG avec vraie transparence).
