"""Adds the fats, minerals, vitamins and other nutrients of the Canadian Nutrient File to
App/Resources/cnf-foods.json.

    curl -o cnf-amounts.json "https://food-nutrition.canada.ca/api/canadian-nutrient-file/nutrientamount/?lang=en&type=json"
    python3 scripts/cnf_extend.py cnf-amounts.json

Source: Health Canada's CNF API (the same data as the CSV files of scripts/cnf_build.py), Open
Government Licence – Canada. The 15 first columns of each row are kept as they are; 29 columns are
added (null when the file has no value for the food: never a made-up zero), per 100 g:
[15] monounsaturated fat g, [16] polyunsaturated fat g, [17] potassium mg, [18] calcium mg,
[19] iron mg, [20] magnesium mg, [21] vitamin C mg, [22] vitamin A µg RAE, [23] vitamin D µg,
[24] vitamin B12 µg, [25] folate µg DFE,
[26] trans fat g, [27] omega-3 g, [28] omega-6 g, [29] zinc mg, [30] phosphorus mg, [31] selenium µg,
[32] copper mg, [33] manganese mg, [34] vitamin E mg (alpha-tocopherol), [35] vitamin K µg,
[36] thiamin mg, [37] riboflavin mg, [38] niacin mg NE (niacin equivalents), [39] pantothenic acid mg,
[40] vitamin B6 mg, [41] choline mg, [42] caffeine mg, [43] alcohol g.
Trailing nulls are left out (a row may stop after column 14) and whole numbers are written without
« .0 », to keep the file small. Running it again replaces the added columns.
"""
import json
import sys

OUT = "App/Resources/cnf-foods.json"
# nutrient_name_id of the API → column, in order.
ADDED = [645, 646, 306, 301, 303, 304, 401, 814, 339, 418, 815,
         605, 868, 869, 309, 305, 317, 312, 315, 323, 430, 404, 405, 409, 410, 415, 862, 262, 221]
DECIMALS = {645: 2, 646: 2, 306: 0, 301: 0, 303: 2, 304: 0, 401: 1, 814: 0, 339: 2, 418: 2, 815: 0,
            605: 2, 868: 2, 869: 2, 309: 2, 305: 0, 317: 1, 312: 2, 315: 2, 323: 2, 430: 1,
            404: 2, 405: 2, 409: 1, 410: 2, 415: 2, 862: 1, 262: 0, 221: 1}
FIRST_ADDED = 15


def compact(value):
    """318.0 → 318: the same number, two bytes less."""
    if isinstance(value, float) and value.is_integer():
        return int(value)
    return value


amounts = {}
for item in json.load(open(sys.argv[1], encoding="utf8")):
    nutrient = item.get("nutrient_name_id")
    if nutrient in DECIMALS and item.get("nutrient_value") is not None:
        amounts.setdefault(item["food_code"], {})[nutrient] = float(item["nutrient_value"])

rows = json.load(open(OUT, encoding="utf8"))
filled = 0
for index, row in enumerate(rows):
    del row[FIRST_ADDED:]
    values = amounts.get(int(row[0]), {})
    for nutrient in ADDED:
        value = values.get(nutrient)
        row.append(None if value is None else round(value, DECIMALS[nutrient]))
    filled += any(v is not None for v in row[FIRST_ADDED:])
    while len(row) > FIRST_ADDED and row[-1] is None:
        row.pop()
    rows[index] = [compact(v) for v in row]

with open(OUT, "w", encoding="utf8") as f:
    json.dump(rows, f, ensure_ascii=False, separators=(",", ":"))
print(f"{len(rows)} foods, {filled} with fats, minerals, vitamins or other nutrients")
