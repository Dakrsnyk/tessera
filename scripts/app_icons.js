// The app icons: the main icon (Corail, the Ardane logo) and the alternates the person can pick in
// « Icône de l'app ». Each icon is drawn in SVG and rendered by Chromium to 1024 × 1024 PNGs, light
// and tinted: the icons stay light when the iPhone is in Dark Mode (app_icons_install.py puts the
// light picture in both slots).
//
//   node scripts/app_icons.js <output folder> [--sheet]   (needs Playwright and a Chromium)
//   python3 scripts/app_icons_install.py <output folder>   (asset catalog + previews)
//
// The mark: an A in two halves split by a narrow gap (left half and right half of two tones).
// The glass icons keep the colors of the former Tessera icons: a clear half and a smoked half on a
// colored mesh, with the same sheen.
const fs = require("fs");
const path = require("path");
const { chromium } = require(process.env.PLAYWRIGHT || "playwright");

// The two halves, in a 100 × 100 box (the B19 logo).
const LEFT = "M47.5 19.3 L47.5 55.4 L34 86 H16 Z";
const RIGHT = "M52.5 19.3 L84 86 H66 L52.5 55.4 Z";
const mesh = (base, blobs) => blobs.map(([c, x, y, r]) => `radial-gradient(circle at ${x}% ${y}%, ${c}, transparent ${r}%)`).join(", ") + `, ${base}`;
const glass = (base, a, b, c) => ({ bg: mesh(base, [[a, 12, 92, 65], [b, 95, 8, 60], [c, 85, 85, 45]]), glass: true });

// Asset name → look. Keep in sync with AppIconChoice.all (App/Core/AppIcons.swift).
const icons = {
  "AppIcon": { bg: "linear-gradient(160deg, #FF7A59, #D9246A)", left: ["#FFFFFF", "#FFFFFF"], right: ["#FFE0CC", "#FFE0CC"] },
  "AppIcon-Classic": { bg: "linear-gradient(135deg, #FBF8F3, #EAE3D8)", left: ["#F04B4D", "#F5782C"], right: ["#2B2223", "#0E0C0C"] },
  // Glass on white: glossy halves, black and cyan.
  "AppIcon-GlassBlack": { bg: "linear-gradient(160deg, #FFFFFF, #E9EDF2)", gloss: true, left: ["#3A3F47", "#07090C"], right: ["#7DF4FF", "#00AFCF"] },
  "AppIcon-RedGlass": { bg: mesh("#E8443A", [["#FF9A3D", 15, 95, 70], ["#D61F3A", 90, 5, 60], ["#FFB36B", 85, 85, 45]]), glass: true },
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

function grad(id, [a, b]) {
  return `<linearGradient id="${id}" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="${a}"/><stop offset="1" stop-color="${b}"/></linearGradient>`;
}

function svg(icon, variant) {
  const defs = [];
  let halves;
  if (variant === "tinted") {
    defs.push(grad("l", ["#FFFFFF", "#E8E8E8"]), grad("r", ["#9A9A9A", "#7E7E7E"]));
    halves = `<path d="${LEFT}" fill="url(#l)"/><path d="${RIGHT}" fill="url(#r)"/>`;
  } else if (icon.glass) {
    // A clear glass half and a smoked one (both clear for the pale icons), like the former tiles.
    const smoke = !icon.allClear;
    defs.push(
      `<linearGradient id="clear" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#fff" stop-opacity=".62"/><stop offset="1" stop-color="#fff" stop-opacity=".2"/></linearGradient>`,
      `<linearGradient id="smoke" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#14101E" stop-opacity=".55"/><stop offset="1" stop-color="#0A0810" stop-opacity=".8"/></linearGradient>`,
      `<filter id="shadow" x="-30%" y="-30%" width="160%" height="160%"><feDropShadow dx="0" dy="2" stdDeviation="2.4" flood-color="#000" flood-opacity=".22"/></filter>`
    );
    const half = (d, fill, edge) => `<path d="${d}" fill="${fill}" filter="url(#shadow)"/><path d="${d}" fill="none" stroke="#fff" stroke-opacity="${edge}" stroke-width=".7"/>`;
    halves = half(LEFT, "url(#clear)", 0.75) + half(RIGHT, smoke ? "url(#smoke)" : "url(#clear)", smoke ? 0.22 : 0.75);
  } else if (icon.gloss) {
    // Classic colors made of glass: each half glossy, lit from the top, with a bright rim and a soft
    // shadow on the white ground.
    defs.push(grad("l", icon.left), grad("r", icon.right),
      `<linearGradient id="shine" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#fff" stop-opacity=".55"/><stop offset=".45" stop-color="#fff" stop-opacity=".08"/><stop offset="1" stop-color="#fff" stop-opacity="0"/></linearGradient>`,
      `<filter id="soft" x="-30%" y="-30%" width="160%" height="160%"><feDropShadow dx="0" dy="2.6" stdDeviation="2.6" flood-color="#0B1A2A" flood-opacity=".28"/></filter>`);
    const half = (d, fill) => `<path d="${d}" fill="${fill}" filter="url(#soft)"/><path d="${d}" fill="url(#shine)"/><path d="${d}" fill="none" stroke="#fff" stroke-opacity=".7" stroke-width=".6"/>`;
    halves = half(LEFT, "url(#l)") + half(RIGHT, "url(#r)");
  } else {
    defs.push(grad("l", icon.left), grad("r", icon.right));
    halves = `<path d="${LEFT}" fill="url(#l)"/><path d="${RIGHT}" fill="url(#r)"/>`;
  }
  return `<svg viewBox="0 0 100 100" width="1024" height="1024"><defs>${defs.join("")}</defs>${halves}</svg>`;
}

function html(icon, variant) {
  const bg = variant === "tinted" ? "#000" : icon.bg;
  const sheen = icon.glass && variant !== "tinted" ? `<b class="sheen"></b>` : "";
  return `<!doctype html><html><head><meta charset="utf-8"><style>
html, body { margin: 0; background: #000; }
.icon { position: relative; overflow: hidden; width: 1024px; height: 1024px; }
.icon svg, .icon b { position: absolute; inset: 0; display: block; }
.sheen { background: linear-gradient(180deg, rgba(255,255,255,.16), transparent 38%); }
</style></head><body><div class="icon" style="background:${bg}">${svg(icon, variant)}${sheen}</div></body></html>`;
}

(async () => {
  const out = process.argv[2];
  if (!out) throw new Error("usage: node scripts/app_icons.js <output folder> [--sheet]");
  fs.mkdirSync(out, { recursive: true });
  const browser = await chromium.launch(process.env.CHROMIUM ? { executablePath: process.env.CHROMIUM } : {});
  const page = await browser.newPage({ viewport: { width: 1024, height: 1024 }, deviceScaleFactor: 1 });
  for (const [name, icon] of Object.entries(icons)) {
    for (const variant of ["light", "tinted"]) {
      await page.setContent(html(icon, variant));
      await page.waitForTimeout(60);
      await (await page.$(".icon")).screenshot({ path: path.join(out, `${name}-${variant}.png`) });
    }
    console.log(name);
  }
  await browser.close();
})();
