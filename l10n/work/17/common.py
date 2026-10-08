import json, os
HERE = os.path.dirname(os.path.abspath(__file__))
L10N = os.path.dirname(os.path.dirname(HERE))
chunk = json.load(open(os.path.join(L10N, 'chunks', '17.json'), encoding='utf8'))
KEYS = [e['key'] for e in chunk]
class B:
    def __init__(self, lang):
        self.lang = lang
        self.v = []
    def S(self, start, items):
        assert len(self.v) == start, (start, len(self.v))
        self.v += items
    def save(self):
        assert len(self.v) == len(KEYS), (len(self.v), len(KEYS))
        out = dict(zip(KEYS, self.v))
        json.dump(out, open(os.path.join(L10N, 'parts', f'17.{self.lang}.json'), 'w', encoding='utf8'), ensure_ascii=False, indent=1)
