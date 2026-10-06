import json
def save(lang, d):
    keys = [e["key"] for e in json.load(open("l10n/chunks/14.json"))]
    assert sorted(d) == list(range(len(keys))), (len(d), len(keys))
    out = {k: d[i] for i, k in enumerate(keys)}
    json.dump(out, open(f"l10n/parts/14.{lang}.json", "w"), ensure_ascii=False, indent=1)
    print(lang, len(out))
