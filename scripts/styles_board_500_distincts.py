"""500 thèmes Ardane différents par leur structure (la couleur reste au choix de l'utilisateur), tous Premium.

python3 scripts/styles_board_500_distincts.py -> docs/design/2026-11-25-100-styles/planche-500-distincts.png + themes-500-distincts.md
Chaque thème combine un fond, une police, un décor (texture, bord, relief), un graphique et une casse ;
deux thèmes diffèrent sur au moins deux axes, et un même fond n'a jamais deux fois la même police avec le même décor. La planche montre tout en Saphir.
"""
import itertools, os, random
from PIL import Image, ImageDraw
import styles_board_2026 as B
import styles_board_ardane as A

OUT = os.path.join(B.ROOT, 'docs/design/2026-11-25-100-styles')
C = '17B3D0'          # la couleur de l'utilisateur sur la planche
mx, W, K = A.mx, 'FFFFFF', '000000'

# fond : (nom de catégorie, mot du nom, fond, encre, accent)
BGS = [
    ('Clair', 'Blanc', 's:FFFFFF', '1C1C1E', C), ('Sombre', 'Nuit', 's:0B0B0F', 'F5F5F7', C),
    ('Plein', 'Plein', f's:{C}', W, W), ('Dégradé', 'Signature', f'l:{mx(C, W, .2)},{mx(C, "1D4E9E", .6)}', W, W),
    ('Verre', 'Verre', f'g:{mx(C, W, .55)},F4F6FB,{mx(C, W, .8)}', '1C1C1E', mx(C, K, .1)),
    ('Verre sombre', 'Cristal', f'g:{mx(C, K, .72)},15101F,{mx(C, K, .5)}', W, mx(C, W, .3)),
    ('Maillage', 'Aurore', f'm:0B1426,{C},1D4E9E,0B1426', W, mx(C, W, .5)),
    ('Aura', 'Aura', f'm:{mx(C, W, .85)},{C},{mx(C, "FF9AE1", .5)},{mx(C, W, .9)}', mx(C, K, .6), mx(C, K, .6)),
    ('Papier', 'Papier', 's:F5F0E6', '1F1A12', mx(C, K, .15)), ('Chrome', 'Chrome', f'l:{mx(C, W, .85)},8E8E93,F2F2F2', '111111', mx(C, K, .5)),
    ('Teinté clair', 'Pastel', f's:{mx(C, W, .82)}', mx(C, K, .65), mx(C, K, .4)), ('Teinté sombre', 'Abysse', f's:{mx(C, K, .82)}', mx(C, W, .75), mx(C, W, .4)),
    ('Duo', 'Duo', f'l:{C},{mx(C, "FF4F9A", .7)}', W, W), ('Luxe', 'Or', 's:0D0C0A', 'F3E6C4', 'C9A54C'),
]
FONTS = [('inter', 'Inter'), ('sysl', 'Fin'), ('sysblack', 'Massif'), ('bodoni', 'Bodoni'), ('playfair', 'Playfair'),
         ('dmital', 'Italique'), ('mono', 'Code'), ('orbitron', 'Orbite'), ('fredoka', 'Rond'), ('archivo', 'Affiche'),
         ('bebas', 'Étroit'), ('righteous', 'Rétro'), ('press', 'Pixel'), ('italiana', 'Couture'), ('comfortaa', 'Bulle'),
         ('gloock', 'Gloock'), ('anton', 'Titre'), ('quicksand', 'Doux')]
DECOS = [('', 'Pur'), ('grain', 'Grain'), ('border', 'Cadre'), ('double', 'Filet'), ('dashed', 'Ticket'),
         ('border hard square', 'Brutal'), ('glow', 'Néon'), ('clay', 'Pâte'), ('gloss', 'Brillant'), ('grid', 'Grille'),
         ('dots', 'Points'), ('scan', 'Écran'), ('halftone', 'Trame'), ('waves', 'Vague'), ('stripes', 'Rayé'),
         ('topo', 'Relief'), ('pixel', 'Damier'), ('columns', 'Colonne')]
VIZ = [('ring', 'Anneau'), ('bars', 'Barres'), ('spark', 'Courbe'), ('week', 'Semaine'), ('progress', 'Jauge'), ('bento', 'Bento')]
CASES = [('', ''), ('caps', 'Capitales'), ('light', 'Léger')]

def pick(n=500, seed=2026):
    combos = list(itertools.product(range(len(BGS)), range(len(FONTS)), range(len(DECOS)), range(len(VIZ)), range(len(CASES))))
    random.Random(seed).shuffle(combos)
    chosen, per_bg = [], {b: 0 for b in range(len(BGS))}
    cap = n // len(BGS) + 1
    for c in combos:
        if per_bg[c[0]] >= cap:
            continue
        # Au moins 2 axes différents, et jamais la même police avec le même décor dans un même fond.
        if all(sum(x != y for x, y in zip(c, o)) >= 2 and (c[0], c[1], c[2]) != (o[0], o[1], o[2]) for o in chosen):
            chosen.append(c)
            per_bg[c[0]] += 1
            if len(chosen) == n:
                break
    return sorted(chosen)

def theme(c):
    b, f, d, v, k = c
    cat, word, bg, ink, acc = BGS[b]
    name = f'{word} {FONTS[f][1]} {DECOS[d][1]}'
    fx = ' '.join(x for x in (DECOS[d][0], CASES[k][0]) if x)
    if VIZ[v][0] == 'bento': fx = (fx + ' bento').strip()
    spec = f'{name}|{bg}|{ink}|{acc}|{FONTS[f][0]}|{fx}|{VIZ[v][0]}'
    return cat, name, spec

def board(items):
    T, GAP, COLS, top = 200, 14, 20, 170
    cats = []
    for it in items:
        if not cats or cats[-1][0] != it[0]: cats.append((it[0], []))
        cats[-1][1].append(it)
    rows = sum((len(c[1]) + COLS - 1) // COLS for c in cats)
    width = COLS * (T + GAP) + GAP
    height = top + len(cats) * 52 + rows * (T + 30) + 20
    page = Image.new('RGB', (width, height), (14, 16, 24))
    d = ImageDraw.Draw(page)
    logo = B.LOGO.resize((80, 80), Image.LANCZOS); page.paste(logo, (GAP, 28), logo)
    d.text((GAP + 100, 30), 'Ardane · 500 thèmes différents', font=B.font('inter', 50), fill=(255, 255, 255))
    d.text((GAP + 102, 94), 'Tous Premium · la couleur est au choix (ici Saphir) · jamais deux fois la même police avec le même décor sur un même fond',
           font=B.font('inter', 22, 'Regular'), fill=(165, 172, 190))
    small = B.font('inter', 13, 'Regular')
    y, n = top, 0
    for cat, its in cats:
        d.text((GAP, y + 8), f'{cat}  ·  {len(its)}', font=B.font('inter', 30), fill=(235, 238, 245))
        y += 52
        for i, (_, name, spec) in enumerate(its):
            n += 1
            x = GAP + (i % COLS) * (T + GAP)
            yy = y + (i // COLS) * (T + 30)
            layer, mask, _, _ = B.card(spec, n - 1, False)
            page.paste(layer.convert('RGB').resize((T, T), Image.LANCZOS), (x, yy), mask.resize((T, T), Image.LANCZOS))
            d.text((x + 2, yy + T + 4), f'{n}. {name}', font=small, fill=(205, 210, 224))
        y += ((len(its) + COLS - 1) // COLS) * (T + 30)
    path = os.path.join(OUT, 'planche-500-distincts.png')
    page.save(path, optimize=True)
    return path, page

if __name__ == '__main__':
    chosen = pick()
    items = [theme(c) for c in chosen]
    assert len({i[1] for i in items}) == len(items), 'noms en double'
    lines = ['# Ardane : 500 thèmes différents (2026-11-25)', '', 'Tous Premium ; couleur au choix de l’utilisateur. Axes : fond, police, décor, graphique, casse ; jamais deux fois la même police avec le même décor sur un même fond.', '',
             '| # | Catégorie | Thème | Police | Décor | Graphique | Casse |', '|---|---|---|---|---|---|---|']
    for n, (c, (cat, name, _)) in enumerate(zip(chosen, items), 1):
        lines.append(f'| {n} | {cat} | {name} | {FONTS[c[1]][1]} | {DECOS[c[2]][1]} | {VIZ[c[3]][1]} | {CASES[c[4]][1] or "normale"} |')
    open(os.path.join(OUT, 'themes-500-distincts.md'), 'w', encoding='utf-8').write('\n'.join(lines) + '\n')
    path, page = board(items)
    print(len(items), page.size)
    page.crop((0, 0, 2200, 1500)).resize((1100, 750)).save(os.path.join(os.environ.get('TEMP', '.'), 'd500.png'))
