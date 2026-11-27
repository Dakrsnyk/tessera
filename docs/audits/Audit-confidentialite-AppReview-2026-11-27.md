# Audit confidentialité et App Review (2026-11-27)

Lecture seule, statique (rien compilé). Aucun secret trouvé dans le dépôt (clés Finnhub/CoinGecko vides dans `Ardane.xcodeproj/project.pbxproj:388-437`).

## 1. Manifeste de confidentialité
- Un seul fichier : `Shared/PrivacyInfo.xcprivacy` (dossier Shared, compilé dans l'app et l'extension). Déclare UserDefaults (CA92.1, 1C8F.1) et FileTimestamp (C617.1). NSPrivacyTracking false, CollectedDataTypes vide.
- Usage de timestamps : `Shared/Domains/Companies.swift:186`, `Shared/Support/StoreRecovery.swift:51` : couvert (C617.1).
- Pas trouvé : systemUptime/boot time, espace disque : rien à déclarer.
- À vérifier sur Mac/CI : que le fichier est bien dans les ressources des deux cibles (groupe synchronisé, non prouvé).
- CollectedDataTypes vide : plausible (aucun compte, Stripe/Wallet restent sur l'appareil). Mais requêtes réseau externes (Open Food Facts : code-barres/recherche `Shared/Domains/FoodDatabase.swift:386`, CoinGecko/Finnhub/Frankfurter/SEC, géocodage `App/Screens/Spaces/TravelCarLifeSpaces.swift:18` via CLGeocoder -> Apple) : aucune donnée liée à l'identité. Les réponses "Data Not Collected" dans App Store Connect sont défendables, à confirmer.

## 2. Info.plist (clés dans project.pbxproj:475-478 et 523-526)
- Calendrier (`NSCalendarsFullAccessUsageDescription`), Caméra, Motion, PhotoLibraryAdd, FinancialData : présents. Traductions dans `App/InfoPlist.xcstrings` : présentes.
- Caméra utilisée (CameraAccessGate.swift:114) OK. Photos : PhotosPicker (pas de clé requise) + addOnly (HomeSetupViews.swift:785, WallpaperCollection.swift:383) OK. Motion : CMPedometer OK. Notifications : pas de clé requise.
- Rappels : aucun EventKit reminders repéré. Localisation : aucun CLLocationManager ; seul CLGeocoder (pas de permission).
- Mineur : `App/InfoPlist.xcstrings:192` contient `NSLocationWhenInUseUsageDescription` sans clé correspondante ni usage : entrée orpheline.
- Mineur : `Config/App-Info.plist:~26` `NSFinancialDataUsageDescription` présent alors que FinanceKit est désactivé (`ArdaneFinanceKit` false) et que `Config/Ardane.entitlements` n'a pas `com.apple.developer.financekit`. Pas de blocage tant que FinanceKit n'est pas appelé ; si le texte est vu en review, il décrit une fonction inactive. Retirer ou garder avec l'entitlement le jour de l'activation.
- Live Activities : `NSSupportsLiveActivities` true OK. `ITSAppUsesNonExemptEncryption` false OK.

## 3. Guidelines App Review
- 3.1.2 abonnements : paywall `App/Premium/PaywallView.swift` : prix `displayPrice` (l.280-285), durée, renouvellement auto + annulation (l.363-364), Restaurer (l.322-327), liens Conditions/Confidentialité (l.369-370). Idem `OnboardingOffer.swift:273-274`, `ProfileView.swift:203-206`. OK sur le papier. Risque : URLs `https://ardane.app/terms.html|privacy.html` (`App/Premium/PremiumConfiguration.swift:14-15`) doivent répondre en 200 avant soumission (non vérifié ici) ; l'URL de politique doit aussi être saisie dans App Store Connect.
- Liens de paiement externes : aucun widget ne mène vers un paiement externe ; `DeepLink` (Shared/Support/DeepLink.swift) est interne, hôtes en liste fermée, UUID validé. OK. Liens externes : Stripe dashboard (`BusinessSources.swift:441`, aide au branchement, pas un achat), Open Food Facts, avis App Store.
- Santé/nutrition : mention "pas un avis médical" présente (NutritionApp.swift:75, WeightPlanSummaryView.swift:110, NutritionPages.swift:307/428, NutritionTargetsCard.swift:93). Plans de perte de poids (WeightPlanSummaryView) : texte prudent présent ; vérifier que l'écran de saisie refuse mineurs/IMC extrêmes (non audité). Guideline 1.4.1.
- Stripe : clé `rk_` en trousseau `kSecAttrAccessibleWhenUnlockedThisDeviceOnly` (`App/Services/StripeSync.swift:13-16`), validée par préfixe (l.123), session éphémère (l.67), HTTPS, suppression à la déconnexion (l.230). Clé dans l'en-tête Authorization, pas dans l'URL. OK.
- Finnhub : le jeton est passé dans l'URL (`Shared/Domains/Portfolio.swift:352`) et la clé est lue de l'Info.plist (`Config/*-Info.plist:8-10`) : une clé injectée serait lisible dans l'IPA. Aujourd'hui vide donc la fonction boursière est peut-être inopérante en production : sinon, c'est un 2.1 (fonction cassée) à tester. CoinGecko : clé demo en en-tête, même remarque.
- 5.1.1 / suppression : pas de compte ; "Effacer toutes mes données" (`ProfileView.swift:270,338`), export (`:245`). OK. 5.1.1(v) non applicable.
- Fichiers App Group : protection `completeUntilFirstUserAuthentication` (`Shared/Support/SharedStore.swift:109-126`) : lisibles écran verrouillé après premier déverrouillage, voulu (widgets).
- 4.2 : app riche (widgets, mini-apps), pas de risque de fonctionnalité minimale.
- Données financières : Wallet/Stripe locaux ; politique de confidentialité doit les mentionner (non vérifiée : site non accessible ici).
- HTTP clair : aucun `http://` dans App/Shared.

## 4. Bloquants probables / avertissements
Bloquants probables : (a) pages terms/privacy en ligne et URL de confidentialité renseignée dans ASC (non vérifiable ici) ; (b) cohérence "Data Not Collected"/questionnaire avec la politique.
Avertissements : points mineurs ci-dessus ; compte démo non nécessaire (pas de compte) ; notes de review à écrire (FinanceKit désactivé, Stripe optionnel avec clé restreinte, pourquoi calendrier).
Non vérifié : compilation, présence réelle du xcprivacy dans les deux bundles, sections Premium StoreKit côté ASC (produits, captures paywall), `check_swift.py` : lancé, 240 "problèmes" listés `Color(...) missing ['name']` (Shared/Theme/Theme.swift:1131...) sans ligne de sécurité Release/INTERNAL_PREMIUM visible dans la sortie (sortie filtrée, à relancer sous Linux/CI ; possible effet de chemins Windows).
