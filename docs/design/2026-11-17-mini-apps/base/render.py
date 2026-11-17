# render.py (copie de celui du dossier 2026-11-16-finance ; seule la sortie change) : rend une planche en PNG avec Edge sans interface,
# la rogne à son contenu, en fait une planche-contact JPG et, sur demande, découpe chaque téléphone.
# Un seul script pour tous les sujets : il se lance depuis le dossier base/ OU depuis le dossier du sujet, avec le chemin de la planche.
# Usage : ~/ardane-tools/venv/Scripts/python.exe -I render.py <planche.html> [--phones] [--query check] [--scale 2] [--maxh 9000]
#   --phones : découpe chaque téléphone dans <sortie>/ecrans/<planche>-NN.png (repérés par la couleur du cadre), dans l'ordre des écrans
#              de la planche (rangée par rangée, de gauche à droite), et en écrit une copie réduite à 500 px de large dans
#              <sortie>/ecrans/vus/<planche>-NN.jpg : c'est elle qu'on ouvre pour contrôler (l'original est trop grand pour être lu d'un coup)
#   --query  : paramètres ajoutés à l'URL (check, w375, mode=dark…)
# La largeur vient de <body style="--bw:1860px">.
# Sortie (hors dépôt), calculée depuis le chemin de la planche :
#   <dépôt>/docs/design/2026-11-17-mini-apps/<dossier>/<planche>.html  ->  <dépôt>/pub/rapports/design-2026-11-17-mini-apps/<dossier>/
#   (le nom « design-… » vient du dossier parent : le script sert tel quel à une autre mission de planches)
import argparse, os, re, shutil, subprocess, sys, tempfile, time
import numpy as np
from PIL import Image
from scipy import ndimage

EDGE = r"C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe"
FRAME = (18, 20, 23)  # --frame #121417


def out_dir(src):
    """Dossier de sortie d'une planche : pub/rapports/design-<mission>/<dossier de la planche>/, à la racine du dépôt."""
    folder = os.path.dirname(src)                      # …/docs/design/2026-11-17-mini-apps/nutrition
    mission = os.path.dirname(folder)                  # …/docs/design/2026-11-17-mini-apps
    root = folder
    for _ in range(8):                                 # racine du dépôt : le premier parent qui contient docs/ et .git (ou App/)
        root = os.path.dirname(root)
        if os.path.isdir(os.path.join(root, "docs")) and (os.path.exists(os.path.join(root, ".git")) or os.path.isdir(os.path.join(root, "App"))):
            break
    else:
        root = os.path.normpath(os.path.join(folder, "..", "..", "..", ".."))
    return os.path.join(root, "pub", "rapports", "design-" + os.path.basename(mission), os.path.basename(folder))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("html")
    ap.add_argument("--phones", action="store_true")
    ap.add_argument("--query", default="")
    ap.add_argument("--scale", type=float, default=2)
    ap.add_argument("--maxh", type=int, default=9000)
    a = ap.parse_args()
    src = os.path.abspath(a.html)
    if not os.path.isfile(src):
        sys.exit("planche introuvable : " + src)
    OUT = out_dir(src)
    name = os.path.splitext(os.path.basename(src))[0] + ("-" + re.sub(r"\W+", "", a.query) if a.query else "")
    m = re.search(r"--bw:\s*(\d+)px", open(src, encoding="utf-8").read())
    bw = int(m.group(1)) if m else 1400
    url = "file:///" + src.replace("\\", "/") + ("?" + a.query if a.query else "")
    os.makedirs(OUT, exist_ok=True)
    png = os.path.join(OUT, name + ".png")

    profs = []

    def clean():
        for _ in range(20):
            for d in profs:
                shutil.rmtree(d, ignore_errors=True)
            if not any(os.path.exists(d) for d in profs):
                break
            time.sleep(0.5)

    def shot(scale, height, dest, y=None):
        if os.path.exists(dest):
            os.remove(dest)
        prof = tempfile.mkdtemp(prefix="edge-cristal-")
        u = url if y is None else url + ("&" if "?" in url else "?") + "y=%d" % y
        subprocess.run([EDGE, "--headless", "--disable-gpu", "--hide-scrollbars", "--no-first-run", "--allow-file-access-from-files",
                        "--user-data-dir=" + prof, "--force-device-scale-factor=%g" % scale, "--window-size=%d,%d" % (bw, height),
                        "--screenshot=" + dest, u], capture_output=True, timeout=300)
        profs.append(prof)   # un profil d'Edge pèse environ 60 Mo : tous sont supprimés en fin de script (clean), sinon le disque se remplit
        for _ in range(12):  # et dès la fin de chaque prise, en insistant : Edge garde ses fichiers une seconde ou deux, et plusieurs rendus en parallèle remplissaient le disque
            shutil.rmtree(prof, ignore_errors=True)
            if not os.path.exists(prof):
                break
            time.sleep(0.4)
        for _ in range(80):
            if os.path.exists(dest) and os.path.getsize(dest) > 0:
                break
            time.sleep(0.5)
        else:
            clean()   # même en cas d'échec, ne rien laisser dans le dossier temporaire
            shutil.rmtree(tmp, ignore_errors=True)
            sys.exit("rendu absent : " + dest)
        time.sleep(0.4)

    # 1re passe, toute petite : mesure la hauteur du contenu.
    tmp = tempfile.mkdtemp(prefix="bandes-")
    probe = os.path.join(tmp, "p.png")
    shot(0.25, a.maxh, probe)
    pp = np.asarray(Image.open(probe).convert("RGB")).astype(np.int16)
    prow = np.where((np.abs(pp - pp[-1, -1]).max(axis=2) > 6).any(axis=1))[0]
    if len(prow) == 0:
        sys.exit("planche vide")
    if prow[-1] >= pp.shape[0] - 3:
        print("ATTENTION : la planche dépasse --maxh, relancer avec une valeur plus grande")
    H = int(prow[-1] / 0.25) + 60
    # 2e passe : rendu par bandes de 1 400 points (un rendu trop haut perd des morceaux), avec 120 points de recouvrement, puis assemblage.
    B, PAD, sc = 1400, 120, a.scale
    full = Image.new("RGB", (round(bw * sc), round(H * sc)))
    for k, y0 in enumerate(range(0, H, B)):
        top, end = max(0, y0 - PAD), min(H, y0 + B)
        bot = min(H, end + PAD)
        f = os.path.join(tmp, "b%d.png" % k)
        shot(sc, bot - top, f, y=top)
        band = Image.open(f).convert("RGB")
        full.paste(band.crop((0, round((y0 - top) * sc), band.width, round((end - top) * sc))), (0, round(y0 * sc)))
    full.save(png)
    shutil.rmtree(tmp, ignore_errors=True)
    im = Image.open(png).convert("RGB")
    px = np.asarray(im).astype(np.int16)
    bgc = px[-1, -1]
    rows = np.where((np.abs(px - bgc).max(axis=2) > 6).any(axis=1))[0]
    if len(rows) == 0:
        sys.exit("planche vide")
    bottom = min(im.height, int(rows[-1]) + round(40 * a.scale))
    im = im.crop((0, 0, im.width, bottom))
    im.save(png)
    cw = min(1600, im.width)
    im.resize((cw, round(im.height * cw / im.width)), Image.LANCZOS).save(os.path.join(OUT, name + "-contact.jpg"), quality=82)
    n = 0
    if a.phones:
        d = os.path.join(OUT, "ecrans")
        dv = os.path.join(d, "vus")
        os.makedirs(dv, exist_ok=True)
        for old in os.listdir(d) + [os.path.join("vus", f) for f in os.listdir(dv)]:   # retire les découpes d'un rendu précédent de la même planche (un écran en moins ne laisse pas d'image périmée)
            if re.fullmatch(re.escape(name) + r"-\d\d\.(png|jpg)", os.path.basename(old)):
                os.remove(os.path.join(d, old))
        px = px[:bottom]
        mask = (np.abs(px - np.array(FRAME, dtype=np.int16)).max(axis=2) <= 5)
        lab, _ = ndimage.label(mask)
        boxes = []
        for sl in ndimage.find_objects(lab):
            h, w = sl[0].stop - sl[0].start, sl[1].stop - sl[1].start
            if w > 380 * a.scale and h > 800 * a.scale:
                boxes.append((sl[0].start, sl[1].start, sl[0].stop, sl[1].stop))
        boxes.sort(key=lambda b: (round(b[0] / (300 * a.scale)), b[1]))
        pad = round(6 * a.scale)
        for k, (y0, x0, y1, x1) in enumerate(boxes):
            crop = im.crop((max(0, x0 - pad), max(0, y0 - pad), min(im.width, x1 + pad), min(im.height, y1 + pad)))
            crop.save(os.path.join(d, "%s-%02d.png" % (name, k + 1)))
            crop.resize((500, round(crop.height * 500 / crop.width)), Image.LANCZOS).save(os.path.join(dv, "%s-%02d.jpg" % (name, k + 1)), quality=86)
        n = len(boxes)
    clean()
    print("%s  %dx%d px%s -> %s" % (name, im.width, im.height, ("  %d téléphones" % n) if a.phones else "", png))


main()
