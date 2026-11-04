"""Jeu FACTICE au format COCO (annotations d'instances) pour tester la chaîne de bout en bout.

Quelques images générées (formes colorées texturées sur un fond uni), avec des classes qui portent des noms
dans le style de MyFoodRepo (« bread-white », « salad-leaf-salad-green »...). Les identifiants de classe sont
INVENTÉS. Ce jeu ne représente aucun aliment réel : les chiffres obtenus dessus ne mesurent RIEN et ne doivent
jamais être présentés comme une précision. Il sert à prouver que les scripts tournent, pas que le modèle marche.

Il contient volontairement des cas pièges : une annotation « foule » (iscrowd), une instance minuscule, une photo
de validation recopiée (légèrement modifiée) dans l'entraînement pour vérifier que la détection de fuite la retire,
et une classe sans équivalent dans la base de l'app.

    python make_fake_coco.py [--root DIR] [--train-images 96] [--val-images 36] [--seed 20261102] [--supervisely]

Avec `--supervisely`, écrit AUSSI les mêmes images sous la forme d'un projet Supervisely (`<racine>/fake/supervisely`) :
jeux train / val / test (le val factice est coupé en deux) + un jeu « unlabeled » à ignorer ; objets polygone, bitmap (PNG à un
canal ou RGBA), rectangle, plus des pièges (point, classe absente de meta.json, objet minuscule). Sert à tester `--format supervisely`.
"""
from __future__ import annotations

import argparse
import base64
import io
import json
import math
import random
import shutil
import zlib
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageEnhance

from ml_common import fail, log, ml_root

# (id inventé, nom façon MyFoodRepo, nom lisible, couleur de base RGB, motif)
CLASSES = [
    (1040, "apple", "Apple", (190, 40, 40), "dots"),
    (1041, "banana", "Banana", (230, 210, 60), "stripes"),
    (1042, "tomato-raw", "Tomato, raw", (210, 60, 30), "checker"),
    (1043, "carrot-raw", "Carrot, raw", (230, 130, 30), "stripes"),
    (1044, "bread-white", "Bread, white", (215, 190, 150), "dots"),
    (1045, "salad-leaf-salad-green", "Salad, leaf / salad, green", (70, 150, 60), "checker"),
    (1046, "cheese", "Cheese", (240, 200, 90), "rings"),
    (1047, "rice", "Rice", (235, 235, 225), "dots"),
    (1048, "egg", "Egg", (250, 245, 230), "rings"),
    (1049, "hummus", "Hummus", (200, 170, 110), "checker"),
    (1050, "zzz-plat-inconnu-test", "Plat inconnu (test)", (120, 60, 160), "rings"),
]


def texture(shape, base, pattern, rng: np.random.Generator):
    h, w = shape
    yy, xx = np.mgrid[0:h, 0:w]
    base = np.array(base, dtype=np.float32)
    if pattern == "stripes":
        wave = np.sin((xx + yy * 0.3) / 5.0)
    elif pattern == "checker":
        wave = np.sign(np.sin(xx / 6.0) * np.sin(yy / 6.0))
    elif pattern == "rings":
        wave = np.sin(np.hypot(xx - w / 2, yy - h / 2) / 4.0)
    else:  # dots
        wave = np.sin(xx / 3.0) * np.sin(yy / 3.0)
    img = base[None, None, :] * (1.0 + 0.18 * wave[:, :, None]) + rng.normal(0, 6, (h, w, 3))
    return np.clip(img, 0, 255).astype(np.uint8)


def blob_polygon(cx, cy, radius, rng: random.Random, n=14):
    points = []
    for k in range(n):
        angle = 2 * math.pi * k / n
        r = radius * rng.uniform(0.8, 1.15)
        points.append((cx + r * math.cos(angle), cy + r * math.sin(angle) * 0.8))
    return points


def make_image(rng: random.Random, nprng: np.random.Generator, classes, size, n_instances, next_ann_id):
    width, height = size
    background = tuple(rng.randint(150, 235) for _ in range(3))
    canvas = Image.new("RGB", size, background)
    annotations = []
    placed = []
    for _ in range(n_instances):
        for _try in range(30):
            radius = rng.uniform(min(size) * 0.12, min(size) * 0.26)
            cx = rng.uniform(radius + 4, width - radius - 4)
            cy = rng.uniform(radius + 4, height - radius - 4)
            if all(math.hypot(cx - ox, cy - oy) > (radius + orad) * 1.05 for ox, oy, orad in placed):
                break
        else:
            continue
        placed.append((cx, cy, radius))
        cls = rng.choice(classes)
        polygon = blob_polygon(cx, cy, radius, rng)
        mask = Image.new("L", size, 0)
        ImageDraw.Draw(mask).polygon(polygon, fill=255)
        tex = Image.fromarray(texture((height, width), cls[3], cls[4], nprng))
        canvas.paste(tex, (0, 0), mask)
        xs, ys = [p[0] for p in polygon], [p[1] for p in polygon]
        bbox = [round(min(xs), 1), round(min(ys), 1), round(max(xs) - min(xs), 1), round(max(ys) - min(ys), 1)]
        area = float(np.array(mask).astype(bool).sum())
        annotations.append({
            "id": next_ann_id(), "category_id": cls[0], "iscrowd": 0, "bbox": bbox, "area": area,
            "segmentation": [[round(c, 1) for p in polygon for c in p]],
        })
    return canvas, annotations


def write_split(folder: Path, n_images: int, classes, seed: int, id_offset: int, tiny_and_crowd: bool):
    (folder / "images").mkdir(parents=True, exist_ok=True)
    rng = random.Random(seed)
    nprng = np.random.default_rng(seed)
    counter = [id_offset * 10]

    def next_ann_id():
        counter[0] += 1
        return counter[0]

    images, annotations = [], []
    for k in range(n_images):
        image_id = id_offset + k
        size = (rng.choice([320, 384, 416]), rng.choice([288, 320, 352]))
        canvas, anns = make_image(rng, nprng, classes, size, rng.choice([1, 2, 2, 3]), next_ann_id)
        name = f"{image_id:06d}.jpg"
        canvas.save(folder / "images" / name, quality=92)
        images.append({"id": image_id, "file_name": name, "width": size[0], "height": size[1]})
        for ann in anns:
            ann["image_id"] = image_id
        annotations.extend(anns)
    if tiny_and_crowd and annotations:
        first = annotations[0]
        # instance minuscule (à ignorer) et annotation « foule » (iscrowd, à ignorer)
        annotations.append({"id": next_ann_id(), "image_id": first["image_id"], "category_id": classes[0][0], "iscrowd": 0,
                            "bbox": [2.0, 2.0, 9.0, 9.0], "area": 81.0, "segmentation": [[2, 2, 11, 2, 11, 11, 2, 11]]})
        annotations.append({"id": next_ann_id(), "image_id": first["image_id"], "category_id": classes[1][0], "iscrowd": 1,
                            "bbox": [20.0, 20.0, 60.0, 60.0], "area": 3600.0, "segmentation": {"counts": "xx", "size": [288, 320]}})
    categories = [{"id": c[0], "name": c[1], "name_readable": c[2], "supercategory": "food"} for c in classes]
    return {"images": images, "annotations": annotations, "categories": categories}


def bitmap_object(polygon, size, kind: str):
    """Masque Supervisely d'un polygone : PNG (un canal « L » ou RGBA) -> zlib -> base64, et origine [x, y]."""
    xs, ys = polygon[0::2], polygon[1::2]
    x0, y0 = int(math.floor(min(xs))), int(math.floor(min(ys)))
    x1, y1 = int(math.ceil(max(xs))) + 1, int(math.ceil(max(ys))) + 1
    mask = Image.new("L", (x1 - x0, y1 - y0), 0)
    ImageDraw.Draw(mask).polygon([(x - x0, y - y0) for x, y in zip(xs, ys)], fill=255)
    if kind == "rgba":
        image = Image.new("RGBA", mask.size, (255, 255, 255, 0))
        image.putalpha(mask)
    else:
        image = mask
    buffer = io.BytesIO()
    image.save(buffer, "PNG")
    return {"data": base64.b64encode(zlib.compress(buffer.getvalue())).decode("ascii"), "origin": [x0, y0]}


def sly_object(ann: dict, class_title: str, class_ids: dict, serial: int) -> dict:
    """Un objet Supervisely tiré d'une annotation COCO : la géométrie tourne (polygone, bitmap L, bitmap RGBA, rectangle)."""
    polygon = ann["segmentation"][0]
    base = {"id": 900000 + serial, "classId": class_ids[class_title], "description": "", "tags": [], "classTitle": class_title,
            "labelerLogin": "fake", "createdAt": "2026-11-02T00:00:00.000Z", "updatedAt": "2026-11-02T00:00:00.000Z"}
    kind = ann["id"] % 4
    xs, ys = polygon[0::2], polygon[1::2]
    if kind == 0:
        return {**base, "geometryType": "polygon", "points": {"exterior": [[x, y] for x, y in zip(xs, ys)], "interior": []}}
    if kind == 1:
        return {**base, "geometryType": "bitmap", "bitmap": bitmap_object(polygon, None, "l")}
    if kind == 2:
        return {**base, "geometryType": "bitmap", "bitmap": bitmap_object(polygon, None, "rgba")}
    return {**base, "geometryType": "rectangle", "points": {"exterior": [[min(xs), min(ys)], [max(xs), max(ys)]], "interior": []}}


def write_supervisely(project: Path, coco_root: Path, train: dict, val: dict) -> None:
    """Projet Supervisely fabriqué depuis le COCO factice : train, val (1re moitié), test (2e moitié), unlabeled."""
    if project.exists():
        shutil.rmtree(project)
    class_ids = {c[1]: 9000 + i for i, c in enumerate(CLASSES)}
    title_of = {c[0]: c[1] for c in CLASSES}
    meta = {"classes": [{"id": class_ids[c[1]], "title": c[1], "shape": "any_shape", "color": "#%02X%02X%02X" % c[3],
                         "geometry_config": {}, "hotkey": ""} for c in CLASSES], "tags": [], "projectType": "images"}
    project.mkdir(parents=True)
    (project / "meta.json").write_text(json.dumps(meta, indent=2), encoding="utf-8")
    half = len(val["images"]) // 2
    parts = {"train": (coco_root / "train", train, train["images"]),
             "val": (coco_root / "val", val, val["images"][:half]),
             "test": (coco_root / "val", val, val["images"][half:])}
    serial = 0
    for dataset, (source, data, images) in parts.items():
        (project / dataset / "img").mkdir(parents=True)
        (project / dataset / "ann").mkdir()
        by_image: dict[int, list] = {}
        for ann in data["annotations"]:
            by_image.setdefault(ann["image_id"], []).append(ann)
        for im in images:
            shutil.copy(source / "images" / im["file_name"], project / dataset / "img" / im["file_name"])
            objects = []
            for ann in by_image.get(im["id"], []):
                if ann.get("iscrowd") or not isinstance(ann.get("segmentation"), list):
                    continue                                   # une « foule » RLE n'a pas d'équivalent ici
                serial += 1
                objects.append(sly_object(ann, title_of[ann["category_id"]], class_ids, serial))
            if dataset == "train" and im is images[0]:
                # pièges : un point (géométrie non gérée), une classe absente de meta.json, une classe inconnue sans identifiant
                objects.append({"id": 1, "classId": class_ids["apple"], "classTitle": "apple", "tags": [], "geometryType": "point",
                                "points": {"exterior": [[10, 10]], "interior": []}})
                objects.append({"id": 2, "classId": 1, "classTitle": "zzz-classe-absente-de-meta", "tags": [], "geometryType": "polygon",
                                "points": {"exterior": [[10, 10], [90, 10], [90, 90]], "interior": []}})
            ann_json = {"description": "", "tags": [], "size": {"height": im["height"], "width": im["width"]}, "objects": objects}
            (project / dataset / "ann" / f"{im['file_name']}.json").write_text(json.dumps(ann_json), encoding="utf-8")
    (project / "unlabeled" / "img").mkdir(parents=True)
    (project / "unlabeled" / "ann").mkdir()
    for im in train["images"][:2]:
        shutil.copy(coco_root / "train" / "images" / im["file_name"], project / "unlabeled" / "img" / im["file_name"])
        (project / "unlabeled" / "ann" / f"{im['file_name']}.json").write_text(
            json.dumps({"description": "", "tags": [], "size": {"height": im["height"], "width": im["width"]}, "objects": []}), encoding="utf-8")
    log(f"Projet Supervisely factice écrit dans {project} (train / val / test / unlabeled)")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--root", help="racine des données (défaut : ARDANE_ML_ROOT ou ~/ardane-tools/ml)")
    parser.add_argument("--train-images", type=int, default=96)
    parser.add_argument("--val-images", type=int, default=36)
    parser.add_argument("--seed", type=int, default=20261102)
    parser.add_argument("--supervisely", action="store_true", help="écrire aussi le même jeu en projet Supervisely")
    args = parser.parse_args()
    root = ml_root(args.root)
    out = root / "fake" / "coco"
    if out.exists() and any(out.iterdir()):
        log(f"{out} existe déjà : régénération (déterministe, mêmes octets).")

    train = write_split(out / "train", args.train_images, CLASSES, args.seed, 100000, tiny_and_crowd=True)
    val = write_split(out / "val", args.val_images, CLASSES, args.seed + 1, 200000, tiny_and_crowd=False)

    # Fuite volontaire : une photo de validation recopiée dans l'entraînement, légèrement modifiée
    # (luminosité + nouvelle compression), sous un autre identifiant.
    source = val["images"][3]
    with Image.open(out / "val" / "images" / source["file_name"]) as im:
        copy = ImageEnhance.Brightness(im.convert("RGB")).enhance(1.03)
        buf = io.BytesIO()
        copy.save(buf, "JPEG", quality=85)
    leak_id = 150000
    leak_name = f"{leak_id:06d}.jpg"
    (out / "train" / "images" / leak_name).write_bytes(buf.getvalue())
    train["images"].append({"id": leak_id, "file_name": leak_name, "width": source["width"], "height": source["height"]})
    next_id = max(a["id"] for a in train["annotations"]) + 1
    for ann in [a for a in val["annotations"] if a["image_id"] == source["id"]]:
        train["annotations"].append({**ann, "id": next_id, "image_id": leak_id})
        next_id += 1

    for split, data in (("train", train), ("val", val)):
        with open(out / split / "annotations.json", "w", encoding="utf-8") as f:
            json.dump(data, f)
    (out / "LISEZ-MOI.txt").write_text(
        "JEU FACTICE généré par scripts/ml/make_fake_coco.py : formes colorées, classes inventées.\n"
        "Aucun chiffre obtenu sur ce jeu n'est une précision.\n", encoding="utf-8")
    log(f"Jeu factice écrit dans {out}")
    for split, data in (("train", train), ("val", val)):
        log(f"  {split} : {len(data['images'])} images, {len(data['annotations'])} annotations, {len(data['categories'])} classes")
    log(f"  fuite volontaire : image val {source['id']} recopiée dans train sous {leak_id}")
    if args.supervisely:
        write_supervisely(root / "fake" / "supervisely", out, train, val)


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        fail("interrompu")
