# Audit parcours, accessibilité, traductions (2026-11-27)

Lecture seule du code. Rien n'a été vu à l'écran (pas de Mac, pas de capture) : tout ce qui suit vient de la lecture du code et de `Shared/Localizable.xcstrings`. Aucun skill de design (`ui-ux-pro-max`, HIG Compliance Auditor) n'était exposé : travail fait avec les HIG. Gravités : B = bloquant App Store, F = forte, M = moyenne, m = mineure.

---

## 1. Parcours : premier lancement → premier widget sur l'écran d'accueil

### 1.1 Chemin réel (code)

1. `LaunchView` : marque 1,15 s (`ArdaneApp.swift:~228`), puis `OnboardingView` en plein écran (`ArdaneApp.swift:149`).
2. Onboarding (`OnboardingView.orderedSteps`, l.32-36) : Style → Identité → Intérêts → 1 page par thème choisi (0 à N) → Autorisations.
3. `OnboardingOffer` (Premium) après la dernière page (l.89-91) : « Plus tard » pour passer.
4. Tutoriel de 8 étapes (`Tutorial.swift`, lancé 0,75 s après, `ArdaneApp.swift:154`) : bienvenue, Mon Quotidien, Créer, Studio, Store, Mes widgets, écran d'accueil, fin.
5. Créer (`CreateFlow.swift`) : Taille → Catégorie → Widget. En Petit, le toucher sur le widget ouvre le Studio (`pick`, l.600-606).
6. Studio (`EditorView.swift`) : « Enregistrer le widget » (l.898-900) ; un widget neuf est enregistrable sans modification (`hasChanges = isNew || …`, l.111).
7. Animation de vol vers « Mes widgets », puis `AddToHomeScreenGuide` (`ArdaneApp.swift:~190`, 3 premiers enregistrements seulement), « Compris ».
8. Hors de l'app : appui long, Modifier, Ajouter un widget, chercher Ardane, taille, Ajouter (7 à 8 gestes iOS que l'app ne peut pas faire à la place de la personne).

### 1.2 Nombre de touchers (minimum, tout passé)

| Segment | Touchers min. | Écrans |
|---|---|---|
| Onboarding (Continuer, Passer, Passer, C'est parti, Plus tard) | 5 | 5 (style, identité, intérêts, autorisations, offre) |
| Avec 3 intérêts + leurs pages | 8 à 12 | 8 à 10 |
| Tutoriel (suivant ×8 ou « quitter ») | 1 à 8 | 8 |
| Créer : onglet, taille, catégorie, widget | 4 | 3 |
| Studio : Enregistrer | 1 | 1 |
| Guide : Compris | 1 | 1 |
| **Total dans l'app** | **12 à 19 (parcours court) ; jusqu'à 30 (parcours complet)** | **~20 écrans** |
| iOS, hors app | 7 à 8 | — |

Constat : environ 15 écrans et 12 à 19 toucher avant que l'utilisateur ait vu son propre widget ; la première valeur arrive après l'offre Premium et un tutoriel de 8 étapes. Le widget n'est jamais sur l'écran d'accueil sans que la personne quitte l'app et suive un texte.

### 1.3 Points de décrochage probables

| # | Où | Problème | Gravité |
|---|---|---|---|
| D1 | `OnboardingView.swift:32-36`, `OnboardingOffer.swift` | 4 à 10 pages de questions (identité, date de naissance, intérêts, pages thématiques) avant tout widget ; l'offre Premium arrive avant la première valeur | F |
| D2 | `ArdaneApp.swift:154` | Tutoriel de 8 étapes juste après l'offre : 3 écrans « passer » d'affilée (questions, offre, tutoriel) | F |
| D3 | `AddToHomeScreenGuide.swift:70-74` | Guide de 5 étapes en texte seul, sans animation ni schéma ; étapes 4 et 5 (« il garde ce widget », « choisir un autre ») sont subtiles : le comportement « dernier widget de la taille » de la galerie iOS est dur à comprendre | F |
| D4 | `AddToHomeScreenGuide` | Aucun accès rapide à l'écran d'accueil ni vérification que le widget a été posé ; aucune relance si la personne ferme le guide sans poser (compteur `addGuideCount` < 3 seulement) | M |
| D5 | `OnboardingOffer.swift:88-112` | « Plus tard » et « Restaurer » en `.secondary` petit : la sortie est discrète (risque ressenti de piège), et la zone tactile est plus petite que 44 pt (voir 2.1) | M |
| D6 | Après le tutoriel | Aucun appel « Crée ton premier widget » : l'app s'ouvre sur Mon Quotidien ; l'étape « Créer » du tutoriel ne mène qu'à l'explication | M |
| D7 | `CreateFlow.swift:790` | Texte « l'Atelier s'ouvre aussitôt » : le reste de l'app dit « Studio » ; mot inconnu de l'utilisateur | M |
| D8 | `OnboardingView.swift:359` | « Saphir est offert. Avec Premium, choisis parmi N couleurs… » : écran de style qui parle déjà de Premium, 1re page de l'app | m |
| D9 | `OnboardingOffer.swift:31-33` | « Statistiques, exercices, scans illimités » : liste de 3 éléments dont le sens d'« exercices » (illimités ou statistiques ?) est ambigu | m |

### 1.4 Textes peu clairs

- `CreateFlow.swift:790` : « l'Atelier » (devrait être « le Studio »). Même mot dans `SpaceBuilderView.swift:275`.
- `AddToHomeScreenGuide.swift:73` : « Ajoute-le : il garde ce widget, même quand tu en crées d'autres » (le « il » est le widget iOS posé, pas le widget Ardane : confus).
- `OnboardingOffer.swift:254` : « Essayer N jours gratuits » sans pluriel (le titre, lui, utilise `Fmt.plural`) : « 1 jours » si l'essai passe à 1 jour.
- `OnboardingOffer.swift:206` : « −50 % » en `Text(verbatim:)`, donc la même forme dans les 6 langues (en/pt/ja : « −50% »).
- `Fmt.plural` met un espace (« 7 日間無料 ») : en japonais, pas d'espace.

### 1.5 Dix améliorations classées

Impact (I) et effort (E), 1 = faible, 3 = fort.

| Rang | Amélioration | I | E |
|---|---|---|---|
| 1 | Après l'onboarding, une carte « Crée ton premier widget » sur Accueil (ou saut direct à Créer › Petit) à la place/avant le tutoriel de 8 étapes ; tutoriel proposé, non imposé | 3 | 1 |
| 2 | Remplacer « Atelier » par « Studio » dans `CreateFlow.swift:790` et `SpaceBuilderView.swift:275` (2 clés françaises à retraduire) | 2 | 1 |
| 3 | Mettre l'offre Premium après le premier widget enregistré (ou à la 2e ouverture) ; en onboarding, seulement « Plus tard » visible et plus grand | 3 | 2 |
| 4 | Passer l'onboarding à 3 pages en parcours court : regrouper Identité + Intérêts, reporter les pages thématiques à « Mes informations » (déjà « à compléter ») | 3 | 2 |
| 5 | Guide « Ajouter un widget » : combiner chaque étape en un élément VoiceOver, ajouter une courte animation ou une carte schématique, et un bouton « Ouvrir l'écran d'accueil » n'existe pas côté iOS : garder 3 étapes essentielles et déplier « Choisir un autre widget » | 2 | 2 |
| 6 | Zone tactile 44 pt sur « Restaurer », « Plus tard », « Conditions », « Confidentialité » (offre) | 2 | 1 |
| 7 | Relancer le guide une fois depuis Mes widgets si le widget n'est pas encore posé (ex. bandeau « Pose-le sur ton écran ») | 2 | 2 |
| 8 | « Essayer N jours gratuits » : passer par `Fmt.plural` ou une clé « Essayer gratuitement » sans nombre ; « −N % » via format localisé | 1 | 1 |
| 9 | Barre « Étape n sur N » visible dans l'onboarding (supprimée le 2026-11-22, `OnboardingView.swift:165`) : au moins un point d'avancement discret, pour réduire l'abandon | 1 | 1 |
| 10 | Clarifier la liste Premium (`OnboardingOffer.swift:31-33`) : « Widgets, styles et scans sans limite » ; retirer « exercices » | 1 | 1 |

---

## 2. Accessibilité

### 2.1 Cibles tactiles < 44 pt

| Fichier:ligne | Problème | Gravité |
|---|---|---|
| `OnboardingOffer.swift:88-112` | `.frame(minHeight: 44)` est posé sur le `HStack`, pas sur les boutons « Restaurer » et « Plus tard » : la zone tactile reste la hauteur du texte (~20 pt) | F |
| `OnboardingOffer.swift:272-277` | « Conditions » / « Confidentialité » en `.caption` sans cadre (~16 pt de haut) ; liens exigés par la règle 3.1.2 donc à garder utilisables | F |
| `ExploreView.swift:328-337` et `:907-914` | Boutons « Tout voir » du Store : texte `.subheadline` seul (~20 pt) | F |
| `PaywallView.swift:329` | « Restaurer mes achats » `minHeight: 32` | M |
| `ExploreView.swift:717` | Puces de filtre du Store `minHeight: 36` | M |
| `DailySection.swift:1542, 1574` | Boutons de l'Accueil `minHeight: 36` ; `:933` cadre 28 × 24 ; `:1448/1522` 28 × 28 si ce sont des boutons | M |
| `MyInfoCenter.swift:248` | Pastille 20 pt (décorative : l'étiquette est portée par la ligne) | m |
| `StudioParts.swift:342, 489`, `StylePicker.swift:153` | Pastilles 24 à 28 pt : décoratives, hors cible | m |

Correction commune : `.frame(minWidth: 44, minHeight: 44)` + `.contentShape(Rectangle())` sur le `Button` lui-même, pas sur le conteneur.

### 2.2 VoiceOver

| Fichier:ligne | Problème | Gravité |
|---|---|---|
| `OnboardingOffer.swift:157` | `Image(systemName: "checkmark")` des avantages non masquée : VoiceOver lit « coche » avant chaque ligne | M |
| `OnboardingView.swift:318` (`StepTitle`) | Icône de page non masquée (`accessibilityHidden(true)` manquant) | M |
| `OnboardingView.swift:403-406` (`AddStepRow`) | Icône non masquée ; « Étape n » et le texte sont deux éléments séparés (2 balayages par étape) : combiner avec `.accessibilityElement(children: .combine)` | M |
| `PaywallView.swift:117` | Icône de contexte non masquée (le titre suit juste après) | m |
| `PremiumLock.swift:15` | Icône du cadenas de carte non masquée | m |
| `OnboardingOffer.swift:215` | Cercle de choix : couvert par le bouton + `.isSelected` ; OK. Le badge « −50 % » est lu « moins 50 pour cent » : bon | — |
| `StoreMagazine.swift:172-174` | `.ignore` + label « Collection X, N widgets » sans pluriel : « 1 widgets » | m |
| `EditorView.swift:423, 429` | Étiquettes « Retour en arrière » / « Retour en avant » : clés françaises peu parlantes (la traduction est correcte : Undo/Redo) ; préférer « Annuler la dernière action » / « Rétablir » | m |
| `StudioComponents.swift:131-162` | Barre de sections : le label vient du texte (OK) ; trait `.isSelected` présent (OK) | — |
| `CreateFlow.swift:604-607` | Tuile de widget : `accessibilityValue` « Choisi »/refus : bon | — |

À garder : `OnboardingOffer` (`.accessibilityIdentifier` + `.contain`), `CreateFlow` (en-têtes `.isHeader`, labels de retour), `StudioRoundButton` (label), `PremiumLockCard` (44 pt).

### 2.3 Dynamic Type

Les tailles fixes `.system(size:)` sont surtout des icônes SF (acceptable, à garder). Textes à tailles fixes :

| Fichier:ligne | Texte | Gravité |
|---|---|---|
| `StoreMagazine.swift:72, 355, 578` | Titres de la carte « Écran d'accueil de la semaine » (34 pt), de couverture de collection (30 pt) et de saison (26 pt) : ne grossissent pas | M |
| `StoreMagazine.swift:105` | `.frame(height: 360)` fixe sur la carte héros + `clipShape` : aux grandes tailles (AX1+) le texte (étiquette, titre, accroche, nombre de widgets, bouton « Installer ») dépasse et est coupé | F |
| `DailySection.swift:692, 699` | « kcal restantes / en trop » en `.system(size: 10)` : trop petit, ne grossit pas | M |
| `MyInfoCenter.swift:139` | « À compléter » en `.system(size: 10)` | M |
| `StudioComponents.swift:130-135` | Légende de section en `.caption2` limitée à 1 ligne + `minimumScaleFactor(0.8)` : « Hintergrund », « Meine Stile » tronquent aux grandes tailles | M |
| `CreateFlow.swift:737, 764` | Icônes d'emplacement 15 à 17 pt : acceptable (icônes) | m |
| `OnboardingOffer.swift:119` | Largeur fixe 124 pt des widgets de la vitrine (zone masquée à VoiceOver) : OK | m |
| `OnboardingOffer.swift:223, 229` | `minimumScaleFactor` sur le prix : bon ; les cartes d'offre tiennent côte à côte seulement aux tailles standards : à AX3, passer en pile verticale | M |

### 2.4 Contraste et modes

| Fichier:ligne | Problème | Gravité |
|---|---|---|
| `CreateFlow.swift:751-754` | Pastille du numéro d'emplacement : `.foregroundStyle(.white)` sur `Color.primary` : en mode sombre `primary` est blanc, donc chiffre blanc sur blanc (invisible) | F |
| `CreateFlow.swift:596` | Numéro `.white` sur `Color.accentColor` : l'accent change avec le style (certains clairs) ; utiliser `.onAccent` comme ailleurs | M |
| `OnboardingView.swift:322` et `ExploreView.swift:266, 893` | Icône `.white` sur couleur de catégorie (`Color(hex:)`) : à vérifier sur les teintes claires (jaune, citron) | M |
| `StoreMagazine.swift:353, 359, 362, 582` | Textes `.white.opacity(0.8 à 0.9)` sur dégradé de collection/saison : contraste non garanti sur les couleurs claires ; relever à 1,0 ou vérifier chaque dégradé | M |
| `OnboardingOffer.swift:109`, `:276` | « Plus tard », « Restaurer », liens légaux en `.secondary` : correct en clair, léger en sombre sur `cristalScreen` | m |
| `MyInfoCenter.swift:140` | `8A4B00` / `F5B25A` : couleurs codées en dur mais appariées clair/sombre (bon) | — |
| `UIComponents.swift:144-145` | `premiumInk` / `premiumFill` : paires clair/sombre (bon) | — |

Réduire les animations : `LaunchView` et `ArdaneMark` respectent `accessibilityReduceMotion` ; l'écran d'offre (`.spring` + `.move`), `CreateFlow.go` (`withAnimation`) et le tutoriel n'ont pas de variante réduite (à vérifier dans `OnboardingView.swift:61, 82` : transitions `.move` toujours actives). Gravité M.

---

## 3. Traductions (en, es, de, it, pt-BR, ja)

Méthode : 609 clés `tr("…")` extraites de 21 fichiers (Premium, onboarding, Créer, Studio, Store, tutoriel) et comparées au catalogue. Résultats : 0 clé manquante, 0 écart de nombre de `%@` (les `%1$@` sont corrects), 0 phrase restée en français (les 34 alertes de mots français ressortaient des mots italiens/espagnols « la, le, per »). Restent des écarts de vocabulaire et de longueur.

### 3.1 Vocabulaire hors glossaire (`l10n/GLOSSARY.md`)

| Clé | Langue | Valeur actuelle | Problème | Correction | Gravité |
|---|---|---|---|---|---|
| « miniapp » (glossaire es/pt-BR) | es | 1 chaîne « mini-apps » (« …todas las mini-apps se benefician ») | glossaire : `miniapp` (9 occurrences l'appliquent) | `miniapps` | m |
| idem | pt-BR | 2 chaînes avec « mini-app(s) » (dont « todos os mini-apps aproveitam ») | idem | `miniapps` | m |
| `Planning est déjà sur ton accueil…` | de | « …auf deinem Startbildschirm » | glossaire : `Home-Bildschirm` (34 occurrences) ; 1 seule en « Startbildschirm » | « Home-Bildschirm » | m |
| `Planning est déjà sur ton accueil…` | pt-BR | « sua tela inicial » | glossaire : `Tela de Início` | « sua Tela de Início » | m |
| `Tes styles apparaîtront ici…` | pt-BR | « a tela inicial » | idem | « a Tela de Início » | m |
| idem + `Planning est déjà…` | en | « home screen » | glossaire : `Home Screen` (33 occurrences ailleurs) | « Home Screen » | m |
| `Écran d'accueil\nde la semaine` (clé avec saut de ligne) et `Écran d'accueil de la semaine : %@. %@` | es | « Pantalla de inicio de la semana » | glossaire : `pantalla de inicio` en minuscule dans une phrase | minuscule hors début de phrase (cosmétique) | m |
| `La police change tout le texte…` | es | « pantalla de bloqueo » | glossaire : `pantalla bloqueada` | « pantalla bloqueada » | m |
| `Daily` | en | « Daily routine » (clé « Routine du jour ») | glossaire : `Mon Quotidien` = My Day (ici seulement un nom de routine : à garder) | rien à faire | — |
| `La place de %@ icônes` | de | « Braucht den Platz von %@ Symbolen » | maladroit (« Symbole » est ambigu : icônes d'app) ; 33 caractères pour une ligne `.caption` | « Entspricht %@ App-Symbolen » (28) | M |
| `Mes widgets` (guide) | de/es/it/pt-BR | `Meine Widgets` etc. | le guide cite le nom de la galerie iOS (`QuickWidget.swift:17`, `tr("Mes widgets")`) : cohérent, car la même clé est utilisée | OK | — |

### 3.2 Incohérences internes

| Clé | Langue | Problème | Correction | Gravité |
|---|---|---|---|---|
| `Retour en arrière` / `Annuler` | it | Annuler = « Annulla » et Retour en arrière = « Annulla » : deux boutons homonymes dans la barre du Studio | « Annulla modifica » pour l'icône (ou « Indietro ») | m |
| `Enregistrer le widget` / `Enregistrer les %@ widgets` | de | « Widget sichern » alors que `Enregistrer` = « Speichern » | « Widget speichern », « %@ Widgets speichern », « Freischalten und speichern » | M |
| `Personnaliser le widget` | de | « Widget gestalten » (le Studio parle d'« anpassen ») | « Widget anpassen » | m |
| `Voir tout` / `Tout voir` | it | « Vedi tutto » / « Mostra tutto » pour deux clés qui s'affichent ensemble | un seul : « Mostra tutto » | m |
| `Compris` | it / ja | it « Ok », ja « OK » : bouton principal du guide sans verbe | it « Ho capito » ; ja OK correct | m |
| `Essayer %@ jours gratuits` | toutes | pas de pluriel : « Try 1 days free » si l'essai est à 1 jour | utiliser `Fmt.plural` ou clé sans nombre | m |
| `jour gratuit` / `jours gratuits` | ja | « 日間無料 » précédé d'un espace par `Fmt.plural` (« 7 日間無料 ») | prévoir un cas sans espace en ja | m |

### 3.3 Textes trop longs pour leur place

Ratio calculé sur les libellés de 22 caractères ou moins. Seuls les cas posant un risque d'affichage sont gardés.

| Clé | Langue | Valeur | Place | Correction | Gravité |
|---|---|---|---|---|---|
| `La place de %@ icônes` | de | 33 car. | légende `.caption` de la carte de taille | voir 3.1 | M |
| `Restauration…` | de | « Wird wiederhergestellt… » (23) | barre de l'offre, côte à côte avec « Plus tard » | « Stelle wieder her… » (20) ou icône de chargement seule | m |
| `Tout change d'un coup` | de | « Alles ändert sich auf einmal » (28) | Studio, bandeau de style | « Alles auf einmal » (16) | m |
| `Fonds et polices` | de | « Hintergründe und Schriften » (26) | liste d'avantages Premium | « Hintergründe, Schriften » | m |
| `Importer mon horaire` | de | « Meinen Stundenplan importieren » (30) | titre de paywall (`.title` centré, multiligne OK) | « Stundenplan importieren » | m |
| `L'accueil « %@ »` | de | « Der Home-Bildschirm „%@“ » (24) | titre de paywall | OK si multiligne ; sinon « Home-Bildschirm „%@“ » | m |
| `Sur mon écran` | de/it | « Auf meinem Bildschirm » / « Sulla mia schermata » | étiquette VoiceOver du bouton œil (non visible) | OK | — |
| `Aucun écran` | de | « Keine Bildschirme » | « Bildschirme » ici veut dire « configurations d'accueil » | « Keine Home-Bildschirme » | m |
| Légendes de la barre de sections Studio (`Hintergrund`, `Meine Stile`, `Bordure`→`Rahmen`) | de | 11 caractères | `.caption2`, 1 ligne, `minimumScaleFactor(0.8)`, `minWidth: 68` | tolérable à la taille standard ; voir 2.3 pour les grandes tailles | M |

Les 4 phrases d'achat (`Les abonnements se renouvellent…`, `%@. Rien n'est débité pendant l'essai…`) sont longues mais en `.caption` multiligne (`fixedSize(horizontal: false)`) : pas de coupure. Les traductions it/es utilisent bien `%1$@ … %2$@`.

### 3.4 Formats suspects

- `OnboardingOffer.swift:206` : `Text(verbatim: "−\(savings) %")` : espace avant `%` seulement correct en fr/de/es (fr, de, es utilisent l'espace) ; en/it/pt-BR/ja devraient être « −50% ». Gravité m.
- `Étape %@ sur %@` (it : « Passo %@ di %@ », ja : « ステップ %@ / %@ ») : OK.
- `+ %@ styles` : en « + %@ styles » (identique au français) ; ja « + %@種類のスタイル » (long pour un badge `.footnote` : « +%@スタイル »). m.
- 85 chaînes identiques au français : toutes légitimes (Premium, Studio, Ardane, Packs, widget, Garage, Cosmos…) sauf à vérifier `Grandes` (es/pt-BR : « Grandes » existe aussi en espagnol, mais pas en portugais : « Grandes » pt-BR est correct) ; rien d'oublié.
- Clés avec pluriel : `Collection %@, %@ widgets` et `Pack %@, %@ widgets. %@` (labels VoiceOver) ne passent pas par `Fmt.plural` : « 1 widgets ». m.

### 3.5 Texte français source à corriger

`CreateFlow.swift:790` et `SpaceBuilderView.swift:275` (« Atelier » pour « Studio »). C'est une clé française : à changer dans le code puis à retraduire (`l10n_catalog.py extract`). Gravité M.

---

## Résumé (10 lignes)

1. Aucun point bloquant App Store détecté ; la règle 3.1.2 est respectée dans l'offre (conditions sous le bouton), mais les liens légaux sont trop petits à toucher (F).
2. Premier widget : 12 à 19 touchers et ~15 écrans dans l'app (30 en parcours complet), puis 7-8 gestes iOS ; la valeur arrive après les questions, l'offre Premium et un tutoriel de 8 étapes.
3. Le meilleur gain : une carte « Crée ton premier widget » juste après l'onboarding, tutoriel facultatif.
4. Le guide d'ajout est texte seul et ses étapes 4-5 sont confuses.
5. Une vraie erreur de contraste : numéro blanc sur `Color.primary` (blanc en mode sombre), `CreateFlow.swift:751`.
6. Cibles < 44 pt : « Restaurer », « Plus tard », liens légaux, « Tout voir » du Store (le cadre de 44 pt est posé sur le conteneur, pas sur les boutons).
7. La carte héros du Store (`frame(height: 360)` fixe) se coupe aux grandes tailles de texte ; titres 34/30/26 pt fixes.
8. VoiceOver : icônes décoratives non masquées (coches de l'offre, `StepTitle`, `AddStepRow`), étapes du guide en deux éléments.
9. Traductions : 609 clés contrôlées, 0 manquante, 0 format cassé ; écarts de vocabulaire (de « sichern » vs « speichern », « Startbildschirm », es/pt « mini-app », « Atelier » côté source) et une ligne allemande trop longue.
10. Réduire les animations : l'écran de lancement le respecte, pas l'onboarding ni Créer.

## Les 10 corrections les plus rentables à coder

1. `CreateFlow.swift:751` : remplacer `.white` par `Color.screenFill`/`.onAccent` selon fond (chiffre invisible en sombre).
2. `OnboardingOffer.swift:88-112, 272-277` : poser `.frame(minWidth: 44, minHeight: 44)` + `contentShape` sur chaque `Button`.
3. `ExploreView.swift:328-337, 907-914` : « Tout voir » avec cible 44 pt (même correction).
4. `StoreMagazine.swift:105` : remplacer `.frame(height: 360)` par `.frame(minHeight: 360)` et passer les titres 34/30/26 pt en `.largeTitle`/`.title` avec `@ScaledMetric`.
5. Carte « Crée ton premier widget » après l'onboarding (`ArdaneApp.swift:154`, Accueil) ; tutoriel reporté ou facultatif.
6. `CreateFlow.swift:790` et `SpaceBuilderView.swift:275` : « Atelier » devient « Studio » ; retraduire les 2 clés.
7. `OnboardingOffer.swift:157`, `OnboardingView.swift:318, 403` : `.accessibilityHidden(true)` sur les icônes décoratives ; `AddStepRow` en `.accessibilityElement(children: .combine)`.
8. Catalogue de.xcstrings : « Widget sichern » en « Widget speichern » (3 clés), « La place de %@ icônes » en « Entspricht %@ App-Symbolen », « Startbildschirm » en « Home-Bildschirm ».
9. `DailySection.swift:692, 699` et `MyInfoCenter.swift:139` : `.font(.system(size: 10))` en `.caption2` (suit Dynamic Type).
10. `OnboardingOffer.swift:254, 206` : `Fmt.plural` pour « Essayer N jours gratuits » et format localisé pour « −N % » ; pour `OnboardingView.swift:61, 82` et `CreateFlow.go` : variante sans mouvement avec `accessibilityReduceMotion`.

## Textes nouveaux

Aucun texte créé par cet audit. Si les corrections 5, 6 et 8 sont faites : « Crée ton premier widget » (nouveau, à traduire), « Touche un widget : le Studio s'ouvre aussitôt. » et la variante de `SpaceBuilderView` (clés françaises modifiées, à retraduire), et trois valeurs allemandes à changer dans le catalogue.

## Non vérifié

Rendu réel (aucune capture), contraste calculé des dégradés du Store, comportement exact des animations avec « Réduire les animations », widgets en mode Clair/Teinté (hors périmètre de cet audit), chemins iOS 17 vs 18 du guide d'ajout.
