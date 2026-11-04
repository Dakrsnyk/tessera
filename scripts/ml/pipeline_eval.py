"""Mesure de BOUT EN BOUT sur le TEST officiel MyFoodRepo : segmenteur (où sont les aliments) puis classifieur (quel aliment).

Pour chaque photo du test (« validation 2.0 », jamais utilisée pour régler) :
  1. le segmenteur RF-DETR-Seg donne des masques (confiance >= `--threshold`, fixée d'avance à 0,30) ;
  2. chaque aliment réel est apparié à au plus un masque (`seg_metrics.match_foods` : glouton, un pour un, sans tenir compte de la classe) ;
  3. le masque apparié est recadré comme à l'entraînement du classifieur (`ml_common.crop_square`, boîte du masque, marge 0,10, 224 px)
     puis classé par le classifieur (DINOv2 affiné + tête, probabilités étalonnées).

Un aliment réel compte comme RECONNU quand il est retrouvé (IoU >= 0,5) ET que sa classe est la 1re proposition (Top-1) ou dans les
3 premières (Top-3). Deux repères, sur les mêmes aliments : le classifieur sur la boîte HUMAINE (ce que dit RESULTS.md, sans
segmenteur) et l'étiquette donnée par le segmenteur lui-même. Ventilation par nombre d'aliments dans la photo : 1, 2, 3 et plus
(les assiettes mélangées). Les classes sont les 498 classes fines de MyFoodRepo : une confusion entre deux classes proches (deux
pains complets) compte comme une erreur ici, même si elles mènent au même aliment Ardane.

Avec `--class-map` (class_map.csv relue), la mesure est AUSSI faite au niveau des aliments d'Ardane : les probabilités des classes qui
mènent au même aliment sont additionnées avant de choisir les 3 propositions (ce que fera l'app : « café » et « espresso » ne prennent
plus deux places sur trois). Une classe sans aliment d'Ardane reste seule.
"""
from __future__ import annotations

import argparse
import json
import sys
import time
from pathlib import Path

import numpy as np

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
sys.path.insert(0, str(HERE / "kaggle" / "segmenter"))
import seg_metrics as sm  # noqa: E402
from ml_common import IMAGE_SIZE, crop_square, load_dinov2_backbone, make_feature_net, make_full_net, rebuild_head  # noqa: E402

BUCKETS = ("1", "2", "3 et plus")


def bucket_of(n: int) -> str:
    return "1" if n == 1 else "2" if n == 2 else "3 et plus"


def mask_bbox(mask):
    ys, xs = np.nonzero(mask)
    if len(xs) == 0:
        return None
    x0, y0, x1, y1 = xs.min(), ys.min(), xs.max() + 1, ys.max() + 1
    return (float(x0), float(y0), float(x1 - x0), float(y1 - y0))


def dedupe(masks, scores, boxes, overlap: float = 0.7) -> list[int]:
    """Indices gardés après fusion des doublons : RF-DETR peut rendre le MÊME aliment plusieurs fois avec des classes différentes
    (une proposition par classe candidate). On garde le plus confiant, on écarte ceux qui le recouvrent à IoU de masque >= `overlap`
    (calculé seulement quand les boîtes se recouvrent déjà à 0,5). Sans tenir compte de la classe : le classifieur nomme ensuite."""
    def box_iou(a, b):
        ix = max(0.0, min(a[2], b[2]) - max(a[0], b[0]))
        iy = max(0.0, min(a[3], b[3]) - max(a[1], b[1]))
        inter = ix * iy
        union = (a[2] - a[0]) * (a[3] - a[1]) + (b[2] - b[0]) * (b[3] - b[1]) - inter
        return inter / union if union > 0 else 0.0

    kept: list[int] = []
    for k in sorted(range(len(masks)), key=lambda j: -scores[j]):
        if all(box_iou(boxes[k], boxes[j]) < 0.5 or (sm.intersection_over_union(masks[k], masks[j]) or 0.0) < overlap for j in kept):
            kept.append(k)
    return kept


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--test-dir", required=True, help="dossier `test` du jeu RF-DETR (_annotations.coco.json + photos)")
    ap.add_argument("--segmenter", required=True, help="point de contrôle RF-DETR-Seg (.pth)")
    ap.add_argument("--head", required=True, help="tête du classifieur (head-*.pt, format ardane-head-v1)")
    ap.add_argument("--backbone-weights", help="DINOv2 affiné (finetuned-backbone.pt) ; sans : DINOv2 officiel")
    ap.add_argument("--torch-root", required=True, help="racine ML dont `torch_home` contient DINOv2 (torch.hub)")
    ap.add_argument("--threshold", type=float, nargs="+", default=[0.30],
                    help="un ou plusieurs seuils (une seule prédiction au plus bas, puis filtrage) ; choisir sur la VALIDATION, pas sur le test")
    ap.add_argument("--margin", type=float, default=0.10)
    ap.add_argument("--limit", type=int, default=0)
    ap.add_argument("--class-map", help="class_map.csv relue : mesure aussi au niveau des aliments d'Ardane (probabilités additionnées)")
    ap.add_argument("--out", required=True, help="rapport JSON ; le Markdown est écrit à côté")
    args = ap.parse_args()

    import torch
    import rfdetr
    from PIL import Image
    from pycocotools.coco import COCO

    t0 = time.time()
    sm.selftest()
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
    group_of = {name: f"classe:{name}" for name in cls_names}      # sans class_map : chaque classe est son propre groupe
    if args.class_map:
        from class_matching import read_class_map
        for row in read_class_map(Path(args.class_map)):
            if row["classe"] in group_of and row["id_ardane"]:
                group_of[row["classe"]] = row["id_ardane"]
    groups = sorted(set(group_of.values()))
    to_group = np.zeros((len(cls_names), len(groups)), dtype=np.float32)
    for k, name in enumerate(cls_names):
        to_group[k, groups.index(group_of[name])] = 1.0

    def classify(crops):
        """Par recadrage : (3 classes fines, 3 groupes « aliment d'Ardane » après addition des probabilités)."""
        if not crops:
            return []
        batch = torch.from_numpy(np.stack([np.asarray(c, dtype=np.float32) for c in crops])).permute(0, 3, 1, 2).contiguous()
        with torch.no_grad():
            probs = net(batch).numpy()
        merged = probs @ to_group
        return [([cls_names[k] for k in np.argsort(-p)[:3]], [groups[k] for k in np.argsort(-q)[:3]]) for p, q in zip(probs, merged)]

    thresholds = sorted(set(args.threshold))
    image_ids = sorted(coco.getImgIds())
    if args.limit:
        image_ids = image_ids[:args.limit]
    foods = {t: [] for t in thresholds}          # par seuil : un enregistrement par aliment réel
    n_pred = {t: {b: 0 for b in BUCKETS} for t in thresholds}
    n_matched = {t: {b: 0 for b in BUCKETS} for t in thresholds}       # masques gardés appariés à un aliment réel (IoU >= 0,1)
    for index, image_id in enumerate(image_ids):
        info = coco.loadImgs([image_id])[0]
        anns = coco.loadAnns(coco.getAnnIds(imgIds=[image_id], iscrowd=False))
        if not anns:
            continue
        path = test_dir / info["file_name"]
        h, w = info["height"], info["width"]
        det = seg.predict(str(path), threshold=thresholds[0])
        masks = det.mask if det.mask is not None else np.zeros((0, h, w), dtype=bool)
        if len(masks) and masks.shape[1:] != (h, w):
            masks = np.stack([np.asarray(Image.fromarray(m.astype(np.uint8) * 255).resize((w, h), Image.NEAREST)) > 0 for m in masks])
        scores = np.asarray(det.confidence if det.confidence is not None else np.zeros(len(masks)), dtype=float)
        labels = [int(c) for c in det.class_id] if len(masks) else []
        real = [k for k in range(len(masks)) if 0 <= labels[k] < len(seg_names)]
        masks, scores, labels = masks[real] if len(masks) else masks, scores[real] if len(scores) else scores, [labels[k] for k in real]
        if len(masks):
            unique = dedupe(masks, scores, [tuple(float(v) for v in det.xyxy[k]) for k in real])
            masks, scores, labels = masks[unique], scores[unique], [labels[k] for k in unique]
        bucket = bucket_of(len(anns))
        gt_masks = [coco.annToMask(a).astype(bool) for a in anns]
        with Image.open(path) as im:
            image = im.convert("RGB")
            gt_top = classify([crop_square(image, tuple(a["bbox"]), args.margin, IMAGE_SIZE) for a in anns])
            cache = {}           # masque prédit -> 3 propositions du classifieur (un masque n'est classé qu'une fois pour tous les seuils)
            for t in thresholds:
                keep = [k for k in range(len(masks)) if scores[k] >= t]
                n_pred[t][bucket] += len(keep)
                matches = sm.match_foods(gt_masks, [masks[k] for k in keep], [scores[k] for k in keep], 0.1)
                n_matched[t][bucket] += sum(1 for m in matches if m["matched"])
                todo = [keep[m["pred_index"]] for m in matches if m["matched"] and keep[m["pred_index"]] not in cache]
                boxes = [(k, mask_bbox(masks[k])) for k in todo]
                boxes = [(k, b) for k, b in boxes if b is not None]
                for (k, _), top in zip(boxes, classify([crop_square(image, b, args.margin, IMAGE_SIZE) for _, b in boxes])):
                    cache[k] = top
                for a, m, (top_gt, _) in zip(anns, matches, gt_top):
                    truth = cat_name[a["category_id"]]
                    group = group_of.get(truth, f"classe:{truth}")
                    found = m["iou"] >= 0.5
                    k = keep[m["pred_index"]] if m["matched"] else None
                    top_seg, top_group = cache.get(k, ([], [])) if k is not None else ([], [])
                    foods[t].append({"image_id": image_id, "bucket": bucket, "truth": truth, "iou": m["iou"], "found": found,
                                     "pipeline_top1": found and bool(top_seg) and top_seg[0] == truth,
                                     "pipeline_top3": found and truth in top_seg,
                                     "ardane_top1": found and bool(top_group) and top_group[0] == group,
                                     "ardane_top3": found and group in top_group,
                                     "human_box_top1": top_gt[0] == truth, "human_box_top3": truth in top_gt,
                                     "segmenter_label_top1": found and k is not None and seg_names[labels[k]] == truth,
                                     "top3": top_seg, "top3_ardane": top_group})
        if index % 50 == 0:
            print(f"  {index + 1}/{len(image_ids)} photos ({time.time() - t0:.0f} s)", flush=True)

    def summary(rows, predictions, matched):
        n = len(rows)
        out = {"foods": n, "predictions": predictions, "precision": matched / predictions if predictions else None}
        for key in ("found", "pipeline_top1", "pipeline_top3", "ardane_top1", "ardane_top3", "human_box_top1", "human_box_top3",
                    "segmenter_label_top1"):
            k = sum(1 for r in rows if r[key])
            out[key] = k / n if n else None
            out[key + "_wilson95"] = sm.wilson_interval(k, n) if n else None
        return out

    images = len({f["image_id"] for f in foods[thresholds[0]]})
    report = {"images": images, "test_dir": str(test_dir), "thresholds": thresholds, "margin": args.margin,
              "segmenter": args.segmenter, "head": args.head, "backbone_weights": args.backbone_weights, "class_map": args.class_map,
              "by_threshold": {str(t): {"all": summary(foods[t], sum(n_pred[t].values()), sum(n_matched[t].values())),
                                        "by_items": {b: {"images": len({f["image_id"] for f in foods[t] if f["bucket"] == b}),
                                                         **summary([f for f in foods[t] if f["bucket"] == b], n_pred[t][b], n_matched[t][b])}
                                                     for b in BUCKETS}}
                               for t in thresholds},
              "seconds": round(time.time() - t0, 1)}
    out = Path(args.out)
    out.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    (out.with_suffix(".foods.json")).write_text(json.dumps({str(t): rows for t, rows in foods.items()}, ensure_ascii=False) + "\n", encoding="utf-8")

    pct = lambda x: "-" if x is None else f"{100 * x:.1f} %"  # noqa: E731
    lines = ["# Segmenteur + classifieur : mesure de bout en bout sur MyFoodRepo", "",
             f"Jeu : `{test_dir}` ({images} photos) ; recadrage marge {args.margin} ; 498 classes fines"
             + (f" ; aliments d'Ardane : `{args.class_map}` ({len(groups)} groupes)." if args.class_map else "."), ""]
    for t in thresholds:
        r = report["by_threshold"][str(t)]
        lines += [f"## Seuil du segmenteur {t}", "",
                  "| Aliments dans la photo | Photos | Aliments réels | Masques gardés (justes) | Retrouvés (IoU >= 0,5) | Reconnus Top-1 | Reconnus Top-3 | "
                  "Aliment Ardane Top-1 / Top-3 | Repère : classifieur sur la boîte humaine Top-1 / Top-3 | Repère : étiquette du segmenteur Top-1 |",
                  "|---|---|---|---|---|---|---|---|---|---|"]
        for name, s in [(b, r["by_items"][b]) for b in BUCKETS] + [("Toutes", {**r["all"], "images": images})]:
            ardane = f"{pct(s['ardane_top1'])} / {pct(s['ardane_top3'])}" if args.class_map else "-"
            lines.append(f"| {name} | {s['images']} | {s['foods']} | {s['predictions']} ({pct(s['precision'])}) | {pct(s['found'])} | {pct(s['pipeline_top1'])} | {pct(s['pipeline_top3'])} | "
                         f"{ardane} | {pct(s['human_box_top1'])} / {pct(s['human_box_top3'])} | {pct(s['segmenter_label_top1'])} |")
        lines.append("")
    lines += ["« Reconnu » = retrouvé par le segmenteur ET bonne classe parmi les propositions du classifieur. Photos suisses annotées : "
              "ce n'est pas la précision d'Ardane sur l'iPhone (mesurée plus tard sur les repas pesés)."]
    out.with_suffix(".md").write_text("\n".join(lines) + "\n", encoding="utf-8")
    print("\n".join(lines), flush=True)


if __name__ == "__main__":
    main()
