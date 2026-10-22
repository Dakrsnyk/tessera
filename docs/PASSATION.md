# Passation — reprise dans une nouvelle conversation (2026-10-22)

À lire en premier, avec `CLAUDE.md` et `docs/memoire/` (Demandes, Chantiers, Decisions, Pieges-connus).

## État du dépôt
- Branche à jour, arbre propre. Dernier code envoyé : build 217 (TestFlight normal) et build 218 (interne, Premium débloqué, « Internal Only » vérifié), commit `43faf16`.
- 331 tests logiques réussis (run 216). Tout ce qui est coché dans `docs/memoire/Demandes.md` jusqu'au 2026-10-17 est livré.
- L'utilisateur fait tester des amis comme testeurs internes avec la version interne : `docs/guide-premium-testflight.md`, dernière section. Après chaque série : `[unit]`, puis `[testflight]`, puis `[interne]` (sinon les amis reçoivent une version sans Premium).

## Travail en cours : NON commencé (l'agent s'est arrêté sur la limite d'usage, aucun fichier modifié)
Demande de l'utilisateur « Ardane — Corriger les actions interactives Fitness et Nutrition » :

1. **Fitness, vrai « Skip » de série.** Aujourd'hui « Passer » (`SkipRestIntent` → `FitnessState.skipRest`) ne passe que le repos. Attendu : après 2/4 faite, Skip sur 3/4 → 4/4 ; la série 3 est « ignorée » (rien dans `sets`, pas de charge/répétitions), distincte de faite et restante (nouveau champ dans `WorkoutSession`, décodage tolérant). Dernière série de l'exercice → exercice suivant (logique de `completeSet`) ; dernière de la séance → fin (une séance sans aucune série faite n'entre pas dans l'historique). « Série faite », « Skip », « Annuler » (`undoLastSet`, doit pouvoir défaire un skip) et « Terminer » restent cohérents. Partout : Live Activity (`Shared/Live/WorkoutLiveActivity.swift`), Dynamic Island (`Widgets/WorkoutLiveActivityWidget.swift`), widgets (`Shared/Render/Tiles/FitnessTiles.swift`, `Tile.swift`, `TileView.swift`, `DashboardTiles.swift`), app (`App/Screens/MiniApps/Fitness/FitnessSession.swift`). Nouvel intent `SkipSetIntent` dans `Shared/Intents/SpaceIntents.swift` via `changeWorkout`.
2. **Doubles appuis.** Passer la position attendue (exercice, série) en `@Parameter` des intents de série ; ignorer l'action si la séance n'est plus à cette position. Garder `init()` sans position pour la compatibilité. Source de vérité : `SharedStore.update` (vérifier l'atomicité).
3. **Retour haptique.** Ne rien prétendre d'impossible : un bouton de widget ou de Live Activity ne peut en général pas faire vibrer l'iPhone (vue rendue en instantané ; générateurs UIKit inactifs hors premier plan). Faire vibrer (légère, une seule fois) seulement quand l'action est acceptée et que l'app est au premier plan, et pour les boutons dans l'app (Fitness et Nutrition, helper `Haptics`). Le code `Shared/` est aussi compilé dans l'extension : passer par un crochet fixé par l'app. Le dire clairement à l'utilisateur.
4. **Nutrition.** `LogFoodIntent` (ajout rapide du widget) : pas de doublon sur double appui (ex. même aliment ignoré dans les 2 s).
5. **Tests obligatoires** (`Tests/WorkoutSkipTests.swift`) : 2/4 puis skip 3/4 → 4/4 sans série comptée ; skip de la dernière série ; appuis rapides (position périmée ignorée) ; chemin des intents (widget et notification) ; doublon Nutrition ; logique « vibrer seulement si accepté ». La vibration se vérifie sur l'iPhone.
6. Fin : l10n (extract → `l10n/parts/31.<langue>.json` → merge, build, check, sync), mémoire, `scripts/graph_map.py`, puis `[check]` → `[unit]` → `[testflight]` → `[interne]`. Rapport final : fichiers modifiés, tests, résultats, limites iOS restantes.

## Rappels
- Pas de Mac : tout passe par la CI ; lire le rapport (`git fetch -q origin ci-report`, puis `git archive`).
- Un commit qui ne touche que des `.md` ne lance pas la CI.
- Le dépôt est public pour la CI : rappeler de le repasser en privé.
- Entreprise et nom de vendeur : `docs/entreprise-et-nom-vendeur.md` (en attente de l'utilisateur).
