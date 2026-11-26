"""Planche des 100 styles d'Ardane, tendances 2026 (maquette, pas le rendu de l'app).

python3 scripts/styles_board_2026.py  ->  docs/design/2026-11-25-100-styles/planche-100-v2.png
Chaque vignette est un widget Ardane (mini-app, chiffre, graphique) dans un style ; ★ = gratuit.
"""
import glob, math, os, random
from PIL import Image, ImageDraw, ImageFilter, ImageFont, ImageChops

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, 'docs/design/2026-11-25-100-styles/planche-100-v2.png')
LOGO = Image.open(os.path.join(ROOT, 'docs/marque/logo-2026-11-19/ardane-0-actuel-1024.png')).convert('RGBA')
WIN = 'C:/Windows/Fonts/'
FILES = {os.path.basename(p).split('.')[0].lower(): p for p in glob.glob(os.path.join(ROOT, '**/*.[to]tf'), recursive=True)
         if 'node_modules' not in p}
FONTS = {
    'sys': WIN + 'segoeuib.ttf', 'sysr': WIN + 'segoeui.ttf', 'sysl': WIN + 'segoeuil.ttf', 'sysblack': WIN + 'seguibl.ttf',
    'mono': 'spacemono-bold', 'courier': 'courierprime-bold', 'poppins': 'poppins-bold', 'playfair': 'playfairdisplay-variable',
    'bodoni': 'bodonimoda-variable', 'dmserif': 'dmserifdisplay-regular', 'dmital': 'dmserifdisplay-italic', 'gloock': 'gloock-regular',
    'italiana': 'italiana-regular', 'cinzel': 'cinzel-variable', 'marcellus': 'marcellus-regular', 'lora': 'lora-variable',
    'orbitron': 'orbitron-variable', 'audiowide': 'audiowide-regular', 'press': 'pressstart2p-regular', 'monoton': 'monoton-regular',
    'bungee': 'bungee-regular', 'archivo': 'archivoblack-regular', 'anton': 'anton-regular', 'bebas': 'bebasneue-regular',
    'righteous': 'righteous-regular', 'fredoka': 'fredoka-variable', 'quicksand': 'quicksand-variable', 'comfortaa': 'comfortaa-variable',
    'chewy': 'chewy-regular', 'shrikhand': 'shrikhand-regular', 'abril': 'abrilfatface-regular', 'limelight': 'limelight-regular',
    'poiret': 'poiretone-regular', 'raleway': 'raleway-variable', 'josefin': 'josefinsans-variable', 'special': 'specialelite-regular',
    'marker': 'permanentmarker-regular', 'patrick': 'patrickhand-regular', 'bangers': 'bangers-regular', 'oswald': 'oswald-variable',
}
READABLE = {'sys', 'sysr', 'sysl', 'mono', 'courier', 'poppins', 'quicksand', 'raleway', 'josefin', 'lora', 'fredoka', 'comfortaa',
            'oswald', 'special', 'patrick', 'sysblack'}
_cache = {}

def font(key, size, weight='Bold'):
    k = (key, size, weight)
    if k not in _cache:
        path = FONTS.get(key, FONTS['sys'])
        path = path if path.startswith('C:') else FILES.get(path, FONTS['sys'])
        f = ImageFont.truetype(path, size)
        try:
            f.set_variation_by_name(weight)
        except Exception:
            pass
        _cache[k] = f
    return _cache[k]

def rgb(h): return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))
def mix(a, b, t): return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))

# Ce que montre chaque mini-app : titre, couleur, libellé, chiffre, unité, détail, part (anneau/barre).
APPS = [
    ('Finances', '2B9A66', 'Reste ce mois', '1 550', '$', '258 $ par jour · 6 jours', 0.77),
    ('Nutrition', 'F08A24', 'Calories restantes', '1 240', 'kcal', 'P 92 · G 180 · L 48', 0.52),
    ('Fitness', 'E5484D', 'Séance du jour', 'Jambes', '', 'Série 3 sur 5 · 80 kg', 0.6),
    ('Habitudes', '7FA33A', 'Série', '12', 'jours', 'Lire · Marcher · Méditer', 0.86),
    ('Planning', '3366FF', 'Prochain', '14:30', '', 'Maths · salle B-204', 0.35),
    ('Études', 'D6409F', 'Examen', 'J-3', '', 'Chimie · A-110', 0.7),
    ('Business', '8C6CFF', 'Ventes du mois', '4 820', '$', '+18 % face à octobre', 0.64),
    ('Voyage', '12A4B5', 'Rome', 'J-12', '', 'Vol AF 1404 · 9:40', 0.4),
]

# nom | fond | encre | accent | police | effets | graphique
# fond : s:HEX (uni) · l:HEX,HEX[,HEX] (dégradé) · m:HEX,HEX,HEX,HEX (maillage) · g:HEX,HEX,HEX (verre liquide)
# effets : grain border double dashed pixel hard glow clay caps ital light square pill scan dots grid stripes stars
FAMILIES = [
    ('Verre liquide', [
        'Verre Clair|g:A5C8FF,FFD6E8,C9F2E4|1C1C1E|3366FF|sys|caps|ring',
        'Verre Nuit|g:1B1F3B,3B2A6B,0E5A6B|FFFFFF|8FD3FF|sys|caps|spark',
        'Verre Aurore|g:FF9A8B,FF6A88,FFC796|FFFFFF|FFFFFF|sys||bars',
        'Verre Menthe|g:B8F2D8,7ED9C3,E8FFF6|10372C|0FA37F|sysr||ring',
        'Verre Corail|g:FFB199,FF6B6B,FFE29A|3A1010|E5484D|poppins||progress',
        'Verre Fumé|g:2A2A2E,4A4A52,1A1A1C|F5F5F7|D0D0D6|sysl|light|spark',
        'Verre Lilas|g:D7C4FF,B7A4F5,F6D9FF|2A1B4D|7C5CFF|quicksand||week',
        'Verre Océan|g:0F4C81,1CA7EC,7FE3F0|FFFFFF|BFF3FF|sys|caps|bars',
        'Verre Ambre|g:FFB347,FF7E5F,FFE0A3|3B1E00|FF7E00|sys||ring',
        'Verre Prisme|g:FF9AE1,9AD0FF,FFF59A|1C1C1E|7C5CFF|sys|grain|bars',
    ]),
    ('Dégradés aurore', [
        'Aurore Boréale|m:0B1D3A,1FD1A5,6A3DE8,0B1D3A|FFFFFF|7DFFCF|sys|grain|spark',
        'Pêche Fondue|m:FFD3B6,FFAAA5,FFE8D6,FF8B94|3D1F1A|E8505B|poppins|grain|ring',
        'Cobalt|m:0A1E6E,2F5BFF,00C2FF,0A1E6E|FFFFFF|FFFFFF|sysblack||bars',
        'Iris|m:5B2EFF,C13BFF,FF6EC7,3B1EB8|FFFFFF|FFE1F4|sys|grain|ring',
        'Sorbet|m:FFF1A8,FFB3C7,B5E8FF,FFD6A5|3A2440|FF4F8B|fredoka||week',
        'Néon Doux|m:00F5D4,9B5DE5,F15BB5,00BBF9|FFFFFF|FFFFFF|sys|grain|spark',
        'Crépuscule|m:2B1055,D53A9D,FF9068,2B1055|FFFFFF|FFC36E|sys|caps|progress',
        'Lagon|m:00B4D8,90E0EF,00F5A0,0077B6|073B4C|FFFFFF|sysr||ring',
        'Bonbon|m:FFC6FF,BDB2FF,A0C4FF,FFADAD|3B1E54|FF5FA2|chewy||bars',
        'Holo|m:E0C3FC,8EC5FC,F9F586,C2FFD8|1C1C1E|5E3BEE|sys|grain|spark',
    ]),
    ('Luxe discret', [
        'Lin|s:EFE9DF|2E2A24|9C7A4D|dmserif|grain|progress',
        'Moka|s:3B2A22|F3E7D8|C8A27A|playfair|grain|spark',
        'Ivoire Or|s:F8F3E6|1F1A12|B8913A|bodoni|double caps|ring',
        'Noir Or|s:0D0C0A|F3E6C4|C9A54C|cinzel|border caps|progress',
        'Bordeaux|s:4A0E1E|F6E3E7|E8B4A0|gloock|grain|spark',
        'Vert Anglais|s:123D2E|EFE6D2|C9A54C|playfair|double|ring',
        'Sable|s:E6D5BC|3A2E20|8C6A43|italiana|caps light|bars',
        'Taupe|s:8B7D72|FBF7F2|FFFFFF|marcellus|caps|week',
        'Marbre|m:F4F2EF,DCD8D2,FFFFFF,C9C4BC|2B2B2B|8A7F72|bodoni|grain|ring',
        'Champagne|l:F7E7CE,E3C9A0|3A2A14|9B6B2C|dmital|grain|progress',
    ]),
    ('Couleurs dopamine', [
        'Tomate|s:FF4D2E|FFF4E8|FFE14D|archivo||bars',
        'Citron|s:F5F02A|141414|141414|archivo|hard|ring',
        'Bleu Klein|s:0033FF|FFFFFF|FFD400|anton|caps|progress',
        'Rose Barbie|s:FF3FA4|FFFFFF|FFE14D|shrikhand||spark',
        'Vert Pomme|s:7CFF6B|0B2E0B|0B2E0B|sysblack|hard|bars',
        'Orange Pop|s:FF8A00|1A0E00|FFFFFF|bebas|caps|ring',
        'Violet Électrique|s:6B2BFF|FFFFFF|C6FF3D|sysblack||week',
        'Turquoise|s:00D1C1|04312D|FFFFFF|righteous||progress',
        'Duo Pop|l:FF3FA4,FFD400|1A1A1A|1A1A1A|archivo|hard|bars',
        'Arc-en-ciel|l:FF5F6D,FFC371,47E891,3FA9F5,A35BFF|FFFFFF|FFFFFF|sysblack|grain|spark',
    ]),
    ('Néo-brutalisme et bento', [
        'Brutal Jaune|s:FFE14D|111111|FF3FA4|archivo|border hard square|bars',
        'Brutal Rose|s:FFB3D9|111111|3366FF|archivo|border hard square|ring',
        'Brutal Bleu|s:9DB8FF|111111|FFE14D|sysblack|border hard square|progress',
        'Bento Crème|s:F4EFE6|1C1C1E|FF6B3D|sys|bento|bento',
        'Bento Nuit|s:111114|F5F5F7|7C5CFF|sys|bento|bento',
        'Sticker|s:FFFFFF|111111|00C2A8|bungee|border hard|ring',
        'Gumroad|s:FF90E8|000000|000000|mono|border hard square caps|bars',
        'Tableau Noir|s:23292E|F2F2F2|F7D354|marker|chalk|spark',
        'Post-it|s:FFF07A|3A3200|E5484D|patrick|hard|week',
        'Ticket|s:FFF6E5|2A1E12|E5484D|courier|dashed caps|progress',
    ]),
    ('Y2K et chrome', [
        'Chrome Liquide|l:F2F2F2,8E8E93,FFFFFF,6E6E73|111111|111111|orbitron|grain|ring',
        'Bulle Y2K|m:B8F1FF,FFD1F7,E6E6FF,9EE7FF|2A1B6B|FF4FD8|comfortaa|glow|spark',
        'Aqua 2001|l:CFF3FF,4FB3FF,0A6CFF|FFFFFF|FFFFFF|sys|gloss|progress',
        'Cyber Rose|s:1A0014|FF7AD9|FF2BD6|audiowide|glow scan|bars',
        'Holographique|m:FFB6F2,B6F2FF,F2FFB6,D6B6FF|1C1C1E|1C1C1E|orbitron|grain|ring',
        'Lave|m:FF2A00,FF8C00,3B0000,FF5100|FFF3E0|FFE14D|righteous|glow|spark',
        'Pixel Pastel|s:FDE2FF|5B2A86|FF6EC7|press|pixel|week',
        'Game Boy|s:9BBC0F|0F380F|306230|press|pixel|bars',
        'Synthwave|l:2D0B4E,7A1C8C,F72585|FFE6FF|FFB800|monoton|grid glow|spark',
        'Vaporwave|l:FF9DE6,9AF5FF|3B1E54|3B1E54|righteous|grid|ring',
    ]),
    ('Sombre et technique', [
        'OLED|s:000000|F5F5F7|30D158|sys||ring',
        'Terminal|s:020A04|33FF66|33FF66|mono|scan|spark',
        'Néon Tokyo|s:0A0014|FFFFFF|00F0FF|audiowide|glow border|bars',
        'HUD|s:05121C|9FE8FF|00D1FF|orbitron|grid caps|ring',
        'Graphite|s:1C1C1E|E5E5EA|FF9F0A|sys|grain|progress',
        'Matrice|s:000000|00FF41|00FF41|mono|scan|week',
        'Ambre CRT|s:120A00|FFB000|FFB000|mono|scan glow|spark',
        'Datacenter|s:0B0F14|C9D1D9|58A6FF|mono|dots|bars',
        'Carbone|s:141414|EDEDED|FF3B30|oswald|stripes caps|progress',
        'Cockpit|s:0E1116|F2F4F7|FFD60A|sysblack|border caps|ring',
    ]),
    ('Doux et pâte à modeler', [
        'Argile|s:E9DDD3|5A4337|D9826B|fredoka|clay|ring',
        'Nuage|s:EEF3FF|33405C|7A9CFF|quicksand|clay|spark',
        'Guimauve|s:FFE3EE|6B2B45|FF7AA8|fredoka|clay|bars',
        'Pistache|s:E3F4D7|2E4A1F|7FBF4D|comfortaa|clay|week',
        'Lavande|s:ECE6FF|3E2F6B|8C6CFF|quicksand|clay|ring',
        'Pêche Douce|s:FFE7D6|6B3A1F|FF9A62|fredoka|clay|progress',
        'Bébé Bleu|s:E0F2FF|1F3A5C|4FA8FF|comfortaa|clay|bars',
        'Beurre|s:FFF5CC|5C4A12|F2B705|fredoka|clay|spark',
        'Sakura|s:FFEAF1|6B2B45|F27BA0|quicksand|clay|week',
        'Coton|s:F7F7FA|3A3A48|A3A3FF|sysr|clay|ring',
    ]),
    ('Nature et matières', [
        'Forêt|l:1E3D2F,0F241B|E8F1E4|8FD694|lora|grain|spark',
        'Mousse|s:4F6B3A|F1F4E6|D9E8A0|lora|grain|ring',
        'Terracotta|s:C8643B|FFF2E8|FFE0C2|dmserif|grain|bars',
        'Désert|l:F2C89B,D9895B|3A1E0E|7A2E0E|josefin|grain caps|progress',
        'Océan Profond|l:00334E,005B82|E3F6FF|4FD1FF|sys|waves|spark',
        'Topographie|s:EDE6D6|3B3325|C46A2A|josefin|topo|ring',
        'Herbier|s:F3EFE2|33402A|6E8B3D|playfair|grain|week',
        'Ardoise|s:3C4148|E8ECEF|9FB4C7|sys|grain|bars',
        'Glacier|l:EAF6FF,BFE3FF|0F3550|1C8FD6|raleway|light|spark',
        'Volcan|l:1A0A06,4A1208|FFE6D9|FF5A1F|anton|glow caps|progress',
    ]),
    ('Éditorial et imprimé', [
        'Journal|s:F2EEE4|111111|111111|playfair|columns|progress',
        'Magazine|s:FFFFFF|111111|E5004F|abril|border|ring',
        'Risographie|s:FBF5E8|1A3FA8|FF4F7B|archivo|dots grain|bars',
        'Suisse|s:F4F1EA|111111|E4002B|sysblack|grid|progress',
        'Trame BD|s:FFE14D|111111|E5004F|bangers|halftone border|spark',
        'Typographie|s:111111|F5F5F5|F5F5F5|bodoni|caps|week',
        'Affiche|s:E9E1CF|1D1D1B|D2381F|anton|caps grain|bars',
        'Riso Duo|l:FF6F91,3E64FF|FFFFFF|FFFFFF|archivo|grain halftone|ring',
        'Manuscrit|s:FBF8F1|1F2A44|1F2A44|special|lines|spark',
        'Fiche Technique|s:FFFFFF|111111|0055FF|mono|grid border caps|bars',
    ]),
]

S = 320          # côté d'une vignette
R_DEF = 64       # rayon des coins d'un widget iOS à cette échelle

def background(spec):
    kind, colors = spec.split(':')
    cs = [rgb(c) for c in colors.split(',')]
    if kind == 's':
        return Image.new('RGB', (S, S), cs[0])
    if kind == 'l':
        strip = Image.new('RGB', (1, len(cs)))
        for i, c in enumerate(cs): strip.putpixel((0, i), c)
        # Dégradé plus grand que la vignette, tourné puis recadré : aucun coin vide.
        big = strip.resize((S * 2, S * 2), Image.BICUBIC).rotate(-25, resample=Image.BICUBIC)
        return big.crop((S // 2, S // 2, S // 2 + S, S // 2 + S))
    if kind == 'm':
        img = Image.new('RGB', (S, S), cs[0])
        d = ImageDraw.Draw(img)
        r = random.Random(sum(sum(c) for c in cs))
        for i, c in enumerate(cs[1:] * 2):
            x, y, rad = r.randrange(-60, S + 60), r.randrange(-60, S + 60), r.randrange(120, 230)
            d.ellipse([x - rad, y - rad, x + rad, y + rad], fill=c)
        return img.filter(ImageFilter.GaussianBlur(70))
    # Verre liquide : des taches de couleur floues, puis une plaque givrée par-dessus.
    img = Image.new('RGB', (S, S), mix(cs[0], cs[1], 0.5))
    d = ImageDraw.Draw(img)
    for (x, y, rad), c in zip([(40, 60, 150), (280, 90, 130), (170, 300, 170), (300, 300, 90)], cs + cs[:1]):
        d.ellipse([x - rad, y - rad, x + rad, y + rad], fill=c)
    img = img.filter(ImageFilter.GaussianBlur(40))
    frost = Image.new('RGBA', (S, S), (255, 255, 255, 46 if sum(cs[0]) > 380 else 26))
    img = Image.alpha_composite(img.convert('RGBA'), frost)
    hl = Image.new('L', (S, S), 0)
    ImageDraw.Draw(hl).ellipse([-S * 0.3, -S * 0.9, S * 1.3, S * 0.35], fill=70)
    img.paste(Image.new('RGBA', (S, S), (255, 255, 255, 255)), (0, 0), hl.filter(ImageFilter.GaussianBlur(30)))
    return img.convert('RGB')

def pattern(img, fx, ink):
    d = ImageDraw.Draw(img, 'RGBA')
    c = lambda a: ink + (a,)
    r = random.Random(3)
    if 'scan' in fx:
        for y in range(0, S, 4): d.line([(0, y), (S, y)], fill=(0, 0, 0, 70))
    if 'grid' in fx:
        for v in range(0, S, 20):
            d.line([(v, 0), (v, S)], fill=c(22)); d.line([(0, v), (S, v)], fill=c(22))
    if 'dots' in fx:
        for y in range(10, S, 16):
            for x in range(10, S, 16): d.ellipse([x - 1.5, y - 1.5, x + 1.5, y + 1.5], fill=c(40))
    if 'halftone' in fx:
        for y in range(6, S, 11):
            for x in range(6 + (y // 11 % 2) * 5, S, 11):
                s = 0.5 + (x + y) / (2 * S) * 4
                d.ellipse([x - s, y - s, x + s, y + s], fill=c(45))
    if 'stripes' in fx:
        for x in range(-S, S, 8): d.line([(x, S), (x + S, 0)], fill=c(14), width=3)
    if 'lines' in fx:
        for y in range(40, S, 26): d.line([(0, y), (S, y)], fill=(90, 130, 200, 60))
    if 'waves' in fx or 'topo' in fx:
        for k, y0 in enumerate(range(-10, S + 20, 18 if 'topo' in fx else 26)):
            pts = [(x, y0 + math.sin(x / 34 + k * 0.7) * 10 + math.sin(x / 13 + k) * 3) for x in range(0, S + 8, 8)]
            d.line(pts, fill=c(30), width=1 if 'topo' in fx else 2)
    if 'columns' in fx:
        d.line([(S * 0.62, 30), (S * 0.62, S - 30)], fill=c(60), width=1)
    if 'pixel' in fx:
        for y in range(0, S, 10):
            for x in range((y // 10 % 2) * 10, S, 20): d.rectangle([x, y, x + 9, y + 9], fill=c(14))
    if 'chalk' in fx:
        for _ in range(500):
            x, y = r.randrange(S), r.randrange(S); d.line([(x, y), (x + r.randrange(2, 9), y + r.randrange(-1, 2))], fill=(255, 255, 255, 14))

def grain(img, amount):
    noise = Image.effect_noise((S, S), 64).convert('RGB')
    return ImageChops.blend(img, ImageChops.overlay(img, noise), amount)

def viz(d, kind, box, ink, accent, part, f_small, apphex):
    x0, y0, x1, y1 = box
    w, h = x1 - x0, y1 - y0
    faint = ink + (45,)
    if kind == 'ring':
        cx, cy, rad = x1 - h / 2, y0 + h / 2 - 34, 46
        d.ellipse([cx - rad, cy - rad, cx + rad, cy + rad], outline=faint, width=12)
        d.arc([cx - rad, cy - rad, cx + rad, cy + rad], -90, -90 + 360 * part, fill=accent, width=12)
        d.text((cx, cy), f'{int(part * 100)} %', font=f_small, fill=ink, anchor='mm')
    elif kind == 'bars':
        vals = [0.45, 0.7, 0.38, 0.9, 0.62, 0.8, part]
        bw = w / len(vals)
        for i, v in enumerate(vals):
            bx = x0 + i * bw + bw * 0.2
            d.rounded_rectangle([bx, y1 - h * v, bx + bw * 0.6, y1], 5, fill=accent if i == len(vals) - 1 else faint)
    elif kind == 'spark':
        vals = [0.3, 0.42, 0.35, 0.6, 0.5, 0.72, 0.66, 0.88]
        pts = [(x0 + i * w / (len(vals) - 1), y1 - h * v) for i, v in enumerate(vals)]
        poly = pts + [(x1, y1), (x0, y1)]
        d.polygon(poly, fill=accent + (55,))
        d.line(pts, fill=accent, width=4, joint='curve')
        d.ellipse([pts[-1][0] - 6, pts[-1][1] - 6, pts[-1][0] + 6, pts[-1][1] + 6], fill=accent)
    elif kind == 'week':
        days = 'LMMJVSD'
        step = w / 7
        for i, ch in enumerate(days):
            cx = x0 + step * (i + 0.5)
            done = i < 5
            d.ellipse([cx - 14, y1 - 30, cx + 14, y1 - 2], fill=accent if done else faint)
            d.text((cx, y1 - 16), ch, font=f_small, fill=ink if not done else (255, 255, 255) if sum(accent) < 500 else (20, 20, 20), anchor='mm')
    elif kind == 'progress':
        d.rounded_rectangle([x0, y1 - 14, x1, y1], 7, fill=faint)
        d.rounded_rectangle([x0, y1 - 14, x0 + w * part, y1], 7, fill=accent)
        d.line([(x0 + w * 0.8, y1 - 22), (x0 + w * 0.8, y1 + 8)], fill=ink, width=2)

def card(spec, index, free):
    name, bg, inkh, acch, fkey, fx, vk = spec.split('|')
    fx = fx.split()
    ink, accent = rgb(inkh), rgb(acch)
    app = APPS[index % len(APPS)]
    appname, apphex, label, value, unit, detail, part = app
    img = background(bg)
    pattern(img, fx, ink)
    if 'grain' in fx: img = grain(img, 0.22)
    radius = 18 if 'square' in fx else (S // 2 if 'pill' in fx else R_DEF)
    layer = img.convert('RGBA')
    d = ImageDraw.Draw(layer, 'RGBA')
    lab_key = fkey if fkey in READABLE else 'sysr'
    small = font(lab_key, 19, 'Regular')

    # En-tête : la pastille de la mini-app et son nom, le logo d'Ardane à droite.
    d.rounded_rectangle([24, 24, 50, 50], 8, fill=rgb(apphex))
    d.text((37, 37), appname[0], font=font('sys', 16), fill=(255, 255, 255), anchor='mm')
    head = appname.upper() if 'caps' in fx else appname
    d.text((60, 37), head, font=font(lab_key, 19, 'Bold' if 'light' not in fx else 'Regular'), fill=ink, anchor='lm')
    logo = LOGO.resize((28, 28), Image.LANCZOS)
    lm = Image.new('L', (28, 28), 0); ImageDraw.Draw(lm).rounded_rectangle([0, 0, 27, 27], 7, fill=255)
    layer.paste(logo, (S - 52, 23), lm)

    if vk == 'bento':
        # Quatre cases : le chiffre, l'anneau, la semaine, une ligne.
        base = rgb(bg.split(':')[1].split(',')[0])
        cell = mix(base, ink, 0.07) if sum(base) > 380 else mix(base, (255, 255, 255), 0.09)
        boxes = [(24, 66, 196, 190), (204, 66, S - 24, 190), (24, 198, 160, S - 24), (168, 198, S - 24, S - 24)]
        for b in boxes: d.rounded_rectangle(b, 22, fill=cell)
        d.text((40, 82), label, font=small, fill=ink + (170,))
        d.text((40, 108), value, font=font(fkey, 52), fill=ink)
        viz(d, 'ring', (204, 66 + 34 + 20, S - 24 - 18, 190 - 18), ink, accent, part, font('sys', 15), apphex)
        viz(d, 'bars', (40, 214, 146, S - 40), ink, accent, part, small, apphex)
        d.text((184, 214), detail.split(' · ')[0], font=font(lab_key, 20), fill=ink)
        d.text((184, 244), detail.split(' · ')[-1], font=small, fill=ink + (150,))
    else:
        lab = label.upper() if 'caps' in fx else label
        d.text((24, 74), lab, font=small, fill=ink + (175,))
        size = 74
        vf = font(fkey, size, 'Light' if 'light' in fx else 'Bold')
        while d.textlength(value, font=vf) > S - 48 - (d.textlength(unit, font=small) + 10 if unit else 0) - (110 if vk == 'ring' else 0):
            size -= 3; vf = font(fkey, size, 'Light' if 'light' in fx else 'Bold')
        pos = (24, 104)
        if 'hard' in fx:
            d.text((pos[0] + 5, pos[1] + 5), value, font=vf, fill=accent if accent != ink else (255, 255, 255))
        if 'glow' in fx:
            g = Image.new('RGBA', (S, S), (0, 0, 0, 0))
            ImageDraw.Draw(g).text(pos, value, font=vf, fill=accent + (255,))
            layer = Image.alpha_composite(layer, g.filter(ImageFilter.GaussianBlur(10)))
            d = ImageDraw.Draw(layer, 'RGBA')
        d.text(pos, value, font=vf, fill=ink)
        if unit:
            bb = d.textbbox(pos, value, font=vf)
            d.text((bb[2] + 8, bb[3] - 4), unit, font=font(lab_key, 22), fill=ink + (190,), anchor='ls')
        d.text((24, 200), detail, font=small, fill=ink + (165,))
        viz(d, vk, (24, 236, S - 24, S - 30) if vk != 'ring' else (24, 70, S - 24, 250), ink, accent, part, font('sys', 15), apphex)

    if 'clay' in fx:
        # Pâte à modeler : lumière en haut à gauche, ombre en bas à droite, à l'intérieur du bord.
        sh = Image.new('L', (S, S), 0)
        ImageDraw.Draw(sh).rounded_rectangle([14, 14, S + 30, S + 30], radius, outline=255, width=28)
        layer = Image.alpha_composite(layer, Image.merge('RGBA', [Image.new('L', (S, S), 0)] * 3 + [sh.filter(ImageFilter.GaussianBlur(14)).point(lambda v: v * 0.22)]))
        hi = Image.new('L', (S, S), 0)
        ImageDraw.Draw(hi).rounded_rectangle([-30, -30, S - 14, S - 14], radius, outline=255, width=28)
        layer = Image.alpha_composite(layer, Image.merge('RGBA', [Image.new('L', (S, S), 255)] * 3 + [hi.filter(ImageFilter.GaussianBlur(14)).point(lambda v: v * 0.7)]))
    if 'gloss' in fx:
        gl = Image.new('L', (S, S), 0); ImageDraw.Draw(gl).rounded_rectangle([8, 8, S - 8, S * 0.45], radius - 8, fill=90)
        layer.paste(Image.new('RGBA', (S, S), (255, 255, 255, 255)), (0, 0), gl.filter(ImageFilter.GaussianBlur(6)))
    d = ImageDraw.Draw(layer, 'RGBA')
    if 'border' in fx: d.rounded_rectangle([3, 3, S - 4, S - 4], radius, outline=ink, width=5)
    if 'double' in fx:
        d.rounded_rectangle([5, 5, S - 6, S - 6], radius, outline=accent, width=3)
        d.rounded_rectangle([14, 14, S - 15, S - 15], radius - 9, outline=accent + (150,), width=1)
    if 'dashed' in fx:
        for x in range(30, S - 30, 16): d.line([(x, 8), (x + 8, 8)], fill=ink, width=3); d.line([(x, S - 9), (x + 8, S - 9)], fill=ink, width=3)
        d.ellipse([-16, S / 2 - 16, 16, S / 2 + 16], fill=(120, 120, 126)); d.ellipse([S - 16, S / 2 - 16, S + 16, S / 2 + 16], fill=(120, 120, 126))
    if bg.startswith('g:'):
        d.rounded_rectangle([1, 1, S - 2, S - 2], radius, outline=(255, 255, 255, 150), width=2)
    mask = Image.new('L', (S, S), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, S - 1, S - 1], radius, fill=255)
    return layer, mask, 'hard' in fx and 'border' in fx, ink

def board():
    gap, cols, label_h, fam_h, top = 26, 10, 46, 54, 150
    width = cols * (S + gap) + gap
    height = top + len(FAMILIES) * (fam_h + S + label_h) + 40
    page = Image.new('RGB', (width, height), (20, 20, 24))
    pd = ImageDraw.Draw(page)
    page.paste(LOGO.resize((84, 84), Image.LANCZOS), (gap, 34), LOGO.resize((84, 84), Image.LANCZOS))
    pd.text((gap + 108, 40), 'Ardane · 100 styles', font=font('sys', 54), fill=(255, 255, 255))
    pd.text((gap + 110, 104), 'Tendances 2026 · chaque vignette est un widget de l’app dans son style · ★ gratuit', font=ImageFont.truetype(WIN + 'seguisym.ttf', 26), fill=(170, 170, 180))
    n = 0
    y = top
    for f_index, (family, styles) in enumerate(FAMILIES):
        pd.text((gap, y + 10), f'{chr(65 + f_index)}  ·  {family}', font=font('sys', 30), fill=(235, 235, 240))
        y += fam_h
        for i, spec in enumerate(styles):
            n += 1
            x = gap + i * (S + gap)
            layer, mask, hard, ink = card(spec, n - 1, i == 0)
            if hard:
                sh = Image.new('RGB', (S, S), (0, 0, 0)); page.paste(sh, (x + 10, y + 10), mask)
            else:
                shadow = Image.new('L', (S + 60, S + 60), 0)
                ImageDraw.Draw(shadow).rounded_rectangle([30, 40, S + 30, S + 40], R_DEF, fill=120)
                page.paste((0, 0, 0), (x - 30, y - 30), shadow.filter(ImageFilter.GaussianBlur(16)))
            page.paste(layer.convert('RGB'), (x, y), mask)
            name = spec.split('|')[0]
            pd.text((x + 4, y + S + 12), f'{n}. {name}' + ('  ★' if i == 0 else ''), font=ImageFont.truetype(WIN + 'seguisym.ttf', 24), fill=(225, 225, 232))
        y += S + label_h
    page.save(OUT, optimize=True)
    return page

if __name__ == '__main__':
    p = board()
    print(OUT, p.size)
