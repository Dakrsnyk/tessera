---
tags: [ardane, memoire]
---

# Chantiers

Retour : [[Memoire]] · Décisions : [[Decisions]]

## 2026-10-11 : passage à l'app Claude Desktop sur le PC Windows de l'utilisateur

Les sessions se font désormais en local, dans le dossier `tessera` : les notes écrites ici sont tout de suite sur le disque, sans Pull. Faire un Pull avant de commencer si une session cloud a poussé entre-temps. Particularités Windows : voir [[Pieges-connus]].

Terminé juste avant : la carte Obsidian (vue graphique en grappes, canvas au format d'Obsidian) et cette mémoire.

## En cours : campagne publicitaire v2 (reprise le 2026-10-11, en local sur le PC Windows)

Demande : une publicité de niveau Apple / Nike en motion design sur la vraie interface, voix off anglaise féminine, 1080 × 1920 à 60 i/s, 7 formats (principal 45–60 s, 30 s, 15 s, 6–10 s, Fitness, Nutrition, Personnalisation). « Une seule publicité exceptionnelle plutôt que plusieurs ordinaires. »

- Brief complet : [[Brief-campagne-v2]] · ce qui existe vraiment dans l'app : [[Faits-verifies-campagne-v2]] · direction retenue : [[Concept-THE-OPENING]].
- Fait :
  - Kit d'éléments réels : export DEBUG `AdExport` ([[AdExport (swift)]]), scènes [[AdShotsUITests (swift)]], listes `scripts/ad_export.txt` et `scripts/ad_screens.txt`. Le tag de commit `[adkit]` relance l'export en CI (PNG sans perte des widgets dans tous les styles, écrans, activité en direct, démos d'exercices image par image).
  - Voix off : script et minutage dans [`scripts/ad2/vo_spec.json`](../../../scripts/ad2/vo_spec.json), génération par [`scripts/ad2/vo.py`](../../../scripts/ad2/vo.py) (Kokoro-82M, voix af_heart, « Ardane » prononcé ar-DAHN, vérification par reconnaissance vocale). 2026-10-11 : films `main` (17 lignes, 29 s, toutes dans leur créneau) et `s8` générés dans `pub/vo/` ; écoute à valider par l'utilisateur (« Your week », « Ardane » seul).
  - Outils installés sur le PC (2026-10-11) : `~/ardane-tools` (venv Python 3.12 : torch CPU, Kokoro, faster-whisper ; Playwright + Chromium ; ffmpeg par winget). Procédure : [`scripts/ad2/README.md`](../../../scripts/ad2/README.md). Rendu Chromium 1080 × 1920 : ~130 ms par image (≈ 8 min pour 60 s à 60 i/s sur une scène simple).
  - Moteur (2026-10-11) : Remotion 4.0.534 dans `~/ardane-tools/film`, sources dans `scripts/ad2/film/` (`film_sync.py`). Fait : la ligne, le logo, le texte qui s'ouvre depuis la ligne, le grain, la scène `Close` (plans 24–25, 53–58 s, signature sonore D5 · silence · A5 par `scripts/ad2/synth.py`) ; rendu `pub/film/close.mp4` (5 s en 1 min 34). Voix des 7 films générée.
  - 2026-10-11 (suite) : téléphone 3D (`Phone3D`), scènes `Opening` (plans 1-3), `LockScreen` (11-13), `Daylight` (14 : une étiquette à code-barres seule dans la lumière, pas de produit), `Close` (24-25) ; partition complète `scripts/ad2/score.py` (58 s) et mixage final `scripts/ad2/mix.py` (−14 LUFS, voix 8 à 19 dB au-dessus de la musique) → `pub/film/`. Run `[adkit]` 169 lancé (accueils héros sur 6 décors via `rows=`, écrans et scènes en sombre, démos sombres) : **récupérer `adkit/` de ci-report dans `pub/kit/` dès qu'il finit, avant tout push**.
  - Piège Remotion : un `ThreeCanvas` ne se redessine qu'au changement d'image ; ne le monter qu'une fois images et police prêtes. Verre du téléphone en matériau non éclairé (l'environnement de scène ignore `envMapIntensity`).
- 2026-10-11 (soir) : **film principal 58 s terminé** (`pub/film/ardane-main-58s.mp4`, contrôlé : 3 480 images, aucune image figée en mouvement ni noire). Déclinaisons montées depuis `film/src/films/cuts.json` (segments de scènes + remappage du temps : caméra accélérable, interface toujours à 1×) avec leur propre musique (`score.py`, sections) et mixage (`mix.py cut <film>`, bruitages recalés par l'inverse du remappage) : 30 s, 15 s (Mon Quotidien recollé par `stitch.py`), 8 s (la ligne qui s'ouvre), Fitness 20 s, Personnalisation 24 s, Nutrition 20 s (apparence claire, attend `home-hero-light`, `lock-etudes`, `quickFood` du run 172).
- 2026-10-11 (nuit) : **sept films livrés** dans `pub/film/` (contrôlés par `scripts/ad2/qc.py` : images exactes, aucune image noire, −14 LUFS) : `ardane-principal-60s`, `ardane-30s`, `ardane-15s`, `ardane-08s`, `ardane-fitness-20s`, `ardane-nutrition-20s`, `ardane-personnalisation-24s`. Chacun s'ouvre sur une accroche et montre la personnalisation des widgets (Studio).
- Reste éventuel : Studio en apparence sombre dans le film principal (run 173 : captures `studio-*-dark`), styles de l'ajout rapide pour le film Nutrition (même run) ; écoute de l'utilisateur (« with Ardane » transcrit « with our Don »).
- Rendus dans `pub/` (ignoré par Git) : ils restent sur le disque, contrairement à une session cloud.

## Carte du projet (graphify) — 2026-10-12

- Fait : la carte Obsidian est remplacée par `scripts/graph_map.py` (graphify + visionneuse `scripts/graph/viewer.html`) : un nœud par fichier, 8 catégories ou les modules, Filtres / Groupes / Affichage / Forces / Animer, recherche, fiche au clic. Ouvrir `graphify-out/index.html`, ou le serveur « graphe » (mise à jour en direct).
- Version téléphone (claude.ai, privée) : https://claude.ai/artifact/FQBb8SpokSP57Hu12asBmV ; c'est un instantané, à republier après les gros changements (`--artifact`).
- Mise à jour après chaque commit par le hook git post-commit (installé sur ce PC ; sur un nouveau clone : `python3 scripts/graph_map.py --install-hook`).

## TestFlight — 2026-10-15

- L'utilisateur a acheté le compte Apple Developer. Préparé : tag CI `[testflight]` (Release signée, envoi TestFlight), signature manuelle en Release, `scripts/signing/ardane_signing.sh` et `scripts/signing/README.md`.
- Fait par l'utilisateur le 2026-10-15 : identifiants, certificat, profils, fiche App Store Connect, clé API (Key ID `YPPQ3U2GKY`), les 8 secrets GitHub (Team ID `WD538Z3CL9`). Premier envoi réussi le même jour : build 186 (version 1.0) envoyé sur App Store Connect (certificat « Apple Distribution: Mathys Lecointre (WD538Z3CL9) », profils valides jusqu'au 2027-10-15).
- « Test Information » de TestFlight (description, courriel de retour, infos pour la revue bêta) : seulement pour les testeurs externes ; pas nécessaire pour l'utilisateur, testeur interne (2026-10-15).

## Série de 13 demandes — 2026-10-15

- Fait (détail dans [[Demandes]]) : besoins nutritionnels calculés, « Mes infos » dans chaque mini-app, ordre de Fitness et ajout direct à la séance, Premium (statistiques détaillées et bibliothèque complète), Planning (création au toucher, pincement jour/semaine/mois/année), Business (Stripe en lecture seule et import CSV), mini-app Photos et citations, retrait de l'Eau, langue et fuseau horaire indépendants, boutons de l'activité en direct iPhone verrouillé, galerie de widgets réduite à « Mes widgets ».
- Tests : run 191 (commit 84b1fe4), 200 tests logiques réussis, 0 échec (dont 22 de `OctoberRequestsTests` et 5 de `LanguageTimeZoneTests`) ; build 192 (version 1.0) envoyé sur TestFlight (run 192). UITests et captures non relancés pour cette série.
- Suite (même jour) : carte Planning de Mon Quotidien touchable, exercices récents masqués, carte « Photos et citations » dans Créer ; run 193 compile, run 194 : 200 tests réussis, puis envoi TestFlight.
- Série du soir (Premium Fitness et Nutrition, widgets posés stables, scan sur l'écran verrouillé, icône Premium, photo derrière une citation, Mon Quotidien) : run 196 compile, run 197 : 229 tests réussis, 0 échec ; puis envoi TestFlight. À vérifier sur l'iPhone : un widget posé ne change plus quand on en crée un autre de même taille (défaut `defaultResult()`), le contrôle « Scanner un aliment » (iOS 18).
- À vérifier sur l'iPhone (impossible en CI) : boutons de l'activité en direct iPhone verrouillé ; galerie des widgets (les anciens widgets posés d'un autre type que « Mes widgets » disparaissent de l'écran d'accueil : les reposer par « Mes widgets ») ; pincement du calendrier ; Stripe avec une clé `rk_test_` puis `rk_live_`.
- Reste à faire par l'utilisateur : produits in-app dans App Store Connect (`com.dakrsnyk.tessera.premium.monthly/yearly/lifetime`) et contrat « Paid Applications » pour tester Premium par TestFlight ; la politique v2.1 (Photos et Stripe) est republiée sur l'artifact de `PremiumConfiguration.privacyURL`, mais cette page est privée : la partager « toute personne disposant du lien » (menu Partager) avant la soumission à l'App Store.
- Plus tard : Shopify, QuickBooks, Stripe Connect par un petit serveur OAuth (architecture dans `docs/integrations-business.md`).

## Premium en test — 2026-10-16

- 2026-10-16 : version interne Premium débloqué (build 200, tag `[interne]`, « Internal Only » vérifié par l'API). L'utilisateur veut un nom de vendeur différent et une entreprise : plan dans `docs/entreprise-et-nom-vendeur.md` (société par actions, D-U-N-S, migration du compte). Ne pas envoyer les formulaires fiscaux ni la banque du compte individuel en attendant.
- Guide pas à pas : `docs/guide-premium-testflight.md` (contrat Paid Apps, impôts, banque, création des 3 produits, test perso, testeurs externes, message pour les amis). En attente de l'utilisateur.

## Série du 2026-10-16 : devises, cours, 3 widgets gratuits, alphabet, salle, mode Clair

- Fait (détail dans [[Demandes]]) : run 201 compile la vague 1, run 202 les corrections et le mode Clair/Teinté ; run 203 : 278 tests logiques réussis, 0 échec (48 nouveaux : `CurrencyConversionTests`, `LivePricesTests`, `FreeWidgetLimitTests`, `SectionIndexTests`, `ScheduleRoomTests`, `AccentedRenderingTests`) ; build 204 (version 1.0) envoyé sur TestFlight (run 204, version normale, Premium non débloqué). Puis build 205 interne, Premium débloqué (run 205, « Internal Only » vérifié par l'API) : c'est lui qui s'installe ; le 204 reste dans TestFlight › Versions précédentes pour tester la version gratuite.
- À vérifier sur l'iPhone : widgets en Clair (clair et sombre) et Teinté (grand « Horaire de la semaine », Habitudes, Focus, Photos, Citation) ; import d'un CSV en USD (aperçu converti ; en mode avion : erreur et « Importer sans conversion ») ; widget Crypto qui avance seul ; Liste de suivi en petit sur un petit iPhone.
- Hypothèse annoncée à l'utilisateur : les citations sont illimitées comme les photos.
- Connu, à traiter à part : en mode En veille de jour (fond retiré, en couleur), les palettes à texte foncé (Jade, Sable…) s'affichent en texte foncé sur noir.

## Série du 2026-10-17 : retour en arrière Fitness, chrono d'étude en direct, encouragements, CSV

- Fait (détail dans [[Demandes]]) : run 208 compile ; run 209 : 323 tests logiques réussis, 0 échec (dont `WorkoutUndoTests`, `StudyLiveActivityTests`, `EncouragementsTests`, `BusinessCSVTests` avec le fichier de l'utilisateur) ; build 210 envoyé sur TestFlight (version normale), puis build 211 interne Premium débloqué (« Internal Only » vérifié).
- À vérifier sur l'iPhone : flèche retour et croix sur l'écran verrouillé et la Dynamic Island ; activité en direct du chrono d'étude ; encouragements (réglage dans Profil › Rappels, notifications autorisées) ; réimport du CSV de test (7 dépenses, 5 revenus).

## Suite du 2026-10-17 : relevé Finances, suppression d'une séance

- Run 214 compile ; run 216 : 331 tests réussis, 0 échec (le run 215 avait perdu le réseau à l'envoi du rapport, puis un test du relevé attendait un mauvais solde) ; build 217 sur TestFlight (normal), puis build 218 interne Premium (« Internal Only » vérifié).
- À vérifier sur l'iPhone : toucher le solde (relevé), ligne « Dépenses fixes », Mes infos de Finances allégé, suppression d'une séance puis la refaire.

## Série du 2026-10-22 : « Passer » une série, doubles appuis, haptique, ajout rapide Nutrition

- Fait (détail dans [[Demandes]] et [[Decisions]]) : « Passer » saute la série en cours (`WorkoutSession.skipped`), doubles appuis ignorés par la position attendue (`WorkoutPosition`), vibration légère seulement app au premier plan (`ButtonFeedback`), pas de doublon à l'ajout rapide Nutrition (`NutritionState.quickLog`). Tests : `Tests/WorkoutSkipTests.swift` (18). Run 219 : compile (statique et simulateur), l10n à jour, 5 400 textes.
- La passation du 2026-10-22 disait ce chantier « non commencé, arbre propre » alors que le code existait déjà dans l'arbre : un agent s'était arrêté sur la limite d'usage après avoir tout écrit. Toujours lancer `git status` avant de croire une passation.
- Relecture indépendante (`code-reviewer`) : aucun bloquant ; un défaut mineur corrigé (`quickLog` cherchait le dernier élément du tableau, pas la date). Deux choix laissés à l'utilisateur : « Passer » ne passe plus le repos (l'intent `SkipRestIntent` n'est plus câblé) ; dans un petit widget à 2 boutons, la flèche « Annuler » prend la place de « Passer » une fois une série faite.
- Équipe multi-agents : `CLAUDE.md` (section « Équipe multi-agents ») et `.claude/agents/` (7 agents) sont versionnés depuis ce jour.
- Améliorations : trois maquettes de l'accueil (A évolution fidèle, B minimaliste premium, C dashboard dynamique) puis une quatrième, D (mixte A + C), clair et sombre, dans `pub/maquettes-accueil/` (non versionné, source `maquettes.html`, rendu `render.js`). L'utilisateur a choisi D. `docs/memoire/Brief-ameliorations.md` (cité par Demandes) n'existe pas ; le § 11 n'apparaît nulle part ; le scanner intelligent est reporté (`docs/references/README.md`).
- Tests : run 220 (`[unit]`) : 350 tests réussis, 0 échec, dont les 19 de `WorkoutSkipTests`.
- Accueil D codé (`App/Screens/Home/DailySection.swift`, `App/Core/DailyBrief.swift`, `Tests/DailyBriefTests.swift`) : run 221 compile. Ce qui diffère de la maquette, faute de donnée : pas de « dans 18 min » (une séance n'a pas d'heure), la pastille « Maintenant » suit le moment de la journée ; la carte s'appelle « Budget » (pas « Finances ») ; la courbe n'apparaît qu'avec des dépenses ; la série de jours n'apparaît qu'avec une série.
- Run 222 (`[unit]`) : 352 tests réussis, 0 échec (dont les 2 de l'accueil). Build 223 (version 1.0, normale, Premium non débloqué) envoyé sur TestFlight (run 223) avec Skip et l'accueil D. Pas de version interne envoyée : à lancer seulement sur demande de l'utilisateur.
- Retour de l'utilisateur sur le build 223 (capture de l'iPhone) : le dégradé de la séance était trop fort et Nutrition n'en avait pas (elle dessine son propre fond, hors `DayCard`). Corrigé : un seul modificateur `CategoryTint` pour toutes les cartes, un peu plus doux, plus de halo (le pager rognait l'ombre en rectangle). Run 225 compile. Build 224 : interne, Premium débloqué, « Internal Only » vérifié (même code que le 223). Build 226 : interne, Premium débloqué, avec le dégradé corrigé (« Internal Only » vérifié, run 226) : c'est celui qui s'installe ; le 223 (normal, ancien dégradé) reste dans TestFlight › Versions précédentes.
- Pas encore fait de l'accueil : le reste des lots (voir `docs/PASSATION.md`).
- À vérifier sur l'iPhone : l'accueil en clair et en sombre (dégradés, pastille, anneaux, courbe) ; « Passer » sur l'écran verrouillé, la Dynamic Island et un widget ; double appui rapide sur « Série faite » (une seule série) ; la vibration dans l'app ; ajout rapide Nutrition touché deux fois.
- Limites iOS : un bouton de widget ou d'activité en direct ne fait vibrer l'iPhone que si l'app est au premier plan.

## Exécution autonome des 8 lots — 2026-10-22 (terminée, à vérifier sur l'iPhone)

Consigne de l'utilisateur (haut de [[Demandes]]) : réaliser les lots dans l'ordre, sans accord entre deux lots ; par lot : agents, relecture `code-reviewer`, `check_swift.py`, `[check]` puis `[unit]` ; `[testflight]` puis `[interne]` une seule fois après le dernier lot, seulement si tous les `[unit]` sont verts. Le § 6 (« Faire mes repas ») n'est pas dans les 8 lots : laissé. `Brief-ameliorations.md` n'existe pas : les lignes de Demandes ont fait office de cahier des charges.

- TestFlight : build 230 (version 1.0, normale, Premium non débloqué, run 230) envoyé le 2026-10-22 avec les 8 lots ; build 231 interne (Premium débloqué, « Internal Only » vérifié par la CI, run 231) : c'est celui qui s'installe ; le 230 reste dans TestFlight › Versions précédentes.
- Blocage rencontré : le dépôt était privé (le run 39822617200 a échoué en 14 s : facturation macOS). L'utilisateur l'a repassé en public le 2026-10-22 ; les lots 2 à 8 ont été écrits et relus sans compilation, puis compilés d'un coup.
- Run 228 (`[check]`, lots 1 à 8) : compilation réussie du premier coup, 0 erreur. Run 229 (`[unit]`) : 400 tests réussis, 0 échec (dont 15 `CalorieModelTests`, 19 `ScanRecapTests`, 11 `FoodLabelMatcherTests`, 11 `PermissionTests`, 12 `QuickTaskTests`, 8 `HabitHeatmapTests`, 4 `WallpaperCatalogTests`, 4 `ReactivityTests`, 3 `PlanningLayoutTests`).

| Lot | Sujet | Fait |
|---|---|---|
| 1 | Harmonisation des mini-apps (§ 2) | `MiniStyle`, `.miniCard()`, `.miniTile()`, `MiniFootnote`, doublons retirés, identifiants des UITests conservés |
| 2 | Planning façon Calendrier Apple, widget plein (§ 3) | en-tête, bande des jours, blocs translucides, mois (`PlanningMonthGrid`), année, widget `fillsHeight` |
| 3 | Habitudes et Productivité (§ 10, § 12) | `HabitHeatmap` (widget, écran, page Planning) ; réglage « Productivité » (Top 3 avec ajout rapide) |
| 4 | Store : fonds d'écran (§ 4) | 43 fonds originaux en code (14 gratuits, 29 Premium), enregistrement dans Photos |
| 5 | Nutrition : licences (§ 5) | `docs/licences-nutrition.md`, écran « À propos », attributions ; USDA et FCÉN déjà intégrées, OFF en ligne, BEDCA et ForkRecipe écartés, UniTools laissé de côté |
| 6 | Fitness : calories (§ 7) | `CalorieModel` (calories actives, travail et repos), poids du profil requis |
| 7 | Permissions et réactivité (§ 8, § 9) | `PermissionExplainer` ; `.pressable` sur les 221 boutons de `App/`, `TapGuard` dans `MiniActionButton` |
| 8 | Scanner alimentaire (§ 5) | étape A complète ; étape B (IA en ligne) préparée et désactivée |

**Limites connues** : la protection du double appui n'est branchée que sur `MiniActionButton` (les boutons « Enregistrer » des feuilles ne sont pas tous gardés) ; la recherche automatique Open Food Facts part 1,2 s après la frappe (4 lettres) ; le scanner : « Scanner à nouveau » efface le récapitulatif sans confirmation, le préfixe de 3 lettres du `FoodLabelMatcher` est large (« pen » → pâtes), la maquette DEBUG `ScanFrameScreenshot` imite l'ancien scanner ; `capturePhoto()` (VisionKit) et le rendu réel des fonds (performance du Store) ne se vérifient que sur l'iPhone.

**À faire par l'utilisateur** : republier la politique de confidentialité (`docs/legal/privacy.html`, caméra et sources nutritives mises à jour) sur l'artifact de `PremiumConfiguration.privacyURL` ; décider de l'étape B du scanner (service, coût, serveur, politique) ; repasser le dépôt en privé après la livraison (la CI macOS n'est gratuite que s'il est public).

**À vérifier sur l'iPhone** : accueil (dégradés, pastille « Maintenant », anneaux, courbe) ; Planning (jour, semaine, mois, année, widget plein) ; habitudes (widget S/M/L, Teinté, écran) ; carte Productivité (« + » de Mon Quotidien) ; Store › Fonds d'écran (défilement, aperçu, enregistrement) ; « À propos » (sources) ; calories de Fitness ; explications avant chaque permission (notifications, calendrier, position, pas, caméra) ; scanner (code-barres, produit inconnu, mode avion, photo d'un plat, récapitulatif, un seul ajout au double appui) ; retour visuel au toucher.

## Mini-apps : sélecteur de semaine et même structure — 2026-10-22

Demande (2026-10-22) : sélecteur de semaine en tête, puis essentiel, complémentaire, réglages en dernier ; aucun doublon. Composant `WeekSelector` (`App/Screens/MiniApps/WeekSelector.swift`, dessin de l'image de référence), appliqué à Nutrition, Fitness, Planning, Finances, Business, Voyage, Auto, Météo (Photos et citations : rien de daté, pas de sélecteur). `DaySwitcher` et `WeekCard` ne sont plus utilisés sur les écrans principaux (le `DaySwitcher` reste dans quelques sous-pages : habitudes, activité, semaine/mois du Planning). Run 232 compile, run 233 : 445 tests réussis (dont 6 `WeekSelectorTests`).

- TestFlight : build 234 interne (Premium débloqué, « Internal Only » vérifié, run 234) envoyé avec cette série ; pas de version normale (voir [[Decisions]] : processus de livraison).
- Le jour choisi pilote l'essentiel : repas et macros (Nutrition), séance (Fitness), agenda (Planning), opérations du jour (Finances), chiffre d'affaires de la période (Business), programme du jour (Voyage), journal du jour (Auto), prévision du jour (Météo).
- Doublons retirés : second sélecteur de dates partout ; Planning : navigation propre du calendrier (la période suit le jour choisi) ; Finances : tuiles « Dépenses » et « Solde » (déjà dans le hero et le graphique) ; Nutrition : chiffres répétés dans la carte conseil ; Voyage : « Programme » une seule fois ; Auto : ligne « Kilométrage » ; Météo : « Mis à jour » une seule fois.
- Choix à connaître : Business garde son sélecteur « Période » (granularité du chiffre d'affaires, dans le hero) ; Planning garde les lignes « Semaine » et « Mois » (sous-pages avec leur propre navigation) ; le Top 3 reste lié à aujourd'hui ; Voyage s'ouvre sur le premier jour d'un voyage à venir ; la Météo n'a pas de prévision pour les jours passés de la semaine (« Météo indisponible », rien d'inventé).
- Piège : le rapport CI coupe la liste des tests à 400 lignes ; le journal complet se lit avec `gh run view <id> --log` (chercher `Test Case .* failed` et `TEST SUCCEEDED`).

## Style « Signature » des mini-apps, budget Finances par jour, Planning réorganisé — 2026-10-22

Demande (2026-10-22) : choix du style C (planche de trois styles dans `pub/styles-mini-apps/`), budget de Finances qui suit le jour choisi, Planning avec la semaine du planning juste sous le sélecteur du haut. `MiniAppScaffold` (`App/Screens/MiniApps/MiniAppScaffold.swift`) : bandeau coloré (sélecteur + chiffre essentiel `MiniHero`), feuille arrondie pour le reste, « Mes infos » en dernier, action principale flottante (`MiniFloatingAction`, deux actions = rangée de boutons en haut de la feuille). Appliqué à toutes les mini-apps (run 236 compile). Finances : `Budget.remaining(_:throughDay:)` etc. (7 `FinancesDayBudgetTests`). Planning : plus de ligne « jour choisi », le tableau de la semaine (`PlanningCalendarCard`) vient juste sous le sélecteur (`compact: true`), le choix d'échelle passe dessous, le mois et l'année listent le jour choisi (`AgendaRow` cochable), les pastilles de jours en trois états (plein = fait, creux = prévu). Reste : `[interne]` puis vérification sans Premium (`[apps]`), rien sur TestFlight public.

## À ne pas oublier

- Le dépôt est public pour la CI : le repasser en privé.
