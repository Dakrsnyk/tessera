---
tags: [ardane, module, zone/interface]
---

# Autres mini-apps

Zone : **Interface (App/Screens)** · Cartes : [[Vue-Globale.canvas|Vue globale]] · [[Architecture.canvas|Architecture]] · [[Fonctionnalites.canvas|Fonctionnalités]]

Business, Voyage, Auto et Météo, plus les espaces Placements, Marchés et Ma vie.

## Ce qui existe (vérifié dans le code)

- Business : ventes, résultats, récurrent, indicateurs.
- Voyage : programme, budget en devise (taux Frankfurter), météo du voyage, liste.
- Auto : pleins, kilométrage, entretien, échéances, coûts.
- Météo : prévisions Open-Meteo pour la ville choisie.
- Placements et marchés : cours CoinGecko et Finnhub, données SEC des sociétés.

## Fichiers sources

- [App/Screens/MiniApps/Business/BusinessApp.swift](../../../App/Screens/MiniApps/Business/BusinessApp.swift)
- [App/Screens/MiniApps/Business/BusinessPages.swift](../../../App/Screens/MiniApps/Business/BusinessPages.swift)
- [App/Screens/MiniApps/Travel/TravelApp.swift](../../../App/Screens/MiniApps/Travel/TravelApp.swift)
- [App/Screens/MiniApps/Travel/TravelPages.swift](../../../App/Screens/MiniApps/Travel/TravelPages.swift)
- [App/Screens/MiniApps/Car/CarApp.swift](../../../App/Screens/MiniApps/Car/CarApp.swift)
- [App/Screens/MiniApps/Car/CarPages.swift](../../../App/Screens/MiniApps/Car/CarPages.swift)
- [App/Screens/MiniApps/Weather/WeatherApp.swift](../../../App/Screens/MiniApps/Weather/WeatherApp.swift)
- [App/Screens/Spaces/MoneySpaces.swift](../../../App/Screens/Spaces/MoneySpaces.swift)
- [App/Screens/Spaces/TravelCarLifeSpaces.swift](../../../App/Screens/Spaces/TravelCarLifeSpaces.swift)

## Relations

- [[Services-externes]] : Open-Meteo, Frankfurter, CoinGecko, Finnhub, SEC
- [[Domaines-metier]]

## Fichiers du module (9)

- [[BusinessApp (swift)]]
- [[BusinessPages (swift)]]
- [[CarApp (swift)]]
- [[CarPages (swift)]]
- [[TravelApp (swift)]]
- [[TravelPages (swift)]]
- [[WeatherApp (swift)]]
- [[MoneySpaces (swift)]]
- [[TravelCarLifeSpaces (swift)]]

## Dépend de (mesuré dans le code)

- [[Domaines-metier]] : 6 fichier(s)
- [[Creer-espaces]] : 2 fichier(s)
- [[Mini-apps]] : 2 fichier(s)
- Outils partagés (Shared/Support) : 2 fichier(s)
- Services externes et frameworks Apple : 2 fichier(s)
- Widgets : extension et rendu : 2 fichier(s)
- Accueil : Mon Quotidien : 1 fichier(s)
- Noyau : AppModel et Router : 1 fichier(s)
- Planning, tâches et habitudes : 1 fichier(s)
- Profil et réglages : 1 fichier(s)

## Services et frameworks

- [[Swift Charts]] : 6 fichier(s)
- [[CoreLocation]] : 1 fichier(s)

Partie de [[Ardane]].

> À mettre à jour quand ce module change (voir `CLAUDE.md` et `scripts/obsidian_map.py`).
