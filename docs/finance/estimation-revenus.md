# Estimation par palier : 1 000 / 5 000 / 10 000 / 50 000 $ par mois

Calculée le 2026-10-25 avec le moteur existant (`finance/estimation_revenus.py`, qui réutilise `finance/withdrawal.py` et `finance/params.json`). Estimation, pas un conseil fiscal : tout point marqué « à confirmer » doit être validé par un CPA du Québec.

## 1. Ce que « génère X $/mois » veut dire ici

Hypothèse retenue : **X = versements nets d'Apple, en CAD, par mois** (après la commission d'Apple, hors taxes de vente que Apple perçoit et remet elle-même), **avant** nos propres dépenses. Autres lectures, pour comparer :

| Palier (net Apple) | Ventes hors taxes si commission 15 % (après 1 an) | Ventes hors taxes si commission 30 % (1re année) | Abonnés actifs requis (15 %) | Abonnés actifs requis (30 %) |
|---|---|---|---|---|
| 1 000 $ | ≈ 1 176 $ | ≈ 1 429 $ | ≈ 160 | ≈ 196 |
| 5 000 $ | ≈ 5 882 $ | ≈ 7 143 $ | ≈ 799 | ≈ 976 |
| 10 000 $ | ≈ 11 765 $ | ≈ 14 286 $ | ≈ 1 598 | ≈ 1 951 |
| 50 000 $ | ≈ 58 824 $ | ≈ 71 429 $ | ≈ 7 990 | ≈ 9 752 |

(Abonnés : scénario central, mix mensuel/annuel du modèle, remboursements inclus, change 1,38, retenue américaine du modèle. Les achats à vie ne sont pas comptés : ils font monter le net sans abonné.) Si tu voulais dire « profit dans ma poche » ou « ventes brutes », reprends la colonne qui correspond.

## 2. Dépenses supposées (par an)

- Entreprise individuelle : ≈ 3 478 $ (compte développeur Apple 99 US$, comptable 1 000 $, registre 41 $, assurance, frais pro.).
- Société : ≈ 4 793 $ (comptable 2 250 $, registre 106 $ en plus, mêmes frais de base).
- Aucun frais d'IA/serveur (politique : tout sur l'appareil). Les frais de marketing ne sont pas inclus dans ces paliers.

## 3. Résultats par an (CAD)

Bénéfice avant impôt B = revenus annuels − dépenses de l'individuelle (3 478 $) : 8 522 / 56 522 / 116 522 / 596 522 $. Pour la société, le moteur retire en plus son surcoût (1 315 $). Correction du 2026-10-25 : la première version déduisait ce surcoût deux fois.

#### A. Règle du modèle : retrait de 80 % du distribuable

**1 000 $/mois (12 000 $/an)**

| Cas | Impôt société | Impôt + cotis. perso | Net retiré | Laissé dans l'entreprise |
|---|---|---|---|---|
| Individuelle | 0 | 698 | 4 869 | 2 956 |
| Société  taux prudent 20 5 %  salaire | 798 | 16 | 3 177 | 3 093 |
| Société  taux prudent 20 5 %  dividendes | 1 478 | 0 | 3 193 | 2 537 |
| Société  taux prudent 20 5 %  mixte | 1 138 | 8 | 3 185 | 2 815 |
| Société  petite entreprise 11 2 %  salaire | 372 | 33 | 3 696 | 2 947 |
| Société  petite entreprise 11 2 %  dividendes | 807 | 0 | 3 729 | 2 671 |
| Société  petite entreprise 11 2 %  mixte | 590 | 9 | 3 720 | 2 816 |

**5 000 $/mois (60 000 $/an)**

| Cas | Impôt société | Impôt + cotis. perso | Net retiré | Laissé dans l'entreprise |
|---|---|---|---|---|
| Individuelle | 0 | 15 229 | 31 643 | 9 650 |
| Société  taux prudent 20 5 %  salaire | 3 746 | 5 625 | 28 096 | 14 527 |
| Société  taux prudent 20 5 %  dividendes | 11 318 | 1 251 | 32 470 | 10 169 |
| Société  taux prudent 20 5 %  mixte | 7 554 | 3 199 | 30 522 | 12 436 |
| Société  petite entreprise 11 2 %  salaire | 1 540 | 6 888 | 30 941 | 12 208 |
| Société  petite entreprise 11 2 %  dividendes | 6 183 | 1 726 | 36 102 | 11 196 |
| Société  petite entreprise 11 2 %  mixte | 3 874 | 4 166 | 33 662 | 11 800 |

**10 000 $/mois (120 000 $/an)**

| Cas | Impôt société | Impôt + cotis. perso | Net retiré | Laissé dans l'entreprise |
|---|---|---|---|---|
| Individuelle | 0 | 39 112 | 60 537 | 16 873 |
| Société  taux prudent 20 5 %  salaire | 7 427 | 18 957 | 52 924 | 28 801 |
| Société  taux prudent 20 5 %  dividendes | 23 618 | 9 902 | 61 979 | 19 709 |
| Société  taux prudent 20 5 %  mixte | 15 545 | 14 347 | 57 534 | 24 343 |
| Société  petite entreprise 11 2 %  salaire | 3 015 | 22 385 | 58 067 | 23 904 |
| Société  petite entreprise 11 2 %  dividendes | 12 903 | 12 331 | 68 121 | 21 852 |
| Société  petite entreprise 11 2 %  mixte | 7 964 | 17 326 | 63 126 | 22 916 |

**50 000 $/mois (600 000 $/an)**

| Cas | Impôt société | Impôt + cotis. perso | Net retiré | Laissé dans l'entreprise |
|---|---|---|---|---|
| Individuelle | 0 | 287 713 | 245 657 | 63 153 |
| Société  taux prudent 20 5 %  salaire | 41 083 | 168 289 | 208 872 | 159 324 |
| Société  taux prudent 20 5 %  dividendes | 122 018 | 144 667 | 232 493 | 96 029 |
| Société  taux prudent 20 5 %  mixte | 80 976 | 158 486 | 218 675 | 125 447 |
| Société  petite entreprise 11 2 %  salaire | 17 328 | 191 895 | 229 550 | 137 383 |
| Société  petite entreprise 11 2 %  dividendes | 66 663 | 165 971 | 255 474 | 107 100 |
| Société  petite entreprise 11 2 %  mixte | 41 681 | 180 941 | 240 504 | 119 752 |

#### B. Retrait de 100 % du distribuable (reste la réserve minimale ≈ 1 739 $)

**1 000 $/mois (12 000 $/an)**

| Cas | Impôt société | Impôt + cotis. perso | Net retiré | Laissé dans l'entreprise |
|---|---|---|---|---|
| Individuelle | 0 | 698 | 6 086 | 1 739 |
| Société  taux prudent 20 5 %  salaire | 621 | 51 | 3 940 | 2 409 |
| Société  taux prudent 20 5 %  dividendes | 1 478 | 0 | 3 991 | 1 739 |
| Société  taux prudent 20 5 %  mixte | 1 053 | 10 | 3 981 | 2 086 |
| Société  petite entreprise 11 2 %  salaire | 257 | 96 | 4 565 | 2 035 |
| Société  petite entreprise 11 2 %  dividendes | 807 | 0 | 4 661 | 1 739 |
| Société  petite entreprise 11 2 %  mixte | 536 | 12 | 4 650 | 1 920 |

**5 000 $/mois (60 000 $/an)**

| Cas | Impôt société | Impôt + cotis. perso | Net retiré | Laissé dans l'entreprise |
|---|---|---|---|---|
| Individuelle | 0 | 15 229 | 39 554 | 1 739 |
| Société  taux prudent 20 5 %  salaire | 1 842 | 8 216 | 33 935 | 7 143 |
| Société  taux prudent 20 5 %  dividendes | 11 318 | 2 315 | 39 836 | 1 739 |
| Société  taux prudent 20 5 %  mixte | 6 602 | 5 184 | 36 967 | 4 529 |
| Société  petite entreprise 11 2 %  salaire | 373 | 9 794 | 37 491 | 2 955 |
| Société  petite entreprise 11 2 %  dividendes | 6 183 | 3 156 | 44 129 | 1 739 |
| Société  petite entreprise 11 2 %  mixte | 3 290 | 6 392 | 40 893 | 2 445 |

**10 000 $/mois (120 000 $/an)**

| Cas | Impôt société | Impôt + cotis. perso | Net retiré | Laissé dans l'entreprise |
|---|---|---|---|---|
| Individuelle | 0 | 39 112 | 75 672 | 1 739 |
| Société  taux prudent 20 5 %  salaire | 3 479 | 25 949 | 63 902 | 13 494 |
| Société  taux prudent 20 5 %  dividendes | 23 618 | 14 995 | 74 856 | 1 739 |
| Société  taux prudent 20 5 %  mixte | 13 515 | 20 592 | 69 259 | 7 487 |
| Société  petite entreprise 11 2 %  salaire | 654 | 29 858 | 70 707 | 5 188 |
| Société  petite entreprise 11 2 %  dividendes | 12 903 | 18 380 | 82 186 | 1 739 |
| Société  petite entreprise 11 2 %  mixte | 6 723 | 24 316 | 76 249 | 3 020 |

**50 000 $/mois (600 000 $/an)**

| Cas | Impôt société | Impôt + cotis. perso | Net retiré | Laissé dans l'entreprise |
|---|---|---|---|---|
| Individuelle | 0 | 287 713 | 307 071 | 1 739 |
| Société  taux prudent 20 5 %  salaire | 21 137 | 218 551 | 252 900 | 81 972 |
| Société  taux prudent 20 5 %  dividendes | 122 018 | 190 027 | 281 424 | 1 739 |
| Société  taux prudent 20 5 %  mixte | 71 003 | 206 297 | 265 154 | 39 626 |
| Société  petite entreprise 11 2 %  salaire | 5 151 | 248 057 | 278 748 | 40 838 |
| Société  petite entreprise 11 2 %  dividendes | 66 663 | 216 656 | 310 149 | 1 739 |
| Société  petite entreprise 11 2 %  mixte | 35 593 | 234 365 | 292 441 | 18 798 |

## 4. Lecture (chiffres corrigés)

- **1 000 $/mois** : individuelle gagnante (≈ 6 086 $ retirés à 100 % contre ≈ 4 661 $ en société, meilleur cas).
- **5 000 $/mois** : société petite entreprise en dividendes ≈ 44 129 $ contre ≈ 39 554 $ en individuelle ; avec le taux prudent, ≈ 39 836 $ : quasi égalité.
- **10 000 $/mois** : société petite entreprise ≈ 82 186 $ contre ≈ 75 672 $ ; taux prudent ≈ 74 856 $ (un peu en dessous de l'individuelle).
- **50 000 $/mois** : ≈ 310 149 $ (petite entreprise) contre ≈ 307 071 $ en individuelle ; le vrai gain est ailleurs : à 80 % de retrait, la société garde ≈ 107 000 $ imposés à taux réduit.
- Meilleure répartition du modèle : 0 % salaire / 100 % dividendes ; chaque tranche de 10 % de salaire coûte du net en année 1 (charges RRQ/RQAP/FSS/CNESST), mais crée des droits (retraite, RQAP, REER) que le modèle ne valorise pas.
- Le taux de petite entreprise est la clé : sans lui (taux prudent), la société ne bat l'individuelle que d'un cheveu ou perd.

## 5. Réserves : à confirmer avec un CPA du Québec

1. Le **taux de petite entreprise** (déduction accordée aux petites entreprises) exige de ne pas être une société de placement ni une « entreprise de prestation de services personnels » ; le Québec réserve aussi le taux réduit aux sociétés qui emploient au moins 5 employés à temps plein, sinon le taux pris est de l'ordre de 20,5 % combiné (variante « DPE-hyp. »). C'est pour cela que les deux variantes sont montrées : la prudente est « DPE-hyp. ».
2. Les revenus App Store sont des **ventes de services numériques à des clients étrangers** : traitement de la TPS/TVQ (inscription, seuil de 30 000 $), retenue américaine (formulaire W-8), à valider.
3. Cotisations Québec (RRQ, RQAP, FSS, CNESST), crédits d'impôt sur dividendes et taux 2026 : estimés, pas certifiés.
4. Le comptable à 1 000 $ / 2 250 $ est une hypothèse.
5. Change fixé à 1,38 CAD/USD ; la commission passe de 30 % à 15 % après 12 mois d'abonnement payé continu ou via le Small Business Program (admissible sous 1 M US$ de revenus) : à confirmer sur les pages Apple.
6. Pas de marketing, pas d'impôt de l'étranger, pas de pertes reportées, pas de revenu autre que l'app.

## 6. Reproduire

```bash
cd finance && python3 estimation_revenus.py
```

Prochaine étape suggérée (rien n'est fait sans ton accord) : rencontre avec un CPA pour trancher individuelle ou société selon le palier visé à 12 mois.

## 7. Toutes les combinaisons salaire + dividendes (2026-10-25)

`python3 finance/optimisation.py [paliers]` calcule 376 combinaisons (structure × part du distribuable retirée de 50 à 100 % × salaire de 0 $ à « tout en salaire »), le reste du retrait étant versé en dividendes. Sorties : `finance/out/optimisation.csv` (toutes les lignes) et `finance/out/optimisation_resume.md` (meilleurs cas par critère). L'agent `comptable` (`.claude/agents/comptable.md`, lecture seule) les lit, compare et liste ce qu'un CPA doit confirmer.
