# Audit : Voyage

Relevé fait dans le code le 2026-11-17 (branche `main`, commit `0172244`). Lecture seule. Chaque ligne porte sa preuve (fichier:ligne ou nom de la vue). Ce qui n'a pas pu être prouvé est marqué « à vérifier ». Les chemins courts : `Travel/` = `App/Screens/MiniApps/Travel/`, `Spaces` = `App/Screens/Spaces/TravelCarLifeSpaces.swift`, `Domaine` = `Shared/Domains/Travel.swift`.

## 1. En bref

- Sert à préparer et suivre un voyage : compte à rebours, heure sur place, vols, hébergements, activités jour par jour, dépenses en devises, liste « à ne pas oublier » (`Travel/TravelApp.swift:46-48`, texte d'accueil `:133`).
- Mini-app complète (cas `MiniApp.travel`, `MiniApp.swift:6`), couleur `12A4B5` (`MiniApp.swift:45`), symbole « airplane ». Usage prévu : ponctuel, intense avant et pendant un voyage, quasi nul entre deux voyages.
- Un seul voyage est « actif » à la fois : celui en cours, sinon le prochain à venir (`TravelMath.currentTrip`, `Domaine:162`). Tout l'écran principal tourne autour de lui. Un voyage fini n'a plus ni programme, ni budget, ni liste accessibles depuis la mini-app (voir problème P3).
- État : fonctionnelle et stable, testée en logique (`Tests/TravelCarTests.swift`) et en UI (`UITests/MiniAppUITests.swift:449`). La saisie des vols, hébergements et activités est dans des feuilles partagées avec l'espace « Voyage » de Créer (`Spaces:136-268`). Il n'existe pas : suppression d'un voyage, d'un vol, d'un hébergement ou d'une activité depuis la mini-app ; carte ; documents ; rappel de départ ; mode hors ligne dédié ; partage.
- Gratuit : toute la mini-app est gratuite (aucune mention de Premium ou de paywall dans `Travel/` ni dans `Domaine`, vérifié par recherche). Premium : seulement 5 des 7 widgets de voyage et le pack « Voyageur » (section 4).

## 2. Écrans et navigation

### Écrans et feuilles (12 réels + 2 éléments intégrés : E13 et E14)

| # | Écran ou feuille | Vue SwiftUI, fichier:ligne | Comment on y arrive | Ce qu'on y fait |
|---|---|---|---|---|
| E1 | Écran principal « Voyage » | `TravelAppView`, `Travel/TravelApp.swift:49` ; routé par `MiniAppView` (`MiniApp.swift:157-158`) | a) Accueil › rangée des mini-apps › puce « Voyage » (`MiniAppsRow.swift:43`, `:100`). b) Mon quotidien › carte « Voyage » (`DailySection.swift:445-452`, `DailyBrief.swift:252`). c) Carte pointillée vide de Mon quotidien (`DailyBrief.swift:238`, `:252`). d) Toucher un widget de voyage : lien d'espace → `openApp` (`WidgetCanvas.swift:181-183`, `Router.swift:168-173`). e) Rappel « Départ pour … » (`DailyBrief.swift:584`). f) « Mes informations » › zone Voyage (`InfoArea.miniApp` et `homeRoute`, `DailySection.swift:15-37`). | Voir le voyage actif, choisir un jour, ouvrir programme, budget, liste, ajouter, modifier. |
| E2 | Page « Programme » | `TravelProgramPage`, `Travel/TravelPages.swift:7` ; route `MiniAppPage.travelProgram(UUID)` (`MiniApp.swift:123`, `:216`) | E1 › section « Programme » (carte), ou section « À venir » (même destination) (`TravelApp.swift:148`, `:188`). | 3 boutons d'ajout (« Vol », « Hébergement », « Activité »), une carte par jour du voyage, toucher une ligne pour la modifier. Titre de barre « Programme ». |
| E3 | Page « Budget · <ville> » | `TravelBudgetPage`, `TravelPages.swift:101` ; route `.travelBudget` (`MiniApp.swift:124`, `:217`) | E1 › tuile « Budget » (`TravelApp.swift:220`). | Total dépensé, jauge, budget saisi, « Ajouter une dépense », anneau « Par type », liste « Dépenses ». |
| E4 | Page « À ne pas oublier » (`List` système : ligne d'ajout « Ajouter (maillot, cadeaux…) », en-tête « N sur M prêts », pied de page « Ajoute les incontournables… ») | `TravelChecklistPage`, `TravelPages.swift:252` ; route `.travelChecklist` (`MiniApp.swift:125`, `:218`) | E1 › tuile « À ne pas oublier » (`TravelApp.swift:233`). | Ajouter, cocher, supprimer par balayage, « Ajouter l'essentiel à emporter ». |
| E5 | Feuille « Voyage » (création et modification) | `TripEditor`, `Spaces:136` ; enveloppe `TravelSheet.trip` (`TravelApp.swift:5`) | a) Bouton flottant « Nouveau voyage » (aucun voyage actif, `TravelApp.swift:124`). b) Dialogue « Ajouter » › « Nouveau voyage » (`:113`). c) E1 › « Mes voyages » › « Modifier le voyage », un voyage de la liste, ou « Nouveau voyage » (`:282`, `:290`, `:298`). d) E11 ; e) carte « À remplir » (`DataItemViews.swift:256-258`). | Destination, recherche de ville (remplit fuseau, devise, coordonnées), départ, retour, devise sur place, fuseau horaire. Pas de bouton supprimer. |
| E6 | Feuille « Vol » | `FlightEditor`, `Spaces:199` | E2 › « Vol » ; E2 › toucher une ligne de vol ; dialogue « Ajouter » › « Vol » ; E11. | Numéro, départ (code), arrivée (code), décollage, atterrissage, terminal, porte, siège. Pas de bouton supprimer. |
| E7 | Feuille « Hébergement » | `StayEditor`, `Spaces:226` | E2 › « Hébergement » ; toucher une ligne « Arrivée · … » ou « Départ · … » ; dialogue « Ajouter » ; E11. | Nom, adresse, arrivée, départ, numéro de réservation. Pas de bouton supprimer. |
| E8 | Feuille « Activité » | `ActivityEditor`, `Spaces:249` | E2 › « Activité » ; toucher une ligne d'activité ; dialogue « Ajouter » ; E11. | Titre, date et heure, lieu. Pas de bouton supprimer. |
| E9 | Feuille « Dépense de voyage » / « Modifier la dépense » (devise proposée : celle du voyage s'il est en cours, sinon celle de l'app, `TravelApp.swift:110`) | `TripExpenseEditor`, `TravelApp.swift:356` | E3 › « Ajouter une dépense » ou une ligne de dépense ; dialogue « Ajouter » › « Dépense » (`:109`). | Montant, devise (segmentée), type (6), note, date ; « Supprimer la dépense » (seule suppression de la mini-app). |
| E10 | Dialogue « Ajouter » | `confirmationDialog`, `TravelApp.swift:104` | Bouton flottant « Ajouter » (voyage actif, `:119`). | Choisir « Vol », « Hébergement », « Activité », « Dépense », « Nouveau voyage ». |
| E11 | Page d'espace « Voyage » (liste système) | `SpaceView` (`SpaceView.swift:5`) + `TravelSpaceSections` (`Spaces:35`) | a) Créer › espace « Voyage ». b) Carte « À remplir » › « Tout voir » une fois un voyage donné (`DataItemViews.swift:256`, `:331-345`). c) Studio › données de l'espace (`SpaceOptionsSection`, à vérifier pour Voyage). | Bande « Widgets de l'espace », puis listes « Voyages », « Vols », « Hébergement », « Activités » (balayage pour supprimer, bouton « + »), « Devise » (montant à convertir). Ni budget ni liste d'affaires. |
| E12 | Feuille « Mes paramètres » | `MiniAppInfoSheet`, `MiniAppSettings.swift:178` ; bouton `MiniAppInfoSection` (`:63`) | E1 › dernier bouton « Mes paramètres » (`TravelApp.swift:91`). | Une seule réglage : la devise de l'app (« Devise », segmenté, `MiniAppSettings.swift:164-170`). Pas de rappel de voyage (`:119-126` : seulement Fitness, Nutrition, Finances). |
| E13 | Bloc « À remplir » (dans E1) | `MiniAppToFillSection(app: .travel)`, `MiniAppToFill.swift:16` ; carte `.trip` (`DataItemViews.swift:256`) | Haut de la zone de contenu de E1 (`TravelApp.swift:77`), tant qu'aucun voyage n'est donné. | Bouton « Nouveau voyage » ouvre E5. |
| E14 | Liste de résultats de ville (PAS une feuille : lignes dans le formulaire E5) | dans E5, `ForEach(results)` (`Spaces:152`) | E5 › champ « Chercher la ville (fuseau et devise) » + bouton « Chercher » (actif dès 2 lettres), ou touche Entrée. | Choisir un résultat de géocodage (`CLGeocoder`, `Spaces:18`) : remplit destination (ville seule), coordonnées, fuseau, devise si elle est dans les 30 devises BCE ; puis « Ville trouvée : heure locale activée » (`Spaces:160-164`). |

### Points d'entrée qui ne sont pas des écrans

| Point d'entrée | Où, fichier:ligne | Ce qu'il fait |
|---|---|---|
| Puce « Voyage » de l'accueil | `MiniAppsRow.swift:43`, `:100-103` | Texte : « <ville> · jour N » en voyage, « <ville> · J-N » avant. Absente de données tant qu'aucun voyage. |
| Carte de Mon quotidien | `DailySection.swift:445-452` | Carte `DayCard` avec une phrase ; toute la carte ouvre E1. Aucune action dessus. |
| Rappel de Mon quotidien | `DailyBrief.swift:583-584` | « Départ pour <ville> », dans les 3 jours avant le départ, ouvre E1. |
| Lignes « Mes voyages » de E1 | `TravelApp.swift:275-307` | Ouvrent le formulaire E5 (pas le programme ni le budget du voyage touché). |

## 3. Écran principal : sections dans l'ordre actuel

Écran principal = E1 (`TravelAppView.body`, `TravelApp.swift:61`), construit avec `MiniAppScaffold` : bandeau coloré en haut, puis zone de cartes, avec un bouton flottant en bas (`MiniAppScaffold.swift:30-77`). Titre de navigation « Voyage ».

**Avec un voyage actif (en cours ou à venir)**

Bandeau (en-tête) :
1. **Sélecteur de semaine** (`WeekSelector`, `:69`) : pastille sur les jours où le programme a quelque chose ; jours futurs permis. À l'ouverture, se place sur le premier jour d'un voyage à venir (`:94-99`).
2. **Bloc voyage** (`TripHero`, `:72`, `:312`) : « <VILLE> · EN VOYAGE » ou « … · PROCHAIN VOYAGE » ; en grand « Jour 2 / 6 » (en cours) ou « Départ dans N jours » / « Départ demain » / « Départ aujourd'hui » ; ligne : dates (avant le départ) et « Heure locale hh:mm » si le fuseau diffère. Se rafraîchit chaque minute.

Zone de cartes :
3. **« À remplir »** (`MiniAppToFillSection`, `:77`), seulement si un voyage manque (donc rare ici).
4. **« Programme »** (`dayProgram`, `:145`) : le jour choisi ; lignes (vol, arrivée/départ d'hébergement, activité) avec l'heure ; vide : « Rien de prévu ce jour-là. » avec « N j » (N = jours du programme qui contiennent un élément, pas la durée du voyage). Toute la carte ouvre E2.
5. **« À venir »** (`next`, `:179`) : jusqu'à 3 lignes (prochain vol, prochain hébergement, prochaine activité) qui ne sont pas déjà dans le programme du jour choisi. Absente s'il n'y a rien. Ouvre E2.
6. **Deux tuiles côte à côte** (`:84-87`) : « Budget » (total dépensé, « / budget » ou « dépensés », rouge si dépassé) → E3 ; « À ne pas oublier » (« 3 / 9 », « N à préparer » ou « tout est prêt » vert, « – » et « liste à préparer » si vide) → E4.
7. **« Devise »** (`converter`, `:247`) : taux « 1 CAD = x EUR » et conversions de 10, 50, 100 unités de la devise locale ; note « Taux de référence de la BCE du <jour> (Frankfurter). ». Absente si la devise du voyage est celle de l'app, ou si les taux manquent.
8. **« Mes voyages »** (`others`, `:275`) : « Modifier le voyage » (ligne crayon), les autres voyages (4 au plus, du plus récent au plus ancien), « Nouveau voyage ».
9. **« Mes paramètres »** (`MiniAppInfoSection`, `:91`).
10. **Bouton flottant « Ajouter »** (`:119`, identifiant `travel-add`) → dialogue E10.

**Sans voyage actif** (aucun voyage, ou tous finis)
- Bandeau : carte de départ « Ton prochain voyage » avec le texte « Ajoute un voyage : compte à rebours, heure sur place, vols, hébergements, programme, budget et liste des choses à ne pas oublier, au même endroit. » (`:129-140`). Pas de sélecteur de semaine.
- Cartes : « À remplir », puis « Mes voyages » (voyages déjà faits, 4 au plus), puis « Mes paramètres ».
- Bouton flottant « Nouveau voyage » (`:124`, identifiant `travel-new-trip`).

## 4. Fonctions existantes

Liste de référence : aucune planche ne doit en perdre une. Toutes les fonctions de la mini-app sont gratuites ; seuls des widgets sont Premium (F20 à F24) et le pack qui les contient (F25).

| # | Fonction | Où elle est | Gratuit ou Premium | Données affichées | Actions possibles |
|---|---|---|---|---|---|
| F1 | Voyage en un coup d'œil (compte à rebours / jour du voyage) | `TripHero`, `TravelApp.swift:312` (E1) | Gratuit | Destination, état, « Jour N / total » ou jours avant départ, dates, heure locale | Lecture seule (pas de toucher) |
| F2 | Sélecteur de jour avec marques | `WeekSelector` dans E1 (`:69`) | Gratuit | Semaine, pastille si programme ce jour | Choisir un jour (pilote la carte « Programme ») |
| F3 | Programme du jour | `dayProgram`, `:145` (E1) | Gratuit | Lignes du jour : type, titre, détail, heure 24 h | Ouvrir E2 |
| F4 | « À venir » (prochain vol, hébergement, activité) | `next`, `:179` (E1) | Gratuit | Vol (numéro, date, trajet, porte, siège), hébergement (arrivée ou départ, n° réservation), activité (date, lieu). Un vol reste affiché jusqu'à 1 h après le décollage ; une activité 30 min | Ouvrir E2 |
| F5 | Programme complet jour par jour | `TravelProgramPage` (E2) | Gratuit | Un bloc par jour QUI CONTIENT quelque chose (les jours vides n'apparaissent pas, `Travel.swift:253-254`), dans la fenêtre « veille du départ → fin du lendemain du retour », « Jour N » (seulement si N ≥ 1), lignes triées par heure | Ajouter vol, hébergement, activité ; modifier une ligne |
| F6 | Saisie d'un voyage | `TripEditor` (E5) | Gratuit | Destination, départ, retour, devise, fuseau, ville trouvée | Créer, modifier, chercher une ville |
| F7 | Saisie d'un vol | `FlightEditor` (E6) | Gratuit | Numéro, codes de départ et d'arrivée, décollage, atterrissage, terminal, porte, siège | Créer, modifier |
| F8 | Saisie d'un hébergement | `StayEditor` (E7) | Gratuit | Nom, adresse, arrivée, départ, n° de réservation | Créer, modifier |
| F9 | Saisie d'une activité | `ActivityEditor` (E8) | Gratuit | Titre, date et heure, lieu | Créer, modifier |
| F10 | Budget du voyage : total, jauge, reste par jour | `TravelBudgetPage.summary`, `TravelPages.swift:158` (E3) | Gratuit | Total dépensé dans la devise de l'app, jauge, « Il reste X sur Y » ou « Dépassé de … », « Soit X par jour jusqu'au retour » (voyage en cours seulement), montants non convertis | Saisir le budget du voyage (champ, enregistré à la frappe) |
| F11 | Dépenses de voyage | `TripExpenseEditor` (E9), liste dans E3 (`:131-146`) | Gratuit | Montant, devise, type, note, date | Ajouter, modifier, supprimer |
| F12 | Répartition par type | `byKind`, `TravelPages.swift:223` (E3) | Gratuit | Anneau et liste par type (Transport, Hébergement, Repas, Activités, Achats, Autre) avec montants | Lecture seule |
| F13 | Tuile Budget | `budgetTile`, `TravelApp.swift:217` | Gratuit | Total dépensé, budget, rouge si dépassé | Ouvrir E3 |
| F14 | Liste « À ne pas oublier » | `TravelChecklistPage` (E4) et tuile `checklistTile` (`TravelApp.swift:230`) | Gratuit | Éléments, nombre prêts sur total | Ajouter, cocher, supprimer (balayage) |
| F15 | « Ajouter l'essentiel à emporter » | `TravelChecklistPage` (`:298-308`) ; `addEssentials` (`Domaine:134`) | Gratuit | 6 éléments (chargeur, médicaments, carte bancaire, vêtements, trousse, confirmations) + 3 à l'étranger (passeport, assurance, adaptateur), sans doublon | Un toucher |
| F16 | Convertisseur de devise | `converter`, `TravelApp.swift:247` | Gratuit | Taux BCE, 10 / 50 / 100 de la devise locale | Lecture seule ; actualisation auto à l'ouverture (`:100`) |
| F17 | Recherche de ville (heure locale, devise) | `DestinationSearch` (`Spaces:15`), dans `TripEditor` | Gratuit | Résultats de géocodage Apple (réseau) | Choisir un résultat |
| F18 | Widget « Départ en voyage » (`tripCountdown`) | `KindCatalog.swift:239` ; rendu `TravelTiles.countdown` | Gratuit | Compte à rebours, jour N sur total | Toucher ouvre E1 |
| F19 | Widget « Heure sur place » (`localTime`) | `KindCatalog.swift:242` ; `TravelTiles.localTime` | Gratuit | Heure à destination, décalage | idem |
| F20 | Widget « Vol » (`flight`) | `KindCatalog.swift:240` ; `TravelTiles.flight` | Premium | Heure ou minuteur, trajet, terminal, porte, siège, heures locales | idem |
| F21 | Widget « Hôtel » (`hotel`) | `KindCatalog.swift:241` | Premium | Nom, adresse, arrivée ou départ, réservation | idem |
| F22 | Widget « Devise » (`currency`) | `KindCatalog.swift:243` | Premium | Taux, montant converti (montant à convertir réglé dans E11) | idem |
| F23 | Widget « Avancement du voyage » (`tripProgress`) | `KindCatalog.swift:244` | Premium | Jour du voyage, jours restants | idem |
| F24 | Widget « Prochaine activité » (`nextActivity`) | `KindCatalog.swift:245` | Premium | Prochaine activité | idem |
| F25 | Pack « Voyageur » | `Packs.swift:68` | Premium (un pack est Premium s'il contient un widget Premium : `Packs.swift:34-35` ; ici vol, hôtel, avancement, devise) | 6 widgets : départ, vol, hôtel, avancement, heure sur place, devise (pas « Prochaine activité »), thème « aurora » | Ajouter |
| F26 | Liste de gestion d'espace (voyages, vols, hébergements, activités, montant à convertir) | `TravelSpaceSections`, `Spaces:35-134` (E11) | Gratuit | Toutes les entrées, triées par date | Créer, modifier, **supprimer par balayage** (seul endroit pour les vols, hébergements, activités, voyages) |
| F27 | Réglage de la devise de l'app | « Mes paramètres », `MiniAppSettings.swift:164` (E12) | Gratuit | Devise (CAD, EUR…) | Changer |
| F28 | Sauvegarde et effacement des données de voyage | `DataBackup.swift:29`, `:136` ; `AppModel.swift:747`, `:781` | Gratuit | Le fichier `StoreFile.travel` fait partie de la sauvegarde et de la remise à zéro générale | Aucun écran propre à Voyage |
| F29 | Rappel « Départ pour <ville> » de Mon quotidien | `DailyBrief.swift:583-584` | Gratuit | Un rappel par voyage dont le départ est dans 3 jours | Toucher ouvre E1 |
| F30 | Puce de l'accueil et carte de Mon quotidien | `MiniAppsRow.swift:100-103` ; `DailySection.swift:445-452` ; carte vide `DailyBrief.swift:238` | Gratuit | Phrase « <ville> · jour N » ou « J-N » | Toucher ouvre E1 |
| F31 | Question « Voyage » de Mes informations | `DataItemViews.swift:256-258` | Gratuit | Destination et dates | Bouton « Nouveau voyage » ouvre E5 ; « Tout voir » ouvre E11 |

## 5. Données et calculs

À ne pas modifier (la mission interdit de toucher aux calculs et aux données).

**Modèles** (`Shared/Domains/Travel.swift`, fichier partagé app + widgets, stocké dans l'App Group, `StoreFile.travel`, `SharedStore.swift:68`) :
- `Trip` (`:3`) : `id`, `destination`, `start`, `end`, `timeZoneID`, `currencyCode` (défaut « EUR »), `latitude`, `longitude`, `budget` (dans la devise de l'app).
- `Flight` (`:18`) : `number`, `from`, `to`, `departure`, `arrival?`, `terminal`, `gate`, `seat`. Aucun lien avec un voyage (rattaché par les dates).
- `Stay` (`:30`) : `name`, `address`, `checkIn`, `checkOut`, `confirmation`. Rattaché par les dates.
- `TripActivity` (`:39`) : `title`, `date`, `place`. Rattachée par les dates.
- `TripExpenseKind` (`:46`) : transport, lodging, food, activities, shopping, other (titre, symbole, couleur chacun).
- `TripExpense` (`:85`) : `tripID`, `amount`, `currencyCode`, `kind`, `label`, `date`. Rattachée par `tripID`.
- `ChecklistItem` (`:96`) : `tripID`, `title`, `isDone`.
- `TravelState` (`:103`) : listes ci-dessus + `sampleAmount` (montant des widgets de devise, 100 par défaut). Décodage tolérant (`:117`).
- `FXRates` / `FXCache` / `FXService` (`:301-346`) : taux BCE par Frankfurter, cache 6 h, 30 devises (`:316`). `FXHistory` (`:350`) sert Business, pas Voyage.

**Calculs** (`TravelMath`, `:160-297`) :
- `currentTrip` : voyage en cours (par jour entier) sinon le prochain à venir (`:162`).
- `isOngoing`, `tripDay` (jour N sur total, `:170-180`).
- `window` : de minuit la veille du départ jusqu'à minuit APRÈS le lendemain du retour, donc fin du lendemain du retour (`:197-201`) ; `flights/stays/activities(for:)` filtrent par cette fenêtre (`:203-214`).
- `program` : regroupe vols, arrivées et départs d'hébergement, activités par jour (`:250`) ; `flightDetail` (`:241`).
- `spending` : total et par type en devise de l'app, avec `unconverted` si taux absent (`:273`) ; `convert` (`:287`).
- `offsetHours` : décalage avec le fuseau du téléphone (`:294`).
- `nextFlight`, `currentStay`, `nextActivity` (`:182-194`) pour les widgets.
- `addEssentials`, `toggleChecklist`, `deleteTrip` (`:128-157`) ; `deleteTrip` n'est appelé qu'en test (voir P8).
- `TripBudgetText` (`TravelPages.swift:327`) : lecture et écriture du champ budget selon la langue.

Données de démonstration : `SampleData.travel` (Lisbonne, vol TP 258, Hôtel Alfama, 3 activités, budget 3 200, dépenses, liste) (`Shared/Data/SampleData.swift:370`).

## 6. Liens

**Carte de Mon quotidien**
- Catégorie `.travel` (`DailyBrief.swift:114`, identifiant `app-travel`), par défaut classée après Études, Budget, Rappels, Pas et Business (`DailyDefaults.swift:13`). Non « toujours présente » (`:17`) : la carte n'existe que si un voyage est donné ; sinon carte pointillée « Ajoute un voyage : son compte à rebours apparaîtra ici. » (`DailyBrief.swift:238`).
- Taille : **petite** par défaut (hors de `wide`, `DailyDefaults.swift:21`) ; la mission du PDG la confirme en « Small » (autres mini-apps sélectionnées en Small, `MISSION.md`). Contenu : `DayCard` avec une seule phrase (`DailySection.swift:445-452`) : « <ville> · jour N » ou « <ville> · J-N » (`MiniAppsRow.swift:100-103`) ; sans donnée : « Rien pour l'instant : touche pour ajouter tes données. ». Toucher : E1.
- Rappel : « Départ pour <ville> » dans le fil des rappels, dans les 3 jours avant le départ (`DailyBrief.swift:583`).

**Widgets** : 7 widgets (F18 à F24), tous liés à l'espace Voyage (`KindInfo.space = .travel`, `KindCatalog.swift:239-245`). Un toucher ouvre la mini-app E1 (`WidgetCanvas.swift:181-183`), sauf widget Premium sans abonnement : page Premium (`:162`). Groupe « Voyage » (`WidgetGroup.swift:27`), pack « Voyageur » (`Packs.swift:68`), suggestions d'espace (`SpaceCatalog.swift:62`, `:89`). Message de widget vide : « Ajoute ton voyage dans Ardane, espace Voyage. » (`TravelTiles.swift:4`) : cite « espace Voyage » et non la mini-app.

**Autres mini-apps** : aucun lien direct vers Finances (les dépenses de voyage ne vont pas dans le budget de Finances : modèles séparés) ; la devise de l'app est partagée avec Finances et Business (`MiniAppSettings.swift:46`). La liste « À ne pas oublier » du voyage est séparée des tâches de Planning. Les taux de change sont partagés (`model.fx`) avec les widgets de devise. L'objectif d'épargne « Voyage au Japon » (Finances, `SampleData.swift:241`) n'est pas relié au voyage.

**Notifications et rappels** : aucune notification propre à Voyage dans `NotificationScheduler.swift` ni `SmartReminders.swift` (aucune occurrence de voyage ; à vérifier plus finement). Pas de réglage de rappel dans « Mes paramètres » (`MiniAppSettings.swift:119-126`). Seul le rappel de Mon quotidien existe (ci-dessus).

**Liens profonds** : pas de lien dédié. Les widgets passent par `tessera://space/travel` (`DeepLink.space`, `Router.swift:168`). Le voyage actif est ouvert par `MiniApp.travel`. Les pages internes utilisent `HomeRoute.page(.travelProgram / .travelBudget / .travelChecklist)` avec l'identifiant du voyage (`MiniApp.swift:123-125`) ; le mode capture les atteint par `-screenshotScreen travel-program|travel-budget|travel-checklist` (`ScreenshotMode.swift:216-218`).

**Autres entrées** : « Mes informations » : la question « Voyage » (`DataItem.trip`, `DataItems.swift:36`, `:112`, `:193`, `:426-428`) donne la destination et les dates ; `Interest.travel` (`Profile.swift:11`) ; `MiniAppUsage.record` compte les ouvertures (`MiniApp.swift:136-138`).

## 7. États vides, première utilisation, erreurs, permissions, limites du mode gratuit

- **Première utilisation** : carte « Ton prochain voyage » + bloc « À remplir » avec « Nouveau voyage » + bouton flottant « Nouveau voyage » : trois accès au même formulaire sur le même écran (`TravelApp.swift:77`, `:129`, `:124`).
- **Programme vide du jour** : ligne « Rien de prévu ce jour-là. » avec « N j » à droite, dont le sens (nombre de jours contenant un élément, `program.count`) n'est pas expliqué (`:151-152`).
- **Programme vide** : « Rien au programme pour l'instant. Ajoute tes vols, ton hébergement et ce que tu veux faire : tout se range ici jour par jour. » (`TravelPages.swift:25`).
- **Liste vide** : tuile « – » et « liste à préparer » ; page : seulement la ligne d'ajout et le bouton « Ajouter l'essentiel à emporter » (`:272-308`).
- **Budget** : sans budget, la jauge et le « il reste » n'apparaissent pas ; tuile « dépensés ». Taux manquant : « Non converti (taux indisponible) : … » en orange (`TravelPages.swift:188-191`) ; les montants non convertis ne comptent pas dans le total. Taux absents ou hors ligne : carte « Devise » masquée sans message dans E1 (`TravelApp.swift:248`), alors que le widget dit « Les taux de change s'affichent dès que la connexion est disponible. » (`TravelTiles.swift`).
- **Voyage introuvable** : `ContentUnavailableView("Voyage introuvable")` si le voyage a disparu (E2, E3).
- **Permissions** : aucune demande d'autorisation (ni localisation, ni notifications). La recherche de ville utilise le géocodage Apple, sans demande ; en cas d'échec ou hors ligne, résultat vide sans message (`Spaces:18`, `try?`). Réseau : seulement les taux Frankfurter (`Travel.swift:333`).
- **Erreurs de saisie** : « Enregistrer » grisé si destination vide ou retour avant départ (`Spaces:143`), numéro de vol vide ou atterrissage avant décollage (`:204`), nom vide ou départ avant arrivée d'hébergement (`:231`), titre vide (`:254`), montant ≤ 0 (`TravelApp.swift:366`). La raison n'est pas affichée (à vérifier dans `SheetForm`).
- **Limites du mode gratuit** : aucune dans la mini-app. Seuls les widgets F20 à F24 sont Premium (`isPremium: true`, `KindCatalog.swift:240-245`) ; pas de contexte de paywall propre à Voyage (`PaywallContext.swift` sans occurrence).

## 8. Problèmes d'UX constatés aujourd'hui

1. **Une seule vie à la fois : un voyage fini n'a plus rien d'accessible.** Budget, programme et liste ne s'ouvrent que depuis le voyage actif (`TravelApp.swift:66-89`, `:220`, `:233`). Un voyage passé ouvre seulement le formulaire de modification (`:290`). Impossible de revoir les dépenses d'un voyage terminé.
2. **Plusieurs voyages à venir : un seul visible.** `currentTrip` ne retourne qu'un voyage (`Travel.swift:162`) ; les suivants sont des lignes qui ouvrent un formulaire, sans programme ni budget (`TravelApp.swift:288-295`).
3. **Liste « Mes voyages » limitée à 4** (`rest.prefix(4)`, `:288`) : les plus anciens ne sont pas atteignables depuis la mini-app.
4. **Aucune suppression dans la mini-app** pour voyage, vol, hébergement, activité : les feuilles n'ont pas de bouton « Supprimer » (`Spaces:136-268`), alors que la dépense en a un (`TravelApp.swift:381`). Il faut passer par Créer › Voyage (`Spaces:53`, `:74`, `:94`, `:114`).
5. **Suppression d'un voyage dans l'espace : débris.** `TravelSpaceSections` retire le voyage sans appeler `deleteTrip` (`Spaces:56`) : ses dépenses et sa liste restent orphelines, alors que `deleteTrip` existe et les nettoie (`Travel.swift:145`).
6. **Trois entrées vers « Nouveau voyage » sur l'écran vide** (carte « À remplir », bouton flottant, rien d'autre sur la carte de départ) et deux sur l'écran rempli (« Mes voyages » + dialogue « Ajouter », `TravelApp.swift:113`, `:298`).
7. **Le bloc voyage (hero) ne se touche pas** : il n'ouvre rien (`TravelApp.swift:312-328`), alors que les cartes voisines sont des liens.
8. **« Programme » et « À venir » ouvrent la même page** (`:148`, `:188`) ; « À venir » masque ce que le programme du jour affiche déjà, ce qui rend la liste difficile à prévoir.
9. **Champs saisis mais jamais affichés** : terminal et atterrissage d'un vol (`flightDetail` n'a que trajet, porte, siège, `Travel.swift:241-247`) ; adresse d'hébergement seulement sur la ligne d'arrivée ; coordonnées GPS stockées mais sans carte ni lien vers Plans.
10. **Les feuilles de saisie vivent dans le fichier de l'espace Créer** (`Spaces:136-268`) et ont une mise en forme de formulaire système, différente des cartes de la mini-app. Idem la page « À ne pas oublier » : `List` système (`TravelPages.swift:262`, `.styledList()`) au lieu de cartes `miniCard`, tandis que budget et programme sont des cartes (`MiniAppScroll`).
11. **Pas de rappel de voyage** : ni notification de départ, ni de vol, ni de liste non finie (aucun code dans `NotificationScheduler`) ; le seul signal est un rappel dans Mon quotidien à moins de 3 jours (`DailyBrief.swift:583`).
12. **Carte de Mon quotidien pauvre** : une seule phrase (« <ville> · J-N ») pour un voyage qui porte vol, hébergement, budget, liste ; pas d'action rapide (`DailySection.swift:445-452`).
13. **Budget : « Dépensé » ne tient pas compte des montants non convertis** et le champ du budget n'est qu'en devise de l'app : un budget en devise locale n'est pas possible (`TravelPages.swift:177-186`, `Travel.swift:12`).
14. **Fenêtre d'un voyage « un jour avant, deux jours après »** (`Travel.swift:197-201`) : un vol de retour tardif ou un vol de la veille s'affiche dans le programme, mais un voyage consécutif peut partager ses éléments (à vérifier sur des voyages qui se touchent).
15. **Message de widget vide parle d'« espace Voyage »** alors que l'utilisateur ouvre la mini-app (`TravelTiles.swift:4`).
16. **Bouton flottant « Ajouter » ouvre un menu de 5 choix** (`TravelApp.swift:104-115`) : deux appuis pour ajouter une dépense, l'usage le plus fréquent pendant le voyage.
17. **Carte « Devise » disparaît sans explication** hors ligne ou si la devise du voyage est celle de l'app (`TravelApp.swift:248`).

## 9. Ce que la mission du PDG cite et qui n'existe pas

Le texte de la mission (`MISSION.md`) ne détaille pas Voyage : il le range dans « Autres mini-apps existantes » (§4 F : cinq propositions, une planche complète chacune, comparaison, recommandation) et impose de s'intégrer à Mon quotidien (§8). Rien de cité par la mission n'est donc absent pour Voyage. Éléments de la mission à appliquer sans les inventer :
- Carte de Mon quotidien en **petite taille** (§8) : existe (`DailyDefaults.swift:21`).
- Vue détaillée, vue de gestion ou de personnalisation, vue secondaire (§4) : existent en partie (E2, E3, E4 ; gestion = E11/E12). Le « mode gestion » d'un voyage (supprimer, réorganiser) n'existe pas dans la mini-app.
- Idées qui n'existent PAS aujourd'hui (à présenter comme « nouvelles idées », jamais comme fonctions) : plusieurs voyages comparables, historique des voyages, carte, documents (billets, passeport), partage, rappels de voyage, objectif d'épargne lié à un voyage, budget par catégorie, budget en devise locale, suppression dans la mini-app, import de réservation (email, calendrier).

## 10. Captures CI disponibles

- La branche `ci-report` ne contient **aucune image** (0 fichier .png ou .jpg dans `git ls-tree -r --name-only origin/ci-report`) : seulement `report.txt` et le dossier `history/` (rapports texte, OCR du scanner). Aucune capture de Voyage ne peut y être lue. Le rapport courant ne mentionne pas « travel » (recherche faite dans `report.txt`).
- Captures que le test produit en CI (noms) : `travel`, `travel-checklist`, `travel-budget`, `travel-program` (`UITests/MiniAppUITests.swift:453`, `:462`, `:466-470`). Leur emplacement (artefact de run, pas dans `ci-report`) : à vérifier dans les artefacts du dernier run `[daily]`/`[apps]` (`gh run download`).
- Écran de départ du test : `-screenshotScreen app-travel` avec les données `SampleData.travel(ongoing: true)` (Lisbonne, voyage en cours) (`ScreenshotMode.swift:178`). L'état « sans voyage » et l'état « voyage à venir » : pas de capture connue (`ScreenshotMode.swift:262` vide le voyage, à vérifier).
- Pas de capture des feuilles (E5 à E9), de l'espace E11 ni de la carte de Mon quotidien.

## 11. Contraintes pour la conception

1. **Ne rien retirer** : conserver F1 à F27, y compris la liste « À ne pas oublier » et son bouton « Ajouter l'essentiel à emporter », le convertisseur BCE, la recherche de ville, la jauge de budget et l'anneau « Par type ».
2. **Ne pas toucher** aux modèles ni aux calculs de la section 5 (fenêtre d'un voyage, `spending`, `convert`, `currentTrip`, formats de `TripBudgetText`). Un nouveau champ ou un lien vol/hébergement ↔ voyage est une idée nouvelle à signaler, pas une base acquise.
3. **Un seul voyage actif** aujourd'hui : toute planche qui montre plusieurs voyages en parallèle ou un voyage passé consulté doit le marquer « nouveau ».
4. **Vols, hébergements, activités n'ont pas de lien explicite avec un voyage** : ils s'y rattachent par les dates. Ne pas dessiner un « voyage qui contient ses vols » comme acquis.
5. **Fenêtre de dates** : le programme couvre de la veille du départ à la fin du lendemain du retour (`Travel.swift:197`) et n'affiche que les jours qui ont un élément.
6. **Mini-app 100 % gratuite** : ne pas inventer de verrou Premium sur Voyage ; seuls les 5 widgets F20-F24 sont Premium.
7. **Carte de Mon quotidien en petit format**, une phrase aujourd'hui (« <ville> · jour N » ou « J-N ») ; la planche doit montrer le lien avec la mini-app et éviter de répéter les mêmes chiffres des deux côtés (mission §8).
8. **Cadre commun à respecter** : `MiniAppScaffold` (bandeau coloré `12A4B5`, `WeekSelector`, `MiniHero`, `MiniRowsCard`, `MiniStat`, bouton flottant, « À remplir », « Mes paramètres ») ; les nouvelles propositions peuvent le réorganiser mais doivent rester dans Crystal Équilibré.
9. **Réseau et permissions** : seuls les taux de change (Frankfurter) et le géocodage Apple sont utilisés ; ne pas supposer de carte, de localisation, de notifications ni de calendrier.
10. **Écrans de saisie** : 5 feuilles réelles (voyage, vol, hébergement, activité, dépense) ; garder leurs champs. La feuille « Voyage » mêle destination libre, recherche de ville (fuseau, devise, coordonnées) et réglages.
11. **Textes** : français source, clés `tr("…")`, six langues cibles ; une planche doit prévoir des textes longs (« Départ dans 120 jours », noms de villes avec pays).
12. **Identifiants de test existants** à conserver pour les UITests : `travel-hero`, `travel-add`, `travel-new-trip`, `travel-add-trip`, `travel-program`, `travel-budget`, `travel-checklist`, `trip-expense-new`, `trip-budget`, `checklist-add`, `checklist-item`, `checklist-essentials`.

## Relecture

- Ajouté : E14 précisé (lignes dans le formulaire, pas une feuille), contenu de la page E4, devise par défaut de la dépense, F28 à F31 (sauvegarde/effacement, rappel de départ, puce et carte quotidien, question « Mes informations »), détail du pack Voyageur.
- Corrigé : le programme n'affiche que les jours non vides ; la fenêtre finit à la fin du lendemain du retour (pas « 2 jours après ») ; le pack Voyageur est Premium ; « N j » = jours non vides ; recompte : 12 écrans réels (+ 2 éléments intégrés), 31 fonctions, 6 Premium (5 widgets + 1 pack).
- Incertain : E11 via Studio non vérifié ; captures CI de Voyage non relues (aucune image sur `ci-report`) ; raison du bouton « Enregistrer » grisé non affichée (SheetForm non relu).
