import json
chunk = json.load(open('/home/claude/tessera/l10n/chunks/11.json', encoding='utf8'))
def write(lang, tr):
    assert len(tr) == len(chunk), (lang, len(tr), len(chunk))
    out = {c['key']: t for c, t in zip(chunk, tr)}
    json.dump(out, open(f'/home/claude/tessera/l10n/parts/11.{lang}.json', 'w', encoding='utf8'), ensure_ascii=False, indent=1)
