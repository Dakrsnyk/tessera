# Audit 24.K : Premium / StoreKit, onboarding, tutoriel, Profil et réglages (2026-11-07)

Méthode : lecture statique du code (pas de Mac, aucune exécution). Rien ne prouve ici que le code compile ou que les tests passent ; seule la CI le prouve. `python3 scripts/check_swift.py` lancé : OK (sécurité Release et build interne vérifiés).

## Synthèse par gravité
- Bloquant : 0
- Majeur : 2 (K-01, K-02)
- Mineur : 7 (K-03 à K-09)
- Amélioration : 4 (K-10 à K-13)
- 7.A : la demande est périmée (voir en fin de rapport).

## Constats

### K-01 (Majeur) Période de grâce de facturation : Premium retiré trop tôt
- `App/Premium/PremiumStore.swift:142` : un abonnement n’est actif que si `expirationDate > Date()`.
- Preuve : pendant la période de grâce (échec de paiement, accès conservé par Apple), `Transaction.currentEntitlements` renvoie encore la transaction mais son `expirationDate` est déjà passée. Le code la rejette, met `isActive = false` (l. 148) et `updatePremium` l’écrit. La tolérance de 3 jours de `PremiumState.hasPurchase` (`Shared/Model/Settings.swift:215`) ne sert alors à rien : elle ne joue que si le cache n’est jamais rafraîchi.
- Impact : un abonné dont la carte est refusée perd Premium aussitôt, alors qu’Apple lui garde l’accès (jusqu’à 16 jours) ; plaintes et remboursements.
- Reproduction : sandbox, abonnement avec « Billing Grace Period » activé, échec de renouvellement, ouvrir l’app. À confirmer en sandbox.
- Correction : pour un abonnement, ne pas exiger `date > Date()` ; se fier à la présence dans `currentEntitlements` (Apple retire l’abonnement réellement expiré) et à `revocationDate == nil`. Ou lire `Product.SubscriptionInfo.status(for:)` : actif si `.subscribed`, `.inGracePeriod`, `.inBillingRetryPeriod`. Garder `expirationDate` seulement pour l’affichage.
- Test : extraire le calcul (transactions vers `PremiumState`) en fonction pure et tester : expiré, en grâce, révoqué, à vie, plusieurs formules. Test StoreKit : `SKTestSession` avec `expireSubscription(productIdentifier:)`, `refundTransaction`, période de grâce, puis `refreshEntitlements()`.

### K-02 (Majeur) Essai gratuit affiché périmé (promesse fausse sur le paywall)
- `App/Premium/PremiumStore.swift:58` : `isIntroEligible` n’est calculé que dans `loadProducts()`, appelé au démarrage puis seulement si `products.isEmpty` (`PaywallView.swift:60`). Jamais recalculé après un achat, une expiration ou une restauration.
- Preuve : après un essai gratuit puis résiliation, l’app ouverte longtemps affiche encore « Essayer 7 jours gratuits » et « Rien n’est débité pendant l’essai » (`PaywallView.swift`, `terms(for:)` et `purchaseButton`), alors qu’Apple débitera. Texte trompeur (règle App Review 3.1.2) même si la feuille Apple montre le vrai prix.
- Correction : recalculer `isIntroEligible` à chaque ouverture du paywall (`.task` de `PaywallView`) et à la fin de `refreshEntitlements()`.
- Test : `SKTestSession` (acheter le mensuel avec essai, expirer, vérifier que `isEligibleForIntroOffer` devient faux et que `introDescription` renvoie nil après rafraîchissement).

### K-03 (Mineur, Majeur si le quota compte pour le revenu) « Effacer toutes mes données » remet les 10 analyses gratuites à zéro
- `App/Core/AppModel.swift:690` (`nutrition = NutritionState()`) et `:679-681` (suppression du fichier `.nutrition`) ; le compteur `photoScansUsed` (`Shared/Domains/Nutrition.swift:691`) est dans cet état. Même effet avec « Restaurer une sauvegarde » ancienne (`App/Core/DataBackup.swift:28` contient `.nutrition`).
- Impact : contournement du quota gratuit (`Shared/Domains/ScanQuota.swift`) en un geste. La réinstallation le remet aussi à zéro (limite connue d’un compteur local).
- Correction : stocker le compteur hors des données effaçables (Keychain, qui survit à la réinstallation) ; au minimum conserver `photoScansUsed` dans `resetAllData` et, dans `restore(_:)`, prendre le maximum entre la valeur actuelle et celle de la sauvegarde.
- Test : `resetAllData()` puis `photoScansUsed` inchangé ; restauration d’une sauvegarde à compteur 0 sur un état à 7 : reste 7.

### K-04 (Mineur) « Effacer toutes mes données » n’est pas complet
- `App/Core/AppModel.swift:655-710` n’efface pas : les styles enregistrés « Mes styles » (`StoreFile.styles` : ni `store.remove(.styles)` ni `savedStyles = []`, `savedStyles` est lu en `AppModel.swift:103`), l’historique des pas (`StepCounter.historyKey` dans `UserDefaults.standard`, sauvegardé par `DataBackup.swift:41`), les compteurs d’usage et masquages des mini-apps (`App/Screens/Home/MiniAppsRow.swift:10-27`), l’icône alternative de l’app.
- Impact : le dialogue promet « Tes widgets, tâches, habitudes et montants seront supprimés » ; l’historique de pas reste visible dans Mon Quotidien après « tout effacer » : écart avec la politique de confidentialité.
- Correction : ajouter `store.remove(.styles)` et `savedStyles = []`, supprimer la clé `StepCounter.historyKey` de `UserDefaults.standard`, nettoyer `MiniAppUsage`, revenir à l’icône par défaut. Écrire dans le dialogue ce qui est conservé.
- Test : état rempli, `resetAllData()`, vérifier que chaque `StoreFile` et clé `UserDefaults` est vide (liste tirée de `StoreFile` pour qu’un futur fichier oublié fasse échouer le test).

### K-05 (Mineur) Limite d’habitudes : bouton « + » muet à la limite
- `App/Screens/Profile/DataItemViews.swift:144` et `App/Screens/Profile/ProfileTopics.swift:553` : `guard model.canAddHabit else { return }` sans rien dire ; `quickAdd` vide ensuite le champ (`DataItemViews.swift:383-389`). Le texte saisi disparaît, aucune habitude créée, aucun paywall (contraste avec `HabitsView.swift:58-62` qui ouvre `.habitLimit`).
- Reproduction : version gratuite avec 5 habitudes, « Mes informations » > Bien-être, taper une habitude, « + ».
- Correction : ouvrir `PaywallContext.habitLimit` au lieu de `return` et ne pas vider le champ. La limite n’est appliquée que dans l’interface : créer un `AppModel.addHabit(_:)` avec la garde, utilisé par les trois points d’entrée (`HabitsView.swift:285`, `DataItemViews.swift:145`, `ProfileTopics.swift:554`).
- Test : `AppModel` gratuit à 5 habitudes, `addHabit` renvoie nil ; avec Premium, il ajoute.

### K-06 (Mineur) Écoute de `Transaction.updates` démarrée trop tard
- `App/ArdaneApp.swift:35-36` : `premium.start(model:)` est dans le `.onAppear` de `RootView`. Si le processus est lancé sans interface, les transactions en attente (Ask to Buy approuvé, renouvellement, remboursement) ne sont ni terminées ni prises en compte avant la première apparition de l’écran. Apple demande d’écouter dès le lancement.
- Correction : appeler `start` depuis `ArdaneApp.init()` ou une `.task`.
- Test : `SKTestSession` avec effacement des transactions, achat hors paywall, vérifier que `refreshEntitlements` suit.

### K-07 (Mineur) Chaque retour au premier plan réécrit le statut et recharge tous les widgets
- `App/Premium/PremiumStore.swift:155` : `state.verifiedAt = Date()` rend `state != premium` toujours vrai ; `AppModel.swift:476-480` (`updatePremium`) écrit le fichier et appelle `scheduleWidgetReload()` à chaque activation (`ArdaneApp.swift:71`).
- Impact : budget de rechargement des widgets et écritures inutiles.
- Correction : comparer sans `verifiedAt`, ou ne l’écrire que si le reste change.

### K-08 (Mineur) Date de naissance incohérente entre onboarding et Profil
- `App/Screens/Profile/ProfileView.swift:416` enregistre « il y a 25 ans » (heure comprise) et le sélecteur enregistre la date telle quelle ; l’onboarding normalise avec `DateMath.startOfDay` (`OnboardingView.swift`, `birthDate`). Un âge de 25 ans est enregistré sans choix de la personne (donnée fictive si elle quitte l’écran).
- Correction : `DateMath.startOfDay(...)` aux deux endroits ; idéalement ne rien enregistrer tant qu’une date n’est pas choisie.

### K-09 (Mineur) Erreurs d’achat brutes
- `App/Premium/PremiumStore.swift:87` : `.failed(error.localizedDescription)` : texte système non maîtrisé. Les cas `StoreKitError.networkError` et `.notAvailableInStorefront` ne sont pas traduits en messages de l’app.
- Correction : `switch` sur `StoreKitError` vers des `tr("…")` ; description système en dernier recours.
- Test : fonction pure `message(for:)` testée sur les cas ; `SKTestSession` avec échec de transaction activé.

### K-10 (Amélioration) Lien Conditions et fiche App Store incohérents
- `App/Premium/PremiumConfiguration.swift:11` : Conditions = EULA standard d’Apple, alors que `docs/lancement/fiche-app-store.md:49` annonce `https://ardane.app/terms.html` (absent de `docs/legal/`). Le lien de l’app et celui de la fiche (champ EULA) doivent désigner le même texte, en ligne.
- Correction : garder l’EULA Apple partout (aucune EULA personnalisée dans App Store Connect) ou publier `terms.html` et pointer `termsURL` dessus.

### K-11 (Amélioration) Assistance : adresse copiée, pas de lien utilisable
- `App/Screens/Profile/ProfileView.swift` (bouton « Contacter le support », section Aide) copie l’adresse dans le presse-papiers. La fiche annonce `https://ardane.app/support.html` ; l’app ne l’ouvre pas. Proposer un `Link` `mailto:` (version de l’app en objet) et le lien web.

### K-12 (Amélioration) `PremiumConfiguration.appStoreID` reste `nil`
- `App/Premium/PremiumConfiguration.swift:17` : « Noter Ardane » (`ProfileView.swift`, `rate()`) retombe sur `requestReview()`, souvent sans effet lorsqu’on le déclenche à la main. À renseigner après la création de la fiche (checklist de publication).

### K-13 (Amélioration) Donnée écrite et jamais lue
- `App/Screens/Onboarding/PermissionsSetupStep.swift:16-18` : `markSeen` écrit `permissionsSetupSeen` ; le commentaire dit que rien ne le lit. Supprimer, ou l’utiliser pour ne pas réafficher la page chez les installations existantes.

## 7.A : échec ouvert `testFirstLaunchAsksOnlyWhatMattersAndFillsMesInformations`
- Cause de l’échec du 2026-10-25 : à cette date, la page Nutrition était la DERNIÈRE de l’onboarding ; sa barre fixe (`OnboardingView.swift`, bouton « C’est parti » en `safeAreaInset`) se trouve juste au-dessus du pavé numérique. Un toucher XCUITest sur un champ (âge, taille) masqué par la barre déclenchait « C’est parti » et terminait l’onboarding : d’où l’accueil et le tutoriel dans la capture. Ce n’est pas une régression de l’app : aucun chemin de code ne termine l’onboarding ailleurs que `advance()` sur la dernière étape ou `skip()` ; `isLast` ne vaut vrai que sur `.permissions` quand la liste des étapes est complète (`OnboardingView.swift:33-37`).
- Deux changements postérieurs ont déjà traité la cause : `f1ffd6bd` (2026-10-25, `tapClear(aboveBar:)` et `assertStillOnNutritionPage` dans `UITests/ProfileUITests.swift:57-98`, qui nomme l’étape fautive) et `863c89c5` (2026-10-30, page Autorisations ajoutée après la dernière rubrique : un mauvais toucher n’arrête plus l’onboarding, et le test fait deux « Passer »).
- La ligne 85 de `Demandes.md` (et `Pieges-connus.md:65`) décrit un état ancien. Reste À CONFIRMER par la CI : que `nutrition-targets` (`NutritionTargetsCard.swift:99`, conteneur `.accessibilityElement(children: .contain)`) soit trouvé par `descendants(matching: .any)`. Seul le rapport du prochain `[daily]` le tranche ; sinon joindre `diagnostic-nutrition-targets`.

## Examiné et trouvé sain
- StoreKit : identifiants `PremiumConfiguration.swift:6-8` identiques à `Config/Ardane.storekit` (monthly, yearly, lifetime) ; un seul groupe, l’annuel au-dessus du mensuel ; essai 7 jours sur les deux formules ; `Transaction.updates` avec `finish()` sur transaction vérifiée ; achat non vérifié refusé ; annulation silencieuse ; attente (Ask to Buy) expliquée ; `revocationDate` exclu ; remboursement de l’achat à vie couvert (retiré de `currentEntitlements`) ; restauration par `AppStore.sync`, annulation silencieuse, échec réseau distinct de « rien trouvé » (`PremiumStore.swift:103-114`) ; produits introuvables : état `.failed` avec « Réessayer » ; prix par `displayPrice`, équivalent mensuel par `priceFormatStyle` ; bouton d’achat désactivé pendant un achat ; achat à vie sans promesse de renouvellement ; mentions de renouvellement, d’annulation 24 h, de gestion dans les réglages App Store, liens Conditions et Confidentialité présents (`PaywallView.swift`, `legal`) ; « Gérer l’abonnement » par `manageSubscriptionsSheet`, masqué pour l’achat à vie.
- Le fichier `.storekit` n’est pas embarqué dans le binaire (référencé par le schéma seulement, `Ardane.xcscheme:78`).
- DEBUG et INTERNAL_PREMIUM : `DebugPremium` et `SignedEntitlements` entièrement dans `#if DEBUG` ; `Settings.swift:225-234` : déblocage seulement sous `DEBUG` ou `INTERNAL_PREMIUM`, sinon `hasPurchase` ; `check_swift.py` interdit `INTERNAL_PREMIUM` dans le projet et hors `[interne]` ; la CI vérifie que la chaîne « en mode test » est absente du binaire `[testflight]` (`build.yml:166-172`). Rappel hors code : l’IPA de test des Releases publiques est un build Debug avec Premium débloqué par défaut (non signé, installable seulement par sideload).
- Droits côté logique : `AppModel.canSave`, `fitting`, `duplicate` (3 widgets comptés, photos et citations exclus), `setStyle` (un style Premium n’est jamais enregistré hors Premium), `ExerciseLibrary.isOpen`, `PhotoScanQuota.canAnalyze` (garde dans `analyze`, compte seulement une analyse réussie), icône d’app (`AppIconChoice.isLocked`). Rendu : `WidgetCanvas.displayedDesign` / `downgradedForFree` et `PremiumLockedView` s’appliquent dans l’extension (`DesignProvider`, `QuickWidget` lisent le cache de l’App Group) ; un design Premium enregistré garde ses réglages et s’affiche dégradé sans perte. Liens profonds (`DeepLink.swift`) : ils ouvrent seulement des écrans. Aucun App Intent ne crée de contenu Premium.
- Expiration : rien n’est supprimé (widgets, habitudes au-delà de 5, style, icône conservés ; seul l’affichage change).
- Aucun écran de connexion, déconnexion, création ou suppression de compte (recherche textuelle sans résultat) ; textes « Aucun compte » cohérents.
- Onboarding : chaque réponse est enregistrée à la saisie ; quitter en plein milieu puis relancer redémarre au premier écran avec les réponses déjà là ; « Passer » à chaque étape ; aucune demande d’autorisation avant la page Autorisations (les appels de `requestAuthorization` suivent un geste ou une carte explicative) ; autorisation refusée : « Ouvrir Réglages », jamais de nouvelle demande ; tutoriel relancé jusqu’à sa fin ou « tout passer » (`hasSeenTutorial`, `TutorialOverlay.swift:270`) et rejouable depuis Profil.
- Réglages : unités, 24 h, devises, rappels (repas, séance, factures, intelligents), apparence, couleur, icône, jours fériés ont chacun un effet lu dans l’app ; `updateSettings` replanifie les rappels et recharge les widgets ; sauvegarde et restauration confirmées par dialogue, fichier validé avant remplacement, version plus récente refusée ; Premium absent de la sauvegarde ; liens Confidentialité et Conditions et crédits des sources alimentaires présents.
- Aucun `TODO` / `FIXME` dans `App/`, `Shared/`, `Widgets/`. Section Développeur sous `#if DEBUG`.

## Non examiné en détail
- `LaunchView.swift`, `TutorialOverlay.swift` (placement des cadres), `SmartRemindersView.swift` ligne par ligne, traductions des chaînes du paywall dans `Localizable.xcstrings`.
- Comportement réel des invites système, de StoreKit et du bac à sable : exige l’iPhone.

## Tests de non-régression à ajouter (récapitulatif)
1. `PremiumEntitlementTests` : calcul pur des droits (K-01) et `SKTestSession` (achat, essai, expiration, remboursement, grâce, Ask to Buy, échec de transaction, restauration).
2. `ResetAllDataTests` : tous les `StoreFile` et clés `UserDefaults` couverts (K-03, K-04).
3. `HabitLimitTests` : `AppModel.addHabit` refuse au-delà de 5 sans Premium (K-05).
4. Test d’interface : paywall depuis « + » d’habitude à la limite (K-05).
