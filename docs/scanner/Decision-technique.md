---
tags: [ardane, scanner, chantier-22, decision]
---

# Décision technique : nouveau scanner alimentaire (2026-11-02)

Chantier 22, phase 1. Fondé sur : `docs/audits/Audit-scanner-alimentaire-2026-11-02.md` (état actuel), `Recherche-modeles.md`, `Recherche-profondeur-volume.md`, `Recherche-bases-nutritionnelles.md` (sources, licences, chiffres). Ce document dit **ce qui est retenu, ce qui est écarté et pourquoi**, puis l'ordre de construction. Rien ici n'est encore une fonctionnalité livrée : l'état réel de chaque brique est suivi dans le tableau final.

## Principes non négociables
1. **Local par défaut** : capture, reconnaissance, segmentation, géométrie, calcul et corrections sur l'iPhone ; aucune photo envoyée. `OnlineMealAnalyzer` reste désactivé. Toute option cloud serait une proposition séparée, désactivée, soumise à décision explicite et à la mise à jour de `PRIVACY.md`, du libellé caméra et du manifeste.
2. **Aucun chiffre fabriqué** : un poids est une estimation avec une loi d'incertitude et une source (mesure, assiette, portion, habitude) ; les valeurs initiales non mesurées sont marquées « à mesurer » ; une précision n'est annoncée qu'après mesure sur repas pesés.
3. **Ancien pipeline gardé en secours** tant que le nouveau n'est pas meilleur, prouvé par le protocole de mesure (`Protocole-mesure.md`).
4. **Licences propres** : code, poids ET données d'entraînement utilisables commercialement, vérifiés et datés. Rien d'entraîné sur Food-101, FoodSeg103, UECFoodPix, FoodX, ISIA, Food2K ou Recipe1M sans clarification écrite.
5. iOS 17 minimum, compilable à chaque étape, peu de dépendances (bibliothèques Apple + modèles Core ML).

## Appareil de référence de l'utilisateur
iPhone 11 Pro : **pas de LiDAR**, pas d'Apple Intelligence, puce A13. Conséquence : la voie sans LiDAR est la seule que l'utilisateur peut mesurer ; elle est la voie principale. Les mesures de vitesse et de mémoire se font sur cet appareil (cas prudent).

## Architecture cible
```
 Photo (DataScanner / PhotosPicker)            [option] Session ARKit (iPhone Pro LiDAR)
            |                                                |
  FoodImageCapture : redressement, gravité (CoreMotion), focale (EXIF/intrinsèques)
            |
  FoodSegmentationEngine : un masque par aliment
     v1 : Vision foreground (existant) ; v2 : RF-DETR-Seg affiné ; repli : RF-DETR détection + EdgeTAM
            |
  FoodRecognitionEngine : nom de chaque masque + top-3 étalonné
     v1 : VNClassifyImageRequest + FoodLabelMatcher (existant) ; v2 : DINOv2-S gelé + tête entraînée
            |
  FoodCompositionEngine : composants visibles, gabarits (existant), suggestions d'huile/sauce à confirmer
            |
  Référence d'échelle : ellipse de l'assiette + diamètre choisi (20/24/27 cm ou vaisselle enregistrée)
            |                                         | [option LiDAR] carte de hauteur sur le plan
  FoodVolumeEstimator : aire du masque x épaisseur type (log-normale)   ou   intégration de la carte de hauteur
            |
  FoodMassEstimator : volume x densité apparente (FCÉN, type de vrac) x facteur personnel appris
            |
  NutritionResolver -> FoodRepository (base unifiée sourcée ; OFF en ligne pour les codes-barres)
            |
  NutritionCalculationEngine : valeur/100 g x grammes / 100 (déterministe, inconnu jamais = 0)
            |
  FoodScanConfidenceEngine : loi log-normale, intervalle à 90 %, recalage conforme sur repas pesés
            |
  ScanRecap / ScanRecapView : aliments délimités, grammes ± fourchette, correction, validation
            |
  FoodLearningEngine : ScanLearning + MealMemory (existants) + corrections enrichies + consentement
```
Correspondance avec l'existant : `OnDeviceMealAnalyzer` (capture, reconnaissance, segmentation v1), `FoodLabelMatcher` + `DishTemplates` (composition), `FoodDatabase` + `NutrientFile` (résolution, remplacés à terme par `FoodRepository`), `FoodItem.nutrients` (calcul), `ScanUncertainty` (confiance, remplacée par la propagation log-normale), `ScanLearning` + `MealMemory` (apprentissage). Nouveaux types et protocoles : `Shared/Domains/Scanner/`.

## Choix retenus
| Domaine | Retenu | Pourquoi |
|---|---|---|
| Quantités, tous iPhone | **Assiette de référence + aire du masque + épaisseur type + densité + facteur personnel** | seule voie disponible sur tous les appareils (dont l'iPhone 11 Pro), erreurs explicables, aucune dépendance |
| Quantités, iPhone Pro | **LiDAR (ARKit `smoothedSceneDepth`) en carte de hauteur**, mode expérimental désactivé | seule mesure métrique native, mais jamais validée sur des repas et impossible à vérifier chez l'utilisateur : activé seulement après mesure par un possesseur d'iPhone Pro |
| Densités | mesures en ml de la FCÉN (puis USDA tasse/cuillère), filtrées, typées (vrac lâche/tassé, liquide, solide) | licence ouverte, déjà embarquées ; FAO exclue sans accord écrit |
| Reconnaissance v2 | **DINOv2-S/14 gelé + tête** entraînée sur recadrages MyFoodRepo (CC BY 4.0) + Open Images vérifié | Apache 2.0, 21–42 Mo, 89 % Food-101 en sonde linéaire, embedding réutilisable pour la mémoire personnelle |
| Segmentation v2 | **RF-DETR-Seg Nano/Small** affiné sur MyFoodRepo ; repli RF-DETR détection + EdgeTAM | Apache 2.0, un masque par aliment ; export Core ML de la tête de segmentation à prouver |
| Base nutritionnelle | **FCÉN 2026 pivot + USDA (CC0)**, puis CIQUAL 2025 si licence confirmée ; SQLite en lecture seule ; provenance par valeur ; jamais de fusion de valeurs entre sources | licences sans partage à l'identique, couverture Québec, sources traçables |
| Codes-barres | Open Food Facts **API v3**, en ligne seulement ; recherche texte explicite par Search-a-licious | v2 dépréciée ; la recherche pendant la frappe enfreint les règles d'OFF ; embarquer OFF rendrait la base ODbL |
| Incertitude | log-normale propagée (surface, épaisseur ou hauteur, densité, reconnaissance), intervalle à 90 %, **recalage conforme** sur repas pesés | intervalles dont la couverture est vérifiable |

## Écartés
| Écarté | Raison |
|---|---|
| Profondeur monoculaire (Depth Anything V2 Small) comme source de volume | relative (échelle et décalage inconnus) ; erreur de l'ordre de l'épaisseur d'un plat ; jamais validée sur nourriture. Peut-être plus tard comme simple indice plat/tas si une mesure montre un gain |
| Disparité double caméra (iPhone 11 Pro) comme mesure | « relative » selon Apple |
| Multi-vues / photogrammétrie (VolE, Object Capture) | minutes de calcul, GPU ou iPhone Pro, parcours à 360° |
| Food-101, FoodSeg103, UECFoodPix, FoodX-251, ISIA, Food2K, Recipe1M | licences recherche ou non claires |
| MobileCLIP, FastVLM (Apple) | poids sous licence de recherche non commerciale |
| YOLO v8/v11, FastSAM (Ultralytics) | AGPL-3.0 |
| SegFormer | licence NVIDIA non commerciale |
| Mask R-CNN, Mask2Former | conversion Core ML difficile ou lourde |
| SmolVLM, Moondream, Qwen-VL embarqués | centaines de Mo à plusieurs Go, précision alimentaire non démontrée |
| Apple Foundation Models avec images | iOS 27+ et Apple Intelligence seulement ; au mieux aide facultative plus tard, jamais source de grammes |
| Base FAO/INFOODS des densités | aucune licence commerciale sans accord écrit |
| Extrait d'Open Food Facts embarqué | rendrait toute la base fusionnée ODbL |
| AFCD (Australie) | partage à l'identique |

## Plan de migration (chaque étape compilable et mesurée)
1. **Fondations (22.2)** : `Shared/Domains/Scanner/` (protocoles, géométrie d'assiette, volume, masse, densités FCÉN, incertitude log-normale, recalage) avec tests sur données synthétiques ; migration OFF v3 et recherche explicite ; correction de l'incertitude des lignes dont l'utilisateur a saisi le poids ; protocole de mesure et métriques.
2. **Socle quantités sans LiDAR (22.4, partie 1)** : choix du diamètre d'assiette (mémorisé) et presets Petite/Moyenne/Grande ; estimation par assiette en **mode expérimental** à côté de l'ancienne portion, affichée comme estimation ; les deux sont enregistrées pour comparaison.
3. **Mesure (22.6)** : premiers repas pesés par l'utilisateur sur son iPhone 11 Pro → premiers vrais chiffres (MAE en grammes et kcal, couverture des intervalles) ; l'estimation par assiette devient la valeur par défaut **seulement si elle bat la portion usuelle**.
4. **Base nutritionnelle B1 (22.3/22.4)** : FCÉN 2026 avec `Food_Code`, alias des anciens identifiants, correction des 1 027 aliments sans micronutriments, portions et densités complètes ; puis USDA.
5. **Reconnaissance v2 (22.3)** : DINOv2 + tête sur les recadrages actuels (jalon A), mesuré contre l'ancien ; puis segmenteur RF-DETR-Seg (jalon B) si l'export Core ML est prouvé. Entraînement sur GPU loué, **après accord de l'utilisateur sur le coût** (estimé 20–200 $ pour un premier cycle, à mesurer par un petit essai).
6. **LiDAR (22.4, partie 2)** : session ARKit et intégration de la carte de hauteur, désactivée tant qu'un possesseur d'iPhone Pro ne l'a pas mesurée.
7. **Apprentissage (22.5)** : corrections enrichies (propositions alternatives, quantités initiales et corrigées, version du modèle, conditions de capture, confiance) ; contribution globale facultative, expliquée, anonymisée, désactivée par défaut et sans envoi tant qu'aucun serveur n'est décidé ; réentraînement hors production, versions de modèles, jamais de mise à jour automatique des poids.

## Décisions qui reviennent à l'utilisateur
- Location d'un GPU pour l'entraînement (après un petit essai chiffré).
- Téléchargement de MyFoodRepo (compte AIcrowd) et archivage de sa licence ; téléchargement de la FCÉN 2026 et des fichiers USDA (données ouvertes officielles).
- Formulaire d'usage de l'API Open Food Facts.
- Licence CIQUAL 2025 (téléchargement manuel sur ciqual.anses.fr).
- Noms français des aliments USDA sans équivalent FCÉN : curation relue ou anglais seulement.
- Modification du workflow CI pour des rapports de précision persistants et datés (aujourd'hui la branche `ci-report` est écrasée à chaque run).

## État réel des briques (mis à jour à chaque étape)
| Brique | État |
|---|---|
| Recherche et décision (22.1) | fait le 2026-11-02 |
| Fondations de calcul (22.2) | en cours |
| Protocole de mesure et métriques | en cours |
| Migration Open Food Facts v3 | à faire |
| Socle assiette (expérimental) | à faire |
| Repas pesés et premiers chiffres | à faire (utilisateur) |
| Base FCÉN 2026 + USDA | à faire |
| Reconnaissance v2 (DINOv2) | à faire (entraînement à décider) |
| Segmentation v2 (RF-DETR-Seg) | à faire (export à prouver) |
| LiDAR | à faire, non vérifiable sur l'iPhone 11 Pro |
| Apprentissage enrichi et pipeline de réentraînement | à faire |
