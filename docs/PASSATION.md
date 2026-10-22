# Passation — reprise dans une nouvelle conversation (2026-10-22, mise à jour)

À lire en premier, avec `CLAUDE.md` et `docs/memoire/` (Demandes, Chantiers, Decisions, Pieges-connus). Lancer `git status` avant de se fier à cette note.

## État du dépôt
- Dernier code envoyé : commit `e586c47` (run 226, build 226 interne). Derniers builds sur TestFlight avant cette série : 217 (normal) et 218 (interne, Premium débloqué).
- Chantier Skip (série passée, doubles appuis, haptique, ajout rapide Nutrition) : terminé, relu par `code-reviewer`, run 220 (`[unit]`) : 350 tests réussis, 0 échec.
- Accueil, maquette D choisie le 2026-10-22 : codé et compilé (run 221) ; ses tests (`DailyBriefTests`) passent par le prochain `[unit]`. Détail et écarts avec la maquette : `docs/memoire/Chantiers.md` (section du 2026-10-22).
- Build 223 (normal) envoyé sur TestFlight le 2026-10-22 avec Skip et l'accueil D (run 222 : 352 tests réussis). Puis, à la demande de l'utilisateur, versions internes (Premium débloqué) : build 224, puis build 226 avec le dégradé de l'accueil corrigé (c'est le dernier ; « Internal Only » vérifié). Le `[testflight]` normal de cette série est le 223 (ancien dégradé) : n'en renvoyer un que pour une vraie livraison, il remplacerait l'interne.
- L'utilisateur fait tester des amis comme testeurs internes avec la version interne : `docs/guide-premium-testflight.md`, dernière section. Après chaque série : `[unit]`, puis `[testflight]`, puis `[interne]` (sinon les amis reçoivent une version sans Premium).

## Choix laissés à l'utilisateur (Skip)
- « Passer » ne passe plus le repos (écran verrouillé, Dynamic Island, widgets) : il passe la série. `SkipRestIntent` n'est plus câblé ; « Passer le repos » n'existe que dans l'app.
- Dans un petit widget à 2 boutons, la flèche « Annuler » prend la place de « Passer » une fois une série faite (l'ordre est « Série faite », « Annuler », « Passer »).
- Les barres « n/N séries » comptent les séries faites seulement : avec des séries passées, elles n'atteignent pas 100 %.
- Vibration : seulement app au premier plan (limite d'iOS, pas un défaut du code). À vérifier sur l'iPhone.

## Prochaine demande : améliorations (`docs/memoire/Demandes.md`, « À faire »)
- **Accueil : fait** (maquette D, mixte A + C, choisie par l'utilisateur). Maquettes dans `pub/maquettes-accueil/` (non versionné ; source `maquettes.html`, rendu `node render.js` avec le Chromium de `~/ardane-tools/render`).
- `docs/memoire/Brief-ameliorations.md` (cité par Demandes pour les § 1 à 12) n'existe pas ; le § 11 n'apparaît nulle part. Le demander à l'utilisateur avant les lots autres que l'accueil.
- Découpage proposé en lots (aucun n'est lancé sans l'accord de l'utilisateur) : 0 Skip (fait) · 1 Accueil (fait ; reste Productivité, § 12) · 2 Habitudes · 3 Planning · 4 Mini-apps harmonisées · 5 Store (fonds d'écran) · 6 Nutrition (sources de données) · 7 « Faire mes repas » · 8 Fitness (calories) · 9 Permissions · 10 Réactivité. Les lots 2, 3, 5 et 9 sont indépendants ; 6, 7 et 8 touchent `Nutrition.swift` et `Fitness.swift` : en séquence ; 4 et 10 en dernier.
- Images de référence : `docs/references/` (non versionnées, voir son `README.md`).

## Rappels
- Pas de Mac : tout passe par la CI ; lire le rapport (`git fetch -q origin ci-report`, puis `git archive`).
- Un commit qui ne touche que des `.md` ne lance pas la CI : un commit `[unit]` ou `[testflight]` doit toucher un autre fichier.
- Équipe multi-agents : `CLAUDE.md` et `.claude/agents/` (versionnés depuis le 2026-10-22).
- Le dépôt est public pour la CI : rappeler de le repasser en privé.
- Entreprise et nom de vendeur : `docs/entreprise-et-nom-vendeur.md` (en attente de l'utilisateur).
