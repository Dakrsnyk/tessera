"""Builds App/Resources/cnf-foods.json from the Canadian Nutrient File (Health Canada, CNF 2015).

    python3 scripts/cnf_build.py <folder with the CNF CSV files>

Source: https://www.canada.ca/en/health-canada/services/food-nutrition/healthy-eating/nutrient-data.html
Licence: Open Government Licence – Canada (attribution: « Fichier canadien sur les éléments nutritifs,
Santé Canada »). The CSV files are in Windows-1252.

Each food becomes one compact row, values per 100 g:
[id, name_fr, name_en, kcal, protein, carbs, fat, fiber, sugars, saturated fat, sodium mg,
 cholesterol mg, serving grams, serving fr, serving en]
"""
import csv
import json
import os
import re
import sys

src = sys.argv[1]
OUT = "App/Resources/cnf-foods.json"


def rows(name):
    with open(os.path.join(src, name), encoding="cp1252", newline="") as f:
        yield from csv.DictReader(f)


NUTRIENTS = {"208": "kcal", "203": "protein", "205": "carbs", "204": "fat", "291": "fiber",
             "269": "sugars", "606": "sat", "307": "sodium", "601": "chol"}
# Baby foods are left out: they would crowd the search with near-duplicates.
SKIPPED_GROUPS = {"3"}

foods = {}
for r in rows("FOOD NAME.csv"):
    if r["FoodGroupID"] in SKIPPED_GROUPS:
        continue
    foods[r["FoodID"]] = {"fr": r["FoodDescriptionF"].strip(), "en": r["FoodDescription"].strip()}

values = {}
for r in rows("NUTRIENT AMOUNT.csv"):
    key = NUTRIENTS.get(r["NutrientID"])
    if key and r["FoodID"] in foods:
        try:
            values.setdefault(r["FoodID"], {})[key] = float(r["NutrientValue"])
        except ValueError:
            pass

measures = {r["MeasureID"]: (r["MeasureDescriptionF"].strip(), r["MeasureDescription"].strip()) for r in rows("MEASURE NAME.csv")}
servings = {}
for r in rows("CONVERSION FACTOR.csv"):
    food, measure = r["FoodID"], r["MeasureID"]
    if food not in foods or measure not in measures or food in servings:
        continue
    fr, en = measures[measure]
    grams = float(r["ConversionFactorValue"]) * 100
    # A household measure (1 cup, 1 slice, 1 medium…), not a « 100 ml » or « 100 g » unit.
    if 5 <= grams <= 600 and not re.match(r"^\s*100\s*(ml|g)\b", en, re.I):
        servings[food] = (round(grams, 1), fr, en)


def num(x):
    return round(x, 1) if x is not None else None


out = []
for fid, names in foods.items():
    v = values.get(fid, {})
    if "kcal" not in v:
        continue
    grams, fr, en = servings.get(fid, (100, "100 g", "100 g"))
    out.append([int(fid), names["fr"], names["en"], round(v["kcal"]), num(v.get("protein", 0)), num(v.get("carbs", 0)),
                num(v.get("fat", 0)), num(v.get("fiber", 0)), num(v.get("sugars")), num(v.get("sat")),
                num(v.get("sodium")), num(v.get("chol")), grams, fr, en])

out.sort(key=lambda row: row[0])
os.makedirs(os.path.dirname(OUT), exist_ok=True)
with open(OUT, "w", encoding="utf8") as f:
    json.dump(out, f, ensure_ascii=False, separators=(",", ":"))
print(f"{len(out)} foods -> {OUT} ({os.path.getsize(OUT) // 1024} KB)")
