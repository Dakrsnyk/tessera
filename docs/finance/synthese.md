# Synthèse : pôle financier et lancement (2026-10-26)

Sources : docs/finance/structures-quebec.md, apple.md, etat-lancement.md, modele.md, verification.md, outils.md. Verdict de la vérification indépendante : **fiable sous réserves**. Aucun CPA n'a validé : tout chiffre fiscal est à confirmer.

## Réponses courtes
- **Structure pour commencer** : entreprise individuelle (41 $ de création, 41 $/an). Société par actions québécoise (397 $, puis 106 $/an) si le nom du vendeur ou la responsabilité comptent ; l'intérêt fiscal seul n'est PAS démontré avant environ 70 000 $ de bénéfice (hypothèse à faire confirmer). Société fédérale écartée.
- **Commission Apple** : 30 % la 1re année d'un abonné, 15 % ensuite ; 15 % pour tous avec le Small Business Program (revenus ≤ 1 M$ US). Apple perçoit et verse les taxes de vente ; versement environ 45 jours après la fin du mois fiscal.
- **Taxes** : inscription TPS/TVQ obligatoire au-delà de 30 000 $ ; inscription volontaire possible (crédits sur les dépenses).
- **Retrait de 80 %** : retirer 80 % du bénéfice lui-même est inatteignable ; en retirant 80 % du distribuable, tu gardes 50 à 64 % du bénéfice en poche (individuel) et 41 à 58 % (société, dividendes).
- **Modèle 36 mois** (bénéfice avant impôt, base d'encaissement, individuel, années 1/2/3) : prudent -32 / 1 763 / 3 912 $ CAD ; central 12 027 / 34 088 / 64 667 ; optimiste 70 511 / 200 520 / 355 827. Abonnés actifs nécessaires (central, 15 %/30 %) : 207/252 pour 12 000 $, 846/1 032 pour 60 000 $, 1 378/1 682 pour 100 000 $. Hypothèse la plus sensible : la conversion payante (1 à 3,5 %).
- **Outils** : trois dépôts MIT, aucun ne couvre le Québec ; rien installé ; copie manuelle d'au plus cinq modules d'Open Accountant si utile (voir outils.md).

## Prochaines actions priorisées (rien n'est fait sans ton accord)
1. **Décider du vendeur** (individu ou société) : conditionne contrat, banque, fiscalité, nom affiché. Ne pas envoyer les formulaires fiscaux avant (conflit documentaire à résoudre).
2. **Rencontrer un CPA québécois** (1 heure) avec docs/finance/ : taux réel d'une société sans employé, TPS/TVQ des ventes via Apple, retenue américaine/W-8, seuil d'incorporation.
3. **Trancher l'essai annuel** (README annonce 7 jours, la configuration n'en a pas) et « 3 ou 30 widgets gratuits ».
4. **Passe de tests en mode gratuit** (Demandes.md) avant toute soumission.
5. **Rendre la politique de confidentialité publique** sur une URL stable ; décider des CGU (ou EULA Apple).
6. **Créer les 3 produits dans App Store Connect**, signer le contrat Paid Apps, banque, tests sandbox.
7. **Fiche App Store** (FR/EN, captures, mots-clés, classification), vérifier les licences restantes (Mixkit, polices, icônes).
8. **Soumission** après TestFlight public sur accord explicite ; marketing et suivi (App Store Connect Analytics, remboursements).

## Budget (faits sourcés, voir structures-quebec.md ; reste « non vérifié »)
- Initial : compte Apple Developer déjà payé ; individuel 41 $ ; société 397 $ (+ réservation du nom 27 $ facultative) ; D-U-N-S gratuit ; comptable : non sourcé (hypothèse 1 000 à 2 500 $/an).
- Récurrent : registre 41 $ (individuel) ou 106 $ (société) ; compte Apple Developer annuel ; comptable ; domaine/courriel si société.

## Non vérifié / à confirmer
Pages Revenu Québec illisibles par l'outil (chiffres lus dans des extraits) ; RRQ, RQAP, crédit de dividende, retenue américaine, coût du comptable, prix 6,99/59,99/99,99 $ US dans App Store Connect.
