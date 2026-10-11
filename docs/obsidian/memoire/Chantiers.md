---
tags: [ardane, memoire]
---

# Chantiers

Retour : [[Memoire]] · Décisions : [[Decisions]]

## 2026-10-11 : passage à l'app Claude Desktop sur le PC Windows de l'utilisateur

Les sessions se font désormais en local, dans le dossier `tessera` qui est aussi le vault Obsidian : les notes écrites ici apparaissent tout de suite dans Obsidian, sans Pull. Faire un Pull avant de commencer si une session cloud a poussé entre-temps. Particularités Windows : voir [[Pieges-connus]].

Terminé juste avant : la carte Obsidian (vue graphique en grappes, canvas au format d'Obsidian) et cette mémoire.

## En cours : campagne publicitaire v2 (reprise le 2026-10-11, en local sur le PC Windows)

Demande : une publicité de niveau Apple / Nike en motion design sur la vraie interface, voix off anglaise féminine, 1080 × 1920 à 60 i/s, 7 formats (principal 45–60 s, 30 s, 15 s, 6–10 s, Fitness, Nutrition, Personnalisation). « Une seule publicité exceptionnelle plutôt que plusieurs ordinaires. »

- Brief complet : [[Brief-campagne-v2]] · ce qui existe vraiment dans l'app : [[Faits-verifies-campagne-v2]] · direction retenue : [[Concept-THE-OPENING]].
- Fait :
  - Kit d'éléments réels : export DEBUG `AdExport` ([[AdExport (swift)]]), scènes [[AdShotsUITests (swift)]], listes `scripts/ad_export.txt` et `scripts/ad_screens.txt`. Le tag de commit `[adkit]` relance l'export en CI (PNG sans perte des widgets dans tous les styles, écrans, activité en direct, démos d'exercices image par image).
  - Voix off : script et minutage dans [`scripts/ad2/vo_spec.json`](../../../scripts/ad2/vo_spec.json), génération par [`scripts/ad2/vo.py`](../../../scripts/ad2/vo.py) (Kokoro-82M, voix af_heart, « Ardane » prononcé ar-DAHN, vérification par reconnaissance vocale). 2026-10-11 : films `main` (17 lignes, 29 s, toutes dans leur créneau) et `s8` générés dans `pub/vo/` ; écoute à valider par l'utilisateur (« Your week », « Ardane » seul).
  - Outils installés sur le PC (2026-10-11) : `~/ardane-tools` (venv Python 3.12 : torch CPU, Kokoro, faster-whisper ; Playwright + Chromium ; ffmpeg par winget). Procédure : [`scripts/ad2/README.md`](../../../scripts/ad2/README.md). Rendu Chromium 1080 × 1920 : ~130 ms par image (≈ 8 min pour 60 s à 60 i/s sur une scène simple).
  - Moteur (2026-10-11) : Remotion 4.0.534 dans `~/ardane-tools/film`, sources dans `scripts/ad2/film/` (`film_sync.py`). Fait : la ligne, le logo, le texte qui s'ouvre depuis la ligne, le grain, la scène `Close` (plans 24–25, 53–58 s, signature sonore D5 · silence · A5 par `scripts/ad2/synth.py`) ; rendu `pub/film/close.mp4` (5 s en 1 min 34). Voix des 7 films générée.
  - 2026-10-11 (suite) : téléphone 3D (`Phone3D`), scènes `Opening` (plans 1-3), `LockScreen` (11-13), `Daylight` (14, pot « GREEK YOGURT 0% » à EAN fictif préfixe 200), `Close` (24-25) ; partition complète `scripts/ad2/score.py` (58 s) et mixage final `scripts/ad2/mix.py` (−14 LUFS, voix 8 à 19 dB au-dessus de la musique) → `pub/film/`. Run `[adkit]` 169 lancé (accueils héros sur 6 décors via `rows=`, écrans et scènes en sombre, démos sombres) : **récupérer `adkit/` de ci-report dans `pub/kit/` dès qu'il finit, avant tout push**.
  - Piège Remotion : un `ThreeCanvas` ne se redessine qu'au changement d'image ; ne le monter qu'une fois images et police prêtes. Verre du téléphone en matériau non éclairé (l'environnement de scène ignore `envMapIntensity`).
- Reste, dans l'ordre : relancer `[adkit]` (les PNG de l'export du run 160 n'étaient que dans la session cloud) et copier le kit dans `pub/kit/`, téléphone 3D (`@remotion/three`), plans 1 à 23, musique, film principal, déclinaisons, contrôle qualité image par image, livraison.
- Rendus dans `pub/` (ignoré par Git, visible dans Obsidian) : ils restent sur le disque, contrairement à une session cloud.

## À ne pas oublier

- Le dépôt est public pour la CI : le repasser en privé.
