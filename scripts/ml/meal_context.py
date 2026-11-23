"""Contexte du repas pour le scanner : les aliments d'une même assiette se renseignent les uns les autres (riz -> poulet, steak ->
pommes de terre, pâtes -> sauce), sans jamais inventer un aliment.

Trois commandes :

    # 1. La base d'associations, apprise sur les vrais repas de MyFoodRepo (train officiel, SANS les photos de la validation)
    python scripts/ml/meal_context.py build --train <raw/myfoodrepo/train/annotations.json> --exclude <ds/valid/_annotations.coco.json> \
        --out Tests/Fixtures/MealContext/ArdaneFoodPairs.json
    # (dans App/Resources/Models/ seulement le jour où `eval` montre un vrai gain sur le test : le 2026-11-23, aucun, donc hors de l'app)

    # 2. La mesure avant / après, hors ligne, sur les zones enregistrées par dump_zones.py
    python scripts/ml/meal_context.py eval --pairs Tests/Fixtures/MealContext/ArdaneFoodPairs.json --zones zones-test.json --out rapport.md

    # 3. Le réglage (sur la VALIDATION seulement, jamais sur le test)
    python scripts/ml/meal_context.py sweep --train ... --exclude ... --zones zones-valid.json

La règle est celle de l'app (`Shared/Domains/Scanner/ScannerMealContext.swift`, à garder identique) :
  - score d'association de deux aliments a, b : S(a, b) = ln((n_ab + k) / (E_ab + k)), E_ab = n_a n_b / N (nombre attendu si les deux
    étaient indépendants) ; k (pseudo-compte) tire les paires rares vers 0 : une paire vue trop peu de fois ne dit rien ;
  - pour une zone, chaque aliment proposé PAR LE CLASSIFIEUR (ses 3 premiers, jamais un autre) reçoit le contexte des AUTRES zones :
    s(c) = somme sur les autres zones y de w_y × somme sur leurs aliments d de p_y(d) × S(c, d) (w = 1 zone sûre, `tentative_weight`
    zone « peut-être ») ;
  - p'(c) = p(c) × exp(borne(alpha × s(c), ±cap)), puis remis à l'échelle pour que la zone garde sa probabilité totale ;
  - un aliment ne passe jamais au-dessus du seuil d'ajout automatique (0,80) grâce au contexte seul : sa probabilité visuelle doit déjà
    l'atteindre. Le contexte peut donc réordonner les hypothèses d'une zone et faire baisser une confiance (« À confirmer »), jamais
    ajouter d'office un aliment ni en créer un que l'image ne propose pas.
"""
from __future__ import annotations

import argparse
import csv
import json
import math
import re
import statistics
import sys
from collections import Counter, defaultdict
from pathlib import Path

HERE = Path(__file__).resolve().parent
REPO = HERE.parent.parent
APP_MAP = REPO / "App" / "Resources" / "Models" / "ArdaneFoodClassMap.json"

# Règles de l'app (MealPhotoAnalysis, ScannerModelLogic, ScanRecap).
SURE = 0.30            # ScannerModelLogic.detectionThreshold
TENTATIVE = 0.20       # ScannerModelLogic.tentativeThreshold
FOODS_PER_ZONE = 3     # ScannerModelLogic.foodsPerZone
MIN_CONFIDENCE = 0.15  # FoodLabelMatcher.minimumConfidence
AUTO_ADD = 0.80        # ScanRecap.autoAddThreshold

DEFAULTS = {"k": 5.0, "alpha": 0.5, "cap": 0.7, "tentative_weight": 0.5}


# MARK: - Base d'associations

def read_class_map(path: Path) -> dict[str, dict]:
    with open(path, encoding="utf-8") as f:
        return {r["classe"]: r for r in csv.DictReader(f)}


def key_of_class(rows: dict[str, dict], name: str) -> str:
    row = rows.get(name)
    return (row["id_ardane"] or f"mfr:{name}") if row else f"mfr:{name}"


def counts(train: Path, exclude: list[Path], class_map: Path):
    """Pour chaque photo du train (hors photos exclues) : l'ensemble des aliments d'Ardane présents. Rend N, n[a], n[(a, b)] (a < b)."""
    data = json.loads(train.read_text(encoding="utf-8"))
    skip = set()
    for path in exclude:
        skip |= {i["id"] for i in json.loads(path.read_text(encoding="utf-8"))["images"]}
    rows = read_class_map(class_map)
    name = {c["id"]: c["name"] for c in data["categories"]}
    per_image: dict[int, set[str]] = defaultdict(set)
    for a in data["annotations"]:
        if a["image_id"] not in skip:
            per_image[a["image_id"]].add(key_of_class(rows, name[a["category_id"]]))
    n: Counter = Counter()
    pairs: Counter = Counter()
    for foods in per_image.values():
        ordered = sorted(foods)
        n.update(ordered)
        for i, a in enumerate(ordered):
            for b in ordered[i + 1:]:
                pairs[(a, b)] += 1
    return len(per_image), n, pairs, len(skip)


def pair_scores(N: int, n: Counter, pairs: Counter, keys: list[str], k: float, floor: float = 0.05) -> dict[tuple[str, str], float]:
    """S(a, b) pour toutes les paires de `keys` dont |S| >= floor (a < b). Une paire jamais vue a quand même un score (négatif) quand
    les deux aliments sont assez fréquents pour qu'on s'attende à les voir ensemble."""
    out = {}
    present = [key for key in sorted(keys) if n[key] > 0]
    for i, a in enumerate(present):
        for b in present[i + 1:]:
            expected = n[a] * n[b] / N
            s = math.log((pairs.get((a, b), 0) + k) / (expected + k))
            if abs(s) >= floor:
                out[(a, b)] = round(s, 3)
    return out


def score(table: dict, a: str, b: str) -> float:
    if a == b:
        return 0.0   # deux zones du même aliment ne se renforcent pas (une assiette n'a pas deux « riz » de plus qu'un)
    return table.get((a, b) if a < b else (b, a), 0.0)


# MARK: - Règle de l'app

def rerank(zones: list[dict], table: dict, alpha: float, cap: float, tentative_weight: float, top: int = FOODS_PER_ZONE):
    """Les candidats de chaque zone gardée (score >= TENTATIVE) après le contexte du repas. Rend une liste parallèle à `zones`
    (None pour une zone écartée) de [[clé, p], ...]."""
    kept = [i for i, z in enumerate(zones) if z["score"] >= TENTATIVE]
    cands = {i: [(c[0], c[1]) for c in zones[i]["top"][:top]] for i in kept}
    weight = {i: 1.0 if zones[i]["score"] >= SURE else tentative_weight for i in kept}
    result: list = [None] * len(zones)
    for i in kept:
        others = [j for j in kept if j != i]
        if not others or alpha == 0:
            result[i] = cands[i]
            continue
        mass = sum(p for _, p in cands[i])
        boosted = []
        for key, p in cands[i]:
            s = sum(weight[j] * sum(q * score(table, key, d) for d, q in cands[j]) for j in others)
            boosted.append((key, p, p * math.exp(max(-cap, min(cap, alpha * s)))))
        total = sum(b for _, _, b in boosted)
        if total <= 0 or mass <= 0:
            result[i] = cands[i]
            continue
        out = []
        for key, p, b in boosted:
            q = b / total * mass
            if p < AUTO_ADD <= q:
                q = AUTO_ADD - 0.001   # jamais ajouté d'office par le contexte seul
            out.append((key, q))
        out.sort(key=lambda x: -x[1])   # tri stable : une égalité garde l'ordre du classifieur
        result[i] = out
    return result


def proposal(cands) -> tuple[str, float] | None:
    """Le premier aliment de la table (pas une étiquette `mfr:`) au-dessus du plancher, comme `MealPhotoAnalysis.modelReading`."""
    for key, p in cands or []:
        if p < MIN_CONFIDENCE:
            return None
        if not key.startswith("mfr:"):
            return key, p
    return None


# MARK: - Mesure

def nutrition_table() -> dict[str, tuple[float, float]]:
    """kcal pour 100 g et portion (g) des aliments de l'app : `FoodDatabase.swift` (builtin) et `cnf-foods.json` (cnf)."""
    out = {}
    src = (REPO / "Shared" / "Domains" / "FoodDatabase.swift").read_text(encoding="utf-8")
    number = r"([\d_.]+)"
    for m in re.finditer(r'f\("(\w+)", tr\("[^"]*"\), ' + ", ".join([number] * 6), src):
        values = [float(v.replace("_", "")) for v in m.groups()[1:]]
        out[f"builtin.{m.group(1)}"] = (values[0], values[5])
    for row in json.loads((REPO / "App" / "Resources" / "cnf-foods.json").read_text(encoding="utf-8")):
        if isinstance(row[3], (int, float)):
            serving = row[12] if isinstance(row[12], (int, float)) and row[12] > 0 else 100
            out[f"cnf.{int(row[0])}"] = (float(row[3]), float(serving))
    return out


def names() -> dict[str, str]:
    rows = read_class_map(HERE / "class_map.csv")
    return {key_of_class(rows, c): (r["nom_ardane"] or c) for c, r in rows.items()}


SCENARIOS = {
    # Les familles sont reconnues sur le nom d'Ardane (minuscules) ; un scénario = photos dont la VÉRITÉ contient toutes ses familles.
    "riz": r"\briz\b",
    "poulet": r"poulet|dinde",
    "steak": r"steak|b(oe|œ)uf",
    "pâtes": r"pâtes|nouilles|spaghetti|lasagne",
    "poisson": r"poisson|saumon|morue|thon|truite|crevette",
    "pommes de terre": r"pomme de terre|frites|purée",
    "légumes": r"légume|brocoli|haricots verts|carotte|courgette|épinard|chou|poivron|asperge|petits pois",
    "sauce": r"sauce|bolognaise|pesto|carbonara",
    "viande": r"steak|b(oe|œ)uf|porc|saucisse|poulet|dinde|agneau|veau|jambon|meat",
    "salade": r"salade|laitue|roquette",
}
SCENARIO_SETS = [
    ("Riz et poulet", ["riz", "poulet"]),
    ("Steak et pâtes ou pommes de terre", ["steak", "pâtes|pommes de terre"]),
    ("Poulet, riz et légumes", ["poulet", "riz", "légumes"]),
    ("Poisson et pommes de terre", ["poisson", "pommes de terre"]),
    ("Pâtes avec sauce et viande", ["pâtes", "sauce", "viande"]),
    ("Salades composées (salade + 2 autres aliments)", ["salade"]),
]


def families_of(key: str, label: dict[str, str]) -> set[str]:
    text = (label.get(key, key) + " " + key).lower()
    return {f for f, pattern in SCENARIOS.items() if re.search(pattern, text)}


def in_scenario(truths: list[str], families: list[str], label: dict[str, str]) -> bool:
    present = set().union(*(families_of(t, label) for t in truths)) if truths else set()
    if families == ["salade"]:
        return "salade" in present and len(set(truths)) >= 3
    return all(any(f in present for f in alt.split("|")) for alt in families)


def evaluate(images: list[dict], table: dict, params: dict, nutrition=None, label=None) -> dict:
    """Les mêmes mesures sans contexte (avant) et avec (après)."""
    def run(alpha):
        stats = {"zones": 0, "zone_ok": 0, "zone_ok_sure": 0, "zones_sure": 0, "ambiguous": 0, "ambiguous_ok": 0,
                 "truths": 0, "found_foods": 0, "proposed": 0, "invented": 0, "auto": 0, "auto_wrong": 0, "to_confirm": 0,
                 "kcal_err": [], "kcal_serving_err": [], "per_zone": []}
        for image in images:
            zones = image["zones"]
            cands = rerank(zones, table, alpha, params["cap"], params["tentative_weight"])
            truths = set(image["truths"])
            proposed: dict[str, float] = {}
            for z, c in zip(zones, cands):
                if c is None:
                    continue
                visual = proposal([(x[0], x[1]) for x in z["top"][:FOODS_PER_ZONE]])
                prop = proposal(c)
                if z["truth"] >= 0 and visual is not None:
                    truth = image["truths"][z["truth"]]
                    ok = prop is not None and prop[0] == truth
                    stats["zones"] += 1
                    stats["zone_ok"] += ok
                    stats["per_zone"].append(ok)
                    if z["score"] >= SURE:
                        stats["zones_sure"] += 1
                        stats["zone_ok_sure"] += ok
                    if visual[1] < 0.5:
                        stats["ambiguous"] += 1
                        stats["ambiguous_ok"] += ok
                    if nutrition and prop and prop[0] in nutrition and truth in nutrition:
                        (kp, sp), (kt, st) = nutrition[prop[0]], nutrition[truth]
                        stats["kcal_err"].append(abs(kp - kt))
                        stats["kcal_serving_err"].append(abs(kp * sp - kt * st) / 100)
                if prop and z["score"] >= SURE:
                    proposed[prop[0]] = max(proposed.get(prop[0], 0), prop[1])
            stats["truths"] += len(truths)
            stats["found_foods"] += len(truths & set(proposed))
            stats["proposed"] += len(proposed)
            stats["invented"] += len(set(proposed) - truths)
            for key, p in proposed.items():
                if p >= AUTO_ADD:
                    stats["auto"] += 1
                    stats["auto_wrong"] += key not in truths
                else:
                    stats["to_confirm"] += 1
        return stats

    before, after = run(0.0), run(params["alpha"])
    gained = sum(1 for b, a in zip(before["per_zone"], after["per_zone"]) if a and not b)
    lost = sum(1 for b, a in zip(before["per_zone"], after["per_zone"]) if b and not a)
    return {"before": before, "after": after, "gained": gained, "lost": lost, "mcnemar_p": mcnemar(gained, lost)}


def mcnemar(b: int, c: int) -> float:
    """p exact (binomial bilatéral) du test de McNemar."""
    n = b + c
    if n == 0:
        return 1.0
    k = min(b, c)
    tail = sum(math.comb(n, i) for i in range(k + 1)) / 2 ** n
    return min(1.0, 2 * tail)


def wilson(k: int, n: int) -> tuple[float, float]:
    if n == 0:
        return (0.0, 0.0)
    z = 1.96
    p = k / n
    d = 1 + z * z / n
    c = p + z * z / (2 * n)
    h = z * math.sqrt(p * (1 - p) / n + z * z / (4 * n * n))
    return ((c - h) / d, (c + h) / d)


def bucket(n: int) -> str:
    return "1" if n == 1 else "2" if n == 2 else "3 et plus"


# MARK: - Commandes

def load_zones(path: Path) -> list[dict]:
    return json.loads(path.read_text(encoding="utf-8"))["images"]


def app_keys() -> list[str]:
    m = json.loads(APP_MAP.read_text(encoding="utf-8"))
    return sorted({food or label for label, food in zip(m["labels"], m["foods"])})


def table_from_file(path: Path) -> tuple[dict, dict]:
    data = json.loads(path.read_text(encoding="utf-8"))
    keys = data["keys"]
    table = {}
    for i, j, s in data["pairs"]:
        a, b = keys[i], keys[j]
        table[(a, b) if a < b else (b, a)] = s / 1000
    return table, data["parameters"]


def cmd_build(args) -> None:
    N, n, pairs, skipped = counts(Path(args.train), [Path(p) for p in args.exclude], Path(args.class_map))
    keys = [k for k in app_keys() if n[k] > 0]
    table = pair_scores(N, n, pairs, keys, args.k)
    index = {k: i for i, k in enumerate(keys)}
    out = {
        "about": "Associations entre aliments d'Ardane, apprises sur les repas photographiés de MyFoodRepo (train officiel, sans les "
                 f"{skipped} photos de la validation) : S(a, b) = ln((n_ab + k) / (n_a n_b / N + k)) × 1000, paires |S| >= 0,05. "
                 "Écrit par scripts/ml/meal_context.py build ; lu par MealContextTable (app).",
        "parameters": {"k": args.k, "alpha": args.alpha, "cap": args.cap, "tentative_weight": args.tentative_weight, "photos": N},
        "keys": keys,
        "pairs": sorted([index[a], index[b], int(round(s * 1000))] for (a, b), s in table.items()),
    }
    Path(args.out).write_text(json.dumps(out, ensure_ascii=False, separators=(",", ":")) + "\n", encoding="utf-8")
    print(f"{N} photos, {len(keys)} aliments, {len(table)} paires -> {args.out}")


def cmd_sweep(args) -> None:
    N, n, pairs, _ = counts(Path(args.train), [Path(p) for p in args.exclude], Path(args.class_map))
    keys = [k for k in app_keys() if n[k] > 0]
    images = load_zones(Path(args.zones))
    rows = []
    for k in (2.0, 5.0, 10.0, 20.0):
        table = pair_scores(N, n, pairs, keys, k)
        for alpha in (0.25, 0.5, 1.0, 1.5):
            for cap in (0.5, 0.7, 1.0, 1.5):
                for tw in (0.5, 1.0):
                    r = evaluate(images, table, {"alpha": alpha, "cap": cap, "tentative_weight": tw})
                    a, b = r["after"], r["before"]
                    rows.append((a["zone_ok"] - b["zone_ok"], r["gained"], r["lost"], a["invented"] - b["invented"],
                                 a["auto_wrong"] - b["auto_wrong"], k, alpha, cap, tw))
    rows.sort(key=lambda r: (-r[0], r[2]))
    print("gain net | gagnés | perdus | Δ inventés | Δ ajoutés faux | k | alpha | cap | poids peut-être")
    for r in rows[:25]:
        print(" | ".join(str(x) for x in r))


def cmd_eval(args) -> None:
    table, params = table_from_file(Path(args.pairs))
    for name in ("alpha", "cap", "tentative_weight"):
        if getattr(args, name) is not None:
            params[name] = getattr(args, name)
    images = load_zones(Path(args.zones))
    nutrition = nutrition_table()
    label = names()
    pct = lambda k, n: f"{100 * k / n:.1f} %" if n else "-"  # noqa: E731
    ci = lambda k, n: "[{:.1f} ; {:.1f}]".format(*(100 * x for x in wilson(k, n)))  # noqa: E731
    lines = [f"# Contexte du repas : avant / après ({Path(args.zones).name}, {len(images)} photos)", "",
             f"Paramètres : k = {params['k']}, alpha = {params['alpha']}, borne = ±{params['cap']} (facteur "
             f"{math.exp(-params['cap']):.2f} à {math.exp(params['cap']):.2f}), poids d'une zone « peut-être » = {params['tentative_weight']}.", ""]

    def section(title, subset):
        r = evaluate(subset, table, params, nutrition, label)
        b, a = r["before"], r["after"]
        rows = [
            ("Zones retrouvées bien nommées (1er aliment)", b["zone_ok"], a["zone_ok"], b["zones"]),
            ("… zones sûres (segmenteur >= 0,30)", b["zone_ok_sure"], a["zone_ok_sure"], b["zones_sure"]),
            ("… zones ambiguës (1er aliment visuel < 0,50)", b["ambiguous_ok"], a["ambiguous_ok"], b["ambiguous"]),
            ("Aliments réels proposés (rappel)", b["found_foods"], a["found_foods"], b["truths"]),
        ]
        out = [f"## {title} ({len(subset)} photos)", "", "| Mesure | Avant | Après | Sur |", "|---|---|---|---|"]
        for name, x, y, n in rows:
            out.append(f"| {name} | {pct(x, n)} {ci(x, n)} | {pct(y, n)} {ci(y, n)} | {n} |")
        out.append(f"| Aliments inventés (proposés, absents de l'assiette) | {b['invented']} sur {b['proposed']} | "
                   f"{a['invented']} sur {a['proposed']} | - |")
        out.append(f"| Ajoutés d'office (>= 0,80) faux | {b['auto_wrong']} sur {b['auto']} | {a['auto_wrong']} sur {a['auto']} | - |")
        out.append(f"| À confirmer (< 0,80) | {b['to_confirm']} | {a['to_confirm']} | - |")
        for key, name in (("kcal_err", "Écart de kcal pour 100 g avec l'aliment réel (moyen / médian)"),
                          ("kcal_serving_err", "Écart de kcal d'une portion habituelle (moyen / médian)")):
            if b[key] and a[key]:
                out.append(f"| {name} | {statistics.mean(b[key]):.0f} / {statistics.median(b[key]):.0f} | "
                           f"{statistics.mean(a[key]):.0f} / {statistics.median(a[key]):.0f} | {len(b[key])} zones |")
        out += ["", f"Zones dont le 1er aliment change de juste à faux ou inversement : {r['gained']} gagnées, {r['lost']} perdues "
                    f"(McNemar exact p = {r['mcnemar_p']:.3g}).", ""]
        return out

    lines += section("Toutes les photos", images)
    for b in ("1", "2", "3 et plus"):
        lines += section(f"Photos à {b} aliment(s)", [i for i in images if bucket(len(i["truths"])) == b])
    for title, families in SCENARIO_SETS:
        subset = [i for i in images if in_scenario(i["truths"], families, label)]
        if subset:
            lines += section(f"Scénario : {title}", subset)
    lines.append("Photos suisses annotées (MyFoodRepo) : mesure de la logique, pas la précision d'Ardane sur l'iPhone. Les portions ne "
                 "sont pas mesurables sur ce jeu (aucun poids) : le contexte ne les change que par l'aliment choisi (écart de kcal ci-dessus).")
    text = "\n".join(lines) + "\n"
    if args.out:
        Path(args.out).write_text(text, encoding="utf-8")
    print(text)


def cmd_fixture(args) -> None:
    """Cas de parité pour `ScannerMealContextTests` : des photos réelles à plusieurs zones, leurs 3 aliments par zone et ce que la
    règle Python en fait avec la table de l'app. Les photos dont une zone change de premier aliment passent d'abord."""
    table, params = table_from_file(Path(args.pairs))
    cases_changed, cases_same = [], []
    for image in load_zones(Path(args.zones)):
        zones = [z for z in image["zones"] if z["score"] >= TENTATIVE]
        if len(zones) < 2:
            continue
        zones = [{"score": z["score"], "top": [[k, p] for k, p in z["top"][:FOODS_PER_ZONE]]} for z in zones]
        out = rerank(zones, table, params["alpha"], params["cap"], params["tentative_weight"])
        case = {"zones": [{"tentative": z["score"] < SURE, "candidates": [[k, repr(float(p))] for k, p in z["top"]]} for z in zones],
                "expected": [[[k, repr(float(p))] for k, p in c] for c in out]}
        changed = any(z["top"][0][0] != c[0][0] for z, c in zip(zones, out))
        (cases_changed if changed else cases_same).append(case)
    cases = cases_changed[:args.count // 2] + cases_same[:args.count - min(len(cases_changed), args.count // 2)]
    Path(args.out).parent.mkdir(parents=True, exist_ok=True)
    Path(args.out).write_text(json.dumps({"about": "Écrit par scripts/ml/meal_context.py fixture ; lu par ScannerMealContextTests.",
                                          "cases": cases}, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
    print(f"{len(cases)} cas ({min(len(cases_changed), args.count // 2)} réordonnés) -> {args.out}")


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    sub = ap.add_subparsers(dest="cmd", required=True)
    for name in ("build", "sweep"):
        p = sub.add_parser(name)
        p.add_argument("--train", required=True)
        p.add_argument("--exclude", nargs="*", default=[])
        p.add_argument("--class-map", default=str(HERE / "class_map.csv"))
        if name == "build":
            p.add_argument("--out", required=True)
            for k, v in DEFAULTS.items():
                p.add_argument(f"--{k.replace('_', '-')}", type=float, default=v)
        else:
            p.add_argument("--zones", required=True)
    p = sub.add_parser("eval")
    p.add_argument("--pairs", required=True)
    p.add_argument("--zones", required=True)
    p.add_argument("--out")
    for k in ("alpha", "cap", "tentative_weight"):
        p.add_argument(f"--{k.replace('_', '-')}", type=float)
    p = sub.add_parser("fixture")
    p.add_argument("--pairs", required=True)
    p.add_argument("--zones", required=True)
    p.add_argument("--count", type=int, default=40)
    p.add_argument("--out", default=str(REPO / "Tests" / "Fixtures" / "MealContext" / "parity.json"))
    args = ap.parse_args()
    {"build": cmd_build, "sweep": cmd_sweep, "eval": cmd_eval, "fixture": cmd_fixture}[args.cmd](args)


if __name__ == "__main__":
    sys.exit(main())
