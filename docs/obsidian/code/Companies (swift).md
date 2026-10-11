---
tags: [ardane, code, zone/metier]
source: Shared/Domains/Companies.swift
---

# Companies.swift

Module : [[Domaines-metier]] · Fichier : [Shared/Domains/Companies.swift](../../../Shared/Domains/Companies.swift) · 225 lignes

> App-wide identity used for API etiquette (the SEC asks for a contact in the User-Agent).

**Déclare :** `AppInfo`, `BigNumber`, `CompanyCache`, `CompanyFinancials`, `CompanyRef`, `CompanyService`, `FinancialPeriod`, `MarketsState`

## Utilise (autres modules)

- Données et stockage : `SharedStore.swift`
- Outils partagés (Shared/Support) : `Formatting.swift`, `Helpers.swift`
- Services externes et frameworks Apple : `WeatherService.swift`

## Services et frameworks

- [[SEC EDGAR]]
- App Group

Utilisé par 10 fichier(s) : `AppModel.swift`, `DataBackup.swift`, `PremiumConfiguration.swift`, `MoneySpaces.swift`, `DomainData.swift`, `SampleData.swift`, `FoodDatabase.swift`, `StoredStates.swift`, `BusinessTiles.swift`, `MoneyTiles.swift`
