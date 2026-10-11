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

## Kit d'éléments réels

Commit avec le tag `[adkit]` (attendre la fin du run en cours : un push annule le précédent), puis copier aussitôt le dossier `adkit/` de la branche `ci-report` (réécrite à chaque run) :

```bash
git fetch -q origin ci-report && mkdir -p pub/kit && git archive origin/ci-report adkit | tar -x -C pub/kit
```

`shots/` (moments réels des scènes `AdShotsUITests`, copies sans perte dans `attachments/`), `screens/` (écrans et tranches de défilement), `export/` (widgets et pièces en PNG avec vraie transparence).
