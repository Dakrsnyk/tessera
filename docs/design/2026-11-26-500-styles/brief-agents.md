# 500 styles : consigne commune des agents designers (nuit du 2026-11-26)

Demande du PDG (docs/memoire/Demandes.md, 2026-11-26 01:45 + ajout 22 h 10) : 500 styles visuels **réellement différents**, utilisables sur tous les widgets ; seul l'aspect change. Un changement de couleur n'est JAMAIS un nouveau style. Les planches précédentes (`planche-ardane*.png`, `planche-500-distincts.png`) ont été refusées : trop de variantes d'un même look (mêmes compositions recolorées). Familles internes, jamais affichées.

## Ce que tu écris
Un fichier JSON par famille dans `scripts/styles/library/NN-famille.json` : une liste de **25 styles**. Tu n'écris RIEN d'autre (pas de Swift).

Exemple d'un style :
```json
{
  "id": "aura-halo", "name": "Halo", "summary": "Aura rose, lueur douce, chiffres fins",
  "theme": "dark", "accent": "FF7AD9",
  "bg": {"kind": "gradient", "from": "2A0F3D", "to": "0B0614", "dir": "radial"},
  "font": "theme", "fontName": "AvenirNext-UltraLight",
  "textHex": "FFF1FA", "secondaryHex": "D9A8C9", "numberHex": "FF9AE1", "chartHex": "FF7AD9",
  "texture": "grain", "textureOpacity": 0.25,
  "border": "glow", "borderHex": "FF7AD9", "borderWidth": 1.5,
  "depth": "glow", "shadowHex": "FF7AD9",
  "shape": "capsule", "layout": "centered", "chart": "ring", "density": "compact",
  "iconStyle": "none", "titleCase": "lower", "tracking": 1, "numberWeight": "light", "titleWeight": "medium", "valueScale": 1.15
}
```
Clés possibles : `id` (kebab-case, unique), `name` (≤ 18 car., évocateur, **jamais une marque** : pas Rolex, Chanel, Nintendo, Barbie…), `summary` (français, ≤ 46 car., décrit ce qu'on voit), `theme` (base : `light`, `dark` ou `minimal`), `accent`, `bg` (`color` + `hex` | `gradient` + `from`, `to`, `dir` ∈ down, diagonal, across, up, radial, `intensity` 0–1 | `glass` | `theme`), `font` (theme | standard | rounded | serif | mono), `fontName` (nom PostScript pris dans `Shared/Model/FontCatalog.swift`), puis toute propriété de `StyleOptions` (`Shared/Model/WidgetStyle.swift`, struct StyleOptions) avec ses valeurs d'enum exactes : textHex, secondaryHex, numberHex, iconHex, chartHex, panelHex, seriesHexes (liste), texture, textureOpacity, border, borderHex, borderWidth, borderOpacity, depth, shadowHex, shadowRadius, shadowOpacity, shadowOffset, shape, valueScale (0.8–1.4), titleScale, textScale, numberWeight, titleWeight, tracking (0–4), titleCase, monospacedNumbers, iconStyle, iconFamily, iconScale, iconPosition, layout, chart, chartThickness, chartFill, chartValues, density.

Obligatoires : `textHex`, `secondaryHex`, `layout` (≠ auto), `shape` (≠ theme), `titleCase` (≠ theme).

Valeurs ajoutées au moteur cette nuit (utilisables) : textures `guilloche` (cadran de montre), `marble`, `terrazzo`, `linen` (toile), `topo` (courbes de niveau), `brushed` (métal brossé), `sunburst` (cadran rayonnant) ; bordures `ticket` (encoches), `stitched` (couture), `bevel` (biseau 3D façon Windows 95), `inset` (filet intérieur fin) ; relief `longShadow` ; casse `smallCaps`. Déjà là : textures grain, paper, dots, grid, lines, diagonal, noise, stars, snow, waves, web, leaves, scanlines, halftone, pixels ; bordures solid, dashed, dotted, double, glow, gradient, pixel ; reliefs soft, strong, glow, floating, embossed, hardShadow ; formes rounded, soft, square, capsule, panel ; dispositions vertical, horizontal, minimal, centered, split, data, list, progress, graph, cards ; graphiques line, area, bars, histogram, dots, sparkline, evolution, comparison, ring, pie, gauge, progress ; icônes plain, circle, square, outline, none.

## Règles (vérifiées par `python3 scripts/styles/library.py check`)
1. **Différence** : deux styles quelconques des 500 diffèrent sur au moins **3 des 7 axes** : (fond + texture), police, disposition, bordure, relief, forme, libellés (casse, interlettrage arrondi, graisses). La couleur ne compte pas. Vise 4 ou plus dans ta famille.
2. **Lisibilité** : contraste texte ≥ 4,5:1, secondaire et chiffre ≥ 3:1 sur chaque couleur du fond. Police décorative (script, fantaisie) seulement si elle reste lisible en petit : préfère-la avec `valueScale` modéré et `density` `compact`.
3. **Identité** : chaque style est une vraie direction artistique cohérente (fond, police, forme, effet, typographie vont ensemble), qu'on reconnaît d'un coup d'œil même en noir et blanc. Fais varier compositions, textures, formes, effets, typographies, finitions. Au sein d'une famille, l'esprit est commun mais chaque style a sa propre structure.
4. Pas de photos, pas d'images : tout est dessiné par le moteur.

## Méthode
- Lis d'abord : StyleOptions et ses enums (`Shared/Model/WidgetStyle.swift`), `Shared/Model/FontCatalog.swift` (polices dispo), ce fichier. Pour voir comment le rendu interprète les options : `Shared/Render/StyleRendering.swift` (lecture seulement).
- Écris tes 4 familles, lance `python3 scripts/styles/library.py check` et corrige jusqu'à 0 erreur pour TES styles. D'autres agents écrivent d'autres familles en même temps : si un de tes styles est « trop proche » d'un style d'une autre famille, change le tien (jamais le fichier d'un autre).
- `python3 scripts/styles/library.py stats` montre la répartition par axe : évite qu'une valeur domine.
- Ne touche à aucun autre fichier. Ne commite rien.
- Rapport final court : familles écrites, nombre de styles, résultat du check (0 erreur ?), 3 styles dont tu es le plus fier, doutes.
