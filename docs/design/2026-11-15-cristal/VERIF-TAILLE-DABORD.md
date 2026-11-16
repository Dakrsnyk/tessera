# Création « taille d'abord » : vérification du code et plan d'intégration (2026-11-15)

Demande du PDG (2026-11-15, après la Build 420) : le parcours de création suit strictement l'ordre
**1 Taille (Petit / Moyen / Grand) → 2 Catégorie → 3 Widget(s) de cette catégorie → 4 Personnalisation → 5 Aperçu et enregistrement**,
et une création donne **toujours un seul widget** : Petit = 1 widget ; Moyen = 1 widget ou 2 réunis ; Grand = 1 widget ou jusqu'à 4 réunis.
Plus jamais plusieurs widgets indépendants dans une même création. Maquettes : planches 21 à 25 (outils communs `parcours.css` / `parcours.js`).

## Ce que le code permet déjà (vérifié le 2026-11-15)
- `Composer.plan(kinds, format)` (`Shared/Model/Combo.swift`) monte exactement les cas voulus : Petit 1 ; Moyen 1 (version moyenne, widget simple) ou 2 petits côte à côte ; Grand 1 (version grande), 2 (deux lignes moyennes), 3 (une ligne entière + 2 petits ; la ligne entière = le dernier qui existe en grand, sinon en moyen), 4 (4 petits). Messages de refus déjà rédigés (« Pour réunir 2 widgets, chacun doit exister en petit. », « Un widget moyen réunit 2 widgets au plus. »…).
- 1 seul widget choisi en Moyen ou en Grand = un `WidgetDesign` simple ; un widget réuni = **un seul** `WidgetDesign` avec `options.parts` ; il compte pour 1 dans la limite gratuite (3).
- Même catégorie imposée : `Fusion.category` (`space.<id>` ou `category.<catégorie>`), `ComboEditing.sameFamily`, `StudioPartRules.candidates`.
- Personnalisation, « Sur mon écran », enregistrement, guide d'ajout : l'Atelier actuel (Builds 418 à 420) sert tel quel à l'étape 4-5.

## Ce qui s'y oppose ou manque
1. **Ordre inversé** : aujourd'hui l'espace est choisi avant la taille (`SpacesView` → `SpaceBuilderView`) ; le choix de taille du constructeur n'existe qu'en DEBUG (`combines`).
2. **Plusieurs widgets séparés** : Créer › « Changer de widget » › espace : `SpaceBuilderView` coche jusqu'à 12 widgets en Petit et propose « Créer les N widgets séparés » (`SpaceBuilderView.swift` `designs`, `toggle`, bouton ; `Composer.maxCount(.small) = 12`). Le Studio gère alors `designs.count > 1` (sélecteur, « Même style », « Enregistrer les N widgets »). **À retirer de Créer.**
3. Hors Créer, à décider : les **packs du Store** (`ExploreView` `PackSheet`) et les **configurations d'écran d'accueil** (`HomeSetupViews`) ouvrent aussi le Studio avec plusieurs widgets.
4. **Pas de page Taille** ni de **carte des emplacements** (places prises / libres, compteur, « simple » / « combiné ») ; pas de passage automatique à l'Atelier en Petit.
5. **Catégories hors espaces** : horloge, calendrier, fuseaux, progression, compte à rebours, l'année en points, ma semaine, phase de lune (`category.time`) existent mais ne sont pas dans Créer → catégorie « Heure et date » à ajouter. À venir et Note (`category.productivity`) ne fusionnent pas avec l'espace Productivité. **Aucun widget météo** (retiré du code) : « Météo » = À développer.
6. Le **« + » de l'Atelier** fait passer le widget en Grand tout seul (`ComboEditing.adding`, note « Passé en Grand… ») : contraire à la taille choisie au départ → proposé : « + » seulement s'il reste une place ; plein = message + changement de taille volontaire dans Taille.
7. `BuilderSelection.toggled` remplace le plus ancien choix quand c'est plein et peut changer la taille ; l'estompage des tuiles doit s'appuyer sur `Composer.plan` (pas sur `fits`, trop permissif).
8. Textes à reprendre : `WidgetFormat.hint` (« Choisis-en plusieurs pour créer plusieurs petits widgets »). Tests de l'ancien flux : `Tests/CreateFlowTests.swift`, `UITests/StudioUITests.swift` (`creator-continue`, `create-change`).

## Plan d'intégration proposé (après validation des maquettes)
- **A. Modèle** : un `CreationDraft` (taille, catégorie, kinds choisis) qui valide chaque ajout par `Composer.plan` et donne pour chaque tuile « possible » ou la raison du refus ; catégorie « Heure et date » (kinds `category.time`). Tests logiques.
- **B. Écrans** : `CreateSizeView` (page 1, silhouettes à la vraie proportion), `CreateCategoryView` (page 2), `CreatePickView` (page 3 : carte des emplacements, compteur, simple / combiné, tuiles, « Personnaliser » ; en Petit le toucher ouvre l'Atelier). Réutiliser `StudioKindTile`, `StudioPlanThumbnail`, `WidgetPreview`.
- **C. Retraits** : plus de « Créer les N widgets séparés » ni de sélection multiple en Petit dans Créer ; « Changer de widget » ramène à la page Catégorie (même taille) ; le « + » de l'Atelier ne change plus la taille seul.
- **D. Décisions du PDG (2026-11-15)** : l'écran verrouillé = **petit lien en bas de la page Taille** (vers `LockScreenCreator`) ; les **packs du Store et les configurations d'écran d'accueil restent tels quels** (la règle « un seul widget » vaut pour l'onglet Créer seulement). Encore proposé, sans réponse : « Pour toi » et « Partir d'un modèle » vont au Store, « Dupliquer » dans Mes widgets.
- Vérification : `[unit]` puis `[daily]`, version interne `[interne]` à chaque lot.
