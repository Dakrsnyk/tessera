"""Shoulders: presses (barbell, dumbbells, Arnold, machine, kettlebell), pike and handstand push-ups,
raises (lateral, cable, front), rear delt flyes, upright row."""
import math

import numpy as np

from demos import demo, show
from engine import (ABOVE, BACK, FRONT, PROFILE, THREE_QUARTER, Body, Frame, SIDE_LEFT, SIDE_RIGHT, View, X, Y, Z,
                    lerp, posture, rotate, unit, vec)
from gear import (PAD_T, PAD_W, TUBE, Column, adjustable_bench, barbell, cable, d_handle, dumbbell, floor, foot_bar,
                  kettlebell)
from machines import pec_deck_arm, pec_deck_frame, seat_with_back, stack
from poses import (feet_flat, on_backrest, placed, plank_on_toes, seated_upright, solve, stance, upright)

PRESS_UP = ("Charge aux épaules", "Poussée vers le haut", "Bras tendus au-dessus", "Descente contrôlée")


def shoulder_mid(body):
    return (body.shoulder[1] + body.shoulder[-1]) / 2


def overhead(body, grip_half, forward=0.0, reach=0.63):
    mid = shoulder_mid(body)
    dz = max(0.0, grip_half - Body.SH_HALF)
    return mid + Y * math.sqrt(reach ** 2 - dz ** 2 - forward ** 2) + X * forward


@demo("ohp", views=[PROFILE(), THREE_QUARTER(35, 10)],
      labels=("Barre sur le haut de la poitrine", "Poussée verticale", "Bras tendus, barre au-dessus de la tête", "Descente contrôlée"),
      timing=(0.7, 1.2, 0.6, 1.6))
def ohp(p, s):
    floor(s, -0.75, 0.75)
    # The head moves back while the bar passes the face, then forward under it.
    head = -14.0 * math.sin(math.pi * min(1.0, p * 1.6))
    body = upright(0.95, -2.0, shoulder_x=0.0, head=head)
    stance(body, 0.0, half_width=0.15)
    grip_half = 0.26
    rack = body.chest.at(u=0.36, f=Body.W_TORSO / 2 + 0.06)
    rack[2] = 0.0
    top = overhead(body, grip_half, forward=-0.02)
    top[2] = 0.0
    bar = lerp(rack, top, p)
    bar[0] = lerp(rack[0], top[0], min(1.0, p * 1.25))
    for side in (1, -1):
        body.arm(side, bar + Z * side * grip_half, unit(-Y + X * 0.7 + body.chest.r * side * 0.4))
    barbell(s, bar, Z, plate_r=0.2)
    show(s, body)


@demo("db-shoulder-press", views=[THREE_QUARTER(40, 10), FRONT(6)],
      labels=("Haltères à hauteur des oreilles", "Poussée", "Bras tendus au-dessus", "Descente contrôlée"),
      timing=(0.7, 1.2, 0.5, 1.6))
def db_shoulder_press(p, s):
    floor(s, -1.0, 0.95)
    J, d, n = adjustable_bench(s, 0.0, 82.0, back_len=0.78, seat_tilt=0.0)
    body = on_backrest(J, d, n, seat_y=0.45, head=2)
    feet_flat(body, (body.pelvis.o[0] + 0.48, 0.26), (body.pelvis.o[0] + 0.48, -0.26))
    for side in (1, -1):
        sh = body.shoulder[side]
        low = sh + body.chest.r * side * 0.2 + Y * 0.06 + body.chest.f * 0.06
        high = shoulder_mid(body) + body.chest.r * side * 0.16 + Y * 0.61 + body.chest.f * 0.03
        grip = lerp(low, high, p)
        body.arm(side, grip, unit(-Y + body.chest.r * side * 0.8 + body.chest.f * 0.3))
        dumbbell(s, grip, body.chest.r, side=SIDE_RIGHT if side == 1 else SIDE_LEFT)
    show(s, body)


@demo("arnold-press", views=[THREE_QUARTER(40, 8), FRONT(6)],
      labels=("Haltères devant, paumes vers toi", "Rotation et poussée", "Bras tendus, paumes vers l'avant", "Retour en rotation"),
      timing=(0.7, 1.6, 0.5, 1.8))
def arnold_press(p, s):
    floor(s, -0.7, 0.8, -0.7, 0.7)
    body = upright(0.95, -2.0, shoulder_x=0.0, head=0)
    stance(body, 0.0, half_width=0.15)
    open_ = min(1.0, p / 0.55)      # elbows go from in front to the sides first
    rise = max(0.0, (p - 0.25) / 0.75)
    for side in (1, -1):
        sh = body.shoulder[side]
        front = sh + X * 0.17 + Y * 0.12 - body.chest.r * side * 0.07
        side_pos = sh + body.chest.r * side * 0.18 + Y * 0.1 + X * 0.04
        low = lerp(front, side_pos, open_)
        high = shoulder_mid(body) + body.chest.r * side * 0.15 + Y * 0.6 + X * 0.02
        grip = lerp(low, high, rise * rise * (3 - 2 * rise))
        pole = unit(lerp(-Y + X * 0.9, -Y + body.chest.r * side * 0.9, open_))
        body.arm(side, grip, pole)
        dumbbell(s, grip, body.chest.r, side=SIDE_RIGHT if side == 1 else SIDE_LEFT)
    show(s, body)


@demo("machine-shoulder-press", views=[PROFILE(), THREE_QUARTER(40, 12)],
      labels=("Poignées à hauteur des épaules", "Poussée", "Bras tendus", "Descente contrôlée"), timing=(0.7, 1.2, 0.5, 1.6))
def machine_shoulder_press(p, s):
    floor(s, -1.0, 0.85)
    seat_y = 0.47
    junction, back_dir, normal = seat_with_back(s, -0.2, 0.2, seat_y, back_angle=8.0, back_len=0.8)
    body = on_backrest(junction, back_dir, normal, seat_y, head=2)
    feet_flat(body, (body.pelvis.o[0] + 0.5, 0.2), (body.pelvis.o[0] + 0.5, -0.2))
    # A carriage slides up two rails behind the backrest; its arms carry the handles.
    rail_x = junction[0] - 0.32
    rise = 0.42 * p
    mid = shoulder_mid(body)
    for side in (1, -1):
        sd = SIDE_RIGHT if side == 1 else SIDE_LEFT
        grip = mid + body.chest.r * side * 0.27 + Y * (0.08 + rise) + X * (0.06 + 0.05 * p)
        body.arm(side, grip, unit(-Y + body.chest.r * side * 0.8 + X * 0.2))
        z = side * 0.3
        carriage = vec(rail_x, grip[1] - 0.05, z)
        s.line([vec(rail_x, 0.03, z), vec(rail_x, 2.05, z)], TUBE * 1.2, "frame", side=sd)
        s.line([carriage, vec(grip[0], grip[1] - 0.05, z), grip + Z * side * 0.05], TUBE * 1.1, "frame", side=sd)
        s.line([grip + X * 0.07, grip - X * 0.07], 0.04, "load", side=sd)
    s.line([vec(rail_x, 2.05, -0.3), vec(rail_x, 2.05, 0.3)], TUBE, "frame")
    s.line([vec(rail_x - 0.3, 0.03, 0), vec(junction[0] + 0.45, 0.03, 0)], TUBE, "frame")
    s.line([vec(junction[0] + 0.05, seat_y - PAD_T, 0), vec(junction[0] + 0.05, 0.03, 0)], TUBE * 1.3, "frame")
    stack(s, rail_x - 0.25, 0.0, lift=rise * 0.35, height=2.05)
    show(s, body)


@demo("kb-press", views=[THREE_QUARTER(35, 8), FRONT(6)],
      labels=("Kettlebell à l'épaule", "Poussée", "Bras tendu au-dessus", "Retour à l'épaule"), timing=(0.7, 1.2, 0.6, 1.5))
def kb_press(p, s):
    floor(s, -0.7, 0.8, -0.7, 0.7)
    body = upright(0.95, -1.0, shoulder_x=0.0, bend=-3.0 * p, head=0)
    stance(body, 0.0, half_width=0.15)
    sh = body.shoulder[1]
    rack = sh + X * 0.12 + Y * 0.02 - body.chest.r * 0.06
    top = sh + Y * 0.62 + body.chest.r * 0.03
    grip = lerp(rack, top, p)
    body.arm(1, grip, unit(-Y + X * lerp(1.0, 0.2, p) + body.chest.r * lerp(0.0, 0.6, p)))
    # The bell rests on the back of the forearm.
    fore = unit(grip - body.elbow[1])
    down = unit(-fore * 0.35 + rotate(fore, body.chest.r, -90) * 0.0 - X * 0.6 + body.chest.r * 0.3)
    kettlebell(s, grip, unit(-body.chest.f * 0.6 + body.chest.r * 0.4 - fore * 0.6), body.chest.r, side=SIDE_RIGHT)
    left = body.shoulder[-1]
    body.arm(-1, left - Y * 0.6 - body.chest.r * 0.08, unit(-X))
    show(s, body)


@demo("pike-push-up", views=[PROFILE(), THREE_QUARTER(35, 14)],
      labels=("Hanches hautes, bras tendus", "Descente de la tête", "Tête près du sol", "Poussée"), timing=(0.6, 1.4, 0.4, 1.1))
def pike_push_up(p, s):
    floor(s, -0.4, 1.5)
    toe = vec(0.0, 0.02, 0.0)
    ankle = toe + vec(-0.07, 0.15, 0.0)
    hands = vec(1.0, 0.03, 0.0)
    legs = Body.SHIN + Body.THIGH
    torso = Body.LUMBAR + Body.THORAX - Body.SH_DROP
    s0 = vec(0.78, 0.6, 0.0)
    s1 = vec(1.05, 0.3, 0.0)
    sh = lerp(s0, s1, p)
    # Hip: on the circle of the straight legs around the ankle and at torso length from the shoulders.
    d = np.linalg.norm(sh - ankle)
    a = (legs ** 2 - torso ** 2 + d ** 2) / (2 * d)
    h = math.sqrt(max(0.0, legs ** 2 - a ** 2))
    base = ankle + (sh - ankle) * (a / d)
    perp = unit(vec(-(sh - ankle)[1], (sh - ankle)[0], 0.0))
    hip = base + perp * h
    if hip[1] < base[1]:
        hip = base - perp * h
    u = unit(sh - hip)
    f = vec(u[1], -u[0], 0.0)
    body = Body(Frame(hip, f, u), head=-30)
    ldir = unit(hip - ankle)
    for side in (1, -1):
        body.leg_dirs(side, -ldir, -ldir)
        body.foot_toward(side, body.ankle[side] + (toe - ankle))
        body.arm(side, hands + body.chest.r * side * 0.27, unit(-u * 0.6 + body.chest.r * side * 0.7))
    show(s, body)


@demo("handstand-push-up", views=[PROFILE(4), THREE_QUARTER(35, 10)],
      labels=("En équilibre contre le mur", "Descente de la tête", "Tête près du sol", "Poussée"), timing=(0.7, 1.6, 0.4, 1.3))
def handstand_push_up(p, s):
    floor(s, -0.55, 0.8)
    wall_x = -0.32
    s.poly([vec(wall_x, 0.0, -0.8), vec(wall_x, 2.5, -0.8), vec(wall_x, 2.5, 0.8), vec(wall_x, 0.0, 0.8)], "floor", 0.0, bias=20.0)
    s.slab(vec(0.05, 0.03, 0), vec(0.45, 0.03, 0), Y, 0.5, 0.03, "pad", solid="le tapis")
    # Upside down: head toward the floor, heels on the wall.
    lean = 8.0
    u = vec(math.sin(math.radians(lean)), -math.cos(math.radians(lean)), 0.0)
    f = vec(-u[1], u[0], 0.0)
    hands = 0.03
    top_sh = hands + 0.6
    bottom_sh = hands + 0.27
    sh_y = lerp(top_sh, bottom_sh, p)
    body = placed(Frame(vec(0, 0, 0), f, u), "shoulders", vec(0.1, sh_y, 0.0), head=-25)
    for side in (1, -1):
        hip = body.hip[side]
        foot = vec(wall_x + 0.06, hip[1] + 0.8, hip[2])
        body.leg(side, foot, pole=X)
        body.foot_toward(side, body.ankle[side] + vec(0.0, 0.17, 0.0))
        body.arm(side, vec(0.18, hands + 0.03, 0.0) + body.chest.r * side * 0.28, unit(X * 0.8 + body.chest.r * side * 0.6))
    show(s, body)


# --- Raises -------------------------------------------------------------------------------------

@demo("lateral-raise", views=[FRONT(6), THREE_QUARTER(40, 10)],
      labels=("Haltères le long du corps", "Élévation sur les côtés", "Bras à hauteur des épaules", "Descente lente"),
      timing=(0.7, 1.2, 0.5, 1.7))
def lateral_raise(p, s):
    floor(s, -0.7, 0.7, -0.8, 0.8)
    body = upright(0.94, 6.0, shoulder_x=0.0, head=0)
    stance(body, 0.0, half_width=0.14)
    angle = lerp(8.0, 86.0, p)
    for side in (1, -1):
        sh = body.shoulder[side]
        d = unit(-Y * math.cos(math.radians(angle)) + body.chest.r * side * math.sin(math.radians(angle)) + X * 0.18)
        grip = sh + d * 0.6
        body.arm(side, grip, unit(-Y * 0.3 - X * 1.0 + body.chest.r * side * 0.2))
        dumbbell(s, grip, X, side=SIDE_RIGHT if side == 1 else SIDE_LEFT)
    show(s, body)


@demo("cable-lateral", views=[FRONT(6), THREE_QUARTER(40, 10)],
      labels=("Poignée devant la hanche opposée", "Élévation sur le côté", "Bras à hauteur de l'épaule", "Descente lente"),
      timing=(0.7, 1.2, 0.5, 1.7))
def cable_lateral(p, s):
    floor(s, -0.7, 0.7, -1.1, 0.8)
    body = upright(0.94, 4.0, shoulder_x=0.0, bend=lerp(0.0, -4.0, p), head=0)
    stance(body, 0.0, half_width=0.14)
    pul = vec(0.02, 0.18, -0.68)
    sh = body.shoulder[1]
    angle = lerp(-12.0, 84.0, p)
    d = unit(-Y * math.cos(math.radians(angle)) + body.chest.r * math.sin(math.radians(angle)) + X * 0.16)
    grip = sh + d * 0.6
    body.arm(1, grip, unit(-X + body.chest.r * 0.2))
    left = body.shoulder[-1]
    body.arm(-1, vec(0.05, 1.18, -0.69), unit(-Y - X * 0.3))
    col = Column(s, 0.02, -0.82, height=2.15, depth=0.24, width=0.24)
    g0 = sh + unit(-Y * math.cos(math.radians(-12)) + body.chest.r * math.sin(math.radians(-12)) + X * 0.16) * 0.6
    col.frame(lift=np.linalg.norm(grip - pul) - np.linalg.norm(g0 - pul))
    s.disc(pul, X, 0.045, "frame")
    cable(s, pul, grip)
    d_handle(s, grip, X, side=SIDE_RIGHT)
    show(s, body)


@demo("front-raise", views=[PROFILE(), THREE_QUARTER(35, 10)],
      labels=("Haltères devant les cuisses", "Élévation devant", "Bras à hauteur des épaules", "Descente lente"),
      timing=(0.7, 1.2, 0.5, 1.7))
def front_raise(p, s):
    floor(s, -0.6, 1.0)
    body = upright(0.94, -2.0, shoulder_x=0.0, head=0)
    stance(body, 0.0, half_width=0.14)
    angle = lerp(-80.0, 0.0, p)
    for side in (1, -1):
        sh = body.shoulder[side]
        d = unit(X * math.cos(math.radians(angle)) + Y * math.sin(math.radians(angle)) - body.chest.r * side * 0.05)
        grip = sh + d * 0.61
        body.arm(side, grip, unit(-Y * 0.3 - body.chest.r * side + X * 0.1))
        dumbbell(s, grip, body.chest.r, side=SIDE_RIGHT if side == 1 else SIDE_LEFT)
    show(s, body)


@demo("rear-delt-fly", views=[FRONT(14), THREE_QUARTER(45, 16)],
      labels=("Buste penché, haltères sous les épaules", "Ouverture sur les côtés", "Bras à l'horizontale", "Descente lente"),
      timing=(0.7, 1.2, 0.5, 1.6))
def rear_delt_fly(p, s):
    floor(s, -0.8, 0.8, -0.85, 0.85)
    body = upright(0.82, 72.0, shoulder_x=0.12, head=-30)
    stance(body, 0.0, half_width=0.15)
    angle = lerp(6.0, 82.0, p)
    for side in (1, -1):
        sh = body.shoulder[side]
        d = unit(-Y * math.cos(math.radians(angle)) + body.chest.r * side * math.sin(math.radians(angle)))
        grip = sh + d * 0.6
        body.arm(side, grip, unit(Y * 0.6 - X * 0.2 + body.chest.r * side * 0.1))
        dumbbell(s, grip, X, side=SIDE_RIGHT if side == 1 else SIDE_LEFT)
    show(s, body)


@demo("reverse-pec-deck", views=[ABOVE(-90, 68), THREE_QUARTER(-50, 26)],
      labels=("Bras tendus devant", "Ouverture vers l'arrière", "Bras dans l'alignement des épaules", "Retour lent"),
      timing=(0.7, 1.2, 0.6, 1.7))
def reverse_pec_deck(p, s):
    floor(s, -0.95, 1.0, -0.95, 0.95)
    seat_y = 0.52
    # Facing the machine: chest against the upright pad, handles in front at shoulder height.
    s.slab(vec(-0.25, seat_y, 0), vec(0.1, seat_y, 0), Y, 0.36, PAD_T, "pad", solid="le siège")
    body = seated_upright(seat_y, -0.04, lean=4.0, head=0)
    feet_flat(body, (body.pelvis.o[0] + 0.42, 0.22), (body.pelvis.o[0] + 0.42, -0.22))
    c = body.chest
    pad_pt = c.at(u=0.2, f=Body.W_TORSO / 2 + 0.004)
    s.slab(pad_pt - c.u * 0.3, pad_pt + c.u * 0.08, -c.f, 0.28, 0.08, "pad", solid="l'appui")
    pivots, col_x = pec_deck_frame(s, seat_y, pad_pt[0] + 0.08, body.shoulder, reverse=True)
    angle = lerp(-6.0, 92.0, p)
    for side in (1, -1):
        sh = body.shoulder[side]
        direction = rotate(X, Y, -side * angle)
        grip = sh + direction * 0.62 - Y * 0.03
        body.arm(side, grip, unit(-Y * 0.4 + direction * 0.0 - X * 0.3 + body.chest.r * side * 0.0 + Y * -0.6))
        pec_deck_arm(s, pivots[side], grip, SIDE_RIGHT if side == 1 else SIDE_LEFT)
    s.line([vec(pad_pt[0] + 0.08, 0.03, 0), vec(pad_pt[0] + 0.08, pad_pt[1], 0)], TUBE * 1.2, "frame")
    stack(s, col_x + 0.15, 0.0, lift=p * 0.12, height=1.9)
    show(s, body)


@demo("upright-row", views=[FRONT(6), PROFILE()],
      labels=("Barre devant les cuisses", "Montée le long du corps", "Coudes à hauteur des épaules", "Descente lente"),
      timing=(0.7, 1.2, 0.5, 1.6))
def upright_row(p, s):
    floor(s, -0.7, 0.8)
    body = upright(0.94, 0.0, shoulder_x=0.0, head=0)
    stance(body, 0.0, half_width=0.14)
    mid = shoulder_mid(body)
    low = vec(mid[0] + 0.1, mid[1] - 0.6, 0.0)
    high = body.chest.at(u=0.27, f=Body.W_TORSO / 2 + 0.05)
    high[2] = 0.0
    bar = lerp(low, high, p)
    for side in (1, -1):
        body.arm(side, bar + Z * side * 0.21, unit(body.chest.r * side * 1.0 + Y * 0.3 - X * 0.2))
    barbell(s, bar, Z, plate_r=0.15)
    show(s, body)
