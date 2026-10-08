import json, os
HERE = os.path.dirname(os.path.abspath(__file__))
L10N = os.path.dirname(os.path.dirname(HERE))
chunk = json.load(open(os.path.join(L10N, 'chunks', '11.json'), encoding='utf8'))
def write(lang, tr):
    assert len(tr) == len(chunk), (lang, len(tr), len(chunk))
    out = {c['key']: t for c, t in zip(chunk, tr)}
    json.dump(out, open(os.path.join(L10N, 'parts', f'11.{lang}.json'), 'w', encoding='utf8'), ensure_ascii=False, indent=1)
