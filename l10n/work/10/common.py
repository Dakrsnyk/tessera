import json
KEYS=[x['key'] for x in json.load(open('/home/claude/tessera/l10n/chunks/10.json'))]
def save(lang, vals):
    assert len(vals)==len(KEYS), (lang,len(vals),len(KEYS))
    json.dump(dict(zip(KEYS,vals)), open(f'/home/claude/tessera/l10n/parts/10.{lang}.json','w'), ensure_ascii=False, indent=1)
