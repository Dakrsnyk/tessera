"""Adds the fats, minerals and vitamins of the Canadian Nutrient File to App/Resources/cnf-foods.json.

    curl -o cnf-amounts.json "https://food-nutrition.canada.ca/api/canadian-nutrient-file/nutrientamount/?lang=en&type=json"
    python3 scripts/cnf_extend.py cnf-amounts.json

Source: Health Canada's CNF API (the same data as the CSV files of scripts/cnf_build.py), Open
Government Licence – Canada. The 15 first columns of each row are kept as they are; 11 columns are
added (null when the file has no value for the food: never a made-up zero), per 100 g:
[15] monounsaturated fat g, [16] polyunsaturated fat g, [17] potassium mg, [18] calcium mg,
[19] iron mg, [20] magnesium mg, [21] vitamin C mg, [22] vitamin A µg RAE, [23] vitamin D µg,
[24] vitamin B12 µg, [25] folate µg DFE.
Running it again replaces the added columns.
"""
import json
import sys

OUT = "App/Resources/cnf-foods.json"
# nutrient_name_id of the API → column, in order.
ADDED = [645, 646, 306, 301, 303, 304, 401, 814, 339, 418, 815]
DECIMALS = {645: 2, 646: 2, 306: 0, 301: 0, 303: 2, 304: 0, 401: 1, 814: 0, 339: 2, 418: 2, 815: 0}

amounts = {}
for item in json.load(open(sys.argv[1], encoding="utf8")):
    nutrient = item.get("nutrient_name_id")
    if nutrient in DECIMALS and item.get("nutrient_value") is not None:
        amounts.setdefault(item["food_code"], {})[nutrient] = float(item["nutrient_value"])

rows = json.load(open(OUT, encoding="utf8"))
filled = 0
for row in rows:
    del row[15:]
    values = amounts.get(int(row[0]), {})
    for nutrient in ADDED:
        value = values.get(nutrient)
        row.append(None if value is None else round(value, DECIMALS[nutrient]))
    filled += any(v is not None for v in row[15:])

with open(OUT, "w", encoding="utf8") as f:
    json.dump(rows, f, ensure_ascii=False, separators=(",", ":"))
print(f"{len(rows)} foods, {filled} with fats, minerals or vitamins")
