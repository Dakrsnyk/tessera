---
tags: [ardane, memoire, campagne-2026, storyboards, pub26]
---

# 20 · Storyboards des deux pubs à la version actuelle — 2026-11-18

Suite de `18-brief-pdg-2026-11-18.md` (brief) et `19-inventaire-2026-11-18.md` (inventaire). Squelette Remotion monté le 2026-11-18, **non rendu en vidéo** : images fixes de contrôle seulement (`pub/pub26/apercus/`, ignoré par Git).

- Code : `scripts/ad2/film/src/pub26/` (copie de travail : `~/ardane-tools/film/src/pub26/`). Compositions `MainPub26` et `WidgetPub26` (dossier « Pub26 » du Root de travail ; le Root du dépôt n'est pas modifié). Tous les minutages : `timing26.ts` ; tout ce qui dépend de la mise en page d'un écran de l'app : `shots.ts` ; les écrans d'accueil : `configs26.ts` ; voix : `vo26.json`.
- 1080 x 1920, 60 i/s, anglais, prop `silent` (aucun son synthétisé ni mixé). Mix attendu, s'il existe : `public/audio/en/mix-pub26-main.wav` et `mix-pub26-widget.wav`.
- Les captures de l'app viennent du kit par nom. **Le kit actuel montre l'ANCIENNE interface** : les images fixes montrent donc l'ancien Create (catégories), l'ancien Studio, l'ancienne Nutrition, etc. C'est attendu ; le nouveau kit les remplace sans changer le code, puis on règle `shots.ts`.

## Film 1 · MainPub26 — 1756 images = 29,27 s

| # | Début – fin | On voit | Voix | Composant / capture | Statut | À régler avec le nouveau kit |
|---|---|---|---|---|---|---|
| 1 | 0,00 – 7,43 s (0–446) | Accroche « Your life isn't one thing… ten apps? », impact | voix de l'accroche validée (non touchée) | `v5/short/HookS` | repris tel quel | rien |
| 2a | 7,43 – 10,2 s (446–606) | Écran « Planning & focus » (clair, ivoire) qui s'ouvre de la ligne Saphir, puis morphing | « All your essentials on your home screen. » (début 470, ~2,7 s) + légende à l'écran | `v5/part2/Home` `HomeBuilder` (`lineOpen`) ; config `prod` ; widgets `weekView-m-light`, `tasks-s-light`, `priorities-s-light`, `habits-m-light` ; fond `mainpub/wall-mp-ivory` | nouveau (mécanique reprise du plan 2 validé) | vérifier que les widgets exportés n'ont pas changé (Cristal) : `[adkit-img]` |
| 2b | 10,2 – 11,8 s (606–~700) | « Sport & wellness » (sombre, indigo) | idem | config `sport` : `todaysWorkout-m-dark`, `restTimer-s-dark`, `calories-s-dark`, `weeklyVolume-m-dark`, fond `wall-mp-indigo` | nouveau | idem |
| 2c | ~11,8 – 13,3 s | « Nutrition » (papier, argile) | idem | config `food` : `macros-m-paper`, `quickFood-m-paper`, `calories-s-paper`, fond `wall-mp-clay` | nouveau | idem ; chiffres des widgets du kit pas cohérents d'un export à l'autre (1 078 / 1 122 kcal) |
| 2d | ~13,3 – 14,4 s | « Everything in one place » (bronze, Luxury) : nutrition, argent, séance | idem | config `all` : `macros-m-luxury`, `budgetLeft-s-luxury`, `calories-s-luxury`, `nextSet-s-luxury`, fond `wall-mp-bronze` | nouveau | idem |
| 3a | 14,43 – 16,6 s (866–996) | Nutrition : mot-titre, caméra, une étiquette « Calories left » | « Nutrition. » (878) | `v5/MiniApp5` ; capture `app-nutrition-s00-dark` ; étiquette/cadrage dans `shots.ts` (`APP_SHOTS.nutrition`) | nouveau (gabarit repris) | `rect` mesuré sur la Build 467 (carte anneau + macros) : donne un cadre faux sur l'ancienne image ; contrôler sur le nouveau kit |
| 3b | 16,6 – 18,8 s (996–1126) | Fitness, étiquette « Program, history, progress » | « Fitness. » (1008) | idem ; `app-fitness-s00` | nouveau | `rect` = 4 raccourcis ronds (Build 467) ; à contrôler |
| 3c | 18,8 – 21,0 s (1126–1256) | Planning, étiquette « Your whole week » | « Planning. » (1138) | idem ; `app-planning-s00` | nouveau | `rect` deviné sur l'ANCIENNE image (grille de la semaine) : aucune capture 467 de Planning ; à refaire |
| 4a | 20,93 – 22,8 s (1256–1368) | Un widget Nutrition (Macros, clair) isolé, sur fond chaud, flottant | « Make everyday your own. » (1312) + légende | `Isolated` de `MainPub26.tsx` ; `kit/macros-m-light` | nouveau | vérifier le widget `macros-m-light` |
| 4b | 22,4 – 25,5 s (1346–~1500) | Le widget arrive sur un vrai écran d'accueil (cream), avec calories et budget, puis morphing | idem | `HomeBuilder` (`installAt`, `morphAt`) ; config `plain` : `macros-m-light`, `calories-s-light`, `budgetLeft-s-light`, fond `kit/wall-cream` | nouveau | idem |
| 4c | 25,5 – 26,4 s (1384–1586) | Résultat : thème Aurora + fond bleu-sarcelle assortis, « With Premium » | idem | config `aurora` : `macros-m-aurora`, `calories-s-aurora`, `habitStreak-s-aurora`, `todaysWorkout-m-aurora`, fond `wall-mp-aurora` ; mention « Some widgets and styles With Premium » de `HomeBuilder` | nouveau | idem |
| 5 | 26,43 – 29,27 s (1586–1756) | Carte finale : logo, « AVAILABLE ON THE APP STORE », « Your whole life. One place. » | « Ardane. Your whole life. One place. » (début 1612) | `scenes/Close` via `EndCard` (même remap que `FilmMainV5Part2`) | repris tel quel | rien |

Repères exacts : voir `timing26.ts` (`MAIN`). Séquence 2 = 420 images, séquence 3 = 3 x 130 (+ 30 de recouvrement entrée/sortie), séquence 4 = 330.

## Film 2 · WidgetPub26 — 1730 images = 28,83 s

| # | Début – fin | On voit | Voix | Composant / capture | Statut | À régler avec le nouveau kit |
|---|---|---|---|---|---|---|
| 1a | 0,0 – 1,5 s (0–90) | AVANT Ardane : le vrai écran d'accueil iOS (sans widget Ardane), écran seul, coins arrondis, ombre | « You want your phone to look like this? » (début 30, ~3,1 s) + légende | `Before` de `WidgetPub26.tsx` ; `avantapres/ios-home-light-fixed.png` | repris (image) / nouveau (plan) | rien |
| 1b | 1,5 – 7,0 s (90–420) | APRÈS : cinq écrans très différents, un par un, qui s'ouvrent de la ligne Saphir : Minimal (glacier, clair), Premium (bronze), Colorful (rose), Sober (indigo), Creative (synthwave) | idem | `HomeBuilder`, config `AFTER_HOMES` ; fonds `avantapres/wall-aa-glacier`, `mainpub/wall-mp-bronze`, `avantapres/wall-aa-rose`, `mainpub/wall-mp-indigo`, `kit/wall-synthwave` | nouveau (matériel de `avantapres/` et `configsMain`) | widgets à confirmer (kit) |
| 2a | 7,0 – 9,2 s (420–550) | Create : « What size for your widget? » ; mot « Create. » ; pastille « Pick a size » | « With Ardane, you can customize your own widgets. » (début 440, ~3,1 s) | `Process26.tsx` (copie de `v4/Process.tsx`) ; capture `spaces` | nouveau | **l'ancienne capture montre « Create » par catégories** ; la Build 467 montre Small / Medium / Large : attendre le kit |
| 2b | 9,2 – 11,3 s (550–720) | Choix d'un widget (`creator-nutrition`), puis passage en Medium (`creator-nutrition-medium`) | idem | idem | nouveau | idem |
| 2c | 11,3 – 12,5 s (720–792) | Ouverture du Studio (`creator-nutrition-studio`) | | idem | nouveau | idem |
| 2d | 12,5 – 15,2 s (792–952) | Styles : Aurora puis Neon ; « With Premium » | « And styles. » (début 792) | `studio-style-aurora`, `studio-style-neon` | nouveau | idem ; la mention Premium couvre aussi les deux plans suivants |
| 2e | 15,2 – 17,5 s (952–1112) | Couleurs puis fonds : `studio-palette-gold`, `studio-background` ; la carte est ensuite aspirée dans la ligne Saphir (34 dernières images) | | idem | nouveau | idem ; retoucher `FADES` de `shots.ts` si des listes défilantes sont coupées |
| 3 | 19,0 – 26,0 s (1140–1560) | Les widgets créés arrivent sur un écran d'accueil (Neon : moyen, petits, moyen), puis Aurora (un GRAND + un petit + un petit), Planner (grand éditorial + petit), Everyday (clair : M, S, S, M) ; fonds et couleurs assortis | | `HomeBuilder`, config `RESULT_HOMES` | nouveau | widgets à confirmer |
| 4 | 26,0 – 28,83 s (1560–1730) | Carte finale validée | « Ardane. Your whole life. One place. » (début 1586) | `scenes/Close` via `EndCard` | repris tel quel | rien |

Transition app -> écran d'accueil : la carte de l'app est aspirée dans la ligne Saphir (`PROCESS.squeeze`), puis `HomeBuilder` s'ouvre de la même ligne (`lineOpen`) et les widgets se posent un par un (`install`).

## Contrôles faits (2026-11-18)
- `npx tsc --noEmit` dans `~/ardane-tools/film` : aucune erreur dans `pub26/` (une erreur déjà présente, `lifestyle/LifestyleAI.tsx`, indépendante).
- Images fixes rendues avec succès pour la première image, le milieu, la dernière image et chaque plan, des deux films (liste dans le rapport de la session).
- Pas de rendu vidéo, pas de test de synchronisation avec la voix (voix non enregistrée).

## À faire à l'arrivée du nouveau kit (ordre conseillé)
1. Copier les nouvelles captures dans `public/kit2026/en/` (mêmes noms).
2. Régler `shots.ts` : `rect` / `focus` / `zoom` des trois mini-apps (Planning surtout), `FADES`, et les noms de captures du Studio si l'enchaînement a changé.
3. Revoir les pastilles de `PILLS` (textes à confirmer sur les nouveaux écrans) et la mention « With Premium » (`PROCESS.premium`).
4. Contrôler les widgets exportés (Cristal, Graphite) utilisés dans `configs26.ts`.
5. Enregistrer la voix (`vo26.json`), mesurer chaque ligne, ajuster `timing26.ts` si besoin, mixer.

## Mise à jour 2026-11-18 (soir) : réglage sur les nouvelles captures (kit run 471)
- Main Pub, séquence 3 : `pub26-nutrition-dark` (étiquette « Calories left » sous la carte anneau + macros), `pub26-fitness-dark` (« Live workout », carte séance en cours ; capture CLAIRE provisoire), `pub26-planning-dark` (« Your whole week », sélecteur + grille ; étiquette sous le cadre). Valeurs `rect`/`focus` mesurées sur les captures (shots.ts). `MainPub26.tsx` passe `below` de `APP_SHOTS` à la mise en valeur.
- Widget Pub, séquence 2 refaite (StepId : create, editor, content, styleAurora, styleNeon, palette) : `pub26-create-dark` (0 s) -> `pub26-editor-dark` (130, petit widget Calories) -> `studio-content-dark` (250, Medium Macros : le MÊME widget que les étapes Style) -> `studio-style-aurora-dark` (372, voix « And styles. ») -> `studio-style-neon-dark` (452) -> `studio-palette-gold-dark` (532-686). Scènes : « Create. » 0, « Choose. » 130, « Style. » 372. Étape « fond » retirée : `studio-background` est claire et montre un autre widget (blanc, 1 078 kcal), `studio-background-dark` est ratée. « With Premium » de 380 à 690. Pastilles : Pick a size / Choose what it shows / Make it Medium / Change the style / Another style / Pick your colors.
- `FADES` reste vide (les listes sont déjà coupées par l'app elle-même). Durées inchangées : MainPub26 1756 i = 29,27 s, WidgetPub26 1730 i = 28,83 s.
- Captures ratées : app-nutrition-s00(-dark), app-nutrition-meal, app-finances-s00-dark, studio-background-dark, creator-nutrition(-medium/-studio).
- À refaire à l'arrivée des captures sombres définitives : remplacer pub26-fitness-dark (clair provisoire), revoir le contraste de l'étiquette Fitness, Nutrition avec boutons Scan/Search ; studio-background-dark pour réajouter l'étape fond ; décider entre pub26-editor-dark (Small Calories) et un éditeur Macros pour la continuité.
- Images : `pub/pub26/apercus/` (0,3), `pub/pub26/cles/` (0,5 + planches).
