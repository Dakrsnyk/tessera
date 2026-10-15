# Ardane — notes pour Claude Code

Ardane (anciennement Tessera : le projet Xcode, les cibles, le module, l'App Group, les produits in-app, le schéma d'URL et le dossier de données gardent « Tessera » ; l'identifiant de l'app est `com.dakrsnyk.ardane` depuis le 2026-10-12). App iOS (SwiftUI, iOS 17, Swift 5) de widgets/mini-apps. Actif de revenu passif visé (50–100 $/jour). Répondre en français.

## Architecture
- `App/` (app), `Shared/` (compilé dans l'app ET l'extension widget), `UITests/`, `scripts/`, `l10n/`.
- Xcode: PBXFileSystemSynchronizedRootGroup → un nouveau fichier rejoint automatiquement les cibles.
- AppModel @Observable @MainActor ; données dans l'App Group `group.com.dakrsnyk.tessera` via SharedStore.
- Pas de Mac : tout se vérifie par la CI GitHub Actions (Dakrsnyk/tessera).

## CI (pilotée par tags dans le message de commit)
`[check]` compile seul (à privilégier ; tokens et temps minimum : ne relire que les 1 à 3 captures liées au changement, en petit) · `[unit]` · `[daily]` (tests logiques + MiniApp/Studio/Profile UITests + captures) · `[studio]` `[apps]` `[demos]` `[shots]` `[langs]` (captures des écrans clés dans les 6 langues, sans tests) `[store]` (tests logiques + captures du Store et des styles) `[stack]` `[marketing]` `[place]` ; workflow_dispatch = tout.
- `[testflight]` : version Release signée avec le compte Apple Developer et envoyée sur TestFlight (pas de simulateur, pas de tests, pas d'IPA de test). Configuration unique et secrets : `scripts/signing/README.md`. Signature manuelle en Release seulement (profils « Ardane App Store » et « Ardane Widgets App Store ») ; Debug reste non signé pour l'IPA de test.
- IPA (Releases « Version de test ») : seulement sans tag, ou avec `[unit]`, `[daily]`, `[apps]`, `[studio]`, `[store]`, `[demos]`, `[shots]`, `[langs]` (tests sans échec). `[check]`, `[marketing]` et `[place]` n'en publient pas. Depuis le 2026-10-15, l'utilisateur installe par TestFlight : finir chaque série de changements par un `[unit]` (tests logiques) puis un commit `[testflight]` (la version arrive seule sur son iPhone, distribution automatique).
- Suivi : `scratchpad/colorcheck/ci.sh` (si absent : `gh api repos/Dakrsnyk/tessera/actions/runs`).
- Rapport : `git fetch -q origin ci-report && mkdir -p /tmp/rNNN && git archive origin/ci-report | tar -x -C /tmp/rNNN` ; échecs : grep "Test Case .*failed" et "error:" dans report.txt. L'étape de tests finit par `|| true` : le job est vert même si des tests échouent.
- Avant chaque commit : `python3 scripts/check_swift.py` (ordre des labels d'init, catalogue de kinds, sécurité Release).

## Règles impératives
- Le déverrouillage premium DEBUG ne doit JAMAIS être actif en Release (check_swift.py le vérifie).
- Ne pas casser l'existant. Pas d'image_search. Livrer des PNG/GIF (l'utilisateur ne peut pas ouvrir les artifacts Design).
- Compte Apple Developer acheté le 2026-10-15 : installer par TestFlight (`[testflight]`) ; le sideload de l'IPA de test reste possible mais limite widgets écran verrouillé / Live Activities.
- Le dépôt est public pour la CI : rappeler de le repasser en privé.
- Commits terminés par :
  `Co-Authored-By: Claude <noreply@anthropic.com>`
  `Claude-Session: https://claude.ai/code/session_011SGgP6YLhofhVhTasQukEx`

## Carte du projet (graphify, remplace Obsidian depuis le 2026-10-12)
- `python3 scripts/graph_map.py` : met à jour le graphe de code avec graphify (en local, sans API ; `pip install graphifyy`, ici dans `~/ardane-tools/graphify-venv`) puis écrit la carte dans `graphify-out/` (non versionné) : `index.html` (visionneuse `scripts/graph/viewer.html`), `graph-data.js` et `.json`. Un nœud par fichier, notes de `docs/memoire/` et services externes compris, 8 catégories.
- Mise à jour à chaque tâche : le hook git post-commit relance le script (installer avec `python3 scripts/graph_map.py --install-hook` sur un nouveau clone ; sans hook, lancer le script en fin de tâche). Servie par le serveur « graphe » (`.claude/launch.json`), la page se recharge seule.
- Quand un module, un écran, une donnée, un service ou une relation change : mettre à jour `MODULES`, `FALLBACK` ou `EXTERNAL` dans `scripts/graph_map.py` (rôle et fonctionnalités affichés au clic).
- Version téléphone (instantané, privé) : https://claude.ai/artifact/FQBb8SpokSP57Hu12asBmV. Après un changement d'architecture : `python3 scripts/graph_map.py --artifact`, puis republier `graphify-out/artifact/carte-ardane.html` sur cette URL.

## Mémoire (docs/memoire/, lue aussi par l'utilisateur)
- Début de tâche : lire `Demandes.md` (demandes écrites par l'utilisateur), `Chantiers.md`, et selon le sujet `Decisions.md`, `Pieges-connus.md`, le module concerné dans `MODULES` de `scripts/graph_map.py`.
- Fin de tâche : cocher les demandes faites (avec la date), mettre à jour `Chantiers.md`, ajouter une décision ou un piège nouveau en une ligne. Ce qui doit survivre à la session va dans le dépôt, pas dans le scratchpad.

## Localisation (voir HANDOFF.md pour l'état)
- Code en français ; `tr("texte français")` cherche le texte comme clé dans `Shared/Localizable.xcstrings`. Interpolations → `%@` (`%1$@` pour réordonner), `%` littéral → `%%`.
- Langues cibles : en, es, de, it, pt-BR, ja (+ fr source). Chinois et coréen retirés le 2026-10-08 (traductions de mauvaise qualité ; récupérables dans l'historique git). Glossaire : `l10n/GLOSSARY.md`.
- Dates/nombres : `Fmt.locale`. Pluriels : `Fmt.plural`.
- Mot français à plusieurs sens : `tr("Taille", context: "height")` → clé `"Taille [height]"` (le français affiche « Taille »). Singulier identique au pluriel (cours, repas, mois) : `Fmt.plural(n, tr("cours", context: "one"), tr("cours"))`.
- Scripts : `scripts/l10n_scan.py`, `l10n_rewrite.py`, `l10n_catalog.py extract|merge|build|check|sync`, `l10n_chunk_check.py NN`. Nouveau texte : extract → traduire dans `l10n/parts/NN.<langue>.json` → merge → build → sync (le rapport CI affiche `l10n sync`).
- Les UITests sont forcés en français (`-AppleLanguages (fr) -AppleLocale fr_CA`).
