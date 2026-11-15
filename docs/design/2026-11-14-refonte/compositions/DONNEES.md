# Données des compositions : ce que les cartes affichent vraiment, et la journée d'exemple

Relevé dans le code le 2026-11-14 (`App/Screens/Home/DailySection.swift`, `App/Core/DailyBrief.swift`, `MiniAppsRow.swift`). **Ne dessiner que ce qui est listé ici.** Étiquettes : E = Existe sur l'accueil ; A = À adapter (la donnée existe dans l'app, mais pas à cet endroit ou pas sous cette forme) ; D = À développer.

## 1. Ce que chaque carte peut montrer

**Cadre commun (E)** : icône + titre de la carte, chevron si la carte ouvre la mini-app, badge facultatif (« Maintenant »). Deux tailles seulement : demi-largeur et pleine largeur (pas de carte « haute »). Une carte vide est un cadre en pointillés avec « Ajouter ». Un « + » en pointillés en bas (« Ajouter une catégorie »). « Organiser » : aujourd'hui dans le menu de l'appui long (un lien visible = A).

**Nutrition** (3 vues avec points de pagination : « Aujourd'hui », « Repas », « 7 jours »)
- E : anneau + chiffre + « kcal restantes » (ou « kcal en trop », « kcal mangées ») ; « mangé / objectif » ; Protéines, Glucides, Lipides en « mangé/objectif g » avec une barre fine ; bouton « Scanner » ; pastille « N repas » ; « Prochain repas : souper, environ 650 kcal ».
- E (vue Repas, « Repas du jour ») : une ligne par repas avec « N kcal » ou « — », puis « Total : X / Y kcal ». Repas : Déjeuner, Dîner, Souper, Collation (français du Canada).
- E (vue « Calories · 7 jours ») : 7 barres, une ligne d'objectif, « Moyenne : N kcal par jour noté ».
- Montrer deux vues côte à côte ou la vue Repas directement = A.

**Séance / Fitness** (2 vues : « Séance », « Semaine »)
- E prévue : titre « Séance du jour », nom du programme, « 6 exercices · 18 séries », bouton « Commencer », badge « Maintenant » après le matin.
- E en cours : titre « Séance en cours », nom de l'exercice, « Série 2/4 · 10 × 60 kg », minuteur de repos avec pause, bouton « Série faite ».
- E faite : « Faite · 18 séries », « 4 320 kg soulevés ».
- E jour de repos : « Repos aujourd'hui », « Demain : Jambes ».
- E (vue « Cette semaine ») : « 2/4 séances », 7 points du lundi au dimanche, « Encore 2 séances ».
- N'existe pas : série de jours de sport, calories brûlées, fréquence cardiaque.

**Planning** (une vue)
- E : une **grille de la semaine** (colonnes lun à dim, heures 8 à 18 au moins, blocs colorés : cours, travail, rendez-vous, tâches, séances, calendrier Apple). En pleine largeur, les blocs portent le nom, puis le lieu et l'heure s'il y a la place ; en demi-largeur, les blocs sont sans texte. Pied : « Toute la semaine ».
- A : une **liste des prochains événements** (heure au format 24 h « 14:00 », titre, lieu). La donnée existe (elle sert à classer les cartes, 5 éléments au plus) mais la carte ne l'affiche pas en liste aujourd'hui.

**Habitudes** (une vue ; la carte ouvre la page, on ne coche pas depuis la carte)
- E demi : un petit anneau par habitude (5 au plus, puis « +N »), plein avec une coche si faite ; le compte « 3 » en gros + « /5 » ; « Série de 12 jours » (la plus longue série).
- E pleine : compte + série, puis une ligne par habitude (anneau, nom, petits carrés des 7 derniers jours).
- A : cocher une habitude depuis l'accueil.

**Budget / Finances** (une vue, même contenu en demi et en pleine)
- E : montant + « à dépenser par jour d'ici la fin du mois » ; « Dépensé aujourd'hui : 14,50 $ » ; courbe des dépenses des 7 derniers jours.
- E (chiffre court) : « 412 $ restants » ou « Budget dépassé ».
- A : « Dépensé ce mois : 788 $ sur 1 200 $ » avec une barre (la donnée existe dans la mini-app).
- A : « Solde » d'un compte saisi à la main (existe dans la mini-app Finances, pas sur l'accueil).
- N'existe pas sur l'accueil : catégories de dépenses, épargne. Les factures proches vont dans « À ne pas oublier ».

**Top 3** (E) : jusqu'à 3 tâches cochables (cercle ou coche, texte barré une fois fait), champ « Ajouter une tâche ».

**À ne pas oublier** (E) : jusqu'à 4 lignes (icône colorée, titre, échéance à droite) : « Examen : … », devoirs, factures (« Demain · 45 $ »), échéances auto, « Départ pour <ville> ». Échéances : « En retard », « Aujourd'hui 16:30 », « Demain », jour de la semaine.

**Pas** (2 vues) : E : « 5 480 / 8 000 », une barre ; vue « Pas · 7 jours » : 7 barres, « Moyenne : N pas ».

**Chiffre court par mini-app** (existe dans le code, rangée « Mes mini-apps » non branchée = A) : Nutrition « 1 078 kcal aujourd'hui » · Fitness « Séance en cours » ou « 2 séances cette semaine » · Planning « Réunion projet à 14:00 » ou « 3 tâches aujourd'hui » · Finances « 412 $ restants » · Entreprise « 2 450 $ ce mois » · Voyage « Lisbonne · J-23 » · Auto « ≈ 380 km d'autonomie » · Photos « 3 widgets photo ou citation ».

**Structures nouvelles déjà admises** : carte « Maintenant » = la carte la mieux classée du moment, mise en avant (A) ; rangée ou grille « Mes mini-apps » avec le chiffre court (A) ; sommaire d'une ligne par mini-app (A) ; phrase du jour composée à partir des données (D).

**Couleurs de catégorie dans l'app** (chaque style les ré-accorde, comme sur ses planches précédentes) : Nutrition `#F08A24`, Fitness `#E5484D`, Planning `#3366FF`, Habitudes `#5C8424`, Budget `#2F8F7A`, Productivité (Top 3) `#6B7280`, Pas `#12A4B5`. Macros : protéines rouge, glucides jaune, lipides bleu.

## 2. La journée d'exemple : jeudi 12 novembre, avatar « M »

Montants au format du Canada français : « 412 $ », « 21,68 $ ». Heures des événements en 24 h : « 14:00 ». Milliers avec une espace : « 1 122 ».

| | Matin 08:10, « Ta matinée » | Journée 13:20, « Ta journée » | Soirée 19:05, « Ta soirée » |
|---|---|---|---|
| Calories (objectif 2 200) | 420 mangées, **1 780 restantes** | 1 078 mangées, **1 122 restantes** | 1 520 mangées, **680 restantes** |
| Protéines / 140 g | 24 | 68 | 96 |
| Glucides / 250 g | 52 | 121 | 168 |
| Lipides / 70 g | 12 | 34 | 46 |
| Repas notés | 1 : Déjeuner 420 | 2 : Déjeuner 420, Dîner 658 | 3 : Déjeuner 420, Dîner 658, Collation 442 ; Souper « — » |
| Prochain repas | dîner, environ 650 kcal | souper, environ 700 kcal | souper, environ 680 kcal |
| Séance | « Séance du jour » : Haut du corps, 6 exercices · 18 séries, « Commencer » | la même, avec le badge « Maintenant » | « Séance en cours » : Développé couché, Série 2/4 · 10 × 60 kg, repos 0:45, « Série faite » |
| Semaine de sport | 2/4 séances (lundi et mardi faits), « Encore 2 séances » | idem | idem |
| Habitudes | **1/5** | **3/5** | **4/5** |
| Budget | 22,45 $ par jour ; dépensé aujourd'hui : 0 $ ; 426,50 $ restants | **21,68 $ par jour** ; dépensé aujourd'hui : 14,50 $ ; **412 $ restants** ; dépensé ce mois : 788 $ sur 1 200 $ | comme la journée |
| Pas (objectif 8 000) | 1 240 | 5 480 | 7 360 |
| Top 3 | 0 faite | 1 faite (le rapport) | 2 faites (le rapport, la banque) |

- **Habitudes** (5, série de 12 jours) : Boire 2 L d'eau · Lecture 20 min · Méditation · Vitamines · Coucher avant 23 h. Faites le matin : Vitamines. À 13:20 : + Méditation, Lecture. À 19:05 : + Boire 2 L d'eau.
- **Planning du jeudi** : 09:00 Comptabilité (cours, B-204) · 11:30 Travail d'équipe (Bibliothèque) · 14:00 Réunion projet (Local 3.12) · 16:30 Dentiste · 18:30 Séance Haut du corps. Vendredi : 10:00 Statistiques (cours) · 13:00 Travail (jusqu'à 17:00). Reste de la semaine pour la grille : lundi 09:00 Comptabilité, 13:00 Marketing ; mardi 10:00 Statistiques, 18:00 Séance ; mercredi 09:00 Marketing, 13:00 Travail ; samedi 10:00 Séance Jambes.
- **Top 3** : Rendre le rapport de marketing · Appeler la banque · Réviser le chapitre 4.
- **À ne pas oublier** : Facture Internet, « Demain · 45 $ » · Devoir : étude de cas, « Vendredi » · Examen : Statistiques, « Lundi » · Assurance auto, « Mardi · 62 $ ».
- **Calories · 7 jours** (ven à jeu) : 2 250, 2 480, 2 050, 2 140, 2 310, 1 980, puis aujourd'hui en cours ; « Moyenne : 2 202 kcal par jour noté ».
- **Dépenses · 7 jours** (courbe) : 32, 0, 58, 12, 41, 9, puis 14,50 aujourd'hui.
- **Solde** (A, si une composition le montre) : Compte chèques, 1 846,20 $.

## 3. Quel moment pour quelle composition
- **A · Équilibrée** : journée, 13:20.
- **B · Quotidien** : soirée, 19:05 (la séance est en cours : c'est elle, « Maintenant »).
- **C · Éditoriale** : matin, 08:10.
- **D · Compacte** : journée, 13:20.
- **E · Premium** : soirée, 19:05.
