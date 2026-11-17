# Brief du dessinateur d'une planche de direction

Tu dessines UNE planche : la direction `N` d'un sujet (une mini-app d'Ardane). Le Chef te donne trois valeurs : le dossier du sujet (par exemple `01-nutrition`), le fichier de données du sujet (par exemple `nutrition.js`) et le numéro de ta direction avec son nom de fichier (par exemple `03-analytique.html`).

Dépôt : `C:/Users/Etudiant/Documents/GitHub/tessera`. Dossier de la mission : `docs/design/2026-11-17-mini-apps/` (noté `D` ci-dessous). Texte du PDG : `D/MISSION.md`.

## Règles strictes
1. **Conception seulement.** Tu ne modifies aucun fichier de l'app (`App/`, `Shared/`, `Widgets/`, `Tests/`, `UITests/`, `scripts/`, `.github/`). Tu n'écris qu'UN fichier : ta planche, `D/<sujet>/0N-<nom>.html`. Tu ne modifies ni `D/base/`, ni `CONCEPT.md`, ni le fichier de données du sujet, ni les planches des autres directions (d'autres agents les dessinent en même temps que toi).
2. **Aucune commande git qui écrit** (pas de add, commit, stash, reset, checkout, switch). Aucun autre agent.
3. **Style imposé** : Cristal « Équilibrée » (`docs/design/2026-11-15-cristal/` : `GUIDE.md`, `cristal.css`, `cristal.js`) et C1 « Atelier » pour ce qui touche à la création. Aucune nouvelle identité graphique. Clair, lumineux, proche d'Apple : blanc, blanc cassé, bleu glacé, palette Ardane, verre discret, arrondis, hiérarchie nette.
4. **Rien de l'existant n'est retiré, rien d'inventé n'est montré comme existant.** L'audit du sujet est la vérité : `D/audit/<sujet>.md` (section 4 : fonctions existantes F1…Fn ; section 9 : ce qui n'existe pas). Tout ce qui n'existe pas porte l'étiquette « Nouveau », dans l'écran et dans la légende.
5. **Français du Canada, mots simples.** Les libellés de l'app sont repris tels qu'ils s'affichent. Données d'exemple crédibles et cohérentes : journée des planches Cristal, jeudi 12 novembre 2026, 13 h 20 (sauf indication du concept).

## À lire en entier avant de dessiner
- `D/<sujet>/CONCEPT.md` : la section 0 (règles communes du sujet), TA direction (idée, navigation, élément vedette, structure, liste des écrans avec leurs données), la matrice des différences, la cohérence avec Mon quotidien, la partie « Rien n'est retiré » de ta direction, les nouveautés.
- `D/<sujet>/<données>.js` : la liste `FEATURES` et les données d'exemple.
- `D/base/GUIDE-PLANCHES.md` (règles, pièces prêtes à l'emploi, nommage, rendu, liste de contrôle en 12 points), `D/base/GABARIT-direction.html`, `D/base/planches.css`, `D/base/planches.js`, `D/base/CATALOGUE.html`.
- `docs/design/2026-11-16-finance/05-hybride.html` : le niveau de finition attendu.
- La section 4 et la section 9 de `D/audit/<sujet>.md`.

Lis aussi le titre et l'idée des quatre autres directions dans `CONCEPT.md` : ta planche doit s'en distinguer nettement. Ne les imite pas.

## Ce que la planche doit contenir
- **6 à 9 écrans iPhone** aux proportions réalistes : de vraies compositions d'interface avec des données crédibles, pas des boîtes grises. Ce sont les écrans prévus pour ta direction dans `CONCEPT.md`.
- Au minimum : l'écran principal ; les sections et leurs accès ; une vue détaillée d'une fonction importante ; une vue de gestion ou de personnalisation ; une vue secondaire pertinente.
- Chaque écran a son nom, sa légende (un titre, deux phrases au plus, les étiquettes « Existe » / « À adapter » / « Nouveau ») et le passage vers l'écran suivant (d'où l'on vient, ce qu'on touche).
- Le bloc « La logique » en tête : le parti pris, ce qu'on lit en ouvrant, ce qu'on trouve en défilant, les forces et les limites (honnêtes).
- La table de fin « Rien n'est retiré » : TOUTES les fonctions de `FEATURES` y sont placées sur un écran de la planche, ou sur la page où elles restent. Aucune ligne en rouge.
- Hiérarchie nette, rien de surchargé : si un écran déborde, c'est qu'il porte trop ; range dans une autre page plutôt que de rapetisser le texte.
- Les nouveautés sont rares, justifiées, marquées.
- Les styles propres à ta planche vont dans son `<style>`, avec un préfixe à toi. Si un outil commun te manque, écris-le dans ta planche et signale-le dans ton rapport.

## Rendu et vérification (obligatoires)
Depuis `D/<sujet>/` :
```
~/ardane-tools/venv/Scripts/python.exe -I ../base/render.py 0N-<nom>.html --phones
~/ardane-tools/venv/Scripts/python.exe -I ../base/render.py 0N-<nom>.html --query check
```
Les images arrivent dans `pub/rapports/design-2026-11-17-mini-apps/<sujet>/` : la planche `.png`, la planche-contact `-contact.jpg`, et chaque téléphone dans `ecrans/0N-<nom>-NN.png`.

**Regarde le résultat** avec l'outil Read : la planche-contact, puis CHAQUE écran découpé. Corrige tout texte coupé ou qui déborde, tout chevauchement, tout écran vide ou trop chargé, puis rends à nouveau. Deux passes au moins. Le guide dit quelles alertes de « check » sont fausses. Passe enfin la liste de contrôle en 12 points du guide.

## Ton rapport (court)
1. Le fichier écrit et le nombre d'écrans.
2. Les nouveautés montrées (chacune étiquetée ?).
3. Les fonctions de `FEATURES` sans place, s'il en reste (il ne doit pas en rester).
4. Ce que tu as vérifié sur les images, et ce qui reste imparfait.
5. Tout outil commun qui t'a manqué.
