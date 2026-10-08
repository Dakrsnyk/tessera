import json, os
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
KEYS = [x["key"] for x in json.load(open(os.path.join(ROOT, "chunks", "13.json"), encoding="utf-8"))]
assert len(KEYS) == 173


def save(lang, tr):
    assert len(tr) == len(KEYS), (lang, len(tr), len(KEYS))
    d = dict(zip(KEYS, tr))
    with open(os.path.join(ROOT, "parts", f"13.{lang}.json"), "w", encoding="utf-8") as f:
        json.dump(d, f, ensure_ascii=False, indent=1)
    print(lang, "ok", len(d))
