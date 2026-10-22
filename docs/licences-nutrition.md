# Sources de données alimentaires : licences

Rapport condensé, consulté le 2026-10-22. Ce n'est pas un avis juridique.

## Tableau

| Source | Licence | Usage commercial | Obligations | Verdict |
|---|---|---|---|---|
| USDA FoodData Central | CC0 (domaine public) | Oui | Aucune, sauf citer la source | Intégrable |
| Fichier canadien sur les éléments nutritifs (FCÉN, Santé Canada) | Licence du gouvernement ouvert – Canada 2.0 | Oui | Attribution, lien vers la licence, aucune apparence d'aval officiel | Intégré (aliments génériques) |
| Open Food Facts | Base : ODbL 1.0 · contenu : DbCL 1.0 · images : CC BY-SA 3.0 | Oui, sous conditions | Attribution visible avec liens vers openfoodfacts.org et la licence ODbL, user-agent personnalisé, requêtes à l'unité (pas de catalogue OFF embarqué, pas d'images sans leur attribution) | Utilisé en ligne seulement (recherche, code-barres). Point à surveiller : la recherche en ligne part seule, 1,2 s après la dernière frappe et dès 4 caractères, quand il y a peu de résultats locaux (`NutritionSpace.searchOnline`) ; la documentation d'Open Food Facts déconseille la recherche à chaque frappe : si elle est jugée trop fréquente, la passer en action explicite. |
| BEDCA | Autorisation écrite requise pour l'usage commercial | Non sans autorisation | — | Écarté |
| ForkRecipe | Aucun jeu de données, seulement du code serveur | — | — | Écarté |
| UniTools World Recipes | CC BY-SA 4.0 (share-alike) | Question ouverte | Voir plus bas | Laissé de côté |

## Textes d'attribution (dans l'app)

Écran « À propos » (Profil), section « Sources des données alimentaires » :

- Open Food Facts : « Contient des données d'Open Food Facts, disponibles sous la licence Open Database License (ODbL). Contenu sous Database Contents License. Données saisies par la communauté : vérifie l'étiquette. » Liens : openfoodfacts.org, ODbL, DbCL.
- FCÉN : « Contient des informations sous licence du gouvernement ouvert – Canada. Source : Fichier canadien sur les éléments nutritifs, Santé Canada. Ardane n'est pas affilié à Santé Canada ni approuvé par lui. » Lien vers la licence.
- USDA : « Une partie des valeurs de la table d'aliments intégrée provient de USDA FoodData Central (domaine public, CC0). U.S. Department of Agriculture, Agricultural Research Service. » Lien vers fdc.nal.usda.gov. Formulé ainsi parce que le commentaire de `FoodDatabase.swift` indique que la table intégrée s'appuie sur la FCÉN et sur USDA FoodData Central, sans que la provenance soit tracée aliment par aliment : à préciser si un audit de la table est fait.

Dans la recherche d'aliments (Nutrition) :

- Sous les aliments génériques : « Aliments génériques : Fichier canadien sur les éléments nutritifs, Santé Canada (licence du gouvernement ouvert – Canada). Ardane n'est pas affilié à Santé Canada. »
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

Chaque `FoodItem` a un champ `source` (`FoodSource` dans `Shared/Domains/Nutrition.swift`) : `builtin`, `openFoodFacts`, `custom` ou `nutrientFile` (FCÉN). Aucun champ n'a été ajouté dans le cadre de ce lot, pour ne pas toucher aux données sauvegardées. Il n'y a pas de valeur distincte pour l'USDA : les aliments `builtin` ne disent pas quelle table (USDA ou autre) a servi.

## Liens officiels

- USDA FoodData Central : https://fdc.nal.usda.gov
- Licence du gouvernement ouvert – Canada : https://open.canada.ca/en/open-government-licence-canada
- Open Food Facts : https://world.openfoodfacts.org
- ODbL 1.0 : https://opendatacommons.org/licenses/odbl/1-0/
- DbCL 1.0 : https://opendatacommons.org/licenses/dbcl/1-0/
