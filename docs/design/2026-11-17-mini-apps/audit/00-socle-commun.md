# Audit : Socle commun (Mon quotidien, cadre des mini-apps, style Cristal)

Relevé dans le code le 2026-11-17. Branche `main`, commit `e09123e` ; le code de l'app est celui du commit `c06fd60` (Build 455), sans changement local dans `App/` ni `Shared/`. Lecture seule. Chaque fait porte sa preuve (`fichier:ligne`). Ce fichier ne décrit pas une mini-app : il décrit ce que toutes partagent.

Deuxième passe du même jour : tout a été relu dans le code. Corrigé depuis la première version : la section « Général » de « Mes informations » ne contient que « Calendrier » ; la page des rappels s'appelle « Rappels intelligents » ; le sélecteur de semaine ne dessine que trois états de point ; plusieurs numéros de ligne ; les couleurs de planche d'Études et d'Entreprise ; les captures du run 454 (copie locale). Ajouté : les écarts 28 à 37. Les numéros E1 à E15, F1 à F37 et les écarts 1 à 27 gardent leur numéro.

## 1. En bref

- Le socle, c'est trois choses : l'Accueil « Mon Quotidien » (la porte de toutes les mini-apps), le cadre commun d'un écran de mini-app (`MiniAppScaffold`) et le style Cristal « Équilibrée ».
- Pour qui : tout le monde, à chaque ouverture de l'app. Mon Quotidien est le premier onglet (`App/Screens/Home/HomeView.swift:7`, `App/ArdaneApp.swift:301-304`).
- Le code compte **9 mini-apps** (`enum MiniApp`, `App/Screens/MiniApps/MiniApp.swift:5-6`), donc **8 hors Finance**. « Habitudes » n'en est pas une : c'est une page de Planning.
- État : en place et testé (run 454, 1 637 tests réussis, `docs/memoire/Chantiers.md:362`). Ordre de Mon Quotidien refait le 2026-11-17 (`App/Core/DailyDefaults.swift:11-14`).
- Le cadre est commun, mais chaque mini-app l'emploie à sa façon : 37 écarts relevés (section 8).

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
- Le choix de la vue se fait dans `MiniAppView` (`MiniApp.swift:134-165`) et `MiniAppPageView` (`:167-226`).
- Chaque ouverture est comptée (`MiniAppUsage.record`, `MiniApp.swift:139`). Ce compte ne sert qu'à la rangée « Mes mini-apps », qui n'est pas affichée (voir 2.2).
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
| **« Mes mini-apps »** (rangée de puces, feuille « Mini-apps ») | Code présent, **jamais affiché** : `MiniAppsRow` n'est appelé nulle part (recherche dans `App/`, `Shared/`, `UITests/`, `Tests/` : aucun appel). | `App/Screens/Home/MiniAppsRow.swift:137`, `:205` ; `HomeView.swift:80-93` ; `scripts/graph_map.py:89` |

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
   - si rien n'est saisi : carte « Complète tes informations pour personnaliser ton Mon Quotidien. » et bouton « Ajouter mes informations » (`:131-133`, `:332-353`). Les cartes vides restent affichées dessous ;
   - la grille des cartes (`:134-148`) ;
   - un « + » en bas tant qu'il manque une catégorie (`:150-152`).
3. **« Mes informations »** : anneau de complétude, pastilles par domaine, « Tout voir » (`MyInfoCenter.swift:4-66`). La carte à l'anneau ne s'affiche que si la personne suit au moins un domaine (`:26`).
4. **Bandeau « Ardane Premium »**, sans Premium seulement (`HomeView.swift:90-92`, `:171-199`).

Vérifié sur les captures du run 454 `profile-home-daily.png`, `profile-home-skipped.png` et `profile-daily-habits-wide.png` (voir section 10).

### 3.2 Écrans et feuilles de Mon Quotidien

| N° | Écran ou feuille | Vue, fichier:ligne | Comment on y arrive | Ce qu'on y fait |
|---|---|---|---|---|
| E1 | Accueil « Mon Quotidien » | `HomeView`, `HomeView.swift:7` ; `DailySection`, `DailySection.swift:57` | Onglet « Accueil » (`App/ArdaneApp.swift:301-304`) | Lire le jour, agir sur une carte, ouvrir une mini-app |
| E2 | Mode « Organiser » | `DailyEditableCard`, `DailyEditMode.swift:78` | Appui long sur une carte, puis « Organiser… » (`DailyEditMode.swift:216-234`) | Déplacer, agrandir (+), rétrécir (−), retirer (croix), « OK ». Détail : texte d'aide « Maintiens une carte puis glisse-la pour la déplacer. + et − changent sa taille. » (`DailySection.swift:125`) ; poignée à trois traits en haut à droite, croix en haut à gauche, un seul bouton « + » (carte demi) ou « − » (carte large) en bas (`DailyEditMode.swift:135-179`) ; maintenir une demi-seconde puis glisser (`DailyHoldToMove.swift`) ; les cartes tremblent (sauf « Réduire les animations ») ; un appui dans une zone vide termine (`DailySection.swift:156-161`). Toutes les cartes acceptent les deux tailles et se déplacent ; seul le type « invitation » (`InviteDayTile`, `DailySection.swift:1468`) ferait exception, mais `DailyBrief.completing` le retire de l'Accueil (`DailyBrief.swift:386`) : code qui ne s'affiche plus (`DailyLayoutRules.swift:12-17`, `:43-46`) |
| E3 | Feuille « Mon Quotidien » | `DailyLayoutEditor`, `DailyLayoutEditor.swift:6` | Bouton à curseurs du mode Organiser (`DailySection.swift:174-184`) | Section « Sur l'Accueil » : ordre (glisser), taille « ½ » ou « Large », œil pour masquer. Section « Masquées ». Section « Catégories ». Bouton « Disposition automatique ». « OK ». Les interrupteurs « Catégories » sont **par mini-app** : les 8 sauf Photos (Finances comprise) plus « Productivité » (`DailyLayoutEditor.swift:48-81`, `DailyCategories.swift:9`). Fitness pilote la carte Séance ; Planning pilote Planning, Habitudes et « À ne pas oublier » (et Top 3 tant que « Productivité » n'est pas ajoutée) (`DailyCategories.swift:12-20`, `:155-178`). **Aucun interrupteur pour la carte Pas** : elle se règle par l'œil, la croix ou le « + » du bas. « Disposition automatique » est grisé quand l'ordre et les tailles sont déjà automatiques (`DailyLayoutEditor.swift:24-26`, `:92`). Dans cette feuille la carte Séance s'appelle « Séance du jour » (`:167`) |
| E4 | Feuille « Ajouter une catégorie » | `AddCategorySheet`, `DailySection.swift:1609` | Le « + » du bas (`:1585-1605`) | Ajouter une carte (une ligne par catégorie absente) ; « Fermer ». Note : « Une carte vide s'affiche tant que tu n'as rien rempli : aucune donnée n'est inventée. » (`:1644`) |
| E5 | Page « Mes tâches réalisées » | `CompletedPrioritiesView`, `App/Screens/Spaces/ProductivitySpace.swift:168` | Lien de la carte Top 3 (`DailySection.swift:1419-1439`) | Revoir les tâches validées (« Terminée le … ») ; toucher une tâche la remet dans le Top 3 s'il reste de la place (`ProductivitySpace.swift:181-205`) |
| E6 | Page « Mes informations » | `MyInfoView`, `MyInfoCenter.swift:151` | « Tout voir » ou l'anneau (`MyInfoCenter.swift:17`, `:28`) | Anneau « n/total » et « Tout est renseigné » ou « N informations à compléter », bouton « Mes centres d'intérêt » (`:165-176`) ; listes « Tes thèmes », « Autres catégories » (ou « Catégories »), puis « Général ». **« Général » ne contient que « Calendrier »** (l'accès au calendrier, donné sur place) : `MyInfoCenter.swift:182`, `App/Core/DataItems.swift:77`. L'anniversaire est rangé dans « Ma vie » (`DataItems.swift:76`). Chaque ligne affiche un résumé (3 au plus, ou « Rien de renseigné ») et une pastille du nombre d'infos à compléter (`:219-260`). Une ligne ouvre sa mini-app ; Habitudes et Productivité ouvrent Planning (`DailySection.swift:18-28`) ; **Placements, Sociétés cotées et Ma vie ouvrent l'écran E15**. Vérifié sur la capture `profile-home-info.png` |
| E15 | Écran de données d'un espace sans mini-app (`SpaceView`, `isEmbedded: true`) | `SpaceView`, `App/Screens/Spaces/SpaceView.swift:5`, `:74-89` ; ouvert par `HomeView.swift:26-32` | Ligne « Placements », « Sociétés cotées » ou « Ma vie » de E6 (`DailySection.swift:28`, `:36`) | Liste de données, sans bandeau de widgets. **Placements** : valeur et gain du portefeuille, « Ajouter un placement », mention « À titre informatif seulement : Ardane ne donne aucun conseil d'investissement. » (`MoneySpaces.swift:5-60`). **Sociétés cotées** (« Entreprises suivies ») : liste, « Ajouter une entreprise » (`MoneySpaces.swift:325-370`). **Ma vie** : « Afficher mon anniversaire », date, âge, prochain anniversaire, « Jours fériés » par région, « Lune » (`TravelCarLifeSpaces.swift:510-570`). Aucun test Premium relevé dans ces vues |
| E7 | Feuille des centres d'intérêt | `InterestsEditorSheet`, `App/Screens/Profile/ProfileTopics.swift` (à vérifier pour la ligne) | « Choisir mes centres d'intérêt » (`MyInfoCenter.swift:89-93`) ou « Mes centres d'intérêt » (`:171`) | Choisir ses intérêts (11 : Sport, Nutrition, Finance, Budget, Business, Études, Planning, Voyage, Automobile, Design, Bien-être, `Shared/Domains/Profile.swift:10-30`) |
| E8 | Feuille d'explication d'une permission | `PermissionExplainerView`, `App/Components/PermissionExplainer.swift:161` | « Relier le calendrier Apple » sur la carte Planning (`DailySection.swift:1028-1046`) | « Continuer » ou « Plus tard » ; refusé : « Ouvrir Réglages » (`PermissionExplainer.swift:201`, `:219`, `:228`) |

Menus et dialogues (non comptés comme écrans) :
- M1. Menu d'une carte : « Organiser… », « Retirer de Mon Quotidien » (`DailyEditMode.swift:222-229`).
- M2. Menu de la séance faite aujourd'hui : « Supprimer la séance », puis les deux entrées de M1 (`DailySection.swift:785-806`), avec confirmation (`Fitness/FitnessPages.swift:516`).

Routes de la pile de l'Accueil (`HomeRoute`, `DailySection.swift:4-13`) : `.space`, `.info`, `.infoArea` (vieux liens seulement), `.app`, `.page`. Destinations : `HomeView.swift:24-46`.

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
| 6 | Études (`app-studies`) | Si intérêt « Études », si ajoutée, ou s'il y a des cours (`DailyCategories.swift:97-104`) | Demi | 1 | Études |
| 7 | Budget (`budget`) | Si intérêt, ajout ou données | Demi | 1 | Finances (`.space(.budget)`, `:1250`) |
| 8 | À ne pas oublier (`reminders`) | S'il y a une échéance, ou si ajoutée | Demi | 1 | Chaque ligne ouvre sa page (`:1294-1300`) |
| 9 | Pas (`steps`) | Si le compteur de pas est autorisé (`:85`), ou si ajoutée | Demi | 2 : « Aujourd'hui », « 7 jours » (`:438`) | Page Activité de Fitness (`:1218`) |
| 10 | Business (`app-business`) | Si intérêt, ajout ou données | Demi | 1 | Business |
| 11 | Voyage (`app-travel`) | Idem | Demi | 1 | Voyage |
| 12 | Auto (`app-car`) | Idem | Demi | 1 | Auto |

« Photos et citations » n'a pas de carte (`DailyCategories.swift:9` ; `DailyBrief.swift:165`).

### 3.4 Ce que chaque carte affiche

**1. Nutrition** (`NutritionDayTile`, `DailySection.swift:575-781`). Visible avec des données dès qu'un objectif est donné ou qu'un aliment est noté aujourd'hui (`DailyBrief.swift:452-459`).
- Vue « Aujourd'hui », large (`:675-760`) : anneau de 90 points avec les « kcal restantes » (ou « kcal en trop », ou « kcal mangées » sans objectif) ; « Objectif à définir » sans objectif ; trois lignes « Protéines », « Glucides », « Lipides » (mangé / cible en g, barre) ; bouton « Scanner » (ouvre le scanner) ; « Rien noté » ou « N repas » ; « Prochain repas : …, environ N kcal ». Un « ≥ » précède un chiffre quand les valeurs d'un aliment sont incomplètes (`:771`, `Shared/Domains/Nutrition.swift:439`).
- Vue « Aujourd'hui », demi-largeur (`:587-650`) : anneau de 46 points, le chiffre, trois macros serrées, bouton rond du scanner, texte des repas.
- Vue « Repas du jour » (`:1662-1711`) : les repas avec leurs kcal ou « — », puis « Total » mangé / objectif.
- Vue « Calories · 7 jours » (`:1713-1728`) : 7 barres, trait de l'objectif, « Moyenne : N kcal par jour noté » ou « Rien noté cette semaine ».
- Vide : « Donne ton objectif calorique ou scanne un repas : tes calories du jour apparaîtront ici. » (`DailyBrief.swift:228`).

**2. Séance** (`WorkoutDayTile`, `:808-953`). Visible dès qu'un programme existe (`DailyBrief.swift:480`). Titre de la carte : « Séance », « Séance du jour » ou « Sport » selon l'état (`:913-919`).
- Prévue : « Séance du jour », le nom, « N exercices · N séries », bouton « Commencer ». Le bouton démarre la séance sur la carte, sans ouvrir Fitness (`:839-843`).
- En cours : « Séance en cours », l'exercice, « Série x/y · reps × charge », le repos qui décompte avec pause et reprise, bouton « Série faite » (`:844-868`).
- Faite : le nom, « Faite · N séries », « N kg soulevés » (`:869-880`). Appui long : « Supprimer la séance ».
- Repos : « Repos aujourd'hui », puis le jour et le nom de la prochaine (`:881-890`).
- Étiquette « Maintenant » : séance en cours, ou prévue à partir de 11 h (`:900-911`). Elle prend la place du titre dans l'en-tête (`:495-506`).
- Vue « Cette semaine » (`:1730-1766`) : « N/objectif séances », 7 points, « Objectif de la semaine atteint » ou « Encore N séances ».
- Vide : carte nommée « Fitness », « Crée ton programme : ta séance du jour apparaîtra ici. » (`DailyBrief.swift:229`).

**3. Planning** (`PlanningDayTile`, `:959-1068`). Toujours là, même vide.
- Large : le tableau de la semaine (`WeekTimetable`, 22 points par heure, blocs avec texte) ; « Rien de prévu cette semaine. » au-dessus si vide ; « Toute la semaine › » (`:1015-1021`, `:1054-1061`).
- Demi-largeur : le même tableau en petit (12 points par heure), blocs sans texte ; vide : le texte seul (`:1008-1013`).
- Contenu du tableau : événements du calendrier Apple, plages de l'horaire, examens, devoirs, tâches, échéances, séances (`App/Core/Agenda.swift:6-8`).
- Calendrier non relié : bouton « Relier le calendrier Apple » (`:972-982`, `:1038`).
- On ne crée rien depuis la carte : la toucher ouvre Planning (`:984`).

**4. Habitudes** (`HabitsDayTile`, `:1070-1210`). Visible dès qu'une habitude existe.
- Large : « faites/total », « Série de N jours », puis une ligne par habitude (5 au plus, puis « +N ») : anneau du jour, nom, derniers jours en petits carrés (`:1115-1129`, `:1174-1201`).
- Demi-largeur : un anneau par habitude, le compte, « faites aujourd'hui », la série ou les noms (`:1089-1114`).
- On ne coche pas depuis la carte : toute la carte est un lien (`:1088`).
- Vide : « Ajoute une habitude à suivre chaque jour. » (`DailyBrief.swift:233`).

**5. Top 3** (`PrioritiesDayTile`, `:1360-1465`). 3 tâches au plus (`Shared/Domains/Productivity.swift:194`).
- Chaque tâche se coche sur place (`:1374-1378`). Une tâche validée quitte la carte et va dans « Mes tâches réalisées » (`Productivity.swift:212`, `:231-242`).
- Champ « Ajouter une tâche » : seulement si « Productivité » a été ajoutée et s'il reste de la place (`:1366-1367`, `:1403-1418`).
- « Mes tâches réalisées » (page E5) et un chevron vers Planning (`:1419-1451`). Quand le champ d'ajout est là, « Mes tâches réalisées » se réduit à une icône (`:1422-1427`).
- Vide : carte nommée « Productivité », « Ajoute tes tâches ou ton top 3 du jour. » (`DailyBrief.swift:234`).

**6. Études, 10. Business, 11. Voyage, 12. Auto** : carte « un chiffre » (`DailySection.swift:448-457`). Nom, icône et couleur de la mini-app, puis une ligne tirée des données (`MiniAppSummary.caption`, `MiniAppsRow.swift:64-111`) :
- Études : prochain examen dans 14 jours « titre · compte à rebours », sinon « N devoirs à rendre », sinon le prochain cours, sinon « N cours » (`:81-92`).
- Business : « X $ ce mois » (`:97-99`).
- Voyage : « destination · jour N » ou « destination · J-N » (`:100-103`).
- Auto : « ≈ N km d'autonomie », sinon « N km » (`:104-106`).
- Sans donnée : carte d'invitation (textes de `DailyBrief.swift:231`, `:237-239`).

**7. Budget** (`BudgetDayTile`, `:1242-1284`). Visible si le budget du mois est connu ou s'il y a une dépense aujourd'hui (`DailyBrief.swift:361-365`). Montant « à dépenser par jour d'ici la fin du mois », « Dépensé aujourd'hui : X », courbe des 7 derniers jours s'il y a eu des dépenses.

**8. À ne pas oublier** (`RemindersDayTile`, `:1286-1358`). 4 lignes au plus en tout : jusqu'à 4 échéances ; la ligne « N tâches à faire » (avec les 2 premiers titres) ne s'ajoute que s'il reste de la place (`DailyBrief.swift:586-591`). Seule chaque ligne est un lien (`DailySection.swift:1294-1300`). Sources : examens (demain au plus), devoirs (3 jours), échéances de Planning (2 jours), factures (3 jours), échéances auto (7 jours), départ en voyage (3 jours) (`DailyBrief.swift:568-585`). « En retard » s'écrit en rouge (`:1326`, `:1350`).

**9. Pas** (`StepsDayTile`, `:1212-1240`). Nombre de pas, « / objectif », barre ; « Objectif à définir » sans objectif. Vue « Pas · 7 jours » : barres et « Moyenne : N pas », ou « La semaine apparaîtra ici. » (`:1768-1790`).

### 3.5 Règles d'affichage à connaître

- **Deux largeurs seulement** : demi ou toute la largeur (`DailyLayoutRules.swift:8-10`). « Moyen » et « Grand » ont la même largeur ; seule la hauteur du contenu change (`DailyDefaults.swift:19-20`).
- Deux cartes en demi-largeur se rangent côte à côte, même si des cartes larges les séparent dans l'ordre. Une demi-carte qui reste seule va en dernier et prend toute la largeur avec son contenu « large » (`DailyLayoutRules.swift:136-151` ; `DailyEditMode.swift:64-66` ; `DailySection.swift:136`, `:143`).
- 12 points entre les cartes (`DailyEditMode.swift:35`). Marge d'écran 20 (`HomeView.swift:94`). Marge intérieure d'une carte 14 (`DailySection.swift:556`).
- En-tête d'une carte : pastille ronde de 30 (26 en demi-largeur), titre, points de vue, chevron. En demi-largeur le chevron part d'abord, puis les points (`DailySection.swift:464-524`).
- Une carte vide a la même largeur que la carte remplie (`DailyBrief.swift:302`). Jamais de faux chiffre.
- Sur l'Accueil, les boutons des cartes ont la couleur de l'app (bleu en Saphir), pas celle de la mini-app (`DailySection.swift:735`, `:949`). Dans la mini-app, la couleur d'action devient la sienne (`MiniAppScaffold.swift:67-68`).
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
5. **Action flottante** à 12 points au-dessus de la barre d'onglets, si la mini-app en a une (`:69-73`, `:99-122`). La page garde alors 130 points libres en bas (`:61`).

Dans la page, la couleur d'action devient la couleur forte de la mini-app (`:67-68`). La barre d'onglets reste visible. Vérifié sur les captures `mini-app-studies.png` et `mini-app-planning.png`.

### 4.2 Écrans et feuilles du cadre

| N° | Écran ou feuille | Vue, fichier:ligne | Comment on y arrive | Ce qu'on y fait |
|---|---|---|---|---|
| E9 | Écran principal d'une mini-app | `MiniAppScaffold`, `MiniAppScaffold.swift:30` | Une carte de Mon Quotidien, « Mes informations », un widget (`Router.swift:168-171`) | Voir l'essentiel du jour, agir, ouvrir les pages |
| E10 | Page secondaire | `MiniAppScroll`, `MiniApp.swift:231` ; routes `MiniAppPage`, `:80-131` | Une ligne ou une tuile de l'écran principal | Le détail d'un sujet |
| E11 | Feuille « Mes paramètres » | `MiniAppInfoSheet`, `MiniAppSettings.swift:184` | Bouton « Mes paramètres » en bas (`:63-85`) ; dans Nutrition aussi depuis la page (`Nutrition/NutritionApp.swift:78`) | Changer ses réponses, la devise, l'heure sur 24 h ; « OK ». Vérifié sur la capture `mini-app-nutrition-settings.png` |
| E12 | Page « Rappels intelligents » | `SmartRemindersView`, `App/Screens/Profile/SmartRemindersView.swift:7`, titre `:144` | Ligne du rappel dans « Mes paramètres » (`MiniAppSettings.swift:88-116`) | Toute la page des rappels de l'app : état des notifications, « Prochain rappel », un interrupteur par famille (Fitness, Nutrition, Habitudes, Planning, objectifs, général), « Séance du jour » et « Repas » avec leur heure, « Encouragements », « Factures », « Horaires et fréquence » (`SmartRemindersView.swift:19-141`) |
| E13 | Feuille « Choisir une date » | dans `DaySwitcher`, `MiniApp.swift:531-555` | La date d'un sélecteur de jour | Choisir un jour ; « Aujourd'hui », « OK » |
| E14 | Feuille d'une carte « À remplir » | `SpaceSheets`, `App/Screens/Spaces/SpaceSheets.swift:12` ; ouverte par `DataItemRow`, `App/Screens/Profile/DataItemViews.swift:46` | Le bouton d'une carte « À remplir » | Donner l'information (calculer ses besoins, créer une séance, un cours, un examen, un voyage) |

Non affichés aujourd'hui : N1 rangée « Mes mini-apps » (`MiniAppsRow.swift:137`) ; N2 feuille « Mini-apps » (`:205`).

**Total des écrans et feuilles du socle : 15** (E1 à E15). Non comptés (sorties du socle) : la barre d'onglets (voir F36), l'offre Premium (`PaywallView`), « Profil et réglages » (où se trouve le choix de la couleur, voir F33).

### 4.3 Les composants partagés

| Composant | Rôle | Preuve |
|---|---|---|
| `WeekSelector` | Sélecteur de semaine sur verre : titre « Cette semaine », « Semaine dernière », « Semaine prochaine » ou « Semaine du 28 sept. » (`WeekViews.swift:5-14`), flèches « Semaine précédente » / « Semaine suivante », 7 jours (initiale, date, point), jour choisi en pilule pleine, aujourd'hui cerclé, futur atténué ; balayage ; bouton « Aujourd'hui » **seulement quand le jour choisi n'est pas aujourd'hui** (`WeekSelector.swift:86-98`). Les journaux (repas, ventes, pleins) s'arrêtent à aujourd'hui (`allowsFuture`). Un seul sélecteur de dates par écran. | `MiniApps/WeekSelector.swift:23-181` |
| Point d'un jour (`WeekDayMark`) | Le sélecteur ne dessine que **trois états** sous la date : point plein (fait, rattrapé ou commencé), point creux (prévu), rien (`WeekSelector.swift:132-141`). Le commentaire de `WeekDayMark` décrit cinq dessins (coche, flèche, anneau, contour, pointillés) qui ne sont pas dessinés (`WeekViews.swift:25-32`). | `WeekSelector.swift:108-160` |
| `MiniHero` | La figure essentielle sur verre : étiquette en capitales, grand chiffre (54), une ligne dessous. | `MiniAppScaffold.swift:125-155` |
| `MiniFloatingAction` | L'action principale, capsule de 50 points, flottante. Un double appui ne compte qu'une fois. | `MiniAppScaffold.swift:16-23`, `:99-122` |
| `MiniSectionTitle` | Titre de section avec petite barre (4 × 16) de la couleur de la mini-app et détail à droite. | `MiniApp.swift:249-271` |
| `MiniRowsCard`, `MiniRow`, `MiniDivider` | Carte de lignes : pastille ronde de 36, titre, détail, valeur, chevron ; filets entre les lignes. | `MiniApp.swift:274-335`, `:459-463` |
| `MiniStat` | Tuile de chiffre : titre, valeur, unité, détail. | `MiniApp.swift:418-456` |
| `MiniActionButton` | Gros bouton en capsule (plein ou teinté), 50 points de haut. | `MiniApp.swift:385-415` |
| `MiniFootnote` | Petite note grise de fin d'écran. | `MiniApp.swift:373-382` |
| `.miniCard()`, `.miniTile()` | Panneau Cristal au rayon de la palette (26 en Saphir), tuile 4 points plus serrée (22). | `MiniApp.swift:351-370` |
| `MiniStyle` | Couleurs d'état : alerte `E5484D`, bon `1E9E75`, pas `12A4B5`. Rayons fixes 20 et 18, peu employés. | `MiniApp.swift:338-348` |
| `DaySwitcher` | Sélecteur de jour des pages secondaires (« Hier », « Aujourd'hui », « Demain » ou la date ; veille, lendemain, retour à aujourd'hui). Employé par Planning › Tâches, la page Habitudes, Fitness › Activité. | `MiniApp.swift:468-571` ; `PlanningPages.swift:61`, `:366` ; `FitnessPages.swift:415` |
| `WeekTimetable`, `WeekTableCard` | La semaine en tableau : toucher une heure libre crée, toucher un bloc ouvre ; bande au-dessus des heures pour ce qui n'a pas d'heure ; ligne « maintenant » ; 8 h à 18 h au moins ; version `compact` de Mon Quotidien (blocs sans texte). `WeekTableCard` a sa propre tête (mois et année en gros, « Aujourd'hui », flèches) et sert à la page Planning « Semaine » (`PlanningPages.swift:183`) : ce n'est pas le `WeekSelector` | `MiniApps/WeekViews.swift:41`, `:486` |
| `MiniAppToFillSection` | Bloc « À remplir ». | `MiniApps/MiniAppToFill.swift:41-129` |
| `MiniAppInfoSection` | Bouton « Mes paramètres » (contour, 44 points). | `MiniAppSettings.swift:63-85` |
| `cristalPanel`, `cristalGlass`, `cristalScreen`, `styledList` | Panneau, verre, fond à deux nappes, listes. | `App/Components/Cristal.swift:85-95` ; `CristalScreen.swift:7-15` |
| `.card()`, `EmptyStateView`, `SectionHeader`, `PremiumBadge` | Carte, état vide (icône sur verre, titre, message, bouton), titre de section, badge Premium doré. | `App/Components/UIComponents.swift:95-187` |
| `PremiumLockCard` | Carte « … est dans Premium ». | `App/Premium/PremiumLock.swift:5` |
| `.buttonStyle(.pressable)`, `TapGuard`, `Haptics` | Retour visuel à l'appui, anti double appui, vibration légère. | `App/Components/Pressable.swift:6-43` ; `UIComponents.swift:283-291` |
| `tapTarget`, `tapAreaOutset`, `confirmDelete`, `Color.readableInk`, `CheckCircleButton` | Cibles de 44 points, confirmation avant suppression, encre lisible sur une couleur, cercle à cocher. | `App/Components/AccessibilityHelpers.swift:8-79` |
| `PermissionExplainerView` | Explication avant une demande du système (notifications, calendrier, mouvement, caméra). | `App/Components/PermissionExplainer.swift:64`, `:161` |
| `AppStyleGrid`, `AppStyleSwatch`, `AppearancePicker` | Grille des 14 couleurs de l'app (aperçu Cristal de chacune, coche, cadenas doré sur les 13 Premium) et sélecteur de mode « Auto » / « Clair » / « Sombre » | `App/Components/StylePicker.swift:5-126` ; `Shared/Model/Settings.swift:4-78` |
| `SaveFlightOverlay` | Animation des widgets enregistrés qui volent vers « Mes widgets » (Créer, pas les mini-apps) | `App/Components/SaveFlight.swift:14` |
| `TemplateCard`, `DesignCard`, `WidgetPreview`, `InteractiveBadge` | Cartes de modèle et de widget (cadenas Premium, badge « Interactif »), aperçu de widget : surtout Créer, Store et Mes widgets | `App/Components/UIComponents.swift:22`, `:190`, `:239`, `:334` |
| `SectionIndexBar` | Index alphabétique au bord d'une liste. | `App/Components/SectionIndex.swift:79` |

### 4.4 « À remplir » (`MiniAppToFill.swift:8-20`)

En tête de la feuille. Titre « À remplir » et compteur « n / total » (`:81`). Une carte par information manquante. Une carte donnée s'efface après 1,4 seconde (`:111-128`). Rien ne s'affiche quand tout est donné.

Dessin d'une carte (`DataItemRow`, `DataItemViews.swift:59-99`) : pastille carrée arrondie de 30 à la couleur brute de la zone, titre, une phrase (ce qui est su, ou à quoi ça sert), étiquette ambre « À renseigner » ou coche « Renseigné », puis le moyen de répondre.

| Mini-app | Cartes demandées | Comment on répond (`DataItemViews.swift:103-291`) |
|---|---|---|
| Nutrition | « Objectif calorique », « Objectifs de macros » | Bouton « Calculer mes besoins » (feuille) |
| Fitness | « Programme d'entraînement », « Séances par semaine », « Poids », « Objectif de pas » | « Créer une séance » (feuille) ; puces 1 à 7 ; champ de poids ; puces 6 000, 8 000, 10 000, 12 000 et « Afficher mes pas » |
| Planning | « Habitudes », « Cours et horaire » | Champ « Ex. : méditer, lire, marcher » ; « Nouveau cours » puis « Ajouter un horaire » (feuilles) |
| Études | « Examens » | « Nouvel examen » (feuille) |
| Business | « Objectif de chiffre d'affaires » | Champ « Chaque mois » |
| Voyage | « Voyage » | « Nouveau voyage » (feuille) |
| Auto | « Ta voiture » | Champs « Marque et modèle » et « Compteur » |
| Photos et citations | aucune | |

(Libellés : `App/Core/DataItems.swift:81-117`. Règle « donné ou non » : `isFilled`, `DataItems.swift:339-377`.)

À savoir :
- La carte « Habitudes » ouvre l'offre Premium à la 4e habitude d'un compte gratuit (`DataItemViews.swift:145-150` ; limite `App/Core/AppModel.swift:13`).
- Une carte déjà remplie montre un second lien pendant le court moment où elle reste : « Tout voir » (ancien écran de données de l'espace) ou « Gérer mes habitudes » (feuille `HabitsView`) (`DataItemViews.swift:151`, `:331-347`). À vérifier sur l'iPhone.

### 4.5 « Mes paramètres » (`MiniAppSettings.swift:11-53`, `:135-209`)

Un bouton en bas de page, qui ouvre une feuille. Dans l'ordre : la ligne du rappel, les questions du sujet, « Réglages communs » (« Pour toute l'app. »), « Tes données », puis la note « Les mêmes infos partout : modifiées ici, elles le sont dans « Mes informations », tes autres mini-apps et tes widgets. » (`:192-194`). Un changement ici vaut partout.

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

« Devise » : 5 choix, CAD, USD, EUR, GBP, CHF (`Shared/Model/Settings.swift:212`).

### 4.6 Comment chaque mini-app emploie le cadre (hors Finance)

| Mini-app | Sélecteur de semaine | Figure du jour | Action principale | « À remplir » | Note | « Mes paramètres » |
|---|---|---|---|---|---|---|
| Nutrition | Oui, sans futur (`NutritionApp.swift:50`) | Carte propre `CalorieHero` sur verre (`:52-54`) | 2 boutons en tête : « Scanner », « Rechercher » (`:89-101`) | Oui (`:58`) | Oui (`:65`) | Oui (`:66`) |
| Fitness | Oui, avec futur (`FitnessApp.swift:352`) | `MiniHero` | Flottante : « Commencer », « Reprendre la séance », « Créer une séance », « Rattraper… » (`:144-164`) | Oui (`:38`) | Oui (`:46`) | Oui (`:47`) |
| Planning | Oui, avec futur, aligné sur le tableau (`PlanningApp.swift:42`) | Aucune (`compact: true`, `:39`) | Flottante : « Nouvelle tâche » (`:36`) | Oui (`:44`) | Non | Oui (`:121`) |
| Études | **Non** (`StudiesApp.swift:97-104`) | `NextClassCard` et 2 ou 3 tuiles (`:101-102`) ; une carte de départ tant qu'il n'y a ni cours, ni examen, ni devoir (`:98-99`) | Ni flottante ni rangée de boutons (`:97`, `:105-110`) | Oui (`:105`) | Non | Oui (`:110`) |
| Business | Oui, sans futur, même sans donnée (`BusinessApp.swift:134`) | `MiniHero` et choix de période (`:204-210`) ; texte de départ sans donnée (`:165-175`) | 2 boutons : « Vente », « Dépense » (`:156-163`) | Oui (`:143`) | Non | Oui (`:150`) |
| Voyage | Seulement s'il y a un voyage (`TravelApp.swift:67-75`) | `TripHero` (`:312`) | Flottante : « Nouveau voyage » ou « Ajouter » (`:120`, `:125`) | Oui (`:77`) | Non | Oui (`:91`) |
| Auto | Seulement s'il y a des données (`CarApp.swift:79-86`) | `MiniHero` | 2 boutons : « Plein », « Kilométrage » (`:90-95`) | Oui (`:88`) | Non | Oui (`:103`) |
| Photos et citations | **Non**, rien de daté (`PhotoQuotesApp.swift:21`) | `MiniHero` (`:22`) | 2 boutons : « Photos », « Citation » (`:26-36`) | Non | Oui (`:79`) | Non |

Ce que veut dire le point du sélecteur, par mini-app : Nutrition, point plein dès qu'un aliment est noté (`NutritionApp.swift:235-240`) ; Fitness, plein = séance faite ou rattrapée, creux = prévue (`FitnessApp.swift:352-357`) ; Planning, plein = tout est coché, creux = quelque chose est prévu (`PlanningApp.swift:133-138`) ; Business et Auto, creux = quelque chose est noté ce jour-là (`BusinessApp.swift:180-183` ; `CarApp.swift:80-81`) ; Voyage, creux = programme ce jour-là (`TravelApp.swift:69-70`).

### 4.7 Couleur d'accent par mini-app

La couleur brute du modèle ne change jamais (les widgets la lisent). À l'écran elle est traduite par la palette (`Shared/Theme/CristalPalette.swift:133-170`) : `category` pour une icône ou un graphique, `strong` pour du texte et les boutons pleins. Sept HEX ont une base adoucie connue (`:179-182`) ; les autres partent du HEX lui-même (`:173-177`).

| Mini-app | HEX du modèle | Dans l'app, Saphir clair : icône | Dans l'app : forte | Sur les planches (`base/planches.js:29`) | Source |
|---|---|---|---|---|---|
| Nutrition | `F08A24` | `#C36F25` | `#A75F1F` | les mêmes | `docs/design/2026-11-15-cristal/palettes.md:26-28` |
| Fitness | `E5484D` | `#DF5661` | `#BF4A53` | les mêmes | idem |
| Planning | `3366FF` | `#4385DB` | `#3A72BC` | les mêmes | idem |
| Habitudes | `7FA33A` | `#49961D` | `#3F811A` | les mêmes | idem |
| Voyage | `12A4B5` (= Pas) | `#1E929F` | `#1A7D88` (recalculé ici) | `#1E929F` / `#1B7D88` | `CristalPalette.swift:179-182` |
| Auto | `6B7280` (= Top 3) | `#79849A` | `#687184` (recalculé ici) | les mêmes | idem |
| Études | `D6409F` | `#D6409F` (recalculé ici) | `#C13A8F` (recalculé ici) | **`#DD4DA1` / `#BE428A`** (base « rendez-vous ») | pas de base connue dans l'app |
| Business | `8C6CFF` | `#8C6CFF` (recalculé ici) | `#785DDA` (recalculé ici) | **`#926FE4` / `#7D5FC4`** (base « travail ») | idem |
| Photos et citations | `D9608B` | `#D9608B` (recalculé ici) | `#BA5277` (recalculé ici) | les mêmes | idem |

« Recalculé ici » : la règle de `CristalPalette` a été rejouée à la main (assombrir jusqu'à 3,2:1 sur le panneau, puis 4,6:1 sur blanc). L'arrondi peut différer d'une unité : à vérifier au rendu. Pour Études et Business, **les planches n'ont pas la même teinte que l'app d'aujourd'hui** (`base/GUIDE-PLANCHES.md`, § 6).

### 4.8 Fonctions existantes du socle : liste de référence

Aucune planche ne doit en perdre une.

| N° | Fonction | Où elle est | Gratuit ou Premium | Données affichées | Actions possibles |
|---|---|---|---|---|---|
| F1 | En-tête de l'Accueil : date, avatar, titre selon l'heure | `HomeView.swift:55-78` ; `DailySection.swift:100-123` | Gratuit | Date, « Ta matinée / journée / soirée » | Ouvrir le Profil |
| F2 | Carte Nutrition, 3 vues | `DailySection.swift:575-781`, `:1662-1728` | Gratuit | kcal restantes, 3 macros, repas, 7 jours | « Scanner », ouvrir Nutrition ou l'Historique |
| F3 | Carte Séance, 2 vues | `:808-953`, `:1730-1766` | Gratuit | Séance prévue, en cours, faite, repos ; semaine | « Commencer », « Série faite », pause du repos, « Supprimer la séance » |
| F4 | Carte Planning | `:959-1068` | Gratuit | Tableau de la semaine | Ouvrir Planning, « Relier le calendrier Apple » |
| F5 | Carte Habitudes | `:1070-1210` | Gratuit | Faites/total, série, derniers jours | Ouvrir la page Habitudes |
| F6 | Carte Top 3 | `:1360-1465` | Gratuit | 3 tâches | Cocher, ajout rapide, « Mes tâches réalisées » (y remettre une tâche), ouvrir Planning |
| F7 | Carte Budget | `:1242-1284` | Gratuit | Par jour, dépensé aujourd'hui, courbe 7 jours | Ouvrir Finances |
| F8 | Carte « À ne pas oublier » | `:1286-1358` ; `DailyBrief.swift:550-593` | Gratuit | 4 échéances, tâches à faire | Ouvrir la page de chaque ligne |
| F9 | Carte Pas, 2 vues | `:1212-1240`, `:1768-1790` | Gratuit | Pas du jour, objectif, 7 jours | Ouvrir la page Activité |
| F10 | Cartes « un chiffre » : Études, Business, Voyage, Auto | `:448-457` ; `MiniAppsRow.swift:64-111` | Gratuit | Une ligne des données | Ouvrir la mini-app |
| F11 | Cartes vides et état vide global, jamais de faux chiffre | `:1491-1581`, `:332-353` | Gratuit | Invitation, « Ajouter » ; « Complète tes informations… » | Ouvrir la mini-app à remplir (la première où il manque quelque chose, `:45-52`) |
| F12 | Vues à balayer, vue gardée | `DailyPager.swift:45-136` | Gratuit | Points dans l'en-tête | Balayer |
| F13 | Mode Organiser | `DailyEditMode.swift:78-193` ; `DailyHoldToMove.swift` | Gratuit | Cartes qui tremblent | Déplacer, + / −, croix, « OK » |
| F14 | Retirer une carte (les données restent) | `DailyCategories.swift:122-129` | Gratuit | — | « Retirer de Mon Quotidien » |
| F15 | Ajouter une catégorie par le « + » | `DailySection.swift:1585-1658` | Gratuit | Catégories absentes | Ajouter |
| F16 | Feuille « Mon Quotidien » | `DailyLayoutEditor.swift:6-180` | Gratuit | « Sur l'Accueil », « Masquées », « Catégories » | Ordre, « ½ / Large », œil, « Disposition automatique » |
| F17 | Ordre et tailles par défaut, migration unique | `DailyDefaults.swift:11-33` | Gratuit | — | — |
| F18 | Signe doré « Premium » et bandeau « Ardane Premium » | `DailySection.swift:1794-1823` ; `HomeView.swift:171-199` | Visible sans Premium | — | Ouvrir l'offre |
| F19 | « Mes informations » : carte et page | `MyInfoCenter.swift:4-66`, `:151-217` | Gratuit | Complétude, domaines, « À compléter », « Général » (calendrier) | Ouvrir une mini-app ou l'écran E15, choisir ses intérêts ; sans intérêt, carte « Personnalise Ardane » et « Choisir mes centres d'intérêt » (`MyInfoCenter.swift:81-101`) |
| F20 | Actions VoiceOver des cartes | `DailyEditMode.swift:197-213` ; `DailyPager.swift:106-107` | Gratuit | — | Déplacer avant / après, Agrandir, Rétrécir, Organiser…, Vue suivante / précédente |
| F21 | Cadre de l'écran principal : nappe, en-tête, feuille, couleur d'action | `MiniAppScaffold.swift:30-95` | Gratuit | — | — |
| F22 | Sélecteur de semaine, titre de semaine et point du jour (plein, creux, rien) | `WeekSelector.swift:23-181` ; `WeekViews.swift:5-32` | Gratuit | 7 jours, un point par jour | Choisir un jour, changer de semaine (flèches ou balayage), « Aujourd'hui » (hors aujourd'hui) |
| F23 | Figure essentielle sur verre | `MiniAppScaffold.swift:125-155` | Gratuit | Le chiffre du jour | — |
| F24 | Action flottante | `MiniAppScaffold.swift:99-122` | Gratuit | — | L'action principale |
| F25 | « À remplir » | `MiniAppToFill.swift:41-129` ; `DataItemViews.swift:46-291` | Gratuit (la carte « Habitudes » suit la limite gratuite de 3) | Informations manquantes, « n / total » | Donner chaque information |
| F26 | « Mes paramètres » | `MiniAppSettings.swift:63-209` | Gratuit | Réponses, « Réglages communs », « Tes données », rappel | Modifier, ouvrir « Rappels intelligents » |
| F27 | Composants de contenu (titre de section, lignes, tuiles, boutons, note) | `MiniApp.swift:249-463` | Gratuit | — | — |
| F28 | Sélecteur de jour et feuille « Choisir une date » | `MiniApp.swift:468-571` | Gratuit | Jour | Veille, lendemain, date, retour à aujourd'hui |
| F29 | Semaine en tableau | `WeekViews.swift:41-564` | Gratuit | Blocs par jour et par heure, ligne « maintenant » | Toucher une heure libre crée, toucher un bloc ouvre |
| F30 | Pages secondaires et routes (47 pages, retour toujours à l'endroit d'avant) | `MiniApp.swift:78-131`, `:231-246` | Gratuit | — | Retour |
| F31 | Explication avant une permission | `PermissionExplainer.swift:64-283` | Gratuit | Pourquoi, ce que l'app ne fait pas | « Continuer », « Plus tard », « Ouvrir Réglages » |
| F32 | Liens profonds et ouverture depuis un widget | `Router.swift:145-178` ; `Shared/Support/DeepLink.swift:4-65` | Gratuit | — | Ouvrir la mini-app de l'espace, le scanner |
| F33 | Couleur de l'app (14 couleurs), clair et sombre | `App/Components/StylePicker.swift:73-110` ; `CristalPalette.swift:187-204` | **Saphir gratuite, 13 couleurs Premium** (toucher une couleur Premium ouvre l'offre « Toutes les couleurs de l'app », `StylePicker.swift:102-109`) | Mini-aperçu par couleur, cadenas doré | Changer la couleur de toute l'app. Où : « Profil et réglages › Apparence » (`ProfileView.swift:87-92`), à l'inscription (`OnboardingView.swift:353`) et une fois pour les anciennes installations sans choix (`ArdaneApp.swift:162-166`, `:241-242`) |
| F34 | Retour à l'appui, anti double appui, cibles de 44 points | `Pressable.swift:6-43` ; `AccessibilityHelpers.swift:8-17` | Gratuit | — | — |
| F35 | Mode d'affichage « Auto » / « Clair » / « Sombre » | `StylePicker.swift:113-126` ; `ProfileView.swift:88` ; `OnboardingView.swift:354` | Gratuit | Mode choisi | Changer le mode |
| F36 | Barre d'onglets : « Accueil », « Créer », « Store », « Mes widgets » (l'Accueil est actif dans toute mini-app ouverte depuis Mon Quotidien) | `App/ArdaneApp.swift:294-319` | Gratuit | — | Changer d'onglet |
| F37 | Écrans de données sans mini-app : Placements, Sociétés cotées, Ma vie (E15) | `SpaceView.swift:74-89` ; `MoneySpaces.swift:5`, `:325` ; `TravelCarLifeSpaces.swift:510` | Gratuit (aucun test Premium relevé) | Portefeuille, entreprises suivies, anniversaire, jours fériés, lune | Ajouter, modifier, supprimer un placement ; suivre une entreprise ; régler l'anniversaire |

**37 fonctions, dont 1 avec une part Premium (F33).** Le signe doré et le bandeau (F18) ne sont visibles que sans Premium mais ne verrouillent rien. Limites du mode gratuit qui touchent le socle : 3 habitudes et 3 widgets (`AppModel.swift:12-13`).

## 5. Style Cristal Équilibrée et C1 Atelier : jetons et règles pour les planches

Sources : `docs/design/2026-11-15-cristal/GUIDE.md` (règles des planches), `GUIDE-CODE.md` (règles SwiftUI), `README.md`, `cristal.css`, `cristal.js`, `palettes.md`, planches `03` à `09` (7 écrans chacune, sauf `08` : 12 et `09` : 6).

### 5.1 Le système en cinq règles (`README.md:32-37`)

1. Fond clair avec deux nappes de couleur floues.
2. Le contenu est sur des panneaux presque opaques. Le verre est réservé à ce qui flotte.
3. Une seule couleur d'action par écran. Les couleurs des mini-apps ne servent qu'aux icônes et aux graphiques.
4. Dans une mini-app, une nappe de sa couleur éclaire le haut de la page et la couleur d'action devient la sienne.
5. Un état ne repose jamais sur la couleur seule (toujours un mot, une coche, un texte barré).

### 5.2 Jetons de la déclinaison Saphir, en clair (`palettes.md:21-30` ; `CristalPalette.swift:37-39`)

| Jeton | Valeur |
|---|---|
| Fond | `#EEF3FA` |
| Nappes | `#BFEAF2` et `#C9D8FB` |
| Panneau | `#FFFFFF` à 80 % (`.pn` ; `Cristal.swift:52`) |
| Verre | `#FFFFFF` à 55 % avec flou (`.gl` ; `Cristal.swift:73-74`) |
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
- Graphiques : `data-u="ring|meter|bars|spark|week|dots7|hab|wsel"` (`cristal.js:5`).
- Page d'une mini-app : `<div class="phone app t-saphir" data-c="…" data-time="13:20" data-tab="0">` (`cristal.css:227-229`).
- Clés `data-c` de Cristal : `nut`, `fit`, `pla`, `hab`, `bud`, `pro`, `pas`, `prot`, `gluc`, `lip` (`cristal.js:78`). Clés ajoutées pour cette mission, sans toucher à Cristal : `etu`, `ent`, `voy`, `aut`, `pho` (`docs/design/2026-11-17-mini-apps/base/planches.js:29`). Le dossier `base/` est présent sur le disque mais pas encore versionné au 2026-11-17.

### 5.5 Règles de contenu (`GUIDE.md:21-29`)

- Rien d'inventé. Chaque bloc vient du relevé, avec ses libellés exacts.
- Étiquettes de légende : `Existe` (`.tag.e`), `À adapter` (`.tag.a`), `À développer` (`.tag.d`).
- Aucune fonction existante ne devient un décor.
- Français du Canada : « 412 $ », « 21,68 $ », « 14:00 », « 1 122 » ; repas Déjeuner, Dîner, Souper, Collation ; guillemets « ».
- Une seule journée d'exemple : jeudi 12 novembre, avatar « M », 13:20 par défaut (ou 08:10, 19:05). Chiffres de `DAY`, `EVENTS`, `HABITS`, `TOP3`, `REMIND` (`cristal.js`).
- Thème clair, `t-saphir`. Aucune ressource du réseau. Le guide dit « Thème clair seulement » (`GUIDE.md:26`), mais `cristal.js` sait dessiner le sombre (classe `.dk` sur `.phone`, `cristal.js:83-112`) et la planche `12-sombre.html` existe : à ne pas employer sans décision du PDG.
- Vrais exports de widgets : `<img data-w="NOM">`, liste fermée dans `GUIDE.md:27` (par exemple `calories-m-light`, `todaysWorkout-m-light`, `habits-m-light`, `weekView-m-light`, `priorities-s-light`, `budgetLeft-s-light`). Utile pour montrer le lien carte, widget et mini-app.
- Barre d'onglets d'une planche : `data-tab` vaut `0` Accueil, `1` Créer, `2` Store, `3` Mes widgets, ou `none` (`GUIDE.md:45`).

### 5.6 C1 « Atelier » (création et personnalisation)

- Principe : on arrive dans le Studio avec un widget déjà là ; le guide d'ajout vient après l'enregistrement (`docs/memoire/Decisions.md:121`). Planche de référence : `08-creer-atelier.html` (12 écrans).
- Mise en page : une scène d'aperçu en haut (`.stage`), les réglages dessous, un bouton fixe « Enregistrer le widget » (`.fab`).
- Depuis le 2026-11-15, les réglages sont en **trois chapitres** : « Contenu », « Disposition », « Style » (`App/Screens/Editor/StudioComponents.swift:51-69`).
- Création « taille d'abord » : Taille → Catégorie → widget(s) → personnalisation → aperçu et enregistrement. Une création = un seul widget (`Decisions.md:122`, `:136`).
- Outils réels du Studio : Taille, Contenu, Thème, Style, Couleurs, Fond, Bordure, Graphique, Densité, Mes styles. Il n'existe ni Police, ni Forme, ni Ombre, ni Effets (`GUIDE-CREATION.md:45`).
- Pièces CSS : `.stage`, `.tools`, `.sizes`, `.thumbs`, `.dots`, `.wt` (`cristal.css:285-295`).
- Mini-app concernée à coup sûr : « Photos et citations » (elle fabrique des widgets, `PhotoQuotesApp.swift:5-8`). Pour les autres, à décider dans chaque audit.

### 5.7 Interdits

- Du verre pour un bloc de texte long (`GUIDE-CODE.md:15`).
- Une deuxième couleur d'action sur un écran (`GUIDE-CODE.md:17`).
- Du texte courant en couleur de catégorie (`GUIDE.md:15`).
- Un choix ou un état signalé par la couleur seule (`GUIDE-CODE.md:18`).
- Une cible de moins de 44 points (`GUIDE.md:16`).
- Dessiner ce qui n'existe pas sans l'étiqueter (hydratation chiffrée, météo, fréquence cardiaque, placements dans Finance…) (`GUIDE.md:22` ; `README.md:63-67`).
- Modifier `cristal.css` ou `cristal.js` : le CSS d'une planche va dans son `<style>`, avec un préfixe à elle (`GUIDE.md:46`).
- Changer le rendu des widgets, le badge et le cadenas Premium dorés (`GUIDE-CODE.md:21`).
- Une nouvelle identité graphique par mini-app (mission, section 2).

### 5.8 Écarts entre le guide et le code d'aujourd'hui

- Le guide parle d'une carte « Maintenant » en verre, une par écran (`GUIDE.md:13`). Dans l'app, depuis le 2026-11-16, la carte garde son panneau et « Maintenant » n'est qu'une étiquette (`DailySection.swift:568-572`).
- Le guide dessine les cartes vides en pointillés (`.empty`, `cristal.css:269`). L'app les dessine en panneau plein (`DailySection.swift:1509`).
- La planche `07-habitudes.html` montre « la 6e habitude » comme limite gratuite (`:122-146`). La limite est de 3 depuis le 2026-11-16 (`AppModel.swift:13` ; `Decisions.md:127`).
- La planche `06-planning.html` range Études dans Planning. Elles sont séparées depuis le 2026-11-17 (`Decisions.md:133`).
- Les relevés `inventaire/*.md` datent du 2026-11-15 : antérieurs à ces changements.

## 6. Liens

- **Carte de Mon Quotidien** : voir 3.3 et 3.4 (contenu, largeur, destination de chacune).
- **Widgets** : chaque mini-app a un espace de Créer (`MiniApp.space`, `MiniApp.swift:54-66`), sauf Photos. Toucher un widget ouvre sa mini-app par `tessera://space/<id>` (`Router.swift:168-171`). Un widget de l'espace Habitudes n'a pas de mini-app : il ouvre l'onglet Créer sur cet espace (`Router.swift:172-173`), à vérifier sur l'iPhone.
- **Autres liens profonds** (`DeepLink.swift:4-65`) : `tessera://scan-food` (scanner), `tessera://habits`, `tessera://tasks`, `tessera://money` (feuilles `HabitsView`, `TasksView`, `MoneyView`, `App/ArdaneApp.swift:330-332`), `tessera://calendar`, `tessera://premium`, `tessera://design/<id>`.
- **Entre mini-apps** :
  - mêmes réponses partout par « Mes paramètres » et « Mes informations » (`MiniAppSettings.swift:3-8`) ;
  - le tableau de Planning réunit cours, examens, devoirs, tâches, échéances, séances et calendrier (`Agenda.swift:6-8`) ;
  - « À ne pas oublier » réunit Études, Planning, Finances, Auto et Voyage (`DailyBrief.swift:568-585`) ;
  - un seul objectif pour Fitness et Nutrition (`Decisions.md:134`) ;
  - la page Pas appartient à Fitness, la page Habitudes à Planning ;
  - la carte « Cours et horaire » est demandée par Planning, pas par Études (`MiniAppToFill.swift:12-13`).
- **Notifications et rappels** : ligne du rappel dans « Mes paramètres » pour Fitness (« Rappel de séance »), Nutrition (« Rappel des repas ») et Finances (« Rappel des factures ») (`MiniAppSettings.swift:125-128`). Elle affiche l'heure ou « Désactivé », et ouvre la page « Rappels intelligents » (E12).
- **Tutoriel** : il s'accroche à l'Accueil par `.daily`, `.dailyHeader`, `.dailyNutrition`, `.dailyFitness`, `.profile` (`DailySection.swift:123`, `:250-251` ; `HomeView.swift:69`, `:86-87` ; `App/Screens/Tutorial/Tutorial.swift:109-115`).
- **Parcours testés** (`UITests/`) : `testMonQuotidienOpensAMiniApp` (`MiniAppUITests.swift:580`), `testAMonQuotidienCardShowsAnotherViewWhenSwiped` (`:517`), `testNutritionSettingsAreEditedInPlaceAndTheGenderCanBeChanged` (`:499`), `testDailyEditModeResizesAndEnds` (`HomeLayoutUITests.swift:17`), `testDailyHabitsCardShowsARowOfDaysPerHabitWhenWide` (`:49`), `testDailyEditModeMovesHeldCardsAndScrollsOnSwipe` (`:121`), `testSkippingEverythingShowsNothingMadeUp` (`ProfileUITests.swift:231`), `testMesInformationsShowTheUsersValues` (`:296`), `testMonQuotidienShowsTheDayFromTheUsersData` (`:308`), `testThePremiumSignShowsOnlyWithoutPremium` (`:320`).

## 7. Format des planches Finance à reproduire

Dossier modèle : `docs/design/2026-11-16-finance/` (résumé dans son `README.md`).

### 7.1 Les fichiers

| Fichier | Contenu | Écrans |
|---|---|---|
| `00-analyse.html` | L'existant : 5 captures réelles de la CI annotées (pastilles rouges numérotées), 23 problèmes en 6 familles, tableau des fonctions (gratuit / Premium), ce qu'on garde | 5 captures |
| `01-minimaliste.html` | Direction 1 | 8 |
| `02-tableau-de-bord.html` | Direction 2 | 9 |
| `03-analytique.html` | Direction 3 | 8 |
| `04-quotidienne.html` | Direction 4 | 8 |
| `05-hybride.html` | Direction 5 | 9 |
| `06-comparaison.html` | Notes, avantages et limites, recommandation, questions, étape 2 | — |
| `finance.css` | Pièces propres à la mini-app, préfixe `fn-` | |
| `finance.js` | Objet `F` (mise en forme, graphiques, morceaux d'écran), données `FIN`, liste `FEATURES` (19 fonctions, `finance.js:155`), `F.mapNote` | |
| `render.py` | Rendu PNG, planche-contact JPG, découpe des téléphones | |
| `README.md` | Résumé, notes, recommandation, questions, limites | |

Total : 42 écrans pour les 5 directions (8 ou 9 par direction, comptés dans les fichiers). La mission demande au moins 5 types d'écran par proposition (principal, sections et accès, détail d'une fonction, gestion ou personnalisation, vue secondaire).

### 7.2 Structure d'une planche de direction (`05-hybride.html:46-146`)

1. `<body style="--bw:1860px">` : 4 téléphones par rangée.
2. En-tête `.bd-head` : le numéro (`.num`), le titre « Direction N · Nom », une phrase, le badge « Étape 1 · conception · données d'exemple ».
3. Un bandeau de 4 cases (`.fn-rule`) : « La logique », « En ouvrant Finance », « En faisant défiler », « Forces et limites », avec des priorités P1, P2, P3.
4. Des rangées (`.row`) de colonnes (`.col`). Chaque colonne : le nom de l'écran (`.nm`, « 1 · Page principale »), le téléphone (`.phone app … t-saphir`, `data-c`, `data-time="13:20"`, `data-tab="0"` ou `none` pour une feuille), une flèche vers l'écran suivant (`<span class="flow">`, 6 par planche), puis la légende (`.cap`) : un titre, une phrase, et des lignes étiquetées « Existe », « À adapter », « Nouveau ».
5. Une case large « Ce que la direction prend ou laisse » (`:129`), avec les nouveautés à développer et le rappel « Gratuit / Premium ».
6. En dernier, la table **« Rien n'est retiré : où se trouve chaque fonction existante »** (`F.mapNote`, `finance.js:176-179`) : sur deux colonnes, chaque fonction de `FEATURES`, son accès (G = gratuite, P = Premium), et l'endroit où elle se trouve dans cette direction.

Les nouveautés sont aussi marquées dans l'écran (jeton violet « Nouveau », `README.md:18`).

### 7.3 La planche de comparaison (`06-comparaison.html`)

- Un tableau de notes : 10 critères en lignes, 5 directions en colonnes ; dans chaque case, une note sur 10 et une raison de quelques mots ; total sur 100 ; la direction conseillée est marquée (`:128-146`).
- « Avantages et limites » : une carte par direction (`:76`).
- « Ma recommandation », « Les questions pour le PDG », « Étape 2 proposée (après ton choix) », « Ce qui ne change dans aucune direction » (`:80-115`).
- **Critères de Finance** (`:130-139`) : Lisibilité, Simplicité, Hiérarchie, Rapidité d'accès, Graphiques, Richesse fonctionnelle, Confort quotidien, Cohérence avec Ardane, Esthétique, Potentiel d'évolution.
- **Critères demandés par la nouvelle mission** (section 6) : Lisibilité, Simplicité d'utilisation, Hiérarchie des informations, Rapidité d'accès aux fonctionnalités, Qualité de l'expérience quotidienne, Richesse fonctionnelle, Cohérence avec Ardane, Qualité esthétique, Facilité de compréhension pour un nouvel utilisateur, Potentiel d'évolution. La différence : « Graphiques » laisse sa place à « Facilité de compréhension pour un nouvel utilisateur ». Les nouvelles planches suivent la liste de la mission.

### 7.4 Rendu et sorties (`README.md:35-42`)

- Commande : `~/ardane-tools/venv/Scripts/python.exe -I render.py NN-nom.html --phones`, puis `--query check` (texte coupé entouré de rouge). Deux passes au moins.
- Sorties hors dépôt, dans `pub/rapports/design-…/` : `NN-nom.png`, `NN-nom-contact.jpg`, `ecrans/NN-nom-01.png…`, et un PDF qui réunit tout.
- Limites à redire sur chaque livraison : maquettes en Inter (SF Pro sur l'iPhone), grandes tailles de texte et mode sombre non dessinés, notes de jugement sans test avec des utilisateurs (`README.md:21`, `:44-47`).

### 7.5 La boîte à outils de cette mission (`docs/design/2026-11-17-mini-apps/base/`)

Présente sur le disque le 2026-11-17, pas encore versionnée. Elle reprend le format Finance pour tous les sujets (`base/GUIDE-PLANCHES.md`) :
- fichiers : `planches.css` (préfixe `pl-`), `planches.js` (objet `PL`), `render.py`, `GABARIT-direction.html`, `GABARIT-analyse.html`, `GABARIT-comparaison.html`, `CATALOGUE.html` ;
- par sujet : `00-analyse.html`, `01-…` à `05-…`, `06-comparaison.html`, `<sujet>.js` avec la liste `FONCTIONS`, `README.md` ;
- 6 à 9 écrans par direction ; table de fin par `PL.mapTable` ; les 10 critères de la mission dans `PL.CRITERES` (`planches.js:100`) ;
- étiquettes : « Existe », « À adapter », « Nouveau », et une étiquette de passage « → Écran N » ;
- badge de l'en-tête : « Phase 2 · conception · données d'exemple ».

## 8. Incohérences constatées entre mini-apps (faits)

1. **Habitudes n'est pas une mini-app.** C'est une page de Planning, hors du cadre commun : pas de nappe, pas de « Mes paramètres », un sélecteur de jour au lieu du sélecteur de semaine, un grand titre (`Planning/PlanningPages.swift:346-398`).
2. **La carte Habitudes mène à deux endroits.** Remplie : la page Habitudes (`DailySection.swift:1088`). Vide : l'écran principal de Planning (`DailyBrief.swift:245` ; `DailySection.swift:22`).
3. **Deux verts pour Habitudes.** `5C8424` sur la carte remplie (`DailySection.swift:1088`) ; `7FA33A` partout ailleurs (`KindCatalog.swift:64` ; `PlanningApp.swift:114` ; `PlanningPages.swift:366` ; `DailyLayoutEditor.swift:169`). Seul `7FA33A` est connu de la palette (`CristalPalette.swift:179`).
4. **Top 3 a trois visages.** Carte : « Top 3 », `3.circle.fill`, gris `6B7280` (`DailySection.swift:1371`). Carte vide et liste du « + » : « Productivité », `checklist` (`DailyBrief.swift:176`, `:193` ; `KindCatalog.swift:12`, `:46`). Feuille d'organisation : « Top 3 », `star.fill`, ambre `F5A524` (`DailyLayoutEditor.swift:173`). L'intérêt du même domaine s'affiche « Planning » (`Shared/Domains/Profile.swift:24`).
5. **La carte Séance ne porte pas le nom de sa mini-app.** Carte : « Séance », « Séance du jour » ou « Sport », icône `figure.strengthtraining.traditional` (`DailySection.swift:824`, `:913-919`). Carte vide et mini-app : « Fitness », `dumbbell.fill` (`DailyBrief.swift:173` ; `MiniApp.swift:12`, `:26`).
6. **Budget ou Finances.** Carte « Budget » (`DailySection.swift:1250`), mini-app « Finances » (`MiniApp.swift:15`). Vert `2F8F7A` sur la carte, `2B9A66` dans la feuille d'organisation (`DailyLayoutEditor.swift:171`).
7. **« À ne pas oublier » change de couleur.** Gris `4B5563` sur la carte (`DailySection.swift:1292`), rouge `E5484D` dans la feuille d'organisation (`DailyLayoutEditor.swift:172`).
8. **Planning a deux icônes.** `calendar` pour la mini-app (`MiniApp.swift:27`), `calendar.day.timeline.left` pour la carte (`DailySection.swift:984` ; `DailyBrief.swift:206`).
9. **Business a deux couleurs et deux noms.** Violet `8C6CFF` et « Business » pour la mini-app (`MiniApp.swift:16`, `:44`) ; or `C28A12` et « Mon entreprise » pour l'espace (`KindCatalog.swift:18`, `:69`) ; or aussi pour l'intérêt « Business » (`Shared/Domains/Profile.swift:21`, `:63`).
10. **Auto a deux gris et deux noms.** `6B7280` et « Auto » pour la mini-app (`MiniApp.swift:18`, `:46`), `4B5563` pour l'espace (`KindCatalog.swift:73`), « Automobile » pour l'intérêt (`Profile.swift:26`). `6B7280` est aussi le gris de Top 3.
11. **Voyage et Pas ont la même couleur**, `12A4B5` (`MiniApp.swift:45`, `:347`).
12. **Études a deux noms.** « Études » pour la mini-app (`MiniApp.swift:14`), « Planning · études » pour l'espace, donc pour sa ligne dans « Mes informations » (`KindCatalog.swift:20` ; `App/Core/DataItems.swift:10`). Vu sur la capture `profile-home-info.png`.
13. **Le sélecteur de semaine n'est pas partout.** La règle dit « en tête de chaque mini-app » (`WeekSelector.swift:15`). Études n'en a pas (`StudiesApp.swift:97-104`). Photos non plus (`PhotoQuotesApp.swift:21`). Voyage et Auto ne l'affichent qu'avec des données (`TravelApp.swift:67-75` ; `CarApp.swift:79-86`).
14. **La figure du jour a quatre formes.** `MiniHero` (Fitness, Business, Auto, Photos, Voyage par `TripHero`), une carte propre sur verre (Nutrition, `NutritionApp.swift:52-54`), une carte et des tuiles (Études, `StudiesApp.swift:101-102`), rien (Planning, `PlanningApp.swift:39`).
15. **L'action principale a trois formes.** Flottante dans Fitness, Planning et Voyage (`FitnessApp.swift:34` ; `PlanningApp.swift:36` ; `TravelApp.swift:66`). Deux boutons en tête de feuille dans Nutrition, Business, Auto et Photos (`NutritionApp.swift:89-101` ; `BusinessApp.swift:156-163` ; `CarApp.swift:90-95` ; `PhotoQuotesApp.swift:26-36`). Aucune des deux sur l'écran principal d'Études (`StudiesApp.swift:97`).
16. **La taille du titre change en entrant dans une page.** Petit titre sur l'écran principal (`MiniAppScaffold.swift:75`). Grand titre sur 25 pages secondaires hors Finance (Études 6, Auto 5, Planning 4, Fitness 4, Nutrition 3, Business 3, comptés dans les fichiers). Petit titre sur les 3 pages de Voyage (`Travel/TravelPages.swift`).
17. **Le titre de l'écran n'est pas toujours le nom de la mini-app.** Business et Auto affichent le nom saisi par la personne (`BusinessApp.swift:152` ; `CarApp.swift:105`).
18. **« Mes paramètres » est très inégal.** Absent de Photos. Une seule ligne (« Devise ») dans Voyage. Un rappel dans Fitness et Nutrition seulement, hors Finance (`MiniAppSettings.swift:11-50`, `:125-128`).
19. **Plusieurs dessins de pastille d'icône.** Ronde, couleur traduite par la palette, dans les lignes (36, `MiniApp.swift:285-291`) et les en-têtes de carte (30, `DailySection.swift:490-494`). Carrée arrondie, HEX brut, dans les cartes « À remplir » (30, `DataItemViews.swift:63-67`). D'autres tailles rondes : 32 et 42 dans « Mes informations » (`MyInfoCenter.swift:132-133`, `:232-233`).
20. **Les cartes vides sont dites « pointillées » mais ne le sont pas.** Les commentaires et la feuille le disent (`DailySection.swift:1489`, `:1583` ; `DailyLayoutEditor.swift:7`). Le dessin est un panneau plein (`DailySection.swift:1509`, `:1598`).
21. **L'écran principal de « Photos et citations » n'a aucune entrée visible.** Pas de carte (`DailyCategories.swift:9`) et la rangée « Mes mini-apps » n'est jamais affichée (`MiniAppsRow.swift:137`). Aucun code ne construit la route `.app(.photos)` hors du mode capture. Dans Créer, la catégorie « Photos et citations » ouvre directement le choix « Photos » ou « Citation » puis l'éditeur (`CreateFlow.swift:212-217`, `:228-229`) ; Mes widgets ouvre aussi l'éditeur (`Router.swift:132-133`). À vérifier sur l'iPhone.
22. **La carte « Maintenant » : verre dans le guide, panneau dans l'app** (`GUIDE.md:13` ; `DailySection.swift:568-572`).
23. **La documentation interne est en retard sur le code.** `scripts/graph_map.py:102` liste `MiniApp` sans `studies` ; `:104` parle de « Mes infos » en tête ; `:283` annonce 5 habitudes gratuites (le code dit 3, `AppModel.swift:13`). Les commentaires du code disent « Mes infos » pour le bouton « Mes paramètres » (`MiniAppSettings.swift:3`, `PlanningApp.swift:120`). Le commentaire de `WeekDayMark` décrit cinq dessins qui n'existent pas (`WeekViews.swift:25-26`). La CI photographie encore `app-weather` (`.github/workflows/build.yml:470-472`) et l'étape de tutoriel `info`, retirée (`:414`).
24. **Deux têtes de semaine pour un même but.** Les écrans principaux emploient le `WeekSelector` en verre ; la page Planning « Semaine » emploie `WeekTableCard` (mois et année en gros, flèches, « Aujourd'hui ») (`PlanningPages.swift:183` ; `WeekViews.swift:486-538`). Leurs boutons « Aujourd'hui » n'ont ni la même taille (36 contre 44 points) ni la même règle : l'un paraît quand le jour choisi n'est pas aujourd'hui, l'autre quand la semaine n'est pas la semaine en cours (`WeekSelector.swift:86`, `:95` ; `WeekViews.swift:516`, `:525`).
25. **Le bouton « Aujourd'hui » et les flèches du sélecteur sont sous 44 points.** Cadre de 36 de haut (`WeekSelector.swift:95`) et flèches de 40 × 36 (`:70`, `:80`), contre la règle de 44 du guide. À vérifier à l'écran.
26. **Aucun interrupteur pour la carte Pas** dans la feuille « Mon Quotidien », alors que chaque mini-app a le sien (`DailyLayoutEditor.swift:48-81`) ; Pas est une carte de Fitness sans interrupteur (`DailyCategories.swift:12-20`).
27. **Le choix de la couleur de l'app n'est pas dans Mon Quotidien ni dans une mini-app** : seulement « Profil et réglages › Apparence » (`ProfileView.swift:87-92`).
28. **On agit sur place dans trois cartes, pas dans les autres.** Nutrition (« Scanner », `DailySection.swift:725-727`), Séance (« Commencer », « Série faite », `:839-868`) et Top 3 (cocher, ajouter, `:1374-1418`) agissent sans ouvrir la mini-app. Habitudes et Planning ne sont que des liens (`:1088`, `:984`) : on ne coche pas une habitude depuis sa carte.
29. **L'écran sans donnée n'a pas le même dessin partout.** Carte de départ en panneau dans Études, Voyage et Auto (`StudiesApp.swift:129-142` ; `TravelApp.swift:129-140` ; `CarApp.swift:109-120`). Texte nu, sans panneau, sous un sélecteur de semaine gardé, dans Business (`BusinessApp.swift:134-136`, `:165-175`). Pas de carte de départ dans Nutrition, Fitness, Planning et Photos.
30. **La ligne du rappel ouvre toute la page des rappels.** « Rappel de séance » ou « Rappel des repas » mène à « Rappels intelligents », qui règle toutes les familles de notifications de l'app (`MiniAppSettings.swift:94-96` ; `SmartRemindersView.swift:59-141`).
31. **Les boutons des cartes « À remplir » ne sont pas ceux du cadre.** Rectangles arrondis (rayon 12) de 42 points, puces de 40 (`DataItemViews.swift:324-325`, `:377-378`), contre des capsules de 50 pour `MiniActionButton` (`MiniApp.swift:410-411`). Sous la règle des 44 points : à vérifier à l'écran.
32. **Quatre noms pour les mêmes réponses.** « Mes informations » sur l'Accueil (`MyInfoCenter.swift:13`), « Mes paramètres » en bas d'une mini-app (`MiniAppSettings.swift:73`), « Tes données » dans sa feuille (`:157`), « À remplir » en haut (`MiniAppToFill.swift:81`).
33. **Relier le calendrier : deux libellés.** « Relier le calendrier Apple » sur la carte Planning de l'Accueil (`DailySection.swift:1038`), « Ajouter les événements de mon calendrier » dans Planning (`PlanningApp.swift:69`).
34. **Cinq rayons de panneau.** 26 pour les cartes (palette, `CristalPalette.swift:38`), 22 pour les tuiles (`MiniApp.swift:367-369`), 20 pour les listes de « Mes informations » (`MyInfoCenter.swift:214`), 18 pour les cartes « À remplir » et la tuile « + » de Photos (`DataItemViews.swift:94` ; `PhotoQuotesApp.swift:71`), 12 pour leurs boutons et pour « Ajouter mes informations » (`DailySection.swift:347`).
35. **Le point du sélecteur de semaine n'a pas le même sens partout.** Dans Nutrition, un jour noté a un point plein (`NutritionApp.swift:235-240`). Dans Business et Auto, un jour noté a un point creux (`BusinessApp.swift:183` ; `CarApp.swift:81`), le dessin qui veut dire « prévu » dans Fitness, Planning et Voyage (`WeekSelector.swift:132-138`).
36. **Planning demande une donnée d'Études.** Sa carte « À remplir » « Cours et horaire » crée des cours (`MiniAppToFill.swift:12` ; `DataItemViews.swift:184-193`). Études ne demande que « Examens » (`MiniAppToFill.swift:13`), alors que les cours lui appartiennent depuis le 2026-11-17 (`Decisions.md:133`).
37. **L'action flottante recouvre le contenu qui défile dessous.** Sur la capture `mini-app-planning.png` du run 454, « Nouvelle tâche » cache deux des quatre choix du sélecteur d'échelle. La page ne garde de la place qu'à sa toute fin (`MiniAppScaffold.swift:61`, `:69-73`).

## 9. Ce que la mission du PDG cite et qui n'existe pas

1. **« Habitudes » comme mini-app** (mission, sections 1 et 4.E). Dans le code c'est une page de Planning, une carte et un espace de Créer (section 2.2). Une mini-app Habitudes à part serait « Nouveau ».
2. **« Hydratation »** (mission, 4.A). La mini-app Eau et son widget sont retirés depuis le 2026-10-15 (section 2.3). Aucun écran ni libellé d'hydratation dans `App/` ni `Shared/` ; seul le mot « eau » reste dans un texte de vitrine marketing (`App/Core/MarketingShots.swift`, à vérifier pour la ligne). Le détail est dans l'audit Nutrition.
3. **Trois tailles de carte « Small », « Medium », « Large » dans Mon quotidien** (mission, section 8). Le code n'a que deux largeurs : « ½ » et « Large » (`DailyLayoutRules.swift:8-10`). « Medium » et « Large » ont la même largeur (`DailyDefaults.swift:19-20`).
4. **« Top 3 en Medium sous les petits blocs »** (mission, section 8). Dans le code, Top 3 est 5e, avant les cartes en demi-largeur (`DailyDefaults.swift:11-14`).
5. **« Nutrition, Fitness et Habitudes en Medium », distinctes de Planning « en Large »** (mission, section 8). Dans le code, ces cartes ont toutes la même largeur ; rien ne les distingue par un format (`DailyDefaults.swift:21`). Les tailles Small, Medium, Large existent pour les widgets de l'écran d'accueil, pas pour les cartes de Mon Quotidien.
6. **« Budget selon son format dédié »** (mission, section 8). Il n'y a pas de format à part : Budget est une carte en demi-largeur par défaut, que l'on peut agrandir (`DailyBrief.swift:297-305` ; `DailySection.swift:1242-1284`).

## 10. Captures CI disponibles

- **Aucune image dans `origin/ci-report` aujourd'hui.** La branche est au commit `170618c` (« Build 455 », 2026-11-17 16:07 UTC), identique sur GitHub (`git ls-remote`) : 918 fichiers, tous en `.txt`. Son `report.txt` dit « screenshots: skipped » (run 455, version interne).
- Raison : la branche est refaite à chaque run (`.github/workflows/build.yml:977-1000`). Les images n'y sont qu'après un run avec captures. Seuls les rapports texte gardent un historique (`history/…`).
- **Copie locale des captures du run 454** (`[daily]`, commit `d1de23c`, « screenshots: success ») : `pub/rapports/design-2026-11-17-mini-apps/captures-ci-454/`, 99 images PNG de 1 206 × 2 622, hors dépôt (`pub/` est ignoré par git). Ce sont les captures prises par les tests d'interface. **20 concernent le socle** :
  - Accueil (7) : `profile-home-daily.png`, `profile-home-skipped.png`, `profile-home-after-onboarding.png`, `profile-home-premium-sign.png`, `profile-home-premium-sign-paywall.png`, `profile-home-graphite-light.png`, `profile-home-graphite-dark.png` ;
  - mode Organiser (4) : `profile-daily-edit-launch.png`, `profile-daily-edit-before-drag.png`, `profile-daily-edit-after-drag.png`, `profile-daily-edit-done.png` ;
  - cartes (3) : `profile-daily-habits-wide.png`, `mini-app-daily-swiped.png`, `mini-app-daily-opens-nutrition.png` ;
  - « Mes informations » (3) : `profile-home-info.png`, `profile-info-after-onboarding.png`, `profile-interests.png` ;
  - « Mes paramètres » (1) : `mini-app-nutrition-settings.png` ;
  - tutoriel sur l'Accueil (2) : `profile-tutorial-daily.png`, `profile-tutorial-step-2.png`.
- Dans la même copie, 7 écrans principaux montrent le cadre commun : `mini-app-nutrition.png`, `mini-app-fitness.png`, `mini-app-planning.png`, `mini-app-studies.png`, `mini-app-business.png`, `mini-app-travel.png`, `mini-app-car.png`. Ils sont comptés dans les audits des mini-apps. Aucune capture de « Photos et citations ».
- Ouvertes pour ce relevé : `profile-home-daily`, `profile-home-skipped`, `profile-daily-edit-launch`, `profile-daily-edit-done`, `profile-daily-habits-wide`, `profile-home-info`, `mini-app-nutrition-settings`, `mini-app-studies`, `mini-app-planning`. Les autres : contenu à vérifier.
- Il manque, pour le socle : la feuille « Mon Quotidien » (E3), la feuille « Ajouter une catégorie » (E4), « Mes tâches réalisées » (E5), un compte neuf sans donnée avec ses cartes vides, une carte en demi-largeur de chaque type, « À remplir » dans une mini-app.
- Noms que la CI produit pour ce sujet, quand elle photographie les écrans fixes :
  - `[daily]` (`build.yml:503-508`) : `home-light.jpg`, `home-dark.jpg`, `home-pages-light.jpg`, `home-pages-dark.jpg`, `app-nutrition-settings-light.jpg` et `-dark.jpg`, `app-fitness-settings-light.jpg` et `-dark.jpg` (bas de page, avec « Mes paramètres ») ;
  - `[apps]` (`build.yml:429-473`, `:539`) : `app-<mini-app>-light.jpg`, `app-<mini-app>-<page>-light.jpg`, `app-<mini-app>-end-light.jpg`, `home-apps-light.jpg`, `app-nutrition-fresh-light.jpg` ;
  - `[langs]` (`build.yml:481-486`) : `<langue>-home-fresh-light.jpg`, `<langue>-home-light.jpg`, `<langue>-home-pages-light.jpg`.
- Autres copies locales hors dépôt : `pub/rapports/nuit-2026-11-17/` ; `pub/rapports/design-2026-11-16-finance/` (captures de Finance) ; `C:/Users/Etudiant/ardane-tools/film/public/kit2026/fr/` (captures du 2026-10-31, avant Cristal : repère de contenu seulement).

## 11. Contraintes pour la conception

1. **Conception seulement.** Aucune ligne de l'app ne change avant la validation du PDG (mission, sections 9 et 11).
2. **Rien n'est retiré.** Les 37 fonctions du tableau 4.8 gardent leur place ou une place équivalente. Chaque planche finit par la table « Rien n'est retiré ».
3. **Pas de mini-app inventée.** Huit mini-apps hors Finance, plus Habitudes, à présenter comme ce qu'elle est (une page de Planning) ou, si on en fait une mini-app, étiquetée « Nouveau ».
4. **Ne pas réintroduire dans Planning** les lignes « Semaine », « Mois », « Concentration » et « Études » (mission, 4.C ; `Decisions.md:133`).
5. **Garder la grammaire commune** : sélecteur de semaine en verre, la figure du jour, les sections en panneaux, « À remplir » en tête de feuille, « Mes paramètres » en dernier, une seule action principale. Un seul sélecteur de dates par écran (`WeekSelector.swift:15-22`).
6. **Cristal « Équilibrée »** : fond à deux nappes, panneaux pour le contenu, verre rare, une seule couleur d'action (celle de la mini-app dans sa page, celle de l'app sur l'Accueil), jamais la couleur seule, cibles de 44 points, rayon 26, marges 20.
7. **Les HEX des modèles ne changent jamais** : les widgets les lisent (`GUIDE-CODE.md:16`). Les écarts de nom, d'icône et de couleur de la section 8 se règlent par un choix à présenter au PDG, pas en silence.
8. **Mon Quotidien** : dessiner les cartes dans les deux largeurs réelles (« ½ » et « Large »). Dire sur la planche quel ordre est montré : celui du code (Top 3 en 5e) ou celui de la mission (Top 3 sous les petits blocs). Ce point est à trancher par le PDG.
9. **Même information, mêmes codes aux deux endroits** : la carte de Mon Quotidien et l'écran de la mini-app doivent montrer le même chiffre vedette, le même nom, la même icône et la même couleur. Aujourd'hui ce n'est pas le cas pour Séance, Top 3, Budget, Planning et Habitudes (écarts 3 à 8).
10. **Calculs inchangés** : contenu des cartes (`DailyBrief`), ligne « un chiffre » (`MiniAppSummary.caption`), règles « À remplir » (`isFilled`), limites gratuites (3 widgets, 3 habitudes, `AppModel.swift:12-13`).
11. **Règles gratuit / Premium inchangées** dans toutes les directions. Le badge et le cadenas Premium restent dorés.
12. **Accroches à garder pour l'intégration** : cibles du tutoriel (`.daily`, `.dailyHeader`, `.dailyNutrition`, `.dailyFitness`, `.profile`) et identifiants des tests (`daily-…`, `week-card`, `week-day-…`, `day-switcher`, `mini-to-fill`, `miniapp-settings-edit`, `mini-floating-action`).
13. **Tenir dans l'app réelle** : mode sombre, grandes tailles de texte, « Réduire la transparence » (`Cristal.swift:43`, `:61`), 7 langues dont l'allemand et le japonais (libellés courts).
14. **Même format que Finance** (section 7) : planche 0 d'analyse, 5 planches de direction, 1 planche de comparaison avec les 10 critères de la mission, un README par mini-app. Journée d'exemple du jeudi 12 novembre, 13:20, thème `t-saphir`, français du Canada.
15. **Couleurs de planche** : employer les clés de `base/planches.js` (`etu`, `ent`, `voy`, `aut`, `pho`). Pour Études et Entreprise, la teinte des planches n'est pas celle de l'app d'aujourd'hui (tableau 4.7) : le dire dans la comparaison de ces sujets, comme question au PDG.
16. **Captures** : la planche d'analyse n'emploie que de vraies captures. Celles du run 454 existent en copie locale ; ce qui manque (section 10) demande un nouveau run avec captures, à lancer par le Chef.
