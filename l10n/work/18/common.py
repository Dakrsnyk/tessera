import json
chunk = json.load(open('/home/claude/tessera/l10n/chunks/18.json', encoding='utf8'))
keys = [c['key'] for c in chunk]
def write(lang, vals):
    assert len(vals) == len(keys), (lang, len(vals), len(keys))
    json.dump(dict(zip(keys, vals)), open(f'/home/claude/tessera/l10n/parts/18.{lang}.json', 'w', encoding='utf8'), ensure_ascii=False, indent=1)
