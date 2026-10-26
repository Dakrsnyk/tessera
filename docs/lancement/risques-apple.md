# Risques de refus Apple et exigences d'App Store Connect (tâche 12.R)

Consulté le 2026-10-26 (agent research-architect, relu par le Chef). « Vérifié » = lu dans la source Apple ou dans le dépôt ; « estimation » = jugement. Limites de lecture : pages Apple longues lues aux 100 000 premiers caractères ; la page `app-privacy-details` (définition de « collecter ») n'a pas été lue.

## Bloquants avant soumission
1. **URL de confidentialité privée** (guidelines 2.1 et 5.1.1) : `App/Premium/PremiumConfiguration.swift:14` pointe vers un artifact claude.ai privé. Héberger `docs/legal/privacy.html` sur une URL publique stable (dépôt dédié public, domaine, ou hébergement statique), la reporter dans le code et dans App Store Connect. Risque ÉLEVÉ.
2. **Produits absents d'App Store Connect** (2.1) : créer les 3 produits aux identifiants exacts (`com.dakrsnyk.tessera.premium.monthly`, `.yearly`, `.lifetime`), les joindre à la version soumise (le premier abonnement part avec une nouvelle version), localisations FR et EN, capture du paywall dans « Review Information », test sandbox. Risque MOYEN.
3. **Fiche et README incohérents avec le paywall** (2.3.1) : « 30 widgets gratuits » (`README.md:105`, `:169`) contre 3 (`Decisions.md:56`) ; essai annuel 7 jours (`README.md:73`, `:170`, `:232`) absent de `Config/Tessera.storekit` (`introductoryOffer: null` sur l'annuel). Décision de l'utilisateur sur l'essai annuel. Risque MOYEN.

## Autres points
- **Nom du groupe et des produits** : le `.storekit` dit « Tessera Premium », le paywall et le README « Ardane Premium » ; aligner. Commentaire `PremiumConfiguration.swift:4` cite un fichier inexistant (`Config/Ardane.storekit`). Localisations StoreKit : `fr_CA` seule.
- **3.1.2** : prix, durée, renouvellement, annulation, restauration, liens présents dans `PaywallView.swift` (lignes 281-289, 326-331, 364-370). À faire : liens Conditions et Confidentialité aussi dans la description de la fiche (règle de pratique à confirmer dans App Store Connect) ; argumenter la valeur continue de l'abonnement.
- **Descriptions d'usage iOS** (caméra, calendrier, position, mouvement, ajout à Photos) : en français ; vérifier qu'une localisation `InfoPlist.xcstrings` existe (aucune trouvée dans `App/` ni `Shared/` : à confirmer). Risque FAIBLE.
- **Chiffrement** : `ITSAppUsesNonExemptEncryption = false` dans `Config/App-Info.plist`, qui est bien le fichier utilisé (`INFOPLIST_FILE`, vérifié dans le projet).
- **App Privacy** : `PrivacyInfo.xcprivacy` : tracking false, aucune donnée collectée. Appels tiers (Open-Meteo, CoinGecko, Frankfurter, Open Food Facts, USDA, SEC EDGAR, Finnhub, Stripe) tous nommés dans `docs/legal/privacy.html` (vérifié par le Chef). « Données non collectées » plausible, mais la définition d'Apple pour la position envoyée à Open-Meteo et le code-barres envoyé à Open Food Facts reste à relire.
- **Classification d'âge** : questionnaire obligatoire ; estimation 9+ (santé, bien-être), à confirmer en le remplissant.
- **Compte de démo** : inutile (aucune connexion) ; dire dans les notes que l'import CSV remplace la clé Stripe.
- **Clés d'API dans `Config/App-Info.plist`** (OpenMeteoAPIKey, CoinGeckoAPIKey, FinnhubAPIKey) : lisibles dans l'IPA ; sensibilité à trancher par l'audit 12.S.
- **Build `[interne]`** : jamais soumis (Premium débloqué) ; Apple le bloque (« Internal Only »).
- **Revue** : Apple indique examiner au moins 50 % des soumissions en moins de 24 h et 90 % en moins de 48 h (https://developer.apple.com/distribute/app-review/).
- **Small Business Program** : 15 % sous 1 M$ US de proceeds ; contrat Paid Apps accepté et effet 15 jours après la fin du mois fiscal d'approbation (https://developer.apple.com/app-store/small-business-program/).

## Décisions pour l'utilisateur
Essai annuel (aligner README ou ajouter l'offre) · « 3 widgets gratuits » ou autre chiffre pour la fiche · nom du groupe d'abonnement · `familyShareable` · où héberger la politique (public, stable).
