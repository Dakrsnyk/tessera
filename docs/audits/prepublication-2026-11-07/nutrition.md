# Audit 24.N - Nutrition et scanner alimentaire (2026-11-07)

Methode : lecture statique du code (pas de Mac : rien compile ni execute). "A confirmer" = seule une execution tranche.
Perimetre lu : `App/Screens/MiniApps/Nutrition/*`, `App/Screens/Spaces/NutritionSpace.swift`, `Shared/Domains/{Nutrition,ScanRecap,ScanQuota,FoodDatabase,WeightPlan,FoodRepository}.swift`, `App/Core/{NutrientFile,SQLiteFoodRepository,AppModel}.swift`, `Shared/Render/Tiles/NutritionTiles.swift`, `Shared/Intents/SpaceIntents.swift`, `Shared/Support/NotificationEngine.swift`, `Tests/`.

## Synthese

| Gravite | Nombre | Identifiants |
|---|---|---|
| Bloquant | 0 | |
| Majeur | 7 | N-01 a N-07 |
| Mineur | 11 | N-08 a N-18 |
| Amelioration | 2 | N-19, N-20 |

## Constats

### N-01 - Majeur - Les totaux incomplets ne sont marques incomplets que dans le recapitulatif de scan
- Preuve : `NutritionTotals.isIncomplete` (`Shared/Domains/Nutrition.swift:427`) n'est lu qu'a `ScanRecapView.swift:50,138` et `NotificationEngine.swift:379`. Ailleurs, un aliment sans proteines/glucides/lipides (`unknownMacros`, stocke comme 0) s'affiche "0 g" comme une valeur mesuree : jauges du jour `NutritionApp.swift:309-311`, page repas `NutritionPages.swift:28-31` et `:50`, feuille d'ajout `NutritionSpace.swift:469` et `:495-497`, editeur `NutritionPages.swift:202-204`, widgets `NutritionTiles.swift` (`macroRows`, `macros`, `proteinLeft`), Mon Quotidien `DailySection.swift:547-549`. `NutritionMath.stats` (`Nutrition.swift:910`) reconstruit les moyennes sans recopier `isIncomplete`.
- Impact : un yaourt Open Food Facts sans proteines compte 0 g ; le widget "Proteines restantes" annonce 130 g a trouver alors que l'utilisateur en a mange ; l'historique sous-estime. C'est le cas que la demande 8.A-1 voulait eviter (le recapitulatif est bon, le reste non).
- Reproduction : scanner un produit OFF sans `proteins_100g`, l'ajouter, ouvrir la mini-app puis le widget Proteines.
- Correction : ajouter `NutritionMath.isIncomplete(_:on:)` (ou garder le drapeau de `totals`) et l'utiliser partout ou une macro est affichee : prefixe ">=" ou "?" comme `ScanLineRow.macroSummary` (`ScanRecapView.swift:434-442`), mention "incomplet" sous les jauges, pas de "restant" calcule quand la macro est incomplete ; `stats` : `averages.isIncomplete = sum.isIncomplete`.
- Test : logique `NutritionAppTests.testDayTotalsStayIncompleteWithAnUnknownMacro` (entree OFF `unknownMacros=[.protein]` : totals du jour, du repas et `stats().averages` incomplets). UI : capture de la mini-app avec ce produit (pas de "0 g" sec).

### N-02 - Majeur - Fibres (et macros du JSON de repli) absentes remplacees par 0, sans marqueur
- Preuve : `FoodDatabase.swift:501` (fibres : `per100("fiber") ?? 0`), `SQLiteFoodRepository.swift:262` (`values[FoodNutrientCode.fibre] ?? 0`), `NutrientFile.swift:119` (fibres, et `protein/carbs/fat ?? 0` sans `unknownMacros`). `FoodItem.fiber` est un `Double` non optionnel et `MacroField` n'a pas les fibres (`Nutrition.swift:63-65`). `Nutrient.foodPath` rend nil pour `.fiber` (`Nutrition.swift:282`) : la couverture "partiel" ne s'applique jamais aux fibres (`NutritionPages.swift:264`, `NutritionApp.swift:127-129`).
- Impact : "Fibres 0 g" pour un produit qui n'a juste pas la donnee ; les idees "Riches en fibres" (`NutritionPages.swift:398`) partent d'un manque affiche comme 0. Les aliments perso d'un utilisateur gratuit ont fibres = 0 connu (`NutritionSpace.swift:608`, champ reserve a Premium).
- Correction : `fiber: Double?` (decodage tolerant : absent = nil) ou `MacroField.fiber` + `foodPath` pour `.fiber`, et `NutritionTotals.fiber` "inconnu" comme `sugars`.
- Test : logique `testMissingFiberIsUnknownNotZero` (OFF JSON sans `fiber_100g`, ligne SQLite sans code fibre) ; page Nutriments : badge "partiel" pour les fibres.

### N-03 - Majeur - Le quota gratuit de 10 analyses photo se remet a zero
- Preuve : le compteur est `NutritionState.photoScansUsed` (`Nutrition.swift:691`), dans le meme fichier que les repas. "Effacer mes donnees" fait `nutrition = NutritionState()` et `store.remove(.nutrition)` (`AppModel.swift:679-696`) ; la restauration d'une sauvegarde (`DataBackup.swift:88`, `store.decodes(NutritionState.self, data)`) reecrit la valeur de la sauvegarde ; une reinstallation repart de 0. Les autres chemins sont sains : `canAnalyze` verifie avant la prise (`FoodScanView.swift:334`) et avant l'analyse d'une photo choisie (`:367`), le selecteur de photos est remplace par le paywall (`:222-231`).
- Impact : contournement en quelques touches (Effacer mes donnees) : le palier gratuit n'est pas un levier de revenu fiable.
- Reproduction : utiliser 10 analyses, Effacer mes donnees, rouvrir le scanner : "Encore 10 analyses".
- Correction : stocker le compteur hors des donnees effacables (Trousseau, qui survit a la reinstallation, ou cle hors effacement), et a la restauration garder `max(actuel, sauvegarde)`. Decision produit a valider par l'utilisateur (le Trousseau survit a la desinstallation).
- Test : logique `PhotoScanQuotaTests.testCounterSurvivesDataReset` et `testRestoreNeverLowersTheCounter`. La logique pure existante (`Tests/PhotoScanQuotaTests.swift`) reste valable.

### N-04 - Majeur - Les calories "-15 % / +10 %" automatiques ignorent toutes les bornes sures du chantier 15
- Preuve : `NutritionCalculator.goals` (`Nutrition.swift:1061-1063`) applique `goal.rawValue` (-0,15 / +0,10) avec seulement un plancher de 1 400 kcal. `recommendedNutritionGoals` (`AppModel.swift:904-915`) l'appelle des qu'un objectif est choisi (`ProfileTopics.swift:356`) ou meme sans choix : `nutritionGoal` reprend `fitnessGoal.nutritionAim` (`AppModel.swift:1089`, `Profile.swift:190` : `.weightLoss`, `.cut` donnent `.lose`), puis `followCalculatedNutritionGoals` l'applique sans confirmation (`AppModel.swift:880-899`). Les gardes (grossesse/allaitement, mineur, IMC < 18,5, IMC >= 30 en prise, plages age 10-100, taille, poids : `WeightPlanCalculator.evaluate`, `WeightPlan.swift`) ne jouent que si un plan est accepte (`inForceWeightPlanKcal`, `AppModel.swift:927-934`). Sans plan, le calcul simple n'en tient aucun compte.
- Impact : une personne enceinte, mineure ou en insuffisance ponderale qui coche "Perdre doucement" (ou qui a un objectif Fitness "Perte de poids") recoit un deficit de 15 % comme cible du jour. Risque sante et de refus de revue.
- Reproduction : profil femme 16 ans, 160 cm, 45 kg, objectif "Perdre doucement", aucun poids cible : l'objectif kcal est inferieur a la depense.
- Correction : dans `recommendedNutritionGoals`, si l'objectif n'est pas "maintenir", appeler les gardes de `WeightPlanCalculator` (etape de vie, mineur, IMC, plages) et retomber sur `.maintain` avec un message "Ardane ne calcule pas d'objectif de poids dans ta situation" ; borner age, taille, poids dans `NutritionCalculator.goals`. Reutiliser les gardes existantes, pas une deuxieme regle.
- Test : logique `NutritionAppTests.testAutomaticAimNeverCutsForMinorPregnantOrUnderweight` (3 profils : kcal = maintien) ; `testCalculatorRejectsOutOfRangeBody`.

### N-05 - Majeur - Plantage possible sur une quantite enorme, sans plafond de saisie
- Preuve : `Nutrition.swift:862`, dans `previousMeals` : la signature du repas convertit les grammes avec `Int(...)` (une conversion Int(Double) plante hors de +-9,2e18 ou sur NaN/inf). Les saisies de quantite n'ont aucun maximum : `FoodLogSheet` (`NutritionSpace.swift:456-476`, `canSave: grams > 0`), `EntryEditor` (`NutritionPages.swift:191`, le `Stepper` plafonne a 5 000 mais pas le champ), `NutritionState.updateEntry` (`Nutrition.swift:737`, tout `grams > 0`). Seul le recapitulatif borne (`ScanRecap.clamped`, 1 a 5 000). Le code connait pourtant `Int(safely:)` (`Formatting.swift:170`).
- Impact : une entree a 1e19 g est enregistree ; `previousMeals` est appele a chaque ouverture d'une page repas d'un jour posterieur : plantage en boucle. Un "99999" donne aussi des kcal absurdes dans les totaux et les widgets.
- Reproduction (A confirmer : lecture du champ numerique) : ajouter un aliment avec 20 chiffres dans "Quantite", puis ouvrir le repas du lendemain.
- Correction : une seule fonction de bornage (1 a 5 000 g, comme le recapitulatif) dans `NutritionState.log` et `updateEntry`, `canSave` borne dans les deux feuilles, et `Int(safely:)` ligne 862.
- Test : logique `testLoggedGramsAreClamped` (1e19, NaN, -5 : bornes ou refuses) ; `testPreviousMealsSurvivesHugeGrams`.

### N-06 - Majeur - Un aliment perso ne peut ni etre corrige ni supprime
- Preuve : `customFoods` n'est qu'insere (`NutritionSpace.swift:662`) ; aucune autre ecriture dans le code (recherche `customFoods` : lectures seulement). Le scan de code-barres renvoie le premier aliment perso portant ce code (`FoodScanView.swift:299-302`) avant Open Food Facts.
- Impact : une faute de frappe (kcal 5000 au lieu de 500) est definitive ; le produit scanne ressortira toujours faux, sans retour possible a la fiche Open Food Facts.
- Correction : une liste "Mes aliments" (modifier, balayage pour supprimer) ; garder les entrees deja journalisees (copie de l'aliment dans `FoodEntry`).
- Test : logique `testCustomFoodCanBeEditedAndDeleted` ; UI : creer puis supprimer un aliment perso depuis la recherche.

### N-07 - Majeur - Un aliment perso peut etre enregistre a 0 kcal ou avec des valeurs negatives ou aberrantes
- Preuve : `CustomFoodEditor` : `canSave: !name.trimmed.isEmpty` seulement (`NutritionSpace.swift:620`), `kcal/protein/carbs/fat` sont des `Double` initialises a 0 (`:603-606`), `NumberRow` n'accepte aucune borne (`SpaceForms.swift:72-90`). Sur le brouillon d'un produit partiel (`FoodScanView.swift:174-183`, `FoodDatabase.swift:670-671`), un simple "Enregistrer" cree "produit X, 0 kcal, 0 g" lie au code-barres, compte comme connu. Aucun controle kcal ~ 4P + 4G + 9L.
- Impact : entrees a 0 kcal silencieuses qui faussent le total et le prochain scan de ce code.
- Correction : exiger kcal > 0 ou au moins une valeur saisie (champs vides = inconnus : `OptionalNumberRow` existe), refuser < 0, > 900 kcal/100 g, > 100 g/100 g, et avertir si l'energie s'ecarte de plus de 25 % de 4P + 4G + 9L (`FoodEnergyCheck`, `FoodRepository.swift:134-157`).
- Test : logique `testCustomFoodValidation` (0 kcal, negatif, incoherent).

### N-08 - Mineur - Decodage "tout ou rien" des listes de repas
- Preuve : `Nutrition.swift:700` (`entries = c.value(.entries, [])`) ; `value` avale l'erreur et rend un tableau vide (`Helpers.swift:6-8`). `FoodEntry`, `FoodItem`, `SavedMeal.Item` ont un decodage synthetise strict : une seule entree illisible (valeur d'enumeration inconnue apres un retour de version, champ corrompu) vide tout l'historique. Cote app, `AppModel.update` (`AppModel.swift:138-143`) reecrit ensuite le fichier (la protection "fichier illisible" n'existe que dans `SharedStore.update`, `SharedStore.swift:225-232`).
- Impact : perte de l'historique apres une anomalie rare (A confirmer). Les anciennes donnees actuelles se lisent bien (champs ajoutes optionnels ou avec defaut).
- Correction : decoder `entries`, `favorites`, `recentFoods`, `customFoods`, `savedMeals` avec un conteneur "lossy" (elements invalides ignores un a un).
- Test : logique `testOneCorruptEntryKeepsTheOthers` (JSON avec une entree dont le repas est inconnu).

### N-09 - Mineur - Ecriture de la mini-app non atomique face aux widgets
- Preuve : `AppModel.update` copie l'etat en memoire, le modifie, puis `store.save` (`AppModel.swift:138-143`) ; l'ajout rapide des widgets passe par `SharedStore.update` (`SpaceIntents.swift:259-264`). L'etat en memoire n'est relu qu'au passage en actif (`ArdaneApp.swift:56-60`).
- Impact : un ajout rapide fait quand l'app est au premier plan peut etre ecrase par la prochaine ecriture de l'app (A confirmer : cas rare). Concerne aussi `photoScansUsed` (`FoodScanView.swift:382`).
- Correction : faire passer `AppModel.update` par `SharedStore.update` pour `NutritionState`, ou relire avant d'ecrire.
- Test : logique `testWidgetEntryIsNotLostByAnAppWrite`.

### N-10 - Mineur - "Reprendre un repas precedent" : double appui = doublon
- Preuve : `NutritionPages.swift:93-97` : `Button` sans garde ; `NutritionState.log(_ items:...)` (`Nutrition.swift:746-751`) n'applique pas la fenetre anti-double appui (`quickAddWindow` n'existe que dans `quickLog` et `ScanRecap.commit`). Idem `SavedMealLogSheet.save` quand `onDone` est nul (`NutritionSpace.swift:575-582`, A confirmer : `SheetForm` ferme-t-il avant un 2e appui ?). Suppression sans confirmation ni annulation : `NutritionPages.swift:62-64`, `NutritionSpace.swift:75`.
- Impact : un repas enregistre deux fois, sans retour visuel.
- Correction : desactiver le bouton apres appui et afficher un retour "Ajoute".
- Test : UI, double appui sur "Reprendre" : un seul repas.

### N-11 - Mineur - Purge a 400 jours calculee sur la date de l'entree
- Preuve : `Nutrition.swift:715-716` : le seuil est la date de l'entree moins 400 jours, puis `entries.removeAll` sur les dates plus anciennes. Un aliment ajoute a un jour de plus de 400 jours dans le passe est supprime sur-le-champ ; l'historique au-dela disparait sans le dire (l'historique Premium propose "Periode").
- Correction : seuil sur `Date()`, pas de purge lors d'un ajout antidate, et l'ecrire dans la fiche.
- Test : logique `testBackdatedEntryIsNotPurged`.

### N-12 - Mineur - Fuseau horaire : les repas changent de jour quand l'iPhone voyage
- Preuve : `Fmt.timeZone` vaut `.autoupdatingCurrent` (`Formatting.swift:15`) ; `DateMath.dayKey` et `isSameDay` lisent ce fuseau (`DateMath.swift:16-19,111`) ; `FoodEntry.date` est un instant absolu sans jour memorise (`Nutrition.swift:403`).
- Impact : un souper a 21 h a Montreal devient "le lendemain" apres un vol vers l'Europe ; historique, series et moyennes se reecrivent. Un repas a 23 h 59 est bien range dans le jour courant (verifie : `entryDate` = maintenant ; `MealType.current` : collation apres 22 h).
- Correction : memoriser `dayKey` a la creation (champ optionnel, repli sur l'ancien calcul).
- Test : logique `LanguageTimeZoneTests.testEntryKeepsItsDayAcrossTimeZones`.

### N-13 - Mineur - Le jour affiche reste celui du lancement
- Preuve : `NutritionAppView` initialise `@State day` une fois (`NutritionApp.swift:24-29`).
- Impact : app laissee ouverte jusqu'au lendemain : le "+" ajoute a hier (a l'heure fixe du repas, `entryDate`), sans alerte, pendant que le widget affiche le nouveau jour.
- Correction : a l'activation de la scene, si `day` etait "aujourd'hui", le remettre a aujourd'hui.
- Test : logique `testDayFollowsMidnightWhenItWasToday`.

### N-14 - Mineur - Widget "Prochain repas" : cible de proteines non verifiee
- Preuve : `NutritionTiles.make` ne teste que `known.kcal` pour `nextMeal` ; `nextMealBudget` (`Nutrition.swift:829-839`) utilise `state.goals.protein` (130 par defaut) pour "dont X g de proteines". Quand seules les calories ont ete donnees, le chiffre vient du defaut (le reste du fichier applique `known.protein`).
- Correction : n'afficher la ligne proteines que si `known.protein`.
- Test : logique `testNextMealHidesProteinWithoutTarget`.

### N-15 - Mineur - Calories d'Open Food Facts deduites des macros sans l'indiquer
- Preuve : `FoodDatabase.swift:481-485` : a defaut d'energie, les kcal valent 4P + 4G + 9L avec les macros manquantes a 0 ; `item()` (`:472-514`) n'applique aucun controle de plausibilite (negatif, > 900 kcal/100 g, P + G + L > 100 g).
- Impact : une energie "calculee" est presentee comme celle de la fiche ; une valeur communautaire fausse est enregistree telle quelle (le texte "verifie l'etiquette" est affiche, `ScanRecapView.swift:310-311`).
- Correction : marquer l'energie estimee ou rejeter ; traiter les valeurs hors bornes comme un produit `.partial`.
- Test : logique, a ajouter a `OpenFoodFactsV3Tests` : JSON sans energie, JSON a proteines negatives ou 150 g.

### N-16 - Mineur - Reglage "Contribuer a l'amelioration" sans effet
- Preuve : `ScanRecapView.swift:153-163` : le texte dit "cette option ne fait rien tant qu'aucun service n'existe". Honnete, mais un interrupteur sans fonction dans une version publiee risque un refus de revue et pose une question de vie privee.
- Correction : le retirer de l'interface jusqu'a l'existence du service (garder `contributionEnabled` dans les donnees).
- Test : UI, le recapitulatif photo n'expose pas l'interrupteur.

### N-17 - Mineur - Fermeture silencieuse quand rien n'est ajoute
- Preuve : `ScanRecapView.swift:344-360` : si `commit` renvoie 0 (doublon dans les 2 s), `onDone()` ferme comme si c'etait ajoute, sans message.
- Correction : n'appeler `onDone` que si `logged > 0`, sinon message "Deja ajoute a l'instant".
- Test : UI (le test logique du commit a 0 existe peut-etre dans `ScanRecapTests` : a verifier).

### N-18 - Mineur - Code mort et doublons
- `NutrientFile.Legacy` et `cnf-foods.json` toujours livres alors que `ardane-food.sqlite` existe (`NutrientFile.swift:20-23,52-140`) : doublon de logique, avec le defaut de N-02. Le fichier doit disparaitre "une fois la nouvelle base prouvee en CI" : a trancher.
- `NutritionSpaceSections` (`NutritionSpace.swift:5-132`) reproduit la page de la mini-app (totaux, repas, favoris) avec sa propre suppression `entries.removeAll` (`:75`) au lieu de `deleteEntry` : verifier qu'il est atteignable, sinon le supprimer.

### N-19 - Amelioration - Unites : seulement des grammes
- Preuve : `FoodLogSheet` ne propose que g et les pastilles 1/2, 1, 2 portions (`NutritionSpace.swift:521-531`) ; ni saisie en ml ni "1,5 portion" ; les portions et densites de la base (`FoodRepository.portions`, `densities`) ne sont lues par aucun ecran (seule reference : `NutrientFile.swift:34`). Les boissons OFF (par 100 ml) sont traitees comme des grammes.
- Saisie "1,5" : `TextField(value:format:.number.locale(Fmt.locale))` (`SpaceForms.swift:81`, `ScanRecapView.swift:517`) : "1,5" est lu en francais ; "1.5" avec un clavier d'une autre region est A confirmer (la locale du champ suit la langue de l'app, le clavier suit la region).
- Correction : selecteur d'unite (g, ml via densite, portion) ; un champ qui accepte virgule et point.
- Test : logique `testDecimalCommaAndPointBothParse`.

### N-20 - Amelioration - Quantites de la photo : portion usuelle, pas une mesure
- Preuve : `MealPhotoAnalysis.swift` (`modelReading`) : les grammes valent `food.servingGrams` ou l'habitude apprise ; `Scanner/ScannerMass` et `ScannerVolume` ne sont pas branches a l'analyse (22.4 non commencee dans `Demandes.md`). L'interface le dit ("ne sont pas des mesures", fourchette "~ 420-560 kcal", `ScanRecapView.swift:307-309`).
- Note memoire : la case 8.A reste non cochee dans `Demandes.md` alors que ses points 1 a 7 sont dans le code ; a cocher avec la date.

## Reponses aux points demandes

1. Chemins : ajout manuel et recherche (locale + CNF/USDA hors ligne, OFF sur demande, erreurs reseau/occupe/aucun resultat : `NutritionSpace.swift:400-420`), code-barres trouve / introuvable / partiel / hors ligne / occupe (`FoodScanView.swift:137-183`), photo aucune detection / echec / confiance faible en "A confirmer" (`ScanRecap.swift:164-188`), remplacement et suppression de lignes, modification de quantite et de repas (`EntryEditor`), suppression : tous aboutissent a `model.update(\.nutrition)` puis `store.save` (persiste, relu au lancement par `reloadFromDisk`). Reserves : N-05, N-06, N-07, N-10, N-19.
2. Calculs : `nutrients(grams:)` = valeur x grammes / 100 ; sommes par ligne, repas, jour avec les memes fonctions partout (`NutritionMath.totals`) ; pas de division par zero (`max(1, goal)`, `max(count, 1)`) ; la table interne respecte kcal ~ 4P + 4G + 9L (207 aliments verifies par script : seuls biere, vin, spiritueux (alcool, 7 kcal/g) et le mais (ecart 15 kcal) sortent de la tolerance). Valeurs negatives ou enormes : N-05, N-07, N-15.
3. Donnees manquantes : micros, sucres, sodium, cholesterol restent `nil` et les sommes les propagent correctement (`Nutrition.swift:127-136, 432-437`) ; les macros inconnues sont signalees dans le recapitulatif ; le reste de l'app les affiche a 0 (N-01), les fibres sont mises a 0 (N-02). Les `?? 0` examines : `Nutrition.swift:132,435` (un cote inconnu + un connu : resultat connu = minimum, correct), `NutritionPages.swift:328,395,398,638` (comparaisons, sans effet), `NutrientViews.swift:54` (valeur deja verifiee connue), `FoodDatabase.swift:482,498-501` (N-02, N-15), `SQLiteFoodRepository.swift:262` (N-02), `NutrientFile.swift:119` (N-02, N-18).
4. Historique, objectifs, quota : N-03, N-04, N-11, N-12, N-13. Formule Mifflin-St Jeor correcte (`Nutrition.swift:1044`, decalages -161 / +5, moyenne -78) ; proteines plafonnees a 35 % des calories ; glucides >= 0.
5. Persistance : voir 1 ; decodage tolerant des champs ajoutes (`NutritionGoals`, `NutritionState`, `SavedMeal`) correct ; reserve N-08.
6. Widgets et Mon Quotidien : memes fonctions (`NutritionMath.totals` et `entries`, `NutritionTiles`, `DailyBrief.swift:427-434`, `Insights.swift:91,224`), meme jour (`DateMath.isSameDay`). Ecart : N-01, N-14.
7. Boutons sans action : aucun hormis N-16 (interrupteur sans effet). Pas de TODO ni FIXME dans le perimetre. Pas de donnees de demonstration accessibles en Release dans les ecrans lus (ecrans de test sous `#if DEBUG`, `NutritionSpace.swift:727-789`). Textes : les libelles lus passent par `tr()` ; restent en clair seulement des symboles et unites ("g", "kcal").

## Examine et trouve sain

- Quota : `PhotoScanQuota` (pure, bornee, testee) ; comptage seulement quand quelque chose est trouve (`FoodScanView.swift:376-382`) ; paywall sur la galerie et l'obturateur ; codes-barres et recherche jamais limites ; pas de double decompte (un seul `analyze` a la fois via `Stage`).
- Scanner : un seul code-barres par ouverture (`didScan`), `handleBarcode` ignore hors camera, code-barres prioritaire sur la photo, erreurs distinctes (introuvable / hors ligne / occupe 429-503 / partiel), jamais de produit invente ; recherche OFF seulement sur demande, annulation et numero de recherche contre les reponses perimees ; `lookupForms`, `barcodeForms`, UPC-E.
- Recapitulatif : fusion des doublons, bornage 1 a 5 000 g, `canConfirm`, fenetre anti-double appui, confirmation necessaire pour toute proposition peu sure (`autoAddThreshold` 0,80), suggestions huile/beurre/sauce jamais ajoutees seules, apprentissage local borne.
- Persistance et migration : `NutritionState`, `NutritionGoals`, `SavedMeal` decodent avec valeurs par defaut ; `photoScansUsed` >= 0 ; `FoodEntry.origin` optionnel.
- Dates : `entryDate` (maintenant pour aujourd'hui, heure habituelle pour un autre jour), series et semaine ; `nextMealBudget` sans division par zero.
- Objectif de poids : bornes de `WeightPlanCalculator` (planchers, plafonds, mineurs, grossesse, IMC) coherentes et testees (`WeightPlanTests`) ; seule la voie "sans plan" les contourne (N-04).
- Table interne (207 aliments) : energie coherente avec les macros (hors alcool) ; micros et sucres inconnus laisses `nil`.
- Licences : credits OFF (ODbL), FCEN et USDA affiches dans le recapitulatif et sous les resultats.

## Tests a ajouter (liste)

Logique : `testDayTotalsStayIncompleteWithAnUnknownMacro`, `testMissingFiberIsUnknownNotZero`, `testCounterSurvivesDataReset`, `testAutomaticAimNeverCutsForMinorPregnantOrUnderweight`, `testLoggedGramsAreClamped`, `testPreviousMealsSurvivesHugeGrams`, `testCustomFoodCanBeEditedAndDeleted`, `testCustomFoodValidation`, `testOneCorruptEntryKeepsTheOthers`, `testWidgetEntryIsNotLostByAnAppWrite`, `testBackdatedEntryIsNotPurged`, `testEntryKeepsItsDayAcrossTimeZones`, `testDayFollowsMidnightWhenItWasToday`, `testNextMealHidesProteinWithoutTarget`, `testDecimalCommaAndPointBothParse`, OFF sans energie ou hors bornes.
UI : jauge sans "0 g" pour un produit incomplet ; double appui sur "Reprendre" ; suppression d'un aliment perso.
