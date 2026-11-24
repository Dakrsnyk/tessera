"""The sculpted mannequin (CEO, 2026-11-23, after two reference pictures: a grey sculpted body, a smooth faceless head,
« muscles de la bonne taille et forme, attachés aux bons endroits », less detailed than the references).

The body is a volume, not strokes: the trunk and every limb are rings of cross-sections around the engine's skeleton; the
silhouette is the union of the hulls of consecutive rings, right from any view. Each muscle is an outline drawn ON that
surface, from its origin to its insertion (pectoralis: clavicle and sternum → humerus; biceps: shoulder → radius below the
elbow; hamstrings: ischium → below the knee; gastrocnemius: femoral condyles → Achilles tendon…), with grooves between
its portions. Light from the upper left, soft shadows in the grooves; the muscles worked in red. Review sheet only.

    ~/ardane-tools/venv/Scripts/python.exe scripts/demos/sculpt.py   # writes out/sculpt.html
"""
import json
import math
from pathlib import Path

import numpy as np

import anatomy
import demos
import ex_arms  # noqa: F401
import ex_legs  # noqa: F401
from engine import BACK, FRONT, THREE_QUARTER, lerp, unit

ROOT = Path(__file__).resolve().parents[2]
EXPORTED = json.loads((ROOT / "App" / "Resources" / "ExerciseDemos.json").read_text(encoding="utf-8"))["demos"]


# --- Geometry helpers ---------------------------------------------------------------------------------

def hull(points):
    pts = sorted(set((round(x, 2), round(y, 2)) for x, y in points))
    if len(pts) < 3:
        return pts

    def cross(o, a, b):
        return (a[0] - o[0]) * (b[1] - o[1]) - (a[1] - o[1]) * (b[0] - o[0])
    lower, upper = [], []
    for p in pts:
        while len(lower) >= 2 and cross(lower[-2], lower[-1], p) <= 0:
            lower.pop()
        lower.append(p)
    for p in reversed(pts):
        while len(upper) >= 2 and cross(upper[-2], upper[-1], p) <= 0:
            upper.pop()
        upper.append(p)
    return lower[:-1] + upper[:-1]


def smooth(P, close=True, tension=6.0):
    n = len(P)
    if n < 3:
        return ""
    d = f"M{P[0][0]:.1f},{P[0][1]:.1f} "
    for i in range(n if close else n - 1):
        p0, p1, p2, p3 = P[(i - 1) % n], P[i], P[(i + 1) % n], P[(i + 2) % n]
        c1 = (p1[0] + (p2[0] - p0[0]) / tension, p1[1] + (p2[1] - p0[1]) / tension)
        c2 = (p2[0] - (p3[0] - p1[0]) / tension, p2[1] - (p3[1] - p1[1]) / tension)
        d += f"C{c1[0]:.1f},{c1[1]:.1f} {c2[0]:.1f},{c2[1]:.1f} {p2[0]:.1f},{p2[1]:.1f} "
    return d + ("Z" if close else "")


def polyline(P):
    return "M" + " L".join(f"{x:.1f},{y:.1f}" for x, y in P)


class Cam:
    def __init__(self, view, box, W, H, close, margin=10):
        self.view = view
        minx, miny, maxx, maxy = box
        self.k = min((W - 2 * margin) / (maxx - minx), (H - 2 * margin) / (maxy - miny))
        if not close:
            self.k = min(self.k, (H - 2 * margin) / 1.8)
        self.cx, self.cy, self.W, self.H = (minx + maxx) / 2, (miny + maxy) / 2, W, H
        self.toward = view.basis()[2]

    def p(self, q):
        x, y, z = self.view.project(np.array([q]))[0]
        return (self.W / 2 + (x - self.cx) * self.k, self.H / 2 - (y - self.cy) * self.k, z)


# --- The body's surface -------------------------------------------------------------------------------

# Trunk sections (height in the chest frame, from the waist): half-width, half-depth. Neutral build, no gendered form.
TRUNK = [(-0.215, 0.105, 0.08), (-0.19, 0.138, 0.096), (-0.15, 0.155, 0.104), (-0.08, 0.160, 0.107), (0.0, 0.133, 0.092), (0.10, 0.139, 0.098),
         (0.20, 0.152, 0.107), (0.27, 0.164, 0.111), (0.31, 0.172, 0.106), (0.34, 0.168, 0.096), (0.36, 0.148, 0.086),
         (0.375, 0.115, 0.074), (0.39, 0.078, 0.062), (0.405, 0.056, 0.054)]


def interp(table, x):
    xs = [t[0] for t in table]
    x = min(max(x, xs[0]), xs[-1])
    for (x0, *a), (x1, *b) in zip(table, table[1:]):
        if x0 <= x <= x1:
            f = (x - x0) / (x1 - x0) if x1 > x0 else 0
            return [ai + (bi - ai) * f for ai, bi in zip(a, b)]
    return list(table[-1][1:])


class Body:
    def __init__(self, b):
        self.b = b
        self.c = b.chest
        self.limbs = {}
        for s in (1, -1):
            c = self.c
            if s in b.elbow:
                sh, el, gr = b.shoulder[s], b.elbow[s], b.grip[s]
                arm, fore = unit(el - sh), unit(gr - el)
                bend = fore - np.dot(fore, arm) * arm
                # Straight arm: its front is the trunk's front made square to it (the biceps faces forward, as standing).
                straight = c.f - np.dot(c.f, arm) * arm
                if np.linalg.norm(bend) > 0.08:
                    front = unit(bend)
                elif np.linalg.norm(straight) > 0.2:
                    front = unit(straight)
                else:
                    # A straight arm pointing forward or back: the biceps faces up. (The trunk's front, along the arm,
                    # made the arm a flat sheet.)
                    front = unit(c.u - np.dot(c.u, arm) * arm)
                away = unit(np.cross(arm, front))
                if np.dot(away, c.r * s) < 0:
                    away = -away
                # The forearm's front is the arm's front turned by the bend of the elbow: never along the forearm (at a
                # right angle the arm's front IS the forearm's direction, and the forearm and the hand were flat sheets).
                ffront = front * np.dot(fore, arm) - arm * np.dot(fore, front)
                ffront = ffront - np.dot(ffront, fore) * fore
                ffront = unit(ffront) if np.linalg.norm(ffront) > 0.2 else unit(np.cross(away, fore))
                faway = unit(np.cross(fore, ffront))
                if np.dot(faway, away) < 0:
                    faway = -faway
                self.limbs[("arm", s)] = (sh, el, front, away, [(0, 0.06), (0.18, 0.058), (0.45, 0.053), (0.75, 0.046), (0.92, 0.04), (1, 0.04)])
                self.limbs[("fore", s)] = (el, gr, ffront, faway, [(0, 0.042), (0.18, 0.047), (0.4, 0.043), (0.75, 0.031), (1, 0.026)])
            if s in b.knee:
                p = b.pelvis
                hip, kn, an = b.hip[s], b.knee[s], b.ankle[s]
                thigh, shin = unit(kn - hip), unit(an - kn)
                tf, sf = np.cross(p.r, thigh), np.cross(p.r, shin)
                # A leg along the hips' axis (side split): its front is the pelvis's front made square to it.
                tf = unit(tf) if np.linalg.norm(tf) > 0.2 else unit(p.f - np.dot(p.f, thigh) * thigh)
                sf = unit(sf) if np.linalg.norm(sf) > 0.2 else unit(p.f - np.dot(p.f, shin) * shin)
                # The outer side, square to the limb (the hips' axis itself squashed a leg opened to the side).
                ta, sa = np.cross(thigh, tf), np.cross(shin, sf)
                ta = ta if np.dot(ta, p.r * s) >= 0 else -ta
                sa = sa if np.dot(sa, p.r * s) >= 0 else -sa
                if abs(np.dot(thigh, p.r)) < 0.3:
                    ta = p.r * s
                if abs(np.dot(shin, p.r)) < 0.3:
                    sa = p.r * s
                self.limbs[("thigh", s)] = (hip, kn, tf, ta, [(-0.04, 0.072), (0.08, 0.084), (0.2, 0.086), (0.45, 0.076), (0.75, 0.063), (0.92, 0.052), (1, 0.05)])
                self.limbs[("shin", s)] = (kn, an, sf, sa, [(0, 0.049), (0.12, 0.052), (0.3, 0.057), (0.5, 0.049), (0.75, 0.036), (0.92, 0.031), (1, 0.031)])

    def trunk_smooth(self, u, phi, s=1, lift=1.0):
        w, d = smooth_interp(TRUNK, u)
        a = math.radians(phi)
        return self.c.at(u=u, r=w * math.sin(a) * s * lift, f=d * math.cos(a) * lift)

    def trunk(self, u, phi, s=1, lift=1.0):
        """A point of the trunk's surface: height u, angle phi (degrees: 0 front, 90 the side s, 180 back)."""
        return self.trunk_smooth(u, phi, s, lift)

    def trunk_normal(self, u, phi, s=1):
        w, d = interp(TRUNK, u)
        a = math.radians(phi)
        return unit(self.c.r * math.sin(a) * s / w + self.c.f * math.cos(a) / d)

    def limb(self, key, t, theta, lift=1.0):
        a, b, front, away, prof = self.limbs[key]
        r = smooth_interp([(x, y) for x, y in prof], t)[0]
        ang = math.radians(theta)
        return lerp(a, b, t) + (front * math.cos(ang) + away * math.sin(ang)) * r * lift

    def limb_normal(self, key, t, theta):
        a, b, front, away, _ = self.limbs[key]
        ang = math.radians(theta)
        return unit(front * math.cos(ang) + away * math.sin(ang))

    def point(self, spec, s, lift=1.03):
        kind = spec[0]
        if kind == "T":
            return self.trunk(spec[1], spec[2], s, lift)
        return self.limb((kind, s), spec[1], spec[2], lift)

    def normal(self, spec, s):
        if spec[0] == "T":
            return self.trunk_normal(spec[1], spec[2], s)
        return self.limb_normal((spec[0], s), spec[1], spec[2])


def smooth_interp(table, x):
    """Like interp, but eased between rows (no corners in the silhouette)."""
    xs = [t[0] for t in table]
    x = min(max(x, xs[0]), xs[-1])
    for (x0, *a), (x1, *b) in zip(table, table[1:]):
        if x0 <= x <= x1:
            f = (x - x0) / (x1 - x0) if x1 > x0 else 0
            f = f * f * (3 - 2 * f)
            return [ai + (bi - ai) * f for ai, bi in zip(a, b)]
    return list(table[-1][1:])


def ellipsoid(cam, center, axes, steps=(10, 16)):
    """A projected ellipsoid (axes: three vectors, their lengths the radii) as a smooth outline and its depth."""
    pts = []
    for i in range(1, steps[0]):
        th = math.pi * i / steps[0]
        for j in range(steps[1]):
            ph = 2 * math.pi * j / steps[1]
            pts.append(center + axes[0] * math.cos(th) + axes[1] * math.sin(th) * math.cos(ph) + axes[2] * math.sin(th) * math.sin(ph))
    pts += [center + axes[0], center - axes[0]]
    P = [cam.p(q) for q in pts]
    return smooth(hull([q[:2] for q in P]), tension=7), cam.p(center)[2]


def skin(cam, body):
    """The plastic body: smooth sweeps (many sections, eased profiles), ball joints, ovoid hands and feet, an egg head.
    Each piece: (d, depth, axis) — axis (a, b, radius) for the limbs' cylinder shading, None otherwise."""
    out = []
    ring = lambda pts: [cam.p(q) for q in pts]
    angles = range(0, 360, 15)

    def sweep(rings, axis=None, bias=0.0):
        for r0, r1 in zip(rings, rings[1:]):
            P = r0 + r1
            out.append((smooth(hull([q[:2] for q in P]), tension=9), float(np.mean([q[2] for q in P])) + bias, axis))

    c, b = body.c, body.b
    lo, hi = TRUNK[0][0], TRUNK[-1][0]
    us = [lo + (hi - lo) * k / 30 for k in range(31)]
    sweep([ring([body.trunk_smooth(u, phi) for phi in angles]) for u in us])
    # Neck, head.
    nb, nt = b.neck - c.u * 0.04, b.head - b.head_frame.u * 0.07
    sweep([ring([lerp(nb, nt, t) + (c.r * math.sin(math.radians(a)) + c.f * math.cos(math.radians(a))) * (0.056 - 0.01 * t)
                 for a in angles]) for t in (0, 0.5, 1)])
    hf = b.head_frame
    d, z = ellipsoid(cam, b.head + hf.u * 0.012, [hf.u * 0.122, hf.f * 0.098, hf.r * 0.083])
    out.append((d, z - 0.01, None))
    jaw, zj = ellipsoid(cam, b.head - hf.u * 0.05 + hf.f * 0.02, [hf.u * 0.06, hf.f * 0.07, hf.r * 0.062])
    out.append((jaw, zj - 0.008, None))
    # Limbs with ball joints.
    for key, (a, e, front, away, prof) in body.limbs.items():
        t0, t1 = prof[0][0], prof[-1][0]
        ts = [t0 + (t1 - t0) * k / 14 for k in range(15)]
        r_mid = smooth_interp(prof, 0.5)[0]
        sweep([ring([body.limb(key, t, th) for th in angles]) for t in ts], axis=(a, e, r_mid))
    joints = []
    for s in (1, -1):
        if s in b.elbow:
            arm_dir = unit(b.elbow[s] - b.shoulder[s])
            # The shoulder's ball sits inside the deltoid, a little down the arm: it rounds the shoulder without sticking out.
            joints += [(b.shoulder[s] + arm_dir * 0.03, 0.05), (b.elbow[s], 0.041), (b.grip[s] - unit(b.grip[s] - b.elbow[s]) * 0.02, 0.028)]
        if s in b.knee:
            joints += [(b.knee[s], 0.05), (b.ankle[s], 0.033)]
    for center, r in joints:
        x, y, z = cam.p(center)
        rr = r * cam.k
        out.append((f"M{x - rr:.1f},{y:.1f} a{rr:.1f},{rr:.1f} 0 1 0 {2 * rr:.1f},0 a{rr:.1f},{rr:.1f} 0 1 0 {-2 * rr:.1f},0 Z", z, None))
    # Hands: an ovoid palm and a thumb. Feet: a heel and an ovoid foot.
    for s in (1, -1):
        if s in b.grip:
            el, g = b.elbow[s], b.grip[s]
            _, _, ff, fa, _ = body.limbs[("fore", s)]
            dvec = unit(g - el)
            d, z = ellipsoid(cam, g + dvec * 0.035, [dvec * 0.058, fa * 0.034, ff * 0.019])
            out.append((d, z, None))
            d, z = ellipsoid(cam, g + dvec * 0.01 + ff * 0.02 - fa * 0.012, [dvec * 0.03, ff * 0.012, fa * 0.012])
            out.append((d, z - 0.004, None))
        if s in b.toe:
            for center, axes in foot_axes(b, s):
                d, z = ellipsoid(cam, center, axes)
                out.append((d, z, None))
    return out


def foot_axes(b, s):
    """The heel and the foot as ellipsoids: [(center, [three axes])]."""
    an, to = b.ankle[s], b.toe[s]
    dvec = unit(to - an)
    dvec_flat = unit(np.array([dvec[0], 0.0, dvec[2]])) if np.linalg.norm([dvec[0], dvec[2]]) > 1e-3 else dvec
    up = np.array([0.0, 1.0, 0.0])
    side = b.pelvis.r
    # A foot on the ground is built level, its sole down. A foot that points up or down (the back foot of a stride, a
    # handstand, a plank on the toes) takes its own top instead, toward the shin: built on the vertical, it was a flat sheet.
    steep = min(1.0, max(0.0, (abs(float(dvec[1])) - 0.45) / 0.35))
    steep = steep * steep * (3 - 2 * steep)
    if steep > 0:
        top = (b.knee[s] - an) if s in b.knee else up
        top = top - np.dot(top, dvec) * dvec
        if np.linalg.norm(top) < 0.15:
            top = np.cross(side, dvec)
        top = unit(top)
        if np.dot(top, up) < 0.2:
            steep = 1.0          # upside down (legs in the air): no blend with the vertical, they would cancel
        up = unit(up * (1 - steep) + top * steep)
        level = dvec_flat * (1 - steep) + dvec * steep
        level = level - up * np.dot(level, up)
        dvec_flat = unit(level) if np.linalg.norm(level) > 0.2 else dvec
    # The foot's width, square to its length and its height (the hips' axis squashed a foot turned to the side).
    if abs(float(np.dot(dvec_flat, np.cross(up, side)))) < 0.8 or abs(float(np.dot(dvec, np.cross(up, side)))) < 0.8:
        across = np.cross(up, dvec)
        if np.linalg.norm(across) > 0.2:
            side = unit(across) if np.dot(across, side) >= 0 else -unit(across)
    heel = an - dvec_flat * 0.035 - up * 0.035
    mid = lerp(an, to, 0.55) - up * 0.012
    return [(heel, [dvec_flat * 0.04, up * 0.03, side * 0.032]), (mid, [dvec * 0.11, up * 0.026, side * 0.04])]


# --- Muscles: outlines from origin to insertion ------------------------------------------------------------
# A point: ("T", height, angle) on the trunk, or (limb, t along it, angle) with limb in arm, fore, thigh, shin
# (angle 0 front, 90 outer side, 180 back, -90 inner side). Grooves split the portions.

M = {
    "chest": [
        dict(name="Grand pectoral", outline=[("T", .372, 4), ("T", .378, 30), ("T", .362, 56), ("arm", .14, -25), ("arm", .21, -40),
                                             ("T", .275, 74), ("T", .225, 58), ("T", .205, 34), ("T", .2, 4)],
             grooves=[[("T", .33, 4), ("T", .335, 30), ("arm", .16, -30)]]),
    ],
    "shoulders": [
        # Origin: lateral third of the clavicle, acromion, spine of the scapula; insertion: deltoid tuberosity (mid-humerus).
        dict(name="Deltoïde", outline=[("T", .368, 44), ("arm", .1, -52), ("arm", .3, -32), ("arm", .47, 28), ("arm", .3, 118),
                                       ("arm", .1, 150), ("T", .352, 128), ("T", .376, 88)],
             grooves=[[("T", .372, 64), ("arm", .4, 12)], [("T", .366, 110), ("arm", .4, 60)]], lift=1.12),
    ],
    "biceps": [
        dict(name="Biceps", outline=[("arm", .2, -28), ("arm", .2, 22), ("arm", .55, 42), ("arm", .86, 26), ("fore", .1, 12),
                                     ("arm", .86, -14), ("arm", .55, -38)], grooves=[[("arm", .22, -3), ("arm", .82, 5)]], lift=1.1),
        dict(name="Brachial", outline=[("arm", .58, 52), ("arm", .9, 70), ("fore", .06, 50), ("arm", .9, 38)], lift=1.04),
    ],
    "triceps": [
        dict(name="Triceps", outline=[("arm", .16, 118), ("arm", .16, 210), ("arm", .55, 228), ("arm", .82, 200), ("arm", .99, 182),
                                      ("arm", .82, 150), ("arm", .55, 112)],
             grooves=[[("arm", .2, 165), ("arm", .62, 172)], [("arm", .62, 140), ("arm", .72, 175), ("arm", .62, 215)]], lift=1.08),
    ],
    "forearms": [
        dict(name="Brachio-radial", outline=[("arm", .68, 62), ("arm", .72, 95), ("fore", .3, 85), ("fore", .82, 55), ("fore", .3, 45)], lift=1.08),
        dict(name="Fléchisseurs", outline=[("fore", .02, -15), ("fore", .02, -85), ("fore", .45, -75), ("fore", .85, -30), ("fore", .45, 8)], lift=1.05),
        dict(name="Extenseurs", outline=[("fore", .04, 100), ("fore", .04, 175), ("fore", .5, 175), ("fore", .86, 130), ("fore", .5, 105)], lift=1.05),
    ],
    "abs": [
        dict(name="Grand droit", outline=[("T", .205, 3), ("T", .205, 27), ("T", .1, 27), ("T", .0, 24), ("T", -.1, 16), ("T", -.165, 5)],
             grooves=[[("T", .155, 3), ("T", .158, 27)], [("T", .105, 3), ("T", .108, 27)], [("T", .05, 3), ("T", .052, 25)]]),
        dict(name="Oblique externe", outline=[("T", .2, 50), ("T", .19, 82), ("T", .02, 95), ("T", -.08, 86), ("T", -.11, 60),
                                              ("T", -.02, 34), ("T", .12, 30)]),
        dict(name="Dentelé", outline=[("T", .29, 68), ("T", .27, 84), ("T", .19, 86), ("T", .17, 72), ("T", .23, 62)],
             grooves=[[("T", .25, 64), ("T", .245, 85)], [("T", .215, 66), ("T", .21, 85)]]),
    ],
    "traps": [
        dict(name="Trapèze", outline=[("T", .41, 178), ("T", .405, 140), ("T", .372, 110), ("T", .335, 122), ("T", .315, 150),
                                      ("T", .17, 177)],
             grooves=[[("T", .392, 168), ("T", .35, 128)], [("T", .3, 177), ("T", .318, 152)]]),
    ],
    "back": [
        dict(name="Infra-épineux", outline=[("T", .31, 152), ("T", .312, 122), ("T", .245, 115), ("T", .21, 135), ("T", .25, 160)]),
        dict(name="Grand rond", outline=[("T", .245, 112), ("T", .27, 100), ("arm", .14, 185), ("T", .225, 112)], lift=1.04),
        dict(name="Grand dorsal", outline=[("T", .24, 176), ("T", .235, 150), ("T", .215, 120), ("T", .27, 104), ("T", .14, 98),
                                           ("T", .02, 104), ("T", -.04, 150), ("T", -.02, 176)]),
    ],
    "lowerBack": [
        dict(name="Érecteurs", outline=[("T", .21, 177), ("T", .21, 162), ("T", .02, 160), ("T", -.06, 165), ("T", -.07, 177)]),
    ],
    "glutes": [
        dict(name="Grand fessier", outline=[("T", -.06, 172), ("T", -.05, 128), ("T", -.12, 104), ("thigh", .2, 105), ("thigh", .22, 160),
                                            ("T", -.21, 176)], lift=1.06),
        dict(name="Moyen fessier", outline=[("T", -.01, 100), ("T", .0, 138), ("T", -.05, 145), ("T", -.1, 104)], lift=1.03),
    ],
    "quads": [
        dict(name="Droit fémoral", outline=[("thigh", .04, -8), ("thigh", .04, 14), ("thigh", .5, 22), ("thigh", .9, 9), ("thigh", .9, -9),
                                            ("thigh", .5, -20)], lift=1.08),
        dict(name="Vaste latéral", outline=[("thigh", .12, 26), ("thigh", .12, 100), ("thigh", .55, 104), ("thigh", .92, 62),
                                            ("thigh", .96, 22), ("thigh", .55, 26)], lift=1.06),
        dict(name="Vaste médial", outline=[("thigh", .55, -22), ("thigh", .72, -58), ("thigh", .93, -50), ("thigh", .97, -16),
                                           ("thigh", .82, -12)], lift=1.08),
        dict(name="Sartorius", outline=[("thigh", -.02, 48), ("thigh", .06, 36), ("thigh", .5, -32), ("thigh", .95, -78), ("thigh", .97, -95),
                                        ("thigh", .55, -52), ("thigh", .1, 20)], lift=1.1),
    ],
    "adductors": [
        dict(name="Adducteurs", outline=[("thigh", .0, -32), ("thigh", .0, -118), ("thigh", .5, -112), ("thigh", .62, -72), ("thigh", .25, -34)],
             lift=1.03),
    ],
    "hamstrings": [
        dict(name="Ischio-jambiers", outline=[("thigh", .1, 116), ("thigh", .1, 215), ("thigh", .6, 238), ("thigh", .97, 230),
                                              ("thigh", .97, 120), ("thigh", .6, 110)],
             grooves=[[("thigh", .12, 168), ("thigh", .9, 172)]], lift=1.06),
    ],
    "calves": [
        dict(name="Gastrocnémien", outline=[("shin", -.02, 110), ("shin", -.02, 250), ("shin", .3, 255), ("shin", .58, 205), ("shin", .6, 175),
                                            ("shin", .5, 140), ("shin", .26, 105)], grooves=[[("shin", .0, 178), ("shin", .5, 180)]], lift=1.1),
        dict(name="Soléaire", outline=[("shin", .32, 100), ("shin", .32, 260), ("shin", .82, 215), ("shin", .82, 145)], lift=1.03),
        dict(name="Tibial antérieur", outline=[("shin", .05, 8), ("shin", .05, 58), ("shin", .6, 42), ("shin", .92, 4), ("shin", .6, 12)], lift=1.05),
    ],
}


def muscle_shapes(cam, body, active):
    out = []
    for group, muscles in M.items():
        for s in (1, -1):
            for mu in muscles:
                specs = mu["outline"]
                if any(sp[0] != "T" and (sp[0], s) not in body.limbs for sp in specs):
                    continue
                lift = mu.get("lift", 1.03)
                P = [cam.p(body.point(sp, s, lift)) for sp in specs]
                normal = unit(sum(body.normal(sp, s) for sp in specs))
                facing = float(np.dot(normal, cam.toward))
                if facing < -0.05:
                    continue
                grooves = [polyline([cam.p(body.point(sp, s, lift * 1.01))[:2] for sp in g]) for g in mu.get("grooves", [])]
                depth = float(np.mean([q[2] for q in P])) - 0.01
                out.append(dict(d=smooth([q[:2] for q in P], tension=6.5), depth=depth, active=group in active, grooves=grooves,
                                facing=facing))
    return out


# --- Drawing ------------------------------------------------------------------------------------------------

STYLES = {
    "Plastique gris": dict(bg="#0F1013", bg2="#26282D", skin="#C4C7CC", hi="#EEF0F2", lo="#7E838B", groove="#5E636B",
                           red="#E5484D", red_hi="#FF8F93", red_lo="#9E1C22", metal="#5E636B", floor="#1C1E23", pad="#3A3E45"),
    "Plastique clair": dict(bg="#E4E6EA", bg2="#FBFBFC", skin="#D5D8DC", hi="#FFFFFF", lo="#959AA2", groove="#7A7F87",
                            red="#E5484D", red_hi="#FF8F93", red_lo="#9E1C22", metal="#5B6068", floor="#D3D5DA", pad="#9A9FA8"),
}


def gear(cam, scene):
    """The equipment of the exercise (bars, dumbbells, bench, cable, floor), simply, behind or in front of the body."""
    out = []
    for pr in scene.prims:
        if pr.role in ("ink", "muscle", "muscle2"):
            continue
        P = [cam.p(q) for q in pr.pts]
        z = float(np.mean([q[2] for q in P])) + pr.bias
        w = max(pr.width * cam.k, 1.0)
        if pr.kind == 0:
            out.append((z, f'<path d="{polyline([q[:2] for q in P])}" fill="none" stroke="{{metal}}" stroke-width="{w:.1f}" stroke-linecap="round"/>', pr.role))
        elif pr.kind == 1:
            d = polyline([q[:2] for q in P]) + " Z"
            out.append((z, f'<path d="{d}" fill="{{{"floor" if pr.role == "floor" else "pad"}}}"/>', pr.role))
        else:
            x, y, _ = P[0]
            out.append((z, f'<circle cx="{x:.1f}" cy="{y:.1f}" r="{w:.1f}" fill="{{metal}}" fill-opacity="0.85" stroke="{{metal_lo}}" stroke-width="1.2"/>', pr.role))
    return out


def render(scene, view, box, close, active, st, W, H, uid):
    """Plastic mannequin: one light for the whole body (no bands between pieces), a sheen along each limb, muscles as a
    soft relief of the same plastic (a shadowed groove below right, a light edge above left); the worked ones in red."""
    cam = Cam(view, box, W, H, close)
    body = Body(scene.body)
    sk = skin(cam, body)
    mus = muscle_shapes(cam, body, set(active))
    colours = dict(metal=st.get("metal", "#6B7078"), metal_lo=st.get("metal_lo", "#41454C"), floor=st.get("floor", "#1C1E23"),
                   pad=st.get("pad", "#3A3E45"))
    items = [(z, 0, (d, axis)) for d, z, axis in sk] + [(m["depth"], 1, m) for m in mus] + \
            [(z, 2, svg.format(**colours)) for z, svg, role in gear(cam, scene)]
    items.sort(key=lambda it: -it[0])
    g = max(0.8, W / 220)   # one unit of softness, in pixels
    defs = [
        f'<radialGradient id="bg{uid}" cx="50%" cy="38%" r="72%"><stop offset="0" stop-color="{st["bg2"]}"/><stop offset="1" stop-color="{st["bg"]}"/></radialGradient>',
        # One light for the whole body: upper left, in the panel's coordinates.
        f'<linearGradient id="sk{uid}" gradientUnits="userSpaceOnUse" x1="{W * 0.15:.0f}" y1="0" x2="{W * 0.85:.0f}" y2="{H:.0f}">'
        f'<stop offset="0" stop-color="{st["hi"]}"/><stop offset="0.5" stop-color="{st["skin"]}"/><stop offset="1" stop-color="{st["lo"]}"/></linearGradient>',
        f'<linearGradient id="re{uid}" gradientUnits="userSpaceOnUse" x1="{W * 0.15:.0f}" y1="0" x2="{W * 0.85:.0f}" y2="{H:.0f}">'
        f'<stop offset="0" stop-color="{st["red_hi"]}"/><stop offset="0.5" stop-color="{st["red"]}"/><stop offset="1" stop-color="{st["red_lo"]}"/></linearGradient>',
        f'<filter id="b1{uid}" x="-30%" y="-30%" width="160%" height="160%"><feGaussianBlur stdDeviation="{g * 1.1:.2f}"/></filter>',
        f'<filter id="b2{uid}" x="-30%" y="-30%" width="160%" height="160%"><feGaussianBlur stdDeviation="{g * 2.4:.2f}"/></filter>',
        f'<filter id="sh{uid}" x="-30%" y="-30%" width="160%" height="160%"><feDropShadow dx="0" dy="{g * 2:.1f}" stdDeviation="{g * 3:.1f}" flood-color="#000" flood-opacity="0.5"/></filter>',
    ]
    clip_all = f"ca{uid}"
    defs.append(f'<clipPath id="{clip_all}">' + "".join(f'<path d="{d}"/>' for d, _, _ in sk) + "</clipPath>")
    body_svg = []
    k = 0
    lx, ly = -0.62, -0.78   # light direction on screen (toward the upper left)
    for z, kind, obj in items:
        if kind == 2:
            body_svg.append(obj)
            continue
        if kind == 0:
            d, axis = obj
            body_svg.append(f'<path d="{d}" fill="url(#sk{uid})" stroke="url(#sk{uid})" stroke-width="0.6"/>')
            if axis is not None:
                # Plastic sheen: a soft light line along the lit side of the limb, a soft shade along the other.
                a, e, r = axis
                A, B = cam.p(a), cam.p(e)
                dx, dy = B[0] - A[0], B[1] - A[1]
                n = math.hypot(dx, dy)
                if n > 2:
                    px, py = -dy / n, dx / n
                    if px * lx + py * ly < 0:
                        px, py = -px, py * -1
                    rp = r * cam.k
                    k += 1
                    cid = f"cl{uid}_{k}"
                    defs.append(f'<clipPath id="{cid}"><path d="{d}"/></clipPath>')
                    body_svg.append(
                        f'<g clip-path="url(#{cid})">'
                        f'<path d="M{A[0] + px * rp * 0.42:.1f},{A[1] + py * rp * 0.42:.1f} L{B[0] + px * rp * 0.42:.1f},{B[1] + py * rp * 0.42:.1f}" '
                        f'stroke="#FFFFFF" stroke-opacity="0.42" stroke-width="{rp * 0.45:.1f}" stroke-linecap="round" filter="url(#b2{uid})"/>'
                        f'<path d="M{A[0] - px * rp * 0.95:.1f},{A[1] - py * rp * 0.95:.1f} L{B[0] - px * rp * 0.95:.1f},{B[1] - py * rp * 0.95:.1f}" '
                        f'stroke="#000000" stroke-opacity="0.26" stroke-width="{rp * 0.7:.1f}" stroke-linecap="round" filter="url(#b2{uid})"/></g>')
            continue
        m = obj
        k += 1
        cid = f"cm{uid}_{k}"
        defs.append(f'<clipPath id="{cid}"><path d="{m["d"]}"/></clipPath>')
        groove = st["red_lo"] if m["active"] else st["groove"]
        fill = f"url(#re{uid})" if m["active"] else f"url(#sk{uid})"
        # Relief: the muscle in the same plastic, a shade inside its lower-right edge, a light inside its upper-left one.
        relief = (f'<g clip-path="url(#{cid})">'
                  f'<path d="{m["d"]}" fill="none" stroke="{groove}" stroke-opacity="{0.55 if m["active"] else 0.5}" stroke-width="{g * 3.2:.1f}" '
                  f'transform="translate({g * 1.2:.1f},{g * 1.4:.1f})" filter="url(#b1{uid})"/>'
                  f'<path d="{m["d"]}" fill="none" stroke="#FFFFFF" stroke-opacity="{0.25 if m["active"] else 0.45}" stroke-width="{g * 2.2:.1f}" '
                  f'transform="translate({-g * 1.3:.1f},{-g * 1.5:.1f})" filter="url(#b1{uid})"/>'
                  + "".join(f'<path d="{gr}" fill="none" stroke="{groove}" stroke-opacity="0.45" stroke-width="{g * 1.4:.1f}" stroke-linecap="round" '
                            f'filter="url(#b1{uid})"/>' for gr in m["grooves"]) + "</g>")
        body_svg.append(f'<g clip-path="url(#{clip_all})"><path d="{m["d"]}" fill="{fill}" fill-opacity="{0.94 if m["active"] else 1}"/>{relief}</g>')
    svg = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" viewBox="0 0 {W} {H}"><defs>{"".join(defs)}</defs>',
           f'<rect width="{W}" height="{H}" rx="14" fill="url(#bg{uid})"/>',
           f'<g filter="url(#sh{uid})">{"".join(body_svg)}</g></svg>']
    return "".join(svg)


def pose(ident, p):
    return demos.DEMOS[ident].scene(p)


if __name__ == "__main__":
    for group, (muscles, view, margin) in anatomy.GROUPS.items():
        if f"anatomy-{group}" not in demos.DEMOS:
            anatomy.register(group, muscles, view)
    full = [-0.62, -0.06, 0.62, 1.88]
    stand = pose("anatomy-quads", 0.25)
    arms = pose("anatomy-biceps", 0.25)
    curl = pose("db-curl", 0.6)
    squat = pose("back-squat", 0.5)
    shots = [
        ("Face", stand, FRONT(4), full, False, ["chest", "abs"], 250, 380),
        ("Dos", stand, BACK(4), full, False, ["back", "traps"], 250, 380),
        ("3/4", stand, THREE_QUARTER(35, 6), full, False, ["shoulders", "quads"], 250, 380),
        ("Pectoraux", stand, FRONT(4), [-0.36, 0.95, 0.36, 1.62], True, ["chest"], 300, 280),
        ("Bras", arms, FRONT(4), [-0.42, 0.95, 0.42, 1.62], True, ["biceps", "forearms"], 300, 280),
        ("Dos", stand, BACK(4), [-0.36, 0.92, 0.36, 1.66], True, ["back", "traps"], 300, 280),
        ("Cuisses", stand, FRONT(4), [-0.36, 0.38, 0.36, 1.06], True, ["quads"], 300, 280),
        ("Arrière des jambes", stand, BACK(4), [-0.36, 0.08, 0.36, 1.0], True, ["hamstrings", "calves", "glutes"], 300, 280),
        ("Curl haltère", curl, demos.DEMOS["db-curl"].views[0], EXPORTED["db-curl"]["views"][0]["box"], False, ["biceps"], 300, 280),
        ("Squat", squat, demos.DEMOS["back-squat"].views[0], EXPORTED["back-squat"]["views"][0]["box"], False, ["quads", "glutes"], 300, 280),
    ]
    rows = []
    for name, st in STYLES.items():
        panels = []
        for i, (label, scene, view, box, close, active, W, H) in enumerate(shots):
            svg = render(scene, view, box, close, active, st, W, H, f"{name[:2]}{i}".replace(" ", ""))
            panels.append(f'<div class="pn">{svg}<div class="lb">{label}</div></div>')
        rows.append(f'<div class="card"><div class="t">{name}</div><div class="p">{"".join(panels)}</div></div>')
    html = ('<html><head><meta charset="utf-8"><style>body{background:#0B0C0F;color:#EEE;font-family:-apple-system,Helvetica,sans-serif;'
            'margin:18px;width:1640px}.card{margin:10px 0;padding:12px;background:#1A1C21;border-radius:18px}.t{font-size:19px;margin:0 0 8px 4px}'
            '.p{display:flex;flex-wrap:wrap;gap:8px;align-items:flex-end}.lb{font-size:12px;opacity:.6;text-align:center;margin-top:3px}</style></head><body>'
            '<div style="font-size:26px;font-weight:700;margin:4px 4px 10px">Ardane · mannequin sculpté, muscles attachés à leurs os</div>'
            + "".join(rows) + "</body></html>")
    out = Path(__file__).parent / "out" / "sculpt.html"
    out.write_text(html, encoding="utf-8")
    print(out)
