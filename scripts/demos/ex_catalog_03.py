"""Catalog lot 03 (2026-11-23): scaption, plate pinch, plate neck work, snatches, trap bar / deficit / rack pull deadlifts,
two-dumbbell row, renegade row, incline bench pull. Each one starts from the demonstration of its closest built-in."""
import math

import numpy as np

from demos import demo, show
from engine import (FRONT, PROFILE, THREE_QUARTER, Body, SIDE_LEFT, SIDE_RIGHT, X, Y, Z, lerp, rotate, unit, vec)
from ex_back import bent_over
from ex_legs import hanging_grip
from gear import PAD_T, PAD_W, TUBE, barbell, dumbbell, flat_bench, floor, kettlebell
from keys import keyed, pose, stage_segments
from poses import lying_on_front, plank_on_toes, solve, stance, upright


def smooth(t):
    t = min(1.0, max(0.0, t))
    return t * t * (3 - 2 * t)


def mid(body):
    return (body.shoulder[1] + body.shoulder[-1]) / 2


def sd(side):
    return SIDE_RIGHT if side == 1 else SIDE_LEFT


# --- Scaption ------------------------------------------------------------------------------------------------------

@demo("x-dumbbell-scaption", views=[FRONT(6), THREE_QUARTER(35, 10)],
      labels=("Haltères le long des cuisses, pouces vers le haut", "Élévation en V, 30° devant le plan latéral",
              "Bras tendus à hauteur d'épaule", "Descente lente"),
      timing=(0.7, 1.3, 0.5, 1.7))
def dumbbell_scaption(p, s):
    floor(s, -0.6, 1.0, -0.8, 0.8)
    body = upright(0.94, -2.0, shoulder_x=0.0, head=0)
    stance(body, 0.0, half_width=0.14)
    angle = lerp(-80.0, 2.0, p)
    for side in (1, -1):
        sh = body.shoulder[side]
        horiz = X * math.cos(math.radians(30)) + Z * side * math.sin(math.radians(30))
        d = unit(horiz * math.cos(math.radians(angle)) + Y * math.sin(math.radians(angle)))
        grip = sh + d * 0.61
        body.arm(side, grip, unit(-Y * 0.3 - Z * side * 0.6 + X * 0.1))
        axis = unit(rotate(horiz, Y, 0))      # thumbs up: the handle runs front to back
        dumbbell(s, grip, axis, side=sd(side))
    show(s, body)


# --- Standing plate pinch ------------------------------------------------------------------------------------------------

@demo("x-standing-olympic-plate-hand-squeeze", views=[THREE_QUARTER(35, 10), PROFILE()],
      labels=("Disque tenu par la tranche", "Serre le disque entre pouce et doigts", "Maintien du pincement", "Relâche"),
      timing=(0.8, 0.7, 1.4, 0.7))
def plate_pinch(p, s):
    floor(s, -0.6, 0.8, -0.7, 0.7)
    body = upright(0.94, -1.0, shoulder_x=0.0, head=0)
    stance(body, 0.0, half_width=0.14)
    squeeze = smooth(p)
    for side in (1, -1):
        sh = body.shoulder[side]
        grip = vec(sh[0] + 0.02, sh[1] - 0.6 + 0.02 * squeeze, side * 0.23)
        body.arm(side, grip, unit(-X * 0.3 + Z * side * 0.5))
        center = grip - Y * (0.2 - 0.012 * squeeze)
        s.disc(center, Z, 0.225, "load", side=sd(side))
        s.line([center - Z * 0.0, center + Z * 0.0 + X * 0.0001], 0.1, "metal", side=sd(side))
    show(s, body)


# --- Plate neck work, face down -------------------------------------------------------------------------------------------

@demo("x-lying-face-down-plate-neck-resistance", views=[PROFILE(), THREE_QUARTER(40, 14)],
      labels=("Tête relâchée vers le sol, disque sur la nuque", "Relève la tête lentement", "Cou en extension, dos immobile",
              "Retour lent"),
      timing=(0.8, 1.6, 0.8, 1.8))
def plate_neck(p, s):
    floor(s, -1.3, 1.0, -0.6, 0.6)
    top = 0.43
    pelvis_x = -0.3
    flat_bench(s, pelvis_x - 0.85, pelvis_x + 0.42, top)
    body = lying_on_front(top, pelvis_x, 1.0, head=lerp(48.0, -22.0, p))
    for side in (1, -1):
        body.leg_dirs(side, -X, -X)
        body.foot_relaxed(side, plantar=25)
    hf = body.head_frame
    center = body.head - hf.f * (Body.HEAD + 0.012) - hf.u * 0.045
    for side in (1, -1):
        grip = center + Z * side * 0.17
        grip = grip + hf.f * 0.0
        body.arm(side, grip, unit(Y * 0.5 + Z * side * 0.9 - X * 0.2))
    s.disc(center, hf.f, 0.225, "load")
    s.allow = {("bassin", "le banc"), ("cuisse droit", "le banc"), ("cuisse gauche", "le banc")}
    show(s, body)


# --- Barbell-less helpers: a deadlift whose bar starts at a given height, from a given ground --------------------------------

def lift_between(p, lean_start, bar_start, bar_top, half, toe_out, grip_half, ground=0.0, ahead=0.02, lo=0.3, hi=1.2, reach=0.625):
    """lift_from_floor with a chosen start height of the bar and of the ground under the feet (all heights absolute)."""
    k = smooth(p)
    bar_y = lerp(bar_start, bar_top, k)
    lean = lean_start * (1 - smooth(min(1.0, p * 1.05)) ** 1.6)

    def make(hip_y, px):
        return upright(hip_y, lean, pelvis_x=px, head=-lean * 0.5)

    def grip_y(hip_y):
        return mid(make(hip_y, 0.0))[1] - reach

    hip_y = solve(grip_y, lo, hi, bar_y + 0.012)
    px = solve(lambda x: mid(make(hip_y, x))[0] + ahead, -1.2, 1.0, 0.0)
    body = make(hip_y, px)
    stance(body, -0.06, half_width=half, toe_out=toe_out, floor=ground)
    bar = vec(0.0, bar_y, 0.0)
    for side in (1, -1):
        body.arm(side, bar + Z * side * grip_half, unit(-X * 1.0 + Z * side * 0.2))
    return body, bar


# --- Trap bar deadlift ---------------------------------------------------------------------------------------------------

def trap_bar(s, handles_y):
    y = handles_y
    hexagon = [vec(-0.5, y, 0.0), vec(-0.3, y, -0.27), vec(0.3, y, -0.27), vec(0.5, y, 0.0), vec(0.3, y, 0.27),
               vec(-0.3, y, 0.27), vec(-0.5, y, 0.0)]
    s.line(hexagon, 0.034, "metal")
    for e in (1, -1):
        s.line([vec(0.5 * e, y, 0.0), vec(0.82 * e, y, 0.0)], 0.05, "metal")
        s.disc(vec(0.62 * e, y, 0.0), X, 0.225, "load")


@demo("x-trap-bar-deadlift", views=[PROFILE(), THREE_QUARTER(40, 12)],
      labels=("Debout dans la barre, dos plat, prise neutre", "Poussée des jambes, poids près du corps",
              "Debout, hanches et genoux tendus", "Descente contrôlée"),
      timing=(0.7, 1.5, 0.6, 1.6))
def trap_bar_deadlift(p, s):
    floor(s, -1.0, 1.0, -0.9, 0.9)
    body, bar = lift_between(p, 48.0, 0.235, 0.84, 0.15, 6.0, 0.27)
    trap_bar(s, bar[1])
    show(s, body)


# --- Deficit deadlift --------------------------------------------------------------------------------------------------

@demo("x-deficit-deadlift", views=[PROFILE(), THREE_QUARTER(35, 12)],
      labels=("Sur la plateforme, barre plus bas qu'au sol habituel", "Poussée des jambes, barre collée",
              "Debout, hanches tendues", "Descente contrôlée"),
      timing=(0.7, 1.6, 0.6, 1.7))
def deficit_deadlift(p, s):
    plat = 0.08
    floor(s, -0.9, 0.9)
    s.box(vec(0.0, plat / 2, 0.0), X * 0.4, Y * plat / 2, Z * 0.42, "pad")
    body, bar = lift_between(p, 64.0, 0.235, plat + 0.84, 0.15, 8.0, 0.25, ground=plat)
    barbell(s, bar, Z)
    show(s, body)


# --- Rack pull -----------------------------------------------------------------------------------------------------------

@demo("x-rack-pulls", views=[PROFILE(), THREE_QUARTER(40, 12)],
      labels=("Barre sur les taquets sous les genoux, dos plat", "Extension des hanches, barre sur les cuisses",
              "Debout, omoplates serrées", "Descente contrôlée jusqu'aux taquets"),
      timing=(0.7, 1.3, 0.6, 1.5))
def rack_pull(p, s):
    floor(s, -1.0, 1.0, -0.9, 0.9)
    start = 0.5
    body, bar = lift_between(p, 40.0, start, 0.84, 0.15, 8.0, 0.22)
    barbell(s, bar, Z)
    # Power rack: four posts, a pair of pins under the bar at its starting height.
    for z in (0.56, -0.56):
        side = sd(1 if z > 0 else -1)
        for x in (-0.3, 0.3):
            s.line([vec(x, 0.03, z), vec(x, 1.6, z)], TUBE * 1.3, "frame", side=side)
        s.line([vec(-0.3, 1.6, z), vec(0.3, 1.6, z)], TUBE * 1.3, "frame", side=side)
        s.line([vec(-0.3, start - 0.045, z), vec(0.3, start - 0.045, z)], TUBE * 1.5, "load", side=side)
    show(s, body)


# --- Bent-over two-dumbbell row ------------------------------------------------------------------------------------------

@demo("x-bent-over-two-dumbbell-row", views=[PROFILE(), THREE_QUARTER(35, 12)],
      labels=("Buste penché, dos plat, haltères tendus", "Tirage des coudes vers les hanches",
              "Omoplates serrées, haltères au ventre", "Descente contrôlée"),
      timing=(0.7, 1.1, 0.5, 1.6))
def two_dumbbell_row(p, s):
    floor(s, -1.0, 1.0)
    body = bent_over(58.0, 0.83)
    sh = mid(body)
    for side in (1, -1):
        hang = vec(sh[0] + 0.02, sh[1] - 0.62, side * 0.19)
        top = body.chest.at(u=0.02, f=Body.W_TORSO / 2 + 0.03, r=side * 0.19)
        top[2] = side * 0.19
        grip = lerp(hang, top, p)
        body.arm(side, grip, unit(-X * 1.0 + Y * 0.6 + body.chest.r * side * 0.35))
        dumbbell(s, grip, X, side=sd(side))
    show(s, body)


# --- Alternating renegade row ----------------------------------------------------------------------------------------------

@demo("x-alternating-renegade-row", views=[THREE_QUARTER(35, 16), PROFILE()], mode="loop", timing=3.6, samples=36,
      labels=())
def renegade_row(p, s):
    floor(s, -0.9, 1.6, -0.8, 0.8)
    hand_y = 0.27
    hand_z = 0.17

    def make(theta):
        body = plank_on_toes(theta, toe_x=0.0, head=-8)
        for side in (1, -1):
            ankle = body.ankle[side] + Z * side * 0.1
            body.leg(side, ankle, pole=-Y)
            body.foot_toward(side, ankle + body.pelvis.f * 0.165 - body.pelvis.u * 0.06)
        return body

    theta = solve(lambda t: mid(make(t))[1], -10.0, 80.0, hand_y + 0.6)
    body = make(theta)
    hx = mid(body)[0]
    # The row alternates: the right arm during the first half, the left in the second.
    pulls = {1: math.sin(math.pi * min(1.0, p / 0.5)) if p < 0.5 else 0.0,
             -1: math.sin(math.pi * (p - 0.5) / 0.5) if p >= 0.5 else 0.0}
    for side in (1, -1):
        rest = vec(hx, hand_y, side * hand_z)
        row = body.chest.at(u=0.12, f=0.07, r=side * 0.21)
        k = smooth(pulls[side])
        grip = lerp(rest, row, k)
        pole = unit(lerp(-body.chest.f * 0.2 + Z * side * 0.3, -body.chest.f * 0.6 - body.chest.u * 0.7 + Z * side * 0.4, k))
        body.arm(side, grip, pole)
        kettlebell(s, grip, -Y, Z, side=sd(side))
    show(s, body)


# --- Incline bench pull (face down, chest on a 30° bench) ----------------------------------------------------------------

@demo("x-incline-bench-pull", views=[PROFILE(), THREE_QUARTER(40, 14)],
      labels=("Allongé face au banc, bras pendants", "Tirage des coudes vers le haut", "Omoplates serrées, coudes au-dessus du dos",
              "Descente contrôlée"),
      timing=(0.7, 1.2, 0.6, 1.6))
def incline_bench_pull(p, s):
    from engine import Frame
    floor(s, -1.0, 1.3, -0.7, 0.7)
    angle = 30.0
    along = vec(math.cos(math.radians(angle)), math.sin(math.radians(angle)), 0.0)
    normal = vec(-math.sin(math.radians(angle)), math.cos(math.radians(angle)), 0.0)
    low = vec(-0.1, 0.46, 0.0)
    top = low + along * 1.0
    s.slab(low, top, normal, PAD_W, PAD_T, "pad", solid="le banc")
    # Frame: floor rails, a post under the low end and one under the high end.
    s.line([vec(-0.35, 0.03, 0), vec(0.9, 0.03, 0)], TUBE, "frame")
    foot_x = [-0.35, 0.9]
    for x in foot_x:
        s.line([vec(x, 0.03, -0.25), vec(x, 0.03, 0.25)], TUBE, "frame")
    for t in (0.1, 0.9):
        a = low + along * t - normal * PAD_T
        s.line([a, vec(a[0], 0.03, 0)], TUBE * 1.2, "frame")
    # The body lies on the pad, the pelvis near the low end, the head beyond the top.
    point = low + along * 0.14
    origin = point + normal * (Body.W_TORSO / 2 + 0.004)
    body = Body(Frame(origin, -normal, along), head=-12)
    for side in (1, -1):
        ankle = vec(-0.68, Body.ANKLE, side * 0.17)
        body.leg(side, ankle, pole=-Y)
        body.foot_toward(side, ankle - X * 0.165 - Y * 0.06)
    for side in (1, -1):
        sh = body.shoulder[side]
        hang = vec(sh[0] + 0.02, sh[1] - 0.6, side * 0.26)
        row = sh - along * 0.3 + normal * 0.03
        row[2] = side * 0.27
        grip = lerp(hang, row, p)
        body.arm(side, grip, unit(normal * 0.7 - along * 0.5 + Z * side * 0.5))
        dumbbell(s, grip, X, side=sd(side))
    show(s, body)


# --- Snatch ------------------------------------------------------------------------------------------------------------

SN_GRIP = 0.45
SN_REACH = 0.625
SN_HANG = math.sqrt(SN_REACH ** 2 - (SN_GRIP - Body.SH_HALF) ** 2)


def overhead_point(probe_mid, x):
    return vec(x, probe_mid[1] + math.sqrt(SN_REACH ** 2 - (SN_GRIP - Body.SH_HALF) ** 2), 0.0)


def foot(toe_x, z, heel=0.0):
    toe = vec(toe_x, 0.02, z)
    back = rotate(-X * 0.165 + Y * 0.06, Z, -heel)
    return toe + back, toe


def snatch_key(bar, pelvis_y, lean, px, head, heel=0.0, shrug=0.0, half=0.17, poles=None):
    legs = {}
    for side in (1, -1):
        ankle, toe = foot(0.105 - 0.0, side * half, heel)
        legs[side] = (ankle, unit(X + Z * side * 0.1), toe)
    pole_r, pole_l = poles if poles else (unit(-X + Z * 0.2), unit(-X - Z * 0.2))
    return {"pelvis": vec(px, pelvis_y, 0.0), "lean": lean, "head": head, "shrug": shrug,
            "arms": {1: (bar + Z * SN_GRIP, pole_r), -1: (bar - Z * SN_GRIP, pole_l)}, "legs": legs}


def snatch_keys():
    def lean_at(p, lean0=55.0):
        return lean0 * (1 - smooth(min(1.0, p * 1.05)) ** 1.6)

    fb, fbar = lift_between(0.0, 55.0, 0.235, 0.84, 0.17, 8.0, SN_GRIP, reach=SN_HANG)
    kb, kbar = lift_between(0.45, 55.0, 0.235, 0.84, 0.17, 8.0, SN_GRIP, reach=SN_HANG)
    k0 = snatch_key(fbar, fb.pelvis.o[1], 55.0, fb.pelvis.o[0], -27.0)
    k1 = snatch_key(kbar, kb.pelvis.o[1], lean_at(0.45), kb.pelvis.o[0], -lean_at(0.45) * 0.5)
    pull_poles = (unit(Y * 0.3 + Z * 0.8), unit(Y * 0.3 - Z * 0.8))
    k2 = snatch_key(vec(0.06, 1.2, 0.0), 1.0, -4.0, -0.02, 0.0, heel=35.0, shrug=0.07, poles=pull_poles)
    # Catch: overhead squat, wide stance, bar above the middle of the feet.
    probe = upright(0.5, 30.0, pelvis_x=0.0, head=-15)
    px = 0.05 - mid(probe)[0]
    bar3 = overhead_point(mid(probe), 0.0)
    up_poles = (unit(Y + Z * 0.4 - X * 0.2), unit(Y - Z * 0.4 - X * 0.2))
    k3 = snatch_key(bar3, 0.5, 30.0, px, -15.0, half=0.26, poles=up_poles)
    probe = upright(0.95, 0.0, pelvis_x=0.0, head=0)
    bar4 = overhead_point(mid(probe), -0.01)
    k4 = snatch_key(bar4, 0.95, 0.0, 0.0, 0.0, half=0.2, poles=up_poles)
    # Lowering: the bar comes down in front of the face, then to the hips.
    probe = upright(0.95, 0.0, pelvis_x=0.0, head=0)
    bar4b = mid(probe) + vec(0.3, 0.08, 0.0)
    k4b = snatch_key(bar4b, 0.95, 0.0, 0.0, 0.0, half=0.17, poles=(unit(-X + Z * 0.5), unit(-X - Z * 0.5)))
    hang = vec(0.03, mid(probe)[1] - math.sqrt(SN_REACH ** 2 - (SN_GRIP - Body.SH_HALF) ** 2) + 0.0, 0.0)
    k5 = snatch_key(hang, 0.95, 4.0, -0.02, 0.0, half=0.17)
    return [(0.0, k0), (0.14, k1), (0.26, k2), (0.38, k3), (0.52, k4), (0.64, k4b), (0.8, k5), (1.0, k0)]


SNATCH_KEYS = snatch_keys()


@demo("x-snatch", views=[PROFILE(), THREE_QUARTER(35, 12)], mode="loop", samples=48,
      labels=("Barre au sol, prise large", "Tirage des jambes", "Extension explosive", "Réception en squat, barre au-dessus",
              "Debout, bras tendus", "La barre descend devant", "Retour aux hanches", "Retour au sol"),
      segments=[(0.5, 0.0, 0.0, 0, 1)] + stage_segments(SNATCH_KEYS, [0.7, 0.35, 0.3, 0.6, 0.6, 0.6, 0.8], [1, 2, 3, 4, 5, 6, 7]))
def snatch(p, s):
    floor(s, -0.9, 0.9, -0.9, 0.9)
    body = pose(keyed(p, SNATCH_KEYS))
    bar = (body.grip[1] + body.grip[-1]) / 2
    bar[2] = 0.0
    barbell(s, bar, Z)
    show(s, body)


# --- One-arm kettlebell split snatch ----------------------------------------------------------------------------------

def kb_key(pelvis, lean, head, legs, grip_rel, down, left_rel, poles, heel_free=True):
    probe = upright(pelvis[1], lean, pelvis_x=pelvis[0], head=head)
    grip = probe.shoulder[1] + grip_rel
    left = probe.shoulder[-1] + left_rel
    return {"pelvis": pelvis, "lean": lean, "head": head, "shrug": 0.0,
            "arms": {1: (grip, poles[0]), -1: (left, poles[1])}, "legs": legs, "down": unit(down)}


def kb_legs(front, back, z_front, z_back, heel_back=0.0):
    a1, t1 = foot(front, z_front)
    a2, t2 = foot(back, z_back, heel_back)
    return {1: (a1, unit(X), t1), -1: (a2, unit(X), t2)}


def kb_keys():
    hike = kb_key(vec(-0.2, 0.8, 0.0), 62.0, -35.0, kb_legs(0.1, 0.1, 0.2, -0.2), vec(-0.25, -0.57, 0.04),
                  -Y * 0.5 - X * 0.3, vec(0.0, -0.4, -0.3), (unit(-X * 0.3 + Z * 0.5), unit(-X * 0.5)))
    pull = kb_key(vec(-0.04, 0.955, 0.0), -3.0, 0.0, kb_legs(0.1, 0.1, 0.17, -0.17), vec(0.2, 0.22, 0.1),
                  -Y * 0.8 + X * 0.3, vec(0.1, -0.35, -0.4), (unit(Z * 0.8 + Y * 0.4 - X * 0.2), unit(-X * 0.5 + Y * 0.0)))
    catch = kb_key(vec(0.0, 0.72, 0.0), 0.0, 0.0, kb_legs(0.55, -0.5, 0.12, -0.12, heel_back=50.0), vec(0.02, 0.62, 0.04),
                   -X * 0.9 - Y * 0.35, vec(0.05, -0.28, -0.5), (unit(-X * 0.6 + Z * 0.3), unit(-X * 0.5)))
    return [(0.0, hike), (0.5, pull), (1.0, catch)]


KB_KEYS = kb_keys()


@demo("x-one-arm-kettlebell-split-snatch", views=[PROFILE(), THREE_QUARTER(35, 12)],
      labels=("Kettlebell entre les jambes, charnière de hanche", "Extension explosive des hanches",
              "Réception en fente, bras tendu au-dessus", "Retour contrôlé"),
      timing=(0.6, 1.0, 0.8, 1.3))
def kb_split_snatch(p, s):
    floor(s, -1.0, 1.1, -0.7, 0.7)
    params = keyed(p, KB_KEYS)
    body = pose(params)
    kettlebell(s, body.grip[1], params["down"], Z, side=SIDE_RIGHT)
    show(s, body)
