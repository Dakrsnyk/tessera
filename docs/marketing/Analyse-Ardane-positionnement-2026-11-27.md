# Analyse complète d'Ardane : ce qu'elle fait, ce qu'elle remplace, où elle se place, ce qu'elle peut rapporter (2026-11-27)

Basée sur le code d'Ardane (inventaire de `scripts/graph_map.py`, build 627) et sur des sources publiques citées. Les chiffres de revenus sont des projections, pas des promesses.

## 1. Ce qu'Ardane sait faire (inventaire du code)

### Le cœur unique : l'écran d'accueil comme tableau de bord de sa vie
- **105 types de widgets** (`WidgetKind`), en petit, moyen, grand et écran verrouillé (circulaire, rectangulaire, en ligne).
- **Widgets combinés** : jusqu'à 2 widgets dans un moyen, 4 dans un grand (Calories + Séance + Tâches dans un seul widget).
- **504 styles** : 4 gratuits, 500 Premium en 20 familles (Aura, Prestige, Luxe, Chrome, Verre, Girly, Pixel, Gaming, Cyberpunk, Y2K, Vintage, Rétro, Néon, Minimaliste, Brutal, Nature, Illustré, Sport…), « Mes styles » réutilisables sur plusieurs widgets.
- **Studio** : aperçu réel, « Sur mon écran » (le widget parmi les icônes), couleurs, texte, fond, bordure, graphique, densité.
- **Store** : 23 écrans d'accueil prêts (fond, widgets, icônes, écran verrouillé assortis), 43 fonds d'écran dessinés, 34 packs, saisons (Halloween, Noël), mosaïques de widgets par mini-app.
- **Widgets interactifs** (iOS 17) : cocher une tâche ou une habitude, ajouter un aliment ou une dépense, compteur, chrono d'étude, sans ouvrir l'app.
- **Activité en direct** (écran verrouillé et Dynamic Island) : séance de sport avec « Série faite », repos minuté, annuler ; chrono d'étude.
- Modes Clair (iOS 26) et Teinté (iOS 18) gérés ; Control iOS 18 « Scanner un aliment ».

### Les mini-apps : chacune est une vraie app
| Mini-app | Ce qu'elle fait | App de référence qu'elle remplace en partie |
|---|---|---|
| **Nutrition** | Calories et macros, besoins calculés (Mifflin-St Jeor, protéines g/kg, micronutriments DRI), objectifs bornés pour la sécurité (mineur, grossesse, IMC), base FCÉN + USDA (≈ 5 600 aliments sourcés) + Open Food Facts, **scanner code-barres et photo de plat** (segmentation et classification Core ML sur l'appareil, contexte du repas), aliments perso, idées de repas, historique | MyFitnessPal, Cal AI |
| **Fitness** | Programme de la semaine, **séance en direct** (série, charge, repos, notification de fin de repos), **244 exercices avec démonstration animée en 3D** et technique en 7 langues, progression par muscle, records, calories actives (MET), pas du jour | Hevy, Strong, Fitbod |
| **Planning** | Calendrier jour/semaine/mois/année, tâches répétées, Top 3, projets, habitudes (séries, rappels), lecture du calendrier iOS | Todoist, Structured, Habitify |
| **Études** | Cours, examens, devoirs, révisions par cartes, chrono de concentration en direct, **scanner d'horaire de cours par photo** (sur l'appareil) | MyStudyLife, Forest |
| **Finances** | Solde, reste du mois, catégories avec limites, factures, épargne, valeur nette, relevé, **dépenses Apple Pay automatiques** (Raccourcis), dépense rapide depuis un widget | YNAB, Copilot (sans connexion bancaire) |
| **Business** | Ventes, résultats, récurrent, **Stripe en lecture seule**, import CSV, devises | Tableaux de bord Stripe, ChartMogul |
| **Placements et marchés** | Cours crypto (CoinGecko), actions (Finnhub), données SEC des sociétés | Apps de bourse |
| **Voyage, Auto** | Programme et budget en devise ; pleins, entretien, échéances | Apps dédiées |
| **Photos et citations** | 1 à 12 photos, citations typographiées | Widgetsmith, Locket |

### Le reste de l'expérience
- **Mon Quotidien** : un accueil qui montre ce qui compte maintenant (repas, séance, habitudes, planning, budget), réorganisable comme l'écran d'accueil d'iOS.
- Rappels intelligents et encouragements limités (2 par jour au plus, 8 h–22 h).
- **Confidentialité** : tout est stocké sur l'iPhone, pas de compte, pas de serveur ; sauvegarde dans un fichier.
- **7 langues** (fr, en, es, de, it, pt-BR, ja).
- IA sur l'appareil (Foundation Models, iOS 26) pour les phrases des widgets.

## 2. Ce que la personne remplace, et ce que ça coûte ailleurs
| Besoin | App spécialisée | Prix public relevé |
|---|---|---|
| Nutrition | MyFitnessPal Premium | 79,99 $/an [blog tiers, avril 2026] |
| Budget | YNAB | 109 $ (période non étiquetée sur l'App Store) |
| Widgets et thèmes | Widgetsmith / Top Widgets / Color Widgets | 19,99 / 34 / ≈ 35 $/an |
| Sport, habitudes, tâches, études | Hevy, Habitify, Todoist… | non relevés ici (à vérifier) |

Total des seuls prix vérifiés : **≈ 210 à 225 $/an** pour 3 apps, contre **59,99 $/an** pour Ardane (prix actuel) ou 39,99 $ (prix recommandé par l'analyse ASO). Argument de vente : « 5 apps en une, pour le prix d'une ».

## 3. Est-ce vraiment unique ? (réponse honnête)
**Non au sens strict, oui dans sa combinaison.**
- Il existe des apps « tout-en-un de la vie » récentes : The Life App, LifeShift 360, Vitae, Multi, DayKit, Tonic Widget, HabitGenius (14 widgets). Elles sont **petites, récentes, souvent sans notes**, avec quelques widgets et un suivi léger (pas de scanner de plat, pas de bibliothèque d'exercices animée, pas d'activité en direct, pas de Stripe).
- Les apps de widgets (Widgetsmith, Color Widgets, Top Widgets : des centaines de milliers de notes) font **de l'apparence** : heure, météo, photo, citation. Elles n'ont **pas tes données de vie**.
- Les apps spécialisées (MyFitnessPal, Hevy, YNAB) ont **la profondeur** mais **un seul domaine** et des widgets simples non personnalisables.

**Ardane est la seule trouvée qui réunit les trois** : profondeur de suivi (niveau des apps spécialisées en nutrition et sport), largeur (11 domaines), et personnalisation de l'écran d'accueil (niveau Widgetsmith, en plus riche : 504 styles, combinés, Store d'écrans complets). Aucun leader n'occupe ce créneau : c'est une vraie ouverture, mais le marché n'est pas « vide » et le message doit être clair pour ne pas être rangé parmi les petites apps « tout-en-un ».

## 4. Forces et faiblesses
**Forces**
1. **Le résultat se voit** : l'écran d'accueil est l'endroit le plus regardé du téléphone (des dizaines de fois par jour). Chaque coup d'œil rappelle Ardane : rétention naturelle que n'ont pas les apps qu'il faut ouvrir.
2. **Très visuel, donc très « TikTok »** : un écran d'accueil avant/après se comprend en 2 secondes (le panel simulé a classé « avant/après » parmi les 3 meilleures pubs).
3. **Profondeur réelle** en nutrition et sport (scanner, 244 exercices animés, séance en direct) : crédible face aux spécialistes.
4. **Confidentialité** : rien ne quitte l'iPhone, pas de compte. Argument fort face à des apps qui revendent ou centralisent les données.
5. **Coût marginal quasi nul** : calcul sur l'appareil, pas de serveur ; la marge après Apple est presque entière.

**Faiblesses**
1. **Trop de choses à expliquer** : le risque n° 1. « Widgets + nutrition + sport + budget + études » se perd en 3 secondes. Il faut un message, pas une liste.
2. **Premier widget long** : 12 à 19 touchers mesurés par l'audit, et le geste iOS d'ajout d'un widget est peu évident.
3. **Pas de connexion bancaire** (choix de confidentialité) : moins fort que YNAB ou Copilot pour les fans de budget.
4. **Précision du scanner de plat non mesurée publiquement** face à Cal AI.
5. **Pas encore en vente** ; aucune note, aucun avis ; un seul développeur ; pas d'Android.
6. **Gratuit généreux** (3 widgets, 5 habitudes, mini-apps utilisables) : bien pour le bouche-à-oreille, mais conversion faible (≈ 2 % selon le marché) si l'essai Premium n'est pas poussé au bon moment.

## 5. Positionnement recommandé
- **Une phrase** : « Ton iPhone, ta vie : un écran d'accueil qui suit tes repas, tes séances, ton argent et tes journées, dans ton style. »
- **Le visuel** : toujours l'écran d'accueil complet (avant/après), puis un geste réel (cocher, scanner, « Série faite »), puis le changement de style.
- **Trois portes d'entrée** pour les pubs, une par public : esthétique (styles et écrans prêts), sport et nutrition (scanner, séance en direct sur l'écran verrouillé), étudiants et organisation (horaire scanné, planning). Chacune finit sur « et tout le reste dans la même app ».

## 6. Modèle économique : leçon de MyFitnessPal et de Cal AI
| | Gratuit généreux (MyFitnessPal) | App bloquée (Cal AI) | **Hybride recommandé pour Ardane** |
|---|---|---|---|
| Principe | Gratuit pour tous, Premium pour les plus motivés | Rien sans abonnement ou essai | Parcours d'accueil engageant (objectif, intérêts), puis **essai de 7 jours de tout Ardane proposé avant le premier widget**, « Plus tard » possible ; version gratuite gardée mais clairement limitée |
| Conversion installés → payants | ≈ 2 % (marché) | ≈ 10 % (RevenueCat, apps bloquées) | **≈ 3,5 à 5,5 %** (hypothèse) |
| Volume et bouche-à-oreille | Très fort | Faible | Fort |
| Temps avant d'être rentable | Long, demande des millions d'utilisateurs | Court | Court à moyen |

Ardane a déjà presque tout pour l'hybride : l'offre de fin d'inscription existe (`OnboardingOffer`, annuel et mensuel côte à côte, 7 jours gratuits). Il reste à la placer au moment le plus fort (juste après avoir vu ses vrais widgets dans son style), à tester l'ordre des questions et le prix (Cal AI a gagné +31 % de conversion par des tests continus).

## 7. Ce que ça change dans les revenus
Même projection que `Projection-croissance-36-mois-2026-11-27.md`, en dollars canadiens (1 $ US ≈ 1,38 $ CA), 1 000 $ CA de pub par mois (≈ 1 million de vues sponsorisées), 1 vidéo organique par jour, bouche-à-oreille, abonnés suivis par cohorte. Seule différence : la conversion de l'hybride.

| Scénario central | Gratuit généreux (2 → 3,5 %) | **Hybride (3,5 → 5,5 %)** |
|---|---:|---:|
| Mois 1 après pub | −699 $ | **−473 $** |
| Pub entièrement remboursée | mois 9 | **mois 5** |
| Année 1 après pub | +2 547 $ | **+11 131 $** |
| Année 2 après pub | +23 605 $ | **+44 090 $** |
| Année 3 après pub | +46 897 $ | **+80 644 $** |
| Revenu par jour fin d'année 1 | 65 $ | **103 $** |
| Revenu par jour fin d'année 3 | 198 $ | **312 $** |
| Abonnés au mois 36 | 814 | **1 280** |

Les trois scénarios avec l'hybride :
| | Prudent | Central | Optimiste |
|---|---:|---:|---:|
| Année 1 après pub | −4 998 $ | +11 131 $ | +59 716 $ |
| Année 3 après pub | +7 269 $ | +80 644 $ | +517 179 $ |
| Revenu par jour fin d'année 3 | 59 $ | 312 $ | 1 887 $ |
| Pub remboursée | mois 30 | mois 5 | mois 1 |

Lecture : avec l'hybride, l'objectif de 50 à 100 $/jour est atteint **dans l'année 1 en central**. Ce qui décide le scénario réel : la part des vues sponsorisées qui installent (0,025 % prudent, 0,05 % central, 0,08 % optimiste) et la part des installés qui paient.

## 8. Plan d'action (ordre)
1. **Avant tout** : signer le contrat « Paid Applications », publier Ardane sur l'App Store, remplir « App Privacy ».
2. **Hybride** : placer l'essai de 7 jours après l'aperçu de ses propres widgets ; prix annuel recommandé 39,99 $ US (à tester contre 49,99 $ avant de descendre) ; mensuel 4,99 $.
3. **Premier widget en moins de 10 touchers** et guide visuel du geste d'ajout à l'écran d'accueil.
4. **Budget de 1 000 $ CA par mois réparti** (proposition) : 500 $ en vidéos sponsorisées (les 2 meilleures organiques du mois), 400 $ pour 3 ou 4 micro-créateurs à public précis (fitness, esthétique, études : la méthode Cal AI), 100 $ de tests (accroches, pays).
5. **Mesurer dès la semaine 1** avec des liens de campagne App Store Connect (`ct=`) : vues → installations → essais → payants. Remplacer les hypothèses du modèle par ces chiffres après 4 semaines.
6. **Une pub par porte d'entrée**, honnête sur le Premium (le panel a relevé « Série faite » montré comme gratuit).

## 9. Ce qui reste à vérifier
- Précision réelle du scanner de plat (banc d'essai interne) face à Cal AI.
- Prix des apps de sport, d'habitudes et de tâches (non relevés ici).
- Conversion réelle de l'hybride : seule une mise en vente la donnera.
- Les apps « tout-en-un » citées sont jugées sur leurs fiches App Store (descriptions des développeurs), pas sur des tests.

## Sources
- Inventaire : `scripts/graph_map.py` (MODULES), build 627.
- Concurrence widgets et prix : `docs/marketing/Fiche-App-Store-ASO-2026-11-27.md` (Widgetsmith, Color Widgets, Top Widgets, MyFitnessPal, YNAB, sources App Store et Adapty).
- Apps « tout-en-un » : [The Life App](https://apps.apple.com/app/id6775685437), [LifeShift 360](https://apps.apple.com/app/id6759218239), [Vitae](https://apps.apple.com/app/id6763250273), [Multi](https://apps.apple.com/app/id6800831904), [DayKit](https://apps.apple.com/app/id6759175889), [Tonic Widget](https://apps.apple.com/us/app/id6754718714), [HabitGenius](https://apps.apple.com/us/app/-/id6466812469), [Progressio](https://apps.apple.com/app/id6740454461).
- Cal AI : [Netinfluencer](https://www.netinfluencer.com/cal-ai-founder-zach-yadegari-breaks-down-the-influencer-playbook-behind-his-apps-growth/), [Superwall](https://superwall.com/case-studies/cal-ai), [Latka](https://getlatka.com/blog/how-cal-ai-achieved-35-million-revenue-in-just-one-year), [Funnelfox](https://blog.funnelfox.com/cal-ai-influencer-marketing/).
- MyFitnessPal : [Wikipedia](https://www.Wikipedia.com/wiki/MyFitnessPal), [TechCrunch](https://techcrunch.com/?p=1152052), [Rigorous Themes](https://rigorousthemes.com/blog/myfitnesspal-revenue-and-user-statistics/).
- Conversion : [RevenueCat, durée d'essai et types de paywall](https://www.revenuecat.com/blog/growth/free-trial-length), [State of Subscription Apps 2023](https://revenuecat.com/state-of-subscription-apps-2023).
- Coûts de pub : [Singular T2 2026](https://www.singular.net/quarterly-report-2026-q2/), [Influee](https://influee.co/ie/blog/tiktok-ads-benchmarks).
