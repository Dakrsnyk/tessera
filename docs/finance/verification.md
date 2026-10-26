# Vérification indépendante du pôle financier (2026-10-26)

Portée : `finance/params.json`, `model.py`, `withdrawal.py`, `tests/*`, `out/*.csv`, `modele.md`. Aucun code modifié.

## 1. Tests
`cd finance && python -m unittest discover -s tests` : 31 tests, OK (exécution locale ; ne prouve pas la CI).

## 2. Recalcul indépendant (script hors dépôt, sans importer model.py)
Central, mois 13 : 1 795,86 téléchargements ; 79,61 payants mensuels ; 24,46 paiements annuels ; 173,63 annuels actifs ; ventes au prix de liste 2 522,96 $ ; TTC 2 584,77 ; taxes 215,76 ; HT 2 369,01 ; commission 653,56 (30 % sur les ventes de 1re année, 15 % cohorte 1 mensuelle et renouvellements annuels) ; proceeds 1 715,45 ; remboursements 47,38 (2 % x HT) ; net 1 668,07 $ = 2 301,94 CAD ; dépenses 452,62 (dont registre 41, Apple 136,62) ; bénéfice 1 849,32. Tout correspond au CSV `central.csv` (écart < 0,01).
Impôt individuel : B = 40 000 : RRQ 4 599, RQAP 305,60, fédéral 2 179,41, Québec 2 260,08. B = 100 000 : RRQ 9 790,60, RQAP 764, fédéral 10 518,40, Québec 11 907,06. Société 70 000 $, dividendes (20,5 %) : B_soc 68 685, impôt société 14 080, dividende 42 293, fédéral 95, Québec 2 243, net 39 955 : identique à `retrait.csv`.

## 3. Logique
- Taxes hors CA, commission sur HT (une fois), 30 % -> 15 % au 13e paiement mensuel et au 1er renouvellement annuel, achat à vie à 30 %, bienvenue 4,99/6,99 sur les 3 premiers mois : corrects.
- Remboursements comptés une fois (r x HT si Apple garde sa commission). Hypothèse prudente cohérente avec apple.md §5. Non retirés des abonnés actifs (surestime un peu les cohortes).
- Annuel et à vie : revenu reconnu à l'encaissement (mois de vente). Le « bénéfice comptable » n'est donc PAS étalé sur 12 mois ; seul le décalage de 2 mois distingue trésorerie et bénéfice. À écrire clairement (modele.md l. 24).
- Conversion USD->CAD appliquée au net : correct. Taxe sur la commission d'Apple (Canada) ignorée (signalée).

## 4. Sources (échantillon de 8)
| Paramètre | Statut annoncé | Constat |
|---|---|---|
| Société fédérale 9 % / 15 % | vérifié | confirmé (canada.ca, 2026-10-26) |
| Plafond d'affaires 500 000 $ | cité | confirmé (même page) |
| Barème fédéral 58 523 / 117 045 | vérifié | confirmé (canada.ca/.../current-year.html, 2026-10-26) |
| Apple 70 %/85 %, Small Business 85 % | vérifié | confirmé (developer.apple.com/app-store/subscriptions/, 2026-10-26) |
| DPE Québec 9 % + 11,5 % = 20,5 % | hypothèse | honnête (heures rémunérées) |
| RRQ 12,6 %, 74 600, 3 500 | vérifié | source citée dans structures-quebec.md ; 2e cotisation 8 % déduite, à confirmer |
| RQAP 0,764 % / 103 000 | vérifié | idem (page non relue par moi) |
| Crédit dividende Québec 3,933 % | à confirmer | note KPMG parle de 3,42 % : risque sur le net en dividendes |
| Seuil TPS/TVQ 30 000 $ | vérifié | cité dans structures-quebec.md (non relu) |
| Montants personnels 16 452 / 18 952 | à confirmer | extraits de recherche, honnête |
Non confirmés en ligne par moi : revenuquebec.ca, retraitequebec, rqap (outil web limité).
`withdraw_share` (params.json l. 645-648) et `welcome_months` sont marqués « vérifié » alors que la source est « consigne » : ce n'est pas une vérification.

## 5. Conclusions du doc
- « 80 % du bénéfice inatteignable » : vrai, mais par construction (retrait = 80 % du distribuable, distribuable < B, 42 lignes sur 42 « non »). Ce n'est pas un résultat empirique ; maximum observé 64,3 %.
- Seuil 70 000 $ : le tableau ne le montre pas. Société en dividendes >= individuelle déjà à 40 000 $ (23 179 contre 23 134 net, 7 542 contre 7 522 laissés) et l'écart à 100 000 $ n'est que +4 %. Comparaison à retraits non égaux (80 % de D différents) et impôt futur sur le reste en société ignoré.

## 6. Écarts
Bloquants : aucun pour le modèle de ventes.
Mineurs :
1. modele.md l. 59 : « cohérent avec le seuil 70 000 $ » -> reformuler : les deux structures sont proches de 40 000 à 100 000 $, la décision vient du report d'impôt et du nom de vendeur.
2. modele.md l. 24 / model.py l. 11 : préciser « bénéfice sur base d'encaissement, annuel/à vie non étalés ».
3. params.json l. 648 et l. 280 : statut « vérifié » -> « consigne ».
4. withdrawal.py l. 148 : RRQ employé sans déduction (simplification, légèrement pessimiste en salaire).
5. model.py l. 149 : remboursés restent actifs.

## Verdict
FIABLE SOUS RÉSERVES : calculs de ventes et d'impôt exacts à la main ; réserves = (a) crédit de dividende Québec (3,933 % contre 3,42 %), (b) taux société 20,5 % (heures rémunérées), (c) base d'encaissement non étalée, (d) conclusion « seuil 70 000 $ » non démontrée par le tableau. Aucun CPA n'a validé.
