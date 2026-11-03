"""Builds the Ardane food pack: App/Resources/ardane-food.sqlite (read-only SQLite), docs/scanner/food-db-report.md and
scripts/food_db/ATTRIBUTIONS.md. Python standard library only.

    python3 -I scripts/food_db/download.py     # once: the open files (pinned in sources.lock.json, kept outside the repo)
    python3 -I scripts/food_db/build.py

Golden rule: no value is ever merged or averaged between sources. Each food keeps the values of ONE source (the
Canadian Nutrient File 2026, or USDA SR Legacy for the foods the Canadian file does not have), each value keeps its
provenance, an unknown value is a missing row. The build is deterministic: the same files give the same pack (up to
the version of SQLite that writes it).
"""
import argparse
import collections
import hashlib
import json
import os
import re
import sqlite3
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
ROOT = os.path.dirname(os.path.dirname(HERE))

import common  # noqa: E402
import download  # noqa: E402
import fcen  # noqa: E402
import usda  # noqa: E402

SR_ID_BASE = 100000
SCHEMA_VERSION = 1
APPLICATION_ID = 0x41524446  # « ARDF »
USDA_CATEGORY_OFFSET = 100

# Quality flags (food.qc).
QC_ENERGY, QC_MACROS, QC_FIBRE, QC_SUGARS, QC_SATURATED = 1, 2, 4, 8, 16
QC_NAMES = {QC_ENERGY: "énergie incohérente", QC_MACROS: "somme des macros au-dessus de 100 g", QC_FIBRE: "fibres au-dessus des glucides",
            QC_SUGARS: "sucres au-dessus des glucides", QC_SATURATED: "saturés au-dessus des lipides"}
ENERGY_TOLERANCE_KCAL = 15.0
ENERGY_TOLERANCE_RATIO = 0.15
MACRO_SUM_LIMIT = 101.0
ORDER_TOLERANCE_G = 0.1

HOUSEHOLD, REFUSE, CONVERSION = 6, 3, 9
KIND_NAMES_FR = {HOUSEHOLD: "mesure ménagère", REFUSE: "partie non comestible", CONVERSION: "autre conversion"}
SERVING_RANGE = (5.0, 600.0)
BARE_100 = re.compile(r"^\s*100\s*(ml|g)\s*$", re.I)


def parse_arguments():
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("--db", default=os.path.join(ROOT, "App", "Resources", "ardane-food.sqlite"))
    parser.add_argument("--report", default=os.path.join(ROOT, "docs", "scanner", "food-db-report.md"))
    parser.add_argument("--attributions", default=os.path.join(HERE, "ATTRIBUTIONS.md"))
    parser.add_argument("--old-foods", default=os.path.join(ROOT, "App", "Resources", "cnf-foods.json"),
                        help="the file of the 2015 edition shipped so far, for the table of old identifiers")
    return parser.parse_args()


# ---------------------------------------------------------------------------------------------------------
# Checks on one food
# ---------------------------------------------------------------------------------------------------------

def energy_from_macros(values):
    """4 kcal per gram of protein and carbohydrate, 9 per gram of fat, 7 per gram of alcohol (general Atwater factors),
    or None when a macro is unknown."""
    protein, carbs, fat = values.get(203), values.get(205), values.get(204)
    if protein is None or carbs is None or fat is None:
        return None
    return 4 * protein + 4 * carbs + 9 * fat + 7 * (values.get(221) or 0)


def quality_flags(values):
    """(bit flags, energy computed from the macros). A flag is a warning to look at, nothing is corrected."""
    flags = 0
    kcal = values.get(208)
    computed = energy_from_macros(values)
    if kcal is not None and computed is not None and abs(kcal - computed) > max(ENERGY_TOLERANCE_KCAL, ENERGY_TOLERANCE_RATIO * kcal):
        flags |= QC_ENERGY
    protein, carbs, fat = values.get(203), values.get(205), values.get(204)
    if protein is not None and carbs is not None and fat is not None and protein + carbs + fat + (values.get(221) or 0) > MACRO_SUM_LIMIT:
        flags |= QC_MACROS
    if carbs is not None:
        if values.get(291) is not None and values[291] > carbs + ORDER_TOLERANCE_G:
            flags |= QC_FIBRE
        if values.get(269) is not None and values[269] > carbs + ORDER_TOLERANCE_G:
            flags |= QC_SUGARS
    if fat is not None and values.get(606) is not None and values[606] > fat + ORDER_TOLERANCE_G:
        flags |= QC_SATURATED
    return flags, computed


def choose_preferred(rows):
    """Index of the serving proposed by default among (label, grams) rows of household measures. Valid: 5 to 600 g, not a
    bare « 100 g » or « 100 ml ». Among the valid ones: a « medium » one, else a measure written in grams (« 195 g »,
    the amount the Canadian file gives for the food as eaten), else the first of the file."""
    valid = [i for i, (label, grams) in enumerate(rows) if SERVING_RANGE[0] <= grams <= SERVING_RANGE[1] and not BARE_100.match(label)]
    if not valid:
        return None
    for i in valid:
        if re.search(r"\bmedium\b", rows[i][0], re.I):
            return i
    for i in valid:
        if re.match(r"^\s*\d+(?:\.\d+)?\s*g\s*$", rows[i][0], re.I):
            return i
    return valid[0]


# ---------------------------------------------------------------------------------------------------------
# Assembly
# ---------------------------------------------------------------------------------------------------------

def assemble(args, lock):
    fcen_path = download.path_of("fcen2026")
    sr_path = download.path_of("usda_sr_legacy")
    stats = collections.OrderedDict()

    # ---- Canadian Nutrient File 2026 ------------------------------------------------------------------
    canadian = fcen.load(fcen_path)
    omegas_added = fcen.add_derived_omegas(canadian["amounts"])
    stats["fcen_foods_in_file"] = len(canadian["foods"])
    stats["fcen_nutrients_in_file"] = len(canadian["nutrients"])
    stats["fcen_conversions_in_file"] = len(canadian["conversions"])
    stats["fcen_amount_rows_kept"] = sum(len(v) for v in canadian["amounts"].values())

    foods = {}          # id → row dict
    values = {}         # id → {nutrient: (value, se, n, src)}
    prep_conflicts = []
    baby_fcen = 0
    no_energy_fcen = 0
    for code, food in sorted(canadian["foods"].items()):
        if food["group"] == fcen.BABY_FOODS_GROUP:
            baby_fcen += 1
            continue
        food_values = canadian["amounts"].get(code, {})
        if 208 not in food_values:
            no_energy_fcen += 1
            continue
        state, ambiguous = common.prep_state(food["en"], food["fr"])
        if ambiguous:
            prep_conflicts.append((code, food["en"], food["fr"]))
        foods[code] = {"id": code, "source": common.SRC_FCEN, "name_fr": food["fr"], "name_en": food["en"], "alt_fr": food["alt_fr"],
                       "alt_en": food["alt_en"], "grp": food["group"], "origin": food["origin"], "ndb": food["ndb"], "prep": state}
        values[code] = {n: v for n, v in food_values.items() if n in common.KEPT_NUTRIENTS or n in (common.OMEGA3, common.OMEGA6)}
    stats["fcen_baby_foods_left_out"] = baby_fcen
    stats["fcen_without_energy_left_out"] = no_energy_fcen
    stats["fcen_foods"] = sum(1 for f in foods.values() if f["source"] == common.SRC_FCEN)
    stats["omegas_added"] = omegas_added

    fcen_ndb = {f["ndb"] for f in canadian["foods"].values() if f["ndb"]}
    fcen_units = {code: n["unit"] for code, n in canadian["nutrients"].items() if code in common.KEPT_NUTRIENTS}

    # ---- USDA SR Legacy, the foods the Canadian file does not have -------------------------------------
    sr = usda.load_sr(sr_path, fcen_ndb, fcen_units)
    stats["sr_foods_already_in_fcen"] = sr["already_in_fcen"]
    stats["sr_baby_foods_left_out"] = sr["skipped_baby"]
    stats["sr_unit_mismatch"] = sr["unit_mismatch"]
    sr_id = {}
    no_energy_sr = 0
    for fdc, food in sorted(sr["foods"].items(), key=lambda item: int(item[1]["ndb"]) if item[1]["ndb"].isdigit() else 10 ** 9):
        if not food["ndb"].isdigit():
            continue
        food_values = sr["amounts"].get(fdc, {})
        if 208 not in food_values:
            no_energy_sr += 1
            continue
        identifier = SR_ID_BASE + int(food["ndb"])
        state, _ = common.prep_state(food["en"], None)
        foods[identifier] = {"id": identifier, "source": common.SRC_SR, "name_fr": None, "name_en": food["en"], "alt_fr": None, "alt_en": None,
                             "grp": USDA_CATEGORY_OFFSET + food["group"], "origin": None, "ndb": food["ndb"], "prep": state}
        values[identifier] = food_values
        sr_id[fdc] = identifier
    stats["sr_foods"] = len(sr_id)
    stats["sr_without_energy_left_out"] = no_energy_sr

    # ---- Quality flags -----------------------------------------------------------------------------------
    flagged = collections.defaultdict(list)
    for identifier, food in foods.items():
        plain = {n: v[0] for n, v in values[identifier].items()}
        flags, computed = quality_flags(plain)
        food["qc"] = flags
        food["computed_kcal"] = computed
        for bit in (QC_ENERGY, QC_MACROS, QC_FIBRE, QC_SUGARS, QC_SATURATED):
            if flags & bit:
                flagged[bit].append(identifier)

    # ---- Measures, portions, densities -------------------------------------------------------------------
    measures = {}       # id → (label_en, label_fr, ml)
    portions = []       # (food_id, measure_id, grams, kind, pos, preferred)
    densities = []      # (food_id, measure_id, g_per_ml, kind)
    density_dropped = 0
    density_candidates = 0
    household_by_food = collections.defaultdict(list)
    other_by_food = collections.defaultdict(list)
    for code, kind, measure, grams in canadian["conversions"]:
        if code not in foods:
            continue
        if kind == HOUSEHOLD:
            if grams > 0:
                household_by_food[code].append((measure, grams))
        elif grams >= 0 and (kind == REFUSE or grams > 0):
            other_by_food[code].append((kind, measure, grams))
    for code in sorted(foods):
        if foods[code]["source"] != common.SRC_FCEN:
            continue
        household = household_by_food.get(code, [])
        labels = [(canadian["measure_names"][m][0], g) for m, g in household]
        preferred = choose_preferred(labels)
        for position, (measure, grams) in enumerate(household, start=1):
            label_en, label_fr = canadian["measure_names"][measure]
            volume = fcen.volume_of(label_en)
            measures[measure] = (label_en, label_fr or None, volume[0] if volume else None)
            portions.append((code, measure, grams, HOUSEHOLD, position, 1 if preferred == position - 1 else None))
            if volume and volume[0] > 0:
                density_candidates += 1
                density = grams / volume[0]
                if fcen.DENSITY_RANGE[0] <= density <= fcen.DENSITY_RANGE[1]:
                    densities.append((code, measure, density, volume[1]))
                else:
                    density_dropped += 1
        for position, (kind, measure, grams) in enumerate(other_by_food.get(code, []), start=1):
            label_en, label_fr = canadian["measure_names"][measure]
            measures.setdefault(measure, (label_en, label_fr or None, None))
            portions.append((code, measure, grams, kind, position, None))

    # SR Legacy portions have free labels: measure ids from 10000, in the order of the sorted labels.
    sr_labels = sorted({p["label"] for fdc in sr_id for p in sr["portions"].get(fdc, [])})
    sr_measure = {label: 10000 + i for i, label in enumerate(sr_labels)}
    sr_ml = {}
    for fdc in sr_id:
        for p in sr["portions"].get(fdc, []):
            if p["volume_ml"]:
                sr_ml[p["label"]] = p["volume_ml"]
    for label, identifier in sr_measure.items():
        measures[identifier] = (label, None, sr_ml.get(label))
    for fdc, identifier in sorted(sr_id.items(), key=lambda item: item[1]):
        rows = sr["portions"].get(fdc, [])
        labels = [(p["label"], p["grams"]) for p in rows]
        preferred = choose_preferred(labels)
        seen = set()
        for position, p in enumerate(rows, start=1):
            measure = sr_measure[p["label"]]
            if (identifier, measure) in seen:
                continue
            seen.add((identifier, measure))
            portions.append((identifier, measure, p["grams"], HOUSEHOLD, position, 1 if preferred == position - 1 else None))
            if p["volume_ml"]:
                density_candidates += 1
                density = p["grams"] / p["volume_ml"]
                if fcen.DENSITY_RANGE[0] <= density <= fcen.DENSITY_RANGE[1]:
                    densities.append((identifier, measure, density, usda.sr_density_kind(p["qualifier"])))
                else:
                    density_dropped += 1
    portions.sort(key=lambda p: (p[0], p[3] != HOUSEHOLD, p[4], p[1]))
    densities.sort(key=lambda d: (d[0], d[1]))
    stats["density_candidates"] = density_candidates
    stats["density_dropped"] = density_dropped

    # ---- Cooking yields ------------------------------------------------------------------------------------
    yields = usda.load_yields(download.path_of("usda_yields"))
    by_ndb = collections.defaultdict(list)
    for identifier, food in foods.items():
        if food["ndb"]:
            by_ndb[food["ndb"]].append(identifier)
    raw_ndb = {}
    for ndb, description in sr["ndb_descriptions"].items():
        raw_ndb[description.strip().lower()] = ndb
    links = []
    unlinked = []
    for row in yields:
        cooked = sorted(by_ndb.get(row["ndb"], [])) if row["ndb"] else []
        raw_candidates = sorted(by_ndb.get(raw_ndb.get(row["raw_description"].strip().lower() + ", raw", ""), []))
        if not cooked:
            unlinked.append(row)
            continue
        for identifier in cooked:
            same_source = [r for r in raw_candidates if foods[r]["source"] == foods[identifier]["source"]]
            raw = (same_source or raw_candidates or [None])[0]
            links.append((identifier, raw, row["method"], row["percent"], row["n"], row["sd"], row["minimum"], row["maximum"],
                          row["moisture"], row["fat"], common.SRC_YIELDS))
    links.sort(key=lambda link: (link[0], link[2], link[3]))
    stats["yield_rows"] = len(yields)
    stats["yield_links"] = len(links)
    stats["yield_unlinked"] = unlinked

    # ---- Old identifiers -------------------------------------------------------------------------------------
    aliases, unresolved, alias_stats = build_aliases(args.old_foods, foods)
    stats["alias"] = alias_stats

    # ---- Validation of the derived omega totals against the 2015 edition ------------------------------------
    stats["omega_validation"] = validate_omegas(args.old_foods, values)

    return {"foods": foods, "values": values, "measures": measures, "portions": portions, "densities": densities, "links": links,
            "aliases": aliases, "unresolved": unresolved, "canadian": canadian, "sr": sr, "sr_id": sr_id, "flagged": flagged,
            "prep_conflicts": prep_conflicts, "stats": stats, "lock": lock}


def build_aliases(old_foods_path, foods):
    """`cnf.<FoodID 2015>` → current food. Same number for the 2015 FoodID that were FoodCode (all below 10000): nothing to
    store. Others: through the FoodCode 2015 (list of the 2015 edition by exact English name), then by exact English name."""
    with open(old_foods_path, encoding="utf-8") as handle:
        old = json.load(handle)
    with open(download.path_of("fcen2015_foods"), encoding="utf-8") as handle:
        api = json.load(handle)
    code_by_name = {}
    ambiguous_names = set()
    for item in api:
        key = item["food_description"].strip().lower()
        if key in code_by_name and code_by_name[key] != item["food_code"]:
            ambiguous_names.add(key)
        code_by_name[key] = item["food_code"]
    current_by_name = collections.defaultdict(list)
    for identifier, food in foods.items():
        if food["source"] == common.SRC_FCEN:
            current_by_name[food["name_en"].strip().lower()].append(identifier)

    aliases, unresolved = [], []
    counts = collections.Counter()
    for row in old:
        old_id, name_fr, name_en = int(row[0]), row[1], row[2]
        key = name_en.strip().lower()
        if old_id <= 9999 and old_id in foods and foods[old_id]["source"] == common.SRC_FCEN:
            counts["same number"] += 1
            continue
        code = code_by_name.get(key) if key not in ambiguous_names else None
        if code is not None and code in foods and foods[code]["source"] == common.SRC_FCEN:
            aliases.append((f"cnf.{old_id}", code, 1))
            counts["FoodCode 2015"] += 1
            continue
        same_name = current_by_name.get(key, [])
        if len(same_name) == 1:
            aliases.append((f"cnf.{old_id}", same_name[0], 2))
            counts["English name"] += 1
            continue
        unresolved.append((old_id, name_en, name_fr))
        counts["unresolved"] += 1
    aliases.sort()
    counts["total"] = len(old)
    return aliases, unresolved, counts


def validate_omegas(old_foods_path, values):
    """How the derived totals compare with the omega-3 and omega-6 the 2015 edition published (columns 27 and 28 of the
    old file), for the foods that kept their number. Information for the report, nothing is adjusted."""
    with open(old_foods_path, encoding="utf-8") as handle:
        old = json.load(handle)
    result = {}
    for column, nutrient, name in ((27, common.OMEGA3, "oméga-3"), (28, common.OMEGA6, "oméga-6")):
        compared = close = 0
        for row in old:
            identifier = int(row[0])
            published = row[column] if column < len(row) else None
            if published is None or identifier not in values:
                continue
            derived = values[identifier].get(nutrient)
            compared += 1
            if derived is not None and abs(derived[0] - published) <= 0.011:
                close += 1
        result[name] = (compared, close)
    return result


# ---------------------------------------------------------------------------------------------------------
# SQLite
# ---------------------------------------------------------------------------------------------------------

def pack_provenance(src, observations, error):
    """The provenance of a value in ONE integer (nutrient_value.prov), 0 bytes more than needed in SQLite:
    bits 0-6 = source code + 1 (0: none), bits 7-18 = observations (0: none), bits 19+ = standard error x 10000
    (0: none). Raises if a number does not fit or the error has more than 4 decimals: nothing is rounded."""
    if src is None and observations is None and error is None:
        return None
    field = 0 if src is None else src + 1
    if not 0 <= field < 128:
        raise ValueError(f"code de source hors limites : {src}")
    packed = field
    if observations is not None:
        if not 0 < observations < 4096:
            raise ValueError(f"nombre d'observations hors limites : {observations}")
        packed |= observations << 7
    if error is not None:
        scaled = round(error * 10000)
        if abs(scaled / 10000 - error) > 1e-9 or scaled >= 1 << 27:
            raise ValueError(f"erreur-type qui ne tient pas sur 4 décimales : {error}")
        packed |= scaled << 19
    return packed


def write_database(path, data):
    foods, values = data["foods"], data["values"]
    canadian, sr, lock = data["canadian"], data["sr"], data["lock"]
    temporary = path + ".building"
    for leftover in (temporary, temporary + "-journal"):
        if os.path.exists(leftover):
            os.remove(leftover)
    connection = sqlite3.connect(temporary)
    connection.execute("PRAGMA page_size = 4096")
    connection.execute("PRAGMA journal_mode = OFF")
    connection.execute("PRAGMA synchronous = OFF")
    with open(os.path.join(HERE, "schema.sql"), encoding="utf-8") as handle:
        connection.executescript(handle.read())

    def insert(table, rows, width):
        connection.executemany(f"INSERT INTO {table} VALUES({','.join('?' * width)})", rows)

    # source
    source_rows = [
        (common.SRC_FCEN, "fcen2026", lock["sources"]["fcen2026"]["name"], lock["sources"]["fcen2026"]["url"], lock["sources"]["fcen2026"]["sha256"],
         lock["sources"]["fcen2026"]["downloaded"], lock["sources"]["fcen2026"]["license"], lock["sources"]["fcen2026"]["license_url"]),
        (common.SRC_SR, "usda_sr_legacy", lock["sources"]["usda_sr_legacy"]["name"], lock["sources"]["usda_sr_legacy"]["url"],
         lock["sources"]["usda_sr_legacy"]["sha256"], lock["sources"]["usda_sr_legacy"]["downloaded"], lock["sources"]["usda_sr_legacy"]["license"],
         lock["sources"]["usda_sr_legacy"]["license_url"]),
        (common.SRC_YIELDS, "usda_yields", lock["sources"]["usda_yields"]["name"], lock["sources"]["usda_yields"]["url"],
         lock["sources"]["usda_yields"]["sha256"], lock["sources"]["usda_yields"]["downloaded"], lock["sources"]["usda_yields"]["license"],
         lock["sources"]["usda_yields"]["license_url"]),
    ]
    insert("source", source_rows, 8)

    # groups and origins
    used_groups = {f["grp"] for f in foods.values()}
    group_rows = []
    for code, (en, fr) in sorted(canadian["groups"].items()):
        if code in used_groups:
            group_rows.append((code, en, fr or None))
    for code, name in sorted(sr["categories"].items()):
        if USDA_CATEGORY_OFFSET + code in used_groups:
            group_rows.append((USDA_CATEGORY_OFFSET + code, name, None))
    insert("food_group", group_rows, 3)
    origins = {f["origin"] for f in foods.values() if f["origin"] is not None}
    origin_rows = sorted((int(r["Food_Source_Code"]), common.clean(r["Food_Source_Description_EN"]), common.clean(r["Food_Source_Description_FR"]) or None)
                         for r in common.csv_rows(download.path_of("fcen2026"), "Food_Source.csv") if int(r["Food_Source_Code"]) in origins)
    insert("food_origin", origin_rows, 3)

    # foods
    food_rows = [(f["id"], f["source"], f["name_fr"], f["name_en"], f["alt_fr"], f["alt_en"], f["grp"], f["origin"], f["ndb"], f["prep"], f["qc"])
                 for _, f in sorted(foods.items())]
    insert("food", food_rows, 11)

    # nutrients
    used_nutrients = sorted({n for v in values.values() for n in v})
    nutrient_rows = []
    for code in used_nutrients:
        info = common.DERIVED_NUTRIENTS.get(code) or canadian["nutrients"][code]
        nutrient_rows.append((code, info["symbol"], info["tag"], info["unit"], info["name_en"], info["name_fr"] or None, info["decimals"]))
    insert("nutrient", nutrient_rows, 7)

    # values
    value_rows = []
    for identifier in sorted(values):
        for nutrient in sorted(values[identifier]):
            value, error, observations, src = values[identifier][nutrient]
            value_rows.append((identifier, nutrient, value, pack_provenance(src, observations, error)))
    insert("nutrient_value", value_rows, 4)

    # provenance codes
    prov_rows = [(common.SRC_FCEN, code, klass, en, fr or None) for code, klass, en, fr in fcen.source_classes(canadian["nutrient_sources"])]
    used_derivations = {v[3] for fdc in data["sr_id"] for v in sr["amounts"].get(fdc, {}).values() if v[3]}
    for code, klass, label in usda.usda_provenance_rows(sr["derivations"]):
        if code in used_derivations:
            prov_rows.append((common.SRC_SR, code, klass, label, None))
    insert("prov_code", prov_rows, 5)

    # measures, portions, densities
    insert("measure", [(i, en, fr, ml) for i, (en, fr, ml) in sorted(data["measures"].items())], 4)
    insert("portion", data["portions"], 6)
    insert("density", data["densities"], 4)
    insert("prep_link", data["links"], 11)
    insert("alias", data["aliases"], 3)

    # words
    flags_of = collections.defaultdict(int)
    for identifier, f in foods.items():
        for flag, text in ((1, f["name_fr"]), (2, f["name_en"]), (4, f["alt_fr"]), (8, f["alt_en"])):
            for term in common.words(text):
                flags_of[(term, identifier)] |= flag
    insert("word", [(term, identifier, flags) for (term, identifier), flags in sorted(flags_of.items())], 3)

    # meta
    meta = [("schema_version", str(SCHEMA_VERSION)),
            ("id_scheme", f"cnf.<Food_Code> (food.id below {SR_ID_BASE}); usda.<NDB> (food.id = {SR_ID_BASE} + NDB)"),
            ("normalization", "NFKD, no combining marks, lower case, œ→oe æ→ae ß→ss ø→o ł→l đ→d; words = runs of letters and digits"),
            ("foods", str(len(foods))), ("nutrient_values", str(len(value_rows))),
            ("builder", "scripts/food_db/build.py"),
            ("rule", "no value is merged or averaged between sources; a missing row is an unknown value, never zero")]
    insert("pack_meta", sorted(meta), 2)

    connection.execute(f"PRAGMA application_id = {APPLICATION_ID}")
    connection.execute(f"PRAGMA user_version = {SCHEMA_VERSION}")
    connection.commit()
    connection.execute("VACUUM")
    check = connection.execute("PRAGMA integrity_check").fetchone()[0]
    connection.close()
    if check != "ok":
        sys.exit(f"integrity_check : {check}")
    os.replace(temporary, path)
    digest = hashlib.sha256(open(path, "rb").read()).hexdigest()
    return {"bytes": os.path.getsize(path), "sha256": digest, "sqlite": sqlite3.sqlite_version, "value_rows": len(value_rows),
            "word_rows": len(flags_of), "nutrient_rows": len(nutrient_rows)}


# ---------------------------------------------------------------------------------------------------------
# Report and attributions
# ---------------------------------------------------------------------------------------------------------

def table(headers, rows):
    lines = ["| " + " | ".join(headers) + " |", "|" + "|".join("---" for _ in headers) + "|"]
    for row in rows:
        lines.append("| " + " | ".join(str(cell).replace("|", "/") for cell in row) + " |")
    return lines


def thousands(number):
    return f"{number:,}".replace(",", " ")


def write_report(path, data, built):
    foods, values, stats, lock = data["foods"], data["values"], data["stats"], data["lock"]
    canadian, sr = data["canadian"], data["sr"]
    L = []
    L += ["---", "tags: [ardane, scanner, chantier-22, base-nutritionnelle]", "---", ""]
    L += ["# Base alimentaire Ardane (B1) : rapport de construction", ""]
    L += ["Généré par `scripts/food_db/build.py` (ne pas modifier à la main). Chantier 22, étape B1 : FCÉN 2026 en pivot, USDA SR Legacy pour les aliments sans équivalent FCÉN, rendements USDA des viandes. CIQUAL, FNDDS et Foundation viennent plus tard (B2). Règle d'or : aucune valeur n'est fusionnée ni moyennée entre sources ; une valeur absente est inconnue, jamais zéro.", ""]

    L += ["## Sources (verrou `scripts/food_db/sources.lock.json`)", ""]
    rows = []
    for key, entry in lock["sources"].items():
        rows.append((key, entry["file"], entry["downloaded"], thousands(entry["bytes"]), f"`{entry['sha256'][:16]}…`", entry["license"], entry["used_for"]))
    L += table(["Source", "Fichier", "Date", "Octets", "SHA-256 (début)", "Licence", "Usage en B1"], rows)
    L += ["", "Les fichiers bruts restent hors du dépôt (`~/ardane-tools/food-data/`) ; SHA-256 complets dans le verrou.", ""]

    L += ["## Résultat", ""]
    L += table(["Mesure", "Valeur"], [
        ("Fichier `App/Resources/ardane-food.sqlite`", f"{thousands(built['bytes'])} octets ({built['bytes'] / 1048576:.2f} Mo)"),
        ("SHA-256 du fichier (SQLite " + built["sqlite"] + ")", f"`{built['sha256']}`"),
        ("Aliments FCÉN 2026 dans la base", thousands(stats["fcen_foods"])),
        ("Aliments USDA SR Legacy sans équivalent FCÉN dans la base", thousands(stats["sr_foods"])),
        ("Total d'aliments", thousands(len(foods))),
        ("Valeurs de nutriments (une ligne par valeur connue)", thousands(built["value_rows"])),
        ("Nutriments conservés", f"{built['nutrient_rows']} (dont 2 totaux dérivés) sur {stats['fcen_nutrients_in_file']} dans le fichier canadien"),
        ("Lignes de mots de l'index de recherche", thousands(built["word_rows"])),
    ])
    L += ["", "Taille visée : moins de 12 Mo. Les nutriments laissés de côté (acides aminés, acides gras un par un, stérols, caroténoïdes, tocophérols, sucres un par un) ne sont lus par aucun écran ; le script les relit si besoin (`KEPT_NUTRIENTS` dans `common.py`).", ""]
    L += ["### Ce qui n'est pas importé", ""]
    L += table(["Exclusion", "Aliments"], [
        ("FCÉN : aliments pour bébés (groupe 3)", stats["fcen_baby_foods_left_out"]),
        ("FCÉN : sans énergie (kcal)", stats["fcen_without_energy_left_out"]),
        ("SR Legacy : déjà dans la FCÉN (même code NDB, zéros de tête ignorés)", thousands(stats["sr_foods_already_in_fcen"])),
        ("SR Legacy : aliments pour bébés", stats["sr_baby_foods_left_out"]),
        ("SR Legacy : sans énergie (kcal)", stats["sr_without_energy_left_out"]),
    ])
    if stats["sr_unit_mismatch"]:
        L += ["", "Nutriments USDA refusés (unité différente de la FCÉN) : " + ", ".join(f"{n} ({u} au lieu de {e})" for n, u, e in stats["sr_unit_mismatch"]) + ".", ""]
    L += [""]

    L += ["## Provenance des valeurs", ""]
    by_class = collections.Counter()
    for identifier, food_values in values.items():
        source = foods[identifier]["source"]
        for nutrient, (value, error, observations, src) in food_values.items():
            if source == common.SRC_FCEN:
                klass = common.FCEN_SOURCE_CLASS.get(src, 7) if src not in (common.DERIVED_OMEGA3_CODE, common.DERIVED_OMEGA6_CODE) else common.CLASS_DERIVED
            else:
                klass = None if src is None else common.USDA_SOURCE_CLASS.get(sr["derivations"].get(src, ("", "", 0))[2], 7)
            by_class[(source, klass)] += 1
    rows = []
    for (source, klass), count in sorted(by_class.items(), key=lambda item: (item[0][0], item[0][1] or 99)):
        rows.append(("FCÉN 2026" if source == common.SRC_FCEN else "USDA SR Legacy", common.CLASS_NAMES_FR.get(klass, "sans code"), thousands(count)))
    L += table(["Source", "Nature de la valeur", "Valeurs"], rows)
    L += ["", f"Chaque ligne de `nutrient_value` garde le code de source (FCÉN `Nutrient_Source_Code` ou dérivation USDA), le nombre d'observations et l'erreur-type quand le fichier les donne ; la table `prov_code` en donne le sens. Les valeurs sont celles du fichier, non arrondies (`Nutrient_Decimals` dit combien de décimales montrer).", ""]
    L += [f"**Totaux oméga-3 et oméga-6 dérivés.** Le fichier 2026 n'a plus ces deux totaux (la FCÉN 2015 les avait). Ardane les calcule, pour la FCÉN seulement, comme la somme des acides gras individuels de l'aliment (oméga-3 : 18:3, 20:3, 20:5, 22:5, 22:6 n-3 ; oméga-6 : 18:2, 18:3, 20:3, 20:4, 22:4 n-6), seulement si TOUTES les composantes sont connues ; classe « dérivé par Ardane ». {thousands(stats['omegas_added'])} totaux ajoutés. Comparaison avec ce que la FCÉN 2015 publiait, pour les aliments qui ont gardé leur numéro : " + "; ".join(f"{name} {close} égaux à 0,01 g près sur {compared} publiés" for name, (compared, close) in stats["omega_validation"].items()) + ". Les totaux publiés en 2015 ne se retrouvent donc pas toujours à partir des acides gras seuls : ils restent des estimations, marquées comme telles. Pour retirer cette dérivation, ne pas appeler `add_derived_omegas`.", ""]

    L += ["## Portions, densités, rendements", ""]
    kinds = collections.Counter(p[3] for p in data["portions"])
    L += table(["Type de mesure", "Lignes"], [(KIND_NAMES_FR[k], thousands(kinds[k])) for k in (HOUSEHOLD, REFUSE, CONVERSION)])
    foods_with_portion = len({p[0] for p in data["portions"] if p[3] == HOUSEHOLD})
    preferred = sum(1 for p in data["portions"] if p[5])
    L += ["", f"{thousands(foods_with_portion)} aliments ont au moins une mesure ménagère ; {thousands(preferred)} ont une portion proposée par défaut (de 5 à 600 g, hors « 100 g » et « 100 ml » ; une portion « moyenne » d'abord, sinon une mesure en grammes comme « 195 g », sinon la première du fichier). Les autres s'affichent « 100 g ».", ""]
    density_kinds = collections.Counter(d[3] for d in data["densities"])
    L += [f"**Densités** : {thousands(len(data['densities']))} densités sur {thousands(len({d[0] for d in data['densities']}))} aliments, dérivées des mesures en volume (grammes ÷ millilitres), gardées entre {fcen.DENSITY_RANGE[0]} et {fcen.DENSITY_RANGE[1]} g/ml ({thousands(stats['density_dropped'])} hors de l'intervalle écartées sur {thousands(stats['density_candidates'])} mesures en volume). Types : "
          + ", ".join(f"{fcen.DENSITY_KIND_NAMES_FR[k]} {thousands(density_kinds[k])}" for k in sorted(density_kinds)) + ". Une densité de FCÉN vient d'une mesure en ml (tasse = 250 ml) ou, pour l'USDA, d'une tasse, cuillère ou once liquide américaine ; ce sont des masses volumiques apparentes en vrac, pas celles d'un tas dans une assiette.", ""]
    L += [f"**Rendements de cuisson** (USDA, viandes et volailles, table Release 2) : {stats['yield_rows']} lignes lues, {stats['yield_links']} liens vers des aliments de la base par le code NDB de l'aliment cuit ; {len(stats['yield_unlinked'])} lignes sans aliment correspondant dans la base (détail plus bas). Le rendement est en pourcentage du poids cru, tel que publié ; l'aliment cru associé est cherché par le nom (« description du rendement, raw »).", ""]
    if stats["yield_unlinked"]:
        L += table(["NDB", "Description", "Méthode", "Rendement %"], [(r["ndb"] or "aucun", r["raw_description"][:80], r["method"], r["percent"]) for r in stats["yield_unlinked"]])
        L += [""]
    linked_raw = sum(1 for link in data["links"] if link[1] is not None)
    L += [f"{linked_raw} des {len(data['links'])} liens ont aussi l'aliment cru correspondant.", ""]

    L += ["## État de préparation (déduit des noms)", ""]
    states = collections.Counter((f["source"], f["prep"]) for f in foods.values())
    rows = []
    for source in (common.SRC_FCEN, common.SRC_SR):
        rows.append(("FCÉN 2026" if source == common.SRC_FCEN else "USDA SR Legacy", *[thousands(states[(source, s)]) for s in (1, 2, 3, 0)]))
    L += table(["Source", "Cru", "Cuit", "Transformé ou conservé", "Non précisé"], rows)
    L += ["", f"Le nom anglais décide ; le nom français confirme. Quand l'un dit cru et l'autre cuit, l'état reste non précisé : {len(data['prep_conflicts'])} cas.", ""]
    if data["prep_conflicts"]:
        L += table(["Code", "Anglais", "Français"], [(c, e, f) for c, e, f in data["prep_conflicts"][:30]])
        L += [""]

    L += ["## Contrôles de cohérence (drapeaux, rien n'est corrigé)", ""]
    L += [f"Énergie : écart entre les kcal publiées et 4·protéines + 4·glucides + 9·lipides + 7·alcool plus grand que max({ENERGY_TOLERANCE_KCAL:g} kcal ; {ENERGY_TOLERANCE_RATIO * 100:g} %). Somme des macros (protéines + glucides + lipides + alcool) au-dessus de {MACRO_SUM_LIMIT:g} g ; fibres, sucres au-dessus des glucides ; saturés au-dessus des lipides (tolérance {ORDER_TOLERANCE_G} g).", ""]
    rows = []
    totals = collections.Counter(f["source"] for f in foods.values())
    for bit in (QC_ENERGY, QC_MACROS, QC_FIBRE, QC_SUGARS, QC_SATURATED):
        per_source = collections.Counter(foods[i]["source"] for i in data["flagged"][bit])
        rows.append((QC_NAMES[bit], f"{per_source[common.SRC_FCEN]} ({per_source[common.SRC_FCEN] * 100 / totals[common.SRC_FCEN]:.1f} %)",
                     f"{per_source[common.SRC_SR]} ({per_source[common.SRC_SR] * 100 / max(1, totals[common.SRC_SR]):.1f} %)"))
    L += table(["Contrôle", "FCÉN 2026", "USDA SR Legacy"], rows)
    energy = sorted(data["flagged"][QC_ENERGY], key=lambda i: -abs(values[i][208][0] - foods[i]["computed_kcal"]))[:15]
    L += ["", "Plus gros écarts d'énergie :", ""]
    L += table(["Aliment", "Nom", "kcal publiées", "kcal recalculées"], [(
        ("cnf." + str(i)) if i < SR_ID_BASE else ("usda." + str(i - SR_ID_BASE)), foods[i]["name_en"][:70], f"{values[i][208][0]:g}", f"{foods[i]['computed_kcal']:.0f}") for i in energy])
    L += [""]

    L += ["## Anciens identifiants `cnf.<FoodID 2015>`", ""]
    counts = stats["alias"]
    L += table(["Résolution", "Identifiants"], [
        ("Même numéro (le FoodID 2015 était le Food_Code, inchangé) : rien à stocker", thousands(counts["same number"])),
        ("Par le FoodCode 2015 (liste officielle de l'édition 2015, nom anglais exact) : ligne dans `alias`", thousands(counts["FoodCode 2015"])),
        ("Par le nom anglais exact dans l'édition 2026 : ligne dans `alias`", thousands(counts["English name"])),
        ("Non résolus (retirés, renommés ou aliments pour bébés)", thousands(counts["unresolved"])),
        ("Total dans `cnf-foods.json`", thousands(counts["total"])),
    ])
    L += ["", "Les identifiants `builtin.*` ne changent pas. Un identifiant non résolu n'a plus d'aliment : `ScanLearning` et `MealMemory` l'ignorent, le journal garde son instantané.", ""]
    L += ["### Non résolus", ""]
    L += table(["Ancien identifiant", "Nom anglais (2015)", "Nom français (2015)"], [(f"cnf.{i}", e, f) for i, e, f in data["unresolved"]])
    L += [""]
    L += ["## Limites et décisions à relire", ""]
    L += [
        "- Les noms français des aliments USDA sans équivalent FCÉN sont vides (jamais traduits automatiquement) : ils ne se trouvent qu'en tapant des mots anglais.",
        "- Aliments pour bébés non importés (trop de quasi-doublons dans la recherche, comme avant).",
        f"- Le jeu de nutriments est réduit à {built['nutrient_rows'] - 2} nutriments de la FCÉN (ceux que l'app lit, plus l'eau, les cendres, le kJ) ; la FCÉN en a {stats['fcen_nutrients_in_file']}.",
        "- `qc` est un drapeau pour regarder, pas une correction : les valeurs restent celles de la source.",
        "- Densités : masses volumiques apparentes en vrac issues de mesures ménagères, à ne pas appliquer telles quelles à un tas d'aliment sur une assiette (voir le protocole de mesure du scanner).",
        "- Les rendements USDA ne couvrent que les viandes et volailles ; pas de rendement dérivé pour les féculents en B1.",
        "- Construction déterministe à la version de SQLite près ; deux constructions de suite donnent le même fichier.",
    ]
    L += [""]
    with open(path, "w", encoding="utf-8", newline="\n") as handle:
        handle.write("\n".join(L))


def write_attributions(path, lock):
    fcen_lock = lock["sources"]["fcen2026"]
    usda_lock = lock["sources"]["usda_sr_legacy"]
    yields_lock = lock["sources"]["usda_yields"]
    text = f"""# Attributions de la base alimentaire Ardane

Généré par `scripts/food_db/build.py`. Ce n'est pas un avis juridique.

## Fichier canadien sur les éléments nutritifs (FCÉN), Santé Canada, 2026

Français : Fichier canadien sur les éléments nutritifs, Santé Canada, 2026. Contient des renseignements licenciés en vertu de la Licence du gouvernement ouvert – Canada. Ardane n'est pas une version officielle de la FCÉN, n'est pas affilié à Santé Canada ni approuvé par lui. Outil de référence, pas un avis médical.

English: Canadian Nutrient File, Health Canada, 2026. Contains information licensed under the Open Government Licence – Canada. Ardane is not an official version of the CNF and is not affiliated with or endorsed by Health Canada. Reference tool, not medical advice.

- Jeu de données : {fcen_lock['page']} (téléchargé le {fcen_lock['downloaded']}, SHA-256 {fcen_lock['sha256']})
- Licence : {fcen_lock['license_url']}
- Les valeurs de la FCÉN ne sont pas modifiées (aucun arrondi, aucune moyenne). Les totaux oméga-3 et oméga-6 sont calculés par Ardane à partir des acides gras individuels et marqués comme dérivés.

## USDA FoodData Central, SR Legacy

U.S. Department of Agriculture, Agricultural Research Service. FoodData Central, SR Legacy (avril 2018). fdc.nal.usda.gov. Domaine public (CC0 1.0).

- Fichier : {usda_lock['url']} (téléchargé le {usda_lock['downloaded']}, SHA-256 {usda_lock['sha256']})
- Seuls les aliments sans équivalent dans la FCÉN sont repris ; leurs valeurs ne sont mélangées à aucune autre source.

## USDA Table of Cooking Yields for Meat and Poultry, Release 2

U.S. Department of Agriculture, Agricultural Research Service, Nutrient Data Laboratory. USDA Table of Cooking Yields for Meat and Poultry, Release 2 (2014). Domaine public (CC0 1.0).

- Fichier : {yields_lock['url']} (téléchargé le {yields_lock['downloaded']}, SHA-256 {yields_lock['sha256']})
"""
    with open(path, "w", encoding="utf-8", newline="\n") as handle:
        handle.write(text)


def main():
    args = parse_arguments()
    problems = download.verify()
    if problems:
        sys.exit("Sources : " + "; ".join(problems))
    lock = download.load_lock()
    data = assemble(args, lock)
    built = write_database(args.db, data)
    write_report(args.report, data, built)
    write_attributions(args.attributions, lock)
    print(f"{len(data['foods'])} aliments, {built['value_rows']} valeurs, {built['bytes'] / 1048576:.2f} Mo, SHA-256 {built['sha256']}")


if __name__ == "__main__":
    main()
