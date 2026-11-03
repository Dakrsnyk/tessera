---
tags: [ardane, scanner, chantier-22, recherche]
---

# Recherche : bases nutritionnelles, 2026-11-02

Chantier 22.1. Légende : [D] documenté par une source officielle ; [C] constaté (téléchargé et mesuré le 2026-11-02) ; [S] supposé. Ce n'est pas un avis juridique.

## Constats sur l'existant
1. **L'app embarque la FCÉN 2015**, dépassée [C] (5 596 lignes, `App/Resources/cnf-foods.json`, 1,44 Mo). La FCÉN 2026 (14e édition, mai 2026) compte 5 993 aliments et 173 nutriments, Licence du gouvernement ouvert – Canada 2.0 [D].
2. **`cnf.<id>` est un `FoodID` interne, pas le `Food_Code` public** [C] : 1 027 identifiants > 9999 n'existent pas en 2026 (ex. `cnf.501098` chou napa = `Food_Code` 6304). 5 477 lignes sur 5 596 se retrouvent en 2026 par le `FoodCode` 2015 ; 119 retirées ou renommées → table d'alias nécessaire.
3. **Défaut probable : 1 027 aliments sans aucun micronutriment** [C] (exactement les identifiants > 9999). Cause supposée : `scripts/cnf_extend.py` joint le `food_code` de l'API (4 chiffres) au `FoodID`. Le test `Tests/NutritionPremiumTests.swift` l.253-254 fige ce défaut.
4. **Portions et densités perdues à la construction** [C] : `cnf_build.py` garde une seule portion et écarte les mesures « 100 ml » ; la FCÉN 2026 a 21 207 mesures (3,6 par aliment).
5. **Arrondi** [C] : macros arrondies à 0,1 g alors que la FCÉN fixe 2 décimales ; ses lignes directrices interdisent de modifier les valeurs [D].
6. **Format 2026 différent** (UTF-8 avec BOM, autres colonnes) : `cnf_build.py` ne fonctionnera pas tel quel [C].

## Sources
| Source | Licence | Couverture | Points clés |
|---|---|---|---|
| **FCÉN 2026** | Licence du gouvernement ouvert – Canada 2.0 : commercial permis, attribution, ne pas modifier les valeurs, ne pas se dire version officielle [D] | 5 993 aliments FR/EN, très bon pour le Québec | code de source par valeur ; lien `USDA_NDB_Code` pour 4 798 aliments ; manquant ≠ zéro ; 21 207 mesures ; densité dérivable pour 3 902 aliments ; 109 seulement ont petite/moyenne/grande ; zip 26,7 Mo |
| **USDA FoodData Central** (SR Legacy, Foundation, FNDDS) | CC0, crédit demandé [D] | anglais seulement ; SR 7 793 (gelé 2018), Foundation 395, FNDDS 5 432 plats | `food_portion` (SR 14 449 lignes) ; facteurs Atwater propres ; SR 6,1 Mo, FNDDS 3,3 Mo |
| **CIQUAL** (ANSES) | 2020 : Licence Ouverte / CC BY 4.0 ; **2025 non vérifiée** | 3 484 aliments FR/EN | glucides SANS fibres (règlement UE) : sémantique différente ; pas de portions |
| **Open Food Facts** | ODbL 1.0 (base), DbCL (contenu), images CC BY-SA 3.0 | produits emballés | qualité variable ; **embarquer un extrait = base dérivée ODbL : écarté** |
| Rendements/rétentions USDA | CC0 | viandes/volailles 173 lignes ; rétentions 7 018 lignes | reliés par NDB |
| FAO/INFOODS (densités) | non indiquée, usage commercial réservé | 638 entrées | ne pas redistribuer sans accord écrit |
| AFCD (Australie) | basée CC BY-SA 3.0 AU (partage à l'identique) | 1 588 | **exclue** |
| CoFID (R.-U.) | OGL v3 | | si le marché britannique devient prioritaire |
| MEXT (Japon) | compatible CC BY 4.0 [S] | | phase ultérieure |
| Livsmedelsverket, Fineli | CC BY 4.0 | | optionnels |
| EuroFIR | payant | | exclu |

Cru/cuit : jamais un champ structuré, à déduire des noms et valider par paires. Rendements : table USDA des viandes ; féculents par bilan des solides (riz 2,80, pâtes 2,38, quinoa 3,05 [C], marqués dérivés). Densités : masses volumiques apparentes en vrac (FCÉN « N ml » + tasse/cuillère USDA), avec type (liquide, vrac lâche, vrac tassé, solide).

## Recommandation : option B en deux étapes
- **B1** : FCÉN 2026 pivot + USDA (rendements, rétentions, portions, comblement SR). D'abord.
- **B2** : CIQUAL 2025 + plats FNDDS curatés, après confirmation de la licence CIQUAL 2025 et de la source des noms français.
- Open Food Facts reste EN LIGNE seulement (décision du 2026-10-22 confirmée).

**Règle d'or : ne jamais fusionner ni moyenner des valeurs de sources différentes.** Chaque aliment garde sa source ; les doublons sont regroupés par `canon_id` ; la région choisit la variante affichée (fr-CA/en-CA : FCÉN > USDA > CIQUAL). Valeurs FCÉN jamais modifiées.

Schéma : SQLite en lecture seule dans le bundle (bibliothèque système). Tables `food` (id stable `source:ref`, `canon_id`, noms FR/EN (NULL si absent, jamais traduit automatiquement), synonymes, clés normalisées, `prep_state`, groupe, partie comestible, source, version), `nutrient_value` (étiquette INFOODS, valeur, unité, dérivation, code source, n, erreur-type ; **absence de ligne = inconnu, jamais zéro**), `carbs_basis`, `portion`, `density`, `prep_link` (rendements), `xref`, `alias` (anciens `cnf.<FoodID>` et `builtin.*`), `pack_meta` (versions, URL, SHA-256, licences, attributions). Côté app : un protocole `FoodRepository` devant la base ; le journal stocke déjà des instantanés de `FoodItem`, l'historique n'est pas menacé ; `ScanLearning` et `MealMemory` ignorent un identifiant non résolu.

Construction reproductible (`scripts/food_db/`, Python standard) : téléchargements épinglés (`sources.lock.json` : URL, date, SHA-256, licence ; fichiers bruts hors dépôt) ; un normaliseur par source ; liens déterministes FCÉN ↔ USDA par NDB ; liens CIQUAL par noms + valeurs, relus dans un `xref_manuel.csv` ; déduplication ; états de préparation ; densités filtrées [0,2 ; 2,0] g/ml ; rendements ; contrôle de cohérence énergétique en DRAPEAU seulement (seuil proposé `max(15 kcal, 15 %)`, ≈ 2 % d'aliments signalés) ; autres contrôles (somme des macros, fibres ≤ glucides, sucres ≤ glucides, saturés ≤ lipides) ; sortie `ardane-food-<version>.sqlite` + `manifest.json` + `ATTRIBUTIONS.md` + rapport persistant ; construction déterministe.
Taille mesurée sur prototype [C] : 14 770 aliments (FCÉN 2026 + 3 345 SR seuls + 5 432 FNDDS) = 6,6 Mo sans provenance par valeur, 10,5 Mo avec une provenance naïve (réductible à quelques centaines de Ko) ; ≈ 2,5–3,2 Mo dans l'IPA [S]. Mise à jour : par versions de l'app ; le scanner ne dépend que de `FoodRepository`.

## Open Food Facts : migration
- v2 « dépréciée, toujours supportée », v3 courante (3.6, 2026-05-27) [D]. URL `https://world.openfoodfacts.org/api/v3/product/{code}?fields=…` ; enveloppe `status: "success"`, `result.id` ; `nutriments` plat identique avec `fields` [C] ; inconnu = 404 + `product_not_found`.
- **Supprimer la boucle `barcodeForms` pour UPC-A et EAN-13** : l'API normalise les zéros de tête ; limite de **15 requêtes/min/IP** en lecture [D]. Garder seulement le cas UPC-E.
- Traiter 429/503 comme « service occupé », pas « hors ligne ».
- **La recherche automatique pendant la frappe (`NutritionSpace.searchOnline`) contrevient à la documentation OFF** (`cgi/search.pl` limité à 10 requêtes/min/IP, « search-as-you-type » interdit) [D] : passer à Search-a-licious (`search.openfoodfacts.org/search`, `brands` en tableau, nutriments `*_100g`) et rendre la recherche explicite (bouton ou Entrée).
- User-Agent : lire la vraie version de l'app. OFF demande de remplir un formulaire d'usage de l'API (action utilisateur).

## Attributions à afficher
- FCÉN : « Fichier canadien sur les éléments nutritifs, Santé Canada, 2026. Contient des renseignements licenciés en vertu de la Licence du gouvernement ouvert – Canada. Ardane n'est pas une version officielle de la FCÉN, n'est pas affilié à Santé Canada ni approuvé par lui. Outil de référence, pas un avis médical. » (le texte actuel n'a ni l'année ni la mention « version officielle »).
- USDA : « U.S. Department of Agriculture, Agricultural Research Service. FoodData Central. fdc.nal.usda.gov » avec les versions utilisées.
- CIQUAL : « Anses. Table de composition nutritionnelle des aliments Ciqual 2025 (mise à jour du 19/11/2025) » (date obligatoire).
- Open Food Facts : inchangé (ODbL, liens), images CC BY-SA 3.0 avec attribution.

## Incertitudes
Licence CIQUAL 2025 non confirmée (site protégé) ; licence FAO densités ; MEXT ; noms français des aliments USDA seuls (aucune source ouverte) ; cause du défaut des 1 027 aliments supposée (non reproduite) ; zip Foundation du 2026-10-29 incomplet ; FTS5 sur iOS 17 non confirmé ; tailles CIQUAL/IPA extrapolées ; limites OFF susceptibles de changer.

## Sources
FCÉN : canada.ca (nutrient-data), open.canada.ca (jeu 1b6139bd-ed7e-4043-bc28-ff00e10f3109), licence open.canada.ca/en/open-government-licence-canada. USDA : fdc.nal.usda.gov (download-datasets, api-guide, faq), catalog.data.gov (cooking yields, retention factors). OFF : openfoodfacts.github.io/openfoodfacts-server/api, docs du dépôt (change log, barcode normalization, cheatsheet), world.openfoodfacts.org/terms-of-use et /data, search.openfoodfacts.org/docs, opendatacommons.org ODbL 1.0. CIQUAL : anses.fr, data.gouv.fr (Ciqual 2020), zenodo 4770600, Licence Ouverte 2.0. Autres : foodstandards.gov.au (AFCD), gov.uk (CoFID), OGL v3, fao.org (INFOODS, conditions), livsmedelsverket.se, eurofir.org, mext.go.jp. Apple : App Review Guidelines 2.5.2, 4.2.3.
