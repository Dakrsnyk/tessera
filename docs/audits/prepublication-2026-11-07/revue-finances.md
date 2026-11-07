# Revue indépendante 24.C-D (Finances et autres)

Lecture statique, rien compilé. `python3 scripts/check_swift.py` : OK (3351 appels, 98 kinds).

## Verdict : OK avec réserves

Constats M-01, 02, 03, 04, 05, 06, 08, 11, 14, 15, 16, 17, 19, 20 : corrigés dans le code (vérifié ligne à ligne). M-04 : héros, tuile Argent et dépense rapide traités.

## À corriger avant fusion
1. Nouveaux textes absents de `Shared/Localizable.xcstrings` (affichés en français dans les 5 autres langues) : « Déjà fait » (TravelCarLifeSpaces.swift ~466), « Enregistrer la date » (~530), « prix à renseigner » (MoneyTiles.swift:248), « Sans prix : compté au prix payé » (MoneyTiles.swift ~254), « Dépensé ce mois-ci » et « Dépensé ce mois-ci : %@ » (FinancesApp.swift, MoneyTiles.swift), « Définir mon budget », « Budget à définir pour savoir ce qu'il te reste » (FinancesApp.swift), « dépensés ce mois-ci · budget à définir » (DashboardTiles.swift), les deux messages Stripe `keyMissing` et `partial` (StripeSync.swift:98-99). Correction : extract, traduire, merge, build, sync.

## Souhaitable
- StripeSync.swift (`nextSyncedUntil`) : après une lecture partielle, `syncedUntil` ne bouge pas, donc chaque synchronisation relit les mêmes 100 pages (pas de boucle infinie, pas de perte, mais coûteux). Option : avancer `syncedUntil` jusqu'à la plus ancienne opération lue moins un jour seulement si on lit par fenêtres.
- TravelPages.swift `TripBudgetText.parse` : en locale de/es/it/pt-BR, taper « 2.5 » donne 25 (le séparateur de milliers est supprimé avant le repli sur l'autre marque décimale). Le clavier décimal du système limite le risque.
- TravelPages.swift `saveBudget` : l'aller-retour `format` (4 décimales max) peut réécrire un budget à plus de 4 décimales au premier affichage ; négligeable.
- Audit24FinancesTests : M-04 testé seulement via `quickExpense` ; ni `DashboardTiles.money` ni le héros. M-03, M-11, M-14, M-20 non testés (vue ou keychain).
- Budget.swift `add` : plus aucune purge, la liste de dépenses grossit sans borne (volume modeste, à surveiller).
- Portfolio.swift `priceBook` : les actions sont supposées cotées en USD (Finnhub) ; un titre coté dans une autre devise serait mal converti. Sans clé Finnhub (cas actuel) sans effet.

## Intervalles semi-ouverts
`holds` remplace `contains` aux endroits où l'intervalle est une période civile : correct. `balanceHistory`, `statement`, `monthThroughDay` finissent à minuit suivant (calendrier, donc DST correct) ; dernier jour du mois = fin du mois exacte ; 23 h 59 incluse ; minuit du 1er compté une seule fois (testé par BudgetBoundsTests). `paymentDates` avait déjà `date < interval.end` : cohérent, aucun doublon. Seul effet : une opération datée exactement à `now` sur un intervalle `[début, now)` (monthToDate, growth, compare) est exclue ; invisible en usage réel.

## nextDue
Calcul depuis l'ancre, identique à `paymentDates` (31 janv. : 28 fév., 31 mars). Ancre future et passée : testé mentalement, même comportement qu'avant. Rappels (SmartReminders:62-71) : la boucle `nextDue(after: due+1 jour)` reste correcte.

## Compilation
`nonisolated` dans l'enum `@MainActor` : valide ; closure `page` non-échappante, pas de `@Sendable` requis en Swift 5. Nouveaux champs de `Position` et `Summary` ont des valeurs par défaut, aucun autre site d'appel. `Failure` : aucun `switch` exhaustif ailleurs. `FXRates`, `PriceBook`, `StripeTransactions.Page/Transaction` : inits du test conformes.
