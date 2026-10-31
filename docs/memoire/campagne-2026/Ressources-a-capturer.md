---
tags: [ardane, memoire, campagne-2026]
---

# Ressources à capturer pour la campagne 2026

Liste des images réelles dont les 8 publicités ont besoin, comparée à `scripts/ad_export.txt` (pièces : `report/adkit/export/<nom>.png`, séquences `<nom>-<NNNN>.png`, setups `<nom>-<index>.png`) et `scripts/ad_screens.txt` (écrans : `report/adkit/screens/<fichier>.png`). Tout est capturé par `[adkit]` ; MISE À JOUR 19.2 (2026-10-31) : les lignes des sections 2 et 3 sont maintenant dans `scripts/ad_export.txt` et `scripts/ad_screens.txt` (sauf ce qui est noté « impossible » ci-dessous) ; les pièces `hydration-s-light`, `lock-hydration-circular`, `*-corail` et `macros-m-palette-coral`, `studio-palette-coral` ne sont plus produites (`hydration-s-ocean` et `hydration-s-glass` restent tant que `Gather.tsx` les cite). Langue : `[adkit]` produit le kit français (`report/adkit`), `[adkit-en]` le kit anglais (`report/adkit-en`, variable `AD_LANG=en`). Faits associés : [[Faits-verifies]].

## 0. Préalables (avant de recapturer)
1. Les en-têtes de `ad_export.txt` et `ad_screens.txt` parlent encore du « style Corail » : l'app est en Saphir par défaut depuis le 2026-10-29 (14.5) et l'icône Saphir depuis le 2026-10-30. Le run `[adkit]` du commit 5ccab01 fournit le kit en Saphir ; vérifier sur une capture avant de composer.
2. La roue des calories ORANGE et les macros rouge/jaune/bleu doivent figurer sur toutes les captures Nutrition (widgets `macros-*`, `calories-*`, `quickFood-*`, écran `app-nutrition-*`, écran verrouillé).
3. Ne plus utiliser : toutes les lignes `hydration-*` (widget retiré), `*-corail`, `*-palette-coral` (l'accent Corail reste une couleur de widget gratuite, mais l'identité de la campagne est Saphir), toute donnée « Eau » de `home-s*`/Mon Quotidien (vérifier qu'il n'en reste pas).
4. Relire `live-*` : les boutons de l'activité en direct sont maintenant Pause/Reprendre, Passer (saute la série), Série faite, retour, croix.

## 1. Déjà dans le kit — à réutiliser (noms exacts)
Écrans (`report/adkit/screens/…`) :
- Mon Quotidien : `home-s00` … `home-s10`.
- Nutrition : `app-nutrition-s00` … `app-nutrition-s10`, `scan-food`, `scan-frame`, `scan-frame-white`, `scan-frame-dark`, `scan-frame-white-dark`, `app-nutrition-s00-dark`.
- Fitness : `app-fitness-s00` … `s10`, `app-fitness-program`, `-progress`, `-history`, `-library`, `app-fitness-exercise-bench-press(-end)`, `…back-squat(-end)`, `…deadlift(-end)`, `…pull-up(-end)`, `app-fitness-session(-end)`, et en sombre `app-fitness-session-dark`, `app-fitness-session-end-dark`, `app-fitness-library-dark`, `app-fitness-exercise-bench-press-dark`.
- Finances : `app-finances-s00` … `s10`, `app-finances-categories`, `-bills`, `-savings`, `-transactions`.
- Planning : `app-planning-s00` … `s10`, `app-planning-habits`, `-week`, `-tasks`, `app-planning-week-dark`, `app-planning-habits-dark`.
- Store, Studio, icônes, écran verrouillé : `store`, `store-at-0.12 … 0.84`, `store-end`, `setups`, `setups-end`, `setup-jade/aurore/minuit/neon`, `studio-content`, `studio-theme`, `studio-style`, `studio-style-mid`, `studio-colors`, `studio-background`, `studio-border`, `studio-palette-sunset`, `icons`, `spaces-lock`, `spaces-lock-end`.
Pièces (`report/adkit/export/…`) :
- Macros : `macros-m-light/dark/glass/aurora/neon/luxury/liquidGlass/paper/space/ocean/synthwave/editorial/matteBlack/blossom`, `macros-m-preset-*`, `macros-m-palette-*`. Calories : `calories-s-*` (14 styles), `calories-m-light`, `calories-m-aurora`. Ajout rapide (Premium) : `quickFood-s-light`, `quickFood-m-light/paper/aurora/neon/glass/luxury/space`.
- Fitness : `nextSet-s-light/neon/luxury`, `todaysWorkout-m-light/dark/aurora`, `restTimer-s-light/neon/dark` (Premium), `trainingStreak-s-light/aurora/sport`, `weeklyVolume-m-*` (Premium), `weekView-m-light/aurora/editorial`.
- Argent : `budgetLeft-s-light/dark/luxury`, `spendingByCategory-m-light/dark/glass/crepuscule` (Premium), `moneyDashboard-m-light/dark/aurora` (Premium).
- Habitudes et Planning : `habits-m-light/aurora/neon`, `habitStreak-s-light/aurora/neon`, `priorities-s-light/dark/paper`, `timetable-l-light/aurora/editorial`, `upNext-s-light/elegant/dark`, `yearDots-l-*` (Premium).
- Écran verrouillé (encre blanche, fond transparent) : `lock-macros-rect`, `lock-macros-rect-darkink`, `lock-caloriesLeft-circular/rect/inline`, `lock-proteinLeft-circular` (Premium), `lock-nextSet-rect`, `lock-restTimer-circular/rect` (Premium), `lock-trainingStreak-circular`, `lock-budgetLeft-rect`, `lock-habitStreak-circular`. (`lock-hydration-circular` : à ne pas utiliser.)
- Décors complets : `setup-<id>` + `lock-<id>-<n>` + `icons-<id>` pour jade, aurore, minuit, neon, ocean, nebuleuse, crepuscule, creme ; `home-<id>` pour les 23 décors du Store (creme, aurore, graphite, neon, topographie, minuit, etudes, jade, dune, pastel, bureau, corail, ocean, foret, crepuscule, terrazzo, nebuleuse, seventies, espace, mars, nature, botanique, vagues) et `home-jade-nebula`, `home-jade-aurora`, `home-minuit-aurora`, `home-creme-pastel` ; 18 fonds `wall-*`.
- Accueils héros : `home-hero-aurore`, `home-hero-espace`, `home-hero-etudes`, `home-hero-neon`, `home-hero-graphite`, `home-hero-crepuscule`, `home-hero-light` + les `setup-hero-*` correspondants, `icons-espace/etudes/graphite`, `lock-etudes`.
- Activité en direct : `live-rest-real-<NNN>`, `live-afterset-real-<NNN>`, `live-paused-real`, `live-ready-real`, mêmes états `…-night`, `live-rest-real-light`, `live-rest-clear`.
- Démonstrations d'exercice (60 i/s, `<nom>-<NNNN>.png`) : `demo-bench-press`, `demo-back-squat`, `demo-deadlift`, `demo-pull-up` et `…-dark`.
Plans de sortie : voir quelle pub utilise quoi dans les fichiers 01 à 08 (section Ressources).

## 2. MANQUANT — à ajouter à `scripts/ad_export.txt` (format de ce fichier)
Accueils composés (rows : `|` sépare les lignes, `+` met deux petits côte à côte ; noms de types = `WidgetKind`) :
```
# Écran d'accueil de 3 widgets, tous gratuits (publicité Widgets, plan d'ouverture)
home home-free3 setup=graphite rows=macros.medium|nextSet.small+priorities.small theme=minimal
setupwidgets setup-free3 setup=graphite rows=macros.medium|nextSet.small+priorities.small theme=minimal
# Trois profils (publicité Widgets, plan P5) et écran complet (principale P7, Lifestyle P8, Courte 3)
home home-profile-athlete setup=neon rows=nextSet.medium|todaysWorkout.medium|macros.small+trainingStreak.small theme=neon
setupwidgets setup-profile-athlete setup=neon rows=nextSet.medium|todaysWorkout.medium|macros.small+trainingStreak.small theme=neon
home home-profile-student setup=etudes rows=timetable.large|upNext.small+priorities.small theme=paper
setupwidgets setup-profile-student setup=etudes rows=timetable.large|upNext.small+priorities.small theme=paper
home home-profile-minimal setup=graphite rows=clock.medium|priorities.small+budgetLeft.small theme=minimal
setupwidgets setup-profile-minimal setup=graphite rows=clock.medium|priorities.small+budgetLeft.small theme=minimal
home home-complete-aurore setup=aurore rows=macros.medium|nextSet.medium|weekView.medium|budgetLeft.small+priorities.small theme=aurora
setupwidgets setup-complete-aurore setup=aurore rows=macros.medium|nextSet.medium|weekView.medium|budgetLeft.small+priorities.small theme=aurora
home home-complete-espace setup=espace rows=macros.medium|nextSet.medium|weekView.medium|budgetLeft.small+priorities.small theme=space
setupwidgets setup-complete-espace setup=espace rows=macros.medium|nextSet.medium|weekView.medium|budgetLeft.small+priorities.small theme=space
# Écrans verrouillés assortis aux profils
lock lock-graphite setup=graphite scale=3
lock lock-espace setup=espace scale=3
```
(Les styles `aurora`, `neon`, `space`, `paper` sont des styles d'identifiant du kit : Aurore, Néon, Espace, Papier ; `minimal` est gratuit. Les accueils « complete » sont Premium : mention « Avec Premium ».)
Widgets isolés (pour les faire « sortir » du téléphone) :
```
widget tasks-s-light kind=tasks family=small scale=4 theme=light
widget tasks-m-light kind=tasks family=medium scale=3 theme=light
widget counter-s-light kind=counter family=small scale=4 theme=light
widget quickExpense-s-light kind=quickExpense family=small scale=4 theme=light
widget savingsGoal-s-light kind=savingsGoal family=small scale=4 theme=light
widget savingsGoal-m-light kind=savingsGoal family=medium scale=3 theme=light
widget habits-m-dark kind=habits family=medium scale=3 theme=dark scheme=dark
widget timetable-m-light kind=timetable family=medium scale=3 theme=light
widget upNext-m-light kind=upNext family=medium scale=3 theme=light
widget clock-m-minimal kind=clock family=medium scale=3 theme=minimal
widget weekView-m-dark kind=weekView family=medium scale=3 theme=dark scheme=dark
widget lock-priorities-rect kind=priorities family=rect scale=4
widget lock-upNext-rect kind=upNext family=rect scale=4
widget lock-timetable-rect kind=timetable family=rect scale=4
widget lock-tasks-rect kind=tasks family=rect scale=4
```
Vérifier chaque `family` contre `KindInfo.families` de `KindCatalog.swift` avant d'ajouter une ligne (certains types n'ont pas de variante rect).
Variantes sombres des widgets de la pub principale (fond noir) : `calories-m-dark`, `nextSet-m-dark`, `budgetLeft-m-dark` en `scheme=dark` si le Moyen existe.

## 3. MANQUANT — à ajouter à `scripts/ad_screens.txt`
Variantes sombres (publicités sur fond noir) :
```
home-s00-dark home -screenshotScroll 0 -screenshotAppearance dark
home-s03-dark home -screenshotScroll 0.3 -screenshotAppearance dark
home-s06-dark home -screenshotScroll 0.6 -screenshotAppearance dark
app-finances-s00-dark app-finances -screenshotScroll 0 -screenshotAppearance dark
app-finances-s03-dark app-finances -screenshotScroll 0.3 -screenshotAppearance dark
app-fitness-progress-dark app-fitness-progress -screenshotAppearance dark
app-planning-tasks-dark app-planning-tasks -screenshotAppearance dark
studio-style-dark studio-style -screenshotAppearance dark
studio-colors-dark studio-colors -screenshotAppearance dark
studio-background-dark studio-background -screenshotAppearance dark
store-dark store -screenshotAppearance dark
```
Écrans qui ont déjà un identifiant de scène dans `App/Core/ScreenshotMode.swift` (donc réalisables par la seule liste) :
```
app-nutrition-meal app-nutrition-meal
app-nutrition-ideas app-nutrition-ideas
app-nutrition-nutrients app-nutrition-nutrients        # Premium : à n'utiliser qu'avec la mention
app-nutrition-saved app-nutrition-saved
app-planning-month app-planning-month
app-planning-focus app-planning-focus
app-finances-trends app-finances-trends                 # 3 mois / année : Premium
app-fitness-activity app-fitness-activity
mywidgets mywidgets
editor-v2 editor-v2
```
Écrans pour lesquels aucun identifiant n'existe dans `ScreenshotMode.swift` (il faudra une entrée Swift, hors de cette tâche, ou une autre solution) :
- `scan-recap` : le récapitulatif du scan (`ScanRecapView`, avec « Vérifié » et, pour la photo, « Estimation »). Utilisé par Nutrition P2 et Lifestyle P3. Solution de repli : une capture composée par Remotion ne doit PAS être fabriquée ; sinon retirer ce plan.
- `nutrition-plan` : `WeightPlanSummaryView` (objectif perdre/maintenir/prendre avec cibles). Utilisé par Nutrition P4. Repli : la carte `NutritionTargetsCard` de Profil (`profile-targets`, aussi sans identifiant).
- `scan-food-lock` : le widget d'écran verrouillé « Scanner un aliment » (circulaire et rectangulaire) : ce n'est pas un `WidgetKind`, `AdExport` ne sait pas le dessiner. Repli : photographier l'écran verrouillé du Store (`lock-*`) qui l'inclut s'il y figure, sinon retirer P6 de Nutrition ou l'annoncer sans image de ce widget.
- `studio-font` : choix de la police du Studio (Thème/Standard/Arrondie/Serif/Mono) ; sinon `studio-style -screenshotScroll bottom`.
- `paywall` : existe (`paywall`, `paywall-widget`, `paywall-history`) ; à capturer pour LECTURE INTERNE seulement (compter les types gratuits/Premium, vérifier les noms), jamais dans une publicité.

## 4. À recomposer en code (Remotion, hors de cette tâche)
- Anneau des calories ORANGE et barres rouge/jaune/bleu dans `Nutrition.tsx` et `Gather.tsx` (roue noire périmée), couleurs `FF9500`, `FF3B30`, `FFCC00`, `0A84FF`.
- `Close.tsx` : version Saphir (logo Saphir, ARDANE, deux lignes de promesse, « Coming soon ») pour les 8 pubs.
- Lignes de texte : fusionner `scripts/ad3/spec/i18n.json` dans `scripts/ad2/film/src/lib/i18n.json` ; ajouter les spécifications de voix `vo_spec_en.json` / `vo_spec_fr.json` (voir le README de `scripts/ad2` : `vo.py` prend un fichier et un nom de film).

## 5. Fichiers attendus en sortie de production (pour l'ordre de livraison 19.5)
Pour chaque film `main`, `nutrition`, `fitness`, `lifestyle`, `widgets`, `finance`, `organisation`, `short1`, `short2`, `short3` : `<film>-<lang>.mp4` (fr, en), voix `audio/<lang>/<film>-<ID>.wav`, mix `audio/<lang>/mix-<film>.wav`, et les formats 9:16 / 1:1 / 4:5 / 16:9 recomposés.

## 6. État après 19.2 (2026-10-31)
- Nouveaux identifiants de scène (`App/Core/ScreenshotMode.swift`) : `scan-recap` (produit lu par code-barres, aliments « Vérifié »), `scan-recap-photo` (plat estimé, « Estimation »), `nutrition-plan` (objectif perdre 6 kg, calcul non appliqué). Données de démonstration seulement (aliments de la table, profil d'exemple). Fichiers de sortie : `scan-recap`, `scan-recap-photo`, `nutrition-plan`, `profile-targets` (= `info-nutrition`), `studio-font` (= `studio-style` défilé en bas), `paywall*` (lecture interne).
- IMPOSSIBLE sans autre fichier : `scan-food-lock` (widget d'écran verrouillé « Scanner un aliment ») : `ScanFoodLockView` est dans `Widgets/` (extension seulement), `AdExport` (app) ne peut pas le dessiner. Il faudrait déplacer `ScanFoodLockView` et `ScanFoodEntry` dans `Shared/` puis ajouter un type `scanfood` à `AdExport`. Repli : écran verrouillé du Store (`lock-*`) s'il l'inclut, ou retirer le plan P6 de Nutrition.
- Kit anglais : les textes de l'app suivent la langue ; les pièces exportées (widgets) dépendent des données de démonstration (noms français éventuels).
