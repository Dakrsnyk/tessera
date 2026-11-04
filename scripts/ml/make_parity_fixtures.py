"""Valeurs de référence PyTorch pour la parité Core ML du scanner (test `FoodModelParityTests` sur le simulateur de la CI).

Pour quelques photos libres de droits de `Tests/Fixtures/FoodPhotos/`, écrit `Tests/Fixtures/FoodModels/parity.json` :
  - segmenteur (RF-DETR-Seg passage 2) : entrée 312 x 312 (étirée, bilinéaire sans anticrénelage, normalisation ImageNet), puis le
    post-traitement que l'app refait en Swift : score = sigmoïde de la colonne 0 des logits (la classe « food » ; la colonne 1 ne sert
    pas), seuil, boîte cx cy l h normalisée -> pixels, masque 78 x 78 agrandi (bilinéaire) puis > 0, fusion des doublons (boîtes à
    IoU >= 0,5 ET masques à IoU >= 0,7, le plus confiant gagne) ;
  - classifieur (DINOv2 affiné + tête MLP, probabilités étalonnées) : sur le recadrage carré de chaque masque (`ml_common.crop_square`,
    marge 0,10, 224 px) et sur un recadrage fixe de la photo entière (pour vérifier le classifieur seul), 5 classes et leur probabilité,
    puis 3 aliments d'Ardane (probabilités des classes d'un même aliment additionnées, `class_map.csv` relue).
Le post-traitement est vérifié contre `rfdetr.predict` (mêmes scores) avant d'écrire quoi que ce soit.

    python make_parity_fixtures.py --segmenter ... --head ... --backbone-weights ... --torch-root ... --out .../parity.json
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

import numpy as np

HERE = Path(__file__).resolve().parent
REPO = HERE.parent.parent
sys.path.insert(0, str(HERE))
from class_matching import read_class_map  # noqa: E402
from ml_common import IMAGE_SIZE, crop_square, load_dinov2_backbone, make_feature_net, make_full_net, rebuild_head  # noqa: E402

PHOTOS = ["01-pomme.jpg", "11-cheeseburger-frites.jpg", "14-pates-bolognaise.jpg", "15-salade-jardin.jpg",
          "21-fish-and-chips.jpg", "24-curry-riz.jpg"]
THRESHOLD = 0.30
MARGIN = 0.10
MEAN = (0.485, 0.456, 0.406)
STD = (0.229, 0.224, 0.225)


def box_iou(a, b) -> float:
    ix = max(0.0, min(a[2], b[2]) - max(a[0], b[0]))
    iy = max(0.0, min(a[3], b[3]) - max(a[1], b[1]))
    inter = ix * iy
    union = (a[2] - a[0]) * (a[3] - a[1]) + (b[2] - b[0]) * (b[3] - b[1]) - inter
    return inter / union if union > 0 else 0.0


def mask_iou(a, b) -> float:
    union = np.logical_or(a, b).sum()
    return float(np.logical_and(a, b).sum() / union) if union else 0.0


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--segmenter", required=True)
    ap.add_argument("--head", required=True)
    ap.add_argument("--backbone-weights", required=True)
    ap.add_argument("--torch-root", required=True)
    ap.add_argument("--class-map", default=str(HERE / "class_map.csv"))
    ap.add_argument("--photos", default=str(REPO / "Tests" / "Fixtures" / "FoodPhotos"))
    ap.add_argument("--out", required=True)
    args = ap.parse_args()

    import torch
    import torch.nn.functional as F
    import rfdetr
    from PIL import Image

    seg = rfdetr.from_checkpoint(args.segmenter)
    module = seg.model.model.eval()
    resolution = int(seg.model.resolution)
    ck = torch.load(args.head, map_location="cpu", weights_only=False)
    labels = [f"mfr:{c['name']}" for c in ck["classes"]]
    feat = make_feature_net(load_dinov2_backbone(Path(args.torch_root), weights_path=args.backbone_weights), ck["pool"])
    net = make_full_net(feat, rebuild_head(ck), float(ck["temperature"]), with_embedding=False)
    food_of = {f"mfr:{r['classe']}": r["id_ardane"] for r in read_class_map(Path(args.class_map))}

    def classify(crop) -> dict:
        x = torch.from_numpy(np.asarray(crop, dtype=np.float32)[None]).permute(0, 3, 1, 2).contiguous()
        with torch.no_grad():
            p = net(x).numpy()[0].astype(float)
        order = np.argsort(-p)
        merged: dict[str, float] = {}
        for k, label in enumerate(labels):
            key = food_of.get(label) or label
            merged[key] = merged.get(key, 0.0) + float(p[k])
        foods = sorted(merged.items(), key=lambda t: -t[1])[:3]
        return {"top5": [{"label": labels[k], "p": round(float(p[k]), 6)} for k in order[:5]],
                "foods": [{"id": key, "p": round(value, 6)} for key, value in foods]}

    photos = []
    for name in PHOTOS:
        with Image.open(Path(args.photos) / name) as im:
            image = im.convert("RGB")       # sans redresser selon l'EXIF : CGImageSourceCreateImageAtIndex non plus
        w, h = image.size
        # = torchvision F.resize(antialias=False) de rfdetr.predict
        x = F.interpolate(torch.from_numpy(np.asarray(image, dtype=np.float32) / 255.0).permute(2, 0, 1)[None],
                          size=(resolution, resolution), mode="bilinear", align_corners=False, antialias=False)
        x = (x - torch.tensor(MEAN).view(1, 3, 1, 1)) / torch.tensor(STD).view(1, 3, 1, 1)
        with torch.no_grad():
            out = module(x)
        logits, boxes, masks = out["pred_logits"][0], out["pred_boxes"][0], out["pred_masks"][0]
        scores = torch.sigmoid(logits[:, 0]).numpy().astype(float)

        # Contrôle : la bibliothèque donne les mêmes scores au-dessus du seuil (sinon le post-traitement Swift serait faux)
        det = seg.predict(image, threshold=THRESHOLD)
        lib = sorted(float(s) for s, c in zip(det.confidence, det.class_id) if int(c) == 0)
        mine = sorted(float(s) for s in scores if s >= THRESHOLD)
        if len(lib) != len(mine) or any(abs(a - b) > 2e-3 for a, b in zip(lib, mine)):
            raise SystemExit(f"{name} : post-traitement différent de rfdetr.predict ({lib[:5]} contre {mine[:5]})")

        keep = [q for q in np.argsort(-scores) if scores[q] >= THRESHOLD]
        dets = []
        for q in keep:
            cx, cy, bw, bh = boxes[q].numpy().astype(float)
            box = [max(0.0, (cx - bw / 2) * w), max(0.0, (cy - bh / 2) * h), min(float(w), (cx + bw / 2) * w), min(float(h), (cy + bh / 2) * h)]
            up = torch.nn.functional.interpolate(masks[q][None, None], size=(h, w), mode="bilinear", align_corners=False)[0, 0]
            dets.append({"query": int(q), "score": float(scores[q]), "box": box, "mask": (up > 0).numpy()})
        kept = []
        for d in dets:
            if all(box_iou(d["box"], k["box"]) < 0.5 or mask_iou(d["mask"], k["mask"]) < 0.7 for k in kept):
                kept.append(d)
        found = []
        for d in kept:
            ys, xs = np.nonzero(d["mask"])
            if len(xs) == 0:
                continue
            bbox = (float(xs.min()), float(ys.min()), float(xs.max() + 1 - xs.min()), float(ys.max() + 1 - ys.min()))
            found.append({"score": round(d["score"], 6), "box": [round(v, 2) for v in d["box"]], "maskBox": [round(v, 2) for v in bbox],
                          "maskArea": round(float(d["mask"].mean()), 6),
                          **classify(crop_square(image, bbox, MARGIN, IMAGE_SIZE))})
        whole = classify(crop_square(image, (0.0, 0.0, float(w), float(h)), 0.0, IMAGE_SIZE))
        photos.append({"file": name, "width": w, "height": h, "detections": found, "wholeImage": whole})
        print(f"{name} : {len(found)} aliment(s) ; {[d['foods'][0]['id'] for d in found]}", flush=True)

    payload = {"about": "Références PyTorch pour FoodModelParityTests (scripts/ml/make_parity_fixtures.py). Ne pas modifier à la main.",
               "segmenter": {"file": Path(args.segmenter).name, "resolution": resolution, "threshold": THRESHOLD,
                             "mean": MEAN, "std": STD, "foodColumn": 0},
               "classifier": {"head": Path(args.head).name, "inputSize": IMAGE_SIZE, "margin": MARGIN, "classes": len(labels)},
               "photos": photos}
    Path(args.out).parent.mkdir(parents=True, exist_ok=True)
    Path(args.out).write_text(json.dumps(payload, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
    print(f"écrit : {args.out}")


if __name__ == "__main__":
    main()
