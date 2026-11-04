"""Export du segmenteur : ONNX (sûr) et Core ML (TENTATIVE, non garantie), avec un rapport qui dit précisément ce qui marche ou échoue.

Ce que dit le paquet `rfdetr` 1.11.2 (docstring de `RFDETR.export`) : `format="coreml"` exporte un `.mlpackage` natif par `torch.export` +
`coremltools` (`pip install rfdetr[coreml]`, coremltools >= 8 et < 10), « expérimental », sans lot dynamique, avec des tests d'opérateurs et de parité
déclarés pour la détection, la segmentation et les points-clés. Aucun de ces tests n'a été rejoué ici : c'est ce que ce script vérifie.

Pour chaque format : un dictionnaire {ok, files, sizes, seconds, error, traceback_tail, versions}. Une exception n'interrompt jamais l'autre format.
Le Core ML produit attend en entrée un tenseur NCHW normalisé (moyenne ImageNet 0,485/0,456/0,406, écart 0,229/0,224/0,225, valeurs 0..1) : la
normalisation et le redimensionnement sont à faire côté Swift ; les sorties se lisent PAR POSITION (dets, labels, masks), pas par nom.

    python seg_export.py --checkpoint run/checkpoint_best_total.pth --size nano --out export/ [--formats onnx,coreml]
"""
from __future__ import annotations

import json
import time
import traceback
from pathlib import Path


def versions() -> dict:
    from importlib import metadata

    out = {}
    for name in ("torch", "coremltools", "rfdetr", "onnx", "onnxruntime", "numpy", "transformers"):
        try:
            out[name] = metadata.version(name)
        except Exception:                                    # noqa: BLE001
            out[name] = None
    return out


def _sizes(paths) -> dict:
    result = {}
    for p in paths:
        p = Path(p)
        if p.is_dir():
            result[p.name] = sum(f.stat().st_size for f in p.rglob("*") if f.is_file())
        elif p.exists():
            result[p.name] = p.stat().st_size
    return result


def export_one(checkpoint: Path, out_dir: Path, fmt: str, **kwargs) -> dict:
    """Un export, protégé : retourne toujours un dictionnaire (jamais d'exception)."""
    import rfdetr

    out_dir.mkdir(parents=True, exist_ok=True)
    before = {p for p in out_dir.iterdir()}
    report: dict = {"format": fmt, "ok": False, "kwargs": {k: str(v) for k, v in kwargs.items()}, "versions": versions()}
    t0 = time.time()
    try:
        model = rfdetr.from_checkpoint(str(checkpoint))
        path = model.export(output_dir=str(out_dir), format=fmt, verbose=False, **kwargs)
        report.update({"ok": True, "main_file": str(path)})
    except BaseException as exc:                              # noqa: BLE001  (SystemExit compris : certains exporteurs l'utilisent)
        report.update({"error": f"{type(exc).__name__}: {str(exc)[:1500]}", "traceback_tail": "".join(traceback.format_exc().splitlines(True)[-14:])})
    report["seconds"] = round(time.time() - t0, 1)
    new = sorted(p for p in out_dir.iterdir() if p not in before)
    report["files"] = [p.name for p in new]
    report["sizes_bytes"] = _sizes(new)
    return report


def inspect_mlpackage(path: Path) -> dict:
    """Entrées et sorties d'un .mlpackage (sans le charger : la prédiction n'existe que sous macOS)."""
    try:
        import coremltools as ct
        from coremltools.proto import FeatureTypes_pb2

        spec = ct.models.MLModel(str(path), skip_model_load=True).get_spec()

        def describe(feature):
            kind = feature.type.WhichOneof("Type")
            if kind == "multiArrayType":
                array = feature.type.multiArrayType
                return {"name": feature.name, "type": "multiArray", "shape": list(array.shape),
                        "dtype": FeatureTypes_pb2.ArrayFeatureType.ArrayDataType.Name(array.dataType)}
            if kind == "imageType":
                image = feature.type.imageType
                return {"name": feature.name, "type": "image", "shape": [image.height, image.width]}
            return {"name": feature.name, "type": kind}

        return {"inputs": [describe(i) for i in spec.description.input], "outputs": [describe(o) for o in spec.description.output],
                "spec_version": spec.specificationVersion}
    except Exception as exc:                                  # noqa: BLE001
        return {"error": f"{type(exc).__name__}: {str(exc)[:300]}"}


def try_int8(package: Path, out_dir: Path) -> dict:
    """Quantification int8 (par canal) des poids du Core ML : tentative, sans prédiction possible ici."""
    report: dict = {"ok": False}
    try:
        import coremltools as ct
        import coremltools.optimize.coreml as cto

        model = ct.models.MLModel(str(package), skip_model_load=True)
        config = cto.OptimizationConfig(global_config=cto.OpLinearQuantizerConfig(mode="linear_symmetric", dtype="int8", granularity="per_channel"))
        quant = cto.linear_quantize_weights(model, config=config)
        target = out_dir / (package.stem + "-int8.mlpackage")
        quant.save(str(target))
        report.update({"ok": True, "file": target.name, "size_bytes": sum(f.stat().st_size for f in target.rglob("*") if f.is_file())})
    except BaseException as exc:                              # noqa: BLE001
        report["error"] = f"{type(exc).__name__}: {str(exc)[:600]}"
    return report


def export_all(checkpoint: Path, out_dir: Path, formats=("onnx", "coreml"), coreml_precisions=("float16",), log=print) -> dict:
    result: dict = {"checkpoint": str(checkpoint), "exports": {}}
    for fmt in formats:
        if fmt == "coreml":
            for precision in coreml_precisions:
                key = f"coreml-{precision}"
                result["exports"][key] = export_one(checkpoint, out_dir / "coreml" / precision, "coreml", coreml_precision=precision)
                rep = result["exports"][key]
                log(f"[export segmenteur] {key} : {'OK' if rep['ok'] else 'ÉCHEC'} en {rep['seconds']} s ; {rep.get('error', '')[:200]}")
                if rep["ok"]:
                    package = Path(rep["main_file"])
                    rep["interface"] = inspect_mlpackage(package)
                    if precision == "float16":
                        rep["int8"] = try_int8(package, package.parent)
                        log(f"[export segmenteur] int8 : {rep['int8']}")
        else:
            result["exports"][fmt] = export_one(checkpoint, out_dir / fmt, fmt)
            rep = result["exports"][fmt]
            log(f"[export segmenteur] {fmt} : {'OK' if rep['ok'] else 'ÉCHEC'} en {rep['seconds']} s ; {rep.get('error', '')[:200]}")
    (out_dir / "export-report.json").write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    return result


def render_markdown(result: dict) -> str:
    lines = []
    for key, rep in result["exports"].items():
        lines.append(f"- **{key}** : {'OK' if rep['ok'] else 'ÉCHEC'} ({rep['seconds']} s). Fichiers : {', '.join(rep['files']) or 'aucun'}.")
        if rep.get("sizes_bytes"):
            lines.append("  Tailles : " + ", ".join(f"{k} {v / 1048576:.1f} Mo" for k, v in rep["sizes_bytes"].items()) + ".")
        if not rep["ok"]:
            lines.append(f"  Erreur exacte : `{rep.get('error', '?')[:400]}`")
        if rep.get("interface"):
            iface = rep["interface"]
            if "error" in iface:
                lines.append(f"  Interface non lisible : {iface['error']}")
            else:
                lines.append("  Entrées : " + "; ".join(f"{i['name']} {i.get('shape', '')} {i.get('dtype', '')}" for i in iface["inputs"]) +
                             " | Sorties (à lire par position) : " + "; ".join(f"{o['name']} {o.get('shape', '')}" for o in iface["outputs"]))
        if rep.get("int8"):
            lines.append(f"  int8 : {'OK, ' + rep['int8'].get('file', '') if rep['int8']['ok'] else 'ÉCHEC : ' + rep['int8'].get('error', '?')}")
    v = next(iter(result["exports"].values()))["versions"] if result["exports"] else {}
    lines.append(f"- Versions : {v}. Parité numérique et prédiction : impossibles hors macOS (Core ML ne prédit que sous macOS) : à mesurer sur le runner macOS de la CI.")
    return "\n".join(lines)


if __name__ == "__main__":
    import argparse

    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--checkpoint", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--formats", default="onnx,coreml")
    ap.add_argument("--precisions", default="float16")
    args = ap.parse_args()
    res = export_all(Path(args.checkpoint), Path(args.out), tuple(args.formats.split(",")), tuple(args.precisions.split(",")))
    print(render_markdown(res))
