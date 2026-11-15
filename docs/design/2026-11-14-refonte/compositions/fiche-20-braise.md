# Fiche 20 · Braise (2026-11-15)

**1. Nom et concept.** Braise : la chaleur du soir. Un sombre chaud (charbon brun) à l'opposé des sombres bleutés, lettres à empattements carrés, grosses barres de progression à bouts ronds.

**2. Palette (HEX).**
- Fond `#151210` · surface `#1F1A17` · surface haute `#2A2320` · encre `#F6EEE6` · secondaire `#B3A699` · filet `#3A302B`.
- Principale braise `#FF6A2B` (texte `#1A0E08` dessus) · ambre `#FFB454` (liens et chiffres de la phrase du jour).
- Catégories : Nutrition `#FFB454`, Fitness `#FF7A6B`, Planning et Pas `#9DB7FF`, Habitudes `#B7D97A`, Budget `#6FD6B8`, Top 3 `#B3A699`. Événements : cours `#9DB7FF`, travail `#C3A8FF`, rendez-vous `#F2A0D0`, séance `#FF7A6B`.
- Ajouts : état vide (coche, segment, contour de bouton) `#8A7E73` et `#857A70` ; liseré de carte `rgba(255,236,220,.13)`.

**3. Rôles.** Braise : actions (« Commencer », « Série faite »), pastille « Maintenant », barre de série en cours, heure actuelle du planning, jour du jour, barre du jour dans les graphiques, repère de l'onglet actif. Ambre : liens. Couleurs de catégorie : icônes et barres de leur mini-app. Rien d'autre n'est orange.

**4. Lettres.** Maquette : Rockwell gras (titres, grands chiffres, titres de sections, heures de liste), Inter (tout le reste, y compris les petits chiffres). Contrôle fait : Rockwell reste net à 15 points, mais n'est pas utilisé sous 15. iOS : Rockwell (`Font.custom("Rockwell-Bold", size:)`, livrée avec iOS) et SF Pro.

**5. Composants.** Boutons en pilule de 46 pt (braise pleine, ou contour `#857A70` pour « Scanner ») ; barres de 8, 12 ou 16 pt à bouts ronds (« vide » en `#3A302B`) ; série d'une séance en 4 segments épais, les vides cernés ; pastilles de repas ; lignes de registre (icône, titre, valeur, barre) entre filets ; onglets : barre pleine, onglet actif = libellé clair et trait braise sur le bord haut.

**6. Cartes, ombres, contrastes.** Cartes rayon 18, aucune ombre, aucun halo ; liseré clair d'un point en haut (comme une arête éclairée) ; carte dominante en surface haute, rayon 22. Mesures : encre 13,5 à 16,3 · secondaire 6,5 à 7,8 · `#1A0E08` sur braise 6,6 · braise sur surface 6,0 · ambre 9,8 · catégories 6,8 à 10,9 · coche et segment vides 3,9 à 4,4 · contour de bouton 4,3 · encre sur blocs du planning 6,3 à 7,4. Zones tactiles ≥ 44 pt. Aucun jeton du brief changé en couleur ; seul `--ev-fill` du planning est relevé à 38 % pour lire les blocs sur fond sombre.

**7. Ambiance.** Salon éclairé à la bougie, braise qui couve. Sur iOS 17 : couleurs d'actif nommées, `Capsule()` pour les barres, `overlay` d'un trait de 1 pt en haut des cartes (`UnevenRoundedRectangle` ou `strokeBorder` en dégradé), thème sombre forcé ou suivi du système.

**Forces.** Chaud, lisible, reconnaissable aux barres épaisses et aux Rockwell ; l'orange rare donne tout de suite l'action.
**Risques.** Rockwell est lourd : à garder pour les titres et les chiffres ; sur les très petits blocs du planning, le texte reste serré.
