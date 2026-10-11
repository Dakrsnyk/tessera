---
tags: [ardane, memoire]
---

# Chantiers

Retour : [[Memoire]] · Décisions : [[Decisions]]

## 2026-10-11 : passage à l'app Claude Desktop sur le PC Windows de l'utilisateur

Les sessions se font désormais en local, dans le dossier `tessera` qui est aussi le vault Obsidian : les notes écrites ici apparaissent tout de suite dans Obsidian, sans Pull. Faire un Pull avant de commencer si une session cloud a poussé entre-temps. Particularités Windows : voir [[Pieges-connus]].

Terminé juste avant : la carte Obsidian (vue graphique en grappes, canvas au format d'Obsidian) et cette mémoire.

## En pause : campagne publicitaire v2 (depuis le 2026-10-11)

Demande : une publicité de niveau Apple / Nike en motion design sur la vraie interface, voix off anglaise féminine, 1080 × 1920 à 60 i/s, 7 formats (principal 45–60 s, 30 s, 15 s, 6–10 s, Fitness, Nutrition, Personnalisation). « Une seule publicité exceptionnelle plutôt que plusieurs ordinaires. »

- Brief complet : [[Brief-campagne-v2]] · ce qui existe vraiment dans l'app : [[Faits-verifies-campagne-v2]] · direction retenue : [[Concept-THE-OPENING]].
- Fait :
  - Kit d'éléments réels : export DEBUG `AdExport` ([[AdExport (swift)]]), scènes [[AdShotsUITests (swift)]], listes `scripts/ad_export.txt` et `scripts/ad_screens.txt`. Le tag de commit `[adkit]` relance l'export en CI (PNG sans perte des widgets dans tous les styles, écrans, activité en direct, démos d'exercices image par image).
  - Voix off : script et minutage dans [`scripts/ad2/vo_spec.json`](../../../scripts/ad2/vo_spec.json), génération par [`scripts/ad2/vo.py`](../../../scripts/ad2/vo.py) (Kokoro-82M, voix af_heart, « Ardane » prononcé ar-DAHN, vérification par reconnaissance vocale). Pas encore généré.
- Reste, dans l'ordre : relancer `[adkit]` (les PNG de l'export du run 160 n'étaient que dans la session cloud), générer la voix, moteur d'animation 60 i/s (CSS 3D + Playwright, courbes GSAP), musique, film principal, déclinaisons, contrôle qualité image par image, livraison.
- Les outils (Kokoro, faster-whisper, ffmpeg, Playwright, musiques Mixkit) ne sont pas dans le dépôt : ce chantier se fait plutôt dans une session cloud (Linux, outils installés en quelques minutes) que sur le PC Windows.

## À ne pas oublier

- Le dépôt est public pour la CI : le repasser en privé.
