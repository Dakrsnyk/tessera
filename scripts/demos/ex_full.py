"""Full body: burpee, thruster, cleans, Turkish get-up, wall ball, battle ropes, sled push, bear crawl."""
import math

import numpy as np

from cyclic import walk_cycle
from demos import demo, show
from engine import (ABOVE, BACK, FRONT, PROFILE, THREE_QUARTER, Body, Frame, SIDE_LEFT, SIDE_RIGHT, View, X, Y, Z,
                    lerp, posture, rotate, unit, vec)
from gear import TUBE, barbell, floor, foot_bar, kettlebell
from keys import blend, flat_foot, keyed, pose, stage_segments
from poses import placed, plank_on_toes, solve, stance, upright


def smooth(t):
    t = min(1.0, max(0.0, t))
    return t * t * (3 - 2 * t)


def mid(body):
    return (body.shoulder[1] + body.shoulder[-1]) / 2


def feet_params(x=-0.04, half=0.12, toe_out=6.0):
    legs = {}
    for side in (1, -1):
        ankle, toe = flat_foot(x, side * half)
        legs[side] = (ankle, unit(X + Z * side * 0.15), toe)
    return legs


# --- Burpee ---------------------------------------------------------------------------------------

def burpee_keys():
    stand = {"pelvis": vec(0.0, 0.94, 0.0), "lean": 0.0, "head": 0.0,
             "arms": {1: (vec(0.02, 0.85, 0.2), -X), -1: (vec(0.02, 0.85, -0.2), -X)},
             "legs": feet_params()}
    squat = {"pelvis": vec(-0.12, 0.42, 0.0), "lean": 65.0, "head": -25.0,
             "arms": {1: (vec(0.42, 0.04, 0.24), -X + Z * 0.3), -1: (vec(0.42, 0.04, -0.24), -X - Z * 0.3)},
             "legs": feet_params(half=0.15)}
    probe = plank_on_toes(18.5, toe_x=0.0, head=-8)
    shift = 0.42 - mid(probe)[0]
    plank = {"pelvis": probe.pelvis.o + X * shift, "lean": 90.0 - 18.5, "head": -20.0,
             "arms": {1: (vec(0.42, 0.04, 0.24), -X + Z * 0.3), -1: (vec(0.42, 0.04, -0.24), -X - Z * 0.3)},
             "legs": {s: (probe.ankle[s] + X * shift, X - Y * 0.3, probe.toe[s] + X * shift) for s in (1, -1)}}
    jump = {"pelvis": vec(0.0, 1.12, 0.0), "lean": 0.0, "head": -5.0,
            "arms": {1: (vec(0.04, 2.18, 0.26), -X), -1: (vec(0.04, 2.18, -0.26), -X)},
            "legs": {s: (vec(-0.02, 0.27, s * 0.12), X, vec(0.09, 0.15, s * 0.12)) for s in (1, -1)}}
    return [(0.0, stand), (0.2, squat), (0.4, plank), (0.6, squat), (0.8, jump), (1.0, stand)]


BURPEE_KEYS = burpee_keys()


@demo("burpee", views=[PROFILE(), THREE_QUARTER(35, 12)], mode="loop", samples=41,
      muscles=(["quads", "chest", "shoulders"], ["glutes", "abs", "triceps"]),
      labels=("Debout", "Accroupi, mains au sol", "Pieds en arrière : planche", "Pieds ramenés", "Saut, bras en l'air",
              "Réception souple"),
      segments=[(0.3, 0.0, 0.0, 0, 1)] + stage_segments(BURPEE_KEYS, [0.5, 0.35, 0.35, 0.4, 0.45], [1, 2, 3, 4, 5]))
def burpee(p, s):
    floor(s, -1.4, 0.9)
    params = keyed(p, BURPEE_KEYS)
    # The feet leave the floor while jumping back, in, and up.
    for (a, b) in ((0.2, 0.4), (0.4, 0.6)):
        if a < p < b:
            t = (p - a) / (b - a)
            lift = 0.2 * math.sin(math.pi * t)
            params = dict(params)
            params["legs"] = {k: (v[0] + Y * lift, v[1], v[2] + Y * lift) for k, v in params["legs"].items()}
    show(s, pose(params))


# --- Thruster -----------------------------------------------------------------------------------------

@demo("thruster", views=[PROFILE(), THREE_QUARTER(35, 12)],
      labels=("Squat avant, barre aux épaules", "Remontée explosive et poussée", "Barre au-dessus de la tête", "Retour aux épaules et squat"),
      timing=(0.4, 1.1, 0.4, 1.3))
def thruster(p, s):
    from ex_legs import front_bar, squat_body
    floor(s, -0.9, 0.9)
    up = smooth(min(1.0, p / 0.55))
    press = smooth(max(0.0, (p - 0.4) / 0.6))
    body = squat_body(1 - up, 2.0, 22.0, 0.52, load_point=front_bar, head=0)
    rack = front_bar(body)
    rack[2] = 0.0
    top = mid(body) + Y * math.sqrt(0.63 ** 2 - (0.26 - Body.SH_HALF) ** 2) - X * 0.02
    top[2] = 0.0
    bar = lerp(rack, top, press)
    for side in (1, -1):
        pole = unit(lerp(X * 1.0 + Y * 0.3 + Z * side * 0.3, -Y + X * 0.6 + Z * side * 0.4, press))
        body.arm(side, bar + Z * side * 0.26, pole)
    barbell(s, bar, Z, plate_r=0.2)
    show(s, body)


# --- Power clean -------------------------------------------------------------------------------------

def clean_key(bar, pelvis_y, lean, heel=0.0, shrug=0.0, poles=None, head=None, px=None, stance_x=-0.06, half=0.15):
    """A clean position: the body placed so the bar is where it should be relative to it."""
    hd = head if head is not None else -lean * 0.5
    if px is None:
        def ax(x):
            b = upright(pelvis_y, lean, pelvis_x=x, head=hd)
            return mid(b)[0]
        px = solve(ax, -1.2, 1.0, bar[0] + 0.02)
    legs = {}
    for side in (1, -1):
        toe = vec(stance_x + 0.165, 0.02, side * half)
        back = -X * 0.165 + Y * 0.06
        back = rotate(back, Z, -heel)
        ankle = toe + back
        legs[side] = (ankle, unit(X + Z * side * 0.1), toe)
    pole_r, pole_l = poles if poles else (unit(-X + Z * 0.2), unit(-X - Z * 0.2))
    return {"pelvis": vec(px, pelvis_y, 0.0), "lean": lean, "head": hd, "shrug": shrug,
            "arms": {1: (bar + Z * 0.27, pole_r), -1: (bar - Z * 0.27, pole_l)}, "legs": legs, "bar": bar}


def clean_keys():
    from ex_legs import lift_from_floor
    floor_b, floor_bar = lift_from_floor(0.0, 50.0, 0.84, 0.15, 8.0, 0.27)
    knee_b, knee_bar = lift_from_floor(0.45, 50.0, 0.84, 0.15, 8.0, 0.27)
    k0 = clean_key(floor_bar, floor_b.pelvis.o[1], 50.0, px=floor_b.pelvis.o[0])
    k1 = clean_key(knee_bar, knee_b.pelvis.o[1], knee_b.pelvis.u[0] and math.degrees(math.asin(max(-1, min(1, knee_b.pelvis.u[0])))),
                   px=knee_b.pelvis.o[0])
    k2 = clean_key(vec(0.04, 1.02, 0.0), 1.02, -6.0, heel=32.0, shrug=0.07,
                   poles=(unit(Y + Z * 0.8), unit(Y - Z * 0.8)), head=0.0, px=-0.02)
    # Catch: quarter squat, bar on the front of the shoulders, elbows high and forward.
    probe = upright(0.8, 14.0, pelvis_x=-0.1, head=-4)
    rack = probe.chest.at(u=Body.THORAX - 0.06, f=Body.W_TORSO / 2 + 0.06)
    rack[2] = 0.0
    k3 = clean_key(rack, 0.8, 14.0, poles=(unit(X + Y * 0.4 + Z * 0.3), unit(X + Y * 0.4 - Z * 0.3)), head=-4, px=-0.1,
                   half=0.18)
    stand = upright(0.95, 0.0, pelvis_x=-0.06, head=0)
    rack2 = stand.chest.at(u=Body.THORAX - 0.06, f=Body.W_TORSO / 2 + 0.06)
    rack2[2] = 0.0
    k4 = clean_key(rack2, 0.95, 0.0, poles=(unit(X + Y * 0.4 + Z * 0.3), unit(X + Y * 0.4 - Z * 0.3)), head=0, px=-0.06,
                   half=0.18)
    hang = upright(0.95, 2.0, pelvis_x=-0.04, head=0)
    hang_bar = mid(hang) + vec(0.04, -0.62, 0.0)
    hang_bar[2] = 0.0
    k5 = clean_key(hang_bar, 0.95, 2.0, head=0, px=-0.04)
    return [(0.0, k0), (0.18, k1), (0.32, k2), (0.45, k3), (0.6, k4), (0.8, k5), (1.0, k0)]


CLEAN_KEYS = clean_keys()


@demo("power-clean", views=[PROFILE(), THREE_QUARTER(35, 12)], mode="loop", samples=43,
      labels=("Barre au sol, dos plat", "Premier tirage", "Extension explosive", "Réception, barre sur les épaules", "Debout",
              "Retour aux hanches", "Retour au sol"),
      segments=[(0.5, 0.0, 0.0, 0, 1)] + stage_segments(CLEAN_KEYS, [0.7, 0.3, 0.3, 0.6, 0.9, 0.9], [1, 2, 3, 4, 5, 6]))
def power_clean(p, s):
    floor(s, -0.9, 0.9)
    params = keyed(p, CLEAN_KEYS)
    body = pose(params)
    bar = (body.grip[1] + body.grip[-1]) / 2     # the bar always sits in the hands
    bar[2] = 0.0
    barbell(s, bar, Z)
    show(s, body)


@demo("kb-clean", views=[PROFILE(), THREE_QUARTER(35, 12)],
      labels=("Kettlebell entre les jambes", "Extension des hanches", "Kettlebell en rack, sur l'avant-bras", "Retour en balancier"),
      timing=(0.4, 0.8, 0.6, 0.9))
def kb_clean(p, s):
    floor(s, -0.9, 1.0)
    k = smooth(p)
    lean = lerp(55.0, 0.0, smooth(min(1.0, p * 1.4)))
    hip_y = lerp(0.84, 0.94, smooth(min(1.0, p * 1.4)))

    def ax(x):
        return mid(upright(hip_y, lean, pelvis_x=x, head=-lean * 0.5))[0]

    px = solve(ax, -1.2, 1.0, lerp(0.12, 0.0, k))
    body = upright(hip_y, lean, pelvis_x=px, head=-lean * 0.5)
    stance(body, -0.06, half_width=0.2, toe_out=12.0)
    sh = body.shoulder[1]
    # From the hike (arm straight, between the legs) close to the body, to the rack (hand at the chin).
    hike = mid(body) + vec(-0.25, -0.58, 0.04)
    rack = body.chest.at(u=0.36, f=0.13, r=0.02)
    path_mid = body.pelvis.at(u=0.2, f=0.22, r=0.05)
    if p < 0.5:
        grip = lerp(hike, path_mid, smooth(p / 0.5))
    else:
        grip = lerp(path_mid, rack, smooth((p - 0.5) / 0.5))
    body.arm(1, grip, unit(lerp(-X, -Y - X * 0.1, k)))
    body.arm(-1, body.shoulder[-1] + unit(vec(lerp(-0.2, 0.25, k), -1.0, -0.25)) * 0.6, unit(-X))
    fore = unit(grip - body.elbow[1])
    down = unit(lerp(unit(grip - sh), unit(-body.chest.f * 0.4 - fore * 0.4 + body.chest.r * 0.6), k))
    kettlebell(s, grip, down, body.chest.r, side=SIDE_RIGHT)
    show(s, body)


# --- Turkish get-up ----------------------------------------------------------------------------------

def tgu_keys():
    """Lying on the back (head toward -x), right arm holding the kettlebell straight up, right knee bent;
    up to the elbow, the hand, the half-kneeling position and standing, facing -z (the left side)."""
    kb_up = 0.62
    keys = []
    # Each key: pelvis frame (f, u), pelvis position, the left support (elbow/hand) and legs.
    lying = {"pelvis": vec(0.0, Body.W_TORSO / 2 + 0.006, 0.0), "frame": (Y, -X), "spine": 0.0, "head": 20.0,
             "legs": {1: (vec(0.36, Body.ANKLE, 0.16), unit(Y + X * 0.2), vec(0.52, 0.02, 0.18)),
                      -1: (vec(0.82, 0.075, -0.38), unit(Y), vec(0.86, 0.21, -0.42))},
             "left": vec(-0.3, 0.035, -0.55), "kb": 0.0}
    elbow = {"pelvis": vec(0.0, Body.W_TORSO / 2 + 0.03, 0.0), "frame": (unit(Y * 0.75 + Z * -0.25 + X * 0.35), unit(-X * 0.85 + Y * 0.45 - Z * 0.2)),
             "spine": 10.0, "head": 20.0,
             "legs": lying["legs"], "left": vec(-0.36, 0.035, -0.42), "kb": 0.0}
    hand = {"pelvis": vec(0.02, Body.W_TORSO / 2 + 0.035, 0.0), "frame": (unit(Y * 0.45 + Z * -0.35 + X * 0.6), unit(-X * 0.55 + Y * 0.8 - Z * 0.25)),
            "spine": 10.0, "head": 12.0,
            "legs": lying["legs"], "left": vec(-0.27, 0.035, -0.41), "kb": 0.0}
    bridge = {"pelvis": vec(0.16, 0.45, -0.05), "frame": (unit(Y * 0.55 - Z * 0.35 + X * 0.5), unit(-X * 0.7 + Y * 0.55 - Z * 0.3)),
              "spine": 0.0, "head": 8.0,
              "legs": {1: (vec(0.36, Body.ANKLE, 0.16), unit(Y + X * 0.3), vec(0.52, 0.02, 0.18)),
                       -1: (vec(0.75, 0.08, -0.32), unit(Y + X * 0.2), vec(0.8, 0.25, -0.36))},
              "left": vec(-0.27, 0.035, -0.41), "kb": 0.0}
    # Low sweep: the left leg passes under, the torso still leaning over the supporting hand.
    kneel = {"pelvis": vec(0.12, 0.48, -0.1), "frame": (unit(-Z + X * 0.3 - Y * 0.4), unit(Y * 0.8 - X * 0.9 - Z * 0.45)),
             "spine": 6.0, "head": 0.0,
             "legs": {1: (vec(0.3, Body.ANKLE, 0.12), unit(-Z + X * 0.4), vec(0.3, 0.02, -0.05)),
                      -1: (vec(0.6, 0.1, 0.0), unit(-Z * 0.6 - Y), vec(0.75, 0.03, 0.02))},
             "left": vec(-0.27, 0.035, -0.41), "kb": 0.0}
    upright_k = {"pelvis": vec(0.2, 0.55, -0.1), "frame": (unit(-Z + X * 0.25), unit(Y)),
                 "spine": 0.0, "head": 0.0,
                 "legs": {1: (vec(0.3, Body.ANKLE, -0.32), unit(-Z), vec(0.3, 0.02, -0.49)),
                          -1: (vec(0.22, 0.1, 0.38), unit(-Z * 0.6 - Y), vec(0.22, 0.03, 0.55))},
                 "left": vec(0.05, 0.6, -0.05), "kb": 0.0}
    stand = {"pelvis": vec(0.26, 0.94, -0.12), "frame": (unit(-Z + X * 0.25), unit(Y)),
             "spine": 0.0, "head": 0.0,
             "legs": {1: (vec(0.28, Body.ANKLE, -0.18), unit(-Z), vec(0.28, 0.02, -0.35)),
                      -1: (vec(0.2, Body.ANKLE, -0.02), unit(-Z), vec(0.2, 0.02, -0.19))},
             "left": vec(0.02, 0.88, -0.1), "kb": 0.0}
    return [(0.0, lying), (0.18, elbow), (0.32, hand), (0.48, bridge), (0.64, kneel), (0.8, upright_k), (1.0, stand)]


TGU_KEYS = tgu_keys()


@demo("turkish-get-up", views=[THREE_QUARTER(55, 18), PROFILE(6)],
      labels=("Allongé, kettlebell bras tendu", "Sur le coude", "Sur la main", "Hanches levées", "Jambe passée dessous, à genou",
              "Buste droit, à genou", "Debout, bras tendu"),
      segments=[(0.6, 0.0, 0.0, 0, 1)] + stage_segments(TGU_KEYS, [1.0, 0.8, 0.8, 1.0, 0.9, 1.1], [1, 2, 3, 4, 5, 6])
      + [(0.8, 1.0, 1.0, 6, 1)]
      + [(d, b, a, lab, 1) for (d, a, b, lab) in reversed(list(zip([1.0, 0.8, 0.8, 1.0, 0.9, 1.1], [k[0] for k in TGU_KEYS[:-1]],
                                                                    [k[0] for k in TGU_KEYS[1:]], [0, 1, 2, 3, 4, 5])))],
      samples=31)
def turkish_get_up(p, s):
    floor(s, -1.0, 1.1, -0.9, 0.7)
    params = keyed(p, TGU_KEYS)
    f, u = params["frame"]
    body = Body(Frame(params["pelvis"], f, u), spine=params["spine"], head=params["head"])
    for side, (ankle, pole, toe) in params["legs"].items():
        body.leg(side, ankle, pole=unit(pole))
        body.toe[side] = toe
    sh = body.shoulder[1]
    grip = sh + Y * 0.615
    body.arm(1, grip, unit(-Y + X * 0.2 + body.chest.r * 0.3))
    left = np.asarray(params["left"], dtype=float)
    d = left - body.shoulder[-1]
    reach = Body.UPPER + Body.LOWER - 0.004
    if np.linalg.norm(d) > reach:      # the hand leaving the floor travels within reach
        left = body.shoulder[-1] + d * (reach / np.linalg.norm(d))
    body.arm(-1, left, unit(-body.chest.u * 0.3 + body.chest.r * -1.0 + Y * 0.5))
    kettlebell(s, grip, unit(-body.chest.f * 0.5 + Y * 0.3 - X * 0.2), Z, side=SIDE_RIGHT)
    s.allow = {"avant-bras gauche"}
    show(s, body)


# --- Wall ball -------------------------------------------------------------------------------------

@demo("wall-ball", views=[PROFILE(), THREE_QUARTER(35, 10)], mode="loop", samples=40,
      labels=("Squat, ballon contre la poitrine", "Poussée et lancer", "Ballon vers la cible", "Réception, nouveau squat"),
      segments=[(0.3, 0.0, 0.0, 0, 1), (0.6, 0.0, 0.35, 1, 1), (0.9, 0.35, 0.75, 2, 0), (0.7, 0.75, 1.0, 3, 1)])
def wall_ball(p, s):
    from ex_legs import squat_body
    wall = 0.75
    floor(s, -0.9, wall)
    s.box(vec(wall + 0.04, 1.6, 0.0), X * 0.04, Y * 1.6, Z * 0.8, "floor", stroke=0.0, bias=10.0)
    s.line([vec(wall - 0.005, 3.0, -0.25), vec(wall - 0.005, 3.0, 0.25)], 0.05, "mark", bias=-0.5)
    # Body: up from the squat while throwing, stands while the ball flies, catches and squats.
    if p < 0.35:
        depth = 1 - smooth(p / 0.35)
        arms = smooth(p / 0.35)
    elif p < 0.75:
        depth = 0.0
        arms = 1.0 - 0.25 * smooth((p - 0.35) / 0.4)
    else:
        depth = smooth((p - 0.75) / 0.25)
        arms = 0.75 * (1 - smooth((p - 0.75) / 0.25))
    body = squat_body(depth, 2.0, 25.0, 0.52, load_point=None, head=-8 - 10 * arms)
    chest = body.chest.at(u=0.26, f=Body.W_TORSO / 2 + 0.13)
    reach = mid(body) + unit(vec(0.35, 1.0, 0.0)) * 0.6
    hands = lerp(chest, reach, arms)
    hands[2] = 0.0
    for side in (1, -1):
        body.arm(side, hands + Z * side * 0.1 - Y * 0.04, unit(-Y + X * 0.2 + Z * side * 0.6))
    # The ball: in the hands, then flying to the target on the wall and back.
    if 0.35 < p < 0.75:
        t = (p - 0.35) / 0.4
        release = reach
        target = vec(wall - 0.13, 3.0, 0.0)
        up = 1 - (2 * t - 1) ** 2
        ball = lerp(release, target, min(1.0, 2 * t)) if t < 0.5 else lerp(target, mid(body) + unit(vec(0.35, 1.0, 0)) * 0.45, (t - 0.5) * 2)
        ball[2] = 0.0
    else:
        ball = hands + Y * 0.06
    s.ball(ball, 0.13, "load")
    show(s, body)


# --- Battle ropes ------------------------------------------------------------------------------------

@demo("battle-ropes", views=[THREE_QUARTER(35, 14), PROFILE()], mode="loop", timing=0.9, samples=24, labels=())
def battle_ropes(p, s):
    from ex_legs import squat_body
    floor(s, -0.8, 2.6)
    body = squat_body(0.45, 2.0, 30.0, 0.52, head=-10)
    anchor = vec(2.5, 0.25, 0.0)
    s.line([anchor - Z * 0.1, anchor + Z * 0.1], 0.08, "frame")
    for side in (1, -1):
        sh = body.shoulder[side]
        a = math.sin(2 * math.pi * p + (0 if side == 1 else math.pi))
        hand = sh + vec(0.32, -0.36 + 0.16 * a, side * 0.08)
        body.arm(side, hand, unit(-Y - X * 0.3 + Z * side * 0.4))
        pts = []
        n = 12
        for i in range(n + 1):
            u = i / n
            x = lerp(hand[0], anchor[0], u)
            amp = 0.18 * (1 - u) ** 1.2
            y = lerp(hand[1], anchor[1], u ** 0.5) + amp * math.sin(2 * math.pi * (p * 1.0 - u * 1.6) + (0 if side == 1 else math.pi)) * (u > 0)
            z = lerp(hand[2], side * 0.12, u)
            pts.append(vec(x, y, z))
        pts[0] = hand
        s.line(pts, 0.035, "load", side=SIDE_RIGHT if side == 1 else SIDE_LEFT)
    show(s, body)


# --- Sled push, bear crawl ------------------------------------------------------------------------------

@demo("sled-push", views=[PROFILE(), THREE_QUARTER(35, 12)], mode="loop", timing=1.1, samples=24, labels=(),
      travel=(0.88, 0.22, -1.4, 1.6, -0.5, 0.5, 0.0, 40.0))
def sled_push(p, s):
    floor(s, -1.4, 1.6)
    # Leaning into the sled: the feet push behind the hips, the free knee drives forward.
    body = walk_cycle(p, s, stride=0.44, arms="none", lean=46.0, bounce=0.012, stance=0.62, lift=0.12, hip=0.83, ahead=-0.15)
    sh = mid(body)
    # The sled ahead: a base with plates and two upright poles, the hands on the poles.
    base_x = sh[0] + 0.52
    for side in (1, -1):
        sd = SIDE_RIGHT if side == 1 else SIDE_LEFT
        top = vec(base_x, sh[1] - 0.02, side * 0.24)
        s.line([vec(base_x + 0.08, 0.08, side * 0.24), top], 0.04, "metal", side=sd)
        body.arm(side, top + vec(-0.0, -0.06, 0.0), unit(-Y - X * 0.2 + Z * side * 0.3))
    s.box(vec(base_x + 0.35, 0.05, 0.0), X * 0.38, Y * 0.04, Z * 0.32, "frame", stroke=0.01)
    s.line([vec(base_x + 0.35, 0.09, 0.0), vec(base_x + 0.35, 0.45, 0.0)], 0.04, "metal")
    s.disc(vec(base_x + 0.35, 0.2, 0.0), Y, 0.22, "load")
    s.disc(vec(base_x + 0.35, 0.26, 0.0), Y, 0.22, "load")
    show(s, body)


@demo("bear-crawl", views=[PROFILE(), THREE_QUARTER(35, 14)], mode="loop", timing=1.6, samples=24, labels=(),
      travel=(0.504, 0.252, -1.0, 1.6, -0.45, 0.45, 0.0, 40.0))
def bear_crawl(p, s):
    floor(s, -1.0, 1.6)
    hip_y = 0.6
    origin = vec(0.0, hip_y, 0.0)
    body = Body(Frame(origin, -Y, X).pitched(-14.0), head=-14)
    # Opposite hand and foot step together; each limb moves forward a half cycle at a time.
    cycle = 0.7
    for side, offset in ((1, 0.0), (-1, 0.5)):
        # Foot: steps with the opposite hand.
        t = (p + offset) % 1.0
        if t < 0.5:
            x = lerp(0.18, -0.18, t / 0.5)
            lift = 0.0
        else:
            x = lerp(-0.18, 0.18, smooth((t - 0.5) / 0.5))
            lift = 0.08 * math.sin(math.pi * (t - 0.5) / 0.5)
        # Knees under the hips, hovering just above the floor; shins back, on the balls of the feet.
        ankle = vec(body.hip[side][0] - 0.42 + x * 0.7, 0.13 + lift, side * 0.13)
        body.leg(side, ankle, pole=unit(-Y + X * 0.35))
        body.toe[side] = ankle + vec(0.07, -0.1, 0.0)
    for side, offset in ((1, 0.5), (-1, 0.0)):
        t = (p + offset) % 1.0
        if t < 0.5:
            x = lerp(0.18, -0.18, t / 0.5)
            lift = 0.0
        else:
            x = lerp(-0.18, 0.18, smooth((t - 0.5) / 0.5))
            lift = 0.08 * math.sin(math.pi * (t - 0.5) / 0.5)
        sh = body.shoulder[side]
        hand = vec(sh[0] + 0.05 + x * 0.7, 0.04 + lift, side * 0.22)
        d = hand - sh
        dist = float(np.linalg.norm(d))
        if dist > 0.625:
            hand = sh + d / dist * 0.625
            hand[1] = max(hand[1], 0.04 + lift)
        body.arm(side, hand, unit(-X + Z * side * 0.2))
    show(s, body)
