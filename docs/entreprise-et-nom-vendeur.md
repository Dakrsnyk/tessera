# Nom de vendeur et entreprise (recherche du 2026-10-16)

> **Décision du 2026-10-26 (chantier 12) :** l'utilisateur démarre en **entreprise individuelle**, société à étudier plus tard. Le vendeur affiché est donc son nom légal, et le conseil « ne pas envoyer les formulaires fiscaux maintenant » ci-dessous ne vaut que pour le scénario société : en individuel, suivre `docs/guide-premium-testflight.md` (W-8BEN, TPS/TVQ selon la décision sur l'inscription). Feuille de route : `docs/lancement/feuille-de-route.md`.

## Ce qu'Apple permet
- Compte **individuel** (le compte actuel) : le vendeur affiché est toujours le nom légal de la personne. Une entreprise individuelle avec un nom déclaré ne change rien (Apple refuse les noms commerciaux et les entreprises individuelles comme « organisation »).
- Pour un autre nom, il faut une **personne morale** : une société par actions (« inc. »), un numéro **D-U-N-S** (gratuit), un **site web public** sur un domaine à soi et un **courriel sur ce domaine**. Ensuite, demander à Apple de faire passer le compte individuel en organisation (formulaire « migrate individual account »). Le Team ID, la fiche Ardane, le bundle ID et les builds sont, d'après les témoignages, conservés ; certificats et profils peuvent devoir être refaits.
- Risque : le nom de développeur est fixé à la création de la première fiche d'app. Dans la demande de migration, demander explicitement que la fiche Ardane affiche la société.
- Transférer l'app vers un nouveau compte est impossible tant qu'aucune version n'est sortie : la migration est la seule voie.

## Noms proposés (vérifiés le 2026-10-16 : registre du Québec en données ouvertes, marques OPIC, App Store)
1. **Studio Ardane inc.** (recommandé) : rien trouvé ; studioardane.com et studioardane.ca semblaient libres.
2. **Applications Ardane inc.** : rien trouvé.
3. **Studio Quadrelle inc.** : nom indépendant d'une seule app ; rien trouvé.

Règles du Québec : générique français en tête (Studio, Applications, Logiciels…), puis « inc. ». « Ardane » seul n'est pas garanti. ardane.com est déjà pris.

## Étapes, dans l'ordre
1. **Ne pas envoyer maintenant**, sur le compte individuel : le questionnaire fiscal américain, le formulaire TPS/TVQ, le compte bancaire. Ne pas soumettre l'app à l'App Store.
2. Vérifier le nom : quebec.ca › « Rechercher une entreprise » ; marques : ised-isde.canada.ca/cipo/trademark-search. Réservation facultative : 27 $ (90 jours).
3. Constituer la société par actions québécoise en ligne (Québec.ca) : 397 $, environ 2 jours ouvrables, toi comme seul actionnaire et administrateur. Puis 106 $ par an (mise à jour annuelle).
4. Ouvrir un compte bancaire d'entreprise.
5. Revenu Québec, « Inscription d'une entreprise en démarrage » : TPS et TVQ de la société (formats 123456789RT0001 et 1234567890TQ0001).
6. Domaine (ex. studioardane.ca), site web simple et courriel (ex. contact@studioardane.ca). Claude peut faire le site.
7. D-U-N-S par l'outil d'Apple (developer.apple.com/support/D-U-N-S) : jusqu'à 5 jours ouvrables + 2 jours.
8. Demande de migration Individual › Organization ; préciser le nom à afficher.
9. Après la migration : contrat payant, formulaire américain de la société (W-8BEN-E), numéros TPS/TVQ, banque, puis les produits Premium et les testeurs externes (`docs/guide-premium-testflight.md`).

## Coûts approximatifs
- Départ : environ 400 à 450 $ de frais de l'État.
- Chaque année : 106 $ au registre, déclarations T2 et CO-17 même sans profit, comptable (estimation non sourcée : 1 000 à 2 500 $), frais bancaires.
- Option la moins chère : rester individuel et s'inscrire à la TPS/TVQ comme particulier (le vendeur reste alors ton nom).

## En attendant : tester Premium
- Tag CI `[interne]` : version TestFlight interne, Premium débloqué, vérifiée « Internal Only » par l'API (build 200, 2026-10-16).
- Les amis ne peuvent la recevoir que comme testeurs internes : utilisateurs d'App Store Connect (Utilisateurs et accès), avec un rôle limité à l'app Ardane, 100 au plus.
