"""Enregistre, pour chaque photo d'un jeu COCO, TOUTES les zones que garde la chaîne de l'app (segmenteur puis classifieur), avec les
probabilités du classifieur au niveau des aliments d'Ardane : de quoi mesurer hors ligne ce qui se passe APRÈS les modèles (contexte du
repas, seuils) sans les relancer.

    python scripts/ml/dump_zones.py --test-dir <ds/test> --segmenter <...nano.pth> --head <...B-head-mlp.pt> \
        --backbone-weights <...finetuned-backbone.pt> --torch-root <ardane-tools/ml> --out zones-test.json

Comme l'app (`FoodModelRecognizer`, `ScannerModelLogic`) : masques du segmenteur dès `--threshold` (0,10 ici, pour pouvoir étudier les
zones sous le seuil « peut-être » de 0,20), doublons fusionnés, recadrage carré sur la boîte du masque (marge 0,10, 224 px), probabilités
des classes qui mènent au même aliment additionnées (clé = aliment de `ArdaneFoodClassMap.json`, sinon l'étiquette `mfr:<classe>`).
Chaque zone est appariée à au plus un aliment réel (`seg_metrics.match_foods`, un pour un) ; elle est « juste » quand l'IoU atteint 0,5.

Sortie : {"images": [{"id", "truths": [clé, ...], "zones": [{"score", "iou", "truth": indice ou -1, "top": [[clé, p], ... 10]}]}]}.
"""
from __future__ import annotations

import argparse
import json
import sys
import time
from pathlib import Path

import numpy as np

HERE = Path(__file__).resolve().parent
REPO = HERE.parent.parent
sys.path.insert(0, str(HERE))
sys.path.insert(0, str(HERE / "kaggle" / "segmenter"))
import seg_metrics as sm  # noqa: E402
from ml_common import IMAGE_SIZE, crop_square, load_dinov2_backbone, make_feature_net, make_full_net, rebuild_head  # noqa: E402
from pipeline_eval import dedupe, mask_bbox  # noqa: E402

TOP = 10


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--test-dir", required=True)
    ap.add_argument("--segmenter", required=True)
    ap.add_argument("--head", required=True)
    ap.add_argument("--backbone-weights")
    ap.add_argument("--torch-root", required=True)
    ap.add_argument("--app-class-map", default=str(REPO / "App" / "Resources" / "Models" / "ArdaneFoodClassMap.json"))
    ap.add_argument("--class-map", default=str(HERE / "class_map.csv"), help="classes fines de la vérité terrain -> aliment d'Ardane")
    ap.add_argument("--threshold", type=float, default=0.10)
    ap.add_argument("--margin", type=float, default=0.10)
    ap.add_argument("--limit", type=int, default=0)
    ap.add_argument("--out", required=True)
    args = ap.parse_args()

    import torch
    import rfdetr
    from PIL import Image
    from pycocotools.coco import COCO
    from class_matching import read_class_map

    t0 = time.time()
    test_dir = Path(args.test_dir)
    coco = COCO(str(test_dir / "_annotations.coco.json"))
    cat_name = {c["id"]: c["name"] for c in coco.loadCats(coco.getCatIds())}

    app_map = json.loads(Path(args.app_class_map).read_text(encoding="utf-8"))
    key_of_label = {label: (food or label) for label, food in zip(app_map["labels"], app_map["foods"])}
    truth_key = {row["classe"]: (row["id_ardane"] or f"mfr:{row['classe']}") for row in read_class_map(Path(args.class_map))}

    seg = rfdetr.from_checkpoint(args.segmenter)
    seg_names = seg.class_names
    ck = torch.load(args.head, map_location="cpu", weights_only=False)
    cls_names = [c["name"] for c in ck["classes"]]
    missing = [n for n in cls_names if f"mfr:{n}" not in key_of_label]
    if missing:
        raise SystemExit(f"classes du classifieur absentes de la carte de l'app : {missing[:5]}")
    keys = sorted({key_of_label[f"mfr:{n}"] for n in cls_names})
    to_key = np.zeros((len(cls_names), len(keys)), dtype=np.float32)
    for k, name in enumerate(cls_names):
        to_key[k, keys.index(key_of_label[f"mfr:{name}"])] = 1.0
    feat = make_feature_net(load_dinov2_backbone(Path(args.torch_root), weights_path=args.backbone_weights), ck["pool"])
    net = make_full_net(feat, rebuild_head(ck), float(ck["temperature"]), with_embedding=False)

    def classify(crops):
        if not crops:
            return []
        batch = torch.from_numpy(np.stack([np.asarray(c, dtype=np.float32) for c in crops])).permute(0, 3, 1, 2).contiguous()
        with torch.no_grad():
            merged = net(batch).numpy() @ to_key
        return [[[keys[j], round(float(q[j]), 5)] for j in np.argsort(-q)[:TOP]] for q in merged]

    image_ids = sorted(coco.getImgIds())
    if args.limit:
        image_ids = image_ids[:args.limit]
    out = []
    for index, image_id in enumerate(image_ids):
        info = coco.loadImgs([image_id])[0]
        anns = coco.loadAnns(coco.getAnnIds(imgIds=[image_id], iscrowd=False))
        if not anns:
            continue
        path = test_dir / info["file_name"]
        h, w = info["height"], info["width"]
        det = seg.predict(str(path), threshold=args.threshold)
        masks = det.mask if det.mask is not None else np.zeros((0, h, w), dtype=bool)
        if len(masks) and masks.shape[1:] != (h, w):
            masks = np.stack([np.asarray(Image.fromarray(m.astype(np.uint8) * 255).resize((w, h), Image.NEAREST)) > 0 for m in masks])
        scores = np.asarray(det.confidence if det.confidence is not None else np.zeros(len(masks)), dtype=float)
        labels = [int(c) for c in det.class_id] if len(masks) else []
        real = [k for k in range(len(masks)) if 0 <= labels[k] < len(seg_names)]
        masks, scores = (masks[real], scores[real]) if len(masks) else (masks, scores)
        if len(masks):
            unique = dedupe(masks, scores, [tuple(float(v) for v in det.xyxy[k]) for k in real])
            masks, scores = masks[unique], scores[unique]
        order = list(np.argsort(-scores))
        masks, scores = (masks[order], scores[order]) if len(masks) else (masks, scores)
        gt_masks = [coco.annToMask(a).astype(bool) for a in anns]
        truths = [truth_key.get(cat_name[a["category_id"]], f"mfr:{cat_name[a['category_id']]}") for a in anns]
        matches = sm.match_foods(gt_masks, list(masks), list(scores), 0.1)
        truth_of = {m["pred_index"]: (t, m["iou"]) for t, m in enumerate(matches) if m["matched"]}
        boxes = [mask_bbox(m) for m in masks]
        valid = [k for k, b in enumerate(boxes) if b is not None]
        with Image.open(path) as im:
            image = im.convert("RGB")
            tops = classify([crop_square(image, boxes[k], args.margin, IMAGE_SIZE) for k in valid])
        zones = []
        for k, top in zip(valid, tops):
            t, iou = truth_of.get(k, (-1, 0.0))
            zones.append({"score": round(float(scores[k]), 4), "iou": round(float(iou), 4),
                          "truth": t if iou >= 0.5 else -1, "top": top})
        out.append({"id": image_id, "truths": truths, "zones": zones})
        if index % 50 == 0:
            print(f"  {index + 1}/{len(image_ids)} photos ({time.time() - t0:.0f} s)", flush=True)
    Path(args.out).write_text(json.dumps({"set": str(test_dir), "threshold": args.threshold, "images": out}, ensure_ascii=False) + "\n",
                              encoding="utf-8")
    print(f"{len(out)} photos, {sum(len(i['zones']) for i in out)} zones, {time.time() - t0:.0f} s", flush=True)


if __name__ == "__main__":
    main()
