# Audit : Auto

Relevé fait dans le code le 2026-11-17 (branche `main`, lecture seule). Chaque ligne porte sa preuve (fichier:ligne ou nom de vue). Ce qui n'a pas pu être prouvé est marqué « à vérifier ». Les libellés sont cités tels qu'ils s'affichent en français.

## 1. En bref

- Auto sert à suivre une seule voiture : pleins, kilométrage, entretiens, échéances (assurance, immatriculation, pneus d'hiver) et coût réel par mois (`Shared/Domains/Car.swift`, `CarState`).
- C'est une vraie mini-app : cas `.car` de `MiniApp` (`App/Screens/MiniApps/MiniApp.swift:6`), titre « Auto », icône `car.fill`, couleur `6B7280` (gris ardoise, `MiniApp.swift:46`). Vue principale `CarAppView` (`App/Screens/MiniApps/Car/CarApp.swift:64`).
- Elle compte **1 écran principal, 5 pages secondaires et 6 feuilles** (4 éditeurs, « Ma voiture », « Mes paramètres »), plus la carte « À remplir » qui est une section de l'écran principal, pas une feuille (voir section 2 ; les repères « F1 à F7 » du tableau 2.1 désignent des feuilles, à ne pas confondre avec les fonctions F1 à F20 de la section 4). Tout le code est dans 2 fichiers : `CarApp.swift` (438 lignes) et `CarPages.swift` (338 lignes). Les 4 éditeurs de feuille (`FuelEditor`, `OdometerEditor`, `ServiceEditor`, `CarDeadlineEditor`) sont dans `App/Screens/Spaces/TravelCarLifeSpaces.swift:394-512`, partagés avec l'espace « Auto » de l'onglet Créer.
- Une seule voiture, pas de plusieurs véhicules (`CarState` a un seul `name`, `Car.swift:37-40`).
- Gratuit : aucune limite ni verrou Premium dans la mini-app elle-même (aucune mention de Premium dans `App/Screens/MiniApps/Car/`). Les limites Premium sont sur les widgets seulement (section 7).
- Tout est calculé sur l'appareil, sans réseau. Pas de rappel ni de notification propre à Auto (section 6).
- Sur Mon quotidien : carte « Auto » de demi-largeur qui ne montre qu'une ligne (autonomie ou compteur).

## 2. Écrans et navigation

### 2.1 Écrans, pages et feuilles

| Écran ou feuille | Vue SwiftUI, fichier:ligne | Comment on y arrive | Ce qu'on y fait |
|---|---|---|---|
| E1. Écran principal « Auto » (titre : le nom de la voiture, ou « Auto » si vide) | `CarAppView`, `CarApp.swift:64` ; ouvert par `MiniApp.car` → `CarAppView()` (`MiniApp.swift:158-159`) | Mon quotidien › carte « Auto » (`DailySection.swift:448-457`) ; puce de mini-app (`MiniAppsRow.swift`) ; toucher un widget Auto (`Router.swift:145`, lien `space` → `openApp`) ; carte vide « Auto » (`DailyBrief.swift:253`) ; ligne de « Mes informations » (`MyInfoSection.swift:71`) | Voir la semaine, le compteur, l'autonomie ; ouvrir toutes les pages ; noter un plein ou un kilométrage |
| E2. Page « Carburant » | `CarFuelPage`, `CarPages.swift:7` ; route `MiniAppPage.carFuel` (`MiniApp.swift:126`, `:219`) | E1 › tuile « Consommation » (`CarApp.swift:257`) ou, tuile cachée, ligne « Carburant » de la liste du bas (`:344`) | Noter un plein, courbe de consommation, courbe du prix au litre, liste de tous les pleins |
| E3. Page « Kilométrage » | `CarMileagePage`, `CarPages.swift:81` ; route `carMileage` | E1 › « Ce mois-ci » du haut (`CarApp.swift:133`) ou ligne « Kilométrage » de la liste (`:353`) | Compteur, moyenne par mois, noter le kilométrage, barres par mois, 12 derniers relevés |
| E4. Page « Entretien » | `CarMaintenancePage`, `CarPages.swift:140` ; route `carMaintenance` | E1 › section « Entretien » (`CarApp.swift:285`) ou ligne « Entretien » de la liste (`:361`) | Liste des entretiens avec jauge ; glisser pour « Fait aujourd'hui » ou « Supprimer » ; « Nouvel entretien » |
| E5. Page « Échéances » | `CarDeadlinesPage`, `CarPages.swift:205` ; route `carDeadlines` | E1 › section « Échéances » (`CarApp.swift:307`) ; ligne de la liste (`:370`) ; ligne de la carte « À ne pas oublier » de Mon quotidien (`DailyBrief.swift:581`) | Liste triée par date ; toucher pour modifier ; balayer pour supprimer ; « Nouvelle échéance » |
| E6. Page « Coûts » | `CarCostsPage`, `CarPages.swift:255` ; route `carCosts` | E1 › tuile « Coût réel » (`CarApp.swift:266`) ou ligne « Coûts » de la liste (`:378`) | Coût par mois, barre de répartition, coût par km ; **modifier les frais fixes en place** (5 champs) |
| F1. Feuille « Plein » / « Modifier le plein » | `FuelEditor`, `TravelCarLifeSpaces.swift:394` ; cas `CarSheet.fuel` (`CarApp.swift:6`) | Bouton « Plein » (E1 `:91`) ; ligne de plein du journal (`:228`) ; « Noter un plein » (E2 `CarPages.swift:19`) ; ligne de plein de E2 | Litres, « Total payé », « Compteur », « Plein complet », « Date » ; « Supprimer le plein » |
| F2. Feuille « Kilométrage » | `OdometerEditor`, `TravelCarLifeSpaces.swift:439` ; `CarSheet.odometer` | Bouton « Kilométrage » (E1 `:93`) ; « Noter le kilométrage » (E3 `CarPages.swift:97`) | Un seul champ « Compteur » (prérempli avec le dernier) |
| F3. Feuille « Entretien » | `ServiceEditor`, `TravelCarLifeSpaces.swift:456` ; `CarSheet.service` | Ligne d'entretien du journal (E1 `:238`) ; ligne de E4 ; « Nouvel entretien » (E4 `:178`) | Nom, « Tous les » km, « ou tous les » mois, « Dernier au compteur », « Déjà fait » + « Dernière fois », « Coût habituel » |
| F4. Feuille « Échéance » | `CarDeadlineEditor`, `TravelCarLifeSpaces.swift:485` ; `CarSheet.deadline` | Ligne ou « Nouvelle échéance » de E5 | « Titre (assurance, immatriculation…) », « Date », « Icône » (6 choix) |
| F5. Feuille « Ma voiture » | `CarSettingsEditor`, `CarApp.swift:412` ; `CarSheet.settings` | **Un seul accès** : le bouton « Indique la taille du réservoir pour voir l'autonomie » du haut de E1 (`CarApp.swift:152`), visible seulement si le réservoir est vide ET la consommation connue | « Nom de la voiture », « Réservoir » (L) |
| F6. Feuille « Mes paramètres » (« Mes infos ») | `MiniAppInfoSection` → `MiniAppInfoSheet`, `MiniAppSettings.swift:63` ; sujet `.car` (`MiniAppSettings.swift:26`) | Bouton « Mes paramètres » au bas de E1 (`CarApp.swift:103`) | Questions « Ta voiture » (marque et modèle), « Kilométrage actuel » (compteur), « Réservoir » (`ProfileTopics.swift:637-664`) |
| F7. Cartes « À remplir » | `MiniAppToFillSection`, `MiniAppToFill.swift:41` ; carte demandée `.carName` (`MiniAppToFill.swift:17`) | Haut de la feuille de E1 (`CarApp.swift:88`), tant que le nom n'est pas donné | Carte « Ta voiture » : nom et compteur (`DataItemViews.swift:268-272`) |

### 2.2 Autres endroits où les données Auto se modifient (hors mini-app)

| Où | Vue, fichier:ligne | Comment y arriver | Ce qu'on y fait |
|---|---|---|---|
| Espace « Auto » (onglet Créer) | `CarSpaceSections`, `TravelCarLifeSpaces.swift:270` ; `SpaceView.swift:86` | Créer › espace « Auto » (sous-titre « Pleins, entretiens et coûts », `Space` à `TravelCarLifeSpaces.swift`/`SpaceCatalog`) | Nom, compteur, consommation, coût par mois, « Noter un plein », « Noter le kilométrage », entretiens (« Fait », « Supprimer »), échéances, 5 frais fixes, 8 derniers pleins avec balayage « Supprimer » (`:366`) ; titres « Ma voiture », « Entretien », « Échéances », « Coûts fixes » (et non « Frais fixes ») ; entretien : balayer « Fait » / « Supprimer » ; échéances : toucher pour modifier, `onDelete`. C'est un **doublon complet** de la mini-app, en liste système |
| « Mes informations » (Accueil) | `MyInfoSection.swift:71-73` | Accueil › « Mes informations » › Auto | Lignes « Voiture » (nom) et « Compteur » |
| Cartes de données (Profil) | `DataItemViews.swift:268-276` ; `DataItems.swift:37` | Cartes `carName`, `carFills`, `carDeadlines` | « Noter un plein », « Nouvelle échéance » |

### 2.3 Navigation

- Pile `NavigationStack` de l'accueil ; les pages se poussent par `NavigationLink(value: HomeRoute.page(...))` (`CarApp.swift:133`, `:257`, `:266`, `:285`, `:307`).
- Les feuilles passent toutes par une seule `enum CarSheet: Identifiable` (`CarApp.swift:5`) et `.sheet(item: $sheet)` ; chaque page a son propre `@State sheet`.
- Re-vérifié par Grep (relecture) : aucun `.contextMenu`, `.alert(`, `.fullScreenCover`, `Picker` ni `isPremium` / `PaywallContext` dans `App/Screens/MiniApps/Car/` ; seuls `.sheet(item:)`, `NavigationLink`, `.swipeActions` (E4) et `.onDelete` (E5, qui offre aussi le balayage).
- Pas de menu `Menu`, pas de `confirmationDialog`, pas de `NavigationLink` caché : tout est visible (vérifié dans les 2 fichiers). Seul passage « caché » : les gestes de balayage (E4 : droite = « Fait aujourd'hui », gauche = « Supprimer » ; E5 : balayer = supprimer).
- Identifiants d'accessibilité utilisés par les tests : `car-hero`, `car-add-fuel`, `car-add-odometer`, `car-journal`, `car-mileage`, `car-fuel`, `car-cost`, `car-maintenance`, `car-deadlines`, `fuel-new`, `fuel-row`, `service-row`, `mileage-chart`, `car-costs`, `car-tank`.

## 3. Écran principal : sections dans l'ordre actuel

Cadre : `MiniAppScaffold` (`CarApp.swift:78`) : un voile de couleur en haut, un en-tête, puis une feuille de contenu ; pas de bouton flottant (`action` non donné).

**En-tête (haut de l'écran)**
1. Si la voiture a des données (au moins un plein, relevé, entretien ou échéance, `CarApp.swift:77`) :
   - `WeekSelector` : 7 jours de la semaine, passé et aujourd'hui seulement (`allowsFuture: false`) ; un point marque un jour avec un plein, un relevé ou un entretien fait (`hasRecord`, `:167`). Les échéances ne marquent pas de jour.
   - **Bloc « Compteur »** (`hero`, `:124`) : grand chiffre « 62 000 km » (`MiniHero`), légende « Autonomie estimée ≈ N km » ; à droite « Ce mois-ci N km » (lien vers E3, présent seulement si le kilométrage du mois est calculable, `CarApp.swift:130`) ; dessous « Environ N L dans le réservoir, d'après ta consommation depuis le plein du <date> » ; ou, sans réservoir mais avec consommation, le bouton « Indique la taille du réservoir pour voir l'autonomie ».
2. Sans aucune donnée : carte de départ « Ta voiture, sans surprise » + texte « Note tes pleins et ton kilométrage : consommation, autonomie, coût réel par mois, entretiens et échéances se suivent tout seuls. » (`start`, `:109-120`). Pas de bouton dans cette carte : l'action est dans la feuille.

**Feuille de contenu (dans l'ordre)**
1. « À remplir » : carte « Ta voiture » (`MiniAppToFillSection`, `:88`), disparaît une fois le nom donné.
2. Rangée de 2 boutons : « Plein » (accent) et « Kilométrage » (`:90-95`), toujours visibles.
3. Journal du jour choisi (`journal`, `:198`), seulement avec données : titre = la date longue, total dépensé du jour à droite ; lignes « Plein » (litres · prix/L · km), « Relevé » (km), entretien fait (nom + « Entretien » + coût) ; ou « Rien noté ce jour-là. ».
4. « Chiffres » (`stats`, `:249`) : jusqu'à 2 tuiles : « Consommation » (L/100, « N / 100 km » de coût) et « Coût réel » (« par mois, tout compris »). Chacune n'apparaît que si elle a une valeur.
5. « Entretien » (`maintenance`, `:280`) : 2 entretiens les plus avancés (« dans N km ou d'ici N j », rouge si dépassé, orange à 85 %). Seulement s'il y a des entretiens.
6. « Échéances » (`deadlines`, `:302`) : 2 prochaines (titre, date, « J-N », rouge à 14 jours ou moins). Seulement s'il y a des échéances à venir.
7. Liste « Plus » (`more`, `:333`) : lignes « Carburant », « Kilométrage », « Entretien », « Échéances », « Coûts », **chacune présente seulement si la tuile ou la section équivalente est cachée** (règle de non-doublon, commentaire `:328-331`). Une fois tout rempli, la liste disparaît.
8. « Mes paramètres » (`MiniAppInfoSection`, `:103`), bouton en dernier.

## 4. Fonctions existantes

| N° | Fonction | Où elle est | Gratuit ou Premium | Données affichées | Actions possibles |
|---|---|---|---|---|---|
| F1 | Compteur et kilométrage du mois | E1 bloc « Compteur » (`CarApp.swift:124`) ; `CarMath.odometer`, `kmThisMonth` (`Car.swift:91`, `:96`) | Gratuit | Plus grand kilométrage connu ; km depuis le premier relevé du mois | Toucher « Ce mois-ci » : ouvre E3 |
| F2 | Autonomie estimée | E1 (`CarApp.swift:125-158`) ; `CarMath.range` (`Car.swift:195`) | Gratuit | Litres restants estimés, km restants, depuis le dernier plein complet, avec les pleins partiels ajoutés | Aucune ; sans réservoir, un bouton ouvre F5 |
| F3 | Noter un plein | Boutons « Plein » (E1, E2), F1 | Gratuit | Litres, total, compteur, plein complet, date | Créer, modifier, supprimer (`FuelFill.save`, `Car.swift:73`) |
| F4 | Noter le kilométrage | Bouton « Kilométrage » (E1, E3), F2 | Gratuit | Compteur | Ajouter un relevé daté de maintenant ; **pas de modification ni de suppression** d'un relevé |
| F5 | Journal du jour | E1 (`journal`, `CarApp.swift:198`) | Gratuit | Pleins, relevés, entretiens faits du jour choisi + total dépensé | Toucher un plein ou un entretien : feuille de modification ; le relevé n'est pas touchable (`showsChevron: false`, `:236`) |
| F6 | Sélecteur de semaine | E1 (`CarApp.swift:80`) | Gratuit | 7 jours, point sur les jours avec trace | Choisir un jour (passé ou aujourd'hui) |
| F7 | Consommation | Tuile E1 (`:257`), page E2 ; `CarMath.consumption`, `consumptionByFill` (`Car.swift:106`, `:233`) | Gratuit | L/100 moyen ; coût aux 100 km (dernier prix) ; courbe par plein complet (dès 2 points) | Ouvrir E2 |
| F8 | Prix au litre | E2 (`CarPages.swift:41-54`) | Gratuit | Courbe (dès 2 pleins), « dernier N $/L » | Aucune |
| F9 | Historique des pleins | E2 liste « Pleins » (`:55-71`) | Gratuit | Date, litres, prix/L, km, « partiel », total | Toucher : modifier ou supprimer |
| F10 | Kilomètres par mois | E3 (`CarPages.swift:98-117`) ; `kmByMonth` (`Car.swift:213`) | Gratuit | Barres des 6 derniers mois ; « Moyenne » km/mois | Aucune |
| F11 | Relevés | E3 (`CarPages.swift:118-130`) ; `odometerPoints` (`Car.swift:86`) | Gratuit | 12 derniers points (relevés + pleins) ; note « Les relevés viennent de tes pleins et des kilométrages notés. » | Aucune (lecture seule) |
| F12 | Entretiens avec jauge | E1 (2 lignes), E4 ; `ServiceStatusRow` (`CarApp.swift:390`) ; `serviceStatus` (`Car.swift:159`) | Gratuit | Nom, reste en km ou en jours, jauge (bleu, orange dès 85 %, rouge dès 100 %), « dernier à N km le <date> », coût | Créer, modifier (F3) ; balayer droite « Fait aujourd'hui » (remet compteur et date) ; balayer gauche « Supprimer » |
| F13 | Échéances | E1 (2 lignes), E5 ; `upcomingDeadlines` (`Car.swift:179`) | Gratuit | Titre, icône, date, « J-N », « passée », « aujourd'hui » | Créer, modifier, supprimer par balayage ; 6 icônes (calendrier, bouclier, document, flocon, outils, carte) |
| F14 | Coût réel par mois | Tuile E1 (`:266`), page E6 ; `monthlyCost` (`Car.swift:143`) | Gratuit | Total, barre de répartition (Frais fixes, Carburant, Entretien), « Soit environ N $ par kilomètre parcouru » | Ouvrir E6 |
| F15 | Frais fixes | E6 section « Frais fixes » (`CarPages.swift:308-318`) ; aussi espace Auto | Gratuit | « Assurance », « Prêt ou location », « Stationnement », « Autres frais » (par mois), « Entretien prévu » (par an) | Écrire directement dans les champs (sauvegarde immédiate, `max(0, …)`) |
| F16 | Nom de la voiture et réservoir | F5 ; F6 ; carte « Ta voiture » (F7) ; espace Auto | Gratuit | Nom (titre de l'écran), réservoir en litres | Modifier (`setCarName`, `AppModel.swift:1309`) |
| F17 | Carte « Auto » de Mon quotidien | `DailySection.swift:448-457` ; `MiniAppSummary.caption` (`MiniAppsRow.swift:104-106`) | Gratuit (carte du jour pour tous) | Une ligne : « ≈ N km d'autonomie » ou « N km » ; sans donnée : « Rien pour l'instant : touche pour ajouter tes données. » | Toucher : ouvre E1 |
| F18 | Rappel d'échéance dans « À ne pas oublier » | `DailyBrief.swift:580-582` | Gratuit | Échéances de la voiture à 7 jours ou moins, symbole `car.fill` | Toucher : ouvre E5 |
| F19 | Widgets Auto (5) | `Shared/Render/Tiles/CarTiles.swift` ; `KindCatalog.swift:250-257` | Voir section 6 | Prochain entretien, coût, kilométrage, carburant, échéances | Voir section 6 |
| F20 | Doublon dans l'espace Auto | `CarSpaceSections` (`TravelCarLifeSpaces.swift:270`) | Gratuit | Voir 2.2 | Mêmes actions, en liste |

## 5. Données et calculs

### Modèles (`Shared/Domains/Car.swift`, stockés dans l'App Group, fichier `car` de `StoreFile`)

| Modèle | Champs | Ligne |
|---|---|---|
| `FuelFill` | `id`, `date`, `liters`, `total`, `odometer`, `isFull` (vrai par défaut) ; calculé `pricePerLiter = total / liters` | `Car.swift:3-13` |
| `OdometerReading` | `date`, `km` (n'a **pas** d'identifiant : repéré par son rang) | `:15-18` |
| `ServiceItem` | `id`, `name`, `intervalKm?`, `intervalMonths?`, `lastKm?`, `lastDate?`, `cost` | `:20-28` |
| `CarDeadline` | `id`, `title`, `date`, `symbol` (« calendar » par défaut) | `:30-35` |
| `CarState` | `name` (défaut « Ma voiture »), `fills`, `readings`, `services`, `deadlines`, `insuranceMonthly`, `loanMonthly`, `parkingMonthly`, `otherMonthly`, `maintenanceYearly`, `tankLiters?` ; décodage tolérant (`c.value(...)`) ; `save(_:)`, `markServiceDone` | `:37-82` |

Aucune notion de plusieurs voitures, de carburant (essence, diesel, électrique), de photo, de plaque, d'assurance avec date de renouvellement séparée, de pièce jointe, ni d'historique des entretiens faits (un entretien ne garde que sa **dernière** fois).

### Calculs existants (`CarMath`, à ne pas modifier)

- `odometerPoints` : relevés + compteurs des pleins, du plus ancien au plus récent (`:86`). `odometer` : le **maximum** (`:91`).
- `kmThisMonth` : dernier point moins le dernier point d'avant le mois (ou le premier du mois) (`:96`).
- `consumption` : litres des pleins après le premier plein complet jusqu'au dernier plein complet, divisés par la distance, fois 100 ; pleins triés par compteur (`:106`). `consumptionByFill` : même chose entre pleins complets (`:233`).
- `lastPricePerLiter`, `fuelCostPerKm` (consommation/100 × dernier prix) (`:115`, `:119`).
- `fuelMonthlyAverage` : dépense de carburant des 3 derniers mois (ou depuis le premier plein) divisée par le nombre de mois (`:129`).
- `monthlyCost` = frais fixes (4 champs) + carburant moyen + `maintenanceYearly / 12` (`:143`). Le coût des entretiens faits (`ServiceItem.cost`) **n'entre pas** dans ce calcul.
- `serviceStatus` : `kmLeft`, `daysLeft`, `used` (le plus grand des deux), trié du plus avancé au moins avancé (`:159`).
- `upcomingDeadlines` : échéances à partir d'aujourd'hui (`:179`).
- `range` : réservoir − (km depuis le dernier plein complet × L/100) + pleins partiels ; km = litres / L/100 × 100 (`:195`).
- `kmByMonth` : km roulés par mois sur N mois (`:213`).
- Écran Coûts : « par kilomètre » = coût total / moyenne des mois roulés hors mois courant (`CarPages.swift:325-330`).
- Seuils d'affichage : orange à 85 % de l'intervalle, rouge à 100 % (`CarApp.swift:290`) ; échéance rouge à 14 jours ou moins (`:312`).
- Tests de ces règles : `Tests/TravelCarTests.swift` (autonomie `:85`, km par mois `:108`).

### Données d'exemple (captures, mode démonstration)

`SampleData.car` (`Shared/Data/SampleData.swift:406`) : « Civic 2019 », réservoir 47 L, 10 pleins sur 95 jours, 1 relevé, 3 entretiens (« Vidange d'huile », « Rotation des pneus », « Plaquettes de frein »), 3 échéances (« Pneus d'hiver », « Immatriculation », « Assurance auto »), assurance 95, prêt 320, stationnement 60, entretien prévu 600 par an.

## 6. Liens

### Mon quotidien

- Catégorie `car` (id de carte `app-car`, `DailyBrief.swift:123`). Rang par défaut : la dernière (12e) (`DailyDefaults.swift:13`). **Pas pour tous** : visible selon l'intérêt « Auto », l'ajout par la personne ou la présence de données (socle `00-socle-commun.md`, `DailyDefaults.swift:17`). Demi-largeur par défaut.
- Contenu : « un chiffre » : nom, icône et couleur de la mini-app (gris `6B7280`) et une ligne (`DailySection.swift:448-457`) : « ≈ N km d'autonomie » sinon « N km » (`MiniAppsRow.swift:104-106`) ; vide : « Rien pour l'instant : touche pour ajouter tes données. » Une seule vue (pas de balayage). Pas d'indicateur d'entretien, pas d'échéance, pas de coût sur la carte.
- Carte vide : « Note un plein ou le kilométrage : ta voiture apparaîtra ici. » (`DailyBrief.swift:239`).
- Test : `Tests/DailyHomeTests.swift:70` (légende « 420 km d'autonomie »).
- La carte « À ne pas oublier » reprend les échéances de la voiture à 7 jours ou moins (`DailyBrief.swift:580`), pas les entretiens à faire.
- Puce de mini-app : « données présentes » seulement si un plein ou un relevé existe (`MiniAppsRow.swift:44`) ; un entretien ou une échéance seuls ne comptent pas (alors que E1 s'affiche avec).

### Widgets (5 types, groupe `.car`, `WidgetGroup.swift:28`)

| Widget | Genre (`WidgetKind`) | Tailles (`KindCatalog.swift:250-257`) | Premium | Contenu (`CarTiles.swift`) |
|---|---|---|---|---|
| « Coût de la voiture » | `carCost` | S, M, L | Premium | Coût mensuel, barre de répartition, lignes fixes/carburant/entretien, carburant au km |
| « Prochain entretien » | `nextService` | S, M, rectangle (écran verrouillé) | **Gratuit** | Km ou jours restants du plus avancé, jauge, 4 suivants |
| « Kilométrage » | `mileage` | S, M | Premium | Compteur, légende « N km en <mois> » ou « au compteur », lignes « Ce mois-ci », prochain entretien (« dans N km »), « Consommation » ; version en ligne = compteur (`CarTiles.swift:76-99`) |
| « Carburant » | `fuelStats` | S, M | Premium | Consommation moyenne, dernier prix, coût aux 100 km, ligne « Ce mois-ci » (dépense carburant du mois) et 3 derniers pleins (`CarTiles.swift:101-125`) |
| « Échéances auto » | `carDeadlines` | S, M, L | Premium | Prochaines dates |

- États vides des widgets : textes qui renvoient à « Ardane, espace Auto » (`CarTiles.swift:102`, `:129`) ; à garder cohérents si l'espace est renommé.
- Widget d'écran verrouillé « Auto » : `CarLockWidget` (`Widgets/DesignWidgets.swift:95`).
- Paquet prêt à l'emploi (thème sombre, `6B7280`) : `Packs.swift:85` (`carCost, nextService, mileage, fuelStats, carDeadlines, clock`). Combos de la boutique : `StoreCombos.swift:148`, `:176`. Suggestions de l'espace Auto : `SpaceCatalog.swift:63`, `:90`.
- Un widget est créé depuis l'espace « Auto » de Créer ; le toucher ouvre la mini-app Auto (`Router.swift:145-160`).

### Autres mini-apps

- **Finances** : aucun lien. Le coût de la voiture n'apparaît ni dans le budget ni dans les dépenses ; les pleins ne sont pas des dépenses (à vérifier dans `Shared/Domains/Budget.swift`, aucune référence à `car` trouvée dans les fichiers lus).
- **Planning** : aucun lien. Les échéances de la voiture ne sont pas dans l'agenda (`App/Core/Agenda.swift` ne lit que les échéances de Productivité, `:78`).
- **Voyage** : aucun lien (pas de trajet ni de distance).
- Fichiers qui lisent `model.car` hors mini-app : `DailyBrief.swift`, `DataItems.swift`, `MyInfoSection.swift`, `MiniAppsRow.swift`, `DataBackup.swift` (sauvegarde), `ScreenshotMode.swift`, `MarketingShots.swift`.

### Notifications et rappels

- **Aucune.** `MiniAppReminderRow` n'a pas de cas Auto (seuls Fitness, Nutrition, Finances ont un rappel : `MiniAppSettings.swift:118-125`) ; `SmartReminders.swift` ne mentionne pas l'auto (recherche sans résultat). Une échéance ou un entretien en retard ne déclenche aucune alerte.

### Liens profonds

- Pas de lien propre à Auto. Un widget envoie un lien `space` (valeur brute de l'espace `car`) qui ouvre la mini-app (`Router.swift:154-157`). Les pages Auto ne s'ouvrent depuis l'extérieur que par `HomeRoute.page(...)` (ligne de rappel `DailyBrief.swift:581`). Le mode capture ouvre `app-car`, `app-car-fuel`, `app-car-mileage`, `app-car-maintenance`, `app-car-deadlines`, `app-car-costs` (`ScreenshotMode.swift:219-223`). Schéma `tessera://` à vérifier pour d'éventuelles routes Auto (non trouvé).

## 7. États vides, première utilisation, erreurs, permissions, limites du mode gratuit

| Cas | Ce qui s'affiche | Preuve |
|---|---|---|
| Aucune donnée | Écran E1 : carte « Ta voiture, sans surprise » ; pas de sélecteur de semaine, pas de journal ; deux boutons « Plein » et « Kilométrage » ; carte « À remplir » (« Ta voiture ») ; pas de bouton de départ dans la carte elle-même | `CarApp.swift:79-86`, `:109-120` |
| Données sans plein ni relevé (par ex. seulement une échéance) | E1 complet (hero « – »), mais la **puce** et le décompte de Mon quotidien disent « sans donnée » | `CarApp.swift:77`, `MiniAppsRow.swift:44` |
| Pas de consommation | Tuile « Consommation » absente ; ligne « Carburant » dans la liste du bas | `CarApp.swift:333-350` |
| Consommation connue, pas de réservoir | Bouton « Indique la taille du réservoir pour voir l'autonomie » | `CarApp.swift:151-158` |
| Pas de plein complet (ou un seul) | Pas de consommation, pas d'autonomie ; aucun message d'explication sur E1 | `Car.swift:106-113` |
| E2 sans plein | « Aucun plein noté. À chaque plein, note les litres, le prix et le compteur : la consommation se calcule entre deux pleins complets. » ; courbes cachées sous 2 points | `CarPages.swift:21-40` |
| E3 sans données | Tuiles « Compteur » et « Moyenne » à « – » ; graphique et relevés cachés | `CarPages.swift:93-130` |
| E4 sans entretien | Liste vide avec seulement « Nouvel entretien » et la note « Glisse vers la droite quand un entretien est fait : il repart du compteur d'aujourd'hui. » (l'écran E1 cache la section, mais la page reste accessible par la liste) | `CarPages.swift:149-186` |
| E5 sans échéance | Liste vide avec seulement « Nouvelle échéance » | `CarPages.swift:214-243` |
| E6 sans frais | Total 0 $, pas de barre ; les 5 champs à 0 | `CarPages.swift:268-318` |
| Journal d'un jour sans trace | « Rien noté ce jour-là. » | `CarApp.swift:205-210` |
| Entretien dont l'échéance est inconnue | « Pas encore de repère » | `CarApp.swift:43` |
| Entretien non encore fait | « Pas encore fait » | `CarPages.swift:199` |
| Erreurs de saisie | « Enregistrer » grisé tant que litres, total et compteur ne sont pas tous > 0 (plein), compteur > 0 (kilométrage), nom non vide (entretien, échéance). Aucun message d'erreur : le bouton reste simplement inactif. Aucune vérification que le compteur soit supérieur au précédent (**à vérifier** : pas de garde trouvée) | `TravelCarLifeSpaces.swift:406`, `:441`, `:462`, `:489` |
| Suppression | Plein : bouton « Supprimer le plein » dans la feuille, **sans confirmation** ; entretien et échéance : balayage, **sans confirmation** ; relevé : impossible | `TravelCarLifeSpaces.swift:415-424`, `CarPages.swift:170`, `:233` |
| Permissions | Aucune (ni localisation, ni notifications, ni caméra, ni photos) | Aucun appel dans les 2 fichiers |
| Limites du mode gratuit | Aucune limite sur les pleins, entretiens, échéances ; widgets : seul « Prochain entretien » est gratuit, les 4 autres sont Premium | `KindCatalog.swift:252-256` |
| Langues | Tous les textes passent par `tr(...)` ; mois et dates par `Fmt` | tout le code |
| Accessibilité | Graphiques avec `accessibilityLabel` ; jauge avec valeur en pourcentage | `CarPages.swift:35`, `CarApp.swift:404-405` |

## 8. Problèmes d'UX constatés aujourd'hui

1. **Trois pages sur cinq sont en liste système, deux en cartes** : Entretien, Échéances et Coûts utilisent `List` + `.styledList()` ; Carburant et Kilométrage utilisent `MiniAppScroll` avec cartes Cristal. Même mini-app, deux langages visuels (`CarPages.swift:149`, `:214`, `:277` contre `:18`, `:92`).
2. **La liste du bas change d'apparence selon les données** : une ligne n'existe que si la tuile ou la section équivalente est cachée. Un nouvel utilisateur voit 5 lignes, un utilisateur complet n'en voit plus aucune, et le chemin pour revenir à une page change (`CarApp.swift:333-386`). Le même but (« aller aux Pleins ») a trois accès différents (tuile, ligne, bouton).
3. **Le réglage « Ma voiture » (nom, réservoir) est quasi introuvable** : la feuille `CarSettingsEditor` n'a qu'un seul déclencheur, le bouton du haut qui n'apparaît que si la consommation est connue et le réservoir vide (`CarApp.swift:151-152`). Après la première saisie du réservoir, plus aucun accès direct ; il faut passer par « Mes paramètres » tout en bas (`:103`). Le nom de la voiture, lui, ne se change que là.
4. **Le relevé du compteur ne se corrige pas** : la ligne « Relevé » du journal n'a ni chevron ni action (`CarApp.swift:234-236`) ; la page Kilométrage liste les relevés sans action (`CarPages.swift:122-127`). Une faute de frappe (« 612 000 » au lieu de « 62 000 ») fixe le compteur pour toujours, puisque `odometer` prend le **maximum** (`Car.swift:91`) et que seul un plein ou un relevé daté peut le remplacer. Plusieurs relevés le même jour sont acceptés (`OdometerEditor.save`, `TravelCarLifeSpaces.swift:451`), alors que `setOdometer` remplace celui du jour (`AppModel.swift:891-897`).
5. **Les entretiens n'ont pas d'historique** : « Fait aujourd'hui » écrase `lastKm` et `lastDate` (`Car.swift:77-81`). On ne sait plus ce qui a été fait ni combien ça a coûté. Le coût figure au journal du jour seulement à la date de la dernière fois (`CarApp.swift:180-185`), et le coût réel d'un entretien fait n'entre pas dans le « Coût réel » (`Car.swift:143-149` : seul `maintenanceYearly / 12` compte).
6. **Le « Coût réel » mélange vrai et estimé sans le dire sur l'écran principal** : le carburant est la moyenne des 3 derniers mois, l'entretien est un forfait annuel à saisir (`CarPages.swift:317` ; texte seulement dans le pied de page de E6). La tuile dit « par mois, tout compris » (`CarApp.swift:267`).
7. **L'autonomie et la consommation exigent des « pleins complets » sans guide** : sans deux pleins complets, rien ne s'affiche et E1 ne dit pas pourquoi ni quoi faire (`Car.swift:106-113`, `CarApp.swift:249-252`). Seule la page Carburant vide l'explique (`CarPages.swift:22`).
8. **Les frais fixes se modifient sans valider** : chaque frappe dans E6 est sauvegardée tout de suite (`CarPages.swift:332-337`) ; pas de bouton, pas d'annulation, et ces champs ne sont accessibles qu'à l'intérieur de la page Coûts (pas de bouton de modification sur E1).
9. **Pas de « marquer comme fait » pour une échéance, ni de répétition** : une échéance passée reste dans la liste (« passée »), une assurance annuelle doit être recréée (`CarPages.swift:216-232`, `CarDeadline` sans répétition, `Car.swift:30-35`). Aucune notification, ni pour les échéances ni pour les entretiens (section 6).
10. **L'entretien à faire est plus visible dans le widget que dans l'app** : le widget « Prochain entretien » (gratuit) affiche la jauge et 4 suivants ; l'écran principal n'en montre que 2 (`CarApp.swift:287`, `CarTiles.swift:service`). Le bloc d'en-tête (compteur) ne dit jamais « un entretien est en retard ».
11. **La carte « Auto » de Mon quotidien est pauvre** : une ligne (« ≈ N km d'autonomie » ou « N km »), sans entretien, ni échéance, ni coût (`MiniAppsRow.swift:104-106`, `DailySection.swift:448-457`). Elle est aussi sans vue à balayer, alors que Nutrition en a 3.
12. **Le sélecteur de semaine apporte peu** : un jour sert à voir un journal qui ne contient souvent rien (« Rien noté ce jour-là. »), un plein se fait au plus quelques fois par mois ; les échéances ne marquent pas de jour (`CarApp.swift:80-82`, `:167-174`). Il occupe la place du haut, avant le compteur, pour une usage rare.
13. **Doublon de l'espace Auto (onglet Créer)** : la même gestion, en liste système, avec des libellés différents (« Fait » au lieu de « Fait aujourd'hui », « Derniers pleins », `TravelCarLifeSpaces.swift:315-384`), hors de la mini-app. À garder en tête pour ne pas casser le chemin « widget → espace ».
14. **Entrées de carte « Ta voiture » peu claires** : la carte « À remplir » ne demande que le nom (`MiniAppToFill.swift:17`) alors que l'écran a besoin d'un compteur, d'un plein complet et d'un réservoir pour tout activer.
15. **Compteur « – » avec des échéances seules** : si l'utilisateur ne saisit que des échéances, E1 s'affiche avec un compteur « – » (`CarApp.swift:126`) alors que `hero` est tout de même montré (`:77-83`).
16. **Couleur de la mini-app (gris ardoise `6B7280`) = couleur de Top 3** (socle `00-socle-commun.md`, ligne « Auto » du tableau des couleurs), donc faible repère visuel ; l'orange `F08A24` du carburant sert aussi à Nutrition (`MiniApp.swift:40`) et le bleu `3366FF` des entretiens à Planning (`:42`).
17. **Suppressions sans confirmation** : plein, entretien, échéance (section 7).
18. **Texte long dans une ligne** : « Environ N L dans le réservoir, d'après ta consommation depuis le plein du <date> » sous le hero (`CarApp.swift:147`) est en caption à 75 % d'opacité ; lisibilité faible (jugement à vérifier sur capture).

## 9. Ce que la mission du PDG cite et qui n'existe pas

La mission ne parle d'Auto que dans la partie F, « Autres mini-apps existantes » (`MISSION.md:181-192`), sans liste de fonctions pour Auto. Il n'y a donc aucune fonction citée qui manque. Points de vigilance :

- « Autres mini-apps sélectionnées en Small » (`MISSION.md:288`) : dans le code, la carte Auto est en **demi-largeur** (`DailyBrief.swift:297-305`), ce qui correspond à la petite taille de la grille de Mon quotidien ; rien n'impose « Small » en dur (taille réglable par la personne, `+` / `−`). À valider avec le PDG si « Small » veut dire « demi » (à vérifier).
- « Ne crée pas de mini-app fictive » (`MISSION.md:192`) : respecté ; Auto existe (`MiniApp.swift:6`).
- Absent du code et donc à **ne pas présenter comme existant** dans les planches (à marquer « nouveau » si proposé) : plusieurs voitures, type de carburant ou voiture électrique, recharge, trajets, GPS, photo de la voiture, plaque, documents, assurance avec renouvellement, historique des entretiens, relevés modifiables, notifications d'entretien ou d'échéance, échéances répétées, export, lien avec Finances ou Planning, coût par kilomètre sur l'écran principal, comparaison de prix de stations, rappel du kilométrage mensuel.

## 10. Captures CI disponibles

- La branche `origin/ci-report` ne contient **aucune image** (seulement `report.txt` à la racine et, dans `history/…`, des fichiers texte OCR et de reconnaissance ; aucun `.png` ni `.jpg` trouvé par `git ls-tree`). Les images sont probablement dans les artefacts d'exécution GitHub (à vérifier).
- Écrans photographiés par le workflow `.github/workflows/build.yml:466-469` (clair) : `app-car`, `app-car-fuel`, `app-car-mileage`, `app-car-maintenance`, `app-car-deadlines`, `app-car-costs` (haut de page), puis `app-car-end` (bas de `app-car`). Pas de capture des feuilles (F1 à F6), ni du mode sombre, ni de l'état vide, ni des 5 widgets en détail (à vérifier).
- Test d'interface : `testCarShowsTheRangeAndItsPages` (`UITests/MiniAppUITests.swift:476`) ; instantanés « car », « car-fuel », « car-mileage ». Il vérifie l'autonomie, l'ouverture de Carburant et Kilométrage et l'ouverture d'un plein (« Supprimer le plein »).
- Les images doivent se regarder en petit et en nombre limité (consigne du projet).

## 11. Contraintes pour la conception

1. **Garder les 5 pages secondaires atteignables** et tout ce qui est dans les sections 2 et 4 : plein, kilométrage, entretien, échéance, coûts, frais fixes, nom, réservoir. Règle de la mission (section 9 de `MISSION.md`) : aucune fonction retirée.
2. **Ne pas modifier les calculs** de `CarMath` (consommation plein-à-plein, autonomie, coût mensuel, état des entretiens). Tout nouvel écran lit les mêmes fonctions.
3. **Ne pas inventer de données** : un chiffre inconnu s'affiche « – », jamais une valeur d'exemple (règle d'Ardane, `DailyBrief.swift` « Never a made-up figure »). Les planches utilisent des données crédibles du jeu d'exemple (« Civic 2019 », 47 L, etc.).
4. **Une seule voiture** : si la planche en montre plusieurs, la marquer « nouveau ».
5. **Cadre commun** : `MiniAppScaffold` (voile de couleur, en-tête sur verre, feuille de contenu, « Mes paramètres » en dernier), `MiniHero`, `MiniStat`, `MiniRow`, `MiniRowsCard`, `MiniActionButton`, `WeekSelector` (`MiniApp.swift`, `MiniAppScaffold.swift`). Ordre commun : sélecteur, essentiel, actions, sections, liste secondaire, mention, « Mes infos » (`docs/memoire/Chantiers.md`, lot 1 du 2026-10-22).
6. **Couleurs** : accent Auto `6B7280` ; carburant `F08A24` ; alerte `MiniStyle.alertHex` ; entretien `3366FF` ; coûts `2F8F7A` (`Car.swift` / `CarApp.swift:35-37`, `:239`, `:379`). Toute la palette passe par `CristalPalette` ; en proposer une teinte plus distinctive reste une proposition (section 8, point 16).
7. **Graphiques** : Swift Charts (`LineMark`, `BarMark`), hauteurs 120 à 170 pt ; courbes et barres de la palette Cristal.
8. **Mon quotidien** : la carte Auto est une carte « un chiffre » en demi-largeur ; toute proposition de carte plus riche doit tenir sur ce gabarit (ou en proposer un nouveau, à marquer comme évolution de `DailySection`).
9. **Widgets existants** : 5 types, 1 gratuit (« Prochain entretien »), 4 Premium ; leurs tailles sont fixées par `KindCatalog`. Une refonte ne doit pas casser leur lien d'ouverture.
10. **Mode gratuit** : aucune limite dans la mini-app ; une proposition qui ajoute du Premium doit le dire clairement et ne rien retirer au gratuit.
11. **Langues** : 6 langues cibles (en, es, de, it, pt-BR, ja) en plus du français ; textes plus longs en allemand ; tout texte passe par `tr(...)`.
12. **Accessibilité et tests** : conserver les identifiants listés en 2.3 (les UITests s'en servent) ou prévoir leur migration ; cibles de 44 pt ; graphiques avec étiquette VoiceOver.
13. **Appareil de test** : iPhone 11 Pro ; pas de LiDAR ni d'Apple Intelligence ; Auto n'en a pas besoin. Aucune permission à ajouter pour l'existant.
14. **Doublon d'espace** (`CarSpaceSections`) : une refonte de la mini-app ne touche pas à l'espace de Créer, sauf décision explicite ; à signaler comme dette.

## Relecture

- Ajouté : le décompte exact des feuilles (6 + section « À remplir »), la collision de numérotation F1-F7 / F1-F20, la condition d'affichage de « Ce mois-ci », le contenu réel des widgets « Kilométrage » et « Carburant », les textes des états vides de widgets, la liste Grep des éléments absents (alert, contextMenu, Picker, Premium).
- Corrigé : l'espace Auto montre 8 derniers pleins (pas 5) et ses sections s'appellent « Coûts fixes » ; la mention « à vérifier » du widget « Kilométrage » est levée ; vérifié contre le code et exact : routes, boutons, identifiants, Premium des 5 widgets, puce « données présentes », calculs `CarMath`.
- Incertain : images CI (non vérifiées, pas de PNG dans `ci-report`), route `tessera://` éventuelle pour Auto, absence de lien avec Finances (`Budget.swift` non relu), garde sur le compteur à la saisie.
