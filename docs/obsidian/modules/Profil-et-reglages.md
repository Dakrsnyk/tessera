---
tags: [ardane, module, interface]
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

> À mettre à jour quand ce module change (voir `CLAUDE.md` et `scripts/obsidian_map.py`).
