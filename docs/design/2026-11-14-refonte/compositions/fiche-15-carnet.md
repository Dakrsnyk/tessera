# 15 · Carnet : le journal à points

**1. Nom et concept.** Le carnet de la personne organisée : papier pointillé, stylo bleu, surligneurs. Les cadres sont tracés à la main (bords un peu irréguliers, un second trait crayon décalé), les tâches se cochent comme sur du papier.

**2. Palette (HEX).** Papier `#F7F3E8` (points `#CFC7B4`, un tous les 14 pt) · fiche `#FFFDF6` · encre `#23211E` · stylo bleu `#1F3A8A` · secondaire `#5F5A50` · crayon `#B9B2A2` · piste des jauges `#E4DDC9`. Surligneurs : jaune `#FFE66D`, rose `#FFB3C1`, bleu `#AFD8F5`, vert `#B8E6B0`, orange `#FFC98A`. Planche : fond `#E8E4D8`.

**3. Rôle des couleurs.** Stylo bleu = l'action (boutons), les graphiques (anneaux, barres, courbe, jauges), les coches, le jour en cours. Encre = tout le texte. Surligneurs = identité de catégorie, toujours derrière une icône ou du texte en encre : Nutrition orange, Fitness rose, Planning bleu, Habitudes vert, Budget et Top 3 jaune, Pas bleu. Types d'événement : cours bleu, travail orange, rendez-vous rose, séance vert.

**4. Lettres.** Maquette : Ink Free pour les titres, étiquettes et liens courts (15 pt au minimum), Inter pour le texte et **tous les chiffres**. iOS : Bradley Hand (ou Noteworthy) pour le manuscrit, SF Pro pour le reste. Un trait de contour de 0,45 pt épaissit l'écriture pour la lisibilité (en SwiftUI : `.fontWeight(.medium)` n'agit pas sur Bradley Hand, prévoir un test).

**5. Composants.** Boutons : plein bleu à texte blanc, ou contour encre ; coins irréguliers, 44 pt de haut. Cartes : fond fiche, trait encre de 1,6 pt, double trait crayon. Titre de carte : écriture manuscrite surlignée dans la couleur de la catégorie. Cases à cocher : carré de 24 pt, coche bleue, texte barré quand c'est fait ; la série en cours est une case en pointillés bleus. « Maintenant » : ruban adhésif jaune, légèrement incliné, bords dentelés. Habitudes : petites cases cochées. Onglets : fiche blanche, l'actif en bleu avec le mot surligné en jaune. Listes : lignes séparées par des pointillés.

**6. Cartes, bordures, rayons, contrastes mesurés.** Rayons 8 à 13 pt, irréguliers ; aucune ombre ; trait encre 1,6 pt. Contrastes : encre sur fiche 15,8:1 · secondaire sur fiche 6,7:1 (sur papier 6,2:1) · bleu sur fiche 10,2:1 · blanc sur bleu 10,3:1 · `#D6DEF5` sur bleu 7,7:1 · encre sur surligneurs de 9,5 à 12,8:1 · barres passées 3,6:1 (graphique, 3:1 requis). Le secondaire sur l'orange tombe à 4,6:1 : on y met l'encre.

**7. Ambiance.** Studieuse et chaleureuse, mais adulte : le manuscrit ne sert que pour les titres, les chiffres restent nets.

**Forces.** Identité immédiate, très lisible (peu de couleurs d'action), cases à cocher naturelles pour le Top 3.
**Risques.** Ink Free n'existe pas sur iOS (équivalent Bradley Hand à tester) ; les doubles traits irréguliers demandent une forme dessinée sur mesure en SwiftUI ; trop de surligneurs deviendrait enfantin.
