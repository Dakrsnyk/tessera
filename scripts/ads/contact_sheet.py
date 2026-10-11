"""A contact sheet of one scene's clip (frames from prep.py), to pick the moments a film cuts to:

    python3 contact_sheet.py <assets dir> <out dir> <scene> <from s> <to s> <step s>
"""
import sys, glob
from PIL import Image, ImageDraw
assets, out, scene, a, b, step = sys.argv[1], sys.argv[2], sys.argv[3], float(sys.argv[4]), float(sys.argv[5]), float(sys.argv[6])
files = sorted(glob.glob(f"{assets}/clips/{scene}/*.jpg"))
idx = [int(round(t*30)) for t in [a + i*step for i in range(int((b-a)/step)+1)]]
idx = [i for i in idx if i < len(files)]
cols = 10; w = 150; h = int(w*2622/1206)
rows = (len(idx)+cols-1)//cols
sheet = Image.new("RGB", (cols*w, rows*(h+18)), "white"); d = ImageDraw.Draw(sheet)
for k, i in enumerate(idx):
    x, y = (k%cols)*w, (k//cols)*(h+18)
    sheet.paste(Image.open(files[i]).resize((w, h)), (x, y+18)); d.text((x+4, y+3), f"{i/30:.1f}s", fill="black")
sheet.save(f"{out}/{scene}-{a:g}.jpg", quality=80)
