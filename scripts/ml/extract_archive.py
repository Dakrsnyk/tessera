"""Extraction SÛRE d'une archive zip de données (non fiable) vers la mise en page attendue par prepare_myfoodrepo.py.

Bibliothèque standard uniquement (à lancer avec `python -I` : aucun import du dossier courant) :
  - l'empreinte SHA-256 de l'archive est vérifiée AVANT toute extraction (--sha256) ;
  - tout chemin absolu, avec lecteur (`C:`), contenant `..` ou une barre oblique inverse, ou tout lien symbolique, fait REFUSER l'archive entière ;
  - seuls les préfixes demandés par --map sont extraits (--skip liste ce qu'on laisse de côté, ex. un jeu de test sans annotations) ;
  - chaque fichier est relu et son CRC contrôlé ; la destination est vérifiée comme étant DANS le dossier de sortie ;
  - reprise : un fichier déjà extrait avec la même taille est conservé.

    python -I extract_archive.py --zip archive.zip --out raw/myfoodrepo --sha256 <empreinte> \\
        --map public_training_set_release_2.0=train --map public_validation_set_2.0=val --skip public_test_release_2.0
"""
from __future__ import annotations

import argparse
import hashlib
import json
import stat
import sys
import time
import zipfile
from pathlib import Path, PurePosixPath


def sha256_of(path: Path) -> str:
    h = hashlib.sha256()
    with open(path, "rb") as f:
        while block := f.read(1 << 22):
            h.update(block)
    return h.hexdigest()


def main() -> None:
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--zip", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--sha256", help="empreinte attendue de l'archive")
    ap.add_argument("--map", action="append", default=[], help="dossier_dans_l_archive=sous-dossier_de_sortie (répétable)")
    ap.add_argument("--skip", action="append", default=[], help="dossier de l'archive à ne pas extraire (répétable)")
    args = ap.parse_args()

    archive, out = Path(args.zip), Path(args.out)
    mapping = dict(item.split("=", 1) for item in args.map)
    if not mapping:
        raise SystemExit("ERREUR : au moins un --map est nécessaire")
    t0 = time.time()
    digest = sha256_of(archive)
    print(f"SHA-256 de l'archive : {digest} ({archive.stat().st_size} octets, {time.time() - t0:.0f} s)")
    if args.sha256 and digest != args.sha256.lower():
        raise SystemExit(f"ERREUR : empreinte attendue {args.sha256}, obtenue {digest} : archive refusée")

    out.mkdir(parents=True, exist_ok=True)
    root = out.resolve()
    with zipfile.ZipFile(archive) as z:
        infos = z.infolist()
        # 1. contrôle de TOUS les chemins avant d'écrire quoi que ce soit
        for info in infos:
            name = info.filename
            parts = PurePosixPath(name).parts
            if (name.startswith(("/", "\\")) or "\\" in name or ":" in name or ".." in parts
                    or stat.S_ISLNK(info.external_attr >> 16) or "\x00" in name):
                raise SystemExit(f"ERREUR : chemin ou entrée suspects dans l'archive : {name!r} : archive refusée")
        # 2. extraction
        extracted = skipped = resumed = 0
        total_bytes = 0
        per_target: dict[str, int] = {}
        unknown: set[str] = set()
        for index, info in enumerate(infos, 1):
            if info.is_dir():
                continue
            parts = PurePosixPath(info.filename).parts
            top = parts[0] if parts else ""
            if top in args.skip:
                skipped += 1
                continue
            if top not in mapping:
                unknown.add(top)
                skipped += 1
                continue
            destination = out / mapping[top] / PurePosixPath(*parts[1:])
            if root not in destination.resolve().parents:
                raise SystemExit(f"ERREUR : {info.filename!r} sortirait du dossier de sortie")
            if destination.exists() and destination.stat().st_size == info.file_size:
                resumed += 1
                continue
            destination.parent.mkdir(parents=True, exist_ok=True)
            with z.open(info) as source, open(destination, "wb") as target:
                while block := source.read(1 << 20):       # le CRC est vérifié à la fin de la lecture
                    target.write(block)
            extracted += 1
            total_bytes += info.file_size
            per_target[mapping[top]] = per_target.get(mapping[top], 0) + 1
            if index % 5000 == 0:
                print(f"  {index}/{len(infos)} entrées")
    report = {"archive": str(archive), "sha256": digest, "bytes": archive.stat().st_size, "entries": len(infos),
              "extracted": extracted, "already_present": resumed, "skipped": skipped, "extracted_bytes": total_bytes,
              "per_target": per_target, "not_in_map_or_skipped_prefixes": sorted(unknown | set(args.skip)),
              "seconds": round(time.time() - t0, 1)}
    (out / "extraction.json").write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(report, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
