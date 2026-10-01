"""Common ways of placing the body on the equipment: lying on a bench, leaning on a backrest, seated,
standing, in a plank. Each returns a Body whose outline touches the surface it rests on."""
import math

import numpy as np

from engine import Body, Frame, X, Y, Z, heading, lerp, posture, rotate, unit, vec

GAP = 0.004


def torso_offset():
    return Body.W_TORSO / 2 + GAP


def on_backrest(junction, back_dir, back_normal, seat_y, z=0.0, slide=0.0, **body_args):
    """Seated on a seat whose back end is junction, the back against a backrest going along back_dir.
    The thighs rest on the seat (the hip joint above it by half a thigh)."""
    off = torso_offset()
    hip_y = seat_y + Body.W_THIGH / 2 + GAP
    base = junction + back_normal * off
    s = (hip_y - base[1]) / back_dir[1] if abs(back_dir[1]) > 1e-6 else 0.0
    s = max(s, 0.0) + slide
    origin = base + back_dir * s
    origin[2] = z
    pelvis = Frame(origin, back_normal, back_dir)
    return Body(pelvis, **body_args)


def on_surface(point, along, normal, z=0.0, **body_args):
    """Lying with the back on a surface through point: the torso along `along` (toward the head),
    the face toward `normal`, the pelvis at point."""
    origin = np.asarray(point, dtype=float) + unit(normal) * torso_offset()
    origin[2] = z
    return Body(Frame(origin, normal, along), **body_args)


def lying_on_back(pad_top, pelvis_x, head_toward=-1.0, z=0.0, **body_args):
    """Lying face up on a flat surface at height pad_top, the head toward -x (head_toward=-1) or +x."""
    origin = vec(pelvis_x, pad_top + torso_offset(), z)
    pelvis = Frame(origin, Y, X * head_toward)
    return Body(pelvis, **body_args)


def lying_on_front(pad_top, pelvis_x, head_toward=1.0, z=0.0, **body_args):
    origin = vec(pelvis_x, pad_top + torso_offset(), z)
    pelvis = Frame(origin, -Y, X * head_toward)
    return Body(pelvis, **body_args)


def seated_upright(seat_top, hip_x, z=0.0, lean=0.0, facing=0.0, **body_args):
    """Sitting on a seat at seat_top, the hip joint above it; lean > 0 leans forward."""
    origin = vec(hip_x, seat_top + Body.W_THIGH / 2 + GAP, z)
    pelvis = posture(origin, facing, lean)
    return Body(pelvis, **body_args)


def standing(x=0.0, z=0.0, hip_height=None, facing=0.0, lean=0.0, **body_args):
    h = hip_height if hip_height is not None else Body.ANKLE + Body.SHIN + Body.THIGH - 0.005
    pelvis = posture(vec(x, h, z), facing, lean)
    return Body(pelvis, **body_args)


def placed(frame, anchor="shoulders", at=None, **body_args):
    """A body oriented like frame, moved so that its anchor (shoulders, neck, head or pelvis) is at `at`."""
    probe = Body(Frame(vec(0, 0, 0), frame.f, frame.u), **body_args)
    if anchor == "shoulders":
        point = (probe.shoulder[1] + probe.shoulder[-1]) / 2
    elif anchor == "neck":
        point = probe.neck
    elif anchor == "head":
        point = probe.head
    else:
        point = probe.pelvis.o
    origin = np.asarray(at, dtype=float) - point
    return Body(Frame(origin, frame.f, frame.u), **body_args)


def feet_flat(body, right_xz, left_xz, facing=0.0, floor=0.0, pole=None):
    body.foot_on_floor(1, right_xz, facing, floor, pole)
    body.foot_on_floor(-1, left_xz, facing, floor, pole)


def stance(body, x, half_width=0.13, facing=0.0, toe_out=8.0, floor=0.0, pole=None, z=0.0):
    """Both feet flat, side by side at x, half_width from the middle, toes turned out a little."""
    for s in (1, -1):
        h = facing + (-toe_out if s == 1 else toe_out)
        lateral = np.cross(heading(facing), Y)
        p = vec(x, 0, z) + lateral * s * half_width
        knee_pole = pole if pole is not None else heading(h)
        body.foot_on_floor(s, (p[0], p[2]), h, floor, knee_pole)


def solve(f, lo, hi, target, steps=60):
    """x in [lo, hi] with f(x) = target (f monotonic)."""
    flo = f(lo) - target
    for _ in range(steps):
        mid = (lo + hi) / 2
        fm = f(mid) - target
        if (fm > 0) == (flo > 0):
            lo, flo = mid, fm
        else:
            hi = mid
    return (lo + hi) / 2


def plank_on_toes(theta, toe_x=0.0, foot_half=0.09, **body_args):
    """Face down, straight from the heels to the head, the body line rising toward the head by theta
    degrees, the toes on the floor at toe_x (head toward +x)."""
    frame = posture(vec(0, 0, 0), 0.0, 90.0 - theta)
    toe = vec(toe_x, 0.02, 0.0)
    ankle = toe - frame.f * 0.165 + frame.u * 0.06
    pelvis = ankle + frame.u * (Body.SHIN + Body.THIGH)
    body = Body(Frame(pelvis, frame.f, frame.u), **body_args)
    for s in (1, -1):
        body.leg_dirs(s, -frame.u, -frame.u)
        body.foot_toward(s, body.ankle[s] + frame.f * 0.165 - frame.u * 0.06)
    return body


def plank_on_knees(theta, knee_x=0.0, shin_up=45.0, **body_args):
    """Face down, straight from the knees to the head (knees on the floor), shins lifted by shin_up."""
    frame = posture(vec(0, 0, 0), 0.0, 90.0 - theta)
    knee = vec(knee_x, Body.W_SHIN / 2 + 0.005, 0.0)
    pelvis = knee + frame.u * Body.THIGH
    body = Body(Frame(pelvis, frame.f, frame.u), **body_args)
    shin = rotate(-X, Z, -shin_up)  # back and up
    for s in (1, -1):
        body.leg_dirs(s, -frame.u, shin)
        body.foot_relaxed(s, plantar=40)
    return body


def upright(hip_y, lean=0.0, shoulder_x=None, pelvis_x=0.0, z=0.0, facing=0.0, **body_args):
    """Standing (or hinged) with the hip joints at hip_y and the torso leaning forward by lean degrees.
    If shoulder_x is given, the body is moved so the shoulders are above it (balance over the feet)."""
    frame = posture(vec(0, 0, 0), facing, lean)
    probe = Body(Frame(vec(pelvis_x, hip_y, z), frame.f, frame.u), **body_args)
    if shoulder_x is not None:
        mid = (probe.shoulder[1] + probe.shoulder[-1]) / 2
        dx = shoulder_x - mid[0]
        return Body(Frame(vec(pelvis_x + dx, hip_y, z), frame.f, frame.u), **body_args)
    return probe


def hang_arms(body, out=0.0, forward=0.0, bend=0.02, pole=None):
    """Arms hanging from the shoulders (nearly straight), optionally a little forward or out."""
    for s in (1, -1):
        sh = body.shoulder[s]
        d = unit(-Y + X * forward + body.chest.r * s * out)
        grip = sh + d * (Body.UPPER + Body.LOWER - bend)
        body.arm(s, grip, pole if pole is not None else unit(-X + Y * 0.0))
    return body


def floor_marks(scene, offset, spacing=0.5, x0=-1.5, x1=1.5, z=0.0, half=0.5):
    """Short marks on the floor, shifted by offset (to show travel while the figure stays centered)."""
    start = math.floor((x0 - offset) / spacing) * spacing + offset
    xs = []
    x = start
    while x <= x1 + 1e-9:
        xs.append(x)
        x += spacing
    return xs
