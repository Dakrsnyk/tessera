"""Tessera's translations.

    python3 scripts/l10n_catalog.py extract   # l10n/keys.json: every French text and where it is used
    python3 scripts/l10n_catalog.py merge     # l10n/<language>.json from the batches l10n/parts/NN.<language>.json
    python3 scripts/l10n_catalog.py build    # Shared/Localizable.xcstrings from l10n/<language>.json
    python3 scripts/l10n_catalog.py check     # placeholders, missing translations (fails on a broken placeholder)

The code is written in French and `tr("…")` looks the French text up at run time. A translation
file maps each French key to its translation; an interpolated value is `%@` (or `%1$@`, `%2$@`… to
move it), a literal percent sign next to values is `%%`.
"""
import glob
import json
import os
import re
import sys

sys.path.insert(0, os.path.dirname(__file__))
from l10n_scan import scan, line_of  # noqa: E402

ROOTS = ("App", "Shared", "Widgets")
LANGUAGES = ["en", "es", "de", "it", "pt-BR", "ja"]
CATALOG = "Shared/Localizable.xcstrings"
INFO_CATALOG = "App/InfoPlist.xcstrings"
KEYS = "l10n/keys.json"

# Literals SwiftUI or App Intents localize by themselves (not wrapped in tr()).
NATIVE_BEFORE = re.compile(r"(LocalizedStringResource\s*=\s*$|IntentDescription\(\s*$|@Parameter\(title:\s*$|"
                           r"DisplayRepresentation\(title:\s*$|TypeDisplayRepresentation\(name:\s*$|"
                           r"(?<![\w.])Text\(\s*$|\.configurationDisplayName\(\s*$|\.description\(\s*$)")
WORDS = re.compile(r"[A-Za-zÀ-ÖØ-öø-ÿ]{2,}")


def swift_files():
    return sorted(f.replace(os.sep, "/") for root in ROOTS for f in glob.glob(f"{root}/**/*.swift", recursive=True))


def extract():
    keys = {}
    for path in swift_files():
        source = open(path, encoding="utf8").read()
        for lit in scan(source):
            if lit.kind != "plain":
                continue
            line_start = source.rfind("\n", 0, lit.start) + 1
            before = source[line_start:lit.start]
            wrapped = re.search(r"\btr\(\s*$", before)
            native = NATIVE_BEFORE.search(before) and WORDS.search(lit.key) and not lit.key.startswith(("%", "\\"))
            if not (wrapped or native):
                continue
            entry = keys.setdefault(lit.key, {"placeholders": lit.placeholder_count if lit.has_interpolation else 0, "uses": []})
            line = source[line_start:source.find("\n", lit.start)].strip()
            if len(entry["uses"]) < 4:
                entry["uses"].append(f"{path}:{line_of(source, lit.start)}: {line[:200]}")
    os.makedirs("l10n", exist_ok=True)
    json.dump(dict(sorted(keys.items())), open(KEYS, "w", encoding="utf8"), ensure_ascii=False, indent=1)
    print(f"{len(keys)} keys")


PLACEHOLDER = re.compile(r"%(?:(\d+)\$)?([@dfs%])|%")


def placeholders(text):
    """The %@ placeholders of a format (positional ones by position), or None if a % is invalid."""
    found = []
    position = 0
    for m in re.finditer(r"%(\d+\$)?(@|%)?", text):
        if m.group(2) == "%" and not m.group(1):
            continue
        if m.group(2) != "@":
            return None
        if m.group(1):
            found.append(int(m.group(1)[:-1]))
        else:
            position += 1
            found.append(position)
    return sorted(found)


def load(language):
    path = f"l10n/{language}.json"
    return json.load(open(path, encoding="utf8")) if os.path.exists(path) else {}


def merge():
    keys = json.load(open(KEYS, encoding="utf8"))
    for language in LANGUAGES:
        table = {}
        for path in sorted(glob.glob(f"l10n/parts/*.{language}.json")):
            table.update(json.load(open(path, encoding="utf8")))
        table = {key: table[key] for key in sorted(table) if key in keys}
        json.dump(table, open(f"l10n/{language}.json", "w", encoding="utf8"), ensure_ascii=False, indent=1)
        print(f"{language}: {len(table)} translations")


def check():
    keys = json.load(open(KEYS, encoding="utf8"))
    broken = []
    for language in LANGUAGES:
        table = load(language)
        missing = [k for k in keys if k not in table]
        for key, value in table.items():
            if key not in keys:
                continue
            count = keys[key]["placeholders"]
            if count == 0:
                continue  # no String(format:): any % is shown as is
            got = placeholders(value)
            if got != list(range(1, count + 1)):
                broken.append(f"{language}: {key!r} -> {value!r}")
        print(f"{language}: {len(table)} translations, {len(missing)} missing")
    if broken:
        print("Broken placeholders:")
        print("\n".join(broken[:80]))
        sys.exit(1)


def unit(value):
    return {"stringUnit": {"state": "translated", "value": value}}


def build():
    keys = json.load(open(KEYS, encoding="utf8"))
    tables = {language: load(language) for language in LANGUAGES}
    strings = {}
    for key in sorted(keys):
        localizations = {"fr": unit(key)}
        for language, table in tables.items():
            if key in table and table[key].strip():
                localizations[language] = unit(table[key])
        strings[key] = {"extractionState": "manual", "localizations": localizations}
    catalog = {"sourceLanguage": "fr", "strings": strings, "version": "1.0"}
    json.dump(catalog, open(CATALOG, "w", encoding="utf8"), ensure_ascii=False, indent=2, sort_keys=True)
    # Info.plist texts (permissions).
    info = json.load(open("l10n/infoplist.json", encoding="utf8"))
    info_strings = {}
    for key, values in info.items():
        info_strings[key] = {"extractionState": "manual",
                             "localizations": {lang: unit(text) for lang, text in values.items()}}
    json.dump({"sourceLanguage": "fr", "strings": info_strings, "version": "1.0"},
              open(INFO_CATALOG, "w", encoding="utf8"), ensure_ascii=False, indent=2, sort_keys=True)
    print(f"{len(strings)} keys, {sum(len(s['localizations']) for s in strings.values())} localizations")


if __name__ == "__main__":
    {"extract": extract, "merge": merge, "build": build, "check": check}[sys.argv[1]]()
