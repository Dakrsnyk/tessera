---
tags: [ardane, memoire, campagne-2026]
---

# 02 · Nutrition — 24 s, 9:16 (+ 1:1, 4:5, 16:9)

Faits : [[Faits-verifies]] §4 · voix : film `nutrition` (`N1…N7`) · [[Ressources-a-capturer]].

## Concept créatif
« Sache exactement ce que tu manges. » Une seule idée : la nourriture devient lisible. Palette plus claire et plus vive que le film principal (apparence claire de l'app, fond crème/blanc chaud), pour se différencier du noir. L'anneau des calories ORANGE et les trois barres ROUGE (protéines), JAUNE (glucides), BLEU (lipides) sont les vedettes : chaque couleur correspond à un mot de la voix. Le scanner est montré par le carré de visée réel, jamais par un produit réel de marque. Même promesse que les autres pubs : à la fin, ces widgets rejoignent l'écran d'accueil et l'écran verrouillé (« Toute ta vie. Un seul endroit. »).

## Storyboard (1 440 images)
| Plan | Temps | Image | Caméra | Transition |
|---|---|---|---|---|
| P1 | 0,0–3,0 | Fond clair. Un code-barres seul (EAN fictif préfixe 200, `Barcode.tsx`) glisse dans le carré de visée du scanner réel (`scan-frame-white`). Texte « Know what you eat. » | poussée vers le carré, mise au point | le code se verrouille (flash Saphir) |
| P2 | 3,0–7,5 | Récapitulatif du scan (`ScanRecapView`, NOUVEAU) : nom, portion, calories et macros, badge « Vérifié » ; puis le bouton obturateur et un plat (carte « Estimation » sur la portion). Textes « Scan a barcode / or photograph your dish » | travelling vertical, cadrage serré | l'ajout fait monter l'anneau |
| P3 | 7,5–10,5 | Écran Nutrition (`app-nutrition-s00`) : l'anneau ORANGE des calories restantes se remplit/diminue, puis les trois barres se lèvent : rouge, jaune, bleu, chacune avec son nom (Protein / Carbs / Fat) | caméra tombe sur l'anneau, 0,4 s par barre | l'écran se replie en widget |
| P4 | 10,5–14,0 | Objectif : écran de plan de poids (`WeightPlanSummaryView`, NOUVEAU) ou carte « Mes cibles » : objectif, cibles calories/macros du jour, ligne « Estimates, adjustable at any time. » | travelling latéral | les cibles deviennent un widget |
| P5 | 14,0–17,4 | Écran d'accueil Saphir avec le widget Macros Moyen (bouton « Scanner » visible) et Calories restantes Petit ; texte « Home Screen. Lock Screen. » | rotation douce du téléphone | glissement vers le haut |
| P6 | 17,4–20,7 | Écran verrouillé : widget rond calories + rectangle « Scanner un aliment » (+ calories restantes) ; légende « iPhone unlocked. » en petit pour rester exact | gros plan écran verrouillé | le téléphone se réduit au logo |
| P7 | 20,7–24,0 | Close : « Ardane », « Your whole life. One place. », « Coming soon to the App Store » | fixe | fin |

## Texte à l'écran (clés)
P1 `nutrition.title` · P2 `nutrition.scanBarcode`, `nutrition.orPhoto`, `nutrition.verified`, `common.estimate` · P3 `nutrition.calories`, `nutrition.protein`, `nutrition.carbs`, `nutrition.fat` · P4 `nutrition.goal`, `nutrition.estimatesNote` · P5 `nutrition.homeLock` · P6 `nutrition.scanFromLock`, `nutrition.needsUnlock` · P7 `common.wordmark`, `common.wholeLifeOnePlace`, `common.comingSoon` · bas : `common.demoData`.

## Voix off
| Id | Début | EN | FR |
|---|---|---|---|
| N1 | 0,5 | Know exactly what's on your plate. | Sache exactement ce que tu manges. |
| N2 | 3,6 | Scan a barcode. Or photograph your dish. | Scanne un code-barres. Ou photographie ton plat. |
| N3 | 7,6 | Calories, protein, carbs, fat. | Calories, protéines, glucides, lipides. |
| N4 | 10,6 | Set a goal. Get your daily targets. | Fixe un objectif. Obtiens tes cibles du jour. |
| N5 | 14,0 | All of it, right on your Home Screen. | Tout ça, sur ton écran d'accueil. |
| N6 | 17,4 | And one tap away on your Lock Screen. | Et à un geste de l'écran verrouillé. |
| N7 | 20,7 | Ardane. Your whole life. One place. | Ardane. Toute ta vie. Un seul endroit. |
Voix un peu plus lumineuse, rythme vif sur N3 (chaque mot tombe sur une couleur : orange, rouge, jaune, bleu).

## Ressources
- Remotion existant : `Nutrition` (anneau et barres : refaire en orange / rouge / jaune / bleu, l'ancienne roue noire est périmée), `Barcode`, `WidgetLift`, `LockScreen`, `Close`. À CRÉER : plan P2 (récapitulatif + estimation) et P4 (plan de poids) comme images fixes recadrées.
- Captures : `scan-frame-white`, `app-nutrition-s00…s10`, `macros-m-*`, `calories-s-*`, `quickFood-*` (Premium, facultatif), `lock-macros-rect`, `lock-caloriesLeft-*`, widget d'écran verrouillé « Scanner un aliment » (NOUVEAU), récapitulatif de scan, plan de poids : [[Ressources-a-capturer]].
- Mentions : aucune fonction Premium obligatoire (scanner, 4 macros, objectif = gratuits). Si l'ajout rapide ou les nutriments apparaissent : « Avec Premium ». L'écran du scanner n'a pas de vraie caméra : carré de visée avec caméra noire/blanche.
- Interdits : « IA », chiffre de précision, promesse de santé ou de perte de poids, produit de marque.
