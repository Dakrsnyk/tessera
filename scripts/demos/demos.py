"""Registry of exercise demonstrations, sampling, checks and export for the app."""
import base64
import json
import math
import re
from pathlib import Path

import numpy as np

from engine import (KIND_BALL, KIND_DISC, KIND_LINE, KIND_POLY, ROLES, Body, Scene, View, Y, ease, lerp)

REPO = Path(__file__).resolve().parents[2]

# --- What the app knows about each exercise (muscles, equipment), read from the library. ---------

def read_library():
    text = (REPO / "Shared/Domains/ExerciseLibrary.swift").read_text()
    out = {}
    pattern = re.compile(r'x\("([^"]+)", "([^"]+)", \[([^\]]*)\], \[([^\]]*)\], \[([^\]]*)\], \.(\w+), \.(\w+), \.(\w+)')
    for m in pattern.finditer(text):
        ident, name, prim, sec, equip, typ, diff, pat = m.groups()
        split = lambda s: [w.strip().lstrip(".") for w in s.split(",") if w.strip()]
        out[ident] = dict(id=ident, name=name, primary=split(prim), secondary=split(sec), equipment=split(equip),
                          type=typ, difficulty=diff, pattern=pat)
    return out


LIBRARY = read_library()

# --- Registry ------------------------------------------------------------------------------------

DEMOS = {}


class Demo:
    def __init__(self, ident, fn, views, labels, timing, mode, samples, muscles, travel, segments):
        self.id = ident
        self.fn = fn
        self.views = views
        self.labels = labels
        self.timing = timing
        self.mode = mode
        self.samples = samples
        self.muscles = muscles
        self.travel = travel
        self.segments = segments

    def info(self):
        return LIBRARY.get(self.id)

    def muscle_sets(self):
        if self.muscles is not None:
            return self.muscles
        info = self.info() or {}
        primary = [m for m in info.get("primary", []) if m not in ("fullBody", "heart")]
        secondary = [m for m in info.get("secondary", []) if m not in ("fullBody", "heart")]
        if not primary:
            primary, secondary = secondary, []
        return primary, secondary

    def scene(self, p):
        scene = Scene()
        scene.muscles = self.muscle_sets()
        self.fn(p, scene)
        return scene

    def phases(self):
        """Samples of the phase p."""
        n = self.samples
        if self.mode == "loop":
            return [i / n for i in range(n)]
        return [i / (n - 1) for i in range(n)]


    def timeline(self):
        """[(seconds, p from, p to, label index or -1)]"""
        if self.segments:
            return self.segments
        if self.mode == "loop":
            return [(self.timing, 0.0, 1.0, -1)]
        hold0, go, hold1, back = self.timing
        return [(hold0, 0.0, 0.0, 0), (go, 0.0, 1.0, 1), (hold1, 1.0, 1.0, 2), (back, 1.0, 0.0, 3)]


DEFAULT_LABELS = ("Départ", "Mouvement", "Position finale", "Retour")


def demo(ident, views, labels=DEFAULT_LABELS, timing=(0.7, 1.5, 0.6, 1.5), mode="pingpong", samples=13,
         muscles=None, travel=None, segments=None):
    def wrap(fn):
        if ident in DEMOS:
            raise ValueError(f"twice: {ident}")
        DEMOS[ident] = Demo(ident, fn, views, labels, timing, mode, samples, muscles, travel, segments)
        return fn
    return wrap


# --- Body emission hook: the body draws itself with the exercise's muscles. ----------------------

def settle_feet(scene, body):
    """A foot never goes into the floor: when the toe would, the floor flattens the foot (it turns
    around the ankle until the toe rests on the floor)."""
    if not scene.ground:
        return
    floor_y = 0.02
    for side, toe in list(body.toe.items()):
        ankle = body.ankle.get(side) if hasattr(body.ankle, "get") else None
        if ankle is None or toe[1] >= floor_y:
            continue
        v = toe - ankle
        length = float(np.linalg.norm(v))
        dy = floor_y - ankle[1]
        flat = v.copy()
        flat[1] = 0.0
        if np.linalg.norm(flat) < 1e-6:
            flat = body.pelvis.f.copy()
            flat[1] = 0.0
        flat = flat / np.linalg.norm(flat)
        if dy < 0 and -dy < length:
            body.toe[side] = ankle + flat * math.sqrt(length ** 2 - dy ** 2) + Y * dy
        else:
            fixed = toe.copy()
            fixed[1] = floor_y
            body.toe[side] = fixed


def show(scene, body, muscles=None):
    primary, secondary = muscles if muscles is not None else scene.muscles
    settle_feet(scene, body)
    body.emit(scene, primary, secondary)


# --- Checks --------------------------------------------------------------------------------------

def body_samples(body):
    """Points along the body with their radius, to test against the equipment and the floor."""
    out = []

    def seg(a, b, r, name):
        for t in np.linspace(0, 1, 6):
            out.append((lerp(a, b, t), r, name))

    for side in (1, -1):
        tag = "droit" if side == 1 else "gauche"
        if side in body.elbow:
            seg(body.shoulder[side], body.elbow[side], body.W_UPPER / 2, f"bras {tag}")
            seg(body.elbow[side], body.grip[side], body.W_LOWER / 2, f"avant-bras {tag}")
        if side in body.knee:
            seg(body.hip[side], body.knee[side], body.W_THIGH / 2, f"cuisse {tag}")
            seg(body.knee[side], body.ankle[side], body.W_SHIN / 2, f"tibia {tag}")
            if side in body.toe:
                seg(body.ankle[side], body.toe[side], 0.02, f"pied {tag}")
    seg(body.pelvis.o, body.waist, body.W_TORSO / 2, "bassin")
    seg(body.waist, body.neck, body.W_TORSO / 2, "buste")
    out.append((body.head, body.HEAD, "tête"))
    return out


def check(demo_obj, scenes):
    problems = []
    for p, scene in scenes:
        body = scene.body
        if body is None:
            continue
        for key, short in body.shortfall.items():
            if short > 0.012:
                problems.append(f"p={p:.2f} {key[0]} {'droit' if key[1] == 1 else 'gauche'} trop court de {short * 100:.1f} cm")
        allowed = getattr(scene, "allow", set())
        for point, radius, name in body_samples(body):
            if scene.ground and point[1] - radius < -0.015 and name not in allowed:
                problems.append(f"p={p:.2f} {name} sous le sol ({(point[1] - radius) * 100:.1f} cm)")
            for solid in scene.solids:
                if (name, solid.name) in allowed or solid.name in allowed:
                    continue
                depth = solid.penetration(point, radius * 0.75)
                seat = any(w in solid.name for w in ("siège", "assise", "banc", "plateau"))
                limit = 0.045 if (seat and name.startswith(("cuisse", "bassin"))) else 0.02
                if depth > limit:
                    problems.append(f"p={p:.2f} {name} dans {solid.name} ({depth * 100:.1f} cm)")
        # Knees bend backward, elbows never overextend.
        for side in (1, -1):
            if side in body.knee:
                hip, knee, ankle = body.hip[side], body.knee[side], body.ankle[side]
                thigh = knee - hip
                shin = ankle - knee
                bend = np.cross(thigh, shin)
                straightness = np.dot(thigh, shin) / (np.linalg.norm(thigh) * np.linalg.norm(shin))
                if straightness < 0.995 and np.dot(bend, body.pelvis.r) > 1e-4:
                    problems.append(f"p={p:.2f} genou {'droit' if side == 1 else 'gauche'} plié à l'envers")
    # Dedupe repeated messages.
    seen, keys = [], set()
    for prob in problems:
        key = re.sub(r"[-\d.]+", "#", re.sub(r"p=\S+ ", "", prob))
        if key not in keys:
            keys.add(key)
            seen.append(prob)
    return seen


# --- Sampling and export -------------------------------------------------------------------------

def sample(demo_obj):
    scenes = [(p, demo_obj.scene(p)) for p in demo_obj.phases()]
    first = scenes[0][1]
    signature = [(pr.kind, pr.role, len(pr.pts)) for pr in first.prims]
    for p, sc in scenes[1:]:
        sig = [(pr.kind, pr.role, len(pr.pts)) for pr in sc.prims]
        if sig != signature:
            raise ValueError(f"{demo_obj.id}: la scène change de structure à p={p}")
    return scenes


def view_box(scenes, view):
    xs, ys = [], []
    for _, sc in scenes:
        for pr in sc.prims:
            if pr.role == "floor":
                continue
            pts = view.project(pr.pts)
            if pr.kind == KIND_LINE or pr.kind == KIND_POLY:
                r = pr.width / 2
                pts = pts[:, :2]
            elif pr.kind == KIND_BALL:
                r = pr.width
                pts = pts[:1, :2]
            else:
                r = pr.width
                pts = pts[:1, :2]
            xs += list(pts[:, 0] - r) + list(pts[:, 0] + r)
            ys += list(pts[:, 1] - r) + list(pts[:, 1] + r)
    return [min(xs), min(ys), max(xs), max(ys)]


def quantize(values):
    arr = np.round(np.asarray(values, dtype=float) * 1000).astype(np.int64)
    if arr.size and (arr.max() > 32767 or arr.min() < -32768):
        raise ValueError("coordinate out of range")
    return base64.b64encode(arr.astype("<i2").tobytes()).decode("ascii")


def export(demo_obj, scenes):
    n = len(scenes)
    prims0 = scenes[0][1].prims
    # Every point slot, across samples.
    slots = []
    for i, pr in enumerate(prims0):
        for j in range(len(pr.pts)):
            track = np.array([sc.prims[i].pts[j] for _, sc in scenes])
            slots.append(track)
    keys = {}
    static, dynamic = [], []
    index_of_slot = []
    for track in slots:
        rounded = tuple(np.round(track * 1000).astype(int).flatten())
        if rounded in keys:
            index_of_slot.append(keys[rounded])
            continue
        if np.allclose(track, track[0], atol=0.0005):
            ref = ("s", len(static))
            static.append(track[0])
        else:
            ref = ("d", len(dynamic))
            dynamic.append(track)
        keys[rounded] = ref
        index_of_slot.append(ref)
    S = len(static)

    def resolve(ref):
        return ref[1] if ref[0] == "s" else S + ref[1]

    prims = []
    k = 0
    for pr in prims0:
        idx = []
        for _ in pr.pts:
            idx.append(resolve(index_of_slot[k]))
            k += 1
        prims.append([pr.kind, ROLES.index(pr.role), int(round(pr.width * 1000)), int(round(pr.bias * 1000)),
                      pr.side, pr.flags] + idx)
    dyn = np.zeros((n, len(dynamic), 3))
    for d, track in enumerate(dynamic):
        dyn[:, d, :] = track
    body = scenes[0][1].body
    views = []
    for v in demo_obj.views:
        box = view_box(scenes, v)
        views.append({"name": v.name, "yaw": v.yaw, "pitch": v.pitch, "box": [round(b, 3) for b in box]})
    # Side shading uses the shoulders.
    refs = []
    if body is not None:
        for target in (body.shoulder[1], body.shoulder[-1]):
            refs.append(find_point(scenes, target, index_of_slot, resolve, prims0))
    timeline = []
    for seg in demo_obj.timeline():
        a, b, c, lab = seg[:4]
        ease_flag = seg[4] if len(seg) > 4 else (0 if demo_obj.mode == "loop" else 1)
        timeline.append([round(a, 3), round(b, 4), round(c, 4), lab, ease_flag])
    return {
        "id": demo_obj.id,
        "loop": demo_obj.mode == "loop",
        "n": n,
        "timeline": timeline,
        "labels": list(demo_obj.labels) if (demo_obj.mode != "loop" or demo_obj.segments) else [],
        "views": views,
        "static": quantize(np.array(static).flatten()) if static else "",
        "dynamic": quantize(dyn.flatten()) if dynamic else "",
        "points": [S, len(dynamic)],
        "prims": prims,
        "shoulders": refs,
        "marks": list(demo_obj.travel) if demo_obj.travel else [],
    }


def find_point(scenes, target, index_of_slot, resolve, prims0):
    k = 0
    for pr in prims0:
        for pt in pr.pts:
            if np.allclose(pt, target, atol=1e-6):
                return resolve(index_of_slot[k])
            k += 1
    return -1
