# Revue indépendante : vague interface (U) et sécurité (S) du Chef

Lecture seule ; rien n'a été compilé. `python3 scripts/check_swift.py` : OK (rien ne prouve la compilation, seule la CI le fait).

## Verdict
Aucune erreur de compilation probable, aucun bug bloquant trouvé. 0 remarque « À corriger avant fusion ». Remarques « Souhaitable » ci-dessous.

## Vérifié sans problème
- `AccessibilityHelpers.swift` : `contentShape(Rectangle().inset(by: -x))` (InsetShape est un Shape), `confirmationDialog(_:isPresented:titleVisibility:presenting:actions:message:)` avec titre String, `CheckCircleButton` (labels et types des appels : Planning, Productivité, Étudiant), modificateurs sur `Chart` / `ProgressView`.
- `forgetIfFreshInstall` : `hasSavedData` teste l'existence des fichiers (visibles avant le premier déverrouillage), donc une mise à jour n'efface jamais la clé ; une installation neuve (aucun fichier) l'efface ; l'indicateur est posé dans les deux cas. `CaseIterable` sur un enum à rawValue : valide.
- `check_release_safety` : `#if DEBUG` / `#if !DEBUG` / `#else` / `#elseif` / `||` bien gérés ; les cas douteux donnent des faux positifs, jamais des passages à tort.
- `resourceValues(forKeys: [.fileSizeKey]).fileSize` : correct.
- Cases à cocher : même action qu'avant.

## Souhaitable
1. Textes non présents dans `Shared/Localizable.xcstrings` (affichés en français dans les 5 autres langues) : « Diminuer : %@ », « Augmenter : %@ », « Supprimer cet objectif ? », « Supprimer ce compte ? », « Icône %@ », « Supprimer toute la série ? », « Supprimer ce cours ? », « Supprimer cette séance du programme ? », « Supprimer cette occurrence ? », « Supprimer uniquement cette occurrence », « Supprimer cet événement ? », « Supprimer l'objectif », « Supprimer le compte » (+ « Supprimer le cours », messages associés). Correctif : `l10n_catalog.py extract`, traduire, merge, build, sync.
2. `App/Screens/MiniApps/Studies/StudiesPages.swift` (dialogues `deletingSeries` et `deletingCourses`) : l'action lit l'état lié au `isPresented` ; si SwiftUI réinitialise le binding avant l'action, rien n'est supprimé. Correctif : utiliser `confirmDelete` (qui passe la valeur via `presenting:`), ou copier l'identifiant à la présentation.
3. `App/Screens/Home/DailySection.swift` (~1235 et ~1262) : `tapAreaOutset(8)` sur deux boutons voisins séparés par `spacing: 8` : les zones se recouvrent dans l'écart (le dernier gagne) ; aucun bouton n'est masqué, mais l'écart est partagé. Correctif : `tapAreaOutset(4)` pour ces deux boutons.
4. `App/Services/StripeSync.swift:15` : une clé existante garde l'ancien niveau d'accès (AfterFirstUnlock) jusqu'à la reconnexion. Correctif : au lancement, si `read` réussit, `save` la même valeur (une fois).
5. `Shared/Theme/Theme.swift` : la plupart des secondes couleurs bougent de peu, mais Carte (7D828C→656A73), Dune (7A6043→5D4933) et Glacier (4A6A88→3A536B) s'assombrissent nettement ; à regarder sur les captures des thèmes.
