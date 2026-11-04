"""Jeu d'entraînement du segmenteur : MyFoodRepo (COCO) -> mise en page « Roboflow COCO » attendue par RF-DETR.

    <sortie>/train/_annotations.coco.json + images        photos réparties par `prepare_myfoodrepo.py` (split « train »)
    <sortie>/valid/_annotations.coco.json + images        VALIDATION prélevée dans train (même découpe par groupes de photos que le classifieur)
    <sortie>/test/_annotations.coco.json  + images        TEST officiel = TOUTES les images du « validation 2.0 » de MyFoodRepo (jamais utilisé pour régler)

Pas de fuite : la découpe train / validation et le retrait des photos d'entraînement quasi identiques à une photo de test viennent de
`crops.csv` (écrit par `prepare_myfoodrepo.py`, empreinte dHash, groupes de photos). Une photo d'entraînement absente de crops.csv (retirée
car quasi identique à une photo de test, ou sans instance utilisable) n'est PAS dans le jeu d'entraînement du segmenteur non plus.

Annotations : instances à polygone (masque), sans les « foules » (iscrowd) pour train et validation ; le TEST garde tout (les foules y sont des
zones ignorées par l'évaluation COCO). Les identifiants de catégorie d'origine sont conservés (RF-DETR les remappe lui-même en indices contigus).
Les images sont reliées par lien symbolique (copie si le système de fichiers l'interdit) : rien de lourd n'est dupliqué.
"""
from __future__ import annotations

import csv
import hashlib
import json
import os
import shutil
from pathlib import Path


def _valid_polygon(segmentation) -> bool:
    return isinstance(segmentation, list) and any(isinstance(p, list) and len(p) >= 6 for p in segmentation)


def _link(src: Path, dst: Path) -> None:
    if dst.exists() or dst.is_symlink():
        return
    try:
        os.symlink(src, dst)
    except (OSError, NotImplementedError):
        shutil.copy2(src, dst)


def read_photo_splits(crops_csv: Path) -> dict[tuple[str, str], str]:
    """{(jeu d'origine « train » | « val », nom de fichier) : « train » | « val » | « test »} depuis crops.csv de prepare_myfoodrepo.py."""
    out: dict[tuple[str, str], str] = {}
    with open(crops_csv, encoding="utf-8", newline="") as f:
        for row in csv.DictReader(f):
            origin, name = row["image"].split("/", 1)
            out[(origin, name)] = row["split"]
    return out


def build_rfdetr_dataset(*, crops_csv: Path, train_json: Path, train_images: Path, val_json: Path, val_images: Path, out_dir: Path,
                         valid_max: int = 1500, limit_train: int = 0, limit_valid: int = 0, limit_test: int = 0, seed: str = "ardane-seg",
                         class_agnostic: bool = False) -> dict:
    """Écrit `out_dir/{train,valid,test}` et retourne les effectifs. `limit_*` : sous-ensembles (essais, mesure du débit).

    `class_agnostic` : une seule catégorie « food » (id 1) au lieu des classes fines. Le segmenteur n'a alors qu'à TROUVER les aliments ;
    le classifieur les nomme. Mesuré le 2026-11-03 : avec 498 classes, la confiance se partage entre classes proches et les aliments
    ambigus des assiettes mélangées passent sous le seuil (29 % retrouvés au seuil 0,30 sur le test, assiettes de 3 aliments et plus)."""
    splits = read_photo_splits(crops_csv)
    data = {"train": json.loads(Path(train_json).read_text(encoding="utf-8")), "val": json.loads(Path(val_json).read_text(encoding="utf-8"))}
    sources = {"train": Path(train_images), "val": Path(val_images)}
    by_image: dict[str, dict[int, list]] = {}
    for origin, d in data.items():
        by_image[origin] = {}
        for ann in d["annotations"]:
            by_image[origin].setdefault(ann["image_id"], []).append(ann)

    def rank(name: str) -> str:                  # ordre pseudo-aléatoire stable (indépendant de l'ordre du fichier)
        return hashlib.sha1(f"{seed}/{name}".encode()).hexdigest()

    chosen: dict[str, list[tuple[str, dict]]] = {"train": [], "valid": [], "test": []}
    for im in data["train"]["images"]:
        role = splits.get(("train", im["file_name"]))
        if role == "train":
            chosen["train"].append(("train", im))
        elif role == "val":
            chosen["valid"].append(("train", im))
    for im in data["val"]["images"]:
        chosen["test"].append(("val", im))
    chosen["valid"].sort(key=lambda t: rank(t[1]["file_name"]))
    chosen["valid"] = chosen["valid"][:valid_max]
    for role, limit in (("train", limit_train), ("valid", limit_valid), ("test", limit_test)):
        chosen[role].sort(key=lambda t: rank(t[1]["file_name"]))
        if limit:
            chosen[role] = chosen[role][:limit]

    # Catégories : celles qui ont au moins une instance dans l'entraînement retenu (le modèle ne peut pas en apprendre d'autres)
    used = {ann["category_id"] for origin, im in chosen["train"] for ann in by_image[origin].get(im["id"], [])
            if not ann.get("iscrowd", 0) and _valid_polygon(ann.get("segmentation"))}
    cats_all = {c["id"]: c for c in data["train"]["categories"]}
    categories = [{"id": cid, "name": cats_all[cid]["name"], "supercategory": cats_all[cid].get("supercategory") or "food"} for cid in sorted(used)]
    if len({c["name"] for c in categories}) != len(categories):
        raise RuntimeError("deux catégories portent le même nom")
    known = {c["id"] for c in categories}
    if class_agnostic:
        categories = [{"id": 1, "name": "food", "supercategory": "food"}]

    stats: dict = {"categories": len(categories), "class_agnostic": class_agnostic}
    for role, folder in (("train", "train"), ("valid", "valid"), ("test", "test")):
        target = Path(out_dir) / folder
        target.mkdir(parents=True, exist_ok=True)
        images, annotations, dropped = [], [], {"crowd": 0, "sans polygone": 0, "classe inconnue": 0, "boîte vide": 0}
        for origin, im in chosen[role]:
            src = sources[origin] / im["file_name"]
            if not src.exists():
                dropped["image absente"] = dropped.get("image absente", 0) + 1
                continue
            _link(src.resolve(), target / im["file_name"])
            images.append({"id": im["id"], "file_name": im["file_name"], "width": im["width"], "height": im["height"]})
            for ann in by_image[origin].get(im["id"], []):
                crowd = bool(ann.get("iscrowd", 0))
                if ann["category_id"] not in known and not class_agnostic:      # « food » : tout aliment compte, même d'une classe absente de train
                    dropped["classe inconnue"] += 1
                    continue
                if role != "test" and crowd:
                    dropped["crowd"] += 1
                    continue
                if not crowd and not _valid_polygon(ann.get("segmentation")):
                    dropped["sans polygone"] += 1
                    continue
                x, y, w, h = ann["bbox"]
                if not crowd and (w < 1 or h < 1):
                    dropped["boîte vide"] += 1
                    continue
                annotations.append({"id": ann["id"], "image_id": ann["image_id"], "category_id": 1 if class_agnostic else ann["category_id"], "bbox": ann["bbox"],
                                    "area": ann.get("area", w * h), "iscrowd": 1 if crowd else 0, "segmentation": ann["segmentation"]})
        payload = {"info": {"description": f"MyFoodRepo / AIcrowd Food Recognition Benchmark 2022, CC BY 4.0 ({role})"},
                   "images": images, "annotations": annotations, "categories": categories}
        (target / "_annotations.coco.json").write_text(json.dumps(payload), encoding="utf-8")
        stats[role] = {"images": len(images), "annotations": len(annotations), "dropped": {k: v for k, v in dropped.items() if v}}
    stats["out_dir"] = str(out_dir)
    (Path(out_dir) / "dataset_stats.json").write_text(json.dumps(stats, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    return stats
