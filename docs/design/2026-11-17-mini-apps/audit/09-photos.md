# Audit : Photos et citations

Relevé fait dans le code le 2026-11-17 (branche `main`, commit `0172244`). Lecture seule. Chaque ligne porte sa preuve (fichier:ligne ou nom de la vue). Ce qui n'a pas pu être prouvé est marqué « à vérifier ». Fichier principal : `App/Screens/MiniApps/Photos/PhotoQuotesApp.swift` (696 lignes, abrégé « PQA » plus bas).

## 1. En bref

- Sert à fabriquer des widgets d'écran d'accueil faits de TES photos (1 à 12, 4 visibles à la fois) ou d'UNE citation (texte, auteur, typographie, couleurs, photo de fond). Ce n'est pas un journal ni une galerie : on crée un widget, on le range, on le retouche.
- Mini-app `MiniApp.photos`, titre « Photos et citations », icône `photo.on.rectangle.angled`, couleur `D9608B` (`App/Screens/MiniApps/MiniApp.swift:19`, `:33`, `:47`). Vue : `PhotoQuotesAppView` (`MiniApp.swift:161-162`).
- Pour qui : tout le monde. Elle apparaît dans « Mes mini-apps » de l'accueil seulement si la personne a déjà un tel widget, ou l'intérêt « design » (`MiniAppsRow.swift:45`, `:59`) ; sinon sous « À découvrir » dans « Toutes ». Elle est exclue de Mon quotidien (`App/Core/DailyCategories.swift:8-9` ; `App/Core/DailyBrief.swift:165` renvoie rien).
- Usage : ponctuel (on crée un widget, on y revient rarement). Aucun rappel, aucune série, aucune donnée datée.
- État : petite, stable, deux parcours complets (photos, citation) et un recadrage. Il n'existe pas : album, bibliothèque de citations, citation du jour, liste d'inspiration, statistiques, réglage de la rotation, widget d'écran verrouillé pour ces deux types.
- Gratuit : photos et citations ILLIMITÉES (elles ne comptent pas dans les 3 widgets gratuits : `App/Core/AppModel.swift:251-254`). Aucune fonction Premium dans cette mini-app.
- Particularité : la création et la retouche passent par UNE seule feuille (`PhotoQuoteEditor`), ouverte aussi depuis Créer, Mes widgets et le toucher d'un widget.

## 2. Écrans et navigation

| # | Écran ou feuille | Vue SwiftUI, fichier:ligne | Comment on y arrive | Ce qu'on y fait |
|---|---|---|---|---|
| E1 | Page « Photos et citations » (écran principal) | `PhotoQuotesAppView`, PQA:9 | Accueil › « Mes mini-apps » › puce (`MiniAppsRow.swift:161`, id `mini-app-photos`) ; ou « Toutes » › ligne (`AllMiniAppsSheet`, `MiniAppsRow.swift:~205`) ; `router.openApp(.photos)` (`Router.swift:121`) | Voir ses widgets, en créer un (Photos ou Citation), ouvrir un widget pour le modifier. |
| E2 | Feuille « Widget photo » / « Widget citation » (éditeur) | `PhotoQuoteEditor`, PQA:127 (titre PQA:187) ; feuille posée en PQA:82, `ArdaneApp.swift:114`, `CreateFlow.swift:216` | a) E1 : « Photos », « Citation », tuile « + » (via E7), ou une tuile de widget. b) Onglet Créer › taille › catégorie « Photos et citations » › choix (E8). c) Onglet Mes widgets : ouvrir un widget Photos ou Citation (`MyWidgetsView.swift:243`, `:293`, `:534` → `router.openEditor`, `Router.swift:131-134`). d) Toucher le widget posé : lien `tessera://design/<id>` (`WidgetCanvas.swift:185`, `Router.swift:149`). e) Dupliquer ou « variante » d'un widget dans Mes widgets (`MyWidgetsView.swift:316-321`). | Taille, photos ou citation, nom, supprimer, enregistrer. Voir E3 à E6. |
| E3 | Feuille de recadrage « Recadrer » | `PhotoFramingView`, PQA:588 ; feuille posée PQA:199 | E2 : toucher une vignette, menu « Recadrer », ou (citation) la photo de fond / « Recadrer » (PQA:488-503) | Glisser pour déplacer, pincer ou curseur « Zoom » (1 à 4), « Réinitialiser », « Annuler », « OK ». Fond noir, cadre à la taille réelle de la case du widget (PQA:598-606). Pour une photo au-delà des 4 visibles à l'instant, la case prise est celle de la 1re position (PQA:601, repli `?? 0`). La feuille se ferme aussi d'un balayage (pas de blocage, contrairement à E2). |
| E4 | Sélecteur de photos d'Apple (système) | `PhotosPicker`, PQA:289 (photos), PQA:504 et PQA:524 (fond de citation) | E2 : « Choisir des photos » / « Ajouter des photos » ; « Changer de photo » ; « Choisir une photo » | Choisir des photos. Aucun accès à la photothèque n'est demandé (texte PQA:23, PQA:307). |
| E5 | Dialogue « Supprimer ce widget ? » | `confirmationDialog`, PQA:206 | E2 (widget déjà enregistré seulement) › « Supprimer ce widget » (PQA:173-181) | « Supprimer » ; message « Il disparaîtra de ton écran d'accueil. Les photos de ta photothèque ne sont pas touchées. ». |
| E6 | Menu contextuel d'une vignette | `contextMenu`, PQA:344-357 | E2 : appui long sur une vignette de photo | « Recadrer », « Avancer », « Reculer », « Retirer » (ordre des photos). |
| E7 | Dialogue « Nouveau widget » | `confirmationDialog`, PQA:86-90 | E1 : tuile « + » en fin de grille (PQA:64-76, id `photos-add`) | « Photos », « Citation », « Annuler ». |
| E8 | Dialogue « Créer un widget » + catégorie | `CreateFlowView`, `CreateFlow.swift:212-215` ; carte de catégorie `CreateFlow.swift:449` (compte fixé à 2) | Onglet Créer › taille › « Photos et citations » (dernière catégorie, `CreateFlow.swift:40`) | Même choix Photos / Citation, puis E2 (`startPhotoQuote`, `CreateFlow.swift:259`). |
| E9 | Feuille Premium « Plus de 3 widgets » | `PaywallView`, PQA:85 ; `PaywallContext.designLimit` (`PaywallContext.swift:38-44`) | `start()` PQA:93-101 si `canSave` refuse | Voir l'offre. **Jamais atteinte dans les faits** : un widget photo ou citation passe toujours la règle (`AppModel.swift:251-254`, `fitsFreePlan`). À vérifier : cas d'une fusion. |
| E10 | Feuille « Ajouter à l'écran d'accueil » (guide de pose) | `AddToHomeScreenGuide`, `ArdaneApp.swift:127-129` | Mes widgets : bouton « Ajouter à l'écran » d'un widget Photos ou Citation (`MyWidgetsView.swift:304-309`, avec son nom et son id) ; ou bouton de la barre de Mes widgets (`:126-130`, sans widget) | Guide pour poser le widget sur l'écran d'accueil. Absent de la mini-app elle-même (E1 n'a qu'une phrase, PQA:79). |

Points d'entrée qui ne sont pas des écrans :

| Point d'entrée | Où | Ce qu'il fait |
|---|---|---|
| Puce « Photos et citations » de l'accueil | `MiniAppsRow.swift:163-170`, légende `:107-109` | Légende : « N widget(s) photo ou citation », ou « Ouvrir » s'il n'y en a pas. Menu « Masquer de l'accueil ». |
| Fiche widget « Photos » et « Citation » du catalogue | `Shared/Model/KindCatalog.swift:271-273` (catégorie `.memories`) | « Fabriqués dans leur mini-app, jamais depuis le catalogue » (commentaire `:271`) ; texte « Une à quatre de tes photos, cadrées comme tu veux. » (à vérifier : 4 photos visibles, 12 possibles). Cette fiche n'est pas montrée dans le catalogue : `WidgetKind.offered` exclut ces deux genres (`Shared/Model/WidgetKind.swift:150`) ; elle ne sert qu'aux libellés et aux mots-clés. |
| Maquettes de l'écran d'accueil | `HomeSetups.swift:120` etc. | « Photos » y est l'app système iOS (dock), sans lien avec la mini-app. |
| Photo de fond du Studio | `EditorView.swift:71`, `:1238`, `:1303` (`StudioPhotoSession`) | Autre fonction (fond d'un widget quelconque). Hors périmètre, mais partage `ImageStore`. |

## 3. Écran principal : sections dans l'ordre actuel

Écran principal = E1 (PQA:18-91), bâti sur `MiniAppScaffold` (voile de couleur, `MiniAppScaffold.swift:30-95`). Pas de sélecteur de semaine ni de jour (rien n'est daté, commentaire PQA:21). Pas d'action flottante.

1. **Titre de navigation « Photos et citations »** (PQA:81).
2. **Bandeau MiniHero** (PQA:22-23) : petit libellé « TES WIDGETS PHOTO », grand chiffre (« 0 widget », « 3 widgets »), légende « Seules les photos que tu choisis sont copiées dans Ardane : aucun accès à ta photothèque n'est demandé. ».
3. **Deux boutons côte à côte** (PQA:26-35) : « Photos » (plein, id `photos-new`) et « Citation » (id `quote-new`).
4. **Titre « Mes widgets »** (PQA:37).
5. **Vide** : un seul texte « Une photo, deux, trois ou quatre, ou une citation : ton premier widget se crée en deux étapes. » (PQA:39). **Sinon** grille de 2 colonnes (PQA:44) : une tuile par widget (aperçu réel `WidgetPreview` à la taille du widget, nom, « Photos · Petit » ; id `photos-widget`), triée du plus récemment utilisé au plus ancien (`photoQuoteDesigns`, PQA:106) ; dernière tuile « + » (id `photos-add`).
6. **Note de pied** (PQA:79) : « Pour le poser : touche longuement l'écran d'accueil, puis + › Ardane › « Mes widgets », et choisis-le avec « Modifier le widget ». ».

Éditeur E2, dans l'ordre (PQA:156-182) : aperçu du widget (taille réelle, 200 pt si Petit, id `photos-preview`) › étape 1 « La taille » (Petit, Moyen, Grand) › étape 2 « Les photos » ou « La citation » › étape 3 « Le nom » › bouton « Supprimer ce widget » (seulement si déjà enregistré). Barre : « Annuler », « Enregistrer » (grisé tant qu'il n'y a ni photo ni texte, PQA:230-236).

Étape « Les photos » (PQA:286-325) : bouton « Choisir des photos » / « Ajouter des photos » (désactivé à 12) › « Préparation des photos… » › « N photo(s) illisible(s) » › texte d'aide qui change (vide / plus de 4 / 1 à 4) › rangée défilante de vignettes 72 pt numérotées.

Étape « La citation » (PQA:404-473) : « Ta citation » (280 caractères, 3 à 8 lignes) › « Auteur (facultatif) » › « Typographie » (Serif, Arrondie, Standard, Mono) › « Couleurs » (8 paires prêtes) › « Fond » et « Texte » (sélecteurs de couleur libres) › « Photo de fond » (voile réglable, PQA:477-544) › « Centrée » › « Guillemets » › lien « Essayer avec un exemple » (texte vide seulement).

## 4. Fonctions existantes

Liste de référence : aucune planche ne doit en perdre une. Gratuit partout ; aucune fonction Premium.

| # | Fonction | Où elle est | Gratuit ou Premium | Données affichées | Actions possibles |
|---|---|---|---|---|---|
| F1 | Créer un widget Photos | E1 bouton « Photos » (PQA:27), E7, E8 | Gratuit, illimité | Aperçu en direct | Ouvre l'éditeur avec un widget Petit nommé « Mes photos » (PQA:117-122) |
| F2 | Créer un widget Citation | E1 bouton « Citation » (PQA:31), E7, E8 | Gratuit, illimité | Aperçu en direct | Ouvre l'éditeur, widget Petit nommé « Ma citation », citation vide (PQA:120) |
| F3 | Grille « Mes widgets » | E1 (PQA:44-76) | Gratuit | Aperçu réel, nom, type et taille, tri par dernier usage | Ouvrir un widget pour le modifier |
| F4 | Compteur de widgets | MiniHero E1 (PQA:22) | Gratuit | Nombre de widgets photo et citation | Aucune |
| F5 | Choisir la taille | E2 étape 1 (`sizePicker`, PQA:254-282) | Gratuit | 3 pictogrammes proportionnels, taille choisie encadrée | Petit, Moyen, Grand (l'aperçu suit) |
| F6 | Choisir des photos | E2 (`photosStep`, PQA:286) + E4 | Gratuit, jusqu'à 12 (`PhotoLayout.maxPhotos`, `PhotoQuote.swift:141`) | Vignettes numérotées, compteur d'illisibles | Ajouter ; copie réduite (2 400 puis 1 200 px, `SafeImage`, PQA:378-379) ; vibration de réussite |
| F7 | Mise en page automatique | `PhotoLayout.cells` (`PhotoQuote.swift:161-183`) | Gratuit | 1 : plein ; 2 : côte à côte (Grand : l'un sur l'autre) ; 3 : une grande + deux ; 4 : grille 2×2 | Aucune (suit le nombre) |
| F8 | Rotation horaire au-delà de 4 photos | `PhotoLayout.visible`, `nextChange` (`PhotoQuote.swift:145-157`) | Gratuit | Texte « Plus de 4 photos : le widget en montre 4 à la fois, puis les suivantes chaque heure. » (PQA:309) | Aucune (pas réglable) |
| F9 | Recadrer une photo | E3 (PQA:588) | Gratuit | Case à la taille réelle, zoom 1 à 4 | Glisser, pincer, curseur, « Réinitialiser », « OK » |
| F10 | Ordre et retrait des photos | E6 (PQA:344-357, `move` PQA:363) | Gratuit | Numéros sur les vignettes | « Avancer », « Reculer », « Retirer » (menu à l'appui long seulement) |
| F11 | Saisir la citation | E2 (PQA:407-415) | Gratuit | Aperçu en direct | Texte (280 max), auteur |
| F12 | Typographie de la citation | PQA:416-420 ; `QuoteFont` (`PhotoQuote.swift:50-62`) | Gratuit | 4 choix | Serif, Arrondie, Standard, Mono |
| F13 | Couleurs de la citation | PQA:421-453 ; `QuotePalette.all` (`PhotoQuote.swift:71-80`) | Gratuit | 8 paires « Aa » : Papier, Nuit, Corail, Océan, Forêt, Rose, Sable, Lilas | Choisir une paire ; « Fond » et « Texte » libres (`ColorPicker`) |
| F14 | Photo de fond d'une citation | `backgroundSection`, PQA:477-544 | Gratuit | Vignette à la forme du widget, curseur « Voile pour la lisibilité » (0,15 à 0,75, `veilRange`) | « Choisir une photo », « Recadrer », « Changer de photo », « Retirer » ; texte clair gardé, sinon blanc (`inkOnPhotoHex`, `PhotoQuote.swift:128`) |
| F15 | Options de la citation | PQA:455-458 | Gratuit | Deux interrupteurs | « Centrée », « Guillemets » |
| F16 | Exemple de citation | PQA:459-470 ; `QuoteContent.sample` (`PhotoQuote.swift:133`) | Gratuit | Une seule citation (Saint-Exupéry) | « Essayer avec un exemple » (seulement texte vide ; garde typographie, couleurs, voile) |
| F17 | Nommer le widget | E2 étape 3 (PQA:167-172) | Gratuit | Champ « Nom du widget » | Saisir (vide = titre du type, PQA:561) |
| F18 | Aperçu en direct | `WidgetPreview` (PQA:157) | Gratuit | Le widget tel qu'il sera ; photos indisponibles remplacées par « Photo indisponible » | Aucune (fait défiler avec la feuille) |
| F19 | Enregistrer / Annuler | PQA:559-584 | Gratuit | Désactivé sans photo ou sans texte | Nettoie les copies inutiles, vibration, célébration à la 1re création (`model.celebrate()`) |
| F20 | Supprimer un widget | E5 (PQA:173-181, `:206-216`) | Gratuit | Confirmation | Efface le widget et ses copies de photos |
| F21 | Dupliquer et variante | Mes widgets (`MyWidgetsView.swift:295`, `:316`) ; `AppModel.duplicate` (`AppModel.swift:353-372`) | Gratuit | — | Copie avec ses propres fichiers photo. Hors de cette mini-app. |
| F22 | Poser le widget | Note de pied PQA:79 ; vide : « Choisis tes photos dans Ardane » (`PhotoQuoteWidgets.swift:23`) ; guide E10 depuis Mes widgets | Gratuit | Texte d'aide | Aucune action dans la mini-app (explication seulement) ; le guide est ailleurs (F25) |
| F23 | Rendu Clair et Teinté d'iOS | `PhotoQuoteWidgets.swift` (`FramedPhoto`, veil, `isMonochrome`) | Gratuit | Photos en couleur, photo de citation désaturée | Aucune |
| F24 | Photos non disponibles | `PhotoCell` (`PhotoQuoteWidgets.swift:46-57`) | Gratuit | « Photo indisponible » | Citation : retombe sur ses couleurs (`:141-146`) || F25 | Actions de Mes widgets sur un widget Photos ou Citation | `MyWidgetsView.swift:292-309` (carrousel : « Modifier » `carousel-edit`, « Dupliquer », « Favori » `carousel-favorite`, « Ajouter à l'écran » `carousel-place`) | Gratuit | Cœur plein ou vide | « Modifier » ouvre E2 ; « Favori » est propre à Mes widgets (pas dans la mini-app) ; « Ajouter à l'écran » ouvre E10. Le bouton « variante » ouvre aussi E2 (`makeVariant`, `:316-321`). |
| F26 | Renouvellement horaire du widget posé | `Widgets/DesignProvider.swift:88-92` | Gratuit | Entrée actuelle + 6 entrées, une par heure à partir de la prochaine heure pleine (plus de 4 photos seulement) ; sinon pas de renouvellement (`policy: .never`) | Aucune |

## 5. Données et calculs (à ne pas modifier)

- **Pas de modèle propre à la mini-app** : un widget photo ou citation est un `WidgetDesign` de genre `.photos` ou `.quote` (`PhotoQuote.swift:207-212` : `madeInTheirMiniApp`, `isMadeInItsMiniApp`). Liste affichée = `recentDesigns.filter { isMadeInItsMiniApp }` (PQA:106) ; `recentDesigns` trie par `lastUsedAt ?? updatedAt` (`AppModel.swift:~286`).
- `PhotoSlot` (`PhotoQuote.swift:11-47`) : `id`, `file` (nom dans `ImageStore`), `centerX`, `centerY` (0 à 1), `zoom` (1 à 4), `clamped`. Stocké dans `WidgetDesign.options.photos` (`DesignOptions.swift:69`) ; la citation est dans `options.quote` (`:77`, `:101-102`).
- `QuoteContent` (`PhotoQuote.swift:84-134`) : `text`, `author`, `font`, `backgroundHex` (« F6F0E6 »), `textHex` (« 2B2622 »), `isCentered`, `showsMarks`, `photoVeil` (0,4). Lecture tolérante aux champs absents.
- Photo de fond d'une citation = la 1re de `options.photos` (`quoteBackground`, `PhotoQuote.swift:204` ; décision 2026-10-15, `Decisions.md:58`). À ne pas changer : suppression, copie, sauvegarde en dépendent.
- Calculs à garder : `PhotoLayout.capacity = 4`, `maxPhotos = 12`, `visible` (heure Unix × 4 modulo le nombre : mêmes photos pendant l'heure sur tous les widgets), `cells`, `frame` (cadrage sans bord vide) ; taille de police de la citation selon la longueur et la famille (`QuoteWidgetView.size`, `PhotoQuoteWidgets.swift:131-137`) ; voile en dégradé (`:164-169`).
- Fichiers : `ImageStore` (`SharedStore.swift:269`), dossier `Tessera/Images/` de l'App Group, JPEG qualité 0,82, 1 200 px (`ImageStore.save`, `:276-292`), nom imposé par le magasin (pas de chemin lu d'un fichier, `:294-299`). Décodage borné : 64 mégapixels, `SafeImage` (`Shared/Support/SafeImage.swift`).
- Nettoyage : copies faites pendant l'édition effacées si Annuler (PQA:578-584), photos retirées effacées à l'enregistrement (PQA:567-572), suppression du widget efface ses fichiers non partagés (`AppModel.swift:325-338`). Feuille non balayable pendant un chargement ou avec des copies non enregistrées (PQA:227).
- Règle gratuite : `countsTowardFreeLimit` (`AppModel.swift:251-254`) ; un widget combiné ne compte que si une de ses parties compte. Limites : 280 caractères de citation (PQA:407).
- Tests existants : `Tests/PhotoQuoteBackgroundTests.swift` (photo de fond, relecture, texte clair, retour aux couleurs) ; `Tests/SafeImageTests.swift` ; `Tests/BackupOrphanPhotosTests.swift` (liste du CLAUDE.md et `Chantiers.md:348`).

## 6. Liens

- **Carte de Mon quotidien** : AUCUNE. Photos est retirée des choix (`DailyCategories.swift:8-9`) et n'a pas de légende de brief (`DailyBrief.swift:165`). Contenu et taille : sans objet.
- **Accueil** : puce de « Mes mini-apps » (128 × 118 pt, `MiniAppsRow.swift:~187`), légende « N widgets photo ou citation ».
- **Widgets** : les widgets sont le produit lui-même : types `.photos` et `.quote`, tailles Petit, Moyen, Grand (`WidgetFormat`, `Shared/Model/Combo.swift:5-24`), pas d'écran verrouillé (`WidgetCanvas.swift:28-32` : `!family.isAccessory`). Toucher le widget ouvre l'éditeur (E2) par `tessera://design/<id>`. Ils se posent avec « Mes widgets » › « Modifier le widget » (PQA:79).
- **Autres mini-apps** : aucune donnée partagée. Un widget photo ou citation peut être une partie d'un widget combiné (`AppModel.swift:253`, `Combo.swift`) : à vérifier dans le Studio.
- **Créer** : catégorie « Photos et citations » (`CreateFlow.swift:23-72`, couleur `EC4899`, comptée « 2 » en dur, `:449`). `graph_map.py:207` cite une `PhotoQuotesCard` : elle n'existe plus dans le code (recherche sans résultat), à corriger dans la carte.
- **Mes widgets** : mêmes widgets (ouvrir, dupliquer, variante, favori) ; bandeau « Photos et citations illimitées » (`MyWidgetsView.swift:364`).
- **Sauvegarde et restauration** : photos incluses (`App/Core/DataBackup.swift:16`, `:88-110`).
- **Notifications et rappels** : aucun. Pas de notification, pas de rappel dans cette mini-app.
- **Liens profonds** : aucun lien propre à la mini-app (pas de `tessera://photos`). `MiniApp.photos` n'a pas d'espace (`space` vaut nil, `MiniApp.swift:64`). Ouverture par `router.openApp(.photos)` seulement.
- **« Mes informations » / « À remplir »** : vides pour Photos (`MiniAppSettings.swift:27`, `MiniAppToFill.swift:18`).

## 7. États vides, première utilisation, erreurs, permissions, limites du mode gratuit

- **Première utilisation** : le bandeau annonce « 0 widget » ; un seul texte explique (PQA:39), deux boutons en tête. Pas d'exemple visuel, pas de widget d'essai, pas de tutoriel. La puce de l'accueil dit « Ouvrir ».
- **Éditeur vide** : « Enregistrer » grisé jusqu'à une photo ou un texte non vide (PQA:230-236). Aperçu : « Choisis tes photos dans Ardane » (photos) ou « Ta citation ici » (citation, `PhotoQuoteWidgets.swift:~178`).
- **Permissions** : aucune. Le sélecteur d'Apple ne partage que les photos choisies (PQA:5-8). Aucune demande de notification.
- **Erreurs** : photo illisible ou trop grande (64 mégapixels) → « N photo(s) illisible(s) » en petit texte avec triangle (PQA:301-305, `:538-542`) ; pas de bouton « réessayer ». Fichier de photo manquant → « Photo indisponible » sur le widget.
- **Limites** : 12 photos (bouton grisé, PQA:296) ; 4 visibles à la fois ; 280 caractères ; 1 photo de fond. Aucune limite de nombre de widgets en gratuit pour ces deux types ; la feuille Premium de E9 n'est pas atteignable en pratique.
- **Chargement** : « Préparation des photos… » (PQA:298-300) ; « Enregistrer » grisé et feuille non balayable pendant ce temps.

## 8. Problèmes d'UX constatés aujourd'hui

1. **Une seule page, pas de hiérarchie ni de détail.** E1 = un bandeau, deux boutons, une grille ; aucune page de détail ni de sections (PQA:18-80). Toute la retouche est dans une feuille unique.
2. **Deux entrées pour la même action.** Les boutons « Photos » / « Citation » (PQA:26-35) ET la tuile « + » avec dialogue (PQA:64-90) font la même chose ; la tuile ajoute une étape de dialogue.
3. **Bandeau peu utile.** Le grand chiffre « N widgets » (PQA:22) est le seul indicateur ; le libellé « Tes widgets photo » exclut les citations ; la légende répète une règle de confidentialité au lieu d'aider.
4. **Éditeur en un long défilement.** L'aperçu n'est pas fixe : il sort de l'écran dès qu'on règle la citation (PQA:157-182, `ScrollView`). La citation compte 10 contrôles empilés (PQA:404-473). Le nom, étape 3, vient après les réglages.
5. **Libellé « 3 étapes » mais l'aide dit « deux étapes ».** Le texte vide (PQA:39) annonce « deux étapes » ; l'éditeur en numérote trois (PQA:161-167).
6. **Chiffres contradictoires sur les photos.** Texte vide : « une, deux, trois ou quatre » (PQA:39) ; fiche catalogue : « Une à quatre » (`KindCatalog.swift:272`) ; réalité : 12 photos, 4 visibles (`PhotoQuote.swift:139-141`).
7. **Rotation horaire invisible et non réglable.** Seule une ligne d'aide l'explique, et seulement au-delà de 4 photos (PQA:309) ; aucun aperçu de ce qui s'affichera à l'heure suivante.
8. **Ordre des photos caché dans un menu d'appui long.** « Avancer / Reculer / Retirer » (PQA:344-357) sont absents de l'écran ; seule la phrase d'aide (PQA:310) et l'indication d'accessibilité (PQA:359) le disent. Pas de glisser-déposer.
9. **Aucune aide pour la citation.** Un seul exemple (PQA:459-470, `PhotoQuote.swift:133`), visible seulement quand le texte est vide ; pas de bibliothèque ni de citation du jour.
10. **Poser le widget : une note de pied en petit.** Dans la mini-app, l'étape finale (PQA:79) est une phrase, sans bouton. Un guide existe pourtant (`AddToHomeScreenGuide`, E10) mais seulement depuis Mes widgets › « Ajouter à l'écran » ; ni la mini-app ni l'éditeur ne l'ouvrent, et « Enregistrer » ne le propose pas (PQA:559-576).
11. **Tuiles de la grille peu lisibles en Moyen et Grand.** Chaque tuile occupe une demi-largeur (PQA:44) : un widget Moyen ou Grand y est réduit sans rapport de taille avec les autres ; légende « Photos · Petit » en très petit corps (`caption2`, PQA:57).
12. **Couleurs d'accent différentes pour la même mini-app.** `D9608B` (`MiniApp.swift:47`) dans la mini-app, `EC4899` dans la catégorie de Créer (`CreateFlow.swift:63`).
13. **Nom de la mini-app instable.** Titre « Photos et citations » (PQA:81), bandeau « Tes widgets photo » (PQA:22), boutons « Photos » et « Citation », éditeur « Widget photo » (PQA:187), puce « widget photo ou citation » (`MiniAppsRow.swift:109`).
14. **Voie Premium morte.** `start()` (PQA:93-101) et `paywall` (PQA:12, 85) servent un cas qui ne se produit pas ; le bandeau de Mes widgets dit « Photos et citations illimitées » (`MyWidgetsView.swift:364`) : le gratuit n'a donc aucun avantage Premium à montrer ici (à vérifier avec le PDG si la mission en veut un).
15. **Pas d'écran de statistiques ni de calendrier** (rien n'est daté), donc la planche « Analytique » doit trouver un autre sens (voir § 11).
16. **Aucun test d'interface ni capture CI** de cette mini-app (§ 10), seulement un test logique : l'écran n'est jamais vérifié visuellement.
17. **Annulation silencieuse.** « Annuler » (PQA:191) ferme l'éditeur sans confirmation même après des photos choisies et recadrées ; c'est le seul garde-fou de la feuille (la feuille est non balayable, PQA:227, mais « Annuler » ne demande rien).

## 9. Ce que la mission du PDG cite et qui n'existe pas

Texte relu : `docs/design/2026-11-17-mini-apps/MISSION.md` (sections 1 à 4 lues). Photos y est couverte par « toutes les autres mini-apps » : une recherche du mot « photo » dans le fichier ne trouve aucune section propre à Photos (seule mention : « Scanner de repas par photo », ligne 88, pour Nutrition).

- Les cinq approches (Minimaliste, Dashboard Premium, Analytique, Quotidienne, Hybride intelligente) : Analytique et Quotidienne n'ont pas de matière dans le code (aucune donnée datée, aucun usage quotidien, aucune statistique).
- « L'écran principal, les sections et leurs accès, une vue détaillée, une vue de gestion ou de personnalisation, une vue secondaire » : il n'existe aujourd'hui qu'une page, un éditeur et un recadrage. Pas de vue détaillée d'un widget, pas de bibliothèque.
- « Une carte dans Mon quotidien » : n'existe pas pour Photos (§ 6).
- Fonctions qui n'existent pas et qui seraient inventées par une planche : albums ou collections, citations favorites ou bibliothèque, citation du jour, rotation réglable (toutes les 15 min, au jour), widgets verrouillage d'écran, partage, statistiques d'usage, filtres ou effets sur les photos, légendes de photo, texte sur photo pour les widgets Photos. Toute planche qui les montre doit les marquer « proposition nouvelle ».

## 10. Captures CI disponibles

- Branche `origin/ci-report` (lecture seule) : AUCUNE capture de la mini-app Photos ni de l'éditeur. Les fichiers présents sont `report.txt` et, dans `history/`, des fichiers texte du scanner alimentaire (`RECO-PHOTOS.txt`, `OCR-*`, `SCORES-*`) : ils n'ont rien à voir (photos de plats).
- Aucun test d'interface n'ouvre la mini-app : recherche de `photos-new`, `photos-widget`, `photos-framing` dans `UITests/` sans résultat. Les identifiants d'accessibilité existent pourtant dans le code (`photos-new`, `quote-new`, `photos-add`, `photos-widget`, `photos-preview`, `photos-pick`, `photos-name`, `photos-save`, `photos-size-small|medium|large`, `photos-thumbnail`, `photos-framing`, `photos-zoom`, `photos-framing-done`, `quote-text`, `quote-author`, `quote-background-pick|frame|remove`).
- Le libellé marketing « Photos, collages, citations » (`App/Core/MarketingShots.swift:849`) parle de « collages » : le mot n'existe pas dans l'app (le rendu s'appelle `PhotoCollageView`, `WidgetCanvas.swift:30`, la mise en page 1 à 4 est automatique, F7).
- Une capture de « Photos » est citée dans `Chantiers.md:258` (2026-11-10, « 4 écrans : développé couché, scanner, Travel, Photos »), mais elle n'est pas dans `ci-report` aujourd'hui : à vérifier (`[shots]` ou `[adkit-en]` à relancer).

## 11. Contraintes pour la conception

- **Garder** : l'aperçu réel du widget (`WidgetPreview`), le parcours « taille d'abord » (cohérent avec Créer), le recadrage au toucher (glisser, pincer) à la taille réelle de la case, l'absence d'accès à la photothèque (sélecteur d'Apple, argument de confidentialité), les 8 palettes, les 4 typographies, la photo de fond avec voile, les 12 photos, la rotation horaire, la mise en page 1 à 4 automatique.
- **Ne pas changer le modèle** : `PhotoSlot`, `QuoteContent`, `quoteBackground` = 1re photo, `ImageStore`, `SafeImage`, règle gratuite (`countsTowardFreeLimit`), `isMadeInItsMiniApp`. Une planche peut proposer une nouvelle présentation, pas un nouveau stockage.
- **Pas de données datées** : aucune planche « Analytique » ou « Quotidienne » ne doit inventer de courbes ou de séries ; si elles existent, elles portent sur ce qui est réel (nombre de widgets, nombre de photos, taille, type, dernier usage = `lastUsedAt`, `updatedAt`).
- **Pas de Premium dans cette mini-app aujourd'hui** : ne pas ajouter de cadenas sur des fonctions existantes sans décision du PDG (gratuit illimité = décision du 2026-10-16, `Decisions.md:63`).
- **Les widgets sont le produit** : toute direction doit montrer le widget fini sur un écran d'accueil (règle des pubs : Créer › widget › style › écran d'accueil), avec le guide « Pour le poser ».
- **Identité** : Crystal Équilibré (fonds blancs, bleu glacé, `cristalPanel`, `cristalScreen`) ; C1 Atelier pour la création et la personnalisation, donc l'éditeur (taille, photos, citation) en relève directement.
- **Une seule feuille d'édition** est partagée par quatre entrées (mini-app, Créer, Mes widgets, toucher du widget : `ArdaneApp.swift:114`, `CreateFlow.swift:216`, PQA:82). Un nouveau dessin de l'éditeur doit rester ouvrable de partout avec le même `PhotoQuoteDraft`.
- **Liste à ne pas perdre** : F1 à F24 (§ 4), plus les points d'entrée de l'accueil, de Créer et de Mes widgets.
- **Pas de Finance** ; ne pas toucher `App/Screens/MiniApps/Finances`.
- **Langues et textes** : tout texte passe par `tr("…")` (6 langues) ; accessibilité : identifiants listés en § 10, étiquettes des vignettes (PQA:358-360), indication « touche longuement » à garder.
- **Tailles** : accueil, tuiles de 128 × 118 pt ; widgets Petit, Moyen, Grand seulement (pas d'accessoires d'écran verrouillé aujourd'hui).

## Relecture

- Ajouté : écran E10 (guide « Ajouter à l'écran », `ArdaneApp.swift:127`), fonctions F25 (actions de Mes widgets dont « Favori ») et F26 (renouvellement horaire, `DesignProvider.swift:88-92`), fiche catalogue masquée (`WidgetKind.swift:150`), libellé marketing « collages » (`MarketingShots.swift:849`), repli du recadrage au-delà de 4 photos (PQA:601).
- Corrigé : la phrase « sans guide » du problème 10 et de F22 (le guide existe, hors de la mini-app) ; plus de 20 références vérifiées (MiniApp.swift:19/33/47/64/161, AppModel.swift:251-254, MiniAppsRow.swift:45/59/109, DailyBrief:165, Router:121/131-134, CreateFlow:449, MyWidgetsView:364, ids d'accessibilité, aucune capture CI, aucun Premium) : exactes. Section 9 confirmée : MISSION.md ne cite Photos qu'en passant (aucune section propre).
- Incertain : fusion d'un widget Photos dans un combiné (Studio) ; atteignabilité réelle de E9 ; capture de `Chantiers.md:258` ; lignes marquées « ~ » non recontrôlées.
