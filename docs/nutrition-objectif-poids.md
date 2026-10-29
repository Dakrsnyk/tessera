# Objectif de poids : formules, limites, sources

Code : `Shared/Domains/WeightPlan.swift` (`WeightPlanCalculator`). Tout est une estimation, présentée comme telle. Les constantes sont à valider par un professionnel de santé avant la publication.

## Formules
- Métabolisme de base : Mifflin-St Jeor (`NutritionCalculator.breakdown`), 10 × kg + 6,25 × cm − 5 × âge + (−161 femme / +5 homme / −78 moyenne).
- Dépense quotidienne = base × facteur d'activité (1,2 à 1,725).
- Calories visées = dépense ± (écart de poids en kg × 7 700 / nombre de jours). Ce n'est pas un pourcentage fixe : la durée choisie décide.
- Rythme : kg par semaine = écart / jours × 7 ; en % = rythme / poids de départ.
- Macros : `NutritionCalculator.goals(..., kcal:)` (protéines g/kg existantes, plafonnées à 35 % des calories, lipides 28 %, glucides le reste).
- Poids de départ et réévaluation : moyenne des pesées des 7 derniers jours (sinon le poids du profil).

## Limites de sécurité (constantes de `WeightPlanCalculator`)
| Limite | Valeur | Origine |
|---|---|---|
| Perte maximale | 1 % du poids / semaine ; conseillé 0,5 à 0,75 % | 0,5 à 1 kg/semaine des recommandations cliniques (NIH, lignes directrices canadiennes sur l'obésité), exprimés en % |
| Gain maximal | 0,5 % / semaine ; conseillé 0,25 à 0,5 % ; surplus ≤ 500 kcal/j | usage en nutrition sportive |
| Déficit | ≤ 25 % de la dépense, sauf au rythme conseillé (≤ 0,75 %/semaine) où le plancher protège | choix de conception |
| Plancher kcal | max(1 200 femme / 1 500 homme ou moyenne, 0,8 × base, 1 400 déjà en place) | minimums usuels des régimes non supervisés |
| Plafond kcal | dépense + 500 | choix de conception |
| IMC | aucune perte si IMC actuel < 18,5 ; aucun objectif dont l'IMC cible < 18,5 | OMS |
| Marge | perte refusée si dépense − plancher < 100 kcal | choix de conception |
| Durée alternative | semaines minimum au rythme conseillé (0,75 % perte, 0,5 % gain) et dans la marge de calories ; refus (professionnel) au-delà de 104 semaines | choix de conception |

Cas renvoyés à un professionnel, sans aucun calcul : moins de 18 ans (sauf maintien indicatif ; l'âge tiré de la seule année de naissance compte un an de moins pour ce test), grossesse, allaitement, situation « je préfère ne pas répondre » ou jamais renseignée (nil) pour toute perte ou prise (le maintien reste permis), prise de poids avec IMC actuel ≥ 30 (OMS), maintien quand la dépense estimée est sous le plancher, IMC trop bas, données manquantes ou aberrantes (âge 10–100, taille 120–230 cm, poids 30–300 kg), objectif contraire au poids actuel. Pour un objectif trop rapide, aucune calorie n'est calculée pour le rythme demandé : seulement pour la durée alternative.

## Suivi
- Rythme réel : médiane des pentes entre toutes les paires de pesées espacées de 3 jours ou plus (Theil-Sen), sur les 28 derniers jours et depuis le début du plan ; il faut au moins 6 pesées couvrant 14 jours. Un pic isolé ne le déplace pas.
- Écart : proposition seulement si le rythme réel diffère de 25 % ou plus du prévu (maintien : dérive de 0,25 % du poids/semaine). Rien n'est appliqué sans l'accord de l'utilisateur ; après refus, 14 jours sans nouvelle proposition.
- Nouvelle cible = dépense réelle déduite (calories suivies − rythme réel × 1 100 kcal/j) ± ce qu'il faut pour finir à la date, au plus au rythme conseillé, bornée par le plancher et le plafond.

## Non vérifié
- Les 7 700 kcal/kg sont une approximation moyenne (le métabolisme s'adapte, le gain de muscle coûte moins).
- La dépense réelle déduite suppose que l'utilisateur suit les calories annoncées.
- Aucune validation clinique ; aucune règle propre aux sportifs, diabétiques, personnes âgées ou aux troubles du comportement alimentaire (à signaler dans l'interface).
