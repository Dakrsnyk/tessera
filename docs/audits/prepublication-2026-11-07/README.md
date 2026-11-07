# Audit intégral prépublication d'Ardane (chantier 24, demandé le 2026-11-07)

Un fichier par domaine, écrit par l'agent qui l'a audité, puis vérifié par le Chef :

| Fichier | Domaine | Agent |
|---|---|---|
| (hors dépôt) | Secrets, réseau, Keychain, ATS, entitlements, CI, signature : le rapport détaillé décrit des scénarios d'attaque et l'emplacement des clés de signature, il reste donc sur le PC de l'utilisateur (`~/ardane-tools/audits-prives/securite-2026-11-07.md`), jamais dans ce dépôt public | security-reviewer |
| `confidentialite-conformite.md` | Données réelles vs politique, App Privacy, permissions, lois, règles Apple, checklist App Store Connect | research-architect |
| `nutrition.md` | Nutrition et scanner | code-reviewer |
| `fitness-habitudes-planning-accueil.md` | Fitness, Habitudes, Productivité, Planning · études, Mon Quotidien | code-reviewer |
| `finances-et-autres.md` | Budget, Placements, Entreprise, Sociétés cotées, Auto, Voyage, Ma vie, Apple Pay | code-reviewer |
| `widgets-studio-donnees.md` | Widgets, Studio, Store, Mes widgets, stockage, notifications | code-reviewer |
| `premium-onboarding-reglages.md` | Premium/StoreKit, onboarding, Profil, réglages, permissions | code-reviewer |
| `interface-accessibilite.md` | UX/UI et accessibilité | ui-ux-designer |
| `performance-release.md` | Performance et build Release | ios-developer |
| `tests.md` | Inventaire et plan de tests | qa-tester |
| `RAPPORT-FINAL.md` | Synthèse, corrections, résultats des tests, restes, checklist | Chef |

Règle : un constat n'existe que s'il est prouvé par `fichier:ligne` (ou par un résultat de la CI). « Aucun défaut trouvé » ne veut pas dire « aucun défaut ».
