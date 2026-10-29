# Revue juridique de la politique de confidentialité (2026-10-29)

Relecture faite par un agent, pas par un avocat. Fichiers : `ardane-site/privacy.html` (v3.0 du 29 octobre 2026), `ardane-site/terms.html`.

## Ce qui a changé (v2.3 → v3.0)
- Faits revérifiés dans le code : permissions (pbxproj : Caméra, Calendrier « accès complet » mais lecture seule, Mouvements, Photos « ajout seulement » ; pas de position, pas de HealthKit, pas d'iCloud/CloudKit ; entitlements = App Group seul) ; réseau = CoinGecko, Finnhub, Frankfurter, SEC, Open Food Facts, Stripe, CLGeocoder (Apple) ; imports d'horaire (PDFKit/Vision), de ventes (CSV) et de sauvegarde lus sur l'iPhone, fichier d'origine non gardé ; notifications et Live Activities locales (`pushType: nil`) ; clé Stripe effacée à la déconnexion ET par `resetAllData` (AppModel.swift:634).
- Ajouts : sauvegarde iCloud de l'iPhone (les fichiers de l'App Group ne sont pas exclus) ; nouvelle section « Ce que nous recevons » (courriels hébergés par Gmail/Google, rapports agrégés d'Apple, analyses partagées par opt-in, TestFlight, site sur GitHub Pages sans cookie, `localStorage` « lang ») ; adresse IP = renseignement personnel selon le RGPD ; Apple responsable distinct ; transferts hors Québec ; bases juridiques avec articles (RGPD art. 6, LGPD art. 7) ; précisions par pays (Californie/États américains, santé Washington/Nevada, UE/UK/Suisse, Brésil, Japon) ; âges (13 ; 14 Québec et Corée ; jusqu'à 16 UE ; 18 Inde) ; incidents (CAI, CPVP, autres) ; section Gouvernance (Loi 25 art. 3.2) ; liste d'autorités élargie (ICO, PFPDT, PIPC, OAIC, Inde, CPPA) ; version française prévaut.
- Retiré : « un avis est affiché dans l'app » (non implémenté) → nouvelle version datée sur la page + notes de version App Store.
- Conditions : Éditeur, Responsabilité (limitée « dans la mesure permise », sans toucher aux droits impératifs du consommateur ni à la faute lourde/préjudice corporel ou moral, C.c.Q. 1474, LPC art. 10), Loi applicable (Québec/Canada, règles impératives du lieu de résidence conservées, C.c.Q. 3117), Modifications, pied de page à 3 liens.

## Durées retenues et leur fondement
- Réponse en 30 jours : Loi sur la protection des renseignements personnels dans le secteur privé (Québec) art. 32 ; LPRPDE art. 8(3) ; RGPD art. 12(3) (un mois) ; plus court si la loi l'exige : LGPD art. 19, II (15 jours pour l'accès). CCPA : 45 jours (plus long, donc couvert).
- Courriels gardés au plus 24 mois après le dernier échange : **choix de l'éditeur**, aucune loi ne fixe de durée ; respecte la limitation de conservation (Loi secteur privé art. 23, LPRPDE principe 4.5, RGPD art. 5(1)(e)). Couvre un cycle d'abonnement annuel et la preuve d'une demande traitée. Si l'avocat veut garder la preuve jusqu'à la prescription civile (3 ans, C.c.Q. 2925), passer à 36 mois.
- Registre des incidents : au moins 5 ans (Règlement sur les incidents de confidentialité, Québec) ; LPRPDE : 24 mois (Règlement sur les atteintes aux mesures de sécurité).

## Points à faire confirmer par un avocat (ou CPA)
1. **Gmail grand public** : pas de contrat de sous-traitance (RGPD art. 28) ni d'EFVP (Loi 25 art. 17) pour l'hébergement des courriels aux États-Unis. Recommandé : Google Workspace ou autre messagerie avec DPA, puis faire et garder l'EFVP.
2. **Représentant dans l'UE/au Royaume-Uni** (RGPD/UK GDPR art. 27) : exemption probable (traitement occasionnel, sans données sensibles à grande échelle), non affirmée dans la politique.
3. **Seuils** : CCPA/CPRA et autres États (non atteints, droits accordés volontairement) ; Australie (exemption petite entreprise < 3 M AUD, sauf si « health service provider » : à confirmer pour Nutrition/Fitness) ; Corée (agent local seulement au-delà de seuils) ; Brésil (petit agent dispensé d'encarregado, canal = courriel) ; Inde (DPDP en vigueur par étapes).
4. Washington My Health My Data Act : la position « données de santé gardées sur l'appareil = non collectées » est à valider.
5. Âges : vérifier la cote d'âge App Store retenue et le choix « 13 ans » face à la Loi 25 (14 ans) et à la DPDP indienne (18 ans).
6. Clause de responsabilité et loi applicable : vérifier la validité face à la LPC du Québec et aux lois des consommateurs de l'UE.
7. Fiscalité (CPA) : TPS/TVQ sur les ventes App Store, revenus d'entreprise individuelle, passage en société.

## Obligations pratiques pour une distribution mondiale
- **Statut « trader » (DSA, UE)** : dans App Store Connect, déclarer si on est commerçant. En vendant Premium, la réponse est « oui » → Apple affiche publiquement **adresse, téléphone et courriel** sur la fiche UE. Pour un particulier : prévoir une adresse d'affaires (case postale ou adresse de domiciliation) et un numéro dédié avant d'ouvrir l'UE ; sinon l'app est retirée des pays de l'UE.
- **Chine continentale** : licence ICP (ou numéro de dépôt) requise depuis 2023 pour les apps ; impossible sans entité ou partenaire chinois → exclure la Chine continentale dans App Store Connect.
- **Exportation/chiffrement** : `ITSAppUsesNonExemptEncryption = false` (App-Info.plist) est correct (HTTPS et chiffrement d'iOS seulement, exemptés) ; la déclaration annuelle BIS/France n'est pas requise dans ce cas. Revoir si un chiffrement propre est ajouté.
- **Étiquettes App Privacy** (App Store Connect) : « Données non collectées » est défendable car rien n'est envoyé au développeur ni à un tiers à des fins de collecte ; les requêtes Open Food Facts/CoinGecko/etc. sont des fonctions à la demande sans identifiant. À vérifier : les rapports de plantage d'Apple ne comptent pas. Cohérence obligatoire avec la politique.
- **Manifest de confidentialité** (`PrivacyInfo.xcprivacy`) : présent (`Shared/PrivacyInfo.xcprivacy` : suivi = non, aucune donnée collectée, UserDefaults et date des fichiers déclarés) ; cohérent avec la politique. Vérifier qu'il est bien inclus dans l'app ET l'extension (dossier Shared/ compilé dans les deux).
- **URL de la politique dans l'app** : `PremiumConfiguration.privacyURL` pointe encore vers un artefact claude.ai → https://ardane.app/privacy.html ; même URL dans App Store Connect. `PRIVACY.md` (v2.1) est en retard.
- Dépôt public : le repasser en privé.
