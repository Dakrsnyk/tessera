"""Évaluation du segmenteur sur le TEST officiel (MyFoodRepo « validation 2.0 », jamais utilisé pour régler) :

  1. mAP de MASQUE et de boîte (COCOeval de pycocotools, protocole COCO : AP 0,5:0,95, AP50, AP75, petits / moyens / grands) ;
  2. IoU et Dice moyens PAR ALIMENT avec les définitions de `Tests/Support/ScanMetrics.swift` (port Python `seg_metrics.py`, mêmes cas limites) :
     pour chaque aliment réel (hors foules), la meilleure prédiction libre (appariement glouton, un pour un, à confiance >= `op_threshold`) ;
     un aliment non retrouvé compte 0. Rappel à IoU >= 0,5 avec intervalle de Wilson ;
  3. latence d'une prédiction sur CE GPU (médiane et p95 par PERCENTILE.INC) : information, PAS la vitesse d'un iPhone.

Le seuil d'exploitation (0,30 par défaut) n'est pas réglé sur le test : c'est une valeur fixée d'avance, à ajuster plus tard sur la validation.
"""
from __future__ import annotations

import json
import time
from pathlib import Path

import numpy as np

import seg_metrics as sm


def _load_coco(path: Path):
    from pycocotools.coco import COCO

    return COCO(str(path))


def predict_all(model, coco_gt, images_dir: Path, *, threshold: float, keep_threshold: float, batch: int = 4, limit: int = 0, log=print):
    """Parcourt les images du test. Retourne (résultats COCO pour COCOeval, par image : masques prédits / confiances au seuil d'exploitation).

    Seuls les masques à confiance >= `keep_threshold` sont gardés en mémoire (en RLE pour COCOeval, pleine taille pour l'IoU par aliment) :
    garder ceux du seuil de mAP (0,01, des centaines par image) a saturé la mémoire de Kaggle au tiers du test (2026-11-03)."""
    from pycocotools import mask as mask_utils

    names = model.class_names
    cat_by_name = {c["name"]: c["id"] for c in coco_gt.loadCats(coco_gt.getCatIds())}
    missing = [n for n in names if n not in cat_by_name]
    if missing:
        raise RuntimeError(f"classes du modèle absentes du test : {missing[:5]}")
    image_ids = sorted(coco_gt.getImgIds())
    if limit:
        image_ids = image_ids[:limit]
    results, per_image = [], []
    t0 = time.time()
    for start in range(0, len(image_ids), batch):
        ids = image_ids[start:start + batch]
        infos = coco_gt.loadImgs(ids)
        paths = [str(images_dir / info["file_name"]) for info in infos]
        detections = model.predict(paths, threshold=threshold)
        if not isinstance(detections, list):
            detections = [detections]
        for info, det in zip(infos, detections):
            h, w = info["height"], info["width"]
            masks = det.mask if det.mask is not None else np.zeros((0, h, w), dtype=bool)
            if masks.shape[1:] != (h, w) and len(masks):
                from PIL import Image
                masks = np.stack([np.asarray(Image.fromarray(m.astype(np.uint8) * 255).resize((w, h), Image.NEAREST)) > 0 for m in masks])
            scores = det.confidence if det.confidence is not None else np.zeros(len(masks))
            # Le logit d'indice len(classes) est l'emplacement « aucun objet » (« __background__ » dans rfdetr.predict) : ce n'est pas un aliment.
            real = np.array([0 <= int(c) < len(names) for c in det.class_id], dtype=bool) if len(masks) else np.zeros(0, dtype=bool)
            if len(masks) and not real.all():
                masks, scores = masks[real], np.asarray(scores)[real]
                det = det[real]
            for k in range(len(masks)):
                rle = mask_utils.encode(np.asfortranarray(masks[k].astype(np.uint8)))
                rle["counts"] = rle["counts"].decode("ascii")
                x0, y0, x1, y1 = (float(v) for v in det.xyxy[k])
                results.append({"image_id": info["id"], "category_id": cat_by_name[names[int(det.class_id[k])]], "score": float(scores[k]),
                                "segmentation": rle, "bbox": [x0, y0, x1 - x0, y1 - y0]})
            scores = np.asarray(scores, dtype=float)
            kept = scores >= keep_threshold
            per_image.append({"image_id": info["id"], "pred_masks": masks[kept] if len(masks) else masks, "pred_scores": scores[kept]})
            del masks, det
        if (start // batch) % 20 == 0:
            log(f"    prédictions : {min(start + batch, len(image_ids))}/{len(image_ids)} images ({time.time() - t0:.0f} s)")
    return results, per_image


def coco_metrics(coco_gt, results, iou_type: str, image_ids) -> dict:
    from pycocotools.cocoeval import COCOeval

    if not results:
        return {"AP": 0.0, "AP50": 0.0, "AP75": 0.0, "APs": 0.0, "APm": 0.0, "APl": 0.0, "note": "aucune détection"}
    coco_dt = coco_gt.loadRes(results)
    ev = COCOeval(coco_gt, coco_dt, iou_type)
    ev.params.imgIds = list(image_ids)
    ev.evaluate()
    ev.accumulate()
    ev.summarize()
    s = ev.stats
    value = lambda v: None if v < 0 else float(v)      # COCOeval renvoie -1 quand aucune vérité terrain n'existe dans la catégorie de taille  # noqa: E731
    return {"AP": value(s[0]), "AP50": value(s[1]), "AP75": value(s[2]), "APs": value(s[3]), "APm": value(s[4]), "APl": value(s[5]),
            "AR100": value(s[8])}


def per_food_metrics(coco_gt, per_image: list[dict], op_threshold: float, min_iou: float = 0.1) -> dict:
    """IoU / Dice par aliment réel (ScanMetrics) au seuil d'exploitation ; ventilé par classe pour les classes les plus fréquentes."""
    foods, n_pred, by_class, by_items = [], 0, {}, {}
    cats = {c["id"]: c["name"] for c in coco_gt.loadCats(coco_gt.getCatIds())}
    for item in per_image:
        anns = [a for a in coco_gt.loadAnns(coco_gt.getAnnIds(imgIds=[item["image_id"]], iscrowd=False))]
        gt_masks = [coco_gt.annToMask(a).astype(bool) for a in anns]
        keep = item["pred_scores"] >= op_threshold
        pred_masks = [m for m, k in zip(item["pred_masks"], keep) if k]
        pred_scores = [float(s) for s, k in zip(item["pred_scores"], keep) if k]
        n_pred += len(pred_masks)
        res = sm.match_foods(gt_masks, pred_masks, pred_scores, min_iou)
        bucket = "1" if len(anns) == 1 else "2" if len(anns) == 2 else "3 et plus"     # assiettes simples contre assiettes mélangées
        by_items.setdefault(bucket, {"images": 0, "foods": [], "predictions": 0})
        by_items[bucket]["images"] += 1
        by_items[bucket]["predictions"] += len(pred_masks)
        for a, r in zip(anns, res):
            foods.append(r)
            by_class.setdefault(a["category_id"], []).append(r)
            by_items[bucket]["foods"].append(r)
    summary = sm.summarize_foods(foods, n_pred)
    summary["by_items"] = {k: {"images": v["images"], **sm.summarize_foods(v["foods"], v["predictions"])}
                           for k, v in sorted(by_items.items())}
    top = sorted(by_class.items(), key=lambda kv: -len(kv[1]))[:25]
    summary["by_class_top25"] = [{"category": cats[cid], "foods": len(rs), "mean_iou": sm.mean([r["iou"] for r in rs]),
                                  "mean_dice": sm.mean([r["dice"] for r in rs])} for cid, rs in top]
    summary["op_threshold"], summary["min_iou_for_matching"] = op_threshold, min_iou
    return summary


def latency(model, paths: list[str], n: int = 40, log=print) -> dict:
    """Latence d'une prédiction (image seule) sur ce GPU. Les 5 premières sont écartées (chauffe)."""
    import torch

    times = []
    for i, path in enumerate((paths * ((n + 5) // max(1, len(paths)) + 1))[:n + 5]):
        if torch.cuda.is_available():
            torch.cuda.synchronize()
        t = time.perf_counter()
        model.predict(path, threshold=0.3)
        if torch.cuda.is_available():
            torch.cuda.synchronize()
        if i >= 5:
            times.append((time.perf_counter() - t) * 1000.0)
    return {"p50_ms": sm.median(times), "p95_ms": sm.percentile(times, 95), "n": len(times),
            "device": torch.cuda.get_device_name(0) if torch.cuda.is_available() else "cpu",
            "note": "latence de ce GPU, bout en bout (prétraitement, réseau, masques) ; PAS la vitesse d'un iPhone"}


def evaluate_checkpoint(checkpoint: Path, test_dir: Path, *, op_threshold: float = 0.30, ap_threshold: float = 0.01, limit: int = 0,
                        batch: int = 4, with_latency: bool = True, log=print) -> dict:
    import rfdetr

    sm.selftest()
    coco_gt = _load_coco(test_dir / "_annotations.coco.json")
    model = rfdetr.from_checkpoint(str(checkpoint))
    results, per_image = predict_all(model, coco_gt, test_dir, threshold=ap_threshold, keep_threshold=op_threshold, batch=batch, limit=limit, log=log)
    image_ids = [p["image_id"] for p in per_image]
    out = {"checkpoint": str(checkpoint), "images": len(image_ids), "detections": len(results),
           "ap_threshold": ap_threshold, "classes": len(model.class_names)}
    out["segm"] = coco_metrics(coco_gt, results, "segm", image_ids)
    out["bbox"] = coco_metrics(coco_gt, results, "bbox", image_ids)
    out["per_food"] = per_food_metrics(coco_gt, per_image, op_threshold)
    if with_latency:
        infos = coco_gt.loadImgs(image_ids[:20])
        out["latency"] = latency(model, [str(test_dir / i["file_name"]) for i in infos])
    return out


def write_report(path: Path, size: str, metrics: dict, extra: dict, fake: bool = False) -> str:
    """Rapport Markdown du segmenteur (chiffres du TEST officiel)."""
    pf, sg, bb = metrics["per_food"], metrics["segm"], metrics["bbox"]
    pct = lambda x: "-" if x is None else f"{100 * x:.1f} %"  # noqa: E731
    f3 = lambda x: "-" if x is None else f"{x:.3f}"  # noqa: E731
    w = []
    w.append(f"# Segmenteur RF-DETR-Seg {size} : résultats sur le TEST officiel" + (" (JEU FACTICE)" if fake else ""))
    w.append("")
    if fake:
        w.append("> **JEU FACTICE.** Ces chiffres prouvent seulement que la chaîne tourne.")
        w.append("")
    w.append(f"- Images de test : {metrics['images']} ; classes du modèle : {metrics['classes']} ; détections au seuil {metrics['ap_threshold']} : {metrics['detections']}.")
    w.append(f"- Jeu : MyFoodRepo / AIcrowd Food Recognition Benchmark 2022, CC BY 4.0 ; modèle de départ : RF-DETR-Seg {size} (Apache 2.0) ; "
             f"entraînement sur la partie « train » seulement.")
    w.append("")
    w.append("## mAP COCO (protocole standard, pycocotools)")
    w.append("| | AP 0,5:0,95 | AP50 | AP75 | AP petits | AP moyens | AP grands |")
    w.append("|---|---|---|---|---|---|---|")
    for name, m in (("masque", sg), ("boîte", bb)):
        w.append(f"| {name} | {f3(m['AP'])} | {f3(m['AP50'])} | {f3(m['AP75'])} | {f3(m['APs'])} | {f3(m['APm'])} | {f3(m['APl'])} |")
    w.append("")
    w.append(f"## IoU et Dice par aliment (définitions de ScanMetrics.swift, seuil d'exploitation {pf['op_threshold']})")
    wil = pf["recall_iou50_wilson95"]
    w.append(f"- Aliments réels : {pf['foods']} ; prédictions retenues : {pf['predictions']} ; appariées : {pf['matched']}.")
    w.append(f"- **IoU moyen {f3(pf['mean_iou'])}**, **Dice moyen {f3(pf['mean_dice'])}** (les aliments non retrouvés comptent 0) ; "
             f"sur les seuls aliments retrouvés : IoU {f3(pf['mean_iou_matched'])}, Dice {f3(pf['mean_dice_matched'])}.")
    w.append(f"- Rappel à IoU >= 0,5 : {pct(pf['recall_iou50'])}" + (f" (Wilson 95 % : {pct(wil[0])} à {pct(wil[1])})" if wil else "")
             + f" ; précision des prédictions : {pct(pf['precision_matched'])} ; IoU médian {f3(pf['median_iou'])}.")
    w.append("")
    w.append("### Selon le nombre d'aliments dans l'assiette (assiettes mélangées = 3 et plus)")
    w.append("| Aliments dans la photo | Photos | Aliments réels | Rappel à IoU >= 0,5 | IoU moyen | Précision des prédictions |")
    w.append("|---|---|---|---|---|---|")
    for bucket, b in pf.get("by_items", {}).items():
        w.append(f"| {bucket} | {b['images']} | {b['foods']} | {pct(b['recall_iou50'])} | {f3(b['mean_iou'])} | {pct(b['precision_matched'])} |")
    w.append("")
    w.append("| Classe (les 25 plus fréquentes) | Aliments | IoU moyen | Dice moyen |")
    w.append("|---|---|---|---|")
    for c in pf["by_class_top25"]:
        w.append(f"| {c['category']} | {c['foods']} | {f3(c['mean_iou'])} | {f3(c['mean_dice'])} |")
    w.append("")
    if "latency" in metrics:
        lat = metrics["latency"]
        w.append(f"## Latence sur {lat['device']}")
        w.append(f"Médiane {f3(lat['p50_ms'])} ms, p95 {f3(lat['p95_ms'])} ms sur {lat['n']} prédictions. {lat['note']}.")
        w.append("")
    for title, body in extra.items():
        w.append(f"## {title}")
        w.append(body)
        w.append("")
    w.append("## À garder en tête")
    w.append("- Photos suisses annotées par des humains : ni l'éclairage ni les assiettes du Québec. La précision réelle sur l'iPhone se mesure sur les repas pesés de l'utilisateur (chantier 22.6).")
    w.append("- Le seuil d'exploitation et l'appariement (IoU >= 0,1, un pour un, sans tenir compte de la classe) sont fixés d'avance ; ils ne sont pas réglés sur le test.")
    text = "\n".join(w) + "\n"
    path.write_text(text, encoding="utf-8")
    return text


if __name__ == "__main__":
    import argparse

    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--checkpoint", required=True)
    ap.add_argument("--test-dir", required=True)
    ap.add_argument("--size", default="nano")
    ap.add_argument("--out", required=True)
    ap.add_argument("--limit", type=int, default=0)
    ap.add_argument("--op-threshold", type=float, default=0.30)
    args = ap.parse_args()
    m = evaluate_checkpoint(Path(args.checkpoint), Path(args.test_dir), op_threshold=args.op_threshold, limit=args.limit)
    Path(args.out).mkdir(parents=True, exist_ok=True)
    (Path(args.out) / f"segmenter-{args.size}.json").write_text(json.dumps(m, ensure_ascii=False, indent=2, default=lambda o: None) + "\n", encoding="utf-8")
    print(write_report(Path(args.out) / f"segmenter-{args.size}.md", args.size, m, {}))
