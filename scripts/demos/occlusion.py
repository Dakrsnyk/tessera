"""Draw-order errors between the sculpted mannequin and the equipment, in every demonstration (2026-11-24).

    python3 scripts/demos/occlusion.py [ids…] [--min 15] [--mode app|old] [--cell 0.1] [--lift 0.6] [--png]

The app has no depth buffer: it paints the pieces of the body and of the equipment from the farthest to the nearest
(ExerciseDemo.swift, SculptMannequin.swift). A big piece sorted by its middle can land on the wrong side of what it
touches: a backrest painted over the shoulders lying on it looks like the body going through the bench, although
nothing collides (collisions.py measures the real volumes).

This tool paints every view of every demonstration twice at a small size: as the app does (`--mode app`: the body in
slices, pads and bars cut in cells of `--cell` metres; `--mode old`: whole pieces, as before 2026-11-24) and with
everything cut very fine, which is the truth. `--lift`: the share of its radius by which a volume is sorted nearer
than its axis (`Sculpt.lift` in the app). It prints, per demonstration, the worst area (cm² of the scene) where
the body and the equipment are painted in the wrong order. `--png` writes out/occlusion-<id>.png (app | truth | errors).
"""
import glob
import importlib
import math
import multiprocessing
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import demos  # noqa: E402
from engine import KIND_BALL, KIND_DISC, KIND_LINE, KIND_POLY, FLAG_CULL, lerp, unit  # noqa: E402
import sculpt  # noqa: E402

for path in sorted(glob.glob(str(HERE / "ex_*.py"))):
    importlib.import_module(Path(path).stem)

BODY_ROLES = {"ink", "muscle", "muscle2"}
BACKDROP = {"floor", "mark"}      # never cut: they lie under everything
FINE = 0.025                      # the truth: cells of 2.5 cm
SIZE = 520                        # pixels across the scene: a 28 mm bar is 5 pixels wide or more
ANGLES = range(0, 360, 15)


class Cam:
    def __init__(self, view, pts):
        self.view = view
        P = view.project(np.array(pts))
        lo, hi = P[:, :2].min(axis=0) - 0.08, P[:, :2].max(axis=0) + 0.08
        self.k = SIZE / max(hi[0] - lo[0], 1e-6)
        self.lo, self.hi = lo, hi
        self.W, self.H = SIZE, int(math.ceil((hi[1] - lo[1]) * self.k))

        self.R, self.U, self.B = view.basis()

    def p(self, q):
        return ((float(np.dot(q, self.R)) - self.lo[0]) * self.k, (self.hi[1] - float(np.dot(q, self.U))) * self.k,
                -float(np.dot(q, self.B)))

    def P(self, pts):
        """Screen x, y and depth of an array of points (…, 3)."""
        pts = np.asarray(pts, dtype=float)
        return np.stack([(pts @ self.R - self.lo[0]) * self.k, (self.hi[1] - pts @ self.U) * self.k, -(pts @ self.B)], axis=-1)


# --- The body, as SculptMannequin.swift builds it ------------------------------------------------------------------

def body_items(cam, b, mode, lift=0.0):
    """[(depth, group, kind, shape)] — kind "poly" (screen points) or "circle" (x, y, r). `mode`: "sliced", one piece per
    pair of sections, `lift` metres nearer than its middle (the app since 2026-11-24); "whole", one piece per part at the
    mean depth of its sections (before); "truth", the facets of the surface, each at its own depth."""
    body = sculpt.Body(b)
    c = b.chest
    out = []

    def sweep(group, rings, bias=0.0):
        R3 = np.array(rings)
        S = cam.P(R3)                                    # sections × angles × (x, y, depth)
        radii = np.linalg.norm(R3[:, 0] - R3[:, R3.shape[1] // 2], axis=1) / 2     # front to back, halved
        if mode == "truth":
            n = S.shape[1]
            for k in range(S.shape[0] - 1):
                for a in range(n):
                    q = np.array([S[k, a], S[k, (a + 1) % n], S[k + 1, (a + 1) % n], S[k + 1, a]])
                    out.append((float(q[:, 2].mean()), group, "poly", q[:, :2]))
            return
        pieces = []
        for k in range(S.shape[0] - 1):
            P = np.concatenate([S[k], S[k + 1]])
            radius = (radii[k] + radii[k + 1]) / 2
            pieces.append((float(P[:, 2].mean()) + bias - lift * radius, sculpt.hull([tuple(q) for q in P[:, :2]])))
        if mode == "whole":
            z = float(np.mean([z for z, _ in pieces]))
            pieces = [(z, h) for _, h in pieces]
        out.extend((z, group, "poly", h) for z, h in pieces if len(h) >= 3)

    def ellipsoid(group, center, axes, bias=0.0):
        pts = []
        for i in range(1, 9):
            th = math.pi * i / 9
            for j in range(14):
                ph = 2 * math.pi * j / 14
                pts.append(cam.p(center + axes[0] * math.cos(th) + axes[1] * math.sin(th) * math.cos(ph)
                                 + axes[2] * math.sin(th) * math.sin(ph))[:2])
        pts += [cam.p(center + axes[0])[:2], cam.p(center - axes[0])[:2]]
        near = (0.7 if mode == "truth" else lift) * min(float(np.linalg.norm(a)) for a in axes)
        out.append((cam.p(center)[2] + (0.0 if mode == "truth" else bias) - near, group, "poly", sculpt.hull(pts)))

    def ball(group, center, r):
        x, y, z = cam.p(center)
        out.append((z - (0.7 if mode == "truth" else lift) * r, group, "circle", (x, y, r * cam.k)))

    lo, hi = sculpt.TRUNK[0][0], sculpt.TRUNK[-1][0]
    us = [lo + (hi - lo) * k / 26 for k in range(27)]
    sweep("tronc", [[body.trunk(u, phi) for phi in ANGLES] for u in us])
    nb, nt = b.neck - c.u * 0.04, b.head - b.head_frame.u * 0.07
    sweep("cou", [[lerp(nb, nt, t) + (c.r * math.sin(math.radians(a)) + c.f * math.cos(math.radians(a))) * (0.056 - 0.01 * t)
                   for a in ANGLES] for t in (0, 0.5, 1)])
    hf = b.head_frame
    ellipsoid("tête", b.head + hf.u * 0.012, [hf.u * 0.122, hf.f * 0.098, hf.r * 0.083], -0.01)
    ellipsoid("tête", b.head - hf.u * 0.05 + hf.f * 0.02, [hf.u * 0.06, hf.f * 0.07, hf.r * 0.062], -0.008)
    names = {"arm": "bras", "fore": "avant-bras", "thigh": "cuisse", "shin": "tibia"}
    for (kind, s), (a, e, front, away, prof) in body.limbs.items():
        t0, t1 = prof[0][0], prof[-1][0]
        ts = [t0 + (t1 - t0) * k / 12 for k in range(13)]
        sweep(f"{names[kind]} {'droit' if s == 1 else 'gauche'}", [[body.limb((kind, s), t, th) for th in ANGLES] for t in ts])
    for s in (1, -1):
        tag = "droit" if s == 1 else "gauche"
        if s in b.elbow:
            sh, el, gr = b.shoulder[s], b.elbow[s], b.grip[s]
            for center, r, name in ((sh + unit(el - sh) * 0.03, 0.05, "épaule"), (el, 0.041, "coude"),
                                    (gr - unit(gr - el) * 0.02, 0.028, "poignet")):
                ball(f"{name} {tag}", center, r)
            _, _, ff, fa, _ = body.limbs[("fore", s)]
            d = unit(gr - el)
            ellipsoid(f"main {tag}", gr + d * 0.035, [d * 0.058, fa * 0.034, ff * 0.019])
            ellipsoid(f"main {tag}", gr + d * 0.01 + ff * 0.02 - fa * 0.012, [d * 0.03, ff * 0.012, fa * 0.012], -0.004)
        if s in b.knee and s in b.toe:
            kn, an, to = b.knee[s], b.ankle[s], b.toe[s]
            for center, r, name in ((kn, 0.05, "genou"), (an, 0.033, "cheville")):
                ball(f"{name} {tag}", center, r)
            d = unit(to - an)
            flat = np.array([d[0], 0.0, d[2]])
            level = unit(flat) if np.linalg.norm(flat) > 1e-3 else d
            up, lateral = np.array([0.0, 1.0, 0.0]), b.pelvis.r
            ellipsoid(f"pied {tag}", an - level * 0.035 - up * 0.035, [level * 0.04, up * 0.03, lateral * 0.032])
            ellipsoid(f"pied {tag}", lerp(an, to, 0.55) - up * 0.012, [d * 0.11, up * 0.026, lateral * 0.04])
    return out


# --- The equipment, as ExerciseDemo.swift draws it -----------------------------------------------------------------

def culled(view, pts):
    P = view.project(np.array(pts))
    area = sum(P[k][0] * P[(k + 1) % len(P)][1] - P[(k + 1) % len(P)][0] * P[k][1] for k in range(len(P)))
    return area <= 2e-6


def gear_items(cam, scene, cell, truth=False, lift=0.0):
    """[(depth, group, kind, shape)] — `cell`: polygons and lines are cut in cells of that size (None: whole)."""
    out = []
    for i, pr in enumerate(scene.prims):
        if pr.role in BODY_ROLES:
            continue
        group = f"{pr.role}#{i}"
        bias = 0.0 if truth else pr.bias
        if pr.role in BACKDROP:
            bias += 1000.0      # the floor, the walls and their marks lie behind everything
        size = None if pr.role in BACKDROP else cell
        if pr.kind == KIND_POLY:
            if pr.flags & FLAG_CULL and culled(cam.view, pr.pts):
                continue
            if size and len(pr.pts) == 4:
                a, b, c, d = pr.pts
                top = 400 if truth else 16
                nu = min(top, max(1, math.ceil(max(np.linalg.norm(b - a), np.linalg.norm(c - d)) / size)))
                nv = min(top, max(1, math.ceil(max(np.linalg.norm(d - a), np.linalg.norm(c - b)) / size)))
                u = np.linspace(0, 1, nu + 1)[:, None, None]
                v = np.linspace(0, 1, nv + 1)[None, :, None]
                G = cam.P((a + (b - a) * u) * (1 - v) + (d + (c - d) * u) * v)       # (nu + 1) × (nv + 1) × 3
                for iu in range(nu):
                    for iv in range(nv):
                        q = np.array([G[iu, iv], G[iu + 1, iv], G[iu + 1, iv + 1], G[iu, iv + 1]])
                        out.append((float(q[:, 2].mean()) + bias, group, "poly", q[:, :2]))
            else:
                P = [cam.p(q) for q in pr.pts]
                out.append((float(np.mean([q[2] for q in P])) + bias, group, "poly", [q[:2] for q in P]))
        elif pr.kind == KIND_LINE:
            w = max(pr.width * cam.k, 1.0)
            if pr.role not in BACKDROP:
                bias -= (0.7 if truth else lift) * pr.width / 2
            if size:
                for a, b in zip(pr.pts, pr.pts[1:]):
                    n = min(400 if truth else 24, max(1, math.ceil(np.linalg.norm(b - a) / size)))
                    L = cam.P(a + (b - a) * np.linspace(0, 1, n + 1)[:, None])
                    for k in range(n):
                        out.append((float(L[k, 2] + L[k + 1, 2]) / 2 + bias, group, "line", ([L[k, :2], L[k + 1, :2]], w)))
            else:
                P = [cam.p(q) for q in pr.pts]
                out.append((float(np.mean([q[2] for q in P])) + bias, group, "line", ([q[:2] for q in P], w)))
        elif pr.kind == KIND_DISC:
            center, n = pr.pts[0], unit(pr.pts[1] - pr.pts[0])
            a = unit(np.cross(n, [0.0, 1.0, 0.0] if abs(n[1]) < 0.9 else [1.0, 0.0, 0.0]))
            bb = np.cross(n, a)
            P = [cam.p(center + (a * math.cos(t) + bb * math.sin(t)) * pr.width) for t in np.linspace(0, 2 * math.pi, 24, endpoint=False)]
            out.append((cam.p(center)[2] + bias, group, "poly", [q[:2] for q in P]))
        elif pr.kind == KIND_BALL:
            x, y, z = cam.p(pr.pts[0])
            out.append((z + bias - (0.7 if truth else lift) * pr.width, group, "circle", (x, y, pr.width * cam.k)))
    return out


# --- Painting ------------------------------------------------------------------------------------------------------

def paint(cam, items, ids):
    """The label of the nearest thing at every pixel, by painting from the farthest to the nearest."""
    img = Image.new("I", (cam.W, cam.H), 0)
    draw = ImageDraw.Draw(img)
    for z, group, kind, shape in sorted(items, key=lambda it: -it[0]):
        label = ids.setdefault(group, len(ids) + 1)
        if kind == "poly":
            if len(shape) >= 3:
                draw.polygon([(float(q[0]), float(q[1])) for q in shape], fill=label, outline=label)
        elif kind == "line":
            pts, w = shape
            draw.line([(float(q[0]), float(q[1])) for q in pts], fill=label, width=max(1, int(round(w))))
            for x, y in ((float(q[0]), float(q[1])) for q in pts):
                draw.ellipse([x - w / 2, y - w / 2, x + w / 2, y + w / 2], fill=label)
        else:
            x, y, r = shape
            draw.ellipse([x - r, y - r, x + r, y + r], fill=label)
    return np.array(img)


def frame(scene, view, mode, cell, lift=0.0):
    """(cm² painted in the wrong order between body and equipment, {(body part, gear): cm²}, images)."""
    b = scene.body
    pts = [q for pr in scene.prims for q in pr.pts]
    cam = Cam(view, pts)
    ids = {}
    body_names = set()
    truth_items = body_items(cam, b, "truth") + gear_items(cam, scene, FINE, truth=True)
    if mode == "old":
        app_items = body_items(cam, b, "whole") + gear_items(cam, scene, None)
    else:
        app_items = body_items(cam, b, "sliced", lift) + gear_items(cam, scene, cell, lift=lift)
    body_names.update(g for _, g, _, _ in app_items if "#" not in g)
    truth = paint(cam, truth_items, ids)
    app = paint(cam, app_items, ids)
    is_body = np.zeros(len(ids) + 1, dtype=bool)
    for g, i in ids.items():
        is_body[i] = g in body_names
    wrong = (is_body[truth] != is_body[app]) & (truth > 0) & (app > 0)
    core = wrong.copy()
    core[1:, :] &= wrong[:-1, :]
    core[:-1, :] &= wrong[1:, :]
    core[:, 1:] &= wrong[:, :-1]
    core[:, :-1] &= wrong[:, 1:]
    wrong = core
    px = (100.0 / cam.k) ** 2     # cm² per pixel
    names = {i: g for g, i in ids.items()}
    pairs = {}
    for t, a in zip(truth[wrong], app[wrong]):
        part, gear = (names[t], names[a]) if is_body[t] else (names[a], names[t])
        key = (part, gear.split("#")[0], "matériel devant" if is_body[t] else "corps devant")
        pairs[key] = pairs.get(key, 0.0) + px
    return float(wrong.sum()) * px, pairs, (app, truth, wrong, is_body)


def analyse(d, mode, cell, lift=0.0):
    worst, where, detail = 0.0, None, {}
    samples = demos.sample(d)
    step = max(1, len(samples) // 6)
    for p, scene in samples[::step]:
        if scene.body is None:
            continue
        for vi, view in enumerate(d.views):
            area, pairs, _ = frame(scene, view, mode, cell, lift)
            if area > worst:
                worst, where, detail = area, (p, vi, view.name), pairs
    return worst, where, detail


def picture(ident, p, vi, mode, cell, lift=0.0):
    d = demos.DEMOS[ident]
    scene = min(demos.sample(d), key=lambda ps: abs(ps[0] - p))[1]
    _, _, (app, truth, wrong, is_body) = frame(scene, d.views[vi], mode, cell, lift)

    def colour(lab, mark=None):
        rgb = np.zeros(lab.shape + (3,), dtype=np.uint8) + 24
        rgb[(lab > 0) & ~is_body[lab]] = (95, 100, 110)
        rgb[(lab > 0) & is_body[lab]] = (215, 215, 220)
        edges = np.zeros(lab.shape, dtype=bool)
        edges[:, 1:] |= lab[:, 1:] != lab[:, :-1]
        edges[1:, :] |= lab[1:, :] != lab[:-1, :]
        rgb[edges] = (rgb[edges] * 0.6).astype(np.uint8)
        if mark is not None:
            rgb[mark] = (235, 60, 60)
        return rgb
    sheet = np.concatenate([colour(app), colour(truth), colour(truth, wrong)], axis=1)
    out = HERE / "out"
    out.mkdir(exist_ok=True)
    path = out / f"occlusion-{ident}-{mode}.png"
    Image.fromarray(sheet).save(path)
    return path


def _one(ident, mode, cell, lift):
    return analyse(demos.DEMOS[ident], mode, cell, lift)


def main():
    args = sys.argv[1:]

    def option(name, default, cast):
        if name in args:
            i = args.index(name)
            value = cast(args[i + 1])
            del args[i:i + 2]
            return value
        return default
    minimum = option("--min", 15.0, float)
    mode = option("--mode", "app", str)
    cell = option("--cell", 0.1, float)
    lift = option("--lift", 0.6, float)
    png = "--png" in args
    ids = [a for a in args if not a.startswith("--")] or sorted(demos.DEMOS)
    rows, total = [], 0.0
    with multiprocessing.Pool() as pool:
        results = pool.starmap(_one, [(ident, mode, cell, lift) for ident in ids])
    for ident, (worst, where, detail) in zip(ids, results):
        total += worst
        if worst >= minimum:
            rows.append((worst, ident, where, detail))
    rows.sort(reverse=True, key=lambda r: r[0])
    for worst, ident, where, detail in rows:
        text = ", ".join(f"{part}/{gear} {side} {v:.0f}" for (part, gear, side), v in sorted(detail.items(), key=lambda kv: -kv[1])[:3])
        if where is None:
            continue
        print(f"{worst:6.0f} cm²  {ident:34s} {where[2]} p={where[0]:.2f}  {text}")
        if png:
            print("   ", picture(ident, where[0], where[1], mode, cell, lift))
    print(f"\n{len(rows)} démonstrations sur {len(ids)} au-delà de {minimum:g} cm² (mode {mode}) ; somme des pires vues : {total:.0f} cm²")


if __name__ == "__main__":
    main()
