"""Second sheet of 20 character styles (CEO, 2026-11-23: « avec des détails, muscles plus réalistes tout en laissant
ingenré »). A detailed, gender-neutral body built on the engine's skeleton (same poses as the app): tapered limbs, a
V-shaped trunk, and 20 muscles drawn as shapes (pecs, abs, obliques, traps, lats, lower back, deltoids, biceps, triceps,
forearms, glutes, quads, hamstrings, calves); the muscles worked in red, the others in a quiet tone. Review sheet only.

    ~/ardane-tools/venv/Scripts/python.exe scripts/demos/anatomy_styles.py   # writes out/anatomy_styles.html
"""
import json
import math
from pathlib import Path

import numpy as np

import demos
import ex_arms  # noqa: F401  (registers db-curl)
import ex_legs  # noqa: F401  (registers back-squat)
import anatomy
from engine import BACK, FRONT, lerp, unit

ROOT = Path(__file__).resolve().parents[2]
EXPORTED = json.loads((ROOT / "App" / "Resources" / "ExerciseDemos.json").read_text(encoding="utf-8"))["demos"]


# --- The body as shapes ------------------------------------------------------------------------------

class Canvas:
    def __init__(self, view, box, W, H, close, margin=8):
        self.view = view
        minx, miny, maxx, maxy = box
        self.scale = min((W - 2 * margin) / (maxx - minx), (H - 2 * margin) / (maxy - miny))
        if not close:
            self.scale = min(self.scale, (H - 2 * margin) / 1.75)
        self.cx, self.cy, self.W, self.H = (minx + maxx) / 2, (miny + maxy) / 2, W, H
        R, U, B = view.basis()
        self.toward = B   # points toward the camera

    def p(self, pt):
        x, y, z = self.view.project(np.array([pt]))[0]
        return (self.W / 2 + (x - self.cx) * self.scale, self.H / 2 - (y - self.cy) * self.scale, z)


def limb(cv, a, b, wa, wb):
    """A tapered capsule from a to b (widths in metres), as an SVG path: both ends rounded, drawn point by point."""
    (x0, y0, z0), (x1, y1, z1) = cv.p(a), cv.p(b)
    ra, rb = wa * cv.scale / 2, wb * cv.scale / 2
    ang = math.atan2(y1 - y0, x1 - x0)
    pts = []
    for k in range(13):   # around b, from one side to the other through the far end
        t = ang - math.pi / 2 + math.pi * k / 12
        pts.append((x1 + rb * math.cos(t), y1 + rb * math.sin(t)))
    for k in range(13):   # around a, back through the near end
        t = ang + math.pi / 2 + math.pi * k / 12
        pts.append((x0 + ra * math.cos(t), y0 + ra * math.sin(t)))
    d = "M" + " L".join(f"{x:.1f},{y:.1f}" for x, y in pts) + " Z"
    return d, (z0 + z1) / 2


def smooth(points, close=True):
    """A closed smooth path through screen points (Catmull-Rom as Béziers)."""
    P = points
    n = len(P)
    d = f"M{P[0][0]:.1f},{P[0][1]:.1f} "
    for i in range(n if close else n - 1):
        p0, p1, p2, p3 = P[(i - 1) % n], P[i], P[(i + 1) % n], P[(i + 2) % n]
        c1 = (p1[0] + (p2[0] - p0[0]) / 6, p1[1] + (p2[1] - p0[1]) / 6)
        c2 = (p2[0] - (p3[0] - p1[0]) / 6, p2[1] - (p3[1] - p1[1]) / 6)
        d += f"C{c1[0]:.1f},{c1[1]:.1f} {c2[0]:.1f},{c2[1]:.1f} {p2[0]:.1f},{p2[1]:.1f} "
    return d + ("Z" if close else "")


def belly(cv, a, b, normal, width, lift=0.03, fat=0.5):
    """A muscle belly along a→b (3-D): a spindle built on screen (its width narrows as it turns away from the camera),
    fattest at `fat` of its length. `lift` (toward `normal`) only orders it above the skin; it moves it a quarter of that."""
    n = unit(normal)
    a, b = np.asarray(a) + n * lift * 0.25, np.asarray(b) + n * lift * 0.25
    A, Bp = cv.p(a), cv.p(b)
    facing = float(np.dot(n, cv.toward))
    w = width * 1.2 * cv.scale * max(0.45, abs(facing) ** 0.5)   # a fifth fuller: the portions fill the limb
    dx, dy = Bp[0] - A[0], Bp[1] - A[1]
    length = math.hypot(dx, dy) or 1e-6
    px, py = -dy / length, dx / length
    k = math.log(0.5) / math.log(min(max(fat, 0.1), 0.9))
    left, right = [], []
    for i in range(1, 12):
        t = i / 12
        h = w / 2 * math.sin(math.pi * t ** k) ** 0.8
        x, y = A[0] + dx * t, A[1] + dy * t
        left.append((x + px * h, y + py * h))
        right.append((x - px * h, y - py * h))
    pts = [A[:2]] + left + [Bp[:2]] + right[::-1]
    depth = cv.p(lerp(a, b, fat) + n * lift)[2]
    return smooth(pts), depth - 0.02, facing


def panel(cv, pts3, normal, lift=0.03):
    n = unit(normal)
    P = [cv.p(np.asarray(q) + n * lift) for q in pts3]
    return smooth([q[:2] for q in P]), float(np.mean([q[2] for q in P])) - 0.02, float(np.dot(n, cv.toward))


def body_shapes(cv, body, active):
    """Skin shapes and muscle portions of a body, each (d, depth, kind, name). Every portion is its own shape (CEO,
    2026-11-23: « il faut voir chaque portion »): the three heads of the deltoid and of the triceps, the two of the biceps,
    the quadriceps' parts, the back's layers… A portion is red when its muscle group is worked."""
    c, p = body.chest, body.pelvis
    out = []
    # --- Skin: trunk, neck, head, limbs ---------------------------------------------------------
    sides = []
    for s in (1, -1):
        sides.append([p.at(u=-0.05, r=0.125 * s), p.at(u=0.10, r=0.125 * s), c.at(u=0.08, r=0.125 * s),
                      c.at(u=0.22, r=0.16 * s), body.shoulder[s] + c.u * 0.03 + c.r * s * 0.01,
                      body.neck - c.u * 0.03 + c.r * s * 0.05])
    trunk = sides[0] + sides[1][::-1]
    P = [cv.p(q) for q in trunk]
    out.append((smooth([q[:2] for q in P]), float(np.mean([q[2] for q in P])), "skin", "trunk"))
    d, z = limb(cv, body.neck - c.u * 0.03, body.head - body.head_frame.u * 0.06, 0.09, 0.078)
    out.append((d, z + 0.005, "skin", "neck"))
    hx, hy, hz = cv.p(body.head)
    r = 0.098 * cv.scale
    out.append((f"M{hx - r:.1f},{hy:.1f} a{r:.1f},{r * 1.12:.1f} 0 1 0 {2 * r:.1f},0 a{r:.1f},{r * 1.12:.1f} 0 1 0 {-2 * r:.1f},0 Z", hz - 0.01, "skin", "head"))
    muscles = []   # (group, (d, z, facing))

    def m(group, shape):
        muscles.append((group, shape))

    # Neck: sternocleidomastoid.
    for s in (1, -1):
        m("traps", belly(cv, body.head - body.head_frame.u * 0.05 + c.r * s * 0.045, c.at(u=0.37, r=0.018 * s),
                         c.f, 0.03, lift=0.04, fat=0.5))
    for s in (1, -1):
        if s in body.elbow:
            sh, el, gr = body.shoulder[s], body.elbow[s], body.grip[s]
            for a, b, wa, wb, name in ((sh, el, 0.10, 0.072, "upperarm"), (el, gr, 0.078, 0.052, "forearm")):
                d, z = limb(cv, a, b, wa, wb)
                out.append((d, z, "skin", name))
            gx, gy, gz = cv.p(gr)
            rr = 0.036 * cv.scale
            out.append((f"M{gx - rr:.1f},{gy:.1f} a{rr:.1f},{rr:.1f} 0 1 0 {2 * rr:.1f},0 a{rr:.1f},{rr:.1f} 0 1 0 {-2 * rr:.1f},0 Z", gz - 0.005, "skin", "hand"))
            arm, fore = unit(el - sh), unit(gr - el)
            bend = fore - np.dot(fore, arm) * arm
            front = unit(bend) if np.linalg.norm(bend) > 0.08 else (unit(np.cross(c.r, arm)) if np.linalg.norm(np.cross(c.r, arm)) > 0.2 else c.f)
            side_axis = np.cross(arm, front)
            away = unit(side_axis) * (1 if np.dot(side_axis, c.r * s) > 0 else -1)   # away from the body
            # Deltoid: anterior, lateral, posterior heads.
            for normal, w in ((front * 0.8 + away * 0.5, 0.055), (away + c.u * 0.25, 0.06), (-front * 0.8 + away * 0.5, 0.055)):
                m("shoulders", belly(cv, sh - arm * 0.035 + c.u * 0.01, sh + arm * 0.14, normal, w, lift=0.04, fat=0.35))
            # Biceps: long head (outer) and short head (inner); brachialis below on the outer side.
            m("biceps", belly(cv, lerp(sh, el, 0.24) + away * 0.016, lerp(sh, el, 0.86) + away * 0.008, front, 0.036, lift=0.03))
            m("biceps", belly(cv, lerp(sh, el, 0.22) - away * 0.016, lerp(sh, el, 0.88) - away * 0.008, front, 0.036, lift=0.031))
            m("biceps", belly(cv, lerp(sh, el, 0.55) + away * 0.03, lerp(sh, el, 0.97) + away * 0.02, front * 0.4 + away, 0.03, lift=0.028))
            # Triceps: long head (inner), lateral head (outer, upper), medial head (lower).
            m("triceps", belly(cv, lerp(sh, el, 0.12) - away * 0.015, lerp(sh, el, 0.8) - away * 0.01, -front, 0.038, lift=0.03))
            m("triceps", belly(cv, lerp(sh, el, 0.2) + away * 0.02, lerp(sh, el, 0.7) + away * 0.012, -front * 0.7 + away * 0.5, 0.036, lift=0.032))
            m("triceps", belly(cv, lerp(sh, el, 0.62), lerp(sh, el, 0.95), -front, 0.04, lift=0.029, fat=0.4))
            # Forearm: brachioradialis (outer, upper), flexors (front), extensors (back).
            m("forearms", belly(cv, lerp(sh, el, 0.8) + away * 0.02, lerp(el, gr, 0.55) + away * 0.01, front * 0.5 + away, 0.032, lift=0.026, fat=0.3))
            m("forearms", belly(cv, lerp(el, gr, 0.05) - away * 0.01, lerp(el, gr, 0.75) - away * 0.005, front, 0.036, lift=0.024, fat=0.3))
            m("forearms", belly(cv, lerp(el, gr, 0.05), lerp(el, gr, 0.75), -front, 0.034, lift=0.024, fat=0.3))
        if s in body.knee:
            hip, kn, an = body.hip[s], body.knee[s], body.ankle[s]
            for a, b, wa, wb, name in ((hip, kn, 0.155, 0.098, "thigh"), (kn, an, 0.104, 0.062, "shin")):
                d, z = limb(cv, a, b, wa, wb)
                out.append((d, z, "skin", name))
            if s in body.toe:
                d, z = limb(cv, an, body.toe[s], 0.065, 0.045)
                out.append((d, z, "skin", "foot"))
            thigh, shin = unit(kn - hip), unit(an - kn)
            tf, sf = unit(np.cross(p.r, thigh)), unit(np.cross(p.r, shin))
            lat = p.r * s   # outward

            def L(t, hip=hip, kn=kn):
                return lerp(hip, kn, t)

            def Sh(t, kn=kn, an=an):
                return lerp(kn, an, t)

            # Quadriceps: rectus femoris (middle), vastus lateralis (outer), vastus medialis (inner teardrop).
            m("quads", belly(cv, L(0.1), L(0.88), tf, 0.052, lift=0.05, fat=0.45))
            m("quads", belly(cv, L(0.18) + lat * 0.035, L(0.92) + lat * 0.03, tf * 0.6 + lat * 0.8, 0.055, lift=0.045, fat=0.5))
            m("quads", belly(cv, L(0.6) - lat * 0.03, L(0.97) - lat * 0.02, tf * 0.7 - lat * 0.7, 0.05, lift=0.046, fat=0.62))
            # Sartorius (thin diagonal), adductors (inner upper), tensor fasciae latae (outer upper).
            m("quads", belly(cv, L(0.02) + lat * 0.05, L(0.85) - lat * 0.04, tf * 0.7 - lat * 0.4, 0.018, lift=0.055, fat=0.5))
            m("glutes", belly(cv, L(0.05) - lat * 0.04, L(0.55) - lat * 0.035, tf * 0.3 - lat, 0.045, lift=0.04, fat=0.35))
            m("glutes", belly(cv, hip + p.u * 0.05 + lat * 0.06, L(0.3) + lat * 0.05, lat + tf * 0.3, 0.04, lift=0.045, fat=0.4))
            # Hamstrings: biceps femoris (outer), semitendinosus (inner).
            m("hamstrings", belly(cv, L(0.12) + lat * 0.02, L(0.9) + lat * 0.03, -tf, 0.05, lift=0.045))
            m("hamstrings", belly(cv, L(0.12) - lat * 0.02, L(0.92) - lat * 0.03, -tf, 0.048, lift=0.046))
            # Calf: gastrocnemius medial and lateral heads, soleus below; tibialis anterior in front.
            m("calves", belly(cv, Sh(0.04) - lat * 0.018, Sh(0.55) - lat * 0.01, -sf, 0.042, lift=0.04, fat=0.33))
            m("calves", belly(cv, Sh(0.04) + lat * 0.018, Sh(0.5) + lat * 0.01, -sf, 0.038, lift=0.041, fat=0.33))
            m("calves", belly(cv, Sh(0.4), Sh(0.85), -sf, 0.05, lift=0.036, fat=0.4))
            m("calves", belly(cv, Sh(0.08) + lat * 0.02, Sh(0.7) + lat * 0.015, sf * 0.8 + lat * 0.3, 0.03, lift=0.03, fat=0.35))
            # Glutes: gluteus medius (upper outer), gluteus maximus.
            m("glutes", belly(cv, hip + p.u * 0.11 + lat * 0.02, hip + p.u * 0.02 + lat * 0.075, -p.f * 0.6 + lat * 0.6, 0.075, lift=0.06))
            m("glutes", belly(cv, hip + p.u * 0.07 - lat * 0.03, hip - p.u * 0.1 + lat * 0.02, -p.f, 0.13, lift=0.075))
    # --- Trunk ---------------------------------------------------------------------------------
    for s in (1, -1):
        def R(u, r, s=s):
            return c.at(u=u, r=r * s)

        # Pectoralis major: clavicular (upper) and sternal (lower) parts.
        m("chest", panel(cv, [R(0.35, 0.02), R(0.36, 0.15), R(0.32, 0.158), R(0.30, 0.02)], c.f, lift=0.05))
        m("chest", panel(cv, [R(0.295, 0.02), R(0.315, 0.158), R(0.265, 0.155), R(0.205, 0.10), R(0.195, 0.02)], c.f, lift=0.051))
        # Serratus anterior: three fingers under the armpit.
        for k, u in enumerate((0.215, 0.18, 0.145)):
            m("abs", panel(cv, [R(u + 0.014, 0.155 - k * 0.006), R(u + 0.012, 0.118), R(u - 0.012, 0.12), R(u - 0.014, 0.15 - k * 0.006)],
                           c.f * 0.6 + c.r * s * 0.6, lift=0.052))
        # External oblique.
        m("abs", panel(cv, [R(0.125, 0.128), R(0.12, 0.085), p.at(u=0.07, r=0.075 * s), p.at(u=0.0, r=0.10 * s), p.at(u=0.06, r=0.122 * s)],
                       c.f * 0.6 + c.r * s * 0.6, lift=0.05))
        # Rectus abdominis: four rows each side (the lowest one longer).
        for u, h in ((0.155, 0.026), (0.097, 0.026), (0.04, 0.026), (-0.03, 0.036)):
            m("abs", panel(cv, [R(u + h, 0.008), R(u + h, 0.05), R(u - h, 0.046), R(u - h, 0.008)], c.f, lift=0.055))
        # Back, deep to superficial: erector spinae, rhomboids, infraspinatus, teres major, latissimus, trapezius in 3 parts.
        m("lowerBack", panel(cv, [R(0.22, 0.012), R(0.22, 0.04), p.at(u=0.02, r=0.05 * s), p.at(u=0.02, r=0.012 * s)], -c.f, lift=0.05))
        m("back", panel(cv, [R(0.31, 0.02), R(0.3, 0.075), R(0.2, 0.075), R(0.21, 0.02)], -c.f, lift=0.051))
        m("back", panel(cv, [R(0.30, 0.08), R(0.305, 0.14), R(0.235, 0.135), R(0.225, 0.085)], -c.f, lift=0.052))
        m("back", panel(cv, [R(0.235, 0.137), R(0.245, 0.158), R(0.205, 0.158), R(0.205, 0.13)], -c.f, lift=0.052))
        m("back", panel(cv, [R(0.2, 0.08), R(0.205, 0.158), R(0.09, 0.13), R(0.0, 0.07), R(0.03, 0.03), R(0.15, 0.03)], -c.f, lift=0.053))
        m("traps", panel(cv, [body.neck + c.r * s * 0.02, body.shoulder[s] + c.u * 0.03, R(0.33, 0.1), R(0.32, 0.02)],
                         -c.f * 0.7 + c.u * 0.3, lift=0.056))
        m("traps", panel(cv, [R(0.32, 0.015), R(0.325, 0.11), R(0.295, 0.105), R(0.27, 0.015)], -c.f, lift=0.057))
        m("traps", panel(cv, [R(0.27, 0.015), R(0.29, 0.085), R(0.19, 0.012)], -c.f, lift=0.057))
    shapes = list(out)
    for group, (d, z, facing) in muscles:
        if facing < -0.12:
            continue
        shapes.append((d, z, "active" if group in active else "muscle", group))
    return shapes


def gear_shapes(cv, scene):
    out = []
    for pr in scene.prims:
        if pr.role in ("ink", "muscle", "muscle2"):
            continue
        P = [cv.p(q) for q in pr.pts]
        z = float(np.mean([q[2] for q in P])) + pr.bias
        w = pr.width * cv.scale
        if pr.kind == 0:
            d = " ".join(("M" if i == 0 else "L") + f"{x:.1f},{y:.1f}" for i, (x, y, _) in enumerate(P))
            out.append((d, z, "gear-line" if pr.role != "floor" else "floor", w))
        elif pr.kind == 1:
            d = " ".join(("M" if i == 0 else "L") + f"{x:.1f},{y:.1f}" for i, (x, y, _) in enumerate(P)) + " Z"
            out.append((d, z, "floor" if pr.role == "floor" else "gear-fill", w))
        else:
            x, y, _ = P[0]
            out.append((f"M{x - w:.1f},{y:.1f} a{w:.1f},{w:.1f} 0 1 0 {2 * w:.1f},0 a{w:.1f},{w:.1f} 0 1 0 {-2 * w:.1f},0 Z",
                        z, "gear-disc", w))
    return out


# --- 20 treatments --------------------------------------------------------------------------------

def S(bg, skin, muscle, active, line="none", lw=0.0, gear="#6E7480", floor="#22252B", **kw):
    return dict(bg=bg, skin=skin, muscle=muscle, active=active, line=line, lw=lw, gear=gear, floor=floor, **kw)


STYLES = [
    ("Sculpté clair", S("#14161A", "#ECEDF0", "#D9DBE0", "#FF4D55", line="#BFC3CA", lw=0.8)),
    ("Sculpté graphite", S("#0E0F12", "#3A3E46", "#4A4F58", "#FF4D55", line="#5C626C", lw=0.8)),
    ("Écorché", S("#141113", "#E9D6CC", "#C98E83", "#E3262F", line="#9C5D55", lw=0.6, fibers="#B0716A")),
    ("Planche médicale", S("#F4EEE2", "#F4EEE2", "#EBDDCB", "#D2353B", line="#6B4E3A", lw=1.1, gear="#A39886", floor="#E8DFCF")),
    ("Marbre", S("#121317", "url(#marble)", "url(#marble2)", "#FF4D55", line="#A9ADB5", lw=0.6)),
    ("Argile", S("#17120F", "#C57B57", "#B86E4B", "#FFD23F", line="#8E4E33", lw=0.7, shade=True)),
    ("Bronze", S("#0F0D0A", "url(#bronze)", "url(#bronze2)", "#FF4D55", line="#6E4B1F", lw=0.7)),
    ("Contours fins", S("#111216", "none", "none", "#FF4D55", line="#E6E8EC", lw=1.0)),
    ("Topographique", S("#0F1115", "#1B1E24", "#1B1E24", "#FF4D55", line="#8C93A0", lw=0.7, topo=True)),
    ("Fibres", S("#121418", "#DDE0E5", "#C9CDD4", "#FF4D55", line="#A2A8B2", lw=0.5, fibers="#9DA3AD", fibers_active="#B3202A")),
    ("Néon anatomique", S("#04050A", "#0B1220", "#0B1220", "#FF2E8A", line="#46E0FF", lw=1.1, glow=True)),
    ("Bleu technique", S("#0E2846", "#123257", "#123257", "#FF7A6E", line="#D8E7FF", lw=0.9, grid=True, gear="#7FA4D6", floor="#163A63")),
    ("Rayons X", S("#04060A", "#5E86AA55", "#7FA7C955", "#FF3D5E", line="#BFD8FF", lw=0.6, glow_active=True)),
    ("Bicolore", S("#0D1B2A", "#335C85", "#3D6A96", "#FFB547", line="#21415F", lw=0.8, gear="#2C4F72", floor="#122437")),
    ("Pastel", S("#F7F2FB", "#D9D3EC", "#CBC3E3", "#FF8FA3", line="#B4ABD3", lw=0.8, gear="#C8C1DE", floor="#EEE7F5")),
    ("Monochrome rouge", S("#160A0C", "#4A1E24", "#5C252C", "#FF3B47", line="#7A3139", lw=0.7)),
    ("Mannequin segmenté", S("#121317", "#D7DAE0", "#C4C8D0", "#FF4D55", line="#121317", lw=1.8)),
    ("Facettes", S("#13151A", "#D3D7DE", "#BFC4CC", "#FF4D55", line="#13151A", lw=0.6, facets=True)),
    ("Carte de chaleur", S("#0C0D10", "#2B2F37", "#343944", "url(#heat)", line="#454B56", lw=0.6, glow_active=True)),
    ("Graphite croquis", S("#F3F1EC", "#F3F1EC", "#E6E2DA", "#D8433F", line="#3A3A3A", lw=1.0, sketch=True, gear="#8C8C8C", floor="#E4E0D7")),
]

DEFS = ('<defs>'
        '<linearGradient id="marble" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#F7F7F8"/><stop offset="1" stop-color="#B9BCC3"/></linearGradient>'
        '<linearGradient id="marble2" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#E9EAED"/><stop offset="1" stop-color="#A6AAB2"/></linearGradient>'
        '<linearGradient id="bronze" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#E2B66E"/><stop offset="1" stop-color="#7A4F1C"/></linearGradient>'
        '<linearGradient id="bronze2" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#D3A45E"/><stop offset="1" stop-color="#6A4316"/></linearGradient>'
        '<radialGradient id="heat"><stop offset="0" stop-color="#FFF36B"/><stop offset="0.45" stop-color="#FF8A2A"/><stop offset="1" stop-color="#E5202E"/></radialGradient>'
        '<filter id="glow" x="-50%" y="-50%" width="200%" height="200%"><feGaussianBlur stdDeviation="2.2" result="b"/><feMerge><feMergeNode in="b"/><feMergeNode in="SourceGraphic"/></feMerge></filter>'
        '<filter id="shade"><feDropShadow dx="0.8" dy="1.4" stdDeviation="1" flood-color="#000" flood-opacity="0.45"/></filter>'
        '<filter id="sketch"><feTurbulence type="fractalNoise" baseFrequency="0.8" numOctaves="1" result="t"/><feDisplacementMap in="SourceGraphic" in2="t" scale="1.8"/></filter>'
        '</defs>')


def draw(shapes, gear, st, W, H, uid):
    out = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" viewBox="0 0 {W} {H}">{DEFS}'
           f'<rect width="{W}" height="{H}" rx="12" fill="{st["bg"]}"/>']
    if st.get("grid"):
        out += [f'<path d="M{x},0V{H}" stroke="#1C4672" stroke-width="0.5"/>' for x in range(0, W, 10)]
        out += [f'<path d="M0,{y}H{W}" stroke="#1C4672" stroke-width="0.5"/>' for y in range(0, H, 10)]
    items = [(z, 0, d, kind, w) for d, z, kind, w in gear] + [(z, 1, d, kind, name) for d, z, kind, name in shapes]
    items.sort(key=lambda it: -it[0])
    body_filter = ' filter="url(#sketch)"' if st.get("sketch") else (' filter="url(#shade)"' if st.get("shade") else "")
    for z, is_body, d, kind, extra in items:
        if not is_body:
            if kind == "floor":
                out.append(f'<path d="{d}" fill="{st["floor"]}"/>')
            elif kind == "gear-line":
                out.append(f'<path d="{d}" fill="none" stroke="{st["gear"]}" stroke-width="{extra:.1f}" stroke-linecap="round"/>')
            elif kind == "gear-fill":
                out.append(f'<path d="{d}" fill="{st["gear"]}"/>')
            else:
                out.append(f'<path d="{d}" fill="{st["gear"]}" fill-opacity="0.45" stroke="{st["gear"]}" stroke-width="1.4"/>')
            continue
        fill = st["skin"] if kind == "skin" else st["muscle"] if kind == "muscle" else st["active"]
        line = st["line"]
        lw = st["lw"]
        if kind == "active" and st["line"] != "none" and not st.get("topo"):
            line = "#7A0E14" if fill.startswith("#F") and not st.get("glow") else line
        attrs = f'fill="{fill}" stroke="{line}" stroke-width="{lw}" stroke-linejoin="round"'
        if fill == "none":
            attrs = f'fill="none" stroke="{line}" stroke-width="{lw}" stroke-linejoin="round"'
        filt = ""
        if st.get("glow") and kind != "skin":
            filt = ' filter="url(#glow)"'
        if st.get("glow_active") and kind == "active":
            filt = ' filter="url(#glow)"'
        if kind == "active" and fill == "none":
            attrs = f'fill="#FF4D55" stroke="{line}" stroke-width="{lw}"'
        out.append(f'<path d="{d}" {attrs}{filt}{body_filter}/>')
        if st.get("topo") and kind != "skin":
            col = "#FF4D55" if kind == "active" else st["line"]
            out.append(f'<path d="{d}" fill="none" stroke="{col}" stroke-width="0.6" transform-origin="center" opacity="0.9"/>')
        if st.get("fibers") and kind != "skin":
            col = st.get("fibers_active", "#B3202A") if kind == "active" else st["fibers"]
            out.append(f'<clipPath id="c{uid}{len(out)}"><path d="{d}"/></clipPath>'
                       f'<g clip-path="url(#c{uid}{len(out)})" opacity="0.55">'
                       + "".join(f'<path d="M{x},{0} l{-H * 0.35:.0f},{H}" stroke="{col}" stroke-width="0.6"/>' for x in range(0, W + H, 3))
                       + '</g>')
        if st.get("facets") and kind != "skin":
            out.append(f'<path d="{d}" fill="#000" fill-opacity="0.08" transform="scale(1)" clip-path="none"/>')
    out.append("</svg>")
    return "".join(out)


# --- Poses -----------------------------------------------------------------------------------------

def pose(ident, p, active, box=None, view=None, close=False):
    d = demos.DEMOS[ident]
    scene = d.scene(p)
    v = view or d.views[0]
    if box is None:
        box = EXPORTED[ident]["views"][0]["box"] if ident in EXPORTED else [-0.5, -0.05, 0.7, 1.8]
    return scene, v, box, close, set(active)


def detail_sheet():
    """Sheet 3: the muscle portions, big, in 6 of the styles (CEO, 2026-11-23: « il faut voir chaque portion »)."""
    for group, (muscles, view, margin) in anatomy.GROUPS.items():
        if f"anatomy-{group}" not in demos.DEMOS:
            anatomy.register(group, muscles, view)
    full = [-0.55, -0.06, 0.55, 1.86]
    box = lambda g: EXPORTED[f"anatomy-{g}"]["views"][0]["box"]
    poses = [
        ("Face", pose("anatomy-quads", 0.25, ["chest", "biceps"], box=full, view=FRONT(4)), 230, 330),
        ("Dos", pose("anatomy-back", 0.25, ["back", "hamstrings"], box=full, view=BACK(4)), 230, 330),
        ("Cuisse · quadriceps", pose("anatomy-quads", 0.25, ["quads"], box=box("quads"), view=FRONT(4), close=True), 280, 240),
        ("Bras · biceps", pose("anatomy-biceps", 0.25, ["biceps", "shoulders"], box=box("biceps"), view=FRONT(4), close=True), 280, 240),
        ("Dos · dorsaux et trapèzes", pose("anatomy-back", 0.25, ["back", "traps"], box=box("back"), view=BACK(4), close=True), 280, 240),
    ]
    keep = [1, 4, 3, 8, 17, 11]
    cards = []
    for i in keep:
        name, st = STYLES[i - 1]
        panels = []
        for k, (label, (scene, v, bx, close, active), W, H) in enumerate(poses):
            cv = Canvas(v, bx, W, H, close)
            svg = draw(body_shapes(cv, scene.body, active), gear_shapes(cv, scene), st, W, H, f"d{i}p{k}")
            panels.append(f'<div class="pn">{svg}<div class="lb">{label}</div></div>')
        cards.append(f'<div class="card"><div class="t"><b>{i:02d}</b> {name}</div><div class="p">{"".join(panels)}</div></div>')
    html = ('<html><head><meta charset="utf-8"><style>body{background:#0B0C0F;color:#EEE;font-family:-apple-system,Helvetica,sans-serif;'
            'margin:18px;width:1440px}.card{margin:10px 0;padding:12px;background:#1A1C21;border-radius:18px}'
            '.t{font-size:18px;margin:0 0 8px 4px}.t b{color:#FF6369;margin-right:6px}.p{display:flex;gap:8px;align-items:flex-end}'
            '.lb{font-size:12px;opacity:.6;text-align:center;margin-top:3px}</style></head><body>'
            '<div style="font-size:26px;font-weight:700;margin:4px 4px 6px">Ardane · chaque portion de muscle</div>'
            '<div style="font-size:14px;opacity:.7;margin:0 4px 10px">Deltoïde 3 faisceaux · biceps 2 chefs + brachial · triceps 3 chefs · avant-bras 3 · '
            'pectoraux claviculaire et sternal · dentelé · grand droit 8 blocs · obliques · trapèze 3 parties · rhomboïdes · infra-épineux · grand rond · '
            'grand dorsal · érecteurs · moyen et grand fessier · droit fémoral, vastes latéral et médial, sartorius, adducteurs, TFL · '
            'biceps fémoral, semi-tendineux · gastrocnémien 2 chefs, soléaire, tibial antérieur · sterno-cléido-mastoïdien</div>'
            + "".join(cards) + "</body></html>")
    out = Path(__file__).parent / "out" / "anatomy_detail.html"
    out.write_text(html, encoding="utf-8")
    print(out)


if __name__ == "__main__":
    import sys
    if "--detail" in sys.argv:
        detail_sheet()
        raise SystemExit
    for group, (muscles, view, margin) in anatomy.GROUPS.items():
        if f"anatomy-{group}" not in demos.DEMOS:
            anatomy.register(group, muscles, view)
    poses = [
        pose("db-curl", 0.55, ["biceps", "forearms"]),
        pose("anatomy-chest", 0.25, ["chest"], box=EXPORTED["anatomy-chest"]["views"][0]["box"], view=FRONT(4), close=True),
        pose("anatomy-back", 0.25, ["back", "traps"], box=EXPORTED["anatomy-back"]["views"][0]["box"], view=BACK(4), close=True),
        pose("back-squat", 0.5, ["quads", "glutes"]),
    ]
    W, H = 150, 132
    cards = []
    for i, (name, st) in enumerate(STYLES, 1):
        panels = []
        for k, (scene, v, box, close, active) in enumerate(poses):
            cv = Canvas(v, box, W, H, close)
            panels.append(draw(body_shapes(cv, scene.body, active), gear_shapes(cv, scene), st, W, H, f"s{i}p{k}"))
        cards.append(f'<div class="card"><div class="t"><b>{i:02d}</b> {name}</div><div class="p">{"".join(panels)}</div></div>')
    html = ('<html><head><meta charset="utf-8"><style>body{background:#0B0C0F;color:#EEE;font-family:-apple-system,Helvetica,sans-serif;'
            'margin:18px;width:2060px}.card{display:inline-block;margin:7px;padding:11px;background:#1A1C21;border-radius:18px;vertical-align:top}'
            '.t{font-size:17px;margin:0 0 8px 4px}.t b{color:#FF6369;margin-right:6px}.p{display:flex;gap:7px}</style></head><body>'
            '<div style="font-size:26px;font-weight:700;margin:4px 10px 10px">Ardane · 20 styles détaillés, muscles réalistes, corps neutre</div>'
            + "".join(cards) + "</body></html>")
    out = Path(__file__).parent / "out" / "anatomy_styles.html"
    out.write_text(html, encoding="utf-8")
    print(out)
