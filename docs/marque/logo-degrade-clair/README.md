# Icône Ardane : dégradé plus clair (propositions du 2026-11-05, rien n'est appliqué)

Même « A », pixel pour pixel (forme, bords, blanc à gauche, #D6E9FA à droite) : seul le fond change. Le fond actuel est un dégradé linéaire presque vertical, de #4D9ADF (haut gauche) à #1B4A7A (bas droite) ; il est éclairci dans OKLab (même teinte). `ardane-0-actuel-1024.png` est identique à `App/Assets.xcassets/ArdaneIcon.appiconset/AppIcon-1024.png` (écart 0), ce qui vérifie la méthode.

Régénérer : `python scripts/logo_degrade_clair.py App/Assets.xcassets/ArdaneIcon.appiconset/AppIcon-1024.png docs/marque/logo-degrade-clair` (Pillow, NumPy).

| Variante | Fond | Contraste au haut du « A » (blanc · bleu pâle) |
|---|---|---|
| Actuel | #4D9ADF → #1B4A7A | 3,95:1 · 3,18:1 |
| A · un peu plus clair | #5AA7ED → #265586 | 3,36:1 · 2,70:1 |
| B · plus clair | #64B1F7 → #2F5D8F | 2,99:1 · 2,41:1 |
| C · nettement plus clair | #6DBAFF → #386698 | 2,67:1 · 2,15:1 |
| D · lumière en haut | #6AB7FE → #214F80 | 2,97:1 · 2,39:1 |
| E · plus clair et plus vif | #55AEFD → #245A92 | 3,11:1 · 2,50:1 |

Plus le fond est clair, moins le « A » ressort (surtout sa moitié bleu pâle) ; le seuil utile pour un pictogramme est 3:1. Les versions sombre et teintée de l'icône (`AppIcon-Dark-1024.png`, `AppIcon-Tinted-1024.png`) ne sont pas touchées.
