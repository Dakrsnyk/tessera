"""Collisions between the sculpted mannequin and the equipment, in every demonstration (2026-11-24).

    ~/ardane-tools/venv/Scripts/python.exe -X utf8 scripts/demos/collisions.py [ids…] [--all] [--min 2.5]

The app draws the sculpted mannequin (sculpt.py, SculptMannequin.swift) from the exported joints, so the body is
tested with its real volume: the trunk as elliptic sections (TRUNK), the limbs as tapered capsules, the head as a ball.
The equipment: every box (bench pads, seats, machine frames, platforms), every line (bars, cables, frames, handles),
every plate (disc) and ball (kettlebells, medicine balls), and loose polygons. A hand holds what it grips: what lies
within HOLD of a grip point is not tested. Prints the demonstrations ranked by their deepest penetration, in cm.
"""
import glob
import importlib
import math
import sys
from pathlib import Path

import numpy as np

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import demos  # noqa: E402
import engine  # noqa: E402
from engine import KIND_BALL, KIND_DISC, KIND_LINE, KIND_POLY  # noqa: E402
from sculpt import TRUNK, interp  # noqa: E402

BODY_ROLES = {"ink", "muscle", "muscle2"}
SKIP_ROLES = BODY_ROLES | {"floor", "mark"}
IGNORE = {"swimming"}   # its only "equipment" is the water line, the body is meant to be in it
HOLD = 0.13          # around a grip, the hand holds the equipment
FOOT_HOLD = 0.10     # around an ankle or a toe, the foot stands on it

# Every box is recorded, solid or not, with its role.
_box = engine.Scene.box


def _record_box(self, center, ax, ay, az, role="pad", stroke=0.012, solid=None, bias=0.0, side=0):
    n0 = len(self.prims)
    _box(self, center, ax, ay, az, role, stroke, solid, bias, side)
    c = np.asarray(center, dtype=float)
    axes = [np.asarray(a, dtype=float) for a in (ax, ay, az)]
    if not hasattr(self, "boxes"):
        self.boxes = []
    self.boxes.append((engine.Solid(c, *axes, solid or role), role, set(range(n0, len(self.prims)))))


engine.Scene.box = _record_box

for path in sorted(glob.glob(str(HERE / "ex_*.py"))):
    importlib.import_module(Path(path).stem)


def profile(table, t):
    return interp(table, t)[0]


ARM = [(0, 0.06), (0.18, 0.058), (0.45, 0.053), (0.75, 0.046), (0.92, 0.04), (1, 0.04)]
FORE = [(0, 0.042), (0.18, 0.047), (0.4, 0.043), (0.75, 0.031), (1, 0.026)]
THIGH = [(0, 0.08), (0.2, 0.086), (0.45, 0.076), (0.75, 0.063), (0.92, 0.052), (1, 0.05)]
SHIN = [(0, 0.049), (0.12, 0.052), (0.3, 0.057), (0.5, 0.049), (0.75, 0.036), (0.92, 0.031), (1, 0.031)]


def limb_samples(b):
    """(point, radius, name) along each limb's axis, with the sculpted radius."""
    out = []

    def seg(a, c, table, name, n=9):
        for t in np.linspace(0, 1, n):
            out.append((a + (c - a) * t, profile(table, t), name))

    for s in (1, -1):
        tag = "droit" if s == 1 else "gauche"
        if s in b.elbow:
            seg(b.shoulder[s], b.elbow[s], ARM, f"bras {tag}")
            seg(b.elbow[s], b.grip[s], FORE, f"avant-bras {tag}", 7)
        if s in b.knee:
            seg(b.hip[s], b.knee[s], THIGH, f"cuisse {tag}")
            seg(b.knee[s], b.ankle[s], SHIN, f"tibia {tag}")
            if s in b.toe:
                seg(b.ankle[s], b.toe[s], [(0, 0.035), (1, 0.025)], f"pied {tag}", 5)
    out.append((b.neck + (b.head - b.neck) * 0.35, 0.05, "cou"))
    out.append((b.head, 0.105, "tête"))
    return out


def trunk_surface(b):
    """Points of the trunk's surface (chest frame, TRUNK sections)."""
    c = b.chest
    pts = []
    for u in np.linspace(TRUNK[0][0], TRUNK[-1][0], 12):
        w, d = interp(TRUNK, u)
        for phi in range(0, 360, 20):
            a = math.radians(phi)
            pts.append(c.at(u=u, r=w * math.sin(a), f=d * math.cos(a)))
    return pts


def trunk_depth(b, q, r):
    """How deep a ball (q, r) goes into the trunk (0 if outside)."""
    c = b.chest
    rel = q - c.o
    u = float(np.dot(rel, c.u))
    lo, hi = TRUNK[0][0], TRUNK[-1][0]
    if u < lo - r or u > hi + r:
        return 0.0
    w, d = interp(TRUNK, min(max(u, lo), hi))
    x, y = float(np.dot(rel, c.r)), float(np.dot(rel, c.f))
    k = math.hypot(x / w, y / d)
    side = 1.0 - k                     # fraction inside the section
    depth = side * min(w, d) + r
    end = min(u - lo, hi - u) + r      # through the bottom or the top
    return max(0.0, min(depth, end))


def near(q, holds, dist):
    return any(np.linalg.norm(q - h) < dist for h in holds)


def line_points(pts, step=0.02):
    out = []
    for a, c in zip(pts, pts[1:]):
        n = max(1, int(np.linalg.norm(c - a) / step))
        out.extend(a + (c - a) * t for t in np.linspace(0, 1, n + 1))
    return out


def disc_points(center, normal, radius):
    n = engine.unit(normal)
    a = engine.unit(np.cross(n, [0.0, 1.0, 0.0] if abs(n[1]) < 0.9 else [1.0, 0.0, 0.0]))
    bb = np.cross(n, a)
    pts = [center]
    for rr in (radius * 0.5, radius):
        for k in range(12):
            t = 2 * math.pi * k / 12
            pts.append(center + (a * math.cos(t) + bb * math.sin(t)) * rr)
    return pts


def poly_points(pts):
    out = list(pts)
    c = np.mean(pts, axis=0)
    out.append(c)
    for p in pts:
        out.append((p + c) / 2)
    return out


def scene_hits(scene):
    """[(depth, body part, equipment)] for one scene."""
    b = scene.body
    if b is None:
        return []
    grips = [b.grip[s] for s in (1, -1) if s in b.grip]
    feet = [b.ankle[s] for s in (1, -1) if s in b.ankle] + [b.toe[s] for s in (1, -1) if s in b.toe]
    limbs = limb_samples(b)
    surface = trunk_surface(b)
    hits = []
    boxes = getattr(scene, "boxes", [])
    in_box = set().union(*[idx for _, _, idx in boxes]) if boxes else set()

    # Boxes against the limbs and the trunk.
    for solid, role, _ in boxes:
        if role in SKIP_ROLES:
            continue
        for q, r, name in limbs:
            if name.startswith(("avant-bras",)) and near(q, grips, HOLD):
                continue
            if name.startswith(("pied", "tibia")) and near(q, feet, FOOT_HOLD):
                # Feet stand on platforms and plates: only going through counts.
                d = solid.penetration(q, r) - 0.03
            else:
                d = solid.penetration(q, r * 0.85)
            if d > 0:
                hits.append((d, name, solid.name))
        for q in surface:
            d = solid.penetration(q, 0.0) - 0.012   # a pad gives a little under the back
            if d > 0:
                hits.append((d, "tronc", solid.name))

    # Lines, plates, balls and loose polygons against the body.
    for i, pr in enumerate(scene.prims):
        if pr.role in SKIP_ROLES or i in in_box:
            continue
        label = {"cable": "câble", "load": "charge", "frame": "cadre", "metal": "barre"}.get(pr.role, pr.role)
        if pr.kind == KIND_LINE:
            pts, rad = line_points(pr.pts), pr.width / 2
        elif pr.kind == KIND_DISC:
            pts, rad, label = disc_points(pr.pts[0], pr.pts[1] - pr.pts[0], pr.width), 0.015, "disque"
        elif pr.kind == KIND_BALL:
            c0 = pr.pts[0]
            pts, rad, label = [c0], pr.width, "boule"
        elif pr.kind == KIND_POLY:
            pts, rad = poly_points(pr.pts), 0.01
        else:
            continue
        for q in pts:
            if near(q, grips, HOLD + rad) or near(q, feet, FOOT_HOLD + rad):
                continue
            d = trunk_depth(b, q, rad) - 0.01
            if d > 0:
                hits.append((d, "tronc", label))
            for p, r, name in limbs:
                dd = r + rad - float(np.linalg.norm(q - p)) - 0.012
                if dd > 0:
                    hits.append((dd, name, label))
    return hits


def analyse(d):
    worst, where = 0.0, None
    parts = {}
    for p, scene in demos.sample(d):
        for depth, part, gear in scene_hits(scene):
            key = (part, gear)
            if depth > parts.get(key, (0,))[0]:
                parts[key] = (depth, p)
            if depth > worst:
                worst, where = depth, (p, part, gear)
    return worst, where, parts


def main():
    args = sys.argv[1:]
    minimum = 2.5
    if "--min" in args:
        i = args.index("--min")
        minimum = float(args[i + 1])
        del args[i:i + 2]
    ids = [a for a in args if not a.startswith("--")] or sorted(set(demos.DEMOS) - IGNORE)
    rows = []
    for ident in ids:
        d = demos.DEMOS[ident]
        try:
            worst, where, parts = analyse(d)
        except Exception as e:  # noqa: BLE001
            print(f"{ident}: erreur {e}")
            continue
        if worst * 100 >= minimum:
            rows.append((worst, ident, where, parts))
    rows.sort(reverse=True)
    for worst, ident, where, parts in rows:
        detail = ", ".join(f"{a}/{g} {v[0] * 100:.0f} (p={v[1]:.2f})"
                           for (a, g), v in sorted(parts.items(), key=lambda kv: -kv[1][0])[:4] if v[0] * 100 >= minimum)
        print(f"{worst * 100:5.1f} cm  {ident:34s} {detail}")
    print(f"\n{len(rows)} démonstrations sur {len(ids)} au-delà de {minimum} cm")


if __name__ == "__main__":
    main()
