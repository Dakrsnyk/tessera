"""Lecture d'un projet au format Supervisely (copie « Dataset Ninja » de Food Recognition 2022) pour prepare_myfoodrepo.py.

Mise en page d'un projet Supervisely (format d'annotation JSON documenté par Supervisely) :

    <projet>/meta.json                       classes : [{"id", "title", "shape", "color", ...}], tags
    <projet>/<jeu>/img/<nom de l'image>      les photos         (jeu = train, val, test...)
    <projet>/<jeu>/ann/<nom de l'image>.json {"size": {"height", "width"}, "objects": [...]}

Un objet porte `classTitle` (et `classId`), un `geometryType` et sa géométrie :
  - `polygon`   : points.exterior = [[x, y], ...]  (les trous `interior` sont ignorés pour la boîte) ;
  - `rectangle` : points.exterior = [[gauche, haut], [droite, bas]] ;
  - `bitmap`    : bitmap.data = PNG compressé en zlib puis encodé en base64, bitmap.origin = [x, y] du coin haut gauche ;
                  le masque est le canal alpha d'un PNG RGBA, sinon l'image à un canal (valeurs non nulles), comme le fait Supervisely.
Autres géométries (point, ligne, graphe...) : rejetées et comptées.

Identifiants : les classes reçoivent 1..N dans l'ordre alphabétique des titres (reproductible, indépendant des identifiants
de la plateforme) ; les photos reçoivent 1..M dans l'ordre alphabétique des noms de fichier de chaque jeu ; les instances
reçoivent un numéro global croissant. La clé stable d'une classe est son TITRE (identique à `name` du COCO d'AIcrowd).

NON TESTÉ sur un vrai téléchargement Dataset Ninja au moment de l'écriture (il n'était pas arrivé) : le lecteur est
validé sur un petit projet fabriqué au même format (`make_fake_coco.py --supervisely`). Voir le README.
"""
from __future__ import annotations

import base64
import io
import json
import re
import zlib
from collections import Counter
from pathlib import Path

import numpy as np
from PIL import Image

from ml_common import fail, log

IMAGE_DIR_NAMES = ("img", "images")
SET_NAMES = ("train", "val", "test")


def find_project(path: Path) -> Path:
    """Dossier qui contient `meta.json` : `path` lui-même, un sous-dossier direct, ou jusqu'à trois niveaux plus bas."""
    if (path / "meta.json").exists():
        return path
    for depth in ("*", "*/*", "*/*/*"):
        found = sorted(p.parent for p in path.glob(f"{depth}/meta.json"))
        if found:
            return found[0]
    fail(f"aucun meta.json de projet Supervisely sous {path}")
    raise SystemExit(1)


def dataset_dirs(project: Path, set_map: dict[str, str] | None) -> tuple[dict[str, Path], list[str]]:
    """Jeux du projet : {train|val|test: dossier}. Les autres dossiers (unlabeled...) sont ignorés et listés."""
    found: dict[str, Path] = {}
    ignored: list[str] = []
    for child in sorted(p for p in project.iterdir() if p.is_dir()):
        if not (child / "ann").is_dir():
            continue
        name = (set_map or {}).get(child.name)
        if name is None:
            lower = child.name.lower()
            name = next((s for s in SET_NAMES if re.search(rf"(^|[^a-z]){s}($|[^a-z])", lower)), None)
        if name not in SET_NAMES or name in found:       # nom inconnu (ex. --sly-map x=ignore) ou doublon : dossier ignoré
            ignored.append(child.name)
            continue
        found[name] = child
    return found, ignored


def decode_bitmap_bbox(bitmap: dict):
    """(x, y, w, h) des pixels non nuls d'un masque Supervisely, en coordonnées de la photo ; None si le masque est vide."""
    raw = zlib.decompress(base64.b64decode(bitmap["data"]))
    with Image.open(io.BytesIO(raw)) as im:
        if im.mode in ("RGBA", "LA"):
            mask = np.asarray(im.getchannel("A")) > 0
        else:
            mask = np.asarray(im.convert("L")) > 0
    ys, xs = np.nonzero(mask)
    if len(xs) == 0:
        return None
    ox, oy = bitmap["origin"]
    return (ox + int(xs.min()), oy + int(ys.min()), int(xs.max() - xs.min() + 1), int(ys.max() - ys.min() + 1))


def object_bbox(obj: dict):
    """Boîte (x, y, w, h) d'un objet, ou une chaîne décrivant pourquoi il est rejeté."""
    kind = obj.get("geometryType")
    if kind in ("polygon", "rectangle"):
        points = (obj.get("points") or {}).get("exterior") or []
        if len(points) < (3 if kind == "polygon" else 2):
            return "géométrie vide"
        xs, ys = [p[0] for p in points], [p[1] for p in points]
        return (min(xs), min(ys), max(xs) - min(xs), max(ys) - min(ys))
    if kind == "bitmap":
        try:
            box = decode_bitmap_bbox(obj["bitmap"])
        except Exception:
            return "masque illisible"
        return box if box is not None else "masque vide"
    return f"géométrie non gérée ({kind})"


def load_supervisely(project_arg: Path, min_size: float, set_map: dict[str, str] | None = None):
    """Retourne (catégories, jeux, résumé) ; chaque jeu = {images, usable, images_dir, rejected, label}.

    `catégories` : {class_id: {"id", "name", "name_readable"}} ; `jeux` : {"train"|"val"|"test": ...} avec les mêmes structures
    que la lecture COCO de prepare_myfoodrepo.py (images {id: {file_name, width, height}}, usable {id: [{ann_id, category_id, bbox}]}).
    """
    project = find_project(project_arg)
    meta = json.loads((project / "meta.json").read_text(encoding="utf-8"))
    titles = sorted({c["title"] for c in meta.get("classes", [])})
    if not titles:
        fail(f"{project / 'meta.json'} ne déclare aucune classe")
    class_id = {title: i + 1 for i, title in enumerate(titles)}
    by_sly_id = {c["id"]: c["title"] for c in meta["classes"] if c.get("id") is not None}
    categories = {cid: {"id": cid, "name": title, "name_readable": ""} for title, cid in class_id.items()}
    dirs, ignored = dataset_dirs(project, set_map)
    log(f"  projet Supervisely : {project} ; {len(titles)} classes ; jeux lus : {', '.join(f'{k} ({v.name})' for k, v in dirs.items())}"
        + (f" ; ignorés : {', '.join(ignored)}" if ignored else ""))
    if "train" not in dirs:
        fail("aucun jeu « train » dans le projet (dossiers : " + ", ".join(p.name for p in project.iterdir() if p.is_dir()) + "). Voir --sly-map.")

    next_ann = 1
    sets: dict[str, dict] = {}
    for set_name, folder in dirs.items():
        images_dir = next((folder / d for d in IMAGE_DIR_NAMES if (folder / d).is_dir()), None)
        if images_dir is None:
            fail(f"{folder} n'a pas de dossier img/")
        images: dict[int, dict] = {}
        usable: dict[int, list] = {}
        rejected: Counter = Counter()
        n_objects = 0
        ann_files = sorted((folder / "ann").glob("*.json"))
        for index, ann_file in enumerate(ann_files, 1):
            image_name = ann_file.name[:-len(".json")]
            if not (images_dir / image_name).exists():
                stem_matches = sorted(images_dir.glob(Path(image_name).stem + ".*"))
                if not stem_matches:
                    rejected["fichier image absent"] += 1
                    continue
                image_name = stem_matches[0].name
            ann = json.loads(ann_file.read_text(encoding="utf-8"))
            size = ann.get("size") or {}
            if not size.get("width") or not size.get("height"):
                with Image.open(images_dir / image_name) as im:
                    size = {"width": im.size[0], "height": im.size[1]}
            image_id = len(images) + 1
            images[image_id] = {"id": image_id, "file_name": image_name, "width": size["width"], "height": size["height"]}
            for obj in ann.get("objects", []):
                n_objects += 1
                title = obj.get("classTitle") or by_sly_id.get(obj.get("classId"))
                if title not in class_id:
                    rejected["classe inconnue"] += 1
                    continue
                box = object_bbox(obj)
                if isinstance(box, str):
                    rejected[box] += 1
                    continue
                x, y, w, h = box
                x0, y0 = max(x, 0.0), max(y, 0.0)
                x1, y1 = min(x + w, float(size["width"])), min(y + h, float(size["height"]))
                if min(x1 - x0, y1 - y0) < min_size:
                    rejected[f"plus petite que {min_size:g} px"] += 1
                    continue
                usable.setdefault(image_id, []).append({"ann_id": next_ann, "category_id": class_id[title], "bbox": (x0, y0, x1 - x0, y1 - y0)})
                next_ann += 1
            if index % 5000 == 0:
                log(f"    {set_name} : {index}/{len(ann_files)} annotations lues")
        n_usable = sum(len(v) for v in usable.values())
        log(f"  {set_name} : {len(images)} images, {n_objects} objets, {n_usable} instances utilisables sur {len(usable)} images")
        for reason, count in rejected.most_common():
            log(f"    rejeté ({reason}) : {count}")
        if not usable:
            log(f"    jeu « {set_name} » sans aucune instance utilisable (non annoté ?) : ignoré")
            continue
        sets[set_name] = {"images": images, "usable": usable, "images_dir": images_dir, "rejected": rejected, "label": set_name}
    return categories, sets, {"project": str(project), "meta_sha_source": str(project / "meta.json"), "ignored_dirs": ignored,
                             "ann_files": sum(len(list((d / 'ann').glob('*.json'))) for d in dirs.values())}
