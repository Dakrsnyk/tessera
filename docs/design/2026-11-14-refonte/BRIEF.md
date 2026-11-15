# Brief commun : refonte exploratoire de l'Accueil et de Créer (2026-11-14)

Écrit par le Chef pour les agents designers. À lire en entier avant toute tâche.

## 1. Ce que veut l'utilisateur (résumé fidèle de son brief)
- Explorer de nouvelles organisations et de nouveaux designs pour **l'Accueil** et **l'onglet Créer**. Travailler comme un directeur artistique, un designer UX/UI senior et un spécialiste d'apps mobiles premium réunis.
- Pas un simple changement de couleurs : repenser comment on découvre Ardane, comment on comprend ce qu'on peut faire, comment on atteint une fonction en peu de gestes.
- Références de niveau, **jamais à copier** : la simplicité et la hiérarchie d'Apple, l'impact et le dynamisme de Nike, la modularité et la lisibilité d'Adidas, le raffinement et le soin du détail de Louis Vuitton. Aucun logo, nom ou motif de ces marques dans une maquette.
- Éviter l'effet « généré par IA » : accumulation de dégradés, verre partout, ombres lourdes, piles de cartes arrondies, décor sans utilité. **Chaque élément a une raison d'être.** Sobre et parfaitement exécuté plutôt que spectaculaire.
- Le thème **Saphir** actuel reste la référence de l'identité. On peut le faire évoluer, pas le remplacer d'office.
- Ne sacrifier aucune fonction utile ; n'inventer aucune fonction pour embellir. Toute nouveauté est marquée « À développer ».
- Livrables : de vraies maquettes à regarder (dimensions réelles d'iPhone, crédibles en SwiftUI), et pour chaque proposition un texte en 7 points. **L'app n'est pas modifiée.**
- Promesse à transmettre : « ARDANE — Your whole life. One place. » (gérer les aspects de sa vie depuis un seul endroit).

## 2. Ce qu'Ardane est aujourd'hui (à respecter ; vérifier dans le code en cas de doute)
- App iOS 17, SwiftUI. Code : `App/` (écrans dans `App/Screens/` : Home, Spaces, Editor, Explore, MyWidgets, MiniApps, Profile…), `Shared/` (modèle, rendu des widgets dans `Shared/Render/`).
- **4 onglets** : Accueil, Créer, Store, Mes widgets. Bouton de profil en haut à droite de l'Accueil.
- **Accueil = « Mon Quotidien »** : une pastille de date, un titre selon le moment (« Ta soirée »), puis des cartes par mini-app choisie (Nutrition, Séance en cours, Habitudes, « À ne pas oublier », Planning, Budget, Top 3…). Une carte existe en demi-largeur ou en pleine largeur, peut avoir plusieurs vues (points de pagination), ouvre sa mini-app au toucher. Appui long, « Organiser… » : déplacer et redimensionner. Un « + » en bas ajoute des mini-apps.
- **Mini-apps** : Nutrition (calories, macros, scanner), Fitness (séance, programme, bibliothèque d'exercices, activité en direct), Planning et Études, Finances/Budget, Entreprise, Voyage, Auto, Habitudes, Photos.
- **Créer** : titre, filtres en pastilles (Tout, Écran verrouillé, Santé, Argent…), puis une longue liste de grandes cartes par espace (12 espaces) avec aperçus. On entre dans un **constructeur** : taille (Petit, Moyen, Grand), choix d'un ou plusieurs widgets (les widgets créés ensemble partagent leur style), option « widgets interactifs seulement », puis « Personnaliser » ouvre le **Studio** (16 thèmes, 14 palettes, fonds, bordures, graphiques, densité, polices, « Mes styles »). Le widget est enregistré dans « Mes widgets ».
- **Contrainte iOS** : l'app ne peut pas poser un widget sur l'écran d'accueil. L'utilisateur l'ajoute lui-même (appui long sur l'écran d'accueil, « + », Ardane), puis choisit son widget enregistré. Toute maquette de fin de parcours doit l'expliquer honnêtement.
- **Store** : écrans d'accueil complets, packs, collections, fonds d'écran. Gratuit : 3 widgets enregistrés, thème Saphir seul ; le reste est Premium (« Avec Premium »).
- **Identité** : Saphir `#245B8F` (clair) et `#68B5F5` (sombre) ; logo : « A » blanc sur dégradé turquoise `#17B3D0` vers bleu roi `#1D4E9E` ; couleurs d'espace : Nutrition orange, Fitness rouge, Habitudes vert, Budget vert, Planning bleu ; calories orange, protéines rouge, glucides jaune, lipides bleu. Ton : tutoiement, sobre, concret.
- Captures réelles pour référence : `C:/Users/Etudiant/ardane-tools/film/public/kit2026/en/spaces.png` (Créer), `en/creator-nutrition.png` (constructeur), `en/studio-*.png` (Studio), `fr/home-*.png` (écrans d'accueil iOS composés, 1206 × 2622).

## 3. Règles des maquettes
- Textes de l'interface en **français**, données d'exemple cohérentes entre les écrans d'une même planche. Bandeau discret « Maquette d'idée · données d'exemple » sur chaque planche.
- iPhone : **393 × 852 points** (cadre, îlot, barre d'état, indicateur d'accueil, barre d'onglets). Rien ne doit casser à 375 points de large.
- Widgets montrés = **vrais exports** de l'app : `C:/Users/Etudiant/ardane-tools/film/public/kit2026/fr/<widget>-<s|m|l>-<style>.png` (exemples : `calories-s-light`, `macros-m-dark`, `calories-s-paper`, `weekView-m-editorial`, `habitStreak-s-light`, `budgetLeft-s-light`, `todaysWorkout-m-light`, `priorities-s-paper` ; lister le dossier pour trouver le style qui s'accorde). Icône de l'app : `C:/Users/Etudiant/ardane-tools/film/public/store/ardane-icon.png`.
- Icônes : un seul jeu au trait (voir la table `P` du fichier de base), même graisse dans toute une planche.
- Chaque fonction montrée est étiquetée dans le texte : « Existe », « À adapter » ou « À développer ».
- Accessibilité : texte courant au moins 4,5:1, zones tactiles d'au moins 44 points, l'état ne repose jamais sur la couleur seule.

## 4. Recette technique (éprouvée le 2026-11-14)
- Fichier de base à réutiliser (cadre de téléphone, icônes, données `CATS`, une section par planche choisie par `?d=`) : `docs/design/2026-11-14-directions-accueil-creer.html`.
- Polices disponibles sans réseau : Inter variable (`C:/Users/Etudiant/ardane-tools/film/public/fonts/Inter-opsz.woff2`, à copier à côté du HTML), Segoe UI, Bahnschrift (variable, `font-stretch: 75%` pour le condensé), Sitka Display / Heading / Text (serif variable, italique), Constantia, Georgia, Consolas, Impact. Aucune ressource du réseau.
- Rendu : Edge sans interface, un dossier de profil **différent à chaque rendu**, puis attendre que le fichier existe :
  `timeout 90 "/c/Program Files (x86)/Microsoft/Edge/Application/msedge.exe" --headless --disable-gpu --hide-scrollbars --no-first-run --allow-file-access-from-files --user-data-dir="<dossier Windows unique>" --force-device-scale-factor=2 --window-size=<largeur>,<hauteur> --screenshot="<chemin Windows .png>" "file:///C:/.../fichier.html?d=<planche>"`
- Vérifier chaque planche : en faire une copie réduite avec PIL (`~/ardane-tools/venv/Scripts/python.exe -I`, chemins `C:/…`), la regarder avec l'outil Read, corriger texte coupé, chevauchement, alignement, contraste. Au moins une passe de correction.
- Sources HTML et textes : `docs/design/2026-11-14-refonte/`. Images PNG : `pub/rapports/design-2026-11-14/` (hors dépôt). Fournir aussi **une planche-contact** JPG (1 600 px de large au plus, moins de 400 Ko) pour la relecture du Chef.
- Interdits : modifier `App/`, `Shared/`, `Widgets/`, `UITests/`, `scripts/` ; commit ou push ; installer quoi que ce soit ; écrire hors des deux dossiers ci-dessus (et du dossier temporaire de rendu).

## 5. Concepts de structure (direction du Chef, à dessiner dans un Saphir évolué, clair)
Accueil :
- **H1 « Maintenant »** (quotidien) : en-tête date et moment ; une carte « Maintenant » qui montre la seule chose utile tout de suite (séance en cours, prochain cours, repas à noter, facture proche) ; une rangée « Mes espaces » d'icônes avec la valeur du jour, un toucher ouvre la mini-app ; puis les cartes de Mon Quotidien existantes. Risque faible, tout est conservé.
- **H2 « Mosaïque »** (modulaire) : l'accueil est une grille de tuiles qui ont **les formes des widgets** (petit, moyen, grand) et le même rendu. On comprend le produit en regardant l'accueil. Toucher : mini-app. Appui long : « Organiser » et « Mettre ce widget sur mon écran d'accueil ». Limite : moins riche que les cartes actuelles (boutons, vues multiples).
- **H3 « La Une »** (éditorial) : une grande « une » typographique qui change selon le moment de la journée, puis un sommaire des espaces (une ligne par espace, avec son chiffre du jour), puis une invitation à personnaliser (Créer, Store). Peu de cartes, beaucoup de hiérarchie. Limite : moins dense.

Créer :
- **C1 « Atelier »** (studio, aperçu d'abord) : on arrive devant un grand aperçu vivant du widget, posé sur un socle neutre ; dessous, une rangée d'outils (Contenu, Taille, Thème, Couleurs, Fond, Police) et un panneau bas pour l'outil choisi. « Changer de widget » ouvre un sélecteur par espace avec recherche. Option « Voir sur mon écran » : le widget en situation parmi des icônes.
- **C2 « Trois gestes »** (guidé) : trois décisions, une par écran, avec l'aperçu toujours visible : « Que veux-tu suivre ? », « Quel format ? » (silhouettes aux vraies proportions, écran verrouillé compris), « Quel style ? ». Un raccourci « Aller au Studio » pour les habitués.
- **C3 « Galerie »** (bibliothèque) : on part d'un modèle : « Reprendre », « Pour toi », modèles par espace, ensembles assortis. Deux actions par modèle : « Utiliser » et « Personnaliser ». Limite : frontière à clarifier avec l'onglet Store.
- Fin de parcours commune : « Enregistré dans Mes widgets », puis l'explication en 3 étapes pour l'ajouter à l'écran d'accueil (contrainte iOS).

## 6. Dix directions artistiques (direction du Chef ; même contenu, mais formes, lettres et composants propres à chaque style)
Chaque style garde la même architecture d'information (en-tête, « Maintenant », accès aux espaces, résumés du jour, barre d'onglets ; Créer : titre, recherche, suggestions de vrais widgets, espaces) mais choisit **ses propres formes** : la rangée d'espaces peut devenir des affiches, un index, des cellules de grille.

| N° | Nom | Univers | Fond / surface / encre / secondaire / filet | Principale, accents | Lettres | Formes et signature |
|---|---|---|---|---|---|---|
| 1 | Saphir | approche « Apple », référence évoluée | `#F4F6FA` `#FFFFFF` `#0B1220` `#6B7686` `#E3E8F0` | `#245B8F`, dégradé `#17B3D0`→`#1D4E9E` réservé à la marque | Inter, titres 34 gras serrés | rayon 22, ombres très légères, barre d'onglets flottante |
| 2 | Architecte | minimalisme architectural | `#F2F1EE` `#FFFFFF` `#111111` `#7A7A76` `#111111` | `#245B8F` seule | Inter, chiffres fins (300), étiquettes en capitales espacées | rayon 0 à 4, aucune ombre, grille de cellules séparées par des filets d'un point, comme un plan |
| 3 | Carbone | élégance technologique | `#0B0F17` `#131A26` `#E8EEF8` `#8A97AB` `#223046` | `#4FD3E8`, `#68B5F5` | Inter + chiffres à chasse fixe (Consolas) | rayon 14, bordures intérieures d'un point, aucun halo, précision d'instrument de bord |
| 4 | Maison | luxe contemporain | `#F6F1E9` `#FBF8F2` `#1A1714` `#8A8178` `#D6CCBD` | `#1F3A5F`, or pâle `#B08D57` avec parcimonie | Sitka Display (italique pour les titres) + petites capitales | rayon 2, filets fins, aucune ombre, couleur d'espace réduite à un point |
| 5 | Gazette | design éditorial | `#FAFAF7` `#FFFFFF` `#0E0E0E` `#5F5F5A` `#0E0E0E` | couleur d'accompagnement unique `#1D4E9E` | titres serif gras (Sitka Heading), texte sans serif, numéros de rubrique | colonnes, filets, pas de cartes : des rubriques ; liens soulignés |
| 6 | Stade | esthétique sportive | `#0A0A0B` `#151517` `#FFFFFF` `#8E8E94` `#26262A` | `#17B3D0`, couleurs d'espace saturées | Bahnschrift condensé, capitales, italique penché | rayon 6 à 8, chiffres géants, lisière de couleur, action en pleine largeur |
| 7 | Mono | minimalisme monochrome | `#FFFFFF` `#F2F2F2` `#000000` `#8C8C8C` `#D9D9D9` | noir ; couleur seulement pour un état | Inter 500 et 800, très grands chiffres noirs | boutons en pilule, blocs noirs inversés, espaces distingués par l'icône et un numéro |
| 8 | Canopée | naturel et organique | `#F3F1E7` `#FBFAF3` `#22301F` `#6E7B66` `#DADFCB` | forêt `#2F5D3A`, mousse `#7FA33A`, terre cuite `#C4673A`, eau `#3D7A8C` | sans serif ronde et humaine (Segoe UI, graisses moyennes) | rayon 28, formes douces, icônes au trait rond et épais, ombres chaudes très légères |
| 9 | Orbite | futurisme maîtrisé | `#0D0B1A` `#17142B` `#F1EEFF` `#9A94C4` `#2B2750` | violet `#7C5CFF`, cyan `#3FE0D0` | capitales larges et espacées, chiffres fins | rayon 16, contours fins en dégradé, anneaux et traits de mesure, jamais de néon envahissant |
| 10 | Nocturne | sophistication du soir | `#0F1B2D` `#16263D` `#F3EEE4` `#9FB0C6` `#2A3C57` | champagne `#D8B982`, saphir clair `#68B5F5` | titres serif (Sitka) sur fond nuit, texte sans serif | rayon 14, filets champagne, surfaces mates |

Chaque style doit pouvoir vivre comme thème d'une vraie app SwiftUI (jetons : couleurs, polices système ou embarquées, rayons, épaisseurs).
