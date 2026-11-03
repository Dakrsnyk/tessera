---
tags: [ardane, scanner, chantier-22, recherche]
---

# Recherche : reconnaissance et segmentation des aliments, 2026-11-02

Chantier 22.1, volet modèles et jeux de données. Légende : [D] documenté (source citée) ; [C] constaté pendant la recherche ; [S] supposé ou déduit ; [calcul] = paramètres × 2 octets (fp16) ou × 1 (int8), poids seuls.

## Constats principaux
1. Presque tous les jeux alimentaires célèbres sont réservés à la recherche ou sans licence claire : Food-101, UECFoodPix(Complete), FoodX-251, FoodSeg103 (non tranché), Recipe1M. Exploitables commercialement : **MyFoodRepo / AIcrowd Food Recognition (CC BY 4.0)**, **Nutrition5k (CC BY 4.0)**, Open Images (annotations CC BY 4.0, images CC BY 2.0 à vérifier une par une).
2. Poids Apple MobileCLIP et FastVLM : « Apple Machine Learning Research Model License », recherche non commerciale : exclus.
3. Ultralytics YOLO v8/v11 : AGPL-3.0 ou licence Enterprise payante ; SegFormer (NVIDIA) : non commercial : exclus.
4. Briques permissives et embarquables : RF-DETR (Apache 2.0, toutes les tailles de segmentation), RT-DETR, SAM 2, EdgeTAM (export Core ML fourni), DINOv2, SmolVLM (tous Apache 2.0).
5. Le meilleur résultat publié par ingrédient (FoodSeg103) plafonne à ≈ 46 mIoU : la reconnaissance fine d'ingrédients reste difficile, la licence n'est pas le seul verrou.
6. iOS 27 (WWDC26) : Foundation Models accepte des images (`Attachment`, iOS 27+, appareils Apple Intelligence) ; Vision gagne `GenerateIterativeSegmentationRequest` (point/boîte → masque) ; framework Core AI. Plancher d'Ardane = iOS 17 : seulement derrière `#available(iOS 27, *)`. Core ML reste la voie pour iOS 17 à 26.

Typologie à ne pas confondre : classifieur de PLAT (une étiquette par photo : Food-101, UEC-Food256, ISIA Food-500, Food2K, FoodX-251) ; segmentation sémantique par INGRÉDIENT (FoodSeg103, UECFoodPix) ; segmentation d'INSTANCES par aliment (MyFoodRepo, Open Images) ; régression masse/calories (Nutrition5k).

## Jeux de données
| Jeu | Contenu | Référence (conditions) | Licence | Commercial ? |
|---|---|---|---|---|
| Food-101 | 101 plats, ~101 000 images | EfficientNet-B4 91,5 %, B7 93,0 % ; DINOv2 sonde linéaire S 89,1 / B 92,8 / L 94,3 | aucune licence ETH ; images Foodspotting « not property of ETHZ », usage au-delà du fair use scientifique à négocier | Non sans avis juridique |
| FoodSeg103 | 7 118 images, 103 ingrédients, 42 097 masques (images Recipe1M) | mIoU : SETR-MLA 45,1 ; Swin-S 41,6 | aucune licence trouvée pour les données (code Apache 2.0) | Non tranché : traiter comme non commercial |
| UECFoodPix(Complete) | 10 000 images, 103 classes | DeepLabv3+ 0,416 / 0,555 mIoU | « non-commercial research purpose only » | Non |
| **MyFoodRepo / AIcrowd 2022** | photos réelles de repas (Suisse), instances COCO ; v2.1 = 54 392 images, 100 256 annotations, 323 classes | Mask R-CNN R50 AP50 0,47–0,51 ; HTC 0,49–0,54 ; meilleure équipe 0,568 | CC BY 4.0 (règles AIcrowd 2022 et papier Frontiers ; un catalogue tiers dit CC0 : retenir CC BY 4.0) | **Oui, avec attribution** : le plus proche de l'usage d'Ardane |
| **Nutrition5k** | ~5 000 assiettes de cafétérias, RGB-D vue de dessus, masse par ingrédient ; 181 Go | RGB : 70,6 kcal (26,1 %), masse 40,4 g (18,8 %) ; RGB-D volume : 41,3 kcal (16,5 %), 29,4 g (13,7 %) ; nutritionnistes ~41 % | CC BY 4.0 | **Oui, avec attribution** ; peu varié, pas de masques |
| Open Images V7 | 2,8 M masques, 350 classes dont ~50 aliments | — | annotations CC BY 4.0, images CC BY 2.0 non garanties | Oui, image par image |
| FoodX-251 | 251 classes | — | non commercial, redistribution interdite | Non |
| UEC-Food256, Recipe1M, ISIA Food-500, Food2K | — | — | non vérifié / non commercial | À considérer non |
| MM-Food-100K | 100 000 échantillons | — | conflit (OpenRAIL-M non commercial) | Non |
| NutritionVerse-Real | 889 images, iPhone 13 Pro Max, ingrédients pesés | — | licence introuvable | À vérifier (validation) |

## Modèles
**Classifieurs (une étiquette par recadrage)**
| Modèle | Licence | Précision | Taille [calcul] | Verdict |
|---|---|---|---|---|
| **DINOv2 ViT-S/14** (+ tête) | Apache 2.0 code et poids | 89,1 % Food-101 (sonde linéaire gelée) | ~42 Mo fp16 / ~21 Mo int8 | **Retenu** ; l'embedding sert aussi à la mémoire personnelle |
| EfficientNet / MobileNet affinés | code permissif, poids ImageNet en zone grise | B4 91,5 % Food-101 | B0 ≈ 11 Mo | Alternative |
| CLIP (OpenAI) | fiche : déploiement hors périmètre | — | — | Écarté |
| SigLIP 2 base | Apache 2.0 | — | ~0,4 B param. | Possible (vocabulaire libre), lourd |
| MobileCLIP / MobileCLIP2 | poids recherche seule | — | — | Exclu |
| Vision `VNClassifyImageRequest` | OS | non publié | 0 | Repli |
| Create ML | modèle à nous, entraînement macOS seulement | — | petit | Prototype |

**Détection et segmentation d'instances**
| Modèle | Licence | Précision | Core ML / taille | Verdict |
|---|---|---|---|---|
| **RF-DETR-Seg Nano/Small** | Apache 2.0 (Nano–Large et toutes les tailles de segmentation ; Atto/Femto/Pico/XL/2XL sous licence « PML ») | COCO segmentation : Nano 40,3 AP, Small 43,1 AP | export Core ML documenté pour la détection, PAS pour la tête de segmentation ; ~34–67 Mo | **Retenu** (à vérifier : export de la segmentation) |
| RT-DETR / v2 | Apache 2.0 | R18 46,5 AP | Core ML non mentionné | Repli |
| DETR segmentation (Core ML d'Apple) | Apache 2.0 | classes COCO | 86 Mo, 40 ms sur iPhone 15 Pro Max (ANE) | Preuve de faisabilité |
| Mask R-CNN | permissif | — | NMS/RoIAlign difficiles à convertir | Écarté |
| SegFormer | NVIDIA non commercial | — | — | Exclu |
| YOLO v8/v11, FastSAM | AGPL-3.0 | — | — | Exclus |

**Segmentation sans classe**
| Modèle | Licence | Précision / vitesse | Taille | Verdict |
|---|---|---|---|---|
| **EdgeTAM** | Apache 2.0 | 55,5 mIoU (1 clic) ; image 40,4 FPS sur iPhone 15 Pro Max | ~20 Mo (export Core ML fourni) | Meilleur candidat iPhone (repli boîtes → masques) |
| SAM 2 tiny (Core ML d'Apple) | Apache 2.0 | — | 79,6 Mo | Repli plus lourd |
| EdgeSAM | NTU S-Lab (commerce non vérifié) | 38,7 FPS iPhone 14 | — | À éviter |
| MobileSAM, EfficientSAM | Apache 2.0 | — | ONNX seulement | Secondaires |
| SAM 3 | SAM License (export contrôlé), 848 M param., GPU | — | — | Non embarquable |
| FoodSAM | code Apache 2.0, poids dépendants de FoodSeg103 | 46,42 mIoU | — | Méthode seulement |
| Vision foreground (existant) | OS | — | 0 | Repli |

**Vocabulaire libre** : Grounding DINO tiny, OWLv2, Florence-2-base (Apache/MIT, ~0,2 B param., pas de voie Core ML connue) : trop lourds ; un classifieur DINOv2 sur recadrages est plus léger.

**Multimodaux** : Apple Foundation Models + images (iOS 27+, 0 Mo, aucune précision alimentaire publiée, pas de masque) : aide facultative iOS 27+, jamais source de grammes. FastVLM : recherche seule (exclu). SmolVLM 256M/500M (Apache 2.0) : ~600 Mo fp16, précision alimentaire inconnue. Moondream2 : 54,7 % sur FoodNExTDB contre Gemini 70,2, Claude 65,9, ChatGPT 64,3 (reconnaissance seule, auteurs : « pas encore fiables »). Qwen2/3-VL-2B : trop lourds.

## Pipeline Apple
`VNCoreMLRequest` (iOS 11+) : classifieur → `VNClassificationObservation` ; autres sorties → `VNCoreMLFeatureValueObservation` (décodage DETR à écrire en Swift) ; confiances non étalonnées (à étalonner par nous). coremltools 9 publie des roues Linux : conversion sous Linux/WSL ; la prédiction n'est disponible que sur macOS → contrôles de parité sur le runner macOS de la CI. Xcode compile le `.mlpackage` à la construction (intégration au groupe synchronisé à tester par `[check]`). Create ML : macOS seulement.

## Options
- **A (incrémentale)** : masques Vision actuels + DINOv2-S gelé + tête entraînée sur recadrages MyFoodRepo (+ Open Images). Le moins risqué, 21–42 Mo ; masques toujours génériques.
- **B (segmenteur + classifieur)** : RF-DETR-Seg affiné sur MyFoodRepo, puis tête DINOv2 par instance ; repli RF-DETR détection + EdgeTAM ; repli final = A. Un masque par aliment (base de l'aire et du volume), licences propres ; export de segmentation non documenté, latence iPhone inconnue, 55–110 Mo, classes suisses/européennes.
- **C (Apple seul, iOS 27+)** : 0 Mo, sans entraînement, mais iOS 27 seulement, non déterministe, précision non publiée.

**Recommandation : B livrée en deux jalons, A d'abord, puis le segmenteur.** Seule combinaison entièrement sous licence commerciale confirmée, entraînable sur données CC BY 4.0 sans GPU local et capable de produire un masque par aliment. C peut s'ajouter derrière `#available(iOS 27, *)` comme aide, jamais comme source de grammes.

À entraîner : segmenteur RF-DETR-Seg sur MyFoodRepo v2.1 (+ Open Images vérifié) ; tête de classification sur les recadrages ; étalonnage sur repas pesés (Nutrition5k pour masse/volume, puis repas de l'utilisateur). Ne rien livrer entraîné sur Food-101, FoodSeg103, UEC, FoodX, ISIA, Food2K, Recipe1M sans clarification écrite des licences.
Coût estimé [S] (location GPU, rien acheté) : tête < 1 h-GPU (< 1 $) ; segmenteur 20–80 h-GPU (≈ 10–150 $) ; premier cycle complet ≈ 20–200 $. Prix relevés le 2026-11-02 : RunPod RTX 4090 0,34–0,89 $/h, A100 80 Go 1,19–1,79 $/h ; Lambda A10 1,29 $/h. À mesurer sur un petit essai avant d'engager.

Normalisation : les classes MyFoodRepo ont leur propre ontologie (correspondance vers `FoodDatabase`/CNF à écrire). Les empreintes `MealMemory` (Vision feature print) ne sont pas comparables à un embedding DINOv2 : versionner les entrées par modèle.
Attention : tout poids livré dans le dépôt public devient public ; GitHub bloque les fichiers de plus de 100 Mo.

## Incertitudes
Aucune latence iPhone publiée pour RF-DETR, DINOv2 ni les têtes de segmentation. Export Core ML de RF-DETR-Seg non documenté. Licences non confirmées : FoodSeg103, UEC-Food256, Recipe1M, ISIA, Food2K, NutritionVerse-Real, EdgeSAM ; poids ImageNet en zone grise (pas d'avis juridique). MyFoodRepo : contrôler le fichier de licence au téléchargement (connexion AIcrowd) et garder une preuve datée. Chiffres EfficientNet B4/B7 et CLIP issus de résumés.

## Sources principales
Jeux : data.vision.ee.ethz.ch/cvl/datasets_extra/food-101 ; huggingface.co/datasets/ethz/food101 ; github.com/google-research-datasets/Nutrition5k ; arXiv 2103.03375 ; xiongweiwu.github.io/foodseg103.html ; github.com/LARC-CMU-SMU/FoodSeg103-Benchmark-v1 ; mm.cs.uec.ac.jp/uecfoodpix ; aicrowd.com/challenges/food-recognition-benchmark-2022 ; discourse.aicrowd.com (règles du 1er fév. 2022) ; Frontiers in Nutrition 10.3389/fnut.2022.875143 ; github.com/karansikka1/iFood_2019 ; storage.googleapis.com/openimages (V7, classes de segmentation).
Modèles : github.com/facebookresearch/dinov2 ; github.com/roboflow/rf-detr et rfdetr.roboflow.com (export Apple) ; github.com/lyuwenyu/RT-DETR ; ultralytics.com/license ; github.com/NVlabs/SegFormer ; github.com/facebookresearch/sam2, sam3, EdgeTAM ; huggingface.co/apple/coreml-sam2-tiny, coreml-detr-semantic-segmentation ; github.com/apple/ml-mobileclip et ml-fastvlm (licences des modèles) ; huggingface.co/HuggingFaceTB/SmolVLM-256M-Instruct ; vikhyatk/moondream2 ; Qwen2-VL-2B.
Apple : documentation `VNCoreMLRequest`, Create ML, Foundation Models (`Attachment`, analyse d'images), `GenerateIterativeSegmentationRequest`, Core AI, WWDC26 ; coremltools (prédiction macOS seulement ; roues Linux sur PyPI). Prix : runpod.io/pricing ; lambda.ai/pricing.
