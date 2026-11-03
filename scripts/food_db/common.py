"""Shared helpers of scripts/food_db: text keys, nutrients kept, provenance classes, preparation state.

Python standard library only. The text key (`normalize`, `words`) has an exact twin in
`App/Core/SQLiteFoodRepository.swift` (`FoodSearchKey`): change both together.
"""
import csv
import io
import re
import unicodedata
import zipfile

# ---------------------------------------------------------------------------------------------------------
# Text keys
# ---------------------------------------------------------------------------------------------------------

# Letters Unicode does not decompose into a base letter and an accent.
LIGATURES = (("œ", "oe"), ("æ", "ae"), ("ß", "ss"), ("ø", "o"), ("ł", "l"), ("đ", "d"))


def normalize(text):
    """Search key: compatibility decomposition, accents removed, lower case, ligatures spelled out."""
    if not text:
        return ""
    decomposed = unicodedata.normalize("NFKD", text)
    stripped = "".join(c for c in decomposed if unicodedata.category(c) != "Mn")
    lowered = stripped.lower()
    for ligature, plain in LIGATURES:
        lowered = lowered.replace(ligature, plain)
    return lowered


def words(text):
    """The words of a text, normalized: runs of letters and digits."""
    return re.findall(r"[^\W_]+", normalize(text))


# ---------------------------------------------------------------------------------------------------------
# Reading the archives (never extracted: members are read in memory)
# ---------------------------------------------------------------------------------------------------------

def csv_rows(archive_path, member_suffix, member_exact=None):
    """Rows (dicts) of the CSV member of a zip whose name ends with `member_suffix`, UTF-8 with or without BOM."""
    with zipfile.ZipFile(archive_path) as archive:
        names = [n for n in archive.namelist() if n.endswith(member_suffix) and ".." not in n]
        if member_exact:
            names = [n for n in names if n == member_exact]
        # Prefer the shortest name: « food.csv » rather than « food_xyz.csv » (a suffix can match twice).
        names.sort(key=len)
        if not names:
            raise FileNotFoundError(f"{member_suffix} absent de {archive_path}")
        with archive.open(names[0]) as raw:
            text = io.TextIOWrapper(raw, encoding="utf-8-sig", newline="")
            for row in csv.DictReader(text):
                yield row


def clean(text):
    return (text or "").strip()


# ---------------------------------------------------------------------------------------------------------
# Nutrients kept in the pack
# ---------------------------------------------------------------------------------------------------------
# Codes are the Canadian Nutrient File 2026 `Nutrient_Code` (the same numbers as the USDA `nutrient_nbr` for all of
# these). The other 120-odd nutrients of the file (amino acids, individual fatty acids, sterols, carotenoids,
# tocopherols, sugars one by one…) are left out to keep the pack small; they are not read by the app. The few
# individual fatty acids needed to add up omega-3 and omega-6 are read at build time only.

KEPT_NUTRIENTS = [
    203, 204, 205, 207, 208, 221, 255, 262, 263, 268, 269, 291,            # protein, fat, carbs, ash, kcal, alcohol, water, caffeine, theobromine, kJ, sugars, fibre
    301, 303, 304, 305, 306, 307, 309, 312, 315, 317,                      # calcium, iron, magnesium, phosphorus, potassium, sodium, zinc, copper, manganese, selenium
    319, 320, 321, 323, 328, 401, 404, 405, 406, 409, 410, 415, 417, 418, 421, 430, 431, 432, 435,   # vitamins, choline, folates
    601, 605, 606, 645, 646,                                               # cholesterol, trans, saturated, mono, polyunsaturated
]
# Individual fatty acids summed into the two derived totals (the 2026 file has no omega-3 / omega-6 total).
OMEGA3_PARTS = (851, 852, 629, 631, 621)   # ALA, 20:3 n-3, EPA, DPA, DHA
OMEGA6_PARTS = (675, 685, 853, 855, 858)   # LA, GLA, 20:3 n-6, AA, 22:4 n-6
OMEGA3 = 10001
OMEGA6 = 10002
DERIVED_NUTRIENTS = {
    OMEGA3: {"symbol": "N3", "tag": "ARDANE_N3", "unit": "g", "name_en": "Omega-3 fatty acids, total (sum of 18:3, 20:3, 20:5, 22:5 and 22:6 n-3; derived by Ardane)",
             "name_fr": "Acides gras oméga-3, total (somme des 18:3, 20:3, 20:5, 22:5 et 22:6 n-3; dérivé par Ardane)", "decimals": 3},
    OMEGA6: {"symbol": "N6", "tag": "ARDANE_N6", "unit": "g", "name_en": "Omega-6 fatty acids, total (sum of 18:2, 18:3, 20:3, 20:4 and 22:4 n-6; derived by Ardane)",
             "name_fr": "Acides gras oméga-6, total (somme des 18:2, 18:3, 20:3, 20:4 et 22:4 n-6; dérivé par Ardane)", "decimals": 3},
}
UNIT_SYMBOLS = {"Gram": "g", "Milligram": "mg", "Microgram": "µg", "kilocalorie": "kcal", "kilojoule": "kJ",
                "Niacin Equivalents": "mg NE", "International Unit": "IU"}
# SR Legacy unit names → the same symbols (to refuse a value whose unit differs from the Canadian one).
USDA_UNIT_SYMBOLS = {"G": "g", "MG": "mg", "UG": "µg", "KCAL": "kcal", "kJ": "kJ", "IU": "IU"}

# ---------------------------------------------------------------------------------------------------------
# Provenance of a value
# ---------------------------------------------------------------------------------------------------------
# Sources of the pack (table `source`).
SRC_FCEN = 1
SRC_SR = 2
SRC_YIELDS = 3

# Classes of a value (table `prov_code.class`), the same for every source.
CLASS_ANALYTICAL, CLASS_CALCULATED, CLASS_IMPUTED, CLASS_ZERO, CLASS_USDA, CLASS_LABEL, CLASS_OTHER, CLASS_PROVISIONAL, CLASS_INTERNATIONAL, CLASS_DERIVED = range(1, 11)
CLASS_NAMES_FR = {1: "analytique", 2: "calculé", 3: "imputé", 4: "zéro supposé", 5: "repris de l'USDA", 6: "étiquette ou industrie",
                  7: "littérature ou autre", 8: "provisoire", 9: "base internationale", 10: "dérivé par Ardane"}

# FCÉN `Nutrient_Source_Code` → class (the descriptions are in Nutrient_Source.csv).
FCEN_SOURCE_CLASS = {0: CLASS_USDA, 1: CLASS_USDA, 2: CLASS_CALCULATED, 3: CLASS_ANALYTICAL, 4: CLASS_CALCULATED, 5: CLASS_IMPUTED,
                     6: CLASS_LABEL, 7: CLASS_ANALYTICAL, 8: CLASS_OTHER, 9: CLASS_LABEL, 10: CLASS_OTHER, 12: CLASS_ZERO,
                     14: CLASS_PROVISIONAL, 15: CLASS_IMPUTED, 16: CLASS_CALCULATED, 17: CLASS_CALCULATED, 50: CLASS_CALCULATED,
                     51: CLASS_CALCULATED, 81: CLASS_INTERNATIONAL, 82: CLASS_INTERNATIONAL, 83: CLASS_INTERNATIONAL}
# USDA `food_nutrient_derivation.source_id` (= food_nutrient_source.id) → class.
USDA_SOURCE_CLASS = {1: CLASS_ANALYTICAL, 2: CLASS_CALCULATED, 3: CLASS_LABEL, 4: CLASS_CALCULATED, 5: CLASS_ZERO, 6: CLASS_LABEL,
                     7: CLASS_LABEL, 8: CLASS_CALCULATED, 9: CLASS_LABEL, 10: CLASS_OTHER}
# Pseudo codes of derived values (source FCÉN).
DERIVED_OMEGA3_CODE = 100
DERIVED_OMEGA6_CODE = 101

# ---------------------------------------------------------------------------------------------------------
# Preparation state, deduced from the names
# ---------------------------------------------------------------------------------------------------------
PREP_UNKNOWN, PREP_RAW, PREP_COOKED, PREP_OTHER = 0, 1, 2, 3
PREP_NAMES_FR = {0: "non précisé", 1: "cru", 2: "cuit", 3: "transformé ou conservé"}

EN_RAW = {"raw", "uncooked"}
EN_COOKED = {"cooked", "boiled", "baked", "roasted", "fried", "grilled", "broiled", "stewed", "steamed", "braised", "microwaved",
             "poached", "simmered", "sauteed", "heated", "scrambled", "refried", "reheated", "barbecued", "bbq", "charbroiled",
             "pan-broiled", "pan-fried", "stir-fried", "deep-fried"}
EN_OTHER = {"canned", "frozen", "dried", "dehydrated", "pickled", "cured", "smoked", "condensed"}
FR_RAW = {"cru", "crue", "crus", "crues"}
FR_COOKED = {"cuit", "cuite", "cuits", "cuites", "bouilli", "bouillie", "bouillis", "bouillies", "roti", "rotie", "rotis", "roties",
             "frit", "frite", "frits", "frites", "grille", "grillee", "grilles", "grillees", "braise", "braisee", "braises", "braisees",
             "mijote", "mijotee", "mijotes", "mijotees", "vapeur", "poche", "pochee", "poches", "pochees", "saute", "sautee", "sautes",
             "sautees", "rechauffe", "rechauffee", "rechauffes", "rechauffees", "chauffe", "chauffee", "chauffes", "chauffees",
             "micro-ondes", "brouille", "brouillee", "brouilles", "brouillees"}
FR_OTHER = {"conserve", "congele", "congelee", "congeles", "congelees", "seche", "sechee", "seches", "sechees", "deshydrate",
            "deshydratee", "deshydrates", "deshydratees", "marine", "marinee", "fume", "fumee", "fumes", "fumees", "condense", "condensee"}


def _state(tokens, raw, cooked, other):
    if tokens & cooked:
        return PREP_COOKED
    if tokens & raw:
        return PREP_RAW
    if tokens & other:
        return PREP_OTHER
    return PREP_UNKNOWN


_FR_NOT_COOKED = re.compile(r"\bnon (?:cuit|cuite|cuits|cuites|chauffe|chauffee|chauffes|chauffees|rechauffe|rechauffee|rechauffes|rechauffees)\b")


def prep_state(name_en, name_fr):
    """(state, ambiguous). English name first; the French one confirms. A disagreement between the two on raw and
    cooked leaves the state unknown and is reported (ambiguous = True).

    English: a cooking word wins over « raw » (« raw » never appears with one in a name). French: « cru » wins over a
    cooking word, because of the cuts called « rôti » (« rôti de surlonge, cru »); « non cuit » is raw."""
    en_tokens = set(re.findall(r"[a-z]+(?:-[a-z]+)*", (name_en or "").lower())) | set(re.findall(r"[a-z]+", (name_en or "").lower()))
    english = _state(en_tokens, EN_RAW, EN_COOKED, EN_OTHER)
    if not name_fr:
        return english, False
    french_text = _FR_NOT_COOKED.sub("cru", normalize(name_fr))
    fr_tokens = set(re.findall(r"[a-z]+(?:-[a-z]+)*", french_text)) | set(re.findall(r"[a-z]+", french_text))
    if fr_tokens & FR_RAW:
        french = PREP_RAW
    else:
        french = _state(fr_tokens, FR_RAW, FR_COOKED, FR_OTHER)
    if english in (PREP_RAW, PREP_COOKED) and french in (PREP_RAW, PREP_COOKED) and english != french:
        return PREP_UNKNOWN, True
    if english == PREP_UNKNOWN:
        return (french if french in (PREP_RAW, PREP_COOKED) else PREP_UNKNOWN), False
    return english, False
