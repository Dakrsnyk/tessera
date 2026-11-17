# Audit : Planning

Relevé du code fait le 2026-11-17 (commit `19f6eb1`), en lecture seule. Le code fait foi. Hors périmètre : Habitudes (audit à part, seul le lien est cité) et Études (audit à part).

Abréviations des chemins : `Planning/` = `App/Screens/MiniApps/Planning/` ; `MiniApps/` = `App/Screens/MiniApps/` ; `Spaces/` = `App/Screens/Spaces/` ; `Home/` = `App/Screens/Home/` ; `Core/` = `App/Core/` ; `Domains/` = `Shared/Domains/`.

## 1. En bref

- Planning sert à voir sa semaine (horaire en tableau) et à gérer ses événements, ses tâches, son Top 3 et ses projets.
- Pour tout le monde : Planning est présent pour tous les comptes, sans question préalable (`docs/memoire/Decisions.md:133`).
- Usage pensé pour chaque jour : sa carte est toujours dans Mon quotidien et ses rappels sont quotidiens. La fréquence réelle n'est pas mesurée dans le dépôt.
- État : complet et testé, mais très long. Dix blocs empilés sur un seul écran, sans chiffre ni phrase d'en-tête.
- Depuis le 2026-11-17, cinq lignes ont été retirées (« Horaire de la semaine », « Études », « Semaine », « Mois », « Concentration »). Une seule fonction est Premium : l'import d'horaire.

## 2. Écrans et navigation

25 écrans et feuilles, numérotés É1 à É25.

### Dans la mini-app Planning

| N° | Écran ou feuille | Vue SwiftUI, fichier:ligne | Comment on y arrive | Ce qu'on y fait |
|---|---|---|---|---|
| É1 | Écran principal « Planning » | `PlanningAppView`, `Planning/PlanningApp.swift:9` | Carte « Planning » de Mon quotidien (`Home/DailySection.swift:974-984`) ; flèche de la carte « Top 3 » (`Home/DailySection.swift:1443`, puis `Home/HomeView.swift:26-29`) ; ligne d'échéance de « À ne pas oublier » (`Core/DailyBrief.swift:575`) ; widgets et rappels (voir § 6) | Voir la semaine, changer de jour et d'échelle, créer et ouvrir des événements, cocher, gérer Top 3 et tâches, ouvrir les pages |
| É2 | Feuille « Nouvelle tâche » ou « Tâche » | `TaskEditor`, `Planning/PlanningApp.swift:359` | Bouton flottant « Nouvelle tâche » (`PlanningApp.swift:36-38`) ; toucher une tâche dans le tableau (`PlanningApp.swift:276-277`) ; toucher une tâche dans la page « Tâches » (`Planning/PlanningPages.swift:97`) | Titre, priorité, échéance, heure, répétition, notes, supprimer. « Répéter » et « À une heure précise » n'apparaissent que si « Échéance » est activée (`PlanningApp.swift:377-387`). Une tâche existante s'ouvre avec une flèche de retour, une nouvelle avec « Annuler » (`:368`) |
| É3 | Feuille « Nouvel événement » ou « Événement » | `SlotEditor`, `Spaces/StudentSpace.swift:223` | Toucher une heure libre du tableau, en « Jour » ou « Semaine » (`PlanningApp.swift:262-266`) ; toucher un bloc de l'horaire (`PlanningApp.swift:274-275`) ; bouton « Ajouter un horaire » de « À remplir » (`App/Screens/Profile/DataItemViews.swift:188-191`) | Type, nom ou cours, répétition, heures, lieu, couleur, annuler un jour, supprimer. Deux dialogues : « Supprimer cet événement ? » (`:338`) et « Modifier la série ? » (`:354`) |
| É4 | Feuille « Examen » | `ExamEditor`, `Spaces/StudentSpace.swift:513` | Toucher un examen dans le tableau (`PlanningApp.swift:278-279`) | Titre, cours, date et heure, salle |
| É5 | Feuille « Devoir » | `AssignmentEditor`, `Spaces/StudentSpace.swift:535` | Toucher un devoir dans le tableau (`PlanningApp.swift:280-281`) | Titre, cours, « À rendre le », « Rendu » |
| É6 | Feuille d'explication « Calendrier » | `permissionSheet(.calendar…)`, `PlanningApp.swift:129` ; textes `App/Components/PermissionExplainer.swift:90,100` | Bouton « Ajouter les événements de mon calendrier » (`PlanningApp.swift:61-71`) | Lire pourquoi, « Continuer » (demande d'iOS) ou « Plus tard » ; après un refus : « Ouvrir Réglages » |
| É7 | Feuille « Importer mon horaire » (6 états : verrou Premium, choix de la source, lecture, échec, vérification, confirmation) | `ScheduleImportView`, `Planning/ScheduleImportView.swift:131` | Ligne « Importer mon horaire » (`PlanningApp.swift:77-84`). La même feuille s'ouvre aussi depuis Études (`MiniApps/Studies/StudiesApp.swift:344-351`) | Choisir caméra, photo ou PDF ; attendre la lecture ; corriger ; ajouter à l'horaire |
| É8 | Caméra de documents, plein écran | `ScheduleCameraSheet`, `Planning/ScheduleCameraSheet.swift:14` | Bouton « Scanner avec la caméra » de É7 (`ScheduleImportView.swift:238-244`) | Explication de la caméra, puis caméra de documents d'iOS (bords, plusieurs pages, flash) |
| É9 | Offre Premium | `PaywallView`, ouverte par `PremiumLockCard`, `App/Premium/PremiumLock.swift:28-42` | Bouton « Découvrir Premium » de la carte verrou de É7 (`ScheduleImportView.swift:213-222`) | Voir l'offre |
| É10 | Page « Tâches » | `PlanningTasksPage`, `Planning/PlanningPages.swift:7` | Les trois tuiles « En retard », « Aujourd'hui », « À faire » (`PlanningApp.swift:92`) ; ligne « N tâches à faire » de « À ne pas oublier » (`Core/DailyBrief.swift:590`) | Filtrer, ajouter vite, cocher, ouvrir, supprimer, effacer les terminées |
| É11 | Feuille « Choisir une date » | `DaySwitcher`, `MiniApps/MiniApp.swift:468` (la feuille est dans le même corps de vue) | Dans É10, filtre « Aujourd'hui », toucher la date (`PlanningPages.swift:61`) | Le sélecteur de jour de la page « Tâches » est une capsule : flèches « Jour précédent » et « Jour suivant », la date au milieu, et une flèche « Revenir à aujourd'hui » si un autre jour est choisi. Toucher la date ouvre la feuille : calendrier graphique, « Aujourd'hui », « OK » |
| É12 | Page « Projets » | `PlanningProjectsPage`, `Planning/PlanningPages.swift:286` | Ligne « Projets » (`PlanningApp.swift:107`) | Cocher les tâches d'un projet, « Modifier le projet », « Nouveau projet » |
| É13 | Feuille projet (« Nouveau projet » ou le nom du projet) | `ProjectEditor`, `Spaces/ProductivitySpace.swift:216` | Depuis É12 (`PlanningPages.swift:314,330,340`) | Nom, couleur, échéance, tâches du projet |
| É14 | Page « Habitudes » | `PlanningHabitsPage`, `Planning/PlanningPages.swift:346` | Ligne « Habitudes » (`PlanningApp.swift:113`) ; carte « Habitudes » de Mon quotidien (`Home/DailySection.swift:1088`) | Lien seulement : voir l'audit Habitudes du même dossier |
| É15 | Feuille « Mes paramètres » | `MiniAppInfoSheet`, `MiniApps/MiniAppSettings.swift:184` | Bouton « Mes paramètres », en bas de É1 (`MiniAppSettings.swift:70-82`) | « Ton objectif du moment », « Ton rythme », « Heure sur 24 h » |
| É16 | Feuille « Cours » | `CourseEditor`, `Spaces/StudentSpace.swift:170` | Bouton « Nouveau cours » de la carte « Cours et horaire » de « À remplir » (`App/Screens/Profile/DataItemViews.swift:186`) | Nom du cours, enseignant, crédits, couleur |

### Pages qui existent encore, sans accès depuis Planning

| N° | Écran | Vue SwiftUI, fichier:ligne | Comment on y arrive | Ce qu'on y fait |
|---|---|---|---|---|
| É17 | Page « Semaine » | `PlanningWeekPage`, `Planning/PlanningPages.swift:171` | Aucun lien dans l'app. Seul le mode capture des versions de test l'ouvre (`Core/ScreenshotMode.swift:4,194`, bloc `#if DEBUG`). Route `planningWeek` gardée (`MiniApps/MiniApp.swift:96,192`) | Tableau de la semaine avec son propre en-tête (mois, flèches, « Aujourd'hui »), puis liste du jour (« Libre » si vide) |
| É18 | Page « Mois » | `PlanningMonthPage`, `Planning/PlanningPages.swift:215` | Aucun lien dans l'app. Mode capture seulement (`Core/ScreenshotMode.swift:195`). Route `planningMonth` gardée (`MiniApps/MiniApp.swift:97,193`) | Grille du mois, flèches, liste du jour touché (« Rien de prévu. » si vide) |
| É19 | Page « Concentration » | `PlanningFocusPage`, `Planning/PlanningPages.swift:436` | Depuis Études seulement : « Concentration » › « Temps de concentration » (`MiniApps/Studies/StudiesApp.swift:316`). Elle appartient à l'audit Études | Minuteur 15, 25, 45, 60, 90 minutes, « Arrêter », barres « Cette semaine » |

### Mêmes données, hors de la mini-app

| N° | Écran ou feuille | Vue SwiftUI, fichier:ligne | Comment on y arrive | Ce qu'on y fait |
|---|---|---|---|---|
| É20 | Espace « Productivité » (données) | `SpaceView` + `ProductivitySpaceSections`, `Spaces/ProductivitySpace.swift:3` | Onglet Créer (`Spaces/CreateView.swift:35`) ; Studio, « Données de l'espace… » (`App/Screens/Editor/SpaceOptionsSection.swift:58`) ; Mes informations, « Voir mon top 3 » et « Tout voir » (`App/Screens/Profile/DataItemViews.swift:162,336`) | Top 3, « Mes tâches réalisées », « Mes tâches », Projets, Échéances, Compteurs, Travail profond |
| É21 | Page « Mes tâches réalisées » | `CompletedPrioritiesView`, `Spaces/ProductivitySpace.swift:168` | Carte « Top 3 » de Mon quotidien (`Home/DailySection.swift:1419-1439`) ; É20 (`ProductivitySpace.swift:29`) | Voir les priorités validées avec leur date ; en toucher une la remet dans le Top 3 |
| É22 | Feuille « Échéance » | `DeadlineEditor`, `Spaces/ProductivitySpace.swift:283` | É20 (`ProductivitySpace.swift:86-104`) ; Mes informations (`DataItemViews.swift:167-170`) | Titre, date et heure |
| É23 | Feuille « Compteur » | `CounterEditor`, `Spaces/ProductivitySpace.swift:307` | É20 (`ProductivitySpace.swift:107-139`) ; Mes informations (`DataItemViews.swift:171-174`) | Nom, icône, couleur, pas, objectif, remise à zéro chaque jour |
| É24 | Liste simple « Tâches » | `TasksView`, `App/Screens/Content/TasksView.swift:3` | Widget « Tâches » et rappel « Tâches importantes » (lien `tessera://tasks` : `Core/Router.swift:160`, `App/ArdaneApp.swift:330`) ; Profil (`App/Screens/Profile/ProfileView.swift:140`) ; É20 ; Studio ; Mes informations | Ajouter, cocher, réordonner, supprimer, « Tout effacer ». Pas de priorité ni de date |
| É25 | Page « Calendrier » (accès) | `CalendarAccessView`, `App/Screens/Content/CalendarAccessView.swift:3` | Widget « À venir » sans accès au calendrier (`Shared/Render/WidgetCanvas.swift:167-168`) ; Profil (`ProfileView.swift:143`) | Lire l'explication du widget « À venir », donner l'accès |

Sorties hors d'Ardane : toucher un événement du calendrier Apple ouvre l'app Calendrier d'iOS (`PlanningApp.swift:282-283`). L'import ouvre le sélecteur de photos et le sélecteur de fichiers d'iOS (`ScheduleImportView.swift:196,247`).

## 3. Écran principal : sections dans l'ordre actuel

Cadre : `MiniAppScaffold` en mode `compact` (`PlanningApp.swift:33-40`). Couleur de Planning : `3366FF` (`MiniApps/MiniApp.swift:41`).

1. **Sélecteur de semaine**, seul dans l'en-tête, sur verre (`WeekSelector`, `PlanningApp.swift:42`, `MiniApps/WeekSelector.swift:23`). Titre « Cette semaine », « Semaine dernière », « Semaine prochaine » ou « Semaine du 28 sept. ». Flèches. Bouton « Aujourd'hui » si un autre jour est choisi. Sept jours : initiale, date, pastille. Pastille pleine : tout ce qui se coche est coché. Pastille creuse : quelque chose est prévu (`PlanningApp.swift:133-139`). Le sélecteur est décalé de 31 points pour que les jours tombent sur les colonnes du tableau (`MiniApps/WeekViews.swift:85`).
2. **« À remplir »**, avec « x / 2 », seulement s'il manque une information (`MiniAppToFillSection`, `PlanningApp.swift:44`). Deux cartes : « Habitudes » et « Cours et horaire » (`MiniApps/MiniAppToFill.swift:12`).
3. **Calendrier** (`PlanningCalendarCard`, `PlanningApp.swift:47`). Par défaut, le tableau de la semaine : sept colonnes, heures 8 à 18 à gauche (plus si un élément déborde), blocs de couleur avec nom, lieu et heure de début si la place le permet, blocs côte à côte s'ils se chevauchent, ligne « maintenant », et un bandeau pour ce qui n'a pas d'heure (3 puces puis « +N »). Sous le tableau : le sélecteur « Jour | Semaine | Mois | Année », puis une note grise (`Planning/PlanningCalendar.swift:80-85`).
4. **Liste du jour choisi** (`dayAgenda`, `PlanningApp.swift:51-55,172-191`). En « Mois » et « Année » : tout le jour. En « Jour » et « Semaine » : seulement ce qui n'a pas d'heure, et seulement s'il y en a. Titre « Aujourd'hui » ou la date, avec « N éléments ». Vide : « Rien de prévu ce jour-là. »
5. **Bouton texte « Ajouter les événements de mon calendrier »**, seulement tant que l'accès au calendrier Apple n'est pas donné (`PlanningApp.swift:60-73`).
6. **Carte d'une ligne « Importer mon horaire »**, détail « À partir d'une photo ou d'un PDF » (`PlanningApp.swift:76-85`).
7. **« Top 3 du jour »**, avec « n/3 » (`PlanningApp.swift:88,193-242`). Une ligne par priorité (rond vide, titre). Champ « Ajouter une priorité » s'il reste de la place.
8. **« Tâches »** : trois tuiles chiffrées, « En retard » (rouge si plus de zéro), « Aujourd'hui », « À faire ». Les trois ouvrent la page « Tâches » (`PlanningApp.swift:90-101`).
9. **Carte de deux lignes** (`PlanningApp.swift:104-119`) : « Projets » (« Tâches regroupées par projet », nombre de projets) et « Habitudes » (« Séries et régularité », « faites/total » du jour, en vert `7FA33A`).
10. **Bouton « Mes paramètres »** (`MiniAppInfoSection`, `PlanningApp.swift:121`).

Toujours visible par-dessus : le bouton flottant « Nouvelle tâche » (`PlanningApp.swift:36-38`).

### Depuis le 2026-11-17 : ce qui est parti, ce qui reste

Le commit `8acb847` a retiré cinq lignes de la carte n° 9. Il ne reste que « Projets » et « Habitudes ». Un test d'interface vérifie cette absence (`UITests/MiniAppUITests.swift:257-268`).

| Ligne retirée | Où elle menait | Ce que c'est devenu |
|---|---|---|
| « Horaire de la semaine » | Page « Horaire » d'Études (`StudiesTimetablePage`) | La page existe. On y va depuis Études › « Organisation étudiante » › « Horaire » (`MiniApps/Studies/StudiesApp.swift:337`). Son bouton « Ajouter un événement » n'est donc plus dans Planning |
| « Études » | Accueil d'Études | Études est une mini-app à part (`MiniApps/MiniApp.swift:6`) |
| « Semaine » | Page É17 | La page existe dans le code. Aucun lien dans l'app. Ouverte seulement par le mode capture des versions de test |
| « Mois » | Page É18 | Même situation que « Semaine » |
| « Concentration » | Page É19 | La page existe. On y va depuis Études seulement |

Attention : les **vues** semaine et mois existent toujours sur l'écran principal. Ce sont deux positions du sélecteur « Jour | Semaine | Mois | Année » du calendrier (n° 3). Seules les lignes et leurs pages séparées ont disparu de la navigation.

## 4. Fonctions existantes

32 fonctions. 3 sont Premium (F14, F15, F16) : ce sont les trois étapes d'une seule fonction, l'import d'horaire. Tout le reste est gratuit, sans limite de nombre (aucun contrôle Premium dans le code des tâches, événements, projets et Top 3 : recherche de `isPremium` et `PaywallContext` faite dans `Planning/`, `StudentSpace.swift` et `ProductivitySpace.swift`). Seule autre trace Premium dans les fichiers de Planning : la page « Habitudes » (limite d'habitudes `PlanningPages.swift:358`, « Régularité » `:407`), comptée dans l'audit Habitudes.

### Dans la mini-app Planning

| N° | Fonction | Où elle est | Gratuit ou Premium | Données affichées | Actions possibles |
|---|---|---|---|---|---|
| F1 | Sélecteur de semaine | En-tête de É1 (`MiniApps/WeekSelector.swift:23`) | Gratuit | Titre de la semaine, 7 jours, pastille pleine ou creuse par jour, aujourd'hui cerclé | Toucher un jour ; flèches ou balayage pour changer de semaine ; « Aujourd'hui » ; le futur est permis |
| F2 | Horaire de la semaine en tableau (échelle « Semaine ») | É1, bloc calendrier (`PlanningCalendar.swift:118-121`, `MiniApps/WeekViews.swift:41`) | Gratuit | 7 colonnes, heures, blocs colorés (nom, lieu, heure de début), chevauchements côte à côte, ligne « maintenant », bandeau sans heure (3 puces, « +N »), éléments faits estompés | Toucher une colonne choisit son jour ; toucher une heure libre crée (F7) ; toucher un bloc ou une puce ouvre (F10) |
| F3 | Vue « Jour » | É1 (`PlanningCalendar.swift:115-117`) | Gratuit | Le jour choisi heure par heure, de 6 h à 22 h | Comme F2, sur un seul jour |
| F4 | Vue « Mois » | É1 (`PlanningCalendar.swift:129-140,276`) | Gratuit | Mois et année en titre ; grille ; aujourd'hui cerclé ; jour choisi plein ; jusqu'à 3 points de couleur par jour ; jours des mois voisins en gris | Toucher un jour l'ouvre en vue « Jour » |
| F5 | Vue « Année » | É1 (`PlanningCalendar.swift:142-165,230`) | Gratuit | Année en titre ; 12 petits mois ; mois en cours teinté ; jours marqués s'il s'y passe une chose ponctuelle | Toucher un mois l'ouvre en vue « Mois » |
| F6 | Changer d'échelle et de période | É1 (`PlanningCalendar.swift:80-84,195-225`) | Gratuit | Sélecteur « Jour | Semaine | Mois | Année » ; note d'aide selon l'échelle | Toucher le sélecteur ; écarter ou pincer deux doigts ; balayer à gauche ou à droite pour la période suivante ou précédente |
| F7 | Créer un événement en touchant une heure libre | É1, vues « Jour » et « Semaine » (`WeekViews.swift:263-271`, `PlanningApp.swift:262-266`) | Gratuit | Feuille « Nouvel événement » déjà remplie : ce jour, l'heure touchée (à la demi-heure), une heure de durée, type « Rendez-vous » | Compléter puis « Enregistrer » |
| F8 | Éditeur d'événement | É3 (`Spaces/StudentSpace.swift:271-337`) | Gratuit | Type (« Cours », « Travail », « Rendez-vous », « Autre événement ») ; cours lié ou « Nom de l'événement » ; « Chaque semaine » ou « Une seule fois » ; date, ou « Répéter » avec 7 pastilles L M M J V S D et sa phrase (« Tous les lundis et mercredis ») ; « Début », « Fin » ; durées rapides 30 min, 1 h, 1 h 30, 2 h ; « Salle » ou « Lieu » ; « Couleur » (habituelle, 10 couleurs, autre) ; avertissement « En même temps que … » | Tout modifier ; enregistrer ; supprimer |
| F9 | Série et occurrence | É3 (`StudentSpace.swift:285-288,324-365`) | Gratuit | Pour un événement hebdomadaire ouvert depuis un jour : « Titre de cette occurrence (facultatif) », « Annulé le … » | Annuler ce jour seulement ; à l'enregistrement, « Cette occurrence seulement » ou « Toute la série » ; à la suppression, « Supprimer uniquement cette occurrence » ou « Supprimer toute la série » |
| F10 | Ouvrir un élément du calendrier | É1 (`PlanningApp.swift:271-287`) | Gratuit | Selon l'élément | Événement de l'horaire : É3. Tâche : É2. Examen : É4. Devoir : É5. Événement du calendrier Apple : app Calendrier d'iOS. Échéance ou séance de sport : choisit seulement son jour |
| F11 | Liste du jour choisi | É1, section 4 (`PlanningApp.swift:172-191,300-356`) | Gratuit | Par ligne : heure ou « Journée », barre de couleur, titre (barré si fait), détail, rond à cocher ou symbole ; ligne en cours mise en couleur | Cocher une tâche ou un devoir. Les lignes ne s'ouvrent pas |
| F12 | Agenda qui réunit 7 sources | `Core/Agenda.swift:41-100` | Gratuit | Calendrier Apple, horaire (cours, travail, rendez-vous, autre), examens, devoirs, tâches datées, échéances, séances de sport prévues | Aucune action propre : alimente F2 à F5, F11 et les pastilles de F1 |
| F13 | Calendrier Apple, en lecture | É1, section 5, et É6 (`PlanningApp.swift:60-73`, `Shared/Data/CalendarService.swift:43`) | Gratuit | Événements du calendrier de l'iPhone : titre, heures, journée entière, couleur du calendrier, lieu | Donner l'accès. Rien n'est écrit dans le calendrier Apple |
| F14 | Import d'horaire : choisir la source | É7, É8 (`ScheduleImportView.swift:225-262`) | Premium | « Ton horaire », texte d'explication, 3 boutons | « Scanner avec la caméra » (flash automatique, activé ou désactivé), « Choisir une photo », « Choisir un PDF » (PDF ou image de Fichiers) |
| F15 | Import d'horaire : vérifier et corriger | É7 (`ScheduleImportView.swift:315-582`) | Premium | Ce qui a été lu, rangé par jour ; étiquette « À vérifier » et champs douteux surlignés ; pour un horaire d'équipe, la liste des personnes | Cocher ou décocher ; corriger titre, type, « Chaque semaine » ou « Une seule fois », date ou jour, début, fin, lieu, personne ou note ; supprimer ; « Ajouter un cours » ; « Décocher les cours incertains » ; « Tout cocher » ; « Garder les quarts de… » |
| F16 | Import d'horaire : ajouter | É7 (`ScheduleImportView.swift:378-400,646-666,747-762`) | Premium | Bouton « Ajouter à mon horaire (N) » ; si un horaire de cours existe déjà : « Un horaire est déjà dans ton planning » ; confirmation « N créneaux ajoutés », « N cours étaient déjà dans ton horaire. » | « Ajouter à mon horaire » ou « Remplacer l'ancien » ; « Terminé » (la feuille se ferme seule après 1,6 s) |
| F17 | Nouvelle tâche | Bouton flottant de É1 (`PlanningApp.swift:36-38`) | Gratuit | Feuille « Nouvelle tâche », échéance déjà mise au jour choisi | Créer une tâche |
| F18 | Éditeur de tâche | É2 (`PlanningApp.swift:359-421`) | Gratuit | « Titre » ; « Priorité » (Aucune, Basse, Moyenne, Haute) ; « Échéance » ; « Jour » ; « À une heure précise » ; « Heure » ; « Répéter » (Jamais, Chaque jour, En semaine, Chaque semaine, Chaque mois) ; « Notes » | Enregistrer ; « Supprimer la tâche » |
| F19 | Tâche répétée | `Shared/Model/Content.swift:332-349` | Gratuit | Note de l'éditeur : « Une fois faite, la tâche revient à sa prochaine date. » | Cocher crée la suivante ; décocher par erreur retire la copie créée |
| F20 | Top 3 du jour | É1, section 7 (`PlanningApp.swift:193-249`) | Gratuit | Jusqu'à 3 priorités, « n/3 » | Ajouter par le champ « Ajouter une priorité » ; toucher pour valider (la ligne disparaît) ; appui long, « Retirer » (menu contextuel, `PlanningApp.swift:219-225`, suppression sans confirmation). Le titre d'une priorité ne se modifie pas |
| F21 | Compteurs de tâches | É1, section 8 (`PlanningApp.swift:90-101`) | Gratuit | « En retard », « Aujourd'hui », « À faire » | Toucher ouvre É10 |
| F22 | Page « Tâches » | É10 (`PlanningPages.swift:7-164`) | Gratuit | Filtres « À faire », « Aujourd'hui », « À venir », « Terminées » ; sections « En retard », « Aujourd'hui », « Plus tard », « Sans date », triées par priorité ; par ligne : rond coloré selon la priorité, titre, détail (date, répétition, priorité ; rouge si en retard) | Ajout rapide « Ajouter une tâche » (avec le jour du sélecteur si le filtre « Aujourd'hui » est actif, `PlanningPages.swift:111`) ; cocher ; toucher pour ouvrir É2 ; glisser pour supprimer ; changer de jour dans le filtre « Aujourd'hui » (si c'est aujourd'hui, la liste inclut aussi les tâches en retard, `PlanningPages.swift:66`) ; « Effacer les tâches terminées » (sans confirmation, `:78-80`). « Terminées » est trié par date de fin ; « À venir » par échéance |
| F23 | Page « Projets » | É12 (`PlanningPages.swift:286-342`) | Gratuit | Par projet : pastille de couleur, nom, « faites/total », tâches, « Échéance : … » | Cocher une tâche du projet ; « Modifier le projet » ; « Nouveau projet » |
| F24 | Éditeur de projet | É13 (`Spaces/ProductivitySpace.swift:216-281`) | Gratuit | « Nom du projet », couleur, « Échéance » et « Date », liste « Tâches » | Ajouter, renommer, cocher, supprimer une tâche du projet ; enregistrer |
| F25 | Accès aux habitudes | Ligne « Habitudes » de É1 (`PlanningApp.swift:113-118`) | Gratuit | « faites/total » du jour | Ouvre É14 (audit Habitudes) |
| F26 | « À remplir » | É1, section 2 (`MiniApps/MiniAppToFill.swift:41`) | Gratuit | « x / 2 » ; carte « Habitudes » ; carte « Cours et horaire » ; étiquette « À renseigner » | Ajouter une habitude par un champ ; « Nouveau cours » ; « Ajouter un horaire » ; une carte remplie s'en va seule |
| F27 | « Mes paramètres » | É15 (`MiniApps/MiniAppSettings.swift:17,48,184` ; `App/Screens/Profile/ProfileTopics.swift:562-578`) | Gratuit | « Ton objectif du moment » ; « Ton rythme » (« Travail / étude », heures par jour) ; « Réglages communs » : « Heure sur 24 h » | Modifier ; « OK » |

### Mêmes données, hors de la mini-app

| N° | Fonction | Où elle est | Gratuit ou Premium | Données affichées | Actions possibles |
|---|---|---|---|---|---|
| F28 | « Mes tâches réalisées » (historique du Top 3) | É21 ; lien sur la carte « Top 3 » de Mon quotidien | Gratuit | Priorités validées, la plus récente d'abord, « Terminée le … » | En toucher une la remet dans le Top 3 (s'il reste de la place) |
| F29 | Échéances | É20, É22. Elles s'affichent dans le calendrier de Planning (`Core/Agenda.swift:78-83`) et dans « À ne pas oublier » | Gratuit | Titre, date et heure | Créer, modifier, supprimer : seulement dans l'espace Productivité ou Mes informations |
| F30 | Compteurs | É20, É23 | Gratuit | Nom, valeur du jour, objectif | « + » ajoute ; créer, modifier, supprimer |
| F31 | Liste simple « Tâches » | É24 | Gratuit | « À faire », « Terminées » | Ajouter, cocher, réordonner, supprimer, « Tout effacer » |
| F32 | Rappels de Planning | Notifications (`Shared/Support/NotificationEngine.swift:596-663`) ; réglage dans Profil › Rappels (`App/Screens/Profile/SmartRemindersView.swift:93`) | Gratuit | « Cours dans 30 minutes », « Rendez-vous demain », « Examen demain », « Demain, une journée bien remplie », « Tâches importantes » | Activer ou couper la catégorie « Planning » ; toucher un rappel ouvre l'écran lié (§ 6) |

## 5. Données et calculs

### Ce qui est saisi

- **Tâche** (`TaskItem`, `Shared/Model/Content.swift:58`) : titre, faite ou non, priorité, échéance, heure précise ou non, répétition, notes. Dates de création et de fin tenues par l'app. Rangée dans `content.tasks`.
- **Priorité du Top 3** (`PriorityItem`, `Domains/Productivity.swift:5`) : titre, date de création, date de validation. Rangée dans `productivity.priorities`. Ce n'est pas une `TaskItem`.
- **Projet** (`Project`, `Domains/Productivity.swift:58`) : nom, couleur, échéance, tâches du projet (`ProjectTask`, `:38` : titre, faite, date).
- **Échéance** (`Deadline`, `Domains/Productivity.swift:90`) : titre, date et heure.
- **Compteur** (`CounterItem`, `Domains/Productivity.swift:110`) : nom, icône, couleur, pas, objectif, remise à zéro chaque jour.
- **Événement de l'horaire** (`ClassSlot`, `Domains/Student.swift:99`) : type (`ScheduleKind`, `:65`), cours lié, jour de la semaine, autres jours, début et fin en minutes, lieu, titre, date si une seule fois, jours annulés, couleur choisie, exceptions par jour (`ClassOverride`, `:218` : titre, heures, lieu, couleur). Rangé dans `student.slots`, la même liste que les cours d'Études.
- **Événement lu à l'import** (`ImportedSlot`, `App/Services/ScheduleImport/ScheduleParser.swift:13`) : jour, heures, titre, lieu, coché ou non, doute global, champs douteux, type, date, personne ou note. Il n'est gardé que le temps de la vérification.
- **Réglages** : « Ton objectif du moment » et « Travail / étude » (profil) ; « Heure sur 24 h » (réglage commun).

### Ce qui est lu, sans être saisi dans Ardane

- **Événement du calendrier Apple** (`EventSnapshot`, `Shared/Data/CalendarService.swift:6`) : identifiant, titre, début, fin, journée entière, couleur, lieu. Lecture seule. Plage lue : le mois autour du jour choisi, plus 7 jours de chaque côté ; l'année entière en vue « Année » (`PlanningCalendar.swift:385-392`).
- Examens, devoirs (Études) et séances prévues (Fitness) : lus par l'agenda.

### Calculs existants, à ne pas modifier

- **Agenda du jour** (`Core/Agenda.swift:41-100`) : réunit les 7 sources. Tri : d'abord ce qui n'a pas d'heure, puis par heure. Durée d'une séance de sport estimée : séries × (40 s + repos), 5 min au moins (`:88`).
- **Occurrences de l'horaire** (`StudentMath.occurrences`, `Domains/Student.swift:552`) : tient compte des jours annulés et des exceptions. Heures murales : 9 h reste 9 h au changement d'heure.
- **Un événement tel qu'il est un jour donné** : `ClassSlot.resolved(on:)` et `applyingOverride(on:)` (`Student.swift:179-202`). Titre affiché : `title(of:)` (`:396`). Couleur affichée : couleur choisie, sinon celle du cours, sinon celle du type (`colorHex(of:)`, `:403`).
- **Répétition par jours** (`Domains/WeekdayRepeat.swift`) : jours normalisés, phrase « Tous les … », « Tous les jours », « Une seule fois ».
- **Supprimer une occurrence** : le jour est ajouté aux jours annulés (`deleteOccurrence`, `Student.swift:509`). **Modifier une occurrence** : seule la différence est gardée (`override(making:)`, `Student.swift:205`).
- **Chevauchements** : signalés dans l'éditeur (`PlanningCalendar.conflicts`, `PlanningCalendar.swift:395-403`), jamais bloquants. Dans le tableau, les blocs se partagent la largeur (`WeekTimetable.layout`, `WeekViews.swift:444-478`).
- **Tableau** : heures affichées de 8 à 18 (6 à 22 en « Jour »), étendues si un élément déborde (`WeekViews.swift:99-100`). Élément sans fin : 45 min. Durée minimale dessinée : 20 min (`WeekViews.swift:435-441`). Lieu et heure écrits dans un bloc selon sa hauteur ; l'heure à partir de 50 min (`WeekViews.swift:406-411`).
- **Pastilles du sélecteur** : « fait » si tout ce qui se coche ce jour-là est coché ; « prévu » si le jour contient quelque chose (`PlanningApp.swift:133-139`).
- **Jours marqués de la vue « Année »** : seulement ce qui arrive une fois (événement Apple, événement daté, examen, devoir, tâche datée, échéance). L'horaire hebdomadaire n'y est pas, pour garder l'année lisible (`PlanningCalendar.swift:370-381`).
- **Pincement** : au-delà de 1,3, on zoome d'un cran ; en dessous de 0,77, on dézoome d'un cran (`PlanningCalendar.swift:37-41`). Aucune création pendant un pincement, ni dans les 350 ms qui suivent (`:209-212`).
- **Tâches** : en retard (`isOverdue`, `Content.swift:117`), due un jour (`isDue`, `:122`), prochaine date d'une répétition (`TaskRepeat.next`, `:43` ; « En semaine » saute samedi et dimanche), enregistrement (`normalizedForSave`, `:105`), répétition au cochage (`toggleTask`, `:332`).
- **Compteurs de l'écran** : en retard ; dues aujourd'hui et non faites ; toutes les non faites (`PlanningApp.swift:94-96`).
- **Top 3** : 3 au plus (`Productivity.swift:194`). Ajout rapide : titre coupé à 120 caractères, vide refusé, double appui en moins d'une seconde ignoré (`addQuickTask`, `:199-209`). Valider garde la priorité avec sa date ; la remettre demande une place libre (`togglePriority`, `:231-242`).
- **Projet** : `doneCount`, `progress` (`Productivity.swift:67-69`).
- **Import** (`ScheduleImportMerge`, `ScheduleImportView.swift:7-124`) : un élément est ajoutable s'il est coché, nommé (pour un cours), avec une fin après le début. Un cours rejoint le cours du même nom ou le crée. Un élément déjà présent (même type, nom, jour ou date, heures) n'est pas doublé. « Remplacer » ne retire que les cours hebdomadaires ; les autres entrées restent. La question « ajouter ou remplacer » n'est posée que si l'horaire a déjà des cours hebdomadaires et que l'import en apporte.
- **Lecture de l'import** (`App/Services/ScheduleImport/ScheduleReader.swift:39-48`) : sur l'iPhone seulement ; 10 pages au plus ; 25 secondes de passes supplémentaires au plus ; image de Fichiers refusée au-delà de 30 Mo (`ScheduleImportView.swift:697`).
- **Carte de Mon quotidien** : `DailyBrief.planningTile` (`Core/DailyBrief.swift:513-545`) retient les 5 prochaines entrées sur 7 jours. Elles servent à savoir si la carte a du contenu ; la carte dessine le tableau de la semaine.
- **Rappels** : cours 30 minutes avant, déplacé hors de la plage de silence ; la veille au soir pour les rendez-vous, les examens et une journée de 4 activités ou plus ; tâches de priorité haute dues aujourd'hui (`NotificationEngine.swift:596-663`).

Tests qui protègent ces calculs : `Tests/PlanningLayoutTests.swift`, `PlanningOccurrenceTests.swift`, `PlanningStudiesTests.swift`, `QuickTaskTests.swift`, `WeekSelectorTests.swift`, `WeekdayRepeatTests.swift`, `ScheduleGlanceTests.swift`, et les fichiers `Schedule…Tests.swift` de l'import.

## 6. Liens

### Mon quotidien

- **Carte « Planning »** (`PlanningDayTile`, `Home/DailySection.swift:959-1068`). Présente pour tous, même vide (`Core/DailyCategories.swift:63-72`). Troisième carte par défaut, après Nutrition et Fitness (`Core/DailyDefaults.swift:11-14`). En **pleine largeur** par défaut (`DailyDefaults.swift:21`).
  - Pleine largeur : le tableau de la semaine en cours, avec la bande des jours et le texte des blocs, à 22 points par heure (`DailySection.swift:1017`). Vide : « Rien de prévu cette semaine. » au-dessus du tableau vide. En bas : « Toute la semaine › ».
  - Demi-largeur : le même tableau en petit, blocs sans texte, à 12 points par heure (`DailySection.swift:1012`). Vide : le texte seul.
  - Toucher la carte ouvre Planning. Rien ne se crée depuis la carte.
  - Sans accès au calendrier : bouton « Relier le calendrier Apple » sous le tableau (`DailySection.swift:1028-1046`).
  - Une seule vue : pas de pages à faire glisser, contrairement à Nutrition et Fitness (`DailySection.swift:424-435`).
- **Carte « Top 3 »** (`PrioritiesDayTile`, `DailySection.swift:1360-1465`). Pleine largeur par défaut, cinquième carte. Priorités à cocher ; champ « Ajouter une tâche » (si la carte a été ajoutée comme Productivité) ; lien « Mes tâches réalisées » ; flèche qui ouvre Planning.
- **Carte « À ne pas oublier »** (`DailySection.swift:1292`, `Core/DailyBrief.swift:550-593`). Demi-largeur. Échéances des 2 prochains jours (ouvrent Planning) ; « N tâches à faire » (ouvre la page « Tâches »).
- **Carte « Habitudes »** : ouvre la page « Habitudes » de Planning (`DailySection.swift:1088`). Voir l'audit Habitudes.

### Widgets

| Widget | Gratuit ou Premium | Tailles | Un toucher ouvre | Preuve |
|---|---|---|---|---|
| « Horaire » | Gratuit | Petit, moyen, grand, écran verrouillé | Planning | `Shared/Model/KindCatalog.swift:233`, `Shared/Render/WidgetCanvas.swift:174-176` |
| « Prochain cours » | Gratuit | Petit, moyen, écran verrouillé | Planning | `KindCatalog.swift:226`, `WidgetCanvas.swift:174-176` |
| « Tâches » (à cocher) | Gratuit | Petit, moyen, grand, écran verrouillé | La liste simple É24 | `KindCatalog.swift:131`, `WidgetCanvas.swift:164` |
| « Top 3 du jour » (à cocher) | Gratuit | Petit, moyen, écran verrouillé | Planning | `KindCatalog.swift:136`, `WidgetCanvas.swift:182-184` |
| « Projet » (à cocher) | Premium | Petit, moyen, grand | Planning | `KindCatalog.swift:137` |
| « Échéance » | Premium | Petit, moyen, écran verrouillé | Planning | `KindCatalog.swift:138` |
| « Compteur » (un toucher ajoute) | Gratuit | Petit, moyen, écran verrouillé | Planning | `KindCatalog.swift:140` |
| « Analyse productivité » | Premium | Petit, moyen | Planning | `KindCatalog.swift:270` |
| « À venir » (calendrier Apple) | Gratuit | Petit, moyen, grand, écran verrouillé | L'éditeur du widget ; É25 sans accès | `KindCatalog.swift:134`, `WidgetCanvas.swift:167-168,185` |

Pour un widget Premium (« Projet », « Échéance », « Analyse productivité »), la personne non Premium qui le touche arrive sur l'offre Premium, pas sur Planning (`Shared/Render/WidgetCanvas.swift:161-162`).

Les widgets « Focus » et « Travail profond » (Premium) ouvrent Études, plus Planning (`WidgetCanvas.swift:177-180`). Les widgets « Calendrier » et « Ma semaine » (`KindCatalog.swift:116,123`) sont dans la catégorie Temps, sans espace lié dans le catalogue. Leur lien avec les données de Planning est à vérifier avant de les rattacher à une planche.

### Autres mini-apps

- **Études** : même liste d'événements (`student.slots`). Un cours importé va dans les cours d'Études ; un quart de travail ou un rendez-vous reste dans le planning. Les examens et les devoirs d'Études s'affichent dans le calendrier de Planning et s'y ouvrent (É4, É5). L'import (É7) est proposé dans les deux mini-apps. La page « Horaire » et « Concentration » sont dans Études.
- **Fitness** : les séances prévues un jour de la semaine s'affichent dans l'agenda, sans heure (`Core/Agenda.swift:84-91`).
- **Habitudes** : ligne « Habitudes » (F25) et carte « Habitudes » de « À remplir ». Voir l'audit Habitudes.

### Notifications et rappels

Cinq rappels (F32). Réglage : Profil › Rappels, catégorie « Planning » (`remindsPlanning`, `Shared/Model/Settings.swift:135`). Heure du soir : `summaryReminderHour`, 19 h par défaut (`Settings.swift:146`). Toucher un rappel (`Shared/Support/SmartReminders.swift:172-180`) : « Cours dans 30 minutes », « Rendez-vous demain » et « Demain, une journée bien remplie » ouvrent Planning ; « Examen demain » ouvre Études ; « Tâches importantes » ouvre la liste simple É24.

### Liens profonds

Définis dans `Shared/Support/DeepLink.swift:4-41`, traités dans `Core/Router.swift:145-178`.

- `tessera://space/productivity` : ouvre Planning.
- `tessera://space/student` : ouvre Études.
- `tessera://tasks` : ouvre la liste simple « Tâches » (É24), en feuille.
- `tessera://calendar` : ouvre la page « Calendrier » (É25), en feuille.
- Sortant : `calshow:` ouvre l'app Calendrier d'iOS à la date de l'événement (`PlanningApp.swift:283`).

Il n'y a pas de lien profond vers une page précise de Planning (Tâches, Projets) ni vers un jour précis.

## 7. États vides, première utilisation, erreurs, permissions, limites du mode gratuit

### Première utilisation (aucune donnée)

- « À remplir » « 0 / 2 » : cartes « Habitudes » (champ « Ex. : méditer, lire, marcher ») et « Cours et horaire » (bouton « Nouveau cours » ; « Ajouter un horaire » apparaît dès qu'un cours existe) (`App/Screens/Profile/DataItemViews.swift:143-152,184-193`).
- Tableau de la semaine vide, heures 8 à 18, avec la note « Touche une heure libre pour créer un événement. Pince avec deux doigts pour voir plus ou moins de temps. » (`PlanningCalendar.swift:105`).
- Bouton « Ajouter les événements de mon calendrier ».
- Top 3 : seulement le champ « Ajouter une priorité ».
- Tuiles de tâches à 0. Lignes « Projets » et « Habitudes » sans chiffre.
- Aucun écran d'accueil ni tutoriel propre à Planning : l'étape « Ton planning » du tutoriel a été retirée le 2026-11-17 (`docs/memoire/Decisions.md:139`).

### États vides

- Liste du jour, en « Mois » et « Année » : « Rien de prévu ce jour-là. » (`PlanningApp.swift:178`).
- Page « Projets » : « Regroupe les tâches d'un même projet (un déménagement, un rapport, un voyage) et suis leur avancement. » (`PlanningPages.swift:295`).
- Page « Tâches » : aucun texte. Seuls le filtre et le champ d'ajout restent (`PlanningPages.swift:94`).
- Liste simple « Tâches » : « Tes tâches apparaîtront dans le widget, et tu pourras les cocher directement depuis l'écran d'accueil. » ; tout fait : « Tout est fait. » (`App/Screens/Content/TasksView.swift:26,34`).
- « Mes tâches réalisées » : « Les tâches que tu valides dans ton Top 3 apparaîtront ici. » (`Spaces/ProductivitySpace.swift:176`).
- Carte de Mon quotidien : « Rien de prévu cette semaine. » (`Home/DailySection.swift:1049`).
- Pages sans accès : « Libre » (Semaine, `PlanningPages.swift:192`), « Rien de prévu. » (Mois, `:252`).

### Erreurs et garde-fous

- Tâche : « Enregistrer » grisé sans titre (`PlanningApp.swift:368`).
- Événement : « Enregistrer » grisé si la fin n'est pas après le début (`Spaces/StudentSpace.swift:272`). Un événement sans nom est accepté ; il s'affiche avec le nom de son type (`Domains/Student.swift:399`).
- Chevauchement : « En même temps que … », simple avertissement (`StudentSpace.swift:314-323`).
- Import, échec : « Impossible de lire ce fichier » ou « Aucun cours trouvé », avec « Essayer avec une autre photo » (`ScheduleImportView.swift:289-311`).
- Import, vérification : « Donne un nom à ce cours pour pouvoir l'ajouter. » (`:511`) ; « La fin doit venir après le début. » (`:569`) ; bouton d'ajout grisé si rien n'est ajoutable (`:386`).
- Import, lecture : la feuille ne peut pas être fermée par glissement pendant la lecture (`:207`) ; « Annuler » reste possible.
- Import, résultat sans nouveauté : « Rien de nouveau à ajouter » (`:651`).

### Permissions

- **Calendrier** : explication d'abord (« Pour afficher tes prochains rendez-vous dans Ardane et ses widgets. », « Tes événements restent sur ton iPhone. »), puis la demande d'iOS. Après un refus : la feuille propose les réglages. Planning marche sans (`PlanningApp.swift:60-73`, `App/Components/PermissionExplainer.swift:90,100,159-160`).
- **Caméra** (import) : explication propre à l'horaire (« Elle photographie ton horaire, sur papier ou sur un écran, pour en lire les cours et les heures. »), autre voie « Choisir une photo ou un PDF » (`ScheduleCameraSheet.swift:18-23`). Sans caméra (simulateur), le bouton n'est pas proposé (`ScheduleImportView.swift:237`).
- **Photos** : sélecteur d'iOS, aucun accès à la photothèque demandé (`ScheduleImportView.swift:128-129,247`).
- **Notifications** : pour les rappels (F32). Demandées ailleurs dans l'app : à vérifier.

### Limites du mode gratuit

- Import d'horaire : verrouillé. La feuille s'ouvre sur une carte « Importer mon horaire » : « Premium lit ton horaire à partir d'une photo ou d'un PDF, sur ton iPhone. Ajouter tes cours et tes événements à la main reste gratuit. » et « Découvrir Premium » (`App/Premium/PaywallContext.swift:56-62`).
- Widgets Premium : « Projet », « Échéance », « Analyse productivité ».
- Habitudes : limite gratuite et « Régularité » Premium. Voir l'audit Habitudes.
- Tout le reste est gratuit et sans plafond.

## 8. Problèmes d'UX constatés aujourd'hui

1. **Pas d'en-tête qui résume.** L'en-tête ne contient que le sélecteur (`PlanningApp.swift:42`). Le commentaire du fichier annonce pourtant « a line about the chosen day » (`PlanningApp.swift:3-4`). Les planches Cristal le notaient déjà : « Planning n'a pas de chiffre en vedette aujourd'hui » (`docs/design/2026-11-15-cristal/README.md:50`).
2. **Dix blocs dans un seul défilement ; les tâches sont loin.** Le tableau de la semaine fait au moins 380 points de haut (10 heures × 38 points : `WeekViews.swift:62,67`). La vue « Jour » fait au moins 832 points (16 heures × 52 points : `PlanningCalendar.swift:116`). Le Top 3 et les tâches viennent après le calendrier, la liste du jour, le bouton calendrier et l'import (`PlanningApp.swift:47-101`).
3. **Le sélecteur d'échelle est sous le tableau** (`PlanningCalendar.swift:73-84`). En vue « Jour », il faut défiler 832 points pour revenir à « Semaine ». L'autre moyen, le pincement, n'est expliqué que par une note grise placée encore plus bas (`PlanningCalendar.swift:85,103-109`).
4. **Créer un événement n'a pas de bouton.** Il faut toucher une heure libre, en « Jour » ou « Semaine » seulement (`PlanningCalendar.swift:115-121`, `WeekViews.swift:263-271`). En « Mois » et « Année », rien ne permet de créer. Le seul bouton d'action crée une tâche (`PlanningApp.swift:36-38`). Le bouton « Ajouter un événement » existe, mais dans Études › « Horaire » (`MiniApps/Studies/StudiesPages.swift:46`).
5. **Plus aucune liste des événements de l'horaire dans Planning.** La page qui les listait est passée dans Études (§ 3). Dans Planning, un événement ne se trouve qu'en le cherchant dans le tableau.
6. **Les lignes de la liste du jour ne s'ouvrent pas.** `AgendaRow` n'a pas de toucher (`PlanningApp.swift:183-185,300-347`) ; seul le rond se coche. Le commentaire dit « to open and check off » (`PlanningApp.swift:48`). En « Mois » et « Année », pour modifier un événement listé, il faut passer en vue « Jour ».
7. **Répétition.** Ce qui n'a pas d'heure le jour choisi est montré deux fois : en puces dans le bandeau du tableau (`WeekViews.swift:211-244`), puis en liste juste dessous (`PlanningApp.swift:53-55`).
8. **Le jour choisi ne pilote qu'une partie de l'écran.** Le calendrier, la liste et la nouvelle tâche suivent le jour choisi (`PlanningApp.swift:30,37,47`). Les tuiles « En retard », « Aujourd'hui », « À faire » et le Top 3 restent sur aujourd'hui (`PlanningApp.swift:94-96,203`). Rien ne le dit à l'écran.
9. **« Top 3 du jour » ne dépend pas du jour.** Une priorité non validée reste les jours suivants (`Domains/Productivity.swift:212`). Une priorité validée disparaît de Planning sans trace : pas de lien vers « Mes tâches réalisées », alors qu'il existe sur la carte de Mon quotidien (`Home/DailySection.swift:1419-1439`) et dans l'espace Productivité (`Spaces/ProductivitySpace.swift:29-34`).
10. **Trois listes de « tâches » séparées, aux mots proches.** Priorités du Top 3 (`PriorityItem`), tâches (`TaskItem`), tâches de projet (`ProjectTask`). Ajouter une priorité ne crée pas de tâche (`Domains/Productivity.swift:199-209`). La même action s'appelle « Ajouter une priorité » dans Planning (`PlanningApp.swift:234`) et « Ajouter une tâche » sur la carte Top 3 de Mon quotidien (`Home/DailySection.swift:1404`). La ligne « Projets » dit « Tâches regroupées par projet » (`PlanningApp.swift:108`), mais ce ne sont pas les tâches de la page « Tâches ».
11. **Deux écrans « Tâches » différents.** La page de Planning a des filtres, des priorités et des dates (`PlanningPages.swift:7`). La liste simple n'en a pas (`App/Screens/Content/TasksView.swift:3`). Le widget « Tâches » et le rappel « Tâches importantes » ouvrent la liste simple (`Shared/Render/WidgetCanvas.swift:164`, `Shared/Support/SmartReminders.swift:179-180`, `Core/Router.swift:160`), pas la page de Planning.
12. **Un second choix de date dans la page « Tâches ».** Le filtre « Aujourd'hui » a son propre sélecteur de jour (`PlanningPages.swift:61`), sans lien avec celui de l'écran principal. Il garde le nom « Aujourd'hui » même quand il montre un autre jour (`PlanningPages.swift:14,68`).
13. **Les échéances se voient mais ne se gèrent pas dans Planning.** Elles sont dans le calendrier (`Core/Agenda.swift:78-83`). Les toucher ne fait que choisir leur jour (`PlanningApp.swift:284-285`). Leur éditeur est dans l'espace Productivité (`Spaces/ProductivitySpace.swift:86-104`). Les widgets « Échéance » et « Compteur » ouvrent pourtant Planning (`KindCatalog.swift:138,140`, `WidgetCanvas.swift:182-184`), où ni échéance ni compteur ne se créent.
14. **Un projet ne se supprime pas depuis Planning.** Ni la page (`PlanningPages.swift:286-342`) ni l'éditeur (`Spaces/ProductivitySpace.swift:216-281`) n'ont de suppression. Elle n'existe que par glissement dans l'espace Productivité (`ProductivitySpace.swift:76-78`). La page « Projets » n'a pas de barre d'avancement (seulement « 2/5 », `PlanningPages.swift:320`) ; l'espace Productivité en a une (`ProductivitySpace.swift:68-70`).
15. **« À remplir » demande des cours dans Planning.** La carte « Cours et horaire » (`MiniApps/MiniAppToFill.swift:12`) n'est remplie que s'il existe au moins un cours et un créneau (`Core/DataItems.swift:355`). Une personne sans cours, avec seulement du travail et des rendez-vous, la garde « À renseigner ». Les cours sont pourtant passés dans Études.
16. **« Mes paramètres » montre un réglage sans effet ici, et pas les rappels.** « Heure sur 24 h » y figure (`MiniApps/MiniAppSettings.swift:48,173-178`), mais Planning écrit toujours les heures sur 24 h (`Core/Agenda.swift:33`, `WeekViews.swift:391`, `PlanningPages.swift:158`). Aucune ligne de rappel n'y figure (`MiniAppSettings.swift:124-129`), alors que cinq rappels de Planning existent (F32).
17. **L'import est Premium sans le dire.** La ligne « Importer mon horaire » n'a aucun signe Premium (`PlanningApp.swift:80-81`). Le verrou n'apparaît qu'une fois la feuille ouverte (`ScheduleImportView.swift:167-168`).
18. **L'import parle de « cours » même pour du travail ou des rendez-vous.** « Aucun cours trouvé » (`ScheduleImportView.swift:294`), « Décocher les cours incertains » (`:341`), « Ajouter un cours » (`:368`), « Inclure ce cours » (`:490`), « Supprimer ce cours » (`:507`), « 1 cours était déjà dans ton horaire. » (`:655`). La confirmation, elle, dit « créneau ajouté » (`:651`).
19. **Même action, deux libellés.** « Ajouter les événements de mon calendrier » dans Planning (`PlanningApp.swift:69`), « Relier le calendrier Apple » sur la carte de Mon quotidien (`Home/DailySection.swift:1038`). Dans Planning, c'est un simple texte posé entre le calendrier et l'import.
20. **Tableau très dense.** Texte des blocs en 9 et 8 points (`WeekViews.swift:381-392`), heures en 10 points (`:118`), puces en 9 points (`:224`), jours de la vue « Année » en 8 points (`PlanningCalendar.swift:254`). Sur l'iPhone 11 Pro de test (375 points de large), une colonne fait environ 41 points (calcul : 375, moins 40 de marges, 28 pour les heures, 21 d'espaces, divisé par 7 ; `MiniApps/MiniAppScaffold.swift:59`, `WeekViews.swift:81-82`).
21. **Pas d'état vide sur la page « Tâches ».** Sans tâche, les sections sont masquées (`PlanningPages.swift:94`) : il ne reste que le filtre et le champ, sans phrase d'aide.
22. **Deux pages mortes.** « Semaine » et « Mois » n'ont plus de lien (§ 2), mais restent dans le code, dans les routes (`MiniApps/MiniApp.swift:96-97`) et dans la liste des captures de la CI (`.github/workflows/build.yml:442`). Une planche faite d'après ces captures reprendrait des écrans que la personne ne voit plus.
23. **Deux types d'éléments ne mènent nulle part dans Ardane.** Une séance de sport touchée ne fait que choisir son jour, sans lien vers Fitness. Un événement du calendrier Apple fait quitter Ardane pour l'app Calendrier (`PlanningApp.swift:282-285`).

## 9. Ce que la mission du PDG cite et qui n'existe pas

La mission cite pour Planning : horaire hebdomadaire, rendez-vous, événements, tâches, organisation personnelle, gestion des créneaux, importation d'horaires, informations liées aux événements. L'horaire, les événements, les tâches et l'import existent (§ 4). Ce qui manque ou diffère :

1. **« Rendez-vous » comme rubrique à part** : n'existe pas. « Rendez-vous » est un des quatre types d'événement (`Domains/Student.swift:66,73`). Aucune page ne liste les seuls rendez-vous.
2. **« Informations liées aux événements »** : un événement porte seulement son type, son nom ou son cours, ses jours ou sa date, son début, sa fin, son lieu et sa couleur (`Domains/Student.swift:99-122`). N'existent pas : notes, invités, rappel réglable par événement, lien, pièce jointe. La personne lue à l'import est collée au titre (« Dentiste · Dr Roy », `ScheduleImportView.swift:65-70`). Pour un événement du calendrier Apple, seuls le titre, les heures, la couleur et le lieu sont lus (`Shared/Data/CalendarService.swift:6-13`).
3. **« Gestion des créneaux » par le geste** : créer, modifier, répéter, annuler un jour et supprimer existent (F7 à F9). N'existent pas : déplacer ou étirer un bloc au doigt (les blocs sont de simples boutons, `WeekViews.swift:289-304`), chercher un créneau libre, écrire dans le calendrier Apple.
4. **« Organisation personnelle »** : aucun écran ni rubrique de ce nom. Ce qui s'en approche existe : Top 3, tâches, projets, habitudes.
5. **« Planning en Large » dans Mon quotidien** : le code n'a que deux tailles de carte, demi-largeur et pleine largeur (`Home/DailyLayoutRules.swift:8-10`). « Moyen » et « Grand » ont la même largeur (`Core/DailyDefaults.swift:19-21`). La carte Planning est en pleine largeur, et plus haute parce qu'elle dessine le tableau.
6. **« Top 3 en Medium sous les petits blocs »** : dans le code, le Top 3 est placé avant les cartes en demi-largeur, pas après (`Core/DailyDefaults.swift:11-14`).

## 10. Captures CI disponibles

**Aucune image** dans `origin/ci-report` tel qu'il est en local. La branche tient en un seul commit, « Build 455 » (2026-11-17, 16 h 07 UTC) : 918 fichiers, tous en texte. Son rapport indique `screenshots: skipped` (`report.txt`, ligne 8) : c'était une version interne, sans captures.

Fichiers texte liés au sujet, tous sur l'import d'horaire (mesures de lecture, pas des captures) :

- `report.txt`
- `history/2026-11-17-run000456/OCR-SYNTHESE.txt`, `OCR-SYNTHESE-semaine.txt`, `OCR-SYNTHESE-tableau.txt`, `OCR-SYNTHESE-liste.txt`, `OCR-SYNTHESE-encadres.txt`, `OCR-SYNTHESE-omnivox.txt`, `OCR-SYNTHESE-travail.txt`, `OCR-SYNTHESE-employes.txt`, `OCR-SYNTHESE-rendez-vous.txt`
- dans le même dossier, les lectures détaillées `OCR-<document>-<état>.txt` (par exemple `OCR-travail-propre.txt`, `OCR-rendez-vous-flou.txt`, `OCR-semaine-incline.txt`) et `SCORES-documents.txt`
- les mêmes noms dans `history/2026-11-17-run000454/`, `…run000451/`, `…run000449/` et les dossiers plus anciens

Captures que la CI sait produire, absentes aujourd'hui (à redemander avant de dessiner) :

- Étape « Screenshots » (`.github/workflows/build.yml:442-446`) : `app-planning`, `app-planning-tasks`, `app-planning-week`, `app-planning-month`, `app-planning-projects`, `app-planning-habits`, `app-planning-focus`, `app-planning-end`, `app-planning-dark`. Attention : `app-planning-week` et `app-planning-month` montrent les pages sans accès (É17, É18) ; `app-planning-focus` montre une page d'Études (É19).
- Tests d'interface (`UITests/MiniAppUITests.swift:231-263`) : `mini-app-planning`, `mini-app-planning-task-added`, `mini-app-planning-tasks`, `mini-app-planning-habits`, `mini-app-planning-projects-habits` (le préfixe `mini-app-` est ajouté par `MiniAppUITests.swift:24-29`).
- Écrans de l'import en mode capture (`Core/ScreenshotMode.swift:125`) : `app-planning-import-pick`, `app-planning-import-reading`, `app-planning-import-review`.

Aucune capture n'existe pour : les vues « Jour », « Mois » et « Année » de l'écran principal, l'éditeur d'événement, l'éditeur de tâche, l'éditeur de projet, « Mes paramètres », l'import verrouillé, l'échec et la confirmation de l'import. À vérifier dans le workflow avant de les demander.

## 11. Contraintes pour la conception

1. **Ne perdre aucune des 32 fonctions** du § 4. Les fonctions F28 à F32 vivent hors de la mini-app : une planche peut les rapprocher, mais doit le marquer comme une idée nouvelle.
2. **Ne pas réintroduire** les lignes « Horaire de la semaine », « Études », « Semaine », « Mois », « Concentration » (mission, § C ; test `UITests/MiniAppUITests.swift:257-268`). « Importer mon horaire » doit rester dans Planning (même test, `:267`).
3. **Les vues semaine et mois du calendrier ne sont pas ces lignes.** Ce sont des échelles du même calendrier (F2, F4), à garder. Leur forme ne doit pas recréer deux rubriques « Semaine » et « Mois ». Point à faire confirmer par le PDG.
4. **L'horaire hebdomadaire reste central** (mission). Il est déjà le premier bloc sous le sélecteur (`docs/memoire/Decisions.md:70`).
5. **Un seul sélecteur de dates par écran**, en tête, et le jour choisi pilote l'essentiel (règle des mini-apps du 2026-10-22, `docs/memoire/Chantiers.md:116-123`). Cadre commun : sélecteur, essentiel, complémentaire, réglages en dernier, une action flottante (`MiniApps/MiniAppScaffold.swift:25-29`).
6. **Données partagées avec Études.** Les événements et les cours sont dans la même liste. Le type « Cours » d'un événement dépend des cours d'Études. Les examens et les devoirs doivent rester visibles dans le calendrier de Planning. Une planche de Planning ne doit pas redessiner la gestion des cours.
7. **Calendrier Apple : lecture seule.** Jamais d'écriture. L'accès se demande après une explication, et Planning doit marcher sans.
8. **Import : tout sur l'iPhone, rien d'envoyé.** Vérification obligatoire avant tout ajout. Jamais d'effacement sans accord, jamais de doublon. La fonction reste Premium ; l'ajout à la main reste gratuit.
9. **Calculs du § 5 inchangés** : agenda, occurrences et exceptions, répétitions, chevauchements, tâches en retard et répétées, Top 3 limité à 3, règles de l'import.
10. **Couleurs porteuses de sens, à garder lisibles.** Planning `3366FF`. Types : Cours `D6409F`, Travail `3366FF`, Rendez-vous `F2A33A`, Autre événement `7FA33A` (`Domains/Student.swift:87-94`). Priorités : Basse `3A8DDE`, Moyenne `F2A33A`, Haute `E5484D` (`Shared/Model/Content.swift:16-23`). Examen `E5484D`, devoir `D6409F`, échéance `F2A33A`, séance `E5484D` (`Core/Agenda.swift:63-89`). Chaque événement peut aussi avoir une couleur choisie par la personne.
11. **Largeur réelle.** Sept colonnes font environ 41 points chacune sur l'iPhone 11 Pro du PDG. Les noms doivent rester lisibles, y compris en allemand et en japonais (7 langues) et avec un texte agrandi.
12. **Mon quotidien.** La carte Planning en pleine largeur montre le tableau de la semaine ; en demi-largeur, les blocs sans texte. Un toucher ouvre Planning. La carte Top 3 est une carte à part. Les deux doivent utiliser les mêmes codes que la mini-app (couleurs des types, pastilles, ronds à cocher).
13. **Points d'arrivée.** Les widgets « Horaire », « Prochain cours », « Top 3 du jour », « Projet », « Échéance », « Compteur » et trois rappels ouvrent l'écran principal de Planning. Ce qu'ils annoncent doit s'y retrouver vite.
14. **Identifiants des tests à conserver** si la structure change : `planning-today`, `planning-calendar`, `planning-scale`, `planning-new-task`, `planning-tasks`, `planning-habits`, `planning-import-schedule`, `week-card`, `week-day-…`, `week-timetable`, `task-title`, `tasks-quick-add`, et tous les `schedule-import-…` et `slot-…`.
15. **Distinguer l'existant des idées.** Ne sont pas dans le code et doivent être marqués « nouveau » sur une planche : une carte « Prochain événement » en tête (idée des planches Cristal, non codée : `docs/memoire/Chantiers.md:280`), un bouton « Nouvel événement », une liste des rendez-vous, le glisser-déposer des blocs, des notes ou des invités sur un événement, les échéances et les compteurs gérés dans Planning, l'historique du Top 3 dans Planning.

## Relecture

- Ajouté : le détail du sélecteur de jour de la page « Tâches » (flèches, retour à aujourd'hui) ; l'éditeur de tâche (répétition et heure seulement avec une échéance) ; le « Retirer » du Top 3 sans confirmation et sans modification du titre ; le filtre « Aujourd'hui » de la page « Tâches » qui inclut les tâches en retard ; l'effacement des terminées sans confirmation ; un widget Premium touché sans Premium ouvre l'offre ; la preuve de recherche des contrôles Premium.
- Corrigé : la ligne de `DaySwitcher` (`MiniApp.swift:468`, et non 531-555). Les autres affirmations vérifiées dans le code (plus de vingt : lignes de `PlanningApp.swift`, `PlanningPages.swift`, `WeekViews.swift`, `Agenda.swift`, `WidgetCanvas.swift`, `DailySection.swift`, `Router.swift`, test `MiniAppUITests.swift:257-268`, section 9 contre `MISSION.md`) sont exactes.
- Reste incertain : les numéros de ligne hors `Planning/` peuvent bouger de quelques lignes ; les widgets « Calendrier » et « Ma semaine » ; les notifications (demande de permission) ; aucune capture CI n'existe, rien n'a été vu à l'écran.
