"""Banc de mesure des QUANTITÉS (chantier 22.4, critère « quantités » de l'objectif 80 % : grammes justes à ±25 %).

Données : Nutrition5k (Google, CC BY 4.0), vue de dessus (rgb.png + depth_raw.png, 640 x 480), poids total de chaque plat PESÉ.
Caméra à 35,9 cm du plan de prise de vue, surface d'un pixel à cette distance 5,957e-3 cm² (article CVPR 2021, § 4) ; depth_raw en mm
(valeurs ~ 350-420 : 35-42 cm). L'échelle est donc CONNUE ici : ce banc mesure la partie « surface -> grammes ». Dans l'app, l'échelle vient
de l'assiette (diamètre confirmé) ; son erreur s'ajoute et ne se mesure que sur des repas pesés pris au téléphone.

Méthodes comparées (mêmes zones : notre segmenteur RF-DETR-Seg, seuil 0,30, doublons fusionnés, chaque pixel à une seule zone) :
  M0  grammes = surface totale x densité surfacique constante (médiane de l'entraînement)                       [référence naïve]
  M1  grammes = somme des zones de surface x densité surfacique apprise de l'empreinte DINOv2 de la zone        [voie de l'app, sans LiDAR]
  M2  grammes = somme des zones de volume (profondeur) x densité apprise de l'empreinte                        [voie LiDAR, iPhone Pro]
Apprentissage sur les plats « train » officiels (15 % gardés pour l'arrêt), mesure UNE fois sur les plats « test » officiels.

    # WSL, venv du segmenteur (rfdetr + torch) :
    python grams_n5k.py zones --n5k <ML>/raw/nutrition5k --segmenter <...>.pth --backbone-weights <...>.pt --torch-root <ML> --out <ML>/work/n5k
    python grams_n5k.py fit --n5k <ML>/raw/nutrition5k --zones <ML>/work/n5k --out <ML>/reports/grams-n5k-<date>
"""
from __future__ import annotations

import argparse
import csv
import hashlib
import json
import sys
import time
from pathlib import Path

import numpy as np

SCRIPT_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(SCRIPT_DIR))
sys.path.insert(0, str(SCRIPT_DIR / "kaggle" / "segmenter"))

PIXEL_AREA_CM2 = 5.957e-3        # à 35,9 cm (article Nutrition5k)
CAMERA_CM = 35.9
MAX_HEIGHT_CM = 12.0             # au-delà : bruit de profondeur, bord de bol
TOLERANCE = 0.25                 # critère de l'utilisateur (2026-11-04) : juste à ±25 % du poids réel


# --------------------------------------------------------------------------- 1. zones

def zones(args) -> None:
    import torch
    import rfdetr
    from PIL import Image

    from ml_common import IMAGE_SIZE, crop_square, load_dinov2_backbone, make_feature_net
    from pipeline_eval import dedupe, mask_bbox

    out = Path(args.out)
    out.mkdir(parents=True, exist_ok=True)
    seg = rfdetr.from_checkpoint(args.segmenter)
    feat = make_feature_net(load_dinov2_backbone(Path(args.torch_root), weights_path=args.backbone_weights), "cls_mean").eval()
    dishes = sorted(p.name for p in (Path(args.n5k) / "overhead").iterdir()
                    if (p / "rgb.png").exists() and (p / "depth_raw.png").exists())
    if args.limit:
        dishes = dishes[:args.limit]
    t0 = time.time()
    for n, dish in enumerate(dishes):
        dest = out / f"{dish}.npz"
        if dest.exists():
            continue
        folder = Path(args.n5k) / "overhead" / dish
        with Image.open(folder / "rgb.png") as im:
            image = im.convert("RGB")
        depth_mm = np.asarray(Image.open(folder / "depth_raw.png"), dtype=np.float32)
        w, h = image.size
        det = seg.predict(str(folder / "rgb.png"), threshold=args.threshold)
        masks = det.mask if det.mask is not None else np.zeros((0, h, w), dtype=bool)
        if len(masks) and masks.shape[1:] != (h, w):
            masks = np.stack([np.asarray(Image.fromarray(m.astype(np.uint8) * 255).resize((w, h), Image.NEAREST)) > 0 for m in masks])
        scores = np.asarray(det.confidence if det.confidence is not None else np.zeros(len(masks)), dtype=float)
        if len(masks):
            keep = dedupe(masks, scores, [tuple(float(v) for v in det.xyxy[k]) for k in range(len(masks))])
            masks, scores = masks[keep], scores[keep]
        # chaque pixel à la zone la plus sûre (pas de double comptage de surface)
        owner = np.full((h, w), -1, dtype=np.int32)
        for k in np.argsort(-scores):
            owner[(owner < 0) & masks[k]] = k
        food = owner >= 0
        valid = depth_mm > 0
        around = valid & ~food
        # plan de l'assiette : profondeur médiane des pixels non-aliment autour des aliments (boîte agrandie)
        plate_mm = float("nan")
        if food.any():
            ys, xs = np.where(food)
            y0, y1 = max(0, ys.min() - 40), min(h, ys.max() + 41)
            x0, x1 = max(0, xs.min() - 40), min(w, xs.max() + 41)
            ring = around[y0:y1, x0:x1]
            if ring.sum() > 200:
                plate_mm = float(np.median(depth_mm[y0:y1, x0:x1][ring]))
        rows, crops = [], []
        for k in range(len(masks)):
            region = owner == k
            px = int(region.sum())
            if px < 50:
                continue
            box = mask_bbox(region)
            if box is None:
                continue
            area = px * PIXEL_AREA_CM2 * ((plate_mm / 10.0 / CAMERA_CM) ** 2 if np.isfinite(plate_mm) else 1.0)
            vol = 0.0
            if np.isfinite(plate_mm):
                d = depth_mm[region & valid]
                hcm = np.clip((plate_mm - d) / 10.0, 0, MAX_HEIGHT_CM)
                vol = float(np.sum(hcm * PIXEL_AREA_CM2 * (d / 10.0 / CAMERA_CM) ** 2))
            rows.append([px, area, vol, float(scores[k])])
            crops.append(np.asarray(crop_square(image, box, 0.10, IMAGE_SIZE), dtype=np.float32))
        emb = np.zeros((0, 768), dtype=np.float32)
        if crops:
            with torch.no_grad():
                emb = feat(torch.from_numpy(np.stack(crops)).permute(0, 3, 1, 2).contiguous()).numpy().astype(np.float32)
        np.savez_compressed(dest, zones=np.asarray(rows, dtype=np.float32).reshape(-1, 4), emb=emb, plate_mm=np.float32(plate_mm))
        if n % 50 == 0:
            print(f"{n}/{len(dishes)} {dish} zones={len(rows)} plaque={plate_mm:.0f} mm  {time.time() - t0:.0f} s", flush=True)


# --------------------------------------------------------------------------- 2. apprentissage et mesure

def read_masses(n5k: Path) -> dict[str, float]:
    out = {}
    for name in ("dish_metadata_cafe1.csv", "dish_metadata_cafe2.csv"):
        with (n5k / "metadata" / name).open(encoding="utf-8") as f:
            for row in csv.reader(f):
                if len(row) > 2:
                    out[row[0]] = float(row[2])
    return out


def load_split(n5k: Path, zones_dir: Path, masses: dict, name: str):
    ids = [l.strip() for l in (n5k / "splits" / name).read_text().splitlines() if l.strip()]
    data = []
    for dish in ids:
        f = zones_dir / f"{dish}.npz"
        if not f.exists() or masses.get(dish, 0) <= 1:
            continue
        z = np.load(f)
        data.append({"dish": dish, "mass": masses[dish], "zones": z["zones"], "emb": z["emb"]})
    return data


def evaluate(pred: np.ndarray, truth: np.ndarray) -> dict:
    rel = np.abs(pred - truth) / truth
    return {"n": int(len(truth)), "mae_g": float(np.mean(np.abs(pred - truth))), "mae_pct": float(100 * np.mean(np.abs(pred - truth)) / np.mean(truth)),
            "median_rel_pct": float(100 * np.median(rel)), "within_25_pct": float(100 * np.mean(rel <= TOLERANCE)),
            "within_10_pct": float(100 * np.mean(rel <= 0.10)), "no_zone": int(np.sum(pred <= 0))}


def fit_density(train, val, column: int, use_emb: bool, epochs: int = 400, seed: int = 0):
    """log densité de chaque zone = MLP(empreinte) (ou constante) ; grammes du plat = somme(mesure_zone x densité). Perte : écart des log."""
    import torch
    from torch import nn

    torch.manual_seed(seed)
    dim = train[0]["emb"].shape[1] if train[0]["emb"].size else 768
    mean = np.concatenate([d["emb"] for d in train if len(d["emb"])]).mean(0)
    std = np.concatenate([d["emb"] for d in train if len(d["emb"])]).std(0) + 1e-6
    ratios = [d["mass"] / max(1e-6, d["zones"][:, column].sum()) for d in train if len(d["zones"]) and d["zones"][:, column].sum() > 0]
    base = float(np.log(np.median(ratios)))
    logm = np.log(np.maximum(np.concatenate([d["zones"][:, column] for d in train if len(d["zones"])]), 1e-3))
    lm_mean, lm_std = float(logm.mean()), float(logm.std() + 1e-6)
    # entrée : empreinte normalisée + log de la mesure de la zone (un gros tas est aussi plus épais)
    net = nn.Sequential(nn.Linear(dim + 1, 128), nn.GELU(), nn.Dropout(0.2), nn.Linear(128, 1)) if use_emb else None
    if net is not None:
        nn.init.zeros_(net[-1].weight)
        nn.init.zeros_(net[-1].bias)

    def batch(items):
        E, M, I, Y = [], [], [], []
        for i, d in enumerate(items):
            for e, z in zip(d["emb"], d["zones"]):
                E.append(np.append((e - mean) / std, (np.log(max(z[column], 1e-3)) - lm_mean) / lm_std))
                M.append(max(z[column], 0.0))
                I.append(i)
            Y.append(d["mass"])
        return (torch.tensor(np.array(E), dtype=torch.float32), torch.tensor(M, dtype=torch.float32),
                torch.tensor(I, dtype=torch.long), torch.tensor(Y, dtype=torch.float32))

    def predict(items, model):
        if not items:
            return np.zeros(0)
        E, M, I, _ = batch(items)
        with torch.no_grad():
            logd = base + (model(E).squeeze(1) if model is not None else torch.zeros(len(M)))
            per = M * torch.exp(logd)
            out = torch.zeros(len(items)).index_add_(0, I, per)
        return out.numpy()

    if net is None:
        return lambda items: predict(items, None), {"base_density": float(np.exp(base))}
    opt = torch.optim.AdamW(net.parameters(), lr=1e-3, weight_decay=1e-2)
    tr = [d for d in train if len(d["zones"])]
    E, M, I, Y = batch(tr)
    best, best_state, waited = float("inf"), None, 0
    for epoch in range(epochs):
        net.train()
        logd = base + net(E).squeeze(1)
        pred = torch.zeros(len(tr)).index_add_(0, I, M * torch.exp(logd))
        loss = torch.nn.functional.huber_loss(torch.log(pred + 1.0), torch.log(Y), delta=0.3)   # robuste aux plats aberrants
        opt.zero_grad()
        loss.backward()
        opt.step()
        net.eval()
        vp = predict([d for d in val if len(d["zones"])], net)
        vy = np.array([d["mass"] for d in val if len(d["zones"])])
        vloss = float(np.mean((np.log(vp + 1.0) - np.log(vy)) ** 2))
        if vloss < best - 1e-5:
            best, best_state, waited = vloss, {k: v.clone() for k, v in net.state_dict().items()}, 0
        else:
            waited += 1
            if waited > 40:
                break
    net.load_state_dict(best_state)
    net.eval()
    return (lambda items: predict(items, net)), {"base_density": float(np.exp(base)), "best_val_logmse": best, "epochs": epoch + 1,
                                                  "net": net, "mean": mean, "std": std, "base": base, "log_measure_mean": lm_mean, "log_measure_std": lm_std}


def fit(args) -> None:
    n5k, zones_dir, out = Path(args.n5k), Path(args.zones), Path(args.out)
    out.parent.mkdir(parents=True, exist_ok=True)
    masses = read_masses(n5k)
    train_all = load_split(n5k, zones_dir, masses, "depth_train_ids.txt")
    test = load_split(n5k, zones_dir, masses, "depth_test_ids.txt")
    is_val = lambda d: int(hashlib.sha256(d["dish"].encode()).hexdigest(), 16) % 100 < 15  # noqa: E731
    train, val = [d for d in train_all if not is_val(d)], [d for d in train_all if is_val(d)]
    truth = np.array([d["mass"] for d in test])
    results = {}
    for name, column, use_emb in (("M0_surface_constante", 1, False), ("M1_surface_x_densite_apprise", 1, True),
                                  ("M2_volume_profondeur_x_densite_apprise", 2, True), ("M2b_volume_constante", 2, False)):
        predict, info = fit_density(train, val, column, use_emb)
        results[name] = {**evaluate(predict(test), truth), **{k: v for k, v in info.items() if isinstance(v, (int, float))}}
        if name.startswith("M1") and "net" in info:
            import torch
            torch.save({"format": "ardane-grams-head-v1", "state_dict": info["net"].state_dict(), "mean": info["mean"], "std": info["std"],
                        "base_log_density": info["base"], "log_area_mean": info["log_measure_mean"], "log_area_std": info["log_measure_std"],
                        "unit": "g/cm2", "pool": "cls_mean"}, out.with_suffix(".M1.pt"))
        print(name, json.dumps(results[name], ensure_ascii=False))
    summary = {"train": len(train), "val": len(val), "test": len(test), "tolerance": TOLERANCE, "results": results,
               "note": "échelle connue (caméra fixe) ; dans l'app l'échelle vient de l'assiette : erreur supplémentaire à mesurer sur repas pesés"}
    out.with_suffix(".json").write_text(json.dumps(summary, ensure_ascii=False, indent=1), encoding="utf-8")
    lines = [f"# Quantités sur Nutrition5k ({time.strftime('%Y-%m-%d')})", "",
             f"Plats : {len(train)} entraînement, {len(val)} arrêt, {len(test)} test (découpage officiel). Critère : à ±{int(TOLERANCE * 100)} % du poids pesé.",
             "Échelle connue (caméra fixe à 35,9 cm) : ce banc mesure surface/volume -> grammes, pas l'échelle par l'assiette.", "",
             "| Méthode | Plats à ±25 % | à ±10 % | Erreur moyenne | Erreur médiane | Sans zone |", "|---|---|---|---|---|---|"]
    for name, r in results.items():
        lines.append(f"| {name} | {r['within_25_pct']:.1f} % | {r['within_10_pct']:.1f} % | {r['mae_g']:.0f} g ({r['mae_pct']:.1f} %) | "
                     f"{r['median_rel_pct']:.1f} % | {r['no_zone']} |")
    lines += ["", "Repères publiés (même jeu, Thames et al. 2021) : image seule 18,8 % d'erreur moyenne sur le poids ; volume par profondeur 13,7 %."]
    out.with_suffix(".md").write_text("\n".join(lines) + "\n", encoding="utf-8")
    print("\n".join(lines))


if __name__ == "__main__":
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="cmd", required=True)
    z = sub.add_parser("zones")
    z.add_argument("--n5k", required=True)
    z.add_argument("--segmenter", required=True)
    z.add_argument("--backbone-weights", required=True)
    z.add_argument("--torch-root", required=True)
    z.add_argument("--threshold", type=float, default=0.30)
    z.add_argument("--limit", type=int, default=0)
    z.add_argument("--out", required=True)
    f = sub.add_parser("fit")
    f.add_argument("--n5k", required=True)
    f.add_argument("--zones", required=True)
    f.add_argument("--out", required=True)
    a = ap.parse_args()
    zones(a) if a.cmd == "zones" else fit(a)
