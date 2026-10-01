"""Cyclic movements: walking, running, high knees. The figure stays in place and the ground passes
under it (marks on the floor scroll at the same speed as the feet in contact)."""
import math

import numpy as np

from engine import Body, Frame, X, Y, Z, heading, lerp, posture, rotate, unit, vec
from poses import upright


def smooth(t):
    t = min(1.0, max(0.0, t))
    return t * t * (3 - 2 * t)


def foot_path(phase, stance, stride, lift, ground=0.0, ahead=0.0, kick=0.0):
    """Ankle (x, y) for one foot over a cycle: on the ground moving back during the stance, then
    swinging forward through the air. Returns (x, y, in_contact, swing_progress)."""
    phase %= 1.0
    half = stride * stance          # distance the ground moves under the foot during the stance
    if phase < stance:
        t = phase / stance
        return ahead + half - 2 * half * t, ground + Body.ANKLE, True, 0.0
    t = (phase - stance) / (1 - stance)
    s = smooth(t)
    x = ahead - half + 2 * half * s - kick * math.sin(math.pi * min(1.0, t * 1.6))
    y = ground + Body.ANKLE + lift * math.sin(math.pi * t) ** 1.2 + kick * 0.8 * math.sin(math.pi * min(1.0, t * 1.4))
    return x, y, False, t


def walk_cycle(p, s, stride=0.68, arms="swing", lean=3.0, bounce=0.025, stance=0.6, lift=0.11, ground=0.0,
               incline=0.0, run=False, hip=None, ahead=0.04):
    """One cycle of walking (two steps). stride: length of one step (the ground travels 2*stride per
    cycle). Arms: 'swing', 'carry' (hanging with loads), 'run' (bent, pumping), 'none'."""
    cycle = 2 * stride
    hip_y = (hip if hip is not None else 0.92) + ground
    # Two bounces per cycle: lowest at mid-stance of each foot... highest at mid-stance for walking.
    phase2 = (p * 2) % 1.0
    if run:
        dy = -bounce * math.cos(2 * math.pi * phase2)
    else:
        dy = bounce * math.cos(2 * math.pi * (phase2 - 0.3))
    body = upright(hip_y + dy, lean, pelvis_x=0.0, head=-lean * 0.5 + 2,
                   twist=6.0 * math.sin(2 * math.pi * p) * (1.6 if run else 1.0))
    for side, offset in ((1, 0.0), (-1, 0.5)):
        x, y, contact, t = foot_path(p + offset, stance, cycle * 0.5, lift, ground, ahead=ahead, kick=0.22 if run else 0.0)
        ankle = vec(x, y + incline * x, side * 0.1)
        slope = math.degrees(math.atan(incline))
        if contact:
            foot = rotate(X * 0.165 - Y * 0.06, Z, slope)      # flat on the (inclined) ground
        else:
            # Heel off first, toe pointing down after push-off, flat again before landing.
            pitch = lerp(35.0, 0.0, smooth(t * 1.4))
            foot = rotate(X * 0.165 - Y * 0.06, Z, slope - pitch)
            toe = ankle + foot
            surface = ground + incline * toe[0] + 0.02
            if toe[1] < surface:
                ankle = ankle + Y * (surface - toe[1])
        body.leg(side, ankle, pole=X)
        body.toe[side] = body.ankle[side] + foot
    for side, offset in ((1, 0.5), (-1, 0.0)):
        # Each arm swings with the opposite leg.
        a = math.sin(2 * math.pi * (p + offset) + math.pi / 2)
        sh = body.shoulder[side]
        if arms == "carry":
            grip = sh + vec(0.03 + 0.03 * a, -0.62, body.chest.r[2] * side * 0.1)
            body.arm(side, grip, unit(-X))
        elif arms == "run":
            upper = unit(-Y + X * 0.55 * a)
            elbow = sh + upper * Body.UPPER
            fore = rotate(upper, body.chest.r, 95 - 10 * a)
            body.arm(side, elbow + fore * Body.LOWER, unit(-X))
        elif arms == "swing":
            upper = unit(-Y + X * 0.35 * a)
            elbow = sh + upper * Body.UPPER
            fore = rotate(upper, body.chest.r, 18 + 12 * max(0.0, a))
            body.arm(side, elbow + fore * Body.LOWER + body.chest.r * side * 0.03, unit(-X))
    return body
