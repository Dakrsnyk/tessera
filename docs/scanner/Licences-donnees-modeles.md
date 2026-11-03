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
