# Audit 24.W : widgets, Studio, Store, Mes widgets, espaces, stockage, liens profonds, notifications

Date : 2026-11-07. Analyse statique seulement (pas de Mac, aucune exécution) : tout ce qui est marqué « À confirmer » ne peut être tranché que par la CI ou l'iPhone. `python3 scripts/check_swift.py` : OK (labels d'init, kinds, sécurité Release).

Résumé : 0 bloquant, 6 majeurs (W-01 à W-06), 11 mineurs (W-07 à W-16, W-18), 2 améliorations (W-17, W-19). 6.A et 7.B : cause non établie par lecture seule (W-05 et W-06), pistes classées.

---

## Majeurs

### W-01 Majeur : aucune donnée financière n'est masquée à l'écran verrouillé (`.privacySensitive` absent)
- Preuve : `grep privacySensitive` dans `Shared/`, `Widgets/`, `App/` : aucun résultat. Les widgets d'écran verrouillé `FinancesLockWidget` et `BusinessLockWidget` (`Widgets/DesignWidgets.swift:83,87`) affichent le reste du budget, le chiffre d'affaires, le bénéfice ; Placements, Nutrition et Fitness aussi, via `AccessoryWidgetView` (`Shared/Render/AccessoryViews.swift:8-18`, défaut `TileAccessoryView`).
- Impact : un solde, un chiffre d'affaires, un poids ou des calories sont lisibles par quiconque regarde l'iPhone verrouillé. Attente forte pour une app de finances et de santé : retours négatifs et question de confidentialité en revue.
- Reproduction : poser le widget Finances en circulaire ou rectangulaire sur l'écran verrouillé, verrouiller, regarder sans Face ID.
- Correction : dans `DesignWidgetEntryView` (`Widgets/DesignWidgets.swift:11`), appliquer `.privacySensitive(...)` pour les kinds sensibles (espaces budget, business, investing, markets, nutrition, fitness), ou sur les seules vues de montants et de poids de `AccessoryViews` et des tuiles. Option : réglage « Masquer à l'écran verrouillé » dans le Profil.
- Test : test logique d'une propriété `WidgetKind.isSensitive` ; capture CI d'un widget avec `redactionReasons = .privacy`.

### W-02 Majeur : l'app réécrit un fichier illisible avec un état vide (perte de données)
- Preuve : le garde `isUnreadable` n'existe que dans `SharedStore.update` et `updateContent` (`Shared/Support/SharedStore.swift:205-232`), utilisés par les widgets. Le chemin de l'app ne l'utilise pas : `AppModel.update` fait `store.save(value)` sur l'état en mémoire (`App/Core/AppModel.swift:138-143`) ; `store.designs = designs` (`AppModel.swift:307,316,331,376,383,421`) ; `updateContent` écrit `store.content = content` (`AppModel.swift:429-433`). Or `read` renvoie nil pour un fichier illisible ou non décodable (`SharedStore.swift:136-140`), donc `state(T.self)` renvoie un état vide (`:213-215`) et `designs` renvoie `[]` (`:185`). La première modification suivante (une dépense, un widget enregistré) écrase le fichier d'origine. Aucune copie de secours (grep `corrupt|.bak` : rien hors Apple Pay).
- Deuxième cause, plus probable : décodage « tout ou rien » par tableau. `NutritionState.init(from:)` fait `entries = c.value(.entries, [])` (`Shared/Domains/Nutrition.swift:700`) et `value` avale l'erreur (`Shared/Support/Helpers.swift:6-8`). Un seul élément qui ne se décode plus (champ ajouté sans défaut dans `FoodEntry`, `FoodItem`…) fait disparaître TOUT le tableau, puis la sauvegarde suivante l'efface. Seuls les widgets sont lus avec `LossyList` (`Shared/Model/LossyList.swift`), qui supprime définitivement un design non décodable à la réécriture (kind retiré, ou retour à une version plus ancienne).
- Impact : perte silencieuse de repas, séances, dépenses, widgets, sans message, après une mise à jour qui change un type, un fichier tronqué ou une restauration iCloud d'une autre version. Contredit la règle « l'app ne doit jamais effacer ».
- Reproduction : remplacer `nutrition.json` par un JSON dont `entries[0]` a une forme invalide, ouvrir l'app, noter un repas : le fichier ne contient plus que ce repas.
- Correction : (1) dans `SharedStore.write`, avant d'écrire, si le fichier existe et ne décode pas, copier l'ancien en `nom.json.corrompu` (une copie) puis écrire ; (2) pour `AppModel.update`, `designs` et `content`, passer par `SharedStore.update` (qui refuse si illisible) ou garder un drapeau de lecture ratée qui bloque l'écriture et affiche un bandeau ; (3) décoder les tableaux d'éléments avec `LossyList` (ajouter un `c.lossy(.entries)` dans `Helpers.swift`) pour ne perdre qu'un élément.
- Test : `SharedStoreCorruptionTests` : fichier corrompu, `update` renvoie false, fichier inchangé ; `NutritionState` avec un `entries` mal formé garde les autres éléments ; une écriture après lecture ratée crée la copie.

### W-03 Majeur : fusion de widgets, la photo de fond est partagée puis supprimée avec l'original
- Preuve : `Fusion.merge` reprend `background: first.background` (`Shared/Model/Combo.swift:135`) sans copier le fichier photo. Après la fusion, `fusionPhaseChanged` supprime les originaux (`App/Screens/MyWidgets/MyWidgetsView.swift:458-459`) et `AppModel.delete` efface le fichier photo de chaque original (`AppModel.swift:322-328`, ligne 326). Même effet si les originaux sont gardés puis supprimés plus tard.
- Impact : le widget fusionné perd sa photo de fond (retombe sur le fond du style, `Shared/Theme/Theme.swift:1033-1040`), sans avertissement.
- Reproduction : widget Nutrition avec photo de fond + un autre widget Nutrition, Fusionner, terminer : le fond a disparu.
- Correction : dans `Fusion.merge`, si `first.background` est une photo, soit `.theme`, soit copier le fichier (`ImageStore.save(image)` comme dans `AppModel.duplicate`, `AppModel.swift:343`), comme `WidgetDesign.withLook` (`Shared/Model/StyleColors.swift:187-188`).
- Test : `FusionTests` : fusion d'un design à fond photo, suppression des originaux, le fichier du fusionné existe encore.

### W-04 Majeur : le rappel « Me rappeler le jour J » est proposé dans un widget combiné mais ne sera jamais programmé
- Preuve : `ComboPartSettingsView` affiche `KindOptionsSection` pour la partie (`App/Screens/Editor/EditorView.swift:749`), donc le bouton « Me rappeler le jour J » (`KindOptionsSection.swift:92-98`) et la demande de permission. Mais `syncCountdownReminder` exige `design.kind == .countdown` et lit `design.options.countdownReminder` du design englobant (`App/Services/NotificationScheduler.swift:62`), alors que l'option de la partie est dans `options.parts[i].options`. Des combinés avec un compte à rebours existent dans le Store (`App/Screens/Explore/StoreCombos.swift:178,188`) et la fusion de « Mes widgets » en crée. La fusion d'un compte à rebours qui avait son rappel l'annule : `save(merged)` appelle `syncCountdownReminder` qui supprime l'identifiant du fusionné, et `delete` supprime ceux des originaux.
- Impact : l'utilisateur active un rappel, accepte la permission, et rien n'arrive le jour J.
- Correction : dans `syncCountdownReminder`, parcourir `design.partDesigns` (un identifiant par partie : identifiant du design + index) et annuler tous les identifiants préfixés au lieu d'un seul.
- Test : `NotificationSchedulerTests` (nouveau) : un combiné avec une partie compte à rebours + rappel produit une demande en attente ; une fusion conserve le rappel.

### W-05 Majeur (À confirmer) : 6.A, `part-caloriesLeft` n'ouvre pas les réglages du Studio
Vérifié dans le code :
- Le bouton existe avec l'identifiant `part-<kind>` (`EditorView.swift:571`) et pousse via `.navigationDestination(item: $openedPart)` (`EditorView.swift:576-578`). La logique est correcte sur le papier (`openedPart = pair.offset`, puis `ComboPartSettingsView(design: edited, index:)`).
- Le Studio du test est lui-même une destination poussée : `SpaceBuilderView` le présente par `.navigationDestination(isPresented: $customizes)` (`App/Screens/Spaces/SpaceBuilderView.swift:136-141`), dont la fermeture est recalculée à chaque mise à jour du créateur (commentaire ligne 135). Le chemin « Mes widgets » (feuille avec sa propre `NavigationStack`, `EditorView.swift:11`) n'a aucun test de partie.
- La déclaration de destination est placée DANS la carte d'une `EditorSection` (`EditorView.swift:539-578`), elle-même dans un `ScrollView` dont l'identité change à chaque section ou widget (modificateur `.id` avec section et index, `EditorView.swift:138`). C'est la zone fragile ; `Pieges-connus.md:65` note que Button + `navigationDestination(item:)` n'a rien changé.
- Cause probable (non prouvée) : la destination imbriquée n'est pas prise en compte quand elle est déclarée dans la carte. Correction à essayer en premier : déplacer `.navigationDestination(item: $openedPart)` sur la racine du Studio (le `VStack` de `screen(_:sections:)`, `EditorView.swift:106`), `openedPart` inchangé. Deuxième piste : destination par valeur (`.navigationDestination(for:)` à la racine et `NavigationLink(value:)`). Troisième piste, côté test : le `tap` suit un `press ... thenDragTo` qui peut laisser le défilement en inertie ; attendre que `part.frame` soit stable deux lectures de suite avant `part.tap()` (`UITests/ProfileUITests.swift:396-402`).
- Test : le test existant ; ajouter la variante « Mes widgets » (combiné enregistré, Studio, partie).

### W-06 Majeur (À confirmer) : 7.B, le retour en arrière n'annule pas la palette
Vérifié dans le code :
- `record`, `undo`, `restore` (`EditorView.swift:622-660`) sont corrects sur le papier pour la séquence du test : un toucher sur la palette ajoute l'état d'avant dans `past` (`:633-636`) ; le second passage causé par « Même style » (`designs = synced`, `:630`) n'ajoute rien s'il arrive moins de 0,6 s plus tard ; `undo` retire `past.last` ; `restore` pose `restored` pour que le `onChange` suivant soit ignoré (`:623-626`).
- Une propagation tardive (plus de 0,6 s) ne reproduit pas ce symptôme : `past` recevrait un état intermédiaire et l'annulation défairait d'abord le widget 2 (le test passerait cette ligne et échouerait plus loin, sur « vaut pour tous les widgets », `UITests/StudioUITests.swift` après la ligne 164).
- Le symptôme exact (palette encore sélectionnée sur le widget 2 après le toucher) correspond soit à un toucher sur « annuler » alors que `past` est vide (bouton désactivé, `EditorView.swift:213`) parce que l'état du Studio a été recréé, soit à un état d'accessibilité périmé du bouton palette (le test le dit lui-même, `StudioUITests.swift:35` : « A choice below the fold keeps its old accessibility state »). Aucune régression retrouvée dans `EditorView` : derniers commits `25597116`, `570364a3`, `e07bc834` (`.pressable`).
- Piste de correction : rendre l'historique indépendant du temps. Dans `record`, un drapeau `isPropagating` posé avant `designs = synced` et lu au début du `onChange` suivant (retour immédiat, sans toucher à `past`, `future`, `lastChange`) ; garder la coalescence de 0,6 s pour les curseurs seulement. Pour trancher : exposer `past.count` en `accessibilityValue` du bouton `studio-undo` et le joindre à la pièce de diagnostic ; si le bouton est désactivé au moment du toucher, la cause est la recréation de l'état (identité du Studio, `EditorRequest` regénéré).
- Test : extraire l'historique dans une structure `StudioHistory` (push, undo, redo, coalescence) et le tester sans interface.

---

## Mineurs

### W-07 Mineur : « Autres widgets » applique un style Premium à des widgets enregistrés sans Premium
- Preuve : `ApplyStyleSheet` appelle `model.apply(style, to:)` (`StudioPanels.swift:583`, `AppModel.swift:411-425`) qui écrit directement dans `designs` ; ni `saveStyle` (`StudioPanels.swift:456`, `AppModel.swift:390`) ni `apply` ne vérifient Premium. Sur l'écran d'accueil `displayedDesign` rabat le look (`WidgetCanvas.swift:15-17`), donc la valeur n'est pas livrée gratuitement, mais « Mes widgets » montre le look Premium et le garde.
- Correction : dans `apply(_:to:)`, ne pas appliquer si `restyled.usesPremiumFeatures && !isPremium` et ouvrir `PaywallContext.designs`.
- Test : `StudioTests` : style Premium appliqué en gratuit, compte 0, designs inchangés.

### W-08 Mineur : fonds d'écran de configurations Premium enregistrables sans Premium
- Preuve : `saveWallpaper` (`App/Screens/Explore/HomeSetupViews.swift:771-796`, bouton ligne 728) n'a pas de garde `needsPremium`, alors que `WallpaperCollection.swift:367-376` bloque les fonds Premium. Question : est-ce voulu ? Sinon ajouter le même garde.
- Aussi : rendu à `scale = 3` d'une vue de 402 x 874 pt (`WallpaperCollection.swift:383-389`) donne 1206 x 2622 px, pas la taille réelle de chaque iPhone alors que le texte annonce « à la taille de ton iPhone » : léger rognage.

### W-09 Mineur : `resetAllData` laisse « Mes styles »
- Preuve : la liste des fichiers effacés (`AppModel.swift:679-681`) n'inclut pas `.styles`, et `savedStyles` n'est pas remis à zéro. Les réglages `myWidgets.remembered.*` de l'App Group restent aussi (`QuickWidget.swift:57-67`).
- Correction : ajouter `.styles` et `savedStyles = []` ; purger les clés `myWidgets.remembered.*`.
- Test : `DataBackupTests` : après reset, `store.state(StyleLibrary.self).styles.isEmpty`.

### W-10 Mineur : notifications sans action ni destination
- Preuve : `didReceive response` se contente de `completionHandler()` (`App/Services/NotificationPresenter.swift:25-28`) ; aucune `UNNotificationAction` ni catégorie dans le code. Toucher une notification de séance ou de facture ouvre l'accueil, pas la mini-app.
- Correction : ajouter un lien dans `userInfo` à chaque demande (`SmartReminders.swift:93-101`, `Encouragements.swift:363`, habitudes, jour J) et le router dans `didReceive` avec `Router.handle`.

### W-11 Mineur : rappel d'habitude répété même si l'habitude est faite
- Preuve : `syncHabitReminder` programme un déclencheur `repeats: true` (`NotificationScheduler.swift:36-41`) sans tenir compte du jour validé, contrairement au moteur intelligent (`habitsLeft`, `NotificationEngine.swift:226-232`). Ni la plage de silence ni le plafond du Profil ne s'y appliquent (choix explicite de l'utilisateur, à documenter).

### W-12 Mineur : plafond de 64 notifications non géré globalement
- Preuve : le moteur limite par jour (`dailyNotificationCap` jusqu'à 10, `Shared/Model/Settings.swift:197`) sur 7 jours, soit jusqu'à 70, auxquels s'ajoutent les habitudes (1 par habitude), les jours J, les encouragements et la fin de Focus. iOS garde les 64 plus proches sans erreur, alors que `NotificationLog` les compte comme envoyées (`NotificationEngine.swift:255-268`) et que `center.add` est appelé avec `try?` (`SmartReminders.swift:101`) : le plafond quotidien peut être faussé.
- Correction : limiter le plan à 64 moins les demandes hors préfixe et ne journaliser que les demandes acceptées.

### W-13 Mineur : widgets après fin d'abonnement
- Preuve : `TimelinePlanner` ne place aucune entrée à `expirationDate + gracePeriod` (`Widgets/DesignProvider.swift:76-167`, `Settings.swift:215`). Un widget Premium garde son look jusqu'au prochain rechargement (minuit pour beaucoup de kinds). Impact faible (quelques heures).

### W-14 Mineur : textes non traduits
- `Shared/Render/AccessoryViews.swift:56` : `"SEM."` n'est pas passé par `tr()` (les autres unités de la même fonction, oui).
- `Shared/Intents/DesignIntent.swift:7` : `"Widget Ardane"` (type d'entité visible dans Raccourcis) absent de `Localizable.xcstrings`.

### W-15 Mineur : réseau pendant l'instantané et délais longs
- `DesignProvider.snapshot` charge avec `allowNetwork: true` pour un design enregistré même dans la galerie (`Widgets/DesignProvider.swift:33-38`), alors que `MyWidgetsProvider` l'évite en aperçu (`QuickWidget.swift:35`). Les requêtes ont des délais de 12 à 15 s (`CryptoService.swift:85`, `Companies.swift:96`, `Portfolio.swift:263,318`), enchaînés pour une liste de cours : la chronologie peut dépasser le temps accordé à l'extension. À confirmer sur iPhone (journal `WidgetLog`).
- Correction : `allowNetwork: !context.isPreview` dans `DesignProvider.snapshot` ; délai global (8 s) dans `PayloadLoader.load`.

### W-16 Mineur : enregistrement du Studio, double appui et fermeture
- `WidgetStudio.save` n'est pas protégé contre le double appui (`EditorView.swift:664-689`, bouton `:595` ; `TapGuard` existe dans `App/Components/Pressable.swift:29-43`) : le second appel ne duplique pas le widget (même identifiant, `AppModel.save:298`) mais appelle deux fois `celebrate()` et refait `router.saveFlight`.
- Un nouveau widget se ferme par glissement sans confirmation (`interactiveDismissDisabled(hasChanges && !isNew)`, `EditorView.swift:102`) : le travail est perdu sans avertissement.
- Correction : `TapGuard` dans `save()` ; confirmation « Abandonner » aussi pour un nouveau widget modifié.

### W-18 Mineur : design choisi dans une taille qu'il ne propose pas
`MyWidgetsChoice.resolve` renvoie le design configuré sans vérifier `design.families.contains(family)` (`Shared/Intents/DesignIntent.swift`, fonction `resolve`) ; seul le repli `latest` filtre par taille. Un design moyen choisi dans « Modifier le widget » d'un petit widget est dessiné à une taille non prévue. Correction : dans `resolve`, si le design configuré ne tient pas dans la famille, utiliser le repli.

---

## Améliorations

### W-17 Tests manquants
Aucun test pour `TimelinePlanner`, `WidgetLinks.url`, `Router.handle`, `NotificationScheduler`, ni `SharedStore` avec fichier illisible. Seul `testDeepLinkRoundTrip` existe (`Tests/CoreLogicTests.swift:103`). Proposer `TimelinePlannerTests` (jamais d'entrée vide, premier instant = `now`, politique au plus tard minuit pour les kinds quotidiennes), `WidgetLinksTests`, `RouterDeepLinkTests` (design supprimé, espace inconnu), `SharedStoreCorruptionTests`, `NotificationSchedulerTests`.

### W-19 Le widget d'un design supprimé affiche un autre widget de l'utilisateur
Voulu (commentaire `QuickWidget.swift:42-48`), mais l'utilisateur peut y voir un défaut ; envisager une carte « Widget supprimé, touche pour en choisir un ».

---

## Examiné et trouvé sain
- Lien profond : `DeepLink` (aller-retour, hôtes inconnus renvoient nil, UUID invalide refusé), `Router.handle` (design supprimé vers « Mes widgets », espace inconnu vers Espaces, premium vers le paywall, scanner), `WidgetLinks.url` (verrou Premium vers le paywall, mini-app vers son espace, calendrier sans accès vers l'autorisation).
- Familles : chaque groupe de widgets d'écran verrouillé a au moins une famille accessoire (vérifié par script sur `KindCatalog` et `WidgetGroup`) ; `QuickWidget` limité à petit, moyen, grand ; `supportedFamilies` jamais vide ; `WidgetCanvas` couvre accessoire, combiné, photos, citation, verrou Premium et cas par défaut `TileView` ; placeholder, instantané et chronologie existent pour les deux fournisseurs ; chronologies jamais vides (`ScheduleGlance.transitions` inclut `now`).
- Widgets interactifs : `IntentButton` inerte dans les aperçus, actif dans l'extension ; les intents écrivent par `updateContent` ou `update` (verrou récursif, refus si illisible) puis `reloadAllTimelines`.
- Stockage : écritures `.atomic` avec protection `completeUntilFirstUserAuthentication`, `relaxFileProtection` au premier plan, un fichier par domaine (l'extension n'écrit pas `designs`), `ImageStore` refuse les noms hors format UUID, photos réduites à 900 ou 1200 px et vignettes à la taille de la cellule, aucun Core ML dans `Shared/` et `Widgets/`, groupe d'App de repli, décodage tolérant des champs (`value`, `WidgetDesign.init(from:)`), rechargement du disque à chaque passage au premier plan, observateurs des écritures externes (séance, étude, budget).
- Studio : `needsPremium`, `savedDesigns` et `exceedsFreeLimit` empêchent d'enregistrer un style, fond, police ou couleur Premium sans Premium ; limite de 3 widgets (`fitsFreePlan`, photos et citations exclues) appliquée au Studio, au duplicata et à la fusion ; photos importées supprimées si non gardées (`StudioPhotoSession`) ; modification d'un widget posé : même identifiant et rechargement.
- Notifications : permission demandée seulement sur action, permission refusée : `forgetPending` et rien de programmé, plage de silence, plafond quotidien, espacement, identifiants stables donc pas de doublons, nettoyage des orphelins après synchronisation, annulation des jours J à la suppression d'un widget.
- Fonds d'écran : accès Photos en ajout seul, états refusé, échec, enregistré, texte d'usage présent.
- Aucun TODO ni FIXME dans `App/`, `Shared/`, `Widgets/` ; aucun texte visible hors `tr()` dans mon périmètre (hors W-14) ; `DebugPremium` compilé hors Release (check_swift.py OK).
