---
tags: [ardane, module, zone/interface]
---

# Mini-apps

Zone : **Interface (App/Screens)** · Cartes : [[Vue-Globale.canvas|Vue globale]] · [[Architecture.canvas|Architecture]] · [[Fonctionnalites.canvas|Fonctionnalités]]

Chaque mini-app est une partie entière d'Ardane : un tableau de bord, puis ses pages. Elles sont atteintes depuis l'Accueil.

## Ce qui existe (vérifié dans le code)

- `MiniApp` : nutrition, fitness, planning, finances, business, travel, car, weather.
- `MiniAppPage` : les pages de chaque mini-app (repas, séance, bibliothèque, historique…).
- « Mes paramètres » de chaque mini-app (`MiniAppSettings`), vues de semaine partagées (`WeekViews`).

## Fichiers sources

- [App/Screens/MiniApps/MiniApp.swift](../../../App/Screens/MiniApps/MiniApp.swift)
- [App/Screens/MiniApps/MiniAppSettings.swift](../../../App/Screens/MiniApps/MiniAppSettings.swift)
- [App/Screens/MiniApps/WeekViews.swift](../../../App/Screens/MiniApps/WeekViews.swift)

## Relations

- [[Nutrition]]
- [[Fitness]]
- [[Planning-et-habitudes]]
- [[Finances]]
- [[Autres-mini-apps]] : Business, Voyage, Auto, Météo, Études
- [[Domaines-metier]] : données de chaque mini-app

## Fichiers du module (3)

- [[MiniApp (swift)]]
- [[MiniAppSettings (swift)]]
- [[WeekViews (swift)]]

Partie de [[Ardane]].

> À mettre à jour quand ce module change (voir `CLAUDE.md` et `scripts/obsidian_map.py`).
