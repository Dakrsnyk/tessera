# Relevé : Finances, Planning + Études, Habitudes

Relevé en lecture seule du code (fait foi), recoupé avec les captures du 2026-10-31 (`kit2026/fr/app-finances-s00/s03/s06/s09/s10`, `app-finances-savings`, `app-planning-s00/s03/s06/s09/tasks/focus/habits`, `hab-0/1`). Sur ces écrans, les captures correspondent au code. Aucune capture des écrans Études ni des pages Finances `bills/categories/trends` (code seul). Tout texte ci-dessous est un `tr("…")` français. « à vérifier » = non confirmé dans le code lu.

## 0. Structure commune (MiniAppScaffold, MiniApp, WeekSelector)

- **Pas de barre du haut maison.** C'est la barre de navigation système : titre inline centré (`navigationTitle` : « Finances », « Planning »), fond masqué (`toolbarBackground(.hidden)`), bouton retour rond (pile Home, pas de bouton Fermer). Aucun bouton réglages en haut : « Mes paramètres » est le dernier bloc de la page (`MiniAppInfoSection`, bouton `.bordered`, `gearshape`, ≥ 44 pt, teinté accent).
- **Accent** (`MiniApp.colorHex`) : Finances `2F8F7A` (jade) ; Planning `3366FF` ; Études `D6409F` (`ScheduleKind.course`) ; Habitudes `7FA33A` (vert, propre à la page). États partagés (`MiniStyle`) : alerte/dépassé `E5484D`, bon/revenu `1E9E75`, pas `12A4B5`. Apple Pay `F2A33A`. Focus `8C6CFF`.
- **Scaffold (Finances et Planning seulement)** : un `ScrollView` en deux étages. (1) En-tête sur une bande d'accent qui remonte sous la barre d'état : dégradé accent opacité 0,34 clair / 0,55 sombre en haut, 0,12 / 0,22 au milieu, transparent en bas. Contient `WeekSelector` + le chiffre essentiel. (2) Feuille en dessous : coins hauts 30 pt continus, remplissage blanc 0,65 clair / blanc 0,045 sombre, ombre en haut, petite poignée capsule 38×4 ; marges 20 pt, espacement vertical 22 pt, hauteur mini 520 pt. Fond d'écran `.screenGradient`.
- **Action flottante** (`MiniFloatingAction`) : capsule accent, hauteur ≥ 50, libellé `.headline`, au-dessus de la barre d'onglets. Planning : « Nouvelle tâche ». Finances : aucune (ses deux actions sont dans la feuille).
- **`WeekSelector`** (seul sélecteur de date) : ligne « ‹ Cette semaine › » (autres libellés : « Semaine dernière », « Semaine prochaine », « Semaine du 28 sept. ») + bouton « Aujourd'hui » hors du jour courant ; 7 pastilles L M M J V S D : initiale, numéro (`.title3` gras), point en dessous (plein = fait/avancé, creux = prévu). Jour choisi = pastille arrondie (blanche en sombre, accent en clair), aujourd'hui = contour, passé normal, futur 0,55. Balayage horizontal = semaine ±1. Finances bloque le futur (`allowsFuture: false`, jours à 0,3) ; Planning l'autorise.
- **Autres pièces partagées** : `MiniSectionTitle` (barre capsule accent 4×16 + `.title3` gras + détail à droite), `MiniRowsCard`/`MiniRow` (carte, icône 36×36 en carré arrondi teinté 0,16, titre, détail `.caption`, valeur `.subheadline` gras, chevron), `MiniStat` (tuile : titre `.caption`, valeur `.title3` gras), `MiniActionButton` (rayon 16, min 50), `MiniFootnote`, `MiniHero`. Rayons : carte 20, tuile 18. `.card()` / `.miniCard()` = fond `.cardFill`.
- **« À remplir »** en tête de feuille (`MiniAppToFillSection`) : cartes de données manquantes, `x / y`, disparaît quand tout est rempli. Finances : budget mensuel ; Planning : habitudes, horaire, examens.
- Les sous-pages ne sont pas des onglets : ce sont des pages poussées (`HomeRoute.page`, `MiniAppPage`). Elles n'utilisent PAS le scaffold (bande + feuille) : `MiniAppScroll` (fond dégradé, marges 20) ou `List` + `.styledList()`, titre large.

---

# PARTIE A : FINANCES

## A1. Page principale, de haut en bas (`FinancesAppView`, `FinancesApp.swift`)

Bande (en-tête) :
1. `WeekSelector` (jours avec opérations marqués d'un point creux).
2. **Héros** (`hero`, id `finances-hero`) : libellé capitales « RESTE CE MOIS-CI » (ou « DÉPASSÉ CE MOIS-CI » si négatif ; « DÉPENSÉ CE MOIS-CI » si aucun budget connu), grand montant 54 pt heavy sans décimales (`1 411 $`), légende « 989 $ dépensés · 12 $ par jour pendant 3 jours » (variantes : « … · dernier jour du mois », « … · N jours avant la fin du mois »). Sans budget : « Budget à définir pour savoir ce qu'il te reste ». Valeurs calculées à la fin du jour choisi.
3. Courbe blanche 40 pt « reste du budget jour par jour » (n'apparaît que si le budget a bougé ; rouge si dépassé).
4. Pastille bouton « Budget 2 400 $ » (ou « Définir mon budget »), ≥ 44 pt → feuille `MonthlyBudgetEditor`.
5. Ligne comparaison (si écart ≥ 1) : flèche + « 230 $ de plus que le mois dernier à la même date » / « … de moins … ».

Feuille :
6. « À remplir » (si besoin).
7. **Deux boutons** (`actions`) : « Dépense » (symbole `minus`, plein accent, id `finances-add-expense`) et « Revenu » (`plus`, doux vert, `finances-add-income`).
8. **Jour choisi** : titre = date longue (« Samedi 31 octobre »), 2 tuiles « Dépenses du jour » (`−12,00 $`) et « Revenus du jour » (vert si > 0), puis liste des opérations du jour (carte) : icône catégorie, titre (note ou nom de catégorie), détail (catégorie ou « Dépense fixe · … »/« Revenu »/« Revenu fixe »), montant `−x,xx $` / `+x,xx $`, marques Apple Pay (`wave.3.right.circle`) et pastille « À vérifier ». Tap = éditeur (ou la facture / montant fixe d'origine).
9. **Ligne « Dépenses Apple Pay automatiques »** (icône ambre) : détail « À configurer » ou « Active · dernière dépense il y a 5 min » → guide `ApplePayGuideView`.
10. **« Ce mois-ci »** (si revenus > 0 ou revenu mensuel du profil) : une ligne « Revenus · ce mois-ci » (ou « prévus (Mes informations) ») + montant, → page Évolution.
11. **Carte « Solde »** (`BalanceChartCard`, `finances-balance`) : titre « Solde » (ou « Solde du compte » si solde de départ) + chevron → Relevé ; montant 34 pt gras arrondi (rouge si < 0) ; segmenté « Mois | 3 mois | Année » ; courbe + aire 170 pt, ligne zéro pointillée, axes dates/montants ; légende (« À partir de 2 000 $ le 1 oct., puis tes revenus et tes dépenses, factures et montants fixes compris. » ou « Revenus moins dépenses depuis le 1 oct., … ») ; bouton « Ajouter ton solde de départ » / « Modifier le solde de départ ».
12. **« Catégories »** (détail = « Octobre 2026 ») : 4 barres max (icône, nom, `395 $ / 500 $`, barre de progression ; rouge si dépassé ; sans barre si pas de limite), lien « Les 6 catégories » / « Détail des catégories » → page Catégories. Masqué si aucune dépense.
13. **« Factures à venir »** (détail « 1 426,98 $ en 14 jours ») : 3 lignes max (icône, nom, « Demain »/« Dans 3 jours », montant 2 décimales ; icône rouge si ≤ 2 jours) → page Factures. Masqué si rien.
14. **« Épargne »** : 2 objectifs max (nom, `43 %` vert, barre, « 2 150 $ sur 5 000 $ · 407 $ / mois d'ici Juin 2027 », « atteint ») → page Épargne. Masqué sans objectif.
15. **Liste de pages** (carte) : « Opérations » (Dépenses et revenus, mois par mois) ; « Catégories », « Factures et abonnements », « Épargne et comptes » (« Valeur nette … »), « Évolution » (Six mois, moyennes et comparaisons) : ces 4 lignes n'apparaissent que si le bloc correspondant (12 à 14, 10) est masqué ; « Dépenses fixes » (« 1 728 $ par mois ») toujours → `MoneyView`.
16. Note : « Ardane ne se connecte à aucune banque : tout vient de ce que tu notes. Ce sont des repères, pas des conseils financiers. »
17. « Mes paramètres » (devise, questions argent, « Revenus et dépenses fixes »).

## A2. Segments internes et sous-pages

- Segmenté du solde : Mois / 3 mois (Premium) / Année (Premium). Segmenté « Type » : Dépenses / Revenus (Opérations).
- **Opérations** (`FinancesTransactionsPage`, List, titre large) : `MonthSwitcher` capsule (‹ Octobre 2026 ›, cadenas si mois verrouillé), segmenté Dépenses/Revenus, menu filtre catégorie (« Toutes les catégories », total en gras), sections par jour (date longue), lignes avec icône catégorie, note, montant ; bouton `+` en haut à droite (« Nouvelle dépense » / « Nouveau revenu »). Revenus : « Total du mois » en vert.
- **Relevé** (`FinancesStatementPage`, via tap sur Solde) : en-tête solde 34 pt + légende ; sections « Aujourd'hui », « Hier », dates ; chaque ligne = icône ronde 32, titre, détail, montant signé et **solde après l'opération** en dessous (style relevé bancaire) ; première ligne « Solde de départ · Ce que ton compte affichait » ; menu `+` (Nouvelle dépense / Nouveau revenu).
- **Catégories** (`FinancesCategoriesPage`, `MiniAppScroll`) : `MonthSwitcher`, **anneau (donut)** 220 pt avec « 1 234 $ / dépensés » au centre, liste des catégories (barre + « 105 $ restants · 23 % du mois » / « Dépassé de 20 $ » / « Sans limite »), « Nouvelle catégorie » ; note « Touche une catégorie pour changer son nom, sa couleur ou sa limite par mois. »
- **Factures** (`FinancesBillsPage`, List) : 2 tuiles « Par mois » (« 3 factures ») et « Abonnements » (« par mois ») ; section « Prochaines échéances » (icône, nom, « Abonnement · mensuel · Demain », montant) ; ligne « Nouvelle facture » ; pied « Loyer, électricité, Internet, abonnements : Ardane te rappelle la prochaine date et le total par mois. »
- **Épargne** (`FinancesSavingsPage`, `MiniAppScroll`, titre large « Épargne ») : « Objectifs d'épargne » (détail = total épargné), lignes `GoalProgressRow`, « Nouvel objectif » ; « Comptes » (détail « valeur nette 10 600 $ »), courbe de valeur nette 150 pt (≥ 2 points), lignes de compte (`building.columns.fill` ; dette = `creditcard.fill` rouge, « Dette », `−x $`), « Nouveau compte ou dette » ; notes « Touche un objectif pour y ajouter un versement ou le supprimer. » et « Saisis tes soldes à la main : Ardane ne se connecte à aucune banque. … »
- **Évolution** (`FinancesTrendsPage`, Premium) : « Six derniers mois » (ou « Par mois ») barres Revenus (vert) / Dépenses (accent 0,55) 210 pt ; « Moyenne par mois » (3 tuiles : Dépenses, Revenus, « Mis de côté » + « % des revenus ») ; « Par rapport au mois dernier » (« à la même date », 6 lignes `270 $ → 340 $`, `+70 $` rouge/vert) ; note « Moyennes calculées sur les mois terminés où tu as noté quelque chose. »
- **Dépenses fixes** = `MoneyView` (titre « Revenus et dépenses », List système, pas le style Signature) : solde net depuis le jour, « Par jour » / « Par mois », sections Revenus et Dépenses, « Ajouter un revenu/une dépense », réglages « Début du calcul », « Devise ».
- **Guide Apple Pay** (feuille) : statut (« À configurer »/« Active »), 6 étapes Raccourcis, bouton « Ouvrir Raccourcis », « Comment ça marche », « Règles de commerçants », bouton « OK ».

## A3. Actions et feuilles (`SheetForm`, dans `Spaces/BudgetSpace.swift` sauf mention)

- **Dépense** (`ExpenseEditor`, titre « Dépense » / « Modifier la dépense ») : Montant (+ devise), Catégorie, « Note (facultatif) », Date ; « Supprimer la dépense ». Si Apple Pay/commerçant : `MerchantExpenseEditor` (`FinancesApplePay.swift`).
- **Revenu** (`IncomeEditor`) : Montant, « Source (salaire, contrat, remboursement…) », Date.
- **Facture** (`BillEditor`) : Nom (loyer, Hydro, Netflix…), Montant, Fréquence (Mensuel/Annuel), « Prochaine échéance », « C'est un abonnement », Catégorie (Automatique…).
- **Objectif d'épargne** (`GoalEditor`) : Nom, Objectif, « Déjà épargné », « Date limite », « Ajouter un versement ».
- **Compte** (`AccountEditor`) : Nom, Solde, « C'est une dette ». **Catégorie** (`CategoryEditor`) : Nom, Icône, couleur, « Limite par mois ».
- **Budget du mois** (`MonthlyBudgetEditor`, `FinancesApp.swift`) : Budget + « Ce que tu te permets de dépenser chaque mois… ». **Solde de départ** (`OpeningBalanceEditor`) : Montant (clavier avec signe moins), « Au début du », « Retirer le solde de départ ».
- **Dépense/revenu fixe** (`MoneyItemEditor`, `Content/MoneyView.swift`) : Type, nom, montant, Fréquence (par jour/semaine/2 semaines/mois/an), « Date d'un paiement », catégorie, « Soit par jour / par mois ».
- Les dépenses « rapides » (`QuickExpenseEditor`) existent dans le code mais ne sont pas sur cette page (à vérifier : widgets seulement).

## A4. États vides (textes exacts)

- Aucun budget : « Budget à définir pour savoir ce qu'il te reste » + « Définir mon budget ».
- Jour sans opération : tuiles à `0,00 $`, aucune liste (pas de texte).
- Solde sans donnée : « Note tes revenus et tes dépenses : ton solde s'affichera ici. »
- Opérations : « Aucune dépense notée pour ce mois. » / « Aucun revenu noté ce mois-ci. » (+ « Revenu mensuel indiqué dans « Mes informations » : … »).
- Relevé : « Aucune opération pour l'instant. Note une dépense ou un revenu : il s'affichera ici, avec ton solde après chaque opération. »
- Évolution : « Rien de noté pour l'instant : les mois apparaîtront ici dès la première opération. »
- Blocs 10, 12, 13, 14 : absents (remplacés par les lignes de la liste 15, détails « Loyer, Internet, abonnements… », « Objectifs et valeur nette », « Loyer, assurances, forfaits… »).

## A5. Premium

Gratuit : mois courant + 7 derniers jours. Cadenas/offre : segments « 3 mois » et « Année » du solde (`PaywallContext.financesHistory`, « Tes mois passés ») ; `MonthSwitcher` (cadenas `lock.fill`, « Mois précédents avec Premium ») dans Opérations et Catégories ; Relevé : bouton « Opérations plus anciennes avec Premium » ; page **Évolution** entière : `PremiumLockCard` « L'évolution est dans Premium » + « Découvrir Premium ». Le sélecteur de semaine n'a pas de verrou visible (à vérifier côté `BudgetMath`).

## A6. Existe / n'existe pas

- Budget mensuel : **existe** (un seul, global) + limite par catégorie.
- « À dépenser par jour » : **existe** (légende du héros, « X $ par jour pendant N jours »), pas en grand chiffre.
- Dépensé aujourd'hui : **existe** (« Dépenses du jour »). Dépensé ce mois : **existe** (légende du héros).
- Solde d'un compte : **existe, calculé** (revenus − dépenses depuis un « Solde de départ » saisi à la main) ; **soldes de comptes saisis à la main** aussi (page Épargne). Aucune connexion bancaire.
- Plusieurs comptes : **existe** (liste de comptes + dettes, valeur nette), mais les opérations ne sont pas rattachées à un compte.
- Revenus : **existe** (saisie, fixes, revenu prévu du profil). Épargne et objectifs d'épargne : **existe** (versements manuels, date limite, mensualité nécessaire).
- Autres objectifs financiers (dette à rembourser, achat) : **n'existe pas** (seulement objectifs d'épargne ; une dette est un compte).
- Catégories de dépenses : **existe** (6 par défaut : Épicerie, Restos, Transport, Sorties, Maison, Autre), barres sur l'accueil, **donut** sur la page Catégories.
- Factures à venir : **existe** (14 jours). Abonnements : **existe** (case sur une facture, total mensuel).
- Tendances 3 mois / année : **existe pour le solde** (courbe Premium) ; barres revenus/dépenses sur **6 mois** (Premium), pas de vue année en barres.
- Apple Pay : **existe** (automatisation Raccourcis, aucune import de relevé/CSV dans Finances). Placements/bourse : **n'existe pas**. Multi-devises : **n'existe pas** (une devise de réglage) à vérifier.

## A7. Fichiers → vues

| Bloc | Fichier | Vue |
|---|---|---|
| Page, héros, jour, mois, catégories, factures, épargne, liste | `MiniApps/Finances/FinancesApp.swift` | `FinancesAppView`, `FinancesRow` (privée), `CategoryBar`, `GoalProgressRow` |
| Carte Solde | idem | `BalanceChartCard` (privée) |
| Feuilles budget / solde de départ | idem | `MonthlyBudgetEditor`, `OpeningBalanceEditor` |
| Opérations, Relevé, Catégories, Factures, Épargne, Évolution, sélecteur de mois | `MiniApps/Finances/FinancesPages.swift` | `FinancesTransactionsPage`, `FinancesStatementPage`, `FinancesCategoriesPage`, `FinancesBillsPage`, `FinancesSavingsPage`, `FinancesTrendsPage`, `MonthSwitcher` |
| Apple Pay | `MiniApps/Finances/FinancesApplePay.swift` | `ApplePayGuideView`, `ApplePayMark`, `ReviewBadge`, `MerchantExpenseEditor` |
| Éditeurs | `Spaces/BudgetSpace.swift` | `ExpenseEditor`, `IncomeEditor`, `BillEditor`, `GoalEditor`, `AccountEditor`, `CategoryEditor` |
| Dépenses fixes | `Content/MoneyView.swift` | `MoneyView`, `MoneyItemEditor` |
| Cadre | `MiniApps/MiniAppScaffold.swift`, `MiniApp.swift`, `WeekSelector.swift` | `MiniAppScaffold`, `MiniHero`, `WeekSelector`, `MiniRow…` |

---

# PARTIE B : PLANNING + ÉTUDES

## B1. Page Planning, de haut en bas (`PlanningAppView`, `Planning/PlanningApp.swift`)

Scaffold `compact: true` (bande plus fine), accent `3366FF`, action flottante « Nouvelle tâche » (`plus`, id `planning-new-task`, crée une tâche à l'échéance du jour choisi).

Bande : uniquement `WeekSelector` (futur autorisé), avec `leadingInset` 31 pt pour que les 7 jours tombent au-dessus des 7 colonnes du tableau. Pas de chiffre héros.

Feuille :
1. « À remplir » (habitudes, horaire, examens).
2. **Calendrier** (`PlanningCalendarCard`, id `planning-calendar`) : par défaut **tableau de la semaine** (colonne par jour, lundi d'abord, heures 8 → 18 à gauche, blocs colorés à l'heure, côte à côte si chevauchement, nom + lieu + heure si la place le permet, ligne rouge « maintenant », bande au-dessus pour ce qui n'a pas d'heure : quelques pastilles puis « +1 ») ; sans cadre ni bande de jours (le sélecteur sert d'en-tête). Segmenté **« Jour | Semaine | Mois | Année »** (`planning-scale`, hauteur d'heure 52 pt et heures 6 → 22 pour Jour ; grille mois style Calendrier : jours 32 pt, aujourd'hui = disque accent, jour choisi = anneau, jusqu'à 3 points de couleur ; année = 12 mini-mois, mois courant teinté). Pincement à 2 doigts = changer d'échelle, balayage = période ±1. Note sous le segmenté : « Touche une heure libre pour créer un événement. Pince avec deux doigts pour voir plus ou moins de temps. » (Mois : « Touche un jour pour le voir en détail. … » ; Année : « Touche un mois pour l'ouvrir. … »).
3. **Agenda du jour** (si échelle Mois/Année, ou si des éléments sans heure) : titre « Aujourd'hui » (ou date longue), détail « 4 éléments » ; lignes `AgendaRow` : heure `HH:mm` 24 h ou « Journée » (54 pt), barre de couleur 4×34, titre (barré si fait), détail (« Priorité moyenne », « Séance · environ 16 min »), à droite un rond à cocher (tâches, devoirs) ou le symbole du type (séance). Vide : « Rien de prévu ce jour-là. »
4. Bouton texte « Ajouter les événements de mon calendrier » (`calendar.badge.plus`), seulement sans accès au calendrier Apple.
5. Carte une ligne **« Importer mon horaire »** / « À partir d'une photo ou d'un PDF » (`doc.viewfinder`, id `planning-import-schedule`) → `ScheduleImportView`.
6. **« Top 3 du jour »** (détail « 3/3 ») : lignes à rond 34 pt (tap = fait), titre ; menu contextuel « Retirer » ; si < 3 : champ « Ajouter une priorité » (valider = crée une tâche du jour, à vérifier si elle reste dans la liste Tâches).
7. **« Tâches »** : 3 tuiles cliquables « En retard » (chiffre rouge si > 0), « Aujourd'hui », « À faire » → page Tâches.
8. **Liste de pages** (carte, chevrons) : « Horaire de la semaine » (« Cours, travail, rendez-vous et autres événements », nombre d'entrées), « Études » (rose `D6409F`, « Cours, examens, devoirs, notes et fiches »), « Semaine » (« Tout ce qui t'attend, jour par jour »), « Mois » (« Le calendrier du mois »), « Projets » (« Tâches regroupées par projet », nombre), « Habitudes » (vert `7FA33A`, « Séries et régularité », `3/4` faits aujourd'hui), « Concentration » (violet, « 8 h sur 10 h cette semaine »).
9. « Mes paramètres » (Productivité, Études, format d'heure).

## B2. Onglets/segments et sous-pages

**Il n'y a pas d'onglets Semaine/Mois/Tâches/Habitudes/Focus** : Semaine, Mois, Tâches, Habitudes, Concentration sont des lignes ou tuiles qui poussent des pages. Les seuls segmentés : « Jour | Semaine | Mois | Année » (calendrier) et le filtre des Tâches.
- **Tâches** (`PlanningTasksPage`, List, titre large) : segmenté « À faire | Aujourd'hui | À venir | Terminées » ; champ « Ajouter une tâche » ; sections « En retard », « Aujourd'hui », « Plus tard », « Sans date » (triées par priorité) ; ligne = rond coloré par priorité (basse `3A8DDE`, moyenne, haute ; fait = accent), titre, détail « Ven. 30 oct. · priorité haute » (rouge si en retard) ou « Aujourd'hui 11:00 · chaque jour » ; filtre Aujourd'hui = `DaySwitcher` ; Terminées : « Effacer les tâches terminées ».
- **Semaine** (`PlanningWeekPage`, titre inline) : même tableau + liste du jour (« Libre » si vide). **Mois** (`PlanningMonthPage`) : titre mois 22 pt gras + flèches 44×44, grille, liste du jour (« Rien de prévu. »).
- **Projets** (`PlanningProjectsPage`, List) : sections par projet (pastille, nom, `2/5`, tâches à cocher, « Modifier le projet », pied « Échéance : … »), « Nouveau projet » ; vide : « Regroupe les tâches d'un même projet (un déménagement, un rapport, un voyage) et suis leur avancement. »
- **Concentration (Focus)** (`PlanningFocusPage`) : carte « Lance une session de concentration » + 5 boutons **15 · 25 · 45 · 60 · 90** (« minutes », dernier choix plein violet) ; en cours : « Session en cours », compte à rebours 54 pt, « Arrêter » ; « Cette semaine » (détail `7,8 h / 10 h`), barres minutes par jour 160 pt. Notification de fin. **Pas un Pomodoro** (un seul décompte, ni pause ni cycles).
- **Importer mon horaire** (`ScheduleImportView`, feuille, Premium) : 5 étapes : « Ton horaire » (« Choisir une photo », « Choisir un PDF »), « Lecture de ton horaire… », échec (« Aucun cours trouvé » / « Impossible de lire ce fichier », « Essayer avec une autre photo »), vérification (cours cochables et corrigeables, ajouter ou remplacer), confirmation. Lecture sur l'iPhone.

## B3. Études (page « Études », `StudiesAppView`, `Studies/StudiesApp.swift`)

Pas de scaffold : `MiniAppScroll`, titre large « Études », accent `D6409F`. De haut en bas : (vide) carte « Ton année en un coup d'œil » + « Ajouter un cours » ; sinon `NextClassCard` (« En cours »/« Prochain cours », nom 22 pt, « 09:00–10:20 · salle B-204 · enseignant », barre de progression si en cours) ; 3 tuiles « Moyenne » (`78,5 %`, « 3 notes »), « Étude » (`2 h 30`, « sur 10 h »), « Fiches » (`4`, « à réviser » / « à jour », si fiches) ; `StudyTimerCard` « Chrono d'étude » + bouton « Démarrer » (menu : « Sans cours précis » ou un cours), en marche : chrono, « Annuler », « Terminer et noter » (Live Activity) ; « À rendre » (`2 devoirs`, 3 lignes, « Voir les N devoirs ») ; « Examens » (2 lignes : pastille `J-5`, rouge si ≤ 3 jours, « 31 oct. à 09:00 · salle · 2 h révisé ») ; « Session » (progression % + « fin … ») ; liste « Horaire », « Cours », « Devoirs », « Examens », « Notes », « Révisions ».
Pages : **Horaire** (`StudiesTimetablePage` : navigation de semaine « Cette semaine », grille `TimetableGrid`, liste du jour, « Ajouter un événement » ; vide : « Ton horaire — Cours, travail, rendez-vous… ») ; **Cours** (List : lignes avec barre de couleur, moyenne, « 3 h / semaine » ; « Nouveau cours » ; réglage « Session » Début/Fin) ; **Cours (détail)** (3 tuiles Moyenne / Évalué / Étude, « Objectif : 80 % » + « Il te faut en moyenne **x %** sur les y % qui restent », sections Horaire, Examens, « Devoirs à rendre », Notes, chacune avec « Ajouter … ») ; **Examens** (« Nouvel examen », « À venir », « Passés » ; vide : « Aucun examen noté. Ajoute-les dès que tu connais les dates : le compte à rebours et le temps révisé s'affichent ici. ») ; **Devoirs** (List : « En retard », « Cette semaine », « Plus tard », « Rendus », « Nouveau devoir ») ; **Notes** (« Moyenne générale » 44 pt « Pondérée par les crédits de chaque cours. », « Nouvelle note », « Par cours » barres, « Toutes les notes » ; vide : « Aucune note pour l'instant. Chaque note compte pour un pourcentage de son cours… ») ; **Révisions** (chrono, « Cette semaine » barres + boutons « +25 min / +45 min / +60 min » + stepper « Objectif : 10 h par semaine », « 6 dernières semaines », « Fiches » avec carte de révision « Voir la réponse » → « À revoir » / « Je savais », paquets, « Nouvelle fiche », note répétition espacée).

## B4. Actions et feuilles

- **Nouvelle tâche** (`TaskEditor`, `PlanningApp.swift`) : Titre, Priorité (Aucune/Basse/Moyenne/Haute), « Échéance » + Jour, « À une heure précise » + Heure, « Répéter » (Jamais, Chaque jour, En semaine, Chaque semaine, Chaque mois), Notes, « Supprimer la tâche ».
- **Événement** (`SlotEditor`, `Spaces/StudentSpace.swift`, titre « Nouvel événement »/« Événement ») : Type (Cours, Travail, Rendez-vous, Autre événement), Cours ou Nom, « Quand » (Chaque semaine / Une seule fois), Date ou pastilles jours (`WeekdayPills`), Début/Fin, lieu, couleur, alerte de chevauchement, annulation d'un seul jour. Créé en touchant une heure libre du tableau.
- **Cours** (`CourseEditor`) : Nom du cours, « Enseignant (facultatif) », Crédits, couleur. **Examen** : Titre (intra, final…), cours, « Date et heure », « Salle (facultatif) ». **Devoir** : Titre, cours, « À rendre le », « Rendu ». **Note** : cours, Évaluation, « Note obtenue », « Sur », « Poids dans le cours » (%). **Fiche** : Paquet, « Question ou mot », Réponse. **Projet** : `ProjectEditor` (`Spaces/ProductivitySpace.swift`).
- Toucher un bloc : tâche/examen/devoir/événement de l'horaire = son éditeur ; événement du calendrier Apple = ouvre l'app Calendrier (`calshow:`) ; échéance/séance = va au jour.

## B5. États vides et Premium

Vides : calendrier vide = tableau sans bloc ; « Rien de prévu ce jour-là. » ; Top 3 sans élément = seulement le champ « Ajouter une priorité » ; tuiles Tâches à `0` ; pages ci-dessus (Projets, Horaire, Examens, Notes, Études). Tâches : aucun texte spécifique (listes vides sans section).
Premium : **« Importer mon horaire »** seul (`PaywallContext.scheduleImport` : « Premium lit ton horaire à partir d'une photo ou d'un PDF, sur ton iPhone. Ajouter tes cours et tes événements à la main reste gratuit. », via `PremiumLockCard` dans la feuille). Aucun cadenas dans Études, Tâches, Focus, calendrier.

## B6. Existe / n'existe pas

- Emploi du temps (cours) : **existe** (hebdomadaire ou ponctuel, 4 types, import photo/PDF Premium). Prochain cours : **existe** (`NextClassCard` sur Études uniquement, pas sur la page Planning).
- Examens : **existe** (compte à rebours `J-n`, salle, temps révisé 14 j). Devoirs à rendre : **existe** (à cocher, en retard rouge).
- Notes / moyennes : **existe** (en %, pondérée par crédits ; pas d'échelle GPA ni lettres). Objectifs de travail : **existe** (heures d'étude par semaine, stepper ; objectif de note par cours via stepper `@State` non persisté : à vérifier ; objectif de concentration en h/semaine : où il se règle, à vérifier).
- Minuteur Focus : **existe** (durées 15 à 90, décompte, notification), **pas de Pomodoro**. Chrono d'étude (Études) : **existe**, avec Live Activity.
- Tâches et priorités : **existent** (4 niveaux, échéance, heure, répétition, notes, projets). Top 3 : **existe**. Sous-tâches : **n'existe pas**. Tags : **n'existe pas**.
- Calendrier Apple : **existe en lecture** (permission, événements dans le tableau). Écriture dans Calendrier : **n'existe pas**. Vue mois : **existe** (échelle + page). Vue année : **existe**.
- Fiches de révision : **existent** (répétition espacée).

## B7. Fichiers → vues

| Bloc | Fichier | Vue |
|---|---|---|
| Page Planning, Top 3, tuiles, liste, `AgendaRow`, `TaskEditor`, `PlanningEditors` | `MiniApps/Planning/PlanningApp.swift` | `PlanningAppView`, `AgendaRow`, `TaskEditor` |
| Calendrier + échelles, grille mois, année | `MiniApps/Planning/PlanningCalendar.swift` | `PlanningCalendarCard`, `PlanningMonthGrid`, `MiniMonth`, `CalendarScale` |
| Tableau de semaine | `MiniApps/WeekViews.swift` | `WeekTimetable`, `WeekTableCard`, `WeekTitle`, `WeekDayMark` |
| Tâches, Semaine, Mois, Projets, Habitudes, Concentration | `MiniApps/Planning/PlanningPages.swift` | `PlanningTasksPage`, `TaskRow`, `PlanningWeekPage`, `PlanningMonthPage`, `PlanningProjectsPage`, `PlanningHabitsPage`, `PlanningFocusPage` |
| Import d'horaire | `MiniApps/Planning/ScheduleImportView.swift` | `ScheduleImportView`, `ScheduleImportMerge` |
| Pastilles jours | `MiniApps/Planning/WeekdayPills.swift` | `WeekdayPills` |
| Études (page + sous-pages) | `MiniApps/Studies/StudiesApp.swift`, `StudiesPages.swift` | `StudiesAppView`, `NextClassCard`, `AssignmentRow`, `ExamRow`, `StudyTimerCard`, `StudiesTimetablePage`, `TimetableGrid`, `StudiesCoursesPage`, `StudiesCoursePage`, `StudiesExamsPage`, `StudiesAssignmentsPage`, `StudiesGradesPage`, `StudiesRevisionPage` |
| Éditeurs d'études | `Spaces/StudentSpace.swift` | `CourseEditor`, `SlotEditor`, `ExamEditor`, `AssignmentEditor`, `GradeEditor`, `CardEditor` |
| Sélecteur et tuiles | `MiniApps/WeekSelector.swift`, `MiniApp.swift` | `WeekSelector`, `DaySwitcher`, `MiniStat`, `MiniRow` |

---

# PARTIE C : HABITUDES

Page de Planning (ligne « Habitudes » → `PlanningHabitsPage`), **sans scaffold** : titre large « Habitudes », `MiniAppScroll`, pas de bande d'accent ni de poignée. Il existe une **2e version** : `HabitsView` (List système, `Content/HabitsView.swift`), ouverte depuis Profil, Créer (« Gérer mes habitudes ») et `ArdaneApp` ; elle partage `HabitRow` et `HabitEditor`.

## C1. Page principale, de haut en bas (`PlanningHabitsPage`)

1. `DaySwitcher` (capsule `.cardFill`, teinte `7FA33A`) : ‹ « Aujourd'hui » ▾ › (« Hier », « Demain », sinon date longue), tap = calendrier graphique en feuille (« Choisir une date », « Aujourd'hui », « OK »), flèche retour « Revenir à aujourd'hui » ; **le futur est bloqué** ; seulement s'il y a des habitudes.
2. **Une carte par habitude** (`HabitRow` dans `.miniCard()`, padding 12) :
   - Bandeau gris arrondi (rayon 12) : bouton **rond de validation** 30 pt dans une zone 44×44 (plein couleur + coche blanche si fait, sinon anneau couleur 0,7 et coche 0,5), puis icône SF + **nom**, légende « Série de 12 jours » ou « Pas encore de série », **pourcentage de régularité 30 jours** à droite (`81 %`, masqué avant le 1er jour coché). Tap sur le texte = éditeur.
   - **Grille type contributions** (`HabitHeatmapGrid`) : 26 colonnes (semaines) sur iPhone, 52 en classe de taille régulière, 7 lignes (lundi en haut), un carré par jour, plein = fait, 0,16 = non fait, rien = jour futur.
3. Bouton « Ajouter une habitude » (`plus.circle.fill`, teinte `7FA33A`).
4. **« Régularité »** : sans Premium = `PremiumLockCard` « La régularité est dans Premium » (« Le taux de réussite de chaque habitude sur 30 et 90 jours, et sa plus longue série. Tes jours cochés restent enregistrés. ») ; avec Premium = lignes `chart.bar.fill` (nom, « Meilleure série : 12 jours », valeur « 81 % · 74 % ») + « Compté depuis le premier jour coché, sur 30 et 90 jours. »
- Les couleurs sont par habitude (`colorHex`, défaut `7FA33A` ici, `2F8F7A` dans `HabitsView`). Captures : Méditer violet, Sport corail, Lecture jade.

## C2. Segments et sous-pages

Aucun segment, aucune sous-page de détail : toucher une habitude ouvre l'éditeur. Pas de page statistiques par habitude, pas de vue semaine/mois/année séparée (la grille de 26 semaines en tient lieu).
`HabitsView` (variante List) : `DaySwitcher` en haut, lignes `HabitRow`, bouton « Nouvelle habitude », bouton « Modifier » (`EditButton`, > 1 habitude) pour réordonner et supprimer par balayage ; pied (gratuit) « 3 sur 5 habitudes en version gratuite. »

## C3. Actions

- **Cocher** : tap sur le rond = bascule pour le jour choisi (aujourd'hui ou un jour passé), retour haptique. Accessibilité : « Valider {nom} » / « Marquer {nom} comme non fait ». Un jour coché n'est pas compté, pas de valeur.
- **Ajouter** : « Ajouter une habitude » → `HabitEditor` (feuille, « Nouvelle habitude ») ; **limite gratuite 5** : au-delà, feuille d'offre `habitLimit` (« Plus de 5 habitudes » : « La version gratuite suit 5 habitudes. Avec Premium, suis-en autant que tu veux, sur tes widgets aussi. »).
- **Éditer** (`HabitEditor`, « Habitude ») : section « Nom » (« Méditer, lire, courir… »), « Icône » (grille 5 colonnes de 20 symboles : course, marche, haltères, yoga, cerveau, livre, crayon, goutte, feuille, lit, couvert, tasse, note, pinceau, globe, cœur, soleil, lune, téléphone posé, pièce), « Couleur » (palette `Palette.freeAccents`, pastilles ≥ 44), « Rappel quotidien » (interrupteur + « Heure », demande d'autorisation des notifications avec explication ; refus : « Les notifications sont désactivées pour Ardane dans Réglages. »), « Supprimer l'habitude » (annule le rappel).
- Habitude validable aussi d'une touche depuis le widget (même donnée).

## C4. États vides (textes exacts)

- `PlanningHabitsPage` : carte `EmptyStateView` (`repeat`) « Tes habitudes » / « Lire, marcher, méditer… Coche-les chaque jour et regarde ta série grandir. » / bouton « Ajouter une habitude » ; pas de `DaySwitcher` ni de « Régularité ».
- `HabitsView` : « Aucune habitude pour l'instant » / « Crée une habitude, puis valide-la chaque jour d'une touche sur ton widget. »
- Habitude neuve : « Pas encore de série », pas de pourcentage, grille entièrement pâle.

## C5. Premium

Limite de 5 habitudes (cadenas = feuille d'offre, pas d'icône cadenas dans la ligne) ; bloc « Régularité » (30/90 jours + meilleure série). Une habitude existante reste toujours modifiable.

## C6. Existe / n'existe pas

- **Fréquence** (jours choisis, x par semaine) : **n'existe pas** : toute habitude est quotidienne (modèle `Habit` : nom, symbole, couleur, jours cochés, heure de rappel).
- **Rappel** : **existe** (un seul, quotidien, heure précise).
- **Série** : **par habitude** (jours consécutifs finissant aujourd'hui ou hier, « Série de N jours ») ; meilleure série par habitude (Premium). **Série globale** : **n'existe pas** (sur cette page ; à vérifier dans « Mon Quotidien », `DailySection.swift`).
- **Historique** : **26 semaines (~6 mois) en grille** sur chaque carte ; 400 jours conservés (`completedDays`). Vues 7 jours / mois / année séparées : **n'existent pas**. Taux : 30 jours (carte), 30 et 90 jours (Premium).
- **Objectif chiffré** (2 L d'eau, 30 min) : **n'existe pas** : simple coche oui/non. (Un compteur d'eau « verres, objectif 8 » existe ailleurs, `HydrationState`, hors habitudes.)
- **Archivage** : **n'existe pas** (supprimer seulement). Réorganiser : **existe** dans `HabitsView` (pas dans la page Planning). Catégories, notes, texte libre par jour : **n'existent pas**.

## C7. Fichiers → vues

| Bloc | Fichier | Vue |
|---|---|---|
| Page Habitudes de Planning, « Régularité » | `MiniApps/Planning/PlanningPages.swift` | `PlanningHabitsPage` |
| Carte d'une habitude (rond, légende, %, grille) | `Content/HabitsView.swift` | `HabitRow` |
| Éditeur | idem | `HabitEditor` |
| Variante List | idem | `HabitsView` |
| Grille de contributions (aussi widgets) | `Shared/Render/Tiles/HabitHeatmap.swift` | `HabitHeatmap` (données), `HabitHeatmapGrid` (vue) |
| Modèle | `Shared/Model/Content.swift` | `Habit` (`streak`, `bestStreak`, `regularity`) |
| Sélecteur de jour | `MiniApps/MiniApp.swift` | `DaySwitcher` |
| Offre limite / Premium | `Premium/PaywallContext.swift`, `Premium/PremiumLock.swift` | `habitLimit`, `PremiumLockCard` |
