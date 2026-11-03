"""Normalizer of the Canadian Nutrient File 2026 (FCÉN, Health Canada, Open Government Licence – Canada).

Reads the « all files » archive without extracting it. Values are NOT modified: the amount is the number written in
`Nutrient_Amount.csv`, the number of decimals to show is `Nutrient_Decimals` (a display rule, not a rounding of the
data). The public key of a food is `Food_Code`. A missing value is a missing row, never a zero.
"""
import re

from common import (CLASS_DERIVED, DERIVED_NUTRIENTS, DERIVED_OMEGA3_CODE, DERIVED_OMEGA6_CODE, FCEN_SOURCE_CLASS, KEPT_NUTRIENTS,
                    OMEGA3, OMEGA3_PARTS, OMEGA6, OMEGA6_PARTS, UNIT_SYMBOLS, clean, csv_rows)

BABY_FOODS_GROUP = 3

# Density filter (g/ml) of the derived densities.
DENSITY_RANGE = (0.2, 2.0)

PLAIN, PIECES, DENSE, CONTAINER = 1, 2, 3, 4
DENSITY_KIND_NAMES_FR = {PLAIN: "mesure simple", PIECES: "morceaux (air entre eux)", DENSE: "compact (purée, haché serré…)", CONTAINER: "contenu d'un contenant"}
_ML_RE = re.compile(r"^\s*(\d+(?:\.\d+)?)\s*ml\b(.*)$", re.I)
_CONTAINER_RE = re.compile(r"\(\s*(\d+(?:\.\d+)?)\s*ml\s*\)", re.I)
_PLAIN_QUALIFIERS = {"", "regular", "poured", "stirred", "fluid"}
_DENSE_WORDS = {"mashed", "melted", "puree", "pulp", "packed", "pressed", "liquid"}


def volume_of(label_en):
    """(millilitres, kind) of a measure written in volume (« 250 ml », « 250 ml chopped », « 1 can (284 ml) »), or None."""
    text = clean(label_en)
    match = _ML_RE.match(text)
    if match:
        millilitres = float(match.group(1))
        rest = match.group(2).strip().lower()
        tokens = re.findall(r"[a-z]+", rest)
        if rest.startswith("to "):
            return None  # « 15 ml to 30ml »: a range, not a measure
        if not rest or (tokens and set(tokens) <= _PLAIN_QUALIFIERS):
            return millilitres, PLAIN
        return millilitres, qualifier_kind(tokens)
    match = _CONTAINER_RE.search(text)
    if match:
        return float(match.group(1)), CONTAINER
    return None


def qualifier_kind(tokens):
    """Pieces (air between them) unless the words say the food is mashed, melted, puréed or packed."""
    words = set(tokens)
    if words & _DENSE_WORDS and not (words & {"unpacked", "not"}):
        return DENSE
    return PIECES


def load(archive):
    """Everything the build needs from the archive (a dict of plain Python structures)."""
    groups = {int(r["CNF_Food_Group_Code"]): (clean(r["CNF_Food_Group_Description_EN"]), clean(r["CNF_Food_Group_Description_FR"]))
              for r in csv_rows(archive, "CNF_Food_Group.csv")}
    nutrient_sources = {int(r["Nutrient_Source_Code"]): (clean(r["Nutrient_Source_Description_EN"]), clean(r["Nutrient_Source_Description_FR"]))
                        for r in csv_rows(archive, "Nutrient_Source.csv")}

    nutrients = {}
    for r in csv_rows(archive, "Nutrient_Name.csv"):
        code = int(r["Nutrient_Code"])
        nutrients[code] = {"symbol": clean(r["Nutrient_Symbol"]), "tag": clean(r["Tagname"]), "unit": UNIT_SYMBOLS.get(clean(r["Nutrient_Unit"]), clean(r["Nutrient_Unit"])),
                           "name_en": clean(r["Nutrient_Name_EN"]), "name_fr": clean(r["Nutrient_Name_FR"]), "decimals": int(r["Nutrient_Decimals"] or 0)}

    foods = {}
    for r in csv_rows(archive, "Food_Name.csv"):
        code = int(r["Food_Code"])
        ndb = clean(r["USDA_NDB_Code"]).lstrip("0")
        foods[code] = {"code": code, "en": clean(r["Food_Description_EN"]), "fr": clean(r["Food_Description_FR"]) or None,
                       "alt_en": clean(r["Alternate_Description_EN"]) or None, "alt_fr": clean(r["Alternate_Description_FR"]) or None,
                       "group": int(r["CNF_Food_Group_Code"]), "origin": int(r["Food_Source_Code"] or 0), "ndb": ndb or None,
                       "updated": clean(r["Food_Last_Updated_Date"]) or None}

    wanted = set(KEPT_NUTRIENTS) | set(OMEGA3_PARTS) | set(OMEGA6_PARTS)
    amounts = {}
    for r in csv_rows(archive, "Nutrient_Amount.csv"):
        nutrient = int(r["Nutrient_Code"])
        if nutrient not in wanted:
            continue
        observations = int(float(r["Observations"] or 0))
        error = float(r["STD_Error"] or 0)
        amounts.setdefault(int(r["Food_Code"]), {})[nutrient] = (
            float(r["Nutrient_Amount"]), error if error > 0 else None, observations if observations > 0 else None, int(r["Nutrient_Source_Code"]))

    measure_names = {int(r["Measure_Code"]): (clean(r["Measure_Description_and_Unit_EN"]), clean(r["Measure_Description_and_Unit_FR"]))
                     for r in csv_rows(archive, "Measure_Name.csv")}
    conversions = []
    for r in csv_rows(archive, "Measure_Weight_Conversion.csv"):
        measure = int(r["Measure_Code"])
        if measure not in measure_names:
            continue  # one conversion points to a measure the file does not name: nothing to show
        conversions.append((int(r["Food_Code"]), int(r["Measure_Type_Code"]), measure, float(r["Measure_Weight_Conversion"])))

    return {"groups": groups, "nutrient_sources": nutrient_sources, "nutrients": nutrients, "foods": foods, "amounts": amounts,
            "measure_names": measure_names, "conversions": conversions}


def add_derived_omegas(amounts):
    """Adds the omega-3 and omega-6 totals (the 2026 file has none; the 2015 edition did) as the sum of the individual
    fatty acids, only for a food that has ALL the parts of the sum. Returns the number of totals added."""
    added = 0
    for code, values in amounts.items():
        for total, parts, pseudo in ((OMEGA3, OMEGA3_PARTS, DERIVED_OMEGA3_CODE), (OMEGA6, OMEGA6_PARTS, DERIVED_OMEGA6_CODE)):
            if all(p in values for p in parts):
                values[total] = (sum(values[p][0] for p in parts), None, None, pseudo)
                added += 1
    return added


def source_classes(nutrient_sources):
    """Rows of `prov_code` for the Canadian file: (code, class, label_en, label_fr)."""
    rows = []
    for code, (en, fr) in sorted(nutrient_sources.items()):
        rows.append((code, FCEN_SOURCE_CLASS.get(code, 7), en, fr))
    rows.append((DERIVED_OMEGA3_CODE, CLASS_DERIVED, DERIVED_NUTRIENTS[OMEGA3]["name_en"], DERIVED_NUTRIENTS[OMEGA3]["name_fr"]))
    rows.append((DERIVED_OMEGA6_CODE, CLASS_DERIVED, DERIVED_NUTRIENTS[OMEGA6]["name_en"], DERIVED_NUTRIENTS[OMEGA6]["name_fr"]))
    return rows
