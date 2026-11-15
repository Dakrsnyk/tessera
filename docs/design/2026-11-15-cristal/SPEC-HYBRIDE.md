# Parcours 5 « Hybride intelligent » : spécification de codage (2026-11-15)

Choix du PDG le 2026-11-15 : coder le parcours 5 (planche `25-creation-hybride.html`, résumé `27-creation-resume.html`) puis l'envoyer sur TestFlight (version interne). Mélange d'espaces dans un widget : **non** pour l'instant (règle actuelle gardée). Ce document est la seule référence commune des agents : interfaces partagées, comportements, identifiants d'accessibilité. Lire aussi `GUIDE-CODE.md` (règles Cristal en SwiftUI) et `CLAUDE.md`.

## 0. Principes
- Rien de supprimé : tailles, écran verrouillé, 12 espaces + widgets hors espace, thèmes, styles, couleurs, fond, bordure, graphique, densité, mes styles, options de chaque widget, Premium, limite gratuite, enregistrer / modifier / dupliquer / supprimer, photos et citations, packs et combinés du Store, fusion de Mes widgets, plusieurs widgets séparés d'un coup.
- Un seul geste pour réunir : le « + » (sur l'aperçu et dans la liste « Dans ce widget »). Jamais un widget retiré sans le dire : quand un ajout ne tient pas, l'app passe à la taille au-dessus et l'annonce (bandeau + « Annuler »), ou refuse en donnant la raison.
- Les règles de mise en page ne changent pas (`ComboLayout`, `Composer`) : une ligne = 1 widget moyen ou 2 petits ; Moyen = 1 ligne, Grand = 2 lignes ; 4 parties au plus ; écran verrouillé = 1 widget, jamais réuni. Même espace (ou même catégorie pour les widgets hors espace, comme `Fusion.category`).
- Tout nouveau texte visible passe par `tr()` ; traductions faites à la fin (lot E).
- Pas de Mac : rien ne compile en local. Écrire du Swift 5 / iOS 17 prudent, lire le code voisin avant d'appeler une API, `python3 scripts/check_swift.py` doit finir par OK.

## 1. Modèle (lot A) — `Shared/Model/Combo.swift` + `Tests/ComboEditingTests.swift`
Fonctions pures, testées. Une composition = `[ComboPart]` ; un widget seul = 1 partie dont `size` est son format (Petit, Moyen ou Grand).

```swift
enum ComboEditing {
    /// Le résultat d'une modification : les parties (1 = widget seul), le format, et ce qui a changé de taille.
    struct Outcome: Equatable {
        let parts: [ComboPart]
        let format: WidgetFormat
        /// Ancien format quand la taille a changé (pour le bandeau « Passé en Grand pour tout afficher »).
        let resizedFrom: WidgetFormat?
    }
    enum Change: Equatable { case applied(Outcome), refused(String) }   // String = raison déjà traduite (tr)

    static func adding(_ part: ComboPart, to current: [ComboPart]) -> Change
    static func removing(at index: Int, from current: [ComboPart]) -> Change
    static func replacing(at index: Int, with part: ComboPart, in current: [ComboPart]) -> Change
    static func moving(from: Int, to: Int, in current: [ComboPart]) -> Change
    /// Les dispositions possibles des mêmes parties (ordre et partie « ligne entière »), la première = l'actuelle.
    static func arrangements(of current: [ComboPart]) -> [[ComboPart]]
    /// Peut-on ajouter ce widget ? nil = oui ; sinon la raison (tuiles estompées du choix).
    static func refusal(adding kind: WidgetKind, to current: [ComboPart]) -> String?
    /// Même espace, ou même catégorie hors espace (règle de `Fusion.category`).
    static func sameFamily(_ a: WidgetKind, _ b: WidgetKind) -> Bool
}
extension WidgetDesign {
    /// Les parties à éditer : celles d'un widget réuni, ou le widget seul comme 1 partie (son format d'affichage).
    var editableParts: [ComboPart] { get }
    /// Le widget avec ces parties : 1 partie = widget seul (kind, options, nom, format ; options.parts vide),
    /// 2 ou plus = widget réuni au format donné. Style, couleurs, fond… inchangés. Le nom suit les parties
    /// (« A + B ») tant que la personne ne l'a pas changé (nom actuel = nom automatique des anciennes parties).
    func applying(_ outcome: ComboEditing.Outcome) -> WidgetDesign
}
extension Fusion {
    /// Pourquoi ces widgets ne fusionnent pas (autre espace, widget Grand, même contenu deux fois, tailles qui ne remplissent pas un Moyen ou un Grand) ; nil s'ils fusionnent.
    static func refusal(for designs: [WidgetDesign]) -> String?
}
```
Règles :
- `adding` : nouvelles sortes = sortes actuelles + la nouvelle à la fin ; essayer `Composer.plan(..., .medium)` puis `.large` (le plus petit qui marche) ; si la partie seule actuelle était Grand, essayer `.large` d'abord. Les parties gardent leurs `options` et `name` (corrige la perte de réglages) ; seule `size` suit le plan. Refus : même widget déjà présent (même `Fusion.contentKey`), autre espace (`sameFamily`), plus de 4, ou le message `Composer.plan(.large)` invalide (déjà traduit). Écran verrouillé : jamais d'ajout (l'appelant ne le propose pas).
- `removing` : 1 partie restante = widget seul au format Moyen s'il existe en moyen, sinon Petit ; 2 ou plus = plus petit plan valide (Moyen puis Grand) ; `resizedFrom` renseigné si le format change. Refuser de retirer la dernière partie.
- `replacing` : comme `removing` puis `adding` à la même place (garder l'ordre) ; refus si la nouvelle sorte ne tient pas.
- `moving` : ordre changé, tailles gardées si `ComboLayout.rows` reste valide ; sinon re-plan avec `Composer` (même format si possible).
- `arrangements` : 2 petits → [A,B], [B,A] ; 2 moyens → [A],[B] / [B],[A] ; 1 moyen + 2 petits → moyen en haut / en bas, et chaque autre partie pouvant être la « ligne entière » (si elle existe en moyen, les deux autres en petit) ; 4 petits → l'ordre actuel puis les deux lignes échangées. Sans doublon, la première = l'actuelle.
- Tests : chaque règle ci-dessus, dont : ajout à un Petit seul → Moyen [A,B] ; 3e ajout → Grand avec `resizedFrom == .medium` ; 5e → refus ; retrait jusqu'à 1 → widget seul ; options et nom d'une partie gardés après ajout, retrait, déplacement ; autre espace refusé ; `applying` garde l'`id`, le thème, la couleur, le fond.

## 2. Écran de départ et « Sur mon écran » (lot B)
Fichiers : nouveau `App/Screens/Spaces/CreateStartView.swift`, `App/Screens/Spaces/CreateView.swift`, nouveau `App/Screens/Editor/HomeScreenPreview.swift`, `App/Core/Router.swift` si besoin.
- L'onglet Créer s'ouvre sur `CreateStartView` (titre « Créer », écran Cristal `cristalScreen()`) :
  - « Pour toi » + « Tes espaces préférés » : défilement horizontal de cartes (panneau, `cristalPanel`) ; une carte par espace (préférés d'abord, `model.profile.preferredSpaces`, puis les autres ; 6 au plus) = le widget Moyen de `SpaceCatalog.preset(for:format:.medium)` monté comme le constructeur le fait (`Composer.plan` + `ComboPart` + `SpaceCatalog.design(for:)`), au look de départ de l'espace ; vrai aperçu `WidgetPreview` avec `model.previewPayload` ; titre = noms des parties (« Prochaine série + Régularité »), sous-titre « Fitness · Moyen », pastille « Gratuit » ou cadenas Premium. Toucher = ouvrir l'Atelier dessus (nouveau widget, chapitre Contenu). Identifiants `create-for-you-<space>`.
  - « Partir de zéro » : 4 tuiles (silhouette + nom) Petit, Moyen, Grand, Écran verrouillé. Petit/Moyen/Grand = l'Atelier sur `SpaceCatalog.proposal(...)` au format demandé (Moyen/Grand : le widget proposé en moyen ou grand s'il existe à ce format, sinon en petit avec la liste « Dans ce widget » prête à recevoir un « + ») ; Écran verrouillé = `LockScreenCreator` (feuille, comme aujourd'hui depuis « Changer de widget »). Identifiants `create-scratch-small|medium|large|lock`.
  - « Partir d'un modèle » : « Un combiné du Store » (onglet Store, page des combinés : `router.tab = .explore` + `storePath = [.combos]`) et « Dupliquer un de mes widgets » (feuille listant Mes widgets en vignettes ; toucher = l'Atelier sur une copie : nouvel `id`, nom « … (copie) » comme le fait déjà « Dupliquer » de Mes widgets si cette fonction existe, nouveau widget). Identifiants `create-from-store`, `create-duplicate`.
  - Ligne « Photos et citations » (illimitées en gratuit) qui ouvre le flux actuel (`PhotoQuoteEditor` via le choix « Photos » / « Citation » existant). Identifiant `create-photos`.
- L'Atelier = `WidgetStudio(request:isPushed: true, onChangeWidget:onClose:)` **poussé** dans la pile de navigation de Créer (`.navigationDestination(item:)` sur la demande), bouton retour rond. Après l'enregistrement : retour à l'écran de départ, puis le vol vers Mes widgets et le guide d'ajout comme aujourd'hui (logique existante de `CreateView` / `ArdaneApp`). « Changer de widget » garde sa feuille (`SpacesView(onChoose:)`) et remplace le widget de l'Atelier.
- `router.requestedCreator` (une catégorie touchée sur l'Accueil, et les captures `creator-<space>`) : ouvrir l'Atelier sur la composition « Pour toi » de cet espace. Garder le constructeur en feuille seulement pour les captures qui en ont besoin (`screenshotCreator…`), sans casser `ScreenshotMode`.
- `HomeScreenPreview` (« Sur mon écran ») : `struct HomeScreenPreview: View { init(design: WidgetDesign, family: WidgetFamily, payload: WidgetPayload, onSave: @escaping () -> Void) }`, présenté en plein écran par l'Atelier. Fond = dégradé doux de la palette Cristal de l'app ; grille d'icônes d'apps génériques d'iOS (symboles SF dans des carrés arrondis blancs : Photos, Appareil photo, Plans, Météo, Téléphone, Messages, Safari, Musique) en 4 colonnes et un dock ; le widget à sa **taille réelle** (`WidgetMetrics.size(family)`, sans mise à l'échelle) à sa place dans la grille (Petit = 2 × 2 icônes, Moyen = 4 × 2, Grand = 4 × 4), libellé « Ardane » dessous ; capsule de verre en haut « Sur mon écran » + taille, avec retour ; bouton plein « Enregistrer le widget » au-dessus du dock (appelle `onSave`). Écran verrouillé : écran de nuit avec l'heure et le widget accessoire. Identifiants `home-preview`, `home-preview-back`, `home-preview-save`.

## 3. L'Atelier (lot C)
Fichiers : `App/Screens/Editor/EditorView.swift`, `StudioComponents.swift`, `StudioPanels.swift`, nouveau `App/Screens/Editor/StudioParts.swift`, `App/Core/Router.swift` (seulement `EditorRequest`).
- **`EditorRequest`** reçoit `var family: WidgetFamily? = nil` (dernier paramètre des deux `init`, défaut nil) : famille d'ouverture (écran verrouillé). Si présente, l'Atelier s'ouvre sur cette famille.
- **Trois chapitres** sous la scène, à la place de la rangée de 10 outils : « 1 Contenu », « 2 Disposition », « 3 Style » (sélecteur à 3 positions en verre ; pastille numérotée, coche quand le chapitre a été ouvert ; identifiants `studio-chapter-content|layout|style`). Un lien « Suivant › » en haut à droite du panneau passe au chapitre suivant.
  - **Contenu** : outil Taille (Petit, Moyen, Grand + Rond, Rectangle, En ligne, comme aujourd'hui ; identifiant `studio-size` gardé sur le bouton qui l'affiche ou sur le bloc), puis « Dans ce widget · N sur M » (liste des parties : vignette, nom, numéro, toucher = détail de la partie ; identifiant `part-<kind>` gardé), une ligne « + Ajouter un widget » (`parts-add`) tant qu'il reste de la place et que ce n'est pas l'écran verrouillé, puis le contenu actuel (nom, « Tes données », options du widget ou des parties, éléments affichés, supprimer). Garder `studio-content` sur l'accès au contenu.
  - **Disposition** : widget réuni → dispositions proposées (`ComboEditing.arrangements`, vignettes schéma : cases numérotées ; identifiants `layout-plan-<n>`), puis la liste des parties avec « Monter » / « Descendre » (44 pt, `part-up-<i>` / `part-down-<i>`) et la phrase « Une ligne = 1 widget large ou 2 petits. ». Widget seul → « Un seul widget : rien à ranger. Ajoute un widget pour en réunir plusieurs. » + bouton « Ajouter un widget ». Écran verrouillé → « Un widget de l'écran verrouillé reste seul. »
  - **Style** : la rangée d'outils actuelle sans Taille ni Contenu (Thème, Style, Couleurs, Fond, Bordure, Graphique s'il y a un graphique, Densité, Mes styles ; identifiants `studio-<section>` gardés) et leurs panneaux inchangés.
  - `EditorRequest.section` reste accepté : `size`/`content` → Contenu, les autres → Style sur cet outil.
- **La scène agit sur le widget** : sur un widget réuni (Moyen, Grand), des zones touchables posées exactement sur chaque partie (même découpage que `ComboWidgetView` : lignes égales, cases égales ; identifiants `stage-part-<i>`) ; la partie choisie a un anneau (couleur d'action + épaisseur, pas la couleur seule). Un bouton rond « + » en verre sur la scène (`stage-add`) quand il reste de la place. Pastilles du bas gardées : « Changer de widget » (`create-change`, cible du tutoriel gardée) et l'œil « Sur mon écran » (`studio-on-my-screen`) qui ouvre `HomeScreenPreview`.
- **Détail d'une partie** (dans le panneau du chapitre Contenu, pas une nouvelle feuille) : titre = nom de la partie + « Petit · Fitness » ; boutons « Remplacer » (`part-replace`) et « Retirer » (`part-remove`, absent s'il ne reste qu'une partie) ; ses réglages (nom et options : réutiliser `ComboPartSettingsView` / `KindOptionsSection` dans le panneau) ; « Va bien avec » : 3 tuiles (`add-kind-<kind>`) des widgets du même espace qu'on peut ajouter maintenant (`ComboEditing.refusal == nil`), gratuits d'abord, présélections de l'espace d'abord, cadenas Premium visible, + lien « Tous les widgets de <espace> ». « Fermer » revient à la liste.
- **Choix d'un widget à ajouter** (`parts-add`, `stage-add`, « Tous les widgets… », « Remplacer ») : dans le panneau, sous la scène (pas de feuille) : titre « Ajouter à côté de <nom> » (ou « Remplacer <nom> ») ; grille 3 colonnes des widgets du même espace (ou de la même catégorie hors espace) avec vrai aperçu, cadenas Premium lisible (pas 9 pt : 12 pt au moins, badge), badge Interactif, filtre « Seulement les widgets interactifs » s'il y en a ; un widget qui ne peut pas être ajouté est estompé ET dit pourquoi en petit dessous (`ComboEditing.refusal`). Toucher = `ComboEditing.adding/replacing` puis `design.applying(...)` (une étape de l'historique annuler / rétablir).
- **Bandeau** quand la taille change (`combo-note`) : « Passé en Grand pour tout afficher : 3 widgets réunis. » (ou « Repassé en Moyen… ») + « Annuler » (`combo-note-undo` = annuler de l'historique). Si le widget est déjà enregistré (`!isNew`) et change de taille : ajouter « Déjà posé sur ton écran ? Il faudra le reposer à la nouvelle taille. ». Un refus s'affiche dans le même bandeau, sans rien modifier.
- **Plusieurs widgets séparés** (lot de « Changer de widget », packs) : sélecteur 1/2… et « Même style » gardés ; « + » et le détail agissent seulement sur le widget en cours (`designs[index]`), jamais sur tout le lot.
- **Après l'enregistrement aussi** (`!isNew`, ouvert depuis Mes widgets) : ajouter, retirer, remplacer, réordonner restent possibles (supprimer la condition `isNew` de `canCombine`). L'ancien bouton « Réunir avec un autre widget » et la feuille `SpaceBuilderView(combines: true)` ouverte depuis Taille disparaissent (remplacés par le « + »).
- Écran verrouillé (`family.isAccessory`) : ni « + », ni zones de partie, ni Disposition active ; un widget réuni affiché sur l'écran verrouillé montre sa 1re partie (comme aujourd'hui).
- Taille d'un widget réuni : les puces Petit / Moyen / Grand restent ; passer de Moyen à Grand ou l'inverse re-planifie avec `Composer` (refus expliqué si impossible : « Pour réunir 4 widgets, chacun doit exister en petit. »…).

## 4. Constructeur, écran verrouillé, fusion (lot D)
Fichiers : `App/Screens/Spaces/SpaceBuilderView.swift`, `App/Screens/Spaces/LockScreenCreator.swift`, `App/Screens/MyWidgets/MyWidgetsView.swift` (et `FusionViews.swift` si besoin).
- « Changer de widget » avec 2 widgets choisis ou plus : bouton « Créer les N widgets séparés » et une note sous le compteur : « Ils seront séparés. Pour les réunir en un seul widget, touche « + » sur le widget dans l'Atelier. ». Un seul choisi : inchangé.
- Écran verrouillé : `LockScreenCreator` ouvre l'Atelier avec `EditorRequest(..., family:)` sur la forme accessoire choisie (Rectangle de préférence, sinon Rond, sinon En ligne).
- Mes widgets, mode sélection avec 2 widgets ou plus quand la fusion est impossible : une ligne sous la barre de sélection avec `Fusion.refusal(for:)` (au lieu de rien).

## 5. Tests, captures, tutoriel, langues (lot E, après B, C, D)
- UITests à mettre à jour : `StudioUITests` (Créer s'ouvre sur l'écran de départ ; « Pour toi » ouvre l'Atelier ; « Partir de zéro › Moyen », « + », un 2e widget → widget réuni, `part-…` visibles ; 3e → bandeau `combo-note` et Grand ; Disposition ; enregistrement → guide d'ajout puis retour à l'écran de départ ; chaque outil du chapitre Style s'ouvre), `MiniAppUITests` (ligne qui touche `create-change`), `ProfileUITests` (parcours du constructeur et des captures), tout test qui suppose que Créer s'ouvre directement sur le Studio.
- `ScreenshotMode` / captures (`-screenshotScreen spaces`, `creator-<space>`, `screenshotCreatorStudio`…) et tutoriel (cible `.createSpace` sur l'écran de départ, texte de l'étape `.create` à vérifier).
- Localisation : extract → traductions en, es, de, it, pt-BR, ja dans `l10n/parts/NN.<langue>.json` (glossaire `l10n/GLOSSARY.md`) → merge → build → sync ; `l10n sync` à 0 manquant.
- `scripts/graph_map.py` (MODULES : Créer, Atelier) ; `python3 scripts/check_swift.py` OK.

## 6. Hors périmètre (dit au PDG)
- Mélanger des espaces dans un même widget (décision : plus tard).
- Glisser une partie directement sur la scène : remplacé par les dispositions proposées et « Monter / Descendre » (plus fiable au doigt) ; à ajouter plus tard si besoin.
- Un lien différent par partie sur l'écran d'accueil.
