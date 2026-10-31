---
tags: [ardane, memoire, campagne-2026]
---

# 06 · Finance — 19 s, 9:16 (+ 1:1, 4:5, 16:9)

Faits : [[Faits-verifies]] §7 · voix : film `finance` (`Fi1…Fi6`) · [[Ressources-a-capturer]].

## Concept créatif
« Sache où en est ton argent. » Épuré, graphique, calme : le chiffre est la vedette. La courbe du solde dessinée à 60 i/s, puis revenus / dépenses / solde en trois mots, puis le mois d'un coup d'œil. Pas d'argent « magique » : on dit clairement que c'est la personne qui saisit (« You enter it. You stay in control. »), jamais de connexion bancaire. Fin sur le widget Budget restant qui rejoint l'écran d'accueil et la promesse commune.

## Storyboard (1 140 images)
| Plan | Temps | Image | Caméra | Transition |
|---|---|---|---|---|
| P1 | 0,0–3,2 | Noir/Saphir ; le chiffre du solde (`app-finances-s00`) roule jusqu'à sa valeur (compteur). Texte « Know where your money stands. » | poussée sur le chiffre | le chiffre devient l'origine de la courbe |
| P2 | 3,2–6,4 | Revenus, dépenses, solde : trois pastilles avec compteur. Textes « Income / Expenses / Balance » | trois coupes de 1 s | la pastille Solde s'étire en courbe |
| P3 | 6,4–9,4 | Courbe du mois (`app-finances-s01`), mois gratuit ; puis sélecteur 3 mois / Année en « Avec Premium » | travelling le long de la courbe | passage aux catégories |
| P4 | 9,4–12,2 | Catégories avec limites (`app-finances-categories`), factures à venir (`app-finances-bills`), objectifs d'épargne (`app-finances-savings`) en trois cartes qui se superposent. | cartes en profondeur | cartes → widgets |
| P5 | 12,2–14,8 | Écran d'accueil Saphir : widgets Budget restant (Petit) et Dépense rapide ; légende « You enter it. You stay in control. » ; (Dépenses par catégorie, Premium, en 3e position avec la mention) | rotation du téléphone | contraction |
| P6 | 14,8–19,0 | Close | fixe | fin |

## Texte à l'écran
P1 `finance.title` · P2 `finance.income`, `finance.expenses`, `finance.balance` · P3 `finance.month`, `finance.threeMonths`, `finance.year`, `common.withPremium` · P4 `finance.categories`, `finance.bills`, `finance.savings` · P5 `finance.manualNote`, `common.homeScreen` · P6 `common.wordmark`, `common.wholeLifeOnePlace`, `common.comingSoon` · bas `common.demoData`.

## Voix off
| Id | Début | EN | FR |
|---|---|---|---|
| Fi1 | 0,4 | Know where your money stands. | Sache où en est ton argent. |
| Fi2 | 3,4 | Income. Expenses. Balance. | Revenus. Dépenses. Solde. |
| Fi3 | 6,6 | See your month at a glance. | Vois ton mois d'un coup d'œil. |
| Fi4 | 9,6 | Bills, savings goals, categories. | Factures, objectifs d'épargne, catégories. |
| Fi5 | 12,4 | Right on your Home Screen. | Directement sur ton écran d'accueil. |
| Fi6 | 15,0 | Ardane. Your whole life. One place. | Ardane. Toute ta vie. Un seul endroit. |
Voix posée, presque murmurée ; pas de chiffres lus.

## Ressources
- Remotion existant : `Essentials` (Argent), `WidgetLift`, `Close`. À CRÉER : compteur animé du solde et tracé de la courbe à partir de la capture (image haute recollée), plan des trois cartes.
- Captures : `app-finances-s00…s10`, `app-finances-categories/bills/savings/transactions`, `budgetLeft-s-*`, `moneyDashboard-*`/`spendingByCategory-*` (Premium), `lock-budgetLeft-rect`. Manquants (saisie d'un revenu, comptes) : [[Ressources-a-capturer]].
- Mentions : « Avec Premium » pour 3 mois/Année et pour Dépenses par catégorie / Tableau de bord. Gratuit : Mois, 7 jours, Budget restant, Dépense rapide, objectifs d'épargne.
- Interdits : banque connectée, synchronisation, reçus, « automatique », rendement, conseil financier.
