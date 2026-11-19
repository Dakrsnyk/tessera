---
tags: [ardane, memoire, campagne-2026, storyboards, pub26, v2]
---

# 22 · Version 2 des deux pubs (retour du PDG sur la v1) — 2026-11-18

Suite de `21-passation-v2-2026-11-18.md` (retour du PDG mot pour mot, règles). Ce qui change par rapport à la v1 (`20-storyboards-2026-11-18.md`) :
- la voix commente ce que montre l'image, du début à la fin : aucun blanc de voix de plus de 1,5 s entre l'accroche et la phrase de fin (mesuré sur la piste de voix seule, voir « Contrôles ») ;
- « Meet Ardane. » juste après l'accroche de la Main Pub ;
- plusieurs écrans par mini-app (Nutrition : 4, Fitness : 6, Planning : 4), Studio complet dans la Widget Pub (styles, couleurs, palettes, thèmes, My widgets) ;
- Main Pub 52,3 s, Widget Pub 38,8 s (une minute au plus) ; accroche (images 0 à 446, son compris) et carte finale (170 images) inchangées.

Texte écrit à partir des trois brouillons de `scripts/ad2/pub26_v2/scenarios-brouillons.json` (base : « bénéfice pour l'utilisateur », avec les phrases courtes de « démonstration rythmée »). Écartés : le scan photo d'un plat (les captures de l'écran de scan sont toutes ratées et l'écran dessiné par le film repose sur une ancienne capture), « Personal best » sombre (pas de capture sombre de la fiche Squat défilée : la claire est gardée), Progress (captures ratées).

## Vérifié dans le code de l'app (lecture seule)
- 163 exercices dans `Shared/Domains/ExerciseLibrary.swift` (`all`), 163 animations dans `App/Resources/ExerciseDemos.json` : « Over 160 exercises. Each one, demonstrated. » est vrai.
- Bibliothèque d'exercices et fiches : Premium (`ExerciseLibraryViews.swift`, « Every exercise is Premium ») ; progression et records : Premium (`FitnessPages.swift`) ; habitudes : 3 gratuites (`AppModel.freeHabitLimit`), la capture en montre 4 : « With Premium » affiché sur ces écrans, et sur les styles, couleurs, palettes et thèmes du Studio.
- L'animation `demo-back-squat-dark` (kit) est le dessin actuel de l'app (silhouette blanche, muscles en rouge, comme `ex-1-dark`) ; posée sur la couleur de la carte (#1A1B1E) : `demo-back-squat-card-*` dans `public/kit2026/en/` (copie éclaircie du noir, faite le 2026-11-18). « Remontée » et « Profil » (français restés dans la capture) sont masqués.

## Film 1 · MainPub26 — 3136 images = 52,27 s

| # | Début – fin | On voit | Voix (début) |
|---|---|---|---|
| 1 | 0 – 7,43 s | Accroche validée | « Your life isn't one thing. » « Why manage it in ten different apps? » |
| 2a | 7,43 – 10,8 s | Écran « Planning & focus » sorti de la ligne Saphir ; légende « Meet Ardane. » puis « All your essentials on your home screen. » | « Meet Ardane. » (7,60) « All your essentials on your home screen. » (8,77) |
| 2b | 10,8 – 12,5 s | « Sport & wellness » | « See today's workout. » (11,00) |
| 2c | 12,5 – 14,0 s | « Nutrition » | « Check your calories. » (12,67) |
| 2d | 14,0 – 16,5 s | « Everything in one place » | « Without opening a single app. » (14,17) |
| 3 | 16,5 – 24,1 s | Nutrition : anneau « Calories left » ; boutons Scan / Search ; feuille Add a food ; quantité du yaourt ; anneau passé à 1 569 kcal | « Nutrition. » « Know what's left to eat. » « Scan it, or search it. » « Log it, and your day updates. » |
| 4 | 24,1 – 35,8 s | Fitness : séance en cours ; série 3 sur 4 ; minuteur de repos ; bibliothèque (With Premium) ; fiche Squat avec l'animation ; record personnel et courbe | « Fitness. » « Never lose count of a set. » « Rest on the timer. » « Over 160 exercises. » « Each one, demonstrated. » « And every record, tracked. » |
| 5 | 35,8 – 42,9 s | Planning : grille de la semaine ; page Week (cours, événements, tâches du jour) ; Habits 3/4, série de 12 jours ; 4/4 | « Planning. » « Classes, events, and tasks. » « Build your habits. » « And keep your streak. » |
| 6 | 42,9 – 49,4 s | Widget Macros isolé, puis l'écran d'accueil où il se pose avec deux autres, puis le thème Aurora assorti au fond (With Premium) | « Make everyday your own. » « Start with one widget. » « Then give it your style. » |
| 7 | 49,4 – 52,27 s | Carte finale validée | « Ardane. Your whole life. One place. » |

Minutages exacts, écran par écran : `scripts/ad2/film/src/pub26/timing26.ts` (`MAIN`, `MAIN_VO`) ; captures, zones et étiquettes : `shots.ts` (`APP_SHOTS`).

## Film 2 · WidgetPub26 — 2330 images = 38,83 s

| # | Début – fin | On voit | Voix |
|---|---|---|---|
| 1a | 0 – 1,5 s | Écran d'accueil iOS AVANT Ardane | « You want your phone to look like this? » (0,50) |
| 1b | 1,5 – 8,3 s | Cinq écrans APRÈS, un par un : Minimal, Luxury (bronze), Colorful (rose), Sober (indigo), Synthwave | « Elegant. » « Colorful. » « Sleek. » « Or bold. » (un mot par écran) |
| 2a | 8,3 – 10,8 s | Create : « What size for your widget? » | « With Ardane, you can customize your own widgets. » |
| 2b | 10,8 – 12,8 s | Éditeur (Calories, tailles) | « Choose what it shows. » |
| 2c | 12,8 – 17,3 s | Style : Aurora, Neon, Space, Liquid Glass (With Premium) | « And styles. » « Neon. » « Space. » « Liquid Glass. » |
| 2d | 17,3 – 20,8 s | Couleurs : Gold, palette Ocean, Dusk | « Pick your colors. » « Or a whole palette. » |
| 2e | 20,8 – 24,3 s | Thèmes : Midnight, Luxury, Cyber | « Or start from a theme. » « One tap, and it all changes. » |
| 2f | 24,3 – 26,7 s | My widgets (« Add to screen »), puis la carte aspirée dans la ligne Saphir | « Then add it to your home screen. » |
| 3 | 26,7 – 36,0 s | Les widgets se posent (Neon), puis Aurora (un grand), Planner, Everyday ; légende « Your phone. Your style. Your widgets. » | « Watch your screen come together. » « Small, medium, or large. » « No two screens alike. » « Your phone. Your style. Your widgets. » |
| 4 | 36,0 – 38,83 s | Carte finale validée | « Ardane. Your whole life. One place. » |

« Meet Ardane. » n'est PAS dans la Widget Pub (la phrase suivante dit déjà « With Ardane… ») : question posée au PDG à la livraison.

## Voix
- Kokoro `af_heart`, vitesse 1.0 (`scripts/ad2/vo_spec_pub26.json`). Gardés de la v1 (déjà entendus par le PDG) : « All your essentials… », « Make everyday your own. », « You want your phone… », « With Ardane… », « And styles. » ; « Nutrition. » « Fitness. » « Planning. », l'accroche et la phrase de fin viennent des pubs validées.
- « Calm. » a été remplacé par « Sleek. » (Whisper entendait « Come. »).

## Contrôles (2026-11-18)
- `npx tsc --noEmit` dans `~/ardane-tools/film` : aucune erreur dans `pub26/`. Images fixes de chaque plan des deux films regardées (`~/ardane-tools/film/out/v2stills/`) ; deux corrections faites : l'étiquette « Set 3 of 4 » passée au-dessus (elle chevauchait « Skip set ») ; le plan « Themes » montrait l'onglet Content : `studio-content-dark` du kit n'est PAS celle du lot 472 (copiée sous `studio-theme-midnight-dark.png`).
- Son (`audio_pub26.py check`) : Main Pub -14,0 LUFS, voix 11,4 dB au-dessus de la musique, 7,43 premières secondes identiques à `mix-v5short.wav` (écart max 7e-19), plus long blanc de voix après l'accroche 1,49 s ; Widget Pub -14,0 LUFS, voix 12,2 dB au-dessus, plus long blanc 1,22 s. Whisper comprend chaque phrase (« Ardane » entendu « Ardhan », comme dans les pubs validées).
- Rendu Main Pub v2 : 52,27 s, 1080x1920, 60 i/s, 3136 images, -14,0 LUFS, aucune image noire (`blackdetect`), planche de 25 images regardée (`pub/pub26/final/planche-main-pub-v2.png`).
- Pas écouté à l'oreille par le Chef (pas d'écoute possible) : rythme de la voix, équilibre voix / musique et naturel des phrases restent à juger par le PDG.
- Widget Pub v2 : montée et mixée, NON rendue (le PDG valide d'abord la Main Pub).

## v2.1 (2026-11-18) : sans zoom / dézoom entre les fonctionnalités
Demande du PDG : « je parle du zoom puis dezoom entre chaques fonctionnalités ». Dans chaque mini-app, la caméra se rapproche une fois, glisse d'une zone à la suivante (même écran) ou garde son rapprochement pendant le balayage vers l'écran suivant, et ne revient au plein écran qu'à la sortie de la mini-app. Les zones mises en valeur s'enchaînent sans trou. Minutages, voix et son inchangés. Rendu : `ardane-main-pub-v2.1-1080x1920.mp4`.

## v2.2 (2026-11-18) : fin sans double image
Bug signalé par le PDG (capture de la fin) : pendant le passage au style Aurora, Budget ($1,631) et Meditate (12 days) se superposaient dans la même case, et Today's workout apparaissait en transparence sur les icônes. Les deux écrans de fin ont maintenant les MÊMES trois widgets (Macros, Calories, Meditate), en clair puis en Aurora (mêmes chiffres) : seul le style change, ce que dit la voix (« Then give it your style. »). Règle pour `HomeBuilder` : un morphing ne doit changer que le style d'un widget, jamais le widget d'une case ni le nombre de cases.

## v2.3 (2026-11-18) : voix liée, écran verrouillé à la fin de Fitness
Demande du PDG : remplacer « Rest on the timer » (minuteur) par « and your training on your lock screen » avec la notification de séance, à la FIN de Fitness ; des mots de transition entre mini-apps et entre fonctionnalités (« you have nutrition », « also fitness ») : voix fluide, professionnelle, cohérente.
- Texte Main Pub (3230 images = 53,83 s) : … « Without opening a single app. » / « Inside the app, you have Nutrition. » « Know what's left to eat. » « Scan your food, or search for it. » « Log it, and your day updates. » / « There's also Fitness. » « Track every set as you go. » « Choose from over 160 exercises. » « Each one, demonstrated. » « Watch your records climb. » « And your training on your lock screen. » / « Finally, there's Planning. » « Your classes, events, and tasks. » « Build your habits. » « And keep your streak. » / « Make everyday your own. » …
- « Nutrition. » « Fitness. » « Planning. » (enregistrements validés de v5short) ne sont plus utilisés : les phrases d'entrée sont enregistrées avec la même voix ; le mot-titre à l'écran reste.
- Écran verrouillé : `custom: "lockLive"` (`v5/lib/LockLive.tsx`, vraies captures `lock-minuit` + `live-ready-night` / `live-afterset-night-*`) : la Live Activity monte du bas, « Set done » est touché, le repos repart à 2:00. Même mise en page que l'aperçu de l'app actuelle (`spaces-lock-end`, 2026-11-18) ; gratuite (aucun contrôle Premium autour de `Activity.request`). Reste visible : la date « Saturday, October 31 » de la capture de l'écran verrouillé.
- Son : `VOICE_LIFT` -1,6 dB, -14,0 LUFS, voix 11,8 dB au-dessus de la musique, plus long blanc de voix 1,48 s, accroche identique bit pour bit, Whisper comprend chaque phrase.

## v2.4 (2026-11-18) : « And much more. »
Demande du PDG : ne plus dire « Finally » pour Planning ; finir la présentation des mini-apps par « and much more » avec des écrans des autres mini-apps qui défilent (2 s au plus).
- Planning : « Stay organized with Planning. » … « Keep your streak going. » (au lieu de « And keep your streak. », pour éviter deux « And » de suite), puis « And much more. ».
- Défilé (`More26.tsx`, 120 images = 2 s, entre Planning et « Make everyday your own. ») : 4 vraies captures de l'app actuelle qui passent de droite à gauche, avec le nom de la mini-app sous chacune : Finances (budget du mois), Business (chiffre d'affaires), Finances « Analysis » (With Premium : comparaisons et six mois sont Premium dans `FinancesApp.swift`), Business (ventes). Études, Voyage, Auto et Photos n'ont AUCUNE capture de l'app actuelle (`app-travel-en`, `app-photos-en` datent du 2026-11-10) : non montrées. Pour les ajouter : captures de ces mini-apps par un run `[adkit-img]`.
- Main Pub 3360 images = 56,0 s ; -14,0 LUFS ; voix 11,2 dB au-dessus de la musique ; plus long blanc de voix 1,49 s.

## v2.5 (2026-11-18) : le widget Planning dans les derniers plans
Demande du PDG : intégrer le widget Planning (« widget essentiel à montrer ») dans les derniers plans, à la place d'anciens. `MAKE_HOMES` : Macros (Medium, rangée du bas, posé en premier : c'est le widget montré seul juste avant) + « Weekly schedule » de Planning (Large, en haut), en clair puis en Aurora (mêmes données) ; Calories et Meditate retirés. `weekView` écarté : ce n'est qu'une barre de progression de la semaine, sans événements. Bruitages : deux poses au lieu de trois (`audio_pub26.py`).
