"""Télécharge la partie « vue de dessus » de Nutrition5k (Google, CC BY 4.0, usage commercial permis : README du dépôt officiel
github.com/google-research-datasets/Nutrition5k, vérifié le 2026-11-04) : rgb.png + depth_raw.png par plat, depuis le seau public officiel.

Sert à MESURER et caler l'estimation des grammes (chantier 22.4) : chaque plat a son poids total et le poids de chaque ingrédient pesés.
Rien ne va dans le dépôt : <ARDANE_ML_ROOT>/raw/nutrition5k/. Reprend là où il s'est arrêté.

    python -I scripts/ml/fetch_nutrition5k.py
"""
from __future__ import annotations

import os
import sys
import urllib.request
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

ROOT = Path(os.environ.get("ARDANE_ML_ROOT", r"C:\Users\Etudiant\ardane-tools\ml")) / "raw" / "nutrition5k"
BASE = "https://storage.googleapis.com/nutrition5k_dataset/nutrition5k_dataset/imagery/realsense_overhead"
UA = "ArdaneFoodDataset/1.0"


def ids() -> list[str]:
    out = []
    for name in ("depth_train_ids.txt", "depth_test_ids.txt"):
        out += [line.strip() for line in (ROOT / "splits" / name).read_text().splitlines() if line.strip()]
    return sorted(set(out))


def fetch(dish: str) -> str:
    folder = ROOT / "overhead" / dish
    folder.mkdir(parents=True, exist_ok=True)
    for f in ("rgb.png", "depth_raw.png"):
        dest = folder / f
        if dest.exists() and dest.stat().st_size > 0:
            continue
        try:
            req = urllib.request.Request(f"{BASE}/{dish}/{f}", headers={"User-Agent": UA})
            with urllib.request.urlopen(req, timeout=60) as r:
                data = r.read()
            tmp = dest.with_suffix(".part")
            tmp.write_bytes(data)
            tmp.replace(dest)
        except Exception as e:
            return f"{dish}/{f}: {e}"
    return ""


if __name__ == "__main__":
    dishes = ids()
    print(len(dishes), "plats")
    with ThreadPoolExecutor(8) as pool:
        errors = [e for e in pool.map(fetch, dishes) if e]
    print("erreurs :", len(errors), *errors[:10], sep="\n")
    sys.exit(0)
