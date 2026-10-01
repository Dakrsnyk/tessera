"""Exercise demonstrations: a 3D stick figure with real proportions, the equipment it uses, and a
camera. Each exercise is a function of the movement phase p (0 = start, 1 = end); sampling it gives
frames the app interpolates and draws (same projection, same depth sort, same colors).

Units are meters. World axes: x forward (to the right in the profile view), y up, z toward the
figure's right side (toward the camera in the profile view).
"""
import math
import numpy as np

X = np.array([1.0, 0.0, 0.0])
Y = np.array([0.0, 1.0, 0.0])
Z = np.array([0.0, 0.0, 1.0])


def vec(x, y, z):
    return np.array([x, y, z], dtype=float)


def unit(a):
    n = float(np.linalg.norm(a))
    return a / n if n > 1e-12 else np.array(a, dtype=float)


def lerp(a, b, t):
    return a + (b - a) * t


def ease(t):
    t = min(1.0, max(0.0, t))
    return t * t * (3 - 2 * t)


def clamp(x, lo, hi):
    return max(lo, min(hi, x))


def rotation(axis, deg):
    axis = unit(np.asarray(axis, dtype=float))
    a = math.radians(deg)
    c, s = math.cos(a), math.sin(a)
    x, y, z = axis
    return np.array([
        [c + x * x * (1 - c), x * y * (1 - c) - z * s, x * z * (1 - c) + y * s],
        [y * x * (1 - c) + z * s, c + y * y * (1 - c), y * z * (1 - c) - x * s],
        [z * x * (1 - c) - y * s, z * y * (1 - c) + x * s, c + z * z * (1 - c)],
    ])


def rotate(v, axis, deg):
    return rotation(axis, deg) @ np.asarray(v, dtype=float)


def heading(deg):
    """Horizontal direction: 0 = +x, 90 = toward -z (the figure's left when it faces +x)."""
    return rotate(X, Y, deg)


def arc(center, start, axis, deg):
    """A point turned around an axis through center."""
    return center + rotate(start - center, axis, deg)


class Frame:
    """An orientation (forward f, up u, right r = f x u) at an origin."""

    def __init__(self, origin, f, u):
        self.o = np.asarray(origin, dtype=float)
        self.f = unit(np.asarray(f, dtype=float))
        u = np.asarray(u, dtype=float)
        self.u = unit(u - np.dot(u, self.f) * self.f)
        self.r = np.cross(self.f, self.u)

    def at(self, f=0.0, u=0.0, r=0.0):
        return self.o + self.f * f + self.u * u + self.r * r

    def dir(self, f=0.0, u=0.0, r=0.0):
        return unit(self.f * f + self.u * u + self.r * r)

    def turned(self, axis, deg, origin=None):
        R = rotation(axis, deg)
        return Frame(self.o if origin is None else origin, R @ self.f, R @ self.u)

    def pitched(self, deg):
        """Leans forward by deg (the up axis goes toward forward)."""
        return self.turned(self.r, -deg)

    def rolled(self, deg):
        """Leans toward the right side by deg."""
        return self.turned(self.f, deg)

    def yawed(self, deg):
        """Turns toward the left by deg."""
        return self.turned(self.u, deg)

    def moved(self, origin):
        return Frame(origin, self.f, self.u)


def posture(origin, facing=0.0, tilt=0.0, roll=0.0):
    """A frame facing a horizontal heading, then tilted forward (+) or back (-) by tilt degrees.
    tilt -90: lying on the back, head toward -facing. tilt 90: lying face down, head toward facing."""
    f = heading(facing)
    frame = Frame(origin, f, Y)
    if tilt:
        frame = frame.pitched(tilt)
    if roll:
        frame = frame.rolled(roll)
    return frame


def ik(root, target, a, b, pole):
    """Two bones from root toward target, bending toward pole. Returns (middle, end, shortfall)."""
    d = np.asarray(target, dtype=float) - root
    dist = float(np.linalg.norm(d))
    shortfall = max(0.0, dist - (a + b))
    direction = d / dist if dist > 1e-9 else unit(pole)
    dist_c = clamp(dist, abs(a - b) + 1e-4, (a + b) - 1e-6)
    cos_alpha = clamp((a * a + dist_c * dist_c - b * b) / (2 * a * dist_c), -1.0, 1.0)
    alpha = math.acos(cos_alpha)
    pole = np.asarray(pole, dtype=float)
    perp = pole - np.dot(pole, direction) * direction
    if np.linalg.norm(perp) < 1e-6:
        perp = np.cross(direction, Y if abs(direction[1]) < 0.9 else X)
    perp = unit(perp)
    middle = root + a * (math.cos(alpha) * direction + math.sin(alpha) * perp)
    end = root + direction * dist_c
    return middle, end, shortfall


# ---------------------------------------------------------------------------------------------
# Scene: what is drawn.

ROLES = ["ink", "muscle", "muscle2", "frame", "pad", "load", "cable", "floor", "mark", "metal"]
KIND_LINE, KIND_POLY, KIND_DISC, KIND_BALL = 0, 1, 2, 3
FLAG_CULL, FLAG_SHADE = 1, 2
SIDE_NONE, SIDE_RIGHT, SIDE_LEFT = 0, 1, 2


class Prim:
    __slots__ = ("kind", "role", "width", "bias", "side", "flags", "pts")

    def __init__(self, kind, role, pts, width=0.0, bias=0.0, side=0, flags=0):
        self.kind = kind
        self.role = role
        self.pts = [np.asarray(p, dtype=float) for p in pts]
        self.width = float(width)
        self.bias = float(bias)
        self.side = side
        self.flags = flags


class Solid:
    """A box the body must not go through (bench pads, seats, platforms)."""

    def __init__(self, center, ax, ay, az, name):
        self.c = np.asarray(center, dtype=float)
        self.axes = [np.asarray(a, dtype=float) for a in (ax, ay, az)]
        self.name = name

    def penetration(self, point, radius):
        """How deep a ball (point, radius) is inside the box (0 if outside)."""
        local = point - self.c
        depths = []
        for a in self.axes:
            half = float(np.linalg.norm(a))
            d = abs(float(np.dot(local, a / half)))
            depths.append(half + radius - d)
        return max(0.0, min(depths))


class Scene:
    def __init__(self):
        self.prims = []
        self.solids = []
        self.notes = []
        self.body = None
        self.ground = True

    # Drawing primitives -------------------------------------------------------------------
    def line(self, pts, width, role="frame", bias=0.0, side=0):
        self.prims.append(Prim(KIND_LINE, role, pts, width, bias, side))

    def segs(self, a, b, width, role="frame", parts=1, bias=0.0, side=0):
        """A straight bar split in parts so it sorts correctly against what it passes in front of."""
        a = np.asarray(a, dtype=float)
        b = np.asarray(b, dtype=float)
        for i in range(parts):
            self.line([lerp(a, b, i / parts), lerp(a, b, (i + 1) / parts)], width, role, bias, side)

    def poly(self, pts, role="pad", stroke=0.0, bias=0.0, side=0, cull=False, shade=False):
        flags = (FLAG_CULL if cull else 0) | (FLAG_SHADE if shade else 0)
        self.prims.append(Prim(KIND_POLY, role, pts, stroke, bias, side, flags))

    def disc(self, center, normal, radius, role="load", bias=0.0, side=0):
        center = np.asarray(center, dtype=float)
        self.prims.append(Prim(KIND_DISC, role, [center, center + unit(normal) * 0.1], radius, bias, side))

    def ball(self, center, radius, role="load", bias=0.0, side=0):
        self.prims.append(Prim(KIND_BALL, role, [center], radius, bias, side))

    def box(self, center, ax, ay, az, role="pad", stroke=0.012, solid=None, bias=0.0, side=0):
        """A box from its center and three half-extent vectors (right-handed). Six faces, the ones
        turned away from the camera skipped when drawn."""
        c = np.asarray(center, dtype=float)
        ax, ay, az = (np.asarray(a, dtype=float) for a in (ax, ay, az))
        if np.dot(np.cross(ax, ay), az) < 0:
            az = -az
        corner = lambda i, j, k: c + ax * i + ay * j + az * k
        faces = [
            [corner(1, -1, -1), corner(1, 1, -1), corner(1, 1, 1), corner(1, -1, 1)],      # +x
            [corner(-1, -1, -1), corner(-1, -1, 1), corner(-1, 1, 1), corner(-1, 1, -1)],  # -x
            [corner(-1, 1, -1), corner(-1, 1, 1), corner(1, 1, 1), corner(1, 1, -1)],      # +y
            [corner(-1, -1, -1), corner(1, -1, -1), corner(1, -1, 1), corner(-1, -1, 1)],  # -y
            [corner(-1, -1, 1), corner(1, -1, 1), corner(1, 1, 1), corner(-1, 1, 1)],      # +z
            [corner(-1, -1, -1), corner(-1, 1, -1), corner(1, 1, -1), corner(1, -1, -1)],  # -z
        ]
        for face in faces:
            self.poly(face, role, stroke, bias, side, cull=True, shade=True)
        if solid:
            self.solids.append(Solid(c, ax, ay, az, solid))

    def slab(self, a, b, up, width, thickness, role="pad", solid=None, stroke=0.014, bias=0.0, side=0):
        """A pad from a to b (along its length), its top facing up, of a width and thickness.
        a and b are on the top surface, in the middle of its width."""
        a = np.asarray(a, dtype=float)
        b = np.asarray(b, dtype=float)
        length_dir = unit(b - a)
        up = unit(np.asarray(up, dtype=float) - np.dot(up, length_dir) * length_dir)
        across = np.cross(length_dir, up)
        center = (a + b) / 2 - up * thickness / 2
        self.box(center, length_dir * (np.linalg.norm(b - a) / 2), up * thickness / 2, across * width / 2,
                 role, stroke, solid, bias, side)

    def tube(self, pts, width=0.035, role="frame", bias=0.0, side=0):
        self.line(pts, width, role, bias, side)

    def note(self, text):
        self.notes.append(text)


# ---------------------------------------------------------------------------------------------
# The body.

MUSCLE_KEYS = ["chest", "back", "traps", "lowerBack", "shoulders", "biceps", "triceps", "forearms",
               "quads", "hamstrings", "glutes", "calves", "abs", "obliques"]


class Body:
    UPPER = 0.30
    LOWER = 0.34     # elbow to the middle of the grip
    THIGH = 0.44
    SHIN = 0.44
    ANKLE = 0.08     # ankle height when standing
    LUMBAR = 0.17
    THORAX = 0.40
    NECK = 0.165
    HEAD = 0.10
    SH_HALF = 0.175
    SH_DROP = 0.05
    HIP_HALF = 0.09

    W_TORSO = 0.105
    W_NECK = 0.06
    W_UPPER = 0.072
    W_LOWER = 0.062
    W_THIGH = 0.092
    W_SHIN = 0.074
    W_FOOT = 0.052

    def __init__(self, pelvis, spine=0.0, twist=0.0, bend=0.0, head=0.0, shrug=0.0, protract=0.0,
                 head_turn=0.0, lumbar=None):
        """pelvis: Frame at the middle of the hip joints. spine: forward flexion of the chest at the
        waist (degrees, negative = extension). twist: chest turned to the left. bend: chest leaned to
        the right. head: chin down (+) or up (-)."""
        self.pelvis = pelvis
        self.waist = pelvis.at(u=self.LUMBAR)
        chest = Frame(self.waist, pelvis.f, pelvis.u)
        if spine:
            chest = chest.pitched(spine)
        if twist:
            chest = chest.yawed(twist)
        if bend:
            chest = chest.rolled(bend)
        self.chest = chest
        self.neck = chest.at(u=self.THORAX)
        top = chest.at(u=self.THORAX - self.SH_DROP + shrug, f=protract)
        self.shoulder = {1: top + chest.r * self.SH_HALF, -1: top - chest.r * self.SH_HALF}
        head_frame = chest.pitched(head)
        if head_turn:
            head_frame = head_frame.yawed(head_turn)
        self.head_frame = head_frame
        self.head = self.neck + head_frame.u * self.NECK
        self.hip = {1: pelvis.at(r=self.HIP_HALF), -1: pelvis.at(r=-self.HIP_HALF)}
        self.elbow, self.grip, self.knee, self.ankle, self.toe = {}, {}, {}, {}, {}
        self.shortfall = {}
        self.planted = {}

    # Arms -------------------------------------------------------------------------------------
    def arm(self, side, target, pole):
        e, g, short = ik(self.shoulder[side], target, self.UPPER, self.LOWER, pole)
        self.elbow[side], self.grip[side] = e, g
        self.shortfall[("arm", side)] = short
        return g

    def arm_via(self, side, target, elbow_hint):
        """Arm to target with the elbow placed as close as possible to elbow_hint."""
        target = np.asarray(target, dtype=float)
        pole = np.asarray(elbow_hint, dtype=float) - (self.shoulder[side] + target) / 2
        return self.arm(side, target, unit(pole))

    def arms(self, right, left, pole_right, pole_left=None):
        if pole_left is None:
            pole_left = self.mirror_dir(pole_right)
        self.arm(1, right, pole_right)
        self.arm(-1, left, pole_left)

    def arm_dirs(self, side, upper_dir, lower_dir):
        """Arm placed by bone directions (no target)."""
        e = self.shoulder[side] + unit(upper_dir) * self.UPPER
        self.elbow[side] = e
        self.grip[side] = e + unit(lower_dir) * self.LOWER
        self.shortfall[("arm", side)] = 0.0
        return self.grip[side]

    def mirror_dir(self, d):
        """The same direction for the other side of the body (mirrored across the chest's midplane)."""
        r = self.chest.r
        d = np.asarray(d, dtype=float)
        return d - 2 * np.dot(d, r) * r

    def mirror_point(self, p, frame=None):
        frame = frame or self.chest
        p = np.asarray(p, dtype=float)
        return p - 2 * np.dot(p - frame.o, frame.r) * frame.r

    # Legs -------------------------------------------------------------------------------------
    def leg(self, side, ankle_target, pole=None):
        if pole is None:
            pole = self.pelvis.f
        k, a, short = ik(self.hip[side], ankle_target, self.THIGH, self.SHIN, pole)
        self.knee[side], self.ankle[side] = k, a
        self.shortfall[("leg", side)] = short
        return a

    def leg_dirs(self, side, thigh_dir, shin_dir):
        k = self.hip[side] + unit(thigh_dir) * self.THIGH
        self.knee[side] = k
        self.ankle[side] = k + unit(shin_dir) * self.SHIN
        self.shortfall[("leg", side)] = 0.0
        return self.ankle[side]

    def stand_foot(self, side, toe, facing=0.0, raise_deg=0.0, toe_height=0.02):
        """Foot on the ground (or a step) by its toe; raise_deg lifts the heel. Sets the leg.
        Returns the ankle."""
        h = heading(facing)
        toe = np.asarray(toe, dtype=float).copy()
        toe[1] = toe[1] if toe_height is None else toe[1]
        back = -h * 0.165 + Y * 0.06
        lateral = np.cross(h, Y)
        back = rotate(back, lateral, -raise_deg)
        ankle = toe + back
        self.toe[side] = toe
        self.planted[side] = True
        return ankle

    def foot_on_floor(self, side, ankle_xz, facing=0.0, floor=0.0, pole=None):
        """Flat foot: ankle above the floor, toe in front of it."""
        h = heading(facing)
        ankle = vec(ankle_xz[0], floor + self.ANKLE, ankle_xz[1])
        self.toe[side] = ankle + h * 0.165 - Y * 0.06
        self.planted[side] = True
        self.leg(side, ankle, pole)
        return ankle

    def foot_relaxed(self, side, plantar=0.0):
        """Foot following the shin: toe in front of the shin, pointed by plantar degrees."""
        shin = unit(self.ankle[side] - self.knee[side])
        lateral = self.pelvis.r
        anterior = unit(np.cross(lateral, shin))
        toe_dir = unit(anterior * 0.165 + shin * 0.06)
        toe_dir = rotate(toe_dir, lateral, -plantar)
        self.toe[side] = self.ankle[side] + toe_dir * 0.176
        return self.toe[side]

    def foot_toward(self, side, toe):
        self.toe[side] = np.asarray(toe, dtype=float)

    # Drawing --------------------------------------------------------------------------------
    def emit(self, scene, primary=(), secondary=()):
        scene.body = self
        ink = "ink"
        c = self.chest
        p = self.pelvis
        hips = [p.at(r=0.115, u=-0.01), p.at(r=-0.115, u=-0.01)]
        waist = [c.o + c.r * 0.12, c.o - c.r * 0.12]
        shoulders = [self.shoulder[1], self.shoulder[-1]]
        torso = [hips[0], waist[0], shoulders[0], shoulders[1], waist[1], hips[1]]
        scene.poly(torso, ink, stroke=self.W_TORSO, bias=-0.002)
        # Neck and head.
        head_base = self.head - self.head_frame.u * self.HEAD * 0.9
        scene.line([self.neck, head_base], self.W_NECK, ink)
        scene.ball(self.head, self.HEAD, ink, bias=-0.004)
        roles = {}
        for m in secondary:
            roles[m] = "muscle2"
        for m in primary:
            roles[m] = "muscle"
        for side in (1, -1):
            flag = SIDE_RIGHT if side == 1 else SIDE_LEFT
            if side in self.elbow:
                scene.line([self.shoulder[side], self.elbow[side]], self.W_UPPER, ink, side=flag)
                scene.line([self.elbow[side], self.grip[side]], self.W_LOWER, roles.get("forearms", ink), side=flag)
            if side in self.knee:
                scene.line([self.hip[side], self.knee[side]], self.W_THIGH, ink, side=flag)
                scene.line([self.knee[side], self.ankle[side]], self.W_SHIN, ink, side=flag)
                if side in self.toe:
                    scene.line([self.ankle[side], self.toe[side]], self.W_FOOT, ink, side=flag)
        self.emit_muscles(scene, roles)

    def emit_muscles(self, scene, roles):
        c = self.chest
        p = self.pelvis
        w = 0.05
        off = 0.024

        def strip(a, b, normal, role, side=0, width=w, bias=-0.006):
            n = unit(normal) * off
            scene.line([a + n, b + n], width, role, bias=bias, side=side)

        for key, role in roles.items():
            if key == "chest":
                for s in (1, -1):
                    a = c.at(u=0.17, r=0.07 * s)
                    b = c.at(u=0.34, r=0.10 * s)
                    strip(a, b, c.f, role, SIDE_RIGHT if s == 1 else SIDE_LEFT, width=0.075)
            elif key == "back":
                for s in (1, -1):
                    a = c.at(u=0.06, r=0.08 * s)
                    b = c.at(u=0.32, r=0.12 * s)
                    strip(a, b, -c.f, role, SIDE_RIGHT if s == 1 else SIDE_LEFT, width=0.07)
            elif key == "traps":
                for s in (1, -1):
                    a = self.neck - c.u * 0.01
                    b = self.shoulder[s] + c.u * 0.015
                    strip(a, b, -c.f, role, SIDE_RIGHT if s == 1 else SIDE_LEFT, width=0.045)
            elif key == "lowerBack":
                strip(p.at(u=0.05), c.at(u=0.12), -c.f * 0.5 - p.f * 0.5, role, width=0.06)
            elif key == "abs":
                strip(p.at(u=0.06), c.at(u=0.2), c.f * 0.5 + p.f * 0.5, role, width=0.07)
            elif key == "obliques":
                for s in (1, -1):
                    strip(p.at(u=0.06, r=0.1 * s), c.at(u=0.16, r=0.12 * s), c.r * s, role,
                          SIDE_RIGHT if s == 1 else SIDE_LEFT, width=0.045)
            elif key == "glutes":
                for s in (1, -1):
                    if s in self.knee:
                        thigh = unit(self.knee[s] - self.hip[s])
                        a = self.hip[s] + p.u * 0.03
                        b = self.hip[s] + thigh * 0.12
                        strip(a, b, -p.f, role, SIDE_RIGHT if s == 1 else SIDE_LEFT, width=0.075)
            elif key == "shoulders":
                for s in (1, -1):
                    scene.ball(self.shoulder[s], 0.058, role, bias=-0.007, side=SIDE_RIGHT if s == 1 else SIDE_LEFT)
            elif key in ("biceps", "triceps"):
                for s in (1, -1):
                    if s not in self.elbow:
                        continue
                    sh, el = self.shoulder[s], self.elbow[s]
                    arm = unit(el - sh)
                    fore = unit(self.grip[s] - el)
                    bend = fore - np.dot(fore, arm) * arm
                    if np.linalg.norm(bend) > 0.08:
                        front = unit(bend)
                    else:
                        front = unit(np.cross(c.r, arm)) if np.linalg.norm(np.cross(c.r, arm)) > 0.2 else c.f
                    normal = front if key == "biceps" else -front
                    a = lerp(sh, el, 0.2)
                    b = lerp(sh, el, 0.85)
                    strip(a, b, normal, role, SIDE_RIGHT if s == 1 else SIDE_LEFT, width=0.05)
            elif key in ("quads", "hamstrings", "calves"):
                for s in (1, -1):
                    if s not in self.knee:
                        continue
                    hip, knee, ankle = self.hip[s], self.knee[s], self.ankle[s]
                    thigh = unit(knee - hip)
                    shin = unit(ankle - knee)
                    lateral = p.r
                    thigh_front = unit(np.cross(lateral, thigh))
                    shin_front = unit(np.cross(lateral, shin))
                    flag = SIDE_RIGHT if s == 1 else SIDE_LEFT
                    if key == "quads":
                        strip(lerp(hip, knee, 0.15), lerp(hip, knee, 0.85), thigh_front, role, flag, width=0.06)
                    elif key == "hamstrings":
                        strip(lerp(hip, knee, 0.2), lerp(hip, knee, 0.88), -thigh_front, role, flag, width=0.06)
                    else:
                        strip(lerp(knee, ankle, 0.12), lerp(knee, ankle, 0.55), -shin_front, role, flag, width=0.055)

    def joints(self):
        pts = [self.pelvis.o, self.waist, self.neck, self.head]
        for d in (self.shoulder, self.elbow, self.grip, self.hip, self.knee, self.ankle, self.toe):
            pts += list(d.values())
        return pts


# ---------------------------------------------------------------------------------------------
# Camera.

class View:
    def __init__(self, name, yaw, pitch=8.0):
        self.name = name
        self.yaw = yaw
        self.pitch = pitch

    def basis(self):
        y = math.radians(self.yaw)
        p = math.radians(self.pitch)
        R = np.array([math.cos(y), 0.0, -math.sin(y)])
        B = np.array([math.sin(y), 0.0, math.cos(y)])
        U = np.array([0.0, 1.0, 0.0])
        U2 = U * math.cos(p) - B * math.sin(p)
        B2 = B * math.cos(p) + U * math.sin(p)
        return R, U2, B2

    def project(self, pts):
        R, U, B = self.basis()
        P = np.asarray(pts)
        return np.stack([P @ R, P @ U, -(P @ B)], axis=-1)


PROFILE = lambda pitch=6.0: View("Profil", 0.0, pitch)
FRONT = lambda pitch=6.0: View("Face", 90.0, pitch)
BACK = lambda pitch=6.0: View("Dos", -90.0, pitch)
THREE_QUARTER = lambda yaw=40.0, pitch=14.0: View("3/4", yaw, pitch)
ABOVE = lambda yaw=90.0, pitch=62.0: View("Dessus", yaw, pitch)
