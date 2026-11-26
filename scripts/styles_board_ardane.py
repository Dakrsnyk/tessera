"""Planche « identité Ardane » : 10 traitements maison × les 10 couleurs de l'app = 100 thèmes (maquette).

python3 scripts/styles_board_ardane.py -> docs/design/2026-11-25-100-styles/planche-ardane.png
Ce qui signe Ardane dans chaque vignette : le A en filigrane, le trait dégradé turquoise → bleu roi du logo,
le verre Cristal, une seule police (Inter), la couleur et le contenu de la mini-app.
"""
import os
from PIL import Image, ImageDraw, ImageFont
import styles_board_2026 as B

OUT = os.path.join(B.ROOT, 'docs/design/2026-11-25-100-styles/planche-ardane.png')
INTER = os.path.join(B.ROOT, 'docs/design/2026-11-14-refonte/Inter-opsz.woff2')
try:
    ImageFont.truetype(INTER, 20)
    B.FONTS['inter'] = INTER
except Exception:
    B.FONTS['inter'] = B.FONTS['sys']
B.READABLE.add('inter')
TURQUOISE, ROYAL = (0x17, 0xB3, 0xD0), (0x1D, 0x4E, 0x9E)

# Le A seul, tiré de l'icône (ses deux moitiés sont blanche et bleu pâle).
_a = B.LOGO.resize((220, 220), Image.LANCZOS)
A_MASK = _a.convert('RGB').point(lambda v: 255 if v > 170 else 0).convert('L')
A_MASK = Image.eval(Image.merge('RGB', _a.convert('RGB').split()).convert('L'), lambda v: 0)
_r, _g, _b = _a.convert('RGB').split()
A_MASK = Image.composite(Image.new('L', _a.size, 255), Image.new('L', _a.size, 0),
                         Image.eval(_r, lambda v: 255 if v > 170 else 0))

# Les couleurs de l'app : (nom, hex, mini-app montrée = index dans B.APPS)
COLORS = [('Saphir', '17B3D0', 0), ('Bleu roi', '1D4E9E', 4), ('Nutrition', 'F08A24', 1), ('Fitness', 'E5484D', 2),
          ('Planning', '3366FF', 4), ('Études', 'D6409F', 5), ('Finances', '2F8F7A', 0), ('Business', '8C6CFF', 6),
          ('Voyage', '12A4B5', 7), ('Habitudes', '7FA33A', 3)]

def hx(c): return '%02X%02X%02X' % tuple(c)
def mx(a, b, t): return hx(B.mix(B.rgb(a) if isinstance(a, str) else a, B.rgb(b) if isinstance(b, str) else b, t))
def lum(h): c = B.rgb(h); return (0.299 * c[0] + 0.587 * c[1] + 0.114 * c[2]) / 255
W, K = 'FFFFFF', '000000'

# traitement : (nom, fond(a), encre(a), accent(a), effets, graphique, filigrane 0-255)
TREATMENTS = [
    ('Cristal Nuit', lambda a: f'g:{mx(a, K, .72)},15101F,{mx(a, K, .5)}', lambda a: W, lambda a: mx(a, W, .3), '', 'spark', 40),
    ('Cristal Jour', lambda a: f'g:{mx(a, W, .55)},F4F6FB,{mx(a, W, .8)}', lambda a: '1C1C1E', lambda a: mx(a, K, .1), '', 'spark', 60),
    ('Signature', lambda a: f'l:{mx(a, W, .18)},{mx(a, "1D4E9E", .45)},{mx(a, K, .45)}', lambda a: W, lambda a: W, 'grain', 'bars', 40),
    ('Encre', lambda a: 's:0B0B0F', lambda a: 'F5F5F7', lambda a: mx(a, W, .15), '', 'progress', 16),
    ('Papier', lambda a: 's:F7F5F0', lambda a: '111111', lambda a: mx(a, K, .08), '', 'week', 18),
    ('Aurore', lambda a: f'm:0B1426,{a},17B3D0,1D4E9E', lambda a: W, lambda a: mx(a, W, .55), 'grain', 'spark', 30),
    ('Plein', lambda a: f's:{a}', lambda a: W if lum(a) < .6 else '111111', lambda a: W if lum(a) < .6 else '111111', 'caps', 'bars', 46),
    ('Bento', lambda a: f's:{mx(a, W, .9)}', lambda a: '1C1C1E', lambda a: a, 'bento', 'bento', 0),
    ('Or Premium', lambda a: f's:{mx(a, "0D0C0A", .88)}', lambda a: 'F3E6C4', lambda a: 'C9A54C', 'double caps', 'progress', 44),
    ('Teinté', lambda a: f's:{mx(a, K, .82)}', lambda a: mx(a, W, .72), lambda a: mx(a, W, .45), 'light', 'progress', 34),
]

def card(t, color):
    name, bg, ink, accent, fx, viz, mark = t[:7]
    fkey = t[7] if len(t) > 7 else 'inter'
    cname, a, app = color
    spec = f'{name} {cname}|{bg(a)}|{ink(a)}|{accent(a)}|{fkey}|{fx}|{viz}'
    layer, mask, _, _ = B.card(spec, app, False)
    S = B.S
    # Le A en filigrane, en bas à droite.
    if mark:
        tint = B.rgb(ink(a)) if name != 'Or Premium' else (0xC9, 0xA5, 0x4C)
        wm = Image.new('RGBA', A_MASK.size, tint + (0,))
        wm.putalpha(A_MASK.point(lambda v: v * mark // 255))
        over = Image.new('RGBA', (S, S), (0, 0, 0, 0))
        over.paste(wm, (S - 170, S - 176), wm)
        layer = Image.alpha_composite(layer, over)
    # Le trait du logo : turquoise → bleu roi, sous le libellé.
    if viz != 'bento':
        seam = Image.new('RGB', (2, 1)); seam.putpixel((0, 0), TURQUOISE); seam.putpixel((1, 0), ROYAL if lum(bg(a).split(':')[1][:6]) > .25 else (0x4F, 0xD3, 0xE8))
        seam = seam.resize((54, 5), Image.BILINEAR)
        sm = Image.new('L', (54, 5), 0); ImageDraw.Draw(sm).rounded_rectangle([0, 0, 53, 4], 2, fill=255)
        layer.paste(seam, (24, 60), sm)
    return layer, mask

def board():
    S, gap, left, top, label_h = B.S, 24, 300, 210, 34
    width = left + len(COLORS) * (S + gap) + gap
    height = top + len(TREATMENTS) * (S + gap + label_h) + 20
    page = Image.new('RGB', (width, height), (14, 16, 24))
    d = ImageDraw.Draw(page)
    logo = B.LOGO.resize((84, 84), Image.LANCZOS)
    page.paste(logo, (gap, 30), logo)
    d.text((gap + 106, 34), 'Ardane · 100 thèmes à l’identité de l’app', font=B.font('inter', 50), fill=(255, 255, 255))
    d.text((gap + 108, 98), '10 traitements maison × les 10 couleurs d’Ardane · le A en filigrane, le trait du logo, le verre Cristal, une seule police · ★ gratuit',
           font=ImageFont.truetype(B.WIN + 'seguisym.ttf', 24), fill=(165, 172, 190))
    for i, (cname, a, _) in enumerate(COLORS):
        x = left + i * (S + gap)
        d.ellipse([x, top - 44, x + 26, top - 18], fill=B.rgb(a))
        d.text((x + 36, top - 46), cname, font=B.font('inter', 24), fill=(235, 238, 245))
    sym = ImageFont.truetype(B.WIN + 'seguisym.ttf', 22)
    n = 0
    for r, t in enumerate(TREATMENTS):
        y = top + r * (S + gap + label_h)
        d.text((gap, y + 110), f'{chr(65 + r)}', font=B.font('inter', 64), fill=(60, 70, 100))
        d.text((gap + 60, y + 124), t[0], font=B.font('inter', 28), fill=(240, 242, 248))
        d.text((gap + 60, y + 162), '1 gratuit · 9 Premium', font=B.font('inter', 18, 'Regular'), fill=(140, 148, 168))
        for i, color in enumerate(COLORS):
            n += 1
            x = left + i * (S + gap)
            layer, mask = card(t, color)
            page.paste(layer.convert('RGB'), (x, y), mask)
            d.text((x + 6, y + S + 6), f'{n}. {t[0]} {color[0]}' + ('  ★' if i == 0 else ''), font=sym, fill=(215, 220, 232))
    page.save(OUT, optimize=True)
    return page

if __name__ == '__main__':
    p = board()
    print(OUT, p.size, 'Inter' if B.FONTS['inter'] == INTER else 'Inter absente : police système')
    p.resize((p.width // 3, p.height // 3)).save(os.path.join(os.environ.get('TEMP', '.'), 'ardane-mini.png'))
