"""Mesure de la règle « zone sûre » du scanner (`ScannerModelLogic.isSureZone`, 2026-11-23).

Avant : une zone est sûre quand le score du segmenteur atteint 0,30. Après : quand score × √(probabilité de son aliment)
atteint 0,20 ; une zone sous 0,30 n'ajoute jamais son aliment seule. Lit les zones écrites par `dump_zones.py` et donne
précision, rappel, F1 des aliments proposés par les zones sûres, les ajouts automatiques (et ceux qui sont faux), et
l'intervalle à 95 % du gain de F1 (bootstrap par photo, 2 000 tirages).

    python scripts/ml/zone_rule.py zones-test.json
"""
import sys
from pathlib import Path
sys.path.insert(0, "scripts/ml")
import meal_context as mc
images = mc.load_zones(Path(sys.argv[1]))
def run(keep, autook):
    tp = fp = fn = auto = autow = 0; per = []
    for im in images:
        truths = set(im["truths"]); prop = {}; au = {}
        for z in im["zones"]:
            p = mc.proposal([(x[0], x[1]) for x in z["top"][:3]])
            if not p or not keep(z, p): continue
            prop[p[0]] = max(prop.get(p[0], 0), p[1])
            if p[1] >= 0.80 and autook(z): au[p[0]] = 1
        a, b, c = len(truths & set(prop)), len(set(prop) - truths), len(truths - set(prop))
        tp += a; fp += b; fn += c; per.append((a, b, c))
        auto += len(au); autow += len(set(au) - truths)
    P = tp/(tp+fp); R = tp/(tp+fn)
    return P, R, 2*P*R/(P+R), auto, autow, per
cur = run(lambda z, p: z["score"] >= 0.30, lambda z: True)
new = run(lambda z, p: z["score"] * p[1] ** 0.5 >= 0.20, lambda z: z["score"] >= 0.30)
for n, r in (("actuel", cur), ("nouvelle regle", new)):
    print(f"{n:16s} P {100*r[0]:.1f} R {100*r[1]:.1f} F1 {100*r[2]:.1f} auto {r[3]} faux {r[4]}")
# bootstrap par photo de la difference de F1
import random
random.seed(0); n = len(images); d = []
def f1(per, idx):
    tp = sum(per[i][0] for i in idx); fp = sum(per[i][1] for i in idx); fn = sum(per[i][2] for i in idx)
    return 2*tp/(2*tp+fp+fn)
for _ in range(2000):
    idx = [random.randrange(n) for _ in range(n)]
    d.append(f1(new[5], idx) - f1(cur[5], idx))
d.sort(); print("delta F1 IC95", round(100*d[50], 2), round(100*d[1949], 2), "part > 0", sum(x > 0 for x in d)/2000)
