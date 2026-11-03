"""Downloads the open food-composition files used by scripts/food_db/build.py (Python standard library only).

    python3 -I scripts/food_db/download.py            # download what is missing, check the SHA-256 of what is there
    python3 -I scripts/food_db/download.py --update   # accept new bytes and rewrite scripts/food_db/sources.lock.json

The raw files are kept OUTSIDE the repository, in `$ARDANE_FOOD_DATA` or `~/ardane-tools/food-data/<id>/<file>`.
`sources.lock.json` pins every file: URL, date, size, SHA-256, licence. A file whose SHA-256 differs from the lock
stops the build (an unnoticed change of the source is never silently taken in). The archives are never extracted:
the build reads their members in memory.

Only official open-data sources are listed (licences in `docs/licences-nutrition.md`):
- Canadian Nutrient File 2026 (Health Canada, Open Government Licence – Canada), and the food list of the 2015
  edition (same publisher and licence), used only to map the old `cnf.<FoodID>` identifiers to the 2026 Food_Code;
- USDA FoodData Central: SR Legacy, FNDDS, Foundation (CC0 1.0);
- USDA Table of Cooking Yields for Meat and Poultry, Release 2 (CC0 1.0).
"""
import datetime
import hashlib
import json
import os
import sys
import urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
LOCK = os.path.join(HERE, "sources.lock.json")
USER_AGENT = "Ardane-food-db/1.0 (+https://github.com/Dakrsnyk/tessera)"
NEWLINE = chr(10)

OGL = "https://open.canada.ca/en/open-government-licence-canada"
CC0 = "https://creativecommons.org/publicdomain/zero/1.0/"
FCEN_PAGE = "https://open.canada.ca/data/dataset/1b6139bd-ed7e-4043-bc28-ff00e10f3109"
FDC_PAGE = "https://fdc.nal.usda.gov/download-datasets"
YIELD_PAGE = "https://catalog.data.gov/dataset/usda-table-of-cooking-yields-for-meat-and-poultry"

SOURCES = [
    {"id": "fcen2026", "file": "cnf_fcen_all-files-data_2026.zip",
     "name": "Fichier canadien sur les éléments nutritifs (FCÉN) 2026, 14e édition, tous les fichiers de données",
     "url": FCEN_PAGE + "/resource/019f2a90-e3a9-489d-b6e1-f74f4ba1d006/download/cnf_fcen_all-files-data_2026.zip",
     "page": FCEN_PAGE, "license": "Licence du gouvernement ouvert – Canada 2.0", "license_url": OGL,
     "used_for": "pivot : aliments, noms FR/EN, nutriments, mesures, provenance par valeur"},
    {"id": "fcen2015_foods", "file": "food2015.json",
     "name": "Fichier canadien sur les éléments nutritifs (FCÉN) 2015, liste des aliments (API officielle, food_code et nom anglais)",
     "url": "https://food-nutrition.canada.ca/api/canadian-nutrient-file/food/?lang=en&type=json",
     "page": "https://food-nutrition.canada.ca/api/canadian-nutrient-file/", "license": "Licence du gouvernement ouvert – Canada 2.0",
     "license_url": OGL, "used_for": "table d'alias : FoodCode 2015 de chaque ancien identifiant cnf.<FoodID>"},
    {"id": "usda_sr_legacy", "file": "FoodData_Central_sr_legacy_food_csv_2018-04.zip",
     "name": "USDA FoodData Central, SR Legacy (avril 2018, gelée)",
     "url": "https://fdc.nal.usda.gov/fdc-datasets/FoodData_Central_sr_legacy_food_csv_2018-04.zip",
     "page": FDC_PAGE, "license": "CC0 1.0", "license_url": CC0,
     "used_for": "aliments sans équivalent FCÉN (lien par NDB), portions"},
    {"id": "usda_fndds", "file": "FoodData_Central_survey_food_csv_2024-10-31.zip",
     "name": "USDA FoodData Central, FNDDS 2021-2023 (survey_food, 31 octobre 2024)",
     "url": "https://fdc.nal.usda.gov/fdc-datasets/FoodData_Central_survey_food_csv_2024-10-31.zip",
     "page": FDC_PAGE, "license": "CC0 1.0", "license_url": CC0,
     "used_for": "pas utilisé en B1 (plats curatés prévus en B2)"},
    {"id": "usda_foundation", "file": "FoodData_Central_foundation_food_csv_2026-04-30.zip",
     "name": "USDA FoodData Central, Foundation Foods (30 avril 2026)",
     "url": "https://fdc.nal.usda.gov/fdc-datasets/FoodData_Central_foundation_food_csv_2026-04-30.zip",
     "page": FDC_PAGE, "license": "CC0 1.0", "license_url": CC0,
     "used_for": "pas utilisé en B1"},
    {"id": "usda_yields", "file": "USDA_CookingYields_MeatPoultry02_0.csv",
     "name": "USDA Table of Cooking Yields for Meat and Poultry, Release 2 (2014, publié 2023-11-30)",
     "url": "https://ndownloader.figshare.com/files/43365402",
     "page": YIELD_PAGE, "license": "CC0 1.0", "license_url": CC0,
     "used_for": "rendements de cuisson des viandes (lien par NDB)"},
    {"id": "usda_yields_dd", "file": "USDA_CookingYields_MeatPoultry02_DD.csv",
     "name": "USDA Table of Cooking Yields, dictionnaire de données",
     "url": "https://ndownloader.figshare.com/files/43365405",
     "page": YIELD_PAGE, "license": "CC0 1.0", "license_url": CC0,
     "used_for": "documentation des colonnes des rendements"},
]


def data_dir():
    return os.environ.get("ARDANE_FOOD_DATA") or os.path.join(os.path.expanduser("~"), "ardane-tools", "food-data")


def path_of(source_id):
    """Absolute path of a source file in the data folder."""
    entry = next(s for s in SOURCES if s["id"] == source_id)
    return os.path.join(data_dir(), entry["id"], entry["file"])


def sha256_of(path):
    digest = hashlib.sha256()
    with open(path, "rb") as f:
        for block in iter(lambda: f.read(1 << 20), b""):
            digest.update(block)
    return digest.hexdigest()


def load_lock():
    if not os.path.exists(LOCK):
        return {"version": 1, "sources": {}}
    with open(LOCK, encoding="utf-8") as f:
        return json.load(f)


def fetch(url, target):
    os.makedirs(os.path.dirname(target), exist_ok=True)
    request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    temporary = target + ".part"
    with urllib.request.urlopen(request, timeout=300) as response, open(temporary, "wb") as out:
        while True:
            block = response.read(1 << 20)
            if not block:
                break
            out.write(block)
    os.replace(temporary, target)


def verify():
    """Checks every pinned file against the lock; returns the list of problems (empty = fine)."""
    lock = load_lock()["sources"]
    problems = []
    for source in SOURCES:
        path = path_of(source["id"])
        pinned = lock.get(source["id"])
        if not os.path.exists(path):
            problems.append(f"{source['id']} : fichier absent ({path}) ; lancer scripts/food_db/download.py")
        elif pinned is None:
            problems.append(f"{source['id']} : absent de sources.lock.json")
        elif sha256_of(path) != pinned["sha256"]:
            problems.append(f"{source['id']} : SHA-256 différent du verrou (source modifiée ?)")
    return problems


def main():
    update = "--update" in sys.argv
    lock = load_lock()
    today = datetime.date.today().isoformat()
    for source in SOURCES:
        path = path_of(source["id"])
        pinned = lock["sources"].get(source["id"])
        if not os.path.exists(path):
            print(f"téléchargement {source['url']}")
            fetch(source["url"], path)
        digest, size = sha256_of(path), os.path.getsize(path)
        if pinned is not None and pinned["sha256"] != digest and not update:
            sys.exit(f"{source['id']} : SHA-256 {digest} différent du verrou {pinned['sha256']} (--update pour l'accepter)")
        if pinned is None or pinned["sha256"] != digest:
            lock["sources"][source["id"]] = {
                "name": source["name"], "url": source["url"], "page": source["page"], "file": source["file"],
                "downloaded": today, "bytes": size, "sha256": digest, "license": source["license"],
                "license_url": source["license_url"], "used_for": source["used_for"]}
        else:
            # Same bytes: keep the date of the first download, refresh the descriptive fields.
            lock["sources"][source["id"]].update({
                "name": source["name"], "url": source["url"], "page": source["page"], "file": source["file"],
                "license": source["license"], "license_url": source["license_url"], "used_for": source["used_for"]})
        print(f"{source['id']:16s} {size:>11,d} octets  {digest}")
    lock["sources"] = {s["id"]: lock["sources"][s["id"]] for s in SOURCES}
    with open(LOCK, "w", encoding="utf-8", newline=NEWLINE) as f:
        json.dump(lock, f, ensure_ascii=False, indent=2)
        f.write(NEWLINE)


if __name__ == "__main__":
    main()
