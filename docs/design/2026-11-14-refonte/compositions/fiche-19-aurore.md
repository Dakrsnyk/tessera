# Fiche 19 · Aurore (2026-11-15)

**1. Nom et concept.** Aurore : la douceur du jour qui change. Un style tendre de bien-être : pastels, galets (rayon 30), et un « ciel » en tête d'écran qui dit le moment de la journée.

**2. Palette (HEX).**
- Fond `#FBF7FB` · surface `#FFFFFF` · encre aubergine `#2A2340` · secondaire `#625A7C` (ajusté, voir 6) · filet `#ECE4F2`.
- Principale lavande `#6B4FD8` (texte blanc) · texte d'action sur pastel ou fond clair `#4F37B5` (ajout).
- Pastels : pêche `#FFE1CF`, rose `#FFD6E0`, ciel `#D6EBFF`, menthe `#D3F2E3`, lilas `#E4DBFF`.
- Encres de catégorie : `#C2622A`, `#C2415E`, `#2F6FB0`, `#2E8760`, `#5B47B8`. État vide (coche, segment) `#8D84A6`.
- Ciel : matinée `#FFCDB2`, `#FFD6E0`, `#FBF7FB` ; journée `#B9DBFF`, `#D6EBFF`, `#FBF7FB` ; soirée `#A99BDB`, `#E4DBFF`, `#FBF7FB`.

**3. Rôles.** Lavande : actions et « Maintenant » seulement. Pastel : fond de l'icône ronde d'une mini-app et petits galets de chiffres. Encre de catégorie : icônes et graphiques. Le ciel est le seul dégradé de l'écran (jamais sur une carte).
Nutrition = pêche · Fitness = rose · Planning et Pas = ciel · Habitudes = menthe · Budget et Top 3 = lilas.

**4. Lettres.** Maquette : Segoe UI Variable, demi-gras (650) pour les titres, 700 pour les grands chiffres, pas de capitales. iOS : SF Pro Rounded (`.fontDesign(.rounded)`). Chiffres tabulaires.

**5. Composants.** Boutons en pilule de 46 pt, lavande pleine (ou pastel à texte `#4F37B5`) ; pastille de moment lavande ; puces pastel (« 2 repas ») ; icône de mini-app en disque pastel ; barres épaisses (9 pt) à bouts ronds ; segments de série en pilules vides à contour ; onglets : barre blanche à coins hauts arrondis, onglet actif = pastille lilas derrière l'icône (et libellé en `#4F37B5`).

**6. Cartes, ombres, contrastes.** Cartes blanches rayon 30 (34 pour « Maintenant », 38 pour la carte dominante), aucune bordure, ombre lilas très légère `0 8 22 rgba(107,79,216,.09)`. Mesures : encre sur fond 14,0 · secondaire sur blanc 6,4 (le `#6B6384` du brief, 5,6, tombait sous 4,5 sur lilas : remonté à `#625A7C`) · blanc sur lavande 5,6 · `#4F37B5` sur lilas 6,2 · encre sur le ciel le plus foncé (soirée) 5,9 · encre sur les pastels ≥ 11 · icônes sur pastel 3,3 à 5,2 · graphiques sur blanc 4,1 à 6,9 · contour d'état vide 3,5 · blocs du planning (30 % d'encre de type) ≥ 9. Zones tactiles ≥ 44 pt.

**7. Ambiance.** Matin de week-end, bien-être, thé et lumière rasante. Sur iOS 17 : `LinearGradient` pour le ciel (fixe par moment), `RoundedRectangle(cornerRadius:, style: .continuous)`, ombre `.shadow(color: .purple.opacity(0.09))`.

**Forces.** Se reconnaît au premier regard par le ciel, tendre sans perdre la densité, états toujours écrits.
**Risques.** Le ciel doit rester lisible sous le titre dans les trois moments (testé) ; les pastels pâles demandent des encres foncées pour les petits textes.
