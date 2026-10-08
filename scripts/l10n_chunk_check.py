"""Checks the translations of one batch: python3 scripts/l10n_chunk_check.py 07

Reads l10n/chunks/07.json and l10n/parts/07.<language>.json for every language and reports missing
keys, extra keys and broken placeholders. Exit code 1 if anything is wrong.
"""
import json
import os
import sys

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8")

sys.path.insert(0, os.path.dirname(__file__))
from l10n_catalog import LANGUAGES, placeholders  # noqa: E402

number = sys.argv[1]
chunk = json.load(open(f"l10n/chunks/{number}.json", encoding="utf8"))
problems = []
for language in LANGUAGES:
    path = f"l10n/parts/{number}.{language}.json"
    if not os.path.exists(path):
        problems.append(f"{language}: file missing ({path})")
        continue
    try:
        table = json.load(open(path, encoding="utf8"))
    except json.JSONDecodeError as error:
        problems.append(f"{language}: invalid JSON: {error}")
        continue
    for item in chunk:
        key = item["key"]
        if key not in table or not str(table[key]).strip():
            problems.append(f"{language}: missing {key!r}")
            continue
        value = table[key]
        if item["placeholders"]:
            got = placeholders(value)
            if got != list(range(1, item["placeholders"] + 1)):
                problems.append(f"{language}: placeholders {key!r} -> {value!r}")
        if key.startswith(" ") != value.startswith(" ") or key.endswith(" ") != value.endswith(" "):
            problems.append(f"{language}: leading/trailing space differs {key!r} -> {value!r}")
    extra = set(table) - {item["key"] for item in chunk}
    if extra:
        problems.append(f"{language}: {len(extra)} keys not in the batch, e.g. {sorted(extra)[:3]}")
print("\n".join(problems) if problems else f"Batch {number}: OK ({len(chunk)} keys x {len(LANGUAGES)} languages)")
sys.exit(1 if problems else 0)
