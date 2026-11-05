# Icône Ardane : dégradés avec du cyan (propositions du 2026-11-05, rien n'est appliqué)

Même « A », pixel pour pixel ; seul le fond change : nouveau dégradé interpolé dans OKLab, sur le même axe (presque vertical) que l'icône actuelle. `ardane-0-actuel-1024.png` est identique à l'icône de l'app (écart 0).

Régénérer : `python scripts/logo_degrade_clair.py App/Assets.xcassets/ArdaneIcon.appiconset/AppIcon-1024.png docs/marque/logo-degrade-cyan --cyan`.

| Variante | Fond (haut → bas) | Contraste au haut du « A » (blanc · bleu pâle) |
|---|---|---|
| Actuel | #4D9ADF → #1B4A7A | 3,95:1 · 3,18:1 |
| F · cyan en haut | #2EB2E4 → #1B4A7A | 3,34:1 · 2,69:1 |
| G · cyan clair | #4CC4F0 → #2A5F96 | 2,66:1 · 2,14:1 |
| H · turquoise et bleu roi | #17B3D0 → #1D4E9E | 3,30:1 · 2,65:1 |
| I · bleu vers cyan (cyan en bas) | #3D7FD0 → #13A0C2 | 3,78:1 · 3,04:1 |
| J · cyan, saphir, nuit (3 teintes, saphir #2A6CB0 à 55 %) | #33BDEB → #183F70 | 3,27:1 · 2,63:1 |
| K · touche de cyan | #52AEE8 → #1F5288 | 3,25:1 · 2,62:1 |

Voir aussi `docs/marque/logo-degrade-clair/` (même fond éclairci, sans cyan).
