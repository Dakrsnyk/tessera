"""Flat body parts in the demonstrations (2026-11-24): a limb whose cross-section collapses to a plane.

    python3 scripts/demos/flatness.py [ids…]

The sculpted mannequin (sculpt.py, SculptMannequin.swift) sweeps each limb around its axis with two directions, front
and away; the feet and the hands are ellipsoids on three axes. When two of those directions line up (a forearm bent at
a right angle, a foot pointing down), the volume is drawn as a flat sheet. Prints, per demonstration, the parts whose
thinnest direction falls under 60 % of what it should be, with the worst phase.
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
import sculpt  # noqa: E402

for path in sorted(glob.glob(str(HERE / "ex_*.py"))):
    importlib.import_module(Path(path).stem)


def thinness(axis, u, v):
    """How much of its section a sweep keeps: the area spanned by u and v across the axis (1 = full, 0 = a plane)."""
    axis = axis / np.linalg.norm(axis)
    pu, pv = u - axis * np.dot(u, axis), v - axis * np.dot(v, axis)
    value = float(np.linalg.norm(np.cross(pu, pv)))
    return value if math.isfinite(value) else 0.0


def volume(a0, a1, a2):
    """The same for an ellipsoid: the volume its three axes span, over the product of their lengths."""
    n = np.linalg.norm(a0) * np.linalg.norm(a1) * np.linalg.norm(a2)
    value = float(abs(np.dot(a0, np.cross(a1, a2))) / n) if n > 1e-12 else 0.0
    return value if math.isfinite(value) else 0.0


def parts(b):
    body = sculpt.Body(b)
    out = {}
    names = {"arm": "bras", "fore": "avant-bras", "thigh": "cuisse", "shin": "tibia"}
    for (kind, s), (a, e, front, away, _) in body.limbs.items():
        out[f"{names[kind]} {'droit' if s == 1 else 'gauche'}"] = thinness(e - a, front, away)
    for s in (1, -1):
        tag = "droit" if s == 1 else "gauche"
        if ("fore", s) in body.limbs:
            _, _, ff, fa, _ = body.limbs[("fore", s)]
            out[f"main {tag}"] = volume(b.grip[s] - b.elbow[s], fa, ff)
        if s in b.toe and s in b.ankle:
            heel, foot = sculpt.foot_axes(b, s)
            out[f"talon {tag}"] = volume(*heel[1])
            out[f"pied {tag}"] = volume(*foot[1])
    return out


def main():
    ids = [a for a in sys.argv[1:] if not a.startswith("--")] or sorted(demos.DEMOS)
    rows = []
    for ident in ids:
        worst = {}
        for p, scene in demos.sample(demos.DEMOS[ident]):
            if scene.body is None:
                continue
            for name, value in parts(scene.body).items():
                if value < worst.get(name, (1.0, 0))[0]:
                    worst[name] = (value, p)
        flat = {k: v for k, v in worst.items() if v[0] < 0.6}
        if flat:
            rows.append((min(v[0] for v in flat.values()), ident, flat))
    rows.sort(key=lambda r: r[0])
    for _, ident, flat in rows:
        print(f"{ident:36s} " + ", ".join(f"{k} {v[0] * 100:.0f} % (p={v[1]:.2f})" for k, v in sorted(flat.items(), key=lambda kv: kv[1][0])))
    print(f"\n{len(rows)} démonstrations sur {len(ids)} avec une partie du corps aplatie")


if __name__ == "__main__":
    main()
