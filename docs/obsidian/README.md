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
- [[Localisation|Localisation]] ([fichier](modules/Localisation.md))
- [[Tests-CI-et-outils|Tests, CI et outils]] ([fichier](modules/Tests-CI-et-outils.md))

## Couleurs

Cyan : interface · Vert : logique métier · Jaune : données · Violet : widgets et iOS · Orange : services externes · Gris : outillage.

## Mettre à jour

Modifier `MODULES` ou les cartes dans `scripts/obsidian_map.py`, puis lancer `python3 scripts/obsidian_map.py` : il réécrit `docs/obsidian/` et vérifie le JSON des cartes, les liens entre notes et l'existence de chaque fichier source cité. `python3 scripts/obsidian_map.py --check` vérifie sans rien écrire.
