import json
KEYS = [e['key'] for e in json.load(open('/home/claude/tessera/l10n/chunks/15.json', encoding='utf8'))]
def write(lang, T):
    assert len(T) == len(KEYS), (lang, len(T), len(KEYS))
    with open(f'/home/claude/tessera/l10n/parts/15.{lang}.json', 'w', encoding='utf8') as f:
        json.dump(dict(zip(KEYS, T)), f, ensure_ascii=False, indent=1)
