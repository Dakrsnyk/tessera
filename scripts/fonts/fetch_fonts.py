"""Fetches the free fonts of the Studio's "Texte" tab (Google Fonts, SIL OFL 1.1 or Apache 2.0) and writes
`Shared/Fonts/*.ttf`, `scripts/fonts/manifest.json`, `docs/legal/polices/*` and `Shared/Model/FontCatalogBundled.swift`.

    python3 scripts/fonts/fetch_fonts.py

Only fonts of github.com/google/fonts (`ofl/` and `apache/`), downloaded to a scratch folder first, checked (TrueType
header) and read for their PostScript name. A variable font keeps its default instance only. Run again to refresh;
the output is deterministic.
"""
import json
import os
import re
import shutil
import struct
import subprocess
import tempfile
import urllib.request
from concurrent.futures import ThreadPoolExecutor

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
MAX_KB = 700

# family directory -> category of FontCategory
CATEGORIES = {}


def cat(kind, names):
    for n in names.split():
        CATEGORIES[n] = kind


cat("script", """pinyonscript parisienne tangerine windsong greatvibes allura alexbrush sacramento satisfy pacifico italianno
 rougescript petitformalscript mrssaintdelafield monsieurladoulaise meaculpa herrvonmuellerhoff birthstone birthstonebounce
 cookie courgette kaushanscript yellowtail lobster marckscript playball qwigley rochester seaweedscript stylescript arizonia
 euphoriascript grandhotel handlee homemadeapple kristi labelleaurore leaguescript niconne norican oleoscript reeniebeanie
 sevillana waterfall whisper sendflowers licorice imperialscript updock ooohbaby passionsconflict carattere charm
 corinthia fleurdeleah gwendolyn hurricane kolkerbrush loversquarrel luxuriousscript moondance mrdehaviland mrssheppards
 ephesis explora inspiration lovelight bonheurroyale comforter engagement msmadi qwitchergrypen waterbrush dancingscript
 caveat ballet indieflower gloriahallelujah amaticsc architectsdaughter patrickhand kalam coveredbyyourgrace permanentmarker
 rocksalt""")
cat("serif", """cinzel cinzeldecorative ovo librebaskerville abrilfatface dmserifdisplay italiana marcellus forum limelight gloock
 playfairdisplay ebgaramond lora bodonimoda cormorantgaramond almendra josefinslab""")
cat("sans", "quicksand josefinsans raleway montserrat comfortaa fredoka poppins poiretone")
cat("condensed", "bebasneue anton oswald")
cat("fun", "bungee audiowide monoton shrikhand chewy bangers pirataone unifrakturcook orbitron pressstart2p righteous archivoblack")
cat("typewriter", "courierprime spacemono specialelite")

# Families with many files: only these styles are kept.
KEEP_STYLES = {
    "Poppins": ("Regular", "Bold"), "Kalam": ("Regular", "Bold"), "CourierPrime": ("Regular", "Bold"),
    "SpaceMono": ("Regular", "Bold"), "Almendra": ("Regular", "Bold"), "Corinthia": ("Regular",),
    "Gwendolyn": ("Regular",), "Charm": ("Regular",), "QwitcherGrypen": ("Regular",),
    "AmaticSC": ("Regular", "Bold"), "Tangerine": ("Regular", "Bold"), "OleoScript": ("Regular",),
    "BirthstoneBounce": ("Regular",), "CinzelDecorative": ("Regular", "Bold", "Black"),
    "DMSerifDisplay": ("Regular", "Italic"),
}
DROP_FAMILIES = {"estonia", "islandmoments", "babylonica", "stylescript", "waterfall", "kalam", "lobster", "caveat", "luxuriousscript",
                 "birthstone", "birthstonebounce", "hurricane", "waterbrush", "comforter", "moondance", "kolkerbrush", "forum", "fleurdeleah"}


def gh(path):
    r = subprocess.run(["gh", "api", "repos/google/fonts/contents/" + path], capture_output=True, text=True)
    return json.loads(r.stdout) if r.returncode == 0 else None


def plan(fam):
    for lic_dir in ("ofl", "apache"):
        items = gh(lic_dir + "/" + fam)
        if items is None:
            continue
        ttf = [i for i in items if i["type"] == "file" and i["name"].endswith(".ttf")]
        chosen = [f for f in ttf if "[" not in f["name"]]
        if any(i["type"] == "dir" and i["name"] == "static" for i in items):
            sf = [f for f in (gh(lic_dir + "/" + fam + "/static") or []) if f["name"].endswith(".ttf")]
            chosen += [f for f in sf if f["name"].endswith(("-Regular.ttf", "-Bold.ttf"))]
        if not chosen:  # variable only: the default instance
            chosen = [f for f in ttf if "[" in f["name"] and "Italic" not in f["name"]]
        lic = next((i for i in items if i["type"] == "file" and i["name"] in ("OFL.txt", "LICENSE.txt")), None)
        return fam, lic_dir, chosen, lic
    return fam, None, [], None


def read_names(data):
    """The name table of a TrueType file: {nameID: string}."""
    num = struct.unpack(">H", data[4:6])[0]
    for i in range(num):
        tag, _, off, length = struct.unpack(">4sIII", data[12 + 16 * i: 28 + 16 * i])
        if tag == b"name":
            t = data[off: off + length]
            count, string_off = struct.unpack(">HH", t[2:6])
            out = {}
            for r in range(count):
                plat, _enc, _lang, nid, ln, so = struct.unpack(">HHHHHH", t[6 + 12 * r: 18 + 12 * r])
                raw = t[string_off + so: string_off + so + ln]
                try:
                    text = raw.decode("utf-16-be") if plat in (0, 3) else raw.decode("mac-roman")
                except Exception:
                    continue
                if plat == 3 or nid not in out:
                    out[nid] = text
            return out
    return {}


def main():
    fams = sorted(CATEGORIES)
    with ThreadPoolExecutor(8) as ex:
        plans = list(ex.map(plan, fams))
    work = tempfile.mkdtemp(prefix="fonts-")
    fonts_dir = os.path.join(ROOT, "Shared", "Fonts")
    legal_dir = os.path.join(ROOT, "docs", "legal", "polices")
    shutil.rmtree(fonts_dir, ignore_errors=True)
    os.makedirs(fonts_dir)
    os.makedirs(legal_dir, exist_ok=True)
    manifest = []
    for fam, lic_dir, files, lic in plans:
        if fam in DROP_FAMILIES:
            continue
        if not files:
            print("absent", fam)
            continue
        for f in files:
            stem = f["name"][:-4]
            style = stem.split("-")[-1] if "-" in stem else "Regular"
            base = stem.split("-")[0].split("[")[0]
            if base in KEEP_STYLES and style not in KEEP_STYLES[base] and "[" not in stem:
                continue
            if f["size"] > MAX_KB * 1024:
                print("too big", f["name"], f["size"] // 1024)
                continue
            dest = os.path.join(work, f["name"])
            urllib.request.urlretrieve(f["download_url"], dest)
            with open(dest, "rb") as fh:
                data = fh.read()
            if data[:4] not in (b"\x00\x01\x00\x00", b"true"):
                print("not a ttf", f["name"])
                continue
            n = read_names(data)
            ps = n.get(6)
            if not ps:
                print("no PostScript name", f["name"])
                continue
            out_name = re.sub(r"\[.*\]", "-Variable", f["name"])
            shutil.copyfile(dest, os.path.join(fonts_dir, out_name))
            manifest.append({
                "dir": fam, "file": out_name, "postscript": ps, "full": n.get(4, ps),
                "style": n.get(17) or n.get(2, "Regular"), "category": CATEGORIES[fam],
                "license": "OFL-1.1" if lic_dir == "ofl" else "Apache-2.0", "kb": len(data) // 1024,
                "variable": "[" in f["name"],
            })
        if lic:
            urllib.request.urlretrieve(lic["download_url"], os.path.join(legal_dir, fam + "-" + lic["name"]))
    manifest.sort(key=lambda m: (m["category"], m["dir"], m["file"]))
    with open(os.path.join(ROOT, "scripts", "fonts", "manifest.json"), "w", encoding="utf-8") as fh:
        json.dump(manifest, fh, indent=1, ensure_ascii=False)
    write_swift(manifest)
    print(len(manifest), "fonts,", sum(m["kb"] for m in manifest), "KB")


def write_swift(manifest):
    """FontCatalogBundled.swift: a Regular file with a Bold one of the same family pairs with it (bold: ...)."""
    by_dir = {}
    for m in manifest:
        by_dir.setdefault(m["dir"], []).append(m)
    body = {}
    for m in manifest:
        siblings = by_dir[m["dir"]]
        if m["style"] == "Bold" and any(s["style"] == "Regular" for s in siblings):
            continue
        bold = next((s for s in siblings if s is not m and s["style"] == "Bold"), None)
        bold_arg = ', bold: "%s"' % bold["postscript"] if bold and m["style"] == "Regular" else ""
        name = re.sub(r"[ -]Regular$", "", m["full"]).replace('"', "'")
        line = '        FontEntry("%s", "%s", .%s%s),' % (name, m["postscript"], m["category"], bold_arg)
        body.setdefault(m["category"], []).append(line)
    kinds = ("script", "serif", "sans", "condensed", "fun", "typewriter")
    out = [
        "// Generated by scripts/fonts/fetch_fonts.py: do not edit by hand.",
        "// Free fonts (SIL OFL 1.1 or Apache 2.0, Google Fonts) bundled in `Shared/Fonts`; the licenses are in `docs/legal/polices`.",
        "",
        "extension FontCatalog {",
        "    static let bundled: [FontEntry] = " + " + ".join("bundled" + k.capitalize() for k in kinds),
        "",
    ]
    for k in kinds:
        out.append("    private static let bundled%s: [FontEntry] = [" % k.capitalize())
        out += body.get(k, [])
        out.append("    ]")
        out.append("")
    with open(os.path.join(ROOT, "Shared", "Model", "FontCatalogBundled.swift"), "w", encoding="utf-8") as fh:
        fh.write("\n".join(out).rstrip() + "\n}\n")


if __name__ == "__main__":
    main()
