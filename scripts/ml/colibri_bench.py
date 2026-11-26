"""Essai hors app : un modèle de vision local (LFM3-VL-2B servi par colibri) liste-t-il les aliments d'une photo ?

Outil de travail sur le PC pour PRÉ-ÉTIQUETER des photos d'entraînement ; l'IA ne va jamais dans l'app. Aucune photo ni poids
dans le dépôt : tout est passé en arguments. Le serveur (`coli serve --host 127.0.0.1`) doit tourner ; le script refuse tout
autre hôte que 127.0.0.1.

    # Python avec Pillow (venv de colibri), mode isolé :
    python -I colibri_bench.py --foodphotos <Tests/Fixtures/FoodPhotos> \
        --mfr-dir <dossier COCO de test MyFoodRepo> --class-map scripts/ml/class_map.csv \
        --n-mfr 56 --seed 0 --max-side 512 --out resultats.json

Vérité :
- FoodPhotos (`manifest.json`) : `expected` = synonymes de l'aliment principal (un seul suffit) ; `alternatives` = autres
  noms acceptables. Rappel = l'aliment principal est retrouvé ; précision = la proposition est dans expected + alternatives
  (les accessoires non listés comptent comme faux : précision plutôt sous-estimée).
- MyFoodRepo (COCO, banc de test jamais utilisé pour entraîner) : une classe distincte par aliment annoté ; noms anglais
  (`class_map.csv` : classe_lisible) et français d'Ardane (nom_ardane) acceptés.
Appariement NOM seulement (aucune localisation), par mots : un mot en commun (égal, ou préfixe d'au moins 4 lettres) entre la
proposition et un des noms acceptables ; mots vides retirés. Option `--dico` : petit dictionnaire anglais -> français.
Les grammes ne sont pas comparés : ni FoodPhotos ni MyFoodRepo n'ont de vérité en grammes.
"""
from __future__ import annotations

import argparse
import base64
import csv
import io
import json
import random
import re
import time
import unicodedata
import urllib.request
from pathlib import Path

PROMPT = 'Liste les aliments visibles, JSON strict : [{"aliment": "...", "grammes_estimes": n}]'
STOP = {"de", "du", "des", "la", "le", "les", "l", "au", "aux", "et", "a", "en", "sans", "avec", "with", "without", "and",
        "in", "of", "the", "or", "added", "addition", "salt", "sugar", "cooked", "raw", "fresh", "plain", "ajout", "sel",
        "sucre", "cuit", "cru", "frais", "other", "autre", "autres", "food", "aliment"}
# Petit dictionnaire anglais -> français (le modèle répond parfois en anglais ; la vérité FoodPhotos est en français).
DICO = {"apple": "pomme", "egg": "oeuf", "bread": "pain", "rice": "riz", "chicken": "poulet", "fries": "frites",
        "chips": "frites", "strawberry": "fraise", "strawberries": "fraise", "burger": "hamburger", "salad": "salade",
        "soup": "soupe", "fish": "poisson", "salmon": "saumon", "beef": "boeuf", "pork": "porc", "pasta": "pates",
        "noodles": "nouilles", "pancake": "crepe", "pancakes": "crepe", "cake": "gateau", "chocolate": "chocolat",
        "cheese": "fromage", "milk": "lait", "coffee": "cafe", "tea": "the", "potato": "pomme de terre",
        "potatoes": "pomme de terre", "vegetables": "legumes", "vegetable": "legume", "meat": "viande", "cookie": "biscuit",
        "cookies": "biscuit", "yogurt": "yogourt", "cereal": "cereales", "ice": "glace", "pie": "tarte", "tomato": "tomate",
        "lettuce": "laitue", "asparagus": "asperge", "sweet": "douce", "bacon": "bacon", "toast": "pain", "donut": "beigne",
        "doughnut": "beigne", "fruit": "fruit", "fruits": "fruits", "lasagna": "lasagne"}


def norm(s: str) -> str:
    s = unicodedata.normalize("NFKD", s.lower()).replace("œ", "oe").replace("æ", "ae")
    return "".join(c for c in s if not unicodedata.combining(c))


def tokens(s: str, dico: bool = False) -> set[str]:
    out = set()
    for w in re.findall(r"[a-z]+", norm(s)):
        if w in STOP:
            continue
        if dico and w in DICO:
            out.update(re.findall(r"[a-z]+", DICO[w]))
        out.add(w[:-1] if len(w) > 3 and w.endswith(("s", "x")) else w)
    return {w for w in out if len(w) >= 2}


def word_match(a: str, b: str) -> bool:
    return a == b or (min(len(a), len(b)) >= 4 and (a.startswith(b) or b.startswith(a)))


def matches(pred: str, terms: list[str], dico: bool) -> bool:
    p = tokens(pred, dico)
    return any(word_match(x, y) for t in terms for x in p for y in tokens(t))


def parse(text: str) -> list[tuple[str, float | None]] | None:
    """Liste (aliment, grammes) ; None si aucun JSON exploitable."""
    t = re.sub(r"```(?:json)?", "", text).strip()
    i, j = t.find("["), t.rfind("]")
    try:
        data = json.loads(t[i:j + 1])
        out = []
        for e in data:
            name = str(e.get("aliment", "")).strip()
            if name:
                g = e.get("grammes_estimes")
                out.append((name, float(g) if isinstance(g, (int, float)) else None))
        return out
    except (ValueError, AttributeError, TypeError):
        names = re.findall(r'"aliment"\s*:\s*"([^"]+)"', t)
        return [(n, None) for n in names] if names else None


def encode(path: Path, max_side: int) -> str:
    from PIL import Image
    im = Image.open(path).convert("RGB")
    if max(im.size) > max_side:
        im.thumbnail((max_side, max_side))
    buf = io.BytesIO()
    im.save(buf, "JPEG", quality=90)
    return base64.b64encode(buf.getvalue()).decode()


def ask(url: str, model: str, b64: str, max_tokens: int, timeout: int) -> tuple[str, float, dict]:
    body = {"model": model, "temperature": 0, "max_tokens": max_tokens, "enable_thinking": False,
            "messages": [{"role": "user", "content": [
                {"type": "image_url", "image_url": {"url": "data:image/jpeg;base64," + b64}},
                {"type": "text", "text": PROMPT}]}]}
    t0 = time.time()
    req = urllib.request.Request(url + "/chat/completions", json.dumps(body).encode(), {"Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=timeout) as r:
        d = json.loads(r.read())
    return d["choices"][0]["message"]["content"], time.time() - t0, d.get("usage", {})


def wilson(k: int, n: int, z: float = 1.96) -> tuple[float, float]:
    if n == 0:
        return (0.0, 0.0)
    p = k / n
    den = 1 + z * z / n
    c = (p + z * z / (2 * n)) / den
    h = z * ((p * (1 - p) / n + z * z / (4 * n * n)) ** 0.5) / den
    return (c - h, c + h)


def bootstrap(per_photo: list[tuple[int, int]], reps: int = 2000, seed: int = 1) -> tuple[float, float]:
    """IC 95 % d'un rapport sum(a)/sum(b) par rééchantillonnage des PHOTOS (groupé par photo)."""
    rnd = random.Random(seed)
    vals = []
    for _ in range(reps):
        s = [per_photo[rnd.randrange(len(per_photo))] for _ in per_photo]
        den = sum(b for _, b in s)
        if den:
            vals.append(sum(a for a, _ in s) / den)
    vals.sort()
    return vals[int(0.025 * len(vals))], vals[int(0.975 * len(vals)) - 1]


def load_truth(args) -> list[dict]:
    items = []
    if args.foodphotos:
        root = Path(args.foodphotos)
        for e in json.loads((root / "manifest.json").read_text(encoding="utf-8")):
            items.append({"set": "foodphotos", "category": e["category"], "path": root / e["file"], "name": e["file"],
                          "groups": [e["expected"]], "extra": e["alternatives"]})
    if args.mfr_dir:
        root = Path(args.mfr_dir)
        coco = json.loads((root / "_annotations.coco.json").read_text(encoding="utf-8"))
        names = {c["id"]: c["name"] for c in coco["categories"]}
        fr = {}
        with open(args.class_map, encoding="utf-8", newline="") as f:
            for r in csv.DictReader(f):
                fr[r["classe"]] = [x for x in (r["classe_lisible"], r["nom_ardane"]) if x]
        per_img: dict[int, set[int]] = {}
        for a in coco["annotations"]:
            per_img.setdefault(a["image_id"], set()).add(a["category_id"])
        imgs = sorted((i for i in coco["images"] if i["id"] in per_img), key=lambda i: i["id"])
        random.Random(args.seed).shuffle(imgs)
        for im in imgs[:args.n_mfr]:
            groups = [fr.get(names[c], []) + [names[c].replace("-", " ")] for c in sorted(per_img[im["id"]])]
            items.append({"set": "mfr", "category": f"{len(groups)} aliment(s)" if len(groups) < 3 else "3+ aliments",
                          "path": root / im["file_name"], "name": im["file_name"], "groups": groups, "extra": []})
    return items


def score(preds: list[str], it: dict, dico: bool) -> dict:
    found = [any(matches(p, g, dico) for p in preds) for g in it["groups"]]
    ok_preds = [matches(p, [t for g in it["groups"] for t in g] + it["extra"], dico) for p in preds]
    return {"found": found, "pred_ok": ok_preds}


def summarize(rows: list[dict], key: str, dico: bool) -> str:
    out = []
    for label, sel in (("tout", lambda r: True),) + tuple(
            (f"{s}", (lambda s: lambda r: r["set"] == s)(s)) for s in sorted({r["set"] for r in rows})):
        sub = [r for r in rows if sel(r)]
        pp_rec = [(sum(r[key]["found"]), len(r[key]["found"])) for r in sub]
        pp_pre = [(sum(r[key]["pred_ok"]), len(r[key]["pred_ok"])) for r in sub if r[key]["pred_ok"]]
        kr, nr = sum(a for a, _ in pp_rec), sum(b for _, b in pp_rec)
        kp, npr = sum(a for a, _ in pp_pre), sum(b for _, b in pp_pre)
        if not nr or not npr:
            continue
        r_lo, r_hi = bootstrap(pp_rec)
        p_lo, p_hi = bootstrap(pp_pre)
        out.append(f"{label:11s} photos={len(sub):3d}  rappel {kr}/{nr} = {kr / nr:.1%} [IC95 groupé {r_lo:.1%}-{r_hi:.1%}]  "
                   f"précision {kp}/{npr} = {kp / npr:.1%} [IC95 groupé {p_lo:.1%}-{p_hi:.1%}]")
    return "\n".join(out)


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--url", default="http://127.0.0.1:8000/v1")
    ap.add_argument("--model", default="lfm3-vl-2b-colibri")
    ap.add_argument("--foodphotos", help="dossier Tests/Fixtures/FoodPhotos (manifest.json + jpg)")
    ap.add_argument("--mfr-dir", help="dossier COCO de test MyFoodRepo (_annotations.coco.json + jpg)")
    ap.add_argument("--class-map", help="scripts/ml/class_map.csv (noms anglais et français des classes MyFoodRepo)")
    ap.add_argument("--n-mfr", type=int, default=56)
    ap.add_argument("--seed", type=int, default=0)
    ap.add_argument("--max-side", type=int, default=512, help="plus grand côté envoyé (la tour de vision tourne sur le CPU)")
    ap.add_argument("--max-tokens", type=int, default=400)
    ap.add_argument("--timeout", type=int, default=900)
    ap.add_argument("--limit", type=int, default=0, help="seulement les N premières photos (essai)")
    ap.add_argument("--resume", action="store_true", help="reprend les réponses déjà dans --out")
    ap.add_argument("--out", required=True)
    args = ap.parse_args()
    if not args.url.startswith("http://127.0.0.1:"):
        raise SystemExit("hôte refusé : seul 127.0.0.1 est autorisé")
    if args.mfr_dir and not args.class_map:
        raise SystemExit("--class-map requis avec --mfr-dir")

    items = load_truth(args)
    if args.limit:
        items = items[:args.limit]
    out = Path(args.out)
    done = {}
    if args.resume and out.exists():
        done = {(r["set"], r["name"]): r for r in json.loads(out.read_text(encoding="utf-8"))["rows"]}
    rows = []
    for k, it in enumerate(items, 1):
        key = (it["set"], it["name"])
        if key in done:
            rows.append(done[key])
            continue
        text, secs, usage = ask(args.url, args.model, encode(it["path"], args.max_side), args.max_tokens, args.timeout)
        parsed = parse(text)
        preds = list(dict.fromkeys(n for n, _ in (parsed or [])))
        row = {"set": it["set"], "category": it["category"], "name": it["name"], "seconds": round(secs, 2),
               "prompt_tokens": usage.get("prompt_tokens"), "raw": text, "parsed": parsed is not None,
               "preds": preds, "grams": [g for _, g in (parsed or [])], "truth": it["groups"], "extra": it["extra"]}
        row["strict"] = score(preds, it, False)
        row["dico"] = score(preds, it, True)
        rows.append(row)
        print(f"[{k}/{len(items)}] {it['name']} {secs:.1f}s -> {preds}", flush=True)
        out.write_text(json.dumps({"args": vars(args), "rows": rows}, ensure_ascii=False, indent=1), encoding="utf-8")
    out.write_text(json.dumps({"args": vars(args), "rows": rows}, ensure_ascii=False, indent=1), encoding="utf-8")

    secs = sorted(r["seconds"] for r in rows)
    print(f"\nphotos {len(rows)}, JSON non lisible : {sum(not r['parsed'] for r in rows)}, "
          f"secondes/photo médiane {secs[len(secs) // 2]:.1f}, moyenne {sum(secs) / len(secs):.1f}, max {secs[-1]:.1f}")
    for key, lab in (("strict", "appariement par mots"), ("dico", "appariement par mots + dictionnaire EN->FR")):
        print(f"\n== {lab} ==\n{summarize(rows, key, key == 'dico')}")
        cats: dict[str, list[dict]] = {}
        for r in rows:
            cats.setdefault(f"{r['set']}/{r['category']}", []).append(r)
        for c, rs in sorted(cats.items()):
            kr = sum(sum(r[key]["found"]) for r in rs); nr = sum(len(r[key]["found"]) for r in rs)
            print(f"  {c:28s} photos={len(rs):3d} rappel {kr}/{nr} = {kr / nr:.0%}")


if __name__ == "__main__":
    main()
