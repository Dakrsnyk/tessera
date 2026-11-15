# Concepts de structure : Accueil et Créer (2026-11-14)

Maquettes : `pub/rapports/design-2026-11-14/` (`accueil-3-concepts.png`, `accueil-etats.png`, `creer-C1-atelier.png`, `creer-C2-trois-gestes.png`, `creer-C3-galerie.png`, `structure-contact.jpg`). Source : `structure.html` (`?d=h|etats|c1|c2|c3`, `&w=375` pour le contrôle à 375 points).
Un seul style (Saphir évolué, clair) : Inter en 5 tailles, grille de 4 points, un seul bouton plein par écran. Les gestes sont comptés depuis l'onglet concerné. Aujourd'hui, on ouvre une mini-app en 1 toucher si sa carte est à l'écran. On crée un widget en 3 touchers depuis Créer.

## H1 « Maintenant »
1. **Identité** : le Saphir actuel, plus calme. Il n'y a qu'un bouton plein par écran. La couleur des mini-apps reste dans les pastilles d'icône.
2. **Organisation** : la date et le titre du moment, puis une carte « Maintenant », la rangée « Mes mini-apps », et enfin « Tes cartes » (Mon Quotidien).
3. **Hiérarchie** : on voit d'abord l'action du moment (« Série faite »), puis les 8 accès, puis le détail.
4. **Éléments** : en-tête date et moment (Existe) · carte « Maintenant », qui reprend la carte la mieux classée par le score actuel (À adapter) · rangée de mini-apps avec le chiffre du jour, `MiniAppsRow.swift` étant à brancher (À adapter) · cartes de Mon Quotidien (Existe) · lien « Organiser » visible (À adapter : aujourd'hui, il est dans le menu de l'appui long) · rangée fixée en haut quand on défile (À développer).
5. **Parcours** : on ouvre l'app, on agit sur la carte du haut ou on touche une icône. Il faut 1 toucher pour les 4 premières mini-apps et 2 pour les autres (glisser, puis toucher). Défilé plus bas, la barre fixée garde chaque mini-app à 1 toucher.
6. **Animations** : le titre se réduit au défilement (comportement natif). La rangée se replie en barre d'icônes avec `matchedGeometryEffect`. La carte « Maintenant » change avec un fondu. Avec « Réduire les animations », il ne reste que des fondus.
7. **Avantages** : rien ne disparaît. Le risque et l'effort sont faibles, et toutes les mini-apps sont toujours à portée. **Limites** : l'écran reste dense. La carte « Maintenant » demande des règles claires quand rien n'est en cours.

## H2 « Mosaïque »
1. **Identité** : l'accueil ressemble à un écran d'accueil iOS. Les tuiles ont le rendu des vrais widgets.
2. **Organisation** : en-tête, puis une grille de tuiles petites, moyennes et grandes, rangées par le score du moment.
3. **Hiérarchie** : elle passe par la taille des tuiles : la séance en cours prend une tuile moyenne en tête.
4. **Éléments** : rendu des widgets dans l'app avec `WidgetPreview` (À adapter) · ordre selon le moment (Existe) · boutons des widgets interactifs dans l'app (À adapter) · appui long « Mettre ce widget sur mon écran d'accueil », qui ouvre le guide (À développer) · mode Organiser en grille de widgets (À adapter).
5. **Parcours** : 1 toucher sur une tuile visible, 2 sinon. Une mini-app sans tuile se rajoute par « + ».
6. **Animations** : les tuiles s'agrandissent légèrement à l'appui. L'ouverture de la mini-app part de la tuile (`matchedGeometryEffect` ou transition de zoom).
7. **Avantages** : on comprend le produit en regardant l'accueil, et ça fait vendre les widgets. **Limites** : c'est moins riche que les cartes (pas de vues multiples, moins de boutons), et chaque tuile garde le style de son widget, d'où une cohérence plus difficile. Effort moyen.

## H3 « La Une »
1. **Identité** : éditoriale et typographique : une phrase en 34 points, des filets et presque pas de cartes.
2. **Organisation** : une « une » qui change avec le moment, puis un sommaire (une ligne par mini-app avec son chiffre du jour), puis une invitation à personnaliser (Créer, Store) plus bas.
3. **Hiérarchie** : la phrase d'abord, puis l'action, puis le sommaire.
4. **Éléments** : la phrase de la une, composée à partir de `DailyBrief` (À développer) · boutons « Série faite » et « Ouvrir » (Existe, actions des cartes) · sommaire avec les chiffres de `MiniAppSummary` (À adapter) · invitation Créer et Store (À adapter).
5. **Parcours** : 1 toucher pour chacune des 8 mini-apps, toutes visibles au lancement.
6. **Animations** : la une se met à jour avec `contentTransition(.numericText())` sur les chiffres.
7. **Avantages** : c'est le plus clair et le plus rapide pour atteindre une mini-app. **Limites** : moins dense, on perd les graphiques de l'accueil. La phrase doit rester juste dans 7 langues, ce qui coûte en traduction.

## C1 « Atelier »
1. **Identité** : un établi : grand aperçu sur un socle neutre, avec les outils dessous.
2. **Organisation** : titre, aperçu (« Changer de widget », « Sur mon écran »), rangée d'outils, panneau de l'outil, « Enregistrer le widget ».
3. **Hiérarchie** : le widget d'abord, l'outil choisi ensuite, l'enregistrement en bas.
4. **Éléments** : Studio avec aperçu fixe et outils Contenu, Thème, Style, Couleurs, Fond, Bordure, Graphique, Densité, Mes styles (Existe) · arrivée directe avec un widget proposé d'après les données (À développer) · outil Taille, avec les silhouettes et l'écran verrouillé (À adapter, vient du constructeur) · « Changer de widget », un sélecteur avec recherche (À développer) · « Sur mon écran » (À développer) · annuler et rétablir (Existe) · guide d'ajout après l'enregistrement (À adapter).
5. **Parcours** : Créer, puis « Enregistrer » : 1 toucher. Changer de thème en coûte 2 de plus. Changer de widget : 2 ou 3.
6. **Animations** : l'aperçu se met à jour en direct (déjà le cas). L'aperçu glisse vers « Sur mon écran » avec une transition de zoom. L'envol vers Mes widgets existe déjà.
7. **Avantages** : c'est le plus rapide, et il réutilise le Studio existant. **Limites** : la liste des espaces disparaît, donc on découvre moins le catalogue. La suggestion doit être juste ; sinon on y ajoute un geste.

## C2 « Trois gestes »
1. **Identité** : un guide calme : une question par écran, une barre de progression en 3 traits.
2. **Organisation** : étape, aperçu, question, réponses. « Aller au Studio » reste toujours en haut.
3. **Hiérarchie** : la question en 22 points domine, et les réponses montrent les vraies données.
4. **Éléments** : choix par donnée suivie (« Mes calories, 1 122 kcal restantes ») (À développer) · silhouettes de format aux vraies proportions, écran verrouillé compris (À adapter) · vignettes de thème réelles avec cadenas Premium (À adapter) · raccourci vers le Studio (Existe) · fin commune (À adapter).
5. **Parcours** : réponse, format, « Enregistrer » : 3 touchers, comme aujourd'hui, mais chaque choix est expliqué. 4 si on change le style.
6. **Animations** : passage d'une étape à l'autre par glissement horizontal. L'aperçu se transforme sur place (`matchedGeometryEffect`).
7. **Avantages** : le parcours le plus compréhensible pour un nouveau. **Limites** : pas plus rapide qu'aujourd'hui, et lent pour les habitués. Ne crée qu'un widget à la fois (la sélection multiple du constructeur passe au Studio). La planche a 4 téléphones : le concept a 4 moments.

## C3 « Galerie »
1. **Identité** : une bibliothèque : des modèles réels, rangés et prêts.
2. **Organisation** : recherche, « Reprendre », « Pour toi » (d'après les données), « Par espace », « Ensembles assortis » (plus bas).
3. **Hiérarchie** : chaque modèle montre son aperçu, son nom et ses deux actions.
4. **Éléments** : modèles (À adapter, `Templates.swift`) · « Utiliser » qui enregistre tel quel (À développer) · « Personnaliser » qui ouvre le Studio (Existe) · fiche de modèle avec taille et autres styles (À développer) · « Reprendre » depuis Mes widgets (À adapter) · filtres par espace (Existe) · ensembles assortis (À adapter, packs).
5. **Parcours** : Créer, puis « Utiliser » : 1 toucher. Avec un autre style : 3.
6. **Animations** : la vignette s'ouvre en fiche (transition de zoom), puis l'envol vers Mes widgets.
7. **Avantages** : immédiat, et rassurant pour ceux qui ne savent pas quoi créer. **Limites** : la frontière avec le Store est à tenir (la Galerie montre des widgets seuls, le Store des écrans complets). Il faut entretenir beaucoup de modèles. Le bouton « Personnaliser » n'est qu'une icône (avec un libellé VoiceOver).

## Fin de parcours commune
Le titre « « Calories » est prêt » et « Enregistré dans Mes widgets » (Existe : envol). Ensuite, « Écran d'accueil / Écran verrouillé » et 3 étapes tirées du guide existant, avec une note honnête : « iOS ne laisse aucune app poser un widget à ta place. » Montrer ce guide après Créer est À adapter.

## Comparaison (5 = meilleur ; pour l'effort et le risque, 5 = faible)

| | Clarté | Rapidité | Widgets en valeur | Effort | Risque |
|---|---|---|---|---|---|
| H1 Maintenant | 4 | 4 | 3 | 4 | 5 |
| H2 Mosaïque | 3 | 3 | 5 | 2 | 3 |
| H3 La Une | 5 | 5 | 2 | 3 | 2 |
| C1 Atelier | 4 | 5 | 4 | 3 | 3 |
| C2 Trois gestes | 5 | 3 | 3 | 3 | 4 |
| C3 Galerie | 4 | 5 | 5 | 2 | 3 |

## Recommandation
**Accueil : H1 « Maintenant », en lui empruntant le sommaire de H3.** Il garde tout ce qui marche (Mon Quotidien, les actions directes). Il remet en service une rangée déjà codée et donne à chaque mini-app un accès en 1 toucher, même après défilement. C'est le meilleur gain pour le moindre risque. La phrase de H3 peut venir ensuite, sous forme de titre de la carte « Maintenant ».

**Créer : C3 « Galerie » comme entrée, qui ouvre le Studio de C1 pour personnaliser.** « Utiliser » ramène la création à 1 toucher. « Personnaliser » mène au Studio, qui a déjà la forme de l'Atelier. Le guidage de C2 peut servir de premier passage (premier widget), sans en faire le parcours de tous les jours.
