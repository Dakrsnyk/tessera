"""Machines: pec deck, leg extension, leg curl, leg press, hack squat, chest/shoulder press, rows,
lat pulldown... Each draws its frame, pads, levers and weight stack, the lever pivots placed on the
joint they turn around (knee, shoulder), so the body and the machine move together."""
import math

import numpy as np

from engine import SIDE_LEFT, SIDE_RIGHT, X, Y, Z, lerp, rotate, unit, vec
from gear import PAD_T, PAD_W, TUBE, foot_bar

PAD = "pad"


def stack(scene, x, z, lift, height=1.75, depth=0.22, width=0.36, side=0):
    """A weight stack in its frame (two guide rods), the top plates lifted by lift."""
    for zz in (z - width / 2, z + width / 2):
        sd = side or (SIDE_RIGHT if zz > z else SIDE_LEFT)
        scene.line([vec(x, 0.03, zz), vec(x, height, zz)], TUBE, "frame", side=sd)
    scene.line([vec(x, height, z - width / 2), vec(x, height, z + width / 2)], TUBE, "frame")
    scene.line([vec(x - 0.12, 0.025, z), vec(x + 0.12, 0.025, z)], TUBE, "frame")
    base = 0.08 + max(0.0, lift)
    scene.box(vec(x, base + 0.14, z), X * depth / 2, Y * 0.14, Z * (width / 2 - 0.04), "load", stroke=0.01)
    scene.box(vec(x, 0.08 + 0.05, z), X * depth / 2, Y * 0.05, Z * (width / 2 - 0.04), "load", stroke=0.01)


def seat_with_back(scene, seat_back_x, seat_front_x, seat_y, back_angle=10.0, back_len=0.68, z=0.0, name="le siège",
                   back_gap=0.0):
    """A seat (pad from back to front, top at seat_y) and a backrest leaning back by back_angle from
    vertical. Returns (junction, backrest direction, normal toward the person)."""
    scene.slab(vec(seat_back_x, seat_y, z), vec(seat_front_x, seat_y, z), Y, 0.36, PAD_T, PAD, solid=name)
    back_dir = rotate(Y, Z, back_angle)        # up and back (toward -x)
    normal = rotate(X, Z, back_angle)          # toward the person (+x, a little up)
    junction = vec(seat_back_x, seat_y, z)
    start = junction + back_dir * 0.03 - normal * 0.0 + X * back_gap
    scene.slab(start, start + back_dir * back_len, normal, 0.36, PAD_T, PAD, solid="le dossier")
    return junction, back_dir, normal


# --- Pec deck ---------------------------------------------------------------------------------------

def pec_deck_frame(scene, seat_y, back_x, shoulder, top_y=2.0, reverse=False):
    """The tower behind the backrest, the top beam over the user and the two pivots above the shoulders.
    shoulder: {1: right shoulder, -1: left}."""
    col_x = back_x - 0.32 if not reverse else back_x + 0.32
    for zz in (-0.16, 0.16):
        scene.line([vec(col_x, 0.03, zz), vec(col_x, top_y, zz)], TUBE * 1.3, "frame",
                   side=SIDE_RIGHT if zz > 0 else SIDE_LEFT)
    scene.line([vec(col_x - 0.35, 0.025, 0), vec(col_x + 0.55 * (1 if not reverse else -1), 0.025, 0)], TUBE, "frame")
    foot_bar(scene, col_x - 0.3, half=0.35)
    pivots = {}
    for s in (1, -1):
        sh = shoulder[s]
        pivot = vec(sh[0], top_y - 0.04, sh[2] + 0.02 * s)
        pivots[s] = pivot
        side = SIDE_RIGHT if s == 1 else SIDE_LEFT
        scene.line([vec(col_x, top_y, 0.16 * s), pivot], TUBE * 1.2, "frame", side=side)
        scene.disc(pivot + Y * 0.02, Y, 0.06, "frame", side=side)
    scene.line([vec(col_x, top_y, -0.16), vec(col_x, top_y, 0.16)], TUBE * 1.2, "frame")
    return pivots, col_x


def pec_deck_arm(scene, pivot, grip, side, handle_half=0.09):
    """A lever hanging from its pivot: across at the top, then down to the vertical handle held at grip."""
    above = vec(grip[0], pivot[1], grip[2])
    scene.line([pivot, above], TUBE * 1.1, "frame", side=side)
    scene.line([above, grip + Y * (handle_half + 0.06)], TUBE * 1.1, "frame", side=side)
    scene.line([grip + Y * handle_half, grip - Y * handle_half], 0.045, "load", side=side)


# --- Leg extension / leg curl --------------------------------------------------------------------------

def roller(scene, center, half=0.19, r=0.05, side=0):
    """A foam roller pad along z."""
    scene.line([center - Z * half, center + Z * half], r * 2, PAD, side=side)
