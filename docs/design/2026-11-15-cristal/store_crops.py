# Découpe les vraies vignettes du Store dans les captures de l'app (31 octobre) pour la planche 11.
import os, sys
from PIL import Image
K = "C:/Users/Etudiant/ardane-tools/film/public/kit2026/fr/"
OUT = "C:/Users/Etudiant/Documents/GitHub/tessera/pub/rapports/design-2026-11-15-cristal/store-src/"
os.makedirs(OUT, exist_ok=True)
C = {
 "setups.png": {"saison": (49, 1152, 1158, 2375)},
 "store-at-0.12.png": {"bota1": (178, 958, 440, 1220), "bota2": (472, 958, 734, 1220), "bota3": (766, 958, 1028, 1220),
                       "pomodoro": (62, 1635, 1021, 2078), "serie": (1068, 1635, 1206, 2078)},
 "store-at-0.36.png": {"mer1": (62, 308, 395, 655), "mer2": (434, 308, 767, 655), "mer3": (805, 308, 1138, 655), "mer4": (1177, 308, 1206, 655),
                       "nb1": (62, 946, 395, 1674), "nb2": (434, 946, 767, 1674), "nb3": (805, 946, 1138, 1674), "nb4": (1177, 946, 1206, 1674),
                       "doux1": (62, 1966, 395, 2370), "doux2": (434, 1966, 767, 2370), "doux3": (805, 1966, 1138, 2370), "doux4": (1177, 1966, 1206, 2370)},
 "store-at-0.72.png": {"combo-m1": (62, 553, 958, 971), "combo-m2": (1002, 553, 1206, 971), "combo-l1": (62, 1144, 773, 1892), "combo-l2": (818, 1144, 1206, 1892)},
 "store-at-0.84.png": {"fan-retro": (62, 282, 809, 534), "fan-salle": (853, 282, 1206, 534), "ic-retro": (62, 575, 156, 670), "ic-salle": (853, 575, 947, 670),
                       "fan-sportif": (62, 861, 809, 1308), "fan-couleurs": (853, 861, 1206, 1308), "ic-sportif": (62, 1349, 156, 1443), "ic-couleurs": (853, 1349, 947, 1443),
                       "fan-espace": (62, 1999, 809, 2373), "fan-mars": (853, 1999, 1206, 2373)},
}
for f, d in C.items():
    im = Image.open(K + f).convert("RGB")
    for n, b in d.items():
        im.crop(b).save(OUT + n + ".png")
        print(n, b[2] - b[0], b[3] - b[1])
