"""Étape 4 : modèle COMPLET en Core ML (.mlpackage) : image 224 -> DINOv2-S/14 -> tête -> softmax étalonné.

À lancer dans WSL/Linux (roues `coremltools` publiées pour Linux et macOS seulement) ou sur macOS :

    python export_coreml.py --dataset myfoodrepo --head head-linear.pt --version 0.1.0 [--int8] [--classifier]

Entrée  : `image`, 224 x 224, RGB, valeurs 0..255 (aucune échelle ni biais Core ML : la normalisation ImageNet fait partie
          du graphe, comme à l'entraînement).
Sorties : `probabilities` (1 x C, softmax étalonné par la température T de la validation) et `embedding` (1 x 768 : CLS +
          moyenne des patchs, utilisable pour la mémoire personnelle). Avec `--classifier` : modèle « classifieur » Core ML
          (étiquette + dictionnaire de probabilités, `VNClassificationObservation`), sans `embedding`.
Classes : `<nom>.classes.json` à côté du paquet (index -> étiquette, nom, id Ardane) et copie dans
          les métadonnées du modèle (`ardane.classes`). Les étiquettes sont `mfr:<nom de classe MyFoodRepo>` : la correspondance vers
          les aliments d'Ardane (class_map.csv) peut être corrigée SANS ré-entraîner ni ré-exporter.
Précision : fp16 par défaut ; `--int8` écrit AUSSI une variante dont les poids sont quantifiés en int8 (par canal).

Sans bibliothèques natives de coremltools (Windows) le script fait une CONVERSION À BLANC (coreml_dryrun.py) : conversion
complète jusqu'au protobuf, taille du paquet calculée, mais AUCUN .mlpackage écrit (`--stop-after-mil` : programme MIL seul). Les écarts PyTorch / Core ML ne se mesurent qu'avec macOS : voir `parity_coreml.py` (runner macOS de la CI).
"""
from __future__ import annotations

import argparse
import hashlib
import json
import platform
import sys
import time
from datetime import date, datetime
from pathlib import Path

import numpy as np

import coreml_dryrun
from ml_common import (ATTRIBUTION_DINOV2, ATTRIBUTION_MYFOODREPO, HUB_COMMIT, HUB_MODEL, HUB_WEIGHTS_SHA256, IMAGE_SIZE, POOLS, fail, file_sha256,
                       class_label, load_dinov2_backbone, log, make_feature_net, make_full_net, ml_root, models_dir, rebuild_head,
                       write_json)


def directory_size(path: Path) -> int:
    return sum(p.stat().st_size for p in path.rglob("*") if p.is_file())


def mib(n: float) -> str:
    return f"{n / 1048576:.1f} Mo"


def main() -> None:
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--root")
    ap.add_argument("--dataset", default="myfoodrepo")
    ap.add_argument("--head", default="head-linear.pt", help="fichier de tête dans <racine>/models/<jeu>/")
    ap.add_argument("--name", default="ArdaneFoodClassifier")
    ap.add_argument("--version", default="0.0.1")
    ap.add_argument("--out", help="dossier de sortie (défaut : <racine>/models/<jeu>/export)")
    ap.add_argument("--int8", action="store_true", help="écrire aussi la variante int8 (poids quantifiés par canal)")
    ap.add_argument("--classifier", action="store_true", help="modèle « classifieur » Core ML (sans sortie embedding)")
    ap.add_argument("--stop-after-mil", action="store_true", help="s'arrêter après la conversion en programme MIL (aucun .mlpackage)")
    ap.add_argument("--parity-samples", type=int, default=8, help="recadrages utilisés pour comparer PyTorch direct / PyTorch tracé")
    ap.add_argument("--backbone-weights", help="state_dict d'un DINOv2 AFFINÉ (finetune_dinov2.py) : le modèle exporté l'utilise à la place des poids officiels")
    args = ap.parse_args()

    import torch
    from torch import nn

    root = ml_root(args.root)
    mdir = models_dir(root, args.dataset)
    head_path = mdir / args.head
    if not head_path.exists():
        fail(f"{head_path} est absent : lancer d'abord train_head.py")
    ck = torch.load(head_path, map_location="cpu", weights_only=False)
    if ck.get("format") != "ardane-head-v1":
        fail("format de tête inconnu")
    is_fake = ck["dataset_kind"] == "fake"
    out_dir = Path(args.out) if args.out else mdir / "export"
    out_dir.mkdir(parents=True, exist_ok=True)
    n_classes, dim, pool = ck["n_classes"], ck["dim"], ck["pool"]
    assert dim == POOLS[pool]

    log(f"== Export Core ML de « {args.name} » v{args.version} depuis {head_path.name} ({n_classes} classes, T = {ck['temperature']:.3f}"
        f"{', JEU FACTICE' if is_fake else ''})")
    head = rebuild_head(ck)
    ft_weights = Path(args.backbone_weights) if args.backbone_weights else None
    if ft_weights is not None and not ft_weights.exists():
        fail(f"{ft_weights} est introuvable (--backbone-weights)")
    ft_sha = file_sha256(ft_weights) if ft_weights is not None else None
    feat = make_feature_net(load_dinov2_backbone(root, weights_path=ft_weights), pool)
    temperature = float(ck["temperature"])
    labels = [class_label(c) for c in ck["classes"]]
    full = make_full_net(feat, head, temperature, with_embedding=not args.classifier)

    # Échantillons réels (recadrages de validation) ou, à défaut, du bruit déterministe
    samples = []
    crops_csv = root / "work" / args.dataset / "crops.csv"
    if crops_csv.exists():
        from PIL import Image
        from ml_common import read_csv
        for row in [r for r in read_csv(crops_csv) if r["split"] == "val"][:args.parity_samples]:
            with Image.open(root / "work" / args.dataset / row["crop"]) as im:
                samples.append(np.asarray(im.convert("RGB").resize((IMAGE_SIZE, IMAGE_SIZE)), dtype=np.float32))
    if not samples:
        rng = np.random.default_rng(0)
        samples = [rng.integers(0, 256, (IMAGE_SIZE, IMAGE_SIZE, 3)).astype(np.float32) for _ in range(args.parity_samples)]
    batch = torch.from_numpy(np.stack(samples)).permute(0, 3, 1, 2).contiguous()

    log("Trace TorchScript (une image par appel)")
    example = batch[:1]
    t0 = time.time()
    with torch.no_grad():
        traced = torch.jit.trace(full, example, strict=False)
    log(f"  tracé en {time.time() - t0:.1f} s")
    with torch.no_grad():
        worst = 0.0
        for i in range(len(batch)):
            ref, got = full(batch[i:i + 1]), traced(batch[i:i + 1])
            ref = ref[0] if isinstance(ref, tuple) else ref
            got = got[0] if isinstance(got, tuple) else got
            worst = max(worst, float((ref - got).abs().max()))
    log(f"  parité PyTorch direct / tracé sur {len(batch)} recadrages : écart maximal des probabilités {worst:.2e}")
    if worst > 1e-4:
        fail("le graphe tracé ne reproduit pas le modèle PyTorch")

    native = coreml_dryrun.natives_present()
    mil_only = args.stop_after_mil or not native
    if not native:
        log("  Bibliothèques natives de coremltools ABSENTES (Windows : pas de roues) : conversion à blanc, AUCUN .mlpackage ne sera écrit.")
        if not args.stop_after_mil:
            coreml_dryrun.install_sizing_shim()
    import coremltools as ct

    image_input = ct.ImageType(name="image", shape=(1, 3, IMAGE_SIZE, IMAGE_SIZE), color_layout=ct.colorlayout.RGB, scale=1.0, bias=[0.0, 0.0, 0.0])
    kwargs = dict(inputs=[image_input], minimum_deployment_target=ct.target.iOS17, compute_precision=ct.precision.FLOAT16)
    if args.classifier:
        kwargs["classifier_config"] = ct.ClassifierConfig(class_labels=labels)
    else:
        kwargs["outputs"] = [ct.TensorType(name="probabilities"), ct.TensorType(name="embedding")]

    summary = {
        "name": args.name, "version": args.version, "dataset": args.dataset, "dataset_kind": ck["dataset_kind"],
        "head_file": args.head, "head_sha256": file_sha256(head_path), "n_classes": n_classes, "temperature": temperature,
        "torch": torch.__version__, "coremltools": ct.__version__, "platform": platform.platform(),
        "exported_at": datetime.now().isoformat(timespec="seconds"), "trace_parity_max_abs": worst,
        "mode": "classifier" if args.classifier else "probabilities+embedding",
        **({"backbone_weights": {"file": ft_weights.name, "sha256": ft_sha}} if ft_sha else {}),
    }

    if mil_only:
        t0 = time.time()
        if not native and not args.stop_after_mil:
            log("Conversion complète à blanc (protobuf réel, poids comptés mais non écrits dans un paquet)")
            sized = coreml_dryrun.dry_serialize(ct, traced, **kwargs)
            log(f"  convertie en {time.time() - t0:.1f} s ; protobuf {sized['proto_bytes'] / 1024:.0f} Ko ; poids (fp16) {mib(sized['weight_bin_bytes'])} "
                f"en {sized['blobs']} blocs ; taille CALCULÉE du .mlpackage fp16 : {mib(sized['package_bytes_estimate'])}")
            summary.update({"dry_run": True, "dry_run_fp16": sized, "note": "taille calculée par conversion à blanc ; AUCUN .mlpackage écrit"})
            write_json(out_dir / f"{args.name}.export.json", summary)
            log(f"  résumé : {out_dir / (args.name + '.export.json')}")
            return
        log("Conversion Torch -> programme MIL seulement (--stop-after-mil)")
        prog = ct.convert(traced, convert_to="milinternal", **{k: v for k, v in kwargs.items() if k != "classifier_config"})
        total_params = 0
        for op in prog.functions["main"].find_ops(op_type="const"):
            val = op.outputs[0].val
            if isinstance(val, np.ndarray) and val.size > 64:
                total_params += val.size
        log(f"  converti en {time.time() - t0:.1f} s ; {len(prog.functions['main'].operations)} opérations de haut niveau, "
            f"{total_params / 1e6:.2f} M constantes volumineuses ({mib(total_params * 2)} en fp16, {mib(total_params)} en int8)")
        summary.update({"mil_only": True, "weight_params": int(total_params), "estimated_fp16_bytes": int(total_params * 2),
                        "estimated_int8_bytes": int(total_params), "note": "estimation par construction ; AUCUN .mlpackage écrit"})
        write_json(out_dir / f"{args.name}.export.json", summary)
        log(f"  résumé : {out_dir / (args.name + '.export.json')}")
        return

    classes_info = [{"index": i, "label": labels[i], "class_id": c["class_id"], "name": c["name"], "name_readable": c["name_readable"],
                     "ardane_id": c.get("ardane_id", "")} for i, c in enumerate(ck["classes"])]
    attribution = [ATTRIBUTION_DINOV2]
    if not is_fake:
        attribution.append(ATTRIBUTION_MYFOODREPO)

    def annotate(model, variant: str) -> None:
        model.short_description = (
            f"Ardane : reconnaissance d'un aliment sur un recadrage carré ({n_classes} classes)"
            + (" ; MODÈLE D'ESSAI ENTRAÎNÉ SUR UN JEU FACTICE, NE PAS LIVRER" if is_fake else "")
        )
        model.author = "Ardane"
        model.license = " ; ".join(attribution) + ". Tête de classification : Ardane."
        model.version = args.version
        model.input_description["image"] = "Recadrage carré de l'aliment, 224 x 224, RGB (0..255)."
        if not args.classifier:
            model.output_description["probabilities"] = "Probabilités par classe (softmax étalonné, température de validation)."
            model.output_description["embedding"] = f"Vecteur DINOv2 ({dim} nombres : CLS + moyenne des patchs)."
        meta = {
            "ardane.version": args.version, "ardane.variant": variant, "ardane.dataset": ck["dataset"],
            "ardane.dataset_kind": ck["dataset_kind"], "ardane.dataset_license": ck["dataset_license"],
            "ardane.attribution": " | ".join(attribution), "ardane.temperature": f"{temperature:.6f}",
            "ardane.backbone": f"facebookresearch/dinov2@{HUB_COMMIT} {HUB_MODEL} (poids sha256 {HUB_WEIGHTS_SHA256})"
            + (f" ; AFFINÉ par Ardane (poids sha256 {ft_sha})" if ft_sha else ""),
            "ardane.pool": pool, "ardane.input": "image 224x224 RGB 0..255 ; normalisation ImageNet dans le graphe",
            "ardane.class_labels": "mfr:<nom de classe MyFoodRepo> ; voir ardane.classes",
            "ardane.classes": json.dumps([[c["index"], c["label"], c["ardane_id"]] for c in classes_info], ensure_ascii=False, separators=(",", ":")),
            "ardane.trained_at": ck["trained_at"], "ardane.exported_at": summary["exported_at"],
        }
        for key, value in meta.items():
            model.user_defined_metadata[key] = value

    log("Conversion Torch -> Core ML (programme ML, fp16, iOS 17)")
    t0 = time.time()
    model = ct.convert(traced, convert_to="mlprogram", **kwargs)
    log(f"  converti en {time.time() - t0:.1f} s")
    package = out_dir / f"{args.name}-fp16.mlpackage"
    annotate(model, "fp16")
    model.save(str(package))
    sizes = {"fp16": directory_size(package)}
    log(f"  {package} : {mib(sizes['fp16'])}")

    if args.int8:
        import coremltools.optimize.coreml as cto
        log("Quantification int8 des poids (par canal, symétrique)")
        config = cto.OptimizationConfig(global_config=cto.OpLinearQuantizerConfig(mode="linear_symmetric", dtype="int8", granularity="per_channel"))
        quant = cto.linear_quantize_weights(model, config=config)
        package8 = out_dir / f"{args.name}-int8.mlpackage"
        annotate(quant, "int8")
        quant.save(str(package8))
        sizes["int8"] = directory_size(package8)
        log(f"  {package8} : {mib(sizes['int8'])}")

    write_json(out_dir / f"{args.name}.classes.json", {
        "version": args.version, "temperature": temperature, "input": {"name": "image", "size": IMAGE_SIZE, "layout": "RGB", "range": "0..255"},
        "outputs": ["classLabel", "classLabelProbs"] if args.classifier else ["probabilities", "embedding"],
        "classes": classes_info, "attribution": attribution, "dataset_kind": ck["dataset_kind"],
    })
    (out_dir / "ATTRIBUTIONS.txt").write_text(
        "À afficher dans l'app (Réglages > Licences) si ce modèle est livré :\n\n" + "\n".join(f"- {a}" for a in attribution)
        + "\n\nLes poids de la tête sont la propriété d'Ardane. Les données d'entraînement ne sont pas redistribuées.\n", encoding="utf-8")
    summary.update({"mil_only": False, "sizes_bytes": sizes, "sizes_human": {k: mib(v) for k, v in sizes.items()}})
    write_json(out_dir / f"{args.name}.export.json", summary)
    log(f"Terminé. Tailles : " + ", ".join(f"{k} {mib(v)}" for k, v in sizes.items()) + f". Résumé : {out_dir / (args.name + '.export.json')}")
    log("Parité PyTorch / Core ML : à mesurer sur macOS avec parity_coreml.py (non vérifiable ici).")


if __name__ == "__main__":
    main()
