# Sources de données alimentaires : licences

Rapport condensé, consulté le 2026-10-22, mis à jour le 2026-11-02 (chantier 22, étape B1 : base `ardane-food.sqlite`). Ce n'est pas un avis juridique.

## Tableau

| Source | Licence | Usage commercial | Obligations | Verdict |
|---|---|---|---|---|
| USDA FoodData Central | CC0 (domaine public) | Oui | Aucune, sauf citer la source | Intégré : SR Legacy (avril 2018) pour les aliments que la FCÉN n'a pas (3 032) et rendements de cuisson des viandes |
| Fichier canadien sur les éléments nutritifs (FCÉN, Santé Canada) | Licence du gouvernement ouvert – Canada 2.0 | Oui | Attribution, lien vers la licence, valeurs non modifiées, ne pas se dire version officielle, aucune apparence d'aval | Intégré : édition 2026, 5 894 aliments génériques (`App/Resources/ardane-food.sqlite`) ; l'édition 2015 (`cnf-foods.json`) reste en secours jusqu'à la preuve en CI |
| Open Food Facts | Base : ODbL 1.0 · contenu : DbCL 1.0 · images : CC BY-SA 3.0 | Oui, sous conditions | Attribution visible avec liens vers openfoodfacts.org et la licence ODbL, user-agent personnalisé, requêtes à l'unité (pas de catalogue OFF embarqué, pas d'images sans leur attribution) | Utilisé en ligne seulement (recherche, code-barres). Point à surveiller : la recherche en ligne part seule, 1,2 s après la dernière frappe et dès 4 caractères, quand il y a peu de résultats locaux (`NutritionSpace.searchOnline`) ; la documentation d'Open Food Facts déconseille la recherche à chaque frappe : si elle est jugée trop fréquente, la passer en action explicite. |
| BEDCA | Autorisation écrite requise pour l'usage commercial | Non sans autorisation | — | Écarté |
| ForkRecipe | Aucun jeu de données, seulement du code serveur | — | — | Écarté |
| UniTools World Recipes | CC BY-SA 4.0 (share-alike) | Question ouverte | Voir plus bas | Laissé de côté |

## Textes d'attribution (dans l'app)

Écran « À propos » (Profil), section « Sources des données alimentaires » :

- Open Food Facts : « Contient des données d'Open Food Facts, disponibles sous la licence Open Database License (ODbL). Contenu sous Database Contents License. Données saisies par la communauté : vérifie l'étiquette. » Liens : openfoodfacts.org, ODbL, DbCL.
- FCÉN : « Fichier canadien sur les éléments nutritifs, Santé Canada, 2026. Contient des renseignements licenciés en vertu de la Licence du gouvernement ouvert – Canada. Ardane n'est pas une version officielle de la FCÉN, n'est pas affilié à Santé Canada ni approuvé par lui. Outil de référence, pas un avis médical. » Lien vers la licence.
- USDA : « U.S. Department of Agriculture, Agricultural Research Service. FoodData Central, SR Legacy (avril 2018), et USDA Table of Cooking Yields for Meat and Poultry, Release 2 (domaine public, CC0). Une partie des valeurs de la table d'aliments intégrée et les aliments que le Fichier canadien n'a pas viennent de l'USDA ; ses valeurs ne sont jamais mélangées à celles du Fichier canadien. fdc.nal.usda.gov » Lien vers fdc.nal.usda.gov. La table intégrée `builtin.*` s'appuie toujours sur la FCÉN et sur USDA FoodData Central sans que la provenance soit tracée aliment par aliment (commentaire de `FoodDatabase.swift`) : à préciser si un audit de cette table est fait. Ce sont les aliments de `ardane-food.sqlite` qui ont une provenance par valeur.

Dans la recherche d'aliments (Nutrition) :

- Sous les aliments génériques : « Aliments génériques : Fichier canadien sur les éléments nutritifs, Santé Canada, 2026 (licence du gouvernement ouvert – Canada), et USDA FoodData Central. Ardane n'est pas une version officielle de la FCÉN, n'est pas affilié à Santé Canada ni approuvé par lui. » (`NutrientFile.attribution`). L'ancien texte, sans l'année, ne s'affiche que si `ardane-food.sqlite` est absente et que l'ancien fichier répond.
- Sous les produits emballés : « Données Open Food Facts (ODbL), saisies par la communauté : vérifie l'étiquette. » avec liens vers openfoodfacts.org et l'ODbL.

Pour la FCÉN, la mention anglaise officielle est : « Contains information licensed under the Open Government Licence – Canada. »

## Ce qui est écarté et pourquoi

- **BEDCA** : l'usage commercial exige une autorisation écrite, que nous n'avons pas.
- **ForkRecipe** : le dépôt ne contient aucun jeu de données, seulement du code serveur.
- **Open Food Facts embarqué** : la licence demande des requêtes à l'unité sur action de l'utilisateur et pas de catalogue OFF embarqué. L'app interroge donc le service en ligne et n'en copie pas la base. Les images d'OFF ne sont pas utilisées sans leur attribution.

## UniTools World Recipes : conditions pour réexaminer

Licence CC BY-SA 4.0 (share-alike). Deux points restent ouverts : la compatibilité avec le DRM de l'App Store, et la provenance des textes, qui n'est pas établie. À réexaminer seulement si toutes ces conditions sont réunies :

1. Les adaptations sont publiées sous CC BY-SA 4.0 dans un dépôt public.
2. Le jeu reste séparé des autres tables.
3. Aucune photo n'est utilisée.
4. Un juriste a validé la question du DRM de l'App Store.

## Provenance dans les données

Chaque `FoodItem` a un champ `source` (`FoodSource` dans `Shared/Domains/Nutrition.swift`) : `builtin`, `openFoodFacts`, `custom` ou `nutrientFile`. Aucun champ n'a été ajouté, pour ne pas toucher aux données sauvegardées : les aliments de `ardane-food.sqlite` ont tous `nutrientFile`, y compris ceux de l'USDA (l'identifiant les distingue : `cnf.<Food_Code>` pour la FCÉN, `usda.<NDB>` pour l'USDA). Les aliments `builtin` ne disent pas quelle table (USDA ou autre) a servi.

Dans `ardane-food.sqlite`, chaque valeur de nutriment garde sa provenance (code de source de la FCÉN ou dérivation USDA, nombre d'observations, erreur-type quand le fichier les donne) ; une valeur absente est inconnue, jamais zéro ; aucune valeur n'est fusionnée ni moyennée entre sources ; les valeurs de la FCÉN ne sont pas modifiées. Seuls les totaux oméga-3 et oméga-6, absents du fichier 2026, sont calculés par Ardane (somme des acides gras individuels) et marqués « dérivés ». Détail et comptes : `docs/scanner/food-db-report.md` (généré) ; textes d'attribution générés : `scripts/food_db/ATTRIBUTIONS.md`.

## Fichiers téléchargés (autorisation de l'utilisateur du 2026-11-02)

Conservés hors du dépôt (`~/ardane-tools/food-data/`), épinglés dans `scripts/food_db/sources.lock.json` (URL, date, taille, SHA-256, licence) : FCÉN 2026 (jeu open.canada.ca 1b6139bd-ed7e-4043-bc28-ff00e10f3109), liste des aliments de la FCÉN 2015 (API officielle, utilisée seulement pour retrouver les anciens identifiants `cnf.<FoodID>`), USDA FoodData Central SR Legacy, FNDDS et Foundation (ces deux derniers pas encore utilisés), table USDA des rendements de cuisson des viandes (CC0). Aucune autre donnée n'a été téléchargée ; aucune donnée du dépôt n'a été envoyée.

## Liens officiels

- USDA FoodData Central : https://fdc.nal.usda.gov (CC0 : https://creativecommons.org/publicdomain/zero/1.0/)
- FCÉN 2026 (jeu de données) : https://open.canada.ca/data/dataset/1b6139bd-ed7e-4043-bc28-ff00e10f3109
- USDA Table of Cooking Yields for Meat and Poultry : https://catalog.data.gov/dataset/usda-table-of-cooking-yields-for-meat-and-poultry
- Licence du gouvernement ouvert – Canada : https://open.canada.ca/en/open-government-licence-canada
- Open Food Facts : https://world.openfoodfacts.org
- ODbL 1.0 : https://opendatacommons.org/licenses/odbl/1-0/
- DbCL 1.0 : https://opendatacommons.org/licenses/dbcl/1-0/
