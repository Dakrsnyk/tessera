---
tags: [ardane, audit, scanner, nutrition]
---

# Audit technique du scanner alimentaire d'Ardane (2026-11-02)

Audit en lecture seule : aucun fichier du projet n'a été modifié. Conventions : « constaté » = lu dans le code ; [supposé] = non vérifié dans le code ; [documenté] = source Apple ou tierce.

**Limite majeure.** Aucun chiffre de précision mesuré en CI n'est disponible : la branche `origin/ci-report` ne contient qu'un `report.txt` (une seule révision, écrasée à chaque run : `.github/workflows/build.yml` l.891-896) et son dernier run a `tests: skipped`. Les rapports `SCORES-*`, `RECO-*`, `SCAN-*` d'anciens runs sont perdus. Les seuls chiffres du dépôt sont les constantes du code et les jeux de test eux-mêmes.

## 1. Parcours d'une analyse de bout en bout

Écran unique : `App/Screens/MiniApps/Nutrition/FoodScanView.swift` (`FoodScanView`), ouvert depuis `NutritionSpace.swift` l.327, le `Router` (`.scanFood`) et `OpenFoodScannerIntent` (`Shared/Intents/FoodScannerIntent.swift`). Machine à états `Stage` : `.camera`, `.looking(code)`, `.analyzing`, `.recap`, `.notFound`, `.offline`, `.partial`, `.photoFailed`. La permission caméra passe par `CameraAccessGate` (explication puis demande système ; `NSCameraUsageDescription` dans `Ardane.xcodeproj/project.pbxproj`).

**Chemin photo (OPÉRATIONNEL)**
1. Capture : `ScanCameraView` (VisionKit `DataScannerViewController`), `shoot()` → `capturePhoto()`. Importation : `PhotosPicker` → `analyze(_ item:)` (sans accès à la photothèque).
2. `analyze(_ image:)` → `MealAnalysisConfig.makeAnalyzer().analyzeMeal(image)`. `onlineEnabled = false` (constante) : `OnDeviceMealAnalyzer` est toujours utilisé.
3. `OnDeviceMealAnalyzer.runVision` (file `DispatchQueue.global(.userInitiated)`) : `uprightCopy` redresse l'image, 1 024 px maximum.
4. Détection : `classify` (`VNClassifyImageRequest`, photo entière) ; `instanceCrops` (`VNGenerateForegroundInstanceMaskRequest`, jusqu'à 4 objets d'aire 4 % à 90 %, marge 8 %) ; repli `gridCrops` (3×3) ; `featurePrint` (`VNGenerateImageFeaturePrintRequest`). Soit 1 + 4 ou 1 + 9 recadrages.
5. Étiquettes → aliments : `FoodLabelMatcher.proposals` (`Shared/Domains/FoodLabelMatcher.swift`) : seuil de confiance 0,15, mots ignorés, gabarits de plats, synonymes, puis recherche locale (`OnDeviceMealAnalyzer.localSearch` = `FoodDatabase.search` + `NutrientFile.search`, limite 5). Fusion par aliment au meilleur niveau de confiance, 8 propositions au maximum.
6. Mémoire visuelle : `MealMemory.suggestionWithDate(for:)` : si ≥ 2 repas validés ont une empreinte à moins de 0,2, leurs aliments et la médiane de leurs grammes passent en tête (confiance fixe 0,8, `usesHabit = true`).
7. Grammes : AUCUNE mesure. Ordre : médiane `ScanLearning.usualGrams` (≥ 2 corrections) ; mémoire visuelle ; grammes du gabarit (`DishTemplate.Component.grams`) ; sinon `food.servingGrams` (portion usuelle de la table) ou 100 g.
8. Récapitulatif : `ScanRecap(proposals:)` et `ScanRecapView.swift` : modifier les grammes (`setGrams`), `replace` (`FoodSearchView`), `remove`, ajouter un aliment, choisir le repas.
9. Suggestions : `ScanRecap.suggestions()` propose huile 10 g, beurre 10 g, mayonnaise 15 g selon des mots-clés du nom ; rien n'est ajouté sans accord.
10. Calcul et affichage : `FoodItem.nutrients(grams:)` ; fourchette « ≈ 420–560 kcal » (`ScanUncertainty`, `kcalRangeText`).
11. Validation : `ScanRecap.commit(into:meal:at:)` écrit dans `NutritionState` (`origin: .scan`), enregistre un `ScanCorrection` dans `state.scanLearning` et un `MealMemoryEntry` dans `state.mealMemory` ; persistance par `SharedStore` (fichier `.nutrition`, App Group).

**Chemin code-barres (OPÉRATIONNEL)** : `Coordinator.didAdd` (VisionKit) lit EAN-13, EAN-8, UPC-E et s'arrête au premier code. `lookup(code)` cherche d'abord dans les aliments de la personne (customFoods, favorites, recentFoods, via `OpenFoodFacts.barcodeForms`), puis `OpenFoodFacts.lookup(barcode:)` (`world.openfoodfacts.org/api/v2/product/{code}.json`). Issues : `.food`, `.partial` (nom sans nutrition : aliment prérempli), `.unknown`, ou erreur réseau → `.offline`. Le résultat suit le même récapitulatif.

**Arrière-plan** : seul Vision tourne hors du fil principal. Aucune tâche de fond persistante : si l'app quitte, l'analyse est perdue [supposé : aucun `BGTask` trouvé].

Étiquettes : analyse photo sur l'appareil OPÉRATIONNEL ; détection multi-objets OPÉRATIONNEL mais utilité PARTIELLE (segmentation de premier plan générique, pas spécifique à la nourriture) ; estimation de grammes par photo SIMULÉ (aucune estimation visuelle, uniquement des portions usuelles) ; analyse en ligne `OnlineMealAnalyzer` PRÉVU-NON IMPLÉMENTÉ (lève `notEnabled`, aucune URL ni clé).

## 2. Technologies

| Technologie | Rôle exact | Local / distant | Données échangées |
|---|---|---|---|
| Vision `VNClassifyImageRequest` (Apple) | Étiquettes génériques avec confiance (~1 300 identifiants selon des sources tierces ; Apple ne donne pas le nombre) | Local | `CGImage` en entrée ; `[(identifier, confidence)]` en sortie |
| Vision `VNGenerateForegroundInstanceMaskRequest` (iOS 17) | Découpe d'objets de premier plan | Local | Masques → boîtes englobantes |
| Vision `VNGenerateImageFeaturePrintRequest` | Empreinte (2 048 valeurs) pour reconnaître un plat déjà validé | Local | Vecteur, stocké emballé (1 octet/valeur) dans `NutritionState.mealMemory`, jamais la photo |
| VisionKit `DataScannerViewController` | Codes-barres et capture photo | Local | `payloadStringValue` |
| Open Food Facts API v2 (`OpenFoodFacts`, `FoodDatabase.swift`) | Produit par code-barres ; recherche texte `cgi/search.pl` (25 résultats) | Distant (`URLSession.shared`) | Voir section 8 |
| `FoodDatabase` (`Shared/Domains/FoodDatabase.swift`) | Table intégrée pour 100 g (CNF et USDA arrondis) | Local | — |
| `NutrientFile` (`App/Core/NutrientFile.swift`) | Fichier canadien (~5 600 aliments, `App/Resources/cnf-foods.json`, 1,44 Mo), recherche par préfixes FR/EN | Local | — |
| `FoodSynonyms` et `DishTemplate` (`Shared/Domains/DishTemplates.swift`) | Dictionnaire manuel étiquette → requêtes FR ; 19 gabarits de plats avec grammes fixes | Local | — |
| `MealMemory` (`Shared/Domains/MealMemory.swift`) | Plus proches voisins sur empreintes (distance euclidienne normalisée, seuil 0,2, 200 repas max, accord de 2 repas min) | Local | — |
| `ScanLearning` (`Shared/Domains/ScanLearning.swift`) | Préférence d'aliment par étiquette et quantité habituelle (médiane) | Local | — |

Constats négatifs : aucun modèle CoreML (`.mlmodel`/`.mlpackage`), aucun `Package.resolved`, aucune dépendance tierce de vision, aucun LiDAR / profondeur / ARKit / `AVDepthData`. `VNRecognizeText` n'est pas utilisé pour les étiquettes nutritionnelles (10.C non fait).

Communication : la vue appelle le protocole `MealPhotoAnalyzing` (remplaçable). L'analyseur lit `SharedStore.shared.state(NutritionState.self)` pour l'apprentissage et la mémoire, puis appelle le matcher (logique pure, testable, avec `resolve` et `search` injectés). Le résultat revient en `MealAnalysis` → `ScanRecap`.

## 3. Calcul des calories et des macros

- Formule (déterministe) : `FoodItem.nutrients(grams:)` (`Shared/Domains/Nutrition.swift` l.50) : valeur pour 100 g × grammes / 100 (kcal, protéines, glucides, lipides, fibres, sucres, saturés, sodium, cholestérol, micronutriments). Total = somme des lignes (`ScanRecap.totals`).
- Sources : table intégrée, CNF, Open Food Facts. Pour OFF, énergie lue dans l'ordre `energy-kcal`, `energy-kj / 4,184`, `energy / 4,184`, puis 4P + 4G + 9L. Valeurs par portion ramenées à 100 g (`per100`). Un macro absent est « inconnu » (`unknownMacros`), pas 0 : total « incomplet », affiché « ≥ ».
- Grammes : voir 1.7 (aucune mesure).
- Aliments similaires : distingués seulement par l'étiquette Vision et le texte. `FoodLabelMatcher.find` : synonymes, puis tous les mots, puis dernier mot avec confiance × 0,6 (`partialMatchFactor`) ; `accepts` filtre les faux amis courts (« pie » / « pied de porc »). Cru/cuit lu dans le nom (`cookingState`), cuit favorisé (`cookedChoice`). `MealProposal.alternative` est calculé mais jamais utilisé par l'interface. Aucune distinction par texture, couleur, recette ou marque.
- Repas composés : 19 gabarits (sandwich, club, pizza, hamburger, hot-dog, pâtes, spaghetti, lasagne, salade, César, bol de riz, sushis, poutine, déjeuner œufs-bacon, crêpes, soupe, pâté chinois, tourtière, poisson-frites), composants à grammes fixes ; composants optionnels à confiance × 0,6. Confiance des lignes : `score × 0,9 × max(0,5, 1−0,03·i)`. Plat sans gabarit : un seul aliment par étiquette.
- Sauces, huiles, assaisonnements : jamais détectés dans l'image ; seulement 3 suggestions par mots-clés à confirmer (huile d'olive 10 g, beurre 10 g, mayonnaise 15 g). Aucune modélisation de l'huile absorbée ni de la méthode de cuisson.
- Marges d'incertitude (`ScanUncertainty`, `ScanRecap.swift` l.31-37) : ±5 % (produit emballé ou quantité tapée), ±30 % (portion usuelle de table), ±40 % (photo). Constantes posées à la main, non sourcées, sans mesure empirique. Bornes arrondies vers l'extérieur par pas de 5 ou 10 kcal.
- Cohérence de la table : `testBuiltInTableIsCoherent` vérifie `|kcal − (4P+4G+9L)| ≤ max(30, 25 % kcal)` (alcool en liste blanche).

## 4. Quantités et précision

- Estimation : vision seule, avec des étiquettes génériques. Les quantités sont des portions usuelles, pas une mesure sur l'image.
- Volume, référence de taille, profondeur, LiDAR, segmentation métrique : PRÉVU-NON IMPLÉMENTÉ (`Demandes.md` 9.A(3) et 9.B non cochés, aucun code). La segmentation sert seulement à produire des recadrages de classification. `capturePhoto()` renvoie une `UIImage` sans profondeur [supposé].
- Saisie utilisateur : OPÉRATIONNEL, grammes bornés à 1–5 000 (`ScanRecap.clamped`). Les presets Petite/Moyenne/Grande (9.A(2)) n'existent pas.
- Limites : l'erreur sur les grammes n'est pas bornée par l'image ; la fourchette ±40 % reste fixe même après saisie manuelle (`ScanLine.uncertainty` renvoie `photoEstimate` dès que `isEstimate` est vrai et `setGrams` ne l'efface pas).

Repas où il devrait être précis : produit emballé scanné (OFF, ±5 % si la fiche est bonne [supposé]) ; aliment unitaire standard (pomme, œuf, banane : étiquette simple, portion de table proche) ; plat à gabarit unique (pizza 220 g, poutine 400 g, lasagne 300 g : valeur de table, mais portion réelle variable, d'où ±40 %).
Repas difficiles : soupes, currys, sauces, plats mijotés (ingrédients cachés) ; graisse de cuisson variable (non mesurée) ; assiettes composées aux portions inhabituelles (pas de volume) ; plats non occidentaux ou rares (dictionnaire manuel, classifieur générique [supposé hors 44 photos]).

## 5. Deux systèmes distincts

**A. Photo de repas** : sections 1 à 4.

**B. Code-barres (OPÉRATIONNEL)**
- Reconnaissance : VisionKit sur l'appareil, EAN-13, EAN-8, UPC-E (UPC-A lu comme EAN-13 [supposé]). QR, Code 128, DataMatrix non lus.
- Recherche : `OpenFoodFacts.lookup(barcode:)` essaie chaque forme (`barcodeForms` : code tel quel, avec/sans zéro de tête, UPC-E → UPC-A, UPC-A → EAN-13), une requête par forme en série, délai 15 s chacune. OFF est bien utilisé (`world.openfoodfacts.org`, API v2, `AppInfo.userAgent`, champs `code,product_name,product_name_fr,product_name_en,generic_name,brands,serving_quantity,serving_size,nutriments`).
- Bases consultées : aliments de la personne (customFoods, favorites, recentFoods), puis OFF. La table intégrée et la CNF n'ont pas de code-barres : non consultées.
- Produit absent : « Produit introuvable » avec « Créer cet aliment » (`draft(for:)` préremplit le code), « Chercher dans la liste », « Scanner à nouveau ». Produit sans nutrition (`.partial`) : recopie depuis l'étiquette.
- Hors ligne : `.offline` avec « Réessayer » ; pas de cache de fiche OFF ; un produit n'est retrouvable hors ligne que s'il est dans `recentFoods` (20 max), les favoris ou les aliments personnalisés.
- Non fait : lecture OCR du tableau nutritionnel (10.C).
- Licence : `docs/licences-nutrition.md` (ODbL/DbCL) ; attribution dans `ScanRecapView.linesFooter`.

## 6. Apprentissage par les corrections

Le mécanisme existe (OPÉRATIONNEL) mais c'est de la **mémorisation statistique locale**, pas un apprentissage de modèle.
- Enregistré : à chaque `ScanRecap.commit` d'une photo, pour chaque ligne ajoutée, `ScanLearning.record(ScanCorrection(...))` : date, étiquettes Vision nettoyées, `detectedFoodID`, `initialGrams`, `validatedFoodID`, `validatedGrams`, drapeau `quarantined`. Une ligne acceptée sans modification compte comme confirmation.
- Exemple riz 150 g → 220 g : entrée `validatedGrams = 220`. Il faut au moins `minimumAgreeing = 2` corrections valides pour que `usualGrams` renvoie la médiane ; elle peut donc être inférieure à 220 g si une validation non modifiée à 160 g existe. Une seule correction ne change rien.
- Stockage : `NutritionState.scanLearning` (`Shared/Domains/Nutrition.swift` l.687), persisté par `SharedStore` (fichier `.nutrition`, App Group `group.com.dakrsnyk.tessera`), plus `NutritionState.mealMemory` (200 repas max). Fichiers en `.completeFileProtectionUntilFirstUserAuthentication`.
- Réutilisation : `FoodLabelMatcher.proposals` utilise `preferredFoodID(forLabel:)` (≥ 2 corrections concordantes et deux fois plus que les autres) et `usualGrams(forFoodID:)`, y compris pour les composants de gabarits. Affichage « Ton habitude ».
- Protections : `plausibleGrams(for:)` (1–100 g si > 700 kcal/100 g, sinon 5–1 500 g) ; valeur hors plage ou dix fois au-dessus/au-dessous de la médiane → quarantaine (conservée, jamais utilisée) ; 500 corrections max (les plus anciennes supprimées) ; médiane robuste. Limites : le premier enregistrement plausible n'a pas de référence ; `usualGrams` est indexé par aliment, pas par contexte (un « pain blanc » de sandwich influence aussi les autres propositions de pain).
- Partage entre utilisateurs : NON. `contributionEnabled` (« Contribuer à l'amélioration », `ScanRecapView` l.133) est un simple booléen sans code réseau (l'interface dit « Aucun envoi pour l'instant »). Fonction visible SIMULÉE, au libellé honnête.
- Effacement : `PRIVACY.md` l.32 affirme l'effacement des empreintes avec « Effacer toutes mes données » (`AppModel.resetAllData`) [supposé : corps non relu en détail pour `nutrition`].
- Seulement envisagé : entraînement global, serveur de corrections, modèle appris (chantier 8 partie II).

## 7. Architecture

| Fichier | Rôle / fonctions | Communique avec |
|---|---|---|
| `App/Screens/MiniApps/Nutrition/FoodScanView.swift` | `FoodScanView`, `Stage`, `ScanCameraView`, `ScanCameraHandle`, `lookup`, `shoot`, `analyze` | `CameraAccessGate`, `OpenFoodFacts`, `MealAnalysisConfig`, `ScanRecapView` |
| `App/Screens/MiniApps/Nutrition/MealPhotoAnalysis.swift` | `MealPhotoAnalyzing`, `MealAnalysisConfig`, `OnlineMealAnalyzer` (désactivé), `OnDeviceMealAnalyzer` (`runVision`, `classify`, `instanceCrops`, `gridCrops`, `featurePrint`) | Vision, `FoodLabelMatcher`, `MealMemory`, `SharedStore` |
| `Shared/Domains/FoodLabelMatcher.swift` | `MealProposal`, `proposals`, `find`, `pick`, `accepts`, `cookedChoice` | `DishTemplate`, `FoodSynonyms`, `ScanLearning`, `FoodDatabase.search` |
| `Shared/Domains/DishTemplates.swift` | `FoodSynonyms.queries`, `DishTemplate.all` (19) | `FoodLabelMatcher` |
| `Shared/Domains/ScanRecap.swift` | `ScanLine`, `ScanRecap` (`add`, `replace`, `setGrams`, `commit`), `suggestions` | `NutritionState`, `ScanLearning`, `MealMemory` |
| `Shared/Domains/ScanLearning.swift` | `ScanCorrection`, `ScanLearning` (`record`, `preferredFoodID`, `usualGrams`), `ScanUncertainty`, `NutrientRange`, `EntryOrigin` | `FoodLabelMatcher`, `ScanRecap` |
| `Shared/Domains/MealMemory.swift` | `MealMemoryEntry`, `MealMemory` (`distance`, `nearest`, `suggestionWithDate`) | `OnDeviceMealAnalyzer`, `ScanRecap` |
| `Shared/Domains/FoodDatabase.swift` | `FoodDatabase` (table, `search`, `item`), `OpenFoodFacts` (`search`, `lookup`, `barcodeForms`, `upcEToUPCA`, `food(fromProductJSON:)`) | `NutrientFile`, `URLSession` |
| `App/Core/NutrientFile.swift` | `NutrientFile.search` (CNF depuis `cnf-foods.json`) | `OnDeviceMealAnalyzer.localSearch` |
| `Shared/Domains/Nutrition.swift` | `FoodItem.nutrients`, `NutritionTotals`, `NutritionState` (`scanLearning`, `mealMemory`, `log`) | `SharedStore` |
| `App/Screens/MiniApps/Nutrition/ScanRecapView.swift` | `ScanRecapView`, `ScanLineRow`, `kcalRangeText`, bascule « Contribuer » | `ScanRecap`, `FoodSearchView` |
| `Shared/Intents/FoodScannerIntent.swift` | `OpenFoodScannerIntent`, `AppOpenRequests` (iOS 18) | `Router` |

```
 Caméra (DataScanner) ou PhotosPicker
        |                      |
 code-barres lu          UIImage (mémoire seulement)
        |                      |
 lookup(code)            OnDeviceMealAnalyzer.analyzeMeal
  |-- aliments perso       uprightCopy (max 1024 px)
  |-- Open Food Facts      VNClassifyImageRequest (photo + <=4 objets ou grille 3x3)
  |   (réseau, code seul)  VNGenerateImageFeaturePrintRequest
  |                              |
  |                        FoodLabelMatcher.proposals
  |                          (gabarits, synonymes, table + CNF, apprentissage)
  |                              + MealMemory (voisins d'empreinte)
  v                              v
       ScanRecap (lignes éditables, grammes, fourchette kcal)
                        |
              ScanRecapView (correction par l'utilisateur)
                        |
   commit -> NutritionState (journal, scanLearning, mealMemory)
                        -> SharedStore (App Group, local)
```

## 8. Coûts, performances, confidentialité

- Coût par analyse : photo = aucun service payant (tout local) ; énergie et batterie : non déterminable depuis le code. Code-barres : API OFF publique et gratuite [supposé : conditions non relues]. Analyse en ligne : rien d'implémenté, coût non déterminable.
- Appels réseau : un seul service, OFF, via `URLSession.shared` (`FoodDatabase.swift` l.488-523) : code-barres (une requête par forme) et recherche textuelle (`NutritionSpace.searchOnline`, 1,2 s après la dernière frappe dès 4 lettres quand peu de résultats locaux : hors scanner photo). Aucune requête réseau dans le chemin photo.
- Données envoyées à OFF : le code-barres (ou le texte cherché), l'adresse IP (inévitable en HTTPS), un User-Agent `Ardane/1.0 (adresse du support)`. Pas de nom, d'identifiant d'appareil ni de photo.
- Photos : `UIImage` en mémoire, jamais écrite, abandonnée à la fin de `analyze`. Conservés : l'empreinte (~2 048 octets emballés par repas, 200 max) et les corrections.
- Manifeste de confidentialité (`Shared/PrivacyInfo.xcprivacy`) : pas de suivi, aucune donnée collectée déclarée ; API déclarées UserDefaults et FileTimestamp. Cohérent. Permission `NSCameraUsageDescription` : « aucune photo n'est enregistrée ni envoyée ». Le sélecteur de photos d'Apple n'exige pas d'accès à la photothèque.
- Sécurité : fichiers d'état en `.completeFileProtectionUntilFirstUserAuthentication`, décodage tolérant, plafonds de taille (500 corrections, 200 repas, empreinte ≤ 4 096).
- Temps d'analyse : aucune mesure dans le dépôt ni dans `ci-report`. Jusqu'à 6 requêtes Vision (1 + 4 recadrages + empreinte) ou 11 (grille) [temps réel non déterminable ; supposé : quelques secondes]. Les tests CI tournent sur simulateur avec `usesCPUOnly = true` : non représentatifs d'un iPhone.
- Hors ligne : photo entièrement hors ligne ; code-barres hors ligne seulement pour les produits déjà locaux.

## 9. Notes sur 10 (uniquement ce qui est démontrable)

Aucun taux mesuré n'est consultable : les notes s'appuient sur la conception du code, les assertions des tests et leurs limites.

| Catégorie | Note | Justification |
|---|---|---|
| Reconnaissance des aliments | 5/10 | Classifieur Apple générique + dictionnaire manuel + 19 gabarits + 44 photos de test. `testRecognitionRateOnRealPhotos` est permissif (OK si un des 5 premiers aliments contient un nom attendu ou alternatif), n'exécute pas le pipeline de production et force `usesCPUOnly` ; seule assertion : au moins 1 photo reconnue. Taux réels indisponibles. |
| Estimation des portions | 2/10 | Aucune estimation visuelle ; portions fixes de table et de gabarit ; ±40 % non mesuré ; l'apprentissage ne corrige qu'après ≥ 2 validations. |
| Précision des calories | 4/10 | Formule exacte mais entrée (aliment et grammes) incertaine ; fourchettes honnêtes. Le seul jeu quantitatif (12 repas synthétiques aux grammes inventés) ne mesure que l'erreur due aux portions et n'est pas une validation réelle. |
| Précision des macros | 4/10 | Même calcul ; macros inconnues d'OFF signalées ; aucun jeu de mesure sur de vrais repas. |
| Identification des ingrédients | 4/10 | 19 gabarits à grammes fixes ; sauces et huiles suggérées par mots-clés ; ailleurs, une étiquette donne un aliment. |
| Scan des codes-barres | 8/10 | Lecture native, plusieurs formes de code, 3 issues de secours, parsing OFF testé (kJ, par portion, macros manquants, virgules). Limites : OFF seul, pas de cache, 3 symbologies, qualité des fiches communautaires, aucun test réseau. |
| Gestion des corrections | 6/10 | Mémorisation locale solide (quarantaine, médiane, plafonds, décodage tolérant, ~91 tests logiques) mais pas un modèle appris ; effet à partir de 2 corrections ; pas de partage. |
| Vitesse d'analyse | non noté | Aucune mesure. |
| Fiabilité globale | 4/10 | Architecture honnête (estimations signalées, jamais de valeur inventée), mais précision réelle inconnue et aucune mesure de quantité. |

Tests : ~118 pour le scanner (ScanAccuracyTests 25, FoodPhotoRecognitionTests 2, ~91 pour FoodLabelMatcher, DishTemplates, ScanLearning, ScanRecap et MealMemory). Jeux : 44 photos libres de droits (`Tests/Fixtures/FoodPhotos/manifest.json` : single 8, composite 20, dessert 7, plate 5, breakfast 4 ; licences CC0 25, CC BY 2.0 11, CC BY 4.0 4, domaine public 4, aucune CC BY-SA ; noms d'aliments attendus seulement, aucun gramme de référence) et 12 repas synthétiques.

## 10. Synthèse

**Fonctionnement aujourd'hui.** Un classifieur Apple générique donne des étiquettes ; un dictionnaire et des gabarits écrits à la main les transforment en aliments (table intégrée + CNF) ; les grammes sont des portions usuelles que l'utilisateur corrige ; le calcul est déterministe sur les valeurs pour 100 g ; la personnalisation mémorise les corrections et reconnaît les assiettes déjà validées ; les codes-barres passent par Open Food Facts.

**Forces.** Photo 100 % locale sans dépendance tierce ; estimations toujours signalées par des fourchettes ; protections contre les corrections aberrantes ; nombreux tests de logique ; licences de photos conformes.

**Faiblesses.** Quantités non estimées ; reconnaissance non mesurée ; fourchettes ±5/30/40 % sans base empirique ; dictionnaire et gabarits limités ; sauces et huiles non estimées ; rapports de précision perdus à chaque run.

**Non implémenté.** Analyse en ligne (étape B), LiDAR (9.B), référence d'assiette ou de main (9.A(3)), presets Petite/Moyenne/Grande (9.A(2)), OCR du tableau nutritionnel (10.C), partage des corrections.

**Trois changements qui amélioreraient le plus la précision** (coûts et difficultés estimés [supposé]).
1. Estimation de taille de portion par référence (assiette, main, profondeur). Principal facteur d'erreur des scanners. Difficulté moyenne à haute, coût de développement seul, 100 % sur l'appareil. Commencer par le choix de taille d'assiette (9.A(3)), puis Petite/Moyenne/Grande.
2. Classifieur alimentaire dédié embarqué (CoreML, Food-101 ou plus grand, quantifié). Meilleur rappel que le classifieur générique. Difficulté moyenne (conversion, validation, poids de plusieurs dizaines de Mo, licence du jeu de données). Compatible avec le traitement sur l'appareil.
3. Mesure systématique sur un jeu de repas pesés (9.C / 10.D) avec des taux conservés dans un rapport persistant (aujourd'hui `ci-report` est écrasé à chaque run). Sans mesure, aucune amélioration n'est vérifiable. Difficulté faible côté outil ; dépend de photos et de pesées fournies par l'utilisateur.

**Pour approcher Cal AI** (sources secondaires, à recouper) : un teardown (RaftLabs) indique que Cal AI combine le capteur de profondeur du téléphone avec un modèle entraîné sur des images d'aliments et sépare composants et proportions ; Cal AI revendique 90 % de précision sur les aliments visibles et reconnaît que les ingrédients cachés sont plus difficiles. Une étude préliminaire de chercheurs du NIH sur 4 applications (MyFitnessPal, Lose It!, Cal AI, Appediet) et plus de 100 repas relève une sous-estimation moyenne de 250 à 345 kcal ; les glucides sont mieux estimés que les lipides et protéines. Ce qui manquerait à Ardane : un grand modèle multimodal (en ligne) et une base d'aliments plus large, plus un entraînement sur de nombreuses photos annotées en grammes.
**Conflit avec la contrainte « sur l'appareil »** : un modèle multimodal en ligne enverrait la photo à un service externe, ce qui contredit la décision du 2026-10-26 (chantier 9 de `Demandes.md` ; elle n'est pas dans `Decisions.md`, où seule la ligne du 2026-10-22 dit que l'IA en ligne reste désactivée). Passer en ligne exigerait une décision explicite de l'utilisateur et la mise à jour de `PRIVACY.md`, du libellé de permission caméra et du manifeste. Un modèle multimodal embarqué (Apple Foundation Models, VLM quantifié) reste compatible, mais sa disponibilité et sa précision sur la nourriture ne sont pas vérifiées.

## Incohérences entre documentation et code
1. `Demandes.md` : 8.A, 8.B, 10.A, 10.B et 10.E sont décrits `[ ]` alors que code et tests existent (commits 4a62040, d7c6c90).
2. `Decisions.md` ne contient pas la décision du 2026-10-26 « sans envoi hors de l'appareil » ni l'autorisation de photos de test.
3. 10.A prévoit des états cru/cuit proposés : le code calcule `MealProposal.alternative` mais l'interface ne l'utilise pas (`ScanLine` n'a pas de champ `alternative`) ; idem `isOptional` et `dishName`.
4. `Chantiers.md` l.110 mentionne une limite du préfixe de 3 lettres (« pen » donne pâtes) ; `accepts` l'a depuis corrigée [supposé périmé].
5. `Chantiers.md` l.108 dit « étape A complète » alors que 9.A(2) et 9.A(3) ne sont pas faits.
6. `MealPhotoAnalysis.swift` : `orientation(of:)` privée inutilisée ; `#available(iOS 17.0, *)` redondant (aucun impact).
7. `ScanLine.uncertainty` : une ligne issue d'une photo reste à ±40 % même après saisie du poids, contrairement au commentaire « a quantity the person set is close to exact » (`ScanRecap.swift` l.48-52).
8. `FoodPhotoRecognitionTests` appelle `FoodLabelMatcher.proposals(from:)` avec `FoodDatabase.search` seul (sans CNF), sans recadrages ni mémoire : le taux mesuré ne représente pas le pipeline réel.
9. Le manifeste déclare `NSPrivacyCollectedDataTypes` vide (cohérent) mais `PRIVACY.md` mentionne l'empreinte visuelle comme donnée conservée (non requis puisque locale).
10. Les rapports `SCORES-*`, `RECO-*`, `SCAN-*` n'existent plus dans `ci-report` (un seul `report.txt`, dernier run avec `tests: skipped`).

## Incertitudes
Aucun taux CI de reconnaissance, d'erreur en grammes ni de temps d'analyse n'est disponible ; le comportement de `resetAllData` sur `nutrition` n'est pas relu en détail ; les affirmations sur Cal AI viennent de sources secondaires.

Sources : code lu (chemins ci-dessus) ; Apple (`VNClassifyImageRequest.supportedIdentifiers`) ; objc2-vision (taxonomie de 1 303 identifiants) ; RaftLabs (teardown de Cal AI) ; Drugs.com (étude de précision des applications photo de calories).
