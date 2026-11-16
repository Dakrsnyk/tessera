# Planches 21 à 25 refaites « taille d'abord » : consigne (2026-11-15)

Demande du PDG : toutes les stratégies de création suivent maintenant EXACTEMENT ce départ, puis gardent leur manière propre de personnaliser.
**1 Taille (Petit / Moyen / Grand) → 2 Catégorie → 3 Widget(s) de cette catégorie → 4 Personnalisation → 5 Aperçu et enregistrement.**
Une création = **un seul widget**. Petit = 1 widget, le toucher passe directement à la personnalisation (pas de bouton, pas de 2e choix). Moyen = 1 widget (version moyenne, widget simple) ou 2 réunis côte à côte. Grand = 1 widget (version grande) ou jusqu'à 4 réunis. On peut finir avant le maximum. Emplacements pris et libres toujours visibles, avec le compteur. Pas d'étape intermédiaire, pas de confirmation, pas de modèle avant la taille. Jamais plusieurs widgets séparés.
Décisions du PDG : l'écran verrouillé = petit lien en bas de la page Taille (déjà dans `CR.sizePage`) ; les packs du Store ne changent pas.

## Modèle à suivre : `25-creation-hybride.html` (déjà refaite)
Lire en entier : `GUIDE-CREATION.md` (système, exemples, règles réelles, rendu), `25-creation-hybride.html` (structure et code), `parcours.js` + `parcours.css` (outils communs), `VERIF-TAILLE-DABORD.md` (ce que le code permet).
L'ancienne version de chaque planche (pour reprendre ses spécificités et ses écrans de personnalisation) : `git show HEAD:docs/design/2026-11-15-cristal/NN-nom.html`.

## Structure imposée (comme la planche 25)
- `<body style="--bw:2320px">`, en-tête `.bd-head` (numéro du parcours, titre « Parcours N · … — taille d'abord », phrase qui dit le nouveau départ ET ce que la stratégie garde ensuite), badge « Maquette d'idée · données d'exemple ».
- Bandeau commun : `<div class="h5-band">`-like (préfixe propre à la planche) avec `CR.rule()` (« Une création = un seul widget »).
- **Rangée 1, 5 téléphones, le nouveau départ** : « 1 · Taille », « 2 · Catégorie », « 3 · Petit : un seul widget », « 4 · Moyen : jusqu'à 2 », « 5 · Grand : jusqu'à 4 ». Mêmes états que la planche 25 (Moyen 2 sur 2 avec les autres tuiles estompées « 2 au plus » ; Grand 3 sur 4 avec une place libre ; Petit : un toucher ouvre la personnalisation). Exemple commun : Fitness ; Moyen « Prochaine série + Régularité » ; Grand + « Séance du jour » (ligne entière, règle réelle de `Composer`).
  Ces 5 pages gardent **la saveur de la stratégie** sans changer l'ordre ni ajouter de page : par exemple le fil d'étapes et « Suivant » (guidée), la scène permanente en haut qui est elle-même la carte des emplacements (Studio), les cases où l'on glisse des blocs (blocs), les intentions et la composition proposée à ajuster (intention). Toujours visibles : places prises / libres, compteur « N sur max », « Widget simple » ou « Combiné · N widgets », la raison d'un refus.
- **Rangée 2, 5 téléphones, la suite propre à la stratégie** : « 6 · Personnalisation… », « 7 · … », « 8 · … » (les écrans qui font la spécificité de la stratégie : reprendre et adapter ceux de l'ancienne planche, avec le widget Moyen « Prochaine série + Régularité » obtenu à la rangée 1), « 9 · Aperçu sur l'écran d'accueil », « 10 · Enregistrement ».
- Sous chaque téléphone, `.cap` : titre, une phrase, 2 à 4 lignes `Existe` / `À adapter` / `À développer` et une ligne `Geste` (nombre de touchers). Flèche `<span class="flow"></span>` dans les colonnes 1 à 4.
- **Rangée 3, 5 notes** : « Le principe » (ce que la stratégie garde après le nouveau départ, pour qui), « Le parcours en clair » (touchers pour Petit, Moyen à 2, Grand à 3), « Où vit chaque fonction existante » (rien n'est supprimé ; écran verrouillé = lien en bas de la page Taille), « Limites dites clairement », « Vérifié dans le code » (reprendre l'essentiel de `VERIF-TAILLE-DABORD.md`).

## Règles
- Utiliser `CR.sizePage`, `CR.chosen`, `CR.catPage`, `CR.build` / `CR.slots`, `CR.go`, `CR.rule` et les outils `CR` de `creation.js`. Ne pas modifier `cristal.*`, `creation.*`, `parcours.*` (un manque → le dire dans le rapport ; CSS propre à la planche dans son `<style>`, avec son préfixe).
- Textes réels seulement (liste dans `GUIDE-CREATION.md` §4 et dans `parcours.js`). Rien d'inventé sans étiquette. Pas de widget météo (catégorie « À développer »). Français du Canada, guillemets « ».
- Annotations (`CR.tap`, `CR.tip`, `CR.arrow`, `CR.lift`) : 2 ou 3 par téléphone au plus, jamais sur un texte utile ni sur le widget.
- Rendu : `~/ardane-tools/venv/Scripts/python.exe -I render.py NN-nom.html --phones` (un seul rendu à la fois ; le disque et la mémoire sont presque pleins). Regarder la planche entière puis chaque téléphone (`pub/rapports/design-2026-11-15-cristal/ecrans/NN-nom-01.png`…, réduits à 440 px de large avec PIL avant lecture). Corriger : texte coupé, chevauchement, tuiles cachées sous le bouton du bas, contraste. Deux passes au moins.
- Interdits : modifier autre chose que sa planche ; `App/`, `Shared/`, `UITests/`, `scripts/` ; commit ou push ; lancer d'autres agents ; installer quoi que ce soit.
