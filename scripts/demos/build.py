"""Builds the demonstrations: samples, checks, exports, and review sheets."""
import json
import sys
from pathlib import Path

import demos
import ex_chest, ex_legs, ex_back, ex_shoulders, ex_arms, ex_core, ex_full, ex_cardio, ex_mobility  # noqa: F401  (registration)
from preview import sheet, animation

OUT = Path(__file__).parent / "out"
OUT.mkdir(exist_ok=True)


def build(ids=None):
    results, problems = {}, {}
    for ident, d in demos.DEMOS.items():
        if ids and ident not in ids:
            continue
        scenes = demos.sample(d)
        problems[ident] = demos.check(d, scenes)
        results[ident] = demos.export(d, scenes)
    return results, problems


if __name__ == "__main__":
    ids = sys.argv[1:] or None
    results, problems = build(ids)
    for ident, probs in problems.items():
        if probs:
            print(ident, "\n  " + "\n  ".join(probs))
    names = {k: v["name"] for k, v in demos.LIBRARY.items()}
    items = list(results.values())
    for old in OUT.glob("sheet*.png"):
        old.unlink()
    for k in range(0, len(items), 4):
        sheet(items[k:k + 4], OUT / f"sheet{k // 4:02d}.png", names=names, problems=problems, W=250, H=172)
    print("ok", len(results))
