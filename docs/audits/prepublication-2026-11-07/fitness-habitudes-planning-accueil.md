# Audit 24.F : Fitness, Habitudes, Productivité, Planning · Études, Mon Quotidien, Accueil

Date : 2026-11-07. Méthode : lecture statique du code, sans exécution (pas de Mac). Aucun fichier du projet modifié. Rien ici ne prouve que le code compile ou que les tests passent : seule la CI le prouve. Les constats « À confirmer » demandent une exécution.

## Synthèse

- Bloquant : 0
- Majeur : 6 (F-01 à F-06)
- Mineur : 17 (F-07 à F-23)
- Amélioration : 3 (F-24 à F-26)

Les 6 plus graves :
1. F-01 Habitudes : la limite gratuite de 5 est contournée par l'écran Planning › Habitudes (`PlanningPages.swift:357,374,384`).
2. F-02 Tâches : l'échéance activée mais jamais touchée n'est pas enregistrée (`PlanningApp.swift:407-409,436,442`).
3. F-03 Fitness : une séance non terminée reste « en cours » indéfiniment (écran Fitness, widgets, Live Activity), mais Mon Quotidien l'ignore le lendemain (`DailyBrief.swift:453` contre `FitnessApp.swift:62`, `Fitness.swift:381-390`).
4. F-04 Fitness : aucune alerte à la fin du repos (ni notification, ni vibration, ni son) et l'écran de séance ne se rafraîchit pas (`FitnessSession.swift:153`, `WorkoutLiveActivity.swift:94`).
5. F-05 Fitness : l'historique est borné à 300 séances et les records en dérivent, donc perte silencieuse de records (`Fitness.swift:387,577`).
6. F-06 Données : `Habit` (et plusieurs types Productivité et Études) a un décodage synthétisé, et un seul élément illisible fait perdre toute la liste (`Content.swift:113,282`, `Productivity.swift:45-90`).

---

## Constats

### F-01 · Majeur · Limite gratuite de 5 habitudes contournable
- Fichier : `App/Screens/MiniApps/Planning/PlanningPages.swift:357, 374, 384` ; `App/Screens/Content/HabitsView.swift:270-289`.
- Preuve : `HabitsView` teste `model.canAddHabit` avant d'ouvrir l'éditeur (`HabitsView.swift:58`). `PlanningHabitsPage` met `creating = true` sans test (lignes 357 et 374) et ouvre `HabitEditor(... isNew: true)` (ligne 384). `HabitEditor.save()` ajoute sans vérifier la limite.
- Impact : un utilisateur gratuit crée autant d'habitudes qu'il veut. Perte du levier Premium (ligne « Habitudes 5 / ∞ » du paywall, `PaywallView.swift:204`).
- Reproduction : sans Premium, créer 5 habitudes, ouvrir Planning › Habitudes › « Ajouter une habitude », enregistrer : la 6e est créée.
- Correction : dans `PlanningHabitsPage`, remplacer `creating = true` par `if model.canAddHabit { creating = true } else { paywall = .habitLimit }` (ajouter un `@State paywall` et un `.sheet(item:)`). Défense en profondeur : refuser l'ajout dans `HabitEditor.save()` quand `isNew && !model.canAddHabit`.
- Test : `canAddHabit` est faux à 5 habitudes sans Premium ; test d'interface : la 6e création ouvre le paywall depuis les deux écrans.

### F-02 · Majeur · Échéance de tâche non enregistrée si le sélecteur n'est pas touché
- Fichier : `App/Screens/MiniApps/Planning/PlanningApp.swift:407-409, 436, 442-451`.
- Preuve : `hasDue` est un `@State` local initialisé à `task.due != nil`. Le `DatePicker` lit `task.due ?? Date()` mais n'écrit que si l'utilisateur change la valeur. `save()` ne remet pas de date quand `hasDue` est vrai et `task.due` nil.
- Impact : sur une tâche sans date (créée dans Tâches ou en saisie rapide), activer « Échéance » puis Enregistrer affiche la date par défaut mais ne la sauve pas. La tâche n'apparaît ni dans l'agenda ni dans « Aujourd'hui », et la répétition est perdue sans message. Même problème avec « À une heure précise » (heure jamais écrite).
- Reproduction : Planning › Tâches › ajouter « test » en saisie rapide › l'ouvrir › activer Échéance › Enregistrer › rouvrir : Échéance désactivée.
- Correction : à l'activation du toggle (`onChange(of: hasDue)`) ou dans `save()`, faire `if hasDue && saved.due == nil { saved.due = DateMath.startOfDay(Date()) }` ; si `hasTime` et `due` nil, utiliser l'heure courante.
- Test : sur la logique pure (extraire la normalisation), `hasDue = true` et `due = nil` donne `due != nil` après sauvegarde.

### F-03 · Majeur · Séance abandonnée : jamais fermée, incohérente entre écrans, durée gonflée
- Fichier : `Shared/Domains/Fitness.swift:375-390, 509-519` ; `App/Screens/MiniApps/Fitness/FitnessApp.swift:62` ; `App/Core/DailyBrief.swift:453` ; `Shared/Live/WorkoutLiveActivity.swift:51-52` ; `App/Screens/Home/MiniAppsRow.swift:69`.
- Preuve : aucune péremption de `state.active` (recherche « stale / orphan / expire » : rien côté Fitness). Mon Quotidien limite la séance en cours à celle du jour (`isSameDay(active.start, now)`), l'écran Fitness (`FitnessApp.swift:62`), les widgets (`FitnessTiles.swift`), la Live Activity et `MiniAppsRow` non. `finishActive` pose `end = date` (instant du clic), pas l'heure de la dernière série. `duration` (`Fitness.swift:306`) lit `end`.
- Impact : après une fermeture forcée ou un oubli, la séance de la veille reste « Séance en cours » dans l'app, la Live Activity et les widgets, alors que Mon Quotidien affiche « Séance du jour : à faire ». Un « Série faite » du widget reprend la séance d'hier. Quand elle est terminée plus tard, `Durée` (historique, semaine, détail) compte tout l'intervalle (heures, voire jours). Les calories ne sont pas touchées (`CalorieModel` plafonne les temps morts). Un `startSession` pendant une séance ancienne l'archive silencieusement avec cette durée.
- Reproduction : lancer une séance, faire 1 série, tuer l'app, attendre le lendemain. Comparer Fitness (en cours) et Mon Quotidien (planifiée). Terminer : Durée = toute la nuit.
- Correction : (a) à l'ouverture (`scenePhase == .active`) et dans `completeNextSet`/`startSession`, fermer une séance dont la dernière activité date de plus de ~3 h ou d'un autre jour : `finishActive` avec `end = lastStepDate ?? start` (archive si séries, sinon abandon) ; (b) dans `finishActive`, `end = session.sets.last?.date` quand le dernier pas date de plus de 30 min ; (c) aligner `DailyBrief` et les écrans sur la même règle.
- Test : `FitnessState` avec `active.start` il y a 26 h : après la règle, `active == nil`, `history.last.duration` est bornée à la dernière série.

### F-04 · Majeur · Fin du repos silencieuse, et l'écran de séance ne se met pas à jour
- Fichier : `App/Screens/MiniApps/Fitness/FitnessSession.swift:153-175` ; `Shared/Live/WorkoutLiveActivity.swift:94` ; `App/Services/NotificationScheduler.swift` (aucune notification de repos).
- Preuve : aucune notification locale, aucun son ni retour haptique à `restEndsAt` (recherche : `restEndsAt` n'est lu que pour l'affichage). Dans l'écran, le bloc de repos est décidé par `rest > now` dans `body`, sans `TimelineView` : à zéro, le compte à rebours reste figé à 0:00 jusqu'au prochain changement d'état. La Live Activity n'a qu'une `staleDate` qui la redessine en « Prêt », sans alerte.
- Impact : en salle, téléphone verrouillé ou en poche, rien ne signale que le repos est fini, alors que c'est la fonction centrale d'un minuteur de repos. À l'écran, un repos fini paraît encore en cours.
- Reproduction : lancer une séance, valider une série (repos 90 s), verrouiller l'iPhone : rien à 90 s. Rester sur l'écran : le chrono reste à 0:00.
- Correction : planifier une notification locale (déclencheur par intervalle, identifiant fixe `tessera.rest.end`, son par défaut) à chaque `completeSet` et `resumeRest`, l'annuler à `skipRest`, `pauseRest`, `skipSet`, `cancelActive`, `finishActive` ; envelopper le bloc repos dans un `TimelineView` explicite ou un `.task(id:)` qui dort jusqu'à `rest`, avec `Haptics.success()`. Les notifications locales se demandent avec l'explication habituelle (`AppPermission.notifications`).
- Test : fonction pure de planification testée (instant, annulation à la pause) ; test d'interface : repos de 15 s, l'écran passe à « Prêt ».

### F-05 · Majeur · Historique tronqué à 300 séances : records et progression perdus sans avertissement
- Fichier : `Shared/Domains/Fitness.swift:386-388` (`history.removeFirst`), `:577-585` (`records`), `:625-632`.
- Preuve : tout (records, volume, séries, progression) dérive de `history`, plafonné à 300. À 4 séances par semaine, la plus ancienne disparaît après environ 75 semaines.
- Impact : un record de 18 mois disparaît, la progression « depuis le début » se réinitialise, la série hebdomadaire est tronquée. Le texte de l'app promet « Tes séances restent enregistrées ».
- Reproduction : (test) ajouter 301 séances, la première et son record disparaissent.
- Correction : garder toutes les séances (une séance pèse quelques Ko), ou fusionner les séances retirées dans une archive de records persistée et lue par `FitnessMath.records`. À défaut, relever le plafond à 2 000.
- Test : 301 séances : le record de la première séance est toujours renvoyé par `records(_:)`.

### F-06 · Majeur (latent) · Décodage non tolérant : un élément illisible fait perdre toute la liste
- Fichier : `Shared/Model/Content.swift:113-118` (`Habit`, décodage synthétisé), `:281-282` (`try? decodeIfPresent` du tableau donne `[]`) ; `Shared/Domains/Productivity.swift:45-90` (`ProjectTask`, `Project`, `Deadline`, `CounterItem`, `FocusLog`) ; `Shared/Domains/Student.swift:6-8, 130-166` (`Course`, `Exam`, `Assignment`, `Grade`, `Flashcard`, `StudySession`).
- Preuve : ces types n'ont pas d'`init(from:)` à valeurs par défaut. Le décodeur synthétisé exige toutes les clés non optionnelles, même celles qui ont une valeur par défaut. Ensuite `ContentState`, `ProductivityState`, `StudentState` décodent le tableau entier avec `try?` ou `c.value` : un seul élément qui échoue donne un tableau vide, puis la sauvegarde suivante écrase le fichier.
- Impact : aujourd'hui sans effet (les clés existent), mais le jour où un champ non optionnel est ajouté à `Habit`, `Course`, `Flashcard`, etc., toutes les habitudes (ou cours, fiches, projets) des utilisateurs existants sont perdues au premier lancement. `TaskItem`, `ClassSlot`, `PriorityItem`, `WorkoutSession` sont, eux, tolérants : l'incohérence est le piège.
- Reproduction : ajouter `var x = 0` à `Habit`, décoder un JSON ancien : la liste des habitudes est vide.
- Correction : (1) écrire un `init(from:)` avec `c.value(.clé, défaut)` pour ces types (modèle : `TaskItem`) ; (2) décoder les tableaux élément par élément (un enveloppeur « lossy » qui ignore les éléments illisibles) pour qu'un élément abîmé ne tue pas les autres.
- Test : un JSON de chaque type avec seulement ses clés historiques se décode ; un tableau avec un élément cassé garde les autres.

### F-07 · Mineur · « Arrêter » une session de concentration n'annule pas la notification de fin
- Fichier : `App/Screens/MiniApps/Planning/PlanningPages.swift:487-495` ; `Shared/Intents/InteractiveIntents.swift:94, 117`.
- Preuve : `start()` appelle `FocusNotifier.schedule`, mais `stop()` n'appelle pas `FocusNotifier.cancel()` (le widget le fait, ligne 94).
- Impact : « Session terminée, prends une pause » arrive à l'heure prévue alors que l'utilisateur a arrêté.
- Correction : ajouter `FocusNotifier.cancel()` dans `stop()`.
- Test : après `stop`, la notification `tessera.focus.end` n'est plus en attente (identifiant injecté ou test d'intégration).

### F-08 · Mineur · « Passer cet exercice » : double appui et séance finie non archivée
- Fichier : `App/Screens/MiniApps/Fitness/FitnessSession.swift:222-226` ; `Shared/Domains/Fitness.swift:262-269`.
- Preuve : bouton simple (pas de `TapGuard`, pas de position attendue) : deux appuis rapides sautent deux exercices. Sur le dernier exercice, `skipExercise` pose `end` sur la séance sans appeler `finishActive` (contrairement à `skipSet` et `completeSet`) : la séance finie reste dans `state.active`, n'est pas dans `history`, l'encouragement et `justFinishedSession` ne se déclenchent pas.
- Impact : exercice sauté par erreur sans annulation possible ; séance terminée « en suspens » jusqu'à la prochaine séance.
- Correction : passer par une fonction `FitnessState.skipExercise` qui appelle `finishActive` si la séance finit, et un `TapGuard` (ou la position attendue de `WorkoutPosition`) sur le bouton.
- Test : `skipExercise` sur le dernier exercice avec séries : `active == nil`, `history.count == 1`.

### F-09 · Mineur · Séance sans exercice (séance libre fermée, séance vide) : « en cours » fantôme
- Fichier : `FitnessSession.swift:27, 437-446` ; `App/Screens/Spaces/FitnessSpace.swift:121-260` (`canSave` ne demande que le nom) ; `MiniAppsRow.swift:69` ; `SmartReminders.swift:38`.
- Preuve : « Séance libre » démarre une séance sans exercice puis ouvre la bibliothèque ; fermer sans choisir laisse `active` non fini, sans exercice courant. `FitnessApp` ne la voit pas comme en cours (`currentExercise` nil), `MiniAppsRow` affiche « Séance en cours » et le rappel de séance du jour est supprimé (`begun`). Une séance enregistrée sans exercice nommé mène au même état via « Commencer ».
- Impact : mini-app qui annonce une séance fantôme et rappel absent.
- Correction : annuler la séance vide à la fermeture du sélecteur ; `RoutineEditor.canSave` exige au moins un exercice nommé ; tester `active.currentExercise != nil` dans `MiniAppsRow` et `SmartReminders`.
- Test : démarrer une séance libre puis fermer : `active == nil`.

### F-10 · Mineur · Chrono d'étude oublié : 4 h inscrites sans moyen de corriger
- Fichier : `Shared/Domains/Student.swift:336-355` ; pas de suppression de `StudySession` dans l'interface (recherche `sessions.remove` : seulement la purge à 200 jours).
- Preuve : `stopTimer` plafonne à 240 min ; un chrono oublié et arrêté le lendemain inscrit 4 h fictives ; « +25/45/60 min » (`StudiesPages.swift:745`) est irréversible.
- Impact : statistiques et objectif hebdomadaire faux, sans correction.
- Correction : proposer « Combien de temps ? » quand le chrono dépasse 4 h, et une liste des sessions avec suppression (glisser).
- Test : `stopTimer` après 10 h inscrit 240 min ; la suppression retire la session et change `studyMinutes`.

### F-11 · Mineur · Suppressions destructrices sans confirmation
- `App/Screens/MiniApps/Studies/StudiesPages.swift:263-266` : glisser pour supprimer un cours supprime aussi tout son horaire (`deleteCourse`), alors que la page du cours demande confirmation (ligne 351). Le pied de page prévient mais ne demande rien.
- `StudiesPages.swift:127-134` : menu contextuel « Supprimer toute la série » sans confirmation.
- `App/Screens/Content/HabitsView.swift:41-45, 224-227` : suppression d'une habitude (avec tout son historique) sans confirmation.
- `FitnessPages.swift:77-79`, `FitnessSpace.swift:78-80` : suppression d'une séance du programme par glisser.
- `TasksView.swift:54`, `PlanningPages.swift:106-110` : « Tout effacer » sans confirmation.
- Impact : perte de données par geste accidentel, sans annulation.
- Correction : `confirmationDialog` (modèle : `StudiesCoursePage`), ou bandeau « Annuler » pendant 5 s.
- Test : tests d'interface à compléter ; logique inchangée.

### F-12 · Mineur · Textes non traduits dans les examens
- Fichier : `App/Screens/MiniApps/Studies/StudiesApp.swift` (struct `ExamRow` : le texte « Auj. », « J-n » et le mot « à » en dur).
- Preuve : `Text(days <= 0 ? "Auj." : "J-\(days)")` est un `String` (aucune localisation) ; `Fmt.shortDay(...) + " à " + Fmt.time(...)` en français codé en dur. « J-3 » n'existe qu'en français.
- Impact : en, es, de, it, pt-BR, ja affichent du français dans la liste des examens.
- Correction : passer ces textes par `tr(...)` et ajouter les clés au catalogue (`l10n_catalog.py extract`).
- Test : `l10n_scan.py` (ou test de clés manquantes) sur `ExamRow`.

### F-13 · Mineur · L'éditeur d'habitude peut écraser des jours cochés entre-temps (À confirmer)
- Fichier : `HabitsView.swift:156, 281-286`.
- Preuve : l'éditeur copie l'habitude en `@State` (y compris `completedDays`) et `save()` remplace l'habitude entière par cette copie.
- Impact : si un jour est coché hors de l'éditeur (bouton du widget pendant que l'éditeur est ouvert, retour depuis l'écran d'accueil), l'enregistrement le perd.
- Correction : dans `save()`, ne modifier que `name`, `symbol`, `colorHex`, `reminderHour`, `reminderMinute` de l'habitude actuelle.
- Test : cocher un jour puis sauvegarder un éditeur ouvert avant : le jour reste coché.

### F-14 · Mineur · « Jours prévus » des habitudes absents ; rappels quotidiens répétés
- Fichier : `Shared/Model/Content.swift:113-121` ; `Shared/Support/NotificationEngine.swift:154-159` (`habitSchedule` jamais rempli en dehors du test `SmartNotificationEngineTests.swift:245`) ; `App/Services/NotificationScheduler.swift:25-37`.
- Preuve : `Habit` n'a pas de jours prévus : toute habitude est quotidienne. Le champ `habitSchedule` du moteur est du code mort côté app. Le rappel par habitude est un déclencheur quotidien répétitif (`repeats: true`) qui sonne même si l'habitude est déjà cochée, en plus de la notification « Tes habitudes du jour » du moteur intelligent.
- Impact : habitude du lundi, mercredi, vendredi impossible ; double notification ; série interrompue les jours non prévus.
- Correction : ajouter `weekdays` à `Habit` (décodage tolérant, voir F-06), l'utiliser dans `streak`, `regularity`, `isPlanned` et le rappel (un déclencheur par jour prévu) ; remplir `habitSchedule` ; reporter les rappels par habitude dans le moteur intelligent pour ne pas sonner si c'est fait.
- Test : habitude lun, mer, ven : `streak` ne casse pas le mardi ; pas de rappel le mardi.

### F-15 · Mineur · Pas de notifications interactives
- Fichier : `App/Services/NotificationPresenter.swift:25-29` (`didReceive` vide), aucun `UNNotificationCategory`.
- Constat : les actions « Série faite », « Cocher » ne sont proposées que par la Live Activity et les widgets, jamais par une notification. À signaler si la fiche promet des « notifications interactives ».
- Correction : catégories avec actions (« Fait » pour une habitude, « Prêt » à la fin du repos) traitées dans `didReceive`, après F-04.

### F-16 · Mineur · Plafond de 400 jours d'une habitude : retire le plus ancien inséré, pas le plus ancien jour
- Fichier : `Shared/Model/Content.swift:127-136`.
- Preuve : `completedDays.removeFirst(...)` retire les premiers éléments insérés ; cocher un jour ancien (rattrapage via le sélecteur de jour), ou décocher puis recocher, range un jour récent en tête. Le plafond coupe aussi les séries de plus de 400 jours.
- Impact : jour récent supprimé à la place d'un ancien ; séries et meilleure série tronquées à 400.
- Correction : trier avant de couper et relever le plafond à 1 000.
- Test : 401 jours dont un ancien inséré en dernier : le plus ancien jour est retiré, pas le dernier ajouté.

### F-17 · Mineur · Éditeur d'événement : requête EventKit répétée à chaque rendu
- Fichier : `App/Screens/Spaces/StudentSpace.swift:236-241, 277-283`.
- Preuve : `conflicts` (propriété calculée) appelle `CalendarService.events(...)` de façon synchrone ; elle est lue deux fois par `body` (`isEmpty` puis `map`), donc à chaque frappe dans un champ.
- Impact : saccades possibles sur un calendrier chargé (À confirmer à l'exécution).
- Correction : calculer une fois par `body` (`let conflicts = self.conflicts`) et mémoriser les événements du jour au `onAppear`.
- Test : non applicable (performance) ; mesurer à l'instrument.

### F-18 · Mineur · Saisie rapide de tâche avec un autre jour sélectionné
- Fichier : `PlanningPages.swift:114-120` (`addQuick`).
- Preuve : le filtre « Aujourd'hui » permet de choisir un autre jour (`DaySwitcher`), mais `addQuick` date la tâche à `Date()`.
- Impact : la tâche ajoutée pour le jeudi apparaît aujourd'hui.
- Correction : `DateMath.startOfDay(day)` quand le filtre est `.today`.
- Test : ajouter avec `day` = demain : `due` = demain.

### F-19 · Mineur · Plusieurs séances le même jour : seule la première est proposée
- Fichier : `Shared/Domains/Fitness.swift:365-368`, `FitnessApp.swift:57`, `DailyBrief.swift:468`, `SmartReminders.swift:34`.
- Preuve : le programme accepte plusieurs séances par jour (« Ma semaine » affiche « A + B »), mais tout le reste ne lit que `routines.first(where:)`.
- Impact : la seconde séance prévue n'apparaît jamais comme « séance du jour ».
- Correction : interdire plusieurs séances par jour dans `toggle`, ou proposer toutes celles du jour (menu « Commencer »).
- Test : deux routines le lundi : `todaysWorkout` expose les deux.

### F-20 · Mineur · Ajout d'habitude silencieusement ignoré à la limite (Profil)
- Fichier : `App/Screens/Profile/DataItemViews.swift:144`, `App/Screens/Profile/ProfileTopics.swift:553`.
- Preuve : `guard model.canAddHabit else { return }` : aucun message ni paywall.
- Impact : bouton qui ne fait rien.
- Correction : ouvrir `PaywallView(context: .habitLimit)`.
- Test : à la limite sans Premium, le paywall s'ouvre.

### F-21 · Mineur · Jauge de repos fausse après une pause (cosmétique)
- Fichier : `Shared/Domains/Fitness.swift:501-505` (`resumeRest`) ; `Shared/Render/Tiles/FitnessTiles.swift` (`restTimer`, `nextSet`) ; `WorkoutLiveActivity.swift:65`.
- Preuve : `restStart` est recalculé comme la date de la dernière série ; après « Pause » puis « Reprendre », `restEndsAt` est décalé mais pas `restStart`, donc la jauge du widget et de la Live Activity part d'un instant antérieur (progression fausse ; le compte à rebours est juste).
- Impact : jauge de repos qui saute après une pause.
- Correction : mémoriser le début du repos dans la session et le décaler à la reprise.
- Test : `resumeRest` conserve la durée restante et la progression reste continue.

### F-22 · Mineur · Passage d'une série hebdomadaire à « Une seule fois » sans avertissement
- Fichier : `App/Screens/Spaces/StudentSpace.swift:343-352, 429-435`.
- Preuve : l'interrupteur « Une seule fois » transforme toute la série en événement unique à la sauvegarde et efface `overrides` et `skippedDays`.
- Impact : les autres semaines disparaissent d'un coup.
- Correction : confirmation « Cela supprime les autres semaines » lorsque `base.date == nil` et `slot.date != nil`.
- Test : série hebdomadaire passée en une seule fois : la confirmation est demandée avant `store`.

### F-23 · Mineur · Page Concentration : la session finie reste affichée « en cours »
- Fichier : `PlanningPages.swift:431-440` (même cause que F-04).
- Preuve : `focus.isRunning(at: now)` est évalué au rendu uniquement ; sans `TimelineView`, à la fin le compte à rebours reste à 0:00.
- Impact : la page paraît bloquée jusqu'au prochain rafraîchissement.
- Correction : `TimelineView` explicite sur `end` ou `.task(id: end)`.
- Test : à `end`, `isRunning` est faux et l'écran propose de relancer (test d'interface).

### F-24 · Amélioration · Éditeur de séance : pas de réordonnancement ni de suppression ciblée
- `FitnessSpace.swift:244-249` : seul « Retirer le dernier exercice » existe ; pas de glissement ni de suppression d'un exercice précis.

### F-25 · Amélioration · Records limités aux charges
- `Fitness.swift:579` : `where set.weight > 0` ; les exercices au poids de corps et le cardio n'ont ni record ni progression. À documenter dans l'écran ou à étendre (répétitions, durée).

### F-26 · Amélioration · Formateur de clés de jour partagé et muté
- `Shared/Support/DateMath.swift:4-23` : `keyFormatter` unique dont `timeZone` est réaffecté à chaque appel ; `dayKey` est appelé depuis des tâches asynchrones et le processus des widgets. À confirmer : risque de course théorique. Correction : un `DateFormatter` par appel. Test : appels concurrents de `dayKey` donnent la même chaîne.

---

## Critères de la mission : vérification point par point

1. Fitness
   - Programmes (créer, modifier, supprimer) : fonctionnent (`RoutineEditor`, `FitnessProgramPage`) ; suppression sans confirmation (F-11), séance vide possible (F-09).
   - Bibliothèque et démonstrations (Premium) : respecté (`ExerciseGate`, `canOpenExercise`, `ExerciseLibraryViews.swift:213, 693`).
   - Séance : lancer, séries, passer, pause, annuler la dernière série : OK. Double appui « Série faite » : protégé (`TapGuard` de `MiniActionButton`, position attendue côté widgets). Double appui « Passer cet exercice » non protégé (F-08).
   - Chrono et repos fondés sur des dates (`restEndsAt`, `Text(timerInterval:)`) : OK. Alerte de fin : absente (F-04).
   - Reprise après fermeture forcée : l'état est restauré, mais jamais fermé (F-03).
   - Abandon : `cancelActive`, `deleteSession` : OK. Fin : OK (durée F-03).
   - Historique, statistiques, records, progression : plafond 300 (F-05) ; records limités aux charges (F-25).
   - Calories : bornées par `CalorieModel`, étiquetées estimation, poids du profil : OK.
   - Notifications interactives : absentes (F-15). Live Activity : début, mise à jour, fin et nettoyage des orphelines (`sync` termine les doublons et les activités sans séance) : OK ; synchronisée au retour au premier plan (`ArdaneApp.swift:68`).
2. Habitudes : créer, modifier, cocher et décocher, séries, fuseau (calendrier à fuseau automatique), heure d'été (clés de jour) : OK. Limite 5 contournée (F-01, F-20). Jours prévus : absents (F-14). Historique après modification : conservé sauf F-13. Statistiques : régularité en Premium, comptée depuis le premier jour (OK).
3. Productivité : Top 3 (maximum 3, double ajout dédoublonné, tâches réalisées conservées), tâches, projets, compteurs (réinitialisation quotidienne par clé de jour) : OK. Défauts : F-02, F-18.
4. Planning · études : création, modification et suppression d'événements, récurrence par jours, une occurrence ou toute la série (`SlotEditor`, `deleteOccurrence`, `overrides`), chevauchements (voies côte à côte, avertissement), couleurs, jour, semaine, mois et année, prochain cours et événement, examens, notes, fiches (Leitner), chrono d'étude (basé sur `timerStart`) et sa Live Activity, calendrier iOS (accès refusé : feuille d'explication, Planning fonctionne sans), import d'horaire (Premium vérifié, erreurs gérées, ajouter ou remplacer sans doublon) : OK. Défauts : F-10, F-11, F-12, F-17, F-22.
5. Mon Quotidien et Accueil : cartes, organisation (déplacer, agrandir, retirer, ajouter par la carte « + »), ordre persisté dans `dailyOrder`, `dailyWide`, `dailyHidden` : OK. Cohérence avec les widgets : séance en cours incohérente (F-03).
6. Persistance et décodage : `WorkoutSession`, `FitnessState`, `TaskItem`, `ClassSlot`, `ClassOverride`, `PriorityItem`, `AppSettings` tolérants. Faiblesse : F-06.
7. Boutons sans action, données fictives : aucun marqueur de tâche à faire dans `App/` et `Shared/` ; les données d'exemple (`SamplePayload`, `SampleData`) ne servent qu'à la galerie des widgets et aux captures. Textes non traduits : F-12. Valeurs codées en dur : couleurs hexadécimales répétées dans plusieurs écrans, sans effet fonctionnel.

## Examiné et trouvé sain

- Modèle de séance : `completeSet`, `skipSet`, `undoLastStep`, `undoLastSet`, `append`, jetons de position `WorkoutPosition` (second appui d'un widget ignoré), `justFinishedSession` (fenêtre d'une heure, même jour).
- Boutons de la Live Activity et widgets : la méthode `press` appliquée en lecture-modification-écriture atomique (`SharedStore.update`), synchronisation de l'app via `workoutSavedOutside`.
- Repos : pause et reprise fondées sur des dates (`restPausedRemaining`).
- Calories : plafond des temps morts, poids absent affiché par un tiret plutôt qu'un poids par défaut.
- Premium Fitness : bibliothèque, fiches, progression, « La dernière fois » : tous gardés par `canOpenExercise` ; « Mes exercices » reste gratuit.
- Récurrence du planning : `ClassSlot.resolved`, `applyingOverride`, `override(making:)`, annulation d'une occurrence, exceptions par jour, décodage tolérant, heures murales stables au changement d'heure (`DateMath.date(on:minute:)`), `ScheduleGlance` (fin exclusive, chevauchements).
- Import d'horaire : `ScheduleImportMerge.merge` et `replace` (sans doublon, cours créés au besoin, événements conservés), Premium, accès sécurisé aux fichiers.
- Top 3 : `addQuickTask` (anti-double appui, plafond 3), `togglePriority` (jamais de suppression).
- Tâches répétées : `toggleTask` crée la suivante et la retire si on décoche.
- Fuseau et calendrier : `Fmt.calendar` à fuseau auto-actualisé, semaine commençant le lundi.
- Accès au calendrier : `hasAccess` exige l'accès complet ; refus géré.
- Organisation de Mon Quotidien : règles pures de `DailyLayoutRules` (déplacement, taille, rangées), couvertes par `DailyLayoutRulesTests`.
- Live Activity d'étude : basée sur `timerStart`, nettoyage des doublons.
