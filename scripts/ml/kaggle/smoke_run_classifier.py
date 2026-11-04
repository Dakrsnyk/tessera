"""Essai de fumée LOCAL du carnet classifieur sur le jeu FACTICE de scripts/ml (aucun GPU, aucune donnée réelle, aucun réseau Kaggle).

Exécute, dans un seul espace de noms et dans l'ordre, les MÊMES cellules de code que `classifier/ardane-classifier.ipynb` (extraites du
fichier .ipynb), avec la variable d'environnement ARDANE_KAGGLE_SMOKE qui redirige tous les chemins sous un dossier d'essai et réduit les
réglages (2 époques, 2 blocs affinés, lots de 16...). Le jeu d'entrée imite exactement la mise en page de
`awsaf49/food-recognition-2022-dataset` (public_training_set_release_2.0/{images, annotations.json}, public_validation_set_2.0/...).

    python smoke_run_classifier.py --work <dossier d'essai>            # CPU ; l'export Core ML réel demande Linux ou macOS (coremltools)
Prérequis : torch, numpy, pillow ; coremltools 9 (Linux/WSL) pour l'export ; DINOv2 déjà en cache dans TORCH_HOME (sinon téléchargé, 84 Mo).
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
NOTEBOOK = HERE / "classifier" / "ardane-classifier.ipynb"

OVERRIDES = {          # appliqués juste après la cellule de réglages
    "B_UNFREEZE_BLOCKS": 2, "B_EPOCHS": 2, "B_BATCH": 16, "B_PATIENCE": 2, "EXTRACT_BATCH": 32, "EXTRACT_EXTRA": ["--threads", "4"],
    "A_ALSO_MLP": True,
}


def build_fake_input(work: Path, train_images: int, val_images: int) -> Path:
    """Jeu factice COCO (make_fake_coco.py) rangé comme le jeu Kaggle."""
    fake_root = work / "fake_source"
    subprocess.run([sys.executable, "-B", str(ML / "make_fake_coco.py"), "--root", str(fake_root), "--train-images", str(train_images),
                    "--val-images", str(val_images)], check=True, cwd=ML)
    dataset = work / "input" / "food-recognition-2022-dataset"
    if dataset.exists():
        shutil.rmtree(dataset)
    for src, dst in (("train", "public_training_set_release_2.0"), ("val", "public_validation_set_2.0")):
        shutil.copytree(fake_root / "fake" / "coco" / src, dataset / dst)
    (dataset / "public_test_release_2.0" / "images").mkdir(parents=True)
    return dataset


def main() -> None:
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--work", required=True, help="dossier d'essai (créé, vidé à chaque lancement)")
    ap.add_argument("--train-images", type=int, default=96)
    ap.add_argument("--val-images", type=int, default=36)
    ap.add_argument("--keep", action="store_true", help="ne pas vider le dossier d'essai (reprise : relancer sur le même dossier)")
    args = ap.parse_args()
    work = Path(args.work)
    if work.exists() and not args.keep:
        shutil.rmtree(work)
    work.mkdir(parents=True, exist_ok=True)
    build_fake_input(work, args.train_images, args.val_images)
    os.environ["ARDANE_KAGGLE_SMOKE"] = str(work)
    os.environ.setdefault("TORCH_HOME", str(work / "temp" / "ardane_ml" / "torch_home"))

    notebook = json.loads(NOTEBOOK.read_text(encoding="utf-8"))
    cells = [c for c in notebook["cells"] if c["cell_type"] == "code"]
    namespace: dict = {"__name__": "__main__"}
    t_all = time.time()
    for index, cell in enumerate(cells):
        source = "".join(cell["source"])
        print(f"\n########## cellule {index + 1}/{len(cells)} ({cell['id']}) ##########", flush=True)
        t = time.time()
        exec(compile(source, f"<{cell['id']}>", "exec"), namespace)
        if index == 0:
            namespace.update(OVERRIDES)
            print("réglages d'essai :", OVERRIDES)
        print(f"----- cellule {index + 1} : {time.time() - t:.1f} s", flush=True)
    print(f"\n=== Carnet exécuté en {time.time() - t_all:.0f} s ===")

    # Vérifications de fin
    out = namespace["ENV"].out
    required = ["RESULTS.md", "class_map.csv", "classes.json", "ardane_state/stages.json", "reports", "weights", "models", "logs"]
    missing = [r for r in required if not (out / r).exists()]
    assert not missing, f"sorties manquantes : {missing}"
    stages = json.loads((out / "ardane_state" / "stages.json").read_text(encoding="utf-8"))["stages"]
    print("étapes terminées :", {k: v.get("done") for k, v in stages.items()})
    print("exports :", [e["zip"] for e in namespace["EXPORTS"]])
    assert namespace["FT"] and namespace["FT"]["status"] == "done", "l'affinage B n'est pas terminé"
    print("OK : le carnet A+B tourne de bout en bout sur le jeu factice.")


if __name__ == "__main__":
    main()
