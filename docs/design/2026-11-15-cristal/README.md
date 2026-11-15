# Ardane en Cristal : phase 1, la vision complète (2026-11-15)

Choix de l'utilisateur le 2026-11-15 : **Cristal « Équilibrée »** (style n° 17 de l'exploration) pour l'accueil et toute l'app, **C1 « Atelier »** pour l'onglet Créer. Cette phase ne contient que des maquettes : l'app n'est pas modifiée. La phase 2 (codage et TestFlight) ne commence qu'après son accord explicite.

Retour de l'utilisateur le 2026-11-15 : tout lui convient sauf le Store. Il veut y garder le fonctionnement et l'affichage actuels et n'adapter que le style (lettres, fond). La planche 11 remplace donc les deux écrans du Store de la planche 9.

## Les planches
Sources HTML dans ce dossier, images dans `pub/rapports/design-2026-11-15-cristal/` (hors dépôt).

| N° | Fichier | Contenu | Écrans |
|---|---|---|---|
| 0 | `00-apercu.html` | aperçu envoyé avant le rendu complet | 6 |
| 1 | `01-declinaisons.html` | le même accueil dans les 10 déclinaisons | 10 |
| 2 | `02-profils.html` | un accueil par usage : équilibre, sport, productivité, finance, nutrition, études, minimaliste | 7 |
| 3 | `03-nutrition.html` | mini-app Nutrition | 7 |
| 4 | `04-fitness.html` | mini-app Fitness | 7 |
| 5 | `05-finances.html` | mini-app Finances | 7 |
| 6 | `06-planning.html` | mini-app Planning, avec Études | 7 |
| 7 | `07-habitudes.html` | page Habitudes | 7 |
| 8 | `08-creer-atelier.html` | Créer « Atelier » : le parcours complet | 12 |
| 9 | `09-autres-pages.html` | Mes widgets, Premium, Profil, mode Organiser | 6 |
| 10 | `10-palettes.html` | les 10 palettes complètes et les règles graphiques | — |
| 11 | `11-store.html` | le Store : mise en page actuelle, habillage Cristal ; captures de l'app en comparaison | 9 |
| 12 | `12-sombre.html` | le mode sombre : Saphir clair et sombre côte à côte, Créer en sombre, les 10 déclinaisons en sombre, règles et codes HEX | 15 |

Autres fichiers : `GUIDE.md` (règles du système et recette de rendu), `palettes.md` (tous les codes HEX), `inventaire/` (ce que l'app affiche aujourd'hui, relevé dans le code : fait foi), `cristal.css` et `cristal.js` (base commune), `render.py` et `make_pdf.py` (rendu), `store_crops.py` (découpe les vignettes du Store dans les captures de l'app, vers `pub/rapports/design-2026-11-15-cristal/store-src/`).

Toute planche se rend aussi en sombre avec `--query mode=dark` (classe `.dk`, jetons de `tokensDark` dans `cristal.js`).

Accord de l'utilisateur pour la phase 2 le 2026-11-15, avec trois consignes : dessiner le mode sombre avant de coder (planche 12), fond du compte gratuit = celui de Cristal « Équilibrée » (Saphir), ne rien dessiner ni développer qui n'existe pas dans l'app.

## Le système en cinq lignes
1. Fond clair avec deux nappes de couleur floues.
2. Le contenu est posé sur des panneaux presque opaques ; le verre est réservé à ce qui flotte (barre de la date, boutons ronds, sélecteur de semaine, barre d'onglets) et à une seule carte par écran : celle du moment.
3. Une seule couleur d'action par écran. Les couleurs des mini-apps ne servent qu'aux icônes et aux graphiques.
4. Dans une mini-app, une nappe de sa couleur éclaire le haut de la page et la couleur d'action devient la sienne.
5. Un état ne repose jamais sur la couleur seule.

## Les 10 déclinaisons
- Saphir reste la déclinaison gratuite. Les autres suivent la « Couleur de l'app » Premium, qui existe déjà.
- Six déclinaisons correspondent à une teinte actuelle de l'app : Lavande (Améthyste), Rose poudré (Rose), Sauge (Pistache), Océan (Aqua), Pêche (Ambre), Forêt (Jade).
- Trois sont des teintes neutres nouvelles, donc à développer : Sable, Graphite, Monochrome.
- Les palettes sont calculées à partir de la couleur principale par une règle unique (`cristal.js`, fonction `tokens`). Les cinq autres teintes actuelles de l'app (Cobalt, Bleu glacier, Olive, Rubis, Orchidée) peuvent donc recevoir leur palette Cristal sans dessin supplémentaire.

## Ce qui est nouveau, et son étiquette
**À adapter** (la donnée ou la fonction existe, pas à cet endroit ou pas sous cette forme)
- Accueil : la carte du moment en verre ; les compositions par profil (l'app sait déjà réordonner et redimensionner ses cartes).
- Accueil, profils Finance et Études : « Dépensé ce mois », solde d'un compte, objectif d'épargne, liste des prochains événements, raccourci « Focus · 25 min ».
- Mini-apps : la bande de couleur saturée devient une nappe douce ; la figure du jour passe dans une carte de verre ; les blocs deviennent des panneaux.
- Planning : une carte « Prochain événement » en tête (Planning n'a pas de chiffre en vedette aujourd'hui).
- Habitudes : le mot « Faite » ou « À faire » devant la série ; « 3 sur 5 faites aujourd'hui » sous le titre.
- Fitness : « Encore 2 séances » sous la tuile Séances.
- Créer : arrivée directe dans le Studio avec un widget proposé ; « Taille » devient le premier outil ; le constructeur actuel passe dans la feuille « Changer de widget » ; « Combiner » (2 widgets en moyen, jusqu'à 4 en grand) se règle dans Taille ; le guide d'ajout s'affiche après l'enregistrement.
- Profil : chaque couleur de l'app montre un mini-aperçu au lieu d'un rond.
- Store : habillage seul. La mise en page d'`ExploreView` ne change pas (huit allées, en-têtes colorés, cartes aux mêmes tailles) ; seuls changent le fond, les lettres, la recherche (verre), les puces et la carte « Style de la semaine » (panneau), la barre d'onglets, et la couleur d'action de « Tout voir », « Obtenir » et du badge « interactif ».

**À développer**
- Créer : l'aperçu « Sur mon écran » (le widget parmi des icônes, à l'échelle).
- Trois teintes neutres : Sable, Graphite, Monochrome.
- Fitness : l'aperçu flouté sous la carte Premium de Progression.
- Les matières Cristal en SwiftUI (verre, panneau, nappes), avec le repli quand « Réduire la transparence » est activé.

**Cité par l'utilisateur, absent de l'app, donc non dessiné**
- Suivi chiffré de l'hydratation : la mini-app Eau et son widget ont été retirés le 2026-10-15. Seule l'habitude « Boire 2 L d'eau » (une coche) existe.
- Récupération sportive, série de jours d'entraînement, fréquence cardiaque.
- Objectifs financiers autres que l'épargne, placements, connexion bancaire.
- Page de détail d'une habitude : toucher une habitude ouvre son éditeur.

## Décisions à prendre par l'utilisateur
1. **Les couleurs à livrer** : Saphir seule d'abord, ou Saphir et les teintes Premium actuelles ; ajouter ou non Sable, Graphite, Monochrome.
2. **Créer** : garder la composition à plusieurs widgets dans « Taille » (recommandé) ; montrer le guide d'ajout après chaque enregistrement ou seulement les premières fois ; développer ou non « Sur mon écran ».
3. **Créer** : où vont « Photos et citations » et l'entrée « écran verrouillé », aujourd'hui dans la liste des espaces (proposition : dans la feuille « Changer de widget »).
4. **Planning** : la carte « Prochain événement ».
5. **Mode sombre** : dessiné le 2026-11-15 à la demande de l'utilisateur (planche 12). Règles : fond = la teinte à 5,5 % de clarté, panneaux à 11,5 %, verre fumé, couleur d'action claire (celle de l'app en sombre) avec texte sombre sur les boutons pleins, widgets inchangés.

## Recommandation
- **Couleurs** : Saphir gratuite ; les 11 teintes Premium actuelles habillées par la même règle ; ajouter Sable et Graphite comme nouveautés Premium ; garder Monochrome en réserve.
- **Accueil** : la composition « Équilibrée » par défaut. Les profils ne demandent pas d'écran nouveau : l'app classe déjà les cartes selon l'heure et les intérêts, et le mode Organiser existe.
- **Créer** : C1 complet, avec le constructeur dans la feuille « Changer de widget » et le guide d'ajout après chaque enregistrement tant que le widget n'a jamais été posé.
- **Ordre de codage proposé pour la phase 2** : (0) dessiner le mode sombre ; (1) les fondations (nappes, panneau, verre, barre d'onglets) et l'accueil ; (2) le cadre commun des mini-apps, qui habille les cinq d'un coup ; (3) Créer « Atelier » ; (4) Mes widgets, Premium, Profil, et l'habillage du Store ; (5) accessibilité (Réduire la transparence, grandes tailles de texte) et teintes nouvelles. Une version de test interne à chaque étape.

## Limites
- Maquettes rendues sur ordinateur avec la police Inter ; sur iPhone, SF Pro change un peu les largeurs.
- Les très grandes tailles de texte ne sont pas dessinées. En sombre, les vignettes des packs du Store restent celles des captures claires.
- Plusieurs vignettes de la planche Créer sont des exports de remplacement (thèmes, widgets Nutrition sans export) ; c'est indiqué sous les écrans.
- Les prix de la page Premium sont des exemples : les vrais viennent de l'App Store.
- Planche 11 : les vignettes viennent des captures de l'app du 31 octobre, prises avec Premium débloqué (donc sans badge ni cadenas Premium) ; la carte de saison est une capture entière, avec la police de l'app.
- Les chiffres ajoutés à la journée d'exemple (opérations, aliments, séries par habitude) sont inventés pour la maquette et cohérents entre eux.
