# État de la localisation (mis à jour le 2026-10-08)

Langues : français (source) + en, es, de, it, pt-BR, ja. Le chinois (zh-Hans) et le coréen (ko) ont été retirés à la demande de l'utilisateur (traductions de mauvaise qualité ; récupérables dans l'historique git, avant le commit 5ee621c).

## Fait
- Lots 01–20 complets dans `l10n/parts/NN.<langue>.json` (`l10n_chunk_check.py NN` OK pour chacun).
- Japonais des lots 13, 15, 17 et 18 retraduit depuis le français (il était resté en anglais ou mélangé).
- Clés ré-extraites : 4873 clés, rattachement des clés tronquées (« mê)me »…).
- Pluriels construits avec `"s"` remplacés par `Fmt.plural` ; « de plus / de moins » en deux phrases.
- Mots à double sens séparés avec `tr("mot", context: "x")` → clé `"mot [x]"` (Note, Notes, Moyennes, Taille, Retour, ans, Barre, Cartes, Actif ; singulier de cours, repas, mois).
- Catalogues : `l10n_catalog.py merge` → `build` → `Shared/Localizable.xcstrings` (app + extension) et `App/InfoPlist.xcstrings` (nom affiché, autorisations). `check` et `sync` : 0 manquante.
- CI : `l10n_catalog.py sync` affiché dans le rapport ; tag `[langs]` = captures des écrans clés en en/de/ja/es/it/pt-BR (fichiers `<langue>-<écran>-light.jpg` dans ci-report).
- `[daily]` du 2026-10-08 (run 108) : compile, 173 tests OK, 1 échec `ProfileUITests.testAPackOpensInTheStudio` (« Le widget 2 ne s'ouvre pas » : le toucher sur la puce du Studio n'a pas sélectionné le widget ; passait aux 3 runs précédents, probablement instable, non lié aux textes — l'app est en français pendant les tests).

## Reste à faire
1. Relire les captures `[langs]` : textes coupés (allemand), police japonaise ; raccourcir les traductions trop longues dans `l10n/parts`, puis merge/build.
2. Décider pour le test instable ci-dessus (relancer `[daily]` ou ajouter un second essai comme dans e940e31).
3. Relecture des traductions par des locuteurs natifs si possible (surtout ja).

## Ensuite
Compte Apple Developer, TestFlight signé via GitHub Actions, fiche App Store + politique de confidentialité (PRIVACY.md existe), marketing. Repasser le dépôt en privé.
