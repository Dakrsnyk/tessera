# Objectif partagé entre Fitness et Nutrition (2026-11-17)

Recherche faite par l'agent `research-architect` (code lu + sources en ligne), décisions prises par le Chef pendant la mission de nuit du 2026-11-17. Complète `docs/nutrition-objectif-poids.md`. **Aucune validation clinique : chiffres à faire relire par un professionnel avant la version publique.** Hors périmètre : mineurs, grossesse et allaitement, troubles alimentaires, maladies (l'app renvoie déjà à un professionnel).

## Ce que faisait le code avant
- Dépense : Mifflin-St Jeor × facteur d'activité (1,2 / 1,375 / 1,55 / 1,725), `NutritionCalculator` (`Shared/Domains/Nutrition.swift`).
- Trois objectifs seulement côté calcul : perdre −15 %, maintenir 0, prendre +10 %. Protéines 1,8 / 1,2 ou 1,6 / 2,0 g/kg, plafonnées à 35 % des calories ; lipides 28 % ; glucides = le reste.
- Deux questions « Ton objectif » : Sport (`fitnessGoal`, 7 choix) et Nutrition (`nutritionAim`, 3 choix), stockées à deux endroits. Sèche = perte de poids, prise de masse = prise de muscle dans le calcul.
- Défauts trouvés : l'objectif choisi dans Sport changeait les calories sans cocher aucune pastille dans Nutrition ; la question grossesse / allaitement n'était posée que si l'objectif venait de Nutrition ; « Ton activité » (Nutrition) était traduit « Your business » en anglais (clé partagée avec Mon entreprise) ; les libellés d'activité (« Légère 1–3 séances »…) ne correspondaient pas au vrai calcul (0–1 séance = sédentaire, 2–3 = légère, 4–5 = modérée, 6 et plus = élevée).

## Ce que disent les sources
| Objectif | Énergie | Protéines | Lipides | Statut |
|---|---|---|---|---|
| Perte de poids | déficit durable, 0,5–1 % du poids par semaine | 1,4–2,0 g/kg ; plateau ≈ 1,6 g/kg en musculation | 20–35 % des calories | sens du déficit : établi ; pourcentage exact : estimation |
| Sèche (adulte mince et entraîné) | 0,5–1 %/sem ; 0,7 %/sem garde mieux le muscle que 1,4 %/sem | 2,3–3,1 g/kg de masse MAIGRE | 15–30 % | preuve limitée (petits effectifs, athlètes) |
| Maintien | 0 | 1,4–2,0 g/kg si entraînement | 20–35 % | établi |
| Prise de muscle | surplus modeste, +10 à +20 %, gain 0,25–0,5 %/sem | 1,6–2,2 g/kg | 0,5–1,5 g/kg | estimation (revue narrative) ; le surplus optimal est inconnu |
| Prise de masse | même fourchette, plutôt le haut ; aller plus vite ajoute du gras, pas du muscle | 1,6–2,2 g/kg | 0,5–1,5 g/kg | estimation |
| Recomposition | proche du maintien, musculation, protéines hautes | ≥ 1,6 g/kg | 20–35 % | observée surtout chez les débutants ; chiffres : estimation |
| Performance, endurance | maintien ou plus, éviter la faible disponibilité énergétique | 1,2–2,0 g/kg | 20–35 % | consensus ; glucides selon le volume non relus dans le texte intégral |

Sources : Jäger et al. 2017 (ISSN, protéines), doi:10.1186/s12970-017-0177-8 · Aragon et al. 2017 (ISSN, diètes), doi:10.1186/s12970-017-0174-y · Morton et al. 2018, doi:10.1136/bjsports-2017-097608 · Helms, Aragon, Fitschen 2014, doi:10.1186/1550-2783-11-20 · Helms et al. 2014, doi:10.1123/ijsnem.2013-0054 · Iraki et al. 2019, doi:10.3390/sports7070154 · Garthe et al. 2011, doi:10.1123/ijsnem.21.2.97 · Slater et al. 2019, doi:10.3389/fnut.2019.00131 (résumé) · Thomas, Erdman, Burke 2016, doi:10.1249/MSS.0000000000000852 (résumé) · Barakat et al. 2020, doi:10.1519/SSC.0000000000000584 (résumé) · Mifflin et al. 1990, doi:10.1093/ajcn/51.2.241 · Santé Canada, apports nutritionnels de référence (fourchettes 10–35 / 45–65 / 20–35 %).

## Décisions (Chef, 2026-11-17)
1. **Un seul objectif**, stocké dans `UserProfile.fitnessGoal` (mêmes valeurs sauvegardées, deux cas ajoutés : prise de muscle, recomposition). `nutritionAim` reste lu pour les anciens comptes et devient une valeur dérivée. Un compte dont les deux anciens champs se contredisent garde exactement son calcul d'avant.
2. **Calcul par objectif** (les planchers et refus de `NutritionSafety` s'appliquent à tous) :

| Objectif | Énergie | Protéines | Nature du chiffre |
|---|---|---|---|
| Perte de poids | −15 % (inchangé) | 1,8 g/kg (inchangé) | prudent, dans les fourchettes publiées |
| Sèche | −20 % | 2,2 g/kg | estimation de conception (rythme publié 0,5–1 %/sem) |
| Maintien | 0 (inchangé) | 1,2 ou 1,6 g/kg (inchangé) | établi |
| Prise de muscle | +10 % (inchangé) | 2,0 g/kg (inchangé) | bas de la fourchette publiée |
| Prise de masse | +15 %, surplus plafonné à 500 kcal | 2,0 g/kg | estimation dans la fourchette 10–20 % |
| Recomposition | 0 | 2,0 g/kg | estimation |
| Performance, endurance | 0 (inchangé) | 1,6 g/kg (avant : 1,2 quand l'activité était sédentaire ou légère) | consensus large |
| Force | +10 % (inchangé) | 2,0 g/kg (inchangé) | choix d'origine gardé |

   Conséquence pour les comptes existants dont les cibles suivent le calcul : sèche −15 % → −20 % et 1,8 → 2,2 g/kg ; prise de masse +10 % → +15 % ; performance et endurance peu actives 1,2 → 1,6 g/kg. Les cibles réglées à la main ne bougent pas.

   Lipides 28 % et glucides = le reste : inchangés. Plafond des protéines à 35 % des calories : inchangé.
3. **Valeurs réglées à la main** : jamais écrasées. Les cibles « calculées » suivent le nouvel objectif ; avec des cibles personnalisées, Nutrition propose le nouveau calcul sans l'appliquer.
4. **Sécurité** : la question grossesse / allaitement est posée pour tout objectif de perte ou de prise, d'où qu'il vienne.
5. **Activité** : pas de nouveau calcul ; les libellés disent ce que fait vraiment le calcul. Nutrition montre l'activité déduite des séances de Fitness, modifiable.
6. Dans l'app, ces chiffres sont présentés comme une estimation, jamais comme une prescription validée.
