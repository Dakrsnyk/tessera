# Listes pour l'entreprise individuelle Ardane (2026-11-04)

NEQ **2282741356**, immatriculée le 2026-11-04, nom d'entreprise « Ardane », CAE 2851 (Industrie du progiciel), aucun salarié. Adresse professionnelle publiée : celle du domicile ; le domicile lui-même est « non publiable » au registre.

Tout ce qui est fiscal reste une hypothèse tant qu'un CPA du Québec ne l'a pas confirmé (voir `docs/finance/`). Ne jamais écrire de NAS, de numéro de compte ou de mot de passe dans ce dépôt ni dans une conversation : l'utilisateur les saisit lui-même.

Ordre recommandé : A (banque) et B (CPA) d'abord, puis C (App Store Connect). Ne pas signer le formulaire fiscal américain ni décider des taxes avant B.

---

## A. Compte bancaire (Desjardins)

Objectif : un compte distinct pour les versements d'Apple, avec un second compte (épargne) pour mettre de côté 25 % de chaque versement pour l'impôt (décision notée dans `docs/lancement/passation-session.md`).

### À apporter
- [ ] Le PDF de l'état de renseignements du registre (page imprimée le 2026-11-04 : preuve d'immatriculation).
- [ ] Le NEQ 2282741356.
- [ ] Une pièce d'identité avec photo (demander à la caisse si une deuxième pièce est exigée).
- [ ] Le NAS (à fournir soi-même à la caisse, jamais par écrit ici).
- [ ] Le reçu de paiement du Registraire (41 $), au cas où.

### À demander à la caisse
- [ ] Quel type de compte pour une entreprise individuelle, et quels documents sont exigés exactement (la liste de la caisse prime sur celle-ci).
- [ ] Frais mensuels, nombre de transactions incluses, frais sur les dépôts.
- [ ] **Nom exact du titulaire** tel qu'il sera inscrit sur le compte (à recopier mot pour mot dans App Store Connect).
- [ ] Compte en dollars canadiens ; existe-t-il un compte en dollars américains, et est-il utile.
- [ ] Un compte d'épargne lié pour la réserve d'impôt.
- [ ] Accès en ligne pour entreprise et carte : y a-t-il des frais.
- [ ] Les trois numéros nécessaires à un dépôt direct (institution, transit, compte), à noter soi-même ; un spécimen de chèque ou un document bancaire les donne.
- [ ] La date d'ouverture effective du compte (pour les versements d'Apple).

---

## B. Rendez-vous avec un CPA du Québec

Coût estimé : 150 à 400 $ (estimation du dépôt, non sourcée). Un seul rendez-vous suffit pour valider les décisions ; les formulaires se remplissent ensuite avec ses réponses.

### Documents à apporter
- [ ] PDF de l'état de renseignements du registre.
- [ ] `docs/finance/synthese.md` et `docs/finance/structures-quebec.md` (hypothèses à confirmer).
- [ ] Tarifs prévus : mensuel 6,99 $, annuel 59,99 $, à vie 99,99 $ (USD, à confirmer dans App Store Connect) ; commission Apple 30 % la première année d'un abonné puis 15 %, ou 15 % avec le Small Business Program (`docs/finance/apple.md`).
- [ ] Les frais déjà payés : compte Apple Developer (acheté le 2026-10-15), domaine `ardane.app` (acheté le 2026-10-29, expire le 2027-10-29), immatriculation (41 $ le 2026-11-03).

### Questions
**Taxes (TPS/TVQ)**
- [ ] Faut-il s'inscrire dès le départ (inscription volontaire) ou attendre le seuil de 30 000 $ ?
- [ ] Si je ne m'inscris pas : perte des crédits de taxe sur mes achats et sur la commission d'Apple, quel ordre de grandeur ?
- [ ] Quelle est la date limite pour s'inscrire après avoir dépassé 30 000 $ ?
- [ ] Les ventes faites via l'App Store hors du Québec et hors du Canada comptent-elles dans les 30 000 $ ? Quel est le rôle d'Apple (agent) pour la TPS/TVQ ?
- [ ] Que doit-on déclarer à Apple si on n'est pas inscrit (son questionnaire canadien demande les numéros de TPS/TVQ) ?

**Impôt américain**
- [ ] Comment remplir le W-8BEN ligne par ligne : numéro d'identification fiscal (NAS ?), pays de résidence, convention Canada–États-Unis, taux de retenue sur les versements d'Apple.
- [ ] Si le formulaire n'est pas fourni correctement, quelle retenue Apple applique-t-elle ?

**Déclarations**
- [ ] Les droits annuels d'immatriculation de 41 $ : l'entreprise est-elle « jumelée » (payés avec la déclaration de revenus, ligne 438) ou payés au Registraire séparément ? Quand ?
- [ ] Quelles déclarations pour la première année (revenus d'entreprise dans la déclaration personnelle), quels délais, y a-t-il des acomptes provisionnels à verser ?
- [ ] Dépenses déductibles : part du logement (je suis locataire), ordinateur, téléphone de test, compte Apple Developer, domaine, abonnements, logiciels.
- [ ] Faut-il tenir une comptabilité particulière, et quel outil (tableur, logiciel) suffit-il pour la première année.
- [ ] Cotisations RRQ, RQAP : montants à prévoir comme travailleur autonome.

**Structure**
- [ ] À partir de quel bénéfice la société devient-elle plus avantageuse (les notes parlent d'environ 70 000 $ par an, hypothèse) ?
- [ ] Le transfert vers une société dans environ 6 mois : démarches, coûts, effet sur le compte Apple (migration individuel vers organisation, voir `docs/entreprise-et-nom-vendeur.md`).
- [ ] Assurances : une protection est-elle utile, par exemple responsabilité civile.

**Divers**
- [ ] Coût du suivi annuel (déclarations) et de la rencontre de départ.
- [ ] Qu'est-ce qui doit être conservé, combien de temps (reçus, relevés Apple).

---

## C. App Store Connect (après A et B)

Source : `docs/guide-premium-testflight.md`. Rien ne se soumet avant que la banque soit ouverte et que le CPA ait validé le formulaire fiscal.

### Prérequis
- [ ] Compte bancaire ouvert (numéros d'institution, de transit et de compte en main).
- [ ] Décision TPS/TVQ prise ; numéros TPS et TVQ si inscrit.
- [ ] Nom légal exact : « Mathys Lecointre » comme sur la pièce d'identité et le compte Apple (le vendeur affiché reste le nom légal en compte individuel).

### Étapes
- [x] **Business › Agreements** : ligne Paid Apps › View and Agree to Terms › Agree (fait ; état « En attente d'infos de l'utilisateur » tant que la banque manque).
- [x] **Tax Forms** (2026-11-23) : FP-2506-V (TVQ, numéros TPS/TVQ) actif ; questionnaire américain refait (Apple proposait d'abord un W-9, à ne jamais remplir) ; « Certificate of Foreign Status » et W-8BEN envoyés : ligne 6a NAS, ligne 10 article XII(3)(b) de la convention Canada–États-Unis (logiciel), 0 %, « Income from the sale of applications ». Pas encore validé par un CPA. Adresse du compte Apple écrite « Apparemment 1 » : faute à faire corriger par Apple (Membership and Account).
- [ ] **Bank Accounts** › Add Bank Account : Canada, devise CAD, titulaire exactement comme à la caisse.
- [ ] Attendre que **Paid Apps, Tax Forms et Bank Accounts** soient **Active**.
- [ ] Créer les 3 produits Premium aux identifiants de `Config/Ardane.storekit` (partage familial désactivé ; groupe d'abonnement « Ardane Premium » ; décisions du 2026-10-29).
- [ ] Vérifier dans l'app que la page Premium ne dit plus « Les offres ne sont pas encore disponibles ».
- [ ] Voir `docs/finance/apple.md` pour le Small Business Program (commission de 15 %) et son inscription.

---

## D. Dates et rappels

| Quand | Quoi | État |
|---|---|---|
| 2026-11-04 | Immatriculation au registre | fait |
| À confirmer par le CPA | Droits annuels d'immatriculation de 41 $ (pénalité de 50 % en retard) | à noter dans le calendrier ; prudence : novembre 2027 |
| 2027-10-29 | Renouvellement du domaine `ardane.app` | rappel à poser |
| Annuel | Renouvellement du compte Apple Developer | date à noter |
| À confirmer par le CPA | Déclaration de revenus avec revenus d'entreprise (habituellement fin avril pour le paiement, mi-juin pour la production des travailleurs autonomes) | à confirmer |

## E. Dossier de justificatifs à garder

- [ ] PDF de l'état de renseignements du registre (2026-11-04) et accusé / reçu de paiement (41 $).
- [ ] Factures : Apple Developer, domaine, logiciels, matériel.
- [ ] Relevés mensuels Apple (ventes, commissions, versements, retenues).
- [ ] Relevés du compte bancaire dédié.
- [ ] Un tableau des revenus et dépenses mis à jour chaque mois.
