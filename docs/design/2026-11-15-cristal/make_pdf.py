# make_pdf.py : assemble des images en un PDF lisible sur téléphone (une image par page).
# Usage : ~/ardane-tools/venv/Scripts/python.exe -I make_pdf.py <sortie.pdf> <largeur max en px> <image> [<image>…]
import sys
from PIL import Image

out, maxw, files = sys.argv[1], int(sys.argv[2]), sys.argv[3:]
pages = []
for f in files:
    im = Image.open(f).convert("RGB")
    if im.width > maxw:
        im = im.resize((maxw, round(im.height * maxw / im.width)), Image.LANCZOS)
    pages.append(im)
pages[0].save(out, save_all=True, append_images=pages[1:], resolution=144, quality=86)
print(out, len(pages), "pages")
