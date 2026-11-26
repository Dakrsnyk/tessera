"""Thèmes chromés, luxe, aura et « girl » à l'identité d'Ardane : 15 traitements × 20 couleurs = 300 (maquette).

python3 scripts/styles_board_ardane_glam.py -> docs/design/2026-11-25-100-styles/planche-ardane-glam.png
"""
import os
import styles_board_2026 as B
import styles_board_ardane as A
import styles_board_ardane_500 as P

mx, W, K = A.mx, A.W, A.K
dark = lambda a: mx(a, K, .62)
GOLD = 'C9A54C'
# (nom, fond, encre, accent, effets, graphique, filigrane, police du chiffre)
GLAM = [
    ('Chrome', lambda a: f'l:{mx(a, W, .85)},{mx(a, "8E8E93", .7)},FFFFFF,{mx(a, "6E6E73", .6)}', lambda a: '111111', dark, 'grain', 'bars', 60, 'orbitron'),
    ('Chrome Noir', lambda a: f'l:{mx(a, "3A3A40", .8)},0E0E10,{mx(a, "6A6A72", .7)},111114', lambda a: W, lambda a: mx(a, W, .45), '', 'spark', 40, 'orbitron'),
    ('Holographique', lambda a: f'm:{mx(a, W, .6)},B6F2FF,F2FFB6,FFB6F2', lambda a: '1C1C1E', dark, 'grain', 'week', 60, 'inter'),
    ('Aura', lambda a: f'm:{mx(a, W, .8)},{a},{mx(a, "FF9AE1", .5)},{mx(a, W, .9)}', dark, dark, 'grain', 'progress', 70, 'inter'),
    ('Aura Nuit', lambda a: f'm:0B0B14,{a},{mx(a, "7C5CFF", .5)},0B0B14', lambda a: W, lambda a: mx(a, W, .6), 'grain glow', 'spark', 36, 'inter'),
    ('Luxe Noir', lambda a: 's:0D0C0A', lambda a: 'F3E6C4', lambda a: mx(a, GOLD, .6), 'double caps', 'progress', 44, 'bodoni'),
    ('Luxe Ivoire', lambda a: 's:F8F3E6', lambda a: '1F1A12', lambda a: mx(a, 'B8913A', .5), 'double caps', 'bars', 40, 'playfair'),
    ('Marbre', lambda a: f'm:F4F2EF,DCD8D2,FFFFFF,{mx(a, W, .8)}', lambda a: '2B2B2B', dark, 'grain', 'week', 50, 'bodoni'),
    ('Velours', lambda a: f'l:{mx(a, K, .55)},{mx(a, K, .85)}', lambda a: mx(a, W, .88), lambda a: GOLD, 'grain', 'spark', 44, 'dmserif'),
    ('Girly', lambda a: f's:{mx(a, "FFD6E8", .65)}', lambda a: '5E1A30', lambda a: mx(a, 'FF4F9A', .5), 'clay', 'week', 60, 'fredoka'),
    ('Coquette', lambda a: f'l:FFF0F5,{mx(a, "FFC1DC", .6)}', lambda a: '6B2B45', lambda a: mx(a, 'E8456F', .5), 'double', 'progress', 60, 'dmital'),
    ('Clean Girl', lambda a: f's:{mx(a, "F3EBE1", .85)}', lambda a: '3B342B', lambda a: mx(a, 'B08968', .6), '', 'spark', 50, 'dmserif'),
    ('Y2K Bulle', lambda a: f'm:{mx(a, W, .6)},FFD1F7,E6E6FF,9EE7FF', lambda a: '2A1B6B', lambda a: mx(a, 'FF4FD8', .5), 'glow gloss', 'bars', 60, 'comfortaa'),
    ('Glossy', lambda a: f'l:{mx(a, W, .6)},{a},{mx(a, K, .3)}', lambda a: W, lambda a: W, 'gloss', 'week', 50, 'poppins'),
    ('Perle', lambda a: f'g:FFF0F5,{mx(a, W, .8)},F0FFFF', lambda a: '3A3A48', dark, '', 'progress', 60, 'quicksand'),
]
if __name__ == '__main__':
    B.FONTS['sysr'] = B.FONTS['inter']  # les libellés restent en Inter
    P.TREATMENTS = GLAM
    P.OUT = os.path.join(B.ROOT, 'docs/design/2026-11-25-100-styles/planche-ardane-glam.png')
    P.TITLE = 'Ardane · 300 thèmes Premium : chrome, luxe, aura, girl'
    P.SUB = '15 traitements × 20 couleurs · le A en filigrane et le trait du logo dans chaque thème'
    p = P.board()
    print(p.size)
    p.resize((p.width // 4, p.height // 4)).save(os.path.join(os.environ.get('TEMP', '.'), 'glam-mini.png'))
