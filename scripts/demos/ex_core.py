"""Core: crunches, planks, leg raises, rotations, Pallof press, ab wheel, back extension, superman,
bird dog, mountain climbers."""
import math

import numpy as np

from demos import demo, show
from engine import (ABOVE, BACK, FRONT, PROFILE, THREE_QUARTER, Body, Frame, SIDE_LEFT, SIDE_RIGHT, View, X, Y, Z,
                    lerp, posture, rotate, unit, vec)
from gear import PAD_T, TUBE, Column, cable, d_handle, floor, foot_bar
from machines import roller, stack
from poses import feet_flat, placed, plank_on_toes, solve, stance, upright

HOLD = ("Mise en place", "Montée en position", "Position tenue", "Relâche")


def smooth(t):
    t = min(1.0, max(0.0, t))
    return t * t * (3 - 2 * t)


def supine(pelvis_x=0.0, spine=0.0, head=20.0, y=None, **args):
    """Lying on the back on the floor, head toward -x."""
    origin = vec(pelvis_x, Body.W_TORSO / 2 + 0.006 if y is None else y, 0.0)
    return Body(Frame(origin, Y, -X), spine=spine, head=head, **args)


def knees_up_feet_flat(body, feet_x=0.36):
    for side in (1, -1):
        body.foot_on_floor(side, (body.pelvis.o[0] + feet_x, side * 0.12), 0.0, pole=Y)


@demo("crunch", views=[PROFILE(), THREE_QUARTER(35, 16)],
      labels=("Allongé, genoux pliés", "Enroulement du haut du dos", "Omoplates décollées", "Descente lente"),
      timing=(0.6, 1.0, 0.6, 1.3))
def crunch(p, s):
    floor(s, -1.0, 0.8)
    body = supine(spine=lerp(0.0, 34.0, p), head=lerp(22.0, 30.0, p))
    knees_up_feet_flat(body)
    for side in (1, -1):
        temple = body.head + body.head_frame.r * side * 0.1 - body.head_frame.f * 0.0
        body.arm(side, temple, unit(body.chest.r * side * 1.0 + body.chest.u * 0.2))
    show(s, body)


@demo("sit-up", views=[PROFILE(), THREE_QUARTER(35, 16)],
      labels=("Allongé, pieds au sol", "Redressement complet", "Buste vers les genoux", "Descente lente"),
      timing=(0.6, 1.3, 0.4, 1.5))
def sit_up(p, s):
    floor(s, -1.0, 0.8)
    k = smooth(p)
    # The spine curls first, then the hips flex to sit up.
    curl = 35.0 * smooth(min(1.0, p * 2.0))
    hip = lerp(0.0, 62.0, smooth(max(0.0, (p - 0.25) / 0.75)))
    pelvis = Frame(vec(0.0, Body.W_TORSO / 2 + 0.006, 0.0), Y, -X).pitched(hip)
    body = Body(pelvis, spine=curl - hip * 0.35, head=lerp(22.0, 18.0, k))
    for side in (1, -1):
        body.foot_on_floor(side, (0.38, side * 0.13), 0.0, pole=Y)
        chest = body.chest.at(u=0.3, f=0.1, r=-side * 0.06)
        body.arm(side, chest, unit(body.chest.r * side + body.chest.f * 0.3))
    show(s, body)


@demo("bicycle-crunch", views=[THREE_QUARTER(40, 22), PROFILE()], mode="loop", timing=2.6, samples=24, labels=())
def bicycle_crunch(p, s):
    floor(s, -1.0, 0.9)
    a = math.sin(2 * math.pi * p)
    body = supine(spine=30.0, twist=24.0 * a, head=26.0, y=Body.W_TORSO / 2 + 0.006)
    for side in (1, -1):
        # Legs pedal: one knee in toward the chest while the other leg extends.
        bend = 0.5 + 0.5 * a * side
        thigh = unit(lerp(vec(0.75, 0.66, 0.0), vec(0.2, 0.98, 0.0), bend))
        thigh = unit(lerp(vec(0.9, 0.42, 0.0), vec(0.25, 0.97, 0.0), bend))
        shin = unit(lerp(vec(1.0, 0.05, 0.0), vec(0.7, -0.7, 0.0), bend))
        body.leg_dirs(side, thigh, shin)
        body.foot_relaxed(side, plantar=20)
        temple = body.head + body.head_frame.r * side * 0.1
        body.arm(side, temple, unit(body.chest.r * side + body.chest.u * 0.2))
    show(s, body)


@demo("cable-crunch", views=[PROFILE(), THREE_QUARTER(35, 14)],
      labels=("À genoux, corde près de la tête", "Enroulement du buste", "Coudes vers les cuisses", "Retour lent"),
      timing=(0.6, 1.1, 0.5, 1.4))
def cable_crunch(p, s):
    floor(s, -0.8, 1.2)
    s.slab(vec(-0.35, 0.03, 0), vec(0.15, 0.03, 0), Y, 0.5, 0.03, "pad")
    knee = vec(0.0, 0.03 + Body.W_SHIN / 2 + 0.004, 0.0)
    pelvis_pt = knee + vec(0.06, Body.THIGH - 0.01, 0.0)
    pelvis = Frame(pelvis_pt, X, Y).pitched(8.0)
    body = Body(pelvis, spine=lerp(25.0, 82.0, p), head=lerp(20.0, 30.0, p))
    for side in (1, -1):
        k = vec(knee[0], knee[1], side * 0.12)
        body.leg_dirs(side, unit(k - body.hip[side]), -X)
        body.foot_relaxed(side, plantar=60)
    # Hands hold the rope beside the head; the rope follows the head down.
    pul = vec(0.78, 2.05, 0.0)
    knot = body.head + body.head_frame.u * 0.05 + body.chest.f * 0.12
    for side in (1, -1):
        g = body.head + body.head_frame.r * side * 0.1 + body.chest.f * 0.06
        body.arm(side, g, unit(body.chest.r * side - body.chest.u * 0.3 + body.chest.f * 0.6))
        s.line([knot, g], 0.022, "load", side=SIDE_RIGHT if side == 1 else SIDE_LEFT)
    col = Column(s, 0.95, 0.0, height=2.2, depth=0.24, width=0.4)
    col.frame(lift=p * 0.35)
    s.disc(pul, Z, 0.045, "frame")
    cable(s, pul, knot)
    show(s, body)


# --- Planks -----------------------------------------------------------------------------------------

@demo("plank", views=[PROFILE(), THREE_QUARTER(35, 14)],
      labels=("Avant-bras sous les épaules", "Décolle les genoux", "Corps aligné : tiens", "Repose les genoux"),
      timing=(0.8, 1.0, 3.0, 1.0))
def plank(p, s):
    floor(s, -0.4, 1.8)
    # Forearms on the floor, elbows under the shoulders; the body pivots from the knees to the toes.
    elbow_y = Body.W_LOWER / 2 + 0.005
    sh_y = elbow_y + Body.UPPER

    def make(theta, on_knees):
        frame = posture(vec(0, 0, 0), 0.0, 90.0 - theta)
        if on_knees:
            knee = vec(0.0, Body.W_SHIN / 2 + 0.005, 0.0)
            pelvis = knee + frame.u * Body.THIGH
            b = Body(Frame(pelvis, frame.f, frame.u), head=-6)
            for side in (1, -1):
                b.leg_dirs(side, -frame.u, -X)
                b.foot_relaxed(side, plantar=50)
        else:
            b = plank_on_toes(theta, toe_x=-0.5, head=-6)
        return b

    def shy(theta, knees):
        m = make(theta, knees)
        return ((m.shoulder[1] + m.shoulder[-1]) / 2)[1]

    t_knees = solve(lambda t: shy(t, True), -5, 60, sh_y)
    t_toes = solve(lambda t: shy(t, False), -5, 60, sh_y)
    k = smooth(p)
    on_knees = p < 0.5
    b_knee = make(t_knees, True)
    b_toe = make(t_toes, False)
    # Blend: the shoulders stay over the elbows; legs go from kneeling to straight.
    if p <= 0.0:
        body = b_knee
    elif p >= 1.0:
        body = b_toe
    else:
        frame = posture(vec(0, 0, 0), 0.0, 90.0 - lerp(t_knees, t_toes, k))
        target = lerp((b_knee.shoulder[1] + b_knee.shoulder[-1]) / 2, (b_toe.shoulder[1] + b_toe.shoulder[-1]) / 2, k)
        body = placed(frame, "shoulders", target, head=-6)
        for side in (1, -1):
            knee_a = b_knee.knee[side]
            ank_b = b_toe.ankle[side]
            ankle = lerp(b_knee.ankle[side], ank_b, k)
            body.leg(side, ankle, pole=-Y)
            body.foot_toward(side, lerp(b_knee.toe[side], b_toe.toe[side], k))
    sh_x = ((b_toe.shoulder[1] + b_toe.shoulder[-1]) / 2)[0]
    for side in (1, -1):
        sh = body.shoulder[side]
        elbow = vec(sh_x, elbow_y, sh[2])
        body.arm_dirs(side, unit(elbow - sh), X)
    show(s, body)


SIDE_PLANK_SAG = 24.0


@demo("side-plank", views=[PROFILE(8), THREE_QUARTER(30, 18)],
      labels=("Sur le côté, avant-bras au sol", "Monte les hanches", "Corps aligné : tiens", "Redescends"),
      timing=(0.8, 1.0, 3.0, 1.0))
def side_plank(p, s):
    floor(s, -0.7, 1.4, -0.6, 0.6)
    # Lying on the right side, head toward -x, chest toward the viewer; right elbow under the shoulder.
    elbow = vec(-0.42, Body.W_LOWER / 2 + 0.005, 0.0)
    shoulder_right = elbow + Y * Body.UPPER
    s_mid = shoulder_right + Y * Body.SH_HALF
    torso = Body.LUMBAR + Body.THORAX - Body.SH_DROP
    reach = torso + Body.THIGH + Body.SHIN - 0.01
    dy = s_mid[1] - 0.07
    feet = vec(s_mid[0] + math.sqrt(reach ** 2 - dy ** 2), 0.07, 0.0)
    # Hips low at first: the upper arm leans toward the feet so the shoulders sink, and the pelvis
    # drops below the line while the legs stay straight and the feet stay put.
    lean = math.radians(SIDE_PLANK_SAG * (1.0 - smooth(p)))
    s_mid = elbow + vec(math.sin(lean), math.cos(lean), 0.0) * Body.UPPER + Y * Body.SH_HALF
    along = unit(feet - s_mid)

    def pelvis_at(phi):
        c, sn = math.cos(phi), math.sin(phi)
        return s_mid + vec(along[0] * c + along[1] * sn, along[1] * c - along[0] * sn, 0.0) * torso

    def gap(phi):
        pel = pelvis_at(phi)
        uu = unit(s_mid - pel)
        down = vec(uu[1], -uu[0], 0.0) if uu[0] > 0 else vec(-uu[1], uu[0], 0.0)
        hip = pel + down * Body.HIP_HALF
        return float(np.linalg.norm(feet - hip)) - (Body.THIGH + Body.SHIN - 0.004)

    lo, hi = 0.0, math.radians(50)
    for _ in range(40):
        mid = (lo + hi) / 2
        if gap(mid) > 0:
            hi = mid
        else:
            lo = mid
    pelvis_pt = pelvis_at(lo)
    u = unit(s_mid - pelvis_pt)
    frame = Frame(vec(0, 0, 0), Z, u)
    body = placed(frame, "shoulders", s_mid, head=-4)
    for side, dy in ((1, 0.0), (-1, 0.11)):
        ankle = vec(feet[0], feet[1] + dy, 0.0)
        body.leg(side, ankle, pole=Z)
        body.foot_toward(side, ankle + Z * 0.165 - X * 0.05)
    body.arm_dirs(1, unit(elbow - body.shoulder[1]), Z * 0.15 - X)
    body.arm(-1, body.pelvis.at(r=-0.17, u=0.1, f=0.02), unit(Y + X * 0.3))
    show(s, body)


@demo("ab-wheel", views=[PROFILE(), THREE_QUARTER(35, 14)],
      labels=("À genoux, roue sous les épaules", "Roulé vers l'avant", "Corps allongé, dos neutre", "Retour en contractant"),
      timing=(0.6, 1.6, 0.4, 1.4))
def ab_wheel(p, s):
    floor(s, -0.6, 1.7)
    knee = vec(0.0, Body.W_SHIN / 2 + 0.005, 0.0)
    wheel_r = 0.09
    k = smooth(p)
    thigh_angle = lerp(72.0, 22.0, k)        # thighs from the floor
    u_thigh = vec(math.cos(math.radians(thigh_angle)), math.sin(math.radians(thigh_angle)), 0.0)
    hip = knee + u_thigh * Body.THIGH
    sh_target = lerp(wheel_r + 0.6, 0.3, k)   # shoulder height: arms vertical at first, then reaching forward

    def make(torso_angle):
        u = vec(math.cos(math.radians(torso_angle)), math.sin(math.radians(torso_angle)), 0.0)
        f = vec(u[1], -u[0], 0.0)
        return Body(Frame(hip, f, u), head=-8)

    def sh_y(a):
        b = make(a)
        return ((b.shoulder[1] + b.shoulder[-1]) / 2)[1]

    body = make(solve(sh_y, -20.0, 80.0, sh_target))
    for side in (1, -1):
        kn = vec(knee[0], knee[1], side * 0.11)
        body.leg_dirs(side, unit(kn - body.hip[side]), -X)
        body.foot_relaxed(side, plantar=55)
    sh = (body.shoulder[1] + body.shoulder[-1]) / 2
    dx = math.sqrt(max(0.0, 0.625 ** 2 - (sh[1] - wheel_r) ** 2))
    wheel = vec(sh[0] + dx, wheel_r, 0.0)
    for side in (1, -1):
        body.arm(side, wheel + Z * side * 0.07, unit(-X + Z * side * 0.2))
    s.disc(wheel, Z, wheel_r, "load")
    s.line([wheel - Z * 0.12, wheel + Z * 0.12], 0.03, "metal")
    show(s, body)


# --- Leg raises ---------------------------------------------------------------------------------------

@demo("leg-raise", views=[PROFILE(), THREE_QUARTER(35, 16)],
      labels=("Allongé, jambes tendues", "Montée des jambes", "Jambes à la verticale", "Descente sans toucher le sol"),
      timing=(0.6, 1.2, 0.4, 1.6))
def leg_raise(p, s):
    floor(s, -1.0, 1.1)
    body = supine(head=20.0)
    angle = lerp(8.0, 88.0, p)
    d = vec(math.cos(math.radians(angle)), math.sin(math.radians(angle)), 0.0)
    for side in (1, -1):
        body.leg_dirs(side, d, d)
        body.foot_relaxed(side, plantar=10)
        body.arm(side, vec(body.shoulder[side][0] + 0.56 * (1 if body.pelvis.o[0] > body.shoulder[side][0] else -1), 0.04, side * 0.26), unit(Z * side + Y * 0.2))
    show(s, body)


@demo("hanging-leg-raise", views=[PROFILE(4), THREE_QUARTER(35, 10)],
      labels=("Suspendu, jambes tendues", "Montée des jambes", "Hanches à 90°", "Descente contrôlée"),
      timing=(0.6, 1.2, 0.4, 1.6))
def hanging_leg_raise(p, s):
    from ex_back import pull_station
    floor(s, -0.9, 1.0, -0.8, 0.8)
    pull_station(s, 2.3)
    sh = vec(-0.03, 2.3 - 0.6, 0.0)
    body = placed(posture(vec(0, 0, 0), 0.0, lerp(-2.0, -12.0, p)), "shoulders", sh, head=0, spine=lerp(0.0, 10.0, p))
    for side in (1, -1):
        body.arm(side, vec(0.0, 2.3, side * 0.32), unit(-X * 0.3 + Z * side))
        angle = lerp(-88.0, 2.0, p)
        d = vec(math.cos(math.radians(angle)), math.sin(math.radians(angle)), 0.0)
        body.leg_dirs(side, d, d)
        body.foot_relaxed(side, plantar=15)
    show(s, body)


@demo("dead-bug", views=[THREE_QUARTER(40, 22), PROFILE()], mode="loop", timing=4.4, samples=32, labels=())
def dead_bug(p, s):
    floor(s, -1.1, 1.0)
    body = supine(head=18.0)
    # First the right arm and left leg extend, then the left arm and right leg.
    for side, phase in ((1, 0.0), (-1, 0.5)):
        t = (p - phase) % 1.0
        ext = math.sin(math.pi * min(1.0, t / 0.5)) if t < 0.5 else 0.0
        e = smooth(ext)
        # Arm: from pointing at the ceiling to overhead near the floor.
        a_angle = lerp(90.0, 170.0, e)
        arm_d = vec(-math.cos(math.radians(180 - a_angle)), math.sin(math.radians(a_angle)), 0.0)
        body.arm(side, body.shoulder[side] + arm_d * 0.62, unit(X * 0.3 + body.chest.r * side))
    for side, phase in ((-1, 0.0), (1, 0.5)):
        t = (p - phase) % 1.0
        ext = math.sin(math.pi * min(1.0, t / 0.5)) if t < 0.5 else 0.0
        e = smooth(ext)
        thigh = unit(lerp(vec(0.0, 1.0, 0.0), vec(0.98, 0.18, 0.0), e))
        shin = unit(lerp(vec(1.0, 0.0, 0.0), vec(0.98, 0.18, 0.0), e))
        body.leg_dirs(side, thigh, shin)
        body.foot_relaxed(side, plantar=10)
    show(s, body)


@demo("hollow-hold", views=[PROFILE(), THREE_QUARTER(35, 16)], labels=HOLD, timing=(0.8, 1.0, 3.0, 1.0))
def hollow_hold(p, s):
    floor(s, -1.3, 1.2)
    k = smooth(p)
    body = supine(spine=lerp(0.0, 22.0, k), head=lerp(18.0, 26.0, k))
    angle = lerp(0.0, 22.0, k)
    d = vec(math.cos(math.radians(angle)), math.sin(math.radians(angle)) + 0.02, 0.0)
    for side in (1, -1):
        body.leg_dirs(side, d, d)
        body.foot_relaxed(side, plantar=25)
        over = unit(-body.chest.u * 0.97 + body.chest.f * lerp(0.0, 0.26, k))
        body.arm(side, body.shoulder[side] + over * 0.62, unit(body.chest.r * side + Y * 0.1))
    show(s, body)


# --- Rotation and anti-rotation --------------------------------------------------------------------------

@demo("russian-twist", views=[View("Face", 90, 18), THREE_QUARTER(45, 20)], mode="loop", timing=2.6, samples=24, labels=())
def russian_twist(p, s):
    floor(s, -0.8, 0.9, -0.8, 0.8)
    a = math.sin(2 * math.pi * p)
    pelvis = Frame(vec(0.0, Body.W_THIGH / 2 + 0.004, 0.0), X, Y).pitched(-45.0)
    body = Body(pelvis, twist=42.0 * a, spine=8.0, head=10.0)
    for side in (1, -1):
        body.leg_dirs(side, unit(vec(0.8, 0.6, 0.0)), unit(vec(0.94, -0.34, 0.0)))
        body.foot_relaxed(side, plantar=10)
    ball = body.chest.at(u=0.12, f=0.33)
    for side in (1, -1):
        body.arm(side, ball + body.chest.r * side * 0.1, unit(-Y + body.chest.r * side * 0.5))
    s.ball(ball, 0.11, "load")
    show(s, body)


@demo("woodchop", views=[View("Face", 90, 8), THREE_QUARTER(50, 12)],
      labels=("Poignée en haut, à droite", "Tirage en diagonale", "Mains en bas, à gauche", "Retour contrôlé"),
      timing=(0.6, 1.0, 0.4, 1.4))
def woodchop(p, s):
    floor(s, -0.8, 0.9, -1.2, 0.9)
    k = smooth(p)
    body = upright(lerp(0.92, 0.86, k), 2.0, pelvis_x=0.0, twist=lerp(-38.0, 42.0, k), head=0)
    stance(body, 0.0, half_width=0.25, toe_out=10)
    pul = vec(0.0, 2.05, 0.95)
    sh = (body.shoulder[1] + body.shoulder[-1]) / 2
    start = sh + unit(vec(0.3, 0.75, 0.55)) * 0.58
    end = sh + unit(vec(0.35, -0.75, -0.55)) * 0.62
    grip = lerp(start, end, k)
    for side in (1, -1):
        body.arm(side, grip + Y * 0.04 * side, unit(-Y + body.chest.r * side * 0.3))
    col = Column(s, 0.0, 1.12, height=2.2, depth=0.24, width=0.24)
    col.frame(lift=np.linalg.norm(grip - pul) - np.linalg.norm(start - pul))
    s.disc(pul, X, 0.045, "frame")
    cable(s, pul, grip)
    d_handle(s, grip, Y)
    show(s, body)


@demo("pallof-press", views=[PROFILE(), View("Dessus", 0, 62)],
      labels=("Poignée contre le sternum", "Bras tendus devant", "Résiste à la rotation", "Retour à la poitrine"),
      timing=(0.6, 1.0, 1.0, 1.0))
def pallof_press(p, s):
    floor(s, -0.6, 1.0, -1.4, 0.7)
    body = upright(0.9, 0.0, pelvis_x=0.0, head=0)
    stance(body, 0.0, half_width=0.22, toe_out=8)
    chest = body.chest.at(u=0.27, f=Body.W_TORSO / 2 + 0.06)
    out = chest + X * 0.5
    grip = lerp(chest, out, smooth(p))
    for side in (1, -1):
        body.arm(side, grip + Z * side * 0.03, unit(-Y + Z * side * 0.4))
    pul = vec(chest[0] + 0.05, chest[1], -1.15)
    col = Column(s, chest[0] + 0.05, -1.28, height=2.15, depth=0.24, width=0.24)
    col.frame(lift=np.linalg.norm(grip - pul) - np.linalg.norm(chest - pul))
    s.disc(pul, Y, 0.045, "frame")
    cable(s, pul, grip)
    d_handle(s, grip, Y)
    show(s, body)


@demo("mountain-climber", views=[PROFILE(), THREE_QUARTER(35, 14)], mode="loop", timing=1.0, samples=24, labels=())
def mountain_climber(p, s):
    floor(s, -0.6, 1.6)
    theta = 18.5
    body = plank_on_toes(theta, toe_x=-0.05, head=-10)
    hands_x = ((body.shoulder[1] + body.shoulder[-1]) / 2)[0]
    # The legs swap together: one knee under the chest while the other leg is long behind, then a
    # quick switch with both feet off the floor.
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
        hip = body.hip[side]
        foot_back = body.ankle[side]
        # The knee drives under the chest, the foot coming in under the hips on the ball of the foot;
        # the body stays in a plank (hips level, hands planted).
        tuck = vec(hip[0] + 0.04, 0.17, hip[2])
        hop = 0.1 * math.sin(math.pi * drive) if switching else 0.0
        ankle = lerp(foot_back, tuck, drive) + Y * hop
        body.leg(side, ankle, pole=unit(X + Y * 0.25))
        toe_tuck = ankle + unit(vec(0.35, -0.94, 0.0)) * 0.17
        toe_back = ankle + body.pelvis.f * 0.165 - body.pelvis.u * 0.06
        body.foot_toward(side, lerp(toe_back, toe_tuck, smooth(drive)))
        body.arm(side, vec(hands_x, 0.025, side * 0.26), unit(-body.chest.u + body.chest.r * side * 0.4))
    show(s, body)


# --- Lower back -----------------------------------------------------------------------------------------

@demo("back-extension", views=[PROFILE(), THREE_QUARTER(35, 12)],
      labels=("Hanches sur l'appui, corps aligné", "Descente du buste", "Buste vers le sol", "Remontée sans cambrer"),
      timing=(0.6, 1.3, 0.4, 1.3))
def back_extension(p, s):
    floor(s, -0.9, 1.3)
    tilt = 45.0
    d = vec(math.cos(math.radians(tilt)), math.sin(math.radians(tilt)), 0.0)    # along the body, toward the head
    n = vec(-d[1], d[0], 0.0) * -1                                                  # under the body (the pads' side)
    # Feet under the rollers at the low end, hips on the pad at the high end.
    ankle = vec(-0.05, 0.3, 0.0)
    hip_pt = ankle + d * (Body.SHIN + Body.THIGH)
    pelvis_frame = Frame(hip_pt, n, d)
    flex = lerp(0.0, 70.0, p)
    body = Body(pelvis_frame.pitched(flex), head=-8)
    for side in (1, -1):
        body.leg_dirs(side, -d, -d)
        body.toe[side] = body.ankle[side] + n * 0.165 - d * 0.06
        cross = body.chest.at(u=0.3, f=0.1, r=-side * 0.06)
        body.arm(side, cross, unit(body.chest.r * side + body.chest.f * 0.3))
    pad = hip_pt + n * (Body.W_THIGH / 2 + 0.004) - d * 0.06
    s.slab(pad - d * 0.2, pad + d * 0.05, -n, 0.4, 0.08, "pad", solid="l'appui")
    roller(s, body.ankle[1] - n * (Body.W_SHIN / 2 + 0.05) + d * 0.03 - Z * body.ankle[1][2], half=0.18)
    plate = ankle + n * 0.06 - d * 0.1
    s.line([vec(plate[0], plate[1], -0.2), vec(plate[0], plate[1], 0.2)], 0.05, "frame")
    s.line([plate, pad + n * 0.08], TUBE * 1.2, "frame")
    s.line([plate, vec(plate[0] - 0.1, 0.03, 0.0)], TUBE * 1.2, "frame")
    s.line([pad + n * 0.08, vec(pad[0] + 0.25, 0.03, 0.0)], TUBE * 1.2, "frame")
    s.line([vec(plate[0] - 0.3, 0.03, 0.0), vec(pad[0] + 0.4, 0.03, 0.0)], TUBE, "frame")
    s.allow = {("cuisse droit", "l'appui"), ("cuisse gauche", "l'appui")}
    show(s, body)


@demo("superman", views=[PROFILE(), THREE_QUARTER(35, 16)],
      labels=("À plat ventre, bras devant", "Décolle bras, buste et jambes", "Tiens deux secondes", "Redescends"),
      timing=(0.6, 1.0, 1.6, 1.0))
def superman(p, s):
    floor(s, -1.2, 1.5)
    k = smooth(p)
    origin = vec(0.0, Body.W_TORSO / 2 + 0.006, 0.0)
    body = Body(Frame(origin, -Y, X), spine=lerp(0.0, -14.0, k), head=lerp(-18.0, -22.0, k))
    lift = lerp(0.0, 10.0, k)
    d = vec(-math.cos(math.radians(lift)), math.sin(math.radians(lift)), 0.0)
    for side in (1, -1):
        body.leg_dirs(side, d, d)
        body.foot_relaxed(side, plantar=60)
        reach = unit(body.chest.u * 1.0 + Y * lerp(0.0, 0.12, k) + body.chest.r * side * 0.15)
        body.arm(side, body.shoulder[side] + reach * 0.63, unit(Y + body.chest.r * side))
    show(s, body)


@demo("bird-dog", views=[PROFILE(), THREE_QUARTER(35, 16)], mode="loop", timing=4.4, samples=32, labels=())
def bird_dog(p, s):
    from ex_legs import quadruped, plant_quadruped
    floor(s, -1.1, 1.4)
    body = quadruped()
    # Right arm with left leg, then left arm with right leg.
    phase = 0 if p < 0.5 else 1
    t = (p % 0.5) / 0.5
    e = smooth(math.sin(math.pi * t))
    arm_side, leg_side = (1, -1) if phase == 0 else (-1, 1)
    plant_quadruped(body, skip={("arm", arm_side), ("leg", leg_side)})
    sh = body.shoulder[arm_side]
    floor_pt = vec(sh[0] + 0.02, 0.04, sh[2] + arm_side * 0.02)
    fwd = vec(1.0, 0.05, 0.0)
    d = unit(lerp(unit(floor_pt - sh), fwd, e))
    reach = lerp(min(0.62, float(np.linalg.norm(floor_pt - sh))), 0.62, e)
    body.arm(arm_side, sh + d * reach, unit(-X + Z * arm_side * 0.3) if e < 0.2 else unit(Y))
    hip = body.hip[leg_side]
    knee_floor = vec(hip[0], Body.W_SHIN / 2 + 0.004, hip[2])
    thigh = unit(lerp(unit(knee_floor - hip), vec(-1.0, 0.04, 0.0), e))
    shin = unit(lerp(vec(-1.0, 0.0, 0.0), vec(-1.0, 0.04, 0.0), e))
    body.leg_dirs(leg_side, thigh, shin)
    body.foot_relaxed(leg_side, plantar=lerp(60.0, 10.0, e))
    show(s, body)
