# Guide des planches : refonte UX/UI des mini-apps (2026-11-17)

Ce dossier `base/` est la boîte à outils commune des 63 planches (9 sujets × 7 planches). Elle fait que toutes parlent la même langue visuelle. Ton travail se réduit au contenu : quoi montrer, dans quel ordre, avec quels mots.

Mission du PDG : `../MISSION.md`. Organisation : `../ESTIMATION.md`. Vérité sur ce qui existe : `../audit/NN-sujet.md` (et `../audit/00-socle-commun.md` pour ce que toutes les mini-apps partagent). Précédent à égaler : `../../2026-11-16-finance/`.

## 0. Les cinq règles qui ne se discutent pas

1. **Conception seulement.** Tu n'écris que dans le dossier de ton sujet. Jamais dans `App/`, `Shared/`, `Widgets/`, `Tests/`, `UITests/`, `scripts/`, `.github/`, ni dans `base/`, ni dans `../../2026-11-15-cristal/`. Aucune commande git qui écrit. Les images vont dans `pub/rapports/` (hors dépôt), toutes seules.
2. **Style imposé : Cristal « Équilibrée »** (et C1 « Atelier » pour ce qui touche à la création de widgets). Aucune nouvelle identité graphique, aucune couleur inventée, aucune police ajoutée.
3. **Rien n'est retiré.** Chaque fonction F1…Fn de l'audit garde une place. La table de fin le prouve, ligne par ligne.
4. **Rien d'inventé n'est montré comme existant.** Ce qui n'est pas dans l'audit porte « Nouveau », dans l'écran et dans la légende.
5. **Français du Canada, mots simples, libellés de l'app tels qu'ils s'affichent** (recopiés de l'audit, entre « »).

## 1. Ce que contient `base/`

| Fichier | Rôle |
|---|---|
| `planches.css` | Les pièces communes (préfixe `pl-`). Se charge après `cristal.css`. |
| `planches.js` | L'objet `PL` (pièces d'écran, graphiques, table de fin, grille de notes, contrôle), les couleurs d'accent manquantes, 54 icônes de plus. Se charge après `cristal.js`. |
| `render.py` | Le rendu en images. Un seul script pour tous les sujets : la sortie se calcule depuis le chemin de la planche. |
| `GABARIT-direction.html` | Squelette commenté d'une planche de direction (6 écrans d'exemple). **À copier.** |
| `GABARIT-analyse.html` | Squelette de la planche d'analyse (planche 0). |
| `GABARIT-comparaison.html` | Squelette de la planche de comparaison (planche C). |
| `CATALOGUE.html` | Les 9 couleurs d'accent sur de vraies pièces et toutes les icônes avec leur nom. À ouvrir pour choisir une icône. |
| `GUIDE-PLANCHES.md` | Ce guide. |

Rendus de référence, à regarder avant de commencer : `pub/rapports/design-2026-11-17-mini-apps/base/GABARIT-direction-contact.jpg`, `GABARIT-comparaison-contact.jpg`, `GABARIT-analyse-contact.jpg`, `CATALOGUE-contact.jpg`.

À lire aussi, une fois : `../../2026-11-15-cristal/GUIDE.md` (le système Cristal) et l'en-tête de `cristal.css` et de `cristal.js` (classes, icônes `P`, données `DAY`, utilitaires `U`). On ne modifie ni l'un ni l'autre.

## 2. Les fichiers d'un sujet

Dans le dossier du sujet (celui que ta tâche indique), à côté de `base/` :

| Fichier | Contenu |
|---|---|
| `00-analyse.html` | L'existant : captures réelles annotées, problèmes, fonctions, ce qui n'existe pas |
| `01-<nom>.html` à `05-<nom>.html` | Les cinq directions. `<nom>` = nom court de la direction, en minuscules, sans accent, avec des tirets (`01-minimaliste.html`, `02-tableau-de-bord.html`) |
| `06-comparaison.html` | Notes, avantages et inconvénients, recommandation, questions |
| `<sujet>.js` | **Le JS commun du sujet**, écrit une seule fois : la liste `FONCTIONS` (F1…Fn de l'audit), les données d'exemple du sujet, les pièces qui ne servent qu'à lui |
| `<sujet>.css` | Le CSS commun du sujet, s'il en faut (préfixe = la clé du sujet : `nut-`, `fit-`…) |
| `README.md` | Résumé du sujet : planches, notes, recommandation, questions, limites |

Si le JS commun du sujet n'existe pas encore quand tu commences une direction, ne recopie pas la liste des fonctions dans ta planche : signale-le dans ton rapport. Cinq copies d'une même liste finissent toujours par différer.

Chargement, dans cet ordre (voir les gabarits) :

```html
<link rel="stylesheet" href="../../2026-11-15-cristal/cristal.css">
<link rel="stylesheet" href="../base/planches.css">
<link rel="stylesheet" href="nutrition.css">            <!-- s'il existe -->
<style>/* CSS propre à la planche, préfixe à elle */</style>
…
<script src="../../2026-11-15-cristal/cristal.js"></script>
<script src="../base/planches.js"></script>
<script src="nutrition.js"></script>
<script>/* les écrans, la table de fin */ PL.init();</script>
```

`PL.init()` s'appelle **en dernier** et **remplace** `Cristal.init()` (il l'appelle lui-même). Aucune ressource du réseau.

## 3. Structure d'une planche de direction

Toujours ces cinq blocs, dans cet ordre (`GABARIT-direction.html`) :

1. **En-tête** (`.bd-head`) : le numéro (1 à 5), la ligne `.pl-kick` (« Direction 2 sur 5 » ; la pastille de la mini-app s'y pose toute seule), le titre « Direction N · Nom », deux ou trois phrases, le badge « Phase 2 · conception · données d'exemple ».
2. **« La logique »** (`.pl-rule`) : quatre colonnes, toujours ces titres : « La logique » (un titre de 4 à 6 mots et 3 ou 4 phrases), « En ouvrant <mini-app> », « En faisant défiler », « Forces et limites » (`<p class="plus">`, `<p class="minus">`). Chaque ligne des deux colonnes du milieu porte sa priorité : `<li data-p="1">` (P1 = vu tout de suite, P2 = vu en un coup d'œil, P3 = en défilant ou derrière un toucher). Quatre lignes au plus par colonne.
3. **6 à 9 écrans**, en rangées de 4 (`.row` > `.col`). La mission (section 4) demande au moins : l'écran principal ; les sections et leurs accès ; une vue détaillée d'une fonction importante ; une vue de gestion ou de personnalisation ; une vue secondaire. Ce n'est pas cinq variantes d'une même page : une direction change l'ordre, le rangement et la navigation.
4. **Une case de texte** (`.col.pl-w2` ou `.pl-w3`, dans la dernière rangée) : ce que la direction garde tel quel, change de place, laisse de côté ; « Nouveau, à développer (n) » avec la liste numérotée et l'écran de chaque nouveauté ; « Gratuit / Premium » en deux phrases.
5. **La table de fin** « Rien n'est retiré : où se trouve chaque fonction existante » (`PL.mapTable`, § 8).

### Une colonne d'écran

```html
<div class="col"><div class="nm">Page principale</div>
  <div class="phone app pl-past t-saphir" data-c="nut" data-time="13:20" data-tab="0" id="p1"></div><span class="flow"></span>
  <div class="cap"><h4>Ce qu'il reste, d'abord</h4>
    <p>Une ou deux phrases : ce que la personne voit, et pourquoi c'est rangé ainsi.</p>
    <ul><li><span class="tag e"></span><span>Ce qui existe déjà, avec ses libellés.</span></li>
      <li><span class="tag a"></span><span>Ce qui existe mais change de place ou de forme.</span></li>
      <li><span class="tag n"></span><span>Ce qui n'existe pas dans l'audit.</span></li>
      <li><span class="tag g" data-to="3"></span><span>Toucher la ligne « Dîner ».</span></li></ul></div></div>
```

- `.nm` : le nom de l'écran, **sans numéro**. `PL.init` numérote les écrans dans l'ordre du document ; ce numéro est celui de la table de fin et du fichier découpé `ecrans/<planche>-NN.png`.
- `.phone app t-saphir` : toujours. `data-c` = la clé de la mini-app (§ 6). `data-time="13:20"`. `data-tab="0"` (la barre d'onglets, Accueil actif) ou `"none"` (une feuille est ouverte, ou la page n'a pas de barre : séance en cours, caméra). Ajoute `pl-past` quand la mini-app bloque le futur (journal de repas, de pleins, de ventes).
- `<span class="flow"></span>` : la flèche vers l'écran de droite. Pas sur le dernier écran d'une rangée. Elle veut dire « on passe de l'un à l'autre » : ne la mets pas entre deux écrans sans lien.
- **Les étiquettes se laissent vides** : `PL.init` écrit « Existe », « À adapter », « Nouveau », « → Écran 3 ». Ainsi le mot est le même partout.
  - `tag e` **Existe** : c'est dans l'audit, à cet endroit ou presque.
  - `tag a` **À adapter** : la donnée ou la fonction existe, mais pas à cet endroit ou pas sous cette forme.
  - `tag n` **Nouveau** : ce n'est pas dans l'audit. Il faudra le développer.
  - `tag g data-to="N"` **passage** : le geste qui mène à l'écran N (toucher, faire défiler, balayer). Au moins un par écran qui mène ailleurs. C'est ce qui montre « comment on passe d'un écran à l'autre », y compris quand les deux écrans ne sont pas voisins.

## 4. Mesures : planche, téléphones, écran

- **Largeur de planche : `<body style="--bw:1860px">`, toujours.** 4 colonnes de 411 points, 47 entre elles. Case de texte : `pl-w2` = 869 (2 colonnes), `pl-w3` = 1 327, `pl-w4` = 1 785. La hauteur est libre.
- **Téléphone : 393 × 852 points** (proportions d'un iPhone récent, 2,17 de haut pour 1 de large), cadre de 9, rayon 55. Jamais d'agrandissement, de réduction ni de `transform` sur un téléphone. La barre d'état, l'îlot, la barre d'onglets et l'indicateur d'accueil sont posés par le script.
- **Dans l'écran** (`.scr`) : marges de 20, donc 353 de large ; 12 entre deux panneaux ; 14 à 16 de marge intérieure ; rayon 26. Largeur utile d'une carte : 319 (c'est la largeur par défaut des graphiques).
- **Hauteur utile** : la page commence à 54 du haut du téléphone (sous la barre d'état) et la barre d'onglets couvre le bas. Ce qui compte doit finir avant **740 points du haut du téléphone** (soit 690 de page) ; avec une action flottante (`PL.fab`), avant **650** (600 de page). Plus bas, le contenu s'efface dans le fondu.
- Boutons et cibles : 44 points au moins. Action flottante : capsule de 50.

## 5. Ce qui va dans un écran, ce qui va en légende, et combien

**Dans l'écran : seulement ce que la personne verrait dans l'app.** Les vrais libellés, des données d'exemple, les états réels (vide, verrouillé, en cours). Deux marques seulement s'y ajoutent : le jeton « Nouveau » et le badge Premium (qui existe dans l'app).
Jamais dans un écran : une explication, une flèche, un numéro de repère, « À adapter », du faux texte, un commentaire de concepteur.

**En légende : le pourquoi.** Un titre de 3 à 6 mots qui dit le choix. Une ou deux phrases. Puis 2 à 5 lignes étiquetées. Pas de paragraphe de plus : ce qui est long va dans la case de texte.

**Densité maximale d'un écran**

| Élément | Maximum |
|---|---|
| Carte de verre (`.gl`) dans la page | 1 (le héros). Le sélecteur de semaine, les boutons ronds et la barre d'onglets sont aussi en verre : rien d'autre |
| Action principale (`.btnP` ou action flottante) | 1 par écran. Les autres boutons sont teintés (`T`) ou en contour (`O`) |
| Couleur d'action | 1 : celle de la mini-app. Les autres couleurs ne servent qu'aux icônes et aux graphiques |
| Blocs visibles sans défiler | 5 (héros compris) |
| Lignes dans une liste visible | 6 ; au-delà, « Tout voir » |
| Tuiles de chiffres | 4 par rangée, 6 par écran |
| Graphiques | 1 par carte, 2 par écran ; chacun avec sa légende écrite et un `aria` qui le dit en une phrase |
| Feuille | ne monte jamais jusqu'à la barre d'état (`o.full` = le plus haut permis) |
| Texte | 12 au plus petit ; un état ne repose jamais sur la couleur seule (un mot, une coche, un signe, un motif) |

Une page plus longue que l'écran se montre en deux écrans : « Page principale » et « Page principale, suite » (défilée). Le dernier panneau peut s'effacer sous la barre d'onglets : c'est le défilement. Mais plus de 320 points cachés, c'est du travail que personne ne verra : le contrôle le signale.

**Premium** : le badge doré (`PL.prem()`), le cadenas (`PL.lock`, `x.lock`), la carte « … est dans Premium » (`PL.lockCard`). Les frontières gratuit / Premium de l'audit ne bougent pas. Montre ce que voit un compte gratuit là où c'est important.

## 6. Couleur d'accent par mini-app

`<main class="bd t-saphir" data-c="…">` et chaque téléphone portent la clé du sujet. La nappe du haut de l'écran, la couleur d'action de la page, les pastilles d'icône et l'en-tête de la planche suivent.

| Sujet | Clé `data-c` | Icône | HEX du modèle | À l'écran, Saphir clair : icônes et graphiques (`--c`) | Couleur d'action de la page (`--cs`) | D'où vient la base |
|---|---|---|---|---|---|---|
| Nutrition | `nut` | `fork` | `F08A24` | `#C36F25` | `#A75F1F` | `cristal.js` |
| Fitness | `fit` | `dumbbell` | `E5484D` | `#DF5661` | `#BF4A53` | `cristal.js` |
| Planning | `pla` | `calendar` | `3366FF` | `#4385DB` | `#3A72BC` | `cristal.js` |
| Habitudes | `hab` | `repeat` | `7FA33A` | `#49961D` | `#3F811A` | `cristal.js` (déjà complète : rien à poser à la main) |
| Études | `etu` | `graduation` | `D6409F` | `#DD4DA1` | `#BE428A` | **ajoutée** : le magenta « rendez-vous » de Cristal, à 4° de teinte du modèle |
| Entreprise (« Business » dans l'app) | `ent` | `briefcase` | `8C6CFF` | `#926FE4` | `#7D5FC4` | **ajoutée** : le violet « travail » de Cristal, à 2° du modèle |
| Voyage | `voy` | `plane` | `12A4B5` | `#1E929F` | `#1B7D88` | **ajoutée** : la base « Pas » (même HEX dans le modèle) |
| Auto | `aut` | `car` | `6B7280` | `#79849A` | `#687184` | **ajoutée** : la base « Top 3 » (même HEX dans le modèle) |
| Photos et citations | `pho` | `images` | `D9608B` | `#D9608B` | `#BA5277` | **ajoutée** : le HEX du modèle, déjà doux (61 % de saturation) |

- Règle de calcul, la même que `cristal.js` et que l'app (`CristalPalette.categoryHex`) : la base est assombrie jusqu'à 3,2:1 sur le panneau, puis jusqu'à 4,6:1 sur blanc pour la couleur d'action. Les autres clés de Cristal restent disponibles pour les icônes et les graphiques : `bud`, `pro`, `pas`, `prot`, `gluc`, `lip`, et `data-ev="cours|travail|rdv|seance|tache"`.
- **Aucune teinte nouvelle** : quatre des cinq clés ajoutées reprennent une couleur que Cristal a déjà. Les HEX des modèles ne changent pas (les widgets les lisent).
- **À dire dans la comparaison de ces sujets, comme question au PDG** : (1) Études prend le magenta des rendez-vous de Planning, comme le fait déjà le modèle à 4° près ; (2) Entreprise a deux couleurs dans le code (violet `8C6CFF` pour la mini-app, or `C28A12` pour l'espace et les widgets) : les planches montrent le violet adouci ; (3) dans l'app d'aujourd'hui, Études, Business et Photos affichent leur HEX brut : l'intégration devra ajouter ces bases à `CristalPalette` pour obtenir exactement ces teintes.
- Rouge = alerte ou dépassement seulement (`var(--pl-over)`). Vert = bon, fait (`var(--pl-ok)`). Gris = période précédente (`var(--pl-prev)`). Violet = nouveauté (jamais ailleurs).

## 7. Données d'exemple

**Une seule journée pour les 63 planches : jeudi 12 novembre 2026, 13 h 20.** Avatar « M ». Semaine du lundi 9 au dimanche 15. Novembre a 30 jours et commence un dimanche (`PL.JOUR`). Deux autres moments sont permis pour montrer un état différent : 08:10 et 19:05 (`data-time`, et dis-le dans la légende).

Les chiffres qui existent déjà (planches Cristal et Finance) et qu'aucune planche ne contredit :

| Sujet | Repères |
|---|---|
| Nutrition | 1 078 kcal mangées, 1 122 restantes, objectif 2 200 · protéines 68 / 140 g, glucides 121 / 250 g, lipides 34 / 70 g · Déjeuner 420 kcal, Dîner 658 kcal, Souper et Collation « Rien noté » · lundi 2 140, mardi 2 310, mercredi 1 980 · 7 derniers jours : `CAL7` · poids 71,6 kg (−0,5 kg en 7 jours) |
| Fitness | Séance du jour « Haut du corps », 6 exercices, 18 séries, à 18:30 · une fois faite : 52 min, 4 320 kg soulevés · 2 séances faites sur 4 cette semaine · à 19:05 : Développé couché, série 2 sur 4, 10 × 60 kg, repos 0:45 · pas : 5 480 sur 8 000 |
| Planning | `EVENTS` de `cristal.js`. Jeudi : 09:00 Comptabilité (B-204), 11:30 Travail d'équipe (Bibliothèque), 14:00 Réunion projet (Local 3.12), 16:30 Dentiste, 18:30 Séance Haut du corps · Top 3 : « Rendre le rapport de marketing », « Appeler la banque », « Réviser le chapitre 4 » (1 faite sur 3 à 13:20) |
| Habitudes | 5 habitudes : Boire 2 L d'eau, Lecture 20 min, Méditation, Vitamines, Coucher avant 23 h · 3 faites sur 5 à 13:20 (Lecture, Méditation, Vitamines) · série de 12 jours. Attention : la limite gratuite est de 3 habitudes ; avec 5, le compte montré est Premium |
| Études | Les cours de `EVENTS` : Comptabilité (lundi et jeudi 09:00, B-204), Marketing (lundi 13:00, mercredi 09:00), Statistiques (mardi et vendredi 10:00) · examen de Statistiques lundi 16 novembre (J-4) · devoir « étude de cas » pour vendredi 13 |
| À ne pas oublier | Facture Internet demain, 45 $ · Devoir : étude de cas, vendredi · Examen : Statistiques, lundi · Assurance auto, mardi, 62 $ |
| Finance (hors mission, pour les liens) | Budget 1 200 $, 788 $ dépensés, 412 $ restants, 21,68 $ par jour · objectif d'épargne « Voyage à Lisbonne » : 640 $ sur 1 500 $, juin 2027 |
| Voyage | Donc **Lisbonne, juin 2027**, budget 1 500 $ (le même voyage que l'objectif d'épargne de Finance). Dates proposées ici, à garder partout : du 12 au 19 juin 2027, soit J-212 le 12 novembre |
| Auto | Donc **« Assurance auto », mardi 17 novembre, 62 $** (la même échéance que dans « À ne pas oublier » et dans Finance) |
| Entreprise, Photos et citations | Aucun repère existant : le JS commun du sujet les fixe une fois, pour ses 7 planches |

Règles :
- Les données d'un sujet sont dans son JS commun, pas dans chaque planche. Les cinq directions montrent **les mêmes chiffres**, rangés autrement.
- Français du Canada : « 412 $ », « 21,68 $ », « 1 122 », « 14:00 », « 71,6 kg », « 49 % » ; repas Déjeuner, Dîner, Souper, Collation ; guillemets « ». `PL.n`, `PL.m`, `PL.pct`, `PL.u`, `PL.dur` écrivent ces formes.
- Un chiffre calculé doit être juste (un reste = objectif − mangé ; un total = la somme de ses lignes ; un pourcentage = sa fraction).
- Une valeur inconnue ne devient jamais un zéro : « — », « Rien noté », « Non disponible », un cadre en pointillés (`PL.empty`).
- Vrais exports de widgets : `<img data-w="NOM">` (liste fermée dans le guide Cristal, § 3). Captures réelles de la CI : `PL.pub + 'captures-ci-454/…'` (99 images, hors dépôt).
- Thème clair, `t-saphir`. Le mode sombre existe (`--query mode=dark`) mais ne se livre pas sans décision du PDG.

## 8. La table de fin « Rien n'est retiré »

```js
// dans <sujet>.js : la liste de l'audit (section 4), dans son ordre, avec ses numéros et ses titres
const FONCTIONS = [['F1', 'Choisir le jour affiché', 'G'], ['F11', 'Feuille de quantité', 'G+P'], ['F44', 'Historique : « Calories par jour »', 'P'], …];

// dans la planche : où est chaque fonction dans CETTE direction
PL.mapTable('map', FONCTIONS, {
  F1:  [1, 'Sélecteur de semaine, en tête.'],                 // sur l'écran 1
  F7:  [[1, 3], 'Bouton teinté ; « Ajouter un aliment ».'],   // sur les écrans 1 et 3
  F62: ['=', 'Notifications inchangées, réglées dans « Rappels ».'],   // gardée à sa place actuelle, non dessinée ici
});
```

- Accès : `'G'` gratuite, `'P'` Premium, `'G+P'` gratuite avec une part Premium (les « Mixte » des audits). Un 4e élément facultatif dit en quelques mots ce que fait la fonction : il sert à la table de la planche d'analyse (`PL.fnTable`).
- **Une fonction absente, sans numéro d'écran, ou « = » sans explication sort en rouge**, comptée en tête de table (« 3 non placées ») et dans le contrôle. Une clé qui n'est pas dans la liste, un numéro en double, un écran qui n'existe pas sur la planche : rouge aussi.
- `'='` n'est pas une échappatoire. Il sert à ce qui ne se dessine pas (notifications, widgets, liens profonds, retour automatique à aujourd'hui, mentions légales) ou à une page que la direction ne touche pas : dis laquelle.
- Le texte dit **où exactement** (« Ligne de la carte Repas », pas « Écran 1 »). 6 à 12 mots.
- Avant de livrer, relis la table à côté de la section 4 de l'audit : un numéro d'écran juste, c'est une fonction que l'on voit vraiment sur cet écran.

## 9. Marquer une nouveauté

Une nouveauté = tout ce qui n'est pas dans la section 4 de l'audit, et d'abord ce que la section 9 de l'audit liste (« ce que la mission cite et qui n'existe pas »). Elle se marque **trois fois** :

1. **Dans l'écran** : le jeton violet `PL.nw()` à côté du titre ou de la ligne (`{ nw: true }` sur `PL.card`, `PL.row`, `PL.kpi`, `PL.sect`, `PL.alert`, `PL.kv`, `PL.due`, `PL.prog`). Pour un bloc entier, le contour en pointillés violets se pose en plus (`PL.card(…, { nw: true })`, ou la classe `pl-newbox`).
2. **Dans la légende** : une ligne `tag n` qui dit ce que c'est et pourquoi c'est nouveau.
3. **Dans la case de texte** : « Nouveau, à développer (n) », la liste numérotée, avec l'écran.

Le contrôle refuse un écran qui a le jeton sans la ligne de légende, ou l'inverse. Peu de nouveautés par direction (Finance : 3 dans la direction conseillée). Une fonction existante déplacée ou redessinée n'est pas « Nouveau » : c'est « À adapter ».

## 10. Les pièces prêtes à l'emploi

Tout est décrit en tête de `planches.js`, avec les options de chaque pièce. L'essentiel :

| Besoin | Pièce | Composant de l'app |
|---|---|---|
| Poser un écran | `PL.mount('p1', page, ce qui flotte)` | |
| En-tête de mini-app | `PL.nv('Nutrition', bouton à droite)`, `PL.rbtn('plus', 'Ajouter')`, `PL.ttl('Dîner')` | barre de navigation, grand titre d'une page |
| Sélecteur de semaine | `PL.wsel({ sel: 3, marks: [0, 1, 2, 3] })` | `WeekSelector` |
| Sélecteur de jour, de mois | `PL.day()`, `PL.month()` | `DaySwitcher` |
| Figure du jour sur verre | `PL.hero({ lab, fig, unit, line })` ou `<article class="gl pl-hero split">` | `MiniHero` |
| Titre de section | `PL.sect('Repas', '1 078 kcal', 'Tout voir')` | `MiniSectionTitle` |
| Carte | `PL.card(contenu, { t, i, right, nw })` | `.miniCard()` |
| Tuile de chiffre | `PL.kpis([PL.kpi('Calories', '1 078', 'sur 2 200')], 3)`, `PL.strip([['658', 'kcal'], …])` | `MiniStat` |
| Ligne de liste | `PL.list([PL.row('fork', 'Mes repas', 'détail', { r: '3' })])` | `MiniRowsCard`, `MiniRow` |
| Ligne datée, progression, bandeau | `PL.due({…})`, `PL.prog({…})`, `PL.alert(…)` | |
| Anneau, jauge, barre | `PL.ring(.49, { b: '1 122', small: 'kcal<br>restantes' })`, `PL.meter(…)`, `PL.bar(.5)` | |
| Barres | `PL.weekBars([…], { goal, today })` (7 jours), `PL.bars({ g, c, yt, ref })` (groupées, période en cours hachurée) | |
| Courbe | `PL.line({ series, yt, xl, ref, tip })` | |
| Anneau en parts, barre empilée, calendrier du mois | `PL.donut(…)`, `PL.stack(…)`, `PL.heat({ vals })`, `PL.cal({ done })`, légende `PL.leg(…)` | |
| Grille de la semaine | `U.week({…})` de `cristal.js` | `WeekTimetable` |
| Bouton principal et autres | `PL.btn('Scanner', { i: 'scan' })` ; `k: 'T'` teinté, `'O'` contour, `'G'` verre | `MiniActionButton` |
| Action flottante | `PL.fab('Commencer', 'play')`, `PL.fab2(…)`, `PL.dock(…)` (3e argument de `PL.mount`) | `MiniFloatingAction` |
| Feuille | `PL.sheet(contenu, 'Titre', { left: 'Annuler', right: PL.sheetBtn('Enregistrer'), full })` (3e argument de `PL.mount`, `data-tab="none"`) | feuilles |
| Formulaire | `PL.field`, `PL.kvs([PL.kv(…)])`, `PL.sw`, `PL.stepper`, `PL.chips`, `PL.seg`, `PL.search`, `PL.quick` | |
| Barre d'onglets | posée par le script selon `data-tab` | barre d'onglets |
| Premium | `PL.prem()`, `PL.lock('3 mois')`, `{ prem: true }`, `PL.lockCard('L\'historique détaillé est dans Premium', '…')` | `PremiumBadge`, `PremiumLockCard` |
| « À remplir », état vide, note, « Mes paramètres » | `PL.toFill([…], '0 / 2')`, `PL.empty(…)`, `PL.foot(…)`, `PL.settings()` | `MiniAppToFillSection`, `EmptyStateView`, `MiniFootnote`, `MiniAppInfoSection` |
| Nouveau | `PL.nw()`, `{ nw: true }`, classe `pl-newbox` | |

Une pièce manque ? Écris-la dans le `<style>` et le script de ta planche, avec ton préfixe, sur les jetons du thème (`var(--primary)`, `var(--ink)`, `var(--ink2)`, `var(--panel)`, `var(--well)`, `var(--rule)`, `var(--track)`, `var(--c)`, `var(--r)`). Si elle sert à plusieurs planches du sujet, elle va dans le CSS et le JS communs du sujet. Ne redéfinis jamais une classe `pl-` ni une classe de Cristal.

Pour ce qui touche à la création de widgets (surtout Photos et citations) : les pièces C1 « Atelier » de Cristal (`.stage`, `.tools`, `.sizes`, `.thumbs`, `.dots`, `.wt`), la planche `../../2026-11-15-cristal/08-creer-atelier.html` et `GUIDE-CREATION.md`. Les réglages sont en trois chapitres : « Contenu », « Disposition », « Style ».

## 11. Les deux autres planches

**Analyse (`GABARIT-analyse.html`, numéro 0, `data-kind="analyse"`).** Quatre ou cinq captures réelles avec leurs pastilles rouges (`PL.shot`), le ruban de l'écran principal (`PL.ribbon`), les problèmes par famille avec les numéros de l'audit (section 8), la table des fonctions (`PL.fnTable`, même liste `FONCTIONS`), ce que la mission cite et qui n'existe pas (section 9 de l'audit), ce qui marche et qu'on garde. Une capture qui manque garde sa case : un cadre en pointillés « Capture à venir » la remplace. Jamais de fausse capture, jamais une maquette à la place d'une capture.

**Comparaison (`GABARIT-comparaison.html`, lettre C, `data-kind="comparaison"`).** À faire après les cinq directions, rendues avec `--phones` (leurs premiers écrans servent de vignettes).
- `PL.grid` : 5 directions × les 10 critères de la mission, déjà écrits dans `PL.CRITERES` (on ne les change pas, on ne les réordonne pas). Chaque case : une note entière sur 10 et une raison de 3 à 6 mots. Total sur 100. La meilleure note de chaque ligne est cerclée, le meilleur total est agrandi et marqué, la colonne conseillée est teintée. Si la direction conseillée n'a pas le meilleur total, la grille l'écrit : la recommandation doit dire pourquoi.
- « Rapidité d'accès » se compte : choisis deux gestes courants du sujet (`acces: 'Noter un yogourt · ouvrir l\'historique'`) et écris le nombre de touchers de chaque direction.
- `PL.cards` : pour chaque direction, 3 avantages (ce qu'elle fait bien, ce qu'elle améliore, ce qu'elle met en valeur) et 3 inconvénients (limites, informations moins accessibles, risque de surcharge, compromis), puis pour qui.
- `.pl-rec` : la recommandation. **Ne conseille pas l'hybride par habitude.** Les sept raisons demandées par la mission ont leur table ; le lien avec Mon quotidien aussi (même chiffre vedette, même nom, même icône, même couleur que la carte).
- `.pl-q` : 3 à 6 questions fermées pour le PDG, chacune avec le choix conseillé. Les écarts de l'audit qui demandent une décision (deux noms, deux couleurs) y vont.
- Les notes sont un jugement, pas une mesure : la planche le dit (c'est écrit sous la grille).

## 12. Nommage

- **Fichiers** : § 2. Titre de la page : `Ardane · <Sujet> — Direction N : Nom`.
- **Identifiants** : téléphones `p1` à `p9`, dans l'ordre ; table de fin `map` ; grille `grid` ; cartes `cards` ; captures `s1`… ; ruban `rib` ; table des fonctions `fn`.
- **Classes CSS d'une planche** : préfixe = clé du sujet + numéro de la planche (`nut1-`, `nut2-`, `nutc-` pour la comparaison, `nuta-` pour l'analyse). **Classes communes du sujet** : la clé seule (`nut-`). Jamais `pl-`, `fn-`, `x-`, `u-`, ni un nom nu (`.card`, `.title`).
- **JavaScript** : `FONCTIONS` pour la liste du sujet ; un seul objet de données par sujet, en capitales (`NUT`, `FIT`, `PLA`, `HAB`, `ETU`, `ENT`, `VOY`, `AUT`, `PHO`). Noms déjà pris, à ne pas redéfinir : `PL`, `PL_BASES`, `NBSP`, `Cristal`, `C`, `P`, `U`, `THEMES`, `CATS0`, `DAY`, `EVENTS`, `HABITS`, `TOP3`, `REMIND`, `CAL7`, `SPEND7`, `STEPS7`, `TODAY`, `WEEKDAYS`, `WEEKDATES`, `MOMENTS`, `KIT`, `Screens`.
- **Icône manquante** : `Object.assign(P, { nom: 'tracé SVG 24 × 24' })` dans le JS du sujet. Regarde d'abord `CATALOGUE.html` (133 icônes).

## 13. Rendu et contrôle (obligatoire, deux passes au moins)

Depuis le dossier du sujet :

```
cd C:/Users/Etudiant/Documents/GitHub/tessera/docs/design/2026-11-17-mini-apps/<dossier>
~/ardane-tools/venv/Scripts/python.exe -I ../base/render.py 01-nom.html --phones
~/ardane-tools/venv/Scripts/python.exe -I ../base/render.py 01-nom.html --query check
```

Sorties, dans `pub/rapports/design-2026-11-17-mini-apps/<dossier>/` (hors dépôt) :

| Fichier | À quoi il sert |
|---|---|
| `01-nom.png` | La planche entière, à livrer |
| `01-nom-contact.jpg` | La planche réduite à 1 600 de large : à regarder en premier |
| `ecrans/01-nom-NN.png` | Chaque téléphone découpé, dans l'ordre des écrans |
| `ecrans/vus/01-nom-NN.jpg` | Le même réduit à 500 de large : **c'est celui-là qu'on ouvre pour contrôler** |
| `01-nom-check.png` et `-check-contact.jpg` | La passe de contrôle : texte coupé entouré de rouge, panneau des remarques en bas |

- Un rendu prend une à deux minutes. Pas plus de deux rendus à la fois (chaque rendu ouvre plusieurs fois le navigateur).
- Autres passes utiles : `--query mode=dark` (mode sombre, pour voir, pas pour livrer) et `--query t=lavande` (une autre couleur de l'app).
- Le PDF d'un sujet se fait à la fin, par le Chef : `~/ardane-tools/venv/Scripts/python.exe -I ../../2026-11-15-cristal/make_pdf.py <sortie.pdf> 1800 <images…>`.
- « ATTENTION : la planche dépasse --maxh » : relancer avec `--maxh 12000`.
- **Regarde les images.** La planche-contact, puis **chaque** écran de `ecrans/vus/`. Cherche : un texte coupé ou sur deux lignes par accident, deux blocs qui se chevauchent, un bloc qui sort de son panneau, quelque chose d'important caché sous la barre d'onglets ou sous l'action flottante, un alignement faux, un contraste faible, un chiffre qui contredit un autre écran. Corrige, rends de nouveau.
- La passe `check` ajoute en bas de la planche le panneau **« Contrôle de la planche »**. Il doit dire « rien à signaler », ou ne garder que des remarques que tu assumes. Il vérifie : 6 à 9 écrans ; « La logique » en 4 colonnes ; chaque téléphone avec sa clé et son thème ; chaque légende avec titre, texte et étiquette ; jeton « Nouveau » et légende d'accord ; passages vers des écrans qui existent ; feuille trop haute ; graphique plus large que sa carte ; contenu caché sous l'écran ; texte coupé ; table de fin complète ; grille de notes complète ; image introuvable.

### Fausses alertes de « check »

- **Retirées toutes seules** par `PL.init` : les textes des graphiques SVG, et les rangées qui défilent sur le côté (`.chips`, `PL.quick`, tout bloc portant l'attribut `data-scroll`, `.tools`, `.thumbs`). Si une rangée de puces doit tenir en entier, utilise `PL.chips(…, { fit: true })` : elle reste contrôlée.
- **Remarque « N points de contenu sous le bas de l'écran »** : normale pour une longue liste voulue (opérations, exercices, historique). Pas normale si le bas contient autre chose : coupe en « suite ».
- **Un téléphone avec feuille** : la page derrière la feuille est contrôlée aussi. Une alerte dans cette page se corrige sur l'écran d'où elle vient.
- **Remarque « Vignette absente »** sur la comparaison : les directions n'ont pas encore été rendues avec `--phones`.
- **Remarque « capture réelle manquante »** sur l'analyse : attendue tant que la CI n'a pas refait les captures. Elle reste écrite sur la planche (cadre « Capture à venir »).
- Le contrôle **ne voit pas** : un chevauchement vertical, un bloc caché sous l'action flottante, un contraste faible, un libellé inexact, un chiffre faux, une fonction placée sur le mauvais écran. Seuls tes yeux et l'audit le voient.

## 14. Liste de contrôle finale (12 points)

1. **Périmètre** : je n'ai écrit que dans le dossier de mon sujet ; aucun fichier de l'app, de `base/` ni de Cristal n'a changé ; aucune commande git qui écrit.
2. **Cadre** : `--bw:1860px` ; `main.bd.t-saphir` avec `data-c` et `data-kind` ; les fichiers communs chargés dans l'ordre ; `PL.init()` en dernier.
3. **En-tête et logique** : numéro, pastille, titre « Direction N · Nom », badge ; « La logique » en 4 colonnes avec les priorités P1 à P3, une force et une limite.
4. **Écrans** : 6 à 9, dont l'écran principal, les sections et leurs accès, une vue de détail, une vue de gestion, une vue secondaire. La direction change vraiment l'organisation : ce n'est pas la même page recolorée.
5. **Téléphones** : 393 × 852, `phone app t-saphir`, la bonne clé, 13:20 (ou un autre moment, dit en légende), `data-tab` juste, `pl-past` si le futur est bloqué.
6. **Cristal** : une seule carte de verre dans la page, une seule action principale, une seule couleur d'action, panneaux pour le contenu, cibles de 44 points, jamais la couleur seule.
7. **Légendes et passages** : chaque écran a son titre, une ou deux phrases, ses étiquettes ; les flèches et les lignes « → Écran N » racontent un parcours qui existe.
8. **Nouveautés** : chacune a son jeton dans l'écran, sa ligne « Nouveau » en légende, sa place dans « Nouveau, à développer (n) ». Rien de la section 9 de l'audit n'est montré comme existant.
9. **Libellés et données** : les mots de l'app, recopiés de l'audit ; la journée du jeudi 12 novembre 2026 ; les mêmes chiffres que les autres planches du sujet ; les calculs justes ; français du Canada.
10. **Table de fin** : la liste complète du sujet, « 0 non placée », chaque « Inchangé » expliqué, relue à côté de la section 4 de l'audit. Gratuit / Premium inchangé et dit.
11. **Rendu regardé** : la planche-contact et **chaque** écran de `ecrans/vus/` ; rien ne déborde, rien d'important sous la barre d'onglets ; la passe `check` sans contour rouge et sans erreur.
12. **Rapport** : fichiers écrits (chemins complets), nombre d'écrans, nouveautés (liste), fonctions « Inchangé » (nombre), ce que j'ai vérifié sur l'image, ce qui reste incertain. Limites à redire : maquettes en Inter (SF Pro sur l'iPhone), grandes tailles de texte et mode sombre non dessinés, notes de jugement sans test avec des utilisateurs.
