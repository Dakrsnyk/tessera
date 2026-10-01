"""Cardio: running, walking, treadmill, high knees, bikes, rower, elliptical, stepper, jumps, rope,
circuit, swimming, boxing."""
import math

import numpy as np

from cyclic import foot_path, walk_cycle
from demos import demo, show
from engine import (ABOVE, BACK, FRONT, PROFILE, THREE_QUARTER, Body, Frame, SIDE_LEFT, SIDE_RIGHT, View, X, Y, Z,
                    lerp, posture, rotate, unit, vec)
from gear import PAD_T, TUBE, floor, foot_bar
from keys import blend, flat_foot, keyed, pose, stage_segments
from poses import placed, solve, stance, upright


def smooth(t):
    t = min(1.0, max(0.0, t))
    return t * t * (3 - 2 * t)


def mid(body):
    return (body.shoulder[1] + body.shoulder[-1]) / 2


RUN_MUSCLES = (["quads", "calves"], ["hamstrings", "glutes"])


@demo("running", views=[PROFILE(), THREE_QUARTER(35, 10)], mode="loop", timing=0.72, samples=24, labels=(),
      travel=(2.0, 0.5, -1.5, 1.5, -0.45, 0.45, 0.0, 40.0), muscles=RUN_MUSCLES)
def running(p, s):
    floor(s, -1.5, 1.5)
    body = walk_cycle(p, s, stride=1.0, arms="run", lean=8.0, bounce=0.035, stance=0.34, lift=0.12, run=True, hip=0.9)
    show(s, body)


@demo("walking", views=[PROFILE(), THREE_QUARTER(35, 10)], mode="loop", timing=1.1, samples=24, labels=(),
      travel=(1.24, 0.31, -1.4, 1.4, -0.45, 0.45, 0.0, 40.0), muscles=(["calves"], ["quads", "glutes"]))
def walking(p, s):
    floor(s, -1.4, 1.4)
    body = walk_cycle(p, s, stride=0.62, arms="swing", lean=3.0, bounce=0.02, stance=0.6, lift=0.1, hip=0.875)
    show(s, body)


def treadmill(s, deck_y=0.2, incline=0.0, x0=-0.85, x1=0.95):
    """Deck with the belt, the upright and console in front, handrails."""
    def ty(x):
        return deck_y + incline * x
    s.slab(vec(x0, ty(x0), 0), vec(x1, ty(x1), 0), unit(vec(-incline, 1.0, 0.0)), 0.6, 0.1, "pad", solid="le tapis")
    s.line([vec(x0 + 0.1, ty(x0) - 0.1, 0), vec(x0 + 0.1, 0.03, 0)], TUBE, "frame")
    s.line([vec(x1 - 0.1, ty(x1) - 0.1, 0), vec(x1 - 0.1, 0.03, 0)], TUBE, "frame")
    for side in (1, -1):
        sd = SIDE_RIGHT if side == 1 else SIDE_LEFT
        z = side * 0.36
        s.line([vec(x1 - 0.05, ty(x1), z), vec(x1 + 0.05, ty(x1) + 1.15, z)], TUBE * 1.2, "frame", side=sd)
        s.line([vec(x1 + 0.0, ty(x1) + 0.95, z), vec(x1 - 0.55, ty(x1) + 0.95, z)], TUBE, "frame", side=sd)
    s.slab(vec(x1 + 0.05, ty(x1) + 1.2, 0), vec(x1 - 0.15, ty(x1) + 1.33, 0), unit(vec(-0.6, 1.0, 0.0)), 0.6, 0.05, "load")


@demo("treadmill", views=[PROFILE(), THREE_QUARTER(35, 12)], mode="loop", timing=0.78, samples=24, labels=(),
      travel=(1.7, 0.34, -0.8, 0.9, -0.25, 0.25, 0.205, -0.02), muscles=RUN_MUSCLES)
def treadmill_run(p, s):
    floor(s, -1.1, 1.3)
    treadmill(s)
    body = walk_cycle(p, s, stride=0.85, arms="run", lean=6.0, bounce=0.03, stance=0.36, lift=0.1, run=True, hip=0.9,
                      ground=0.2)
    show(s, body)


@demo("incline-walk", views=[PROFILE(), THREE_QUARTER(35, 12)], mode="loop", timing=1.2, samples=24, labels=(),
      travel=(1.08, 0.27, -0.8, 0.9, -0.25, 0.25, 0.205, -0.02, 0.18), muscles=(["glutes", "calves"], ["quads", "hamstrings"]))
def incline_walk(p, s):
    floor(s, -1.1, 1.3)
    incline = 0.18
    treadmill(s, incline=incline)
    body = walk_cycle(p, s, stride=0.54, arms="swing", lean=8.0, bounce=0.015, stance=0.6, lift=0.09, hip=0.86,
                      ground=0.2, incline=incline)
    show(s, body)


@demo("high-knees", views=[PROFILE(), THREE_QUARTER(35, 10)], mode="loop", timing=0.6, samples=24, labels=(),
      muscles=(["quads"], ["calves", "abs"]))
def high_knees(p, s):
    floor(s, -0.7, 0.9)
    bounce = 0.04 * abs(math.sin(2 * math.pi * p))
    body = upright(0.93 + bounce, 2.0, pelvis_x=0.0, head=0)
    for side, offset in ((1, 0.0), (-1, 0.5)):
        t = (p + offset) % 1.0
        up = math.sin(math.pi * t / 0.6) if t < 0.6 else 0.0      # knee up to hip height, then down
        thigh = unit(lerp(vec(0.0, -1.0, 0.0), vec(1.0, 0.05, 0.0), up))
        shin = unit(lerp(vec(0.0, -1.0, 0.0), vec(-0.15, -1.0, 0.0), up))
        if up < 0.02:
            body.foot_on_floor(side, (0.04, side * 0.11), 0.0, pole=X)
            body.toe[side] = body.ankle[side] + vec(0.15, -0.07, 0.0)
        else:
            body.leg_dirs(side, thigh, shin)
            body.foot_relaxed(side, plantar=25)
    for side, offset in ((1, 0.5), (-1, 0.0)):
        a = math.sin(2 * math.pi * (p + offset) + math.pi / 2)
        sh = body.shoulder[side]
        upper = unit(-Y + X * 0.6 * a)
        elbow = sh + upper * Body.UPPER
        body.arm(side, elbow + rotate(upper, Z, 95) * Body.LOWER, unit(-X))
    show(s, body)


# --- Bikes ---------------------------------------------------------------------------------------------

def pedal_legs(body, crank, p, radius=0.17, half=0.11):
    for side, offset in ((1, 0.0), (-1, 0.5)):
        a = 2 * math.pi * (p + offset)
        pedal = crank + vec(radius * math.cos(a), radius * math.sin(a), side * half)
        ankle = pedal + vec(-0.07, 0.07, 0.0)
        body.leg(side, ankle, pole=X)
        body.toe[side] = ankle + vec(0.16, -0.05, 0.0)
    return body


def crank_parts(s, crank, p, radius=0.17, half=0.11):
    for side, offset in ((1, 0.0), (-1, 0.5)):
        a = 2 * math.pi * (p + offset)
        pedal = crank + vec(radius * math.cos(a), radius * math.sin(a), side * half)
        sd = SIDE_RIGHT if side == 1 else SIDE_LEFT
        s.line([crank + Z * side * 0.06, pedal - Z * side * 0.03], 0.025, "metal", side=sd)
        s.line([pedal - X * 0.05, pedal + X * 0.05], 0.03, "load", side=sd)


@demo("cycling", views=[PROFILE(), THREE_QUARTER(35, 12)], mode="loop", timing=0.9, samples=24, labels=(),
      travel=(2.4, 0.4, -1.4, 1.4, -0.45, 0.45, 0.0, 40.0), muscles=(["quads"], ["glutes", "calves"]))
def cycling(p, s):
    floor(s, -1.4, 1.4)
    rear, front = vec(-0.52, 0.34, 0.0), vec(0.5, 0.34, 0.0)
    crank = vec(-0.02, 0.29, 0.0)
    saddle = vec(-0.24, 0.94, 0.0)
    bars = vec(0.42, 0.95, 0.0)
    for c in (rear, front):
        s.disc(c, Z, 0.34, "frame")
        s.disc(c, Z, 0.04, "metal")
    s.line([rear, crank, vec(-0.18, 0.86, 0), rear], 0.03, "metal")
    s.line([crank, vec(0.34, 0.86, 0), vec(-0.18, 0.86, 0)], 0.035, "metal")
    s.line([vec(0.34, 0.86, 0), front], 0.03, "metal")
    s.line([vec(0.34, 0.86, 0), bars], 0.03, "metal")
    s.line([bars - Z * 0.2, bars + Z * 0.2], 0.03, "metal")
    s.line([saddle - X * 0.1, saddle + X * 0.12], 0.05, "load")
    s.line([vec(-0.18, 0.86, 0), saddle], 0.03, "metal")
    crank_parts(s, crank, p)
    pelvis = Frame(saddle + Y * (Body.W_THIGH / 2 + 0.02), X, Y).pitched(52.0)
    body = Body(pelvis, spine=8.0, head=-28)
    pedal_legs(body, crank, p)
    for side in (1, -1):
        body.arm(side, bars + Z * side * 0.19, unit(-Y * 0.5 + X * 0.0 - X + Z * side * 0.2))
    show(s, body)


@demo("spinning", views=[PROFILE(), THREE_QUARTER(35, 12)], mode="loop", timing=0.7, samples=24, labels=(),
      muscles=(["quads"], ["glutes", "calves"]))
def spinning(p, s):
    floor(s, -0.9, 1.0)
    crank = vec(0.0, 0.3, 0.0)
    saddle = vec(-0.22, 0.92, 0.0)
    bars = vec(0.42, 1.05, 0.0)
    fly = vec(0.45, 0.32, 0.0)
    s.disc(fly, Z, 0.25, "load")
    s.line([vec(-0.55, 0.04, 0), vec(0.7, 0.04, 0)], TUBE, "frame")
    foot_bar(s, -0.5, half=0.3)
    foot_bar(s, 0.65, half=0.3)
    s.line([vec(-0.35, 0.04, 0), saddle - Y * 0.03], TUBE * 1.3, "frame")
    s.line([vec(0.55, 0.04, 0), vec(0.38, 1.0, 0)], TUBE * 1.3, "frame")
    s.line([vec(0.38, 1.0, 0), bars], TUBE, "frame")
    s.line([bars - Z * 0.22, bars + Z * 0.22], 0.035, "metal")
    s.line([crank, vec(0.46, 0.75, 0)], TUBE, "frame")
    s.line([saddle - X * 0.1, saddle + X * 0.12], 0.06, "load")
    crank_parts(s, crank, p)
    pelvis = Frame(saddle + Y * (Body.W_THIGH / 2 + 0.02), X, Y).pitched(35.0)
    body = Body(pelvis, spine=6.0, head=-18)
    pedal_legs(body, crank, p)
    for side in (1, -1):
        body.arm(side, bars + Z * side * 0.2, unit(-Y - X * 0.5 + Z * side * 0.3))
    show(s, body)


# --- Rower -----------------------------------------------------------------------------------------------

def rower_phase(p):
    """Leg drive, then back swing, then arm pull; recovery in reverse order, twice as long."""
    if p < 0.35:
        t = p / 0.35
        legs = smooth(t / 0.55)
        back = smooth((t - 0.3) / 0.45)
        arms = smooth((t - 0.6) / 0.4)
    else:
        t = (p - 0.35) / 0.65
        arms = 1 - smooth(t / 0.3)
        back = 1 - smooth((t - 0.2) / 0.3)
        legs = 1 - smooth((t - 0.4) / 0.6)
    return legs, back, arms


@demo("rowing-machine", views=[PROFILE(), THREE_QUARTER(35, 12)], mode="loop", timing=2.4, samples=32,
      labels=("Jambes", "Buste", "Bras", "Retour : bras, buste, jambes"),
      segments=[(0.32, 0.0, 0.12, 0, 0), (0.28, 0.12, 0.24, 1, 0), (0.24, 0.24, 0.35, 2, 0), (1.56, 0.35, 1.0, 3, 0)],
      muscles=(["quads", "back"], ["glutes", "hamstrings", "biceps"]))
def rowing_machine(p, s):
    floor(s, -1.4, 1.3)
    rail_y = 0.32
    foot = vec(0.7, 0.32, 0.0)
    legs, back, arms = rower_phase(p)
    s.line([vec(-1.2, rail_y - 0.04, 0), vec(0.9, rail_y - 0.04, 0)], 0.05, "metal")
    s.line([vec(-1.2, rail_y - 0.04, 0), vec(-1.2, 0.03, 0)], TUBE, "frame")
    foot_bar(s, -1.2, half=0.25)
    s.line([vec(1.0, 0.03, 0), vec(1.0, 0.42, 0)], TUBE * 1.3, "frame")
    s.disc(vec(1.05, 0.5, 0.0), Z, 0.24, "load")
    foot_bar(s, 1.0, half=0.3)
    s.slab(foot + vec(0.08, -0.15, 0), foot + vec(0.12, 0.2, 0), unit(vec(-1.0, 0.25, 0)), 0.36, 0.03, "frame")
    # Seat position: from the catch (close to the feet) to the finish (legs straight).
    for side in (1, -1):
        ankle = foot + vec(0.0, 0.0, side * 0.11)
    seat_x = lerp(0.16, -0.26, legs)
    seat = vec(seat_x, rail_y + 0.04, 0.0)
    s.slab(seat - X * 0.16, seat + X * 0.16, Y, 0.3, 0.05, "pad", solid="le siège")
    lean = lerp(24.0, -22.0, back)
    pelvis = Frame(seat + Y * (Body.W_THIGH / 2 + 0.006), X, Y).pitched(lean)
    body = Body(pelvis, head=-lean * 0.3)
    for side in (1, -1):
        ankle = foot + vec(-0.08, 0.06, side * 0.11)
        body.leg(side, ankle, pole=Y)
        body.toe[side] = ankle + unit(vec(0.25, 0.97, 0)) * 0.17
    sh = mid(body)
    reach = vec(sh[0] + 0.6, sh[1] - 0.12, 0.0)
    ribs = body.chest.at(u=0.12, f=Body.W_TORSO / 2 + 0.06)
    ribs[2] = 0.0
    straight = sh + unit(vec(0.97, -0.25, 0.0)) * 0.62
    handle = lerp(straight, ribs, arms)
    for side in (1, -1):
        body.arm(side, handle + Z * side * 0.13, unit(-X + Z * side * 0.6 - Y * 0.2))
    s.line([handle - Z * 0.2, handle + Z * 0.2], 0.035, "load")
    s.line([handle, vec(0.95, 0.55, 0.0)], 0.012, "cable")
    s.allow = {"le siège"}
    show(s, body)


# --- Elliptical, stepper ------------------------------------------------------------------------------------

@demo("elliptical", views=[PROFILE(), THREE_QUARTER(35, 12)], mode="loop", timing=1.3, samples=24, labels=(),
      muscles=(["quads", "glutes"], ["calves", "hamstrings"]))
def elliptical(p, s):
    floor(s, -1.1, 1.2)
    center = vec(0.0, 0.3, 0.0)
    body = upright(1.14, 6.0, pelvis_x=-0.02, head=0)
    for side, offset in ((1, 0.0), (-1, 0.5)):
        a = 2 * math.pi * (p + offset)
        pedal = center + vec(0.24 * math.cos(a), 0.1 * math.sin(a), side * 0.12)
        sd = SIDE_RIGHT if side == 1 else SIDE_LEFT
        s.line([pedal - X * 0.17, pedal + X * 0.17], 0.045, "load", side=sd)
        s.line([pedal + X * 0.17, vec(0.75, 0.42, side * 0.12)], TUBE, "frame", side=sd)
        ankle = pedal + vec(-0.04, Body.ANKLE - 0.01, 0.0)
        body.leg(side, ankle, pole=X)
        body.toe[side] = ankle + X * 0.165 - Y * 0.06
        # Moving handle: swings opposite to the foot on the same side.
        swing = math.cos(a + math.pi)
        top = vec(0.5, 1.68, side * 0.3)
        grip = vec(0.3 + 0.08 * swing, 1.3 - 0.02 * swing, side * 0.3)
        s.line([vec(0.72, 0.6, side * 0.3), grip, top], TUBE * 1.1, "frame", side=sd)
        body.arm(side, grip, unit(-Y - X + Z * side * 0.3))
    s.line([vec(-0.6, 0.03, 0), vec(1.0, 0.03, 0)], TUBE, "frame")
    s.disc(vec(-0.55, 0.32, 0.0), Z, 0.22, "load")
    s.line([vec(0.75, 0.03, 0), vec(0.72, 1.3, 0)], TUBE * 1.3, "frame")
    s.slab(vec(0.66, 1.32, 0), vec(0.82, 1.42, 0), unit(vec(-0.5, 1, 0)), 0.4, 0.05, "load")
    show(s, body)


@demo("stair-climber", views=[PROFILE(), THREE_QUARTER(35, 12)], mode="loop", timing=1.4, samples=24, labels=(),
      muscles=(["glutes", "quads"], ["calves"]))
def stair_climber(p, s):
    floor(s, -0.9, 1.2)
    pivot_x = 0.55
    hip = 1.06
    body = upright(hip + 0.02 * math.sin(4 * math.pi * p), 8.0, pelvis_x=0.0, head=-4)
    for side, offset in ((1, 0.0), (-1, 0.5)):
        h = 0.22 + 0.1 * math.cos(2 * math.pi * (p + offset))   # pedal height: high then pushed down
        pedal = vec(0.08, h, side * 0.12)
        sd = SIDE_RIGHT if side == 1 else SIDE_LEFT
        s.line([pedal - X * 0.16, pedal + X * 0.14], 0.05, "load", side=sd)
        s.line([pedal + X * 0.14, vec(pivot_x, 0.25, side * 0.12)], TUBE, "frame", side=sd)
        ankle = pedal + vec(-0.05, Body.ANKLE - 0.0, 0.0)
        body.leg(side, ankle, pole=X)
        body.toe[side] = ankle + X * 0.165 - Y * 0.06
        body.arm(side, vec(0.36, 1.12, side * 0.3), unit(-Y - X + Z * side * 0.3))
        s.line([vec(pivot_x, 0.03, side * 0.3), vec(pivot_x, 1.1, side * 0.3), vec(0.3, 1.08, side * 0.3)], TUBE, "frame", side=sd)
    s.line([vec(-0.3, 0.03, 0), vec(pivot_x + 0.2, 0.03, 0)], TUBE, "frame")
    s.disc(vec(pivot_x, 0.25, 0.0), Z, 0.05, "frame")
    s.slab(vec(pivot_x - 0.05, 1.25, 0), vec(pivot_x + 0.1, 1.35, 0), unit(vec(-0.5, 1, 0)), 0.4, 0.05, "load")
    s.line([vec(pivot_x, 1.1, 0), vec(pivot_x, 1.27, 0)], TUBE, "frame")
    show(s, body)


# --- Jumps -----------------------------------------------------------------------------------------------

@demo("jump-rope", views=[PROFILE(), THREE_QUARTER(35, 10)], mode="loop", timing=0.55, samples=24, labels=(),
      muscles=(["calves"], ["shoulders", "quads"]))
def jump_rope(p, s):
    floor(s, -1.0, 1.0)
    angle = 2 * math.pi * p - math.pi / 2         # the rope under the feet at p = 0
    hop = 0.06 * max(0.0, math.sin(2 * math.pi * p + math.pi * 0.0)) if False else 0.06 * (0.5 - 0.5 * math.cos(2 * math.pi * p)) * 0
    air = 0.06 * math.sin(math.pi * ((p + 0.25) % 1.0)) ** 2 if ((p + 0.25) % 1.0) < 0.5 else 0.0
    # In the air while the rope passes under the feet.
    lift = 0.07 * smooth(1 - abs(((p + 0.5) % 1.0) - 0.5) * 4) if abs(((p + 0.5) % 1.0) - 0.5) < 0.25 else 0.0
    lift = 0.07 * max(0.0, math.cos(2 * math.pi * p)) ** 2
    body = upright(0.94 + lift, 1.0, pelvis_x=0.0, head=0)
    for side in (1, -1):
        toe = vec(0.12, 0.02 + lift, side * 0.1)
        ankle = toe + rotate(-X * 0.165 + Y * 0.06, Z, -20 - 10 * lift / 0.07)
        body.leg(side, ankle, pole=X)
        body.toe[side] = toe
    hands_y = 0.95 + lift
    for side in (1, -1):
        sh = body.shoulder[side]
        body.arm(side, vec(0.12, hands_y, side * 0.28), unit(-X + Z * side * 0.3 - Y * 0.4))
    # The rope turns around the line between the hands, reaching under the feet and over the head.
    pts = []
    n = 14
    for i in range(n + 1):
        u = i / n
        z = lerp(-0.28, 0.28, u)
        r = 1.0 * math.sin(math.pi * u) ** 0.7 + 0.02
        pts.append(vec(0.12 + r * math.cos(angle) * 0.55, hands_y + r * math.sin(angle), z))
    pts[0] = body.grip[-1]
    pts[-1] = body.grip[1]
    s.line(pts, 0.016, "load")
    s.ground = True
    show(s, body)


@demo("jumping-jacks", views=[FRONT(6), THREE_QUARTER(35, 10)], mode="loop", timing=0.9, samples=24, labels=(),
      muscles=(["calves", "shoulders"], ["glutes", "quads"]))
def jumping_jacks(p, s):
    floor(s, -0.6, 0.6, -0.8, 0.8)
    open_ = 0.5 - 0.5 * math.cos(2 * math.pi * p)
    lift = 0.06 * abs(math.sin(2 * math.pi * p))
    body = upright(0.94 + lift - 0.05 * open_, 0.0, pelvis_x=0.0, head=0)
    for side in (1, -1):
        toe = vec(0.12, 0.02 + lift, side * lerp(0.1, 0.42, open_))
        ankle = toe + vec(-0.165, 0.06 + lift * 0.5, 0.0)
        body.leg(side, ankle, pole=X)
        body.toe[side] = toe
        angle = lerp(8.0, 165.0, open_)
        d = unit(-Y * math.cos(math.radians(angle)) + Z * side * math.sin(math.radians(angle)) + X * 0.05)
        body.arm(side, body.shoulder[side] + d * 0.62, unit(-X))
    show(s, body)


def jump_squat_body(t):
    """One squat jump over t in [0, 1): down, explode up, flight, landing."""
    from ex_legs import squat_body
    if t < 0.35:
        depth = smooth(t / 0.35)
        body = squat_body(depth * 0.85, 2.0, 32.0, 0.52, head=-6)
        arms = depth
        air = 0.0
    elif t < 0.5:
        depth = 0.85 * (1 - smooth((t - 0.35) / 0.15))
        body = squat_body(depth, 2.0, 32.0, 0.52, head=-6)
        arms = depth
        air = 0.0
    else:
        u = (t - 0.5) / 0.5
        air = 0.32 * math.sin(math.pi * min(1.0, u / 0.7)) if u < 0.7 else 0.0
        depth = 0.0 if u < 0.7 else 0.4 * math.sin(math.pi * (u - 0.7) / 0.3)
        body = squat_body(depth, 2.0, 32.0, 0.52, head=-6)
        arms = 0.0
        if air > 0:
            pelvis = body.pelvis
            body = upright(pelvis.o[1] + air, 1.0, pelvis_x=pelvis.o[0], head=-4)
            for side in (1, -1):
                ankle = vec(-0.03, Body.ANKLE + air + 0.012, side * 0.13)     # legs long, toes pointed
                body.leg(side, ankle, pole=X)
                body.toe[side] = ankle + rotate(X * 0.165 - Y * 0.06, Z, -35)
    for side in (1, -1):
        sh = body.shoulder[side]
        a = lerp(-80.0, -150.0, arms) if air == 0 else 60.0 * math.sin(math.pi * min(1.0, max(0.0, (t - 0.5) / 0.35)))
        if air == 0 and t >= 0.5:
            a = -80.0
        d = vec(math.cos(math.radians(a)), math.sin(math.radians(a)), side * 0.08)
        body.arm(side, sh + unit(d) * 0.6, unit(-Y + Z * side * 0.3))
    return body


@demo("jump-squat", views=[PROFILE(), THREE_QUARTER(35, 10)], mode="loop", samples=36,
      labels=("Descente en squat", "Poussée explosive", "En l'air", "Réception souple"),
      segments=[(0.6, 0.0, 0.35, 0, 1), (0.25, 0.35, 0.5, 1, 1), (0.45, 0.5, 0.85, 2, 0), (0.35, 0.85, 1.0, 3, 1)])
def jump_squat(p, s):
    floor(s, -0.9, 0.9)
    show(s, jump_squat_body(p))


@demo("box-jump", views=[PROFILE(), THREE_QUARTER(35, 12)], mode="loop", samples=40,
      labels=("Devant la boîte", "Élan, bras en arrière", "Saut", "Réception sur la boîte", "Debout sur la boîte", "Descente en marchant"),
      segments=[(0.4, 0.0, 0.0, 0, 1), (0.5, 0.0, 0.15, 1, 1), (0.35, 0.15, 0.3, 2, 1), (0.35, 0.3, 0.45, 3, 1),
                (0.6, 0.45, 0.6, 4, 1), (1.4, 0.6, 1.0, 5, 1)],
      muscles=(["quads", "glutes"], ["calves", "hamstrings"]))
def box_jump(p, s):
    floor(s, -0.9, 1.3)
    box_top = 0.6
    s.box(vec(0.78, box_top / 2, 0.0), X * 0.3, Y * box_top / 2, Z * 0.38, "pad", stroke=0.012, solid="la boîte")

    def stand_at(x, y, lean=0.0, hip_drop=0.0, head=0.0):
        return {"pelvis": vec(x, y + 0.945 - hip_drop, 0.0), "lean": lean, "head": head,
                "arms": {1: (vec(x + 0.04, y + 0.86 - hip_drop, 0.2), -X), -1: (vec(x + 0.04, y + 0.86 - hip_drop, -0.2), -X)},
                "legs": {sd: (vec(x - 0.04, y + Body.ANKLE, sd * 0.12), X, vec(x + 0.125, y + 0.02, sd * 0.12)) for sd in (1, -1)}}

    k0 = stand_at(0.0, 0.0)
    k1 = stand_at(-0.08, 0.0, lean=35.0, hip_drop=0.3, head=-10)
    k1["arms"] = {1: (vec(-0.32, 0.8, 0.22), -X), -1: (vec(-0.32, 0.8, -0.22), -X)}
    k2 = stand_at(0.45, 0.45, lean=25.0, hip_drop=0.25, head=-10)
    k2["legs"] = {sd: (vec(0.58, 0.7, sd * 0.12), X, vec(0.71, 0.62, sd * 0.12)) for sd in (1, -1)}
    k2["arms"] = {1: (vec(0.78, 1.5, 0.22), -X), -1: (vec(0.78, 1.5, -0.22), -X)}
    k3 = stand_at(0.66, box_top, lean=30.0, hip_drop=0.3, head=-10)
    k3["arms"] = {1: (vec(1.08, box_top + 0.95, 0.22), -X), -1: (vec(1.08, box_top + 0.95, -0.22), -X)}
    k4 = stand_at(0.74, box_top)
    # Step down: the left foot first, then the right.
    k5 = stand_at(0.28, 0.0, lean=14.0, hip_drop=0.04)
    k5["legs"] = {1: (vec(0.62, box_top + Body.ANKLE, 0.12), X, vec(0.785, box_top + 0.02, 0.12)),
                  -1: (vec(0.0, Body.ANKLE, -0.12), X, vec(0.165, 0.02, -0.12))}
    keys = [(0.0, k0), (0.15, k1), (0.3, k2), (0.45, k3), (0.6, k4), (0.8, k5), (1.0, k0)]
    params = keyed(p, keys)
    # In the air the feet tuck up over the front edge of the box.
    if 0.15 < p < 0.3:
        t = (p - 0.15) / 0.15
        tuck = Y * 0.3 * math.sin(math.pi * t)
        params = dict(params)
        params["legs"] = {sd: (a + tuck, pole, toe + tuck) for sd, (a, pole, toe) in params["legs"].items()}
    # Feet stepping down travel over the edge of the box, not through it.
    for a, b, side in ((0.6, 0.8, -1), (0.8, 1.0, 1)):
        if a < p < b:
            t = (p - a) / (b - a)
            lift = vec(-0.05, 0.24, 0.0) * math.sin(math.pi * min(1.0, t * 1.15))
            legs = dict(params["legs"])
            ankle, pole, toe = legs[side]
            legs[side] = (ankle + lift, pole, toe + lift)
            params = dict(params)
            params["legs"] = legs
    show(s, pose(params))


@demo("hiit", views=[PROFILE(), THREE_QUARTER(35, 10)], mode="loop", samples=48,
      labels=("Jumping jack", "Squat sauté", "Montées de genoux"),
      segments=[(1.2, 0.0, 1 / 3, 0, 0), (1.6, 1 / 3, 2 / 3, 1, 0), (1.2, 2 / 3, 1.0, 2, 0)],
      muscles=(["quads", "calves"], ["glutes", "shoulders"]))
def hiit(p, s):
    floor(s, -0.9, 0.9, -0.8, 0.8)
    if p < 1 / 3:
        t = (p * 3 * 2) % 1.0       # two jumping jacks
        open_ = 0.5 - 0.5 * math.cos(2 * math.pi * t)
        lift = 0.06 * abs(math.sin(2 * math.pi * t))
        body = upright(0.94 + lift - 0.05 * open_, 0.0, pelvis_x=0.0, head=0)
        for side in (1, -1):
            toe = vec(0.12, 0.02 + lift, side * lerp(0.1, 0.42, open_))
            ankle = toe + vec(-0.165, 0.06 + lift * 0.5, 0.0)
            body.leg(side, ankle, pole=X)
            body.toe[side] = toe
            angle = lerp(8.0, 165.0, open_)
            d = unit(-Y * math.cos(math.radians(angle)) + Z * side * math.sin(math.radians(angle)) + X * 0.05)
            body.arm(side, body.shoulder[side] + d * 0.62, unit(-X))
    elif p < 2 / 3:
        body = jump_squat_body((p - 1 / 3) * 3)
    else:
        t = ((p - 2 / 3) * 3 * 2) % 1.0
        body = upright(0.93 + 0.04 * abs(math.sin(2 * math.pi * t)), 2.0, pelvis_x=0.0, head=0)
        for side, offset in ((1, 0.0), (-1, 0.5)):
            tt = (t + offset) % 1.0
            up = math.sin(math.pi * tt / 0.6) if tt < 0.6 else 0.0
            if up < 0.02:
                body.foot_on_floor(side, (0.04, side * 0.11), 0.0, pole=X)
            else:
                body.leg_dirs(side, unit(lerp(vec(0, -1, 0), vec(1, 0.05, 0), up)), unit(lerp(vec(0, -1, 0), vec(-0.15, -1, 0), up)))
                body.foot_relaxed(side, plantar=25)
        for side, offset in ((1, 0.5), (-1, 0.0)):
            a = math.sin(2 * math.pi * (t + offset) + math.pi / 2)
            sh = body.shoulder[side]
            upper = unit(-Y + X * 0.6 * a)
            elbow = sh + upper * Body.UPPER
            body.arm(side, elbow + rotate(upper, Z, 95) * Body.LOWER, unit(-X))
    show(s, body)


# --- Swimming, boxing -----------------------------------------------------------------------------------

@demo("swimming", views=[PROFILE(), THREE_QUARTER(35, 18)], mode="loop", timing=1.6, samples=32, labels=(),
      travel=(1.6, 0.4, -1.4, 1.4, -0.02, 0.02, 0.62, 40.0), muscles=(["back", "shoulders"], ["triceps", "glutes"]))
def swimming(p, s):
    s.ground = False
    water = 0.62
    s.line([vec(-1.5, water, 0.0), vec(1.5, water, 0.0)], 0.012, "cable", bias=5.0)
    roll = 35.0 * math.sin(2 * math.pi * p)
    pelvis = Frame(vec(-0.35, water - 0.06, 0.0), -Y, X).rolled(roll)
    body = Body(pelvis, head=-10, head_turn=0)
    for side, offset in ((1, 0.0), (-1, 0.5)):
        a = 2 * math.pi * (p + offset)
        sh = body.shoulder[side]
        # The arm turns around the shoulder: reach forward, pull under the body, recover over the water.
        d = vec(math.cos(a), -math.sin(a) * 0.9, side * 0.08)
        bend = 0.6 if math.sin(a) < 0 else 0.0
        body.arm(side, sh + unit(d) * (0.6 - 0.12 * (1 if math.sin(a) > 0 else 0)), unit(Y * (1 if math.sin(a) < 0 else -1) - X * 0.3))
        kick = 0.08 * math.sin(2 * math.pi * (p * 3 + offset))
        ankle = body.hip[side] + vec(-0.86, kick, 0.0)
        body.leg(side, ankle, pole=-Y)
        body.foot_relaxed(side, plantar=60)
    show(s, body)


@demo("boxing", views=[THREE_QUARTER(35, 10), PROFILE()], mode="loop", samples=36,
      labels=("Garde", "Direct du bras avant", "Garde", "Direct du bras arrière"),
      segments=[(0.4, 0.0, 0.0, 0, 1), (0.35, 0.0, 0.5, 1, 1), (0.4, 0.5, 0.5, 2, 1), (0.4, 0.5, 1.0, 3, 1)],
      muscles=(["shoulders", "triceps"], ["obliques", "chest"]))
def boxing(p, s):
    floor(s, -0.9, 1.3, -0.7, 0.7)
    bag = vec(0.78, 0.0, -0.04)
    s.line([bag + Y * 0.62, bag + Y * 1.55], 0.36, "pad")
    s.line([bag + Y * 1.55, bag + Y * 2.3], 0.012, "cable")
    jab = math.sin(math.pi * min(1.0, p / 0.5)) if p < 0.5 else 0.0
    cross = math.sin(math.pi * (p - 0.5) / 0.5) if p >= 0.5 else 0.0
    twist = 8.0 - 38.0 * cross + 6.0 * jab
    body = upright(0.9, 6.0, pelvis_x=-0.02, facing=0.0, twist=twist, head=0)
    # Stance: left foot forward, right foot back, knees soft.
    body.foot_on_floor(-1, (0.2, -0.14), -15.0, pole=X)
    body.foot_on_floor(1, (-0.25, 0.16), 25.0, pole=X)
    if cross > 0.05:
        body.toe[1] = body.ankle[1] + rotate(X * 0.165 - Y * 0.06, Z, -25 * cross)
    chin = body.head + body.head_frame.f * 0.12 - Y * 0.08
    for side, amount in ((-1, jab), (1, cross)):
        guard = chin + body.chest.r * side * 0.1 - body.chest.f * 0.02
        target = vec(bag[0] - 0.2, body.shoulder[side][1] + 0.02, bag[2] + side * 0.03)
        grip = lerp(guard, target, smooth(amount))
        d = grip - body.shoulder[side]
        reach = Body.UPPER + Body.LOWER - 0.004
        if np.linalg.norm(d) > reach:      # a full punch: the arm extends as far as it goes
            grip = body.shoulder[side] + d * (reach / np.linalg.norm(d))
        body.arm(side, grip, unit(-Y + body.chest.r * side * 0.5))
        s.ball(grip + unit(grip - body.elbow[side]) * 0.03, 0.06, "muscle2" if False else "load",
               side=SIDE_RIGHT if side == 1 else SIDE_LEFT)
    show(s, body)
