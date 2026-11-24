"""Catalog lot 01 (2026-11-23): kettlebell halo, floor press, reverse hyperextension, donkey calf raise, calf press,
oblique crunch, ab crunch machine, jackknife sit-up, Zottman curl, spider curl, prone incline dumbbell curl."""
import math

import numpy as np

from demos import demo, show
from engine import (FRONT, PROFILE, THREE_QUARTER, Body, Frame, SIDE_LEFT, SIDE_RIGHT, View, X, Y, Z, lerp, posture,
                    rotate, unit, vec)
from gear import PAD_T, TUBE, barbell, bench_rack, dumbbell, ez_bar, floor, foot_bar, kettlebell
from machines import roller, stack
from poses import feet_flat, lying_on_back, lying_on_front, plank_on_toes, stance, upright


def smooth(t):
    t = min(1.0, max(0.0, t))
    return t * t * (3 - 2 * t)


def sd(side):
    return SIDE_RIGHT if side == 1 else SIDE_LEFT


# --- Kettlebell halo ----------------------------------------------------------------------------------

@demo("x-kettlebell-halo", views=[THREE_QUARTER(40, 14), FRONT(6)], mode="loop", timing=3.6, samples=32, labels=(),
      muscles=(["shoulders"], ["traps", "back", "abs", "triceps"]))
def kettlebell_halo(p, s):
    floor(s, -0.6, 0.6, -0.9, 0.9)
    body = upright(0.945, 0.0, pelvis_x=0.0, head=0)
    stance(body, 0.0, half_width=0.13)
    a = 2 * math.pi * p
    radius = 0.27
    center = vec(0.0, 1.58, 0.0)
    g = center + vec(math.cos(a), 0.0, math.sin(a)) * radius
    for side in (1, -1):
        hand = g + Z * side * 0.06
        body.arm(side, hand, unit(-Y + Z * side * 0.6 - X * 0.3))
    kettlebell(s, g, Y, Z, side=0)
    show(s, body)


# --- Floor press ---------------------------------------------------------------------------------------

def shoulder_mid(body):
    return (body.shoulder[1] + body.shoulder[-1]) / 2


@demo("x-floor-press", views=[PROFILE(), THREE_QUARTER(38, 16)],
      labels=("Bras tendus, barre au-dessus des épaules", "Descente, coudes à 45°", "Triceps posés au sol", "Poussée"),
      timing=(0.7, 1.5, 0.6, 1.1), muscles=(["triceps"], ["chest", "shoulders"]))
def floor_press(p, s):
    floor(s, -1.2, 1.0)
    body = lying_on_back(0.0, 0.0, head=14)
    feet_flat(body, (0.5, 0.2), (0.5, -0.2), pole=Y)
    grip = 0.2
    mid = shoulder_mid(body)
    top = mid + Y * math.sqrt(0.632 ** 2 - (grip - Body.SH_HALF) ** 2 * 0.0 - 0.0)
    top = vec(mid[0], mid[1] + 0.6, 0.0)
    k = smooth(p) * 0.0 + p
    # Bottom: the upper arms rest on the floor (elbows on it), the forearms vertical.
    elbow_floor = Body.W_UPPER / 2 + 0.004
    bottom = vec(mid[0] + 0.06, elbow_floor + 0.325, 0.0)
    bar = top + (bottom - top) * k
    for side in (1, -1):
        sh = body.shoulder[side]
        elbow_hint = lerp(sh + vec(0.0, 0.3, side * 0.1), vec(sh[0] + 0.04, elbow_floor, side * 0.34), k)
        body.arm_via(side, bar + Z * side * grip, elbow_hint)
    bench_rack(s, x=top[0] - 0.14, height=top[1] - 0.05)
    barbell(s, bar, Z)
    show(s, body)


# --- Abdominals on the floor -----------------------------------------------------------------------------

def supine(pelvis_x=0.0, spine=0.0, head=20.0, y=None, **args):
    """Lying on the back on the floor, head toward -x."""
    origin = vec(pelvis_x, Body.D_TRUNK + 0.006 if y is None else y, 0.0)
    return Body(Frame(origin, Y, -X), spine=spine, head=head, **args)


@demo("x-oblique-crunches", views=[THREE_QUARTER(40, 22), View("Face", 90, 30)],
      labels=("Allongé, genoux pliés", "Enroulement et rotation", "Épaule vers le genou opposé", "Descente lente"),
      timing=(0.6, 1.1, 0.6, 1.3), muscles=(["abs", "obliques"], []))
def oblique_crunches(p, s):
    floor(s, -1.0, 0.8)
    k = smooth(p)
    body = supine(spine=lerp(0.0, 32.0, k), twist=lerp(0.0, 38.0, k), head=lerp(22.0, 26.0, k))
    for side in (1, -1):
        body.foot_on_floor(side, (body.pelvis.o[0] + 0.36, side * 0.12), 0.0, pole=Y)
    # One hand behind the head (the working side), the other arm resting on the floor.
    temple = body.head + body.head_frame.r * 0.1 - body.head_frame.f * 0.0
    body.arm(1, temple, unit(body.chest.r * 1.0 + body.chest.u * 0.2))
    body.arm(-1, vec(body.shoulder[-1][0] + 0.1, 0.04, -0.4), unit(Z * -1.0 + Y * 0.2))
    show(s, body)


@demo("x-jackknife-sit-up", views=[PROFILE(), THREE_QUARTER(35, 16)],
      labels=("Allongé, bras et jambes tendus", "Buste et jambes montent ensemble", "Mains vers les pieds, en V", "Descente sous contrôle"),
      timing=(0.6, 1.3, 0.5, 1.5), muscles=(["abs"], []))
def jackknife_sit_up(p, s):
    floor(s, -1.2, 1.1)
    k = smooth(p)
    hip = 58.0 * k
    origin = vec(0.0, Body.D_TRUNK + 0.006 + 0.03 * k, 0.0)
    body = Body(Frame(origin, Y, -X).pitched(hip), spine=36.0 * k, head=lerp(14.0, 28.0, k))
    leg_up = 56.0 * k
    thigh = vec(math.cos(math.radians(leg_up)), math.sin(math.radians(leg_up)) - 0.0, 0.0)
    for side in (1, -1):
        body.leg_dirs(side, thigh + Z * side * 0.0, thigh)
        body.foot_relaxed(side, plantar=-10)
    # Arms: overhead on the floor at the start, then swinging forward toward the feet.
    for side in (1, -1):
        sh = body.shoulder[side]
        swing = lerp(180.0, 15.0, k)           # angle of the arm from +x, going over the top
        d = vec(math.cos(math.radians(swing)), math.sin(math.radians(swing)), 0.0)
        target = sh + d * 0.62
        target[1] = max(target[1], 0.04)
        if k > 0.85:
            ankle = body.ankle[side]
            target = lerp(target, ankle - unit(thigh) * 0.12 + Z * side * 0.0, smooth((k - 0.85) / 0.15))
        body.arm(side, target, unit(Z * side + Y * 0.3))
    show(s, body)


# --- Curls -----------------------------------------------------------------------------------------------

def curl_grip(body, side, angle, elbow_forward=0.0, out=0.0):
    """The upper arm hanging (a little forward at the top), the forearm turned angle degrees from
    straight down toward the shoulder."""
    sh = body.shoulder[side]
    upper = unit(-Y + X * elbow_forward + body.chest.r * side * out)
    elbow = sh + upper * Body.UPPER
    fore = rotate(upper, body.chest.r, angle)
    return elbow + fore * Body.LOWER, elbow


ZOTTMAN = ("Haltères en supination", "Montée en supination", "Rotation en pronation", "Descente lente en pronation",
           "Rotation en supination")


@demo("x-zottman-curl", views=[THREE_QUARTER(35, 10), PROFILE()], mode="loop", timing=5.0, samples=40,
      labels=ZOTTMAN, muscles=(["biceps"], ["forearms"]),
      segments=[(0.4, 0.0, 0.0, 0, 1), (1.2, 0.0, 0.4, 1, 1), (0.7, 0.4, 0.55, 2, 1), (1.6, 0.55, 0.9, 3, 1),
                (0.7, 0.9, 1.0, 4, 1)])
def zottman_curl(p, s):
    floor(s, -0.6, 0.9, -0.7, 0.7)
    body = upright(0.945, 0.0, shoulder_x=0.0, head=0)
    stance(body, 0.0, half_width=0.14)
    if p < 0.4:
        up = p / 0.4
    elif p < 0.55:
        up = 1.0
    elif p < 0.9:
        up = 1.0 - (p - 0.55) / 0.35
    else:
        up = 0.0
    up = smooth(up)
    # Turn of the hand: 0 = palm forward (supination), 180 = palm back (pronation).
    if p < 0.4:
        turn = 0.0
    elif p < 0.55:
        turn = 180.0 * smooth((p - 0.4) / 0.15)
    elif p < 0.9:
        turn = 180.0
    else:
        turn = 180.0 * (1 - smooth((p - 0.9) / 0.1))
    angle = lerp(6.0, 138.0, up)
    fwd = lerp(0.0, 0.18, up)
    for side in (1, -1):
        g, elbow = curl_grip(body, side, angle, fwd, out=0.15)
        body.arm_via(side, g, elbow)
        fore = unit(g - body.elbow[side])
        axis = rotate(body.chest.r, fore, turn * side)
        dumbbell(s, g, axis, side=sd(side))
        # The thumb: a small mark on the hand, inside when supinated, outside when pronated.
        thumb_dir = rotate(body.chest.r * -side, fore, turn * side) if False else None
    show(s, body)


def prone_incline(s, p, tool, angle=52.0):
    """Lying face down on a steep bench, the body straight from the toes to the head, the chest on the top
    of the pad, the arms hanging straight down beyond it. tool: 'bar' (EZ bar) or 'db' (dumbbells)."""
    floor(s, -1.4, 1.0)
    body = plank_on_toes(angle, toe_x=-0.75, head=-6)
    pel = body.pelvis
    d, n = pel.u, pel.f                      # up the body toward the head, and toward the belly
    surface = n * (Body.D_TRUNK + 0.006)
    start = pel.o + d * 0.02 + surface
    end = pel.o + d * 0.44 + surface
    s.slab(start, end, -n, 0.3, PAD_T, "pad", solid="le banc")
    # Frame: a post under the top of the pad, another under the lower end, a rail on the floor.
    for t in (0.05, 0.42):
        top_pt = pel.o + d * t + surface - n * 0.0 - (-n) * PAD_T * 0.0
        low = top_pt + n * PAD_T
        s.line([low, vec(low[0], 0.03, 0.0)], TUBE * 1.2, "frame")
        foot_bar(s, low[0])
    s.line([vec(pel.o[0] - 0.1, 0.03, 0.0), vec(end[0] + 0.25, 0.03, 0.0)], TUBE, "frame")
    angle_el = lerp(4.0, 132.0, p)
    for side in (1, -1):
        sh = body.shoulder[side]
        upper = unit(-Y + Z * side * 0.04)
        elbow = sh + upper * Body.UPPER
        fore = rotate(upper, Z, angle_el)           # the forearm swings forward, away from the pad
        grip = elbow + fore * Body.LOWER
        body.arm_via(side, grip, elbow)
        if tool == "db":
            dumbbell(s, grip, Z, side=sd(side))
    if tool == "bar":
        bar = (body.grip[1] + body.grip[-1]) / 2
        fore = unit(body.grip[1] - body.elbow[1])
        ez_bar(s, bar, Z, forward=rotate(fore, Z, 90))
    return body


@demo("x-spider-curl", views=[PROFILE(), THREE_QUARTER(35, 12)],
      labels=("Bras pendus à la verticale", "Flexion des coudes", "Contraction en haut", "Descente lente"),
      timing=(0.6, 1.2, 0.5, 1.7), muscles=(["biceps"], []))
def spider_curl(p, s):
    body = prone_incline(s, p, "bar")
    s.allow = {"le banc"}
    show(s, body)


@demo("x-dumbbell-prone-incline-curl", views=[PROFILE(), THREE_QUARTER(35, 12)],
      labels=("Bras pendus, haltères en supination", "Flexion des coudes", "Contraction en haut", "Descente lente"),
      timing=(0.6, 1.2, 0.5, 1.7), muscles=(["biceps"], []))
def prone_incline_db_curl(p, s):
    body = prone_incline(s, p, "db")
    s.allow = {"le banc"}
    show(s, body)


# --- Reverse hyperextension ------------------------------------------------------------------------------

@demo("x-reverse-hyperextension", views=[PROFILE(), THREE_QUARTER(35, 12)],
      labels=("Jambes pendantes, torse sur le coussin", "Montée des jambes tendues", "Jambes à l'horizontale, fessiers serrés", "Descente contrôlée"),
      timing=(0.6, 1.2, 0.6, 1.6), muscles=(["hamstrings"], ["calves", "glutes"]))
def reverse_hyperextension(p, s):
    floor(s, -1.2, 1.3)
    top = 0.95
    edge = 0.06
    body = lying_on_front(top, edge - 0.06 + 0.0, head=-8)
    hipx = body.pelvis.o[0]
    pad_start = hipx + 0.07
    pad_end = pad_start + 0.95
    s.slab(vec(pad_start, top, 0), vec(pad_end, top, 0), Y, 0.42, PAD_T, "pad", solid="le coussin")
    theta = lerp(-8.0, 86.0, p)
    leg = vec(-math.sin(math.radians(theta)), -math.cos(math.radians(theta)), 0.0)
    for side in (1, -1):
        body.leg_dirs(side, leg, leg)
        body.foot_relaxed(side, plantar=-10)
        # Hands on the handles at the head end of the pad.
        # The hands hold the handles at the front of the pad, beside it: the arms lie along its sides, not through it.
        body.arm(side, vec(pad_end - 0.04, top + 0.03, side * 0.27), unit(-Y + Z * side * 0.5))
        sh = vec(pad_end - 0.04, top - 0.1, side * 0.27)
        s.line([sh, sh + Y * 0.19], 0.035, "load", side=sd(side))
    # Frame under the pad.
    for x in (pad_start + 0.12, pad_end - 0.15):
        s.line([vec(x, top - PAD_T, 0), vec(x, 0.03, 0)], TUBE * 1.3, "frame")
        foot_bar(s, x, half=0.3)
    s.line([vec(pad_start - 0.1, 0.03, 0), vec(pad_end + 0.1, 0.03, 0)], TUBE, "frame")
    # Pendulum: a lever on each side from the hip pivot, with a roller across the ankles and a weight on the other end.
    ankle = body.ankle[1]
    shin = unit(body.ankle[1] - body.knee[1])
    for side in (1, -1):
        pivot = vec(hipx - 0.02, body.hip[1][1] - 0.02, side * 0.3)
        end = vec(ankle[0], ankle[1], side * 0.3) + shin * 0.1
        s.line([pivot, end], TUBE * 1.2, "frame", side=sd(side))
        s.disc(pivot, Z, 0.05, "frame", side=sd(side))
        back = pivot - unit(end - pivot) * 0.28
        s.line([pivot, back], TUBE * 1.2, "frame", side=sd(side))
        s.disc(back + Z * side * 0.03, Z, 0.13, "load", side=sd(side))
    roll = ankle + shin * 0.0
    s.line([vec(roll[0], roll[1], -0.3), vec(roll[0], roll[1], 0.3)], 0.07, "pad")
    s.allow = {"le coussin"}
    show(s, body)


# --- Donkey calf raise -----------------------------------------------------------------------------------

@demo("x-donkey-calf-raises", views=[PROFILE(), THREE_QUARTER(35, 12)],
      labels=("Talons bas, buste penché", "Montée sur la pointe des pieds", "Contraction en haut", "Descente lente"),
      timing=(0.6, 0.9, 0.7, 1.3), muscles=(["calves"], []))
def donkey_calf_raises(p, s):
    floor(s, -1.0, 1.1)
    step = 0.1
    s.box(vec(0.2, step / 2, 0.0), X * 0.12, Y * step / 2, Z * 0.35, "frame", stroke=0.01, solid="la marche")
    raise_deg = lerp(-18.0, 32.0, p)
    ankles = {}
    probe = upright(1.0, 86.0, pelvis_x=0.0, head=-25)
    for side in (1, -1):
        ankles[side] = probe.stand_foot(side, vec(0.12, step + 0.02, side * 0.11), 0.0, raise_deg)
    hip_y = ankles[1][1] + Body.SHIN + Body.THIGH - 0.004
    body = upright(hip_y, 86.0, pelvis_x=ankles[1][0], head=-25)
    for side in (1, -1):
        body.stand_foot(side, vec(0.12, step + 0.02, side * 0.11), 0.0, raise_deg)
        body.leg(side, ankles[side], pole=X)
    # Forearms on the padded handles of the machine, ahead of the shoulders.
    hand_y = 1.0
    for side in (1, -1):
        sh = body.shoulder[side]
        g = vec(sh[0] + 0.1, hand_y, side * 0.2)
        body.arm(side, g, unit(-Y + Z * side * 0.3))
        s.line([g - X * 0.07, g + X * 0.07], 0.04, "load", side=sd(side))
        s.line([vec(g[0], g[1] - 0.02, g[2]), vec(g[0], 0.03, g[2])], TUBE * 1.2, "frame", side=sd(side))
    foot_bar(s, sh[0] + 0.1, half=0.3)
    s.line([vec(sh[0] + 0.1, hand_y - 0.03, -0.2), vec(sh[0] + 0.1, hand_y - 0.03, 0.2)], TUBE * 1.2, "frame")
    # The padded lever across the lower back, carrying the weight behind.
    pel = body.pelvis
    pad_c = pel.o + Y * (Body.D_TRUNK + 0.05) + X * 0.05
    s.slab(pad_c - X * 0.12 + Y * 0.0, pad_c + X * 0.14, -Y, 0.4, 0.07, "pad")
    lever_y = pad_c[1] + 0.08
    s.line([vec(pad_c[0] - 0.1, pad_c[1] + 0.04, 0.0), vec(pad_c[0] - 0.1, lever_y, 0.0), vec(-0.7, lever_y, 0.0)], TUBE * 1.3, "frame")
    s.line([vec(pad_c[0] - 0.1, lever_y, -0.22), vec(pad_c[0] - 0.1, lever_y, 0.22)], TUBE * 1.2, "frame")
    for side in (1, -1):
        s.line([vec(-0.7, lever_y, side * 0.22), vec(-0.7, lever_y - 0.9, side * 0.22)], TUBE, "frame", side=sd(side))
        s.disc(vec(-0.7, lever_y - 0.7, side * 0.26), Z, 0.2, "load", side=sd(side))
    s.line([vec(-0.7, lever_y, -0.22), vec(-0.7, lever_y, 0.22)], TUBE, "frame")
    s.allow = {"la marche"}
    show(s, body)


# --- Calf press on the leg press -------------------------------------------------------------------------

@demo("x-calf-press", views=[PROFILE(), THREE_QUARTER(35, 14)],
      labels=("Jambes presque tendues, talons dans le vide", "Poussée sur les avant-pieds", "Chevilles tendues", "Retour, mollets étirés"),
      timing=(0.6, 1.0, 0.7, 1.4), muscles=(["calves"], []))
def calf_press(p, s):
    floor(s, -1.1, 1.8)
    back_angle = 38.0
    up = vec(-math.cos(math.radians(back_angle)), math.sin(math.radians(back_angle)), 0.0)
    normal = vec(math.sin(math.radians(back_angle)), math.cos(math.radians(back_angle)), 0.0)
    hip = vec(0.0, 0.5, 0.0)
    body = Body(Frame(hip, normal, up), head=12)
    sled = vec(math.cos(math.radians(45)), math.sin(math.radians(45)), 0.0)
    plate_up = vec(-sled[1], sled[0], 0.0)
    beta = lerp(-22.0, 38.0, p)                        # the foot pitched on its ball: plus = ankle extended
    for side in (1, -1):
        ankle = hip + sled * 0.84 + plate_up * 0.1 + Z * side * 0.15
        foot_dir = rotate(plate_up, Z, -beta)
        toe = ankle + foot_dir * 0.165
        body.leg(side, ankle, pole=plate_up)
        body.foot_toward(side, toe)
    q = float(np.dot(toe - hip, sled)) + 0.02          # the platform follows the ball of the foot
    sole = hip + sled * q + plate_up * 0.1
    # Seat and backrest.
    seat_pt = hip - normal * (Body.D_TRUNK + 0.004)
    s.slab(seat_pt - up * 0.08, seat_pt + up * 0.75, normal, 0.34, 0.08, "pad", solid="le dossier")
    seat_dir = rotate(sled, Z, -20)
    s.slab(seat_pt + seat_dir * 0.02, seat_pt + seat_dir * 0.3, rotate(seat_dir, Z, 90), 0.42, 0.08, "pad")
    # Platform: its lower edge at the toes, the heels hanging below it; rails at 45 degrees.
    s.slab(sole + plate_up * 0.13, sole + plate_up * 0.62, -sled, 0.7, 0.04, "frame")
    for side in (1, -1):
        z = side * 0.42
        rail_a = hip - plate_up * 0.26 + sled * 0.35 + Z * z
        rail_b = hip - plate_up * 0.26 + sled * 1.95 + Z * z
        s.line([rail_a, rail_b], TUBE * 1.3, "frame", side=sd(side))
        s.line([rail_b, vec(rail_b[0], 0.03, z)], TUBE * 1.3, "frame", side=sd(side))
        horn = sole + sled * 0.12 + plate_up * 0.42 + Z * side * 0.36
        s.line([horn, horn + Z * side * 0.18], 0.04, "metal", side=sd(side))
        s.disc(horn + Z * side * 0.08, Z, 0.2, "load", side=sd(side))
        s.line([sole + sled * 0.02 + plate_up * 0.3 + Z * side * 0.32, horn], TUBE, "frame", side=sd(side))
        s.line([sole + sled * 0.03 + plate_up * 0.13 + Z * z, hip - plate_up * 0.26 + sled * (q + 0.1) + Z * z],
               TUBE * 1.2, "frame", side=sd(side))
        handle = hip + Z * side * 0.3 + Y * 0.02 + X * 0.05
        body.arm(side, handle, unit(-X - Y * 0.3))
        s.line([handle - X * 0.08, handle + X * 0.08], 0.035, "load", side=sd(side))
    s.line([vec(-0.9, 0.03, 0), vec(1.9, 0.03, 0)], TUBE, "frame")
    s.line([seat_pt - normal * 0.08, vec(seat_pt[0], 0.03, 0)], TUBE * 1.3, "frame")
    back_top = seat_pt + up * 0.75 - normal * 0.08
    s.line([back_top, vec(back_top[0], 0.03, 0)], TUBE * 1.3, "frame")
    show(s, body)


# --- Ab crunch machine ---------------------------------------------------------------------------------------

@demo("x-ab-crunch-machine", views=[PROFILE(), THREE_QUARTER(35, 12)],
      labels=("Assis, mains aux poignées", "Enroulement du buste", "Buste enroulé, abdos contractés", "Retour contrôlé"),
      timing=(0.6, 1.2, 0.6, 1.5), muscles=(["abs"], []))
def ab_crunch_machine(p, s):
    floor(s, -0.9, 1.0)
    seat_y = 0.46
    s.slab(vec(-0.22, seat_y, 0), vec(0.22, seat_y, 0), Y, 0.4, PAD_T, "pad", solid="le siège")
    s.line([vec(0.0, seat_y - PAD_T, 0), vec(0.0, 0.03, 0)], TUBE * 1.3, "frame")
    s.line([vec(-0.5, 0.03, 0), vec(0.75, 0.03, 0)], TUBE, "frame")
    body = seated_hip(seat_y, -0.04, spine=lerp(2.0, 46.0, p), head=lerp(8.0, 24.0, p))
    for side in (1, -1):
        body.foot_on_floor(side, (0.42, side * 0.16), 0.0, pole=X + Y * 0.3)
    # Rollers pressing on the feet.
    ank = body.ankle[1]
    s.line([vec(ank[0] + 0.02, ank[1] + 0.07, -0.25), vec(ank[0] + 0.02, ank[1] + 0.07, 0.25)], 0.085, "pad")
    s.line([vec(ank[0] + 0.02, ank[1] + 0.07, 0.0), vec(ank[0] - 0.25, ank[1] + 0.2, 0.0), vec(-0.35, 0.3, 0.0)], TUBE * 1.2, "frame")
    # The chest pad and its handles turn with the trunk around a pivot behind the hips.
    c = body.chest
    pivot = vec(-0.28, 0.75, 0.0)
    # The pad lies across the upper chest; the arm holding it comes down on each side, outside the shoulders.
    pad_pt = c.at(u=0.27, f=Body.D_TRUNK + 0.055)
    pad_pt[2] = 0.0
    s.line([pad_pt - Z * 0.17, pad_pt + Z * 0.17], 0.1, "pad")
    for side in (1, -1):
        z = side * 0.3
        end = vec(pad_pt[0], pad_pt[1], side * 0.17)
        s.line([vec(pivot[0], pivot[1], z), vec(pivot[0], pivot[1] + 0.2, z), vec(pad_pt[0] - 0.05, pad_pt[1] + 0.24, z),
                vec(pad_pt[0], pad_pt[1], z), end], TUBE * 1.3, "frame", side=sd(side))
        s.disc(vec(pivot[0], pivot[1], z), Z, 0.055, "frame", side=sd(side))
    for side in (1, -1):
        grip = c.at(u=0.37, f=Body.D_TRUNK + 0.08, r=side * 0.2)
        body.arm(side, grip, unit(-c.u * 0.3 + c.f * 0.1 + c.r * side * 0.3 - Y * 0.5))
        s.line([grip - c.u * 0.04, grip + c.u * 0.07], 0.035, "load", side=sd(side))
        s.line([vec(pad_pt[0], pad_pt[1], side * 0.17), vec(grip[0], grip[1], grip[2])], TUBE, "frame", side=sd(side))
    stack(s, -0.62, 0.0, lift=p * 0.12, height=1.3)
    s.allow = {"le siège"}
    show(s, body)


def seated_hip(seat_y, hip_x, **args):
    """Sitting on a seat, the trunk upright (the spine may curl forward)."""
    origin = vec(hip_x, seat_y + Body.R_THIGH + 0.004, 0.0)
    return Body(posture(origin, 0.0, 0.0), **args)
