# Mission de nuit du 2026-11-16 : corrections ciblées et audit complet

Demande du PDG (01 h 15) : 5 corrections précises, puis un audit fonctionnel, de cohérence et UX/UI de toute l'app ; corriger les bugs avérés, documenter le reste ; compte rendu et version de test complète au retour (~6 h).

## Méthode
- Pas de Mac : les tests « exécutés » sont ceux de la CI GitHub Actions (simulateur iPhone, iOS 17+) : tests logiques (environ 1 400) et tests d'interface de Mon quotidien, Créer, le Studio, l'inscription, le Profil et les mini-apps (série `[daily]`), plus les captures d'écran.
- Audit du code par 2 agents en lecture seule (cohérence des données ; parcours et interface), chaque constat revérifié dans le code avant correction.
- Toute correction relue par un agent indépendant (`code-reviewer`).

## 1. Les 5 corrections demandées
| # | Demande | Fait | Fichiers |
|---|---|---|---|
| 1 | Créer, Moyen : 1er widget sur toute la surface, partage au 2e ; aperçu réel en haut | Le haut de la page montre le vrai widget (`WidgetPreview` du widget composé) : 1 widget = sa version moyenne pleine surface, 2 = côte à côte ; mis à jour à chaque toucher | `App/Screens/Spaces/CreateFlow.swift` |
| 2 | Mon quotidien, Fitness : même style ; détourage du coin | La carte garde toujours le même panneau (le « verre » utilisé pour « Maintenant » changeait le style et son flou était coupé carré par le défilement horizontal de la carte) ; « Maintenant » reste en étiquette | `App/Screens/Home/DailySection.swift` |
| 3 | Inscription : masquer la barre des intérêts | Tirets d'étapes masqués sur l'étape des intérêts seulement (VoiceOver garde « Étape x sur n ») | `App/Screens/Onboarding/OnboardingView.swift` |
| 4 | Store : fonds d'écran avant « Styles » | Ordre des rayons : … Thèmes, Fonds d'écran, Styles | `App/Screens/Explore/ExploreView.swift` |
| 5 | Mon quotidien : horaire pour tous, en grand | Carte Planning toujours là (tableau de la semaine, même vide), large par défaut, après les repas et la séance ; retirée par la personne, elle reste retirée | `App/Core/DailyCategories.swift`, `App/Core/DailyBrief.swift` |

## 2. Bugs trouvés par l'audit et corrigés
| Niveau | Bug | Correction |
|---|---|---|
| Critique | Widgets Nutrition, Budget, Fitness (et autres mini-apps) : après minuit, ils pouvaient garder les chiffres d'hier comme ceux d'« aujourd'hui » si iOS retardait le rechargement (fréquent la nuit) | Une image à minuit toujours prévue (`Widgets/DesignProvider.swift`) |
| Important | Carte séance de Mon quotidien en « kg » même en unités impériales | Unité choisie (`Units.loadText`) |
| Important | Programme de sport sans jour choisi : Mon quotidien disait « Crée ton programme » | Carte « Repos », comme dans la mini-app Fitness (`DailyBrief.workoutTile`) |
| Important | Pas de Mon quotidien figés tant qu'on ne quittait pas l'écran (et effacés si une lecture échouait) | Relus à chaque retour dans l'app ; une lecture ratée garde le chiffre du jour (`StepCounter`, `ArdaneApp`) |
| Important | « Dépense rapide » (widget) : un double appui ajoutait 2 dépenses | Même garde de 2 s que l'ajout rapide d'un aliment (`SpaceIntents.swift`) |
| Important | Supprimer une habitude effaçait son historique sans confirmation (le reste de l'app confirme) | Confirmation (`HabitsView.swift`) |
| Important | Date de naissance : valeur de départ différente entre l'inscription (1er janv. 2000) et le Profil (il y a 25 ans), heure gardée côté Profil | Même valeur et même jour sans heure (`ProfileView.swift`) |
| Secondaire | « Contacter le support » restait sur « Copiée » | Revient à l'adresse après 2 s |
| Secondaire | Habitudes de plus de 400 jours : un jour récent pouvait être retiré au lieu du plus ancien | Tri des jours avant de couper (`Content.swift`) |

### Corrigés aussi (audit des mini-apps)
| Niveau | Bug | Correction |
|---|---|---|
| Important | Planning : une tâche ajoutée pendant qu'un autre jour est affiché était datée d'aujourd'hui et disparaissait de la liste | Datée du jour affiché |
| Important | Fitness : graphique des charges en kg pour un utilisateur en livres | Unité choisie |
| Important | Cours supprimé depuis l'espace Études : ses plages restaient dans l'horaire | Même suppression complète que dans Études |
| Secondaire | « J-5 » non traduit (Études, Auto, Voyage) ; ligne d'aliment d'un repas non traduite (« G », « L » en anglais) | Traduits |
| Secondaire | Moyennes de Nutrition affichées exactes alors qu'une donnée manque | Marqueur « ≥ » comme sur les écrans du jour |
| Secondaire | Éditeur d'habitude : une coche faite entre-temps (widget) était effacée à l'enregistrement | Les jours cochés sont gardés |

## 3. Recommandations à valider (non faites : elles changent l'expérience ou demandent ton choix)
**Important**
1. **Confirmer les autres suppressions** : une dépense ou un revenu, « Effacer les tâches terminées », « Supprimer ce repas » partent sans confirmation, alors que widgets, habitudes, séances et cours confirment.
2. **Clavier des nombres sans « Terminé »** (`NumberRow`, formulaires Finances, Fitness, Nutrition) : le pavé décimal ne se ferme qu'en faisant défiler. Proposé : une barre « Terminé » commune.
3. **« Noter Ardane »** (Profil) : sans identifiant App Store, le bouton peut ne rien afficher (iOS limite la fenêtre, rien en TestFlight). Proposé : le cacher jusqu'à la publication.
4. **Tâche « Chaque mois » due le 31** : la suivante tombe le 28 février, puis reste au 28. Une tâche quotidienne en retard de 10 jours doit être cochée 10 fois. Proposé : garder le jour d'origine et caler la suivante sur aujourd'hui au plus tôt.
5. **Créer** : le « + » de l'Atelier fait encore passer le widget à la taille au-dessus tout seul (« Passé en Moyen pour tout afficher »), et l'Atelier compte « 2 sur 4 » pour un widget moyen alors que Créer dit « 2 au plus » ; proposé : « + » seulement s'il reste une place, compteur à la limite de la taille, sinon le message et le choix de taille. `CreateStartView.swift` (ancien départ) et `SpacesView` (ancienne feuille « Changer de widget ») ne sont plus utilisés : à retirer après ton accord.
6. **Textes coupés probables en allemand / portugais** (lignes de listes en une ligne sans réduction : mini-apps, Apple Pay, Business) : proposé une réduction légère du texte.
**Secondaire**
7. Profil : « Rappels d'habitudes » et « Habitudes » ouvrent le même écran ; « Contacter le support » pourrait aussi ouvrir Mail.
8. Mon quotidien ne se remet pas à jour tout seul au changement de jour si l'app reste ouverte (titre matin / soir, ordre des cartes) ; calculs de fenêtres sur 24 h exactes aux changements d'heure.
9. Planning : avec un calendrier chargé d'événements « toute la journée », des rendez-vous horaires peuvent sortir des 12 premiers.
10. Fitness : « 0 / 3 séances » affiché alors que l'objectif de 3 est une valeur par défaut que la personne n'a pas choisie.
11. Finances : graphique des catégories identifié par le nom (deux catégories du même nom se confondent) ; Business : relevé d'abonnements daté plus tard dans le mois exclu du mois en cours.
12. Fiabilité : un fichier de données illisible pourrait être remplacé par un état vide à la première action (une copie est gardée dans `Recovery/`, sans écran pour la restaurer).
13. Premier lancement : l'accueil vide apparaît un instant entre l'écran de lancement et l'inscription ; bouton « Illimité » de Mes widgets un peu petit ; prix « −17 % » non localisé.
14. Mon quotidien : sur la carte séance en demi-largeur, un nom d'exercice long est coupé (« Développé couc… ») ; proposé : réduire légèrement le texte ou passer sur deux lignes.

## 4. Tests exécutés
Tous sur la CI GitHub Actions (simulateur iPhone 402 × 874 points, français) ; rien n'a tourné sur un vrai iPhone cette nuit.

| Série | Commit | Compilation | Tests | Résultat |
|---|---|---|---|---|
| Run 425 (lots 1 et 2) | `1e47926` | simulateur, iPhone non signé, IPA : OK ; contrôles statiques OK | 1 439 réussis, 12 en échec | voir ci-dessous |
| Run 426 (lot 3 + tests corrigés) | `a5bb008` | simulateur, iPhone non signé, IPA : OK ; contrôles statiques OK ; traductions : 5 743 textes, 0 manquant, 0 non traduit | 1 449 réussis, 2 en échec | les 2 dans les tests du Studio, côté test (voir ci-dessous) |
| Version interne Build 427 (Premium, TestFlight) | `cebf414` | Release signée, envoyée, « Internal Only » vérifié | pas de tests (build d'essai) | à essayer sur ton iPhone |
| Run suivant (2 tests du Studio corrigés) | à venir | | | |

Les 12 échecs du run 425, tous analysés :
- 9 tests logiques `ProfileMatrixTests` attendaient l'ancien Mon quotidien (profil vide = aucune carte). La règle a changé à ta demande (horaire de la semaine pour tous) : tests mis à jour, la garantie « rien d'inventé » reste vérifiée (l'horaire vide n'a aucun élément).
- 1 test d'interface de Mon quotidien glissait sur la barre d'onglets : la grande carte Planning pousse maintenant la carte Nutrition plus bas. Le test fait d'abord monter la carte entière.
- 2 tests d'interface du Studio mesuraient l'écran d'Accueil resté derrière le Studio et touchaient un bouton pendant la montée des réglages. Les vérifications de la montée elle-même (poignée, widget qui rapetisse et reste visible) passaient. Aides de test corrigées.

Les 2 échecs du run 426, analysés sur l'arbre d'écran enregistré au moment de l'échec :
- `testSettingsRiseAndComeBackDown` : la place des réglages était mesurée pendant le ressort de la montée (haut à 404 points au lieu de 336 une fois arrêtée) ; la montée elle-même est vérifiée juste avant (poignée, widget rapetissé et visible). Le test attend maintenant la fin du mouvement.
- `testTheStudioChangesTheWidgetAndKeepsItAll` : au lancement, le champ « Nom » est sous le bas de l'écran. L'outil de test le fait défiler lui-même avant de le toucher ; ce défilement fait monter les réglages (comportement voulu) et le toucher tombe à l'ancienne place : le clavier ne s'ouvre pas. Une personne fait défiler puis touche le champ ; le test fait de même. Au run 425, cette étape était passée (aléatoire, selon la vitesse du simulateur).
- Ce ne sont pas des bugs de l'app : aucune ligne de l'app n'a changé pour ces 2 corrections (seulement `UITests/StudioUITests.swift`).

Vérifié sur les captures de la CI : barre des intérêts masquée à l'inscription ; carte Planning en grand en tête de Mon quotidien ; carte séance « Maintenant » dans le même panneau que les autres ; page de choix Moyen (1 et 2 numérotés, les autres grisés avec « Un widget moyen réunit 2 widgets au plus »).

### Tests impossibles cette nuit, et pourquoi
- **Vrai écran d'accueil iOS et rafraîchissement des widgets à minuit** : le simulateur ne suit pas le budget de rechargement d'iOS ; à vérifier sur ton iPhone demain matin (les chiffres d'hier ne doivent plus rester après minuit).
- **Pas (Santé)** : le simulateur n'a pas de capteur ni de données de pas.
- **Achats Premium** : StoreKit réel seulement par TestFlight.
- **Apple Pay (automatisation Raccourcis), accès au Calendrier, notifications reçues** : demandent un appareil et des autorisations réelles.
- **Allemand / portugais** : les tests d'interface tournent en français ; les textes coupés possibles (recommandation 6) n'ont pas été capturés (série `[langs]` non lancée).
- **VoiceOver** : vérifié par les libellés d'accessibilité dans les tests, pas à l'écoute.

## 5. État de stabilité
- **Compilation** : propre à chaque série (simulateur, iPhone, IPA), contrôles statiques verts (sécurité Release : pas de déblocage Premium en version publique), traductions complètes dans les 6 langues.
- **Tests** : 1 449 sur 1 451 au dernier run complet ; les 2 restants sont des défauts de synchronisation des tests d'interface du Studio, corrigés dans les tests (aucune ligne de l'app touchée), à confirmer au run suivant.
- **Données** : aucun format de données sauvegardées changé cette nuit ; les corrections gardent les données existantes (l'horaire de la semaine n'ajoute rien aux fichiers, il est affiché s'il n'a pas été retiré).
- **Risque restant principal** : ce qui ne peut se voir que sur un vrai iPhone (widgets après minuit, pas, achats, Apple Pay) ; à vérifier sur la version interne.
- **Avis** : application stable pour un essai sur iPhone ; la version publique `[testflight]` attend ton accord, après ton essai.
