---
tags: [ardane, scanner, chantier-22, base-nutritionnelle]
---

# Base alimentaire Ardane (B1) : rapport de construction

Généré par `scripts/food_db/build.py` (ne pas modifier à la main). Chantier 22, étape B1 : FCÉN 2026 en pivot, USDA SR Legacy pour les aliments sans équivalent FCÉN, rendements USDA des viandes. CIQUAL, FNDDS et Foundation viennent plus tard (B2). Règle d'or : aucune valeur n'est fusionnée ni moyennée entre sources ; une valeur absente est inconnue, jamais zéro.

## Sources (verrou `scripts/food_db/sources.lock.json`)

| Source | Fichier | Date | Octets | SHA-256 (début) | Licence | Usage en B1 |
|---|---|---|---|---|---|---|
| fcen2026 | cnf_fcen_all-files-data_2026.zip | 2026-11-02 | 26 656 195 | `f5faad8977ee6bbd…` | Licence du gouvernement ouvert – Canada 2.0 | pivot : aliments, noms FR/EN, nutriments, mesures, provenance par valeur |
| fcen2015_foods | food2015.json | 2026-11-02 | 471 337 | `1af146f3b8db61d7…` | Licence du gouvernement ouvert – Canada 2.0 | table d'alias : FoodCode 2015 de chaque ancien identifiant cnf.<FoodID> |
| usda_sr_legacy | FoodData_Central_sr_legacy_food_csv_2018-04.zip | 2026-11-02 | 6 074 592 | `b80817294b885053…` | CC0 1.0 | aliments sans équivalent FCÉN (lien par NDB), portions |
| usda_fndds | FoodData_Central_survey_food_csv_2024-10-31.zip | 2026-11-02 | 3 325 692 | `5ccc25ec2777a898…` | CC0 1.0 | pas utilisé en B1 (plats curatés prévus en B2) |
| usda_foundation | FoodData_Central_foundation_food_csv_2026-04-30.zip | 2026-11-02 | 3 825 741 | `70457ee9d9342f43…` | CC0 1.0 | pas utilisé en B1 |
| usda_yields | USDA_CookingYields_MeatPoultry02_0.csv | 2026-11-02 | 21 559 | `e6144d36488781c3…` | CC0 1.0 | rendements de cuisson des viandes (lien par NDB) |
| usda_yields_dd | USDA_CookingYields_MeatPoultry02_DD.csv | 2026-11-02 | 1 677 | `a58e2eaca6ea1ebd…` | CC0 1.0 | documentation des colonnes des rendements |

Les fichiers bruts restent hors du dépôt (`~/ardane-tools/food-data/`) ; SHA-256 complets dans le verrou.

## Résultat

| Mesure | Valeur |
|---|---|
| Fichier `App/Resources/ardane-food.sqlite` | 10 846 208 octets (10.34 Mo) |
| SHA-256 du fichier (SQLite 3.50.4) | `530a84cb9519a4a9e731e74a61345dab94e064f888a701e46c3abc88ac2bdf54` |
| Aliments FCÉN 2026 dans la base | 5 894 |
| Aliments USDA SR Legacy sans équivalent FCÉN dans la base | 3 032 |
| Total d'aliments | 8 926 |
| Valeurs de nutriments (une ligne par valeur connue) | 369 706 |
| Nutriments conservés | 48 (dont 2 totaux dérivés) sur 173 dans le fichier canadien |
| Lignes de mots de l'index de recherche | 114 658 |

Taille visée : moins de 12 Mo. Les nutriments laissés de côté (acides aminés, acides gras un par un, stérols, caroténoïdes, tocophérols, sucres un par un) ne sont lus par aucun écran ; le script les relit si besoin (`KEPT_NUTRIENTS` dans `common.py`).

### Ce qui n'est pas importé

| Exclusion | Aliments |
|---|---|
| FCÉN : aliments pour bébés (groupe 3) | 99 |
| FCÉN : sans énergie (kcal) | 0 |
| SR Legacy : déjà dans la FCÉN (même code NDB, zéros de tête ignorés) | 4 448 |
| SR Legacy : aliments pour bébés | 313 |
| SR Legacy : sans énergie (kcal) | 0 |

## Provenance des valeurs

| Source | Nature de la valeur | Valeurs |
|---|---|---|
| FCÉN 2026 | analytique | 22 859 |
| FCÉN 2026 | calculé | 36 454 |
| FCÉN 2026 | imputé | 8 548 |
| FCÉN 2026 | zéro supposé | 13 664 |
| FCÉN 2026 | repris de l'USDA | 162 939 |
| FCÉN 2026 | étiquette ou industrie | 3 029 |
| FCÉN 2026 | littérature ou autre | 3 227 |
| FCÉN 2026 | provisoire | 86 |
| FCÉN 2026 | base internationale | 46 |
| FCÉN 2026 | dérivé par Ardane | 5 619 |
| USDA SR Legacy | analytique | 36 932 |
| USDA SR Legacy | calculé | 40 977 |
| USDA SR Legacy | zéro supposé | 11 404 |
| USDA SR Legacy | étiquette ou industrie | 9 290 |
| USDA SR Legacy | littérature ou autre | 324 |
| USDA SR Legacy | sans code | 14 308 |

Chaque ligne de `nutrient_value` garde le code de source (FCÉN `Nutrient_Source_Code` ou dérivation USDA), le nombre d'observations et l'erreur-type quand le fichier les donne ; la table `prov_code` en donne le sens. Les valeurs sont celles du fichier, non arrondies (`Nutrient_Decimals` dit combien de décimales montrer).

**Totaux oméga-3 et oméga-6 dérivés.** Le fichier 2026 n'a plus ces deux totaux (la FCÉN 2015 les avait). Ardane les calcule, pour la FCÉN seulement, comme la somme des acides gras individuels de l'aliment (oméga-3 : 18:3, 20:3, 20:5, 22:5, 22:6 n-3 ; oméga-6 : 18:2, 18:3, 20:3, 20:4, 22:4 n-6), seulement si TOUTES les composantes sont connues ; classe « dérivé par Ardane ». 5 801 totaux ajoutés. Comparaison avec ce que la FCÉN 2015 publiait, pour les aliments qui ont gardé leur numéro : oméga-3 1073 égaux à 0,01 g près sur 1495 publiés; oméga-6 471 égaux à 0,01 g près sur 1501 publiés. Les totaux publiés en 2015 ne se retrouvent donc pas toujours à partir des acides gras seuls : ils restent des estimations, marquées comme telles. Pour retirer cette dérivation, ne pas appeler `add_derived_omegas`.

## Portions, densités, rendements

| Type de mesure | Lignes |
|---|---|
| mesure ménagère | 25 866 |
| partie non comestible | 7 094 |
| autre conversion | 1 468 |

8 703 aliments ont au moins une mesure ménagère ; 8 588 ont une portion proposée par défaut (de 5 à 600 g, hors « 100 g » et « 100 ml » ; une portion « moyenne » d'abord, sinon une mesure en grammes comme « 195 g », sinon la première du fichier). Les autres s'affichent « 100 g ».

**Densités** : 11 607 densités sur 4 320 aliments, dérivées des mesures en volume (grammes ÷ millilitres), gardées entre 0.2 et 2.0 g/ml (687 hors de l'intervalle écartées sur 12 294 mesures en volume). Types : mesure simple 8 287, morceaux (air entre eux) 3 072, compact (purée, haché serré…) 161, contenu d'un contenant 87. Une densité de FCÉN vient d'une mesure en ml (tasse = 250 ml) ou, pour l'USDA, d'une tasse, cuillère ou once liquide américaine ; ce sont des masses volumiques apparentes en vrac, pas celles d'un tas dans une assiette.

**Rendements de cuisson** (USDA, viandes et volailles, table Release 2) : 173 lignes lues, 175 liens vers des aliments de la base par le code NDB de l'aliment cuit ; 11 lignes sans aliment correspondant dans la base (détail plus bas). Le rendement est en pourcentage du poids cru, tel que publié ; l'aliment cru associé est cherché par le nom (« description du rendement, raw »).

| NDB | Description | Méthode | Rendement % |
|---|---|---|---|
| aucun | Beef, retail all cuts, all temps | Broiled or Grilled | 78.0 |
| aucun | Beef, retail cuts, all, bone in | Braised | 73.0 |
| aucun | Beef, retail cuts, all, boneless | Braised | 67.0 |
| aucun | Beef, retail cuts, bone in, all temps | Baked or Roasted, unspecified | 77.0 |
| aucun | Beef, retail cuts, boneless, all temps | Baked or Roasted, unspecified | 79.0 |
| aucun | Beef, retail cuts, boneless, short ribs | Braised | 66.0 |
| aucun | Beef, retail cuts, steaks, bone in and boneless | Multiple cooking methods | 76.0 |
| aucun | Lamb, retail cuts, roasts, all samples | Baked or Roasted, unspecified | 74.0 |
| aucun | Lamb, retail cuts, shoulder, shank, breast, flank | Braised | 60.0 |
| aucun | Lamb, retail cuts, shoulder, shank, breast, flank | Poached, Simmered or Stewed | 60.0 |
| 5731 | Turkey, retail parts, enhanced, breast, meat and skin | Roasted | 68.0 |

62 des 175 liens ont aussi l'aliment cru correspondant.

## État de préparation (déduit des noms)

| Source | Cru | Cuit | Transformé ou conservé | Non précisé |
|---|---|---|---|---|
| FCÉN 2026 | 963 | 1 617 | 828 | 2 486 |
| USDA SR Legacy | 583 | 926 | 197 | 1 326 |

Le nom anglais décide ; le nom français confirme. Quand l'un dit cru et l'autre cuit, l'état reste non précisé : 6 cas.

| Code | Anglais | Français |
|---|---|---|
| 1486 | Apple, raw, without skin, sliced, cooked, microwaved | Pomme, crue, sans pelure, tranchée, cuite au four à micro-ondes |
| 1698 | Apple, raw, without skin, sliced, cooked, boiled | Pomme, crue, sans pelure, tranchée, cuite, bouillie |
| 6891 | Turkey, hen, thigh, meat and skin, raw | Dinde, jeune, haut de cuisse, viande et peau, rôtie |
| 7034 | Chicken nuggets, dark and white meat, pre-cooked, frozen, not heated | Poulet, croquette, viande blanche et brune, précuite, congelée, non réchauffée |
| 7035 | Chicken nuggets, white meat, pre-cooked, frozen, not heated | Poulet, croquette, viande blanche, précuite, congelée, non réchauffée |
| 7361 | Sausage, spicy beef and roasted red pepper, raw | Saucisse, épicée au boeuf et poivrons rouges rôtis, crue |

## Contrôles de cohérence (drapeaux, rien n'est corrigé)

Énergie : écart entre les kcal publiées et 4·protéines + 4·glucides + 9·lipides + 7·alcool plus grand que max(15 kcal ; 15 %). Somme des macros (protéines + glucides + lipides + alcool) au-dessus de 101 g ; fibres, sucres au-dessus des glucides ; saturés au-dessus des lipides (tolérance 0.1 g).

| Contrôle | FCÉN 2026 | USDA SR Legacy |
|---|---|---|
| énergie incohérente | 140 (2.4 %) | 11 (0.4 %) |
| somme des macros au-dessus de 100 g | 0 (0.0 %) | 0 (0.0 %) |
| fibres au-dessus des glucides | 0 (0.0 %) | 0 (0.0 %) |
| sucres au-dessus des glucides | 19 (0.3 %) | 9 (0.3 %) |
| saturés au-dessus des lipides | 0 (0.0 %) | 0 (0.0 %) |

Plus gros écarts d'énergie :

| Aliment | Nom | kcal publiées | kcal recalculées |
|---|---|---|---|
| cnf.7245 | Sweetener, herbal extract powder from Stevia leaves | 0 | 400 |
| cnf.4223 | Sweets, cocoa, powder, unsweetened | 228 | 433 |
| cnf.4224 | Sweets, cocoa, powder, unsweetened, dutch process | 220 | 424 |
| cnf.4232 | Dessert, gelatin, dry mix, calorie-reduced, with aspartame, unprepared | 198 | 384 |
| cnf.4416 | Grains, corn bran, crude | 224 | 384 |
| cnf.3278 | Carob (St. John's bread), flour | 222 | 380 |
| cnf.7075 | Drink, fruit flavour, powder, low calorie, vitamin C added | 200 | 355 |
| usda.8363 | Cereals ready-to-eat, SUN COUNTRY, KRETSCHMER Toasted Wheat Bran | 200 | 355 |
| cnf.4493 | Grains, oat bran, dry | 246 | 397 |
| cnf.4146 | Sweets, baking chocolate, unsweetened, liquid | 472 | 622 |
| cnf.5912 | Fish, burbot (loche), Indigenous, liver, baked | 603 | 459 |
| cnf.4442 | Grains, wheat bran, crude | 216 | 358 |
| cnf.5714 | Drink, orange flavour, vitamin C added, low calorie, powder | 217 | 358 |
| usda.43345 | Beverages, fruit-flavored drink, powder, with high vitamin C with othe | 227 | 366 |
| cnf.5632 | Drink, fruit flavour, powder, vitamin C, unsweetened | 226 | 365 |

## Anciens identifiants `cnf.<FoodID 2015>`

| Résolution | Identifiants |
|---|---|
| Même numéro (le FoodID 2015 était le Food_Code, inchangé) : rien à stocker | 4 466 |
| Par le FoodCode 2015 (liste officielle de l'édition 2015, nom anglais exact) : ligne dans `alias` | 1 014 |
| Par le nom anglais exact dans l'édition 2026 : ligne dans `alias` | 4 |
| Non résolus (retirés, renommés ou aliments pour bébés) | 112 |
| Total dans `cnf-foods.json` | 5 596 |

Les identifiants `builtin.*` ne changent pas. Un identifiant non résolu n'a plus d'aliment : `ScanLearning` et `MealMemory` l'ignorent, le journal garde son instantané.

### Non résolus

| Ancien identifiant | Nom anglais (2015) | Nom français (2015) |
|---|---|---|
| cnf.117 | Egg substitute, frozen (yolk replaced) | Oeuf, succédané, congelé (jaune remplacé) |
| cnf.163 | Cream, table (coffee), 20% M.F. | Crème de table (à café) 20% M.G. |
| cnf.455 | Shortening, special purpose, baking | Shortening, usage déterminé, cuisson |
| cnf.523 | Shortening, industrial, for frying (liquid), soybean | Shortening, industriel, friture (liquide), soya |
| cnf.540 | Shortening, industrial, for frying (liquid), canola | Shortening, industriel, friture (liquide), canola |
| cnf.541 | Shortening, industrial, for frying (solid), canola | Shortening, industriel, friture (solide), canola |
| cnf.542 | Shortening, industrial, for frying (solid), soybean | Shortening, industriel, friture (solide), soya |
| cnf.543 | Shortening, industrial, for baking (cake), canola | Shortening, industriel, pour cuisson (gâteau), canola |
| cnf.544 | Shortening, industrial, for baking (cake), soybean | Shortening, industriel, pour cuisson (gâteau), soya |
| cnf.545 | Shortening, industrial, for baking (pastry), canola | Shortening, industriel, pour cuisson (pâtisserie), canola |
| cnf.546 | Shortening, industrial, for baking (pastry), soybean | Shortening, industriel, pour cuisson (pâtisserie), soya |
| cnf.547 | Shortening, industrial, all purpose, soy and palm | Shortening, industriel, tout usage, soya et palme |
| cnf.548 | Shortening, industrial, all purpose, canola and palm | Shortening, industriel, tout usage, canola et palme |
| cnf.637 | Chicken, roasting, meat and skin, raw | Poulet à rôtir, viande et peau, cru |
| cnf.805 | Poultry food products, turkey patties, breaded, battered and fried | Volaille, produit: dinde, croquettes, panées, frites avec pâte |
| cnf.979 | Soup, consomme, dehydrated | Soupe, consommé, déshydraté |
| cnf.1088 | Soup, consomme, dehydrated, water added | Soupe, consommé, déshydraté, eau ajoutée |
| cnf.1196 | Deli-meat, pickle and pimiento loaf, pork | Charcuterie, pain de viande aux piments et aux cornichons, porc |
| cnf.1266 | Cereal, ready to eat, Puffed Rice, unsweenened, Quaker | Céréale, prête-à-manger, riz soufflé, non-sucré, Quaker |
| cnf.1859 | Pork, cured, back bacon, grilled | Porc, salé, bacon de dos, grillé |
| cnf.2798 | Beef, tongue, potted or deviled | Boeuf, langue de, en pot ou à la diable |
| cnf.2828 | Beef, cured, corned beef, outside and eye of round, cooked | Boeuf, salé, "corned beef", extérieur et noix de ronde, cuit |
| cnf.2851 | Alcohol, table wine, rosé (11.5% alcohol by volume) | Alcoolisé, vin de table, rosé (11,5% alcool par volume) |
| cnf.4135 | Candies, bars, Almond Joy | Bonbons, tablettes, Almond Joy |
| cnf.4136 | Candies, bars, Alpine White bar with almonds | Bonbons, tablettes, Alpine White avec amandes |
| cnf.4152 | Candies, Golden Almond Solitaires, chocolate with almonds | Bonbons, Golden Almond Solitaires, chocolat avec amandes |
| cnf.4166 | Candies, bars, 5th Avenue | Bonbons, tablettes, 5th Avenue |
| cnf.4178 | Candies, bars, Krackel | Bonbons, tablettes, Krackel |
| cnf.4182 | Candies, bars, Mars almond | Bonbons, tablettes, Mars avec amandes |
| cnf.4194 | Candies, bars, Golden Almond | Bonbons, tablettes, Golden Almond |
| cnf.4203 | Candies, bars, Mounds | Bonbons, tablettes, Mounds |
| cnf.4204 | Candies, bars, Mr Goodbar | Bonbons, tablettes, Mr Goodbar |
| cnf.4456 | Pasta, macaroni (elbow), whole wheat, dry | Pâtes, macaroni (coudes), blé entier, sec |
| cnf.4457 | Pasta, macaroni (elbow), whole wheat, cooked | Pâtes, macaroni (coudes), blé entier, cuit |
| cnf.4506 | Pasta, macaroni (elbow), enriched, dry | Pâtes, macaroni (coudes), enrichi, sec |
| cnf.4507 | Pasta, macaroni (elbow), enriched, cooked | Pâtes, macaroni (coudes), enrichi, cuit |
| cnf.4508 | Pasta, macaroni, protein-fortified, enriched, dry | Pâtes, macaroni, enrichi de protéines, enrichi, sec |
| cnf.4509 | Pasta, macaroni, protein-fortified, enriched, cooked | Pâtes, macaroni, enrichi de protéines, enrichi, cuit |
| cnf.4520 | Pasta, macaroni (elbow), unenriched, cooked | Pâtes, macaroni (coudes), non enrichi, cuit |
| cnf.4524 | Pasta, macaroni (elbow), unenriched, dry | Pâtes, macaroni (coudes), non enrichi, sec |
| cnf.4526 | Pasta, spaghetti, protein-fortified, enriched, dry | Pâtes, spaghetti, enrichi de protéines, enrichi, sec |
| cnf.4527 | Pasta, spaghetti, protein-fortified, enriched, cooked | Pâtes, spaghetti, enrichi de protéines, enrichi, cuit |
| cnf.4549 | Fast foods, breakfast, english muffin with butter | Aliments prêts à manger, déjeuner, muffin anglais avec beurre |
| cnf.4558 | Fast foods, dessert, animal crackers | Aliments prêts à manger, dessert, biscuits, petits animaux |
| cnf.4559 | Fast foods, dessert, cookies, chocolate chip | Aliments prêts à manger, dessert, biscuits, grains de chocolat |
| cnf.4564 | Fast foods, entree, chicken, breaded and fried, dark meat (drumstick or thigh) | Aliments prêts à manger, plat principal, poulet, pané et frit, viande brune (pilon ou cuisse) |
| cnf.4565 | Fast foods, entree, chicken, breaded and fried, light meat (breast or wing) | Aliments prêts à manger, plat principal, poulet, pané et frit, viande blanche (poitrine ou aile) |
| cnf.4571 | Fast foods, entree, chili con carne | Aliments prêts à manger, plat principal, chili con carne |
| cnf.4572 | Fast foods, entree, clams, breaded and fried | Aliments prêts à manger, plat principal, myes (palourdes), panées et frites |
| cnf.4575 | Fast foods, entree, crab cake | Aliments prêts à manger, plat principal, beignet de crabe |
| cnf.4576 | Fast foods, entree, fish fillet, battered or breaded, fried | Aliments prêts à manger, plat principal, poisson, filet, en pâte à frire ou pané, frit |
| cnf.4577 | Fast foods, entree, oysters, battered or breaded, fried | Aliments prêts à manger, plat principal, huîtres, en pâte à frire ou panées, frites |
| cnf.4579 | Fast foods, entree, salad, vegetable, no dressing | Aliments prêts à manger, plat principal, salade, légumes, sans vinaigrette |
| cnf.4580 | Fast foods, entree, salad, vegetable, no dressing, with cheese and egg | Aliments prêts à manger, plat principal, salade, légumes, sans vinaigrette, avec fromage et oeuf |
| cnf.4581 | Fast foods, entree, salad, vegetable, no dressing, with chicken | Aliments prêts à manger, plat principal, salade, légumes, sans vinaigrette, avec poulet |
| cnf.4582 | Fast foods, entree, salad, vegetable, no dressing, with pasta and seafood | Aliments prêts à manger, plat principal, salade, légumes, sans vinaigrette, avec pâtes et fruits de mer |
| cnf.4583 | Fast foods, entree, salad, vegetable, no dressing, with shrimp | Aliments prêts à manger, plat principal, salade, légumes, sans vinaigrette, avec crevettes |
| cnf.4584 | Fast foods, entree, salad, vegetable, no dressing, with turkey, ham and cheese | Aliments prêts à manger, plat principal, salade, légumes, sans vinaigrette, avec dinde, jambon et fromage |
| cnf.4585 | Fast foods, entree, scallops, breaded and fried | Aliments prêts à manger, plat principal, pétoncles, panés et frits |
| cnf.4589 | Fast foods, mexican, burrito with beans and chili peppers | Aliments prêts à manger, mexicain, burrito avec haricots et piments forts |
| cnf.4592 | Fast foods, mexican, burrito with beans, cheese and chili peppers | Aliments prêts à manger, mexicain, burrito avec haricots, fromage et piments forts |
| cnf.4593 | Fast foods, mexican, burrito with beef | Aliments prêts à manger, mexicain, burrito avec boeuf |
| cnf.4594 | Fast foods, mexican, burrito with beef and chili peppers | Aliments prêts à manger, mexicain burrito avec boeuf et piments forts |
| cnf.4595 | Fast foods, mexican, burrito with beef, cheese and chili | Aliments prêts à manger, mexicain, burrito avec boeuf, fromage et piments forts |
| cnf.4596 | Fast foods, dessert, burrito with fruit (apple or cherry) | Aliments prêts à manger, dessert, burrito avec fruits (pommes ou cerises) |
| cnf.4597 | Fast foods, mexican, chimichanga with beef | Aliments prêts à manger, mexicain, chimichanga avec boeuf |
| cnf.4598 | Fast foods, mexican, chimichanga with beef and cheese | Aliments prêts à manger, mexicain, chimichanga avec boeuf et fromage |
| cnf.4599 | Fast foods, mexican, chimichanga with beef and red chili | Aliments prêts à manger, mexicain, chimichanga avec boeuf et piments forts rouges |
| cnf.4600 | Fast foods, mexican, chimichanga with beef, cheese and red chili peppers | Aliments prêts à manger, mexicain, chimichanga avec boeuf, fromage et piments forts rouges |
| cnf.4601 | Fast foods, mexican, enchilada with cheese | Aliments prêts à manger, mexicain, enchilada avec fromage |
| cnf.4602 | Fast foods, mexican, enchilada with cheese and beef | Aliments prêts à manger, mexicain, enchilada avec fromage et boeuf |
| cnf.4603 | Fast foods, mexican, enchirito with cheese, beef and beans | Aliments prêts à manger, mexicain, enchirito avec fromage, boeuf et haricots |
| cnf.4604 | Fast foods, mexican, frijoles (pinto beans) with cheese | Aliments prêts à manger, mexicain, frijoles (haricots pinto) avec fromage |
| cnf.4611 | Fast foods, mexican, taco salad with chili con carne | Aliments prêts à manger, mexicain, salade de taco avec chili con carne |
| cnf.4612 | Fast foods, mexican, tostada with beans and cheese | Aliments prêts à manger, mexicain, tostada avec haricots et fromage |
| cnf.4613 | Fast foods, mexican, tostada with beans, beef and cheese | Aliments prêts à manger, mexicain, tostada avec haricots, boeuf et fromage |
| cnf.4614 | Fast foods, mexican, tostada with beef and cheese | Aliments prêts à manger, mexicain, tostada avec boeuf et fromage |
| cnf.4615 | Fast foods, mexican, tostada with guacamole | Aliments prêts à manger, mexicain, tostada avec guacamole |
| cnf.4631 | Fast foods, sandwiches and burgers, egg and cheese sandwich | Aliments prêts à manger, sandwichs et burgers, sandwich aux oeufs et fromage |
| cnf.4642 | Fast foods, sandwiches and burgers, ham and cheese sandwich | Aliments prêts à manger, sandwichs et burgers, sandwich au jambon et fromage |
| cnf.4643 | Fast foods, sandwiches and burgers, ham, egg and cheese sandwich | Aliments prêts à manger, sandwichs et burgers, sandwich au jambon, oeuf et fromage |
| cnf.4654 | Fast foods, side dish, corn on the cob with butter | Aliments prêts à manger, plat d'accompagnement, épi de maïs avec beurre |
| cnf.4657 | Fast foods, side dish, potato, baked, topped with cheese sauce | Aliments prêts à manger, plat d'accompagnement, pommes de terre, au four, avec sauce au fromage |
| cnf.4658 | Fast foods, side dish, potato, baked, topped with cheese sauce and bacon | Aliments prêts à manger, plat d'accompagnement, pommes de terre, au four, avec sauce au fromage et bacon |
| cnf.4659 | Fast foods, side dish, potato, baked, topped with cheese sauce and broccoli | Aliments prêts à manger, plat d'accompagnement, pommes de terre, au four, avec sauce au fromage et brocoli |
| cnf.4660 | Fast foods, side dish, potato, baked, topped with cheese sauce and chili | Aliments prêts à manger, plat d'accompagnement, pommes de terre, au four, avec sauce au fromage et chili |
| cnf.4661 | Fast foods, side dish, potato, baked, topped with sour cream and chives | Aliments prêts à manger, plat d'accompagnement, pommes de terre, au four, avec crème sure et ciboulette |
| cnf.4778 | Hot chocolate, cocoa, without sugar, mix, powder | Chocolat chaud, cacao, sans sucre ajouté, mélange sec |
| cnf.4908 | Tea, iced, lemon flavour, ready-to-drink | Thé glacé, saveur de citron, prêt-à-boire |
| cnf.4951 | Chicken enchilada and mexican-style rice with Monterey Jack cheese sauce, frozen | Enchilada au poulet, riz de type mexicain, sauce au fromage Monterey Jack, congelé |
| cnf.5297 | Hot chocolate, cocoa, without sugar, mix, powder, prepared with water | Chocolat chaud, cacao, sans sucre ajouté, mélange sec, préparé avec eau |
| cnf.5450 | Hot chocolate, cocoa, high fat or breakfast, plain, mix, powder | Chocolat chaud, cacao, à haute teneur en matière grasse ou déjeuner, nature, mélange sec |
| cnf.5451 | Hot chocolate, cocoa, high fat or breakfast, processed with alkali, mix, powder | Chocolat chaud, cacao, à haute teneur en matière grasse ou déjeuner, préparé avec alkali, mélange sec |
| cnf.5483 | Beverage, bean | Boisson, fèves |
| cnf.5528 | Candies, chocolate covered, dietetic or low calorie | Bonbons, enrobage de chocolat, diététique ou hypocalorique |
| cnf.5538 | Meatless, fish sticks | Viande, simili, poisson |
| cnf.5545 | Vegetarian stew, meatless | Ragoût, végétarien, sans viande |
| cnf.5578 | Salad dressing, mayonnaise and mayonnaise-type, low calorie | Vinaigrette, mayonnaise et type mayonnaise, hypocalorique |
| cnf.5582 | Sauerkraut, canned, low sodium | Choucroute, conserve, faible en sodium |
| cnf.5747 | Candies,  ALMOND JOY BITES | Bonbons, ALMOND JOY bouchées |
| cnf.501515 | Chicken breast tenders, breaded, cooked in conventional oven | Poulet, tendres de poitrine, panés, cuits au four conventionnel |
| cnf.501649 | Fast foods, brownie | Aliments prêts à manger, carré au chocolat |
| cnf.501683 | Oil, cooking spray | Huile, enduit à cuisson en vaporisateur |
| cnf.501949 | Egg substitute, frozen (yolk replaced), cooked | Oeuf, succédané, congelé (jaune remplacé), cuit |
| cnf.502153 | Cream, 5% | Crème, 5% |
| cnf.502161 | Yogourt, vanilla flavoured, artificially sweetened, fat free (0-0.5% M.F.), with added Vitamin D | Yogourt, saveur de vanille, avec édulcorant artificiel, sans gras (0-0,5% M.G.), avec vitamine D ajoutée |
| cnf.502178 | Yogourt, fruit flavoured, with added calcium and vitamin D (2-3.9% M.F.) | Yogourt, saveurs de fruits, calcium et vitamine D ajoutés (2-3,9% M.G.) |
| cnf.502179 | Yogourt, vanilla flavoured, with added calcium and vitamin D (2-3.9% M.F.) | Yogourt, saveur de vanille, calcium et vitamine D ajoutés (2-3,9% M.G.) |
| cnf.502209 | Kefir, fruit flavours, low fat (0.5-1.9% M.F.) | Kéfir, saveurs de fruits, faible en gras (0,5-1,9% M.G.) |
| cnf.502242 | Frozen, dessert, ice milk bar, low fat | Dessert, congelé, lait glacé, barre, faible en gras |
| cnf.502257 | Drink, fruit flavour, vitamin C added, ready-to-drink | Boisson, saveur de fruits, vitamine C ajoutée, prête-à-boire |
| cnf.502272 | Drink, fruit flavour, powder, low calorie, vitamin C | Boisson, saveur de fruits, poudre, hypocalorique, vitamine C |

## Limites et décisions à relire

- Les noms français des aliments USDA sans équivalent FCÉN sont vides (jamais traduits automatiquement) : ils ne se trouvent qu'en tapant des mots anglais.
- Aliments pour bébés non importés (trop de quasi-doublons dans la recherche, comme avant).
- Le jeu de nutriments est réduit à 46 nutriments de la FCÉN (ceux que l'app lit, plus l'eau, les cendres, le kJ) ; la FCÉN en a 173.
- `qc` est un drapeau pour regarder, pas une correction : les valeurs restent celles de la source.
- Densités : masses volumiques apparentes en vrac issues de mesures ménagères, à ne pas appliquer telles quelles à un tas d'aliment sur une assiette (voir le protocole de mesure du scanner).
- Les rendements USDA ne couvrent que les viandes et volailles ; pas de rendement dérivé pour les féculents en B1.
- Construction déterministe à la version de SQLite près ; deux constructions de suite donnent le même fichier.
