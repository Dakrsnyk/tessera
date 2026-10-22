# Passation — reprise dans une nouvelle conversation (2026-10-22, mise à jour)

À lire en premier, avec `CLAUDE.md` et `docs/memoire/` (Demandes, Chantiers, Decisions, Pieges-connus). Lancer `git status` avant de se fier à cette note.

## État du dépôt
- Les 8 lots de `docs/memoire/Demandes.md` sont écrits, relus, compilés (run 228) et testés (run 229 : 400 tests réussis, 0 échec). Détail, limites et liste « à vérifier sur l'iPhone » : `docs/memoire/Chantiers.md` (section « Exécution autonome des 8 lots »).
- Envoyé sur TestFlight le 2026-10-22 : une version normale (`[testflight]`) puis une version interne (`[interne]`, Premium débloqué, c'est la dernière) : build 230 (normal) puis build 231 (interne, « Internal Only » vérifié, c'est le dernier). Avant : builds 217/218, puis 223 (normal), 224 et 226 (internes).
- L'utilisateur fait tester des amis comme testeurs internes avec la version interne : `docs/guide-premium-testflight.md`. Après chaque série : `[unit]`, puis `[testflight]`, puis `[interne]` (sinon les amis reçoivent une version sans Premium).
- Le dépôt est PUBLIC pour la CI (privé : les runners macOS ne démarrent pas, facturation) : à repasser en privé après la livraison.

## Choix laissés à l'utilisateur
- Skip : « Passer » ne passe plus le repos ; « Annuler » prend la place de « Passer » dans un petit widget à 2 boutons ; barres « n/N séries » comptent les séries faites ; vibration seulement app au premier plan.
- Habitudes : le pourcentage sur 30 jours est gratuit ; seule la section « Régularité » 90 jours / meilleure série reste Premium.
- Calories : calories ACTIVES (≈ 137 kcal pour 60 min à 75 kg, contre 375 avant) ; sans poids du profil, pas de chiffre.
- Scanner : l'étape B (analyse de photo par une IA en ligne) est DÉSACTIVÉE ; à activer seulement après décision (service, coût, serveur, politique de confidentialité).
- Licences : UniTools laissé de côté (CC BY-SA 4.0, DRM de l'App Store) ; BEDCA et ForkRecipe écartés (`docs/licences-nutrition.md`).

## Suite possible
- § 6 « Faire mes repas » (Premium Nutrition), pas dans les 8 lots.
- `docs/memoire/Brief-ameliorations.md` n'existe pas ; le § 11 n'apparaît nulle part : le demander.
- Limites du scanner et de la réactivité listées dans `Chantiers.md`.

## Rappels
- Pas de Mac : tout passe par la CI ; lire le rapport (`git fetch -q origin ci-report`, puis `git archive`).
- Un commit qui ne touche que des `.md` ne lance pas la CI : un commit `[unit]` ou `[testflight]` doit toucher un autre fichier.
- Équipe multi-agents : `CLAUDE.md` et `.claude/agents/` (versionnés depuis le 2026-10-22).
- Le dépôt est public pour la CI : rappeler de le repasser en privé.
- Entreprise et nom de vendeur : `docs/entreprise-et-nom-vendeur.md` (en attente de l'utilisateur).
