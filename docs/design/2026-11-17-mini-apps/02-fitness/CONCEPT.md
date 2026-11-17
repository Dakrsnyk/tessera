# Fitness : les cinq directions (document de conception)

Écrit le 2026-11-17. Sujet 2 de la mission `../MISSION.md`. Vérité sur l'existant : `../audit/02-fitness.md` (68 fonctions, F1 à F68) et `../audit/00-socle-commun.md`. Règles des planches : `../base/GUIDE-PLANCHES.md`. Données d'exemple et liste des fonctions : `fitness.js` (ce dossier). **Conception seulement : aucune ligne de l'app n'est modifiée.**

Ce document sert aux cinq dessinateurs. Chacun réalise une planche (`01-minimaliste.html` … `05-hybride.html`) d'après sa section, avec `fitness.js` tel quel. Personne ne recopie la liste des fonctions ni ne change un chiffre.

---

## 1. Ce que la personne vient faire

### Les besoins réels, du plus fréquent au plus rare

| Rang | Besoin | Fréquence | Fonctions de l'audit |
|---|---|---|---|
| 1 | **Valider une série et suivre son repos**, d'une main, sans réfléchir | Toutes les 1 à 3 minutes pendant une séance (18 fois pour « Haut du corps ») | F15 à F26 |
| 2 | **Savoir quoi faire aujourd'hui et commencer** | Chaque jour d'entraînement (4 fois par semaine ici) ; les jours de repos, juste vérifier | F1 à F6, F13 |
| 3 | **Régler la charge ou les répétitions** avant de valider | Plusieurs fois par séance | F18, F26 |
| 4 | **Voir où en est la semaine** (2 séances sur 4, encore 2) | Chaque ouverture | F7, F60 |
| 5 | **Revoir comment se fait un exercice** (démonstration, technique) | Pendant ou juste avant une séance, surtout au début | F45 à F51 (Premium) |
| 6 | **Voir ses progrès** (charges, records, volume) | Après une séance, ou une fois par semaine | F48, F54, F55 (Premium), F52, F53 |
| 7 | **Préparer ou corriger son programme** (séances, jours, exercices) | Rare, mais long quand ça arrive | F32 à F38 |
| 8 | **Voir ses pas** | Chaque jour, sans rien faire | F10, F56 |

### Les problèmes d'UX que la refonte doit résoudre (numéros de l'audit, section 8)

1. **Quatre pages sur dix n'ont qu'une porte, placée bas** (problème 1). « Programme », « Historique », « Exercices » et « Progression » sont sous la séance, « À remplir » et les tuiles, et le bouton flottant recouvre la carte.
2. **Les mots ne disent pas ce qu'ils ouvrent** (problèmes 2, 3, 4). La carte « Programme » contient aussi l'historique, la bibliothèque et la progression. Deux blocs s'appellent « Exercices ». La ligne « Séances faites » ouvre « Historique ».
3. **Pendant une séance, l'écran principal ne sert à rien** (problème 5) : il montre « Reprendre la séance », alors que Mon quotidien et les widgets ont « Série faite ».
4. **Sept actions en texte autour de « Série faite »** (problème 8), dont trois « Passer » et deux « Annuler ».
5. **La charge ne se tape pas et le repos ne se règle pas pendant la séance** (problèmes 9 et 10).
6. **La séance finit sur un écran de choix** (« Choisis la séance à faire. »), sans bilan (problème 6).
7. **« Séance libre » n'a pas d'accès direct** (problème 7).
8. **Tempo et notes sont saisis mais jamais relus** (problème 11) ; l'éditeur ne permet ni de changer l'ordre ni de retirer un exercice précis (problème 12).
9. **Des chiffres existent dans les widgets et pas dans la mini-app** (problème 28) : série de semaines, calendrier du mois, écart avec la semaine d'avant.
10. **Petites incohérences à corriger partout** : « Calories » sans unité (problème 18), barre de progression de deux couleurs (problème 20), filtre « Niveau » coupé (problème 24).

### Les deux phrases du PDG, traduites en critères

- « La séance du jour immédiatement compréhensible, accès rapide à l'entraînement » : le nom de la séance, sa taille (« 6 exercices · 18 séries · environ 55 min ») et le bouton pour commencer se voient **sans défiler**, dans les cinq directions. Un toucher pour commencer.
- « Pensée pour une utilisation pendant une séance » : sur l'écran « Séance », le bouton « Série faite » est le plus gros élément et le plus bas ; chiffres de 34 points au moins ; une seule action principale ; les actions rares sont rangées.

---

## 2. Ce qui vaut pour les cinq planches

### Mots (un seul nom par chose)

| Chose | Mot employé partout | Remarque |
|---|---|---|
| Titres de page | « Fitness », « Séance », « Programme », « Historique », « Exercices », « Progression », « Activité » | Titres actuels de l'app |
| Porte vers l'historique | « Historique » | **À adapter** : aujourd'hui la ligne dit « Séances faites » (problème 4). Question pour le PDG. |
| Bloc des exercices favoris | « Favoris » | **À adapter** : aujourd'hui « Exercices », comme la bibliothèque (problème 3) |
| Séance prévue | « Séance du jour » · nom · « 6 exercices · 18 séries · environ 55 min » | Libellés actuels |
| Bouton pour commencer | « Commencer » ; pendant : « Série faite » ; « Reprendre la séance » ; « Créer une séance » ; « Rattraper la séance » | Libellés actuels, jamais d'autres verbes |
| Plan d'un exercice | « 4 × 10 · 60 kg » ; au poids du corps « 3 × 8 » | `FIT.plan(e)` |
| Série faite (pastille) | « 60 × 10 » ; « Corps × 8 » ; série sautée : « Passée » | `FIT.serie(kg, r)` |
| Tuiles de la semaine | « Durée », « Volume », « Calories », « Séances » | « Calories » s'écrit « ≈ 220 kcal » : unité ajoutée, **À adapter** (problème 18) |
| Reste de la semaine | « Encore 2 séances » ; « Objectif de la semaine atteint » | Texte de Mon quotidien, repris tel quel (`FIT.encore`) |
| Réglages | « Mes paramètres », toujours en dernier | Cadre commun |

### Pièces dessinées de la même façon

- **Jour du sélecteur de semaine** : point plein = séance faite ou rattrapée ; anneau = séance prévue ; rien = repos. `PL.wsel({ sel: 3, marks: [0, 1] })` et l'anneau du samedi posé comme sur la planche Cristal 04.
- **Réglette** (« Répétitions », « Charge ») : libellé de 13, chiffre de 34 au moins, boutons − et + de 48 points, « Corps » si la charge est 0.
- **Repos** : compte à rebours en chiffres à chasse fixe, barre ou anneau dans la couleur Fitness, bouton pause rond de 44, « Passer le repos » en bouton teinté. À zéro : « Prêt ».
- **« Série faite »** : bouton plein, couleur d'action Fitness, 64 points de haut au moins, toute la largeur, en bas.
- **Barre de progression de la séance** : couleur Fitness partout (fin de la barre noire, problème 20), avec « 1/18 séries » écrit.
- **Ligne d'exercice** : nom, puis plan en gris ; à droite ⓘ (fiche) ; badge Premium à la place de ⓘ en compte gratuit.
- **Pas** : toujours `data-c="pas"` (turquoise), jamais le rouge de Fitness.
- **Fait** : coche et vert `var(--pl-ok)` ; jamais la couleur seule.

### Compte d'exemple et moments

- Compte **Premium**, programme complet, rien à remplir. Chaque planche montre **au moins un écran en compte gratuit** (indiqué dans la liste des écrans).
- Quatre moments, à écrire dans la légende : **13:20** séance prévue · **19:05** séance en cours · **19:55** séance faite (moment propre à Fitness : 18:59 + 52 min = 19:51) · 08:10 comme 13:20.
- **Une séance n'a pas d'heure** dans Fitness. Aucune planche n'écrit « 18:30 », « dans 18 min » ni un compte à rebours avant la séance.

### Données d'exemple (toutes dans `fitness.js`, objet `FIT`)

| Donnée | Valeur |
|---|---|
| Programme | 3 séances : « Haut du corps » (lundi, jeudi), « Jambes » (mardi, samedi), « Maison, sans matériel » (aucun jour). Objectif : 4 séances / semaine |
| Séance du jour | « Haut du corps » : 6 exercices · 18 séries · environ 55 min. Développé couché (barre) 4 × 10 · 60 kg ; Tractions (pronation) 3 × 8 ; Développé militaire (barre) 3 × 10 · 35 kg ; Pompes 3 × 12 ; Curl haltères 3 × 12 · 12,5 kg ; Extension triceps à la poulie 2 × 12 · 17,5 kg |
| Cette semaine (13:20) | 2 / 4 séances (lundi « Haut du corps » 59 min · 4 220 kg ; mardi « Jambes » 53 min · 4 240 kg) · Durée 1 h 52 · Volume 8 460 kg · Calories ≈ 220 kcal · « Encore 2 séances » |
| En cours (19:05) | Chrono 6:05 · 1/18 séries · Développé couché (barre), série 2 sur 4 · 10 × 60 kg · repos 0:45 sur 3:00 · « La dernière fois : 57,5 kg × 10 » · tuiles de la semaine : 1 h 58 · 9 060 kg · ≈ 228 kcal · 3 / 4, « Encore 1 séance » (dans le code, la séance en cours compte dès sa première série : `FIT.semaineEnCours`) |
| Faite (19:55) | 18 séries · 52 min · 4 320 kg soulevés · ≈ 111 kcal · semaine : 3 / 4, 2 h 44, 12 780 kg, ≈ 331 kcal, « Encore 1 séance » · record Développé couché (barre) 60 × 10 |
| Historique | 23 séances depuis le lundi 28 septembre (24 après celle du jour). Vendredi 6 novembre : séance « Rattrapée » (celle du jeudi 5). Samedi 24 octobre : « Prévu, pas fait » |
| Progression | 8 semaines de volume : 0 · 10 760 · 10 915 · 15 145 · 11 850 · 16 285 · 16 845 · 8 460 (en cours). 7 records. Développé couché (barre) : 50 → 57,5 kg en 12 séances, record 57,5 × 10, 1RM ≈ 77 kg, « +7,5 kg depuis le début · 12 séances » |
| Bibliothèque | 163 exercices ; 3 favoris (Développé couché (barre), Tractions (pronation), Squat (barre)) ; 1 exercice perso (« Tirage élastique maison ») ; recherche « développé » : 12 résultats |
| Pas | 5 480 sur 8 000 · 3,9 km · 6 étages · ~ 224 kcal · moyenne 8 323 sur 7 jours |

Cinq écarts voulus avec la planche Cristal `04-fitness.html` (le code fait foi ; détail en tête de `fitness.js`) : calories de la semaine (≈ 220 au lieu de ≈ 410, la règle de calcul ne permet pas 410) ; « La dernière fois » (57,5 kg × 10 au lieu de 59,6 kg × 8, impossible par pas de 2,5 kg) ; noms d'exercice de la bibliothèque (« Développé couché (barre) ») ; comptes « Par muscle » recomptés (Pectoraux 16, Dos 17) ; « 3 séances » sur la ligne du programme.

### Nouveautés communes (catalogue fermé : `FIT.nouveau`)

Une nouveauté porte le même nom, la même forme et les mêmes chiffres dans toutes les directions qui l'emploient. Aucune direction n'en invente d'autre.

| N° | Nouveauté | Pourquoi (audit) | Directions |
|---|---|---|---|
| N1 | Récapitulatif de fin de séance (« Séance terminée ») | Problème 6 ; section 9, point 7 | 4, 5 |
| N2 | « − 15 s » et « + 15 s » pendant le repos | Problème 10 ; section 9, point 4 | 1, 4, 5 |
| N3 | Taper la charge avant de valider (toucher le chiffre) | Problème 9 | 1, 4 |
| N4 | Série de semaines dans la mini-app (« 2 semaines de suite à l'objectif ») | Problème 28 (existe en widget) | 2, 5 |
| N5 | Calendrier du mois dans la mini-app | Section 9, points 2 et 6 (existe en widget Premium) | 2 |
| N6 | Comparer avec la semaine d'avant | Problème 28 (existe en widget Premium) | 2, 3 |
| N7 | Tempo et notes affichés pendant la séance | Problème 11 | 4 |
| N8 | Changer l'ordre et retirer un exercice précis dans l'éditeur | Problème 12 | 5 |
| N9 | Volume par groupe de muscles | Section 9, point 2 | 3 |
| N10 | Filtrer l'historique par séance | Section 9, point 6 | 3 |

N4, N5 et N6 existent déjà en widget : c'est leur présence **dans la mini-app** qui est nouvelle. Elles portent quand même « Nouveau » (règle la plus stricte de l'audit, section 9).

**Jamais montré comme existant** (audit, section 9) : heure de séance, durée ou distance d'un exercice, vidéos ou photos, Santé, montre, fréquence cardiaque, programmes tout faits, plusieurs programmes.

### Pourquoi les cinq approches du PDG sont gardées

Les cinq approches suggérées ont toutes un sens pour Fitness, parce que le sujet a deux temps très différents : **hors séance** (décider, préparer, regarder ses progrès) et **en séance** (un geste toutes les deux minutes). Aucune n'est remplacée. Une seule est fortement adaptée : la « Quotidienne » devient **« En séance »**, parce que l'usage régulier de Fitness, c'est la séance elle-même, pas une liste d'actions rapides.

---

## 3. Direction 1 · Minimaliste : « Une séance, un bouton »

Fichier : `01-minimaliste.html` · 8 écrans.

**Idée directrice.** En ouvrant Fitness, on voit la séance du jour, un bouton, et une liste fixe de cinq pages : tout tient sur un écran, sans défiler.

**Pour qui, quand.** La personne qui suit son programme sans se poser de questions, le débutant, et tout le monde à la salle au moment de commencer. La meilleure quand on ouvre Fitness pour une seule raison : faire sa séance.

**Navigation.** Une page courte et une **liste fixe de cinq lignes**, toujours dans le même ordre : « Programme », « Exercices », « Historique », « Progression », « Activité ». Chaque ligne ouvre sa page actuelle, inchangée. Pas de tuiles, pas de graphique, pas de bouton flottant.

**Élément vedette.** Le bouton « Commencer », dans la carte de verre de la séance du jour.

**Accès à l'action la plus fréquente.** Le bouton est dans la carte, haut de 64 points, sur toute sa largeur. Pendant la séance : une série par écran, « Série faite » en bas.

**Écran principal, bloc par bloc**
1. Barre : retour, « Fitness ».
2. Sélecteur de semaine (F1).
3. Carte de verre : « Séance du jour » · « Haut du corps » · « 6 exercices · 18 séries · environ 55 min » · bouton « Commencer ». Toucher le nom ouvre l'aperçu.
4. Une ligne : « 2 séances sur 4 cette semaine » · « Encore 2 séances ». Touchée, elle se déplie en quatre tuiles (F7).
5. Liste fixe : « Programme » (« 3 séances · 4 jours par semaine »), « Exercices » (« 163 exercices, fiches et démonstrations »), « Historique » (« 23 séances »), « Progression » (« Charges, volume, records et évolution »), « Activité » (« 5 480 pas sur 8 000 », icône turquoise).
6. « Mes paramètres ».

« À remplir » ne s'affiche que s'il manque une information (écran 8). Les favoris vont dans « Exercices ». La carte des pas devient la ligne « Activité ».

**Les 8 écrans**

| N° | Titre (`.nm`) | Heure | Ce qu'il montre | D'où l'on vient | Où l'on va |
|---|---|---|---|---|---|
| 1 | Page principale | 13:20 | Les 6 blocs ci-dessus, séance prévue. Jeudi choisi ; lundi et mardi en points pleins ; samedi en anneau. Rien ne flotte. | Carte Fitness de Mon quotidien, widget, notification | Toucher le nom → 2 ; « Commencer » → 3 ; « Programme » → 5 ; « Exercices » → 6 |
| 2 | Avant de commencer | 13:20 | Feuille « Haut du corps » : les 6 exercices avec leur plan et leur repos (« 4 × 10 · 60 kg · repos 3:00 »), ⓘ sur chaque ligne, « environ 55 min ». Bouton « Commencer ». En contour : « Modifier la séance ». Lien « Faire une autre séance » : « Jambes », « Maison, sans matériel », « Séance libre ». `data-tab="none"` | Écran 1, toucher le nom | « Commencer » → 3 ; « Modifier la séance » → éditeur actuel (non dessiné) |
| 3 | Séance : une série à la fois | 19:05 | Chrono 6:05 · « 1/18 séries » · barre. « Série 2 sur 4 » · « Développé couché (barre) » ⓘ. « La dernière fois : 57,5 kg × 10 » (Premium). Deux réglettes : Répétitions 10, Charge 60 kg ; toucher le chiffre ouvre le clavier (**N3**). Repos 0:45, pause, « − 15 s », « + 15 s » (**N2**), « Passer le repos ». « Série faite » de 72 points. En bas, deux boutons ronds seulement : « La séance » et « … ». Pas de liste sur cet écran. `data-tab="none"` | Écran 1 ou 2 | « La séance » ou « … » → 4 |
| 4 | La séance et les autres actions | 19:05 | Feuille « La séance » : les 6 exercices (fait, en cours, à venir), pastille « 60 × 10 » sous le premier. Dessous, deux groupes : « Cette série » (« Passer la série », « Annuler la dernière série », « Passer cet exercice ») et « La séance » (« Ajouter un exercice », « Choisir dans la bibliothèque » avec badge Premium, « Terminer la séance », « Annuler la séance »). | Écran 3 | Toucher une pastille → « Modifier une série » (non dessinée) ; « Fermer » → 3 |
| 5 | Programme | 13:20 | Page « Programme » actuelle : « Ma semaine » (Lundi Haut du corps, Mardi Jambes, Mercredi Repos, Jeudi Haut du corps, Vendredi Repos, Samedi Jambes, Dimanche Repos), « Mes séances » (3 lignes avec « 6 exercices · environ 55 min », « Nouvelle séance »), « Objectif » : « 4 séances / semaine », − / +. | Écran 1, ligne « Programme » | Toucher une séance → éditeur actuel |
| 6 | Exercices, compte gratuit | 13:20 | Bibliothèque : recherche, quatre filtres qui tiennent dans la largeur (« Muscle », « Équipement », « Type », « Niveau »), carte dorée « Toute la bibliothèque d'exercices », « Favoris » (3, badge Premium), « Mes exercices » (« Tirage élastique maison », « Créer un exercice »), « Par muscle » (Pectoraux 16, Dos 17…). **Compte gratuit.** | Écran 1, ligne « Exercices » | Toucher un exercice → fiche (Premium) ou offre |
| 7 | Page principale, séance faite | 19:55 | Carte de verre : « Séance faite » · « Haut du corps » · « 18 séries · 52 min · 4 320 kg soulevés » · « Voir le détail » · menu « … ». Ligne de la semaine **dépliée** : Durée 2 h 44, Volume 12 780 kg, Calories ≈ 331 kcal, Séances 3 / 4, « Encore 1 séance », et la note « Calories et volumes estimés… ». Liste fixe (« Historique » : « 24 séances »). | Dernière « Série faite » ou « Terminer la séance » : on revient ici, plus à l'écran de choix | « Voir le détail » → détail de la séance (non dessiné) |
| 8 | Premier jour | 13:20 | Aucun programme : « Aujourd'hui » · « Ton programme » · le texte de l'app · bouton « Créer une séance ». « À remplir 0 / 4 » avec ses quatre cartes. Liste fixe sans faux chiffres. | Première ouverture | « Créer une séance » → éditeur |

**Nouveautés (2).** N2 « − 15 s / + 15 s » (écran 3) ; N3 taper la charge (écran 3).

**À adapter (les principales).** Le bouton passe du flottant à la carte. La fin de séance ramène à la page principale (écran 7) au lieu de l'écran de choix. Les quatre tuiles sont derrière une ligne. Les sept actions de la séance sont rangées dans une feuille. « Séance libre » et « Faire une séance quand même » ont une porte (écran 2).

**Ce que la direction sacrifie.** Les chiffres de la semaine ne se voient pas d'emblée. Les favoris et les pas sont un toucher plus loin. La progression est invisible tant qu'on ne l'ouvre pas : peu d'envie de passer à Premium. Les listes « La séance » et les actions rares demandent un toucher de plus pendant la séance.

---

## 4. Direction 2 · Tableau de bord : « Ma semaine d'entraînement »

Fichier : `02-tableau-de-bord.html` · 8 écrans.

**Idée directrice.** Fitness s'ouvre sur la semaine : un anneau « 2 / 4 séances », puis des tuiles vivantes qui montrent chacune un chiffre vrai et ouvrent leur page.

**Pour qui, quand.** La personne régulière qui veut tout voir d'un coup : où en est sa semaine, ce qui l'attend, ce qui progresse. La meilleure hors séance, le matin ou le dimanche.

**Navigation.** En étoile : **chaque tuile est une porte**. La tuile montre déjà l'essentiel de sa page (le dernier chiffre, un mini-graphique), et un toucher l'ouvre. Grille de 2 colonnes.

**Élément vedette.** L'anneau de la semaine (« 2 / 4 séances », « Encore 2 séances ») avec Durée, Volume et Calories à côté.

**Accès à l'action la plus fréquente.** L'action flottante du cadre commun, « Commencer ». Pendant la séance, « Série faite » est **dans la tuile** de la séance, sur le tableau de bord.

**Écran principal, bloc par bloc**
1. Barre, sélecteur de semaine (F1).
2. Carte de verre « Cette semaine » : anneau 2 / 4, « Encore 2 séances », et trois chiffres : 1 h 52, 8 460 kg, ≈ 220 kcal (F7).
3. Tuile large « Séance du jour » : « Haut du corps » · « 6 exercices · 18 séries · environ 55 min » · les 3 premiers exercices · « + 3 autres » (F2, F6).
4. Grille de tuiles : « Programme » (4 jours marqués sur 7, « 3 séances »), « Historique » (« 23 séances », « Dernière : Jambes, mar. 10 nov. »), « Exercices » (« 163 exercices », 3 favoris), « Progression » (8 petites barres, Premium), « Activité » (anneau 5 480 / 8 000), « Régularité » (**N4**).
5. Note, « Mes paramètres ».
6. Action flottante « Commencer ».

**Les 8 écrans**

| N° | Titre | Heure | Ce qu'il montre | D'où l'on vient | Où l'on va |
|---|---|---|---|---|---|
| 1 | Tableau de bord | 13:20 | Blocs 1 à 3 et le haut de la grille. Action flottante « Commencer ». | Mon quotidien, widget | Défiler → 2 ; « Commencer » → 4 ; toucher la tuile de la séance → aperçu |
| 2 | Tableau de bord, suite | 13:20 | La grille complète des 6 tuiles, la note, « Mes paramètres ». Tuile « Régularité » : « 2 semaines de suite à l'objectif » (**N4**). | Écran 1, en défilant | « Programme » → 5 ; « Progression » → 6 ; « Historique » → 7 |
| 3 | Tableau de bord, séance en cours | 19:05 | L'anneau passe à 3 / 4, « Encore 1 séance », avec 1 h 58, 9 060 kg, ≈ 228 kcal (règle actuelle : la séance en cours compte déjà ; `FIT.semaineEnCours`). La tuile de la séance devient « Séance en cours » : « Développé couché (barre) » · « Série 2 sur 4 · 10 × 60 kg » · repos 0:45 avec pause · barre « 1/18 séries » · bouton « Série faite » dans la tuile. Aucune action flottante. | Retour depuis « Séance », ou réouverture de l'app | Toucher la tuile → 4 |
| 4 | Séance | 19:05 | Tout sur un écran, rangé : en-tête (chrono, « 1/18 séries », barre) ; exercice en cours, « La dernière fois », deux réglettes ; repos ; « Série faite » ; une rangée de trois actions (« Passer la série », « Passer cet exercice », « Annuler la dernière série ») ; liste « La séance » avec pastilles ; plus bas « Choisir dans la bibliothèque », « Ajouter un exercice », « Terminer la séance », « Annuler la séance ». Aucune nouveauté. `data-tab="none"` | Écran 1 ou 3 | ⓘ → fiche en feuille |
| 5 | Programme | 13:20 | « Ma semaine » en bande de 7 jours (L à D) avec le nom de la séance sous chaque jour ; « Mes séances » en 3 cartes (nom, « 6 exercices · environ 55 min », jours) ; « Nouvelle séance » ; « Séance libre » ; « Objectif » : « 4 séances / semaine ». | Écran 2, tuile « Programme » | Toucher un jour → menu à coches ; toucher une séance → éditeur actuel |
| 6 | Progression | 13:20 | Premium. « Volume par semaine » : 8 barres, la semaine en cours hachurée, sous le graphique « Semaine dernière : 4 séances · 3 h 37 · 16 845 kg » (**N6**). « Records » : A à Z, index à gauche, 4 lignes visibles (« Développé couché (barre) · +7,5 kg depuis le début · 12 séances · 57,5 × 10 »). | Écran 2, tuile « Progression » | Toucher un record → fiche |
| 7 | Historique | 13:20 | En tête, calendrier de novembre (**N5**) : 2, 3, 6, 7, 9, 10 faits ; le 5 rattrapé ; 12 aujourd'hui ; jours prévus en anneau ; « 6 séances en novembre ». Dessous, la liste de novembre (6 lignes, « Ven. 6 nov. · Haut du corps · Rattrapée »). | Écran 2, tuile « Historique » | Toucher une ligne → détail ; glisser → supprimer |
| 8 | Premier jour, compte gratuit | 13:20 | Aucun programme : carte de verre « Ton programme » ; « À remplir 0 / 4 » ; tuiles en pointillés sans chiffre ; badge Premium sur « Exercices » et « Progression ». Action flottante « Créer une séance ». **Compte gratuit.** | Première ouverture | « Créer une séance » → éditeur |

**Nouveautés (3).** N4 série de semaines (écran 2) ; N5 calendrier du mois (écran 7) ; N6 comparaison avec la semaine d'avant (écran 6).

**À adapter.** Les quatre tuiles deviennent la carte de verre. Les quatre lignes de « Programme » deviennent des tuiles avec un chiffre. « Série faite » sur l'écran principal (comme Mon quotidien). « Séance libre » dans « Programme ».

**Ce que la direction sacrifie.** L'écran d'ouverture est dense et se lit en deux écrans. La séance du jour est le deuxième bloc, pas le premier. Le soir d'une séance, on ouvre sur un bilan de semaine alors qu'on veut commencer. Six tuiles à tenir à jour : plus de risques de petits écarts de chiffres.

---

## 5. Direction 3 · Analytique : « Progression d'abord »

Fichier : `03-analytique.html` · 9 écrans.

**Idée directrice.** Fitness s'ouvre sur les progrès : volume, charges et records occupent la page, et la séance du jour tient dans un bandeau toujours présent en tête.

**Pour qui, quand.** La personne qui s'entraîne depuis des mois et que les chiffres motivent ; le compte Premium. La meilleure après une séance et pour décider d'augmenter une charge.

**Navigation.** Un **bandeau de séance** en tête de l'écran principal, puis des cartes de graphique. On **descend en profondeur** : un graphique → un exercice → une séance → une série. Les pages sans chiffres (« Programme », « Exercices ») sont en lignes, en bas.

**Élément vedette.** Le graphique « Volume par semaine » (8 semaines, semaine en cours hachurée).

**Accès à l'action la plus fréquente.** Le bouton « Commencer » est dans le bandeau de tête : un toucher, sans défiler.

**Écran principal, bloc par bloc**
1. Barre, sélecteur de semaine (F1).
2. Bandeau de verre, bas (72 points) : « Séance du jour » · « Haut du corps · environ 55 min » · bouton « Commencer » à droite.
3. « Cette semaine » : 4 tuiles (F7) et la ligne « Semaine dernière : 4 séances · 3 h 37 · 16 845 kg » (**N6**).
4. Carte « Volume par semaine » (F54, Premium).
5. « Charges » : trois lignes avec une mini-courbe (les favoris d'abord) : Développé couché (barre) 50 → 57,5 kg ; Squat (barre) 60 → 70 kg ; Développé militaire (barre) 30 → 35 kg.
6. « Records » : 3 lignes, « Tout voir ».
7. Lignes : « Programme », « Exercices », « Historique », « Activité ». Note, « Mes paramètres ».

**Les 9 écrans**

| N° | Titre | Heure | Ce qu'il montre | D'où l'on vient | Où l'on va |
|---|---|---|---|---|---|
| 1 | Page principale | 13:20 | Blocs 1 à 4. Un seul verre : le bandeau. 8 barres : 0, 10 760, 10 915, 15 145, 11 850, 16 285, 16 845, 8 460 kg. | Mon quotidien, widget | « Commencer » → 7 ; défiler → 2 ; toucher le graphique → 4 |
| 2 | Page principale, suite | 13:20 | Blocs 5 à 7. Chaque ligne de « Charges » porte sa mini-courbe et son gain (« +7,5 kg »). | Écran 1, en défilant | Ligne « Développé couché (barre) » → 3 ; « Tout voir » → 4 ; « Historique » → 5 ; « Programme » → 8 |
| 3 | Fiche : mes performances d'abord | 13:20 | Fiche « Développé couché (barre) », étoile de favori pleine. « Mes performances » en tête : courbe de la charge la plus lourde (12 séances, 50 → 57,5 kg), « Record » 57,5 × 10 · 1RM ≈ 77 kg, « Dernière séance » lun. 9 nov. · 4 séries · meilleure 57,5 × 10, « Volume » 2 300 kg, « Fréquence » 8 séances en 30 jours. Dessous : démonstration réduite, « Position de départ », « Alternatives », « Ajouter à une séance ». | Écran 2 ; un record | Démonstration, technique : en défilant |
| 4 | Progression | 13:20 | Premium. « Volume par semaine » en grand. « Par muscle », cette semaine (**N9**) : barres couchées, Pectoraux 7 séries, Quadriceps 7, Ischio-jambiers 5, Dos 3, Épaules 3, Biceps 3, Mollets 3, Triceps 2. Début de « Records » A à Z avec l'index. | Écran 1 ou 2 | Un record → 3 |
| 5 | Historique | 13:20 | Puces « Toutes 23 », « Haut du corps 12 », « Jambes 11 » (**N10**). Liste par mois : « Mar. 10 nov. · Jambes · 53 min · 15 séries · 4 240 kg », « Lun. 9 nov. · Haut du corps · 59 min · 18 séries · 4 220 kg », « Ven. 6 nov. · Haut du corps · Rattrapée »… | Écran 2 | Une ligne → 6 |
| 6 | Détail d'une séance | 13:20 | « Haut du corps » : « Date » lundi 9 novembre, « Durée » 59 min, « Volume » 4 220 kg ; séries par exercice avec l'heure (« 57,5 × 10 · 18:05 »), ⓘ par exercice ; « Supprimer la séance ». | Écran 5 | Toucher une série → « Modifier une série » |
| 7 | Séance : comparer en direct | 19:05 | En-tête (chrono 6:05, « 1/18 séries », barre). Exercice en cours, puis un tableau de ses 4 séries : série 1 « 60 × 10 » faite, à côté « la dernière fois 57,5 × 10 » ; série 2 en cours avec les deux réglettes ; séries 3 et 4 à venir. Ligne « Record : 57,5 × 10 ». Repos 0:45, « Série faite ». Actions et liste « La séance » en défilant. `data-tab="none"` | Écran 1, « Commencer » | ⓘ → fiche en feuille |
| 8 | Programme | 13:20 | « Ma semaine » avec la durée estimée de chaque jour (« Haut du corps · environ 55 min ») et, en tête, « 4 jours · environ 3 h 18 par semaine ». « Mes séances », « Nouvelle séance », « Séance libre », « Objectif » : « 4 séances / semaine ». | Écran 2 | Une séance → éditeur actuel |
| 9 | Page principale, compte gratuit | 13:20 | **Compte gratuit.** Bandeau de séance ; « Cette semaine » (4 tuiles, sans N6) ; aperçu « Séance du jour » (4 exercices, « + 2 autres ») ; **une seule** carte « La progression est dans Premium » avec « Découvrir Premium » à la place des blocs 4 à 6 ; « Dernières séances » (3 lignes) ; « 7 derniers jours » de pas (moyenne 8 323). | Mon quotidien | Offre Premium ; « Historique » |

**Nouveautés (3).** N6 comparaison avec la semaine d'avant (écran 1) ; N9 volume par groupe de muscles (écran 4) ; N10 filtre de l'historique (écran 5).

**À adapter.** La séance du jour devient un bandeau. La courbe et le record d'une fiche remontent sur l'écran principal (« Charges ») et en tête de la fiche. La durée de la semaine prévue est la somme des durées estimées. Sans Premium, les trois verrous deviennent une seule carte.

**Ce que la direction sacrifie.** En compte gratuit, la moitié de ce qui fait la direction est derrière un verrou. La séance du jour perd sa place de héros : moins évidente pour un nouveau. L'écran principal est le plus dense des cinq. Les jours sans séance, la page parle surtout du passé.

---

## 6. Direction 4 · Quotidienne : « En séance »

Fichier : `04-quotidienne.html` · 8 écrans.

**Idée directrice.** Fitness est un compagnon de salle : l'écran principal **est** la séance, exercice par exercice, et un socle en bas porte le geste du moment.

**Pour qui, quand.** Toute personne pendant sa séance : téléphone à bout de bras, une main, peu d'attention. La meilleure entre « Commencer » et la dernière série.

**Navigation.** On **balaie de côté** d'un exercice à l'autre (1 sur 6 … 6 sur 6), avant comme pendant la séance. Un **socle fixe** en bas porte l'action. Les autres pages sont rangées derrière un bouton rond « Plus », en haut à droite.

**Élément vedette.** La carte de l'exercice (nom, plan, « La dernière fois », tempo et notes) et, pendant le repos, le minuteur en grand.

**Accès à l'action la plus fréquente.** Le socle : « Commencer », puis « Série faite », toujours au même endroit, sous le pouce.

**Écran principal, bloc par bloc**
1. Barre : retour, « Fitness », bouton rond « Plus ».
2. Sélecteur de semaine (F1).
3. Ligne de titre, sans carte : « Séance du jour » · « Haut du corps » · « 6 exercices · 18 séries · environ 55 min ».
4. Carte de verre de l'exercice, que l'on balaie : « 1 sur 6 » · « Développé couché (barre) » · « 4 × 10 · 60 kg » · « repos 3:00 » · « La dernière fois : 57,5 kg × 10 » · « Tempo 2-0-1 · Omoplates serrées, pieds à plat. » (**N7**) · ⓘ. Le bord de la carte suivante dépasse à droite. Six points sous la carte.
5. Ligne mince : « 2 / 4 séances · Encore 2 séances ».
6. Socle : « Commencer ».

**Les 8 écrans**

| N° | Titre | Heure | Ce qu'il montre | D'où l'on vient | Où l'on va |
|---|---|---|---|---|---|
| 1 | Page principale | 13:20 | Les 6 blocs. Séance prévue. | Mon quotidien, widget | Balayer → exercice suivant ; « Commencer » → 2 ; « Plus » → 7 ; ⓘ → 5 |
| 2 | Séance : le repos | 19:05 | Même gabarit, sans barre d'onglets : en-tête « Haut du corps » · 6:05 · « 1/18 séries » · barre. Carte de l'exercice : « Série 2 sur 4 », « La dernière fois : 57,5 kg × 10 », deux réglettes (Répétitions 10, Charge 60 kg), pastille « 60 × 10 » de la série 1. Minuteur en grand : 0:45, anneau, pause, « − 15 s », « + 15 s » (**N2**), « Passer le repos ». Socle en deux parties : « Série faite » (large) et « La séance » (rond). `data-tab="none"` | Écran 1 | Toucher « 60 kg » → 3 ; « La séance » → 4 ; ⓘ → 5 ; balayer → exercice suivant |
| 3 | Taper la charge | 19:05 | Feuille « Charge » (**N3**) : trois propositions « 57,5 kg », « 60 kg », « 62,5 kg », pavé de chiffres, « OK ». Derrière, l'écran 2. | Écran 2, toucher le chiffre | « OK » → 2 |
| 4 | La séance | 19:05 | Feuille : les 6 exercices (en cours, à venir), pastilles des séries, toucher un exercice y saute. Dessous : « Passer la série », « Passer cet exercice », « Annuler la dernière série » ; « Ajouter un exercice », « Choisir dans la bibliothèque » (Premium) ; « Terminer la séance », « Annuler la séance ». | Écran 2 | Une pastille → « Modifier une série » ; « Terminer la séance » → 6 |
| 5 | Fiche en feuille | 19:05 | Fiche « Développé couché (barre) » ouverte par ⓘ, par-dessus la séance : démonstration animée, vues « Profil » et « 3/4 », muscles principaux et secondaires, « Position de départ », « Exécution » (3 étapes), étoile de favori, « Ajouter à ma séance », « Fermer ». Premium. | Écran 1 ou 2, ⓘ | « Fermer » → où l'on était |
| 6 | Séance terminée | 19:55 | Récapitulatif (**N1**), à la place de l'écran de choix : « Séance terminée » · « Haut du corps » ; Durée 52 min, Séries 18, Volume 4 320 kg, Calories ≈ 111 kcal ; « Nouveau record : Développé couché (barre), 60 × 10 » ; « 3 / 4 séances · Encore 1 séance » ; « Voir le détail », « Annuler la dernière série » ; bouton « Terminé ». | Dernière « Série faite », ou « Terminer la séance » | « Terminé » → page principale, état « Séance faite » ; « Voir le détail » |
| 7 | Plus | 13:20 | Feuille « Fitness » : en tête, « Cette semaine » en 4 chiffres (1 h 52, 8 460 kg, ≈ 220 kcal, 2 / 4). Puis les pages : « Programme », « Exercices » (rangée de 3 favoris), « Historique » (23), « Progression » (Premium), « Activité » (5 480 pas). Puis « Faire une autre séance » (« Jambes », « Maison, sans matériel », « Séance libre »), et « Mes paramètres ». | Écran 1, bouton « Plus » | Chaque ligne → sa page actuelle |
| 8 | Éditeur de séance, compte gratuit | 13:20 | Feuille « Haut du corps » : nom, jours (L et J cochés), puis **une ligne par exercice** (« Développé couché (barre) · 4 × 10 · 60 kg · repos 3:00 »). L'exercice touché se déplie : séries, répétitions, charge, repos, tempo, notes. « Ajouter un exercice », « Choisir dans la bibliothèque » avec badge Premium, « Retirer le dernier exercice ». **Compte gratuit.** | « Plus » → « Programme » → une séance | « OK » → « Programme » |

**Nouveautés (4).** N1 récapitulatif (écran 6) ; N2 « − 15 s / + 15 s » (écran 2) ; N3 taper la charge (écran 3) ; N7 tempo et notes (écrans 1 et 2).

**À adapter.** L'aperçu de la séance devient des cartes à balayer. Le bouton flottant devient un socle. Les actions rares et la liste vont dans une feuille. L'éditeur passe de 7 lignes par exercice à une ligne dépliable. Les quatre lignes de « Programme », les favoris et les pas vont dans « Plus ».

**Ce que la direction sacrifie.** La semaine et la progression sont un toucher plus loin. Le balayage de côté n'existe dans aucune autre mini-app : à apprendre. Les jours de repos, la page est presque vide. C'est la direction la plus éloignée du cadre commun (socle au lieu du bouton flottant, bouton « Plus »).

---

## 7. Direction 5 · Hybride intelligente : « L'écran qui suit ton moment »

Fichier : `05-hybride.html` · 9 écrans.

**Idée directrice.** L'écran garde toujours le même squelette, mais sa première carte change avec le moment : avant la séance, pendant, après, ou un jour de repos.

**Pour qui, quand.** Tout le monde, du premier jour au centième : la page dit toujours « voici la chose à faire maintenant ». La meilleure pour quelqu'un qui ouvre Fitness à des moments différents de la journée.

**Navigation.** Une page, et sous la carte une **rangée fixe de quatre raccourcis ronds** (« Programme », « Exercices », « Historique », « Progression »), visibles sans défiler, toujours au même endroit. L'action flottante du cadre commun reste, et change avec le moment.

**Élément vedette.** La « carte du moment », en verre : les neuf états de l'audit, regroupés en quatre visages.

**Accès à l'action la plus fréquente.** L'action flottante suit le moment : « Commencer » avant ; « Série faite » avec le repos à côté pendant (on valide sans quitter la page) ; rien après.

**Écran principal, bloc par bloc**
1. Barre, sélecteur de semaine (F1).
2. Carte du moment (F2) : avant = « Séance du jour » ; pendant = « Séance en cours » avec l'exercice, la série et la barre ; après = « Séance faite » ; repos = « Repos » et la prochaine séance.
3. Rangée de 4 raccourcis ronds avec leur nom.
4. « Cette semaine » : 4 tuiles (F7), « Encore 2 séances ».
5. « À remplir », seulement s'il manque une information.
6. Aperçu de la séance (avant) : 4 exercices, « + 2 autres » (F6).
7. Carte des pas, note, « Mes paramètres ».
8. Action flottante.

**Les 9 écrans**

| N° | Titre | Heure | Ce qu'il montre | D'où l'on vient | Où l'on va |
|---|---|---|---|---|---|
| 1 | Avant la séance | 13:20 | Carte « Séance du jour » · « Haut du corps » · « 6 exercices · 18 séries · environ 55 min ». Raccourcis. « Cette semaine » (1 h 52, 8 460 kg, ≈ 220 kcal, 2 / 4). Aperçu des exercices, haut de la carte des pas. Action flottante « Commencer ». | Mon quotidien, widget | « Commencer » → 3 ; raccourci « Exercices » → 7 ; « Progression » → 9 |
| 2 | Pendant la séance | 19:05 | Carte « Séance en cours » · « Haut du corps » · « Développé couché (barre) · série 2 sur 4 » · « 10 × 60 kg » · barre « 1/18 séries ». Raccourcis à la même place. Tuiles de `FIT.semaineEnCours` (1 h 58, 9 060 kg, ≈ 228 kcal, 3 / 4). Action flottante en deux parties : « Série faite » et le repos 0:45 avec pause. | Retour depuis « Séance », réouverture de l'app | Toucher la carte → 3 |
| 3 | Séance | 19:05 | En-tête (6:05, « 1/18 séries », barre). « Série 2 sur 4 » · « Développé couché (barre) » ⓘ · « La dernière fois : 57,5 kg × 10 ». Deux réglettes. Repos 0:45, pause, « − 15 s », « + 15 s » (**N2**), « Passer le repos ». « Série faite ». Deux actions visibles (« Passer la série », « Annuler la dernière série ») et « … » pour les autres. Liste « La séance » dessous. `data-tab="none"` | Écran 1 ou 2 | ⓘ → fiche en feuille ; dernière série → 4 |
| 4 | Après : séance terminée | 19:55 | Feuille de récapitulatif (**N1**) sur la page principale : mêmes lignes que `FIT.nouveau.recap` (52 min, 18 séries, 4 320 kg, ≈ 111 kcal, record 60 × 10, « 3 / 4 séances · Encore 1 séance »), « Voir le détail », « Annuler la dernière série », « Terminé ». Derrière : la carte du moment « Séance faite ». `data-tab="none"` | Écran 3 | « Terminé » → page principale, « Séance faite » |
| 5 | Un autre jour : séance rattrapée | 13:20 | Semaine dernière, jeudi 5 novembre choisi, bouton « Aujourd'hui ». Carte « Séance rattrapée » · « Haut du corps » · « Faite le vendredi 6 novembre à la place. » · « Voir le détail ». Tuiles « Semaine dernière » : 3 h 37, 16 845 kg, 4 / 4. Aucune action flottante. | Écran 1, flèche du sélecteur | « Voir le détail » → détail ; « Aujourd'hui » → 1 |
| 6 | Éditeur de séance | 13:20 | Feuille « Haut du corps » : nom, jours ; chaque exercice sur une ligne avec une poignée pour changer l'ordre et un bouton pour le retirer (**N8**) ; l'exercice ouvert montre séries, répétitions, charge, repos, tempo, notes ; suggestion de nom sous le champ (Premium) ; « Ajouter un exercice », « Choisir dans la bibliothèque ». | Raccourci « Programme » → une séance | « OK » → « Programme » (page actuelle, non dessinée) |
| 7 | Exercices, compte gratuit | 13:20 | Bibliothèque : recherche « développé », 12 résultats, 4 filtres ; chaque ligne grisée avec badge Premium ; carte « Toute la bibliothèque d'exercices » ; « Favoris », « Mes exercices », « Par muscle » en dessous. **Compte gratuit.** | Écran 1, raccourci « Exercices » | Une ligne → 8 (Premium) ou offre |
| 8 | Fiche d'exercice | 13:20 | Premium. « Développé couché (barre) » : démonstration, vues, pastilles (Musculation, Intermédiaire, Barre, Banc), muscles, « Position de départ », « Exécution », « Mes performances » (record 57,5 × 10, 1RM ≈ 77 kg), « Alternatives » (5), « Ajouter à une séance ». | Écran 7 ; favori ; record | « Ajouter à une séance » → feuille actuelle |
| 9 | Progression | 13:20 | Premium. En tête « 2 semaines de suite à l'objectif » (**N4**). « Volume par semaine » (8 barres). « Records » A à Z. | Écran 1, raccourci « Progression » | Un record → 8 |

**Nouveautés (4).** N1 récapitulatif (écran 4) ; N2 « − 15 s / + 15 s » (écran 3) ; N4 série de semaines (écran 9) ; N8 ordre et retrait dans l'éditeur (écran 6).

**À adapter.** Les quatre lignes de « Programme » deviennent quatre raccourcis sous la carte. « Série faite » sur l'écran principal. Deux actions visibles au lieu de sept. « Séance libre » dans « Programme ».

**Ce que la direction sacrifie.** L'écran a quatre visages : il faut les dessiner, les développer et les tester tous. Les raccourcis ne montrent aucun chiffre. C'est la direction qui demande le plus de travail d'intégration (états de la carte, action flottante double). Les progrès restent derrière un toucher.

---

## 8. Matrice des différences

| Axe | 1 · Minimaliste | 2 · Tableau de bord | 3 · Analytique | 4 · Quotidienne | 5 · Hybride |
|---|---|---|---|---|---|
| **Navigation** | Liste fixe de 5 pages, sur un écran sans défiler | Tuiles-portes en 2 colonnes (étoile) | Bandeau + descente en profondeur (graphique → exercice → séance) | Balayage de côté + socle + feuille « Plus » | Carte du moment + 4 raccourcis fixes |
| **Élément vedette** | Le bouton « Commencer » dans la carte | L'anneau de la semaine, 2 / 4 | Le graphique « Volume par semaine » | La carte de l'exercice et le minuteur | La carte du moment (4 visages) |
| **Accès à l'action la plus fréquente** | Bouton de 64 points dans la carte ; une série par écran | Action flottante ; « Série faite » dans la tuile | Bouton dans le bandeau de tête | Socle fixe sous le pouce | Action flottante qui change avec le moment |
| **Place de l'analyse** | Une ligne (« 2 séances sur 4 ») | Résumée dans chaque tuile | Les deux tiers de l'écran principal | Dans la carte (« La dernière fois ») et au bilan | Après la séance, et dans « Progression » |
| **Densité de l'écran principal** | Très faible : 3 blocs | Forte : 8 blocs sur 2 écrans | Très forte : 2 graphiques, 4 tuiles | Faible : une carte, gros caractères | Moyenne : 4 blocs |
| **Ce que montre l'écran pendant une séance** | Rien de plus (on est sur « Séance ») | La tuile avec « Série faite » | Le bandeau « Reprendre la séance » | L'écran principal est la séance | La carte et l'action flottante |
| **Écran « Séance »** | Une série à la fois, actions dans une feuille | Tout sur un écran, rangé | Tableau des séries comparées à la dernière fois | Carte à balayer, minuteur géant | L'actuel, simplifié (2 actions + « … ») |
| **Fin de séance** | Retour à la page principale | Écran de choix actuel | Écran de choix actuel | Récapitulatif (Nouveau) | Récapitulatif en feuille (Nouveau) |
| **Nouveautés** | 2 | 3 | 3 | 4 | 4 |
| **Écart avec le cadre commun** | Faible (pas de flottant) | Nul | Faible (héros réduit) | Fort (socle, « Plus », balayage) | Nul |

Les cinq diffèrent sur les cinq axes demandés. Deux directions seulement partagent une forme : l'action flottante (2 et 5), mais elle ne fait pas la même chose pendant la séance.

---

## 9. Cohérence avec Mon quotidien

**Ce que montre la carte aujourd'hui** (audit, section 6). Carte Fitness en **pleine largeur**, deuxième après Nutrition, toujours présente, avec **deux pages** : « Séance » (prévue : « Séance du jour », « Haut du corps », « 6 exercices · 18 séries », « Commencer », pastille « Maintenant » ; en cours : exercice, « Série 2/4 · 10 × 60 kg », repos, « Série faite » ; faite : « Faite · 18 séries », « 4 320 kg soulevés » ; repos : « Repos aujourd'hui ») et « Semaine » (« 2/4 séances », 7 ronds, « Encore 2 séances »). Sans programme : « Crée ton programme : ta séance du jour apparaîtra ici. ». La carte « Pas » est en demi-largeur et ouvre « Activité ».

**« Fitness en Medium » (mission, partie 8).** Le code n'a que deux largeurs : demi et pleine. « Medium » et « Large » ont la même largeur, seule la hauteur change. Les planches gardent donc la carte en pleine largeur, à deux pages. Rien n'est à redessiner dans Mon quotidien pour ces cinq directions.

**Règle commune aux cinq.** La carte dit **quoi** et **combien** pour aujourd'hui ; la mini-app ajoute **le détail, le temps et la gestion**. Mêmes mots (« Séance du jour », « Commencer », « Série faite », « Encore 2 séances »), même icône, même couleur, mêmes chiffres (« 18 séries », « 2 / 4 », « 4 320 kg »).

| Direction | Comment elle prolonge la carte | Ce qu'elle ne répète pas |
|---|---|---|
| 1 · Minimaliste | Même phrase et même bouton que la page « Séance » de la carte, en plus grand, avec la durée en plus | Les 7 ronds de la semaine : une seule ligne de texte |
| 2 · Tableau de bord | La page « Semaine » de la carte (ronds, « 2/4 ») devient l'anneau vedette, avec Durée, Volume et Calories que la carte n'a pas | La séance du jour n'est pas le premier bloc : la carte l'a déjà dite |
| 3 · Analytique | La carte donne aujourd'hui, la mini-app donne les 8 semaines : aucun chiffre en double | La séance : un simple bandeau |
| 4 · Quotidienne | Le socle « Série faite » fait exactement ce que fait le bouton de la carte ; le repos est le même | Les chiffres de la semaine, rangés dans « Plus » |
| 5 · Hybride | La carte du moment a les mêmes quatre états que la carte de Mon quotidien, avec les mêmes mots : la suite la plus directe | Les ronds de la semaine : remplacés par les 4 tuiles |

**Trois points à faire trancher par le PDG (à reprendre dans la planche de comparaison).**
1. La carte de Mon quotidien s'appelle « Séance », « Séance du jour » ou « Sport » selon l'état, avec une autre icône que la mini-app. Proposition : « Fitness » et l'haltère partout.
2. « Commencer » dans Mon quotidien lance la séance et reste sur l'accueil ; dans Fitness il ouvre « Séance » (problème 22). Proposition : garder les deux, c'est voulu (l'accueil sert à valider sans entrer).
3. Trois comptes différents des séances (problème 15) : « 2 / 4 » à 13:20 et « 3 / 4 » à 19:55 partout ; mais à 19:05 la mini-app dit déjà « 3 / 4 » (la séance en cours compte dès sa première série) quand la carte de Mon quotidien dit encore « 2/4 ». Les planches montrent le chiffre du code (`FIT.semaineEnCours`) et le disent en légende. Proposition à trancher : compter partout de la même façon.

**Autres mini-apps.** Planning montre les séances prévues sans heure (F65) ; Nutrition partage l'objectif et le poids (F67). Aucune direction n'y touche.

---

## 10. Rien n'est retiré : où va chaque fonction

Un nombre = l'écran de la planche de cette direction. « = » = la fonction reste à sa place actuelle et n'est pas dessinée sur cette planche ; la table de fin doit dire où (colonne « Si = »). Les dessinateurs recopient ces places dans `PL.mapTable`, avec 6 à 12 mots par ligne.

| Fonction | D1 | D2 | D3 | D4 | D5 | Si « = » : où elle reste |
|---|---|---|---|---|---|---|
| F1 Sélecteur de semaine | 1, 7, 8 | 1, 3, 8 | 1, 9 | 1 | 1, 2, 5 | |
| F2 Séance du jour, 9 états | 1, 7, 8 | 1, 3, 8 | 1, 9 | 1, 2 | 1, 2, 5 | |
| F3 Action principale | 1, 8 | 1, 8 | 1, 9 | 1 | 1, 2 | |
| F4 Rattraper | = | 7 | 5 | = | 5 | Même bouton que « Commencer », un jour manqué ; pastille « Rattrapée » dans l'historique |
| F5 « Faire une séance quand même » | 2 | = | = | 7 | = | Menu de la carte de la séance, un jour de repos |
| F6 Aperçu de la séance | 2 | 1 | 9 | 1 | 1 | |
| F7 Totaux de la semaine | 1, 7 | 1 | 1, 9 | 7 | 1, 2, 5 | |
| F8 « À remplir » | 8 | 8 | = | = | = | Sous la première carte, tant qu'il manque une information |
| F9 Favoris | 6 | 2 | 2 | 7 | 7 | |
| F10 Carte des pas | 1 | 2 | 9 | 7 | 1 | |
| F11 Fermeture d'une séance oubliée | = | = | = | = | = | Sans écran, automatique après 3 h |
| F12 Supprimer une séance faite | 7 | 7 | 6 | = | = | Menu « … » de la séance faite, détail, historique |
| F13 Démarrer une séance | 1, 2 | 1 | 1 | 1 | 1 | |
| F14 « Séance libre » | 2 | 5 | 8 | 7 | = | D5 : dans « Programme », sous « Mes séances » |
| F15 En-tête de la séance | 3 | 4 | 7 | 2 | 3 | |
| F16 Carte de l'exercice en cours | 3 | 4 | 7 | 2 | 3 | |
| F17 « La dernière fois » | 3 | 4 | 7 | 1, 2 | 3 | |
| F18 Régler répétitions et charge | 3 | 4 | 7 | 2, 3 | 3 | |
| F19 « Série faite » | 3 | 3, 4 | 7 | 2 | 2, 3 | |
| F20 Repos minuté | 3 | 3, 4 | 7 | 2 | 2, 3 | |
| F21 Alerte de fin de repos | = | = | = | = | = | Notification, proposée au premier repos |
| F22 « Passer la série » | 4 | 4 | 7 | 4 | 3 | |
| F23 « Annuler la dernière série » | 4 | 4 | 7 | 4, 6 | 3, 4 | |
| F24 « Passer cet exercice » | 4 | 4 | 7 | 4 | 3 | D5 : derrière « … » |
| F25 Liste « La séance » | 4 | 4 | 7 | 4 | 3 | |
| F26 Modifier une série faite | 4 | 4 | 6 | 4 | 3 | |
| F27 Exercice de la bibliothèque en séance | 4 | 4 | 7 | 4 | 3 | D3, D5 : sous la liste, en défilant |
| F28 Exercice écrit à la main en séance | 4 | 4 | 7 | 4 | 3 | idem |
| F29 « Terminer la séance » | 4 | 4 | 7 | 4 | 3 | D5 : derrière « … » |
| F30 « Annuler la séance » | 4 | 4 | 7 | 4 | 3 | D5 : derrière « … » |
| F31 Fin automatique | 7 | = | = | 6 | 4 | Écran de choix actuel, inchangé |
| F32 « Ma semaine » | 5 | 5 | 8 | = | = | Page « Programme » actuelle |
| F33 « Mes séances » | 5 | 5 | 8 | = | = | Page « Programme » actuelle |
| F34 Objectif par semaine | 5 | 5 | 8 | = | = | Page « Programme » actuelle |
| F35 Éditeur de séance | = | = | = | 8 | 6 | Feuille actuelle, ouverte depuis « Programme » |
| F36 Ajouter un exercice au programme | = | = | = | 8 | 6 | Éditeur actuel |
| F37 Suggestions de nom | = | = | = | = | 6 | Éditeur actuel, sous le champ du nom |
| F38 Durée estimée | 1, 2, 5 | 1, 5 | 1, 8 | 1 | 1 | |
| F39 Bibliothèque | 6 | 2 | 2 | 7 | 7 | D2, D3, D4 : la porte seulement ; page actuelle |
| F40 Recherche | 6 | = | = | = | 7 | Page « Exercices » actuelle |
| F41 Filtres | 6 | = | = | = | 7 | Page « Exercices » actuelle |
| F42 Raccourcis de la bibliothèque | 6 | = | = | = | 7 | Page « Exercices » actuelle |
| F43 Favoris (étoile, glissement) | 6 | = | 3 | 5 | 7 | Glissement d'une ligne de « Exercices », étoile de la fiche |
| F44 « Mes exercices » | 6 | = | = | = | 7 | Page « Exercices » actuelle |
| F45 Démonstration | = | = | 3 | 5 | 8 | Fiche actuelle, ouverte par ⓘ |
| F46 Identité de l'exercice | = | = | 3 | 5 | 8 | Fiche actuelle |
| F47 Technique | = | = | 3 | 5 | 8 | Fiche actuelle |
| F48 « Mes performances » | = | = | 2, 3 | = | 8 | Fiche actuelle |
| F49 « Alternatives » | = | = | 3 | = | 8 | Fiche actuelle |
| F50 Ajouter l'exercice à une séance | = | = | 3 | 5 | 8 | Fiche actuelle |
| F51 Fiche par-dessus l'écran | 2, 3 | 4 | 7 | 5 | 3 | |
| F52 Liste des séances faites | = | 7 | 5, 9 | = | = | Page « Historique » actuelle |
| F53 Détail d'une séance | = | = | 6 | = | = | Page actuelle, ouverte par « Voir le détail » |
| F54 « Volume par semaine » | = | 2, 6 | 1, 4 | = | 9 | Page « Progression » actuelle |
| F55 « Records » | = | 6 | 2, 4 | = | 9 | Page « Progression » actuelle |
| F56 Page « Activité » | = | = | 9 | = | = | Page actuelle, ouverte par la ligne ou la carte des pas |
| F57 « Mes paramètres » | 1 | 2 | 2 | 7 | 1 | |
| F58 Unités kg ou lb | = | = | = | = | = | Réglage général de l'app |
| F59 Carte de Mon quotidien, « Séance » | = | = | = | = | = | Mon quotidien, inchangée |
| F60 Carte de Mon quotidien, « Semaine » | = | = | = | = | = | Mon quotidien, inchangée |
| F61 Carte « Pas » de Mon quotidien | = | = | = | = | = | Mon quotidien, inchangée |
| F62 Activité en direct | = | = | = | = | = | Écran verrouillé et Dynamic Island, inchangée |
| F63 Widgets Fitness | = | = | = | = | = | 9 widgets, inchangés |
| F64 Rappels et encouragements | = | = | = | = | = | Réglés dans « Rappels » |
| F65 Séances dans l'agenda de Planning | = | = | = | = | = | Planning, inchangé |
| F66 Données Fitness dans Créer | = | = | = | = | = | Créer, inchangé |
| F67 Objectif partagé avec Nutrition | = | = | = | = | = | « Mes paramètres » › « Ton objectif » |
| F68 Pastille Fitness de l'accueil | = | = | = | = | = | Accueil, inchangée |

Si un dessinateur ne dessine pas une fonction là où cette table l'annonce, il la passe en « = » avec le lieu, ou il l'ajoute à l'écran : il ne la laisse jamais sans place.

### Les fonctions difficiles

- **F31, fin automatique.** Aujourd'hui la page passe à l'écran de choix. Les directions 1, 4 et 5 changent ce qui suit la dernière série (page principale ou récapitulatif). L'écran de choix reste accessible : il devient « Faire une autre séance ». À dire dans la légende.
- **F14, « Séance libre ».** Elle n'a aujourd'hui aucun accès direct. Chaque direction lui donne une porte ; aucune ne la met sur l'écran principal.
- **F4 et F5, rattrapage et jour de repos.** Ils dépendent du jour : une planche ne peut pas tout montrer. La direction 5 dessine le rattrapage (écran 5) ; les autres le disent en légende avec les textes exacts de `FIT.etats`.
- **F2, les neuf états.** Chaque planche en dessine au moins trois (prévue, en cours ou faite, vide ou autre jour) et cite les autres dans la case de texte, avec les libellés de `FIT.etats`.
- **F8, « À remplir ».** Le compte d'exemple est complet : la section n'apparaît que sur les écrans « Premier jour » (directions 1 et 2).
- **F9, favoris.** Le bloc quitte l'écran principal dans les directions 1, 4 et 5. Il reste à un toucher.
- **F17, F27, F37, F45 à F51, F54, F55 : Premium.** La frontière ne bouge pas. Un écran en compte gratuit par planche montre le badge ou la carte verrou.
- **F35 à F37, l'éditeur.** Il n'est dessiné que dans les directions 4 et 5 ; ailleurs il reste tel quel.
- **F11, F21, F58, F59 à F68.** Sans écran dans la mini-app : « = » dans les cinq tables, avec le lieu.
- **F12, supprimer une séance.** Quatre gestes existent (menu, appui long, glissement, bouton). Chaque planche en montre un et cite les autres.

---

## 11. Pour les dessinateurs : rappels propres à ce sujet

1. Clé `data-c="fit"` sur `main` et sur chaque téléphone. Pas de `pl-past` : Fitness autorise le futur.
2. `data-tab="none"` sur l'écran « Séance » et sur toute feuille. `data-time` : 13:20, 19:05 ou 19:55, dit en légende quand ce n'est pas 13:20.
3. Un seul verre par page : la carte vedette de la direction. Un seul bouton plein par écran.
4. Tous les textes entre « » de ce document viennent de l'audit ou de `fitness.js` : ne pas les reformuler.
5. Préfixes CSS : `fit1-` … `fit5-`. Ne pas créer `fitness.css` chacun de son côté : une pièce utile à plusieurs planches se signale dans le rapport.
6. Limites à redire dans le rapport : maquettes en Inter, grandes tailles de texte et mode sombre non dessinés, libellés longs des 6 autres langues non vérifiés (« Rattraper « Haut du corps » d'hier » doit tenir dans le bouton), écran de 5,8 pouces non vérifié pour « Séance ».
