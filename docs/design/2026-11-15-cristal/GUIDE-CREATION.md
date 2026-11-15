# Parcours de création de widgets : guide des planches 20 à 26 (2026-11-15)

Mission de l'utilisateur : comparer **cinq parcours de création** avant de choisir. Phase 1 = maquettes seulement ; l'app n'est pas modifiée. Direction artistique validée et obligatoire : **Cristal « Équilibrée »** + **Créer « C1 Atelier »** (planche `08-creer-atelier.html`). Pas de nouvelle identité.

## 1. À lire avant de dessiner
- `GUIDE.md` (en entier : système Cristal, règles de contenu, structure d'une planche, rendu et contrôle).
- `08-creer-atelier.html` : le Studio validé (formes, panneaux, textes réels).
- `creation.css` et `creation.js` : outils communs (objet `CR`), à utiliser plutôt que de refaire.
- `cristal.css` / `cristal.js` : classes et icônes `P` disponibles.

## 2. Outils communs (`CR`, dans `creation.js`)
Charger dans cet ordre : `cristal.css`, `creation.css` ; `cristal.js`, `creation.js`, script de la planche, puis `Cristal.init()` en dernier.
- `CR.combo(parts, o)` : **widget combiné** monté avec de vrais exports, comme l'app le dessine (filet entre les parties). `parts` = `'nextSet-s'`, `'todaysWorkout-m'`, `null` (emplacement vide petit), `'+m'` (emplacement vide ligne entière). Options : `w` largeur, `sel` index entouré, `num` pastilles 1-2-3, `dim`, `lock`, `x` (croix de retrait), `dark` (approximation du style Sombre), `hue` (autre couleur principale : 58 bleu, 110 violet, -133 ambre, -160 corail), `add` (texte des emplacements vides), `cls:'flat'`.
- `CR.w(nom, largeur)` : un widget seul (vrai export). `CR.tile(nom, o)` : tuile de choix (`on`, `n`, `lock`, `off`, `sub`, `hand`). `CR.ph(icône, titre, o)` : tuile de remplacement d'un widget sans export.
- `CR.home(o)` : **écran d'accueil d'iPhone** (fond d'écran, icônes, dock). À mettre dans `<div class="phone cr-hs t-saphir" data-tab="none">` à la place de `.scr`. `o.widget` (HTML, largeur 338 pour moyen et grand avec `cls:'flat'`, `<img data-w>` pour petit), `o.fmt` `'s'|'m'|'l'`, `o.ring`, `o.rows` (1), `o.extra`.
- `CR.lock(o)` : écran verrouillé (`o.widgets` = exports `lock-…`), dans `<div class="phone cr-hs night …">`.
- Studio : `CR.head(titre, o)`, `CR.stage(html, o)`, `CR.tools(on, shift, liste)`, `CR.panel(h, html)`, `CR.hd(t, r)`, `CR.sizes(sel)`, `CR.lockSizes(sel)`, `CR.part(nom, o)`, `CR.layout(rows, o)`, `CR.dot(hex, on)`, `CR.toggle(t, on)`, `CR.steps(n, on)`. Bouton fixe : `<div class="fab">Enregistrer le widget</div>` (hors de `.scr`).
- Annotations **sur** un téléphone (en absolu dans `.phone`, repère 393 × 852) : `CR.tip(n, texte, x, y)`, `CR.pin(n, x, y)`, `CR.tap(x, y)` (rond de toucher), `CR.arrow(x1, y1, x2, y2, {dash, pri, bend})`, `CR.lift(nom, x, y, w)` (pièce soulevée par le doigt). 2 ou 3 par téléphone au plus : elles montrent le geste et le changement d'état.
- Classes : `.cr-kick`, `.cr-q` (grande question), `.cr-sub`, `.cr-card(.on)`, `.cr-rdo(.on)`, `.cr-free`, `.cr-lockb`, `.cr-why` (explication d'une limite), `.cr-ok` (confirmation), `.cr-g3`, `.cr-g2`, `.cr-note`, `.cr-row`, `.cr-field`, `.cr-part.add`.
- Ne pas modifier `cristal.*` ni `creation.*`. Le CSS propre à une planche va dans son `<style>`, avec un préfixe à elle. Une icône manquante : `Object.assign(P, {…})` dans la planche, sans écraser une icône existante.

## 3. Exemple commun aux cinq planches (pour pouvoir comparer)
Espace **Fitness**. Résultat visé : un widget **Moyen** qui réunit **« Prochaine série » + « Régularité »** (2 petits côte à côte, tout gratuit). Prolongement en **Grand** : **« Séance du jour »** sur une ligne entière + les 2 petits.

| Widget (nom exact) | Tailles | Accès | Export à utiliser |
|---|---|---|---|
| Prochaine série | Petit, Moyen | gratuit, interactif (main) | `nextSet-s-light` |
| Régularité | Petit, Moyen | gratuit | `trainingStreak-s-light` |
| Séance du jour | Petit, Moyen, Grand | gratuit | `todaysWorkout-m-light` (moyen) |
| Repos | Petit, Moyen | **Premium**, interactif | `restTimer-s-light` |
| Volume de la semaine | Petit, Moyen, Grand | **Premium** | `weeklyVolume-m-light` (moyen) |
| Records · Calories brûlées · Mois d'entraînement | — | **Premium** | aucun : `CR.ph('trophy' / 'flame' / 'calendar', …)` |

Autres espaces, si une planche en montre (exports réels) : Nutrition `calories-s-light`, `quickFood-s-light` (Premium), `macros-m-light` ; Budget `budgetLeft-s-light`, `savingsGoal-s-light`, `quickExpense-s-light` ; Productivité `tasks-s-light`, `priorities-s-light`, `counter-s-light` ; Habitudes `habitStreak-s-light`, `habits-m-light`. Écran verrouillé : `lock-nextSet-rect`, `lock-caloriesLeft-circular`, `lock-habitStreak-circular`.
Les 12 espaces de Créer : Productivité, Habitudes, Nutrition, Fitness, Budget, Placements, Mon entreprise, Sociétés cotées, Planning · études, Voyage, Auto, Ma vie. « Photos et citations » a son propre éditeur (illimité en gratuit). **Il n'y a pas de widget météo.**

## 4. Règles réelles de la combinaison (à respecter sur chaque écran)
- **Moyen** = 1 widget en version moyenne, **ou 2 petits côte à côte**. 2 au plus.
- **Grand** = 2 lignes ; chaque ligne = 1 widget moyen **ou** 2 petits. Donc : 2 moyens, ou 1 moyen + 2 petits, ou 4 petits. 4 au plus. Pas de colonne haute, pas de taille libre.
- **Petit** = 1 seul widget. **Écran verrouillé** (Rond, Rectangle, En ligne) = 1 seul widget, jamais combiné.
- Un widget combiné réunit des widgets **du même espace** (limite de l'app aujourd'hui, pas d'iOS). Le mélange d'espaces ne se dessine que s'il est étiqueté `À développer`.
- **Un seul style pour tout le widget** (thème, style, couleurs, fond, bordure, densité). Le **contenu** se règle par partie (nom, options).
- Une partie Premium rend le widget Premium : le pied devient « Débloquer et enregistrer ». Gratuit : 3 widgets enregistrés ; un widget combiné compte pour 1.
- iOS ne laisse aucune app poser un widget : après l'enregistrement, on montre le guide « Ajouter un widget ».
- Outils réels du Studio, dans l'ordre : Taille, Contenu, Thème, Style, Couleurs, Fond, Bordure, Graphique, Densité, Mes styles. Aucun outil Police, Forme, Ombre ou Effets n'existe : ne pas en inventer.

Textes réels à reprendre tels quels : « Enregistrer le widget », « Débloquer et enregistrer », « Changer de widget », « Réunir avec un autre widget », « L'essentiel en un coup d'œil. », « Plus d'informations : un widget dans sa version moyenne, ou 2 widgets réunis côte à côte. », « Un tableau de bord de l'espace : un widget en grand, ou jusqu'à 4 widgets réunis. », « Un widget moyen réunit 2 widgets au plus. », « Un grand widget réunit 4 widgets au plus. », « Pour réunir 2 widgets, chacun doit exister en petit. », « Combiné · 2 widgets », nom par défaut « Prochaine série + Régularité », « Ajouter un widget », « Enregistré dans Mes widgets », « iOS ne laisse aucune app poser un widget à ta place. », « Compris », « Seulement les widgets interactifs ».

## 5. Structure imposée d'une planche de parcours
- `<body style="--bw:1860px">`, en-tête `.bd-head` (`.num` = numéro du parcours, 1 à 5), badge « Maquette d'idée · données d'exemple ».
- **8 téléphones, 2 rangées de 4**, dans cet ordre, avec ces intitulés exacts dans `.nm` : « 1 · Écran de départ », « 2 · Premier choix », « 3 · Choix des éléments », « 4 · Combinaison », « 5 · Organisation », « 6 · Personnalisation », « 7 · Aperçu sur l'écran d'accueil », « 8 · Enregistrement ». Flèche `<span class="flow"></span>` dans les colonnes 1 à 3 et 5 à 7.
- Sous chaque téléphone, `.cap` : un titre court, une phrase, puis 2 à 4 lignes étiquetées `Existe` (`.tag.e`), `À adapter` (`.tag.a`), `À développer` (`.tag.d`), et une ligne `Geste` (`.tag.e`) avec le nombre de touchers.
- **3e rangée : 4 cases de texte** (`.note`) : « Le principe » (l'idée, pour qui) ; « Combiner, en clair » (les gestes dans l'ordre et le total de touchers pour arriver au widget Moyen à 2 widgets) ; « Où vit chaque fonction existante » (tailles, écran verrouillé, espaces, thèmes / styles / couleurs / fond / bordure / graphique / densité / mes styles, options de contenu, Premium, enregistrer / modifier / supprimer, photos et citations : rien n'est supprimé) ; « Limites dites clairement » (ce qu'iOS ou l'app ne permet pas, et la taille du chantier : moyen ou gros).
- Écrans soignés, pas de fil de fer : vraies matières Cristal, vrais exports, états visibles (choisi, vide, estompé, Premium), cibles de 44 points, textes non coupés.
- Journée d'exemple : jeudi 12 novembre, 13:20. Thème `t-saphir`. Français du Canada, guillemets « ».

## 6. Rendu et contrôle (obligatoire, deux passes au moins)
```
cd C:/Users/Etudiant/Documents/GitHub/tessera/docs/design/2026-11-15-cristal
~/ardane-tools/venv/Scripts/python.exe -I render.py NN-nom.html --phones
~/ardane-tools/venv/Scripts/python.exe -I render.py NN-nom.html --query check
```
Regarder la planche-contact puis **chaque** téléphone découpé (`pub/rapports/design-2026-11-15-cristal/ecrans/NN-nom-01.png`…, réduits à 500 px de large avec PIL avant lecture). Corriger : texte coupé ou rouge au contrôle, chevauchement (surtout une annotation sur un texte utile), bloc qui déborde, bouton caché sous la barre d'onglets, contraste. Un seul rendu à la fois (le disque est presque plein).

## 7. Interdits
Modifier `App/`, `Shared/`, `Widgets/`, `UITests/`, `scripts/` ; commit ou push ; installer quoi que ce soit ; écrire hors de `docs/design/2026-11-15-cristal/`, de `pub/rapports/design-2026-11-15-cristal/` et du dossier temporaire ; lancer d'autres agents ; inventer une fonction sans l'étiqueter.
