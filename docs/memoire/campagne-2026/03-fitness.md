---
tags: [ardane, memoire, campagne-2026]
---

# 03 · Fitness — 24 s, 9:16 (+ 1:1, 4:5, 16:9)

Faits : [[Faits-verifies]] §5 · voix : film `fitness` (`F1…F7`) · [[Ressources-a-capturer]].

## Concept créatif
« Chaque série, comptée. » Énergie : noir profond, rythme de coupes plus rapide, basses marquées, bruitage sur chaque série validée. Le spectateur suit UNE série du début à la fin : on entre dans la séance, on compte, on se repose (décompte), on valide depuis l'écran verrouillé, puis on voit le mouvement (démonstration animée) et la progression. Le fil conducteur est un chiffre : « Set 3 of 4 / Série 3 sur 4 ».

## Storyboard (1 440 images)
| Plan | Temps | Image | Caméra | Transition |
|---|---|---|---|---|
| P1 | 0,0–3,5 | Séance réelle (`app-fitness-session-dark`) : routine + minuteur, « 2/14 séries », « Série 3 sur 4 · Développé couché », pas à pas des reps/charge. Texte « Every set. Counted. » | coup sec 1,15 → 1,0, haptique visuel | le compteur monte d'un cran |
| P2 | 3,5–6,8 | Gros bouton « Série faite » (état avant/après : `app-fitness-session`, `app-fitness-session-end`), puis décompte du repos (0:55…) | cadrage serré sur le décompte, 1 coupe par seconde pour 3 s | le décompte sort de l'écran |
| P3 | 6,8–10,6 | Écran verrouillé : Activité en direct (`live-rest-night` → `live-afterset-night`) ; légende « Right from your Lock Screen. ». Image avant/après uniquement (jamais un doigt qui appuie) | plongée verticale sur l'écran verrouillé | fondu du repos vers la démonstration |
| P4 | 10,6–13,8 | Démonstration animée du développé couché (`demo-bench-press-dark`, 60 i/s), puis squat et soulevé de terre en coupe ; bibliothèque (`app-fitness-library-dark`) en arrière-plan. « With Premium » | orbite 30° autour de la barre, recadrages | la barre devient la courbe de progression |
| P5 | 13,8–16,8 | Progression (`app-fitness-progress`) : volume des semaines, évolution des charges, records. « With Premium » | travelling droite → gauche | l'écran se replie en widgets |
| P6 | 16,8–20,3 | Écran d'accueil : widgets Prochaine série (bouton « Série faite »), Séance du jour, Série d'entraînement, Ma semaine. Texte « Home Screen. Lock Screen. » | rotation douce | glissement |
| P7 | 20,3–24,0 | Close | fixe | fin |

## Texte à l'écran
P1 `fitness.title`, `fitness.setCounter` · P2 `fitness.rest`, `fitness.setDone` · P3 `fitness.fromLock`, `fitness.liveActivity`, `common.lockScreen` · P4 `fitness.exercises`, `common.withPremium` · P5 `fitness.progress`, `common.withPremium` · P6 `common.homeScreen` · P7 `common.wordmark`, `common.wholeLifeOnePlace`, `common.comingSoon` · bas `common.demoData`.

## Voix off
| Id | Début | EN | FR |
|---|---|---|---|
| F1 | 0,5 | Train. Ardane counts every set. | Entraîne-toi. Ardane compte chaque série. |
| F2 | 3,8 | Rest, counted to the second. | Le repos, compté à la seconde. |
| F3 | 6,9 | Set done? Tap it on your Lock Screen. | Série faite ? Touche-la sur ton écran verrouillé. |
| F4 | 10,8 | Every exercise, move by move. | Chaque exercice, mouvement par mouvement. |
| F5 | 14,0 | And watch yourself progress. | Et regarde-toi progresser. |
| F6 | 16,8 | Right on your Home Screen, too. | Sur ton écran d'accueil aussi. |
| F7 | 20,4 | Ardane. Your whole life. One place. | Ardane. Toute ta vie. Un seul endroit. |
Voix plus ferme, courte, légèrement plus rapide ; F3 sur le moment où l'activité en direct se met à jour.

## Ressources
- Remotion existant : `Fitness`, `FitnessCold`, `LockScreen` (live), `WidgetLift`, `Close`. À CRÉER : plan P5 (progression) ; la liste des boutons de l'activité en direct doit refléter « Pause / Passer / Série faite » actuels (pas ceux de la v2).
- Captures : voir [[Ressources-a-capturer]] (séance sombre, démos d'exercice, bibliothèque, progression, live-*, widgets nextSet/todaysWorkout/trainingStreak/weekView).
- Mentions : P4 et P5 = « Avec Premium » (bibliothèque et progression). La séance, les séries, le repos, l'activité en direct, Prochaine série, Séance du jour sont gratuits. Le widget « Repos » est Premium (n'est pas montré dans cette pub, ou avec la mention).
- Interdits : « 163 exercices » à l'écran (nombre à recompter) ; fractions de charge en gros plan ; démo « 6 / 3 séances » ; afficher un doigt appuyant sur l'écran verrouillé.
