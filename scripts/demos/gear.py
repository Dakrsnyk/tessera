"""Equipment, at real sizes (meters): benches, bars, dumbbells, kettlebells, cable stations, racks and
the floor. Each builder draws into a scene and returns the points the body uses (pad surfaces,
handles), so the body is placed on the equipment rather than near it."""
import math

import numpy as np

from engine import (SIDE_LEFT, SIDE_RIGHT, X, Y, Z, lerp, rotate, unit, vec)

TUBE = 0.04      # frame tubes
PAD_T = 0.07     # pad thickness
PAD_W = 0.28     # bench pad width


def floor(scene, x0, x1, z0=-0.55, z1=0.55):
    y = -0.004
    scene.poly([vec(x0, y, z1), vec(x1, y, z1), vec(x1, y, z0), vec(x0, y, z0)], "floor", 0.0, bias=50.0)


def foot_bar(scene, x, y=0.025, half=0.24, z=0.0):
    scene.segs(vec(x, y, z - half), vec(x, y, z + half), TUBE, "frame", parts=2)


# --- Benches ------------------------------------------------------------------------------------

def flat_bench(scene, x0, x1, height=0.43, z=0.0, name="le banc"):
    """Pad from x0 to x1 (top at height), on two legs. Returns the pad's top height."""
    scene.slab(vec(x0, height, z), vec(x1, height, z), Y, PAD_W, PAD_T, "pad", solid=name)
    under = height - PAD_T
    a, b = x0 + 0.14, x1 - 0.14
    scene.line([vec(a, under, z), vec(b, under, z)], TUBE, "frame")
    for x in (a, b):
        scene.line([vec(x, under, z), vec(x, 0.03, z)], TUBE, "frame")
        foot_bar(scene, x, z=z)
    return height


def adjustable_bench(scene, seat_back_x, angle, seat_len=0.34, back_len=0.82, height=0.45, z=0.0,
                     seat_tilt=8.0, name="le banc"):
    """Seat in front of seat_back_x (toward +x), backrest rising toward -x at angle degrees from the
    floor (0 = flat). Returns (junction point on the top surface, backrest direction, backrest normal)."""
    junction = vec(seat_back_x, height, z)
    seat_dir = rotate(X, Z, seat_tilt)
    seat_front = junction + seat_dir * seat_len
    scene.slab(junction, seat_front, rotate(Y, Z, seat_tilt), PAD_W, PAD_T, "pad", solid=name + " (assise)")
    back_dir = rotate(-X, Z, -angle)          # up and back
    back_normal = rotate(Y, Z, -angle)        # toward the person
    back_start = junction + back_dir * 0.02
    back_end = back_start + back_dir * back_len
    scene.slab(back_start, back_end, back_normal, PAD_W, PAD_T, "pad", solid=name + " (dossier)")
    # Frame: a rail on the floor, a post under the seat and a strut under the backrest.
    rail_y = 0.03
    x_front = seat_front[0] + 0.05
    x_back = min(back_end[0], seat_back_x - 0.6) - 0.05
    scene.line([vec(x_back, rail_y, z), vec(x_front, rail_y, z)], TUBE, "frame")
    foot_bar(scene, x_front, z=z)
    foot_bar(scene, x_back, z=z)
    under_seat = lerp(junction, seat_front, 0.45) - rotate(Y, Z, seat_tilt) * PAD_T
    scene.line([under_seat, vec(under_seat[0], rail_y, z)], TUBE, "frame")
    mid_back = lerp(back_start, back_end, 0.55) - back_normal * PAD_T
    foot = vec(min(mid_back[0] + 0.05, seat_back_x - 0.15), rail_y, z)
    scene.line([mid_back, foot], TUBE, "frame")
    return junction, back_dir, back_normal


def bench_rack(scene, x, height, z_half=0.55, z=0.0):
    """The uprights with hooks at the head of a bench press bench (behind the head)."""
    for s in (1, -1):
        zz = z + s * z_half
        side = SIDE_RIGHT if s == 1 else SIDE_LEFT
        scene.line([vec(x, 0.03, zz), vec(x, height, zz)], TUBE, "frame", side=side)
        scene.line([vec(x, height - 0.03, zz), vec(x + 0.07, height - 0.03, zz), vec(x + 0.07, height + 0.03, zz)], 0.03, "frame", side=side)
        foot_bar(scene, x, half=0.12, z=zz)


# --- Bars and weights ---------------------------------------------------------------------------

def barbell(scene, center, axis=Z, plate_r=0.225, length=2.2, plates=1, sleeve=0.66, parts=8):
    """An Olympic bar centered on center, along axis, with plates of radius plate_r on each side."""
    axis = unit(axis)
    c = np.asarray(center, dtype=float)
    half = length / 2
    scene.segs(c - axis * sleeve, c + axis * sleeve, 0.03, "metal", parts=parts)
    for s in (1, -1):
        side = SIDE_RIGHT if s * axis[2] >= 0 else SIDE_LEFT
        scene.line([c + axis * s * sleeve, c + axis * s * half], 0.05, "metal", side=side)
        for k in range(plates):
            at = c + axis * s * (sleeve + 0.06 + k * 0.055)
            scene.disc(at, axis, plate_r, "load", side=side)
        scene.line([c + axis * s * (sleeve + 0.005), c + axis * s * (sleeve + 0.02)], 0.075, "metal", side=side)


def ez_bar(scene, center, axis=Z, plate_r=0.14, forward=X):
    """A curl bar: 1.2 m, with the cambered middle (angled grips)."""
    axis = unit(axis)
    forward = unit(forward - np.dot(forward, axis) * axis)
    c = np.asarray(center, dtype=float)
    k = 0.05
    pts = [c - axis * 0.42, c - axis * 0.28, c - axis * 0.2 + forward * k, c - axis * 0.1 - forward * k * 0.4,
           c + axis * 0.1 - forward * k * 0.4, c + axis * 0.2 + forward * k, c + axis * 0.28, c + axis * 0.42]
    for a, b in zip(pts[:-1], pts[1:]):
        scene.line([a, b], 0.028, "metal")
    for s in (1, -1):
        side = SIDE_RIGHT if s * axis[2] >= 0 else SIDE_LEFT
        scene.line([c + axis * s * 0.42, c + axis * s * 0.62], 0.045, "metal", side=side)
        scene.disc(c + axis * s * 0.48, axis, plate_r, "load", side=side)


def dumbbell(scene, grip, axis, head=0.06, handle=0.07, length=0.07, side=0):
    """A dumbbell held at grip, its handle along axis."""
    axis = unit(axis)
    g = np.asarray(grip, dtype=float)
    scene.line([g - axis * handle, g + axis * handle], 0.028, "metal", side=side)
    for s in (1, -1):
        a = g + axis * s * (handle + 0.004)
        b = g + axis * s * (handle + length)
        scene.line([a, b], head * 2, "load", side=side)


def kettlebell(scene, grip, down, axis, side=0, bell=0.1):
    """A kettlebell held by its handle at grip, the bell toward down."""
    down = unit(down)
    axis = unit(axis - np.dot(axis, down) * down)
    g = np.asarray(grip, dtype=float)
    center = g + down * 0.17
    a = g + axis * 0.065
    b = g - axis * 0.065
    scene.line([center + axis * 0.07 - down * 0.06, a + down * 0.02, a - down * 0.0, b - down * 0.0, b + down * 0.02,
                center - axis * 0.07 - down * 0.06], 0.026, "load", side=side)
    scene.ball(center, bell, "load", side=side)
    return center


def plate(scene, center, normal, r=0.225, side=0):
    scene.disc(center, normal, r, "load", side=side)


# --- Cable stations -----------------------------------------------------------------------------

class Column:
    """A cable column: the frame, the weight stack inside, and a pulley. The stack rises by how much
    cable is pulled out, so it moves with the handle."""

    def __init__(self, scene, x, z=0.0, height=2.15, depth=0.3, width=0.42, facing=1.0):
        self.scene = scene
        self.x, self.z = x, z
        self.height = height
        self.depth = depth
        self.width = width
        self.facing = facing  # +1: the person is toward +x of the column
        self.front_x = x + facing * depth / 2

    def frame(self, lift=0.0):
        s = self.scene
        x, z, d, w = self.x, self.z, self.depth / 2, self.width / 2
        for zz in (z - w, z + w):
            side = SIDE_RIGHT if zz > z else SIDE_LEFT
            s.line([vec(x - d, 0.03, zz), vec(x - d, self.height, zz)], TUBE, "frame", side=side)
            s.line([vec(x + d, 0.03, zz), vec(x + d, self.height, zz)], TUBE, "frame", side=side)
            s.line([vec(x - d, self.height, zz), vec(x + d, self.height, zz)], TUBE, "frame", side=side)
            s.line([vec(x - d - 0.08, 0.025, zz), vec(x + d + 0.08, 0.025, zz)], TUBE, "frame", side=side)
        s.line([vec(x - d, self.height, z - w), vec(x - d, self.height, z + w)], TUBE, "frame")
        # The stack: plates between the uprights, lifted by the pull.
        base = 0.1 + max(0.0, lift)
        s.box(vec(x, base + 0.16, z), X * 0.1, Y * 0.16, Z * 0.13, "load", stroke=0.01)
        s.line([vec(x, base + 0.32, z), vec(x, self.height - 0.06, z)], 0.012, "cable")


def pulley(scene, at, normal, r=0.045, side=0):
    scene.disc(at, normal, r, "frame", side=side)


def cable(scene, a, b, side=0):
    scene.line([a, b], 0.012, "cable", side=side)


def d_handle(scene, grip, axis, side=0):
    axis = unit(axis)
    scene.line([grip - axis * 0.06, grip + axis * 0.06], 0.03, "load", side=side)


def straight_handle(scene, center, axis, half=0.25, side=0):
    axis = unit(axis)
    scene.line([center - axis * half, center + axis * half], 0.028, "metal", side=side)


# --- Bars to hang from and to push on ------------------------------------------------------------

def pull_up_bar(scene, height=2.3, x=0.0, wall_x=-0.65, half=0.6):
    """A bar fixed to a wall behind the person by two brackets."""
    scene.segs(vec(x, height, -half), vec(x, height, half), 0.032, "metal", parts=6)
    for s in (1, -1):
        side = SIDE_RIGHT if s == 1 else SIDE_LEFT
        scene.line([vec(x, height, s * half), vec(wall_x, height + 0.12, s * half)], TUBE, "frame", side=side)
    scene.poly([vec(wall_x - 0.02, 1.2, -0.9), vec(wall_x - 0.02, 2.65, -0.9), vec(wall_x - 0.02, 2.65, 0.9),
                vec(wall_x - 0.02, 1.2, 0.9)], "floor", 0.0, bias=20.0)


def dip_station(scene, height=1.12, half_gap=0.27, x0=-0.32, x1=0.3, name="les barres"):
    for s in (1, -1):
        z = s * half_gap
        side = SIDE_RIGHT if s == 1 else SIDE_LEFT
        scene.line([vec(x0, height, z), vec(x1, height, z)], 0.04, "metal", side=side)
        for x in (x0 + 0.04, x1 - 0.04):
            scene.line([vec(x, height, z), vec(x, 0.03, z)], TUBE, "frame", side=side)
        scene.line([vec(x0 - 0.05, 0.025, z), vec(x1 + 0.05, 0.025, z)], TUBE, "frame", side=side)
