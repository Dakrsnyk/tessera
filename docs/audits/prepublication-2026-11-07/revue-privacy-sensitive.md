# Revue 24.C-P1 privacySensitive

Verdict : à corriger (1 bloquant).

## À corriger avant fusion
- Shared/Render/StyleRendering.swift:537 (évolution premier→dernier), :563 (showsEndValue), :642 et :808 (valeurs des barres), Shared/Render/Tiles/TileView.swift:1256 : montants de graphiques non masqués. Le `.privacySensitive` de TileView n'est posé que sur valueText, légendes, stats, lignes ; ces vues ne sont pas enfants. Oui, showsEndValue est un vrai trou (valeur du dernier point d'une série d'argent, visible écran verrouillé). Correctif : ajouter `var isSensitive = false` en fin de SeriesLineChart / BarsChart, ajouter `.privacySensitive(isSensitive)` sur chacun de ces Text, et passer `isSensitive: tile.isSensitive` dans TileView.series (l.1163-1180) et l.1256. Ou, plus simple, `.privacySensitive(tile.isSensitive)` sur le résultat de `series(...)`.

## Souhaitable
- TileView.swift:277 : légende de l'anneau sans privacySensitive (caption d'un montant). Ajouter `.privacySensitive(tile.isSensitive)`.
- Tests : aucun test ne couvre les graphiques ni le rendu ; testTheMoneyWidgets ne vérifie que le drapeau.

## Vérifié
- check_swift.py : OK. Champs ajoutés en fin de struct avec défaut.
- Rappel de facture : « À payer demain. » présent dans Localizable.xcstrings (l.260478, 9 valeurs). Aucun montant dans NotificationScheduler, Encouragements, InteractiveIntents (grep sans résultat). DailyBrief.swift:548 garde un montant dans l'app, pas une notification.
- isSensitive : catégories finance/business/markets/investing (hors crypto, marketOverview) + moneyDashboard, aiFinance ; nutrition/sport non masqués. Budget de « Ma journée » : ligne seule. Déverrouillé : aucun changement visuel (privacySensitive n'agit que verrouillé).
- Non vérifié : privacySensitive(_:) sur iOS 17 (API iOS 15+, attendue disponible) ; compilation.
