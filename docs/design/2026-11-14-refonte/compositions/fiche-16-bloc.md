# 16 · Bloc : franc et assumé

**1. Nom et concept.** Le néo-brutalisme : contours noirs épais, ombres dures décalées, aplats vifs. Rien n'est flou, tout se touche du doigt. Chaque mini-app est une « fenêtre » à bandeau de couleur.

**2. Palette (HEX).** Crème `#FFF8E7` · blanc `#FFFFFF` · encre et contours `#111111` · secondaire `#4A4A4A` · piste des jauges `#EDE6D0`. Aplats : jaune `#FFD43B`, rose `#FF8FAB`, bleu `#74C0FC`, menthe `#7BE0AD`, orange `#FFA94D`, lilas `#B197FC` (lilas réservé au Top 3, visible seulement en pastille de la bande de l'écran E).

**3. Rôle des couleurs.** Noir = tout le texte, les contours, les graphiques et les cases cochées. Aplat = identité de la mini-app (bandeau ou cellule) : Nutrition orange, Fitness rose, Planning bleu, Habitudes menthe, Budget jaune, Top 3 lilas, Pas bleu. Jaune = aussi l'action du moment (« Commencer », onglet actif, autocollants). Blocs noirs : bouton principal, bloc dominant de l'écran E. Le texte sur aplat est toujours noir.

**4. Lettres.** Maquette : Inter 900 (titres, chiffres, bandeaux en capitales), Inter 500 à 800 (texte), Consolas 700 en capitales (étiquettes, date, autocollants). iOS : SF Pro Black / Heavy et Menlo.

**5. Composants.** Boutons : noir à texte blanc (ombre jaune), jaune à texte noir (action du moment), blanc à contour ; hauteur 44 pt, contour 2,5 pt, ombre 3 pt qui disparaît à l'appui (le bouton s'enfonce : décalage de 3 pt). Cartes : contour 2,5 pt, ombre dure 4 pt, rayon 10, bandeau coloré de 34 pt avec icône et titre. Filtres/pastilles : autocollants à bord noir, inclinés de 2 degrés, un seul par carte. Cases : carré noir coché (fait), carré en pointillés jaune (en cours), carré blanc (à faire) ; texte barré. Onglets : barre blanche à filet noir, onglet actif en bloc jaune à contour et ombre.

**6. Cartes, bordures, ombres, rayons, contrastes mesurés.** Rayon 10 (6 pour les petits blocs), contour 2,5 pt, une ombre dure `4px 4px 0 #111` par carte (6 pt rose pour le bloc dominant). Contrastes : noir sur crème 18,1:1 · noir sur blanc 18,9:1 · secondaire sur blanc 8,6:1 · noir sur jaune 12,9:1, orange 10,7:1, bleu 10,6:1, menthe 12,3:1, rose 9,5:1, lilas 7,6:1 · jaune sur noir 12,9:1 · rose sur noir 8,3:1 · barres passées (noir à 55 %) 4,2:1 sur blanc (graphique : 3:1 requis).

**7. Ambiance.** Directe, joueuse mais précise : on lit d'abord de gros chiffres noirs, la couleur sert à repérer, jamais à décorer.

**Forces.** Lisibilité maximale (noir sur aplat, très grosses cibles), identité immédiate, états visibles même en noir et blanc.
**Risques.** Beaucoup de traits épais : la densité des écrans C/D se tient de justesse, et l'ombre dure demande une forme sur mesure en SwiftUI (pas `.shadow`) ; le style est tranché et peut fatiguer sur de longues listes.
