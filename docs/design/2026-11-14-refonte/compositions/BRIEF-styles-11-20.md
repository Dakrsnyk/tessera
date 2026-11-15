# Brief : dix nouveaux styles (11 à 20), montrés en accueils complets (2026-11-15)

Écrit par le Chef pour les agents designers. L'utilisateur a demandé « encore 10 autres styles ». Il a déjà dit qu'il ne veut plus d'écrans presque vides : chaque nouveau style est donc montré directement en **5 écrans d'accueil complets**, avec la même méthode et les mêmes données que les styles 1 à 10, pour que les 20 se comparent à contenu égal.

À lire avant, dans cet ordre : `BRIEF-compositions.md` (les 5 compositions, les règles, la planche, les interdits), `DONNEES.md` (ce que chaque carte a le droit de montrer et la journée d'exemple : **fait foi**), l'en-tête de `compo-base.css` et de `compo-base.js` (base commune, à inclure sans la modifier), puis `compo-01-saphir.html` (modèle de structure) et, pour voir comment un style s'écarte vraiment de Saphir, `compo-02-architecte.html` ou `compo-07-mono.html`. Recette de rendu : `../BRIEF.md` section 4.

## 1. Ce qui est nouveau par rapport aux styles 1 à 10
- **Il n'existe pas de planche précédente** pour ces styles : tu inventes leur langage (composants, formes, lettres) à partir de la fiche ci-dessous. Les jetons donnés sont un point de départ vérifié pour le contraste ; tu peux les ajuster si un contraste mesuré l'exige, en le notant.
- Les dix premiers styles sont : Saphir (clair, « Apple »), Architecte (plan fileté noir), Carbone (tableau de bord bleu nuit, cyan), Maison (ivoire, serif italique, bleu nuit), Gazette (journal), Stade (sport sombre, condensé penché), Mono (noir et blanc), Canopée (jardin, verts et terres), Orbite (violet sombre, anneaux), Nocturne (bleu nuit, champagne, serif). **Un nouveau style ne doit ressembler à aucun d'eux.**
- Polices : choisir des polices présentes sur la machine de rendu **et** fournies avec iOS (ou dont l'équivalent iOS est indiqué), pour ne rien avoir à acheter ni à embarquer. Disponibles ici : Inter (variable, `../Inter-opsz.woff2`), Segoe UI Variable, Bahnschrift, Gill Sans MT, Century Gothic, Rockwell (dont Extra Bold), Baskerville Old Face, Garamond, Perpetua, Palatino Linotype, Georgia, Constantia, Sitka, Franklin Gothic, Ink Free, Segoe Print, Consolas. (Yu Mincho n'est pas installé.)
- Pour chaque style, écrire aussi une **fiche en 7 points** dans `fiche-NN-nom.md` (40 lignes au plus, français simple) : 1 nom et concept ; 2 palette complète en HEX ; 3 rôle de chaque couleur ; 4 lettres (police de la maquette et police iOS) ; 5 composants (boutons, filtres, cartes, onglets) ; 6 cartes, bordures, ombres, rayons, avec les contrastes mesurés ; 7 ambiance ; puis « Forces » et « Risques » en une ligne chacun.

## 2. Règles (rappel de l'essentiel)
- 5 compositions par style : A Équilibrée (13:20), B Quotidien (19:05), C Éditoriale (08:10), D Compacte (13:20), E Premium (19:05). Même contenu et mêmes chiffres que Saphir. Chaque écran est rempli jusqu'à la barre d'onglets, montre au moins 4 des 5 mini-apps (A et D : les 5), et les 5 écrans sont franchement différents entre eux.
- Aucune donnée ou fonction hors de `DONNEES.md`. La légende (6e case) liste Existe / À adapter / À développer.
- Texte courant au moins 4,5:1 (au moins 12 points), étiquettes au moins 11 points, icônes et graphiques au moins 3:1, zones tactiles d'au moins 44 points, l'état jamais par la couleur seule.
- Sobre et exécuté avec soin. Pas de décor sans rôle. Chaque signature du style doit servir à lire ou à agir.
- Crédible en SwiftUI sur iOS 17.

## 3. Leçons de la première série (à appliquer)
- **Noms de classes** : la base utilise déjà `.now`, `.n`, `.k`, `.a`, `.tag`, `.sb`, `.tabbar`, `.ti`, `.hi`, `.edge`, `.cb-*`, `.ph-*`. Préfixe tes classes (par exemple `.x-…`) ou limite-les à `.scr`, sinon elles entrent en collision.
- **Dossier temporaire** : il est partagé par plusieurs agents. Travaille dans TON sous-dossier (nom donné dans ta consigne) et ne touche à aucun autre.
- **Edge sans interface** échoue parfois sans rien dire, ou laisse l'ancienne image : supprime ta propre image avant le rendu, attends que le fichier existe, relance si besoin. Donne un nom différent à chaque recadrage que tu regardes (l'outil Read garde en mémoire une image par chemin).
- `?check` et `?measure` aident mais ne suffisent pas : la vérification qui compte est de **regarder chaque téléphone recadré** (environ 800 px de large).
- Dans `U.week`, les libellés des blocs d'une heure sont serrés : règle la hauteur de la grille, l'interligne et la largeur du jour élargi (`fw`).
- La barre d'onglets ne doit couper aucune ligne de texte à mi-hauteur : cale la fin de l'écran sur un bord de carte ou entre deux lignes.
- Planche-contact JPG : 1 600 px de large au plus, **moins de 450 Ko** (baisse la qualité si besoin).

## 4. Les dix styles

### 11 · Outremer : la marque en plein écran
Tout l'écran est du bleu roi d'Ardane, celui du logo. On ne regarde plus une app à accent bleu : on est dans le bleu.
- Jetons : fond `#123A7A`, surface `#1B4A93`, surface creuse `#0E2F66`, encre `#FFFFFF`, secondaire `#B9CBEA`, filet `#2C5BA8`, principale turquoise `#2FD0E6` (texte `#0B2550` dessus). Catégories éclaircies : ambre `#FFC27A`, corail `#FF9C9C`, lilas `#C9B8FF`, vert `#9FE3A6`, menthe `#7FE0C8`.
- Lettres : Inter (SF Pro) 700, chiffres tabulaires.
- Signature : le dégradé du logo (`#17B3D0` vers `#1D4E9E`) n'apparaît qu'une fois par écran, sur l'élément « Maintenant » ; boutons en pilule blanche à texte bleu ; filets blancs à 12 % ; rayon 20 ; aucune ombre.
- À surveiller : ne pas ressembler à Nocturne ni à Carbone (ici le fond est un bleu franc et lumineux, pas un bleu nuit).

### 12 · Vitrail : la couleur en aplats
Chaque mini-app est une tuile de couleur pleine, posée bord à bord comme les pièces d'un vitrail. On reconnaît une mini-app à sa couleur avant de lire.
- Jetons : fond `#FAFAF7`, encre `#16181D`, secondaire sur fond clair `#5A6070`, principale = encre (bouton noir à texte blanc). Tuiles : Nutrition `#F6B25C`, Fitness `#F0706F`, Planning `#7FA6F8`, Habitudes `#8CCB6B`, Budget `#5CC7AE`, Top 3 `#D9DCE3`, Pas `#6FD3E0`. Sur une tuile, tout le texte est en encre `#16181D` (jamais de blanc ni de gris clair sur une couleur).
- Lettres : Century Gothic gras pour les titres et les chiffres (iOS : Avenir Next), Inter pour le texte.
- Signature : tuiles à rayon 26 séparées par 6 points de fond clair, sans bordure ni ombre ; les graphiques sont en encre sur la couleur (anneaux, barres) ; un seul bouton noir par écran.
- À surveiller : l'harmonie des couleurs entre elles (même clarté, même saturation) ; ne pas tomber dans le bariolé.

### 13 · Sellier : le soin de l'artisan
L'univers de la maroquinerie : une toile claire, un cuir orangé, un brun profond, et la couture comme seul ornement.
- Jetons : fond toile `#F5F0E8`, surface `#FFFDF8`, encre chocolat `#2B1D14`, secondaire `#75614F`, filet `#D9CBB8`, principale orange sellier `#C24E12` (texte blanc dessus), laiton `#A8843F` en filet seulement. Catégories en teintes de cuir : `#B5651D`, `#9E3B32`, `#3F5E8C`, `#5F7A3A`, `#2F6F62`.
- Lettres : Gill Sans MT en capitales espacées pour les étiquettes (iOS : Gill Sans), Baskerville Old Face pour les titres et les grands chiffres (iOS : Baskerville), Inter pour le texte courant.
- Signature : une « couture » (trait pointillé de 1,5 point, à 5 points du bord, à l'intérieur des cartes) ; « Maintenant » en étiquette de bagage ; rayon 10 ; aucune ombre ; onglet actif marqué par un point orange.
- À surveiller : ne pas ressembler à Maison (Maison est ivoire et bleu nuit, en serif italique, à rayon 2 ; Sellier est chaud, orange et brun, avec des capitales Gill Sans et la couture).

### 14 · Sumi : l'encre et le vide utile
Un minimalisme d'inspiration japonaise : papier washi, encre noire, un sceau vermillon pour la seule chose qui compte maintenant.
- Jetons : fond `#F4F1EA`, surface `#FBF9F4`, encre `#1C1B19`, secondaire `#6A665E`, filet `#D8D3C7`, principale = encre (bouton noir), accent vermillon `#C7372F` (texte blanc dessus), réservé au sceau « Maintenant » et à l'état en cours. Catégories en pigments naturels : indigo `#3B5B8A`, kaki `#C96B2C`, matcha `#6E8B3D`, prune `#8A4A6B`, pin `#2F6B5E`.
- Lettres : Garamond pour les titres et les grands chiffres (iOS : New York, ou Hiragino Mincho en japonais), Inter pour le texte.
- Signature : un filet vertical fin à gauche qui porte la date ; des filets horizontaux d'un demi-point à un point, pas de cartes pleines ; un sceau rond vermillon ; compositions asymétriques ; rayon 0 à 4.
- À surveiller : le brief interdit les écrans vides. Le calme vient de l'alignement et des filets, pas du vide : les écrans restent pleins. Ne pas ressembler à Gazette (pas de colonnes de journal, pas de gras) ni à Maison.

### 15 · Carnet : le journal à points
Le carnet de l'étudiant ou de la personne organisée : papier pointillé, stylo bleu, surligneurs.
- Jetons : fond papier `#F7F3E8` avec une trame de points `#CFC7B4` tous les 14 points (discrète), surface `#FFFDF6`, encre `#23211E`, stylo bleu `#1F3A8A` (principale, texte blanc dessus), secondaire `#5F5A50`, filet au crayon `#B9B2A2`. Surligneurs par catégorie, toujours derrière du texte encre : jaune `#FFE66D`, rose `#FFB3C1`, bleu `#AFD8F5`, vert `#B8E6B0`, orange `#FFC98A`.
- Lettres : Ink Free pour les titres et les étiquettes seulement (iOS : Bradley Hand ou Noteworthy), Inter pour le texte et **tous les chiffres** (lisibilité).
- Signature : cadres tracés à la main (bords légèrement irréguliers), cases à cocher de carnet, traits de surligneur derrière les titres, un onglet en ruban adhésif pour « Maintenant ».
- À surveiller : rester lisible et adulte, pas enfantin ; l'écriture manuscrite reste courte (titres, étiquettes), jamais en dessous de 14 points.

### 16 · Bloc : franc et assumé
Le néo-brutalisme : contours noirs épais, ombres dures décalées, aplats vifs. Rien n'est flou, tout se touche du doigt.
- Jetons : fond crème `#FFF8E7`, surface `#FFFFFF`, encre et contours `#111111` (2,5 points), ombre dure `4px 4px 0 #111111`, secondaire `#4A4A4A`. Aplats : jaune `#FFD43B`, rose `#FF8FAB`, bleu `#74C0FC`, menthe `#7BE0AD`, orange `#FFA94D`, lilas `#B197FC`. Principale : bouton noir à texte blanc, ou jaune à texte noir pour l'action du moment.
- Lettres : Inter 900 (SF Pro Black) pour les titres et les chiffres, Consolas pour les petites étiquettes (iOS : Menlo), Inter 500 pour le texte.
- Signature : cartes à contour épais et ombre dure ; étiquettes en « autocollants » inclinés de 2 degrés ; boutons qui semblent s'enfoncer ; rayon 10.
- À surveiller : le texte sur aplat reste noir ; ne pas surcharger (une ombre dure par carte, pas sur chaque élément).

### 17 · Cristal : le verre, avec mesure
L'esprit des interfaces Apple récentes : une couche de navigation en verre au-dessus d'un contenu net. Le verre sert à flotter, pas à décorer.
- Jetons : fond `#EEF3FA` avec deux grandes nappes de couleur floues et fixes (turquoise `#BFEAF2`, bleu `#C9D8FB`), panneaux de contenu blanc à 78 %, verre de navigation blanc à 55 % avec flou d'arrière-plan et liseré blanc à 70 %, encre `#0B1220`, secondaire `#4E5A6B`, principale `#245B8F`. Catégories : celles de Saphir.
- Lettres : Inter (SF Pro), titres 700.
- Signature : le verre n'est utilisé que pour ce qui flotte (barre du haut, barre d'onglets en capsule, carte « Maintenant », boutons groupés) ; le contenu reste sur des panneaux presque opaques ; rayon 26 ; un reflet d'un point en haut des panneaux de verre.
- À surveiller : contraste d'au moins 4,5:1 dans le pire cas (texte sur verre au-dessus de la nappe la plus foncée) ; pas de dégradés arc-en-ciel ; en SwiftUI iOS 17 : `Material`. Le dire dans la fiche.

### 18 · Affiche : la typographie suisse
Une affiche de l'école suisse : du blanc, du noir, un rouge signal, et de très grandes lettres alignées à gauche. La hiérarchie vient de la taille, pas des boîtes.
- Jetons : fond `#FFFFFF`, encre `#0A0A0A`, secondaire `#5C5C5C`, filet fort `#0A0A0A` (2 points), filet léger `#DADADA`, principale rouge `#E10600` (texte blanc dessus), réservée à l'action et à « maintenant ». Aucune couleur de catégorie : les mini-apps se distinguent par leur nom en grandes lettres et leur place dans la grille.
- Lettres : Inter 800 à 900 très serré, en minuscules, de 56 à 96 points pour les grands chiffres (iOS : SF Pro ou Helvetica Neue) ; Inter 500 pour le texte.
- Signature : grille asymétrique (une colonne étroite d'étiquettes, une large de contenu) ; chiffres qui débordent presque du cadre ; une barre rouge pour l'état en cours ; une étiquette verticale le long du bord gauche ; rayon 0 ; aucune carte.
- À surveiller : ne pas ressembler à Mono (pas de pilules, pas de surfaces grises, pas de bloc noir) ni à Architecte (pas de quadrillage de cellules).

### 19 · Aurore : la douceur du jour qui change
Un style tendre, de bien-être : des pastels, des formes en galet, et un ciel en tête d'écran qui change avec le moment de la journée.
- Jetons : fond `#FBF7FB`, surface `#FFFFFF`, encre aubergine `#2A2340`, secondaire `#6B6384`, filet `#ECE4F2`, principale lavande profonde `#6B4FD8` (texte blanc dessus). Fonds pastel par catégorie : pêche `#FFE1CF`, rose `#FFD6E0`, lilas `#E4DBFF`, menthe `#D3F2E3`, ciel `#D6EBFF` ; encre de catégorie pour les icônes et les graphiques : `#C2622A`, `#C2415E`, `#5B47B8`, `#2E8760`, `#2F6FB0`.
- Lettres : Segoe UI Variable demi-gras (iOS : SF Pro Rounded), pas de capitales.
- Signature : le seul dégradé de l'écran est le « ciel » de l'en-tête, qui suit le titre du moment (matinée : pêche vers rose ; journée : ciel vers blanc ; soirée : lilas vers aubergine clair) ; cartes en galet à rayon 30 ; ombre très légère teintée de lilas.
- À surveiller : ne pas ressembler à Canopée (Canopée est verte et terreuse ; Aurore est lilas, pêche et ciel) ; garder la densité.

### 20 · Braise : la chaleur du soir
Un sombre chaud, à l'opposé des sombres bleutés : charbon brun, braise orange, lettres à empattements carrés.
- Jetons : fond `#151210`, surface `#1F1A17`, surface haute `#2A2320`, encre `#F6EEE6`, secondaire `#B3A699`, filet `#3A302B`, principale braise `#FF6A2B` (texte `#1A0E08` dessus), ambre `#FFB454`. Catégories réchauffées : `#FFB454`, `#FF7A6B`, `#9DB7FF`, `#B7D97A`, `#6FD6B8`.
- Lettres : Rockwell gras pour les titres et les grands chiffres (iOS : Rockwell), Inter pour le texte.
- Signature : barres de progression épaisses à bouts ronds ; un liseré clair d'un point en haut des cartes (comme une arête éclairée) ; l'orange réservé à l'action et à l'état en cours ; rayon 18 ; aucun halo.
- À surveiller : ne pas ressembler à Stade (pas de condensé penché, pas de cyan) ni à Carbone (pas de bleu, pas de chasse fixe).

## 5. Fichiers à livrer, par style
- `compo-NN-nom.html` (inclut la base, ne contient que le propre du style) et `fiche-NN-nom.md`, dans ce dossier.
- `pub/rapports/design-2026-11-14/compositions/compo-NN-nom.png` (échelle 2, 2800 × 4020) et `compo-NN-nom-contact.jpg`.
- Noms : `11-outremer`, `12-vitrail`, `13-sellier`, `14-sumi`, `15-carnet`, `16-bloc`, `17-cristal`, `18-affiche`, `19-aurore`, `20-braise`.
