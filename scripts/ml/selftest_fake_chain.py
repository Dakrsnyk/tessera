"""Auto-test de bout en bout de la chaîne sur le jeu FACTICE : fabrication -> préparation -> vecteurs -> tête -> export Core ML.

Aucun chiffre n'est une précision (formes colorées, classes inventées) : le test prouve seulement que chaque étape tourne et
que ses sorties existent et se tiennent. À relancer après toute modification des scripts, et sur le runner macOS de la CI
(où l'export écrit un vrai .mlpackage et où `--parity` lance parity_coreml.py).

    python selftest_fake_chain.py                              # tout dans l'environnement courant
    python selftest_fake_chain.py --export-python <python de l'env d'export>   # Windows : export dans un autre venv
    python selftest_fake_chain.py --supervisely                # teste AUSSI la lecture d'un projet Supervisely (Dataset Ninja)
"""
from __future__ import annotations

import argparse
import platform
import subprocess
import sys
import time
from pathlib import Path

from ml_common import SCRIPT_DIR, fail, log, ml_root, read_json


def run(label: str, command: list[str]) -> float:
    log(f"\n##### {label}\n$ {' '.join(command)}")
    t0 = time.time()
    result = subprocess.run(command, cwd=SCRIPT_DIR)
    if result.returncode != 0:
        fail(f"étape « {label} » en échec (code {result.returncode})")
    return time.time() - t0


def main() -> None:
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--root")
    ap.add_argument("--export-python", default=sys.executable, help="interpréteur qui a coremltools (défaut : le courant)")
    ap.add_argument("--int8", action="store_true")
    ap.add_argument("--parity", action="store_true", help="lancer parity_coreml.py (macOS seulement)")
    ap.add_argument("--supervisely", action="store_true", help="tester aussi `prepare_myfoodrepo.py --format supervisely` (jeu « fake-sly »)")
    args = ap.parse_args()
    root = str(ml_root(args.root))
    py = sys.executable
    common = ["--root", root, "--dataset", "fake"]
    timings = {}
    fake_cmd = [py, "make_fake_coco.py", "--root", root] + (["--supervisely"] if args.supervisely else [])
    timings["jeu factice"] = run("1/5 jeu factice COCO" + (" + Supervisely" if args.supervisely else ""), fake_cmd)
    timings["préparation"] = run("2/5 préparation", [py, "prepare_myfoodrepo.py", *common])
    timings["vecteurs"] = run("3/5 vecteurs DINOv2", [py, "extract_features.py", *common])
    timings["tête"] = run("4/5 tête + étalonnage + rapport", [py, "train_head.py", *common])
    export_cmd = [args.export_python, "export_coreml.py", *common, "--head", "head-linear.pt", "--version", "0.0.1-fake"]
    if args.int8:
        export_cmd.append("--int8")
    timings["export"] = run("5/5 export Core ML", export_cmd)
    if args.supervisely:
        sly = ["--root", root, "--dataset", "fake-sly"]
        timings["Supervisely : préparation"] = run("Supervisely 1/3 préparation", [py, "prepare_myfoodrepo.py", *sly, "--format", "supervisely"])
        timings["Supervisely : vecteurs"] = run("Supervisely 2/3 vecteurs", [py, "extract_features.py", *sly])
        timings["Supervisely : tête"] = run("Supervisely 3/3 tête", [py, "train_head.py", *sly])

    work = Path(root) / "work" / "fake"
    meta, fmeta = read_json(work / "meta.json"), read_json(work / "features" / "meta.json")
    exported = read_json(Path(root) / "models" / "fake" / "export" / "ArdaneFoodClassifier.export.json")
    assert meta["kind"] == "fake" and meta["dropped_train_photos_leak"] >= 1, "la fuite volontaire n'a pas été détectée"
    assert fmeta["dim"] == 768
    log("\n=== Auto-test terminé ===")
    for name, seconds in timings.items():
        log(f"  {name} : {seconds:.0f} s")
    if args.supervisely:
        sly_meta = read_json(Path(root) / "work" / "fake-sly" / "meta.json")
        classes_coco = {c["name"] for c in read_json(work / "classes.json")}
        classes_sly = {c["name"] for c in read_json(Path(root) / "work" / "fake-sly" / "classes.json")}
        assert sly_meta["split_mode"] == "three", "le découpage officiel en trois jeux n'a pas été reconnu"
        assert classes_coco == classes_sly, "les classes diffèrent entre COCO et Supervisely"
        assert sum(meta["crops"].values()) == sum(sly_meta["crops"].values()), "nombre de recadrages différent entre COCO et Supervisely"
        assert sly_meta["dropped_train_photos_leak"] >= 1, "la fuite volontaire n'a pas été détectée (Supervisely)"
        log(f"  Supervisely : mêmes {len(classes_sly)} classes et mêmes {sum(sly_meta['crops'].values())} recadrages que le COCO ; "
            f"découpage {sly_meta['photos']} ; rejets {sly_meta['rejected']}")
    if exported.get("dry_run"):
        log(f"  export : conversion à blanc, taille calculée {exported['dry_run_fp16']['package_bytes_estimate'] / 1048576:.1f} Mo (aucun .mlpackage : plate-forme sans natives)")
    else:
        log(f"  export : tailles {exported.get('sizes_human')}")
    if args.parity:
        package = Path(root) / "models" / "fake" / "export" / "ArdaneFoodClassifier-fp16.mlpackage"
        run("parité PyTorch / Core ML", [py, "parity_coreml.py", "--package", str(package), "--head",
                                         str(Path(root) / "models" / "fake" / "head-linear.pt"), "--synthetic", "32", "--root", root])
    elif platform.system() == "Darwin":
        log("  (sur macOS, relancer avec --parity pour mesurer l'écart PyTorch / Core ML)")


if __name__ == "__main__":
    main()
