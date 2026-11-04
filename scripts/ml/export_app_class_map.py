"""Écrit `App/Resources/Models/ArdaneFoodClassMap.json` : pour chaque sortie du classifieur Core ML (dans l'ordre de ses probabilités),
l'étiquette (`mfr:<classe>`) et l'aliment d'Ardane de la `class_map.csv` RELUE (vide : aucun aliment ne convient).

    python scripts/ml/export_app_class_map.py --classes <...>/ArdaneFoodClassifierBM.classes.json

L'ordre vient du `.classes.json` écrit à l'export du modèle (champ `index`) ; toutes les lignes de class_map.csv doivent être relues
(`methode` = manuel), sinon rien n'est écrit. Corriger un aliment ne demande ni ré-entraînement ni ré-export : relire, appliquer
(`apply_class_review.py`), relancer ce script.
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent
REPO = SCRIPT_DIR.parent.parent
sys.path.insert(0, str(SCRIPT_DIR))

from class_matching import read_class_map  # noqa: E402


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--classes", required=True, help="<modèle>.classes.json de l'export Core ML")
    ap.add_argument("--class-map", default=str(SCRIPT_DIR / "class_map.csv"))
    ap.add_argument("--out", default=str(REPO / "App" / "Resources" / "Models" / "ArdaneFoodClassMap.json"))
    args = ap.parse_args()

    exported = json.loads(Path(args.classes).read_text(encoding="utf-8"))
    classes = sorted(exported["classes"], key=lambda c: c["index"])
    if [c["index"] for c in classes] != list(range(len(classes))):
        print("indices du classifieur non contigus")
        return 1
    rows = {r["classe"]: r for r in read_class_map(Path(args.class_map))}
    unreviewed = [c["name"] for c in classes if rows.get(c["name"], {}).get("methode") != "manuel"]
    if unreviewed:
        print(f"{len(unreviewed)} classes non relues, par exemple {unreviewed[:5]}")
        return 1
    payload = {"about": "Généré par scripts/ml/export_app_class_map.py depuis class_map.csv relue. Ne pas modifier à la main.",
               "model": "ArdaneFoodClassifier " + str(exported.get("version", "")),
               "labels": [c["label"] for c in classes],
               "foods": [rows[c["name"]]["id_ardane"] for c in classes]}
    out = Path(args.out)
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(payload, ensure_ascii=False, separators=(",", ":")) + "\n", encoding="utf-8")
    print(f"{len(classes)} classes, {sum(1 for f in payload['foods'] if f)} avec un aliment ; écrit : {out}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
