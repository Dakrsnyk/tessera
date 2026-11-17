# Audit : Habitudes

Relevé fait dans le code le 2026-11-17 (branche `main`, commit `19f6eb1`). Lecture seule. Chaque ligne porte sa preuve (fichier:ligne). Ce qui n'a pas pu être prouvé est marqué « à vérifier ».

## 1. En bref

- Sert à suivre de petites actions à refaire chaque jour (lire, marcher, méditer) : on coche, la série grandit.
- Pour tout le monde : la carte « Habitudes » est présente d'office dans Mon quotidien (`App/Core/DailyDefaults.swift:17`). Usage prévu : une à plusieurs fois par jour, surtout le soir (rappel du soir à 19 h, `Shared/Model/Settings.swift:146`).
- **Habitudes n'est PAS une mini-app dans le code.** L'énumération `MiniApp` n'a pas de cas « habits » (`App/Screens/MiniApps/MiniApp.swift:6`). C'est une page de Planning (`MiniAppPage.planningHabits`, `MiniApp.swift:99`), plus un deuxième écran en liste (`HabitsView`) ouvert depuis le Profil, les widgets et Créer.
- État : simple et stable. Tout est quotidien. Il existe : cocher, série, régularité en %, grille des semaines, rappel, 4 widgets, notifications. Il n'existe pas : hebdomadaire, objectifs, calendrier mensuel, page de statistiques, page de détail.
- Gratuit : 3 habitudes (`App/Core/AppModel.swift:13`). Premium : habitudes sans limite, section « Régularité », 2 widgets, tableaux de bord.

## 2. Écrans et navigation

### Écrans et feuilles (9)

| # | Écran ou feuille | Vue SwiftUI, fichier:ligne | Comment on y arrive | Ce qu'on y fait |
|---|---|---|---|---|
| E1 | Page « Habitudes » (cartes). C'est l'écran principal. | `PlanningHabitsPage`, `App/Screens/MiniApps/Planning/PlanningPages.swift:346` ; route `MiniAppPage.planningHabits` (`MiniApp.swift:195`) | a) Accueil › Mon quotidien › carte « Habitudes » (1 toucher, `App/Screens/Home/DailySection.swift:1088`). b) Planning › ligne « Habitudes », tout en bas (`App/Screens/MiniApps/Planning/PlanningApp.swift:113`). | Choisir le jour, cocher, ouvrir une habitude, en ajouter une, lire la régularité (Premium). |
| E2 | Écran « Habitudes » (liste système) | `HabitsView`, `App/Screens/Content/HabitsView.swift:3` | a) Profil › Notifications › « Rappels d'habitudes » (`App/Screens/Profile/ProfileView.swift:127`). b) Profil › Tes données › « Habitudes » (`ProfileView.swift:141`). c) Toucher le widget « Habitudes » : lien `tessera://habits`, feuille avec bouton « OK » (`Shared/Render/WidgetCanvas.swift:165`, `App/Core/Router.swift:161`, `App/ArdaneApp.swift:120` et `:331`). d) Studio › Contenu › « Gérer mes habitudes » (`App/Screens/Editor/KindOptionsSection.swift:140`). e) Carte « Habitudes » d'un bloc « À remplir » › « Gérer mes habitudes » (`App/Screens/Profile/DataItemViews.swift:151`). f) Page d'espace E8 › « Mes habitudes ». | Comme E1, plus : réordonner (« Modifier »), supprimer par balayage, voir « x sur 3 habitudes en version gratuite. ». Sans la section « Régularité ». |
| E3 | Feuille « Nouvelle habitude » / « Habitude » | `HabitEditor`, `HabitsView.swift:154` | Bouton d'ajout de E1 ou E2 ; toucher la bande d'une habitude (hors rond) dans E1 ou E2. | Nom, icône (20), couleur (8), « Rappel quotidien » + « Heure », « Supprimer l'habitude », « Enregistrer ». |
| E4 | Feuille « Choisir une date » | feuille de `DaySwitcher`, `App/Screens/MiniApps/MiniApp.swift:531` | Toucher la date du sélecteur de jour (E1, E2). | Calendrier graphique, jours passés et aujourd'hui seulement ; « Aujourd'hui », « OK ». |
| E5 | Dialogue « Supprimer l'habitude ? » | `confirmationDialog`, `HabitsView.swift:240` | E3 › « Supprimer l'habitude ». | « Supprimer » ; message « Son historique et sa série seront effacés. ». |
| E6 | Feuille d'explication de la permission Notifications | `.permissionSheet(.notifications…)`, `HabitsView.swift:266-271` | E3, en activant « Rappel quotidien » la première fois. | Lire l'explication, puis la demande d'iOS. Refus : le rappel reste éteint. |
| E7 | Feuille Premium (2 contextes) | `PaywallView` ; contexte « Plus de 3 habitudes » (`App/Premium/PaywallContext.swift:47`) ; contexte de la carte verrou (`App/Premium/PremiumLock.swift:30`) | Ajouter une 4e habitude sans Premium (bouton d'ajout de E1/E2, ou « Enregistrer » dans E3 : la feuille reste ouverte, `HabitsView.swift:307-308`) ; « Découvrir Premium » sur la carte « La régularité est dans Premium ». | Voir l'offre, s'abonner. |
| E8 | Page d'espace « Habitudes » (onglet Créer) | `SpaceView` (`App/Screens/Spaces/SpaceView.swift:5`) + `HabitsSpaceSections` (`App/Screens/Spaces/ProductivitySpace.swift:353`) | a) Toucher une notification d'habitude. b) Toucher un widget « Série », « Semaine d'habitudes » ou « Taux de réussite » : lien `tessera://space/habits` (`Shared/Support/SmartReminders.swift:145`, `:153`, `:168` ; `WidgetCanvas.swift:182` ; `Router.swift:168-176` ; `App/Screens/Spaces/CreateView.swift:34`). c) Studio › « Données de l'espace Habitudes » (`App/Screens/Editor/SpaceOptionsSection.swift:58`, version sans bande de widgets). | Bande « Widgets de l'espace » ; « Suivi » › « Mes habitudes » (nombre) › E2 ; « Ce mois-ci » : une ligne par habitude avec sa série. |
| E9 | Écran « Rappels intelligents », section « Habitudes » | `SmartRemindersView`, `App/Screens/Profile/SmartRemindersView.swift:88` | Profil › Notifications › « Rappels intelligents ». | Un interrupteur « Habitudes ». Texte : « Les habitudes qu'il te reste à faire, ta série, un record battu et le bilan de la semaine. ». |

### Points d'entrée qui ne sont pas des écrans

| Point d'entrée | Où, fichier:ligne | Ce qu'il fait |
|---|---|---|
| Carte « Habitudes » de Mon quotidien (avec données) | `HabitsDayTile`, `DailySection.swift:1070` | Toute la carte est un lien vers E1. On ne coche pas dessus. |
| Carte pointillée « Habitudes » de Mon quotidien (vide) | `App/Core/DailyBrief.swift:233` et `:244-245` ; `DailySection.swift:22` | Texte « Ajoute une habitude à suivre chaque jour. ». Ouvre la mini-app **Planning** entière, pas E1. |
| Ligne « Habitudes » de Planning | `PlanningApp.swift:113-118` | Détail « Séries et régularité », valeur « faites/total » du jour. Ouvre E1. |
| Carte « Habitudes » du bloc « À remplir » de Planning | `App/Screens/MiniApps/MiniAppToFill.swift:12` ; `DataItemViews.swift:143-152` | Champ « Ex. : méditer, lire, marcher » : ajout par le nom seul. Puis lien « Gérer mes habitudes ». Même carte dans « Tes données » du Studio et des packs (`WidgetDataSection`, `DataItemViews.swift:12`). |
| Question « Une habitude à suivre » | `App/Screens/Profile/ProfileTopics.swift:670-681` | Même ajout rapide. Thème « Bien-être » des premières questions et de « Mes informations ». Retirée de « Mes paramètres » de Planning (`App/Screens/MiniApps/MiniAppSettings.swift:15-17`). |
| « Mes informations » › zone « Habitudes » | `App/Screens/Home/MyInfoCenter.swift:54`, `:203` ; `DailySection.swift:22` | Ouvre Planning (pas E1). |
| Studio, widget « Série » : choix « Habitude » | `SpaceOptionsSection.swift:12`, `:24`, `:47` | « Automatique » ou une habitude précise. |
| Créer › taille › catégorie « Habitudes » | `App/Screens/Spaces/CreateFlow.swift:40` ; `Shared/Model/KindCatalog.swift:132`, `:147-149` | Fabriquer un des 4 widgets d'habitudes. |

## 3. Écran principal : sections dans l'ordre actuel

Écran principal = page « Habitudes » de Planning (E1, `PlanningPages.swift:361-400`). Fond et marges communs (`MiniAppScroll`), sans le cadre des mini-apps (pas de bandeau, pas d'action flottante).

1. **Titre large « Habitudes »** (`PlanningPages.swift:395-396`).
2. **Sélecteur de jour** (`DaySwitcher`, `:366`, teinte `7FA33A`) : ‹, « Aujourd'hui » (ou « Hier », ou la date), flèche de retour à aujourd'hui, ›. Jamais de jour futur. Caché s'il n'y a aucune habitude.
3. **Une carte par habitude** (`HabitRow` dans `.miniCard()`, `:375-385` ; dessin dans `HabitsView.swift:85-152`). Dans chaque carte :
   - une bande : rond à cocher du jour choisi ; icône et nom ; « Série de N jours » ou « Pas encore de série » ; à droite le % de régularité sur 30 jours (absent tant que rien n'a été coché) ;
   - sous la bande : la grille des 26 dernières semaines (52 sur iPad), un carré par jour, plein si fait.
4. **Bouton « Ajouter une habitude »** (`:386-391`).
5. **Section « Régularité »** (`:392`, `:403-425`). Premium : une ligne par habitude, « Meilleure série : N jours » et « x % · y % » (30 jours · 90 jours), puis la note « Compté depuis le premier jour coché, sur 30 et 90 jours. ». Gratuit : carte verrou « La régularité est dans Premium ».

Sans habitude : à la place de 2 à 5, un état vide « Tes habitudes » / « Lire, marcher, méditer… Coche-les chaque jour et regarde ta série grandir. » / bouton « Ajouter une habitude » (`:368-372`).

Variante E2 (`HabitsView.swift:10-79`), dans l'ordre : sélecteur de jour ; liste des habitudes (mêmes `HabitRow`) avec pied « x sur 3 habitudes en version gratuite. » ; bouton « Nouvelle habitude » ; bouton « Modifier » en haut à gauche dès 2 habitudes.

## 4. Fonctions existantes

Liste de référence : aucune planche ne doit en perdre une. Premium : 5 (F13, F14 au-delà de 3, F20, F21, F22).

| # | Fonction | Où elle est | Gratuit ou Premium | Données affichées | Actions possibles |
|---|---|---|---|---|---|
| F1 | Liste de ses habitudes | E1, E2 (`HabitsView.swift:33`, `PlanningPages.swift:375`) | Gratuit | Nom, icône, couleur de chaque habitude | Faire défiler |
| F2 | Cocher ou décocher une habitude pour le jour affiché | Rond de `HabitRow` (`HabitsView.swift:101-114`) | Gratuit | Rond plein avec coche = fait ; rond vide = à faire | Un toucher, avec vibration |
| F3 | Changer de jour pour rattraper un oubli | `DaySwitcher` (`MiniApp.swift:468-570`) ; E4 | Gratuit | « Aujourd'hui », « Hier » ou la date | Jour précédent, jour suivant (bloqué à aujourd'hui), choisir une date passée, « Revenir à aujourd'hui » |
| F4 | Série en cours | `HabitRow` (`HabitsView.swift:126`) | Gratuit | « Série de N jours » ou « Pas encore de série » | Aucune |
| F5 | Régularité sur 30 jours | `HabitRow` (`HabitsView.swift:131-136`), calcul `HabitHeatmap.rate` | Gratuit (décision du 2026-10-22, `docs/memoire/Decisions.md:27`) | Un % à droite du nom | Aucune |
| F6 | Grille des dernières semaines | `HabitHeatmapGrid` (`HabitsView.swift:148`) | Gratuit | 26 colonnes de 7 jours (52 sur iPad), sans dates écrites | Aucune (lecture) |
| F7 | Créer une habitude | E3 (`HabitsView.swift:183-236`, `:285-313`) | Gratuit jusqu'à 3 | Champs : « Nom », « Icône », « Couleur », « Rappel quotidien », « Heure » | « Annuler », « Enregistrer » (grisé sans nom) |
| F8 | Modifier une habitude | Toucher la bande › E3 (`HabitsView.swift:116`, `:296-305`) | Gratuit, même au-delà de 3 | Les mêmes champs, remplis | Tout changer sauf les jours cochés, qui sont gardés |
| F9 | Supprimer depuis la fiche, avec confirmation | E3 › E5 (`HabitsView.swift:229-248`) | Gratuit | « Son historique et sa série seront effacés. » | « Supprimer » ; le rappel est annulé |
| F10 | Supprimer par balayage | E2 seulement (`HabitsView.swift:41-45`) | Gratuit | — | Balayer ; pas de confirmation |
| F11 | Réordonner les habitudes | E2 seulement, bouton « Modifier » (`HabitsView.swift:46-48`, `:70-74`) | Gratuit | — | Glisser les lignes. L'ordre décide de ce que montrent la carte et les widgets (F16, F18, F20) |
| F12 | Rappel quotidien par habitude | E3 (`HabitsView.swift:218-228`) ; `App/Services/NotificationScheduler.swift:30-42` | Gratuit | Notification : titre = nom de l'habitude, texte « C'est le moment de valider ton habitude du jour. » | Activer, choisir l'heure (20:00 proposé) |
| F13 | Section « Régularité » : 30 jours, 90 jours, meilleure série | E1 seulement (`PlanningPages.swift:403-431`) | **Premium** | Par habitude : « Meilleure série : N jours », « x % · y % » | Aucune. Gratuit : carte verrou, « Découvrir Premium » |
| F14 | Limite gratuite et offre | `AppModel.swift:13`, `:490-499` ; `PaywallContext.swift:47-53` ; pied de E2 (`HabitsView.swift:49-53`) | 3 en gratuit ; **Premium** : sans limite | « x sur 3 habitudes en version gratuite. » (E2) ; offre « Plus de 3 habitudes » | Seul l'ajout est bloqué. Les habitudes déjà là restent et se modifient |
| F15 | Ajout rapide par le nom seul | Bloc « À remplir » de Planning, « Tes données » du Studio, « Une habitude à suivre » (`DataItemViews.swift:143-152`, `ProfileTopics.swift:670-681`) | Gratuit jusqu'à 3 | Champ « Ex. : méditer, lire, marcher » ; « N habitudes suivies » | Taper un nom, valider. Icône et couleur mises d'office |
| F16 | Carte « Habitudes » de Mon quotidien | `HabitsDayTile` (`DailySection.swift:1070-1210`) | Gratuit | Voir la section 6 | Toucher = ouvrir E1. Appui long : « Retirer de Mon Quotidien », « Organiser… » |
| F17 | Ligne « Habitudes » de Planning | `PlanningApp.swift:113-118` | Gratuit | « Séries et régularité » ; « faites/total » d'aujourd'hui | Ouvrir E1 |
| F18 | Widget « Habitudes » (petit, moyen, grand) | `HabitsWidgetView` (`Shared/Render/Kinds/ProductivityWidgets.swift:70-204`) ; `KindCatalog.swift:132` | Gratuit | « faites/total » ; par habitude : rond, nom, flamme + série, % 30 jours, grille. 3 habitudes (petit, moyen), 7 (grand) | Cocher sur l'écran d'accueil (`ToggleHabitIntent`, `Shared/Intents/InteractiveIntents.swift:31`) ; toucher ailleurs ouvre E2 |
| F19 | Widget « Série » (petit, moyen, rond d'écran verrouillé) | `ProductivityTiles.swift:130-164` ; `KindCatalog.swift:147` | Gratuit | Série d'une habitude ; « fait aujourd'hui » / « pas encore fait aujourd'hui » ; petit : la semaine ; moyen : le mois en calendrier et « Record : N jours » | Moyen : bouton « Fait ». Studio : choisir l'habitude ou « Automatique » (la plus longue série) |
| F20 | Widget « Semaine d'habitudes » (moyen, grand) | `ProductivityTiles.swift:183-201` ; `KindCatalog.swift:148` | **Premium** | Grille 7 jours × 6 habitudes au plus ; « N / total » « validations cette semaine » | Lecture |
| F21 | Widget « Taux de réussite » (petit, moyen) | `ProductivityTiles.swift:203-230` ; `KindCatalog.swift:149` | **Premium** | % du mois en cours, « des habitudes tenues en <mois> », anneau, une ligne par habitude | Lecture |
| F22 | Ligne « Habitudes x/y » dans « Ma journée » et « Maintenant » ; habitudes dans « Analyse productivité » | `Shared/Render/Tiles/DashboardTiles.swift:52-57` ; `Shared/Data/Insights.swift:169-193` ; `KindCatalog.swift:261-270` | **Premium** (ces widgets le sont) | « Habitudes » « faites/total » ; « <nom> · série de N j » | Lecture |
| F23 | Notifications intelligentes « Habitudes » | `Shared/Support/NotificationEngine.swift:471-517` ; réglage E9 | Gratuit | « Tes habitudes du jour » (il en reste N), « Ta série continue » (dès 3 jours), « Nouveau record », « Ta semaine d'habitudes » (dimanche, en %) ; à l'heure du résumé du soir | Couper avec l'interrupteur « Habitudes » |
| F24 | Encouragement « Belle série » | `Shared/Support/Encouragements.swift:286-300` | Gratuit | « N jours d'affilée pour « nom ». Continue comme ça ! » aux paliers 7, 21, 30, 50, 100, 200, 365 | Aucune (réglage « Encouragements ») |
| F25 | Page d'espace « Habitudes » | E8 (`ProductivitySpace.swift:353-374`) | Gratuit | Widgets de l'espace ; « Mes habitudes » (nombre) ; série par habitude | Ouvrir un widget dans le Studio ; ouvrir E2 |
| F26 | Compteurs d'habitudes ailleurs | Profil, tuile « N habitudes » (`ProfileView.swift:388`) ; « Mes informations » (`App/Screens/Home/MyInfoSection.swift:75`) | Gratuit | Le nombre d'habitudes | Aucune |
| F27 | Liens profonds | `Shared/Support/DeepLink.swift:8`, `:30`, `:52` ; `Router.swift:161`, `:168-176` | Gratuit | — | `tessera://habits` ouvre E2 en feuille ; `tessera://space/habits` ouvre E8 dans Créer |
| F28 | Widget « Hydratation » rangé dans la catégorie « Habitudes » de Créer | `KindCatalog.swift:146` (catégorie `wellbeing`) ; `Router.swift:162-163` | Gratuit | « Tes verres d'eau de la journée, ajoutés d'une touche. » Ce n'est pas une habitude (aucun lien avec `Habit`) ; la mini-app Eau est retirée, un ancien widget ouvre l'accueil | Cocher sur le widget. Hors page Habitudes ; à garder dans la catégorie ou à déplacer (à décider) |

## 5. Données et calculs

### Modèle (à ne pas changer de format)

`struct Habit` (`Shared/Model/Content.swift:128-232`), rangé dans `ContentState.habits` (`Content.swift:314`), dans l'App Group, lu aussi par les widgets.

| Champ | Type | Saisi ou calculé |
|---|---|---|
| `id` | UUID | Créé par l'app |
| `name` | texte | Saisi (« Nom », ou ajout rapide) |
| `symbol` | nom d'icône | Saisi : 20 icônes (`HabitsView.swift:168-173`). Ajout rapide : `checkmark.circle` |
| `colorHex` | couleur | Saisi : 8 couleurs gratuites, Jade, Cobalt, Corail, Ambre, Lilas, Rose, Olive, Ardoise (`Shared/Theme/Palette.swift:13-22`) |
| `completedDays` | liste de jours « aaaa-MM-jj » | Écrit en cochant (app ou widget). 400 jours gardés au plus, les plus vieux partent (`Content.swift:167-180`) |
| `reminderHour`, `reminderMinute` | heure, ou rien | Saisi (« Rappel quotidien », « Heure ») |

Il n'y a **pas** de champ pour : fréquence, jours de la semaine, objectif, quantité, note, date de début, pause ou archive.

Tests qui gardent le format : `testHabitEncodedFormatIsUnchanged` et `testHabitFromAnOlderFormatWithoutAFieldIsStillRead` (`Tests/Audit24FitnessPlanningTests.swift:21`, `:32`).

### Calculs existants (à ne pas modifier)

| Calcul | Règle | Preuve |
|---|---|---|
| Fait ce jour-là | Le jour est dans `completedDays` | `Content.swift:163` |
| Cocher | Ajoute ou retire le jour ; un seul chemin : `toggleHabit` | `Content.swift:167`, `:351` |
| Série en cours | Jours d'affilée jusqu'à aujourd'hui ; si aujourd'hui n'est pas fait, jusqu'à hier | `Content.swift:217-226` ; `Tests/HabitStreakTests.swift` |
| Meilleure série (page) | Plus longue suite de jours parmi tous les jours gardés | `Content.swift:199-214` |
| Régularité sur N jours | Jours faits ÷ jours écoulés, sur N jours, sans remonter avant le premier jour coché ; rien avant le premier jour coché | `Content.swift:184-196` ; `Tests/OctoberRequestsTests.swift:237` |
| % affiché sur la carte | Régularité sur 30 jours | `Shared/Render/Tiles/HabitHeatmap.swift:12`, `:91-94` |
| Grille | Semaines complètes, la dernière colonne est la semaine en cours ; jours à venir non dessinés ; une seule rangée de jours récents quand la hauteur manque | `HabitHeatmap.swift:17-79` ; `Tests/HabitHeatmapTests.swift` |
| Carte Mon quotidien | Faites aujourd'hui ÷ total ; série par habitude ; la carte montre la plus longue | `DailyBrief.swift:352-355` ; `DailySection.swift:1083` |
| Widget « Série » : « Record » | Plus longue suite sur les 366 derniers jours (calcul à part de la page) | `ProductivityTiles.swift:167-181` |
| Widget « Taux de réussite » | Jours faits ÷ jours écoulés depuis le 1er du mois en cours, par habitude et au total | `ProductivityTiles.swift:203-230` |
| Widget « Semaine d'habitudes » | Coches de la semaine ÷ (jours écoulés × habitudes, 6 au plus) | `ProductivityTiles.swift:183-201` |
| Notifications | « Actif » = au moins un jour fait en 14 jours ; série à garder dès 3 jours ; record = dépasse l'ancienne meilleure série (≥ 2) ; bilan du dimanche si au moins 3 jours comptés | `NotificationEngine.swift:471-517` |
| Paliers d'encouragement | 7, 21, 30, 50, 100, 200, 365 jours | `Encouragements.swift:286` |
| Demande de note App Store | Une série de 5 jours ou plus compte comme « bonne expérience » | `Shared/Model/ReviewPrompt.swift:34`, `:81` |
| Limite gratuite | 3 habitudes ; `addHabit` est le seul chemin d'ajout | `AppModel.swift:13`, `:490-499` ; `Tests/Audit24AppModelTests.swift:133` |

À chaque changement d'habitude, `updateContent` (`AppModel.swift:476-488`) enregistre, regarde s'il faut un encouragement, replanifie les notifications et recharge les widgets.

À savoir : le moteur de notifications sait déjà lire des « jours prévus » par habitude (`habitSchedule`, `NotificationEngine.swift:164-171`), mais l'app ne le remplit jamais. Seul un test s'en sert (`Tests/SmartNotificationEngineTests.swift:245`). Noté « logique prête, inactive » dans `docs/memoire/Demandes.md:276`.

## 6. Liens

### Carte de Mon quotidien

- Titre « Habitudes », icône `repeat`, teinte `5C8424`, chevron. Toute la carte est un lien vers E1 (`DailySection.swift:1088`, `:559-561`).
- Place par défaut : 4e, après Nutrition, Fitness, Planning, avant Top 3 (`DailyDefaults.swift:11-14`). Présente pour tous, même vide (`:17`).
- Tailles : il n'y a que deux largeurs, demi et pleine (`App/Screens/Home/DailyLayoutRules.swift:8-10`). Pleine largeur par défaut (`DailyDefaults.swift:21`). Le code dit que « moyen » et « grand » ont la même largeur (`DailyDefaults.swift:19-20`).
- Contenu en pleine largeur (`DailySection.swift:1115-1128`) : grand chiffre « faites/total » ; à droite « Série de N jours » (la plus longue de toutes) ; puis une ligne par habitude, 5 au plus : anneau du jour, nom, derniers jours en petits carrés (aujourd'hui en dernier) ; « +N » s'il y en a plus.
- Contenu à demi-largeur, à côté d'une autre carte (`:1089-1114`) : un anneau par habitude (5 au plus, « +N ») ; « faites/total » ; « faites aujourd'hui » ; puis « Série de N jours », ou la liste des noms s'il n'y a pas de série.
- Vide : carte pointillée « Habitudes », « Ajoute une habitude à suivre chaque jour. », « Ajouter » ; ouvre Planning (`DailyBrief.swift:233`, `:244-245`).
- Réglages par la personne : retirer, déplacer, agrandir ou rétrécir (« Organiser… », `App/Screens/Home/DailyEditMode.swift:78-179`).
- VoiceOver lit chaque ligne avec « Régularité : x % » ; un test le vérifie (`UITests/HomeLayoutUITests.swift:49-111`).

### Widgets

| Widget | Tailles | Gratuit / Premium | Au toucher |
|---|---|---|---|
| « Habitudes » | Petit, moyen, grand | Gratuit, interactif | Le rond coche ; le reste ouvre E2 en feuille |
| « Série » | Petit, moyen, rond d'écran verrouillé | Gratuit | Ouvre E8 (onglet Créer) |
| « Semaine d'habitudes » | Moyen, grand | Premium | Ouvre E8 ; sans Premium, ouvre l'offre (`WidgetCanvas.swift:162`) |
| « Taux de réussite » | Petit, moyen | Premium | Idem |

- Écran verrouillé : entrée « Habitudes » de la galerie iOS, groupe « Suivi d'habitudes » (`Widgets/DesignWidgets.swift:79-81` ; `Shared/Model/WidgetGroup.swift:19`).
- Modèles et packs du Store qui en contiennent : « Mes habitudes », « Routine rétro », « Série » (`Shared/Model/Templates.swift:90-91`, `:129`) ; pack « Bonnes habitudes » et 7 autres packs (`Shared/Model/Packs.swift:58-111`).
- Sans habitude, les widgets disent « Aucune habitude » / « Crée-les dans Ardane » (`ProductivityWidgets.swift:96`), ou « Crée une habitude dans Ardane pour suivre ta série. » (`ProductivityTiles.swift:135`).

### Autres mini-apps

- Planning : Habitudes y vit (ligne en bas de page, bloc « À remplir »). Les cartes « habits » de Mon quotidien sont comptées comme cartes de Planning (`App/Core/DailyCategories.swift:16`).
- Les habitudes n'apparaissent pas dans le calendrier ni dans l'agenda de Planning (aucune mention dans `App/Core/Agenda.swift`).
- Aucun lien avec Nutrition, Fitness, Études ou Finances.
- Créer : `Space.habits` existe comme « espace » (titre « Habitudes », sous-titre « Habitudes et séries », couleur `7FA33A`, `KindCatalog.swift:13`, `:30`, `:64`), sans mini-app derrière.

### Notifications et rappels

- Rappel quotidien par habitude, à heure fixe (F12). Identifiant `tessera.habit.<id>`.
- 4 notifications intelligentes (F23) et l'encouragement « Belle série » (F24).
- Règles communes : silence de 22 h à 8 h, 4 par jour au plus, 90 minutes d'écart (`Settings.swift:139-144`).
- Au toucher, toutes ouvrent `tessera://space/habits`, donc E8 dans l'onglet Créer (`SmartReminders.swift:145`, `:153`, `:168-169` ; test `Tests/Audit24WidgetsNotificationsTests.swift:98`).

### Liens profonds

- `tessera://habits` : feuille E2 avec « OK ».
- `tessera://space/habits` : onglet Créer, page E8. `Router.handle` cherche une mini-app pour l'espace « habits », n'en trouve pas, et ouvre l'espace (`Router.swift:168-176`).

## 7. États vides, première utilisation, erreurs, permissions, limites du mode gratuit

- **États vides** : E1 « Tes habitudes » + bouton « Ajouter une habitude » (`PlanningPages.swift:368-372`). E2 « Aucune habitude pour l'instant » / « Crée une habitude, puis valide-la chaque jour d'une touche sur ton widget. » (`HabitsView.swift:20-30`). E8 « Crée une habitude pour suivre ta série. » (`ProductivitySpace.swift:370`). Mon quotidien : carte pointillée.
- **Avant le premier jour coché** : pas de %, « Pas encore de série », grille vide. Aucun chiffre inventé (`HabitHeatmap.swift:89-94`).
- **Première utilisation** : intérêt « Bien-être » aux premières questions › « Une habitude à suivre » (ajout par le nom). Sinon le bloc « À remplir » de Planning. Il n'y a pas de tutoriel propre aux habitudes.
- **Erreurs** : pas de message d'erreur. « Enregistrer » est grisé sans nom (`HabitsView.swift:259`). Une habitude dont un champ est illisible est quand même lue (`Content.swift:150-161`).
- **Permission Notifications** : demandée seulement en activant « Rappel quotidien », après une feuille d'explication. En cas de refus, l'interrupteur se remet à zéro et le pied dit « Les notifications sont désactivées pour Ardane dans Réglages. » (`HabitsView.swift:224-228`, `:262-283`).
- **Mode gratuit** : 3 habitudes. Au-delà, le bouton d'ajout ouvre l'offre « Plus de 3 habitudes » : « La version gratuite suit 3 habitudes. Avec Premium, suis-en autant que tu veux, sur tes widgets aussi. ». Qui en a déjà plus les garde et peut les modifier. Section « Régularité » verrouillée : « La régularité est dans Premium » / « Le taux de réussite de chaque habitude sur 30 et 90 jours, et sa plus longue série. Tes jours cochés restent enregistrés. ». Tableau de l'offre : ligne « Habitudes » 3 / ∞ (`App/Premium/PaywallView.swift:209`).
- **Limites d'affichage** : 5 habitudes sur la carte, 3 ou 7 sur le widget « Habitudes », 6 sur « Semaine d'habitudes ». Historique gardé : 400 jours.
- **Jours** : on peut cocher n'importe quel jour passé. Jamais un jour futur (`MiniApp.swift:524`, `:534`).
- **À vérifier** : le texte de Créer › Écran verrouillé cite « cocher une habitude » parmi les gestes possibles sans déverrouiller (`App/Screens/Spaces/LockScreenCreator.swift:100`). Le seul widget d'habitude offert en écran verrouillé est « Série » en rond, une jauge sans bouton (`KindCatalog.swift:147`).

## 8. Problèmes d'UX constatés aujourd'hui

1. **Deux écrans pour la même chose, avec des fonctions différentes.** E1 (cartes) et E2 (liste). Supprimer par balayage, réordonner et le compteur « x sur 3 » ne sont que dans E2. La section « Régularité » n'est que dans E1. Preuve : `HabitsView.swift:41-53`, `:70-74` ; `PlanningPages.swift:364-394`.
2. **Depuis le chemin principal, on ne peut pas réordonner.** Or l'ordre décide des habitudes montrées : 5 sur la carte, 3 sur le widget (`DailySection.swift:1080` ; `ProductivityWidgets.swift:76`). Il faut passer par le Profil pour changer l'ordre.
3. **Deux libellés pour la même action.** « Nouvelle habitude » (`HabitsView.swift:64`) et « Ajouter une habitude » (`PlanningPages.swift:369`, `:389`). Deux états vides différents (section 7).
4. **Une nouvelle habitude ne démarre pas pareil selon l'entrée.** Depuis E2 : icône `figure.run`, couleur Jade (`HabitsView.swift:59`). Depuis E1 : icône `checkmark`, couleur Olive (`PlanningPages.swift:397`) ; cette icône n'est pas dans la grille des 20, donc aucune icône n'est sélectionnée. En ajout rapide : `checkmark.circle` (`DataItemViews.swift:147`).
5. **Trois verts pour « Habitudes ».** `7FA33A` sur E1 et l'espace, `5C8424` sur la carte de Mon quotidien (`DailySection.swift:1088`), Jade `2F8F7A` sur le sélecteur de jour de E2 (`HabitsView.swift:15`).
6. **Pas de résumé du jour sur la page.** Le « faites/total » existe sur la ligne de Planning (`PlanningApp.swift:115`), la carte (`DailySection.swift:1149-1157`) et le widget (`ProductivityWidgets.swift:88-92`), mais pas sur E1 ni E2.
7. **Faites et à faire sont mélangées.** La liste garde l'ordre de création. L'état n'est dit que par le rond plein ou vide ; aucun mot à l'écran (les mots n'existent que pour VoiceOver, `HabitsView.swift:114`). La maquette Cristal `docs/design/2026-11-15-cristal/07-habitudes.html` écrit « Faite » / « À faire » ; le code non.
8. **La série, le % et la grille ne suivent pas le jour choisi.** Ils sont calculés à aujourd'hui (`HabitsView.swift:96-98`). Seul le rond suit le sélecteur (`:95`).
9. **Deux gestes sur la même bande, sans indice.** Le rond coche ; le reste de la bande ouvre la fiche (`HabitsView.swift:101`, `:116`). Pas de chevron, pas de mot « Modifier ».
10. **Pas de vue de détail.** Toucher une habitude ouvre tout de suite le formulaire de modification. Ses chiffres (meilleure série, 90 jours) sont ailleurs, en bas de page, dans une liste à part (`PlanningPages.swift:404-425`).
11. **Cartes hautes.** Chaque carte porte une grille de 7 rangées sur 26 colonnes. Calcul sur un iPhone de 393 points de large : environ 171 points par carte. Avec 3 habitudes, la section « Régularité » est sous l'écran. À vérifier sur capture.
12. **Message Premium ambigu.** La carte verrou promet « Le taux de réussite de chaque habitude sur 30 et 90 jours » (`PlanningPages.swift:408-409`). Le % sur 30 jours est déjà affiché gratuitement sur chaque carte (`HabitsView.swift:131-136`).
13. **Valeur peu lisible.** « 80 % · 75 % » sans dire lequel est 30 jours et lequel 90 (`PlanningPages.swift:427-431`). L'explication est dans une note sous la carte (`:420`).
14. **Deux calculs proches sous deux noms.** « Régularité » = 30 jours glissants depuis le premier jour coché (`Content.swift:184-196`). « Taux de réussite » du widget = mois en cours depuis le 1er (`ProductivityTiles.swift:203-230`). Pour la même habitude, les deux % peuvent différer. Pareil pour « Meilleure série » (page) et « Record » (widget, 366 jours).
15. **Une notification n'ouvre pas la page où l'on coche.** Elle ouvre l'onglet Créer sur la page d'espace E8 (`SmartReminders.swift:145` ; `Router.swift:168-176`). Il faut encore toucher « Mes habitudes », puis le rond : 2 touchers de plus. Pareil pour 3 widgets sur 4.
16. **Trois destinations selon l'entrée.** Carte de Mon quotidien : E1. Widget « Habitudes » : E2 en feuille. Notifications et autres widgets : E8 dans Créer.
17. **La carte vide de Mon quotidien ouvre Planning, pas Habitudes** (`DailyBrief.swift:244-245`). L'habitude s'y ajoute par son nom seul, dans le bloc « À remplir ».
18. **Dans Planning, la ligne « Habitudes » est la dernière de la page.** Après le calendrier, « Importer mon horaire », « Top 3 du jour », « Tâches » et « Projets » (`PlanningApp.swift:44-121`).
19. **On ne peut pas cocher depuis Mon quotidien.** La carte entière est un lien (`DailySection.swift:1088`). La carte « Top 3 » voisine se coche sur place (`DailySection.swift:1371-1393`). Le widget d'écran d'accueil aussi (`ProductivityWidgets.swift:185`).
20. **« Série de N jours » sur la carte ne dit pas de quelle habitude.** C'est la plus longue de toutes (`DailySection.swift:1083`, `:1159-1164`).
21. **« Rappels d'habitudes » ouvre la liste des habitudes, pas des rappels** (`ProfileView.swift:127`). Le rappel se règle habitude par habitude. La même liste est aussi sous « Tes données » › « Habitudes » (`:141`) : deux lignes du Profil pour un même écran.
22. **Le rappel quotidien sonne même si l'habitude est déjà cochée.** Notification répétée à heure fixe, sans condition ; cocher ne l'annule pas (`NotificationScheduler.swift:30-42` ; seuls l'enregistrement, la suppression et la restauration y touchent : `HabitsView.swift:43`, `:242`, `:311` ; `AppModel.swift:707-708`).
23. **Titre trompeur sur la page d'espace.** La section « Ce mois-ci » affiche la série en cours de chaque habitude, pas un chiffre du mois (`ProductivitySpace.swift:364-368`).
24. **Suppression sans confirmation par balayage** (`HabitsView.swift:41-45`), alors que la fiche demande « Supprimer l'habitude ? » (`:240-248`).
25. **La limite gratuite ne se voit pas sur l'écran principal.** Pas de « x sur 3 » sur E1 ; l'offre s'ouvre au toucher du bouton (`PlanningPages.swift:357-359`).
26. **Un cadre différent des mini-apps.** E1 utilise `DaySwitcher` (un jour à la fois) et `MiniAppScroll` (`PlanningPages.swift:364-366`). Les écrans principaux des mini-apps utilisent `WeekSelector` et `MiniAppScaffold` (`PlanningApp.swift:33-42` ; `docs/memoire/Chantiers.md:118`). Pas de bandeau, pas d'action flottante, pas de « Mes paramètres ».

## 9. Ce que la mission du PDG cite et qui n'existe pas

La mission (`MISSION.md`, partie E et § 8) cite 9 sujets pour Habitudes. État de chacun :

| Cité par le PDG | État dans le code |
|---|---|
| Habitudes quotidiennes | **Existe.** Toutes les habitudes sont quotidiennes. |
| Séries et régularité | **Existe.** Série en cours et % sur 30 jours gratuits ; 90 jours et meilleure série en Premium. |
| Création et modification des habitudes | **Existe** (fiche E3, ajout rapide). |
| Suivi de progression | **En partie.** « faites/total » du jour hors de la page, % par habitude, grille. Pas de progression globale sur la page. |
| Calendrier de suivi | **En partie.** La grille de semaines en tient lieu, sans dates. Le mois en calendrier n'existe que dans le widget « Série » moyen. |
| Historique | **En partie.** On remonte jour par jour avec le sélecteur ; la grille montre 26 semaines. Pas de page ni de liste. |
| Statistiques | **En partie.** Section « Régularité » (Premium). Le taux du mois et la grille de la semaine n'existent que dans des widgets Premium. |
| Habitudes hebdomadaires | **N'existe pas.** |
| Objectifs | **N'existe pas.** |

Ce qui n'existe pas, à dessiner comme « nouveau » :

1. **Une mini-app « Habitudes » à part.** Pas de cas dans `enum MiniApp` (`MiniApp.swift:6`), pas d'écran d'accueil propre, pas de cadre commun, pas de « Mes paramètres ».
2. **Habitudes hebdomadaires.** Aucune fréquence ni jour de la semaine dans `Habit` (`Content.swift:128-136`). Le moteur de notifications a une logique « jours prévus » prête mais jamais alimentée (`NotificationEngine.swift:164-171`).
3. **Objectifs.** Aucun objectif par habitude ni global : pas de cible par semaine, de quantité, de durée, de série visée.
4. **Calendrier mensuel de suivi dans l'app.**
5. **Historique en page ou en liste.**
6. **Statistiques globales et graphiques** dans l'app : pas de courbe, pas de taux global, pas de tendance, pas de chiffres par jour de la semaine.
7. **Progression globale du jour sur la page** (« x sur y », anneau ou barre).
8. **Séparation « réalisées » / « à accomplir »** (phrase du PDG, partie E) : pas de tri ni de groupes.
9. **Format « Medium » de la carte de Mon quotidien** (§ 8 de la mission) : il n'existe que demi-largeur et pleine largeur ; la carte Habitudes est en pleine largeur par défaut.

## 10. Captures CI disponibles

**Aucune image dans `origin/ci-report` aujourd'hui.** La branche est refaite à chaque run. Son seul commit (`170618c`, « Build 455 », 2026-11-17) contient 918 fichiers, tous en `.txt` (rapports de tests) : 0 `.png`, 0 `.jpg`. Référence locale à jour (comparée avec `git ls-remote`).

Noms que la CI produit pour ce sujet quand un run avec captures est lancé (à redemander avant de dessiner) :

| Nom attendu | Ce que c'est | Source |
|---|---|---|
| `app-planning-habits-light.jpg` | Page « Habitudes » (E1), haut | `.github/workflows/build.yml:442` ; clé `planning-habits` (`App/Core/ScreenshotMode.swift:197`) |
| `app-planning-end-light.jpg` | Bas de Planning : lignes « Projets » et « Habitudes » | `build.yml:445` |
| `tests/mini-app-planning-habits.png` | E1 ouverte depuis Planning | `UITests/MiniAppUITests.swift:245-249` |
| `tests/mini-app-planning-projects-habits.png` | Les lignes « Projets » et « Habitudes » | `UITests/MiniAppUITests.swift:263` |
| `tests/profile-daily-habits-wide.png` | Carte « Habitudes » de Mon quotidien en pleine largeur | `UITests/HomeLayoutUITests.swift:96` |
| `adkit-en/shots/hab-0.png`, `hab-1.png` (et versions sombres, à vérifier) | E1 en anglais, avant et après une coche | `UITests/AdShotsUITests.swift:265-289` ; `build.yml:765-766` |

Images déjà dans le dépôt, utiles en référence : `docs/references/habitudes-0-widget-actuel.jpg`, `docs/references/habitudes-1-grille-style-cible.jpg`. Maquette Cristal déjà faite (une maquette, pas l'app) : `docs/design/2026-11-15-cristal/07-habitudes.html`.

## 11. Contraintes pour la conception

1. **Ne perdre aucune des 28 fonctions** de la section 4. En particulier celles qui ne sont que dans E2 : réordonner (F11), supprimer par balayage (F10), compteur de la limite (F14).
2. **Dire clairement ce qui est nouveau.** Hebdomadaire, objectifs, calendrier mensuel, historique, statistiques globales, mini-app à part : rien de cela n'existe. Les dessiner avec la mention « nouveau » (règle du PDG, `MISSION.md` § 9 ; consigne du 2026-11-15, `docs/memoire/Chantiers.md:268`).
3. **Ne pas changer le format de `Habit`** ni les calculs de la section 5 (série, meilleure série, régularité, grille, 400 jours, paliers). Une fréquence ou un objectif demanderait de nouveaux champs : c'est du développement, pas de l'habillage.
4. **Aucun chiffre inventé.** Pas de % avant le premier jour coché ; pas de données d'exemple dans la vraie app.
5. **Gratuit / Premium inchangé.** 3 habitudes gratuites, seul l'ajout est bloqué. Le % sur 30 jours reste gratuit ; 90 jours et meilleure série restent Premium (`docs/memoire/Decisions.md:27`, `:127`). Rien de ce que la personne a saisi n'est jamais verrouillé.
6. **Une seule source de données**, partagée avec les widgets. Toute coche passe par `toggleHabit` ; tout ajout par `addHabit`.
7. **L'ordre des habitudes compte** : il décide de ce que montrent la carte (5), le widget (3 ou 7) et « Semaine d'habitudes » (6).
8. **La couleur appartient à chaque habitude** (8 couleurs gratuites), traduite par la palette Cristal (`style.cristal.category` et `strong`). Référence visuelle : Cristal « Équilibré ».
9. **Carte de Mon quotidien** : identifiant `habits`, 4e par défaut, présente pour tous, deux largeurs (demi, pleine), retirable et déplaçable. Sa version demi-largeur et sa version pleine largeur doivent exister toutes les deux. Les mêmes codes (anneau du jour, petits carrés) servent au widget : les garder cohérents.
10. **Jours** : on doit pouvoir cocher un jour passé oublié ; jamais un jour futur.
11. **Notifications** : la permission n'est demandée qu'au moment d'activer un rappel, après une explication ; un refus ne bloque rien.
12. **Accessibilité** : zones de toucher de 44 points ; libellés VoiceOver « Valider <nom> », « Marquer <nom> comme non fait », « Régularité : x % » ; grandes tailles de texte.
13. **Sept langues** (français, anglais, espagnol, allemand, italien, portugais du Brésil, japonais) : prévoir des libellés longs.
14. **Repères utilisés par les tests et les captures, à garder** : `planning-habits`, `daily-habits`, `habits-regularity`, `day-switcher`, `premium-lock`, `data-new-habit`, `first-habit`, `mini-to-fill-habits` ; la scène pub `testAdHabits` cherche le sélecteur de jour puis les ronds à gauche, sous lui (`UITests/AdShotsUITests.swift:265-289`).
15. **Chemins à garder ouverts** : `MiniAppPage.planningHabits`, `ContentScreen.habits`, `tessera://habits`, `tessera://space/habits` (des widgets déjà posés et des notifications déjà planifiées les utilisent).
16. **Si Habitudes devient une vraie mini-app** (c'est un choix nouveau, à faire valider) : points du code touchés plus tard, pour mémoire : `enum MiniApp`, `InfoArea.miniApp` (`DailySection.swift:22`), `DailyCategories.cardIDs` (`DailyCategories.swift:16`), `MiniApp.toFillItems` (`MiniAppToFill.swift:12`), `Router.handle` pour l'espace « habits », la route de la carte vide.
17. **Hors mission, à corriger un jour** : `scripts/graph_map.py:39` et `:283` disent encore « 5 habitudes » ; le code dit 3.

## Relecture

- Ajouté : F28 (widget « Hydratation » rangé dans la catégorie « Habitudes » de Créer, `KindCatalog.swift:146`) ; chemin du paywall depuis « Enregistrer » de E3 (`HabitsView.swift:307`) ; la ligne de l'accueil des mini-apps montre Planning dès qu'il y a une habitude (`MiniAppsRow.swift:38`).
- Corrigé : compte des fonctions, 27 devient 28 (Premium inchangé : 5). Une quinzaine d'affirmations vérifiées (écrans, routes, limite 3, rappel, liens profonds, palette, widgets Premium) : toutes justes. `scripts/graph_map.py:39` dit bien « 5 habitudes » : déjà noté en 11.17.
- Incertain : captures CI absentes (aucune image) ; hauteur des cartes (point 11) ; texte « cocher une habitude » de l'écran verrouillé (7) ; versions sombres des captures pub.
