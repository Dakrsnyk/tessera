---
tags: [ardane, memoire]
---

# Décisions

Les choix déjà faits, avec leur date. Retour : [[Memoire]]

## Produit
- 2026-10-08 : iPad et Apple Watch abandonnés. Chinois et coréen retirés (traductions de mauvaise qualité, récupérables avant 5ee621c) ; langues : fr, en, es, de, it, pt-BR, ja.
- 2026-10-09 : photo du repas retirée de [[Nutrition]] (récupérable avant 54d2373) ; le scan de code-barres garde son carré de visée.
- 2026-10-11 : l'app s'appelle Ardane. Projet, cibles, module, identifiants, App Group et dossier de données gardent « Tessera » (rien n'est perdu).
- Le déverrouillage premium DEBUG n'est jamais actif en Release ([[Premium-et-abonnements]], vérifié par `scripts/check_swift.py`).

## Publicité
- Une seule publicité exceptionnelle plutôt que plusieurs ordinaires ; seulement des fonctionnalités qui existent vraiment, montrées avec de vrais éléments de l'app.
- Direction retenue : [[Concept-THE-OPENING]] (la fente du « A » d'Ardane comme lumière et comme transition).
- Les enregistrements vidéo du simulateur ne tournent qu'à 8–14 i/s : le mouvement est reconstruit à 60 i/s à partir d'images fixes réelles.
- Voix : Kokoro-82M (licence Apache-2.0). Musique : Mixkit (licence gratuite, publicité en ligne permise). Runway n'est pas utilisé : la version gratuite (125 crédits une seule fois) met un filigrane.

## Outillage
- La CI est pilotée par des tags dans le message de commit (voir `CLAUDE.md`) ; `[check]` d'abord, finir une série par `[unit]` pour avoir une version à installer.
- Carte Obsidian générée depuis le code par `scripts/obsidian_map.py` : chaque module est une étoile de ses fichiers ; seules les 3 plus fortes dépendances entre modules sont des liens (sinon le graphe devient une boule).
