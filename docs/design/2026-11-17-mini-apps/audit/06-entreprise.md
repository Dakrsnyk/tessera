# Audit : Entreprise (Business)

Relevé refait dans le code le 2026-11-17 (branche `main`, commit `e09123e`). Lecture seule. Chaque ligne porte sa preuve (fichier:ligne ou nom de la vue). Ce qui n'est pas prouvé est marqué « à vérifier ». Finance est hors mission et n'est pas relevée ici.

Chemins courts : `BusinessApp.swift`, `BusinessPages.swift`, `BusinessSources.swift` = `App/Screens/MiniApps/Business/`. `MoneySpaces.swift` = `App/Screens/Spaces/MoneySpaces.swift`. `Business.swift`, `BusinessImport.swift` = `Shared/Domains/`. `StripeSync.swift` = `App/Services/StripeSync.swift`. `MiniApp.swift`, `MiniAppSettings.swift`, `MiniAppScaffold.swift` = `App/Screens/MiniApps/`. `DailySection.swift`, `MiniAppsRow.swift`, `MyInfoCenter.swift`, `MyInfoSection.swift`, `HomeView.swift` = `App/Screens/Home/`.

Corrections par rapport à la version du matin (même fichier, commit `0e8dd68`) :
- La rangée de puces « Mes mini-apps » de l'Accueil n'existe plus à l'écran : `MiniAppsRow` n'est appelée nulle part hors de son fichier (retirée par le commit `3978be6`, « Accueil épuré »). La puce « Business » n'est donc pas une entrée.
- La carte « Ventes » du Studio n'a pas de bouton « Tout voir » : elle n'a que « Noter une vente » (`App/Screens/Profile/DataItemViews.swift:247-248`).
- Les lignes « Activité, Objectif, Clients, Ce mois-ci » de `facts(for:)` ne s'affichent nulle part (seul appel : `App/Screens/Onboarding/OnboardingView.swift:80`, pour savoir si un thème est vide).
- Les demandes 23.7 et 23.8 (taxes) concernent l'entreprise du PDG, pas la mini-app.
- Ajouts : le widget d'écran verrouillé « Business », la page de données de l'espace comptée comme fonction (F26), la présence dans « Mes informations » (F27), 4 captures du run 454 trouvées en local, 8 problèmes d'UX nouveaux. Les numéros F1 à F25 gardent le même sens qu'avant.

## 1. En bref

- Sert à un indépendant ou à un petit vendeur : il note ses ventes et ses dépenses, Ardane calcule le chiffre d'affaires, le bénéfice, la marge, le panier moyen, et compare à la période d'avant (texte d'accueil « Ton activité, chiffres à l'appui », `BusinessApp.swift:165-175`).
- C'est une vraie mini-app : cas `MiniApp.business`, titre « Business », couleur `8C6CFF` (`MiniApp.swift:6`, `:16`, `:44`). Le PDG dit « Entreprise » ; l'app dit aussi « Mon entreprise » (voir problème 1).
- Fréquence prévue : quelques fois par semaine (le total du jour, puis la lecture du mois). Aucun rappel n'existe.
- État : complète. 1 écran principal, 4 pages, 8 feuilles, 1 page de données d'espace, 1 feuille « Mes paramètres » : 15 écrans et feuilles, 27 fonctions.
- Gratuit : toute la saisie à la main, les indicateurs, la courbe, les totaux de l'année, le revenu récurrent, les suivis, 1 widget sur 7. Premium : import CSV, Stripe, analyse mois par mois, 6 widgets.

## 2. Écrans et navigation

### Écrans, pages et feuilles (15)

| # | Écran ou feuille | Vue SwiftUI, fichier:ligne | Comment on y arrive | Ce qu'on y fait |
|---|---|---|---|---|
| E1 | Écran principal (titre = nom saisi, « Mon entreprise » par défaut, « Business » si vide) | `BusinessAppView`, `BusinessApp.swift:111` ; branché dans `MiniApp.swift:155-156` | a) Accueil › Mon quotidien › carte « Business » (avec chiffre ou pointillée) (`DailySection.swift:445-456`, `App/Core/DailyBrief.swift:251`). b) Accueil › carte « Mes informations » › pastille « Mon entreprise », ou « Tout voir » › ligne « Mon entreprise » (`MyInfoCenter.swift:53-59`, `:203-207` ; route `DailySection.swift:15-38`). c) Toucher un widget d'entreprise : lien `tessera://space/business` (`Shared/Render/WidgetCanvas.swift:182-184`, `App/Core/Router.swift:168-171`). | Lire le chiffre d'affaires, changer de jour et de période, ajouter une vente ou une dépense, ouvrir tout le reste. |
| E2 | Page « Ventes et dépenses » | `BusinessSalesPage`, `BusinessPages.swift:6` ; route `MiniAppPage.businessSales` (`MiniApp.swift:119`, `:212`) | E1 › ligne « Ventes et dépenses » (`BusinessApp.swift:318`) | Basculer « Ventes » / « Dépenses », lire par mois avec le total du mois, toucher une ligne pour la modifier, « + » en haut à droite (`:41-46`), balayer pour supprimer (`:72-75`, `:107-110`). |
| E3 | Page « Résultats » | `BusinessResultsPage`, `BusinessPages.swift:137` | E1 › ligne « Résultats » (`BusinessApp.swift:324`) | Graphique par mois (barres CA et dépenses, ligne du bénéfice), « Depuis le 1er janvier », liste « Mois par mois ». Lecture seule. |
| E4 | Page « Revenu récurrent » | `BusinessRecurringPage`, `BusinessPages.swift:234` | E1 › ligne « Revenu récurrent » (`BusinessApp.swift:330`) | Lire MRR, ARR, abonnés ; « Mettre à jour le MRR » ; courbe ; liste des mois ; supprimer un mois par appui long (`:284-290`). |
| E5 | Page « Suivis à la main » | `BusinessMetricsPage`, `BusinessPages.swift:303` | E1 › section « Suivis à la main » (s'il y en a) ou ligne du même nom (sinon) (`BusinessApp.swift:256`, `:338`) | « Nouvel indicateur » ; une carte par indicateur (valeur, variation, objectif, courbe) ; « Noter une valeur ». |
| E6 | Feuille « Vente » / « Modifier la vente » | `SaleEditor`, `MoneySpaces.swift:210` | E1 › bouton « Vente » (`BusinessApp.swift:158`) ; E2 › « + » ou une ligne ; E14 ; Studio › « Tes données » › « Noter une vente » (`DataItemViews.swift:247-248`) | « Montant », « Date », « Commandes », « Nouveaux clients », « Visiteurs », « Note (facultatif) » ; « Supprimer la vente » (`:227-240`). |
| E7 | Feuille « Dépense » / « Modifier la dépense » | `BusinessCostEditor`, `MoneySpaces.swift:255` | E1 › bouton « Dépense » (`BusinessApp.swift:160`) ; E2 (Dépenses) › « + » ou une ligne ; E14 | « Montant », « Libellé (publicité, matériel…) », « Date » ; « Supprimer la dépense » (`:271-281`). |
| E8 | Feuille « Revenu récurrent » | `MRREditor`, `MoneySpaces.swift:295` | E4 › « Mettre à jour le MRR » (`BusinessPages.swift:259`) ; E14 | « Mois », « MRR », « Abonnés », préremplis avec le dernier mois (`:301-310`). Le même mois est remplacé (`:317`). |
| E9 | Feuille « Mes indicateurs » | `KPIPicker`, `BusinessApp.swift:474` | E1 › section « Indicateurs » › « Choisir » (`:223`) | Cocher parmi 11 indicateurs, chacun avec une phrase d'explication (`:517-531`) ; « OK ». |
| E10 | Feuille « Nouvel indicateur » (ou le nom de l'indicateur) | `MetricEditor`, `BusinessApp.swift:536` | E5 › « Nouvel indicateur » ou toucher une carte (`BusinessPages.swift:311-313`, `:333`) | « Nom (abonnés, devis envoyés, NPS…) », « Unité (facultatif) », « Plus c'est haut, mieux c'est », « Objectif » puis « Valeur visée », « Valeur d'aujourd'hui (facultatif) » (nouveau seulement), « Supprimer l'indicateur » (`:548-570`). |
| E11 | Feuille de valeur d'un suivi (titre = nom de l'indicateur) | `MetricValueEditor`, `BusinessApp.swift:592` | E5 › « Noter une valeur » (`BusinessPages.swift:350`) | « Valeur », « Date » (pas de futur, `:603`) ; rappel « Dernière valeur : … » (`:607`). |
| E12 | Feuille « Connecter Stripe » | `StripeConnectSheet`, `BusinessSources.swift:424` | E1 › « Ventes automatiques » › « Connecter Stripe » (Premium, `:87-98`) | 3 étapes, « Ouvrir les clés API de Stripe », champ masqué « Clé restreinte (rk_…) », « Connecter » (`:437-482`). |
| E13 | Feuille « Importer » (aperçu du fichier) | `BusinessImportSheet`, `BusinessSources.swift:268` | E1 › « Importer un fichier CSV » (Premium) › sélecteur de fichiers (`:101-124`) | Voir ce que le fichier contient, choisir « Des ventes » / « Des dépenses », inclure ou non les opérations non payées, « Réessayer », « Importer sans conversion », « Enregistrer » (`:306-373`). |
| E14 | Page de données de l'espace « Mon entreprise » | `BusinessSpaceSections`, `MoneySpaces.swift:153`, dans `SpaceView` (`App/Screens/Spaces/SpaceView.swift:82`) | Studio, en modifiant un widget d'entreprise › « Contenu » › « Données de l'espace Mon entreprise » (`App/Screens/Editor/SpaceOptionsSection.swift:56-73`). La version avec la bande de widgets n'est ouverte que par les captures (`App/Core/ScreenshotMode.swift:156-158`). | Nom, objectif du mois, 5 chiffres, 3 boutons (vente, dépense, MRR), 15 dernières ventes (balayer pour supprimer). Liste système. |
| E15 | Feuille « Mes paramètres » | `MiniAppInfoSheet`, `MiniAppSettings.swift:184` | E1, dernier bloc, bouton « Mes paramètres » (`BusinessApp.swift:150`, `MiniAppSettings.swift:63-84`) | « Ton activité » (nom), « Chaque mois » (« Objectif de CA », « Clients ») (`App/Screens/Profile/ProfileTopics.swift:527-557`), « Réglages communs » › « Devise » (`MiniAppSettings.swift:45`, `:164-172`). |

### Éléments qui ne sont pas des écrans propres

| Élément | Où | Ce qu'il fait |
|---|---|---|
| Sélecteur de fichiers iOS (.csv, .tsv, texte) | `BusinessSources.swift:116` | Choisit le fichier. L'aperçu E13 s'ouvre 0,6 s après (piège iOS, `:118-123`). |
| Alerte « Import impossible » / « Import terminé » | `BusinessSources.swift:132-136`, `:171-181` | Dit pourquoi le fichier ne se lit pas, ou ce que l'import a fait (« 12 nouvelles opérations · … », `:226-235`). |
| Dialogue « Déconnecter Stripe ? » | `BusinessSources.swift:137-142` | « Déconnecter et garder les ventes », « Déconnecter et retirer ses ventes ». |
| Offre Premium « Connecter Stripe, avec Premium » | `PaywallContext.stripeConnection`, `BusinessSources.swift:249-256` | Ouverte par « Connecter Stripe » ou « Synchroniser » sans Premium (`:68`, `:89`). |
| Offre Premium « Importer un fichier, avec Premium » | `PaywallContext.businessImport`, `BusinessSources.swift:239-246` | Ouverte par « Importer un fichier CSV » sans Premium (`:103`). |
| Carte verrou « L'analyse mois par mois est dans Premium » | `BusinessPages.swift:159-162` ; `PremiumLockCard`, `App/Premium/PremiumLock.swift:5` | Bouton « Découvrir Premium », en tête de E3 sans Premium. |
| Carte « À remplir » | `MiniAppToFillSection`, `App/Screens/MiniApps/MiniAppToFill.swift:15`, `:41` ; champ `DataItemViews.swift:238-246` | En tête de la feuille de E1 : « Objectif de chiffre d'affaires », champ « Chaque mois ». Disparaît une fois l'objectif donné. |
| Studio › « Tes données » | `App/Screens/Editor/EditorView.swift:583` ; `DataItemViews.swift:238-248` | En créant un widget d'entreprise : champ « Chaque mois » et bouton « Noter une vente » (ouvre E6). |
| Questions du premier lancement | `OnboardingView.swift:283` ; `ProfileTopics.swift:527-557` | Si l'intérêt « Business » est choisi : les mêmes champs que E15 (nom, objectif, clients). |
| Feuille « Ajouter une catégorie » | `DailySection.swift:1609-1657` | Accueil › « + » : pose la carte « Business » sur Mon quotidien. N'ouvre pas la mini-app. |

### Code présent mais pas affiché

- `MiniAppsRow` et `AllMiniAppsSheet` (`MiniAppsRow.swift:137`, `:205`) : rangée de puces et liste « Mini-apps ». Aucun appel hors du fichier ; `HomeView.swift:80-91` ne pose que Mon quotidien, « Mes informations » et la bannière Premium. `MiniAppSummary.caption` (même fichier, `:64-111`) sert encore à la carte de Mon quotidien.
- `facts(for:)` cas `.business` (`MyInfoSection.swift:56-60`) : jamais affiché.
- `BusinessSource.title` (« Fichier importé », `BusinessImport.swift:12-17`) : jamais affiché.

## 3. Écran principal : sections dans l'ordre actuel

E1 est un `MiniAppScaffold` (`BusinessApp.swift:131-151`) : un haut sur nappe violette, puis des blocs. Pas d'action flottante (paramètre `action` absent, `:131`). Vérifié sur la capture `mini-app-business.png` du run 454.

**Haut de l'écran**
1. **Titre** : le nom saisi (« Atelier Nova » dans les données de démonstration), « Business » si le nom est vide (`:152`).
2. **Sélecteur de semaine** (`WeekSelector`, `:134`) : 7 jours, pas de jour futur, un point sous les jours qui ont une vente ou une dépense (`:180-184`), flèches de semaine.
3. **Sans aucune donnée** (`start`, `:165-175`) : icône mallette, « Ton activité, chiffres à l'appui », phrase d'aide. Condition : aucune vente, aucune dépense, aucun MRR (`:135`).
   **Avec des données** (`hero`, `:186-214`) : sélecteur « Jour / Semaine / Mois / Année », puis carte « CHIFFRE D'AFFAIRES » avec le montant en très grand et une légende : « +32,4 % par rapport au mois dernier à la même date » et, en « Mois » seulement, « 75 % de l'objectif de 12 000 $ ».

**Blocs suivants**
4. **« À remplir »** (`:143`) : l'objectif de chiffre d'affaires, tant qu'il n'est pas donné.
5. **Deux boutons** « + Vente » (plein) et « − Dépense » (clair) (`actions`, `:156-163`).
6. **« Indicateurs »** avec le lien « Choisir » (`kpis`, `:218-249`) : tuiles sur 2 colonnes (nom, valeur, variation en vert ou rouge). Par défaut : Bénéfice, Commandes, Panier moyen. Le chiffre d'affaires n'y est jamais répété (`:219`).
7. **« Ventes automatiques »** (`BusinessSourcesCard`, `:146`) : ligne Stripe, ligne « Importer un fichier CSV », note « Les données vont directement de ton iPhone à Stripe… ».
8. **« Suivis à la main »** (`metrics`, `:251-271`) : seulement s'il y en a ; les 3 premiers ; toute la carte ouvre E5.
9. **« Chiffre d'affaires cumulé »** (`curve`, `:275-303`) : courbe de la période (trait plein) contre la précédente (pointillés), légende « Cette période » / « Période précédente ». Cachée sans chiffre.
10. **Carte de lignes** (`more`, `:316-346`) : « Ventes et dépenses », « Résultats », « Revenu récurrent » (avec « MRR x $ » s'il existe), et « Suivis à la main » tant qu'il n'y en a aucun.
11. **« Mes paramètres »** (`:150`).

Le jour choisi et la période pilotent le héros, les tuiles et la courbe (`:187`, `:238`, `:277`). Ils ne pilotent aucune page (E2 à E5).

## 4. Fonctions existantes

Liste de référence : aucune planche ne doit en perdre une. 27 fonctions. Premium : F12, F15, F16, F17, F18, F23, et 6 des 7 widgets de F24 (7 fonctions touchées par Premium).

| N° | Fonction | Où elle est | Gratuit ou Premium | Données affichées | Actions possibles |
|---|---|---|---|---|---|
| F1 | Chiffre d'affaires de la période | E1 héros, `BusinessApp.swift:186-214` | Gratuit | CA du début de la période jusqu'au jour choisi ; variation contre la période d'avant, ou « Rien hier à la même heure » (etc.) si elle vaut 0 | Changer le jour et la période |
| F2 | Choix de la période | E1, `:204-208` (id `business-period`) | Gratuit | « Jour », « Semaine », « Mois », « Année » | Toucher un segment |
| F3 | Sélecteur de semaine avec repères | E1, `:134`, `:180-184` | Gratuit | Les 7 jours, un point sur les jours avec une opération | Choisir un jour (jamais futur), changer de semaine, revenir à aujourd'hui |
| F4 | Objectif mensuel de chiffre d'affaires | Légende du héros en « Mois » (`:196-200`) ; saisie : « À remplir », E15, E14, premier lancement, Studio | Gratuit | « x % de l'objectif de y $ » | Donner, changer, effacer l'objectif |
| F5 | Ajouter une vente | E6 | Gratuit | Montant, date, commandes (1 par défaut), nouveaux clients, visiteurs, note | Enregistrer (montant > 0). Le total du jour suffit (`:169`) |
| F6 | Ajouter une dépense | E7 | Gratuit | Montant, libellé, date | Enregistrer. Libellé vide = « Dépense » (`MoneySpaces.swift:289`) |
| F7 | Modifier ou supprimer une vente ou une dépense | E2, E6, E7, E14 | Gratuit | La ligne et ses champs | Toucher, changer, « Supprimer… », balayer. Retaper le montant efface le montant d'origine en devise (`MoneySpaces.swift:249`, `:290`) |
| F8 | Indicateurs au choix (11) | E1 bloc 6 (`KPITile`, `:401`) ; choix E9 | Gratuit | Chiffre d'affaires, Dépenses, Bénéfice, Marge, Commandes, Panier moyen, Nouveaux clients, Visiteurs, Conversion, MRR, Abonnés (`Business.swift:50-68`) ; valeur et variation ; « ce mois-ci » pour MRR et Abonnés | Cocher, décocher. Défaut : CA, Bénéfice, Commandes, Panier moyen (`Business.swift:142`) |
| F9 | Courbe du chiffre d'affaires cumulé | E1 bloc 9 | Gratuit | Période en cours contre la précédente ; en « Jour », la semaine (« cette semaine ») ; en « Année », par mois | Lecture seule |
| F10 | Journal « Ventes et dépenses » | E2 | Gratuit | Ventes (date, « 4 commandes · 1 nouveau client », note, montant) ou dépenses (libellé, date, montant), par mois avec le total | Basculer, ajouter, modifier, supprimer |
| F11 | Résultats : totaux de l'année | E3, `BusinessPages.swift:197-205` | Gratuit | « Depuis le 1er janvier » : chiffre d'affaires, bénéfice, « marge x % » | Lecture seule |
| F12 | Résultats : analyse mois par mois | E3, `:169-195`, `:206-218` | **Premium** | Graphique des 6 derniers mois (barres CA et dépenses, ligne du bénéfice) ; liste « Mois par mois » (CA − dépenses, bénéfice) | Lecture seule. Sans Premium : carte verrou |
| F13 | Revenu récurrent | E4, E8 ; ligne de E1 (`BusinessApp.swift:331-332`) | Gratuit | MRR et « +x % sur un mois », ARR (« MRR × 12 »), abonnés et montant par abonné, courbe dès 2 mois, liste des mois | « Mettre à jour le MRR » ; supprimer un mois (appui long) |
| F14 | Suivis à la main (indicateurs personnels) | E5, E10, E11 ; aperçu sur E1 bloc 8 | Gratuit | Nom, unité, dernière valeur et sa date, variation, « objectif y · x % », courbe dès 2 valeurs avec la ligne d'objectif | Créer, modifier, supprimer, noter une valeur (une par jour, 400 au plus, `Business.swift:116-121`) |
| F15 | Importer un fichier CSV | E1 bloc 7, E13 | **Premium** | Nom du fichier, nombre de ventes et de dépenses, totaux, période, lignes ignorées ; « Dernier : fichier, date » sur la ligne | Choisir le fichier, dire « Des ventes » ou « Des dépenses », inclure les non payées, enregistrer |
| F16 | Conversion de devise | E13 (`BusinessSources.swift:357-372`, `:389-397`) ; Stripe (`:47-65`) | **Premium** | « Conversion en CAD… », « Converti depuis USD au taux de référence de la BCE… », message en rouge si un taux manque | « Réessayer », « Importer sans conversion », « Synchroniser sans conversion » |
| F17 | Connecter Stripe en lecture seule | E1 bloc 7, E12 | **Premium** | « Stripe » ou « Stripe (mode test) », « Clé …a1B2 · jamais synchronisé » | Coller une clé restreinte `rk_` ; ouvrir les clés API de Stripe |
| F18 | Synchronisation Stripe | E1 bloc 7 (`BusinessSources.swift:66-79`, `:128`) | **Premium** | « Synchronisé aujourd'hui à 14 h 02 · 3 nouvelles opérations », erreur en rouge, devises converties ou gardées | « Synchroniser » ; seule à l'ouverture si la dernière a plus d'une heure (`StripeSync.swift:238-242`) |
| F19 | Déconnecter Stripe | E1 bloc 7 (`BusinessSources.swift:81`, `:137-142`) | Gratuit (toujours possible) | « La clé est effacée de ton iPhone… » | Garder ou retirer les ventes venues de Stripe |
| F20 | Stripe connecté, Premium arrêté | E1 bloc 7 (`BusinessSources.swift:39-46`) | Gratuit | « La synchronisation Stripe est dans Premium. Les ventes déjà importées restent. » | « Synchroniser » ouvre l'offre ; « Déconnecter » |
| F21 | Nom, objectif, clients | E15 ; premier lancement ; nom et objectif aussi dans E14 | Gratuit | Nom ou activité, objectif de CA, nombre de clients | Modifier. Le nom devient le titre de E1 et du widget « Tableau de bord business » |
| F22 | Devise de l'app | E15 › « Réglages communs » | Gratuit | CAD, USD, EUR, GBP, CHF (`Shared/Model/Settings.swift:212`) | Choisir |
| F23 | Fusion sans doublon des opérations importées | `BusinessState.merge`, `BusinessImport.swift:89` | Premium (suit l'import et Stripe) | « déjà présente », « opération mise à jour » | Automatique. Une ligne tapée à la main n'est jamais touchée |
| F24 | Widgets d'entreprise | 7 widgets (`Shared/Model/KindCatalog.swift:204-211`) ; widget d'écran verrouillé « Business » (`Widgets/DesignWidgets.swift:87-89`) | 1 gratuit, 6 Premium (détail en section 6) | Voir section 6 | Créer dans le Studio, poser sur l'écran, toucher pour ouvrir E1 |
| F25 | Carte de Mon quotidien | Accueil (`DailySection.swift:445-456`) | Gratuit | « x $ ce mois », ou l'invitation « Note tes ventes : … » | Ouvre E1 ; ajout par le « + » de l'Accueil |
| F26 | Page de données de l'espace : toutes les périodes d'un coup | E14, `MoneySpaces.swift:162-173` | Gratuit | « Aujourd'hui », « Cette semaine », « Ce mois-ci », « Cette année », « Bénéfice du mois » avec la marge ; 15 dernières ventes | Changer le nom et l'objectif ; « Noter une vente », « Noter une dépense », « Mettre à jour le MRR » |
| F27 | Présence dans « Mes informations » | Accueil, pastille et ligne « Mon entreprise » (`MyInfoCenter.swift:53-59`, `:219-240`) | Gratuit | « À compléter » ou ✓ ; résumé « 12 000 $ par mois · 62 ventes notées » (`App/Core/DataItems.swift:422-423`) | Ouvre E1 |

## 5. Données et calculs

À ne pas modifier. Sauvegarde : fichier `business` de l'App Group (`Shared/Support/SharedStore.swift:68`), inclus dans les sauvegardes (`App/Core/DataBackup.swift:28`, `:132`). Toute écriture passe par `model.update(\.business)`.

**Ce qui est saisi**
- `BusinessState` (`Business.swift:131-141`) : `name` (« Mon entreprise »), `monthlyGoal` (10 000 par défaut), `sales`, `expenses`, `subscriptions`, `pinnedKPIs`, `metrics`, `connections`.
- `SalesEntry` (`:3-17`) : date, `amount`, `orders` (1), `newCustomers`, `visitors`, `note` ; pour une ligne importée : `source`, `externalID`, `original`.
- `BusinessExpense` (`:19-27`) : date, `amount`, `label`, `source`, `externalID`, `original`. Pas de catégorie.
- `SubscriptionSnapshot` (`:40-46`) : mois, `mrr`, `subscribers`. Un par mois.
- `CustomMetric` (`:104-129`) : nom, unité, objectif, sens, valeurs (une par jour, 400 au plus).
- `ForeignAmount` (`:30-38`) : montant d'origine, devise, taux, jour du taux.
- `BusinessConnections` (`BusinessImport.swift:49-80`) : `StripeLink` (fin de la clé, mode test, dernière synchronisation, erreur, résultat, devises) et `ImportRecord` (fichier, date, résultat, lignes ignorées).
- Hors de `BusinessState` : `profile.businessClients` (`Shared/Domains/Profile.swift:367`) ; faits « donnés » `businessName` et `businessGoal` (`Profile.swift:304`, `App/Core/AppModel.swift:1288-1296`) ; clé Stripe dans le trousseau (`StripeSync.swift:6-58`).

**Ce qui est calculé (`BusinessMath`, `Business.swift:173-403`)**
- Période et période précédente coupée au même point (`interval` `:176`, `previousInterval` `:188`) : un mois en cours se compare aux mêmes jours du mois d'avant.
- Chiffre d'affaires = somme des ventes (`:208`) ; dépenses (`:227`) ; bénéfice = CA − dépenses ; marge = bénéfice ÷ CA, absente sans CA (`:231-236`).
- Indicateurs (`value`, `:298-321`) : panier moyen = CA ÷ commandes ; conversion = commandes ÷ visiteurs ; visiteurs, conversion, marge et panier absents sans données (« – ») ; MRR et abonnés lus au dernier mois noté.
- Comparaison (`compare`, `:333-343`) ; variation nulle si la période d'avant vaut 0 (`Shared/Support/Helpers.swift:62-65`).
- Objectif (`goalProgress`, `:222-225`) : CA du mois entier ÷ objectif.
- Courbe (`cumulative`, `:354-384`) : par jour, par mois pour l'année ; en « Jour », la semaine.
- Mois (`months`, `:395-402`) : 6 derniers mois ; les mois vides du début sont retirés (`BusinessPages.swift:154`).
- Récurrent (`recurring`, `:278-283`) : dernier MRR, abonnés, croissance, ARR = MRR × 12.
- Pour les widgets : `profit(month:)` (`:238`), `kpis(month:)` (`:250`), `dailyRevenue` (`:264`), `growth` (`:216`), `todayVersusLastWeek` (`:286`).
- Tests : `Tests/FinancesBusinessTests.swift:120`, `:151` ; `Tests/BusinessCSVTests.swift` (24 tests) ; `Tests/CurrencyConversionTests.swift` (10 tests).

**Import et Stripe**
- Lecture du fichier : `BusinessCSV.parse` (`BusinessImport.swift:320`). Ordre des règles pour décider vente ou dépense : commentaire `:171-196`. Lignes ignorées : paiements échoués (`:212`), virements, lignes sans date ou sans montant. Opérations non payées repérées (`:215`).
- Fusion : `merge` (`:89-145`). Même source et même identifiant = même ligne. Une ligne lue du mauvais côté change de côté au réimport.
- Stripe : `StripeTransactions.batch` (`:770-829`). Paiement = vente ; remboursement = vente négative ; frais = une dépense « Frais Stripe » par jour ; virements ignorés.
- Conversion : `CurrencyConversion` (`:838-881`), taux BCE du jour de l'opération, arrondi au cent, montant d'origine gardé.
- Synchronisation : `StripeSync.sync` (`StripeSync.swift:149-226`). Première lecture sur 365 jours (`:71`) ; 100 pages de 100 au plus (`:75`) ; clé `rk_live_` ou `rk_test_` seulement (`:123`) ; arrêt sans Premium (`:151`).

## 6. Liens

**Carte de Mon quotidien**
- Catégorie `business`, identifiant de carte `app-business` (`App/Core/DailyBrief.swift:114`, `:121`), identifiant de test `daily-app-business` (`DailySection.swift:456`).
- Contenu avec au moins une vente : nom « Business », icône mallette, couleur `8C6CFF`, une ligne « x $ ce mois » (`MiniAppsRow.swift:97-99`). Toute la carte ouvre E1.
- Contenu sans vente : carte d'invitation « Note tes ventes : ton chiffre d'affaires du mois apparaîtra ici. » (`DailyBrief.swift:237`), seulement si la catégorie est voulue (intérêt « Business » ou ajout par le « + », `App/Core/DailyCategories.swift:97-104`).
- Taille : demi-largeur par défaut (`DailyBrief.swift:297-305`, `App/Core/DailyDefaults.swift:21`). Peut passer en pleine largeur avec « + » en mode édition (`App/Screens/Home/DailyLayoutRules.swift:14-17`). Le dessin est le même dans les deux largeurs.
- Place par défaut : 10e sur 12, après Pas, avant Voyage et Auto (`DailyDefaults.swift:11-14`). Retirable et déplaçable.

**Widgets** (`KindCatalog.swift:204-211` ; contenu : `Shared/Render/Tiles/BusinessTiles.swift`)

| Widget | Gratuit ou Premium | Tailles | Contenu |
|---|---|---|---|
| « Objectif du mois » | Gratuit | petit, moyen, cercle, rectangle | CA du mois, anneau, « sur 12 000 $ · 75 % », reste par jour (`BusinessTiles.swift:28-52`) |
| « Ventes sur 30 jours » | Premium | petit, moyen, grand | Total 30 jours, barres par jour, semaine, mois, année (`:54-72`) |
| « Bénéfice » | Premium | petit, moyen | Bénéfice du mois, marge, CA, dépenses (`:74-86`) |
| « Indicateurs » | Premium | petit, moyen, grand | Commandes, panier moyen, nouveaux clients, conversion du mois (`:88-103`) |
| « MRR et ARR » | Premium | petit, moyen, rectangle | MRR, ARR, abonnés, croissance, barres sur 12 mois (`:105-121`) |
| « Ventes du jour » | Premium | petit, moyen, rectangle, ligne | CA du jour contre le même jour la semaine d'avant, à la même heure ; commandes (`:123-137`) |
| « Tableau de bord business » | Premium | moyen, grand | Nom, CA du mois, % de l'objectif, aujourd'hui, semaine, bénéfice, commandes, MRR, barres 14 jours (`:139-160`) |

- Widget d'écran verrouillé « Business » dans la galerie d'iOS (`Widgets/ArdaneWidgetsBundle.swift:45`).
- Toucher un widget ouvre E1 (`WidgetCanvas.swift:182-184`, `Router.swift:168-171`). Un widget Premium sans Premium ouvre l'offre (`WidgetCanvas.swift:162`).
- Montants masqués quand l'iPhone est verrouillé (`Shared/Render/Tiles/TileFactory.swift:15-18`).
- Widget vide : « Note tes ventes dans Ardane, espace Mon entreprise. » (`BusinessTiles.swift:4`).
- Dans Créer : catégorie « Mon entreprise », « Chiffre d'affaires et indicateurs » (`KindCatalog.swift:18`, `:35`). Modèle mis en avant « Objectif du mois » (`Shared/Model/Templates.swift:121`). Pack (`Shared/Model/Packs.swift:65`). Store : rayon « Pour entreprendre » (`App/Screens/Explore/StoreShowcase.swift:113`).

**Autres mini-apps** : aucun échange de données. Seul partage : le service de taux de change, aussi utilisé par Voyage (`Shared/Domains/Travel.swift:349`).

**Notifications et rappels** : aucun. La ligne de rappel de « Mes paramètres » n'existe que pour Fitness, Nutrition et Finances (`MiniAppSettings.swift:124-129`). Aucune occurrence « business » dans `Shared/Support/SmartReminders.swift`.

**Liens profonds** : un seul, `tessera://space/business`, qui ouvre E1. Aucun lien vers une page ni vers « ajouter une vente ».

**Services externes** : `api.stripe.com` (`StripeSync.swift:245`) et les taux de change BCE par Frankfurter (`scripts/graph_map.py:316`). Rien ne passe par un serveur d'Ardane.

## 7. États vides, première utilisation, erreurs, permissions, limites du mode gratuit

**Première utilisation (aucune donnée)**
- Haut : texte « Ton activité, chiffres à l'appui », sans bouton (`BusinessApp.swift:165-175`).
- Puis : « À remplir » (objectif), les deux boutons, les tuiles par défaut (« 0 $ » et « rien avant », « – » et « pas encore de données », `:423`), « Ventes automatiques », la carte de 4 lignes, « Mes paramètres ». Pas de courbe.
- Dès la première vente, dépense ou MRR : le héros remplace le texte (`:135`).

**Vides par vue**
- E2 : « Aucune vente notée pour l'instant. » / « Aucune dépense notée pour l'instant. » (`BusinessPages.swift:54`, `:90`).
- E3 : « Rien de noté pour l'instant : les mois apparaîtront ici dès la première opération. » (`:164`).
- E4 : « Si tu vends des abonnements, note ton revenu mensuel récurrent chaque mois : Ardane en suit la croissance. » (`:254`).
- E5 : « Abonnés, devis envoyés, avis clients, NPS… » (`:316`).
- E1 sans indicateur coché : « Choisis les indicateurs à suivre ici : bénéfice, marge, panier moyen, conversion, MRR… » (`BusinessApp.swift:229`).
- Suivi sans valeur : « Aucune valeur » (`:469`).

**Erreurs**
- Stripe, 9 messages (`StripeSync.swift:105-117`) : clé non restreinte, clé refusée, autorisation manquante, pas de réseau, erreur du serveur, réponse illisible, taux manquants, « Clé absente de cet iPhone : reconnecte Stripe. » (après une restauration), « Synchronisation partielle… ». Affichés en rouge sous la ligne Stripe (`BusinessSources.swift:32-38`) ou dans E12 (`:453-457`).
- Fichier (`BusinessSources.swift:183-215`) : « Le fichier n'a pas pu être lu. », « Ce fichier est trop gros pour être lu. » (plus de 20 Mo), « Aucune colonne de date ou de montant n'a été trouvée… », « Le fichier est vide. ». Fermer le sélecteur ne dit rien (voulu).
- Taux indisponibles à l'import : message rouge, « Réessayer », « Importer sans conversion » (`:357-372`).
- Aucune valeur d'exemple n'est montrée à la place d'une vraie donnée.

**Permissions**
- Aucune demande système (ni notifications, ni caméra, ni photos, ni position).
- Fichiers : sélecteur de documents d'iOS, accès au seul fichier choisi (`BusinessSources.swift:192-193`).
- Trousseau : clé Stripe lisible iPhone déverrouillé, jamais copiée sur un autre appareil (`StripeSync.swift:16`), effacée à une installation neuve (`:47-57`).

**Limites du mode gratuit**
- Aucun plafond de quantité (ventes, dépenses, suivis, mois de MRR).
- Premium : import CSV (2026-11-05), Stripe (2026-11-16, `docs/memoire/Decisions.md:127`), analyse mois par mois, 6 widgets sur 7. Badge « Premium » sur les deux lignes de « Ventes automatiques » (`BusinessSources.swift:94`, `:109`).
- Rien de saisi n'est verrouillé. Premium arrêté : les ventes Stripe restent, la synchronisation attend, « Déconnecter » reste possible.

## 8. Problèmes d'UX constatés aujourd'hui

1. **Trop de noms pour le même sujet.** « Business » : mini-app, carte de Mon quotidien, thème du premier lancement, widget d'écran verrouillé (`MiniApp.swift:16`, `Profile.swift:21`, `DesignWidgets.swift:88`). « Mon entreprise » : catégorie de Créer, ligne de « Mes informations », nom par défaut (`KindCatalog.swift:18`, `Business.swift:132`). « Pour entreprendre » : Store (`StoreShowcase.swift:113`). « Ton activité » : question (`ProfileTopics.swift:529`). Un style de widget s'appelle aussi « Business » (`Shared/Theme/Theme.swift:361`). Le PDG dit « Entreprise ».
2. **Le titre de l'écran est le nom saisi, pas celui de la mini-app.** La capture montre « Atelier Nova » (`BusinessApp.swift:152`).
3. **L'accès depuis l'Accueil est long sans intérêt ni vente.** Il n'y a plus de liste des mini-apps sur l'Accueil (`HomeView.swift:80-91`). Chemin : « + » › « Ajouter une catégorie » › « Business » › toucher la carte pointillée ; ou « Mes informations » › « Tout voir » › « Mon entreprise ».
4. **Deux sélecteurs de temps empilés, sans dire ce qui est compté.** Le jour choisi fixe la fin de la période, la période est un second sélecteur (`BusinessApp.swift:123-125`, `:134`, `:204-208`). La carte dit seulement « CHIFFRE D'AFFAIRES » (`:209`), jamais « du 1er au 5 novembre ».
5. **La période et le jour ne commandent que le héros, les tuiles et la courbe** (`:187`, `:238`, `:277`). E2 reste par mois, E3 sur 6 mois et l'année en cours (`BusinessPages.swift:56`, `:154-157`).
6. **Le pourcentage de l'objectif ne suit pas le jour choisi.** Le CA du héros s'arrête au jour choisi (`BusinessApp.swift:187`), le pourcentage compte le mois entier (`:196`, `Business.swift:222-225`). À vérifier à l'écran avec un jour passé.
7. **Un objectif de 10 000 s'affiche sans avoir été donné.** Le héros teste `monthlyGoal > 0` (`BusinessApp.swift:197`), la valeur par défaut est 10 000 (`Business.swift:133`), alors que « À remplir » demande encore l'objectif (`DataItems.swift:366`). Même chose dans E14 (`MoneySpaces.swift:164`) et le widget tableau de bord (`BusinessTiles.swift:142`).
8. **L'objectif n'a ni jauge ni anneau dans la mini-app.** Il n'est qu'une phrase, et seulement en « Mois » (`BusinessApp.swift:197-200`). Le widget, lui, dessine un anneau et calcule le reste par jour (`BusinessTiles.swift:46-47`) : ce calcul n'est visible nulle part dans la mini-app.
9. **Une vente ajoutée depuis E1 prend la date d'aujourd'hui, pas le jour choisi** (`BusinessApp.swift:158`, `Business.swift:5`). Et sa date peut être future (`MoneySpaces.swift:228`, `:273`, sans borne), alors que le sélecteur s'arrête à aujourd'hui.
10. **L'action principale n'est pas flottante.** Les deux boutons défilent avec la page (`BusinessApp.swift:144`). Fitness, Planning et Voyage ont une action flottante (`Fitness/FitnessApp.swift:34`, `Planning/PlanningApp.swift:36`, `Travel/TravelApp.swift:66`) ; Nutrition, Auto, Études et Photos n'en ont pas.
11. **L'état vide n'a pas de bouton dans son texte, et montre des tuiles à zéro.** Texte en haut (`:165-175`), boutons plus bas, tuiles « 0 $ · rien avant » (`:423`).
12. **« Ventes automatiques » est le 4e bloc, avant les suivis, la courbe et les pages** (`:146`). Pour un compte gratuit, ce sont deux lignes verrouillées et une note au milieu du tableau de bord.
13. **Les 4 pages sont tout en bas, dans une carte de lignes** (`:316-346`), après 5 à 6 blocs. La ligne « Suivis à la main » quitte cette carte dès qu'un suivi existe (`:336`) : le même accès change de place.
14. **Plusieurs couleurs pour un seul sujet.** Mini-app `8C6CFF` (`MiniApp.swift:44`) ; catégorie, intérêt et ligne de « Mes informations » `C28A12` (`KindCatalog.swift:69`, `Profile.swift:63`) ; modèles de widgets `F2A33A` (`Templates.swift:121`) ; dans E1 : Résultats `3366FF`, récurrent `1E9E75`, suivis `F2A33A` (`BusinessApp.swift:325`, `:331`, `:339`), Stripe `635BFF`. Les pages E2 et E3 n'ont pas la nappe violette de E1 (captures du run 454 : fond bleu-vert, bouton « + » bleu).
15. **Le titre change de taille d'une page à l'autre.** Petit sur E1 et E2 (`MiniAppScaffold.swift:75`, `BusinessPages.swift:40`), grand sur E3, E4, E5 (`:224`, `:296`, `:326`).
16. **E3 paraît à moitié vide sans Premium.** Une carte verrou, deux tuiles, une note (`BusinessPages.swift:159-162`, `:197-205`, `:219`).
17. **L'origine d'une opération est invisible.** `source` (Stripe ou fichier) et `original` (montant en devise) ne sont affichés ni dans E2 (`:121-126`) ni dans E6 (`MoneySpaces.swift:227-232`).
18. **Aucune confirmation de suppression**, sauf pour Stripe. Balayage (`BusinessPages.swift:72-75`, `:107-110`), « Supprimer la vente » (`MoneySpaces.swift:236-240`), « Supprimer l'indicateur » avec toutes ses valeurs (`BusinessApp.swift:564-568`). La suppression d'un mois de MRR est cachée sous un appui long (`BusinessPages.swift:284-290`).
19. **Le journal n'a ni recherche, ni filtre, ni catégorie de dépense** (`BusinessPages.swift:56-83`, `:92-118`). Une synchronisation Stripe peut y poser jusqu'à 10 000 lignes (`StripeSync.swift:71-75`). Les visiteurs d'une vente ne s'y lisent pas (`:121-126`).
20. **Le formulaire de vente donne le même poids à 6 champs** (`MoneySpaces.swift:227-232`). « Commandes » vaut 1 par défaut (`Business.swift:7`) : un total du jour saisi vite compte pour une seule commande, et le panier moyen devient ce total (`Business.swift:308`).
21. **Les indicateurs se règlent mal.** « Choisir » est un petit lien texte (`BusinessApp.swift:223-226`). Une tuile ne se touche pas (`:401-430`). L'ordre est celui des coches, sans moyen de le changer (`Business.swift:160-162`). « Chiffre d'affaires » se coche sans aucun effet (`BusinessApp.swift:219`, `:483`).
22. **Seuls 3 suivis s'affichent sur E1** (`prefix(3)`, `:258`), sans mention « voir tout ».
23. **« Clients » est une donnée orpheline.** Saisie (`ProfileTopics.swift:551-555`), gardée (`Profile.swift:367`), jamais affichée ni calculée (`MyInfoSection.swift:59`, lu seulement par `OnboardingView.swift:80`).
24. **E14 double E1 et E15, en moins bien, avec un texte périmé.** Liste système, ventes non modifiables (`MoneySpaces.swift:184-201`), et la note « Saisie manuelle : pour un export Shopify, Stripe ou autre, note le total du jour. » (`:180`) alors que l'import et Stripe existent.
25. **La carte de Mon quotidien n'a qu'une ligne de texte** (`DailySection.swift:448-456`) : ni variation, ni objectif, ni graphique, ni bouton. Elle ne montre un chiffre que s'il y a une vente (`MiniAppsRow.swift:98`) : avec seulement des dépenses ou un MRR, elle reste une invitation.
26. **Les erreurs Stripe sont une petite ligne rouge dans le 4e bloc** (`BusinessSources.swift:32-38`). « Le chiffre d'affaires peut être sous-estimé » (`StripeSync.swift:115`) n'apparaît pas près du chiffre.
27. **Aucun rappel de saisie** (`MiniAppSettings.swift:124-129`), alors que l'usage repose sur une saisie régulière.
28. **Le MRR se règle loin de là où il se lit.** Tuiles « MRR » et « Abonnés » sur E1, mais « Mettre à jour le MRR » seulement dans E4 et E14 (`BusinessPages.swift:259`). La feuille demande un « Mois » avec un calendrier au jour près (`MoneySpaces.swift:301`).

## 9. Ce que la mission du PDG cite et qui n'existe pas

Rien. `MISSION.md` ne nomme pas l'Entreprise : elle entre dans « F. Autres mini-apps existantes », sans liste de fonctions. Les vues demandées pour chaque mini-app existent toutes : écran principal (E1), sections et accès, vue détaillée (E3), vue de gestion ou de personnalisation (E9, E15), vue secondaire (E2, E4, E5).

Pour mémoire, ce qui n'existe pas et qu'une planche ne doit dessiner qu'avec la mention « nouvelle idée » :
- Factures, devis, liste de clients, produits.
- Catégories de dépenses, dépenses répétées, pièces jointes.
- Taxes, export comptable, export de fichier.
- Objectif annuel, objectif par indicateur, jauge d'objectif dans la mini-app.
- Rappels de saisie, alertes de seuil.
- Détail d'un indicateur au toucher d'une tuile, ordre des tuiles.
- Recherche et filtres dans le journal, étiquette « Stripe » ou « fichier » sur une ligne.
- Shopify, QuickBooks, Stripe Connect : « plus tard » (`docs/memoire/Chantiers.md:52`, `Decisions.md:16`).
- Graphique, variation ou bouton sur la carte de Mon quotidien.

## 10. Captures CI disponibles

**Dans `origin/ci-report` : aucune image.** 918 fichiers, tous en `.txt`, aucun nom avec « business » ou « entreprise » (dernier commit `170618c`, « Build 455 »).

**Captures de la CI copiées en local (run 454, style Cristal actuel, en français) : 4.** Dossier `pub/rapports/design-2026-11-17-mini-apps/captures-ci-454/` (non versionné).

| Fichier | Ce qu'il montre | Source |
|---|---|---|
| `mini-app-business.png` | E1 en « Mois » : sélecteur, héros « 9 044 $ », boutons, 4 tuiles | `UITests/MiniAppUITests.swift:422` |
| `mini-app-business-kpis.png` | E1 en « Semaine », après ajout de « Visiteurs » | `MiniAppUITests.swift:435` |
| `mini-app-business-sales.png` | E2, onglet « Ventes », novembre 2026 | `MiniAppUITests.swift:439` |
| `mini-app-business-results.png` | E3 avec Premium : graphique, année, « Mois par mois » | `MiniAppUITests.swift:439` |

Plus anciennes, en anglais, style d'avant Cristal (2026-11-07), à ne pas prendre comme référence : `pub/kit-en4/adkit-en/shots/app-business-hero.png`, `app-business-kpis.png`, `app-business-sales.png` (`UITests/AdShotsUITests.swift:292-315`).

**Noms que la CI sait produire et qui manquent** (`.github/workflows/build.yml:458-461`, `:542`) : `app-business`, `app-business-end` (bas de E1), `app-business-sales`, `app-business-results`, `app-business-recurring` (E4), `app-business-metrics` (E5), `space-business` (E14).

**Jamais capturés** : le bas de E1 (« Ventes automatiques », suivis, courbe, lignes), E4, E5, les feuilles E6 à E13 et E15, l'état vide, E3 sans Premium, la carte de Mon quotidien, les onglets « Dépenses ».

Données des captures (`Shared/Data/SampleData.swift:258-290`) : « Atelier Nova », objectif 12 000, 62 jours de ventes, 5 dépenses (Publicité, Matériel, Hébergement, Frais de paiement, Sous-traitance), 6 mois de MRR (2 100 à 3 420), indicateurs Bénéfice, Commandes, Panier moyen, Conversion, MRR, deux suivis (« Abonnés Instagram », « Devis envoyés »).

## 11. Contraintes pour la conception

1. **Garder les 27 fonctions** de la section 4, y compris celles des feuilles : choix des 11 indicateurs (F8), « Ce fichier contient » et les opérations non payées (F15), conversion et « sans conversion » (F16), garder ou retirer les ventes de Stripe (F19), Premium arrêté (F20), suivis avec objectif et courbe (F14), mois de MRR (F13).
2. **Dire ce qui est nouveau.** Tout ce qui est dans la liste de la section 9 porte la mention « nouvelle idée ». Aucune donnée d'exemple dans la vraie app.
3. **Ne pas changer les données ni les calculs** (section 5). Une catégorie de dépense, un objectif annuel ou une facture sont du développement, pas de l'habillage.
4. **Gratuit et Premium inchangés** : saisie à la main gratuite ; import CSV, Stripe, analyse mois par mois et 6 widgets en Premium ; rien de saisi n'est verrouillé ; « Déconnecter » toujours possible (`Decisions.md:127`).
5. **Confidentialité** : clé restreinte `rk_` seulement, jamais de mot de passe ni de clé secrète ; trousseau ; lecture seule ; aucun serveur. La note « Les données vont directement de ton iPhone à Stripe, sans passer par Ardane. » (`BusinessSources.swift:126`) et les 3 étapes de E12 restent visibles. Montants des widgets masqués iPhone verrouillé.
6. **Une seule source de données** pour la mini-app, les widgets, Mon quotidien et « Mes informations ».
7. **Cadre commun** : `MiniAppScaffold` (sélecteur de semaine en tête, l'essentiel, le complémentaire, « Mes paramètres » en dernier), Cristal « Équilibré », une seule couleur de mini-app (problème 14).
8. **Sélecteur de semaine** : jamais de jour futur, repère des jours avec opération. Le sélecteur « Période » est un choix connu et gardé jusqu'ici (`Chantiers.md:123`) : le déplacer ou le fondre est une décision à poser au PDG.
9. **Mon quotidien** : carte `app-business`, demi-largeur par défaut (« Small » de la mission), pleine largeur possible, retirable, déplaçable ; état vide avec la phrase d'invitation.
10. **Tests** : garder les identifiants `business-hero`, `business-period`, `business-add-sale`, `business-add-cost`, `business-choose-kpis`, `business-kpis`, `kpi-<nom>`, `business-sales`, `business-results`, `business-metrics`, `business-import`, `business-import-contents`, `business-import-pending`, `business-import-unconverted`, `stripe-connect`, `stripe-connect-save`, `stripe-key`, `stripe-sync`, `stripe-sync-unconverted`, `stripe-error`, `stripe-premium-note`, `metrics-new`, `metric-name`, `metric-value`, `metric-add-value`, `recurring-update`, `sale-row`, `results-chart`. Le parcours testé : changer de période, cocher « Visiteurs », ouvrir « Ventes et dépenses » puis « Résultats » (`MiniAppUITests.swift:418-443`).
11. **Sept langues** : prévoir les libellés longs (« par rapport à la semaine dernière à la même date », « L'analyse mois par mois est dans Premium »). La légende du héros tient déjà sur 2 lignes en français.
12. **Devise** : tous les montants dans la devise de l'app ; un montant importé garde son original ; le retaper efface la conversion.
13. **Nom** : choisir un seul nom pour la mini-app et le garder partout (problème 1). Le nom de l'entreprise est un réglage de la personne.
14. **Accessibilité** : zones de toucher de 44 points, texte lisible en grande taille, libellés VoiceOver des graphiques (`BusinessApp.swift:293`, `BusinessPages.swift:184`, `:269`, `:346`).
15. **Données de planche** : reprendre « Atelier Nova » et ses chiffres (section 10) ; ne montrer aucun service que l'app ne lit pas (seuls Stripe et un fichier CSV sont réels).
