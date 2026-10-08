# Tessera — notes pour Claude Code

App iOS (SwiftUI, iOS 17, Swift 5) de widgets/mini-apps. Actif de revenu passif visé (50–100 $/jour). Répondre en français.

## Architecture
- `App/` (app), `Shared/` (compilé dans l'app ET l'extension widget), `UITests/`, `scripts/`, `l10n/`.
- Xcode: PBXFileSystemSynchronizedRootGroup → un nouveau fichier rejoint automatiquement les cibles.
- AppModel @Observable @MainActor ; données dans l'App Group `group.com.dakrsnyk.tessera` via SharedStore.
- Pas de Mac : tout se vérifie par la CI GitHub Actions (Dakrsnyk/tessera).

## CI (pilotée par tags dans le message de commit)
`[check]` compile seul · `[unit]` · `[daily]` (tests logiques + MiniApp/Studio/Profile UITests + captures) · `[studio]` `[apps]` `[demos]` `[shots]` `[langs]` (captures des écrans clés dans les 6 langues, sans tests) `[stack]` `[marketing]` `[place]` ; workflow_dispatch = tout.
- Suivi : `scratchpad/colorcheck/ci.sh` (si absent : `gh api repos/Dakrsnyk/tessera/actions/runs`).
- Rapport : `git fetch -q origin ci-report && mkdir -p /tmp/rNNN && git archive origin/ci-report | tar -x -C /tmp/rNNN` ; échecs : grep "Test Case .*failed" et "error:" dans report.txt. L'étape de tests finit par `|| true` : le job est vert même si des tests échouent.
- Avant chaque commit : `python3 scripts/check_swift.py` (ordre des labels d'init, catalogue de kinds, sécurité Release).

## Règles impératives
- Le déverrouillage premium DEBUG ne doit JAMAIS être actif en Release (check_swift.py le vérifie).
- Ne pas casser l'existant. Pas d'image_search. Livrer des PNG/GIF (l'utilisateur ne peut pas ouvrir les artifacts Design).
- Utilisateur sans compte Apple Developer : widgets écran verrouillé / Live Activities peuvent ne pas marcher en sideload.
- Le dépôt est public pour la CI : rappeler de le repasser en privé.
- Commits terminés par :
  `Co-Authored-By: Claude <noreply@anthropic.com>`
  `Claude-Session: https://claude.ai/code/session_011SGgP6YLhofhVhTasQukEx`

## Localisation (voir HANDOFF.md pour l'état)
- Code en français ; `tr("texte français")` cherche le texte comme clé dans `Shared/Localizable.xcstrings`. Interpolations → `%@` (`%1$@` pour réordonner), `%` littéral → `%%`.
- Langues cibles : en, es, de, it, pt-BR, ja (+ fr source). Chinois et coréen retirés le 2026-10-08 (traductions de mauvaise qualité ; récupérables dans l'historique git). Glossaire : `l10n/GLOSSARY.md`.
- Dates/nombres : `Fmt.locale`. Pluriels : `Fmt.plural`.
- Scripts : `scripts/l10n_scan.py`, `l10n_rewrite.py`, `l10n_catalog.py extract|merge|build|check|sync`, `l10n_chunk_check.py NN`. Nouveau texte : extract → traduire dans `l10n/parts/NN.<langue>.json` → merge → build → sync (le rapport CI affiche `l10n sync`).
- Les UITests sont forcés en français (`-AppleLanguages (fr) -AppleLocale fr_CA`).
