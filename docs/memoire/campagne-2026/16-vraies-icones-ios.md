---
tags: [ardane, memoire, campagne-2026, ios, icones]
---

# 16 · Écrans d'accueil iOS réalistes dans TOUTES les pubs (demande du PDG, 2026-11-11)

Demande : chaque pub (films du dépôt tessera ET pubs du QG ardane-hq) montre de VRAIES apps d'iPhone, plus aucune icône du kit (`icons-*`, dessinées par l'app avec des SF Symbols). On ne change pas les widgets d'une pub : on recompose l'écran comme la pub avant / après (note 15), plus propre et plus épuré.

## Ressources (hors dépôt : illustrations d'Apple, dépôt public)
- `~/ardane-tools/film/public/apple-icons/<Nom>.png` : 188 × 188 px, coins transparents. On les régénère avec `scripts/ad2/avant_apres/apple_icons.py` à partir de la capture CI `[ios-home]`.
- **Les seules apps autorisées** sont : Calendar, Photos, Reminders, News, Maps, Health, Wallet, Settings, Safari, Messages. Le simulateur n'a ni Phone, ni Camera, ni Music, ni Clock, ni App Store : ne jamais les montrer, ne jamais les redessiner.
- `apple-icons/ios-home-light-fixed.png` : le vrai écran d'accueil iOS (sans widget Ardane), pile pleine. Il sert à l'écran « avant » ; règle d'Apple : un écran d'accueil sans le widget de l'app est une zone grise, à garder court.
- Code de référence : `scripts/ad2/film/src/avantapres/` (`screens.ts` pour `GRID`, `rectOf` et `iconXY` ; `Home.tsx` pour `HomeScreen`, `AppIcon` et `StatusBar`).

## Grille iOS mesurée (iPhone 16 Pro, capture 1206 × 2622, @3x)
- Icône : 188 px. Colonnes à x = 92,5 + 277,7·c (c = 0..3). Rangées à y = 272 + 301·r (r = 0..5).
- Widgets : petit 489 × 489, moyen 1046 × 489, grand 1046 × 1098. Colonne gauche x = 81, droite x = 638. Une paire de rangées vaut 602 px.
- Libellés : Inter 500, 36 px, blancs, ombre `0 1px 6px rgba(0,0,0,.35)`, 10 px sous l'icône. Sous chaque widget, « Ardane » à 18 px sous son bas.
- Pilule « Search » : x 488, y 2113, 230 × 84. Dock : x 52, y 2263, 1100 × 304, rayon 120, verre teinté selon le fond. Icônes du Dock à y 2322 : 4 icônes sur les colonnes de la grille, moins de 4 centrées, 264 px d'écart.
- Barre d'état : « 9:41 » Inter 600 52 px centré vers x 217. Île : x 415, y 43, 375 × 108. Réseau, Wi-Fi et batterie PLEINS (règle d'Apple).
- Ancienne géométrie du kit (rects des configs : x 57/638, y 204 + 609·k, M 1092 × 510) vers la nouvelle : x' = 81 + (x − 57) × 0,9579 ; y' = 272 + (y − 204) × 0,98851 ; w' = w × 0,9579 ; h' = h × 0,9579.

## Règles de composition (« propre et épuré »)
- Chaque case libre de la grille peut recevoir une vraie app, jamais deux fois la même sur un écran (Dock compris). Mieux vaut quelques cases vides en bas qu'un écran surchargé.
- Pas de coque d'iPhone dessinée (règle d'Apple : aucune imitation d'appareil). On montre l'écran seul, coins arrondis (rayon 165 px de capture), avec une ombre.
- Les captures d'écran d'accueil ENTIÈRES de l'app (`home-*`, `setup-*`) ont les icônes du kit incrustées : on ne les montre plus telles quelles. On recompose : fond `wall-*` + widgets du kit (mêmes fichiers qu'avant) + vraies icônes.
