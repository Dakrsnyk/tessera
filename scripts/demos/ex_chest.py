"""Chest: presses (bench, dumbbells, incline, decline, machine), push-ups, flyes, dips."""
import math

import numpy as np

from demos import demo, show
from engine import (ABOVE, FRONT, PROFILE, THREE_QUARTER, Body, Frame, SIDE_LEFT, SIDE_RIGHT, View, X, Y, Z, lerp,
                    posture, rotate, unit, vec)
from gear import (PAD_T, PAD_W, TUBE, Column, adjustable_bench, barbell, bench_rack, cable, d_handle, dumbbell,
                  flat_bench, floor, foot_bar, pulley)
from machines import pec_deck_arm, pec_deck_frame, roller, seat_with_back, stack
from poses import (feet_flat, lying_on_back, on_backrest, on_surface, placed, plank_on_knees, plank_on_toes,
                   seated_upright, solve, stance)

PRESS = ("Bras tendus", "Descente", "Charge à la poitrine", "Poussée")
PUSH_UP = ("Bras tendus, corps gainé", "Descente", "Poitrine près du sol", "Poussée")
BENCH_TOP = 0.43


def press_poles(body, out=0.75, down=1.0, toward_feet=0.15):
    """Elbows under the load, opened about 45-60° from the torso."""
    c = body.chest
    right = unit(-c.f * down + c.r * out - c.u * toward_feet)
    left = unit(-c.f * down - c.r * out - c.u * toward_feet)
    return right, left


def shoulder_mid(body):
    return (body.shoulder[1] + body.shoulder[-1]) / 2


def lockout(body, grip_half, reach=0.632):
    """The load above the shoulders, arms almost straight and vertical."""
    top = shoulder_mid(body) + Y * math.sqrt(reach ** 2 - max(0.0, grip_half - Body.SH_HALF) ** 2)
    top[2] = 0.0
    return top


def on_chest(body, u, extra=0.02):
    point = body.chest.at(u=u, f=Body.W_TORSO / 2 + extra)
    point[2] = 0.0
    return point


def j_path(top, bottom, p):
    """Bar path of a bench press: over the shoulders at the top, onto the lower chest at the bottom,
    curving (vertical near the chest)."""
    q = 1 - (1 - p) ** 2
    out = lerp(top, bottom, p)
    out[0] = lerp(top[0], bottom[0], q)
    return out


# --- Flat bench -------------------------------------------------------------------------------------

def bench_across(s, x, height=BENCH_TOP, half=0.6):
    """A flat bench seen from its side: the pad runs along z (across the person)."""
    s.slab(vec(x, height, -half), vec(x, height, half), Y, PAD_W, PAD_T, "pad", solid="le banc")
    under = height - PAD_T
    s.line([vec(x, under, -half + 0.14), vec(x, under, half - 0.14)], TUBE, "frame")
    for z in (-half + 0.14, half - 0.14):
        sd = SIDE_RIGHT if z > 0 else SIDE_LEFT
        s.line([vec(x, under, z), vec(x, 0.03, z)], TUBE, "frame", side=sd)
        s.line([vec(x - 0.22, 0.025, z), vec(x + 0.22, 0.025, z)], TUBE, "frame", side=sd)


def flat_bench_scene(s, rack=True):
    floor(s, -1.2, 1.0)
    flat_bench(s, -0.8, 0.42, BENCH_TOP)
    body = lying_on_back(BENCH_TOP, 0.0, head=14)
    feet_flat(body, (0.62, 0.27), (0.62, -0.27), pole=Y)
    return body


@demo("bench-press", views=[PROFILE(), THREE_QUARTER(38, 16)],
      labels=("Bras tendus", "Descente", "Barre sur le bas des pecs", "Poussée"), timing=(0.7, 1.7, 0.4, 1.2))
def bench_press(p, s):
    body = flat_bench_scene(s)
    grip = 0.40
    top = lockout(body, grip)
    bottom = on_chest(body, 0.21)
    bar = j_path(top, bottom, p)
    bench_rack(s, x=top[0] - 0.14, height=top[1] - 0.05)
    right, left = press_poles(body, out=0.85, down=1.0, toward_feet=0.2)
    body.arms(bar + Z * grip, bar - Z * grip, right, left)
    barbell(s, bar, Z)
    show(s, body)


@demo("close-grip-bench", views=[PROFILE(), THREE_QUARTER(38, 16)],
      labels=("Bras tendus", "Descente, coudes serrés", "Barre sur le bas des pecs", "Poussée"), timing=(0.7, 1.7, 0.4, 1.2))
def close_grip_bench(p, s):
    body = flat_bench_scene(s)
    grip = 0.2
    top = lockout(body, grip)
    bottom = on_chest(body, 0.19)
    bar = j_path(top, bottom, p)
    bench_rack(s, x=top[0] - 0.14, height=top[1] - 0.05)
    right, left = press_poles(body, out=0.3, down=1.0, toward_feet=0.45)
    body.arms(bar + Z * grip, bar - Z * grip, right, left)
    barbell(s, bar, Z)
    show(s, body)


@demo("db-bench", views=[THREE_QUARTER(40, 16), PROFILE()],
      labels=("Haltères au-dessus des épaules", "Descente", "Haltères au niveau de la poitrine", "Poussée"),
      timing=(0.7, 1.7, 0.4, 1.2))
def db_bench(p, s):
    body = flat_bench_scene(s, rack=False)
    top_mid = lockout(body, 0.17)
    for side in (1, -1):
        top = top_mid + Z * side * 0.17
        bottom = on_chest(body, 0.26, extra=0.0) + Z * side * 0.36
        bottom[1] = body.shoulder[side][1] + 0.1
        grip = j_path(top, bottom, p)
        right, left = press_poles(body, out=0.9, down=1.0, toward_feet=0.15)
        body.arm(side, grip, right if side == 1 else left)
        dumbbell(s, grip, Z, side=SIDE_RIGHT if side == 1 else SIDE_LEFT)
    show(s, body)


# --- Incline ----------------------------------------------------------------------------------------

def incline_scene(s, angle=35.0):
    floor(s, -1.45, 1.0)
    J, d, n = adjustable_bench(s, 0.0, angle)
    body = on_backrest(J, d, n, seat_y=0.45, head=16)
    feet_flat(body, (body.pelvis.o[0] + 0.5, 0.24), (body.pelvis.o[0] + 0.5, -0.24))
    return J, d, n, body


@demo("incline-bench", views=[PROFILE(), THREE_QUARTER(35, 14)],
      labels=("Bras tendus", "Descente", "Barre en haut des pecs", "Poussée"), timing=(0.7, 1.7, 0.4, 1.2))
def incline_bench(p, s):
    J, d, n, body = incline_scene(s)
    grip = 0.40
    top = lockout(body, grip)
    bottom = on_chest(body, 0.31)
    bar = lerp(top, bottom, p)
    bench_rack(s, x=top[0] - 0.17, height=top[1] - 0.06)
    right, left = press_poles(body, out=0.8, down=1.0, toward_feet=0.1)
    body.arms(bar + Z * grip, bar - Z * grip, right, left)
    barbell(s, bar, Z)
    show(s, body)


@demo("incline-db", views=[THREE_QUARTER(35, 14), PROFILE()],
      labels=("Haltères au-dessus des épaules", "Descente", "Haltères en haut des pecs", "Poussée"),
      timing=(0.7, 1.7, 0.4, 1.2))
def incline_db(p, s):
    J, d, n, body = incline_scene(s)
    top_mid = lockout(body, 0.17)
    for side in (1, -1):
        top = top_mid + Z * side * 0.17
        bottom = on_chest(body, 0.33, extra=0.0) + Z * side * 0.36 + body.chest.f * 0.05
        grip = lerp(top, bottom, p)
        right, left = press_poles(body, out=0.9, down=1.0, toward_feet=0.1)
        body.arm(side, grip, right if side == 1 else left)
        dumbbell(s, grip, Z, side=SIDE_RIGHT if side == 1 else SIDE_LEFT)
    show(s, body)


# --- Decline ----------------------------------------------------------------------------------------

def decline_bench(s, junction, angle=18.0, back_len=0.86, thigh_angle=25.0, thigh_len=0.36):
    """Backrest going down toward -x from junction (the hips), a thigh pad rising forward, and a foam
    roller to hook the lower legs. Returns (back direction, normal)."""
    back_dir = rotate(-X, Z, angle)              # down and back
    normal = rotate(Y, Z, angle)                 # up, a little toward -x
    end = junction + back_dir * back_len
    s.slab(junction, end, normal, PAD_W, PAD_T, "pad", solid="le banc")
    thigh_dir = rotate(X, Z, thigh_angle)
    front = junction + thigh_dir * thigh_len
    s.slab(junction + thigh_dir * 0.02, front, rotate(Y, Z, thigh_angle), PAD_W, PAD_T, "pad", solid="le banc (cuisses)")
    # Frame: a post under the hips, a leg at the head end, the uprights for the bar.
    s.line([junction - normal * PAD_T, vec(junction[0], 0.03, 0)], TUBE * 1.2, "frame")
    s.line([end - normal * PAD_T + X * 0.1, vec(end[0] + 0.1, 0.03, 0)], TUBE, "frame")
    s.line([vec(end[0] + 0.1, 0.03, 0), vec(junction[0] + 0.55, 0.03, 0)], TUBE, "frame")
    foot_bar(s, end[0] + 0.1)
    foot_bar(s, junction[0] + 0.55)
    return back_dir, normal, thigh_dir


@demo("decline-bench", views=[PROFILE(), THREE_QUARTER(38, 16)],
      labels=("Bras tendus", "Descente", "Barre sur le bas des pecs", "Poussée"), timing=(0.7, 1.7, 0.4, 1.2))
def decline_bench_press(p, s):
    floor(s, -1.15, 1.1)
    junction = vec(0.25, 0.62, 0.0)
    back_dir, normal, thigh_dir = decline_bench(s, junction)
    body = on_surface(junction - back_dir * 0.0, back_dir, normal, head=14)
    # Thighs on the thigh pad, knees bent over its end, the lower legs hooked behind the roller.
    for side in (1, -1):
        thigh = thigh_dir
        shin = rotate(thigh_dir, Z, -105)
        body.leg_dirs(side, thigh, shin)
        body.foot_relaxed(side, plantar=10)
    ankle = body.ankle[1]
    shin_dir = unit(body.ankle[1] - body.knee[1])
    front = rotate(shin_dir, Z, 90)
    roll = ankle - shin_dir * 0.06 + front * (Body.W_SHIN / 2 + 0.05)
    roller(s, vec(roll[0], roll[1], 0.0), half=0.2)
    s.line([vec(roll[0], roll[1], 0.0), vec(roll[0], 0.03, 0.0)], TUBE, "frame")
    grip = 0.40
    top = lockout(body, grip)
    bottom = on_chest(body, 0.2)
    bar = j_path(top, bottom, p)
    bench_rack(s, x=top[0] - 0.15, height=top[1] - 0.05)
    right, left = press_poles(body, out=0.85, down=1.0, toward_feet=0.2)
    body.arms(bar + Z * grip, bar - Z * grip, right, left)
    barbell(s, bar, Z)
    show(s, body)


# --- Chest press machine ----------------------------------------------------------------------------

@demo("machine-chest-press", views=[PROFILE(), THREE_QUARTER(40, 16)],
      labels=("Poignées à la poitrine", "Poussée", "Bras tendus", "Retour contrôlé"), timing=(0.7, 1.3, 0.5, 1.8))
def machine_chest_press(p, s):
    floor(s, -0.95, 1.05)
    seat_y = 0.47
    junction, back_dir, normal = seat_with_back(s, -0.18, 0.22, seat_y, back_angle=12.0, back_len=0.78)
    body = on_backrest(junction, back_dir, normal, seat_y, head=4)
    feet_flat(body, (body.pelvis.o[0] + 0.52, 0.2), (body.pelvis.o[0] + 0.52, -0.2))
    sh = shoulder_mid(body)
    # Each lever turns around a pivot high behind the shoulders; the handle follows its arc.
    start = vec(sh[0] + 0.16, sh[1] - 0.07, 0.0)
    end_x = sh[0] + 0.56
    pivot = vec((start[0] + end_x) / 2 - 0.08, sh[1] + 0.95, 0.0)
    radius = np.linalg.norm(start - pivot)
    a0 = math.atan2(start[1] - pivot[1], start[0] - pivot[0])
    a1 = -math.acos(min(1.0, (end_x - pivot[0]) / radius))
    a = lerp(a0, a1, p)
    handle = pivot + vec(math.cos(a), math.sin(a), 0) * radius
    col_x = junction[0] - 0.38
    for side in (1, -1):
        z = side * lerp(0.27, 0.23, p)
        grip = vec(handle[0], handle[1], z)
        pole = unit(-Y + Z * side * 0.6 - X * 0.3)
        body.arm(side, grip, pole)
        sd = SIDE_RIGHT if side == 1 else SIDE_LEFT
        pz = vec(pivot[0], pivot[1], side * 0.36)
        s.line([pz, vec(grip[0], grip[1], side * 0.36)], TUBE * 1.3, "frame", side=sd)
        s.line([vec(grip[0], grip[1], side * 0.36), grip + Z * side * 0.07], TUBE, "frame", side=sd)
        s.line([grip + Z * side * 0.07, grip - Z * side * 0.07], 0.04, "load", side=sd)
        s.disc(pz, Z, 0.06, "frame", side=sd)
        s.line([pz, vec(col_x, pivot[1], side * 0.2)], TUBE * 1.2, "frame", side=sd)
    stack(s, col_x, 0.0, lift=p * 0.14, height=pivot[1] + 0.1)
    s.line([vec(junction[0] + 0.05, seat_y - PAD_T, 0), vec(junction[0] + 0.05, 0.03, 0)], TUBE * 1.3, "frame")
    s.line([vec(col_x, 0.03, 0), vec(junction[0] + 0.5, 0.03, 0)], TUBE, "frame")
    foot_bar(s, junction[0] + 0.5)
    show(s, body)


# --- Push-ups ---------------------------------------------------------------------------------------

def push_up_body(p, shoulder_top, shoulder_bottom, hands_half=0.27, hands_y=0.025, toes_on=0.0, knees=False,
                 elbows_out=0.75, hands_x=None, hands_z=None, toe_x=0.0):
    """A push-up rotating around the toes (or knees): the shoulders go from shoulder_top to
    shoulder_bottom height, the hands stay put."""
    def make(theta):
        if knees:
            return plank_on_knees(theta, knee_x=toe_x, shin_up=28, head=-8)
        b = plank_on_toes(theta, toe_x=toe_x, head=-8)
        if toes_on:
            pass
        return b

    def sh_y(theta):
        b = make(theta)
        return shoulder_mid(b)[1]

    theta_top = solve(sh_y, -10.0, 70.0, shoulder_top)
    theta_bottom = solve(sh_y, -10.0, 70.0, shoulder_bottom)
    top_body = make(theta_top)
    hx = shoulder_mid(top_body)[0] if hands_x is None else hands_x
    theta = lerp(theta_top, theta_bottom, p)
    body = make(theta)
    for side in (1, -1):
        hz = hands_half if hands_z is None else hands_z
        grip = vec(hx, hands_y, side * hz)
        pole = unit(-body.chest.u * 1.0 + body.chest.r * side * elbows_out - body.chest.f * 0.2)
        body.arm(side, grip, pole)
    return body


@demo("push-up", views=[PROFILE(), THREE_QUARTER(30, 16)], labels=PUSH_UP, timing=(0.6, 1.4, 0.4, 1.1))
def push_up(p, s):
    floor(s, -0.3, 1.9)
    body = push_up_body(p, 0.66, 0.14)
    show(s, body)


@demo("knee-push-up", views=[PROFILE(), THREE_QUARTER(30, 16)],
      labels=("Bras tendus, genoux au sol", "Descente", "Poitrine près du sol", "Poussée"), timing=(0.6, 1.4, 0.4, 1.1))
def knee_push_up(p, s):
    floor(s, -0.6, 1.6)
    body = push_up_body(p, 0.66, 0.14, knees=True)
    show(s, body)


@demo("incline-push-up", views=[PROFILE(), THREE_QUARTER(30, 16)],
      labels=("Mains sur le banc, bras tendus", "Descente", "Poitrine près du banc", "Poussée"), timing=(0.6, 1.4, 0.4, 1.1))
def incline_push_up(p, s):
    floor(s, -0.3, 2.0)
    body = push_up_body(p, BENCH_TOP + 0.62, BENCH_TOP + 0.13, hands_y=BENCH_TOP + 0.025)
    hx = body.grip[1][0]
    bench_across(s, hx + 0.04, BENCH_TOP)
    show(s, body)


@demo("decline-push-up", views=[PROFILE(), THREE_QUARTER(30, 16)],
      labels=("Pieds sur le banc, bras tendus", "Descente", "Poitrine près du sol", "Poussée"), timing=(0.6, 1.4, 0.4, 1.1))
def decline_push_up(p, s):
    floor(s, -1.3, 1.6)
    # Toes on a bench behind: the same push-up, rotated around the toes at bench height.
    def make(theta):
        frame = posture(vec(0, 0, 0), 0.0, 90.0 + theta)
        toe = vec(-0.85, BENCH_TOP + 0.02, 0.0)
        ankle = toe - frame.f * 0.165 + frame.u * 0.06
        pelvis = ankle + frame.u * (Body.SHIN + Body.THIGH)
        b = Body(Frame(pelvis, frame.f, frame.u), head=-8)
        for side in (1, -1):
            b.leg_dirs(side, -frame.u, -frame.u)
            b.foot_toward(side, b.ankle[side] + frame.f * 0.165 - frame.u * 0.06)
        return b

    sh_y = lambda th: shoulder_mid(make(th))[1]
    t_top = solve(sh_y, -10.0, 40.0, 0.64)
    t_bottom = solve(sh_y, -10.0, 40.0, 0.2)
    hx = shoulder_mid(make(t_top))[0]
    body = make(lerp(t_top, t_bottom, p))
    for side in (1, -1):
        grip = vec(hx, 0.025, side * 0.27)
        body.arm(side, grip, unit(-body.chest.u + body.chest.r * side * 0.75 - body.chest.f * 0.2))
    flat_bench(s, -1.25, -0.6, BENCH_TOP)
    show(s, body)


@demo("diamond-push-up", views=[THREE_QUARTER(40, 18), PROFILE()],
      labels=("Mains jointes sous la poitrine", "Descente, coudes le long du corps", "Poitrine sur les mains", "Poussée"),
      timing=(0.6, 1.4, 0.4, 1.1))
def diamond_push_up(p, s):
    floor(s, -0.3, 1.9)
    body = push_up_body(p, 0.66, 0.17, hands_z=0.05, elbows_out=0.35)
    # Thumbs and index fingers touching: the hands drawn as a small diamond under the chest.
    g1, g2 = body.grip[1], body.grip[-1]
    s.poly([g1 + X * 0.05, (g1 + g2) / 2 + X * 0.1, g2 + X * 0.05, (g1 + g2) / 2], "ink", 0.02, bias=-0.01)
    show(s, body)


# --- Flyes ------------------------------------------------------------------------------------------

@demo("db-fly", views=[THREE_QUARTER(55, 22), View("Face", 90, 14)],
      labels=("Bras au-dessus de la poitrine", "Ouverture en arc", "Étirement des pecs", "Fermeture"),
      timing=(0.7, 1.8, 0.4, 1.4))
def db_fly(p, s):
    floor(s, -1.2, 1.0, -0.9, 0.9)
    flat_bench(s, -0.8, 0.42, BENCH_TOP)
    body = lying_on_back(BENCH_TOP, 0.0, head=14)
    feet_flat(body, (0.62, 0.27), (0.62, -0.27), pole=Y)
    phi = lerp(-9.0, 80.0, p)  # from above the chest (slightly inward) to out at the sides
    reach = 0.6
    for side in (1, -1):
        sh = body.shoulder[side]
        direction = unit(Y * math.cos(math.radians(phi)) + Z * side * math.sin(math.radians(phi)))
        grip = sh + direction * reach + X * 0.04
        pole = unit(-Y * 0.4 + X * 0.6 + Z * side * 0.2)
        body.arm(side, grip, pole)
        dumbbell(s, grip, X, side=SIDE_RIGHT if side == 1 else SIDE_LEFT)
    show(s, body)


@demo("cable-fly", views=[View("Face", 90, 8), THREE_QUARTER(50, 14)],
      labels=("Bras ouverts", "Mains vers l'avant et le bas", "Mains jointes", "Ouverture lente"),
      timing=(0.7, 1.4, 0.6, 1.8))
def cable_fly(p, s):
    floor(s, -0.75, 1.0, -1.45, 1.45)
    z_col = 1.2
    pulley_y = 1.85
    body = placed(posture(vec(0, 0, 0), 0.0, 14.0), "pelvis", vec(0.28, 0.9, 0.0), head=-4)
    # Staggered stance: the right foot forward.
    body.foot_on_floor(1, (0.55, 0.15), -8.0)
    body.foot_on_floor(-1, (0.0, -0.15), 8.0)
    body.planted[-1] = True
    start = {}
    for side in (1, -1):
        sh = body.shoulder[side]
        d0 = unit(Z * side * 0.95 + Y * 0.22 - X * 0.08)
        d1 = unit(X * 0.85 - Y * 0.5 - Z * side * 0.08)
        d = unit(lerp(d0, d1, p))
        grip = sh + d * 0.6
        body.arm(side, grip, unit(-Y * 0.5 - X * 0.6 + Z * side * 0.1))
        sd = SIDE_RIGHT if side == 1 else SIDE_LEFT
        top = vec(0.1, pulley_y, side * (z_col - 0.12))
        g0 = sh + d0 * 0.6
        lift = np.linalg.norm(grip - top) - np.linalg.norm(g0 - top)
        column = Column(s, 0.1, side * z_col, height=2.2, depth=0.22, width=0.24)
        column.frame(lift=lift)
        pulley(s, top, unit(np.cross(grip - top, X)), side=sd)
        cable(s, top, grip, side=sd)
        d_handle(s, grip, unit(Y * 0.8 + X * 0.2), side=sd)
    s.line([vec(0.1, 2.2, -z_col), vec(0.1, 2.2, z_col)], TUBE, "frame")
    show(s, body)


@demo("pec-deck", views=[THREE_QUARTER(55, 30), View("Face", 90, 38), ABOVE(90, 70)],
      labels=("Bras ouverts", "Fermeture", "Mains jointes", "Ouverture lente"), timing=(0.7, 1.5, 0.6, 1.8))
def pec_deck(p, s):
    floor(s, -1.0, 0.9, -0.95, 0.95)
    seat_y = 0.5
    seat_with_back(s, -0.12, 0.3, seat_y, back_angle=6.0, back_len=0.72)
    body = seated_upright(seat_y, -0.12 + 0.07, lean=-6, head=0)
    feet_flat(body, (body.pelvis.o[0] + 0.5, 0.2), (body.pelvis.o[0] + 0.5, -0.2))
    pivots, col_x = pec_deck_frame(s, seat_y, -0.12, body.shoulder)
    # The hands turn around the shoulders (pivots right above them): from out to the sides to joined in front.
    angle = lerp(95.0, -11.0, p)
    reach = 0.6
    for side in (1, -1):
        sh = body.shoulder[side]
        direction = rotate(X, Y, -side * angle)
        grip = sh + direction * reach - Y * 0.03
        pole = unit(-Y * 1.0 - direction * 0.35)
        body.arm(side, grip, pole)
        pec_deck_arm(s, pivots[side], grip, SIDE_RIGHT if side == 1 else SIDE_LEFT)
    stack(s, col_x - 0.12, 0.0, lift=(95.0 - angle) / 106.0 * 0.12, height=1.9)
    show(s, body)


# --- Dips -------------------------------------------------------------------------------------------

def dips_body(p, lean_top, lean_bottom, drop, elbows_out, bar_y=1.12, bar_half=0.27):
    lean = lerp(lean_top, lean_bottom, p)
    frame = posture(vec(0, 0, 0), 0.0, lean)
    top_sh = vec(0.0, bar_y + 0.61, 0.0)
    sh = top_sh - Y * drop * p + X * 0.06 * p * (lean_bottom / 30.0)
    body = placed(frame, "shoulders", sh, head=4 + lean * 0.2)
    for side in (1, -1):
        grip = vec(0.02, bar_y + 0.02, side * bar_half)
        body.arm(side, grip, unit(-X * 1.0 + Z * side * elbows_out))
        thigh = rotate(-Y, Z, 18 + lean * 0.4)
        shin = rotate(thigh, Z, -95)
        body.leg_dirs(side, thigh, shin)
        body.foot_relaxed(side, plantar=35)
    return body


@demo("chest-dips", views=[PROFILE(), THREE_QUARTER(40, 12)],
      labels=("En appui, bras tendus", "Descente, buste penché", "Coudes à 90°", "Poussée"), timing=(0.6, 1.5, 0.4, 1.1))
def chest_dips(p, s):
    from gear import dip_station
    floor(s, -0.7, 0.7)
    dip_station(s)
    body = dips_body(p, 24, 32, 0.27, 0.45)
    show(s, body)
