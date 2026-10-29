# Variantes du logo Ardane (étude, rien n'est appliqué)

Forme EXACTE du « A » conservée (viewBox 100, polygones `47.5,19.3 47.5,55.4 34,86 16,86` et `52.5,19.3 84,86 66,86 52.5,55.4`). Seules les couleurs changent. Source : logo du site/`docs/legal/privacy.html` ; jeux d'icônes de l'app dans `App/Assets.xcassets/ArdaneIcon-*`. Aucun fichier de production touché.

Fichiers : `ardane-<variante>.svg` (icône complète, fond dégradé diagonal haut-gauche vers bas-droite, symbole en dégradé vertical si deux teintes), `ardane-<variante>-symbole.svg` (symbole seul, aplat de la teinte la plus sombre du fond, fond transparent), `index.html` (comparatif autonome, tailles 29/60/120/256, symbole sur fond clair et sombre ; ouvrir le SVG pour 1024). Pas de PNG : ni cairosvg ni PIL disponibles ici. Rendu non vérifié visuellement (à voir sur la page HTML).

Contraste = ratio WCAG 2.x le plus faible entre une teinte du symbole et une teinte du fond. Le logo est un grand pictogramme : le seuil utile est 3:1 (éléments graphiques), 4.5:1 est confortable.

| Variante | Fond (haut-gauche → bas-droite) | Symbole | Symbole seul | Intention | Contraste min | 29 px | 60 px |
|---|---|---|---|---|---|---|---|
| A-saphir Saphir principal | #3D84C6 → #245B8F | #FFFFFF | #245B8F | Fidèle au thème : minimaliste, familier, cohérent avec l'accent de l'app | 3.95:1 | limite | net |
| B-saphir-profond Saphir profond | #245B8F → #133A63 | #FFFFFF | #133A63 | Premium, posé, plus dense | 7.08:1 | lisible (gros trait) | très net |
| C-bleu-nuit Bleu nuit | #1B2A55 → #0A1230 | #E8EEFF | #0A1230 | Sérieux, nocturne, très contrasté | 12.00:1 | lisible (gros trait) | très net |
| D-bleu-cyan Bleu et cyan | #1F4F9A → #14899E | #FFFFFF | #1F4F9A | Technologique, dynamique | 4.12:1 | limite | net |
| E-bleu-argent Bleu et argent | #0F2744 → #245B8F | #F7F9FB → #C3CCD6 | #0F2744 | Premium métallique, élégant | 4.36:1 | limite | net |
| F-monochrome Monochrome sobre | #111418 → #262B33 | #F2F4F7 | #111418 | Minimaliste haut de gamme, graphite et blanc cassé | 12.91:1 | lisible (gros trait) | très net |

Verdicts : à 29 px (icône de notification) A (3.95) et D (4.12) passent le seuil graphique 3:1 mais restent les moins marqués, E (4.36) correct, B/C/F très nets. À 60 px toutes les variantes sont nettes ; la barre horizontale absente du « A » ne gêne pas la lecture.

Rappel du thème Saphir : accent #245B8F (clair) / #68B5F5 (sombre) ; A et B reprennent #245B8F comme ancre.

## Recommandation
B (saphir profond) : ancrée sur l'accent #245B8F, contraste 7.08:1, nette à 29 px et premium sans changer d'univers. Alternative plus distinctive : E (bleu et argent) si l'on veut un côté métallique.
