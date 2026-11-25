# Audit : Photos et citations

Relevé fait dans le code le 2026-11-17 (branche `main`, commit `0c3409e`). Lecture seule. Chaque ligne porte sa preuve (fichier:ligne ou nom de la vue). Ce qui n'a pas pu être prouvé est marqué « à vérifier ». Fichier principal : `App/Screens/MiniApps/Photos/PhotoQuotesApp.swift` (696 lignes, lu en entier, abrégé « PQA »). Autres fichiers lus en entier : `Shared/Model/PhotoQuote.swift` (abrégé « PQ »), `Shared/Render/Kinds/PhotoQuoteWidgets.swift` (abrégé « PQW »), `Shared/Support/SafeImage.swift`. Il n'y a aucun fichier photos ou citations dans `Shared/Domains` (les « quotes » qu'on y trouve sont des cours de bourse, hors sujet).

## 1. En bref

- Sert à fabriquer des widgets d'écran d'accueil faits de TES photos (1 à 12, 4 visibles à la fois) ou d'UNE citation (texte, auteur, typographie, couleurs, photo de fond). Ce n'est ni une galerie ni un journal.
- Pour qui : tout le monde. Mini-app `MiniApp.photos`, titre « Photos et citations », couleur `D9608B` (`App/Screens/MiniApps/MiniApp.swift:19`, `:33`, `:47`), vue `PhotoQuotesAppView` (`MiniApp.swift:161-162`).
- Fréquence : ponctuelle. On crée un widget, on y revient rarement. Rien n'est daté, aucun rappel.
- État : petite et stable. Une page, un éditeur, un recadrage. Tout est gratuit et illimité (`App/Core/AppModel.swift:250-254`).
- Elle est exclue de Mon quotidien (`App/Core/DailyCategories.swift:8-9`).

## 2. Écrans et navigation

| # | Écran ou feuille | Vue SwiftUI, fichier:ligne | Comment on y arrive | Ce qu'on y fait |
|---|---|---|---|---|
| E1 | Page « Photos et citations » (écran principal) | `PhotoQuotesAppView`, PQA:9 | Accueil › « Mes mini-apps » › puce (`App/Screens/Home/MiniAppsRow.swift:160-164`, id `mini-app-photos`) ; ou feuille « Mini-apps » › ligne (`AllMiniAppsSheet`, `MiniAppsRow.swift:205`, id `all-apps-photos`) ; `router.openApp(.photos)` (`App/Core/Router.swift:121-128`) | Voir ses widgets, en créer un (Photos ou Citation), ouvrir un widget pour le modifier. |
| E2 | Feuille « Widget photo » / « Widget citation » (éditeur) | `PhotoQuoteEditor`, PQA:127 (titre PQA:187). Feuille posée à trois endroits : PQA:82, `App/ArdaneApp.swift:114-116`, `App/Screens/Spaces/CreateFlow.swift:216-218` | a) E1 : « Photos », « Citation », tuile « + » (par E7), ou une tuile de widget. b) Onglet Créer › taille › catégorie « Photos et citations » › E8. c) Mes widgets : toucher un widget Photos ou Citation, « Modifier », « Créer une variante » (`App/Screens/MyWidgets/MyWidgetsView.swift:243`, `:292-294`, `:315-322`, `:544` → `router.openEditor`, `Router.swift:130-137`). d) Toucher le widget posé : lien `tessera://design/<id>` (`Shared/Render/WidgetCanvas.swift:185`, `Shared/Support/DeepLink.swift:5`). | Taille, photos ou citation, nom, supprimer, « Annuler », « Enregistrer ». |
| E3 | Feuille « Recadrer » | `PhotoFramingView`, PQA:588 ; posée PQA:199-205 | E2 : toucher une vignette (PQA:328-330), menu « Recadrer » (PQA:345), ou, pour une citation, la vignette de la photo de fond ou « Recadrer » (PQA:488-503) | Glisser pour déplacer, pincer ou curseur « Zoom » (1 à 4), « Réinitialiser », « Annuler », « OK ». Fond noir. Cadre aux proportions réelles de la case du widget (PQA:598-606). Pour une photo hors des 4 visibles à cet instant, la case prise est la première (repli `?? 0`, PQA:601). La feuille se ferme aussi d'un balayage, sans garder le recadrage. |
| E4 | Sélecteur de photos d'Apple (système) | `PhotosPicker`, PQA:289 (photos), PQA:504 et PQA:524 (fond d'une citation) | E2 : « Choisir des photos » / « Ajouter des photos » ; « Choisir une photo » ; « Changer de photo » | Choisir des images. Aucun accès à la photothèque n'est demandé (PQA:5-8, texte PQA:23). |
| E5 | Dialogue « Supprimer ce widget ? » | `confirmationDialog`, PQA:206-216 | E2, widget déjà enregistré seulement : bouton « Supprimer ce widget » (PQA:173-181) | « Supprimer ». Message : « Il disparaîtra de ton écran d'accueil. Les photos de ta photothèque ne sont pas touchées. » |
| E6 | Menu d'une vignette (appui long) | `contextMenu`, PQA:344-357 | E2, étape « Les photos » : appui long sur une vignette | « Recadrer », « Avancer », « Reculer », « Retirer ». |
| E7 | Dialogue « Nouveau widget » | `confirmationDialog`, PQA:86-90 | E1 : tuile « + » en fin de grille (PQA:64-76, id `photos-add`). Visible seulement s'il existe déjà un widget. | « Photos », « Citation », « Annuler ». |
| E8 | Dialogue « Créer un widget » (onglet Créer) | `CreateFlowView`, `CreateFlow.swift:212-215` ; toucher de la catégorie `CreateFlow.swift:228-229` ; carte comptée « 2 » en dur (`:449`) | Onglet Créer › taille › « Photos et citations » (dernière catégorie, `CreateFlow.swift:40`) | « Photos », « Citation », puis E2 (`startPhotoQuote`, `CreateFlow.swift:259-265`). |
| E9 | Feuille Premium « Plus de 3 widgets » | `PaywallView`, PQA:85 ; `PaywallContext.designLimit` (`App/Premium/PaywallContext.swift:38-44`) | `start()`, PQA:93-101, si `canSave` refuse | Voir l'offre. **Non atteinte dans les faits** : un widget Photos ou Citation ne compte pas, donc `fitsFreePlan` accepte toujours (`AppModel.swift:252-265`). |
| E10 | Feuille guide « Ajouter à l'écran d'accueil » | `AddToHomeScreenGuide`, `ArdaneApp.swift:127-129` | Mes widgets seulement : « Ajouter à l'écran » d'un widget (`MyWidgetsView.swift:304-311`) ou le « ? » de la barre (`:127-131`) | Lire comment poser le widget. **Absent de la mini-app** : E1 n'a qu'une phrase (PQA:79). |

Points d'entrée et faux amis (ce ne sont pas des écrans de la mini-app) :

| Élément | Où | Ce qu'il fait |
|---|---|---|
| Puce de l'accueil | `MiniAppsRow.swift:160-172`, légende `:107-109`, dessin `:185-202` | Titre, légende « N widget(s) photo ou citation » ou « Ouvrir ». Appui long : « Masquer de l'accueil ». Visible dans « Mes mini-apps » si la personne a déjà un tel widget ou l'intérêt « design » (`:45`, `:59`), sinon sous « À découvrir ». |
| Fiches « Photos » et « Citation » du catalogue | `Shared/Model/KindCatalog.swift:271-273`, catégorie `.memories` | Jamais proposées dans le catalogue : `WidgetKind.offered` les exclut (`Shared/Model/WidgetKind.swift:150`). Elles ne servent qu'aux titres et aux mots-clés. |
| Modèle « Citation » du catalogue | `Shared/Model/Templates.swift:96` (`note-quote`) | C'est un widget **Note** au style typographique, pas un widget Citation. À ne pas confondre. |
| App « Photos » des maquettes d'accueil | `App/Screens/Explore/HomeSetups.swift:396` | Icône de l'app système d'iOS. Sans lien. |
| Photo de fond du Studio | `App/Screens/Editor/EditorView.swift` (`StudioPhotoSession`) | Fond photo d'un widget quelconque : option **Premium** (`PaywallView.swift:169`). Autre fonction, mais même magasin `ImageStore`. |
| Photos de plats (Nutrition), photo d'horaire (Planning) | `MealPhotoAnalysis.swift`, `ScheduleImportView.swift` | Autres mini-apps. Sans lien. |

## 3. Écran principal : sections dans l'ordre actuel

Écran principal = E1 (PQA:18-91), bâti sur `MiniAppScaffold` (`App/Screens/MiniApps/MiniAppScaffold.swift:30`). Pas de sélecteur de semaine (rien n'est daté, PQA:21). Pas de bouton flottant, pas de menu dans la barre.

1. **Titre de navigation** : « Photos et citations » (PQA:81).
2. **Bandeau** (`MiniHero`, PQA:22-23) : petit libellé « Tes widgets photo », grande valeur « 0 widget » / « 3 widgets », légende « Seules les photos que tu choisis sont copiées dans Ardane : aucun accès à ta photothèque n'est demandé. »
3. **Deux boutons côte à côte** (PQA:26-35) : « Photos » (plein, id `photos-new`) et « Citation » (secondaire, id `quote-new`).
4. **Titre de section** « Mes widgets » (PQA:37).
5. **Contenu de la section** :
   - Vide : un seul texte dans une carte, « Une photo, deux, trois ou quatre, ou une citation : ton premier widget se crée en deux étapes. » (PQA:38-42).
   - Sinon : grille de 2 colonnes (PQA:44). Une tuile par widget : aperçu réel (`WidgetPreview`), nom, puis « Photos · Petit » (type · taille) ; id `photos-widget`. Ordre : du plus récemment utilisé au plus ancien (`photoQuoteDesigns`, PQA:106). Dernière tuile : « + » (étiquette « Nouveau widget », id `photos-add`).
6. **Note de pied** (PQA:79) : « Pour le poser : touche longuement l'écran d'accueil, puis + › Ardane › « Mes widgets », et choisis-le avec « Modifier le widget ». »

Éditeur E2, dans l'ordre (PQA:156-182) : aperçu du widget (200 pt de large au plus en Petit, id `photos-preview`) › étape 1 « La taille » › étape 2 « Les photos » ou « La citation » › étape 3 « Le nom » › « Supprimer ce widget » (widget déjà enregistré seulement). Barre : « Annuler », « Enregistrer ».

Étape « Les photos » (PQA:286-325) : bouton plein « Choisir des photos » / « Ajouter des photos » › « Préparation des photos… » › « N photo(s) illisible(s) » › une phrase d'aide qui change selon le nombre › rangée horizontale de vignettes de 72 pt, numérotées.

Étape « La citation » (PQA:404-473) : champ « Ta citation » › champ « Auteur (facultatif) » › « Typographie » (4 choix) › « Couleurs » (8 paires « Aa ») › sélecteurs « Fond » et « Texte » › « Photo de fond » › interrupteurs « Centrée » et « Guillemets » › lien « Essayer avec un exemple » (seulement si le texte est vide).

## 4. Fonctions existantes

Liste de référence : aucune planche ne doit en perdre une. Tout est gratuit : **0 fonction Premium**.

| # | Fonction | Où elle est | Gratuit ou Premium | Données affichées | Actions possibles |
|---|---|---|---|---|---|
| F1 | Créer un widget Photos | E1 « Photos » (PQA:27), E7, E8 | Gratuit, illimité | Aperçu en direct | Ouvre E2 avec un widget Petit nommé « Mes photos » (PQA:117-122) |
| F2 | Créer un widget Citation | E1 « Citation » (PQA:31), E7, E8 | Gratuit, illimité | Aperçu en direct | Ouvre E2 avec un widget Petit nommé « Ma citation », citation vide (PQA:119-120) |
| F3 | Grille « Mes widgets » | E1 (PQA:44-62) | Gratuit | Aperçu réel, nom, type · taille ; tri par dernier usage | Toucher une tuile : ouvre E2 |
| F4 | Compteur de widgets | Bandeau de E1 (PQA:22) ; puce de l'accueil (`MiniAppsRow.swift:107-109`) | Gratuit | Nombre de widgets Photos et Citation | Aucune |
| F5 | Choisir la taille | E2 étape 1 (`sizePicker`, PQA:254-282) | Gratuit | 3 cadres aux proportions réelles, choix encadré | « Petit », « Moyen », « Grand » ; l'aperçu suit. Modifiable aussi après coup. |
| F6 | Choisir des photos | E2 (`photosStep`, PQA:286-297) + E4 ; chargement `load`, PQA:373-396 | Gratuit, 12 au plus (`PhotoLayout.maxPhotos`, PQ:141) | Vignettes numérotées ; « Préparation des photos… » ; nombre d'illisibles | Ajouter jusqu'à 12 ; chaque photo est copiée et réduite (décodée à 2 400 px, gardée à 1 200 px, PQA:378-379) ; vibration de réussite |
| F7 | Mise en page automatique | `PhotoLayout.cells`, PQ:161-183 ; rendu `PhotoCollageView`, PQW:9-43 | Gratuit | 1 : plein cadre ; 2 : côte à côte (Grand : l'une sur l'autre) ; 3 : une grande et deux petites ; 4 : grille 2 × 2 | Aucune (suit le nombre de photos et la taille) |
| F8 | Rotation au-delà de 4 photos | `PhotoLayout.visible`, PQ:145-150 ; texte d'aide PQA:308-309 | Gratuit | « Plus de 4 photos : le widget en montre 4 à la fois, puis les suivantes chaque heure. » | Aucune (pas réglable) |
| F9 | Recadrer une photo | E3 (PQA:588-696) | Gratuit | Photo dans sa case, curseur « Zoom » | Glisser, pincer, curseur 1 à 4, « Réinitialiser », « Annuler », « OK » |
| F10 | Ordre et retrait des photos | E6 (PQA:344-357 ; `move`, PQA:363-369) | Gratuit | Numéro sur chaque vignette | « Avancer », « Reculer », « Retirer » |
| F11 | Écrire la citation | E2 (PQA:407-415) | Gratuit | Aperçu en direct ; « Ta citation ici » tant que c'est vide (PQW:203) | Texte (280 caractères au plus, 3 à 8 lignes), auteur facultatif (affiché « — Auteur », PQW:209-215) |
| F12 | Typographie de la citation | PQA:416-420 ; `QuoteFont`, PQ:50-62 | Gratuit | 4 choix | « Serif » (italique), « Arrondie », « Standard », « Mono » |
| F13 | Couleurs de la citation | PQA:421-453 ; `QuotePalette.all`, PQ:71-80 | Gratuit | 8 paires : « Papier », « Nuit », « Corail », « Océan », « Forêt », « Rose », « Sable », « Lilas » ; paire choisie encadrée | Choisir une paire ; « Fond » et « Texte » en couleur libre (`ColorPicker`) |
| F14 | Photo de fond d'une citation | `backgroundSection`, PQA:477-544 | Gratuit, 1 photo | Vignette aux proportions du widget ; curseur « Voile pour la lisibilité » (0,15 à 0,75, PQ:123) ; phrase d'aide (PQA:519) | « Choisir une photo », « Recadrer », « Changer de photo », « Retirer » |
| F15 | Options de la citation | PQA:455-458 | Gratuit | 2 interrupteurs | « Centrée », « Guillemets » |
| F16 | Exemple de citation | PQA:459-470 ; `QuoteContent.sample`, PQ:133 | Gratuit | Une seule citation (Saint-Exupéry) | « Essayer avec un exemple » (texte vide seulement ; garde typographie, couleurs et voile) |
| F17 | Nommer le widget | E2 étape 3 (PQA:167-172) | Gratuit | Champ « Nom du widget » | Saisir ; nom vide = « Photos » ou « Citation » à l'enregistrement (PQA:561) |
| F18 | Aperçu en direct | `WidgetPreview`, PQA:157 | Gratuit | Le widget tel qu'il sera posé | Aucune (l'aperçu ne se touche pas) |
| F19 | Enregistrer / Annuler | PQA:189-198, `save` PQA:559-576, `cancel` PQA:578-584 | Gratuit | « Enregistrer » grisé sans photo ou sans texte (PQA:230-236) | Enregistre, efface les copies devenues inutiles, vibration, célébration à la création (`model.celebrate()`) |
| F20 | Supprimer un widget | E5 (PQA:173-181, 206-216) | Gratuit | Confirmation | Efface le widget et ses copies de photos (`AppModel.swift:332-338`) |
| F21 | Aide pour poser le widget | Note de pied PQA:79 | Gratuit | Une phrase | Aucune |
| F22 | Photo disparue | `PhotoCell`, PQW:46-56 ; citation PQW:163-165 | Gratuit | « Photo indisponible » dans la case ; la citation reprend ses deux couleurs | Aucune |
| F23 | Modes Clair et Teinté d'iOS | PQW:41, PQW:85-94, PQW:130-132, PQW:160-161 | Gratuit | Photos gardées en couleur ; photo sous une citation désaturée et pâle, sans voile | Aucune |
| F24 | Renouvellement du widget posé | `Widgets/DesignProvider.swift:88-94` | Gratuit | Plus de 4 photos : l'instant présent puis 6 heures pleines ; sinon aucun renouvellement (`.never`) ; citation : jamais | Aucune |
| F25 | Toucher le widget posé | `WidgetCanvas.swift:185` ; `Router.swift:130-134` | Gratuit | — | Ouvre E2 sur ce widget |
| F26 | Actions de Mes widgets sur ces widgets | `MyWidgetsView.swift:290-312` (boutons) et `:542-569` (menu) | Gratuit | Cœur plein ou vide | « Modifier » (E2), « Dupliquer », « Créer une variante » (copie puis E2), « Favori », « Ajouter à l'écran » (E10), « Supprimer ». Une copie reçoit ses propres fichiers photo (`AppModel.duplicate`, `AppModel.swift:353-372`). Hors de la mini-app. |
| F27 | Fusionner deux widgets Photos ou Citation | Mes widgets › « Sélectionner » › « Fusionner » (`MyWidgetsView.swift:121`, `:401`) ; règle `Fusion.result`, `Shared/Model/Combo.swift:113-132` | Gratuit (une fusion de photos et citations ne compte pas, `AppModel.swift:253`) | — | La règle l'autorise (même catégorie `.memories`). **Rendu à vérifier sur l'iPhone** : voir § 8, point 18. Hors de la mini-app. |

## 5. Données et calculs (à ne pas modifier)

**Pas de modèle propre à la mini-app.** Un widget Photos ou Citation est un `WidgetDesign` de genre `.photos` ou `.quote` (`WidgetKind.swift:113` ; `isMadeInItsMiniApp`, PQ:207-212). La liste de E1 = `recentDesigns` filtrée (PQA:106), triée par `lastUsedAt ?? updatedAt` (`AppModel.swift:288-290`).

Ce qui est saisi :

- `PhotoSlot` (PQ:11-47) : `id`, `file` (nom du fichier dans `ImageStore`), `centerX`, `centerY` (0 à 1), `zoom` (1 à 4). Rangé dans `options.photos` (`Shared/Model/DesignOptions.swift:69`).
- `QuoteContent` (PQ:84-134) : `text`, `author`, `font` (serif par défaut), `backgroundHex` (« F6F0E6 »), `textHex` (« 2B2622 »), `isCentered` (oui), `showsMarks` (oui), `photoVeil` (0,4). Rangé dans `options.quote` (`DesignOptions.swift:71`). Lecture tolérante aux champs absents (PQ:104-115).
- `WidgetDesign.name`, `WidgetDesign.format` (Petit, Moyen, Grand : `WidgetFormat`, `Combo.swift:5-24`).

Ce qui est calculé :

- `PhotoLayout.capacity = 4`, `maxPhotos = 12` (PQ:139-141).
- `PhotoLayout.visible` (PQ:145-150) : départ = (heure Unix × 4) modulo le nombre de photos. Mêmes photos pendant toute l'heure, sur tous les widgets.
- `PhotoLayout.nextChange` (PQ:153-157) : prochaine heure pleine, ou rien à 4 photos ou moins.
- `PhotoLayout.cells` (PQ:161-183) : cases selon le nombre et la taille. `PhotoLayout.frame` (PQ:187-198) : cadrage sans jamais montrer de bord vide.
- Photo de fond d'une citation = la 1re de `options.photos` (`quoteBackground`, PQ:204 ; décision du 2026-10-15, `docs/memoire/Decisions.md:58`). La suppression, la copie et la sauvegarde en dépendent.
- Couleur du texte sur une photo (`inkOnPhotoHex`, PQ:128-131) : la couleur choisie si elle est claire (luminance ≥ 0,6), sinon blanc.
- Taille du texte d'une citation selon sa longueur et la taille du widget (PQW:134-141) ; voile en dégradé, plus sombre en bas (PQW:183-188) ; ombre douce sur photo (PQW:220).
- Image lue à la taille dessinée (× 3, × zoom), pour la mémoire du widget (PQW:59-66).

Fichiers et sécurité :

- `ImageStore` (`Shared/Support/SharedStore.swift:269-327`) : dossier `Tessera/Images` de l'App Group, JPEG qualité 0,82, nom = UUID + « .jpg » donné par le magasin (`isStoredName`, `:323-325`).
- `SafeImage` (`Shared/Support/SafeImage.swift`) : refuse une image illisible ou de plus de 64 mégapixels (`:11`), décode en vignette bornée (`:36-48`).
- Nettoyage : « Annuler » efface les copies faites pendant l'édition (PQA:578-584) ; « Enregistrer » efface les photos retirées (PQA:567-572) ; la suppression efface les fichiers que plus aucun widget n'utilise (`AppModel.swift:325-338`). E2 ne se ferme pas d'un balayage pendant un chargement ou tant qu'il reste des copies non enregistrées (PQA:227).
- Sauvegarde et restauration : les photos des widgets sont incluses (`App/Core/DataBackup.swift:110-114`).

Règle du gratuit : `countsTowardFreeLimit` (`AppModel.swift:252-254`), `freeDesignLimit` = 3 (`AppModel.swift:11`).

Tests logiques existants : `Tests/PhotoQuoteBackgroundTests.swift`, `Tests/SafeImageTests.swift`, `Tests/BackupOrphanPhotosTests.swift`, `Tests/FreeWidgetLimitTests.swift`, `Tests/OctoberRequestsTests.swift:222-232`, `Tests/CreateFlowTests.swift:77-98`, `Tests/MiniAppToFillTests.swift:53-54`.

## 6. Liens

- **Carte de Mon quotidien** : AUCUNE. Photos est retirée des choix (`DailyCategories.swift:8-9`) et n'a pas d'espace de brief (`App/Core/DailyBrief.swift:165`). Contenu et taille : sans objet.
- **Accueil** : puce de « Mes mini-apps », 128 × 118 pt plus 12 pt de marge (`MiniAppsRow.swift:198-200`), légende « N widgets photo ou citation » ou « Ouvrir ».
- **Widgets** : ils sont le produit lui-même. Genres `.photos` et `.quote`, tailles Petit, Moyen, Grand. Pas de version d'écran verrouillé (`WidgetCanvas.swift:28-32`, condition `!family.isAccessory`). Dessinés bord à bord, sans marge ni style d'Ardane (PQW:5-6). Le Studio ne les édite pas (`Router.swift:52-53`, `:132-135`).
- **Autres mini-apps** : aucune donnée partagée.
- **Onglet Créer** : catégorie « Photos et citations », en dernier (`CreateFlow.swift:40`, `:47`), couleur `EC4899` (`:63`).
- **Mes widgets** : mêmes widgets, avec les actions F26 et F27 ; bandeau « Photos et citations illimitées » (`MyWidgetsView.swift:364`).
- **Offre Premium** : ligne du tableau comparatif « Photos et citations », ∞ en gratuit comme en Premium (`App/Premium/PaywallView.swift:208`).
- **Notifications et rappels** : aucun.
- **Liens profonds** : aucun lien propre à la mini-app. Seul `tessera://design/<id>` (toucher un widget posé) mène à E2. `MiniApp.photos.space` vaut `nil` (`MiniApp.swift:64`).
- **« Mes informations » et « À remplir »** : vides pour Photos (`App/Screens/MiniApps/MiniAppSettings.swift:27`, `MiniAppToFill.swift:18`).
- **Carte du projet** : `scripts/graph_map.py:187` décrit la mini-app ; `:207` cite une `PhotoQuotesCard` qui n'existe plus dans le code (recherche sans résultat).

## 7. États vides, première utilisation, erreurs, permissions, limites du mode gratuit

- **Première utilisation** : bandeau « 0 widget », les deux boutons, un texte seul (PQA:39). Pas d'exemple visuel, pas de widget d'essai, pas de tutoriel. La tuile « + » et E7 n'existent pas encore. Puce de l'accueil : « Ouvrir ».
- **Éditeur vide** : aperçu « Choisis tes photos dans Ardane » (PQW:21) ou « Ta citation ici » (PQW:203). « Enregistrer » grisé (PQA:230-236).
- **Permissions** : aucune. Le sélecteur d'Apple ne donne que les photos choisies. Pas de caméra, pas de notification.
- **Erreurs** : image illisible ou trop grande → « 1 photo illisible » / « N photos illisibles », petit texte gris avec un triangle (PQA:301-305, 538-542). Pas de « réessayer ». Fichier disparu → « Photo indisponible » (PQW:54). Au-delà de 12, les photos en trop sont ignorées sans message (PQA:389-390).
- **Chargement** : « Préparation des photos… » (PQA:298-300) ; pour une citation, une roue à côté de « Photo de fond » (PQA:482).
- **Limites** : 12 photos par widget (bouton grisé, PQA:296), 4 visibles à la fois, 280 caractères, 1 photo de fond, auteur sur 1 ligne.
- **Mode gratuit** : aucune limite. Nombre de widgets Photos et Citation illimité. La feuille Premium E9 est câblée mais ne s'ouvre pas en pratique.

## 8. Problèmes d'UX constatés aujourd'hui

1. **Deux entrées pour la même action sur le même écran.** Boutons « Photos » / « Citation » (PQA:26-35) et tuile « + » avec dialogue (PQA:64-90). La tuile ajoute un toucher.
2. **Bandeau peu utile.** Sa seule donnée est le nombre de widgets (PQA:22). Son libellé « Tes widgets photo » oublie les citations, pourtant comptées (PQA:106). Sa légende est une règle de confidentialité, répétée mot pour mot dans l'éditeur (PQA:23 et PQA:307).
3. **« Deux étapes » annoncées, trois numérotées.** Texte vide : « se crée en deux étapes » (PQA:39) ; l'éditeur affiche 1, 2, 3 (PQA:161-167).
4. **Nombre de photos contradictoire.** « Une photo, deux, trois ou quatre » (PQA:39) et « Une à quatre de tes photos » (`KindCatalog.swift:272`) ; la réalité est 12, dont 4 visibles (PQ:139-141).
5. **Taille demandée deux fois depuis Créer.** L'onglet Créer fait choisir la taille, puis la catégorie ; pour Photos, la taille choisie n'est pas transmise : le brouillon repart en Petit (`CreateFlow.swift:228-229`, `:259-260` ; `PhotoQuoteDraft.blank`, PQA:117-118) et l'éditeur repose la question (PQA:161).
6. **Aperçu qui sort de l'écran.** L'aperçu est en tête d'un seul long défilement (PQA:155-157). Les réglages de la citation (une dizaine de contrôles, PQA:404-473) se font sans le voir.
7. **Ordre des réglages de la citation.** « Photo de fond » est placée entre les couleurs et les interrupteurs (PQA:454-458) ; or avec une photo, la couleur « Fond » ne sert plus (texte PQA:519) mais reste affichée juste au-dessus.
8. **Ordre et retrait des photos cachés.** « Avancer », « Reculer », « Retirer » ne sont que dans un menu d'appui long (PQA:344-357). La phrase d'aide visible ne parle que du recadrage (PQA:310) ; seul VoiceOver l'annonce (PQA:359). Pas de glisser-déposer.
9. **Rotation horaire peu expliquée.** Une seule phrase, et seulement au-delà de 4 photos (PQA:308-309). Rien ne montre quelles photos passent ensemble. Pas de réglage.
10. **Recadrage d'une photo « en attente ».** Pour une photo hors des 4 visibles à cet instant, le cadre montré est celui de la 1re case (PQA:601), pas forcément celui qu'elle aura.
11. **Recadrage perdu sans avertir.** E3 se ferme d'un balayage sans rien garder (pas de blocage, PQA:608-667), alors que E2 le bloque (PQA:227).
12. **« Annuler » sans confirmation.** Il ferme l'éditeur et efface les copies, même après plusieurs photos choisies et recadrées (PQA:191, 578-584).
13. **Poser le widget : une phrase en bas de page.** Dans la mini-app, la dernière étape est une note de pied (PQA:79). Le guide `AddToHomeScreenGuide` existe mais ne s'ouvre que depuis Mes widgets (`MyWidgetsView.swift:304-311`). « Enregistrer » ne le propose pas (PQA:559-576).
14. **Actions absentes de la mini-app.** « Dupliquer », « Créer une variante », « Favori », « Ajouter à l'écran » existent pour ces widgets, mais seulement dans Mes widgets (`MyWidgetsView.swift:290-312`, `:542-569`). Dans E1, une tuile n'a ni menu ni appui long (PQA:46-61) ; supprimer demande d'ouvrir l'éditeur et d'aller tout en bas (PQA:173-181).
15. **Grille peu lisible pour les grandes tailles.** Chaque tuile occupe une demi-largeur (PQA:44) : un Moyen et un Grand y sont réduits, sans rapport de taille entre eux. La légende est en très petit corps (`caption2`, PQA:55-57).
16. **Deux couleurs pour la même mini-app.** `D9608B` dans la mini-app (`MiniApp.swift:47`) et le catalogue (`WidgetKind.swift:76`), `EC4899` dans Créer (`CreateFlow.swift:63`).
17. **Vocabulaire instable.** « Photos et citations » (PQA:81), « Tes widgets photo » (PQA:22), « Mes widgets » (PQA:37), « Widget photo » (PQA:187), « widget photo ou citation » (`MiniAppsRow.swift:109`), et « Photos, collages, citations » dans une image marketing (`App/Core/MarketingShots.swift:849`) : le mot « collage » n'apparaît nulle part dans l'app.
18. **Fusion de widgets Photos : rendu douteux, à vérifier sur l'iPhone.** La fusion donne un widget combiné de genre `.photos` dont les photos sont dans ses parties (`Combo.swift:137-153`). Or `WidgetCanvas` teste `kind == .photos` (`:28`) avant `isCombo` (`:42`) et dessine `design.options.photos`, vide dans ce cas. Ce combiné apparaîtrait aussi dans la grille de E1 (filtre sur le genre, PQA:106) et s'ouvrirait dans E2 sans ses photos (`Router.swift:132`). Lu dans le code, pas constaté à l'écran.

Fait de vérification (pas un défaut d'écran) : aucun test d'interface n'ouvre cette mini-app et aucune capture CI n'existe (§ 10). L'écran n'est donc jamais contrôlé visuellement par la CI.

## 9. Ce que la mission du PDG cite et qui n'existe pas

`MISSION.md` ne nomme pas Photos : elle relève de la section F, « Autres mini-apps existantes ». Ce que la mission demande pour toutes et qui n'a pas de matière ici :

- **Une place dans Mon quotidien** (section 8 : « Autres mini-apps sélectionnées en Small »). Photos ne peut pas y être choisie (`DailyCategories.swift:8-9`) et n'a aucune carte.
- **Des indicateurs et des graphiques** (section 2, approche « Analytique »). Aucune donnée datée, aucune statistique. Seuls chiffres réels : nombre de widgets, nombre de photos par widget, type, taille, date du dernier usage.
- **Un usage quotidien** (approche « Quotidienne »). Aucune action récurrente, aucun rappel.
- **Une « vue détaillée d'une fonctionnalité importante » et une « vue secondaire »** (section 4). Il n'existe qu'une page, un éditeur et un recadrage. Pas de fiche de widget en lecture seule, pas de bibliothèque.
- **Des fonctions Premium à montrer.** Il n'y en a aucune ici.

Fonctions qui n'existent pas et qu'une planche inventerait : albums ou collections, bibliothèque de citations, citation du jour, citations favorites, rotation réglable, choix manuel de la mise en page, widgets d'écran verrouillé, partage, filtres ou effets, légende ou texte sur un widget Photos, statistiques. Toute planche qui en montre une doit la marquer « idée nouvelle ».

## 10. Captures CI disponibles

**Aucune.** La branche `origin/ci-report` (918 fichiers) ne contient aucune image (0 fichier `.png`, `.jpg` ou `.gif`) : seulement `report.txt` et des fichiers texte dans `history/`.

- Les 21 fichiers `history/<date>-runNNN/RECO-PHOTOS.txt` concernent la reconnaissance de plats (Nutrition), pas cette mini-app.
- Aucun test d'interface ne vise la mini-app : recherche de `photos-`, `quote-`, `mini-app-photos` dans `UITests/` sans résultat.
- `docs/memoire/Chantiers.md:258` cite une capture « Photos » faite le 2026-11-10 pour le kit pub : elle n'est pas dans `ci-report` aujourd'hui. À vérifier (ou à refaire avec `[shots]`).
- Identifiants d'accessibilité déjà posés, utiles pour de futures captures : `photos-new`, `quote-new`, `photos-add`, `photos-widget`, `photos-preview`, `photos-size-small|medium|large`, `photos-pick`, `photos-thumbnail`, `photos-name`, `photos-save`, `photos-framing`, `photos-zoom`, `photos-framing-done`, `quote-text`, `quote-author`, `quote-background-pick`, `quote-background-frame`, `quote-background-remove`.

## 11. Contraintes pour la conception

- **Ne perdre aucune fonction** : F1 à F27 (§ 4) et les quatre entrées vers l'éditeur (mini-app, Créer, Mes widgets, toucher du widget).
- **Un seul éditeur partagé.** `PhotoQuoteEditor` s'ouvre de trois endroits avec le même `PhotoQuoteDraft` (PQA:82, `ArdaneApp.swift:114`, `CreateFlow.swift:216`). Un nouveau dessin doit rester ouvrable de partout, en création comme en modification.
- **Ne pas changer le modèle ni les calculs** : `PhotoSlot`, `QuoteContent`, `quoteBackground` = 1re photo, `PhotoLayout` (4 visibles, 12 au plus, rotation à l'heure, cases, cadrage), taille du texte, voile, `ImageStore`, `SafeImage`, nettoyage des copies.
- **Garder l'aperçu réel** (`WidgetPreview`) : le widget montré est celui qui sera posé, bord à bord, sans style d'Ardane autour.
- **Garder la promesse de confidentialité** : sélecteur d'Apple, aucune demande d'accès à la photothèque, photos copiées dans l'app.
- **Gratuit et illimité** : décision du 2026-10-16 (`Decisions.md:63`). Pas de cadenas sur une fonction existante sans décision du PDG.
- **Pas de données datées.** Une planche « Analytique » ou « Quotidienne » ne peut pas inventer de courbes ni de séries. Elle doit trouver un autre sens (par exemple l'ordre et la rotation des photos, ou l'état des widgets) et le dire.
- **Mon quotidien** : Photos en est exclue aujourd'hui. Toute carte Small dans Mon quotidien serait une idée nouvelle, à marquer comme telle.
- **Tailles** : Petit, Moyen, Grand seulement. Pas d'écran verrouillé pour ces deux genres.
- **Identité** : Crystal Équilibré pour la page (`cristalPanel`, `cristalScreen`, `MiniAppScaffold`) ; C1 Atelier pour l'éditeur, qui est une expérience de création et de personnalisation. Une seule couleur d'accent à retenir (voir § 8, point 16).
- **Le recadrage reste sur fond sombre et au doigt** (glisser, pincer), aux proportions réelles de la case.
- **Textes** : tout passe par `tr("…")` (7 langues avec le français) ; les libellés cités ici sont ceux de l'app. Garder les identifiants d'accessibilité du § 10 et les étiquettes des vignettes (PQA:358-360).
- **Hors périmètre** : Finance ; le fond photo du Studio (Premium, autre fonction) ; les photos de plats et d'horaires.
