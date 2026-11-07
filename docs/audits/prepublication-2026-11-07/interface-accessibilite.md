# Audit UX/UI et accessibilité (mission 24.U) — 2026-11-07

Audit sans modification du code. Méthode : recherche statique dans `App/**` et `Shared/Theme/**` (scripts de balayage, relus à la main sur les cas cités), calcul des rapports de contraste WCAG, 4 captures réelles anglaises (`ci-report:adkit-en`, `screens/`). Aucun rendu iPhone SE ni Dynamic Type n'existe dans les captures : ces points sont déduits du code et marqués « à confirmer en capture ». Aucun skill de design n'était exposé : travail fait avec les HIG.

## Synthèse par gravité

- Bloquant : 0
- Majeur : 4 (U-01 à U-04)
- Mineur : 7 (U-05 à U-11)
- Amélioration : 4 (U-12 à U-15)

## Majeur

### U-01 — Textes de rangées teintés à l'accent au lieu d'être noirs/gris (contraste)
- Preuve : capture `app-finances-transactions.png` : « Lunch », « Groceries », les montants et les sous-titres sont verts (jade, gris-vert pâle pour « Restaurants », environ 2,5:1) alors que le code demande `.foregroundStyle(.primary)` / `.secondary` (`FinancesPages.swift:126-128`, `expenseRow` 176-198). Cause : `.primary` en forme abrégée est le niveau hiérarchique du style de premier plan hérité ; dans un `Button` au style par défaut ce style est la teinte, donc `.primary` devient l'accent et `.secondary` l'accent atténué. `Color.primary` n'a pas ce défaut.
- Endroits (heuristique : `Button` sans `buttonStyle`, étiquette utilisant `.foregroundStyle(.primary|.secondary)`) : 13 : `MoneyView.swift:68`, `KindOptionsSection.swift:323`, `DailySection.swift:1389`, `MiniAppsRow.swift:235`, `BusinessApp.swift:476`, `BusinessPages.swift:59,95`, `CarPages.swift:146,211`, `FinancesPages.swift:156,492`, `ExerciseLibraryViews.swift:102`, `ProfileView.swift:450`. Certains sont en `List` (même effet) ; à confirmer en capture pour chacun.
- Correction : sur ces boutons ajouter `.buttonStyle(.pressable)` (déjà le style maison, sans teinte) ; sinon remplacer par `Color.primary` / `Color.secondary`. Correction globale : règle dans `check_swift.py` (Button + `.foregroundStyle(.primary|.secondary)` sans `buttonStyle`).

### U-02 — Texte blanc sur les couleurs de mini-apps claires (< 3:1)
- Preuve : `MiniApp.swift:380` (`MiniActionButton`) met `Color.white` sur `colorHex`. Rapports : Nutrition F08A24 = 2,51:1 (capture `app-nutrition-s03.png`, « Add a food » blanc sur orange), Voyage 12A4B5 = 3,0:1, Photos D9608B = 3,5:1, Finances 2F8F7A = 3,94:1, Fitness E5484D = 3,91:1 (le texte `.headline` semi-gras 17 pt ne bénéficie du seuil 3:1 que s'il est gras). Seuls Planning 3366FF (4,68) et Business 8C6CFF (3,68) sont proches.
- Même défaut ailleurs : `ProfileView` Premium, boutons « Terminé » colorés, chips (à relever par grep `foregroundStyle(.white)` sur fond `Color(hex:)`, environ 580 couleurs codées en dur dans `App/`).
- Correction : fonction commune `Color.readableInk(on: hex)` (texte noir 0.85 si luminance > 0,4, sinon blanc ; il existe déjà `ColorMath.luminance` et `inkOnDarkAccent` dans `AppStyle`) utilisée par `MiniActionButton` et tous les boutons « prominent ». Alternative : assombrir Nutrition à C46A10 (4,5:1 avec blanc).

### U-03 — Zones tactiles de moins de 44 pt sur des boutons
- Preuves (Button sans zone étendue) : `FitnessSession.swift:330,339` (− / + des séries et poids, 36×36, **sans accessibilityLabel**, écran le plus utilisé pendant l'effort) ; `MiniApp.swift:480` (retour à aujourd'hui, 32×36) ; `FitnessApp.swift:256` (36×30, menu ellipsis) ; `DailySection.swift:868` (28×24, +/− d'eau, de séries), `:1237,1258` (28×28) ; `DailyLayoutEditor.swift:146` (32) ; `StoreMagazine.swift:206,665` (32) ; `ExerciseLibraryViews.swift:55` (36) ; `BusinessApp.swift:363,436`, `FinancesApp.swift:555`, `NutritionApp.swift:360`, `MiniApp.swift:282` (36). Au total 67 cadres ≤ 39 pt dans `App/` ; la moitié sont décoratifs (icônes de rangée, pastilles), l'autre moitié sont des boutons.
- Pas de problème pour `ColorDot` (min 44, `EditorView.swift:825`) ni pour `HabitsView.swift:187` (46).
- Correction globale : modificateur `.tapTarget()` = `.frame(minWidth: 44, minHeight: 44).contentShape(Rectangle())` (ou `.contentShape(Rectangle().inset(by: -8))`) appliqué aux boutons ci-dessus ; la taille visuelle ne change pas.

### U-04 — Boutons d'icône sans libellé VoiceOver
- Preuve (balayage des `Button` dont l'étiquette n'est qu'une `Image`, sans `accessibilityLabel`) : 6 cas : `FitnessSession.swift:329` (moins) et `:338` (plus) ; `PlanningPages.swift:124` (case à cocher de tâche : lit seulement « bouton » ; seul un identifiant UI existe) ; `ProductivitySpace.swift:240` ; `StudentSpace.swift:80` ; `HabitsView.swift:187` (choix du symbole : 18 symboles muets, VoiceOver lit « bouton » ou le nom SF). Les cases à cocher rendues avec `checkmark.circle` (`DailySection.swift:1187`, `TasksView.swift:68`) contiennent un `Text` donc sont lues, mais sans l'état coché (voir U-05).
- Correction : `.accessibilityLabel(tr("Diminuer les répétitions"))` etc. ; pour les cases `.accessibilityValue(isDone ? tr("Fait") : tr("À faire"))` ou `.accessibilityAddTraits(isDone ? .isSelected : [])`. Correction globale : composant `CheckCircleButton(isDone:, label:, action:)` réutilisé par les 5 sites (tâches Planning, Productivité, Études, Accueil, Content/Tasks), qui apporte aussi la zone de 44 pt.

## Mineur

### U-05 — État « fait / à faire » non lu sur les cases à cocher
Voir U-04 : `PlanningPages.swift:124`, `ProductivitySpace.swift:240`, `StudentSpace.swift:80`, `DailySection.swift:1187`, `TasksView.swift:68`. Correction : trait `.isSelected` ou valeur. 5 endroits, regroupé dans le composant de U-04.

### U-06 — Graphiques et jauges sans description
- Preuve : 22 `Chart` dans les mini-apps ; 6 sans aucun `accessibility…` dans leur bloc : `CarPages.swift:29`, `FinancesPages.swift:584` (valeur nette), `FitnessPages.swift:421`, `NutritionPages.swift:559` (calories de la semaine), `PlanningPages.swift:463`, `StudiesPages.swift:768`. Les 16 autres en ont. 21 `ProgressView(value:)` sans libellé (ex. `CarApp.swift:401`, `FinancesApp.swift:613,637`, `StudiesApp.swift:225`, `StudiesPages.swift:689,730`, `NutritionSpace.swift:30`, `FitnessSession.swift:112`) : VoiceOver lit un pourcentage sans nom, sauf si un parent est un `accessibilityElement(children: .combine)` (93 usages dans l'app : bon signe, à vérifier un à un).
- Correction : `.accessibilityLabel(tr("Valeur nette"))` + `.accessibilityValue(résumé)` sur les 6 `Chart` ; pour les jauges `ProgressView(value:) { Text(nom) }.accessibilityValue(…)` ou `.accessibilityLabel`. `MacroGauge` (NutritionApp) à confirmer.

### U-07 — Contraste du texte secondaire des widgets par défaut
- Preuve (`Theme.swift`) : thème « Minimal » (le défaut) : `8A8A8E` sur blanc = 3,44:1 ; « Clair » `7C7D82` sur `F5F5F2` = 3,76:1 ; « Retro » 3,72 ; « Paper » 3,93 ; « Éditorial » 4,18 ; « Mist » 3,53 ; « Glacier » 3,23 ; « Dune » 3,14. Les thèmes sur dégradé à texte secondaire blanc translucide (Verre 1,98 au point le plus clair, Aurore 1,96, Dawn 1,53, Vapor 2,1, Space 2,18, Ocean 2,33, Lagoon 2,07, Mars 2,08) sont calculés sur la pire des étapes du dégradé et sont donc pessimistes, mais la lecture sur la zone claire reste faible pour du texte de 9-11 pt.
- Correction : Minimal/clair : secondary `6B6B70` (≥ 5:1) ; Rétro `6F5640`, Paper `625C52`, Éditorial `5E584E` ; thèmes à dégradé : opacité du texte secondaire 0.74 → 0.88 et ombre portée légère ou voile sombre sous le texte. À valider sur les captures des familles.

### U-08 — Accents de l'app sous 4,5:1 en mode clair
- Preuve (`AppStyle.swift`, accent clair sur blanc) : Jade (défaut) 4,46 (à la limite), Ambre 4,11, Aqua 4,05, Pistache 3,80, Bleu glace 3,70. Mode sombre : tous ≥ 5,9:1. Le texte-lien d'accent (« See ideas » orange en capture nutrition, rangées « Voir plus ») est concerné.
- Correction : assombrir 4 valeurs claires (Jade 237F72 → 4,9 ; Ambre A85F10 ; Aqua 007F87 ; Pistache 657D3B ; Bleu glace 2F7F99), ou ne pas utiliser l'accent comme couleur de texte de petite taille.

### U-09 — Tailles de police fixes qui ne suivent pas Dynamic Type
- Preuve : 141 `.font(.system(size:))` dans `App/` (dont 20 dans `MarketingShots.swift`, hors usage). La majorité sont des icônes (acceptable), mais ces **textes** restent fixes entre 9 et 12 pt : `SectionIndex.swift:134` (lettres de l'index, 11), `StylePicker.swift:49,151,154,168,176` (9-10), `UIComponents.swift:337,340` (9-10), `StudioComponents.swift:222`, `ExploreView.swift:665`, `DailyPager.swift:124`, `DailySection.swift:432,626,633,1023,1153`, `MyInfoCenter.swift:137`, `NutritionApp.swift:300`, `StudiesPages.swift:190,227`, `WeekViews.swift:359,378,518` (9), `SpaceBuilderView.swift:352`, `HomeSetupViews.swift:283`. Aucun `@ScaledMetric` dans `App/` ni `Shared/` : les pastilles d'icône (28-48 pt) ne grandissent pas avec le texte voisin.
- Correction : remplacer par `.font(.caption2.weight(.bold))` ou `.footnote` ; pour les textes à encombrement contraint, `.dynamicTypeSize(...DynamicTypeSize.accessibility1)`. Pour les icônes de rangée, `@ScaledMetric(relativeTo: .body) var iconBox = 32`. Sur la grille de la semaine (`WeekViews`), 9 pt est illisible : au moins `.caption2` (11 pt) ; l'écran peut rester limité à `.xxxLarge`.

### U-10 — Texte coupé : `lineLimit(1)` et titres tronqués
- Preuve : 135 `lineLimit(1)` dans `App/`. Les titres d'événements du planning sont tronqués dès le réglage normal (capture `app-planning-week.png` : « Uppe… », « Lowe… », « Run 5… », « Send the inv… »), ce qui est voulu pour une grille mais sans aucune alternative (pas de `.help` ni de détail au toucher lu par VoiceOver : à confirmer). `MiniActionButton` (`MiniApp.swift:381-382`) force `lineLimit(1)` + `minimumScaleFactor(0.8)` : en allemand ou en japonais aux grandes tailles le libellé sera coupé (« Aggiungere un alimento »…). `DailyLayoutEditor.swift:114` coupe aussi le titre de la rangée.
- Correction : `MiniActionButton` : `.lineLimit(2)`, `minHeight: 50` (déjà non fixe) ; auditer les 135 occurrences en ne gardant `lineLimit(1)` que pour les montants et les heures.

### U-11 — Mode sombre / couleurs codées en dur
- Preuve : environ 580 `Color(hex:)`, `.white`, `.black` dans `App/`. Beaucoup viennent de la marque des mini-apps (voulu). À surveiller : texte `Color(hex: "E5484D")` rouge sur fond sombre (4,35:1 sur noir) ; `Color(hex: "8A8A8E")` en gris de secours (`PlanningPages.swift:128`) 3,4:1 sur blanc ; `Color(hex: "6B7280")` Voiture (3,5:1 sur noir). Pas de `preferredColorScheme` forcé : l'app suit le système (sain). Les captures en mode sombre `-dark` existent mais n'ont pas été comparées une à une.
- Correction : définir `Color.danger`, `Color.neutralInk` via `Color(light:dark:)` (existe dans `UIComponents.swift:113`) et y faire passer les rouges de texte.

## Amélioration

### U-12 — « Réduire les animations »
Pris en compte à 9 endroits (`Pressable`, `SaveFlight`, `DailyPager`, `DailyEditMode` pour le tremblement `repeatForever`, `LaunchView`, `ExerciseDemo`, `FusionViews`, `DailySection`, `ArdaneApp`). Mais environ 120 `withAnimation` / `.animation` dans `App/` n'y sont pas conditionnés (transitions `.scale`/`.snappy`, ex. `MiniApp.swift:475-481`, `WidgetCarousel.swift:64,102`). Ces animations sont courtes et non vestibulaires ; pour l'essentiel conforme. Correction globale optionnelle : helper `Animation.ifMotion(_:)` ou `withAnimationIfAllowed`, appliqué aux grands déplacements (carrousel, pager, `.spring`).

### U-13 — Suppressions : confirmation inégale
- État : 26 `confirmationDialog`/`alert` ; suppression par balayage (`onDelete`, 40 sites) sans confirmation, ce qui est la convention iOS pour une rangée de liste. Les boutons `role: .destructive` des menus contextuels (≈ 45) sont pour la plupart directs (ex. `FitnessSession.swift:256,274`, `NutritionPages.swift:62,215`, `PlanningApp.swift:251`, `PhotoQuotesApp.swift:171,349,505`). Les suppressions de gros objets (séance, widget, habitude, projet, voiture) passent par un dialogue (`EditorView.swift:146-149`, `HabitsView.swift:224`, `BusinessSources.swift:71`).
- Correction : confirmer les suppressions de données agrégées (séance entière `FitnessPages.swift:483`, projet, cours avec devoirs, photo) ; pour les autres, un « Annuler » après suppression (toast) serait préférable à un dialogue. Pas bloquant.

### U-14 — Cohérence des composants
- Boutons : trois écritures d'un bouton prominent coexistent : `MiniActionButton` (hauteur 50, rayon 16, `MiniApp.swift:370`), boutons en capsule `SpacesView.swift:162` (`caption.bold`) et bannière Premium `HomeView.swift:170` ; deux écritures de retour : `SpaceForms.swift:49` (chevron + texte « Retour », identifiant `back-arrow`) et le bouton rond de verre des mini-apps (capture : cercle bleu pâle, `MiniAppScaffold`). Les cercles « + » en haut à droite des mini-apps (capture `app-finances-transactions.png`) sont à 44-52 pt : sains.
- Case à cocher : cinq implémentations (voir U-04) → un composant.
- Correction : un `PrimaryActionStyle` partagé (hauteur min 50, rayon 16, `readableInk`) et un `CheckCircleButton`.

### U-15 — Petits écrans (iPhone SE, 375 pt)
- Largeurs fixes trouvées : `HomeSetupViews.swift:204` (382×94), `:228,239` (364) ; `SetupWallpapers.swift`, `WallpaperCollection.swift` (réalisations de fonds d'écran : 300-520 pt) ; `MarketingShots.swift`. Ce sont des **rendus de visuels** (aperçus mis à l'échelle, export) et non de l'interface ; ils n'ont pas à être modifiés, mais il faut vérifier que l'aperçu dans l'écran « Ma configuration » est dans un `GeometryReader`/`scaleEffect` (à confirmer en capture SE). `StoreMagazine.swift:105` (hauteur fixe 360 pour la bannière) : acceptable sur SE (667 pt de haut). Aucun `UIScreen.main` dans l'interface (une occurrence dans `ScheduleReader`, hors affichage).
- À capturer : Fitness session (+/− à 36 pt en `HStack` à 3 colonnes), `WeekViews` (7 colonnes, texte 9 pt), `MiniActionButton` en allemand.

## Widgets (famille par famille)
Examen limité au code de thèmes et aux calculs de contraste (captures `export/*` non ouvertes une à une) : voir U-07. `accessoryCircular/Rectangular/Inline` : le rendu force `.dark` (`AdExport.swift:187` pour l'export) ; le mode Clair/Teinté des widgets ne doit pas dépendre de couleurs fixes : à vérifier dans `Shared/Render/` (non couvert faute de temps, signalé comme reste). Le texte secondaire de l'écran verrouillage reste blanc translucide : conforme à la convention système.

## Examiné et trouvé sain
- Zone tactile du `ColorDot` (44 pt) et de l'index alphabétique (adjustable, lu par VoiceOver, `SectionIndex.swift:120-125`).
- Boutons du retour et « + » des mini-apps : grands (≈ 44-52 pt), avec identifiant ; boutons de la plupart des rangées avec texte.
- 145 `accessibilityLabel` et 93 `accessibilityElement(children:)` : la couverture est large ; seuls les 6 boutons de U-04 sont muets.
- Les images décoratives sont masquées (`accessibilityHidden(true)`, ex. `HabitsView.swift:119`).
- Accents sombres du thème d'app tous ≥ 5,9:1 ; Premium `7A5500` sur `F6E7B8` lisible ; couleurs Nutrition (rouge, jaune, bleu) sont utilisées en barres, pas en texte.
- `Pressable` respecte « Réduire les animations » (suppression de la mise à l'échelle). Aucune animation infinie hors mode édition de l'accueil (qui est conditionnée).
- Pas de `preferredColorScheme` forcé dans les écrans ; suppression de gros objets confirmée.
- États vides : présents et traduits dans les pages examinées (`FinancesPages.swift:119` « Aucune dépense notée pour ce mois. »).

## Corrections globales proposées
1. `.tapTarget()` (44 pt + `contentShape`) : U-03.
2. `CheckCircleButton` (libellé, valeur, 44 pt) : U-04/05/14.
3. `Color.readableInk(on:)` pour tous les textes sur couleur de marque : U-02.
4. Règle `check_swift.py` : Button + `.foregroundStyle(.primary|.secondary)` sans `buttonStyle` ; et `.font(.system(size: <12))` appliqué à un `Text` : U-01/U-09.
5. Ajustement des 5 secondaires de widgets et 5 accents : U-07/U-08.
6. Libellés des 6 `Chart` et des `ProgressView` : U-06.

## Restes non couverts
Rendu SE et Dynamic Type XXL (aucune capture disponible), `Shared/Render/` famille par famille, comparaison clair/sombre des captures, VoiceOver réel.

## Corrections faites (mission 24.C-U, 2026-11-07)

Rien n'est compilé : tout reste à confirmer par la CI (`[check]`). `python3 scripts/check_swift.py` passe (OK). Nouveau fichier : `App/Components/AccessibilityHelpers.swift` (`tapTarget`, `tapAreaOutset`, `confirmDelete`, `Color.readableInk(on:)`, `CheckCircleButton`).

- **U-01 (fait)** : le balayage retrouve les 13 sites + 1 faux positif (Onboarding). `MoneyView`, `KindOptionsSection` et `ProfileView` avaient déjà `.tint(.primary)` (effet neutralisé). Les autres passent à `Color.primary` / `Color.secondary` (et `Color.secondary.opacity(0.55)` pour les chevrons `.tertiary`) : `DailySection` (ajout de catégorie), `MiniAppsRow`, `BusinessApp` (indicateurs), `BusinessPages` (ventes, coûts), `CarPages` (+ `ServiceStatusRow` dans `CarApp`), `FinancesPages` (revenus, factures, et `expenseRow` qui était la vraie cause de la capture), `ExerciseLibraryViews`. Apparence voulue inchangée. Règle ajoutée dans `check_swift.py` (`check_button_label_tint`), testée sur un fichier factice (détecte, puis fichier supprimé).
- **U-03 (fait pour les boutons)** : `tapTarget()` (cadre 44 pt) pour − / + de la séance ; `tapAreaOutset()` (zone étendue sans bouger la mise en page) pour `DaySwitcher` (3 boutons), « retour à aujourd'hui », menu « … » de Fitness, +/− de repos, coche et chevron de la carte Top 3 (`DailySection`), œil de `DailyLayoutEditor`. Laissés : `MiniApp.swift:282`, `StoreMagazine`, `ExerciseLibraryViews:55`, `BusinessApp`, `FinancesApp`, `NutritionApp` (36 pt) : ce sont des pastilles d'icône décoratives dans des rangées déjà tactiles.
- **U-04 / U-05 (fait)** : `CheckCircleButton` (zone 44 pt, libellé = titre, valeur « Fait » / « À faire », trait `isSelected`) remplace les cases de Planning, Productivité (`ProductivitySpace`) et Études (`StudentSpace`) ; couleurs d'origine conservées. Top 3 de l'Accueil : valeur et trait ajoutés. `TasksView` avait déjà le trait. − / + : libellé « Diminuer : … » / « Augmenter : … ». `HabitsView` : libellé « Icône n » et trait de sélection.
- **U-02 (fait en partie)** : `Color.readableInk(on:)` : blanc tant qu'il atteint 4,5:1 ou que l'encre sombre ne gagne pas 15 %, sinon encre 141414. Appliqué à `MiniActionButton`, bouton flottant `MiniAppScaffold`, pastilles `MiniAppsRow`, `MyInfoCenter`, `DataItemViews`, numéros d'Apple Pay, sélecteur d'icône des habitudes, boutons de scan orange de l'Accueil. Effet : Nutrition (2,5), Voyage (3,0), Photos (3,5) passent en encre sombre ; Finances (3,94) et Fitness (3,91) restent en blanc (le noir ne gagne que 12 %) : sous 4,5 mais ce texte est gras ; décision de marque à confirmer. Non traité : les ~25 autres `.white` sur couleur dans `StoreMagazine`, `SpacesView`, `PhotoQuotesApp`, `WeekViews` (pastilles, voiles noirs ou taille 9-10 pt, voir U-09).
- **U-06 (fait)** : `accessibilityLabel` sur 19 `Chart` (titre de la section voisine, textes déjà traduits) ; libellé + valeur sur 16 `ProgressView(value:)`. Pas de valeur détaillée sur les graphiques (l'audio graph de Charts reste actif).
- **U-07 (fait)** : voir la liste ci-dessous. **U-08 (non fait)** : `Tests/AppPaletteTests.swift` fige les 12 valeurs d'accent (fichier de test interdit) et la palette est une décision du 2026-10-27. Valeurs proposées (4,5:1 sur le fond d'écran teinté) : Bleu glace 398FA8 -> 2F768B, Aqua 008C95 -> 007B83, Jade 268577 -> 237B6E, Pistache 718C42 -> 607738, Olive 77752B -> 74722A, Ambre B86A13 -> A25D11, Rose C04472 -> B93E6C, Orchid 9854B8 -> 934BB4. À faire avec la mise à jour du test.
- **U-10 (fait)** : `MiniActionButton` : 2 lignes, centré, `minimumScaleFactor` 0,8, marges verticales ; hauteur minimale 50 inchangée. Les autres `lineLimit(1)` ne sont pas touchés.
- **U-13 (fait, sobre)** : confirmation (`confirmDelete`) pour les suppressions par menu contextuel sans annulation : événement unique et occurrence d'un cours (`StudiesPages`), objectif d'épargne et compte (`FinancesPages`). Laissés : suppressions par balayage (convention iOS), séances/habitudes/widgets (déjà confirmées), exercices, Top 3, abonnements MRR, examens (menu contextuel, à décider).
- **Non traités** : U-09 (polices fixes < 12 pt) et la règle `check_swift.py` correspondante (beaucoup d'occurrences, risque de rendu ; à faire avec captures SE/Dynamic Type), U-11, U-12, U-14, U-15.

### Couleurs de widgets changées (`Shared/Theme/Theme.swift`, secondaire, contraste visé 4,5:1 sur le fond)
Minimal et Compact (clair) 8A8A8E -> 757579 ; Clair 7C7D82 -> 6E6F73 ; Rétro 8A6F55 -> 78614A ; Typo (clair) 85858A -> 75757A ; Moderne (clair) 84858B -> 74757B ; Carte (clair) 7D828C -> 656A73 ; Soft (clair) 8D7F99 -> 776883 ; Éditorial 7A746A -> 736E64 ; Magazine (clair) 7F7F7F -> 757575 ; Pastel (clair) 9C8A82 -> 7D6B63 ; Paper 7C766C -> 716C63 ; Brume 6B7785 -> 5B6571 ; Forest (clair) 5E7462 -> 5D7361 ; Blossom (clair) A07380 -> 90626F ; Dune 7A6043 -> 5D4933 ; Glacier 4A6A88 -> 3A536B ; Botanical 557A5B -> 48684E. Thèmes à dégradé : opacité du texte secondaire blanc portée à 0,88 pour Verre (0,74), Aurore (0,72), Vapor (0,80), Dawn (0,82), Space (0,78), Heroic (0,80). Aucun accent de marque ni logo touché. À valider sur les captures de familles.
