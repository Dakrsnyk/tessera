"""Classifieur v4 (2026-11-04) : entraîner au niveau des ALIMENTS D'ARDANE et apprendre les plats québécois.

Pourquoi : sur les 498 classes fines de MyFoodRepo, beaucoup d'« erreurs » sont des quasi-synonymes qui mènent au même aliment d'Ardane
(café / espresso, eau / eau minérale) ; l'app additionne déjà les probabilités par aliment. Ici, les classes qui mènent au même aliment
(`class_map.csv` relue) sont FUSIONNÉES en une seule classe d'entraînement, nommée d'après sa classe la plus fournie : les étiquettes Core ML
restent `mfr:<nom>` et `export_app_class_map.py` fonctionne sans changement. Les classes sans aliment restent seules.

Deux sous-commandes :

    # 1. (PC) recadrages 224 x 224 des photos libres de droits relues (raw/quebec, collect_openverse.py) + répartition par AUTEUR
    python -I scripts/ml/derive_ardane_labels.py quebec-crops --raw <ML>/raw/quebec --out <ML>/quebec-crops
    # 2. (Kaggle ou PC) jeu de travail dérivé : classes fusionnées + plats québécois, mêmes recadrages MyFoodRepo (chemins absolus)
    python scripts/ml/derive_ardane_labels.py derive --root <ML> --src myfoodrepo --dst myfoodrepo-ardane [--quebec <dossier quebec-crops>]

Rien n'est lu du TEST pour décider quoi que ce soit : la fusion vient de la table relue, la répartition québécoise d'un tri par auteur.
"""
from __future__ import annotations

import argparse
import csv
import hashlib
import json
import sys
from collections import defaultdict
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(SCRIPT_DIR))

# classe québécoise -> (nom de classe d'entraînement, aliment d'Ardane). Tourte = tourtière (décision de l'utilisateur, 2026-11-04).
QUEBEC = {
    "poutine": ("qc-poutine", "builtin.poutine"),
    "pate-chinois": ("qc-pate-chinois", "builtin.shepherd"),
    "tourtiere": ("qc-tourtiere", "cnf.6883"),
}
QC_CLASS_ID_BASE = 990000
FILL = (124, 116, 104)          # même gris que l'app (ScannerModelLogic.cropFill) et que prepare_myfoodrepo
SIZE = 224
TEST_SHARE, VAL_SHARE = 0.20, 0.10


# --------------------------------------------------------------------------- 1. recadrages québécois

def _square_full(im):
    from PIL import Image
    w, h = im.size
    side = max(w, h)
    canvas = Image.new("RGB", (side, side), FILL)
    canvas.paste(im, ((side - w) // 2, (side - h) // 2))
    return canvas.resize((SIZE, SIZE), Image.BILINEAR)


def _square_center(im, keep: float = 0.85):
    from PIL import Image
    w, h = im.size
    side = int(min(w, h) * keep)
    left, top = (w - side) // 2, (h - side) // 2
    return im.crop((left, top, left + side, top + side)).resize((SIZE, SIZE), Image.BILINEAR)


def split_by_author(rows: list[dict]) -> dict[str, str]:
    """{fichier: split}. Toutes les photos d'un même auteur vont dans le même jeu (pas de fuite par série de photos)."""
    out = {}
    by_class = defaultdict(lambda: defaultdict(list))
    for r in rows:
        author = (r.get("creator") or "").strip().lower() or r["file"]
        by_class[r["class"]][author].append(r["file"])
    for cls, groups in by_class.items():
        total = sum(len(v) for v in groups.values())
        order = sorted(groups, key=lambda a: hashlib.sha256(f"{cls}|{a}".encode()).hexdigest())
        n_test = n_val = 0
        for author in order:
            files = groups[author]
            if n_test < TEST_SHARE * total and len(files) <= max(3, 0.1 * total):
                split, n_test = "test", n_test + len(files)
            elif n_val < VAL_SHARE * total and len(files) <= max(3, 0.1 * total):
                split, n_val = "val", n_val + len(files)
            else:
                split = "train"
            for f in files:
                out[f] = split
    return out


def quebec_crops(raw: Path, out: Path) -> None:
    from PIL import Image
    with (raw / "attributions.csv").open(encoding="utf-8") as f:
        rows = [r for r in csv.DictReader(f) if r["class"] in QUEBEC and r.get("keep", "").strip().lower() != "non"]
    splits = split_by_author(rows)
    index = []
    for r in rows:
        split = splits[r["file"]]
        with Image.open(raw / r["file"]) as im:
            im = im.convert("RGB")
            views = [("full", _square_full(im))] + ([("center", _square_center(im))] if split == "train" else [])
        stem = Path(r["file"]).stem
        for kind, crop in views:
            rel = f"{split}/{r['class']}/{stem}-{kind}.jpg"
            (out / rel).parent.mkdir(parents=True, exist_ok=True)
            crop.save(out / rel, "JPEG", quality=92)
            index.append({"crop": rel, "split": split, "class": r["class"], "food_id": QUEBEC[r["class"]][1], "kind": kind,
                          "source_file": r["file"], "creator": r.get("creator", ""), "license": r.get("license", ""),
                          "license_version": r.get("license_version", ""), "landing": r.get("landing", "")})
    with (out / "quebec_crops.csv").open("w", encoding="utf-8", newline="") as f:
        w = csv.DictWriter(f, fieldnames=list(index[0]))
        w.writeheader()
        w.writerows(index)
    counts = defaultdict(int)
    for r in index:
        counts[(r["class"], r["split"])] += 1
    for (cls, split), n in sorted(counts.items()):
        print(f"{cls:14s} {split:5s} {n}")
    print(f"{len(rows)} photos, {len(index)} recadrages -> {out}")


# --------------------------------------------------------------------------- 2. jeu de travail dérivé

def derive(root: Path, src: str, dst: str, class_map: Path, quebec: Path | None) -> dict:
    from class_matching import read_class_map

    work_src, work_dst = root / "work" / src, root / "work" / dst
    work_dst.mkdir(parents=True, exist_ok=True)
    classes = json.loads((work_src / "classes.json").read_text(encoding="utf-8"))
    cmap = {r["classe"]: r for r in read_class_map(class_map)}

    by_food: dict[str, list[dict]] = defaultdict(list)
    group_of: dict[str, str] = {}
    for c in classes:
        food = (cmap.get(c["name"], {}).get("id_ardane") or "").strip()
        if food:
            by_food[food].append(c)
        else:
            group_of[c["name"]] = c["name"]
    rep_of_food = {}
    for food, members in by_food.items():
        rep = max(members, key=lambda c: (c["n_train"], c["name"]))
        rep_of_food[food] = rep
        for m in members:
            group_of[m["name"]] = rep["name"]

    groups: dict[str, dict] = {}
    for c in classes:
        g = group_of[c["name"]]
        rep = next(x for x in classes if x["name"] == g)
        entry = groups.setdefault(g, {"class_id": rep["class_id"], "name": g, "name_readable": rep.get("name_readable", ""),
                                      "id_ardane": (cmap.get(g, {}).get("id_ardane") or "").strip(), "members": []})
        entry["members"].append(c["name"])

    qc_rows = []
    if quebec is not None:
        with (quebec / "quebec_crops.csv").open(encoding="utf-8") as f:
            qc_rows = list(csv.DictReader(f))
        for i, (qc, (name, food)) in enumerate(sorted(QUEBEC.items())):
            if food in rep_of_food:                     # l'aliment existe déjà dans MyFoodRepo : les photos rejoignent ce groupe
                groups[rep_of_food[food]["name"]]["members"].append(name)
                continue
            if name not in cmap or (cmap[name].get("id_ardane") or "").strip() != food:
                raise SystemExit(f"class_map.csv doit contenir la ligne relue « {name} » -> {food}")
            groups[name] = {"class_id": QC_CLASS_ID_BASE + i, "name": name, "name_readable": name, "id_ardane": food, "members": [name]}

    ordered = sorted(groups.values(), key=lambda g: g["name"])
    index_of = {g["name"]: i for i, g in enumerate(ordered)}
    member_to_group = {m: g["name"] for g in ordered for m in g["members"]}
    counts = defaultdict(lambda: {"train": 0, "val": 0, "test": 0})

    out_rows = []
    with (work_src / "crops.csv").open(encoding="utf-8", newline="") as f:
        reader = csv.DictReader(f)
        fields = reader.fieldnames
        name_of_index = {c["index"]: c["name"] for c in classes}
        for r in reader:
            g = member_to_group[name_of_index[int(r["class_index"])]]
            path = Path(r["crop"])
            r["crop"] = str(path if path.is_absolute() else (work_src / path).resolve())
            r["class_index"] = index_of[g]
            r["class_id"] = groups[g]["class_id"]
            counts[g][r["split"]] += 1
            out_rows.append(r)
    for i, r in enumerate(qc_rows):
        g = member_to_group[QUEBEC[r["class"]][0]]
        out_rows.append({"crop": str((quebec / r["crop"]).resolve()), "split": r["split"], "class_id": groups[g]["class_id"],
                         "class_index": index_of[g], "image": r["source_file"], "image_id": QC_CLASS_ID_BASE * 10 + i,
                         "ann_id": QC_CLASS_ID_BASE * 10 + i, "x": 0, "y": 0, "w": SIZE, "h": SIZE,
                         "group": "qc:" + hashlib.sha256(r["source_file"].encode()).hexdigest()[:10]})
        counts[g][r["split"]] += 1

    new_classes = [{"index": index_of[g["name"]], "class_id": g["class_id"], "name": g["name"], "name_readable": g["name_readable"],
                    "id_ardane": g["id_ardane"], "members": sorted(g["members"]),
                    "n_train": counts[g["name"]]["train"], "n_val": counts[g["name"]]["val"], "n_test": counts[g["name"]]["test"]}
                   for g in ordered]
    (work_dst / "classes.json").write_text(json.dumps(new_classes, ensure_ascii=False, indent=1), encoding="utf-8")
    with (work_dst / "crops.csv").open("w", encoding="utf-8", newline="") as f:
        w = csv.DictWriter(f, fieldnames=fields)
        w.writeheader()
        w.writerows(out_rows)
    meta = json.loads((work_src / "meta.json").read_text(encoding="utf-8"))
    crops_by_split = {sp: sum(1 for r in out_rows if r["split"] == sp) for sp in ("train", "val", "test")}
    meta.update({"name": dst, "derived_from": src, "n_classes": len(new_classes), "crops": crops_by_split,
                 "derivation": "classes MyFoodRepo fusionnées par aliment d'Ardane (class_map.csv relue) + photos québécoises libres de droits "
                               "(CC0, domaine public, CC BY ; auteurs dans quebec_crops.csv)" if qc_rows else
                               "classes MyFoodRepo fusionnées par aliment d'Ardane (class_map.csv relue)",
                 "quebec_crops": len(qc_rows)})
    (work_dst / "meta.json").write_text(json.dumps(meta, ensure_ascii=False, indent=1), encoding="utf-8")
    for extra in ("class_stats.csv",):
        if (work_src / extra).exists():
            (work_dst / extra).write_bytes((work_src / extra).read_bytes())
    summary = {"classes_before": len(classes), "classes_after": len(new_classes), "crops": len(out_rows), "quebec_crops": len(qc_rows),
               "merged_groups": sum(1 for g in ordered if len(g["members"]) > 1)}
    print(json.dumps(summary, ensure_ascii=False))
    return summary


if __name__ == "__main__":
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="cmd", required=True)
    q = sub.add_parser("quebec-crops")
    q.add_argument("--raw", required=True)
    q.add_argument("--out", required=True)
    d = sub.add_parser("derive")
    d.add_argument("--root", required=True)
    d.add_argument("--src", default="myfoodrepo")
    d.add_argument("--dst", default="myfoodrepo-ardane")
    d.add_argument("--class-map", default=str(SCRIPT_DIR / "class_map.csv"))
    d.add_argument("--quebec", default=None)
    a = ap.parse_args()
    if a.cmd == "quebec-crops":
        quebec_crops(Path(a.raw), Path(a.out))
    else:
        derive(Path(a.root), a.src, a.dst, Path(a.class_map), Path(a.quebec) if a.quebec else None)
