"""Builds App/Resources/food-densities.json (apparent densities in g/ml) from App/Resources/cnf-foods.json.

    python3 scripts/build_food_densities.py           # writes the file
    python3 scripts/build_food_densities.py --check   # exits 1 if the file on disk is not what this script produces

Source: Canadian Nutrient File (Health Canada, CNF 2015), Open Government Licence - Canada (attribution and
conditions: docs/licences-nutrition.md). Nothing else is read: the same input always gives the same output
(no date, no random value), so the file can be regenerated and compared.

How a density is obtained
- A CNF row carries one household measure (columns 12 to 14 of cnf-foods.json: grams of the measure, its name in
  French and in English). When that measure is a volume in millilitres (« 125ml », « 250ml chopped », « 1 can
  (284 ml) »), density = grams / millilitres.
- A density outside 0.15 to 2.0 g/ml is rejected: dry cereals and dried herbs measured loose (0.05 to 0.14), and a few
  rows that are plainly wrong (18.36). The rejected rows are counted in the output, never silently dropped.
- If a food had several volume measures, its density is their median (today the file has one per food).
- Provenance of every value: the CNF identifier, the measure text and the grams of that measure.

Category priors (used by the app when a food has no measured density)
- Each CNF food is put in one of the 10 families of the app (`FoodCategory`) from the first words of its English name.
  The rules below are a coarse, readable guess: a food they do not recognise has no family and is not counted.
- For every family: the median density of its measured foods that are eaten as served (not raw or dry for starches
  and proteins, never a powder, flour or mix), the quartiles, the number of foods and the spread of ln(density).
  The app uses sigma = max(0.30, spread): a family density is a prior, never a precise value.
"""
import json
import math
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SOURCE = os.path.join(ROOT, "App", "Resources", "cnf-foods.json")
OUT = os.path.join(ROOT, "App", "Resources", "food-densities.json")

MIN_DENSITY, MAX_DENSITY = 0.15, 2.0

# Column positions in cnf-foods.json (see scripts/cnf_build.py).
ID, NAME_EN, SERVING_GRAMS, SERVING_FR, SERVING_EN = 0, 2, 12, 13, 14

VOLUME_LEADING = re.compile(r"^\s*(\d+(?:[.,]\d+)?)\s*ml\b", re.I)
VOLUME_IN_PARENTHESES = re.compile(r"\(\s*(\d+(?:[.,]\d+)?)\s*ml\s*\)", re.I)

# ---------------------------------------------------------------- families (FoodCategory of the app)

FRUIT_WORDS = (
    "apple", "pear", "apricot", "peach", "cherry", "grapefruit", "pineapple", "orange", "blueberry", "fig", "plum", "prune",
    "raspberry", "strawberry", "blackberry", "grape", "melon", "banana", "boysenberry", "cranberry", "jackfruit", "jujube",
    "kiwi", "longan", "mango", "papaya", "passion fruit", "fruit", "applesauce", "date", "currant", "guava", "persimmon",
    "rhubarb", "raisin", "tangerine", "lemon", "lime", "nectarine", "pomegranate", "watermelon", "acerola", "breadfruit",
    "carambola", "carissa", "cherimoya", "crabapple", "custard-apple", "elderberry", "gooseberry", "groundcherry", "haw",
    "java-plum", "kumquat", "loganberry", "loquat", "lychee", "mulberry", "oheloberry", "pitanga", "prickly pear", "pummelo",
    "quince", "roselle", "rose-apple", "sapodilla", "sapote", "soursop", "sugar-apple", "tamarind", "feijoa", "mammy-apple",
    "avocado", "huckleberries", "salmonberry", "mangosteen", "durian", "rambutan", "apricots",
)
VEGETABLE_WORDS = (
    "potato", "squash", "pepper", "peas", "corn", "mushroom", "onion", "cabbage", "broccoli", "carrot", "tomato", "asparagus",
    "cauliflower", "spinach", "kale", "turnip", "succotash", "vegetables", "beets", "radish", "pickles", "artichoke",
    "balsam-pear", "brussels sprouts", "collards", "gourd", "drumstick", "lettuce", "mustard greens", "okra", "taro", "salad",
    "pumpkin", "yam", "bamboo shoots", "butterbur", "leeks", "plantain", "greens", "arrowhead", "burdock", "cardoon",
    "celeriac", "chrysanthemum", "cress", "eggplant", "jute", "kohlrabi", "lambsquarters", "lotus root", "pokeberry",
    "purslane", "salsify", "swamp cabbage", "winged beans", "yambean", "borage", "dock", "pickle relish", "celery", "parsnip",
    "rutabaga", "fiddlehead", "amaranth", "bok choy", "cassava", "chard", "chayote", "chives", "jew's ear", "sauerkraut",
    "waterchestnuts", "waxgourd", "parsley", "shallot", "hearts of palm", "nopales", "cucumber", "seaweed", "fireweed",
    "broccoli raab", "celtuce", "alfalfa seeds", "beet greens", "willow", "agutuk", "arugula", "watercress", "radicchio",
    "fennel", "garlic", "escarole", "endive", "coriander", "tomatillo", "pimento", "ginger", "chicory", "sesbania flowers",
)
STARCH_WORDS = (
    "grains", "cereal", "pasta", "bread", "bagel", "roll", "tortilla", "pancake", "waffle", "muffin", "english muffin",
    "croissant", "biscuit", "spaghetti", "vermicelli", "rice", "croutons", "bread crumbs", "bread stuffing", "taco shell",
    "pasta mix", "french toast", "ice cream cone", "meal replacement (cereal)", "cracker",
)
PROTEIN_WORDS = (
    "fish", "pork", "beef", "chicken", "game meat", "turkey", "veal", "lamb", "sausage", "deli-meat", "mollusks", "crustaceans",
    "goose", "egg", "ostrich", "duck", "emu", "tofu", "beans", "lentils", "soybeans", "soybean", "broadbeans", "cowpeas",
    "black-eyed peas", "chickpeas", "refried beans", "pheasant", "quail", "squab", "poultry", "ham", "wiener", "meat stick",
    "meat sticks", "ptarmigan", "spruce grouse", "guinea", "crusteceans", "chicken spread", "liver sausage", "pâté", "cretons",
    "lupins", "moth beans", "egg substitute", "meatless", "soy flour", "soybean kernels", "whey", "peanut flour",
)
DAIRY_WORDS = ("cheese", "yogourt", "yogurt", "milk", "cream", "kefir", "butter", "margarine", "whey")
FAT_WORDS = (
    "nuts", "seeds", "peanuts", "peanut butter", "vegetable oil", "shortening", "animal fat", "fish oil", "butter oil",
    "hummus", "oil", "olive",
)
DISH_WORDS = (
    "fast foods", "fast food", "chinese dish", "indian", "macaroni and cheese", "lasagna", "burrito", "egg roll", "ravioli",
    "tamale", "taquito", "pizza", "sandwich", "chicken nuggets", "chicken patty", "chicken breast tenders", "chop suey",
    "cheese souffle", "corn fritter", "beef pot roast", "fried chicken", "meat loaf", "sliced turkey", "cheese fondue",
    "potato puff", "onion rings", "poultry food products", "turnover", "spaghetti with", "spaghetti and",
)
SNACK_WORDS = (
    "dessert", "candies", "snacks", "cookie", "sweets", "cake", "pie", "granola bar", "doughnut", "danish pastry", "sweet roll",
    "toaster pastry", "puff pastry", "cream puff", "cheesecake", "coffee cake", "pie crust", "candied foods", "icing",
    "dessert topping", "chocolate",
)
DRINK_WORDS = (
    "alcohol", "drink", "coffee", "plant-based beverage", "carbonated drinks", "juice", "tea", "hot chocolate", "energy drink",
    "beverage", "vitamin water", "malted milk", "lemonade", "limeade", "water", "sports drink", "milk shake", "eggnog",
    "instant breakfast", "coffee substitute", "yogourt beverage", "vegetable juice", "nectar", "coffee whitener",
)
CONDIMENT_WORDS = (
    "salad dressing", "spices", "sauce", "gravy", "peanut butter", "jam type spread", "sweetener", "vinegar", "agave",
    "tomato ketchup", "soy sauce", "sandwich spread", "dip", "chocolate syrup", "seasoning mix", "salt", "basil",
    "vanilla extract", "leavening agent", "spread", "tomato products", "guava sauce", "cranberry orange relish",
)


def first_token(name):
    return name.split(",")[0].strip().lower()


def word_pattern(words):
    """One regex that finds any of the words as whole words (a hyphen or an apostrophe does not split a word)."""
    return re.compile(r"(?<![\w-])(?:" + "|".join(re.escape(w) for w in sorted(words, key=len, reverse=True)) + r")(?![\w-])")


DRINKS = word_pattern(DRINK_WORDS)
CONDIMENTS = word_pattern(CONDIMENT_WORDS)
DISHES = word_pattern(DISH_WORDS)
SNACKS = word_pattern(SNACK_WORDS)
FATS = word_pattern(FAT_WORDS)
DAIRY = word_pattern(DAIRY_WORDS)
STARCHES = word_pattern(STARCH_WORDS)
PROTEINS = word_pattern(PROTEIN_WORDS)
FRUITS = word_pattern(FRUIT_WORDS)
VEGETABLES = word_pattern(VEGETABLE_WORDS)
SNAP_BEANS = re.compile(r"\b(snap|green|yellow|wax|string|french|italian)\b")


def classify(name_en):
    """The family (a `FoodCategory` raw value of the app) of a CNF food, or None when the rules do not know it."""
    whole = name_en.lower()
    token = first_token(name_en)
    # The order matters: « orange juice » is not a fruit, « milk shake » is not milk, « cheese sauce » is a sauce.
    if token == "coffee cake":
        return "snacks"
    if DRINKS.search(token):
        return "drinks"
    if token in ("peanut butter", "hummus"):
        return "fats"
    if CONDIMENTS.search(token) or "spread" in token:
        return "condiments"
    if DISHES.search(token):
        return "dishes"
    if SNACKS.search(token):
        return "snacks"
    if FATS.search(token):
        return "fats"
    if DAIRY.search(token):
        return "dairy"
    if token in ("soup", "soups"):
        return "dishes"
    if token == "beans" and SNAP_BEANS.search(whole):
        return "vegetables"
    if STARCHES.search(token):
        return "starches"
    if PROTEINS.search(token):
        return "proteins"
    if FRUITS.search(token):
        return "fruits"
    if VEGETABLES.search(token):
        return "vegetables"
    if "juice" in whole:
        return "drinks"
    return None


NOT_SERVED = re.compile(r"\b(dry|dried|dehydrated|powder|powdered|flour|mix|concentrate|condensed|unprepared|uncooked|granules|crystals)\b", re.I)
RAW = re.compile(r"\braw\b", re.I)


def is_eaten_as_served(name_en, family):
    """False for a powder, a dry or condensed product, and (for starches and proteins) a raw one."""
    if NOT_SERVED.search(name_en):
        return False
    if family in ("starches", "proteins") and RAW.search(name_en):
        return False
    return True


# ---------------------------------------------------------------- densities

def volume_ml(measure):
    """(millilitres, kind) of a CNF measure text, or None when the measure is not a volume.

    kind: « plain » (« 125ml »: a cup of the food as the file describes it), « pieces » (« 250ml chopped »,
    « 125ml cubes »: a cup of cut pieces, air gaps included) or « container » (« 1 can (284 ml) »: the
    contents of a container, a true density)."""
    leading = VOLUME_LEADING.match(measure)
    if leading:
        value = float(leading.group(1).replace(",", "."))
        qualifier = measure[leading.end():].strip(" ,")
        return (value, "pieces" if qualifier else "plain") if value > 0 else None
    inside = VOLUME_IN_PARENTHESES.search(measure)
    if inside:
        value = float(inside.group(1).replace(",", "."))
        return (value, "container") if value > 0 else None
    return None


def median(values):
    ordered = sorted(values)
    middle = len(ordered) // 2
    return ordered[middle] if len(ordered) % 2 else (ordered[middle - 1] + ordered[middle]) / 2


def quantile(values, q):
    """Linear interpolation between the closest ranks (same as numpy's default)."""
    ordered = sorted(values)
    position = (len(ordered) - 1) * q
    low, high = int(math.floor(position)), int(math.ceil(position))
    return ordered[low] + (ordered[high] - ordered[low]) * (position - low)


def spread_of_log(values):
    """Standard deviation of ln(density)."""
    logs = [math.log(v) for v in values]
    mean = sum(logs) / len(logs)
    return math.sqrt(sum((x - mean) ** 2 for x in logs) / max(1, len(logs) - 1))


def category_record(values):
    return {
        "n": len(values),
        "gPerMl": round(median(values), 3),
        "p25": round(quantile(values, 0.25), 3),
        "p75": round(quantile(values, 0.75), 3),
        "spreadLog": round(spread_of_log(values), 3),
    }


def build(rows):
    foods = []
    rejected = 0
    no_volume = 0
    densities_by_family = {}
    all_served = []
    classified = {}
    measured_ids = set()
    for row in rows:
        fid, name_en, grams = row[ID], row[NAME_EN], row[SERVING_GRAMS]
        family = classify(name_en)
        measures = []
        for measure in (row[SERVING_EN],):
            found = volume_ml(measure)
            if found is not None and isinstance(grams, (int, float)) and grams > 0:
                measures.append((grams / found[0], measure, grams, found[1]))
        if not measures:
            no_volume += 1
        else:
            kept = [m for m in measures if MIN_DENSITY <= m[0] <= MAX_DENSITY]
            if not kept:
                rejected += 1
            else:
                density = median([m[0] for m in kept])
                _, measure, measure_grams, kind = min(kept, key=lambda m: abs(m[0] - density))
                foods.append([fid, round(density, 3), measure, round(float(measure_grams), 1), kind])
                measured_ids.add(fid)
                if is_eaten_as_served(name_en, family):
                    all_served.append(density)
                    if family:
                        densities_by_family.setdefault(family, []).append(density)
        if family and fid not in measured_ids:
            classified.setdefault(family, []).append(fid)
    categories = {name: category_record(values) for name, values in sorted(densities_by_family.items())}
    result = {
        "format": 1,
        "source": "App/Resources/cnf-foods.json (Fichier canadien sur les éléments nutritifs 2015, Santé Canada)",
        "licence": "Open Government Licence - Canada (docs/licences-nutrition.md)",
        "filter": {"minGPerMl": MIN_DENSITY, "maxGPerMl": MAX_DENSITY},
        "counts": {"cnfFoods": len(rows), "measured": len(foods), "rejectedByFilter": rejected, "noVolumeMeasure": no_volume},
        "columns": ["cnfId", "gPerMl", "measure", "measureGrams", "kind"],
        "foods": foods,
        "overall": category_record(all_served),
        "categories": categories,
        "familyOfOtherFoods": {name: sorted(ids) for name, ids in sorted(classified.items())},
    }
    return result


def render(result):
    return json.dumps(result, ensure_ascii=False, separators=(",", ":")) + "\n"


def main():
    with open(SOURCE, encoding="utf-8") as f:
        rows = json.load(f)
    text = render(build(rows))
    if "--check" in sys.argv:
        current = ""
        if os.path.exists(OUT):
            with open(OUT, encoding="utf-8") as f:
                current = f.read()
        if current != text:
            print("food-densities.json is not up to date: run python3 scripts/build_food_densities.py")
            sys.exit(1)
        print("food-densities.json is up to date")
        return
    with open(OUT, "w", encoding="utf-8", newline="\n") as f:
        f.write(text)
    result = json.loads(text)
    counts = result["counts"]
    print(f"{counts['measured']} densities ({counts['rejectedByFilter']} rejected by the 0.15-2.0 filter, "
          f"{counts['noVolumeMeasure']} foods without a volume measure) -> {OUT} ({os.path.getsize(OUT) // 1024} KB)")
    for name, record in result["categories"].items():
        print(f"  {name:11s} n={record['n']:4d} median={record['gPerMl']:.3f} quartiles={record['p25']:.3f}-{record['p75']:.3f} spread={record['spreadLog']:.3f}")


if __name__ == "__main__":
    main()
