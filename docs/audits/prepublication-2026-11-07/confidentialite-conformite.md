# 24.P — Confidentialité, conformité légale et règles d'Apple (audit du 2026-11-07)

Auteur : research-architect (lecture seule ; seul ce rapport a été écrit). Ce rapport n'est PAS un avis juridique : les points marqués « Juriste » doivent être validés par un avocat (Québec) ou un conseiller en protection des renseignements personnels.

Légende : **documenté** = lu dans une source officielle citée ; **constaté** = lu dans le code ou le dépôt (`fichier:ligne`) ; **supposé** = jugement non vérifié (dit explicitement). Pas de Mac : rien n'a été exécuté sur iPhone ; seule la CI prouve compilation et tests.

Pages Apple lues le 2026-11-07 : App Review Guidelines (https://developer.apple.com/app-store/review/guidelines/ ; 100 000 premiers caractères sur 114 428, la fin de 5.2.5 n'a pas été lue), App Privacy Details (https://developer.apple.com/app-store/app-privacy-details/), Age ratings (https://developer.apple.com/help/app-store-connect/reference/app-information/age-ratings-values-and-definitions ; libellés exacts des options non lus), App Information (https://developer.apple.com/help/app-store-connect/reference/app-information/app-information), Manage App Privacy (https://developer.apple.com/help/app-store-connect/manage-app-information/manage-app-privacy), Enrollment (https://developer.apple.com/support/enrollment/). La page « platform version information » a renvoyé une 404 : les limites de la version viennent de la fiche du dépôt et de ma connaissance générale (supposé).

---

## 1. Inventaire réel des données (constaté dans le code)

Aucune dépendance tierce : `project.pbxproj` ne contient aucun `XCRemoteSwiftPackageReference` → pas de SDK d'analyse, de pub ou de plantage. Aucune exception ATS (`Config/App-Info.plist`), aucun `WKWebView`/`SFSafariViewController`/`AsyncImage`, aucune URL `http://`. Entitlements : App Group seul (`Config/Ardane.entitlements`, `Config/ArdaneWidgets.entitlements`) ; ni HealthKit, ni iCloud/CloudKit, ni position, ni push.

### 1.1 Où sont stockées les données

| Donnée | Pourquoi | Où | Durée | Envoyée à |
|---|---|---|---|---|
| Widgets, réglages, tâches, habitudes, horaires, études, repas, séances, budget, entreprise, placements, voyage, auto, ma vie, profil (année de naissance, taille, poids, historique de poids, sexe, détail du genre, objectifs), styles | Fonction de l'app et des widgets | Un JSON par domaine dans `<App Group>/Tessera/*.json` (`Shared/Support/SharedStore.swift:80-93, 217`), protection `completeUntilFirstUserAuthentication` (`SharedStore.swift:101`) | Jusqu'à effacement ou désinstallation | Nulle part |
| Photos de fond de widget et de « Photos et citations » (JPEG réduit à 900 ou 1 200 px) | Fond de widget | `<App Group>/Tessera/Images/<UUID>.jpg` (`SharedStore.swift:240-263`) ; seuls appelants de `ImageStore.save` : `EditorView.swift:702`, `PhotoQuotesApp.swift:376` | Jusqu'à suppression du widget ou effacement | Nulle part |
| Mémoire visuelle du scanner (vecteurs de nombres + aliments validés, max 400) | Mieux reconnaître vos plats | `PersonalFoodMemory.json` (`Shared/Domains/Scanner/ScannerPersonalMemory.swift:176-250`) | Jusqu'à effacement | Nulle part |
| Corrections du scanner (étiquettes, aliments, grammes ; max 500) et empreintes de repas | Apprentissage local | Dans `nutrition.json` (`Shared/Domains/ScanLearning.swift:50-100`, `MealMemory.swift:30-58`) | Jusqu'à effacement | Nulle part |
| Historique des pas, distance, étages | Mon Quotidien, Fitness | `UserDefaults.standard`, clé `stepHistory` (`App/Core/StepCounter.swift:82-92`) | NON effacé par « Effacer toutes mes données » (P-05) | Nulle part |
| Journaux de notifications, d'encouragements, d'avis, du widget | Limiter la fréquence des rappels | `UserDefaults(suiteName: App Group)` (`NotificationEngine.swift:72`, `Encouragements.swift:391`, `ReviewPrompt.swift:231`, `WidgetDiagnostics.swift:13`) | Les deux premiers remis à zéro par l'effacement ; celui des avis gardé exprès (`AppModel.swift:705-708`) | Nulle part |
| Compteurs d'usage des mini-apps, favoris, mini-apps masquées, « permission déjà expliquée » | Interface | `UserDefaults.standard` (`MiniAppsRow.swift:10-27`, `HomeSetupViews.swift:470`, `PermissionExplainer.swift:45-55`) | Non effacés (non personnels) | Nulle part |
| Droit Premium (produit, expiration, vérification) | Débloquer Premium | `premium.json` ; vérifié avec StoreKit | Conservé à l'effacement (voulu, `AppModel.swift:654`) | Apple (StoreKit) |
| Clé Stripe restreinte (facultatif) | Business › Stripe | Keychain `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly` (`App/Services/StripeSync.swift:15`) ; indice « …1234 » dans `business.json` | Voir P-06 | `api.stripe.com` seulement |
| Photos de plat, photos et PDF d'horaire, fichiers de ventes importés | Analyse ponctuelle | Mémoire seulement, jamais écrits (§2) | Supprimés à la fin de l'analyse | Nulle part |
| Fonds d'écran du Store enregistrés | Choix de l'utilisateur | Photothèque de l'utilisateur, accès « ajout seulement » (`HomeSetupViews.swift:774`, `WallpaperCollection.swift:383`) | Hors du contrôle d'Ardane | Nulle part |
| Sauvegarde exportée (JSON en clair) | Portabilité | Fichier choisi par l'utilisateur (`App/Core/DataBackup.swift:25-48`, `ProfileView.swift:235`) | Hors du contrôle d'Ardane | Nulle part |

Calendrier (lecture seule, `Shared/Data/CalendarService.swift:25-70`) et podomètre (`CMPedometer`, `StepCounter.swift:11`) sont lus à l'affichage. Résumés Apple Intelligence : `FoundationModels` sur l'appareil (`App/Services/AIPhraser.swift:2-27`). Aucun `HealthKit`, `CLLocationManager`, `ATTrackingManager`, `identifierForVendor` ni identifiant publicitaire (grep `App/`, `Shared/`, `Widgets/`).

### 1.2 Chaque appel réseau (constaté ; tout part de l'iPhone, sans compte)

Tous en HTTPS, sans nom ni courriel ni identifiant d'appareil. Chacun voit l'adresse IP et l'en-tête standard.

| Service | Code | Ce qui est envoyé | Déclencheur |
|---|---|---|---|
| Open Food Facts (`world.openfoodfacts.org/api/v3/product/<code>`, `search.openfoodfacts.org/search`) | `Shared/Domains/FoodDatabase.swift:377-400, 677` | Code-barres (chiffres seulement : `productURL` refuse le reste) ou texte tapé ; `User-Agent: Ardane/<version> (support.ardane@gmail.com)` (`Companies.swift:13-14`) | Scan ou recherche demandés |
| CoinGecko (`/coins/markets`, `/global`) | `Shared/Domains/Portfolio.swift:262-296`, `Shared/Data/CryptoService.swift:76-93` | Identifiants des cryptos suivies (watchlist/portefeuille), devise ; en-tête `x-cg-demo-api-key` seulement si la clé est renseignée (elle est vide : `project.pbxproj:388,431`) | Ouverture de l'app ET rafraîchissement automatique des widgets (P-09) |
| Finnhub (`/api/v1/quote`) | `Portfolio.swift:314-320` | Symbole + jeton dans l'URL | Inactif : `FINNHUB_API_KEY = ""` (`project.pbxproj:395,437`), aucun secret dans `.github/` → `stockKey` nil (`Portfolio.swift:216-218`), aucune requête ne part |
| SEC EDGAR (`data.sec.gov/api/xbrl/...`, `www.sec.gov/files/company_tickers.json`) | `Shared/Domains/Companies.swift:113, 190` | CIK de l'entreprise suivie ; User-Agent avec l'adresse de support (exigé par la SEC) | Sociétés cotées, widgets compris |
| Frankfurter (`api.frankfurter.dev/v1/latest`, historique) | `Shared/Domains/Travel.swift:324, 421` | Devise de base, devises, dates | Voyage, conversions Stripe/Apple Pay |
| Stripe (`api.stripe.com/v1/balance_transactions`) | `StripeSync.swift:194-201` | Clé restreinte (`Authorization: Bearer`), bornes de dates ; session `.ephemeral`, sans cache ni cookies (`:51`) | Seulement si la personne a connecté son compte |
| Apple CLGeocoder | `App/Screens/Spaces/TravelCarLifeSpaces.swift:18` | Nom de ville tapé | Recherche de ville (Voyage, Auto) |
| Apple StoreKit / App Store | `App/Premium/*` | Achats, restauration | Paywall |
| Open-Meteo, USDA | Aucun appel (météo retirée ; USDA et Santé Canada = tables locales, `NutrientFile.swift:5-10` ne contient que des liens de crédit) | — | — |

Les modèles Core ML sont chargés depuis le bundle (`FoodModelRecognizer.swift:176`, `Bundle.main.url(... "mlmodelc")`) : aucun téléchargement de code ni de modèle (2.5.2).

---

## 2. Scanner alimentaire : aucune photo de repas ne quitte l'iPhone (preuve par le code)

1. **Aucun code réseau dans le scanner.** `URLSession` n'apparaît que dans 6 fichiers (`FoodDatabase`, `Portfolio`, `CryptoService`, `Companies`, `Travel`, `StripeSync`). Aucune occurrence de `URLSession|URLRequest|http` dans `Shared/Domains/Scanner/`, `App/Screens/MiniApps/Nutrition/` et `App/Services/ScheduleImport/` (hors liens de crédit de `NutrientFile.swift`).
2. **Chemin de la photo.** Caméra (`DataScannerViewController`, `FoodScanView.swift:202, 470-490`) ou `PhotosPicker` sans accès à la photothèque (`FoodScanView.swift:353-362`) → `UIImage` en mémoire → `MealAnalysisConfig.makeAnalyzer().analyzeMeal(image)` (`:374`) → `OnDeviceMealAnalyzer` (Vision `VNClassifyImageRequest` + deux modèles Core ML du bundle, `MealPhotoAnalysis.swift:75-110`), sur une copie de 1 024 px max.
3. **Le chemin « en ligne » est mort.** `MealAnalysisConfig.onlineEnabled = false` (`MealPhotoAnalysis.swift:70`) ; `OnlineMealAnalyzer.analyze` ne fait que `throw .notEnabled` (`:89-93`), sans URL ni clé ; constante de code, pas un réglage (`:64-68`). Activer ce chemin exigerait de changer la politique, l'étiquette App Privacy et le manifeste.
4. **Gardé :** (a) la photo : jamais (aucun `jpegData`/`write` hors `ImageStore`, dont les appelants sont l'éditeur de widget et Photos et citations) ; (b) un vecteur de nombres par zone validée (`PersonalFoodMemory.json`, max 400) et une empreinte de repas (`nutrition.json`) ; (c) le journal des corrections `ScanLearning.corrections` (étiquettes, aliments, grammes, max 500) ; (d) un booléen `contributionEnabled`. **Effacé :** `resetAllData()` supprime `PersonalFoodMemory.json` (`AppModel.swift:683`), le fichier `nutrition` (`:679-680`) donc corrections et empreintes, et remet `nutrition = NutritionState()` (`:690`). L'export (`DataBackup.files`) contient `nutrition` mais pas `PersonalFoodMemory.json`.
5. **Journaux système :** seul le `Logger` du scanner écrit un nombre de zones et un message d'erreur de chargement des modèles (`MealPhotoAnalysis.swift:320-322`) : aucune donnée personnelle.
6. **Limite :** un vecteur visuel n'est pas une photo mais n'est pas démontré anonyme ; il reste sur l'appareil, la politique le dit (« empreinte visuelle … jamais la photo »), et il est dans la sauvegarde iCloud de l'iPhone (§4).

**Conclusion : confirmé par le code** pour la version actuelle : aucune photo de repas, d'horaire ou de fichier de ventes n'est envoyée. Garde-fou suggéré : un test (ou `check_swift.py`) qui échoue si `onlineEnabled` vaut `true` ou si `URLSession` apparaît dans ces trois dossiers.

---

## 3. Comparaison comportement réel / politique / manifeste / permissions

Politique : https://ardane.app/privacy.html, en ligne, version 3.0 du 29 octobre 2026 (HTTP 200 vérifié ; `terms.html` et `support.html` répondent aussi 200) ; la copie locale `ardane-site/privacy.html` est la même version.

### 3.1 `Shared/PrivacyInfo.xcprivacy`
- Suivi faux, domaines vides, données collectées vides : **cohérent** avec « Data Not Collected » (§7).
- UserDefaults `CA92.1` (app) et `1C8F.1` (App Group) : **cohérent** (`QuickWidget.swift:68-72`, `Encouragements.swift:391`).
- Horodatage de fichiers `C617.1` (métadonnées dans le conteneur de l'app/du groupe) : **cohérent** (`Companies.swift:186`, `SharedStore.swift:126`, `attributesOfItem`).
- Espace disque et démarrage du système : **aucune API de ces catégories dans le code** (aucun `volumeAvailableCapacity*`, `systemUptime`, `mach_absolute_time`, `stat`, `creationDate`, `contentModificationDate`) ; les seules métadonnées lues sont `fileSizeKey` (`BusinessSources.swift:181`, `ProfileView.swift:356`), non listées comme à raison obligatoire (supposé : liste d'Apple non relue). **Cohérent.**
- Extension : `Shared/` est un groupe synchronisé compilé dans les deux cibles ; la CI vérifie la présence du manifeste dans l'app ET dans `ArdaneWidgets.appex` (`.github/workflows/build.yml:872`). Je n'ai ouvert aucun IPA : constaté seulement pour le script de contrôle. Preuve complémentaire : aucun courriel Apple « ITMS-91053 » après les envois TestFlight (supposé).

### 3.2 Textes de permission
- App (`project.pbxproj:473-476`) : Calendrier (accès complet), Caméra, Mouvements, Photos « ajout seulement ». Pas de photothèque complète (`PhotosPicker`), pas de position.
- `App/InfoPlist.xcstrings` : 7 langues (fr, en, es, de, it, ja, pt-BR), tous « translated », aucune copie du français (vérifié par script) ; `knownRegions` = fr, en, es, de, it, pt-BR, ja (`project.pbxproj:267-276`). **Traduits dans les 6 langues cibles + fr : oui.**
- Texte de la caméra (« code-barres … ou photographier ton plat ») : exact, le scan d'horaire passe par le sélecteur (`ScheduleImportView.swift:170`).
- Moment de la demande : toujours après un toucher et un écran d'explication (`PermissionsSetupStep.swift:41-50` « Only called from the person's tap », `CameraAccessGate.swift:108`, `PermissionExplainer.swift`). Notifications aussi depuis les habitudes et l'éditeur (`HabitsView.swift:262`, `KindOptionsSection.swift:18`) ; Photos (ajout) à l'enregistrement d'un fond (`HomeSetupViews.swift:774`). **À l'usage, avec explication préalable, conforme à 5.1.1(ii)-(iv)** ; la carte d'autorisation de fin d'intégration est une demande anticipée, mais déclenchée par la personne.

### 3.3 Incohérences
Détail au §9 : notes de revue (P-07), chaîne de position résiduelle (P-10), « à ta demande » contre rafraîchissement des widgets (P-09), effacement incomplet (P-05, P-06, P-12), interrupteur « Contribuer » (P-04), copies périmées de la politique (P-11), liste des données du profil (P-16).

---

## 4. Effacement, désinstallation, sauvegarde

- **Dans l'app :** Profil › « Effacer toutes mes données » (`ProfileView.swift:260`, dialogue `:323-327`) → `AppModel.resetAllData()` (`AppModel.swift:655-710`) : supprime la clé Stripe, les photos référencées par les widgets, tous les fichiers de domaines, la mémoire du scanner, les notifications planifiées et les journaux ; conserve Premium, l'apparence, le prénom et le nom (`:664-673, 685-687`), le journal d'avis et les explications de permission (voulu, `:705-708`). Profil › « Exporter mes données » (`ProfileView.swift:235`) : JSON en clair. **Existe : oui, mais incomplet** (P-05, P-12).
- **Désinstallation :** le conteneur de l'App Group et `UserDefaults` disparaissent avec l'app (supposé : comportement standard d'iOS, non vérifié sur appareil) ; **le Keychain survit à la désinstallation** (comportement connu, non testé ici, aucune source Apple citée) → la clé Stripe peut réapparaître à la réinstallation (P-06). Fonds d'écran enregistrés dans Photos et sauvegardes exportées restent (choix de l'utilisateur).
- **Sauvegarde iCloud/ordinateur :** aucune exclusion dans le code (aucun `isExcludedFromBackup`) → santé, finances et profil sont dans la sauvegarde de l'iPhone gérée par Apple. La politique l'annonce (§2). La règle 5.1.3(ii) (« may not store personal health information in iCloud ») vise le stockage iCloud d'une app ; la sauvegarde d'appareil est faite par iOS (supposé non applicable). L'attribut `ThisDeviceOnly` de la clé Stripe l'exclut du transfert de sauvegarde (documenté par le nom de l'attribut).

---

## 5. Exigences légales : écarts et recommandations

L'éditeur ne reçoit pas les données de l'app (§1-2). Il détient réellement : les courriels du support (Gmail), les rapports agrégés d'Apple, l'identité du vendeur. Les exigences portent donc sur ces flux et sur la transparence. Numéros d'articles cités de mémoire : à valider par le juriste.

| Exigence | État / écart | Recommandation | Juriste ? |
|---|---|---|---|
| **Loi 25** (Loi sur la protection des renseignements personnels dans le secteur privé, RLRQ c. P-39.1) : responsable (art. 3.1) | Politique §1 et §15 : l'éditeur assume la fonction et donne un courriel. Le titre « responsable de la protection des renseignements personnels » devrait être publié avec ses coordonnées : il l'est en substance, pas sous un intitulé net. | Écrire « Responsable de la protection des renseignements personnels : [nom], propriétaire » dans la politique et la page d'assistance. | Oui |
| Loi 25 : gouvernance (art. 3.2), transparence (art. 8, 8.2) | Politique §14-§15 : gouvernance, incidents, conservation, droits, en français clair, accessible depuis l'app (`ProfileView.swift:196`, `PaywallView.swift:377`) et la fiche. | Conforme en apparence ; faire relire. | Oui |
| Loi 25 : consentement (art. 12-14) | Données de l'app : sur l'appareil, pas de collecte. Courriels : consentement implicite par l'envoi ; avertissement présent (« N'envoie pas de données de santé ou financières… »). | Garder l'avertissement dans la page d'assistance. | Oui |
| Loi 25 : incidents (art. 3.5-3.8) | Politique §14 et registre 5 ans (§9) annoncés ; aucun registre ni procédure écrite dans le dépôt. | Créer le registre (feuille datée, vide) et une procédure d'une page (CAI + personnes si « risque de préjudice sérieux »). | Oui |
| Loi 25 : évaluation des facteurs relatifs à la vie privée (art. 3.3, 17) | Courriels hébergés chez Google (États-Unis) : communication hors Québec, évaluation requise avant. §15 dit « évalue » ; aucune évaluation n'est dans le dépôt (déjà relevé le 29 octobre). | Faire et garder une évaluation d'une page ; envisager une messagerie avec contrat de traitement (Workspace ou équivalent) plutôt que Gmail grand public. | Oui |
| Loi 25 : mineurs (art. 4.1, moins de 14 ans) | Politique §13 : « pas pour les moins de 13 ans » + accord parental pour écrire. | Aligner sur 14 ans ou garder 13 avec l'avis d'un juriste (cote d'âge 9+, §7.2). | Oui |
| **LPRPDE** | Applicable aux activités commerciales transfrontalières ; atteintes graves : signalement + registre 24 mois (la politique annonce 5 ans : plus strict, donc couvert). | Rien à ajouter. | Oui (portée) |
| **RGPD** (art. 3(2), 13, droits, transferts) | L'app est distribuée dans l'UE ; politique §7, §11, §12 : bases juridiques et droits. Écarts : mécanisme de transfert des courriels vers Google (États-Unis) non nommé ; représentant UE (art. 27) non affirmé (exemption probable, non vérifiée) ; registre des traitements (art. 30) absent. | Nommer le mécanisme de transfert de Google ; tenir un registre d'une page ; trancher l'article 27 avec un avocat. | Oui |
| **États américains** (CCPA/CPRA, etc.) | Seuils non atteints ; la politique accorde les droits volontairement (§12). Washington « My Health My Data » : pas de seuil de revenu ; l'argument « santé gardée sur l'appareil = non collectée » est celui de l'éditeur. | Conserver ; faire valider l'argument de Washington/Nevada. | Oui |
| **DSA (UE)** | Statut « trader » obligatoire pour distribuer dans l'UE ; adresse, téléphone et courriel affichés publiquement (documenté, page App Information). | Adresse d'affaires et numéro dédiés, ou exclure l'UE (P-01). | Oui |
| **Transparence côté app** | Lien vers la politique dans Profil et dans le paywall (5.1.1(i)). | OK. | Non |

Les points 1 à 6 de la section « Points à faire confirmer » de `docs/lancement/revue-juridique-confidentialite.md` restent entiers.

---

## 6. App Review Guidelines (texte lu le 2026-11-07)

**1.4.1** (« clearly disclose data and methodology to support accuracy claims relating to health measurements »). Ardane n'affirme aucune précision et n'est pas un dispositif médical. Mises en garde dans l'app (« Valeurs indicatives, pas un avis médical » : `NutritionApp.swift:54`, `NutritionSpace.swift:119`, `WeightPlanSummaryView.swift:97`, `FitnessSpace.swift:108`), la fiche et `terms.html`. Le scanner affiche des intervalles (`ScanLearning.swift:23-48`, ±40 % pour une photo). La méthode des objectifs caloriques (`Shared/Domains/Nutrition.swift`, `WeightPlan.swift`) n'est pas nommée à l'utilisateur (P-13). Garder la catégorie principale Productivité (`INFOPLIST_KEY_LSApplicationCategoryType = public.app-category.productivity`) : « Santé et forme » déclencherait la déclaration « Regulated Medical Devices » (documenté, page App Information).

**2.1.** Produits IAP à créer et joindre (P-02) ; interrupteur « Contribuer » = fonction inachevée (P-04) ; pas de compte, donc pas de compte de démonstration (« Sign-in required » décoché).

**2.3 / 2.3.1.** Description vérifiée phrase par phrase (§6.1) ; notes de revue inexactes (P-07).

**2.5.x.** 2.5.1 : aucune API privée trouvée (`FoundationModels` lié en `-weak_framework`, `project.pbxproj` vers les lignes 445-451 ; API publique : supposé). 2.5.2 : aucun téléchargement de code ni de modèle (§1.2). 2.5.4 : aucun mode d'arrière-plan déclaré dans `App-Info.plist`. 2.5.16 : widgets et activités liés au contenu de l'app (documenté).

**3.1.1.** Premium débloqué par StoreKit seulement ; le déverrouillage Debug est exclu de Release (règle vérifiée par `check_swift.py`, non relue ici).

**3.1.2.** Le paywall montre prix et durée par offre (`PaywallView.swift:271-296`), « Renouvellement automatique … annulable à tout moment » et « L'essai gratuit ne vaut qu'une fois par compte Apple » (`:287-288`), « Restaurer mes achats » (`:343-349`), texte du renouvellement à 24 h (`:361-362`), liens Conditions et Confidentialité (`:371-378`). Périodes P1M et P1Y (≥ 7 jours : `Config/Ardane.storekit`). Écarts mineurs (P-14) : le lien « Conditions » ouvre l'EULA standard d'Apple (`PremiumConfiguration.swift:13`) alors que la fiche renvoie vers `ardane.app/terms.html` (cohérent : `terms.html` dit que l'EULA standard s'applique, mais mettre aussi le lien Apple dans la description ou le champ Licence) ; `.storekit` n'a que la localisation `fr_CA` ; la « valeur continue » est à argumenter dans les notes.

**4.2.** 12 mini-apps, Studio, widgets, activités en direct : bien au-delà d'un site empaqueté. Risque faible (supposé).

**5.1.1.** (i) politique liée dans l'app, à saisir dans ASC ; elle couvre collecte, usages, conservation, retrait et effacement ; (ii) permissions : §3.2 ; (iii) `PhotosPicker` plutôt que la photothèque (recommandé par la règle) ; (v) pas de compte, donc pas de suppression de compte requise ; **(ix) « Apps that provide services in highly regulated fields (such as banking and financial services, healthcare, … crypto exchanges) … should be submitted by a legal entity … and not by an individual developer »** : risque pour Placements, Mon entreprise (Stripe), Nutrition et Fitness, car l'entreprise individuelle s'inscrit comme « individual » (« your personal legal name will be listed as the seller », page d'inscription Apple). Ardane n'exécute ni transaction ni conseil (P-08).

**5.1.2 / 5.1.3.** Aucun partage ni suivi ; les appels externes sont des fonctions demandées. Pas, distance et séances ne sont ni partagés ni utilisés pour la pub (constaté). L'interrupteur « Contribuer » évoque un partage sans base (P-04).

**5.2.5.** Le texte lu interdit une app « confusingly similar to an existing Apple product », l'emoji Apple, des anneaux d'activité imitant Move/Exercise/Stand. `ApplePayIntent.swift:16-17` et l'interface (`FinancesApplePay.swift:40, 87, 100-101, 141, 170, 345`) emploient « Apple Pay » comme nom descriptif d'un moyen de paiement ; aucune marque graphique d'Apple Pay, un SF Symbol (`wave.3.right.circle`). Je n'ai lu ni la fin de 5.2.5 ni les règles de marque d'Apple : usage nominatif supposé acceptable (P-15).

**Live Activities.** Aucune règle propre dans le texte lu (4.5.3 : pas de spam). `pushType: nil` partout (`StudyLiveActivity.swift:82`, `WorkoutLiveActivity.swift:105`) : pas de serveur de push. `NSSupportsLiveActivities = true` (`App-Info.plist`).

**Widgets.** 2.5.16 (widgets liés à l'app) et 2.5.18 (pas de publicité dans les widgets) : conformes.

### 6.1 La description de `fiche-app-store.md`, vérifiée contre le code
Exact : 12 mini-apps ; import d'horaire par photo ou PDF réservé à Premium (`ScheduleImportView.swift:108`) ; code-barres et recherche sans limite, analyse de plat limitée à 10 (`ScanQuota.swift:7`) ; gratuit = 3 widgets et 5 habitudes (`AppModel.swift:12-13`) ; Premium = tous widgets, styles et packs Étudiant/Sportif/Voyageur (`Packs.swift:60-68`), habitudes illimitées, statistiques détaillées (`PaywallView.swift:162, 206`) ; activités en direct sport/étude ; widgets d'écran verrouillé ; boutons dans certains widgets ; « pas de compte, pas de publicité, pas de suivi » ; données sur l'iPhone ; renouvellement automatique, 24 h, gestion dans les réglages du compte.

À nuancer (Mineur) :
- « Sociétés cotées : les chiffres officiels des entreprises en bourse » : seules les sociétés déclarées à la SEC (États-Unis) sont couvertes (`Companies.swift:113, 190`) ; écrire « sociétés cotées aux États-Unis ».
- « Placements : actions, ETF, crypto » : cours d'actions en direct inactifs (clé Finnhub vide, §1.2) ; les actions prennent le prix saisi (`Portfolio.swift:215-217`) ; écrire « cours crypto en direct, prix des actions saisis par toi », ou fournir une clé.
- L'essai gratuit de 7 jours n'est pas dans la description : acceptable (affiché par Apple et le paywall, décrit dans `terms.html`).
- Notes de revue : P-07.

---

## 7. Réponses recommandées : App Privacy et classification d'âge

### 7.1 App Privacy
Définition d'Apple (page lue) : « "Collect" refers to transmitting data off the device in a way that allows you and/or your third-party partners to access it for a period longer than what is necessary to service the transmitted request in real time. » Les partenaires tiers sont « analytics tools, advertising networks, third-party SDKs, or other external vendors whose code you've added to your app ». « Data that is processed only on device is not "collected" ». Apple précise aussi : « You are not responsible for disclosing data collected by Apple ».

Application : (1) rien n'est transmis à l'éditeur ; (2) aucun SDK ni code tiers ; (3) les requêtes vers Open Food Facts, CoinGecko, SEC, Frankfurter, Stripe et Apple (géocodage) sont des appels d'API à la demande, sans compte, auxquels l'éditeur n'a jamais accès.

**Réponse recommandée : « Data Not Collected » (aucune donnée collectée) ; suivi : non.** Cohérent avec `NSPrivacyCollectedDataTypes = []` et la politique. Incertitude : Apple ne dit pas explicitement qu'un appel à une API publique tierce n'est pas une « collecte par un partenaire » ; ces services ne sont pas du code ajouté à l'app (supposé). Position prudente possible, non recommandée : déclarer « Search History » et « Other Financial Info », non liés à l'identité, sans suivi (sur-déclaration sans risque de refus). À revoir si l'interrupteur « Contribuer » ou un service en ligne est un jour activé (P-04). « User Privacy Choices URL » (facultatif) : laisser vide. L'URL de la politique doit être celle de la fiche : `https://ardane.app/privacy.html`.

### 7.2 Classification d'âge (nouveau questionnaire : 4+, 9+, 13+, 16+, 18+)
Réponses recommandées (barème lu ; libellés exacts des options non lus) :
- Contrôles dans l'app (parental, vérification d'âge) : aucun.
- Accès Web illimité : non (les liens ouvrent Safari ou Réglages ; aucun navigateur intégré).
- Contenu généré par les utilisateurs, messagerie, réseau social, publicité : non.
- Informations médicales ou de traitement : non (occasionnel = 13+, fréquent = 16+).
- Sujets de santé ou de bien-être : oui (« calorie tracking, dieting advice, exercise recommendations » : 9+ selon la page).
- Violence, sexualité, grossièretés, alcool/tabac/drogues, horreur : aucun. Jeux de hasard simulés, loot boxes, concours : aucun (les cours de Placements sont de l'information : supposé).

Résultat attendu : **9+**. La politique dit « pas pour les moins de 13 ans » : pas contradictoire (cote de contenu, pas ciblage) mais à décider par écrit avec le juriste (§5).

---

## 8. CHECKLIST App Store Connect (champ par champ)

[FAIT] = préparé dans `docs/lancement/fiche-app-store.md` ; [À FAIRE] = à saisir ou confirmer dans App Store Connect ; [?] = état inconnu.

### 8.0 Prérequis du compte
- [?] Compte Apple Developer actif (acheté le 2026-10-15, `CLAUDE.md`), type Individuel : le vendeur affiché est le nom légal de la personne, pas « Ardane » (documenté, page d'inscription).
- [À FAIRE] Contrat Paid Apps accepté (indispensable pour vendre abonnements et achat à vie) ; compte bancaire (la NEQ 2282741356 reçue le 2026-11-04 le débloque) ; formulaires fiscaux américains (éditeur non américain : à faire avec le CPA) ; TPS/TVQ (`docs/lancement/inscription-tps-tvq.md`) ; Small Business Program (15 %) à demander (`docs/lancement/risques-apple.md`).
- [À FAIRE] DSA : déclarer le statut de trader ; fournir adresse, téléphone, courriel (publics en UE) ou exclure l'UE.

### 8.1 App Information
- Nom « Ardane » (2 à 30 caractères) [FAIT] ; sous-titre FR « Widgets, mini-apps, ton style » et EN « Custom widgets & mini-apps » [FAIT].
- Langue principale : anglais, recommandé par la fiche [À FAIRE dans ASC].
- Bundle ID `com.dakrsnyk.ardane` [FAIT, `project.pbxproj`] ; SKU à choisir, immuable [À FAIRE].
- Catégorie principale Productivité ; secondaire : éviter « Santé et forme » [À FAIRE].
- Privacy Policy URL `https://ardane.app/privacy.html` (en ligne, v3.0) [À FAIRE].
- Content Rights : déclarer le contenu de tiers (Open Food Facts sous ODbL, Santé Canada, USDA, SEC) avec licences réunies [À FAIRE].
- Licence : EULA standard d'Apple (cohérent avec `terms.html`) [À FAIRE].
- Age Rating : §7.2 [À FAIRE] ; Made for Kids : non.
- Chine continentale : retirer (licence ICP) [À FAIRE].
- Regulated Medical Devices : seulement si catégorie Santé et forme ou contenu médical fréquent (sans objet si Productivité).

### 8.2 Pricing and Availability
- Prix de l'app : Gratuit [À FAIRE].
- Pays et régions : tous sauf Chine continentale ; l'UE dépend du DSA [À FAIRE].
- Prix des IAP : `Config/Ardane.storekit` donne 6,99 (mensuel), 59,99 (annuel), 99,99 (à vie), pour le test local seulement ; choisir les échelons équivalents dans ASC [À FAIRE]. Précommande : non.

### 8.3 App Privacy
- URL de la politique [À FAIRE] ; « Data Not Collected », suivi non (§7.1) [À FAIRE]. Rôle requis : Account Holder, Admin ou App Manager (documenté).

### 8.4 In-App Purchases et abonnements
- Groupe « Ardane Premium » ; abonnements `com.dakrsnyk.ardane.premium.monthly` (P1M) et `.yearly` (P1Y) ; non consommable `.lifetime` [À FAIRE : `docs/lancement/risques-apple.md` les disait absents au 2026-10-26 ; état actuel [?]].
- Offre d'introduction : essai gratuit d'une semaine sur le mensuel et l'annuel, comme dans `Config/Ardane.storekit` [À FAIRE].
- Localisation de chaque produit (nom affiché, description : 45 caractères pour l'achat à vie, 55 pour un abonnement d'après `risques-apple.md`) dans toutes les langues de la fiche ; le `.storekit` n'a que `fr_CA` [À FAIRE].
- Partage familial : décision ouverte (`familyShareable` faux dans le fichier local).
- Capture d'écran du paywall par produit (guideline 2.1(b)) et jonction des produits à la version soumise [À FAIRE].
- Test sandbox d'achat, de restauration et d'annulation après un envoi `[testflight]` [À FAIRE].

### 8.5 Version 1.0
- Captures iPhone : au moins un jeu de tailles obligatoire (6,9 pouces selon ma connaissance ; page Apple 404, à vérifier dans ASC) [À FAIRE] ; aperçus vidéo facultatifs.
- Texte promotionnel (170), description (4 000), mots-clés (100) en FR et EN [FAIT] ; corrections du §6.1 [À FAIRE].
- URL d'assistance `https://ardane.app/support.html` (200 vérifié) et URL marketing `https://ardane.app` [FAIT].
- Version 1.0 (`MARKETING_VERSION`) et copyright « 2026 Ardane » [FAIT].
- Build : un envoi `[testflight]` (jamais `[interne]`, bloqué par Apple) [À FAIRE]. Chiffrement : `ITSAppUsesNonExemptEncryption = false` [FAIT, `App-Info.plist`].
- App Review Information : sans connexion, notes en anglais [FAIT] mais à corriger (P-07) ; contact (nom, téléphone, courriel) à saisir par l'utilisateur [À FAIRE].
- Version Release : choisir « manuel » pour contrôler la sortie [À FAIRE]. « What's New » : facultatif pour la 1.0.
- Routing App Coverage, App Clip, iMessage : rien [FAIT]. Bannières Header et Search Results choisies [FAIT], à téléverser.
- Après la soumission : repasser le dépôt en privé ; renseigner `PremiumConfiguration.appStoreID` (nil aujourd'hui, `ProfileView.swift:425`) dans la version suivante pour « Noter Ardane ».

---

## 9. Constats (identifiant, gravité, preuve, correction)

### Bloquants avant soumission

**P-01 — Bloquant (pour l'UE) : statut « trader » (DSA) et coordonnées publiques.** Preuve : page App Information d'Apple (« If you are a trader, you must provide identification and contact details shown to EU consumers ») ; Premium rend l'éditeur commerçant ; `docs/lancement/revue-juridique-confidentialite.md`. Correction : adresse d'affaires et téléphone dédiés avant d'ouvrir l'UE, ou exclure l'UE.

**P-02 — Bloquant (processus) : produits IAP, contrat Paid Apps, fiscalité non confirmés.** Preuve : `docs/lancement/risques-apple.md` (produits absents au 2026-10-26) ; guideline 2.1(b). Correction : §8.0 et §8.4.

**P-03 — Bloquant (processus) : questionnaires App Privacy et classification d'âge à remplir.** Obligatoires pour soumettre (documenté). Réponses : §7.

### Majeurs

**P-04 — Majeur : interrupteur « Contribuer à l'amélioration » sans fonction et absent de la politique.** Preuve : `App/Screens/MiniApps/Nutrition/ScanRecapView.swift:153-162` (visible après chaque photo ; pied de page « Aucun envoi pour l'instant : cette option ne fait rien tant qu'aucun service n'existe »), `Shared/Domains/ScanLearning.swift:93-95`, `Tests/ScanLearningTests.swift:154`. Risque : 2.1 (fonction inachevée), 5.1.2 (consentement à un partage inexistant), contradiction avec « Ardane n'envoie rien ». Correction : masquer la section pour la 1.0 (garder la variable pour les sauvegardes) ; test qui échoue si `MealAnalysisConfig.onlineEnabled` vaut `true`.

**P-05 — Majeur : « Effacer toutes mes données » n'efface pas l'historique des pas et distances.** Preuve : `UserDefaults.standard`, clé `stepHistory` (`StepCounter.swift:82-92`, exporté par `DataBackup.swift:41, 73`) ; `resetAllData()` (`AppModel.swift:655-710`) n'appelle aucun `removeObject` (aucune occurrence de `removeObject` ou `removePersistentDomain` dans `App/` et `Shared/`). La politique §11 promet l'effacement ; ce sont des données d'activité (Fitness au sens d'Apple). Le prénom et le nom sont conservés sans que le dialogue (`ProfileView.swift:323-327`) le dise. Correction : `UserDefaults.standard.removeObject(forKey: StepCounter.historyKey)` ; dire ou effacer le nom ; test unitaire de `resetAllData`.

**P-06 — Majeur : la clé Stripe du Keychain survit probablement à la désinstallation, contrairement à la politique.** Preuve : la politique §11 propose « supprimer l'app » pour effacer ; la clé est dans le Keychain (`StripeSync.swift:15`), supprimée seulement par la déconnexion et par `resetAllData` (`AppModel.swift:657`). Persistance du Keychain après désinstallation : comportement connu, non testé ici, sans source Apple citée (supposé). Clé en lecture seule, ce qui limite la gravité. Correction : au premier lancement sans fichiers de données, supprimer la clé orpheline (drapeau dans `UserDefaults`), ou écrire dans la politique de déconnecter Stripe avant de désinstaller ; test sur iPhone.

**P-07 — Majeur : notes pour l'examinateur inexactes (2.3.1).** Preuve : `docs/lancement/fiche-app-store.md`, section App Review Information : (a) « Open Food Facts and USDA FoodData Central: food data from a barcode or a search » alors qu'aucune requête USDA n'existe (`NutrientFile.swift:5-10`, politique §4) ; (b) « Camera: … or photograph a class schedule » alors que l'horaire passe par `PhotosPicker` (`ScheduleImportView.swift:170`) ; (c) Frankfurter (taux de change) omis. Correction : remplacer (a) par « Open Food Facts (barcode and search text); generic food tables are built into the app », supprimer « or photograph a class schedule », ajouter « Frankfurter: exchange rates (currencies and dates only) ».

**P-08 — Majeur (risque de refus à arbitrer) : vendeur « individu » pour des domaines réglementés (5.1.1(ix)).** Preuve : guideline 5.1.1(ix) ; page d'inscription Apple (sole proprietor = « individual », nom légal affiché) ; Ardane contient Placements, Mon entreprise (Stripe), Nutrition, Fitness. Correction : dire dans les notes de revue qu'Ardane n'exécute aucune transaction, ne donne aucun conseil, n'a aucun accès en écriture (clé Stripe restreinte en lecture) et que les cours sont informatifs (`terms.html`) ; envisager l'incorporation (compte Organization, D-U-N-S) si Apple refuse. Juriste et CPA pour la structure.

### Mineurs

**P-09 — Mineur : la politique dit « à ta demande » mais les widgets de cours rafraîchissent seuls.** Preuve : `Widgets/DesignProvider.swift:37, 46` (`allowNetwork: true`), `:83, 156-157`, `Shared/Data/DomainData.swift:123-143`. Les identifiants des cryptos, le CIK des sociétés suivies et les devises partent de l'extension sans ouverture de l'app. Correction : ajouter à la politique §4 « Les widgets de cours et de sociétés se rafraîchissent aussi en arrière-plan, selon iOS, et interrogent alors ces mêmes services ».

**P-10 — Mineur : chaîne de permission de position résiduelle.** Preuve : `App/InfoPlist.xcstrings`, clé `NSLocationWhenInUseUsageDescription` (7 langues, « Your location is only used to find the weather in your city »), sans clé correspondante dans `project.pbxproj` ni appel de position (météo retirée, commit `fe9b7555`). Correction : supprimer la clé du catalogue.

**P-11 — Mineur : copies périmées de la politique dans le dépôt public.** Preuve : `docs/legal/privacy.html` (version 2.1, versionné) et `PRIVACY.md` (version 2.1, avec renvoi au site) ; le site en ligne est en 3.0. Correction : supprimer `docs/legal/privacy.html` ou le remplacer par un renvoi.

**P-12 — Mineur : photos orphelines après l'effacement.** Preuve : `resetAllData()` ne supprime que les photos référencées par les designs (`AppModel.swift:658-661`) alors que `ImageStore.allNames()` existe (`SharedStore.swift:278`). Correction : supprimer toutes les images de `ImageStore.allNames()` à l'effacement.

**P-13 — Mineur : méthode des estimations caloriques non nommée (1.4.1).** Preuve : seules des mises en garde générales (`NutritionApp.swift:54`, `WeightPlanSummaryView.swift:97`). Correction : ligne dans « À propos » nommant la formule (`Shared/Domains/Nutrition.swift`, `WeightPlan.swift`) et les tolérances du scanner.

**P-14 — Mineur : détails 3.1.2 et localisations.** Ajouter le lien de l'EULA standard d'Apple dans la description ou le champ Licence ; créer les localisations des produits dans ASC ; argumenter la valeur continue dans les notes. Preuves : `PremiumConfiguration.swift:13`, `Config/Ardane.storekit`.

**P-15 — Mineur : « Apple Pay » comme nom descriptif (5.2.5).** Preuve : `ApplePayIntent.swift:16-17`, `FinancesApplePay.swift:40, 87, 100-101, 345`. Usage nominatif, sans marque graphique ; règles de marque d'Apple non lues (supposé acceptable). Correction : ajouter dans l'écran Apple Pay ou « À propos » « Apple Pay est une marque d'Apple Inc. Ardane n'est pas affiliée à Apple » ; jamais le logo ni le bouton Apple Pay ; pas « Apple Pay » dans le nom ni les mots-clés.

**P-16 — Mineur : liste des données du profil dans la politique.** La politique §2 cite « date de naissance » ; le profil garde l'année (`Profile.swift:275`), le sexe, le détail du genre et l'historique de poids (`Profile.swift:279-284`). Correction : ajouter « sexe, genre » ; préciser que l'export ne contient pas la mémoire visuelle du scanner (`DataBackup.swift:27-30`).

**P-17 — Mineur : textes de permission de l'extension non localisés (supposé).** `InfoPlist.xcstrings` est dans `App/` ; la chaîne du calendrier de l'extension (`project.pbxproj` ~l.551) est en français seulement. La demande est faite par l'app (`CalendarService.requestAccess`), donc probablement jamais affichée ; à vérifier sur un iPhone en anglais.

**P-18 — Mineur : sauvegarde iCloud incluant santé et finances.** Aucune exclusion (`isExcludedFromBackup` absent). La politique l'annonce ; 5.1.3(ii) vise l'iCloud de l'app (supposé non applicable). Décision à documenter.

### Contrôles réussis (constatés)
Aucun SDK tiers ; aucune photo de repas envoyée ; modèles Core ML locaux ; permissions demandées à l'usage avec explication ; 7 langues pour les textes de permission ; manifeste et raisons d'API cohérents avec le code ; Stripe en session éphémère et Keychain `ThisDeviceOnly` ; pas d'ATS désactivé ; pas de `http://` ; politique, conditions et assistance en ligne (200) ; lien de politique dans l'app (Profil, paywall).

---

## 10. Actions proposées, par ordre
1. Correctifs de code (petits) : P-04, P-05, P-06, P-10, P-12, plus un test de garde (`onlineEnabled == false`).
2. Fiche et notes : P-07 et nuances du §6.1.
3. Politique : P-09, P-16, transfert Google (RGPD), titre du responsable.
4. Dépôt : P-11.
5. App Store Connect : checklist §8 (DSA, contrat Paid Apps, produits, questionnaires).
6. Juriste : évaluation des facteurs relatifs à la vie privée, registre des incidents, article 27 du RGPD, Washington, âge minimal, 5.1.1(ix) (incorporation éventuelle).
