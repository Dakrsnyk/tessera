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

## 3. Recommandations à valider (non faites : elles changent l'expérience)
(complété en fin de mission)

## 4. Tests exécutés
(complété avec les résultats de la CI)
