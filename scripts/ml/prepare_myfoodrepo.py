"""Étape 1 : préparer MyFoodRepo (AIcrowd Food Recognition Benchmark 2022, format COCO d'instances).

Lit les annotations COCO, découpe un recadrage carré par instance (boîte du polygone + marge), répartit les PHOTOS
(jamais les recadrages) entre entraînement / validation / test sans fuite, écrit la table de correspondance
`class_map.csv` vers les identifiants d'aliments d'Ardane et les statistiques par classe.

Deux formats de sources (même sortie) :
  --format coco (défaut), archives AIcrowd :
    <racine>/raw/myfoodrepo/train/annotations.json   et   train/images/*.jpg    (public_training_set_release_2.1)
    <racine>/raw/myfoodrepo/val/annotations.json     et   val/images/*.jpg      (public_validation_set_2.1)
  --format supervisely, copie « Dataset Ninja » (Food Recognition 2022, v2.0) : un projet Supervisely
    <projet>/meta.json et <projet>/{train,val,test}/{img,ann}/ ; voir sly_format.py et README.md (--sly-root, --sly-map).

Répartition (le découpage officiel est respecté quand il existe) :
  - train + val + test annotés (Dataset Ninja) : train -> entraînement, val -> VALIDATION, test -> TEST ;
  - train + val seulement (archives AIcrowd) : le jeu officiel `val` devient le TEST ; la VALIDATION est prélevée dans `train`,
    par groupes de photos ;
  - un seul jeu : tout est réparti par groupes de photos (80 / 10 / 10 par défaut) ;
  - les photos quasi identiques (empreinte dHash, distance de Hamming <= --dedup-hamming) forment un groupe qui reste
    d'un seul côté, celui du jeu de plus haute priorité (test > validation > entraînement) ; les photos des jeux de priorité
    inférieure du même groupe sont RETIRÉES ;
  - le TEST n'est jamais utilisé pour régler, arrêter ou étalonner.

    python prepare_myfoodrepo.py --dataset myfoodrepo
    python prepare_myfoodrepo.py --dataset fake --coco-root <racine>/fake/coco
"""
from __future__ import annotations

import argparse
import hashlib
import random
import subprocess
import sys
import time
from collections import Counter, defaultdict
from concurrent.futures import ThreadPoolExecutor
from datetime import date
from pathlib import Path

import numpy as np
from PIL import Image

import class_matching
from ml_common import (REPO, SCRIPT_DIR, crop_square, dhash, fail, file_sha256, log, ml_root, read_json, work_dir,
                       write_csv, write_json)

SPLITS = ("train", "val", "test")


# --------------------------------------------------------------------------- lecture COCO

def polygon_bbox(segmentation):
    """Boîte (x, y, w, h) des polygones COCO ; None si la segmentation est un RLE (foule) ou vide."""
    if not isinstance(segmentation, list) or not segmentation:
        return None
    xs, ys = [], []
    for poly in segmentation:
        if isinstance(poly, list) and len(poly) >= 6:
            xs += poly[0::2]
            ys += poly[1::2]
    if not xs:
        return None
    return (min(xs), min(ys), max(xs) - min(xs), max(ys) - min(ys))


def load_coco(json_path: Path, images_dir: Path, min_size: float, label: str):
    """Retourne (catégories, images, instances utilisables, compteurs de rejets)."""
    data = read_json(json_path)
    for key in ("images", "annotations", "categories"):
        if key not in data:
            fail(f"{json_path} n'est pas un COCO d'instances (clé « {key} » absente)")
    categories = {c["id"]: c for c in data["categories"]}
    images = {im["id"]: im for im in data["images"]}
    rejected = Counter()
    usable: dict[int, list[dict]] = defaultdict(list)
    for ann in data["annotations"]:
        im = images.get(ann.get("image_id"))
        if im is None:
            rejected["image inconnue"] += 1
            continue
        if ann.get("category_id") not in categories:
            rejected["classe inconnue"] += 1
            continue
        if ann.get("iscrowd", 0):
            rejected["foule (iscrowd)"] += 1
            continue
        box = polygon_bbox(ann.get("segmentation")) or (tuple(ann["bbox"]) if ann.get("bbox") else None)
        if box is None:
            rejected["sans boîte ni polygone"] += 1
            continue
        x, y, w, h = box
        x0, y0 = max(x, 0.0), max(y, 0.0)
        x1, y1 = min(x + w, float(im["width"])), min(y + h, float(im["height"]))
        if min(x1 - x0, y1 - y0) < min_size:
            rejected[f"plus petite que {min_size:g} px"] += 1
            continue
        usable[im["id"]].append({"ann_id": ann["id"], "category_id": ann["category_id"], "bbox": (x0, y0, x1 - x0, y1 - y0)})
    missing = [iid for iid in usable if not (images_dir / images[iid]["file_name"]).exists()]
    for iid in missing:
        rejected["fichier image absent"] += len(usable[iid])
        del usable[iid]
    log(f"  {label} : {len(images)} images, {len(data['annotations'])} annotations, {len(categories)} classes ; "
        f"{sum(len(v) for v in usable.values())} instances utilisables sur {len(usable)} images")
    for reason, count in rejected.most_common():
        log(f"    rejeté ({reason}) : {count}")
    return categories, images, usable, rejected


# --------------------------------------------------------------------------- groupes de photos quasi identiques

def _popcount(values: np.ndarray) -> np.ndarray:
    if hasattr(np, "bitwise_count"):
        return np.bitwise_count(values)
    return np.unpackbits(values.view(np.uint8).reshape(-1, 8), axis=1).sum(axis=1)


def hamming_groups(hashes: list[int], k: int) -> list[int]:
    """Groupe chaque empreinte avec celles à distance <= k (union-find, index multiples par blocs de bits)."""
    n = len(hashes)
    parent = list(range(n))

    def find(a: int) -> int:
        while parent[a] != a:
            parent[a] = parent[parent[a]]
            a = parent[a]
        return a

    arr = np.array(hashes, dtype=np.uint64)
    n_chunks = k + 1                       # principe des tiroirs : distance <= k  =>  un des k+1 blocs est identique
    edges = np.linspace(0, 64, n_chunks + 1).astype(int)
    for c in range(n_chunks):
        lo, hi = int(edges[c]), int(edges[c + 1])
        mask = np.uint64((1 << (hi - lo)) - 1)
        keys = (arr >> np.uint64(lo)) & mask
        order = np.argsort(keys, kind="stable")
        sorted_keys = keys[order]
        boundaries = np.flatnonzero(np.diff(sorted_keys)) + 1
        for block in np.split(order, boundaries):
            if len(block) < 2:
                continue
            if len(block) > 4000:
                log(f"    avertissement : bloc de {len(block)} empreintes très proches (images très uniformes ?), sous-échantillonné")
                block = block[:4000]
            vals = arr[block]
            for i in range(len(block) - 1):
                near = np.flatnonzero(_popcount(vals[i + 1:] ^ vals[i]) <= k)
                for j in near:
                    ra, rb = find(int(block[i])), find(int(block[i + 1 + j]))
                    if ra != rb:
                        parent[ra] = rb
    return [find(i) for i in range(n)]


def image_hashes(keys: list[tuple[str, int]], paths: dict, cache_path: Path, workers: int) -> dict:
    """dHash de chaque photo (cache disque : la reprise est gratuite)."""
    cache = read_json(cache_path) if cache_path.exists() else {}
    ck = lambda key: f"{key[0]}/{paths[key].name}"
    todo = [k for k in keys if ck(k) not in cache]

    def one(key):
        with Image.open(paths[key]) as im:
            im.draft("L", (96, 96))          # JPEG : décodage réduit, bien plus rapide
            return key, f"{dhash(im):016x}"

    if todo:
        t0 = time.time()
        with ThreadPoolExecutor(max_workers=workers) as pool:
            for done, (key, value) in enumerate(pool.map(one, todo), 1):
                cache[ck(key)] = value
                if done % 5000 == 0:
                    log(f"    empreintes : {done}/{len(todo)}")
        write_json(cache_path, cache)
        log(f"  empreintes de {len(todo)} photos calculées en {time.time() - t0:.1f} s")
    return {k: int(cache[ck(k)], 16) for k in keys}


# --------------------------------------------------------------------------- programme

def git_head() -> str:
    try:
        return subprocess.run(["git", "rev-parse", "HEAD"], cwd=REPO, capture_output=True, text=True, timeout=10).stdout.strip()
    except Exception:
        return ""


def main() -> None:
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--root", help="racine des données (défaut : ARDANE_ML_ROOT ou ~/ardane-tools/ml)")
    ap.add_argument("--dataset", default="myfoodrepo", help="nom du jeu de travail (« fake » = jeu factice)")
    ap.add_argument("--coco-root", help="dossier contenant train/ et val/ (défaut : <racine>/raw/myfoodrepo, ou <racine>/fake/coco)")
    ap.add_argument("--format", choices=["coco", "supervisely"], default="coco",
                    help="format des annotations : COCO d'AIcrowd (défaut) ou projet Supervisely (copie Dataset Ninja)")
    ap.add_argument("--sly-root", help="dossier du projet Supervisely (celui qui contient meta.json, ou un dossier parent)")
    ap.add_argument("--sly-map", help="correspondance dossier=jeu si les noms ne contiennent pas train/val/test, ex. « a=train,b=val »")
    ap.add_argument("--dataset-version", default="", help="version du jeu source à consigner (« 2.1 » AIcrowd, « 2.0 » Dataset Ninja...)")
    ap.add_argument("--train-json"); ap.add_argument("--train-images")
    ap.add_argument("--val-json"); ap.add_argument("--val-images")
    ap.add_argument("--margin", type=float, default=0.10, help="marge autour de la boîte, en fraction de son côté (0,10)")
    ap.add_argument("--min-size", type=float, default=32.0, help="côté minimal (px de la photo d'origine) d'une instance retenue")
    ap.add_argument("--crop-size", type=int, default=224)
    ap.add_argument("--val-fraction", type=float, default=0.10, help="part de photos d'entraînement mise en validation")
    ap.add_argument("--test-fraction", type=float, default=0.10, help="part de photos mise en test s'il n'y a PAS de jeu val officiel")
    ap.add_argument("--seed", type=int, default=20261102)
    ap.add_argument("--dedup-hamming", type=int, default=4, help="distance de Hamming (sur 64 bits) sous laquelle deux photos sont « les mêmes »")
    ap.add_argument("--no-dedup", action="store_true")
    ap.add_argument("--workers", type=int, default=8)
    ap.add_argument("--no-crops", action="store_true", help="statistiques et correspondance seulement, sans écrire les recadrages")
    ap.add_argument("--class-map", help="chemin de class_map.csv (défaut : scripts/ml/class_map.csv pour myfoodrepo, sinon dans le dossier de travail)")
    ap.add_argument("--class-map-only", action="store_true",
                    help="ne régénérer que class_map.csv depuis classes.json déjà préparé (base d'aliments mise à jour), sans relire les données")
    ap.add_argument("--remap", action="store_true", help="régénérer toute la table (même les lignes « manuel »)")
    ap.add_argument("--skip-class-map", action="store_true",
                    help="ne pas toucher à class_map.csv (ni lire la base d'aliments d'Ardane) : pour un environnement sans dépôt, ex. Kaggle")
    ap.add_argument("--fcen-zip", help="FCÉN 2026 brute (défaut : <racine>/../food-data/fcen2026/cnf_fcen_all-files-data_2026.zip)")
    ap.add_argument("--license-note", default="", help="licence affichée sur la page de téléchargement (à recopier telle quelle)")
    args = ap.parse_args()

    if not 0 <= args.margin <= 0.5:
        fail("--margin doit être entre 0 et 0,5")
    root = ml_root(args.root)
    if args.class_map_only:
        out = work_dir(root, args.dataset)
        if not (out / "classes.json").exists():
            fail(f"{out / 'classes.json'} est absent : lancer d'abord la préparation complète")
        classes = read_json(out / "classes.json")
        catalog, description = class_matching.load_catalog(root, Path(args.fcen_zip) if args.fcen_zip else None)
        matcher = class_matching.Matcher(catalog, class_matching.load_synonyms())
        map_path = Path(args.class_map) if args.class_map else (SCRIPT_DIR / "class_map.csv" if args.dataset == "myfoodrepo" else out / "class_map.csv")
        rows = class_matching.build_class_map(classes, matcher, [] if args.remap else class_matching.read_class_map(map_path))
        class_matching.write_class_map(map_path, rows)
        methods = Counter(r["methode"] for r in rows)
        log(f"{map_path} ({description}) : " + ", ".join(f"{m} {n}" for m, n in methods.most_common())
            + f" ; sans identifiant : {sum(1 for r in rows if not r['id_ardane'])}")
        return
    is_fake = args.dataset.startswith("fake")
    use_sly = args.format == "supervisely"
    out = work_dir(root, args.dataset)
    t_start = time.time()
    log(f"== Préparation du jeu « {args.dataset} » ({'FACTICE' if is_fake else 'réel'}, format {args.format}) -> {out}")

    # --- lecture : `sets` = {train | val | test : images, instances utilisables, dossier des photos}
    sets: dict[str, dict] = {}
    source_files: dict = {}
    if use_sly:
        from sly_format import load_supervisely

        sly_root = Path(args.sly_root) if args.sly_root else (root / "fake" / "supervisely" if is_fake else root / "raw" / "myfoodrepo-supervisely")
        if not sly_root.exists():
            fail(f"{sly_root} est introuvable. Voir scripts/ml/README.md, section « Format Supervisely (Dataset Ninja) ».")
        data_dir = sly_root
        set_map = dict(item.split("=", 1) for item in args.sly_map.split(",") if "=" in item) if args.sly_map else None
        log("Lecture des annotations Supervisely")
        categories, sets, info = load_supervisely(sly_root, args.min_size, set_map)
        meta_json = Path(info["project"]) / "meta.json"
        source_files = {"meta.json": {"path": str(meta_json), "sha256": file_sha256(meta_json)}, "annotation_files": info["ann_files"]}
    else:
        coco_root = Path(args.coco_root) if args.coco_root else (root / "fake" / "coco" if is_fake else root / "raw" / "myfoodrepo")
        data_dir = coco_root
        train_json = Path(args.train_json) if args.train_json else coco_root / "train" / "annotations.json"
        train_images = Path(args.train_images) if args.train_images else coco_root / "train" / "images"
        val_json = Path(args.val_json) if args.val_json else coco_root / "val" / "annotations.json"
        val_images = Path(args.val_images) if args.val_images else coco_root / "val" / "images"
        if not train_json.exists():
            fail(f"{train_json} est introuvable. Voir scripts/ml/README.md, section « Télécharger MyFoodRepo ».")
        log("Lecture des annotations COCO")
        categories, images_train, usable_train, rej_train = load_coco(train_json, train_images, args.min_size, "train")
        sets["train"] = {"images": images_train, "usable": usable_train, "images_dir": train_images, "rejected": rej_train}
        source_files["train_annotations"] = {"path": str(train_json), "sha256": file_sha256(train_json)}
        if val_json.exists():
            cats_val, images_val, usable_val, rej_val = load_coco(val_json, val_images, args.min_size, "val (officiel)")
            for cid, c in cats_val.items():
                if cid in categories and categories[cid]["name"] != c["name"]:
                    fail(f"la classe {cid} n'a pas le même nom dans train et val ({categories[cid]['name']} / {c['name']})")
                categories.setdefault(cid, c)
            sets["val"] = {"images": images_val, "usable": usable_val, "images_dir": val_images, "rejected": rej_val}
            source_files["val_annotations"] = {"path": str(val_json), "sha256": file_sha256(val_json)}
    if "train" not in sets:
        fail("aucun jeu d'entraînement utilisable")
    names = [c["name"] for c in categories.values()]
    if len(set(names)) != len(names):
        fail("deux classes portent le même nom : la clé stable d'une classe est son nom")

    # Photos concernées : (jeu d'origine, id)
    keys = [(s, i) for s, d in sets.items() for i in d["usable"]]
    paths = {(s, i): d["images_dir"] / d["images"][i]["file_name"] for s, d in sets.items() for i in d["usable"]}
    if not keys:
        fail("aucune instance utilisable")

    # Groupes de photos quasi identiques
    if args.no_dedup:
        groups = {k: n for n, k in enumerate(keys)}
        log("Détection de doublons désactivée (--no-dedup)")
    else:
        log(f"Empreintes des {len(keys)} photos (dHash 64 bits)")
        hashes = image_hashes(keys, paths, out / "image_hashes.json", args.workers)
        roots = hamming_groups([hashes[k] for k in keys], args.dedup_hamming)
        groups = dict(zip(keys, roots))
        sizes = Counter(roots)
        log(f"  {len(sizes)} groupes pour {len(keys)} photos ; {sum(1 for s in sizes.values() if s > 1)} groupes de photos quasi identiques "
            f"({sum(s for s in sizes.values() if s > 1)} photos)")
    members: dict[int, list] = defaultdict(list)
    for k in keys:
        members[groups[k]].append(k)

    # Répartition : le découpage OFFICIEL est respecté quand il existe ; un groupe de photos quasi identiques va d'un seul
    # côté, celui du jeu de plus haute priorité (test > validation > entraînement) ; les photos des jeux de priorité
    # inférieure du même groupe sont retirées.
    rng = random.Random(args.seed)
    split_of: dict[tuple, str] = {}
    dropped: Counter = Counter()
    if {"train", "val", "test"} <= set(sets):
        mode, final = "three", {"train": "train", "val": "val", "test": "test"}
        split_method = "officielle en trois jeux : train -> entraînement, val -> validation, test -> test"
    elif {"train", "val"} <= set(sets):
        mode, final = "two", {"train": "train", "val": "test"}
        split_method = "officielle en deux jeux : val officiel -> test ; validation prélevée dans train par groupes de photos"
    else:
        mode, final = "none", {s: "train" for s in sets}
        split_method = "par groupes de photos, aléatoire reproductible (seed %d), sans découpage officiel" % args.seed
    rank = {"train": 0, "val": 1, "test": 2}
    pool: list[int] = []
    for g, ms in members.items():
        if mode == "none":
            pool.append(g)
            continue
        best = max(rank[final[k[0]]] for k in ms)
        kept = [k for k in ms if rank[final[k[0]]] == best]
        for k in ms:
            if k not in kept:
                dropped[final[k[0]]] += 1           # photo quasi identique à une photo d'un jeu prioritaire : retirée
        if best == 0 and mode == "two":
            pool.append(g)                          # groupe d'entraînement pur : alimente le prélèvement de la validation
        else:
            for k in kept:
                split_of[k] = final[k[0]]
    val_target = args.val_fraction if mode in ("two", "none") else 0.0
    test_target = args.test_fraction if mode == "none" else 0.0
    rng.shuffle(pool)
    total_pool_photos = sum(len(members[g]) for g in pool)
    n_val = n_test = 0
    for g in pool:
        size = len(members[g])
        if n_test < test_target * total_pool_photos:
            target, n_test = "test", n_test + size
        elif n_val < val_target * total_pool_photos:
            target, n_val = "val", n_val + size
        else:
            target = "train"
        for k in members[g]:
            split_of[k] = target
    dropped_leak = sum(dropped.values())
    if dropped_leak:
        split_method += f" ; {dropped_leak} photos retirées car quasi identiques à une photo d'un jeu prioritaire (" \
                        + ", ".join(f"{n} {s}" for s, n in dropped.items()) + ")"
    photos_per_split = Counter(split_of.values())
    log(f"Répartition ({split_method}) : " + ", ".join(f"{s} {photos_per_split[s]} photos" for s in SPLITS))

    # Instances et recadrages
    def annotations_of(k):
        return sets[k[0]]["usable"][k[1]]

    crop_rows = []
    jobs = []   # (clé photo, split, annotations)
    for k, split in split_of.items():
        anns = annotations_of(k)
        jobs.append((k, split, anns))
        for a in anns:
            crop_rows.append({"crop": f"crops/{split}/{a['ann_id']}.jpg", "split": split, "class_id": a["category_id"],
                              "image": f"{k[0]}/{paths[k].name}", "image_id": k[1], "ann_id": a["ann_id"],
                              "x": round(a["bbox"][0], 1), "y": round(a["bbox"][1], 1), "w": round(a["bbox"][2], 1),
                              "h": round(a["bbox"][3], 1), "group": groups[k]})
    counts = {s: Counter() for s in SPLITS}
    for r in crop_rows:
        counts[r["split"]][r["class_id"]] += 1
    n_per_split = {s: sum(counts[s].values()) for s in SPLITS}
    log("Recadrages : " + ", ".join(f"{s} {n_per_split[s]}" for s in SPLITS))

    # Classes (indices stables : par NOM de classe croissant, indépendant du format source ; seulement celles qui ont au moins un recadrage)
    present = sorted({r["class_id"] for r in crop_rows}, key=lambda cid: categories[cid]["name"])
    classes = []
    for idx, cid in enumerate(present):
        c = categories[cid]
        classes.append({"index": idx, "class_id": cid, "name": c["name"], "name_readable": c.get("name_readable", ""),
                        "n_train": counts["train"][cid], "n_val": counts["val"][cid], "n_test": counts["test"][cid]})
    index_of = {c["class_id"]: c["index"] for c in classes}
    for r in crop_rows:
        r["class_index"] = index_of[r["class_id"]]
    absent = [c for c in categories.values() if c["id"] not in index_of]
    thin = [c for c in classes if c["n_train"] < 20]
    log(f"Classes : {len(classes)} avec recadrages ({len(absent)} du fichier sans aucune instance utilisable) ; "
        f"{len(thin)} avec moins de 20 recadrages d'entraînement ; "
        f"{sum(1 for c in classes if c['n_val'] == 0)} sans recadrage de validation ; {sum(1 for c in classes if c['n_test'] == 0)} sans recadrage de test")

    write_json(out / "classes.json", classes)
    write_csv(out / "class_stats.csv", classes, ["index", "class_id", "name", "name_readable", "n_train", "n_val", "n_test"])
    crop_fields = ["crop", "split", "class_id", "class_index", "image", "image_id", "ann_id", "x", "y", "w", "h", "group"]
    crop_rows.sort(key=lambda r: (SPLITS.index(r["split"]), r["ann_id"]))
    write_csv(out / "crops.csv", crop_rows, crop_fields)

    # Table de correspondance avec les aliments d'Ardane
    map_path = Path(args.class_map) if args.class_map else (SCRIPT_DIR / "class_map.csv" if args.dataset == "myfoodrepo" else out / "class_map.csv")
    if args.skip_class_map:
        description = "non calculé (--skip-class-map)"
        log(f"Correspondance avec les aliments d'Ardane : sautée (--skip-class-map) ; {map_path} n'est pas modifié")
    else:
        log("Correspondance avec les aliments d'Ardane")
        catalog, description = class_matching.load_catalog(root, Path(args.fcen_zip) if args.fcen_zip else None)
        log(f"  catalogue : {description}")
        matcher = class_matching.Matcher(catalog, class_matching.load_synonyms())
        previous = [] if args.remap else class_matching.read_class_map(map_path)
        rows = class_matching.build_class_map(classes, matcher, previous)
        class_matching.write_class_map(map_path, rows)
        methods = Counter(r["methode"] for r in rows)
        log(f"  {map_path} : " + ", ".join(f"{m} {n}" for m, n in methods.most_common())
            + f" ; à relire : {sum(1 for r in rows if r['a_relire'] == 'oui')}/{len(rows)} ; sans identifiant : {sum(1 for r in rows if not r['id_ardane'])}")

    # Recadrages
    if not args.no_crops:
        log(f"Découpe des recadrages carrés {args.crop_size} x {args.crop_size} (marge {args.margin:.0%})")
        (out / "crops").mkdir(exist_ok=True)
        for s in SPLITS:
            (out / "crops" / s).mkdir(parents=True, exist_ok=True)

        def cut(job):
            k, split, anns = job
            todo = [a for a in anns if not (out / "crops" / split / f"{a['ann_id']}.jpg").exists()]
            if not todo:
                return 0
            with Image.open(paths[k]) as im:
                im = im.convert("RGB")
                for a in todo:
                    crop_square(im, a["bbox"], args.margin, args.crop_size).save(out / "crops" / split / f"{a['ann_id']}.jpg", quality=95)
            return len(todo)

        t0, made = time.time(), 0
        with ThreadPoolExecutor(max_workers=args.workers) as pool:
            for done, n in enumerate(pool.map(cut, jobs), 1):
                made += n
                if done % 2000 == 0:
                    log(f"    {done}/{len(jobs)} photos")
        log(f"  {made} recadrages écrits en {time.time() - t0:.1f} s ({len(crop_rows) - made} déjà présents)")

    license_dirs = [root / "raw" / "myfoodrepo", root / "raw" / "myfoodrepo-supervisely", data_dir, data_dir.parent]
    license_files = [] if is_fake else sorted({f"{d.name}/{f.name}" for d in license_dirs if d.is_dir() for f in d.glob("LICENCE*")})
    source_label = "copie Dataset Ninja, format Supervisely" if use_sly else "annotations COCO d'AIcrowd"
    meta = {
        "dataset": args.dataset,
        "kind": "fake" if is_fake else "real",
        "name": "jeu factice généré (formes colorées)" if is_fake
        else f"MyFoodRepo / AIcrowd Food Recognition Benchmark 2022 ({source_label}{', version ' + args.dataset_version if args.dataset_version else ''})",
        "source_format": args.format,
        "dataset_version": args.dataset_version,
        "license": "aucune (jeu factice, aucun aliment réel)" if is_fake
        else "CC BY 4.0 (règles du concours AIcrowd 2022, section 1 ; preuve datée dans docs/scanner/Licences-donnees-modeles.md" + (
            " ; Dataset Ninja affiche CC0 pour sa copie : on retient la plus restrictive, CC BY 4.0)" if use_sly else ")"),
        "license_note_from_download_page": args.license_note,
        "license_files_archived": license_files,
        "attribution": "" if is_fake else "MyFoodRepo / AIcrowd, CC BY 4.0",
        "source_files": source_files,
        "split_method": split_method,
        "split_mode": mode,
        "official_val_used_as_test": mode == "two",
        "photos": dict(photos_per_split),
        "crops": n_per_split,
        "n_classes": len(classes),
        "params": {"margin": args.margin, "min_size": args.min_size, "crop_size": args.crop_size, "seed": args.seed,
                   "dedup_hamming": None if args.no_dedup else args.dedup_hamming, "val_fraction": val_target, "test_fraction": test_target},
        "rejected": {name: dict(d["rejected"]) for name, d in sets.items()},
        "dropped_train_photos_leak": dropped_leak,
        "dropped_photos_by_split": dict(dropped),
        "class_map": str(map_path), "catalog": description,
        "prepared_on": date.today().isoformat(), "git_head": git_head(), "seconds": round(time.time() - t_start, 1),
    }
    write_json(out / "meta.json", meta)
    if not is_fake and not license_files:
        log("ATTENTION : aucun fichier LICENCE* archivé à côté des données : voir README.md (archiver la licence AFFICHÉE au téléchargement).")
    log(f"Terminé en {time.time() - t_start:.1f} s. Résumé : {out / 'meta.json'}")


if __name__ == "__main__":
    main()
