# Audit : Fitness

État du code lu le 2026-11-17 (branche `main`, commit `e09123e` ; le code de l'app est le même qu'au commit `19f6eb1`, seuls des fichiers de `docs/` ont changé depuis). Lecture seule, rien n'a été modifié.
Deuxième passe le même jour : tous les fichiers de Fitness relus en entier, six captures de la CI regardées. Les numéros F1 à F68 et les problèmes 1 à 31 n'ont pas bougé (les planches déjà commencées s'y réfèrent). Les ajouts sont marqués « Précision » ou placés à la fin (problèmes 32 à 35).
Les preuves sont notées `Fichier.swift:ligne`. Dossiers : `FitnessApp`, `FitnessSession`, `FitnessPages`, `ExerciseLibraryViews`, `ExerciseDemo` sont dans `App/Screens/MiniApps/Fitness/` ; `FitnessSpace` dans `App/Screens/Spaces/` ; `Fitness`, `ExerciseLibrary`, `ExerciseTechniques`, `CalorieModel` dans `Shared/Domains/` ; `DailySection` dans `App/Screens/Home/` ; `DailyBrief`, `DailyDefaults`, `StepCounter`, `Agenda` dans `App/Core/` ; `WorkoutLiveActivity` dans `Shared/Live/` ; `FitnessTiles` dans `Shared/Render/Tiles/`.

## 1. En bref

- **À quoi ça sert** : préparer sa semaine de musculation (séances et jours), faire la séance série par série avec le repos minuté, puis suivre ce qui a été fait.
- **Pour qui** : une personne qui s'entraîne avec un programme fixe à la semaine. Le cardio et les étirements sont dans la bibliothèque, mais ils se notent comme des séries (pas de durée ni de distance).
- **Fréquence** : objectif de 1 à 7 séances par semaine (3 par défaut). Pendant une séance, l'écran « Séance » sert toutes les 1 à 3 minutes, souvent d'une main.
- **État** : vraie mini-app, complète (`MiniApp.fitness`, MiniApp.swift:6). 18 écrans et feuilles propres, 68 fonctions, 9 widgets, une activité en direct, style Cristal déjà appliqué.
- **Premium** : la bibliothèque (163 exercices), les fiches, les données par exercice et « Progression ». Le reste est gratuit.

## 2. Écrans et navigation

Aucun onglet ni segment dans Fitness. Tout part de l'écran principal. Les pages s'empilent sur l'onglet Accueil (`HomeRoute.page`, DailySection.swift:4-12 ; HomeView.swift:24-45).

### Pages (10)

| N° | Écran | Vue SwiftUI, fichier:ligne | Comment on y arrive | Ce qu'on y fait |
|---|---|---|---|---|
| E1 | « Fitness » (écran principal) | `FitnessAppView`, FitnessApp.swift:9 | Carte Fitness de Mon quotidien (DailySection.swift:824, 1742). Pastille Fitness de la rangée des mini-apps de l'accueil (MiniAppsRow.swift:160). Toucher un widget Fitness ou une notification Fitness (Router.swift:168-171). « Mes informations » › Fitness (ProfileUITests.swift:209-223). | Voir la séance du jour choisi, la lancer, voir la semaine, aller aux autres pages. |
| E2 | « Séance » : séance en cours | `FitnessSessionPage` › `live`, FitnessSession.swift:126 (route `.fitnessSession`, MiniApp.swift:178) | Boutons « Commencer », « Reprendre la séance », « Rattraper… » (FitnessApp.swift:143-168). Menu « Faire une séance quand même » (FitnessApp.swift:195-204). « Voir la séance » d'une fiche (ExerciseLibraryViews.swift:437). | Valider, passer ou annuler une série. Régler répétitions et charge. Suivre le repos. Ajouter un exercice. Terminer ou annuler la séance. |
| E3 | « Séance » : choix d'une séance | `FitnessSessionPage` › `chooser`, FitnessSession.swift:479 | Seulement sur la page « Séance » quand il n'y a plus de séance en cours, par exemple juste après la dernière série (FitnessSession.swift:31-35, 391). Aucun lien direct depuis l'écran principal. | Choisir une séance du programme ou « Séance libre ». « Annuler la dernière série ». |
| E4 | « Programme » | `FitnessProgramPage`, FitnessPages.swift:7 | Ligne « Programme et séances » (FitnessApp.swift:445). | Donner des séances aux jours. Créer, modifier, supprimer une séance. Régler l'objectif par semaine. |
| E5 | « Historique » | `FitnessHistoryPage`, FitnessPages.swift:130 | Ligne « Séances faites » (FitnessApp.swift:452). | Parcourir les séances par mois, ouvrir un détail, supprimer. |
| E6 | Détail d'une séance (titre : nom de la séance) | `FitnessSessionDetailPage`, FitnessPages.swift:191 | « Voir le détail » (FitnessApp.swift:246). Ligne d'une séance (FitnessApp.swift:221 ; FitnessPages.swift:149). | Voir date, durée, volume et séries. Modifier une série. Ouvrir une fiche. Supprimer la séance. |
| E7 | « Exercices » (bibliothèque) | `ExerciseLibraryPage`, ExerciseLibraryViews.swift:21 | Ligne « Exercices » (FitnessApp.swift:459). | Chercher, filtrer, ouvrir une fiche, mettre en favori, gérer « Mes exercices ». |
| E8 | Fiche d'exercice (titre : nom de l'exercice) | `ExerciseGate` puis `ExerciseDetailView`, ExerciseLibraryViews.swift:691, 306 (route `.fitnessExercise`, MiniApp.swift:181) | Ligne de la bibliothèque (ExerciseLibraryViews.swift:239). Favori de l'écran principal (FitnessApp.swift:487). Record (FitnessPages.swift:359). Alternative (ExerciseLibraryViews.swift:408). | Regarder la démonstration, lire la technique, voir ses performances, ajouter à une séance, mettre en favori. Sans Premium : carte « Cet exercice est dans Premium » (ExerciseLibraryViews.swift:700-711). |
| E9 | « Progression » | `FitnessProgressPage`, FitnessPages.swift:278 | Ligne « Progression » (FitnessApp.swift:466). | Voir le volume par semaine et les records. Sans Premium : carte verrou. |
| E10 | « Activité » (pas) | `FitnessActivityPage`, FitnessPages.swift:391 | Carte des pas en bas de l'écran principal (FitnessApp.swift:395). Carte « Pas » de Mon quotidien (DailySection.swift:1218, 1775). | Voir pas, distance, étages, calories actives. Changer de jour. Voir 7 jours. |

### Feuilles propres à Fitness (8)

| N° | Feuille | Vue SwiftUI, fichier:ligne | Comment on y arrive | Ce qu'on y fait |
|---|---|---|---|---|
| S1 | Éditeur de séance (« Nouvelle séance » ou nom de la séance) | `RoutineEditor`, FitnessSpace.swift:123 | « Créer une séance » (FitnessApp.swift:158). « Nouvelle séance » ou toucher une séance dans « Programme » (FitnessPages.swift:62, 80). Carte « Programme d'entraînement » de « À remplir » (DataItemViews.swift:117-120). | Nom, jours, exercices avec séries, répétitions, charge, repos, tempo, notes. |
| S2 | Bibliothèque en mode choix (« Ajouter un exercice ») | `ExerciseLibraryPage(onPick:)`, FitnessSession.swift:45-61 ; FitnessSpace.swift:139-152 | « Choisir dans la bibliothèque » (séance en cours ou éditeur de séance). « Séance libre » avec Premium. | Toucher un exercice : il s'ajoute tout de suite. Premium. |
| S3 | Fiche d'exercice en feuille | `ExerciseInfoSheet`, ExerciseLibraryViews.swift:285 | Bouton ⓘ : séance en cours (FitnessSession.swift:39), bibliothèque (ExerciseLibraryViews.swift:138), détail d'une séance (FitnessPages.swift:268), éditeur de séance (FitnessSpace.swift:153). | Même contenu que E8, avec « Fermer ». On revient exactement où on était. |
| S4 | « Ajouter un exercice » (écrit à la main) | `SessionExerciseForm`, FitnessSession.swift:529 | « Ajouter un exercice » pendant la séance (FitnessSession.swift:275). « Séance libre » sans Premium (FitnessSession.swift:517). | Nom libre ou un de « Mes exercices », séries, répétitions, charge, repos. |
| S5 | Modifier une série (titre : nom de l'exercice) | `SetEditor`, FitnessSession.swift:586 | Toucher une pastille de série faite (FitnessSession.swift:449) ou une série du détail (FitnessPages.swift:216). | Changer répétitions et charge. « Supprimer cette série ». |
| S6 | Ajouter à une séance du programme (titre : nom de l'exercice) | `AddToRoutineSheet`, ExerciseLibraryViews.swift:595 | « Ajouter à une séance » d'une fiche, quand aucune séance n'est en cours (ExerciseLibraryViews.swift:446, 496). | Choisir la séance (ou « Nouvelle séance »), séries, répétitions, charge, repos, tempo, notes. |
| S7 | « Nouvel exercice » | `CustomExerciseEditor`, ExerciseLibraryViews.swift:655 | « Créer un exercice » dans « Mes exercices » (ExerciseLibraryViews.swift:94). | Nom, muscle, équipement, type, notes. |
| S8 | « Mes paramètres » | `MiniAppInfoSheet`, MiniAppSettings.swift:184 | Bouton « Mes paramètres », dernier élément de l'écran principal (FitnessApp.swift:47 ; MiniAppSettings.swift:63). | « Rappel de séance », « Ton objectif », « Ton niveau », « Séances par semaine », « Toi », objectif de pas. |

### Feuilles partagées avec le reste de l'app (5)

| N° | Feuille | Vue, fichier:ligne | Comment on y arrive |
|---|---|---|---|
| C1 | Offre Premium | `PaywallView`, contexte `.exerciseLibrary` (PaywallContext.swift:84) ; contexte `.fitnessProgress` « La progression est dans Premium » (PaywallContext.swift:94), ouvert par la ligne « Meilleur record » de Créer (FitnessSpace.swift:94) ; `PremiumLockCard` (PremiumLock.swift:5), qui ouvre sa propre offre | Toucher un élément Premium sans Premium. |
| C2 | Explication avant la permission « Mouvement et pas » | `.permissionSheet(.motion)`, FitnessApp.swift:61 ; FitnessPages.swift:479 | « Afficher mes pas », « Autoriser ». |
| C3 | Explication avant les notifications (alerte de fin de repos) | `.permissionSheet(.notifications)`, FitnessSession.swift:68 | S'ouvre seule au premier repos, une seule fois (FitnessSession.swift:89-101). |
| C4 | « Choisir une date » | `DaySwitcher`, MiniApp.swift:531 | Toucher la date sur « Activité ». |
| C5 | Rappels | `SmartRemindersView`, SmartRemindersView.swift:59-72 | « Mes paramètres » › « Rappel de séance » (MiniAppSettings.swift:94). |

### Surfaces hors de la mini-app (6)

| N° | Surface | Vue, fichier:ligne |
|---|---|---|
| H1 | Carte Fitness de Mon quotidien, pages « Séance » et « Semaine » | `WorkoutDayTile`, DailySection.swift:808 ; `WorkoutWeekTile`, DailySection.swift:1730 ; pages : DailySection.swift:432 |
| H2 | Carte « Pas » de Mon quotidien, pages « Aujourd'hui » et « 7 jours » | `StepsDayTile`, DailySection.swift:1212 ; `StepsWeekTile`, DailySection.swift:1768 |
| H3 | Activité en direct (écran verrouillé et Dynamic Island) | `WorkoutActivityView`, WorkoutLiveActivity.swift:156 ; `WorkoutLiveActivityWidget`, Widgets/WorkoutLiveActivityWidget.swift:7 |
| H4 | Données Fitness dans Créer (« Séance », « Mes séances », « Suivi ») | `FitnessSpaceSections`, FitnessSpace.swift:3, affichée par `SpaceView` (SpaceView.swift:80) |
| H5 | Aperçu « Pendant une séance » dans Créer › écran verrouillé | `workoutLive`, LockScreenCreator.swift:117 |
| H6 | Pastille Fitness de la rangée des mini-apps de l'accueil, avec une ligne vivante : « Séance en cours » ou « n séance(s) cette semaine » (rien sans programme ni séance) ; aussi dans les catégories de Mon quotidien | `MiniAppSummary.caption`, MiniAppsRow.swift:70-73, 161 ; DailyCategories.swift:28, 52 |

### Menus et confirmations

- Menu « Faire une séance quand même » : la liste des séances du programme (FitnessApp.swift:195-204).
- Menu « … » d'une séance faite : « Supprimer la séance » (FitnessApp.swift:255-271). Aussi par appui long (FitnessApp.swift:208, 225 ; FitnessPages.swift:173) et par glissement dans l'historique (FitnessPages.swift:166).
- Menu d'un jour dans « Programme » : une coche par séance (FitnessPages.swift:24-38).
- Menus de filtre « Muscle », « Équipement », « Type », « Niveau » (ExerciseLibraryViews.swift:150-181).
- Confirmations : « Terminer la séance ? » (FitnessSession.swift:290), « Annuler la séance ? Elle ne sera pas comptée. » (FitnessSession.swift:309), « Supprimer cette séance ? Elle ne sera plus comptée et tu pourras la refaire. » (FitnessPages.swift:501), « Supprimer cette séance du programme ? » (FitnessPages.swift:103).

## 3. Écran principal : sections dans l'ordre actuel

Cadre commun à toutes les mini-apps : `MiniAppScaffold` (MiniAppScaffold.swift:30). En haut un voile rouge, puis la feuille. Preuve de l'ordre : FitnessApp.swift:34-48.

1. **Barre** : retour, titre « Fitness ». Aucun bouton de réglages en haut (FitnessApp.swift:49).
2. **Sélecteur de semaine** (FitnessApp.swift:351 ; WeekSelector.swift:23). Titre « Cette semaine », flèches, 7 jours (initiale, numéro, point). Point plein : séance faite ou rattrapée. Point creux : séance prévue. Le jour choisi est une pilule rouge. Le futur est autorisé. Bouton « Aujourd'hui » quand un autre jour est choisi.
3. **Séance du jour choisi**, en grand sur verre (`MiniHero`, FitnessApp.swift:100-138) : petit libellé, nom en 54 points, une ligne de détail. Neuf états, voir le tableau plus bas. Séance en cours : une barre de progression sous la carte (FitnessApp.swift:105).
4. **« À remplir » n / 4** (MiniAppToFill.swift:41). Seulement s'il manque une information. Quatre cartes possibles : « Programme d'entraînement », « Séances par semaine », « Poids », « Objectif de pas » (MiniAppToFill.swift:11 ; DataItems.swift:86-89). Une carte remplie part au bout d'environ 1,4 seconde.
5. **« Cette semaine »** (ou « Semaine dernière », « Semaine prochaine », « Semaine du … ») : quatre tuiles en 2 × 2 (FitnessApp.swift:363-376). « Durée », « Volume » (kg ou lb), « Calories » (« ≈ n », ou « — » sans poids), « Séances » (« faites / objectif »).
6. **« Séance du jour »** (ou la date du jour choisi) : détails et actions secondaires (FitnessApp.swift:175-244). Absente si la séance est en cours, s'il n'y a pas de programme, ou si le jour est libre (FitnessApp.swift:542-549).
7. **« Programme »** : une carte de quatre lignes (FitnessApp.swift:441-473). « Programme et séances » (« n séances »), « Séances faites » (« Toutes tes séances », nombre à droite), « Exercices » (« 163 exercices, fiches et démonstrations », badge Premium), « Progression » (« Charges, volume, records et évolution », badge Premium).
8. **« Exercices »** : les favoris, 6 au plus, avec une étoile (FitnessApp.swift:477-495). Rien sans favori.
9. **Carte des pas** (FitnessApp.swift:389-428) : anneau, « n pas », objectif, distance, étages. Si l'accès n'a jamais été demandé : ligne « Afficher mes pas ». Si l'accès est refusé ou impossible : rien.
10. **Note** : « Calories et volumes estimés à partir de tes séances et de ton poids : des repères, pas des mesures. » (FitnessApp.swift:46).
11. **« Mes paramètres »** : bouton bordé, tout en bas (FitnessApp.swift:47).
12. **Action flottante** au-dessus de la barre d'onglets, une seule à la fois (FitnessApp.swift:141-172).

### Les neuf états de la séance du jour (FitnessApp.swift:68-86, 100-172, 184-244)

| État | Libellé | Grand texte | Ligne de détail | Action flottante | Section de détail |
|---|---|---|---|---|---|
| Aujourd'hui, séance en cours | « Séance en cours » ou « Rattrapage en cours » | Nom de la séance | « Exercice · série n sur m » + barre | « Reprendre la séance » | Aucune |
| Aujourd'hui, séance faite | « Séance faite » ou « Séance rattrapée » | Nom | « n séries · n min · n kg soulevés » | Aucune | « Voir le détail » + menu « … » |
| Aujourd'hui, séance prévue | « Séance du jour » | Nom | « n exercices · n séries · environ n min » | « Commencer » | 4 premiers exercices (« 4 × 8 · 80 kg »), « + n autres » |
| Aujourd'hui, repos | « Repos aujourd'hui » | « Repos » | « Prochaine séance : nom, demain » | « Rattraper « nom » d'hier » si la séance d'hier n'a pas été faite, sinon aucune | Menu « Faire une séance quand même » |
| Aujourd'hui, aucun programme | « Aujourd'hui » | « Ton programme » | « Crée tes séances (exercices, séries, charges, repos) et choisis leurs jours : Ardane te propose chaque jour la bonne. » | « Créer une séance » | Aucune |
| Autre jour, séances faites | « n séance(s) faite(s) » | Noms séparés par des virgules | Total séries, minutes, volume | Aucune | « Voir le détail », ou la liste des séances |
| Autre jour, séance rattrapée ailleurs | « Séance rattrapée » | Nom | « Faite le … à la place. » ou « Rattrapage en cours. » | Aucune | « Voir le détail » ou aperçu des exercices |
| Autre jour, séance prévue | « Prévu » (futur) ou « Prévu, pas fait » (passé) | Nom | « n exercices · n séries · environ n min » | « Rattraper la séance » (jour passé seulement) | Aperçu des exercices |
| Autre jour, rien | La date longue | « Repos » | « Aucune séance prévue ce jour-là. » ou « Aucune séance ce jour-là. » | Aucune | Aucune |

## 4. Fonctions existantes

Liste de référence : aucune planche ne doit en perdre une. 68 fonctions. Colonne « Accès » : **Gratuit**, **Premium**, ou **Mixte** (une partie gratuite, une partie Premium). 12 fonctions sont entièrement Premium, 8 sont mixtes, 48 sont gratuites.

### A. Écran principal

| N° | Fonction | Où elle est | Accès | Données affichées | Actions possibles |
|---|---|---|---|---|---|
| F1 | Sélecteur de semaine | FitnessApp.swift:351 ; WeekSelector.swift:23 | Gratuit | 7 jours, point plein (fait ou rattrapé), point creux (prévu), titre de la semaine | Choisir un jour, changer de semaine (flèches ou balayage), « Aujourd'hui » |
| F2 | Séance du jour choisi, 9 états | FitnessApp.swift:68, 100 | Gratuit | Libellé, nom, détail, barre de progression si en cours | Lire. L'action est dans F3 |
| F3 | Action principale flottante | FitnessApp.swift:141 | Gratuit | Un bouton selon l'état | « Commencer », « Reprendre la séance », « Créer une séance », « Rattraper « nom » d'hier », « Rattraper la séance » |
| F4 | Rattraper une séance manquée | FitnessApp.swift:151-168, 321, 329 ; Fitness.swift:387, 578 | Gratuit | « Séance rattrapée », « Rattrapage de la séance du … », pastille « Rattrapée » dans l'historique | Lancer le rattrapage. Le jour manqué est marqué comme rattrapé |
| F5 | « Faire une séance quand même » un jour de repos | FitnessApp.swift:194-204 | Gratuit | Liste des séances du programme | Lancer une séance |
| F6 | Aperçu de la séance prévue | FitnessApp.swift:299-318 | Gratuit | 4 premiers exercices avec « séries × répétitions · charge », « + n autres » | Lire |
| F7 | Totaux de la semaine choisie | FitnessApp.swift:363-385 | Gratuit | « Durée », « Volume », « Calories » (≈), « Séances » (faites / objectif) | Lire |
| F8 | « À remplir » | MiniAppToFill.swift:11, 41 ; DataItemViews.swift:117-142 | Gratuit | Cartes « Programme d'entraînement », « Séances par semaine », « Poids », « Objectif de pas », compteur n / 4 | « Créer une séance », choisir 1 à 7, taper le poids, choisir 6 000 / 8 000 / 10 000 / 12 000 pas, « Afficher mes pas » |
| F9 | Raccourcis des exercices favoris | FitnessApp.swift:477-495 | Mixte : la liste est visible, la fiche demande Premium | Jusqu'à 6 favoris : nom, muscles, équipement | Ouvrir la fiche |
| F10 | Carte des pas du jour | FitnessApp.swift:389-436 | Gratuit | Anneau, pas, objectif, distance, étages | Ouvrir « Activité », ou « Afficher mes pas » |
| F11 | Fermeture d'une séance oubliée | FitnessApp.swift:50-54 ; Fitness.swift:232, 413 | Gratuit | Rien (automatique) | Après 3 h sans série, la séance est close à sa dernière série |
| F12 | Supprimer une séance faite | FitnessApp.swift:255 ; FitnessPages.swift:166, 173, 252, 495 ; DailySection.swift:785 | Gratuit | Confirmation | Menu « … », appui long, glissement, bouton du détail, appui long sur la carte de Mon quotidien |

### B. Séance en direct

| N° | Fonction | Où elle est | Accès | Données affichées | Actions possibles |
|---|---|---|---|---|---|
| F13 | Démarrer une séance | FitnessApp.swift:336 ; FitnessSession.swift:501 ; DailySection.swift:839 ; FitnessTiles.swift:95, 117 | Gratuit | Nom, « n exercices · environ n min » | Depuis l'écran principal, la liste de choix, Mon quotidien ou un widget. Précision : le bouton « Commencer » d'un widget démarre la séance et note la première série dans le même appui (Fitness.swift:551-562 ; test DomainLogicTests.swift:43-44) |
| F14 | « Séance libre » | FitnessSession.swift:512-520 | Gratuit | « Ajoute les exercices au fur et à mesure » | Démarre une séance vide, puis ouvre la bibliothèque (Premium) ou le formulaire à la main |
| F15 | En-tête de la séance | FitnessSession.swift:135-153 | Gratuit | Nom, chrono depuis le début, « n/m séries », barre | Lire |
| F16 | Carte de l'exercice en cours | FitnessSession.swift:156-180 | Gratuit (le bouton ⓘ demande Premium) | « Série n sur m », nom de l'exercice | Ouvrir la fiche (ⓘ) |
| F17 | « La dernière fois : charge × répétitions » | FitnessSession.swift:130-133, 163 | Premium | Meilleure série de la dernière séance d'un autre jour | Lire |
| F18 | Régler répétitions et charge avant de valider | FitnessSession.swift:181-191 ; Units.swift:88 | Gratuit | « Répétitions », « Charge » (« Corps » si 0) | − / + : 1 répétition (1 à 100), 2,5 kg ou 5 lb |
| F19 | « Série faite » | FitnessSession.swift:217, 376-396 | Gratuit | Bouton principal | Note la série telle que faite, lance le repos. La charge faite devient le plan des séries suivantes de l'exercice |
| F20 | Repos minuté | FitnessSession.swift:193-216, 322-362 | Gratuit | Compte à rebours, « Prêt » à zéro, « Repos en pause · m:ss » | Pause, « Reprendre », « Passer le repos ». Vibration à la fin dans l'app |
| F21 | Alerte de fin de repos par notification | FitnessSession.swift:89-101 ; WorkoutLiveActivity.swift:124-152 | Gratuit | « Repos terminé » / « Prêt pour la prochaine série. » | Proposée une seule fois, au premier repos |
| F22 | « Passer la série » | FitnessSession.swift:222 ; Fitness.swift:246 | Gratuit | Pastille « Passée » | La série n'est ni faite ni comptée. Pas de repos |
| F23 | « Annuler la dernière série » | FitnessSession.swift:232-244, 481-492 ; Fitness.swift:433-505 | Gratuit | Bouton | Défait une série faite ou passée. Rouvre une séance finie par sa dernière série (même jour, moins d'une heure) |
| F24 | « Passer cet exercice » | FitnessSession.swift:246 ; Fitness.swift:423 | Gratuit | Bouton | Passe à l'exercice suivant sans noter les séries restantes |
| F25 | Liste « La séance » | FitnessSession.swift:258-265, 424-475 | Gratuit (ⓘ : Premium) | Chaque exercice : fait, en cours ou à venir ; plan « 4 × 8 · 60 kg » ; pastilles des séries faites ; pastilles « Passée » | Toucher une pastille pour la modifier. Ouvrir une fiche |
| F26 | Modifier ou supprimer une série faite | FitnessSession.swift:586-635 | Gratuit | Répétitions, charge | Changer, « Supprimer cette série ». Marche aussi dans l'historique |
| F27 | Ajouter un exercice de la bibliothèque pendant la séance | FitnessSession.swift:45-61, 266-274 ; Fitness.swift:659 | Premium | « Choisir dans la bibliothèque » | L'exercice s'ajoute à la fin, avec la charge de la dernière fois |
| F28 | Ajouter un exercice écrit à la main pendant la séance | FitnessSession.swift:275, 529-583 | Gratuit | Nom, « Mes exercices », séries (1 à 12), répétitions (1 à 100), charge, repos (15 à 600 s) | Ajouter à la séance en cours |
| F29 | « Terminer la séance » | FitnessSession.swift:283-298 | Gratuit | Confirmation « Terminer et enregistrer » | Les séries faites vont dans l'historique |
| F30 | « Annuler la séance » | FitnessSession.swift:301-311 ; Fitness.swift:509 | Gratuit | Confirmation si des séries sont notées | La séance n'est jamais comptée |
| F31 | Fin automatique à la dernière série | FitnessSession.swift:391 ; Fitness.swift:182-186 | Gratuit | La page passe au choix d'une séance (E3) | Rien à faire |

### C. Programme

| N° | Fonction | Où elle est | Accès | Données affichées | Actions possibles |
|---|---|---|---|---|---|
| F32 | « Ma semaine » | FitnessPages.swift:21-58, 114-125 | Gratuit | Lundi à dimanche : nom de la séance (ou « A + B »), sinon « Repos » | Menu par jour : cocher ou décocher une séance |
| F33 | « Mes séances » | FitnessPages.swift:60-88, 103-111 | Gratuit | Nom, exercices, « n exercices · environ n min » | Toucher pour modifier, « Nouvelle séance », glisser pour supprimer (confirmé) |
| F34 | Objectif de séances par semaine | FitnessPages.swift:90-94 ; AppModel.swift:1269 | Gratuit | « Objectif » : « n séances / semaine » | − / + de 1 à 7 |
| F35 | Éditeur de séance | FitnessSpace.swift:157-250 | Gratuit | Nom, jours, exercices | Séries 1 à 12, répétitions 1 à 50 (1 à 100 dans S4 et S6), charge, repos 15 à 600 s par pas de 15, tempo, notes, « Retirer le dernier exercice » |
| F36 | Ajouter un exercice à une séance du programme | FitnessSpace.swift:167-186 | Mixte : « Ajouter un exercice » (à la main) gratuit, « Choisir dans la bibliothèque » Premium | Deux boutons sous le nom et les jours | Ajouter une ligne vide, ou choisir dans la bibliothèque |
| F37 | Suggestions pendant la saisie du nom | FitnessSpace.swift:209-219 | Premium | 3 exercices au plus, dès 2 lettres | Toucher pour relier l'exercice à la bibliothèque |
| F38 | Durée estimée d'une séance | FitnessApp.swift:528-531 | Gratuit | « environ n min » | Lire |

### D. Bibliothèque et fiches

| N° | Fonction | Où elle est | Accès | Données affichées | Actions possibles |
|---|---|---|---|---|---|
| F39 | Bibliothèque de 163 exercices | ExerciseLibrary.swift:575 ; ExerciseLibraryViews.swift:21 | Mixte : la liste est visible par tous, chaque exercice s'ouvre avec Premium | Nom, « muscles · équipement · niveau » | Ouvrir un exercice |
| F40 | Recherche au fil de la frappe | ExerciseLibraryViews.swift:135 ; ExerciseLibrary.swift:913 | Mixte : résultats visibles, ouverture Premium | Nombre de résultats, liste | Taper un nom, un autre nom, un muscle, un équipement. Sans accents aussi |
| F41 | Filtres | ExerciseLibraryViews.swift:150-181 | Mixte : comme F40 | « Muscle » (13 groupes), « Équipement » (10), « Type » (4), « Niveau » (3) | Choisir, « Effacer » |
| F42 | Raccourcis de la bibliothèque | ExerciseLibraryViews.swift:78-117 | Mixte : comme F40 | « Favoris », « Récents » (en mode choix seulement), « Les plus faits », « Par muscle » avec le nombre | Ouvrir, ou filtrer par muscle |
| F43 | Favoris | ExerciseLibraryViews.swift:256-263, 459-468 ; Fitness.swift:351 | Mixte : le glissement marche pour tous, l'étoile de la fiche demande Premium | Étoile | Glisser une ligne (« Favori » / « Retirer »), ou étoile en haut de la fiche |
| F44 | « Mes exercices » | ExerciseLibraryViews.swift:84-101, 655-685 | Gratuit | Nom, « muscle · équipement » | « Créer un exercice », glisser pour supprimer |
| F45 | Démonstration animée | ExerciseDemo.swift:9-94 | Premium | Personnage qui fait le mouvement sur son matériel, bande des phases, nom de la phase en cours (« Poussée »…), petit bouton pause ou lecture en haut à droite | Toucher l'image pour mettre en pause ou relancer. Choisir la vue : deux vues par exercice parmi « Profil », « 3/4 », « Face », « Dessus » (trois pour le pec deck). Précision : avec « Réduire les animations » de l'iPhone, la démonstration reste à l'arrêt tant qu'on ne la touche pas (ExerciseDemo.swift:76) |
| F46 | Identité de l'exercice | ExerciseLibraryViews.swift:335-359 | Premium | Légende « Muscles principaux » / « secondaires », pastilles type, niveau, équipement, « Principalement », « Aussi » | Lire |
| F47 | Technique | ExerciseLibraryViews.swift:361-389, 421 | Premium | « Position de départ », « Exécution » (étapes numérotées, amplitude, respiration), « Points importants », « À éviter ». En bas de la fiche, la note de prudence : « Consignes générales : adapte la charge à ton niveau et arrête en cas de douleur. En cas de doute, demande à un professionnel. » | Lire |
| F48 | « Mes performances » | ExerciseLibraryViews.swift:542-588 (le message « L'évolution de tes charges sur cet exercice est dans Premium. », ligne 565, est du code mort en pratique : la fiche entière demande Premium) | Premium | Dernière séance, « Record » avec « 1RM ≈ », « Volume » de la dernière séance, « Fréquence » en 30 jours, courbe de la charge la plus lourde (dès 3 séances) | Lire |
| F49 | « Alternatives » | ExerciseLibraryViews.swift:393-419 ; ExerciseLibrary.swift:941 | Premium | 5 au plus : « Variante » ou « Mêmes muscles » | Ouvrir l'autre fiche |
| F50 | Ajouter l'exercice à une séance | ExerciseLibraryViews.swift:426-455, 484-499, 595-652 | Premium | « Ajouter à ma séance » ou « Ajouter à une séance », puis « Ajouté à « nom » » | Séance en cours : ajout direct, « Voir la séance ». Sinon : feuille S6 |
| F51 | Fiche ouverte par-dessus l'écran en cours | ExerciseLibraryViews.swift:285-300 | Premium | La fiche en feuille | « Fermer » ramène où on était |

### E. Historique

| N° | Fonction | Où elle est | Accès | Données affichées | Actions possibles |
|---|---|---|---|---|---|
| F52 | Liste des séances faites | FitnessPages.swift:130-189 | Gratuit | Par mois : nom, « Rattrapée », date, « n min · n séries · volume » | Ouvrir, supprimer |
| F53 | Détail d'une séance | FitnessPages.swift:191-271 | Gratuit (ⓘ : Premium) | « Date », « Séance rattrapée », « Durée », « Volume », séries par exercice avec l'heure | Modifier une série, ouvrir la fiche, « Supprimer la séance » |

### F. Progression

| N° | Fonction | Où elle est | Accès | Données affichées | Actions possibles |
|---|---|---|---|---|---|
| F54 | « Volume par semaine » | FitnessPages.swift:303-314, 379-385 | Premium | Barres des 8 dernières semaines | Lire |
| F55 | « Records » | FitnessPages.swift:316-376 ; SectionIndex.swift:8 | Premium | Un record par exercice, de A à Z, « +n kg depuis le début · n séances », valeur « charge × répétitions » | Index alphabétique à gauche, ouvrir la fiche |

### G. Pas

| N° | Fonction | Où elle est | Accès | Données affichées | Actions possibles |
|---|---|---|---|---|---|
| F56 | Page « Activité » | FitnessPages.swift:391-489 ; StepCounter.swift:8 | Gratuit | « Pas » (objectif), « Distance », « Étages », « Calories actives » (~), « 7 derniers jours » avec moyenne et ligne d'objectif | Changer de jour, choisir une date |

### H. Réglages

| N° | Fonction | Où elle est | Accès | Données affichées | Actions possibles |
|---|---|---|---|---|---|
| F57 | « Mes paramètres » | MiniAppSettings.swift:184 ; ProfileTopics.swift:401-434 | Gratuit | « Rappel de séance » (heure ou « Désactivé »), « Ton objectif », « Es-tu enceinte ou allaitante ? » (selon l'objectif), « Ton niveau », « Séances par semaine », « Toi », « Tes données » (objectif de pas) | Tout modifier. Les mêmes réponses que « Mes informations » |
| F58 | Unités kg ou lb | Units.swift:88 ; FitnessApp.swift:369 | Gratuit | Toutes les charges et le poids | Réglage général de l'app. Les valeurs restent enregistrées en kg |

### I. Hors de la mini-app

| N° | Fonction | Où elle est | Accès | Données affichées | Actions possibles |
|---|---|---|---|---|---|
| F59 | Carte Fitness de Mon quotidien, page « Séance » | DailySection.swift:808-953 ; DailyBrief.swift:477-507 | Gratuit | Prévue : nom, « n exercices · n séries ». En cours : exercice, « Série n/m · répétitions × charge », repos. Faite : « Faite · n séries », volume. Repos : « Repos aujourd'hui », prochaine séance | « Commencer », « Série faite », pause ou reprise du repos, appui long « Supprimer la séance », toucher pour ouvrir Fitness |
| F60 | Carte Fitness de Mon quotidien, page « Semaine » | DailySection.swift:1730-1766 | Gratuit | « n/objectif séances », 7 ronds, « Encore n séances » ou « Objectif de la semaine atteint » | Toucher pour ouvrir Fitness |
| F61 | Carte « Pas » de Mon quotidien | DailySection.swift:1212-1239, 1768-1790 | Gratuit | Pas / objectif, barre ; 7 jours et moyenne | Toucher pour ouvrir « Activité » |
| F62 | Activité en direct | WorkoutLiveActivity.swift:156 ; Widgets/WorkoutLiveActivityWidget.swift:7 | Gratuit | Écran verrouillé : nom de la séance, exercice, « Série n/m · charge », repos (« Repos » + compte à rebours, « En pause », ou « Prêt »), barre. Dynamic Island ouverte : exercice, « Série n/m », repos ou « n/m ». Dynamic Island fermée : icône à gauche, repos ou « n/m » à droite | « Série faite », « Passer », « Pause » / « Reprendre », flèche retour (annule la dernière série) ou croix (annule la séance). Mêmes boutons sur l'écran verrouillé et dans la Dynamic Island ouverte |
| F63 | Widgets Fitness | KindCatalog.swift:167-175, 264 ; FitnessTiles.swift:6 | Mixte : 3 gratuits, 6 Premium | Voir la section 6 | « Commencer », « Série faite », « Passer », retour, sur les widgets interactifs |
| F64 | Rappels et encouragements | SmartReminders.swift:32-43 ; NotificationEngine.swift:539-586 ; Encouragements.swift:207-253 | Gratuit | Voir la section 6 | Régler dans « Rappels » |
| F65 | Séances prévues dans l'agenda de Planning | Agenda.swift:85-91 | Gratuit | Nom, « Séance · environ n min », sans heure | Voir le jour |
| F66 | Données Fitness dans Créer | FitnessSpace.swift:3-119 | Gratuit (« Meilleur record » : Premium) | « Séance », « Mes séances », « Suivi » (objectif, poids, « Cette semaine », « Volume », « Meilleur record ») | « Commencer la séance », « Série faite », « Terminer la séance », créer ou modifier une séance |
| F67 | Objectif et activité partagés avec Nutrition | Profile.swift:425 ; ProfileTopics.swift:383 ; AppModel.swift:1336 ; Nutrition.swift:1095 | Gratuit | « Ton objectif » : « Le même pour Sport et Nutrition. » | Les séances par semaine donnent le niveau d'activité du calcul des besoins |
| F68 | Pastille Fitness de l'accueil (rangée des mini-apps) | MiniAppsRow.swift:70-73, 160-170 ; DailyCategories.swift:28 | Gratuit | « Séance en cours » ou « n séance(s) cette semaine » | Toucher ouvre l'écran principal de Fitness (`HomeRoute.app`, MiniAppsRow.swift:160). Appui long : « Masquer de l'accueil » (MiniAppsRow.swift:170) |

## 5. Données et calculs

### Modèles (Fitness.swift). Tout est enregistré dans le fichier `fitness` de l'App Group.

- `Routine` (ligne 80) : nom, exercices, jours ISO (1 = lundi … 7 = dimanche).
- `ExerciseTemplate` (ligne 3) : nom, séries, répétitions, charge en kg, repos en secondes (90 par défaut), identifiant de bibliothèque (facultatif), tempo, notes.
- `CustomExercise` (ligne 51) : nom, muscle, équipement, type, notes.
- `SetLog` (ligne 88) : nom de l'exercice, répétitions, charge, date et heure, identifiant de bibliothèque.
- `SkippedSet` (ligne 100) : une série passée, gardée à part.
- `WorkoutSession` (ligne 147) : séance d'origine, nom, exercices, début, fin, séries faites, position (exercice et série), fin du repos, repos en pause, jour rattrapé, séries passées.
- `FitnessState` (ligne 324) : séances du programme, séance en cours, historique (2 000 séances au plus, ligne 395), objectif par semaine (3 par défaut), poids par défaut 70 kg, « Mes exercices », favoris, récents (15 au plus).
- `WorkoutPosition` (ligne 111) : la position que porte chaque bouton hors de l'app. Un second appui sur un dessin périmé est ignoré.
- Bibliothèque (ExerciseLibrary.swift) : 163 `ExerciseInfo` (ligne 147), soit 124 de musculation, 21 de cardio, 10 d'étirement, 8 de mobilité ; 102 débutant, 54 intermédiaire, 7 avancé. 16 muscles, 13 groupes de filtre, 10 équipements, 4 types, 3 niveaux. Technique propre pour 68 exercices (ExerciseTechniques.swift), technique de la famille pour les autres.
- Démonstrations : `App/Resources/ExerciseDemos.json`, 163 sur 163 (recompté : aucun exercice sans démonstration, aucune démonstration en trop). 162 ont 2 vues, 1 en a 3 (le pec deck). Paires de vues : « Profil » + « 3/4 » pour 137 exercices, les autres mêlent « Face », « 3/4 », « Profil » et « Dessus ». 140 ont des phases nommées (4 le plus souvent). 23 n'en ont pas et affichent « Mouvement continu » (ExerciseDemo.swift:104) : marche, course, vélo, corde à sauter, natation, mountain climbers… Les noms des phases et des vues viennent du fichier, en français seulement (voir le problème 34).
- Récents : ouvrir une fiche range l'exercice en tête des « Récents » (ExerciseLibraryViews.swift:477-479 ; Fitness.swift:359-363).
- Pas : `StepCounter` (capteur de mouvement, sans Santé). L'iPhone garde environ 7 jours ; Ardane garde chaque jour lu (StepCounter.swift:71-99).
- Ailleurs : poids, objectif de pas, objectif et niveau dans le profil (Profile.swift:332-335) ; rappels dans les réglages (Settings.swift:119-134).

### Ce qui est saisi

Séances, jours, exercices, séries, répétitions, charge, repos, tempo, notes. Répétitions et charge réellement faites à chaque série. « Mes exercices ». Favoris. Objectif de séances par semaine. Poids. Objectif de pas. Objectif et niveau.

### Ce qui est calculé (à ne pas modifier)

1. **Volume** = somme des répétitions × charge (Fitness.swift:96, 168, 605).
2. **Séances de la semaine** = nombre de jours différents avec une séance, séance en cours comprise dès sa première série (Fitness.swift:571-588).
3. **Série de semaines** = semaines de suite à l'objectif (Fitness.swift:591-602). Affichée seulement dans les widgets.
4. **Record** d'un exercice = la série au meilleur 1RM estimé, formule d'Epley : charge × (1 + répétitions / 30) (Fitness.swift:617-628, 650).
5. **Calories actives d'une séance** (CalorieModel.swift:19-112) : série chargée MET 5,0, au poids du corps 3,8, repos 2,0, moins 1 MET de repos ; 3,5 s par répétition + 15 s, entre 25 et 90 s par série ; pauses plafonnées à 10 minutes ; séries passées ignorées ; aucun chiffre sans poids connu.
6. **Calories des pas** : 0,04 kcal par pas pour 70 kg, selon le poids, moins 30 pas par minute de séance (CalorieModel.swift:40-45, 118-123).
7. **Durée estimée d'une séance** = 40 s par série + repos, 5 minutes au moins (FitnessApp.swift:528-531 ; même formule dans Agenda.swift:88).
8. **Durée réelle** = fin moins début (Fitness.swift:318-321). Durée de la semaine = somme (Fitness.swift:698-701).
9. **Séance oubliée** : close après 3 h sans série (Fitness.swift:232). **Annulation de la dernière série** d'une séance finie : 1 h, même jour (Fitness.swift:433-444).
10. **Reprise de la dernière fois** pour un exercice ajouté en séance : série la plus lourde, 3 × 10 sinon (Fitness.swift:659-665).
11. **Prochaine séance prévue** dans les 7 jours (Fitness.swift:710-717). **Rattrapage** (Fitness.swift:578-582).
12. **Séance proposée par les widgets** : celle du jour, sinon la première du programme (Fitness.swift:377-380).
13. **« Les plus faits »** : exercices présents dans le plus de séances (Fitness.swift:688-695).
14. **« Fréquence »** d'une fiche : séances avec cet exercice sur 30 jours (ExerciseLibraryViews.swift:546). **Gain d'un record** : record moins la plus lourde charge de la première séance (FitnessPages.swift:370-372).
15. **Pas de charge** : 2,5 kg ou 5 lb (Units.swift:88-95).
16. **Recherche** : classement des résultats et correspondance d'un nom tapé avec la bibliothèque (ExerciseLibrary.swift:886-938). **Alternatives** : même muscle principal et même type, variantes d'abord (ExerciseLibrary.swift:941-946).
17. **Niveau d'activité de Nutrition** d'après les séances par semaine (Nutrition.swift:1095).

Règles vérifiées par des tests : `FitnessAppTests`, `WorkoutSkipTests`, `WorkoutUndoTests`, `WorkoutDeleteTests`, `CalorieModelTests`, `Audit24FitnessPlanningTests`, `ExerciseDemoTests`, `SectionIndexTests` (dossier `Tests/`).

## 6. Liens

### Carte de Mon quotidien

- **Taille** : pleine largeur par défaut, comme Nutrition, Planning, Habitudes et Top 3 (DailyDefaults.swift:21). Mon quotidien n'a que deux largeurs : demi et pleine. « Moyen » et « grand » sont la même largeur (DailyDefaults.swift:19-20).
- **Place** : deuxième, après Nutrition (DailyDefaults.swift:11-14). Toujours présente (DailyDefaults.swift:17).
- **Deux pages** qu'on balaie : « Séance » et « Semaine » (DailySection.swift:432-434). Contenu : F59 et F60.
- **Sans programme** : carte vide « Crée ton programme : ta séance du jour apparaîtra ici. » qui ouvre Fitness (DailyBrief.swift:229, 480).
- **Pastille « Maintenant »** : séance en cours, ou séance prévue à partir de l'après-midi (DailySection.swift:898-909).
- **Toucher la carte** ouvre l'écran principal de Fitness (DailySection.swift:824 ; HomeView.swift:26-29).
- **Carte « Pas »** : demi-largeur, pages « Aujourd'hui » et « 7 jours », ouvre « Activité » (DailySection.swift:437-439, 1218).

### Widgets (KindCatalog.swift:167-175, 264)

| Widget | Accès | Tailles | Ce qu'il montre |
|---|---|---|---|
| « Séance du jour » | Gratuit | Petit, moyen, grand | Séance, exercices, « Commencer » ou « Série faite » |
| « Prochaine série » | Gratuit | Petit, moyen, écran verrouillé (rectangle) | Série à faire, repos, « Série faite », retour, « Passer » |
| « Régularité » | Gratuit | Petit, moyen, écran verrouillé (cercle) | « n/objectif », semaine en ronds, série de semaines |
| « Repos » | Premium | Petit, moyen, écran verrouillé (cercle, rectangle) | Compte à rebours, « Passer », « Fait » |
| « Volume de la semaine » | Premium | Petit, moyen, grand | Volume par jour, écart avec la semaine d'avant |
| « Records » | Premium | Petit, moyen, grand | Meilleure charge, 6 records, 1RM estimé |
| « Calories brûlées » | Premium | Petit, moyen | Calories du jour et de la semaine. Demande le poids |
| « Mois d'entraînement » | Premium | Petit, moyen, grand | Calendrier du mois, jours d'entraînement |
| « Tableau fitness » | Premium | Moyen, grand | Séances de la semaine, série de semaines, prochaine série ou séance du jour, volume, calories du jour (si le poids est connu), protéines du jour si des repas sont notés (DashboardTiles.swift:175-198) |

Les widgets montrent des données que la mini-app ne montre pas : la série de semaines, le calendrier du mois, les calories du jour, l'écart avec la semaine d'avant (FitnessTiles.swift:155-244).

Précision sur les boutons des widgets (FitnessTiles.swift:43-66) : « Série faite » (ou « Commencer » sans séance en cours), puis la flèche retour (ou la croix), puis « Passer ». Sans séance en cours, « Commencer » démarre la séance prévue et note sa première série dans le même appui (Fitness.swift:551-562). Un jour sans séance prévue, le widget démarre la première séance du programme (Fitness.swift:377-380).

### Activité en direct

Écran verrouillé et Dynamic Island (WorkoutLiveActivity.swift:52-121). Elle suit la séance en cours : exercice, « Série n/m · charge », repos qui défile ou « Prêt », barre de progression. Boutons : « Série faite », « Passer », « Pause » ou « Reprendre », flèche retour ou croix. Elle prend les couleurs du style de l'app, pas le rouge de Fitness (WorkoutLiveActivity.swift:164-165). Dynamic Island (Widgets/WorkoutLiveActivityWidget.swift:17-72) : ouverte, elle montre l'exercice et « Série n/m » à gauche, le repos ou « n/m » à droite, et les mêmes boutons en bas ; fermée, une icône à gauche et le repos ou « n/m » à droite ; en tout petit, une icône seule (un chrono pendant le repos). Elle démarre avec la séance et s'arrête avec elle (AppModel.swift:155-158 ; WorkoutLiveActivity.swift:52-54).

### Autres mini-apps et écrans

- **Nutrition** : même objectif (« Ton objectif »), même poids ; les séances par semaine donnent le niveau d'activité (AppModel.swift:1336).
- **Planning** : les séances prévues sont dans l'agenda du jour, sans heure (Agenda.swift:85-91). Toucher une séance montre le jour, pas Fitness (PlanningApp.swift:284).
- **Mes informations** : sujet « Sport », mêmes réponses que « Mes paramètres » (ProfileTopics.swift:401).
- **Créer** : page de données Fitness (H4), aperçu de l'activité en direct (H5), packs du Store qui contiennent des widgets Fitness (Packs.swift:63, 87, 119).
- **Tutoriel** : l'étape « Mon quotidien » montre la carte Fitness (Tutorial.swift:29).
- **Demande de note** : une séance enregistrée compte comme un bon moment (AppModel.swift:186-189).

### Notifications et rappels

| Titre | Quand | Preuve |
|---|---|---|
| « Ta séance t'attend » | Jour avec une séance prévue, à l'heure choisie (18 h par défaut), si elle n'est pas commencée | SmartReminders.swift:32-43 |
| « Ta semaine sportive » | Midi, jour d'entraînement, objectif pas encore atteint | NotificationEngine.swift:548-555 |
| « Un petit tour ? » | 17 h, objectif de pas pas atteint, accès aux pas autorisé | NotificationEngine.swift:558-562 |
| « Séance demain » | La veille au soir | NotificationEngine.swift:565-571 |
| « Bilan sportif de la semaine » | Dimanche soir, s'il y a eu au moins une séance | NotificationEngine.swift:574-584 |
| « Nouvelle semaine » | Lundi matin | NotificationEngine.swift:705-714 |
| « Repos terminé » | À la fin d'un repos, app en arrière-plan | WorkoutLiveActivity.swift:124-152 |
| « Séance terminée », « Belle progression », « Objectif de la semaine atteint » | Après une séance enregistrée, 2 encouragements par jour au plus | Encouragements.swift:207-253 |

Rien un jour de repos (SmartRemindersView.swift:71). Réglages : « Rappels » › Fitness › « Séance du jour » et son heure (SmartRemindersView.swift:59-68).

### Liens profonds

- Autres entrées sans écran propre : les boutons des activités en direct et des widgets sont des intents (`CompleteSetIntent`, `SkipSetIntent`, `UndoSetIntent`, `CancelWorkoutIntent`, `PauseRestIntent`, `ResumeRestIntent`, `SkipRestIntent`, SpaceIntents.swift:93-213) ; pas de raccourci Siri ni d'`AppShortcutsProvider` pour Fitness (ApplePayIntent.swift:12). Précision : `SkipRestIntent` (« Passer le repos ») est défini mais aucun bouton ne l'utilise ; hors de l'app, « Passer » passe la série, pas le repos (Decisions.md, 2026-10-22). « Passer le repos » n'existe que sur la page « Séance ».
- Un seul lien externe : `tessera://space/fitness`. Il ouvre l'écran principal (DeepLink.swift:13-14 ; Router.swift:168-171). Widgets et notifications l'utilisent (SmartReminders.swift:151-171).
- Aucun lien externe vers la séance en cours, une fiche ou « Progression ».
- Routes internes : 8 pages `MiniAppPage` (MiniApp.swift:87-94).

## 7. États vides, première utilisation, erreurs, permissions, limites du mode gratuit

### Première utilisation (aucun programme)

- En grand : « Aujourd'hui » / « Ton programme » / « Crée tes séances (exercices, séries, charges, repos) et choisis leurs jours : Ardane te propose chaque jour la bonne. » (FitnessApp.swift:119-121).
- Bouton flottant « Créer une séance » (FitnessApp.swift:157-160).
- « À remplir » 0 / 4 avec ses quatre cartes (MiniAppToFill.swift:11).
- Tuiles de la semaine à zéro, « Calories » « — » sans poids (FitnessApp.swift:381), « Séances » « 0 / 3 ».
- Mon quotidien : carte vide « Crée ton programme : ta séance du jour apparaîtra ici. » (DailyBrief.swift:229).
- Widgets : « Crée ta première séance dans Ardane, espace Fitness. » (FitnessTiles.swift:4).

### États vides

- « Programme », menu d'un jour : « Crée d'abord une séance » (FitnessPages.swift:36-38).
- « Historique » : « Aucune séance pour l'instant. Commence celle du jour depuis Fitness : elle s'enregistre ici. » (FitnessPages.swift:143).
- Détail : « Séance introuvable. » (FitnessPages.swift:260).
- « Progression » avec Premium, sans séance : « Pas encore de progression » / « Fais quelques séances : tes charges, ton volume et tes records apparaîtront ici. » (FitnessPages.swift:298).
- Bibliothèque sans résultat : « Aucun exercice ne correspond. Essaie un autre mot ou retire un filtre. » (ExerciseLibraryViews.swift:122).
- Choix d'une séance sans programme : « Aucune séance dans ton programme : crée-en une dans Programme. » (FitnessSession.swift:496).
- Fiche sans séance faite : pas de section « Mes performances » (ExerciseLibraryViews.swift:544).
- Fiche sans démonstration : « Démonstration indisponible » (ExerciseDemo.swift:26). Aucun cas aujourd'hui : 163 démonstrations pour 163 exercices.
- Exercice inconnu : « Exercice introuvable » (MiniApp.swift:185).
- « Activité », jour ancien sans donnée : « Pas de données de pas pour ce jour : l'iPhone garde environ une semaine, Ardane garde ensuite chaque jour lu. » (FitnessPages.swift:419).

### Permissions

- **Mouvement et pas** (capteur de l'iPhone, pas Santé). Explication d'abord, puis demande du système (FitnessApp.swift:419 ; PermissionExplainer.swift:91, 101). Jamais demandé : « Tes pas » / « Autoriser » (FitnessPages.swift:462). Refusé : « Accès refusé » / « Ouvrir Réglages » (FitnessPages.swift:468). Appareil sans capteur : « Pas disponible » (FitnessPages.swift:473).
- **Notifications** pour l'alerte de fin de repos. Proposée une seule fois, au premier repos, quelle que soit la réponse (FitnessSession.swift:85-101, 639-654). Refusée : le repos finit sans alerte.
- **Activités en direct** : si elles sont coupées dans les Réglages de l'iPhone, rien ne s'affiche et l'app ne dit rien (WorkoutLiveActivity.swift:113).
- Ardane ne lit pas et n'écrit pas Apple Santé (CalorieModel.swift:8-11).

### Erreurs et gardes

- Double appui sur « Série faite » : compté une fois (`TapGuard`, MiniApp.swift:392 ; `WorkoutPosition`, Fitness.swift:470-479).
- Séance laissée ouverte : close après 3 h (FitnessApp.swift:50-54).
- « Séance libre » fermée sans exercice : la séance vide disparaît (FitnessSession.swift:76-79).
- Séance terminée sans aucune série faite : pas dans l'historique (Fitness.swift:399-408).
- Second appui sur « Passer cet exercice » : ignoré, pour ne pas passer deux exercices (FitnessSession.swift:245-250 ; Fitness.swift:423-424).
- « Réduire les animations » de l'iPhone : la démonstration d'un exercice ne démarre pas seule (ExerciseDemo.swift:76).
- Captures de la CI (mode `-screenshotScreen`) : pas de feuille de notification ni d'activité en direct (FitnessSession.swift:90-93 ; WorkoutLiveActivity.swift:80-88). Une capture ne montre donc jamais ces deux éléments.

### Limites du mode gratuit (Decisions.md, 2026-10-15 ; ExerciseLibrary.swift:577-583)

- **Gratuit** : programme, séances, séance en direct, séries notées, exercices écrits à la main, « Mes exercices », historique, totaux de la semaine, pas, activité en direct, 3 widgets. Aucune limite de nombre de séances.
- **Premium** : ouvrir un exercice de la bibliothèque (fiche, démonstration, technique, alternatives, performances), « Choisir dans la bibliothèque », suggestions de nom, « La dernière fois », « Progression », « Meilleur record », 6 widgets.
- **Ce que voit une personne sans Premium** : badge Premium sur les lignes « Exercices » et « Progression » et sur chaque favori (FitnessApp.swift:498-509). Dans la bibliothèque, carte « Toute la bibliothèque d'exercices » et chaque ligne grisée avec un badge (ExerciseLibraryViews.swift:48-76, 218-230). Dans « Progression », carte « La progression est dans Premium » (FitnessPages.swift:295). Sur une fiche, « Cet exercice est dans Premium » (ExerciseLibraryViews.swift:708).
- Rien n'est effacé : les séries restent enregistrées et tout s'affiche dès le passage à Premium.
- Limite générale de l'app : 3 widgets enregistrés en gratuit (AppModel.swift:12).

## 8. Problèmes d'UX constatés aujourd'hui

1. **Quatre pages sur dix n'ont qu'une porte, placée bas.** « Programme », « Historique », « Exercices » et « Progression » ne s'ouvrent que par la carte « Programme », après la séance du jour, « À remplir » et les quatre tuiles (FitnessApp.swift:38-44). Sur la capture `tests/mini-app-fitness.png`, seule sa première ligne est visible et le bouton flottant la recouvre.
2. **Le titre « Programme » couvre autre chose que le programme.** La carte contient aussi l'historique, la bibliothèque et la progression (FitnessApp.swift:443-471).
3. **Deux blocs s'appellent « Exercices »** sur le même écran : la ligne de la bibliothèque (FitnessApp.swift:460) et le titre des favoris (FitnessApp.swift:481).
4. **Un même objet, plusieurs noms.** La ligne « Séances faites » ouvre une page « Historique » (FitnessApp.swift:453 ; FitnessPages.swift:185). La carte de Mon quotidien s'appelle « Séance », « Séance du jour » ou « Sport » selon l'état (DailySection.swift:913-918). La carte des pas ouvre une page « Activité » (FitnessPages.swift:477).
5. **Pendant une séance, l'écran principal ne permet pas de valider une série.** Il montre seulement « Reprendre la séance » (FitnessApp.swift:143-146, 544). La carte de Mon quotidien et les widgets ont « Série faite » (DailySection.swift:864).
6. **Pas d'écran de fin de séance.** Après la dernière « Série faite », la page affiche « Choisis la séance à faire. » avec « Annuler la dernière série » (FitnessSession.swift:31-35, 391, 479-493). Aucun récapitulatif à cet endroit.
7. **« Séance libre » n'a pas d'accès direct.** Elle n'existe que sur l'écran de choix (FitnessSession.swift:512-520). Cet écran ne s'ouvre que depuis la page « Séance », qui n'est poussée qu'avec une séance en cours (FitnessApp.swift:145, 339 ; ExerciseLibraryViews.swift:437). Précision : on ne le voit donc qu'à la fin d'une séance, tant qu'on reste sur la page (voir aussi le problème 32).
8. **Sept actions en texte autour de « Série faite ».** Trois commencent par « Passer » (« Passer le repos », « Passer la série », « Passer cet exercice ») et deux par « Annuler » (« Annuler la dernière série », « Annuler la séance »), plus « Terminer la séance » et la pause (FitnessSession.swift:209, 227, 239, 246, 286, 304 ; capture `tests/mini-app-fitness-session.png`).
9. **La charge ne se tape pas pendant la séance.** Seulement − / + par 2,5 kg ou 5 lb (FitnessSession.swift:187-191 ; Units.swift:88-95). La saisie au clavier n'existe qu'après, en touchant la pastille de la série (FitnessSession.swift:597).
10. **Le temps de repos ne se règle pas pendant la séance.** Pause, « Reprendre » et « Passer le repos » seulement (FitnessSession.swift:193-216). Il se règle par exercice dans l'éditeur (FitnessSpace.swift:223). Un exercice ajouté depuis la bibliothèque reçoit 90 s (Fitness.swift:9, 659-665). Précision : le repos prévu d'un exercice ne s'affiche nulle part avant de démarrer, ni sur la page « Séance », ni dans l'aperçu de la séance, ni dans « Programme » ; ces écrans montrent « séries × répétitions · charge » seulement (FitnessApp.swift:522-525). On ne le lit que dans l'éditeur de séance.
11. **Tempo et notes sont saisis mais jamais affichés.** Ils sont demandés dans l'éditeur de séance (FitnessSpace.swift:224-225) et dans S6 (ExerciseLibraryViews.swift:629-630). Aucun écran ne les relit, ni la séance, ni les widgets. Même chose pour les notes de « Mes exercices » (ExerciseLibraryViews.swift:676).
12. **L'éditeur de séance ne permet ni de changer l'ordre ni de retirer un exercice précis.** Seulement « Retirer le dernier exercice » (FitnessSpace.swift:229-235). Chaque exercice prend 7 lignes dans un seul long formulaire (FitnessSpace.swift:187-227).
13. **Deux séances le même jour : une seule est proposée.** « Programme » accepte « A + B » (FitnessPages.swift:44). L'écran principal, Mon quotidien et les widgets ne proposent que la première (FitnessApp.swift:75, 82 ; Fitness.swift:377-380).
14. **Un jour de repos ne se lit pas pareil partout.** Fitness et Mon quotidien disent « Repos » (FitnessApp.swift:78 ; DailyBrief.swift:495-506). Les widgets et la page de Créer proposent la première séance du programme comme « Prochaine séance » (FitnessTiles.swift:69-75, 106-121 ; FitnessSpace.swift:43-49).
15. **Trois comptes différents des séances.** La tuile « Séances » compte les jours avec une séance, séance en cours comprise (Fitness.swift:571-588). La page « Semaine » de Mon quotidien compte les séances finies (DailySection.swift:1738-1740). La ligne « Séances faites » compte toutes les séances, celle en cours comprise (FitnessApp.swift:453).
16. **L'objectif « / 3 » s'affiche même s'il n'a jamais été choisi.** C'est la valeur par défaut (Fitness.swift:328 ; FitnessApp.swift:373 ; DailySection.swift:1741). Le widget « Régularité », lui, masque l'objectif dans ce cas (FitnessTiles.swift:204-212).
17. **Le même réglage à plusieurs endroits.** Les séances par semaine se règlent dans « Programme » (FitnessPages.swift:91), « Mes paramètres » (ProfileTopics.swift:412), « À remplir » (DataItemViews.swift:121) et Créer (FitnessSpace.swift:81). À la première utilisation, deux boutons « Créer une séance » sont visibles et n'ouvrent pas le même formulaire : sans exercice (FitnessApp.swift:159) ou avec un exercice vide 3 × 10 (DataItemViews.swift:119).
18. **La tuile « Calories » n'a pas d'unité.** « ≈ 103 » seul, alors que « Volume » affiche « kg » (FitnessApp.swift:369, 372 ; capture `tests/mini-app-fitness.png`). Sans poids, elle affiche « — » sans explication sur la tuile (FitnessApp.swift:381).
19. **La note de bas de page dit que les volumes sont estimés à partir du poids.** Le volume est répétitions × charge, sans le poids (FitnessApp.swift:46 ; Fitness.swift:168).
20. **La même barre, deux couleurs.** La barre de progression est noire sur l'écran principal (FitnessApp.swift:108) et rouge sur la page « Séance » (FitnessSession.swift:153). Sur Mon quotidien, « Série faite » prend la couleur de l'accueil, bleue sur la capture `home-light.jpg` (DailySection.swift:943-949), et non le rouge de Fitness.
21. **Sur Mon quotidien, la pastille « Maintenant » remplace le titre de la carte.** L'en-tête ne montre plus que l'icône, sans titre ni chevron (DailySection.swift:495-506 ; capture `home-light.jpg`).
22. **« Commencer » ne fait pas la même chose aux deux endroits.** Dans Fitness il ouvre la page « Séance » (FitnessApp.swift:336-340). Sur Mon quotidien il lance la séance et reste sur l'accueil (DailySection.swift:839-843). Précision : sur un widget, « Commencer » lance la séance et note aussi la première série, avec les répétitions et la charge prévues (FitnessTiles.swift:95 ; Fitness.swift:551-562). Trois effets pour le même mot.
23. **Bibliothèque : deux cibles par ligne pour le même contenu.** La ligne ouvre la fiche en page, le bouton ⓘ ouvre la même fiche en feuille (ExerciseLibraryViews.swift:239-254). Le favori ne se pose que par un glissement de la ligne, sans bouton visible (ExerciseLibraryViews.swift:256-263), ou par l'étoile de la fiche.
24. **Les quatre filtres ne tiennent pas dans la largeur.** Sur la capture `tests/mini-app-fitness-search.png`, le quatrième (« Niveau ») est coupé (ExerciseLibraryViews.swift:150-181).
25. **« Mes exercices » : un exercice créé ne s'ouvre pas et ne se modifie pas.** La ligne n'est pas touchable. La suppression par glissement n'est pas confirmée (ExerciseLibraryViews.swift:85-93). On ne peut pas le choisir dans l'éditeur de séance, seulement pendant une séance (FitnessSession.swift:545-560).
26. **La page « Activité » devient inaccessible depuis Fitness si l'accès aux pas est refusé.** La carte disparaît (FitnessApp.swift:425-426), alors que la page sait afficher « Accès refusé » et « Ouvrir Réglages » (FitnessPages.swift:467-471).
27. **Le rappel de séance est loin.** Il faut descendre tout en bas, ouvrir « Mes paramètres », puis « Rappel de séance », puis régler dans « Rappels » (FitnessApp.swift:47 ; MiniAppSettings.swift:94).
28. **Des données existent dans les widgets et pas dans la mini-app.** Série de semaines, calendrier du mois, calories du jour, écart avec la semaine d'avant (FitnessTiles.swift:155-244). Le détail d'une séance ne montre ni ses calories ni ses séries passées (FitnessPages.swift:204-211).
29. **Le nom de la séance tient sur une seule ligne en 54 points.** Il est réduit jusqu'à moitié, puis coupé (MiniAppScaffold.swift:139-142). Plusieurs séances le même jour sont mises bout à bout sur cette ligne (FitnessApp.swift:124).
30. **Dans Créer, deux gestes ne sont pas confirmés.** « Terminer la séance » (FitnessSpace.swift:40-42) et la suppression d'une séance du programme (FitnessSpace.swift:70-72) agissent tout de suite. Dans la mini-app, les deux sont confirmés (FitnessSession.swift:290 ; FitnessPages.swift:103).
31. **À vérifier : un texte de Créer ne dit pas la même chose que le code.** « Dès ta première série validée, ta séance s'affiche sur l'écran verrouillé » (LockScreenCreator.swift:130). Le code lance l'activité dès qu'une séance est en cours (WorkoutLiveActivity.swift:54 ; AppModel.swift:156-158).

Ajoutés à la deuxième passe (mêmes règles : un fait, une preuve) :

32. **Après une séance faite aujourd'hui, l'écran principal ne permet plus d'en lancer une autre.** La séance faite passe avant la séance prévue (FitnessApp.swift:72-76). Dans cet état il n'y a aucun bouton flottant (FitnessApp.swift:169-170) et la section du jour n'offre que « Voir le détail » et « Supprimer la séance » (FitnessApp.swift:186-191). La carte de Mon quotidien n'a pas de bouton non plus (DailySection.swift:869-880). Il reste : rattraper un jour passé (FitnessApp.swift:161-168), le widget « Prochaine série » (FitnessTiles.swift:117) ou la page de Créer (FitnessSpace.swift:43-49). Un jour de repos, au contraire, offre « Faire une séance quand même ».
33. **Sur la page « Séance », « Série faite » n'est pas fixé à l'écran.** Toute la page défile d'un bloc : en-tête, carte de l'exercice, liste « La séance », ajouts, puis « Terminer la séance » et « Annuler la séance » tout en bas (FitnessSession.swift:134-312). Aucun bouton n'est ancré, alors que la fiche d'exercice ancre le sien en bas (ExerciseLibraryViews.swift:426). Sur la capture `tests/mini-app-fitness-session.png`, « Série faite » est au milieu de l'écran, la barre d'onglets reste visible et recouvre la liste. Dès qu'on descend lire la liste, le bouton principal sort de l'écran.
34. **Les noms des phases et des vues d'une démonstration ne sont pas traduits.** Ils sont lus tels quels dans `ExerciseDemos.json`, en français (« Poussée », « Profil », « 3/4 »), sans passer par `tr()` (ExerciseDemo.swift:64, 68, 116, 144, 272-273). Dans les six autres langues la fiche garde ces mots en français (Pieges-connus.md, 2026-11-10).
35. **Trois cadres d'écran différents dans la même mini-app.** L'écran principal a le voile rouge et des titres de section avec une barre rouge (`MiniAppScaffold`, FitnessApp.swift:34 ; MiniAppScaffold.swift:74). « Séance », « Progression », « Activité » et la fiche sont des pages à cartes sans voile rouge ni barre devant les titres (`MiniAppScroll`, FitnessSession.swift:134 ; FitnessPages.swift:292, 412 ; ExerciseLibraryViews.swift:331 ; MiniApp.swift:257). « Programme », « Historique », le détail d'une séance et « Exercices » sont des listes du système (FitnessPages.swift:20, 141, 202 ; ExerciseLibraryViews.swift:41). Les titres sont grands sur cinq pages et petits sur les autres (FitnessPages.swift:99, 186, 349, 478 ; ExerciseLibraryViews.swift:137). Visible en comparant `tests/mini-app-fitness.png` et `tests/mini-app-fitness-session.png`.

## 9. Ce que la mission du PDG cite et qui n'existe pas

Les dix points de la liste B existent tous : séance du jour (F2, F3), programme (F32 à F38), bibliothèque (F39 à F44), exercices et démonstrations (F45 à F51), séries, répétitions et charges (F18, F19, F25, F26), temps de repos (F20, F21), progression (F54, F55), historique (F52, F53), statistiques (F7, F48, F54, F55), Premium (section 7).

Ce qui n'existe pas, ou pas sous la forme que les mots de la mission laissent attendre :

1. **« Fitness en Medium » dans Mon quotidien** (mission, partie 8). Mon quotidien n'a pas de taille « Medium » distincte : deux largeurs seulement, demi et pleine (DailyDefaults.swift:19-21). La carte Fitness est en pleine largeur, avec deux pages.
2. **« Statistiques de performance »** : pas de page de ce nom. Elles sont à trois endroits (tuiles de la semaine, « Progression », « Mes performances » d'une fiche). N'existent pas : statistiques par muscle, par mois ou par année, courbe de durée ou de calories. La série de semaines et le calendrier du mois existent seulement en widget.
3. **« Séance du jour » avec une heure** : une séance a des jours, pas d'heure (Fitness.swift:80-86). Donc pas de compte à rebours ni de « dans 18 min » (Decisions.md, 2026-10-22).
4. **« Temps de repos »** : pas de réglage général, pas de + 15 s pendant le repos. Le repos se règle par exercice, dans l'éditeur.
5. **« Programme d'entraînement »** : un seul programme, une semaine type. Pas de programmes tout faits, pas de plusieurs programmes, pas de cycles.
6. **« Historique des séances »** : pas de recherche, pas de filtre, pas de vue en calendrier dans la mini-app.
7. **Écran de fin de séance** (récapitulatif) : n'existe pas (problème 6).
8. **Durée ou distance d'un exercice** : un exercice n'a que séries, répétitions, charge et repos (Fitness.swift:3-9). Un exercice de cardio ou d'étirement se note « 1 × 1 » (ExerciseLibraryViews.swift:637-640).
9. **Vidéos ou photos d'exercice** : les démonstrations sont des animations dessinées par l'app (ExerciseDemo.swift:5-8).
10. **Santé, montre, fréquence cardiaque** : rien (CalorieModel.swift:8-11).
11. **Carte « Encore 2 séances » dans la mini-app** : notée « non codée » dans Chantiers.md. Le texte « Encore n séances » existe seulement sur la page « Semaine » de Mon quotidien (DailySection.swift:1761).

Toute planche qui montre un de ces éléments doit le marquer « nouvelle idée ».

## 10. Captures CI disponibles

- **Tête actuelle de `origin/ci-report`** (commit `170618c`, « Build 455 ») : 918 fichiers, tous en `.txt`. **Aucune image.** La branche est refaite à chaque run et ce run n'a pas pris de captures. Revérifié à la deuxième passe avec `git ls-tree -r --name-only origin/ci-report` : même tête, toujours aucune image.
- **Regardées à la deuxième passe** (commit `9261911`) : `tests/mini-app-fitness.png`, `tests/mini-app-fitness-session.png`, `tests/mini-app-fitness-search.png`, `tests/mini-app-fitness-exercise-sheet.png`, `app-fitness-settings-light.jpg`, `home-light.jpg`. Elles montrent bien ce que disent le tableau et les problèmes 1, 8, 18, 20, 21, 24 et 33. Les autres n'ont pas été rouvertes.
- **Dernier rapport avec captures** : « Build 454 », commit `9261911`, encore présent dans le dépôt local (`origin/ci-report@{1}`). 118 images, dont **9 pour Fitness**. Lecture : `git show 9261911:<chemin>`.

| Fichier (commit `9261911`) | Ce qu'on y voit |
|---|---|
| `tests/mini-app-fitness.png` | Écran principal, séance en cours : sélecteur, « Séance en cours », tuiles, début de « Programme », bouton « Reprendre la séance » |
| `tests/mini-app-fitness-session.png` | Page « Séance » : série 3 sur 4, réglettes, repos, « Série faite », liste « La séance » |
| `tests/mini-app-fitness-search.png` | Bibliothèque : recherche « développé », filtres, 12 résultats |
| `tests/mini-app-fitness-exercise-sheet.png` | Fiche en feuille : démonstration, vues, muscles, « Position de départ », « Ajouter à ma séance » |
| `app-fitness-settings-light.jpg` | Bas de l'écran principal, clair : tuiles, « Programme », note, « Mes paramètres » |
| `app-fitness-settings-dark.jpg` | Le même en sombre |
| `creator-fitness-light.jpg` | Créer : widget moyen « Prochaine série » + « Régularité » |
| `onboarding-sport-light.jpg` | Inscription, étape Sport |
| `tests/profile-sport.png` | Inscription, étape Sport : « Ton niveau », « Séances par semaine », « Toi » |

- **Captures liées, même commit** : `home-light.jpg`, `home-dark.jpg`, `home-pages-light.jpg`, `home-pages-dark.jpg`, `tests/profile-home-daily.png` (carte Fitness de Mon quotidien) ; `spaces-lock-light.jpg`, `spaces-lock-dark.jpg`, `tests/mini-app-lock-creator.png` (aperçu de l'activité en direct).
- **Pas de capture CI récente** pour « Programme », « Historique », le détail d'une séance, « Progression », « Activité », l'éditeur de séance, ni l'état sans programme. La CI sait les prendre (`app-fitness-program`, `app-fitness-history`, `app-fitness-progress`, `app-fitness-activity`, `app-fitness-library`, `app-fitness-exercise`, build.yml:436-441), mais pas dans le run 454.
- **Hors CI** : anciens kits de publicité en local, non versionnés (`pub/kit-fr/`, 2026-10-31 ; `pub/kit-en4/`, 2026-11-07), avec `app-fitness-program`, `-history`, `-progress`, `-library` et les images `live-*`. Ils datent d'avant le style Cristal : à ne pas prendre pour l'état actuel.

## 11. Contraintes pour la conception

1. **Garder les 68 fonctions** de la section 4. Une fonction peut changer de place, pas disparaître.
2. **Ne changer aucun calcul ni aucune donnée** (section 5). Les trois comptes de séances (problème 15) et la règle des jours de repos (problème 14) sont des faits du code : une planche peut proposer de les aligner, en le marquant « nouvelle idée ».
3. **Dessiner les neuf états de la séance du jour** et le rattrapage (section 3). Une planche qui ne montre que « séance prévue » est incomplète.
4. **La séance se pilote de cinq endroits** : page « Séance », carte de Mon quotidien, widgets, écran verrouillé, Dynamic Island. Mêmes actions et mêmes mots partout : « Série faite », « Passer », « Annuler la dernière série », « Annuler la séance », pause et reprise du repos.
5. **Écran de séance : une main, peu d'attention.** Le bouton principal doit rester le plus gros et le plus proche du pouce. Garder les gardes contre le double appui. Aujourd'hui il défile avec la page (problème 33) : le fixer serait un changement, à marquer comme tel. Garder aussi les deux confirmations (« Terminer la séance ? », « Annuler la séance ? ») et la différence entre les deux : terminer enregistre, annuler ne compte rien.
6. **Règle Premium inchangée** : gratuit et Premium comme en section 7. Le badge Premium reste visible là où une fonction est verrouillée. Rien n'est effacé.
7. **Cadre commun des mini-apps** (`MiniAppScaffold`, demande du 2026-10-22) : un seul sélecteur de dates par écran, l'essentiel d'abord, le complémentaire ensuite, « Mes paramètres » en dernier, une action principale flottante. Une organisation différente doit rester cohérente avec les autres mini-apps.
8. **Couleur de Fitness** : rouge `E5484D`, passé par la palette Cristal (FitnessApp.swift:512-517). Les pas gardent leur turquoise `12A4B5` (MiniApp.swift:347). Composants existants : `MiniHero`, `MiniStat`, `MiniRow`, `MiniRowsCard`, `MiniSectionTitle`, `MiniActionButton`.
9. **Mon quotidien** : carte Fitness en pleine largeur, deuxième, deux pages (« Séance », « Semaine »), quatre états plus la carte vide. Pas d'ombre ni de halo sur une carte à pages (Pieges-connus.md). Les mêmes chiffres doivent se lire dans la carte et dans la mini-app.
10. **Ne pas dessiner comme existant** ce que liste la section 9 : heure de séance, durée ou distance d'un exercice, vidéos, Santé, récapitulatif de fin, programmes tout faits.
11. **Sept langues** (français, anglais, espagnol, allemand, italien, portugais du Brésil, japonais) et deux unités (kg, lb). Prévoir la place des libellés longs, par exemple « Rattraper « Haut du corps » d'hier » dans le bouton flottant.
12. **Petits écrans et iPhone sans Dynamic Island** : l'écran de séance doit tenir sur 5,8 pouces. Texte agrandi : le sélecteur s'adapte déjà (WeekSelector.swift:127-128) et les tuiles réduisent leur chiffre (MiniApp.swift:437-438). L'iPhone de test du PDG est un 11 Pro : 5,8 pouces, sans Dynamic Island.
13. **Démonstrations** : 163 animations fournies par `ExerciseDemos.json`, 2 ou 3 vues chacune, fond gris clair ou sombre, hauteur 236 points aujourd'hui (ExerciseDemo.swift:12). Les noms de phases et de vues sont en français seulement (problème 34) : une planche ne peut pas supposer qu'ils sont traduits. Ne pas régénérer ce fichier sous Windows (Pieges-connus.md).
14. **Références de style** : planche Cristal actuelle `docs/design/2026-11-15-cristal/04-fitness.html` ; format des cinq directions déjà fait pour Finance dans `docs/design/2026-11-16-finance/`.
15. **Pour l'intégration future** : les tests d'interface s'appuient sur des identifiants (`fitness-today`, `fitness-start`, `fitness-library`, `session-set-done`, `exercise-demo`, `exercise-add`…, MiniAppUITests.swift:163-220). Sans Mac, seule la CI prouve qu'un écran compile et s'affiche.

## Relecture

- Ajouté : surface H6 et fonction F68 (pastille Fitness de la rangée des mini-apps, MiniAppsRow.swift:70-73) ; contexte d'offre `.fitnessProgress` (ouvert par « Meilleur record » dans Créer) ; liste des intents des boutons hors de l'app ; bornes des répétitions (1 à 100 hors éditeur) ; note sur le message verrou mort de « Mes performances ». Totaux : 18 écrans et feuilles propres, 68 fonctions, 12 Premium, 8 mixtes.
- Corrigé : les totaux de fonctions (67 devient 68, gratuites 47 devient 48). Les autres affirmations vérifiées dans le code (163 exercices, 2 000 séances, 3 h, 3 widgets gratuits et 6 Premium, 8 routes, « Récents » en mode choix seulement, Créer sans confirmation, repos 15 à 600 s) sont exactes ; la section 9 est confirmée (aucun élément cité n'existe).
- Incertain après la première relecture : cible exacte du toucher sur la pastille de l'accueil (F68) ; les 23 démonstrations sans phases nommées ; captures CI du run 454 non relues. Ces trois points sont levés ci-dessous.

### Deuxième passe (2026-11-17, après-midi)

- Méthode : les cinq fichiers de `App/Screens/MiniApps/Fitness/`, `FitnessSpace.swift`, `Fitness.swift`, `WorkoutLiveActivity.swift`, `WorkoutLiveActivityWidget.swift`, `FitnessTiles.swift`, `CalorieModel.swift`, `StepCounter.swift`, `MiniAppScaffold.swift`, `WeekSelector.swift`, `MiniAppToFill.swift` et `MiniAppSettings.swift` relus en entier ; les parties Fitness de `DailySection`, `DailyBrief`, `DailyDefaults`, `SmartReminders`, `NotificationEngine`, `Encouragements`, `SpaceIntents`, `KindCatalog`, `ExerciseLibrary` relues ; `ExerciseDemos.json` recompté par script.
- Confirmé : 10 pages et 8 feuilles propres (18), 68 fonctions (48 gratuites, 8 mixtes, 12 Premium), 9 widgets (3 gratuits, 6 Premium), 163 exercices et 163 démonstrations, 23 démonstrations sans phases nommées, les 31 problèmes de la première passe. Les numéros de ligne cités ont été recontrôlés à la lecture pour les fichiers de Fitness, et par sondage pour les autres fichiers (une quarantaine de renvois) ; deux ont été corrigés (F67 : le libellé est dans ProfileTopics.swift:383 ; contrainte 12 : WeekSelector.swift:127-128).
- Levé : F68 (le toucher ouvre l'écran principal, MiniAppsRow.swift:160) ; le chiffre de 23 ; six captures du run 454 regardées.
- Précisé, sans changer de numéro : F13 et le problème 22 (« Commencer » sur un widget note aussi la première série), F45 (vues, « Réduire les animations »), F47 (note de prudence), F62 (Dynamic Island), le problème 7, le problème 10 (le repos prévu ne s'affiche nulle part avant de démarrer), le tableau des widgets (« Tableau fitness » montre aussi les protéines), les liens (`SkipRestIntent` sans bouton).
- Ajouté : problèmes 32 à 35 ; trois gardes en section 7 ; la contrainte 5 complétée ; la contrainte 13 complétée.
- Total : 35 problèmes d'UX. Rien n'a été retiré du fichier.
- Reste à vérifier sur un iPhone, pas dans le code : l'effet réel du bouton « Commencer » d'un widget (le code note la première série), et le moment exact où l'activité en direct apparaît (problème 31).
