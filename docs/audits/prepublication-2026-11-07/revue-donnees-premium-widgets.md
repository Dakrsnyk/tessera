# Revue indépendante : données, Premium, widgets et notifications (audit 24)

Rien n'a été compilé ; `check_swift.py` : OK (3351 appels vérifiés).

## Lot 1 – Données (W-02 / M-07) : OK avec réserves
Vérifié : `update`/`updateContent` laissent un fichier illisible intact (le test existant passe sur le papier) ; copie dans `Recovery/` avant écrasement ; pas de verrou imbriqué dangereux (`updateLock` récursif, puis `lock`) ; surcharge `value(_:_:)` sans ambiguïté (tous les appels `[]`, `[:]`, `[String]()` résolus) ; l'app se répare via `store.content = …` (pas `update`).
À corriger avant fusion :
- `Shared/Model/LossyList.swift:12-17` : `LossyList` (fichier `designs`, la donnée la plus précieuse) ne signale pas `LossyDecoding.noteLoss()`. Un widget illisible est écarté sans copie, puis écrasé à la sauvegarde suivante. Ajouter `LossyDecoding.noteLoss()` dans le `else`.
- `App/Core/AppModel.swift:716-745` (`resetAllData`) : le dossier `Recovery/` n'est pas effacé ; « tout effacer » laisse des copies des données. Ajouter une méthode `SharedStore.removeRecovery()` appelée ici.
Souhaitable : `SharedStore.swift:152` `write` relit tout le fichier à chaque écriture (coût double) ; un `fileExists` + lecture d'un octet suffirait.

## Lot 2 – Premium : OK avec réserves
API StoreKit 2 vérifiées (`Transaction.subscriptionStatus`, `RenewalInfo.gracePeriodExpirationDate`, `.inGracePeriod`, `StoreKitError`, `Product.PurchaseError`). Achat à vie inchangé. Écoute lancée une fois par instance (`@State` dans l'App).
À corriger avant fusion :
- `App/Premium/PremiumConfiguration.swift:14` : `termsURL` pointe sur `https://ardane.app/terms.html`, absent de `docs/legal/` (seul `privacy.html` existe). Lien mort possible à la revue (règle 3.1.2). Publier la page, ou revenir à l'EULA Apple.
Souhaitable :
- `PremiumStore.swift:~77-111` : 7 nouveaux textes `tr()` absents de `Localizable.xcstrings` (affichés en français dans les autres langues). Lancer extract/merge/build.
- `Tests/Audit24PremiumTests.swift` : le test d'éligibilité dépend de `Config/Ardane.storekit` (skip si illisible) ; correct, mais `Tests/PremiumStoreKitTests.swift` et ce fichier sont non suivis par git.

## Lot 3 – Widgets et notifications : OK avec réserves
Vérifié : `switch` de `NotificationRoute` exhaustif sur `NotificationEngine.Kind` (23 cas) ; `Space`, `DeepLink`, `Encouragements` sont dans `Shared/` ; `AppOpenRequests` est lu au lancement (`initial: true`) ; `TapGuard`, `ImageStore.data/restore`, `partDesigns` existent ; textes de `HomeSetupViews` déjà localisés.
Aucun bloquant. Souhaitable :
- `NotificationScheduler.swift:~50-60` (`add`) : chaque `Task` lit `pending` avant les ajouts des autres (boucle `AppModel.swift:709`) ; le plafond de 64 peut être dépassé de quelques unités (4 places de réserve). Sérialiser les ajouts.
- `AppModel.swift:311/336` : `sync` puis `cancel` rapprochés : le `Task` d'ajout passe après l'annulation et laisse un rappel orphelin.
- `Combo.swift:137` : `merge` copie la photo par défaut (`ScreenshotMode` y fuit un fichier par appel) ; inoffensif hors captures.
Tests : exercent le vrai code, sans état global partagé (compteur `LossyDecoding` remis à zéro en début de test).

Hors périmètre : rien constaté dans les fichiers relus (`StripeSync.swift` modifié, non demandé ici).
