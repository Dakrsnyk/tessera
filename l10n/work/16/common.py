import json
chunk = json.load(open('/home/claude/tessera/l10n/chunks/16.json', encoding='utf8'))
keys = [x['key'] for x in chunk]
def save(lang, vals):
    assert len(vals) == len(keys), (lang, len(vals), len(keys))
    out = dict(zip(keys, vals))
    with open(f'/home/claude/tessera/l10n/parts/16.{lang}.json', 'w', encoding='utf8') as f:
        json.dump(out, f, ensure_ascii=False, indent=1)
