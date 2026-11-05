---
tags: [ardane, memoire, scanner, reprise]
---

# Point de reprise du scanner : 2026-11-04 (soir)

Écrit à la demande de l'utilisateur (mission « 90 / 80 / 90 » du 2026-11-04) : **tous les développements du scanner sont en pause** jusqu'à la validation du plan `docs/scanner/Plan-scanner-90-80-90-2026-11-04.md`. Ce document permet de reprendre exactement où le travail s'est arrêté. Rien n'a été supprimé ni réinitialisé.

## 1. Sauvegarde
- **Copie hors du dépôt** : `C:\Users\Etudiant\ardane-tools\sauvegardes\2026-11-04-mission-scanner\`. Elle contient :
  - `modifs-suivies.patch` : modifications suivies non commitées, celles de la campagne publicitaire (`scripts/ad2`, `scripts/ad3`), qui ne sont pas au scanner ;
  - `fichiers-non-suivis.tgz` : `docs/memoire/campagne-2026/10…13`, `scripts/ad2/film/src/v4/series`, `v5`, `composeHome.ts`, `vo_lib.py`, `Tests/Fixtures/Entreprise/` ;
  - `scratchpad/` : scripts de mesure et maquettes de la session.
- **Référence git locale** : `refs/sauvegardes/2026-11-04-mission-scanner` (objet `0ee13bf`, mêmes modifications suivies). Pour la relire : `git show refs/sauvegardes/2026-11-04-mission-scanner`.
- **Le dossier de travail n'a pas été touché** : les fichiers des autres sessions (campagne, entreprise) sont restés en place, non commités.
- **Données et modèles d'apprentissage** (hors dépôt, permanents) : `C:\Users\Etudiant\ardane-tools\ml\`. On y trouve :
  - `raw/` : MyFoodRepo, Nutrition5k, photos québécoises et leur `attributions.csv` ;
  - `kaggle-outputs/` : classifier-v1 à v4, segmenter-v1 et v2 ;
  - `reports/` : grammes Nutrition5k ;
  - `work/n5k-zones/`.

## 2. Ce qui est fait et fonctionne (commité)
| Commit | Contenu | Vérification |
|---|---|---|
| bb82843 `[check]`, da86e6c `[unit]`, 267bea2 `[interne]` | Phase 1 de l'app : mémoire visuelle personnelle, contexte des 60 derniers jours, pastilles de propositions | Build 324 compile ; Build 325 : tous les tests passent (14 nouveaux) ; build interne envoyé |
| d97f0d1 `[check]` | **Classifieur v4 dans l'app** (DINOv2 ViT-B, 346 classes par aliment d'Ardane dont poutine, pâté chinois, tourtière ; int8 86 Mo), carte des classes, références de parité régénérées | Build 327 compile |
| 7ab2cf7 `[unit]` | Tests logiques avec v4 (parité Core ML) ; option de vues multiples dans `pipeline_eval.py` | **Build 328 : 1 198 tests, aucun échec** ; parité Core ML v4 : zones appariées 15/18, même 1er aliment 15/15 (v3 : 14/15) ; photos libres de droits reconnues 34/44 (77 %, comme v3) ; IPA de test (Debug, non amincie) 154 Mo |

## 3. Résultats mesurés (à garder comme référence)
- **Classifieur v4 contre v3**, mêmes 1 000 photos et seuil 0,30 : nom du premier coup parmi les retrouvés **70,4 %** (65,9 %), parmi 3 propositions 88,8 % (86,2 %). En appariant les deux modèles : 135 aliments gagnés, 75 perdus (McNemar p < 0,001). Rapports : `kaggle-outputs\classifier-v4\eval-local\pipeline-v4-ardane-test.*`.
- **Découpe** : 73,9 % retrouvés au seuil 0,30 (77,9 % à 0,20). Ce qui manque : 323 aliments jamais vus, 155 mal découpés, surtout petits (tomate, beurre, salade, carotte, poivron, eau, oignon).
- **Erreurs de nom** : 401 sur 1 352 aliments retrouvés, dont 249 avec la bonne réponse parmi les 3 pastilles. Ce sont surtout des quasi-jumeaux : pains, laitue / salade composée, café / latte, confiture / beurre.
- **Option « peut-être »** (zones 0,20-0,30), sur 15 photos libres de droits : 17 nouvelles propositions, 14 justes, 1 approximative, 2 fausses. Maquette : `maquette-peut-etre.png`. **Décision de l'utilisateur attendue.**
- **Grammes Nutrition5k** (plat entier, échelle connue) : 65,8 % à ± 25 %, erreur moyenne 22,2 %. Rapport : `reports/grams-n5k-2026-11-04.md`.

## 4. Audit du 2026-11-04 (mesure de la mission)
Script `scratchpad/calib/pipeline_sets.py` (copié dans la sauvegarde), sur les 1 000 photos de test. Il mesure les aliments **distincts** de chaque assiette, au niveau des aliments d'Ardane : précision, rappel, F1, catégories, fiabilité des confiances, seuil d'ajout automatique par Learn-then-Test. Résultats : **§ 7**.

## 5. Problèmes identifiés
1. Petits aliments et aliments transparents ratés par le segmenteur Nano (312 px).
2. Quasi-synonymes confondus. Classes sans aliment d'Ardane : 54 sur 498.
3. Grammes par aliment jamais mesurés : aucune donnée avec poids par aliment dans notre chaîne.
4. Tourtière : peu de photos libres de droits (45), donc 6 bonnes réponses sur 9 au test.
5. Crédits CC BY des photos québécoises à publier avant l'App Store (page de crédits sur ardane.app).
6. Dépôt public (pour la CI) : à repasser en privé. `.git` pèse 3,7 Go à cause de l'historique des modèles.
7. Quota GPU Kaggle épuisé jusqu'au 2026-11-07 à 0 h UTC.

## 6. En pause (à reprendre seulement après validation)
- **Build `[interne]` du classifieur v4** : `[unit]` est vert (Build 328) ; envoi sur l'iPhone dès que l'utilisateur confirme la reprise.
- **Option « peut-être »** : en attente de la réponse de l'utilisateur.
- **Mesure « vues multiples »** (`pipeline_eval.py --tta miroir-marge`) : tourne en arrière-plan sur le PC, log `C:\Users\Etudiant\ardane-tools\ml\eval_v4_tta.log`, rapport `kaggle-outputs\classifier-v4\eval-local\pipeline-v4-tta-test.*`. Elle sert à une décision de la phase 1.
- **Segmenteur Small** : carnet prêt (`scripts/ml/kaggle/segmenter/notebook_cells.py`, `SIZES = ["small"]`). À pousser sur Kaggle après le 2026-11-07, avec `kaggle kernels push -p scripts/ml/kaggle/segmenter --accelerator NvidiaTeslaT4`.
- **Grammes** : affinage complet sur GPU, empreintes Nutrition5k à recalculer avec la dorsale v4, intégration expérimentale dans l'app (assiette), repas pesés (22.6).
- **Plus ancien** : sauce bolognaise seule (pas d'entrée FCÉN pure), interface inspirée de Plategist (question de l'huile, étiquettes « nom · ~g »), mémoire visuelle non incluse dans les sauvegardes de SharedStore.

## 7. Audit : résultats (2026-11-04, segmenteur passage 2 + classifieur v4, 1 000 photos de test)

### Seuil du segmenteur 0.3

- Photos : 1000 ; aliments distincts réels (niveau Ardane) : 1796 ; aliments proposés : 1462 ; zones gardées : 2126
- **Aliments distincts, automatique (1re proposition)** : précision **70.2 %** [67.7 % ; 72.6 %], rappel **57.1 %** [54.6 % ; 59.5 %], F1 **63.0 %** [60.7 % ; 65.2 %] (VP 1026, FP 436, FN 770 ; taux de faux positifs = FP / proposés = 29.8 % ; taux de faux négatifs = FN / réels = 42.9 %)
- Rappel « assisté » (le bon aliment est parmi les 3 propositions d'une zone) : **74.9 %**
- Par annotation (comme les mesures précédentes) : retrouvés 75.0 %, bien nommés 50.9 % ; nommés parmi les retrouvés 67.8 %
- Segmentation : IoU moyenne des aliments retrouvés (appariés à IoU ≥ 0,5) **0.862** ; IoU moyenne en comptant 0 pour les ratés **0.647** ; part des retrouvés à IoU ≥ 0,90 : 48.7 %

| Catégorie | Aliments réels | Précision | Rappel | F1 |
|---|---|---|---|---|
| Féculents, pains, céréales | 319 | 70.4 % | 59.6 % | 64.5 % |
| Légumes | 311 | 70.2 % | 51.4 % | 59.4 % |
| Plats, desserts, autres | 284 | 76.1 % | 56.0 % | 64.5 % |
| Viandes, poissons, oeufs | 234 | 69.7 % | 58.1 % | 63.4 % |
| Produits laitiers | 175 | 59.3 % | 49.1 % | 53.8 % |
| Boissons | 165 | 73.5 % | 73.9 % | 73.7 % |
| Sauces, condiments, tartinables | 158 | 52.6 % | 38.6 % | 44.5 % |
| Fruits | 150 | 84.2 % | 74.7 % | 79.2 % |

| Aliments distincts dans la photo | Photos | Précision | Rappel | F1 |
|---|---|---|---|---|
| 1 | 594 | 72.0 % | 73.7 % | 72.9 % |
| 2 | 195 | 67.3 % | 52.8 % | 59.2 % |
| 3 et plus | 211 | 69.7 % | 47.0 % | 56.2 % |

### Seuil du segmenteur 0.2

- Photos : 1000 ; aliments distincts réels (niveau Ardane) : 1796 ; aliments proposés : 1737 ; zones gardées : 3107
- **Aliments distincts, automatique (1re proposition)** : précision **64.9 %** [62.6 % ; 67.3 %], rappel **62.8 %** [60.6 % ; 65.0 %], F1 **63.9 %** [61.8 % ; 65.9 %] (VP 1128, FP 609, FN 668 ; taux de faux positifs = FP / proposés = 35.1 % ; taux de faux négatifs = FN / réels = 37.2 %)
- Rappel « assisté » (le bon aliment est parmi les 3 propositions d'une zone) : **79.8 %**
- Par annotation (comme les mesures précédentes) : retrouvés 81.2 %, bien nommés 54.5 % ; nommés parmi les retrouvés 67.2 %
- Segmentation : IoU moyenne des aliments retrouvés (appariés à IoU ≥ 0,5) **0.855** ; IoU moyenne en comptant 0 pour les ratés **0.695** ; part des retrouvés à IoU ≥ 0,90 : 46.2 %

| Catégorie | Aliments réels | Précision | Rappel | F1 |
|---|---|---|---|---|
| Féculents, pains, céréales | 319 | 67.6 % | 62.1 % | 64.7 % |
| Légumes | 311 | 61.0 % | 64.3 % | 62.6 % |
| Plats, desserts, autres | 284 | 69.4 % | 59.9 % | 64.3 % |
| Viandes, poissons, oeufs | 234 | 67.1 % | 63.7 % | 65.4 % |
| Produits laitiers | 175 | 52.5 % | 53.1 % | 52.8 % |
| Boissons | 165 | 70.1 % | 75.2 % | 72.5 % |
| Sauces, condiments, tartinables | 158 | 50.7 % | 47.5 % | 49.0 % |
| Fruits | 150 | 81.0 % | 79.3 % | 80.1 % |

| Aliments distincts dans la photo | Photos | Précision | Rappel | F1 |
|---|---|---|---|---|
| 1 | 594 | 66.8 % | 74.1 % | 70.2 % |
| 2 | 195 | 60.4 % | 58.2 % | 59.3 % |
| 3 et plus | 211 | 65.7 % | 56.8 % | 60.9 % |

### Fiabilité des confiances (lignes proposées, seuil 0,30)

| Confiance annoncée | Lignes | Justes | Écart |
|---|---|---|---|
| 0.15 à 0.30 (moy. 0.23) | 116 | 26.7 % | +3.3 pts |
| 0.30 à 0.50 (moy. 0.40) | 208 | 46.6 % | +7.0 pts |
| 0.50 à 0.70 (moy. 0.60) | 237 | 56.1 % | -3.9 pts |
| 0.70 à 0.80 (moy. 0.75) | 131 | 68.7 % | -6.8 pts |
| 0.80 à 0.90 (moy. 0.85) | 248 | 83.9 % | -1.4 pts |
| 0.90 à 0.95 (moy. 0.93) | 191 | 85.9 % | -7.0 pts |
| 0.95 à 1.00 (moy. 0.98) | 331 | 91.5 % | -6.2 pts |

ECE (écart moyen pondéré) : 0.050. Une ligne fausse inclut les zones qui ne sont pas un aliment réel et les aliments sans équivalent.

| Seuil d'ajout automatique | Lignes ajoutées seules | Précision des ajouts (IC 95 %) | Part des aliments réels ajoutés seuls |
|---|---|---|---|
| 0.50 | 1138 (77.8 % des lignes) | 78.9 % [76.4 % ; 81.2 %] | 50.0 % |
| 0.70 | 901 (61.6 % des lignes) | 84.9 % [82.4 % ; 87.2 %] | 42.6 % |
| 0.80 | 770 (52.7 % des lignes) | 87.7 % [85.1 % ; 89.9 %] | 37.6 % |
| 0.90 | 522 (35.7 % des lignes) | 89.5 % [86.5 % ; 92.0 %] | 26.0 % |
| 0.95 | 331 (22.6 % des lignes) | 91.5 % [88.0 % ; 94.3 %] | 16.9 % |

#### Learn-then-Test (seuil choisi sur une moitié des photos, vérifié sur l'autre)

- Risque visé 10.0 % : aucun seuil ne le garantit sur cette moitié.
- Risque visé 5.0 % : aucun seuil ne le garantit sur cette moitié.

### Erreurs des lignes à confiance ≥ 0,90 (55 sur 522)
- 25 confusions de nom (zone juste) ; 29 zones qui ne correspondent à aucun aliment annoté (15 sans chevauchement, 14 qui chevauchent un aliment à IoU < 0,5) ; 1 aliment réel sans équivalent Ardane.
- Précision des lignes ≥ 0,80 par catégorie : fruits 96,1 % (n = 102) ; viandes 89,9 % (89) ; plats 89,4 % (132) ; boissons 88,5 % (96) ; légumes 86,1 % (115) ; féculents 84,7 % (131) ; produits laitiers 81,0 % (58) ; sauces 78,7 % (47).
- Fichiers : `kaggle-outputs\classifier-v4\eval-local\audit-sets-test.json` ; scripts `pipeline_sets.py`, `analyse_sets.py`, `erreurs_haut.py` (sauvegarde, `scratchpad/calib`).
