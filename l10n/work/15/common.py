import json, os
HERE = os.path.dirname(os.path.abspath(__file__))
L10N = os.path.dirname(os.path.dirname(HERE))
KEYS = [e['key'] for e in json.load(open(os.path.join(L10N, 'chunks', '15.json'), encoding='utf8'))]
def write(lang, T):
    assert len(T) == len(KEYS), (lang, len(T), len(KEYS))
    with open(os.path.join(L10N, 'parts', f'15.{lang}.json'), 'w', encoding='utf8') as f:
        json.dump(dict(zip(KEYS, T)), f, ensure_ascii=False, indent=1)
