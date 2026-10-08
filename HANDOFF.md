# État de Tessera (mis à jour le 2026-10-08)

## Localisation — terminée
Français (source) + en, es, de, it, pt-BR, ja. Chinois et coréen retirés (récupérables avant 5ee621c).
`l10n_catalog.py extract|merge|build|check|sync`, lots `l10n/parts/NN.<langue>.json` (01–21), `tr("mot", context: "x")` pour les mots à double sens. Tag `[langs]` = captures des écrans clés dans les 6 langues.

## Améliorations du 2026-10-08 (demande en 21 points)
Abandonnés à la demande de l'utilisateur : iPad, Apple Watch.

Fait :
- Scan code-barres : jamais d'écran vide (formes UPC/EAN, calories en kJ / par portion / depuis les macros, fiche incomplète → aliment perso prérempli, introuvable / hors ligne → message + « Créer cet aliment »).
- Séance : une seule source de vérité (notification `workoutSavedOutside` quand l'écran verrouillé change la séance), activité en direct redessinée à la fin du repos, aux couleurs / police du style (AppStyle est dans Shared).
- Navigation par jour (`DaySwitcher` : précédent / suivant / calendrier / aujourd'hui) : Nutrition, Planning, Tâches, Habitudes (2 écrans), Fitness.
- Flèche « ‹ Retour » sur une tâche ou une habitude existante (`BackArrowButton`, `SheetForm.closesWithBackArrow`).
- Accueil fixe : `DailyPager` change de vue sur un balayage franc, sans suivre le doigt.
- Base alimentaire : Fichier canadien sur les éléments nutritifs (5 596 aliments fr/en, `scripts/cnf_build.py` → `App/Resources/cnf-foods.json`, `NutrientFile`), Open Food Facts lancé automatiquement si peu de résultats.
- Photo du repas : Vision d'Apple sur l'iPhone (pas d'IA en ligne, choix de l'utilisateur) → aliments candidats → quantités et macros estimées (≈) → correction → « Ajouter au journal ».
- Mon Quotidien : Nutrition puis séance du jour en tête ; invitations limitées ; bouton de disposition sous « Mes données » (ordre, ½ / Large, masquer ; `AppSettings.dailyOrder/dailyHidden/dailyWide`).
- Fond : `screenGradient` (dégradé discret calculé depuis le style).
- Store : « À découvrir cette semaine » (`TemplateCatalog.weeklyPick`, tirage par semaine ISO).
- Personnages des démonstrations : +12 % corps / +18 % muscles au rendu (`DemoRenderer.bodyBulk`). Ne pas régénérer `ExerciseDemos.json` sur Windows sans vérifier : l'export local ne reproduit pas le fichier du dépôt (et écrit en cp1252 sans `PYTHONUTF8=1`).

## Outils
- Hook `.git/hooks/pre-commit` : check_swift.py + `l10n_catalog.py sync` (bloque un texte non traduit).
- `bash scripts/ci_report.sh [run]` : attend la CI et n'affiche que statuts, tests échoués, erreurs, l10n.

## Tests instables connus (non liés aux changements, à surveiller)
`ProfileUITests.testAPackOpensInTheStudio` (run 108) et `StudioUITests.testTheStudioChangesTheWidgetAndKeepsItAll` (run 113) : un toucher sur une puce du Studio parfois non pris en compte. Piste : second essai comme dans e940e31.

## Ensuite
Compte Apple Developer, TestFlight signé via GitHub Actions, fiche App Store + politique de confidentialité (PRIVACY.md existe, à compléter pour la photo du repas : analysée sur l'iPhone, rien n'est envoyé), marketing. Repasser le dépôt en privé.
