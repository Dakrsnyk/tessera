# Audit prépublication : inventaire et plan de tests (24.Q, qa-tester, 2026-11-07)

Aucun test écrit ni modifié. Sources : `Tests/` (102 fichiers, 1 244 `func test`), `UITests/` (8 fichiers, 57 tests), `Ardane.xcscheme`, `App/Premium/PremiumStore.swift`, journal complet de la CI du 2026-11-06.

## 0. État de la CI de référence

- L'exécution `[daily]` de référence (run 42409228969, commit 6fad886f) est en échec en 3 secondes, sans aucune étape : le job n'a pas démarré (problème d'infrastructure ou de facturation GitHub, pas un test). `gh run view --log` répond « log not found ». Elle ne donne aucun résultat de test.
- Dernier journal complet disponible : run 42140979318 (`[daily]`, 2026-11-06, build 344). 1 242 tests logiques réussis, 30 tests d'interface réussis, 1 échec. Les lignes « Executed N tests » ne sont pas dans le journal : l'étape filtre avec `grep` sur `Test Case`, `error:` et `TEST`.
- Échec : `ProfileUITests.testAPackOpensInTheStudio` (`UITests/ProfileUITests.swift:334`, « Le widget 2 ne s'ouvre pas »). Chantiers.md note qu'il a été rendu plus solide au build 345, jamais rejoué.
- Le `[daily]` n'exécute que MiniApp, Studio, Profile et Home. `AdShotsUITests`, `PromoVideoUITests`, `WidgetPlacementUITests` et une partie de `DataEntryUITests` ne comptent pas dans cette base.

## 1. Inventaire par domaine (tests logiques)

| Domaine | Fichiers principaux | Tests |
|---|---|---|
| Scanner d'aliments (reconnaissance, masse, volume, confiance, géométrie, mémoire, apprentissage, quota, récap, étiquettes) | Scan*Tests, Scanner*Tests, FoodLabelMatcher, FoodModel*, FoodPhotoRecognition, WeighedMealsEvaluation, PhotoScanQuota | 239 |
| Nutrition hors scanner (calories, plats, dépôt d'aliments, mémoire des repas, Open Food Facts, plan de poids) | CalorieModel, DishTemplates, FoodModelLogic, FoodRepository, MealMemory, NutritionApp, NutritionPremium, OpenFoodFactsV3, WeightPlan, WeightPlanModel | 174 |
| Horaires et Études (analyse OCR, ambiguïtés, import, remplacement, salles, Live Activity) | Schedule*Tests (12 fichiers), StudyLiveActivity | 214 |
| Planning, productivité, habitudes | PlanningLayout/Occurrence/Studies, QuickTask, Top3Completed, WeekSelector, WeekdayRepeat, HabitHeatmap, SmartReminders | 70 |
| Fitness | FitnessApp, Workout{Delete,Skip,Undo}, ExerciseDemo | 44 |
| Finances, Entreprise, Voyage, Auto, placements, Apple Pay | ApplePayExpense (49), BusinessCSV, CurrencyConversion, FinanceStatement, FinancesBusiness/DayBudget/Sync, LivePrices, TravelCar | 125 |
| Mon Quotidien, accueil, mini-apps à remplir | DailyBrief, DailyHome, DailyLayoutRules, Encouragements, QuotidienAndLockScreen, MiniAppToFill, SectionIndex, Reactivity | 92 |
| Widgets, Studio, Store, Premium (offre), thèmes | Studio, StudioColor, Fusion, WidgetGallery, FreeWidgetLimit, AppearanceAndStore, AppTheme/Icon/Palette, AccentedRendering, PremiumTrialOffer, StoreSeason, PhotoQuoteBackground, WallpaperCatalog | 107 |
| Profil, permissions, notifications, réglages, langue | Profile, ProfileMatrix (32), Permission(s), PermissionsSetup, ReviewPromptSmart, SmartNotificationEngine, Tutorial, LanguageTimeZone, Units, RemovedWeather | 121 |
| Noyau et données (catalogue, rendu de chaque widget, anciens formats, sauvegarde) | CoreLogic, DomainLogic, OctoberRequests, DataBackup | 58 |
| Total | | 1 244 |

Tests d'interface (57) : MiniApp 14 (Nutrition, Fitness, Planning, Études, Finances, Entreprise, Voyage, Auto, Mon Quotidien, écran verrouillé), Profile 9, DataEntry 5, Home 4, Studio 4, WidgetPlacement 3, AdShots 9 et PromoVideo 9 (captures, pas des tests de comportement).

Autres éléments vérifiés :
- Le catalogue de traductions `Shared/Localizable.xcstrings` n'est lu par aucun test. Seul `l10n sync` du rapport CI le vérifie.
- Aucun `XCTMetric` ni `measure` : 0 test de performance (les 5 occurrences de `measure` du dossier sont du vocabulaire du scanner).
- Pas d'`SKTestSession`. `PremiumTrialOfferTests` lit `Config/Ardane.storekit` comme un fichier JSON (via `#filePath`) et ne lance aucun achat.

## 2. Couverture par mini-app et fonction (N = nominal, E = erreur, L = cas limite, P = persistance)

Légende : oui, partiel, non.

| Fonction | N | E | L | P | Constat |
|---|---|---|---|---|---|
| Nutrition : journal, repas, totaux | oui | partiel | oui | oui | Bien couvert ; suppression d'un repas testée en UI seulement |
| Nutrition : besoins et plan de poids | oui | oui | oui | oui | 28+17 tests ; anciens formats testés |
| Scanner | oui | oui | oui | oui | Domaine le mieux couvert (239) |
| Fitness : séance, annulation, saut, suppression | oui | partiel | oui | partiel | Séries, records, volume : surtout via l'historique, peu de cas limites de dates |
| Habitudes : série consécutive | oui | non | partiel | non | Un seul test de série (`CoreLogicTests:45`) ; pas de jour manqué, de changement d'heure, de fuseau, d'habitude hebdomadaire |
| Planning : récurrences et exceptions | oui | oui | oui | oui | Bon (11 tests), changement d'heure testé |
| Études / Horaires | oui | oui | oui | oui | Très couvert |
| Budget : calculs, catégories, objectifs | oui | non | partiel | partiel | `testOlderBudgetsOpenWithoutIncomes` ; rien sur montant négatif, 0, très grand, arrondi, devise inconnue |
| Finances : Apple Pay | oui | oui | oui | oui | 49 tests |
| Placements (`PortfolioState`, `Holding`) | partiel | non | non | non | Un seul test (variation du jour, `LivePricesTests:126`) : coût moyen, plus-value, quantité 0 ou négative, cours indisponible non testés |
| Entreprise (KPI, CSV Stripe/Shopify) | oui | partiel | oui | oui | Bon ; devise mixte et période vide à vérifier |
| Sociétés cotées (`Companies`) | partiel | non | non | non | Citations testées, pas de cas d'erreur réseau ou de symbole inconnu |
| Voyage | oui | non | partiel | oui | Conversion de budget : taux absent non testé |
| Auto (`CarState`) | oui | non | partiel | non | 3 tests d'autonomie et distance ; plein partiel, odomètre qui recule, un seul plein non testés |
| Ma vie (`LifeState`) | partiel | non | non | non | Âge et prochain anniversaire seulement ; 29 février, naissance future non testés |
| Mon Quotidien | oui | oui | oui | oui | Bon |
| Widgets : rendu de chaque kind et chaque famille | oui | non | partiel | n/a | `testEveryWidgetRendersItsSampleContent` couvre toutes les familles de `kind.families`, mais avec des données d'exemple seulement : pas de charge vide, pleine ou invalide ; `AccessoryViews` (écran verrouillé) sans test dédié |
| Studio | oui | partiel | oui | oui | Rendu des styles, couleurs, fusion |
| Premium : état mis en cache (`PremiumState`, grâce de 3 jours) | oui | non | partiel | non | Voir ci-dessous |
| Premium : StoreKit (`PremiumStore`) | non | non | non | non | Aucun test du code réel d'achat |
| Mode gratuit | oui | n/a | oui | oui | `FreeWidgetLimitTests` solide ; mais la limite des widgets d'un modèle réel après expiration d'abonnement n'est pas testée |
| Décodage des anciens formats | oui | oui | oui | oui | Budget, Voyage, Planning, Entreprise, Profil, Design, Nutrition ; absent pour Fitness, Habitudes, Auto, Ma vie, Placements |
| Sauvegarde et restauration | oui | oui | partiel | oui | 3 tests ; version plus récente refusée, fichiers volumineux non testés |
| Notifications | partiel | partiel | partiel | non | `SmartNotificationEngine` testé ; planification réelle (`NotificationScheduler`) non testée |
| Permissions | oui | oui | oui | n/a | |
| Double appui et concurrence | partiel | n/a | n/a | n/a | Deux tests (« Apple Pay deux fois », Stripe importé deux fois) ; rien sur deux écritures simultanées de `SharedStore` (app et widget/intent) hormis `testAButtonNeverWritesAnEmptyStateOverAFileItCantRead` |
| Traductions (clés manquantes, `%@` cohérents) | non | non | non | n/a | Hors tests |
| Performance (lancement, mémoire) | non | non | non | n/a | Aucune mesure |

### Premium et StoreKit en détail

1. `PremiumStore.purchase`, `restore`, `refreshEntitlements`, `loadProducts` ne sont exécutés par aucun test (`App/Premium/PremiumStore.swift:55`, `66`, `107`, `132`). Les cas « remboursement » (`revocationDate`, ligne 133), « abonnement expiré » (ligne 143) et « achat à vie » (ligne 138) sont du code de production sans filet.
2. Aucun `SKTestSession` dans `Tests/` ni `UITests/` (recherche sur `SKTestSession` : 0 résultat).
3. `Config/Ardane.storekit` est attaché à la `LaunchAction` du schéma (`Ardane.xcscheme:77`), pas à la `TestAction` (lignes 26 à 56 : aucune référence StoreKit). Un `xcodebuild test` n'utilise donc pas cette configuration. Pour un test logique, la solution est de créer la session en code avec `SKTestSession(contentsOf:)` sur le chemin construit depuis `#filePath` (même méthode que `PremiumTrialOfferTests`) ; pour un test d'interface, ajouter la référence à la `TestAction` (modification du schéma : hors du dossier `Tests/`, à demander au Chef).
4. Le Premium DEBUG (`DebugPremium.isUnlocked`) peut masquer un défaut dans les tests Debug : tout test du mode gratuit doit forcer l'état (comme `testPurchaseStateWithoutDebugUnlock`).

## 3. Échecs connus (journal du 2026-11-06, run 42140979318)

| Tâche | Test | État dans le dernier journal complet |
|---|---|---|
| 6.A | `ProfileUITests.testEachWidgetOfACombinedWidgetCanBeSet` | réussi (51,9 s) |
| 6.A / 7.A | `ProfileUITests.testFirstLaunchAsksOnlyWhatMattersAndFillsMesInformations` | réussi (164 s) |
| 7.B | `StudioUITests.testWidgetsMadeTogetherShareTheirLook` | réussi (65 s) |

Les trois ne échouent plus dans ce journal. Mais le journal date du build 344 ; le run de référence du jour n'a pas tourné (voir section 0). Nouvel échec constaté : `testAPackOpensInTheStudio`. Il n'est pas dans `Demandes.md`. Conclusion non définitive : les trois passent, mais seule une exécution `[daily]` sur le commit actuel le prouvera, et elle devra être relancée à cause de l'échec d'infrastructure.

## 4. Plan de tests priorisé

Priorités : P0 avant publication, P1 ensuite, P2 souhaitable. Type : L = logique (`Tests/`), UI = `UITests/`. Aucun test factice : chacun appelle le vrai code cité.

### P0 (13 tests)

| # | Nom | Fichier | Type | Ce qu'il vérifie |
|---|---|---|---|---|
| 1 | `testPurchaseOfTheMonthlyGrantsPremium` | `Tests/PremiumStoreKitTests.swift` (nouveau) | L | `SKTestSession` sur `Config/Ardane.storekit`, `PremiumStore.purchase(monthly)` renvoie `.success`, `model.isPremium` vrai, `PremiumState` écrit dans un `SharedStore` temporaire avec `productID` et date d'expiration |
| 2 | `testLifetimePurchaseHasNoExpiration` | idem | L | Achat à vie : `expirationDate` nil, `isActive` vrai |
| 3 | `testRefundRevokesPremium` | idem | L | `session.refundTransaction(...)` puis `refreshEntitlements()` : `isActive` faux (`revocationDate`) |
| 4 | `testExpiredSubscriptionEndsPremiumAfterGrace` | idem | L | `session.expireSubscription` ou `forceRenewalOfSubscription` ; `isActive` faux et `hasPurchase` faux une fois la grâce de 3 jours passée |
| 5 | `testRestoreFindsAnExistingPurchaseAndSaysNothingWhenThereIsNone` | idem | L | `restore()` : `.restored` avec achat, `.notFound` sans |
| 6 | `testPurchaseFailureAndCancellationAreReported` | idem | L | `session.failTransactionsEnabled` renvoie `.failed` ; achat annulé renvoie `.cancelled` ; `purchasingID` revient à nil |
| 7 | `testTrialEligibilityIsOnlyOnceForTheGroup` | idem | L | `isIntroEligible` vrai avant l'essai, faux après un premier abonnement (`resetToDefaultState`) |
| 8 | `testRevokedOrExpiredPremiumReturnsToTheFreeLimit` | `Tests/FreeWidgetLimitTests.swift` (ajout) | L | Après expiration, un modèle avec plus de 3 widgets garde ses widgets mais n'en ajoute pas (règle « qui en a plus les garde ») et les styles Premium sont rétrogradés |
| 9 | `testHabitStreakBreaksOnAMissedDayAndSurvivesTimeChangeAndTimezone` | `Tests/CoreLogicTests.swift` (ajout) ou nouveau `HabitStreakTests.swift` | L | Série interrompue par un jour manqué ; jour du changement d'heure ; fuseau différent ; aujourd'hui non fait ne casse pas la série |
| 10 | `testPortfolioGainCostBasisAndMissingPrice` | `Tests/PortfolioTests.swift` (nouveau) | L | Plus-value, coût moyen, quantité 0, cours indisponible (aucun chiffre inventé), encodage et décodage de `PortfolioState` |
| 11 | `testBudgetAmountsAtTheLimits` | `Tests/FinancesBusinessTests.swift` (ajout) | L | Montant 0, négatif, très grand, arrondi à deux décimales, catégorie inconnue : pas de plantage, totaux exacts |
| 12 | `testEveryWidgetRendersWithEmptyAndWithMissingPayload` | `Tests/DomainLogicTests.swift` (ajout) | L | Pour chaque kind et chaque famille (dont `accessory*`), `TileFactory.make` avec un payload vide ou absent : pas de plantage, `tile.empty` renseigné, jamais de chiffre inventé |
| 13 | `testTwoWritersOfTheSameStateDoNotLoseData` | `Tests/OctoberRequestsTests.swift` (ajout) ou `SharedStoreConcurrencyTests.swift` | L | Deux écritures concurrentes (app et intent) sur le même `SharedStore` : l'état final contient les deux changements ou le cas est détecté ; la sauvegarde d'un état vide ne remplace jamais un fichier illisible |

### P1

| # | Nom | Fichier | Type | Ce qu'il vérifie |
|---|---|---|---|---|
| 14 | `testLoadProductsReturnsThreeProductsWithPrices` et `testLoadProductsFailureShowsAMessage` | `PremiumStoreKitTests.swift` | L | `loadProducts()` : 3 produits dans l'ordre de `allProductIDs` ; `failTransactionsEnabled` ou liste vide donne `.failed` |
| 15 | `testPremiumSurvivesRelaunch` | idem | L | Achat, nouvelle instance de `AppModel` sur le même dossier : Premium toujours actif sans réseau |
| 16 | `testPaywallPurchaseFlowWithStoreKitConfiguration` | `UITests/PremiumUITests.swift` (nouveau) | UI | Exige l'ajout de `Config/Ardane.storekit` à la `TestAction` du schéma (hors `Tests/` : à demander au Chef). Ouvrir le paywall, voir les 3 offres, acheter (la feuille de test de StoreKit), contenu Premium débloqué |
| 17 | `testCarOddometerGoingBackAndSingleFillUp` | `Tests/TravelCarTests.swift` (ajout) | L | Autonomie : un seul plein, plein partiel, kilométrage qui recule, consommation 0 |
| 18 | `testLifeStateEdgeDatesAndOldFormat` | `Tests/DomainLogicTests.swift` (ajout) | L | Naissance un 29 février, naissance future, ancien JSON de `LifeState` |
| 19 | `testOldFitnessHabitsCarPortfolioStatesStillDecode` | `Tests/OldFormatsTests.swift` (nouveau) | L | Un JSON minimal de chaque ancien format (champs manquants) décode avec valeurs par défaut |
| 20 | `testDeletingAMealWorkoutHabitAndBudgetEntryKeepsTheRestAndPersists` | `Tests/CrudPersistenceTests.swift` (nouveau) | L | Pour chaque mini-app sans test de suppression (Habitudes, Budget, Auto, Voyage, Entreprise) : créer, modifier, supprimer, recharger depuis un `SharedStore` temporaire |
| 21 | `testNotificationSchedulerBuildsTheExpectedRequests` | `Tests/SmartNotificationEngineTests.swift` (ajout) | L | `NotificationScheduler` : une requête par rappel, aucune sans permission, annulation à la suppression |
| 22 | `testLaunchPerformance` | `UITests/PerformanceUITests.swift` (nouveau) | UI | `XCTApplicationLaunchMetric` (lancement à froid, 5 itérations). Sur simulateur : sans base de référence, il enregistre des durées sans échouer ; garde-fou : `XCTAssertLessThan` en secondes très larges (par exemple 10 s) pour éviter un échec par bruit |
| 23 | `testMemoryAfterOpeningEveryMiniApp` | `UITests/PerformanceUITests.swift` | UI | `XCTMemoryMetric(application:)` et `XCTClockMetric` pendant un parcours des 9 mini-apps ; relève la mémoire de pointe, sans seuil de réussite au départ |
| 24 | `testTranslationCatalogHasEverySourceKeyInEveryLanguage` | `Tests/LocalizationCatalogTests.swift` (nouveau) | L | Lit `Shared/Localizable.xcstrings` (`#filePath`) : chaque clé a en, es, de, it, pt-BR, ja ; les marqueurs `%@` et `%1$@` sont les mêmes que dans la source |
| 25 | `testBackupRefusesANewerVersionAndKeepsCurrentDataOnFailure` | `Tests/DataBackupTests.swift` (ajout) | L | Version plus récente refusée ; échec en cours de restauration ne perd pas les données actuelles |

### P2

| # | Nom | Fichier | Type | Ce qu'il vérifie |
|---|---|---|---|---|
| 26 | `testPerformanceOfRenderingEveryWidgetKind` | `Tests/StudioTests.swift` (ajout) | L | `measure {}` sur le rendu de tous les kinds à `scale 1` ; sert de repère de régression, sans seuil |
| 27 | `testPerformanceOfDecodingALargeBudgetAndNutritionHistory` | `Tests/PerformanceTests.swift` (nouveau) | L | `measure {}` : décoder 5 ans de données (génération depuis les vrais types) ; détecte une dérive de temps de démarrage |
| 28 | `testPurchaseWhileOfflineKeepsTheLastKnownStatus` | `PremiumStoreKitTests.swift` | L | `SKTestSession` avec `askToBuyEnabled` (état `.pending`) et statut mis en cache |
| 29 | `testCompaniesUnknownSymbolAndNetworkFailure` | `Tests/LivePricesTests.swift` (ajout) | L | Symbole inconnu, réponse invalide : l'erreur est typée, aucun cours inventé |
| 30 | `testRestorePurchasesFromSettingsOpensTheRightMessage` | `UITests/PremiumUITests.swift` | UI | Réglages › Restaurer : message selon `PremiumStore.message(for:)` |

### Faisabilité sur le simulateur de la CI

- `SKTestSession` : utilisable dans les tests logiques d'un simulateur (Xcode 14 et suivants) ; créer la session dans `setUp` avec `resetToDefaultState()`, `clearTransactions()` et `disableDialogs = true`. Risque : `Transaction.updates` a besoin d'un compte de test StoreKit, donc un test peut être instable lors du premier lancement sur la CI. À valider par un premier `[unit]` avec seulement ce fichier.
- Les tests d'interface avec StoreKit exigent la référence dans la `TestAction` du schéma : une modification de `Ardane.xcscheme`, que je ne suis pas autorisé à faire. À arbitrer par le Chef.
- Lancement et mémoire : `XCTApplicationLaunchMetric` et `XCTMemoryMetric` fonctionnent sur simulateur mais les valeurs sont bruitées (machine partagée) : utiles comme historique, pas comme barrière.

## 5. Les 8 trous les plus graves

1. Aucun test du code réel d'achat, de restauration, de remboursement et d'expiration (`PremiumStore`) : c'est la source de revenu de l'app.
2. `Ardane.storekit` non attaché à la `TestAction` ; pas d'`SKTestSession`.
3. Aucune mesure de performance (lancement, mémoire).
4. Séries d'habitudes : un seul test, sans jour manqué ni changement d'heure ou de fuseau.
5. Placements (`PortfolioState`) : un seul test ; plus-values et cours manquant non couverts. Chiffres affichés à l'utilisateur.
6. Calculs du Budget : aucun cas d'erreur ni de bornes (0, négatif, très grand, arrondi).
7. Widgets : le rendu n'est vérifié qu'avec des données d'exemple ; aucun cas de charge vide ou invalide, ni dédié aux familles d'écran verrouillé.
8. Anciens formats absents pour Fitness, Habitudes, Auto, Ma vie, Placements ; en plus, aucune vérification du catalogue de traductions dans les tests.

Autre point : le `[daily]` de référence n'a pas tourné (échec d'infrastructure, 3 s), et `testAPackOpensInTheStudio` échoue encore dans le dernier journal complet.

## 6. Tests P0 écrits (2026-11-07, après feu vert du Chef)

Rien n'a été compilé ni exécuté (pas de Mac, CI bloquée). `python3 scripts/check_swift.py` : OK. `Tests/` est un `PBXFileSystemSynchronizedRootGroup` sans exception : les nouveaux fichiers rejoignent la cible seuls. 46 tests dans 7 nouveaux fichiers, aucun fichier existant modifié.

| Fichier | Tests | Ce qu'ils vérifient | État attendu |
|---|---|---|---|
| `Tests/PremiumStoreKitTests.swift` (P0 1 à 7) | 9 | `SKTestSession(contentsOf:)` sur `Config/Ardane.storekit`, `PremiumStore` réel : 3 offres chargées dans l'ordre ; achat mensuel (état dans `AppModel.premium` et relu dans le fichier) ; achat à vie sans expiration ; remboursement ; expiration + grâce de 3 jours ; restauration avec achat ; restauration sans achat (`.notFound`) ; échec d'achat (`failTransactionsEnabled`) ; essai offert une seule fois (`isIntroEligible`) | réussite, sous réserve des risques StoreKit ci-dessous |
| `Tests/PremiumLapseTests.swift` (P0 8) | 3 | Après fin de Premium : widgets conservés, plus d'ajout au-delà de 3, photos et citations libres, styles Premium gardés dans le fichier mais rétrogradés à l'affichage ; cache « actif » expiré hors grâce | réussite |
| `Tests/HabitStreakTests.swift` (P0 9) | 8 | Jour manqué, aujourd'hui non fait, changements d'heure (5 mars au 2 avril), nouvel an, bascule d'un jour, clés illisibles, relecture, journal borné à 400 | réussite |
| `Tests/PortfolioTests.swift` (P0 10) | 8 | Plus-value et perte, prix manuel puis coût, position vide sans division par zéro, liquidités, répartition, enregistrement et relecture, ancien format et champs illisibles | réussite |
| `Tests/BudgetBoundsTests.swift` (P0 11) | 11 | Budget vide, montant 0, budget 0, montants énormes, catégorie inconnue, catégorie sans limite, limites de mois et année bissextile, minuit du 1er (dépense et revenu), facture du 31, objectif d'épargne | 9 réussites, **2 échecs attendus** (défaut réel) |
| `Tests/WidgetEmptyDataTests.swift` (P0 12) | 2 | Chaque kind dans chaque famille (écran verrouillé compris) avec un payload vide : tuile construite, titre non vide, aucun « NaN » ni « ∞ » ; la vue se dessine (`ImageRenderer`) | réussite |
| `Tests/SharedStoreConcurrencyTests.swift` (P0 13) | 5 | 100 `update` concurrents sans perte ; deux domaines en parallèle ; deux `SharedStore` sur le même dossier ; fichier illisible jamais remplacé ; fichier abîmé laissé tel quel | 4 réussites, **1 échec attendu** (à arbitrer) |

### Échecs attendus (défauts suspectés, attentes non affaiblies)

1. `BudgetBoundsTests.testAnExpenseAtMidnightOfTheFirstCountsInTheNewMonthOnly` et `testAnIncomeAtMidnightOfTheFirstCountsInTheNewMonthOnly`. Cause : `BudgetMath.expenses` (`Shared/Domains/Budget.swift:352`) et `incomes` (ligne 546) filtrent avec `interval.contains(date)`. `DateInterval.contains` est fermé aux deux bouts : une dépense ou un revenu daté exactement à 00:00 le 1er est compté dans le mois qui finit et dans celui qui commence (`months`, `spentThisMonth`, `byCategory`). Une date sans heure (saisie par jour, import) vaut minuit. Correction possible : `date >= interval.start && date < interval.end`.
2. `SharedStoreConcurrencyTests.testAnUpdateLeavesADamagedFileAsItIs`. Cause : `SharedStore.isUnreadable` (`Shared/Support/SharedStore.swift:150`) ne teste que la lecture des octets, alors que son commentaire (ligne 146) annonce « can't be read or decoded ». Un fichier JSON abîmé est lu, `state()` renvoie l'état par défaut, et `update` le réécrit avec une seule modification : les octets abîmés sont perdus. À arbitrer : si le choix est de réparer par écrasement, supprimer ce test et corriger le commentaire.

### Risques de compilation et d'exécution (à lever en CI)

- `import StoreKitTest` : le framework doit se lier tout seul à la cible `ArdaneTests` ; sinon erreur d'édition de liens.
- Signatures StoreKitTest écrites de mémoire : `refundTransaction(_:)` et `expireSubscription(productIdentifier:)` sont appelés avec `try await` (accepté qu'ils soient synchrones ou asynchrones, au pire un avertissement) ; `failTransactionsEnabled`, `disableDialogs`, `resetToDefaultState()`, `clearTransactions()` sont supposés synchrones.
- Comportement StoreKit sur simulateur CI, non vérifié : `AppStore.sync()` dans `testRestoreWithoutAnyPurchaseSaysNothingWasFound` (si l'appel échoue, `restore()` renvoie `.failed` au lieu de `.notFound`), la forme du remboursement (`revocationDate` ou retrait de `currentEntitlements`, les deux sont gérés), l'échec d'achat (supposé lever une erreur, donc `.failed`), et l'éligibilité à l'essai après achat.
- Les tests StoreKit forcent `DebugPremium.setUnlocked(false)` (restauré ensuite), sinon `isPremium` est vrai en Debug et `restore()` répond toujours `.restored`.
- `testEveryWidgetDrawsWithoutAnyData` fait environ 250 rendus `ImageRenderer` : durée à surveiller.
- Non couverts : annulation par la personne et achat en attente (`.cancelled`, `.pending`), qui exigent l'interface de la feuille d'achat.
