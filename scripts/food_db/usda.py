"""Normalizer of USDA FoodData Central, SR Legacy (CC0), and of the USDA cooking yields of meat and poultry (CC0).

SR Legacy only fills the foods the Canadian Nutrient File does not have: a food whose NDB code appears in the Canadian
file (`USDA_NDB_Code`, leading zeros ignored) is NOT inserted again. French names stay empty: nothing is translated
automatically. Values are the ones of the file, per 100 g, with the USDA derivation code kept as provenance.
"""
import csv
import re

from common import KEPT_NUTRIENTS, USDA_SOURCE_CLASS, USDA_UNIT_SYMBOLS, clean, csv_rows
from fcen import DENSE, PIECES, PLAIN, qualifier_kind

SR_PREFIX = "FoodData_Central_sr_legacy_food_csv_2018-04/"
BABY_CATEGORY = "Baby Foods"

# Volume units of `measure_unit.csv` (US customary), in millilitres.
VOLUME_UNITS_ML = {"cup": 236.5882365, "tablespoon": 14.78676478125, "teaspoon": 4.92892159375, "liter": 1000.0, "milliliter": 1.0,
                   "fl oz": 29.5735295625, "pint": 473.176473, "quart": 946.352946, "gallon": 3785.411784, "cubic inch": 16.387064,
                   "cubic centimeter": 1.0}
UNDETERMINED_UNIT = 9999
# SR Legacy writes EVERY portion with the unit « undetermined » (9999): the unit is the start of `modifier`
# (« cup, diced », « tbsp », « fl oz »). Weight units (oz, lb) and pieces (slice, piece) are not volumes.
_SR_VOLUME_RE = re.compile(r"^(fl oz|cubic inch|cups?|tbsps?|tablespoons?|tsps?|teaspoons?|pints?|quarts?|liters?|ml)\b[\s,]*(.*)$", re.I)
_SR_VOLUME_UNITS = {"fl oz": "fl oz", "cubic inch": "cubic inch", "cup": "cup", "tbsp": "tablespoon", "tablespoon": "tablespoon",
                    "tsp": "teaspoon", "teaspoon": "teaspoon", "pint": "pint", "quart": "quart", "liter": "liter", "ml": "milliliter"}
_SR_NOTE_RE = re.compile(r"\([^)]*\b(?:serving|fl oz|oz|cup|tbsp|tsp)\b[^)]*\)|\b\d[\d./]*\s*(?:fl oz|oz)\b", re.I)


def _number(text):
    text = clean(text)
    if not text:
        return None
    try:
        return float(text)
    except ValueError:
        return None


def format_amount(value):
    """1.0 → « 1 », 0.5 → « 0.5 »."""
    return f"{value:g}"


def load_sr(archive, fcen_ndb, fcen_units):
    """SR Legacy foods that have no Canadian equivalent, with values, portions and densities.

    `fcen_ndb`: set of the NDB codes (no leading zero) of the Canadian file. `fcen_units`: nutrient code → unit symbol,
    to refuse a value whose unit is not the Canadian one. Returns a dict of plain structures."""
    def rows(name):
        return csv_rows(archive, name, member_exact=SR_PREFIX + name)

    categories = {int(r["id"]): clean(r["description"]) for r in rows("food_category.csv")}
    ndb_of = {r["fdc_id"]: clean(r["NDB_number"]).lstrip("0") for r in rows("sr_legacy_food.csv")}
    foods = {}
    skipped_baby = 0
    already_in_fcen = 0
    for r in rows("food.csv"):
        fdc = r["fdc_id"]
        ndb = ndb_of.get(fdc)
        if not ndb:
            continue
        if ndb in fcen_ndb:
            already_in_fcen += 1
            continue
        category = int(r["food_category_id"] or 0)
        if categories.get(category) == BABY_CATEGORY:
            skipped_baby += 1
            continue
        foods[fdc] = {"fdc": fdc, "ndb": ndb, "en": clean(r["description"]), "group": category}

    # nutrient_id → nutrient_nbr, only the kept ones whose unit is the Canadian one.
    by_id = {}
    unit_mismatch = []
    for r in rows("nutrient.csv"):
        nbr = _number(r["nutrient_nbr"])
        if nbr is None or int(nbr) not in KEPT_NUTRIENTS:
            continue
        unit = USDA_UNIT_SYMBOLS.get(clean(r["unit_name"]), clean(r["unit_name"]))
        expected = fcen_units.get(int(nbr))
        # « mg NE » (Canadian niacin equivalents) is milligrams in the USDA file.
        if expected == "mg NE":
            expected = "mg"
        if expected is not None and unit != expected:
            unit_mismatch.append((int(nbr), unit, expected))
            continue
        by_id[r["id"]] = int(nbr)

    derivations = {}
    for r in rows("food_nutrient_derivation.csv"):
        derivations[int(r["id"])] = (clean(r["code"]), clean(r["description"]), int(r["source_id"] or 0))

    amounts = {}
    for r in rows("food_nutrient.csv"):
        nbr = by_id.get(r["nutrient_id"])
        if nbr is None or r["fdc_id"] not in foods:
            continue
        amount = _number(r["amount"])
        if amount is None:
            continue
        points = _number(r["data_points"])
        derivation = _number(r["derivation_id"])
        amounts.setdefault(r["fdc_id"], {})[nbr] = (
            amount, None, int(points) if points and points > 0 else None, int(derivation) if derivation else None)

    units = {int(r["id"]): clean(r["name"]) for r in rows("measure_unit.csv")}
    portions = {}
    for r in rows("food_portion.csv"):
        if r["fdc_id"] not in foods:
            continue
        grams = _number(r["gram_weight"])
        amount = _number(r["amount"])
        if grams is None or grams <= 0 or amount is None or amount <= 0:
            continue
        unit_id = int(r["measure_unit_id"] or UNDETERMINED_UNIT)
        unit = "" if unit_id == UNDETERMINED_UNIT else units.get(unit_id, "")
        modifier = clean(r["modifier"])
        description = clean(r["portion_description"])
        label = format_amount(amount)
        if unit:
            label += " " + unit
        if description:
            label += (", " if unit else " ") + description
        if modifier:
            label += (", " if unit and not modifier.startswith("(") else " ") + modifier
        volume_ml = amount * VOLUME_UNITS_ML[unit] if unit in VOLUME_UNITS_ML else None
        qualifier = modifier
        if not unit:
            in_modifier = sr_volume(modifier)
            if in_modifier:
                volume_ml = amount * in_modifier[0]
                qualifier = in_modifier[1]
        portions.setdefault(r["fdc_id"], []).append({"seq": int(_number(r["seq_num"]) or 0), "label": label, "grams": grams,
                                                      "volume_ml": volume_ml, "qualifier": qualifier})
    for values in portions.values():
        values.sort(key=lambda p: (p["seq"], p["label"]))

    return {"foods": foods, "amounts": amounts, "portions": portions, "categories": categories, "derivations": derivations,
            "skipped_baby": skipped_baby, "already_in_fcen": already_in_fcen, "unit_mismatch": sorted(set(unit_mismatch)),
            "ndb_descriptions": {ndb_of[r["fdc_id"]]: clean(r["description"]) for r in rows("food.csv") if ndb_of.get(r["fdc_id"])}}


def sr_volume(modifier):
    """(millilitres per unit, the words after the unit) when an SR Legacy `modifier` starts with a US volume unit, else None."""
    match = _SR_VOLUME_RE.match(modifier)
    if not match:
        return None
    word = match.group(1).lower()
    unit = _SR_VOLUME_UNITS.get(word) or _SR_VOLUME_UNITS[word.rstrip("s")]
    return VOLUME_UNITS_ML[unit], match.group(2).strip()


def sr_density_kind(qualifier):
    """The words after the unit decide; a portion note (« (8 fl oz) », « 8 fl oz », « (1 NLEA serving) ») is not a qualifier,
    a shape in parentheses (« (1" pieces) ») is."""
    tokens = re.findall(r"[a-z]+", _SR_NOTE_RE.sub(" ", qualifier).lower())
    if not tokens:
        return PLAIN
    return qualifier_kind(tokens)


def usda_provenance_rows(derivations):
    """Rows of `prov_code` for SR Legacy: (code, class, label_en)."""
    return [(code, USDA_SOURCE_CLASS.get(source, 7), f"{short}: {text}") for code, (short, text, source) in sorted(derivations.items())]


def load_yields(path):
    """The USDA cooking yields of meat and poultry: one dict per row (the NDB is the COOKED food of SR Legacy)."""
    rows = []
    with open(path, encoding="utf-8-sig", newline="") as handle:
        for r in csv.DictReader(handle):
            ndb = clean(r["NDB"]).lstrip("0")
            percent = _number(r[" Cooking Yield %"])
            if percent is None:
                continue
            samples = _number(r["n"])
            rows.append({
                "ndb": ndb or None, "raw_description": clean(r["Yield Description"]), "method": clean(r["Preparation Method1"]),
                "percent": percent, "n": int(samples) if samples else None, "sd": _number(r["SD"]),
                "minimum": _number(r["Yield Minimum %"]), "maximum": _number(r["Yield Maximum %"]),
                "moisture": _number(r["Moisture Gain/ Loss %"]), "fat": _number(r["Fat   Gain/ Loss %"]),
                "year": int(_number(r["Release Year2"]) or 0) or None})
    return rows
