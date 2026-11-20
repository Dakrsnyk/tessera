#!/usr/bin/env python3
"""Replace the lit screen of a hand-held phone shot by a flat picture (ffmpeg + OpenCV + PIL, no Remotion).

Two commands:

  homes  --assets <film/public> --out <dir>
      composes the flat 1206 x 2622 Home Screens (Fitness, Planning) from the real exports: wallpaper, widget
      exports as they are (only scaled to the measured iOS grid of film/src/lib/iosHome.ts), the real Apple icons,
      a status bar for a NOTCH iPhone (9:41 in the left ear, network / Wi-Fi / battery in the right ear).

  shot   --src <video> --start <s> --dur <s> --home <flat.png> --out <name.mp4>
      1. tracks the four corners of the lit screen on every frame (robust sub-pixel line fit of the four sides,
         zero-phase smoothing of the shape of the quad) and writes them beside the output (<name>-corners.json);
      2. measures the fixed shape of the lit area in screen space (rounded corners, notch) over the whole range;
      3. draws the flat picture, perspective-correct, at the OUTPUT resolution (after the crop and the scale),
         only inside that shape and behind whatever is lit by the room and not by the screen (the hand, a thumb);
      4. turns everything else into a denoised black and white taken from the room's coloured light only, so that
         no light of the original screen is left (no halo, no content), then bloom, a very light blur and grain;
      5. writes <name>.mp4 (H.264 crf 14, yuv420p, no audio), <name>-sheet.jpg and three stills <name>-a/b/c.png.

The footage this was made for: a dark room lit by a purple LED, a phone whose own screen is neutral (grey / white).
The separation « in front of the screen or not » relies on that (see room_light).
"""
from __future__ import annotations

import argparse
import json
import math
import subprocess
import sys
from pathlib import Path

import cv2
import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

FW, FH = 1206, 2622  # the flat screen (capture px, iPhone 16 Pro @3x: the kit's size)

# ------------------------------------------------------------------------------------------------------------------
# 1. The flat Home Screens (grid measured on the simulator: film/src/lib/iosHome.ts)
# ------------------------------------------------------------------------------------------------------------------
IOS = dict(left=81, right=638, top=272, pair=602, small=489, medium=(1046, 489), large=(1046, 1098), icon=188,
           icon_left=92.5, icon_step=277.7, row_step=301, dock_top=2263, dock_icon_top=2322)
DOCK = ["Messages", "Safari", "Photos", "Settings"]


def icon_xy(c: int, r: int) -> tuple[float, float]:
    return IOS["icon_left"] + IOS["icon_step"] * c, IOS["top"] + r * IOS["row_step"]


def ios_rect(size: str, c: int, r: int) -> tuple[int, int, int, int]:
    x = IOS["left"] if c == 0 else IOS["right"]
    y = IOS["top"] + (r // 2) * IOS["pair"]
    if size == "s":
        return x, y, IOS["small"], IOS["small"]
    w, h = IOS["medium"] if size == "m" else IOS["large"]
    return IOS["left"], y, w, h


HOMES = {
    "fitness": dict(
        wall="irl/fitness/wall-irl-apps.png", dark=True, search=True,
        widgets=[("campaign/kit/irl-nextSet-combo-carbon.png", ios_rect("m", 0, 0)),
                 ("campaign/kit/irl-personalRecords-s-carbon.png", ios_rect("s", 0, 2)),
                 ("campaign/kit/irl-weeklyVolume-m-carbon.png", ios_rect("m", 0, 4))],
        apps=[("Health", 2, 2), ("Maps", 3, 2), ("Calendar", 2, 3), ("Reminders", 3, 3)]),
    "planning": dict(
        wall="kit2026/en/wall-pastel.png", dark=False, search=False,  # page 1 of 2: page dots, as in the film
        widgets=[("campaign/kit/camp-timetable-l-light.png", ios_rect("l", 0, 0)),
                 ("campaign/kit/camp-priorities-s-light.png", ios_rect("s", 0, 4))],
        apps=[("Calendar", 2, 4), ("Reminders", 3, 4), ("News", 2, 5), ("Maps", 3, 5)]),
}


class Canvas:
    """A 1206 x 2622 RGBA canvas with anti-aliased shapes (drawn 4x, then reduced) and Inter labels."""

    SS = 4

    def __init__(self, wall: Image.Image, font_file: Path):
        self.im = wall.convert("RGBA").resize((FW, FH), Image.LANCZOS)
        self.font_file = font_file

    def font(self, weight: int, px: float) -> ImageFont.FreeTypeFont:
        f = ImageFont.truetype(str(self.font_file), round(px))
        f.set_variation_by_axes([min(32, max(14, px)), weight])  # opsz follows the size, as the browser does
        return f

    def shape(self, box, draw_fn, rgba, blur: float = 0.0, dy: int = 0):
        """draw_fn(draw, s) paints in white on a mask of `box` (x0, y0, x1, y1), s = supersampling factor."""
        x0, y0, x1, y1 = [int(math.floor(v)) for v in box[:2]] + [int(math.ceil(v)) for v in box[2:]]
        pad = int(blur * 3) + 2
        x0, y0, x1, y1 = x0 - pad, y0 - pad, x1 + pad, y1 + pad
        s = self.SS
        m = Image.new("L", ((x1 - x0) * s, (y1 - y0) * s), 0)
        d = ImageDraw.Draw(m)
        draw_fn(d, s, x0, y0)
        m = m.resize((x1 - x0, y1 - y0), Image.LANCZOS)
        if blur:
            m = m.filter(ImageFilter.GaussianBlur(blur))
        r, g, b, a = rgba
        layer = Image.new("RGBA", m.size, (r, g, b, 0))
        layer.putalpha(m.point(lambda v: round(v * a)))
        self.im.alpha_composite(layer, (x0, y0 + dy)) if y0 + dy >= 0 and x0 >= 0 else self.im.paste(layer, (x0, y0 + dy), layer)

    def rrect(self, x, y, w, h, r, rgba, outline: float = 0.0):
        def fn(d, s, ox, oy):
            box = [(x - ox) * s, (y - oy) * s, (x + w - ox) * s, (y + h - oy) * s]
            if outline:
                d.rounded_rectangle(box, r * s, outline=255, width=round(outline * s))
            else:
                d.rounded_rectangle(box, r * s, fill=255)
        self.shape((x, y, x + w, y + h), fn, rgba)

    def text(self, s: str, cx: float, top: float, weight: int, px: float, rgba, shadow: bool = False, middle: bool = False):
        """Centred on cx; `top` is the top of the CSS line box (or the middle of the digits when `middle`)."""
        f = self.font(weight, px)
        base = top + (0.727 * px / 2 if middle else 0.969 * px)
        if shadow:  # text-shadow: 0 1px 6px rgba(0,0,0,0.35)
            self.shape((cx - 300, base - px, cx + 300, base + px * 0.4), lambda d, k, ox, oy: d.text(((cx - ox) * k, (base - oy) * k), s, font=self.font(weight, px * k), fill=255, anchor="ms"), (0, 0, 0, 0.35), blur=3, dy=1)
        self.shape((cx - 300, base - px, cx + 300, base + px * 0.4), lambda d, k, ox, oy: d.text(((cx - ox) * k, (base - oy) * k), s, font=self.font(weight, px * k), fill=255, anchor="ms"), rgba)
        return f.getlength(s)

    def picture(self, img: Image.Image, x: float, y: float, w: int, h: int, shadow: bool = False):
        img = img.convert("RGBA").resize((w, h), Image.LANCZOS)
        x, y = round(x), round(y)
        if shadow:  # drop-shadow(0 6px 9px rgba(0,0,0,0.18))
            pad = 30
            a = Image.new("L", (w + 2 * pad, h + 2 * pad), 0)
            a.paste(img.getchannel("A"), (pad, pad))
            a = a.filter(ImageFilter.GaussianBlur(5)).point(lambda v: round(v * 0.18))
            sh = Image.new("RGBA", a.size, (0, 0, 0, 0))
            sh.putalpha(a)
            self.im.alpha_composite(sh, (x - pad, y - pad + 6))
        self.im.alpha_composite(img, (x, y))


def status_bar_notch(cv_: Canvas, ink):
    """9:41 in the left ear, network / Wi-Fi / FULL battery in the right ear (shapes of iosHome.ts, scaled to the ear).
    The middle is left empty: the physical notch of the footage covers it."""
    cv_.text("9:41", 150, 74, 600, 48, ink + (1.0,), middle=True)
    k = 0.84  # the three indicators of iosHome.ts are 232 px wide: an ear leaves about 200
    gx, gy = 1055 - 121 * k, 74 - 27.5 * k

    def bars(d, s, ox, oy):
        P = lambda x, y: ((gx + x * k - ox) * s, (gy + y * k - oy) * s)
        for i, h in enumerate([12, 19, 27, 36]):
            d.rounded_rectangle([P(5 + i * 16, 45 - h), P(15 + i * 16, 45)], 3 * k * s, fill=255)
        for r in (24, 16, 8):  # Wi-Fi: three arcs with round ends, and the dot
            x0, y0 = P(110 - r, 43 - r)
            x1, y1 = P(110 + r, 43 + r)
            w = 6 * k * s
            d.arc([x0 - w / 2, y0 - w / 2, x1 + w / 2, y1 + w / 2], 225, 315, fill=255, width=round(w))
            for a in (225, 315):
                ex, ey = P(110 + r * math.cos(math.radians(a)), 43 + r * math.sin(math.radians(a)))
                d.ellipse([ex - w / 2, ey - w / 2, ex + w / 2, ey + w / 2], fill=255)
        d.ellipse([P(106, 37), P(114, 45)], fill=255)
        d.rounded_rectangle([P(165, 15), P(225, 40)], 6.5 * k * s, fill=255)

    def faint(d, s, ox, oy):
        P = lambda x, y: ((gx + x * k - ox) * s, (gy + y * k - oy) * s)
        d.rounded_rectangle([P(160, 10), P(230, 45)], 10 * k * s, outline=255, width=round(3 * k * s))
        d.rounded_rectangle([P(233, 21), P(237.5, 34)], 2 * k * s, fill=255)

    box = (gx, gy, gx + 240 * k, gy + 50 * k)
    cv_.shape(box, bars, ink + (1.0,))
    cv_.shape(box, faint, ink + (0.4,))


def compose_home(kind: str, assets: Path) -> Image.Image:
    cfg = HOMES[kind]
    dark = cfg["dark"]
    cv_ = Canvas(Image.open(assets / cfg["wall"]), assets / "fonts/Inter-opsz.woff2")
    label = (255, 255, 255, 0.96) if dark else (28, 32, 40, 0.86)
    ink = (255, 255, 255) if dark else (0, 0, 0)
    for file, (x, y, w, h) in cfg["widgets"]:  # the export as it is (its own rounded corners and transparency)
        cv_.picture(Image.open(assets / file), x, y, w, h)
        cv_.text("Ardane", x + w / 2, y + h + 18, 500, 36, label, shadow=dark)
    for name, c, r in cfg["apps"]:
        x, y = icon_xy(c, r)
        cv_.picture(Image.open(assets / f"apple-icons/{name}.png"), x, y, IOS["icon"], IOS["icon"], shadow=True)
        cv_.text(name, x + IOS["icon"] / 2, y + IOS["icon"] + 10, 500, 36, label, shadow=dark)
    status_bar_notch(cv_, ink)
    fill, line = ((18, 22, 30, 0.32), (255, 255, 255, 0.20)) if dark else ((255, 255, 255, 0.34), (255, 255, 255, 0.55))
    if cfg["search"]:  # the Search pill: magnifier + « Search », centred in the pill (488, 2113, 230 x 84)
        cv_.rrect(488, 2113, 230, 84, 42, fill)
        cv_.rrect(488, 2113, 230, 84, 42, line, outline=2)
        tw = cv_.font(500, 36).getlength("Search")
        x0 = 488 + (230 - (28 + 14 + tw)) / 2

        def glass(d, s, ox, oy):
            cx, cy, w = (x0 + 11.5 - ox) * s, (2155 - 2.5 - oy) * s, 3.7 * s
            d.ellipse([cx - 9 * s - w / 2, cy - 9 * s - w / 2, cx + 9 * s + w / 2, cy + 9 * s + w / 2], outline=255, width=round(w))
            d.line([((x0 + 18 - ox) * s, (2159 - oy) * s), ((x0 + 25.5 - ox) * s, (2166.5 - oy) * s)], fill=255, width=round(w))
        cv_.shape((x0 - 2, 2135, x0 + 30, 2172), glass, label)
        cv_.text("Search", x0 + 42 + tw / 2, 2156, 500, 36, label, middle=True)
    else:  # two page dots, the first one current
        for i, a in enumerate((0.85, 0.35)):
            cx = FW / 2 + (i - 0.5) * 48
            cv_.shape((cx - 11, 2146, cx + 11, 2168), lambda d, s, ox, oy, cx=cx: d.ellipse([(cx - 11 - ox) * s, (2146 - oy) * s, (cx + 11 - ox) * s, (2168 - oy) * s], fill=255), (30, 36, 48, a))
    cv_.rrect(52, IOS["dock_top"], 1100, 304, 120, fill)
    cv_.rrect(52, IOS["dock_top"], 1100, 304, 120, line, outline=2)
    for i, name in enumerate(DOCK):
        cv_.picture(Image.open(assets / f"apple-icons/{name}.png"), icon_xy(i, 0)[0], IOS["dock_icon_top"], IOS["icon"], IOS["icon"], shadow=True)
    return cv_.im.convert("RGB")


def cmd_homes(a):
    out = Path(a.out)
    out.mkdir(parents=True, exist_ok=True)
    for kind in HOMES:
        p = out / f"home-{kind}-{FW}x{FH}.png"
        compose_home(kind, Path(a.assets)).save(p)
        print("wrote", p)


# ------------------------------------------------------------------------------------------------------------------
# 2. Tracking: the four corners of the lit screen
# ------------------------------------------------------------------------------------------------------------------
def read_frames(src: str, start: float, n: int, fps: float = 30.0):
    """Frames [start, start + n / fps) as BGR arrays (ffmpeg seeks to the exact frame)."""
    info = subprocess.run(["ffprobe", "-v", "error", "-select_streams", "v:0", "-show_entries", "stream=width,height", "-of", "csv=p=0", src], capture_output=True, text=True, check=True).stdout.strip().split(",")
    w, h = int(info[0]), int(info[1])
    p = subprocess.Popen(["ffmpeg", "-v", "error", "-ss", f"{start:.4f}", "-i", src, "-frames:v", str(n), "-vf", f"fps={fps}", "-f", "rawvideo", "-pix_fmt", "bgr24", "-"], stdout=subprocess.PIPE)
    out = []
    for _ in range(n):
        buf = p.stdout.read(w * h * 3)
        if len(buf) < w * h * 3:
            break
        out.append(np.frombuffer(buf, np.uint8).reshape(h, w, 3))
    p.stdout.close()
    p.wait()
    if len(out) < n:
        raise SystemExit(f"only {len(out)} of {n} frames could be read from {src} at {start} s")
    return out


def order_quad(q: np.ndarray) -> np.ndarray:
    """TL, TR, BR, BL for a phone held roughly upright."""
    c = q.mean(0)
    ang = np.arctan2(q[:, 1] - c[1], q[:, 0] - c[0])
    q = q[np.argsort(ang)]  # clockwise on screen (y down), starting somewhere on the top
    return np.roll(q, -int(np.argmin(q[:, 0] + q[:, 1])), axis=0)


def coarse_quad(gray: np.ndarray) -> np.ndarray:
    """The lit screen is by far the brightest thing of the picture: every bright blob of some size (dark content or a
    finger may cut the screen in several), as one rotated rectangle."""
    blur = cv2.GaussianBlur(gray, (0, 0), 4)
    thr = max(30.0, 0.3 * float(np.percentile(blur, 99.7)))
    n, lab, st, _ = cv2.connectedComponentsWithStats((blur > thr).astype(np.uint8), connectivity=8)
    if n < 2:
        raise RuntimeError("no lit screen found")
    big = 1 + np.flatnonzero(st[1:, cv2.CC_STAT_AREA] >= 0.03 * st[1:, cv2.CC_STAT_AREA].max())
    pts = cv2.findNonZero(np.isin(lab, big).astype(np.uint8))
    return order_quad(cv2.boxPoints(cv2.minAreaRect(cv2.convexHull(pts))).astype(np.float64))


# parts of each side (fraction of its length) where the edge of the lit area is the straight side of the screen:
# never the rounded corners, and on the top side only the two « ears » beside the notch
SIDE_SPANS = [[(0.125, 0.195), (0.805, 0.875)], [(0.07, 0.93)], [(0.14, 0.86)], [(0.07, 0.93)]]  # top, right, bottom, left


def fit_side(gray: np.ndarray, a: np.ndarray, b: np.ndarray, inward: np.ndarray, spans, reach: float):
    """Sub-pixel points of the dark -> lit step along the side a-b, then a robust line. Returns (point, direction, n)."""
    length = float(np.linalg.norm(b - a))
    ss = np.concatenate([np.arange(s0, s1, 1.0 / length) for s0, s1 in spans])
    base = a[None, :] + ss[:, None] * (b - a)[None, :]
    offs = np.arange(-reach, reach + 0.25, 0.5)
    xs = (base[:, None, 0] + offs[None, :] * inward[0]).astype(np.float32)
    ys = (base[:, None, 1] + offs[None, :] * inward[1]).astype(np.float32)
    prof = cv2.remap(gray, xs, ys, cv2.INTER_LINEAR, borderMode=cv2.BORDER_REPLICATE)
    g = np.clip(np.diff(prof, axis=1), 0, None)  # only dark -> lit, going inward
    k = np.argmax(g, axis=1)
    idx = np.arange(len(ss))
    win = np.clip(k[:, None] + np.arange(-4, 5)[None, :], 0, g.shape[1] - 1)
    gw = g[idx[:, None], win]
    pos = (gw * (offs[win] + 0.25)).sum(1) / np.maximum(gw.sum(1), 1e-6)
    # a real screen edge: black just outside, lit just inside
    out_l = prof[idx, np.clip(k - 6, 0, prof.shape[1] - 1)]
    in_l = prof[idx, np.clip(k + 7, 0, prof.shape[1] - 1)]
    ok = (gw.sum(1) > 45) & (out_l < 45) & (in_l > 70) & (k > 4) & (k < g.shape[1] - 5)
    pts = (base + pos[:, None] * inward[None, :])[ok]
    if len(pts) < 12:
        return None
    line = cv2.fitLine(pts.astype(np.float32), cv2.DIST_HUBER, 0, 0.01, 0.01).ravel()
    d, p0 = line[:2].astype(np.float64), line[2:].astype(np.float64)
    res = np.abs((pts - p0) @ np.array([-d[1], d[0]]))
    keep = res < max(0.6, 2.5 * float(np.median(res)))
    if keep.sum() < 12:
        return None
    line = cv2.fitLine(pts[keep].astype(np.float32), cv2.DIST_L2, 0, 0.01, 0.01).ravel()
    return line[2:].astype(np.float64), line[:2].astype(np.float64), int(keep.sum())


def intersect(l1, l2) -> np.ndarray:
    (p, d), (q, e) = l1[:2], l2[:2]
    t = np.linalg.solve(np.array([d, -e]).T, q - p)[0]
    return p + t * d


def refine_quad(gray: np.ndarray, quad: np.ndarray, reaches=(16, 8, 5, 5)):
    """Quad -> quad whose sides lie on the edge of the lit area. Returns (quad, points used per side) or None."""
    counts = [0, 0, 0, 0]
    for reach in reaches:
        c = quad.mean(0)
        lines = []
        for i in range(4):
            a, b = quad[i], quad[(i + 1) % 4]
            n = np.array([-(b - a)[1], (b - a)[0]])
            n /= np.linalg.norm(n)
            if (c - a) @ n < 0:
                n = -n
            fit = fit_side(gray, a, b, n, SIDE_SPANS[i], reach)
            if fit is None:
                return None
            lines.append(fit)
            counts[i] = fit[2]
        quad = np.array([intersect(lines[3], lines[0]), intersect(lines[0], lines[1]), intersect(lines[1], lines[2]), intersect(lines[2], lines[3])])
    return quad, counts


def lowpass(a: np.ndarray, sigma: float) -> np.ndarray:
    """Zero-phase Gaussian along the first axis (no lag); ends extended by point reflection (keeps a steady drift)."""
    a = np.asarray(a, np.float64)
    n = len(a)
    r = min(int(math.ceil(3 * sigma)), n - 1)
    if sigma <= 0 or r < 1:
        return a.copy()
    ext = np.concatenate([2 * a[0] - a[r:0:-1], a, 2 * a[-1] - a[-2:-r - 2:-1]])
    k = np.exp(-0.5 * (np.arange(-r, r + 1) / sigma) ** 2)
    k /= k.sum()
    flat = ext.reshape(len(ext), -1)
    return np.stack([np.convolve(flat[:, j], k, mode="valid") for j in range(flat.shape[1])], 1).reshape(a.shape)


def smooth_shape(q: np.ndarray, sigma: float) -> np.ndarray:
    """Temporal smoothing that cannot lag nor swim: position, angle and size of the quad are kept as measured on each
    frame (a hand-held shot really moves from one frame to the next: smoothing them was measured to make the content
    swim 4 times more); only the SHAPE left once they are taken out (the perspective, which changes slowly and is the
    noisiest part of a line fit) is smoothed, zero-phase."""
    z = q[..., 0] + 1j * q[..., 1]
    ref = z.mean(0)
    refc = ref - ref.mean()
    zc = z - z.mean(1, keepdims=True)
    a = (zc * refc.conj()).sum(1) / (refc * refc.conj()).sum()  # similarity ref -> frame: z = a ref + b
    b = z.mean(1) - a * ref.mean()
    res = (z - b[:, None]) / a[:, None]  # the quad of each frame, seen in the reference pose
    res = lowpass(np.stack([res.real, res.imag], -1), sigma)
    out = a[:, None] * (res[..., 0] + 1j * res[..., 1]) + b[:, None]
    return np.stack([out.real, out.imag], -1)


def track(frames, sigma: float = 1.5, log=print):
    """Per frame: raw corners, final corners (TL, TR, BR, BL, source px) and the edge points used per side."""
    raw, used, prev = [], [], None
    for i, f in enumerate(frames):
        gray = cv2.GaussianBlur(cv2.cvtColor(f, cv2.COLOR_BGR2GRAY).astype(np.float32), (0, 0), 0.8)
        res = refine_quad(gray, prev, reaches=(8, 5, 5)) if prev is not None else None
        if res is None:
            res = refine_quad(gray, coarse_quad(gray))
        if res is None:
            raise RuntimeError(f"frame {i}: the edge of the lit screen was not found")
        prev = res[0]
        raw.append(res[0])
        used.append(res[1])
    raw = np.array(raw)
    fin = smooth_shape(raw, sigma)
    d = fin - raw
    log(f"track: {len(raw)} frames; shape smoothing moved the corners by rms {np.sqrt((d ** 2).mean()):.3f} px (max {np.abs(d).max():.2f}); fewest edge points per side (top, right, bottom, left): {np.min(used, axis=0).tolist()}")
    return raw, fin, used


def flat_to_src(q: np.ndarray, w: int = FW, h: int = FH) -> np.ndarray:
    """Homography flat picture -> source frame. Pixel centres are integers: the picture spans -0.5 .. w - 0.5."""
    src = np.array([[-0.5, -0.5], [w - 0.5, -0.5], [w - 0.5, h - 0.5], [-0.5, h - 0.5]], np.float32)
    return cv2.getPerspectiveTransform(src, q.astype(np.float32))


def swim_check(frames, corners, log=print) -> dict:
    """Self-check, meaningful only while the ORIGINAL content is still: every frame is rectified with its corners and
    the content of four areas is compared with the middle frame (phase correlation). A perfect track gives 0."""
    w, h = 402, 874
    areas = [(40, 60, 360, 250), (30, 700, 380, 840), (20, 100, 120, 800), (290, 100, 390, 800)]
    rect = [cv2.warpPerspective(cv2.cvtColor(f, cv2.COLOR_BGR2GRAY).astype(np.float32), np.linalg.inv(flat_to_src(q, w, h)), (w, h), flags=cv2.INTER_CUBIC) for f, q in zip(frames, corners)]
    ref = rect[len(rect) // 2]
    dev = []
    for x0, y0, x1, y1 in areas:
        win = cv2.createHanningWindow((x1 - x0, y1 - y0), cv2.CV_32F)
        v = np.array([cv2.phaseCorrelate(ref[y0:y1, x0:x1].copy(), r[y0:y1, x0:x1].copy(), win)[0] for r in rect])
        dev.append(v - np.median(v, 0))
    dev = np.array(dev)
    out = dict(frames=len(rect), rms_px=round(float(np.sqrt((dev ** 2).mean())), 3), max_px=round(float(np.abs(dev).max()), 2))
    log(f"swim check on {out['frames']} frames of still content: rms {out['rms_px']} px, max {out['max_px']} px (source px, screen space)")
    return out


# ------------------------------------------------------------------------------------------------------------------
# 3. The fixed shape of the lit area (screen space): rounded corners and notch
# ------------------------------------------------------------------------------------------------------------------
def screen_shape(frames, corners, log=print) -> np.ndarray:
    """Alpha (float32, FH x FW) of the lit area: 1 inside, 0 in the four rounded corners and in the notch. Measured
    on the footage (60th percentile over the frames of the rectified luminance, at half size): the corners as ONE
    radius (the lit ones agree), the notch as a slot (width, depth, radius of its bottom corners)."""
    w, h = FW // 2, FH // 2
    step = max(1, len(frames) // 60)
    rect = np.array([cv2.warpPerspective(cv2.cvtColor(f, cv2.COLOR_BGR2GRAY), np.linalg.inv(flat_to_src(q, w, h)), (w, h), flags=cv2.INTER_LINEAR) for f, q in list(zip(frames, corners))[::step]])
    p = np.percentile(rect, 60, axis=0).astype(np.float32)
    # corners: along the diagonal of a corner the light starts at r (1 - 1 / sqrt 2) (only the diagonal is read, so
    # dark content near the corner does not count)
    k = int(0.16 * w)
    radii = []
    for win in (p[:k, :k], p[:k, ::-1][:, :k], p[::-1][:k, :k], p[::-1, ::-1][:k, :k]):
        d = np.diagonal(win).astype(np.float64)
        white = float(d[k // 3: k // 2].mean())
        if white > 40:
            i = int(np.argmax(d > 0.5 * white))
            if 0 < i < k // 3:
                radii.append((i - 1 + (0.5 * white - d[i - 1]) / (d[i] - d[i - 1])) / (1 - math.sqrt(0.5)))
    if not radii:
        raise RuntimeError("no lit corner to measure the corner radius")
    r = float(np.median(radii)) * 2  # flat px
    # notch: the dark blob hanging from the top side, between the corners, read as a symmetric slot with a flat bottom
    # and two round bottom corners (cracks of the glass hang under it: the depth is the one most columns agree on)
    x0 = int(0.12 * w)
    band = p[: int(0.07 * h), x0: w - x0]
    white = float(np.percentile(band, 85))
    dark = cv2.morphologyEx((band < 0.5 * white).astype(np.uint8), cv2.MORPH_OPEN, cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (5, 5)))
    _, lab = cv2.connectedComponents(dark)
    blob = np.isin(lab, [i for i in np.unique(lab[0]) if i > 0]).astype(np.uint8)
    s = 2  # drawn at 2x the flat size, blurred, reduced: an anti-aliased edge about 3 flat px wide (1.5 px on output)
    m = np.zeros((FH * s, FW * s), np.uint8)
    cv2.rectangle(m, (int(r * s), 0), (FW * s - 1 - int(r * s), FH * s - 1), 255, -1)
    cv2.rectangle(m, (0, int(r * s)), (FW * s - 1, FH * s - 1 - int(r * s)), 255, -1)
    for cx, cy in ((r, r), (FW - r, r), (r, FH - r), (FW - r, FH - r)):
        cv2.circle(m, (int(round(cx * s)), int(round(cy * s))), int(round(r * s)), 255, -1, cv2.LINE_AA)
    note = "no notch"
    if blob.any():
        cols = np.flatnonzero(blob.any(0))
        mid = slice(int(cols[0] + 0.25 * len(cols)), int(cols[0] + 0.75 * len(cols)))
        first = np.clip(np.where(blob[:, mid].all(0), blob.shape[0] - 1, blob[:, mid].argmin(0)), 1, None)  # first lit row
        lo_, hi_ = band[:, mid][first - 1, np.arange(len(first))], band[:, mid][first, np.arange(len(first))]
        depth = float(np.percentile(first - 0.5 + np.clip((0.5 * white - lo_) / np.maximum(hi_ - lo_, 1e-3), 0, 1), 30))
        rows = blob[int(0.2 * depth): max(int(0.5 * depth), int(0.2 * depth) + 1)]
        half = float(np.median([np.flatnonzero(row)[[0, -1]] @ [-0.5, 0.5] + 0.5 for row in rows if row.any()]))  # half width
        cxn = (w - 1) / 2 - x0  # the notch is centred on the screen

        def slot(rad: float, k: float = 1.0, off: float = 0.0) -> np.ndarray:
            o = np.zeros((int(blob.shape[0] * k), int(blob.shape[1] * k)), np.uint8)
            xa, xb, d, rr = (cxn - half) * k + off, (cxn + half) * k + off, depth * k, rad * k
            cv2.rectangle(o, (int(round(xa)), 0), (int(round(xb)), int(round(d - rr))), 1, -1)
            cv2.rectangle(o, (int(round(xa + rr)), 0), (int(round(xb - rr)), int(round(d))), 1, -1)
            for cx in (xa + rr, xb - rr):
                cv2.circle(o, (int(round(cx)), int(round(d - rr))), int(round(rr)), 1, -1)
            return o

        side = np.zeros(blob.shape, bool)  # the bottom corners are judged on the sides only, away from the cracks
        side[:, : int(cxn - 0.6 * half)] = side[:, int(cxn + 0.6 * half):] = True
        cands = np.arange(0.2 * depth, min(depth, half) + 0.1, 0.5)
        rad = float(cands[int(np.argmin([((slot(c) != blob) & side).sum() for c in cands]))])
        # half-size band px -> 2x flat px: x4 (pixel centres: X = 4 x + 1.5)
        big = np.zeros_like(m)
        o = slot(rad, 4.0, 0.0)
        xs = x0 * 4 + 1
        big[: o.shape[0], xs: xs + o.shape[1]] = o[:, : big.shape[1] - xs]
        m[big > 0] = 0
        note = f"notch x {2 * (x0 + cxn - half) + 0.5:.0f}..{2 * (x0 + cxn + half) + 0.5:.0f}, depth {2 * depth:.0f}, bottom radius {2 * rad:.0f} flat px"
    alpha = cv2.resize(cv2.GaussianBlur(m, (0, 0), 1.2 * s), (FW, FH), interpolation=cv2.INTER_AREA).astype(np.float32) / 255
    log(f"shape: corner radius {r:.0f} flat px ({100 * r / FW:.1f} % of the width, from {len(radii)} lit corners); {note}")
    return alpha


# ------------------------------------------------------------------------------------------------------------------
# 4. The shot
# ------------------------------------------------------------------------------------------------------------------
OW, OH = 1080, 1920


def room_light(bgr: np.ndarray) -> np.ndarray:
    """What the ROOM lights, without what the old screen lights. The LED of the room is purple (red and blue, almost
    no green), the old screen is neutral: R - 1.03 G is about 0 on the screen, on its glow on the bezel and in the
    notch, and positive on the hand and the room.
    ponytail: tied to a red / purple room light and a neutral screen; another footage needs another channel mix."""
    f = bgr.astype(np.float32)
    return np.clip(f[..., 2] - 1.03 * f[..., 1], 0, None)


def front_matte(v: np.ndarray, luma: np.ndarray, quad: np.ndarray, lo: float, hi: float, guide: int) -> np.ndarray:
    """Alpha (output px) of what stands IN FRONT of the screen: lit by the room (v, denoised) and attached to
    something outside the screen (a finger always comes from outside; a coloured dot of the old screen does not).
    Holes are filled. The room light is a chroma signal (half resolution, blocky): the outline is then drawn along
    the edge of the luminance wherever there is one (guided filter, radius `guide`)."""
    seed = (v > lo).astype(np.uint8)
    inside = np.zeros(seed.shape, np.uint8)
    cv2.fillConvexPoly(inside, np.round(quad).astype(np.int32), 1)
    inside = cv2.erode(inside, np.ones((7, 7), np.uint8))
    n, lab = cv2.connectedComponents(seed, connectivity=8)
    ok = np.zeros(n, bool)
    ok[np.unique(lab[(seed > 0) & (inside == 0)])] = True
    ok[0] = False
    keep = ok[lab]
    a = np.clip((v - lo) / (hi - lo), 0, 1) * keep
    a = a * a * (3 - 2 * a)
    solid = cv2.morphologyEx(((v > (lo + hi) / 2) & keep).astype(np.uint8), cv2.MORPH_CLOSE, cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (13, 13)))
    cnt, _ = cv2.findContours(solid, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
    cv2.drawContours(solid, cnt, -1, 1, -1)
    a = np.maximum(a, cv2.GaussianBlur(solid.astype(np.float32), (0, 0), 1.5))
    if guide:
        g, k = luma / 255.0, (2 * guide + 1, 2 * guide + 1)  # guided filter (He et al.)
        mg, ma = cv2.blur(g, k), cv2.blur(a, k)
        ca = (cv2.blur(g * a, k) - mg * ma) / (cv2.blur(g * g, k) - mg * mg + 2e-3)
        a = np.clip(cv2.blur(ca, k) * g + cv2.blur(ma - ca * mg, k), 0, 1)
        a = np.clip((cv2.GaussianBlur(a, (0, 0), 1.3) - 0.3) / 0.4, 0, 1)
    else:
        a = np.clip((cv2.GaussianBlur(a, (0, 0), 2.5) - 0.3) / 0.4, 0, 1)
    gate = np.clip((230.0 - luma) / 60.0, 0, 1)  # never in front where the old screen is plainly white
    return (a * a * (3 - 2 * a) * gate).astype(np.float32)



def stabilize(corners: np.ndarray, width_frac: float, centre, keep: float, sigma: float) -> np.ndarray:
    """Per frame, the similarity (2 x 3) source -> output that locks the picture on the phone: its fast motion goes
    (the phone is pinned), `keep` of its slow drift stays (position, tilt, size), so the shot still feels hand-held."""
    c = corners.mean(1)
    axis = (corners[:, 0] + corners[:, 1]) / 2 - (corners[:, 2] + corners[:, 3]) / 2  # bottom -> top
    size = np.linalg.norm(axis, axis=1)
    tilt = np.arctan2(axis[:, 0], -axis[:, 1])  # clockwise from the vertical
    cl, sl, tl = lowpass(c, sigma), lowpass(size, sigma), lowpass(tilt, sigma)
    mean_q = corners.mean(0)
    s0 = width_frac * OW / float(mean_q[:, 0].max() - mean_q[:, 0].min())
    out = []
    for i in range(len(corners)):
        k = s0 * (1 + keep * (sl[i] / sl.mean() - 1)) * sl.mean() / size[i]
        phi = tl.mean() + keep * (tl[i] - tl.mean()) - tilt[i]
        m = k * np.array([[math.cos(phi), -math.sin(phi)], [math.sin(phi), math.cos(phi)]])
        t = np.array(centre) + keep * s0 * (cl[i] - cl.mean(0)) - m @ c[i]
        out.append(np.hstack([m, t[:, None]]))
    return np.array(out)


def grade_room(v: np.ndarray) -> np.ndarray:
    """Room light -> contrasty black and white (0..255): black stays black, the hand reads as a hand."""
    return 120.0 * np.tanh(np.clip(v - 3.0, 0, None) / 26.0)


def cmd_shot(a):
    out = Path(a.out)
    out.parent.mkdir(parents=True, exist_ok=True)
    stem = out.with_suffix("")
    n = int(round(a.dur * a.fps))
    frames = read_frames(a.src, a.start, n, a.fps)
    raw, corners, used = track(frames, a.shape_sigma)
    k0 = int(round(a.check_from * a.fps)) if a.check_from is not None else None
    check = swim_check(frames[k0:], corners[k0:]) if k0 is not None else None
    shape = screen_shape(frames, corners)
    home = cv2.imread(a.home, cv2.IMREAD_COLOR)
    if home is None or home.shape[:2] != (FH, FW):
        raise SystemExit(f"{a.home}: a {FW} x {FH} picture is expected")
    # the flat picture as premultiplied BGRA: exposure of a phone filmed in a dark room, the shape as alpha
    rgba = np.dstack([home.astype(np.float32) * a.gain * shape[..., None], shape * 255]).round().astype(np.uint8)
    M = stabilize(corners, a.width, (a.cx * OW, a.cy * OH), a.keep, a.fps * 0.4)
    box = np.array([[0, 0, 1], [OW - 1, 0, 1], [OW - 1, OH - 1, 1], [0, OH - 1, 1]], np.float64).T
    seen = np.array([(np.linalg.inv(np.vstack([m, [0, 0, 1]])) @ box)[:2].T for m in M])  # output frame, in source px
    sh, sw = frames[0].shape[:2]
    if seen.min() < -0.5 or seen[..., 0].max() > sw - 0.5 or seen[..., 1].max() > sh - 0.5:
        print("WARNING: the output frame leaves the source picture (edges are repeated): lower --width or move --cx / --cy")
    print(f"framing: scale {np.linalg.norm(M[:, :, 0], axis=1).mean():.3f}, source window x {seen[..., 0].min():.0f}..{seen[..., 0].max():.0f}, y {seen[..., 1].min():.0f}..{seen[..., 1].max():.0f}")
    S = 2  # the screen is drawn at twice the output size, then reduced: sharp and without aliasing
    up = np.array([[S, 0, (S - 1) / 2], [0, S, (S - 1) / 2], [0, 0, 1]], np.float64)
    rng = np.random.default_rng(7)
    todo = sorted({0, n // 2, n - 1}) if a.preview else list(range(n))

    room_cache: dict[int, np.ndarray] = {}

    def room(i: int) -> np.ndarray:  # room light of frame i, in output space (phone-locked), lightly blurred
        if i not in room_cache:
            v = cv2.warpAffine(room_light(frames[i]), M[i], (OW, OH), flags=cv2.INTER_LINEAR, borderMode=cv2.BORDER_REPLICATE)
            room_cache[i] = cv2.GaussianBlur(v, (0, 0), 1.6).astype(np.float16)
            for j in [j for j in room_cache if j < i - 8]:
                del room_cache[j]
        return room_cache[i].astype(np.float32)

    enc = None
    if not a.preview:
        enc = subprocess.Popen(["ffmpeg", "-v", "error", "-y", "-f", "rawvideo", "-pix_fmt", "bgr24", "-s", f"{OW}x{OH}", "-r", str(a.fps), "-i", "-", "-an", "-c:v", "libx264", "-preset", "slow", "-crf", "14", "-pix_fmt", "yuv420p", "-colorspace", "bt709", "-color_primaries", "bt709", "-color_trc", "bt709", "-movflags", "+faststart", str(out)], stdin=subprocess.PIPE)
    stills = {0: "a", n // 2: "b", n - 1: "c"}
    sheet = []
    out_corners = []
    flat_box = np.array([[[-0.5, -0.5], [FW - 0.5, -0.5], [FW - 0.5, FH - 0.5], [-0.5, FH - 0.5]]], np.float64)
    for i in range(n):
        hom = np.vstack([M[i], [0, 0, 1]]) @ flat_to_src(corners[i])  # flat -> output
        out_corners.append(cv2.perspectiveTransform(flat_box, hom)[0])
        if i not in todo:
            continue
        # surround: room light only, denoised over time where it does not move (the picture is locked on the phone)
        cur = room(i)
        acc, wsum = cur.copy(), np.ones_like(cur)
        for j in range(max(0, i - 4), min(n, i + 5)):
            if j != i:
                o = room(j)
                wgt = np.exp(-((o - cur) / 6.0) ** 2)
                acc += wgt * o
                wsum += wgt
        vd = acc / wsum
        bw = grade_room(cv2.GaussianBlur(vd, (0, 0), a.room_soft))
        # new screen, perspective-correct, behind whatever stands in front of it
        scr = cv2.warpPerspective(rgba, up @ hom, (OW * S, OH * S), flags=cv2.INTER_CUBIC, borderMode=cv2.BORDER_CONSTANT, borderValue=0)
        scr = cv2.resize(scr, (OW, OH), interpolation=cv2.INTER_AREA).astype(np.float32)
        luma = cv2.warpAffine(cv2.cvtColor(frames[i], cv2.COLOR_BGR2GRAY), M[i], (OW, OH), flags=cv2.INTER_LINEAR).astype(np.float32)
        front = front_matte(vd, luma, out_corners[-1], a.front_lo, a.front_hi, a.guide)
        scr *= (1 - front)[..., None]
        scr = cv2.GaussianBlur(scr, (0, 0), a.soft)  # the very light blur of a filmed screen (colour and alpha together)
        al = scr[..., 3:4] / 255
        img = scr[..., :3] + (1 - al) * bw[..., None]
        # bloom: the light of the new screen spills a little on everything (bezel, thumb, hand)
        small = cv2.resize(scr[..., :3], (OW // 4, OH // 4), interpolation=cv2.INTER_AREA)
        glow = 0.10 * cv2.GaussianBlur(small, (0, 0), 3.5) + 0.07 * cv2.GaussianBlur(small, (0, 0), 16)
        img = 255 - (255 - img) * (1 - cv2.resize(glow, (OW, OH), interpolation=cv2.INTER_LINEAR) / 255)
        # grain: luminance noise, a little soft, new on each frame, stronger in the dark
        g = cv2.GaussianBlur(rng.standard_normal((OH, OW)).astype(np.float32), (0, 0), 0.7) * (a.grain / 0.39)
        img = np.clip(img + g[..., None] * (0.55 + 0.45 * (1 - img / 255)), 0, 255).round().astype(np.uint8)
        if enc:
            enc.stdin.write(img.tobytes())
        if i in stills:
            cv2.imwrite(f"{stem}-{stills[i]}.png", img)
        if i % max(1, int(round(a.fps * 0.25))) == 0 and not a.preview:
            sheet.append(cv2.resize(img, (360, 640), interpolation=cv2.INTER_AREA))
    if enc:
        enc.stdin.close()
        if enc.wait() != 0:
            raise SystemExit("ffmpeg failed")
        cols = 6
        sheet += [np.zeros_like(sheet[0])] * (-len(sheet) % cols)
        cv2.imwrite(f"{stem}-sheet.jpg", np.vstack([np.hstack(sheet[r: r + cols]) for r in range(0, len(sheet), cols)]), [cv2.IMWRITE_JPEG_QUALITY, 92])
        meta = dict(
            source=Path(a.src).name, start=a.start, fps=a.fps, frames=n, flat=[FW, FH], output=[OW, OH],
            note="corners TL, TR, BR, BL of the lit screen (its straight sides prolonged: the rounded corners are inside); pixel centres are integers",
            swim_check=check,
            corners_source=np.round(corners, 3).tolist(), corners_source_raw=np.round(raw, 3).tolist(),
            corners_output=np.round(np.array(out_corners), 3).tolist(), source_to_output=np.round(M, 6).tolist(),
            edge_points_per_side=np.array(used).tolist())
        Path(f"{stem}-corners.json").write_text(json.dumps(meta), encoding="utf-8")
        print("wrote", out, f"{stem}-sheet.jpg", f"{stem}-corners.json")


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="cmd", required=True)
    h = sub.add_parser("homes", help="compose the flat Home Screens")
    h.add_argument("--assets", default=str(Path.home() / "ardane-tools/film/public"), help="public folder of the film project")
    h.add_argument("--out", required=True)
    h.set_defaults(fn=cmd_homes)
    s = sub.add_parser("shot", help="replace the screen of a shot")
    s.add_argument("--src", required=True)
    s.add_argument("--start", type=float, required=True)
    s.add_argument("--dur", type=float, default=3.0)
    s.add_argument("--fps", type=float, default=30.0)
    s.add_argument("--home", required=True, help=f"flat picture, {FW} x {FH}")
    s.add_argument("--out", required=True, help="<name>.mp4; the sheet, the stills and the corners go beside it")
    s.add_argument("--width", type=float, default=0.68, help="width of the screen (its bounding box) / width of the frame")
    s.add_argument("--cx", type=float, default=0.53, help="centre of the screen in the frame (fraction of the width)")
    s.add_argument("--cy", type=float, default=0.5)
    s.add_argument("--keep", type=float, default=0.35, help="part of the slow hand-held drift that is kept")
    s.add_argument("--shape-sigma", type=float, default=1.5, help="frames; smoothing of the shape of the quad only")
    s.add_argument("--gain", type=float, default=0.88, help="exposure of the new screen")
    s.add_argument("--soft", type=float, default=0.55, help="blur of the new screen, output px")
    s.add_argument("--grain", type=float, default=2.2, help="grain, levels (rms)")
    s.add_argument("--room-soft", type=float, default=3.2, help="blur of the black and white surround, output px")
    s.add_argument("--front-lo", type=float, default=11.0, help="room light above which something is in front of the screen")
    s.add_argument("--front-hi", type=float, default=21.0)
    s.add_argument("--guide", type=int, default=8, help="radius (output px) of the luminance-guided outline of what is in front; 0 = off")
    s.add_argument("--check-from", type=float, default=None, help="seconds into the shot from which the ORIGINAL content is still: runs the swim check")
    s.add_argument("--preview", action="store_true", help="only the three stills")
    s.set_defaults(fn=cmd_shot)
    a = ap.parse_args()
    a.fn(a)


if __name__ == "__main__":
    main()
