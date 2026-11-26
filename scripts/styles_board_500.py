"""500 thèmes d'Ardane : 20 catégories de 25, les 2 premiers de chaque catégorie gratuits (40), le reste Premium.

python3 scripts/styles_board_500.py -> docs/design/2026-11-25-100-styles/themes-500-page-1..5.png et themes-500.md
Maquette d'après le moteur de styles (scripts/styles_board_2026.py), pas le rendu de l'app.
"""
import os
from PIL import Image, ImageDraw, ImageFont
import styles_board_2026 as B

OUT = os.path.join(B.ROOT, 'docs/design/2026-11-25-100-styles')

# catégorie : (fond, polices, effets tournants, graphiques tournants, palettes « Nom:c1,c2,c3 »)
CATS = [
    ('Verre liquide', 'g', ['sys', 'sysr', 'poppins'], ['caps', '', 'grain'], [
        'Cristal:A5C8FF,FFD6E8,C9F2E4', 'Nuit de verre:1B1F3B,3B2A6B,0E5A6B', 'Aurore:FF9A8B,FF6A88,FFC796', 'Menthe glacée:B8F2D8,7ED9C3,E8FFF6',
        'Corail:FFB199,FF6B6B,FFE29A', 'Fumé:2A2A2E,4A4A52,1A1A1C', 'Lilas:D7C4FF,B7A4F5,F6D9FF', 'Océan:0F4C81,1CA7EC,7FE3F0',
        'Ambre:FFB347,FF7E5F,FFE0A3', 'Prisme:FF9AE1,9AD0FF,FFF59A', 'Opale:E3F6F5,BAE8E8,FFD6E0', 'Saphir:142850,27496D,0C7B93',
        'Rubis:5C0F1F,B3203C,FF7A8A', 'Émeraude:0B3D2E,1E8A5F,7FE0B0', 'Quartz rose:FFD1DC,FFB7C5,FFF0F5', 'Givre:EAF4FF,CFE3FF,FFFFFF',
        'Brume:C9D6DF,E2E2E2,A7BBC7', 'Néon verre:120458,7A04EB,FF124F', 'Miel:FFD56B,FFB830,FFF1C1', 'Lagune:00A6A6,3BCEAC,A9F0D1',
        'Améthyste:3E1F6B,7B4FC9,C9A7FF', 'Pêche verre:FFE0CC,FFB49A,FFD6E8', 'Graphite verre:3A3F47,5B6370,22262B', 'Cerise:FF5C8A,FF9EB7,FFD0DC',
        'Polaire:B4E0FF,7FB8FF,E6F4FF']),
    ('Aurore et maillages', 'm', ['sys', 'sysblack', 'poppins'], ['grain', '', 'caps'], [
        'Boréale:0B1D3A,1FD1A5,6A3DE8', 'Pêche fondue:FFD3B6,FFAAA5,FF8B94', 'Cobalt:0A1E6E,2F5BFF,00C2FF', 'Iris:5B2EFF,C13BFF,FF6EC7',
        'Sorbet:FFF1A8,FFB3C7,B5E8FF', 'Néon doux:00F5D4,9B5DE5,F15BB5', 'Crépuscule:2B1055,D53A9D,FF9068', 'Lagon:00B4D8,90E0EF,00F5A0',
        'Bonbon:FFC6FF,BDB2FF,A0C4FF', 'Holo:E0C3FC,8EC5FC,F9F586', 'Mangue:FFB000,FF6A00,FFE29A', 'Cosmos:120136,6A0572,AB83A1',
        'Pastèque:FF6B81,7BED9F,FFF3E0', 'Glacier:A1C4FD,C2E9FB,E0F7FF', 'Feu:FF0844,FFB199,FF5F00', 'Jade:00B09B,96C93D,D4FC79',
        'Myrtille:30336B,5E60CE,A1A6FF', 'Flamant:FF9A9E,FECFEF,FAD0C4', 'Électrique:00DBDE,FC00FF,5F2EEA', 'Pétrole:0F2027,203A43,2C5364',
        'Abricot:FCCB90,D57EEB,FFE1C4', 'Lime:D4FC79,96E6A1,F9F586', 'Velours:3A1C71,D76D77,FFAF7B', 'Banquise:E0EAFC,CFDEF3,FFFFFF',
        'Supernova:F12711,F5AF19,7B2FF7']),
    ('Minimal clair', 's', ['sysr', 'sys', 'raleway'], ['', 'light', 'caps'], [
        'Blanc:FFFFFF,111111,3366FF', 'Papier:F4F1EA,1A1A1A,E4002B', 'Galet:E9EAEC,2B2D31,5B6472', 'Nordique:F7F7F5,2E3440,88C0D0',
        'Lin clair:EFE9DF,2E2A24,9C7A4D', 'Craie:FAFAF7,333333,999999', 'Brume:EEF1F4,334155,64748B', 'Coquille:FFF8F0,5A4636,D08C60',
        'Riz:F8F6F1,2D2A26,B5A48B', 'Nuage:F5F7FB,2B3445,6C8EF5', 'Os:F2EDE4,3B342B,A07D52', 'Perle:F3F3F5,1C1C1E,8E8E93',
        'Sauge claire:EEF2EA,2F3B2A,7C9A6B', 'Rose poudré:FBF0F0,4A2C2C,D98C8C', 'Ciel pâle:EEF6FB,1F3A4D,4FA3D1', 'Vanille:FFF9EC,3F3626,E0A526',
        'Argile claire:F3E9E2,4E3B31,C07A5C', 'Lavande pâle:F4F1FA,322A48,8C7AD6', 'Menthe pâle:EEF8F3,1F3B30,3FB37F', 'Sable clair:F5EFE4,3D3324,B99566',
        'Béton clair:E6E6E3,2A2A28,6E6E69', 'Citron pâle:FDFBE7,3A3711,C4B52E', 'Glace:F0F7F7,163636,2BA6A6', 'Pêche pâle:FFF2EA,4D2A1A,F08A5D',
        'Blanc cassé:F9F7F3,262626,FF5A36']),
    ('Minimal sombre', 's', ['sys', 'sysl', 'sysr'], ['', 'light', 'caps'], [
        'Nuit:0B0B0F,F5F5F7,0A84FF', 'Encre:0E0E0E,F2F2F2,F2F2F2', 'OLED:000000,F5F5F7,30D158', 'Ardoise:1E232A,E6EAF0,7AA2F7',
        'Graphite:1C1C1E,E5E5EA,FF9F0A', 'Marine:0B1426,E3EAF7,4C8DFF', 'Forêt nuit:0E1A14,E2EFE6,4CC38A', 'Prune:1A0F1F,F3E8F7,C77DFF',
        'Bordeaux nuit:1C0A10,F7E6EA,FF4D6D', 'Café:1B1512,F1E6DB,D19A66', 'Anthracite:232528,EDEDED,FFD60A', 'Abysse:020B14,CFE8FF,00B4D8',
        'Charbon:121212,E0E0E0,BB86FC', 'Sapin:0F1F1A,DDEFE7,2BD4A4', 'Minuit:10102A,E6E6FF,8C8CFF', 'Cacao:20140F,F3E3D3,E0703A',
        'Acier:1A1F24,DCE3EA,9AB1C7', 'Aubergine:1E1024,F1E3F5,E36BAE', 'Mousse nuit:151A10,E8F0DC,A3D65C', 'Tabac:1E1913,EEE2CF,C9A35C',
        'Indigo:0F1030,E2E4FF,6E6BFF', 'Corbeau:0A0A0A,D9D9D9,E5484D', 'Pétrole nuit:0B1F24,D5ECEF,26C6DA', 'Velours noir:111014,EFEAF4,F5C2E7',
        'Éclipse:050505,FFFFFF,FFB800']),
    ('Luxe et horlogerie', 's', ['bodoni', 'cinzel', 'dmserif', 'italiana', 'marcellus'], ['double caps', 'grain', 'border caps', 'double'], [
        'Noir et or:0D0C0A,F3E6C4,C9A54C', 'Ivoire et or:F8F3E6,1F1A12,B8913A', 'Vert anglais:123D2E,EFE6D2,C9A54C', 'Bordeaux:4A0E1E,F6E3E7,E8B4A0',
        'Champagne:F7E7CE,3A2A14,9B6B2C', 'Cadran bleu:0E2240,E9EEF6,C0C7D1', 'Cadran ardoise:2C3138,E9E5DC,C9A54C', 'Or rose:F6E1DA,4A2A24,C98A7A',
        'Platine:E5E4E2,2A2A2A,8A8A8A', 'Velours:2A0E2E,F2E6F4,D4AF37', 'Marbre noir:111111,EEEEEE,BFA06A', 'Cognac:5A2E12,F7E8D8,E0A060',
        'Saphir royal:0F1E5A,EEF1FF,D4AF37', 'Émeraude:063D2B,E6F4EE,D4AF37', 'Ébène:1A1410,F1E7DA,B08D57', 'Perle noire:202024,ECECF0,BFC4CC',
        'Cuir:3B2416,F3E5D5,C58B4B', 'Chronographe:F2F2F0,111111,D21F1F', 'Jaspe:7A1F1F,F8E9E4,F1C27D', 'Opéra:3A0A14,FFEFF2,C9A54C',
        'Cachemire:E8DED3,3F342B,8C6A4F', 'Minuit or:0A1024,F4EBD0,C9A54C', 'Bronze:3A2D1E,F1E6D2,B87333', 'Ivoire noir:FFFFF0,111111,111111',
        'Tweed:6B6151,F4EFE6,D9C5A0']),
    ('Éditorial et magazine', 's', ['playfair', 'abril', 'gloock', 'dmital', 'anton'], ['', 'caps', 'border', 'columns'], [
        'Journal:F2EEE4,111111,111111', 'Magazine:FFFFFF,111111,E5004F', 'Suisse:F4F1EA,111111,E4002B', 'Typographie:111111,F5F5F5,F5F5F5',
        'Affiche:E9E1CF,1D1D1B,D2381F', 'Une:FAF7F0,1A1A1A,0047AB', 'Couverture:FFE7D6,1E1E1E,FF4F00', 'Gazette:EDE6D3,2B2520,8B1E1E',
        'Mode:F5F5F5,0A0A0A,C9A0DC', 'Quotidien:F7F5EF,222222,2E7D32', 'Critique:111827,F9FAFB,F59E0B', 'Revue:F3EDE2,2A2118,6B4226',
        'Galerie:FFFFFF,000000,FF3B30', 'Essai:FBF8F1,1F2A44,1F2A44', 'Manifeste:FF3B30,FFFFFF,111111', 'Colonne:EFEFEA,1C1C1C,5B5BD6',
        'Encre bleue:F7F7FF,1A2A6C,1A2A6C', 'Titre:FFD400,111111,111111', 'Imprimerie:EDE8DF,3B3B3B,C1440E', 'Brochure:E8F1F2,0B3954,FF5A5F',
        'Rubrique:FCFCFC,262626,0081A7', 'Feuilleton:F4ECE1,3D2B1F,A44A3F', 'Supplément:FFF1F1,2E1A1A,E63946', 'Lettrine:F5F0E6,222222,B8860B',
        'Édition noire:0F0F0F,EAEAEA,E5004F']),
    ('Couleurs dopamine', 's', ['archivo', 'sysblack', 'shrikhand', 'bebas'], ['', 'caps', 'hard', ''], [
        'Tomate:FF4D2E,FFF4E8,FFE14D', 'Citron:F5F02A,141414,141414', 'Bleu Klein:0033FF,FFFFFF,FFD400', 'Rose Barbie:FF3FA4,FFFFFF,FFE14D',
        'Vert pomme:7CFF6B,0B2E0B,0B2E0B', 'Orange pop:FF8A00,1A0E00,FFFFFF', 'Violet électrique:6B2BFF,FFFFFF,C6FF3D', 'Turquoise:00D1C1,04312D,FFFFFF',
        'Fraise:FF2E63,FFFFFF,FFE66D', 'Mandarine:FF6B00,FFFFFF,2B2B2B', 'Lagon vif:00E0FF,002B36,FF3FA4', 'Fuchsia:E0218A,FFFFFF,FFD23F',
        'Jaune taxi:FFC300,111111,111111', 'Cyan:00F0FF,0A0A0A,FF006E', 'Lime:C6FF3D,1A2600,6B2BFF', 'Corail vif:FF5A5F,FFFFFF,FFE0B2',
        'Grenade:C1121F,FFF0F0,FFD166', 'Bleu piscine:00A8E8,FFFFFF,FFE14D', 'Menthe vive:3DFFB0,003B24,FF3FA4', 'Pêche vive:FF9E7A,3A1408,3A1408',
        'Lavande vive:B388FF,1B0B3A,FFFFFF', 'Ketchup:E63946,F1FAEE,F1FAEE', 'Moutarde:E9B10A,2B1E00,2B1E00', 'Kiwi:8AC926,1A2E00,FFFFFF',
        'Bubblegum:FF8AD8,3B0030,3B0030']),
    ('Néo-brutalisme', 's', ['archivo', 'sysblack', 'mono', 'bungee'], ['border hard square', 'border hard square caps', 'border hard', 'border hard square'], [
        'Jaune:FFE14D,111111,FF3FA4', 'Rose:FFB3D9,111111,3366FF', 'Bleu:9DB8FF,111111,FFE14D', 'Gumroad:FF90E8,000000,000000',
        'Vert:A6FF8F,111111,FF5C00', 'Orange:FFB86B,111111,6B2BFF', 'Blanc:FFFFFF,111111,00C2A8', 'Lilas:CDB4FF,111111,FFE14D',
        'Menthe:9FF0D0,111111,FF3FA4', 'Corail:FF9A8A,111111,111111', 'Ciel:8FD3FF,111111,FF5C00', 'Citron:EFFF6B,111111,6B2BFF',
        'Pêche:FFD6B0,111111,E5484D', 'Crème:FFF3D6,111111,3366FF', 'Rouge:FF5C5C,111111,FFE14D', 'Turquoise:5CE1E6,111111,111111',
        'Sable:E8D5B5,111111,111111', 'Violet:A78BFA,111111,C6FF3D', 'Gris:D4D4D4,111111,FF3B30', 'Bonbon:FFC6E5,111111,00C2A8',
        'Pistache:D4F5A1,111111,E5484D', 'Ocre:F2B33D,111111,111111', 'Noir:111111,FFFFFF,FFE14D', 'Bleu nuit:1E3A8A,FFFFFF,FFE14D',
        'Sticker:FFFFFF,111111,FF3FA4']),
    ('Bento', 's', ['sys', 'poppins', 'sysr'], ['bento'], [
        'Crème:F4EFE6,1C1C1E,FF6B3D', 'Nuit:111114,F5F5F7,7C5CFF', 'Blanc:FFFFFF,111111,0A84FF', 'Sauge:E7EDE4,22301E,4E8C3A',
        'Rosé:FBEDEE,3A1C22,E05272', 'Ardoise:1E232A,E6EAF0,22C55E', 'Sable:EFE6D8,33281C,C2410C', 'Glace:EAF3FB,12324A,0EA5E9',
        'Lilas:F0ECFB,2A2142,8B5CF6', 'Graphite:202124,EAEAEA,F59E0B', 'Menthe:E6F7F0,113A2B,10B981', 'Pêche:FFF0E6,40210F,F97316',
        'Encre:0A0A0A,F0F0F0,EF4444', 'Citron:FBF8DC,333000,CA8A04', 'Bleu:E8EEFF,14214A,3B5BFF', 'Terre:EADCD0,3A2A1E,B45309',
        'Prune:1F1023,F2E7F6,D946EF', 'Forêt:13201A,E3EFE7,34D399', 'Corail:FFE9E4,3D1410,F43F5E', 'Brume:E5E9EE,25303B,64748B',
        'Moka:2A1F1A,EFE3D7,D6A273', 'Lavande nuit:16132A,E9E6FF,A78BFA', 'Pop:FFFFFF,111111,FF3FA4', 'Océan:0B1E2D,DDEFFA,38BDF8',
        'Or:15130E,F5ECD7,D4AF37']),
    ('Pastel et pâte à modeler', 's', ['fredoka', 'quicksand', 'comfortaa', 'chewy'], ['clay'], [
        'Argile:E9DDD3,5A4337,D9826B', 'Nuage:EEF3FF,33405C,7A9CFF', 'Guimauve:FFE3EE,6B2B45,FF7AA8', 'Pistache:E3F4D7,2E4A1F,7FBF4D',
        'Lavande:ECE6FF,3E2F6B,8C6CFF', 'Pêche:FFE7D6,6B3A1F,FF9A62', 'Bébé bleu:E0F2FF,1F3A5C,4FA8FF', 'Beurre:FFF5CC,5C4A12,F2B705',
        'Sakura:FFEAF1,6B2B45,F27BA0', 'Coton:F7F7FA,3A3A48,A3A3FF', 'Menthe:DFF7EC,1F4A3A,3CC48F', 'Abricot:FFE5CC,5A3215,F28C38',
        'Lilas:F3E5FF,4A2A66,B36BFF', 'Ciel:DDF1FF,1B3A57,2E9BFF', 'Framboise:FFDDE6,5E1A30,E8456F', 'Vanille:FFF8E6,4D3F1E,E0A92E',
        'Glycine:E9E4FF,35295C,7B61FF', 'Corail:FFE1DA,5C2418,F2664A', 'Écume:DFFAF6,1A4842,2CC5B0', 'Rose thé:FBE4E1,5A2F2A,D98274',
        'Sorbet citron:FDFBD3,4D4A12,D6C21E', 'Mûre:EDE0F5,3F2350,9B4DCA', 'Pomme:E8F8DA,30491B,6CC33A', 'Lait fraise:FFE8EE,5C2A36,FF8FAB',
        'Gris doux:EDEDF2,3A3A47,7A7A99']),
    ('Y2K et chrome', 'l', ['orbitron', 'comfortaa', 'righteous', 'sys'], ['grain', 'glow', 'gloss', 'grain'], [
        'Chrome liquide:F2F2F2,8E8E93,FFFFFF', 'Bulle Y2K:B8F1FF,FFD1F7,E6E6FF', 'Aqua 2001:CFF3FF,4FB3FF,0A6CFF', 'Holographique:FFB6F2,B6F2FF,F2FFB6',
        'Argent:E6E9EF,A3ABB8,FFFFFF', 'Bleu givré:D6F0FF,6EC1FF,0057FF', 'Rose chrome:FFE0F0,FF8CC6,FFFFFF', 'Lime chrome:F2FFD6,B8F25A,FFFFFF',
        'Lave:FF2A00,FF8C00,3B0000', 'Gel:A0FFE6,60D6FF,B48CFF', 'Disco:FFD700,FF4FD8,00E5FF', 'Mercure:CFD8DC,78909C,ECEFF1',
        'Bulle violette:E0C8FF,A06BFF,FFFFFF', 'Translucide:F5FAFF,C7E2FF,FFFFFF', 'Cyber argent:B0BEC5,ECEFF1,546E7A', 'Glace pilée:E8FBFF,9FE7FF,FFFFFF',
        'Rose bonbon:FFC1E3,FF6FB5,FFE6F3', 'Turquoise 2000:7FFFD4,00CED1,E0FFFF', 'Orange chrome:FFE0B2,FF9800,FFF3E0', 'Ultraviolet:3A0CA3,7209B7,F72585',
        'Platine Y2K:FAFAFA,BDBDBD,FFFFFF', 'Pixel bleu:00C6FF,0072FF,E0F7FF', 'Perle irisée:FFF0F5,E6E6FA,F0FFFF', 'Néon citron:F9FF00,B2FF59,FFFFFF',
        'Vaporwave:FF9DE6,9AF5FF,FFF1A6']),
    ('Cyberpunk et néon', 's', ['audiowide', 'orbitron', 'monoton', 'sys'], ['glow scan', 'glow border', 'glow grid', 'glow'], [
        'Néon Tokyo:0A0014,FFFFFF,00F0FF', 'Cyber rose:1A0014,FF7AD9,FF2BD6', 'Synthwave:1B0638,FFE6FF,FFB800', 'Laser:050014,F0F0FF,FF003C',
        'Blade:07131A,DFF6FF,FF7B00', 'Acide:050A00,EFFFD6,B6FF00', 'Plasma:0D001A,F5E6FF,BF00FF', 'Glitch:000000,FFFFFF,00FFC6',
        'Hologramme:000814,CAF0F8,00B4D8', 'Néon vert:001A0D,D6FFE9,00FF85', 'Rouge sang:120000,FFE5E5,FF1744', 'Ultraviolet:0B0020,E6DFFF,7C4DFF',
        'Arcade:0A0A23,FFFFFF,FFD300', 'Tron:000510,DFF9FF,18DCFF', 'Neo Séoul:12001F,FFE8FA,FF4FD8', 'Megacity:0B0F1A,E3E8F5,FF6B00',
        'Chrome sombre:0E0E12,EDEDF2,C0C0FF', 'Circuit:001014,D6FFFB,00E5C0', 'Électro:08000F,FFFFFF,E100FF', 'Signal:000000,FFFFFF,FF2D55',
        'Néon bleu:000818,E0ECFF,2979FF', 'Toxique:0A0F00,F4FFE0,76FF03', 'Rétine:140014,FFE0F0,FF0080', 'Datastream:00060F,D0F0FF,00D9FF',
        'Minuit néon:0A0614,F0E6FF,9D4EDD']),
    ('Terminal et tech', 's', ['mono', 'courier', 'sys'], ['scan', 'grid caps', 'dots', 'border caps'], [
        'Terminal:020A04,33FF66,33FF66', 'Matrice:000000,00FF41,00FF41', 'Ambre CRT:120A00,FFB000,FFB000', 'HUD:05121C,9FE8FF,00D1FF',
        'Datacenter:0B0F14,C9D1D9,58A6FF', 'Cockpit:0E1116,F2F4F7,FFD60A', 'Carbone:141414,EDEDED,FF3B30', 'Console blanche:F5F5F5,111111,0055FF',
        'Solarisé:002B36,EEE8D5,B58900', 'Monokai:272822,F8F8F2,A6E22E', 'Dracula:282A36,F8F8F2,FF79C6', 'Nord:2E3440,ECEFF4,88C0D0',
        'Gruvbox:282828,EBDBB2,FE8019', 'Tokyo nuit:1A1B26,C0CAF5,7AA2F7', 'One Dark:282C34,ABB2BF,61AFEF', 'Github sombre:0D1117,C9D1D9,3FB950',
        'Catppuccin:1E1E2E,CDD6F4,F5C2E7', 'Radar:00140A,7CFFB2,00FF7F', 'Oscilloscope:001018,9FFFEF,00FFD0', 'Plan:0B3D91,FFFFFF,FFFFFF',
        'Fiche technique:FFFFFF,111111,0055FF', 'Ingénieur:E8EDF2,1D2B3A,FF6A00', 'Kernel:0A0A0A,D0D0D0,FF5F57', 'Sonar:001F1A,BFFFF0,1DE9B6',
        'Rose terminal:1A0A14,FFC2E2,FF6AC1']),
    ('Rétro 70-80', 'l', ['righteous', 'limelight', 'shrikhand', 'poiret'], ['grain', 'grain caps', 'grain', 'stripes grain'], [
        'Rétro 70:F2C14E,F78154,4D9078', 'Soleil couchant:FFB347,FF6961,5B2A86', 'Disco:FF6F61,FFD166,6A0572', 'Jukebox:B91C1C,F59E0B,111111',
        'Formica:F4D35E,EE964B,0D3B66', 'Moutarde:E1A140,532200,EFCFE3', 'Avocat:B5C99A,718355,FFF8E1', 'Orange 70:F47C3C,F9C784,3E2C41',
        'Diner:E63946,F1FAEE,A8DADC', 'Polaroïd:F5F1E8,E0B354,3D3D3D', 'Cassette:2A2A2A,F25C54,F7B267', 'Miami:FF71CE,01CDFE,FFFB96',
        'Atari:2B2B2B,E07A1F,F2E3BC', 'Tapisserie:7A4419,D9A441,F3E4C9', 'Velours côtelé:8C4A2F,D98E48,F5DEB3', 'Arcade 80:12086F,F72585,FCD200',
        'Cinéma:2B0F0F,E8C547,F5E9D7', 'Ticket:FFF6E5,E5484D,2A1E12', 'Roller:FF4F79,FFB48F,3A1C71', 'Néon motel:1B1B3A,FF3864,2DE2E6',
        'Caramel:D4A373,FAEDCD,6B4226', 'Patchwork:E76F51,F4A261,2A9D8F', 'Pin-up:D62828,F7EDE2,003049', 'Westerns:9C6644,DDB892,3E2723',
        'VHS:0F0F0F,FF2E63,08D9D6']),
    ('Pixel et jeu vidéo', 's', ['press', 'mono', 'bungee'], ['pixel', 'pixel caps', 'pixel border', 'scan'], [
        '8 bits:2B2D42,EDF2F4,EF233C', 'Game Boy:9BBC0F,0F380F,306230', 'Pixel pastel:FDE2FF,5B2A86,FF6EC7', 'Arcade:000000,FFFFFF,FFD300',
        'Voxel:7AE582,1B4332,FFFFFF', 'Quête:F3E9D2,3B2A1A,C1440E', 'Donjon:1A1423,E8E0F0,FF9F1C', 'Console néon:0B0033,E0D7FF,00F5D4',
        'Plateforme:5C94FC,FFFFFF,E52521', 'Cartouche:3D3D3D,E6E6E6,8BAC0F', 'MMO:1C2541,E0E6F2,3A86FF', 'Lave pixel:3B0A0A,FFE0B5,FF5400',
        'Glace pixel:CAF0F8,03045E,0077B6', 'Forêt pixel:2D6A4F,D8F3DC,FFD166', 'Rose pixel:FF99C8,3A0CA3,FCF6BD', 'Écran bleu:0000AA,FFFFFF,FFFF55',
        'Monochrome:E0E0E0,111111,111111', 'Boss:2B0A3D,F5E6FF,FF006E', 'Score:111111,F5F5F5,00FF9C', 'Rétro PC:C0C0C0,000000,000080',
        'Pomme pixel:FFFFFF,000000,FF3B30', 'Coffre:6B4226,F9E4B7,FFD700', 'Potion:3A0CA3,F1E3FF,4CC9F0', 'Esport:0A0A0F,EDEDF2,FF2E63',
        'Sprite:FFE8D6,3D2817,6A994E']),
    ('Nature et forêt', 'l', ['lora', 'playfair', 'josefin'], ['grain', 'grain', 'topo', 'grain caps'], [
        'Forêt:1E3D2F,0F241B,8FD694', 'Mousse:4F6B3A,3A5028,D9E8A0', 'Fougère:2F5D3A,1B3A23,B8E3A6', 'Pin:0F3B2E,0A2620,7FD1AE',
        'Lichen:9CA77A,6E7A4F,F4F1DE', 'Olivier:6B7B3A,4A5527,F2EFD5', 'Herbier:F3EFE2,E5DFC9,6E8B3D', 'Feuille morte:A65E2E,6B3A1A,F2D3A6',
        'Bambou:CFE3A0,8FB35A,2F4A1A', 'Sous-bois:2E2A22,1C1A15,C9B37E', 'Eucalyptus:A3BFAE,6E8F7E,F4F7F2', 'Sauge:B2C2A8,7E9474,F7F8F3',
        'Prairie:8BC34A,558B2F,F9FBE7', 'Cèdre:5D3A1A,3B2410,E7C9A0', 'Jungle:0B3D20,052611,40E0A0', 'Trèfle:3BB273,22814C,F1FFF6',
        'Chêne:7A5230,4E341E,EEDCC2', 'Rosée:DDF2E3,B6E2C4,2E6B47', 'Kaki:7D7A4A,55532F,F4F1D6', 'Thé vert:C5D9A5,9EBB7A,3A4A23',
        'Matcha:A8C686,7FA55A,FDFDF5', 'Écorce:4A3B2E,30261D,D4B896', 'Aiguille:2C4A3E,1A3027,E3D9B5', 'Champignon:C9B8A6,9C8673,3E2F23',
        'Bruyère:7E5A7E,5A3D5A,F1E3F1']),
    ('Océan et ciel', 'l', ['raleway', 'sys', 'quicksand'], ['waves', 'light', '', 'waves'], [
        'Océan profond:00334E,005B82,4FD1FF', 'Lagon:00B4D8,0077B6,CAF0F8', 'Glacier:EAF6FF,BFE3FF,1C8FD6', 'Récif:00A896,028090,F0F3BD',
        'Écume:E0FBFC,98C1D9,3D5A80', 'Tempête:2B3A4A,1B2632,A9C1D9', 'Abysse:03045E,000428,48CAE4', 'Ciel d’été:8ED1FC,4A90E2,FFFFFF',
        'Aube marine:FFB5A7,8EC5FC,FFFFFF', 'Méduse:7B2CBF,3C096C,FFB3FF', 'Corail:FF7F50,FF5E62,FFF1E6', 'Mistral:A8DADC,457B9D,F1FAEE',
        'Brise:D7F9FF,A0E7E5,1D6A72', 'Nuit marine:0B132B,1C2541,5BC0BE', 'Plage:F6E7CB,7EC4CF,1E6091', 'Orage:4A4E69,22223B,C9ADA7',
        'Aurore polaire:0B3C5D,1D7874,93E1D8', 'Turquoise:40E0D0,20B2AA,F0FFFF', 'Phare:F4F4F4,1D3557,E63946', 'Marée:5E60CE,48BFE3,E0FBFC',
        'Nuage rose:FDE2E4,E2ECE9,6D597A', 'Horizon:FF9E6D,7FB3D5,FFFFFF', 'Bleu marine:14213D,0B132B,FCA311', 'Embruns:BEE3F8,90CDF4,2A4365',
        'Ciel étoilé:0B0C2A,1B1D4A,FFFFFF']),
    ('Désert et terre', 'l', ['josefin', 'dmserif', 'marcellus'], ['grain caps', 'grain', 'topo', 'grain'], [
        'Désert:F2C89B,D9895B,7A2E0E', 'Terracotta:C8643B,A04A26,FFE0C2', 'Dune:EBCB9C,C9A06A,4A2F14', 'Canyon:C1440E,7A2E0E,FCE4C8',
        'Sahara:F4D19B,E0A458,5C3A13', 'Argile rouge:B5523B,8C3A26,F9E3D6', 'Ocre:D99A3C,A66C1F,FFF2D9', 'Oasis:E9C46A,2A9D8F,264653',
        'Mesa:D17A47,8A4A2B,F6E0C8', 'Grès:D6B48E,B08D63,3A2A1A', 'Cuivre:B87333,7A4A1F,FBE7D3', 'Safran:F4A300,C77700,FFF4D6',
        'Adobe:CC8B65,9C6644,F8E6D6', 'Rouille:8B3A1F,5A2412,F3D5C0', 'Cactus:7A9E7E,4F6B53,F2E8CF', 'Topographie:EDE6D6,D8CDB4,C46A2A',
        'Caravane:D4A373,A47148,FEFAE0', 'Mirage:F6BD60,F28482,FFF1E6', 'Volcan:1A0A06,4A1208,FF5A1F', 'Basalte:3A3A3A,1F1F1F,D97A3A',
        'Épice:A44A3F,7A2F27,F7DDC4', 'Cannelle:B5651D,7F4314,FCEBD7', 'Kasbah:E07A5F,BC4B2F,F4F1DE', 'Poussière:CFC1AE,A99780,3D342A',
        'Coucher du désert:FF7E5F,FEB47B,4A1C0F']),
    ('Saisons et fêtes', 'm', ['poppins', 'shrikhand', 'fredoka', 'playfair'], ['grain', '', 'stars', 'grain'], [
        'Printemps:FDE2E4,C6F1D6,FFF1B5', 'Été:FFD166,EF476F,06D6A0', 'Automne:D9822B,8C2F39,F2C14E', 'Hiver:E0F2FF,B8D8F2,FFFFFF',
        'Noël:0B3D2E,B3202C,F7E7CE', 'Neige:EEF5FF,D6E6F5,FFFFFF', 'Halloween:1A0E00,FF7A00,6B2BFF', 'Saint-Valentin:FFCAD4,FF4D6D,FFF0F3',
        'Pâques:FFF3B0,CDE7B0,E0C3FC', 'Nouvel An:0A0A14,D4AF37,FFFFFF', 'Rentrée:FFE5B4,3A86FF,FF006E', 'Vacances:00C2CB,FFD166,FF6B6B',
        'Récolte:B5651D,E9C46A,606C38', 'Feu de camp:3B1E08,FF7B00,FFD166', 'Sakura en fleurs:FFE4EC,FFB7C5,FFFFFF', 'Canicule:FF4E00,FFB000,FFF3B0',
        'Pluie:9DB4C0,5C6B73,E0FBFC', 'Lanternes:7A0019,FF4D00,FFD166', 'Carnaval:FF006E,FFBE0B,3A86FF', 'Diwali:4A0E4E,FF9F1C,FFD700',
        'Ramadan:0B1D51,D4AF37,F5F0E1', 'Fête des mères:FFD6E0,FF8FAB,FFF0F5', 'Mardi gras:5B2A86,FFD100,00A86B', 'Pleine lune:0B0C2A,E8E8F0,FFFFFF',
        'Cocooning:E9DCC9,B08968,FFF8F0']),
    ('Art et imprimé', 's', ['archivo', 'bangers', 'special', 'marker'], ['halftone border', 'dots grain', 'grain', 'lines'], [
        'Risographie:FBF5E8,1A3FA8,FF4F7B', 'Trame BD:FFE14D,111111,E5004F', 'Pop Art:FF3FA4,111111,FFE14D', 'Bauhaus:F2E8D5,111111,D7263D',
        'Memphis:FFF0F5,111111,00BFA6', 'Matisse:F5E6D3,1E3A8A,E4572E', 'Mondrian:FFFFFF,111111,D7263D', 'Aquarelle:F7F3EE,3A4A5A,7FB3D5',
        'Linogravure:EFE6D8,1A1A1A,B91C1C', 'Sérigraphie:FFD400,1A1A1A,0066FF', 'Carnet de croquis:FBF8F1,333333,333333', 'Craie:23292E,F2F2F2,F7D354',
        'Collage:F4EDE4,222222,FF6B35', 'Origami:F7F7F7,333333,E63946', 'Fresque:D9C5A7,4A3426,2E6F95', 'Graffiti:1B1B1B,FFFFFF,39FF14',
        'Pochoir:E5E5E5,111111,FF3B30', 'Vitrail:0F1C2E,F5F0E1,F2B134', 'Estampe:F2E9DC,1F2E4A,C1121F', 'Kraft:C9A27E,2E2014,FFFFFF',
        'Manuscrit:FBF8F1,1F2A44,1F2A44', 'Post-it:FFF07A,3A3200,E5484D', 'Tableau noir:23292E,F2F2F2,F7D354', 'Riso duo:FF6F91,FFFFFF,3E64FF',
        'Affiche suisse:F4F1EA,111111,E4002B']),
]
FREE_PER_CAT = 2
VIZ = ['ring', 'bars', 'spark', 'week', 'progress']

def lum(h): c = B.rgb(h); return (0.299 * c[0] + 0.587 * c[1] + 0.114 * c[2]) / 255

def spec(cat, i, entry):
    _, kind, fonts, fxs, _ = cat
    name, colors = entry.split(':', 1)
    c = colors.split(',')
    if kind == 's':
        bg, ink, accent = 's:' + c[0], c[1], c[2]
    else:
        bg = {'g': 'g:', 'm': 'm:', 'l': 'l:'}[kind] + ','.join(c if kind != 'm' else c + c[:1])
        avg = sum(lum(x) for x in c) / len(c)
        ink = '1C1C1E' if avg > 0.62 else 'FFFFFF'
        accent = max(c, key=lambda x: abs(lum(x) - (0.1 if ink == 'FFFFFF' else 0.9)))
        if abs(lum(accent) - lum(c[0])) < 0.15: accent = ink
    fx = fxs[i % len(fxs)]
    viz = 'bento' if fx == 'bento' else VIZ[i % len(VIZ)]
    return f'{name}|{bg}|{ink}|{accent}|{fonts[i % len(fonts)]}|{fx}|{viz}'

T = 230          # côté d'une vignette sur la planche
COLS = 13

def page(cats, number, first):
    gap, label_h, head_h, top = 22, 54, 60, 140
    rows = 2
    width = COLS * (T + gap) + gap
    height = top + len(cats) * (head_h + rows * (T + label_h)) + 30
    img = Image.new('RGB', (width, height), (20, 20, 24))
    d = ImageDraw.Draw(img)
    logo = B.LOGO.resize((72, 72), Image.LANCZOS)
    img.paste(logo, (gap, 34), logo)
    d.text((gap + 92, 36), f'Ardane · 500 thèmes · page {number}/5', font=B.font('sys', 46), fill=(255, 255, 255))
    d.text((gap + 94, 92), '25 thèmes par catégorie · les 2 premiers gratuits, les autres Premium', font=B.font('sysr', 24, 'Regular'), fill=(170, 170, 180))
    sym = ImageFont.truetype(B.WIN + 'seguisym.ttf', 19)
    y, n = top, first
    for cat in cats:
        cindex = CATS.index(cat) + 1
        d.text((gap, y + 8), f'{cindex}. {cat[0]}', font=B.font('sys', 30), fill=(240, 240, 245))
        d.text((gap + d.textlength(f'{cindex}. {cat[0]}', font=B.font('sys', 30)) + 20, y + 16),
               f'{FREE_PER_CAT} gratuits · {len(cat[4]) - FREE_PER_CAT} Premium', font=B.font('sysr', 20, 'Regular'), fill=(150, 150, 160))
        y += head_h
        for i, entry in enumerate(cat[4]):
            n += 1
            x = gap + (i % COLS) * (T + gap)
            yy = y + (i // COLS) * (T + label_h)
            layer, mask, _, _ = B.card(spec(cat, i, entry), n - 1, False)
            img.paste(layer.convert('RGB').resize((T, T), Image.LANCZOS), (x, yy), mask.resize((T, T), Image.LANCZOS))
            free = i < FREE_PER_CAT
            tag = '★ Gratuit' if free else '◆ Premium'
            d.text((x + 2, yy + T + 6), f'{n}. {entry.split(":")[0]}', font=B.font('sys', 17), fill=(230, 230, 236))
            d.text((x + 2, yy + T + 24), tag, font=sym, fill=(120, 220, 150) if free else (214, 178, 92))
        y += rows * (T + label_h)
    path = os.path.join(OUT, f'themes-500-page-{number}.png')
    img.save(path, optimize=True)
    return path

def catalogue():
    lines = ['# Ardane : 500 thèmes (2026-11-25)', '', 'Maquette d’après le moteur de styles. 20 catégories de 25 ; ★ gratuit (2 par catégorie, 40 en tout), ◆ Premium (460).', '']
    n = 0
    for c, cat in enumerate(CATS, 1):
        lines += [f'## {c}. {cat[0]}', '', '| # | Thème | Accès | Couleurs | Police | Effets | Graphique |', '|---|---|---|---|---|---|---|']
        for i, entry in enumerate(cat[4]):
            n += 1
            name, bg, ink, accent, fkey, fx, viz = spec(cat, i, entry).split('|')
            lines.append(f'| {n} | {name} | {"★ Gratuit" if i < FREE_PER_CAT else "◆ Premium"} | {bg} · texte {ink} · accent {accent} | {fkey} | {fx or "—"} | {viz} |')
        lines.append('')
    open(os.path.join(OUT, 'themes-500.md'), 'w', encoding='utf-8').write('\n'.join(lines))

if __name__ == '__main__':
    assert len(CATS) == 20 and all(len(c[4]) == 25 for c in CATS), [len(c[4]) for c in CATS]
    catalogue()
    for p in range(5):
        print(page(CATS[p * 4:(p + 1) * 4], p + 1, p * 100))
