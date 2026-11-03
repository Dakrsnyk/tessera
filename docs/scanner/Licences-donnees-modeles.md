---
tags: [ardane, scanner, chantier-22, licences]
---

# Licences des données et des modèles du scanner (preuves datées)

## MyFoodRepo (AIcrowd Food Recognition Benchmark 2022)
- Vérifié le 2026-11-02 sur la page officielle des règles : https://www.aicrowd.com/challenges/food-recognition-benchmark-2022/challenge_rules
- Texte exact (section 1, « Competition Description ») : « The dataset used in this challenge has been made available by the MyFoodRepo project (https://www.myfoodrepo.org/), and is released under the CC BY 4.0 License. »
- Conséquence : usage commercial permis avec attribution (« MyFoodRepo / AIcrowd Food Recognition Benchmark, CC BY 4.0 », lien vers la licence) dans l'app (Profil › À propos › Sources) et dans les métadonnées du modèle.
- Fichiers utilisés (version 2.1) : `public_training_set_release_2.1.tar.gz`, `public_validation_set_2.1.tar.gz` (téléchargés par l'utilisateur avec son compte AIcrowd ; empreintes SHA-256 à consigner dans `scripts/ml/` au premier traitement).
- Les règles du concours (prix, éligibilité, dates 2021-2022) concernent la compétition, pas la licence des données.

## DINOv2 (Meta)
- Code et poids sous Apache 2.0 (https://github.com/facebookresearch/dinov2) : à revérifier et dater au téléchargement des poids.

## Archive effectivement utilisée (2026-11-02)
- AIcrowd (erreur 500) et le lien Dropbox de Dataset Ninja (« Link Temporarily Disabled ») étant indisponibles, l'utilisateur a téléchargé la copie Kaggle du même jeu : https://www.kaggle.com/datasets/awsaf49/food-recognition-2022-dataset (MyFoodRepo v2.0 : 39 962 images d'entraînement annotées, 1 000 de validation annotées, 3 000 de test sans annotations ; format COCO).
- Fichier `archive.zip`, 2 575 509 790 octets, SHA-256 `234564b1cdb2b6782ba52e8fb31ecdb7494c26cc9e4618086986277546f42204` ; inspecté sans extraction : 43 962 JPG + 2 JSON, aucun chemin suspect.
- Kaggle et Dataset Ninja affichent CC0 ; la licence d'origine déclarée par les organisateurs (règles AIcrowd) est CC BY 4.0 : Ardane applique la plus exigeante (attribution).
- Extraction sûre faite le 2026-11-02 par `scripts/ml/extract_archive.py` (empreinte de l'archive vérifiée avant, chemins contrôlés, CRC vérifiés ; jeu de test sans annotations non extrait) vers `C:\Users\Etudiant\ardane-tools\ml\raw\myfoodrepo\{train,val}`. Empreintes des annotations : `train/annotations.json` SHA-256 `614aafcc75dbaab5cbdf03cf77b63885882aaef26387f1a12a722b4ec552a757` (39 962 images, 76 491 annotations, 498 classes) ; `val/annotations.json` SHA-256 `cb45ddd986f3ea9a94252e2869ae54779a7f2a1275225e583bd38a0b8478e461` (1 000 images, 1 830 annotations). La preuve de licence est archivée à côté des données : `raw/myfoodrepo/LICENCE-2026-11-02.txt`.

## RF-DETR-Seg (Roboflow), vérifié le 2026-11-02
- Toutes les tailles de segmentation (Nano à 2XL) et le paquet `rfdetr` sont sous Apache 2.0 : README du dépôt `roboflow/rf-detr` (branche `develop`, commit `091ab7f`) et paquet `rfdetr` 1.11.2 (publié le 2026-10-04). Les modèles sous licence « PML » (XL et 2XL de détection, Atto, Femto, Pico, NAS) ne sont pas utilisés.

## Entraînements faits (2026-11-03)
- Sur le PC (CPU) puis sur Kaggle (GPU T4, compte privé de l'utilisateur, carnets privés `darksnyk/ardane-food-classifier` et `darksnyk/ardane-food-segmenter`) avec la copie Kaggle ci-dessus. Aucune donnée d'entraînement ni photo de l'utilisateur n'est redistribuée ; seuls les poids et les rapports sont téléchargés dans `C:\Users\Etudiant\ardane-tools\ml\` (hors dépôt).
