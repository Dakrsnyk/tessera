# Jeu de repas pesés (mesure de la précision réelle du scanner)

Un repas pesé = **une photo** + **le poids de chaque aliment lu sur une balance de cuisine** + les conditions de prise de vue + les droits sur la photo. C'est la seule vérité terrain acceptée pour mesurer ce que le scanner alimentaire d'Ardane fait vraiment (reconnaissance, grammes, calories, macros, fourchettes). Procédure complète, indicateurs et règles : [`docs/scanner/Protocole-mesure.md`](../../../docs/scanner/Protocole-mesure.md).

**Aujourd'hui ce dossier ne contient AUCUN repas pesé.** Il n'y a donc aucun chiffre de précision : le test `WeighedMealsEvaluationTests` le dit dans son rapport `SCAN-PRECISION-<date>.txt` et passe. Rien n'est inventé.

## Fichiers

| Fichier | Rôle |
|---|---|
| `meals.json` | **Le jeu réel** (à créer quand les premiers repas sont pesés). Lu par le test. Absent = « aucune mesure ». |
| `meals.example.json` | Un exemple de structure SANS photo, aux poids factices, marqué `"example": true`. Jamais mesuré. À copier pour démarrer. |
| `manifest.schema.json` | Schéma JSON (2020-12) de `meals.json`. Les éditeurs (VS Code) le reconnaissent via `"$schema"`. |
| `photos/` | Les photos (`.jpg`, `.jpeg`, `.png`, `.heic`), un fichier par repas. **Voir « Où mettre les photos ».** |
| `masks/` | Facultatif : masques de segmentation de référence (`.png`, blanc = l'aliment), pour IoU et Dice. |

Par prudence, les noms de fichiers de ce dossier ne répètent aucun nom de fichier de `Tests/` (le paquet de tests peut copier ses ressources à plat, et deux fichiers de même nom feraient échouer la compilation) : le jeu s'appelle `meals.json` et non `manifest.json`, déjà pris par `Tests/Fixtures/FoodPhotos/`. Les photos portent aussi un nom unique (`repas-014.jpg`).

## Règles non négociables

1. **Les grammes viennent d'une balance.** Jamais estimés à l'œil, jamais déduits d'une portion usuelle, jamais recopiés d'un emballage. Le test refuse un poids qui n'est pas un multiple de la résolution de la balance (`weighing.resolutionG`) : c'est un contrôle contre les chiffres inventés, pas une preuve.
2. **Photos : seulement les tiennes (avec ton accord écrit dans le jeu) ou des photos sous licence libre qui publient aussi des poids mesurés** (CC0, domaine public, CC BY ; jamais CC BY-SA ni photo protégée). Une photo sans poids mesuré n'entre pas ici (les 44 photos de `Tests/Fixtures/FoodPhotos/` mesurent la reconnaissance, pas les grammes).
3. **Pas de visage, pas d'écran, pas de courrier, pas d'intérieur reconnaissable.** Position GPS retirée des métadonnées (Partager › Options › désactiver Position, ou une app qui nettoie l'EXIF) avant d'ajouter la photo. Le test refuse un repas dont `containsPeopleOrPersonalData` est vrai ou `exifLocationRemoved` faux.
4. **Anti-fuite : un `groupID` dans un seul `split`.** Même assiette photographiée plusieurs fois, même préparation (restes compris), même recette cuisinée un autre jour : même `groupID`, donc même split. Le test refuse un groupe réparti sur deux splits.
5. **Les valeurs de référence (kcal, protéines, glucides, lipides) ne sont pas écrites dans le jeu.** Elles sont calculées à chaque mesure depuis les tables de l'app (poids × valeurs pour 100 g) ; le rapport donne l'empreinte SHA-256 de `meals.json` pour savoir si deux rapports portent sur le même jeu. Exception : un produit emballé ou un ingrédient hors tables (`off.*`, `custom.*`) porte ses valeurs pour 100 g lues sur l'étiquette (`nutrientsPer100g`).

## Où mettre les photos

Le dépôt GitHub d'Ardane est **public** (pour la CI). Des photos personnelles ne doivent pas y entrer tant qu'il n'est pas privé. Deux voies :

- **Dépôt repassé en privé** : les photos vont dans `Tests/Fixtures/WeighedMeals/photos/` (JPEG, 1 600 px de côté au plus, environ 1 Mo chacune ; elles sont copiées dans le paquet de tests, 100 photos pèsent donc environ 100 Mo).
- **Photos hors dépôt** : sur un Mac, `TEST_RUNNER_WEIGHED_MEALS_DIR=/chemin/du/dossier xcodebuild test …` (dossier contenant `meals.json` et les photos). La CI GitHub ne verrait pas ce dossier : aucune mesure CI sans dépôt privé.

Un fichier de profondeur LiDAR n'est pas prévu par cette version du format (`schemaVersion` 1) ; `device.lidar` note seulement que l'appareil en avait un. La version 2 ajoutera la profondeur quand une méthode de volume sera retenue.

## Champs d'un repas

| Champ | Contenu |
|---|---|
| `id` | Identifiant unique (`a-z`, `0-9`, tirets), ex. `repas-014`. |
| `split` | `train`, `validation` ou `test` (voir le protocole : attribué par GROUPE, avant tout résultat). |
| `groupID` | Groupe anti-fuite (voir règle 4). |
| `cuisine`, `mealType` | Famille de cuisine et moment du repas (listes fermées du schéma). |
| `photo` | `file` (chemin relatif), `capturedAt` (`AAAA-MM-JJThh:mm:ssZ`), `sha256` facultatif (détecte une photo modifiée), `widthPx`/`heightPx` facultatifs. |
| `rights` | `origin` (`own-photo` ou `licensed-dataset`), `license`, `consent`, `consentDate`, `author`/`sourceURL` (jeu sous licence), `commercialUseAllowed`, `containsPeopleOrPersonalData`, `exifLocationRemoved`. |
| `device` | Appareil qui a pris la photo : `model` (ex. « iPhone 15 Pro »), `iosVersion`, `lens` (`main`, `ultrawide`, `telephoto`, `front`, `other`), `lidar`. |
| `capture` | `lighting`, `tableware`, `angle`, `distanceCm`, `plateDiameterCm` (facultatif), `referenceObject`. |
| `weighing` | `scaleModel`, `resolutionG`, `method` (`tare-sequence`, `separate-weighing`, `recipe-share`). |
| `items[]` | Les aliments pesés : voir ci-dessous. |

### Un aliment (`items[]`)

| Champ | Contenu |
|---|---|
| `foodID` | `builtin.<id>` (table intégrée, `Shared/Domains/FoodDatabase.swift`), `cnf.<numéro>` (Fichier canadien, première colonne de `App/Resources/cnf-foods.json`), `off.<code-barres>` (produit emballé) ou `custom.<nom>` (plat maison). |
| `foodName` | Nom de l'aliment dans la table. Pour `cnf.*`, c'est lui qui permet de retrouver l'aliment : il doit être celui de la table. |
| `grams` | Poids lu sur la balance, en grammes. |
| `state` | `raw`, `cooked` ou `not-applicable`, **au moment de la pesée**. Le test refuse « cooked » pour un aliment dont le nom de la table dit « cru », et l'inverse. |
| `acceptedFoodIDs` | Facultatif : autres identifiants qui comptent comme une bonne reconnaissance (la même chose dans une autre table). |
| `visible` | `false` pour ce que la photo ne peut pas montrer (huile de cuisson, beurre, sauce sous le fromage) : il est pesé et compté dans les calories de référence, mais pas dans la reconnaissance. Défaut `true`. |
| `nutrientsPer100g` | `kcal`, `protein`, `carbs`, `fat` (et `fiber`) lus sur l'étiquette. Obligatoire pour `off.*` et `custom.*` sans `recipe`. |
| `recipe` | Plat maison : `totalCookedG` (poids du plat cuit) et `ingredients[]` (`foodID`, `foodName`, `grams` pesés à la préparation, `nutrientsPer100g` si hors tables). Les valeurs de référence d'une portion sont celles des ingrédients × (poids de la portion / poids total cuit). |
| `mask` | Facultatif : `{ "file": "masks/repas-014-riz.png" }`. |

Forme d'un plat maison (les chiffres de cet exemple sont FACTICES, ils ne montrent que le format ; un vrai plat liste tous les ingrédients réellement pesés, et la portion de 250 g est celle pesée à table) :

```json
{
  "foodID": "custom.ragout-boeuf",
  "foodName": "Ragoût de bœuf maison",
  "grams": 250,
  "state": "cooked",
  "recipe": {
    "totalCookedG": 1800,
    "ingredients": [
      { "foodID": "builtin.beef", "foodName": "Viande hachée", "grams": 900 },
      { "foodID": "builtin.potato", "foodName": "Pomme de terre", "grams": 800 }
    ]
  }
}
```

Pour un plat maison, `acceptedFoodIDs` liste les aliments que le scanner peut raisonnablement proposer à sa place (à décider avant de voir les résultats).

## Vérifier le jeu

- Les tests `[unit]` de la CI : `WeighedMealsEvaluationTests.testTheMeasuredDatasetIsValid` liste tous les défauts du jeu (identifiants en double, fuite entre splits, consentement manquant, photo absente ou modifiée, poids incohérent, aliment introuvable, état contredit…) ; `testSchemaEnumsMatchTheSwiftVocabulary` garde le schéma et le code d'accord.
- Hors CI : `python3 -m pip install jsonschema` puis valider `meals.json` contre `manifest.schema.json` (le schéma ne voit pas les règles croisées, voir ci-dessus).

## Ce que la mesure produit

`WeighedMealsEvaluationTests.testEvaluateWeighedMeals` lance le scan actuel sur chaque photo et joint à la CI `SCAN-PRECISION-<date>.txt` (lisible) et `SCAN-PRECISION-<date>-donnees.json` (chiffres, pour comparer deux runs). Sans `meals.json`, le rapport dit « AUCUNE MESURE DE PRÉCISION N'A ÉTÉ PRODUITE » et le test passe.
