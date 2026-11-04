"""Conversion Core ML « à blanc » pour une machine SANS les bibliothèques natives de coremltools (Windows).

coremltools ne publie des roues natives que pour Linux et macOS. Sous Windows, tout ce qui est écrit en Python marche
(conversion PyTorch -> programme MIL -> protobuf du modèle), seuls manquent : l'écriture du fichier de poids
(`libmilstoragepython`) et celle du paquet (`libmodelpackage`).

Ce module remplace la première par un écrivain qui ne fait que COMPTER les octets (mêmes en-têtes de 64 octets et même
alignement que le format de poids MIL) et intercepte la seconde juste avant l'écriture du paquet. Résultat :
  - la conversion complète est exécutée (opérations, passes fp16, génération du protobuf) : tout opérateur non
    convertible ou toute erreur de génération se manifeste ici ;
  - la taille du `.mlpackage` est CALCULÉE (protobuf réel + fichier de poids reconstitué + manifeste), à ± quelques ko près.

Ce n'est PAS un `.mlpackage` : aucun fichier chargeable n'est produit. La vraie taille et la parité numérique se
confirment avec `export_coreml.py` sous Linux/WSL et `parity_coreml.py` sous macOS.
"""
from __future__ import annotations

import importlib.util
import sys
import tempfile
import types
from pathlib import Path

ALIGN = 64            # alignement du format de poids MIL
HEADER = 64           # en-tête du fichier et métadonnées de chaque blob
MANIFEST_ESTIMATE = 1024


def natives_present() -> bool:
    """Vrai si les bibliothèques natives de coremltools sont installées (sans importer coremltools)."""
    spec = importlib.util.find_spec("coremltools")
    if spec is None or not spec.submodule_search_locations:
        return False
    folder = Path(next(iter(spec.submodule_search_locations)))
    return any(folder.glob("libmilstoragepython*")) and any(folder.glob("libmodelpackage*"))


class _SizingWriter:
    """Même interface que `_BlobStorageWriter` pour ce que le convertisseur appelle ; écrit réellement les octets."""

    def __init__(self, path):
        self._file = open(path, "wb")
        self._file.write(b"\0" * HEADER)
        self._position = HEADER
        self.blobs = 0
        _SizingWriter.last = self

    def _write(self, array) -> int:
        offset = self._position
        data = array.tobytes()
        padded = (len(data) + ALIGN - 1) // ALIGN * ALIGN
        self._file.write(b"\0" * HEADER)               # métadonnées du blob
        self._file.write(data + b"\0" * (padded - len(data)))
        self._position += HEADER + padded
        self.blobs += 1
        return offset

    def __getattr__(self, name):
        if name.startswith("write_") and name.endswith("_data"):
            return self._write
        raise AttributeError(name)

    def close(self):
        self._file.flush()
        self._file.close()


def install_sizing_shim() -> None:
    """À appeler AVANT `import coremltools`."""
    if "coremltools" in sys.modules:
        raise RuntimeError("install_sizing_shim() doit précéder l'import de coremltools")
    module = types.ModuleType("coremltools.libmilstoragepython")
    module._BlobStorageWriter = _SizingWriter
    sys.modules["coremltools.libmilstoragepython"] = module


class _Captured(Exception):
    pass


def dry_serialize(ct, traced, **convert_kwargs) -> dict:
    """Lance `ct.convert(..., convert_to='mlprogram')` jusqu'à l'écriture du paquet et retourne les tailles calculées."""
    import coremltools.models.model as cmodel

    captured: dict = {}

    def fake_create_mlpackage(proto, weights_dir, package_dir=None):
        if _SizingWriter.last is not None:
            _SizingWriter.last.close()
        weight_file = Path(weights_dir) / "weight.bin"
        captured["proto_bytes"] = len(proto.SerializeToString())
        captured["weight_bin_bytes"] = weight_file.stat().st_size if weight_file.exists() else 0
        captured["blobs"] = _SizingWriter.last.blobs if _SizingWriter.last is not None else 0
        raise _Captured()

    _SizingWriter.last = None
    original = cmodel._create_mlpackage
    cmodel._create_mlpackage = fake_create_mlpackage
    try:
        ct.convert(traced, convert_to="mlprogram", **convert_kwargs)
    except _Captured:
        pass
    finally:
        cmodel._create_mlpackage = original
    if not captured:
        raise RuntimeError("la conversion n'est pas arrivée jusqu'à l'écriture du paquet")
    captured["package_bytes_estimate"] = captured["proto_bytes"] + captured["weight_bin_bytes"] + MANIFEST_ESTIMATE
    return captured
