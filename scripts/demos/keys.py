"""Movements in several stages: poses described by a few parameters (pelvis, lean, where the hands
and feet are), blended between keys, and solved into a body (so bones keep their length)."""
import numpy as np

from engine import Body, Frame, X, Y, Z, posture, unit, vec


def blend(a, b, t):
    if isinstance(a, dict):
        return {k: blend(a[k], b[k], t) for k in a}
    if isinstance(a, (list, tuple)):
        return type(a)(blend(x, y, t) for x, y in zip(a, b))
    if isinstance(a, np.ndarray):
        return a + (b - a) * t
    if isinstance(a, (int, float)):
        return a + (b - a) * t
    return a if t < 0.5 else b


def keyed(p, keys):
    """keys: [(p, params), ...] sorted by p. Linear between keys (the timeline eases each stage)."""
    if p <= keys[0][0]:
        return keys[0][1]
    for (p0, a), (p1, b) in zip(keys[:-1], keys[1:]):
        if p <= p1 + 1e-9:
            t = 0.0 if p1 == p0 else (p - p0) / (p1 - p0)
            out = blend(a, b, t)
            if 1e-6 < t < 1 - 1e-6:
                out = dict(out)
                out["_transit"] = True
            return out
    return keys[-1][1]


def stage_segments(keys, durations, labels_index, holds=None):
    """Timeline segments, one per stage between keys, each eased."""
    segs = []
    for i, ((p0, _), (p1, _)) in enumerate(zip(keys[:-1], keys[1:])):
        if holds and holds[i]:
            segs.append((holds[i], p0, p0, labels_index[i], 1))
        segs.append((durations[i], p0, p1, labels_index[i], 1))
    return segs


def pose(params):
    """params: pelvis, lean (forward tilt), facing, spine, twist, bend, head, shrug, and
    arms {side: (target, pole)} / legs {side: (ankle, pole, toe or None)}; or 'frame': (f, u)."""
    if "frame" in params:
        f, u = params["frame"]
        frame = Frame(params["pelvis"], f, u)
    else:
        frame = posture(params["pelvis"], params.get("facing", 0.0), params.get("lean", 0.0))
    body = Body(frame, spine=params.get("spine", 0.0), twist=params.get("twist", 0.0), bend=params.get("bend", 0.0),
                head=params.get("head", 0.0), shrug=params.get("shrug", 0.0))
    for side, (ankle, pole, toe) in params.get("legs", {}).items():
        body.leg(side, ankle, pole=unit(pole))
        if toe is not None:
            body.toe[side] = np.asarray(toe, dtype=float)
        else:
            body.foot_relaxed(side, plantar=0)
    for side, (target, pole) in params.get("arms", {}).items():
        if params.get("_transit"):
            # Between two key poses the hands travel: keep them within reach (no overstretched arm).
            sh = body.shoulder[side]
            d = np.asarray(target, dtype=float) - sh
            reach = Body.UPPER + Body.LOWER - 0.004
            dist = float(np.linalg.norm(d))
            if dist > reach:
                target = sh + d * (reach / dist)
        body.arm(side, target, unit(pole))
    return body


def flat_foot(x, z, facing_x=1.0):
    ankle = vec(x, Body.ANKLE, z)
    toe = ankle + X * 0.165 * facing_x - Y * 0.06
    return ankle, toe
