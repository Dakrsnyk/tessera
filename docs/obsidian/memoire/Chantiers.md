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
- Reste, dans l'ordre : relancer `[adkit]` (les PNG de l'export du run 160 n'étaient que dans la session cloud) et copier le kit dans `pub/kit/`, voix des autres films, moteur d'animation 60 i/s (CSS 3D + Playwright, courbes GSAP), musique, film principal, déclinaisons, contrôle qualité image par image, livraison.
- Rendus dans `pub/` (ignoré par Git, visible dans Obsidian) : ils restent sur le disque, contrairement à une session cloud.

## À ne pas oublier

- Le dépôt est public pour la CI : le repasser en privé.
