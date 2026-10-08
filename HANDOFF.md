# État au passage à Claude Code

Dernier commit poussé : 9d3e577 (localisation : réécriture `tr()`, tests en français, 9 langues déclarées). Résultat CI de ce commit pas encore lu.

## Reste à faire (localisation)
1. Lire la CI de 9d3e577 (doit compiler ; tests en fr).
2. Traductions : lots 11, 13, 15, 17, 18 incomplets (ko manquant au moins) → compléter dans `l10n/parts/NN.<lang>.json`, vérifier avec `python3 scripts/l10n_chunk_check.py NN`. Lots 01–10, 12, 14, 16 OK mais à revérifier après ré-extraction.
3. Ré-extraire : `python3 scripts/l10n_catalog.py extract` (clés ~10 « mangées » ex. "sér)ies", "mê)me" → rattacher à la version propre).
4. Pluriels à suffixe « s » à corriger dans le code avec `Fmt.plural` : "%@ séance%@ cette semaine", "%@ tâche%@ aujourd'hui", "%@ devoir%@ à rendre", "Série de %@ jour%@", "%@ mois gratuit%@" (PremiumStore), "%@ séance%@", "%@ jour%@ noté%@", "%@ jour%@ sur %@ à moins de 10 %% de ton objectif", "%@ · %@ jour%@ sur %@ dans l'objectif", "%@ faite%@ aujourd'hui", "%@ tâche%@ à faire", "%@ de %@ que le mois dernier…".
5. Clés ambiguës (un mot FR, deux sens) à séparer : Note, Moyennes, Taille, Retour, ans, cours, repas, Barre, Terminal, Notes, Cartes, Actif, Référence, widgets "Next set"/"Focus".
6. Fusionner `l10n/parts/NN.<lang>.json` → `l10n/<lang>.json`, puis `python3 scripts/l10n_catalog.py build` → `Shared/Localizable.xcstrings` + `App/InfoPlist.xcstrings` (brancher InfoPlist ; les INFOPLIST_KEY_* français du pbxproj restent en repli). `l10n_catalog.py check`.
7. Vérifier : `[daily]`, puis captures par langue (`SHOT_LANG`/`SHOT_LOCALE` : en, de, ja…) pour troncatures (allemand long, police ja). Ajouter un test clés↔catalogue, mettre à jour le README.

## Ensuite
Compte Apple Developer, TestFlight signé via GitHub Actions, fiche App Store + politique de confidentialité (PRIVACY.md existe), marketing. Repasser le dépôt en privé.
