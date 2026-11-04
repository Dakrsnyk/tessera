"""Appariement des classes MyFoodRepo avec les identifiants d'aliments d'Ardane (table `class_map.csv`).

Les classes MyFoodRepo ont des noms anglais en « slug » (`bread-white`, `tomato-raw`, `salad-leaf-salad-green`) et un
nom lisible (`Bread, white`). Les identifiants d'Ardane sont :
  - `builtin.<id>`  : la table intégrée (`Shared/Domains/FoodDatabase.swift`, noms français) ;
  - `cnf.<Food_Code>` et `usda.<NDB>` : la nouvelle base `App/Resources/ardane-food.sqlite` (schéma d'identifiants lu dans
    sa table `pack_meta`), ou à défaut la FCÉN 2026 brute (mêmes identifiants `cnf.<Food_Code>`) ; l'ancienne FCÉN 2015 de
    `App/Resources/cnf-foods.json` (`cnf.<FoodID>`, identifiants DIFFÉRENTS) seulement en tout dernier recours.

Méthodes, de la plus sûre à la moins sûre (colonne `methode`) :
  1. `exact-en` / `exact-fr`  : le nom normalisé est identique à un nom de la base ;
  2. `synonyme-app`           : le nom est dans les groupes de `FoodSynonyms` (DishTemplates.swift) : l'app sait déjà
                                 chercher cet aliment, on rejoue la même recherche (builtin d'abord, puis FCÉN) ;
  3. `jetons-en`              : recouvrement COMPLET des mots (singularisés) avec les noms anglais de la base, mot de tête
                                 obligatoire ; score plafonné à 0,7 (jamais au-dessus d'une formulation précise de FoodSynonyms) ;
  4. `aucun`                  : rien de crédible : l'identifiant reste vide, les candidats faibles sont listés en alternatives ;
  5. `manuel`                 : ligne corrigée à la main (conservée telle quelle quand on régénère le fichier).

Rien n'est jamais déclaré sûr : la colonne `a_relire` vaut « oui » pour TOUTE ligne automatique (même une identité exacte) ;
seule une ligne corrigée à la main (`manuel`) est validée. Le gabarit d'un plat, l'état cru/cuit, la variante de coupe ne se
devinent pas à partir d'un nom ; `methode` et `score` indiquent seulement à quel point la proposition est plausible.
"""
from __future__ import annotations

import json
import re
import sqlite3
import unicodedata
import zipfile
from dataclasses import dataclass, field
from pathlib import Path

from ml_common import REPO, log, read_csv, write_csv

STOPWORDS = {"de", "du", "des", "la", "le", "les", "au", "aux", "a", "et", "en", "the", "of", "and", "with", "without",
             "in", "or", "sans", "avec", "for", "on"}
FIELDS = ["classe_id", "classe", "classe_lisible", "id_ardane", "nom_ardane", "methode", "score", "a_relire",
          "alternatives", "effectif_train"]


def norm(text: str) -> str:
    text = unicodedata.normalize("NFKD", text.replace("œ", "oe").replace("Œ", "oe")).encode("ascii", "ignore").decode()
    return re.sub(r"[^a-z0-9]+", " ", text.lower()).strip()


def stem(token: str) -> str:
    """Singulier approximatif (anglais et français) : suffisant pour comparer des noms d'aliments."""
    if len(token) > 4 and token.endswith("ies"):
        return token[:-3] + "y"
    if len(token) > 4 and token.endswith(("oes", "ches", "shes", "sses", "xes")):
        return token[:-2]
    if len(token) > 3 and token.endswith(("s", "x")) and not token.endswith("ss"):
        return token[:-1]
    return token


CLASS_TOKEN_REWRITES = {"wholemeal": ["whole", "wheat"], "wholegrain": ["whole", "grain"]}
CLASS_TOKEN_DROPS = {"caffeine"}      # « coffee-with-caffeine » : la caféine n'est pas un mot du nom de l'aliment


def tokens(text: str) -> list[str]:
    return [stem(t) for t in norm(text).split() if t not in STOPWORDS]


def class_tokens_of(name: str) -> list[str]:
    out: list[str] = []
    for t in tokens(name.replace("-", " ")):
        if t in CLASS_TOKEN_DROPS:
            continue
        out += [stem(x) for x in CLASS_TOKEN_REWRITES.get(t, [t])]
    return out


def source_rank(food: "Food") -> int:
    """Égalité de score : la table intégrée d'abord, puis la FCÉN (Québec), puis l'USDA."""
    return {"builtin": 0}.get(food.source, 1 if food.source.startswith(("fcen", "cnf")) else 2)


@dataclass
class Food:
    id: str
    name_fr: str = ""
    name_en: str = ""
    source: str = ""
    extra: list[str] = field(default_factory=list)   # autres noms (alias de l'app)


# --------------------------------------------------------------------------- lecture du catalogue de l'app

def load_builtin(path: Path | None = None) -> list[Food]:
    """Aliments de la table intégrée : `f("apple", tr("Pomme"), ...)` + alias (`aliases`) de FoodDatabase.swift."""
    path = path or REPO / "Shared" / "Domains" / "FoodDatabase.swift"
    text = path.read_text(encoding="utf-8")
    foods: dict[str, Food] = {}
    for m in re.finditer(r'\bf\("(?P<id>[A-Za-z0-9_]+)",\s*(?:tr\()?"(?P<name>[^"]+)"', text):
        foods[m["id"]] = Food(id=f"builtin.{m['id']}", name_fr=m["name"], source="builtin")
    block = re.search(r"private static let aliases: \[String: \[String\]\] = \[(?P<body>.*?)\n    \]", text, re.S)
    if block:
        for m in re.finditer(r'"(?P<key>[A-Za-z0-9_]+)":\s*\[(?P<list>[^\]]*)\]', block["body"]):
            if m["key"] in foods:
                foods[m["key"]].extra += re.findall(r'"([^"]+)"', m["list"])
    return list(foods.values())


def load_synonyms(path: Path | None = None) -> dict[str, list[str]]:
    """`FoodSynonyms.groups` (DishTemplates.swift) : étiquette anglaise normalisée -> recherches françaises, dans l'ordre."""
    path = path or REPO / "Shared" / "Domains" / "DishTemplates.swift"
    text = path.read_text(encoding="utf-8")
    table: dict[str, list[str]] = {}
    for m in re.finditer(r'^\s*\(\[(?P<labels>[^\]]*)\],\s*\[(?P<queries>[^\]]*)\]\),?\s*$', text, re.M):
        queries = re.findall(r'"([^"]+)"', m["queries"])
        for label in re.findall(r'"([^"]+)"', m["labels"]):
            table.setdefault(norm(label.replace("'", "")), queries)
    return table


def load_fcen_zip(path: Path) -> list[Food]:
    import csv
    import io

    with zipfile.ZipFile(path) as z:
        text = z.read("Food_Name.csv").decode("utf-8-sig")
    foods = []
    for row in csv.DictReader(io.StringIO(text)):
        foods.append(Food(id=f"cnf.{row['Food_Code']}", name_fr=row["Food_Description_FR"], name_en=row["Food_Description_EN"],
                          source="fcen2026", extra=[row["Alternate_Description_EN"], row["Alternate_Description_FR"]]))
    return foods


def load_fcen_legacy(path: Path) -> list[Food]:
    rows = json.loads(path.read_text(encoding="utf-8"))
    return [Food(id=f"cnf.{r[0]}", name_fr=r[1], name_en=r[2], source="fcen2015-legacy") for r in rows]


def load_ardane_sqlite(path: Path) -> list[Food] | None:
    """La nouvelle base (`ardane-food.sqlite`), si elle existe et si son schéma est celui construit par scripts/food_db.

    Les identifiants textuels suivent `pack_meta.id_scheme` de la base elle-même (au 2026-11-02 : `cnf.<Food_Code>` pour
    food.id < 100000 et `usda.<NDB>` pour food.id = 100000 + NDB ; la consigne du Chef écrivait `cnf:<Food_Code>` avec deux
    points : la base fait foi, à réconcilier côté app). Si la base change de schéma, on se replie sur la FCÉN 2026 brute.
    """
    if not path.exists():
        return None
    try:
        con = sqlite3.connect(f"file:{path}?mode=ro", uri=True)
        cols = {r[1] for r in con.execute("PRAGMA table_info(food)")}
        if not {"id", "source", "name_en", "name_fr"} <= cols:
            log(f"  (schéma de {path.name} non reconnu : colonnes {sorted(cols)}) ; repli sur la FCÉN 2026 brute")
            return None
        scheme = dict(con.execute("SELECT key, value FROM pack_meta")).get("id_scheme", "")
        sep = ":" if "cnf:" in scheme else "."
        sources = {r[0]: r[1] for r in con.execute("SELECT id, code FROM source")}
        foods = []
        for fid, source, fr, en, alt_fr, alt_en in con.execute("SELECT id, source, name_fr, name_en, alt_fr, alt_en FROM food"):
            code = sources.get(source, str(source))
            if code.startswith("usda"):
                text_id = f"usda{sep}{fid - 100000 if fid >= 100000 else fid}"
            elif code.startswith("fcen"):
                text_id = f"cnf{sep}{fid}"
            else:
                text_id = f"{code}{sep}{fid}"
            foods.append(Food(id=text_id, name_fr=fr or "", name_en=en or "", source=code, extra=[alt_fr or "", alt_en or ""]))
        con.close()
        return foods
    except sqlite3.Error as error:
        log(f"  ({path.name} illisible ou en cours de construction : {error}) ; repli sur la FCÉN 2026 brute")
        return None


def load_catalog(root: Path, fcen_zip: Path | None = None, sqlite_path: Path | None = None) -> tuple[list[Food], str]:
    """Catalogue d'appariement : table intégrée + (nouvelle base | FCÉN 2026 brute | FCÉN 2015 de l'app)."""
    catalog = load_builtin()
    description = f"table intégrée ({len(catalog)})"
    sqlite_path = sqlite_path or REPO / "App" / "Resources" / "ardane-food.sqlite"
    fcen_zip = fcen_zip or root.parent / "food-data" / "fcen2026" / "cnf_fcen_all-files-data_2026.zip"
    new_base = load_ardane_sqlite(sqlite_path)
    if new_base:
        catalog += [f for f in new_base if not f.id.startswith("builtin.")]
        description += f" + ardane-food.sqlite ({len(new_base)})"
    elif fcen_zip.exists():
        fcen = load_fcen_zip(fcen_zip)
        catalog += fcen
        description += f" + FCÉN 2026 brute ({len(fcen)}, identifiants cnf.<Food_Code>)"
    else:
        legacy = REPO / "App" / "Resources" / "cnf-foods.json"
        fcen = load_fcen_legacy(legacy)
        catalog += fcen
        description += f" + FCÉN 2015 de l'app ({len(fcen)}, identifiants cnf.<FoodID> ANCIENS : à rejouer avec la base 2026)"
    return catalog, description


# --------------------------------------------------------------------------- appariement

class Matcher:
    def __init__(self, catalog: list[Food], synonyms: dict[str, list[str]]):
        self.catalog = catalog
        self.synonyms = synonyms
        self.by_id = {f.id: f for f in catalog}
        self.norm_en: dict[str, list[Food]] = {}
        self.norm_fr: dict[str, list[Food]] = {}
        self.index: dict[str, list[int]] = {}    # mot (singularisé) du début du nom anglais -> aliments
        self.fr_words: list[tuple[Food, str, list[str]]] = []
        for i, food in enumerate(catalog):
            if food.name_en:
                self.norm_en.setdefault(norm(food.name_en), []).append(food)
                for tok in set(tokens(food.name_en.split(",")[0])):
                    self.index.setdefault(tok, []).append(i)
            if food.name_fr:
                self.norm_fr.setdefault(norm(food.name_fr), []).append(food)
            self.fr_words.append((food, norm(food.name_fr), norm(food.name_fr).split()))

    # -- variantes de nom d'une classe
    @staticmethod
    def variants(name: str, readable: str) -> list[tuple[str, bool]]:
        """Formulations d'une classe : (texte, réduite). Les formulations « réduites » (qualificatifs retirés par la fin :
        « tomato raw » -> « tomato ») sont moins sûres : elles ne servent que si rien de plus précis n'a été trouvé."""
        out: list[tuple[str, bool]] = []

        def add(text: str, reduced: bool = False) -> None:
            if text and text not in [t for t, _ in out]:
                out.append((text, reduced))

        for source in (readable, name.replace("-", " ")):
            n = norm(source)
            add(n)
            parts = [t for t in n.split() if t not in STOPWORDS]
            if len(parts) >= 2:
                add(" ".join(parts[1:] + parts[:1]))       # « bread white » -> « white bread » (nom + qualificatifs -> qualificatifs + nom)
            add(norm(source.split(",")[0].split("/")[0]))
        slug_parts = [t for t in norm(name.replace("-", " ")).split() if t not in STOPWORDS]
        for keep in range(len(slug_parts) - 1, 0, -1):
            add(" ".join(slug_parts[:keep]), reduced=True)
        return out

    def _app_search(self, query: str) -> list[Food]:
        """Même règle que `FoodDatabase.search` : chaque mot de la requête commence un mot du nom."""
        q = norm(query.replace("'", " "))
        toks = q.split()
        if not toks:
            return []
        ranked = []
        for food, name, words in self.fr_words:
            if not name:
                continue
            if all(any(w.startswith(t) for w in words) for t in toks):
                rank = 0 if name.startswith(q) else 1
                ranked.append((source_rank(food), rank, len(name), food))
        ranked.sort(key=lambda r: r[:3])
        return [r[3] for r in ranked]

    def _tokens_candidates(self, name: str, readable: str) -> list[tuple[float, Food]]:
        class_tokens = class_tokens_of(name)
        if not class_tokens:
            return []
        head = class_tokens[0]
        results = []
        for i in self.index.get(head, []):
            food = self.catalog[i]
            first_segment = tokens(food.name_en.split(",")[0])
            all_tokens = set(tokens(food.name_en))
            cover = sum(1 for t in set(class_tokens) if t in all_tokens) / len(set(class_tokens))
            if cover < 0.5:
                continue
            precision = len(set(class_tokens) & all_tokens) / max(len(all_tokens), 1)
            head_bonus = 1.0 if first_segment and first_segment[0] == head else 0.5
            score = 0.6 * cover + 0.2 * precision + 0.2 * head_bonus
            if cover < 1.0:
                score = min(score, 0.55)       # un mot de la classe manque : jamais retenu seul, seulement proposé en alternative
            results.append((min(score, 0.7), food))
        results.sort(key=lambda r: (-r[0], source_rank(r[1]), len(r[1].name_en), r[1].id))
        return results

    def match(self, name: str, readable: str) -> dict:
        variants = self.variants(name, readable)
        candidates: list[tuple[float, str, Food, str]] = []   # (score, méthode, aliment, détail)
        # 1. identité exacte
        for variant, reduced in variants:
            if reduced:
                continue
            for food in self.norm_en.get(variant, []):
                candidates.append((1.0, "exact-en", food, variant))
            for food in self.norm_fr.get(variant, []):
                candidates.append((1.0, "exact-fr", food, variant))
        # 2. synonymes de l'app (formulation réduite : un cran de moins)
        for variant, reduced in variants:
            queries = self.synonyms.get(variant) or self.synonyms.get(" ".join(stem(t) for t in variant.split()))
            if not queries:
                continue
            for query in queries:
                if query.startswith("id:"):
                    food = self.by_id.get(query[3:])
                    if food:
                        candidates.append((0.75 if reduced else 1.0, "synonyme-app", food, f"{variant} -> {query}"))
                    continue
                found = self._app_search(query)
                if found:
                    food = found[0]
                    base = 0.9 if food.source == "builtin" else 0.8
                    candidates.append((base - (0.15 if reduced else 0.0), "synonyme-app", food, f"{variant} -> « {query} »"))
                    break
        # 3. recouvrement de mots
        for score, food in self._tokens_candidates(name, readable)[:5]:
            candidates.append((score, "jetons-en", food, "mots de tête communs"))

        if not candidates:
            return {"id": "", "nom": "", "methode": "aucun", "score": 0.0, "a_relire": "oui", "alternatives": ""}
        candidates.sort(key=lambda c: (-c[0], source_rank(c[2]), c[2].id))
        best = candidates[0]
        seen = {best[2].id}
        alternatives = []
        for score, method, food, _ in candidates[1:]:
            if food.id not in seen:
                seen.add(food.id)
                alternatives.append(f"{food.id} ({(food.name_fr or food.name_en)[:48]}; {method} {score:.2f})")
            if len(alternatives) == 3:
                break
        accepted = best[0] >= 0.6
        same_exact = sum(1 for c in candidates if c[1] == best[1] and c[0] == 1.0)
        explicit = (best[1] in ("exact-en", "exact-fr") and same_exact == 1) or (best[1] == "synonyme-app" and "id:" in best[3])
        return {
            "id": best[2].id if accepted else "",
            "nom": (best[2].name_fr or best[2].name_en) if accepted else "",
            "methode": best[1] if accepted else "aucun",
            "score": round(best[0], 2),
            "a_relire": "oui",         # une correspondance automatique n'est JAMAIS validée : seule une ligne « manuel » l'est
            "alternatives": " | ".join(alternatives) if accepted else " | ".join(
                [f"{best[2].id} ({(best[2].name_fr or best[2].name_en)[:48]}; {best[1]} {best[0]:.2f})"] + alternatives),
        }


def build_class_map(classes: list[dict], matcher: Matcher, previous: list[dict] | None = None) -> list[dict]:
    """Une ligne par classe. Les lignes `manuel` d'une version précédente sont conservées."""
    manual = {r["classe"]: r for r in (previous or []) if r.get("methode") == "manuel"}      # clé stable : le NOM de la classe
    rows = []
    for cls in classes:
        key = str(cls["class_id"])
        if cls["name"] in manual:
            row = dict(manual[cls["name"]])
            row["classe_id"] = key
            row["effectif_train"] = cls.get("n_train", 0)
            rows.append(row)
            continue
        m = matcher.match(cls["name"], cls.get("name_readable") or "")
        rows.append({
            "classe_id": key, "classe": cls["name"], "classe_lisible": cls.get("name_readable") or "",
            "id_ardane": m["id"], "nom_ardane": m["nom"], "methode": m["methode"], "score": m["score"],
            "a_relire": m["a_relire"], "alternatives": m["alternatives"], "effectif_train": cls.get("n_train", 0),
        })
    return rows


def write_class_map(path: Path, rows: list[dict]) -> None:
    write_csv(path, rows, FIELDS)


def read_class_map(path: Path) -> list[dict]:
    return read_csv(path) if path.exists() else []
