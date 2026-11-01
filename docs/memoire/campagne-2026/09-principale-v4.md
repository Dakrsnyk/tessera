---
tags: [ardane, memoire, campagne-2026, principale-v4]
---

# 09 · Principale V4 — « Too many apps → one place » (≈ 66 s, 9:16 d'abord, anglais seul)

Demande de l'utilisateur du 2026-10-31 (V3 → V4). La V3 (`pub/film2026/v3/main-v3-9x16-en.mp4`, composition `FilmMainV3`) garde sa direction : identité Saphir premium, accroche, couches explosées. À corriger : transitions Nutrition/Fitness/Habitudes beaucoup trop rapides, widgets coupés, séquence widgets sans processus, écrans d'accueil absents. Périmètre : UNIQUEMENT la principale (pas de Nutrition/Fitness/Finance/Widgets individuelles). Voix anglaise seule, pas de français.

Règles : réutiliser les clips et captures existants (`public/kit2026/en/`, scènes de `src/scenes/`, `src/v3/`) ; rien d'inventé (ni écran, ni widget, ni fonction) ; interface en anglais ; roue des calories orange, macros rouge/jaune/bleu ; « With Premium » sur toute fonction Premium ; aucun badge, aucun prix ; aucun widget coupé, aucun texte tronqué, marges respectées ; pas d'emojis ; pas de décor gratuit ; moments de respiration ; chaque mini-app doit rester assez longtemps pour être comprise.

## Inventaire des ressources réelles (kit anglais `public/kit2026/en/`)
- **Écrans complets de l'app** : `app-finances-s00…s10`, `app-finances-categories/bills/savings/transactions/trends`, `fin-mois/3mois/annee`, `app-fitness-*` (library, program, progress, history, activity, exercise-*), `session-0…3`, `lib-0…3`, `ex-0/1`, `nut-0…3`, `nutrition-plan`, `scan-food`, `scan-frame*`, `hab-0/1`, `habits-m-*`, `habitStreak-s-*`, `plan-0/1`, `timetable-*`, `weekView-*`, `home-s00…s10` (Mon Quotidien : nutrition, planning, habitudes, budget).
- **Animations d'exercices** : `demo-back-squat-NNNN`, `demo-bench-press-NNNN`, `demo-pull-up-NNNN`, `demo-deadlift-dark-NNNN` (séquences d'images).
- **Widgets** : `calories-*`, `macros-m-*`, `nextSet-*`, `budgetLeft-*`, `habits-m-*`, `priorities-*`, `weekView-*`, `spendingByCategory-*`, `moneyDashboard-*`…, avec styles (light, dark, aurora, neon, luxury, paper, space, glass).
- **Processus de création** : `store*` (`store-at-0.12…0.84`, `store`, `store-dark`, `store-end` : la bibliothèque de widgets qui défile), `mywidgets`, `editor-v2`, `studio-content/style-*/colors/background/palette-*/preset-*`, `setups`, `spaces-lock`.
- **Écrans d'accueil réels (générés par l'app, avec ses icônes d'applications natives thématisées)** : `home-*` (aurore, espace, minuit, minuit-aurora, hero-aurore, hero-espace, hero-crepuscule, hero-neon, hero-light, hero-graphite, hero-etudes, crepuscule, mars, ocean, neon, nebuleuse, graphite, creme, free3, jade…), `setup-*`, `icons-*` (icônes du dock et des applications par thème), `wall-*` (fonds d'écran), `lock-*`.

## Structure (4 étapes, dans l'ordre)
| Étape | Temps | Contenu |
|---|---|---|
| 1. ACCROCHE | 0–10,5 s | Accroche V3 conservée, MOINS précipitée : la phrase « Your life isn't one thing. » (0,6 s) puis « Why manage it in ten different apps? » (≈ 3,6 s) ; moments du quotidien traités sans emojis (formes graphiques sobres, mots-clés), l'essaim d'applis génériques monte plus lentement, gel et impact (≈ 8 s) puis transition forte vers l'écosystème Ardane (ligne Saphir → iPhone 3D) ; « Meet Ardane. Everything that matters. One place. » |
| 2. MINI-APPS | 10,5–36 s | Nutrition (≈ 5,5 s) · Fitness (≈ 6,5 s) · Habits (≈ 4,5 s) · Finances (≈ 5,5 s) · Planning (≈ 5 s). Chaque mini-app : titre, écran réel complet bien cadré, un geste clé (scan du code-barres → calories orange + macros ; bibliothèque → fiche d'exercice animée → série/progression ; habitudes cochées + régularité ; budget, comptes, graphique, catégories ; calendrier, semaine, événements). Transitions de motion design d'une mini-app à l'autre (un seul écosystème : l'écran glisse, la ligne Saphir passe, les cartes se réassemblent), 0,4–0,6 s de respiration entre. |
| 3. WIDGETS | 36–50 s | Le processus : bibliothèque de widgets (Store qui défile, catégories) → sélection d'un widget → éditeur (contenu, style, couleurs, fond ; « With Premium » sur Aurora/Neon) → composition de son écran (setups). Visuel : motion design premium, l'interface réelle jamais coupée. |
| 4. ÉCRANS D'ACCUEIL | 50–61 s | 4 vrais écrans d'accueil iPhone, chacun ≈ 2,5 s avec respiration, dans un iPhone crédible (applications natives du thème déjà présentes : Calculator/Compass/Photos/Calendar/Settings… tirées des icônes `icons-*` du kit, jamais surchargé) : bleu et sombre · rouge et sombre · rose et violet · blanc et argenté. Couleurs des widgets et fond d'écran qui matchent parfaitement (voir règle ci-dessous). |
| FIN | 61–66 s | Close : logo, ARDANE, « Your whole life. One place. », « Coming soon to the App Store » (sans badge ni prix), 0,3 s de silence final. |

Règle des écrans d'accueil : si le kit ne contient pas une composition exacte, la composer à partir de pièces réelles (fond `wall-*`, widgets exportés dans le style voulu, icônes `icons-*`), sans inventer de widget ; vérifier à l'œil que widgets, fond et icônes ont la même teinte ; sinon changer de composition.

## Voix (anglais, féminine) — lignes
H1 « Your life isn't one thing. » · H2 « Why manage it in ten different apps? » · « Meet Ardane. » · « Everything that matters. One place. » · Nutrition « Scan what you eat. See what it adds up to. » · Fitness « Every exercise, move by move. Every set, counted. » · Habits « Build the habits that stick. » · Finances « Know where your money stands. » · Planning « Your week, at a glance. » · Widgets « Pick the widgets that matter. Make them yours. » · Homes « Your iPhone. Your way. » · Close « Ardane. Your whole life. One place. »
(Les textes d'écran correspondants sont les mêmes en plus court ; rien de médical : « estimates ».)

## Cadrage (contrôle obligatoire)
Pour chaque iPhone et chaque widget : widget entier visible, proportions réelles, marges, aucun texte tronqué, aucun zoom qui masque l'interface, aucune animation qui sort du cadre. Contrôle image par image de chaque séquence puis du montage complet (planches-contact à regarder).

Livrables : `pub/film2026/v4/main-v4-9x16-en.mp4`, projet Remotion (`FilmMainV4` dans `scripts/ad2/film/src/v4/`), liste des ressources utilisées, rapport des modifications par rapport à la V3.
