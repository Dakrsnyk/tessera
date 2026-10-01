"""Review sheets and animated previews of exported demonstrations."""
import json
import subprocess
import sys
from pathlib import Path

from playwright.sync_api import sync_playwright

from render import DARK, LIGHT, Player

OUT = Path(__file__).parent / "out"
OUT.mkdir(exist_ok=True)


def sheet(datas, path, phases=(0.0, 0.5, 1.0), W=300, H=210, dark=False, names=None, problems=None):
    palette = DARK if dark else LIGHT
    rows = []
    for data in datas:
        player = Player(data)
        cells = []
        phs = (0.0, 0.25, 0.5, 0.75) if data["loop"] else phases
        if data["labels"] and len(data["timeline"]) > 4:
            phs = sorted(set(round(seg[1], 3) for seg in data["timeline"]))
        for vi, v in enumerate(data["views"]):
            for p in phs:
                cells.append(f'<div class="cell">{player.svg(p, vi, W, H, palette)}<div class="cap">{v["name"]} · p={p:g}</div></div>')
        title = data["id"] + (f" — {names[data['id']]}" if names and data["id"] in names else "")
        probs = ""
        if problems and problems.get(data["id"]):
            probs = '<div class="prob">' + "<br>".join(problems[data["id"]]) + "</div>"
        rows.append(f'<div class="row"><div class="title">{title}</div>{probs}<div class="cells">{"".join(cells)}</div></div>')
    html = f"""<html><head><meta charset="utf-8"><style>
    body {{ margin: 0; padding: 16px; background: {'#000' if dark else '#fff'}; font-family: -apple-system, Helvetica, sans-serif; color: {'#eee' if dark else '#222'}; }}
    .row {{ margin-bottom: 18px; }}
    .title {{ font-weight: 700; font-size: 15px; margin: 4px 0 6px; }}
    .prob {{ color: #d00; font-size: 12px; margin-bottom: 4px; }}
    .cells {{ display: flex; flex-wrap: wrap; gap: 8px; }}
    .cell {{ display: flex; flex-direction: column; align-items: center; }}
    .cap {{ font-size: 11px; opacity: 0.6; }}
    </style></head><body>{''.join(rows)}</body></html>"""
    html_path = Path(path).with_suffix(".html")
    html_path.write_text(html)
    with sync_playwright() as pw:
        browser = pw.chromium.launch()
        page = browser.new_page(viewport={"width": 1600, "height": 900}, device_scale_factor=1)
        page.goto("file://" + str(html_path))
        page.screenshot(path=str(path), full_page=True)
        browser.close()
    return path


def animation(data, path, view=0, W=390, H=260, fps=20, dark=False, scale=2):
    """An MP4/GIF of one loop, as the app plays it."""
    palette = DARK if dark else LIGHT
    player = Player(data)
    frames_dir = Path(path).with_suffix("")
    frames_dir.mkdir(exist_ok=True, parents=True)
    count = int(player.duration * fps)
    labels = data["labels"]
    html_frames = []
    for i in range(count):
        t = i / fps
        p, label = player.phase_at(t)
        svg = player.svg(p, view, W, H, palette)
        cap = labels[label] if labels and label >= 0 else ""
        html_frames.append((svg, cap))
    with sync_playwright() as pw:
        browser = pw.chromium.launch()
        page = browser.new_page(viewport={"width": W, "height": H + 30}, device_scale_factor=scale)
        for i, (svg, cap) in enumerate(html_frames):
            page.set_content(f'<html><body style="margin:0;background:{"#000" if dark else "#fff"};font-family:Helvetica">{svg}'
                             f'<div style="height:30px;text-align:center;font-size:14px;color:#888">{cap}</div></body></html>')
            page.screenshot(path=str(frames_dir / f"f{i:04d}.png"))
        browser.close()
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-framerate", str(fps), "-i", str(frames_dir / "f%04d.png"),
                    "-vf", "split[a][b];[a]palettegen[p];[b][p]paletteuse", str(path)], check=True)
    return path
