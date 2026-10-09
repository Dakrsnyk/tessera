# État de Tessera (mis à jour le 2026-10-09)

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
- Photo du repas : retirée le 2026-10-09 à la demande de l'utilisateur (récupérable avant 54d2373). Le scan de code-barres a un carré de visée (`ScanFrame`).
- Mon Quotidien : Nutrition puis séance du jour en tête ; invitations limitées ; bouton de disposition sous « Mes données » (ordre, ½ / Large, masquer ; `AppSettings.dailyOrder/dailyHidden/dailyWide`).
- Fond : `screenGradient` (dégradé discret calculé depuis le style).
- Store : « À découvrir cette semaine » (`TemplateCatalog.weeklyPick`, tirage par semaine ISO).
- Personnages des démonstrations : +12 % corps / +18 % muscles au rendu (`DemoRenderer.bodyBulk`). Ne pas régénérer `ExerciseDemos.json` sur Windows sans vérifier : l'export local ne reproduit pas le fichier du dépôt (et écrit en cp1252 sans `PYTHONUTF8=1`).

## App Store (2026-10-09)
- Manifeste de confidentialité `Shared/PrivacyInfo.xcprivacy` (copié dans l'app et l'extension) : UserDefaults (CA92.1, 1C8F.1), horodatage de fichier (C617.1). `check_swift.py` refuse une API « required reason » non déclarée ; le rapport CI affiche `privacy manifest: app yes, widget yes`.
- Politique : PRIVACY.md et la page en ligne (`PremiumConfiguration.privacyURL`, artifact claude.ai, à partager « toute personne disposant du lien » avant la soumission).
- Captures : `[marketing]` rend les scènes de `scripts/marketing_scenes.txt` (ordre de la page, `pano-<nom>-1/2` = une image sur deux captures, 2e colonne = vrai écran dans le téléphone), en français (`MARKETING_LANG`/`MARKETING_LOCALE` pour une autre langue). Assemblage : `python3 scripts/marketing_compose.py /tmp/rNNN/marketing <sortie>` → `NN-scene.png` 1320 × 2868 + `contact-sheet.jpg`.

## Icône de l'app (2026-10-09)
- Par défaut : « Classique » (AppIcon). 16 icônes en verre au choix, dont Verre rouge (AppIcon-<Nom>.appiconset, compilées comme icônes alternatives : `ASSETCATALOG_COMPILER_INCLUDE_ALL_APPICON_ASSETS`), vignettes `IconPreviews/IconPreview-<Nom>`. Toutes restent claires en mode sombre (l'image claire est aussi dans l'emplacement « dark ») ; version teintée conservée.
- Choix : Profil → « Icône de l'app », ou appui long sur l'icône → « Changer d'icône » (raccourci dynamique `QuickActions`, reçu par `TesseraAppDelegate` / `TesseraSceneDelegate`). Liste dans `AppIconChoice.all` (check_swift.py vérifie les assets).
- Dessin : `node scripts/app_icons.js <dossier>` (Playwright + Chromium) puis `python3 scripts/app_icons_install.py <dossier>`. `TesseraMark` dessine le logo Classique dans l'app.

## Outils
- Hook `.git/hooks/pre-commit` : check_swift.py + `l10n_catalog.py sync` (bloque un texte non traduit).
- `bash scripts/ci_report.sh [run]` : attend la CI et n'affiche que statuts, tests échoués, erreurs, l10n.

## Tests instables connus (non liés aux changements, à surveiller)
`ProfileUITests.testAPackOpensInTheStudio` (run 108) et `StudioUITests.testTheStudioChangesTheWidgetAndKeepsItAll` (run 113) : un toucher sur une puce du Studio parfois non pris en compte. Piste : second essai comme dans e940e31.

## Ensuite
Compte Apple Developer, TestFlight signé via GitHub Actions, fiche App Store (textes, choix des captures), marketing. Repasser le dépôt en privé.
