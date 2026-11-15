# Fiche 14 · Sumi : l'encre et le vide utile

**1. Nom et concept.** Sumi. Un minimalisme d'inspiration japonaise : papier washi, encre noire, et un sceau vermillon pour la seule chose qui compte maintenant. Le calme vient de l'alignement et des filets, pas du vide : les écrans restent pleins.

**2. Palette (HEX).** Papier `#F4F1EA` · surface `#FBF9F4` · encre `#1C1B19` · secondaire `#66625A` (le brief donnait `#6A665E` ; assombri pour viser 5,4:1) · filet `#D8D3C7` · filet vertical `#9C978B` · piste `#E1DCCF` · vermillon `#C7372F`. Pigments : kaki `#C96B2C` (Nutrition), prune `#8A4A6B` (Fitness), indigo `#3B5B8A` (Planning), matcha `#6E8B3D` (Habitudes), pin `#2F6B5E` (Budget), eau `#4F7C86` (Pas, ajouté), gris encre (Top 3). Macros : prune, ocre `#9A7B1C`, indigo. Événements : cours indigo, travail pin, rendez-vous kaki, séance prune.

**3. Rôle des couleurs.** Encre : texte, titres, boutons, filets forts. Vermillon : uniquement le sceau « Maintenant », le petit sceau « Maintenant » des cartes, le trait « en cours » (segment de série, ligne de l'heure). Pigments : icônes au trait et graphiques, jamais des fonds. Aucun pigment ne porte seul un état.

**4. Lettres.** Maquette : Garamond (titres, grands chiffres, heures) ; iOS : New York, ou Hiragino Mincho en japonais. Inter (iOS : SF Pro) pour le texte, les boutons et la date. Pas de gras dans les titres ; la hiérarchie vient de la taille.

**5. Composants.** Bouton principal : noir, texte blanc, rayon 2, 44 points. Secondaire : contour encre de 1 point. Liens : soulignés d'un point. Sceau : disque vermillon de 66 à 84 points, double cercle fin. Listes : lignes séparées par un filet. Onglets : sur surface, filet encre au-dessus, petit trait épais encre sur l'onglet actif, étiquette en gras. Filet vertical à gauche, avec la date écrite verticalement. Cases : anneaux fins, pleins avec coche une fois faits.

**6. Cartes, bordures, ombres, rayons.** Pas de cartes pleines : des sections entre filets (1 point encre pour les coupures fortes, 1 point `#D8D3C7` pour les lignes), colonnes séparées par un filet vertical. Rayon 2, aucune ombre. Contrastes mesurés : encre sur papier 15,3:1 · secondaire sur papier 5,4:1 (sur surface 5,8:1) · blanc sur vermillon 5,2:1 · vermillon sur papier 4,6:1 · blanc sur encre 17,2:1. Icônes et graphiques sur papier : prune 5,7 · indigo 6,1 · pin 5,5 · eau 4,1 · ocre 3,6 · matcha 3,4 · kaki 3,3 (tous ≥ 3). Filet vertical 2,6:1, filets et pistes décoratifs (1,2 à 1,3:1).

**7. Ambiance.** Une page de carnet japonais : alignée à gauche, silencieuse, avec un unique coup de sceau rouge là où l'attention doit aller.

**Forces.** Hiérarchie très claire (le sceau est le seul rouge) ; très différent de Gazette (pas de colonnes ni de gras) ; léger à dessiner en SwiftUI (filets, texte, un cercle).
**Risques.** Filets fins moins lisibles en plein soleil ; la colonne de gauche (48 points) réduit la largeur utile à environ 325 points ; Garamond fin demande les polices New York / Hiragino en vraie taille pour rester lisible.
