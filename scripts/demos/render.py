"""Draws an exported demonstration exactly as the app will (same interpolation, projection, depth
sort, shading and colors), as SVG, for review sheets and animated previews."""
import base64
import math

import numpy as np

from engine import ROLES, View

LIGHT = {
    "bg": "#F3F3F5", "ink": "#1E2127", "muscle": "#E5484D", "frame": "#B3B8C2", "pad": "#80869299",
    "load": "#4C525E", "cable": "#8E95A1", "floor": "#E4E5E9", "mark": "#CDD0D6", "metal": "#8A909C",
}
DARK = {
    "bg": "#16171A", "ink": "#F1F2F4", "muscle": "#FF6369", "frame": "#555B66", "pad": "#6B717C",
    "load": "#A3A9B4", "cable": "#7C838F", "floor": "#232529", "mark": "#30333A", "metal": "#7B828E",
}


def hex_rgb(h):
    h = h.lstrip("#")[:6]
    return np.array([int(h[i:i + 2], 16) for i in (0, 2, 4)], dtype=float)


def rgb_hex(c):
    c = np.clip(np.round(c), 0, 255).astype(int)
    return "#%02X%02X%02X" % tuple(c)


def mix(a, b, t):
    return a + (b - a) * t


def role_color(role, palette):
    bg = hex_rgb(palette["bg"])
    if role == "muscle2":
        return mix(hex_rgb(palette["muscle"]), bg, 0.5)
    if role == "pad":
        return hex_rgb(palette["pad"])
    return hex_rgb(palette[role])


def decode(b64, count):
    if not b64:
        return np.zeros((0,))
    raw = base64.b64decode(b64)
    return np.frombuffer(raw, dtype="<i2").astype(float)[:count] / 1000.0


class Player:
    def __init__(self, data):
        self.d = data
        S, D = data["points"]
        self.S, self.D, self.n = S, D, data["n"]
        self.static = decode(data["static"], S * 3).reshape(S, 3) if S else np.zeros((0, 3))
        self.dynamic = decode(data["dynamic"], self.n * D * 3).reshape(self.n, D, 3) if D else np.zeros((self.n, 0, 3))
        self.duration = sum(seg[0] for seg in data["timeline"])

    def phase_at(self, t):
        """(p, label index) at t seconds into the loop."""
        t = t % self.duration
        for dur, a, b, label, eased in self.d["timeline"]:
            if t <= dur or dur == 0:
                local = t / dur if dur > 0 else 1.0
                s = local * local * (3 - 2 * local) if eased else local
                return a + (b - a) * s, label
            t -= dur
        seg = self.d["timeline"][-1]
        return seg[2], seg[3]

    def points(self, p):
        n = self.n
        if self.D == 0:
            return self.static
        if self.d["loop"]:
            u = (p % 1.0) * n
            i = int(math.floor(u)) % n
            f = u - math.floor(u)
            idx = [(i - 1) % n, i, (i + 1) % n, (i + 2) % n]
        else:
            u = min(max(p, 0.0), 1.0) * (n - 1)
            i = min(int(math.floor(u)), n - 2)
            f = u - i
            idx = [max(i - 1, 0), i, i + 1, min(i + 2, n - 1)]
        P0, P1, P2, P3 = (self.dynamic[k] for k in idx)
        f2, f3 = f * f, f * f * f
        dyn = 0.5 * ((2 * P1) + (-P0 + P2) * f + (2 * P0 - 5 * P1 + 4 * P2 - P3) * f2 + (-P0 + 3 * P1 - 3 * P2 + P3) * f3)
        return np.concatenate([self.static, dyn], axis=0)

    def svg(self, p, view_index=0, W=360, H=240, palette=LIGHT, margin=14, background=True, box=None):
        v = self.d["views"][view_index]
        view = View(v["name"], v["yaw"], v["pitch"])
        pts = self.points(p)
        proj = view.project(pts)
        minx, miny, maxx, maxy = box or v["box"]
        w, h = maxx - minx, maxy - miny
        scale = min((W - 2 * margin) / w, (H - 2 * margin) / h, (H - 2 * margin) / 1.75)
        cx, cy = (minx + maxx) / 2, (miny + maxy) / 2

        def sx(x):
            return W / 2 + (x - cx) * scale

        def sy(y):
            return H / 2 - (y - cy) * scale

        bg = hex_rgb(palette["bg"])
        R, U, B = view.basis()
        # Which side of the body is farther: the left (f > 0) or the right (f < 0).
        side_factor = 0.0
        sh = self.d.get("shoulders") or []
        if len(sh) == 2 and sh[0] >= 0 and sh[1] >= 0:
            side_factor = max(-1.0, min(1.0, (proj[sh[1], 2] - proj[sh[0], 2]) / 0.35))
        light = np.array([0.35, 1.0, 0.45])
        light = light / np.linalg.norm(light)
        items = []
        for order, prim in enumerate(self.d["prims"]):
            kind, role_i, width, bias, side, flags = prim[:6]
            idx = prim[6:]
            role = ROLES[role_i]
            P = proj[idx]
            depth = float(P[:, 2].mean()) + bias / 1000.0
            if kind == 2:
                depth = float(P[0, 2]) + bias / 1000.0
            color = role_color(role, palette)
            if flags & 1:  # cull faces turned away
                xs, ys = P[:, 0], P[:, 1]
                area = 0.5 * float(np.sum(xs * np.roll(ys, -1) - np.roll(xs, -1) * ys))
                if area <= 1e-6:
                    continue
            if flags & 2:  # light the faces of boxes
                W3 = pts[idx]
                normal = np.cross(W3[1] - W3[0], W3[2] - W3[0])
                nn = np.linalg.norm(normal)
                if nn > 1e-9:
                    lit = float(np.dot(normal / nn, light))
                    color = mix(color, np.array([255.0, 255, 255]), 0.22 * lit) if lit > 0 else mix(color, np.zeros(3), 0.16 * -lit)
            fade = 0.0
            if side == 1:
                fade = max(0.0, -side_factor) * 0.55
            elif side == 2:
                fade = max(0.0, side_factor) * 0.55
            if fade:
                color = mix(color, bg, fade)
            items.append((depth, order, kind, color, width / 1000.0, P))
        marks = self.d.get("marks") or []
        if marks:
            travel, spacing, x0, x1, z0, z1, my, mbias = marks[:8]
            slope = marks[8] if len(marks) > 8 else 0.0
            offset = (p * travel) % spacing
            x = math.ceil(x0 / spacing) * spacing - offset
            while x <= x1 + 1e-9:
                if x >= x0 - 1e-9:
                    yy = my + slope * x
                    seg = view.project(np.array([[x, yy, z0], [x, yy, z1]]))
                    items.append((float(seg[:, 2].mean()) + mbias, -1, 0, role_color("mark", palette), 0.03, seg))
                x += spacing
        items.sort(key=lambda it: (-it[0], it[1]))
        out = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" viewBox="0 0 {W} {H}">']
        if background:
            out.append(f'<rect width="{W}" height="{H}" rx="18" fill="{palette["bg"]}"/>')
        for depth, order, kind, color, width, P in items:
            col = rgb_hex(color)
            if kind == 0:
                d = " ".join(("M" if i == 0 else "L") + f"{sx(x):.2f},{sy(y):.2f}" for i, (x, y, _) in enumerate(P))
                out.append(f'<path d="{d}" fill="none" stroke="{col}" stroke-width="{width * scale:.2f}" stroke-linecap="round" stroke-linejoin="round"/>')
            elif kind == 1:
                d = " ".join(("M" if i == 0 else "L") + f"{sx(x):.2f},{sy(y):.2f}" for i, (x, y, _) in enumerate(P)) + " Z"
                stroke = f' stroke="{col}" stroke-width="{width * scale:.2f}" stroke-linejoin="round"' if width > 0 else ""
                out.append(f'<path d="{d}" fill="{col}"{stroke}/>')
            elif kind == 3:
                out.append(f'<circle cx="{sx(P[0][0]):.2f}" cy="{sy(P[0][1]):.2f}" r="{width * scale:.2f}" fill="{col}"/>')
            elif kind == 2:
                c = P[0]
                axis_world = pts[self.d["prims"][order][7]] - pts[self.d["prims"][order][6]]
                half = float(np.linalg.norm(axis_world))
                nvec = axis_world / half if half > 1e-9 else np.array([0, 0, 1.0])
                nr, nu, nb = float(nvec @ R), float(nvec @ U), float(nvec @ B)
                r = width
                minor = r * abs(nb) + half * math.sqrt(max(0.0, 1 - nb * nb))
                ang = math.degrees(math.atan2(-nu, nr))  # screen y is down
                ring = max(0.016, min(0.03, r * 0.16)) * scale
                out.append(f'<ellipse cx="{sx(c[0]):.2f}" cy="{sy(c[1]):.2f}" rx="{max(minor * scale - ring / 2, 0.5):.2f}" ry="{max(r * scale - ring / 2, 0.5):.2f}" '
                           f'transform="rotate({ang:.2f} {sx(c[0]):.2f} {sy(c[1]):.2f})" fill="{col}" fill-opacity="0.38" stroke="{col}" stroke-width="{ring:.2f}"/>')
        out.append("</svg>")
        return "\n".join(out)
