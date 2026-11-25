# Audit : Voyage

Relevé refait dans le code le 2026-11-17 (branche `main`, commit `e09123e` ; le code de Voyage n'a pas changé depuis `80c7521`). Lecture seule. Chaque ligne porte sa preuve (fichier:ligne ou nom de la vue). Ce qui n'a pas pu être prouvé est marqué « à vérifier ».

Chemins courts : `TravelApp` = `App/Screens/MiniApps/Travel/TravelApp.swift` ; `TravelPages` = `App/Screens/MiniApps/Travel/TravelPages.swift` ; `Spaces` = `App/Screens/Spaces/TravelCarLifeSpaces.swift` ; `Domaine` = `Shared/Domains/Travel.swift` ; `Tuiles` = `Shared/Render/Tiles/TravelTiles.swift`.

Cette version remplace celle de 13 h 15. Les numéros F1 à F31 sont gardés. F32 à F34 sont ajoutées. Corrections principales : la rangée de puces « Mes mini-apps » n'est plus affichée sur l'accueil ; la page d'espace ne s'ouvre plus depuis l'onglet Créer ; les noms des captures CI sont précisés.

## 1. En bref

- Sert à préparer et suivre un voyage : compte à rebours, heure sur place, vols, hébergements, activités jour par jour, dépenses en plusieurs devises, liste « À ne pas oublier » (`TravelApp:46-48`, texte d'accueil `TravelApp:133`).
- Pour qui : la personne qui part en voyage. Fréquence : rare entre deux voyages, forte avant le départ et chaque jour pendant le voyage.
- C'est un vrai cas de `enum MiniApp` (`.travel`, `App/Screens/MiniApps/MiniApp.swift:6`), titre « Voyage », symbole « airplane », couleur `12A4B5` (`MiniApp.swift:17`, `:31`, `:45`).
- Un seul voyage est « actif » : celui en cours, sinon le prochain (`TravelMath.currentTrip`, `Domaine:162-168`). Tout l'écran tourne autour de lui.
- État : complète et stable, testée (`Tests/TravelCarTests.swift`, `UITests/MiniAppUITests.swift:449`). Toute la mini-app est gratuite ; seuls 5 widgets sur 7 et le pack « Voyageur » sont Premium.

## 2. Écrans et navigation

### Écrans et feuilles (12)

| # | Écran ou feuille | Vue SwiftUI, fichier:ligne | Comment on y arrive | Ce qu'on y fait |
|---|---|---|---|---|
| E1 | Écran principal « Voyage » (deux états : avec voyage actif, sans voyage actif) | `TravelAppView`, `TravelApp:49` ; ouvert par `MiniAppView` (`MiniApp.swift:157-158`) sur la pile de l'accueil (`App/Screens/Home/HomeView.swift:24-44`) | a) Mon quotidien › carte « Voyage » (`App/Screens/Home/DailySection.swift:448-457`). b) Mon quotidien › carte vide en pointillé « Voyage » (`DailySection.swift:445-447` ; texte `App/Core/DailyBrief.swift:238` ; route `:252`). c) Mon quotidien › carte « À ne pas oublier » › rappel « Départ pour <ville> » (`DailyBrief.swift:583-585`). d) « Mes informations » › pastille ou ligne « Voyage » (`App/Screens/Home/MyInfoCenter.swift:54`, `:203` ; `DailySection.swift:17-37`). e) Toucher un widget de voyage : lien `tessera://space/travel` puis `openApp(.travel)` (`Shared/Render/WidgetCanvas.swift:182-183`, `App/Core/Router.swift:168-171`). f) « Complète tes informations » si le voyage est la première donnée manquante (`DailySection.swift:44-52`, à vérifier pour l'ordre). | Voir le voyage actif, choisir un jour, ouvrir programme, budget, liste, ajouter, modifier. |
| E2 | Page « Programme » | `TravelProgramPage`, `TravelPages:7` ; route `MiniAppPage.travelProgram(UUID)` (`MiniApp.swift:123`, `:216`) | E1 › carte « Programme » (`TravelApp:148`) ou carte « À venir » (`TravelApp:188`). | 3 boutons d'ajout « Vol », « Hébergement », « Activité » (`TravelPages:19-23`). Une carte par jour qui contient quelque chose. Toucher une ligne ouvre sa feuille (`TravelPages:70`, `:88-96`). |
| E3 | Page « Budget · <ville> » | `TravelBudgetPage`, `TravelPages:101` ; route `.travelBudget` (`MiniApp.swift:124`, `:217`) | E1 › tuile « Budget » (`TravelApp:220`). | Voir « Dépensé », la jauge, le reste ; saisir « Budget du voyage » ; « Ajouter une dépense » ; anneau « Par type » ; liste « Dépenses » ; toucher une dépense pour la modifier. |
| E4 | Page « À ne pas oublier » (liste système) | `TravelChecklistPage`, `TravelPages:252` ; route `.travelChecklist` (`MiniApp.swift:125`, `:218`) | E1 › tuile « À ne pas oublier » (`TravelApp:233`). | Ajouter (champ « Ajouter (maillot, cadeaux…) »), cocher, supprimer en glissant, « Ajouter l'essentiel à emporter ». En-tête « N sur M prêts ». |
| E5 | Feuille « Voyage » (créer et modifier) | `TripEditor`, `Spaces:136` ; enveloppe `TravelSheet.trip` (`TravelApp:5`, `:24`) | a) Bouton flottant « Nouveau voyage » (sans voyage actif, `TravelApp:124-126`). b) Dialogue « Ajouter » › « Nouveau voyage » (`TravelApp:113`). c) E1 › « Mes voyages » : « Modifier le voyage », un autre voyage, ou « Nouveau voyage » (`TravelApp:282`, `:290`, `:298`). d) Carte de donnée « Voyage » › « Nouveau voyage » (bloc « À remplir » et Studio, `App/Screens/Profile/DataItemViews.swift:255-258`). e) E11 (`Spaces:44`, `:58-62`). | « Destination », « Chercher la ville (fuseau et devise) » + « Chercher », résultats, « Départ », « Retour », « Devise sur place », « Fuseau horaire ». Pas de budget, pas de bouton supprimer. |
| E6 | Feuille « Vol » | `FlightEditor`, `Spaces:199` | E2 › « Vol » ; E2 › ligne de vol ; dialogue « Ajouter » › « Vol » (`TravelApp:106`) ; E11 (`Spaces:69`, `:79-84`). | « Numéro de vol (AC 870…) », « Départ (YUL) », « Arrivée (CDG) », « Décollage », « Atterrissage », « Terminal », « Porte », « Siège ». Pas de bouton supprimer. |
| E7 | Feuille « Hébergement » | `StayEditor`, `Spaces:226` | E2 › « Hébergement » ; E2 › ligne « Arrivée · … » ou « Départ · … » ; dialogue « Ajouter » (`TravelApp:107`) ; E11 (`Spaces:89`, `:99-104`). | « Nom », « Adresse », « Arrivée », « Départ », « Numéro de réservation ». Pas de bouton supprimer. |
| E8 | Feuille « Activité » | `ActivityEditor`, `Spaces:249` | E2 › « Activité » ; E2 › ligne d'activité ; dialogue « Ajouter » (`TravelApp:108`) ; E11 (`Spaces:109`, `:119-123`). | « Activité (visite, restaurant…) », « Date et heure », « Lieu ». Pas de bouton supprimer. |
| E9 | Feuille « Dépense de voyage » ou « Modifier la dépense » | `TripExpenseEditor`, `TravelApp:356` | E3 › « Ajouter une dépense » (`TravelPages:124-126`) ou une ligne de dépense (`TravelPages:137`) ; dialogue « Ajouter » › « Dépense » (`TravelApp:109-111`). | « Montant », « Devise » (segments : devise de l'app, devise du voyage), « Type » (6 choix), « Note (facultatif) », « Date ». « Supprimer la dépense » si elle existe déjà (`TravelApp:379-386`). |
| E10 | Dialogue « Ajouter » | `confirmationDialog`, `TravelApp:104-115` | Bouton flottant « Ajouter » (voyage actif, `TravelApp:119-121`). | Choisir « Vol », « Hébergement », « Activité », « Dépense », « Nouveau voyage », « Annuler ». |
| E11 | Page de données de l'espace « Voyage » (liste système) | `SpaceView` (`App/Screens/Spaces/SpaceView.swift:5`, `:85`) + `TravelSpaceSections` (`Spaces:35-134`) | a) Studio d'un widget de voyage › « Contenu » › « Données de l'espace Voyage » (`App/Screens/Editor/SpaceOptionsSection.swift:56-72`, appelé par `KindOptionsSection.swift:211-212`). b) Carte de donnée « Voyage » › « Tout voir », une fois un voyage donné (`DataItemViews.swift:331-345` ; dans le Studio `App/Screens/Editor/EditorView.swift:582-584`). c) Mode capture `space-travel` (`App/Core/ScreenshotMode.swift:156-157`). Plus de lien depuis l'onglet Créer : il commence par la taille (`App/Screens/Spaces/CreateFlow.swift:4-12`). Aucun lien depuis E1. | Listes « Voyages », « Vols », « Hébergement », « Activités » : toucher pour modifier, glisser pour supprimer, « Nouveau voyage », « Nouveau vol », « Nouvel hébergement », « Nouvelle activité ». Section « Devise » : « Montant à convertir ». Ni budget ni liste d'affaires. |
| E12 | Feuille « Mes paramètres » | `MiniAppInfoSheet`, `App/Screens/MiniApps/MiniAppSettings.swift:184` ; bouton `MiniAppInfoSection` (`:63-85`) | E1 › dernier bouton « Mes paramètres » (`TravelApp:91`). | Un seul réglage : carte « Réglages communs », « Pour toute l'app. », « Devise » en segments CAD, USD, EUR, GBP, CHF (`MiniAppSettings.swift:46`, `:148`, `:164-172` ; `Shared/Model/Settings.swift:212`). Pas de rappel pour Voyage (`MiniAppSettings.swift:124-129`). |

### Éléments intégrés (pas des écrans)

| Élément | Où, fichier:ligne | Ce qu'il fait |
|---|---|---|
| Bloc « À remplir » | `MiniAppToFillSection(app: .travel)`, `TravelApp:77` ; `App/Screens/MiniApps/MiniAppToFill.swift:16`, `:41` | Carte « Voyage », « Ton prochain voyage : destination et dates. », pastille « À renseigner », bouton « Nouveau voyage » (`App/Core/DataItems.swift:112`, `:193`). Visible seulement tant qu'aucun voyage n'existe (`DataItems.swift:370`). |
| Résultats de ville | Dans E5, `Spaces:152-161` | Lignes sous le champ de recherche. Un toucher remplit destination (ville seule), coordonnées, fuseau, devise. Puis « Ville trouvée : heure locale activée » (`Spaces:162-166`). |
| Carte de départ « Ton prochain voyage » | `TravelApp:129-140` | Texte seul, sans bouton. Remplace le sélecteur et le bloc voyage quand il n'y a pas de voyage actif. |
| Lignes de « Mes voyages » | `TravelApp:275-307` | Ouvrent E5 (le formulaire), jamais le programme ni le budget du voyage touché. |

## 3. Écran principal : sections dans l'ordre actuel

Écran E1 (`TravelAppView.body`, `TravelApp:61-116`). Cadre commun `MiniAppScaffold` : nappe de couleur en haut, en-tête sur verre, puis cartes, bouton flottant au-dessus de la barre d'onglets (`App/Screens/MiniApps/MiniAppScaffold.swift:30-77`). Titre « Voyage ».

**Avec un voyage actif (en cours ou à venir)**

1. **Sélecteur de semaine** (`WeekSelector`, `TravelApp:69-71`). Sept jours, flèches de semaine, bouton « Aujourd'hui ». Un point creux sous les jours qui ont un élément au programme. Jours futurs permis. À l'ouverture, il se place sur le premier jour d'un voyage à venir (`TravelApp:94-99`).
2. **Bloc voyage** (`TripHero`, `TravelApp:72`, `:312-353`). Petite ligne « <VILLE> · EN VOYAGE » ou « <VILLE> · PROCHAIN VOYAGE ». En grand : « Jour 4 / 10 », ou « Départ dans N jours », « Départ demain », « Départ aujourd'hui ». Dessous : les dates (avant le départ) et « Heure locale 15:40 » si le fuseau diffère de celui du téléphone. Mis à jour chaque minute. Ne se touche pas.
3. **« À remplir »** (`TravelApp:77`). Absent ici : il ne s'affiche que sans aucun voyage.
4. **« Programme »** avec la date du jour choisi à droite (`dayProgram`, `TravelApp:145-165`). Lignes du jour : vol, arrivée ou départ d'hébergement, activité, avec l'heure. Jour vide : « Rien de prévu ce jour-là. », « Vols, hébergements et activités, jour par jour », et « N j » à droite. Toute la carte ouvre E2.
5. **« À venir »** (`next`, `TravelApp:179-213`). Jusqu'à 3 lignes : prochain vol, prochain hébergement (avec le numéro de réservation à droite), prochaine activité. Ce que le programme du jour choisi montre déjà est retiré. Section absente s'il ne reste rien. Toute la carte ouvre E2.
6. **Deux tuiles côte à côte** (`TravelApp:84-87`). « Budget » : total dépensé, puis « / budget » ou « dépensés », rouge si dépassé (`TravelApp:217-228`) → E3. « À ne pas oublier » : « 3 / 9 », « N à préparer » ou « tout est prêt » en vert ; liste vide : « – » et « liste à préparer » (`TravelApp:230-242`) → E4.
7. **« Devise »** (`converter`, `TravelApp:247-268`). À droite du titre : « 1 CAD = 0,660 EUR ». Trois cases : 10, 50 et 100 unités de la devise du voyage, converties dans la devise de l'app. Note « Taux de référence de la BCE du <jour> (Frankfurter). ». Absente si la devise du voyage est celle de l'app ou si les taux manquent.
8. **« Mes voyages »** (`others`, `TravelApp:275-307`). Ligne « Modifier le voyage » (crayon) avec ville et dates. Puis les autres voyages, 4 au plus, du plus lointain au plus ancien. Puis « Nouveau voyage ».
9. **« Mes paramètres »** (`TravelApp:91`).
10. **Bouton flottant « Ajouter »** (`TravelApp:119-121`, identifiant `travel-add`) → dialogue E10. Sur la capture du run 454, il recouvre les deux tuiles au premier affichage (voir section 10).

**Sans voyage actif** (aucun voyage, ou tous finis)

1. Carte « Ton prochain voyage » : « Ajoute un voyage : compte à rebours, heure sur place, vols, hébergements, programme, budget et liste des choses à ne pas oublier, au même endroit. » (`TravelApp:129-140`). Pas de sélecteur de semaine.
2. « À remplir » avec « Nouveau voyage », seulement si aucun voyage n'a jamais été saisi.
3. « Mes voyages » : les voyages passés, 4 au plus (pas de ligne « Nouveau voyage » ici, `TravelApp:297`).
4. « Mes paramètres ».
5. Bouton flottant « Nouveau voyage » (`TravelApp:124-126`, identifiant `travel-new-trip`).

## 4. Fonctions existantes

Liste de référence : aucune planche ne doit en perdre une. 34 fonctions. Premium : F20 à F25 (6). Tout le reste est gratuit : aucun mot « Premium » ni « paywall » dans `TravelApp`, `TravelPages`, `Domaine` (recherche faite).

| # | Fonction | Où elle est | Gratuit ou Premium | Données affichées | Actions possibles |
|---|---|---|---|---|---|
| F1 | Voyage en un coup d'œil : compte à rebours ou jour du voyage, heure locale | `TripHero`, `TravelApp:312-353` (E1) | Gratuit | Ville, « EN VOYAGE » ou « PROCHAIN VOYAGE », « Jour N / total » ou jours avant le départ, dates, « Heure locale » | Lecture seule |
| F2 | Sélecteur de semaine avec marques | `WeekSelector`, `TravelApp:69-71` ; `App/Screens/MiniApps/WeekSelector.swift:23` | Gratuit | Semaine, point sous les jours avec programme | Choisir un jour, changer de semaine (flèches ou glissement), « Aujourd'hui » |
| F3 | Programme du jour choisi | `dayProgram`, `TravelApp:145-165` | Gratuit | Lignes du jour : symbole, titre, détail, heure | Ouvrir E2 |
| F4 | « À venir » : prochain vol, hébergement, activité | `next`, `TravelApp:179-213` | Gratuit | Vol (numéro, date, trajet, porte, siège), hébergement (arrivée ou départ, numéro de réservation), activité (date, lieu). Un vol reste 1 h après le décollage, une activité 30 min | Ouvrir E2 |
| F5 | Programme complet jour par jour | `TravelProgramPage`, `TravelPages:7-97` (E2) | Gratuit | Une carte par jour qui a un élément, date longue, « Jour N », lignes triées par heure | Ajouter vol, hébergement, activité ; toucher une ligne pour la modifier |
| F6 | Saisie d'un voyage | `TripEditor`, `Spaces:136-197` (E5) | Gratuit | Destination, départ, retour, devise sur place (30 codes), fuseau horaire | Créer, modifier |
| F7 | Saisie d'un vol | `FlightEditor`, `Spaces:199-224` (E6) | Gratuit | Numéro, départ, arrivée, décollage, atterrissage, terminal, porte, siège | Créer, modifier |
| F8 | Saisie d'un hébergement | `StayEditor`, `Spaces:226-247` (E7) | Gratuit | Nom, adresse, arrivée, départ, numéro de réservation | Créer, modifier |
| F9 | Saisie d'une activité | `ActivityEditor`, `Spaces:249-268` (E8) | Gratuit | Titre, date et heure, lieu | Créer, modifier |
| F10 | Budget du voyage : total, jauge, reste, reste par jour | `summary`, `TravelPages:158-200` (E3) | Gratuit | « Dépensé » dans la devise de l'app, jauge, « Il reste X sur Y » ou « Dépassé de X sur Y », « Soit X par jour jusqu'au retour » (voyage en cours), « Non converti (taux indisponible) : … », « Montants en EUR convertis au taux de référence de la BCE. » | Saisir « Budget du voyage » (enregistré pendant la frappe, `TravelPages:199`, `:205-221`) |
| F11 | Dépenses de voyage, dans la devise payée | `TripExpenseEditor`, `TravelApp:356-399` ; liste `TravelPages:131-146` | Gratuit | Montant, devise, type, note, date ; liste triée de la plus récente à la plus ancienne, avec le nombre | Ajouter, modifier, supprimer |
| F12 | Répartition « Par type » | `byKind`, `TravelPages:223-247` (E3) | Gratuit | Anneau et légende : Transport, Hébergement, Repas, Activités, Achats, Autre, avec montants | Lecture seule |
| F13 | Tuile « Budget » | `budgetTile`, `TravelApp:217-228` | Gratuit | Total dépensé, budget, rouge si dépassé | Ouvrir E3 |
| F14 | Liste « À ne pas oublier » et sa tuile | `TravelChecklistPage`, `TravelPages:252-323` ; `checklistTile`, `TravelApp:230-242` | Gratuit | Éléments, « N sur M prêts » | Ajouter, cocher, décocher, supprimer en glissant |
| F15 | « Ajouter l'essentiel à emporter » | `TravelPages:298-308` ; `addEssentials`, `Domaine:134-141` | Gratuit | 6 éléments : « Chargeur de téléphone », « Médicaments », « Carte bancaire », « Vêtements », « Trousse de toilette », « Confirmations de réservation ». À l'étranger, 3 de plus : « Passeport », « Assurance voyage », « Adaptateur de prise ». Sans doublon | Un toucher |
| F16 | Carte « Devise » : taux et conversions | `converter`, `TravelApp:247-268` | Gratuit | Taux BCE, 10 / 50 / 100 de la devise du voyage dans la devise de l'app, date du taux | Lecture seule ; taux rafraîchis à l'ouverture (`TravelApp:100-102`) |
| F17 | Recherche de ville (fuseau, devise, coordonnées) | `DestinationSearch`, `Spaces:15-33` ; dans E5 `Spaces:146-166` | Gratuit | Résultats « Ville, Pays » du géocodage Apple | Choisir un résultat |
| F18 | Widget « Départ en voyage » | `KindCatalog.swift:239` ; `Tuiles:21-46` | Gratuit | Jours avant le départ, « avant <ville> », dates ; en voyage « Jour N », « sur T · bon voyage ! ». Petit, moyen, écran verrouillé (rond, rectangle, ligne) | Toucher ouvre E1 |
| F19 | Widget « Heure sur place » | `KindCatalog.swift:242` ; `Tuiles:108-123` | Gratuit | Heure à destination, « +N h par rapport à ici » ou « même heure qu'ici », date sur place. Petit, moyen, ligne d'écran verrouillé | Toucher ouvre E1 |
| F20 | Widget « Vol » | `KindCatalog.swift:240` ; `Tuiles:48-81` | Premium | « Vol <numéro> », heure ou minuteur (moins de 12 h avant), trajet, « Terminal », « Porte », « Siège », heures de départ et d'arrivée. Petit, moyen, rectangle d'écran verrouillé | Toucher ouvre E1 (ou Premium) |
| F21 | Widget « Hôtel » | `KindCatalog.swift:241` ; `Tuiles:83-106` | Premium | Nom, adresse, « Arrivée … » ou « Départ … », « Réservation ». Petit, moyen | idem |
| F22 | Widget « Devise » | `KindCatalog.swift:243` ; `Tuiles:125-148` | Premium | « CAD → EUR », montant converti, 3 lignes de taux, « Taux de référence BCE · date · Frankfurter ». Petit, moyen | idem |
| F23 | Widget « Avancement du voyage » | `KindCatalog.swift:244` ; `Tuiles:150-176` | Premium | « N/T jours », « X jours restants » ou « dernier jour » ; avant : durée et départ. Petit, moyen, rond d'écran verrouillé | idem |
| F24 | Widget « Prochaine activité » | `KindCatalog.swift:245` ; `Tuiles:178-194` | Premium | Titre, jour et heure (fuseau du voyage), lieu, 4 activités suivantes. Petit, moyen, rectangle d'écran verrouillé | idem |
| F25 | Pack « Voyageur » (Store) | `Shared/Model/Packs.swift:68-69` ; règle Premium `:34-37` | Premium (il contient des widgets Premium) | 6 widgets : départ, vol, hôtel, avancement, heure sur place, devise | Ajouter le pack |
| F26 | Page de données de l'espace : toutes les entrées | `TravelSpaceSections`, `Spaces:35-134` (E11) | Gratuit | Voyages (ville, dates, devise), vols, hébergements, activités, triés par date | Créer, modifier, **supprimer en glissant** (seul endroit pour voyage, vol, hébergement, activité) |
| F27 | Réglage de la devise de l'app | « Mes paramètres », `MiniAppSettings.swift:164-172` (E12) | Gratuit | Devise : CAD, USD, EUR, GBP, CHF | Changer |
| F28 | Sauvegarde et effacement des données | `App/Core/DataBackup.swift:29`, `:136` ; `App/Core/AppModel.swift:747`, `:781` | Gratuit | Le fichier `travel` fait partie de la sauvegarde et de la remise à zéro | Aucun écran propre à Voyage |
| F29 | Rappel « Départ pour <ville> » dans Mon quotidien | `DailyBrief.swift:583-585` | Gratuit | Un rappel par voyage qui part aujourd'hui ou dans les 3 jours, avec « Aujourd'hui », « Demain » ou le jour | Toucher ouvre E1 |
| F30 | Carte « Voyage » de Mon quotidien | `DailySection.swift:448-457` ; phrase `App/Screens/Home/MiniAppsRow.swift:100-103` ; carte vide `DailyBrief.swift:238` | Gratuit | « <ville> · jour N » ou « <ville> · J-N » ; vide : « Ajoute un voyage : son compte à rebours apparaîtra ici. » | Toucher ouvre E1 |
| F31 | Carte de donnée « Voyage » | `DataItemViews.swift:255-258` (bloc « À remplir » de E1 et « Tes données » du Studio) | Gratuit | Prochaine ville et date, sinon « Ton prochain voyage : destination et dates. » (`DataItems.swift:426-428`, `:193`) | « Nouveau voyage » ouvre E5 ; « Tout voir » ouvre E11 |
| F32 | Bouton flottant et dialogue « Ajouter » | `TravelApp:104-126` (E10) | Gratuit | 5 choix : « Vol », « Hébergement », « Activité », « Dépense », « Nouveau voyage » | Ouvrir la feuille choisie. Dates proposées : celles du voyage. Devise de la dépense : celle du voyage s'il est en cours, sinon celle de l'app (`TravelApp:110`) |
| F33 | « Mes voyages » : liste des voyages | `others`, `TravelApp:275-307` | Gratuit | « Modifier le voyage », 4 autres voyages au plus (ville, dates ; horloge grise si passé, avion si à venir), « Nouveau voyage » | Ouvrir E5 pour le voyage touché |
| F34 | « Montant à convertir » du widget Devise | `Spaces:126-132` (E11) ; `sampleAmount`, `Domaine:109` | Gratuit (sert un widget Premium) | Montant dans la devise de l'app, 100 par défaut | Changer le montant (1 au minimum) |

## 5. Données et calculs

À ne pas modifier. Tout est dans `Shared/Domains/Travel.swift`, compilé dans l'app et dans les widgets, stocké dans l'App Group (fichier `travel`, `Shared/Support/SharedStore.swift:68` ; `Shared/Domains/StoredStates.swift:12`).

**Modèles (saisis)**
- `Trip` (`Domaine:3-16`) : `destination`, `start`, `end`, `timeZoneID` (défaut : fuseau du téléphone), `currencyCode` (défaut « EUR »), `latitude`, `longitude`, `budget` (dans la devise de l'app).
- `Flight` (`Domaine:18-28`) : `number`, `from`, `to`, `departure`, `arrival` (facultatif), `terminal`, `gate`, `seat`. Aucun identifiant de voyage.
- `Stay` (`Domaine:30-37`) : `name`, `address`, `checkIn`, `checkOut`, `confirmation`. Aucun identifiant de voyage.
- `TripActivity` (`Domaine:39-44`) : `title`, `date`, `place`. Aucun identifiant de voyage.
- `TripExpense` (`Domaine:85-93`) : `tripID`, `amount`, `currencyCode`, `kind`, `label`, `date`.
- `TripExpenseKind` (`Domaine:46-82`) : 6 types, chacun avec titre, symbole, couleur.
- `ChecklistItem` (`Domaine:96-101`) : `tripID`, `title`, `isDone`.
- `TravelState` (`Domaine:103-158`) : les listes + `sampleAmount`. Lecture tolérante des anciennes données (`Domaine:117-126`).
- Taux : `FXRates`, `FXCache`, `FXService` (`Domaine:301-346`). Source Frankfurter (taux BCE), sans clé, cache de 6 h, 30 devises (`Domaine:314-316`). `FXHistory` (`Domaine:350-453`) sert Entreprise, pas Voyage.

**Calculs (`TravelMath`, `Domaine:160-297`)**
- `currentTrip` : le voyage en cours (par jour entier), sinon le prochain (`:162-168`).
- `isOngoing`, `tripDay` : jour N sur total (`:170-180`).
- `window` : de minuit la veille du départ à la fin du lendemain du retour (`:197-201`). `flights`, `stays`, `activities(for:)` rattachent les éléments au voyage par cette fenêtre de dates (`:203-214`).
- `program` : regroupe vols, arrivées, départs d'hébergement et activités par jour, triés par heure (`:250-264`). `flightDetail` : trajet, porte, siège (`:241-247`).
- `spending` : total et total par type dans la devise de l'app ; ce qui n'a pas de taux va dans `unconverted` et ne compte pas dans le total (`:273-284`). `convert` (`:287-291`).
- `offsetHours` : décalage avec le fuseau du téléphone (`:294-296`).
- `nextFlight`, `currentStay`, `nextActivity` : pour les widgets, sur toutes les entrées, sans fenêtre de voyage (`:182-194`).
- `addEssentials`, `toggleChecklist` (`:128-141`). `deleteTrip` retire un voyage avec ses dépenses, sa liste et ses éléments (`:145-157`) ; appelé seulement par les tests (`Tests/TravelCarTests.swift:70`, `Tests/Audit24FinancesTests.swift:163`).
- « À l'étranger » pour la liste d'essentiels : devise du voyage différente de celle de l'app, ou fuseau différent (`TravelPages:300`).
- Reste par jour : (budget − dépensé) ÷ jours restants, jour courant compris (`TravelPages:169-173`).
- `TripBudgetText` : écrit et lit le champ du budget selon la langue (`TravelPages:327-357`, testé dans `Audit24FinancesTests.swift:34-42`).
- Nouveau voyage proposé : départ dans 30 jours à 9 h, retour 7 jours après (`TravelApp:36-39`).

**Données d'exemple** (captures et aperçus) : `SampleData.travel`, `Shared/Data/SampleData.swift:370-404` : Lisbonne, vol TP 258 YUL → LIS, Hôtel Alfama (HX4821), 3 activités, budget 3 200, 2 à 6 dépenses, liste d'essentiels.

## 6. Liens

**Carte de Mon quotidien**
- Catégorie `.travel`, identifiant `app-travel` (`DailyBrief.swift:114`, `:122`). Ordre par défaut : avant-dernière, après Études, Budget, Rappels, Pas, Entreprise (`App/Core/DailyDefaults.swift:11-14`).
- Présence : la carte s'affiche dès qu'un voyage actif existe (`App/Core/DailyCategories.swift:50-53`). Sans voyage : carte vide en pointillé seulement si l'intérêt « Voyage » a été choisi ou si la catégorie a été ajoutée par « + » (`DailyCategories.swift:97-104` ; `DailySection.swift:150-167`, `:1602-1603`). Sinon rien.
- Taille : demi-largeur par défaut (`DailyDefaults.swift:21` ; `DailyBrief.swift:296-304`), ce que la mission appelle « Small ». La personne peut la passer en pleine largeur (`App/Screens/Home/DailyLayoutRules.swift:14-22`). Le code n'a que ces deux largeurs.
- Contenu : en-tête « Voyage » avec l'avion, puis une seule phrase : « Lisbonne · jour 4 » ou « Lisbonne · J-18 » (`MiniAppsRow.swift:100-103`). Aucune action sur la carte. Un toucher ouvre E1.
- Rappel « Départ pour <ville> » dans la carte « À ne pas oublier » de Mon quotidien, départ aujourd'hui ou dans les 3 jours ; 4 rappels au plus, toutes sources confondues (`DailyBrief.swift:569-571`, `:583-586`).

**Widgets**
- 7 widgets (F18 à F24), tous liés à l'espace Voyage (`Shared/Model/KindCatalog.swift:239-245`). Groupe « Voyage », « Départ, vol, hôtel et devise sur place. » (`Shared/Model/WidgetGroup.swift:27`, `:67`). Widget d'écran verrouillé « Voyage » (`Widgets/DesignWidgets.swift:91-92`).
- Un toucher ouvre E1 (`WidgetCanvas.swift:182-183`, `Router.swift:168-171`). Widget Premium sans abonnement : page Premium (`WidgetCanvas.swift:162`).
- Widgets vides : « Ajoute ton voyage dans Ardane, espace Voyage. », « Ajoute ton vol dans Ardane, espace Voyage. », « Ajoute ton hébergement dans Ardane, espace Voyage. », « Planifie tes activités dans Ardane, espace Voyage. », « Ta destination utilise ta devise : rien à convertir. », « Les taux de change s'affichent dès que la connexion est disponible. » (`Tuiles:4`, `:51`, `:86`, `:181`, `:130`, `:133`).
- Rythme de mise à jour : vol et prochaine activité toutes les 15 min, devise toutes les 6 h, départ et avancement à minuit (`Widgets/DesignProvider.swift:156-157`, `:163-166`).
- Création : onglet Créer › taille › catégorie « Voyage » (`CreateFlow.swift:24-25`, `:70`) ; widgets proposés d'abord : départ + heure sur place (`App/Screens/Spaces/SpaceCatalog.swift:62`).
- Store : rayon « En voyage », « Départ, vol, hôtel et heure sur place. » (`App/Screens/Explore/StoreShowcase.swift:124-133`), pack « Voyageur » (F25), duos et écrans d'accueil étiquetés « voyage » (`App/Screens/Explore/StoreCombos.swift:102`, `:104` ; `HomeSetups.swift:54`, `:320`). Le Store est hors de cette mission.

**Autres mini-apps**
- Aucun lien direct. Les dépenses de voyage ne vont pas dans Finances (modèles séparés). La liste « À ne pas oublier » n'est pas reliée aux tâches de Planning. Les dates du voyage ne vont pas dans l'horaire.
- Partagé : la devise de l'app (Finances, Entreprise, Voyage, `MiniAppSettings.swift:45-46`) ; les taux `model.fx` (`AppModel.swift:619-621`) ; `TravelMath.convert` sert aussi aux placements (`Shared/Domains/Portfolio.swift:259`).
- Intérêt « Voyage » du premier lancement : met en avant l'espace et le rayon du Store, sans question à poser (`Shared/Domains/Profile.swift:83`, `:100`, `:118`).
- « Mes informations » : zone « Voyage » qui ouvre la mini-app (`DailySection.swift:26`).

**Notifications et rappels**
- Aucune notification pour Voyage : aucune occurrence de voyage, vol ou départ dans `App/Services/NotificationScheduler.swift`, `Shared/Support/SmartReminders.swift`, `Shared/Support/NotificationEngine.swift` (recherche faite). Pas de ligne de rappel dans « Mes paramètres » (`MiniAppSettings.swift:124-129`). Seul le rappel de Mon quotidien existe (F29).

**Liens profonds**
- Pas de lien propre à un voyage. Les widgets passent par `tessera://space/travel` (`Shared/Support/DeepLink.swift:35-37`). Pages internes : `HomeRoute.page(.travelProgram / .travelBudget / .travelChecklist)` avec l'identifiant du voyage (`MiniApp.swift:123-125`).
- Mode capture : `-screenshotScreen app-travel`, `app-travel-program`, `app-travel-budget`, `app-travel-checklist` (`ScreenshotMode.swift:171-179`, `:216-218`).

## 7. États vides, première utilisation, erreurs, permissions, limites du mode gratuit

- **Première utilisation** : carte « Ton prochain voyage », bloc « À remplir » (0 / 1) avec « Nouveau voyage », bouton flottant « Nouveau voyage » (`TravelApp:129-140`, `:77`, `:124`).
- **Tous les voyages finis** : même écran que la première utilisation, sans « À remplir », avec « Mes voyages » (passés). Arrive dès le lendemain du retour (`Domaine:162-168`).
- **Jour sans programme** : « Rien de prévu ce jour-là. » et « N j » (`TravelApp:151-152`).
- **Programme vide (E2)** : « Rien au programme pour l'instant. Ajoute tes vols, ton hébergement et ce que tu veux faire : tout se range ici jour par jour. » (`TravelPages:24-29`).
- **Liste vide** : tuile « – », « liste à préparer » ; page avec la ligne d'ajout et « Ajouter l'essentiel à emporter », pied « Ajoute les incontournables (passeport, chargeur, assurance…) sans doublon ; retire ceux qui ne te servent pas en glissant. » (`TravelPages:298-308`). Un élément ne se renomme pas et ne se déplace pas (`TravelPages:274-293`).
- **Budget** : sans budget, ni jauge ni « Il reste » ; tuile « dépensés ». Sans dépense : ni anneau ni liste (`TravelPages:128`, `:131`).
- **Taux manquant** : E3 écrit « Non converti (taux indisponible) : … » en orange et ne compte pas ces montants (`TravelPages:188-191`). E1 cache la carte « Devise » sans rien dire (`TravelApp:248`).
- **Voyage introuvable** : « Voyage introuvable » sur E2 et E3 (`TravelPages:36`, `:150`).
- **Erreurs de saisie** : « Enregistrer » est grisé, sans dire pourquoi (`App/Screens/Spaces/SpaceForms.swift:33-37`), si : destination vide ou retour avant départ (`Spaces:143`) ; numéro de vol vide ou atterrissage avant décollage (`Spaces:204`) ; nom d'hébergement vide ou départ avant arrivée (`Spaces:231`) ; titre d'activité vide (`Spaces:254`) ; montant nul (`TravelApp:366`).
- **Recherche de ville** : moins de 2 lettres, hors ligne ou ville inconnue : aucun résultat et aucun message (`Spaces:17-18`, `:150`).
- **Permissions** : aucune demande (ni position, ni notifications, ni calendrier). Réseau : taux Frankfurter (`Domaine:333`) et géocodage Apple (`Spaces:18`).
- **Limites du mode gratuit** : aucune dans la mini-app. Premium : widgets F20 à F24 (`KindCatalog.swift:240-245`) et pack F25. Gratuits : « Départ en voyage » et « Heure sur place ».

## 8. Problèmes d'UX constatés aujourd'hui

1. **Un voyage fini n'a plus rien d'accessible.** Programme, budget et liste ne s'ouvrent que depuis le voyage actif (`TravelApp:67-89`). Dès le lendemain du retour, l'écran redevient « Ton prochain voyage ». Un voyage passé n'ouvre que son formulaire (`TravelApp:290`) : impossible de revoir ou de compléter ses dépenses.
2. **Plusieurs voyages à venir : un seul visible.** `currentTrip` n'en rend qu'un (`Domaine:162-168`). Les autres sont des lignes qui ouvrent un formulaire (`TravelApp:288-295`).
3. **« Mes voyages » s'arrête à 4** (`rest.prefix(4)`, `TravelApp:288`). Les plus anciens ne sont plus atteignables dans la mini-app.
4. **Aucune suppression dans la mini-app** pour un voyage, un vol, un hébergement, une activité (feuilles sans bouton, `Spaces:136-268`), alors que la dépense en a un (`TravelApp:381`). Il faut la page d'espace E11, qui ne s'ouvre que depuis le Studio d'un widget de voyage (section 2).
5. **Supprimer un voyage dans E11 laisse ses dépenses et sa liste.** Le code retire seulement le voyage (`Spaces:53-57`) ; `deleteTrip`, qui nettoie tout, n'est pas appelé (`Domaine:145`).
6. **« Nouveau voyage » en double.** Écran vide : bouton du bloc « À remplir » et bouton flottant, même libellé, plus une carte de texte sans bouton (`TravelApp:77`, `:124`, `:129`). Écran rempli : dialogue « Ajouter » et ligne de « Mes voyages » (`TravelApp:113`, `:298`).
7. **Le bloc voyage ne se touche pas** (`TravelApp:312-328`). « Modifier le voyage » est la 8e section, tout en bas, dans « Mes voyages » (`TravelApp:282`).
8. **« Programme » et « À venir » ouvrent la même page** (`TravelApp:148`, `:188`). « À venir » retire ce que le jour choisi montre déjà : son contenu change quand on change de jour (`TravelApp:180-184`).
9. **Le sélecteur de semaine ne pilote qu'une carte.** Seul « Programme » suit le jour choisi (`TravelApp:80-81`). Le bloc voyage, « À venir », le budget, la liste et la devise ne changent pas. On peut choisir un jour hors du voyage : aucune borne (`TravelApp:69`).
10. **Une ligne du programme de E1 n'ouvre pas son élément.** Toute la carte ouvre E2 ; il faut un second toucher pour modifier (`TravelApp:148-161`). Chaque ligne porte pourtant un chevron (défaut de `MiniRow`, `MiniApp.swift:280`), alors que celles de « À venir » n'en ont pas (`TravelApp:192`).
11. **« N j » sans explication.** Sur un jour vide, le chiffre à droite est le nombre de jours qui ont un élément, pas la durée du voyage (`TravelApp:81`, `:151-152`). Le « j » est écrit en dur, hors traduction.
12. **Champs saisis, jamais montrés dans la mini-app.** « Terminal » et « Atterrissage » d'un vol ne sont lus que par le widget « Vol » (`Domaine:241-247` ; `Tuiles:62`, `:72-74`). Les coordonnées de la ville ne servent qu'à la mention « Ville trouvée » (`Spaces:155-156`, `:162`) : ni carte ni lien.
13. **Heures : deux règles.** La mini-app affiche les heures du programme dans le fuseau du téléphone et toujours sur 24 h (`TravelApp:157` ; `TravelPages:72` ; `Shared/Support/Formatting.swift:47`). Le widget « Prochaine activité » les affiche dans le fuseau du voyage et suit le réglage 12/24 h (`Tuiles:185-186` ; `TileFactory.swift:112-114`). Les sélecteurs de date n'ont pas de fuseau (`Spaces:169-170`, `:208-209`, `:234-235`, `:256`). Avant le départ, la même activité peut donc montrer deux heures différentes (déduit du code, à vérifier sur appareil).
14. **Un élément dont la date sort du voyage disparaît.** Vols, hébergements et activités n'ont pas d'identifiant de voyage : ils sont rattachés par les dates (`Domaine:203-214`). Une date hors de la fenêtre et l'élément n'est plus visible que dans E11. Deux voyages qui se suivent partagent les éléments des jours communs (fenêtres qui se recouvrent, `Domaine:197-201`).
15. **Le budget ne se saisit pas avec le voyage.** La feuille « Voyage » n'a pas de champ budget (`Spaces:143-178`). Il est en bas de la carte de E3, enregistré pendant la frappe, sans bouton (`TravelPages:176-186`, `:199`).
16. **Budget : deux limites.** « Dépensé » ignore les montants sans taux (`Domaine:276-279`). Le budget ne se donne que dans la devise de l'app (`Domaine:12-13`).
17. **Devise sur place « EUR » par défaut**, quelle que soit la devise de l'app (`Domaine:9` ; `TravelApp:36-39`). Sans recherche de ville, un voyage au pays affiche la carte « Devise » et reçoit « Passeport » dans l'essentiel (`TravelPages:300`). Une ville dont la devise n'est pas dans les 30 garde l'ancienne devise, sans message (`Spaces:158`).
18. **Deux longs sélecteurs dans la feuille « Voyage ».** « Fuseau horaire » liste tous les identifiants du système, en nom brut (« America/Toronto ») ; « Devise sur place » liste 30 codes sans nom (`Spaces:171-176`, `:181-188`).
19. **« Atterrissage » montre une heure qui n'est pas enregistrée.** Le champ affiche décollage + 7 h tant qu'on n'y touche pas ; rien n'est gardé (`Spaces:209`).
20. **Bouton flottant « Ajouter » : deux touchers pour une dépense**, le geste le plus fréquent en voyage (`TravelApp:104-115`). Au premier affichage il recouvre les tuiles « Budget » et « À ne pas oublier » (capture `mini-app-travel.png` du run 454, section 10).
21. **Carte « Devise » : montants fixes et disparition muette.** Seulement 10, 50, 100, dans un seul sens, sans saisie (`TravelApp:253`). La carte disparaît sans explication hors ligne ou si la devise est la même (`TravelApp:248`), alors que le widget, lui, l'explique (`Tuiles:130`, `:133`).
22. **Libellés qui se croisent.** « À ne pas oublier » est aussi le titre de la carte des rappels de Mon quotidien (`DailyBrief.swift:197` ; `DailySection.swift:1292`). « Programme » est aussi le programme de Fitness (`App/Screens/MiniApps/Fitness/FitnessApp.swift:443`). « Devise » nomme 5 choses : la carte de taux (`TravelApp:250`), la devise d'une dépense (`TravelApp:369`), la devise de l'app (`MiniAppSettings.swift:165`), la « Devise sur place » (`Spaces:171`), le montant du widget (`Spaces:129`).
23. **Deux styles d'écran.** Feuilles de saisie et page « À ne pas oublier » en formulaire et liste système (`SpaceForms.swift:17` ; `TravelPages:262`, `:310`) ; E1, E2, E3 en cartes Cristal (`MiniAppScroll`, `MiniRowsCard`).
24. **Pas de rappel de voyage** : ni départ, ni vol, ni liste non finie (section 6). Le seul signal est une ligne dans Mon quotidien à 3 jours du départ.
25. **Carte de Mon quotidien pauvre** : une phrase pour un voyage qui porte vol, hébergement, budget et liste ; aucune action (`DailySection.swift:448-457`).
26. **Widgets vides qui parlent d'« espace Voyage »** (4 messages, `Tuiles:4`, `:51`, `:86`, `:181`), alors qu'un toucher ouvre la mini-app.
27. **Accès long à la mini-app.** La rangée de puces « Mes mini-apps » existe dans le code mais n'est affichée nulle part (`MiniAppsRow.swift:137` ; aucun appel trouvé ; l'accueil ne contient que Mon quotidien, « Mes informations » et la bannière Premium, `HomeView.swift:82-91`). Sans voyage et sans l'intérêt « Voyage », il faut passer par « + » de Mon quotidien ou par « Mes informations ». Point commun à plusieurs mini-apps.

## 9. Ce que la mission du PDG cite et qui n'existe pas

La mission ne détaille pas Voyage. Elle le range dans « F. Autres mini-apps existantes » : même méthode, cinq propositions, une planche par proposition. Ce qu'elle cite pour toutes les mini-apps et qui manque pour Voyage :

1. **Approche « Analytique : graphiques, statistiques, évolution »** (§3). Il n'existe qu'un anneau « Par type » et une jauge de budget. Aucune courbe dans le temps, aucune statistique entre voyages.
2. **« Vue de gestion ou de personnalisation »** (§4). La gestion existe hors de la mini-app (E11) ; la personnalisation se limite à la devise de l'app (E12).
3. **Mini-apps qui « communiquent naturellement entre elles »** (§8). Aucun lien entre Voyage et Finances, Planning ou les autres.

Existe bien : la carte de Mon quotidien en petit format (§8).

Idées qui n'existent pas aujourd'hui (à présenter comme « nouvelle idée », jamais comme fonction) : consulter un voyage passé, plusieurs voyages côte à côte, carte et lien vers Plans, documents (billets, passeport), partage, notifications de voyage, supprimer depuis la mini-app, budget dans la feuille du voyage, budget par type, budget en devise locale, convertisseur avec saisie, import d'une réservation, lien avec un objectif d'épargne.

## 10. Captures CI disponibles

- **Dans `origin/ci-report` : aucune.** La référence locale est au commit `170618c` (« Build 455 », 2026-11-17 16:07 UTC) : 918 fichiers, tous `.txt` (`report.txt` et `history/…`). Aucun nom ne contient « travel » ou « voyage ». Son rapport dit « screenshots: skipped ». La branche est refaite à chaque run (`.github/workflows/build.yml:997-1004`).
- **Copies locales hors dépôt** (dossier `pub/`, ignoré par git), tirées du run 454 : `pub/rapports/design-2026-11-17-mini-apps/captures-ci-454/mini-app-travel.png` (E1, voyage en cours, relue pour cet audit), `mini-app-travel-program.png` (E2), `mini-app-travel-budget.png` (E3), `mini-app-travel-checklist.png` (E4, après ajout de « Maillot de bain »). Les trois dernières n'ont pas été relues ici.
- Noms que la CI produit pour Voyage quand elle photographie :
  - test d'interface `testTravelChecksTheListAndOpensTheProgram` (`UITests/MiniAppUITests.swift:449-474`) : `tests/mini-app-travel`, `mini-app-travel-checklist`, `mini-app-travel-budget`, `mini-app-travel-program` (préfixe `mini-app-`, `MiniAppUITests.swift:24-29`) ;
  - `[apps]` (`build.yml:462-465`) : `app-travel-light.jpg`, `app-travel-program-light.jpg`, `app-travel-budget-light.jpg`, `app-travel-checklist-light.jpg`, `app-travel-end-light.jpg` (bas de E1) ;
  - run complet (`build.yml:542`) : `space-travel-light.jpg` (E11 avec la bande de widgets).
- Toutes montrent les données d'exemple, voyage en cours à Lisbonne (`ScreenshotMode.swift:177-178`).
- Pas de capture connue : état sans voyage, voyage à venir, feuilles E5 à E10, « Mes paramètres », carte de Mon quotidien, mode sombre, widgets de voyage.

## 11. Contraintes pour la conception

1. **Ne rien retirer** : F1 à F34. À surveiller : « Ajouter l'essentiel à emporter », la carte « Devise », la recherche de ville, la jauge et le reste par jour, l'anneau « Par type », « Montant à convertir », la suppression par E11.
2. **Ne pas toucher** aux modèles ni aux calculs de la section 5 : fenêtre d'un voyage, `currentTrip`, `spending`, `convert`, `TripBudgetText`, liste d'essentiels.
3. **Un seul voyage actif.** Toute planche qui montre plusieurs voyages ouverts ou un voyage passé consulté doit le marquer « nouveau ».
4. **Vols, hébergements, activités sont rattachés par les dates**, pas par un lien. Ne pas dessiner « un voyage qui contient ses vols » comme acquis.
5. **Le programme n'a que les jours remplis**, de la veille du départ au lendemain du retour. Une frise de tous les jours est une idée nouvelle.
6. **Mini-app entièrement gratuite.** Ne pas inventer de verrou Premium. Premium : seulement les widgets F20 à F24 et le pack F25.
7. **Mon quotidien** : carte en demi-largeur, une phrase aujourd'hui. Montrer le lien avec la mini-app sans répéter les mêmes chiffres (mission §8). Deux largeurs seulement dans le code.
8. **Trois états à dessiner** : sans voyage, voyage à venir (compte à rebours, dates, heure locale), voyage en cours (« Jour N / total »). Plus l'état « tous les voyages finis ».
9. **Cadre commun** : `MiniAppScaffold`, sélecteur de semaine en tête, essentiel, complémentaire, « Mes paramètres » en dernier, une action flottante, un seul sélecteur de dates par écran (`docs/memoire/Chantiers.md:116-123`). Style Cristal « Équilibrée ». Couleur `12A4B5` ; hébergement `8C6CFF`, activité `F08A24` (`TravelApp:167-173`).
10. **Réseau et permissions** : seulement les taux Frankfurter et le géocodage Apple. Ne pas supposer carte, position, notifications ni calendrier. Prévoir l'état hors ligne (pas de taux).
11. **Devises** : la devise de l'app est commune à Finances et Entreprise (5 choix) ; la devise du voyage vient de 30 codes BCE. Les dépenses gardent leur devise d'origine.
12. **Feuilles de saisie** : 5 feuilles réelles (voyage, vol, hébergement, activité, dépense). Garder tous leurs champs. Elles servent aussi à E11, au bloc « À remplir » et au Studio.
13. **Textes** : français source par `tr("…")`, six langues. Prévoir les textes longs (« Départ dans 120 jours », ville avec pays, « À ne pas oublier » dans une demi-tuile).
14. **Identifiants de test à garder** : `travel-hero`, `travel-add`, `travel-new-trip`, `travel-add-trip`, `travel-program`, `travel-budget`, `travel-checklist`, `trip-expense-new`, `trip-budget`, `checklist-add`, `checklist-item`, `checklist-essentials`, `miniapp-settings-edit`, `mini-to-fill`.
