# Inventaire de l'existant : Accueil, Créer, navigation (2026-11-14)

Relevé dans le code par un agent en lecture seule. **Il corrige la section 2 du brief** : en cas d'écart, ce fichier fait foi.

## Accueil (`App/Screens/Home/HomeView.swift`, `DailySection.swift`, `App/Core/DailyBrief.swift`)
- Barre du haut : la date en **texte** accentué à gauche (pas une pastille), l'avatar du profil à droite (feuille Profil).
- Puis, dans l'ordre : « MON QUOTIDIEN » et le titre selon l'heure (« Ta matinée » de 5 h à 11 h, « Ta journée » de 11 h à 18 h, sinon « Ta soirée ») ; la grille de cartes ; une carte pointillée « + » (« Ajouter une catégorie », seulement s'il en manque) ; la carte « Mes informations » (anneau de complétion, pastilles de domaines) ; un bandeau Premium si l'utilisateur n'est pas Premium. État vide : « Ajouter mes informations ».
- **L'ordre des cartes dépend déjà du moment** : chaque carte a un score (séance en cours en tête, cours ou examen dans moins de 2 h, séance prévue, repas, habitudes le soir…). Une pastille « Maintenant » existe déjà sur la séance prévue après 11 h.
- 11 catégories de cartes : nutrition, séance, planning, habitudes, budget, Top 3, « À ne pas oublier », pas, entreprise, voyage, auto. Chacune en demi-largeur ou pleine largeur. Une carte sans donnée est un cadre pointillé « Ajouter ».
- Plusieurs vues (points et balayage) : **seulement** Nutrition, Séance et Pas.
- Toucher : ouvre la mini-app ou une de ses pages. Actions directes déjà présentes : « Commencer », « Série faite », pause du repos ; bouton Scanner ; coches du Top 3 ; ajout rapide de tâche.
- Appui long : un **menu** (« Organiser… », « Retirer de Mon Quotidien »). Le mode Organiser : cartes qui tremblent, croix pour retirer, +/− pour la taille, maintenir puis glisser, feuille de disposition.
- L'accueil ne défile jamais à l'horizontale (verrou volontaire).
- Décision validée le 2026-10-22 : léger dégradé de la couleur de catégorie sur chaque carte, sans image.

## Créer (`App/Screens/Spaces/SpacesView.swift`, `SpaceBuilderView.swift`, `App/Screens/Editor/EditorView.swift`)
- Liste : titre, phrase d'aide, filtres (Tout, Écran verrouillé, Santé, Argent, Organisation, Vie), puis **13 grandes cartes** : 12 espaces (Productivité, Habitudes, Nutrition, Fitness, Budget, Placements, Entreprise, Marchés, Études, Voyage, Auto, Vie) et « Photos et citations ». Les intérêts de l'utilisateur passent en premier.
- Constructeur (feuille) : Petit / Moyen / Grand, aperçu aux vraies proportions, grille de widgets (cadenas Premium, badge Interactif, filtre « interactifs seulement »), un widget déjà présélectionné, barre « Personnaliser ». Moyen : 1 widget ou 2 combinés ; Grand : jusqu'à 4.
- **Studio** : aperçu fixe en haut, puis des onglets d'outils : Contenu, Thème, Style, Couleurs, Fond, Bordure, Graphique, Densité, Mes styles ; annuler et rétablir ; barre « Enregistrer le widget ». **C'est déjà la structure du concept C1 « Atelier »** : la nouveauté de C1 serait d'y arriver directement.
- Aujourd'hui : **3 touchers** depuis l'onglet Créer pour enregistrer un widget (carte d'espace, « Personnaliser », « Enregistrer »).
- Fin de parcours : une animation fait voler le widget vers « Mes widgets ». Le guide « Ajouter un widget à l'écran d'accueil » existe (5 étapes, 4 pour l'écran verrouillé) mais **n'est pas montré après Créer** : le montrer serait « À adapter ».
- Gratuit : 3 widgets enregistrés, photos et citations illimitées, environ 10 thèmes de widgets. Premium : widgets marqués, thèmes, fonds, polices, palettes, bordures. Abonnement mensuel ou annuel seulement.

## Navigation (`App/ArdaneApp.swift`, `App/Core/Router.swift`)
- 4 onglets : Accueil, Créer, Store, Mes widgets.
- **8 mini-apps** : Nutrition, Fitness, Planning (qui contient Études **et** Habitudes), Finances, Entreprise, Voyage, Auto, Photos et citations. « Habitudes » n'est donc pas une mini-app à part. Placements, Marchés et Vie n'ont pas de mini-app.
- On atteint une mini-app par sa carte de l'accueil, par un widget (lien profond) ou par le tutoriel. Un composant « rangée de mini-apps » (`MiniAppsRow.swift`) existe dans le code mais n'est branché nulle part.

## Composants réutilisables
`DayCard`, `DailyPager`, `DailyGridLayout`, `.card()`, `FilterChip`, `ThemeSwatch`, `CompletionRing`, `RingView`, `ImmersiveCard`, `WidgetPreview` (vrai rendu d'un widget dans l'app), `StudioStage`, `SaveFlightOverlay`, `PremiumBadge`, `ExampleBadge`.

## Contraintes
- iOS 17. L'app ne pose pas de widget elle-même. Dans la galerie iOS, le widget Ardane montre le dernier widget enregistré de chaque taille ; un appui long permet d'en choisir un autre.
- Pas de vraie transparence pour un widget. Écran verrouillé : une seule teinte.
- Rien d'inventé : une carte vide plutôt qu'un faux chiffre. Mode sombre existant (Auto, Clair, Sombre).
- Couleur de l'app : 12 teintes, Saphir gratuite, 11 Premium (`Shared/Theme/AppStyle.swift`).
