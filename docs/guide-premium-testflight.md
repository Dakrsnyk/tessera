# Tester Premium avec TestFlight, soi-même et avec des amis (2026-10-16)

Dans une version TestFlight, tous les achats intégrés passent par le « sandbox » d'Apple : **rien n'est jamais facturé**, et chacun achète avec son propre compte Apple. Il suffit que les produits Premium existent dans App Store Connect. Aucun code « Premium gratuit » n'est à ajouter (App Review teste aussi en sandbox : ce serait un risque de rejet).

## Étape 1 — Contrat payant, impôts, banque (une seule fois)

App Store Connect, compte titulaire (Account Holder) :

1. **Business** (en haut) › onglet **Agreements** › ligne **Paid Apps** › **View and Agree to Terms** › **Agree**.
2. Même page, **Tax Forms** › **Add Tax Info** : le questionnaire américain (W-8BEN en général pour un particulier canadien), puis le formulaire Canada : numéro de TPS/TVH et numéro de TVQ (Québec). À vérifier si tu n'es pas inscrit aux taxes (petit fournisseur) : Apple ne documente pas ce cas.
3. **Bank Accounts** › **Add Bank Account** › Canada › devise CAD, type de compte, numéros › titulaire exactement comme à la banque › cocher l'accord › **Add**.
4. Attendre que **Paid Apps**, **Tax Forms** et **Bank Accounts** soient **Active**. Avant cela, l'app ne reçoit aucun produit : la page Premium dit « Les offres ne sont pas encore disponibles. ».

## Étape 2 — Créer les 3 produits (identifiants exactement comme dans le code)

Dans **Apps › Ardane** (Bundle ID `com.dakrsnyk.ardane`) › barre latérale **Monetization**. Un identifiant de produit ne se modifie ni ne se réutilise jamais : vérifier lettre par lettre avant **Create**.

**Achat à vie** — **In-App Purchases** › (+) › **Non-Consumable**
- Reference Name : `Premium à vie` · Product ID : `com.dakrsnyk.tessera.premium.lifetime` › **Create**.
- **Availability** : tous les pays · **Price Schedule** › **Add Pricing** › Canada › 99,99 $.
- **Localization** › français (Canada) puis anglais : nom (2 à 30 caractères) et description (45 au plus).
- **Review Information** : une capture de la page Premium de l'app › **Save**.
- **Family Sharing** : ne l'activer que si tu le veux vraiment (irréversible).

**Abonnements** — **Subscriptions** › (+) › nom du groupe `Tessera Premium` › **Create**
- Dans le groupe : **Display Name and Description** › **Add** › langues, nom visible (ex. « Ardane Premium »). Oubli le plus fréquent : sans cela, les abonnements restent bloqués.
- **Mensuel** : **Create** › Product ID `com.dakrsnyk.tessera.premium.monthly` › durée **1 month** › prix 6,99 $ › pays › nom et description › capture › **Save**.
- **Annuel** : Product ID `com.dakrsnyk.tessera.premium.yearly` › durée **1 year** › 59,99 $ › même chose.
- **Offre de lancement du mensuel** : abonnement mensuel › **Subscription Prices** › **View all Subscription Pricing** › **Set up Introductory Offer** › pays › date de début › **Pay as you go**, **3 months**, 4,99 $ › **Confirm** (non modifiable ensuite).

**Ne pas cliquer « Add for Review »** : ce n'est utile que pour la sortie sur l'App Store. Attendre jusqu'à 1 h.

## Étape 3 — Tester toi-même

1. Ouvrir Ardane installée par TestFlight › page Premium : les 3 prix doivent s'afficher.
2. Tester d'abord le **mensuel** (offre de lancement), puis l'annuler : Profil › « Gérer l'abonnement ». Dans TestFlight, un abonnement se renouvelle **chaque jour, 6 fois au plus**, puis s'arrête (environ une semaine), même l'annuel.
3. Acheter **« à vie » en dernier** : avec ton vrai compte Apple, cet achat de test ne peut pas être effacé ; Premium restera actif sur toutes tes versions TestFlight et tu ne reverras plus la page d'achat.
4. « Restaurer mes achats » et une réinstallation retrouvent l'achat.

## Étape 4 — Faire tester des amis

Préférer des **testeurs externes** (lien ou courriel). Des testeurs internes devraient recevoir un rôle dans App Store Connect, avec accès à tes données.

1. **Test Information** : onglet **TestFlight** › **Additional** › **Test Information** :
   - **Beta App Description** (obligatoire) ;
   - **Feedback Email** : `support.ardane@gmail.com` ;
   - **Privacy Policy URL** : `https://claude.ai/artifact/M2hUyRzRz9zxoSMJ4PJ5X8`, après l'avoir rendue publique (menu Partager › « toute personne disposant du lien ») ;
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
> 3. Pour avoir Premium : dans Ardane, ouvre Premium et choisis **« À vie »**. La fenêtre d'Apple affiche un prix, mais **rien n'est débité** : c'est une version de test. Les abonnements de test s'arrêtent seuls après une semaine, le « à vie » reste.
> 4. Pour me faire un retour : fais une capture d'écran dans l'app, touche la vignette, puis choisis l'option de commentaire bêta (ou ouvre TestFlight › Ardane › Envoyer un commentaire bêta).
> Ton achat de test ne sera pas repris dans la version de l'App Store.

## Ce qui ne fonctionne pas en test

- Un compte enfant avec « Demander pour acheter » reste bloqué en attente.
- Un ami qui a déjà utilisé l'offre de lancement ne peut pas la reprendre.
- Les achats de test ne passent pas à la version App Store.
- Il est interdit de faire payer l'accès à la bêta (directive 2.2).
