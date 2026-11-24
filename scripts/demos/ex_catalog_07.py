"""Catalog lot 07 (2026-11-23): standing stretches (biceps, upper back, neck, lateral), kettlebell sumo high pull, rope climb,
muscle-up, scapular pull-up, bent press, Cuban press, barbell press behind the neck."""
import math

import numpy as np

from demos import demo, show
from engine import (ABOVE, BACK, FRONT, PROFILE, THREE_QUARTER, Body, Frame, SIDE_LEFT, SIDE_RIGHT, View, X, Y, Z,
                    lerp, posture, rotate, unit, vec)
from ex_back import hanging_body, pull_station
from gear import TUBE, barbell, dumbbell, floor, kettlebell
from poses import placed, solve, stance, upright

STRETCH = ("Mise en place", "Entrée dans l'étirement", "Tiens 20 à 40 s en respirant", "Relâche doucement")


def smooth(t):
    t = min(1.0, max(0.0, t))
    return t * t * (3 - 2 * t)


def shoulder_mid(body):
    return (body.shoulder[1] + body.shoulder[-1]) / 2


def reach_to(body, side, target, pole, length=0.62):
    """Arm toward target, never farther than length (so the bones keep their size)."""
    sh = body.shoulder[side]
    d = np.asarray(target, dtype=float) - sh
    dist = float(np.linalg.norm(d))
    if dist > length:
        d = d * (length / dist)
    body.arm(side, sh + d, pole)


def tilt_head(body, deg):
    """Head leaned toward the right shoulder by deg (the neck stays where it is)."""
    body.head_frame = body.head_frame.rolled(deg)
    body.head = body.neck + body.head_frame.u * Body.NECK


# --- Stretches ------------------------------------------------------------------------------------

@demo("x-standing-biceps-stretch", views=[PROFILE(), THREE_QUARTER(-140, 10)], labels=STRETCH, timing=(0.8, 1.2, 3.0, 1.0),
      muscles=(["biceps"], ["chest", "shoulders"]))
def standing_biceps_stretch(p, s):
    floor(s, -0.8, 0.8, -0.7, 0.7)
    k = smooth(p)
    body = upright(0.945, lerp(0.0, 8.0, k), pelvis_x=0.0, head=lerp(0.0, 6.0, k))
    stance(body, 0.0, half_width=0.13)
    sh = shoulder_mid(body)
    # The hands, clasped behind the back, rise behind the body with the arms straight.
    low = body.pelvis.at(f=-0.13, u=-0.01)
    high = sh + vec(-0.46, -0.16, 0.0)
    clasp = lerp(low, high, k)
    for side in (1, -1):
        reach_to(body, side, clasp + Z * side * 0.035, unit(-Y * 0.5 + body.chest.r * side * 0.6 - X * 0.3), 0.625)
    show(s, body)


@demo("x-upper-back-stretch", views=[PROFILE(), THREE_QUARTER(40, 10)], labels=STRETCH, timing=(0.8, 1.2, 3.0, 1.0),
      muscles=(["back"], []))
def upper_back_stretch(p, s):
    floor(s, -0.8, 0.8, -0.7, 0.7)
    k = smooth(p)
    # The hips shift back a little and the upper back rounds while the hands push forward.
    body = upright(0.945, lerp(0.0, 14.0, k), pelvis_x=lerp(0.0, -0.06, k), head=lerp(0.0, 28.0, k), protract=lerp(0.0, 0.08, k))
    stance(body, 0.0, half_width=0.13)
    sh = shoulder_mid(body)
    hands = sh + vec(0.0, 0.0, 0.0) + X * lerp(0.4, 0.62, k) - Y * lerp(0.17, 0.06, k)
    for side in (1, -1):
        reach_to(body, side, hands + Z * side * 0.04, unit(-Y + body.chest.r * side * 0.5), 0.628)
    show(s, body)


@demo("x-side-neck-stretch", views=[FRONT(6), THREE_QUARTER(40, 8)], labels=STRETCH, timing=(0.8, 1.2, 3.0, 1.0),
      muscles=(["traps"], []))
def side_neck_stretch(p, s):
    floor(s, -0.7, 0.7, -0.7, 0.7)
    k = smooth(p)
    body = upright(0.945, 0.0, pelvis_x=0.0, head=0)
    stance(body, 0.0, half_width=0.13)
    tilt_head(body, lerp(0.0, 38.0, k))
    sh = body.shoulder
    # The left hand reaches over the head and rests on the side of it (it pulls gently).
    top = body.head - body.chest.r * 0.0
    hand = body.head + body.head_frame.u * 0.06 + body.head_frame.r * 0.07
    rest = sh[-1] - Y * 0.6 - body.chest.r * 0.02
    grab = smooth(min(1.0, p / 0.6))
    reach_to(body, -1, lerp(rest, hand, grab), unit(-body.chest.r * 1.0 + Y * 0.3), 0.628)
    body.arm(1, sh[1] - Y * 0.6 + body.chest.r * 0.02, unit(-X * 0.2))
    show(s, body)


@demo("x-standing-lateral-stretch", views=[FRONT(6), THREE_QUARTER(40, 8)], labels=STRETCH, timing=(0.8, 1.4, 3.0, 1.0),
      muscles=(["abs"], ["obliques"]))
def standing_lateral_stretch(p, s):
    floor(s, -0.7, 0.7, -0.8, 0.8)
    k = smooth(p)
    body = upright(0.935, 0.0, pelvis_x=0.0, bend=lerp(0.0, 32.0, k), head=0)
    stance(body, 0.0, half_width=0.2, toe_out=10.0)
    for side in (1, -1):
        body.leg(side, body.ankle[side], pole=X)
    # The right hand rests on the right hip; the left arm rises overhead and leans over with the trunk.
    body.arm(1, body.pelvis.at(u=0.09, r=0.19, f=0.0) + body.chest.r * 0.0, unit(body.chest.r * 1.0 - X * 0.2))
    rise = smooth(min(1.0, p / 0.5))
    side_pos = body.shoulder[-1] - Y * 0.6 - body.chest.r * 0.1
    top = body.shoulder[-1] + unit(body.chest.u * 0.9 + body.chest.r * 0.45) * 0.625
    reach_to(body, -1, lerp(side_pos, top, rise), unit(-body.chest.r * 0.6 - X * 0.3), 0.628)
    show(s, body)


# --- Kettlebell sumo high pull ------------------------------------------------------------------------

@demo("x-kettlebell-sumo-high-pull", views=[THREE_QUARTER(40, 10), PROFILE()],
      labels=("Kettlebell au sol entre les pieds", "Extension des hanches, coudes hauts", "Kettlebell au menton, coudes à l'extérieur",
              "Retour au sol"), timing=(0.7, 1.4, 0.5, 1.5))
def kettlebell_sumo_high_pull(p, s):
    floor(s, -0.9, 0.9, -0.9, 0.9)
    stand = smooth(min(1.0, p / 0.6))       # hips and knees extend first
    pull = smooth(max(0.0, (p - 0.45) / 0.55))   # then the elbows rise
    lean = lerp(34.0, 2.0, stand)
    hip_y = lerp(0.62, 0.89, stand)

    def make(px):
        return upright(hip_y, lean, pelvis_x=px, head=-lean * 0.4)

    # The hands hang over the bell at the start; at the end the bell is under the chin.
    def hand_x(px):
        return shoulder_mid(make(px))[0]

    px = solve(hand_x, -1.2, 1.0, lerp(0.02, 0.0, stand))
    body = make(px)
    stance(body, 0.0, half_width=0.36, toe_out=40.0, pole=None)
    hang = shoulder_mid(body) + vec(0.02, -0.6, 0.0)
    hang[1] = max(hang[1], 0.3)
    chin = body.chest.at(u=0.36, f=Body.D_TRUNK + 0.06)
    chin[2] = 0.0
    grip = lerp(hang, chin, pull)
    # Elbows go high and out: poles toward the sides and up while pulling.
    for side in (1, -1):
        body.arm(side, grip + Z * side * 0.05, unit(body.chest.r * side * 1.0 + Y * 0.9 * pull - Y * 0.2 * (1 - pull) - X * 0.2))
    down = unit(-Y * (1 - 0.4 * pull) - X * 0.2 * pull)
    kettlebell(s, grip, down, Z)
    show(s, body)


# --- Rope climb ---------------------------------------------------------------------------------------

@demo("x-rope-climb", views=[PROFILE(4), THREE_QUARTER(-40, 10)],
      labels=("Suspendu à la corde, bras tendus", "Tirage et genoux remontés", "Pieds pincent la corde, bras fléchis", "Descente contrôlée"),
      timing=(0.7, 1.6, 0.5, 1.7))
def rope_climb(p, s):
    floor(s, -0.9, 0.9, -0.8, 0.8)
    rope_x = 0.12
    beam_y = 2.7
    s.segs(vec(rope_x, beam_y, 0.0), vec(rope_x, 0.12, 0.0), 0.034, "metal", parts=8)
    s.line([vec(rope_x - 0.45, beam_y, 0.0), vec(rope_x + 0.45, beam_y, 0.0)], TUBE * 1.5, "frame")
    top_hand, low_hand = 2.28, 2.0
    k = smooth(p)
    # The shoulders rise with the pull; the upper hand holds the rope high, the lower one below it.
    sh = vec(lerp(-0.02, -0.03, k), lerp(1.72, 1.93, k), 0.0)
    frame = posture(vec(0, 0, 0), 0.0, lerp(-3.0, -8.0, k))
    body = placed(frame, "shoulders", sh, head=lerp(0.0, -6.0, k))
    for side in (1, -1):
        top = side == 1
        hand = vec(rope_x, top_hand if top else low_hand, side * 0.04)
        body.arm(side, hand, unit(-X * 0.1 + body.chest.r * side * 1.0 - Y * 0.5))
        # The knees come up while the feet pinch the rope.
        foot = vec(rope_x + 0.02, body.pelvis.o[1] - lerp(0.86, 0.55, k), side * 0.07)
        body.leg(side, foot, pole=X + body.pelvis.r * side * 0.5)
        body.foot_relaxed(side, plantar=lerp(25.0, 10.0, k))
    show(s, body)


# --- Muscle-up -----------------------------------------------------------------------------------------

@demo("x-muscle-up", views=[PROFILE(4), THREE_QUARTER(-40, 10)],
      labels=("Suspendu, prise en faux", "Traction explosive vers la barre", "Transition au-dessus de la barre",
              "Appui bras tendus au-dessus de la barre"), timing=(0.7, 2.0, 0.7, 2.0))
def muscle_up(p, s):
    floor(s, -0.9, 0.7, -0.8, 0.8)
    bar_y = 2.3
    pull_station(s, bar_y)
    grip_half = 0.22
    # Four key positions of the shoulders, the trunk lean and the elbow direction.
    keys = [
        (0.0, vec(-0.04, bar_y - 0.60, 0.0), -4.0, 35.0, -8.0, unit(-Y * 0.6 + X * -0.15)),
        (0.4, vec(-0.12, bar_y - 0.12, 0.0), -16.0, 55.0, -10.0, unit(-Y * 0.6 - X * 0.35)),
        (0.55, vec(-0.14, bar_y + 0.04, 0.0), 8.0, 58.0, 0.0, unit(-Y * 0.3 - X * 0.8)),
        # The chest rolls over the bar (folded at the hips), then the hips rest behind it, the shoulders ahead.
        (0.7, vec(0.0, bar_y + 0.18, 0.0), 45.0, 60.0, 12.0, unit(-X * 1.0 + Y * 0.2)),
        (1.0, vec(0.06, bar_y + 0.58, 0.0), 20.0, 20.0, 0.0, unit(-X * 0.7 - Y * 0.1)),
    ]
    for (p0, *a), (p1, *b) in zip(keys[:-1], keys[1:]):
        if p <= p1 + 1e-9:
            t = 0.0 if p1 == p0 else smooth((p - p0) / (p1 - p0))
            break
    sh = lerp(a[0], b[0], t)
    lean = lerp(a[1], b[1], t)
    knees = lerp(a[2], b[2], t)
    head = lerp(a[3], b[3], t)
    pole_dir = unit(lerp(a[4], b[4], t))
    body = hanging_body(sh, lean=lean, knees=knees, head=head)
    for side in (1, -1):
        grip = vec(0.0, bar_y, side * grip_half)
        body.arm(side, grip, unit(pole_dir + body.chest.r * side * 0.5))
    s.ground = True
    show(s, body)


# --- Scapular pull-up -----------------------------------------------------------------------------------

@demo("x-scapular-pull-up", views=[PROFILE(4), THREE_QUARTER(-40, 10)],
      labels=("Suspendu, épaules relâchées", "Abaisse les omoplates", "Corps remonté, bras tendus", "Relâche doucement"),
      timing=(0.8, 1.0, 0.8, 1.2))
def scapular_pull_up(p, s):
    floor(s, -0.9, 0.7, -0.8, 0.8)
    bar_y = 2.3
    pull_station(s, bar_y)
    k = smooth(p)
    # The arms stay straight: the shoulder joints do not move, the trunk rises as the shrug is released.
    sh = vec(-0.03, bar_y - 0.585, 0.0)
    body = hanging_body(sh, lean=-3.0, knees=20.0, shrug=lerp(0.07, -0.04, k), head=0.0)
    for side in (1, -1):
        body.arm(side, vec(0.0, bar_y, side * 0.4), unit(-X * 0.3 + body.chest.r * side))
    s.ground = True
    show(s, body)


# --- Bent press -----------------------------------------------------------------------------------------

@demo("x-bent-press", views=[FRONT(6), THREE_QUARTER(40, 8)],
      labels=("Kettlebell au rack, jambes écartées", "Flexion latérale sous la charge", "Bras tendu, tronc incliné sous le poids",
              "Redressement"), timing=(0.7, 1.8, 0.7, 1.8))
def bent_press(p, s):
    floor(s, -0.8, 0.8, -0.9, 0.9)
    k = smooth(p)
    # The trunk leans to the left (away from the bell) while the right arm rises straight up.
    body = upright(0.925, 0.0, pelvis_x=0.0, z=lerp(0.0, 0.07, k), bend=lerp(0.0, -34.0, k), head=0)
    stance(body, 0.0, half_width=0.22, toe_out=25.0)
    for side in (1, -1):
        body.leg(side, body.ankle[side], pole=X)
    sh = body.shoulder[1]
    rack = sh + X * 0.12 + Y * 0.02 - body.chest.r * 0.06
    top = sh + Y * 0.625
    grip = lerp(rack, top, smooth(min(1.0, p / 0.9)) ** 1.0)
    body.arm(1, grip, unit(-Y + X * lerp(1.0, 0.2, k) + body.chest.r * lerp(0.0, 0.5, k)))
    fore = unit(grip - body.elbow[1])
    kettlebell(s, grip, unit(-body.chest.f * 0.6 + body.chest.r * 0.4 - fore * 0.6), body.chest.r, side=SIDE_RIGHT)
    # The free hand slides down the left leg.
    hang = body.shoulder[-1] - Y * 0.6 - body.chest.r * 0.1
    knee_side = body.knee[-1] + Y * 0.05 + body.chest.r * -0.06
    reach_to(body, -1, lerp(hang, knee_side, k), unit(-body.chest.r * 0.8 - X * 0.2), 0.63)
    show(s, body)


# --- Cuban press ----------------------------------------------------------------------------------------

@demo("x-cuban-press", views=[FRONT(6), THREE_QUARTER(40, 8)],
      labels=("Haltères devant les cuisses", "Rowing, rotation externe, puis poussée", "Bras tendus au-dessus de la tête",
              "Retour en sens inverse"), timing=(0.7, 3.0, 0.6, 2.6))
def cuban_press(p, s):
    floor(s, -0.7, 0.8, -0.7, 0.7)
    body = upright(0.945, 0.0, shoulder_x=0.0, head=0)
    stance(body, 0.0, half_width=0.15)
    c = body.chest
    # Three stages: upright row, rotation of the forearms to the vertical, press overhead.
    keys = [
        (0.0, unit(-Y + X * 0.1), unit(-Y + X * 0.25)),
        (1 / 3, unit(c.r * 1.0 + Y * 0.35 + X * 0.1), unit(-c.r * 0.9 - Y * 0.5 + X * 0.25)),
        (2 / 3, unit(c.r * 1.0 + Y * 0.05 + X * 0.05), unit(Y * 1.0 + X * 0.1)),
        (1.0, unit(c.r * 0.28 + Y * 0.96), unit(Y * 1.0 + c.r * -0.05)),
    ]
    for (p0, ua, la), (p1, ub, lb) in zip(keys[:-1], keys[1:]):
        if p <= p1 + 1e-9:
            t = 0.0 if p1 == p0 else smooth((p - p0) / (p1 - p0))
            up0, lo0, up1, lo1 = ua, la, ub, lb
            break
    for side in (1, -1):
        mirror = lambda d: d - 2 * np.dot(d, c.r) * c.r if side == -1 else d
        upper = unit(lerp(mirror(up0), mirror(up1), t))
        lower = unit(lerp(mirror(lo0), mirror(lo1), t))
        body.arm_dirs(side, upper, lower)
        dumbbell(s, body.grip[side], c.r, side=SIDE_RIGHT if side == 1 else SIDE_LEFT)
    show(s, body)


# --- Barbell press behind the neck -----------------------------------------------------------------------

@demo("x-standing-barbell-press-behind-neck", views=[PROFILE(), THREE_QUARTER(-140, 10)],
      labels=("Barre derrière la nuque sur les trapèzes", "Poussée verticale", "Bras tendus au-dessus de la tête",
              "Descente derrière la nuque"), timing=(0.7, 1.2, 0.6, 1.6))
def press_behind_neck(p, s):
    floor(s, -0.75, 0.75)
    k = smooth(p)
    body = upright(0.95, 1.0, shoulder_x=0.0, head=lerp(10.0, 0.0, k))
    stance(body, 0.0, half_width=0.15)
    grip_half = 0.38
    mid = shoulder_mid(body)
    rest = body.chest.at(u=0.385, f=-(Body.D_TRUNK + 0.045))
    rest[2] = 0.0
    dz = grip_half - Body.SH_HALF
    top = mid + Y * math.sqrt(0.63 ** 2 - dz ** 2) - X * 0.02
    top[2] = 0.0
    bar = lerp(rest, top, p)
    # Once the bar clears the head it comes back over the crown.
    clear = body.head[1] + Body.HEAD + 0.03
    bar[0] = rest[0] if bar[1] <= clear else lerp(rest[0], top[0], smooth((bar[1] - clear) / max(top[1] - clear, 1e-6)))
    for side in (1, -1):
        body.arm(side, bar + Z * side * grip_half, unit(-Y + body.chest.r * side * 0.9 - X * 0.3))
    barbell(s, bar, Z, plate_r=0.2)
    show(s, body)
