"""Étape 2 : vecteurs DINOv2 ViT-S/14 (gelé) de tous les recadrages, sur CPU, avec cache et reprise.

Chaque recadrage (224 x 224, voir prepare_myfoodrepo.py) passe dans `FeatureNet` de ml_common.py (normalisation ImageNet
dans le graphe, DINOv2 officiel de Meta, agrégation CLS + moyenne des patchs = 768 nombres). Les vecteurs sont écrits par
lots (« shards ») : on peut interrompre (Ctrl+C, veille, coupure) et relancer la même commande, seuls les lots manquants
sont recalculés. Les lots sont rangés dans un dossier qui porte l'empreinte de crops.csv, l'agrégation et la taille des lots : changer
le découpage, l'agrégation ou la taille des lots ne réutilise JAMAIS d'anciens vecteurs.

    python extract_features.py --dataset fake
    python extract_features.py --dataset myfoodrepo            # ~ plusieurs heures sur CPU : voir README.md
    python extract_features.py --dataset fake --bench 256      # mesure du débit seulement, ne touche pas au cache

Le débit mesuré est écrit dans features/throughput.json avec l'estimation du temps pour 100 000 recadrages.
"""
from __future__ import annotations

import argparse
import hashlib
import os
import sys
import time
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime
from pathlib import Path

import numpy as np
from PIL import Image

from ml_common import (HUB_COMMIT, HUB_MODEL, HUB_WEIGHTS_SHA256, IMAGE_SIZE, POOLS, fail, file_sha256, load_dinov2_backbone, log,
                       make_feature_net, ml_root, read_csv, read_json, setup_torch_home, work_dir, write_json)


def load_pixels(path: Path) -> np.ndarray:
    with Image.open(path) as im:
        im = im.convert("RGB")
        if im.size != (IMAGE_SIZE, IMAGE_SIZE):
            im = im.resize((IMAGE_SIZE, IMAGE_SIZE), Image.BICUBIC)
        return np.asarray(im, dtype=np.uint8)   # H x W x 3


def to_batch(arrays: list[np.ndarray]):
    import torch

    return torch.from_numpy(np.stack(arrays)).permute(0, 3, 1, 2).contiguous().float()   # 0..255, NCHW


def sha_of_file(path: Path) -> str:
    h = hashlib.sha256()
    with open(path, "rb") as f:
        while block := f.read(1 << 20):
            h.update(block)
    return h.hexdigest()


def run_batches(net, paths: list[Path], batch: int, pool: ThreadPoolExecutor, device: str = "cpu", amp: bool = False):
    """Générateur de vecteurs par lot, le décodage JPEG du lot suivant se fait pendant le calcul du lot courant.

    `device` / `amp` (défauts : CPU, fp32 = comportement d'origine) : sur GPU, le lot part sur le GPU et les vecteurs reviennent en
    float32 ; `amp` calcule en demi-précision (autocast fp16), un peu plus rapide mais numériquement différent : à ne pas
    mélanger avec des vecteurs calculés en fp32.
    """
    import torch

    chunks = [paths[i:i + batch] for i in range(0, len(paths), batch)]
    pending = pool.map(load_pixels, chunks[0]) if chunks else None
    on_gpu = device != "cpu"
    for n, chunk in enumerate(chunks):
        arrays = list(pending)
        pending = pool.map(load_pixels, chunks[n + 1]) if n + 1 < len(chunks) else None
        with torch.inference_mode():
            x = to_batch(arrays)
            if on_gpu:
                x = x.to(device, non_blocking=True)
            if amp and on_gpu:
                with torch.autocast(device_type="cuda", dtype=torch.float16):
                    out = net(x)
            else:
                out = net(x)
            yield out.float().cpu().numpy()


def benchmark(net, paths: list[Path], n: int, batch: int, workers: int, threads_list: list[int], device: str = "cpu") -> dict:
    import torch

    cycled = [paths[i % len(paths)] for i in range(n)]
    results = {}
    with ThreadPoolExecutor(max_workers=workers) as pool:
        for threads in threads_list:
            torch.set_num_threads(threads)
            warm = to_batch([load_pixels(p) for p in cycled[:batch]])
            if device != "cpu":
                warm = warm.to(device)
            with torch.inference_mode():
                net(warm)                                  # échauffement (non compté)
                if device != "cpu":
                    torch.cuda.synchronize()
                t0 = time.perf_counter()
                reps = max(2, n // batch // 2)
                for _ in range(reps):
                    net(warm)
                if device != "cpu":
                    torch.cuda.synchronize()
                model_only = reps * len(warm) / (time.perf_counter() - t0)
            t0 = time.perf_counter()
            count = sum(len(v) for v in run_batches(net, cycled, batch, pool, device))
            full = count / (time.perf_counter() - t0)
            results[str(threads)] = {"model_only_img_per_s": round(model_only, 2), "pipeline_img_per_s": round(full, 2)}
            log(f"  {threads} threads torch : modèle seul {model_only:.1f} img/s ; chaîne complète (décodage inclus) {full:.1f} img/s")
    return results


def main() -> None:
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--root")
    ap.add_argument("--dataset", default="myfoodrepo")
    ap.add_argument("--splits", nargs="+", default=["train", "val", "test"])
    ap.add_argument("--pool", choices=sorted(POOLS), default="cls_mean", help="agrégation : CLS + moyenne des patchs (768) ou CLS seul (384)")
    ap.add_argument("--batch", type=int, default=32)
    ap.add_argument("--threads", type=int, default=0, help="threads de calcul de torch (défaut : coeurs physiques estimés)")
    ap.add_argument("--workers", type=int, default=3, help="threads de décodage JPEG")
    ap.add_argument("--shard", type=int, default=2048, help="recadrages par lot enregistré")
    ap.add_argument("--limit", type=int, default=0, help="n'extraire que les N premiers recadrages de chaque jeu (essais)")
    ap.add_argument("--bench", type=int, default=0, help="mesurer le débit sur N recadrages (sans écrire de vecteurs)")
    ap.add_argument("--bench-threads", default="", help="liste de nombres de threads à comparer, ex. 4,8")
    ap.add_argument("--device", default="cpu", help="cpu (défaut), cuda ou auto (cuda s'il existe) : sur GPU, fp32 sauf --amp")
    ap.add_argument("--amp", action="store_true", help="GPU seulement : calcul en demi-précision (autocast fp16). Numériquement différent du fp32.")
    ap.add_argument("--backbone-weights", help="state_dict d'un DINOv2 AFFINÉ (finetune_dinov2.py) à charger à la place des poids officiels")
    args = ap.parse_args()

    root = ml_root(args.root)
    setup_torch_home(root)
    import torch

    out = work_dir(root, args.dataset)
    crops_csv = out / "crops.csv"
    if not crops_csv.exists():
        fail(f"{crops_csv} est absent : lancer d'abord prepare_myfoodrepo.py --dataset {args.dataset}")
    rows = read_csv(crops_csv)
    threads = args.threads or max(1, (os.cpu_count() or 2) // 2)
    torch.set_num_threads(threads)

    log(f"== Extraction DINOv2-S/14 ({args.pool}) du jeu « {args.dataset} » : {len(rows)} recadrages, {threads} threads torch")
    t0 = time.time()
    device = args.device
    if device == "auto":
        device = "cuda" if torch.cuda.is_available() else "cpu"
    if device != "cpu" and not torch.cuda.is_available():
        fail(f"--device {device} demandé mais CUDA est indisponible")
    ft_weights = Path(args.backbone_weights) if args.backbone_weights else None
    if ft_weights is not None and not ft_weights.exists():
        fail(f"{ft_weights} est introuvable (--backbone-weights)")
    net = make_feature_net(load_dinov2_backbone(root, weights_path=ft_weights), args.pool)
    if device != "cpu":
        net = net.to(device).eval()
    ft_sha = file_sha256(ft_weights) if ft_weights is not None else None
    log(f"  modèle chargé en {time.time() - t0:.1f} s ; appareil {device}{' (autocast fp16)' if args.amp and device != 'cpu' else ''}"
        + (f" ; DINOv2 AFFINÉ ({ft_weights.name}, sha256 {ft_sha[:12]})" if ft_sha else ""))

    if args.bench:
        paths = [out / r["crop"] for r in rows]
        thread_list = [int(t) for t in args.bench_threads.split(",") if t] or [threads]
        res = benchmark(net, paths, args.bench, args.batch, args.workers, thread_list, device)
        best = max(r["pipeline_img_per_s"] for r in res.values())
        log(f"  estimation pour 100 000 recadrages au meilleur débit : {100000 / best / 3600:.1f} h")
        write_json(out / "bench.json", {"measured_at": datetime.now().isoformat(timespec="seconds"), "n": args.bench, "batch": args.batch,
                                        "results": res, "estimate_100k_hours": round(100000 / best / 3600, 2)})
        return

    crops_sha = sha_of_file(crops_csv)[:12]
    feat_dir = out / "features"
    shard_name = f"shards-{crops_sha}-{args.pool}-{args.shard}" + (f"-ft{ft_sha[:8]}" if ft_sha else "") \
        + ("-amp" if args.amp and device != "cpu" else "")
    shard_dir = feat_dir / shard_name
    shard_dir.mkdir(parents=True, exist_ok=True)
    dim = POOLS[args.pool]
    totals = {"images": 0, "seconds": 0.0}
    split_info = {}
    with ThreadPoolExecutor(max_workers=args.workers) as pool:
        for split in args.splits:
            split_rows = [r for r in rows if r["split"] == split]
            if args.limit:
                split_rows = split_rows[:args.limit]
            if not split_rows:
                log(f"  {split} : aucun recadrage")
                continue
            paths = [out / r["crop"] for r in split_rows]
            n_shards = (len(paths) + args.shard - 1) // args.shard
            computed = 0
            t_split = time.perf_counter()
            for s in range(n_shards):
                part = paths[s * args.shard:(s + 1) * args.shard]
                shard_file = shard_dir / f"{split}-{s:05d}.npy"
                if shard_file.exists():
                    cached = np.load(shard_file, mmap_mode="r")
                    if cached.shape == (len(part), dim):
                        continue                        # lot déjà calculé : reprise
                t_shard = time.perf_counter()
                vectors = np.concatenate(list(run_batches(net, part, args.batch, pool, device, args.amp)), axis=0).astype(np.float32)
                tmp = shard_file.with_suffix(".tmp.npy")
                np.save(tmp, vectors)
                os.replace(tmp, shard_file)             # écriture atomique : un lot est entier ou absent
                computed += len(part)
                rate = len(part) / (time.perf_counter() - t_shard)
                log(f"  {split} lot {s + 1}/{n_shards} : {len(part)} recadrages, {rate:.1f} img/s")
            elapsed = time.perf_counter() - t_split
            totals["images"] += computed
            totals["seconds"] += elapsed if computed else 0.0
            X = np.concatenate([np.load(shard_dir / f"{split}-{s:05d}.npy") for s in range(n_shards)], axis=0)
            y = np.array([int(r["class_index"]) for r in split_rows], dtype=np.int32)
            ann = np.array([int(r["ann_id"]) for r in split_rows], dtype=np.int64)
            if len(X) != len(y):
                fail(f"{split} : {len(X)} vecteurs pour {len(y)} recadrages")
            np.save(feat_dir / f"{split}.X.npy", X)
            np.save(feat_dir / f"{split}.y.npy", y)
            np.save(feat_dir / f"{split}.ann_id.npy", ann)
            split_info[split] = {"n": int(len(y)), "computed_now": computed}
            log(f"  {split} : {len(y)} vecteurs ({computed} calculés maintenant) -> {feat_dir / (split + '.X.npy')}")

    throughput = None
    if totals["images"]:
        ips = totals["images"] / totals["seconds"]
        throughput = {"images_per_second": round(ips, 2), "estimate_hours_for_100k": round(100000 / ips / 3600, 2),
                      "measured_on": f"{os.cpu_count()} threads logiques, torch {torch.__version__}, {threads} threads de calcul, lot {args.batch}",
                      "images_timed": totals["images"]}
        write_json(feat_dir / "throughput.json", throughput)
        log(f"Débit mesuré : {ips:.1f} img/s ; 100 000 recadrages = {100000 / ips / 3600:.1f} h")
    write_json(feat_dir / "meta.json", {
        "backbone": {"hub": f"facebookresearch/dinov2@{HUB_COMMIT}", "model": HUB_MODEL, "weights_sha256": HUB_WEIGHTS_SHA256,
                     "license": "Apache 2.0"},
        "pool": args.pool, "dim": dim, "image_size": IMAGE_SIZE, "normalization": "ImageNet (dans le graphe, entrée 0..255)",
        "crops_csv_sha256_12": crops_sha, "splits": split_info, "limit": args.limit or None,
        "torch": torch.__version__, "extracted_at": datetime.now().isoformat(timespec="seconds"),
        "device": device, "amp": bool(args.amp and device != "cpu"),
        **({"finetuned": {"file": ft_weights.name, "sha256": ft_sha,
                          "description": "derniers blocs affinés par finetune_dinov2.py ; gelé pour l'extraction"}} if ft_sha else {}),
    })
    log("Terminé.")


if __name__ == "__main__":
    main()
