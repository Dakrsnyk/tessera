# Fiche 13 · Sellier : le soin de l'artisan

**1. Nom et concept.** Sellier. L'univers de la maroquinerie : une toile claire, un cuir orangé, un brun profond. La couture (un pointillé à 5 points du bord) est le seul ornement ; « Maintenant » est une étiquette de bagage.

**2. Palette (HEX).** Toile `#F5F0E8` · surface `#FFFDF8` · encre chocolat `#2B1D14` · secondaire `#75614F` · filet `#D9CBB8` · couture `#CDBBA2` · orange sellier `#C24E12` · laiton `#A8843F` (filet seulement) · piste des graphiques `#E6DCCB`. Cuirs : Nutrition `#B5651D`, Fitness `#9E3B32`, Planning `#3F5E8C`, Habitudes `#5F7A3A`, Budget `#2F6F62`, Top 3 `#75614F`, Pas `#3B7480` (ajouté : le brief n'en donnait que cinq). Événements : cours bleu, travail `#6A4F8C`, rendez-vous `#8B3A62`, séance rouge cuir.

**3. Rôle des couleurs.** Orange : l'action (boutons, étiquette « Maintenant », liens, point de l'onglet actif). Encre : texte et titres. Laiton : un filet sous le titre et la couture du bloc brun. Cuirs : plaque de l'icône de chaque mini-app et ses graphiques ; jamais seuls pour dire un état.

**4. Lettres.** Maquette : Gill Sans MT en capitales espacées pour les étiquettes (iOS : Gill Sans), Baskerville Old Face pour titres et grands chiffres (iOS : Baskerville), Inter pour le texte et la date (iOS : SF Pro). Le « 1 » de Gill Sans ressemble à un « I » en capitales : les chiffres des étiquettes restent donc en Inter.

**5. Composants.** Bouton principal : orange, texte blanc en capitales Gill Sans, 44 points, rayon 10. Secondaire : contour encre 1,5 point. Pastille : contour couture, rayon 7. Étiquette de bagage : pan coupé et œillet, orange. Icône : plaque de cuir carrée, rayon 8. Listes : lignes séparées par une couture pointillée. Onglets : fond surface, capitales Gill Sans, point orange sous l'onglet actif. Pagination : points.

**6. Cartes, bordures, ombres, rayons.** Carte `#FFFDF8`, bordure 1 point `#D9CBB8`, couture pointillée 1,5 point `#CDBBA2` à 5 points du bord (rayon 6), rayon 10, aucune ombre. Bloc dominant : brun `#2B1D14`, couture laiton. Contrastes mesurés : encre sur toile 14,4:1 · secondaire sur toile 5,2:1 (sur surface 5,8:1) · blanc sur orange 4,8:1 · orange sur surface 4,7:1 · crème `#FFF8EC` sur brun 15,4:1 · `#E2D5C2` sur brun 11,3:1 · blanc sur cuirs 4,3 à 6,6:1. Graphiques et icônes : cuirs sur surface de 4,3 à 6,6:1 (≥ 3). Orange sur brun 3,4:1 (bouton, ≥ 3). Pistes et couture sont décoratives (1,3 et 1,8:1).

**7. Ambiance.** Un atelier : posé, chaud, précis. Les écrans se lisent comme une pièce de cuir piquée à la main.

**Forces.** Langage reconnaissable (couture, étiquette de bagage) qui ne sert qu'à lire ou agir ; chaud sans être sombre ; très différent de Maison malgré le serif.
**Risques.** Gill Sans et Baskerville ne sont pas des polices système modernes (disponibles dans iOS, mais le rendu SwiftUI de la couture demande un `strokeBorder` en pointillé par carte) ; le pointillé alourdit les grilles denses ; Baskerville n'a pas de gras, la hiérarchie vient de la taille.
