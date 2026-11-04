"""Construit les deux carnets Kaggle d'Ardane à partir du code de `scripts/ml/` (source de vérité UNIQUE, jamais dupliquée à la main).

    python build_notebooks.py            # (ré)écrit classifier/ardane-classifier.ipynb et segmenter/ardane-segmenter.ipynb
    python build_notebooks.py --check    # n'écrit rien : échoue si un carnet n'est plus à jour avec le code (à lancer avant de pousser sur Kaggle)
    python build_notebooks.py --py311 C:\\...\\python.exe   # vérifie en plus la syntaxe de TOUT le code embarqué avec Python 3.11 (image Kaggle)

Le code nécessaire est embarqué dans chaque carnet sous forme d'une archive zip encodée en base64, avec son empreinte SHA-256 ; la
première cellule de code la vérifie et l'extrait dans /kaggle/working/ardane_code. Le carnet ne dépend donc d'aucun clone Git, épinglé
ou non : il contient la version exacte du code qui a servi à le construire (empreintes affichées au lancement).

Les `kernel-metadata.json` ne sont écrits que s'ils n'existent pas (ils contiennent le nom d'utilisateur Kaggle).
"""
from __future__ import annotations

import argparse
import base64
import hashlib
import importlib.util
import io
import json
import subprocess
import sys
import zipfile
from pathlib import Path

HERE = Path(__file__).resolve().parent
ML = HERE.parent

PAYLOADS = {
    "classifier": [ML / n for n in ("ml_common.py", "class_matching.py", "prepare_myfoodrepo.py", "derive_ardane_labels.py", "extract_features.py", "train_head.py",
                                    "export_coreml.py", "coreml_dryrun.py", "class_map.csv")]
    + [HERE / "kaggle_common.py", HERE / "classifier" / "finetune_dinov2.py", HERE / "classifier" / "classifier_report.py"],
    "segmenter": [ML / n for n in ("ml_common.py", "class_matching.py", "prepare_myfoodrepo.py")]
    + [HERE / "kaggle_common.py"] + [HERE / "segmenter" / n for n in ("seg_metrics.py", "seg_dataset.py", "seg_train.py", "seg_eval.py", "seg_export.py")],
}
NOTEBOOKS = {
    "classifier": {"file": HERE / "classifier" / "ardane-classifier.ipynb", "cells": HERE / "classifier" / "notebook_cells.py"},
    "segmenter": {"file": HERE / "segmenter" / "ardane-segmenter.ipynb", "cells": HERE / "segmenter" / "notebook_cells.py"},
}
METADATA = {
    "classifier": {"id": "darksnyk/ardane-food-classifier", "title": "Ardane food classifier", "code_file": "ardane-classifier.ipynb"},
    "segmenter": {"id": "darksnyk/ardane-food-segmenter", "title": "Ardane food segmenter", "code_file": "ardane-segmenter.ipynb"},
}


def git_head() -> str:
    try:
        return subprocess.run(["git", "rev-parse", "HEAD"], cwd=ML, capture_output=True, text=True, timeout=10).stdout.strip()[:10]
    except Exception:                                                  # noqa: BLE001
        return ""


def build_payload(files: list[Path]) -> tuple[bytes, dict]:
    """Zip déterministe (noms triés, dates fixes) : la même source donne les mêmes octets, donc la même empreinte."""
    buffer = io.BytesIO()
    manifest = {}
    with zipfile.ZipFile(buffer, "w", zipfile.ZIP_DEFLATED, compresslevel=9) as z:
        for path in sorted(files, key=lambda p: p.name):
            data = path.read_bytes().replace(b"\r\n", b"\n")           # fins de ligne normalisées : même empreinte sous Windows et Linux
            info = zipfile.ZipInfo(path.name, date_time=(2026, 11, 2, 0, 0, 0))
            info.compress_type = zipfile.ZIP_DEFLATED
            z.writestr(info, data)
            manifest[path.name] = hashlib.sha256(data).hexdigest()
    return buffer.getvalue(), manifest


def load_cells(path: Path):
    spec = importlib.util.spec_from_file_location("cells_" + path.parent.name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def to_source(text: str) -> list[str]:
    lines = text.strip("\n").split("\n")
    return [line + "\n" for line in lines[:-1]] + [lines[-1]]


def build_notebook(kind: str) -> tuple[dict, dict]:
    payload, manifest = build_payload(PAYLOADS[kind])
    digest = hashlib.sha256(payload).hexdigest()
    b64 = base64.b64encode(payload).decode("ascii")
    wrapped = "\n".join(b64[i:i + 110] for i in range(0, len(b64), 110))
    source = f"scripts/ml/ du dépôt Dakrsnyk/tessera, commit de base {git_head() or 'inconnu'} (+ modifications locales non commitées) ; fichiers : {', '.join(sorted(manifest))}"
    module = load_cells(NOTEBOOKS[kind]["cells"])
    cells = []
    for n, entry in enumerate(module.CELLS):
        cell_type, text = entry[0], entry[1]
        flags = entry[2] if len(entry) > 2 else {}
        text = text.replace("{{PAYLOAD_SHA256}}", digest).replace("{{PAYLOAD_SOURCE}}", source.replace('"', "'")).replace("{{PAYLOAD_B64}}", wrapped)
        cell = {"id": f"ardane-{kind[:3]}-{n:02d}", "cell_type": "markdown" if cell_type == "md" else "code", "metadata": {}, "source": to_source(text)}
        if cell_type == "code":
            cell.update({"execution_count": None, "outputs": []})
            if flags.get("hidden"):
                cell["metadata"] = {"jupyter": {"source_hidden": True}, "collapsed": True}
        cells.append(cell)
    notebook = {"cells": cells, "nbformat": 4, "nbformat_minor": 5,
                "metadata": {"kernelspec": {"display_name": "Python 3", "language": "python", "name": "python3"},
                             "language_info": {"name": "python"}, "ardane": {"payload_sha256": digest, "files": manifest, "title": module.TITLE}}}
    return notebook, {"payload_sha256": digest, "files": manifest, "bytes": len(payload)}


def metadata_for(kind: str) -> dict:
    base = {"language": "python", "kernel_type": "notebook", "is_private": True, "enable_gpu": True, "enable_tpu": False, "enable_internet": True,
            "machine_shape": "NvidiaTeslaT4", "docker_image_pinning_type": "original",
            "dataset_sources": ["awsaf49/food-recognition-2022-dataset"], "competition_sources": [], "kernel_sources": [], "model_sources": []}
    return {**METADATA[kind], **base}


def check_code_cells(notebook: dict, label: str) -> None:
    for cell in notebook["cells"]:
        if cell["cell_type"] == "code":
            try:
                compile("".join(cell["source"]), f"{label}:{cell['id']}", "exec")
            except SyntaxError as exc:
                raise SystemExit(f"ERREUR : cellule {cell['id']} de {label} : {exc}")


def check_py311(interpreter: str, files: list[Path], notebook: dict, label: str) -> None:
    """Compile chaque fichier embarqué et chaque cellule avec Python 3.11 (version probable de l'image Kaggle)."""
    snippet = "import sys; compile(open(sys.argv[1], encoding='utf-8').read(), sys.argv[1], 'exec')"
    for path in files:
        if path.suffix == ".py":
            result = subprocess.run([interpreter, "-I", "-c", snippet, str(path)], capture_output=True, text=True)
            if result.returncode:
                raise SystemExit(f"ERREUR Python 3.11 : {path.name}\n{result.stderr}")
    import tempfile

    with tempfile.TemporaryDirectory() as tmp:
        for cell in notebook["cells"]:
            if cell["cell_type"] == "code":
                cell_file = Path(tmp) / f"{cell['id']}.py"
                cell_file.write_text("".join(cell["source"]), encoding="utf-8")
                result = subprocess.run([interpreter, "-I", "-c", snippet, str(cell_file)], capture_output=True, text=True)
                if result.returncode:
                    raise SystemExit(f"ERREUR Python 3.11 : cellule {cell['id']} de {label}\n{result.stderr}")
    print(f"  {label} : syntaxe Python 3.11 OK ({len(files)} fichiers, {sum(1 for c in notebook['cells'] if c['cell_type'] == 'code')} cellules)")


def main() -> None:
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--check", action="store_true", help="ne rien écrire ; échouer si un carnet n'est pas à jour")
    ap.add_argument("--py311", help="interpréteur Python 3.11 pour vérifier la syntaxe")
    ap.add_argument("--only", choices=sorted(NOTEBOOKS))
    args = ap.parse_args()
    stale = False
    for kind in ([args.only] if args.only else sorted(NOTEBOOKS)):
        if not NOTEBOOKS[kind]["cells"].exists():
            print(f"{kind} : cellules absentes, ignoré")
            continue
        notebook, info = build_notebook(kind)
        check_code_cells(notebook, kind)
        text = json.dumps(notebook, ensure_ascii=False, indent=1) + "\n"
        target = NOTEBOOKS[kind]["file"]
        if args.py311:
            check_py311(args.py311, PAYLOADS[kind], notebook, kind)
        if args.check:
            current = target.read_text(encoding="utf-8") if target.exists() else ""
            if current != text:
                stale = True
                print(f"{kind} : PAS À JOUR ({target.name}) ; relancer build_notebooks.py")
            else:
                print(f"{kind} : à jour (code embarqué {info['payload_sha256'][:12]}, {info['bytes'] / 1024:.0f} Ko)")
            continue
        target.write_text(text, encoding="utf-8", newline="\n")
        meta_path = target.parent / "kernel-metadata.json"
        if not meta_path.exists():
            meta_path.write_text(json.dumps(metadata_for(kind), ensure_ascii=False, indent=2) + "\n", encoding="utf-8", newline="\n")
        print(f"{kind} : {target} ({len(text) / 1024:.0f} Ko ; {len(notebook['cells'])} cellules ; code embarqué {info['payload_sha256'][:12]}, {info['bytes'] / 1024:.0f} Ko)")
    if stale:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
