"""Applique la relecture humaine `class_map_review.csv` à `class_map.csv` (lignes « manuel », conservées par class_matching).

    python scripts/ml/apply_class_review.py [--check]

`class_map_review.csv` : une ligne par classe MyFoodRepo, colonnes `classe,id_ardane,note`.
  - `id_ardane` = « = »  : la proposition automatique est juste, on la valide telle quelle ;
  - `id_ardane` vide      : aucun aliment d'Ardane ne convient (le scanner passera à la proposition suivante) ;
  - sinon                 : identifiant de la base (`builtin.*`, `cnf.*`, `usda.*`), vérifié dans le catalogue.
`note` commence par « approx » quand l'aliment choisi n'est qu'une approximation nutritionnelle (à garder en tête pour 22.6).

Toute classe de class_map.csv doit être relue, et seulement celles-là : sinon rien n'est écrit. `--check` ne fait que vérifier.
"""
from __future__ import annotations

import argparse
import sys
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(SCRIPT_DIR))

import class_matching  # noqa: E402
from ml_common import read_csv  # noqa: E402


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--class-map", default=str(SCRIPT_DIR / "class_map.csv"))
    ap.add_argument("--review", default=str(SCRIPT_DIR / "class_map_review.csv"))
    ap.add_argument("--check", action="store_true", help="vérifier sans écrire")
    args = ap.parse_args()

    rows = class_matching.read_class_map(Path(args.class_map))
    review = {r["classe"]: r for r in read_csv(Path(args.review))}
    catalog, _ = class_matching.load_catalog(SCRIPT_DIR)
    by_id = {f.id: f for f in catalog}

    problems = []
    names = {r["classe"] for r in rows}
    problems += [f"classe non relue : {n}" for n in sorted(names - review.keys())]
    problems += [f"classe inconnue dans la relecture : {n}" for n in sorted(review.keys() - names)]
    out = []
    for row in rows:
        decision = review.get(row["classe"])
        if decision is None:
            continue
        food_id = row["id_ardane"] if decision["id_ardane"] == "=" else decision["id_ardane"]
        if decision["id_ardane"] == "=" and not food_id:
            problems.append(f"{row['classe']} : « = » sur une ligne sans proposition")
        if food_id and food_id not in by_id:
            problems.append(f"{row['classe']} : identifiant absent du catalogue : {food_id}")
            continue
        food = by_id.get(food_id)
        out.append({**row, "id_ardane": food_id, "nom_ardane": (food.name_fr or food.name_en) if food else "",
                    "methode": "manuel", "score": "1.0" if food else "0.0", "a_relire": "non"})
    if problems:
        print("\n".join(problems))
        return 1
    mapped = sum(1 for r in out if r["id_ardane"])
    approx = sum(1 for r in review.values() if r["note"].startswith("approx"))
    print(f"{len(out)} classes relues : {mapped} avec un aliment d'Ardane (dont {approx} approximations), {len(out) - mapped} sans")
    if not args.check:
        class_matching.write_class_map(Path(args.class_map), out)
        print(f"écrit : {args.class_map}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
