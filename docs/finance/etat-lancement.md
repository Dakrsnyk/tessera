# État du lancement App Store (Ardane)

Lecture seule du dépôt (agent 11.3, Haiku), consolidé par le Chef. Statuts : RÉALISÉ, À VÉRIFIER, À FAIRE. « non trouvé » = preuve absente.

## 1. État du projet
- Statut : RÉALISÉ (code) / À VÉRIFIER (iPhone).
- Preuve : CLAUDE.md:1-2 ; docs/PASSATION.md:6-7 ; docs/memoire/Chantiers.md (8 lots, 400+ tests).
- Reste : vérifier sur iPhone ; builds 269 et 272 rejetés au traitement par Apple (ITMS-90626, corrigé au build 274) ; repasser le dépôt en privé.

## 2. Code, tests, sécurité, performance
- Statut : À VÉRIFIER.
- Preuve : scripts/check_swift.py (garde Release, INTERNAL_PREMIUM) ; Shared/PrivacyInfo.xcprivacy (tracking false, aucune donnée collectée) ; App/Premium/*.swift.
- Reste : tests StoreKit (aucun test de PremiumStore ni de refreshEntitlements) ; passe de tests en mode gratuit (voir Demandes.md) ; performance du Store et des fonds.

## 3. StoreKit 2
- Statut : À VÉRIFIER (code RÉALISÉ, sandbox non testé).
- Produits : App/Premium/PremiumConfiguration.swift ; Config/Ardane.storekit (à vie 99,99 ; mensuel 6,99 avec 4,99 x 3 mois ; annuel 59,99 sans offre).
- Restauration : PaywallView.swift et ProfileView.swift : RÉALISÉ. Transaction.updates : PremiumStore.swift : RÉALISÉ. Seules les transactions « verified » comptent ; pas de vérification serveur (par conception).
- Reste : trancher l'essai annuel (README.md:73 et :170 annoncent 7 jours, absent de Ardane.storekit) ; localisation fr_CA seule ; familyShareable à true partout (décision à prendre) ; commentaire PremiumConfiguration.swift:4 cite Config/Ardane.storekit, inexistant.

## 4. Apple Developer
- Statut : compte RÉALISÉ ; accords, fiscalité, banque À FAIRE.
- Preuve : compte acheté le 2026-10-15 (Chantiers.md) ; contrat, formulaires et banque : non trouvés comme faits.
- Conflit documentaire : docs/guide-premium-testflight.md demande d'envoyer les formulaires fiscaux maintenant, docs/entreprise-et-nom-vendeur.md:17 demande de ne pas les envoyer avant la société.

## 5. Statut juridique
- Statut : À FAIRE. Vendeur individuel ; société « inc. » non constituée ; D-U-N-S non demandé ; nom « Studio Ardane inc. » recommandé, non réservé.

## 6. Confidentialité, CGU, conformité
- Politique : RÉALISÉE (docs/legal/privacy.html, PRIVACY.md) ; publication À FAIRE : l'URL actuelle est un artifact claude.ai privé (PremiumConfiguration.swift:14).
- CGU : propres non trouvées ; termsURL = EULA standard Apple.
- App Privacy : « Données non collectées » (NSPrivacyCollectedDataTypes vide). Loi 25 : mentions présentes ; registre ou évaluation non trouvés.

## 7. Licences des données, API, images
- RÉALISÉ (attributions in-app) : Open Food Facts ODbL, FCÉN, USDA, Open-Meteo CC BY 4.0, CoinGecko, SEC EDGAR. Photos de test CC BY : Tests/Fixtures/FoodPhotos/ATTRIBUTIONS.md (non livrées dans l'app).
- À VÉRIFIER : audit de la table USDA (docs/licences-nutrition.md) ; polices, icônes, musique Mixkit (licence non stockée).

## 8. App Store Connect
- À FAIRE : textes, mots-clés, classification, sous-titre, captures (pub/kit* ignorées par Git), fiche FR et EN, capture de la page Premium pour la revue.

## 9. Prix, commissions, Small Business Program
- Prix fixés (voir Ardane.storekit). Commissions et éligibilité : voir docs/finance/apple.md (à confirmer sur les pages Apple).

## 10. TestFlight, soumission, refus
- TestFlight RÉALISÉ en partie (builds internes jusqu'au 277) ; soumission À FAIRE.
- Risques de refus : 2.2 (test payant), 3.1.2 (liens EULA et confidentialité, métadonnées), 5.1.1 (politique sur URL privée), 2.1 (produits absents d'App Store Connect).

## 11. Marketing
- RÉALISÉ : 8 films dans pub/film/, campagne docs/memoire/campagne-v2/. À FAIRE : mots-clés, sous-titre, ASO.
- Incohérence : README.md:169 « 30 widgets gratuits » contre Decisions.md « 3 widgets gratuits ».

## 12. Suivi abonnements et remboursements
- À FAIRE (suivi technique partiel) : état Premium recalculé depuis Transaction.currentEntitlements (révocation gérée) ; tableau de bord ventes/remboursements non trouvé ; aucun serveur de notifications.

## Les 10 actions les plus bloquantes avant soumission
1. Trancher la personne vendeuse (individu ou société) : elle conditionne contrat, banque et fiscalité.
2. Signer le contrat Paid Apps, les formulaires fiscaux et le compte bancaire jusqu'au statut « Active ».
3. Créer les 3 produits aux identifiants exacts, avec localisations FR et EN ; décider familyShareable.
4. Trancher l'essai annuel : aligner README.md sur Ardane.storekit ou ajouter l'offre.
5. Tester en sandbox TestFlight : achat, offre, restauration, annulation, mode avion.
6. Rendre la politique publique sur une URL stable et la reporter dans la fiche.
7. Décider des CGU propres ou de l'EULA Apple, et le lier.
8. Rédiger la fiche FR et EN, captures, mots-clés, classification, déclaration « Données non collectées ».
9. Confirmer les licences (Mixkit, polices, icônes).
10. Repasser le dépôt en privé après livraison ; tout envoi public exige l'accord explicite de l'utilisateur.
