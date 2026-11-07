# Revue indépendante : Nutrition, Fitness/données/Planning (2026-11-07)

Lecture statique seulement ; `python3 scripts/check_swift.py` : OK. Rien n'est compilé : seule la CI le prouve.

## Verdicts
- Nutrition (N-01, 02, 05, 06, 07, 10, 13, 17, P-04) : à corriger (1 point bloquant de localisation).
- Fitness, données, Planning (F-02 à F-12) : à corriger (1 point).

## À corriger avant fusion
1. `App/Screens/MiniApps/Nutrition/NutritionApp.swift` (nutrientsRow, `tr("Fibres \(fiberText)\(sugars)\(sodium)")`) : la clé devient `Fibres %@%@%@`, absente du catalogue (l'ancienne `Fibres %@ g%@%@` existe) : texte non traduit dans les 5 langues. Correctif : garder `tr("Fibres \(marqueur + TF.int(fiber)) g\(sugars)\(sodium)")`.
2. `Shared/Render/Tiles/NutritionTiles.swift` (proteinLeft, ~l.147-168) : `tr("\(mark)\(TF.int(left)) g de protéines restantes")` et `…aujourd'hui` changent de clé (`%@%@ g…`, absente). Correctif : `tr("\(mark + TF.int(left)) g de protéines restantes")` (clé `%@ g…` conservée).
3. `Shared/Render/Tiles/FitnessTiles.swift:56,71,102,124` (et `activeHasNoSets` Fitness.swift:454) : les widgets Fitness n'appliquent pas `isIdle`. Une séance abandonnée reste « en cours » dans les widgets alors que l'app, la Live Activity et DailyBrief l'ignorent. Correctif : `state.active.flatMap { $0.isFinished || $0.isIdle(at: now) ? nil : $0 }` (skipButton reçoit `now`).

## Souhaitable
- Textes nouveaux absents de `Localizable.xcstrings` : Mes aliments, Déjà ajouté à l'instant, Enregistrer quand même ?, Voir la fiche Open Food Facts, messages de CustomFoodEditForm, Repos terminé, Prêt pour la prochaine série., Supprimer cette séance du programme ?, Supprimer toute la série ?, Supprimer ce cours ?, `J-%lld`. Lancer extract/merge/build/sync.
- `WorkoutLiveActivity.swift` RestNotifier.schedule : course possible entre `await notificationSettings()` et un `cancel()` d'un sync concurrent (alerte d'un repos passé). Revérifier `restEndsAt` après l'await.
- `FitnessSession.swift` signalRestEnd : si l'app revient au premier plan après la fin du repos, le haptique part en retard. Tester `rest.timeIntervalSinceNow > -2` après le sleep.
- `NutritionPages.swift` (resumedMeals) : le garde-fou bloque définitivement sans retour visuel ; ajouter `.disabled(resumedMeals.contains(past.id))`.
- Marqueur « ≥ » appliqué aux trois macros même si une seule est inconnue (`isIncomplete` global) ; MacroGauge sans `minimumScaleFactor` (troncature possible).
- N-02 partiel : un aliment perso (Premium requis pour les fibres) garde fibres = 0 « connu » (`CustomFoodEditor.commit`).

## Vérifié sans reproche
- F-06 : CodingKeys complètes, formats encodés identiques, champs absents tolérés, `Habit` init explicite aux mêmes labels/défauts, `adCourseColors` intact.
- Inactivité : sets conservés, durée = dernier pas, Live Activity et DailyBrief cohérents ; `press` et `completeNextSet` ferment d'abord.
- Notification de repos : id fixe (pas de doublon), annulée si pause/skip/fin, permission respectée, bannière de premier plan supprimée par NotificationPresenter.
- Validation des aliments perso : 0 kcal = confirmation (eau ok), seuls négatif/NaN/hors bornes bloquent.
- Tests : exercent le vrai code, sans état global.
