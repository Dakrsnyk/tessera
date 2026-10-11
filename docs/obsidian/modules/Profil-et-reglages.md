---
tags: [ardane, module, zone/interface]
---

# Profil et réglages

Zone : **Interface (App/Screens)** · Cartes : [[Vue-Globale.canvas|Vue globale]] · [[Architecture.canvas|Architecture]] · [[Fonctionnalites.canvas|Fonctionnalités]]

Le profil (qui est la personne, ses chiffres) et tous les réglages de l'app.

## Ce qui existe (vérifié dans le code)

- Informations de la personne et données demandées là où un widget les utilise.
- Rappels intelligents (séance, repas, factures), notifications locales.
- Icône de l'app (19 icônes), style de l'app (10 styles `AppStyleID`, clair/sombre).
- Sauvegarde et import, aide (tutoriel), note de l'app.

## Fichiers sources

- [App/Screens/Profile/ProfileView.swift](../../../App/Screens/Profile/ProfileView.swift)
- [App/Screens/Profile/ProfileTopics.swift](../../../App/Screens/Profile/ProfileTopics.swift)
- [App/Screens/Profile/DataItemViews.swift](../../../App/Screens/Profile/DataItemViews.swift)
- [App/Screens/Profile/SmartRemindersView.swift](../../../App/Screens/Profile/SmartRemindersView.swift)
- [App/Screens/Profile/AppIconPicker.swift](../../../App/Screens/Profile/AppIconPicker.swift)
- [App/Core/AppIcons.swift](../../../App/Core/AppIcons.swift)
- [Shared/Model/Settings.swift](../../../Shared/Model/Settings.swift)
- [Shared/Theme/AppStyle.swift](../../../Shared/Theme/AppStyle.swift)
- [Shared/Support/SmartReminders.swift](../../../Shared/Support/SmartReminders.swift)
- [App/Services/NotificationScheduler.swift](../../../App/Services/NotificationScheduler.swift)
- [Shared/Model/ReviewPrompt.swift](../../../Shared/Model/ReviewPrompt.swift)

## Relations

- [[Donnees-et-stockage]] : sauvegarde
- [[Services-externes]] : UserNotifications
- [[Onboarding-et-tutoriel]] : aide

## Fichiers du module (11)

- [[AppIcons (swift)]]
- [[AppIconPicker (swift)]]
- [[DataItemViews (swift)]]
- [[ProfileTopics (swift)]]
- [[ProfileView (swift)]]
- [[SmartRemindersView (swift)]]
- [[NotificationScheduler (swift)]]
- [[ReviewPrompt (swift)]]
- [[Settings (swift)]]
- [[SmartReminders (swift)]]
- [[AppStyle (swift)]]

## Dépend de (mesuré dans le code)

- [[Domaines-metier]] : 10 fichier(s)
- [[Creer-espaces]] : 6 fichier(s)
- [[Planning-et-habitudes]] : 5 fichier(s)
- Premium et abonnements : 4 fichier(s)
- Studio (éditeur de widgets) : 4 fichier(s)
- Données et stockage : 3 fichier(s)
- Outils partagés (Shared/Support) : 3 fichier(s)
- Autres mini-apps : 2 fichier(s)
- Finances : 2 fichier(s)
- Fitness : 2 fichier(s)
- Noyau : AppModel et Router : 2 fichier(s)
- Nutrition : 1 fichier(s)
- Widgets : extension et rendu : 1 fichier(s)

## Services et frameworks

- [[UserNotifications]] : 4 fichier(s)
- [[App Group]] : 2 fichier(s)
- [[StoreKit]] : 1 fichier(s)
- [[WidgetKit]] : 1 fichier(s)

Partie de [[Ardane]].

> À mettre à jour quand ce module change (voir `CLAUDE.md` et `scripts/obsidian_map.py`).
