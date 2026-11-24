"""20 character styles proposed for the exercise demonstrations (CEO, 2026-11-23: « propose moi plusieurs maquettes,
20 personnages… plusieurs styles ou shape »). The same exported poses (a dumbbell curl, the chest anatomy figure), drawn
by 20 renderers. Only a review sheet: nothing changes in the app until a style is chosen.

    ~/ardane-tools/venv/Scripts/python.exe scripts/demos/style_sheet.py   # writes out/styles.html (photographed apart)
"""
import json
import math
from pathlib import Path

import numpy as np

from engine import ROLES, View
from render import DARK, Player, hex_rgb, mix, rgb_hex, role_color

ROOT = Path(__file__).resolve().parents[2]
DEMOS = json.loads((ROOT / "App" / "Resources" / "ExerciseDemos.json").read_text(encoding="utf-8"))["demos"]


def items_for(data, p, W, H, margin=10, palette=DARK):
    """The drawn primitives of a demonstration at p, in screen space, back to front (same projection and sort as the app)."""
    pl = Player(data)
    v = data["views"][0]
    view = View(v["name"], v["yaw"], v["pitch"])
    pts = pl.points(p)
    proj = view.project(pts)
    minx, miny, maxx, maxy = v["box"]
    w, h = maxx - minx, maxy - miny
    scale = min((W - 2 * margin) / w, (H - 2 * margin) / h)
    if not v.get("close"):
        scale = min(scale, (H - 2 * margin) / 1.75)
    cx, cy = (minx + maxx) / 2, (miny + maxy) / 2
    out = []
    for order, prim in enumerate(data["prims"]):
        kind, role_i, width, bias, side, flags = prim[:6]
        idx = prim[6:]
        P = proj[idx]
        if flags & 1:
            xs, ys = P[:, 0], P[:, 1]
            if 0.5 * float(np.sum(xs * np.roll(ys, -1) - np.roll(xs, -1) * ys)) <= 1e-6:
                continue
        depth = (float(P[0, 2]) if kind == 2 else float(P[:, 2].mean())) + bias / 1000.0
        S = [(W / 2 + (x - cx) * scale, H / 2 - (y - cy) * scale) for x, y, _ in P]
        out.append(dict(depth=depth, order=order, kind=kind, role=ROLES[role_i], w=width / 1000.0 * scale, pts=S, side=side))
    out.sort(key=lambda it: (-it["depth"], it["order"]))
    return out, scale


def path(pts, close=False):
    d = " ".join(("M" if i == 0 else "L") + f"{x:.1f},{y:.1f}" for i, (x, y) in enumerate(pts))
    return d + (" Z" if close else "")


def taper(a, b, wa, wb):
    (x0, y0), (x1, y1) = a, b
    dx, dy = x1 - x0, y1 - y0
    n = math.hypot(dx, dy) or 1
    nx, ny = -dy / n, dx / n
    return [(x0 + nx * wa / 2, y0 + ny * wa / 2), (x1 + nx * wb / 2, y1 + ny * wb / 2),
            (x1 - nx * wb / 2, y1 - ny * wb / 2), (x0 - nx * wa / 2, y0 - ny * wa / 2)]


# A style: background, colours by role, and how each primitive is drawn.
def style(bg, body, muscle, gear="#7B828E", floor="#232529", **kw):
    return dict(bg=bg, body=body, muscle=muscle, gear=gear, floor=floor, **kw)


STYLES = [
    ("Actuel", style("#16171A", "#F1F2F4", "#FF6369")),
    ("Trait fin", style("#111214", "#F1F2F4", "#FF5A5F", widthk=0.38, torso="outline", head="ring")),
    ("Capsules", style("#15161A", "#E9EAEE", "#FF5A5F", widthk=1.55)),
    ("Mannequin articulé", style("#1A1814", "#D9B98C", "#E5484D", joints="#8A6A44", widthk=0.9)),
    ("Silhouette", style("#0E0F11", "#F4F4F6", "#F4F4F6", widthk=1.25, muscle_on="limb")),
    ("Contour", style("#141518", "#F1F2F4", "#FF6369", outline=True)),
    ("Néon", style("#05060A", "#5CE1FF", "#FF2E63", glow=True, widthk=0.7)),
    ("Relief 3D", style("#15171C", "#E6E8EC", "#FF5A5F", relief=True, widthk=1.2)),
    ("Blocs géométriques", style("#141518", "#ECEDEF", "#FF5A5F", cap="butt", head="square", widthk=1.2)),
    ("Pointillé", style("#121316", "#F1F2F4", "#FF6369", dots=True)),
    ("Croquis", style("#F4F1EA", "#2B2B2B", "#D8433F", gear="#8B8B8B", floor="#E6E1D6", sketch=True)),
    ("Plan technique", style("#0F2A4A", "#E8F1FF", "#FF7A6E", gear="#8FB3E0", floor="#17365C", widthk=0.45, torso="outline", grid=True)),
    ("Rayons X", style("#05070A", "#7FA7C9", "#FF4D6D", xray=True)),
    ("Pastel", style("#F6F1FA", "#B9B3D6", "#FF8FA3", gear="#C9C3DD", floor="#ECE6F3", widthk=1.4)),
    ("Bicolore", style("#0E1C2B", "#3E6E9E", "#FFB547", gear="#2C4F72", floor="#13263A", widthk=1.1)),
    ("Ombre portée", style("#F2F2F4", "#1E2127", "#E5484D", gear="#9AA0AA", floor="#E3E4E8", shadow=True)),
    ("Pixel", style("#101114", "#F1F2F4", "#FF5A5F", pixel=7, cap="square", widthk=1.1)),
    ("Facettes", style("#14161B", "#DADDE3", "#FF5A5F", facets=True)),
    ("Organique effilé", style("#131418", "#EFEFF2", "#FF6369", tapered=True)),
    ("Anatomique", style("#0D0E11", "#9AA0AA", "#FF3B47", anatomic=True)),
]


def render(data, p, st, W=170, H=150):
    items, scale = items_for(data, p, W, H)
    k = st.get("widthk", 1.0)
    cap = st.get("cap", "round")
    defs, out = [], []
    if st.get("glow"):
        defs.append('<filter id="g" x="-50%" y="-50%" width="200%" height="200%"><feGaussianBlur stdDeviation="3" result="b"/>'
                    '<feMerge><feMergeNode in="b"/><feMergeNode in="b"/><feMergeNode in="SourceGraphic"/></feMerge></filter>')
    if st.get("relief"):
        defs.append('<filter id="r"><feDropShadow dx="1.2" dy="2" stdDeviation="1.4" flood-color="#000" flood-opacity="0.55"/></filter>')
    if st.get("shadow"):
        defs.append('<filter id="s"><feDropShadow dx="5" dy="5" stdDeviation="0.5" flood-color="#000" flood-opacity="0.16"/></filter>')
    if st.get("sketch"):
        defs.append('<filter id="k"><feTurbulence type="fractalNoise" baseFrequency="0.9" numOctaves="1" result="t"/>'
                    '<feDisplacementMap in="SourceGraphic" in2="t" scale="2.2"/></filter>')
    if st.get("grid"):
        out.append(''.join(f'<path d="M{x},0V{H}" stroke="#1E4470" stroke-width="0.6"/>' for x in range(0, W, 12)))
        out.append(''.join(f'<path d="M0,{y}H{W}" stroke="#1E4470" stroke-width="0.6"/>' for y in range(0, H, 12)))
    filt = ' filter="url(#g)"' if st.get("glow") else ' filter="url(#r)"' if st.get("relief") else \
        ' filter="url(#s)"' if st.get("shadow") else ' filter="url(#k)"' if st.get("sketch") else ""

    def colour(role):
        if role in ("muscle", "muscle2"):
            return st["muscle"] if role == "muscle" else rgb_hex(mix(hex_rgb(st["muscle"]), hex_rgb(st["bg"]), 0.5))
        if role == "ink":
            return st["body"]
        if role == "floor" or role == "mark":
            return st["floor"]
        return st["gear"]

    def snap(pts):
        g = st.get("pixel")
        return [(round(x / g) * g, round(y / g) * g) for x, y in pts] if g else pts

    body_parts = []
    for it in items:
        role, kind, pts = it["role"], it["kind"], snap(it["pts"])
        col = colour(role)
        is_body = role in ("ink", "muscle", "muscle2")
        w = it["w"] * (k if is_body else 1.0)
        if st.get("muscle_on") == "limb" and role in ("muscle", "muscle2"):
            col, w = "#FF5A5F", w * 1.25
        if st.get("anatomic") and role in ("muscle", "muscle2"):
            w *= 1.35
        el = ""
        if kind == 0:
            if st.get("tapered") and is_body and len(pts) == 2:
                el = f'<path d="{path(taper(pts[0], pts[1], w * 1.45, w * 0.7), True)}" fill="{col}" stroke="{col}" stroke-width="1.5" stroke-linejoin="round"/>'
            elif st.get("facets") and is_body and len(pts) == 2:
                a, b = pts
                m = ((a[0] + b[0]) / 2, (a[1] + b[1]) / 2)
                el = (f'<path d="{path(taper(a, m, w * 0.8, w * 1.3), True)}" fill="{col}"/>'
                      f'<path d="{path(taper(m, b, w * 1.3, w * 0.6), True)}" fill="{rgb_hex(mix(hex_rgb(col), np.zeros(3), 0.18))}"/>')
            elif st.get("dots") and is_body:
                el = (f'<path d="{path(pts)}" fill="none" stroke="{col}" stroke-width="{w:.1f}" stroke-linecap="round" '
                      f'stroke-dasharray="0 {w * 1.35:.1f}"/>')
            else:
                el = f'<path d="{path(pts)}" fill="none" stroke="{col}" stroke-width="{w:.1f}" stroke-linecap="{cap}" stroke-linejoin="round"/>'
                if st.get("outline") and is_body:
                    el = (f'<path d="{path(pts)}" fill="none" stroke="{col}" stroke-width="{w:.1f}" stroke-linecap="round"/>'
                          f'<path d="{path(pts)}" fill="none" stroke="{st["bg"] if role == "ink" else col}" stroke-width="{max(w - 3.2, 0.6):.1f}" stroke-linecap="round"/>')
                if st.get("xray") and role == "ink":
                    el = (f'<path d="{path(pts)}" fill="none" stroke="{col}" stroke-opacity="0.28" stroke-width="{w:.1f}" stroke-linecap="round"/>'
                          f'<path d="{path(pts)}" fill="none" stroke="#DDEBFF" stroke-width="1.3" stroke-linecap="round"/>')
                if st.get("anatomic") and role == "ink":
                    el = f'<path d="{path(pts)}" fill="none" stroke="{col}" stroke-width="{w:.1f}" stroke-linecap="round" stroke-opacity="0.75"/>'
                if st.get("sketch") and is_body:
                    el += f'<path d="{path(pts)}" fill="none" stroke="{col}" stroke-opacity="0.45" stroke-width="1" transform="translate(1.4,-1)"/>'
            if st.get("joints") and role == "ink" and len(pts) == 2:
                for x, y in pts:
                    el += f'<circle cx="{x:.1f}" cy="{y:.1f}" r="{w * 0.62:.1f}" fill="{st["joints"]}"/>'
        elif kind == 1:
            if st.get("torso") == "outline" and role == "ink":
                el = f'<path d="{path(pts, True)}" fill="none" stroke="{col}" stroke-width="{max(it["w"] * 0.9, 1.4):.1f}" stroke-linejoin="round"/>'
            elif st.get("outline") and role == "ink":
                el = f'<path d="{path(pts, True)}" fill="{st["bg"]}" stroke="{col}" stroke-width="2.4" stroke-linejoin="round"/>'
            elif st.get("xray") and role == "ink":
                el = (f'<path d="{path(pts, True)}" fill="{col}" fill-opacity="0.22" stroke="{col}" stroke-opacity="0.5" stroke-width="1"/>'
                      f'<path d="{path([((pts[0][0] + pts[-1][0]) / 2, (pts[0][1] + pts[-1][1]) / 2), ((pts[2][0] + pts[3][0]) / 2, (pts[2][1] + pts[3][1]) / 2)])}" '
                      f'stroke="#DDEBFF" stroke-width="1.6"/>')
            elif st.get("facets") and role == "ink" and len(pts) >= 4:
                c = (sum(x for x, _ in pts) / len(pts), sum(y for _, y in pts) / len(pts))
                for i in range(len(pts)):
                    tri = [c, pts[i], pts[(i + 1) % len(pts)]]
                    shade = rgb_hex(mix(hex_rgb(col), np.zeros(3), 0.05 * (i % 3)))
                    el += f'<path d="{path(tri, True)}" fill="{shade}" stroke="{shade}" stroke-width="0.6"/>'
            else:
                el = f'<path d="{path(pts, True)}" fill="{col}" stroke="{col}" stroke-width="{it["w"] * (k if is_body else 1):.1f}" stroke-linejoin="round"/>'
        elif kind == 3:
            (x, y), r = pts[0], it["w"] * (1.0 if not is_body else min(k, 1.2) if role == "ink" else k)
            if st.get("head") == "ring" and role == "ink":
                el = f'<circle cx="{x:.1f}" cy="{y:.1f}" r="{r:.1f}" fill="none" stroke="{col}" stroke-width="1.6"/>'
            elif st.get("head") == "square" and role == "ink":
                el = f'<rect x="{x - r:.1f}" y="{y - r:.1f}" width="{2 * r:.1f}" height="{2 * r:.1f}" fill="{col}"/>'
            elif st.get("outline") and role == "ink":
                el = f'<circle cx="{x:.1f}" cy="{y:.1f}" r="{r:.1f}" fill="{st["bg"]}" stroke="{col}" stroke-width="2.4"/>'
            else:
                el = f'<circle cx="{x:.1f}" cy="{y:.1f}" r="{r:.1f}" fill="{col}"' + (' fill-opacity="0.35"' if st.get("xray") and role == "ink" else "") + "/>"
        elif kind == 2:
            (x, y) = pts[0]
            el = f'<circle cx="{x:.1f}" cy="{y:.1f}" r="{it["w"]:.1f}" fill="{col}" fill-opacity="0.45" stroke="{col}" stroke-width="1.5"/>'
        (body_parts if is_body else out).append(el)
    group = f'<g{filt}>' + "".join(body_parts) + '</g>'
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" viewBox="0 0 {W} {H}"><defs>{"".join(defs)}</defs>'
            f'<rect width="{W}" height="{H}" rx="14" fill="{st["bg"]}"/>{"".join(out)}{group}</svg>')


if __name__ == "__main__":
    cards = []
    for i, (name, st) in enumerate(STYLES, 1):
        panels = "".join(render(DEMOS[d], p, st) for d, p in (("db-curl", 0.55), ("anatomy-chest", 0.25), ("back-squat", 0.5)))
        cards.append(f'<div class="card"><div class="t"><b>{i:02d}</b> {name}</div><div class="p">{panels}</div></div>')
    html = ('<html><head><meta charset="utf-8"><style>body{background:#0B0C0F;color:#EEE;font-family:-apple-system,Helvetica,sans-serif;'
            'margin:18px;width:2240px}.card{display:inline-block;margin:8px;padding:12px;background:#1A1C21;border-radius:18px;vertical-align:top}'
            '.t{font-size:17px;margin:0 0 8px 4px}.t b{color:#FF6369;margin-right:6px}.p{display:flex;gap:8px}</style></head><body>'
            '<div style="font-size:26px;font-weight:700;margin:4px 10px 10px">Ardane · 20 styles de personnage pour les démonstrations</div>'
            + "".join(cards) + "</body></html>")
    out = Path(__file__).parent / "out" / "styles.html"
    out.parent.mkdir(exist_ok=True)
    out.write_text(html, encoding="utf-8")
    print(out)
