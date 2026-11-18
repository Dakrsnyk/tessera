# Nutrition : refonte UX/UI, étapes 1 et 2 (conception, 2026-11-17)

Sujet 1 de la refonte des mini-apps (`../MISSION.md`). **Conception seulement : aucune ligne de l'app ne change.** Style imposé : Cristal « Équilibrée », couleur orange de Nutrition. Rien de l'existant n'est retiré : chaque planche prouve par une table que les 64 fonctions de l'audit (`../audit/01-nutrition.md`) ont une place (0 non placée sur les cinq).

## Les planches
Sources HTML dans ce dossier ; images dans `pub/rapports/design-2026-11-17-mini-apps/01-nutrition/` (hors dépôt), avec `ecrans/` (chaque téléphone découpé) et `Ardane-Nutrition-refonte.pdf` (tout réuni).

| N° | Fichier | Idée | Écrans | Nouveautés |
|---|---|---|---|---|
| 0 | `00-analyse.html` | Nutrition aujourd'hui : captures de la CI, problèmes, fonctions | — | — |
| 1 | `01-minimaliste.html` | « Un chiffre, un geste » : le reste en grand, un bouton « Ajouter », tout le reste dans « Tout Nutrition » | 8 | 0 |
| 2 | `02-tableau-de-bord.html` | « Le bilan en tuiles » : objectif − mangé = reste, trois boutons, six tuiles | 6 | 2 (eau, renommer un repas) |
| 3 | `03-analytique.html` | « Les tendances d'abord » : onglets Jour, Semaine, Tendances | 9 | 3 (évolution des objectifs, constats, semaine dernière) |
| 4 | `04-quotidienne.html` | « Le journal des repas » : repas dépliés, repère « Maintenant », barre de saisie fixe | 9 | 2 (eau, favoris en une touche) |
| 5 | `05-hybride.html` | « La page qui suit ta journée » : anneau, carte « Maintenant », deux portes « Bilan » et « Ma bibliothèque » | 9 | 2 (objectif daté, modifier un repas) |
| C | `06-comparaison.html` | Notes sur 10 pour les 10 critères, avantages et inconvénients, recommandation, questions | — | — |

Fichiers communs : `nutrition.js` (les 64 fonctions, les données d'exemple, les pièces `NUT.ui`), `nutrition.css`, `CONCEPT.md` (le cadrage des cinq directions).

## Notes (jugement, pas de test avec des utilisateurs)
Minimaliste 75 · Tableau de bord 69 · Analytique 65 · Quotidienne 74 · **Hybride 79**.

## Recommandation
La 5, hybride, avec les favoris en une touche de la 4. Nutrition sert surtout à noter un repas plusieurs fois par jour puis à lire ce qu'il reste : la 4 est la plus rapide (1 toucher pour un favori, contre 3) mais allonge la page et ajoute une barre fixe que les autres mini-apps n'ont pas. La 5 garde une page courte, met le scan sous le pouce, range l'analyse à un toucher et réutilise les pièces des autres mini-apps. Pour le plus petit chantier et aucune nouveauté : la 1.

## Questions pour le PDG (choix conseillé entre parenthèses)
1. Direction : 5 avec les favoris de la 4 (conseillé), 5 seule, ou 1.
2. Favoris en une touche dans l'app : gratuit ou Premium (Premium, comme le widget « Ajout rapide »).
3. Eau : hors de Nutrition, déjà suivie comme habitude (hors).
4. Objectif daté et « Modifier » un repas enregistré : oui aux deux.
5. Écarts de l'audit : suivre le code (2 041 kcal sur 7 jours, souper à 1 122 kcal) plutôt que les planches Cristal, et choisir une seule règle pour « objectif atteint ».
6. Carte de Mon quotidien : pleine largeur (conseillé), la « Medium » de la mission n'existant pas.

## Limites
Maquettes en Inter (SF Pro sur l'iPhone) ; grandes tailles de texte et mode sombre non dessinés ; notes de jugement ; libellés nouveaux (« Tout Nutrition », « Ma bibliothèque », « Bilan », « Maintenant », « Plat ») à vérifier en allemand et en japonais ; la planche d'analyse (0) attend les captures de la CI (cadres « Capture à venir » le cas échéant). Plusieurs écrans montrent un état à un autre moment (08:10, 19:05), dit en légende.
