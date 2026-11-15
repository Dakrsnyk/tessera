# Comparatif des 10 styles et recommandation du Chef (2026-11-14)

Rien n'est codé. Ce document sert à choisir une direction.

## Comparatif des 10 styles

| Style | Identité de marque | Expérience d'usage | Perception premium | Effort pour le coder |
|---|---|---|---|---|
| 1 Saphir | très forte : c'est Ardane, affiné | très bonne, familière sur iPhone | bonne | faible |
| 2 Architecte | forte et très distinctive | très bonne : tout se lit dans une grille | forte, un peu froide | moyen |
| 3 Carbone | moyenne : proche de beaucoup d'apps sombres | bonne le soir | bonne | moyen |
| 4 Maison | forte, mais loin du Saphir | bonne, moins dense | très forte | moyen |
| 5 Gazette | forte | bonne, mais chargée | forte | élevé : les brèves sont à développer |
| 6 Stade | faible hors du sport | bonne pour Fitness, moins pour Budget ou Études | moyenne | moyen |
| 7 Mono | moyenne : sobre, peu reconnaissable | très bonne, les widgets en couleur ressortent | forte | faible |
| 8 Canopée | faible : le Saphir disparaît | bonne, douce | moyenne | moyen |
| 9 Orbite | faible : le violet s'éloigne d'Ardane | bonne, anneaux très lisibles | forte | élevé |
| 10 Nocturne | très forte : le Saphir, la nuit | très bonne | très forte | moyen |

## Les trois styles que je recommande

1. **Saphir (n° 1), comme identité par défaut.** Il garde ce qui fait Ardane, il se code avec les composants actuels et il ne déroute personne.
2. **Nocturne (n° 10), comme mode sombre.** C'est le même bleu, la nuit, avec des filets champagne. L'app a déjà les réglages Auto, Clair et Sombre : Saphir le jour et Nocturne la nuit forment une seule identité en deux tenues.
3. **Architecte (n° 2), comme alternative forte.** C'est le plus reconnaissable. Sa grille montre toutes les mini-apps et leur chiffre du jour d'un coup d'œil. À garder comme option, ou comme source d'idées pour la grille des espaces.

Les autres styles ne sont pas perdus : l'app vend déjà 11 couleurs d'app en Premium. Maison, Mono ou Canopée pourraient devenir plus tard des « ambiances » Premium. C'est un travail plus lourd qu'une couleur, car les formes et les lettres changent aussi.

Précision sur les lettres : les titres à empattements de Nocturne, Maison et Gazette peuvent utiliser la police serif d'Apple (New York), fournie avec iOS. Aucune police n'est à acheter ni à embarquer.

## L'organisation que je recommande

**Accueil : « Maintenant » (H1).**
- Il garde toutes les cartes et le mode Organiser.
- Il remet en service la rangée de mini-apps, déjà écrite dans le code mais jamais branchée : chaque mini-app s'ouvre en un toucher.
- L'app classe déjà les cartes selon l'heure : la carte « Maintenant » prolonge cette logique au lieu d'en créer une.
- Plus tard, on peut y ajouter la phrase du jour de « La Une ».

**Créer : « Galerie » (C3) à l'entrée, le Studio actuel derrière.**
- « Utiliser » enregistre un modèle en un toucher, contre trois aujourd'hui.
- « Personnaliser » ouvre le Studio, qui a déjà la forme de « Atelier ».
- Le parcours guidé « Trois gestes » ne sert que pour le tout premier widget.
- Après chaque enregistrement, on montre enfin le guide pour ajouter le widget à l'écran d'accueil. Ce guide existe, mais il n'apparaît pas aujourd'hui après Créer.
- À trancher : la frontière avec le Store. Ma proposition : Créer montre les widgets et les modèles ; le Store garde les écrans complets, les packs et les fonds d'écran.

## Pourquoi cette combinaison
- Elle améliore l'accès sans retirer une seule fonction.
- Elle réutilise ce qui existe : rangée de mini-apps, Studio, guide d'ajout, réglage clair et sombre.
- Elle garde une seule identité, reconnaissable, au lieu d'empiler des effets.

## Limites à connaître
- Les maquettes sont rendues sur ordinateur, pas sur un iPhone : les proportions fines seront à régler dans l'app.
- Le mode sombre de Saphir et le mode clair de Nocturne ne sont pas dessinés.
- Les grandes tailles de texte (accessibilité) ne sont pas dessinées.
- Les chiffres des maquettes sont des exemples.

## Suite proposée, après ton choix
1. Une maquette poussée de la combinaison retenue, en clair et en sombre, avec les écrans du constructeur et du Studio.
2. Le codage par étapes, avec une version de test sur ton iPhone à chaque étape : la rangée de mini-apps et la carte « Maintenant », puis l'entrée de Créer, puis le guide après l'enregistrement, puis le mode Nocturne.
