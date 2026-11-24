"""Anatomy figures for the muscle groups of the exercise library (2026-11-23, CEO's request): the figure of the exercise
demonstrations, standing, with the group in red (the role « muscle », as in every demonstration), seen from the side
that shows it, framed on the muscle and breathing slowly in a loop.

Built alone and merged into App/Resources/ExerciseDemos.json under the ids « anatomy-<MuscleGroup raw value> », without
touching the exercise demonstrations (export_all.py would rebuild them all).

    ~/ardane-tools/venv/Scripts/python.exe scripts/demos/anatomy.py [--sheet]
"""
import json
import math
import sys
from pathlib import Path

import numpy as np

import demos
from demos import demo, export, sample, show
from engine import BACK, FRONT, Y
from gear import floor
from poses import stance, upright

OUT = Path(__file__).resolve().parents[2] / "App" / "Resources" / "ExerciseDemos.json"

# MuscleGroup raw value -> (muscles in red, view, framing). Framing: None = the whole body, else the muscles' box
# enlarged so that the muscle sits in the middle with some of the body around it.
GROUPS = {
    "chest": (["chest"], FRONT(4), 0.12),
    "back": (["back", "traps"], BACK(4), 0.12),
    "shoulders": (["shoulders"], FRONT(4), 0.14),
    "biceps": (["biceps"], FRONT(4), 0.12),
    "triceps": (["triceps"], BACK(4), 0.12),
    "forearms": (["forearms"], FRONT(4), 0.12),
    "quads": (["quads"], FRONT(4), 0.12),
    "hamstrings": (["hamstrings"], BACK(4), 0.12),
    "glutes": (["glutes"], BACK(4), 0.12),
    "calves": (["calves"], BACK(4), 0.12),
    "abs": (["abs", "obliques"], FRONT(4), 0.12),
    "lowerBack": (["lowerBack"], BACK(4), 0.12),
    "fullBody": (["chest", "back", "shoulders", "biceps", "triceps", "quads", "glutes", "abs"], FRONT(4), None),
}



ARMS_OUT = {"biceps": 0.36, "triceps": 0.36, "forearms": 0.36}   # the arms away from the trunk, so it hides none of them


def register(group, muscles, view):
    @demo(f"anatomy-{group}", views=[view], mode="loop", timing=3.2, samples=16, labels=(), muscles=(muscles, []))
    def figure(p, s):
        floor(s, -0.45, 0.45, -0.5, 0.5)
        breath = math.sin(2 * math.pi * p)
        # Standing tall, the chest rising a little with each breath, arms hanging a little away from the body.
        body = upright(0.945 + 0.004 * breath, 0.0, pelvis_x=0.0, head=0)
        stance(body, 0.0, half_width=0.13)
        for side in (1, -1):
            sh = body.shoulder[side]
            out = ARMS_OUT.get(group, 0.20) + 0.025 * breath
            d = -Y + body.chest.r * side * out
            d = d / np.linalg.norm(d)
            grip = sh + d * (0.30 + 0.34 - 0.03)
            body.arm(side, grip, -body.chest.f * 0.2 + Y * 0.0 + body.pelvis.f * -1)
        show(s, body)
    return demos.DEMOS[f"anatomy-{group}"]


# Every close-up has the frame of the chest one (CEO, 2026-11-23: « comme pour le chest ou lower back »): the same size,
# so every muscle is seen at the same scale, on the same part of body around it.
CLOSE_W, CLOSE_H = 0.70, 0.60


def focus_box(scenes, view, margin):
    """The chest's frame (CLOSE_W × CLOSE_H), centred on the red strokes over the loop. `margin` is kept for a muscle
    wider than the frame (both forearms), which then gets a frame just large enough."""
    xs, ys = [], []
    for _, sc in scenes:
        for pr in sc.prims:
            if pr.role != "muscle":
                continue
            pts = view.project(pr.pts)[:, :2]
            r = pr.width
            xs += list(pts[:, 0] - r) + list(pts[:, 0] + r)
            ys += list(pts[:, 1] - r) + list(pts[:, 1] + r)
    cx, cy = (min(xs) + max(xs)) / 2, (min(ys) + max(ys)) / 2
    scale = max(1.0, (max(xs) - min(xs) + margin) / CLOSE_W, (max(ys) - min(ys) + margin) / CLOSE_H)
    w, h = CLOSE_W * scale, CLOSE_H * scale
    return [round(cx - w / 2, 3), round(cy - h / 2, 3), round(cx + w / 2, 3), round(cy + h / 2, 3)]


def build():
    out = {}
    for group, (muscles, view, margin) in GROUPS.items():
        d = register(group, muscles, view)
        scenes = sample(d)
        problems = demos.check(d, scenes)
        if problems:
            print(group, problems)
        data = export(d, scenes)
        if margin is not None:
            data["views"][0]["box"] = focus_box(scenes, view, margin)
            data["views"][0]["close"] = True   # the app fills the box (ExerciseDemo.swift, `ViewSpec.close`)
        out[d.id] = data
    return out


if __name__ == "__main__":
    results = build()
    payload = json.loads(OUT.read_text(encoding="utf-8"))
    before = len(payload["demos"])
    payload["demos"].update(results)
    OUT.write_text(json.dumps(payload, separators=(",", ":"), ensure_ascii=False), encoding="utf-8")
    print(f"{len(results)} anatomy figures merged; {before} -> {len(payload['demos'])} demonstrations")
    if "--sheet" in sys.argv:
        from preview import sheet
        sheet(list(results.values()), Path(__file__).parent / "out" / "anatomy.png", W=260, H=226, dark=True)
        print("sheet: scripts/demos/out/anatomy.png")
