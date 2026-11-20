#!/usr/bin/env python3
"""Replace the plain WHITE screen of a stock « phone in hand » shot (e.g. a free Pexels clip) by a flat Home Screen.

Reuses the tracking and the shape measurement of screen_replace.py (four sides of the lit screen, rounded corners
and notch measured on the footage); only the composition differs: the room is kept as filmed (no black and white
regrade), the new screen takes the measured exposure of the old one, sits behind any finger that crosses it, gets a
faint glass sheen fixed in the room (it slides over the screen when the phone moves) and the footage's grain.

  screen_replace_stock.py --src clip.mp4 --start 4 --dur 3 --home home-fitness-1206x2622.png --out phone-fitness.mp4

Writes <out>.mp4 (1080 x 1920, H.264 crf 14, yuv420p, no audio), <out>-sheet.jpg (one frame every 0.25 s) and
three full-size stills <out>-a/b/c.png. The source must be 1080 wide; a taller one is cropped (--crop-y).
ponytail: the screen must be plain white (or very light) and the bezel dark; a green screen needs another key.
"""
from __future__ import annotations

import argparse
import subprocess
from pathlib import Path

import cv2
import numpy as np

import screen_replace as sr
from screen_replace import FH, FW, flat_to_src, read_frames, screen_shape, track

OW, OH = 1080, 1920


def coarse_white(gray: np.ndarray) -> np.ndarray:
    """The white screen is the brightest large blob; the hand, lit too, stays under 85 % of it."""
    b = cv2.GaussianBlur(gray, (0, 0), 3)
    n, lab, st, _ = cv2.connectedComponentsWithStats((b > 0.85 * np.percentile(b, 99.5)).astype(np.uint8))
    if n < 2:
        raise RuntimeError("no white screen found")
    pts = cv2.findNonZero((lab == 1 + int(np.argmax(st[1:, cv2.CC_STAT_AREA]))).astype(np.uint8))
    return sr.order_quad(cv2.boxPoints(cv2.minAreaRect(pts)).astype(np.float64))


sr.coarse_quad = coarse_white  # track() looks it up at call time


def white_level(frame: np.ndarray, quad: np.ndarray) -> np.ndarray:
    """Median colour (BGR) of the middle of the old screen: its exposure and white balance on this frame."""
    m = np.zeros(frame.shape[:2], np.uint8)
    c = quad.mean(0)
    cv2.fillConvexPoly(m, np.round(c + 0.6 * (quad - c)).astype(np.int32), 1)
    return np.median(frame[m > 0].reshape(-1, 3), 0).astype(np.float32)


def front_matte(frame: np.ndarray, alpha: np.ndarray, white: np.ndarray) -> np.ndarray:
    """What stands in front of the old screen (a finger): inside the lit shape but clearly darker or more coloured
    than its white, and touching the outside of the shape (a finger always comes from outside)."""
    f = frame.astype(np.float32)
    lum = f.mean(2)
    sat = f.max(2) - f.min(2)
    d = np.clip((0.82 * white.mean() - lum) / (0.2 * white.mean()), 0, 1)
    d = np.maximum(d, np.clip((sat - (white.max() - white.min()) - 18) / 25, 0, 1))
    inner = cv2.erode((alpha > 0.5).astype(np.uint8), np.ones((5, 5), np.uint8))
    seed = ((d > 0.5) | (alpha < 0.5)).astype(np.uint8)
    n, lab = cv2.connectedComponents(seed, connectivity=8)
    ok = np.zeros(n, bool)
    ok[np.unique(lab[(seed > 0) & (inner == 0)])] = True
    ok[0] = False
    return (cv2.GaussianBlur(d * ok[lab], (0, 0), 0.8) * inner).astype(np.float32)


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--src", required=True)
    ap.add_argument("--start", type=float, required=True)
    ap.add_argument("--dur", type=float, default=3.0)
    ap.add_argument("--fps", type=float, default=30.0)
    ap.add_argument("--home", required=True, help=f"flat picture, {FW} x {FH}")
    ap.add_argument("--out", required=True)
    ap.add_argument("--crop-y", type=int, default=0, help="top of the 1920 px window in a taller source")
    ap.add_argument("--grow", type=float, default=3, help="flat px added around the measured lit shape (hides the old screen's edge)")
    ap.add_argument("--sheen", type=float, default=0.05, help="strength of the glass reflection")
    ap.add_argument("--grain", type=float, default=1.6)
    ap.add_argument("--preview", action="store_true", help="only the three stills")
    a = ap.parse_args()
    out = Path(a.out)
    out.parent.mkdir(parents=True, exist_ok=True)
    stem = out.with_suffix("")
    n = int(round(a.dur * a.fps))
    frames = [f[a.crop_y: a.crop_y + OH] for f in read_frames(a.src, a.start, n, a.fps)]
    if frames[0].shape[:2] != (OH, OW):
        raise SystemExit(f"source frames are {frames[0].shape[1]} x {frames[0].shape[0]} after the crop, 1080 x 1920 expected")
    frames = [np.ascontiguousarray(f) for f in frames]
    _, corners, _ = track(frames)
    shape = screen_shape(frames, corners)
    if a.grow >= 1:
        shape = cv2.dilate(shape, cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (3, 3)), iterations=int(round(a.grow)))
    home = cv2.imread(a.home, cv2.IMREAD_COLOR)
    if home is None or home.shape[:2] != (FH, FW):
        raise SystemExit(f"{a.home}: a {FW} x {FH} picture is expected")
    rgba = np.dstack([home.astype(np.float32) / 255 * shape[..., None], shape]).astype(np.float32)
    whites = np.array([white_level(f, q) for f, q in zip(frames, corners)])
    k = np.exp(-0.5 * (np.arange(-6, 7) / 3.0) ** 2)
    whites = np.stack([np.convolve(np.pad(whites[:, c], 6, mode="edge"), k / k.sum(), "valid") for c in range(3)], 1)
    # the old screen is a white field: its level, slightly below clipping, is the exposure of a lit screen here
    gain = np.clip(whites / 255.0, 0.55, 1.0) * 0.97
    yy, xx = np.mgrid[0:OH, 0:OW].astype(np.float32)
    sheen = np.clip(1 - np.abs((xx * 0.55 + yy * 0.84) - 0.42 * (OW * 0.55 + OH * 0.84)) / 260, 0, 1) ** 2  # a soft diagonal band, fixed in the room
    sheen += 0.35 * np.clip(1 - yy / OH, 0, 1)
    rng = np.random.default_rng(3)
    enc = None if a.preview else subprocess.Popen(["ffmpeg", "-v", "error", "-y", "-f", "rawvideo", "-pix_fmt", "bgr24", "-s", f"{OW}x{OH}", "-r", str(a.fps), "-i", "-", "-an", "-c:v", "libx264", "-preset", "slow", "-crf", "14", "-pix_fmt", "yuv420p", "-colorspace", "bt709", "-color_primaries", "bt709", "-color_trc", "bt709", "-movflags", "+faststart", str(out)], stdin=subprocess.PIPE)
    stills = {0: "a", n // 2: "b", n - 1: "c"}
    sheet = []
    S = 2
    up = np.array([[S, 0, (S - 1) / 2], [0, S, (S - 1) / 2], [0, 0, 1]], np.float64)
    for i, f in enumerate(frames):
        if a.preview and i not in stills:
            continue
        hom = flat_to_src(corners[i])
        scr = cv2.warpPerspective(rgba, up @ hom, (OW * S, OH * S), flags=cv2.INTER_CUBIC, borderMode=cv2.BORDER_CONSTANT, borderValue=0)
        scr = np.clip(cv2.resize(scr, (OW, OH), interpolation=cv2.INTER_AREA), 0, 1)
        al = scr[..., 3]
        front = front_matte(f, al, whites[i])
        al_eff = al * (1 - front)
        col = scr[..., :3] * gain[i][None, None, :] * 255
        col += (a.sheen * 255) * sheen[..., None] * al[..., None]  # reflection on the glass, premultiplied by the screen
        col = cv2.GaussianBlur(col, (0, 0), 0.5)
        img = f.astype(np.float32) * (1 - al_eff[..., None]) + col * (1 - front)[..., None]
        # the anti-aliased rim of the old white screen just outside the drawn shape (corners, notch): unmix it, i.e.
        # swap the share of old white of each rim pixel for the same share of the new screen's colour there
        ff = f.astype(np.float32)
        lum, sat = ff.mean(2), ff.max(2) - ff.min(2)
        rim = cv2.dilate((al > 0.02).astype(np.uint8), np.ones((15, 15), np.uint8)).astype(np.float32) * (1 - al)
        bez = float(np.percentile(lum[(rim > 0.5) & (lum < 0.5 * whites[i].mean())], 20)) if ((rim > 0.5) & (lum < 0.5 * whites[i].mean())).any() else 20.0
        c = np.clip((lum - bez) / (whites[i].mean() - bez), 0, 1) * np.clip((40 - sat) / 20, 0, 1) * rim
        under = cv2.warpPerspective(home, hom, (OW, OH), flags=cv2.INTER_LINEAR, borderMode=cv2.BORDER_REPLICATE).astype(np.float32) * gain[i] * 0.97
        img += c[..., None] * (under - whites[i][None, None, :])
        g = cv2.GaussianBlur(rng.standard_normal((OH, OW)).astype(np.float32), (0, 0), 0.6) * a.grain * 1.6
        img = np.clip(img + g[..., None] * al[..., None], 0, 255).round().astype(np.uint8)
        if not a.preview:
            enc.stdin.write(img.tobytes())
        if i in stills:
            cv2.imwrite(f"{stem}-{stills[i]}.png", img)
        if i % max(1, int(round(a.fps * 0.25))) == 0:
            sheet.append(cv2.resize(img, (270, 480), interpolation=cv2.INTER_AREA))
    if a.preview:
        return
    enc.stdin.close()
    if enc.wait() != 0:
        raise SystemExit("ffmpeg failed")
    cols = 6
    sheet += [np.zeros_like(sheet[0])] * (-len(sheet) % cols)
    cv2.imwrite(f"{stem}-sheet.jpg", np.vstack([np.hstack(sheet[r: r + cols]) for r in range(0, len(sheet), cols)]), [cv2.IMWRITE_JPEG_QUALITY, 92])
    print("wrote", out)


if __name__ == "__main__":
    main()
