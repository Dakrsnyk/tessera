// The app icons: Verre rouge (the main icon) and the alternates the person can pick in « Icône de l'app ».
// Each icon is drawn in HTML and rendered by Chromium to 1024 × 1024 PNGs: light, dark and tinted.
//
//   node scripts/app_icons.js <output folder>     (needs Playwright and a Chromium)
//   python3 scripts/app_icons_install.py <output folder>   (asset catalog + previews)
//
// The same geometry as TesseraMark: a band across the top, two tiles below, cream or glass.
const fs = require("fs");
const path = require("path");
const { chromium } = require(process.env.PLAYWRIGHT || "playwright");

const RECTS = [[-90, -90, 1204, 390], [-90, 392, 556, 722], [558, 392, 556, 722]];
const mesh = (base, blobs) => blobs.map(([c, x, y, r]) => `radial-gradient(circle at ${x}% ${y}%, ${c}, transparent ${r}%)`).join(", ") + `, ${base}`;
const glass = (base, a, b, c) => ({ bg: mesh(base, [[a, 12, 92, 65], [b, 95, 8, 60], [c, 85, 85, 45]]), glass: true });

// Asset name → look. Keep in sync with AppIconChoice.all (App/Core/AppIcons.swift).
const icons = {
  "AppIcon": { bg: mesh("#E8443A", [["#FF9A3D", 15, 95, 70], ["#D61F3A", 90, 5, 60], ["#FFB36B", 85, 85, 45]]), glass: true },
  "AppIcon-Classic": { classic: true },
  "AppIcon-Jade": { bg: mesh("#1F8F78", [["#7FE0C4", 10, 90, 65], ["#0E5C4C", 95, 10, 60], ["#3FD0A8", 80, 80, 45]]), glass: true },
  "AppIcon-Night": { bg: mesh("#241B5C", [["#7B5CFF", 15, 85, 60], ["#0B0A2A", 95, 5, 60], ["#E0479E", 90, 95, 45]]), glass: true },
  "AppIcon-Blue": { bg: mesh("#2563EB", [["#7C3AED", 90, 90, 60], ["#38BDF8", 10, 5, 55], ["#4F46E5", 20, 95, 50]]), glass: true },
  "AppIcon-Ocean": glass("#1550C8", "#3FD7FF", "#0A1F66", "#2E8BFF"),
  "AppIcon-Coral": glass("#F25C54", "#FFB38A", "#E0306A", "#FF8A6B"),
  "AppIcon-Emerald": glass("#119A5A", "#9BEA5C", "#065A3A", "#2FD18A"),
  "AppIcon-Amethyst": glass("#7B2FD6", "#E85CC8", "#3A0F7A", "#A45CFF"),
  "AppIcon-Amber": glass("#E8892A", "#FFD45C", "#B4511A", "#FFB03D"),
  "AppIcon-Lagoon": glass("#0E9AA7", "#7FF0E0", "#0B4F6C", "#2CD4C6"),
  "AppIcon-Raspberry": glass("#D6245E", "#FF7AB0", "#6E1048", "#F04B8A"),
  "AppIcon-Midnight": { bg: mesh("#0E1430", [["#2B4CFF", 15, 90, 55], ["#05070F", 95, 5, 60], ["#5A3CFF", 90, 95, 40]]), glass: true },
  "AppIcon-Aurora": { bg: mesh("#123E5C", [["#3DF2A0", 10, 90, 60], ["#7A3CFF", 95, 10, 55], ["#1FC8D8", 60, 70, 45]]), glass: true },
  "AppIcon-Sakura": { ...glass("#F3A6C8", "#FFD6E6", "#B79CFF", "#FFB8D2"), allClear: true },
  "AppIcon-Forest": glass("#1E5A3C", "#8FB54A", "#0B2A1C", "#3E8A55"),
  "AppIcon-Graphite": glass("#4A5160", "#AEB8C8", "#1C2028", "#7A8598"),
};

const u = (v) => `${v}px`;
function tileStyle(kind, dark) {
  const shadow = `0 20px 50px rgba(0,0,0,${dark ? 0.3 : 0.18})`;
  if (kind === "clear") return `background:linear-gradient(160deg, rgba(255,255,255,${dark ? 0.3 : 0.55}), rgba(255,255,255,${dark ? 0.08 : 0.18}));backdrop-filter:blur(30px) saturate(1.4);box-shadow:inset 0 6px 0 rgba(255,255,255,${dark ? 0.45 : 0.75}), inset 0 0 0 4px rgba(255,255,255,${dark ? 0.2 : 0.35}), ${shadow};`;
  return `background:linear-gradient(160deg, rgba(20,16,30,${dark ? 0.65 : 0.55}), rgba(10,8,16,${dark ? 0.85 : 0.78}));backdrop-filter:blur(30px);box-shadow:inset 0 6px 0 rgba(255,255,255,${dark ? 0.18 : 0.28}), inset 0 0 0 4px rgba(255,255,255,0.12), ${shadow};`;
}
const classicFills = ["linear-gradient(#F04B4D, #D62F33)", "linear-gradient(#FF9D55, #F5782C)", "linear-gradient(#2B2223, #0E0C0C)"];
const tintedFills = ["linear-gradient(#FFFFFF, #E8E8E8)", "linear-gradient(#C9C9C9, #B5B5B5)", "linear-gradient(#7A7A7A, #626262)"];

function html(icon, variant) {
  const dark = variant === "dark";
  let bg; let tiles;
  if (variant === "tinted") {
    bg = "#000";
    tiles = RECTS.map((r, i) => `background:${tintedFills[i]};`);
  } else if (icon.classic) {
    bg = dark ? "linear-gradient(135deg, #2E2829, #141112)" : "linear-gradient(135deg, #FBF8F3, #EAE3D8)";
    tiles = RECTS.map((r, i) => `background:${classicFills[i]};`);
  } else {
    bg = icon.bg;
    tiles = RECTS.map((r, i) => tileStyle(i === 2 && !icon.allClear ? "smoke" : "clear", dark));
  }
  const parts = RECTS.map(([x, y, w, h], i) => `<i style="left:${u(x)};top:${u(y)};width:${u(w)};height:${u(h)};border-radius:${u(64)};${tiles[i]}"></i>`).join("");
  const veil = dark && !icon.classic && variant !== "tinted" ? `<b class="veil"></b>` : "";
  const sheen = variant === "tinted" || icon.classic ? "" : `<b class="sheen"></b>`;
  return `<!doctype html><html><head><meta charset="utf-8"><style>
html, body { margin: 0; background: #000; }
.icon { position: relative; overflow: hidden; width: 1024px; height: 1024px; isolation: isolate; }
.icon i, .icon b { position: absolute; display: block; }
.veil { inset: 0; background: rgba(0,0,0,.42); }
.sheen { inset: 0; background: linear-gradient(180deg, rgba(255,255,255,${dark ? 0.06 : 0.16}), transparent 38%); }
</style></head><body><div class="icon" style="background:${bg}">${veil}${parts}${sheen}</div></body></html>`;
}

(async () => {
  const out = process.argv[2];
  if (!out) throw new Error("usage: node scripts/app_icons.js <output folder>");
  fs.mkdirSync(out, { recursive: true });
  const browser = await chromium.launch(process.env.CHROMIUM ? { executablePath: process.env.CHROMIUM } : {});
  const page = await browser.newPage({ viewport: { width: 1024, height: 1024 }, deviceScaleFactor: 1 });
  for (const [name, icon] of Object.entries(icons)) {
    for (const variant of ["light", "dark", "tinted"]) {
      await page.setContent(html(icon, variant));
      await page.waitForTimeout(80);
      await (await page.$(".icon")).screenshot({ path: path.join(out, `${name}-${variant}.png`) });
    }
    console.log(name);
  }
  await browser.close();
})();
