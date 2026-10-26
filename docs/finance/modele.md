# Modèle financier Ardane (36 mois) et retrait des bénéfices

Date des sources : 2026-10-26. Code dans `finance/` (Python 3 standard seulement ; openpyxl absent : pas de `modele.xlsx`, CSV uniquement). Ce n'est pas un avis fiscal : tout ce qui est « hypothèse » ou « à confirmer CPA » reste à valider. Sources des taux : `structures-quebec.md`, `apple.md`, `outils.md` (aucun module existant ne couvre le Québec : rien n'est repris des barèmes américains ou britanniques).

## 1. Mode d'emploi

- Hypothèses : `finance/params.json`. Chaque paramètre a `value`, `source`, `status` (vérifié / hypothèse / à confirmer CPA). Ne modifier que `value`. Trois scénarios sous `scenarios` (prudent, central, optimiste) ; dépenses sous `depenses` (individuelle / société) ; commission sous `commission` ; change USD vers CAD sous `change.usd_cad` ; fiscalité sous `fiscalite` ; retrait sous `retrait`.
- Lancer : `python finance/model.py [--structure individuelle|societe]` puis `python finance/withdrawal.py`.
- Tests : `cd finance && python -m unittest discover -s tests` (31 tests, tous passent).
- Sorties dans `finance/out/` : `<scenario>.csv` (mensuel, standard) et `<scenario>_pme.csv` (variante Small Business 15 %) ; `resume.csv` (années 1 à 3) ; `abonnes_necessaires.csv` ; `retrait.csv`. Séparateur « ; », colonnes en français.
- Lire : `ventes_ttc_client_usd` = ce que paie le client ; `taxes_collectees_apple_usd` = à Apple/États, jamais à nous ; `chiffre_affaires_ht_usd` ; `commission_apple_usd` ; `proceeds_usd` = HT - commission ; `remboursements_usd` ; `revenus_nets_cad` ; `depenses_cad` ; `benefice_avant_impot_cad` ; `tresorerie_cad`.

## 2. Formules (model.py)

Prix de liste P (6,99 / 4,99 x 3 mois / 59,99 / 99,99 USD).
- Boutiques à prix TTC (part s_in, taux t_in) : HT = P/(1+t), taxe = P x t/(1+t). Boutiques à taxe ajoutée (s_ex, t_ex) : HT = P, taxe = P x t, client paie P(1+t). Reste : sans taxe. Le chiffre d'affaires est toujours HT.
- Nouveaux payants du mois = téléchargements x conversion x part du type. Téléchargements = min(d1 x (1+g)^(m-1), plafond) ; 0 pendant les mois d'inactivité (marketing aussi).
- Mensuels : la cohorte c paie son k-ième mois (k = m-c+1) avec (1-résiliation)^(k-1) survivants ; prix = mélange offre 4,99 / 6,99 pendant les 3 premiers mois, 6,99 ensuite ; commission 30 % pour k <= 12, 15 % dès k = 13.
- Annuels : paiement à l'achat (30 %), renouvelé tous les 12 mois avec le taux de renouvellement (15 % dès le premier renouvellement). Achat à vie : 30 % (0,15 en variante PME). Variante PME : 15 % partout, sans cumul vers 10 %.
- Commission = taux x HT (une seule fois, jamais dans les dépenses). Proceeds = HT - commission.
- Remboursements (part r des ventes) : coût = r x proceeds, plus r x commission si Apple garde sa commission (prudent, `commission_kept_by_apple` = true) ; donc perte totale r x HT.
- Revenus nets USD = proceeds - remboursements - retenue américaine (0 % par défaut) ; CAD = USD x taux de change.
- Dépenses : création au mois 1, registre aux mois 13 et 25, comptable lissé, programme développeur Apple (99 USD, premier renouvellement mois 13), assurances, frais professionnels, marketing, hébergement/API/IA (0).
- Bénéfice comptable avant impôt = revenus nets CAD - dépenses (aucun impôt, aucune TPS/TVQ). Trésorerie = départ + encaissements Apple (décalage de 2 mois) - dépenses.
- Abonnés nécessaires = (objectif + dépenses récurrentes annuelles) / revenus nets CAD par abonné et par an, en régime permanent (mix mensuel/annuel du scénario, hors offre de bienvenue et achats à vie), calculé à 15 % et à 30 % de commission.
- Aucun double comptage : taxes hors chiffre d'affaires ; commission déduite des proceeds seulement ; remboursements sur une ligne ; impôts absents du bénéfice comptable (traités dans withdrawal.py). Vérifié par les tests.

## 3. Résultats (scénarios, structure individuelle, USD→CAD 1,38, commission standard)

| Scénario | Année | Ventes HT (USD) | Taxes Apple (USD) | Commission (USD) | Revenus nets (CAD) | Dépenses (CAD) | Bénéfice avant impôt (CAD) | Abonnés actifs fin |
|---|---|---|---|---|---|---|---|---|
| prudent | 1 | 1 632 | 149 | 490 | 1 509 | 1 541 | -32 | 24 |
| prudent | 2 | 3 591 | 327 | 990 | 3 441 | 1 678 | 1 763 | 53 |
| prudent | 3 | 5 744 | 523 | 1 522 | 5 589 | 1 678 | 3 912 | 85 |
| central | 1 | 16 376 | 1 491 | 4 913 | 15 368 | 3 341 | 12 027 | 233 |
| central | 2 | 38 516 | 3 508 | 10 524 | 37 566 | 3 478 | 34 088 | 545 |
| central | 3 | 68 825 | 6 268 | 18 068 | 68 145 | 3 478 | 64 667 | 966 |
| optimiste | 1 | 81 299 | 7 404 | 24 390 | 76 852 | 6 341 | 70 511 | 1 060 |
| optimiste | 2 | 210 914 | 19 209 | 57 752 | 206 998 | 6 478 | 200 520 | 2 821 |
| optimiste | 3 | 360 431 | 32 826 | 92 485 | 362 305 | 6 478 | 355 827 | 4 829 |

Seuil de rentabilité (bénéfice cumulé qui reste >= 0) : prudent mois 14 (bénéfice mensuel positif dès le mois 4, trésorerie positive dès le mois 18 à cause du décalage Apple et de 2 mois d'inactivité) ; central mois 1 (trésorerie positive dès le mois 4) ; optimiste mois 1 (trésorerie dès le mois 3). Le central est positif tout de suite parce que les dépenses sont très basses (41 $ de création, pas de serveur) : c'est un résultat d'hypothèses, pas une prévision. Variante Small Business (15 % partout) : +24 % à +28 % de bénéfice l'année 1 (central, optimiste), +15 % à +23 % l'année 3 (voir `<scenario>_pme.csv`). Le modèle ne dit pas si le taux de conversion de 1 à 3,5 % est réaliste : c'est l'hypothèse la plus sensible.

Abonnés actifs nécessaires pour un bénéfice avant impôt annuel (central ; commission 15 % / 30 %) : 12 000 $ : 207 / 252 ; 30 000 $ : 446 / 545 ; 60 000 $ : 846 / 1 032 ; 100 000 $ : 1 378 / 1 682. Prudent : 179 / 415 / 807 / 1 331 à 15 %. Optimiste : 248 / 489 / 892 / 1 428 à 15 %. (Tous les chiffres dans `abonnes_necessaires.csv`.)

## 4. Retrait de 80 % du distribuable (CAD, par an)

Définitions : réserve = 6 mois de dépenses récurrentes (scénario central, environ 1 700 $ individuelle, plus en société) ; distribuable individuelle = B - impôts - cotisations - réserve ; distribuable société = B_soc x (1 - taux société) - réserve (B_soc = B moins le surcoût annuel de la société, environ 1 300 $). Retrait cible = 80 % du distribuable. « Net » = argent personnel après impôt personnel et cotisations. Entre parenthèses, net en % de B.

| B | Individuelle : net | Distribuable / B | Société 20,5 % : salaire | dividendes | mixte | Société 11,2 % : dividendes | Reste dans la société (div., 20,5 %) |
|---|---|---|---|---|---|---|---|
| 10 000 | 5 893 (59 %) | 74 % | 4 072 | 4 133 (41 %) | 4 122 | 4 779 | 2 772 |
| 20 000 | 12 700 (64 %) | 79 % | 10 000 | 10 493 (52 %) | 10 357 | 11 883 | 4 362 |
| 40 000 | 23 134 (58 %) | 72 % | 20 818 | 23 179 (58 %) | 22 409 | 25 724 | 7 542 |
| 70 000 | 37 810 (54 %) | 68 % | 34 033 | 39 955 (57 %) | 37 076 | 44 221 | 12 312 |
| 100 000 | 52 225 (52 %) | 65 % | 46 742 | 54 449 (54 %) | 50 677 | 59 710 | 17 082 |
| 150 000 | 75 096 (50 %) | 63 % | 66 011 | 77 237 (51 %) | 71 426 | 84 474 | 25 032 |

Lecture : retirer 80 % du distribuable donne en réalité 50 à 64 % de B en poche en individuelle, 41 à 58 % en société (dividendes, taux 20,5 %), le reste étant impôts, cotisations, réserve et 20 % non retirés. « Retirer 80 % du bénéfice » (au sens de B) n'est atteignable à aucun niveau : l'objectif réaliste est 80 % du distribuable, soit environ 50 à 65 % de B. Sous 40 000 $ de B, l'individuelle donne plus que la société (surcoût fixe, taux société 20,5 % dès le premier dollar) ; vers 70 000 $ et plus, les dividendes en société donnent un net un peu plus élevé et laissent plus d'argent dans la société (report d'impôt) : cohérent avec le seuil d'environ 70 000 $ de `structures-quebec.md`. Le salaire seul est le moins avantageux (cotisations RRQ/RQAP/FSS/CNESST). Le détail (impôts fédéral, Québec, société, cotisations) est dans `out/retrait.csv`. La variante à 11,2 % n'est possible qu'avec 5 500 heures rémunérées : improbable sans employé.

## 5. Vérifié, hypothèse, à confirmer par un CPA

Vérifié (sources dans params.json) : commission 30 % puis 15 % après un an de service payé, Small Business 15 %, proceeds = prix - taxes - commission, barèmes fédéral et Québec 2026, abattement 16,5 %, RRQ et RQAP du travailleur autonome, frais REQ, majoration de dividende 115 %, FSS.

Hypothèses : tous les paramètres des scénarios (téléchargements, conversion, mix, résiliation, renouvellement, remboursements), taux et parts de taxes Apple par région, taux de change 1,38, coût du comptable, assurances, marketing, programme développeur 99 USD, décalage de versement de 2 mois.

À confirmer par un CPA : prix de 6,99 / 4,99 / 59,99 / 99,99 USD réellement disponibles ; remboursement (Apple garde-t-il sa commission) ; retenue américaine et formulaire W-8 ; taux de la 2e cotisation RRQ (calculé à 8 %) ; montants personnels de base (16 452 $ fédéral, 18 952 $ Québec : extraits de recherche KPMG) ; crédit de dividende fédéral (9,0301 %, non vérifié dans le fichier) et québécois (3,933 % ; une note citée parle de 3,42 % puis 2,69 % en 2027) ; taux québécois réel de la société (11,5 % supposé, DPE exigeant des heures rémunérées) ; parts employé/employeur RQAP ; CNESST ; simplifications (déduction de la moitié de la RRQ, crédit à 14 %, pas de crédit pour emploi, pas de crédits de solidarité, TPS/TVQ non perçues sous 30 000 $ et taxe sur la commission d'Apple ignorée) ; intégration complète des dividendes ; impôt sur la trésorerie laissée dans la société (revenu de placement).


## Réserves de la vérification indépendante (2026-10-26, voir verification.md)
- Le « bénéfice comptable » du modèle est en **base d'encaissement** : les abonnements annuels et les achats à vie sont comptés quand ils sont payés, sans étalement. Un comptable étalerait ou non selon la méthode choisie.
- La conclusion « incorporer vers 70 000 $ » n'est PAS démontrée par le tableau seul : en dividendes, la société égale déjà l'entreprise individuelle vers 40 000 $ et ne la dépasse que d'environ 4 % à 100 000 $, les retraits comparés ne sont pas égaux, et l'impôt futur sur l'argent laissé dans la société est ignoré. Traiter 70 000 $ comme une hypothèse à faire confirmer par un CPA.
- « Retirer 80 % du bénéfice » est inatteignable par construction (le retrait vaut 80 % du distribuable, qui est inférieur au bénéfice) ; le maximum observé est 64,3 %.
- Statuts corrigés : `withdraw_share` et `welcome_months` sont des hypothèses, pas des faits vérifiés.
- Confirmés en ligne : société 9 %/15 % et plafond de 500 000 $ (canada.ca), barème fédéral (canada.ca), Apple 70/85 % et Small Business (developer.apple.com). Non confirmés : revenuquebec.ca, RRQ, RQAP.
