# Cristal dans le code SwiftUI : règles communes (2026-11-15)

À lire avant de toucher un écran pour la refonte Cristal. Les planches de ce dossier sont la référence visuelle ; ce guide dit comment les traduire dans l'app sans rien casser.

## Ce qui existe déjà (ne pas refaire)
- `Shared/Theme/CristalPalette.swift` : `CristalPalette.of(style.id)` donne les jetons de la couleur de l'app, clair et sombre (`bgColor`, `panelSolidColor`, `tintColor`, `tint2Color`, `wellColor`, `well2Color`, `dotColor`, `ruleColor`, `okColor`, `radius`…), et traduit une couleur de catégorie de l'app : `.category(hex)` pour un graphique, une pastille ou une icône, `.strong(hex)` pour du TEXTE dans cette couleur.
- `App/Components/Cristal.swift` : `cristalPanel(radius:)` (panneau presque opaque, liseré clair, ombre douce : le contenu) et `cristalGlass(in:)` (verre : seulement ce qui flotte, une carte « Maintenant » par écran, sélecteur de semaine, boutons ronds), `CristalBackdrop`.
- `App/Components/CristalScreen.swift` : `cristalScreen()` (fond à deux nappes d'un écran entier) et `styledList()` (listes et formulaires).
- Au centre : `.card()`, `miniCard()`, `miniTile()` sont des panneaux ; `.screenFill`, `.cardFill`, `.onAccent` lisent la palette ; `.tint` / `Color.accentColor` = couleur d'action Cristal (dans une mini-app : la couleur forte de la mini-app, posée par `MiniAppScaffold`).
- La couleur de l'app se lit avec `@Environment(\.appStyle) private var style`.

## Règles
1. **Fonds** : un écran entier = `cristalScreen()` ou `styledList()`. Plus de `Color(.systemGroupedBackground)`, `Color(.secondarySystemBackground)` ni de gris ou blanc codé en dur comme fond d'écran.
2. **Cartes** : tout bloc de contenu = panneau (`.card()`, `miniCard()` ou `cristalPanel(radius:)` au rayon d'origine). Une carte posée sur un voile sombre (tutoriel) ou servant de fond opaque derrière un contenu qui défile reste opaque (`.cardFill`).
3. **Verre** : rare. Seulement ce qui flotte au-dessus du contenu. Jamais pour un bloc de texte long.
4. **Couleurs de catégorie** (`colorHex`, `accentHex`, `MiniStyle.alertHex` / `goodHex` / `stepsHex`, `NutritionColors.*`, couleurs d'habitude, d'événement, de budget) : jamais `Color(hex:)` brut pour du chrome ou un graphique ; passer par `CristalPalette.of(style.id).category(hex)` (ou `.strong(hex)` pour du texte). Les HEX des modèles ne changent JAMAIS (les widgets les lisent).
5. **Boutons** : action principale = capsule pleine `Color.accentColor` + texte `.onAccent` (44 pt au moins ; `.borderedProminent` convient) ; action secondaire = fond `tintColor` + texte `Color.accentColor` ; liens = `Color.accentColor`. Une seule couleur d'action par écran.
6. **Choix** (segments, puces, tailles, vignettes, pastilles de couleur) : l'élément choisi a un anneau, un fond ou une coche EN PLUS de la couleur ; jamais la couleur seule. `FilterChip` existe déjà (choisie pleine, non choisie en panneau).
7. **Pastilles d'icône** : rondes, fond = couleur de catégorie traduite à 13 % (clair) / 20 % (sombre), symbole dans cette couleur.
8. **Titres** : titre d'écran grand et gras ; titre de section `.headline` (17 pt gras) ; petits libellés en capitales `.caption.weight(.bold)` + secondaire ; chiffres `.monospacedDigit()`.
9. **Ce qui ne change pas** : rendu des widgets (`Shared/Render/`, `WidgetPreview`, `DesignBackground`), Live Activities, badge et cadenas Premium en or (`premiumFill` / `premiumInk`), fonds d'écran et miniatures d'écrans, photos, aperçus « écran verrouillé » sur fond de nuit, cartes qui imitent un objet réel (carte bancaire, ticket).

## Interdits
- Aucune logique, aucun geste, aucune route, aucun texte, aucun ordre ni aucune taille de bloc ne change dans un simple habillage. Une fonction absente des planches n'est JAMAIS supprimée.
- Identifiants d'accessibilité, libellés, traits et cibles du tutoriel (`tutorialTarget`) gardés : compter avant et après chaque fichier.
- `python3 scripts/check_swift.py` doit finir par OK (ordre des labels d'init, `Button` dont le label a `.foregroundStyle(.primary/.secondary)` → `buttonStyle` obligatoire ou `Color.primary` / `Color.secondary`).
- Aucun nouveau texte visible sans `tr()` et traduction dans les 6 langues (pipeline de `CLAUDE.md`).
