"""Writes the credits page of the site (ardane.app/credits.html, French and English).

It lists what Ardane uses under a license that asks for credit: the food data, the scanner's datasets and models,
the photos of Quebec dishes the classifier learned from (CC BY: title, author, source, license, changes) and the
fonts bundled in the app (SIL OFL 1.1 or Apache 2.0, full license texts on the page).

    python3 scripts/site/credits_page.py [--photos <quebec_crops.csv>] [--attributions <attributions.csv>] [--out <credits.html>]

Inputs: `scripts/fonts/manifest.json`, `Shared/Model/FontCatalogBundled.swift` and `docs/legal/polices` (in this
repository); the photo lists live outside it (`ardane-tools/ml/...`, defaults below). The page goes to the site's
repository (`../ardane-site/credits.html` by default), published by GitHub Pages.
"""
import argparse
import csv
import html
import json
import os
import re
from collections import OrderedDict

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
HOME = os.path.expanduser("~")
DEFAULT_CROPS = os.path.join(HOME, "ardane-tools", "ml", "quebec-crops", "quebec_crops.csv")
DEFAULT_ATTR = os.path.join(HOME, "ardane-tools", "ml", "raw", "quebec", "attributions.csv")
DEFAULT_OUT = os.path.join(os.path.dirname(ROOT), "ardane-site", "credits.html")

UPDATED = {"fr": "Mise à jour le 22 novembre 2026", "en": "Updated November 22, 2026"}

DISHES = OrderedDict([
    ("poutine", {"fr": "Poutine", "en": "Poutine"}),
    ("tourtiere", {"fr": "Tourtière", "en": "Tourtière (meat pie)"}),
    ("pate-chinois", {"fr": "Pâté chinois", "en": "Pâté chinois (shepherd's pie)"}),
])

LICENSES = {
    ("by", "2.0"): ("CC BY 2.0", "https://creativecommons.org/licenses/by/2.0/"),
    ("by", "3.0"): ("CC BY 3.0", "https://creativecommons.org/licenses/by/3.0/"),
    ("by", "4.0"): ("CC BY 4.0", "https://creativecommons.org/licenses/by/4.0/"),
    ("cc0", "1.0"): ("CC0 1.0", "https://creativecommons.org/publicdomain/zero/1.0/"),
    ("pdm", "1.0"): ("Public Domain Mark 1.0", "https://creativecommons.org/publicdomain/mark/1.0/"),
}

T = {
    "fr": {
        "title": "Crédits et licences d'Ardane",
        "sub": "Crédits et licences",
        "intro": "Ardane s'appuie sur des données, des modèles, des photos et des polices partagés librement par leurs auteurs. Cette page les remercie et donne les conditions de leurs licences.",
        "data_h": "1. Données nutritives",
        "data": [
            ("Fichier canadien sur les éléments nutritifs (FCÉN)", "Santé Canada, 2026. Licence du gouvernement ouvert – Canada. Ardane n'est pas une version officielle du FCÉN, n'est pas affiliée à Santé Canada ni approuvée par lui.", "https://open.canada.ca/fr/licence-du-gouvernement-ouvert-canada"),
            ("USDA FoodData Central", "Département de l'Agriculture des États-Unis, Agricultural Research Service. Domaine public (CC0 1.0).", "https://fdc.nal.usda.gov"),
            ("Open Food Facts", "Contient des données d'Open Food Facts, disponibles sous la licence Open Database License (ODbL) ; contenu sous Database Contents License (DbCL). Données saisies par la communauté.", "https://world.openfoodfacts.org"),
        ],
        "scan_h": "2. Reconnaissance des aliments",
        "scan_p": "Le scanner fonctionne sur ton iPhone avec des modèles entraînés par Ardane. Les données d'entraînement ne sont pas distribuées avec l'app.",
        "scan": [
            ("MyFoodRepo / AIcrowd Food Recognition Benchmark 2022", "Jeu de données du projet MyFoodRepo (myfoodrepo.org). Licence CC BY 4.0.", "https://creativecommons.org/licenses/by/4.0/"),
            ("DINOv2", "Meta Platforms, Inc. Code et poids sous licence Apache 2.0.", "https://github.com/facebookresearch/dinov2"),
            ("RF-DETR", "Roboflow, Inc. Code et poids sous licence Apache 2.0.", "https://github.com/roboflow/rf-detr"),
        ],
        "photos_h": "3. Photos de plats québécois",
        "photos_p": "Pour reconnaître la poutine, la tourtière et le pâté chinois, le modèle a appris sur les photos ci-dessous, partagées sous licence Creative Commons ou versées au domaine public. Modifications : photos recadrées et réduites pour l'entraînement. Elles ne sont ni affichées ni distribuées dans l'app. Merci à leurs auteurs.",
        "photos_n": "{n} photos",
        "col_photo": "Photo", "col_author": "Auteur", "col_license": "Licence",
        "untitled": "Sans titre", "unknown": "Auteur inconnu",
        "fonts_h": "4. Polices du Studio",
        "fonts_p": "Les {n} polices proposées dans l'onglet « Texte » du Studio viennent de Google Fonts. Elles sont distribuées sous la SIL Open Font License 1.1 ou la licence Apache 2.0 ; les textes complets sont plus bas.",
        "col_font": "Police", "col_copyright": "Droits d'auteur",
        "apache_note": "Voir le texte de la licence Apache 2.0 plus bas.",
        "ofl_h": "Texte de la SIL Open Font License 1.1",
        "apache_h": "Texte de la licence Apache 2.0",
        "show": "Afficher",
        "other_h": "5. Le reste",
        "other_p": "Les icônes de l'app sont les SF Symbols d'Apple, utilisés selon les conditions d'Apple. Le logo, les textes, les illustrations et le code d'Ardane appartiennent à leur éditeur. Une erreur ou un oubli dans ces crédits ? Écris à support.ardane@gmail.com : nous corrigeons au plus vite.",
        "nav_label": "Liens légaux",
        "nav": [("privacy.html#fr", "Politique de confidentialité"), ("terms.html#fr", "Conditions d'utilisation"), ("credits.html#fr", "Crédits"), ("support.html#fr", "Assistance")],
        "copy": "© 2026 Ardane · Québec, Canada",
    },
    "en": {
        "title": "Ardane credits and licenses",
        "sub": "Credits and licenses",
        "intro": "Ardane relies on data, models, photos and fonts freely shared by their authors. This page thanks them and gives the terms of their licenses.",
        "data_h": "1. Nutrition data",
        "data": [
            ("Canadian Nutrient File (CNF)", "Health Canada, 2026. Open Government Licence – Canada. Ardane is not an official version of the CNF, and is not affiliated with or endorsed by Health Canada.", "https://open.canada.ca/en/open-government-licence-canada"),
            ("USDA FoodData Central", "U.S. Department of Agriculture, Agricultural Research Service. Public domain (CC0 1.0).", "https://fdc.nal.usda.gov"),
            ("Open Food Facts", "Contains data from Open Food Facts, made available under the Open Database License (ODbL); contents under the Database Contents License (DbCL). Data entered by the community.", "https://world.openfoodfacts.org"),
        ],
        "scan_h": "2. Food recognition",
        "scan_p": "The scanner runs on your iPhone with models trained by Ardane. The training data is not distributed with the app.",
        "scan": [
            ("MyFoodRepo / AIcrowd Food Recognition Benchmark 2022", "Dataset of the MyFoodRepo project (myfoodrepo.org). CC BY 4.0 license.", "https://creativecommons.org/licenses/by/4.0/"),
            ("DINOv2", "Meta Platforms, Inc. Code and weights under the Apache 2.0 license.", "https://github.com/facebookresearch/dinov2"),
            ("RF-DETR", "Roboflow, Inc. Code and weights under the Apache 2.0 license.", "https://github.com/roboflow/rf-detr"),
        ],
        "photos_h": "3. Photos of Quebec dishes",
        "photos_p": "To recognize poutine, tourtière and pâté chinois, the model learned from the photos below, shared under a Creative Commons license or dedicated to the public domain. Changes: photos cropped and resized for training. They are neither shown nor distributed in the app. Thanks to their authors.",
        "photos_n": "{n} photos",
        "col_photo": "Photo", "col_author": "Author", "col_license": "License",
        "untitled": "Untitled", "unknown": "Unknown author",
        "fonts_h": "4. Studio fonts",
        "fonts_p": "The {n} fonts offered in the Studio's “Text” tab come from Google Fonts. They are distributed under the SIL Open Font License 1.1 or the Apache License 2.0; the full texts are below.",
        "col_font": "Font", "col_copyright": "Copyright",
        "apache_note": "See the text of the Apache License 2.0 below.",
        "ofl_h": "Text of the SIL Open Font License 1.1",
        "apache_h": "Text of the Apache License 2.0",
        "show": "Show",
        "other_h": "5. Everything else",
        "other_p": "The app's icons are Apple's SF Symbols, used under Apple's terms. Ardane's logo, texts, illustrations and code belong to its publisher. An error or omission in these credits? Write to support.ardane@gmail.com and we will fix it quickly.",
        "nav_label": "Legal links",
        "nav": [("privacy.html#en", "Privacy policy"), ("terms.html#en", "Terms of use"), ("credits.html#en", "Credits"), ("support.html#en", "Support")],
        "copy": "© 2026 Ardane · Quebec, Canada",
    },
}


def e(text):
    return html.escape(text or "", quote=True)


def link(url, text):
    return f'<a href="{e(url)}">{e(text)}</a>' if url else e(text)


def load_photos(crops_path, attr_path):
    """The source photos behind the crops (each once), with their credit from the collection's list."""
    with open(crops_path, encoding="utf-8") as fh:
        used = OrderedDict()
        for row in csv.DictReader(fh):
            used.setdefault(row["source_file"], row["class"])
    with open(attr_path, encoding="utf-8") as fh:
        meta = {row["file"]: row for row in csv.DictReader(fh)}
    photos = []
    for src, dish in used.items():
        m = meta.get(src)
        if m is None:
            raise SystemExit(f"photo absente de la liste d'attributions : {src}")
        key = (m["license"], m["license_version"])
        if key not in LICENSES:
            raise SystemExit(f"licence inattendue {key} pour {src} : seules CC BY, CC0 et PDM sont permises")
        photos.append({
            "dish": dish, "title": m["title"].strip(), "creator": m["creator"].strip(),
            "creator_url": m["creator_url"].strip(), "landing": m["landing"].strip(), "license": LICENSES[key],
        })
    for p in photos:
        if p["dish"] not in DISHES:
            raise SystemExit(f"plat inconnu : {p['dish']}")
    return photos


def load_fonts():
    """One row per family bundled in the app: display name, license and copyright lines."""
    with open(os.path.join(ROOT, "scripts", "fonts", "manifest.json"), encoding="utf-8") as fh:
        manifest = json.load(fh)
    with open(os.path.join(ROOT, "Shared", "Model", "FontCatalogBundled.swift"), encoding="utf-8") as fh:
        display = {ps: name for name, ps in re.findall(r'FontEntry\("([^"]+)", "([^"]+)"', fh.read())}
    legal = os.path.join(ROOT, "docs", "legal", "polices")
    families = OrderedDict()
    for m in manifest:
        fam = families.setdefault(m["dir"], {"name": None, "license": m["license"]})
        fam["name"] = fam["name"] or display.get(m["postscript"])
    rows = []
    for slug, fam in families.items():
        name = fam["name"] or slug
        file = os.path.join(legal, slug + ("-OFL.txt" if fam["license"] == "OFL-1.1" else "-LICENSE.txt"))
        if not os.path.exists(file):
            raise SystemExit(f"licence absente pour la police {name} : {file}")
        copyright_lines = []
        if fam["license"] == "OFL-1.1":
            with open(file, encoding="utf-8", errors="replace") as fh:
                for line in fh:
                    if line.startswith("This Font Software is licensed"):
                        break
                    if line.strip():
                        copyright_lines.append(line.strip())
        rows.append({"name": name, "license": fam["license"], "copyright": " ".join(copyright_lines)})
    rows.sort(key=lambda r: r["name"].lower())
    return rows


def license_text(kind):
    legal = os.path.join(ROOT, "docs", "legal", "polices")
    suffix = "-OFL.txt" if kind == "ofl" else "-LICENSE.txt"
    name = sorted(f for f in os.listdir(legal) if f.endswith(suffix))[0]
    with open(os.path.join(legal, name), encoding="utf-8", errors="replace") as fh:
        text = fh.read()
    if kind == "ofl":
        start = text.find("SIL OPEN FONT LICENSE Version 1.1")
        if start > 0:
            rule = text.rfind("-" * 10, 0, start)
            text = text[text.rfind("\n", 0, rule) + 1:] if rule >= 0 else text[start:]
    return text.strip()


def article(lang, photos, fonts, ofl, apache):
    t = T[lang]
    out = [f'  <article id="{lang}" lang="{lang}"' + (" hidden>" if lang == "en" else ">")]
    out.append(f'    <p class="updated">{e(UPDATED[lang])}</p>')
    out.append(f'    <div class="summary"><p>{e(t["intro"])}</p></div>')

    def sources(title, items, para=None):
        out.append("    <section>")
        out.append(f"      <h2>{e(title)}</h2>")
        if para:
            out.append(f"      <p>{e(para)}</p>")
        out.append('      <ul class="list">')
        for name, text, url in items:
            out.append(f"        <li><b>{link(url, name)}</b><span>{e(text)}</span></li>")
        out.append("      </ul>")
        out.append("    </section>")

    sources(t["data_h"], t["data"])
    sources(t["scan_h"], t["scan"], t["scan_p"])

    out.append("    <section>")
    out.append(f'      <h2>{e(t["photos_h"])}</h2>')
    out.append(f'      <p>{e(t["photos_p"])}</p>')
    for dish, names in DISHES.items():
        rows = [p for p in photos if p["dish"] == dish]
        if not rows:
            continue
        out.append(f'      <details><summary>{e(names[lang])} · {e(t["photos_n"].format(n=len(rows)))}</summary>')
        out.append(f'        <div class="scroll"><table><thead><tr><th>{e(t["col_photo"])}</th><th>{e(t["col_author"])}</th><th>{e(t["col_license"])}</th></tr></thead><tbody>')
        for p in rows:
            lic_name, lic_url = p["license"]
            out.append("          <tr><td>{}</td><td>{}</td><td class=\"nw\">{}</td></tr>".format(
                link(p["landing"], p["title"] or t["untitled"]),
                link(p["creator_url"], p["creator"]) if p["creator"] else e(t["unknown"]),
                link(lic_url, lic_name)))
        out.append("        </tbody></table></div>")
        out.append("      </details>")
    out.append("    </section>")

    out.append("    <section>")
    out.append(f'      <h2>{e(t["fonts_h"])}</h2>')
    out.append(f'      <p>{e(t["fonts_p"].format(n=len(fonts)))}</p>')
    out.append(f'      <details><summary>{e(t["col_font"])} · {len(fonts)}</summary>')
    out.append(f'        <div class="scroll"><table><thead><tr><th>{e(t["col_font"])}</th><th>{e(t["col_license"])}</th><th>{e(t["col_copyright"])}</th></tr></thead><tbody>')
    for f in fonts:
        lic = ("SIL OFL 1.1", "https://openfontlicense.org") if f["license"] == "OFL-1.1" else ("Apache 2.0", "https://www.apache.org/licenses/LICENSE-2.0")
        out.append("          <tr><td class=\"nw\">{}</td><td class=\"nw\">{}</td><td>{}</td></tr>".format(
            e(f["name"]), link(lic[1], lic[0]), e(f["copyright"] or t["apache_note"])))
    out.append("        </tbody></table></div>")
    out.append("      </details>")
    out.append(f'      <details><summary>{e(t["ofl_h"])}</summary><pre>{e(ofl)}</pre></details>')
    out.append(f'      <details><summary>{e(t["apache_h"])}</summary><pre>{e(apache)}</pre></details>')
    out.append("    </section>")

    out.append("    <section>")
    out.append(f'      <h2>{e(t["other_h"])}</h2>')
    out.append(f'      <p>{e(t["other_p"])}</p>')
    out.append("    </section>")

    nav = "".join(f'<a href="{e(h)}">{e(x)}</a>' for h, x in t["nav"])
    out.append("    <footer>")
    out.append(f'      <nav class="links" aria-label="{e(t["nav_label"])}">{nav}</nav>')
    out.append(f'      <span>{e(t["copy"])}</span>')
    out.append("    </footer>")
    out.append("  </article>")
    return "\n".join(out)


def page(photos, fonts):
    ofl, apache = license_text("ofl"), license_text("apache")
    fr, en = T["fr"], T["en"]
    head = f"""<!doctype html>
<html lang="fr" data-title-fr="{e(fr["title"])}" data-title-en="{e(en["title"])}">
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="color-scheme" content="light dark">
<meta name="theme-color" content="#EBF1F7" media="(prefers-color-scheme: light)">
<meta name="theme-color" content="#080E14" media="(prefers-color-scheme: dark)">
<title>{e(fr["title"])}</title>
<link rel="stylesheet" href="style.css">
<!-- Généré par scripts/site/credits_page.py (dépôt de l'app) : ne pas modifier à la main. -->

<main>
  <header>
    <div class="mark" aria-hidden="true"></div>
    <div class="titles">
      <h1>Ardane</h1>
      <p class="sub" id="sub">{e(fr["sub"])}</p>
    </div>
    <div class="lang" role="group" aria-label="Langue / Language">
      <button id="btn-fr" type="button" aria-pressed="true" lang="fr">Français</button>
      <button id="btn-en" type="button" aria-pressed="false" lang="en">English</button>
    </div>
  </header>
"""
    tail = f"""
</main>
<script src="site.js"></script>
<script>
(function(){{var s=document.getElementById("sub");function f(){{s.textContent=document.documentElement.lang==="en"?{json.dumps(en["sub"])}:{json.dumps(fr["sub"])};}}f();new MutationObserver(f).observe(document.documentElement,{{attributes:true,attributeFilter:["lang"]}});}})();
</script>
"""
    return head + "\n" + article("fr", photos, fonts, ofl, apache) + "\n\n" + article("en", photos, fonts, ofl, apache) + "\n" + tail


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--photos", default=DEFAULT_CROPS, help="liste des recadrages (quebec_crops.csv)")
    ap.add_argument("--attributions", default=DEFAULT_ATTR, help="attributions des photos (attributions.csv)")
    ap.add_argument("--out", default=DEFAULT_OUT, help="page à écrire")
    args = ap.parse_args()
    photos = load_photos(args.photos, args.attributions)
    fonts = load_fonts()
    with open(args.out, "w", encoding="utf-8", newline="\n") as fh:
        fh.write(page(photos, fonts))
    by = sum(1 for p in photos if p["license"][0].startswith("CC BY"))
    print(f"{args.out} : {len(photos)} photos ({by} CC BY), {len(fonts)} polices")


if __name__ == "__main__":
    main()
