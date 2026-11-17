# Nutrition : les cinq directions (document de conception)

Écrit le 2026-11-17. Sujet 1 de la refonte UX/UI des mini-apps (`../MISSION.md`, partie A). Ce document sert aux cinq dessinateurs : chacun réalise une planche (`01-minimaliste.html` à `05-hybride.html`) d'après sa section. **Conception seulement : aucune ligne de l'app ne change.**

À lire avant de dessiner : `../base/GUIDE-PLANCHES.md` (format, pièces, contrôle), `../audit/01-nutrition.md` (la vérité sur ce qui existe : écrans E1 à E24, fonctions F1 à F64, problèmes 1 à 23), `nutrition.js` (la liste `FONCTIONS` et les données `NUT`, à ne jamais recopier ni changer dans une planche).

## 0. Règles communes aux cinq planches

1. **Style** : Cristal « Équilibrée », thème `t-saphir`, `data-c="nut"`. Anneau des calories orange (`nut`), protéines rouge (`prot`), glucides jaune (`gluc`), lipides bleu (`lip`). Une seule carte de verre dans la page (le héros), une seule action principale, une seule couleur d'action. Rien ici ne touche à la création de widgets : C1 « Atelier » ne sert pas dans ce sujet.
2. **Journée** : jeudi 12 novembre 2026, 13 h 20. Deux autres moments permis, à dire en légende : 08:10 (`NUT.matin`) et 19:05 (`NUT.soir`). Les téléphones portent `pl-past` (journal : pas de jour futur).
3. **Compte montré : gratuit** (`NUT.compte`). Les verrous Premium se voient là où ils sont dans l'app. Une vue Premium peut être montrée quand elle est le sujet de l'écran : la légende le dit (« vue Premium »).
4. **Mêmes chiffres partout** : 1 078 kcal mangées, 1 122 restantes, objectif 2 200 ; protéines 68 / 140 g, glucides 121 / 250 g, lipides 34 / 70 g ; Déjeuner 420 kcal (3 aliments), Dîner 658 kcal (3 aliments), Souper et Collation « Rien noté ».
5. **Mêmes mots que l'app** : « kcal restantes », « kcal en trop », « kcal mangées », « Scanner », « Rechercher », « Ajouter un aliment », « Repas », « Rien noté », « Tous les nutriments », « Calories de la semaine », « Historique », « Mes repas », « Mes aliments », « Mes paramètres », « Enregistrer ce repas », « Ajouter au journal », « Ajouter à ma journée ». Quatre repas fixes : Déjeuner, Dîner, Souper, Collation.
6. **Jamais de zéro inventé** : « — », « Rien noté », « Non disponible », « partiel », « ≥ », « ≈ » et la fourchette d'une estimation gardent leur place. Une photo de plat reste une estimation.
7. **Sans caméra** (simulateur, certains appareils) : le bouton de scan disparaît et « Ajouter un aliment » devient le bouton principal. Chaque direction dit en légende ce que devient son action.
8. **Mentions** : la note « Valeurs indicatives, pas un avis médical. Aliments emballés : Open Food Facts (licence ODbL). » reste au bas de la page principale. « Mes paramètres » reste le dernier élément.
9. **Trois étiquettes** : « Existe », « À adapter » (existe ailleurs ou sous une autre forme), « Nouveau » (n'est pas dans l'audit). Une amélioration qui n'est pas dessinée se dit dans la case de texte, sans jeton.
10. **Répartition des écrans existants entre les planches** (pour que chacun soit dessiné au moins une fois, sans cinq copies du même) :

| Écran existant | Planche qui le dessine |
|---|---|
| Page d'un repas remplie (« Dîner ») | 1 |
| Page d'un repas vide avec les reprises (« Souper ») | 5 |
| Recherche « Ajouter un aliment » | 1 (feuille « Ajouter »), 3 (recherche avec filtres), 4 (saisie en bas) |
| Feuille de quantité | 1 |
| Scanner, caméra | 4 (à 19:05) |
| Récapitulatif d'un scan | 2 (code-barres), 4 (photo) |
| Scanner : « Produit introuvable » et ses sorties | 5 |
| Modifier un aliment noté | 4 |
| « Nutriments » | 2 (vue Premium), 3 |
| « Idées » | 5 |
| « Historique » | 1 (compte gratuit), 3 (découpé en onglets), 5 (page « Bilan ») |
| Poids et objectif de poids | 2, 3, 5 |
| « Mes repas », « Mes aliments », favoris | 2 et 5 (« Ma bibliothèque »), 4 (« Mes repas ») |
| « Mes paramètres » | 1 (en chapitres) |
| « Tes besoins par jour » et l'éditeur d'une cible | 3 (la liste), 5 (l'éditeur) |
| Première ouverture (« À remplir ») | 1 |
| Accès à la caméra, « Aliment perso », « Rappels », feuille d'un repas enregistré, offre Premium | aucune : pages inchangées, citées « = » dans la table de fin |

### Données d'exemple (`nutrition.js`, objet `NUT`)

- **La personne** : homme, 24 ans, 182 cm, 71,6 kg, objectif « Perte de poids », activité « Modérée (4–5 séances) » (elle suit ses 4 séances de Fitness). Dépense 2 695 kcal par jour ; plan : 68 kg pour le 7 janvier 2027, soit 8 semaines, −0,45 kg par semaine, **2 200 kcal par jour** (« Calculé d'après ton plan »). Plan commencé le 15 octobre à 73,4 kg : 1,8 kg perdus sur 5,4 (33 %).
- **Cibles** : calories « Calculé » ; protéines 140 g, glucides 250 g, lipides 70 g « Personnalisé » (« Recommandé : 129 g », « 268 g », « 68 g »). Les règles du code ne donnent pas 140 / 250 / 70 pour 2 200 kcal : ces trois valeurs sont donc montrées comme personnalisées. Fibres 31 g, sucres 55 g, gras saturés 24 g, sodium 2 300 mg.
- **Repas du jour** : Déjeuner (07:45) Pain de blé entier 70 g, Beurre d'arachide 15 g, Yogourt grec à la vanille 175 g. Dîner (12:35) Poulet grillé 120 g, Riz basmati cuit 200 g, Brocoli à l'huile d'olive 180 g (658 kcal · P 44 · G 69 · L 22).
- **Exemple d'ajout** : Yogourt grec nature, 175 g, 128 kcal, dans « Collation » ; « Après ajout, il te restera 994 kcal. »
- **Semaine civile** : lundi 2 140, mardi 2 310, mercredi 1 980, jeudi 1 078 (en cours) ; « Moyenne 1 877 kcal · 3 jours sur 4 dans l'objectif ». Semaine dernière : 2 191 kcal en moyenne, 5 jours sur 7.
- **7 derniers jours** (Premium) : moyenne 2 041 kcal, « 5 jours sur 7 à moins de 10 % de ton objectif », protéines 123 g, glucides 242 g, lipides 64 g, répartition 24 / 48 / 28 %. **30 jours** : 2 172 kcal, 23 jours sur 28, 131 / 256 / 68 g. Série de suivi : 23 jours.
- **Poids** : 71,6 kg, −0,5 kg en 7 jours, −1,8 kg en 30 jours, cible 68 kg.
- **Bibliothèque** : 3 favoris (Yogourt grec nature, Banane, Amandes), 3 repas enregistrés (« Déjeuner habituel » 420 kcal, « Bol poulet et riz » 658 kcal, « Pâtes du dimanche » 689 kcal), 2 aliments perso (« Smoothie protéiné maison », « Barre maison avoine et dattes »).
- **Scans** : code-barres à 13:20, « Barre tendre avoine et miel », 35 g, 140 kcal, étiquette « Open Food Facts ». Photo à 19:05 pour le souper : Saumon grillé 140 g, Riz basmati cuit 150 g (« Ton habitude »), Haricots verts 100 g, « Huile de cuisson ? » à confirmer, total « ≈ 440–600 kcal ». « Encore 3 analyses de plat gratuites ».
- **Nouveautés** (seulement sous `NUT.nouveau`) : eau 1,25 L sur 2 L (5 verres sur 8) ; journal des objectifs (2 729 → 2 228 → 2 200 kcal) ; constats écrits ; comparaison avec la semaine dernière.

**Trois écarts voulus avec les planches Cristal** (le code de l'app fait foi ; à confirmer par le Chef) :

| Donnée | Planche Cristal du 15 novembre | Ici | Pourquoi |
|---|---|---|---|
| Moyenne « 7 jours » | 2 202 kcal, « 5 jours sur 6 » | 2 041 kcal, « 5 jours sur 7 » | Le code compte le jour en cours comme un jour noté (`NutritionMath.stats`, carte « Calories · 7 jours »). 2 202 est la moyenne des 6 jours complets. |
| « Prochain repas » à 13:20 | « souper, environ 700 kcal » | « souper, environ 1 122 kcal » | Le code donne tout le reste au seul repas principal qui n'est pas noté (`nextMealBudget`). |
| Cibles de « Nutriments » | fibres 30 g, sucres 50 g, gras saturés 20 g, fer 14 mg | 31 g, 55 g, 24 g, 8 mg | Règles du code pour 2 200 kcal et un homme de 24 ans. |

## 1. Ce que la personne vient faire

Classé par fréquence, d'après l'audit (sections 1, 3 et 4).

| Rang | Besoin | Fréquence | Fonctions en jeu | Aujourd'hui |
|---|---|---|---|---|
| 1 | **Noter ce qu'elle vient de manger**, vite : code-barres, photo du plat, recherche, reprise d'un repas | 3 à 5 fois par jour | F6 à F26, F32, F33 | Deux boutons en tête ; le scan par photo n'a pas d'entrée à lui |
| 2 | **Savoir ce qu'il reste** avant de choisir le repas suivant : calories, protéines, glucides, lipides | 3 à 5 fois par jour | F3, F4, F39, F40 | L'anneau dit le reste ; le « mangé / objectif » n'est pas sur la page |
| 3 | **Voir et corriger ses repas du jour** : quantité, repas, suppression | 1 à 3 fois par jour | F27 à F31 | Bien placé ; suppression sans retour |
| 4 | **Reprendre un repas habituel** : repas enregistré, repas précédent, favori | 1 fois par jour chez les réguliers | F14, F31 à F35, F61 | Favoris cachés ; reprises au bas de la page d'un repas |
| 5 | **Vérifier sa semaine** : jours dans l'objectif, moyenne | 1 à 3 fois par semaine | F41, F59 | Sous le premier écran ; deux définitions de la semaine |
| 6 | **Comprendre sur la durée** : historique, répartition, nutriments, poids | 1 fois par semaine ou par mois (surtout Premium) | F37, F38, F42 à F47 | En bas de page ; trois segments verrouillés sans signe |
| 7 | **Régler son objectif** : besoins, poids cible, plan, rappel | Au début, puis à chaque changement | F5, F48 à F58 | Quatre accès au même formulaire ; une très longue feuille |
| 8 | **Tenir sa bibliothèque** : aliments perso, repas enregistrés, favoris | Rare | F13, F34 à F36, F63 | Dispersée ; un repas enregistré ne se modifie pas |

### Les problèmes d'UX que la refonte doit résoudre

Numéros de l'audit (section 8). Toutes les directions répondent aux problèmes 1, 2, 3, 5, 9 et 17 ; elles diffèrent sur les autres.

| Problème (n° de l'audit) | Réponse commune ou réponses selon la direction |
|---|---|
| 1. Le « mangé / objectif » n'est pas sur la page | Commune : « 1 078 mangées sur 2 200 kcal » à côté du reste. « À adapter ». |
| 2. Le scan par photo n'a pas d'entrée | Commune : deux entrées libellées, « Code-barres » et « Photo du plat » (ou « Photo »), qui ouvrent le même scanner. « À adapter ». |
| 3. Annuler un scan demande deux fermetures | Commune : le scanner s'ouvre seul ; la croix revient à la page. « À adapter ». |
| 4. Quatre accès au même réglage pour un compte neuf | Directions 1 et 5 : une seule carte « À remplir » pour les deux objectifs, la carte conseil se tait tant qu'elle est là. |
| 5. Deux blocs sans titre | Commune : chaque bloc a un titre. |
| 6. Historique, « Mes repas », réglages sous l'écran ; « Idées » conditionnelle | 1 : page « Tout Nutrition ». 2 : tuiles. 3 : onglets. 4 : dans le repas à venir. 5 : carte « Maintenant » et deux portes. |
| 7. La semaine montrée trois fois, deux définitions | Commune : les deux mots sont écrits, « Cette semaine » (lundi à dimanche) et « 7 derniers jours ». Aucun calcul ne change. |
| 8. Deux règles pour « objectif atteint » | À trancher par le PDG à l'étape de comparaison (question). Les planches gardent les deux textes actuels. |
| 9. Le sélecteur ne montre pas les jours réussis | Commune : jour noté et dans l'objectif = repère plein avec coche ; jour noté hors objectif = anneau ; rien = pointillés (états existants de `WeekDayMark`). « À adapter ». |
| 10. Favoris cachés | 2 et 5 : « Ma bibliothèque » avec la liste des favoris. Recherche : une étoile sur les favoris. « À adapter ». |
| 11. Série de suivi et prochain repas absents de la mini-app | 2 : tuile « Série de suivi ». 3 : tuile de l'onglet « Semaine ». 4 et 5 : « Prochain repas » en vedette. « À adapter ». |
| 12. Le poids est coupé en deux | 2, 3 et 5 : une page « Poids et objectif » (courbe, cible, plan, « Ajouter une pesée »). « À adapter ». |
| 13. « Mes paramètres » est une très longue feuille | 1 et 5 : la feuille en chapitres repliés, chacun avec son résumé. « À adapter ». |
| 14 et 15. Suppressions sans retour ; repas enregistré non modifiable | 2 : « Renommer » un repas enregistré. 5 : « Modifier ». « Nouveau ». L'annulation d'une suppression est proposée en texte (case de texte), pas dessinée. |
| 18. Segments verrouillés sans signe | 1, 3 et 5 : cadenas sur chaque période Premium avant de toucher. « À adapter ». |
| 21. L'objectif n'est pas daté | 3 : « Évolution des objectifs ». 5 : « Objectif depuis le 5 nov. ». « Nouveau ». |
| 22. L'Historique ouvre une copie de la page | 3 et 5 : toucher un jour replace la page principale sur ce jour. « À adapter ». |
| 19, 23 (couleurs, second tableau de bord côté Créer) | Hors des planches de direction : notés pour la comparaison. |

## 2. Les cinq directions

Les cinq approches suggérées par le PDG ont toutes un sens pour Nutrition : le sujet a un geste quotidien (noter), un chiffre vedette (le reste), des données sur la durée (historique, poids) et beaucoup d'indicateurs. Aucune n'est remplacée. Chacune est adaptée au sujet et reçoit un sous-titre qui dit son parti pris.

---

### Direction 1 · Minimaliste — « Un chiffre, un geste »

Fichier : `01-minimaliste.html`. 8 écrans.

- **Idée directrice** : en ouvrant Nutrition, on lit un seul chiffre (ce qu'il reste) et on a un seul geste (« Ajouter ») ; tout le reste est rangé dans une page « Tout Nutrition ».
- **Pour qui, à quel moment** : la personne qui note vite, debout, entre deux cours, et qui ne veut pas d'analyse. La meilleure pour un nouvel utilisateur et pour un compte gratuit.
- **Navigation** : une page qui tient sans défiler ; un bouton « Ajouter » ; une ligne « Tout Nutrition » qui mène à une page d'index titrée. Deux niveaux, jamais plus.
- **Élément vedette** : le grand chiffre « 1 122 kcal restantes » (figure de 54, comme `MiniHero`), avec une seule barre fine et la ligne « 1 078 mangées sur 2 200 kcal ».
- **Action la plus fréquente** : un seul bouton plein « Ajouter » sous le héros (pas d'action flottante). Il ouvre une feuille qui réunit tout : champ de recherche, « Code-barres », « Photo du plat », récents et favoris.

**Écran principal, bloc par bloc**
1. Sélecteur de semaine (verre), jeudi 12 choisi ; lundi, mardi, mercredi avec la coche « dans l'objectif ».
2. Héros (verre) : « AUJOURD'HUI » ; « 1 122 » « kcal restantes » ; barre fine à 49 % ; « 1 078 mangées sur 2 200 kcal » ; trois jauges serrées « Protéines 68 / 140 g », « Glucides 121 / 250 g », « Lipides 34 / 70 g ».
3. Bouton plein « Ajouter ».
4. « Repas » (à droite du titre : « 1 078 kcal ») : Déjeuner « 3 aliments » 420 kcal ; Dîner « 3 aliments » 658 kcal ; Souper « Rien noté » ; Collation « Rien noté » ; un « + » par ligne.
5. Ligne « Tout Nutrition » (détail : « Semaine, historique, nutriments, mes repas, réglages »).

**Les 8 écrans de la planche**

| N° | Titre | Ce qu'il montre | D'où l'on vient | Où l'on va |
|---|---|---|---|---|
| 1 | Page principale | Les 5 blocs ci-dessus, à 13:20. Rien sous l'écran. | Carte Nutrition de Mon quotidien, widget | 2 (« Ajouter »), 4 (ligne « Dîner »), 5 (« Tout Nutrition ») |
| 2 | Feuille « Ajouter » | La recherche existante, rangée autrement : champ « Rechercher un aliment » ; deux boutons « Code-barres » et « Photo du plat » (sous le second : « Encore 3 analyses de plat gratuites ») ; pastilles « Pour toi », « Fruits », « Légumes »… ; « Suggestions » : Yogourt grec nature (étoile), Banane (étoile), Poulet grillé, Riz basmati cuit, chacun avec « kcal / 100 g · P · G · L » ; lien « Aliment perso » ; section « Mes repas ». « Fermer » en haut. `data-tab="none"`. | 1 (bouton « Ajouter » ou un « + ») | 3 (toucher « Yogourt grec nature ») ; scanner inchangé (non dessiné) |
| 3 | Feuille de quantité | « Yogourt grec nature » ; « Pour 100 g : 73 kcal · protéines 10,0 g · glucides 4,0 g · lipides 2,0 g » ; Quantité 175 g ; « ½ portion », « 1 portion » (choisie), « 2 portions », « 100 g » ; Repas « Collation » ; « Après ajout, il te restera 994 kcal. » ; « Apport » : 128 kcal, 17,5 g, 7,0 g, 3,5 g ; « Tous les nutriments » avec le badge Premium ; « Enregistrer ». | 2 | 1 (le chiffre passe à 994) |
| 4 | « Dîner » | Totaux 658 kcal · 44 g · 69 g · 22 g ; « Aliments » : Poulet grillé « 120 g · P 36 · G 0 · L 5 » 198 kcal ; Riz basmati cuit « 200 g · P 5 · G 56 · L 1 » 260 kcal ; Brocoli à l'huile d'olive « 180 g · P 3 · G 13 · L 16 » 200 kcal ; « Ajouter un aliment » ; « Reprendre un dîner précédent » : « Mer. 11 nov. » Saumon, Quinoa, Haricots verts 702 kcal ; « Mar. 10 nov. » Pâtes, Sauce tomate, Fromage 689 kcal ; « Enregistrer ce repas ». | 1 | Feuille d'un aliment noté (inchangée), 2 |
| 5 | « Tout Nutrition » | Trois groupes titrés. « Suivre » : carte « Calories de la semaine » (7 barres, ligne d'objectif, « Moyenne 1 877 kcal · 3 jours sur 4 dans l'objectif »), lignes « Historique » (« Moyennes, tendances et poids »), « Tous les nutriments » (badge Premium), « Idées » (« Il te reste environ 1 122 kcal »). « Ma bibliothèque » : « Mes repas » 3, « Mes aliments » 2. « Réglages » : « Mes paramètres ». Puis la note des sources. | 1 | 6, 7, pages inchangées |
| 6 | « Historique », compte gratuit | Périodes « Aujourd'hui » (choisie), « Hier », puis « 7 jours », « 30 jours », « Période » avec un cadenas chacune. « Bilan » : Calories 1 078 kcal (« objectif 2 200 »), Protéines 68 g, Glucides 121 g, Lipides 34 g. « Répartition des calories » : 26 % · 45 % · 29 %. Sous la flottaison, en légende : la carte « L'historique détaillé est dans Premium » quand on touche une période verrouillée. | 5 | Offre Premium (inchangée) |
| 7 | « Mes paramètres », en chapitres | La même feuille, repliée en 5 lignes avec leur résumé : « Ton objectif » (« Perte de poids · 68 kg pour le 7 janv. ») ; « Toi » (« 24 ans · 182 cm · 71,6 kg ») ; « Ton niveau d'activité » (« Modérée (4–5 séances) ») ; « Tes besoins par jour » (« 2 200 kcal · 140 g · 250 g · 70 g ») ; « Rappel des repas » (« 20:00 »). Note : « Les mêmes réponses que dans « Mes informations ». » `o.full`. | 5 | Chaque chapitre ouvre son bloc actuel (inchangé) |
| 8 | Première ouverture | Compte neuf à 13:20 : héros « 0 » « kcal mangées », jauges sans objectif ; « À remplir » « 0 / 2 » en une seule carte à deux lignes (« Objectif calorique », « Objectifs de macros ») et un seul bouton « Calculer mes besoins » ; bouton « Ajouter » ; « Repas » : quatre fois « Rien noté ». | Premier lancement | Formulaire « Nutrition » (inchangé) |

- **Nouveautés** : aucune. C'est le parti pris : tout existe déjà, seule l'organisation change. L'hydratation et l'évolution des objectifs sont laissées de côté, et la planche le dit.
- **Ce que la direction sacrifie** : scanner demande deux touchers au lieu d'un ; la semaine n'est plus sur la page ; « Idées » et l'historique sont à deux touchers ; la page ajoute peu à la carte de Mon quotidien (anneau, macros, repas) ; aucune réponse à l'hydratation ni à l'évolution des objectifs.

---

### Direction 2 · Tableau de bord — « Le bilan du jour en tuiles »

Fichier : `02-tableau-de-bord.html`. 6 écrans.

- **Idée directrice** : toute la journée sur un tableau de tuiles : chaque question (calories, macros, repas, semaine, poids, nutriments) a sa tuile avec son chiffre, et chaque tuile ouvre sa page.
- **Pour qui, à quel moment** : la personne déjà engagée (objectif de poids, Premium ou proche de l'être) qui veut tout voir d'un coup d'œil, le soir ou au moment de faire le point.
- **Navigation** : en étoile. La page est une grille ; une tuile = une porte vers une page existante. Pas d'onglet, pas de liste de liens.
- **Élément vedette** : le bilan écrit comme une soustraction, à côté de l'anneau : « Objectif 2 200 », « Mangé 1 078 », « Reste 1 122 ».
- **Action la plus fréquente** : trois boutons directs en tête, sous le héros : « Code-barres » (plein), « Photo » et « Rechercher » (teintés). Un toucher pour chaque façon d'ajouter.

**Écran principal, bloc par bloc**
1. Sélecteur de semaine (verre).
2. Héros (verre) : anneau à 49 % « 1 122 kcal restantes » ; à droite trois lignes « Objectif 2 200 kcal », « Mangé 1 078 kcal », « Reste 1 122 kcal ».
3. Trois boutons : « Code-barres », « Photo », « Rechercher ».
4. Trois tuiles de macros : « Protéines » 68 / 140 g, « reste 72 g » ; « Glucides » 121 / 250 g, « reste 129 g » ; « Lipides » 34 / 70 g, « reste 36 g ». Chacune avec sa barre à sa couleur.
5. Bande « Repas » en quatre cases : Déjeuner 420, Dîner 658, Souper « + », Collation « + ».
6. (En défilant) six tuiles par deux : « Semaine » (7 mini-barres, « 3 jours sur 4 ») ; « Objectif de poids » (« 71,6 kg », « cible 68 kg ») ; « Nutriments » (cadenas Premium) ; « Série de suivi » (« 23 jours ») ; « Idées » (« Il te reste environ 1 122 kcal ») ; « Eau » (« 1,25 L sur 2 L », Nouveau).
7. Lignes « Historique », « Ma bibliothèque » (« 3 repas · 2 aliments · 3 favoris ») ; note des sources ; « Mes paramètres ».

**Les 6 écrans de la planche**

| N° | Titre | Ce qu'il montre | D'où l'on vient | Où l'on va |
|---|---|---|---|---|
| 1 | Page principale, haut | Blocs 1 à 5. Sans caméra : les trois boutons deviennent un seul « Ajouter un aliment » (à dire en légende). | Carte de Mon quotidien | 3 (« Code-barres »), page d'un repas (case « Dîner », inchangée), 2 (défiler) |
| 2 | Page principale, suite | Blocs 6 et 7. Compte gratuit : la tuile « Nutriments » porte le cadenas ; la tuile « Eau » porte le jeton « Nouveau » et le contour en pointillés. | 1 | 4 (« Nutriments »), 5 (« Objectif de poids »), 6 (« Ma bibliothèque »), « Idées » et « Historique » inchangés |
| 3 | « Récapitulatif » d'un code-barres | « Barre tendre avoine et miel », étiquette « Open Food Facts » ; quantité « 1 barre (35 g) » avec − et + ; 140 kcal · P 2,5 · G 23 · L 4 ; Repas « Collation » ; « Objectifs » : « il te restera 982 kcal » ; bouton « Ajouter au journal » ; icône « Scanner à nouveau » ; mention Open Food Facts (ODbL). `data-tab="none"`. | 1 (« Code-barres », puis la caméra : dessinée sur la planche 4) | 1 (fermeture en une fois) |
| 4 | « Nutriments » (vue Premium, dit en légende) | « Objectifs » : Calories 1 078 / 2 200 kcal, Protéines 68 / 140 g, Glucides 121 / 250 g, Lipides 34 / 70 g, Fibres 11 / 31 g. « À limiter » : Sucres 28 / 55 g, Gras saturés 9 / 24 g, Sodium 1 240 / 2 300 mg. « Minéraux » : Potassium « Non disponible », Calcium 380 / 1 000 mg « partiel », Fer 4 / 8 mg. Sans Premium : les 4 premiers, puis la ligne verrouillée. | 2 (tuile), ou une tuile de macro | — |
| 5 | « Objectif de poids » | Ce qui est coupé en deux aujourd'hui, réuni : « 71,6 kg », « −1,8 kg en 30 jours » ; courbe « Poids » sur 30 jours avec la ligne « Cible » à 68 kg (Premium : cadenas pour un compte gratuit) ; « Ton objectif de poids » : Poids actuel 71,6 kg, Poids cible 68 kg, Durée 8 semaines, Rythme −0,45 kg par semaine, Calories par jour 2 200 kcal, Date estimée 7 janvier 2027 ; boutons « Ajouter une pesée » (teinté) et « Modifier l'objectif ». | 2 (tuile) | « Mes paramètres » › « Toi » et « Ton poids cible » (inchangés) |
| 6 | « Ma bibliothèque » | Trois segments : « Mes repas » (3, choisi), « Mes aliments » (2), « Favoris » (3). Liste : « Déjeuner habituel » 420 kcal · P 24 g ; « Bol poulet et riz » 658 kcal · P 44 g ; « Pâtes du dimanche » 689 kcal · P 33 g, avec leurs aliments. Sur chaque repas : « Ajouter à ma journée » ; menu « … » : « Renommer » (Nouveau), « Supprimer ce repas ». | 2 (ligne) | Feuille d'un repas enregistré (inchangée) |

- **Nouveautés (2)** : (1) tuile « Eau », 1,25 L sur 2 L, « + 250 ml » (écran 2) : la mission cite l'hydratation, retirée le 2026-10-15 ; c'est ici qu'elle coûte le moins de place. (2) « Renommer » un repas enregistré (écran 6) : aujourd'hui on ne peut que l'ajouter ou le supprimer (problème 15).
- **Ce que la direction sacrifie** : la page est dense et demande de défiler ; les aliments d'un repas sont à un toucher de plus ; un compte neuf ou gratuit voit des tuiles vides ou verrouillées (« Objectif de poids » sans pesée, « Nutriments ») ; trois boutons en tête au lieu d'une seule action principale.

---

### Direction 3 · Analytique — « Les tendances d'abord »

Fichier : `03-analytique.html`. 9 écrans.

- **Idée directrice** : la page se lit par période : trois onglets « Jour », « Semaine », « Tendances », et dans chacun le graphique passe avant la liste.
- **Pour qui, à quel moment** : la personne qui suit un plan de poids et veut comprendre pourquoi elle avance ou non. La meilleure pour le point de la semaine et pour un compte Premium.
- **Navigation** : trois onglets en tête de la page (un segmenté). Le sélecteur de semaine sert aux onglets « Jour » et « Semaine » ; l'onglet « Tendances » le remplace par les périodes « 7 jours », « 30 jours », « Période ». L'Historique n'est plus une page à part : il est réparti dans les onglets.
- **Élément vedette** : le graphique de la période. « Jour » : la barre de la journée découpée par repas face à l'objectif. « Semaine » : sept barres et la ligne d'objectif. « Tendances » : trente barres.
- **Action la plus fréquente** : un bouton rond « + » en haut à droite, dans la barre de navigation. Il ouvre la recherche (avec « Scanner »). Les lignes de « Repas » gardent leur « + ».

**Écran principal (onglet « Jour »), bloc par bloc**
1. Barre de navigation : « Nutrition », bouton « + ».
2. Onglets : « Jour » (choisi), « Semaine », « Tendances » (cadenas pour un compte gratuit).
3. Sélecteur de semaine (verre).
4. Héros (verre) : « 1 122 kcal restantes » ; barre de la journée en trois parts : Déjeuner 420, Dîner 658, reste 1 122 en creux ; « 1 078 mangées sur 2 200 kcal ».
5. « Macros et répartition » : trois jauges « mangé / objectif » et la part de chacune dans les calories : 26 %, 45 %, 29 %.
6. « Repas » : quatre lignes serrées avec « + ».
7. Ligne « Tous les nutriments » (badge Premium), carte conseil, « Mes repas », « Mes aliments », note, « Mes paramètres ».

**Les 9 écrans de la planche**

| N° | Titre | Ce qu'il montre | D'où l'on vient | Où l'on va |
|---|---|---|---|---|
| 1 | Onglet « Jour » | Blocs 1 à 6 à 13:20. La répartition du jour est gratuite. | Carte de Mon quotidien | 2 (onglet), 8 (« + ») |
| 2 | Onglet « Semaine » | Gratuit. « Calories de la semaine » : 7 barres lundi à dimanche (2 140, 2 310, 1 980, 1 078 hachuré « en cours », trois jours à venir vides), ligne d'objectif 2 200, « Moyenne 1 877 kcal · 3 jours sur 4 dans l'objectif ». Deux tuiles : « Série de suivi » 23 jours (à adapter : le calcul existe, la mini-app ne le montre pas) ; « Semaine dernière » 2 191 kcal en moyenne, 5 jours sur 7 dans l'objectif (Nouveau). Liste des jours notés : « Lun. 9 nov. » 2 140 kcal (coche), « Mar. 10 nov. » 2 310 (coche), « Mer. 11 nov. » 1 980 (coche), « Jeu. 12 nov. » 1 078 « en cours ». | 1 | 1 sur un autre jour (toucher un jour), 3 |
| 3 | Onglet « Tendances » (vue Premium, dit en légende) | Périodes « 7 jours », « 30 jours » (choisie), « Période ». « Moyennes » : 2 172 kcal (« objectif 2 200 »), 131 g, 256 g, 68 g ; « 23 jours sur 28 à moins de 10 % de ton objectif ». « Calories par jour » : 30 barres, ligne « Objectif », deux jours « Rien de noté » vides. « Répartition des calories » : 24 % · 48 % · 28 %. « Constats » (Nouveau) : trois phrases de `NUT.nouveau.constats`. Lignes « Poids et objectif », « Jour par jour ». | 2 | 6, 7 |
| 4 | Onglet « Tendances », compte gratuit | L'onglet porte un cadenas avant qu'on le touche. Dedans : la carte « L'historique détaillé est dans Premium » et « Découvrir Premium » ; au-dessus, une phrase dit ce qui reste libre : le jour choisi et la semaine. | 1 ou 2 | Offre Premium (inchangée) |
| 5 | « Nutriments » | La page actuelle : « Objectifs », « À limiter », « Acides gras », « Minéraux », « Vitamines ». Montrer l'état gratuit : quatre lignes ouvertes, puis la ligne verrouillée « Tous les nutriments ». | 1 | Offre Premium |
| 6 | « Poids et objectif » (vue Premium) | Courbe « Poids » sur 30 jours : 73,4 → 71,6 kg, « −1,8 kg », courbe lissée sur 7 jours, ligne « Cible » 68 kg. « Ton objectif de poids » : Rythme −0,45 kg par semaine, Date estimée 7 janvier 2027, Calories par jour 2 200 kcal. « Évolution des objectifs » (Nouveau) : frise « 2 sept. 2 729 kcal · Maintien », « 15 oct. 2 228 kcal · Perte de poids », « 5 nov. 2 200 kcal · Ajustement accepté ». | 3 | 9 |
| 7 | « Jour par jour » (Premium) | Liste : « Jeu. 12 nov. » 1 078 kcal « en cours », « Mer. 11 nov. » 1 980, « Mar. 10 nov. » 2 310, « Lun. 9 nov. » 2 140, « Dim. 8 nov. » 2 050, « Sam. 7 nov. » 2 480 (hors objectif), « Tout voir ». | 3 | 1 placé sur ce jour (plus de copie empilée de la page) |
| 8 | « Ajouter un aliment » | La recherche actuelle : champ « yogourt » ; « Scanner », « Aliment perso » ; pastilles de familles ; « Résultats » : Yogourt grec nature (étoile) « 73 kcal / 100 g · P 10 · G 4 · L 2 », Yogourt nature 2 % « 61 kcal / 100 g · P 4 · G 5 · L 3 », Yogourt grec à la vanille, Yogourt à boire aux fraises ; « Chercher « yogourt » dans les produits emballés ». `data-tab="none"`. | 1 (« + ») | Feuille de quantité (inchangée), scanner |
| 9 | « Tes besoins par jour » | Interrupteur « Calcul automatique » ; « Calculé d'après ton plan » › « Voir le récapitulatif » ; Calories 2 200 kcal « Calculé » ; Protéines 140 g « Personnalisé », « Recommandé : 129 g » ; Glucides 250 g « Personnalisé », « Recommandé : 268 g » ; Lipides 70 g « Personnalisé », « Recommandé : 68 g » ; « Acides gras, minéraux et vitamines » (Premium) ; « Comment c'est calculé ». | 6, « Mes paramètres » | Éditeur d'une cible (dessiné sur la planche 5) |

- **Nouveautés (3)** : (1) « Évolution des objectifs » (écran 6) : la mission la demande, l'app ne garde qu'une valeur ; avec elle, l'historique peut comparer chaque jour à l'objectif de l'époque (problème 21), ce qui change un calcul et doit être validé. (2) « Constats » écrits, Premium (écran 3) : trois phrases tirées de calculs existants, pour qui ne lit pas les graphiques. (3) Comparaison avec la semaine dernière (écran 2).
- **Ce que la direction sacrifie** : ajouter un aliment est en haut à droite, loin du pouce, et scanner demande deux touchers ; le chiffre du reste est plus petit ; un compte gratuit voit un onglet sur trois verrouillé ; les onglets n'existent dans aucune autre mini-app (cohérence) ; le sélecteur de dates change de forme selon l'onglet.

---

### Direction 4 · Quotidienne — « Le journal des repas »

Fichier : `04-quotidienne.html`. 8 écrans.

- **Idée directrice** : la page est le journal du jour, dans l'ordre des repas ; on lit, on note et on corrige au même endroit, sans changer de page.
- **Pour qui, à quel moment** : la personne qui note chaque repas, plusieurs fois par jour, souvent les mêmes aliments. La meilleure pour la rapidité et pour installer l'habitude.
- **Navigation** : une seule colonne qui suit la journée. Chaque repas se déplie sur place (il n'y a plus de page de repas à ouvrir). Un repère « Maintenant » sépare ce qui est noté de ce qui vient. Le reste (historique, bibliothèque, réglages) est en bas.
- **Élément vedette** : le repas à venir, mis en avant dans le journal avec ce qu'il lui reste : « Souper · environ 1 122 kcal ».
- **Action la plus fréquente** : une barre fixe au-dessus de la barre d'onglets : un champ « Ajouter un aliment » et deux boutons ronds, « Code-barres » et « Photo ». Dans un repas vide : les reprises en une touche.

**Écran principal, bloc par bloc**
1. Sélecteur de semaine (verre).
2. Bandeau de verre, fin : « 1 122 kcal restantes » ; « 1 078 mangées sur 2 200 kcal » ; trois jauges fines « 68 / 140 g », « 121 / 250 g », « 34 / 70 g ».
3. « Déjeuner · 07:45 » replié : « 3 aliments » 420 kcal.
4. « Dîner · 12:35 » déplié : Poulet grillé 120 g, 198 kcal ; Riz basmati cuit 200 g, 260 kcal ; Brocoli à l'huile d'olive 180 g, 200 kcal ; total 658 kcal · P 44 · G 69 · L 22 ; « Enregistrer ce repas ».
5. Repère « Maintenant · 13:20 ».
6. « Souper » à venir : « Environ 1 122 kcal pour ce repas » ; « Reprendre » : « Mer. 11 nov. » Omelette aux légumes… 623 kcal ; « Mar. 10 nov. » Chili con carne… 759 kcal ; puce « Mes repas » ; lien « Voir des idées ».
7. « Collation » : « Rien noté » ; favoris en une touche : Yogourt grec nature 128 kcal, Banane 107 kcal, Amandes 174 kcal (Nouveau).
8. « Eau » : 5 verres sur 8, « 1,25 L sur 2 L » (Nouveau).
9. Ligne « Cette semaine » (7 mini-barres, « 3 jours sur 4 dans l'objectif ») ; lignes « Historique », « Tous les nutriments », « Mes repas », « Mes aliments » ; note ; « Mes paramètres ».
10. Barre fixe : champ « Ajouter un aliment », boutons « Code-barres » et « Photo ».

**Les 8 écrans de la planche**

| N° | Titre | Ce qu'il montre | D'où l'on vient | Où l'on va |
|---|---|---|---|---|
| 1 | Journal, 13:20 | Blocs 1 à 6 et la barre fixe. | Carte de Mon quotidien | 2 (défiler), 3 (champ), 4 (bouton « Photo »), 6 (toucher « Riz basmati cuit ») |
| 2 | Journal, suite | Blocs 6 à 9 et la barre fixe. | 1 | 7 (« Mes repas »), « Idées », « Historique » (inchangés) |
| 3 | Saisie en bas | Le champ est actif, « yogourt » tapé ; au-dessus : puces de repas « Déjeuner », « Dîner », « Souper », « Collation » (choisie ; « Dîner » était proposé à 13:20) ; « Résultats » : les quatre yogourts de `NUT.recherche` ; « Chercher « yogourt » dans les produits emballés » ; lien « Aliment perso ». Clavier ouvert, `data-tab="none"`. | 1 | Feuille de quantité (inchangée, dessinée sur la planche 1) |
| 4 | Scanner, 19:05 (dit en légende) | Caméra : titre « Code-barres ou aliments » ; cadre ; « Vise un code-barres ou ton assiette » ; flash « Flash automatique » à côté du déclencheur ; déclencheur « Photographier le plat » ; bouton de la galerie ; « Encore 3 analyses de plat gratuites » ; croix qui revient au journal en une fois. `data-tab="none"`. | 1 (bouton « Photo ») | 5 |
| 5 | « Récapitulatif », photo du souper, 19:05 | Saumon grillé 140 g, « Estimation », « assez sûr », 288 kcal ; Riz basmati cuit 150 g, « Vérifié », « Ton habitude », 195 kcal ; Haricots verts 100 g, « Estimation », 35 kcal ; chaque ligne avec − et + et le menu « … » (« Remplacer », « Supprimer ») ; « À confirmer » : « Huile de cuisson ? » avec « Ajouter » et « Ignorer » ; total « ≈ 440–600 kcal » · P 37 · G 50 · L 18 ; Repas « Souper » ; « Objectifs » : environ 162 kcal restantes après l'ajout ; « Ajouter au journal » ; icône « Scanner à nouveau ». | 4 | 1 (le souper est noté) |
| 6 | Corriger un aliment | Sur le journal, la feuille « Riz basmati cuit » : « Quantité » 200 g ; « Ajuster de 10 g » (− et +) ; « Repas » Dîner ; « Apport » : 260 kcal, 5 g, 56 g, 1 g ; « Tous les nutriments » (badge Premium) ; « Retirer de ce repas ». En légende : glisser une ligne garde « Supprimer » et « Favori ». | 1 | 1 |
| 7 | « Mes repas » | Les trois repas enregistrés avec leurs aliments et « kcal · P g » ; sur chacun « Ajouter à ma journée » et « Supprimer ce repas ». Le texte d'aide dit où est « Enregistrer ce repas » (au bas d'un repas déplié). | 2, ou la puce « Mes repas » d'un repas vide | Feuille d'un repas enregistré (inchangée) |
| 8 | Journal, 08:10 (dit en légende) | Le même journal le matin : 420 kcal mangées, 1 780 restantes ; Déjeuner déplié (3 aliments) ; repère « Maintenant · 08:10 » ; « Dîner » à venir : « Environ 890 kcal pour ce repas » ; Souper et Collation repliés. Montre que la page suit la journée. | — | — |

- **Nouveautés (2)** : (1) « Eau » en verres, 5 sur 8 (écran 2) : un geste quotidien de plus dans un journal quotidien ; même objectif que l'habitude « Boire 2 L d'eau ». (2) Favoris en une touche dans l'app (écran 2) : aujourd'hui une touche n'ajoute une portion que depuis le widget « Ajout rapide » (Premium) ; à décider : gratuit ou Premium.
- **Ce que la direction sacrifie** : la page est longue ; l'analyse se réduit à une ligne en bas ; la barre de saisie est une pièce nouvelle du cadre commun (les autres mini-apps ont une action flottante ou deux boutons) ; le chiffre vedette est plus petit que sur la carte de Mon quotidien ; un journal déplié devient lourd après quatre repas complets.

---

### Direction 5 · Hybride — « La page qui suit ta journée »

Fichier : `05-hybride.html`. 9 écrans.

- **Idée directrice** : une page courte qui répond aux trois questions du PDG dans l'ordre (ce qu'il reste, ce qui est mangé, où j'en suis) et une carte « Maintenant » qui dit la prochaine chose utile ; le reste est rangé derrière deux portes, « Bilan » et « Ma bibliothèque », avant « Mes paramètres ».
- **Pour qui, à quel moment** : tout le monde, du premier jour au sixième mois. La page reste simple pour qui note, et l'analyse est à un toucher pour qui la veut.
- **Navigation** : la page principale, une action flottante double, et trois pages thématiques au lieu de huit liens : « Bilan » (semaine, périodes, nutriments, poids), « Ma bibliothèque » (favoris, repas, aliments), « Mes paramètres ».
- **Élément vedette** : l'anneau avec « 1 078 mangées sur 2 200 kcal », et juste dessous la carte « Maintenant », qui change avec l'état du jour (les quatre messages de la carte conseil actuelle, plus « Prochain repas »).
- **Action la plus fréquente** : action flottante double, toujours sous le pouce : « Scanner » (plein) et « Rechercher » (verre). Le scanner s'ouvre avec ses deux modes libellés, « Code-barres » et « Plat ».

**Écran principal, bloc par bloc**
1. Sélecteur de semaine (verre), avec la coche des jours dans l'objectif.
2. Héros (verre) : anneau à 49 % « 1 122 kcal restantes » ; « 1 078 mangées sur 2 200 kcal » ; trois jauges « Protéines 68 / 140 g », « Glucides 121 / 250 g », « Lipides 34 / 70 g ».
3. Carte « Maintenant » : « Prochain repas : souper, environ 1 122 kcal » ; « dont 72 g de protéines » ; bouton teinté « Voir des idées ». « À adapter » : le calcul du prochain repas existe (calories et protéines) ; la mini-app ne le montre pas aujourd'hui.
4. « Repas » : quatre lignes avec « + ».
5. (En défilant) « Aller plus loin » : « Bilan » (« Cette semaine : 3 jours sur 4 dans l'objectif ») ; « Ma bibliothèque » (« 3 repas · 2 aliments · 3 favoris »).
6. Note des sources ; « Mes paramètres » (« 2 200 kcal · 68 kg pour le 7 janv. »).
7. Action flottante double : « Scanner », « Rechercher ».

**Les 9 écrans de la planche**

| N° | Titre | Ce qu'il montre | D'où l'on vient | Où l'on va |
|---|---|---|---|---|
| 1 | Page principale | Blocs 1 à 4 et l'action flottante, à 13:20. Sans caméra : une seule action « Ajouter un aliment ». | Carte de Mon quotidien | 3 (ligne « Souper »), 4 (« Voir des idées »), 5 (« Scanner »), 2 (défiler) |
| 2 | Page principale, suite | Fin de « Repas », blocs 5 et 6. | 1 | 6 (« Bilan »), 8 (« Ma bibliothèque »), 9 (« Mes paramètres ») |
| 3 | « Souper », repas vide | « Rien de noté pour ce repas. » ; « Ajouter un aliment » ; « Reprendre un souper précédent » : « Mer. 11 nov. » Omelette aux légumes, Pain de blé entier, Salade verte, 623 kcal ; « Mar. 10 nov. » Chili con carne, Riz basmati cuit, Salade verte, 759 kcal ; « Lun. 9 nov. » Poulet grillé, Patate douce, Brocoli, 690 kcal ; « Mes repas » : « Bol poulet et riz » 658 kcal, « Pâtes du dimanche » 689 kcal. | 1 | Feuille d'un repas enregistré, recherche (inchangées) |
| 4 | « Idées » | « Il te reste environ 1 122 kcal ». « Un repas qui tient dans ce qu'il reste » : Chili con carne 400 g, 540 kcal, 36 g de protéines ; Lasagne à la viande 350 g, 560 kcal ; Pâté chinois 350 g, 510 kcal. « Riches en protéines » : Poulet grillé 120 g, 198 kcal, 36 g ; Thon en conserve 100 g, 116 kcal, 26 g. « Riches en fibres » : verrouillé, badge Premium. | 1 (carte « Maintenant ») | Feuille de quantité, « Souper » déjà choisi |
| 5 | Scanner : « Produit introuvable » | Le scanner après un code inconnu : le message « Produit introuvable » et ses trois sorties, « Créer cet aliment », « Chercher dans la liste », « Scanner à nouveau ». En haut, les deux modes « Code-barres » (choisi) et « Plat ». Aucune impasse. `data-tab="none"`. | 1 (« Scanner ») | « Aliment perso », recherche (inchangés) |
| 6 | « Bilan », segment « Calories » | Trois segments : « Calories » (choisi), « Nutriments », « Poids ». Périodes : « Cette semaine » (choisie, gratuite), puis « 7 derniers jours », « 30 jours », « Période » avec un cadenas. « Calories de la semaine » : 7 barres, ligne d'objectif, « Moyenne 1 877 kcal · 3 jours sur 4 dans l'objectif ». « Bilan » d'aujourd'hui : 1 078 kcal (« objectif 2 200 »), 68 g, 121 g, 34 g. « Répartition des calories » : 26 % · 45 % · 29 %. « Série de suivi » : 23 jours. | 2 | 7 (segment « Poids »), page principale sur un autre jour |
| 7 | « Bilan », segment « Poids » (vue Premium pour la courbe) | « 71,6 kg », « −0,5 kg en 7 jours » ; courbe sur 30 jours, ligne « Cible » 68 kg ; progression du plan : 1,8 kg perdus sur 5,4 (33 %), « 68 kg pour le 7 janvier 2027 » ; « Objectif : 2 200 kcal par jour, depuis le 5 nov. » (Nouveau) ; boutons « Ajouter une pesée » et « Voir le récapitulatif ». | 6 | Récapitulatif « Ton objectif de poids » (inchangé) |
| 8 | « Ma bibliothèque » | Une page, trois sections titrées. « Favoris » (3) : Yogourt grec nature, Banane, Amandes, avec « Retirer ». « Mes repas » (3) : les trois repas, « Ajouter à ma journée », « Modifier » (Nouveau). « Mes aliments » (2) : Smoothie protéiné maison « 76 kcal / 100 g », Barre maison avoine et dattes « 391 kcal / 100 g ». | 2 | Éditeurs existants |
| 9 | « Mes paramètres » : une cible | La feuille en chapitres, « Tes besoins par jour » ouvert, et par-dessus l'éditeur de la cible « Protéines » : champ 140 g ; « Recommandé : 129 g » ; « Enregistrer » ; « Revenir au calcul ». | 2 | 2 |

- **Nouveautés (2)** : (1) l'objectif daté, « depuis le 5 nov. » (écran 7) : la plus petite réponse à « évolution des objectifs » ; elle demande de garder la date de chaque changement. (2) « Modifier » un repas enregistré (écran 8) : le renommer et changer ses aliments (problème 15). L'hydratation est laissée de côté et la planche le dit : elle a été retirée le 2026-10-15 et se suit déjà comme une habitude (« Boire 2 L d'eau ») ; la question est posée au PDG.
- **Ce que la direction sacrifie** : trois pages à construire (« Bilan », « Ma bibliothèque », les chapitres) ; la carte « Maintenant » demande une règle claire (quel message passe avant l'autre) ; la semaine n'est plus sur la page, seulement en une phrase ; moins tranchée que les quatre autres.

## 3. Matrice des différences

| Axe | 1 · Minimaliste | 2 · Tableau de bord | 3 · Analytique | 4 · Quotidienne | 5 · Hybride |
|---|---|---|---|---|---|
| **Navigation** | Une page sans défilement et une page d'index | Grille de tuiles, en étoile | Trois onglets par période | Une colonne, tout se déplie sur place | Page courte et trois pages thématiques |
| **Élément vedette** | Un chiffre : « 1 122 kcal restantes » | La soustraction « objectif − mangé = reste » | Le graphique de la période | Le repas à venir dans le journal | L'anneau et la carte « Maintenant » |
| **Action la plus fréquente** | Un bouton « Ajouter » dans la page, puis une feuille | Trois boutons directs en tête | « + » en haut à droite | Champ fixe en bas et deux boutons de scan | Action flottante double |
| **Place de l'analyse** | Hors de la page, à deux touchers | En tuiles, sur la page | C'est la page | Une ligne en bas | Une page « Bilan » à un toucher |
| **Densité** | Très faible : 5 blocs, aucun défilement | Forte : 13 tuiles et cases | Forte : un graphique par écran | Moyenne, mais longue | Moyenne : 4 blocs, puis 2 portes |
| **Les repas** | Liste de 4 lignes | Bande de 4 cases | Liste serrée, après les graphiques | Dépliés, avec leurs aliments | Liste de 4 lignes |
| **Accès à « Mes repas » et aux favoris** | Page d'index | Page « Ma bibliothèque » en segments | Bas de l'onglet « Jour » | Dans chaque repas vide | Page « Ma bibliothèque » en sections |
| **Compte gratuit** | Presque rien de verrouillé à l'écran | Une tuile verrouillée | Un onglet sur trois verrouillé | Rien de verrouillé sur la page | Verrous seulement dans « Bilan » |
| **Nouveautés** | 0 | 2 (eau, renommer un repas) | 3 (évolution des objectifs, constats, semaine dernière) | 2 (eau, favoris en une touche) | 2 (objectif daté, modifier un repas) |

**Nombre de touchers** (pour la planche de comparaison ; aujourd'hui entre parenthèses) :

| Geste | Aujourd'hui | 1 | 2 | 3 | 4 | 5 |
|---|---|---|---|---|---|---|
| Noter le yogourt favori dans la collation | 3 | 3 | 3 | 3 | 1 | 3 |
| Scanner un code-barres et l'ajouter | 2 | 3 | 2 | 3 | 2 | 2 |
| Voir la moyenne de la semaine | 0, en défilant | 1 | 0, en défilant | 1 | 0, en défilant | 1 |
| Ouvrir l'historique d'un mois (Premium) | 2 | 3 | 2 | 2 | 2 | 2 |

## 4. Cohérence avec Mon quotidien

**Ce que montre la carte Nutrition** (audit, section 6 ; socle, section 3.4). Elle est la première de Mon quotidien, en pleine largeur. Trois vues à balayer :
1. « Aujourd'hui » : anneau de 90 points « 1 122 kcal restantes », trois lignes de macros (« 68 / 140 g »…), bouton « Scanner », « 2 repas », « Prochain repas : souper, environ 1 122 kcal ».
2. « Repas du jour » : Déjeuner 420, Dîner 658, Souper « — », Collation « — », « Total 1 078 / 2 200 kcal ».
3. « Calories · 7 jours » : sept barres, « Moyenne : 2 041 kcal par jour noté » ; elle ouvre l'Historique.

**Deux largeurs seulement dans le code** : demi et pleine. La mission demande Nutrition en « Medium » : cette taille n'existe pas. Proposition pour les cinq directions : la carte reste en pleine largeur, avec sa hauteur actuelle (la vue « Aujourd'hui »). La version demi-largeur existe déjà (anneau de 46 points, macros serrées, bouton rond du scanner) et reste possible. À trancher par le PDG sur la planche de cohérence.

**Règles communes aux cinq directions**
- Même chiffre vedette, mêmes mots : « kcal restantes » (ou « kcal en trop », « kcal mangées »), même anneau orange, mêmes couleurs de macros, même icône, même bouton « Scanner ».
- Chaque vue de la carte mène à sa suite dans la mini-app : « Aujourd'hui » ouvre la page principale ; « Repas du jour » ouvre la page placée sur « Repas » (à adapter) ; « Calories · 7 jours » ouvre l'analyse (existe).
- La mini-app ne recopie pas la carte : elle y ajoute ce que la carte n'a pas.

| Direction | Ce que la page reprend de la carte | Ce qu'elle ajoute | Risque |
|---|---|---|---|
| 1 · Minimaliste | Le chiffre du reste, les trois macros | « Mangées sur », la liste des repas, un seul bouton « Ajouter » | Répétition : la page ressemble beaucoup à la carte |
| 2 · Tableau de bord | L'anneau | Une tuile par vue de la carte (« Repas », « Semaine ») et six autres | Aucune répétition, mais beaucoup plus dense que la carte |
| 3 · Analytique | Le reste, en plus petit | Les graphiques ; la vue « 7 jours » de la carte mène droit à l'onglet « Semaine » | Le chiffre vedette n'a pas la même taille aux deux endroits |
| 4 · Quotidienne | Le reste dans un bandeau fin ; « Prochain repas » | Les aliments de chaque repas, la saisie | La carte reste l'endroit où le chiffre se lit le mieux |
| 5 · Hybride | L'anneau et « Prochain repas » | « Mangées sur », la carte « Maintenant » avec les idées, les repas, deux portes | Faible : la carte résume, la page prolonge |

**Liens avec les autres mini-apps** (inchangés dans les cinq directions) : l'objectif est commun à Fitness et Nutrition (« Le même pour Sport et Nutrition. ») ; le niveau d'activité suit les séances de Fitness ; le poids sert aux deux. La nouveauté « Eau » (directions 2 et 4) reprend l'objectif de l'habitude « Boire 2 L d'eau » : si elle est gardée, il faudra dire laquelle des deux fait foi.

## 5. Rien n'est retiré

Les 64 fonctions, par groupe. « = » : gardée à sa place actuelle, non dessinée sur cette planche (la table de fin dit laquelle). Les numéros sont ceux des écrans de la planche de la direction.

**Groupes** : A le jour (F1, F2) · B le bilan du jour (F3, F4, F39, F41) · C premier réglage (F5) · D ajouter (F6 à F14) · E scanner (F15 à F26) · F les repas (F27 à F34) · G bibliothèque (F35, F36) · H nutriments et idées (F37, F38, F40) · I historique (F42 à F47) · J objectifs et réglages (F48 à F58) · K hors de la mini-app (F59 à F64).

### Direction 1 · Minimaliste

| Groupe | Où |
|---|---|
| A | F1 : écran 1, sélecteur. F2 : « = », sans écran. |
| B | F3, F4 : écran 1, héros. F39 : « Calcule tes besoins du jour » dans « À remplir » (écran 8) ; « Des idées… » devient la ligne « Idées » (écran 5) ; « Objectif atteint » et « Objectif dépassé » s'écrivent sous le chiffre du héros. F41 : écran 5, carte en tête. |
| C | F5 : écran 8, une carte à deux lignes. |
| D | F7 : écran 1, bouton « Ajouter ». F6, F8, F9, F13, F14 : écran 2. F11 : écran 3. F12 : écrans 1 (« + ») et 4. F10 : « = », la ligne « Chercher « … » dans les produits emballés » apparaît dès qu'un mot est tapé. |
| E | F24 : écran 2, sous « Photo du plat ». F15 à F23, F25, F26 : « = », scanner et récapitulatif inchangés, ouverts depuis l'écran 2. |
| F | F27 : écran 1. F28, F32, F34 : écran 4. F29, F30, F31, F33 : « = », page d'un repas inchangée (feuille d'un aliment, glisser, section « Mes repas »). |
| G | F35, F36 : écran 5, lignes ; pages inchangées. |
| H | F37, F40 : écran 5, lignes. F38 : « = », page inchangée. |
| I | F42, F43, F45 : écran 6. F44, F46, F47 : « = », mêmes blocs de la même page, en Premium. |
| J | F48 : écran 5, dernière ligne. F49 à F54, F58 : écran 7, chapitres. F55, F56, F57 : « = », en tête de la feuille quand il y a lieu. |
| K | F64 : écran 5, note. F59 à F63 : « = ». |

### Direction 2 · Tableau de bord

| Groupe | Où |
|---|---|
| A | F1 : écran 1. F2 : « = ». |
| B | F3 : écran 1, héros. F4 : écran 1, trois tuiles. F39 : écran 2, tuile « Idées » ; les messages d'objectif atteint ou dépassé dans le héros. F41 : écran 2, tuile « Semaine ». |
| C | F5 : « = », sous le héros, comme aujourd'hui. |
| D | F6 : écran 1, « Code-barres » et « Photo ». F7 : écran 1, « Rechercher ». F12 : écran 1, « + » des cases vides de « Repas ». F8 à F11, F13, F14 : « = », recherche et feuille de quantité inchangées. |
| E | F21, F25 : écran 3. F15 à F20, F22, F23, F24, F26 : « = », scanner inchangé (caméra dessinée sur la planche 4). |
| F | F27 : écran 1, bande « Repas ». F28 à F34 : « = », page d'un repas inchangée. |
| G | F35, F36 : écran 6, segments. La liste des favoris de l'espace (F63) y vient aussi. |
| H | F37 : écran 2, tuile. F38 : écran 4. F40 : écran 2, tuile « Idées » ; page inchangée. |
| I | F46 : écran 5. F42 à F45, F47 : « = », Historique inchangé, ouvert par la tuile « Semaine » ou la ligne « Historique » (écran 2). |
| J | F48 : écran 2. F51, F55 : écran 5. F49, F50, F52, F53, F54, F56, F57, F58 : « = », « Mes paramètres » inchangé. |
| K | F64 : écrans 2 et 3. F59 à F63 : « = ». |

### Direction 3 · Analytique

| Groupe | Où |
|---|---|
| A | F1 : écran 1, sous les onglets. F2 : « = ». |
| B | F3, F4 : écran 1. F41 : écran 2. F39 : « = », carte conseil au bas de l'onglet « Jour ». |
| C | F5 : « = », en tête de l'onglet « Jour ». |
| D | F7 : écrans 1 (« + ») et 8. F6, F8, F9, F10, F13 : écran 8. F12 : écran 1, « + » des lignes. F11, F14 : « = ». |
| E | F15 à F26 : « = », ouverts depuis la recherche, comme aujourd'hui. |
| F | F27 : écran 1. F28 à F34 : « = ». |
| G | F35, F36 : « = », lignes au bas de l'onglet « Jour ». |
| H | F37 : écran 1. F38 : écran 5. F40 : « = ». |
| I | F42 : écrans 3 et 4. F43 : écrans 1 (bilan du jour) et 3 (moyennes). F44 : écran 3. F45 : écrans 1 et 3. F46 : écran 6. F47 : écran 7. |
| J | F58 : écran 9. F51, F55 : écran 6. F48 : « = », bas de l'onglet « Jour ». F49, F50, F52, F53, F54, F56, F57 : « = ». |
| K | F59 à F64 : « = » (la note reste au bas de l'onglet « Jour »). |

### Direction 4 · Quotidienne

| Groupe | Où |
|---|---|
| A | F1 : écran 1. F2 : « = ». |
| B | F3, F4 : écran 1, bandeau. F39 : écran 2, « Voir des idées » du repas à venir. F41 : écran 2, ligne « Cette semaine ». |
| C | F5 : « = », sous le bandeau. |
| D | F6 : écran 1, deux boutons de la barre. F7, F8, F10, F13 : écran 3. F9 : « = », pastilles de la recherche vide. F12 : écrans 1 et 2, dans chaque repas. F14 : écran 2, puce « Mes repas ». F11 : « = ». |
| E | F15, F16, F17, F18, F24 : écran 4. F21, F22, F23, F25 : écran 5. F19, F20, F26 : « = ». |
| F | F27, F28, F34 : écran 1 (un repas déplié est sa page). F29 : écran 6. F32, F33 : écran 2. F30, F31 : « = », glisser inchangé. |
| G | F35 : écran 7. F36 : écran 2, ligne. |
| H | F37 : écran 2. F40 : écran 2 (lien), page inchangée. F38 : « = ». |
| I | F42 à F47 : « = », Historique inchangé, ligne de l'écran 2. |
| J | F48 : écran 2. F49 à F58 : « = ». |
| K | F64 : écrans 2 et 5. F59 à F63 : « = ». |

### Direction 5 · Hybride

| Groupe | Où |
|---|---|
| A | F1 : écran 1. F2 : « = ». |
| B | F3, F4 : écran 1. F39 : écran 1, carte « Maintenant ». F41 : écran 6. |
| C | F5 : « = », en tête ; « Maintenant » se tait tant qu'elle est là. |
| D | F6, F7 : écran 1, action flottante. F12 : écrans 1 et 3. F8 à F11, F13, F14 : « = ». |
| E | F20, F25 : écran 5. F15 à F19, F21 à F24, F26 : « = ». |
| F | F27 : écran 1. F28, F32, F33 : écran 3. F29, F30, F31, F34 : « = ». |
| G | F35, F36 : écran 8, avec les favoris. |
| H | F40 : écran 4. F37 : écran 6, segment « Nutriments ». F38 : « = », la page devient ce segment. |
| I | F42, F43, F45 : écran 6. F46 : écran 7. F44, F47 : « = », même page, périodes Premium. |
| J | F48 : écran 2. F58 : écran 9. F51, F55 : écran 7. F49, F50, F52, F53, F54, F56, F57 : « = », chapitres de « Mes paramètres ». |
| K | F64 : écran 2. F59 à F63 : « = ». |

### Fonctions difficiles à placer (à surveiller sur chaque planche)

| Fonction | Difficulté | Consigne |
|---|---|---|
| F2 Retour automatique à aujourd'hui | Aucun écran | « = » partout, avec la phrase « sans écran : la page suit le jour ». |
| F19 Explication avant la caméra | Montrée une seule fois | « = » ; le texte « Ce qui reste sur ton iPhone » doit rester avant la demande de caméra. |
| F20 Sorties d'un code-barres | État d'erreur | Dessinée sur la planche 5 seulement. |
| F22, F23 « À confirmer », apprentissage | Dans le récapitulatif d'une photo | Dessinées sur la planche 4 seulement. |
| F26 Pas de doublon | Alerte | « = » partout. |
| F31 Favori | Geste caché | Reste le glisser ; les planches 1 et 3 ajoutent l'étoile dans la recherche ; 2 et 5 la liste. |
| F36 « Mes aliments » | N'apparaît que s'il y en a | Les données d'exemple en ont 2 : la ligne se montre. |
| F56, F57 Ajustement et nouveau calcul proposés | N'apparaissent que dans certains états | La personne suit son rythme : aucune des deux cartes n'est affichée dans les données d'exemple. « = », avec l'endroit où elles apparaîtraient. |
| F61 Ajout rapide depuis un widget | Hors de l'app, Premium | « = » ; la planche 4 propose le même geste dans l'app, comme nouveauté. |
| F63 Espace Nutrition côté Créer | Second tableau de bord (problème 23) | « = » ; sa liste des favoris est reprise dans « Ma bibliothèque » (planches 2 et 5). |
| F64 Mentions des sources | Plusieurs endroits | La note de la page principale et la mention du récapitulatif restent visibles. |

## 6. Nouveautés : vue d'ensemble

| Nouveauté | Pourquoi | Directions | Demande de l'app |
|---|---|---|---|
| Eau du jour (hydratation) | Citée par la mission ; retirée le 2026-10-15 | 2 (tuile), 4 (verres) | Remettre une donnée et un écran ; décision du PDG |
| Évolution des objectifs | Citée par la mission ; l'objectif n'est pas daté (problème 21) | 3 (frise complète), 5 (date seule) | Garder la date de chaque changement ; pour la 3, comparer chaque jour à l'objectif de l'époque |
| Constats écrits | Lire une tendance sans graphique | 3 | Phrases tirées de calculs existants ; Premium |
| Comparaison avec la semaine dernière | Dire si la semaine est meilleure | 3 | Calcul simple sur des données existantes |
| Favoris en une touche dans l'app | N'existe que dans le widget « Ajout rapide » | 4 | Reprendre l'action du widget ; gratuit ou Premium à décider |
| Renommer ou modifier un repas enregistré | Problème 15 | 2 (renommer), 5 (modifier) | Un éditeur de repas enregistré |

Proposées en texte seulement, sans dessin : annuler une suppression pendant quelques secondes (problème 14) ; déplacer un aliment vers un autre jour (problème 20) ; les mêmes valeurs à la correction qu'à la création d'un aliment perso (problème 16).

## 7. Points à trancher et incertitudes

1. **Écarts avec `cristal.js`** (moyenne des 7 jours, prochain repas, cibles de nutriments) : ce document suit le code. Si le Chef préfère les repères Cristal, une ligne de `nutrition.js` suffit à changer.
2. **Macros « Personnalisé »** : choix fait pour garder 140 / 250 / 70 g sans contredire les règles de calcul. Il rend l'écran « Tes besoins par jour » plus parlant (les deux états se voient).
3. **Compte gratuit par défaut** : les vues « Tendances », « Poids » et « Nutriments » sont montrées en Premium, en le disant. Si le PDG veut juger la version gratuite, chaque planche a au moins un écran qui la montre.
4. **Direction 4** : la barre de saisie fixe est une pièce nouvelle du cadre commun. Elle doit se dessiner avec les jetons du thème, au-dessus de la barre d'onglets, comme l'action flottante.
5. **Direction 3** : le journal des objectifs change la règle « jour dans l'objectif » pour les jours passés (objectif de l'époque). C'est un calcul modifié : à présenter comme tel.
6. **Non vérifié** : la règle exacte de recalcul de l'objectif quand le poids change (le plan garde les calories acceptées) ; les valeurs de la frise des objectifs sont un exemple.
7. **Limites** : planches en Inter (SF Pro sur l'iPhone) ; grandes tailles de texte et mode sombre non dessinés ; libellés nouveaux à vérifier en allemand et en japonais (« Code-barres », « Photo du plat », « Tout Nutrition », « Ma bibliothèque », « Bilan », « Maintenant »).
