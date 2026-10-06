import json
chunk = json.load(open('/home/claude/tessera/l10n/chunks/17.json', encoding='utf8'))
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
        json.dump(out, open(f'/home/claude/tessera/l10n/parts/17.{self.lang}.json', 'w', encoding='utf8'), ensure_ascii=False, indent=1)
