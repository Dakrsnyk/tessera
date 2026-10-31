---
tags: [ardane, memoire, campagne-2026]
---

# 01 · Publicité principale « Your whole life. One place. » — 45 s, 9:16 (recomposée en 1:1, 4:5, 16:9)

Faits : [[Faits-verifies]] · textes : `scripts/ad3/spec/i18n.json` · voix : `vo_spec_en.json` / `vo_spec_fr.json`, film `main` · captures : [[Ressources-a-capturer]].

## Concept créatif
« L'iPhone devient un tableau de bord personnel. » Dans le noir, une seule ligne Saphir s'ouvre et dit la promesse : TOUTE TA VIE. UN SEUL ENDROIT. Puis la promesse devient visible : quatre widgets réels sortent du téléphone (repas, entraînement, semaine, argent) et reviennent s'ordonner dans Mon Quotidien : tout est au même endroit. Deuxième moitié : la personnalisation, le sujet essentiel. Le même widget change de style sous nos yeux, le décor change autour, et le spectateur comprend que c'est LUI qui décide (« Tes widgets. À ta façon. »). Ça vit sur l'écran d'accueil ET sur l'écran verrouillé. Le plan final réunit plusieurs widgets personnalisés (tailles et styles variés) qui se posent sur un écran d'accueil complet, puis le logo Saphir.
Ton : calme, confiant, élégant ; musique qui monte lentement ; silence de 0,4 s avant le logo (signature D5 · silence · A5). Une seule idée par plan, aucune liste de fonctions.
Ce que le spectateur retient : 1) tout au même endroit, 2) gérer son quotidien depuis un seul endroit, 3) widgets personnalisables sur l'écran d'accueil et l'écran verrouillé.

## Storyboard (60 i/s, 2 700 images)
| Plan | Temps | Image | Caméra | Transition |
|---|---|---|---|---|
| P1 | 0,0–3,0 | Noir. Fine ligne Saphir (#68B5F5) au centre, elle s'ouvre horizontalement et révèle le texte « Your whole life. / Toute ta vie. » (SplitText, mot par mot sur la voix M1) | fixe, poussée lente 1,00 → 1,04 | la ligne devient le bord du téléphone (« line seam ») |
| P2 | 3,0–6,0 | Le téléphone sort de la ligne, noir, léger reflet Saphir ; sur l'écran, l'accueil Saphir (`home-hero-*` recapturé Saphir). Texte « One place. / Un seul endroit. » | orbite 14° → face, poussée dans l'écran | cut sur mouvement |
| P3 | 6,0–12,5 | Quatre widgets sortent un par un du téléphone en profondeur (calories + macros Moyen avec ANNEAU ORANGE, Prochaine série, Horaire/À venir, Budget restant) ; chacun grossit jusqu'à être lisible, avec son étiquette (Nutrition / Fitness / Planning / Finances), puis flotte en parallaxe | travelling latéral lent, léger roulis, profondeur de champ | les 4 widgets se replient dans l'écran (SplitOut inverse) |
| P4 | 12,5–17,5 | Plongée dans Mon Quotidien (défilement 60 i/s de `home-s00…s10` recollées) : cartes Nutrition, Séance, Planning, Habitudes, Budget. Texte « Everything that matters. In one place. » | descente verticale continue, 0,6 écran/s | fondu à travers l'écran (le Studio s'ouvre) |
| P5 | 17,5–25,0 | Studio : un même widget (Macros) change de style en direct : Minimal → Clair → Sombre (gratuits) puis Aurore → Néon → Espace (« Avec Premium » en petit), pendant que le fond d'écran change derrière (Universes). Texte « You decide how it looks. / Tu décides de son allure. » puis « Your widgets. Your way. » | contre-plongée orbitale, 3 changements de décor, un geste de caméra par style | le décor Néon se fige et devient l'écran verrouillé |
| P6 | 25,0–32,5 | Écran verrouillé en gros plan (`lock-*` Saphir/Études) : widgets circulaires et rectangulaires (calories, prochaine série, scanner), puis l'Activité en direct du repos (images `live-rest-*`). Textes « Home Screen / Lock Screen », « One glance away. » | gros plan 1,25 → 1,0, léger tangage | les widgets de l'écran verrouillé s'envolent vers le centre |
| P7 | 32,5–39,0 | Gather : 6 à 8 widgets personnalisés de tailles et styles différents (Macros Moyen Aurore, Prochaine série Néon, Budget Petit Sombre, Top 3 Papier, Semaine Moyen…) convergent autour du téléphone et se posent sur un écran d'accueil COMPLET (fond d'un décor du Store). Texte « Your iPhone. Your dashboard. » | recul large, mise au point sur l'écran, rotation 360° douce du téléphone | l'écran complet se contracte en icône Saphir |
| P8 | 39,0–45,0 | Close : l'icône Saphir devient le logo (le « A » en deux moitiés), ARDANE, ligne « Your whole life. One place. » puis « Your widgets. Your way. », petite ligne « Coming soon to the App Store » (sans badge ni prix) | fixe | fin, 0,3 s de silence |

## Texte à l'écran (clés `i18n.json`)
- P1 `common.wholeLife` Your whole life. / Toute ta vie.
- P2 `common.onePlace` One place. / Un seul endroit.
- P3 `common.hlNutrition`, `hlFitness`, `hlPlanning`, `hlFinances`.
- P4 `common.everythingOnePlace` Everything that matters, in one place. / Tout ce qui compte, au même endroit.
- P5 `main.decide`, `common.widgetsYourWay`, `common.withPremium` (sur les styles Aurore, Néon, Espace).
- P6 `common.homeScreen`, `common.lockScreen`, `main.glance`.
- P7 `main.dashboard`.
- P8 `common.wordmark`, `common.wholeLifeOnePlace`, `common.widgetsYourWay`, `common.comingSoon`.
- Petite ligne légale permanente, bas gauche : `common.demoData`.

## Voix off (EN et FR : `vo_spec_*.json`, film `main` ; « Ardane » = ar-DAHN en anglais)
| Id | Début (s) | EN | FR |
|---|---|---|---|
| M1 | 0,8 | Your whole life. | Toute ta vie. |
| M2 | 3,4 | One place. | Un seul endroit. |
| M3 | 6,2 | Your meals. Your training. Your week. Your money. | Tes repas. Ton entraînement. Ta semaine. Ton budget. |
| M4 | 12,6 | Everything that matters, in one place. | Tout ce qui compte, au même endroit. |
| M5 | 17,6 | And you decide how it looks. | Et c'est toi qui décides de son allure. |
| M6 | 21,4 | Your widgets. Your way. | Tes widgets. À ta façon. |
| M7 | 25,4 | On your Home Screen. On your Lock Screen. | Sur ton écran d'accueil. Sur ton écran verrouillé. |
| M8 | 30,0 | Always one glance away. | Toujours à portée de regard. |
| M9 | 33,6 | Your iPhone becomes your personal dashboard. | Ton iPhone devient ton tableau de bord personnel. |
| M10 | 39,4 | Ardane. | Ardane. |
| M11 | 40,3 | Your whole life. One place. | Toute ta vie. Un seul endroit. |
| M12 | 42,6 | Coming soon to the App Store. | Bientôt sur l'App Store. |
Direction : voix féminine, naturelle, élégante, sûre d'elle, inspirante ; chaque ligne posée sur son plan, silence entre M2 et M3 et avant M10. Les « max » des fichiers JSON sont des estimations : à confirmer par `vo.py` puis ajuster le plan, jamais la vitesse de la voix.

## Ressources
- Scènes Remotion existantes : `LineOpen` (P1), `Opening` + `Phone3D` (P2), `WidgetLift` (P3), `MyDay` (P4), `Studio` + `Universes` (P5), `LockScreen` (P6), `Gather` (P7, à refaire avec la roue orange et plus de widgets), `Close` (P8). À CRÉER : un enchaînement `Opening → WidgetLift` qui sort 4 widgets de domaines différents ; la version Saphir de `Close` (logo + deux lignes + « bientôt ») ; la composition `Gather` « écran complet » avec fond de décor.
- Images du kit : `home-hero-*` (écran d'accueil héros, Saphir), `setup-hero-*`, `macros-m-*`, `nextSet-s-*`, `budgetLeft-s-*`, `priorities-s-*`, `timetable-l-*`, `weekView-m-*`, `home-s00…s10`, `lock-*`, `live-rest-*`, `studio-style`, `studio-theme`. Détail et manquants : [[Ressources-a-capturer]].
- Musique : partition originale (`score.py`), montée 0 → 100 % de P2 à P7, silence avant le logo.

## Mentions
- « Avec Premium » : P5 (styles Aurore, Néon, Espace) et P7 (écran complet de 6 à 8 widgets stylés). Les 3 premiers styles du P5 (Minimal, Clair, Sombre) et 3 widgets sont gratuits. Aucun prix, aucun essai.
- Chiffres de P3/P4 lus sur les captures (données de démonstration).
