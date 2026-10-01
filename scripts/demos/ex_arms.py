"""Arms: curls (barbell, EZ, dumbbells, hammer, incline, preacher, cable, concentration, band), triceps
(pushdowns, overhead, skull crusher, dips, kickback), forearms (wrist curl, reverse curl), carries."""
import math

import numpy as np

from demos import demo, show
from engine import (ABOVE, BACK, FRONT, PROFILE, THREE_QUARTER, Body, Frame, SIDE_LEFT, SIDE_RIGHT, View, X, Y, Z,
                    lerp, posture, rotate, unit, vec)
from gear import (PAD_T, PAD_W, TUBE, Column, adjustable_bench, barbell, cable, d_handle, dip_station, dumbbell,
                  ez_bar, flat_bench, floor, foot_bar, straight_handle)
from machines import seat_with_back, stack
from poses import feet_flat, lying_on_back, on_backrest, placed, seated_upright, stance, upright

CURL = ("Bras tendus", "Flexion des coudes", "Contraction en haut", "Descente lente")
EXT = ("Coudes pliés", "Extension", "Bras tendus", "Retour contrôlé")


def curl_grip(body, side, angle, elbow_forward=0.0, half=None, out=0.0):
    """The grip of a curl: the upper arm hanging (a little forward at the top), the forearm turned
    by angle degrees from straight down (0) toward the shoulder."""
    sh = body.shoulder[side]
    upper = unit(-Y + X * elbow_forward + body.chest.r * side * out)
    elbow = sh + upper * Body.UPPER
    fore = rotate(upper, body.chest.r, angle)  # turning forward and up around the elbow axis
    grip = elbow + fore * Body.LOWER
    if half is not None:
        grip = grip - body.chest.r * side * (abs(np.dot(grip - body.chest.o, body.chest.r)) - half)
    return grip


def curl_elbow(body, side, elbow_forward=0.0, out=0.0):
    """Where the elbow stays during a curl: under the shoulder, against the side."""
    return body.shoulder[side] + unit(-Y + X * elbow_forward + body.chest.r * side * out) * Body.UPPER


def curl_body(p, s, lean=0.0):
    body = upright(0.945, lean, shoulder_x=0.0, head=0)
    stance(body, 0.0, half_width=0.14)
    return body


def curl_angles(p, top=140.0):
    return lerp(6.0, top, p), lerp(0.0, 0.18, p)


@demo("bb-curl", views=[PROFILE(), THREE_QUARTER(35, 10)], labels=CURL, timing=(0.6, 1.1, 0.5, 1.6))
def bb_curl(p, s):
    floor(s, -0.6, 0.9)
    body = curl_body(p, s)
    angle, fwd = curl_angles(p)
    for side in (1, -1):
        g = curl_grip(body, side, angle, fwd, out=0.12)
        body.arm_via(side, vec(g[0], g[1], side * 0.22), curl_elbow(body, side, fwd, 0.12))
    bar = (body.grip[1] + body.grip[-1]) / 2
    barbell(s, bar, Z, plate_r=0.14)
    show(s, body)


@demo("ez-curl", views=[PROFILE(), THREE_QUARTER(35, 10)], labels=CURL, timing=(0.6, 1.1, 0.5, 1.6))
def ez_curl(p, s):
    floor(s, -0.6, 0.9)
    body = curl_body(p, s)
    angle, fwd = curl_angles(p)
    for side in (1, -1):
        g = curl_grip(body, side, angle, fwd, out=0.05)
        body.arm_via(side, vec(g[0], g[1], side * 0.17), curl_elbow(body, side, fwd, 0.05))
    bar = (body.grip[1] + body.grip[-1]) / 2
    fore = unit(body.grip[1] - body.elbow[1])
    ez_bar(s, bar, Z, forward=rotate(fore, Z, 90))
    show(s, body)


@demo("reverse-curl", views=[PROFILE(), THREE_QUARTER(35, 10)],
      labels=("Bras tendus, prise en pronation", "Flexion des coudes", "Contraction en haut", "Descente lente"),
      timing=(0.6, 1.1, 0.5, 1.6))
def reverse_curl(p, s):
    floor(s, -0.6, 0.9)
    body = curl_body(p, s)
    angle, fwd = curl_angles(p, top=130.0)
    for side in (1, -1):
        g = curl_grip(body, side, angle, fwd, out=0.1)
        body.arm_via(side, vec(g[0], g[1], side * 0.2), curl_elbow(body, side, fwd, 0.1))
    bar = (body.grip[1] + body.grip[-1]) / 2
    barbell(s, bar, Z, plate_r=0.12)
    show(s, body)


@demo("db-curl", views=[THREE_QUARTER(35, 10), PROFILE()],
      labels=("Bras tendus, paumes vers l'avant", "Flexion des coudes", "Contraction en haut", "Descente lente"),
      timing=(0.6, 1.1, 0.5, 1.6))
def db_curl(p, s):
    floor(s, -0.6, 0.9, -0.7, 0.7)
    body = curl_body(p, s)
    angle, fwd = curl_angles(p)
    for side in (1, -1):
        g = curl_grip(body, side, angle, fwd, out=0.15)
        body.arm_via(side, g, curl_elbow(body, side, fwd, 0.15))
        dumbbell(s, g, body.chest.r, side=SIDE_RIGHT if side == 1 else SIDE_LEFT)
    show(s, body)


@demo("hammer-curl", views=[THREE_QUARTER(35, 10), PROFILE()],
      labels=("Bras tendus, paumes face à face", "Flexion des coudes", "Contraction en haut", "Descente lente"),
      timing=(0.6, 1.1, 0.5, 1.6))
def hammer_curl(p, s):
    floor(s, -0.6, 0.9, -0.7, 0.7)
    body = curl_body(p, s)
    angle, fwd = curl_angles(p, top=135.0)
    for side in (1, -1):
        g = curl_grip(body, side, angle, fwd, out=0.1)
        body.arm_via(side, g, curl_elbow(body, side, fwd, 0.1))
        fore = unit(g - body.elbow[side])
        axis = rotate(fore, body.chest.r, 90)   # thumb up: the handle across the forearm, front to back
        dumbbell(s, g, axis, side=SIDE_RIGHT if side == 1 else SIDE_LEFT)
    show(s, body)


@demo("incline-curl", views=[PROFILE(), THREE_QUARTER(35, 12)],
      labels=("Bras tendus vers le sol", "Flexion des coudes", "Contraction en haut", "Descente lente"),
      timing=(0.6, 1.2, 0.5, 1.7))
def incline_curl(p, s):
    floor(s, -1.2, 0.9)
    J, d, n = adjustable_bench(s, 0.0, 58.0)
    body = on_backrest(J, d, n, seat_y=0.45, head=10)
    feet_flat(body, (body.pelvis.o[0] + 0.52, 0.22), (body.pelvis.o[0] + 0.52, -0.22))
    angle = lerp(4.0, 128.0, p)
    for side in (1, -1):
        sh = body.shoulder[side]
        upper = unit(-Y + body.chest.r * side * 0.18 - X * 0.08)
        elbow = sh + upper * Body.UPPER
        fore = rotate(upper, body.chest.r, angle)
        grip = elbow + fore * Body.LOWER
        body.arm_via(side, grip, elbow)
        dumbbell(s, grip, body.chest.r, side=SIDE_RIGHT if side == 1 else SIDE_LEFT)
    show(s, body)


@demo("preacher-curl", views=[PROFILE(), THREE_QUARTER(35, 12)],
      labels=("Bras presque tendus sur le pupitre", "Flexion des coudes", "Contraction en haut", "Descente lente"),
      timing=(0.6, 1.1, 0.5, 1.8))
def preacher_curl(p, s):
    floor(s, -0.7, 1.0)
    seat_y = 0.58
    s.slab(vec(-0.2, seat_y, 0), vec(0.15, seat_y, 0), Y, 0.34, PAD_T, "pad", solid="le siège")
    body = seated_upright(seat_y, -0.06, lean=4.0, head=10)
    feet_flat(body, (0.42, 0.2), (0.42, -0.2), pole=X)
    # The pad: angled 45°, the back of the upper arms resting on it.
    elbow_x = None
    for side in (1, -1):
        sh = body.shoulder[side]
        upper = unit(X * 0.72 - Y * 0.7 + body.chest.r * side * 0.0)
        elbow = sh + upper * Body.UPPER
        start = rotate(upper, body.chest.r, 18)
        fore = rotate(upper, body.chest.r, lerp(18.0, 118.0, p))
        grip = elbow + fore * Body.LOWER
        body.arm_via(side, grip, elbow)
    sh = body.shoulder[1]
    upper = unit(X * 0.72 - Y * 0.7)
    normal = rotate(upper, Z, 90)        # up and forward: the pad's top surface, under the arms
    top_pt = sh + upper * 0.02 - normal * (Body.W_UPPER / 2 + 0.005)
    end_pt = sh + upper * (Body.UPPER + 0.03) - normal * (Body.W_UPPER / 2 + 0.005)
    s.slab(vec(top_pt[0], top_pt[1], 0), vec(end_pt[0], end_pt[1], 0), normal, 0.5, 0.06, "pad", solid="le pupitre")
    s.allow = {("buste", "le pupitre")}   # the chest leans on the top of the pad
    s.line([vec(end_pt[0] - 0.05, end_pt[1] - 0.06, 0), vec(end_pt[0] - 0.1, 0.03, 0)], TUBE * 1.2, "frame")
    s.line([vec(0.0, seat_y - PAD_T, 0), vec(0.0, 0.03, 0)], TUBE * 1.2, "frame")
    s.line([vec(-0.3, 0.03, 0), vec(end_pt[0] + 0.15, 0.03, 0)], TUBE, "frame")
    bar = (body.grip[1] + body.grip[-1]) / 2
    fore = unit(body.grip[1] - body.elbow[1])
    ez_bar(s, bar, Z, forward=rotate(fore, Z, 90))
    show(s, body)


@demo("cable-curl", views=[PROFILE(), THREE_QUARTER(35, 10)], labels=CURL, timing=(0.6, 1.1, 0.5, 1.6))
def cable_curl(p, s):
    floor(s, -0.6, 1.2)
    body = curl_body(p, s, lean=-3.0)
    angle, fwd = curl_angles(p, top=135.0)
    for side in (1, -1):
        g = curl_grip(body, side, angle, fwd, out=0.08)
        body.arm_via(side, vec(g[0], g[1], side * 0.18), curl_elbow(body, side, fwd, 0.08))
    bar = (body.grip[1] + body.grip[-1]) / 2
    pul = vec(0.72, 0.16, 0.0)
    g0 = curl_grip(body, 1, 6.0, 0.0, out=0.08)
    col = Column(s, 0.9, 0.0, height=2.1, depth=0.24, width=0.36)
    col.frame(lift=np.linalg.norm(bar - pul) - np.linalg.norm(vec(g0[0], g0[1], 0) - pul))
    s.disc(pul, Z, 0.045, "frame")
    cable(s, pul, bar)
    straight_handle(s, bar, Z, half=0.25)
    show(s, body)


@demo("concentration-curl", views=[THREE_QUARTER(55, 16), PROFILE()],
      labels=("Coude contre la cuisse, bras tendu", "Flexion du coude", "Contraction en haut", "Descente lente"),
      timing=(0.6, 1.1, 0.6, 1.6))
def concentration_curl(p, s):
    floor(s, -0.9, 0.9, -0.8, 0.8)
    top = 0.43
    s.slab(vec(-0.75, top, 0), vec(0.12, top, 0), Y, PAD_W, PAD_T, "pad", solid="le banc")
    s.line([vec(-0.6, top - PAD_T, 0), vec(-0.6, 0.03, 0)], TUBE, "frame")
    s.line([vec(0.0, top - PAD_T, 0), vec(0.0, 0.03, 0)], TUBE, "frame")
    foot_bar(s, -0.6)
    foot_bar(s, 0.0)
    # Seated on the end of the bench, legs apart, leaning forward over the right thigh.
    body = seated_upright(top, -0.02, lean=40.0, head=30, twist=10.0, bend=4.0)
    feet_flat(body, (0.48, 0.36), (0.48, -0.36), pole=unit(X + Y * 0.6))
    knee = body.knee[1]
    hip = body.hip[1]
    elbow_at = lerp(hip, knee, 0.82) - body.pelvis.r * 0.07 + Y * 0.035
    sh = body.shoulder[1]
    upper = unit(elbow_at - sh)
    elbow = sh + upper * Body.UPPER
    chest = body.chest.at(u=0.28, f=0.1)
    toward = unit(chest - elbow)
    axis = unit(np.cross(upper, toward))
    angle = lerp(178.0, 40.0, p)    # between upper arm and forearm
    fore = rotate(upper, axis, 180.0 - angle)
    grip = elbow + fore * Body.LOWER
    body.arm_via(1, grip, elbow)       # the elbow stays braced against the inner thigh
    dumbbell(s, grip, body.chest.r, side=SIDE_RIGHT)
    # The other hand on the other thigh.
    body.arm(-1, lerp(body.hip[-1], body.knee[-1], 0.75) + Y * 0.07, unit(-Y + X * 0.2 - body.chest.r))
    show(s, body)


@demo("band-curl", views=[PROFILE(), THREE_QUARTER(35, 10)],
      labels=("Pieds sur l'élastique, bras tendus", "Flexion des coudes", "Contraction en haut", "Descente lente"),
      timing=(0.6, 1.1, 0.5, 1.6))
def band_curl(p, s):
    floor(s, -0.6, 0.9, -0.7, 0.7)
    body = curl_body(p, s)
    angle, fwd = curl_angles(p)
    for side in (1, -1):
        g = curl_grip(body, side, angle, fwd, out=0.12)
        body.arm_via(side, g, curl_elbow(body, side, fwd, 0.12))
        foot = body.ankle[side] + X * 0.06 - Y * 0.07
        s.line([foot, g], 0.02, "load", side=SIDE_RIGHT if side == 1 else SIDE_LEFT)
        s.line([g - body.chest.r * 0.05, g + body.chest.r * 0.05], 0.035, "load", side=SIDE_RIGHT if side == 1 else SIDE_LEFT)
    show(s, body)


# --- Triceps ----------------------------------------------------------------------------------------------

def pushdown_body(p, s, top_angle=95.0, lean=10.0):
    body = upright(0.94, lean, shoulder_x=0.02, head=-4)
    stance(body, 0.0, half_width=0.15)
    angle = lerp(top_angle, 6.0, p)
    for side in (1, -1):
        sh = body.shoulder[side]
        upper = unit(-Y + X * 0.04)
        elbow = sh + upper * Body.UPPER
        fore = rotate(upper, body.chest.r, angle)
        grip = elbow + fore * Body.LOWER
        body.arm_via(side, grip, elbow)      # elbows stay pinned at the sides
    return body


@demo("pushdown", views=[PROFILE(), THREE_QUARTER(35, 10)],
      labels=("Coudes au corps, avant-bras horizontaux", "Extension vers le bas", "Bras tendus", "Remontée contrôlée"),
      timing=(0.6, 1.0, 0.5, 1.5))
def pushdown(p, s):
    floor(s, -0.6, 1.1)
    body = pushdown_body(p, s)
    bar = (body.grip[1] + body.grip[-1]) / 2
    for side in (1, -1):
        g = body.grip[side]
        body.arm_via(side, vec(g[0], g[1], side * 0.14), body.elbow[side])
    bar = vec(body.grip[1][0], body.grip[1][1], 0.0)
    pul = vec(0.55, 2.1, 0.0)
    col = Column(s, 0.75, 0.0, height=2.25, depth=0.24, width=0.36)
    top_bar = pushdown_body(0.0, s.__class__()).grip[1]
    col.frame(lift=np.linalg.norm(bar - pul) - np.linalg.norm(vec(top_bar[0], top_bar[1], 0) - pul))
    s.disc(pul, Z, 0.045, "frame")
    cable(s, pul, bar)
    straight_handle(s, bar, Z, half=0.2)
    show(s, body)


@demo("rope-pushdown", views=[PROFILE(), THREE_QUARTER(35, 10)],
      labels=("Coudes au corps, corde en main", "Extension, bouts écartés", "Bras tendus", "Remontée contrôlée"),
      timing=(0.6, 1.0, 0.5, 1.5))
def rope_pushdown(p, s):
    floor(s, -0.6, 1.1, -0.6, 0.6)
    body = pushdown_body(p, s)
    for side in (1, -1):
        g = body.grip[side]
        # Neutral grip on the two rope ends, pulled apart beside the thighs at the bottom.
        z = side * lerp(0.07, 0.27, p ** 1.5)
        body.arm_via(side, vec(g[0] - 0.02 * p, g[1], z), body.elbow[side])
    pul = vec(0.55, 2.1, 0.0)
    knot = vec(lerp(body.grip[1][0], body.grip[1][0] + 0.04, p), max(body.grip[1][1], body.grip[-1][1]) + lerp(0.12, 0.2, p), 0.0)
    col = Column(s, 0.75, 0.0, height=2.25, depth=0.24, width=0.36)
    col.frame(lift=p * 0.4)
    s.disc(pul, Z, 0.045, "frame")
    cable(s, pul, knot)
    for side in (1, -1):
        g = body.grip[side]
        sd = SIDE_RIGHT if side == 1 else SIDE_LEFT
        s.line([knot, g], 0.025, "load", side=sd)
        s.ball(g - Y * 0.05, 0.03, "load", side=sd)
    show(s, body)


@demo("overhead-extension", views=[PROFILE(), THREE_QUARTER(35, 10)],
      labels=("Haltère au-dessus de la tête", "Descente derrière la tête", "Coudes pliés, coudes hauts", "Extension"),
      timing=(0.6, 1.4, 0.4, 1.2))
def overhead_extension(p, s):
    floor(s, -0.6, 0.8)
    body = upright(0.945, -2.0, shoulder_x=0.0, head=8)
    stance(body, 0.0, half_width=0.15)
    mid = (body.shoulder[1] + body.shoulder[-1]) / 2
    angle = lerp(4.0, 125.0, p)
    for side in (1, -1):
        sh = body.shoulder[side]
        upper = unit(Y + X * 0.12 - body.chest.r * side * 0.1)
        elbow = sh + upper * Body.UPPER
        fore = rotate(upper, body.chest.r, angle)
        grip = elbow + fore * Body.LOWER
        grip = grip - body.chest.r * side * (abs(np.dot(grip - mid, body.chest.r)) - 0.04)
        body.arm_via(side, grip, elbow)      # elbows stay high, pointing up
    g = (body.grip[1] + body.grip[-1]) / 2
    fore = unit(g - (body.elbow[1] + body.elbow[-1]) / 2)
    axis = unit(rotate(fore, Z, 0))
    # One dumbbell held under its top plate, upright along the forearms.
    s.line([g - axis * 0.12, g + axis * 0.06], 0.028, "metal")
    s.line([g + axis * 0.04, g + axis * 0.11], 0.17, "load")
    s.line([g - axis * 0.18, g - axis * 0.12], 0.15, "load")
    show(s, body)


@demo("skull-crusher", views=[PROFILE(), THREE_QUARTER(38, 16)],
      labels=("Bras tendus au-dessus de la poitrine", "Flexion des coudes", "Barre près du front", "Extension"),
      timing=(0.6, 1.5, 0.4, 1.2))
def skull_crusher(p, s):
    floor(s, -1.2, 1.0)
    flat_bench(s, -0.8, 0.42, 0.43)
    body = lying_on_back(0.43, 0.0, head=14)
    feet_flat(body, (0.62, 0.27), (0.62, -0.27), pole=Y)
    angle = lerp(4.0, 112.0, p)
    for side in (1, -1):
        sh = body.shoulder[side]
        upper = unit(Y - X * 0.2)          # arms slightly tilted toward the head
        elbow = sh + upper * Body.UPPER
        fore = rotate(upper, Z, angle)     # only the forearm hinges, toward the forehead
        grip = elbow + fore * Body.LOWER
        body.arm_via(side, vec(grip[0], grip[1], side * 0.15), elbow)
    bar = vec(body.grip[1][0], body.grip[1][1], 0.0)
    ez_bar(s, bar, Z, forward=Y)
    show(s, body)


@demo("triceps-dips", views=[PROFILE(), THREE_QUARTER(40, 12)],
      labels=("En appui, bras tendus", "Descente, buste droit", "Coudes à 90°", "Poussée"), timing=(0.6, 1.5, 0.4, 1.1))
def triceps_dips(p, s):
    from ex_chest import dips_body
    floor(s, -0.7, 0.7)
    dip_station(s)
    body = dips_body(p, 4, 8, 0.26, 0.12)
    show(s, body)


@demo("bench-dips", views=[PROFILE(), THREE_QUARTER(35, 14)],
      labels=("Mains sur le banc, bras tendus", "Descente des fesses", "Coudes à 90°", "Poussée"), timing=(0.6, 1.4, 0.4, 1.1))
def bench_dips(p, s):
    floor(s, -0.6, 1.3)
    from ex_chest import bench_across
    top = 0.43
    bench_across(s, -0.25, top)
    hands = vec(-0.13, top + 0.02, 0.0)
    # From arms locked out to elbows at 90°, the hips dropping below the bench.
    sh = vec(-0.08, lerp(top + 0.625, top + 0.44, p), 0.0)
    body = placed(posture(vec(0, 0, 0), 0.0, -4.0), "shoulders", sh, head=0)
    for side in (1, -1):
        body.arm(side, hands + Z * side * 0.21, unit(-X + Z * side * 0.1))
        body.foot_on_floor(side, (0.7, side * 0.12), 0.0, pole=Y)
    show(s, body)


@demo("kickback", views=[PROFILE(), THREE_QUARTER(30, 14)],
      labels=("Buste penché, coudes au corps", "Extension vers l'arrière", "Bras tendus", "Retour contrôlé"),
      timing=(0.6, 1.0, 0.5, 1.4))
def kickback(p, s):
    floor(s, -0.8, 0.9)
    body = upright(0.84, 68.0, shoulder_x=0.16, head=-20)
    stance(body, 0.0, half_width=0.15)
    angle = lerp(92.0, 4.0, p)
    for side in (1, -1):
        sh = body.shoulder[side]
        upper = unit(-body.chest.u * 0.97 - Y * 0.05)   # along the torso, toward the hips
        elbow = sh + upper * Body.UPPER
        fore = rotate(upper, body.chest.r, angle)
        grip = elbow + fore * Body.LOWER
        body.arm_via(side, grip, elbow)
        dumbbell(s, grip, rotate(fore, body.chest.r, 90), side=SIDE_RIGHT if side == 1 else SIDE_LEFT)
    show(s, body)


WRIST_LEAN = 52.0


# --- Forearms and grip --------------------------------------------------------------------------------------

@demo("wrist-curl", views=[PROFILE(), THREE_QUARTER(35, 14)],
      labels=("Avant-bras sur les cuisses, poignets en bas", "Flexion des poignets", "Poignets en haut", "Descente lente"),
      timing=(0.6, 0.9, 0.5, 1.2), muscles=(["forearms"], []))
def wrist_curl(p, s):
    floor(s, -0.8, 1.0)
    top = 0.43
    flat_bench(s, -0.6, 0.35, top)
    body = seated_upright(top, -0.05, lean=WRIST_LEAN, head=20)
    feet_flat(body, (0.42, 0.17), (0.42, -0.17), pole=unit(X + Y * 0.6))
    wrist_angle = lerp(-60.0, 50.0, p)
    for side in (1, -1):
        knee = body.knee[side]
        thigh = unit(knee - body.hip[side])
        thigh_top = knee + Y * (Body.W_THIGH / 2 + Body.W_LOWER / 2)
        # Forearm lying along the thigh, the wrist just past the knee.
        wrist = thigh_top + thigh * 0.11
        elbow = wrist - thigh * Body.LOWER
        body.arm_via(side, wrist, elbow)
    # Hands: from the wrists to the bar, turned by the wrist.
    hand_dir = rotate(unit(body.grip[1] - body.elbow[1]), Z, wrist_angle)
    bar = vec(body.grip[1][0], body.grip[1][1], 0.0) + hand_dir * 0.1
    for side in (1, -1):
        w = body.grip[side]
        s.line([w, vec(bar[0], bar[1], w[2])], 0.05, "muscle", side=SIDE_RIGHT if side == 1 else SIDE_LEFT)
    barbell(s, bar, Z, plate_r=0.11)
    show(s, body)


@demo("farmer-walk", views=[PROFILE(), THREE_QUARTER(35, 10)], mode="loop", timing=1.3, samples=24,
      labels=(), travel=(1.12, 0.28, -1.2, 1.2, -0.45, 0.45, 0.0, 40.0))
def farmer_walk(p, s):
    from cyclic import walk_cycle
    floor(s, -1.2, 1.2)
    body = walk_cycle(p, s, stride=0.56, arms="carry", hip=0.885, bounce=0.015)
    for side in (1, -1):
        g = body.grip[side]
        dumbbell(s, g, X, head=0.07, length=0.08, side=SIDE_RIGHT if side == 1 else SIDE_LEFT)
    show(s, body)
