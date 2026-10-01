"""Mobility and stretching: circles, stick dislocates, cat-cow, lunges with rotation, ankle and
thoracic mobility; hamstring, quad, hip flexor, calf, chest, triceps, shoulder stretches, child's
pose, pigeon, cobra."""
import math

import numpy as np

from demos import demo, show
from engine import (ABOVE, BACK, FRONT, PROFILE, THREE_QUARTER, Body, Frame, SIDE_LEFT, SIDE_RIGHT, View, X, Y, Z,
                    lerp, posture, rotate, unit, vec)
from gear import TUBE, floor
from poses import placed, solve, stance, upright

STRETCH = ("Mise en place", "Entrée dans l'étirement", "Tiens 20 à 40 s en respirant", "Relâche doucement")


def smooth(t):
    t = min(1.0, max(0.0, t))
    return t * t * (3 - 2 * t)


def mid(body):
    return (body.shoulder[1] + body.shoulder[-1]) / 2


def wall(s, x, y1=2.0, half=0.7, facing=1):
    s.box(vec(x + facing * 0.04, y1 / 2, 0.0), X * 0.04, Y * y1 / 2, Z * half, "floor", stroke=0.0, bias=10.0)


def mat(s, x0, x1, half=0.32):
    s.slab(vec(x0, 0.012, 0), vec(x1, 0.012, 0), Y, half * 2, 0.012, "pad")



def half_kneeling(front_ankle_x, shin_angle, rear_knee_x, lean=2.0, head=0, mat_top=0.0):
    """Half-kneeling on the left knee: the right foot flat in front, its shin leaning forward by
    shin_angle degrees; the hips sit where both thighs reach (left knee on the floor)."""
    a = math.radians(shin_angle)
    front_ankle = vec(front_ankle_x, Body.ANKLE + mat_top, 0.12)
    front_knee = front_ankle + vec(math.sin(a), math.cos(a), 0.0) * Body.SHIN
    rear_knee = vec(rear_knee_x, mat_top + Body.W_SHIN / 2 + 0.006, -0.12)
    # Hip joints sit 0.09 from the middle; both knees are 0.12 out: 0.03 sideways from their hip.
    r = math.sqrt(Body.THIGH ** 2 - 0.03 ** 2)
    c1, c2 = front_knee[:2], rear_knee[:2]
    d = float(np.linalg.norm(c2 - c1))
    m = (d * d) / (2 * d)
    h = math.sqrt(max(r * r - m * m, 0.0))
    mid = (c1 + c2) / 2
    perp = np.array([-(c2 - c1)[1], (c2 - c1)[0]]) / d
    if perp[1] < 0:
        perp = -perp
    hip = mid + perp * h
    body = upright(float(hip[1]), lean, pelvis_x=float(hip[0]), head=head)
    body.leg(1, front_ankle, pole=X)
    body.toe[1] = front_ankle + X * 0.165 - Y * 0.06
    body.leg_dirs(-1, unit(rear_knee - body.hip[-1]), -X)
    body.foot_toward(-1, body.ankle[-1] + vec(-0.17, -0.025, 0.0))
    body.planted[1] = True
    return body

def hands_on_hips(body):
    for side in (1, -1):
        body.arm(side, body.pelvis.at(u=0.12, r=side * 0.16, f=0.02), unit(-X * 0.6 + body.chest.r * side))


# --- Mobility -------------------------------------------------------------------------------------

@demo("arm-circles", views=[THREE_QUARTER(40, 12), FRONT(6)], mode="loop", timing=1.6, samples=24, labels=(),
      muscles=(["shoulders"], []))
def arm_circles(p, s):
    floor(s, -0.6, 0.6, -0.9, 0.9)
    body = upright(0.945, 0.0, pelvis_x=0.0, head=0)
    stance(body, 0.0, half_width=0.15)
    a = 2 * math.pi * p
    for side in (1, -1):
        sh = body.shoulder[side]
        center = sh + Z * side * 0.6
        grip = center + (X * math.cos(a) + Y * math.sin(a)) * 0.12
        body.arm(side, grip, unit(-Y - X * 0.3))
    show(s, body)


@demo("shoulder-dislocates", views=[PROFILE(), THREE_QUARTER(40, 12)],
      labels=("Bâton devant les cuisses, prise large", "Bras tendus au-dessus de la tête", "Bâton derrière le dos", "Retour par le même chemin"),
      timing=(0.6, 1.8, 0.5, 1.8), muscles=(["shoulders"], ["chest"]))
def shoulder_dislocates(p, s):
    floor(s, -0.8, 0.8)
    body = upright(0.945, 0.0, pelvis_x=0.0, head=0)
    stance(body, 0.0, half_width=0.15)
    angle = lerp(-80.0, 245.0, p)      # arms turning forward, over the head, to the back
    d = vec(math.cos(math.radians(angle)), math.sin(math.radians(angle)), 0.0)
    m = mid(body)
    half = 0.62
    for side in (1, -1):
        reach = math.sqrt(0.63 ** 2 - (half - Body.SH_HALF) ** 2)
        body.arm(side, m + d * reach + Z * side * half, unit(-Y + Z * side * 0.2))
    stick = m + d * math.sqrt(0.63 ** 2 - (half - Body.SH_HALF) ** 2)
    s.line([stick - Z * 0.75, stick + Z * 0.75], 0.03, "metal")
    show(s, body)


@demo("hip-circles", views=[THREE_QUARTER(35, 18), FRONT(8)], mode="loop", timing=2.6, samples=24, labels=(),
      muscles=(["glutes"], ["lowerBack"]))
def hip_circles(p, s):
    floor(s, -0.7, 0.7, -0.7, 0.7)
    a = 2 * math.pi * p
    shift = vec(0.07 * math.cos(a), 0.0, 0.07 * math.sin(a))
    pelvis = posture(vec(0.0, 0.92, 0.0) + shift, 0.0, -6.0 * math.cos(a)).rolled(6.0 * math.sin(a))
    body = Body(pelvis, spine=6.0 * math.cos(a), bend=-6.0 * math.sin(a), head=0)
    stance(body, -0.02, half_width=0.2, toe_out=10)
    hands_on_hips(body)
    show(s, body)


def quadruped(spine=0.0, pelvis_tilt=0.0, head=-12):
    from ex_legs import quadruped as q
    return q(head=head, spine=spine, pelvis_tilt=pelvis_tilt)


@demo("cat-cow", views=[PROFILE(), THREE_QUARTER(35, 16)],
      labels=("Dos rond, tête rentrée (chat)", "Passage lent", "Dos creusé, regard devant (vache)", "Retour au dos rond"),
      timing=(0.8, 1.6, 0.8, 1.6), muscles=(["lowerBack", "back"], ["abs"]))
def cat_cow(p, s):
    from ex_legs import plant_quadruped
    floor(s, -0.8, 1.1)
    k = smooth(p)
    body = quadruped(spine=lerp(42.0, -30.0, k), pelvis_tilt=lerp(-18.0, 14.0, k), head=lerp(34.0, -34.0, k))
    plant_quadruped(body)
    show(s, body)


@demo("worlds-greatest", views=[THREE_QUARTER(40, 18), PROFILE()],
      labels=("En fente, coude vers le pied avant", "Rotation du buste", "Bras vers le plafond", "Retour"),
      timing=(0.7, 1.4, 1.2, 1.2), muscles=(["hamstrings", "back"], ["quads", "glutes"]))
def worlds_greatest(p, s):
    floor(s, -1.2, 1.2, -0.7, 0.7)
    k = smooth(p)
    body = upright(0.42, 68.0, pelvis_x=0.0, twist=lerp(-10.0, -62.0, k), head=lerp(-20.0, -6.0, k))
    body.foot_on_floor(1, (0.55, 0.16), 0.0, pole=X)
    ankle = body.stand_foot(-1, vec(-0.8, 0.02, -0.12), 0.0, 55.0)     # rear leg long, on the toes
    body.leg(-1, ankle, pole=X)
    # Left hand on the floor inside the right foot; the right arm goes from the instep up to the ceiling.
    body.arm(-1, vec(0.48, 0.04, -0.05), unit(-X + Y * 0.2))
    sh = body.shoulder[1]
    down = vec(0.5, 0.25, 0.08)
    up = sh + unit(Y + body.chest.r * 0.3) * 0.62
    body.arm(1, lerp(down, up, k), unit(-X + body.chest.r * 0.4))
    show(s, body)


@demo("ankle-mobility", views=[PROFILE(), THREE_QUARTER(35, 14)],
      labels=("Genou au sol, pied avant près du mur", "Genou avant vers le mur", "Talon au sol, genou au mur", "Retour"),
      timing=(0.6, 1.2, 0.8, 1.0), muscles=(["calves"], []))
def ankle_mobility(p, s):
    wall_x = 0.62
    floor(s, -0.9, wall_x)
    wall(s, wall_x)
    mat(s, -0.75, -0.0)
    k = smooth(p)
    # Front toes about ten centimetres from the wall; the knee travels over the toes to the wall,
    # the heel staying down. The rear knee stays on the mat.
    front_x = wall_x - 0.275
    reach = math.degrees(math.asin((wall_x - 0.05 - front_x) / Body.SHIN))
    body = half_kneeling(front_x, lerp(8.0, reach, k), -0.12, lean=lerp(2.0, 6.0, k), mat_top=0.0)
    for side in (1, -1):
        body.arm(side, vec(wall_x - 0.02, body.shoulder[side][1] - 0.04, side * 0.2), unit(-Y - X * 0.3 + Z * side * 0.3))
    show(s, body)


@demo("thoracic-rotation", views=[View("3/4 avant", 55, 20), PROFILE()],
      labels=("À quatre pattes, main derrière la tête", "Coude vers le plafond", "Rotation du haut du dos", "Coude vers le bras d'appui"),
      timing=(0.6, 1.3, 0.6, 1.3), muscles=(["back"], ["obliques"]))
def thoracic_rotation(p, s):
    from ex_legs import plant_quadruped
    floor(s, -0.8, 1.1, -0.7, 0.7)
    k = smooth(p)
    body = __import__("ex_legs").quadruped(head=lerp(-5.0, -20.0, k), twist=lerp(15.0, -45.0, k), shoulder_y=0.64)
    plant_quadruped(body, skip={("arm", 1)})
    # Right hand behind the head, the elbow pointing out.
    hand = body.head - body.head_frame.f * 0.08 + body.head_frame.u * 0.0
    body.arm(1, hand, unit(body.chest.r * 1.0 - body.chest.f * 0.2))
    show(s, body)


# --- Stretches ---------------------------------------------------------------------------------------

@demo("hamstring-stretch", views=[PROFILE(), THREE_QUARTER(35, 16)], labels=STRETCH, timing=(0.8, 1.5, 3.0, 1.2),
      muscles=(["hamstrings"], ["lowerBack"]))
def hamstring_stretch(p, s):
    floor(s, -0.9, 1.1)
    mat(s, -0.7, 1.0)
    k = smooth(p)
    pelvis = Frame(vec(0.0, Body.W_THIGH / 2 + 0.02, 0.0), X, Y).pitched(lerp(-5.0, 45.0, k))
    body = Body(pelvis, spine=lerp(0.0, 22.0, k), head=lerp(0.0, 15.0, k))
    for side in (1, -1):
        body.leg_dirs(side, X, X)
        body.foot_relaxed(side, plantar=-5)
        toe = body.toe[side]
        rest = body.hip[side] + vec(0.22, -0.02, side * 0.06)
        body.arm(side, lerp(rest, toe - X * 0.12 + Y * 0.04, k), unit(-Y + body.chest.r * side * 0.4))
    show(s, body)


@demo("quad-stretch", views=[PROFILE(), THREE_QUARTER(35, 12)], labels=STRETCH, timing=(0.8, 1.2, 3.0, 1.0),
      muscles=(["quads"], []))
def quad_stretch(p, s):
    wall_x = 0.55
    floor(s, -0.8, wall_x)
    wall(s, wall_x)
    k = smooth(p)
    body = upright(0.945, 2.0, pelvis_x=0.0, head=0)
    body.foot_on_floor(-1, (0.0, -0.1), 0.0, pole=X)
    # Right knee bends, the heel goes to the buttock, held by the right hand; knees side by side.
    flex = lerp(0.0, 150.0, k)
    thigh = unit(rotate(-Y, Z, lerp(0.0, -6.0, k)))
    shin = rotate(thigh, Z, -flex)
    body.leg_dirs(1, thigh, shin)
    body.foot_relaxed(1, plantar=lerp(0.0, 40.0, k))
    sh = body.shoulder[1]
    hang = sh + vec(0.02, -0.59, 0.06)
    ankle = body.ankle[1] + X * 0.0 + Y * 0.0
    # The hand waits by the side, then reaches back for the ankle once the heel has come up.
    grab = smooth(min(1.0, max(0.0, (k - 0.45) / 0.55)))
    d = lerp(hang, ankle + vec(-0.03, 0.03, 0.06), grab) - sh
    body.arm(1, sh + unit(d) * min(float(np.linalg.norm(d)), 0.6), unit(-X * 0.2 + Z * 0.5 - Y * 0.5))
    body.arm(-1, vec(wall_x - 0.02, 1.3, -0.22), unit(-Y - X * 0.2 - Z * 0.4))
    show(s, body)


@demo("hip-flexor-stretch", views=[PROFILE(), THREE_QUARTER(35, 14)], labels=STRETCH, timing=(0.8, 1.4, 3.0, 1.2),
      muscles=(["quads"], ["glutes"]))
def hip_flexor_stretch(p, s):
    floor(s, -1.0, 1.0)
    mat(s, -0.75, -0.0)
    k = smooth(p)
    # The hips glide forward and down: the front shin leans forward, the rear hip opens.
    body = half_kneeling(0.5, lerp(0.0, 20.0, k), -0.05, lean=lerp(3.0, -6.0, k))
    hands_on_hips(body)
    show(s, body)


@demo("calf-stretch", views=[PROFILE(), THREE_QUARTER(35, 12)], labels=STRETCH, timing=(0.8, 1.2, 3.0, 1.0),
      muscles=(["calves"], []))
def calf_stretch(p, s):
    wall_x = 0.62
    floor(s, -1.0, wall_x)
    wall(s, wall_x)
    k = smooth(p)
    lean = lerp(8.0, 22.0, k)
    body = upright(lerp(0.855, 0.825, k), lean, pelvis_x=lerp(-0.02, 0.06, k), head=-4)
    body.foot_on_floor(1, (0.25, 0.12), 0.0, pole=X)
    body.foot_on_floor(-1, (-0.42, -0.12), 0.0, pole=X)     # rear leg straight, heel down
    for side in (1, -1):
        body.arm(side, vec(wall_x - 0.02, 1.38, side * 0.22), unit(-Y - X * 0.4 + Z * side * 0.3))
    show(s, body)


@demo("chest-stretch", views=[ABOVE(90, 65), THREE_QUARTER(-40, 14)], labels=STRETCH, timing=(0.8, 1.2, 3.0, 1.0),
      muscles=(["chest"], ["shoulders"]))
def chest_stretch(p, s):
    floor(s, -0.9, 0.9, -0.9, 0.9)
    # A door frame on the right side; the right forearm against it, the body turning away.
    post = vec(0.02, 0.0, 0.55)
    s.box(post + Y * 1.05 + X * 0.0, X * 0.05, Y * 1.05, Z * 0.06, "frame", stroke=0.01, solid="le cadre")
    k = smooth(p)
    body = upright(0.945, 3.0, pelvis_x=lerp(-0.05, 0.12, k), twist=lerp(0.0, 22.0, k), head=0)
    body.foot_on_floor(1, (lerp(0.0, 0.18, k), 0.13), 0.0, pole=X)
    body.foot_on_floor(-1, (lerp(0.0, 0.25, k) - 0.05, -0.13), 0.0, pole=X)
    elbow = vec(post[0] + 0.0, body.shoulder[1][1], post[2] - 0.08)
    hand = elbow + Y * 0.3
    body.arm(1, hand, unit(elbow - body.shoulder[1]))
    body.arm(-1, body.shoulder[-1] + vec(0.02, -0.6, -0.05), unit(-X))
    s.allow = {"le cadre"}
    show(s, body)


@demo("triceps-stretch", views=[PROFILE(), THREE_QUARTER(-40, 12)], labels=STRETCH, timing=(0.8, 1.2, 3.0, 1.0),
      muscles=(["triceps"], ["shoulders"]))
def triceps_stretch(p, s):
    floor(s, -0.7, 0.7, -0.7, 0.7)
    k = smooth(p)
    body = upright(0.945, 0.0, pelvis_x=0.0, head=lerp(0.0, 6.0, k))
    stance(body, 0.0, half_width=0.14)
    # The right arm rises in front up overhead, then the elbow bends and the hand drops behind the
    # head; the left hand gently pushes the right elbow back.
    a = math.radians(lerp(-86.0, 98.0, smooth(min(1.0, k * 1.4))))
    upper = unit(X * math.cos(a) + Y * math.sin(a) + body.chest.r * 0.08)
    flex = lerp(4.0, 150.0, smooth(max(0.0, (k - 0.45) / 0.55)))
    body.arm_dirs(1, upper, rotate(upper, body.chest.r, flex))
    elbow = body.elbow[1]
    hang_l = body.shoulder[-1] + vec(0.02, -0.6, -0.05)
    grab = smooth(max(0.0, (k - 0.55) / 0.45))
    target = lerp(hang_l, elbow + X * 0.04 - body.chest.r * 0.03, grab)
    d = target - body.shoulder[-1]
    target = body.shoulder[-1] + unit(d) * min(float(np.linalg.norm(d)), 0.62)
    body.arm(-1, target, unit(-Y + X * 0.6 - Z * 0.2))
    show(s, body)


@demo("shoulder-stretch", views=[View("Dessus", 70, 72), THREE_QUARTER(55, 30)], labels=STRETCH, timing=(0.8, 1.2, 3.0, 1.0),
      muscles=(["shoulders"], []))
def shoulder_stretch(p, s):
    floor(s, -0.7, 0.7, -0.7, 0.7)
    k = smooth(p)
    body = upright(0.945, 0.0, pelvis_x=0.0, head=0)
    stance(body, 0.0, half_width=0.14)
    sh = body.shoulder[1]
    hang = sh + vec(0.02, -0.62, 0.05)
    across = sh + unit(vec(0.6, -0.03, -1.0)) * 0.62      # across in front of the chest, not through it
    grip = lerp(hang, across, k)
    body.arm(1, grip, unit(-Y + X * 0.3))
    elbow_r = body.elbow[1]
    upper_mid = lerp(sh, elbow_r, 0.85) + X * 0.04
    hang_l = body.shoulder[-1] + vec(0.02, -0.62, -0.05)
    body.arm(-1, lerp(hang_l, upper_mid, k), unit(-Y - Z * 0.3))
    show(s, body)


@demo("childs-pose", views=[PROFILE(), THREE_QUARTER(35, 16)], labels=STRETCH, timing=(0.8, 1.6, 3.0, 1.4),
      muscles=(["lowerBack"], ["back", "shoulders"]))
def childs_pose(p, s):
    floor(s, -0.9, 1.2)
    mat(s, -0.75, 1.0)
    k = smooth(p)
    knee = vec(0.0, Body.W_SHIN / 2 + 0.02, 0.0)
    # Hips from above the knees back to the heels; the torso folds down over the thighs.
    thigh_angle = lerp(88.0, 158.0, k)         # angle of the thigh from the floor, measured from +x
    thigh_dir = vec(math.cos(math.radians(thigh_angle)), math.sin(math.radians(thigh_angle)), 0.0)
    hip = knee + thigh_dir * Body.THIGH
    torso_angle = lerp(88.0, 22.0, k)
    u = vec(math.cos(math.radians(torso_angle)), math.sin(math.radians(torso_angle)), 0.0)
    f = vec(u[1], -u[0], 0.0)
    body = Body(Frame(hip, f, u), spine=lerp(0.0, 18.0, k), head=lerp(0.0, 25.0, k))
    for side in (1, -1):
        kn = vec(knee[0], knee[1], side * 0.12)
        body.leg_dirs(side, unit(kn - body.hip[side]), -X)
        body.foot_relaxed(side, plantar=60)
        sh = body.shoulder[side]
        # The hands slide from beside the thighs forward along the floor (always within reach).
        rest = vec(0.0, -0.58, 0.02 * side)
        reach = vec(sh[0] + 0.55, 0.04, side * 0.2) - sh
        d = lerp(rest, reach, k)
        hand = sh + unit(d) * min(float(np.linalg.norm(d)), 0.6)
        hand[1] = max(hand[1], 0.04)
        body.arm(side, hand, unit(Y + Z * side * 0.3))
    s.allow = {"le tapis"}
    show(s, body)


@demo("pigeon", views=[THREE_QUARTER(40, 18), PROFILE()], labels=STRETCH, timing=(0.8, 1.6, 3.0, 1.4),
      muscles=(["glutes"], ["lowerBack"]))
def pigeon(p, s):
    floor(s, -1.3, 1.0, -0.7, 0.7)
    mat(s, -1.2, 0.8)
    k = smooth(p)
    hip_y = Body.W_THIGH / 2 + 0.07
    body = Body(posture(vec(0.0, hip_y + 0.05, 0.0), 0.0, lerp(14.0, 62.0, k)), spine=lerp(0.0, 12.0, k), head=lerp(-8.0, 10.0, k))
    # Front (right) leg folded across in front, the shin on the floor; the left leg straight back.
    body.leg_dirs(1, unit(vec(0.7, -0.15, -0.25)), unit(vec(-0.05, -0.02, -1.0)))
    body.foot_toward(1, body.ankle[1] + unit(vec(0.25, -0.12, -0.95)) * 0.17)      # resting on its outer edge
    # Rear leg long on the mat: the knee and the top of the foot on the floor.
    knee_y = Body.W_THIGH / 2 + 0.006
    drop = (knee_y - body.hip[-1][1]) / Body.THIGH
    body.leg_dirs(-1, unit(vec(-math.sqrt(max(1 - drop * drop, 0.0)), drop, -0.02)), unit(vec(-1.0, -0.015, 0.0)))
    body.foot_toward(-1, body.ankle[-1] + vec(-0.172, -0.012, 0.0))
    for side in (1, -1):
        sh = body.shoulder[side]
        start = vec(0.2, 0.04, side * 0.26)
        end = vec(sh[0] + 0.45, 0.04, side * 0.22)
        body.arm(side, lerp(start, end, k), unit(-X + Z * side * 0.3))
    s.allow = {"le tapis", "cuisse droit", "tibia droit", "tibia gauche", "cuisse gauche"}
    show(s, body)


@demo("cobra", views=[PROFILE(), THREE_QUARTER(35, 16)], labels=STRETCH, timing=(0.8, 1.4, 3.0, 1.2),
      muscles=(["abs"], ["lowerBack"]))
def cobra(p, s):
    floor(s, -1.2, 1.1)
    mat(s, -1.1, 1.0)
    k = smooth(p)
    origin = vec(0.0, Body.W_TORSO / 2 + 0.02, 0.0)
    pelvis = Frame(origin, -Y, X).pitched(lerp(0.0, -10.0, k))
    body = Body(pelvis, spine=lerp(0.0, -36.0, k), head=lerp(-18.0, -12.0, k))
    for side in (1, -1):
        body.leg_dirs(side, -X, -X)
        body.foot_relaxed(side, plantar=75)
        sh = body.shoulder[side]
        hand = vec(0.42, 0.04, side * 0.24)
        body.arm(side, hand, unit(-X + Z * side * 0.1 + Y * 0.3))
    show(s, body)
