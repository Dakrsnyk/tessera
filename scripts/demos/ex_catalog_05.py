"""Catalog lot 05 (2026-11-23): suspended fallout, stomach vacuum, suspended / plyometric / single-arm push-ups,
dumbbell side bend, landmine 180s, band external rotation, sled drag, weighted sissy squat."""
import math

import numpy as np

from cyclic import walk_cycle
from demos import demo, show
from engine import (ABOVE, FRONT, PROFILE, THREE_QUARTER, Body, Frame, SIDE_LEFT, SIDE_RIGHT, View, X, Y, Z, lerp,
                    posture, unit, vec)
from gear import TUBE, floor, plate
from poses import plank_on_toes, solve, stance, upright


def smooth(t):
    t = min(1.0, max(0.0, t))
    return t * t * (3 - 2 * t)


def mid(body):
    return (body.shoulder[1] + body.shoulder[-1]) / 2


def sd(side):
    return SIDE_RIGHT if side == 1 else SIDE_LEFT


# --- Plank family: suspended fallout, suspended / plyometric / single-arm push-ups -------------------------

def strap_handles(s, anchor, hands):
    """A suspension trainer: a strap from the anchor to each handle."""
    for side, grip in hands.items():
        s.line([anchor, grip + Y * 0.03], 0.016, "cable", side=sd(side))
        s.line([grip - Z * 0.055 * side, grip + Z * 0.055 * side], 0.032, "load", side=sd(side))
    s.line([anchor - Z * 0.06, anchor + Z * 0.06], 0.04, "metal")


FALL_LABELS = ("Gainé, bras sous l'ancrage", "Les bras partent loin devant", "Corps allongé, abdos serrés", "Retour en contractant")


@demo("x-suspended-fallout", views=[PROFILE(), THREE_QUARTER(35, 14)], labels=FALL_LABELS, timing=(0.6, 1.8, 0.5, 1.6),
      muscles=(["abs"], ["chest", "lowerBack", "shoulders"]))
def suspended_fallout(p, s):
    floor(s, -0.9, 1.8)
    k = smooth(p)
    top_sh, low_sh = 0.74, 0.34

    def make(theta):
        return plank_on_toes(theta, toe_x=-0.6, head=-6)

    sh_y = lambda t: mid(make(t))[1]
    th_top = solve(sh_y, -5.0, 70.0, top_sh)
    th_low = solve(sh_y, -5.0, 70.0, low_sh)
    body = make(lerp(th_top, th_low, k))
    elev = lerp(-82.0, 22.0, k)                  # the arms swing from hanging to reaching forward
    d = unit(X * math.cos(math.radians(elev)) + Y * math.sin(math.radians(elev)))
    hand_top = {}
    for side in (1, -1):
        sh = body.shoulder[side]
        grip = sh + d * (Body.UPPER + Body.LOWER - 0.012)
        body.arm(side, grip, unit(-Y * 0.3 + body.chest.r * side * 0.3 - body.chest.f * 0.4))
        hand_top[side] = body.grip[side]
    top_body = make(th_top)
    ax = mid(top_body)[0] + 0.0
    strap_handles(s, vec(ax, 1.55, 0.0), hand_top)
    s.line([vec(ax - 0.2, 1.55, 0), vec(ax + 0.25, 1.55, 0)], 0.05, "metal")
    show(s, body)


def stance_line(s, top):
    pass


# One body rotating around the toes, the hands at given heights.

def toes_plank(theta, toe_x=0.0, toe_z=0.0, spread=0.0, **args):
    """Face down on the toes, straight line; spread: feet apart by this much each side."""
    frame = posture(vec(0, 0, 0), 0.0, 90.0 - theta)
    alpha = math.asin(min(0.9, spread / 0.875)) if spread else 0.0

    def build(origin):
        b = Body(Frame(origin, frame.f, frame.u), **args)
        for side in (1, -1):
            dirn = -frame.u * math.cos(alpha) + frame.r * side * math.sin(alpha)
            ankle = b.hip[side] + unit(dirn) * (Body.THIGH + Body.SHIN)
            b.leg(side, ankle, pole=-frame.f)
            b.foot_toward(side, ankle + frame.f * 0.165 - frame.u * 0.06)
        return b

    probe = build(vec(0, 0, 0))
    toe_mid = (probe.toe[1] + probe.toe[-1]) / 2
    target = vec(toe_x, 0.02, toe_z)
    return build(target - toe_mid)


PUSH_LABELS = ("Bras tendus, corps gainé", "Descente", "Poitrine près des mains", "Poussée")


@demo("x-suspended-push-up", views=[PROFILE(), THREE_QUARTER(30, 16)], labels=("Bras tendus dans les poignées", "Descente entre les sangles",
                                                                              "Poitrine entre les poignées", "Poussée"),
      timing=(0.6, 1.5, 0.4, 1.2), muscles=(["chest"], ["shoulders", "triceps"]))
def suspended_push_up(p, s):
    floor(s, -0.5, 1.9)
    hy = 0.36                                     # handles
    top_sh, low_sh = hy + 0.6, hy + 0.14
    make = lambda t: toes_plank(t, toe_x=0.0, head=-8)
    sh_y = lambda t: mid(make(t))[1]
    th_top = solve(sh_y, -5.0, 75.0, top_sh)
    th_low = solve(sh_y, -5.0, 75.0, low_sh)
    hx = mid(make(th_top))[0]
    body = make(lerp(th_top, th_low, p))
    hands = {}
    for side in (1, -1):
        grip = vec(hx, hy, side * 0.2)
        pole = unit(-body.chest.u * 1.0 + body.chest.r * side * 0.7 - body.chest.f * 0.2)
        body.arm(side, grip, pole)
        hands[side] = body.grip[side]
    strap_handles(s, vec(hx, 1.7, 0.0), hands)
    s.line([vec(hx - 0.15, 1.7, 0), vec(hx + 0.2, 1.7, 0)], 0.05, "metal")
    show(s, body)


@demo("x-plyo-push-up", views=[PROFILE(), THREE_QUARTER(30, 16)], mode="loop", samples=30,
      labels=("Bras tendus, corps gainé", "Descente", "Poussée explosive", "Mains décollées", "Réception bras souples"),
      segments=[(0.45, 0.0, 0.3, 1, 1), (0.14, 0.3, 0.45, 2, 1), (0.34, 0.45, 0.7, 3, 0), (0.4, 0.7, 1.0, 4, 1),
                (0.2, 1.0, 1.0, 0, 1)],
      muscles=(["chest"], ["shoulders", "triceps"]))
def plyo_push_up(p, s):
    floor(s, -0.4, 1.8)
    top_sh, low_sh = 0.65, 0.14
    make = lambda t: plank_on_toes(t, toe_x=0.0, head=-8)
    sh_y = lambda t: mid(make(t))[1]
    th_top = solve(sh_y, -5.0, 75.0, top_sh)
    hx = mid(make(th_top))[0]
    # shoulder height and how far the hands are off the floor
    if p < 0.3:
        h, lift = lerp(top_sh, low_sh, smooth(p / 0.3)), 0.0
    elif p < 0.45:
        t = (p - 0.3) / 0.15
        h, lift = lerp(low_sh, top_sh, smooth(t) ** 0.8), 0.0
    elif p < 0.7:
        t = (p - 0.45) / 0.25
        h, lift = top_sh + 0.05 * math.sin(math.pi * t), 0.09 * math.sin(math.pi * t)
    else:
        t = (p - 0.7) / 0.3
        h, lift = top_sh - 0.07 * math.sin(math.pi * t), 0.0
    body = make(solve(sh_y, -5.0, 75.0, h))
    for side in (1, -1):
        grip = vec(hx, 0.025 + lift, side * 0.27)
        pole = unit(-body.chest.u * 1.0 + body.chest.r * side * 0.75 - body.chest.f * 0.2)
        body.arm(side, grip, pole)
    show(s, body)


@demo("x-single-arm-push-up", views=[PROFILE(), THREE_QUARTER(30, 16)],
      labels=("Un bras sous l'épaule, jambes écartées", "Descente", "Poitrine près du sol", "Poussée"),
      timing=(0.7, 1.6, 0.5, 1.3), muscles=(["chest"], ["shoulders", "triceps"]))
def single_arm_push_up(p, s):
    floor(s, -0.5, 1.9, -0.75, 0.75)
    top_sh, low_sh = 0.64, 0.16
    side = 1                                      # the working arm
    zoff = -0.07
    make = lambda t: toes_plank(t, toe_x=0.0, toe_z=zoff, spread=0.26, head=-8)
    sh_y = lambda t: mid(make(t))[1]
    th_top = solve(sh_y, -5.0, 75.0, top_sh)
    th_low = solve(sh_y, -5.0, 75.0, low_sh)
    hx = mid(make(th_top))[0]
    body = make(lerp(th_top, th_low, p))
    sh = body.shoulder[side]
    body.arm(side, vec(hx, 0.025, sh[2]), unit(-body.chest.u * 1.0 + body.chest.r * side * 0.7 - body.chest.f * 0.2))
    # The free hand rests on the lower back.
    back = body.pelvis.at(u=0.12, f=-(Body.W_TORSO / 2 + 0.03), r=-side * 0.02)
    body.arm(-side, back, unit(-body.chest.f * 0.5 - body.chest.r * side * 0.8 - body.chest.u * 0.2))
    show(s, body)


# --- Standing: stomach vacuum, side bend ------------------------------------------------------------------

@demo("x-stomach-vacuum", views=[FRONT(), THREE_QUARTER(40, 10)],
      labels=("Debout, mains sur les hanches", "Expire tout l'air", "Ventre rentré : tiens", "Relâche et respire"),
      timing=(0.8, 1.6, 2.5, 1.2), muscles=(["abs"], []))
def stomach_vacuum(p, s):
    floor(s, -0.6, 0.6, -0.6, 0.6)
    k = smooth(p)
    # Full breath in at the start (chest high, shoulders back); then everything out, the trunk rounds a little.
    body = upright(0.95, 0.0, pelvis_x=0.0, spine=lerp(-3.0, 4.0, k), head=lerp(-3.0, 4.0, k),
                   shrug=lerp(0.012, -0.012, k))
    stance(body, 0.0, half_width=0.14, toe_out=6)
    for side in (1, -1):
        hip = body.pelvis.at(u=0.09, r=side * 0.2, f=0.0)
        body.arm(side, hip, unit(body.chest.r * side * 1.0 - body.chest.f * 0.45))
    show(s, body)


SIDE_BEND = ("Debout, haltère le long de la cuisse", "Incline le buste sur le côté", "Haltère près du genou", "Retour droit")


@demo("x-dumbbell-side-bend", views=[FRONT(), THREE_QUARTER(40, 12)], labels=SIDE_BEND, timing=(0.6, 1.4, 0.4, 1.4),
      muscles=(["abs", "obliques"], []))
def dumbbell_side_bend(p, s):
    floor(s, -0.6, 0.6, -0.7, 0.7)
    k = smooth(p)
    side = 1
    body = upright(0.95, 0.0, pelvis_x=0.0, bend=lerp(0.0, 30.0, k), head=0.0)
    stance(body, 0.0, half_width=0.14, toe_out=6)
    sh = body.shoulder[side]
    grip = sh + vec(0.0, -0.6, side * 0.03)
    body.arm(side, grip, unit(-X * 0.1 + Z * side * 0.3))
    hip = body.pelvis.at(u=0.09, r=-side * 0.2)
    body.arm(-side, hip, unit(-body.chest.r * side * 1.0 - body.chest.f * 0.3))
    from gear import dumbbell
    dumbbell(s, body.grip[side], X, side=sd(side))
    show(s, body)


# --- Landmine 180 -----------------------------------------------------------------------------------------

@demo("x-landmine-180s", views=[THREE_QUARTER(55, 18), FRONT(14)],
      labels=("Barre à gauche, bras tendus", "Balayage en arc", "Barre à droite", "Retour de l'autre côté"),
      timing=(0.5, 1.1, 0.4, 1.1), muscles=(["abs", "obliques"], ["glutes", "lowerBack", "shoulders"]))
def landmine_180s(p, s):
    floor(s, -0.8, 2.2, -0.9, 0.9)
    k = smooth(p)
    yaw = lerp(-42.0, 42.0, k)
    pelvis_yaw = yaw * 0.55
    body = upright(0.9, 6.0, pelvis_x=0.0, facing=pelvis_yaw, twist=yaw - pelvis_yaw, head=0.0)
    stance(body, 0.0, half_width=0.2, facing=0.0, toe_out=0)
    # Hands together around the bar end, in front of the chest, arms straight.
    sh = mid(body)
    grip = sh + body.chest.f * 0.5 - body.chest.u * 0.1
    for side in (1, -1):
        body.arm(side, grip + body.chest.r * side * 0.05, unit(-Y * 0.4 + body.chest.r * side * 0.5))
    show(s, body)
    # The bar: its far end pivots on the floor ahead, the near end is in the hands.
    anchor = vec(1.95, 0.06, 0.0)
    s.line([anchor, grip + (grip - anchor) * 0.04], 0.04, "metal")
    s.line([grip + body.chest.r * 0.0, grip + (grip - anchor) * 0.1], 0.052, "load")
    s.ball(anchor, 0.045, "frame")
    s.line([anchor + vec(0.12, -0.05, 0.0), anchor - vec(0.12, 0.05, 0.0)], 0.05, "frame")


# --- Band external rotation -------------------------------------------------------------------------------

@demo("x-external-rotation-with-band", views=[ABOVE(90, 70), THREE_QUARTER(30, 14)],
      labels=("Avant-bras devant le ventre", "Tourne vers l'extérieur", "Avant-bras vers l'avant", "Retour lent"),
      timing=(0.6, 1.3, 0.5, 1.6), muscles=(["shoulders"], []))
def external_rotation_band(p, s):
    floor(s, -0.6, 1.0, -1.1, 0.7)
    k = smooth(p)
    side = 1
    body = upright(0.95, 0.0, pelvis_x=0.0, head=0.0)
    stance(body, 0.0, half_width=0.14, toe_out=6)
    sh = body.shoulder[side]
    upper = unit(-Y + Z * side * 0.12)
    elbow = sh + upper * Body.UPPER
    ang = lerp(62.0, -12.0, k)                    # forearm: across the belly (toward -z) to straight ahead / a bit out
    fore = unit(X * math.cos(math.radians(ang)) - Z * side * math.sin(math.radians(ang)) + Y * 0.05)
    body.arm_dirs(side, upper, fore)
    # The other arm hangs along the body.
    body.arm(-side, body.shoulder[-side] + vec(0.0, -0.62, -side * 0.02), unit(-X * 0.2 - Z * side * 0.2))
    grip = body.grip[side]
    post = vec(0.28, 0.0, -0.95)
    s.line([post, post + Y * 1.45], TUBE * 1.4, "frame")
    s.line([post + Y * 0.0 - X * 0.15, post + X * 0.15], TUBE, "frame")
    anchor = vec(post[0], grip[1], post[2] + 0.03)
    s.line([anchor, grip], 0.022, "load")
    s.line([grip - X * 0.02 - Z * 0.02, grip + X * 0.02 + Z * 0.02], 0.04, "load")
    show(s, body)


# --- Sled drag ---------------------------------------------------------------------------------------------

@demo("x-sled-drag-harness", views=[PROFILE(), THREE_QUARTER(35, 12)], mode="loop", timing=1.1, samples=24, labels=(),
      travel=(1.0, 0.25, -2.6, 1.0, -0.5, 0.5, 0.0, 40.0),
      muscles=(["quads"], ["calves", "glutes", "hamstrings"]))
def sled_drag_harness(p, s):
    floor(s, -2.6, 1.0)
    body = walk_cycle(p, s, stride=0.5, arms="swing", lean=26.0, bounce=0.012, stance=0.62, lift=0.12, hip=0.84, ahead=-0.1)
    # Waist belt, a strap down to the sled behind.
    belt = body.pelvis.at(u=0.03, f=-(Body.W_TORSO / 2 + 0.035))
    left, right = belt - body.pelvis.r * 0.13, belt + body.pelvis.r * 0.13
    s.line([left, right], 0.045, "load")
    s.line([belt - body.pelvis.f * 0.0, belt - body.pelvis.r * 0.0 + vec(0, 0, 0)], 0.03, "load")
    sled_x = -1.75
    hitch = vec(sled_x + 0.42, 0.2, 0.0)
    s.line([belt, hitch], 0.02, "cable")
    s.box(vec(sled_x, 0.05, 0.0), X * 0.45, Y * 0.04, Z * 0.3, "frame", stroke=0.01)
    s.line([vec(sled_x + 0.45, 0.05, 0.0), vec(sled_x + 0.58, 0.14, 0.0)], 0.03, "metal")
    s.line([vec(sled_x - 0.1, 0.09, 0.0), vec(sled_x - 0.1, 0.5, 0.0)], 0.04, "metal")
    s.disc(vec(sled_x - 0.1, 0.2, 0.0), Y, 0.22, "load")
    s.disc(vec(sled_x - 0.1, 0.26, 0.0), Y, 0.22, "load")
    s.line([vec(sled_x + 0.42, 0.09, 0.0), hitch], 0.03, "metal")
    show(s, body)


# --- Weighted sissy squat ----------------------------------------------------------------------------------

@demo("x-weighted-sissy-squat", views=[PROFILE(), THREE_QUARTER(35, 12)],
      labels=("Debout sur la pointe, disque contre la poitrine", "Genoux vers l'avant, buste en arrière",
              "Ligne genoux-épaules, talons hauts", "Remontée en poussant les genoux"),
      timing=(0.6, 1.8, 0.5, 1.6), muscles=(["quads"], ["calves", "glutes", "hamstrings"]))
def weighted_sissy_squat(p, s):
    floor(s, -1.0, 0.9)
    k = smooth(p)
    psi = lerp(2.0, 48.0, k)                      # torso and thigh lean back together
    gamma = lerp(2.0, 50.0, k)                    # the shin leans forward
    heel = lerp(22.0, 52.0, k)                    # heel lift
    toe = vec(0.17, 0.02, 0.0)
    foot = unit(vec(-math.cos(math.radians(heel)), math.sin(math.radians(heel)), 0.0))
    ankle = toe + foot * 0.176
    knee = ankle + vec(math.sin(math.radians(gamma)), math.cos(math.radians(gamma)), 0.0) * Body.SHIN
    hip = knee + vec(-math.sin(math.radians(psi)), math.cos(math.radians(psi)), 0.0) * Body.THIGH
    # the torso continues the thigh line, leaning back
    u = vec(-math.sin(math.radians(psi)), math.cos(math.radians(psi)), 0.0)
    f = vec(u[1], -u[0], 0.0)
    body = Body(Frame(hip - Body.HIP_HALF * 0, f, u), head=lerp(0.0, -8.0, k))
    for side in (1, -1):
        zz = side * 0.13
        a = ankle + Z * zz
        t = toe + Z * zz
        body.leg(side, a + (body.hip[side] - hip) * 0.0 - Z * 0.0, pole=X)
        body.toe[side] = t
    # Plate held against the chest by the right hand, the left hand on the rack upright.
    c = body.chest
    pc = c.at(u=0.27, f=Body.W_TORSO / 2 + 0.12)
    plate(s, pc, c.f, r=0.17)
    body.arm(1, pc + c.r * 0.0 + c.u * 0.1 + c.r * 0.04 - c.u * 0.17 * 0.0, unit(c.r * 0.9 - c.u * 0.6 - c.f * 0.2))
    post_x = 0.2
    post = vec(post_x, 0.0, -0.4)
    s.line([post, post + Y * 1.9], TUBE * 1.5, "frame", side=SIDE_LEFT)
    s.line([post - X * 0.2, post + X * 0.3], TUBE, "frame", side=SIDE_LEFT)
    grip = vec(post_x - 0.03, 1.12, -0.4)
    body.arm(-1, grip, unit(-Y * 0.5 - Z * 0.4))
    show(s, body)
