# Audit performance, 2026-11-27 (lecture seule, rien compilé ni mesuré)

Constats lus dans le code ; impact ressenti = estimation, à confirmer au Profiler sur l'iPhone 11 Pro. Cause commune de la correction du Store : widgets SwiftUI vivants, redessinés ou reconstruits à chaque passage. Les mosaïques du Store sont réglées ; restent les mêmes causes ailleurs, plus une cause cachée : `SamplePayload.make`.

## A. Causes transversales

**A1. `SamplePayload.make` reconstruit tout le monde d'exemple à chaque appel (FORT, effort faible).**
`Shared/Data/PayloadLoader.swift:40-62` puis `Shared/Data/SampleData.swift:6-11` et `:54-85` : pour tout type de widget sans échantillon propre (la grande majorité, branche `default:` de `make(for kind:)`), `SampleData.domains` fabrique nutrition, fitness, budget, business, portfolio, 3 sociétés, étudiant, voyage, voiture, productivité, avec des dizaines de `tr()`, `Date` et `Calendar`. Aucun cache (seul `sampleHabitDays` en a un). Appelé dans des `body` : `ExploreView.swift:488`, `StoreShowcase.swift:249`, `StoreMagazine.swift:145,192,294,629`, `StoreCombos.swift:238,352`, `HomeSetupViews.swift:254,345,361,691`, et via `model.previewPayload` (`App/Core/DataItems.swift:452`) dans `EditorView.swift:478`, `CreateFlow.swift:590,685`, `StudioPanels.swift:793`.
Correction : mémoriser dans `make(for design:)` et `make(for kind:)` (verrou + dictionnaire, clé `kind.rawValue|coinID|Int(now.timeIntervalSince1970/600)` ; combinés : liste des types des parties). `WidgetPayload` est une valeur (copie à l'écriture) : la copie coûte peu. Un seul changement dans `Shared/` accélère Store, Créer, Studio et Écrans d'accueil.

**A2. `WidgetPreview` vivants sans rastérisation (FORT là où il y en a des dizaines).**
`App/Components/UIComponents.swift:22-90` : chaque aperçu dessine le widget à taille réelle (158 ou 338 pt) puis `scaleEffect` (l.43-48), avec fonds, flous, verre, lueurs. Aucun `drawingGroup` ni image figée hors fonds d'écran (`WallpaperCollection.swift:267`) et mosaïques.
Correction : généraliser `MosaicPictures` (`StoreMiniAppMosaic.swift:212-260`) en `StillWidget(design:family:payload:width:)` (cache `NSCache`, clé = design + famille + largeur + scheme + scale) pour toutes les rangées et grilles de vignettes (B1, C1, D1 à D3). Garder `WidgetPreview` vivant pour la scène du Studio, le carrousel de Mes widgets et les grandes cartes.

## B. Studio (EditorView, StudioPanels)

**B1. Panneau Style : 504 styles, vignettes vivantes (FORT, effort moyen).**
`StudioPanels.swift:232-233` (`LazyHStack`) et `:265-266` (grille « Voir tout ») : chaque `tile` (l.271-289) fait `look.applied(to: design)` (copie complète d'un `WidgetDesign`) et un `WidgetPreview` vivant. À chaque appui de style, toutes les vignettes visibles se reconstruisent, et `withAnimation(.easeInOut 0.25)` (l.275) les anime. Plusieurs rangées visibles à l'ouverture.
Correction : vignette = image figée (A2), clé `look.id + famille + design.kind/options/displayFormat` (le contenu de l'utilisateur ne change pas le style à cette échelle) ; seul l'anneau de sélection reste vivant (overlay).

**B2. `StyleCatalog.current(for:)` dans le `body` (MOYEN, effort faible).**
`StudioPanels.swift:165` appelle `StyleLibrary.swift:66` : `all.first { $0.matches(design) }` ; `matches` (l.38-43) appelle `applied(to:)`, donc une copie de `WidgetDesign` par style : jusqu'à 504 copies par évaluation du corps quand le style a été modifié (cas où rien ne correspond). Idem `tile` : `look.matches(design)` (l.272) par vignette.
Correction : `matches` sans copie (comparer `themeID/accentHex/background/font/style.look` au design) ; mémoriser l'id du style courant dans l'état du panneau, recalculé par `onChange` des champs de style ; `tile` reçoit cet id.

**B3. `previewFrame` écrit par `onGeometryChange` : tout le Studio redessiné à chaque image d'animation (FORT pendant le geste, effort faible).**
`EditorView.swift:58` (`@State previewFrame`) et `:140` : `onGeometryChange(... frame(in: .global)) { previewFrame = $0 }`. Pendant que la scène rétrécit ou grandit (`raisePanel`, l.201-206) ou que la feuille est tirée, le cadre global change à chaque image : `@State` écrit, donc corps de `WidgetStudio` réévalué (`studioInput` l.485-494 = `previewPayload` + `TileFactory.make`, `sections`, panneau Style avec B2). La valeur ne sert qu'à l'enregistrement (`EditorView.swift:1188`).
Correction : classe non observée (`final class FrameBox { var rect = CGRect.zero }` dans un `@State`) ou lecture du cadre au moment d'enregistrer.

**B4. `studioInput` recalculé à chaque évaluation (MOYEN, effort faible).**
`EditorView.swift:127-130, 478, 485-494` : `previewPayload` (A1, ou `payload(for:)` qui copie `domains`, `AppModel.swift:232-254`) + `TileFactory.make`, y compris pendant un glisser de `ColorPicker`. Correction : `@State` recalculé par `onChange` de `design.kind / options / displayFormat / family` seulement.

**B5. Animation globale (FAIBLE).** `StudioComponents.swift:386` : `.animation(.easeInOut, value: design)` compare un gros `WidgetDesign` à chaque corps. Préférer des `withAnimation` ciblés.

## C. Créer

**C1. Grille de types de widgets (MOYEN, effort moyen).** `CreateFlow.swift:566-590` : `LazyVGrid` ; chaque tuile fait `category.design(for:)`, `model.previewPayload(for:)` (A1), `draft.refusal(adding:)` dans le corps du parent, et `StudioKindTile` a un `WidgetPreview` vivant (`StudioParts.swift:451`). Un appui (`draft.picked`, animé l.652) redessine toutes les tuiles visibles. Correction : image figée (A2) ; numéro et refus seulement en overlay.
**C2. `StudioParts.swift:588-590` (ajout d'un widget dans un combiné)** : même schéma que C1, même correction.
**C3. Aperçu final** (`CreateFlow.swift:685`) : un seul aperçu ; réglé par A1.

## D. Store (reste)

**D1. Cartes « Écrans d'accueil » (SetupCard) : un faux iPhone vivant par carte (FORT, effort moyen).**
`ExploreView.swift:376-381` (`setupsRow`, 150 pt), `:452-456` (thèmes assortis), `:636-647` (filtré). Chaque `SetupCard` donne un `SetupScreenshot` (`HomeSetupViews.swift:63-79`) : un écran 393×852 dessiné en vrai (fond `SetupWallpaperView`, icônes `SetupAppIcon`, 3 à 6 `WidgetPreview` avec ombres et `SamplePayload.make` aux l.254, 345, 361), puis réduit par `scaleEffect` dans un `GeometryReader`. Le commentaire « Equatable, ainsi le glissement ne redessine pas » ne joue probablement pas : `.equatable()` n'apparaît nulle part dans `App/` (à vérifier au Profiler). `favoritesRaw` (`@AppStorage` d'`ExploreView`) invalide toutes les cartes à chaque cœur, et `SetupFavorites.ids(favoritesRaw)` est analysé pour chaque carte.
Correction : image figée par setup et par page (`ImageRenderer` en cache, comme `MosaicPictures`), cœur et badge Premium en overlay ; calculer le `Set` des favoris une fois par corps. À défaut : `.drawingGroup()` sur `SetupScreenshot` et `.equatable()` à l'appel.
**D2. Rangée « Styles » (MOYEN, effort faible).** `ExploreView.swift:479-490` : `LazyHGrid` 2 rangées, `makeDesign()` + `SamplePayload.make` (A1) + `WidgetPreview` vivant par cellule ; `StoreEdition.style()` (`StoreMagazine.swift:509-513`) filtre les 504 styles et `StoreShowcase.allStyles` (`StoreShowcase.swift:63-65`) les reparcourt à chaque corps. Correction : A1 + image figée + `static let` de la liste (change une fois par semaine).
**D3. Autres rangées (MOYEN).** `StoreMagazine.swift:145,192,294,629`, `StoreCombos.swift:238,352`, `StoreShowcase.swift:249` (écran verrouillé : `ZStack` dégradé + `WidgetPreview` à taille réelle). Paresseux (`LazyHStack`), mais A1 et A2 s'appliquent.
**D4. Fonds d'écran : sain.** `WallpaperCollection.swift:154-215, 258-267` : `LazyVStack` + `drawingGroup`.

## E. Accueil

**E1. `DailySection` recalcule tout le résumé à chaque image d'un glisser (FORT en mode édition, effort faible).**
`DailySection.swift:68` (`@State dragOffset`), `:288` (écrit à chaque mouvement) ; le corps (l.80-98) refait `DailyCategories.home(model:now:steps:)` (`App/Core/DailyCategories.swift:43-55` : `DailyBrief.tiles`, `MiniAppSummary.caption` par catégorie, `wanted`, `withWeekSchedule`), `arranged`, `ordered`, `readingOrder`, plusieurs `Set` : à chaque image. `frames` (l.73, `onPreferenceChange` l.146) réécrit aussi l'état à chaque changement de mise en page.
Correction : sortir le glisser dans une sous-vue (`dragOffset` dans `DailyHoldToMove` ou une carte), ou mémoriser `automatic` et `arranged` (`@State`, mis à jour par `onChange` des données lues) ; `frames` dans une classe non observée.
**E2. Observation large de l'AppModel (MOYEN, effort élevé).** `DailySection.body` lit `settings`, `content`, `nutrition`, `fitness`, `budget`, `student`, `productivity` via `DailyBrief.Input(model:)` : une écriture (tâche cochée, verre d'eau, série) redessine tout Quotidien. Chaque tuile (`WorkoutDayTile` l.807, `HabitsDayTile` l.1069, `BudgetDayTile` l.1306) lit aussi `model`. À terme : tuiles qui reçoivent seulement leur sous-état. Court terme : E1 suffit.
**E3. Habitudes (FAIBLE).** `DailySection.swift:1173-1200` : un `GeometryReader` par ligne, 3 lignes au plus. Laisser. `ViewThatFits` l.478 (`DayHeader`) : un seul, hors tuiles de widget ; laisser.

## F. Mes widgets

**F1. `cardFrames` écrit à chaque image de défilement en sélection (FORT en sélection, effort faible).**
`MyWidgetsView.swift:20` et `:524` : `onGeometryChange` sur le cadre global de chaque carte, qui écrit `cardFrames[design.id]`. Le cadre global change à chaque pixel de défilement : N écritures d'état par image, donc le corps entier est refait (tri `recentDesigns` l.32, `designs`, `current`, `fusion` = `Fusion.result`, `model.payload(for:)` par carte l.510 et 536). Le cadre ne sert qu'à l'animation de fusion (l.448).
Correction : classe non observée, ou lecture du cadre au lancement de la fusion seulement.
**F2. Tri et filtres dans le corps (MOYEN, effort faible).** `MyWidgetsView.swift:23-33` : `model.recentDesigns` (`AppModel.swift:304`, `sorted`) puis `.filter`, rappelés plusieurs fois par corps (`designs`, `current`, `allShownSelected`, `rows`). Calculer une fois en tête de `body`.
**F3. Carrousel (FAIBLE).** `WidgetCarousel.swift:42-100` : `LazyHStack` + `scrollTransition` 3D sur des aperçus vivants, 3 pages visibles : acceptable. `payload(design)` (`MyWidgetsView.swift:242`) copie `domains` par page à chaque réévaluation.

## G. Mini-apps

**G1. Démonstrations d'exercices animées (MOYEN, effort faible).** `Fitness/DemoRow.swift:22` : `TimelineView(.animation(minimumInterval: 1/15))` + `Canvas` par ligne de `List` (`ExerciseLibraryViews.swift:108-120, 276`) : 8 à 12 canevas à 15 images par seconde pendant un défilement. Correction : image fixe pendant le défilement ou 1/6 s en liste.
**G2. `ViewThatFits(in: .vertical)` dans les blocs du planning (MOYEN, effort faible).** `WeekViews.swift:351-356` : 3 variantes par événement du tableau de la semaine. Pas une tuile de widget, mais le piège de `Pieges-connus.md` (2026-11-07, 2026-11-26) vaut de même. Correction : choisir avec `lines.time` et `lines.place` (déjà calculés l.344).
**G3. Minuteries** (`PlanningApp.swift:49`, `TravelApp.swift:355` par minute ; `FitnessApp.swift:581`, `FitnessSession.swift:205`, `StudiesApp.swift:582` par seconde) : bornées, laisser. `FinancesApp.swift:894` `ViewThatFits(in: .horizontal)` : une instance, à surveiller.
**G4. Recherche d'exercices dans le corps** (`ExerciseLibraryViews.swift:~120`, `ExerciseLibrary.search` à chaque frappe sur tout le catalogue) : debounce ou cache (FAIBLE).

## H. Sain (ne pas toucher)
Fonds d'écran du Store (`drawingGroup`, `LazyVStack`) ; mosaïques du Store (images figées, `NSCache` 400) ; `StyleCatalog.traits` (filtres précalculés, `StyleLibrary.swift:132`) ; la plupart des rangées sont en `LazyHStack`, `LazyVGrid` ou `List`, aucun `ForEach` non paresseux sur 500 éléments trouvé dans les écrans lus.

## Les 8 corrections les plus rentables

1. **Mémoriser `SamplePayload.make`** : `Shared/Data/PayloadLoader.swift:40` (et `make(for kind:)`). Cache verrouillé, clé type + pièce + tranche de 10 min ; supprime la reconstruction du monde d'exemple à chaque corps (Store, Créer, Studio, Écrans d'accueil).
2. **`previewFrame` hors observation** : `EditorView.swift:58,140`. Boîte non observée (ou lecture à l'enregistrement) pour que l'animation de la scène ne redessine plus tout le Studio à chaque image.
3. **`cardFrames` hors observation** : `MyWidgetsView.swift:20,524`. Ne mesurer que pendant la fusion ; supprime N écritures d'état par image de défilement en sélection.
4. **Glisser de « Mon Quotidien »** : `DailySection.swift:68,80-98,288`. Sortir `dragOffset` et `frames` du corps qui recalcule `DailyCategories.home`, ou mémoriser `automatic` et `arranged`.
5. **Vignettes de styles du Studio en images figées** : `StudioPanels.swift:232,265,271-289`, avec un `StillWidget` générique dérivé de `MosaicPictures`. Clé : style, type, famille, largeur, scheme.
6. **`matches` sans copie et style courant mémorisé** : `StyleLibrary.swift:38-43,66` et `StudioPanels.swift:165,272`. Comparer sans `applied(to:)`, mémoriser l'id par `onChange`.
7. **Cartes « Écrans d'accueil » en images figées** : `HomeSetupViews.swift:63-79` et appels `ExploreView.swift:376,452,636`. `ImageRenderer` en cache, cœur et badge en overlay ; sinon `.drawingGroup()` + `.equatable()`.
8. **Même `StillWidget` pour Créer et le Store (Styles, packs, combinés)** : `CreateFlow.swift:566-590`, `ExploreView.swift:479-490`, `StoreMagazine.swift:145,192,629`, `StoreCombos.swift:238` ; gains rapides en plus : retirer `ViewThatFits` de `WeekViews.swift:351`, `DemoRow.swift:22` de 15 à 6 images par seconde en liste.

Non vérifié : aucune mesure, aucune compilation. `AppModel` expose des propriétés `@Observable` par domaine (`nutrition`, `fitness`, `profile`) : l'observation est déjà par propriété ; le problème est surtout les vues qui en lisent beaucoup à la fois et les états écrits à chaque image.
