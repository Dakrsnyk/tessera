"""500 thèmes à l'identité d'Ardane, tous Premium : 25 traitements × 20 couleurs (maquette).

python3 scripts/styles_board_ardane_500.py -> docs/design/2026-11-25-100-styles/planche-ardane-500.png
"""
import os
from PIL import Image, ImageDraw, ImageFont
import styles_board_2026 as B
import styles_board_ardane as A

OUT = os.path.join(B.ROOT, 'docs/design/2026-11-25-100-styles/planche-ardane-500.png')
mx, lum, W, K = A.mx, A.lum, A.W, A.K
dark = lambda a: mx(a, K, .62)

COLORS = A.COLORS + [('Photos', 'D9608B', 5), ('Or', 'C9A54C', 6), ('Corail', 'FF6B5E', 2), ('Menthe', '3CC48F', 3),
                     ('Lavande', 'A78BFA', 6), ('Ciel', '4FA8FF', 7), ('Ambre', 'F2B705', 1), ('Rose', 'FF7AA8', 5),
                     ('Graphite', '6B7280', 0), ('Lagon', '4FD3E8', 7)]

TREATMENTS = A.TREATMENTS + [
    ('Verre Fumé', lambda a: f'g:2A2A2E,{mx(a, K, .6)},1A1A1C', lambda a: W, lambda a: mx(a, W, .35), '', 'bars', 30),
    ('Verre Givré', lambda a: f'g:FFFFFF,{mx(a, W, .7)},EEF2F8', lambda a: '1C1C1E', lambda a: a, 'light', 'spark', 50),
    ('Minuit', lambda a: f'l:0B1426,{mx(a, K, .55)}', lambda a: W, lambda a: mx(a, W, .4), '', 'week', 30),
    ('Aube', lambda a: f'l:{mx(a, W, .8)},{mx(a, W, .35)}', lambda a: dark(a), lambda a: dark(a), '', 'progress', 60),
    ('Néon', lambda a: 's:07070C', lambda a: W, lambda a: mx(a, W, .1), 'glow', 'spark', 20),
    ('Brutal', lambda a: f's:{mx(a, W, .5)}', lambda a: '111111', lambda a: '111111', 'border hard square', 'bars', 40),
    ('Pâte', lambda a: f's:{mx(a, W, .82)}', lambda a: dark(a), lambda a: a, 'clay', 'week', 50),
    ('Grille', lambda a: 's:0B0F14', lambda a: mx(a, W, .7), lambda a: mx(a, W, .2), 'grid caps', 'spark', 24),
    ('Trame', lambda a: f's:{mx(a, W, .88)}', lambda a: dark(a), lambda a: a, 'dots', 'bars', 50),
    ('Éditorial', lambda a: 's:F2EEE4', lambda a: '111111', lambda a: mx(a, K, .15), 'columns caps', 'progress', 22),
    ('Duo Saphir', lambda a: f'l:{a},17B3D0,1D4E9E', lambda a: W, lambda a: W, 'grain', 'week', 40),
    ('Carbone', lambda a: 's:141414', lambda a: 'EDEDED', lambda a: mx(a, W, .15), 'stripes caps', 'progress', 22),
    ('Vague', lambda a: f'l:{mx(a, K, .45)},{mx(a, K, .78)}', lambda a: W, lambda a: mx(a, W, .45), 'waves', 'spark', 30),
    ('Contour', lambda a: 's:FFFFFF', lambda a: '111111', lambda a: a, 'border', 'week', 16),
    ('Pastel', lambda a: f's:{mx(a, W, .62)}', lambda a: mx(a, K, .7), lambda a: mx(a, K, .7), '', 'bars', 60),
]
T, GAP, LEFT, TOP, LABEL = 210, 16, 250, 190, 30
TITLE = 'Ardane · 500 thèmes Premium'
SUB = '25 traitements maison × 20 couleurs · le A en filigrane, le trait du logo, une seule police · tous Premium'

def board():
    S = B.S
    width = LEFT + len(COLORS) * (T + GAP) + GAP
    height = TOP + len(TREATMENTS) * (T + GAP + LABEL) + 20
    page = Image.new('RGB', (width, height), (14, 16, 24))
    d = ImageDraw.Draw(page)
    logo = B.LOGO.resize((84, 84), Image.LANCZOS)
    page.paste(logo, (24, 28), logo)
    d.text((130, 30), TITLE, font=B.font('inter', 52), fill=(255, 255, 255))
    d.text((132, 96), SUB,
           font=B.font('inter', 24, 'Regular'), fill=(165, 172, 190))
    for i, (cname, a, _) in enumerate(COLORS):
        x = LEFT + i * (T + GAP)
        d.ellipse([x, TOP - 34, x + 20, TOP - 14], fill=B.rgb(a))
        d.text((x + 28, TOP - 37), cname, font=B.font('inter', 20), fill=(235, 238, 245))
    small = B.font('inter', 15, 'Regular')
    n = 0
    for r, t in enumerate(TREATMENTS):
        y = TOP + r * (T + GAP + LABEL)
        d.text((24, y + 70), f'{r + 1:02d}', font=B.font('inter', 40), fill=(70, 82, 116))
        d.text((24, y + 122), t[0], font=B.font('inter', 24), fill=(240, 242, 248))
        for i, color in enumerate(COLORS):
            n += 1
            x = LEFT + i * (T + GAP)
            layer, mask = A.card(t, color)
            page.paste(layer.convert('RGB').resize((T, T), Image.LANCZOS), (x, y), mask.resize((T, T), Image.LANCZOS))
            d.text((x + 4, y + T + 5), f'{n}. {t[0]} {color[0]}', font=small, fill=(205, 210, 224))
    page.save(OUT, optimize=True)
    return page

if __name__ == '__main__':
    assert len(TREATMENTS) * len(COLORS) == 500
    p = board()
    print(p.size)
    p.crop((0, 2400, 2500, 4100)).resize((1250, 850)).save(os.path.join(os.environ.get('TEMP', '.'), 'a500-crop.png'))
