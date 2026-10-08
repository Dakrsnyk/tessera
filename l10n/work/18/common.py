import json, os
HERE = os.path.dirname(os.path.abspath(__file__))
L10N = os.path.dirname(os.path.dirname(HERE))
chunk = json.load(open(os.path.join(L10N, 'chunks', '18.json'), encoding='utf8'))
keys = [c['key'] for c in chunk]
def write(lang, vals):
    assert len(vals) == len(keys), (lang, len(vals), len(keys))
    json.dump(dict(zip(keys, vals)), open(os.path.join(L10N, 'parts', f'18.{lang}.json'), 'w', encoding='utf8'), ensure_ascii=False, indent=1)
