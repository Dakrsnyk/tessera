"""Catalogue d'exercices, lot 02 : curls croisé et traîné, poulies, poignets, dips (anneaux, machine), écartés, Svend press.
Chaque démonstration part de celle d'un exercice intégré proche et l'adapte."""
import math

import numpy as np

from demos import demo, show
from engine import (FRONT, PROFILE, THREE_QUARTER, Body, SIDE_LEFT, SIDE_RIGHT, View, X, Y, Z,
                    lerp, posture, rotate, unit, vec)
from gear import (TUBE, Column, adjustable_bench, barbell, cable, d_handle, dumbbell,
                  flat_bench, floor, plate, pulley)
from machines import seat_with_back, stack
from poses import feet_flat, lying_on_back, on_backrest, placed, seated_upright, stance
from ex_arms import curl_body


def sd(side):
    return SIDE_RIGHT if side == 1 else SIDE_LEFT


# --- Curl marteau croisé : les deux bras en alternance, l'avant-bras remonte en diagonale vers l'épaule opposée. -----

def cross_amount(p, side):
    """0..1 : le bras de droite monte dans la première moitié de la boucle, celui de gauche dans la seconde."""
    q = p if side == 1 else (p + 0.5) % 1.0
    return math.sin(math.pi * q * 2) ** 2 if q < 0.5 else 0.0


@demo("x-cross-body-hammer-curl", views=[THREE_QUARTER(35, 10), FRONT()], mode="loop", timing=4.4, samples=28,
      labels=(), muscles=(["biceps"], ["forearms"]))
def cross_body_hammer_curl(p, s):
    floor(s, -0.6, 0.9, -0.7, 0.7)
    body = curl_body(p, s)
    for side in (1, -1):
        a = cross_amount(p, side)
        sh = body.shoulder[side]
        upper = unit(-Y + X * 0.05 * a + body.chest.r * side * 0.06)
        elbow = sh + upper * Body.UPPER
        # Le coude se plie autour d'un axe incliné : la main monte vers l'épaule opposée.
        axis = rotate(body.chest.r, Y, side * 40.0)
        fore = rotate(upper, axis, 6.0 + 134.0 * a)
        grip = elbow + fore * Body.LOWER
        body.arm_via(side, grip, elbow)
        dumbbell(s, grip, rotate(fore, body.chest.r * side, 90), side=sd(side))
    show(s, body)


# --- Curl traîné : la barre glisse le long du buste, les coudes reculent. ------------------------------------------

@demo("x-drag-curl", views=[PROFILE(), THREE_QUARTER(35, 10)],
      labels=("Bras tendus, barre contre les cuisses", "Coudes vers l'arrière, barre collée au corps",
              "Barre sous la poitrine", "Descente lente"),
      timing=(0.6, 1.2, 0.5, 1.6), muscles=(["biceps"], ["forearms"]))
def drag_curl(p, s):
    floor(s, -0.6, 0.9)
    body = curl_body(p, s)
    for side in (1, -1):
        sh = body.shoulder[side]
        upper = unit(-Y - X * 0.5 * p + body.chest.r * side * 0.12)
        elbow = sh + upper * Body.UPPER
        fore = rotate(upper, body.chest.r, lerp(16.0, 105.0, p) + 24.0 * p)
        grip = elbow + fore * Body.LOWER
        body.arm_via(side, vec(grip[0], grip[1], side * 0.2), elbow)
    bar = (body.grip[1] + body.grip[-1]) / 2
    barbell(s, bar, Z, plate_r=0.14)
    show(s, body)


# --- Curl à la poulie, bras en l'air : double biceps entre deux poulies hautes. ------------------------------------

@demo("x-overhead-cable-curl", views=[FRONT(), THREE_QUARTER(50, 12)],
      labels=("Bras écartés, à hauteur d'épaules", "Mains vers la tête", "Contraction, biceps serrés", "Retour lent"),
      timing=(0.6, 1.2, 0.6, 1.6), muscles=(["biceps"], []))
def overhead_cable_curl(p, s):
    floor(s, -0.7, 0.9, -1.5, 1.5)
    body = curl_body(p, s)
    z_col = 1.25
    pulley_y = 1.95
    angle = lerp(8.0, 128.0, p)
    for side in (1, -1):
        sh = body.shoulder[side]
        upper = unit(Z * side * 1.0 + Y * 0.04)
        elbow = sh + upper * Body.UPPER
        fore = rotate(upper, X, -side * angle)       # la main monte vers la tête
        grip = elbow + fore * Body.LOWER
        body.arm_via(side, grip, elbow)
    for side in (1, -1):
        top = vec(0.05, pulley_y, side * (z_col - 0.12))
        g = body.grip[side]
        sh0 = body.shoulder[side]
        g0 = sh0 + Z * side * (Body.UPPER + Body.LOWER)
        column = Column(s, 0.05, side * z_col, height=2.15, depth=0.22, width=0.24)
        column.frame(lift=np.linalg.norm(g - top) - np.linalg.norm(g0 - top))
        pulley(s, top, X, side=sd(side))
        cable(s, top, g, side=sd(side))
        d_handle(s, g, unit(Y * 0.3 + X), side=sd(side))
    s.line([vec(0.05, 2.15, -z_col), vec(0.05, 2.15, z_col)], TUBE, "frame")
    show(s, body)


# --- Extension des poignets assis, un bras, haltère en pronation. --------------------------------------------------

@demo("x-seated-one-arm-dumbbell-palms-down-wrist-curl", views=[PROFILE(), THREE_QUARTER(35, 14)],
      labels=("Avant-bras sur la cuisse, poignet en bas", "Extension du poignet", "Poignet en haut", "Descente lente"),
      timing=(0.6, 0.9, 0.5, 1.2), muscles=(["forearms"], []))
def wrist_extension_one_arm(p, s):
    floor(s, -0.8, 1.0)
    top = 0.43
    flat_bench(s, -0.6, 0.35, top)
    body = seated_upright(top, -0.05, lean=52.0, head=20)
    feet_flat(body, (0.42, 0.17), (0.42, -0.17), pole=unit(X + Y * 0.6))
    wrist_angle = lerp(-55.0, 45.0, p)
    for side in (1, -1):
        knee = body.knee[side]
        thigh = unit(knee - body.hip[side])
        thigh_top = knee + Y * (Body.R_THIGH + Body.W_LOWER / 2)
        wrist = thigh_top + thigh * 0.11
        elbow = wrist - thigh * Body.LOWER
        body.arm_via(side, wrist, elbow)
    fore = unit(body.grip[1] - body.elbow[1])
    hand_dir = rotate(fore, Z, wrist_angle)
    center = body.grip[1] + hand_dir * 0.09
    s.line([body.grip[1], center], 0.05, "muscle", side=SIDE_RIGHT)
    dumbbell(s, center, Z, side=SIDE_RIGHT)
    show(s, body)


# --- Dips aux anneaux : anneaux suspendus, coudes qui s'écartent légèrement. ----------------------------------------

@demo("x-ring-dips", views=[PROFILE(), THREE_QUARTER(40, 12)],
      labels=("Appui sur les anneaux, bras tendus", "Descente, épaules sous les coudes", "Coudes à 90° ou plus bas",
              "Poussée, anneaux stables"),
      timing=(0.6, 1.6, 0.4, 1.2), muscles=(["triceps"], ["chest", "shoulders"]))
def ring_dips(p, s):
    from ex_chest import dips_body
    floor(s, -0.7, 0.7)
    body = dips_body(p, 6, 18, 0.30, 0.3, bar_y=1.12, bar_half=0.24)
    beam = 2.15
    s.line([vec(0.0, beam, -0.5), vec(0.0, beam, 0.5)], 0.04, "metal")
    for side in (1, -1):
        g = body.grip[side]
        center = g + Y * 0.075
        s.disc(center, Z, 0.085, "metal", side=sd(side))
        s.line([center + Y * 0.085, vec(0.0, beam, side * 0.24)], 0.014, "cable", side=sd(side))
    s.line([vec(-0.65, beam, -0.5), vec(-0.65, 0.03, -0.5)], TUBE, "frame")
    s.line([vec(-0.65, beam, 0.5), vec(-0.65, 0.03, 0.5)], TUBE, "frame")
    s.line([vec(-0.65, beam, -0.5), vec(0.0, beam, -0.5)], TUBE, "frame")
    s.line([vec(-0.65, beam, 0.5), vec(0.0, beam, 0.5)], TUBE, "frame")
    show(s, body)


# --- Dips à la machine : assis, on pousse les poignées vers le bas. ------------------------------------------------

@demo("x-dip-machine", views=[PROFILE(), THREE_QUARTER(45, 14)],
      labels=("Coudes à 90°, mains sur les poignées", "Poussée vers le bas", "Bras tendus", "Remontée contrôlée"),
      timing=(0.7, 1.4, 0.5, 1.6), muscles=(["triceps"], ["chest", "shoulders"]))
def dip_machine(p, s):
    floor(s, -0.9, 0.9, -0.8, 0.8)
    seat_y = 0.5
    seat_with_back(s, -0.1, 0.3, seat_y, back_angle=6.0, back_len=0.78)
    body = seated_upright(seat_y, -0.1 + 0.07, lean=-4, head=0)
    feet_flat(body, (body.pelvis.o[0] + 0.5, 0.2), (body.pelvis.o[0] + 0.5, -0.2))
    for side in (1, -1):
        sh = body.shoulder[side]
        start = sh + vec(0.28, -0.30, 0.0) + Z * side * 0.07
        end = sh + vec(0.08, -(Body.UPPER + Body.LOWER - 0.02), 0.0) + Z * side * 0.07
        grip = lerp(start, end, p)
        body.arm(side, grip, unit(-X * 1.0 + Z * side * 0.25 - Y * 0.1))
        # Poignée, bras de levier vers un pivot en arrière du siège.
        pivot = vec(-0.28, 0.62, side * 0.3)
        s.line([pivot, grip], 0.036, "frame", side=sd(side))
        d_handle(s, grip, Z, side=sd(side))
        s.disc(pivot, Z, 0.04, "metal", side=sd(side))
    stack(s, -0.62, 0.0, lift=p * 0.12, height=1.4)
    show(s, body)


# --- Oiseau à la poulie : câbles croisés, ouverture horizontale. ---------------------------------------------------

@demo("x-cable-rear-delt-fly", views=[FRONT(8), THREE_QUARTER(50, 14)],
      labels=("Bras tendus devant, câbles croisés", "Ouverture vers l'arrière", "Bras en croix, omoplates serrées",
              "Retour contrôlé"),
      timing=(0.7, 1.4, 0.6, 1.8), muscles=(["shoulders"], []))
def cable_rear_delt_fly(p, s):
    floor(s, -0.75, 1.0, -1.5, 1.5)
    z_col = 1.25
    pulley_y = 1.5      # at shoulder height, ahead of the body: the crossed cables pass in front of the chest, not the face
    body = placed(posture(vec(0, 0, 0), 0.0, 8.0), "pelvis", vec(0.0, 0.92, 0.0), head=-2)
    stance(body, 0.0, half_width=0.13)
    for side in (1, -1):
        sh = body.shoulder[side]
        d0 = unit(X * 0.97 - Z * side * 0.18 - Y * 0.06)
        d1 = unit(Z * side * 0.97 - X * 0.2 - Y * 0.02)
        d = unit(lerp(d0, d1, p))
        grip = sh + d * 0.6
        body.arm(side, grip, unit(-Y * 0.35 - X * 0.5 + Z * side * 0.3 * p))
        top = vec(0.6, pulley_y, -side * (z_col - 0.12))   # le câble de la main droite vient de la poulie gauche
        g0 = sh + d0 * 0.6
        column = Column(s, 0.6, -side * z_col, height=2.15, depth=0.22, width=0.24)
        column.frame(lift=np.linalg.norm(grip - top) - np.linalg.norm(g0 - top))
        pulley(s, top, unit(np.cross(grip - top, X)), side=sd(side))
        cable(s, top, grip, side=sd(side))
        d_handle(s, grip, Y, side=sd(side))
    s.line([vec(0.6, 2.15, -z_col), vec(0.6, 2.15, z_col)], TUBE, "frame")
    show(s, body)


# --- Svend press : deux disques serrés paume contre paume, poussés devant la poitrine. -----------------------------

@demo("x-svend-press", views=[PROFILE(), THREE_QUARTER(40, 12)],
      labels=("Disques serrés contre la poitrine", "Extension des bras vers l'avant", "Bras tendus, disques serrés",
              "Retour à la poitrine"),
      timing=(0.7, 1.3, 0.8, 1.3), muscles=(["chest"], ["forearms", "shoulders", "triceps"]))
def svend_press(p, s):
    floor(s, -0.6, 1.0, -0.7, 0.7)
    body = placed(posture(vec(0, 0, 0), 0.0, 3.0), "pelvis", vec(0.0, 0.92, 0.0), head=0)
    stance(body, 0.0, half_width=0.13)
    mid = (body.shoulder[1] + body.shoulder[-1]) / 2
    start = mid + vec(0.22, -0.17, 0.0)
    end = mid + vec(Body.UPPER + Body.LOWER - 0.06, -0.01, 0.0)
    center = lerp(start, end, p)
    for side in (1, -1):
        body.arm(side, center + Z * side * 0.03, unit(-Y * 1.0 + Z * side * 0.3 - X * 0.1))
    plate(s, center, Z, r=0.115)
    plate(s, center + Z * 0.012, Z, r=0.115)
    plate(s, center - Z * 0.012, Z, r=0.115)
    show(s, body)


# --- Tour du monde : sur banc plat, bras tendus en arc, du dessus de la poitrine vers les hanches. ----------------

@demo("x-around-the-worlds", views=[THREE_QUARTER(55, 22), View("Face", 90, 42)],
      labels=("Haltères au-dessus de la poitrine", "Arc large sur les côtés", "Bras le long du corps, vers les hanches",
              "Retour en arc"),
      timing=(0.7, 2.2, 0.5, 1.8), muscles=(["chest"], ["shoulders"]))
def around_the_worlds(p, s):
    floor(s, -1.2, 1.0, -0.9, 0.9)
    flat_bench(s, -0.8, 0.42, 0.43)
    body = lying_on_back(0.43, 0.0, head=14)
    feet_flat(body, (0.62, 0.27), (0.62, -0.27), pole=Y)
    reach = 0.58
    for side in (1, -1):
        sh = body.shoulder[side]
        if p < 0.5:
            phi = math.radians(lerp(-6.0, 88.0, p * 2))
            d = unit(Y * math.cos(phi) + Z * side * math.sin(phi))
        else:
            beta = math.radians(lerp(0.0, 62.0, (p - 0.5) * 2))
            d = unit(Z * side * math.cos(beta) + X * math.sin(beta) - Y * 0.04)
        grip = sh + d * reach
        body.arm(side, grip, unit(-Y * 0.4 + Z * side * 0.1 + X * 0.2))
        dumbbell(s, grip, X, side=sd(side))
    show(s, body)


# --- Écarté incliné (haltères) : banc à 30°. -----------------------------------------------------------------------

@demo("x-incline-dumbbell-flyes", views=[THREE_QUARTER(55, 18), View("Face", 90, 38)],
      labels=("Haltères au-dessus de la poitrine", "Ouverture en arc", "Étirement des pecs", "Fermeture"),
      timing=(0.7, 1.8, 0.4, 1.4), muscles=(["chest"], ["shoulders"]))
def incline_dumbbell_flyes(p, s):
    floor(s, -1.45, 1.0, -0.9, 0.9)
    J, d, n = adjustable_bench(s, 0.0, 30.0)
    body = on_backrest(J, d, n, seat_y=0.45, head=14)
    feet_flat(body, (body.pelvis.o[0] + 0.5, 0.24), (body.pelvis.o[0] + 0.5, -0.24))
    phi = lerp(-9.0, 72.0, p)
    reach = 0.58
    c = body.chest
    for side in (1, -1):
        sh = body.shoulder[side]
        direction = unit(c.f * math.cos(math.radians(phi)) + c.r * side * math.sin(math.radians(phi)))
        grip = sh + direction * reach
        body.arm(side, grip, unit(-c.f * 0.1 - c.u * 0.6 + c.r * side * 0.1))
        dumbbell(s, grip, c.u, side=sd(side))
    show(s, body)


# --- Écarté à la poulie basse (vis-à-vis bas) : de bas en haut en arc. --------------------------------------------

@demo("x-low-cable-crossover", views=[FRONT(8), THREE_QUARTER(50, 14)],
      labels=("Bras tendus vers le bas, mains écartées", "Arc vers le haut et l'avant", "Mains jointes devant la poitrine",
              "Retour lent"),
      timing=(0.7, 1.4, 0.6, 1.8), muscles=(["chest"], ["shoulders"]))
def low_cable_crossover(p, s):
    floor(s, -0.75, 1.0, -1.5, 1.5)
    z_col = 1.25
    body = placed(posture(vec(0, 0, 0), 0.0, 14.0), "pelvis", vec(0.28, 0.9, 0.0), head=-4)
    body.foot_on_floor(1, (0.55, 0.15), -8.0)
    body.foot_on_floor(-1, (0.0, -0.15), 8.0)
    body.planted[-1] = True
    for side in (1, -1):
        sh = body.shoulder[side]
        d0 = unit(Z * side * 0.85 - Y * 0.5 - X * 0.12)
        d1 = unit(X * 0.9 + Y * 0.4 - Z * side * 0.06)
        d = unit(lerp(d0, d1, p))
        grip = sh + d * 0.6
        body.arm(side, grip, unit(-Y * 0.5 - X * 0.5 + Z * side * 0.1))
        low = vec(0.1, 0.2, side * (z_col - 0.12))
        g0 = sh + d0 * 0.6
        column = Column(s, 0.1, side * z_col, height=2.15, depth=0.22, width=0.24)
        column.frame(lift=np.linalg.norm(grip - low) - np.linalg.norm(g0 - low))
        pulley(s, low, unit(np.cross(grip - low, X)), side=sd(side))
        cable(s, low, grip, side=sd(side))
        d_handle(s, grip, unit(Y * 0.3 + X * 0.7), side=sd(side))
    s.line([vec(0.1, 2.15, -z_col), vec(0.1, 2.15, z_col)], TUBE, "frame")
    show(s, body)
