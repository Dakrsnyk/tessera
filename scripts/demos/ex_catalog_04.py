"""Catalogue (lot 04, 2026-11-23): bonds, saut de profondeur, saut en longueur, glute-ham raise, leg curl sur ballon,
flutter kicks, crunch inversé, fentes à la barre, marche monster, Tate press, groiners."""
import math

import numpy as np

from demos import demo, show
from engine import (FRONT, PROFILE, THREE_QUARTER, Body, Frame, SIDE_LEFT, SIDE_RIGHT, X, Y, Z, lerp, rotate, unit, vec)
from gear import PAD_T, TUBE, barbell, dumbbell, flat_bench, floor
from keys import keyed, pose
from poses import lying_on_back, plank_on_toes, stance, upright, feet_flat, solve


def smooth(t):
    t = min(1.0, max(0.0, t))
    return t * t * (3 - 2 * t)


FOOT = X * 0.165 - Y * 0.06


# --- Bonds diagonaux alternés ------------------------------------------------------------------------------

@demo("x-alternate-leg-diagonal-bound", views=[PROFILE(), THREE_QUARTER(35, 10)], mode="loop", samples=40,
      labels=("Réception sur une jambe", "Poussée explosive", "Genou opposé haut, en l'air", "Réception sur l'autre jambe"),
      segments=[(0.30, 0.0, 0.25, 0, 1), (0.25, 0.25, 0.45, 1, 1), (0.40, 0.45, 0.75, 2, 0), (0.30, 0.75, 1.0, 3, 1)],
      muscles=(["quads"], ["glutes", "calves", "hamstrings"]))
def diagonal_bound(p, s):
    floor(s, -0.9, 0.9, -0.7, 0.7)
    h = (p * 2) % 1.0
    land = 1 if p < 0.5 else -1          # the side that lands first in this half cycle
    zl = 0.17

    def foot(x, y, z, point=0.0):
        ankle = vec(x, y, z)
        toe = ankle + rotate(FOOT, Z, -point)
        return ankle, X, toe

    # (landing leg L, trailing leg T): L is planted, pushes, then trails; T trails, drives forward, lands.
    k = [
        (0.0, {"pelvis": vec(0.02, 0.80, land * zl), "lean": 14.0, "head": -8,
               "L": foot(0.0, Body.ANKLE, land * zl), "T": foot(-0.45, 0.30, -land * zl, 35),
               "arms": {land: vec(-0.25, 1.0, land * 0.3), -land: vec(0.30, 1.05, -land * 0.3)}}),
        (0.3, {"pelvis": vec(0.0, 0.94, land * zl * 0.4), "lean": 16.0, "head": -8,
               "L": foot(-0.22, 0.16, land * zl, 45), "T": foot(0.12, 0.52, -land * zl, 25),
               "arms": {land: vec(-0.1, 1.15, land * 0.3), -land: vec(0.2, 1.1, -land * 0.3)}}),
        (0.62, {"pelvis": vec(0.04, 1.18, 0.0), "lean": 10.0, "head": -6,
                "L": foot(-0.55, 0.68, land * zl, 55), "T": foot(0.30, 0.74, -land * zl, 15),
                "arms": {land: vec(0.30, 1.45, land * 0.3), -land: vec(-0.25, 1.15, -land * 0.3)}}),
        (1.0, {"pelvis": vec(0.02, 0.80, -land * zl), "lean": 14.0, "head": -8,
               "L": foot(-0.45, 0.30, land * zl, 35), "T": foot(0.0, Body.ANKLE, -land * zl),
               "arms": {land: vec(0.30, 1.05, land * 0.3), -land: vec(-0.25, 1.0, -land * 0.3)}}),
    ]
    keys = []
    for pk, d in k:
        keys.append((pk, {"pelvis": d["pelvis"], "lean": d["lean"], "head": d["head"],
                          "legs": {land: (d["L"][0], X, d["L"][2]), -land: (d["T"][0], X, d["T"][2])},
                          "arms": {sd: (t, -Y - X * 0.2) for sd, t in d["arms"].items()}}))
    show(s, pose(keyed(h, keys)))


# --- Saut de profondeur --------------------------------------------------------------------------------------

def params_of(body, pole=X):
    """Pose parameters read back from a solved body (to blend a solved squat with stage poses)."""
    u = body.pelvis.u
    return {"pelvis": body.pelvis.o.copy(), "lean": math.degrees(math.atan2(u[0], u[1])), "head": -6,
            "legs": {sd: (body.ankle[sd].copy(), pole, body.toe[sd].copy()) for sd in (1, -1)},
            "arms": {sd: (body.grip[sd].copy(), -X) for sd in (1, -1)}}


def stand_params(x, y=0.0, lean=0.0, drop=0.0, head=0.0, arms=(0.04, 0.86, 0.2)):
    ax, ay, az = arms
    return {"pelvis": vec(x, y + 0.945 - drop, 0.0), "lean": lean, "head": head,
            "arms": {sd: (vec(x + ax, y + ay - drop, sd * az), -X) for sd in (1, -1)},
            "legs": {sd: (vec(x - 0.04, y + Body.ANKLE, sd * 0.12), X, vec(x + 0.125, y + 0.02, sd * 0.12)) for sd in (1, -1)}}


@demo("x-linear-depth-jump", views=[PROFILE(), THREE_QUARTER(35, 12)], mode="loop", samples=44,
      labels=("Debout sur le box", "Pas dans le vide", "Réception pieds joints", "Rebond vertical maximal", "Réception amortie"),
      segments=[(0.6, 0.0, 0.08, 0, 1), (0.45, 0.08, 0.22, 1, 0), (0.25, 0.22, 0.34, 2, 1), (0.45, 0.34, 0.62, 3, 0),
                (0.5, 0.62, 0.8, 4, 1), (0.6, 0.8, 1.0, 4, 1)],
      muscles=(["quads"], ["calves", "glutes", "hamstrings"]))
def depth_jump(p, s):
    from ex_cardio import jump_squat_body
    floor(s, -1.0, 0.9, -0.6, 0.6)
    box_top = 0.45
    s.box(vec(-0.55, box_top / 2, 0.0), X * 0.3, Y * box_top / 2, Z * 0.38, "pad", stroke=0.012, solid="le box")
    if p < 0.22:
        land = params_of(jump_squat_body(0.1))
        k0 = stand_params(-0.38, box_top)
        k1 = stand_params(-0.30, box_top)
        k1["legs"][1] = (vec(-0.15, box_top + 0.2, 0.12), X, vec(0.0, box_top + 0.14, 0.12))
        k2 = stand_params(-0.1, 0.22, drop=0.0, head=-4)
        k2["legs"] = {sd: (vec(-0.06, 0.4, sd * 0.12), X, vec(0.08, 0.3, sd * 0.12)) for sd in (1, -1)}
        keys = [(0.0, k0), (0.08, k0), (0.12, k1), (0.17, k2), (0.22, land)]
        params = keyed(p, keys)
        if 0.08 < p < 0.2:
            t = (p - 0.08) / 0.12
            legs = dict(params["legs"])
            a, pole, toe = legs[-1]
            # the trailing foot leaves the box edge
            lift = vec(0.0, 0.0, 0.0)
            legs[-1] = (a + lift, pole, toe + lift)
            params = dict(params)
            params["legs"] = legs
        show(s, pose(params))
    else:
        # ground contact, rebound and landing: the squat jump, starting from a shallow absorption
        if p < 0.34:
            u = 0.1 + 0.25 * smooth((p - 0.22) / 0.12)
        else:
            u = 0.35 + 0.65 * ((p - 0.34) / 0.66)
        show(s, jump_squat_body(u))


# --- Saut en longueur sans élan --------------------------------------------------------------------------------

@demo("x-standing-long-jump", views=[PROFILE(), THREE_QUARTER(35, 10)], mode="loop", samples=44,
      labels=("Debout, pieds écartés", "Armé des bras et flexion", "Extension et bras devant", "Envol vers l'avant", "Réception amortie"),
      segments=[(0.5, 0.0, 0.1, 0, 1), (0.55, 0.1, 0.3, 1, 1), (0.2, 0.3, 0.42, 2, 1), (0.45, 0.42, 0.75, 3, 0),
                (0.55, 0.75, 0.9, 4, 1), (0.6, 0.9, 1.0, 4, 1)],
      muscles=(["quads"], ["calves", "glutes", "hamstrings"]))
def standing_long_jump(p, s):
    floor(s, -0.7, 2.1, -0.7, 0.7)
    s.line([vec(0.17, 0.002, -0.35), vec(0.17, 0.002, 0.35)], 0.025, "mark")
    s.line([vec(1.55, 0.002, -0.35), vec(1.55, 0.002, 0.35)], 0.025, "mark")

    def flat(x, y=0.0):
        return {sd: (vec(x, y + Body.ANKLE, sd * 0.13), X, vec(x + 0.165, y + 0.02, sd * 0.13)) for sd in (1, -1)}

    def toes(x, point, y=0.0):
        a = vec(x, y + Body.ANKLE + 0.07, 0)
        return {sd: (a + Z * sd * 0.13, X, a + Z * sd * 0.13 + rotate(FOOT, Z, -point)) for sd in (1, -1)}

    def arms(a, b):
        return {sd: (vec(a, b, sd * 0.22), -X) for sd in (1, -1)}

    k_stand = {"pelvis": vec(0.0, 0.945, 0.0), "lean": 2.0, "head": 0.0, "legs": flat(-0.04), "arms": arms(0.04, 0.88)}
    k_load = {"pelvis": vec(-0.17, 0.62, 0.0), "lean": 42.0, "head": -12, "legs": flat(-0.04), "arms": arms(-0.4, 0.8)}
    k_push = {"pelvis": vec(0.2, 0.90, 0.0), "lean": 30.0, "head": -8, "legs": toes(-0.02, 40), "arms": arms(0.5, 1.7)}
    k_fly = {"pelvis": vec(0.75, 1.15, 0.0), "lean": 24.0, "head": -6,
             "legs": {sd: (vec(1.0, 0.7, sd * 0.13), X, vec(1.12, 0.62, sd * 0.13)) for sd in (1, -1)}, "arms": arms(1.2, 1.55)}
    k_land = {"pelvis": vec(1.43, 0.66, 0.0), "lean": 40.0, "head": -12,
              "legs": {sd: (vec(1.68, Body.ANKLE, sd * 0.13), X, vec(1.845, 0.02, sd * 0.13)) for sd in (1, -1)},
              "arms": arms(1.95, 0.95)}
    k_up = {"pelvis": vec(1.6, 0.945, 0.0), "lean": 2.0, "head": 0.0, "legs": flat(1.56), "arms": arms(1.64, 0.88)}
    keys = [(0.0, k_stand), (0.1, k_stand), (0.3, k_load), (0.42, k_push), (0.58, k_fly), (0.75, k_land),
            (0.9, k_land), (1.0, k_up)]
    params = keyed(p, keys)
    # heels land first, a hop of the feet over the last metre
    show(s, pose(params))


# --- Glute-ham raise (banc GHD) -------------------------------------------------------------------------------

@demo("x-glute-ham-raise", views=[PROFILE(), THREE_QUARTER(35, 12)],
      labels=("Buste vertical, genoux fléchis", "Descente contrôlée du buste", "Corps à l'horizontale", "Remontée par les ischios"),
      timing=(0.6, 2.4, 0.5, 2.2), muscles=(["hamstrings"], ["calves", "glutes"]))
def glute_ham_raise(p, s):
    from machines import roller
    floor(s, -1.2, 1.3)
    pad_top = 0.80
    knee = vec(-0.3, pad_top + Body.R_SHIN + 0.005, 0.0)
    s.slab(vec(-0.98, pad_top, 0), vec(0.2, pad_top, 0), Y, 0.34, 0.05, "pad", solid="le banc")
    angle = lerp(88.0, 4.0, p)
    u = vec(math.cos(math.radians(angle)), math.sin(math.radians(angle)), 0.0)
    f = vec(u[1], -u[0], 0.0)
    pelvis = knee + u * Body.THIGH
    body = Body(Frame(pelvis, f, u), head=-8)
    for side in (1, -1):
        body.leg_dirs(side, -u, -X)
        body.foot_toward(side, body.ankle[side] + vec(-0.172, -0.02, 0.0))
    ankle = body.ankle[1]
    roller(s, vec(ankle[0] + 0.02, ankle[1] + Body.R_SHIN + 0.05, 0.0), half=0.22)
    s.slab(vec(ankle[0] - 0.24, pad_top + 0.02, 0), vec(ankle[0] - 0.24, pad_top + 0.34, 0), X, 0.44, 0.04, "pad")
    for x in (-0.9, 0.1):
        s.line([vec(x, pad_top - 0.05, 0), vec(x, 0.03, 0)], TUBE * 1.2, "frame")
    s.line([vec(-1.05, 0.03, 0), vec(0.25, 0.03, 0)], TUBE, "frame")
    s.line([vec(ankle[0] - 0.24, pad_top, 0), vec(ankle[0] - 0.24, 0.03, 0)], TUBE, "frame")
    for side in (1, -1):
        chest = body.chest.at(u=0.3, f=0.12, r=-side * 0.08)
        body.arm(side, chest, unit(-u + body.chest.r * side * 0.5))
    show(s, body)


# --- Leg curl sur ballon -------------------------------------------------------------------------------------------

@demo("x-ball-leg-curl", views=[PROFILE(), THREE_QUARTER(35, 14)],
      labels=("Pont, talons sur le ballon", "Flexion des genoux", "Ballon près des fessiers, bassin haut", "Extension lente"),
      timing=(0.7, 1.5, 0.6, 1.8), muscles=(["hamstrings"], ["calves", "glutes"]))
def ball_leg_curl(p, s):
    from poses import placed
    floor(s, -1.1, 1.5)
    a = 40.0
    d = vec(math.cos(math.radians(a)), math.sin(math.radians(a)), 0.0)
    u = -d
    f = vec(-u[1], u[0], 0.0) * -1
    shoulders = vec(-0.5, 0.12, 0.0)
    body = placed(Frame(vec(0, 0, 0), f, u), "shoulders", shoulders, head=a)
    hip = body.pelvis.o
    r = 0.2
    reach = lerp(0.88, 0.34, smooth(p))
    ankle_x = hip[0] + reach
    top = 0.2 + r
    for side in (1, -1):
        ankle = vec(ankle_x, top + 0.035, side * 0.1)
        body.leg(side, ankle, pole=Y)
        body.foot_relaxed(side, plantar=-35)
        body.arm(side, vec(shoulders[0] + 0.5, 0.035, side * 0.27), unit(Z * side + X * 0.2))
    s.ball(vec(ankle_x + 0.015, 0.2, 0.0), r, "load")
    show(s, body)


# --- Battements de jambes sur banc ---------------------------------------------------------------------------------

@demo("x-flutter-kicks", views=[PROFILE(), THREE_QUARTER(38, 16)], mode="loop", timing=0.9, samples=24, labels=(),
      muscles=(["glutes"], ["hamstrings"]))
def flutter_kicks(p, s):
    floor(s, -1.2, 1.2)
    flat_bench(s, -0.85, 0.14, 0.43)
    body = lying_on_back(0.43, 0.0, head=14)
    for side in (1, -1):
        angle = 22.0 + 14.0 * math.sin(2 * math.pi * p) * side
        d = vec(math.cos(math.radians(angle)), math.sin(math.radians(angle)), 0.0)
        body.leg_dirs(side, d, d)
        body.foot_relaxed(side, plantar=25)
        # hands under the hips, gripping the sides of the bench
        body.arm(side, vec(-0.12, 0.40, side * 0.2), unit(Z * side - Y * 0.3))
    show(s, body)


# --- Crunch inversé -----------------------------------------------------------------------------------------------

@demo("x-reverse-crunch", views=[PROFILE(), THREE_QUARTER(35, 16)],
      labels=("Allongé, jambes fléchies à 90°", "Enroulement du bassin", "Hanches décollées vers la poitrine", "Descente contrôlée"),
      timing=(0.6, 1.3, 0.5, 1.6), muscles=(["abs"], []))
def reverse_crunch(p, s):
    from ex_core import supine
    floor(s, -1.1, 1.1)
    theta = lerp(0.0, 30.0, smooth(p))
    base = supine(head=18.0)
    o = base.pelvis.o
    waist = base.waist
    new_o = waist + rotate(o - waist, Z, theta)
    f = rotate(base.pelvis.f, Z, theta)
    u = rotate(base.pelvis.u, Z, theta)
    body = Body(Frame(new_o, f, u), spine=theta, head=18.0)
    alpha = 8.0 + 0.9 * theta + 14.0 * smooth(p)
    thigh = rotate(Y, Z, alpha)
    shin = rotate(thigh, Z, -95.0)
    for side in (1, -1):
        body.leg_dirs(side, thigh, shin)
        body.foot_relaxed(side, plantar=0)
        sh = body.shoulder[side]
        body.arm(side, vec(sh[0] + 0.5, 0.04, side * 0.27), unit(Z * side + Y * 0.2))
    show(s, body)


# --- Fentes à la barre ---------------------------------------------------------------------------------------------

@demo("x-barbell-lunge", views=[PROFILE(), THREE_QUARTER(35, 12)],
      labels=("Debout, barre sur les trapèzes", "Grand pas en avant et descente", "Genou arrière près du sol", "Poussée pour revenir"),
      timing=(0.5, 1.6, 0.4, 1.3), muscles=(["quads"], ["calves", "glutes", "hamstrings"]))
def barbell_lunge(p, s):
    from ex_legs import back_bar
    floor(s, -0.9, 1.3)
    step = 0.95
    a = smooth(min(1.0, p / 0.4))              # the step
    b = smooth(max(0.0, (p - 0.3) / 0.7))      # the descent
    hip_y = lerp(0.95 - 0.1 * a, 0.53, b)
    front = vec(lerp(0.0, step, a), 0.0, 0.11)
    body = upright(hip_y, 3.0, pelvis_x=lerp(0.0, step * 0.53, a), head=-2)
    lift = 0.12 * math.sin(math.pi * a) if a < 0.999 else 0.0
    if a < 0.999:
        ankle = vec(front[0], Body.ANKLE + lift, 0.11)
        body.leg(1, ankle, pole=X)
        body.toe[1] = ankle + X * 0.165 - Y * 0.06
    else:
        body.foot_on_floor(1, (front[0], 0.11), 0.0, pole=X)
    heel = lerp(0.0, 55.0, smooth(min(1.0, p / 0.5)))
    ankle = body.stand_foot(-1, vec(0.165, 0.02, -0.11), 0.0, heel)
    body.leg(-1, ankle, pole=X)
    bar = back_bar(body)
    bar[2] = 0.0
    for side in (1, -1):
        body.arm(side, bar + Z * side * 0.42, unit(-Y - X * 0.6 + Z * side * 0.2))
    barbell(s, bar, Z)
    show(s, body)


# --- Marche monster avec élastique ----------------------------------------------------------------------------------

@demo("x-monster-walk", views=[FRONT(6), THREE_QUARTER(35, 10)], mode="loop", timing=1.6, samples=32, labels=(),
      travel=(0.8, 0.2, -1.4, 1.4, -0.6, 0.6, 0.0, 40.0), muscles=(["glutes"], []))
def monster_walk(p, s):
    from cyclic import foot_path
    floor(s, -1.4, 1.4, -0.7, 0.7)
    hip_y = 0.80 + 0.012 * math.cos(4 * math.pi * p)
    body = upright(hip_y, 16.0, pelvis_x=-0.02, head=-6)
    half = 0.24
    for side, offset in ((1, 0.0), (-1, 0.5)):
        x, y, contact, t = foot_path(p + offset, 0.65, 0.4, 0.07, 0.0, ahead=0.05)
        ankle = vec(x, y, side * half)
        pole = unit(X + Z * side * 0.7)
        body.leg(side, ankle, pole=pole)
        pitch = 0.0 if contact else 14.0 * math.sin(math.pi * t)
        body.toe[side] = body.ankle[side] + rotate(FOOT, Z, -pitch)
    # the band around the knees, kept tight by the wide stance
    # The band loops around both legs just above the knees (not through them).
    f, r = body.pelvis.f, body.pelvis.r
    kr, kl = body.knee[1], body.knee[-1]
    s.line([kr + f * 0.075, kl + f * 0.075, kl - r * 0.075, kl - f * 0.075, kr - f * 0.075, kr + r * 0.075, kr + f * 0.075],
           0.022, "load")
    for side in (1, -1):
        sh = body.shoulder[side]
        body.arm(side, sh + vec(0.3, -0.26, -side * 0.08), unit(-Y + Z * side * 0.3))
    show(s, body)


# --- Tate press ----------------------------------------------------------------------------------------------------

@demo("x-tate-press", views=[FRONT(8), THREE_QUARTER(38, 18)],
      labels=("Bras tendus, haltères au-dessus de la poitrine", "Flexion des coudes vers l'extérieur", "Haltères sur la poitrine", "Extension"),
      timing=(0.6, 1.5, 0.4, 1.2), muscles=(["triceps"], ["chest", "shoulders"]))
def tate_press(p, s):
    floor(s, -1.2, 1.0)
    flat_bench(s, -0.8, 0.42, 0.43)
    body = lying_on_back(0.43, 0.0, head=14)
    feet_flat(body, (0.62, 0.27), (0.62, -0.27), pole=Y)
    angle = lerp(4.0, 108.0, p)
    flare = smooth(min(1.0, p * 1.6))
    for side in (1, -1):
        sh = body.shoulder[side]
        upper = unit(Y + Z * side * 0.42 * flare)        # the elbows spread out
        elbow = sh + upper * Body.UPPER
        fore = rotate(upper, X, -side * angle)           # the forearm folds toward the middle of the chest
        grip = elbow + fore * Body.LOWER
        body.arm_via(side, grip, elbow)
        sd = SIDE_RIGHT if side == 1 else SIDE_LEFT
        dumbbell(s, body.grip[side], X, side=sd)
    show(s, body)


# --- Groiners (pas de l'araignée) ---------------------------------------------------------------------------------

@demo("x-groiners", views=[PROFILE(), THREE_QUARTER(35, 14)], mode="loop", timing=1.2, samples=24, labels=(),
      muscles=(["quads"], []))
def groiners(p, s):
    floor(s, -0.6, 1.6, -0.7, 0.7)
    body = plank_on_toes(13.0, toe_x=-0.05, head=-10)
    hands_x = ((body.shoulder[1] + body.shoulder[-1]) / 2)[0]
    # One foot comes forward beside the same hand, then goes back while the other foot comes in.
    t = p % 1.0
    if t < 0.4:
        d = 1.0
    elif t < 0.5:
        d = 1.0 - smooth((t - 0.4) / 0.1)
    elif t < 0.9:
        d = 0.0
    else:
        d = smooth((t - 0.9) / 0.1)
    switching = (0.4 < t < 0.5) or (t > 0.9)
    for side in (1, -1):
        drive = d if side == 1 else 1.0 - d
        foot_back = body.ankle[side]
        beside = vec(hands_x - 0.1, 0.1, side * 0.42)
        hop = (0.14 if switching else 0.05) * math.sin(math.pi * drive)
        ankle = lerp(foot_back, beside, drive) + Y * hop
        k = smooth(drive)
        # knee out and up when the foot is forward beside the hand, down when it trails behind
        body.leg(side, ankle, pole=unit(lerp(X * 0.3 - Y * 0.9, Y * 0.8 + X * 0.2 + Z * side * 0.7, k)))
        toe_back = ankle + body.pelvis.f * 0.165 - body.pelvis.u * 0.06
        toe_side = ankle + unit(vec(0.9, -0.3, side * 0.4)) * 0.17
        body.foot_toward(side, lerp(toe_back, toe_side, smooth(drive)))
        body.arm(side, vec(hands_x, 0.025, side * 0.26), unit(-body.chest.u + body.chest.r * side * 0.4))
    show(s, body)
