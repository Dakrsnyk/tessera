"""Catalogue lot 06 (2026-11-23): Zercher squat, overhead squat, Smith pistol squat, box squat, inchworm, adductor,
forearm, side-lying, glute and strapped hamstring stretches, kettlebell windmill."""
import math

import numpy as np

from demos import demo, show
from engine import (ABOVE, FRONT, PROFILE, THREE_QUARTER, Body, Frame, SIDE_LEFT, SIDE_RIGHT, View, X, Y, Z, lerp,
                    posture, rotate, unit, vec)
from ex_legs import SQUAT, shoulder_mid, smooth, squat_body
from gear import TUBE, barbell, floor, kettlebell
from keys import keyed, pose
from poses import lying_on_back, solve, upright

STRETCH = ("Mise en place", "Entrée dans l'étirement", "Tiens 20 à 40 s en respirant", "Relâche doucement")


def mat(s, x0, x1, half=0.32):
    s.slab(vec(x0, 0.012, 0), vec(x1, 0.012, 0), Y, half * 2, 0.012, "pad")


# --- Squats ---------------------------------------------------------------------------------------------

def zercher_bar(b):
    """In the crook of the elbows, in front of the belly."""
    return b.chest.at(u=0.13, f=Body.D_TRUNK + 0.085)


@demo("x-zercher-squats", views=[PROFILE(), THREE_QUARTER(35, 12)],
      labels=("Barre dans le creux des coudes", "Descente, buste droit", "Cuisses parallèles", "Remontée"),
      timing=(0.6, 1.6, 0.4, 1.3), muscles=(["quads"], ["calves", "glutes", "hamstrings"]))
def zercher_squat(p, s):
    floor(s, -0.9, 0.9)
    body = squat_body(p, 2.0, 26.0, 0.5, load_point=zercher_bar)
    bar = zercher_bar(body)
    bar[2] = 0.0
    for side in (1, -1):
        # Forearms folded up on the chest, the hands joined; the elbows hold the bar.
        hand = body.chest.at(u=0.36, f=Body.D_TRUNK + 0.12, r=0.03 * side)
        elbow_hint = bar + Z * side * 0.17 + body.chest.f * 0.0
        body.arm_via(side, hand, elbow_hint)
    barbell(s, bar, Z)
    show(s, body)


def overhead_bar(b, k):
    mid = shoulder_mid(b)
    dz = 0.5 - Body.SH_HALF
    vert = math.sqrt(0.628 ** 2 - dz ** 2)
    a = math.radians(lerp(0.0, 10.0, k))
    return mid + (Y * math.cos(a) - X * math.sin(a)) * vert


@demo("x-overhead-squat", views=[PROFILE(), THREE_QUARTER(35, 12)],
      labels=("Barre bras tendus au-dessus de la tête", "Descente, bras verrouillés", "Squat profond, barre au-dessus des pieds", "Remontée"),
      timing=(0.6, 1.8, 0.5, 1.5), muscles=(["quads"], ["abs", "calves", "glutes", "hamstrings", "lowerBack", "shoulders", "triceps"]))
def overhead_squat(p, s):
    floor(s, -0.9, 0.9)
    k = smooth(p)
    body = squat_body(p, 4.0, 34.0, 0.42, load_point=lambda b: overhead_bar(b, k), half=0.22, toe_out=25.0, head=lerp(-2.0, -8.0, k))
    bar = overhead_bar(body, k)
    bar[2] = 0.0
    for side in (1, -1):
        body.arm(side, bar + Z * side * 0.5, unit(-X * 0.3 + Z * side * 0.2 - Y * 0.1))
    barbell(s, bar, Z, plate_r=0.2)
    show(s, body)


def smith(s, bar_y, x=0.0, height=2.1, half=0.7):
    """Smith machine: two vertical rails, the bar sliding between them."""
    for side in (1, -1):
        sd = SIDE_RIGHT if side == 1 else SIDE_LEFT
        z = side * half
        s.line([vec(x, 0.03, z), vec(x, height, z)], TUBE * 1.5, "frame", side=sd)
        s.line([vec(x - 0.35, 0.025, z), vec(x + 0.35, 0.025, z)], TUBE * 1.3, "frame", side=sd)
        s.line([vec(x, bar_y, z), vec(x, bar_y, z * 0.88)], 0.07, "metal", side=sd)
        s.disc(vec(x, bar_y, z * 0.88 - side * 0.06), Z, 0.13, "load", side=sd)
    s.line([vec(x, bar_y, -half * 0.88), vec(x, bar_y, half * 0.88)], 0.03, "metal")
    s.line([vec(x, height, -half), vec(x, height, half)], TUBE * 1.5, "frame")


@demo("x-smith-machine-pistol-squat", views=[PROFILE(), THREE_QUARTER(35, 12)],
      labels=("Sur une jambe sous la barre, l'autre tendue devant", "Descente sur la jambe d'appui", "Bas du squat, jambe libre tendue", "Remontée"),
      timing=(0.7, 2.0, 0.5, 1.8), muscles=(["quads"], ["calves", "glutes", "hamstrings"]))
def smith_pistol(p, s):
    floor(s, -0.9, 0.9)
    k = smooth(p)
    hip_y = lerp(0.948, 0.30, k)
    lean = lerp(3.0, 32.0, k)
    ankle_x = 0.05

    def build(px):
        return upright(hip_y, lean, pelvis_x=px, head=-lean * 0.4)

    def bar_x(px):
        b = build(px)
        return back_bar_point(b)[0]

    px = solve(bar_x, -1.0, 1.0, 0.0)
    body = build(px)
    body.foot_on_floor(1, (ankle_x, 0.09), 0.0, pole=X + Z * 0.15)
    # The free leg held straight out in front, from low at the start to level at the bottom.
    rise = math.radians(lerp(-30.0, 2.0, k))
    thigh = vec(math.cos(rise), math.sin(rise), 0.0)
    body.leg_dirs(-1, thigh, vec(math.cos(rise), math.sin(rise) - 0.05, 0.0))
    body.foot_relaxed(-1, plantar=-20)
    bar = back_bar_point(body)
    bar[0] = 0.0
    bar[2] = 0.0
    for side in (1, -1):
        body.arm(side, bar + Z * side * 0.3, unit(-Y - X * 0.6 + Z * side * 0.2))
    smith(s, bar[1])
    s.allow = {"cuisse gauche", "tibia gauche", "pied gauche"}
    show(s, body)


def back_bar_point(b):
    return b.neck - b.chest.f * 0.075 - b.chest.u * 0.02


@demo("x-box-squat", views=[PROFILE(), THREE_QUARTER(35, 12)],
      labels=("Debout, barre sur le dos, box derrière", "Hanches en arrière", "Assis sur le box : pause, gainé", "Remontée"),
      timing=(0.6, 1.7, 0.8, 1.3), muscles=(["quads"], ["calves", "glutes", "hamstrings", "lowerBack"]))
def box_squat(p, s):
    floor(s, -0.9, 0.9)

    def make(q):
        return squat_body(q, 6.0, 42.0, 0.5, load_point=back_bar_point, half=0.2, toe_out=15.0)

    body = make(p)
    low = make(1.0)
    top = 0.5 - Body.R_THIGH - 0.004
    bx = float(low.pelvis.o[0]) - 0.04
    s.box(vec(bx, top / 2, 0.0), X * 0.22, Y * top / 2, Z * 0.34, "pad", stroke=0.012, solid="le plateau du box")
    bar = back_bar_point(body)
    bar[2] = 0.0
    for side in (1, -1):
        body.arm(side, bar + Z * side * 0.42, unit(-Y - X * 0.6 + Z * side * 0.2))
    barbell(s, bar, Z)
    show(s, body)


# --- Inchworm --------------------------------------------------------------------------------------------

def inchworm_key(alpha, beta, hand_x, ankle_y=0.08, head=0.0):
    """Feet planted at x=0; the legs straight at alpha degrees from the floor, the torso at beta degrees."""
    a, b = math.radians(alpha), math.radians(beta)
    ankle = vec(0.0, ankle_y, 0.0)
    pelvis = ankle + vec(math.cos(a), math.sin(a), 0.0) * (Body.THIGH + Body.SHIN)
    toe_drop = 0.0 if ankle_y < 0.09 else 0.0
    legs = {}
    for sd in (1, -1):
        a_s = ankle + Z * 0.09 * sd
        toe = a_s + (vec(0.165, -0.06, 0.0) if ankle_y < 0.09 else vec(0.158, -0.078, 0.0))
        legs[sd] = (a_s, X, toe)
    arms = {sd: (vec(hand_x, 0.035, 0.2 * sd), -X * 0.5 + Z * sd * 0.5) for sd in (1, -1)}
    return {"pelvis": pelvis + Z * 0.0, "lean": 90.0 - beta, "head": head, "legs": legs, "arms": arms}


@demo("x-inchworm", views=[PROFILE(), THREE_QUARTER(35, 14)],
      labels=("Debout, jambes tendues", "Penche-toi, mains au sol", "Marche avec les mains jusqu'en planche", "Reviens : mains vers les pieds"),
      timing=(0.7, 3.2, 1.0, 3.0), muscles=(["hamstrings"], []))
def inchworm(p, s):
    floor(s, -0.7, 1.8)
    k0 = inchworm_key(90.0, 90.0, 0.3)
    k0["arms"] = {sd: (vec(0.04, 0.86, 0.2 * sd), -X) for sd in (1, -1)}
    k1 = inchworm_key(92.0, -48.0, 0.5, head=-10)
    k2 = inchworm_key(70.0, -40.0, 0.95, head=-10)
    k3 = inchworm_key(40.0, 6.0, 1.3, ankle_y=0.11, head=-15)
    k4 = inchworm_key(24.0, 24.0, 1.28, ankle_y=0.11, head=-20)
    keys = [(0.0, k0), (0.18, k1), (0.45, k2), (0.72, k3), (1.0, k4)]
    show(s, pose(keyed(p, keys)))


# --- Floor stretches ---------------------------------------------------------------------------------------

@demo("x-adductor-groin", views=[FRONT(20), THREE_QUARTER(-50, 30)], labels=STRETCH, timing=(0.8, 1.5, 3.0, 1.2),
      muscles=(["quads"], []))
def adductor_groin(p, s):
    floor(s, -0.9, 0.9, -0.7, 0.7)
    mat(s, -0.6, 0.8, 0.5)
    k = smooth(p)
    hip_y = Body.R_THIGH + 0.03
    body = Body(Frame(vec(0.0, hip_y, 0.0), X, Y).pitched(lerp(4.0, 16.0, k)), spine=lerp(2.0, 12.0, k), head=lerp(0.0, 12.0, k))
    for side in (1, -1):
        ankle = vec(lerp(0.2, 0.17, k), 0.045, 0.04 * side)
        # Knees start up and open out, then sink toward the floor.
        pole = unit(Z * side * lerp(0.6, 1.0, k) + Y * lerp(1.0, 0.12, k))
        body.leg(side, ankle, pole=pole)
        body.foot_toward(side, ankle + vec(-0.02, -0.0, -0.17 * side * 0.0) + X * 0.0 + Y * 0.0 - Z * side * 0.0 + vec(0.05, 0.0, 0.0))
        knee = body.knee[side]
        # Hands hold the feet, then move to the knees to press them down.
        grab = smooth(min(1.0, k / 0.5))
        target = lerp(ankle + Y * 0.04, knee + Y * 0.05, grab)
        body.arm(side, target, unit(Z * side + Y * 0.3 - X * 0.2))
    s.allow = {"cuisse droit", "cuisse gauche", "tibia droit", "tibia gauche", "le tapis"}
    show(s, body)


@demo("x-kneeling-forearm-stretch", views=[PROFILE(), THREE_QUARTER(35, 14)], labels=STRETCH, timing=(0.8, 1.8, 3.0, 1.4),
      muscles=(["forearms"], []))
def kneeling_forearm_stretch(p, s):
    floor(s, -0.9, 1.1, -0.6, 0.6)
    mat(s, -0.8, 0.9, 0.45)
    k = smooth(p)
    # Knees and hands stay put (fingers pointing back toward the knees); the hips sit back toward the heels and the
    # chest sinks, so the wrists open under the weight of the body.
    knee_y = Body.R_SHIN + 0.004

    def make(q, sy):
        d = lerp(0.0, 0.4, q)
        pelvis = vec(-d, knee_y + math.sqrt(Body.THIGH ** 2 - d ** 2), 0.0)

        def mid_y(tilt):
            b = Body(Frame(pelvis, -Y, X).pitched(tilt), head=-8.0)
            return float((b.shoulder[1][1] + b.shoulder[-1][1]) / 2)
        tilt = solve(mid_y, -60.0, 45.0, sy)
        return Body(Frame(pelvis, -Y, X).pitched(tilt), head=-8.0)

    start = make(0.0, 0.66)
    hand_x = float((start.shoulder[1][0] + start.shoulder[-1][0]) / 2) + 0.02
    body = make(k, lerp(0.66, 0.46, k))
    for side in (1, -1):
        knee = vec(0.0, knee_y, body.hip[side][2])
        body.leg_dirs(side, unit(knee - body.hip[side]), -X)
        body.foot_relaxed(side, plantar=60)
        body.arm(side, vec(hand_x, 0.04, side * 0.19), unit(-X * 0.4 + Z * side * 0.3))
    s.allow = {"le tapis"}
    show(s, body)


@demo("x-side-lying-floor-stretch", views=[PROFILE(12), THREE_QUARTER(-40, 28)], labels=STRETCH, timing=(0.8, 1.6, 3.0, 1.4),
      muscles=(["back"], []))
def side_lying_floor_stretch(p, s):
    floor(s, -1.4, 1.0, -0.7, 0.7)
    mat(s, -1.3, 0.9, 0.45)
    k = smooth(p)
    # Lying on the left side (head toward -x, belly toward +z): the lower knee bent in front, the upper leg straight
    # behind it; the upper arm goes overhead and the lower hand pulls its wrist.
    y0 = 0.215      # on the side of the (sculpted) hips and shoulder, not sunk in the mat
    body = Body(Frame(vec(0.0, y0, 0.0), Z, -X), head=lerp(0.0, -4.0, k))
    bottom, top = 1, -1
    body.leg_dirs(bottom, unit(vec(0.35, -0.1, 0.9)), unit(vec(0.9, -0.06, -0.15)))
    body.foot_relaxed(bottom, plantar=10)
    body.leg_dirs(top, unit(vec(0.97, -0.22, 0.0)), unit(vec(0.97, -0.22, 0.0)))
    body.foot_relaxed(top, plantar=10)
    sh_top, sh_bottom = body.shoulder[top], body.shoulder[bottom]
    rest_top = sh_top + vec(0.55, -0.2, 0.0) * 1.0
    over_top = vec(sh_top[0] - 0.59, 0.22, 0.0)
    hand_top = lerp(rest_top, over_top, k)
    body.arm(top, hand_top, unit(Z * 0.6 + Y * 0.8))
    under = vec(sh_bottom[0] - 0.5, 0.075, 0.02)
    hold = hand_top + vec(0.0, -0.03, -0.02)
    body.arm(bottom, lerp(under, hold, k), unit(Z * 0.6 - Y * 0.1))
    s.allow = {"le tapis", "tibia droit", "cuisse droit", "bras droit", "avant-bras droit", "pied droit"}
    show(s, body)


@demo("x-lying-glute", views=[THREE_QUARTER(-35, 25), PROFILE(10)], labels=STRETCH, timing=(0.8, 1.6, 3.0, 1.4),
      muscles=(["glutes"], []))
def lying_glute(p, s):
    floor(s, -1.0, 1.1, -0.6, 0.6)
    mat(s, -0.9, 1.0, 0.42)
    k = smooth(p)
    body = lying_on_back(0.024, 0.0, head=8)
    # Left foot flat, the knee up; the right ankle crosses over the left knee (figure 4). The left thigh then comes
    # toward the chest and the hands hold it.
    a = math.radians(lerp(56.0, 84.0, k))
    thigh = vec(math.cos(a), math.sin(a), 0.0)
    shin_a = math.radians(lerp(-50.0, -12.0, k))
    shin = vec(math.cos(shin_a), math.sin(shin_a), 0.0)
    body.leg_dirs(-1, thigh, shin)
    body.foot_relaxed(-1, plantar=lerp(0.0, 30.0, k))
    left_knee = body.knee[-1]
    body.leg(1, left_knee + vec(0.02, 0.075, 0.03), pole=unit(Z * 1.0 + Y * 0.5))
    body.foot_relaxed(1, plantar=-35)
    for side in (1, -1):
        sh = body.shoulder[side]
        rest = sh + vec(0.2, -0.05, side * 0.08)
        hold_pt = body.hip[-1] + thigh * 0.2 + vec(0.0, 0.0, -0.03 * side)
        tgt = lerp(rest, hold_pt, smooth(min(1.0, k / 0.5)))
        d = tgt - sh
        tgt = sh + d * min(1.0, 0.63 / float(np.linalg.norm(d)))
        body.arm(side, tgt, unit(Z * side * 0.6 + Y * 0.8))
    s.allow = {"le tapis", "cuisse droit", "tibia droit", "pied droit", "tibia gauche", "cuisse gauche"}
    show(s, body)


@demo("x-lying-hamstring", views=[PROFILE(10), THREE_QUARTER(-35, 24)], labels=STRETCH, timing=(0.8, 1.6, 3.0, 1.4),
      muscles=(["hamstrings"], ["calves"]))
def lying_hamstring(p, s):
    floor(s, -1.0, 1.1, -0.6, 0.6)
    mat(s, -0.9, 1.0, 0.42)
    k = smooth(p)
    body = lying_on_back(0.024, 0.0, head=8)
    # Left leg flat on the floor; the right leg rises straight toward the chest, a strap around the foot, both hands on it.
    a = math.radians(lerp(35.0, 82.0, k))
    leg = vec(math.cos(a), math.sin(a), 0.0)
    body.leg_dirs(-1, X, X)
    body.foot_relaxed(-1, plantar=-5)
    body.leg_dirs(1, leg, leg)
    body.foot_relaxed(1, plantar=lerp(5.0, -25.0, k))
    foot = (body.ankle[1] + body.toe[1]) / 2 + vec(0.0, 0.0, 0.0)
    sole = body.ankle[1] + (body.toe[1] - body.ankle[1]) * 0.7
    # The strap runs from the sole to the hands; the arms reach toward the foot, straight.
    mid = (body.shoulder[1] + body.shoulder[-1]) / 2
    grip_pt = None
    for side in (1, -1):
        sh = body.shoulder[side]
        d = sole - sh
        dist = float(np.linalg.norm(d))
        reach = 0.62
        hand = sh + d * min(1.0, reach / dist)
        hand[2] = side * 0.06
        body.arm(side, hand, unit(Z * side * 0.5 + Y * 0.6))
        if side == 1:
            grip_pt = hand
    hands_mid = (body.grip[1] + body.grip[-1]) / 2
    s.line([hands_mid, sole], 0.02, "load")
    s.line([sole + Z * 0.03, sole - Z * 0.03], 0.02, "load")
    s.allow = {"le tapis"}
    show(s, body)


@demo("x-kettlebell-windmill", views=[FRONT(8), THREE_QUARTER(55, 14)],
      labels=("Debout, kettlebell bras tendu au-dessus de la tête", "Hanche vers la kettlebell, buste incliné de côté", "Main libre le long de la jambe, regard sur la kettlebell", "Remontée en poussant les hanches"),
      timing=(0.8, 2.2, 0.8, 2.0), muscles=(["abs"], ["glutes", "hamstrings", "shoulders", "triceps"]))
def kettlebell_windmill(p, s):
    floor(s, -0.8, 0.8, -0.7, 0.7)
    k = smooth(p)
    # The kettlebell stays locked overhead above the right hand (+z side); the hip pushes out toward it while the
    # chest tips the other way, the free hand sliding down the straight left leg.
    base = Frame(vec(0.0, 0.905 + 0.0 * k, 0.07 * k), X, Y).rolled(-36.0 * k)
    body = Body(base, bend=-62.0 * k, head=lerp(0.0, -4.0, k))
    from poses import stance
    stance(body, 0.0, half_width=0.26, toe_out=30.0)
    sh = body.shoulder[1]
    top = sh + Y * 0.625
    body.arm(1, top, unit(-X * 0.3 + Z * 0.4))
    kettlebell(s, body.grip[1], unit(Y * 0.9 - X * 0.3), Z, side=SIDE_RIGHT)
    free = body.shoulder[-1]
    hang = free + vec(0.02, -0.62, -0.03)
    ankle, knee = body.ankle[-1], body.knee[-1]
    leg_pt = ankle + (knee - ankle) * 0.4 + X * 0.05 - Z * 0.0
    tgt = lerp(hang, leg_pt, k)
    d = tgt - free
    tgt = free + d * min(1.0, 0.63 / float(np.linalg.norm(d)))
    body.arm(-1, tgt, unit(-Z * 0.6 - X * 0.3))
    show(s, body)
