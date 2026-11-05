"""Banc d'essai du scanner, mesuré comme le demandent les objectifs « 90 / 80 / 90 » (plan validé le 2026-11-04,
`docs/scanner/Plan-scanner-90-80-90-2026-11-04.md`) : ce que l'app ferait sur un jeu de photos annotées (COCO), aliment
DISTINCT par aliment distinct de chaque assiette, au niveau des aliments d'Ardane.

Deux étapes :

    # 1. mesure (WSL, venv avec rfdetr/torch ; ARDANE_DINOV2=vitb14 pour le classifieur v4)
    python bench_sets.py run --test-dir <dossier COCO> --segmenter <.pth> --head <head-*.pt> \
        --backbone-weights <finetuned-backbone.pt> --torch-root <racine ML> --class-map class_map.csv --out audit.json
    # 2. analyse (n'importe quel Python avec numpy et scipy)
    python bench_sets.py analyse --audit audit.json --class-map class_map.csv --out rapport.md

`run` garde toutes les zones du segmenteur dès 0,15 (doublons fusionnés comme dans l'app), les 5 premiers aliments d'Ardane du
classifieur (probabilités étalonnées, additionnées par aliment) et l'IoU de chaque zone avec chaque aliment réel. `analyse` en tire,
aux seuils 0,30 (zones sûres) et 0,20 (avec les « peut-être ») :
- précision, rappel, F1 sur les aliments distincts (automatique, 1re proposition), intervalles à 95 % par bootstrap groupé par photo,
  taux de faux positifs et de faux négatifs ; rappel « assisté » (bon aliment parmi les 3 propositions d'une zone) ;
- détail par catégorie et par nombre d'aliments dans la photo (catégories par mots-clés des classes MyFoodRepo : approximatif) ;
- segmentation : IoU des aliments retrouvés (appariés un pour un à IoU ≥ 0,5), IoU en comptant 0 pour les ratés, part ≥ 0,90 ;
- fiabilité des confiances, règle d'ajout automatique (précision des lignes au-dessus d'un seuil, Clopper-Pearson), seuil
  Learn-then-Test choisi sur une moitié des photos et vérifié sur l'autre, nature des erreurs à haute confiance.

Première mesure (2026-11-04, 1 000 photos de test MyFoodRepo, segmenteur passage 2 + classifieur v4) : précision 70,2 %, rappel
57,1 %, F1 63,0 % ; IoU des retrouvés 0,862. Le tableau « Seuil 0.80 » correspond à `ScanRecap.autoAddThreshold` de l'app
(lignes ajoutées seules, build 330) ; « Seuil du segmenteur 0.2 » aux zones « peut-être » (`ScannerModelLogic.tentativeThreshold`).
Aucun fichier du dépôt n'est écrit par ce script.
"""
from __future__ import annotations

import argparse
import csv
import hashlib
import json
import sys
import time
from collections import Counter, defaultdict
from pathlib import Path

HERE = Path(__file__).resolve().parent
MIN_CONF = 0.15        # FoodLabelMatcher.minimumConfidence : l'app ne propose rien en dessous
SEG_FLOOR = 0.15       # plus bas seuil gardé par `run` (les analyses filtrent ensuite)


# ---------------------------------------------------------------------------------------------------------------- run

def run(args) -> None:
    import numpy as np
    sys.path.insert(0, str(HERE))
    sys.path.insert(0, str(HERE / "kaggle" / "segmenter"))
    import rfdetr
    import seg_metrics as sm
    import torch
    from PIL import Image
    from pycocotools.coco import COCO

    from class_matching import read_class_map
    from ml_common import IMAGE_SIZE, crop_square, load_dinov2_backbone, make_feature_net, make_full_net, rebuild_head
    from pipeline_eval import dedupe, mask_bbox

    test_dir = Path(args.test_dir)
    coco = COCO(str(test_dir / "_annotations.coco.json"))
    cat_name = {c["id"]: c["name"] for c in coco.loadCats(coco.getCatIds())}
    seg = rfdetr.from_checkpoint(args.segmenter)
    seg_names = seg.class_names
    ck = torch.load(args.head, map_location="cpu", weights_only=False)
    if ck.get("format") != "ardane-head-v1":
        raise SystemExit("format de tête inconnu")
    cls_names = [c["name"] for c in ck["classes"]]
    feat = make_feature_net(load_dinov2_backbone(Path(args.torch_root), weights_path=args.backbone_weights), ck["pool"])
    net = make_full_net(feat, rebuild_head(ck), float(ck["temperature"]), with_embedding=False)
    group_of = {n: f"classe:{n}" for n in cls_names}
    for row in read_class_map(Path(args.class_map)):
        if row["id_ardane"]:
            group_of[row["classe"]] = row["id_ardane"]
    groups = sorted({group_of[n] for n in cls_names})
    to_group = np.zeros((len(cls_names), len(groups)), dtype=np.float32)
    for k, n in enumerate(cls_names):
        to_group[k, groups.index(group_of[n])] = 1.0

    def classify(crops):
        out = []
        for s in range(0, len(crops), 16):
            batch = torch.from_numpy(np.stack([np.asarray(c, dtype=np.float32) for c in crops[s:s + 16]])).permute(0, 3, 1, 2).contiguous()
            with torch.no_grad():
                out.append(net(batch).numpy() @ to_group)
        return np.concatenate(out) if out else np.zeros((0, len(groups)), dtype=np.float32)

    records, t0 = [], time.time()
    ids = sorted(coco.getImgIds())
    if args.limit:
        ids = ids[:args.limit]
    for index, image_id in enumerate(ids):
        info = coco.loadImgs([image_id])[0]
        anns = coco.loadAnns(coco.getAnnIds(imgIds=[image_id], iscrowd=False))
        if not anns:
            continue
        path = test_dir / info["file_name"]
        h, w = info["height"], info["width"]
        det = seg.predict(str(path), threshold=SEG_FLOOR)
        masks = det.mask if det.mask is not None else np.zeros((0, h, w), dtype=bool)
        if len(masks) and masks.shape[1:] != (h, w):
            masks = np.stack([np.asarray(Image.fromarray(m.astype(np.uint8) * 255).resize((w, h), Image.NEAREST)) > 0 for m in masks])
        scores = np.asarray(det.confidence if det.confidence is not None else np.zeros(len(masks)), dtype=float)
        labels = [int(c) for c in det.class_id] if len(masks) else []
        real = [k for k in range(len(masks)) if 0 <= labels[k] < len(seg_names)]
        if real:
            masks, scores = masks[real], scores[real]
            keep = dedupe(masks, scores, [tuple(float(v) for v in det.xyxy[k]) for k in real])
            masks, scores = masks[keep], scores[keep]
        else:
            masks, scores = np.zeros((0, h, w), dtype=bool), np.zeros(0)
        gt_masks = [coco.annToMask(a).astype(bool) for a in anns]
        gt_names = [cat_name[a["category_id"]] for a in anns]
        with Image.open(path) as im:
            image = im.convert("RGB")
            boxes = [mask_bbox(m) for m in masks]
            valid = [k for k, b in enumerate(boxes) if b is not None]
            probs = classify([crop_square(image, boxes[k], 0.10, IMAGE_SIZE) for k in valid])
        zones = []
        for j, k in enumerate(valid):
            q = probs[j]
            top = np.argsort(-q)[:5]
            zones.append({"score": round(float(scores[k]), 4), "area": round(float(masks[k].mean()), 5),
                          "top": [[groups[i], round(float(q[i]), 4)] for i in top],
                          "ious": [round(float(sm.intersection_over_union(masks[k], g) or 0.0), 4) for g in gt_masks]})
        records.append({"image_id": image_id, "gt": [group_of.get(n, f"classe:{n}") for n in gt_names], "gt_names": gt_names,
                        "gt_area": [round(float(g.mean()), 5) for g in gt_masks], "zones": zones})
        if index % 50 == 0:
            print(f"  {index + 1}/{len(ids)} photos ({time.time() - t0:.0f} s)", flush=True)
    meta = {"test_dir": str(test_dir), "segmenter": args.segmenter, "head": args.head, "backbone_weights": args.backbone_weights,
            "class_map": args.class_map, "seg_floor": SEG_FLOOR, "seconds": round(time.time() - t0, 1)}
    Path(args.out).write_text(json.dumps({"meta": meta, "groups": len(groups), "records": records}, ensure_ascii=False) + "\n", encoding="utf-8")
    print("écrit", args.out, flush=True)


# ------------------------------------------------------------------------------------------------------------ analyse

CATS = [
    ("Boissons", ["water", "coffee", "tea", "wine", "beer", "juice", "espresso", "latte", "cappuccino", "cola", "soda", "drink", "smoothie", "syrup", "ristretto", "macchiato", "lemonade"]),
    ("Sauces, condiments, tartinables", ["sauce", "dressing", "jam", "honey", "mayonnaise", "ketchup", "mustard", "oil", "vinegar", "pesto", "hummus", "spread", "nutella", "gravy", "jelly", "sugar", "salt", "pepper-", "chutney"]),
    ("Produits laitiers", ["cheese", "butter", "yogurt", "yoghurt", "milk", "cream", "mozzarella", "parmesan", "quark", "cottage", "feta", "gruyere", "brie", "camembert", "emmental"]),
    ("Viandes, poissons, oeufs", ["chicken", "beef", "pork", "ham", "salami", "sausage", "bacon", "meat", "steak", "turkey", "lamb", "veal", "fish", "salmon", "tuna", "shrimp", "egg", "prosciutto", "cervelat", "schnitzel", "cordon"]),
    ("Fruits", ["apple", "banana", "orange", "mandarin", "strawberr", "kiwi", "grape", "pear", "peach", "berr", "melon", "pineapple", "mango", "cherr", "apricot", "plum", "fruit", "nectarine", "fig", "lemon", "date"]),
    ("Légumes", ["tomato", "salad", "lettuce", "cucumber", "carrot", "pepper", "onion", "broccoli", "zucchini", "spinach", "mushroom", "bean", "cabbage", "cauliflower", "avocado", "leek", "eggplant", "beetroot", "radish", "corn", "pea", "asparagus", "celery", "vegetable", "garlic", "kohlrabi", "fennel", "pumpkin", "squash", "olive", "rocket", "arugula", "chard", "sprout"]),
    ("Féculents, pains, céréales", ["bread", "toast", "croissant", "roll", "baguette", "muesli", "cereal", "oat", "rice", "pasta", "noodle", "couscous", "quinoa", "polenta", "potato", "spaetzli", "gnocchi", "tortilla", "wrap", "cracker", "rusk", "zwieback", "braid", "bun", "fries", "rösti", "rosti"]),
]


def analyse(args) -> None:
    import numpy as np
    from scipy.stats import beta

    rng = np.random.default_rng(20261104)
    records = json.load(open(args.audit, encoding="utf-8"))["records"]
    fine_of_group = {}
    with open(args.class_map, encoding="utf-8") as f:
        for r in csv.DictReader(f):
            if r["id_ardane"]:
                fine_of_group.setdefault(r["id_ardane"], r["classe"])

    def category(fine):
        name = fine.lower()
        for cat, words in CATS:
            if any(w in name for w in words):
                return cat
        return "Plats, desserts, autres"

    def cat_of_group(g):
        return category(g[len("classe:"):] if g.startswith("classe:") else fine_of_group.get(g, g))

    def zone_food(z):
        for g, p in z["top"]:
            if g.startswith("classe:"):
                continue
            return (g, p) if p >= MIN_CONF else (None, 0.0)
        return None, 0.0

    def greedy_match(zones, n_gt, thr=0.5):
        pairs = sorted(((z["ious"][j], i, j) for i, z in enumerate(zones) for j in range(n_gt) if z["ious"][j] >= thr), reverse=True)
        used_z, used_g, match = set(), set(), {}
        for iou, i, j in pairs:
            if i in used_z or j in used_g:
                continue
            used_z.add(i); used_g.add(j); match[j] = (i, iou)
        return match

    def per_photo(rec, t_seg):
        zones = [z for z in rec["zones"] if z["score"] >= t_seg]
        gt = rec["gt"]
        lines = {}
        for z in zones:
            g, p = zone_food(z)
            if g is not None:
                lines[g] = max(lines.get(g, 0.0), p)
        top3 = {g for z in zones for g in [g for g, p in z["top"] if not g.startswith("classe:")][:3]}
        match = greedy_match(zones, len(gt))
        inst = []
        for j, g in enumerate(gt):
            if j in match:
                i, iou = match[j]
                inst.append((True, zone_food(zones[i])[0] == g, iou))
            else:
                inst.append((False, False, 0.0))
        return {"id": rec["image_id"], "G": set(gt), "P": set(lines), "lines": lines, "top3": top3, "inst": inst, "n": len(zones)}

    def prf(photos):
        tp = sum(len(p["P"] & p["G"]) for p in photos)
        fp = sum(len(p["P"] - p["G"]) for p in photos)
        fn = sum(len(p["G"] - p["P"]) for p in photos)
        P = tp / (tp + fp) if tp + fp else 0.0
        R = tp / (tp + fn) if tp + fn else 0.0
        return P, R, (2 * P * R / (P + R) if P + R else 0.0), tp, fp, fn

    def boot(photos, n=1000):
        idx = np.arange(len(photos))
        vals = np.array([prf([photos[k] for k in rng.choice(idx, size=len(idx), replace=True)])[:3] for _ in range(n)])
        return np.percentile(vals, 2.5, axis=0), np.percentile(vals, 97.5, axis=0)

    pct = lambda x: f"{100 * x:.1f} %"  # noqa: E731
    out = [f"# Banc d'essai du scanner : `{args.audit}`", ""]
    for t_seg in (0.30, 0.20):
        photos = [per_photo(r, t_seg) for r in records]
        P, R, F, tp, fp, fn = prf(photos)
        lo, hi = boot(photos)
        nG = sum(len(p["G"]) for p in photos)
        inst = [x for p in photos for x in p["inst"]]
        ious = [x[2] for x in inst if x[0]]
        out += [f"## Seuil du segmenteur {t_seg}", "",
                f"- Photos {len(photos)} ; aliments distincts réels {nG} ; proposés {tp + fp} ; zones {sum(p['n'] for p in photos)}",
                f"- **Automatique** : précision **{pct(P)}** [{pct(lo[0])} ; {pct(hi[0])}], rappel **{pct(R)}** [{pct(lo[1])} ; {pct(hi[1])}], "
                f"F1 **{pct(F)}** [{pct(lo[2])} ; {pct(hi[2])}] (VP {tp}, FP {fp}, FN {fn} ; faux positifs {pct(fp / max(1, tp + fp))} des proposés ; "
                f"faux négatifs {pct(fn / max(1, nG))} des réels)",
                f"- **Assisté** (bon aliment parmi les 3 propositions d'une zone) : rappel {pct(sum(len(p['G'] & p['top3']) for p in photos) / max(1, nG))}",
                f"- Par annotation : retrouvés {pct(np.mean([x[0] for x in inst]))}, bien nommés {pct(np.mean([x[1] for x in inst]))}",
                f"- Segmentation : IoU des retrouvés **{np.mean(ious):.3f}** ; en comptant 0 pour les ratés **{np.mean([x[2] for x in inst]):.3f}** ; "
                f"retrouvés à IoU ≥ 0,90 : {pct(np.mean(np.array(ious) >= 0.9))}", "",
                "| Catégorie | Aliments réels | Précision | Rappel | F1 |", "|---|---|---|---|---|"]
        ct, cf, cn = defaultdict(int), defaultdict(int), defaultdict(int)
        for p in photos:
            for g in p["P"] & p["G"]:
                ct[cat_of_group(g)] += 1
            for g in p["P"] - p["G"]:
                cf[cat_of_group(g)] += 1
            for g in p["G"] - p["P"]:
                cn[cat_of_group(g)] += 1
        for cat in sorted(set(ct) | set(cn) | set(cf), key=lambda c: -(ct[c] + cn[c])):
            a, b, c = ct[cat], cf[cat], cn[cat]
            p_, r_ = (a / (a + b) if a + b else 0.0), (a / (a + c) if a + c else 0.0)
            out.append(f"| {cat} | {a + c} | {pct(p_)} | {pct(r_)} | {pct(2 * p_ * r_ / (p_ + r_) if p_ + r_ else 0.0)} |")
        out += ["", "| Aliments distincts dans la photo | Photos | Précision | Rappel | F1 |", "|---|---|---|---|---|"]
        for lab, cond in (("1", lambda n: n == 1), ("2", lambda n: n == 2), ("3 et plus", lambda n: n >= 3)):
            sub = [p for p in photos if cond(len(p["G"]))]
            a = prf(sub)
            out.append(f"| {lab} | {len(sub)} | {pct(a[0])} | {pct(a[1])} | {pct(a[2])} |")
        out.append("")

    photos = [per_photo(r, 0.30) for r in records]
    lines = [(conf, g in p["G"], int(hashlib.sha256(str(p["id"]).encode()).hexdigest(), 16) % 2, cat_of_group(g))
             for p in photos for g, conf in p["lines"].items()]
    conf = np.array([x[0] for x in lines]); ok = np.array([x[1] for x in lines]); half = np.array([x[2] for x in lines])
    nG = sum(len(p["G"]) for p in photos)
    out += ["## Confiances et ajout automatique (seuil 0,30)", "", "| Confiance annoncée | Lignes | Justes |", "|---|---|---|"]
    ece = 0.0
    for a, b in [(0.15, 0.3), (0.3, 0.5), (0.5, 0.7), (0.7, 0.8), (0.8, 0.9), (0.9, 0.95), (0.95, 1.01)]:
        m = (conf >= a) & (conf < b)
        if m.sum():
            ece += m.sum() / len(conf) * abs(ok[m].mean() - conf[m].mean())
            out.append(f"| {a:.2f} à {min(b, 1):.2f} (moy. {conf[m].mean():.2f}) | {m.sum()} | {pct(ok[m].mean())} |")
    out += ["", f"ECE {ece:.3f}", "", "| Seuil | Lignes ajoutées seules | Précision (IC 95 %) | Aliments réels ajoutés seuls |", "|---|---|---|---|"]
    for c in (0.5, 0.7, 0.8, 0.9, 0.95):
        m = conf >= c
        k, n = int(ok[m].sum()), int(m.sum())
        lo = beta.ppf(0.025, k, n - k + 1) if k > 0 else 0.0
        hi = beta.ppf(0.975, k + 1, n - k) if k < n else 1.0
        out.append(f"| {c:.2f} | {n} | {pct(k / n if n else 0)} [{pct(lo)} ; {pct(hi)}] | {pct(k / max(1, nG))} |")
    out += ["", "Précision des lignes ≥ 0,80 par catégorie : " + " ; ".join(
        f"{cat} {pct(np.mean([x[1] for x in lines if x[0] >= 0.8 and x[3] == cat]))} (n = {sum(1 for x in lines if x[0] >= 0.8 and x[3] == cat)})"
        for cat in sorted({x[3] for x in lines if x[0] >= 0.8}))]
    out += ["", "### Learn-then-Test (seuil choisi sur une moitié des photos, vérifié sur l'autre ; δ = 0,10)", ""]
    for alpha in (0.10, 0.05):
        valid = []
        for c in np.round(np.arange(0.99, 0.495, -0.01), 2):        # séquence fixe : du plus haut au plus bas, arrêt au premier échec
            m = (conf >= c) & (half == 0)
            n, err = int(m.sum()), int((~ok[m]).sum())
            if n == 0 or beta.ppf(0.9, err + 1, n - err) > alpha:
                break
            valid.append(c)
        if valid:
            c = min(valid)
            m = (conf >= c) & (half == 1)
            out.append(f"- Risque {pct(alpha)} : seuil {c:.2f} ; sur l'autre moitié, {int(m.sum())} lignes, précision {pct(ok[m].mean() if m.sum() else 0)}")
        else:
            out.append(f"- Risque {pct(alpha)} : aucun seuil ne le garantit sur ce jeu.")
    out.append("")
    report = "\n".join(out) + "\n"
    if args.out:
        Path(args.out).write_text(report, encoding="utf-8")
    print(report)


def main() -> None:
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8")       # console Windows (cp1252) : « ≥ », « é »…
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    sub = ap.add_subparsers(dest="cmd", required=True)
    r = sub.add_parser("run", help="mesure (segmenteur + classifieur) et écrit le JSON d'audit")
    r.add_argument("--test-dir", required=True)
    r.add_argument("--segmenter", required=True)
    r.add_argument("--head", required=True)
    r.add_argument("--backbone-weights")
    r.add_argument("--torch-root", required=True)
    r.add_argument("--class-map", default=str(HERE / "class_map.csv"))
    r.add_argument("--limit", type=int, default=0)
    r.add_argument("--out", required=True)
    a = sub.add_parser("analyse", help="précision, rappel, F1, IoU, confiances depuis le JSON d'audit")
    a.add_argument("--audit", required=True)
    a.add_argument("--class-map", default=str(HERE / "class_map.csv"))
    a.add_argument("--out")
    args = ap.parse_args()
    run(args) if args.cmd == "run" else analyse(args)


if __name__ == "__main__":
    main()
