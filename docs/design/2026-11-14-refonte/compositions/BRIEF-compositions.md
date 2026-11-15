# Brief : compositions d'accueil complètes pour les 10 styles (2026-11-14, complément)

Écrit par le Chef pour les agents designers. À lire en entier, avec `../BRIEF.md` (règles générales, recette de rendu) et `../00-existant.md` (inventaire). En cas d'écart, `DONNEES.md` (ce dossier) fait foi sur ce que les cartes affichent.

## 1. Ce que demande l'utilisateur (résumé fidèle)
- Les planches précédentes montraient des écrans trop vides : une carte, un widget. Il veut voir **la richesse d'Ardane** : des écrans d'accueil complets, vivants, réalistes, comme sur le téléphone d'un vrai utilisateur.
- **Plusieurs mini-apps visibles en même temps sur un même écran** : Nutrition (calories, protéines, glucides, lipides, repas), Fitness (séance du jour, progression, prochaine séance), Finance (dépenses du mois, budget restant), Planning (prochains événements, organisation de la journée), Habitudes (suivi et objectifs du jour). Pas cinq écrans qui montrent chacun une seule chose : des compositions où tout cohabite.
- Pour **chacun des 10 styles**, **5 compositions** de l'écran d'accueil d'Ardane (onglet Accueil, dans l'app) :
  - **A · Équilibrée** : les 5 mini-apps, à poids presque égal.
  - **B · Quotidien** : l'essentiel du moment d'abord (ce qu'il faut faire maintenant), puis le reste.
  - **C · Éditoriale** : plus visuelle, typographique, de grands chiffres ou une phrase, de grands graphiques.
  - **D · Compacte** : dense, pour tout consulter en un coup d'œil.
  - **E · Premium** : hiérarchie très marquée, un élément dominant, des secondaires, du souffle, des finitions soignées.

## 2. Règles propres à ce complément
- **Jamais d'écran presque vide.** Chaque composition montre **au moins 4 des 5 mini-apps** citées ; A et D montrent **les 5**. L'écran est rempli jusqu'à la barre d'onglets : la dernière carte peut être coupée par la barre (c'est un écran qui défile), jamais un grand vide.
- **Rien d'inventé.** Chaque carte ne montre que des données listées dans `DONNEES.md`. Une donnée absente de cette liste ne se dessine pas. Les nouveautés de structure déjà admises (« Maintenant », rangée de mini-apps, sommaire, phrase du jour) restent étiquetées « À adapter » ou « À développer » dans la légende.
- **Mêmes données partout** (`DONNEES.md`) : même personne, même jeudi, trois moments. Les 10 styles se comparent ainsi à contenu égal.
- **Chaque style parle sa propre langue.** Une composition n'est pas la planche Saphir recolorée : elle reprend les formes, les lettres et les composants du style, tels qu'ils sont déjà dessinés dans `../styles-01-05.html` ou `../styles-06-10.html` (cellules filetées d'Architecte, jauges de Carbone, carnet de Maison, colonnes et brèves de Gazette, couloirs de Stade, cellules numérotées de Mono, galets de Canopée, anneaux et règles d'Orbite, médaillons et menu de Nocturne). Reprendre les jetons et les corrections de contraste de ces fichiers.
- **Crédible en SwiftUI** : grille de l'accueil à 2 colonnes (carte en demi-largeur ou en pleine largeur), marges de 16 à 20 points, zones tactiles d'au moins 44 points, texte courant au moins 4,5:1, l'état jamais par la couleur seule. Pas de défilement horizontal sur l'accueil.
- Éviter l'effet « généré par IA » (voir `../BRIEF.md`) : pas de dégradés partout, pas de verre, pas d'ombres lourdes, pas de décor sans rôle. La densité vient du contenu, pas d'ornements.
- Barre d'onglets : Accueil (actif), Créer, Store, Mes widgets. En-tête : date en texte à gauche, avatar « M » à droite, « MON QUOTIDIEN », titre du moment.

## 3. Planche à livrer, par style
- **Une planche de 1400 points de large**, grille de 3 colonnes sur 2 rangées : les 5 téléphones (A, B, C en haut ; D, E en bas) et, dans la 6e case, une **légende** : le nom du style, une ligne par composition (à quoi elle sert, ce qui la distingue), et la liste « Existe / À adapter / À développer » des éléments montrés. Bandeau discret « Maquette d'idée · données d'exemple ».
- Sous chaque téléphone : la lettre, le nom de la composition, le moment (« Jeudi 12 novembre · 13 h 20 »).
- Téléphone : 393 × 852 points, cadre, îlot, barre d'état (l'heure de la barre d'état = l'heure du moment), indicateur d'accueil.
- Rendu : Edge sans interface, `--force-device-scale-factor=2`, fenêtre de 1400 points de large et de la hauteur de la planche (voir la recette dans `../BRIEF.md`).
- Fichiers : source `docs/design/2026-11-14-refonte/compositions/compo-NN-nom.html` (un fichier par style) ; image `pub/rapports/design-2026-11-14/compositions/compo-NN-nom.png` ; une planche-contact JPG par agent pour la relecture du Chef (1 600 px de large au plus, moins de 450 Ko).
- Vérification obligatoire : regarder chaque planche réduite, **puis chaque téléphone recadré à taille lisible** ; corriger texte coupé, chevauchement, débordement sous la barre d'onglets non voulu, alignement, contraste. Au moins deux passes.

## 4. Interdits
Modifier `App/`, `Shared/`, `Widgets/`, `UITests/`, `scripts/` ; commit ou push ; installer quoi que ce soit ; toucher aux fichiers d'un autre agent ; écrire hors de `docs/design/2026-11-14-refonte/compositions/`, de `pub/rapports/design-2026-11-14/compositions/` et du dossier temporaire de rendu. Aucune ressource du réseau.
