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
        try:
            with Image.open(folder / "rgb.png") as im:
                image = im.convert("RGB")
            raw = np.asarray(Image.open(folder / "depth_raw.png"), dtype=np.float32)
        except Exception as e:                       # fichier tronqué ou absent à la source : plat ignoré
            print(f"{dish} ignoré : {e}", flush=True)
            continue
        # unité : 1e-4 m (article) pour presque tous les plats (valeurs ~3 500), mm pour quelques-uns (~350) ; vérifié le 2026-11-04
        depth_mm = raw / 10.0 if np.median(raw[raw > 0]) > 1500 else raw
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
        np.savez_compressed(dest, zones=np.asarray(rows, dtype=np.float32).reshape(-1, 4), emb=emb, plate_mm=np.float32(plate_mm),
                            units_ok=np.int8(1))
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


def zone_features(d: dict, column: int, norm: dict) -> np.ndarray:
    """Entrée du modèle pour chaque zone d'un plat : empreinte normalisée, log de la mesure de la zone, et le contexte du plat
    (log de la mesure totale, log du nombre de zones, part de la zone, confiance du segmenteur). Calculable tel quel dans l'app."""
    z = d["zones"]
    total = max(float(z[:, column].sum()), 1e-3)
    rows = []
    for e, zz in zip(d["emb"], z):
        rows.append(np.concatenate([(e - norm["mean"]) / norm["std"],
                                    [(np.log(max(zz[column], 1e-3)) - norm["lm_mean"]) / norm["lm_std"],
                                     (np.log(total) - norm["lm_mean"]) / norm["lm_std"], np.log(len(z)), zz[column] / total, zz[3]]]))
    return np.array(rows, dtype=np.float32).reshape(-1, len(norm["mean"]) + 5)    # plat sans zone : (0, D)


def fit_density(train, val, column: int, use_emb: bool, seeds: int = 5, hidden: int = 256, dropout: float = 0.3,
                weight_decay: float = 0.05, lr: float = 1e-3, max_epochs: int = 1500, patience: int = 60):
    """log densité de chaque zone = MLP(zone_features) (ou constante) ; grammes du plat = somme(mesure_zone x densité).
    Perte de Huber sur le log (robuste aux plats aberrants), arrêt sur la validation, moyenne géométrique de `seeds` modèles.
    Réglages choisis le 2026-11-04 sur la VALIDATION seule (balayage de 5 réglages x 5 graines) : 74,9 % à ±25 % en validation."""
    import torch
    from torch import nn

    train = [d for d in train if len(d["zones"])]
    val = [d for d in val if len(d["zones"])]
    emb = np.concatenate([d["emb"] for d in train])
    logm = np.log(np.maximum(np.concatenate([d["zones"][:, column] for d in train]), 1e-3))
    norm = {"mean": emb.mean(0), "std": emb.std(0) + 1e-6, "lm_mean": float(logm.mean()), "lm_std": float(logm.std() + 1e-6)}
    ratios = [d["mass"] / d["zones"][:, column].sum() for d in train if d["zones"][:, column].sum() > 0]
    base = float(np.log(np.median(ratios)))

    def tensors(items):
        F, M, I = [], [], []
        for i, d in enumerate(items):
            F.append(zone_features(d, column, norm))
            M += [max(float(v), 0.0) for v in d["zones"][:, column]]
            I += [i] * len(d["zones"])
        return (torch.tensor(np.concatenate(F)), torch.tensor(M, dtype=torch.float32), torch.tensor(I, dtype=torch.long),
                torch.tensor([d["mass"] for d in items], dtype=torch.float32))

    def run(nets, items):
        if not items:
            return np.zeros(0)
        F, M, I, _ = tensors(items)
        logs = []
        with torch.no_grad():
            for net in nets or [None]:
                logd = base + (net(F).squeeze(1) if net is not None else torch.zeros(len(M)))
                logs.append(torch.log(torch.zeros(len(items)).index_add_(0, I, M * torch.exp(logd)) + 1e-6))
        return torch.exp(torch.stack(logs).mean(0)).numpy()

    info = {"base_density": float(np.exp(base)), "norm": norm, "base": base, "column": column}
    if not use_emb:
        return (lambda items: run([], items)), info
    Ft, Mt, It, Yt = tensors(train)
    Fv, Mv, Iv, Yv = tensors(val)
    nets, best_vals = [], []
    for seed in range(seeds):
        torch.manual_seed(seed)
        net = nn.Sequential(nn.Linear(Ft.shape[1], hidden), nn.GELU(), nn.Dropout(dropout), nn.Linear(hidden, 1))
        nn.init.zeros_(net[-1].weight)
        nn.init.zeros_(net[-1].bias)
        opt = torch.optim.AdamW(net.parameters(), lr=lr, weight_decay=weight_decay)
        best, state, waited = float("inf"), None, 0
        for _ in range(max_epochs):
            net.train()
            pred = torch.zeros(len(Yt)).index_add_(0, It, Mt * torch.exp(base + net(Ft).squeeze(1)))
            loss = nn.functional.huber_loss(torch.log(pred + 1.0), torch.log(Yt), delta=0.3)
            opt.zero_grad()
            loss.backward()
            opt.step()
            net.eval()
            with torch.no_grad():
                pv = torch.zeros(len(Yv)).index_add_(0, Iv, Mv * torch.exp(base + net(Fv).squeeze(1)))
                v = float(torch.mean((torch.log(pv + 1.0) - torch.log(Yv)) ** 2))
            if v < best - 1e-5:
                best, state, waited = v, {k: x.clone() for k, x in net.state_dict().items()}, 0
            else:
                waited += 1
                if waited > patience:
                    break
        net.load_state_dict(state)
        net.eval()
        nets.append(net)
        best_vals.append(best)
    info.update({"nets": nets, "best_val_logmse": float(np.mean(best_vals)), "seeds": seeds, "hidden": hidden})
    return (lambda items: run(nets, items)), info


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
    ok_vol = lambda items: [d for d in items if len(d["zones"]) and np.isfinite(d["zones"][:, 2]).all()]  # noqa: E731
    for name, column, use_emb in (("M0_surface_constante", 1, False), ("M1_surface_x_densite_apprise", 1, True),
                                  ("M2_volume_profondeur_x_densite_apprise", 2, True), ("M2b_volume_constante", 2, False)):
        tr, va, te = (train, val, test) if column == 1 else (ok_vol(train), ok_vol(val), ok_vol(test))
        if not tr or not te:
            continue
        predict, info = fit_density(tr, va, column, use_emb)
        results[name] = {**evaluate(predict(te), np.array([d["mass"] for d in te])),
                         **{k: v for k, v in info.items() if isinstance(v, (int, float))}}
        if name.startswith("M1") and "nets" in info:
            import torch
            torch.save({"format": "ardane-grams-head-v2", "state_dicts": [n.state_dict() for n in info["nets"]], "norm": info["norm"],
                        "base_log_density": info["base"], "hidden": info["hidden"], "unit": "g/cm2", "pool": "cls_mean",
                        "features": "empreinte normalisée + [log surface zone, log surface plat, log nb zones, part, confiance] (zone_features)"},
                       out.with_suffix(".M1.pt"))
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
