"""Contrôle de parité numérique PyTorch / Core ML : à exécuter sur macOS (Core ML ne prédit que sous macOS).

NON EXÉCUTÉ À CE JOUR : l'ordinateur de développement est un Windows sans macOS. Ce script est prêt pour le runner macOS de la
CI (voir README.md, section « Parité sur le runner macOS »). Il compare, sur les mêmes images :
  - le modèle PyTorch complet (DINOv2-S + tête + softmax étalonné), tel que l'export le construit ;
  - le `.mlpackage` produit par export_coreml.py.
Mesures : écart maximal et moyen des probabilités, accord du Top-1 et du Top-3, cosinus des embeddings. Le code de sortie est
non nul si une tolérance est dépassée. Tolérances par défaut pour fp16 ; en int8 : --variant int8.

    pip install coremltools torch pillow numpy
    python parity_coreml.py --package ArdaneFoodClassifier-fp16.mlpackage --head head-linear.pt --synthetic 64
    python parity_coreml.py --package ... --head ... --crops <dossier de .jpg 224x224> --n 200
"""
from __future__ import annotations

import argparse
import json
import platform
import sys
from pathlib import Path

import numpy as np

from ml_common import IMAGE_SIZE, class_label, fail, load_dinov2_backbone, log, make_feature_net, make_full_net, ml_root, rebuild_head

TOLERANCES = {   # (écart maximal des probabilités, accord Top-1 minimal)
    "fp16": (0.02, 0.98),
    "int8": (0.08, 0.93),
}


def synthetic_images(n: int, seed: int = 0) -> list[np.ndarray]:
    """Images déterministes « naturelles » : champs lisses + formes, pour exercer le modèle sans données."""
    from PIL import Image, ImageDraw, ImageFilter

    rng = np.random.default_rng(seed)
    out = []
    for _ in range(n):
        base = rng.integers(0, 256, (14, 14, 3), dtype=np.uint8)
        img = Image.fromarray(base).resize((IMAGE_SIZE, IMAGE_SIZE), Image.BICUBIC)
        draw = ImageDraw.Draw(img)
        for _ in range(rng.integers(2, 6)):
            x, y = rng.integers(0, IMAGE_SIZE - 40, 2)
            w, h = rng.integers(20, 100, 2)
            draw.ellipse((x, y, x + w, y + h), fill=tuple(int(v) for v in rng.integers(0, 256, 3)))
        out.append(img.filter(ImageFilter.GaussianBlur(1.0)))
    return out


def main() -> None:
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--root")
    ap.add_argument("--package", required=True, help="chemin du .mlpackage à contrôler")
    ap.add_argument("--head", required=True, help="chemin du head-*.pt utilisé pour l'export")
    ap.add_argument("--variant", choices=sorted(TOLERANCES), default="fp16")
    ap.add_argument("--crops", help="dossier de recadrages 224 x 224 (.jpg) ; sinon --synthetic")
    ap.add_argument("--n", type=int, default=100)
    ap.add_argument("--synthetic", type=int, default=0, help="nombre d'images synthétiques déterministes")
    ap.add_argument("--classifier", action="store_true", help="le paquet a été exporté avec --classifier")
    ap.add_argument("--report", help="écrire le résultat en JSON")
    ap.add_argument("--backbone-weights", help="state_dict du DINOv2 AFFINÉ utilisé à l'export (finetune_dinov2.py)")
    args = ap.parse_args()

    if platform.system() != "Darwin":
        fail("Core ML ne prédit que sous macOS : ce contrôle ne peut pas tourner ici (Windows/Linux).")
    import coremltools as ct
    import torch
    from PIL import Image

    root = ml_root(args.root)
    ck = torch.load(args.head, map_location="cpu", weights_only=False)
    full = make_full_net(make_feature_net(load_dinov2_backbone(root, weights_path=args.backbone_weights), ck["pool"]), rebuild_head(ck),
                         float(ck["temperature"]), with_embedding=True)
    labels = [class_label(c) for c in ck["classes"]]

    if args.crops:
        files = sorted(Path(args.crops).glob("*.jpg"))[:args.n]
        images = [Image.open(f).convert("RGB").resize((IMAGE_SIZE, IMAGE_SIZE)) for f in files]
    else:
        images = synthetic_images(args.synthetic or args.n)
    if not images:
        fail("aucune image de contrôle")

    model = ct.models.MLModel(args.package)
    spec = model.get_spec()
    log(f"Paquet : {args.package} ; entrées {[i.name for i in spec.description.input]} ; sorties {[o.name for o in spec.description.output]}")
    diffs, top1_ok, top3_ok, cosines = [], 0, 0, []
    for img in images:
        pixels = torch.from_numpy(np.asarray(img, dtype=np.float32)).permute(2, 0, 1).unsqueeze(0)
        with torch.no_grad():
            ref_p, ref_e = full(pixels)
        ref_p, ref_e = ref_p[0].numpy(), ref_e[0].numpy()
        result = model.predict({"image": img})
        if args.classifier:
            probs = result["classLabelProbs"]
            got_p = np.array([probs[label] for label in labels], dtype=np.float64)
        else:
            got_p = np.asarray(result["probabilities"], dtype=np.float64).reshape(-1)
            got_e = np.asarray(result["embedding"], dtype=np.float64).reshape(-1)
            cosines.append(float(got_e @ ref_e / (np.linalg.norm(got_e) * np.linalg.norm(ref_e) + 1e-12)))
        diffs.append(float(np.abs(got_p - ref_p).max()))
        top1_ok += int(got_p.argmax() == ref_p.argmax())
        top3_ok += int(set(np.argsort(-got_p)[:3]) == set(np.argsort(-ref_p)[:3]))
    n = len(images)
    max_tol, top1_min = TOLERANCES[args.variant]
    result = {
        "package": args.package, "variant": args.variant, "n": n,
        "max_abs_prob_diff": max(diffs), "mean_abs_prob_diff_of_max": float(np.mean(diffs)),
        "top1_agreement": top1_ok / n, "top3_set_agreement": top3_ok / n,
        "embedding_cosine_min": min(cosines) if cosines else None,
        "tolerances": {"max_abs_prob_diff": max_tol, "top1_agreement_min": top1_min},
        "coremltools": ct.__version__, "torch": torch.__version__, "platform": platform.platform(),
        "synthetic_inputs": not args.crops,
    }
    result["passed"] = bool(result["max_abs_prob_diff"] <= max_tol and result["top1_agreement"] >= top1_min)
    log(json.dumps(result, indent=2, ensure_ascii=False))
    if args.report:
        Path(args.report).write_text(json.dumps(result, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    sys.exit(0 if result["passed"] else 1)


if __name__ == "__main__":
    main()
