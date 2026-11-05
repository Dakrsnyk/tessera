---
tags: [ardane, scanner, recherche]
---

# Rapports bruts des agents de recherche (mission « 90 / 80 / 90 », 2026-11-04)

Cinq agents `research-architect` (lecture seule, web), deux passes chacun : la 1re, large ; la 2e, vérification à la source primaire demandée par le Chef. Textes conservés tels quels. Ce qui est marqué « non vérifié » le reste. La 2e passe corrige la 1re quand elles diffèrent. Synthèse, décisions et plan : `Plan-scanner-90-80-90-2026-11-04.md`.

## Reconnaissance des aliments et calibration

### Passe 1

Question : comment augmenter la reconnaissance des aliments d'Ardane et fixer la règle des 80 % avec une garantie mesurée ?

Avertissement sur la méthode : je n'ai vérifié à la source que 5 points (listés en section 6). Tout le reste vient de ma connaissance antérieure et est marqué « non vérifié ». Aucun chiffre externe n'est donné sans source. L'objectif de 90 % n'a pas pu être confronté à des résultats publiés comparables ; je n'ai pas trouvé de score multi-aliments P/R/F1 vérifiable.

## 1. Résumé
- Le goulot n'est plus la dorsale. Il vient (a) des aliments non détectés (26 % manquants, surtout les petits) et (b) des confusions fines (pain, laitue, café/latte).
- La levée la plus sûre et chiffrable est la calibration avec prédiction sélective. Elle donne une garantie mesurée sur les ajouts automatiques, pas un gain de rappel.
- DINOv3 est utilisable commercialement sur le papier (licence Meta propre, non OSI), mais pas de gain démontré pour Ardane ; le risque juridique est moyen.
- Les VLM embarqués sont irréalistes sur A13 / 4 Go. Un VLM en ligne (Gemini ou GPT) peut servir de second avis facultatif, avec consentement.
- P/R/F1 ≥ 90 % sur tous les aliments d'une assiette est très probablement hors d'atteinte par la seule IA. Réaliste : ≥ 90 % de précision sur les ajouts automatiques (couverture partielle) et ≥ 90 % de rappel après confirmation de l'utilisateur.

## 2. Technologies (jugement d'architecte ; seules les cases « source » sont vérifiées)

| Techno | Fonctionnement / perf. | Pertinence, iOS, ressources | Licence | Gain estimé |
|---|---|---|---|---|
| Calibration + sélectif + LTT | Seuil choisi par test d'hypothèses avec borne binomiale exacte (arXiv 2110.01052, vérifié) | Aucun modèle, quelques Ko, hors ligne | Papier ouvert | Garantie sur la précision des ajouts auto ; rappel inchangé |
| Mémoire visuelle + a priori utilisateur (déjà en place) | Prototypes DINOv2 des zones validées | Déjà là | Interne | Fort sur les mangeurs réguliers ; à mesurer sur un journal réel (supposé) |
| Multi-étiquettes / vues multiples (TTA) | Plusieurs recadrages, miroir, moyenne | Coût ×N en calcul, A13 acceptable | — | Faible à moyen (supposé, à tester sur ton banc) |
| DINOv3 ViT-B/S | Dorsale Meta 2025 | Core ML possible (non vérifié) | « DINOv3 License », 19 août 2025 (vérifié) : redevance nulle, dérivés permis, mais rétro-ingénierie interdite, indemnisation de Meta en cas d'action IP, résiliation possible, Meta peut modifier le texte | Incertain ; ne pas migrer sans test A/B |
| Nutrition5k (ingrédients) | 5 006 plats, ingrédients et masses | Données d'entraînement multi-étiquettes | Données CC BY 4.0 ; dépôt archivé le 19 avril 2026 ; licence du code non indiquée (vérifié) | Utile pour les ingrédients, mais plats de cantine américaine (biais) |
| VLM embarqués (SmolVLM2, Moondream, Florence-2, Qwen2.5-VL 3B, Gemma 3n, FastVLM) | Légende ou liste d'ingrédients | Non vérifié : 4 Go de RAM, jetons lents, int4 minimum | Variables, non vérifiées | Irréaliste sur iPhone 11 Pro |
| VLM en ligne (GPT-4o, Gemini, Claude) | Second avis en un appel | Hors ligne impossible, données personnelles (photo de repas) à protéger, coût par photo | Conditions API | Preuve : 87,5 % d'identification d'aliments dans Lo et al. 2023 avec GPT-4V, préimpression non relue (vérifié) ; pas de banc indépendant récent trouvé |
| Passio, LogMeal, Foodvisor, Calorie Mama, Bite, Clarifai | SDK ou API | Prix, licence, preuves indépendantes : non vérifiés | Commerciales | Ne pas les adopter sans étude externe ; dépendance et coût récurrent |
| Vocabulaire ouvert (CLIP, OWLv2, YOLO-World, Grounding DINO) | Détection par texte | Trop lourd ou imprécis pour les petits aliments (supposé) | Variable | Non recommandé |

## 3. Calibration et règle des 80 %

Constat : l'ECE de 0,067 est bon en moyenne, mais l'ECE moyen ne garantit rien sur le sous-ensemble des ajouts automatiques, ni par catégorie. Ce n'est pas un seuil de 80 % de confiance qui donne 80 % de précision, surtout quand le détecteur a déjà filtré.

Recommandation : remplacer le seuil fixe de 80 % par un seuil choisi en Learn-then-Test (LTT).
1. Définir le risque : erreur sur les aliments ajoutés automatiquement (un ajout automatique faux = un « nom incorrect »).
2. Jeu de calibration : photos jamais vues par l'entraînement ni par l'étalonnage de température, de préférence séparées par source de photo (pas deux photos du même plat). Viser ≥ 2 000 aliments détectés.
3. Choisir α (par exemple 5 % d'erreur, soit 95 % de précision) et δ (par exemple 10 %). Tester une grille de seuils sur le score (probabilité étalonnée de l'aliment, avec la marge entre les 2 premières classes). Un seuil est retenu si la borne binomiale exacte de l'erreur est ≤ α. Retenir le plus bas seuil valide, donc la plus grande couverture (méthode décrite dans arXiv 2110.01052, vérifié).
4. Mesurer et publier : couverture (part des aliments ajoutés automatiquement), précision avec intervalle de Clopper-Pearson à 95 %, par catégorie (au moins 50 exemples chacune, sinon regrouper), et séparément sur la version « de bout en bout » (détecteur inclus).
5. Prédiction conforme pour les 3 propositions : calibrer un ensemble de taille variable pour viser 95 % de couverture de la bonne étiquette, au lieu du top-3 fixe (88,8 % aujourd'hui). Non vérifié sur Ardane : c'est une proposition à tester.
6. Rejet : en deçà du seuil, demander confirmation ; si la marge entre les 2 premières est faible, ne rien imposer (conforme à ta règle).
7. Cadrage : la garantie vaut tant que les photos ressemblent à la calibration. Prévoir une recalibration à chaque modèle (le seuil est lié à la version).

## 4. Top 5 par impact réel
1. LTT avec seuil par catégorie + mesure de bout en bout : protège la précision des ajouts auto ; effort faible, aucune dépendance.
2. Rappel du détecteur : le « retrouvé 73,9 % » plafonne tout. Ajouter une passe sur les zones non couvertes (tuiles zoomées) pour tomates, beurre, oignon, verre. Gain potentiel le plus grand sur le rappel (supposé, non démontré).
3. Confusions fines : fusions de classes ou listes de désambiguïsation affichées (pain blanc/complet, laitue/salade, café/latte, confiture/beurre) plutôt que des choix imposés ; moins de précision exigée, plus d'honnêteté.
4. Personnalisation : prototypes et a priori utilisateur déjà là ; mesurer avec un journal réel de plusieurs semaines (le gain publié manque).
5. Second avis en ligne facultatif, avec consentement explicite (photo envoyée au service), uniquement pour les cas ambigus ; à étudier après les points 1 à 4, avec un contrat sans entraînement sur les données.

## 5. Irréaliste ou bloquant, et écart avec 90 %
- VLM embarqués : 4 Go de RAM et A13 (non vérifié mais très probable).
- DINOv3 : licence Meta spécifique, clauses d'indemnisation et de résiliation ; avis juridique avant tout usage commercial.
- Nutrition5k : environnement de cantine américaine, plats québécois absents.
- MyFoodRepo : CC BY 4.0 selon ton contexte ; la page AIcrowd consultée ne mentionne aucune licence, à vérifier à la source.
- Licences Food2K, Open Images, FoodSeg103, UEC, Recipe1M : non vérifiées. Ne pas entraîner dessus avant lecture des textes.
- Les solutions payantes : pas de preuves indépendantes retrouvées.
- Écart probable avec 90 % sur tous les aliments d'une assiette : large. Avec 73,9 % de rappel du détecteur et 70,4 % de nom juste au premier coup, l'estimation approximative est un F1 aliment par aliment autour de 55 à 65 % en automatique (calcul de ma part, non mesuré). Atteindre 90 % exige la confirmation de l'utilisateur, un échantillon indépendant de 10 000 plats annotés, et sans doute un jeu d'entraînement beaucoup plus grand et local (québécois).

## 6. Sources vérifiées
- DINOv3 License : https://github.com/facebookresearch/dinov3/blob/main/LICENSE.md
- Nutrition5k (CC BY 4.0, 5 006 plats, archivé 19 avr. 2026) : https://github.com/google-research-datasets/Nutrition5k
- AIcrowd Food Recognition Benchmark 2022 (classement AP 0,423 ; 54 392 images v2.1, 323 classes) : https://www.aicrowd.com/challenges/food-recognition-benchmark-2022
- Learn then Test : https://arxiv.org/abs/2110.01052
- Lo et al., Dietary Assessment with Multimodal ChatGPT : https://arxiv.org/abs/2312.08592
- Pistes non lues en détail : January Food Benchmark https://arxiv.org/pdf/2508.09966v1 ; NutriBench https://arxiv.org/abs/2407.12843

Incertitudes : tout ce qui n'est pas dans la section 6 est non vérifié, en particulier les licences de Food2K, Open Images, SigLIP 2, MobileCLIP, ConvNeXt V2, les SDK payants et les bancs de VLM alimentaires.

Prochaine action : demander une seconde passe de recherche ciblée sur (1) les textes de licence des jeux de données candidats et de MyFoodRepo, (2) un banc indépendant de VLM sur photos de repas, ou lancer l'implémentation LTT sur les 1 000 photos de test en gardant un lot séparé pour la calibration.

### Passe 2

DEUXIÈME PASSE — vérifications et corrections. 19 pages primaires ouvertes. Les limites sont signalées pour chaque point.

## A. Licences (vérifiées à la source)
| Objet | Licence exacte | Clause clé | Verdict commercial | Source |
|---|---|---|---|---|
| Food-101 | « License: unknown » ; un « LICENSE AGREEMENT » propre au jeu | Images de Foodspotting, pas propriété de l'ETH ; « Any use beyond scientific fair use must be negociated with the respective picture owners » | NON pour entraîner un produit | https://huggingface.co/datasets/ethz/food101 (la page ETH https://data.vision.ee.ethz.ch/cvl/datasets_extra/food-101/ ne donne aucune licence) |
| Food2K | Introuvable (page arXiv sans lien d'accès ni licence ; food2k.github.io = 404) | — | Ne pas utiliser sans texte de licence | https://arxiv.org/abs/2103.16107 |
| Open Images V7 | Annotations : CC BY 4.0. Images : « listed as having a CC BY 2.0 license » | « we make no representations or warranties regarding the license status of each image » | OUI avec attribution, mais statut de chaque image non garanti (vérifier par photo) | https://storage.googleapis.com/openimages/web/factsfigures_v7.html |
| SigLIP 2 (base-patch16-224) | Apache 2.0 (étiquette HF), pré-entraîné sur WebLI | — | OUI pour les poids ; WebLI n'est pas publié | https://huggingface.co/google/siglip2-base-patch16-224 |
| MobileCLIP / MobileCLIP2 (code) | MIT | — | OUI (code) | https://github.com/apple/ml-mobileclip |
| MobileCLIP / MobileCLIP2 (poids) | « Apple ML Research Model TOU » (LICENSE_MODELS) | « exclusively for Research Purposes », qui excluent « any commercial exploitation, product development or use in any commercial product or service » ; dérivés idem | NON | https://github.com/apple/ml-mobileclip/blob/main/LICENSE_MODELS |
| MobileCLIP (données) | CC-BY-NC-ND (LICENSE_DATA) | NC + ND | NON | idem dépôt |
| ConvNeXt V2 | Code MIT ; poids ImageNet pré-entraînés et affinés : CC-BY-NC | « except ImageNet pre-trained and fine-tuned models which are licensed under a CC-BY-NC » | NON pour les poids (l'architecture seule est libre ; entraîner soi-même est permis) | https://github.com/facebookresearch/ConvNeXt-V2 |
| EVA-02 | LICENSE du dépôt = MIT, « Copyright (c) 2022 BAAI-Vision » | vente et modification permises avec avis de copyright. La page README EVA-02 ne mentionne pas de licence des poids : poids non confirmés | Code OUI ; poids : non vérifié | https://raw.githubusercontent.com/baaivision/EVA/master/LICENSE |
| DINOv3 | « DINOv3 License » (voir 1er rapport) | — | Voir 1er rapport | https://github.com/facebookresearch/dinov3/blob/main/LICENSE.md |
| MyFoodRepo-273 (images d'entraînement du FRB) | CC-BY-4.0 | Le jeu de test privé n'est pas publié | OUI | https://www.frontiersin.org/journals/nutrition/articles/10.3389/fnut.2022.875143/full |

Correction majeure à mon 1er rapport : MobileCLIP2 et ConvNeXt V2 sont à écarter (poids non commerciaux). SigLIP 2 devient une dorsale candidate propre (Apache 2.0).

## B. January Food Benchmark et NutriBench
- JFB (arXiv 2508.09966, août 2025, CC-BY-4.0, 1 000 photos de repas à étiquettes validées par des humains). Score global : modèle propriétaire january/food-vision-v1 = 86,2 ; meilleure configuration généraliste GPT-4o (Best) = 74,1 ; meilleur Gemini = 60,7. Claude n'est pas évalué. Métriques : similarité d'embeddings du nom du repas, F1 d'ingrédients avec seuil de similarité 0,75 (appariement souple, pas égalité d'étiquette), WMAPE des macros, latence et coût ; score global = moyenne géométrique pondérée. Réserve : les auteurs sont ceux du modèle spécialisé. Le tableau détaillé (F1 par modèle) n'a pas été restitué par la page : non vérifié. https://arxiv.org/abs/2508.09966 et https://arxiv.org/html/2508.09966
- NutriBench (ICLR 2025, v6 du 3 mars 2026) : entrées TEXTE (11 857 descriptions), glucides surtout, 12 LLM dont GPT-4o ; sans rapport avec la reconnaissance d'images. Licence CC BY-NC-SA 4.0 : inutilisable pour entraîner. Chiffres de portion : introuvables. https://arxiv.org/abs/2407.12843
- Correction : mon « 87,5 % » de Lo et al. restait vrai en tant que citation de recherche, mais aucun banc récent n'établit la précision de GPT-4o par aliment dans une assiette.

## C. Passio et LogMeal
- Passio (https://www.passio.ai/nutrition-ai) : aucun prix affiché (renvoi vers /pricing), page décrivant une architecture cloud ; fonctionnement sur l'appareil non confirmé par cette page ; aucune précision revendiquée ; conditions « Tools License Terms » non lues. Étude indépendante : introuvable.
- LogMeal (https://logmeal.com/api/) : API REST par crédits, plans limités à 20 images par jour par utilisateur final et 1 image par seconde, aucun montant ni précision publiée sur cette page ; essai gratuit. Étude indépendante : introuvable. Hors ligne impossible.

## D. État de l'art Food-101 / Food2K
Introuvable : paperswithcode redirige vers Hugging Face. Aucun top-1 ni taille de modèle vérifié. Mon 1er rapport n'en donnait pas ; je n'en ajoute pas. De toute façon Food-101 est inutilisable commercialement (voir A) et son top-1 ne mesure pas l'assiette multi-aliments.

## E. Prédiction conforme et sélective
- Conforme en alimentation : aucun article trouvé appliquant la prédiction conforme à la reconnaissance d'aliments. La recherche renvoie seulement à la méthode générale : Angelopoulos et Bates, « A Gentle Introduction to Conformal Prediction » (https://arxiv.org/pdf/2107.07511 ; score = 1 − softmax de la vraie classe ; couverture ≈ 1−α). Applicable telle quelle ; ce serait une première application documentée (non vérifiée par un article alimentaire).
- Prédiction sélective avec garantie de risque : Geifman et El-Yaniv, « Selective Classification for Deep Neural Networks » (NIPS 2017, https://arxiv.org/abs/1705.08500). Le risque cible est fixé par l'utilisateur et tenu avec probabilité élevée (exemple publié : 2 % d'erreur top-5 sur ImageNet garanti à 99,9 %, en classant près de 60 % des entrées). Learn-then-Test (https://arxiv.org/abs/2110.01052) reste la méthode que je recommande : binomiale exacte, applicable à un risque défini sur les seuls ajouts automatiques, également pour le multi-étiquettes (contrôle du taux de fausses découvertes). Ces articles ne fournissent pas de bibliothèque : l'implémentation est à écrire (quelques dizaines de lignes, sans dépendance).
- Correction de contexte : ces garanties supposent des exemples échangeables entre calibration et production ; une dérive (nouvelle cuisine, autre éclairage) les invalide.

## F. Classement du Food Recognition Benchmark 2022
- Classement final du round 2 de 2022 : introuvable (le fil des gagnants https://discourse.aicrowd.com/t/winners-of-round-2/7685 renvoie vers le classement sans l'afficher). Aucun nom de gagnant confirmé (« team_zi » seulement évoqué dans un commentaire non vérifié).
- Résultats de l'article de l'organisation (Mohanty et al., Frontiers in Nutrition 2022, tours précédents, MyFoodRepo-273 : 24 119 images, 39 325 polygones, 273 classes) : meilleur mAP à IoU > 0,5 / mAR : tour 1 (40 classes) 0,573 / 0,831 ; tour 2 (61) 0,633 / 0,886 ; tour 3 (273) 0,551 / 0,884 ; tour 4 (273) 0,568 / 0,767. Ces scores incluent des ensembles. Reproductible : HTC ResNet101 mAP 0,539, mAR 0,867 (tour 4). L'article ne donne pas l'AP moyen sur les IoU 0,5 à 0,95.
- Correction du 1er rapport : le classement affiché sur la page (AP 0,423 pour le premier) était un classement en cours d'épreuve sur la métrique AP@[0,50:0,95], et non le résultat final ; je l'avais cité avec prudence mais il ne faut pas le lire comme final. L'ordre de grandeur utile : même les meilleurs systèmes plafonnent à environ 0,55 à 0,63 de mAP@0,5 sur 273 classes, ce qui rend l'objectif 90 % de P/R/F1 par aliment encore moins plausible en automatique.

## G. Impact sur la recommandation
La recommandation (1. LTT en priorité) est confirmée. Précision : si une dorsale alternative est testée, ce serait SigLIP 2 (Apache 2.0), pas MobileCLIP ni ConvNeXt V2. L'estimation de F1 de 55 à 65 % dans mon 1er rapport reste mon propre calcul, non mesuré.

Reste non vérifié : licences des poids EVA-02, Food2K, texte de Passio, prix de Passio et LogMeal, top-1 Food-101 / Food2K, résultats par modèle du JFB.

## Segmentation

### Passe 1

Question : comment améliorer la délimitation des aliments (segmentation) du scanner Ardane vers une IoU moyenne ≥ 0,90 ? Lecture seule, 8 recherches web ; rien n'a été installé ni téléchargé. Légende : [V] vérifié à la source citée, [N] non vérifié ou issu de mes connaissances, [S] supposé (estimation à tester).

1. RÉSUMÉ
- Le goulot n'est pas la netteté du contour mais la détection : 73,9 % retrouvés au seuil 0,30 contre 0,82 d'IoU moyenne sur les retrouvés. Les 26 % manqués pèsent davantage que les 0,08 qui séparent 0,82 de 0,90.
- 0,90 d'IoU moyenne sur les seules instances appariées est un objectif tendu mais pas absurde. 0,90 en comptant 0 pour les ratés est irréaliste. Aucune source trouvée ne chiffre l'accord entre annotateurs sur MyFoodRepo [N].
- Meilleure piste : garder RF-DETR-Seg comme détecteur et ajouter un raffineur de style SAM (invite par boîte, puis par point au toucher). SAM 2.1 Tiny est en Core ML sous Apache-2.0 [V]. Les autres variantes allégées ont des licences à vérifier ou un blocage (EdgeSAM, YOLO).
- Deuxième levier : passer de Nano à Small ou Medium. Troisième : des données d'entraînement sous licence commerciale. FoodSeg103 et UECFoodPix sont probablement « recherche seulement » [N], donc inutilisables pour entraîner.
- Écart probable avec l'objectif : 0,85 à 0,88 sur les appariées avec raffineur [S]. 0,90 sur toutes les zones évaluables, cas difficiles compris, est improbable.

2. ÉTAT DE L'ART (chiffres vérifiés)
- FoodSeg103 (mIoU) : FoodSAM 46,42 %, BEiT v2 Large 49,4 %, Swin-TUNA 50,56 % (2025). Sur UECFoodPix Complete : FoodSAM 66,14 %, Swin-TUNA 74,94 %. Ce sont des mIoU sémantiques par classe, pas de l'IoU d'instance, donc pas comparables à votre mesure. Les protocoles diffèrent d'un papier à l'autre. [V, tiers] [arXiv 2411.01469](https://arxiv.org/pdf/2411.01469), [arXiv 2507.17347](https://arxiv.org/pdf/2507.17347).
- Même sur ces jeux avec classes, personne ne dépasse 0,75 de mIoU. Cela montre que 0,90 est hors de portée de l'état de l'art publié sur de la segmentation sémantique alimentaire.
- MyFoodRepo FRB 2022 : jeu de 39 962 images, 498 classes [V, [AIcrowd](https://aicrowd.com/challenges/food-recognition-benchmark-2022)]. Les AP des gagnants n'ont pas pu être confirmés. Le papier de [Frontiers in Nutrition 2022](https://www.frontiersin.org/journals/nutrition/articles/10.3389/fnut.2022.875143/full) décrit les gagnants du round 4, à lire à la source. L'AP du gagnant 2022 reste [N].
- Votre mAP masque de 0,22 sur une seule classe ne se compare pas aux AP du benchmark officiel à 498 classes.

3. TABLEAU COMPARATIF (condensé)

| Option | Fonctionnement | Performance (source) | iOS / Core ML | Licence | Gain estimé [S] |
|---|---|---|---|---|---|
| RF-DETR-Seg Nano → Small → Medium (actuel) | Détecteur de type DETR avec tête de masque | AP masque COCO 40,3 (312 px), 43,1 (384 px), 45,3 (432 px), 47,1 (504 px) ; latence T4/TensorRT 3,4 / 4,4 / 5,9 / 8,8 ms [V, [GitHub](https://github.com/roboflow/rf-detr), chiffres vendeur] | Nano converti déjà (30 Mo int8). Small et Medium : même famille donc faisables, latence A13 non mesurée | Code Apache-2.0 [V par vous]. Poids : à revérifier par taille [N] | +3 à 5 points de détection avec Small, en se fondant sur +2,8 AP COCO [S] |
| SAM 2.1 Tiny/Small/BasePlus Core ML | Encodeur Hiera + décodeur d'invites (boîte, point) | Conversions fp16 publiées par Hugging Face sous le compte Apple, 1er oct. 2024, démo « SAM2 Studio » [V, [HF](https://huggingface.co/apple/coreml-sam2.1-tiny)]. Latence A13 inconnue [N] | Core ML prêt, mais encodeur fp16 de plusieurs dizaines de Mo, mémoire à surveiller sur 4 Go | Apache-2.0 [V] | Contour : 0,82 → 0,86 à 0,88 sur les appariées [S]. Pas de gain de détection |
| EdgeSAM | SAM distillé, CNN | 38,7 images/s sur iPhone 14, 9,6 M de paramètres, 14× plus rapide que MobileSAM [V, [GitHub](https://github.com/chongzhou96/EdgeSAM), [arXiv 2312.06660](https://arxiv.org/abs/2312.06660)] | Core ML fourni | « NTU S-Lab License 1.0 » [V] : je crois cette licence non commerciale mais ne l'ai pas lue [N]. Bloquant tant que non confirmé | Même gain que SAM 2.1 Tiny, si la licence le permet |
| MobileSAM / EfficientSAM | Encodeur ViT-Tiny distillé | EfficientSAM n'est pas plus rapide que MobileSAM ; MobileSAM 4,9 images/s sur iPhone 14 [V, EdgeSAM] | Faisable, plus lent | Licences non vérifiées [N] | Dominé par SAM 2.1 Tiny et EdgeSAM |
| SAM 3 | Segmentation par concept (texte ou exemple) | Publié le 19 nov. 2025 [V, [Roboflow](https://blog.roboflow.com/what-is-sam3/)] | Modèle grand, pas pour A13 [N] | « SAM License » de Meta : usage commercial gratuit, avec conditions (copie de la licence, interdits militaires, résiliation si procès contre Meta, termes modifiables). Un tiers la qualifie de propriétaire. À lire sur facebook/sam3 [V partiel] | Utile hors ligne comme annotateur pour produire des pseudo-étiquettes, pas dans l'app |
| Vision VNGenerateForegroundInstanceMaskRequest | Masques d'instances de sujets saillants | iOS 17+, exposé par `results` ; pas de plafond d'instances documenté [V, [Apple](https://developer.apple.com/tutorials/data/documentation/vision/vngenerateforegroundinstancemaskrequest.md)] | Natif, 0 Mo, A13 OK | Aucun coût | Qualité sur assiettes inconnue [N]. Sujets saillants : l'assiette et la table risquent d'être fusionnées avec les aliments [S]. Au mieux un comparateur ou un repli |
| YOLO11-seg / YOLOE (Ultralytics) | Détecteur de type YOLO | non vérifié ici | Core ML natif | AGPL-3.0 (ou licence entreprise payante) [N] | Écarté pour un produit vendu sans licence entreprise |
| Mask2Former / OneFormer / SegFormer / BiRefNet | Segmentation par requêtes ou sémantique | non vérifié ici | Lourds en mémoire, opérateurs d'attention difficiles pour Core ML [N] | Mask2Former : MIT/Apache selon version ; SegFormer : licence NVIDIA à lire ; BiRefNet : MIT [tous N] | BiRefNet fait du premier plan sans instances, donc inadapté |
| Grounded-SAM / FoodSAM | Détecteur de texte + SAM, ou SAM + segmentation sémantique | FoodSAM 46,4 % mIoU FoodSeg103 [V tiers] | Chaîne trop lourde pour l'iPhone | Dépend de GroundingDINO et SAM | Hors ligne seulement (annotation) |

Points non évalués : SAM 2 vs SAM 2.1 en détail, SAM-HQ, EfficientViT-SAM, Core ML de SAM 3, nouveautés Vision iOS 18/26. Je n'ai pas trouvé de source fiable pour ces points.

4. MÉTRIQUE RECOMMANDÉE POUR « IoU ≥ 0,90 »
Il faut en publier plusieurs, déclarées d'avance. Une seule moyenne peut être gonflée.
- A. IoU d'instance appariée : moyenne sur les paires (prédiction, vérité) en appariement un-pour-un au seuil IoU ≥ 0,5 (hongrois). C'est votre 0,82 actuel. Elle ignore les ratés, donc elle ne doit jamais être présentée seule.
- B. Rappel de détection aux seuils 0,5 et 0,75, avec précision et fausses zones par image (c'est votre 73,9 %).
- C. IoU « sans triche » : moyenne sur TOUTES les vérités évaluables, avec 0 pour chaque aliment raté. C'est la vraie mesure du « sans exclure les cas difficiles ». Elle vaut à peu près rappel × IoU appariée, soit environ 0,74 × 0,82 ≈ 0,61 aujourd'hui [S, calcul].
- D. Qualité panoptique : PQ = SQ × RQ, où SQ est l'IoU des appariées et RQ le F1 de détection. C'est la façon standard de ne pas mélanger C et A.
- E. Boundary IoU ou F de bord (bande de quelques pixels) : un masque peut avoir 0,9 d'IoU avec un bord médiocre.
- Découper chaque métrique par catégorie, par taille (petit < 32², moyen, grand) et par difficulté (nombre d'aliments, contact entre aliments, transparent). Ajouter des intervalles de confiance par rééchantillonnage.
- Échantillon indépendant : MyFoodRepo (suisse) ne représente pas les plats québécois. Fixer l'échantillon de 10 000 plats avant toute optimisation ; ne rien ajuster dessus. Garder un second jeu de photos libres de droits pour mesurer le décalage de domaine.
- Exclusions « non évaluables » : les définir par règle écrite (par exemple vérité de moins de N pixels ou ambiguë) et publier le nombre exclu, pas par choix a posteriori.

Plafond réaliste :
- L'accord entre deux annotateurs sur MyFoodRepo n'est pas publié à ma connaissance [N]. Pour des polygones de la COCO, l'accord IoU d'instance se situe souvent autour de 0,85 à 0,90 selon les objets [N, mémoire, à vérifier]. Les bords flous (sauces, riz, salade, liquides) sont pires.
- Conséquence : si les polygones de vérité ont eux-mêmes un bruit de cet ordre, une IoU moyenne de 0,90 contre ce bruit est quasi un plafond. La mesure A à 0,90 demande donc une vérité plus propre, par exemple un sous-ensemble de quelques centaines de photos annotées au masque pixel par SAM puis corrigé par un humain.
- Le seul moyen honnête de fixer le plafond est de faire annoter 200 à 300 photos par deux personnes et de mesurer leur IoU. Cela coûte une demi-journée et donne la limite de l'objectif.

5. RAFFINEMENT INTERACTIF (toucher pour ajouter ou corriger)
- Faisable avec le décodeur de SAM 2.1 : invite par point ou boîte, sur l'encodeur calculé une fois par photo. Core ML existe [V]. Coût sur A13 inconnu [N] : à mesurer avant tout engagement.
- Évaluation honnête, séparée de la mesure automatique : simuler des clics à partir de la vérité (premier clic au centre de la zone d'erreur la plus grande) et rapporter le nombre de clics pour atteindre 0,90 (NoC@90) et l'IoU après 1, 3 et 5 clics. Ne jamais ajouter ces chiffres à A, B ou C : ils mesurent l'interface, pas le modèle.

6. DONNÉES D'ENTRAÎNEMENT
- Utilisable : MyFoodRepo FRB (CC BY 4.0, [V par vous]). FoodSeg103 et UECFoodPix Complete : licences à lire, probablement académiques [N]. Ne pas les utiliser sans lecture de la licence.
- Auto-annotation : un SAM (2.1 en Apache-2.0, ou SAM 3 sous licence Meta) peut proposer des masques sur vos photos libres de droits (CC0, domaine public, CC BY), avec vérification humaine d'un échantillon pour chiffrer le taux d'erreur avant d'entraîner dessus. À faire hors ligne, photos hors du dépôt, comme pour le classifieur. Vérifier que la licence du modèle teacher n'interdit pas d'entraîner un modèle commercial avec ses sorties [N pour SAM 3].
- Copier-coller synthétique : coller des petits aliments (tomate, beurre, oignon) sur d'autres assiettes pour augmenter leur nombre. Gain plausible sur le rappel des petits objets, mais risque de domaine artificiel [S]. À tester avec A/B sur le jeu d'évaluation fixe.
- Résolution : 312 px est faible pour les petits aliments. Le passage Small à 384 px et un Medium à 432 px sont les tests directs. Une autre piste est un second passage en recadrant les zones de faible confiance [S].

7. TOP 5 RECOMMANDATIONS (par impact)
1. Entraîner Small (384 px) comme prévu, puis évaluer Medium (432 px) selon la latence A13 réelle. Cible : détection 74 → 78 % ou plus. Plus gros levier sur C [S].
2. Prototyper un raffineur SAM 2.1 Tiny (invite par boîte issue de RF-DETR), mesuré par A et E sur les 1 000 photos. Mesurer d'abord taille, mémoire et latence sur l'iPhone 11 Pro. Cible : 0,82 → 0,86+ [S]. À abandonner si latence > 300 ms ou mémoire excessive [S].
3. Figer le protocole de mesure (section 4) et faire annoter 200 photos par deux personnes pour connaître le plafond d'accord. Sans ce chiffre, « 0,90 » ne veut rien dire.
4. Ajouter le toucher pour corriger, branché sur le même décodeur, avec NoC@90 mesuré à part.
5. Enrichir les données avec des photos libres de droits annotées par SAM puis vérifiées, centrées sur les plats québécois et les petits aliments.

8. IRRÉALISTE OU BLOQUANT
- YOLO11/YOLOE : AGPL-3.0 [N], bloquant sans licence entreprise.
- EdgeSAM : licence NTU S-Lab probablement non commerciale [N], à lire avant tout test sérieux.
- SAM 3 sur l'appareil : trop grand [N]. Licence Meta non Apache, avec clauses de résiliation et de modification unilatérale.
- Vision de base : les aliments ne sont pas des « sujets saillants » ; ne pas en dépendre.
- 0,90 d'IoU, ratés comptés à zéro (mesure C) : inatteignable. Même une détection parfaite à 95 % × 0,90 donne 0,86.
- Écart probable : mesure A autour de 0,85 à 0,88 avec raffineur, 0,90 possible seulement sur sous-ensembles faciles (un seul aliment, bien séparé) [S]. Mesure C autour de 0,65 à 0,75 [S].

9. SOURCES
- [SAM 3 / licence, Roboflow](https://roboflow.com/model-licenses/segment-anything-3) ; [blog SAM 3](https://blog.roboflow.com/what-is-sam3/)
- [Apple SAM 2.1 Tiny Core ML (Hugging Face)](https://huggingface.co/apple/coreml-sam2.1-tiny) ; [BasePlus](https://huggingface.co/apple/coreml-sam2.1-baseplus/commits/main)
- [RF-DETR (GitHub)](https://github.com/roboflow/rf-detr)
- [FoodSAM, arXiv 2308.05938](https://arxiv.org/pdf/2308.05938) ; [PCA, arXiv 2411.01469](https://arxiv.org/pdf/2411.01469) ; [Swin-TUNA, arXiv 2507.17347](https://arxiv.org/pdf/2507.17347) ; [classement FoodSeg103](https://hyper.ai/en/sota/tasks/semantic-segmentation/benchmark/semantic-segmentation-on-foodseg103)
- [AIcrowd FRB 2022](https://aicrowd.com/challenges/food-recognition-benchmark-2022) ; [Frontiers in Nutrition 2022](https://www.frontiersin.org/journals/nutrition/articles/10.3389/fnut.2022.875143/full)
- [EdgeSAM GitHub](https://github.com/chongzhou96/EdgeSAM) ; [arXiv 2312.06660](https://arxiv.org/abs/2312.06660)
- [Apple Vision, VNGenerateForegroundInstanceMaskRequest](https://developer.apple.com/tutorials/data/documentation/vision/vngenerateforegroundinstancemaskrequest.md)

Incertitudes : les latences sur A13 n'ont été trouvées pour aucun modèle (EdgeSAM : iPhone 14 seulement). Les AP des gagnants FRB 2022, l'accord entre annotateurs, les licences de MobileSAM, EfficientSAM, SegFormer, Mask2Former, FoodSeg103, UECFoodPix et d'EdgeSAM (texte exact) ne sont pas vérifiés. Les nouveautés Vision d'iOS 18 et 26 et SAM 3.1 ne sont pas explorées. Les chiffres de gain marqués [S] sont des estimations.

Prochaine action : (1) lancer le passage Small sur Kaggle comme prévu ; (2) faire lire par l'utilisateur ou un agent la licence de SAM 3 sur facebook/sam3 et celle d'EdgeSAM (NTU S-Lab) ; (3) mesurer sur l'iPhone 11 Pro la latence et la mémoire d'un encodeur SAM 2.1 Tiny en fp16 avant de décider du raffineur ; (4) faire annoter 200 photos par deux personnes pour chiffrer le plafond.

### Passe 2

Vérifications de la deuxième passe (segmentation). 15 pages ouvertes, rien téléchargé ni installé. [V] = lu à la source primaire ; [N] = introuvable ou non confirmé.

1. EdgeSAM : usage commercial non permis (CORRECTION : je l'avais noté « à vérifier »)
- Page : https://raw.githubusercontent.com/chongzhou96/EdgeSAM/master/LICENSE. Nom exact : « S-Lab License 1.0 » (Copyright 2022 S-Lab). [V]
- Clause clé : « Redistribution and use for non-commercial purpose in source and binary forms ». Pour tout usage commercial : « please contact the contributor(s) of the work ». [V]
- Conclusion : EdgeSAM est bloqué pour Ardane sans accord écrit des auteurs.

2. MobileSAM, EfficientSAM, EfficientViT-SAM, SAM-HQ
- MobileSAM (https://github.com/ChaoningZhang/MobileSAM) : code « Apache-2.0 » [V, bandeau GitHub]. Poids : aucune licence séparée ; le README n'en mentionne aucune ; ils sont dans `weights/` [V]. Le README annonce 8 ms d'encodeur et 4 ms de décodeur, mais sur GPU et sans mention d'iPhone [V]. Poids : licence [N].
- EfficientSAM (https://github.com/yformer/EfficientSAM) : code « Apache-2.0 » avec fichier LICENSE [V]. Poids EfficientSAM-S et EfficientSAM-Ti dans `weights/`, sans licence séparée [V]. Poids : licence [N].
- EfficientViT-SAM (https://github.com/mit-han-lab/efficientvit, README de l'application) : dépôt « Apache-2.0 » [V]. Fiche des poids https://huggingface.co/mit-han-lab/efficientvit-sam : métadonnée « apache-2.0 » [V]. Vitesse publiée : Jetson Orin 8,2 à 37,2 ms (TensorRT fp16), aucune mesure iPhone [V]. Le README de l'application ne donne aucune licence [V, absence].
- SAM-HQ (https://github.com/SysCV/sam-hq) : code « Apache-2.0 » [V]. Poids (Google Drive et Hugging Face) : aucune licence indiquée sur la page [V, absence]. Ils sont dérivés de SAM, donc licence des poids [N].
- Aucun de ces modèles n'a de mesure A13 publiée que j'aie trouvée [N].

3. RF-DETR-Seg : toutes les tailles en Apache 2.0 (CORRECTION : j'avais écrit « à revérifier par taille »)
- Page : https://github.com/roboflow/rf-detr (README, section License). [V]
- Segmentation : Nano, Small, Medium, Large, XLarge et 2XLarge sont toutes en Apache 2.0 [V].
- PML 1.0 (« Roboflow Platform Model License ») ne s'applique qu'à la détection Atto, Femto, Pico, XL et 2XL (`rfdetr[plus]`) et aux modèles NAS [V]. Clause : « Commercial use is included when you deploy on Roboflow; commercial self-hosting requires the Enterprise add-on » [V].
- Donc passer à Small ou Medium en segmentation ne change pas la licence. Ne pas choisir un modèle de détection XL/2XL ni NAS.

4. SAM 3 (facebook/sam3)
- Page : https://huggingface.co/facebook/sam3/blob/main/LICENSE, « SAM License » [V]. Résumé tiré de la page, pas un avis juridique.
- Octroi (§1a) : licence « non-exclusive, worldwide, non-transferable and royalty-free limited license » pour utiliser, copier, distribuer et modifier [V].
- Sorties : mentionnées seulement dans la clause d'exclusion de garantie (« THE SAM MATERIALS AND ANY OUTPUT AND RESULTS THEREFROM ARE PROVIDED ON AN "AS IS" BASIS ») [V]. L'entraînement d'un autre modèle avec les sorties n'est ni autorisé ni interdit par le texte [V, silence]. Je ne peux donc pas affirmer qu'il est permis.
- Résiliation : §6, Meta peut résilier en cas de manquement ; il faut alors « delete and cease use of the SAM Materials ». §5b : si vous poursuivez Meta pour atteinte à vos droits sur ces matériaux, « any licenses granted to you under this Agreement shall terminate » ; indemnisation de Meta pour les réclamations de tiers [V].
- Usages interdits (§1b.iv-v) : ITAR, militaire, nucléaire, espionnage, armes [V]. Les dérivés vous appartiennent (§5a) [V].
- Risque pratique : si Meta résilie, il faudrait cesser d'utiliser SAM 3, et l'effet sur un modèle déjà entraîné avec ses sorties n'est pas tranché par le texte. Avis juridique conseillé avant de s'en servir pour pseudo-étiqueter.

5. FoodSeg103 et UECFoodPix Complete
- UECFoodPix / UECFoodPix Complete : https://mm.cs.uec.ac.jp/uecfoodpix/, section Agreement : le jeu de données « can be used only for non-commercial research purpose » [V]. Inutilisable pour entraîner (CORRECTION : j'avais écrit « probablement »).
- FoodSeg103 : https://github.com/LARC-CMU-SMU/FoodSeg103-Benchmark-v1 : « This project is released under the Apache 2.0 license » ne couvre que le code ; aucune licence pour les images et annotations ; l'archive est protégée par un mot de passe [V]. Licence des données : introuvable [N]. À traiter comme non utilisable en commercial tant qu'une licence écrite n'est pas obtenue.

6. Gagnants du Food Recognition Benchmark
- Page des résultats https://www.aicrowd.com/challenges/food-recognition-benchmark-2022/leaderboards : top 5 avec colonnes « AP » et « AR » (sigles non définis sur la page) : Lab_3i 0,423 / 0,636 ; gaurav_singhal 0,414 / 0,587 ; gear_fifth 0,390 / 0,611 ; Camaro 0,390 / 0,600 ; nebula 0,381 / 0,613 [V]. Je n'ai pas confirmé que c'est l'AP masque COCO (IoU 0,5:0,95), ni quel jeu de test. [N] sur ces deux points.
- Article https://www.frontiersin.org/journals/nutrition/articles/10.3389/fnut.2022.875143/full : mAP à IoU > 0,5, donc effectivement AP50, pour les rounds 1 à 4 (2019 à 2021) : 0,573 / 0,633 / 0,551 / 0,568, mAR 0,831 / 0,886 / 0,884 / 0,767 [V]. Ce ne sont pas des AP 0,5:0,95 ni des chiffres 2022. Le meilleur modèle unique reproductible de l'article (HTC ResNet101, round 4) : mAP 0,539, mAR 0,867 [V].
- Conclusion : l'AP gagnant (~0,42) du classement 2022 n'est pas comparable à votre mAP masque de 0,22 sans connaître la métrique et le nombre de classes (498 contre une seule chez vous).

7. apple/coreml-sam2.1-tiny et -small
- https://huggingface.co/apple/coreml-sam2.1-tiny : licence « apache-2.0 », précision float16 [V]. Dossier total 79,7 MB (fichiers : SAM2_1TinyImageEncoderFLOAT16, PromptEncoder, MaskDecoder en .mlpackage) ; la taille de chaque paquet n'est pas affichée [V, absence]. Aucune latence ni appareil sur la fiche [V].
- https://huggingface.co/apple/coreml-sam2.1-small : dossier total 93,9 MB, float16 [V]. Pas de tailles par fichier [N]. Licence présumée identique, non relue sur cette page.
- Latence publiée sur iPhone : introuvable [N] (la page de l'exemple Hugging Face coreml-examples renvoie 404).
- Correction mémoire : le total tient en ~80 à ~94 Mo sur disque, non pas « plusieurs dizaines de Mo » pour le seul encodeur ; la mémoire vive à l'exécution reste non mesurée.

8. Accord entre annotateurs (masques d'instances)
- Source secondaire : EPIC-KITCHENS VISOR (https://arxiv.org/pdf/2209.13064), dont j'ai lu les extraits via une recherche ; la page complète dépasse la limite de lecture, donc non relue en entier [N sur le contexte exact]. Elle cite environ 90 d'IoU par instance pour OpenImages et environ 80 pour les polygones COCO, d'après l'article OpenImages ; et 90,3 de mIoU moyen par paires pour ses propres annotateurs.
- LVIS (https://arxiv.org/pdf/1908.03195) : 0,85 d'IoU de masque contre des annotations d'experts sur 100 instances ; ce n'est pas un accord entre annotateurs [V par extrait].
- L'article COCO (https://arxiv.org/abs/1405.0312) ne donne pas ce chiffre dans le résumé [V].
- Aucune source sur des aliments / MyFoodRepo [N].
- Conséquence : mon « 0,85 à 0,90 pour COCO » était trop optimiste ; la valeur citée est ~0,80 pour COCO et ~0,90 pour des annotations soignées (OpenImages, VISOR). Un objectif de 0,90 contre les polygones de MyFoodRepo est donc très probablement au-dessus du plafond de la vérité, sauf si ces polygones sont de qualité OpenImages [N]. Cela renforce la recommandation d'annoter un sous-ensemble en double pour mesurer le plafond.

Corrections au rapport initial
- EdgeSAM : non commercial, bloquant (confirmé).
- RF-DETR-Seg : toutes tailles Apache 2.0 ; PML seulement pour certains modèles de détection.
- UECFoodPix : non commercial confirmé. FoodSeg103 : licence des données introuvable.
- SAM 3 : les sorties ne sont pas traitées par la licence ; résiliation possible ; avis juridique nécessaire avant pseudo-étiquetage.
- Le classement AIcrowd 2022 (AP 0,423 en tête) existe, mais sa métrique n'est pas confirmée.
- Plafond d'accord : ~0,80 (COCO) à ~0,90 (annotations soignées), pas 0,85 à 0,90.
- Latences A13 / iPhone pour SAM 2.1 et les autres : toujours introuvables.

## Quantités, volume, densité

### Passe 1

Question : comment estimer les grammes PAR ALIMENT (volume, densité, incertitude) pour le scanner Ardane, et « 80 % à ± 20 % par aliment » est-il atteignable ?

Limite de ce rapport : j'ai fait 8 recherches web seulement, sans ouvrir les pages primaires. Je n'ai pas lu le code ni la mémoire du dépôt. Tout chiffre non relié à une source ci-dessous est marqué « non vérifié » ou « connaissance générale ». Rien n'a été téléchargé ni modifié.

## 1. Résumé
- Sur une photo sans échelle, l'état de l'art tient à environ 15-25 % d'erreur moyenne sur la masse du PLAT ENTIER. Par aliment, c'est moins bon : les aliments s'additionnent et les erreurs ne se compensent plus. Je n'ai trouvé aucune étude « 80 % des aliments à ± 20 % » (non vérifié).
- Sans LiDAR, la profondeur de la double caméra d'AVFoundation est « relative », pas métrique (documenté Apple). Seule la caméra avant TrueDepth donne une profondeur absolue, mais elle sert mal pour un repas.
- Le gain le plus sûr vient donc de l'échelle (assiette connue, référence) et des habitudes apprises de la personne. La profondeur monoculaire métrique est un pari : licences à restrictions, précision à 30-60 cm non établie par mes sources.
- Verdict honnête : 80 % à ± 20 % par aliment est atteignable seulement dans des conditions favorables (LiDAR ou échelle connue, aliments distincts, personnalisation). Sur photo libre, le réaliste est 45-60 % (estimation, non vérifiée). Il faut afficher des fourchettes.

## 2. Tableau comparatif des approches

| Approche | Fonctionnement | Performance démontrée | iPhone 11 Pro / LiDAR | Hors ligne, licence, coût, effort | Gain estimé* |
|---|---|---|---|---|---|
| A. Surface du masque × densité apprise (déjà fait) | Aire en pixels × épaisseur moyenne apprise | Banc Ardane : 65,8 % à ± 25 % sur le plat entier (donnée interne) | Les deux. Besoin d'une échelle | Hors ligne, aucun coût | Base |
| B. Échelle par objet de référence (assiette de diamètre connu, carte, main) | Pixels/cm déduits de l'objet | Pas de chiffre trouvé (non vérifié). Raisonnement : l'aire varie comme le carré de l'échelle, donc 5 % d'erreur de diamètre donne environ 10 % sur l'aire (calcul, pas une étude) | Les deux | Hors ligne, effort faible, mais assiette souvent inconnue ou vue en perspective | Moyen à fort si l'assiette est connue |
| C. Profondeur monoculaire métrique (Depth Anything V2 métrique, Depth Pro, Metric3D, UniDepth, ZoeDepth) | Réseau qui prédit la profondeur absolue, puis volume du masque | Aucun chiffre vérifié à 30-60 cm en intérieur. Sur Nutrition5k, la voie profondeur d'Ardane donne 50,9 % : le plan de l'assiette est mal estimé | Les deux. Poids Core ML lourds | Hors ligne. Licences : Depth Anything V2 Small = Apache-2.0, Base/Large/Giant = CC-BY-NC-4.0 (non commercial). Statut des variantes métriques : non vérifié, à lire dans le dépôt. Depth Pro : licence Apple « ASCL » (indiquée par des ports tiers, texte non lu, probablement non commercial, à vérifier) | Incertain. Prototype à tester sur le banc |
| D. AVDepthData double caméra (iPhone 11 Pro) | Disparité stéréo, en 1/m | Documenté : précision « relative ». La précision dépend de la calibration, et une erreur de focale introduit une erreur d'échelle en z. Résolution : environ 0,5 Mpx sur iPhone 7 Plus (2017) ; non vérifié pour l'iPhone 11 Pro | iPhone 11 Pro uniquement | Hors ligne, API gratuite. Peu fiable pour des grammes | Faible |
| E. TrueDepth (caméra avant) | Lumière structurée, profondeur absolue | Documenté : mesure directe en mètres, précision « absolute » | Non adapté : on cadre un repas avec la caméra arrière | Hors ligne | Très faible |
| F. LiDAR (sceneDepth, ARKit) | Profondeur métrique mesurée | Précision à 30-50 cm : non vérifiée par mes recherches | iPhone Pro récents seulement (pas l'iPhone de test) | Hors ligne, gratuit, effort moyen, non testable sur l'iPhone 11 Pro | Fort, mais inutilisable sur l'appareil de référence |
| G. ARKit sans LiDAR (plan + odométrie visuo-inertielle) | Détection du plan de table, échelle par mouvement | Précision en cm : non vérifiée | Les deux | Hors ligne. Demande un mouvement de l'utilisateur | Moyen, très incertain |
| H. Multi-vues, vidéo, 3D (gaussiennes, VolETA et autres) | Reconstruction du volume par plusieurs images | Défi MetaFood CVPR 2024 : métrique MAPE sur le volume, 16 équipes en phase finale. Les MAPE des gagnants ne sont pas vérifiés. Sources contradictoires sur le vainqueur : VolETA (site du défi) ou FoodRiddle (rapport arXiv) | Les deux, mais lourd et gourmand pour un A13 | Hors ligne difficile. Effort élevé | Fort en labo, faible en usage quotidien |
| I. Grands modèles multimodaux (GPT-4V/4o, Gemini) | Estimation par le langage | GPT-4V : erreur de portion de 54,6 g contre 43,6 g pour les diététiciens (jeu réel, avec objets de référence). Humains sur Nutrition5k : 53 % d'erreur moyenne (non-nutritionnistes), 41 % (nutritionnistes). Étude ODU : l'erreur sur les glucides de Gemini 2.5 Flash passe de 56,6 % à 39,5 % avec une estimation de poids par RGB-D | En ligne | Payant, envoi de photos (vie privée), non hors ligne | Faible à moyen, utile surtout en repli |
| J. Habitudes et étalonnage personnel | Portions apprises des corrections et des repas pesés | Non vérifié dans la littérature trouvée | Les deux | Hors ligne, effort faible | Fort sur les aliments répétés |

*Gain estimé : mon jugement, pas une mesure.

Références publiées : Nutrition5k, 18,8 % d'erreur moyenne sur la masse (image seule) et 13,7 % sur le volume avec profondeur (chiffres fournis dans la mission, non revérifiés par moi).

## 3. Faisabilité de « 80 % des aliments à ± 20 % »
Constat appuyé par les sources : les humains font 41-53 % d'erreur sur Nutrition5k, et même un modèle fort vise 15-20 % d'erreur moyenne sur le plat entier. Une erreur moyenne de 18 % laisse environ 30 à 40 % des estimations au-delà de ± 20 %. Je tire cet ordre de grandeur de la distribution d'erreurs du banc Ardane (65,8 % à ± 25 % pour une erreur moyenne de 22 %), pas d'une étude.

Conditions pour s'en approcher :
1. Échelle connue : assiette de diamètre connu bien détectée, ou LiDAR.
2. Aliments distincts, pas empilés ni en sauce.
3. Aliments déjà vus : portions personnelles apprises.
4. Aliments emballés avec poids connu : alors l'erreur tombe presque à zéro.
5. Pesée d'étalonnage de l'utilisateur.

Ordre de grandeur réaliste, mon estimation non vérifiée :
- Photo libre sans échelle : 35-50 % à ± 20 % par aliment.
- Avec assiette connue : 50-60 %.
- Avec LiDAR plus assiette : 60-70 %.
- Avec habitudes sur aliments répétés : peut dépasser 80 % sur ce sous-ensemble.

Le chiffre global de 80 % n'est donc réaliste que sur un sous-ensemble défini (par exemple les repas courants de l'utilisateur) ou avec fourchettes. Pour un échantillon indépendant de 10 000 plats en vrac, c'est très improbable (écart probable : 20-30 points).

## 4. Top 5 des recommandations (par impact)
1. Personnalisation par les corrections et les repas pesés (portion habituelle apprise, par aliment). Offline, coût faible, gain le plus sûr.
2. Afficher une fourchette honnête (par exemple 120-180 g) plutôt qu'un chiffre unique. Méthode : régression par quantiles ou prédiction conforme (calibrer l'intervalle sur le banc Nutrition5k puis sur les corrections réelles). Cette partie n'a pas été vérifiée dans mes recherches (connaissance générale) ; je n'ai pas de source à citer.
3. Renforcer l'échelle : assiette de diamètre connu ou carte, avec correction de perspective, et demander une photo à plat quand c'est possible.
4. Utiliser le LiDAR quand il existe (iPhone Pro récents) avec une mesure du plan de la table. Impossible à tester sur l'iPhone 11 Pro : à n'activer qu'après tests sur un appareil équipé.
5. Prototyper un modèle de profondeur monoculaire seulement avec des poids commerciaux sûrs (Depth Anything V2 Small, Apache-2.0, avec version Core ML d'Apple), en mesurant d'abord l'erreur de plan sur le banc. Mettre de côté Depth Pro, Base et Large tant que la licence n'est pas lue.

## 5. Obstacles et irréalismes
- La profondeur double caméra est relative (documenté) : ne pas en faire des grammes.
- Une profondeur monoculaire « métrique » sans échelle connue reste incertaine à ces distances (hypothèse, non vérifiée).
- Licences : Base/Large de Depth Anything V2 = CC-BY-NC-4.0 (interdit en commercial) ; Depth Pro (ASCL) à lire ; MetaFood3D : licence du jeu non trouvée ; NutritionVerse-Real (889 images, 251 plats, 45 types d'aliments, poids de chaque ingrédient mesuré) : licence à lire sur la page Kaggle ; FAO/INFOODS Density Database v2 (638 aliments, 20 groupes, 11 sources) : licence non trouvée ; ECUSTFD : rien trouvé.
- Les grandes bases de portions (USDA FNDDS, Fichier canadien) n'ont pas pu être vérifiées ici.
- Les LMM en ligne coûtent, envoient la photo hors de l'appareil et ne sont pas hors ligne.
- 80 % à ± 20 % sur 10 000 plats libres : irréaliste aujourd'hui, selon les sources lues.

## 6. Sources
- MetaFood CVPR 2024 : https://arxiv.org/pdf/2407.09285 et https://sites.google.com/view/cvpr-metafood-2024/challenge
- MetaFood3D : https://arxiv.org/abs/2409.01966 (données : https://lorenz.ecn.purdue.edu/~food3d/, licence non lue)
- Nutrition5k : https://arxiv.org/pdf/2103.03375
- GPT-4V et diététiciens : https://arxiv.org/abs/2312.08592
- Étude ODU sur les LMM : https://digitalcommons.odu.edu/computerscience_fac_pubs/417
- Depth Anything V2 : https://github.com/DepthAnything/Depth-Anything-V2 ; Core ML Apple : https://huggingface.co/apple/coreml-depth-anything-v2-small
- Depth Pro (ports Core ML tiers, tag ASCL) : https://huggingface.co/mickeyvanolst/depthpro-coreml
- AVDepthData : https://developer.apple.com/documentation/avfoundation/capturing-photos-with-depth et https://developer.apple.com/documentation/avfoundation/avdepthdata/accuracy
- FAO/INFOODS densité v2 : https://openknowledge.fao.org/handle/20.500.14283/ap815e
- NutritionVerse-Real : https://arxiv.org/html/2401.08598v1

Incertitudes : MAPE des gagnants MetaFood ; précision de profondeur à 30-60 cm (iPhone, LiDAR, monoculaire) ; versions d'iOS ; licences listées plus haut ; chiffres « Gain estimé » = jugement.

Prochaine action : lire les licences primaires (ml-depth-pro, metric_depth de Depth Anything, FAO densité, page Kaggle NutritionVerse-Real, page MetaFood3D) et relancer une recherche ciblée sur la profondeur LiDAR/monoculaire à courte distance avant toute implémentation.

### Passe 2

DEUXIÈME PASSE : vérifications et corrections (pages primaires ouvertes : une vingtaine, certaines en échec 403 ou illisibles, signalées).

## 1. Depth Anything V2
- README principal (https://raw.githubusercontent.com/DepthAnything/Depth-Anything-V2/main/README.md) : « Depth-Anything-V2-Small model is under the Apache-2.0 license » ; « Base/Large/Giant ... CC-BY-NC-4.0 ». Le README dit que les modèles métriques (Small et Base, 2024-06-22) existent mais ne donne PAS leur licence.
- metric_depth/README.md : six modèles métriques (Small/Base/Large, intérieur = Hypersim, extérieur = Virtual KITTI 2). Aucune licence énoncée dans ce fichier. Le LICENSE racine est Apache-2.0 (entête « Apache License, Version 2.0 », 2004), mais l'attribution par taille du README prévaut sans doute. Licence des poids métriques : INTROUVABLE explicitement. Prudence : seul « Small » est certain Apache-2.0 ; les poids métriques Base/Large sont à supposer CC-BY-NC tant que non précisé (supposé, non vérifié). Le Small métrique n'est pas explicitement couvert non plus. De plus, Hypersim et VKITTI2 ont leurs propres licences (non lues).
- https://huggingface.co/apple/coreml-depth-anything-v2-small : licence apache-2.0 ; fichiers F32 99,2 Mo, F16 49,8 Mo ; la fiche ne précise pas relative ou métrique (c'est la version relative de Depth-Anything-V2-Small, supposé). Évaluation en 518x396.

## 2. Apple Depth Pro
- LICENSE du dépôt GitHub (https://raw.githubusercontent.com/apple/ml-depth-pro/main/LICENSE) : licence de type « Apple Sample Code » (« personal, non-exclusive license under Apple's copyrights in this original Apple software ... to use, reproduce, modify and redistribute the Apple Software ») ; ne mentionne ni usage commercial ni recherche seule. README : « sample code ... et model weights are released under the LICENSE terms ».
- MAIS la fiche Hugging Face https://huggingface.co/apple/DepthPro porte « License: apple-amlr », et son fichier LICENSE (https://huggingface.co/apple/DepthPro/raw/main/LICENSE) dit : « Apple Machine Learning Research Model License Agreement » ; usage « exclusively for Research Purposes » ; « Research Purposes does not include any commercial exploitation, product development or use in any commercial product or service ». Conclusion : poids HF = non commercial (documenté). Correction de mon premier rapport : « ASCL » probablement non commercial était juste pour les poids HF ; le LICENSE GitHub, lui, est ambigu. Ne pas utiliser Depth Pro en commercial.

## 3. MetaFood CVPR 2024 (arXiv 2407.09285)
Le rapport (version HTML v1) ne donne le MAPE que pour VolETA : 10,973 %, classé 1er (phase I, volume). MAPE de ININ-VIAUN et FoodRiddle : introuvable dans le contenu récupéré (le PDF est trop gros pour WebFetch). Chamfer (phase II, forme) : FoodRiddle meilleur (multivue 0,0364 ; monovue 0,0192), puis ININ-VIAUN (0,0416 ; 0,0279), puis VolETA (0,0719 ; 0,0587). Correction : le classement général a VolETA 1er (volume), FoodRiddle meilleur en forme. Le MAPE porte sur le VOLUME d'objets 3D, pas sur la masse d'aliments en photo libre.

## 4. NutritionVerse-Real
https://arxiv.org/html/2401.08598v1 : 889 images, 251 plats, 45 types d'aliments ; poids de chaque ingrédient mesuré à la balance ; l'article ne publie que le poids moyen d'un plat (406 g). Disponible sur Kaggle, « open initiative ». Licence exacte : INTROUVABLE (la page Kaggle ne s'est pas rendue, seul son titre). Ne pas l'utiliser en entraînement commercial avant d'avoir lu la licence Kaggle.

## 5. FAO/INFOODS Density Database v2
Page https://www.fao.org/infoods/infoods/tables-and-databases/faoinfoods-databases/en/ : aucune licence ni condition d'usage énoncée pour cette base (PDF ap815e et Excel density_DB_v2_0_final). La fiche openknowledge.fao.org a répondu 403. « CC BY-NC-SA 3.0 IGO » : NON VÉRIFIÉ (licence habituelle des publications FAO, mais je n'ai pas pu la lire pour ce document). Pour du commercial, demander l'autorisation à la FAO.

## 6. Études par aliment et meilleurs résultats Nutrition5k
- Introuvable : aucune étude lue qui donne la part des masses PAR ALIMENT à ± 20 % ou ± 25 %. Mes recherches n'en ont pas trouvé.
- Nutrition5k original (https://arxiv.org/pdf/2103.03375) : PDF illisible en WebFetch. Via la recherche : la masse passe de 29,5 % (image seule) à 13,7 % avec un volume estimé ; les calories de 26,1 % à 18,8 % avec la profondeur (non revérifié en primaire). Correction à noter : dans ma première réponse, 18,8 % était présenté comme erreur sur la masse ; il s'agit des calories. Le chiffre masse est 29,5 % (image seule) et 13,7 % (avec volume).
- Après 2021 : arXiv 2508.03996 (ViT préentraînés, août 2025) et Bianco et al., Nutrients 2025 (correction de la vérité terrain masse/ingrédients, gain de 6 à 42 % selon les algorithmes) : chiffres de masse non lus. Un agrégateur indique 41,56 g de MAE sur la masse absolue (modèle et date inconnus, ne pas citer).

## 7. LiDAR et ARKit sans LiDAR
- LiDAR à 30-60 cm : introuvable. Évaluation 2025 de l'iPhone 13 Pro Max : fiabilité de 1 à 2 cm (surtout sur les arêtes). Études sub-millimétriques sur iPad Pro 2020 à courte portée (non iPhone). Apple : la fiabilité dépend de la confiance (carte de confiance ARKit). Mesure maison recommandée.
- TrueDepth : https://ar5iv.labs.arxiv.org/html/2201.10865 : sur iPhone 11 Pro à environ 200 mm, la profondeur concorde à la planche Charuco à moins d'un millimètre (intrinsèques d'usine). Utile uniquement en selfie, pas pour un repas.
- ARKit sans LiDAR : aucune étude propre. Une étude de dérive (iPhone 11, ARKit 4) : 25,1 cm de dérive moyenne après un aller-retour (https://par.nsf.gov/servlets/purl/10358173). Un blog (Nomtek) : mesures de pièces à moins de 10 cm. Pas de chiffre fiable à 30-60 cm : introuvable.

## 8. AVDepthData sur iPhone 11 Pro
Documentation Apple (https://developer.apple.com/documentation/avfoundation/capturing-photos-with-depth.md) : « Each point in a depth map captured by a dual camera device measures disparity units of 1/meters, and offers AVDepthData.Accuracy.relative accuracy. An individual point isn't a good estimate of real-world distance ». Et .relative (https://developer.apple.com/documentation/avfoundation/avdepthdata/accuracy/relative.md, iOS 11+) : « usable relative to one another ... but do not accurately convey real-world distance ». TrueDepth : « directly measure depth (in meters) with absolute accuracy ». Confirmé. L'article cite builtInDualCamera et TrueDepth ; il ne mentionne pas builtInDualWideCamera ni builtInTripleCamera. Si l'iPhone 11 Pro (triple) livre la profondeur par ces types : non documenté dans cette page (supposé oui ; à tester sur l'appareil).

## Corrections au premier rapport
1. 18,8 % = calories, pas masse.
2. Depth Pro : poids HF sous licence de recherche seule (apple-amlr), clause citée ci-dessus.
3. MAPE gagnants MetaFood : seulement VolETA 10,973 % (volume objets) ; les deux autres introuvables.
4. FAO : licence introuvable (« CC BY-NC-SA 3.0 IGO » non vérifié).
5. Licence des poids métriques de Depth Anything V2 : introuvable ; seul Small relatif est certain Apache-2.0.
6. Le portrait de faisabilité reste valide (aucune source nouvelle ne le contredit), mais le « 35-60 % à ± 20 % par aliment » reste mon estimation, non vérifiée.

Pages non ouvertes ou en échec : Kaggle NutritionVerse-Real (titre seul), openknowledge.fao.org (403), PDF MetaFood et Nutrition5k (trop gros ou binaires), pages Apple LiDAR (aucune page primaire sur la précision).

## Plateforme Apple, performances, poids

### Passe 1

Question : comment alléger l'app, compresser les modèles et mesurer les performances sur A13 pour le scanner (technologies Apple, distribution). Recherche limitée : 6 recherches web ; le texte des pages Apple n'a pas été ouvert en entier, donc beaucoup de points restent « à vérifier ». Aucun fichier modifié ; la mémoire du dépôt ne mentionne ni Background Assets, ni ODR, ni compileModel (aucune correspondance dans docs/memoire).

## 1. Résumé
- Le bundle actuel (86 Mo + 30 Mo) est modeste. Une app de moins de ~200 Mo n'a pas de vrai problème de poids, et la limite de téléchargement cellulaire est un seuil de confirmation, pas un blocage (non vérifié : la valeur actuelle). Je ne chercherais pas à télécharger les modèles tant que le total reste raisonnable.
- Si le poids devient un enjeu : Background Assets géré (Apple-hosted) est la voie moderne, mais il exige iOS 26 minimum (constaté par un blog tiers, non vérifié chez Apple). Avec une cible iOS 17, il n'est utilisable qu'en mode non géré (hébergement propre). Un app ne peut pas mélanger géré et non géré (réponse d'un ingénieur Apple sur les forums).
- On-Demand Resources serait déprécié dans les notes de version « 27 » (source unique : un blog, non vérifié chez Apple). Ne pas l'adopter.
- Compression : la palettisation est documentée comme la meilleure option sur le Neural Engine. La quantification W8A8 (int8 sur les activations) est documentée comme rapide seulement sur les puces récentes (A17 Pro, M4) : sur A13 elle ne donne probablement aucun gain de vitesse. Aucun chiffre publié de latence pour un ViT-B sur A13 : il faut mesurer sur l'appareil.
- Foundation Models : texte seulement en iOS 26, image annoncée plus tard (WWDC 2026), et il faut Apple Intelligence (iPhone 15 Pro ou plus) : inutilisable sur l'iPhone 11 Pro.

## 2. Tableau
| Technologie | Apport | Disponibilité | Impact | Complexité | Risques |
|---|---|---|---|---|---|
| Palettisation 4/6 bits (coremltools 8) | Poids réduit ; documentée la plus efficace sur ANE | coremltools 7+, modes avancés iOS 18 | Poids -50 à -70 % vs fp16 (calcul, non mesuré chez vous) ; précision à valider sur les 1 000 photos | Moyenne | Perte de précision DINOv2 : aucune source trouvée, à mesurer |
| Quantification linéaire int8 des poids | Déjà utilisée | iOS 16+ | Poids ÷2 vs fp16, vitesse neutre | Faible | Déjà acquis |
| W8A8 (activations int8) | Vitesse | Gains documentés A17 Pro / M4 seulement ; API « experimental » | Probablement nul sur A13 | Élevée (calibration) | Perte de précision, aucun gain A13 : à écarter pour l'iPhone 11 Pro |
| Background Assets géré (Apple-hosted) | Modèles hors bundle, hébergés par Apple | iOS 26+ (managed) ; limites : 200 Go, 100 packs | Bundle -116 Mo possible | Moyenne-élevée | Exige iOS 26 ; bugs bêta signalés (HTTP 400, forum) ; pas de test local sans Mac |
| Background Assets non géré, serveur propre | Modèles téléchargés | iOS 16+ (non vérifié) | Idem | Élevée, coût d'hébergement | Règle 2.5.2 (voir ci-dessous) |
| On-Demand Resources | idem | existant, obsolescence signalée | - | - | Déprécié : éviter |
| MLModel.compileModel | Compilation sur l'appareil après téléchargement | iOS 16+ | Nécessaire si on télécharge un .mlpackage | Faible | Temps de première utilisation ; ne pas compiler en fond sans test |
| Vision (classification, masque de premier plan) | Pistes de secours sans modèle embarqué | VNGenerateForegroundInstanceMaskRequest iOS 17+ | Non évalué sur la précision aliments | Faible | Taxonomie d'aliments Vision non vérifiée |
| VisionKit DataScanner | Codes-barres live | iOS 16+, puce A12+ | - | Déjà utilisé | Photo dans le même écran : non vérifié |
| AVFoundation profondeur double caméra | Profondeur/disparité sur iPhone 11 Pro (caméras dos) | non vérifié ici | Qualité faible pour des grammes | Moyenne | Non vérifié, à tester |
| Foundation Models | Texte (iOS 26), image plus tard | Apple Intelligence uniquement | Nul sur iPhone 11 Pro | - | Inutilisable chez la cible |
| VLM sur l'appareil (FastVLM, SmolVLM2, Moondream, Qwen2.5-VL 3B, Gemma 3n) | Descriptions riches | selon runtime | Mémoire : FastVLM affiné ≈ 1 Go de RAM sous MLX (une seule source communautaire, 256 jetons) | Très élevée | 4 Go de RAM partagés avec l'app ; licence FastVLM = Apple AMLR (pas open source ; lire LICENSE_MODEL avant tout usage commercial) |

## 3. Stratégie de poids
- Garder dans le bundle : le classifieur (86 Mo), le segmenteur (30 Mo), la base SQLite. Ça fonctionne hors ligne, sans serveur, sans risque de revue.
- Mesurer d'abord : exporter avec `xcodebuild -exportArchive` et une option de rapport d'« app thinning » (non vérifié pour la CI), et lire « App Store File Sizes » dans App Store Connect après un envoi TestFlight. Décider seulement si le téléchargement dépasse un seuil gênant.
- Si on doit alléger : (1) palettiser le classifieur à 6 bits, (2) seulement ensuite envisager Background Assets, et uniquement si on relève la cible à iOS 26 (sinon mode non géré avec serveur propre, ce qui ajoute coût et risque).
- Gain estimé réaliste : de 86 Mo à ~35-45 Mo par palettisation 4-6 bits (calcul simple, non mesuré). Le gain de téléchargement différé serait de ~116 Mo, au prix de la première utilisation hors ligne.

## 4. Compression et mesure sur A13
- Méthode : convertir en variantes (int8 actuel, palettisation 6 bits, 4 bits), puis comparer sur le banc de 1 000 photos déjà en place (nom du premier coup 70,4 %) : accepter une variante si la perte est inférieure à ~0,5 point (seuil à fixer par vous).
- Latence : aucun chiffre publié pour ViT-B/14 ou RF-DETR-Seg sur A13. Mesurer avec un test d'instrumentation sur la CI (simulateur ne représente PAS l'ANE) : il faut un iPhone réel, donc l'iPhone 11 Pro de l'utilisateur via TestFlight, avec un mode de benchmark caché dans le build interne. Comparer `.cpuAndNeuralEngine`, `.cpuAndGPU` et `.all`. Le plan de calcul Core ML (MLComputePlan, à vérifier) indique quelles opérations retombent sur le CPU.
- Piège connu : les opérations d'attention d'un ViT peuvent retomber sur le CPU ; conseil de ma source : tester avec `CPU_AND_NE`.

## 5. Top 5
1. Mesurer avant d'agir : taille réelle du téléchargement (App Store Connect) et latence sur l'iPhone 11 Pro (benchmark dans le build interne). Impact : évite un chantier inutile.
2. Ne pas télécharger les modèles tant que le total reste modeste ; garder tout hors ligne.
3. Tester la palettisation 6 bits du classifieur sur le banc de 1 000 photos (gain poids, risque contrôlé).
4. Écarter W8A8 et Foundation Models pour l'iPhone 11 Pro (pas de gain / non supporté).
5. Ne pas lancer de VLM embarqué (mémoire, licence AMLR, complexité) ; réévaluer si la cible passe à des appareils récents.

## 6. Obstacles et sources
- Pas de Mac : conversion coremltools possible sur Windows/Linux (non vérifié pour toutes les opérations), mais les mesures ANE exigent un vrai iPhone.
- Règle 2.5.2 : interdit le code exécutable téléchargé ; les poids de modèle sont des données, mais je n'ai pas obtenu le texte actuel de la règle ni une décision d'Apple sur les modèles : non vérifié. Allégations santé (1.4.1), manifeste de confidentialité : non recherchés.
- Interface de capture (point 6) et ARKit sans LiDAR : non traités.
- Sources : [coremltools, optimisation](https://apple.github.io/coremltools/docs-guides/source/opt-overview.html) ; [coremltools, nouveautés](https://apple.github.io/coremltools/docs-guides/source/opt-whats-new.html) ; [Background Assets, taille](https://developer.apple.com/tutorials/data/documentation/backgroundassets/assetpack/downloadsize.md) ; [forum, limite des packs](https://developer.apple.com/forums/thread/810659) ; [forum, géré vs non géré](https://developer.apple.com/forums/thread/827100) ; [ODR déprécié (blog, non Apple)](https://blakecrosley.com/blog/on-demand-resources-deprecated-background-assets) ; [FastVLM](https://github.com/apple/ml-fastvlm) ; [Core ML vs Foundation Models (tiers)](https://dev.to/arshtechpro/core-ml-vs-foundation-models-which-should-you-use-3jo0) ; [Callstack, après WWDC 2026 (tiers)](https://callstack.com/blog/on-device-ai-after-wwdc-2026-whats-new) ; [MacStories sur 2.5.2 (2017)](https://www.macstories.net/linked/apples-app-store-guidelines-now-allow-executable-code-in-educational-apps-and-developer-tools/).

Incertitudes : tout ce qui est « non vérifié » ci-dessus ; en particulier les versions iOS exactes, la dépréciation d'ODR, la perte de précision de la palettisation sur DINOv2 et la latence A13.

Prochaine action : ajouter un mode de benchmark (latence par unité de calcul) dans le prochain build `[interne]` pour obtenir les vraies mesures sur l'iPhone 11 Pro, et lire la taille du téléchargement dans App Store Connect avant toute décision de distribution. Demander une seconde passe de recherche ciblée (règle 2.5.2 et 1.4.1 sur le site Apple, interface de capture) si utile.

### Passe 2

Vérification Apple, deuxième passe. Bilan : 15 pages ouvertes. Les pages HTML de developer.apple.com sont rendues par JavaScript et renvoient le plus souvent seulement un titre. J'ai donc utilisé le point d'accès JSON de la documentation (developer.apple.com/tutorials/data/documentation/...), qui contient le texte officiel. Les pages d'aide App Store Connect se lisent normalement. Ci-dessous, « vérifié » signifie lu sur une page Apple ; le reste est dit « introuvable ».

## Corrections majeures de mon premier rapport
1. VisionKit : j'avais laissé entendre qu'une photo dans le même écran n'était pas démontrée. FAUX, corrigé. `DataScannerViewController` a `capturePhoto() async throws -> UIImage`, « Captures a high-resolution photo of the camera's live video » (rubrique « Capturing photos »). Lecture des codes-barres et photo du plat peuvent donc partager le même écran et la même session. Source : https://developer.apple.com/tutorials/data/documentation/visionkit/datascannerviewcontroller.json
2. On-Demand Resources : la dépréciation est CONFIRMÉE chez Apple (plus seulement par un blog). `NSBundleResourceRequest` : introduit iOS 9.0, déprécié 27.0 (iOS, iPadOS, Mac Catalyst, tvOS, visionOS, watchOS), message « Use Background Assets instead. » Source : https://developer.apple.com/tutorials/data/documentation/foundation/nsbundleresourcerequest.json
3. Limite de packs Apple-hosted : 200 packs (pas 100 comme dit par des messages de forum) et 200 Go au total, par fiche d'app. Source : https://developer.apple.com/help/app-store-connect/reference/apple-hosted-asset-pack-size-limits (« Asset pack total 200 GB », « Asset pack count 200 », partagé entre plateformes).

## Réponses aux 8 points
1. Guidelines (https://developer.apple.com/app-store/review/guidelines/, lues sur 100 000 de 114 428 caractères).
 - 2.5.2 : « Apps should be self-contained in their bundles, and may not read or write data outside the designated container area, nor may they download, install, or execute code which introduces or changes features or functionality of the app… » Exception pour les apps éducatives qui enseignent le code.
 - Le texte ne parle pas de modèles ni de poids Core ML. Aucune mention de « machine learning model » dans la partie lue. Donc : permission explicite introuvable. Une lecture raisonnable (supposé, non documenté) : des poids sont des données, pas du code exécutable, mais un modèle téléchargé qui change les fonctions de l'app est à risque. Le moyen le plus sûr est Background Assets, mécanisme officiel d'Apple pour du contenu hors bundle. À décider avec prudence, pas de garantie.
 - 4.2.3(ii) (constaté) : « If your app needs to download additional resources in order to function on initial launch, disclose the size of the download and prompt users before doing so. » Si le scanner exige un modèle téléchargé au premier lancement, il faut afficher la taille et demander à l'utilisateur.
 - 1.4.1 : « Apps must clearly disclose data and methodology to support accuracy claims relating to health measurements, and if the level of accuracy or methodology cannot be validated, we will reject your app. » Et : rappeler à l'utilisateur de consulter un médecin avant toute décision médicale. Pour Ardane : ne pas présenter les calories/grammes comme exacts ; indiquer la méthode et le niveau d'incertitude. (Sections 5 et suivantes non lues : confidentialité 5.1 non vérifiée.)
2. Background Assets (https://developer.apple.com/tutorials/data/documentation/backgroundassets.json) : le cadre est disponible iOS 16.0 (macOS 13.0, tvOS 18.4, visionOS 2.4). La page ne donne PAS de version distincte pour géré / non géré ni pour Apple-hosted. L'exigence « iOS 26 minimum » pour le mode géré (blog) reste donc NON VÉRIFIÉE chez Apple. Textes confirmés : « If you choose Apple-Hosted Background Assets, you upload your assets to App Store Connect and maintain them there, similar to app builds » ; les packs doivent être envoyés avant TestFlight/App Store ; clé `BAUsesAppleHosting`. Extension : `ManagedDownloaderExtension`. L'impossibilité de mélanger géré et non géré vient d'un message d'ingénieur sur les forums (https://developer.apple.com/forums/thread/827100), pas de la doc. Tailles : 200 Go / 200 packs (voir correction 3). Taille de l'app elle-même : 4 Go non compressée, exécutable 500 Mo pour iOS 9+ (https://developer.apple.com/help/app-store-connect/reference/maximum-build-file-sizes). La page de taille de la fiche produit affichera « Up to » avec les packs essentiels.
3. ODR : voir correction 2.
4. Limite cellulaire : INTROUVABLE dans la source primaire (la page des tailles maximales n'en parle pas ; le texte des guidelines lu non plus). Ne pas citer de chiffre.
5. AVFoundation : `builtInDualWideCamera` (iOS 13.0+) : « can generate depth data by measuring the disparities between the images captured by the ultrawide and wide-angle cameras » (https://developer.apple.com/tutorials/data/documentation/avfoundation/avcapturedevice/devicetype-swift.struct/builtindualwidecamera.json). `builtInTripleCamera` (iOS 13.0+) : aucune mention de profondeur dans l'abrégé. `AVDepthData` (iOS 11.0+) : carte de profondeur (mètres) ou de disparité (1/mètre) ; `depthDataAccuracy` existe mais sa page ne dit pas relative ou absolue : INTROUVABLE (les cas de l'énumération ont renvoyé 404). `AVCapturePhotoOutput.isDepthDataDeliveryEnabled` (iOS 11.0+) : à activer avant `startRunning()`, vérifier `isDepthDataDeliverySupported`. Les formats exacts de l'iPhone 11 Pro (`supportedDepthDataFormats`) : introuvables ; la précision d'une profondeur par disparité entre deux caméras proches pour estimer des grammes reste non démontrée.
6. VisionKit : `isSupported` exige A12 Bionic ou plus récent (« For this property to be true, the device must have the A12 Bionic chip or later »), iOS 16.0+ ; Apple recommande la clé `UIRequiredDeviceCapabilities` avec `iphone-ipad-minimum-performance-a12` si le scan est indispensable. `isAvailable` : permission caméra non refusée et pas de restriction. L'iPhone 11 Pro (A13) est donc supporté. Source : .../datascannerviewcontroller/issupported.json.
7. HIG caméra plein écran : INTROUVABLE (la page « Camera Control » ouverte n'a rendu que son titre ; la page « Camera » des HIG n'a pas été lue). Mes conseils sur l'aperçu `resizeAspectFill`, la grille, l'indicateur de niveau étaient des connaissances générales, pas des citations Apple.
8. MLComputePlan : la page primaire renvoie 404 en JSON et un titre seul en HTML ; la disponibilité « iOS 17.4 » est une mémoire non vérifiée. Méthode de mesure : Xcode (éditeur de modèle › onglet Performance › rapport sur appareil connecté) est la méthode que je connais, mais la page Apple ouverte n'a rendu que le titre : NON VÉRIFIÉ. Instruments (modèle Core ML) : non ouvert.

## Ce qui reste valable de mon premier rapport
- Palettisation recommandée sur le Neural Engine et W8A8 réservé aux puces récentes (A17 Pro, M4) : issus de la doc coremltools (https://apple.github.io/coremltools/docs-guides/source/opt-overview.html), à ne pas confondre avec une preuve pour l'A13.
- Foundation Models, VLM, FastVLM (licence Apple AMLR) : non revérifiés à la source primaire dans cette passe.

## Conséquence sur la recommandation
Garder les modèles dans le bundle reste le choix le plus sûr côté revue (2.5.2). Si un allègement devient nécessaire : Background Assets (iOS 16+ pour le cadre, mode géré à confirmer), pas ODR (déprécié). Le scanner peut utiliser un seul écran `DataScannerViewController` avec `capturePhoto()` : piste simple à étudier avant tout écran AVFoundation personnalisé.

Prochaine action : lire à la source les trois pages restées introuvables (limite cellulaire, rapport de performance Core ML, `AVDepthData.Accuracy`) depuis une session ayant accès au HTML rendu, ou les accepter comme incertitudes.

## Données, recettes, banc de 10 000 plats, corrections

### Passe 1

Question : constituer un banc indépendant de 10 000 plats (reconnaissance ≥ 90 %, grammes par aliment ≥ 80 % à ±20 %, IoU ≥ 0,90), choisir les bases nutritionnelles et recettes, et apprendre des corrections des utilisateurs.

Méthode : trois recherches web seulement (MetaFood3D, Nutrition5k, USDA FDC). Tout le reste vient de ma connaissance générale. Je le marque « non vérifié » : il faut le contrôler à la source avant toute décision. Je n'ai pas lu le dépôt Ardane au-delà du brief.

## 1. Résumé
- Aucun jeu public ne donne 10 000 plats avec poids PAR ALIMENT, masques et licence commerciale claire. Les 10 000 plats ne peuvent pas venir de jeux existants. Les jeux existants servent de compléments (voir l'ordre de grandeur plus bas).
- Il faut un banc maison, pesé, hors des sources d'entraînement. Pour les grammes, 10 000 plats entiers sont inutiles. Environ 1 500 à 2 500 plats pesés par aliment suffisent pour (B). Pour (A) et (C), environ 3 000 à 5 000 photos annotées, avec un minimum par catégorie.
- Le facteur limitant est la pesée par aliment (travail humain), pas l'annotation de masques.
- Bases nutritionnelles : garder FCÉN comme base principale. Ajouter USDA FDC/FNDDS (domaine public, sûr) pour les recettes et comme repli. CIQUAL est une option. Open Food Facts reste limité aux codes-barres (ODbL).
- Apprentissage par les corrections : faisable sur l'appareil (déjà fait). La collecte centralisée est possible avec consentement explicite (Loi 25, RGPD). L'apprentissage fédéré est irréaliste pour une petite équipe.

## 2. Jeux de données
Légende : « v » = vérifié dans cette session ; « nv » = non vérifié.

| Jeu | Contenu / taille | Poids par aliment | Masques | Licence | Pertinence |
|---|---|---|---|---|---|
| Nutrition5k | 5 006 plats, vidéo + profondeur, masse et nutriments par ingrédient (v : [Nutrients 2025](https://mdpi.com/2072-6643/17/13/2196), [CVPR 2021](https://openaccess.thecvf.com/content/CVPR2021/papers/Thames_Nutrition5k_Towards_Automatic_Nutritional_Understanding_of_Generic_Food_CVPR_2021_paper.pdf)) | Oui, par ingrédient. Des erreurs de masse sont signalées (v, même article). | Non (je crois, nv) | CC BY 4.0 vue sur un miroir [Hugging Face](https://huggingface.co/datasets/panikos/nutrition5k_dataset/commits/main). Le dépôt officiel Google n'a pas été vérifié. | Entraînement et évaluation des grammes. Caméra fixe, cafétéria américaine : domaine étroit. Vous en utilisez déjà 506. |
| MetaFood3D | 743 objets 3D scannés, 131 catégories (v2) ; masques, RGB-D, poids et code de base nutritionnelle ([arXiv](https://arxiv.org/abs/2409.01966)) | Oui, par objet isolé | Oui | Licence introuvable (v). Page de téléchargement : lorenz.ecn.purdue.edu/~food3d/. Usage commercial non démontré. | Faible pour un banc de plats. À considérer comme non commercial tant que la licence n'est pas lue. |
| NutritionVerse-Real / -3D | Quelques centaines à milliers d'images, avec poids (nv) | Oui, par aliment (nv) | Oui (nv) | nv | À vérifier. Taille trop petite pour le banc. |
| MyFoodRepo / AIcrowd FRB 2022 | Photos suisses, environ 24 000 images (nv) ; vous avez 1 830 aliments annotés dans le jeu de test | Non | Oui | CC BY 4.0 (indiqué dans votre contexte, nv ici) | Reconnaissance et segmentation. Photos suisses. À exclure du banc s'il sert à l'entraînement. |
| UNIMIB2016 | environ 1 000 plateaux de cafétéria italienne, 73 classes (nv) | Non | Oui, polygones | nv, probablement académique | Faible. |
| ECUSTFD | environ 2 900 images, 20 classes, avec objet de référence (nv) | Masses par photo (nv) | Oui (nv) | nv | Faible, domaine étroit. |
| FoodSeg103 | environ 7 000 images, 103 classes, masques (nv) | Non | Oui | nv, recettes issues de Recipe1M (nv) | Segmentation seulement. Licence commerciale douteuse. |
| UECFoodPix Complete | Plats japonais, 102 classes (nv) | Non | Oui | nv, académique (nv) | Faible pour le Québec. |
| Open Images (aliments) | Boîtes englobantes, quelques masques | Non | Peu | Annotations CC BY 4.0 ; images CC BY avec auteur variable (nv) | Seulement pour des négatifs ou des aliments isolés. |

Poids par aliment réellement disponibles : environ 5 000 plats avec poids (Nutrition5k) plus quelques centaines d'autres. Chiffre issu de mon estimation, nv. Le total reste très inférieur à 10 000 et les domaines sont étrangers au Québec. Conclusion : il faut un banc maison.

## 3. Plan du banc
Sources, par ordre de valeur :
1. Collecte maison pesée (gros du banc). Un participant pèse chaque composant avec une balance de cuisine à 1 g avant de les assembler, puis photographie avec son téléphone. Cadre à fixer : 2 à 3 angles, éclairage libre, assiettes variées. Pesée avant assemblage, aliment par aliment, pour avoir la vérité terrain.
2. Partenaires : cafétérias, traiteurs, programmes de nutrition d'universités québécoises (contacts à établir, nv). Ils peuvent peser les portions à la préparation.
3. Collecte volontaire via l'app avec consentement et pesée facultative. Utile pour la diversité des photos, mais les poids sont moins fiables.
4. Photos libres de droits (CC0, CC BY) de plats québécois pour (A) et (C) seulement. Sans poids.

Taille et répartition :
- (B) grammes : 1 500 à 2 500 plats pesés, soit environ 4 000 à 8 000 aliments, répartis en 8 à 12 familles d'aliments.
- (A) et (C) : 3 000 à 5 000 photos annotées en masques.
- Un banc de 10 000 plats entiers est un objectif de prestige, pas une nécessité statistique. Si l'utilisateur le maintient, comptez 3 à 5 fois les coûts ci-dessous.

Outils (nv, à confirmer) :
- CVAT : open source (MIT), auto-hébergeable.
- Label Studio Community : Apache 2.0, auto-hébergeable.
- Prestataires : Scale, Labelbox, SuperAnnotate. Tarifs surtout sur devis, donc non vérifiés. Ordre de grandeur courant pour un masque d'instance : 0,05 à 0,30 USD (nv).

Contrôle qualité :
- Double annotation de 10 à 20 % des images. Mesurer l'accord par IoU entre annotateurs et par kappa de Cohen sur les classes.
- Arbitrage par un diététiste pour les classes et les poids litigieux.
- Quasi-doublons : hachage perceptuel (pHash) puis distance d'embeddings DINOv2. Comparer le banc à tout l'entraînement et à l'étalonnage.
- Séparation par groupe : source, photographe, repas et session. Aucune photo du même repas ou du même participant des deux côtés.
- Stratification par catégorie (viandes, féculents, légumes, fruits, produits laitiers, plats composés, sauces, boissons) et par difficulté (mélangé, couvert, sauce, plat sombre).

Coûts et délais (fourchettes personnelles, non vérifiées) :
- Pesée et photos : 5 à 15 minutes par plat. Pour 2 000 plats : 170 à 500 heures de bénévolat ou d'étudiants, soit 3 000 à 10 000 USD à 20 USD/h.
- Annotation de masques : 2 à 6 minutes par aliment avec assistance de modèle. 4 000 photos × 3 aliments × 4 minutes = environ 800 heures, soit 10 000 à 25 000 USD en interne.
- Délai réaliste : 3 à 6 mois pour le banc minimal. Ne pas promettre 10 000 plats avant un an.

Statistiques :
- Intervalle de Wilson ou de Clopper-Pearson pour une proportion. Pour prouver ≥ 90 % avec une borne inférieure à 95 % de 88 % ou plus, il faut environ 600 à 900 cas évaluables si la vraie valeur est 91 à 92 %. Calcul à refaire, car il dépend de l'écart réel.
- Pour ≥ 80 % à ±20 % : environ 400 à 600 aliments par catégorie suffisent pour une demi-largeur d'environ ±4 points. Calcul à refaire.
- Les aliments d'un même plat sont corrélés. Utiliser un bootstrap groupé par photo ou par plat. Les intervalles de Wilson naïfs sont trop étroits.
- Comparer deux modèles sur le même banc avec McNemar (apparié) ou un bootstrap apparié.
- Comparaisons multiples par catégorie : Holm-Bonferroni ou contrôle du FDR. Annoncer à l'avance les hypothèses.
- Chaque catégorie a besoin d'au moins 100 à 150 cas pour une conclusion utile. Les catégories plus petites doivent être signalées comme non concluantes, jamais regroupées en silence.
- L'IoU moyenne se rapporte avec un bootstrap groupé. Préciser que les masques de référence ont eux-mêmes un accord limité : un IoU de 0,90 est proche du plafond humain. Mesurer cet accord pour fixer un objectif réaliste.

## 4. Bases nutritionnelles et recettes
- FCÉN (Santé Canada) : base principale, licence gouvernementale canadienne (nv, vérifier les conditions de réutilisation commerciale à la source).
- USDA FoodData Central : données en domaine public, CC0 1.0 (v : [fdc.nal.usda.gov](https://fdc.nal.usda.gov/index.html), [data.gov](https://catalog.data.gov/dataset/fooddata-central)). Le catalogue data.gov classe FNDDS sous l'étiquette « domaine public » des États-Unis plutôt que CC0 ([FNDDS](https://catalog.data.gov/dataset/food-and-nutrient-database-for-dietary-studies-fndds)). Les deux sont permissifs. Les recettes FNDDS décomposent les plats en ingrédients et grammes : ce sont les modèles de recettes les plus sûrs sur le plan juridique. Je n'ai pas vu de texte précisant la licence des tables de recettes elles-mêmes : à lire dans la documentation FNDDS.
- CIQUAL (ANSES) : Licence Ouverte, compatible avec l'usage commercial (nv). Utile pour les produits français.
- Open Food Facts : ODbL. Obligations de partage à l'identique pour la base dérivée et d'attribution (nv). Garder strictement aux codes-barres, sans mélanger à la table maison.
- API payantes (Nutritionix, Edamam, Spoonacular, Passio) : prix et licence de stockage non vérifiés. Les conditions interdisent souvent la copie en cache. À éviter pour un usage hors ligne sur l'appareil.
- Jeux de recettes (Recipe1M, RecipeNLG, Food.com) : licences non vérifiées. Recipe1M est réputé pour un usage académique. À ne pas utiliser pour le commerce.
- Recettes québécoises : écrire des modèles de recettes à partir de sources publiques (Canada, Québec) et de la FCÉN, puis les faire valider par un diététiste ou nutritionniste. Pour les plats comme la poutine ou le pâté chinois, utiliser des proportions pesées lors de la collecte, avec la plage de variation. Comptez environ 30 à 60 modèles de base.

## 5. Apprentissage par les corrections
- Sur l'appareil : c'est déjà le cas (mémoire visuelle personnelle, repondération sur 60 jours). Sans transfert hors de l'appareil, il n'y a presque aucune contrainte légale à ajouter.
- Collecte volontaire de photos et corrections : possible avec consentement explicite, distinct et révocable, indiqué à l'écran avant tout envoi.
- Loi 25 (Québec) : consentement exprès, information claire, droit de retrait et de suppression, évaluation des facteurs relatifs à la vie privée avant un projet qui implique des renseignements personnels (nv). Les photos de repas peuvent révéler des données de santé : prudence. Faire valider par un juriste québécois.
- RGPD : base légale par consentement, minimisation, droit à l'effacement. Pour la santé, c'est une catégorie particulière, soumise à des règles plus strictes (nv).
- App Store : étiquettes de confidentialité à jour et explication de l'usage dans l'app. Respecter la règle des 5.1.x sur la collecte (nv).
- Bonnes pratiques : retirer les EXIF et la localisation, stocker sous un identifiant aléatoire, séparer les données du banc de test de tout flux d'entraînement.
- Apprentissage fédéré : irréaliste pour une petite équipe. Il faut une infrastructure, des mises à jour de modèle sur l'appareil et une agrégation sécurisée, et le gain ne justifie pas le coût. La collecte centralisée avec consentement est plus simple.
- Piège : les photos utilisateur ne doivent jamais entrer dans le banc de test, sinon l'indépendance est perdue.

## 6. Obstacles, irréaliste, sources
- Irréaliste : 10 000 plats avec poids par aliment en quelques mois depuis des jeux publics ; IoU ≥ 0,90 garanti sur tous les cas sans mesurer d'abord l'accord humain ; une précision ≥ 90 % sur toutes les catégories si certaines familles sont intrinsèquement ambiguës (sauces, mélanges).
- Obstacles : poids de référence imprécis (la pesée avant assemblage ne capte pas les pertes de cuisson, les os, les peaux) ; licences de jeux non lues ; coût humain de la pesée.
- Sources lues dans cette session : [MetaFood3D arXiv](https://arxiv.org/abs/2409.01966) ; [Nutrition5k CVPR 2021](https://openaccess.thecvf.com/content/CVPR2021/papers/Thames_Nutrition5k_Towards_Automatic_Nutritional_Understanding_of_Generic_Food_CVPR_2021_paper.pdf) ; [Nutrients 2025 sur Nutrition5k](https://mdpi.com/2072-6643/17/13/2196) ; [miroir Hugging Face](https://huggingface.co/datasets/panikos/nutrition5k_dataset/commits/main) ; [USDA FDC](https://fdc.nal.usda.gov/index.html) ; [data.gov FNDDS](https://catalog.data.gov/dataset/food-and-nutrient-database-for-dietary-studies-fndds). Consultées le 2026-11-04.

Incertitudes : licences officielles de Nutrition5k (dépôt Google), MetaFood3D, NutritionVerse, FoodSeg103, UEC, UNIMIB, ECUSTFD ; prix des prestataires et des API ; conditions de réutilisation de la FCÉN et de CIQUAL ; tailles d'échantillon (à recalculer par simulation) ; texte exact de la Loi 25.

Prochaine action : (1) lire les licences à la source pour les 6 jeux ci-dessus, en commençant par Nutrition5k et MetaFood3D ; (2) décider avec l'utilisateur si l'objectif est 10 000 plats entiers ou un banc minimal de 2 000 plats pesés plus 4 000 photos annotées ; (3) lancer une mission de suivi pour le calcul des tailles d'échantillon par simulation, sans nouvelle dépendance ; (4) faire relire le consentement de collecte par un juriste québécois avant tout envoi de photos d'utilisateurs.

### Passe 2

Vérification de deuxième passe, consultée le 2026-11-04. Onze pages primaires ont répondu sur une vingtaine tentées. Les autres ont donné 402, 403, 404, un échec de certificat ou un nom de domaine inconnu. Elles sont listées en « introuvable ».

## Vérifié à la source primaire

1. Nutrition5k, dépôt officiel https://github.com/google-research-datasets/Nutrition5k :
   - Licence : « We release all Nutrition5k data under the Creative Commons V4.0 license ». Le lien pointe vers CC BY 4.0, donc usage commercial permis avec attribution. Le dépôt est archivé.
   - Le dépôt annonce 5 006 plats. La masse par ingrédient figure dans les métadonnées par plat (CSV `dish_metadata_cafe1` et `cafe2`). Ces CSV ne sont pas ouverts, donc le nombre exact de plats avec masse par ingrédient n'est pas vérifié. Je n'ai pas non plus vérifié que tous les plats ont une masse par ingrédient.
   - Prise de vue : 4 caméras vidéo Raspberry Pi (A à D), angles alternés de 30° et 60°, espacées de 90°. Les images RGB-D aériennes sont fournies « when available », donc pas pour tous les plats. Profondeur : 1 m vaut 10 000 unités, plafond à 0,4 m. Lieu : « a few select cafeterias in California ».
   - Correction de mon premier rapport : la licence CC BY 4.0 est maintenant vérifiée. Le jeu n'a pas de masques d'instance dans le dépôt (non détaillé sur la page).

2. FCÉN :
   - La page https://www.canada.ca/en/health-canada/services/food-nutrition/healthy-eating/nutrient-data/canadian-nutrient-file-about-us.html ne donne aucune licence. Elle renvoie au jeu de données sur open.canada.ca, qui propose la FCÉN 2026 en CSV.
   - Licence du gouvernement ouvert du Canada, v2.0 (https://open.canada.ca/en/open-government-licence-canada) : usage commercial permis (« worldwide, royalty-free, perpetual, non-exclusive »). Attribution obligatoire. Texte de repli : « Contains information licensed under the Open Government Licence – Canada. » Pas d'endossement implicite. Les marques et noms officiels sont exclus.
   - Non vérifié : que la FCÉN elle-même relève bien de cette licence (la page du jeu sur open.canada.ca n'a pas été ouverte). Mon « licence gouvernementale canadienne » du premier rapport reste donc une hypothèse plausible.

3. CIQUAL :
   - Le site https://ciqual.anses.fr/ a répondu 503. Licence introuvable à la source. Je ne peux pas confirmer que CIQUAL est sous Licence Ouverte.
   - Texte de la Licence Ouverte 2.0 (https://www.data.gouv.fr/pages/legal/licences/etalab-2.0) : réutilisation commerciale permise, mondiale, sans durée ni redevance. Condition principale : mentionner la paternité, c'est-à-dire au moins le concédant et la date de dernière mise à jour. Pas de suggestion d'endossement officiel. Les données personnelles éventuelles restent soumises aux règles de protection.

4. API payantes :
   - Spoonacular (https://spoonacular.com/food-api/pricing) : Free 0 $ (50 points/jour) ; Cook 29 $/mois (1 500 points/jour) ; Culinarian 79 $/mois (4 500) ; Chef 149 $/mois (10 000) ; Enterprise à partir de 300 $. Cache : « You may cache user-requested data ... (for a maximum of 1 hour) ». Après une heure, il faut vider le cache. À l'arrêt de l'usage, il faut supprimer toutes les données obtenues. Conclusion : incompatible avec une table hors ligne dans l'app.
   - Edamam (https://developer.edamam.com/edamam-nutrition-api) : Nutrition Analysis, Enterprise Basic 29 $/mois, Core 299 $/mois, Unlimited sur devis ; Site Parser de 0,06 à 0,01 $ par requête selon le volume. Conditions de stockage : introuvables (pages de conditions en 404).
   - Nutritionix : introuvable (402 et 404). Prix et clauses non vérifiés.
   - Passio : non ouvert, non vérifié.

5. Outils d'annotation :
   - CVAT (https://github.com/cvat-ai/cvat) : « CVAT Community is released under the MIT License ». Attention : le dossier `/serverless` peut utiliser des ressources tierces sous licences séparées, y compris non commerciales ; FFmpeg est sous LGPL/GPL. Prix du cloud : pas de montant sur cette page.
   - Label Studio (https://github.com/HumanSignal/label-studio) : « licensed under the Apache 2.0 LICENSE », © Heartex 2020-2025. La page ne distingue pas d'édition « Community ».
   - SuperAnnotate (https://superannotate.com/pricing) : trois plans (Starter, Pro, Enterprise), aucun prix chiffré, devis ou démonstration. Scale AI et Labelbox : introuvables (404). Encord, V7 : non essayés. Mon fourchette « 0,05 à 0,30 USD par masque » du premier rapport n'est donc PAS sourcée et reste une hypothèse. Il faut demander des devis.

6. Loi 25 (Commission d'accès à l'information, https://www.cai.gouv.qc.ca/protection-renseignements-personnels/information-entreprises-privees/consentement-personnes-entreprises) :
   - Le consentement doit être manifeste (« évident et donné d'une façon qui démontre la volonté réelle »), libre (« un réel choix », « sans contraintes et sans pression indue »), éclairé (« en toute connaissance de cause »), spécifique (« un objectif précis et clairement circonscrit »). Par écrit, il doit être demandé « distinctement de toute autre information ».
   - Le critère de nécessité « doit prévaloir en toute circonstance » : évaluer la nécessité avant de demander le consentement.
   - Évaluation des facteurs relatifs à la vie privée : texte de loi (LégisQuébec) refusé en 403 et page de la CAI en 404. Obligation non confirmée à la source dans cette passe. Mon affirmation précédente reste « non vérifiée ». À relire dans la Loi sur la protection des renseignements personnels dans le secteur privé, avec un juriste.

7. MetaFood3D : la page https://lorenz.ecn.purdue.edu/~food3d/ a échoué (certificat non vérifiable). Licence introuvable. NutritionVerse : le site officiel n'existe pas à l'adresse essayée et le dépôt GitHub essayé donne 404. Licence introuvable. Les deux restent « à traiter comme non commerciaux » tant que la licence n'est pas lue.

## Corrections au premier rapport
- Nutrition5k : licence maintenant vérifiée (CC BY 4.0, dépôt officiel). Mon mention « nv » est levée. Restreindre l'usage à des plats californiens en cafétéria reste valable.
- Fourchette de prix d'annotation : retirer, non sourcée.
- Spoonacular : exclu définitivement pour un usage hors ligne (cache d'une heure).
- Statut de la FCÉN et de CIQUAL : les licences ouvertes existent, mais l'appartenance de chaque base à sa licence n'est pas vérifiée à la source.

Prochaine action : relire la page open.canada.ca de la FCÉN, la page licence de CIQUAL (hors 503), les conditions d'Edamam et de Nutritionix, la licence MetaFood3D (hors erreur de certificat) et le texte de la Loi sur le privé sur l'évaluation des facteurs relatifs à la vie privée.

