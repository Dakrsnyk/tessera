---
tags: [ardane, memoire, campagne-2026]
---

# Faits vérifiés pour la campagne 2026 (lus dans le code le 2026-10-31)

Remplace et complète [[Faits-verifies-campagne-v2]] (audit du 2026-10-11, PÉRIMÉ sur les points marqués « CHANGÉ » ci-dessous). Chaque ligne vient du code ; entre parenthèses, le fichier. « À confirmer » = non tranché par le code seul. Règle de la campagne : on ne montre et on ne dit que ce qui est ici ; tout chiffre affiché à l'écran vient d'une capture réelle, jamais d'un texte tapé.

## 0. Statut de l'app (ne pas promettre plus)
- Pas encore publiée sur l'App Store : carte finale « Bientôt sur l'App Store / Coming soon to the App Store », AUCUN badge officiel, AUCUN prix, aucun lien de téléchargement.
- Premium : 3 formules (mensuel, annuel, à vie ; `PremiumConfiguration`) ; essai gratuit de 7 jours sur le mensuel et l'annuel, une fois par compte Apple (`PremiumStore.trialDays`, `PaywallView`). L'essai ne s'affiche que si l'offre existe dans App Store Connect. À confirmer que les produits sont créés et actifs ; donc AUCUNE mention d'essai ni de prix dans les publicités tant que ce n'est pas vérifié sur le paywall réel.
- Marque : thème Saphir seul pour l'interface de l'app (#245B8F clair, #68B5F5 sombre ; `Shared/Theme/AppStyle.swift`) ; icône par défaut = Saphir (`AppIconChoice.main`), logo = le « A » en deux moitiés (voir `docs/marque/`). Tout le kit publicitaire doit être recapturé en Saphir (l'ancien kit est Corail).
- Langues de l'app : fr (source), en, es, de, it, pt-BR, ja. Les publicités sont en FR et EN.

## 1. Ce qui est GRATUIT et ce qui est PREMIUM (source : `PaywallView.comparison`, `AppModel`, code des écrans)

| Élément | Gratuit | Premium |
|---|---|---|
| Widgets enregistrés (« Mes widgets ») | 3 (`AppModel.freeDesignLimit`) ; photos et citations illimitées | illimité |
| Types de widgets | les types non Premium (`WidgetKind.freeKinds`, environ 33 ; chiffre exact affiché par le paywall) | tous (`WidgetKind.offered`) ; 64 lignes Premium dans `KindCatalog`, dont une partie « faite dans sa mini-app » : l'utilisateur dit 63, à lire sur la capture du paywall avant d'écrire un nombre |
| Styles de widgets (57 au total, `ThemeCatalog.all`) | 10 : Minimal, Clair, Sombre, Monochrome, Moderne, Carte, Doux, Compact, Forêt, Glacier | 47 autres (Aurore, Néon, Luxe, Verre, Verre liquide, Papier, Espace, Océan, Synthwave, Éditorial, Noir mat, Blossom, Mars…) |
| Fonds de widget | celui du style | couleur, dégradé, photo, verre (tout sauf « Thème », `BackgroundStyle.isPremium`) |
| Polices de widget | Thème, Standard, Arrondie | Serif, Mono (`FontChoice.isPremium`). CHANGÉ : v2 disait « pas de police » ; il y a un choix de police |
| Couleurs d'accent des widgets | couleurs de base (`Palette.freeAccents`) | couleur libre |
| Couleurs de l'app | 1 : Saphir | 11 autres (Cobalt, Bleu glacier, Aqua, Jade, Pistache, Olive, Ambre, Rubis, Rose, Orchidée, Améthyste) |
| Icônes de l'app (20) | Saphir (par défaut) | 19 autres : Corail, Classique, 16 variantes « Verre »/Aurore… (changer d'icône est Premium) |
| Écrans d'accueil du Store (23 ; `HomeSetups`) | ceux dont tous les widgets/styles sont gratuits | un écran est Premium dès qu'un de ses widgets utilise un type, un style, un fond, une police ou une couleur Premium (`HomeSetup.isPremium`) ; la plupart des 23 le sont |
| Fonds d'écran du Store | 14 gratuits sur 43 (Chantiers, lot 4 du 2026-10-22) | 29 |
| Habitudes suivies | 5 (`freeHabitLimit`) ; pourcentage de régularité 30 jours gratuit | illimité ; régularité 90 jours, meilleure série |
| Bibliothèque d'exercices | « Mes exercices » (écrits à la main) ; séances et séries notées gratuites | toute la bibliothèque (fiche, démonstration animée, technique, alternatives, performances), progression (volume, charges, records) |
| Nutriments | calories, protéines, glucides, lipides (les 4 macros ; `Nutrient.free`) | tous les autres (fibres, sucres, sodium, vitamines, minéraux…) ; historique détaillé 7/30 jours et période libre |
| Finances | le mois courant et les 7 derniers jours (`PremiumHistory`) ; courbe « Mois » | mois précédents, courbe 3 mois / Année, évolution sur six mois |
| Statistiques détaillées de chaque mini-app | — | oui |
| Scanner alimentaire (code-barres et photo de plat) | GRATUIT : aucun verrou Premium dans `FoodScanView`, `ScanRecapView`, `MealPhotoAnalysis` | — |
| Import d'horaire (photo/PDF, sur l'appareil) | gratuit « pour l'instant » (Decisions 2026-10-23) | — |

Widgets précis dont le statut compte pour les images : GRATUITS = Calories restantes, Macros, Prochaine série, Séance du jour, Série d'entraînement, Budget restant, Habitudes, Série d'habitude, Top 3, Tâches, Ma semaine, À venir, Compteur, Horloge, Calendrier, Note, Emploi du temps (timetable), Objectif d'épargne, Dépense rapide. PREMIUM = Repos (restTimer), Ajout rapide (quickFood), Protéines restantes, Repas du jour, Semaine nutrition, Prochain repas, Volume de la semaine, Dépenses par catégorie, Tableau de bord argent (moneyDashboard), L'année en points, Focus, Semaine d'habitudes. Vérifier chaque widget dans `KindCatalog.swift` avant de le mettre dans une image « gratuite ».

Règle de mention : tout plan qui montre une fonction ou un réglage Premium porte la mention « Avec Premium / With Premium » (petite, discrète, 1,2 s mini), et la publicité principale ne laisse jamais croire que tout est gratuit. Un écran d'accueil de 8 widgets ou plus, des styles Aurore/Néon/Espace, des fonds photo, la bibliothèque d'exercices, la progression, les nutriments, les mois d'avant de Finances et le changement d'icône sont des plans Premium. Les 3 widgets gratuits, le thème Saphir, le scanner, les 4 macros, 5 habitudes, séances et séries, Planning, Finances (7 jours) sont gratuits.

## 2. Ce qui a été RETIRÉ ou n'existe pas (à ne jamais montrer)
- Eau : mini-app retirée (2026-10-15) et widget Hydratation « retiré » (`WidgetKind.retired = [.hydration]`). Les lignes `hydration-*` de `scripts/ad_export.txt` ne servent plus. Aucun verre d'eau, aucune « Eau » sur Mon Quotidien.
- Météo : mini-app retirée (politique v3.0 : pas de localisation).
- Reconnaissance de plat par IA en ligne : désactivée (étape B). Ce qui existe : photo d'un plat analysée sur l'iPhone (Vision), résultat étiqueté « Estimation », récapitulatif modifiable avant d'enregistrer (`FoodScanView` doc, `ScanRecapView`). CHANGÉ : v2 disait « photo du repas retirée » ; elle est revenue au lot 8 (2026-10-22). Ne pas dire « IA », ne pas promettre la précision.
- Pas de connexion bancaire, pas de lecture de reçus, pas de catégorisation automatique par banque. La dépense Apple Pay passe par un raccourci Shortcuts que l'utilisateur configure : ne pas la montrer.
- Pas de nombre de pas dans les captures (la carte Pas existe dans Mon Quotidien mais dépend du capteur), pas d'Apple Watch, pas d'iPad.
- Widgets de l'écran d'accueil : la galerie iOS n'offre que « Mes widgets » (widgets que l'utilisateur crée dans Ardane) ; ne pas montrer une galerie iOS pleine d'Ardane de types séparés.

## 3. Écran d'accueil et écran verrouillé
- Écran d'accueil : widgets Petit / Moyen / Grand « Mes widgets » (`QuickWidget`) dessinés dans le Studio ; un widget peut être combiné (plusieurs mini-widgets dans un, `partDesigns`). Widgets interactifs (boutons qui agissent sans ouvrir l'app) : Prochaine série (Série faite), Ajout rapide (Premium), Tâches, Top 3, Habitudes, Compteur, Dépense rapide.
- Écran verrouillé (extension widgets, `ArdaneWidgetsBundle`) : widgets Nutrition (calories, macros, protéines), « Scanner un aliment » (rond et rectangulaire ; touche = Ardane s'ouvre sur le scanner une fois l'iPhone déverrouillé ; le rectangle affiche aussi les calories restantes), Fitness (série suivante, repos, série), Planning/Horaire (« Horaire Lundi / Prochain : Anglais 12 h–15 h »), Tâches, À venir, Habitudes, Finances, Entreprise, Voyage, Auto ; Activité en direct d'entraînement (écran verrouillé et Dynamic Island) et du chrono d'étude ; contrôle « Scanner » du Centre de contrôle (iOS 18).
- CHANGÉ : v2 interdisait « scan depuis l'écran verrouillé ». Aujourd'hui le widget d'écran verrouillé « Scanner un aliment » existe : on peut dire « un geste depuis l'écran verrouillé » mais pas « sans déverrouiller » (iOS demande de déverrouiller ; `ScanFoodWidgets.swift`). Les widgets d'écran verrouillé Nutrition seuls restent en affichage.
- Activité en direct (écran verrouillé) : séance, exercice, « Série 3/4 · 8 × 60 kg », décompte du repos, barre de progression ; boutons Pause/Reprendre, Passer (CHANGÉ : saute la SÉRIE en cours, plus le repos), Série faite, flèche retour (annuler la dernière série) et croix (`WorkoutLiveActivityWidget`). Le jeu d'images démo « live-* » du kit est donc à relire : les boutons ne sont plus « Pause / Passer le repos / Série faite » comme dans v2.
- Précision : le fonctionnement des boutons de l'activité en direct sur un vrai iPhone reste « à vérifier sur l'iPhone » dans Chantiers (jamais prouvé en CI). Les publicités montrent les images d'état avant/après (jeu `live-*`), jamais un doigt qui touche un bouton en prétendant un effet filmé.

## 4. Nutrition (`App/Screens/MiniApps/Nutrition`, `Shared/Domains/Nutrition.swift`, `WeightPlan.swift`)
- Accueil : anneau des calories restantes, barres de macros, repas du jour (déjeuner, dîner, collation…), idées, semaine. COULEURS (décision 2026-10-30, `NutritionColors`) : anneau des calories ORANGE #FF9500, protéines ROUGE #FF3B30, glucides JAUNE #FFCC00, lipides BLEU #0A84FF, quel que soit le thème de l'app ; rouge « dépassé » = l'alerte de l'app.
- Saisie : recherche (suggestions, base intégrée, Fichier canadien sur les éléments nutritifs), feuille de quantité, ajout rapide ; aliments favoris/récents/perso.
- Scanner (une seule vue, aucun mode à choisir) : la caméra lit un code-barres seule (recherche dans les aliments de la personne, puis Open Food Facts, une requête par scan ; sans connexion ou produit inconnu : écran qui le dit et propose de chercher/créer, jamais d'invention) ; le bouton obturateur photographie un plat (analyse sur l'iPhone, photo non gardée). Les deux aboutissent au même récapitulatif modifiable (« Vérifié » = valeur d'une base ; « Estimation » = portion devinée d'après la photo). Accès : bouton « Scanner » des widgets Nutrition Moyen/Grand, bouton de Mon Quotidien, widget d'écran verrouillé, contrôle iOS 18. GRATUIT. Caméra derrière une explication préalable.
- Objectifs (chantier 15, `WeightPlan`, `WeightPlanSummaryView`, `NutritionTargetsCard`) : objectif perdre/maintenir/gagner, poids actuel et cible, durée ; métabolisme de base (Mifflin-St Jeor), dépense selon l'activité, calories adaptées au rythme, protéines/glucides/lipides cohérents, rythme hebdomadaire et date estimée ; refus avec « Objectif impossible à atteindre de manière sûre » et durée alternative ; présenté comme des estimations, jamais un conseil médical. Dire « tes cibles du jour » ou « des estimations », jamais « le bon régime ».
- Widgets : Calories restantes (anneau), Macros (avec « Scanner » en Moyen), Protéines restantes (P), Repas du jour (P), Semaine (P), Série de suivi (P), Prochain repas (P), Ajout rapide (P : Yaourt / Banane / Café qui enregistrent sans ouvrir l'app) ; écran verrouillé : jauge de calories, barres de macros, protéines.
- Premium dans Nutrition : nutriments au-delà des 4 macros, historique 7/30 jours.

## 5. Fitness (`Fitness*.swift`, `ExerciseLibrary.swift`, `CalorieModel.swift`)
- Séance : nom de la routine et minuteur, compteur « 2/14 séries », « Série 3 sur 4 · Développé couché », dernier poids/reps (la donnée « dernière fois » est une donnée d'exercice : Premium), pas à pas des répétitions et de la charge, décompte du repos avec pause/passer, gros bouton « Série faite », liste des exercices avec pastilles de séries faites. Annuler la dernière série. « Passer » saute une série. Calories estimées (`CalorieModel`, poids du profil requis).
- Bibliothèque : environ 160 exercices (163 comptés à l'audit v2 ; à recompter, `ExerciseLibrary.all.count`), chacun avec démonstration animée, vues, technique, alternatives, historique. Premium (« Mes exercices » écrits à la main restent gratuits).
- Programme, historique, semaine, progression (volume sur les semaines, évolution des charges, records, 1RM estimé) : progression Premium.
- Widgets : Prochaine série (G, bouton Série faite), Séance du jour (G), Série d'entraînement (G), Volume de la semaine (P), Repos (P), Ma semaine (G) ; Activité en direct.
- Données démo : séance « Haut du corps », développé couché 4 × 8 à 60 kg ; éviter « 6 / 3 séances » et les charges fractionnaires en gros plan (voir Faits v2).

## 6. Habitudes, Planning, Objectifs (`HabitsView`, `Planning*`, `Productivity.swift`, `Life.swift`)
- Habitudes : cercle à cocher par jour, carrés des 7 jours, série (« 12 jours »), rappels, carte de chaleur (S/M/L). 5 gratuites.
- Planning : jour/semaine/mois/année façon Calendrier Apple, blocs colorés (couleur par événement), récurrence avec exceptions (supprimer une occurrence, modifier une seule), ligne d'aujourd'hui, semaine suivante ; Top 3 du jour (une tâche faite quitte le Top 3 et va dans « Mes tâches réalisées ») ; tâches avec répétition ; projets ; minuteur de concentration ; études (cours, examens) ; import d'horaire par photo/PDF sur l'appareil ; lecture seule du Calendrier iOS. Widget d'écran verrouillé Horaire.
- Objectifs : objectif de poids (Nutrition), objectifs d'épargne (Finances), Top 3, régularité des habitudes. Il n'y a PAS d'écran « Objectifs » unique : à présenter comme « des objectifs dans chaque domaine », pas comme une 5e mini-app. Statistiques détaillées = Premium.
- Mon Quotidien (accueil de l'app) : une page de cartes ordonnées par moment de la journée (Nutrition, Séance du jour, Planning, Habitudes, Pas, Budget, « À ne pas oublier », Top 3), réorganisable. L'Eau et la météo n'y sont plus.

## 7. Finances (`App/Screens/MiniApps/Finances`, `Shared/Domains/Budget.swift`) — saisie manuelle
- Comptes (`Account` : nom, solde, passif ou non) et valeur nette ; revenus (`IncomeEntry`) ; dépenses ; flux fixes (loyer, assurance, abonnements : catégorie trouvée d'après le nom) ; factures à venir (14 jours) ; objectifs d'épargne avec progression ; catégories avec limites ; transactions ; relevé en touchant le solde ; courbe du solde Mois / 3 mois / Année (Mois gratuit, le reste Premium) ; « Reste ce mois-ci ».
- Widgets : Budget restant (G), Dépense rapide (G, interactif), Objectif d'épargne (G), Dépenses par catégorie (P), Tableau de bord argent (P) ; écran verrouillé : budget restant.
- Jamais : connexion bancaire, lecture de reçus, synchronisation automatique.

## 8. Studio, Store, widgets (`App/Screens/Editor`, `Explore`, `MyWidgets`, `Shared/Model`)
- Studio : contenu du widget, style (57), couleur, fond (thème/couleur/dégradé/photo/verre), police, bordure, textures ; aperçu en direct ; widget combiné ; « Ajouter à l'écran d'accueil » guidé.
- Store (Explorer) : 23 écrans d'accueil prêts (fond + widgets + icônes assorties + écran verrouillé, un geste pour installer), 43 fonds d'écran dessinés en code, packs, combos, collections.
- Créer un écran verrouillé (`LockScreenCreator`), Icône de l'app (`AppIconPicker`).
- Chiffres du v2 périmés : « 103 types de widgets » → le catalogue compte 99 lignes dont 1 retirée (Eau) ; « 18 fonds » → 43 ; « 19 icônes » → 20 ; « 16 thèmes complets / 14 palettes » : à ne plus citer, parler de « plus de 50 styles » seulement si la capture du Studio le confirme.

## 9. Couleurs et images (pour la production)
- Interface : Saphir, clair et sombre. Fond de la publicité : noir profond ; accent Saphir #68B5F5.
- Nutrition : anneau ORANGE, protéines ROUGE, glucides JAUNE, lipides BLEU, partout (app, widgets, `Gather`/`Nutrition` Remotion à refaire : l'ancienne roue noire est périmée).
- Les widgets stylés (Aurore, Néon…) gardent leurs propres couleurs ; seuls les anneaux Nutrition gardent les 4 teintes.

## 10. Points d'incertitude (à trancher ou lire sur une capture)
1. Nombre exact de types de widgets gratuits/Premium (33/63 ou 64) : lire sur le paywall recapturé.
2. Nombre d'exercices (`ExerciseLibrary.all.count`).
3. Produits in-app et essai de 7 jours actifs dans App Store Connect ? (aucune mention tant que non vérifié.)
4. Statut de chaque widget d'écran verrouillé (gratuit ou Premium) : la règle est `kind.isPremium` du widget affiché, à vérifier cas par cas.
5. L'activité en direct n'a jamais été vérifiée sur un iPhone pour les boutons (voir Chantiers 2026-10-15/17).
6. Les noms français exacts des écrans (Mon Quotidien, « Série faite »…) viennent des captures : toute légende doit être relue contre la capture.
