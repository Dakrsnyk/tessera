---
tags: [ardane, module, zone/outils]
---

# Outils partagés (Shared/Support)

Zone : **Qualité et outillage** · Cartes : [[Vue-Globale.canvas|Vue globale]] · [[Architecture.canvas|Architecture]] · [[Fonctionnalites.canvas|Fonctionnalités]]

Petits outils communs à l'app et à l'extension : couleurs, dates, formats, décodage tolérant, diagnostic des widgets.

## Ce qui existe (vérifié dans le code)

- Couleurs hexadécimales, calculs de dates, formats de nombres et de dates selon la langue.
- Diagnostic des widgets manquants (builds de test), droits signés de l'App Group.

## Fichiers sources

- [Shared/Support/ColorHex.swift](../../../Shared/Support/ColorHex.swift)
- [Shared/Support/DateMath.swift](../../../Shared/Support/DateMath.swift)
- [Shared/Support/Formatting.swift](../../../Shared/Support/Formatting.swift)
- [Shared/Support/Helpers.swift](../../../Shared/Support/Helpers.swift)
- [Shared/Support/WidgetDiagnostics.swift](../../../Shared/Support/WidgetDiagnostics.swift)
- [Shared/Support/SignedEntitlements.swift](../../../Shared/Support/SignedEntitlements.swift)

## Relations

- [[Donnees-et-stockage]] : App Group
- [[Localisation]] : formats selon la langue

## Fichiers du module (6)

- [[ColorHex (swift)]]
- [[DateMath (swift)]]
- [[Formatting (swift)]]
- [[Helpers (swift)]]
- [[SignedEntitlements (swift)]]
- [[WidgetDiagnostics (swift)]]

## Dépend de (mesuré dans le code)

- [[Donnees-et-stockage]] : 1 fichier(s)
- [[Localisation]] : 1 fichier(s)
- [[Profil-et-reglages]] : 1 fichier(s)
- Studio (éditeur de widgets) : 1 fichier(s)

Partie de [[Ardane]].

> À mettre à jour quand ce module change (voir `CLAUDE.md` et `scripts/obsidian_map.py`).
