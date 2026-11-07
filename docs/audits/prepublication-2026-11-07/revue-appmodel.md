# Revue indépendante 24.C-A2 (AppModel, limites, réinitialisation, nutrition, styles, photos)

Rien n'a été compilé (pas de Mac). `python3 scripts/check_swift.py` : OK.

## Verdict
À corriger avant fusion : 1 point. Le reste est correct à la lecture.

## À corriger avant fusion
1. App/Core/AppModel.swift:959-972 (`followCalculatedNutritionGoals`) : écrit `nutrition.goals = goals; store.save(nutrition)` depuis la
   MÉMOIRE, sans passer par `update`. Un ajout rapide fait par le widget depuis la dernière lecture est donc écrasé : c'est la
   course N-09 que `update` vient de fermer, et cette fonction est appelée à chaque changement de profil, de fitness ou de vie.
   Correctif : `update(\.nutrition) { $0.goals = goals }` (pas de récursion : `NutritionState` n'est pas dans la liste de
   suivi de `update`), en gardant la comparaison `goals != nutrition.goals` avant.

## Souhaitable
- Tests/Audit24AppModelTests.swift : aucun test de N-09 (`AppModel.update(\.nutrition)` qui repart du fichier : écrire par
  `store.update(NutritionState.self)` puis `model.update(\.nutrition)` et vérifier que l'entrée du widget survit) ni du fichier
  abîmé (mémoire gardée, copie dans Recovery). Ajouter les deux.
- Tests/Audit24AppModelTests.swift:11-37 : `setUp`/`tearDown` ne rétablissent pas `PersonalFoodMemoryStore` (vidé par
  `resetAllData`, dossier réel), l'icône, `NotificationLog`/`EncouragementLog`. Le test de réinitialisation vide la mémoire
  visuelle du scanner du simulateur : un test d'un autre fichier qui s'y appuie dépend de l'ordre. Sauvegarder/restaurer le
  fichier, ou n'appeler `resetAllData` que si le store est isolé.
- App/Core/AppModel.swift:750 : clés `"miniAppOpens"`/`"miniAppsHidden"` recopiées en dur (privées dans MiniAppsRow.swift:5,17).
  Exposer les clés pour éviter qu'un renommage casse la réinitialisation en silence.
- Hors des chemins d'ajout : `DataBackup.restore` et le retour d'un abonnement expiré peuvent laisser plus de 5 habitudes en
  gratuit. Acceptable (ce n'est pas un ajout), à décider.
- App/Core/AppModel.swift:428 : `needsPremium(_:)` n'est utilisé que par les tests.
- Nutrition hors plage (âge <10 ou >100, taille, poids) : `recommendedNutritionGoals` renvoie nil, comme « données
  manquantes » ; aucun plantage, mais l'écran ne dit pas que la donnée est refusée et `follow…` laisse les anciens objectifs.

## Critères
1. Quota : conservé (AppModel.swift reset ; DataBackup.swift:65-79, max des deux) ✔
2. Réinitialisation : styles, pas, ouvertures, favoris, icône, photos orphelines ajoutés ; Premium et quota gardés ✔
3. Habitudes : `addHabit` unique ; chemins vérifiés (HabitsView, Planning, DataItemViews, ProfileTopics) ; aucun App Intent
   ni autre `habits.append` hors ScreenshotMode ✔
4. Nutrition : bornes identiques à `WeightPlanCalculator` (plages, IMC, étapes de vie, plancher 1500/1200 ≥80 % repos) ;
   adulte ordinaire inchangé (tests existants OctoberRequests restent cohérents) ✔ ; hors plage : nil, voir ci-dessus
5. Styles : tout ou rien dans `applyOrAskPremium`, paywall `.designs` ✔
6. Photos : `deleteImages(of:keeping:)` garde toute image encore référencée (fond, photos, parties) ; `delete` d'un fichier
   absent sans erreur (`try?`) ✔ ; les styles enregistrés ne gardent jamais de photo (WidgetStyle.swift:754)
7. N-09 : `update` repart du fichier pour `NutritionState` ; lecture nil → mémoire gardée ; Encouragements reçoit `before` =
   fichier (juste). Course résiduelle inter-processus minime (lecture-écriture sans verrou commun) ; `follow…` voir ci-dessus.
   `SharedStore.update`/`updateContent` refusent d'écraser un fichier abîmé ; copie dédupliquée par SHA-256 ✔
8. Compilation : labels d'init et `switch` sur `StyleApplication` cohérents ; closure `quickAdd` passée à `() -> Bool` : tous
   les appelants de DataItemViews retournent un Bool ✔ (non compilé)
9. Tests : exercent le vrai code, non tautologiques ; lacunes ci-dessus
10. check_swift.py : OK
