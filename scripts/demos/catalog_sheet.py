"""Review sheet of some demonstrations, as PNG (for the new movements of the triage, 2026-11-23).

    ~/ardane-tools/venv/Scripts/python.exe scripts/demos/catalog_sheet.py out/lot01.png x-snatch x-floor-press …

Samples each demonstration with the engine (registered in ex_*.py), prints the engine's problems (bones too short, limbs
in the floor or in the equipment…), and draws 4 phases per view; the picture is taken by the Playwright of
~/ardane-tools/dl-venv (this Python has none).
"""
import glob
import importlib
import json
import os
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import demos  # noqa: E402
from render import DARK, Player  # noqa: E402

for path in sorted(glob.glob(str(HERE / "ex_*.py"))):
    importlib.import_module(Path(path).stem)

SHOT = """
import sys
from playwright.sync_api import sync_playwright
src, out = sys.argv[1], sys.argv[2]
with sync_playwright() as pw:
    b = pw.chromium.launch(); pg = b.new_page(viewport={'width': 1300, 'height': 600}); pg.goto('file:///' + src)
    pg.screenshot(path=out, full_page=True); b.close()
"""


def main():
    out, ids = sys.argv[1], sys.argv[2:]
    rows = []
    for ident in ids:
        d = demos.DEMOS.get(ident)
        if d is None:
            print(ident, "| NOT REGISTERED")
            continue
        scenes = demos.sample(d)
        problems = demos.check(d, scenes)
        print(ident, "|", "; ".join(problems) if problems else "ok")
        data = demos.export(d, scenes)
        player = Player(data)
        phases = (0.0, 0.25, 0.5, 0.75) if data["loop"] else (0.0, 0.35, 0.65, 1.0)
        cells = "".join(f'<div class="c">{player.svg(p, vi, 230, 170, DARK)}</div>'
                        for vi in range(len(data["views"])) for p in phases)
        rows.append(f'<div class="r"><div class="t">{ident}</div><div class="cs">{cells}</div></div>')
    html = ('<html><head><meta charset="utf-8"><style>body{background:#0d0e11;color:#ddd;font-family:Helvetica;margin:10px;width:1270px}'
            '.r{margin:8px 0}.t{font-size:14px;margin:2px}.cs{display:flex;flex-wrap:wrap;gap:4px}</style></head><body>'
            + "".join(rows) + "</body></html>")
    out = str(Path(out).resolve())
    src = out[:-4] + ".html"
    Path(src).write_text(html, encoding="utf-8")
    shooter = Path(os.path.expanduser("~")) / "ardane-tools" / "dl-venv" / "Scripts" / "python.exe"
    subprocess.run([str(shooter), "-c", SHOT, src.replace("\\", "/"), out], check=True)
    print("sheet:", out)


if __name__ == "__main__":
    main()
