---
tags: [ardane, module, zone/outils]
---

# Localisation

Zone : **Qualité et outillage** · Cartes : [[Vue-Globale.canvas|Vue globale]] · [[Architecture.canvas|Architecture]] · [[Fonctionnalites.canvas|Fonctionnalités]]

Le code est écrit en français ; `tr("texte")` cherche ce texte comme clé dans le catalogue. Langues : fr (source), en, es, de, it, pt-BR, ja.

## Ce qui existe (vérifié dans le code)

- Catalogue `Shared/Localizable.xcstrings`, textes d'Info.plist `App/InfoPlist.xcstrings`.
- Traductions en lots dans `l10n/`, glossaire, scripts `l10n_*`.

## Fichiers sources

- [Shared/Support/Localization.swift](../../../Shared/Support/Localization.swift)
- [Shared/Support/Formatting.swift](../../../Shared/Support/Formatting.swift)
- [Shared/Localizable.xcstrings](../../../Shared/Localizable.xcstrings)
- [App/InfoPlist.xcstrings](../../../App/InfoPlist.xcstrings)
- [l10n/GLOSSARY.md](../../../l10n/GLOSSARY.md)
- [scripts/l10n_catalog.py](../../../scripts/l10n_catalog.py)
- [scripts/l10n_scan.py](../../../scripts/l10n_scan.py)

## Relations

- [[Tests-CI-et-outils]] : vérifié par la CI (l10n sync)

## Fichiers du module (1)

- [[Localization (swift)]]

Partie de [[Ardane]].

> À mettre à jour quand ce module change (voir `CLAUDE.md` et `scripts/obsidian_map.py`).
