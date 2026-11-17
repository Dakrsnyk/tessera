# Audit : Entreprise (Business)

Relevé fait dans le code le 2026-11-17 (branche `main`, commit `0172244`). Lecture seule. Chaque ligne porte sa preuve (fichier:ligne). Ce qui n'a pas pu être prouvé est marqué « à vérifier ». Finance est hors mission et n'est pas relevée ici.

Chemins courts : `Business/` = `App/Screens/MiniApps/Business/`. `BusinessApp.swift`, `BusinessPages.swift`, `BusinessSources.swift` sont dans ce dossier. `MoneySpaces.swift` = `App/Screens/Spaces/MoneySpaces.swift`.

## 1. En bref

- Sert à un petit indépendant ou vendeur en ligne : on note ses ventes et ses dépenses, Ardane calcule le chiffre d'affaires, le bénéfice, la marge, le panier moyen, et compare à la période d'avant (`BusinessApp.swift:165-175`, texte d'accueil « Ton activité, chiffres à l'appui »).
- **Le nom change selon l'endroit** : cas `MiniApp.business`, titre « Business » (`App/Screens/MiniApps/MiniApp.swift:16`) ; titre de l'écran = le nom de l'entreprise saisi, par défaut « Mon entreprise » (`BusinessApp.swift:152`, `Shared/Domains/Business.swift:132`) ; widgets et catégorie « Mon entreprise » (`Shared/Model/KindCatalog.swift:18`) ; thème du Profil « Business » (`Shared/Domains/Profile.swift:21`) ; question « Ton activité » (`App/Screens/Profile/ProfileTopics.swift:529`). Le PDG dit « Entreprise ».
- Pour qui : tout le monde peut l'ouvrir (puce dans la rangée de l'accueil, carte demi-largeur dans Mon quotidien : `App/Core/DailyDefaults.swift:13`, `:17-22`). Usage prévu : quelques fois par semaine (saisie du total du jour, lecture du mois). Aucun rappel n'existe.
- État : complète pour la saisie manuelle et la lecture. Elle a 1 écran principal, 4 pages, 6 feuilles de saisie, 1 carte « Ventes automatiques » (Stripe et fichier CSV) avec 2 feuilles. Il n'existe pas : factures, clients, produits, catégories de dépenses, taxes (TPS/TVQ), export, rappels, objectif annuel, bouton flottant.
- Gratuit : toute la saisie (ventes, dépenses, MRR, indicateurs à la main), les indicateurs, la courbe, les totaux de l'année, 1 widget sur 7. Premium : import CSV, connexion et synchronisation Stripe, analyse mois par mois (page Résultats), 6 widgets.

## 2. Écrans et navigation

### Écrans, pages et feuilles (15)

| # | Écran ou feuille | Vue SwiftUI, fichier:ligne | Comment on y arrive | Ce qu'on y fait |
|---|---|---|---|---|
| E1 | Écran principal « Business » (titre = nom de l'entreprise) | `BusinessAppView`, `Business/BusinessApp.swift:111` ; `MiniApp.swift:155` | a) Accueil › rangée des mini-apps › puce « Business » (`App/Screens/Home/MiniAppsRow.swift:158`). b) Mon quotidien › carte « Business » ou carte pointillée (`App/Core/DailyBrief.swift:251`, `App/Screens/Home/DailySection.swift:445-455`). c) Toucher un widget d'entreprise : lien `tessera://space/business`, qui ouvre la mini-app (`App/Core/Router.swift:168-171`). d) Profil / Mon quotidien : la carte de données « Noter une vente » a un bouton « Tout voir » qui ouvre la page d'espace E14 (`App/Screens/Profile/DataItemViews.swift:336`), et « Créer » ouvre `SpaceView(space:)` (`App/Screens/Spaces/CreateView.swift:35`). | Lire, choisir la période, ouvrir toutes les autres vues. |
| E2 | Page « Ventes et dépenses » | `BusinessSalesPage`, `BusinessPages.swift:6` ; `MiniAppPage.businessSales` (`MiniApp.swift:119`, `:212`) | E1 › ligne « Ventes et dépenses » (`BusinessApp.swift:318`) | Choisir « Ventes » ou « Dépenses » (sélecteur « Type »), lire par mois avec le total du mois, toucher une ligne pour la modifier, « + » en haut à droite (« Nouvelle vente » / « Nouvelle dépense » selon l'onglet, `BusinessPages.swift:41-46`), balayer pour supprimer. Liste système (`List`), pas de bouton de saisie dans le corps de la page. La ligne d'une vente n'affiche ni les visiteurs ni la source (`saleDetail`, `:119-124`). |
| E3 | Page « Résultats » | `BusinessResultsPage`, `BusinessPages.swift:137` | E1 › ligne « Résultats » (`BusinessApp.swift:324`) | Graphique 6 mois (CA, dépenses, bénéfice), totaux « Depuis le 1er janvier », liste « Mois par mois ». Graphique et liste : Premium. |
| E4 | Page « Revenu récurrent » | `BusinessRecurringPage`, `BusinessPages.swift:234` | E1 › ligne « Revenu récurrent » (`BusinessApp.swift:330`) | MRR, ARR, abonnés, courbe, liste des mois, « Mettre à jour le MRR », suppression d'un mois par appui long. |
| E5 | Page « Suivis à la main » | `BusinessMetricsPage`, `BusinessPages.swift:303` | E1 › section « Suivis à la main » (si au moins 1 suivi) ou ligne du même nom (sinon) (`BusinessApp.swift:256`, `:338`) | « Nouvel indicateur », une carte par indicateur (valeur, variation, objectif, courbe), « Noter une valeur ». |
| E6 | Feuille « Vente » / « Modifier la vente » | `SaleEditor`, `MoneySpaces.swift:210` ; `BusinessSheet.sale` (`BusinessApp.swift:6`) | E1 › bouton « Vente » ; E2 › « + » ou une ligne ; carte « Noter une vente » (`App/Screens/Profile/DataItemViews.swift:248`) ; E14 | Montant, date, commandes, nouveaux clients, visiteurs, note, « Supprimer la vente ». |
| E7 | Feuille « Dépense » / « Modifier la dépense » | `BusinessCostEditor`, `MoneySpaces.swift:255` | E1 › bouton « Dépense » ; E2 (onglet Dépenses) › « + » ou une ligne ; E14 | Montant, libellé, date, « Supprimer la dépense ». |
| E8 | Feuille « Revenu récurrent » | `MRREditor`, `MoneySpaces.swift:295` | E4 › « Mettre à jour le MRR » ; E14 | Mois, MRR, abonnés (préremplis avec le dernier mois). Un même mois est remplacé. |
| E9 | Feuille « Mes indicateurs » | `KPIPicker`, `BusinessApp.swift:474` | E1 › section « Indicateurs » › « Choisir » (`:223`) | Cocher parmi 11 indicateurs (chacun avec une phrase d'explication), note de bas « Le chiffre d'affaires reste toujours en haut… », « OK » (`BusinessApp.swift:474-530`). |
| E10 | Feuille « Nouvel indicateur » / nom de l'indicateur | `MetricEditor`, `BusinessApp.swift:536` | E5 › « Nouvel indicateur » ou toucher une carte | « Nom (abonnés, devis envoyés, NPS…) », « Unité (facultatif) », bascule « Plus c'est haut, mieux c'est », bascule « Objectif » puis « Valeur visée », « Valeur d'aujourd'hui (facultatif) » (nouveau seulement), « Supprimer l'indicateur » (sans confirmation, `BusinessApp.swift:559-564`). |
| E11 | Feuille de valeur d'un suivi | `MetricValueEditor`, `BusinessApp.swift:592` | E5 › « Noter une valeur » | Valeur, date (pas de futur). Une valeur le même jour remplace l'ancienne. |
| E12 | Feuille « Connecter Stripe » | `StripeConnectSheet`, `BusinessSources.swift:424` | E1 › carte « Ventes automatiques » › « Connecter Stripe » (Premium) | 3 étapes, bouton « Ouvrir les clés API de Stripe » (ouvre `dashboard.stripe.com/apikeys`), champ sécurisé de la clé `rk_…`, « Connecter ». |
| E13 | Feuille « Importer » (aperçu du CSV) | `BusinessImportSheet`, `BusinessSources.swift:268` | E1 › « Importer un fichier CSV » (Premium) › sélecteur de fichiers | Voir le contenu du fichier, choisir « Des ventes » ou « Des dépenses » si le fichier ne le dit pas, inclure ou non les opérations non payées, conversion de devise, « Importer sans conversion », « Enregistrer ». |
| E14 | Page d'espace « Mon entreprise » (liste de réglages) | `BusinessSpaceSections` dans `SpaceView`, `MoneySpaces.swift:153` ; `App/Screens/Spaces/SpaceView.swift:82` | `SpaceView(isEmbedded: true)` depuis le Studio et le créateur d'espace (`App/Screens/Editor/SpaceOptionsSection.swift:58`, `App/Screens/Spaces/SpaceBuilderView.swift:127`) ; et par le bouton « Tout voir » de la carte « Noter une vente » du Profil (`DataItemViews.swift:336`) ; un lien d'espace `tessera://space/business`, lui, ouvre la mini-app (`Router.swift:169`) | Nom, objectif du mois, 5 chiffres, 3 boutons (vente, dépense, MRR), 15 dernières ventes (suppression par balayage). Version plus pauvre, en liste système. |
| E15 | Feuille « Mes paramètres » | `MiniAppInfoSection` (`App/Screens/MiniApps/MiniAppSettings.swift:63`) › `MiniAppInfoSheet` (`:184`) ; `BusinessApp.swift:150` | E1, dernier bloc, bouton « Mes paramètres » | Nom de l'entreprise, « Objectif de CA », « Clients » (`ProfileTopics.swift:527-557`), devise (`MiniAppSettings.swift:45`). |

### Autres feuilles, dialogues et alertes

| Élément | Où | Ce qu'il fait |
|---|---|---|
| Sélecteur de fichiers (.csv, .tsv, .txt) | `BusinessSources.swift:116` | Choisit le fichier à importer. L'aperçu s'ouvre 0,6 s après (piège iOS, `:118-123`). |
| Alerte « Import impossible » / « Import terminé » | `BusinessSources.swift:132-136`, `:171-181` | Dit pourquoi le fichier ne se lit pas, ou ce que l'import a ajouté (« 12 nouvelles opérations · … »). |
| Dialogue « Déconnecter Stripe ? » | `BusinessSources.swift:137-142` | « Déconnecter et garder les ventes », « Déconnecter et retirer ses ventes ». |
| Feuille Premium « Connecter Stripe, avec Premium » | `PaywallContext.stripeConnection`, `BusinessSources.swift:249` | Ouverte par « Connecter Stripe » ou « Synchroniser » sans Premium. |
| Feuille Premium « Importer un fichier, avec Premium » | `PaywallContext.businessImport`, `BusinessSources.swift:239` | Ouverte par « Importer un fichier CSV » sans Premium. |
| Carte verrou « L'analyse mois par mois est dans Premium » | `BusinessPages.swift:159-162` (`PremiumLockCard`, `App/Premium/PremiumLock.swift:5`) | « Découvrir Premium » dans E3. |

### Points d'entrée qui ne sont pas des écrans

| Point d'entrée | Où, fichier:ligne | Ce qu'il fait |
|---|---|---|
| Puce « Business » de l'accueil | `MiniAppsRow.swift:94-99`, `:158` | Texte « x $ ce mois » (seulement s'il y a au moins une vente). Ouvre E1. Appui long : « Masquer de l'accueil ». |
| Carte « Business » de Mon quotidien (avec données) | `DailySection.swift:445-455` ; légende de `MiniAppSummary.caption` (`App/Core/DailyCategories.swift:49-52`) | Une seule ligne de texte, « x $ ce mois ». Toute la carte ouvre E1. Demi-largeur par défaut. |
| Carte pointillée de Mon quotidien (vide) | `DailyBrief.swift:237`, `:251` | « Note tes ventes : ton chiffre d'affaires du mois apparaîtra ici. » Ouvre E1. |
| Carte « À remplir » en tête de E1 | `App/Screens/MiniApps/MiniAppToFill.swift:15` ; `DataItemViews.swift:238-246` | Champ « Chaque mois » (objectif de CA). N'apparaît que tant que l'objectif n'est pas donné. |
| Question « Ton activité » et « Chaque mois » | `ProfileTopics.swift:527-557` | Nom, objectif de CA, nombre de clients. Mêmes données que E15. Thème « Business » de « Mes informations ». |
| Studio | `SpaceOptionsSection.swift` | Aucune option propre à l'entreprise trouvée (aucune occurrence de « business » dans ce fichier). |

## 3. Écran principal : sections dans l'ordre actuel

Écran principal = E1, `MiniAppScaffold` (`BusinessApp.swift:131-151`) : un bandeau coloré en haut, puis une « feuille » de blocs. Pas d'action flottante (le paramètre `action` du cadre n'est pas donné, contrairement à Fitness `FitnessApp.swift:34` et Finances `FinancesApp.swift:168`).

**Bandeau (en haut)**
1. **Titre de navigation** : le nom de l'entreprise (« Mon entreprise » par défaut), « Business » s'il est vide (`:152`).
2. **Sélecteur de semaine** (`WeekSelector`, `:134`) : 7 jours, pas de jour futur, un repère sur les jours qui ont une vente ou une dépense (`:180-184`).
3. **Soit l'accueil vide** (`start`, `:165-175`) : icône mallette, « Ton activité, chiffres à l'appui », phrase d'aide. Sans aucun bouton. Condition : aucune vente, aucune dépense, aucun abonnement (`:135`).
   **Soit le héros** (`hero`, `:186-214`) : sélecteur « Période » (Jour, Semaine, Mois, Année), puis « Chiffre d'affaires » en grand (`MiniHero`) avec une légende : variation en % contre la période d'avant, et en mois seulement « x % de l'objectif de y $ ».

**Feuille (sous le bandeau)**
4. **« À remplir »** (`MiniAppToFillSection`, `:143`) : l'objectif mensuel, tant qu'il n'est pas donné.
5. **Deux boutons « Vente » (principal) et « Dépense »** (`actions`, `:156-163`).
6. **« Indicateurs »** + lien « Choisir » (`kpis`, `:218-249`) : tuiles en 2 colonnes. Par défaut : Bénéfice, Commandes, Panier moyen (le CA est déjà dans le héros et n'est jamais répété, `:219`).
7. **« Ventes automatiques »** (`BusinessSourcesCard`, `:146`) : ligne Stripe, ligne « Importer un fichier CSV », note de confidentialité.
8. **« Suivis à la main »** (`metrics`, `:251-271`) : seulement s'il y en a ; 3 premiers au plus ; toute la carte ouvre E5.
9. **« Chiffre d'affaires cumulé »** (`curve`, `:275-303`) : courbe de la période contre la précédente (pointillés) ; seulement s'il y a des chiffres.
10. **Carte de lignes** (`more`, `:316-346`) : « Ventes et dépenses », « Résultats », « Revenu récurrent », et « Suivis à la main » seulement tant qu'il n'y en a aucun.
11. **« Mes paramètres »** (`MiniAppInfoSection`, `:150`).

Le choix de la période (Jour/Semaine/Mois/Année) pilote le héros, les tuiles et la courbe (`BusinessApp.swift:187`, `:238`, `:277`). Il ne pilote pas Résultats ni Ventes et dépenses.

## 4. Fonctions existantes

Liste de référence : aucune planche ne doit en perdre une. Premium : F12, F15, F16, F17, F18, F23 et 6 des 7 widgets (F24).

| N° | Fonction | Où elle est | Gratuit ou Premium | Données affichées | Actions possibles |
|---|---|---|---|---|---|
| F1 | Chiffre d'affaires de la période (héros) | E1 bandeau, `:186-214` | Gratuit | CA, variation contre la période d'avant, progression de l'objectif (mois) | Changer la période et le jour |
| F2 | Choix de la période | E1 héros, `:204-208` (id `business-period`) | Gratuit | Jour, Semaine, Mois, Année | Toucher un segment |
| F3 | Sélecteur de jour avec repères | E1 bandeau, `:134`, `:180` | Gratuit | Jours qui contiennent une opération | Choisir un jour (jamais futur) ; il fixe la fin de la période lue |
| F4 | Objectif mensuel | E1 légende (mois), E14, E15, carte « À remplir », Profil | Gratuit | « x % de l'objectif de y $ » | Donner ou changer l'objectif ; l'effacer |
| F5 | Ajouter une vente | E6 | Gratuit | Montant, date, commandes (1 par défaut), nouveaux clients, visiteurs, note | Enregistrer ; le total du jour suffit (`:169`) |
| F6 | Ajouter une dépense | E7 | Gratuit | Montant, libellé, date | Enregistrer ; libellé vide = « Dépense » (`MoneySpaces.swift:289`) |
| F7 | Modifier ou supprimer une vente ou une dépense | E2, E6, E7, E14 | Gratuit | Liste par mois, total du mois | Toucher, modifier, « Supprimer… », balayer. Retaper le montant efface le montant d'origine étranger (`MoneySpaces.swift:249`, `:290`) |
| F8 | Indicateurs affichés (11 au choix) | E1 §6, E9 | Gratuit | Chiffre d'affaires, Dépenses, Bénéfice, Marge, Commandes, Panier moyen, Nouveaux clients, Visiteurs, Conversion, MRR, Abonnés (`Business.swift:50-101`) ; valeur + variation | Cocher ou décocher. Défaut : CA, Bénéfice, Commandes, Panier moyen (`Business.swift:142`) |
| F9 | Courbe du CA cumulé contre la période d'avant | E1 §9 | Gratuit | Deux courbes ; en « Jour », la semaine (« cette semaine ») | Lecture seule |
| F10 | Page « Ventes et dépenses » | E2 | Gratuit | Ventes (détail : commandes, nouveaux clients, note) ou dépenses (libellé, date), groupées par mois avec total | Basculer, ajouter, modifier, supprimer |
| F11 | Page « Résultats » : totaux de l'année | E3 | Gratuit | « Depuis le 1er janvier » : CA, bénéfice, marge | Lecture seule |
| F12 | Page « Résultats » : analyse mois par mois | E3 | **Premium** | Graphique des 6 derniers mois (barres CA et dépenses, ligne du bénéfice), liste « Mois par mois » | Lecture seule ; sans Premium : carte verrou |
| F13 | Revenu récurrent (MRR, ARR, abonnés) | E4, E8 | Gratuit | MRR, croissance sur un mois, ARR = MRR × 12, abonnés et MRR par abonné, courbe dès 2 mois, liste | « Mettre à jour le MRR » ; supprimer un mois (appui long) |
| F14 | Suivis à la main (indicateurs perso) | E5, E10, E11, section E1 §8 | Gratuit | Nom, unité, dernière valeur, variation, objectif en %, courbe dès 2 valeurs (ligne d'objectif) | Créer, modifier, supprimer, noter une valeur (une par jour, 400 au plus) |
| F15 | Importer un fichier CSV | E1 §7, E13 | **Premium** | Nom du fichier, nombre de ventes et de dépenses, totaux, période, lignes ignorées, dernier import | Choisir le fichier, trancher ventes ou dépenses, inclure les non payées, convertir, importer |
| F16 | Conversion de devise à l'import | E13 | **Premium** (avec l'import) | Taux de la BCE du jour de chaque opération | « Réessayer », « Importer sans conversion » |
| F17 | Connexion Stripe en lecture seule | E1 §7, E12 | **Premium** | Clé (4 derniers caractères), mode test, dernière synchronisation, nouvelles opérations | Connecter par une clé restreinte `rk_` ; ouvrir le tableau de bord Stripe |
| F18 | Synchronisation Stripe | E1 §7 | **Premium** | Résultat, erreur, devises converties ou gardées | « Synchroniser » ; automatique à l'ouverture si la dernière a plus d'une heure (`StripeSync.swift:238-242`) ; « Synchroniser sans conversion » |
| F19 | Déconnecter Stripe | E1 §7 | Gratuit (toujours possible) | Message sur la clé effacée | Garder ou retirer les ventes de Stripe ; la clé est effacée du trousseau |
| F20 | État « Premium terminé » avec Stripe connecté | E1 §7 | Gratuit | « La synchronisation Stripe est dans Premium. Les ventes déjà importées restent. » (`BusinessSources.swift:42`) | Seulement « Déconnecter » |
| F21 | Nom, objectif et clients (réglages) | E15, E14, Profil | Gratuit | Nom de l'entreprise, objectif de CA, nombre de clients | Modifier. « Clients » n'est lu que par « Mes informations » (`MyInfoSection.swift:59`) |
| F22 | Devise de l'app | E15 | Gratuit | Devise | Choisir |
| F23 | Fusion sans doublon des opérations importées | `BusinessState.merge` (`BusinessImport.swift:89`) | Premium (suit l'import et Stripe) | « déjà présente », « mise à jour » | Automatique ; une vente tapée à la main n'est jamais touchée |
| F24 | 7 widgets d'entreprise | `KindCatalog.swift:204-211` | 1 gratuit, 6 Premium (§6) | | Fabriquer dans le Studio, poser sur l'écran |
| F25 | Carte de Mon quotidien et puce d'accueil | §6 | Gratuit | « x $ ce mois » | Ouvre E1 |

## 5. Données et calculs (à ne pas modifier)

Fichiers : `Shared/Domains/Business.swift` (403 lignes), `Shared/Domains/BusinessImport.swift` (973 lignes). Sauvegarde : fichier `StoreFile.business` de l'App Group (`Shared/Support/SharedStore.swift:68`) ; inclus dans les sauvegardes (`App/Core/DataBackup.swift:28`, `:132`). La clé Stripe est dans le trousseau, jamais dans les sauvegardes ni les widgets (`App/Services/StripeSync.swift:1-8`).

**Modèles**
- `BusinessState` (`Business.swift:131`) : `name` (« Mon entreprise »), `monthlyGoal` (10 000 par défaut), `sales`, `expenses`, `subscriptions`, `pinnedKPIs`, `metrics`, `connections`. Décodage tolérant (`:148-158`).
- `SalesEntry` (`:3`) : id, date, `amount`, `orders` (1), `newCustomers`, `visitors`, `note`, `source`, `externalID`, `original` (montant d'origine en devise étrangère).
- `BusinessExpense` (`:19`) : id, date, `amount`, `label`, `source`, `externalID`, `original`. **Pas de catégorie.**
- `ForeignAmount` (`:30`) : montant, devise, taux, jour du taux.
- `SubscriptionSnapshot` (`:40`) : mois, `mrr`, `subscribers`.
- `BusinessKPI` (`:50`) : 11 cas, unité (argent, pourcentage, nombre), `higherIsBetter` (sauf Dépenses), `isSnapshot` (MRR et Abonnés).
- `CustomMetric` (`:104`) : nom, unité, objectif, sens, valeurs (une par jour, 400 au plus, `:120`).
- `BusinessConnections` (`BusinessImport.swift:49`) : `StripeLink` (indice de clé, mode test, dernière synchro, `syncedUntil`, erreur, résultat, devises), `ImportRecord` (nom, date, résultat, lignes ignorées).
- `BusinessSheet` (`BusinessApp.swift:5`) : 6 feuilles. `BusinessPeriod` (`:37`) : jour, semaine, mois, année, avec textes de comparaison.

**Calculs (`BusinessMath`, `Business.swift:173-403`)**
- Période en cours et période précédente coupée au même point (`previousInterval`, `:188`) : un mois partiel se compare au même nombre de jours du mois d'avant.
- `revenue`, `costs`, `profit` (CA − dépenses), marge (bénéfice ÷ CA, absente sans CA, `:235`).
- `value(kpi…)` (`:298`) : Panier moyen = CA ÷ commandes ; Conversion = commandes ÷ visiteurs ; Visiteurs, Conversion et Marge absents sans données ; MRR et Abonnés lus au dernier instantané.
- `compare` (`:333`) : valeur actuelle contre la précédente ; pour MRR et Abonnés, ce mois contre le mois d'avant.
- `goalProgress` (`:222`) : CA du mois ÷ objectif.
- `cumulative` (`:354`) : courbe jour par jour (mois pour l'année) ; en « Jour », la semaine.
- `months(count: 6)` (`:395`) : résultats des 6 derniers mois, les mois vides du début sont retirés (`BusinessPages.swift:154`).
- `recurring` (`:278`) : dernier MRR, abonnés, croissance, ARR.
- `todayVersusLastWeek` (`:286`) : CA du jour contre le même jour d'il y a 7 jours, à la même heure (widget « Ventes du jour »).
- Import : `BusinessCSV.parse` (`BusinessImport.swift:197`), sens lu par colonnes (revenu/dépense, débit/crédit), `StripeTransactions` (`:742`), conversion BCE (`CurrencyConversion`, `:838`), `merge` (`:89`) avec sens corrigé au réimport.
- Stripe : première synchro sur 365 jours (`StripeSync.swift:63`), puis dès la veille de la dernière opération lue ; 100 pages de 100 au plus (10 000 opérations) ; clé `rk_live_` ou `rk_test_` seulement (`:123`).

## 6. Liens

**Carte de Mon quotidien**
- Catégorie `business` (`DailyBrief.swift:114`), identifiant `app-business` (`:121`), identifiant de test `daily-app-business` (`DailySection.swift:454`).
- Contenu : une seule ligne de texte, « x $ ce mois » (`MiniAppsRow.swift:99`). Sans vente : pas de légende, donc carte pointillée si la catégorie est voulue (« Note tes ventes : … », `DailyBrief.swift:237`).
- Taille : demi-largeur par défaut ; pas dans `DailyDefaults.wide` ni dans `alwaysPresent` (`DailyDefaults.swift:17-22`). Retirable et déplaçable comme les autres. Ordre par défaut : 10e sur 12 (`:13`).
- Aucun graphique, aucun anneau d'objectif, aucun bouton « Vente » sur cette carte.

**Puce de l'accueil** : même texte (`MiniAppsRow.swift:94-99`) ; appui long « Masquer de l'accueil » (`:162-170`).

**Widgets** (`Shared/Model/KindCatalog.swift:204-211`, tuiles : `Shared/Render/Tiles/BusinessTiles.swift`)

| Widget | Gratuit ou Premium | Tailles | Contenu |
|---|---|---|---|
| « Objectif du mois » (`revenueGoal`) | Gratuit | petit, moyen, cercle, rectangle | CA du mois, anneau de progression, reste par jour (`BusinessTiles.swift:21-52`) |
| « Ventes sur 30 jours » (`revenueTrend`) | Premium | petit, moyen, grand | CA jour par jour, semaine, mois |
| « Bénéfice » (`profit`) | Premium | petit, moyen | Bénéfice du mois et marge |
| « Indicateurs » (`businessKPIs`) | Premium | petit, moyen, grand | Commandes, panier moyen, nouveaux clients, conversion |
| « MRR et ARR » (`mrr`) | Premium | petit, moyen, rectangle | MRR, abonnés, croissance |
| « Ventes du jour » (`revenueToday`) | Premium | petit, moyen, rectangle, ligne | CA du jour contre le même jour la semaine dernière |
| « Tableau de bord business » (`businessDashboard`) | Premium | moyen, grand | Chiffres clés |

Toucher un widget d'entreprise : `tessera://space/business`, qui ouvre la mini-app E1 (`Shared/Render/WidgetCanvas.swift:32-34`, `Router.swift:168-171`). Les montants sont masqués quand l'iPhone est verrouillé (`docs/memoire/Decisions.md:88`, décision du 2026-11-07). Un pack « entreprise » existe (`Shared/Model/Packs.swift:65`), ainsi que des combos de boutique (`App/Screens/Explore/StoreCombos.swift`) et des écrans d'accueil composés (`HomeSetups.swift:348-353`). Couleur d'accent des exemples : `F2A33A`.

**Autres mini-apps** : aucune lecture croisée trouvée. Finances (budget) et Entreprise n'échangent rien. La conversion de devise utilise le service de taux partagé avec Voyage (`Shared/Domains/Travel.swift:349-398`).

**Notifications et rappels** : aucun. `MiniAppReminderRow` ne connaît que Fitness, Nutrition et Finances (`MiniAppSettings.swift:124-128`) ; aucune occurrence « business » dans `SmartReminders.swift` ni `SmartRemindersView.swift`.

**Liens profonds** : `tessera://space/business` (widgets) uniquement. Pas de lien vers une page (ventes, résultats…). Les routes de page `businessSales/Results/Recurring/Metrics` servent aux `NavigationLink` et aux captures (`App/Core/ScreenshotMode.swift:212-215`).

**Studio et Créer** : catégorie « Chiffre d'affaires et indicateurs » (`KindCatalog.swift:35`) ; modèle « Objectif du mois » mis en avant (`Shared/Model/Templates.swift:121`).

**Profil** : « Mes informations » › Business : Activité, Objectif, Clients, Ce mois-ci (`MyInfoSection.swift:56-60`). Thème de premières questions « Business » (`Profile.swift:21`).

**Précisions de la relecture (liens et présence)**
- Source de données du Profil : les éléments `businessGoal` (« Objectif de chiffre d'affaires ») et `sales` (« x ventes notées ») de `App/Core/DataItems.swift:33`, `:289-290`, `:422-423` ; ils pilotent « À remplir » et les cartes de données.
- Studio / Créer : `App/Screens/Spaces/SpaceCatalog.swift:14` (l'espace Entreprise compte comme « rempli » dès qu'il y a une vente), `:59` et `:86` (widgets proposés par défaut : Ventes du jour, Objectif du mois, MRR). La puce d'accueil n'apparaît comme « avec données » que s'il y a une vente (`MiniAppsRow.swift:42`).
- Chemins complets : `MyInfoSection.swift` = `App/Screens/Home/MyInfoSection.swift` ; `HomeSetups.swift` et `StoreCombos.swift` = `App/Screens/Explore/`.

## 7. États vides, première utilisation, erreurs, permissions, limites du mode gratuit

**Première utilisation**
- Aucune donnée : bandeau « Ton activité, chiffres à l'appui » (`BusinessApp.swift:165-175`, sans bouton ; les boutons sont plus bas), « À remplir » pour l'objectif.
- Dès qu'une vente, une dépense ou un abonnement existe : le héros s'affiche (`:135`).
- Objectif par défaut de 10 000 : la phrase « x % de l'objectif de 10 000 $ » s'affiche dès que la période est « Mois », même si la personne n'a jamais donné d'objectif (`:197` teste `monthlyGoal > 0`, pas `knows(.businessGoal)` ; défaut `Business.swift:133`). À vérifier à l'écran.
- Vides par vue : « Aucune vente notée pour l'instant. » / « Aucune dépense notée pour l'instant. » (E2) ; « Rien de noté pour l'instant : les mois apparaîtront ici dès la première opération. » (E3) ; « Si tu vends des abonnements, note ton revenu mensuel récurrent chaque mois… » (E4) ; « Abonnés, devis envoyés, avis clients, NPS… » (E5) ; « Choisis les indicateurs à suivre ici… » (E1 sans aucun indicateur) ; tuile « pas encore de données » ou « rien avant ».
- Courbe : cachée sans chiffre. Héros : si la période d'avant est à 0, « Rien hier à la même heure… » (`:193-195`).

**Erreurs**
- Stripe : clé non `rk_` (« Utilise une clé restreinte… »), refusée, autorisation manquante, réseau, erreur serveur, réponse illisible, taux de change manquants, clé absente de l'iPhone (restauration), synchronisation partielle (au-delà de 10 000 opérations) (`StripeSync.swift:100-112`). Message rouge sous la ligne Stripe, id `stripe-error`.
- CSV : « Le fichier n'a pas pu être lu. », « Ce fichier est trop gros pour être lu. » (> 20 Mo), « Aucune colonne de date ou de montant n'a été trouvée… », « Le fichier est vide. » (`BusinessSources.swift:183-215`). Fichier annulé : silence voulu.
- Taux BCE indisponibles à l'import : « Réessayer » ou « Importer sans conversion », message en rouge (`:357-372`).
- Aucune valeur d'exemple n'est affichée à la place d'une vraie donnée dans l'app.

**Permissions**
- Notifications, position, photos, caméra : aucune demandée.
- Réseau : seulement Stripe (`api.stripe.com`, session sans cache) et le service de taux de change.
- Fichiers : sélecteur de documents iOS (accès temporaire au fichier choisi, `:192`).
- Trousseau : clé Stripe, accessible quand l'iPhone est déverrouillé, non transférée à un autre appareil ; effacée à la réinstallation (`StripeSync.swift:47-57`).

**Limites du mode gratuit** (aucune limite de quantité : pas de plafond de ventes, dépenses ou suivis)
- Premium : import CSV (décision du 2026-11-05), connexion Stripe (décision du 2026-11-16, `Decisions.md:127`), analyse mois par mois de E3, 6 widgets sur 7.
- Rien de ce que la personne a saisi n'est verrouillé. Sans Premium, les ventes Stripe déjà lues restent, la synchronisation attend, « Déconnecter » reste possible.
- Badge « Premium » sur les lignes Stripe et CSV (`BusinessSources.swift:94`, `:109`).

## 8. Problèmes d'UX constatés aujourd'hui

1. **Quatre noms pour la même chose** : « Business » (puce, titre de la mini-app, Profil), « Mon entreprise » (titre d'écran, widgets, espace), « Ton activité » (question), « Entreprise » (mot du PDG). Preuves : `MiniApp.swift:16`, `Business.swift:132`, `KindCatalog.swift:18`, `ProfileTopics.swift:529`. Le texte d'aide des widgets dit même « espace Mon entreprise » (`BusinessTiles.swift:4`).
2. **Pas d'action principale flottante.** Ajouter une vente demande de descendre sous le héros (bloc n° 5). Les autres mini-apps ont un bouton flottant (`FitnessApp.swift:34`, `FinancesApp.swift:168`). Preuve : `BusinessApp.swift:131-151` sans `action:`.
3. **Accueil vide sans bouton.** Le bandeau « Ton activité… » est un texte ; les deux boutons sont dans la feuille plus bas (`:165-175`, `:144`).
4. **L'objectif n'est visible que dans la légende du héros et seulement en « Mois »** (`:197-200`) : pas de jauge, pas d'anneau, alors que le widget « Objectif du mois » dessine un anneau (`BusinessTiles.swift:47`). Et l'objectif par défaut (10 000) s'affiche sans avoir été donné (voir §7).
5. **Le jour choisi et la période se mélangent.** Le jour fixe la fin de la période, et la période est un autre sélecteur (`:123-125`, `:204`). « Mois » + un jour du mois dernier lit le mois dernier, sans que le titre le dise. Le sélecteur de jour ne filtre ni la liste des ventes ni les pages.
6. **Le sélecteur de période ne commande que la moitié de l'écran.** Il pilote héros, tuiles et courbe mais pas Résultats (toujours mensuel) ni Ventes et dépenses (`:187`, `:238`, `:277`, `BusinessPages.swift:154`).
7. **La carte « Ventes automatiques » est un bloc d'intégration au milieu du tableau de bord**, avant les suivis et la courbe. Elle occupe 2 lignes plus une note, même pour quelqu'un qui saisit à la main (`BusinessApp.swift:146`).
8. **Les 4 pages se cachent dans une carte de lignes en bas de l'écran** (« Ventes et dépenses », « Résultats », « Revenu récurrent », parfois « Suivis à la main ») : il faut défiler pour les trouver (`:316-346`). La ligne « Suivis à la main » disparaît quand la section du même nom apparaît (`:336`).
9. **Plusieurs couleurs pour une mini-app.** Mini-app `8C6CFF` (`MiniApp.swift:44`), widgets et catégorie `C28A12` (`KindCatalog.swift:69`, `WidgetKind.swift:71`, `Profile.swift:63`), exemples de widgets `F2A33A` (`HomeSetups.swift:348`), suivis `F2A33A` (`BusinessApp.swift:339`, `:438`), résultats `3366FF` (`:325`), MRR `1E9E75` (`:331`), Stripe `635BFF`. Chaque ligne de la carte « more » a sa propre couleur.
10. **Gratuit et Premium se mélangent sur E3.** La page « Résultats » commence par un verrou pour un gratuit, puis montre les totaux de l'année (`BusinessPages.swift:159-205`) : la page paraît à moitié vide.
11. **L'origine d'une opération est invisible.** Une vente importée de Stripe ou d'un CSV a une `source`, mais la ligne n'affiche que commandes, clients et note (`BusinessPages.swift:121-126`). On ne voit ni ce qui est automatique, ni un montant converti (`original`).
12. **Aucune confirmation de suppression.** Balayer une vente ou une dépense la supprime tout de suite (`BusinessPages.swift:72-75`, `:107-110` ; `MoneySpaces.swift:195-200`). Sur E4, la suppression d'un mois est cachée sous un appui long (`BusinessPages.swift:284-290`).
13. **Pas de catégorie de dépense, pas de recherche, pas de filtre, pas de total sur la période** dans E2 : liste simple groupée par mois (`BusinessPages.swift:56-83`).
14. **La saisie est un formulaire de liste système.** « Visiteurs », « Nouveaux clients » et « Commandes » ont le même poids que le montant (`MoneySpaces.swift:226-232`) ; la saisie rapide « total du jour » n'est pas distinguée de la saisie détaillée.
15. **« Choisir » les indicateurs est un petit lien texte** à droite du titre (`BusinessApp.swift:223-226`). Les tuiles ne se touchent pas : pas de détail d'un indicateur ni d'historique (`KPITile` n'a aucune action, `:401-430`).
16. **Les suivis à la main sont limités à 3 sur l'écran principal** (`prefix(3)`, `:258`) sans « Voir les autres » autre que de toucher la carte entière.
17. **« Clients » est une donnée orpheline.** Saisie dans le Profil et E15, lue seulement par « Mes informations » (`ProfileTopics.swift:553`, `MyInfoSection.swift:59`) ; ni calcul, ni widget.
18. **Deux écrans pour les mêmes réglages.** E14 (liste système, 15 dernières ventes, nom, objectif) double E1 plus E15 avec une autre présentation (`MoneySpaces.swift:153-208`).
19. **La carte de Mon quotidien n'a qu'une ligne de texte** (« x $ ce mois ») : pas de variation, pas d'objectif, pas d'action de saisie (`DailySection.swift:448-453`).
20. **Les erreurs Stripe sont de petits textes sous la ligne**, sans action sauf « Synchroniser sans conversion » (`BusinessSources.swift:32-38`). La date de la dernière synchronisation est une phrase longue dans le détail de la ligne (`:145-151`).
21. **Aucun rappel** de noter ses ventes (voir §6), alors que Fitness, Nutrition et Finances en ont (`MiniAppSettings.swift:124-128`).
22. **Le titre de l'écran change avec le nom saisi** : une personne qui écrit « Boulangerie Léa » n'a plus de repère « Business » ; si le champ est vidé, retour à « Business » (`BusinessApp.swift:152`).

## 9. Ce que la mission du PDG cite et qui n'existe pas

`MISSION.md` ne nomme pas l'Entreprise. Elle entre dans « F. Autres mini-apps existantes » (§4 F) avec la même méthode : 5 propositions, planche complète, comparaison, recommandation, aucune mini-app fictive. Les règles générales (écran principal, sections et accès, vue détaillée, vue de gestion, vue secondaire, graphiques et indicateurs élégants) valent donc pour elle. Aucune fonction n'est citée par la mission pour cette mini-app : rien de cité n'est absent.

Absent aujourd'hui (à dessiner avec la mention « nouveau » si on l'ajoute, règle du PDG du 2026-11-15) :
- Factures, devis, liste de clients, produits ou services.
- Catégories de dépenses ; dépenses récurrentes ; pièces justificatives.
- TPS/TVQ, impôts, export comptable, export CSV. (Le besoin existe dans les demandes de l'utilisateur, `docs/memoire/Demandes.md` 23.7 et 23.8, mais pas dans l'app.)
- Objectif annuel, objectifs par indicateur sur l'écran principal, historique de l'objectif.
- Rappels de saisie, notifications de seuil.
- Bouton flottant d'ajout rapide.
- Détail d'un indicateur (toucher une tuile).
- Shopify, QuickBooks, Stripe Connect : annoncés « plus tard » (`docs/memoire/Chantiers.md:52`, `Decisions.md:16`).
- Comparaison entre deux périodes au choix, filtre par source.

## 10. Captures CI disponibles

**Aucune image dans `origin/ci-report` aujourd'hui** : 918 fichiers, 0 `.png`, 0 `.jpg`, rien dont le nom contienne « business » ou « entreprise » (relevé par `git ls-tree -r --name-only origin/ci-report`, dernier commit `170618c`).

Noms que la CI produit pour ce sujet quand un run avec captures est lancé (à redemander avant de dessiner) :

| Nom attendu | Ce que c'est | Source |
|---|---|---|
| `app-business-light.jpg` | E1, haut | `.github/workflows/build.yml:458-460` ; clé `app-business` |
| `app-business-end-light.jpg` | E1, bas (carte de lignes, « Mes paramètres ») | `build.yml:461` |
| `app-business-sales-light.jpg` | E2 | `build.yml:458`, `ScreenshotMode.swift:212` |
| `app-business-results-light.jpg` | E3 | `ScreenshotMode.swift:213` |
| `app-business-recurring-light.jpg` | E4 | `ScreenshotMode.swift:214` |
| `app-business-metrics-light.jpg` | E5 | `ScreenshotMode.swift:215` |
| `space-business` | E14 | `build.yml:542` |
| `tests/mini-app-business.png`, `mini-app-business-kpis.png`, `mini-app-business-sales.png`, `mini-app-business-results.png` | E1, E1 avec « Visiteurs » ajouté, E2, E3 | `UITests/MiniAppUITests.swift:418-440` |
| `app-business-hero`, `app-business-kpis` (pub) | héros, tuiles | `UITests/AdShotsUITests.swift:291-310` |

Les captures montrent les données de démonstration (`Shared/Data/SampleData.swift`, contenu à vérifier). Aucune capture n'existe pour les feuilles E6 à E13 ni pour l'état vide : à demander.

## 11. Contraintes pour la conception

1. **Ne perdre aucune des 25 fonctions** de la section 4, y compris celles rangées dans les feuilles : choix des 11 indicateurs (F8), conversion de devise (F16), « Synchroniser sans conversion » (F18), « Déconnecter et garder / retirer » (F19), suivis à la main avec objectif et courbe (F14), instantanés de MRR (F13).
2. **Dire clairement ce qui est nouveau** (voir §9) ; aucun chiffre ni donnée d'exemple dans la vraie app.
3. **Ne pas changer le format des données** (`BusinessState`, `SalesEntry`, `BusinessExpense`, `SubscriptionSnapshot`, `CustomMetric`, `BusinessConnections`) ni les calculs de `BusinessMath` (§5). Une catégorie de dépense, un objectif annuel ou une facture sont du développement, pas de l'habillage.
4. **Gratuit / Premium inchangé** : saisie à la main toujours gratuite ; import CSV, Stripe, analyse mois par mois et 6 widgets sur 7 en Premium ; rien de saisi n'est jamais verrouillé ; « Déconnecter » toujours possible (`Decisions.md:127`).
5. **Confidentialité** : clé Stripe restreinte `rk_` seulement (jamais `sk_`, jamais de mot de passe), gardée dans le trousseau, lecture seule, sans serveur ; montants masqués sur écran verrouillé ; la note « Les données vont directement de ton iPhone à Stripe » (`BusinessSources.swift:126`) reste visible.
6. **Une seule source de données** partagée avec les widgets, la carte de Mon quotidien, la puce d'accueil et « Mes informations ». Toute saisie passe par `model.update(\.business)`.
7. **Cadre commun** : `MiniAppScaffold` (bandeau, sélecteur de semaine en tête, essentiel, complémentaire, « Mes paramètres » en dernier) ; Cristal « Équilibré » ; palette Cristal (`category` et `strong`) ; une seule couleur de mini-app (voir problème 9) ; texte lisible avec les grandes tailles.
8. **Sélecteur de semaine** : jamais de jour futur ; les ventes et dépenses sont réelles (`BusinessApp.swift:134`). Garder le repère des jours avec opérations.
9. **Carte de Mon quotidien** : identifiant `business`, demi-largeur par défaut, deux largeurs à prévoir, retirable et déplaçable ; état vide pointillé avec phrase d'invitation (`DailyBrief.swift:237`).
10. **Accessibilité** : identifiants à conserver pour les tests (`business-hero`, `business-period`, `business-add-sale`, `business-add-cost`, `business-choose-kpis`, `kpi-<nom>`, `business-sales`, `business-results`, `business-metrics`, `business-import`, `stripe-connect`, `stripe-sync`, `stripe-error`, `metric-name`, `metric-value`, `metrics-new`, `metric-add-value`, `recurring-update`, `sale-row`, `results-chart`) ; zones de toucher de 44 points ; libellés VoiceOver des graphiques (`BusinessApp.swift:293`).
11. **Sept langues** (français, anglais, espagnol, allemand, italien, portugais du Brésil, japonais) : prévoir des libellés longs (« L'analyse mois par mois est dans Premium », « par rapport à la semaine dernière à la même date »).
12. **Devise** : tous les montants passent par `TF.money(…, currency)` ; les montants étrangers gardent leur original (`ForeignAmount`) ; un montant retapé efface la conversion.
13. **Nom** : choisir un seul nom pour la mini-app et le garder partout (voir problème 1). Le champ « nom de l'entreprise » est un réglage de l'utilisateur, pas le nom de la mini-app.
14. **Données de planche** : crédibles et marquées comme exemple ; ne pas inventer de service tiers que l'app ne lit pas (seuls Stripe et un fichier CSV sont réels).

## Relecture

- Ajouté : accès réel à E14 (« Tout voir » du Profil, `DataItemViews.swift:336`, et Créer), détails de E2 (libellés du « + », ligne sans visiteurs), champs exacts de E10, note de bas de E9, éléments `businessGoal`/`sales` du Profil, `SpaceCatalog`, chemins complets de trois fichiers.
- Corrigé : le « à vérifier » de E1 (d) et de E14 est levé ; rien d'autre de faux trouvé dans une vingtaine d'affirmations contrôlées (sections, ordre du héros, objectif par défaut de 10 000 affiché sans être donné, 7 widgets et leurs tailles, Premium sur Stripe, import et Résultats, absence de confirmation de suppression, absence de rappel, `contextMenu` du MRR, 6 cas de `BusinessSheet`). Recomptage : 15 écrans et feuilles (E1 à E15), 25 fonctions, 7 fonctions Premium (F12, F15, F16, F17, F18, F23, F24 partielle).
- Incertain : contenu exact des données de démonstration des captures, aucune image CI disponible ; accès à E14 depuis le seul menu « Mon quotidien » non prouvé ; widgets ajoutés depuis la galerie du Studio (`SpaceOptionsSection`) non relus ligne à ligne.
