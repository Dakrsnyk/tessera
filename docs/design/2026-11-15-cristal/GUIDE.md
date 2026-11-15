# Cristal : guide des planches (2026-11-15)

Choix de l'utilisateur le 2026-11-15 : **Cristal « Équilibrée »** pour toute l'app, **C1 « Atelier »** pour Créer. Phase 1 = maquettes seulement ; l'app n'est pas modifiée avant sa validation.

## 1. À lire avant de dessiner
- `cristal.css` et `cristal.js` (en entier : classes, icônes `P`, données `DAY`, utilitaires `U`, thèmes `THEMES`).
- `00-apercu.html` : planche d'exemple (accueil de référence, Créer en 3 écrans). Son rendu : `pub/rapports/design-2026-11-15-cristal/00-apercu-contact.jpg`.
- `inventaire/*.md` : ce que l'app affiche vraiment (relevé dans le code, **fait foi**).
- `../2026-11-14-refonte/compositions/DONNEES.md` : contenu des cartes de l'accueil et journée d'exemple.
- Les deux références choisies par l'utilisateur : `C:/Users/Etudiant/.claude/uploads/a80d9a9c-6c92-4db7-b02e-61e003377ee2/5653dfd6-image.png` (accueil Cristal) et `a934f218-image.png` (Créer C1 Atelier).

## 2. Le système Cristal
- **Deux matières.** Verre (`.gl`) : seulement ce qui flotte (barre date + avatar, boutons ronds de navigation `.rb.gl`, sélecteur de semaine d'une mini-app, la carte « Maintenant » : une seule par écran, boutons posés sur un aperçu, barre d'onglets). Panneau (`.pn`) : tout le contenu, presque opaque. Les feuilles (`.sheet`) sont opaques.
- **Fond** : clair, deux nappes de couleur floues (posées par le thème). Une page de mini-app (`.phone.app` + `data-c`) ajoute en haut une nappe de la couleur de la mini-app, et la couleur d'action de la page devient celle de la mini-app.
- **Couleur** : une seule couleur d'action (`--primary`) ; les couleurs de catégorie (`data-c`) ne servent qu'aux pastilles d'icône (`.ico`) et aux graphiques ; un état ne repose jamais sur la couleur seule (toujours un texte, une coche, un texte barré) ; pas de texte courant en couleur de catégorie.
- **Formes** : panneaux à rayon `var(--r)` (26), marges d'écran 20, 12 entre panneaux, 14 à 16 de marge intérieure. Boutons en capsule de 44 points au moins.
- **Lettres** (Inter, remplacée par SF Pro sur iPhone) : titre d'écran 32/700 (`.x-title`) ; section 20/700 (`.x-sec b`) ou 17/700 (`.sect b`, `.h3`) ; titre de carte 15/650 ; texte 15 ; secondaire 12,5 à 14 (`.s`, `.m`) ; grand chiffre 28 (`.big`) ou 44 (`.huge`) ; étiquette en capitales 12/700 (`.x-lab`). Chiffres tabulaires (`.tn`).
- **Composants disponibles** : `.x-top`, `.x-kick`, `.x-title`, `.x-sub`, `.nv` + `.rb`, `.x-sec`, `.sect`, `.pn` / `.gl`, `.cd` / `.hc` / `.mn`, `.ch` (en-tête de carte : `.ico`, titre, `.pg`, `.go`), `.nb` (« Maintenant »), `.prem` (badge Premium), `.btnP` / `.btnT` / `.btnG` / `.btnO`, `.pill`, `.grp`, `.seg`, `.chips` + `.chip`, `.ls` + `.li` (listes), `.chk`, `.stat`, `.empty` (état vide en pointillés), `.dim` + `.sheet` + `.grab`, `.step`, `.info`, `.okl`, `.fab`, `.wsel` (par `U.wsel` ou `data-u="wsel"`), `.stage`, `.tools`, `.sizes`, `.thumbs`, `.dots`, `.mini`, `.wt`, graphiques `data-u="ring|meter|bars|spark|week|dots7|hab"`.
- **Page d'une mini-app** (structure de l'app gardée, habillage Cristal) : `.nv` (retour rond en verre + titre), sélecteur de semaine en verre, la « figure essentielle » du jour dans une carte de verre, puis des panneaux avec des titres `.sect` ; action flottante `.fab` si la mini-app en a une ; « Mes paramètres » en bas (`.btnO`). La barre d'onglets reste visible (onglet Accueil actif).

## 3. Règles de contenu
- **Rien d'inventé.** Chaque bloc vient de l'inventaire, avec ses libellés exacts. Une nouveauté est permise seulement si elle est étiquetée dans la légende : `Existe` (`.tag.e`), `À adapter` (`.tag.a` : la donnée ou la fonction existe, pas à cet endroit ou pas sous cette forme), `À développer` (`.tag.d`). Ce qui n'existe pas (hydratation, série de jours de sport, fréquence cardiaque, placements…) ne se dessine pas.
- Aucune fonction existante ne devient un simple décor : chaque bouton de l'inventaire garde sa place ou une place équivalente.
- Français du Canada : « 412 $ », « 21,68 $ », « 14:00 », « 1 122 », repas Déjeuner / Dîner / Souper / Collation. Guillemets « ».
- **Une seule journée d'exemple** : jeudi 12 novembre, avatar « M », aux moments 08:10, 13:20 (par défaut) ou 19:05. Reprendre les chiffres de `DAY`, `EVENTS`, `HABITS`, `TOP3`, `REMIND`, `CAL7`, `SPEND7`. Toute donnée ajoutée doit rester cohérente avec eux (budget du mois 1 200 $, dépensé 788 $, 412 $ restants, 21,68 $ par jour, 14,50 $ aujourd'hui ; compte chèques 1 846,20 $ ; séance Haut du corps : 6 exercices, 18 séries, 4 320 kg ; 2 séances faites sur 4 ; habitudes 3/5 à 13:20, série de 12 jours).
- Thème clair seulement. Thème par défaut : `t-saphir`.
- Vrais exports de widgets : `<img data-w="NOM">`, parmi : `calories-s-light|dark|paper|editorial|ocean|aurora|glass|luxury|neon|space|blossom|matteBlack|liquidGlass|synthwave`, `calories-m-light|dark|aurora`, `macros-m-light|dark|paper|editorial|ocean|aurora|glass|luxury|neon`, `quickFood-s-light`, `quickFood-m-light|paper|glass`, `todaysWorkout-m-light|dark|aurora`, `nextSet-s-light|luxury|neon`, `nextSet-m-dark`, `restTimer-s-light|dark|neon`, `trainingStreak-s-light|aurora|sport`, `weeklyVolume-m-light|dark|neon`, `budgetLeft-s-light|dark|luxury`, `budgetLeft-m-dark`, `moneyDashboard-m-light|dark|aurora`, `spendingByCategory-m-light|dark|glass`, `savingsGoal-s-light`, `savingsGoal-m-light`, `quickExpense-s-light`, `upNext-s-light|dark|elegant`, `upNext-m-light`, `weekView-m-light|dark|editorial|aurora`, `timetable-m-light`, `timetable-l-light|editorial|aurora`, `tasks-s-light`, `tasks-m-light`, `priorities-s-light|dark|paper`, `habits-m-light|dark|aurora|neon`, `habitStreak-s-light|aurora|neon`, `yearDots-l-light|dark|space`, `clock-m-minimal`, `counter-s-light`, `lock-caloriesLeft-circular`, `lock-caloriesLeft-rect`, `lock-macros-rect`, `lock-habitStreak-circular`, `lock-nextSet-rect`, `lock-upNext-rect`, `lock-budgetLeft-rect`. Petit = carré ; moyen = environ 2,13:1 ; grand = carré.
- Captures réelles de l'app (pour contrôle, du 2026-10-31) : `C:/Users/Etudiant/ardane-tools/film/public/kit2026/fr/app-<mini-app>-*.png`, `studio-*.png`, `store.png`, `mywidgets.png`, `paywall.png`.
- Aucune ressource du réseau. Police : Inter (déjà déclarée).

## 4. Structure d'une planche
```html
<body style="--bw:1860px">   <!-- 4 téléphones par rangée ; 1400px pour 3 -->
<main class="bd">
  <header class="bd-head"><div class="num">3</div><div><h1>…</h1><p>…</p></div><span class="badge">Maquette d'idée · données d'exemple</span></header>
  <div class="row">
    <div class="col"><div class="nm">1 · Page principale</div>
      <div class="phone app t-saphir" data-c="nut" data-time="13:20" data-tab="0"><div class="scr">…</div></div>
      <div class="cap"><h4>…</h4><p>…</p><ul><li><span class="tag e">Existe</span><span>…</span></li></ul></div></div>
    …
  </div>
</main>
<script src="cristal.js"></script><script>/* Object.assign(P, {…}) pour une icône manquante */ Cristal.init();</script>
```
- `data-tab` : `0` Accueil, `1` Créer, `2` Store, `3` Mes widgets, `none`. Une feuille : `.dim` puis `.sheet` **hors** de `.scr`, dans `.phone`.
- Ne pas modifier `cristal.css` ni `cristal.js`. Le CSS propre à une planche va dans son `<style>`, avec un préfixe de classe à elle.
- Une case de texte dans une rangée : `<div class="col"><div class="nm">Légende</div><div class="note" style="margin:9px">…</div></div>`.
- Flèche vers le téléphone suivant : `<span class="flow"></span>` dans `.col`.

## 5. Rendu et contrôle (obligatoire, deux passes au moins)
```
cd C:/Users/Etudiant/Documents/GitHub/tessera/docs/design/2026-11-15-cristal
~/ardane-tools/venv/Scripts/python.exe -I render.py NN-nom.html --phones
~/ardane-tools/venv/Scripts/python.exe -I render.py NN-nom.html --query check
```
- Sorties dans `pub/rapports/design-2026-11-15-cristal/` : `NN-nom.png`, `NN-nom-contact.jpg`, `ecrans/NN-nom-01.png`… et `NN-nom-check.png` (texte coupé ou débordant entouré de rouge).
- Regarder la planche-contact, puis **chaque** téléphone découpé (les réduire à 500 px de large avec PIL avant de les lire). Corriger : texte coupé, chevauchement, bloc qui déborde de son panneau, contenu important caché sous la barre d'onglets (le dernier panneau peut s'effacer dessous : c'est le défilement), alignements, cibles de moins de 44 points, contraste.
- Si le script signale que la planche touche le bas du rendu : ajouter `--maxh 8000`.

## 6. Interdits
Modifier `App/`, `Shared/`, `Widgets/`, `UITests/`, `scripts/` ; commit ou push ; installer quoi que ce soit ; écrire hors de `docs/design/2026-11-15-cristal/`, de `pub/rapports/design-2026-11-15-cristal/` et du dossier temporaire ; lancer d'autres agents.
