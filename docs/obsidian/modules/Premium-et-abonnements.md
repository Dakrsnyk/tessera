---
tags: [ardane, module, zone/metier]
---

# Premium et abonnements

Zone : **Logique métier et état** · Cartes : [[Vue-Globale.canvas|Vue globale]] · [[Architecture.canvas|Architecture]] · [[Fonctionnalites.canvas|Fonctionnalités]]

Achats StoreKit 2 : l'App Store fait foi, le résultat est mis en cache pour l'extension. Le paywall s'ouvre sur ce que la personne a touché.

## Ce qui existe (vérifié dans le code)

- Produits (`Config/Tessera.storekit`) : `com.dakrsnyk.tessera.premium.lifetime` (achat unique), `.monthly` et `.yearly` (abonnements).
- Paywall contextuel (`PaywallContext`) : widget, limite de widgets ou d'habitudes, historique, écran d'accueil, pack.
- Limites gratuites (8 widgets, 5 habitudes), accents gratuits (`Palette`), cadenas Premium (`PremiumLock`).
- Builds DEBUG : déverrouillage de test (`DebugPremium`), jamais en Release (vérifié par `scripts/check_swift.py` et la CI).

## Fichiers sources

- [App/Premium/PremiumStore.swift](../../../App/Premium/PremiumStore.swift)
- [App/Premium/PaywallView.swift](../../../App/Premium/PaywallView.swift)
- [App/Premium/PaywallContext.swift](../../../App/Premium/PaywallContext.swift)
- [App/Premium/PremiumLock.swift](../../../App/Premium/PremiumLock.swift)
- [App/Premium/PremiumConfiguration.swift](../../../App/Premium/PremiumConfiguration.swift)
- [Shared/Theme/Palette.swift](../../../Shared/Theme/Palette.swift)
- [Shared/Support/DebugPremium.swift](../../../Shared/Support/DebugPremium.swift)
- [Config/Tessera.storekit](../../../Config/Tessera.storekit)

## Relations

- [[Services-externes]] : StoreKit / App Store
- [[Noyau-AppModel]] : état Premium, limites
- [[Store]] : packs Premium
- [[Studio-editeur]] : styles Premium

## Fichiers du module (7)

- [[PaywallContext (swift)]]
- [[PaywallView (swift)]]
- [[PremiumConfiguration (swift)]]
- [[PremiumLock (swift)]]
- [[PremiumStore (swift)]]
- [[DebugPremium (swift)]]
- [[Palette (swift)]]

Partie de [[Ardane]].

> À mettre à jour quand ce module change (voir `CLAUDE.md` et `scripts/obsidian_map.py`).
