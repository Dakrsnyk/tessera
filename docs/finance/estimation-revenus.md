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

Règle de retrait du modèle : on retire 80 % de ce qui reste après impôts, cotisations et réserve minimale (≈ 1 739 $) ; le reste demeure dans l'entreprise. « Perso » = impôts fédéral et Québec + cotisations (RRQ/RQAP) à la charge de la personne. Pour l'entreprise individuelle, l'impôt porte sur tout le bénéfice, retiré ou non.

### 1 000 $/mois (12 000 $/an)
| Cas | Bénéfice | Impôt société | Impôt + cotis. perso | Net retiré | Laissé dans l'entreprise |
|---|---|---|---|---|---|
| Individuelle | 8 522 | – | 698 | **4 869** | 2 956 |
| Société, DPE-hyp., salaire | 7 207 | 706 | 12 | 2 345 | 2 738 |
| Société, DPE-hyp., dividendes | 7 207 | 1 208 | 0 | 2 357 | 2 328 |
| Société, petite ent., salaire | 7 207 | 335 | 14 | 2 781 | 2 654 |
| Société, petite ent., dividendes | 7 207 | 660 | 0 | 2 795 | 2 438 |

### 5 000 $/mois (60 000 $/an)
| Cas | Bénéfice | Impôt société | Impôt + cotis. perso | Net retiré | Laissé |
|---|---|---|---|---|---|
| Individuelle | 56 522 | – | 15 229 | **31 643** | 9 650 |
| Société, DPE-hyp., salaire | 55 207 | 3 665 | 5 368 | 27 517 | 14 215 |
| Société, DPE-hyp., dividendes | 55 207 | 11 048 | 1 154 | 31 731 | 9 960 |
| Société, DPE-hyp., mixte | 55 207 | 7 379 | 3 002 | 29 883 | 12 175 |
| Société, petite ent., salaire | 55 207 | 1 508 | 6 600 | 30 294 | 11 954 |
| Société, petite ent., dividendes | 55 207 | 6 036 | 1 618 | **35 276** | 10 962 |
| Société, petite ent., mixte | 55 207 | 3 784 | 3 946 | 32 948 | 11 556 |

### 10 000 $/mois (120 000 $/an)
| Cas | Bénéfice | Impôt société | Impôt + cotis. perso | Net retiré | Laissé |
|---|---|---|---|---|---|
| Individuelle | 116 522 | – | 39 112 | 60 537 | 16 873 |
| Société, DPE-hyp., salaire | 115 207 | 7 346 | 18 612 | 52 432 | 28 489 |
| Société, DPE-hyp., dividendes | 115 207 | 23 348 | 9 665 | 61 380 | 19 500 |
| Société, DPE-hyp., mixte | 115 207 | 15 370 | 14 057 | 56 988 | 24 082 |
| Société, petite ent., salaire | 115 207 | 2 980 | 22 017 | 57 502 | 23 631 |
| Société, petite ent., dividendes | 115 207 | 12 756 | 12 066 | **67 452** | 21 618 |
| Société, petite ent., mixte | 115 207 | 7 874 | 17 001 | 62 517 | 22 672 |

### 50 000 $/mois (600 000 $/an)
| Cas | Bénéfice | Impôt société | Impôt + cotis. perso | Net retiré | Laissé |
|---|---|---|---|---|---|
| Individuelle | 596 522 | – | 287 713 | 245 657 | 63 153 |
| Société, DPE-hyp., salaire | 595 207 | 40 991 | 167 844 | 208 481 | 158 964 |
| Société, DPE-hyp., dividendes | 595 207 | 121 748 | 144 265 | 232 059 | 95 820 |
| Société, DPE-hyp., mixte | 595 207 | 80 795 | 158 062 | 218 262 | 125 163 |
| Société, petite ent., salaire | 595 207 | 17 288 | 191 397 | 229 113 | 137 072 |
| Société, petite ent., dividendes | 595 207 | 66 516 | 165 521 | **254 989** | 106 866 |
| Société, petite ent., mixte | 595 207 | 41 588 | 180 467 | 240 043 | 119 479 |

## 4. Lecture

- **1 000 $/mois** : l'entreprise individuelle gagne nettement (≈ 4 900 $ retirés contre ≈ 2 800 $ en société) : une société coûte plus cher en comptable et en frais fixes pour un si petit bénéfice. Pas de raison de s'incorporer.
- **5 000 $/mois** : écart faible. La société avec le taux de petite entreprise (dividendes) donne ≈ 35 300 $ contre ≈ 31 600 $ en individuelle, mais seulement si le taux de petite entreprise s'applique (voir réserves). Avec le taux « DPE hypothèse », l'avantage disparaît. Zone de transition : on peut commencer en individuelle et s'incorporer plus tard.
- **10 000 $/mois** : la société devient plus avantageuse (≈ 67 500 $ contre ≈ 60 500 $ avec la petite entreprise), et surtout elle garde ≈ 20 000 $ de plus dans l'entreprise, imposés à taux réduit (report d'impôt).
- **50 000 $/mois** : écart marqué sur le net retiré (≈ 255 000 $ contre ≈ 246 000 $) et très marqué sur le report : ≈ 107 000 $ restent dans la société, imposés bien moins qu'à 53 % marginal. À ce niveau, un comptable et une structure (parfois holding) sont indispensables, et ce modèle ne les couvre pas.
- Le mode **dividendes** retire plus d'argent net à court terme, mais n'ajoute pas de droits RRQ/RQAP ; le mode **salaire** coûte plus d'impôt immédiat mais crée des droits (retraite, congé parental) et de l'espace REER. Le mixte est un compromis.
- Seuil de rentabilité indicatif de la société : autour de 5 000–8 000 $/mois net Apple (≈ 800 à 1 300 abonnés), à confirmer.

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
