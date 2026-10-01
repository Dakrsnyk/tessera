"""Legs: squats, presses, extensions, curls, lunges, hinges, hip thrusts, calves."""
import math

import numpy as np

from demos import demo, show
from engine import (FRONT, PROFILE, THREE_QUARTER, ABOVE, BACK, Body, Frame, X, Y, Z, lerp, rotate, unit, vec,
                    SIDE_LEFT, SIDE_RIGHT, posture)
from engine import View, heading
from gear import PAD_T, PAD_W, TUBE, Column, barbell, bench_rack, cable, d_handle, dumbbell, flat_bench, floor, foot_bar, kettlebell
from machines import roller, seat_with_back, stack
from poses import (feet_flat, hang_arms, lying_on_back, lying_on_front, on_surface, placed, seated_upright, solve,
                   standing, stance, upright)


def shoulder_mid(body):
    return (body.shoulder[1] + body.shoulder[-1]) / 2


def smooth(t):
    t = min(1.0, max(0.0, t))
    return t * t * (3 - 2 * t)


@demo("leg-extension", views=[PROFILE(), THREE_QUARTER(40, 14)],
      labels=("Genoux pliés à 90°", "Extension", "Jambes tendues", "Descente contrôlée"), timing=(0.7, 1.3, 0.8, 1.8))
def leg_extension(p, s):
    floor(s, -0.85, 1.25)
    seat_y = 0.52
    hip_x = 0.0
    seat_front = hip_x + Body.THIGH - 0.06
    junction, back_dir, normal = seat_with_back(s, hip_x - 0.1, seat_front, seat_y, back_angle=14.0, back_len=0.62)
    body = seated_upright(seat_y, hip_x, lean=-14, head=6)
    # Shin turns around the knee, from vertical (90°) to in line with the thigh.
    knee_angle = lerp(92.0, 4.0, p)    # flexion
    lever_lift = (92.0 - knee_angle) / 88.0
    for side in (1, -1):
        thigh = X
        shin = rotate(-Y, Z, 90 - knee_angle)      # 90° flexion: straight down; 0: forward
        body.leg_dirs(side, thigh, shin)
        body.foot_relaxed(side, plantar=-8)
    # Pivot on the knee axis, outside the left knee; the lever runs along the shin to the roller.
    knee = body.knee[1]
    pivot = vec(knee[0], knee[1], -0.27)
    shin_dir = unit(body.ankle[1] - body.knee[1])
    front = rotate(shin_dir, Z, 90)  # in front of the shin
    roll_at = knee + shin_dir * 0.355 + front * (Body.W_SHIN / 2 + 0.05)
    roller(s, vec(roll_at[0], roll_at[1], 0.0), half=0.2, r=0.05)
    lever_end = vec(roll_at[0], roll_at[1], -0.27)
    s.line([pivot, lever_end], TUBE * 1.2, "frame", side=SIDE_LEFT)
    s.line([lever_end, vec(roll_at[0], roll_at[1], -0.2)], TUBE, "frame", side=SIDE_LEFT)
    s.disc(pivot, Z, 0.07, "frame", side=SIDE_LEFT)
    # Frame: base, seat post, the arm holding the pivot, handles beside the seat.
    s.line([vec(-0.7, 0.025, 0), vec(seat_front + 0.25, 0.025, 0)], TUBE, "frame")
    foot_bar(s, -0.62, half=0.32)
    foot_bar(s, seat_front + 0.2, half=0.32)
    s.line([vec(0.1, seat_y - PAD_T, 0), vec(0.1, 0.03, 0)], TUBE * 1.3, "frame")
    s.line([vec(seat_front + 0.18, 0.03, -0.27), vec(seat_front + 0.12, seat_y - 0.1, -0.27), pivot], TUBE * 1.2, "frame", side=SIDE_LEFT)
    for side in (1, -1):
        z = 0.29 * side
        sd = SIDE_RIGHT if side == 1 else SIDE_LEFT
        s.line([vec(-0.02, seat_y - 0.05, z), vec(0.16, seat_y - 0.05, z)], 0.035, "load", side=sd)
        s.line([vec(-0.02, seat_y - 0.05, z), vec(-0.02, seat_y - PAD_T, z * 0.6)], TUBE, "frame", side=sd)
    for side in (1, -1):
        body.arm(side, vec(0.07, seat_y - 0.05, 0.29 * side), unit(-X * 0.6 + Y * 0.0 + Z * side * 0.3))
    stack(s, -0.6, 0.0, lift=lever_lift * 0.13, height=1.45)
    s.allow = {("cuisse droit", "le siège"), ("cuisse gauche", "le siège")}
    show(s, body)


# --- Squats -------------------------------------------------------------------------------------------

SQUAT = ("Debout, gainé", "Descente, hanches en arrière", "Cuisses parallèles au sol", "Remontée")


def squat_body(p, lean_top=4.0, lean_bottom=40.0, hip_bottom=0.5, load_point=None, half=0.17, toe_out=15.0, head=None,
               midfoot=0.0):
    """A squat with the load (or the shoulders) kept over the middle of the feet."""
    k = smooth(p)
    hip_y = lerp(0.948, hip_bottom, p)
    lean = lerp(lean_top, lean_bottom, k)
    hd = head if head is not None else -lean * 0.55

    def at_x(px):
        b = upright(hip_y, lean, pelvis_x=px, head=hd)
        point = load_point(b) if load_point else shoulder_mid(b)
        return point[0]

    px = solve(at_x, -1.0, 1.0, midfoot)
    body = upright(hip_y, lean, pelvis_x=px, head=hd)
    stance(body, midfoot - 0.06, half_width=half, toe_out=toe_out)
    return body


def back_bar(b):
    return b.neck - b.chest.f * 0.075 - b.chest.u * 0.02


@demo("back-squat", views=[PROFILE(), THREE_QUARTER(35, 12)], labels=SQUAT, timing=(0.6, 1.6, 0.4, 1.3))
def back_squat(p, s):
    floor(s, -0.9, 0.9)
    body = squat_body(p, 4.0, 42.0, 0.5, load_point=back_bar)
    bar = back_bar(body)
    bar[2] = 0.0
    for side in (1, -1):
        body.arm(side, bar + Z * side * 0.42, unit(-Y - X * 0.6 + Z * side * 0.2))
    barbell(s, bar, Z)
    show(s, body)


def front_bar(b):
    p = b.chest.at(u=b.THORAX - 0.06, f=b.W_TORSO / 2 + 0.06)
    return p


@demo("front-squat", views=[PROFILE(), THREE_QUARTER(35, 12)],
      labels=("Barre sur l'avant des épaules", "Descente, buste droit", "Cuisses parallèles", "Remontée"), timing=(0.6, 1.6, 0.4, 1.3))
def front_squat(p, s):
    floor(s, -0.9, 0.9)
    body = squat_body(p, 2.0, 22.0, 0.5, load_point=front_bar)
    bar = front_bar(body)
    bar[2] = 0.0
    for side in (1, -1):
        sh = body.shoulder[side]
        grip = bar + Z * side * 0.24 - body.chest.f * 0.0 + Y * 0.0
        body.arm(side, grip, unit(X * 1.0 + Y * 0.3 + Z * side * 0.3))
    barbell(s, bar, Z)
    show(s, body)


def goblet_point(b):
    return b.chest.at(u=0.26, f=b.W_TORSO / 2 + 0.11)


@demo("goblet-squat", views=[THREE_QUARTER(35, 12), PROFILE()],
      labels=("Charge contre la poitrine", "Descente, coudes entre les genoux", "Squat profond", "Remontée"), timing=(0.6, 1.6, 0.4, 1.3))
def goblet_squat(p, s):
    floor(s, -0.9, 0.9, -0.7, 0.7)
    body = squat_body(p, 2.0, 20.0, 0.46, load_point=goblet_point, half=0.21, toe_out=22.0)
    kb = goblet_point(body)
    kb[2] = 0.0
    for side in (1, -1):
        body.arm(side, kb + Y * 0.09 + Z * side * 0.07 - X * 0.02, unit(-Y + Z * side * 0.3 - X * 0.2))
    # Held by the horns, the bell below the hands.
    handle_l, handle_r = kb + Y * 0.09 - Z * 0.07, kb + Y * 0.09 + Z * 0.07
    s.line([kb + Y * 0.0 - Z * 0.08, handle_l, handle_r, kb + Y * 0.0 + Z * 0.08], 0.026, "load")
    s.ball(kb - Y * 0.05, 0.1, "load")
    show(s, body)


@demo("air-squat", views=[PROFILE(), THREE_QUARTER(35, 12)], labels=SQUAT, timing=(0.6, 1.5, 0.4, 1.2))
def air_squat(p, s):
    floor(s, -0.9, 0.9)
    body = squat_body(p, 2.0, 35.0, 0.5, load_point=None, midfoot=0.0)
    for side in (1, -1):
        sh = body.shoulder[side]
        a = lerp(-85.0, 0.0, smooth(p))   # arms rise to the front for balance
        d = unit(X * math.cos(math.radians(a)) + Y * math.sin(math.radians(a)) + Z * side * 0.04)
        body.arm(side, sh + d * 0.6, unit(-Y - X * 0.2))
    show(s, body)


@demo("deep-squat-hold", views=[PROFILE(), THREE_QUARTER(35, 12)],
      labels=("Debout, pieds largeur d'épaules", "Descente", "Squat profond, talons au sol : tiens", "Remontée"),
      timing=(0.6, 1.8, 2.6, 1.4))
def deep_squat_hold(p, s):
    floor(s, -0.9, 0.9, -0.7, 0.7)
    body = squat_body(p, 2.0, 30.0, 0.32, load_point=None, half=0.2, toe_out=25.0)
    mid = shoulder_mid(body)
    for side in (1, -1):
        hands = lerp(body.shoulder[side] - Y * 0.6 + X * 0.05, body.chest.at(u=0.18, f=0.2), smooth(p))
        hands[2] = side * lerp(0.2, 0.03, smooth(p))
        body.arm(side, hands, unit(-Y + Z * side * 0.6))
    show(s, body)


@demo("wall-sit", views=[PROFILE(), THREE_QUARTER(35, 12)],
      labels=("Dos au mur, pieds en avant", "Glisse le long du mur", "Cuisses parallèles : tiens", "Remonte"),
      timing=(0.6, 1.4, 3.0, 1.2))
def wall_sit(p, s):
    wall = -0.5
    floor(s, wall, 0.9)
    s.box(vec(wall - 0.04, 1.0, 0.0), X * 0.04, Y * 1.0, Z * 0.7, "floor", stroke=0.0, bias=10.0)
    hip_y = lerp(0.85, Body.ANKLE + Body.SHIN + 0.0, p)
    body = upright(hip_y, 0.0, pelvis_x=wall + Body.W_TORSO / 2 + 0.01, head=0)
    feet_flat(body, (wall + 0.06 + Body.THIGH, 0.14), (wall + 0.06 + Body.THIGH, -0.14))
    for side in (1, -1):
        body.arm(side, body.shoulder[side] - Y * 0.6 + Z * side * 0.05, unit(-X))
    show(s, body)


# --- Hack squat and leg press ----------------------------------------------------------------------------------

@demo("hack-squat", views=[PROFILE(), THREE_QUARTER(35, 12)],
      labels=("Dos contre le dossier, jambes tendues", "Descente le long des rails", "Cuisses parallèles au plateau", "Poussée"),
      timing=(0.6, 1.6, 0.4, 1.3))
def hack_squat(p, s):
    floor(s, -1.0, 1.1)
    rail = 50.0
    up = vec(-math.cos(math.radians(rail)), math.sin(math.radians(rail)), 0.0)   # along the rails, up and back
    normal = vec(math.sin(math.radians(rail)), math.cos(math.radians(rail)), 0.0)  # off the back pad, toward the chest
    top = vec(0.0, 0.98, 0.0)
    travel = 0.38 * p
    pelvis = top - up * travel
    body = Body(Frame(pelvis, normal, up), head=6)
    plate_tilt = 18.0
    for side in (1, -1):
        ankle = vec(0.43, 0.21, side * 0.15)
        body.leg(side, ankle, pole=unit(X + Y * 0.4))
        body.foot_toward(side, ankle + rotate(X * 0.165 - Y * 0.06, Z, plate_tilt))
    # The angled foot plate, the rails and the sled (back pad, shoulder pads, weight horns).
    plate_c = vec(0.5, 0.11, 0.0)
    pdir = rotate(X, Z, plate_tilt)
    pnorm = rotate(Y, Z, plate_tilt)
    s.slab(plate_c - pdir * 0.2, plate_c + pdir * 0.22, pnorm, 0.7, 0.04, "frame")
    s.line([vec(0.25, 0.03, 0), vec(0.85, 0.03, 0)], TUBE, "frame")
    base = vec(0.32, 0.12, 0.0)
    for side in (1, -1):
        sd = SIDE_RIGHT if side == 1 else SIDE_LEFT
        z = side * 0.33
        a = vec(0.3, 0.14, z)
        b = a + up * 1.75
        s.line([a, b], TUBE * 1.3, "frame", side=sd)
        s.line([b, vec(b[0], 0.03, z)], TUBE * 1.3, "frame", side=sd)
        s.line([vec(b[0] - 0.2, 0.025, z), vec(0.9, 0.025, z)], TUBE, "frame", side=sd)
    back_point = pelvis - normal * (Body.W_TORSO / 2 + 0.004)
    s.slab(back_point - up * 0.12, back_point + up * 0.62, normal, 0.4, 0.07, "pad", solid="le dossier")
    for side in (1, -1):
        sd = SIDE_RIGHT if side == 1 else SIDE_LEFT
        sh = body.shoulder[side]
        pad = sh + up * 0.09 + normal * 0.02
        s.line([pad - normal * 0.07, pad + normal * 0.07], 0.09, "pad", side=sd)
        horn = back_point + up * 0.2 - normal * 0.1 + Z * side * 0.33
        s.line([horn, horn + Z * side * 0.18], 0.04, "metal", side=sd)
        s.disc(horn + Z * side * 0.08, Z, 0.17, "load", side=sd)
        handle = sh + up * 0.05 + Z * side * 0.12 + normal * 0.12
        body.arm(side, handle, unit(-Y - X * 0.3 + Z * side * 0.4))
        s.line([handle, handle + up * 0.0 + normal * 0.1], 0.035, "load", side=sd)
    show(s, body)


@demo("leg-press", views=[PROFILE(), THREE_QUARTER(35, 14)],
      labels=("Jambes presque tendues", "Descente du plateau", "Genoux vers la poitrine", "Poussée"), timing=(0.6, 1.5, 0.4, 1.2))
def leg_press(p, s):
    floor(s, -1.1, 1.5)
    back_angle = 38.0
    up = vec(-math.cos(math.radians(back_angle)), math.sin(math.radians(back_angle)), 0.0)
    normal = vec(math.sin(math.radians(back_angle)), math.cos(math.radians(back_angle)), 0.0)
    hip = vec(0.0, 0.5, 0.0)
    body = Body(Frame(hip, normal, up), head=12)
    sled = vec(math.cos(math.radians(45)), math.sin(math.radians(45)), 0.0)
    plate_up = vec(-sled[1], sled[0], 0.0)
    reach = lerp(0.84, 0.47, smooth(p) * 0.0 + p)
    for side in (1, -1):
        ankle = hip + sled * reach + plate_up * 0.08 + Z * side * 0.15
        body.leg(side, ankle, pole=plate_up)
        body.foot_toward(side, ankle + plate_up * 0.165 + sled * 0.06)
    # Seat and backrest.
    seat_pt = hip - normal * (Body.W_TORSO / 2 + 0.004)
    s.slab(seat_pt - up * 0.08, seat_pt + up * 0.75, normal, 0.34, 0.08, "pad", solid="le dossier")
    seat_dir = rotate(sled, Z, -20)
    s.slab(seat_pt + seat_dir * 0.02 - Y * 0.0, seat_pt + seat_dir * 0.3, rotate(seat_dir, Z, 90), 0.42, 0.08, "pad")
    # Platform on the sled, rails at 45°.
    sole = hip + sled * (reach + 0.08) + plate_up * 0.08
    s.slab(sole - plate_up * 0.22, sole + plate_up * 0.38, -sled, 0.7, 0.04, "frame")
    for side in (1, -1):
        sd = SIDE_RIGHT if side == 1 else SIDE_LEFT
        z = side * 0.42
        rail_a = hip - plate_up * 0.26 + sled * 0.35 + Z * z
        rail_b = hip - plate_up * 0.26 + sled * 1.75 + Z * z
        s.line([rail_a, rail_b], TUBE * 1.3, "frame", side=sd)
        s.line([rail_b, vec(rail_b[0], 0.03, z)], TUBE * 1.3, "frame", side=sd)
        horn = sole + sled * 0.12 + plate_up * 0.25 + Z * side * 0.36
        s.line([horn, horn + Z * side * 0.18], 0.04, "metal", side=sd)
        s.disc(horn + Z * side * 0.08, Z, 0.2, "load", side=sd)
        s.line([sole + sled * 0.02 + Z * side * 0.32, horn], TUBE, "frame", side=sd)
        s.line([sole + sled * 0.03 - plate_up * 0.2 + Z * z, hip - plate_up * 0.26 + sled * (reach + 0.12) + Z * z], TUBE * 1.2, "frame", side=sd)
        handle = hip + Z * side * 0.3 + Y * 0.02 + X * 0.05
        body.arm(side, handle, unit(-X - Y * 0.3))
        s.line([handle - X * 0.08, handle + X * 0.08], 0.035, "load", side=sd)
    s.line([vec(-0.9, 0.03, 0), vec(1.55, 0.03, 0)], TUBE, "frame")
    s.line([seat_pt - normal * 0.08, vec(seat_pt[0], 0.03, 0)], TUBE * 1.3, "frame")
    back_top = seat_pt + up * 0.75 - normal * 0.08
    s.line([back_top, vec(back_top[0], 0.03, 0)], TUBE * 1.3, "frame")
    show(s, body)


# --- Hinges: deadlifts, RDL, good morning ----------------------------------------------------------------

def hinge_body(p, hip_top, hip_bottom, lean_top, lean_bottom, grip_point, bar_x=0.0, half=0.15, toe_out=8.0, head=None,
               knee_lock=None):
    """A hinge with the load kept over the middle of the feet: the hips go back as the torso leans."""
    hip_y = lerp(hip_top, hip_bottom, p)
    lean = lerp(lean_top, lean_bottom, p)
    hd = head if head is not None else -lean * 0.6

    def at_x(px):
        b = upright(hip_y, lean, pelvis_x=px, head=hd)
        return grip_point(b)[0]

    px = solve(at_x, -1.2, 1.0, bar_x)
    body = upright(hip_y, lean, pelvis_x=px, head=hd)
    stance(body, bar_x - 0.06, half_width=half, toe_out=toe_out)
    return body


def hanging_grip(b, ahead=0.0):
    """Where the hands are with the arms hanging straight down (a little ahead of the shoulders)."""
    m = shoulder_mid(b)
    return m + vec(ahead, -0.625, 0.0)


def lift_from_floor(p, lean_floor, bar_top, half, toe_out, grip_half, ahead=0.02):
    """A deadlift: the bar rises from the floor along a vertical line over the middle of the feet;
    knees extend first, then the hips. Hips are found so the straight arms reach the bar."""
    k = smooth(p)
    bar_y = lerp(0.225, bar_top, k)
    lean = lean_floor * (1 - smooth(min(1.0, p * 1.05)) ** 1.6)

    def make(hip_y, px):
        return upright(hip_y, lean, pelvis_x=px, head=-lean * 0.5)

    def grip_y(hip_y):
        return hanging_grip(make(hip_y, 0.0), ahead)[1]

    hip_y = solve(grip_y, 0.3, 1.1, bar_y + 0.012)
    px = solve(lambda x: hanging_grip(make(hip_y, x), ahead)[0], -1.2, 1.0, 0.0)
    body = make(hip_y, px)
    stance(body, -0.06, half_width=half, toe_out=toe_out)
    bar = vec(0.0, bar_y, 0.0)
    for side in (1, -1):
        body.arm(side, bar + Z * side * grip_half, unit(-X * 1.0 + Z * side * 0.2))
    return body, bar


@demo("deadlift", views=[PROFILE(), THREE_QUARTER(35, 12)],
      labels=("Barre au sol, dos plat", "Poussée des jambes, barre collée", "Debout, hanches tendues", "Descente contrôlée"),
      timing=(0.7, 1.5, 0.6, 1.6))
def deadlift(p, s):
    floor(s, -0.9, 0.9)
    body, bar = lift_from_floor(p, 50.0, 0.84, 0.15, 8.0, 0.25)
    barbell(s, bar, Z)
    show(s, body)


@demo("sumo-deadlift", views=[THREE_QUARTER(40, 12), FRONT(6)],
      labels=("Pieds très écartés, barre au sol", "Poussée des jambes", "Debout, hanches tendues", "Descente contrôlée"),
      timing=(0.7, 1.5, 0.6, 1.6))
def sumo_deadlift(p, s):
    floor(s, -0.9, 0.9, -0.9, 0.9)
    body, bar = lift_from_floor(p, 38.0, 0.79, 0.4, 38.0, 0.17)
    barbell(s, bar, Z)
    show(s, body)


def rdl_like(p, s, load, lean_bottom=72.0, hip_drop=0.06):
    body = hinge_body(p, 0.925, 0.925 - hip_drop, 2.0, lean_bottom, lambda b: hanging_grip(b, 0.03), bar_x=0.0)
    for side in (1, -1):
        sh = body.shoulder[side]
        target = hanging_grip(body, 0.03) + Z * side * 0.22
        body.arm(side, target, unit(-X + Z * side * 0.1))
    return body


@demo("rdl", views=[PROFILE(), THREE_QUARTER(35, 12)],
      labels=("Debout, barre contre les cuisses", "Hanches en arrière, dos plat", "Étirement des ischios", "Retour, hanches en avant"),
      timing=(0.6, 1.7, 0.4, 1.3))
def rdl(p, s):
    floor(s, -0.9, 0.9)
    body = rdl_like(p, s, "bar", hip_drop=0.09)
    bar = (body.grip[1] + body.grip[-1]) / 2
    barbell(s, bar, Z)
    show(s, body)


@demo("db-rdl", views=[PROFILE(), THREE_QUARTER(35, 12)],
      labels=("Debout, haltères devant les cuisses", "Hanches en arrière, dos plat", "Étirement des ischios", "Retour, hanches en avant"),
      timing=(0.6, 1.7, 0.4, 1.3))
def db_rdl(p, s):
    floor(s, -0.9, 0.9)
    body = rdl_like(p, s, "dumbbells", lean_bottom=70.0, hip_drop=0.09)
    for side in (1, -1):
        dumbbell(s, body.grip[side], Z, side=SIDE_RIGHT if side == 1 else SIDE_LEFT)
    show(s, body)


@demo("good-morning", views=[PROFILE(), THREE_QUARTER(35, 12)],
      labels=("Barre sur le haut du dos", "Buste vers l'avant, dos plat", "Buste presque à l'horizontale", "Retour"),
      timing=(0.6, 1.7, 0.4, 1.3))
def good_morning(p, s):
    floor(s, -1.0, 0.9)
    body = hinge_body(p, 0.935, 0.9, 2.0, 78.0, lambda b: shoulder_mid(b) * 0.0 + b.pelvis.o * 0.0 + vec(b.pelvis.o[0] + 0.12, 0, 0), bar_x=0.0)
    bar = back_bar(body)
    bar[2] = 0.0
    for side in (1, -1):
        body.arm(side, bar + Z * side * 0.42, unit(-Y - X * 0.6 + Z * side * 0.2))
    barbell(s, bar, Z)
    show(s, body)


@demo("single-leg-rdl", views=[PROFILE(), THREE_QUARTER(35, 12)],
      labels=("Debout sur une jambe", "Buste et jambe libre en balancier", "Corps en « T »", "Retour"),
      timing=(0.6, 1.7, 0.5, 1.4))
def single_leg_rdl(p, s):
    floor(s, -1.3, 0.9)
    lean = lerp(2.0, 80.0, p)
    hip_y = lerp(0.915, 0.87, smooth(p))     # the standing knee softens slightly
    body = upright(hip_y, lean, pelvis_x=-0.0, head=-lean * 0.7)

    def at_x(px):
        b = upright(hip_y, lean, pelvis_x=px, head=-lean * 0.7)
        return hanging_grip(b, 0.03)[0]

    px = solve(at_x, -1.2, 1.0, lerp(0.04, 0.16, smooth(p)))     # free leg as counterweight: hands slightly ahead of the foot
    body = upright(hip_y, lean, pelvis_x=px, head=-lean * 0.7)
    body.foot_on_floor(-1, (0.0, -0.1), 0.0, pole=X)
    # The free (right) leg goes back in line with the torso.
    back_dir = unit(-body.pelvis.u * 1.0)
    rest = unit(-Y + X * 0.08)
    d = unit(lerp(rest, back_dir, smooth(p)))
    knee_bend = lerp(25.0, 4.0, p)
    body.leg_dirs(1, d, rotate(d, Z, -knee_bend))
    body.foot_relaxed(1, plantar=lerp(20.0, 0.0, p))
    g = hanging_grip(body, 0.03)
    body.arm(1, g + body.chest.r * 0.15, unit(-X))
    body.arm(-1, body.shoulder[-1] - Y * 0.6 + X * 0.02, unit(-X))
    dumbbell(s, body.grip[1], X, side=SIDE_RIGHT)
    show(s, body)


@demo("kb-swing", views=[PROFILE(), THREE_QUARTER(35, 12)],
      labels=("Kettlebell entre les jambes", "Extension explosive des hanches", "Kettlebell à hauteur de poitrine", "Retour en charnière"),
      timing=(0.25, 0.7, 0.2, 0.75))
def kb_swing(p, s):
    floor(s, -0.9, 1.1)
    lean = lerp(58.0, -2.0, p)
    hip_y = lerp(0.84, 0.94, p)

    def at_x(px):
        b = upright(hip_y, lean, pelvis_x=px, head=-lean * 0.55)
        return shoulder_mid(b)[0]

    px = solve(at_x, -1.2, 1.0, lerp(0.12, 0.0, p))
    body = upright(hip_y, lean, pelvis_x=px, head=-lean * 0.55)
    stance(body, -0.06, half_width=0.2, toe_out=12.0)
    angle = lerp(-112.0, 2.0, p)   # arms: behind between the legs, then forward at chest height
    d = vec(math.cos(math.radians(angle)), math.sin(math.radians(angle)), 0.0)
    grip = shoulder_mid(body) + d * 0.62
    for side in (1, -1):
        body.arm(side, grip + Z * side * 0.05, unit(-X * 0.2 + Z * side))
    kettlebell(s, grip, d, Z)
    show(s, body)


# --- Lunges, split squats, step-ups -----------------------------------------------------------------------------

def hands_on_hips(body):
    for side in (1, -1):
        target = body.pelvis.at(u=0.12, r=side * 0.16, f=0.02)
        body.arm(side, target, unit(-X * 0.6 + body.chest.r * side))


def lunge_pose(front_ankle, back_toe, hip_y, lean=2.0, back_heel_up=50.0, torso_x=None):
    """Feet planted (front flat, back on the toes), hips at hip_y between them."""
    px = torso_x if torso_x is not None else (front_ankle[0] + back_toe[0]) / 2 - 0.02
    body = upright(hip_y, lean, pelvis_x=px, head=0)
    body.foot_on_floor(1, (front_ankle[0], front_ankle[2]), 0.0, pole=X)
    ankle = body.stand_foot(-1, back_toe, 0.0, back_heel_up)
    body.leg(-1, ankle, pole=X)
    return body


@demo("lunge", views=[PROFILE(), THREE_QUARTER(35, 12)],
      labels=("Debout", "Grand pas en avant et descente", "Genou arrière près du sol", "Poussée pour revenir"),
      timing=(0.5, 1.6, 0.4, 1.3))
def lunge(p, s):
    floor(s, -0.9, 1.2)
    step = 0.95
    a = smooth(min(1.0, p / 0.4))      # the step
    b = smooth(max(0.0, (p - 0.3) / 0.7))   # the descent
    hip_y = lerp(0.95 - 0.1 * a, 0.53, b)
    front = vec(lerp(0.0, step, a), 0.0, 0.11)
    body = upright(hip_y, 2.0, pelvis_x=lerp(0.0, step * 0.53, a), head=0)
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
    hands_on_hips(body)
    show(s, body)


@demo("reverse-lunge", views=[PROFILE(), THREE_QUARTER(35, 12)],
      labels=("Debout, haltères en main", "Grand pas en arrière et descente", "Genou arrière près du sol", "Retour en avant"),
      timing=(0.5, 1.6, 0.4, 1.3))
def reverse_lunge(p, s):
    floor(s, -1.2, 0.9)
    step = 0.98
    a = smooth(min(1.0, p / 0.4))
    b = smooth(max(0.0, (p - 0.35) / 0.65))
    hip_y = lerp(0.95 - 0.08 * a, 0.53, b)
    body = upright(hip_y, 3.0, pelvis_x=lerp(0.0, -step * 0.43, a), head=0)
    body.foot_on_floor(1, (0.0, 0.11), 0.0, pole=X)
    toe_x = lerp(0.165, 0.165 - step, a)
    lift = 0.1 * math.sin(math.pi * a) if a < 0.999 else 0.0
    heel = lerp(0.0, 55.0, a)
    ankle = body.stand_foot(-1, vec(toe_x, 0.02 + lift, -0.11), 0.0, heel)
    body.leg(-1, ankle, pole=X)
    for side in (1, -1):
        g = body.shoulder[side] - Y * 0.62 + X * 0.02
        body.arm(side, g, unit(-X))
        dumbbell(s, g, X, side=SIDE_RIGHT if side == 1 else SIDE_LEFT)
    show(s, body)


@demo("bulgarian-split", views=[PROFILE(), THREE_QUARTER(35, 12)],
      labels=("Pied arrière sur le banc", "Descente verticale", "Cuisse avant parallèle", "Poussée sur la jambe avant"),
      timing=(0.6, 1.5, 0.4, 1.2))
def bulgarian_split(p, s):
    floor(s, -1.25, 0.9)
    top = 0.43
    from ex_chest import bench_across
    bench_across(s, -0.82, top, half=0.5)
    hip_y = lerp(0.86, 0.55, p)
    body = upright(hip_y, lerp(4.0, 12.0, p), pelvis_x=lerp(-0.14, -0.1, p), head=0)
    body.foot_on_floor(1, (0.24, 0.11), 0.0, pole=X)
    # Rear foot: the top of the foot on the bench, toes pointing back.
    instep = vec(-0.78, top + 0.03, -0.11)
    ankle = instep + vec(0.12, 0.05, 0.0)
    body.leg(-1, ankle, pole=X)
    body.toe[-1] = ankle + vec(-0.17, -0.03, 0.0)
    for side in (1, -1):
        g = body.shoulder[side] - Y * 0.62 + X * 0.03
        body.arm(side, g, unit(-X))
        dumbbell(s, g, X, side=SIDE_RIGHT if side == 1 else SIDE_LEFT)
    s.allow = {("tibia gauche", "le banc")}
    show(s, body)


@demo("step-up", views=[PROFILE(), THREE_QUARTER(35, 12)],
      labels=("Pied droit sur le banc", "Poussée sur la jambe droite", "Debout sur le banc", "Redescente contrôlée"),
      timing=(0.6, 1.4, 0.5, 1.4))
def step_up(p, s):
    floor(s, -0.7, 1.1)
    top = 0.43
    from ex_chest import bench_across
    bench_across(s, 0.42, top, half=0.55)
    k = smooth(p)
    # The right foot stays on the bench; the body rises over it; the left foot joins.
    hip = lerp(vec(0.08, 0.9, 0.0), vec(0.4, top + 0.93, 0.0), k)
    body = upright(hip[1], lerp(14.0, 2.0, k), pelvis_x=hip[0], head=0)
    body.foot_on_floor(1, (0.36, 0.11), 0.0, floor=top, pole=X)
    # The left foot pushes off its toes (heel rising), then swings up to join the right one.
    left_t = smooth(max(0.0, (p - 0.3) / 0.7))
    start = vec(-0.05, Body.ANKLE, -0.11)
    toe0 = vec(start[0] + 0.165, 0.02, start[2])
    end = vec(0.36, top + Body.ANKLE, -0.11)
    if left_t < 0.02:
        heel = 55.0 * smooth(min(1.0, p / 0.3))
        ankle = body.stand_foot(-1, toe0, 0.0, heel)
        body.leg(-1, ankle, pole=X)
    else:
        lifted = body.stand_foot(-1, toe0, 0.0, 55.0)
        # Up above the bench first, then forward over it, then down onto it.
        up = smooth(min(1.0, left_t * 2.2))
        forward = smooth(max(0.0, (left_t - 0.15) / 0.85))
        left = vec(lerp(lifted[0], end[0], forward), lerp(lifted[1], end[1], up), end[2])
        left[1] += 0.07 * math.sin(math.pi * left_t)
        body.leg(-1, left, pole=X)
        body.toe[-1] = left + rotate(X * 0.175, Z, -lerp(55.0, 20.0, up))
    for side in (1, -1):
        g = body.shoulder[side] - Y * 0.62 + X * 0.03
        body.arm(side, g, unit(-X))
        dumbbell(s, g, X, side=SIDE_RIGHT if side == 1 else SIDE_LEFT)
    show(s, body)


# --- Leg curls -------------------------------------------------------------------------------------------

@demo("lying-leg-curl", views=[PROFILE(), THREE_QUARTER(35, 14)],
      labels=("À plat ventre, jambes tendues", "Flexion des genoux", "Talons vers les fessiers", "Descente lente"),
      timing=(0.6, 1.2, 0.5, 1.8))
def lying_leg_curl(p, s):
    floor(s, -1.3, 1.1)
    top = 0.62
    # Pad: thighs part slightly lower than the hips' hump, chest part ahead.
    s.slab(vec(-0.38, top, 0), vec(0.85, top, 0), Y, 0.34, PAD_T, "pad", solid="le banc")
    body = lying_on_front(top, 0.0, head=-6)
    flex = lerp(2.0, 118.0, p)
    for side in (1, -1):
        thigh = -X
        shin = rotate(-X, Z, -flex)
        body.leg_dirs(side, thigh, shin)
        body.foot_relaxed(side, plantar=-5)
        body.arm(side, vec(0.62, top - 0.08, side * 0.24), unit(Y * 0.3 + X * 0.3 + Z * side))
    knee = body.knee[1]
    shin_dir = unit(body.ankle[1] - knee)
    back_of_leg = rotate(shin_dir, Z, 90)
    roll_at = knee + shin_dir * 0.37 + back_of_leg * (Body.W_SHIN / 2 + 0.05)
    roller(s, vec(roll_at[0], roll_at[1], 0.0), half=0.2)
    pivot = vec(knee[0], knee[1], -0.27)
    s.line([pivot, vec(roll_at[0], roll_at[1], -0.27), vec(roll_at[0], roll_at[1], -0.2)], TUBE * 1.2, "frame", side=SIDE_LEFT)
    s.disc(pivot, Z, 0.06, "frame", side=SIDE_LEFT)
    s.line([vec(-0.3, top - PAD_T, 0), vec(-0.3, 0.03, 0)], TUBE * 1.2, "frame")
    s.line([vec(0.75, top - PAD_T, 0), vec(0.75, 0.03, 0)], TUBE * 1.2, "frame")
    s.line([vec(-0.6, 0.03, 0), vec(0.95, 0.03, 0)], TUBE, "frame")
    s.line([vec(-0.5, 0.03, -0.27), vec(knee[0], knee[1] - 0.02, -0.27)], TUBE * 1.2, "frame", side=SIDE_LEFT)
    for side in (1, -1):
        s.line([vec(0.55, top - 0.08, side * 0.3), vec(0.7, top - 0.08, side * 0.3)], 0.035, "load",
               side=SIDE_RIGHT if side == 1 else SIDE_LEFT)
    stack(s, -0.75, 0.0, lift=p * 0.12, height=1.2)
    show(s, body)


@demo("seated-leg-curl", views=[PROFILE(), THREE_QUARTER(35, 14)],
      labels=("Jambes tendues sur le rouleau", "Flexion des genoux", "Talons sous le siège", "Retour lent"),
      timing=(0.6, 1.2, 0.5, 1.8))
def seated_leg_curl(p, s):
    floor(s, -0.85, 1.35)
    seat_y = 0.5
    junction, back_dir, normal = seat_with_back(s, -0.1, 0.36, seat_y, back_angle=16.0, back_len=0.66)
    body = seated_upright(seat_y, 0.0, lean=-16, head=8)
    flex = lerp(8.0, 112.0, p)
    for side in (1, -1):
        body.leg_dirs(side, X, rotate(X, Z, -flex))
        body.foot_relaxed(side, plantar=-5)
    knee = body.knee[1]
    shin_dir = unit(body.ankle[1] - knee)
    calf_side = rotate(shin_dir, Z, -90)
    roll_at = knee + shin_dir * 0.36 + calf_side * (Body.W_SHIN / 2 + 0.05)
    roller(s, vec(roll_at[0], roll_at[1], 0.0), half=0.2)
    # The thigh pad, on top of the thighs just above the knees.
    thigh_pad = knee - X * 0.1 + Y * (Body.W_THIGH / 2 + 0.05)
    roller(s, vec(thigh_pad[0], thigh_pad[1], 0.0), half=0.2, r=0.05)
    pivot = vec(knee[0], knee[1], -0.28)
    s.line([pivot, vec(roll_at[0], roll_at[1], -0.28), vec(roll_at[0], roll_at[1], -0.2)], TUBE * 1.2, "frame", side=SIDE_LEFT)
    s.line([vec(thigh_pad[0], thigh_pad[1], -0.2), vec(thigh_pad[0], thigh_pad[1], -0.28), pivot], TUBE, "frame", side=SIDE_LEFT)
    s.disc(pivot, Z, 0.06, "frame", side=SIDE_LEFT)
    s.line([vec(0.05, seat_y - PAD_T, 0), vec(0.05, 0.03, 0)], TUBE * 1.3, "frame")
    s.line([vec(-0.65, 0.03, 0), vec(0.85, 0.03, 0)], TUBE, "frame")
    s.line([vec(0.85, 0.03, -0.28), pivot], TUBE * 1.2, "frame", side=SIDE_LEFT)
    for side in (1, -1):
        sd = SIDE_RIGHT if side == 1 else SIDE_LEFT
        h = vec(0.05, seat_y + 0.02, side * 0.28)
        s.line([h - X * 0.08, h + X * 0.08], 0.035, "load", side=sd)
        body.arm(side, h, unit(-X + Z * side * 0.3))
    stack(s, -0.6, 0.0, lift=p * 0.12, height=1.35)
    show(s, body)


@demo("nordic-curl", views=[PROFILE(), THREE_QUARTER(35, 12)],
      labels=("À genoux, chevilles bloquées", "Descente très lente du buste", "Mains qui amortissent", "Retour"),
      timing=(0.6, 2.6, 0.4, 1.4))
def nordic_curl(p, s):
    floor(s, -0.9, 1.3)
    pad_top = 0.05
    s.slab(vec(-0.6, pad_top, 0), vec(0.15, pad_top, 0), Y, 0.5, 0.05, "pad", solid="le tapis")
    knee = vec(0.0, pad_top + Body.W_SHIN / 2 + 0.004, 0.0)
    angle = lerp(88.0, 22.0, p)       # the body line from the floor
    u = vec(math.cos(math.radians(angle)), math.sin(math.radians(angle)), 0.0)
    f = vec(u[1], -u[0], 0.0)
    pelvis = knee + u * Body.THIGH
    body = Body(Frame(pelvis, f, u), head=-6)
    for side in (1, -1):
        body.leg_dirs(side, -u, -X)
        # Shins on the pad, the top of the foot resting on it, toes pointing back.
        body.foot_toward(side, body.ankle[side] + vec(-0.172, -0.02, 0.0))
    ankle = body.ankle[1]
    roller(s, vec(ankle[0] + 0.02, ankle[1] + Body.W_SHIN / 2 + 0.05, 0.0), half=0.22)
    s.line([vec(ankle[0] + 0.02, ankle[1] + 0.1, 0.24), vec(ankle[0] - 0.2, 0.03, 0.24)], TUBE, "frame", side=SIDE_RIGHT)
    s.line([vec(ankle[0] + 0.02, ankle[1] + 0.1, -0.24), vec(ankle[0] - 0.2, 0.03, -0.24)], TUBE, "frame", side=SIDE_LEFT)
    # Hands: crossed on the chest, then out to catch near the floor.
    catch = smooth(max(0.0, (p - 0.6) / 0.4))
    for side in (1, -1):
        sh = body.shoulder[side]
        chest = body.chest.at(u=0.3, f=0.12, r=-side * 0.08)
        floor_pt = vec(sh[0] + 0.15, 0.03, sh[2])
        target = lerp(chest, floor_pt, catch)
        body.arm(side, target, unit(-u + body.chest.r * side * 0.5))
    show(s, body)


# --- Glutes ---------------------------------------------------------------------------------------------

def bridge_body(p, contact, feet_x, lift_angle, low_angle, single=False, head=10, reach=0.3):
    """Shoulder blades on a contact point (bench edge or floor): the torso turns around it."""
    a = lerp(low_angle, lift_angle, p)
    d = vec(math.cos(math.radians(a)), math.sin(math.radians(a)), 0.0)     # from the contact toward the hips
    pelvis = contact + d * reach
    u = -d
    f = vec(-u[1], u[0], 0.0) * -1
    if f[1] < 0:
        f = -f
    body = Body(Frame(pelvis, f, u), head=head)
    for side in (1, -1):
        if single and side == -1:
            thigh = unit(body.knee[1] - body.hip[1]) if 1 in body.knee else X
            continue
        body.foot_on_floor(side, (feet_x, side * 0.14), 0.0, pole=Y)
    if single:
        thigh = unit(body.knee[1] - body.hip[1])
        body.leg_dirs(-1, thigh, thigh)
        body.foot_relaxed(-1, plantar=20)
    return body


@demo("hip-thrust", views=[PROFILE(), THREE_QUARTER(35, 14)],
      labels=("Haut du dos sur le banc, hanches basses", "Poussée des hanches", "Buste et cuisses alignés", "Descente contrôlée"),
      timing=(0.6, 1.1, 0.8, 1.4))
def hip_thrust(p, s):
    floor(s, -1.0, 1.0)
    from ex_chest import bench_across
    top = 0.43
    bench_across(s, -0.62, top, half=0.6)
    contact = vec(-0.5, top + Body.W_TORSO / 2, 0.0)
    body = bridge_body(p, contact, 0.32, 0.0, -38.0, head=lerp(25.0, 12.0, p))
    bar = body.pelvis.at(f=Body.W_TORSO / 2 + 0.035, u=-0.04)
    bar[2] = 0.0
    for side in (1, -1):
        body.arm(side, bar + Z * side * 0.42, unit(Y * 0.2 - X * 0.5 + Z * side * 0.4))
    barbell(s, bar, Z)
    s.allow = {"le banc"}
    show(s, body)


@demo("glute-bridge", views=[PROFILE(), THREE_QUARTER(35, 14)],
      labels=("Allongé, genoux pliés", "Montée des hanches", "Épaules, hanches et genoux alignés", "Descente contrôlée"),
      timing=(0.6, 1.0, 0.8, 1.3))
def glute_bridge(p, s):
    floor(s, -1.0, 0.9)
    contact = vec(-0.6, Body.W_TORSO / 2 + 0.02, 0.0)
    body = bridge_body(p, contact, 0.3, 30.0, 0.0, head=lerp(32.0, 52.0, p), reach=0.53)
    for side in (1, -1):
        body.arm(side, vec(body.pelvis.o[0] - 0.12, 0.03, side * 0.3), unit(Y + Z * side * 0.2))
    show(s, body)


@demo("single-leg-bridge", views=[PROFILE(), THREE_QUARTER(35, 14)],
      labels=("Une jambe tendue", "Montée sur la jambe d'appui", "Hanches hautes et de niveau", "Descente contrôlée"),
      timing=(0.6, 1.0, 0.8, 1.3))
def single_leg_bridge(p, s):
    floor(s, -1.0, 1.2)
    contact = vec(-0.6, Body.W_TORSO / 2 + 0.02, 0.0)
    body = bridge_body(p, contact, 0.3, 28.0, 0.0, single=True, head=lerp(32.0, 52.0, p), reach=0.53)
    for side in (1, -1):
        body.arm(side, vec(body.pelvis.o[0] - 0.12, 0.03, side * 0.3), unit(Y + Z * side * 0.2))
    show(s, body)


def all_fours(hip_y=0.6, hands_x=0.62, knees_x=0.0, head=-10):
    """On hands and knees: hands under the shoulders, knees under the hips, back flat."""
    knee_pt = vec(knees_x, Body.W_SHIN / 2 + 0.004, 0.0)
    pelvis = knee_pt + Y * Body.THIGH + vec(0.0, 0.0, 0.0)
    body = Body(Frame(pelvis, -Y, X), head=head)
    return body


def quadruped(head=-12, twist=0.0, spine=0.0, pelvis_tilt=0.0):
    pelvis_pt = vec(0.0, Body.W_SHIN / 2 + 0.01 + Body.THIGH, 0.0)
    frame = Frame(pelvis_pt, -Y, X)
    if pelvis_tilt:
        frame = frame.pitched(pelvis_tilt)
    body = Body(frame, head=head, twist=twist, spine=spine)
    return body


def plant_quadruped(body, skip=()):
    for side in (1, -1):
        if ("leg", side) not in skip:
            knee = vec(body.hip[side][0], Body.W_SHIN / 2 + 0.004, body.hip[side][2])
            body.leg_dirs(side, unit(knee - body.hip[side]), -X)
            body.foot_relaxed(side, plantar=60)
        if ("arm", side) not in skip:
            sh = body.shoulder[side]
            body.arm(side, vec(sh[0] + 0.02, 0.04, sh[2] + side * 0.02), unit(-X + Z * side * 0.1))


@demo("donkey-kick", views=[PROFILE(), THREE_QUARTER(35, 14)],
      labels=("À quatre pattes, dos plat", "Talon vers le plafond", "Cuisse dans l'alignement du dos", "Retour sans poser le genou"),
      timing=(0.5, 1.0, 0.6, 1.1))
def donkey_kick(p, s):
    floor(s, -0.9, 1.0)
    body = quadruped()
    plant_quadruped(body, skip={("leg", 1)})
    hip = body.hip[1]
    lift = lerp(-88.0, 8.0, p)      # thigh angle from horizontal-backward
    thigh = vec(-math.cos(math.radians(lift)), math.sin(math.radians(lift)), 0.0)
    thigh = unit(vec(thigh[0], thigh[1], 0.0)) if p > 0 else unit(vec(0.0, -1.0, 0.0))
    shin = rotate(thigh, Z, -90 if p > 0 else -90)
    body.leg_dirs(1, thigh, shin)
    body.foot_relaxed(1, plantar=-5)
    show(s, body)


@demo("fire-hydrant", views=[View("3/4 dos", -45, 22), BACK(16)],
      labels=("À quatre pattes, dos plat", "Genou plié levé sur le côté", "Cuisse à l'horizontale", "Retour lent"),
      timing=(0.5, 1.0, 0.6, 1.1))
def fire_hydrant(p, s):
    floor(s, -0.9, 1.0, -0.8, 0.8)
    body = quadruped()
    plant_quadruped(body, skip={("leg", 1)})
    angle = lerp(0.0, 80.0, p)
    thigh = unit(-Y * math.cos(math.radians(angle)) + Z * math.sin(math.radians(angle)))
    shin = -X
    body.leg_dirs(1, thigh, shin)
    body.foot_relaxed(1, plantar=50)
    show(s, body)


@demo("cable-kickback", views=[PROFILE(), THREE_QUARTER(35, 12)],
      labels=("Face à la poulie, sangle à la cheville", "Jambe tendue vers l'arrière", "Fessier contracté", "Retour lent"),
      timing=(0.6, 1.0, 0.6, 1.4))
def cable_kickback(p, s):
    floor(s, -1.0, 1.0)
    body = upright(0.94, 18.0, pelvis_x=-0.05, head=-10)
    body.foot_on_floor(-1, (0.05, -0.1), 0.0, pole=X)
    angle = lerp(-6.0, 32.0, p)        # hip extension, from a bit in front to behind
    d = unit(vec(-math.sin(math.radians(angle)), -math.cos(math.radians(angle)), 0.0))
    d = rotate(d, Z, 18.0)
    body.leg_dirs(1, d, rotate(d, Z, -8))
    body.foot_relaxed(1, plantar=10)
    col_x = 0.62
    for side in (1, -1):
        body.arm(side, vec(col_x - 0.12, 1.15, side * 0.2), unit(-Y - X * 0.3 + Z * side * 0.3))
    pul = vec(col_x - 0.13, 0.12, 0.0)
    ankle = body.ankle[1]
    col = Column(s, col_x, 0.0, height=2.1, depth=0.24, width=0.4)
    a0 = unit(rotate(vec(math.sin(math.radians(6)), -math.cos(math.radians(6)), 0.0), Z, 18.0))
    start_ankle = body.hip[1] + a0 * 0.86
    col.frame(lift=np.linalg.norm(ankle - pul) - np.linalg.norm(start_ankle - pul))
    s.disc(pul, Z, 0.045, "frame")
    cable(s, pul, ankle)
    s.ball(ankle, 0.045, "load", side=SIDE_RIGHT)
    show(s, body)


@demo("cable-pull-through", views=[PROFILE(), THREE_QUARTER(35, 12)],
      labels=("Dos à la poulie, corde entre les jambes", "Extension des hanches", "Debout, fessiers serrés", "Retour en charnière"),
      timing=(0.6, 1.1, 0.6, 1.4))
def cable_pull_through(p, s):
    floor(s, -1.3, 0.9)
    lean = lerp(62.0, 0.0, p)
    hip_y = lerp(0.84, 0.94, p)

    def at_x(px):
        b = upright(hip_y, lean, pelvis_x=px, head=-lean * 0.6)
        return shoulder_mid(b)[0]

    px = solve(at_x, -1.2, 1.0, lerp(0.18, 0.02, p))
    body = upright(hip_y, lean, pelvis_x=px, head=-lean * 0.6)
    stance(body, -0.04, half_width=0.25, toe_out=15.0)
    # Arms straight: hands pulled back between the legs, then in front of the hips.
    angle = lerp(-118.0, -84.0, p)
    d = vec(math.cos(math.radians(angle)), math.sin(math.radians(angle)), 0.0)
    grip = shoulder_mid(body) + d * 0.62
    for side in (1, -1):
        body.arm(side, grip + Z * side * 0.05, unit(-X * 0.2 + Z * side))
    pul = vec(-1.0, 0.18, 0.0)
    col = Column(s, -1.15, 0.0, height=2.1, depth=0.24, width=0.4)
    col.frame(lift=p * 0.45)
    s.disc(pul, Z, 0.045, "frame")
    knot = grip - X * 0.06
    cable(s, pul, knot)
    for side in (1, -1):
        s.line([knot, grip + Z * side * 0.05], 0.022, "load")
    show(s, body)


def abductor_machine(s, p, opening, pads_outside):
    """Seated, back reclined, knees bent with the feet on pegs; the leg pads turn around a vertical
    axis under each hip. opening: angle of each thigh from straight ahead."""
    seat_y = 0.48
    junction, back_dir, normal = seat_with_back(s, -0.12, 0.3, seat_y, back_angle=20.0, back_len=0.66)
    body = on_surface_seat(seat_y)
    for side in (1, -1):
        thigh = rotate(X, Y, -side * opening)
        shin = unit(-Y * 0.9 + thigh * 0.25)
        body.leg_dirs(side, thigh, shin)
        body.foot_relaxed(side, plantar=0)
        knee = body.knee[side]
        sd = SIDE_RIGHT if side == 1 else SIDE_LEFT
        lateral = unit(np.cross(Y, thigh)) * -side      # outward from the thigh
        off = (Body.W_THIGH / 2 + 0.04) * (1 if pads_outside else -1)
        pad_c = knee - thigh * 0.08 + lateral * off
        s.line([pad_c - thigh * 0.12, pad_c + thigh * 0.06], 0.08, "pad", side=sd)
        pivot = vec(body.hip[side][0], seat_y - 0.12, side * 0.08)
        arm_end = vec(pad_c[0], seat_y - 0.12, pad_c[2])
        s.line([pivot, arm_end, vec(pad_c[0], pad_c[1] - 0.04, pad_c[2])], TUBE, "frame", side=sd)
        peg = body.ankle[side] - Y * 0.03
        s.line([peg - thigh * 0.06, peg + thigh * 0.12], 0.035, "frame", side=sd)
        body.arm(side, vec(0.05, seat_y + 0.04, side * 0.27), unit(-X + Z * side * 0.4))
        s.line([vec(-0.02, seat_y + 0.04, side * 0.27), vec(0.12, seat_y + 0.04, side * 0.27)], 0.035, "load", side=sd)
    s.line([vec(0.05, seat_y - PAD_T, 0), vec(0.05, 0.03, 0)], TUBE * 1.3, "frame")
    s.line([vec(-0.7, 0.03, 0), vec(0.7, 0.03, 0)], TUBE, "frame")
    stack(s, -0.62, 0.0, lift=p * 0.12, height=1.3)
    return body


def on_surface_seat(seat_y):
    return seated_upright(seat_y, 0.0, lean=-20, head=10)


@demo("hip-abduction", views=[View("Face", 90, 34), ABOVE(90, 72)],
      labels=("Genoux serrés, coussins à l'extérieur", "Écarte les genoux", "Ouverture maximale", "Retour lent"),
      timing=(0.6, 1.1, 0.6, 1.5))
def hip_abduction(p, s):
    floor(s, -0.9, 0.95, -0.85, 0.85)
    body = abductor_machine(s, p, lerp(2.0, 34.0, p), pads_outside=True)
    show(s, body)


@demo("hip-adduction", views=[View("Face", 90, 34), ABOVE(90, 72)],
      labels=("Genoux écartés, coussins à l'intérieur", "Resserre les genoux", "Genoux joints", "Ouverture lente"),
      timing=(0.6, 1.1, 0.6, 1.5))
def hip_adduction(p, s):
    floor(s, -0.9, 0.95, -0.85, 0.85)
    body = abductor_machine(s, p, lerp(36.0, 3.0, p), pads_outside=False)
    show(s, body)


# --- Calves ---------------------------------------------------------------------------------------------

CALF = ("Talons bas", "Montée sur la pointe des pieds", "Contraction en haut", "Descente lente")


def calf_body(p, step_y, low=-18.0, high=32.0, lean=0.0, x=0.0):
    raise_deg = lerp(low, high, p)
    body = upright(1.0, lean, pelvis_x=x, head=0)
    ankles = {}
    for side in (1, -1):
        toe = vec(x + 0.12, step_y + 0.02, side * 0.11)
        ankles[side] = body.stand_foot(side, toe, 0.0, raise_deg)
    # The body rises with the ankles (legs straight).
    hip_y = ankles[1][1] + Body.SHIN + Body.THIGH - 0.004
    body = upright(hip_y, lean, pelvis_x=ankles[1][0] - 0.0, head=0)
    for side in (1, -1):
        body.stand_foot(side, vec(x + 0.12, step_y + 0.02, side * 0.11), 0.0, raise_deg)
        body.leg(side, ankles[side], pole=X)
    return body


@demo("standing-calf", views=[PROFILE(), THREE_QUARTER(35, 12)], labels=CALF, timing=(0.6, 0.9, 0.7, 1.3))
def standing_calf(p, s):
    floor(s, -0.8, 0.8)
    step = 0.1
    s.box(vec(0.2, step / 2, 0.0), X * 0.12, Y * step / 2, Z * 0.35, "frame", stroke=0.01, solid="la marche")
    body = calf_body(p, step)
    # Shoulder pads on a lever over the shoulders.
    for side in (1, -1):
        sh = body.shoulder[side]
        sd = SIDE_RIGHT if side == 1 else SIDE_LEFT
        s.line([sh + Y * 0.07 - X * 0.07, sh + Y * 0.07 + X * 0.1], 0.09, "pad", side=sd)
        body.arm(side, sh + Y * 0.1 + X * 0.14 + Z * side * 0.1, unit(-Y + Z * side))
    mid = shoulder_mid(body)
    lever_end = mid + Y * 0.12 + X * 0.02
    pivot = vec(0.75, lever_end[1] + 0.02 - 0.0, 0.0)
    s.line([vec(lever_end[0], lever_end[1], -0.28), vec(lever_end[0], lever_end[1], 0.28)], TUBE, "frame")
    s.line([vec(lever_end[0], lever_end[1], 0.0), vec(-0.45, lever_end[1], 0.0)], TUBE * 1.2, "frame")
    s.line([vec(-0.45, 0.03, 0.0), vec(-0.45, 2.0, 0.0)], TUBE * 1.3, "frame")
    s.line([vec(-0.6, 0.03, 0), vec(0.45, 0.03, 0)], TUBE, "frame")
    stack(s, -0.62, 0.0, lift=(lever_end[1] - 1.55) if False else p * 0.1, height=2.0)
    s.allow = {"la marche"}
    show(s, body)


@demo("seated-calf", views=[PROFILE(), THREE_QUARTER(35, 12)], labels=CALF, timing=(0.6, 0.9, 0.7, 1.3))
def seated_calf(p, s):
    floor(s, -0.7, 0.9)
    seat_y = 0.47
    s.slab(vec(-0.25, seat_y, 0), vec(0.15, seat_y, 0), Y, 0.36, PAD_T, "pad", solid="le siège")
    s.line([vec(-0.05, seat_y - PAD_T, 0), vec(-0.05, 0.03, 0)], TUBE * 1.2, "frame")
    step = 0.12
    s.box(vec(0.55, step / 2, 0.0), X * 0.1, Y * step / 2, Z * 0.3, "frame", stroke=0.01, solid="la marche")
    body = seated_upright(seat_y, -0.05, lean=6.0, head=6)
    raise_deg = lerp(-16.0, 30.0, p)
    for side in (1, -1):
        toe = vec(0.56, step + 0.02, side * 0.11)
        ankle = body.stand_foot(side, toe, 0.0, raise_deg)
        body.leg(side, ankle, pole=unit(X + Y))
    knee = body.knee[1]
    pad = knee - X * 0.08 + Y * (Body.W_THIGH / 2 + 0.05)
    roller(s, vec(pad[0], pad[1], 0.0), half=0.2)
    s.line([vec(pad[0], pad[1], 0.0), vec(pad[0] - 0.45, pad[1] - 0.05, 0.0), vec(-0.5, 0.2, 0.0)], TUBE * 1.2, "frame")
    for side in (1, -1):
        body.arm(side, vec(pad[0] - 0.05, pad[1] + 0.03, side * 0.24), unit(-X - Y * 0.3 + Z * side * 0.4))
    s.disc(vec(-0.45, 0.4, 0.0), Z, 0.06, "frame")
    s.line([vec(-0.5, 0.03, 0), vec(0.75, 0.03, 0)], TUBE, "frame")
    s.allow = {"la marche"}
    show(s, body)


@demo("single-calf", views=[PROFILE(), THREE_QUARTER(35, 12)],
      labels=("Sur une jambe, talon bas", "Montée sur la pointe", "Contraction en haut", "Descente lente"),
      timing=(0.6, 0.9, 0.7, 1.3))
def single_calf(p, s):
    floor(s, -0.6, 1.0)
    step = 0.15
    s.box(vec(0.2, step / 2, 0.0), X * 0.13, Y * step / 2, Z * 0.35, "frame", stroke=0.01, solid="la marche")
    raise_deg = lerp(-18.0, 32.0, p)
    body = upright(1.0, 0.0, pelvis_x=0.0, head=0)
    toe = vec(0.12, step + 0.02, 0.1)
    ankle = body.stand_foot(1, toe, 0.0, raise_deg)
    body = upright(ankle[1] + Body.SHIN + Body.THIGH - 0.004, 2.0, pelvis_x=ankle[0], head=0)
    body.stand_foot(1, toe, 0.0, raise_deg)
    body.leg(1, ankle, pole=X)
    # The other foot hooked behind the working ankle.
    body.leg(-1, ankle + vec(-0.14, 0.06, -0.08), pole=X)
    body.foot_relaxed(-1, plantar=30)
    g = body.shoulder[1] - Y * 0.62 + X * 0.02
    body.arm(1, g, unit(-X))
    dumbbell(s, g, X, side=SIDE_RIGHT)
    wall = 0.5
    s.box(vec(wall + 0.04, 1.0, 0.0), X * 0.04, Y * 1.0, Z * 0.6, "floor", stroke=0.0, bias=10.0)
    body.arm(-1, vec(wall, 1.3, -0.22), unit(-Y - X * 0.3 - Z * 0.4))
    s.allow = {"la marche"}
    show(s, body)


@demo("walking-lunge", views=[PROFILE(), THREE_QUARTER(35, 12)], mode="loop", samples=40,
      labels=("Descente en fente", "Pas en avant avec l'autre jambe"),
      segments=[(0.9, 0.0, 0.2, 0, 1), (1.1, 0.2, 0.5, 1, 1), (0.9, 0.5, 0.7, 0, 1), (1.1, 0.7, 1.0, 1, 1)],
      travel=(1.84, 0.46, -1.3, 1.5, -0.45, 0.45, 0.0, 40.0))
def walking_lunge(p, s):
    floor(s, -1.3, 1.5)
    step = 0.92
    half = 0 if p < 0.5 else 1
    t = (p - 0.5 * half) / 0.5          # within one lunge
    base = step * half                   # world shift of this half cycle
    front_side = 1 if half == 0 else -1
    back_side = -front_side
    if t < 0.4:
        k = smooth(t / 0.4)
        hip = vec(base + 0.5, lerp(0.83, 0.53, k), 0.0)
        front = vec(base + step, 0.0, 0.0)
        back = vec(base, 0.0, 0.0)
        moving = 0.0
    else:
        k = smooth((t - 0.4) / 0.6)
        hip = vec(base + 0.5 + step * k, 0.0, 0.0)
        hip[1] = lerp(0.53, 0.83, k) + 0.08 * math.sin(math.pi * k)
        front = vec(base + step, 0.0, 0.0)
        back = vec(base + 2 * step * k, 0.0, 0.0)
        moving = k
    shift = -2 * step * p
    hip[0] += shift
    body = upright(hip[1], 3.0, pelvis_x=hip[0], head=0)
    fx = front[0] + shift
    body.foot_on_floor(front_side, (fx, front_side * 0.11), 0.0, pole=X)
    bx = back[0] + shift
    if moving <= 0.0 or moving >= 1.0:
        heel = 55.0 if t < 0.4 or moving <= 0.0 else 0.0
        ankle = body.stand_foot(back_side, vec(bx + 0.165, 0.02, back_side * 0.11), 0.0, heel if moving < 1 else 0.0)
        body.leg(back_side, ankle, pole=X)
    else:
        lift = 0.16 * math.sin(math.pi * moving)
        ankle = vec(bx + 0.02, Body.ANKLE + lift + 0.06 * (1 - moving), back_side * 0.11)
        body.leg(back_side, ankle, pole=X)
        body.toe[back_side] = ankle + rotate(X * 0.165 - Y * 0.06, Z, -30 * math.sin(math.pi * moving))
    hands_on_hips(body)
    show(s, body)
