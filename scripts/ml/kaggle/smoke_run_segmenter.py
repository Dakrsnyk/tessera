"""Essai de fumée LOCAL des modules du segmenteur (CPU, jeu FACTICE, quelques images) : prouve que le code appelle correctement `rfdetr`.

Enchaîne exactement les fonctions que le carnet `segmenter/ardane-segmenter.ipynb` appelle :
  prepare_myfoodrepo.py --no-crops  ->  seg_dataset.build_rfdetr_dataset  ->  seg_train.measure_throughput (mesure du débit)  ->
  seg_train.train (1 époque, arrêt par budget, puis REPRISE depuis last.ckpt)  ->  seg_eval.evaluate_checkpoint  ->  seg_export.export_all
Ne prouve PAS la qualité du modèle (quelques images de formes colorées) ni la vitesse sur GPU.

Prérequis (Linux ou WSL) : torch, `rfdetr[train]==1.11.2`, coremltools 9 ; ex. venv /root/ardane-ml/venv-seg.
    python smoke_run_segmenter.py --work <dossier d'essai>
"""
from __future__ import annotations

import argparse
import json
import os
import shutil
import subprocess
import sys
import time
from pathlib import Path

HERE = Path(__file__).resolve().parent
ML = HERE.parent
sys.path[:0] = [str(HERE), str(HERE / "segmenter"), str(ML)]


NOTEBOOK = HERE / "segmenter" / "ardane-segmenter.ipynb"
NOTEBOOK_OVERRIDES = {   # appliqués juste après la cellule de réglages du carnet
    "SIZES": [os.environ.get("ARDANE_SMOKE_SIZE", "nano")], "EPOCHS_MAX": 2, "MIN_EPOCHS": 1, "BATCH": {"nano": 2, "small": 2}, "VALID_MAX": 6, "BENCH_TRAIN": 8, "BENCH_VALID": 4,
    "LIMITS": {"train": 16, "valid": 6, "test": 6}, "TRAIN_WORKERS": 0, "EVAL_EXPORT_RESERVE_S": 120,
}


def run_notebook(work: Path) -> None:
    """Exécute les cellules de code du .ipynb du segmenteur (même mécanique que smoke_run_classifier.py)."""
    sys.path.insert(0, str(HERE))
    from smoke_run_classifier import build_fake_input

    build_fake_input(work, 96, 36)
    os.environ["ARDANE_KAGGLE_SMOKE"] = str(work)
    notebook = json.loads(NOTEBOOK.read_text(encoding="utf-8"))
    cells = [c for c in notebook["cells"] if c["cell_type"] == "code"]
    namespace: dict = {"__name__": "__main__"}
    t_all = time.time()
    for index, cell in enumerate(cells):
        print(f"\n########## cellule {index + 1}/{len(cells)} ({cell['id']}) ##########", flush=True)
        t = time.time()
        exec(compile("".join(cell["source"]), f"<{cell['id']}>", "exec"), namespace)
        if index == 0:
            namespace.update(NOTEBOOK_OVERRIDES)
        print(f"----- cellule {index + 1} : {time.time() - t:.1f} s", flush=True)
    out = namespace["ENV"].out
    print(f"\n=== Carnet exécuté en {time.time() - t_all:.0f} s ===")
    missing = [r for r in ("RESULTS-segmenter.md", "segmenter-nano.md", "models/segmenter-nano", "ardane_state/stages.json") if not (out / r).exists()]
    assert not missing, f"sorties manquantes : {missing}"
    print("étapes :", {k: v.get("done") for k, v in json.loads((out / "ardane_state" / "stages.json").read_text(encoding="utf-8"))["stages"].items()})
    print("OK : le carnet du segmenteur tourne de bout en bout sur le jeu factice (CPU).")


def main() -> None:
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--work", required=True)
    ap.add_argument("--train-images", type=int, default=24)
    ap.add_argument("--val-images", type=int, default=10)
    ap.add_argument("--size", default="nano")
    ap.add_argument("--skip-export", action="store_true")
    ap.add_argument("--notebook", action="store_true", help="exécuter les cellules du .ipynb au lieu d'appeler les fonctions une à une")
    args = ap.parse_args()
    work = Path(args.work)
    shutil.rmtree(work, ignore_errors=True)
    work.mkdir(parents=True)
    if args.notebook:
        os.environ.setdefault("RF_HOME", str(work / "rf_home"))
        run_notebook(work)
        return
    os.environ["ARDANE_ML_ROOT"] = str(work / "ml")
    os.environ.setdefault("RF_HOME", str(work / "rf_home"))
    py = sys.executable

    import kaggle_common as kc
    import seg_dataset, seg_eval, seg_export, seg_metrics, seg_train

    seg_metrics.selftest()
    t = time.time()
    subprocess.run([py, "-B", str(ML / "make_fake_coco.py"), "--root", str(work / "fake_source"), "--train-images", str(args.train_images),
                    "--val-images", str(args.val_images)], check=True, cwd=ML)
    coco = work / "fake_source" / "fake" / "coco"
    subprocess.run([py, "-B", str(ML / "prepare_myfoodrepo.py"), "--root", str(work / "ml"), "--dataset", "fake", "--no-crops", "--skip-class-map",
                    "--train-json", str(coco / "train" / "annotations.json"), "--train-images", str(coco / "train" / "images"),
                    "--val-json", str(coco / "val" / "annotations.json"), "--val-images", str(coco / "val" / "images")], check=True, cwd=ML)
    crops_csv = work / "ml" / "work" / "fake" / "crops.csv"
    common = dict(crops_csv=crops_csv, train_json=coco / "train" / "annotations.json", train_images=coco / "train" / "images",
                  val_json=coco / "val" / "annotations.json", val_images=coco / "val" / "images")
    stats = seg_dataset.build_rfdetr_dataset(**common, out_dir=work / "seg_data" / "full", valid_max=6, limit_train=16, limit_valid=6, limit_test=6)
    bench_stats = seg_dataset.build_rfdetr_dataset(**common, out_dir=work / "seg_data" / "bench", valid_max=4, limit_train=8, limit_valid=4, limit_test=1)
    print("jeu RF-DETR :", json.dumps({k: v for k, v in stats.items() if k != "out_dir"}, ensure_ascii=False))
    print(f"[préparation] {time.time() - t:.0f} s")

    ds, run = work / "seg_data" / "full", work / "ml" / "seg" / args.size / "run"
    t = time.time()
    bench = seg_train.measure_throughput(args.size, work / "seg_data" / "bench", work / "ml" / "seg" / args.size / "bench_run", n_train=8, n_valid=4,
                                         full_train=stats["train"]["images"], full_valid=stats["valid"]["images"], batch_size=2, num_workers=0,
                                         device="cpu")
    print("débit mesuré :", json.dumps(bench, ensure_ascii=False), f"({time.time() - t:.0f} s)")
    assert bench["epoch_seconds_estimate"] > 0

    # Budget : on demande l'arrêt après la 1re époque d'un entraînement de 2 époques, puis on REPREND depuis last.ckpt
    t = time.time()
    calls = []
    first = seg_train.train(args.size, ds, run, epochs=2, batch_size=2, num_workers=0, device="cpu",
                            can_continue=lambda seconds: calls.append(seconds) or False, persist_fn=lambda: calls.append("persist"))
    assert first["paused"], "le budget aurait dû arrêter l'entraînement après l'époque 1"
    assert (run / "last.ckpt").exists(), "last.ckpt absent après l'arrêt par budget"
    print(f"[entraînement] pause après l'époque 1 : OK ({time.time() - t:.0f} s) ; appels du budget : {calls}")
    t = time.time()
    second = seg_train.train(args.size, ds, run, epochs=2, batch_size=2, num_workers=0, device="cpu", resume=run / "last.ckpt")
    assert not second["paused"] and len(second["epoch_seconds"]) == 1, f"la reprise devait faire exactement 1 époque : {second['epoch_seconds']}"
    print(f"[entraînement] reprise depuis last.ckpt : OK, 1 époque ({time.time() - t:.0f} s)")
    checkpoint = next((run / n for n in ("checkpoint_best_total.pth", "checkpoint_best_ema.pth", "checkpoint_best_regular.pth", "last.ckpt") if (run / n).exists()))
    print("fichiers du point de contrôle :", sorted(p.name for p in run.iterdir()))

    t = time.time()
    metrics = seg_eval.evaluate_checkpoint(checkpoint, ds / "test", op_threshold=0.3, ap_threshold=0.01, with_latency=True)
    text = seg_eval.write_report(work / "segmenter-test.md", args.size, metrics, {"Exports": "(essai)"}, fake=True)
    print(f"[évaluation] {time.time() - t:.0f} s ; mAP masque {metrics['segm']['AP']} ; IoU/aliment {metrics['per_food']['mean_iou']} ; "
          f"{metrics['detections']} détections (JEU FACTICE, sans signification)")

    if not args.skip_export:
        t = time.time()
        result = seg_export.export_all(checkpoint, work / "export", ("onnx", "coreml"), ("float16",))
        print(seg_export.render_markdown(result))
        print(f"[export] {time.time() - t:.0f} s")
    print("OK : les modules du segmenteur tournent de bout en bout sur le jeu factice (CPU).")


if __name__ == "__main__":
    main()
