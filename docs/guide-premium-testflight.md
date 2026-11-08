# Tester Premium avec TestFlight, soi-même et avec des amis (2026-10-16)

Dans une version TestFlight, tous les achats intégrés passent par le « sandbox » d'Apple : **rien n'est jamais facturé**, et chacun achète avec son propre compte Apple. Il suffit que les produits Premium existent dans App Store Connect. Aucun code « Premium gratuit » n'est à ajouter (App Review teste aussi en sandbox : ce serait un risque de rejet).

## Étape 1 — Contrat payant, impôts, banque (une seule fois)

App Store Connect, compte titulaire (Account Holder) :

1. **Business** (en haut) › onglet **Agreements** › ligne **Paid Apps** › **View and Agree to Terms** › **Agree**.
2. Même page, **Tax Forms** › **Add Tax Info** : le questionnaire américain (W-8BEN en général pour un particulier canadien), puis le formulaire Canada : numéro de TPS/TVH et numéro de TVQ (Québec). À vérifier si tu n'es pas inscrit aux taxes (petit fournisseur) : Apple ne documente pas ce cas.
3. **Bank Accounts** › **Add Bank Account** › Canada › devise CAD, type de compte, numéros › titulaire exactement comme à la banque › cocher l'accord › **Add**.
4. Attendre que **Paid Apps**, **Tax Forms** et **Bank Accounts** soient **Active**. Avant cela, l'app ne reçoit aucun produit : la page Premium dit « Les offres ne sont pas encore disponibles. ».

## Étape 2 — Créer les 2 abonnements (identifiants exactement comme dans le code)

Dans **Apps › Ardane** (Bundle ID `com.dakrsnyk.ardane`) › barre latérale **Monetization**. Un identifiant de produit ne se modifie ni ne se réutilise jamais : vérifier lettre par lettre avant **Create**.

**Pas d'achat à vie au lancement** (décision de l'utilisateur du 2026-11-08) : ne pas créer `com.dakrsnyk.ardane.premium.lifetime`, et surtout pas pour le supprimer ensuite (un identifiant supprimé ne se réutilise jamais). Le code le demande toujours à l'App Store : s'il est créé un jour (non consommable, 99,99 $, « Premium à vie » / « Tout Premium pour toujours. Un seul paiement. », « Lifetime Premium » / « All of Premium, forever. One payment. »), la page Premium l'affichera avec sa mention légale, sans mise à jour de l'app.

**Abonnements** — **Subscriptions** › (+) › nom du groupe `Ardane Premium` › **Create**
- Dans le groupe : **Display Name and Description** › **Add** › langues, nom visible (ex. « Ardane Premium »). Oubli le plus fréquent : sans cela, les abonnements restent bloqués.
- **Mensuel** : **Create** › Product ID `com.dakrsnyk.ardane.premium.monthly` › durée **1 month** › prix 6,99 $ › pays › nom et description › capture › **Save**.
- **Annuel** : Product ID `com.dakrsnyk.ardane.premium.yearly` › durée **1 year** › 59,99 $ › même chose.
- **Essai gratuit de 7 jours, sur le mensuel ET sur l'annuel** (c'est ce que l'app affiche : « 7 jours gratuits… rien n'est débité » ; corrigé le 2026-11-05, l'ancienne offre « Pay as you go 3 mois à 4,99 $ » n'existe pas dans le code) : pour chacun des deux abonnements › **Subscription Prices** › **View all Subscription Pricing** › **Set up Introductory Offer** › tous les pays › date de début › type **Free**, durée **1 week** › **Confirm** (non modifiable ensuite). L'essai ne se prend qu'une fois par groupe.
- **Textes à saisir** (identiques au fichier `Config/Ardane.storekit` ; en anglais, en français (Canada) et en français (France)) : mensuel « Premium mensuel » / « Tout Premium, chaque mois. Essai de 7 jours. » ; annuel « Premium annuel » / « Tout Premium pendant un an. Essai de 7 jours. » (55 au plus). Anglais : « Lifetime Premium » / « All of Premium, forever. One payment. » ; « Premium Monthly » / « All of Premium, billed monthly. 7-day trial. » ; « Premium Yearly » / « All of Premium for a year. 7-day trial. ». Niveaux du groupe : annuel 1, mensuel 2.

**Ne pas cliquer « Add for Review »** : ce n'est utile que pour la sortie sur l'App Store. Attendre jusqu'à 1 h.

## Étape 3 — Tester toi-même

1. Ouvrir Ardane installée par TestFlight › page Premium : les 2 prix doivent s'afficher.
2. Tester d'abord le **mensuel** (offre de lancement), puis l'annuler : Profil › « Gérer l'abonnement ». Dans TestFlight, un abonnement se renouvelle **chaque jour, 6 fois au plus**, puis s'arrête (environ une semaine), même l'annuel.
3. Les abonnements de test s'arrêtent seuls : pour revoir la page d'achat, attendre la fin des renouvellements ou annuler.
4. « Restaurer mes achats » et une réinstallation retrouvent l'achat.

## Étape 4 — Faire tester des amis

Préférer des **testeurs externes** (lien ou courriel). Des testeurs internes devraient recevoir un rôle dans App Store Connect, avec accès à tes données.

1. **Test Information** : onglet **TestFlight** › **Additional** › **Test Information** :
   - **Beta App Description** (obligatoire) ;
   - **Feedback Email** : `support.ardane@gmail.com` ;
   - **Privacy Policy URL** : `https://ardane.app/privacy.html` ;
   - **Beta App Review Information** : tes coordonnées ; **Sign-in required** : non.
2. **Groupe** : (+) à côté de **External Testing** › nom « Amis » › **Create**.
3. **Build** : dans « Amis » › **Add Builds** › la dernière version › **What to Test** › cocher **Automatically notify testers** › **Submit Review**. La première version passe par la vérification d'Apple (de 1 à plusieurs jours en 2026). Les versions suivantes de la même version (1.0) passent souvent sans nouvelle vérification.
4. **Inviter** : groupe « Amis » › **Testers** › **Create Public Link** › **Filter by Criteria** : iOS 17 ou plus (Ardane l'exige) › **Set Limit** (ex. 20) › **Confirm** › copier le lien. Ou (+) › **Email**.
5. **Chaque nouvelle version** : les groupes externes n'ont pas de distribution automatique. Après chaque envoi TestFlight, ajouter le build au groupe « Amis » (**Add Builds**). Claude peut automatiser cette étape dans la CI avec la clé API existante.
6. Une version TestFlight expire après **90 jours**.

## Message à envoyer aux amis

> Salut ! Tu peux tester Ardane avant sa sortie :
> 1. Installe l'app **TestFlight** depuis l'App Store (iPhone en iOS 17 ou plus).
> 2. Ouvre ce lien sur ton iPhone : [lien public] › **Accepter** › **Installer**.
> 3. Pour avoir Premium : dans Ardane, ouvre Premium et choisis **l'annuel** ou **le mensuel**. La fenêtre d'Apple affiche un prix, mais **rien n'est débité** : c'est une version de test. Les abonnements de test s'arrêtent seuls après environ une semaine ; il suffit alors de reprendre un abonnement.
> 4. Pour me faire un retour : fais une capture d'écran dans l'app, touche la vignette, puis choisis l'option de commentaire bêta (ou ouvre TestFlight › Ardane › Envoyer un commentaire bêta).
> Ton achat de test ne sera pas repris dans la version de l'App Store.

## Ce qui ne fonctionne pas en test

- Un compte enfant avec « Demander pour acheter » reste bloqué en attente.
- Un ami qui a déjà utilisé l'offre de lancement ne peut pas la reprendre.
- Les achats de test ne passent pas à la version App Store.
- Il est interdit de faire payer l'accès à la bêta (directive 2.2).

## En attendant le contrat payant : des amis en testeurs internes, Premium débloqué (2026-10-17)

La version `[interne]` (Premium débloqué, « Internal Only ») ne va qu'aux testeurs internes, c'est-à-dire des utilisateurs de ton compte App Store Connect (100 au plus). Inviter seulement des personnes de confiance.

1. App Store Connect › **Utilisateurs et accès** › (+) : prénom, nom, courriel de l'identifiant Apple de l'ami ; rôle **Marketing** ; accès aux apps limité à **Ardane** › **Inviter**. L'ami accepte l'invitation reçue par courriel.
2. **Apps › Ardane › TestFlight** › (+) à côté de **Tests internes** › groupe « Amis » › cocher **Distribution automatique** › ajouter les amis (une fois l'invitation acceptée).
3. Le groupe reçoit la dernière version interne (la plus récente marquée « Interne ») ; avec la distribution automatique, chaque nouvelle version lui parvient seule. Une version normale `[testflight]` arrive aussi et n'a pas Premium : Claude envoie une version interne après chaque série.
4. L'ami installe **TestFlight** (iPhone en iOS 17 ou plus), ouvre l'invitation reçue par courriel › **Accepter** › **Installer**. Vérifier dans Ardane › Profil › Premium : « Débloqué en mode test ».
5. Une version TestFlight expire après 90 jours.
