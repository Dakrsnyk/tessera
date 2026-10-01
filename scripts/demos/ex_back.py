"""Back: pull-ups, pulldowns, rows, pullovers, face pulls, shrugs."""
import math

import numpy as np

from demos import demo, show
from engine import (ABOVE, BACK, FRONT, PROFILE, THREE_QUARTER, Body, Frame, SIDE_LEFT, SIDE_RIGHT, View, X, Y, Z,
                    lerp, posture, rotate, unit, vec)
from gear import (PAD_T, PAD_W, TUBE, Column, barbell, cable, d_handle, dumbbell, flat_bench, floor, foot_bar,
                  pulley, straight_handle)
from machines import roller, seat_with_back, stack
from poses import (feet_flat, hang_arms, lying_on_back, on_surface, placed, seated_upright, solve, stance, upright)

PULL = ("Bras tendus", "Tirage", "Contraction", "Retour contrôlé")


def shoulder_mid(body):
    return (body.shoulder[1] + body.shoulder[-1]) / 2


# --- Pull-up station ----------------------------------------------------------------------------------

def pull_station(s, bar_y=2.3, half=0.62, post_x=-0.42):
    """A free-standing station: posts behind the person, arms forward to the bar."""
    s.segs(vec(0.0, bar_y, -half), vec(0.0, bar_y, half), 0.032, "metal", parts=6)
    for side in (1, -1):
        z = side * (half + 0.04)
        sd = SIDE_RIGHT if side == 1 else SIDE_LEFT
        s.line([vec(post_x, 0.03, z), vec(post_x, bar_y + 0.08, z), vec(0.0, bar_y + 0.08, z), vec(0.0, bar_y, z)], TUBE * 1.2,
               "frame", side=sd)
        s.line([vec(post_x - 0.35, 0.025, z), vec(post_x + 0.45, 0.025, z)], TUBE, "frame", side=sd)
    s.line([vec(post_x, bar_y + 0.08, -half), vec(post_x, bar_y + 0.08, half)], TUBE, "frame")
    s.line([vec(post_x, 0.4, -half), vec(post_x, 0.4, half)], TUBE, "frame")


def hanging_body(shoulder_target, lean=-6.0, knees=40.0, **args):
    """Hanging from a bar: the body (slightly leaning back), knees bent and crossed behind."""
    frame = posture(vec(0, 0, 0), 0.0, lean)
    body = placed(frame, "shoulders", shoulder_target, **args)
    for s in (1, -1):
        thigh = rotate(-Y, Z, 10 + lean * 0.5)
        shin = rotate(thigh, Z, -knees)
        body.leg_dirs(s, thigh, shin)
        body.foot_relaxed(s, plantar=30)
    return body


def pull_up_like(p, s, grip_half, poles, bar_y=2.3, lean_top=-14.0, chin=True):
    pull_station(s, bar_y)
    top = vec(-0.04, bar_y - math.sqrt(0.628 ** 2 - max(0.0, grip_half - Body.SH_HALF) ** 2 - 0.04 ** 2), 0.0)
    # At the top the chin passes the bar: shoulders about 18 cm under it, a little behind.
    high = vec(-0.12, bar_y - 0.2, 0.0)
    sh = lerp(top, high, p)
    body = hanging_body(sh, lean=lerp(-4.0, lean_top, p), knees=lerp(35.0, 50.0, p), head=lerp(0.0, -12.0, p))
    for side in (1, -1):
        grip = vec(0.0, bar_y, side * grip_half)
        body.arm(side, grip, poles(body, side))
    s.ground = True
    return body


@demo("pull-up", views=[THREE_QUARTER(-40, 10), PROFILE(4)],
      labels=("Suspendu, bras tendus", "Tirage, coudes vers le bas", "Menton au-dessus de la barre", "Descente contrôlée"),
      timing=(0.7, 1.4, 0.5, 1.7))
def pull_up(p, s):
    floor(s, -0.9, 0.7, -0.8, 0.8)
    body = pull_up_like(p, s, 0.42, lambda b, side: unit(-Y * 0.6 + b.chest.r * side * 1.0 - X * 0.15))
    show(s, body)


@demo("chin-up", views=[PROFILE(4), THREE_QUARTER(40, 10)],
      labels=("Suspendu, paumes vers toi", "Tirage, coudes vers l'avant", "Menton au-dessus de la barre", "Descente contrôlée"),
      timing=(0.7, 1.4, 0.5, 1.7))
def chin_up(p, s):
    floor(s, -0.9, 0.7, -0.8, 0.8)
    body = pull_up_like(p, s, 0.2, lambda b, side: unit(-Y * 0.4 + X * 1.0 + b.chest.r * side * 0.25), lean_top=-10.0)
    show(s, body)


@demo("dead-hang", views=[THREE_QUARTER(-35, 8), PROFILE(4)],
      labels=("Saisis la barre", "Épaules engagées", "Suspension tenue", "Relâche doucement"), timing=(0.8, 0.8, 2.6, 0.8))
def dead_hang(p, s):
    floor(s, -0.9, 0.7, -0.8, 0.8)
    pull_station(s, 2.3)
    sh = vec(-0.04, 2.3 - 0.03 - 0.6 + 0.035 * p, 0.0)
    body = hanging_body(sh, lean=-3.0, knees=20.0, shrug=0.035 * (1 - p))
    for side in (1, -1):
        body.arm(side, vec(0.0, 2.3, side * 0.32), unit(-X * 0.3 + body.chest.r * side))
    show(s, body)


# --- Assisted pull-up machine -------------------------------------------------------------------------------

@demo("assisted-pull-up", views=[PROFILE(4), THREE_QUARTER(-35, 10)],
      labels=("À genoux sur le plateau, bras tendus", "Tirage aidé", "Menton au niveau des poignées", "Descente contrôlée"),
      timing=(0.7, 1.4, 0.5, 1.7))
def assisted_pull_up(p, s):
    floor(s, -1.0, 0.75, -0.8, 0.8)
    handle_y = 2.15
    grip_half = 0.4
    # Kneeling on a pad that rises with the person (the counterweight pushes it up).
    top = vec(-0.04, handle_y - math.sqrt(0.628 ** 2 - (grip_half - Body.SH_HALF) ** 2 - 0.04 ** 2), 0.0)
    high = vec(-0.11, handle_y - 0.18, 0.0)
    sh = lerp(top, high, p)
    frame = posture(vec(0, 0, 0), 0.0, -5.0)
    body = placed(frame, "shoulders", sh, head=lerp(0.0, -10.0, p))
    for side in (1, -1):
        thigh = rotate(-Y, Z, 3)
        shin = rotate(thigh, Z, -88)
        body.leg_dirs(side, thigh, shin)
        body.foot_relaxed(side, plantar=88)     # top of the foot along the pad
        body.arm(side, vec(0.0, handle_y, side * grip_half), unit(-Y * 0.6 + body.chest.r * side - X * 0.15))
    knee = body.knee[1]
    pad_top = knee[1] - Body.W_SHIN / 2 - 0.005
    s.slab(vec(knee[0] - 0.12, pad_top, 0.0), vec(knee[0] - 0.55, pad_top, 0.0), Y, 0.4, 0.06, "pad", solid="le plateau")
    # Frame: tall posts behind with the handles forward, the pad on a lever to the counterweight.
    post_x = -0.75
    for side in (1, -1):
        sd = SIDE_RIGHT if side == 1 else SIDE_LEFT
        z = side * 0.3
        s.line([vec(post_x, 0.03, z), vec(post_x, handle_y + 0.15, z)], TUBE * 1.3, "frame", side=sd)
        s.line([vec(post_x, handle_y + 0.12, z), vec(0.02, handle_y + 0.12, side * grip_half), vec(0.02, handle_y, side * grip_half)],
               TUBE * 1.1, "frame", side=sd)
        s.line([vec(0.0, handle_y, side * (grip_half - 0.07)), vec(0.0, handle_y, side * (grip_half + 0.07))], 0.04, "load", side=sd)
        s.line([vec(post_x - 0.3, 0.025, z), vec(0.5, 0.025, z)], TUBE, "frame", side=sd)
    pivot = vec(post_x + 0.05, 0.55, 0.0)
    s.line([pivot, vec(knee[0] - 0.33, pad_top - 0.06, 0.0)], TUBE * 1.2, "frame")
    s.disc(pivot, Z, 0.05, "frame")
    stack(s, post_x - 0.22, 0.0, lift=(1 - p) * 0.12, height=handle_y)
    s.allow = {("tibia droit", "le plateau"), ("tibia gauche", "le plateau")}
    show(s, body)


# --- Lat pulldown -----------------------------------------------------------------------------------------

def pulldown_machine(s, seat_y, hip_x, thigh_top, lift):
    """Seat, thigh rollers, the column in front with its high pulley and the stack."""
    s.slab(vec(hip_x - 0.2, seat_y, 0), vec(hip_x + 0.2, seat_y, 0), Y, 0.38, PAD_T, "pad", solid="le siège")
    s.line([vec(hip_x, seat_y - PAD_T, 0), vec(hip_x, 0.03, 0)], TUBE * 1.3, "frame")
    roll = vec(hip_x + 0.3, thigh_top + 0.05, 0.0)
    s.line([roll - Z * 0.22, roll + Z * 0.22], 0.1, "pad")
    col_x = hip_x + 0.78
    s.line([vec(hip_x + 0.3, thigh_top + 0.05, 0), vec(col_x, thigh_top + 0.05, 0)], TUBE, "frame")
    s.line([vec(hip_x - 0.45, 0.025, 0), vec(col_x + 0.25, 0.025, 0)], TUBE, "frame")
    foot_bar(s, hip_x - 0.4, half=0.3)
    foot_bar(s, col_x + 0.2, half=0.3)
    stack(s, col_x, 0.0, lift=lift, height=2.35)
    s.line([vec(col_x, 2.35, 0), vec(hip_x + 0.08, 2.35, 0)], TUBE * 1.2, "frame")
    return col_x


def lat_bar(s, center, half=0.6):
    """The long pulldown bar, its ends bent down."""
    pts = [center + Z * half + vec(0.0, -0.07, 0.0), center + Z * (half - 0.12), center - Z * (half - 0.12),
           center - Z * half + vec(0.0, -0.07, 0.0)]
    for a, b in zip(pts[:-1], pts[1:]):
        s.line([a, b], 0.03, "metal")


@demo("lat-pulldown", views=[PROFILE(4), THREE_QUARTER(-40, 12)],
      labels=("Bras tendus, prise large", "Tirage, coudes vers le bas", "Barre en haut de la poitrine", "Remontée contrôlée"),
      timing=(0.7, 1.3, 0.5, 1.7))
def lat_pulldown(p, s):
    floor(s, -0.75, 1.3, -0.8, 0.8)
    seat_y, hip_x = 0.48, 0.0
    lean = lerp(-10.0, -18.0, p)
    body = seated_upright(seat_y, hip_x, lean=lean, head=lerp(-4.0, -12.0, p))
    feet_flat(body, (0.5, 0.17), (0.5, -0.17))
    thigh_top = body.hip[1][1] + Body.W_THIGH / 2
    sh = shoulder_mid(body)
    grip_half = 0.45
    top = vec(sh[0] + 0.12, sh[1] + math.sqrt(0.632 ** 2 - (grip_half - Body.SH_HALF) ** 2 - 0.12 ** 2), 0.0)
    low = body.chest.at(u=0.36, f=Body.W_TORSO / 2 + 0.03)
    low[2] = 0.0
    bar = lerp(top, low, p)
    for side in (1, -1):
        body.arm(side, bar + Z * side * (grip_half - 0.04), unit(-Y * 0.5 + body.chest.r * side - X * 0.4))
    col_x = pulldown_machine(s, seat_y, hip_x, thigh_top, lift=p * 0.5)
    pul = vec(hip_x + 0.08, 2.3, 0.0)
    s.disc(pul, Z, 0.05, "frame")
    cable(s, pul, bar)
    lat_bar(s, bar)
    show(s, body)


@demo("close-pulldown", views=[PROFILE(4), THREE_QUARTER(-40, 12)],
      labels=("Bras tendus, poignée serrée", "Tirage, coudes le long du corps", "Poignée sur la poitrine", "Remontée contrôlée"),
      timing=(0.7, 1.3, 0.5, 1.7))
def close_pulldown(p, s):
    floor(s, -0.75, 1.3, -0.8, 0.8)
    seat_y, hip_x = 0.48, 0.0
    body = seated_upright(seat_y, hip_x, lean=lerp(-10.0, -20.0, p), head=lerp(-4.0, -12.0, p))
    feet_flat(body, (0.5, 0.17), (0.5, -0.17))
    thigh_top = body.hip[1][1] + Body.W_THIGH / 2
    sh = shoulder_mid(body)
    top = vec(sh[0] + 0.14, sh[1] + math.sqrt(0.632 ** 2 - Body.SH_HALF ** 2 * 0.6 - 0.14 ** 2), 0.0)
    low = body.chest.at(u=0.3, f=Body.W_TORSO / 2 + 0.05)
    low[2] = 0.0
    grip = lerp(top, low, p)
    for side in (1, -1):
        body.arm(side, grip + Z * side * 0.07, unit(-Y + X * 0.1 + body.chest.r * side * 0.35))
    pulldown_machine(s, seat_y, hip_x, thigh_top, lift=p * 0.5)
    pul = vec(hip_x + 0.08, 2.3, 0.0)
    s.disc(pul, Z, 0.05, "frame")
    top_handle = grip + Y * 0.12
    cable(s, pul, top_handle)
    s.line([top_handle, grip + Z * 0.07, grip - Z * 0.07, top_handle], 0.025, "metal")
    show(s, body)


# --- Rows ---------------------------------------------------------------------------------------------

def bent_over(p_lean, hip_y, feet_x=0.0, half=0.15, bar_over=0.0, head=-18.0, **args):
    """Hinged forward with flat back, knees bent, shoulders over the middle of the feet."""
    body = upright(hip_y, p_lean, shoulder_x=feet_x + 0.06 + bar_over, head=head, **args)
    stance(body, feet_x - 0.04, half_width=half, toe_out=6)
    return body


@demo("barbell-row", views=[PROFILE(), THREE_QUARTER(35, 12)],
      labels=("Buste penché, bras tendus", "Tirage vers le nombril", "Barre contre le ventre", "Descente contrôlée"),
      timing=(0.7, 1.1, 0.5, 1.6))
def barbell_row(p, s):
    floor(s, -1.0, 1.0)
    body = bent_over(48.0, 0.84)
    sh = shoulder_mid(body)
    hang = vec(sh[0] + 0.02, sh[1] - 0.62, 0.0)
    belly = body.chest.at(u=0.06, f=Body.W_TORSO / 2 + 0.03)
    belly[2] = 0.0
    bar = lerp(hang, belly, p)
    for side in (1, -1):
        body.arm(side, bar + Z * side * 0.27, unit(-X * 1.0 + Y * 0.6 + body.chest.r * side * 0.35))
    barbell(s, bar, Z)
    show(s, body)


@demo("t-bar-row", views=[PROFILE(), THREE_QUARTER(35, 12)],
      labels=("Buste penché, bras tendus", "Tirage vers la poitrine", "Poignée contre le buste", "Descente contrôlée"),
      timing=(0.7, 1.1, 0.5, 1.6))
def t_bar_row(p, s):
    floor(s, -1.9, 1.0)
    body = bent_over(45.0, 0.85, half=0.22)
    sh = shoulder_mid(body)
    anchor = vec(-1.75, 0.06, 0.0)
    # The bar turns around its anchor on the floor: the handle under the plates follows that arc.
    hang = vec(sh[0] + 0.03, sh[1] - 0.6, 0.0)
    radius = np.linalg.norm(hang - anchor)
    chest = body.chest.at(u=0.12, f=Body.W_TORSO / 2 + 0.03)
    a0 = math.atan2(hang[1] - anchor[1], hang[0] - anchor[0])
    a1 = math.atan2(chest[1] - anchor[1], chest[0] - anchor[0])
    a = lerp(a0, a1, p)
    handle = anchor + vec(math.cos(a), math.sin(a), 0.0) * radius
    direction = unit(handle - anchor)
    bar_end = anchor + direction * (radius + 0.25)
    s.segs(anchor, bar_end, 0.035, "metal", parts=6)
    s.disc(anchor, Y, 0.06, "frame")
    s.disc(anchor + direction * (radius + 0.12), direction, 0.225, "load")
    s.line([handle, handle + Z * 0.08], 0.03, "metal")
    s.line([handle, handle - Z * 0.08], 0.03, "metal")
    s.line([handle + direction * 0.02, handle + rotate(direction, Z, 90) * 0.04], 0.03, "metal")
    for side in (1, -1):
        body.arm(side, handle + Z * side * 0.07, unit(-X + Y * 0.5 + body.chest.r * side * 0.4))
    show(s, body)


@demo("db-row", views=[PROFILE(), THREE_QUARTER(30, 18)],
      labels=("Bras tendu, dos plat", "Tirage du coude vers le haut", "Haltère contre la hanche", "Descente contrôlée"),
      timing=(0.7, 1.1, 0.5, 1.6))
def db_row(p, s):
    floor(s, -0.9, 1.4, -0.6, 0.8)
    top = 0.43
    flat_bench(s, -0.35, 0.95, top, z=-0.05)
    # Left knee and left hand on the bench, right foot on the floor, back flat (horizontal).
    knee_y = top + Body.W_SHIN / 2 + 0.004
    hip_y = knee_y + Body.THIGH
    body = upright(hip_y - 0.03, 82.0, pelvis_x=0.02, z=0.0, head=-25)
    body.leg(-1, vec(0.02 - 0.0, knee_y, -0.09), pole=X)
    left_knee = vec(0.04, knee_y, -0.09)
    body.leg_dirs(-1, unit(left_knee - body.hip[-1]), -X)
    body.foot_relaxed(-1, plantar=45)
    body.foot_on_floor(1, (-0.12, 0.36), -10.0, pole=unit(X + Z * 0.3))
    sh = body.shoulder[-1]
    body.arm(-1, vec(sh[0] + 0.03, top + 0.025, -0.1), unit(-X * 0.2 + Z * -0.4 + Y * 0.0 - X))
    shr = body.shoulder[1]
    hang = vec(shr[0] + 0.04, shr[1] - 0.62, 0.3)
    hip = body.chest.at(u=-0.05, f=Body.W_TORSO / 2 + 0.06, r=0.2)
    grip = lerp(hang, hip, p)
    body.arm(1, grip, unit(Y * 1.0 - X * 0.5 + Z * 0.2))
    dumbbell(s, grip, X, side=SIDE_RIGHT)
    s.allow = {("tibia gauche", "le banc"), ("avant-bras gauche", "le banc"), ("cuisse gauche", "le banc")}
    show(s, body)


@demo("inverted-row", views=[PROFILE(4), THREE_QUARTER(30, 14)],
      labels=("Sous la barre, bras tendus", "Tirage, corps gainé", "Poitrine contre la barre", "Descente contrôlée"),
      timing=(0.7, 1.2, 0.5, 1.6))
def inverted_row(p, s):
    floor(s, -1.2, 1.2, -0.8, 0.8)
    bar_y = 1.0
    # Body straight from the heels (on the floor) to the head, turning around the heels.
    heel = vec(-1.05, 0.03, 0.0)

    def make(theta):
        u = vec(math.cos(math.radians(theta)), math.sin(math.radians(theta)), 0.0)
        frame = Frame(vec(0, 0, 0), vec(-u[1], u[0], 0.0), u)
        ankle = heel + Y * 0.06
        pelvis = ankle + frame.u * (Body.SHIN + Body.THIGH)
        b = Body(Frame(pelvis, frame.f, frame.u), head=-6)
        for side in (1, -1):
            b.leg_dirs(side, -frame.u, -frame.u)
            b.foot_toward(side, b.ankle[side] + frame.f * 0.16 + frame.u * 0.05)
        return b

    def gap(theta):
        b = make(theta)
        return shoulder_mid(b)[1]

    t_low = solve(gap, 5.0, 60.0, bar_y - 0.6)
    t_high = solve(gap, 5.0, 60.0, bar_y - 0.12)
    body = make(lerp(t_low, t_high, p))
    bar_x = shoulder_mid(make(t_low))[0] + 0.02
    for side in (1, -1):
        body.arm(side, vec(bar_x, bar_y, 0.0) + body.chest.r * side * 0.3, unit(-body.chest.u * 0.5 + body.chest.r * side * 0.8 - Y * 0.6))
    s.segs(vec(bar_x, bar_y, -0.7), vec(bar_x, bar_y, 0.7), 0.032, "metal", parts=6)
    for side in (1, -1):
        sd = SIDE_RIGHT if side == 1 else SIDE_LEFT
        s.line([vec(bar_x + 0.55, 0.03, side * 0.72), vec(bar_x + 0.55, bar_y + 0.4, side * 0.72)], TUBE * 1.2, "frame", side=sd)
        s.line([vec(bar_x + 0.55, bar_y, side * 0.72), vec(bar_x, bar_y, side * 0.72)], TUBE, "frame", side=sd)
        s.line([vec(bar_x + 0.3, 0.025, side * 0.72), vec(bar_x + 0.8, 0.025, side * 0.72)], TUBE, "frame", side=sd)
    show(s, body)


def low_row_station(s, seat_y, seat_x0, seat_x1, plate_x, pulley_y, lift):
    s.slab(vec(seat_x0, seat_y, 0), vec(seat_x1, seat_y, 0), Y, 0.3, PAD_T, "pad", solid="le banc")
    s.line([vec(seat_x0 + 0.1, seat_y - PAD_T, 0), vec(seat_x0 + 0.1, 0.03, 0)], TUBE, "frame")
    s.line([vec(seat_x0 - 0.05, 0.03, 0), vec(plate_x + 0.45, 0.03, 0)], TUBE, "frame")
    foot_bar(s, seat_x0 + 0.1, half=0.3)
    # Foot plate, angled.
    s.slab(vec(plate_x, 0.12, 0), vec(plate_x + 0.08, 0.5, 0), rotate(-X, Z, -12), 0.42, 0.04, "frame", solid="le repose-pieds")
    col_x = plate_x + 0.35
    stack(s, col_x, 0.0, lift=lift, height=1.8)
    pul = vec(plate_x + 0.12, pulley_y, 0.0)
    s.disc(pul, Z, 0.05, "frame")
    s.line([pul, vec(col_x, pulley_y, 0)], TUBE, "frame")
    return pul


@demo("seated-cable-row", views=[PROFILE(), THREE_QUARTER(35, 14)],
      labels=("Bras tendus, dos droit", "Tirage vers le ventre", "Omoplates serrées", "Retour contrôlé"),
      timing=(0.7, 1.2, 0.6, 1.7))
def seated_cable_row(p, s):
    floor(s, -0.8, 1.5)
    seat_y = 0.42
    body = seated_upright(seat_y, 0.0, lean=lerp(8.0, -4.0, p), head=lerp(4.0, 0.0, p))
    plate_x = 0.92
    for side in (1, -1):
        ankle = vec(plate_x - 0.09, 0.34, side * 0.13)
        body.leg(side, ankle, pole=Y)
        body.foot_toward(side, ankle + unit(Y * 0.9 + X * 0.25) * 0.17)
    sh = shoulder_mid(body)
    far = vec(sh[0] + 0.6, sh[1] - 0.12, 0.0)
    belly = body.chest.at(u=0.08, f=Body.W_TORSO / 2 + 0.05)
    belly[2] = 0.0
    grip = lerp(far, belly, p)
    for side in (1, -1):
        body.arm(side, grip + Z * side * 0.06, unit(-X + body.chest.r * side * 0.3 - Y * 0.2))
    pul = low_row_station(s, seat_y, -0.45, 0.42, plate_x, 0.32, lift=p * 0.45)
    cable(s, pul, grip + X * 0.1)
    s.line([grip + X * 0.1, grip + Z * 0.06, grip - Z * 0.06, grip + X * 0.1], 0.025, "metal")
    show(s, body)


@demo("machine-row", views=[PROFILE(), THREE_QUARTER(35, 14)],
      labels=("Bras tendus, poitrine contre l'appui", "Tirage, coudes vers l'arrière", "Omoplates serrées", "Retour contrôlé"),
      timing=(0.7, 1.2, 0.6, 1.7))
def machine_row(p, s):
    floor(s, -0.9, 1.3)
    seat_y = 0.5
    s.slab(vec(-0.2, seat_y, 0), vec(0.2, seat_y, 0), Y, 0.36, PAD_T, "pad", solid="le siège")
    s.line([vec(0.0, seat_y - PAD_T, 0), vec(0.0, 0.03, 0)], TUBE * 1.3, "frame")
    body = seated_upright(seat_y, -0.02, lean=6.0, head=2)
    feet_flat(body, (0.48, 0.18), (0.48, -0.18))
    # Chest pad in front of the sternum.
    c = body.chest
    pad_pt = c.at(u=0.25, f=Body.W_TORSO / 2 + 0.004)
    s.slab(pad_pt - c.u * 0.2, pad_pt + c.u * 0.2, -c.f, 0.36, 0.08, "pad", solid="l'appui")
    s.line([pad_pt + c.f * 0.08, vec(pad_pt[0] + 0.25, 0.03, 0)], TUBE * 1.2, "frame")
    sh = shoulder_mid(body)
    # Levers hang from a pivot high in front; the handles come back in a flat arc.
    pivot = vec(sh[0] + 0.38, sh[1] + 0.92, 0.0)
    far = vec(sh[0] + 0.58, sh[1] - 0.08, 0.0)
    radius = np.linalg.norm(far - pivot)
    a0 = math.atan2(far[1] - pivot[1], far[0] - pivot[0])
    near_x = sh[0] + 0.12
    a1 = -math.acos((near_x - pivot[0]) / radius)
    a = lerp(a0, a1, p)
    handle = pivot + vec(math.cos(a), math.sin(a), 0.0) * radius
    for side in (1, -1):
        sd = SIDE_RIGHT if side == 1 else SIDE_LEFT
        grip = handle + Z * side * 0.24
        body.arm(side, grip, unit(-X + Y * 0.2 + body.chest.r * side * 0.5))
        pz = vec(pivot[0], pivot[1], side * 0.3)
        s.line([pz, vec(grip[0], grip[1], side * 0.3)], TUBE * 1.2, "frame", side=sd)
        s.line([grip + Y * 0.08, grip - Y * 0.08], 0.04, "load", side=sd)
        s.line([vec(grip[0], grip[1], side * 0.3), grip], TUBE, "frame", side=sd)
        s.disc(pz, Z, 0.05, "frame", side=sd)
    post_x = pivot[0] + 0.35
    s.line([vec(post_x, 0.03, 0), vec(post_x, pivot[1], 0), vec(pivot[0], pivot[1], 0)], TUBE * 1.3, "frame")
    s.line([vec(pad_pt[0] + 0.25, 0.03, 0), vec(post_x, 0.03, 0)], TUBE, "frame")
    s.line([vec(pivot[0], pivot[1], -0.3), vec(pivot[0], pivot[1], 0.3)], TUBE, "frame")
    s.line([vec(-0.3, 0.03, 0), vec(0.3, 0.03, 0)], TUBE, "frame")
    stack(s, post_x + 0.3, 0.0, lift=p * 0.13, height=pivot[1])
    show(s, body)


# --- Pullovers ---------------------------------------------------------------------------------------

@demo("straight-arm-pulldown", views=[PROFILE(), THREE_QUARTER(35, 12)],
      labels=("Bras tendus, barre à hauteur des yeux", "Descente en arc", "Barre contre les cuisses", "Remontée contrôlée"),
      timing=(0.7, 1.3, 0.5, 1.6))
def straight_arm_pulldown(p, s):
    floor(s, -0.7, 1.4)
    body = upright(0.9, 22.0, shoulder_x=0.12, head=-10)
    stance(body, 0.0, half_width=0.14)
    sh = shoulder_mid(body)
    # Arms almost straight, turning around the shoulders.
    angle = lerp(38.0, -78.0, p)   # above horizontal at the start, down to the thighs
    d = vec(math.cos(math.radians(angle)), math.sin(math.radians(angle)), 0.0)
    bar = sh + d * 0.62
    for side in (1, -1):
        body.arm(side, bar + Z * side * 0.22, unit(-Y * 0.3 - X * 0.1 + body.chest.r * side))
    col = Column(s, 1.15, 0.0, height=2.25)
    top = vec(1.0, 2.1, 0.0)
    g0 = sh + vec(math.cos(math.radians(38)), math.sin(math.radians(38)), 0) * 0.62
    col.frame(lift=np.linalg.norm(bar - top) - np.linalg.norm(g0 - top))
    s.disc(top, Z, 0.05, "frame")
    cable(s, top, bar)
    straight_handle(s, bar, Z, half=0.3)
    show(s, body)


@demo("db-pullover", views=[PROFILE(), THREE_QUARTER(30, 16)],
      labels=("Haltère au-dessus de la poitrine", "Descente derrière la tête", "Étirement", "Retour en arc"),
      timing=(0.7, 1.7, 0.4, 1.4))
def db_pullover(p, s):
    floor(s, -1.25, 0.95)
    top = 0.43
    # Upper back across the bench, hips level with it, feet on the floor.
    from ex_chest import bench_across
    bench_across(s, -0.42, top)
    body = on_surface(vec(0.0, top, 0.0), -X, Y, head=8)
    for side in (1, -1):
        ankle = vec(0.47, 0.08, side * 0.2)
        body.leg(side, ankle, pole=Y)
        body.foot_toward(side, ankle + X * 0.17 - Y * 0.06)
    sh = shoulder_mid(body)
    angle = lerp(90.0, 192.0, p)   # straight up, then back past the head
    d = vec(math.cos(math.radians(angle)), math.sin(math.radians(angle)), 0.0)
    grip = sh + d * 0.6
    for side in (1, -1):
        body.arm(side, grip + Z * side * 0.05, unit(X * 0.6 + Y * 0.2 + body.chest.r * side * 0.8))
    # One dumbbell held by the inner plate with both hands, upright.
    axis = unit(rotate(d, Z, 90))
    s.line([grip - d * 0.0 - axis * 0.06, grip + d * 0.16], 0.028, "metal")
    s.line([grip + d * 0.1, grip + d * 0.18], 0.17, "load")
    s.line([grip - d * 0.14, grip - d * 0.08], 0.14, "load")
    s.line([grip - d * 0.14, grip + d * 0.1], 0.028, "metal")
    s.allow = {"le banc"}
    show(s, body)


# --- Face pull, pull-apart ---------------------------------------------------------------------------------

@demo("face-pull", views=[THREE_QUARTER(30, 12), PROFILE()],
      labels=("Bras tendus vers la poulie", "Tirage vers le visage", "Coudes hauts, mains aux oreilles", "Retour contrôlé"),
      timing=(0.7, 1.2, 0.6, 1.6))
def face_pull(p, s):
    floor(s, -0.7, 1.5)
    body = upright(0.94, -4.0, pelvis_x=0.0, head=-4)
    stance(body, 0.02, half_width=0.15)
    sh = shoulder_mid(body)
    pul = vec(1.12, sh[1] + 0.12, 0.0)
    far = vec(sh[0] + 0.6, sh[1] + 0.08, 0.0)
    for side in (1, -1):
        start = far + Z * side * 0.05
        end = body.head + X * 0.05 + Z * side * 0.22 - Y * 0.02
        grip = lerp(start, end, p)
        body.arm(side, grip, unit(Y * 0.2 + body.chest.r * side * 1.0 - X * 0.3))
        cable(s, pul, grip)
        s.ball(grip, 0.025, "load", side=SIDE_RIGHT if side == 1 else SIDE_LEFT)
    s0 = far
    lift = np.linalg.norm((body.head + X * 0.05) - pul) * p - 0.0
    col = Column(s, 1.3, 0.0, height=2.2)
    col.frame(lift=p * 0.45)
    s.disc(pul, Y, 0.045, "frame")
    s.line([pul, vec(1.3, pul[1], 0)], TUBE, "frame")
    show(s, body)


@demo("band-pull-apart", views=[View("3/4", 60, 26), ABOVE(90, 72)],
      labels=("Bras tendus devant", "Écarte l'élastique", "Élastique contre la poitrine", "Retour lent"),
      timing=(0.7, 1.1, 0.6, 1.4))
def band_pull_apart(p, s):
    floor(s, -0.6, 0.9, -0.9, 0.9)
    body = upright(0.945, 0.0, head=0)
    stance(body, 0.02, half_width=0.14)
    sh = shoulder_mid(body)
    angle = lerp(14.0, 80.0, p)
    for side in (1, -1):
        d = rotate(X, Y, -side * angle)
        grip = body.shoulder[side] + d * 0.62 - Y * 0.02 + X * 0.07 * p
        body.arm(side, grip, unit(-Y + X * 0.0 - d * 0.2))
    a, b = body.grip[1], body.grip[-1]
    s.line([a, b], 0.022, "load")
    show(s, body)


# --- Shrugs -----------------------------------------------------------------------------------------

@demo("bb-shrug", views=[FRONT(6), PROFILE()],
      labels=("Bras tendus, épaules basses", "Haussement", "Épaules vers les oreilles", "Descente lente"),
      timing=(0.7, 0.9, 0.8, 1.2))
def bb_shrug(p, s):
    floor(s, -0.7, 0.8)
    body = upright(0.94, 3.0, shoulder_x=0.02, shrug=0.08 * p, head=0)
    stance(body, 0.0, half_width=0.15)
    for side in (1, -1):
        sh = body.shoulder[side]
        body.arm(side, vec(sh[0] + 0.1, sh[1] - 0.6, side * 0.24), unit(-X + body.chest.r * side * 0.2))
    bar = vec(body.grip[1][0], body.grip[1][1], 0.0)
    barbell(s, bar, Z, plate_r=0.17)
    show(s, body)


@demo("db-shrug", views=[FRONT(6), PROFILE()],
      labels=("Bras le long du corps", "Haussement", "Épaules vers les oreilles", "Descente lente"),
      timing=(0.7, 0.9, 0.8, 1.2))
def db_shrug(p, s):
    floor(s, -0.7, 0.8, -0.7, 0.7)
    body = upright(0.94, 0.0, shoulder_x=0.0, shrug=0.08 * p, head=0)
    stance(body, 0.0, half_width=0.14)
    for side in (1, -1):
        sh = body.shoulder[side]
        grip = vec(sh[0] + 0.01, sh[1] - 0.62, side * 0.27)
        body.arm(side, grip, unit(-X))
        dumbbell(s, grip, X, side=SIDE_RIGHT if side == 1 else SIDE_LEFT)
    show(s, body)
