# Business : récupérer ses ventes sans les saisir (audit et architecture, 2026-10-15)

## Ce qui existait

- La mini-app Business (`Shared/Domains/Business.swift`, `App/Screens/MiniApps/Business/`) ne connaissait que la saisie à la main : `SalesEntry` (date, montant, commandes, nouveaux clients, visiteurs, note), `BusinessExpense`, instantanés de MRR, indicateurs suivis à la main.
- Aucune source externe, aucun import de fichier, aucun serveur Ardane.

## Plateformes étudiées

| Plateforme | Accès officiel | Sans serveur ? | Coût / restrictions | Retenu |
|---|---|---|---|---|
| **Stripe** | API REST ; **clé restreinte** créée par le titulaire du compte, limitée à « Balance transactions : lecture » | **Oui** : la clé reste dans le trousseau de l'iPhone, les appels vont directement à `api.stripe.com` | Gratuit ; limites de débit larges (environ 100 lectures/s) ; ne jamais embarquer la clé du développeur dans l'app (ce n'est pas le cas : c'est la clé de l'utilisateur, sur son appareil) | **Oui (v1)** |
| Stripe Connect (OAuth) | OAuth « Standard » | Non : l'échange du code contre un jeton exige la clé secrète de la plateforme Ardane, donc un serveur | Gratuit ; demande un compte plateforme Stripe validé | Plus tard |
| Shopify | Admin API (GraphQL) par OAuth d'une app publique ou personnalisée | Non : OAuth avec secret client, et une app publique doit passer la revue de Shopify | Gratuit pour le marchand ; revue de l'app | Plus tard ; **import CSV des commandes dès maintenant** |
| QuickBooks Online | API Accounting, OAuth 2.0 | Non : secret client + jetons de rafraîchissement à garder côté serveur | Programme développeur Intuit gratuit, mais validation de l'app pour la production | Plus tard |
| Square, PayPal, Etsy | OAuth | Non (même raison) | Variables | Plus tard ; **import CSV** |
| Banque | Pas d'API ouverte au Canada pour les particuliers (agrégateurs payants : Flinks, Plaid) | Non, et coûteux | Payant | Non ; **import CSV** du relevé |

## Ce qui est en place (v1)

1. **Stripe en lecture seule, sans serveur** (`App/Services/StripeSync.swift`)
   - L'utilisateur crée une clé restreinte (`rk_live_…`) avec **une seule autorisation** : *Balance transactions : Read*. Ardane refuse les clés secrètes (`sk_…`) et ne demande jamais de mot de passe.
   - La clé est gardée dans le **trousseau iOS** (`kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`) : jamais dans les fichiers partagés, les sauvegardes ou les widgets ; seule sa fin (« …a1B2 ») est affichée.
   - Synchronisation à l'ouverture de Business (si la dernière a plus d'une heure) et par le bouton « Synchroniser » : `GET /v1/balance_transactions` depuis la veille du dernier jour lu (12 mois la première fois), 100 par page.
   - Paiements → ventes ; remboursements → ventes négatives ; frais Stripe → une dépense par jour ; virements vers la banque → ignorés (déjà comptés).
   - **Pas de doublon** : chaque opération garde sa source et son identifiant Stripe (`SalesEntry.source/externalID`) ; une nouvelle synchronisation met à jour au lieu d'ajouter (`BusinessState.merge`). Les saisies à la main ne sont jamais touchées.
   - Date et résultat de la dernière synchronisation affichés ; erreurs claires (clé refusée, autorisation manquante, réseau, Stripe indisponible).
   - Déconnexion : la clé est effacée ; au choix, les ventes venues de Stripe sont gardées ou retirées.
2. **Import CSV** (`Shared/Domains/BusinessImport.swift`, `BusinessCSV`) : exports Stripe (paiements ou soldes), Shopify (commandes, une ligne par article), relevé bancaire ou tableur avec au moins une date et un montant. Virgules, points-virgules ou tabulations ; montants « 1 234,56 $ » ou « $1,234.56 » ; dates ISO, Shopify, jj/mm/aaaa. Paiements échoués, annulés et virements ignorés ; un fichier réimporté n'ajoute rien. Aperçu avant l'import (nombre de ventes, dépenses, lignes ignorées, période, avertissement si la devise diffère).
3. **Saisie à la main** : inchangée.

## Ce qui n'est pas prétendu

- Aucune intégration ne fonctionne sans action de l'utilisateur : il doit créer sa clé restreinte dans son tableau de bord Stripe.
- Testé par des tests unitaires sur des réponses et des fichiers d'exemple (`Tests/OctoberRequestsTests.swift`), **pas sur un vrai compte Stripe** : à vérifier avec une clé `rk_test_` (mode test) puis `rk_live_`.
- Les montants ne sont pas convertis d'une devise à l'autre : un avertissement s'affiche si la devise du compte ou du fichier diffère de celle d'Ardane.

## Architecture proposée pour Shopify, QuickBooks et Stripe Connect (à faire)

Un petit serveur sans état métier, par exemple Cloudflare Workers ou Firebase Functions :

1. `GET /oauth/<service>/start` : génère `state` (anti-CSRF, lié à l'appareil) et redirige vers la page d'autorisation du service avec des **portées minimales** (`read_orders` pour Shopify, `com.intuit.quickbooks.accounting` en lecture, `read_only` pour Stripe Connect).
2. `GET /oauth/<service>/callback` : vérifie `state`, échange le code contre les jetons **avec le secret client gardé dans les secrets du serveur** (jamais dans l'app ni dans GitHub), chiffre le jeton de rafraîchissement, et renvoie l'app par un lien universel (`https://…/connected`) avec un identifiant opaque.
3. `GET /sync/<service>?since=…` : l'app appelle avec l'identifiant opaque ; le serveur rafraîchit le jeton, lit les commandes/paiements et renvoie la même structure que `BusinessBatch` (identifiants externes compris), donc la même fusion sans doublon dans l'app.
4. `DELETE /connections/<id>` : révoque le jeton chez le service et l'efface.

À configurer avant de l'activer : comptes développeur (Shopify Partners, Intuit Developer, plateforme Stripe Connect), URL de redirection, secrets du serveur, mise à jour de la politique de confidentialité (un serveur Ardane traiterait alors des jetons), revue des apps par Shopify et Intuit.

## Confidentialité

La politique (`docs/legal/privacy.html`, `PRIVACY.md`) mentionne la connexion Stripe facultative : les données vont directement de l'iPhone à Stripe, rien n'est envoyé à Ardane, la clé reste dans le trousseau.
