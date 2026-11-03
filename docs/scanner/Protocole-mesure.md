---
tags: [ardane, scanner, mesure, protocole]
---

# Protocole de mesure de la précision réelle du scanner alimentaire

Chantier 22, point 22.6 (écrit le 2026-11-02). Ce protocole est **indépendant du modèle choisi** : il mesure le pipeline actuel aujourd'hui, et mesurera n'importe quel pipeline qui le remplace, sur les mêmes repas pesés, avec les mêmes indicateurs. Il part de `docs/audits/Audit-scanner-alimentaire-2026-11-02.md` (aucun chiffre de précision n'existait ; les rapports de CI étaient écrasés à chaque run).

**État au 2026-11-02 : le harnais est écrit, mais il n'existe encore AUCUN repas pesé.** Il n'y a donc aucun chiffre de précision. Rien dans ce document, dans les tests ni dans les rapports n'est une mesure. Compilation et tests du harnais : à lire dans un rapport CI (`[unit]`), pas encore faits.

## 1. Règles (non négociables)

1. **Les poids viennent d'une balance.** Jamais estimés, jamais déduits d'une portion usuelle, jamais recopiés d'un emballage. Un poids invraisemblable pour la balance déclarée (non multiple de sa résolution) fait refuser le jeu.
2. **Aucun chiffre inventé.** Sans repas pesés, le test dit « aucune mesure » et passe. Une valeur non définie (division par zéro, liste vide) s'affiche `n/d`, jamais `0`. La segmentation (IoU, Dice) s'affiche « non mesurée » tant que le pipeline n'expose pas de masque.
3. **Le simulateur n'est pas un iPhone.** Un chiffre mesuré sur simulateur (la CI) est étiqueté « SIMULATEUR » dans le rapport et n'est jamais présenté comme un résultat iPhone. C'est vrai surtout pour les temps, la mémoire et le comportement de Vision ; l'exactitude du calcul (grammes, kcal, fourchettes à partir d'aliments donnés) est la même.
4. **Chaque rapport dit sur quoi il porte** : date, plateforme (modèle d'appareil et iOS, ou simulateur), version de l'app, révision du classifieur, modèles Core ML embarqués et leur taille, tables utilisées, empreinte SHA-256 du jeu. Deux rapports ne se comparent que si l'empreinte du jeu est la même.
5. **Seul le split `test` donne des chiffres publiables**, et seulement à partir de 30 repas. En dessous, le rapport écrit « INDICATIFS » ; chaque taux porte son intervalle de Wilson à 95 % (l'incertitude due au nombre de repas).
6. **Le split `test` n'a jamais servi à régler quoi que ce soit** (voir § 5).
7. **Les photos ne sont jamais celles de quelqu'un sans son accord**, jamais protégées par un droit d'auteur, jamais avec des visages ou des données personnelles, et sans position GPS.
8. **L'ancien pipeline reste le pipeline de secours** tant que le nouveau n'est pas meilleur *prouvé* sur ce protocole (§ 11).

## 2. Ce qui existe

| Fichier | Rôle |
|---|---|
| `Tests/Fixtures/WeighedMeals/README.md` | Format du jeu, règles des photos, où les mettre. |
| `Tests/Fixtures/WeighedMeals/manifest.schema.json` | Schéma JSON de `meals.json`. |
| `Tests/Fixtures/WeighedMeals/meals.example.json` | Exemple de structure (une seule entrée, sans photo, poids factices, `"example": true`, jamais mesuré). |
| `Tests/Fixtures/WeighedMeals/meals.json` | **Le jeu réel. N'existe pas encore.** |
| `Tests/Support/ScanMetrics.swift` | Fonctions de mesure pures (top-k, rappel, IoU, Dice, MAE, biais, RMSE, erreurs relatives, couverture d'intervalles, intervalle de Wilson, percentiles). |
| `Tests/ScanMetricsTests.swift` | Tests de ces fonctions contre des valeurs calculées à la main. |
| `Tests/WeighedMealsEvaluationTests.swift` | Modèle du jeu, validateur, calcul des références, évaluation du pipeline actuel, rapport. |

`ScanMetrics.swift` n'a aucune dépendance UI ni modèle : il pourra passer dans `Shared/` le jour où un écran de diagnostic sur iPhone sera décidé (§ 10).

## 3. Contenu d'un repas pesé

Détail des champs : `Tests/Fixtures/WeighedMeals/README.md` et `manifest.schema.json`. En résumé, pour chaque repas :

- **la photo** (un fichier par repas, `capturedAt`, `sha256` facultatif) et ses **droits** (origine, licence, consentement et sa date, usage commercial autorisé, pas de personnes, position GPS retirée) ;
- **les aliments présents** : identifiant dans la base (`builtin.*` table intégrée, `cnf.*` Fichier canadien, `off.*` produit emballé, `custom.*` plat maison), **poids réel en grammes lu sur la balance**, **état cru/cuit au moment de la pesée**, visible ou caché (huile, beurre, sauce), alternatives acceptées ;
- **la composition** d'un plat maison : ingrédients pesés à la préparation et poids total cuit ; la référence d'une portion en découle ;
- **les valeurs de référence** : *jamais écrites dans le jeu*. Elles sont calculées à chaque mesure depuis les tables de l'app (poids × valeurs pour 100 g, ou valeurs d'étiquette pour un produit emballé). Si une table change, la référence change : l'empreinte du jeu et la version de l'app du rapport permettent de le savoir ;
- **l'appareil de prise de vue** (modèle, iOS, objectif, LiDAR) ;
- **les conditions** : éclairage, vaisselle (et diamètre d'assiette), angle, distance, objet de référence éventuel ;
- **la pesée** : modèle de balance, résolution, méthode (tare successive, pesée séparée, portion d'un plat maison) ;
- **le split** (`train`, `validation`, `test`) et le **groupe** anti-fuite.

L'appareil et la version du modèle *qui exécute* la mesure ne sont pas dans le jeu : ils sont écrits dans l'en-tête de chaque rapport (§ 9).

## 4. Procédure pour toi : photographier et peser un repas

Il te faut une **balance de cuisine** qui affiche le gramme (pas de 1 g, ou 0,1 g), avec la touche de **tare** (zéro). Compte 3 à 5 minutes de plus par repas.

**Avant de manger**

1. Pose l'assiette (ou le bol) **vide** sur la balance et appuie sur la tare : l'écran affiche 0.
2. Ajoute **un seul aliment** (par exemple le riz). Attends que le chiffre se stabilise. **Note le poids affiché** sur la fiche, avec le nom de l'aliment.
3. Appuie sur la tare. Ajoute l'aliment suivant. Note. Recommence jusqu'à la fin. Ne retire jamais un aliment de l'assiette en cours de route : si tu te trompes, vide tout et recommence le repas.
4. **Ce que la photo ne montre pas** (huile de cuisson, beurre, sauce sous le fromage, mayonnaise dans un sandwich) : pèse-le **quand tu le mets** (cuillère ou petit bol posé sur la balance, tare, puis ajoute ; ou bouteille avant/après, différence). Note-le sur la fiche avec la mention **caché**.
5. **Cru ou cuit** : pèse l'aliment *tel qu'il est dans l'assiette* (cuit), et écris « cuit ». Si tu n'as pu peser que cru, écris « cru » : le poids cru ne vaut que pour la valeur cru de la table.
6. **Plat mijoté ou soupe** (ragoût, pâté chinois, soupe, chili) : pèse **chaque ingrédient cru** quand tu cuisines, puis pèse la marmite cuite (tare de la marmite vide d'abord) pour avoir le **poids total cuit**, puis pèse **la portion servie**. Note les trois.

**La photo**

7. Photographie l'assiette **une fois la pesée finie, avant de manger**, avec l'app Appareil photo de l'iPhone, **sans zoom** (1×), **sans mode Portrait**, sans filtre, flash éteint (sauf si c'est la condition que tu veux tester). Une photo représente un repas : si tu veux un autre angle, c'est un autre fichier et le même groupe (§ 5).
8. Cadre comme tu le ferais pour un vrai scan : toute l'assiette visible, pas de main dans le cadre, pas d'autre assiette.
9. Note l'**éclairage** (jour près d'une fenêtre, jour dehors, intérieur chaud, intérieur froid, faible, flash, mixte), la **vaisselle** (assiette plate, creuse, bol, planche, boîte à emporter, plateau, à la main), l'**angle** (dessus, 45°, 30°, de côté), la **distance** approximative en cm, et le **diamètre de l'assiette** si tu le sais.
10. Avant d'envoyer la photo : **retire la position** (Photos › la photo › Partager › Options › désactiver Position) et vérifie qu'il n'y a **personne** ni rien de personnel dans le cadre.

**Ce que tu me donnes pour un repas** (une fiche par repas ; ne remplis jamais un poids que tu n'as pas lu) :

```
Repas : 014            Photo : IMG_4821.JPG       Date et heure : 2026-11-05 18:42
Appareil : iPhone 15 Pro, objectif principal, LiDAR oui
Éclairage : jour près d'une fenêtre     Vaisselle : assiette plate, 26 cm
Angle : dessus     Distance : environ 40 cm
Cuisine : québécoise     Moment : souper
Balance : (modèle), pas de 1 g
Aliments, pesés un par un, assiette tarée :
  - riz blanc cuit ............ 180 g   cuit
  - poitrine de poulet cuite .. 140 g   cuit
  - brocoli cuit ..............  90 g   cuit
  - huile d'olive (CACHÉE) ....   8 g
Même plat ou même recette qu'un autre repas ?  oui, comme le repas 009 (poulet, riz, brocoli)
J'autorise l'usage de cette photo pour mesurer et améliorer le scanner : oui, le 2026-11-05
```

Un agent (ou moi) transforme les fiches en `meals.json` en associant chaque aliment à son identifiant de la base ; le test `testTheMeasuredDatasetIsValid` signale tout défaut. Tu n'écris jamais de JSON toi-même.

## 5. Séparer entraînement, validation et test sans fuite

Une fuite fausse tous les chiffres : un modèle ou un réglage qui a « vu » un repas (ou sa recette) paraît meilleur qu'il n'est.

- **L'unité de répartition est le groupe, pas la photo.** Un `groupID` réunit : la même assiette photographiée plusieurs fois (autres angles, autre éclairage) ; la même préparation, restes compris ; la même recette cuisinée un autre jour (poulet-riz-brocoli de lundi et de jeudi). **Un groupe vit dans un seul split.** Le test refuse tout groupe réparti sur deux splits.
- **Attribution** : on tire les groupes au sort *avant* de regarder le moindre résultat, avec une graine notée dans les notes du jeu, par exemple 60 % `train`, 20 % `validation`, 20 % `test` des groupes, en veillant à ce que `test` contienne **au moins 30 repas**. Les répartitions ne se refont jamais après un résultat.
- **Rôles** : `train` = ce que le modèle apprend (et, pour la personnalisation, ce que l'app « apprend de l'utilisateur ») ; `validation` = choix de seuils, de variantes et de modèles ; `test` = **une seule mesure finale par décision**. Tant que le pipeline actuel n'apprend rien, les trois splits peuvent être mesurés, mais seul `test` est cité.
- **« Test brûlé »** : si un résultat du split `test` a guidé une modification, ces repas ne sont plus un test. On en constitue de nouveaux (nouveaux repas, nouveaux groupes) ; les anciens passent en `validation`.
- **Personnalisation (`ScanLearning`, `MealMemory`)** : la mesure se fait en validation croisée par groupe (apprendre sur tous les autres groupes, mesurer le groupe retenu), jamais en apprenant depuis un groupe `test`. Un repas appris puis re-mesuré mesure la mémoire, pas le scanner.
- **Photos libres de droits sans poids** (`Tests/Fixtures/FoodPhotos/`, 44 photos) : elles mesurent la reconnaissance seulement ; elles ne font pas partie de ce jeu et ne donnent aucun gramme.
- Le jeu `test` et `validation` ne sert jamais à entraîner, y compris par extraction de données pour un futur apprentissage (Phase 5).

## 6. Diversité visée

Ce sont des **cibles de couverture** (pour que les chiffres ne valent pas seulement pour « mon assiette blanche à la fenêtre »), pas des seuils de qualité. Le rapport imprime l'effectif et les résultats par éclairage, vaisselle, angle, appareil et cuisine : une cible manquée se voit.

| Dimension | Cible pour 100 repas |
|---|---|
| Cuisines | au moins 5 familles de la liste du schéma, aucune au-dessus de 40 % |
| Type de plat | aliments simples ≥ 20 % ; assiettes composées ≥ 30 % ; plats mélangés (soupe, ragoût, pâtes à la sauce, sandwich, poutine) ≥ 25 % ; déjeuners ≥ 10 % ; desserts et collations ≥ 10 % |
| Vaisselle | au moins 4 types (plate, creuse, bol, planche ou boîte à emporter…), aucun au-dessus de 50 % |
| Éclairage | au moins 4 conditions dont jour/fenêtre, intérieur chaud, intérieur froid ou faible, aucune au-dessus de 40 % |
| Angle | dessus environ 40 %, 45° environ 30 %, 30° environ 20 %, côté environ 10 % |
| Distance | de 25 à 60 cm |
| Appareils | au moins 2 modèles d'iPhone de générations différentes, dont un avec et un sans LiDAR ; avec un seul appareil, le rapport le montre (« appareil photo : un seul ») et les conclusions s'arrêtent à lui |
| Portions | petites, moyennes et grandes pour les mêmes aliments (riz 80 g et 250 g) |
| Aliments cachés | au moins 20 % des repas avec huile, beurre ou sauce pesés cachés |
| Cru/cuit | au moins 10 repas avec un aliment pesé cru |
| Repas | volume minimal : 50 repas pour commencer, 100 pour une décision ; `test` ≥ 30 repas |

## 7. Indicateurs

Tous sont calculés par `ScanMetrics` (`Tests/Support/ScanMetrics.swift`). Les ratios sont des fractions, affichées en pourcentage. Une valeur indéfinie vaut `n/d`.

| Indicateur | Définition | Remarque |
|---|---|---|
| **Top-1 / Top-3 / Top-5** (par photo) | Part des photos où l'une des k premières propositions est un des aliments **visibles** (identifiant du jeu ou alternative acceptée). | Avec intervalle de Wilson à 95 %. |
| **Rappel @1, @3, @5** (par aliment) | Part des aliments visibles retrouvés parmi les k premières propositions ; une proposition ne sert qu'un aliment. | Mesure les repas à plusieurs aliments, que Top-k ne voit pas. |
| **Propositions superflues** | Propositions qui ne correspondent à aucun aliment pesé (visible ou caché), par repas. | Elles ajoutent des calories fausses. |
| **IoU et Dice** (segmentation) | Intersection sur union, et 2 × intersection / (aire A + aire B), entre masque de référence (`mask`) et masque prédit, de même taille. | **Non mesurés** tant que le pipeline n'expose pas de masque par aliment. Les masques de référence sont facultatifs. |
| **MAE en grammes** | Moyenne de \|grammes proposés − grammes pesés\| sur les aliments **retrouvés**. | Les aliments manqués ne sont pas dans cette moyenne : ils sont dans le rappel. Lire les deux ensemble. |
| **Erreur relative moyenne** (par aliment et globale) | Moyenne de \|proposé − pesé\| / pesé. | Table « par aliment » : attendu, reconnu, MAE, biais, erreur relative. |
| **Biais en grammes** | Moyenne de (proposé − pesé). Négatif = sous-estime. | Une MAE faible avec un biais fort signale une erreur systématique corrigeable. |
| **Poids total du repas** | MAE et biais sur la somme des grammes proposés contre la somme pesée. | |
| **MAE et biais en kcal** | Calories du récapitulatif tel quel (toutes les propositions acceptées sans correction) contre les calories de référence de tout ce qui a été pesé, **cachés compris**. | C'est ce que verrait quelqu'un qui valide sans corriger. |
| **Erreur relative en kcal** et part des repas à ± 20 % | Moyenne de \|kcal proposées − kcal pesées\| / kcal pesées ; part des repas sous 20 %. | |
| **MAE et biais protéines, glucides, lipides** | En grammes, comme les kcal. | |
| **Calibration des fourchettes** | Taux de **couverture** : part des repas où les calories pesées sont dans la fourchette « ≈ a–b kcal » affichée (bornes arrondies comme l'écran ; fourchette brute aussi), avec **largeur relative moyenne** (largeur / calories pesées). | Une grande couverture avec une fourchette énorme n'a pas de valeur : toujours lire les deux. L'app n'annonce aucun niveau de confiance (±40 % fixe, non sourcé) : on mesure le taux réel. Si un modèle annonce « 80 % de confiance », comparer la couverture mesurée à 80 %. |
| **Temps par photo** | Médiane et 95e centile (interpolation linéaire entre rangs voisins), plus la première photo (« à froid », chargement des modèles). | Sur simulateur : indicatif seulement. |
| **Mémoire (RAM)** | Empreinte du processus (`phys_footprint`, le chiffre d'Xcode) après chaque photo : médiane et maximum. | Échantillonnée entre deux photos : ce n'est pas le pic exact. |
| **Taille des modèles** | Modèles Core ML présents dans l'app (`.mlmodelc`, `.mlpackage`), nombre et octets. Aujourd'hui : aucun (classifieur de Vision fourni par iOS, taille non mesurable). | À étendre : nom, SHA-256 du modèle, licence des poids, licence du jeu d'entraînement, unités de calcul. |

**Deux pipelines sont mesurés à chaque run.** `app` = `OnDeviceMealAnalyzer.analyzeMeal` (photo, objets ou grille, mémoire visuelle, apprentissage de l'utilisateur) : c'est ce que l'utilisateur obtient. `matcher` = étiquettes Vision de la photo entière → `FoodLabelMatcher` avec la table intégrée **et le Fichier canadien**, sans apprentissage ni mémoire : une base « à froid » reproductible. Le rapport signale si l'état personnel de l'app (corrections, repas mémorisés) est non vide, car le pipeline `app` en serait influencé.

Pas encore implémenté (à ajouter quand le jeu existera) : intervalles de confiance sur les erreurs moyennes (rééchantillonnage), comparaison appariée de deux pipelines (même repas, deux erreurs), tests de signification. À 30 repas, une différence de quelques points entre deux pipelines n'est pas démontrée.

## 8. Lancer la mesure et la lire

- **CI** : un commit `[unit]` exécute les tests logiques dont `WeighedMealsEvaluationTests`. Le test lit `Tests/Fixtures/WeighedMeals/meals.json` ; s'il est absent, le rapport dit « AUCUNE MESURE DE PRÉCISION N'A ÉTÉ PRODUITE » et le test passe (il ne passe pas pour dire que la précision est bonne : il n'y a pas de chiffre).
- **Pièces jointes** : `SCAN-PRECISION-AAAA-MM-JJ.txt` (rapport lisible) et `SCAN-PRECISION-AAAA-MM-JJ-donnees.json` (chiffres, pour comparer deux runs), exportées par la CI dans `tests/` de la branche `ci-report`.
- **Lire** : `git fetch -q origin ci-report`, extraire avec `git archive` (voir `CLAUDE.md`), ouvrir `tests/SCAN-PRECISION-*.txt`. Vérifier d'abord la première ligne de plateforme (SIMULATEUR ?), l'empreinte du jeu et l'état personnel.
- **Mac** (hors CI, photos hors dépôt) : `TEST_RUNNER_WEIGHED_MEALS_DIR=/chemin xcodebuild test … -only-testing:ArdaneTests/WeighedMealsEvaluationTests`.
- Une erreur de validation du jeu (`testTheMeasuredDatasetIsValid`, ou pièce jointe « jeu INVALIDE ») arrête la mesure : on corrige le jeu, on ne contourne pas.

## 9. Rapports persistants et datés

Aujourd'hui `.github/workflows/build.yml` (étape « Publish build report », l. 880-896) recrée la branche `ci-report` de zéro à chaque run (`git init` puis `git push -f`) : un rapport de précision disparaît au run suivant, y compris à un `[check]`.

**Format d'un rapport.** Nom `SCAN-PRECISION-AAAA-MM-JJ.txt` (date UTC du run), et `SCAN-PRECISION-AAAA-MM-JJ-donnees.json`. En-tête obligatoire : date et heure, plateforme (simulateur ou iPhone réel, modèle, iOS), version et build de l'app, révision du classifieur Vision, nombre et taille des modèles Core ML, tables disponibles (Fichier canadien oui/non), état personnel, jeu (nom, effectifs, groupes, répartition des splits, **empreinte SHA-256**), puis, pour chaque pipeline : photos analysées et échecs, temps, mémoire, et pour chaque split : indicateurs du § 7 avec effectifs. Le JSON contient les mêmes chiffres sous des clés stables (`app.test.top3`, `app.test.kcalMAE`, `matcher.validation.coverageShown`…), `datasetSHA256` et `platform`.

**Modification minimale proposée du workflow** (à soumettre à l'utilisateur ; **je n'ai pas touché au workflow**) : dans « Publish build report », juste avant `cd report` (après la ligne qui copie `stackreports`), conserver l'historique de la branche précédente et y ajouter les rapports de précision de ce run dans un dossier `history/<date>-run<numéro>/` :

```bash
          # Dated scanner precision reports: ci-report is rebuilt from scratch at every run, so the previous
          # history/ folder is copied over and this run's SCAN-PRECISION-* files are added to it.
          git clone -q --depth 1 --branch ci-report "https://x-access-token:${{ secrets.GITHUB_TOKEN }}@github.com/${{ github.repository }}.git" previous-report 2>/dev/null || true
          if [ -d previous-report/history ]; then mkdir -p report/history && cp -R previous-report/history/. report/history/; fi
          if ls testshots/SCAN-PRECISION-* >/dev/null 2>&1; then
            RUNDIR="report/history/$(date -u +%F)-run${{ github.run_number }}"
            mkdir -p "$RUNDIR" && cp testshots/SCAN-PRECISION-* "$RUNDIR"/
          fi
          # Keep the 60 most recent runs only.
          if [ -d report/history ]; then ls -1 report/history | sort -r | tail -n +61 | while read -r old; do rm -rf "report/history/$old"; done; fi
```

Points à vérifier avant d'appliquer : le jeton `GITHUB_TOKEN` du job a déjà le droit d'écriture sur le contenu (il sert au `push -f` de la même étape) ; le premier run n'a pas encore de branche à cloner (d'où `|| true`) ; l'étape reste en `if: always()` ; seuls des fichiers texte et JSON sont copiés (jamais les photos du jeu). Lecture : `git fetch -q origin ci-report`, `git archive origin/ci-report history | tar -x -C <dossier>`, puis ouvrir `history/<date>-run<N>/SCAN-PRECISION-*.txt`. À côté, les fichiers `SCAN-PRECISION-*` du dernier run restent dans `tests/` comme tous les autres rapports.

Règle de comparaison : on ne compare que des rapports de **même empreinte de jeu**, de **même plateforme** (jamais simulateur contre iPhone) et de **même split**. Chaque décision de remplacement de pipeline cite les deux dossiers `history/` comparés.

## 10. Mesure sur iPhone réel

La CI exécute les tests sur **simulateur** (macOS de GitHub, sans iPhone). Elle valide l'exactitude du calcul et de la logique, pas les temps, la mémoire ni la qualité de Vision et des futurs modèles Core ML sur la puce de l'iPhone. Aucun chiffre de CI ne dit ce que fait l'iPhone de l'utilisateur.

Pour mesurer sur l'iPhone sans Mac, il faudra un moyen d'exécuter **le même évaluateur dans l'app** : par exemple un écran de diagnostic réservé aux versions internes (`#if DEBUG` ou condition équivalente que `scripts/check_swift.py` accepte), qui lit `meals.json` et les photos depuis Fichiers, appelle `ScanMetrics` et le scoreur (à déplacer dans `Shared/`), puis exporte `SCAN-PRECISION-*.txt/.json` par le menu Partager. **Ce n'est pas fait ni décidé** : c'est une proposition pour le Chef, à soumettre ; elle ne doit rien envoyer hors de l'appareil. D'ici là, toute mention de temps ou de mémoire dit « simulateur ».

## 11. Quand un nouveau pipeline remplace l'ancien

Les seuils ne sont **pas fixés ici** : ils doivent l'être par l'utilisateur et le Chef **avant la première mesure du nouveau pipeline**, puis écrits dans `Decisions.md` (sinon on les ajusterait pour que le résultat passe). Le gabarit de la règle :

1. Mêmes repas `test` (même empreinte), mêmes conditions de plateforme, deux pipelines mesurés dans le même run.
2. Sur `test` : Top-3 non inférieur, MAE en kcal inférieure d'au moins un écart fixé d'avance, biais en kcal pas plus grand en valeur absolue, couverture des fourchettes affichées pas dégradée (ou fourchettes plus étroites à couverture égale).
3. Pas de régression sur une condition de prise de vue (éclairage, vaisselle, angle, appareil) au-delà d'une tolérance fixée d'avance.
4. Temps médian, 95e centile et mémoire sur iPhone réel (§ 10) sous des plafonds fixés d'avance ; taille du modèle acceptable pour l'App Store et la bande passante.
5. Licences des poids du modèle **et** du jeu qui l'a entraîné compatibles avec un usage commercial (vérifiées et notées).
6. Tant que 2 à 5 ne sont pas tous prouvés, l'ancien pipeline reste le chemin par défaut, le nouveau est derrière un interrupteur.

## 12. Limites connues du harnais actuel

- **Pas de segmentation mesurable** : `OnDeviceMealAnalyzer` ne rend que des propositions (les masques d'objets servent à recadrer, pas à être comparés). IoU et Dice sont codés et testés (`ScanMetrics`) mais non branchés.
- **Pipeline `matcher` sur simulateur** : `VNClassifyImageRequest` est forcé en CPU (`usesCPUOnly`) sous simulateur, comme dans `FoodPhotoRecognitionTests`, parce que Vision y est instable ; le pipeline `app` n'a pas ce réglage (il est identique à la production) et peut échouer par photo sous simulateur : les échecs sont comptés et listés dans le rapport, pas masqués.
- **État personnel** : `app` lit `SharedStore.shared` comme la production. À froid (CI, simulateur neuf) il est vide ; si ce n'est pas le cas, le rapport l'écrit en toutes lettres.
- **Grammes de la mémoire visuelle et des gabarits** : un gabarit (`DishTemplate`) propose des grammes fixes ; le rapport les juge comme n'importe quelle proposition, par aliment retrouvé.
- **Aliments retrouvés sous un autre identifiant** : sans `acceptedFoodIDs`, « Riz blanc cuit » (`builtin.rice`) et un riz du Fichier canadien (`cnf.*`) ne comptent pas l'un pour l'autre. C'est à celui qui constitue le jeu d'ajouter les équivalences, et de le faire avant de regarder les résultats.
- **Intervalles de confiance** : seuls les taux ont leur intervalle de Wilson ; les erreurs moyennes (MAE, biais) n'en ont pas encore (§ 7).
- **Compilation non vérifiée** : le harnais a été écrit sans Mac ; seul un rapport CI `[unit]` dira s'il compile et si ses tests passent.

## 13. Avant le premier vrai run

- [ ] Décider où vivent les photos (dépôt privé ou dossier local) et repasser le dépôt en privé si les photos y entrent.
- [ ] Peser et photographier au moins 50 repas (§ 4) en visant la diversité du § 6 ; remplir une fiche par repas.
- [ ] Transformer les fiches en `meals.json` (identifiants de la base, alternatives acceptées), attribuer les groupes et les splits par tirage au sort noté (§ 5).
- [ ] Lire le rapport de validation du jeu (`testTheMeasuredDatasetIsValid`) et corriger.
- [ ] Soumettre la modification du workflow du § 9 à l'utilisateur ; l'appliquer seulement avec son accord explicite.
- [ ] Fixer les seuils du § 11 avant de mesurer un autre pipeline que l'actuel.
- [ ] Premier run `[unit]` : lire le rapport CI, noter les chiffres du pipeline actuel comme **ligne de base** (simulateur, étiquetée comme telle).
