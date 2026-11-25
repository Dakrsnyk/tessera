# Audit : Études

Audit fait le 2026-11-17 par lecture complète du code (branche `main`, commit `e09123e` ; le code de l'app est le même depuis `19f6eb1`). Lecture seule : rien n'a été modifié dans l'app. Seconde lecture le même jour : chaque preuve a été revérifiée ligne par ligne ; les corrections et les ajouts sont listés à la fin (« Relecture »). Les chiffres cités entre guillemets viennent des captures de la CI (données de démonstration) ; une lettre (X, Y, N) remplace un nombre qui dépend des données.

Abréviations des fichiers, pour les preuves :

- **SA** = `App/Screens/MiniApps/Studies/StudiesApp.swift`
- **SP** = `App/Screens/MiniApps/Studies/StudiesPages.swift`
- **SS** = `App/Screens/Spaces/StudentSpace.swift` (les formulaires)
- **DS** = `Shared/Domains/Student.swift` (les données et les calculs)
- **IV** = `App/Screens/MiniApps/Planning/ScheduleImportView.swift`
- **CS** = `App/Screens/MiniApps/Planning/ScheduleCameraSheet.swift`
- **PP** = `App/Screens/MiniApps/Planning/PlanningPages.swift`
- **PA** = `App/Screens/MiniApps/Planning/PlanningApp.swift`

## 1. En bref (5 lignes au plus : à quoi sert le sujet, pour qui, à quelle fréquence, son état)

- Études range la vie d'un étudiant : cours, horaire, examens, devoirs, notes et moyenne, temps d'étude, fiches de révision, concentration.
- Pour les élèves et les étudiants (centre d'intérêt « Études », `Shared/Domains/Profile.swift:22`).
- Prévue pour un usage de tous les jours en période de cours : carte « En cours », chrono d'étude, devoirs à cocher.
- C'est une mini-app à part depuis le 2026-11-17 (`MiniApp.studies`, `App/Screens/MiniApps/MiniApp.swift:6`). Avant, elle était dans Planning. Elle partage encore l'horaire et la Concentration avec Planning.
- État : 9 pages, 9 feuilles, 49 fonctions. Tout est gratuit sauf l'import d'horaire. Tests réussis au run 454 (1 637 tests, 0 échec, `docs/memoire/Chantiers.md:362`).

## 2. Écrans et navigation (tableau : écran ou feuille | vue SwiftUI, fichier:ligne | comment on y arrive | ce qu on y fait)

18 écrans et feuilles dans la mini-app : 9 pages (P1 à P9) et 9 feuilles (S1 à S9).

| N° | Écran ou feuille | Vue SwiftUI, fichier:ligne | Comment on y arrive | Ce qu'on y fait |
|---|---|---|---|---|
| P1 | Écran principal « Études » | `StudiesAppView`, SA:83 | Carte « Études » de Mon quotidien (`App/Core/DailyBrief.swift:248`) ; widgets d'Études ; notifications « Examen demain », « Objectif d'étude atteint », « Beau travail » ; lien `tessera://space/student` (`App/Core/Router.swift:168`) | Voir le cours en cours, 3 chiffres, les cours, les examens, les devoirs, lancer le chrono, ouvrir toutes les pages |
| P2 | « Cours » (liste) | `StudiesCoursesPage`, SP:282 | P1 › « Mes cours » › ligne « Cours » (SA:206) | Voir chaque cours avec sa moyenne, ajouter, supprimer en glissant, régler les dates de la session |
| P3 | Détail d'un cours (titre = nom du cours) | `StudiesCoursePage`, SP:364 | P1 › une ligne de « Mes cours » (SA:179) ; carte « En cours » (SA:409) ; P2 › un cours (SP:295) ; P6 › « Par cours » (SP:691) | Voir les chiffres du cours, régler un objectif de note, gérer ses plages, examens, devoirs, notes ; menu « ⋯ » : modifier, supprimer |
| P4 | « Examens » | `StudiesExamsPage`, SP:543 | P1 › « Mes examens » › ligne « Examens » (SA:283) ; Mon quotidien › « À ne pas oublier » (`DailyBrief.swift:569`) | « Nouvel examen », listes « À venir » et « Passés », conseil de révision |
| P5 | « Devoirs » | `StudiesAssignmentsPage`, SP:607 | P1 › « Organisation étudiante » › « Devoirs » (SA:353) ; Mon quotidien › « À ne pas oublier » (`DailyBrief.swift:572`) | « Nouveau devoir », cocher, modifier, supprimer en glissant ; « En retard », « Cette semaine », « Plus tard », « Rendus » |
| P6 | « Notes » | `StudiesGradesPage`, SP:652 | P1 › tuile « Moyenne » (SA:150) ; P1 › « Organisation étudiante » › « Notes » (SA:361) | Voir la « Moyenne générale », la moyenne « Par cours », « Toutes les notes » ; « Nouvelle note » |
| P7 | « Révisions » | `StudiesRevisionPage`, SP:752 | P1 › tuiles « Étude » et « Fiches » (SA:156, SA:162) ; P1 › « Organisation étudiante » › « Révisions » (SA:367) | Chrono, temps de la semaine, ajout rapide, objectif d'heures, 6 dernières semaines, fiches à réviser, paquets |
| P8 | « Horaire » | `StudiesTimetablePage`, SP:8 | P1 › « Organisation étudiante » › « Horaire » (SA:337) ; carte « Prochain cours » si l'entrée n'a pas de cours (SA:409) | Voir la semaine en grille, changer de semaine, voir un jour, ajouter, modifier, annuler une fois, supprimer |
| P9 | « Concentration » | `PlanningFocusPage`, PP:436 | P1 › « Concentration » › « Temps de concentration » (SA:316). Planning n'a plus de ligne vers cette page (PA:105) | Lancer une session de 15, 25, 45, 60 ou 90 minutes, l'arrêter, voir la semaine |
| S1 | Feuille « Cours » | `CourseEditor`, SS:170 | « Ajouter un cours » (SA:199) ; « Nouveau cours » (SP:303) ; menu « ⋯ » › « Modifier le cours » (SA:185, SP:390) | Nom, enseignant, crédits, couleur (10 couleurs, `App/Screens/Spaces/SpaceForms.swift:209`) ; note de doublon |
| S2 | Feuille « Événement » ou « Nouvel événement » | `SlotEditor`, SS:223 | P8 : état vide (SP:39), bloc de la grille (SP:44), ligne du jour (SP:132), « Ajouter un événement » (SP:46) ; P3 › « Horaire » › une plage ou « Ajouter une plage » (SP:468, SP:471) ; aussi depuis le calendrier de Planning (PA:255-287) | Type, cours ou nom, chaque semaine ou une seule fois, jours, heures, durée, salle, couleur, annuler un jour, supprimer |
| S3 | Feuille « Examen » | `ExamEditor`, SS:513 | « Ajouter un examen » (SA:276, SP:483) ; « Nouvel examen » (SP:554) ; toucher un examen (SA:265, SP:486, SP:588) ; carte « À remplir » (`App/Screens/Profile/DataItemViews.swift:195`) ; calendrier de Planning (PA:255-287) | Titre, cours, date et heure, salle |
| S4 | Feuille « Devoir » | `AssignmentEditor`, SS:535 | « Nouveau devoir » (SA:299, SP:619) ; « Ajouter un devoir » (SP:495) ; toucher un devoir (SA:296, SP:498, SP:639) ; calendrier de Planning | Titre, cours, « À rendre le », « Rendu » |
| S5 | Feuille « Note » | `GradeEditor`, SS:557 | « Nouvelle note » (SP:674) ; « Ajouter une note » (SP:505) ; toucher une note (SP:508, SP:707) | Cours, évaluation, note obtenue, sur, poids |
| S6 | Feuille « Fiche » | `CardEditor`, SS:580 | P7 › « Nouvelle fiche » (SP:879) ; toucher une fiche d'un paquet ouvert (SP:864) | Paquet, question ou mot, réponse |
| S7 | Feuille « Importer mon horaire » | `ScheduleImportView`, IV:131 | P1 › « Organisation étudiante » › « Importer mon horaire » (SA:344, SA:114) ; aussi dans Planning (PA:76-85, PA:128) | 6 états : verrou Premium, choix de la source, lecture, échec, vérification, confirmation |
| S8 | Caméra de documents (plein écran) | `ScheduleCameraSheet`, CS:14 ; `ScheduleDocumentCamera`, CS:33 | S7 › « Scanner avec la caméra » (IV:238, IV:200) | Explication de la caméra, puis photo d'une ou plusieurs pages (caméra d'iOS) |
| S9 | Feuille « Mes paramètres » | `MiniAppInfoSheet`, `App/Screens/MiniApps/MiniAppSettings.swift:184` | P1, dernier bouton « Mes paramètres » (`MiniAppSettings.swift:63`) | « Ce que tu étudies », « Ton rythme » : heures d'étude et de concentration par semaine |

Menus et boîtes de dialogue (pas des écrans, mais des fonctions s'y cachent) :

- Menu « ⋯ » d'un cours : « Modifier le cours », « Supprimer le cours » (SA:184, SP:389).
- Menu du bouton « Démarrer » du chrono : « Sans cours précis », puis chaque cours (SA:606).
- Appui long sur un examen : « Supprimer » (SA:267, SP:590).
- Appui long sur une ligne de l'horaire : « Annuler cette fois-ci » ou « Rétablir cette fois-ci », « Supprimer uniquement cette occurrence », « Supprimer toute la série », ou « Supprimer » (SP:141).
- Confirmations de suppression d'un cours : « Supprimer ce cours ? » depuis P1 et P2 (SA:116, SP:326) ; « Supprimer « nom du cours » ? » depuis P3 (SP:398). Même message dans les trois cas.
- Confirmations de l'horaire : « Supprimer toute la série ? », « Supprimer cette occurrence ? », « Supprimer cet événement ? » (SP:55, SP:64, SP:68) ; dans la feuille S2 : « Supprimer cet événement ? » (SS:338) et « Modifier la série ? » (SS:354).
- Dans l'import : « Un horaire est déjà dans ton planning » (IV:393) ; menu « Garder les quarts de… » (IV:410).
- Sélecteurs d'iOS ouverts par l'import : photos (IV:247) et Fichiers (IV:196).
- Feuille Premium : bouton « Découvrir Premium » de la carte verrou de l'import (`App/Premium/PremiumLock.swift:28-32`). C'est l'écran d'offre commun à toute l'app.
- Supprimer un cours depuis sa page (P3) ferme la page et revient en arrière (SP:399-401). Supprimer depuis P1 ou P2 reste sur place.
- Composant partagé par les feuilles S2, S3, S4 et S5 : `CoursePicker`, liste « Cours » avec « Aucun » (SS:211).
- « Toutes les notes » (P6) range la dernière note ajoutée en premier (SP:705). Les notes n'y portent pas de menu de suppression.
- Une route `studiesHome` existe dans le code (`MiniApp.swift:102`, `:197`) mais aucun lien ne l'utilise.

Deux surfaces hors de la mini-app, sur les mêmes données :

| Surface | Vue, fichier:ligne | Comment on y arrive | Ce qu'on y fait |
|---|---|---|---|
| Liste de l'espace « Planning · études » (ancienne forme) | `StudentSpaceSections`, SS:3, dans `SpaceView` (`App/Screens/Spaces/SpaceView.swift:84`) | « Tout voir » d'une carte de données déjà remplie (`DataItemViews.swift:336`) ; « Données de l'espace… » dans l'éditeur de widget (`App/Screens/Editor/SpaceOptionsSection.swift:58`) ; « Mes données » dans le créateur d'espace (`App/Screens/Spaces/SpaceBuilderView.swift:127`) | Tout modifier dans une seule liste : cours, horaire, examens, devoirs, notes, fiches, temps d'étude, session. **Seul endroit où l'on supprime une note ou une fiche**, en glissant (SS:116, SS:133). On y supprime aussi en glissant les cours (sans confirmation, SS:28-32), les plages, les examens et les devoirs (SS:54, SS:74, SS:98). Boutons grisés sans cours : « Ajouter un cours à l'horaire », « Nouvelle note » (SS:64, SS:118). Montre aussi « À réviser maintenant », « Cette semaine », « +25/45/60 min », l'objectif et les dates de « Session » (SS:126-162) |
| Activité en direct du chrono (écran verrouillé, Dynamic Island) | `StudyActivityView`, `Shared/Live/StudyLiveActivity.swift:90` ; `Widgets/StudyLiveActivityWidget.swift:7` | Elle apparaît quand le chrono démarre (SA:641) | Voir le temps qui défile et la semaine ; « Annuler », « Terminer » |

## 3. Écran principal : sections dans l ordre actuel (liste numérotée, avec ce que chaque section montre)

L'écran utilise le cadre commun `MiniAppScaffold` (`App/Screens/MiniApps/MiniAppScaffold.swift:30`) : un en-tête sur un lavis rose, puis les sections. Pas de bouton flottant (SA:97). Ordre du code : SA:97-111.

1. **Carte « En cours » ou « Prochain cours »** (`NextClassCard`, SA:399). Le nom du cours en grand. Dessous : « jusqu'à 14:50 » pendant le cours, sinon ses heures de début et de fin, ou « Demain à » et l'heure ; puis la salle et l'enseignant. Une barre d'avancement pendant le cours. Un toucher ouvre le cours. La carte est absente s'il n'y a aucun cours dans les 7 jours (DS:569). Si la personne n'a ni cours, ni examen, ni devoir, elle est remplacée, avec les trois chiffres de la section 2, par la carte d'accueil « Ton année en un coup d'œil » (SA:98-105, SA:129). Les deux blocs d'en-tête disparaissent ensemble.
2. **Trois chiffres** (SA:146) : « Moyenne » (moyenne générale, nombre de notes), « Étude » (temps de la semaine, « sur 12 h », en vert quand l'objectif est atteint), « Fiches » (nombre à réviser ; seulement s'il existe des fiches). Chaque tuile ouvre sa page.
3. **« À remplir »** (`MiniAppToFillSection`, `App/Screens/MiniApps/MiniAppToFill.swift:41`). Une seule carte possible : « Examens », tant qu'aucun examen n'existe (`MiniAppToFill.swift:13`). Le bloc disparaît ensuite.
4. **« Mes cours »** (SA:173). Le nombre de cours à droite du titre. Une ligne par cours : barre de couleur, nom, enseignant, prochain cours (« Demain · 08:30 »), chevron, menu « ⋯ ». Puis « Ajouter un cours ». Puis la ligne « Cours » (« Moyennes, horaire et devoirs par cours », avec le nombre de cours) s'il y a au moins un cours (SA:204-208).
5. **« Mes examens »** (SA:258). Le nombre d'examens à venir. Les 3 prochains : pastille « J-6 », titre, date et heure, cours, salle, temps révisé. Puis « Ajouter un examen ». Puis la ligne « Examens » (« Compte à rebours et préparation ») s'il existe un examen. Dessous, **« À rendre »** (SA:291), seulement s'il reste un devoir : les 3 prochains devoirs à cocher, puis « Nouveau devoir ».
6. **« Concentration »** (SA:312). Une ligne : « Temps de concentration », « X h sur Y h cette semaine ».
7. **« Organisation étudiante »** (SA:329). Dans l'ordre : la carte « Chrono d'étude » avec « Démarrer » ; la carte « Session » (pourcentage, date de fin, barre) si les deux dates sont réglées ; puis 5 lignes : « Horaire », « Importer mon horaire », « Devoirs », « Notes », « Révisions ».
8. **« Mes paramètres »** (`MiniAppInfoSection`, `MiniAppSettings.swift:63`). Un bouton en bas de page.

## 4. Fonctions existantes (tableau numéroté F1, F2… : fonction | où elle est | gratuit ou Premium | données affichées | actions possibles). C est la liste de référence : aucune planche ne devra en perdre une.

49 fonctions. 46 gratuites, 3 Premium (F42 à F44 : l'import d'horaire). Les numéros F1 à F48 sont ceux de la première lecture ; F49 a été ajoutée à la seconde.

| N° | Fonction | Où elle est | Gratuit ou Premium | Données affichées | Actions possibles |
|---|---|---|---|---|---|
| F1 | Carte du cours en cours ou du prochain cours | P1, en-tête (SA:399) | Gratuit | « En cours » ou « Prochain cours », nom, heures, salle, enseignant, barre d'avancement | Toucher : ouvre le cours (P3), ou l'horaire (P8) si l'entrée n'a pas de cours |
| F2 | Trois chiffres : « Moyenne », « Étude », « Fiches » | P1, en-tête (SA:146) | Gratuit | Moyenne générale et nombre de notes ; temps d'étude de la semaine et objectif ; fiches à réviser | Toucher : P6, P7, P7 |
| F3 | Bloc « À remplir » | P1 (`MiniAppToFill.swift:13`, `:41`) | Gratuit | Carte « Examens », « Tes prochains examens. », « À renseigner », compteur « 0 / 1 » | « Nouvel examen » (`DataItemViews.swift:195`) |
| F4 | Liste « Mes cours », les uns sous les autres | P1 (SA:173-253) | Gratuit | Nombre de cours ; par cours : couleur, nom, enseignant, prochain cours | Toucher : P3 |
| F5 | Ajouter un cours à la main | P1 « Ajouter un cours » (SA:199) ; P2 « Nouveau cours » (SP:303) ; S1 (SS:170) | Gratuit | Champs « Nom du cours », « Enseignant (facultatif) », « Crédits », couleur | « Enregistrer » (le nom est obligatoire), « Annuler » |
| F6 | Modifier un cours | Menu « ⋯ » de P1 (SA:185) et de P3 (SP:390) | Gratuit | Les mêmes champs | « Modifier le cours » |
| F7 | Supprimer un cours, avec confirmation | Menu « ⋯ » de P1 (SA:186, SA:116) ; glisser dans P2 (SP:300, SP:326) ; menu de P3 (SP:391, SP:398) | Gratuit | « Ses plages quittent l'horaire. Ses notes, examens et devoirs restent, sans cours. » | « Supprimer le cours » |
| F8 | Pas de doublon de cours | S1 (SS:180-207) ; règle `CourseMatch`, DS:29 ; `ensureCourse`, DS:48 | Gratuit | « « Zoologie » existe déjà : le cours est complété, pas ajouté une seconde fois. » | Enregistrer complète le cours existant (l'enseignant, s'il était vide) |
| F9 | Page « Cours » : la liste avec les moyennes | P2 (SP:282-361) | Gratuit | Par cours : couleur, nom, enseignant, heures de cours par semaine, moyenne | Toucher : P3 ; glisser : supprimer ; « Nouveau cours » |
| F10 | Dates de la session et carte « Session » | Dates : P2, section « Session » (SP:310) ; carte : P1 (SA:377) | Gratuit | « Début », « Fin » ; carte : « N % · fin » et la date, barre | Choisir les deux dates |
| F11 | En-tête du détail d'un cours | P3 (SP:414-438) | Gratuit | Enseignant, crédits, heures de cours par semaine ; « Moyenne » ; « Évalué » (part de la note finale) ; « Étude » de la semaine | Aucune (lecture) |
| F12 | Objectif de note d'un cours | P3 (SP:440-464) | Gratuit | « Objectif : 80 % » ; « Il te faut en moyenne 79 % sur les 75 % qui restent. », ou « C'est acquis… », ou « Hors d'atteinte… » | « − » et « + », de 50 à 100 %, par pas de 5. Visible seulement s'il y a une note et qu'il reste des évaluations |
| F13 | Plages horaires d'un cours | P3, « Horaire » (SP:466) | Gratuit | Jour ou jours, salle, heures (les plages de chaque semaine seulement) | Toucher une plage : S2 ; « Ajouter une plage » |
| F14 | Examens d'un cours | P3, « Examens » (SP:481) | Gratuit | Tous les examens du cours (les passés en plus pâle) | Toucher : S3 ; « Ajouter un examen », déjà relié à ce cours |
| F15 | Devoirs à rendre d'un cours | P3, « Devoirs à rendre » (SP:493) | Gratuit | Les devoirs non rendus du cours | Cocher, toucher : S4 ; « Ajouter un devoir » |
| F16 | Notes d'un cours | P3, « Notes » (SP:503) | Gratuit | Titre, « 17,0/20 · compte pour 10 % », pourcentage | Toucher : S5 ; « Ajouter une note » |
| F17 | « Mes examens » sur l'écran principal | P1 (SA:258-290) | Gratuit | Nombre à venir ; les 3 prochains | Toucher : S3 ; « Ajouter un examen » ; ligne « Examens » : P4 |
| F18 | Ajouter ou modifier un examen, relié à un cours | S3 (SS:513) ; donnée `Exam.courseID`, DS:243 | Gratuit | « Titre (intra, final…) », « Cours » (un cours ou « Aucun »), « Date et heure », « Salle (facultatif) » | « Enregistrer » (titre obligatoire). Un nouvel examen est prérempli avec le premier cours, dans 7 jours à 9 h (SA:59) |
| F19 | Supprimer un examen | Appui long, P1 (SA:267) et P4 (SP:590) | Gratuit | « Supprimer » | Suppression immédiate, sans confirmation |
| F20 | Page « Examens » | P4 (SP:543-603) | Gratuit | « À venir », « Passés » ; conseil si le prochain examen est dans 7 jours ou moins | « Nouvel examen » ; toucher : S3 |
| F21 | Compte à rebours et temps révisé d'un examen | `ExamRow`, SA:505 | Gratuit | « J-6 » (rouge à 3 jours ou moins), date, heure, cours, salle, « X révisé » (étude de ce cours sur 14 jours) | Aucune (lecture) |
| F22 | « À rendre » sur l'écran principal | P1 (SA:291-305) | Gratuit | Nombre de devoirs ; les 3 prochains : titre, cours, échéance (rouge si en retard) | Cocher, toucher : S4 ; « Nouveau devoir » |
| F23 | Ajouter ou modifier un devoir | S4 (SS:535) | Gratuit | « Titre », « Cours », « À rendre le » (date et heure), « Rendu » | « Enregistrer » (titre obligatoire). Prérempli : premier cours, dans 3 jours à 23 h 59 (SA:63) |
| F24 | Cocher un devoir comme rendu | `AssignmentRow`, SA:454 ; aussi dans l'agenda de Planning (PA:349) et le widget « Devoirs » | Gratuit | Cercle vide ou coché, titre barré | Cocher, décocher |
| F25 | Page « Devoirs » | P5 (SP:607-648) | Gratuit | « En retard », « Cette semaine », « Plus tard », « Rendus » (les 20 derniers) | « Nouveau devoir », cocher, toucher : S4, glisser : supprimer (sans confirmation) |
| F26 | Page « Notes » | P6 (SP:652-747) | Gratuit | « Moyenne générale », « Pondérée par les crédits de chaque cours. » ; « Par cours » : barre, moyenne, « 25 % de la note finale évalué » ; « Toutes les notes » | « Nouvelle note » ; toucher un cours : P3 ; toucher une note : S5 |
| F27 | Ajouter ou modifier une note | S5 (SS:557) | Gratuit | « Cours », « Évaluation (quiz, examen…) », « Note obtenue », « Sur », « Poids dans le cours » (%) | « Enregistrer » (titre obligatoire, « Sur » plus grand que 0) |
| F28 | Chrono d'étude | P1 et P7, `StudyTimerCard` (SA:552) | Gratuit | Arrêté : « Chrono d'étude », « Lance-le quand tu t'y mets, le temps s'ajoute à ta semaine. » En marche : nom du cours ou « Étude », temps qui défile. Après : « X ajoutées à ta semaine » | « Démarrer » (menu : « Sans cours précis » ou un cours), « Annuler », « Terminer et noter ». Moins d'une minute : rien n'est noté. 4 heures au plus (DS:478) |
| F29 | Chrono sur l'écran verrouillé et la Dynamic Island | `Shared/Live/StudyLiveActivity.swift:31` ; `Shared/Intents/StudyIntents.swift:29`, `:45` | Gratuit (aucun verrou dans le code) | « Temps d'étude », cours, temps, « X sur Y cette semaine » | « Annuler », « Terminer », sans déverrouiller |
| F30 | Temps d'étude de la semaine | P7, « Cette semaine » (SP:775) | Gratuit | « 2 h 35 sur 12 h », barre vers l'objectif, graphique par jour | Aucune (lecture) |
| F31 | Ajout rapide de temps | P7 (SP:799) | Gratuit | Boutons « +25 min », « +45 min », « +60 min » | Ajoute ce temps à la semaine, sans cours |
| F32 | Objectif d'heures d'étude par semaine | P7 (SP:810) ; S9 « Étude personnelle » (`App/Screens/Profile/ProfileTopics.swift:609`) ; `setStudyGoal`, `App/Core/AppModel.swift:1304` | Gratuit | « Objectif : 12 h par semaine » | « − » et « + », de 1 à 60 heures |
| F33 | « 6 dernières semaines » | P7 (SP:818) | Gratuit | Barres en heures, ligne pointillée de l'objectif. Visible si une semaine passée a du temps | Aucune (lecture) |
| F34 | Réviser une fiche | P7, « Fiches » (SP:896) ; règle DS:454 | Gratuit | Paquet, question ; puis la réponse | « Voir la réponse », « À revoir », « Je savais ». Fiche sue : revient dans 1, 2, 4, 8 puis 16 jours. Ratée : dans 10 minutes |
| F35 | Paquets de fiches | P7 (SP:853) | Gratuit | Par paquet : nom, « 2 à réviser » ou « à jour », total. Paquet ouvert : chaque fiche et sa « boîte » | Toucher un paquet : l'ouvrir ou le fermer ; toucher une fiche : S6 |
| F36 | Ajouter ou modifier une fiche | S6 (SS:580) ; « Nouvelle fiche » (SP:879) | Gratuit | « Paquet (biologie, anglais…) », « Question ou mot », « Réponse » | « Enregistrer » (question et réponse obligatoires) |
| F37 | Horaire de la semaine en grille, et liste du jour | P8 (SP:8, grille SP:174) | Gratuit | Lundi à vendredi (le week-end s'il est occupé), blocs de couleur, heures ; le jour choisi en liste : titre, salle, heures, « Une seule fois », « Annulé cette fois-ci » | Toucher un jour : le choisir ; toucher un bloc ou une ligne : S2 |
| F38 | Changer de semaine | P8 (SP:77) | Gratuit | « Cette semaine » ou « Semaine du » et la date du lundi | Flèches ; toucher le titre : retour à cette semaine |
| F39 | Ajouter ou modifier un événement de l'horaire | S2 (SS:223-463) | Gratuit | « Type » (Cours, Travail, Rendez-vous, Autre événement), cours ou nom, « Chaque semaine » ou « Une seule fois », « Répéter » (jours), « Début », « Fin », durées 30 min, 1 h, 1 h 30, 2 h, salle ou lieu, « Couleur » (habituelle, 10 couleurs, ou une autre), alerte « En même temps que… » | « Enregistrer » (la fin après le début), « Annuler » |
| F40 | Changer un seul jour d'une série | S2 (SS:285, SS:325, SS:354) ; appui long sur P8 (SP:143) | Gratuit | « Titre de cette occurrence (facultatif) », « Annulé le » et le jour, « Modifier la série ? » | « Cette occurrence seulement », « Toute la série » ; « Annuler cette fois-ci », « Rétablir cette fois-ci » |
| F41 | Supprimer un événement de l'horaire | S2 (SS:329-353) ; appui long sur P8 (SP:150-167) | Gratuit | Confirmation | « Supprimer uniquement cette occurrence », « Supprimer toute la série », « Supprimer » |
| F42 | Importer un horaire : choisir la source | S7, étape 1 (IV:225-262) ; S8 (CS:14) | **Premium** (IV:167, carte IV:213) | « Scanner avec la caméra », « Choisir une photo », « Choisir un PDF » ; « La lecture se fait sur ton iPhone : rien n'est envoyé. » | Caméra de documents (plusieurs pages, flash automatique réglable), photo, PDF ou image depuis Fichiers |
| F43 | Importer un horaire : vérifier ce qui a été lu | S7, étapes 2 et 3 (IV:273, IV:315-582) | **Premium** | « Lecture de ton horaire… » ; puis, par jour, chaque entrée : titre, type, chaque semaine ou une seule fois, jour ou date, début, fin, salle, enseignant ; marque « À vérifier » sur les lectures douteuses | Cocher ou décocher, corriger chaque champ, supprimer, « Ajouter un cours », « Décocher les cours incertains », « Tout cocher », « Garder les quarts de… » |
| F44 | Importer un horaire : ajouter, et créer les cours trouvés | S7, étapes 3 et 4 (IV:379-399, IV:646, IV:747) ; règle `ScheduleImportMerge`, IV:7-124 | **Premium** | « Ajouter à mon horaire (N) » ; « Un horaire est déjà dans ton planning » ; « N créneaux ajoutés » ; « N cours étaient déjà dans ton horaire. » | « Ajouter à mon horaire », « Remplacer l'ancien », « Terminé ». Un cours lu rejoint « Mes cours » (IV:50) ; s'il existe déjà sous le même nom, il n'est pas créé deux fois |
| F45 | Ligne « Temps de concentration » | P1 (SA:312-324) | Gratuit | « X h sur Y h cette semaine » | Toucher : P9 |
| F46 | Session de concentration (compte à rebours) | P9 (PP:449-478, PP:497-515) ; alerte de fin `Shared/Intents/InteractiveIntents.swift:101` | Gratuit | « Lance une session de concentration », boutons 15, 25, 45, 60, 90 « minutes » ; en marche : « Session en cours », temps restant | Toucher une durée : démarrer ; « Arrêter ». À la fin : notification « Session terminée » |
| F47 | Concentration de la semaine | P9 (PP:479-491) | Gratuit | « Cette semaine », « X h / Y h », graphique par jour | Aucune (lecture). L'objectif se règle dans S9 |
| F48 | « Mes paramètres » d'Études | S9 (`MiniAppSettings.swift:184`) ; questions `ProfileTopics.swift:601-632` | Gratuit | « Ce que tu étudies » (« Filière, niveau… ») ; « Ton rythme » : « Étude personnelle » (h par semaine), « Concentration » (h / sem.) | Saisir, effacer, « OK » |
| F49 | Supprimer une note ; supprimer une fiche | **Hors de la mini-app** : seulement dans la liste « Planning · études », en glissant (SS:116, SS:133). Les feuilles S5 et S6 n'ont pas de bouton de suppression (SS:557-600) | Gratuit | La ligne de la note ou de la fiche | Glisser pour supprimer, sans confirmation |

## 5. Données et calculs (modèles, champs, calculs existants à ne pas modifier ; ce qui est saisi, ce qui est calculé)

### Ce qui est saisi (modèles de DS)

| Modèle | Champs | Ligne |
|---|---|---|
| `Course` (cours) | nom, couleur (rose `D6409F` par défaut), enseignant, crédits (3 par défaut) | DS:3 |
| `ClassSlot` (entrée de l'horaire) | cours (facultatif), jour de semaine, autres jours, début et fin en minutes, salle, type (`course`, `work`, `appointment`, `other`), titre, date si « une seule fois », jours annulés, couleur choisie, exceptions par jour | DS:99 |
| `ClassOverride` (exception d'un jour) | titre, début, fin, salle, couleur | DS:218 |
| `Exam` (examen) | cours (facultatif), titre, date et heure, salle | DS:241 |
| `Assignment` (devoir) | cours (facultatif), titre, échéance, rendu ou non | DS:263 |
| `Grade` (note) | cours (facultatif), titre, note, « sur » (100 par défaut), poids en % (10 par défaut) | DS:285 |
| `Flashcard` (fiche) | paquet (texte libre, « Général » par défaut), question, réponse, boîte (1 à 5), prochaine date | DS:313 |
| `StudySession` (temps d'étude noté) | date, minutes, cours (facultatif) | DS:337 |
| `StudentState` (l'ensemble) | les listes ci-dessus, début et fin de session, objectif d'heures par semaine (10 par défaut), chrono en cours (début, cours), réponse de la fiche montrée ou non sur le widget | DS:355 |

Hors de `StudentState` :

- Concentration : `FocusSession` (début, fin, dernière durée, `Shared/Model/Content.swift:251`) ; journal `focusLog` et objectif `weeklyFocusGoalHours` (10 par défaut) dans `ProductivityState` (`Shared/Domains/Productivity.swift:176-177`). Ce sont des données de Planning.
- Profil : `studyField` (ce que la personne étudie, `Shared/Domains/Profile.swift:370`).
- Import : `ImportedSlot` (`App/Services/ScheduleImport/ScheduleParser.swift:13`) n'est pas gardé. C'est le brouillon de l'écran de vérification.

Tout est gardé sur l'iPhone, dans le dossier partagé avec les widgets (`Shared/Domains/StoredStates.swift:11`).

Valeurs par défaut à connaître :

- Couleur par type d'entrée : cours `D6409F`, travail `3366FF`, rendez-vous `F2A33A`, autre `7FA33A` (DS:87-94).
- Un cours créé à la main est rose. Un cours créé par l'import reçoit une des 10 couleurs, à tour de rôle (IV:49-50).
- Une nouvelle entrée de l'horaire : 8 h 30 à 10 h 20, le jour d'aujourd'hui (vendredi au plus tard) ; de type « Cours » s'il existe un cours, sinon « Autre événement » (SA:72-76).

### Ce qui est calculé (à ne pas modifier)

| Calcul | Règle | Ligne |
|---|---|---|
| Moyenne d'un cours | Somme (note ÷ « sur » × poids) ÷ somme des poids × 100 | DS:595 |
| Moyenne générale | Moyenne des cours, pondérée par les crédits. Si aucun cours n'a de note : moyenne des notes sans cours | DS:603 |
| « Évalué » | Somme des poids du cours, 100 % au plus | DS:701 |
| Moyenne à obtenir pour un objectif | (objectif × 100 − points gagnés) ÷ (100 − poids déjà évalué). Rien s'il reste 0,5 % ou moins | DS:707 |
| Avancement de la session | (aujourd'hui − début) ÷ (fin − début), entre 0 et 1 | DS:615 |
| Ce que contient un jour | Entrées de la semaine et entrées datées, exception du jour appliquée, annulations retirées | DS:552, DS:179 |
| Prochain cours | Premier cours (type `course`) non fini, sur 7 jours | DS:569 |
| Prochain cours d'une matière (ligne de « Mes cours ») | Première plage de ce cours non finie, sur 7 jours | SA:246 |
| Examens à venir, passés | Tri par date | DS:641, DS:645 |
| Compte à rebours | « aujourd'hui », « demain », « J-6 », « passé » (SA:48) ; pastille rouge à 3 jours ou moins (SA:514) | SA:48 |
| Devoirs par groupe | En retard, dans les 7 jours, plus tard | DS:657 |
| Temps d'étude | Par semaine, par jour, par cours, par semaine sur 6 semaines | DS:620, DS:625, DS:672, DS:683 |
| « révisé » d'un examen | Minutes d'étude du cours sur les 14 derniers jours | SA:544 |
| Heures de cours par semaine | Durée des plages hebdomadaires × nombre de jours | DS:693 |
| Chrono | Au moins 1 minute, 240 minutes au plus | DS:478 |
| Journal d'étude | Garde 200 jours | DS:464 |
| Fiches | Fiche due : la plus ancienne échue (DS:631). Sue : boîte + 1 (5 au plus), retour dans 1, 2, 4, 8, 16 jours. Ratée : boîte 1, retour dans 10 minutes | DS:454 |
| Paquets | Noms triés ; par paquet : total et nombre à réviser | DS:724 |
| Même cours ou non | Noms comparés sans majuscules, accents, espaces en trop ni ponctuation | DS:29 |
| Fusion de l'import | Jamais d'effacement ni de doublon ; « Remplacer » n'enlève que les cours hebdomadaires | IV:33, IV:119 |
| Suppression d'un cours | Ses plages partent ; notes, examens, devoirs et temps d'étude restent, sans cours | DS:491 |
| Concentration de la semaine | Minutes du journal de concentration | `Productivity.swift:276-284` |

## 6. Liens (carte de Mon quotidien : contenu et taille ; widgets ; autres mini-apps ; notifications et rappels ; liens profonds)

### Mon quotidien

- **Carte « Études »** : petite (demi-largeur). `DailyDefaults.wide` ne contient pas Études (`App/Core/DailyDefaults.swift:21`). Elle montre le titre et **une seule ligne** (`App/Screens/Home/DailySection.swift:448`). La ligne vient de `MiniAppSummary.caption` (`App/Screens/Home/MiniAppsRow.swift:81`), dans cet ordre : le prochain examen s'il est dans 14 jours ou moins (son titre, puis « J-N ») ; sinon « N devoirs à rendre » ; sinon la prochaine entrée de l'horaire du jour (son nom et son heure) ; sinon « N cours ». Un toucher ouvre Études.
- **Carte vide** : en pointillé, « Ajoute tes cours et tes examens : tes prochaines échéances apparaîtront ici. » (`App/Core/DailyBrief.swift:231`).
- **Quand la carte est là** : si l'intérêt « Études » a été choisi, si la personne a au moins un cours, ou si elle l'a ajoutée par « Ajouter une catégorie » (`App/Core/DailyCategories.swift:97-104`). Place par défaut : 6e, après Top 3 (`DailyDefaults.swift:11`). La taille se change en mode « Organiser… » (`DailySection.swift:261`).
- **Carte « Planning »** (grande) : c'est elle qui montre l'horaire de la semaine, donc les cours (`DailySection.swift:959`). Elle ouvre Planning.
- **Carte « À ne pas oublier »** : un examen dans la journée ou le lendemain ouvre la page « Examens » ; un devoir en retard ou à rendre sous 3 jours ouvre la page « Devoirs » (`DailyBrief.swift:568-573`).
- Mon quotidien est l'entrée d'Études sur l'Accueil (`App/Screens/Home/HomeView.swift:5`). Le fichier `MiniAppsRow.swift` décrit une rangée « Mes mini-apps », mais aucune vue ne l'affiche (aucune référence hors du fichier). Un accès par « Mes informations » : à vérifier.

### Widgets

Catégorie nommée « Planning · études » (`Shared/Model/KindCatalog.swift:20`). Liste : `KindCatalog.swift:226-233`. Destination au toucher : `Shared/Render/WidgetCanvas.swift:160-185`. Sans Premium, un widget Premium ouvre l'offre (`WidgetCanvas.swift:161`).

| Widget | Tailles | Gratuit ou Premium | Au toucher |
|---|---|---|---|
| « Prochain cours » | Petit, moyen, écran verrouillé (rectangle, ligne) | Gratuit | Planning |
| « Horaire » | Petit, moyen, grand, écran verrouillé (rectangle, ligne) | Gratuit | Planning |
| « Prochain examen » | Petit, moyen, écran verrouillé (rond, rectangle, ligne) | Gratuit | Études |
| « Session » | Petit, moyen, écran verrouillé (rond, ligne) | Gratuit | Études |
| « Devoirs » (cases à cocher) | Petit, moyen, grand, écran verrouillé (rectangle) | Premium | Études |
| « Moyenne » | Petit, moyen, grand | Premium | Études |
| « Fiche de révision » (« Réponse », « À revoir », « Je savais ») | Petit, moyen | Premium | Études |
| « Heures d'étude » | Petit, moyen, grand | Premium | Études |
| « Tableau études » (`KindCatalog.swift:266`) | Moyen, grand | Premium | Ni Études ni Planning : ce widget n'a pas d'espace dans le catalogue, il ouvre donc son propre réglage (`WidgetCanvas.swift:182-185`). À confirmer sur l'iPhone |
| « Focus » (minuteur, `KindCatalog.swift:133`) | Petit, moyen, écran verrouillé (rond, rectangle) | Premium | Études |
| « Travail profond » (`KindCatalog.swift:139`) | Petit, moyen, grand | Premium | Études |

Le contenu de chaque widget : `Shared/Render/Tiles/StudentTiles.swift`. Les widgets vides disent « Ajoute tes cours dans Ardane, espace Études. » (`StudentTiles.swift:4`). Le widget « Prochain cours » montre aussi un événement qui n'est pas un cours (« Prochain événement », `StudentTiles.swift:56-65`).

### Autres mini-apps

- **Planning** partage l'horaire : c'est la même liste `slots`. Le calendrier de Planning montre les cours, les examens et les devoirs (`App/Core/Agenda.swift:50-73`). Il ouvre les mêmes feuilles S2, S3, S4 (PA:255-287). Un devoir se coche aussi depuis Planning (PA:349). « Importer mon horaire » existe aussi dans Planning (PA:76-85). Le bloc « À remplir » de Planning demande « Cours et horaire » (`MiniAppToFill.swift:12`) : on y crée un cours avec « Nouveau cours » (`DataItemViews.swift:186`).
- **Concentration** est une page de Planning (PP:436), ouverte seulement depuis Études. Ses données sont celles de Planning.
- **Calendrier d'iOS** : la feuille S2 prévient d'un conflit avec le calendrier et l'horaire (SS:265).
- **« Mes informations »** : la carte Études montre « Études », « Étude perso », « Concentration », « Cours » (`App/Screens/Home/MyInfoSection.swift:66`). Les réponses sont les mêmes que dans S9.
- **Studio de widgets** : les cartes de données « Cours et horaire », « Examens », « Devoirs », « Notes », « Fiches » y sont proposées selon le widget (`App/Core/DataItems.swift:292-305`, `DataItemViews.swift:184-212`). Elles ouvrent les mêmes feuilles S1 à S6.

### Notifications et rappels

| Notification | Quand | Ouvre | Ligne |
|---|---|---|---|
| « Cours dans 30 minutes » | 30 minutes avant chaque cours | Planning | `Shared/Support/NotificationEngine.swift:604-623` |
| « Examen demain » | La veille au soir | Études | `NotificationEngine.swift:642` |
| « Rendez-vous demain », « Demain, une journée bien remplie » | La veille au soir | Planning | `NotificationEngine.swift:633`, `:647` |
| « Objectif d'étude atteint » | Quand l'objectif de la semaine est atteint | Études | `Shared/Support/Encouragements.swift:269` |
| « Beau travail » | À 1 h 30 d'étude dans la journée | Études | `Encouragements.swift:276` |
| « Session terminée » | À la fin d'une session de concentration | Aucune page précise : son identifiant (`tessera.focus.end`) n'a pas de destination | `Shared/Intents/InteractiveIntents.swift:101-109` ; `Shared/Support/SmartReminders.swift:137-185` |

Destinations : `SmartReminders.swift:146-180`. Réglage : « Cours dans 30 minutes » et « Examen demain » dépendent du même interrupteur « Planning » de Profil › Rappels (`NotificationEngine.swift:13`, `:35` ; `App/Screens/Profile/SmartRemindersView.swift:93`). Les deux encouragements dépendent de l'interrupteur des encouragements (`SmartRemindersView.swift:99`). Il n'y a pas de notification pour un devoir à rendre ni pour des fiches à réviser. « Mes paramètres » d'Études n'a pas de ligne de rappel (`MiniAppSettings.swift:124-129`).

### Liens profonds

- `tessera://space/student` ouvre l'écran principal d'Études (`Shared/Support/DeepLink.swift:14`, `Router.swift:168`).
- Aucun lien profond ne mène à une page précise (cours, examens, révisions).

## 7. États vides, première utilisation, erreurs, permissions, limites du mode gratuit

### Première utilisation (ni cours, ni examen, ni devoir)

- En-tête : la carte « Ton année en un coup d'œil », avec le texte « Ajoute tes cours : ton horaire, tes devoirs, tes examens et tes notes viendront s'y ranger. Ardane calcule ensuite tes moyennes et ce qu'il te reste à faire. » (SA:129-142). Pas de chiffres. La carte n'a pas de bouton.
- « À remplir » : la carte « Examens », « 0 / 1 ».
- « Mes cours » : seulement « Ajouter un cours ». « Mes examens » : seulement « Ajouter un examen ».
- « Concentration » et « Organisation étudiante » sont déjà là : chrono, « Horaire » (« Tes cours de la semaine »), « Importer mon horaire », « Devoirs » (« À rendre, rendus »), « Notes », « Révisions ».

### États vides des pages

| Où | Ce qui s'affiche | Ligne |
|---|---|---|
| Tuile « Moyenne » sans note | « – », « aucune note » | SA:151 |
| Tuile « Fiches » sans fiche | La tuile n'existe pas | SA:161 |
| Carte « Session » sans dates | La carte n'existe pas | SA:378 |
| « À rendre » sans devoir à rendre | Le bloc n'existe pas | SA:291 |
| « Horaire » vide | « Ton horaire », « Cours, travail, rendez-vous… Ajoute ce qui revient chaque semaine ou ce qui arrive une seule fois : ta semaine s'organise ici et dans le widget Horaire. », « Ajouter un événement » | SP:35 |
| Jour sans rien | « Rien de prévu ce jour-là. » | SP:116 |
| « Examens » vide | « Aucun examen noté. Ajoute-les dès que tu connais les dates : le compte à rebours et le temps révisé s'affichent ici. » | SP:559 |
| « Devoirs » vide | Seulement « Nouveau devoir », sans message | SP:617 |
| « Notes » vide | « Aucune note pour l'instant. Chaque note compte pour un pourcentage de son cours : Ardane en tire la moyenne du cours, puis ta moyenne générale. » | SP:679 |
| Fiches toutes révisées | « Tout est révisé pour l'instant. » | SP:848 |
| « Révisions » sans aucune fiche | Seulement « Nouvelle fiche » et la phrase sur la répétition espacée | SP:853-892 |
| Cours ouvert puis supprimé | « Cours supprimé » | SP:407 |

### Erreurs et garde-fous

- Chrono trop court : « Moins d'une minute : rien n'a été noté » (SA:630).
- Import : « Impossible de lire ce fichier » ou « Aucun cours trouvé », avec « Essayer avec une autre photo » (IV:289-311). Une image de plus de 30 Mo est refusée (IV:697). Un PDF ou un scan est lu sur 10 pages au plus (`App/Services/ScheduleImport/ScheduleReader.swift:40`). Pendant la lecture, la feuille ne se ferme pas d'un geste (IV:207).
- Vérification de l'import : « La fin doit venir après le début. » (IV:569) ; « Donne un nom à ce cours pour pouvoir l'ajouter. » (IV:511) ; « Rien de nouveau à ajouter » (IV:651).
- Formulaires : « Enregistrer » reste gris tant qu'il manque le nom, le titre, ou que la fin est avant le début (SS:175, SS:272, SS:518, SS:540, SS:562, SS:585).
- Conflit d'horaire : simple avertissement « En même temps que… », l'enregistrement reste possible (SS:314).

### Permissions

- **Caméra** : demandée seulement pour « Scanner avec la caméra ». D'abord une explication (« Utiliser la caméra », « Continuer », « Plus tard »), puis la demande d'iOS. Refusée : « Caméra désactivée », avec « Ouvrir Réglages » (`App/Screens/MiniApps/Nutrition/CameraAccessGate.swift:14`, `:122`). Sans caméra (simulateur), le bouton n'est pas proposé (CS:38).
- **Photos** : le sélecteur d'iOS, sans accès à la photothèque (IV:128).
- **Notifications** : nécessaires pour « Session terminée », « Cours dans 30 minutes », « Examen demain » et les encouragements.
- **Activités en direct** : si elles sont coupées dans Réglages, le chrono marche sans l'écran verrouillé (`StudyLiveActivity.swift:81`).

### Limites du mode gratuit

- Dans la mini-app, une seule chose est Premium : l'import d'horaire. Sans Premium, la feuille montre la carte « Importer mon horaire », « Premium lit ton horaire à partir d'une photo ou d'un PDF, sur ton iPhone. Ajouter tes cours et tes événements à la main reste gratuit. », et « Découvrir Premium » (IV:213, `App/Premium/PaywallContext.swift:56`).
- Aucune limite de nombre : cours, examens, devoirs, notes, fiches.
- Widgets Premium : « Devoirs », « Moyenne », « Fiche de révision », « Heures d'étude », « Tableau études », « Focus », « Travail profond ».

## 8. Problèmes d UX constatés aujourd hui (liste numérotée, chacun avec sa preuve : hiérarchie, répétitions, accès trop longs, libellés, densité). Des faits, pas des goûts.

35 problèmes. Les numéros 1 à 28 sont ceux de la première lecture ; 29 à 35 ont été ajoutés à la seconde.

Hiérarchie et longueur

1. **L'écran principal est une longue pile.** 8 blocs à la suite (SA:97-111). Avec 4 cours, le premier écran s'arrête à « Mes cours » : « Mes examens » commence sous la barre d'onglets (capture `mini-app-studies.png`). Le chrono d'étude, action de tous les jours, est dans le 7e bloc (SA:334).
2. **Les devoirs sont rangés dans « Mes examens » et coupés en deux.** « À rendre » est dessiné par la fonction des examens (SA:291). La page « Devoirs » est plus bas, dans « Organisation étudiante » (SA:353). Quand tout est rendu, « À rendre » disparaît, et le bouton « Nouveau devoir » de l'écran principal avec lui (SA:291).
3. **L'état vide n'a pas de bouton.** La carte « Ton année en un coup d'œil » dit d'ajouter des cours mais n'offre aucune action (SA:129-142). Juste dessous, « À remplir » demande un examen, pas un cours (`MiniAppToFill.swift:13`). L'import d'horaire n'y est pas proposé.

Répétitions

4. **Deux listes des mêmes cours.** « Mes cours » liste tous les cours (SA:177). Juste dessous, la ligne « Cours » ouvre une page qui liste les mêmes cours (SP:294). Les deux mènent au même détail.
5. **Le chrono d'étude est à deux endroits** : écran principal (SA:334) et « Révisions » (SP:765). Le conseil de la page « Examens » renvoie vers « Révisions » seulement (SP:567). Ce conseil est un texte : on ne peut pas le toucher.
6. **Deux minuteurs, deux objectifs, deux totaux.** Le « Chrono d'étude » compte le temps, par cours, vers l'objectif « Étude » (SA:633, DS:464). La « Concentration » est un compte à rebours, sans cours, vers un autre objectif (PP:497-503). Une session de concentration n'ajoute rien au temps d'étude. L'écran principal montre les deux totaux, à deux endroits (SA:157, SA:318).
7. **Une seconde interface modifie les mêmes données avec d'autres règles.** La liste « Planning · études » (SS:3) reste ouverte par « Tout voir » et par l'éditeur de widget. On y supprime en glissant, et « Nouvelle note » y est grisé sans cours (SS:118), ce qui n'est pas le cas dans la mini-app.

Accès longs ou cachés

8. **Les dates de la session sont cachées.** Elles sont en bas de la page « Cours » (SP:310). La carte « Session » n'apparaît qu'une fois les deux dates réglées (SA:378). Avant tout réglage, les deux champs montrent déjà une date (aujourd'hui, et dans 100 jours) qui n'est pas enregistrée (SP:311-312).
9. **Réviser une fiche demande trois niveaux.** Écran principal, puis « Révisions » tout en bas (SA:367), puis défiler sous le chrono et le graphique : les fiches sont le 4e bloc de la page (SP:765-768). Le raccourci « Fiches » en haut n'existe que s'il y a déjà des fiches (SA:161).
10. **L'import d'horaire est loin des cours.** La mission parle de « cours détectés automatiquement depuis un horaire importé ». Or l'import est dans le 7e bloc (SA:344), pas dans « Mes cours » ni dans l'état vide.
11. **La suppression change selon l'objet.** Cours : menu et confirmation (SA:186). Examen : appui long, sans confirmation, et impossible depuis la page du cours (SA:267, SP:481-491). Devoir : seulement en glissant dans la page « Devoirs » (SP:641). Note et fiche : aucune suppression dans la mini-app, leurs feuilles n'ont pas de bouton (SS:557-600 ; voir F49). Temps d'étude : un « +25 min » touché par erreur ne peut pas être retiré, aucune vue ne liste les sessions (DS:464).
12. **L'objectif de concentration ne se règle pas sur la page Concentration** (PP:436-495), seulement dans « Mes paramètres » (`ProfileTopics.swift:624`). L'objectif d'étude, lui, se règle sur « Révisions » (SP:810).

Libellés

13. **Deux libellés pour la même action.** « Ajouter un cours » (SA:200) et « Nouveau cours » (SP:303). « Ajouter un examen » (SA:277) et « Nouvel examen » (SP:554). « Nouveau devoir » (SA:300) et « Ajouter un devoir » (SP:495). « Nouvelle note » (SP:674) et « Ajouter une note » (SP:505).
14. **« Session » a deux sens dans l'app, trois avec la mission.** Le semestre (« Session », SA:381). Une session de concentration (« Session en cours », PP:452 ; « Session terminée », `InteractiveIntents.swift:109`). Et la mission parle de « sessions de révision ».
15. **La tuile « Étude » ouvre la page « Révisions »** (SA:156). Et « Notes » veut dire résultats chiffrés : le code doit préciser le sens du mot pour le traduire (`tr("Note", context: "grade")`, SS:562).
16. **« Mes paramètres » envoie ailleurs.** La carte « Ton rythme » dit « Tes cours, examens et notes s'ajoutent dans Créer › Études. » (`ProfileTopics.swift:605`), alors qu'ils s'ajoutent dans la mini-app où l'on se trouve.
17. **L'import garde la couleur et les mots de Planning.** Il est bleu dans une mini-app rose (IV:157). Il dit « Un horaire est déjà dans ton planning » (IV:393). Sa ligne dit « À partir d'une photo ou d'un PDF » (SA:348) sans citer la caméra, ajoutée le 2026-11-17.
18. **Les widgets sont rangés sous « Planning · études »** (`KindCatalog.swift:20`, `Shared/Model/WidgetKind.swift:35`) et le widget d'écran verrouillé s'appelle « Planning » (`Widgets/DesignWidgets.swift:68`), alors que ce sont deux mini-apps depuis le 2026-11-17. « Horaire » et « Prochain cours » ouvrent Planning, les autres ouvrent Études (`WidgetCanvas.swift:172-179`).
19. **« cours » désigne deux choses.** Une matière : « Mes cours », 4. Une plage : la ligne « Horaire » dit « 15 cours par semaine » avec les données de démonstration, car elle compte toutes les entrées hebdomadaires, travail et rendez-vous compris (SA:331, SA:339). La page « Horaire » d'Études montre d'ailleurs tous les types, avec un bouton « Ajouter un événement » (SP:46, SS:274).

Affichage

20. **Tuiles de hauteurs inégales sur la page d'un cours.** « Moyenne », « Évalué », « Étude » n'ont pas la même hauteur (capture `mini-app-studies-course.png` ; SP:424-428).
21. **Nom coupé dans la grille de l'horaire** : « Mathématique » puis « s » à la ligne (capture `mini-app-studies-timetable.png` ; texte de 9 points, SP:256-259).
22. **Les pages secondaires perdent la couleur d'Études.** L'écran principal a un lavis rose et une barre rose devant chaque titre. Les pages « Horaire », « Notes », « Révisions » et le détail d'un cours ont le fond bleuté de l'app et des titres sans barre (captures `mini-app-studies-grades.png`, `-revision.png`, `-timetable.png`, `-course.png` ; `MiniApp.swift:231` contre `MiniAppScaffold.swift:74`).
23. **Le graphique « Cette semaine » est en minutes, sans unité** (axe 0, 25, 50, 75, 100), sous un titre en heures, « 2 h 35 sur 12 h » (capture `mini-app-studies-revision.png` ; SP:787). Le graphique des 6 semaines est en heures (SP:826). Le graphique de la page « Concentration » est construit de la même façon : barres en minutes sous un titre en heures (PP:480-483) ; pas de capture, à vérifier à l'écran.
24. **Un examen passé affiche « Auj. » en rouge**, d'après le code : la pastille écrit « Auj. » dès que le nombre de jours est 0 ou moins (SA:514-517), et cette ligne sert aussi à la liste « Passés » (SP:572) et aux examens passés d'un cours (SP:486). Aucune capture ne le montre : à vérifier à l'écran.
25. **L'objectif de note d'un cours n'est pas gardé.** C'est une valeur de l'écran (`@State private var target = 80.0`, SP:370) : elle revient à 80 % à chaque ouverture, pour tous les cours.

Liens manquants entre les données

26. **Un examen et sa note ne sont pas reliés.** `Exam` n'a pas de résultat et `Grade` n'a pas d'examen (DS:241, DS:285). Un examen passé va dans « Passés » sans proposer de saisir la note. De plus, on peut écrire « Examen » comme « Titre de cette occurrence » d'un cours (SS:285) : cela ne crée pas d'examen.
27. **Les fiches ne sont pas reliées à un cours.** Le « paquet » est un texte libre (DS:315). La page d'un cours ne montre pas ses fiches.
28. **Un nouvel examen, devoir ou note prend le premier cours de la liste** quand on l'ajoute depuis l'écran principal (SA:59-69). La personne doit penser à changer le cours.

Constats ajoutés à la seconde lecture

29. **Deux écritures de l'heure dans la même mini-app.** L'écran principal écrit « 08:30 » (SA:250 ; capture `mini-app-studies.png` : « Demain · 08:30 »). La page d'un cours et l'horaire écrivent « 8:30–10:20 » (SA:44-46, SP:136, SP:474 ; capture `mini-app-studies-course.png`). De plus, Études affiche toujours l'heure sur 24 h (SA:250, SA:441, SA:500, SA:540), alors que la carte Études de Mon quotidien suit le réglage « Heure sur 24 h » (`MiniAppsRow.swift:89`). Ce réglage est proposé dans « Mes paramètres » de Planning, pas dans celui d'Études (`MiniAppSettings.swift:47`).
30. **Rien n'annonce que l'import est Premium.** La ligne « Importer mon horaire » n'a ni badge ni mention (SA:344-351). La personne sans Premium le découvre après le toucher, sur la carte verrou (IV:167, IV:213). Même chose dans Planning (PA:76-85).
31. **La carte Études de Mon quotidien peut montrer autre chose qu'un cours.** Sa troisième ligne possible prend la prochaine entrée de l'horaire du jour, quel que soit son type : un quart de travail ou un rendez-vous peut s'y afficher (`MiniAppsRow.swift:88` ; le commentaire du code dit pourtant « Classes only »).
32. **La page d'un cours ne montre pas ses séances « une seule fois ».** Sa section « Horaire » ne liste que les plages de chaque semaine (SP:467). Un cours ajouté pour une seule date (un rattrapage) n'y apparaît pas ; il se voit seulement dans la page « Horaire ».
33. **Deux habillages pour les pages secondaires.** « Cours » et « Devoirs » sont des listes du système, avec « Nouveau… » en simple ligne (SP:292, SP:303, SP:617-619). « Examens », « Notes », « Révisions », « Horaire » et le détail d'un cours sont des pages de cartes, avec un grand bouton (SP:34, SP:378, SP:553-554, SP:659, SP:674, SP:764). Pas de capture de « Cours » ni de « Devoirs » : rendu à vérifier à l'écran.
34. **Supprimer un cours demande une confirmation ici, pas là.** Dans la mini-app : toujours (SA:116, SP:326, SP:398). Dans la liste « Planning · études » : un glissement le supprime tout de suite (SS:28-32).
35. **Les feuilles s'ouvrent en bleu.** Dans la feuille « Cours », « Annuler » et « Enregistrer » sont bleus, dans une mini-app rose (capture `mini-app-studies-course-duplicate.png` ; `SheetForm`, `SpaceForms.swift:4`). Les autres feuilles (S2 à S6) utilisent le même cadre : même couleur attendue, à vérifier à l'écran.

## 9. Ce que la mission du PDG cite et qui n existe pas (liste ; « rien » si tout existe)

La mission (`MISSION.md`, partie D) cite 12 points. Existent en entier : la liste des cours, l'ajout à la main, le détail d'un cours, les examens à venir, l'association d'un examen à un cours, la Concentration. Les points ci-dessous n'existent pas, ou seulement en partie :

1. **Sessions de révision** : on ne peut pas prévoir une révision (date, heure, cours, examen visé). Il existe seulement du temps noté après coup (chrono, « +25 min ») et la révision des fiches.
2. **Suivi des révisions par examen** : pas d'objectif d'heures par examen, pas d'avancement, pas de liste de chapitres. Il existe seulement « X révisé » sur 14 jours (SA:544), le total de la semaine et les 6 dernières semaines.
3. **Historique des sessions d'étude** : aucune liste des sessions notées ; on ne peut ni les voir une à une, ni les corriger, ni les supprimer.
4. **Cours « détectés » reconnaissables** : l'import crée bien les cours (F44), mais rien ne dit ensuite qu'un cours vient d'un import (`Course` n'a pas de champ d'origine, DS:3). Et l'import est Premium : sans Premium, aucun cours n'est détecté.
5. **Dates et échéances au même endroit** : dans Études, examens, devoirs et fin de session sont dans trois listes séparées. La vue qui les réunit sur un calendrier est dans Planning (`Agenda.swift:50-73`).
6. **Organisation du travail au-delà des devoirs** : un devoir n'a ni étapes, ni priorité, ni note libre, ni pièce jointe (DS:263). Un cours et un examen n'ont pas de note libre non plus.
7. **Concentration reliée aux études** : la session de concentration ne choisit pas de cours et ne compte pas dans le temps d'étude (voir le problème 6 de la partie 8).

À traiter dans les planches comme de **nouvelles idées**, pas comme des fonctions existantes.

## 10. Captures CI disponibles (noms de fichiers dans origin/ci-report)

État constaté le 2026-11-17 (`git ls-tree -r --name-only origin/ci-report`, lecture seule) :

- **La pointe de `origin/ci-report` ne contient aucune image.** C'est le rapport du run 455 (`[interne]`, commit `170618c`) : `report.txt` et le dossier `history/` seulement (918 fichiers, 0 image).
- **Les 8 captures d'Études sont dans le rapport du run 454** (`[daily]`, commit `9261911`, encore présent dans le dépôt local : `origin/ci-report@{1}`). Pour les lire sans rien écrire dans le dépôt : `git show 9261911:tests/<nom>.png > <dossier temporaire>/<nom>.png`. Les 8 ont été relues à la seconde lecture.

| Fichier | Ce qu'il montre |
|---|---|
| `tests/mini-app-studies.png` | Écran principal, haut : carte « En cours », 3 chiffres, « Mes cours » |
| `tests/mini-app-studies-sections.png` | Presque la même image (le haut de l'écran) |
| `tests/mini-app-studies-course-added.png` | « Mes cours » avec un 5e cours ajouté |
| `tests/mini-app-studies-course-duplicate.png` | Feuille « Cours » avec la note de doublon |
| `tests/mini-app-studies-course.png` | Détail d'un cours : chiffres, objectif, « Horaire » |
| `tests/mini-app-studies-grades.png` | Page « Notes » |
| `tests/mini-app-studies-revision.png` | Page « Révisions » : chrono, semaine, première fiche |
| `tests/mini-app-studies-timetable.png` | Page « Horaire » : grille de la semaine |

Captures voisines, dans le même rapport : `tests/mini-app-planning.png` (Planning, avec la ligne « Importer mon horaire ») et `tests/profile-home-daily.png` (Mon quotidien).

Ce qui n'a **aucune capture** dans les rapports présents sur ce poste :

- Le bas de l'écran principal : « Mes examens », « À rendre », « Concentration », « Organisation étudiante », « Mes paramètres ».
- Les pages « Examens », « Devoirs », « Cours » (liste), « Concentration ».
- Les feuilles « Examen », « Devoir », « Note », « Fiche », « Événement », « Importer mon horaire », « Mes paramètres ».
- L'état vide, le mode sombre.

Le workflow sait pourtant en produire 11 autres avec le tag `[apps]` : `app-studies`, `app-studies-timetable`, `app-studies-courses`, `app-studies-course`, `app-studies-exams`, `app-studies-assignments`, `app-studies-grades`, `app-studies-revision`, `app-studies-end`, `app-studies-course-end`, `app-studies-revision-end` (`.github/workflows/build.yml:447-452`). Aucune n'est dans les rapports locaux.

## 11. Contraintes pour la conception (ce qu une nouvelle organisation doit absolument respecter)

1. **Garder les 49 fonctions de la partie 4.** Chaque planche doit pouvoir les situer toutes, y compris celles des menus et des appuis longs. La suppression d'une note et d'une fiche (F49) n'existe aujourd'hui que hors de la mini-app : une planche qui retire l'ancienne liste doit lui donner une place.
2. **Ne changer aucun calcul de la partie 5** : moyennes, poids, crédits, objectif de note, répétition espacée, chrono (1 minute au moins, 4 heures au plus), règle des doublons.
3. **Ne montrer comme existant que ce qui existe.** Les 7 points de la partie 9 sont à marquer « nouvelle idée ». Aucun champ nouveau n'est acquis (origine d'un cours, note libre, session planifiée, lien examen et note).
4. **L'horaire est commun avec Planning.** Une entrée ajoutée dans Études paraît dans Planning, et l'inverse. Il contient aussi le travail et les rendez-vous. Toute planche qui montre l'horaire dans Études doit dire ce qu'elle fait des entrées qui ne sont pas des cours.
5. **La Concentration reste accessible depuis Études et ne revient pas dans Planning.** Décision du PDG du 2026-11-17 (`docs/memoire/Decisions.md:133`) ; la mission l'interdit aussi pour Planning.
6. **Les quatre repères demandés par le PDG doivent rester lisibles** : « Mes cours », « Mes examens », « Concentration », organisation étudiante (`docs/audits/compte-rendu-nuit-2026-11-17.md:23`). La mission veut les cours « les uns en dessous des autres ».
7. **L'import d'horaire reste Premium, la saisie à la main reste gratuite.** La lecture se fait sur l'iPhone : garder les phrases « rien n'est envoyé ».
8. **Supprimer un cours garde ses notes, examens et devoirs** (DS:491). Les planches ne doivent pas promettre autre chose.
9. **Mon quotidien** : la carte Études est petite et tient en une ligne. L'horaire de la semaine est déjà dans la grande carte Planning : ne pas le répéter dans la carte Études.
10. **Destinations fixées et testées** (`Tests/StudiesMiniAppTests.swift:28`, `:44`) : widgets « Horaire » et « Prochain cours » vers Planning, les autres vers Études ; « Cours dans 30 minutes » vers Planning, « Examen demain » vers Études.
11. **Couleurs** : rose `D6409F` pour Études (`MiniApp.swift:42`), une couleur par cours, rouge d'alerte `E5484D` pour un examen à 3 jours ou moins et un devoir en retard, violet `8C6CFF` pour la Concentration et les fiches.
12. **Composants du style Cristal déjà en place** : `MiniAppScaffold` (en-tête sur lavis, puis sections, un bouton flottant possible mais pas utilisé ici), `MiniSectionTitle`, `MiniRowsCard`, `MiniRow`, `MiniStat`, `MiniActionButton`, feuilles `SheetForm`.
13. **Le chrono doit rester synchronisé** avec l'écran verrouillé et la Dynamic Island : démarrer, terminer, annuler (SA:641).
14. **7 langues** (français, anglais, espagnol, allemand, italien, portugais du Brésil, japonais) : prévoir la place des libellés longs.
15. **Petit écran** : l'iPhone de test est un iPhone 11 Pro (5,8 pouces). Les planches doivent tenir sur cette taille.
16. **Repères des tests d'interface à conserver à l'intégration** : les titres « Mes cours », « Mes examens », « Concentration » et les identifiants `studies-timer`, `studies-timer-start`, `studies-timer-stop`, `studies-add-course`, `course-row`, `course-row-menu`, `course-menu`, `course-duplicate-note`, `studies-courses`, `studies-timetable`, `studies-grades`, `studies-revision`, `assignment-toggle`, `card-reveal`, `card-known` (`UITests/MiniAppUITests.swift:272-370`).

## Relecture

Première lecture (commit `0e8dd68`) :

- Ajouté : l'état vide masque aussi les trois chiffres ; les suppressions en glissant et les boutons grisés de la liste « Planning · études » ; la suppression d'un cours depuis sa page qui revient en arrière ; `CoursePicker` ; l'ordre de « Toutes les notes ».
- Corrigé : la section 3 disait que la carte d'accueil ne remplaçait que la carte « En cours ».

Seconde lecture (2026-11-17, code relu en entier, les 8 captures regardées) :

- Vérifié : toutes les preuves fichier:ligne des parties 2 à 7 et 11 correspondent au code actuel. Les comptes 18 écrans et 3 fonctions Premium restent justes.
- Ajouté : la fonction F49 (supprimer une note ou une fiche, hors de la mini-app) : la partie 4 passe de 48 à 49 fonctions. Les problèmes 29 à 35 : la partie 8 passe de 28 à 35. `docs/design/2026-11-17-mini-apps/ESTIMATION.md` cite encore 48 et 28.
- Ajouté aussi : d'autres entrées vers les feuilles (calendrier de Planning, « À remplir », Studio de widgets, créateur d'espace) ; la route `studiesHome` jamais utilisée ; l'interrupteur « Planning » qui commande les rappels de cours et d'examen ; les valeurs par défaut d'un cours et d'une entrée ; l'état « Révisions » sans fiche.
- Corrigé : la confirmation de suppression depuis la page d'un cours s'intitule « Supprimer « nom du cours » ? », pas « Supprimer ce cours ? ». La ligne de la carte Études dans Mon quotidien prend la prochaine entrée de l'horaire, pas seulement un cours.
- Levé : la destination de la notification « Session terminée » (aucune page précise, d'après le code) et celle du widget « Tableau études » (son propre réglage, d'après le code ; à confirmer sur l'iPhone).
- Reste incertain : l'accès à « Mes informations » depuis l'Accueil ; le comportement à l'écran d'un examen passé (« Auj. »), du graphique de la page « Concentration », des pages « Cours » et « Devoirs » et de la couleur des feuilles S2 à S6, faute de captures.
