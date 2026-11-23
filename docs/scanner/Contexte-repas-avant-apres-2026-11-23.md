# Contexte du repas : avant / après (zones-test.json, 1000 photos)

## Conclusion (2026-11-23)

- **Pas de gain mesurable : le contexte reste éteint dans l'app.** Sur 1 000 photos de test jamais vues pendant le réglage, il change le 1er aliment de 13 zones sur 1 364 : 6 deviennent justes, 7 deviennent fausses (p = 1). L'écart de kcal est inchangé. Salades composées : −2 points, non significatif.
- **Pourquoi si peu :** le classifieur v4 hésite surtout entre aliments qui se ressemblent *et* s'accompagnent pareil (riz / couscous, deux salades). Le contexte de MyFoodRepo ne les départage pas.
- **Réglage (validation, 1 500 photos) :** 128 puis 24 combinaisons essayées. La meilleure ne gagne que +4 à +6 zones sur 2 094 (p ≥ 0,24), avec une dizaine d'aliments inventés en moins. Ce gain ne se retrouve pas sur le test : c'était du bruit. Choix final : k = 50, alpha = 0,25, borne ±1, poids « peut-être » 1.
- **Piste mesurée, non retenue : les zones faibles (segmenteur 0,10–0,20) soutenues par le reste de l'assiette**, proposées en « Peut-être » pour les aliments à moitié cachés.
  - Validation : 59 % de justes (contre 43 % pour les « Peut-être » actuels).
  - Test : 54 %, mais le taux *baisse* quand le soutien monte (43 %, puis 39 %). Signal instable, classement supplémentaire coûteux : non ajouté.
- **Ce qui est prêt :**
  - la règle Swift (`ScannerMealContext`), testée et identique au Python (40 cas de parité) ;
  - l'indication « Choisi d'après le reste de l'assiette » ;
  - la table apprise (`Tests/Fixtures/MealContext/ArdaneFoodPairs.json`) ;
  - l'outil de mesure (`scripts/ml/meal_context.py`, `dump_zones.py`).
- **Pour l'allumer :** placer une table dans `App/Resources/Models/` seulement si `eval` montre un vrai gain sur le test. La source la plus prometteuse : les associations des propres repas de la personne (mêmes assiettes d'une semaine à l'autre).

Paramètres : k = 50.0, alpha = 0.25, borne = ±1.0 (facteur 0.37 à 2.72), poids d'une zone « peut-être » = 1.0.

## Toutes les photos (1000 photos)

| Mesure | Avant | Après | Sur |
|---|---|---|---|
| Zones retrouvées bien nommées (1er aliment) | 70.6 % [68.1 ; 73.0] | 70.5 % [68.1 ; 72.9] | 1364 |
| … zones sûres (segmenteur >= 0,30) | 71.0 % [68.5 ; 73.4] | 71.0 % [68.5 ; 73.4] | 1294 |
| … zones ambiguës (1er aliment visuel < 0,50) | 37.9 % [32.5 ; 43.6] | 37.5 % [32.2 ; 43.2] | 293 |
| Aliments réels proposés (rappel) | 57.1 % [54.8 ; 59.4] | 57.5 % [55.2 ; 59.7] | 1796 |
| Aliments inventés (proposés, absents de l'assiette) | 436 sur 1462 | 437 sur 1469 | - |
| Ajoutés d'office (>= 0,80) faux | 95 sur 770 | 95 sur 768 | - |
| À confirmer (< 0,80) | 692 | 701 | - |
| Écart de kcal pour 100 g avec l'aliment réel (moyen / médian) | 26 / 0 | 27 / 0 | 1255 zones |
| Écart de kcal d'une portion habituelle (moyen / médian) | 27 / 0 | 26 / 0 | 1255 zones |

Zones dont le 1er aliment change de juste à faux ou inversement : 6 gagnées, 7 perdues (McNemar exact p = 1).

## Photos à 1 aliment(s) (582 photos)

| Mesure | Avant | Après | Sur |
|---|---|---|---|
| Zones retrouvées bien nommées (1er aliment) | 77.9 % [74.2 ; 81.2] | 77.7 % [74.0 ; 81.0] | 538 |
| … zones sûres (segmenteur >= 0,30) | 77.9 % [74.2 ; 81.3] | 77.8 % [74.0 ; 81.1] | 535 |
| … zones ambiguës (1er aliment visuel < 0,50) | 42.7 % [32.5 ; 53.5] | 41.5 % [31.4 ; 52.3] | 82 |
| Aliments réels proposés (rappel) | 73.9 % [70.2 ; 77.3] | 73.7 % [70.0 ; 77.1] | 582 |
| Aliments inventés (proposés, absents de l'assiette) | 166 sur 596 | 167 sur 596 | - |
| Ajoutés d'office (>= 0,80) faux | 38 sur 362 | 38 sur 362 | - |
| À confirmer (< 0,80) | 234 | 234 | - |
| Écart de kcal pour 100 g avec l'aliment réel (moyen / médian) | 12 / 0 | 12 / 0 | 493 zones |
| Écart de kcal d'une portion habituelle (moyen / médian) | 23 / 0 | 23 / 0 | 493 zones |

Zones dont le 1er aliment change de juste à faux ou inversement : 0 gagnées, 1 perdues (McNemar exact p = 1).

## Photos à 2 aliment(s) (199 photos)

| Mesure | Avant | Après | Sur |
|---|---|---|---|
| Zones retrouvées bien nommées (1er aliment) | 65.0 % [59.4 ; 70.2] | 65.3 % [59.7 ; 70.5] | 297 |
| … zones sûres (segmenteur >= 0,30) | 66.2 % [60.4 ; 71.5] | 66.5 % [60.8 ; 71.8] | 278 |
| … zones ambiguës (1er aliment visuel < 0,50) | 32.5 % [23.2 ; 43.4] | 33.8 % [24.3 ; 44.6] | 80 |
| Aliments réels proposés (rappel) | 52.9 % [48.0 ; 57.8] | 53.5 % [48.5 ; 58.3] | 391 |
| Aliments inventés (proposés, absents de l'assiette) | 103 sur 310 | 103 sur 312 | - |
| Ajoutés d'office (>= 0,80) faux | 20 sur 144 | 20 sur 143 | - |
| À confirmer (< 0,80) | 166 | 169 | - |
| Écart de kcal pour 100 g avec l'aliment réel (moyen / médian) | 35 / 0 | 35 / 0 | 269 zones |
| Écart de kcal d'une portion habituelle (moyen / médian) | 32 / 0 | 29 / 0 | 269 zones |

Zones dont le 1er aliment change de juste à faux ou inversement : 1 gagnées, 0 perdues (McNemar exact p = 1).

## Photos à 3 et plus aliment(s) (219 photos)

| Mesure | Avant | Après | Sur |
|---|---|---|---|
| Zones retrouvées bien nommées (1er aliment) | 66.4 % [62.2 ; 70.2] | 66.2 % [62.0 ; 70.1] | 529 |
| … zones sûres (segmenteur >= 0,30) | 66.1 % [61.8 ; 70.2] | 66.1 % [61.8 ; 70.2] | 481 |
| … zones ambiguës (1er aliment visuel < 0,50) | 38.2 % [30.3 ; 46.7] | 37.4 % [29.6 ; 45.9] | 131 |
| Aliments réels proposés (rappel) | 47.3 % [43.9 ; 50.7] | 47.9 % [44.5 ; 51.3] | 823 |
| Aliments inventés (proposés, absents de l'assiette) | 167 sur 556 | 167 sur 561 | - |
| Ajoutés d'office (>= 0,80) faux | 37 sur 264 | 37 sur 263 | - |
| À confirmer (< 0,80) | 292 | 298 | - |
| Écart de kcal pour 100 g avec l'aliment réel (moyen / médian) | 36 / 0 | 37 / 0 | 493 zones |
| Écart de kcal d'une portion habituelle (moyen / médian) | 28 / 0 | 28 / 0 | 493 zones |

Zones dont le 1er aliment change de juste à faux ou inversement : 5 gagnées, 6 perdues (McNemar exact p = 1).

## Scénario : Riz et poulet (1 photos)

| Mesure | Avant | Après | Sur |
|---|---|---|---|
| Zones retrouvées bien nommées (1er aliment) | 50.0 % [9.5 ; 90.5] | 50.0 % [9.5 ; 90.5] | 2 |
| … zones sûres (segmenteur >= 0,30) | 50.0 % [9.5 ; 90.5] | 50.0 % [9.5 ; 90.5] | 2 |
| … zones ambiguës (1er aliment visuel < 0,50) | 0.0 % [0.0 ; 79.3] | 0.0 % [0.0 ; 79.3] | 1 |
| Aliments réels proposés (rappel) | 20.0 % [3.6 ; 62.4] | 20.0 % [3.6 ; 62.4] | 5 |
| Aliments inventés (proposés, absents de l'assiette) | 1 sur 2 | 1 sur 2 | - |
| Ajoutés d'office (>= 0,80) faux | 1 sur 2 | 1 sur 2 | - |
| À confirmer (< 0,80) | 0 | 0 | - |
| Écart de kcal pour 100 g avec l'aliment réel (moyen / médian) | 0 / 0 | 0 / 0 | 1 zones |
| Écart de kcal d'une portion habituelle (moyen / médian) | 0 / 0 | 0 / 0 | 1 zones |

Zones dont le 1er aliment change de juste à faux ou inversement : 0 gagnées, 0 perdues (McNemar exact p = 1).

## Scénario : Steak et pâtes ou pommes de terre (4 photos)

| Mesure | Avant | Après | Sur |
|---|---|---|---|
| Zones retrouvées bien nommées (1er aliment) | 50.0 % [23.7 ; 76.3] | 50.0 % [23.7 ; 76.3] | 10 |
| … zones sûres (segmenteur >= 0,30) | 50.0 % [23.7 ; 76.3] | 50.0 % [23.7 ; 76.3] | 10 |
| … zones ambiguës (1er aliment visuel < 0,50) | 0.0 % [0.0 ; 56.2] | 0.0 % [0.0 ; 56.2] | 3 |
| Aliments réels proposés (rappel) | 46.2 % [23.2 ; 70.9] | 46.2 % [23.2 ; 70.9] | 13 |
| Aliments inventés (proposés, absents de l'assiette) | 4 sur 10 | 4 sur 10 | - |
| Ajoutés d'office (>= 0,80) faux | 0 sur 4 | 0 sur 4 | - |
| À confirmer (< 0,80) | 6 | 6 | - |
| Écart de kcal pour 100 g avec l'aliment réel (moyen / médian) | 42 / 11 | 42 / 11 | 9 zones |
| Écart de kcal d'une portion habituelle (moyen / médian) | 58 / 41 | 58 / 41 | 9 zones |

Zones dont le 1er aliment change de juste à faux ou inversement : 0 gagnées, 0 perdues (McNemar exact p = 1).

## Scénario : Poulet, riz et légumes (1 photos)

| Mesure | Avant | Après | Sur |
|---|---|---|---|
| Zones retrouvées bien nommées (1er aliment) | 50.0 % [9.5 ; 90.5] | 50.0 % [9.5 ; 90.5] | 2 |
| … zones sûres (segmenteur >= 0,30) | 50.0 % [9.5 ; 90.5] | 50.0 % [9.5 ; 90.5] | 2 |
| … zones ambiguës (1er aliment visuel < 0,50) | 0.0 % [0.0 ; 79.3] | 0.0 % [0.0 ; 79.3] | 1 |
| Aliments réels proposés (rappel) | 20.0 % [3.6 ; 62.4] | 20.0 % [3.6 ; 62.4] | 5 |
| Aliments inventés (proposés, absents de l'assiette) | 1 sur 2 | 1 sur 2 | - |
| Ajoutés d'office (>= 0,80) faux | 1 sur 2 | 1 sur 2 | - |
| À confirmer (< 0,80) | 0 | 0 | - |
| Écart de kcal pour 100 g avec l'aliment réel (moyen / médian) | 0 / 0 | 0 / 0 | 1 zones |
| Écart de kcal d'une portion habituelle (moyen / médian) | 0 / 0 | 0 / 0 | 1 zones |

Zones dont le 1er aliment change de juste à faux ou inversement : 0 gagnées, 0 perdues (McNemar exact p = 1).

## Scénario : Poisson et pommes de terre (3 photos)

| Mesure | Avant | Après | Sur |
|---|---|---|---|
| Zones retrouvées bien nommées (1er aliment) | 87.5 % [52.9 ; 97.8] | 87.5 % [52.9 ; 97.8] | 8 |
| … zones sûres (segmenteur >= 0,30) | 85.7 % [48.7 ; 97.4] | 85.7 % [48.7 ; 97.4] | 7 |
| … zones ambiguës (1er aliment visuel < 0,50) | 66.7 % [20.8 ; 93.9] | 66.7 % [20.8 ; 93.9] | 3 |
| Aliments réels proposés (rappel) | 75.0 % [40.9 ; 92.9] | 75.0 % [40.9 ; 92.9] | 8 |
| Aliments inventés (proposés, absents de l'assiette) | 1 sur 7 | 1 sur 7 | - |
| Ajoutés d'office (>= 0,80) faux | 0 sur 3 | 0 sur 3 | - |
| À confirmer (< 0,80) | 4 | 4 | - |
| Écart de kcal pour 100 g avec l'aliment réel (moyen / médian) | 30 / 0 | 30 / 0 | 7 zones |
| Écart de kcal d'une portion habituelle (moyen / médian) | 21 / 0 | 21 / 0 | 7 zones |

Zones dont le 1er aliment change de juste à faux ou inversement : 0 gagnées, 0 perdues (McNemar exact p = 1).

## Scénario : Pâtes avec sauce et viande (1 photos)

| Mesure | Avant | Après | Sur |
|---|---|---|---|
| Zones retrouvées bien nommées (1er aliment) | 75.0 % [30.1 ; 95.4] | 75.0 % [30.1 ; 95.4] | 4 |
| … zones sûres (segmenteur >= 0,30) | 100.0 % [34.2 ; 100.0] | 100.0 % [34.2 ; 100.0] | 2 |
| … zones ambiguës (1er aliment visuel < 0,50) | 50.0 % [9.5 ; 90.5] | 50.0 % [9.5 ; 90.5] | 2 |
| Aliments réels proposés (rappel) | 50.0 % [15.0 ; 85.0] | 50.0 % [15.0 ; 85.0] | 4 |
| Aliments inventés (proposés, absents de l'assiette) | 0 sur 2 | 0 sur 2 | - |
| Ajoutés d'office (>= 0,80) faux | 0 sur 1 | 0 sur 1 | - |
| À confirmer (< 0,80) | 1 | 1 | - |
| Écart de kcal pour 100 g avec l'aliment réel (moyen / médian) | 3 / 0 | 3 / 0 | 4 zones |
| Écart de kcal d'une portion habituelle (moyen / médian) | 33 / 0 | 33 / 0 | 4 zones |

Zones dont le 1er aliment change de juste à faux ou inversement : 0 gagnées, 0 perdues (McNemar exact p = 1).

## Scénario : Salades composées (salade + 2 autres aliments) (54 photos)

| Mesure | Avant | Après | Sur |
|---|---|---|---|
| Zones retrouvées bien nommées (1er aliment) | 69.5 % [61.8 ; 76.3] | 67.5 % [59.7 ; 74.5] | 151 |
| … zones sûres (segmenteur >= 0,30) | 70.4 % [62.2 ; 77.4] | 68.1 % [59.9 ; 75.4] | 135 |
| … zones ambiguës (1er aliment visuel < 0,50) | 51.5 % [35.2 ; 67.5] | 42.4 % [27.2 ; 59.2] | 33 |
| Aliments réels proposés (rappel) | 47.5 % [41.3 ; 53.8] | 47.1 % [40.9 ; 53.4] | 240 |
| Aliments inventés (proposés, absents de l'assiette) | 49 sur 163 | 50 sur 163 | - |
| Ajoutés d'office (>= 0,80) faux | 12 sur 73 | 12 sur 72 | - |
| À confirmer (< 0,80) | 90 | 91 | - |
| Écart de kcal pour 100 g avec l'aliment réel (moyen / médian) | 37 / 0 | 41 / 0 | 144 zones |
| Écart de kcal d'une portion habituelle (moyen / médian) | 29 / 0 | 29 / 0 | 144 zones |

Zones dont le 1er aliment change de juste à faux ou inversement : 1 gagnées, 4 perdues (McNemar exact p = 0.375).

Photos suisses annotées (MyFoodRepo) : mesure de la logique, pas la précision d'Ardane sur l'iPhone. Les portions ne sont pas mesurables sur ce jeu (aucun poids) : le contexte ne les change que par l'aliment choisi (écart de kcal ci-dessus).
