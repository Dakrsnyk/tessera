---
tags: [ardane, module, outils]
---

# Tests, CI et outils

Zone : **Qualité et outillage** · Cartes : [[Vue-Globale.canvas|Vue globale]] · [[Architecture.canvas|Architecture]] · [[Fonctionnalites.canvas|Fonctionnalités]]

Pas de Mac : tout se compile et se teste sur GitHub Actions, piloté par des tags dans le message de commit. Outils DEBUG de captures.

## Ce qui existe (vérifié dans le code)

- Cibles : Tessera (app), TesseraWidgets (extension), TesseraTests (21 fichiers), TesseraUITests (7 fichiers).
- Workflow `.github/workflows/build.yml` : `[check]`, `[unit]`, `[daily]`, `[studio]`, `[apps]`, `[shots]`, `[langs]`, `[store]`, `[marketing]`, `[video]`, `[adkit]`…
- `scripts/check_swift.py` : ordre des labels d'init, catalogue de kinds, sécurité Release, manifeste de confidentialité.
- Outils DEBUG : `ScreenshotMode` (-screenshotScreen), `MarketingShots`, `StudioGallery`, `DemoGallery`, `AdExport` ; pubs dans `scripts/ads/`.

## Fichiers sources

- [.github/workflows/build.yml](../../../.github/workflows/build.yml)
- [scripts/check_swift.py](../../../scripts/check_swift.py)
- [scripts/ci_report.sh](../../../scripts/ci_report.sh)
- [App/Core/ScreenshotMode.swift](../../../App/Core/ScreenshotMode.swift)
- [App/Core/MarketingShots.swift](../../../App/Core/MarketingShots.swift)
- [App/Core/StudioGallery.swift](../../../App/Core/StudioGallery.swift)
- [App/Core/DemoGallery.swift](../../../App/Core/DemoGallery.swift)
- [App/Core/AdExport.swift](../../../App/Core/AdExport.swift)
- [Tessera.xcodeproj/project.pbxproj](../../../Tessera.xcodeproj/project.pbxproj)
- [HANDOFF.md](../../../HANDOFF.md)

## Relations

- [[Localisation]]
- [[Premium-et-abonnements]] : sécurité Release du déverrouillage DEBUG

> À mettre à jour quand ce module change (voir `CLAUDE.md` et `scripts/obsidian_map.py`).
