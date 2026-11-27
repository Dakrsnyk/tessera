# Analyse intégrale d'Ardane : Gratuit et Premium, pubs du QG, estimation (2026-11-27)

Trois sources : (1) le code d'Ardane lu fonction par fonction (build 627), (2) les 63 vidéos et 34 images du QG (`ardane-hq/workspace/marketing/_imports/`) vues image par image (12 images par vidéo, sans le son), (3) les chiffres publics du marché (coût d'installation, conversion). L'estimation reste une projection : seuls les vrais chiffres de vente la confirmeront.

## 1. En bref
- **Ardane est déjà une app « gratuite + Premium » bien conçue** : rien n'est bloqué à l'ouverture, environ 25 points d'entrée vers l'offre, et surtout **l'essai visuel de tout le Premium** : dans le Studio, un utilisateur gratuit peut appliquer n'importe lequel des 500 styles Premium, les couleurs, polices, fonds, et les 61 types de widgets Premium, et les voir en grand sur un faux écran d'accueil (« Sur mon écran »). Seul « Enregistrer » est bloqué (« Débloquer et enregistrer »). C'est le meilleur levier de conversion possible sans bloquer l'app.
- **L'écart Gratuit / Premium est large** : 3 widgets contre illimité, 29 types de widgets sur 90, 4 styles sur 504, 3 habitudes, 10 analyses de plat, 4 nutriments sur 38, historique limité au mois en cours, bibliothèque d'exercices Premium.
- **Les pubs sont moyennes (≈ 6,5/10)** avec quelques très bonnes (scan 8,5 ; nutrition, papier, planning, budget, finances, voyage 8). Défauts récurrents : ouverture lente ou sur écran noir, pas de geste réel, fin sans « Télécharge gratuitement », mention Premium illisible, widgets Premium montrés comme le cœur de la promesse (Série faite, Prochaine série, Macros).
- **Estimation (1 000 $ CA/mois de pub + 1 vidéo/jour)** : avec les pubs actuelles, pub remboursée au **mois 9**, ≈ **60 $/jour** à la fin de l'an 1 ; avec les pubs corrigées, remboursée au **mois 3**, ≈ **112 $/jour** à la fin de l'an 1 et ≈ 340 $/jour à la fin de l'an 3.

## 2. Gratuit et Premium, tel que codé
### Limites gratuites
| | Gratuit | Premium |
|---|---|---|
| Widgets enregistrés | 3 (photos et citations illimitées, hors compte) | illimités |
| Types de widgets | 29 sur 90 | 90 |
| Styles de widget | 4 (Minimal, Clair, Sombre, Monochrome) | 504 |
| Couleurs principales du Studio | 8 | toutes (nuancier) |
| Fonds, polices, dégradés, textures, bordures, ombres, couleurs par ligne | thème, 2 polices | tout |
| Habitudes | 3 | illimitées |
| Analyses de plat en photo | 10 au total | illimitées |
| Code-barres et recherche d'aliments | illimités | illimités |
| Nutriments | 4 (calories, protéines, glucides, lipides) | 38 |
| Couleurs de l'app / icônes de l'app | 1 sur 14 / 1 sur 20 | toutes |
| Fonds d'écran du Store | 14 sur 43 | 43 |
| Écrans d'accueil prêts, packs, modèles | gratuits seulement si tous leurs widgets et leur style le sont | tous |
| Activité en direct (séance, chrono d'étude) | gratuite | gratuite |

### Par mini-app
| Mini-app | Gratuit | Premium |
|---|---|---|
| Nutrition | code-barres illimité, recherche, 10 photos de plat, calories et macros avec objectifs, jour et semaine, aliments perso, plan de poids | photos illimitées, 34 autres nutriments, historique et analyses |
| Fitness | programmes, séances, exercices écrits à la main, séries, activité en direct, alerte de fin de repos, volume de la semaine | bibliothèque de 244 exercices (fiches, démonstrations, historique, records), progression |
| Planning, tâches, habitudes | tâches, calendrier, cours tapés, 3 habitudes, % sur 30 jours, série | import d'horaire par photo ou PDF, bilan (90 jours, meilleure série), carte semaine, plus de 3 habitudes |
| Études | cours, examens, notes, échéances, activité en direct | import d'horaire par photo ou PDF |
| Finances | dépenses et revenus, budget, épargne, mois en cours, 7 derniers jours du relevé, graphique du mois | mois passés, graphiques 3 mois et année, page Analyse, import Apple Pay |
| Business | saisie, totaux de l'année, mois en cours | mois par mois, import CSV, Stripe |
| Placements et marchés | widget de liste de suivi | crypto, portefeuille, répartition, marchés, 4 widgets de sociétés |
| Voyage | voyages, compte à rebours, heure locale | vol, hôtel, devise, progression du voyage, prochaine activité |
| Photos et citations | illimité, 8 couleurs | 10 fonds et nuancier libre |

### Widgets interactifs
- **Gratuits et interactifs** : Tâches, Habitudes, Compteur, Dépense rapide ; « Commencer » de Séance du jour ; scanner sur Calories restantes.
- **Premium** : Concentration, Projet, Ajout rapide d'aliment, Prochaine série (« Série faite »), Minuteur de repos, Devoirs, Cartes de révision.
- Un widget Premium posé par un utilisateur gratuit affiche un cadenas « Premium » (toucher = offre) ; la galerie iOS les montre en entier avec des données d'exemple.

### Comment on essaie le Premium avant de payer
1. **Studio** : tout est utilisable et visible (styles, couleurs, fonds, polices, types Premium avec données d'exemple, « Sur mon écran ») ; seul Enregistrer est bloqué.
2. **Store** : un style touché ouvre le Studio sur un widget d'essai ; packs et écrans d'accueil montrés en entier, bouton « Débloquer avec Premium » ; fonds d'écran en plein écran.
3. **« Mes styles »** : « Appliquer » montre chaque widget restylé avant l'offre.
4. **L'offre elle-même** montre les widgets tels qu'ils seront.
5. Sans aperçu : couleurs et icônes de l'app (toucher = offre directe).

### L'offre et les prix
- **Offre de bienvenue** : une seule fois, à la fin de la première configuration (après les autorisations), avec 3 vrais widgets des centres d'intérêt, « + 500 styles », annuel présélectionné (−28 %) et mensuel, bouton « Essayer 7 jours gratuits », « Plus tard » possible.
- **Prix** : mensuel 6,99 $, annuel 59,99 $ (5 $/mois), essai de 7 jours sur les deux ; l'achat à vie (99,99 $) existe dans le code mais n'est pas créé dans App Store Connect.
- **≈ 25 points d'entrée vers l'offre** : pastille dorée et bandeau de l'accueil, Profil, widget verrouillé, Studio, limites (widgets, habitudes, scans), cartes verrouillées des mini-apps, Store, fonds d'écran, icônes.

### Points à corriger dans l'app (trouvés dans le code)
1. Après « Plus tard », l'offre de bienvenue ne revient **jamais** en version publique (seulement en version de test) : prévoir un retour (après le 3e widget ou au 3e jour).
2. Le compteur des 10 analyses de plat repart à zéro si on supprime et réinstalle l'app.
3. Le tableau comparatif de l'offre oublie : analyses de plat, nutriments, fonds d'écran, icônes, imports (Stripe, CSV, horaire, Apple Pay) ; la bannière dit « 500 styles », l'offre « 504 ».
4. Le nuancier de fond des citations est désactivé sans explication pour un utilisateur gratuit (aucune offre au toucher).
5. Couleurs et icônes de l'app : aucun aperçu avant l'achat.
6. Ancien abonné Premium : l'app montre encore le style Premium alors que l'écran d'accueil montre le style gratuit.

## 3. Pubs du QG (63 vidéos, 34 images)
### Les meilleures, à publier en premier
| Pub | Note | À faire |
|---|---:|---|
| pub-organique-scan-v1 | 8,5 | ajouter « Télécharge gratuitement » |
| pub-organique-nutrition-v5.1 | 8 | telle quelle |
| pub-organique-papier-v1 | 8 | telle quelle |
| pub-organique-planning-v2 | 8 | telle quelle |
| pub-organique-budget-v1 | 8 | telle quelle |
| pub-organique-finances-v3 | 8 | appel à l'action plus gros |
| pub-organique-voyage-v3 | 8 | retirer le doublon, mention Premium lisible |
| battle, business-v4, cours, études-v3 | 7,5 | petites corrections (fin, mention Premium) |
| Images post-feed-02 (néon), post-feed-05 (astuce habitudes) | 8,5 | telles quelles |

### À refaire ou retirer
- **pub-principale-v5-restylee-v3** (58,9 s, ouverture sur une affiche) : 5/10, à refaire en 25-30 s. **main-pub v2.5** (56 s) : 5,5, trop longue pour de l'organique.
- **Les 30 « fadein »** (10 s, même gabarit) : 4 à 6/10 ; ouverture sur une image noire, aucun geste, fin sur le logo seul. Garder 4 à 6 (14, 15, 16, 20, 22, 23), les rallonger à 15 s avec un geste et un appel à l'action ; retirer 11 et 28.
- **affiche-09 et post-feed-11** : montrent « Prochaine série » (Premium) comme gratuit : à corriger avant publication.

### Les 6 défauts qui reviennent
1. **Accroche** : beaucoup ouvrent sur du noir, un texte seul ou un petit téléphone. Les meilleures ouvrent sur une question de douleur dans un vrai décor.
2. **Premium** : « With Premium » écrit en 10-14 px gris, illisible ; et des widgets Premium (Série faite, Prochaine série, Minuteur de repos, Macros, 4 habitudes) présentés comme le cœur de la promesse. Risque de déception à l'installation.
3. **Aucun style gratuit montré** : tous les styles des pubs (Néon, Aurore, Blossom, Luxe, Carbone) sont Premium ; « 3 widgets gratuits » et « 10 scans gratuits » ne sont presque jamais dits.
4. **Geste réel absent** dans la plupart des formats courts (les valeurs changent sans doigt).
5. **Fin sans verbe** : « Available on the App Store » au lieu de « Télécharge Ardane gratuitement » ; des posts disent « Download » alors que l'app n'est pas encore en ligne.
6. **Variété** : 30 fadein identiques, 17 posts sur 20 au même gabarit (widget blanc sur fond sombre), aucune personne, le Studio et les 504 styles jamais montrés en action.

### Ce que les pubs devraient montrer (d'après l'inventaire)
Ce qui est **gratuit et impressionnant** : la séance en direct sur l'écran verrouillé, le scan de code-barres et 10 photos de plat, les tâches et habitudes cochées depuis l'écran d'accueil, la dépense rapide, Mon Quotidien ; puis **le Studio** qui essaie un style Premium sur son propre widget (gratuit à essayer), avec une pastille lisible « Premium ».

## 4. Estimation finale
Hypothèses communes : 1 vidéo organique par jour, 1 000 $ CA/mois de vidéos sponsorisées (≈ 1 million de vues), bouche-à-oreille, abonnés suivis par cohorte (départs selon l'ancienneté, renouvellements annuels 50 % puis 70 %), 65 % d'annuels, montants nets d'Apple en $ CA (1 $ US ≈ 1,38 $ CA).

| | Pubs actuelles | Pubs corrigées |
|---|---|---|
| Vues organiques → installation | 0,2 % | 0,3 % |
| Vues sponsorisées → installation (mois 1 → 6) | 0,02 → 0,04 % | 0,03 → 0,06 % |
| Installés qui paient (mois 1 → 6) | 3,5 → 4,5 % | 4 → 5 % |
| Pourquoi | essai visuel du Studio et offre de bienvenue déjà en place, mais pubs qui déçoivent parfois (Premium montré comme gratuit) | même app, pubs honnêtes et plus claires : plus d'installations, moins de déception |

Résultats mois par mois :

## Pubs actuelles  (rentabilité cumulée atteinte au mois 9)
| Mois | Vues/vidéo | Installs organiques | Installs payés (CPI) | Bouche-à-oreille | Installs totaux | % payants | Nouveaux payeurs | Abonnés actifs | Revenu net | Après pub | Cumul |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 1 | 800 | 48 | 200 (5.00 $) | 0 | 248 | 3.5 % | 9 | 9 | 422 $ | -578 $ | -578 $ |
| 2 | 920 | 55 | 240 (4.17 $) | 25 | 320 | 3.7 % | 12 | 19 | 592 $ | -408 $ | -986 $ |
| 3 | 1 058 | 63 | 280 (3.57 $) | 32 | 375 | 3.9 % | 15 | 32 | 747 $ | -253 $ | -1 239 $ |
| 4 | 1 217 | 73 | 320 (3.12 $) | 38 | 431 | 4.1 % | 18 | 47 | 914 $ | -86 $ | -1 325 $ |
| 5 | 1 399 | 84 | 360 (2.78 $) | 43 | 487 | 4.3 % | 21 | 65 | 1 099 $ | 99 $ | -1 226 $ |
| 6 | 1 609 | 97 | 400 (2.50 $) | 49 | 545 | 4.5 % | 25 | 86 | 1 301 $ | 301 $ | -925 $ |
| 7 | 1 850 | 111 | 400 (2.50 $) | 55 | 566 | 4.5 % | 25 | 106 | 1 377 $ | 377 $ | -548 $ |
| 8 | 2 128 | 128 | 400 (2.50 $) | 57 | 584 | 4.5 % | 26 | 127 | 1 448 $ | 448 $ | -100 $ |
| 9 | 2 447 | 147 | 400 (2.50 $) | 58 | 605 | 4.5 % | 27 | 149 | 1 523 $ | 523 $ | 422 $ |
| 10 | 2 814 | 169 | 400 (2.50 $) | 61 | 629 | 4.5 % | 28 | 171 | 1 604 $ | 604 $ | 1 026 $ |
| 11 | 3 236 | 194 | 400 (2.50 $) | 63 | 657 | 4.5 % | 30 | 194 | 1 693 $ | 693 $ | 1 719 $ |
| 12 | 3 722 | 223 | 400 (2.50 $) | 66 | 689 | 4.5 % | 31 | 219 | 1 792 $ | 792 $ | 2 511 $ |
| 15 | 4 309 | 259 | 400 (2.50 $) | 72 | 730 | 4.5 % | 33 | 281 | 2 303 $ | 1 303 $ | 6 045 $ |
| 18 | 4 988 | 299 | 400 (2.50 $) | 76 | 775 | 4.5 % | 35 | 338 | 2 707 $ | 1 707 $ | 10 747 $ |
| 21 | 5 774 | 346 | 400 (2.50 $) | 81 | 827 | 4.5 % | 37 | 393 | 2 960 $ | 1 960 $ | 16 372 $ |
| 24 | 6 684 | 401 | 400 (2.50 $) | 87 | 888 | 4.5 % | 40 | 451 | 3 255 $ | 2 255 $ | 22 829 $ |
| 30 | 8 957 | 537 | 400 (2.50 $) | 101 | 1 038 | 4.5 % | 47 | 568 | 4 222 $ | 3 222 $ | 39 885 $ |
| 36 | 12 004 | 720 | 400 (2.50 $) | 120 | 1 240 | 4.5 % | 56 | 705 | 5 056 $ | 4 056 $ | 62 014 $ |
Année 1: revenu 14 511 $  après pub 2 511 $  revenu/jour fin d'année 60 $
Année 2: revenu 32 318 $  après pub 20 318 $  revenu/jour fin d'année 108 $
Année 3: revenu 51 184 $  après pub 39 184 $  revenu/jour fin d'année 169 $

## Pubs corrigées  (rentabilité cumulée atteinte au mois 3)
| Mois | Vues/vidéo | Installs organiques | Installs payés (CPI) | Bouche-à-oreille | Installs totaux | % payants | Nouveaux payeurs | Abonnés actifs | Revenu net | Après pub | Cumul |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 1 | 800 | 72 | 300 (3.33 $) | 0 | 372 | 4.0 % | 15 | 15 | 723 $ | -277 $ | -277 $ |
| 2 | 944 | 85 | 360 (2.78 $) | 45 | 490 | 4.2 % | 21 | 34 | 1 027 $ | 27 $ | -249 $ |
| 3 | 1 114 | 100 | 420 (2.38 $) | 59 | 579 | 4.4 % | 25 | 56 | 1 299 $ | 299 $ | 50 $ |
| 4 | 1 314 | 118 | 480 (2.08 $) | 69 | 668 | 4.6 % | 31 | 82 | 1 591 $ | 591 $ | 640 $ |
| 5 | 1 551 | 140 | 540 (1.85 $) | 80 | 760 | 4.8 % | 36 | 113 | 1 913 $ | 913 $ | 1 553 $ |
| 6 | 1 830 | 165 | 600 (1.67 $) | 91 | 856 | 5.0 % | 43 | 149 | 2 269 $ | 1 269 $ | 2 822 $ |
| 7 | 2 160 | 194 | 600 (1.67 $) | 103 | 897 | 5.0 % | 45 | 186 | 2 424 $ | 1 424 $ | 4 246 $ |
| 8 | 2 548 | 229 | 600 (1.67 $) | 108 | 937 | 5.0 % | 47 | 223 | 2 574 $ | 1 574 $ | 5 820 $ |
| 9 | 3 007 | 271 | 600 (1.67 $) | 112 | 983 | 5.0 % | 49 | 262 | 2 738 $ | 1 738 $ | 7 557 $ |
| 10 | 3 548 | 319 | 600 (1.67 $) | 118 | 1 037 | 5.0 % | 52 | 303 | 2 922 $ | 1 922 $ | 9 480 $ |
| 11 | 4 187 | 377 | 600 (1.67 $) | 124 | 1 101 | 5.0 % | 55 | 347 | 3 131 $ | 2 131 $ | 11 611 $ |
| 12 | 4 941 | 445 | 600 (1.67 $) | 132 | 1 177 | 5.0 % | 59 | 393 | 3 370 $ | 2 370 $ | 13 981 $ |
| 15 | 5 720 | 515 | 600 (1.67 $) | 148 | 1 263 | 5.0 % | 63 | 516 | 4 332 $ | 3 332 $ | 23 255 $ |
| 18 | 6 621 | 596 | 600 (1.67 $) | 159 | 1 355 | 5.0 % | 68 | 630 | 5 111 $ | 4 111 $ | 34 780 $ |
| 21 | 7 665 | 690 | 600 (1.67 $) | 171 | 1 461 | 5.0 % | 73 | 745 | 5 671 $ | 4 671 $ | 48 219 $ |
| 24 | 8 873 | 799 | 600 (1.67 $) | 185 | 1 583 | 5.0 % | 79 | 862 | 6 347 $ | 5 347 $ | 63 550 $ |
| 30 | 11 890 | 1 070 | 600 (1.67 $) | 220 | 1 890 | 5.0 % | 95 | 1 108 | 8 309 $ | 7 309 $ | 102 710 $ |
| 36 | 15 934 | 1 434 | 600 (1.67 $) | 267 | 2 301 | 5.0 % | 115 | 1 400 | 10 199 $ | 9 199 $ | 152 868 $ |
Année 1: revenu 25 981 $  après pub 13 981 $  revenu/jour fin d'année 112 $
Année 2: revenu 61 569 $  après pub 49 569 $  revenu/jour fin d'année 212 $
Année 3: revenu 101 318 $  après pub 89 318 $  revenu/jour fin d'année 340 $

### Lecture
- **Pubs actuelles** : pertes jusqu'au mois 4 (≈ −1 300 $ CA au pire), pub remboursée au mois 9, ≈ 60 $/jour fin d'an 1, ≈ 169 $/jour fin d'an 3.
- **Pubs corrigées** : presque à l'équilibre dès le mois 2, remboursée au mois 3, ≈ 112 $/jour fin d'an 1, ≈ 340 $/jour fin d'an 3.
- Corriger les pubs (accroche, fin, honnêteté Premium, gestes réels) **double presque le revenu** : c'est le chantier le plus rentable avant d'augmenter le budget.

### Variante : 2 posts par jour sur TikTok et 2 sur Instagram (contenus séparés)
Hypothèses ajoutées : Instagram démarre plus bas (≈ 450 vues par Reel contre 800 sur TikTok, plafond 12 000 contre 20 000) ; le 2e post du jour et les photos (carrousels) font ≈ 80 % des vues d'une vidéo seule ; publier 2 fois par jour donne +2 points de croissance par mois (plus d'essais, l'algorithme apprend plus vite). La pub payée (1 000 $ CA/mois) ne change pas. La référence ci-dessous est recalculée avec les mêmes règles, d'où un léger écart avec le tableau précédent.

## 1 vidéo/jour TikTok (référence) — Pubs actuelles (pub remboursée au mois 8)
| Mois | Installs organiques | payés | bouche-à-oreille | total | nouveaux payeurs | abonnés | revenu net | après pub | cumul |
| 1 | 48 | 200 | 0 | 248 | 9 | 9 | 422 $ | -578 $ | -578 $ |
| 2 | 57 | 240 | 25 | 321 | 12 | 20 | 594 $ | -406 $ | -984 $ |
| 3 | 67 | 280 | 32 | 379 | 15 | 32 | 754 $ | -246 $ | -1 230 $ |
| 4 | 79 | 320 | 38 | 437 | 18 | 48 | 927 $ | -73 $ | -1 303 $ |
| 6 | 110 | 400 | 50 | 559 | 25 | 87 | 1 334 $ | 334 $ | -849 $ |
| 9 | 180 | 400 | 61 | 642 | 29 | 154 | 1 607 $ | 607 $ | 692 $ |
| 12 | 296 | 400 | 72 | 768 | 35 | 231 | 1 980 $ | 980 $ | 3 227 $ |
| 18 | 397 | 400 | 86 | 884 | 40 | 370 | 3 001 $ | 2 001 $ | 12 945 $ |
| 24 | 532 | 400 | 100 | 1 033 | 46 | 506 | 3 727 $ | 2 727 $ | 27 358 $ |
| 36 | 956 | 400 | 145 | 1 501 | 68 | 822 | 5 988 $ | 4 988 $ | 74 833 $ |
An 1: revenu 15 227 $  après pub 3 227 $  66 $/jour fin d'année
An 2: revenu 36 132 $  après pub 24 132 $  124 $/jour fin d'année
An 3: revenu 59 475 $  après pub 47 475 $  200 $/jour fin d'année

## 1 vidéo/jour TikTok (référence) — Pubs corrigées (pub remboursée au mois 3)
| Mois | Installs organiques | payés | bouche-à-oreille | total | nouveaux payeurs | abonnés | revenu net | après pub | cumul |
| 1 | 72 | 300 | 0 | 372 | 15 | 15 | 723 $ | -277 $ | -277 $ |
| 2 | 87 | 360 | 45 | 492 | 21 | 34 | 1 032 $ | 32 $ | -245 $ |
| 3 | 105 | 420 | 59 | 584 | 26 | 56 | 1 311 $ | 311 $ | 66 $ |
| 4 | 128 | 480 | 70 | 678 | 31 | 83 | 1 614 $ | 614 $ | 679 $ |
| 6 | 187 | 600 | 93 | 880 | 44 | 152 | 2 330 $ | 1 330 $ | 2 960 $ |
| 9 | 331 | 600 | 118 | 1 049 | 52 | 271 | 2 909 $ | 1 909 $ | 8 079 $ |
| 12 | 586 | 600 | 146 | 1 332 | 67 | 418 | 3 778 $ | 2 778 $ | 15 449 $ |
| 18 | 785 | 600 | 183 | 1 569 | 78 | 700 | 5 750 $ | 4 750 $ | 39 477 $ |
| 24 | 1 053 | 600 | 218 | 1 870 | 94 | 982 | 7 381 $ | 6 381 $ | 73 327 $ |
| 36 | 1 800 | 600 | 326 | 2 726 | 136 | 1 651 | 12 024 $ | 11 024 $ | 180 583 $ |
An 1: revenu 27 449 $  après pub 15 449 $  126 $/jour fin d'année
An 2: revenu 69 877 $  après pub 57 877 $  246 $/jour fin d'année
An 3: revenu 119 256 $  après pub 107 256 $  401 $/jour fin d'année

## 2/jour TikTok + 2/jour Insta — Pubs actuelles (pub remboursée au mois 6)
| Mois | Installs organiques | payés | bouche-à-oreille | total | nouveaux payeurs | abonnés | revenu net | après pub | cumul |
| 1 | 120 | 200 | 0 | 320 | 11 | 11 | 544 $ | -456 $ | -456 $ |
| 2 | 143 | 240 | 32 | 415 | 15 | 25 | 767 $ | -233 $ | -689 $ |
| 3 | 170 | 280 | 41 | 491 | 19 | 42 | 977 $ | -23 $ | -712 $ |
| 4 | 202 | 320 | 49 | 571 | 23 | 62 | 1 211 $ | 211 $ | -501 $ |
| 6 | 286 | 400 | 66 | 752 | 34 | 115 | 1 788 $ | 788 $ | 767 $ |
| 9 | 482 | 400 | 89 | 971 | 44 | 213 | 2 402 $ | 1 402 $ | 4 310 $ |
| 12 | 814 | 400 | 119 | 1 333 | 60 | 343 | 3 355 $ | 2 355 $ | 10 321 $ |
| 18 | 1 090 | 400 | 159 | 1 649 | 74 | 618 | 5 202 $ | 4 202 $ | 31 181 $ |
| 24 | 1 461 | 400 | 198 | 2 059 | 93 | 910 | 7 088 $ | 6 088 $ | 62 564 $ |
| 36 | 2 624 | 400 | 321 | 3 345 | 151 | 1 658 | 12 593 $ | 11 593 $ | 169 416 $ |
An 1: revenu 22 321 $  après pub 10 321 $  112 $/jour fin d'année
An 2: revenu 64 244 $  après pub 52 244 $  236 $/jour fin d'année
An 3: revenu 118 852 $  après pub 106 852 $  420 $/jour fin d'année

## 2/jour TikTok + 2/jour Insta — Pubs corrigées (pub remboursée au mois 2)
| Mois | Installs organiques | payés | bouche-à-oreille | total | nouveaux payeurs | abonnés | revenu net | après pub | cumul |
| 1 | 180 | 300 | 0 | 480 | 19 | 19 | 933 $ | -67 $ | -67 $ |
| 2 | 219 | 360 | 58 | 637 | 27 | 44 | 1 336 $ | 336 $ | 270 $ |
| 3 | 268 | 420 | 76 | 764 | 34 | 73 | 1 713 $ | 713 $ | 982 $ |
| 4 | 326 | 480 | 92 | 898 | 41 | 109 | 2 136 $ | 1 136 $ | 2 118 $ |
| 6 | 486 | 600 | 125 | 1 211 | 61 | 203 | 3 197 $ | 2 197 $ | 5 940 $ |
| 9 | 882 | 600 | 178 | 1 660 | 83 | 387 | 4 537 $ | 3 537 $ | 15 081 $ |
| 12 | 1 605 | 600 | 257 | 2 461 | 123 | 651 | 6 810 $ | 5 810 $ | 29 955 $ |
| 18 | 2 150 | 600 | 359 | 3 110 | 155 | 1 240 | 10 587 $ | 9 587 $ | 78 476 $ |
| 24 | 2 882 | 600 | 454 | 3 935 | 197 | 1 876 | 14 874 $ | 13 874 $ | 149 890 $ |
| 36 | 4 433 | 600 | 675 | 5 708 | 285 | 3 418 | 24 895 $ | 23 895 $ | 383 926 $ |
An 1: revenu 41 955 $  après pub 29 955 $  227 $/jour fin d'année
An 2: revenu 131 935 $  après pub 119 935 $  496 $/jour fin d'année
An 3: revenu 246 036 $  après pub 234 036 $  830 $/jour fin d'année


### Variante : 3 vidéos par jour, les mêmes sur TikTok, Instagram et Facebook (9 publications par jour)

**Pas à pas du mois 1 (pubs corrigées)**

1. **Vues.** Sur un même compte, la 2e vidéo du jour fait ≈ 80 % des vues de la 1re et la 3e ≈ 65 %.
   - TikTok : 800 + 640 + 520 = 1 960 vues par jour, × 30 = **58 800**.
   - Instagram : 450 + 360 + 293 = 1 103 par jour, × 30 = **33 075**.
   - Facebook : 400 + 320 + 260 = 980 par jour, × 30 = **29 400**.
   - Total : **121 275 vues** dans le mois.
2. **Installations organiques.** Une vidéo corrigée fait installer 3 personnes pour 1 000 vues (0,3 %).
   - TikTok : 58 800 × 0,003 = 176.
   - Instagram : 33 075 × 0,003 = 99.
   - Facebook : 29 400 × 0,003 × 0,6 = 53. Le facteur 0,6 vient d'un public plus âgé, avec plus d'Android, qui installe moins.
   - Total : **329**.
3. **Pub payée.** 1 000 $ CA ≈ 1 million de vues sponsorisées. À 0,03 % d'installation, cela donne **300 installations**, soit ≈ 3,33 $ CA chacune.
4. **Bouche-à-oreille.** 12 % des installations du mois précédent : 0 au mois 1.
5. **Installations totales :** 629. Avec **4 %** qui paient : **25 nouveaux abonnés**.
6. **Argent net.** Apple garde 15 % ; on compte 1 $ US = 1,38 $ CA.
   - 65 % d'annuels : 16,3 × 59,99 $ US × 0,85 × 1,38 = 16,3 × 70,37 $ CA = **1 150 $ CA**, payés d'avance.
   - 35 % de mensuels : 8,8 × 6,99 × 0,85 × 1,38 = 8,8 × 8,20 $ CA = **72 $ CA**.
   - Total : **1 222 $ CA**, moins 1 000 $ de pub = **+222 $ CA**.
7. **Mois 2.**
   - Des 8,8 mensuels, 35 % partent après leur 1er mois : il en reste 5,7.
   - S'y ajoutent 12,2 nouveaux mensuels : 17,9 mensuels × 8,20 $ = 147 $.
   - Plus 22,7 nouveaux annuels × 70,37 $ = 1 598 $.
   - Total : **1 745 $ CA**.
   - Chaque mois s'ajoute ainsi aux précédents.
   - Départs des mensuels selon leur ancienneté : 35 % après le 1er mois, 20 % après le 2e, 12 % après le 3e, 8 % du 4e au 6e mois, puis 5 % par mois.
   - Les annuels renouvellent à 50 % au 12e mois, puis à 70 %.

**Hypothèses de vues**

| Réseau | 1re vidéo au mois 1 | Croissance par mois, an 1 (pubs actuelles / corrigées) | Puis | Plafond moyen |
|---|---:|---:|---:|---:|
| TikTok | 800 | +19 % / +22 % | +5 % | 20 000 |
| Instagram | 450 | +17 % / +20 % | +5 % | 12 000 |
| Facebook | 400 | +14 % / +17 % | +4 % | 8 000 |

La croissance comprend +2 points par mois : publier 3 fois par jour multiplie les essais.

**Scénario « les vues stagnent »**

Les vues montent de 1 % par mois au plus, avec un plafond de 1 500 vues sur TikTok, 900 sur Instagram et 800 sur Facebook. C'est le cas de beaucoup de comptes qui ne percent pas.

| | Pubs actuelles | Pubs corrigées |
|---|---:|---:|
| Pub remboursée | mois 4 | mois 1 |
| $ par jour, fin de l'an 1 | ≈ 64 $ | ≈ 109 $ |
| $ par jour, fin de l'an 3 | ≈ 126 $ | ≈ 215 $ |

**À savoir**
- **Fichier propre partout.** Une même vidéo peut aller sur les 3 réseaux, mais il faut publier le fichier propre, sans le filigrane TikTok : Instagram et Facebook réduisent la portée d'une vidéo marquée.
- **90 vidéos par mois.** C'est beaucoup. Mieux vaut des séries (même format, sujet différent) que 90 vidéos moyennes, et ne jamais republier la même vidéo sur le même réseau.
- **Plus grande incertitude.** C'est la croissance des vues. Les taux (0,3 %, 4 à 5 %) sont à remplacer par les vrais chiffres après 4 semaines.

## Pubs actuelles — pub remboursée au mois 4
| Mois | Vues/vidéo TT · IG · FB | Vues du mois (3 réseaux) | Installs organiques | payés | bouche-à-oreille | total | % payants | nouveaux payeurs | abonnés actifs | revenu net $ CA | après pub | cumul |
| 1 | 800 · 450 · 400 | 121 275 | 219 | 200 | 0 | 419 | 3.5 % | 15 | 15 | 713 | -287 | -287 |
| 2 | 952 · 526 · 456 | 142 186 | 258 | 240 | 42 | 539 | 3.7 % | 20 | 33 | 998 | -2 | -289 |
| 3 | 1 133 · 616 · 520 | 166 751 | 303 | 280 | 54 | 637 | 3.9 % | 25 | 55 | 1 266 | 266 | -23 |
| 4 | 1 348 · 721 · 593 | 195 618 | 356 | 320 | 64 | 740 | 4.1 % | 30 | 81 | 1 570 | 570 | 547 |
| 5 | 1 604 · 843 · 676 | 229 548 | 419 | 360 | 74 | 853 | 4.3 % | 37 | 112 | 1 921 | 921 | 1 469 |
| 6 | 1 909 · 987 · 770 | 269 440 | 494 | 400 | 85 | 979 | 4.5 % | 44 | 149 | 2 328 | 1 328 | 2 797 |
| 9 | 3 217 · 1 580 · 1 141 | 436 465 | 806 | 400 | 119 | 1 325 | 4.5 % | 60 | 282 | 3 265 | 2 265 | 8 577 |
| 12 | 5 421 · 2 531 · 1 690 | 708 733 | 1 318 | 400 | 167 | 1 885 | 4.5 % | 85 | 466 | 4 718 | 3 718 | 18 128 |
| 18 | 7 265 · 3 392 · 2 139 | 940 479 | 1 755 | 400 | 229 | 2 385 | 4.5 % | 107 | 867 | 7 373 | 6 373 | 50 051 |
| 24 | 9 736 · 4 545 · 2 707 | 1 248 576 | 2 338 | 400 | 291 | 3 029 | 4.5 % | 136 | 1 304 | 10 300 | 9 300 | 97 877 |
| 36 | 17 484 · 8 162 · 4 333 | 2 203 506 | 4 152 | 400 | 482 | 5 034 | 4.5 % | 227 | 2 444 | 18 727 | 17 727 | 260 710 |
An 1: revenu 30 128 $, après pub 18 128 $, 157 $/jour fin d'année
An 2: revenu 91 748 $, après pub 79 748 $, 343 $/jour fin d'année
An 3: revenu 174 834 $, après pub 162 834 $, 624 $/jour fin d'année

## Pubs corrigées — pub remboursée au mois 1
| Mois | Vues/vidéo TT · IG · FB | Vues du mois (3 réseaux) | Installs organiques | payés | bouche-à-oreille | total | % payants | nouveaux payeurs | abonnés actifs | revenu net $ CA | après pub | cumul |
| 1 | 800 · 450 · 400 | 121 275 | 329 | 300 | 0 | 629 | 4.0 % | 25 | 25 | 1 222 | 222 | 222 |
| 2 | 976 · 540 · 468 | 145 824 | 396 | 360 | 75 | 832 | 4.2 % | 35 | 57 | 1 745 | 745 | 967 |
| 3 | 1 191 · 648 · 548 | 175 392 | 478 | 420 | 100 | 998 | 4.4 % | 44 | 95 | 2 236 | 1 236 | 2 203 |
| 4 | 1 453 · 778 · 641 | 211 013 | 577 | 480 | 120 | 1 176 | 4.6 % | 54 | 142 | 2 797 | 1 797 | 4 000 |
| 5 | 1 772 · 933 · 750 | 253 938 | 696 | 540 | 141 | 1 377 | 4.8 % | 66 | 198 | 3 455 | 2 455 | 6 456 |
| 6 | 2 162 · 1 120 · 877 | 305 678 | 840 | 600 | 165 | 1 605 | 5.0 % | 80 | 266 | 4 232 | 3 232 | 9 688 |
| 9 | 3 926 · 1 935 · 1 405 | 534 026 | 1 478 | 600 | 245 | 2 323 | 5.0 % | 116 | 521 | 6 319 | 5 319 | 23 343 |
| 12 | 7 129 · 3 344 · 2 250 | 935 100 | 2 607 | 600 | 369 | 3 576 | 5.0 % | 179 | 904 | 9 837 | 8 837 | 45 911 |
| 18 | 9 554 · 4 481 · 2 846 | 1 240 760 | 3 471 | 600 | 530 | 4 601 | 5.0 % | 230 | 1 785 | 15 383 | 14 383 | 118 855 |
| 24 | 12 803 · 6 005 · 3 602 | 1 647 093 | 4 624 | 600 | 679 | 5 903 | 5.0 % | 295 | 2 753 | 22 092 | 21 092 | 226 930 |
| 36 | 20 000 · 10 783 · 5 766 | 2 686 399 | 7 551 | 600 | 1 089 | 9 240 | 5.0 % | 462 | 5 221 | 39 023 | 38 023 | 588 900 |
An 1: revenu 57 911 $, après pub 45 911 $, 328 $/jour fin d'année
An 2: revenu 193 019 $, après pub 181 019 $, 736 $/jour fin d'année
An 3: revenu 373 970 $, après pub 361 970 $, 1 301 $/jour fin d'année

## 5. Actions, dans l'ordre
1. Contrat « Paid Applications », mise en vente, questionnaire « App Privacy ».
2. Corriger les pubs : affiche-09 et post-feed-11 ; refaire la principale en 25-30 s ; fin « Télécharge Ardane gratuitement » partout ; pastille Premium lisible ; un plan avec un style gratuit ; un geste réel par pub.
3. Publier d'abord : scan, nutrition, papier, planning, budget, finances, voyage ; puis 4 à 6 fadein rallongés.
4. App : faire revenir l'offre de bienvenue après « Plus tard » ; compléter le tableau de l'offre ; protéger le compteur de scans contre la réinstallation.
5. Mesurer dès la semaine 1 (liens de campagne App Store Connect) et remplacer les hypothèses par les vrais chiffres après 4 semaines.

---
## Annexe A : inventaire technique Gratuit / Premium (avec les références du code, en anglais)
# Ardane: free vs Premium, from the code (2026-11-27)

Paths relative to repo root. "Free" = no purchase. Premium = `AppModel.isPremium` (`App/Core/AppModel.swift:259`), true only with a real StoreKit entitlement (`Shared/Model/Settings.swift:237-258`; DEBUG and `[interne]` builds are always true, never Release).
No hard paywall anywhere: the whole app opens free; Premium is a set of locks + limits.

## 1. Global limits for a free user

| Thing | Free | Premium | Where |
|---|---|---|---|
| Saved widgets (non photo/quote) | 3 | unlimited | `AppModel.swift:12`, `:287`, `:280` (`fitsFreePlan`) |
| Photo and quote widgets | unlimited, do not count | same | `AppModel.swift:278` (`countsTowardFreeLimit`), `PhotoQuote.swift:409` |
| A combo counts if any part is not photo/quote | yes | n/a | `AppModel.swift:279` |
| Already over the limit (old Premium, backup) | keeps all, can only delete/merge | | `AppModel.swift:280` (`after <= now`) |
| Habits | 3 (adding refused, paywall `.habitLimit`) | unlimited | `AppModel.swift:13`, `:506-514`; `PaywallContext.swift:47` |
| Dish photo analyses | 10 total, lifetime (counted only if something is found) | unlimited | `ScanQuota.swift:7`; `FoodScanView.swift:119`, `:431` |
| Barcodes, food search | unlimited | same | `ScanQuota.swift:3`; `PaywallContext.swift:69` |
| Widget TYPES (kinds) | 29 of 90 offered | 90 | counted from `KindCatalog.swift:118-277` isPremium flags, retired excluded (`WidgetKind.swift:152`); `PaywallView.swift:204` |
| Widget styles ("Style" tool) | 4 (Minimal, Clair, Sombre, Monochrome) | 504 (500 Premium) | `StyleLibrary.swift:48`; `Theme.swift:105-130`; `StyleLibraryData.swift` (500 entries) |
| Main accent colors in Studio | 8 | any (color picker) | `Palette.swift:13-22`; `StudioPanels.swift:340-351` |
| App color (whole app) | 1 (Saphir) of 14 | 14 | `Settings.swift:47-54`; `AppModel.swift:714-716`; `StylePicker.swift:85-89` |
| Light/Dark/Auto mode | free | | `StylePicker.swift:115-123` |
| Widget background | theme only (`.theme`); color, gradient, photo, glass = Premium | | `WidgetDesign.swift:16` |
| Fonts | theme, Standard, Arrondie; Serif, Mono, any named font = Premium | | `WidgetDesign.swift:43`, `WidgetStyle.swift:604` |
| Custom colors, gradient, texture, border, shadow/depth, per-line colors, palettes | Premium | | `WidgetStyle.swift:596-606`; `StudioPanels.swift:368,397,412,481`; `EditorView.swift:728,862` |
| App icons | main icon only (1 of 20); the icon currently set is kept but cannot be re-picked once left | all 20 | `AppIcons.swift:24-30`; `AppIconPicker.swift:68-79` |
| Store wallpapers | 14 free of 43 | all | `WallpaperCollection.swift:66-75` (`free: true` count); `:292` |
| Ready-made Home Screens (24 in `HomeSetups.all`) | free if every widget of it is free-kind + free theme/accent; else Premium | | `HomeSetups.swift:34,221`; `HomeSetupViews.swift:580` |
| Packs (32) | free if theme, kinds and accent all free | | `Packs.swift:34-37` |
| Store templates and combos | Premium if kind/theme/background/font/accent is Premium | | `Templates.swift:29-32`; `StoreCombos.swift:47` |
| Combos in Studio | free, but locks per part kind (Premium kind = Premium combo) | | `Combo.swift:227`; `WidgetDesign.swift:159` |
| Lock Screen widgets | free kinds only; Premium kinds show a lock | | `WidgetCanvas.swift:128-132` |
| Interactive widgets | see section 3 | | |
| Live Activity (workout, study) | free, with buttons (no gate in code) | | `Shared/Live/*` (no isPremium); `Decisions.md:174` |
| Nutrients tracked | 4 (kcal, protein, carbs, fat) of 38 | 38 | `Nutrition.swift:146,185`; `NutrientViews.swift:6` |
| Finance history | current month + last 7 days; chart "Mois" only | all months, 3 mois, Année | `PremiumLock.swift:50-54`; `FinancesApp.swift:713-731` |
| Backup restore | capped to free limits | | `AppModel.swift:733-746` |

## 2. Per mini-app (MiniApp.offered = 8; Auto removed, `MiniApp.swift:9`)

| Mini-app | Free | Premium | Where |
|---|---|---|---|
| Nutrition | log by barcode (unlimited), food search, 10 dish photo analyses, calories/protein/carbs/fat + goals, today and week view, custom foods, weight plan | unlimited dish analyses; all other nutrients (fiber, sugars, fats, minerals, vitamins) in food sheets and targets; history 7/30 days/custom (averages, charts, macro split, weight chart); fiber ideas | `FoodScanView.swift:119,249-250,383,418`; `NutritionPages.swift:212-221,275,418,442,456,542-573,926`; `NutrientViews.swift:14-35`; `NutritionTargetsCard.swift:79,139`; `NutritionSpace.swift:501,508,660` |
| Fitness | routines, sessions, own written exercises, sets, Live Activity, rest alert, week count/volume figures on summary | exercise library (every exercise, sheet, demo, history, records); "Choisir dans la bibliothèque"; Progression page (volume, loads, records); "Meilleur record" row | `ExerciseLibrary.swift:597`; `ExerciseLibraryViews.swift:54,578,717`; `FitnessApp.swift:508-524`; `FitnessPages.swift:298-300`; `FitnessSession.swift:114,283,561`; `FitnessSpace.swift:90-103,175` |
| Planning / Tasks / Habits | tasks, calendar, classes typed by hand, 3 habits, 30-day % in habit grid, streak | import timetable from photo/PDF; habit week card; "Bilan" (regularity, 90 days, best streak); >3 habits | `PlanningApp.swift:153-180`; `ScheduleImportView.swift:167,212-222`; `HabitsApp.swift:143,203-244,481-485,572-573`; `HabitsView.swift:50-61` |
| Études | courses, exams, grades, deadlines, Live Activity | import timetable from photo/PDF (badge, lock card) | `StudiesApp.swift:183`; `StudiesPages.swift:343`; `ScheduleImportView.swift:167` |
| Finances | expenses/income, budget, savings, current month, last 7 days of statement, balance chart "Mois" | months before current (statement, categories, cascade), chart 3 mois/Année, "Analyse" page (6 months, averages, comparison), Apple Pay auto-import (FinanceKit) | `FinancesPages.swift:88,104,122,445,546,1100-1106`; `FinancesApp.swift:436,713-731`; `FinancesApplePay.swift:216,255-270`; `WalletImport.swift:67,103` |
| Business | manual entry, year totals, this month | month-by-month chart and list, CSV import, Stripe connect and sync (an already-connected Stripe keeps its imported sales, can disconnect) | `BusinessPages.swift:159-221`; `BusinessSources.swift:39-109`; `StripeSync.swift:151`; `Decisions.md:129` |
| Investing / Markets | no mini-app screen of its own; watchlist widget free | crypto, portfolio, allocation, top mover, market overview, 4 company widgets (snapshot, revenue, stock, compare) are Premium kinds | `KindCatalog.swift:198-203,221-224` |
| Travel | trips, countdown, local time widget (free kinds) | flight, hotel, currency, trip progress, next activity widgets | `KindCatalog.swift:243-249`; no gate in `Travel/*.swift` |
| Car | removed from the app (old data still reads) | all car widgets retired | `MiniApp.swift:9`; `WidgetKind.swift:152` |
| Photos and quotes | unlimited photo/quote widgets; 8 accent swatches + text color for quotes | 10 flat background swatches and free "Fond" color picker for quotes (picker is `.disabled` for free) | `PhotoQuotesApp.swift:129-143,770-790`; `PhotosHybrid.swift:219`; `Palette.swift:25-36` |
| Mon Quotidien (Home) | everything on the page | gold "Premium" pill next to title and `PremiumBanner` card (free only); Premium kinds in daily blocks shown as sample data | `DailySection.swift:113-115,1793`; `HomeView.swift:90-91,171` |
| Profile / settings | profile, units, 24 h clock, reminders, light/dark, Saphir color, backup, restore purchases | other 13 app colors, icon picker (20 icons), micronutrient targets, "Voir l'offre de bienvenue" (DEBUG/INTERNAL builds only) | `ProfileView.swift:96-111,392-398,453-500`; `AppIconPicker.swift`; `NutritionTargetsCard.swift:71-80`; `Settings.swift:47` |

## 3. Widgets

Counts from `KindCatalog.swift` (field `isPremium`); retired and photo/quote excluded. 29 free, 61 Premium.

FREE kinds (29): clock, calendar, progress, countdown, birthday, weekView, holiday, moonPhase (`:118-128`); tasks, note, upNext, counter (`:134,137-139,143`); habits, habitStreak (`:135,150`); caloriesLeft (`:158`); todaysWorkout, trainingStreak (`:171,176`); balance, budgetLeft, savingsGoal, quickExpense (`:185,186,189,192`); revenueGoal (`:209`); watchlist (`:202`); nextClass, nextExam, semesterProgress, timetable (`:230,231,234,237`); tripCountdown, localTime (`:243,246`).

PREMIUM kinds (61): worldClock, yearDots, ageProgress; focus, project, deadline, deepWork; habitWeek, habitRate; macros, proteinLeft, mealsToday, nextMeal, nutritionWeek, nutritionStreak, quickFood; nextSet, restTimer, weeklyVolume, personalRecords, caloriesBurned, workoutMonth; moneyFlow, spendingByCategory, billsUpcoming, netWorth, subscriptions; revenueTrend, profit, businessKPIs, mrr, businessDashboard, revenueToday; crypto, portfolio, allocation, topMover, marketOverview; companySnapshot, companyRevenue, companyStock, companyCompare; assignments, gradeAverage, studyHours, flashcard; flight, hotel, currency, tripProgress, nextActivity; dashboards myDay, now, morning, fitnessDashboard, moneyDashboard, studentDashboard, aiSummary, aiNutrition, aiFinance, aiProductivity (`KindCatalog.swift:120,123-124,136,140-142,151-152,159-165,172-178,184-191,210-215,198-203,221-224,232-236,244-249,265-274`).

What a free user sees on a Premium widget:
- On the Home Screen: `PremiumLockedView` = kind icon, kind title, gold "Premium" lock capsule, "Touche pour débloquer ce widget" (not on small); Lock Screen sizes show only a lock. Tap opens the paywall (`tessera://premium`). `WidgetCanvas.swift:26,123-157,162`; `DeepLink.premium` handled `Router.swift:160-161`. No real data, no sample data, no buttons.
- Widget gallery (not yet configured): shown fully with sample data, `isPremium: true` (`DesignProvider.swift:25,35`; `QuickWidget.swift:29`). So the iOS gallery previews every Premium widget for free; placing it gives the lock.
- Inside the app: `WidgetPreview` always draws with `isPremium: true` (`UIComponents.swift:63`), payload = sample data (never the person's own) for Premium kinds (`AppModel.swift:578`; `DataItems.swift:452`).
- A saved widget whose Premium LOOK lapsed (theme/background/font/accent/effects) shows on the Home Screen as the free look, same content (`WidgetDesign.swift:172-181`; `WidgetCanvas.swift:15`).

Interactive widgets (button on the widget):
- Free AND interactive: tasks, habits, counter, quickExpense (`KindCatalog.swift:134,135,143,192`; decided `Decisions.md:165`). Note habitStreak's "Fait" button, record and 90-day rate are Premium (`ProductivityTiles.swift:148-158`).
- Premium interactive: focus, project, quickFood, nextSet, restTimer, assignments, flashcard (`KindCatalog.swift:136,140,164,172,173,232,235`).
- Nutrition scanner button on the widget: free only on caloriesLeft; the other 6 scan-kinds are Premium kinds (`NutritionTiles.swift:7,57-59`).
- todaysWorkout "Commencer" free (`Decisions.md:174`); macros fiber line Premium (`NutritionTiles.swift:47`).

## 4. Studio and Store: what is free, and exactly how Premium is previewed

Free in Studio (everything is usable; only SAVING is gated):
- Size, Content, Style, Colors, Text, Background, Border, Chart, Density, "Mes styles" tools (`StudioComponents.swift:6`).
- A free user can pick ANY of the 504 styles (tile shows a gold lock but is tappable): `StudioPanels.swift:271-290`. Same for Premium colors, palettes, backgrounds, fonts, textures, borders, Premium widget kinds in the picker (`StudioParts.swift:535-548`). Sections are only badged (`EditorSection isPremium`, `EditorView.swift:1293-1306`; `StudioPanels.swift:368,397,412,481,569`).
- The stage preview shows the Premium result in full; sample data for Premium kinds. "Sur mon écran" (eye button) opens a fullscreen Home Screen mock with the Premium widget, also for free (`EditorView.swift:268-271,333-345`).
- Locked: Save. `needsPremium` = any Premium feature in any widget (`EditorView.swift:118`). Banner "Ce widget utilise Premium" + "Débloquer" button (`:296,668-686`); save button reads "Débloquer et enregistrer" (`:903`); tapping save opens the paywall with the widgets as they will look (`:1184-1187`). Over the 3-widget limit: banner `limitNotice`, locked widgets not saved (`:298,693-711`).
- Free-plan save of a free-looking widget works until the 3rd; `model.fitting` keeps the first ones (`AppModel.swift:292-302`).

Try-before-buy flows (no timed trial of Premium features exists; the only trial is the 7-day StoreKit trial):
1. Studio as above: Store style tap opens the Studio on a demo widget in that style ("Touche un style pour l'essayer sur un widget", `ExploreView.swift:474-514`); templates and combos open the Studio with `isNew: true` (`ExploreView.swift:412,433,698`).
2. Pack sheet: full previews of every widget of the pack (data example flagged "Exemple"), button reads "Débloquer avec Premium" -> paywall `.pack` with the widgets shown (`ExploreView.swift:787-842`; `PaywallContext.swift:116`).
3. Home Screen sheet (Store "Écrans"): carousel previews rendered `isPremium: true` (`HomeSetupViews.swift:343-345`); button "Débloquer avec Premium" -> paywall `.setup` with the widgets (`:580,652-655,763`).
4. Wallpapers: full-size preview, save-to-Photos locked for Premium ones; paywall "Les fonds d'écran Premium" (`WallpaperCollection.swift:292,300,355-372`). A Premium setup's wallpaper is locked too (`HomeSetupViews.swift:771-780`).
5. Saved looks: "Appliquer" sheet shows each widget restyled; on tap with a Premium look it changes nothing and opens the paywall with those restyled widgets (`StudioPanels.swift:778-835`; `AppModel.swift:445-475`).
6. Paywall itself (when opened with a context) shows the widgets as they will look (`PaywallView.swift:131-149`).
7. App colors and app icons: lock badge, tap = paywall; NO preview before buying (`StylePicker.swift:86-89`; `AppIconPicker.swift:27,111`).
8. Lock cards (analytics, library, history) say data is kept and appears with Premium; no sample of the locked chart (`PremiumLock.swift:5-48`).

Store filters: chips "Tous / Gratuits / Premium" for templates, combos, packs, setups (`ExploreView.swift:84-100,582-611`). Premium badges appear on tiles for free users only (`UIComponents.swift:97-110,261,308`; `StoreMagazine.swift:92,219,306,648`; `StoreCombos.swift:251,364`; `StoreShowcase.swift:262`).

## 5. Paywall entry points

All open `PaywallView(context:)` (`App/Premium/PaywallView.swift`). Context = title/detail/symbol/widgets + highlighted perk (`PaywallContext.swift`).

| Where | Context | File:line |
|---|---|---|
| Onboarding offer, last step (free only) | `OnboardingOffer` (no context) | below |
| Home: gold "Premium" pill by title | general | `DailySection.swift:113-115` |
| Home: `PremiumBanner` card at bottom (free only) | general | `HomeView.swift:90-91` |
| Profile: "Passer à Premium" row | general | `ProfileView.swift:468-471` |
| Widget on Home Screen (tap) | `tessera://premium` general | `WidgetCanvas.swift:162`; `Router.swift:160` |
| Studio: Débloquer banner and Save | `.designs(...)` "Débloque ce widget" | `EditorView.swift:681,1186` |
| Studio / My Widgets / Photos / Create: over 3 widgets | `.designLimit` "Plus de 3 widgets" | `EditorView.swift:693,1186`; `MyWidgetsView.swift:322,331,373,459`; `PhotoQuotesApp.swift:131,143`; `CreateFlow.swift:302` |
| My Widgets: "Illimité" button in the "x sur 3 widgets gratuits" bar | `.designLimit` | `MyWidgetsView.swift:363-376` |
| Merge widgets with Premium look | `.designs([merged])` | `MyWidgetsView.swift:451-459` |
| 4th habit (7 places) | `.habitLimit` | `HabitsApp.swift:124,299`; `HabitsView.swift:61,308`; `DataItemViews.swift:148`; `ProfileTopics.swift:845,857` |
| Dish scan: shutter or gallery after 10 | `.photoScanLimit` | `FoodScanView.swift:250,383,418` |
| Premium nutrients (rows, targets) | `.nutrients` | `NutrientViews.swift:22`; `NutritionTargetsCard.swift:141` |
| Exercise library (many) | `.exerciseLibrary` | `ExerciseLibraryViews.swift:57,224,249,417`; `FitnessSession.swift:114,130`; `FitnessSpace.swift:175,205`; `FitnessPages.swift:247` |
| Fitness record row | `.fitnessProgress` | `FitnessSpace.swift:94` |
| Finances: earlier month, older ops, 3 mois/Année | `.financesHistory` | `FinancesPages.swift:104,122,445,546`; `FinancesApp.swift:716` |
| Apple Pay auto import | `.walletImport` | `FinancesApplePay.swift:270` |
| Business CSV / Stripe | `.businessImport` / `.stripeConnection` | `BusinessSources.swift:68,89,103` |
| Any `PremiumLockCard` ("Découvrir Premium") | card's own words | `PremiumLock.swift:28-31` |
| Store pack, Home Screen setup, wallpaper | `.pack`, `.setup`, wallpaper | `ExploreView.swift:828`; `HomeSetupViews.swift:763,775`; `WallpaperCollection.swift:368` |
| Applying a Premium saved look | `.designs(restyled)` | `StudioPanels.swift:822` |
| Quote background color | "Couleurs de fond" | `PhotoQuotesApp.swift:772` |
| App color grid | "Toutes les couleurs de l'app" | `StylePicker.swift:88,102` |
| App icons | "Toutes les icônes de l'app" | `AppIconPicker.swift:27,77` |

Onboarding offer (`App/Premium/OnboardingOffer.swift`; "Vitrine", PDG 2026-11-23):
- When: end of FIRST setup only, after the permissions page, only when not Premium; never for style-only or personalization-only runs (`OnboardingView.swift:31-48,86-92`). Order: style, identity, interests, topics, permissions, offer. Never blocking: "Plus tard" (`OnboardingOffer.swift:104-112`) and "Restaurer" (`:90-102`).
- Shows: 3 real small widgets of the person's interests with a "+ 500 styles" chip (`premiumCount`) (`:123-146`), title "Tout Ardane, 7 jours gratuits" (or "sans limite" if no trial available) (`:71-86`), 3 perks: "Widgets illimités, tous les types", "504 styles et 14 couleurs d'app", "Statistiques, exercices, scans illimités" (`:31-33`).
- Plans shown: yearly (default, with "-28 %" badge computed, price, "x par mois") and monthly side by side; lifetime never (`:18,198-238`).
- Button "Essayer 7 jours gratuits" + terms line under it (`:277-292`).
- Also reachable later only in DEBUG/INTERNAL builds: Profile "Voir l'offre de bienvenue" (`ProfileView.swift:496-499`). A Release free user who taps "Plus tard" never sees this screen again.

Gold badge: `PremiumBadge` (A glyph on gold capsule, compact or with "Premium") on tiles/rows for free users only (`UIComponents.swift:97-110`). `PremiumGoldBadge` pill next to Home title (`DailySection.swift:1793-1818`). Profile shows "Version gratuite" vs "Ardane Premium" with gold A (`ProfileView.swift:392-398`).

## 6. Products and prices

`App/Premium/PremiumConfiguration.swift:6-10`; local test file `Config/Ardane.storekit`.
| ID | Price in config | Trial | Line |
|---|---|---|---|
| `com.dakrsnyk.ardane.premium.monthly` | 6.99 / month | 7 days free (P1W) | `Ardane.storekit:36-52` |
| `com.dakrsnyk.ardane.premium.yearly` | 59.99 / year (5.00 per month; -28 % vs 12 months) | 7 days free (P1W) | `:61-77` |
| `com.dakrsnyk.ardane.premium.lifetime` | 99.99 non-consumable | none | `:6-16` |
- Trial: once per Apple account for the whole group; paywall only promises it when `isEligibleForIntroOffer` (`PremiumStore.swift:22,69-77,244-247`). Yearly is preselected (`PaywallView.swift:12`).
- Real prices come from App Store Connect; `Decisions.md:34` says lifetime is NOT created there (monthly 6.99 and yearly 59.99 only). Paywall shows lifetime only if the store returns it (`PaywallView.swift:343-347`).
- Access rules: subscription until its date + billing grace; expired/revoked = no access; clock set back = not Premium until re-verified (`PremiumStore.swift:174-216`; `Settings.swift:225-234`).

## 7. Inconsistent or surprising

1. Free can build and preview ANY Premium look and Premium kind (with sample data) in the Studio and "Sur mon écran"; the only gate is Save. Strong "try" but no reminder until Save. `EditorView.swift:118,1184`.
2. Lifetime: present in `Ardane.storekit` ($99.99) and in code, but not planned for the store (`Decisions.md:34`). Local StoreKit tests show 3 plans; production shows 2. Onboarding never shows it.
3. Free dish-scan counter (10) lives in the App Group data files only. Reset-all and restore keep it (`AppModel.swift:756-813`; `DataBackup.swift:65-76`), but deleting and reinstalling the app very likely gives 10 more (no keychain/iCloud store found in `ScanQuota.swift`).
4. A lapsed Premium user: Home Screen shows free-look downgrade (`downgradedForFree`) while in-app previews still show the Premium look (`UIComponents.swift:63` always `isPremium: true`). Looks fine in the app, different on the Home Screen.
5. Premium-kind widget saved earlier then Premium lapses: widget turns into a lock tile showing no data at all, not even sample data (`WidgetCanvas.swift:26`).
6. Quote background "Fond" ColorPicker is silently `.disabled` for free (no paywall on tap), while locked swatches open the paywall (`PhotoQuotesApp.swift:785-788`).
7. App colors and app icons: no preview before buying (tap = paywall). `StylePicker.swift:86-89`.
8. Paywall comparison table omits: dish scans (10), app icons, wallpapers, nutrients (34 Premium), Stripe/CSV/timetable/Apple Pay imports, 3-habit limit is listed (`PaywallView.swift:204-213`). "Types de widgets" counts 29 vs 90 but excludes photos/quotes. Home banner says "61 widgets en plus, 500 styles" (`HomeView.swift:186`) while the offer says "504 styles" (`OnboardingOffer.swift:32` uses `StyleCatalog.all.count`, which includes the 4 free ones).
9. Free user sees Premium Studio sections open and editable; a custom per-line color picker is also free to touch (`StudioPanels.swift:108-114`) and is only caught at save via `rowColors`.
10. Premium badge on "Analyse" row etc. is shown, but the page opens with a lock card plus free `FinancesBudgetSections` (`FinancesPages.swift:1100-1106`): partly useful, partly empty.
11. Interactive-widget rule (free = interactive only for tasks, habits, counter, quickExpense) is data-driven by kind, so the free "Habitudes" widget stays interactive though habits are capped at 3. `KindCatalog.swift:135`.
12. Old Premium themes (Aurore, Néon…) are no longer selectable in the Studio (replaced by the Style tool); only existing widgets keep them (`Decisions.md:169`). The 4 free ones plus six formerly free (Moderne, Carte, Doux, Compact, Sous-bois, Glacier) are now Premium (`Theme.swift:213-250,482,523`).
13. `Shared/Model/ArdaneThemes.swift` is untracked in git (git status); not used for the counts above.
14. Not verified: count of free Home Screens (24 total) and free packs (32 total); both are computed at runtime from `isPremium` of their widgets (`HomeSetups.swift:34`, `Packs.swift:34`). Combos and templates likewise.

---
## Annexe B : revue détaillée des vidéos (lot 1)
# Revue marketing part00 (21 vidéos)

Limites : revue faite sur 12 images par vidéo, sans le son ni la voix. Les durées, la voix et les sous-titres entre deux images ne sont pas évalués. Les images fixes de 0 à 1 s sont parfois noires (fondu), donc l'accroche est jugée sur ce qui apparaît à 1-3 s.

Repères Premium (inventaire) : gratuits = calories restantes, habitudes (3 max), série d'habitudes, tâches, budget restant, objectif de revenu, quick expense, compte à rebours de voyage, prochain cours, séance du jour, 4 styles. Premium = Homework (assignments), ventes 30 jours, profit, indicateurs, trip « Day 4 » (progression de voyage), macros, bibliothèque d'exercices, minuteur de repos, flashcards/minuteur d'étude, moyenne des notes, 500 styles.

### main-pub-all-your-essentials-v2.5 — 56.0 s
- Accroche (0-3 s) : icône calendrier + « PLANNING / Your life isn't one thing. » sur noir, puis une image grise vide (transition). Phrase intrigante mais abstraite, pas de personne. Note 3/5.
- Message principal / public : « tout sur ton écran d'accueil » (sport, nutrition, planning), public large. Promesse floue (liste de domaines).
- Fonctions montrées : séance Full body, minuteur de repos, volume, calories, macros, bibliothèque de 163 exercices, fiche Squat, habitudes, planning. Beaucoup sont Premium. Les mentions « With Premium » existent (en haut à droite des écrans, pied de page « Some widgets and styles With Premium ») mais minuscules. La bibliothèque d'exercices, le minuteur de repos et le widget Macros sont présentés comme l'app de base : risque de promesse trompeuse modéré.
- Lisibilité, rythme, fin : titres d'écran lisibles, mentions Premium illisibles sur téléphone. 56 s est deux à quatre fois trop long pour du organique. Écran gris vide à ~5 s. Fin : « Make everyday your own. » puis logo seul, sans « Available on the App Store ».
- Note globale 5,5/10. Correction n° 1 : couper à 25-30 s (garder Fitness + Planning + style) ou en faire un format « pub payante » séparé, et ajouter un CTA store.

### pub-organique-accueil-v1 — 20.3 s
- Accroche : « Your Home Screen is boring. » sur écran d'accueil iOS vanille. Question-constat claire, mais texte en haut, assez petit, sans personne. Note 3,5/5.
- Message / public : personnaliser son écran d'accueil (cible large, jeune). Une promesse nette.
- Fonctions : calories, habitudes, budget gratuits ; styles Neon, Pastel, Light et vote 1-2-3. Mentions « Some widgets and styles With Premium » en tout petit. Neon, Pastel = Premium ; honnête mais illisible.
- Lisibilité, rythme, fin : titres bleus lisibles ; sous-ligne Premium trop petite. Rythme régulier, un « Which one are you? » répété (deux images identiques, temps mort). Fin avec logo et « AVAILABLE ON THE APP STORE » : bon. Ardane n'apparaît qu'à ~19 s (app identifiable trop tard).
- Note globale 6,5/10. Correction n° 1 : montrer le nom ou l'icône Ardane dès 2-3 s et agrandir la mention Premium.

### pub-organique-affiche-03-v1 — 10.0 s
- Accroche : « Can I still have dessert tonight? » texte seul sur noir orange pendant les 3 premières images (~3 s), pas de visuel. Question forte (public nutrition) mais 3 s de texte statique. Note 3/5.
- Message / public : calories restantes en un coup d'œil ; public suivi alimentaire.
- Fonctions : widget calories (gratuit), bouton Scan (10 analyses gratuites). Styles Dark gratuit, Neon et Blossom « With Premium » en petite pastille.
- Lisibilité, rythme, fin : texte gros et contrasté, bon. Mais 10 s : la démonstration du geste est absente (aucun tap, juste un zoom). Fin : logo + « AVAILABLE ON THE APP STORE ».
- Note globale 6/10. Correction n° 1 : faire apparaître le téléphone dès 1 s et montrer un geste (scan d'un dessert).

### pub-organique-affiche-04-v1 — 10.0 s
- Accroche : « How much can I still spend today? » sur noir/vert, même structure : 3 s de texte seul. Question utile. Note 3/5.
- Message / public : budget restant du jour (étudiants, jeunes actifs).
- Fonctions : widget « Left this month $1,631 / $148 per day » (gratuit). Styles Dark, Minimal gratuits ; Aurora « With Premium ».
- Lisibilité, rythme, fin : bon contraste ; zoom sur le widget lisible. Pas de geste. Fin CTA App Store OK.
- Note globale 6,5/10. Correction n° 1 : même correction que affiche-03 (visuel dès 1 s, un geste).

### pub-organique-affiche-06-v1 — 10.0 s
- Accroche : « Did I read today, or just think about it? » texte seul pendant ~3 s. Relatable, plus long à lire (3 lignes). Note 3/5.
- Message / public : suivi d'habitudes (lecture, méditation, fitness).
- Fonctions : widget Habits (gratuit jusqu'à 3 habitudes : exactement les 3 montrées, bien). Styles Aurora et Pastel « With Premium ».
- Lisibilité, rythme, fin : texte OK ; les points colorés du widget sont trop petits à lire. Un cercle de tap apparaît sur « Reading » (début de geste) mais flou. CTA OK.
- Note globale 5,5/10. Correction n° 1 : agrandir le widget sur toute la largeur et montrer un tap net qui coche l'habitude.

### pub-organique-battle-v1 — 23.1 s
- Accroche : « Your home screen: Light or Neon? » avec deux téléphones « vs ». Visuel immédiat, format vote (engagement commentaire). Note 4/5.
- Message / public : choisis ton style (jeunes, personnalisation) ; appel à commenter.
- Fonctions : 3 manches (Light/Neon, Dark/Aurora, Minimal/Blossom), Studio « Pick yours in the Studio ». Neon, Aurora, Blossom étiquetés « With Premium » (étiquette claire sur chaque manche) ; pied « Neon, Aurora and Blossom: With Premium ». Honnête.
- Lisibilité, rythme, fin : textes lisibles, rythme de manches clair. « Which one wins? Comment your pick » : CTA d'engagement, mais pas d'appel à télécharger avant le logo final.
- Note globale 7,5/10. Correction n° 1 : ajouter « Available on the App Store » et ne montrer qu'une seule image fixe pour le vote (deux images quasi identiques).

### pub-organique-budget-v1 — 22.2 s
- Accroche : « How much can you still spend this month? $1,961 – Guess before it stops. » avec compteur qui tourne. Jeu, curiosité, très bon. Note 4,5/5.
- Message / public : budget restant du mois, tap pour logger un café (quick expense).
- Fonctions : budget restant, quick expense (« Coffee? One tap. » : le montant passe de $125.99 à $130.49 et le solde se met à jour), écran verrouillé, Studio, styles Dark (gratuit), Aurora (« With Premium », libellé net). Tout gratuit sauf Aurora. Le widget Lock Screen « Left this month » est un type gratuit : OK.
- Lisibilité, rythme, fin : excellente lisibilité, geste réel démontré. « What's left, before you unlock » bonne idée. CTA App Store final.
- Note globale 8/10. Correction n° 1 : le téléphone de la première image est petit, l'agrandir et vérifier que le compteur est lisible dès 1 s.

### pub-organique-business-v4 — 20.8 s
- Accroche : photo d'un commerçant qui compte des pièces + « How much did you make this month? ». Personne + question, accroche humaine. Note 4,5/5.
- Message / public : indépendants et petits commerçants, suivre ses revenus.
- Fonctions : objectif mensuel (gratuit), puis ventes 30 jours, profit, indicateurs (tous Premium). Mentions « Sales over 30 days With Premium », « Profit widget With Premium », « Indicators widget With Premium » en tout petit sous le titre. Honnête mais minuscule, et 4 écrans sur 6 sont Premium : le spectateur gratuit verra surtout du payant.
- Lisibilité, rythme, fin : titres violets lisibles, rythme bon. Fin : photo café + « know your numbers. » en petit et minuscules, puis logo + CTA App Store.
- Note globale 7,5/10. Correction n° 1 : agrandir la mention Premium ou montrer l'objectif gratuit plus longtemps, et corriger « know your numbers. » (petit, en minuscules).

### pub-organique-cours-v1 — 24.8 s
- Accroche : main tenant un téléphone noir + « What's my first class tomorrow? ». Personne + question, puis écran verrouillé. Note 4/5.
- Message / public : étudiants, réponse avant de déverrouiller.
- Fonctions : widget Lock Screen « Next class » (gratuit), puis widget Homework (Premium, étiqueté « Homework widget With Premium »), styles Pastel, Blossom (« Style and Homework widget With Premium »). Honnête (étiquette lisible sur plusieurs plans).
- Lisibilité, rythme, fin : gros 9:41 très lisible, rythme correct. Geste « Handed in? One tap » montré (cercle sur le widget). CTA final.
- Note globale 7,5/10. Correction n° 1 : le téléphone noir de la 1re image fait perdre 1 à 2 s ; montrer l'écran verrouillé tout de suite.

### pub-organique-depart-v1 — 24.8 s
- Accroche : « POV: the trip is booked and you count the days » sur une valise, texte petit et blanc sur fond clair. Image jolie mais texte faible. Note 3/5.
- Message / public : voyageurs, compte à rebours et liste de bagages.
- Fonctions : compte à rebours Lisbonne (gratuit), liste « Don't forget » (tâches, gratuit), plus tard « Day 4 / 10 » et widget conversion devise (€66.00 : Premium, étiqueté « Some widgets With Premium », « Aurora style and some widgets With Premium »). Étiquettes présentes, petites.
- Lisibilité, rythme, fin : texte turquoise sur nuages peu lisible (« Departure day. », « Start your countdown. »). Plans de fond (aile d'avion) agréables mais allongent sans montrer l'app. Fin CTA App Store.
- Note globale 7/10. Correction n° 1 : mettre un contour sombre ou un fond sous le texte sur les photos et agrandir le POV d'ouverture.

### pub-organique-etudes-v3 — 25.7 s
- Accroche : étudiante qui écrit + « 3 years of college and still lost in your schedule? ». Personne, question, problème clair. Note 4,5/5.
- Message / public : étudiants, emploi du temps, devoirs, examens, notes.
- Fonctions : écran verrouillé « Current class », widget Weekly schedule (gratuit), Homework (Premium, étiqueté en petit), Exams, « Study time, tracked » (chronomètre d'étude, Premium selon l'inventaire pour flashcards et minuteur) et « Every grade, one average » (moyenne des notes). Ces deux écrans de l'app ne sont pas étiquetés Premium : promesse partiellement trompeuse (flashcards/minuteur/moyenne = Premium).
- Lisibilité, rythme, fin : textes violets et noirs lisibles, rythme dense mais clair (six fonctions : trop). CTA final.
- Note globale 7,5/10. Correction n° 1 : étiqueter « With Premium » sur les écrans Study time/Grades, ou ne montrer que les fonctions gratuites.

### pub-organique-fadein-01-v2 — 10.0 s
- Accroche : noir (0-1 s), puis « Tap. Done. Streak +1. » petit en haut. Pas de personne, texte petit, la première image est entièrement vide. Note 2/5.
- Message / public : habitudes, série (streak). Message court mais un peu cryptique sans contexte.
- Fonctions : widget Habits (gratuit, 3 habitudes). Styles Dark (gratuit), Aurora « With Premium » (pastille).
- Lisibilité, rythme, fin : texte trop petit (haut de l'écran, environ 15 px apparent), pastille Premium minuscule. Fond sombre vert peu contrasté avec le téléphone. Fin : logo Ardane sans mention App Store.
- Note globale 5,5/10. Correction n° 1 : 10 s ne suffisent pas pour une accroche noire de 1 s : texte x2 dès 0,2 s et téléphone plus grand.

### pub-organique-fadein-02-v2 — 10.0 s
- Accroche : noir puis « Gym week, on your Home Screen. » Aucune accroche forte. Note 2/5.
- Message / public : widget de régularité de séances (« Consistency 6/3 workouts this week »).
- Fonctions : widget trainingStreak (gratuit). Dark gratuit ; Neon « With Premium » en pastille. Incohérence de données : « 6/3 » (6 séances sur un objectif de 3) peut paraître une erreur.
- Lisibilité, rythme, fin : même modèle, texte petit. Fin : logo seul.
- Note globale 5/10. Correction n° 1 : corriger la valeur (par ex. 3/3 ou 4/5) et agrandir le texte.

### pub-organique-fadein-03-v2 — 10.0 s
- Accroche : noir puis « Your coffee, logged in one tap. » Note 2/5.
- Message / public : quick expense (café) ; dépense en un tap.
- Fonctions : quick expense (gratuit). Le « $125.99 spent today » est irréaliste pour un café ; passe à $130.49 après un tap (montre le geste uniquement par le changement de valeur). Neon Premium étiqueté.
- Lisibilité, rythme, fin : texte petit, rythme lent. Pas de geste visible, juste le résultat. Fin : logo seul.
- Note globale 5,5/10. Correction n° 1 : montrer le tap (doigt/cercle) et partir de 0 $ ou d'un montant plausible.

### pub-organique-fadein-04-v2 — 10.0 s
- Accroche : noir puis « Check it off. Right there. » Note 2/5.
- Message / public : tâches cochées depuis l'écran d'accueil.
- Fonctions : widget Tasks (gratuit), mais en haut du téléphone le widget « Day 4 » (progression de voyage, Premium) apparaît sans étiquette Premium. Pastel étiqueté.
- Lisibilité, rythme, fin : texte petit ; les cases à cocher sont bien visibles en zoom, le geste est montré (2 tâches cochées). Fin : logo seul.
- Note globale 5,5/10. Correction n° 1 : remplacer le widget Day 4 par un widget gratuit (compte à rebours) ou l'étiqueter.

### pub-organique-fadein-05-v2 — 10.0 s
- Accroche : noir puis « Calories left? One glance. » Note 2/5.
- Message / public : calories restantes d'un coup d'œil.
- Fonctions : widget calories (gratuit), bouton Scan (10 analyses gratuites). Widget « Day 4 » Premium visible sans étiquette ; Neon étiqueté.
- Lisibilité, rythme, fin : texte petit ; pas de geste. Fin : logo seul.
- Note globale 5/10. Correction n° 1 : mêmes que fadein-04 (étiqueter ou retirer le widget Day 4) et montrer un scan.

### pub-organique-fadein-06-v2 — 10.0 s
- Accroche : noir puis « Homework handed in? Tap it. » Note 2/5.
- Message / public : étudiants, devoirs.
- Fonctions : widget Homework (Premium), étiqueté « Homework widget With Premium » juste sous le widget (lisible en zoom), puis Dark/Aurora avec pastilles. Honnête, mais l'ensemble de la vidéo repose sur un widget Premium.
- Lisibilité, rythme, fin : texte petit. Geste : tap, devoir coché (2 restants). Fin : logo seul.
- Note globale 5,5/10. Correction n° 1 : accroche avec visuel dès la première image et mettre le prix/essai en perspective (c'est un widget payant).

### pub-organique-fadein-07-v2 — 10.0 s
- Accroche : noir puis « How close is your monthly goal? » Note 2/5.
- Message / public : objectif de revenu (indépendants).
- Fonctions : widget objectif du mois (gratuit). Pastel étiqueté ; widget « Day 4 » visible sans étiquette.
- Lisibilité, rythme, fin : texte petit ; pas de geste. Fin : logo seul.
- Note globale 5,5/10. Correction n° 1 : accroche plus forte (montant, % atteint) dès 1 s.

### pub-organique-fadein-08-v2 — 10.0 s
- Accroche : noir puis « Count down to your next trip. » Note 2/5.
- Message / public : compte à rebours de voyage.
- Fonctions : widget countdown 18 jours (gratuit). Blossom « With Premium » étiqueté.
- Lisibilité, rythme, fin : texte petit ; pas de geste. Fin : logo seul.
- Note globale 5,5/10. Correction n° 1 : ajouter une image de voyage (valise/avion) dès la première image comme dans « depart ».

### pub-organique-fadein-09-v2 — 10.0 s
- Accroche : noir puis « Your Home Screen, seven styles. » Note 2/5.
- Message / public : styles de widgets. Le titre promet « seven styles » mais la vidéo n'en montre que quatre (Light, Dark, Neon, Blossom) : promesse non tenue à l'écran.
- Fonctions : Neon et Blossom étiquetés « With Premium » ; style Dark gratuit.
- Lisibilité, rythme, fin : texte petit. Fin : logo seul.
- Note globale 5/10. Correction n° 1 : montrer sept styles ou écrire « four styles » ; sinon « 500 styles » (Premium) à étiqueter.

### pub-organique-fadein-10-v2 — 10.0 s
- Accroche : noir puis « Your to-do list, always in sight. » Note 2/5.
- Message / public : liste de tâches visible en permanence.
- Fonctions : widget Tasks (gratuit). Blossom « With Premium » étiqueté.
- Lisibilité, rythme, fin : texte petit ; tâche cochée, aucun geste net. Fin : logo seul.
- Note globale 5,5/10. Correction n° 1 : accroche avec un visuel dès la première image.

---

## Classement

| # | Vidéo | Note /10 | Verdict |
|---|---|---|---|
| 1 | pub-organique-budget-v1 | 8 | publier tel quel (agrandir le téléphone initial si possible) |
| 2 | pub-organique-battle-v1 | 7,5 | corriger (CTA store) |
| 3 | pub-organique-business-v4 | 7,5 | corriger (mention Premium plus grande) |
| 4 | pub-organique-cours-v1 | 7,5 | publier tel quel (couper l'image noire initiale si possible) |
| 5 | pub-organique-etudes-v3 | 7,5 | corriger (étiqueter Study time / Grades) |
| 6 | pub-organique-depart-v1 | 7 | corriger (lisibilité du texte sur photos) |
| 7 | pub-organique-accueil-v1 | 6,5 | corriger (nom Ardane tôt, mention Premium) |
| 8 | pub-organique-affiche-04-v1 | 6,5 | corriger |
| 9 | pub-organique-affiche-03-v1 | 6 | corriger |
| 10 | pub-organique-affiche-06-v1 | 5,5 | corriger |
| 11 | main-pub-all-your-essentials-v2.5 | 5,5 | corriger (56 s, trop long) |
| 12 | pub-organique-fadein-01-v2 | 5,5 | corriger |
| 13 | pub-organique-fadein-03-v2 | 5,5 | corriger |
| 14 | pub-organique-fadein-04-v2 | 5,5 | corriger |
| 15 | pub-organique-fadein-06-v2 | 5,5 | corriger |
| 16 | pub-organique-fadein-07-v2 | 5,5 | corriger |
| 17 | pub-organique-fadein-08-v2 | 5,5 | corriger |
| 18 | pub-organique-fadein-10-v2 | 5,5 | corriger |
| 19 | pub-organique-fadein-02-v2 | 5 | corriger (valeur 6/3) |
| 20 | pub-organique-fadein-05-v2 | 5 | corriger (widget Day 4) |
| 21 | pub-organique-fadein-09-v2 | 5 | corriger (« seven styles » non tenu) |

Aucune vidéo à retirer : aucune ne montre de fonction Premium comme gratuite sans aucune mention.

## 5 constats transversaux

1. **Accroche en texte seul sur noir.** Les 3 « affiche » (3 s de texte statique) et les 10 « fadein » (première image noire, texte petit en haut) n'arrêtent pas le scroll. Seules budget, business, cours et études ouvrent sur une personne, un compteur ou un vote. Mettre un visuel (main, personne, chiffre qui bouge) dès 0 s et agrandir le texte d'ouverture.
2. **Honnêteté Premium présente mais illisible.** Presque toutes les vidéos étiquettent « With Premium », mais en minuscules (environ 10 px apparent) : un spectateur ne les lit pas. Les trous réels : widget « Day 4 » (Premium) sans étiquette dans fadein-04/05/07, écrans Study time / Grades dans etudes-v3, bibliothèque d'exercices et minuteur dans main-pub. Agrandir la pastille et lui donner un contraste fort.
3. **Les fadein sont un même gabarit répété.** Les dix variantes (et les vingt autres hors de cette partie) partagent le même téléphone, le même fond et la même fin ; seul le titre change. Risque de contenu perçu comme dupliqué sur TikTok/Reels. Les publier espacées et varier les plans (une vraie scène humaine par vidéo).
4. **Le geste réel manque ou est à peine visible.** Dans les formats courts (affiche, fadein), le résultat s'affiche sans doigt ni tap visible (valeur qui change seule). Les meilleures (budget, cours, études) montrent un cercle de tap. Ajouter un doigt ou un cercle net sur le geste clé.
5. **Durée et appel à l'action.** Les formats de 10 s sont sous la fourchette 12-30 s ; la pub principale de 56 s est trop longue pour du organique. Les fadein finissent sur le logo sans « Available on the App Store » (les affiche l'ont) et battle finit sans appel à télécharger. Uniformiser : 15-25 s, CTA store + une promesse unique en dernière image.

---
## Annexe C : revue détaillée des vidéos (lot 2)
# Revue marketing, part01 (21 vidéos), 2026-11-27

Les 20 vidéos « fadein 11 à 30 » partagent une seule structure de 10 s ; les défauts communs sont répétés dans chaque bloc, les spécificités sont dans « Message » et « Fonctions ».

### pub-organique-fadein-11-v2 — 10.0 s
- Accroche (0-3 s) : Image 1 (s 0) = écran noir vide, puis phrase blanche sur halo coloré (s 1), téléphone petit et loin (s 2-3). Pas de personne, pas d'avant/après, pas de geste. Texte « Light or dark? You pick. ». Note 2/5. Accroche textuelle seule, jamais la personne ni le résultat.
- Message principal / public visé : Accueil habitudes + calories + objectif, puis Dark et Minimal.
- Fonctions montrées : Gratuit : Dark et Minimal sont des styles gratuits, widgets Habitudes/Calories/Objectif/Voyage gratuits. Rien de trompeur, mais rien de vendeur : aucun des 500 styles Premium n'est montré.
- Lisibilité, rythme, fin : Texte blanc centré, gros, bon contraste, mais seulement ~1 s visible avant que le téléphone arrive (image 2 sur 12, puis le titre reste au-dessus d'un petit téléphone). Étiquettes « Make it yours » / « With Premium » minuscules, illisibles sur mobile. Rythme : 10 s en 6 séquences identiques (titre, accueil beige, zoom widget, zoom arrière, Dark, style Premium), aucun geste réel, tout s'anime tout seul. Fin : logo Ardane seul sur fond noir, aucun « Disponible sur l'App Store », aucun appel à l'action.
- Note globale 4/10. Correction n°1 : Retirer ou refondre : « clair ou sombre » est gratuit chez Apple, aucun motif de télécharger. Remplacer la fin par un style Premium (Aurora) ou supprimer la vidéo.

### pub-organique-fadein-12-v2 — 10.0 s
- Accroche (0-3 s) : Image 1 (s 0) = écran noir vide, puis phrase blanche sur halo coloré (s 1), téléphone petit et loin (s 2-3). Pas de personne, pas d'avant/après, pas de geste. Texte « Your macros, without opening anything. ». Note 2/5. Accroche textuelle seule, jamais la personne ni le résultat.
- Message principal / public visé : Suivi des macros d'un coup d'oeil, public nutrition.
- Fonctions montrées : Widget Macros (protéines, glucides, lipides + bouton Scan) = widget Premium (kind macros), non étiqueté Premium dans la vidéo : promesse trompeuse pour un utilisateur gratuit (il verra un cadenas). Seul Aurora est étiqueté. Dark gratuit.
- Lisibilité, rythme, fin : Texte blanc centré, gros, bon contraste, mais seulement ~1 s visible avant que le téléphone arrive (image 2 sur 12, puis le titre reste au-dessus d'un petit téléphone). Étiquettes « Make it yours » / « With Premium » minuscules, illisibles sur mobile. Rythme : 10 s en 6 séquences identiques (titre, accueil beige, zoom widget, zoom arrière, Dark, style Premium), aucun geste réel, tout s'anime tout seul. Fin : logo Ardane seul sur fond noir, aucun « Disponible sur l'App Store », aucun appel à l'action.
- Note globale 4/10. Correction n°1 : Ajouter « With Premium » sous le widget Macros comme dans les vidéos Sales/Volume, ou montrer le widget gratuit Calories restantes avec le scan.

### pub-organique-fadein-13-v2 — 10.0 s
- Accroche (0-3 s) : Image 1 (s 0) = écran noir vide, puis phrase blanche sur halo coloré (s 1), téléphone petit et loin (s 2-3). Pas de personne, pas d'avant/après, pas de geste. Texte « Your next set, always in sight. ». Note 2/5. Accroche textuelle seule, jamais la personne ni le résultat.
- Message principal / public visé : Prochaine série visible sans ouvrir l'app, public fitness.
- Fonctions montrées : Widget « Next set / Set done » = nextSet, Premium et interactif, non étiqueté : promesse trompeuse (cas cité dans l'inventaire). Neon étiqueté Premium.
- Lisibilité, rythme, fin : Texte blanc centré, gros, bon contraste, mais seulement ~1 s visible avant que le téléphone arrive (image 2 sur 12, puis le titre reste au-dessus d'un petit téléphone). Étiquettes « Make it yours » / « With Premium » minuscules, illisibles sur mobile. Rythme : 10 s en 6 séquences identiques (titre, accueil beige, zoom widget, zoom arrière, Dark, style Premium), aucun geste réel, tout s'anime tout seul. Fin : logo Ardane seul sur fond noir, aucun « Disponible sur l'App Store », aucun appel à l'action.
- Note globale 4/10. Correction n°1 : Étiqueter « With Premium » sur le widget, ou remplacer par le widget gratuit Séance du jour / Commencer (todaysWorkout) et la Live Activity d'entraînement, gratuite.

### pub-organique-fadein-14-v2 — 10.0 s
- Accroche (0-3 s) : Image 1 (s 0) = écran noir vide, puis phrase blanche sur halo coloré (s 1), téléphone petit et loin (s 2-3). Pas de personne, pas d'avant/après, pas de geste. Texte « Your budget, one glance. ». Note 2/5. Accroche textuelle seule, jamais la personne ni le résultat.
- Message principal / public visé : Budget restant du mois, public finances perso.
- Fonctions montrées : Gratuit : « Left this month » = budgetLeft. Calories restantes et habitudes gratuits aussi. Aurora étiqueté Premium. Honnête.
- Lisibilité, rythme, fin : Texte blanc centré, gros, bon contraste, mais seulement ~1 s visible avant que le téléphone arrive (image 2 sur 12, puis le titre reste au-dessus d'un petit téléphone). Étiquettes « Make it yours » / « With Premium » minuscules, illisibles sur mobile. Rythme : 10 s en 6 séquences identiques (titre, accueil beige, zoom widget, zoom arrière, Dark, style Premium), aucun geste réel, tout s'anime tout seul. Fin : logo Ardane seul sur fond noir, aucun « Disponible sur l'App Store », aucun appel à l'action.
- Note globale 6/10. Correction n°1 : Remplacer le halo vert vide du début par le chiffre $1,631 en gros dès la première seconde.

### pub-organique-fadein-15-v2 — 10.0 s
- Accroche (0-3 s) : Image 1 (s 0) = écran noir vide, puis phrase blanche sur halo coloré (s 1), téléphone petit et loin (s 2-3). Pas de personne, pas d'avant/après, pas de geste. Texte « Three things today. That's it. ». Note 2/5. Accroche textuelle seule, jamais la personne ni le résultat.
- Message principal / public visé : Top 3 des tâches, public productivité/étudiants.
- Fonctions montrées : Gratuit : Tasks. Pastel étiqueté Premium. Honnête. Message le plus proche d'un usage quotidien.
- Lisibilité, rythme, fin : Texte blanc centré, gros, bon contraste, mais seulement ~1 s visible avant que le téléphone arrive (image 2 sur 12, puis le titre reste au-dessus d'un petit téléphone). Étiquettes « Make it yours » / « With Premium » minuscules, illisibles sur mobile. Rythme : 10 s en 6 séquences identiques (titre, accueil beige, zoom widget, zoom arrière, Dark, style Premium), aucun geste réel, tout s'anime tout seul. Fin : logo Ardane seul sur fond noir, aucun « Disponible sur l'App Store », aucun appel à l'action.
- Note globale 6/10. Correction n°1 : Montrer une case qu'on coche (tasks est interactif et gratuit) : vrai geste, absent aujourd'hui.

### pub-organique-fadein-16-v2 — 10.0 s
- Accroche (0-3 s) : Image 1 (s 0) = écran noir vide, puis phrase blanche sur halo coloré (s 1), téléphone petit et loin (s 2-3). Pas de personne, pas d'avant/après, pas de geste. Texte « Don't break the streak. ». Note 2/5. Accroche textuelle seule, jamais la personne ni le résultat.
- Message principal / public visé : Série de jours de méditation, public habitudes.
- Fonctions montrées : Gratuit : Habit streak (le bouton « Fait » et le record sont Premium, mais non montrés). Néon étiqueté Premium. Honnête.
- Lisibilité, rythme, fin : Texte blanc centré, gros, bon contraste, mais seulement ~1 s visible avant que le téléphone arrive (image 2 sur 12, puis le titre reste au-dessus d'un petit téléphone). Étiquettes « Make it yours » / « With Premium » minuscules, illisibles sur mobile. Rythme : 10 s en 6 séquences identiques (titre, accueil beige, zoom widget, zoom arrière, Dark, style Premium), aucun geste réel, tout s'anime tout seul. Fin : logo Ardane seul sur fond noir, aucun « Disponible sur l'App Store », aucun appel à l'action.
- Note globale 6/10. Correction n°1 : Montrer la série qui passe de 11 à 12 jours par un tap : c'est la tension émotionnelle du message (attention, le bouton « Fait » du widget est Premium, utiliser l'app).

### pub-organique-fadein-17-v2 — 10.0 s
- Accroche (0-3 s) : Image 1 (s 0) = écran noir vide, puis phrase blanche sur halo coloré (s 1), téléphone petit et loin (s 2-3). Pas de personne, pas d'avant/après, pas de geste. Texte « Today's classes, before the bell. ». Note 2/5. Accroche textuelle seule, jamais la personne ni le résultat.
- Message principal / public visé : Emploi du temps du jour, public étudiants.
- Fonctions montrées : Gratuit : Today's schedule / timetable. Blossom étiqueté Premium. Honnête. La saisie des cours à la main est gratuite ; l'import par photo (Premium) n'est pas promis.
- Lisibilité, rythme, fin : Texte blanc centré, gros, bon contraste, mais seulement ~1 s visible avant que le téléphone arrive (image 2 sur 12, puis le titre reste au-dessus d'un petit téléphone). Étiquettes « Make it yours » / « With Premium » minuscules, illisibles sur mobile. Rythme : 10 s en 6 séquences identiques (titre, accueil beige, zoom widget, zoom arrière, Dark, style Premium), aucun geste réel, tout s'anime tout seul. Fin : logo Ardane seul sur fond noir, aucun « Disponible sur l'App Store », aucun appel à l'action.
- Note globale 5/10. Correction n°1 : Viser l'étudiant (« Classes today? ») et montrer les 3 cours en gros ; un zoom lisible existe mais sans geste.

### pub-organique-fadein-18-v2 — 10.0 s
- Accroche (0-3 s) : Image 1 (s 0) = écran noir vide, puis phrase blanche sur halo coloré (s 1), téléphone petit et loin (s 2-3). Pas de personne, pas d'avant/après, pas de geste. Texte « Your sales, last 30 days. ». Note 2/5. Accroche textuelle seule, jamais la personne ni le résultat.
- Message principal / public visé : Ventes 30 jours, public freelance/e-commerce.
- Fonctions montrées : Premium : revenueTrend, étiqueté « Sales widget With Premium » sous le widget (petit mais présent) et sur Aurora. Honnête. Ne dit pas d'où viennent les données (saisie ou Stripe Premium).
- Lisibilité, rythme, fin : Texte blanc centré, gros, bon contraste, mais seulement ~1 s visible avant que le téléphone arrive (image 2 sur 12, puis le titre reste au-dessus d'un petit téléphone). Étiquettes « Make it yours » / « With Premium » minuscules, illisibles sur mobile. Rythme : 10 s en 6 séquences identiques (titre, accueil beige, zoom widget, zoom arrière, Dark, style Premium), aucun geste réel, tout s'anime tout seul. Fin : logo Ardane seul sur fond noir, aucun « Disponible sur l'App Store », aucun appel à l'action.
- Note globale 5/10. Correction n°1 : Agrandir l'étiquette Premium (lisible 1,5 s) et dire d'où viennent les données.

### pub-organique-fadein-19-v2 — 10.0 s
- Accroche (0-3 s) : Image 1 (s 0) = écran noir vide, puis phrase blanche sur halo coloré (s 1), téléphone petit et loin (s 2-3). Pas de personne, pas d'avant/après, pas de geste. Texte « Your trip, day by day. ». Note 2/5. Accroche textuelle seule, jamais la personne ni le résultat.
- Message principal / public visé : Jour du voyage à Lisbonne, public voyageurs.
- Fonctions montrées : Gratuit : compte à rebours de voyage. Neon étiqueté Premium. Honnête. « Day 4 · bon voyage! » mélange français et anglais.
- Lisibilité, rythme, fin : Texte blanc centré, gros, bon contraste, mais seulement ~1 s visible avant que le téléphone arrive (image 2 sur 12, puis le titre reste au-dessus d'un petit téléphone). Étiquettes « Make it yours » / « With Premium » minuscules, illisibles sur mobile. Rythme : 10 s en 6 séquences identiques (titre, accueil beige, zoom widget, zoom arrière, Dark, style Premium), aucun geste réel, tout s'anime tout seul. Fin : logo Ardane seul sur fond noir, aucun « Disponible sur l'App Store », aucun appel à l'action.
- Note globale 5/10. Correction n°1 : Mettre « bon voyage! » en anglais cohérent et remplacer le halo vide par le widget plein écran dès la première seconde.

### pub-organique-fadein-20-v2 — 10.0 s
- Accroche (0-3 s) : Image 1 (s 0) = écran noir vide, puis phrase blanche sur halo coloré (s 1), téléphone petit et loin (s 2-3). Pas de personne, pas d'avant/après, pas de geste. Texte « Lunch? Check your Home Screen. ». Note 2/5. Accroche textuelle seule, jamais la personne ni le résultat.
- Message principal / public visé : Calories restantes à midi, public nutrition.
- Fonctions montrées : Gratuit : Calories restantes. Pastel étiqueté Premium. Honnête. Le scan de plat (10 gratuits) n'est pas montré : occasion manquée du vrai geste.
- Lisibilité, rythme, fin : Texte blanc centré, gros, bon contraste, mais seulement ~1 s visible avant que le téléphone arrive (image 2 sur 12, puis le titre reste au-dessus d'un petit téléphone). Étiquettes « Make it yours » / « With Premium » minuscules, illisibles sur mobile. Rythme : 10 s en 6 séquences identiques (titre, accueil beige, zoom widget, zoom arrière, Dark, style Premium), aucun geste réel, tout s'anime tout seul. Fin : logo Ardane seul sur fond noir, aucun « Disponible sur l'App Store », aucun appel à l'action.
- Note globale 6/10. Correction n°1 : Montrer le scan d'un plat (10 analyses gratuites) puis le widget qui se met à jour : geste réel et gratuit.

### pub-organique-fadein-21-v2 — 10.0 s
- Accroche (0-3 s) : Image 1 (s 0) = écran noir vide, puis phrase blanche sur halo coloré (s 1), téléphone petit et loin (s 2-3). Pas de personne, pas d'avant/après, pas de geste. Texte « Every kilo this week, counted. ». Note 2/5. Accroche textuelle seule, jamais la personne ni le résultat.
- Message principal / public visé : Volume soulevé de la semaine, public musculation.
- Fonctions montrées : Premium : weeklyVolume, étiqueté « Volume widget With Premium ». Honnête. Aurora étiqueté.
- Lisibilité, rythme, fin : Texte blanc centré, gros, bon contraste, mais seulement ~1 s visible avant que le téléphone arrive (image 2 sur 12, puis le titre reste au-dessus d'un petit téléphone). Étiquettes « Make it yours » / « With Premium » minuscules, illisibles sur mobile. Rythme : 10 s en 6 séquences identiques (titre, accueil beige, zoom widget, zoom arrière, Dark, style Premium), aucun geste réel, tout s'anime tout seul. Fin : logo Ardane seul sur fond noir, aucun « Disponible sur l'App Store », aucun appel à l'action.
- Note globale 5/10. Correction n°1 : Étiquette trop petite ; remplacer « counted » ambigu par « Lifted this week: 18,523 kg ».

### pub-organique-fadein-22-v2 — 10.0 s
- Accroche (0-3 s) : Image 1 (s 0) = écran noir vide, puis phrase blanche sur halo coloré (s 1), téléphone petit et loin (s 2-3). Pas de personne, pas d'avant/après, pas de geste. Texte « Watch your trip fund grow. ». Note 2/5. Accroche textuelle seule, jamais la personne ni le résultat.
- Message principal / public visé : Épargne voyage au Japon 43 %, public épargne.
- Fonctions montrées : Gratuit : Savings goal. Blossom étiqueté Premium. Honnête.
- Lisibilité, rythme, fin : Texte blanc centré, gros, bon contraste, mais seulement ~1 s visible avant que le téléphone arrive (image 2 sur 12, puis le titre reste au-dessus d'un petit téléphone). Étiquettes « Make it yours » / « With Premium » minuscules, illisibles sur mobile. Rythme : 10 s en 6 séquences identiques (titre, accueil beige, zoom widget, zoom arrière, Dark, style Premium), aucun geste réel, tout s'anime tout seul. Fin : logo Ardane seul sur fond noir, aucun « Disponible sur l'App Store », aucun appel à l'action.
- Note globale 6/10. Correction n°1 : Animer l'anneau qui passe de 40 à 43 % dès la première seconde : l'accroche devient un mouvement.

### pub-organique-fadein-23-v2 — 10.0 s
- Accroche (0-3 s) : Image 1 (s 0) = écran noir vide, puis phrase blanche sur halo coloré (s 1), téléphone petit et loin (s 2-3). Pas de personne, pas d'avant/après, pas de geste. Texte « Your whole week, one widget. ». Note 2/5. Accroche textuelle seule, jamais la personne ni le résultat.
- Message principal / public visé : Semaine complète colorée, public étudiants/planning.
- Fonctions montrées : Gratuit : widget Semaine (weekView). Pastel étiqueté Premium. Honnête. Plus beau visuel de la série (blocs colorés), mais petit dans le téléphone.
- Lisibilité, rythme, fin : Texte blanc centré, gros, bon contraste, mais seulement ~1 s visible avant que le téléphone arrive (image 2 sur 12, puis le titre reste au-dessus d'un petit téléphone). Étiquettes « Make it yours » / « With Premium » minuscules, illisibles sur mobile. Rythme : 10 s en 6 séquences identiques (titre, accueil beige, zoom widget, zoom arrière, Dark, style Premium), aucun geste réel, tout s'anime tout seul. Fin : logo Ardane seul sur fond noir, aucun « Disponible sur l'App Store », aucun appel à l'action.
- Note globale 6/10. Correction n°1 : Commencer directement sur le zoom du widget coloré (image 5) au lieu du texte seul.

### pub-organique-fadein-24-v2 — 10.0 s
- Accroche (0-3 s) : Image 1 (s 0) = écran noir vide, puis phrase blanche sur halo coloré (s 1), téléphone petit et loin (s 2-3). Pas de personne, pas d'avant/après, pas de geste. Texte « Seven days. Every habit. ». Note 2/5. Accroche textuelle seule, jamais la personne ni le résultat.
- Message principal / public visé : Grille 7 jours des habitudes, public habitudes.
- Fonctions montrées : Premium : habitWeek, étiqueté « Habits week widget With Premium ». Honnête. Mais la grille montre 4 habitudes (dont « No screen ») alors que le plan gratuit en limite 3.
- Lisibilité, rythme, fin : Texte blanc centré, gros, bon contraste, mais seulement ~1 s visible avant que le téléphone arrive (image 2 sur 12, puis le titre reste au-dessus d'un petit téléphone). Étiquettes « Make it yours » / « With Premium » minuscules, illisibles sur mobile. Rythme : 10 s en 6 séquences identiques (titre, accueil beige, zoom widget, zoom arrière, Dark, style Premium), aucun geste réel, tout s'anime tout seul. Fin : logo Ardane seul sur fond noir, aucun « Disponible sur l'App Store », aucun appel à l'action.
- Note globale 5/10. Correction n°1 : Agrandir l'étiquette Premium et signaler que plus de 3 habitudes = Premium.

### pub-organique-fadein-25-v2 — 10.0 s
- Accroche (0-3 s) : Image 1 (s 0) = écran noir vide, puis phrase blanche sur halo coloré (s 1), téléphone petit et loin (s 2-3). Pas de personne, pas d'avant/après, pas de geste. Texte « Your class, at a glance. ». Note 2/5. Accroche textuelle seule, jamais la personne ni le résultat.
- Message principal / public visé : Prochain cours 08:30, public étudiants.
- Fonctions montrées : Gratuit : Next class. Neon étiqueté Premium. Honnête. Contenu pauvre : une heure et « Math ».
- Lisibilité, rythme, fin : Texte blanc centré, gros, bon contraste, mais seulement ~1 s visible avant que le téléphone arrive (image 2 sur 12, puis le titre reste au-dessus d'un petit téléphone). Étiquettes « Make it yours » / « With Premium » minuscules, illisibles sur mobile. Rythme : 10 s en 6 séquences identiques (titre, accueil beige, zoom widget, zoom arrière, Dark, style Premium), aucun geste réel, tout s'anime tout seul. Fin : logo Ardane seul sur fond noir, aucun « Disponible sur l'App Store », aucun appel à l'action.
- Note globale 5/10. Correction n°1 : Ajouter salle et compte à rebours dans le widget, sinon le zoom ne dit rien d'utile.

### pub-organique-fadein-26-v2 — 10.0 s
- Accroche (0-3 s) : Image 1 (s 0) = écran noir vide, puis phrase blanche sur halo coloré (s 1), téléphone petit et loin (s 2-3). Pas de personne, pas d'avant/après, pas de geste. Texte « Orders, customers, conversion. All here. ». Note 2/5. Accroche textuelle seule, jamais la personne ni le résultat.
- Message principal / public visé : Indicateurs mensuels, public business.
- Fonctions montrées : Premium : businessKPIs, étiqueté « Indicators widget With Premium ». Honnête. Ne dit pas que les données sont saisies à la main ou via Stripe/CSV (Premium).
- Lisibilité, rythme, fin : Texte blanc centré, gros, bon contraste, mais seulement ~1 s visible avant que le téléphone arrive (image 2 sur 12, puis le titre reste au-dessus d'un petit téléphone). Étiquettes « Make it yours » / « With Premium » minuscules, illisibles sur mobile. Rythme : 10 s en 6 séquences identiques (titre, accueil beige, zoom widget, zoom arrière, Dark, style Premium), aucun geste réel, tout s'anime tout seul. Fin : logo Ardane seul sur fond noir, aucun « Disponible sur l'App Store », aucun appel à l'action.
- Note globale 5/10. Correction n°1 : Mentionner la source des données et agrandir l'étiquette.

### pub-organique-fadein-27-v2 — 10.0 s
- Accroche (0-3 s) : Image 1 (s 0) = écran noir vide, puis phrase blanche sur halo coloré (s 1), téléphone petit et loin (s 2-3). Pas de personne, pas d'avant/après, pas de geste. Texte « How many vacation days left? ». Note 2/5. Accroche textuelle seule, jamais la personne ni le résultat.
- Message principal / public visé : Progression du voyage 4/10, public voyageurs.
- Fonctions montrées : Premium : tripProgress, étiqueté « Trip progress widget With Premium ». Honnête. Le widget gratuit Compte à rebours dit presque la même chose.
- Lisibilité, rythme, fin : Texte blanc centré, gros, bon contraste, mais seulement ~1 s visible avant que le téléphone arrive (image 2 sur 12, puis le titre reste au-dessus d'un petit téléphone). Étiquettes « Make it yours » / « With Premium » minuscules, illisibles sur mobile. Rythme : 10 s en 6 séquences identiques (titre, accueil beige, zoom widget, zoom arrière, Dark, style Premium), aucun geste réel, tout s'anime tout seul. Fin : logo Ardane seul sur fond noir, aucun « Disponible sur l'App Store », aucun appel à l'action.
- Note globale 5/10. Correction n°1 : Montrer le widget gratuit pour la question, puis le Premium en style.

### pub-organique-fadein-28-v2 — 10.0 s
- Accroche (0-3 s) : Image 1 (s 0) = écran noir vide, puis phrase blanche sur halo coloré (s 1), téléphone petit et loin (s 2-3). Pas de personne, pas d'avant/après, pas de geste. Texte « Your habits, your style. ». Note 2/5. Accroche textuelle seule, jamais la personne ni le résultat.
- Message principal / public visé : Habitudes + styles, public habitudes.
- Fonctions montrées : Gratuit : Habits (3). Neon et Blossom étiquetés Premium. Honnête, mais le premier plan est coupé (widgets en haut hors cadre) et la promesse est floue.
- Lisibilité, rythme, fin : Texte blanc centré, gros, bon contraste, mais seulement ~1 s visible avant que le téléphone arrive (image 2 sur 12, puis le titre reste au-dessus d'un petit téléphone). Étiquettes « Make it yours » / « With Premium » minuscules, illisibles sur mobile. Rythme : 10 s en 6 séquences identiques (titre, accueil beige, zoom widget, zoom arrière, Dark, style Premium), aucun geste réel, tout s'anime tout seul. Fin : logo Ardane seul sur fond noir, aucun « Disponible sur l'App Store », aucun appel à l'action.
- Note globale 4/10. Correction n°1 : Retirer ou refondre : redondant avec 16 et 24, cadrage raté, promesse floue. Fusionner avec la 11 en « 500 styles, 1 minute ».

### pub-organique-fadein-29-v2 — 10.0 s
- Accroche (0-3 s) : Image 1 (s 0) = écran noir vide, puis phrase blanche sur halo coloré (s 1), téléphone petit et loin (s 2-3). Pas de personne, pas d'avant/après, pas de geste. Texte « Your best lifts, always visible. ». Note 2/5. Accroche textuelle seule, jamais la personne ni le résultat.
- Message principal / public visé : Record 100 kg soulevé, public musculation.
- Fonctions montrées : Premium : personalRecords, étiqueté « Records widget With Premium ». Honnête. Mais Dark porte aussi « With Premium » : inexact, Dark est gratuit.
- Lisibilité, rythme, fin : Texte blanc centré, gros, bon contraste, mais seulement ~1 s visible avant que le téléphone arrive (image 2 sur 12, puis le titre reste au-dessus d'un petit téléphone). Étiquettes « Make it yours » / « With Premium » minuscules, illisibles sur mobile. Rythme : 10 s en 6 séquences identiques (titre, accueil beige, zoom widget, zoom arrière, Dark, style Premium), aucun geste réel, tout s'anime tout seul. Fin : logo Ardane seul sur fond noir, aucun « Disponible sur l'App Store », aucun appel à l'action.
- Note globale 5/10. Correction n°1 : Une seule étiquette « With Premium » pour le widget ; Dark sans mention.

### pub-organique-fadein-30-v2 — 10.0 s
- Accroche (0-3 s) : Image 1 (s 0) = écran noir vide, puis phrase blanche sur halo coloré (s 1), téléphone petit et loin (s 2-3). Pas de personne, pas d'avant/après, pas de geste. Texte « Where did your money go? ». Note 2/5. Accroche textuelle seule, jamais la personne ni le résultat.
- Message principal / public visé : Dépenses par catégorie du mois, public finances.
- Fonctions montrées : Premium : spendingByCategory, étiqueté « Spending widget With Premium ». Honnête. Question forte, mais la finances-v3 la traite bien mieux.
- Lisibilité, rythme, fin : Texte blanc centré, gros, bon contraste, mais seulement ~1 s visible avant que le téléphone arrive (image 2 sur 12, puis le titre reste au-dessus d'un petit téléphone). Étiquettes « Make it yours » / « With Premium » minuscules, illisibles sur mobile. Rythme : 10 s en 6 séquences identiques (titre, accueil beige, zoom widget, zoom arrière, Dark, style Premium), aucun geste réel, tout s'anime tout seul. Fin : logo Ardane seul sur fond noir, aucun « Disponible sur l'App Store », aucun appel à l'action.
- Note globale 5/10. Correction n°1 : Reprendre l'accroche visuelle de finances-v3 (main + calculatrice) au lieu d'un fond noir.

### pub-organique-finances-v3 — 24.2 s
- Accroche (0-3 s) : photo d'une main qui calcule avec un stylo et une calculatrice, texte « Where does your money go? » vert foncé gros dès l'image 1 ; l'accueil Ardane suit (~s 2, « Just had a coffee? »). Une personne (main) et une question. Note 4/5 (photo d'ambiance, app visible à ~2 s).
- Message principal / public visé : « Je note ma dépense en un geste, le reste du budget se met à jour », public finances personnelles. Promesse unique et claire.
- Fonctions montrées : surtout gratuit : Dépense rapide ($145.49) et Reste du mois (quickExpense, budgetLeft, gratuits et interactifs), Catégories et Revenus/Dépenses du mois courant, Épargne (objectif Japon 43 %), Studio. Style Néon : Premium, signalé par « Some widgets and styles With Premium » en tout petit sous l'écran : honnête mais trop discret. Historique et Analyse (Premium) non promis.
- Lisibilité, rythme, fin : titres vert foncé très gros, bi-couleur, lisibles ; un message par écran (~2 s) ; vrais écrans et vrai geste (saisie puis chiffre qui change, surlignage vert). Fin : logo + « Available on the App Store » (CTA présent, mais petit et sans verbe). 24 s dans la fourchette.
- Note globale 8/10. Correction n°1 : agrandir la mention Premium et mettre un verbe au CTA final (« Download Ardane, free »).

## Classement

| Vidéo | Note /10 | Verdict |
|---|---|---|
| pub-organique-finances-v3 | 8 | publier tel quel (après correction du CTA) |
| pub-organique-fadein-14-v2 | 6 | corriger |
| pub-organique-fadein-15-v2 | 6 | corriger |
| pub-organique-fadein-16-v2 | 6 | corriger |
| pub-organique-fadein-20-v2 | 6 | corriger |
| pub-organique-fadein-22-v2 | 6 | corriger |
| pub-organique-fadein-23-v2 | 6 | corriger |
| pub-organique-fadein-17-v2 | 5 | corriger |
| pub-organique-fadein-18-v2 | 5 | corriger |
| pub-organique-fadein-19-v2 | 5 | corriger |
| pub-organique-fadein-21-v2 | 5 | corriger |
| pub-organique-fadein-24-v2 | 5 | corriger |
| pub-organique-fadein-25-v2 | 5 | corriger |
| pub-organique-fadein-26-v2 | 5 | corriger |
| pub-organique-fadein-27-v2 | 5 | corriger |
| pub-organique-fadein-29-v2 | 5 | corriger |
| pub-organique-fadein-30-v2 | 5 | corriger |
| pub-organique-fadein-11-v2 | 4 | retirer ou refondre |
| pub-organique-fadein-12-v2 | 4 | corriger |
| pub-organique-fadein-13-v2 | 4 | corriger |
| pub-organique-fadein-28-v2 | 4 | retirer ou refondre |

## 5 constats transversaux

1. Accroche faible partout (fadein) : image 1 noire (s 0), phrase seule, téléphone minuscule, jamais de personne ni de résultat. Seule finances-v3 démarre sur une main et une question. Corriger : commencer sur le zoom du widget ou une main, texte dès la première image.
2. Aucun geste réel dans les 20 fadein : tout est animé tout seul (pas de tap, pas de scan, pas de case cochée), alors que tasks, habits, counter, quickExpense et le scan de plat (10 gratuits) sont gratuits et interactifs.
3. Honnêteté Premium inégale : bien étiquetés (Sales, Volume, Habits week, Indicators, Trip progress, Records, Spending, styles Aurora/Neon/Pastel/Blossom), mais Macros (12) et Next set (13) sont Premium et non étiquetés ; l'étiquette est partout minuscule ; la 29 l'applique à tort à Dark. Environ 9 vidéos sur 20 montrent un widget Premium.
4. Fin sans appel à l'action : les 20 fadein finissent sur le logo seul ; pas de « Download », pas de « App Store », pas de « free ». finances-v3 a « Available on the App Store » mais sans verbe.
5. Série trop uniforme : 20 vidéos de 10 s sur le même modèle et le même accueil beige en fond ; risque de répétition et de lassitude. Publier 4 à 6 variantes (14, 15, 16, 20, 22, 23), rallongées à 15 s avec un geste réel et un CTA, plutôt que les 20.
---
## Annexe D : revue détaillée des vidéos (lot 3)
# Revue marketing, partie 02 (21 vidéos)

Grille : accroche ≤ 3 s, app identifiable à 2-3 s, une promesse, texte lisible, geste réel, 12-30 s, appel à l'action, honnêteté Premium. Source Premium : premium-inventory.md. Revue faite sur 12 images par vidéo (pas de son).

Constat commun : presque toutes les vidéos portent « Some widgets and styles With Premium » ou « With Premium », mais en caractères minuscules (environ 10-14 px sur 1080), gris sur fond clair ou sombre : présent, mais invisible pour le spectateur. Aucun des 4 styles gratuits n'est montré ; tous les styles montrés (Neon, Aurora, Blossom, Cherry blossom, Luxury, Carbon, Matte Black, Pastel) sont Premium. L'icône Ardane n'apparaît qu'à la toute fin.

### pub-organique-fitness-v4.3 — 29,8 s
- Accroche : photo de salle N&B, « Still opening an app after every set? » blanc/rouge, gros et lisible. Question forte, pas de personne. 4/5.
- Message / public : logger une série sans ouvrir l'app (écran verrouillé, widget « Set done »), puis personnaliser. Pratiquants de musculation.
- Fonctions : Live Activity séance sur écran verrouillé = gratuite. Widget Next set + « Set done » (nextSet), Rest timer, Consistency = Premium. Styles Luxury/Neon/Gold = Premium. Mentions présentes mais minuscules ; le plan « Set finished? One tap. No app to open. » vend le widget Premium comme la solution. Promesse en partie trompeuse.
- Lisibilité/rythme/fin : titres gros et rouges, rythme régulier. Fin : icône + « Available on the App Store », sans verbe.
- Note 7/10. Correction n°1 : ouvrir sur la Live Activity gratuite et mettre « With Premium » en pastille lisible sur Next set et les styles.

### pub-organique-gym-v1 — 21,9 s
- Accroche : « Stop typing every set into your phone. » sur athlète N&B, très lisible. 4/5.
- Message / public : noter ses séries depuis l'écran verrouillé, progression, bibliothèque d'exercices, restyler l'accueil. Public gym.
- Fonctions : Live Activity et écran de séance gratuits. Page Progression (volume par semaine) et bibliothèque d'exercices animée = Premium, étiquetées « With Premium » (bon point). Widgets Next set / Consistency, styles Matte Black / Carbon / Neon = Premium, étiquetés en petit.
- Lisibilité : bien ; « Built for the gym. » sur plan réel de salle. Fin sans verbe.
- Note 7,5/10. Correction n°1 : agrandir la mention Premium (au moins 2x) et chiffrer le gain (« 10 s gagnées par série »).

### pub-organique-habitudes-v3 — 22,4 s
- Accroche : réveil en gros plan, « New habits never stick? » vert, lisible. Objet plutôt que personne, question universelle. 3,5/5.
- Message / public : cocher ses habitudes depuis l'accueil, voir sa régularité, garder la série. Bien-être grand public.
- Fonctions : widget Habitudes avec bouton = gratuit (3 habitudes). « How regular you are » (taux par habitude) et « Your week, day by day » = habitRate / habitWeek, Premium, mention « More than 3 habits With Premium » minuscule. Le widget montre 3 puis 4 habitudes (« Done 4 »), au-delà de la limite gratuite. Styles Premium.
- Lisibilité : bonne, palette douce. Plans plein écran longs (3-4 s) : bien pour lire. Fin : icône sans verbe.
- Note 6,5/10. Correction n°1 : rester à 3 habitudes (limite gratuite) ou écrire « Plus de 3 habitudes : Premium » en grand ; ajouter un vrai doigt qui coche.

### pub-organique-huit-v1 — 24,9 s
- Accroche : « You don't need 8 apps. » sur 8 icônes qui disparaissent, il ne reste qu'Ardane. Avant/après fort, marque visible dès 2 s. 4,5/5 (pas d'humain).
- Message / public : 8 apps remplacées par une (Calories, Budget, Habits, Planner, Workout, Trips, Grades, Sales). Jeunes actifs multi-besoins.
- Fonctions : Nutrition/scan, Workout (écran séance), Grades = gratuits ; Habits avec « More than 3 habits With Premium » (bien). Accueil final (Calories, Habits, solde du mois) réalisable gratuitement dans la limite de 3 widgets. « Sales » : l'historique mensuel, CSV et Stripe sont Premium, non dit. Styles « Some styles With Premium » minuscule.
- Lisibilité : excellente. Rythme : même phrase sur les 3 premiers plans (environ 6 s perdues).
- Note 7,5/10. Correction n°1 : réduire l'ouverture à 2 plans et préciser « Sales : Premium ».

### pub-organique-inspo-v1 — 25,3 s
- Accroche : « Home screen ideas for every kind of person » avec trois accueils minuscules. Ni personne ni question, promesse floue, texte petit. 2,5/5.
- Message / public : 5 personas (étudiant, gym rat, budget queen, planner, voyageur), un style chacun, appel à commenter. Public inspiration.
- Fonctions : widget Homework (Premium, « With Premium » sous chaque persona), Next set (Premium), Quick expense (gratuit, « Coffee? One tap. »), Dark (gratuit), Aurora, Carbon, Cherry blossom (Premium), vol/hôtel Lisbon (Premium). C'est la série qui étiquette le mieux, persona par persona.
- Lisibilité : badges 1/5 à 5/5 aident ; sous-titres petits. Rythme ~3,5 s par persona : bon. Fin : « Which one are you? Tell me in the comments. » = vrai appel à l'engagement.
- Note 7/10. Correction n°1 : ouvrir sur un seul accueil spectaculaire et la question « Which one are you? » dès 2 s.

### pub-organique-journee-v1 — 26,1 s
- Accroche : « 7:00 AM / My day, hour by hour. » sur tasse à la fenêtre, pastille bleue. Pas de personne, format « ma journée » reconnaissable. 3/5.
- Message / public : toute une journée (cours sur écran verrouillé, scan du déjeuner, série, dépenses, habitudes). Étudiant/actif.
- Fonctions : écran verrouillé Schedule (nextClass), scan photo du plat (10 analyses gratuites, non dit), Quick expense, Left this month, habitudes 3/3 = gratuits. Scène 6:00 PM « Set done? / Rest timer starts » = nextSet et restTimer, Premium, mention minuscule. Styles Premium en petit.
- Lisibilité : pastilles horaires très lisibles. La scène Set done occupe deux plans (~6 s). Fin : « Your whole day. One app. » puis icône, sans verbe.
- Note 7/10. Correction n°1 : remplacer la scène 6:00 PM par un widget gratuit, ou la marquer Premium en pastille ; ouvrir sur un humain.

### pub-organique-liste3-v1 — 22,8 s
- Accroche : « 3 iPhone widgets you're not using. » sur un accueil, texte bleu/blanc. Chiffre et promesse nette, pas de personne. 3,5/5.
- Message / public : 3 widgets (Rest timer écran verrouillé, Tick a habit, Scan a plate) puis bonus style. Grand public utilitaire.
- Fonctions : n°1 Rest timer = widget Premium (mention minuscule) ; n°2 Habitudes = gratuit ; n°3 scan depuis le widget = gratuit sur caloriesLeft (10 scans ensuite Premium, non dit) ; « Bonus » styles avec « With Premium » (pastille).
- Lisibilité : numérotation 1/3-2/3-3/3 claire, bon rythme ; trois plans quasi identiques sur les habitudes. Fin : icône sans verbe.
- Note 7,5/10. Correction n°1 : mettre Habitudes en n°1, marquer Rest timer comme Premium en pastille, ajouter « 10 scans gratuits ».

### pub-organique-lock-v1 — 23,8 s
- Accroche : « Still unlocking your phone just to check one thing? » sur écran verrouillé flou, texte petit. Bonne question, mais téléphone sombre qui n'arrête pas l'oeil. 3/5.
- Message / public : voir budget, calories et cours depuis l'écran verrouillé, puis accueil et style. Tout public.
- Fonctions : « Left this month » (budgetLeft), « Calories left » (caloriesLeft), Schedule (nextClass), Quick expense = tous gratuits : la plus honnête de la série. Style Minimal gratuit ; Neon étiqueté « With Premium ».
- Lisibilité : titres petits (~40 px), contours orange qui guident l'oeil. Fin : icône sans verbe.
- Note 7,5/10. Correction n°1 : agrandir les titres de 40 % et ouvrir sur le geste (doigt qui déverrouille).

### pub-organique-main-v1 — 21,5 s
- Accroche : « POV: your whole day lives in one app. » sur téléphone tenu en main, bureau réel. Texte petit en pastille grise. 3,5/5.
- Message / public : tout le quotidien dans l'app (Tasks, Workouts, Meals, Classes, Trips) puis personnalisation. Grand public.
- Fonctions : Tasks, Classes/Grades, Trips = gratuits ; Workouts (« Some features With Premium », Set done Premium) ; Meals/History 7 jours (« 7-day history With Premium », Premium, étiqueté) ; styles dorés étiquetés. Écrans filmés en main : crédible, gestes petits.
- Lisibilité : sous-titres en pastille petits (~34 px), étiquettes minuscules ; chaque libellé répété sur 2-3 plans. Fin : icône sans verbe.
- Note 7/10. Correction n°1 : doubler la taille des sous-titres et supprimer les plans en doublon.

### pub-organique-nutrition-v5.1 — 26,3 s
- Accroche : « Still guessing your calories? » orange sur petit-déjeuner, très lisible. Douleur forte, décor appétissant. 4/5.
- Message / public : scanner un plat, régler la quantité, voir macros, historique, personnaliser. Public perte de poids/fitness.
- Fonctions : scan photo (gratuit, 10 analyses, non dit), 4 macros (gratuit), « More nutrients With Premium » (étiqueté, petit), « Your whole week. With Premium » (historique, étiqueté), styles « Some widgets With Premium ».
- Lisibilité : excellente, couleurs chaudes cohérentes. Fin : « Always in sight » puis icône, sans CTA.
- Note 8/10. Correction n°1 : ajouter « 10 scans gratuits » en gros avant l'icône et un « Free on the App Store ».

### pub-organique-papier-v1 — 23,0 s
- Accroche : « Still tracking it on paper? » mains sur post-it, blanc/bleu. Question claire, humain, mais fond gris terne. 3,5/5.
- Message / public : remplacer papier et calculatrice par widgets (liste, dépenses, solde). Public organisation.
- Fonctions : Tasks, Quick expense, Left this month = gratuits. Styles Pastel et Aurora étiquetés « With Premium » (pastille). Le moins de Premium implicite de la série. Montage « OLD WAY / NEW WAY » très clair.
- Lisibilité : étiquettes « NEW WAY » petites ; le reste lisible. « Put the pen down. » fort. Fin : icône sans verbe.
- Note 8/10. Correction n°1 : agrandir « OLD WAY / NEW WAY » et finir par un CTA texte.

### pub-organique-planning-v2 — 23,8 s
- Accroche : « Writing to-do lists you never look at again? » sur post-it flou, lisible. Question vécue, gros plan humain. 4/5.
- Message / public : to-do sur écran verrouillé et accueil, semaine, import d'emploi du temps, styles. Étudiant/actif.
- Fonctions : Tasks widget (gratuit, bouton), pages Tasks et Week (gratuites), « Import a schedule. With Premium » (étiqueté, bien), widget emploi du temps et styles « With Premium » en petit.
- Lisibilité : bon, décor animé sympa. Boucle narrative réussie (post-it « DONE! »). Fin : icône sans verbe.
- Note 8/10. Correction n°1 : montrer l'import fonctionner (photo vers calendrier), c'est la meilleure démonstration Premium.

### pub-organique-pov-v1 — 21,0 s
- Accroche : « POV: you check off your day without opening an app » sur main tenant un téléphone, texte doublé sur 2 plans. Format POV reconnu, humain, téléphone petit. 3,5/5.
- Message / public : cocher tâches et habitudes depuis l'accueil, puis styles. Tout public.
- Fonctions : Tasks, habitudes, Quick expense, anneau d'objectif de revenu = gratuits ; Blossom, Aurora, Neon étiquetés « With Premium » en pastille lisible.
- Lisibilité : bien, geste « Tap a task » avec pastille de tap. Doublon d'ouverture (0-2 s). Fin : icône sans verbe.
- Note 7,5/10. Correction n°1 : supprimer le doublon d'ouverture et ajouter une action finale.

### pub-organique-satisfying-v1 — 21,4 s
- Accroche : « If checking things off calms you down, watch this. » blanc/bleu. Promesse « satisfaisant », pas de personne. 3,5/5.
- Message / public : « Tap. Tap. Tap. » sur tâches, dépenses, habitudes, puis styles. Public lifestyle.
- Fonctions : tâches, quick expense, habitudes = gratuits ; style Dark gratuit ; Aurora/Blossom « With Premium » en pastille. Geste réel et répétitif, bon pour le temps de visionnage.
- Lisibilité : texte minimal, pastille Premium lisible. Fin : icône sans verbe.
- Note 7,5/10. Correction n°1 : ajouter un son de tap et un CTA texte final.

### pub-organique-scan-v1 — 20,3 s
- Accroche : « Still typing in your dinner? » orange/blanc sur plat de poulet appétissant. Image forte, douleur nette. 4,5/5.
- Message / public : pointer son assiette, estimer, voir les calories restantes sur l'accueil. Public nutrition.
- Fonctions : scan photo (10 analyses gratuites), widget Calories left (gratuit), « Make it yours » Pastel/Blossom « With Premium » (pastille). Fonction centrale gratuite : la plus honnête.
- Lisibilité : excellente, rythme ~1,7 s par plan. « Bon appétit. » final charmant. Fin : icône sans verbe.
- Note 8,5/10. Correction n°1 : ajouter « 10 scans gratuits » et « Free on the App Store ».

### pub-organique-top5-v1 — 24,5 s
- Accroche : « Your Home Screen is missing these 5. » sur accueil sobre. Promesse en liste, pas de personne. 3,5/5.
- Message / public : 5 widgets utiles en compte à rebours (café, habitude, tâche, devoirs, style). Grand public, étudiants.
- Fonctions : Quick expense, Habitudes, Tasks = gratuits ; Homework « With Premium » (étiqueté, petit) ; styles Neon/Aurora « With Premium » (pastille). 3 sur 5 gratuits.
- Lisibilité : compte à rebours 5-4-3-2-1 très clair, mais deux plans par widget (long). Fin : « Nothing missing now. » puis icône sans verbe.
- Note 7,5/10. Correction n°1 : démarrer directement sur le n°5 et limiter chaque entrée à 3 s.

### pub-organique-tuto-v1 — 23,2 s
- Accroche : « How to make your home screen look like this » sur accueil Aurora, texte doublé sur 2 plans, petit. 3/5.
- Message / public : tutoriel en 5 étapes (ouvrir Ardane, Create, taille, style, ajouter). Public débutant.
- Fonctions : les étapes sont gratuites mais le résultat de départ (Aurora) et celui de fin (Neon) sont Premium ; « Aurora style With Premium » minuscule. Le spectateur croit refaire l'accueil Aurora gratuitement : promesse en partie trompeuse.
- Lisibilité : pastilles « STEP 1... » lisibles. Peu de gestes de doigt. Fin : icône sans verbe.
- Note 6,5/10. Correction n°1 : partir d'un style gratuit (Dark/Light) ou écrire « Aurora : Premium » en grand à l'étape 4.

### pub-organique-verrou-v1 — 12,6 s
- Accroche : « Crazy how one Lock Screen runs my whole day. » texte répété sur tous les plans, heure énorme. Ton témoignage, sans personne ni geste. 3/5.
- Message / public : l'écran verrouillé affiche tâches, cours, calories, rest timer toute la journée.
- Fonctions : tâches, Schedule, Calories = gratuits ; rest timer Skip/Set done = Premium, « Some widgets and styles With Premium » minuscule (~14 px).
- Lisibilité : horloge lisible, titre petit. Rythme ~1 s par plan, très court (12,6 s) : sous les 20 s visés par la charte interne. Fin : icône sans verbe.
- Note 6,5/10. Correction n°1 : rallonger à 18-20 s (Studio, accueil), agrandir le titre et la mention Premium.

### pub-organique-voyage-v3 — 23,9 s
- Accroche : « Bookings buried in your inbox? » sur voyageuse avec valise, vert lisible. Humain réel, douleur claire. 4/5.
- Message / public : tout le voyage dans l'app (programme, hébergement, budget, liste à emporter), compte à rebours, styles. Voyageurs.
- Fonctions : écrans Voyage, Program, Budget, liste = sans verrou Premium dans le code ; compte à rebours « 18 days until Lisbon » (tripCountdown) gratuit ; plan final « On the trip » avec Day 4/10 et Hotel (tripProgress, hotel) = Premium, mention petite seulement sur ce plan.
- Lisibilité : bonne, couleurs fraîches ; le plan Program est répété. Fin : « bon voyage. » sur aile d'avion puis icône, sans verbe.
- Note 8/10. Correction n°1 : supprimer le doublon Program et marquer Hotel/Day 4 comme Premium en pastille lisible.

### pub-principale-v5-restylee-v3 — 58,9 s
- Accroche : icône calendrier « PLANNING — Your life isn't one thing. » (affiche/logo), puis plan noir avec une barre lumineuse. Pas de personne, app non identifiable (on voit un calendrier). 2,5/5.
- Message / public : tour d'horizon (Planning, Nutrition, Fitness, Finances, Store) puis personnalisation. Pub de marque tous publics.
- Fonctions : Nutrition avec « 10 free, then With Premium » (seul plan qui écrit la limite gratuite, bien) ; Fitness avec démo animée d'exercice (bibliothèque, Premium, non étiqueté) ; Finances Trends 6 mois (Premium, non étiqueté) ; widgets Macros (Premium) ; styles Neon/Everyday avec mention petite.
- Lisibilité : titres d'un mot très lisibles, sous-titres petits. 58,9 s : bien trop long pour de l'organique (max 30 s). Fin : logo en fondu, pas de CTA.
- Note 5/10. Correction n°1 : couper à 25-30 s (ouvrir sur Nutrition « 10 free » avec le scan, garder 3 écrans) et retirer l'affiche d'ouverture.

### voici-ton-telephone-avant-apres-v5 — 25,0 s
- Accroche : « This is your phone... » accueil iOS banal, puis « ...and this is mine. » Avant/après immédiat. Pas de personne. 4/5.
- Message / public : transformer un accueil banal en accueil thématique (Sport, Organisation, Finance, Wellness, Voyage). Public esthétique/personnalisation.
- Fonctions : Next set, Business (revenus, graphique), widgets Travel (vol, hôtel, devise) = Premium ; Calories, Habitudes = gratuits ; fonds d'écran stylés (14 gratuits sur 43). Mention « Some widgets and styles With Premium » répétée à chaque plan, minuscule. L'effet « mine » n'est pas atteignable gratuitement (4 styles, 3 widgets).
- Lisibilité : « ...and this is mine. » lisible sur fonds variés. Fin : « Your widgets. Your way. » puis icône + « Available on the App Store » + mention Premium.
- Note 7,5/10. Correction n°1 : écrire en clair « Gratuit : 3 widgets, 4 styles / Premium : tout » sur le dernier plan.

## Classement

| Vidéo | Note | Verdict |
|---|---|---|
| pub-organique-scan-v1 | 8,5 | publier tel quel (CTA à ajouter si possible) |
| pub-organique-nutrition-v5.1 | 8 | publier tel quel |
| pub-organique-papier-v1 | 8 | publier tel quel |
| pub-organique-planning-v2 | 8 | publier tel quel |
| pub-organique-voyage-v3 | 8 | corriger (doublon, mention Premium) |
| pub-organique-gym-v1 | 7,5 | corriger (mention Premium lisible) |
| pub-organique-huit-v1 | 7,5 | corriger (ouverture trop lente) |
| pub-organique-liste3-v1 | 7,5 | corriger (n°1 Premium) |
| pub-organique-lock-v1 | 7,5 | corriger (titres trop petits) |
| pub-organique-pov-v1 | 7,5 | corriger (doublon d'ouverture) |
| pub-organique-satisfying-v1 | 7,5 | corriger (CTA) |
| pub-organique-top5-v1 | 7,5 | corriger (rythme) |
| voici-ton-telephone-avant-apres-v5 | 7,5 | corriger (dire gratuit vs Premium) |
| pub-organique-fitness-v4.3 | 7 | corriger (widget Premium présenté comme standard) |
| pub-organique-inspo-v1 | 7 | corriger (accroche floue) |
| pub-organique-journee-v1 | 7 | corriger (scène Premium) |
| pub-organique-main-v1 | 7 | corriger (sous-titres, doublons) |
| pub-organique-habitudes-v3 | 6,5 | corriger (4 habitudes, Premium illisible) |
| pub-organique-tuto-v1 | 6,5 | corriger (résultat Premium vendu comme gratuit) |
| pub-organique-verrou-v1 | 6,5 | corriger (trop court, texte minuscule) |
| pub-principale-v5-restylee-v3 | 5 | retirer / refaire en 25-30 s |

## 5 constats transversaux

1. Mention Premium présente mais invisible : « Some widgets and styles With Premium » fait environ 10-14 px, gris, sur presque toutes les vidéos. Passer à une pastille lisible (au moins 40 px, fond plein) sur chaque plan Premium, sinon risque de refus de la pub et de retours négatifs d'utilisateurs gratuits.
2. Widgets Premium présentés comme la solution centrale : Set done / Next set / Rest timer (fitness, gym, journée, liste3, verrou) et Habitudes à 4 (habitudes). Ouvrir sur ce qui est gratuit (Live Activity écran verrouillé, 3 habitudes, Tasks, Quick expense, scan) et marquer le reste Premium.
3. Aucun style gratuit montré : tous les styles « wow » (Neon, Aurora, Blossom, Luxury, Carbon) sont Premium. Montrer un avant/après avec un des 4 styles gratuits rendrait le « Make it yours » honnête et ajouterait l'argument « gratuit pour commencer » ; ajouter aussi « 10 scans gratuits » et « 3 widgets gratuits » qui ne sont dits nulle part (sauf la principale).
4. Accroche : les meilleures (scan, nutrition, planning, voyage, papier) combinent une question de douleur et un décor réel ; les plus faibles (inspo, tuto, verrou, lock, principale) ouvrent sur un téléphone petit ou sombre, du texte seul ou un logo. La marque n'apparaît qu'à la fin partout.
5. Fin sans appel à l'action : toutes les vidéos finissent sur l'icône + « Available on the App Store », sans verbe (« Download free »). Plusieurs plans sont en doublon (même texte sur 2-3 plans : huit, habitudes, liste3, pov, tuto, voyage) : couper libère 3-5 s pour un vrai CTA et les limites gratuites.

---
## Annexe E : revue des images et du feed
# Revue marketing : photos (affiches, épinglés, feed) — 2026-11-27

Source : `ardane-hq/workspace/marketing/_imports/photos` (11 affiches 1080x1920, 3 épinglés 1080x1350, 20 posts 1080x1350) + affiches-legendes.md + post-feed-legendes.md. Référence Premium : premium-inventory.md (sections 1, 3, 4). Lecture seule, rien modifié.

## Règles Premium utilisées
- Gratuit : 29 types de widgets (caloriesLeft, budgetLeft, savingsGoal, revenueGoal, habits, habitStreak, tasks/priorités, timetable, tripCountdown...), 4 styles (Minimal, Clair, Sombre, Monochrome), 8 couleurs d'accent.
- Premium : nextSet, assignments (Homework), les 500 autres styles (Néon, Blossom, Aurora, Pastel...), couleur personnalisée, couleur d'app Rubis, "Last time" (historique d'exercice), analyses de plats au-delà de 10.
- Un widget Premium posé sur l'accueil sans abonnement affiche un cadenas, pas les données montrées en pub (aperçu et Studio possibles, enregistrement bloqué).

## Affiches (1080x1920)
Gabarit commun : phrase "à citation" en haut (blanc + mot-clé coloré, très lisible), widget agrandi sur un iPhone, logo en bas à gauche. Lisibilité téléphone : excellente. Faiblesses communes : même gabarit et même arrière-plan (widget Habitudes) sur 9 affiches sur 11 ; le widget agrandi cache presque tout l'iPhone (04, 05, 07, 08, 09, 11), donc "écran d'accueil" peu crédible.

| Image | Montre | Promesse | Lisibilité | App identifiable | Honnêteté Premium | Légende | Note | Correctif |
|---|---|---|---|---|---|---|---|---|
| affiche-01 | "Wait... when is that lab report due?" + Homework | Échéances triées sur l'accueil | Très bonne ; mention "Homework widget With Premium" petite (~30 px), chevauche l'iPhone | Logo + widgets | Honnête sur l'image ; la légende ne le dit pas | Accroche = titre, CTA "Tag the friend", 7 tags | 8 | Mettre "Premium" dans la légende ; agrandir la mention |
| affiche-02 | Écran verrouillé 11:58, "Tomorrow: Math 08:30" | Cours de demain sous l'heure | Très bonne | Logo seul | Gratuit (timetable) | Accroche reprise ; CTA question | 8 | Le widget flotte hors de l'iPhone ; le recadrer |
| affiche-03 | "Can I still have dessert tonight?" + Calories | 1 122 kcal restantes | Très bonne | Oui (Scan, accueil derrière) | Gratuit | Bon CTA (commentaires) | 8 | Modèle à garder |
| affiche-04 | "How much can I still spend today?" + Reste du mois | 1 631 $ / 148 $ par jour | Très bonne | Moyenne (iPhone masqué) | Gratuit | "Save this for payday" | 7 | Montrer sur un vrai accueil |
| affiche-05 | "So much to do. What actually matters today?" + Top 3 | 3 tâches cochables | Bonne ; bleu moyen sur fond sombre | Moyenne | Gratuit (tasks interactif) | Question "top 3" | 7 | Éclaircir le bleu |
| affiche-06 | "Did I read today, or just think about it?" + Habits 2/3 | Une touche coche l'habitude | Très bonne | Oui (accueil visible) | Gratuit | Bon CTA | 7.5 | Vert olive du titre terne |
| affiche-07 | "How is it already day 4 of vacation?" + Lisbon Day 4 of 10 | Voyage jour par jour | Très bonne | Moyenne | Gratuit | Ne parle pas de Lisbonne | 7 | "bon voyage!" en français dans une pub en anglais |
| affiche-08 | "Will I hit my goal this month?" + anneau 84 % | 10 050 $ / 12 000 $ | Très bonne | Moyenne | Gratuit | Bon CTA | 7.5 | Ancrer dans un accueil |
| affiche-09 | "Wait. How many reps was I doing?" + Next set + Set done | Prochaine série sur l'accueil | Très bonne | Moyenne | **Widget Premium présenté comme gratuit** (nextSet est Premium, interactif Premium). La note de légende dit "gratuit" : faux | Aucune mention Premium | 6 | Ajouter "With Premium" ou passer à todaysWorkout / trainingStreak (gratuits) |
| affiche-10 | "Day 12. Not breaking it now." + Meditate 12 jours | Série visible | Très bonne | Moyenne | Gratuit (habitStreak) | Bonne | 7.5 | Titre vert terne |
| affiche-11 | "Is my Japan fund even growing?" + 43 % | 2 150 $ de 5 000 $ | Très bonne | Moyenne | Gratuit | "What are you saving for?" | 7.5 | Idem 04 |

Légendes d'affiches : le texte suit la phrase de l'image (pas de vrai crochet distinct), CTA d'engagement (tag, save, question) bien choisis, 6 à 7 hashtags pertinents mais génériques (#homescreen, #iphonewidgets sur 8 posts). Aucun "Coming soon to the App Store" malgré la règle du fichier : le spectateur ne sait pas où trouver l'app.

## Épinglés (3, sans légende)

| Image | Montre | Promesse | Lisibilité | App identifiable | Honnêteté Premium | Note | Correctif |
|---|---|---|---|---|---|---|---|
| epingle-1-promesse | Icône + "Your whole life. One place." + badge App Store | Widgets et mini-apps pour iPhone | Excellente | Oui | N/A | 7 | Badge App Store affiché avant mise en ligne (contredit "Coming soon") ; promesse vague, aucun widget montré |
| epingle-2-trois-iphone | 3 iPhone : Fitness, accueil complet, Studio | "Your day, at a glance." | Bonne ; sous-titre gris, iPhone latéraux rognés | Oui, image la plus complète | Aucune mention alors que Studio / Live workout sont en partie Premium | 8 | Ajouter "Some features With Premium" |
| epingle-3-styles | 7 styles du même widget, "Make it yours." | Personnalisation | Bonne ; libellés ~28 px | Oui | Partiel : "Some styles With Premium" sans dire lesquels (Light, Dark, Minimal gratuits ; Pastel, Blossom, Aurora, Neon Premium) | 7.5 | Badge doré sur les 4 styles Premium |

## Posts du feed (1080x1350)
Posts à fond uni très lisibles. Posts N&B (03, 09, 15) : titre ~55 px au lieu de ~100, 2e ligne grise sur photo.

| Image | Montre | Promesse | Lisibilité | Honnêteté Premium | Légende | Note | Correctif |
|---|---|---|---|---|---|---|---|
| 01 planning | Emploi du temps hebdo | Planning avant de demander | Excellente | Gratuit | CTA "Search Ardane on the App Store" contredit la règle "une fois en ligne" | 8 | Remplacer par "Coming soon" |
| 02 style-neon | Accueil complet en Néon | Même widgets, nouvelle ambiance | Très bonne | Honnête (mention générique) | CTA question | 8.5 | Aucun |
| 03 nb-fitness | Carte série Bench press sur photo N&B | Log the set, rest, repeat | Titre petit, gris sur photo | Mention vague "Some features" ; "Last time" Premium | "Save this" | 6.5 | Préciser ce qui est Premium ; grossir le titre |
| 04 nutrition | Calories left | Calories à portée de regard | Excellente | Gratuit | Bonne | 8 | Aucun |
| 05 astuce-habitudes | Avant/après 2/3 vers 3/3 | Une touche coche l'habitude | Excellente, pédagogique | Gratuit | CTA question | 8.5 | Aucun, meilleur format |
| 06 verrouille-widgets | Écran verrouillé, aile d'avion | Écran verrouillé utile | "but useful." coupé par le bord de l'iPhone | Gratuit | CTA | 6.5 | Remonter l'iPhone |
| 07 finances | Reste du mois | Mois en un chiffre | Excellente | Gratuit | "Follow" | 8 | Aucun |
| 08 motivation-habitudes | Meditate 12 jours | Petites habitudes, longues séries | Très bonne | Gratuit | "Tag the friend" | 7 | Doublon d'affiche-10 |
| 09 nb-business | Carte Revenue 9 630 $ sur bureau N&B | Mois contre objectif | Titre petit, 2e ligne grise sur affiche murale : mauvais contraste | Ligne "+31,8 % vs mois précédent" probablement Premium (comparatif mensuel), non mentionné | "Save this" | 5.5 | Assombrir la photo, grossir le titre, vérifier le gratuit |
| 10 style-blossom | Accueil Blossom | Rose pastel | Mention chevauche la barre de recherche ("Sea...") | Honnête | CTA | 6.5 | Décaler la mention |
| 11 widget-fitness | Next set + Consistency rouge | Prochaine série en une touche | Très bonne | **Mention trompeuse** : "Custom colours With Premium" alors que le widget Next set est lui-même Premium | "Follow" | 6 | "Next set widget and custom colours With Premium" |
| 12 astuce-scan | Bouton Scan puis récapitulatif "Estimate" | Scanner un plat | Bonne ; bas de carte coupé | Scan gratuit mais 10 analyses à vie, non dit | Honnête sur l'estimation | 8 | Ajouter "10 free scans" en légende |
| 13 widget-business | Goal for the month en Lilas | Objectif en vue | Excellente | Gratuit (Lilas non vérifié dans les 8 accents gratuits) | "Follow" | 7.5 | Confirmer le Lilas |
| 14 verrouille-repos | Live Activity repos en Rubis | Minuteur sur écran verrouillé | Bonne ; iPhone noir vide | Honnête (couleur Rubis Premium ; Live Activity gratuite) | "Save this" | 7.5 | Fond d'écran sur l'iPhone |
| 15 nb-etudes | Notes par cours sur photo N&B | "One clear average" | Titre petit, gris sur photo chargée | Gratuit ; aucune moyenne globale affichée | "Send this" | 6 | Montrer la moyenne ou changer le titre |
| 16 widget-habitudes | Habits 3/3 | Habitudes sur l'accueil | Excellente ; sous-titre "Habits · Habits" | Gratuit | "Follow" | 6.5 | Corriger le sous-titre ; 3e usage de cette capture |
| 17 motivation-top3 | Top 3 du jour | Trois choses, un bon jour | Très bonne | Gratuit | Question | 6.5 | Doublon d'affiche-05 |
| 18 style-aurore | Accueil Aurora | Aurore boréale | Compteurs de séries illisibles ; mention chevauche la barre de recherche | Honnête | CTA | 6.5 | Contraste ; décaler la mention |
| 19 widget-etudes | Homework | Échéances en vue | Excellente | Honnête ("Homework widget With Premium") | "Follow" | 7.5 | Doublon d'affiche-01 |
| 20 widget-voyage | Compte à rebours Lisbonne 18 j | Le décompte démarre | Excellente | Gratuit | "Where are you going next?" | 7.5 | Doublon partiel d'affiche-07 |

## Le feed dans son ensemble
- Cohérence : très bonne (police, pastille de catégorie, logo, une couleur de fond par thème qui tourne). Les 3 posts N&B (03, 09, 15) tombent tous dans la colonne de droite de la grille à 3 colonnes : bande grise, pas d'alternance.
- Variété : faible. 17 posts sur 20 sont un widget blanc sur fond sombre. Aucun visage, aucune vue de mini-app ni du Studio, seulement 3 photos de décor. Les mêmes captures servent aux affiches et au feed.
- Épinglés : bons choix, mais l'épinglé 1 montre le badge App Store avant la mise en ligne et aucun épinglé n'a de légende. L'épinglé 2 explique Ardane en 3 secondes, le 1 non.
- Honnêteté Premium : globalement bonne et visible (pastille "With Premium"), mais fausse sur affiche-09 et post 11, vague sur 03, 09 et les mentions "Some widgets and styles".
- Légendes : hashtags corrects, CTA d'engagement bons, mais pas de crochet distinct de l'image, CTA App Store incohérent.

## Classement

| Rang | Image | Note |
|---|---|---|
| 1 | post-feed-02 style-neon | 8.5 |
| 1 | post-feed-05 astuce-habitudes | 8.5 |
| 3 | affiche-01, 02, 03 | 8 |
| 3 | post-epingle-2 | 8 |
| 3 | post-feed-01, 04, 07, 12 | 8 |
| 11 | affiche-06, 08, 10, 11 | 7.5 |
| 11 | post-epingle-3 | 7.5 |
| 11 | post-feed-13, 14, 19, 20 | 7.5 |
| 20 | affiche-04, 05, 07 | 7 |
| 20 | post-epingle-1 | 7 |
| 20 | post-feed-08 | 7 |
| 23 | post-feed-03, 06, 10, 16, 17, 18 | 6.5 |
| 29 | affiche-09, post-feed-11, post-feed-15 | 6 |
| 32 | post-feed-09 | 5.5 |

## 5 constats
1. Deux widgets Premium sont présentés comme gratuits : affiche-09 (Next set, aucune mention, la note de légende dit "gratuit" à tort) et post 11 (mention "Custom colours" alors que Next set lui-même est Premium). Un utilisateur gratuit verrait un cadenas. À corriger avant publication.
2. CTA incohérent : badge "Download on the App Store" (épinglé 1) et "Search Ardane on the App Store" (post 01) contredisent la règle "Coming soon". Aligner tous les CTA sur l'état réel de l'app.
3. Les posts N&B avec photo (03, 09, 15) sont les plus faibles : titre deux fois plus petit, 2e ligne grise sur image chargée, carte d'app plutôt que widget d'accueil. Assombrir et grossir, ou passer au gabarit fond uni.
4. Répétition : mêmes ~9 captures dans affiches et feed, aucune vue de mini-app ni du Studio, aucun humain. Ajouter 4 à 6 vues de mini-app et du Studio pour montrer les 504 styles en action.
5. Défauts de mise en page : titre rogné (post 06), mention Premium sur la barre de recherche (10, 18), compteurs illisibles sur Aurora (18), "Habits · Habits" (16), "bon voyage!" en français (affiche-07), widget qui masque l'iPhone (affiches 04, 05, 07, 08, 09, 11).
