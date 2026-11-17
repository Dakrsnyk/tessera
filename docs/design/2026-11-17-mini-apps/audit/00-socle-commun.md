# Audit : Socle commun (Mon quotidien, cadre des mini-apps, style Cristal)

Relevé dans le code le 2026-11-17 (branche `main`, commit `19f6eb1`). Lecture seule. Chaque fait porte sa preuve (`fichier:ligne`). Ce fichier ne décrit pas une mini-app : il décrit ce que toutes partagent.

## 1. En bref

- Le socle, c'est trois choses : l'Accueil « Mon Quotidien » (la porte de toutes les mini-apps), le cadre commun d'un écran de mini-app (`MiniAppScaffold`) et le style Cristal « Équilibrée ».
- Pour qui : tout le monde, à chaque ouverture de l'app. Mon Quotidien est le premier écran (`App/Screens/Home/HomeView.swift:7`).
- Le code compte **9 mini-apps** (`enum MiniApp`, `App/Screens/MiniApps/MiniApp.swift:5-6`), donc **8 hors Finance**. « Habitudes » n'en est pas une : c'est une page de Planning.
- État : en place et testé (run 454, 1 637 tests réussis, `docs/memoire/Chantiers.md:362`). Ordre de Mon Quotidien refait le 2026-11-17 (`App/Core/DailyDefaults.swift:11-14`).
- Le cadre est commun, mais chaque mini-app l'emploie à sa façon : 27 écarts relevés (section 8).

## 2. Liste exacte des mini-apps et de ce qui n'en est pas

### 2.1 Les 9 cas de `enum MiniApp` (`App/Screens/MiniApps/MiniApp.swift:5-6`)

| # | Cas | Titre affiché (`:9-21`) | Symbole (`:23-35`) | Couleur (`:37-49`) | Espace de Créer (`:54-66`) | Vue principale | Pages (`MiniAppPage`, `:80-131`) | Dans la mission |
|---|---|---|---|---|---|---|---|---|
| 1 | `nutrition` | « Nutrition » | `fork.knife` | `F08A24` | `nutrition` | `NutritionAppView`, `Nutrition/NutritionApp.swift:24` | 6 | Oui (A) |
| 2 | `fitness` | « Fitness » | `dumbbell.fill` | `E5484D` | `fitness` | `FitnessAppView`, `Fitness/FitnessApp.swift:9` | 8 | Oui (B) |
| 3 | `planning` | « Planning » | `calendar` | `3366FF` | `productivity` | `PlanningAppView`, `Planning/PlanningApp.swift:9` | 6 (dont `planningHabits`) | Oui (C) |
| 4 | `studies` | « Études » | `graduationcap.fill` | `D6409F` | `student` | `StudiesAppView`, `Studies/StudiesApp.swift:83` | 8 | Oui (D) |
| 5 | `finances` | « Finances » | `creditcard.fill` | `2F8F7A` | `budget` | `FinancesAppView` | 7 | **Non : exclue** |
| 6 | `business` | « Business » | `briefcase.fill` | `8C6CFF` | `business` | `BusinessAppView`, `Business/BusinessApp.swift:111` | 4 | Oui (F, « autres ») |
| 7 | `travel` | « Voyage » | `airplane` | `12A4B5` | `travel` | `TravelAppView`, `Travel/TravelApp.swift:49` | 3 | Oui (F) |
| 8 | `car` | « Auto » | `car.fill` | `6B7280` | `car` | `CarAppView`, `Car/CarApp.swift:64` | 5 | Oui (F) |
| 9 | `photos` | « Photos et citations » | `photo.on.rectangle.angled` | `D9608B` | aucun | `PhotoQuotesAppView`, `Photos/PhotoQuotesApp.swift:9` | 0 | Oui (F) |

- Total des pages : 47 cas dans `MiniAppPage`, dont 40 hors Finance.
- Le choix de la vue se fait dans `MiniAppView` (`MiniApp.swift:134-165`) et `MiniAppPageView` (`:167-226`). Chaque ouverture est comptée (`MiniAppUsage.record`, `MiniApp.swift:139`).
- `isBuilt` vaut toujours vrai (`MiniApp.swift:69`) : toutes sont construites.

**Vraies mini-apps hors Finance : 8.** Nutrition, Fitness, Planning, Études, Business, Voyage, Auto, Photos et citations.

### 2.2 Ce qui ressemble à une mini-app sans en être une

| Élément | Ce que c'est vraiment | Preuve |
|---|---|---|
| **Habitudes** | Une **page de Planning** (`MiniAppPage.planningHabits`, vue `PlanningHabitsPage`). Aussi : un espace de Créer (`Space.habits`), une zone de « Mes informations » (`InfoArea.habits`), une carte de Mon Quotidien, une feuille `HabitsView` (lien `tessera://habits`). Pas de cas dans `enum MiniApp`. | `MiniApp.swift:99` ; `Planning/PlanningPages.swift:346` ; `Shared/Model/KindCatalog.swift:6` ; `App/Screens/Home/DailySection.swift:22` ; `App/ArdaneApp.swift:331` |
| **Top 3** (« Productivité ») | Une carte de Mon Quotidien et un espace de Créer (`Space.productivity`). Ses données sont dans Planning. | `DailySection.swift:1371` ; `MiniApp.swift:58` |
| **À ne pas oublier** (rappels) | Une carte seulement. Elle réunit des échéances de 5 mini-apps. | `DailySection.swift:1292` ; `App/Core/DailyBrief.swift:550-593` |
| **Pas** | Une carte. Sa page est dans Fitness (`fitnessActivity`). | `DailySection.swift:1218` ; `MiniApp.swift:94` |
| **Budget** | La carte de la mini-app Finances (hors mission). | `DailySection.swift:1250` |
| **Placements**, **Sociétés cotées**, **Ma vie** | Des espaces de Créer (widgets) et des zones de « Mes informations ». Aucune mini-app. | `DailySection.swift:28` ; `KindCatalog.swift:6` |
| **Heure et date** | Une catégorie de Créer, sans mini-app. | `App/Screens/Spaces/CreateFlow.swift:40` |
| **Mes informations** | Une page de l'Accueil (`MyInfoView`), pas une mini-app. | `App/Screens/Home/MyInfoCenter.swift:151` |
| **« Mes mini-apps »** (rangée de puces, feuille « Mini-apps ») | Code présent, **jamais affiché** : `MiniAppsRow` n'est appelé nulle part. | `App/Screens/Home/MiniAppsRow.swift:137`, `:205` ; `HomeView.swift:80-93` ; `scripts/graph_map.py:89` |

### 2.3 Anciennes mini-apps retirées (à ne pas redessiner)

| Mini-app | Retirée le | Preuve |
|---|---|---|
| **Eau** (hydratation chiffrée) | 2026-10-15 | `docs/memoire/Decisions.md:13` ; `Shared/Model/WidgetKind.swift:145` (`retired = [.hydration]`) ; `App/Core/AppModel.swift:813` ; un ancien lien `tessera://hydration` ouvre l'Accueil (`App/Core/Router.swift:163`) |
| **Météo** | 2026-10-26 | `docs/memoire/Demandes.md:312-315` ; `Shared/Model/LossyList.swift:4`. Plus aucun écran. Le mot « Météo » ne reste que comme fausse icône d'app dans les aperçus (`App/Screens/Editor/HomeScreenPreview.swift:35`). |

## 3. Mon quotidien : chaque carte, sa taille, son contenu, sa destination

### 3.1 L'Accueil, de haut en bas (`HomeView.swift:80-93`)

1. **Capsule de verre** : la date du jour, et l'avatar qui ouvre « Profil et réglages » (`HomeView.swift:55-78`).
2. **Mon Quotidien** (`DailySection`, `DailySection.swift:57`) :
   - étiquette « MON QUOTIDIEN » et grand titre selon l'heure : « Ta matinée » (5 h à 11 h), « Ta journée » (11 h à 18 h), « Ta soirée » (`DailyBrief.swift:9-27`, `DailySection.swift:102-112`) ;
   - sans Premium : signe doré « Premium » à droite du titre, qui ouvre l'offre (`DailySection.swift:114-117`, `:1794-1823`) ;
   - si rien n'est saisi : carte « Complète tes informations pour personnaliser ton Mon Quotidien. » et bouton « Ajouter mes informations » (`:131-133`, `:332-353`) ;
   - la grille des cartes (`:134-148`) ;
   - un « + » en bas tant qu'il manque une catégorie (`:150-152`).
3. **« Mes informations »** : anneau de complétude, pastilles par domaine, « Tout voir » (`MyInfoCenter.swift:4-66`).
4. **Bandeau « Ardane Premium »**, sans Premium seulement (`HomeView.swift:90-92`, `:171-199`).

### 3.2 Écrans et feuilles de Mon Quotidien

| N° | Écran ou feuille | Vue, fichier:ligne | Comment on y arrive | Ce qu'on y fait |
|---|---|---|---|---|
| E1 | Accueil « Mon Quotidien » | `HomeView`, `HomeView.swift:7` ; `DailySection`, `DailySection.swift:57` | Onglet « Accueil » (`App/ArdaneApp.swift:303`) | Lire le jour, agir sur une carte, ouvrir une mini-app |
| E2 | Mode « Organiser » | `DailyEditableCard`, `DailyEditMode.swift:78` | Appui long sur une carte, puis « Organiser… » (`DailyEditMode.swift:216-234`) | Déplacer, agrandir (+), rétrécir (−), retirer (croix), « OK ». Détail : texte d'aide « Maintiens une carte puis glisse-la… » (`DailySection.swift:125`) ; poignée à trois traits en haut à droite, croix en haut à gauche, un seul bouton « + » (carte demi) ou « − » (carte large) en bas (`DailyEditMode.swift:131-186`) ; maintenir une demi-seconde puis glisser ; les cartes tremblent (sauf « Réduire les animations ») ; un appui dans une zone vide termine (`DailySection.swift:156-161`). Toutes les cartes acceptent les deux tailles et se déplacent ; seul le type « invitation » (`InviteDayTile`, `DailySection.swift:1468`) ferait exception, mais `DailyBrief.completing` le retire de l'Accueil (`DailyBrief.swift:386`) : code qui ne s'affiche plus (`DailyLayoutRules.swift:12-16`, `:43-46`) |
| E3 | Feuille « Mon Quotidien » | `DailyLayoutEditor`, `DailyLayoutEditor.swift:6` | Bouton à curseurs du mode Organiser (`DailySection.swift:174-184`) | Ordre, taille « ½ » ou « Large », masquer, « Catégories », « Disposition automatique ». Les interrupteurs « Catégories » sont **par mini-app** : les 8 sauf Photos (Finances comprise) plus « Productivité » (`DailyLayoutEditor.swift:54-78`, `DailyCategories.swift:9`). Fitness pilote la carte Séance ; Planning pilote Planning, Habitudes et « À ne pas oublier » (et Top 3 tant que « Productivité » n'est pas ajoutée) (`DailyCategories.swift:12-20`, `:155-175`). **Aucun interrupteur pour la carte Pas** : elle se règle par l'œil (ligne de la liste), la croix ou le « + » du bas. Le bouton « Disposition automatique » est grisé quand l'ordre et les tailles sont déjà automatiques (`DailyLayoutEditor.swift:24-26`, `:92`). Dans cette feuille la carte Séance s'appelle « Séance du jour » (`:152`) |
| E4 | Feuille « Ajouter une catégorie » | `AddCategorySheet`, `DailySection.swift:1609` | Le « + » du bas (`:1585-1605`) | Ajouter une carte ; « Fermer » |
| E5 | Page « Mes tâches réalisées » | `CompletedPrioritiesView`, `App/Screens/Spaces/ProductivitySpace.swift:168` | Lien de la carte Top 3 (`DailySection.swift:1419-1439`) | Revoir les tâches terminées |
| E6 | Page « Mes informations » | `MyInfoView`, `MyInfoCenter.swift:151` | « Tout voir » ou l'anneau (`MyInfoCenter.swift:17`, `:28`) | Anneau « n/total » et « Tout est renseigné » ou « N informations à compléter », bouton « Mes centres d'intérêt » (`:165-176`) ; listes « Tes thèmes », « Autres catégories » (ou « Catégories »), puis « Général » (anniversaire et calendrier, saisis sur place, `DataItems.swift:76-77`, `MyInfoCenter.swift:182`). Chaque ligne affiche un résumé (3 au plus, ou « Rien de renseigné ») et une pastille du nombre d'infos à compléter (`:219-260`). Une ligne ouvre sa mini-app ; Habitudes et Productivité ouvrent Planning (`DailySection.swift:18-28`) ; **Placements, Sociétés cotées et Ma vie ouvrent l'écran E15** |
| E15 | Écran de données d'un espace sans mini-app (`SpaceView`, `isEmbedded: true`) | `SpaceView`, `App/Screens/Spaces/SpaceView.swift:5`, `:73-85` ; vue `HomeView.swift:26-32` | Ligne « Placements », « Sociétés cotées » ou « Ma vie » de E6 (`DailySection.swift:28`, `:36`) | Liste de données, sans bandeau de widgets. **Placements** : valeur et gain du portefeuille, ligne par position (touche = feuille `HoldingEditor`, glisser = supprimer), « Ajouter un placement », mention « Ardane ne donne aucun conseil d'investissement » (`MoneySpaces.swift:5-60`). **Sociétés cotées** (« Entreprises suivies ») : liste (déplacer, supprimer), détail `CompanyDetailView`, recherche « Nom ou symbole » et « Chercher » (`MoneySpaces.swift:325-380`). **Ma vie** : « Afficher mon anniversaire », date, âge, prochain anniversaire, « Jours fériés » par région, « Lune » (`TravelCarLifeSpaces.swift:510-560`). Aucun test Premium relevé dans ces vues |
| E7 | Feuille des centres d'intérêt | `InterestsEditorSheet`, `App/Screens/Profile/ProfileTopics.swift:778` | « Choisir mes centres d'intérêt » (`MyInfoCenter.swift:92-93`) ou « Mes centres d'intérêt » (`:173`) | Choisir ses intérêts |
| E8 | Feuille d'explication d'une permission | `PermissionExplainerView`, `App/Components/PermissionExplainer.swift:161` | « Relier le calendrier Apple » sur la carte Planning (`DailySection.swift:1029-1046`) | « Continuer » ou « Plus tard » ; refusé : « Ouvrir Réglages » |

Menus (non comptés comme écrans) :
- M1. Menu d'une carte : « Organiser… », « Retirer de Mon Quotidien » (`DailyEditMode.swift:222-229`).
- M2. Menu de la séance faite aujourd'hui : « Supprimer la séance », puis les deux entrées de M1 (`DailySection.swift:785-806`), avec confirmation (`Fitness/FitnessPages.swift:516`).

Routes de la pile de l'Accueil (`HomeRoute`) : `.space`, `.info`, `.infoArea` (vieux liens seulement : ouvre la mini-app, l'espace ou « Mes informations »), `.app`, `.page` (`HomeView.swift:24-46`). Écran vide d'Études : tant qu'il n'y a ni cours, ni examen, ni devoir, l'en-tête montre une carte de départ au lieu de `NextClassCard` (`StudiesApp.swift:98-99`).

Sorties vers d'autres parties (non comptées) : scanner d'aliments (`router.isFoodScanPresented`, `DailySection.swift:621`, `:726`), offre Premium, Profil.

### 3.3 Les 12 catégories de cartes (`DailyBrief.Category`, `DailyBrief.swift:113-114`)

Ordre par défaut, fixe pour tous (`DailyDefaults.swift:11-14`) : Nutrition, Séance, Planning, Habitudes, Top 3, puis Études, Budget, À ne pas oublier, Pas, Business, Voyage, Auto.

| # | Catégorie (id) | Pour tous, même vide ? (`DailyDefaults.swift:17`) | Largeur par défaut (`DailyDefaults.swift:21`, `DailyBrief.swift:297-305`) | Vues à balayer | Où elle mène |
|---|---|---|---|---|---|
| 1 | Nutrition (`nutrition`) | Oui | Large | 3 : « Aujourd'hui », « Repas », « 7 jours » (`DailySection.swift:424`) | Nutrition ; la vue « 7 jours » ouvre l'Historique (`:1720`) |
| 2 | Séance (`workout`) | Oui | Large | 2 : « Séance », « Semaine » (`:432`) | Fitness (`.space(.fitness)`, `:824`) |
| 3 | Planning (`planning`) | Oui, toujours le tableau (`DailyCategories.swift:63-72`) | Large | 1 | Planning (`:984`) |
| 4 | Habitudes (`habits`) | Oui | Large | 1 | Page Habitudes (`.page(.planningHabits)`, `:1088`) |
| 5 | Top 3 (`priorities`) | Oui | Large | 1 | Pas de lien sur toute la carte ; chevron vers Planning (`:1443`) |
| 6 | Études (`app-studies`) | Si intérêt « Études » ou s'il y a des cours (`DailyCategories.swift:102`) | Demi | 1 | Études |
| 7 | Budget (`budget`) | Si intérêt, ajout ou données | Demi | 1 | Finances (`.space(.budget)`, `:1250`) |
| 8 | À ne pas oublier (`reminders`) | S'il y a une échéance, ou si ajoutée | Demi | 1 | Chaque ligne ouvre sa page (`:1295-1297`) |
| 9 | Pas (`steps`) | Si le compteur de pas est autorisé (`:85`), ou si ajoutée | Demi | 2 : « Aujourd'hui », « 7 jours » (`:438`) | Page Activité de Fitness (`:1218`) |
| 10 | Business (`app-business`) | Si intérêt, ajout ou données | Demi | 1 | Business |
| 11 | Voyage (`app-travel`) | Idem | Demi | 1 | Voyage |
| 12 | Auto (`app-car`) | Idem | Demi | 1 | Auto |

« Photos et citations » n'a pas de carte (`DailyCategories.swift:9` ; `DailyBrief.swift:165`).

### 3.4 Ce que chaque carte affiche

**1. Nutrition** (`NutritionDayTile`, `DailySection.swift:575-781`). Visible avec des données dès qu'un objectif est donné ou qu'un aliment est noté aujourd'hui (`DailyBrief.swift:452-459`).
- Vue « Aujourd'hui », large (`:675-760`) : anneau de 90 points avec les « kcal restantes » (ou « kcal en trop », ou « kcal mangées » sans objectif) ; « Objectif à définir » sans objectif ; trois lignes « Protéines », « Glucides », « Lipides » (mangé / cible en g, barre) ; bouton « Scanner » (ouvre le scanner) ; « Rien noté » ou « N repas » ; « Prochain repas : …, environ N kcal ».
- Vue « Aujourd'hui », demi-largeur (`:587-650`) : anneau de 46 points, le chiffre, trois macros serrées, bouton rond du scanner, texte des repas.
- Vue « Repas du jour » (`:1662-1711`) : les repas avec leurs kcal ou « — », puis « Total » mangé / objectif.
- Vue « Calories · 7 jours » (`:1713-1728`) : 7 barres, trait de l'objectif, « Moyenne : N kcal par jour noté » ou « Rien noté cette semaine ».
- Vide : « Donne ton objectif calorique ou scanne un repas : tes calories du jour apparaîtront ici. » (`DailyBrief.swift:228`).

**2. Séance** (`WorkoutDayTile`, `:808-953`). Visible dès qu'un programme existe (`DailyBrief.swift:480`). Titre de la carte : « Séance », « Séance du jour » ou « Sport » selon l'état (`:913-919`).
- Prévue : « Séance du jour », le nom, « N exercices · N séries », bouton « Commencer » (démarre sur place, `:839-843`).
- En cours : « Séance en cours », l'exercice, « Série x/y · reps × charge », le repos qui décompte avec pause et reprise, bouton « Série faite » (`:844-868`).
- Faite : le nom, « Faite · N séries », « N kg soulevés » (`:869-880`). Appui long : « Supprimer la séance ».
- Repos : « Repos aujourd'hui », puis le jour et le nom de la prochaine (`:881-890`).
- Étiquette « Maintenant » : séance en cours, ou prévue à partir de 11 h (`:900-911`).
- Vue « Cette semaine » (`:1730-1766`) : « N/objectif séances », 7 points, « Objectif de la semaine atteint » ou « Encore N séances ».
- Vide : « Crée ton programme : ta séance du jour apparaîtra ici. » (`DailyBrief.swift:229`).

**3. Planning** (`PlanningDayTile`, `:959-1068`). Toujours là, même vide.
- Large : le tableau de la semaine (`WeekTimetable`, 22 points par heure, blocs avec texte) ; « Rien de prévu cette semaine. » au-dessus si vide ; « Toute la semaine › » (`:1015-1021`, `:1054-1061`).
- Demi-largeur : le même tableau en petit, blocs sans texte ; vide : le texte seul (`:1008-1013`).
- Contenu du tableau : cours, travail, rendez-vous, examens, devoirs, tâches, échéances, séances, calendrier Apple (`App/Core/Agenda.swift:6-8`, `:103`).
- Calendrier non relié : bouton « Relier le calendrier Apple » (`:972-982`, `:1038`).
- On ne crée rien depuis la carte : la toucher ouvre Planning (`:984`).

**4. Habitudes** (`HabitsDayTile`, `:1070-1210`). Visible dès qu'une habitude existe.
- Large : « faites/total », « Série de N jours », puis une ligne par habitude (5 au plus, puis « +N ») : anneau du jour, nom, derniers jours en petits carrés (`:1115-1129`, `:1174-1201`).
- Demi-largeur : un anneau par habitude, le compte, « faites aujourd'hui », la série ou les noms (`:1089-1114`).
- On ne coche pas depuis la carte : toute la carte est un lien (`:1088`).
- Vide : « Ajoute une habitude à suivre chaque jour. » (`DailyBrief.swift:233`).

**5. Top 3** (`PrioritiesDayTile`, `:1360-1465`). 3 tâches au plus (`Shared/Domains/Productivity.swift:194`).
- Chaque tâche se coche sur place (`:1374-1378`).
- Champ « Ajouter une tâche » : seulement si « Productivité » a été ajoutée et s'il reste de la place (`:1366-1367`, `:1403-1418`).
- « Mes tâches réalisées » (page E5) et un chevron vers Planning (`:1419-1451`). Quand le champ d'ajout est là, « Mes tâches réalisées » se réduit à une icône (`:1422-1427`). Quand les 3 places sont prises, le champ disparaît.
- Vide : carte nommée « Productivité », « Ajoute tes tâches ou ton top 3 du jour. » (`DailyBrief.swift:234`).

**6. Études, 10. Business, 11. Voyage, 12. Auto** : carte « un chiffre » (`DailySection.swift:448-457`). Nom, icône et couleur de la mini-app, puis une ligne tirée des données (`MiniAppSummary.caption`, `MiniAppsRow.swift:64-111`) :
- Études : prochain examen dans 14 jours « titre · compte à rebours », sinon « N devoirs à rendre », sinon le prochain cours, sinon « N cours » (`:81-92`).
- Business : « X $ ce mois » (`:97-99`).
- Voyage : « destination · jour N » ou « destination · J-N » (`:100-103`).
- Auto : « ≈ N km d'autonomie », sinon « N km » (`:104-106`).
- Sans donnée : carte d'invitation (texte de `DailyBrief.swift:231`, `:237-239`).

**7. Budget** (`BudgetDayTile`, `:1242-1284`). Visible si le budget du mois est connu ou s'il y a une dépense aujourd'hui (`DailyBrief.swift:361-365`). Montant « à dépenser par jour d'ici la fin du mois », « Dépensé aujourd'hui : X », courbe des 7 derniers jours s'il y a eu des dépenses.

**8. À ne pas oublier** (`RemindersDayTile`, `:1286-1358`). 4 lignes au plus en tout : jusqu'à 4 échéances ; la ligne « N tâches à faire » (avec les 2 premiers titres) ne s'ajoute que s'il reste de la place, donc jamais en 5e (`DailyBrief.swift:586-591`, condition `result.count < 4`). Pas de pastille de vue ni de bouton : seule chaque ligne est un lien (`DailySection.swift:1294-1300`). Sources : examens (demain au plus), devoirs (3 jours), échéances de Planning (2 jours), factures (3 jours), échéances auto (7 jours), départ en voyage (3 jours) (`DailyBrief.swift:568-585`). « En retard » s'écrit en rouge (`:1326`, `:1350`).

**9. Pas** (`StepsDayTile`, `:1212-1240`). Nombre de pas, « / objectif », barre ; « Objectif à définir » sans objectif. Vue « Pas · 7 jours » : barres et « Moyenne : N pas » (`:1768-1790`).

### 3.5 Règles d'affichage à connaître

- **Deux largeurs seulement** : demi ou toute la largeur (`DailyLayoutRules.swift:8-10`). « Moyen » et « Grand » ont la même largeur ; seule la hauteur du contenu change (`DailyDefaults.swift:19-20`).
- Deux cartes en demi-largeur se rangent côte à côte. Une demi-carte seule sur sa ligne prend toute la largeur avec son contenu « large » (`DailyEditMode.swift:64-66` ; `DailySection.swift:136`, `:143`).
- 12 points entre les cartes (`DailyEditMode.swift:35`). Marge d'écran 20 (`HomeView.swift:94`).
- Une carte vide a la même largeur que la carte remplie (`DailyBrief.swift:302`). Jamais de faux chiffre.
- Ce que la personne a rangé passe avant l'ordre par défaut : `dailyOrder`, `dailyWide`, `dailyHidden`, `dailyAdded`, `dailyCardPages` (`Shared/Model/Settings.swift:104-116`).
- La vue choisie sur une carte à plusieurs vues est gardée (`DailyPager.swift:58`, `:108-112`).
- Les scores par moment de la journée existent encore (`DailyBrief.swift:310-377`) mais l'ordre affiché est l'ordre fixe (`DailyCategories.swift:56`).

## 4. Cadre commun des mini-apps (MiniAppScaffold et composants)

### 4.1 L'écran principal d'une mini-app (`MiniAppScaffold`, `App/Screens/MiniApps/MiniAppScaffold.swift:30-95`)

De haut en bas :
1. **Barre de navigation** : retour, titre en petit, fond caché (`:75-76`).
2. **Nappe de couleur** : la couleur de la mini-app en dégradé rond, 30 % en clair, 22 % en sombre, éteinte à 380 points (`:80-94`).
3. **En-tête** (`header`), marges de 20, 12 entre les blocs (`:48-55`) : en général le sélecteur de semaine, puis la figure du jour sur verre.
4. **Feuille** (`sheet`), 22 entre les blocs (`:56-62`) : « À remplir », les actions, les sections par ordre d'importance, la note, puis « Mes paramètres » en dernier.
5. **Action flottante** au-dessus de la barre d'onglets, si la mini-app en a une (`:69-73`, `:99-122`).

Dans la page, la couleur d'action devient la couleur forte de la mini-app (`:67-68`). La barre d'onglets reste visible.

### 4.2 Écrans et feuilles du cadre

| N° | Écran ou feuille | Vue, fichier:ligne | Comment on y arrive | Ce qu'on y fait |
|---|---|---|---|---|
| E9 | Écran principal d'une mini-app | `MiniAppScaffold`, `MiniAppScaffold.swift:30` | Une carte de Mon Quotidien, « Mes informations », un widget (`Router.swift:169-171`) | Voir l'essentiel du jour, agir, ouvrir les pages |
| E10 | Page secondaire | `MiniAppScroll`, `MiniApp.swift:231` ; routes `MiniAppPage`, `:80-131` | Une ligne ou une tuile de l'écran principal | Le détail d'un sujet |
| E11 | Feuille « Mes paramètres » | `MiniAppInfoSheet`, `MiniAppSettings.swift:184` | Bouton « Mes paramètres » en bas (`:63-85`) ; dans Nutrition aussi depuis la page (`Nutrition/NutritionApp.swift:78`, `:175`) | Changer ses réponses, la devise, l'heure sur 24 h ; « OK » |
| E12 | Page « Rappels » | `SmartRemindersView`, `App/Screens/Profile/SmartRemindersView.swift:7` | Ligne du rappel dans « Mes paramètres » (`MiniAppSettings.swift:88-116`) | Régler le rappel |
| E13 | Feuille « Choisir une date » | dans `DaySwitcher`, `MiniApp.swift:531-555` | La date d'un sélecteur de jour | Choisir un jour ; « Aujourd'hui », « OK » |
| E14 | Feuille d'une carte « À remplir » | `SpaceSheets`, `App/Screens/Spaces/SpaceSheets.swift:12` ; ouverte par `DataItemRow`, `App/Screens/Profile/DataItemViews.swift:46` | Le bouton d'une carte « À remplir » | Donner l'information (calculer ses besoins, créer une séance…) |

Non affichés aujourd'hui : N1 rangée « Mes mini-apps » (`MiniAppsRow.swift:137`) ; N2 feuille « Mini-apps » (`:205`).

**Total des écrans et feuilles du socle : 15** (E1 à E15). Ajoutés à la relecture : E15 (écran de données sans mini-app). Non comptés (sorties du socle) : la barre d'onglets (voir F36), l'offre Premium (`PaywallView`), « Profil et réglages » (où se trouve le choix de la couleur, voir F33).

### 4.3 Les composants partagés

| Composant | Rôle | Preuve |
|---|---|---|
| `WeekSelector` | Sélecteur de semaine sur verre : titre « Cette semaine », « Semaine dernière », « Semaine prochaine » ou « Semaine du 28 sept. » (`WeekViews.swift:5-14`), flèches « Semaine précédente » / « Semaine suivante », 7 jours (initiale, date, repère), jour choisi en pilule pleine, aujourd'hui cerclé, futur atténué ; balayage ; bouton « Aujourd'hui » **seulement quand le jour choisi n'est pas aujourd'hui** (`WeekSelector.swift:86-98`). Les logs (repas, dépenses) s'arrêtent à aujourd'hui (`allowsFuture`). Un seul sélecteur de dates par écran. | `MiniApps/WeekSelector.swift:23-181` |
| `WeekDayMark` | Les 5 états d'un jour du sélecteur : fait (plein, coche), rattrapé un autre jour (teinté, flèche de retour), avancement (anneau), prévu (contour plein), rien (contour en pointillés) | `MiniApps/WeekViews.swift:25-32` |
| `MiniHero` | La figure essentielle sur verre : étiquette en capitales, grand chiffre (54), une ligne dessous. | `MiniAppScaffold.swift:125-155` |
| `MiniFloatingAction` | L'action principale, capsule de 50 points, flottante. Un double appui ne compte qu'une fois. | `MiniAppScaffold.swift:16-23`, `:99-122` |
| `MiniSectionTitle` | Titre de section avec petite barre de la couleur de la mini-app et détail à droite. | `MiniApp.swift:249-271` |
| `MiniRowsCard`, `MiniRow`, `MiniDivider` | Carte de lignes : pastille ronde de 36, titre, détail, valeur, chevron ; filets entre les lignes. | `MiniApp.swift:274-335`, `:459-463` |
| `MiniStat` | Tuile de chiffre : titre, valeur, unité, détail. | `MiniApp.swift:418-456` |
| `MiniActionButton` | Gros bouton en capsule (plein ou teinté), 50 points de haut. | `MiniApp.swift:385-415` |
| `MiniFootnote` | Petite note grise de fin d'écran. | `MiniApp.swift:373-382` |
| `.miniCard()`, `.miniTile()` | Panneau Cristal au rayon de la palette (26 en Saphir), tuile 4 points plus serrée. | `MiniApp.swift:351-370` |
| `MiniStyle` | Couleurs d'état : alerte `E5484D`, bon `1E9E75`, pas `12A4B5`. | `MiniApp.swift:338-348` |
| `DaySwitcher` | Sélecteur de jour des pages secondaires (veille, lendemain, date, retour à aujourd'hui). | `MiniApp.swift:468-571` |
| `WeekTimetable`, `WeekTableCard` | La semaine en tableau : toucher une heure libre crée, toucher un bloc ouvre ; bande au-dessus des heures pour ce qui n'a pas d'heure ; ligne « maintenant » ; 8 h à 18 h au moins ; version `compact` de Mon Quotidien (blocs sans texte). `WeekTableCard` a sa propre tête (mois et année en gros, « Aujourd'hui », flèches) et sert à la page Planning « Semaine » (`PlanningPages.swift:183`) : ce n'est pas le `WeekSelector` | `MiniApps/WeekViews.swift:41`, `:486` |
| `MiniAppToFillSection` | Bloc « À remplir ». | `MiniApps/MiniAppToFill.swift:41-129` |
| `MiniAppInfoSection` | Bouton « Mes paramètres ». | `MiniAppSettings.swift:63-85` |
| `cristalPanel`, `cristalGlass`, `cristalScreen`, `styledList` | Panneau, verre, fond à deux nappes, listes. | `App/Components/Cristal.swift:85-95` ; `CristalScreen.swift:7-15` |
| `.card()`, `EmptyStateView`, `SectionHeader`, `PremiumBadge` | Carte, état vide (icône sur verre, titre, message, bouton), titre de section, badge Premium doré. | `App/Components/UIComponents.swift:95-187` |
| `PremiumLockCard` | Carte « … est dans Premium ». | `App/Premium/PremiumLock.swift:5` |
| `.buttonStyle(.pressable)`, `TapGuard`, `Haptics` | Retour visuel à l'appui, anti double appui, vibration légère. | `App/Components/Pressable.swift:6-43` ; `UIComponents.swift:283-291` |
| `tapTarget`, `tapAreaOutset`, `confirmDelete`, `Color.readableInk` | Cibles de 44 points, confirmation avant suppression, encre lisible sur une couleur. | `App/Components/AccessibilityHelpers.swift:8-46` |
| `PermissionExplainerView` | Explication avant une demande du système (calendrier, mouvement, notifications). | `App/Components/PermissionExplainer.swift:63`, `:161` |
| `AppStyleGrid`, `AppStyleSwatch`, `AppearancePicker` | Grille des 14 couleurs de l'app (aperçu Cristal de chacune, coche, cadenas doré sur les 13 Premium) et sélecteur de mode « Auto » / « Clair » / « Sombre » | `App/Components/StylePicker.swift:5-100` ; `Shared/Model/Settings.swift:59-69` |
| `SaveFlightOverlay` | Animation des widgets enregistrés qui volent vers « Mes widgets » (Créer, pas les mini-apps) | `App/Components/SaveFlight.swift:1-40` |
| `TemplateCard`, `DesignCard`, `WidgetPreview`, `InteractiveBadge` | Cartes de modèle et de widget (cadenas Premium, badge « interactif »), aperçu de widget : surtout Créer, Store et Mes widgets | `App/Components/UIComponents.swift:22`, `:190`, `:239`, `:334` |
| `SectionIndexBar` | Index alphabétique au bord d'une liste. | `App/Components/SectionIndex.swift:79` |

### 4.4 « À remplir » (`MiniAppToFill.swift:8-20`)

En tête de la feuille. Titre « À remplir » et compteur « n / total » (`:81`). Une carte par information manquante. Une carte donnée s'efface après 1,4 seconde (`:117-123`). Rien ne s'affiche quand tout est donné.

| Mini-app | Cartes demandées |
|---|---|
| Nutrition | « Objectif calorique », « Objectifs de macros » |
| Fitness | « Programme d'entraînement », « Séances par semaine », « Poids », « Objectif de pas » |
| Planning | « Habitudes », « Cours et horaire » |
| Études | « Examens » |
| Business | « Objectif de chiffre d'affaires » |
| Voyage | « Voyage » |
| Auto | « Ta voiture » |
| Photos et citations | aucune |

(Libellés : `App/Core/DataItems.swift:85-117`.)

### 4.5 « Mes paramètres » (`MiniAppSettings.swift:11-53`, `:135-209`)

Un bouton en bas de page, qui ouvre une feuille. Elle montre les mêmes réponses que « Mes informations » : un changement ici vaut partout (note de la feuille, `:194`).

| Mini-app | Questions | « Réglages communs » | « Tes données » | Rappel |
|---|---|---|---|---|
| Nutrition | sujet Nutrition | — | — | « Rappel des repas » |
| Fitness | sujet Sport | — | objectif de pas | « Rappel de séance » |
| Planning | sujet Productivité | « Heure sur 24 h » | — | — |
| Études | sujet Études | — | — | — |
| Business | sujet Business | « Devise » | — | — |
| Voyage | aucune | « Devise » | — | — |
| Auto | sujet Auto | — | — | — |
| Photos et citations | **pas de bouton** (`hasInfo` faux, `:53`) | | | |

### 4.6 Comment chaque mini-app emploie le cadre (hors Finance)

| Mini-app | Sélecteur de semaine | Figure du jour | Action principale | « À remplir » | Note | « Mes paramètres » |
|---|---|---|---|---|---|---|
| Nutrition | Oui, sans futur (`NutritionApp.swift:50`) | Carte propre `CalorieHero` sur verre (`:52-54`) | 2 boutons en tête : « Scanner », « Rechercher » (`:89-101`) | Oui (`:58`) | Oui (`:65`) | Oui (`:66`) |
| Fitness | Oui, avec futur (`FitnessApp.swift:352`) | `MiniHero` | Flottante : « Commencer », « Reprendre la séance », « Créer une séance », « Rattraper… » (`:144-164`) | Oui (`:38`) | Oui (`:46`) | Oui (`:47`) |
| Planning | Oui, avec futur, aligné sur le tableau (`PlanningApp.swift:42`) | Aucune (`compact: true`, `:39`) | Flottante : « Nouvelle tâche » (`:36`) | Oui (`:44`) | Non | Oui (`:121`) |
| Études | **Non** (`StudiesApp.swift:97-104`) | `NextClassCard` et 2 ou 3 tuiles (`:101-102`) ; une carte de départ tant qu'il n'y a ni cours, ni examen, ni devoir (`:98-99`) | Ni flottante ni rangée de boutons (`:97`, `:105-110`) | Oui (`:105`) | Non | Oui (`:110`) |
| Business | Oui, sans futur (`BusinessApp.swift:134`) | `MiniHero` | 2 boutons : « Vente », « Dépense » (`:156-163`) | Oui (`:143`) | Non | Oui (`:150`) |
| Voyage | Seulement s'il y a un voyage (`TravelApp.swift:67-75`) | `TripHero` (`:312`) | Flottante : « Nouveau voyage » ou « Ajouter » (`:120`, `:125`) | Oui (`:77`) | Non | Oui (`:91`) |
| Auto | Seulement s'il y a des données (`CarApp.swift:79-86`) | `MiniHero` | 2 boutons : « Plein », « Kilométrage » (`:90-95`) | Oui (`:88`) | Non | Oui (`:103`) |
| Photos et citations | **Non**, rien de daté (`PhotoQuotesApp.swift:21`) | `MiniHero` (`:22`) | 2 boutons : « Photos », « Citation » (`:26-36`) | Non | Oui (`:79`) | Non |

### 4.7 Couleur d'accent par mini-app

La couleur brute du modèle ne change jamais (les widgets la lisent). À l'écran elle est traduite par la palette (`Shared/Theme/CristalPalette.swift:133-170`) : `category` pour une icône ou un graphique, `strong` pour du texte et les boutons pleins.

| Mini-app | HEX du modèle | En Saphir clair : icône | En Saphir clair : forte | Source |
|---|---|---|---|---|
| Nutrition | `F08A24` | `#C36F25` | `#A75F1F` | `docs/design/2026-11-15-cristal/palettes.md:26-28` |
| Fitness | `E5484D` | `#DF5661` | `#BF4A53` | idem |
| Planning | `3366FF` | `#4385DB` | `#3A72BC` | idem |
| Habitudes | `7FA33A` | `#49961D` | `#3F811A` | idem |
| Voyage | `12A4B5` (= Pas) | `#1E929F` | `#1A7D88` (calculé, à vérifier) | `CristalPalette.swift:179-182` |
| Auto | `6B7280` (= Top 3) | `#79849A` | `#687184` (calculé, à vérifier) | idem |
| Études | `D6409F` | `#D6409F` (calculé, à vérifier) | `#C13A8F` (calculé, à vérifier) | pas de base connue : la règle part du HEX lui-même (`CristalPalette.swift:173-177`) |
| Business | `8C6CFF` | `#8C6CFF` (calculé, à vérifier) | `#785DDA` (calculé, à vérifier) | idem |
| Photos et citations | `D9608B` | `#D9608B` (calculé, à vérifier) | `#BA5277` (calculé, à vérifier) | idem |

### 4.8 Fonctions existantes du socle : liste de référence

Aucune planche ne doit en perdre une.

| N° | Fonction | Où elle est | Gratuit ou Premium | Données affichées | Actions possibles |
|---|---|---|---|---|---|
| F1 | En-tête de l'Accueil : date, avatar, titre selon l'heure | `HomeView.swift:55-78` ; `DailySection.swift:100-123` | Gratuit | Date, « Ta matinée / journée / soirée » | Ouvrir le Profil |
| F2 | Carte Nutrition, 3 vues | `DailySection.swift:575-781`, `:1662-1728` | Gratuit | kcal restantes, 3 macros, repas, 7 jours | « Scanner », ouvrir Nutrition ou l'Historique |
| F3 | Carte Séance, 2 vues | `:808-953`, `:1730-1766` | Gratuit | Séance prévue, en cours, faite, repos ; semaine | « Commencer », « Série faite », pause du repos, « Supprimer la séance » |
| F4 | Carte Planning | `:959-1068` | Gratuit | Tableau de la semaine | Ouvrir Planning, « Relier le calendrier Apple » |
| F5 | Carte Habitudes | `:1070-1210` | Gratuit | Faites/total, série, derniers jours | Ouvrir la page Habitudes |
| F6 | Carte Top 3 | `:1360-1465` | Gratuit | 3 tâches | Cocher, ajout rapide, « Mes tâches réalisées », ouvrir Planning |
| F7 | Carte Budget | `:1242-1284` | Gratuit | Par jour, dépensé aujourd'hui, courbe 7 jours | Ouvrir Finances |
| F8 | Carte « À ne pas oublier » | `:1286-1358` ; `DailyBrief.swift:550-593` | Gratuit | 4 échéances, tâches à faire | Ouvrir la page de chaque ligne |
| F9 | Carte Pas, 2 vues | `:1212-1240`, `:1768-1790` | Gratuit | Pas du jour, objectif, 7 jours | Ouvrir la page Activité |
| F10 | Cartes « un chiffre » : Études, Business, Voyage, Auto | `:448-457` ; `MiniAppsRow.swift:64-111` | Gratuit | Une ligne des données | Ouvrir la mini-app |
| F11 | Cartes vides et état vide global, jamais de faux chiffre | `:1491-1581`, `:332-353` | Gratuit | Invitation, « Ajouter » | Ouvrir la mini-app à remplir |
| F12 | Vues à balayer, vue gardée | `DailyPager.swift:45-136` | Gratuit | Points dans l'en-tête | Balayer |
| F13 | Mode Organiser | `DailyEditMode.swift:78-193` ; `DailyHoldToMove.swift:17` | Gratuit | Cartes qui tremblent | Déplacer, + / −, croix, « OK » |
| F14 | Retirer une carte (les données restent) | `DailyCategories.swift:122-129` | Gratuit | — | « Retirer de Mon Quotidien » |
| F15 | Ajouter une catégorie par le « + » | `DailySection.swift:1585-1658` | Gratuit | Catégories absentes | Ajouter |
| F16 | Feuille « Mon Quotidien » | `DailyLayoutEditor.swift:6-180` | Gratuit | « Sur l'Accueil », « Masquées », « Catégories » | Ordre, « ½ / Large », œil, « Disposition automatique » |
| F17 | Ordre et tailles par défaut, migration unique | `DailyDefaults.swift:11-33` | Gratuit | — | — |
| F18 | Signe doré « Premium » et bandeau « Ardane Premium » | `DailySection.swift:1794-1823` ; `HomeView.swift:171-199` | Visible sans Premium | — | Ouvrir l'offre |
| F19 | « Mes informations » : carte et page | `MyInfoCenter.swift:4-66`, `:151-215` | Gratuit | Complétude, domaines, « À compléter », « Général » (anniversaire, calendrier) | Ouvrir une mini-app ou l'écran E15, choisir ses intérêts ; sans intérêt, carte « Personnalise Ardane » et « Choisir mes centres d'intérêt » (`MyInfoCenter.swift:81-101`) |
| F20 | Actions VoiceOver des cartes | `DailyEditMode.swift:197-213` ; `DailyPager.swift:106-107` | Gratuit | — | Déplacer avant / après, Agrandir, Rétrécir, Vue suivante / précédente |
| F21 | Cadre de l'écran principal : nappe, en-tête, feuille, couleur d'action | `MiniAppScaffold.swift:30-95` | Gratuit | — | — |
| F22 | Sélecteur de semaine, titre de semaine et 5 états de jour (`WeekDayMark`) | `WeekSelector.swift:23-181` ; `WeekViews.swift:5-32` | Gratuit | 7 jours, repères (fait, rattrapé, avancement, prévu, rien) | Choisir un jour, changer de semaine, « Aujourd'hui » (hors aujourd'hui) |
| F23 | Figure essentielle sur verre | `MiniAppScaffold.swift:125-155` | Gratuit | Le chiffre du jour | — |
| F24 | Action flottante | `MiniAppScaffold.swift:99-122` | Gratuit | — | L'action principale |
| F25 | « À remplir » | `MiniAppToFill.swift:41-129` | Gratuit | Informations manquantes, « n / total » | Donner chaque information |
| F26 | « Mes paramètres » | `MiniAppSettings.swift:63-209` | Gratuit | Réponses, « Réglages communs », « Tes données », rappel | Modifier, ouvrir les Rappels |
| F27 | Composants de contenu (titre de section, lignes, tuiles, boutons, note) | `MiniApp.swift:249-463` | Gratuit | — | — |
| F28 | Sélecteur de jour et feuille « Choisir une date » | `MiniApp.swift:468-571` | Gratuit | Jour | Veille, lendemain, date, retour à aujourd'hui |
| F29 | Semaine en tableau | `WeekViews.swift:41-564` | Gratuit | Blocs par jour et par heure, ligne « maintenant » | Toucher une heure libre crée, toucher un bloc ouvre |
| F30 | Pages secondaires et routes (47 pages, retour toujours à l'endroit d'avant) | `MiniApp.swift:78-131`, `:231-246` | Gratuit | — | Retour |
| F31 | Explication avant une permission | `PermissionExplainer.swift:63-283` | Gratuit | Pourquoi, ce que l'app ne fait pas | « Continuer », « Plus tard », « Ouvrir Réglages » |
| F32 | Liens profonds et ouverture depuis un widget | `Router.swift:145-178` ; `Shared/Support/DeepLink.swift:4-64` | Gratuit | — | Ouvrir la mini-app de l'espace, le scanner |
| F33 | Couleur de l'app (14 couleurs), clair et sombre | `App/Components/StylePicker.swift:73-100` ; `CristalPalette.swift:187-204` | **Saphir gratuite, 13 couleurs Premium** (toucher une couleur Premium ouvre l'offre « Toutes les couleurs de l'app », `StylePicker.swift:102-108`) | Mini-aperçu par couleur, cadenas doré | Changer la couleur de toute l'app. Où : « Profil et réglages › Apparence » (`ProfileView.swift:84-93`), à l'inscription (`OnboardingView.swift:353`) et une fois pour les anciennes installations sans choix (`ArdaneApp.swift:162-166`, `:240-242`) |
| F34 | Retour à l'appui, anti double appui, cibles de 44 points | `Pressable.swift:6-43` ; `AccessibilityHelpers.swift:8-17` | Gratuit | — | — |
| F35 | Mode d'affichage « Auto » / « Clair » / « Sombre » | `StylePicker.swift:113-125` ; `ProfileView.swift:88` ; `OnboardingView.swift:354` | Gratuit | Mode choisi | Changer le mode |
| F36 | Barre d'onglets : « Accueil », « Créer », « Store », « Mes widgets » (l'Accueil est actif dans toute mini-app ouverte depuis Mon Quotidien) | `App/ArdaneApp.swift:296-322` | Gratuit | — | Changer d'onglet |
| F37 | Écrans de données sans mini-app : Placements, Sociétés cotées, Ma vie (E15) | `SpaceView.swift:73-85` ; `MoneySpaces.swift:5`, `:325` ; `TravelCarLifeSpaces.swift:510` | Gratuit (aucun test Premium relevé) | Portefeuille, entreprises suivies, anniversaire, jours fériés, lune | Ajouter, modifier, supprimer un placement ; suivre une entreprise ; régler l'anniversaire |

**37 fonctions (34 relevées d'abord, 3 ajoutées à la relecture : F35, F36, F37), dont 1 avec une part Premium (F33).** Le signe doré et le bandeau (F18) ne sont visibles que sans Premium mais ne verrouillent rien.

## 5. Style Cristal Équilibrée et C1 Atelier : jetons et règles pour les planches

Sources : `docs/design/2026-11-15-cristal/GUIDE.md` (règles des planches), `GUIDE-CODE.md` (règles SwiftUI), `README.md`, `cristal.css`, `cristal.js`, `palettes.md`, planches `03` à `09`.

### 5.1 Le système en cinq règles (`README.md:32-37`)

1. Fond clair avec deux nappes de couleur floues.
2. Le contenu est sur des panneaux presque opaques. Le verre est réservé à ce qui flotte.
3. Une seule couleur d'action par écran. Les couleurs des mini-apps ne servent qu'aux icônes et aux graphiques.
4. Dans une mini-app, une nappe de sa couleur éclaire le haut de la page et la couleur d'action devient la sienne.
5. Un état ne repose jamais sur la couleur seule (toujours un mot, une coche, un texte barré).

### 5.2 Jetons de la déclinaison Saphir, en clair (`palettes.md:21-30`)

| Jeton | Valeur |
|---|---|
| Fond | `#EEF3FA` |
| Nappes | `#BFEAF2` et `#C9D8FB` |
| Panneau | `#FFFFFF` à 80 % (`.pn`) |
| Verre | `#FFFFFF` à 55 % avec flou (`.gl`) |
| Feuille | `#FDFEFE` (opaque) |
| Creux | `#E5EBF4` |
| Encre | `#0B1220` |
| Encre secondaire | `#4E5A6B` |
| Filet | `#D6DFEB` |
| Piste des jauges | `#D3DCE8` |
| Action | `#245B8F`, texte blanc |
| Teinte (bouton secondaire) | `#E9EFF4` |
| Teinte 2 (onglet actif) | `#E0E8EF` |
| Secondaire, accentuation | `#398FA8`, `#1E9EC0` |
| Macros | protéines `#DF5661`, glucides `#A37F12`, lipides `#4385DB` |
| Événements | cours `#4385DB`, travail `#926FE4`, rendez-vous `#DD4DA1`, séance `#DF5661` |
| Premium (or) | fond `#F6E7C1`, texte `#6B4E0A` (`cristal.css:247`) |

Les couleurs des mini-apps sont dans le tableau 4.7.

### 5.3 Formes et lettres (`GUIDE.md:16-17`)

- Téléphone de 393 × 852 (`cristal.css:55`). Marges d'écran 20. 12 entre panneaux. 14 à 16 de marge intérieure.
- Rayon des panneaux : 26 en Saphir (`--r`). Pastilles d'icône rondes de 30, 36 ou 44 (`cristal.css:118-119`).
- Boutons en capsule, 44 points au moins (`cristal.css:138`). Action flottante : capsule de 50, à 98 du bas (`cristal.css:231`).
- Lettres (Inter sur les planches, SF Pro sur l'iPhone) : titre d'écran 32/700 ; section 20/700 ou 17/700 ; titre de carte 15/650 ; texte 15 ; secondaire 12,5 à 14 ; grand chiffre 28 ou 44 ; étiquette en capitales 12/700 ; chiffres tabulaires.
- Dans l'app, la figure d'une mini-app est à 54 (`MiniAppScaffold.swift:129`).

### 5.4 Pièces prêtes à l'emploi (`GUIDE.md:18-19`, `cristal.css`)

- En-têtes : `.x-top` (capsule date + avatar), `.x-kick`, `.x-title`, `.x-sub`, `.nv` + `.rb` (retour rond en verre + titre), `.x-sec`, `.sect` (titre de section d'une mini-app, avec sa petite barre).
- Cartes : `.pn` / `.gl`, `.cd`, `.hc`, `.ch` (en-tête de carte : `.ico`, titre, points `.pg`, chevron `.go`), `.nb` (« Maintenant »), `.prem`, `.stat`, `.empty`, `.foot`.
- Boutons et choix : `.btnP` (plein), `.btnT` (teinté), `.btnG` (verre clair), `.btnO` (contour), `.pill`, `.grp`, `.seg`, `.chips` + `.chip`, `.fab`.
- Listes : `.ls` + `.li`, `.chk`, `.tm`, `.evb`.
- Feuilles : `.dim` puis `.sheet` + `.grab`, posées dans `.phone`, hors de `.scr` (`GUIDE.md:45`).
- Graphiques : `data-u="ring|meter|bars|spark|week|dots7|hab|wsel"` (`cristal.js:4-5`).
- Page d'une mini-app : `<div class="phone app t-saphir" data-c="…" data-time="13:20" data-tab="0">` (`cristal.css:224-229`).
- **Attention** : `data-c` ne connaît que `nut`, `fit`, `pla`, `hab`, `bud`, `pro`, `pas`, `prot`, `gluc`, `lip` (`cristal.js`, fonction `themeCss`). Il n'y a pas de clé pour Études, Business ni Photos. Voyage a la même base que `pas`, Auto la même que `pro`. Pour les trois autres, la planche doit poser `--c` et `--cs` elle-même, sans modifier `cristal.css` ni `cristal.js` (`GUIDE.md:46`).

### 5.5 Règles de contenu (`GUIDE.md:21-29`)

- Rien d'inventé. Chaque bloc vient du relevé, avec ses libellés exacts.
- Étiquettes de légende : `Existe` (`.tag.e`), `À adapter` (`.tag.a`), `À développer` (`.tag.d`).
- Aucune fonction existante ne devient un décor.
- Français du Canada : « 412 $ », « 21,68 $ », « 14:00 », « 1 122 » ; repas Déjeuner, Dîner, Souper, Collation ; guillemets « ».
- Une seule journée d'exemple : jeudi 12 novembre, avatar « M », 13:20 par défaut (ou 08:10, 19:05). Chiffres de `DAY`, `EVENTS`, `HABITS`, `TOP3`, `REMIND` (`cristal.js`).
- Thème clair, `t-saphir`. Aucune ressource du réseau. Le guide dit « thème clair seulement » (`GUIDE.md` §3), mais `cristal.js` sait dessiner le sombre (classe `.dk` sur `.phone`, `cristal.js:81-112`) et la planche `12-sombre.html` existe : à ne pas employer sans décision du PDG.
- Vrais exports de widgets : `<img data-w="NOM">`, liste fermée dans `GUIDE.md` §3 (par exemple `calories-m-light`, `todaysWorkout-m-light`, `habits-m-light`, `weekView-m-light`, `priorities-s-light`, `budgetLeft-s-light`). Utile pour montrer le lien carte, widget et mini-app.
- Barre d'onglets d'une planche : `data-tab` vaut `0` Accueil, `1` Créer, `2` Store, `3` Mes widgets, ou `none` (`GUIDE.md` §4).

### 5.6 C1 « Atelier » (création et personnalisation)

- Principe : on arrive dans le Studio avec un widget déjà là ; le guide d'ajout vient après l'enregistrement (`docs/memoire/Decisions.md:121`). Planche de référence : `08-creer-atelier.html` (12 écrans).
- Mise en page : une scène d'aperçu en haut (`.stage`), les réglages dessous, un bouton fixe « Enregistrer le widget » (`.fab`).
- Depuis le 2026-11-15, les réglages sont en **trois chapitres** : « Contenu », « Disposition », « Style » (`App/Screens/Editor/StudioComponents.swift:51-65` ; `SPEC-HYBRIDE.md:72`).
- Création « taille d'abord » : Taille → Catégorie → widget(s) → personnalisation → aperçu et enregistrement. Une création = un seul widget (`Decisions.md:122`, `:136`).
- Outils réels du style : Thème, Style, Couleurs, Fond, Bordure, Graphique, Densité, Mes styles. Il n'existe ni Police, ni Forme, ni Ombre, ni Effets (`GUIDE-CREATION.md` §4).
- Pièces CSS : `.stage`, `.tools`, `.sizes`, `.thumbs`, `.dots`, `.wt` (`cristal.css:284-317`). Outils `CR` dans `creation.js`.
- Mini-app concernée à coup sûr : « Photos et citations » (elle fabrique des widgets, `PhotoQuotesApp.swift:1-8`). Pour les autres, à décider dans chaque audit.

### 5.7 Interdits

- Du verre pour un bloc de texte long (`GUIDE-CODE.md:15`).
- Une deuxième couleur d'action sur un écran (`GUIDE-CODE.md:17`).
- Du texte courant en couleur de catégorie (`GUIDE.md:15`).
- Un choix ou un état signalé par la couleur seule (`GUIDE-CODE.md:18`).
- Une cible de moins de 44 points.
- Dessiner ce qui n'existe pas sans l'étiqueter (hydratation chiffrée, météo, fréquence cardiaque, placements dans Finance…) (`GUIDE.md:22` ; `README.md:63-67`).
- Modifier `cristal.css` ou `cristal.js` : le CSS d'une planche va dans son `<style>`, avec un préfixe à elle (`GUIDE.md:46`).
- Changer le rendu des widgets, le badge et le cadenas Premium dorés (`GUIDE-CODE.md:21`).
- Une nouvelle identité graphique par mini-app (mission, section 2).

### 5.8 Écarts entre le guide et le code d'aujourd'hui

- Le guide parle d'une carte « Maintenant » en verre, une par écran (`GUIDE.md:13`). Dans l'app, depuis le 2026-11-16, la carte garde son panneau et « Maintenant » n'est qu'une étiquette (`DailySection.swift:568-572`).
- Le guide dessine les cartes vides en pointillés (`.empty`, `cristal.css:268-269`). L'app les dessine en panneau plein (`DailySection.swift:1509`).
- La planche `07-habitudes.html` montre « la 6e habitude » comme limite gratuite. La limite est de 3 depuis le 2026-11-16 (`AppModel.swift:13` ; `Decisions.md:127`).
- La planche `06-planning.html` range Études dans Planning. Elles sont séparées depuis le 2026-11-17 (`Decisions.md:133`).
- Les relevés `inventaire/*.md` datent du 2026-11-15 : antérieurs à ces changements.

## 6. Liens

- **Carte de Mon Quotidien** : voir 3.3 et 3.4 (contenu, largeur, destination de chacune).
- **Widgets** : chaque mini-app a un espace de Créer (`MiniApp.space`, `MiniApp.swift:54-66`), sauf Photos. Toucher un widget ouvre sa mini-app par `tessera://space/<id>` (`Router.swift:168-171`). Un widget de l'espace Habitudes n'a pas de mini-app : il ouvre l'onglet Créer sur cet espace (`Router.swift:172-173`), à vérifier sur l'iPhone.
- **Autres liens profonds** (`DeepLink.swift:4-64`) : `tessera://scan-food` (scanner), `tessera://habits`, `tessera://tasks`, `tessera://money` (feuilles `HabitsView`, `TasksView`, `MoneyView`, `App/ArdaneApp.swift:330-332`), `tessera://calendar`, `tessera://premium`, `tessera://design/<id>`.
- **Entre mini-apps** :
  - mêmes réponses partout par « Mes paramètres » et « Mes informations » (`MiniAppSettings.swift:3-8`) ;
  - le tableau de Planning réunit cours, examens, devoirs, tâches, échéances, séances et calendrier (`Agenda.swift:6-8`) ;
  - « À ne pas oublier » réunit Études, Planning, Finances, Auto et Voyage (`DailyBrief.swift:568-585`) ;
  - un seul objectif pour Fitness et Nutrition (`Decisions.md:134`) ;
  - la page Pas appartient à Fitness, la page Habitudes à Planning.
- **Notifications et rappels** : ligne du rappel dans « Mes paramètres » pour Fitness (« Rappel de séance »), Nutrition (« Rappel des repas ») et Finances (« Rappel des factures ») (`MiniAppSettings.swift:125-128`). Elle ouvre `SmartRemindersView`.
- **Tutoriel** : il s'accroche à l'Accueil par `.daily`, `.dailyHeader`, `.dailyNutrition`, `.dailyFitness`, `.profile` (`DailySection.swift:123`, `:250-251` ; `HomeView.swift:69`, `:86-87` ; `App/Screens/Tutorial/Tutorial.swift:109-115`).
- **Parcours testés** (`UITests/`) : `testMonQuotidienOpensAMiniApp` (`MiniAppUITests.swift:580`), `testAMonQuotidienCardShowsAnotherViewWhenSwiped` (`:517`), `testNutritionSettingsAreEditedInPlaceAndTheGenderCanBeChanged` (`:499`), `testDailyEditModeResizesAndEnds` (`HomeLayoutUITests.swift:17`), `testDailyHabitsCardShowsARowOfDaysPerHabitWhenWide` (`:49`), `testDailyEditModeMovesHeldCardsAndScrollsOnSwipe` (`:121`), `testSkippingEverythingShowsNothingMadeUp` (`ProfileUITests.swift:231`), `testMonQuotidienShowsTheDayFromTheUsersData` (`:308`).

## 7. Format des planches Finance à reproduire

Dossier modèle : `docs/design/2026-11-16-finance/` (résumé dans son `README.md`).

### 7.1 Les fichiers

| Fichier | Contenu | Écrans |
|---|---|---|
| `00-analyse.html` | L'existant : 5 captures réelles de la CI annotées (pastilles rouges numérotées), 23 problèmes en 6 familles, tableau des fonctions (Fonction, Ce qu'elle fait, Gratuit, Premium), « Ce qui marche et qu'on garde » | 5 captures |
| `01-minimaliste.html` | Direction 1 | 8 |
| `02-tableau-de-bord.html` | Direction 2 | 9 |
| `03-analytique.html` | Direction 3 | 8 |
| `04-quotidienne.html` | Direction 4 | 8 |
| `05-hybride.html` | Direction 5 | 9 |
| `06-comparaison.html` | Notes, avantages et limites, recommandation, questions, étape 2 | — |
| `finance.css` | Pièces propres à la mini-app, préfixe `fn-` | |
| `finance.js` | Objet `F` (mise en forme, graphiques, morceaux d'écran), données `FIN`, liste `FEATURES` (19 fonctions), `F.mapNote` | |
| `render.py` | Rendu PNG, planche-contact JPG, découpe des téléphones | |
| `README.md` | Résumé, notes, recommandation, questions, limites | |

Total : 42 écrans pour les 5 directions (8 ou 9 par direction). La mission demande au moins 5 types d'écran par proposition (principal, sections et accès, détail d'une fonction, gestion ou personnalisation, vue secondaire).

### 7.2 Structure d'une planche de direction (`05-hybride.html:46-146`)

1. `<body style="--bw:1860px">` : 4 téléphones par rangée.
2. En-tête `.bd-head` : le numéro (`.num`), le titre « Direction N · Nom », une phrase, le badge « Étape 1 · conception · données d'exemple ».
3. Un bandeau de 4 cases (`.fn-rule`) : « La logique », « En ouvrant … », « En faisant défiler », « Forces et limites », avec des priorités P1, P2, P3.
4. Des rangées (`.row`) de colonnes (`.col`). Chaque colonne : le nom de l'écran (`.nm`, « 1 · Page principale »), le téléphone (`.phone app … t-saphir`, `data-c`, `data-time="13:20"`, `data-tab="0"` ou `none` pour une feuille), une flèche vers l'écran suivant (`<span class="flow">`, 6 par planche), puis la légende (`.cap`) : un titre, une phrase, et des lignes étiquetées « Existe », « À adapter », « Nouveau ».
5. Une case large « Ce que la direction prend ou laisse », avec les nouveautés à développer et le rappel « Gratuit / Premium ».
6. En dernier, la table **« Rien n'est retiré : où se trouve chaque fonction existante »** (`F.mapNote`, `finance.js:176-179`) : sur deux colonnes, chaque fonction de `FEATURES`, son accès (G = gratuite, P = Premium), et l'écran où elle se trouve dans cette direction.

Les nouveautés sont aussi marquées dans l'écran (jeton violet « Nouveau », `README.md:18`).

### 7.3 La planche de comparaison (`06-comparaison.html`)

- Un tableau de notes : 10 critères en lignes, 5 directions en colonnes ; dans chaque case, une note sur 10 et une raison de quelques mots ; total sur 100 ; la direction conseillée est marquée (`:128-146`).
- Une carte par direction : vignette du premier écran, « Avantages », « Limites », pour qui (`:148-157`).
- « Ma recommandation », « Les questions pour le PDG », « Étape 2 proposée », « Ce qui ne change dans aucune direction ».
- **Critères de Finance** : Lisibilité, Simplicité, Hiérarchie, Rapidité d'accès, Graphiques, Richesse fonctionnelle, Confort quotidien, Cohérence avec Ardane, Esthétique, Potentiel d'évolution.
- **Critères demandés par la nouvelle mission** (section 6) : les mêmes, sauf que « Graphiques » est remplacé par « Facilité de compréhension pour un nouvel utilisateur ». Les nouvelles planches doivent suivre la liste de la mission.

### 7.4 Rendu et sorties (`README.md:35-42`)

- Commande : `~/ardane-tools/venv/Scripts/python.exe -I render.py NN-nom.html --phones`, puis `--query check` (texte coupé entouré de rouge). Deux passes au moins.
- Sorties hors dépôt, dans `pub/rapports/design-…/` : `NN-nom.png`, `NN-nom-contact.jpg`, `ecrans/NN-nom-01.png…`, et un PDF qui réunit tout.
- Limites à redire sur chaque livraison : maquettes en Inter (SF Pro sur l'iPhone), grandes tailles de texte et mode sombre non dessinés, notes de jugement sans test avec des utilisateurs (`README.md:21`, `:44-47`).

## 8. Incohérences constatées entre mini-apps (faits)

1. **Habitudes n'est pas une mini-app.** C'est une page de Planning, hors du cadre commun : pas de nappe, pas de « Mes paramètres », un sélecteur de jour au lieu du sélecteur de semaine, un grand titre (`Planning/PlanningPages.swift:346-394`).
2. **La carte Habitudes mène à deux endroits.** Remplie : la page Habitudes (`DailySection.swift:1088`). Vide : l'écran principal de Planning (`DailyBrief.swift:245` ; `DailySection.swift:22`).
3. **Deux verts pour Habitudes.** `5C8424` sur la carte remplie (`DailySection.swift:1088`) ; `7FA33A` partout ailleurs (`KindCatalog.swift:64` ; `PlanningApp.swift:113` ; `PlanningPages.swift:366`). Seul `7FA33A` est connu de la palette (`CristalPalette.swift:179`).
4. **Top 3 a trois visages.** Carte : « Top 3 », `3.circle.fill`, gris `6B7280` (`DailySection.swift:1371`). Carte vide et liste du « + » : « Productivité », `checklist` (`DailyBrief.swift:176`, `:193` ; `KindCatalog.swift:12`, `:46`). Feuille d'organisation : « Top 3 », `star.fill`, ambre `F5A524` (`DailyLayoutEditor.swift:173`).
5. **La carte Séance ne porte pas le nom de sa mini-app.** Carte : « Séance », « Séance du jour » ou « Sport », icône `figure.strengthtraining.traditional` (`DailySection.swift:824`, `:913-919`). Carte vide et mini-app : « Fitness », `dumbbell.fill` (`DailyBrief.swift:173` ; `MiniApp.swift:12`, `:26`).
6. **Budget ou Finances.** Carte « Budget » (`DailySection.swift:1250`), mini-app « Finances » (`MiniApp.swift:15`). Vert `2F8F7A` sur la carte, `2B9A66` dans la feuille d'organisation (`DailyLayoutEditor.swift:169`).
7. **« À ne pas oublier » change de couleur.** Gris `4B5563` sur la carte (`DailySection.swift:1292`), rouge `E5484D` dans la feuille d'organisation (`DailyLayoutEditor.swift:170`).
8. **Planning a deux icônes.** `calendar` pour la mini-app (`MiniApp.swift:27`), `calendar.day.timeline.left` pour la carte (`DailySection.swift:984` ; `DailyBrief.swift:206`).
9. **Business a deux couleurs et deux noms.** Violet `8C6CFF` et « Business » pour la mini-app (`MiniApp.swift:16`, `:44`) ; or `C28A12` et « Mon entreprise » pour l'espace et l'intérêt (`KindCatalog.swift:18`, `:69` ; `Shared/Domains/Profile.swift:63`).
10. **Auto a deux gris.** `6B7280` pour la mini-app (`MiniApp.swift:46`), `4B5563` pour l'espace (`KindCatalog.swift:73`). `6B7280` est aussi le gris de Top 3.
11. **Voyage et Pas ont la même couleur**, `12A4B5` (`MiniApp.swift:45`, `:347`).
12. **Études a deux noms.** « Études » pour la mini-app (`MiniApp.swift:14`), « Planning · études » pour l'espace, donc pour sa pastille dans « Mes informations » (`KindCatalog.swift:20` ; `App/Core/DataItems.swift:10`).
13. **Le sélecteur de semaine n'est pas partout.** La règle dit « en tête de chaque mini-app » (`WeekSelector.swift:13`). Études n'en a pas (`StudiesApp.swift:97-104`). Photos non plus (`PhotoQuotesApp.swift:21`). Voyage et Auto ne l'affichent qu'avec des données (`TravelApp.swift:67-75` ; `CarApp.swift:79-86`).
14. **La figure du jour a quatre formes.** `MiniHero` (Fitness, Business, Auto, Photos, Voyage par `TripHero`), une carte propre sur verre (Nutrition, `NutritionApp.swift:52-54`), une carte et des tuiles (Études, `StudiesApp.swift:101-102`), rien (Planning, `PlanningApp.swift:39`).
15. **L'action principale a trois formes.** Flottante dans Fitness, Planning et Voyage (`FitnessApp.swift:34` ; `PlanningApp.swift:36` ; `TravelApp.swift:66`). Deux boutons en tête de feuille dans Nutrition, Business, Auto et Photos (`NutritionApp.swift:89-101` ; `BusinessApp.swift:156-163` ; `CarApp.swift:90-95` ; `PhotoQuotesApp.swift:26-36`). Aucune des deux sur l'écran principal d'Études (`StudiesApp.swift:97`).
16. **La taille du titre change en entrant dans une page.** Petit titre sur l'écran principal (`MiniAppScaffold.swift:75`). Grand titre sur 25 pages secondaires hors Finance (Études 6, Auto 5, Planning 4, Fitness 4, Nutrition 3, Business 3). Petit titre sur les 3 pages de Voyage (`Travel/TravelPages.swift`).
17. **Le titre de l'écran n'est pas toujours le nom de la mini-app.** Business et Auto affichent le nom saisi par la personne (`BusinessApp.swift:152` ; `CarApp.swift:105`).
18. **« Mes paramètres » est très inégal.** Absent de Photos. Une seule ligne (« Devise ») dans Voyage. Un rappel dans Fitness et Nutrition seulement, hors Finance (`MiniAppSettings.swift:11-50`, `:125-128`).
19. **Deux dessins de pastille d'icône.** Ronde, couleur traduite par la palette, dans les lignes (`MiniApp.swift:285-291`). Carrée arrondie, HEX brut, dans les cartes « À remplir » (`DataItemViews.swift:63-67`).
20. **Les cartes vides sont dites « pointillées » mais ne le sont pas.** Les commentaires et la feuille le disent (`DailySection.swift:1489`, `:1583` ; `DailyLayoutEditor.swift:7`). Le dessin est un panneau plein (`DailySection.swift:1509`, `:1598`).
21. **La page « Photos et citations » n'a pas d'entrée depuis l'Accueil.** Pas de carte (`DailyCategories.swift:9`) et la rangée « Mes mini-apps » n'est jamais affichée (`MiniAppsRow.swift:137`). Aucun code ne construit la route `.app(.photos)` hors du mode capture. Ses fonctions restent accessibles par Créer (`CreateFlow.swift:212-217`) et par Mes widgets (`Router.swift:132-133`). À vérifier sur l'iPhone.
22. **La carte « Maintenant » : verre dans le guide, panneau dans l'app** (`GUIDE.md:13` ; `DailySection.swift:568-572`).
23. **La documentation interne est en retard sur le code.** `scripts/graph_map.py:102` liste `MiniApp` sans `studies` ; `:104` parle de « Mes infos » en tête ; `:39` annonce 5 habitudes gratuites (le code dit 3, `AppModel.swift:13`). La CI photographie encore `app-weather` (`.github/workflows/build.yml:470-472`).
24. **Deux têtes de semaine pour un même but.** Les écrans principaux emploient le `WeekSelector` en verre ; la page Planning « Semaine » emploie `WeekTableCard` (mois et année en gros, flèches, « Aujourd'hui ») (`PlanningPages.swift:183` ; `WeekViews.swift:486-530`). Les deux boutons « Aujourd'hui » n'ont pas la même taille (36 contre 44 points de haut, `WeekSelector.swift:93` ; `WeekViews.swift:524`).
25. **Le bouton « Aujourd'hui » du sélecteur est sous 44 points.** Cadre de 36 de haut (`WeekSelector.swift:93-96`) et flèches de 40 × 36 (`:69-72`), contre la règle de 44 du guide. À vérifier à l'écran.
26. **Aucun interrupteur pour la carte Pas** dans la feuille « Mon Quotidien », alors que chaque mini-app a le sien (`DailyLayoutEditor.swift:54-78`) ; Pas est une carte de Fitness sans interrupteur (`DailyCategories.swift:12-20`).
27. **Le choix de la couleur de l'app n'est pas dans Mon Quotidien ni dans une mini-app** : seulement « Profil et réglages › Apparence » (`ProfileView.swift:84-93`).

## 9. Ce que la mission du PDG cite et qui n'existe pas

1. **« Habitudes » comme mini-app** (mission, sections 1 et 4.E). Dans le code c'est une page de Planning, une carte et un espace de Créer (section 2.2). Une mini-app Habitudes à part serait « À développer ».
2. **« Hydratation »** (mission, 4.A). La mini-app Eau et son widget sont retirés depuis le 2026-10-15 (section 2.3). Recherche à la relecture : aucun écran ni libellé d'hydratation dans `App/` ni `Shared/` ; seul le mot « eau » reste dans un texte de vitrine marketing (`App/Core/MarketingShots.swift:761`, « Repas, séance, eau, pas, budget. »), à signaler comme promesse sans écran. Le détail reste à confirmer dans l'audit Nutrition.
3. **Trois tailles de carte « Small », « Medium », « Large » dans Mon quotidien** (mission, section 8). Le code n'a que deux largeurs : « ½ » et « Large » (`DailyLayoutRules.swift:8-10`). « Medium » et « Large » ont la même largeur (`DailyDefaults.swift:19-20`).
4. **« Top 3 en Medium sous les petits blocs »** (mission, section 8). Dans le code, Top 3 est 5e, avant les cartes en demi-largeur (`DailyDefaults.swift:11-14`).
5. **« Nutrition, Fitness et Habitudes en Medium »** (mission, section 8). Dans le code, ces trois cartes sont « Large » par défaut, comme Planning et Top 3 (`DailyDefaults.swift:21`) ; il n'y a pas de taille « Medium » (les tailles Small, Medium, Large existent pour les widgets de l'écran d'accueil, pas pour les cartes de Mon Quotidien).
6. **« Budget selon son format dédié »** (mission, section 8). Il n'y a pas de format à part : Budget est une carte en demi-largeur par défaut, que l'on peut agrandir (`DailyDefaults.swift:21` ; `DailySection.swift:1242-1284`).

## 10. Captures CI disponibles

- **Aucune image dans `origin/ci-report` aujourd'hui.** La référence locale est au commit `170618c` (« Build 455 », 2026-11-17 16:07 UTC) : 918 fichiers, tous en `.txt`. Son `report.txt` dit « screenshots: skipped » (run 455, `[interne]`).
- Raison : la branche est refaite à chaque run (`.github/workflows/build.yml:980-1000`). Les images n'y sont qu'après un run avec captures. Seuls les rapports texte gardent un historique (`history/…`).
- Noms que la CI produit pour ce sujet, quand elle photographie :
  - `[daily]` (`build.yml:503-508`) : `home-light.jpg`, `home-dark.jpg`, `home-pages-light.jpg`, `home-pages-dark.jpg`, `app-nutrition-settings-light.jpg` et `-dark.jpg`, `app-fitness-settings-light.jpg` et `-dark.jpg` (bas de page, avec « Mes paramètres ») ;
  - `[apps]` (`build.yml:429-473`, `:539`) : `app-<mini-app>-light.jpg`, `app-<mini-app>-<page>-light.jpg`, `app-<mini-app>-end-light.jpg`, `home-apps-light.jpg`, `app-nutrition-fresh-light.jpg` ;
  - `[langs]` (`build.yml:481-486`) : `<langue>-home-fresh-light.jpg`, `<langue>-home-light.jpg`, `<langue>-home-pages-light.jpg` ;
  - tests d'interface (dossier `tests/`, `build.yml:977`) : `daily-swiped`, `daily-opens-nutrition`, `nutrition-settings` (`MiniAppUITests.swift:513`, `:546`, `:598`).
- Copies locales hors dépôt (dossier `pub/`, ignoré par git) : `pub/rapports/nuit-2026-11-17/1-inscription-accueil-planning-etudes.jpg` ; `pub/rapports/design-2026-11-16-finance/ci-441/` (5 captures de Finance).
- **Captures locales plus anciennes, hors dépôt** : `C:/Users/Etudiant/ardane-tools/film/public/kit2026/fr/` (2 704 fichiers, datés du 2026-10-31, avant Cristal du 2026-11-15) contient `app-nutrition-*`, `app-fitness-*`, `app-planning-*` et `app-finances-*` (écran principal `sNN`, pages, versions sombres), mais **aucune** pour Études, Business, Voyage, Auto, Photos ni Mon Quotidien (les `home-*` sont des fonds d'écran). Elles montrent l'ancien dessin : à utiliser seulement comme repère de contenu.
- Pour la planche « 0 · analyse » de chaque mini-app, il faudra donc un run avec captures (`[apps]` ou `[daily]`), à lancer par le Chef.

## 11. Contraintes pour la conception

1. **Conception seulement.** Aucune ligne de l'app ne change avant la validation du PDG (mission, sections 9 et 11).
2. **Rien n'est retiré.** Les 37 fonctions du tableau 4.8 gardent leur place ou une place équivalente. Chaque planche finit par la table « Rien n'est retiré ».
3. **Pas de mini-app inventée.** Huit mini-apps hors Finance, plus Habitudes, à présenter comme ce qu'elle est (une page de Planning) ou, si on en fait une mini-app, étiquetée « À développer ».
4. **Ne pas réintroduire dans Planning** les lignes « Semaine », « Mois », « Concentration » et « Études » (mission, 4.C ; `Decisions.md:133`).
5. **Garder la grammaire commune** : sélecteur de semaine en verre, la figure du jour, les sections en panneaux, « À remplir » en tête de feuille, « Mes paramètres » en dernier, une seule action principale. Un seul sélecteur de dates par écran (`WeekSelector.swift:13-21`).
6. **Cristal « Équilibrée »** : fond à deux nappes, panneaux pour le contenu, verre rare, une seule couleur d'action (celle de la mini-app dans sa page), jamais la couleur seule, cibles de 44 points, rayon 26, marges 20.
7. **Les HEX des modèles ne changent jamais** : les widgets les lisent (`GUIDE-CODE.md:16`). Les écarts de couleur de la section 8 se règlent par un choix à présenter au PDG, pas en silence.
8. **Mon Quotidien** : dessiner les cartes dans les deux largeurs réelles (« ½ » et « Large »). Dire sur la planche quel ordre est montré : celui du code (Top 3 en 5e) ou celui de la mission (Top 3 sous les petits blocs). Ce point est à trancher par le PDG.
9. **Même information, mêmes codes aux deux endroits** : la carte de Mon Quotidien et l'écran de la mini-app doivent montrer le même chiffre vedette, le même nom, la même icône et la même couleur.
10. **Calculs inchangés** : contenu des cartes (`DailyBrief`), ligne « un chiffre » (`MiniAppSummary.caption`), règles « À remplir » (`isFilled`), limites gratuites (3 widgets, 3 habitudes, `AppModel.swift:12-13`).
11. **Règles gratuit / Premium inchangées** dans toutes les directions. Le badge et le cadenas Premium restent dorés.
12. **Accroches à garder pour l'intégration** : cibles du tutoriel (`.daily`, `.dailyHeader`, `.dailyNutrition`, `.dailyFitness`) et identifiants des tests (`daily-…`, `week-card`, `week-day-…`, `day-switcher`, `mini-to-fill`, `miniapp-settings-edit`, `mini-floating-action`).
13. **Tenir dans l'app réelle** : mode sombre, grandes tailles de texte, « Réduire la transparence » (`Cristal.swift:43`, `:61`), 7 langues dont l'allemand et le japonais (libellés courts).
14. **Même format que Finance** (section 7) : planche 0 d'analyse, 5 planches de direction, 1 planche de comparaison avec les 10 critères de la mission, un README par mini-app. Journée d'exemple du jeudi 12 novembre, 13:20, thème `t-saphir`, français du Canada.
15. **Couleurs de planche pour Études, Business et Photos** : pas de clé `data-c` ; poser `--c` et `--cs` dans le `<style>` de la planche (valeurs du tableau 4.7, à vérifier au rendu).

## Relecture

- **Ajouté** : écran E15 (Placements, Sociétés cotées, Ma vie, ouverts depuis « Mes informations ») ; fonctions F35 (mode Auto/Clair/Sombre), F36 (barre d'onglets), F37 (écrans de données sans mini-app) ; détail du mode Organiser, des interrupteurs « Catégories » (par mini-app, rien pour Pas), des 5 états `WeekDayMark`, des titres de semaine, de `WeekTableCard`, de la grille des couleurs (où la changer) ; écarts 24 à 27 ; règles `.dk`, `data-w` et `data-tab` du guide ; captures locales du 2026-10-31 ; recherche « hydratation » ; point « Nutrition, Fitness, Habitudes en Medium » en section 9. Totaux : 15 écrans, 37 fonctions, 1 avec part Premium, 27 écarts.
- **Corrigé** : la ligne « N tâches à faire » de « À ne pas oublier » ne vient jamais en 5e (4 lignes au plus en tout) ; « chaque ligne de Mes informations ouvre sa mini-app » était faux pour 3 lignes ; l'invitation (`InviteDayTile`) est du code que l'Accueil n'affiche plus ; le guide dit « thème clair seulement » mais le sombre existe dans `cristal.js`. Les autres affirmations vérifiées (liste des 9 cas, 47 pages, ordre et largeurs par défaut, titres d'heure, composants du cadre, « Mes paramètres », « À remplir », limite de 3 habitudes, 42 écrans Finance) sont justes.
- **Incertain** : tailles réelles de touche du bouton « Aujourd'hui » du sélecteur (36 points de haut dans le code, contour tactile à vérifier à l'écran) ; couleurs calculées d'Études, Business, Photos (tableau 4.7) ; entrée de « Photos et citations » depuis l'Accueil (écart 21) ; widgets de l'espace Habitudes (`Router.swift:172-173`) ; numéros de ligne de `ProfileView.swift:84-93`, relevés à la lecture sans recomptage.
