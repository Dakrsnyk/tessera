#!/usr/bin/env python3
"""Bibliothèque des styles du Studio (onglet « Style ») : source JSON -> Swift.

Source : scripts/styles/library/*.json (une famille par fichier, liste d'objets ; ordre des fichiers = ordre de la grille).
  python3 scripts/styles/library.py check   # validité, contraste, règle de différence (>= 3 axes sur 7 entre deux styles)
  python3 scripts/styles/library.py gen     # écrit Shared/Model/StyleLibraryData.swift (généré, ne pas éditer)
  python3 scripts/styles/library.py stats   # répartition par axe

Schéma d'un style (clés de StyleOptions telles quelles, plus quelques clés propres) :
  id, name, summary (français, une ligne), theme (ThemeID de base : light | dark | minimal ; un autre thème seulement
  avec "classic": true, pour reprendre un thème existant tel quel), accent (HEX), bg ({"kind": "color", "hex"} |
  {"kind": "gradient", "from", "to", "dir", "intensity"?} | {"kind": "glass"} | {"kind": "theme"}),
  font (theme | standard | rounded | serif | mono), fontName (nom PostScript de FontCatalog ou absent),
  textHex, secondaryHex (obligatoires sauf classic), et toute autre propriété de StyleOptions.
"""
import json, math, re, sys, glob, os, itertools

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SRC = os.path.join(ROOT, "scripts", "styles", "library")
OUT = os.path.join(ROOT, "Shared", "Model", "StyleLibraryData.swift")
STYLE = os.path.join(ROOT, "Shared", "Model", "WidgetStyle.swift")
THEME = os.path.join(ROOT, "Shared", "Theme", "Theme.swift")
FONTS = os.path.join(ROOT, "Shared", "Model", "FontCatalog.swift")

# Cas ajoutés au moteur pendant la nuit du 2026-11-26 (acceptés même avant d'être dans WidgetStyle.swift).
PLANNED = {
    "TextureKind": {"guilloche", "marble", "terrazzo", "linen", "topo", "brushed", "sunburst"},
    "BorderKind": {"ticket", "stitched", "bevel", "inset"},
    "DepthKind": {"longShadow"},
    "TitleCase": {"smallCaps"},
}

ENUM_FIELDS = {
    "texture": "TextureKind", "border": "BorderKind", "depth": "DepthKind", "shape": "ShapeKind",
    "numberWeight": "WeightChoice", "titleWeight": "WeightChoice", "titleCase": "TitleCase",
    "iconStyle": "IconStyle", "iconFamily": "IconFamily", "iconPosition": "IconPosition",
    "layout": "LayoutKind", "chart": "ChartKind", "density": "Density",
}
HEX_FIELDS = {"textHex", "secondaryHex", "numberHex", "iconHex", "chartHex", "positiveHex", "negativeHex", "panelHex",
              "borderHex", "shadowHex"}
NUM_FIELDS = {"textureOpacity", "veil", "borderWidth", "borderOpacity", "shadowRadius", "shadowOpacity", "shadowOffset",
              "valueScale", "titleScale", "textScale", "tracking", "iconScale", "chartThickness"}
BOOL_FIELDS = {"monospacedNumbers", "chartFill", "chartValues", "recolor"}
OWN = {"id", "name", "summary", "theme", "accent", "bg", "font", "fontName", "classic", "seriesHexes", "note"}
FONT_CHOICES = {"theme", "standard", "rounded", "serif", "mono"}
DIRS = {"down", "diagonal", "across", "up", "radial"}
PLAIN_BASES = {"light", "dark", "minimal"}


def enum_cases(path, name):
    text = open(path, encoding="utf-8").read()
    m = re.search(r"enum %s\b[^{]*\{(.*?)\n\}" % name, text, re.S)
    cases = set()
    if m:
        for line in m.group(1).split("\n"):
            line = line.strip()
            if line.startswith("case ") and "(" not in line.split("//")[0] and ":" not in line.split("//")[0]:
                for c in line[5:].split("//")[0].split(","):
                    c = c.strip()
                    if c:
                        cases.add(c)
    return cases


def load_enums():
    enums = {n: enum_cases(STYLE, n) | PLANNED.get(n, set()) for n in set(ENUM_FIELDS.values())}
    enums["ThemeID"] = enum_cases(THEME, "ThemeID")
    return enums


def load_fonts():
    text = open(FONTS, encoding="utf-8").read()
    return set(re.findall(r'FontEntry\("[^"]*",\s*"([^"]+)"', text)) | set(re.findall(r'bold:\s*"([^"]+)"', text))


def load():
    styles = []
    for path in sorted(glob.glob(os.path.join(SRC, "*.json"))):
        family = os.path.basename(path)[:-5].split("-", 1)[-1]
        for item in json.load(open(path, encoding="utf-8")):
            item["_family"] = family
            item["_file"] = os.path.basename(path)
            styles.append(item)
    return styles


def lum(hexs):
    hexs = hexs.lstrip("#")
    rgb = [int(hexs[i:i + 2], 16) / 255 for i in (0, 2, 4)]
    lin = [c / 12.92 if c <= 0.03928 else ((c + 0.055) / 1.055) ** 2.4 for c in rgb]
    return 0.2126 * lin[0] + 0.7152 * lin[1] + 0.0722 * lin[2]


def contrast(a, b):
    la, lb = lum(a), lum(b)
    return (max(la, lb) + 0.05) / (min(la, lb) + 0.05)


def bg_stops(s):
    bg = s.get("bg", {"kind": "theme"})
    if bg["kind"] == "color":
        return [bg["hex"]]
    if bg["kind"] == "gradient":
        return [bg["from"], bg["to"]]
    return []


def axes(s):
    bg = s.get("bg", {"kind": "theme"})
    kind = bg["kind"]
    if kind == "color":
        kind = "light" if lum(bg["hex"]) > 0.4 else "dark"
    elif kind == "theme":
        kind = "theme:" + s.get("theme", "")
    return (
        (kind, s.get("texture", "none")),
        s.get("fontName") or s.get("font", "theme"),
        s.get("layout", "auto"),
        s.get("border", "none"),
        s.get("depth", "none"),
        s.get("shape", "theme"),
        (s.get("titleCase", "theme"), round(float(s.get("tracking", 0))), s.get("numberWeight"), s.get("titleWeight")),
    )


AXIS_NAMES = ["fond+texture", "police", "disposition", "bordure", "relief", "forme", "libellés"]


def check(verbose=True):
    enums, fonts, styles = load_enums(), load_fonts(), load()
    errors, warnings = [], []
    ids, names = {}, {}
    for s in styles:
        where = "%s:%s" % (s["_file"], s.get("id"))
        for key in ("id", "name", "summary", "theme"):
            if not s.get(key):
                errors.append("%s : %s manquant" % (where, key))
        if not re.fullmatch(r"[a-z0-9]+(-[a-z0-9]+)*", s.get("id", "")):
            errors.append("%s : id en kebab-case attendu" % where)
        if s.get("id") in ids:
            errors.append("%s : id déjà pris par %s" % (where, ids[s["id"]]))
        ids[s.get("id")] = where
        if s.get("name", "").lower() in names:
            errors.append("%s : nom « %s » déjà pris par %s" % (where, s.get("name"), names[s["name"].lower()]))
        names[s.get("name", "").lower()] = where
        if len(s.get("summary", "")) > 46:
            warnings.append("%s : accroche longue (%d car.)" % (where, len(s["summary"])))
        if len(s.get("name", "")) > 18:
            warnings.append("%s : nom long (%d car.)" % (where, len(s["name"])))
        if s.get("theme") not in enums["ThemeID"]:
            errors.append("%s : thème inconnu %s" % (where, s.get("theme")))
        elif not s.get("classic") and s.get("theme") not in PLAIN_BASES:
            errors.append("%s : base %s interdite sans classic (light | dark | minimal)" % (where, s.get("theme")))
        for key, value in s.items():
            if key.startswith("_") or key in OWN:
                continue
            if key in ENUM_FIELDS:
                if value not in enums[ENUM_FIELDS[key]]:
                    errors.append("%s : %s=%s inconnu (%s)" % (where, key, value, ENUM_FIELDS[key]))
            elif key in HEX_FIELDS:
                if not re.fullmatch(r"[0-9A-Fa-f]{6}", str(value)):
                    errors.append("%s : %s n'est pas un HEX" % (where, key))
            elif key in NUM_FIELDS:
                if not isinstance(value, (int, float)):
                    errors.append("%s : %s n'est pas un nombre" % (where, key))
            elif key in BOOL_FIELDS:
                if not isinstance(value, bool):
                    errors.append("%s : %s n'est pas un booléen" % (where, key))
            else:
                errors.append("%s : clé inconnue %s" % (where, key))
        if s.get("accent") and not re.fullmatch(r"[0-9A-Fa-f]{6}", s["accent"]):
            errors.append("%s : accent n'est pas un HEX" % where)
        if s.get("font", "theme") not in FONT_CHOICES:
            errors.append("%s : font inconnue" % where)
        if s.get("fontName") and s["fontName"] not in fonts:
            errors.append("%s : fontName %s absente de FontCatalog" % (where, s["fontName"]))
        bg = s.get("bg", {"kind": "theme"})
        if bg.get("kind") not in ("color", "gradient", "glass", "theme"):
            errors.append("%s : bg.kind inconnu" % where)
        if bg.get("kind") == "gradient" and bg.get("dir", "diagonal") not in DIRS:
            errors.append("%s : bg.dir inconnu" % where)
        if not s.get("classic"):
            for key in ("textHex", "secondaryHex", "layout", "shape", "titleCase"):
                if key not in s:
                    errors.append("%s : %s obligatoire" % (where, key))
            if s.get("layout") == "auto" or s.get("shape") == "theme" or s.get("titleCase") == "theme":
                errors.append("%s : layout/shape/titleCase doivent être explicites" % where)
        try:
            for stop in bg_stops(s):
                if s.get("textHex") and contrast(s["textHex"], stop) < 4.5:
                    errors.append("%s : contraste texte %.1f:1 < 4,5 sur %s" % (where, contrast(s["textHex"], stop), stop))
                if s.get("secondaryHex") and contrast(s["secondaryHex"], stop) < 3.0:
                    errors.append("%s : contraste secondaire %.1f:1 < 3 sur %s" % (where, contrast(s["secondaryHex"], stop), stop))
                if s.get("numberHex") and contrast(s["numberHex"], stop) < 3.0:
                    errors.append("%s : contraste chiffre %.1f:1 < 3 sur %s" % (where, contrast(s["numberHex"], stop), stop))
        except (ValueError, KeyError) as error:
            errors.append("%s : couleur illisible (%s)" % (where, error))
    # Règle de différence : au moins 3 axes sur 7 entre chaque paire.
    close = []
    vectors = [(s, axes(s)) for s in styles if s.get("id")]
    for (a, va), (b, vb) in itertools.combinations(vectors, 2):
        diff = sum(1 for x, y in zip(va, vb) if x != y)
        if diff < 3:
            same = [AXIS_NAMES[i] for i, (x, y) in enumerate(zip(va, vb)) if x == y]
            close.append("%s ~ %s (%d axes différents ; mêmes : %s)" % (a["id"], b["id"], diff, ", ".join(same)))
    errors += ["trop proches : " + c for c in close]
    if verbose:
        for w in warnings:
            print("avertissement :", w)
        for e in errors:
            print("ERREUR :", e)
        print("%d styles, %d erreurs, %d avertissements" % (len(styles), len(errors), len(warnings)))
    return styles, errors


def swift_str(value):
    return '"' + value.replace("\\", "\\\\").replace('"', '\\"') + '"'


def tr(value):
    # Le catalogue de traductions prend le texte français comme clé ; % littéral doublé.
    return "tr(%s)" % swift_str(value.replace("%", "%%"))


def gen():
    styles, errors = check(verbose=False)
    if errors:
        print("\n".join(errors[:40]))
        sys.exit("gen refusé : %d erreurs (lancer check)" % len(errors))
    families = []
    for s in styles:
        if not families or families[-1][0] != s["_family"]:
            families.append((s["_family"], []))
        families[-1][1].append(s)
    lines = [
        "// GÉNÉRÉ par scripts/styles/library.py depuis scripts/styles/library/*.json : ne pas éditer à la main.",
        "import SwiftUI",
        "",
        "extension StyleLibrary {",
        "    /// %d styles en %d familles (hors des 4 styles d'origine)." % (len(styles), len(families)),
        "    static let generated: [StyleLook] = {",
        "        var all: [StyleLook] = []",
        "        all.reserveCapacity(%d)" % len(styles),
    ]
    for i, _ in enumerate(families):
        lines.append("        all += family%02d()" % (i + 1))
    lines += ["        return all", "    }()", ""]
    for i, (family, items) in enumerate(families):
        lines.append("    // MARK: %s" % family)
        lines.append("    private static func family%02d() -> [StyleLook] {" % (i + 1))
        lines.append("        var list: [StyleLook] = []")
        lines.append("        var o = StyleOptions()")
        for s in items:
            lines.append("        o = StyleOptions()")
            bg = s.get("bg", {"kind": "theme"})
            if bg["kind"] == "gradient":
                lines.append("        o.gradient = GradientSpec(startHex: %s, endHex: %s, direction: .%s, intensity: %s)" % (
                    swift_str(bg["from"].upper()), swift_str(bg["to"].upper()), bg.get("dir", "diagonal"), float(bg.get("intensity", 1))))
            if s.get("fontName"):
                lines.append("        o.fontName = %s" % swift_str(s["fontName"]))
            if s.get("seriesHexes"):
                lines.append("        o.seriesHexes = [%s]" % ", ".join(swift_str(h.upper()) for h in s["seriesHexes"]))
            for key, value in s.items():
                if key.startswith("_") or key in OWN:
                    continue
                if key in ENUM_FIELDS:
                    lines.append("        o.%s = .%s" % (key, value))
                elif key in HEX_FIELDS:
                    lines.append("        o.%s = %s" % (key, swift_str(value.upper())))
                elif key in NUM_FIELDS:
                    lines.append("        o.%s = %s" % (key, float(value)))
                elif key in BOOL_FIELDS:
                    lines.append("        o.%s = %s" % (key, "true" if value else "false"))
            background = {
                "color": lambda: ".color(%s)" % swift_str(bg["hex"].upper()),
                "gradient": lambda: ".gradient",
                "glass": lambda: ".glass",
                "theme": lambda: ".theme",
            }[bg["kind"]]()
            accent = swift_str(s["accent"].upper()) if s.get("accent") else "nil"
            lines.append("        list.append(StyleLook(id: %s, name: %s, summary: %s, family: %s, themeID: .%s, accentHex: %s, background: %s, font: .%s, style: o))" % (
                swift_str(s["id"]), tr(s["name"]), tr(s["summary"]), swift_str(family), s["theme"], accent, background, s.get("font", "theme")))
        lines += ["        return list", "    }", ""]
    lines.append("}")
    open(OUT, "w", encoding="utf-8", newline="\n").write("\n".join(lines) + "\n")
    print("écrit %s : %d styles, %d familles" % (os.path.relpath(OUT, ROOT), len(styles), len(families)))


def stats():
    styles = load()
    for i, name in enumerate(AXIS_NAMES):
        counts = {}
        for s in styles:
            v = str(axes(s)[i])
            counts[v] = counts.get(v, 0) + 1
        top = sorted(counts.items(), key=lambda kv: -kv[1])[:8]
        print("%s : %d valeurs ; %s" % (name, len(counts), ", ".join("%s×%d" % kv for kv in top)))


if __name__ == "__main__":
    {"check": lambda: sys.exit(1 if check()[1] else 0), "gen": gen, "stats": stats}[sys.argv[1] if len(sys.argv) > 1 else "check"]()
