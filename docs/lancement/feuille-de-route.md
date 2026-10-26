# Feuille de route : de l'état actuel à Ardane sur l'App Store

Écrite le 2026-10-26 (chantier 12). Décision de l'utilisateur : **démarrer en entreprise individuelle au Québec**, étudier la société plus tard (seuil indicatif : voir `docs/finance/estimation-revenus.md`). Objectif : 100 000 $ CAD de chiffre d'affaires annuel (≠ bénéfice ≠ argent retiré : `docs/finance/modele.md`).

Légende : RÉALISÉ / À VÉRIFIER / À CRÉER. Les coûts sont ceux des sources officielles consultées (`docs/finance/structures-quebec.md`, `apple.md`) ; « hypothèse » = non sourcé. Aucune dépense, démarche officielle ni envoi public n'est fait sans l'accord de l'utilisateur.

## Décision qui change des documents existants
`docs/entreprise-et-nom-vendeur.md` et `docs/guide-premium-testflight.md` se contredisaient (envoyer ou non les formulaires fiscaux avant la société). Avec l'entreprise individuelle : le vendeur affiché est le **nom légal de la personne** (Apple refuse un nom commercial pour un compte individuel), le formulaire américain est le **W-8BEN**, et on peut signer le contrat Paid Apps sans attendre. Une société plus tard = migration du compte individuel vers organisation (D-U-N-S, site, courriel au domaine) : possible, mais elle se prépare (voir `entreprise-et-nom-vendeur.md`).

## Étapes

| # | Étape | État | Coût estimé (CAD) | Délai indicatif | Dépend de | Fini quand |
|---|---|---|---|---|---|---|
| 1 | Fonctionnalités, interfaces, perfs, corrections | À VÉRIFIER | 0 | en cours | – | liste des correctifs vide ; `[daily]` vert ; essai sur iPhone |
| 2 | Tests : fonctionnels, non-régression, appareils, **mode gratuit** | À VÉRIFIER | 0 | 1 à 3 jours | 1 | passe gratuit faite (Demandes.md) ; `[unit]` + `[daily]` verts lus dans le journal complet ; essai iPhone gratuit/Premium |
| 3 | Audit de sécurité | EN COURS (agent 12.S) | 0 | 1 jour | – | critiques corrigés, test de confirmation pour chaque correction |
| 4 | Confidentialité, CGU, conformité (Loi 25, LPRPDE, UE) | politique RÉALISÉE ; CGU, URL publique, registre Loi 25 À CRÉER | 0 (validation juridique : hypothèse) | 1 à 2 jours + hébergement | 3 | politique sur URL stable ; CGU propres ou EULA Apple décidé et liés ; déclaration « App Privacy » préparée |
| 5 | Données personnelles et autorisations iOS | À VÉRIFIER | 0 | 0,5 jour | 3 | chaque permission justifiée et utilisée ; descriptions d'usage exactes |
| 6 | Entreprise individuelle et démarches | À CRÉER (action de l'utilisateur) | 41 $ immatriculation REQ, puis 41 $/an ; comptable : hypothèse 500 à 1 500 $/an | quelques jours (délai REQ non vérifié) | – | numéro d'entreprise obtenu ; TPS/TVQ décidée ; banque prête ; CPA rencontré |
| 7 | Compte Apple Developer et App Store Connect | compte RÉALISÉ (acheté le 2026-10-15) ; contrat, fiscalité, banque À FAIRE | 0 de plus cette année ; renouvellement annuel | 1 à 3 jours | 6 (nom légal, banque) | contrat Paid Apps « Actif » ; W-8BEN soumis ; banque saisie |
| 8 | Prix, abonnements, achats intégrés | code RÉALISÉ ; produits À CRÉER dans App Store Connect | 0 | 0,5 jour | 7 | 3 produits aux identifiants exacts, localisés FR/EN ; achat sandbox testé (achat, offre, restauration, annulation) |
| 9 | Fiche App Store, captures, classification | À CRÉER | 0 (captures : CI/pub) | 1 à 2 jours | 4, 8 | fiche FR/EN complète ; captures ; mots-clés ; classification ; capture de la page Premium |
| 10 | TestFlight, soumission, refus éventuels, publication | TestFlight interne RÉALISÉ ; soumission À FAIRE | 0 | revue Apple : délai non vérifié | 2 à 9, accord explicite pour `[testflight]` | version « Prête pour la vente » et téléchargeable |
| 11 | Lancement marketing, premiers utilisateurs, suivi financier | films RÉALISÉS (pub/film/) ; ASO et suivi À CRÉER | à fixer avec toi (voir Budget) | continu | 10 | tableau de suivi (ventes, remboursements, trésorerie) à jour |

## Risques principaux
1. **Rejet à la revue** (2.1 produits absents d'App Store Connect, 3.1.2 liens, 5.1.1 politique sur URL privée) : traités aux étapes 4, 8, 9.
2. **Dépôt public** : tout ce que la CI y expose est lisible par tous ; l'audit (3) le liste ; repasser en privé dès que possible (la CI en a besoin public pour l'instant).
3. **Hypothèse fiscale** : la société n'est pas démontrée avantageuse sous ≈ 70 000 $ de bénéfice (`synthese.md`) ; ne pas s'incorporer pour l'instant.
4. **Conversion payante** (1 à 3,5 %) : l'hypothèse la plus sensible du modèle 36 mois.
5. **Retenue américaine** sur les ventes : dépend du W-8BEN ; à confirmer avec un CPA.

## Budget
- **Minimum pour publier** : 41 $ (REQ) ; le compte Apple est déjà payé. Comptable : facultatif la première année si le chiffre d'affaires est faible, mais une rencontre unique avec un CPA (hypothèse : 150 à 400 $) est recommandée avant la première déclaration.
- **Recommandé** : CPA pour la première déclaration ; une adresse publique stable pour la politique de confidentialité (domaine ≈ 20 $/an, hypothèse).
- **Facultatif** : marketing payant, assurance, société.
- Prévisions 36 mois et retrait : `docs/finance/modele.md`, `estimation-revenus.md`.

## Ce que seul l'utilisateur peut faire
Immatriculation REQ (paiement de 41 $), banque, TPS/TVQ, signature du contrat Paid Apps et des formulaires fiscaux dans App Store Connect, création des produits sous son compte, soumission. Je prépare chaque étape avec les textes, les identifiants et les clics exacts.
