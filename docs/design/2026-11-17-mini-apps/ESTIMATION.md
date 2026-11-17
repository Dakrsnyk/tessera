# Refonte UX/UI des mini-apps : audit, estimation et organisation (phase 1)

Écrit le 2026-11-17 à 13 h 30. Mission du PDG : `MISSION.md`. Audits détaillés : `audit/` (10 fichiers, chacun relu par un second agent chargé de trouver les oublis). **Conception seulement : aucune ligne de l'app n'est modifiée avant la validation du PDG.**

## 1. Ce qui existe vraiment

Le code compte 9 mini-apps (`enum MiniApp`, `App/Screens/MiniApps/MiniApp.swift:6`) : Nutrition, Fitness, Planning, Études, Finances, Entreprise, Voyage, Auto, Photos. Finance est hors mission. **Habitudes n'est pas une mini-app** : c'est une page de Planning, une carte de Mon quotidien et une liste dans le Profil ; elle est traitée à part, comme demandé, et dessinée comme une mini-app nouvelle.

| Sujet | Écrans et feuilles | Fonctions existantes | dont Premium | Problèmes d'UX relevés | Taille du travail |
|---|---|---|---|---|---|
| Nutrition | 24 | 64 | 17 | 23 | très grande |
| Fitness | 18 | 68 | 12 | 31 | très grande |
| Études | 18 | 48 | 3 | 28 | très grande |
| Planning | 25 | 32 | 3 | 23 | grande |
| Entreprise | 15 | 25 | 7 | 22 | grande |
| Habitudes | 9 | 28 | 5 | 26 | moyenne |
| Voyage | 12 | 31 | 6 | 17 | moyenne |
| Auto | 12 | 20 | 4 | 18 | moyenne |
| Photos | 10 | 26 | 0 | 17 | moyenne |
| **Total** | **143** | **342** | **57** | **205** | |

Chaque planche finira par la table « Rien n'est retiré » : où se trouve chacune des fonctions existantes du sujet.

### Ce que la mission cite et qui n'existe pas (à dessiner comme « nouvelle idée », jamais comme de l'existant)
- **Nutrition** : l'hydratation (mini-app Eau retirée le 2026-10-15), l'historique des objectifs.
- **Fitness** : une page de statistiques de performance, un écran de fin de séance, plusieurs programmes, un réglage général du repos.
- **Planning** : les rendez-vous comme rubrique, les notes et rappels d'un événement, le déplacement d'un bloc au doigt.
- **Études** : les sessions de révision planifiées, le suivi des révisions par examen, l'historique des sessions.
- **Habitudes** : la mini-app à part, les habitudes hebdomadaires, les objectifs, le calendrier du mois, l'historique, les statistiques globales.
- **Mon quotidien** : le code n'a que deux largeurs de carte (demi et pleine). « Medium » et « Large » ont la même largeur ; seule la hauteur change. Le Top 3 est aujourd'hui avant les petites cartes, pas après.
- **Photos** : aucune donnée datée ni statistique, pas de carte dans Mon quotidien : les directions « analytique » et « quotidienne » n'ont pas de sens, cinq autres organisations seront explorées.

## 2. Ce qui sera livré

Le même exercice que pour Finance (`../2026-11-16-finance/`), pour chacun des 9 sujets :
- 1 planche d'analyse (captures réelles annotées, problèmes, table des fonctions) ;
- 5 planches de direction, de 6 à 9 écrans iPhone chacune, avec annotations, passages d'un écran à l'autre et table « Rien n'est retiré » ;
- 1 planche de comparaison (notes sur 10 pour les 10 critères, avantages, inconvénients, recommandation, questions).

Soit **63 planches et environ 330 écrans iPhone**, plus 1 planche de cohérence avec Mon quotidien et 1 synthèse. Images PNG et un PDF par sujet dans `pub/rapports/design-2026-11-17-mini-apps/`.

## 3. Estimation du temps de conception

Référence mesurée : Finance (19 fonctions, 7 planches, 42 écrans) a pris 3 h 15 le 2026-11-16.

| Étape | Temps de travail |
|---|---|
| 1. Audit des mini-apps | 2 h — **fait** |
| Base commune des planches (cadres, composants, journée d'exemple) et captures fraîches par la CI | 3 h |
| 2. Concevoir les cinq propositions de chaque sujet (structure, parcours, données d'exemple) | 12 h |
| 3. Réaliser les planches (écrans, rendu, corrections) | 21 h |
| 4. Comparaisons (notes, avantages, inconvénients) | 4 h 30 |
| 5. Recommandations, cohérence avec Mon quotidien, synthèse | 4 h |
| 6. Préparer l'intégration (lots par mini-app, ce qui est nouveau, ordre) | 2 h |
| **Total** | **environ 48 h de travail** |

Par sujet (étapes 2 à 5) : Nutrition, Fitness, Études : 5 h 30 chacune · Planning, Entreprise : 4 h 30 chacune · Habitudes, Voyage, Auto, Photos : 3 h 30 chacune.

**Temps réel** : les cinq directions d'un sujet se dessinent en même temps (un agent par direction), deux sujets à la fois. Sans limite d'usage, le tout tient en 12 à 14 heures de machine. Avec la limite du forfait (fenêtre de 5 heures, atteinte deux fois le 2026-11-17), il faut compter **2 à 4 jours**.

## 4. Estimation du temps d'intégration (mission distincte, après validation)

À titre indicatif : chaque mini-app en 3 ou 4 lots, chacun codé, relu, vérifié par la CI (90 minutes par passage complet) et livré en version interne.

| Sujet | Temps réel |
|---|---|
| Nutrition, Fitness, Études | 2 jours chacune |
| Planning, Entreprise | 1 jour et demi chacune |
| Voyage, Auto, Photos | 1 jour chacune |
| Habitudes (devient une vraie mini-app ; plus si l'hebdomadaire et les objectifs sont retenus) | 2 jours |
| **Total** | **environ 14 jours, soit 3 semaines**, une mini-app à la fois |

Ce chiffre dépend des directions retenues et du nombre de nouveautés gardées.

## 5. Dépendances
1. La base commune des planches doit exister avant tout le reste (elle garantit que les 63 planches parlent la même langue visuelle).
2. Planning et Études partagent l'horaire et la Concentration : elles se dessinent dans le même groupe.
3. Habitudes dépend de Planning (elle en sort).
4. Les planches d'analyse ont besoin de captures réelles : la plupart des mini-apps n'en ont plus sur la CI ; un passage de la CI (environ 80 minutes) les refait.
5. La planche de cohérence avec Mon quotidien dépend des 9 recommandations.
6. La limite d'usage du forfait.

## 6. Organisation
| Ordre | Sujets | Pourquoi |
|---|---|---|
| 0 | Base commune, captures CI | tout en dépend |
| 1 | Nutrition (pilote) | montrée en premier, en aperçu, pour confirmer le format avant de produire le reste |
| 2 | Fitness, Habitudes | les deux autres cartes larges de Mon quotidien |
| 3 | Planning, Études | pièces partagées |
| 4 | Entreprise, Voyage | |
| 5 | Auto, Photos | |
| 6 | Cohérence avec Mon quotidien, synthèse, PDF | dépend de tout |

En parallèle à chaque étape : 5 agents de dessin (un par direction), puis un relecteur par planche (rendu, débordements, table « Rien n'est retiré » comparée à l'audit, respect de Cristal), puis un agent pour la comparaison. Un sujet est montré au PDG dès qu'il est fini.
