# Carte du projet Ardane (Obsidian)

Cartes et notes générées à partir du code par `scripts/obsidian_map.py` : rien n'y est inventé, chaque élément renvoie à ses fichiers sources.

## Ouvrir dans Obsidian

1. Obsidian → **Open folder as vault** → choisir la **racine du dépôt** (le dossier qui contient `App/`, `Shared/`, `docs/`). Les liens vers les fichiers sources n'existent qu'avec ce choix.
2. Ouvrir `docs/obsidian/Vue-Globale.canvas` (la carte principale), puis `Architecture.canvas` et `Fonctionnalites.canvas`.
3. Pour ouvrir les fichiers `.swift` depuis Obsidian : Settings → Files & links → activer **Detect all file extensions** (sinon ils s'ouvrent seulement depuis GitHub ou Xcode).
4. Dans une carte : molette ou pincement pour zoomer, clic sur un lien de note pour ouvrir la note du module.

## Les cartes

- [[Vue-Globale.canvas|Vue globale]] : le projet au centre, les grands modules autour (interface, logique métier, données, widgets et iOS, services externes, outillage), les sous-fonctionnalités en groupes et les liens entre modules.
- [[Architecture.canvas|Architecture]] : les couches (interface → état → code partagé → persistance), l'extension WidgetKit, les services, les cibles Xcode et la CI.
- [[Fonctionnalites.canvas|Fonctionnalités]] : chaque partie d'Ardane avec ses sous-fonctionnalités et les fichiers qui les portent.

## Les notes de modules

**Interface (App/Screens)**
- [[Accueil-Mon-Quotidien|Accueil : Mon Quotidien]] ([fichier](modules/Accueil-Mon-Quotidien.md))
- [[Mini-apps|Mini-apps]] ([fichier](modules/Mini-apps.md))
- [[Nutrition|Nutrition]] ([fichier](modules/Nutrition.md))
- [[Fitness|Fitness]] ([fichier](modules/Fitness.md))
- [[Planning-et-habitudes|Planning, tâches et habitudes]] ([fichier](modules/Planning-et-habitudes.md))
- [[Finances|Finances]] ([fichier](modules/Finances.md))
- [[Autres-mini-apps|Autres mini-apps]] ([fichier](modules/Autres-mini-apps.md))
- [[Creer-espaces|Créer : les espaces]] ([fichier](modules/Creer-espaces.md))
- [[Store|Store]] ([fichier](modules/Store.md))
- [[Studio-editeur|Studio (éditeur de widgets)]] ([fichier](modules/Studio-editeur.md))
- [[Mes-widgets|Mes widgets]] ([fichier](modules/Mes-widgets.md))
- [[Profil-et-reglages|Profil et réglages]] ([fichier](modules/Profil-et-reglages.md))
- [[Onboarding-et-tutoriel|Lancement, premier lancement et tutoriel]] ([fichier](modules/Onboarding-et-tutoriel.md))

**Logique métier et état**
- [[Noyau-AppModel|Noyau : AppModel et Router]] ([fichier](modules/Noyau-AppModel.md))
- [[Domaines-metier|Domaines métier (Shared/Domains)]] ([fichier](modules/Domaines-metier.md))
- [[Premium-et-abonnements|Premium et abonnements]] ([fichier](modules/Premium-et-abonnements.md))

**Données et stockage**
- [[Donnees-et-stockage|Données et stockage]] ([fichier](modules/Donnees-et-stockage.md))

**Widgets et système iOS**
- [[Widgets-extension|Widgets : extension et rendu]] ([fichier](modules/Widgets-extension.md))
- [[Intents-et-activite-en-direct|Boutons des widgets, activité en direct et liens]] ([fichier](modules/Intents-et-activite-en-direct.md))

**Services externes**
- [[Services-externes|Services externes et frameworks Apple]] ([fichier](modules/Services-externes.md))

**Qualité et outillage**
- [[Outils-partages|Outils partagés (Shared/Support)]] ([fichier](modules/Outils-partages.md))
- [[Localisation|Localisation]] ([fichier](modules/Localisation.md))
- [[Tests-CI-et-outils|Tests, CI et outils]] ([fichier](modules/Tests-CI-et-outils.md))

## Vue graphique (le réseau d'étoiles)

Chaque fichier du code a sa note dans `code/` (ce qu'il déclare, ce qu'il utilise, ses services), chaque service ou framework dans `services/`, et [[Ardane]] est le centre. Chaque module est une étoile : ses fichiers sont reliés à lui et entre eux ; les modules sont reliés à leurs trois plus fortes dépendances (mesurées dans le code) et à leurs services. Les dépendances vers les fichiers d'autres modules restent écrites dans chaque note, sans lien, pour garder des grappes lisibles.

1. Ouvrir la vue graphique : icône « Vue graphique » dans la barre de gauche (ou Ctrl+G).
2. Roue dentée en haut à droite du graphe → **Filtres** → dans la recherche, taper `tag:#ardane` (seulement les notes de la carte, sans le guide ni les canvas).
3. **Groupes** → « Nouveau groupe » six fois, avec ces requêtes et une couleur chacune :
   - `tag:#zone/interface` (cyan) · `tag:#zone/metier` (vert) · `tag:#zone/donnees` (jaune)
   - `tag:#zone/ios` (violet) · `tag:#zone/outils` (gris) · `tag:#service` (orange)
   - facultatif : `tag:#memoire` (blanc) pour la [[Memoire|mémoire du projet]] (demandes, chantiers, décisions, pièges).
4. **Forces** : force centrale ≈ 0,3 · répulsion ≈ 15 · force des liens ≈ 0,6 · distance des liens ≈ 120. **Affichage** : « Flèches » activé, taille des nœuds ≈ 1,5, seuil d'estompage du texte vers la gauche pour voir les noms des modules.
5. Clic sur un point : ouvre la note ; survol : allume ses liens. Les gros points (AppModel, SharedStore, WidgetDesign…) sont les fichiers dont tout dépend.

## Couleurs

Cyan : interface · Vert : logique métier · Jaune : données · Violet : widgets et iOS · Orange : services externes · Gris : outillage.

## Mettre à jour

Modifier `MODULES` ou les cartes dans `scripts/obsidian_map.py`, puis lancer `python3 scripts/obsidian_map.py` : il réécrit `docs/obsidian/` et vérifie le JSON des cartes, les liens entre notes et l'existence de chaque fichier source cité. `python3 scripts/obsidian_map.py --check` vérifie sans rien écrire.
