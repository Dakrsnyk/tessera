Réalise la phase 2 et la phase 3 de la mission de design des mini-apps d'Ardane, en reprenant là où le travail s'est arrêté, de façon ÉCONOME (le travail précédent a consommé 70 % de la fenêtre d'usage de 5 heures en 7 minutes avec cinq agents en parallèle).

## Où en est le travail (tout est dans le dépôt, commit 26948d5)
- `docs/design/2026-11-17-mini-apps/MISSION.md` : texte complet de la mission (à lire une fois). Conception seulement : aucune ligne de l'app ne change.
- `docs/design/2026-11-17-mini-apps/ESTIMATION.md` : inventaire, livrables, organisation (déjà présentés).
- `docs/design/2026-11-17-mini-apps/audit/` : un audit par sujet, relu. Section 4 de chaque audit = fonctions existantes F1…Fn ; section 9 = ce qui n'existe pas (à étiqueter « Nouveau »).
- `docs/design/2026-11-17-mini-apps/base/` : boîte à outils commune des planches (planches.css, planches.js, gabarits, GUIDE-PLANCHES.md, CATALOGUE.html, render.py) et BRIEF-DESSINATEUR.md (le brief d'une planche de direction, à suivre pour chaque planche). Précédent à égaler : `docs/design/2026-11-16-finance/`.
- Nutrition : `01-nutrition/CONCEPT.md` (5 directions décidées, écran par écran), `nutrition.js`, `00-analyse.html` (rendue). Les 5 planches de direction n'existent pas encore.
- Fitness : `02-fitness/CONCEPT.md` et `fitness.js` (5 directions décidées). Rien de dessiné.
- Habitudes, Planning, Études, Entreprise, Voyage, Auto, Photos : seulement l'audit.
- Captures réelles de la CI : `pub/rapports/design-2026-11-17-mini-apps/captures-ci-454/` (hors dépôt). Rendus : `pub/rapports/design-2026-11-17-mini-apps/<sujet>/`.

## À faire, dans cet ordre
1. Nutrition (pilote) : les 5 planches de direction (01-minimaliste, 02-tableau-de-bord, 03-analytique, 04-quotidienne, 05-hybride), chacune rendue et vérifiée sur l'image ; puis 06-comparaison.html (notes sur 10 pour les 10 critères, avantages, inconvénients, recommandation fondée sur l'usage réel et pas l'hybride par défaut, cohérence avec Mon quotidien, questions, lots d'intégration), le README.md du sujet et son PDF (`docs/design/2026-11-15-cristal/make_pdf.py`).
2. Me montrer Nutrition (2 ou 3 planches-contact en JPG) et attendre mon retour avant le reste.
3. Ensuite, sujet par sujet : Fitness, Habitudes, Planning, Études, Entreprise, Voyage, Auto, Photos (CONCEPT.md et données si absents, analyse, 5 directions, comparaison, README, PDF), puis une planche de cohérence avec Mon quotidien et une synthèse. Me montrer chaque sujet dès qu'il est fini.
4. S'arrêter après l'ensemble pour ma validation. Aucune intégration dans le code.

## Économie d'usage (prioritaire)
- Pas de groupe d'agents en parallèle : faire les planches soi-même, une à la fois ; si un agent est utilisé, un seul à la fois, avec un brief qui nomme les seules sections à lire.
- Lire les gros fichiers une fois, et seulement les parties utiles (la section de la direction dans CONCEPT.md, le guide, le gabarit).
- Pour vérifier un rendu : la planche-contact et seulement les écrans qui posent problème.
- Si la fenêtre d'usage approche de sa limite : s'arrêter proprement, commiter ce qui est fini et me dire où on en est.

## Règles du dépôt
- D'autres sessions écrivent dans le même dossier : commiter seulement ses fichiers avec `git commit --only <chemins>` ; ne jamais toucher scripts/ad2, scripts/ad3, docs/memoire/campagne-2026, Tests/Fixtures/Entreprise, docs/lancement/listes-entreprise.md, docs/design/2026-11-14-refonte/Inter-opsz.woff2 ; jamais git stash, reset ni changement de branche.
- Les fichiers .html lancent la CI : mettre [skip ci] dans le message des commits de design. Pousser soi-même.
- À la fin : mettre à jour docs/memoire/Demandes.md (demande « Refonte UX/UI des mini-apps ») et docs/memoire/Chantiers.md.
