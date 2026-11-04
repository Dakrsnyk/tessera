"""Photos LIBRES DE DROITS de plats québécois pour entraîner et tester le classifieur (chantier 22.3, décision du 2026-11-04).

Sources : Openverse (Flickr, Wikimedia...) et Wikimedia Commons (catégories). Licences gardées : CC0, marque du domaine public, CC BY
(toutes versions). Jamais CC BY-SA, NC ou ND. Chaque photo garde son auteur, sa licence et sa page d'origine dans `attributions.csv`
(obligation CC BY : créditer). Les photos NE vont PAS dans le dépôt : elles vivent sous `<ARDANE_ML_ROOT>/raw/quebec/`.

    python -I scripts/ml/collect_openverse.py            # télécharge (reprend là où il s'est arrêté)
    python -I scripts/ml/collect_openverse.py --sheets   # planches de contrôle numérotées pour la relecture visuelle

Les fichiers téléchargés sont des données NON FIABLES : ils sont seulement décodés par Pillow (taille plafonnée), jamais exécutés.
"""
from __future__ import annotations

import argparse
import csv
import hashlib
import io
import json
import os
import time
import urllib.parse
import urllib.request
from pathlib import Path

ROOT = Path(os.environ.get("ARDANE_ML_ROOT", r"C:\Users\Etudiant\ardane-tools\ml"))
OUT = ROOT / "raw" / "quebec"
UA = "ArdaneFoodDataset/1.0 (training data collection; contact via GitHub Dakrsnyk)"

# classe -> (aliment Ardane, requêtes Openverse, catégories Commons)
CLASSES = {
    "poutine": ("poutine", ["poutine", "poutine quebec", "poutine fries gravy cheese curds", "poutine montreal", "classic poutine",
                            "poutine dish", "smoked meat poutine", "poutine restaurant", "poutine frites", "poutine plate"], ["Poutine"]),
    "pate-chinois": ("shepherd", ["pâté chinois", "pate chinois", "shepherd's pie", "shepherds pie", "cottage pie"],
                     ["Pâté chinois", "Shepherd's pie", "Cottage pie"]),
    "tourtiere": ("tourtiere", ["tourtière", "tourtiere", "tourtiere quebec", "pâté à la viande", "meat pie slice", "meat pie",
                                "tourtière québécoise", "tourtiere pie", "french canadian meat pie", "christmas tourtiere",
                                "pork pie quebec", "tourtiere slice", "homemade meat pie", "minced meat pie"],
                  ["Tourtière", "Meat pies"]),
}
KEEP_LICENSES = {"cc0", "pdm", "by"}
MAX_SIDE = 896
MAX_PIXELS = 60_000_000


def http_get(url: str, timeout: int = 40) -> bytes:
    req = urllib.request.Request(url, headers={"User-Agent": UA})
    with urllib.request.urlopen(req, timeout=timeout) as r:
        if r.status != 200:
            raise RuntimeError(f"HTTP {r.status}")
        return r.read(25_000_000)


def openverse(query: str, pages: int) -> list[dict]:
    found = []
    for page in range(1, pages + 1):
        qs = urllib.parse.urlencode({"q": query, "license": "cc0,by,pdm", "page_size": 20, "page": page, "mature": "false"})
        data = None
        for attempt in range(4):                       # l'API anonyme répond parfois 500 : on réessaie, en ralentissant
            try:
                data = json.loads(http_get(f"https://api.openverse.org/v1/images/?{qs}"))
                break
            except Exception as e:
                print(f"  openverse {query!r} page {page} essai {attempt + 1}: {e}")
                time.sleep(5 * (attempt + 1))
        if data is None:
            break
        for r in data.get("results", []):
            lic = (r.get("license") or "").lower()
            if lic not in KEEP_LICENSES:
                continue
            # Vignette servie par l'API officielle d'Openverse (600 px) : les serveurs d'images d'origine (Flickr) refusent les clients
            # automatiques ; on ne contourne pas ce refus.
            found.append({"key": f"ov-{r['id']}", "url": f"https://api.openverse.org/v1/images/{r['id']}/thumb/", "title": r.get("title") or "", "creator": r.get("creator") or "",
                          "creator_url": r.get("creator_url") or "", "license": lic, "license_version": r.get("license_version") or "",
                          "license_url": r.get("license_url") or "", "landing": r.get("foreign_landing_url") or "",
                          "source": r.get("source") or "", "query": query})
        if page >= int(data.get("page_count") or 0):
            break
        time.sleep(1.5)
    return found


def commons_license(short: str) -> tuple[str, str] | None:
    s = short.strip().lower()
    if s in ("cc0", "cc-zero", "cc0 1.0"):
        return "cc0", "1.0"
    if s.startswith("public domain") or s == "pd":
        return "pdm", "1.0"
    if s.startswith("cc by ") and "sa" not in s and "nc" not in s and "nd" not in s:
        return "by", s.split()[-1]
    return None


def commons(category: str) -> list[dict]:
    found, cont = [], None
    while True:
        params = {"action": "query", "format": "json", "generator": "categorymembers", "gcmtitle": f"Category:{category}",
                  "gcmtype": "file", "gcmlimit": "50", "prop": "imageinfo", "iiprop": "url|extmetadata", "iiurlwidth": str(MAX_SIDE)}
        if cont:
            params.update(cont)
        try:
            data = json.loads(http_get("https://commons.wikimedia.org/w/api.php?" + urllib.parse.urlencode(params)))
        except Exception as e:
            print(f"  commons {category!r}: {e}")
            break
        for page in (data.get("query", {}).get("pages") or {}).values():
            info = (page.get("imageinfo") or [{}])[0]
            meta = info.get("extmetadata") or {}
            lic = commons_license((meta.get("LicenseShortName") or {}).get("value", ""))
            if not lic:
                continue
            artist = (meta.get("Artist") or {}).get("value", "")
            found.append({"key": f"wc-{page['pageid']}", "url": info.get("thumburl") or info.get("url"), "title": page.get("title", ""),
                          "creator": strip_html(artist), "creator_url": "", "license": lic[0], "license_version": lic[1],
                          "license_url": (meta.get("LicenseUrl") or {}).get("value", ""), "landing": info.get("descriptionurl", ""),
                          "source": "wikimedia_commons", "query": f"Category:{category}"})
        cont = data.get("continue")
        if not cont:
            break
        time.sleep(1.0)
    return found


def strip_html(s: str) -> str:
    import re
    return re.sub(r"<[^>]+>", "", s).strip()[:200]


def dhash(img) -> int:
    g = img.convert("L").resize((9, 8))
    px = list(g.tobytes())
    return sum(1 << i for i in range(64) if px[(i // 8) * 9 + i % 8] > px[(i // 8) * 9 + i % 8 + 1])


def save_image(raw: bytes, dest: Path):
    from PIL import Image
    Image.MAX_IMAGE_PIXELS = MAX_PIXELS
    with Image.open(io.BytesIO(raw)) as im:
        im.load()
        im = im.convert("RGB")
        if min(im.size) < 200:
            raise ValueError(f"trop petite {im.size}")
        im.thumbnail((MAX_SIDE, MAX_SIDE))
        im.save(dest, "JPEG", quality=92)
        return dhash(im), im.size


FIELDS = ["class", "food_id", "file", "split", "keep", "title", "creator", "creator_url", "license", "license_version", "license_url",
          "landing", "source", "query", "dhash", "width", "height"]


def collect(only: list[str] | None = None):
    OUT.mkdir(parents=True, exist_ok=True)
    index_path = OUT / "attributions.csv"
    rows = {}
    if index_path.exists():
        with index_path.open(encoding="utf-8") as f:
            rows = {r["file"]: r for r in csv.DictReader(f)}
    hashes = {int(r["dhash"]): r["file"] for r in rows.values() if r.get("dhash")}
    for cls, (food_id, queries, cats) in CLASSES.items():
        if only and cls not in only:
            continue
        (OUT / cls).mkdir(exist_ok=True)
        cands = []
        for q in queries:
            cands += openverse(q, pages=12)
            time.sleep(1.5)
        for c in cats:
            cands += commons(c)
        seen = set()
        print(f"{cls}: {len(cands)} candidats")
        for c in cands:
            if not c["url"] or c["key"] in seen:
                continue
            seen.add(c["key"])
            name = f"{cls}/{c['key']}.jpg"
            if name in rows:
                continue
            dest = OUT / name
            try:
                h, size = save_image(http_get(c["url"]), dest)
            except Exception as e:
                print(f"  {c['key']}: ignorée ({str(e)[:80]})")
                continue
            dup = next((f for hh, f in hashes.items() if bin(hh ^ h).count("1") <= 4), None)
            if dup:
                dest.unlink(missing_ok=True)
                print(f"  {c['key']}: doublon de {dup}")
                continue
            hashes[h] = name
            rows[name] = {**{k: c.get(k, "") for k in FIELDS}, "class": cls, "food_id": food_id, "file": name, "split": "",
                          "keep": "", "dhash": str(h), "width": size[0], "height": size[1]}
            time.sleep(0.3)
        with index_path.open("w", encoding="utf-8", newline="") as f:
            w = csv.DictWriter(f, fieldnames=FIELDS)
            w.writeheader()
            w.writerows(rows.values())
        print(f"{cls}: {sum(1 for r in rows.values() if r['class'] == cls)} photos gardées")


def sheets(per_sheet: int = 48, cell: int = 150, unreviewed: bool = False):
    """Planches numérotées (6 x 8) pour la relecture : le numéro = rang dans attributions.csv pour la classe.
    `unreviewed` : seulement les photos pas encore relues (colonne keep vide), avec leur numéro d'origine."""
    from PIL import Image, ImageDraw
    with (OUT / "attributions.csv").open(encoding="utf-8") as f:
        rows = list(csv.DictReader(f))
    out = OUT / "_sheets"
    out.mkdir(exist_ok=True)
    for old in out.glob("*.jpg"):
        old.unlink()
    for cls in CLASSES:
        items = [(i, r) for i, r in enumerate(r for r in rows if r["class"] == cls)]
        if unreviewed:
            items = [(i, r) for i, r in items if not r.get("keep", "").strip()]
        for s in range(0, len(items), per_sheet):
            chunk = items[s:s + per_sheet]
            sheet = Image.new("RGB", (8 * cell, 6 * cell), "white")
            d = ImageDraw.Draw(sheet)
            for i, (number, r) in enumerate(chunk):
                with Image.open(OUT / r["file"]) as im:
                    im = im.convert("RGB")
                    im.thumbnail((cell - 4, cell - 4))
                    x, y = (i % 8) * cell, (i // 8) * cell
                    sheet.paste(im, (x + 2, y + 2))
                    d.rectangle([x + 2, y + 2, x + 34, y + 20], fill="black")
                    d.text((x + 5, y + 5), str(number), fill="yellow")
            sheet.save(out / f"{cls}_{s // per_sheet:02d}.jpg", quality=80)
    print(f"planches dans {out}")


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--sheets", action="store_true")
    ap.add_argument("--classes", nargs="*", help="classes à collecter (défaut : toutes)")
    ap.add_argument("--unreviewed", action="store_true", help="planches : seulement les photos pas encore relues")
    a = ap.parse_args()
    sheets(unreviewed=a.unreviewed) if a.sheets else collect(a.classes)
