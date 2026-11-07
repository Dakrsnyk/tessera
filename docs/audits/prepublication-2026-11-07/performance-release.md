# Audit 24.R : performance, stabilité et build Release

Date : 2026-11-07. Lecture seule (code, projet Xcode, `build.yml`, rapports `origin/ci-report`, journal de l'exécution 42370408591 = build [interne] 355). Aucun fichier du projet modifié, rien compilé ni lancé : tout ce qui suit est « estimé d'après le code » sauf mention « mesuré ».

## Ce qui est mesuré, et ce qui ne l'est pas

- Mesuré : la CI compile bien la Release signée et l'envoie (ARCHIVE SUCCEEDED, upload en 30 s, exécution 42370408591). Le binaire Release ne contient aucun des symboles de capture (étape `release-check`, `build.yml:819-829`, résultat « found: 0 »).
- NON mesuré : la taille du binaire, de l'IPA, des modèles compilés, le temps de lancement, la mémoire. Les rapports `report.txt` et `history/*` ne contiennent AUCUNE taille (`ipa: not published` pour les builds `[check]` et TestFlight). Le journal de l'exécution TestFlight n'affiche que le pourcentage de l'envoi. La ligne 49 de `build.yml` (commentaire du tag `[stack]`) compare un build non optimisé à un build optimisé pour la pile de 1 Mo ; elle ne rapporte pas de taille. Il n'y a donc pas de comparaison de tailles entre versions : voir R-04.
- Aucun test de performance n'existe (`grep XCTApplicationLaunchMetric|XCTMemoryMetric|measure(` : seuls des helpers nommés `measure` dans `Tests/ScheduleEvaluationTests.swift:184` et `Tests/WeighedMealsEvaluationTests.swift:764`, qui ne sont pas des métriques XCTest).

## Taille estimée du contenu embarqué (sources dans le dépôt, du plus gros au plus petit)

| Ressource | Taille source | Cible(s) | Remarque |
|---|---|---|---|
| `App/Resources/Models/ArdaneFoodClassifier.mlpackage` | 88 Mo | app seule | compilé en `.mlmodelc` par Xcode (taille finale non mesurée) |
| `App/Resources/Models/ArdaneFoodSegmenter.mlpackage` | 30 Mo | app seule | idem |
| `App/Assets.xcassets` (20 icônes alternatives + 1) | 21 Mo, dont 32 PNG de plus de 300 Ko (19,3 Mo) | app | R-05 |
| `App/Resources/ardane-food.sqlite` | 10,6 Mo | app seule | base FCÉN + USDA |
| `Shared/Localizable.xcstrings` | 6,9 Mo | app ET widget | 6 langues + français |
| `App/Resources/cnf-foods.json` | 1,4 Mo | app | ancien fichier, inutile : R-03 |
| `App/Resources/ExerciseDemos.json` | 0,75 Mo | app | démonstrations d'exercices : ce sont des modèles 3D en JSON dessinés par `Canvas`, il n'y a ni vidéo ni image |
| `food-densities.json` | 0,12 Mo | app | |
| Polices | 0 | | polices système uniquement |
| Vidéos | 0 | | les `.mp4` sont dans `pub/`, hors des cibles |

Estimation : l'app pèse au moins 150 à 170 Mo décompressés, dont environ 75 % de modèles Core ML. Avec la compression de l'App Store, 100 à 130 Mo de téléchargement probable. Au-dessus du seuil de 200 Mo de téléchargement cellulaire de l'App Store : non (estimé, à confirmer par R-04).

L'extension widget (`ArdaneWidgets`) ne synchronise que `Widgets/` (53 Ko) et `Shared/` (`project.pbxproj`, groupes `A10…42` et `A10…41`) : les modèles, la base SQLite et les JSON de `App/` ne sont PAS dans l'extension. Sain.

---

## Constats

### R-01 — Majeur — Aucune mesure de taille, de lancement ni de mémoire en CI
- `.github/workflows/build.yml` (étapes `archive`, lignes 156-200) ; absence de tests de performance dans `Tests/` et `UITests/`.
- Preuve : voir plus haut (aucune taille dans les rapports).
- Impact : impossible de savoir si l'app dépasse le plafond mémoire du widget, si le lancement dépasse la limite du watchdog iOS (environ 20 s, mais une app lente à ouvrir est notée mal), ou si la taille a explosé après l'ajout des modèles (R-04).
- Correction : ajouter les tests de la section « Tests proposés » et l'étape de taille de R-04.
- Vérification : le rapport CI publie les nombres ; comparer d'une exécution à l'autre.

### R-02 — Majeur — Lecture des données et du calendrier SUR LE FIL PRINCIPAL, deux fois au lancement
- `App/Core/AppModel.swift:55-57` (`init` appelle `reloadFromDisk()`), puis `App/ArdaneApp.swift:67` (`model.reloadFromDisk()` à chaque passage à `.active`, y compris le premier). `reloadFromDisk` (`AppModel.swift:84-117`) lit et décode de façon synchrone au moins 17 fichiers JSON de l'App Group (`store.state(...)` ×13, `designs`, `content`, `settings`, `InsightCache.load()`, `MarketService.cache`, `FXService.cached`, `CompanyService.cached` dans une boucle), appelle `CalendarService.upcoming(hours:limit:)` (EventKit, ligne ~89), et `syncFinances()` qui peut réécrire le budget.
- Preuve : lecture du code ; `AppModel` est `@MainActor`, `@State private var model = AppModel()` est créé dans `ArdaneApp`. Le lancement n'a pas de chargement différé.
- Impact (estimé) : au lancement, l'`init` bloque l'affichage du premier écran ; les données grossissent avec l'usage (historique de repas, séries, transactions). Chaque retour au premier plan refait tout le travail sur le fil principal, ce qui peut causer un saccade à la réouverture et un écrasement d'état si un widget écrit pendant la lecture. Le lancement a de plus un délai fixe de 1,15 s (`ArdaneApp.swift:221`, `Task.sleep(1_150)`) sur la marque de lancement : c'est voulu, mais il s'ajoute au temps perçu.
- Correction proposée :
  1. dans `ArdaneApp.swift:67`, ne pas appeler `reloadFromDisk()` au premier `.active` quand l'`init` vient de le faire (mémoriser la date du dernier rechargement, ignorer si moins de 1 s) ;
  2. sortir `CalendarService.upcoming` du chemin synchrone : le charger dans `Task` (EventKit est thread-safe pour la lecture) puis affecter `events` ;
  3. ne recharger que les fichiers modifiés (comparer `modificationDate` de chaque fichier) plutôt que les 17.
- Vérification : `XCTApplicationLaunchMetric` et `measure` sur `reloadFromDisk` (tests P-1 et P-2).

### R-03 — Majeur — Ancien `cnf-foods.json` (1,4 Mo) embarqué et encore décodé dans le code, plus une recherche synchrone dans le corps d'une vue
- Embarquement : `App/Resources/cnf-foods.json` ; code : `App/Core/NutrientFile.swift:63` (`static let entries = load()`) et `:107` (`JSONSerialization` de tout le fichier, création d'environ plusieurs milliers de `FoodItem`). Le commentaire en tête de `NutrientFile.swift:20-21` dit que le fichier « disparaît une fois la nouvelle base prouvée en CI ».
- Recherche dans le `body` : `App/Screens/Spaces/NutritionSpace.swift:172-185` (`local` est une propriété calculée lue à chaque rendu de la vue : `FoodDatabase.search`, `NutrientFile.search(query)` qui interroge SQLite, tri et filtres sur les listes de l'utilisateur, sur le fil principal, à chaque frappe ET à chaque réévaluation de `body`).
- Impact (estimé) : 1,4 Mo de poids mort si la base SQLite est présente (elle l'est : `SQLiteFoodRepository.bundled()`), et si elle ne se charge pas jamais, le repli décode 1,4 Mo sur le fil principal à la première recherche. La recherche SQLite dans `body` est répétée à chaque réaffichage (par exemple pendant le défilement ou la saisie).
- Correction proposée : (a) supprimer `cnf-foods.json` et l'énumération `Legacy` une fois la base SQLite validée (les tests `FoodRepositoryTests` la couvrent déjà) ; (b) mémoriser le résultat dans `@State` mis à jour par `.onChange(of: query)` avec un délai de 150 ms (`task(id: query)`), hors du `body`.
- Vérification : `measure` de `NutrientFile.search("poul", limit: 60)` (test P-3) ; taille de l'IPA avant/après (R-04).

### R-04 — Majeur — La taille de l'app n'est pas suivie et les modèles Core ML n'ont pas de budget
- `App/Resources/Models/*.mlpackage` (118 Mo de sources) ; `build.yml` n'imprime aucune taille.
- Impact : 118 Mo de modèles pour une fonction (le scanner de plats) utilisée par une fraction des utilisateurs ; le risque est de dépasser sans le savoir un seuil pénible (téléchargement cellulaire de 200 Mo) ou de faire attendre l'examen. La précision (Float32 ou Float16) des modèles n'est pas vérifiée dans ce rapport.
- Correction proposée : (a) ajouter à l'étape d'archive, après la ligne 167 de `build.yml`, `du -sk "$APP" "$APP/PlugIns/ArdaneWidgets.appex" "$APP"/*.mlmodelc "$APP/Assets.car" "$APP/ardane-food.sqlite" | tee -a testflight.txt` et `ls -l build/export/*.ipa`, et publier le résultat dans le rapport ; (b) vérifier que les deux modèles sont convertis en Float16 (`ct.convert(..., compute_precision=ct.precision.FLOAT16)` ; avec quantification 8 bits on gagne environ 50 % de plus) ; (c) à plus long terme, envisager des Ressources à la demande (On-Demand Resources) pour les modèles.
- Vérification : tailles dans le rapport CI avant/après ; test P-4 (mémoire au chargement des modèles).

### R-05 — Mineur — 20 icônes sombres IDENTIQUES aux claires, 11,8 Mo dans le dépôt, et icônes alternatives embarquées avec leurs variantes 1024
- `App/Assets.xcassets/ArdaneIcon-*.appiconset/AppIcon-*-Dark-1024.png` : `md5sum` identique à `AppIcon-*-1024.png` pour les 20 icônes (mesuré par `cmp`, 20/20 identiques ; 588 417 octets chacune pour Amber). Réglage `ASSETCATALOG_COMPILER_INCLUDE_ALL_APPICON_ASSETS = YES` (`project.pbxproj` ligne ~474 et Release).
- Impact : 11,8 Mo de PNG en doublon dans le dépôt ; effet sur l'IPA non mesuré (l'outil `actool` peut dédoublonner). Les icônes sont lues à la demande, pas de coût mémoire.
- Correction proposée : retirer la variante « Dark » du `Contents.json` quand elle est identique (l'icône claire sert alors aux deux modes), ou la supprimer des 20 jeux.
- Vérification : taille de `Assets.car` (R-04).

### R-06 — Mineur — Modèles Core ML jamais libérés après usage
- `App/Screens/MiniApps/Nutrition/FoodModelRecognizer.swift:93-110` (`FoodModelRecognizer.shared`, `loading` garde `Loaded` à vie) ; préchauffage `MealPhotoAnalysis.swift:77-79`. Aucun `didReceiveMemoryWarning` dans `App/` ni `Shared/` (grep : 0 résultat).
- Preuve : le résultat du chargement est conservé indéfiniment ; les deux modèles sont chargés ensemble avec `computeUnits = .all` sur iPhone (`FoodModelRecognizer.swift:36-42`).
- Impact (estimé) : une fois le scanner ouvert, 120 Mo de poids restent résidents pour toute la session, ce qui augmente le risque que iOS tue l'app en arrière-plan (jetsam) sur les iPhone de 3 à 4 Go (iPhone 11 Pro : 4 Go). Le chargement est bien paresseux (hors fil principal : `Task.detached(priority: .utility)`) : sain.
- Correction proposée : ajouter `releaseModels()` qui met `loading = nil` sous `lock`, appelé à la fermeture de l'écran du scanner et sur `UIApplication.didReceiveMemoryWarningNotification` (hors `Shared/`, l'app seulement).
- Vérification : test P-4 (`XCTMemoryMetric` avant/après libération).

### R-07 — Mineur — Réglages Release : l'essentiel est sain, trois points à confirmer
- `Ardane.xcodeproj/project.pbxproj` :
  - Release du projet (lignes ~420-450) : `SWIFT_COMPILATION_MODE = wholemodule`, `DEBUG_INFORMATION_FORMAT = "dwarf-with-dsym"` (ligne 433), `ENABLE_NS_ASSERTIONS = NO`, `VALIDATE_PRODUCT = YES`, pas de `ENABLE_TESTABILITY` (donc NO par défaut en Release), `SWIFT_OPTIMIZATION_LEVEL` non défini en Release (donc `-O` par défaut en Release : sain). Pas de `STRIP_INSTALLED_PRODUCT` ni `DEAD_CODE_STRIPPING` : valeurs par défaut (YES à l'archive). `COPY_PHASE_STRIP = NO` (ligne 389/430) : sans effet sur l'archive, qui retire les symboles.
  - Debug : `SWIFT_OPTIMIZATION_LEVEL = "-O"` (ligne 411) et `ENABLE_TESTABILITY = YES` (ligne 393) ; `-Wl,-stack_size,0x100000` seulement en Debug (ligne 459, pour reproduire la pile de 1 Mo : absent de la Release : voulu).
  - À confirmer : `ENABLE_PREVIEWS = YES` en Release (sans effet sur le binaire, mais inutile), et `SWIFT_VERSION = 5.0` (OK).
- Impact : aucun défaut bloquant ; la Release est optimisée et sans testabilité. Pas de mesure de taille pour prouver le retrait.
- Correction proposée : mettre `ENABLE_PREVIEWS = NO` dans la Release ; ajouter explicitement `SWIFT_OPTIMIZATION_LEVEL = "-O"` (ou `-Osize`, à tester : peut gagner 5 à 10 % de taille de code) pour que le réglage soit visible.
- Vérification : étape de taille de R-04 ; `otool -l` pas nécessaire.

### R-08 — Amélioration — `Shared/Localizable.xcstrings` (6,9 Mo) est compilé dans l'extension widget
- `Ardane.xcodeproj` : le groupe `Shared` est dans les deux cibles. Le catalogue contient toutes les chaînes de l'app (l'extension n'en affiche qu'une petite partie).
- Impact : l'extension, limitée à environ 30 Mo en mémoire, charge un catalogue de chaînes compilé plus gros que nécessaire (`.strings` compilés par langue : probablement 1 à 2 Mo par langue) : les tables sont lues à la demande (`mmap`), le risque est faible.
- Correction proposée : un catalogue dédié `Widgets/Localizable.xcstrings` avec seulement les clés utilisées par `Shared/Render` et `Widgets/`, généré par `scripts/l10n_catalog.py`. À faire seulement si la mesure P-5 montre un dépassement.
- Vérification : test P-5.

### R-09 — Amélioration — Photos des widgets « Citation en photo » : décodage plein format à chaque rendu
- `Shared/Render/Kinds/PhotoQuoteWidgets.swift:60` et `Shared/Theme/Theme.swift:1033` : `ImageStore.image(named:)` (`Shared/Support/SharedStore.swift:266-270`, `UIImage(contentsOfFile:)`) ; les photos sont réduites à 900 px à l'enregistrement (`save`, `maxDimension = 900`, JPEG 0,82 : sain).
- Impact (estimé) : une photo de 900 × 1200 décodée pèse 4,3 Mo en mémoire ; l'extension a un plafond d'environ 30 Mo : trois widgets photo visibles à la fois, plus la mise en page, peuvent s'en approcher. Aucun cache (`NSCache`) pour éviter un second décodage lors de plusieurs entrées de la ligne de temps.
- Correction proposée : dans `ImageStore.image(named:)`, utiliser `UIImage.preparingThumbnail(of:)` à la taille d'affichage maximale du widget (par exemple 600 px de large) quand l'appelant est l'extension (paramètre `maxPixel:`), et un `NSCache` à deux entrées.
- Vérification : test P-5 (`XCTMemoryMetric` du rendu d'un widget photo) ; sur l'iPhone, Instruments (Allocations) sur l'extension.

### R-10 — Amélioration — Réseau : pas de nouvelle tentative ni de `waitsForConnectivity`, mais délais et caches présents
- `Shared/Data/CryptoService.swift:85` (12 s), `Shared/Domains/Portfolio.swift:263,318` (12 s), `Companies.swift:96` (15 s), `FoodDatabase.swift:387` (15 s), `Travel.swift:326,425` (12/15 s), `App/Services/StripeSync.swift:199` (20 s). Caches de fraîcheur : `LivePrices.isFresh` (`CryptoService.swift:58`), caches lus avant le réseau dans `reloadFromDisk` (`AppModel.swift:105-113`). Hors ligne : le cache est servi (`CryptoService.swift:62`). `MoneySpaces.swift:59` appelle `refreshMarkets()` à chaque affichage de l'écran (garde par fraîcheur à vérifier).
- Impact : comportement hors ligne sain pour les cours ; 9 appels `URLSession.shared` sans délai de ressource global ni nouvelle tentative : une panne réseau brève donne un cache périmé jusqu'à la prochaine ouverture. Pas de risque de boucle de requêtes trouvé.
- Correction proposée : rien d'obligatoire ; si souhaité, un `URLSession` partagé avec `timeoutIntervalForResource = 30` et `waitsForConnectivity = false` explicite.
- Vérification : test réseau coupé dans les UITests existants (`LivePricesTests`).

### R-11 — Amélioration — Lancement : `refreshInsights()` et trois `Task` à chaque retour au premier plan
- `App/ArdaneApp.swift:65-77` : à chaque `.active`, `WorkoutLiveActivity.sync`, `StudyLiveActivity.sync`, `premium.refreshEntitlements()`, `model.refreshInsights()` (Apple Intelligence, `AIPhraser.refresh`, `Shared/…/AIPhraser` ligne 45-59) et `syncReminders()`.
- Preuve : `AIPhraser.refresh` ignore les widgets dont `factsKey` n'a pas changé (ligne 51) et sort tout de suite si le modèle n'est pas disponible (ligne 46) : le coût répété est faible. `syncReminders` est différé de 1 s et annulable (`AppModel.swift:580-590`) : sain.
- Impact : faible ; au premier lancement, ces quatre tâches démarrent en même temps que le premier rendu.
- Correction proposée : différer ces `Task` de 1,5 s au premier `.active` (après la marque de lancement), sans changer les suivants.
- Vérification : `XCTApplicationLaunchMetric` (P-1).

---

## Tests proposés

Trois cibles existent : `ArdaneTests` (logique, `@testable import Ardane`, groupe `Tests/`) et `ArdaneUITests` (`UITests/`). Les tests de performance ne doivent PAS tourner dans `[unit]` par défaut : les nommer `Performance…Tests` et les lancer avec un tag dédié.

### P-1 : lancement à froid (nouveau fichier `UITests/LaunchPerformanceUITests.swift`)
```swift
import XCTest

final class LaunchPerformanceUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    func testLaunchTime() throws {
        let options = XCTMeasureOptions()
        options.iterationCount = 5
        measure(metrics: [XCTApplicationLaunchMetric(waitUntilResponsive: true)], options: options) {
            let app = XCUIApplication()
            app.launchArguments = ["-AppleLanguages", "(fr)", "-AppleLocale", "fr_CA"]
            app.launch()
        }
    }

    func testMemoryAfterLaunch() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(fr)", "-AppleLocale", "fr_CA"]
        measure(metrics: [XCTMemoryMetric(application: app), XCTCPUMetric(application: app)]) {
            app.launch()
            _ = app.wait(for: .runningForeground, timeout: 10)
            app.terminate()
        }
    }
}
```
Seuil : enregistrer la référence (« Set Baseline ») à la première exécution ; avec `xcodebuild`, passer `-only-testing:ArdaneUITests/LaunchPerformanceUITests`. Sur le simulateur de la CI, les valeurs servent à comparer d'une exécution à l'autre, pas à décider une valeur absolue sur iPhone.

### P-2 : rechargement des données (nouveau fichier `Tests/PerformanceTests.swift`)
```swift
import XCTest
@testable import Ardane

@MainActor
final class PerformanceTests: XCTestCase {
    func testReloadFromDisk() {
        let model = AppModel()
        measure(metrics: [XCTClockMetric(), XCTMemoryMetric()]) {
            model.reloadFromDisk()
        }
    }

    // P-3 : recherche de la base d'aliments
    func testFoodSearch() {
        XCTAssertFalse(NutrientFile.isEmpty)
        measure(metrics: [XCTClockMetric()]) {
            for query in ["poul", "pomme", "riz cuit", "chicken", "yaourt nature"] {
                _ = NutrientFile.search(query, limit: 60)
            }
        }
    }

    func testExerciseDemoPreparation() {
        measure(metrics: [XCTClockMetric(), XCTMemoryMetric()]) {
            for id in ExerciseDemos.ids.prefix(40) { _ = ExerciseDemos.demo(for: id) }
        }
    }
}
```

### P-4 : mémoire du scanner (dans `Tests/PerformanceTests.swift`)
```swift
    func testFoodModelsMemory() throws {
        let engine = FoodModelRecognizer()   // CPU seul sur le simulateur
        measure(metrics: [XCTMemoryMetric(), XCTClockMetric()]) {
            try? engine.prepare()
        }
    }
```
Après la correction R-06, ajouter un test qui appelle `releaseModels()` puis vérifie la baisse avec `XCTMemoryMetric`.

### P-5 : mémoire de l'extension (rendu d'un widget photo)
`XCTMemoryMetric` ne mesure pas l'extension : utiliser `XCTMemoryMetric` sur un `ImageRenderer` du widget dans `ArdaneTests` (le code de rendu est dans `Shared/`, donc compilable dans les tests), ou lire `phys_footprint` :
```swift
    func testPhotoQuoteWidgetFootprint() {
        // construire un WidgetDesign « citation en photo » avec une photo de 900 x 1200 enregistrée par ImageStore.save
        measure(metrics: [XCTMemoryMetric()]) {
            let renderer = ImageRenderer(content: PhotoQuoteWidgetPreviewView(/* design de test */))
            _ = renderer.uiImage
        }
    }
```
(le nom de la vue de rendu doit être celui de `Shared/Render/Kinds/PhotoQuoteWidgets.swift` ; à adapter au moment de l'écriture). Seuil proposé : pic inférieur à 20 Mo.

### Taille : étape de CI (modification de `build.yml`, à faire par le Chef avec autorisation, ligne 167)
```bash
du -sk "$APP" "$APP/PlugIns/ArdaneWidgets.appex" | tee -a testflight.txt
find "$APP" -maxdepth 2 \( -name "*.mlmodelc" -o -name "Assets.car" -o -name "*.sqlite" \) -exec du -sk {} + | sort -rn | tee -a testflight.txt
ls -l build/export/*.ipa 2>/dev/null | tee -a testflight.txt
```

---

## Examiné et trouvé sain

- Exclusion Release du code de capture : `ScreenshotMode.swift`, `AdExport.swift`, `DemoGallery.swift` sont entièrement entre `#if DEBUG … #endif` (lignes 4-525, 1-605, 3-57) ; les usages restants dans `ArdaneApp.swift`, `AppModel.swift`, `OnboardingView.swift`, `NutritionSpace.swift` sont sous `#if DEBUG` ; l'étape `release-check` (`build.yml:819-829`) cherche les symboles `ScreenshotMode|AdExport|DebugPremium|WidgetGalleryView|SetupGalleryView|MarketingView` dans l'app ET dans l'extension.
- `Tests/` (dont `Tests/Fixtures`, 3,3 Mo de photos et références) et `UITests/` sont des groupes des seules cibles de test (`ArdaneTests`, `ArdaneUITests`) : aucune fixture dans l'app ni l'extension. Les `.mp4` des pubs sont dans `pub/`, hors projet.
- Extension widget : ne contient ni modèle Core ML, ni SQLite, ni JSON volumineux (groupes `Widgets` + `Shared` seulement) ; `ScannerMass.swift:93-97` renvoie une table vide quand le fichier est absent (extension).
- Chargement paresseux : modèles Core ML (`FoodModelRecognizer.swift`, hors fil principal, échec mémorisé pour une absence), `ExerciseDemos` (décodage unique, `NSLock`, préparation à la demande), `FoodDensityTable.bundled` (`static let`), SQLite ouvert à la demande.
- Lecture OCR, PDF et analyse d'image : `ScheduleReader.swift:232-236` exécute le travail sur `DispatchQueue.global(.userInitiated)` ; `MealPhotoAnalysis.swift:309,335` idem ; la reconnaissance des plats est annoncée « lourde : hors du fil principal » (`FoodModelRecognizer.swift`, `recognize`).
- Cycles de rétention : les trois observateurs de `NotificationCenter` d'`AppModel` utilisent `[weak self]` (`AppModel.swift:61,68,75`) ; aucun `Timer.scheduledTimer` ni `Timer.publish` dans `App/`, `Shared/`, `Widgets/` ; les tâches différées (`reloadTask`, `remindersTask`) sont annulées avant remplacement (`AppModel.swift:580-600`).
- Arrière-plan : `Config/App-Info.plist` n'a AUCUN `UIBackgroundModes` (pas de mode inutile à justifier à l'examen). Les Live Activities sont arrêtées proprement (`StudyLiveActivity.swift:59-79`, `staleDate` posé). `NSSupportsLiveActivities = true`, `ITSAppUsesNonExemptEncryption = false`.
- Entitlements : seulement l'App Group `group.com.dakrsnyk.tessera` (`Config/Ardane.entitlements`), pas de capacité superflue.
- Versions : `MARKETING_VERSION = 1.0` (8 occurrences, `project.pbxproj:485`, app, widgets et tests alignés) ; `CURRENT_PROJECT_VERSION = 1` dans le projet mais la CI le remplace par `github.run_number` (`build.yml:~159`, 355 pour le dernier build) : numéros de build croissants, pas de collision. `IPHONEOS_DEPLOYMENT_TARGET = 17.0` (projet, Debug et Release) conforme à l'iOS 17 annoncé.
- Signature Release : manuelle, profils « Ardane App Store » / « Ardane Widgets App Store » ; déblocage Premium vérifié absent du binaire (`grep "en mode test"`, `build.yml:~175`).
- Images enregistrées : `ImageStore.save` réduit à 900 px avant l'écriture (JPEG 0,82), jamais l'original de l'appareil photo ; le scanner refuse les images de plus de 2 048 px (`FoodModelRecognizer.maximumSide`).
- Réseau : un `timeoutInterval` partout (12 à 20 s), caches lus avant le réseau, données périmées servies hors ligne.
- `AIPhraser.refresh` n'appelle le modèle que pour les faits qui ont changé (`factsKey`).
