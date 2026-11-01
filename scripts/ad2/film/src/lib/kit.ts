// The real pieces of the ad kit (pub/kit, copied to public/kit) and where they sit, measured by
// scripts/ad2/kit_layout.py on the Home Screens the app drew itself (px of the 1206 × 2622 capture).
import { getStaticFiles, staticFile } from "remotion";
import * as THREE from "three";
import { H, W } from "./brand";

export type Rect = [number, number, number, number];

/** The hero Home Screen: macros M, nextSet M, budgetLeft S + priorities S on a real Store setup. */
export const HERO_WIDGETS: { kind: string; index: number; rect: Rect }[] = [
  { kind: "macros", index: 0, rect: [57, 204, 1092, 510] },
  { kind: "nextSet", index: 1, rect: [57, 813, 1092, 510] },
  { kind: "budgetLeft", index: 2, rect: [57, 1422, 510, 510] },
  { kind: "priorities", index: 3, rect: [638, 1421, 510, 510] },
];
/** Dock icons (indexes 4–7 of icons-<setup>.json), the same slots in every setup. */
export const DOCK: Rect[] = [
  [64, 2340, 222, 222],
  [349, 2340, 222, 222],
  [635, 2340, 222, 222],
  [920, 2340, 222, 222],
];

/** The universes of S2, in the film's order: Aurora → Space → Paper → Neon → Minimal → Sunset. */
export const UNIVERSES = [
  { id: "aurore", wall: "wall-aurora.png", name: "Aurora" },
  { id: "espace", wall: "wall-midnight.png", name: "Space" },
  { id: "etudes", wall: "wall-paper.png", name: "Paper" },
  { id: "neon", wall: "wall-synthwave.png", name: "Neon" },
  { id: "graphite", wall: "wall-graphite.png", name: "Minimal" },
  { id: "crepuscule", wall: "wall-sunset.png", name: "Sunset" },
] as const;
export type UniverseId = (typeof UNIVERSES)[number]["id"];

// ---------------------------------------------------------------------------------------------------------
// THE ONE PLACE where a capture of the app is turned into a file (chantier 19.4). Everything that shows a
// picture of the app asks for it by NAME (`kitSrc("home-hero-aurore")`) or by the legacy `kit/<name>.png`
// path through `asset()`; nothing else knows where the files live. Look-up order:
//   1. public/kit2026/<lang>/<name>.png   (the new kit: app captured in Saphir, in the film's language)
//   2. public/kit2026/<other lang>/<name>.png
//   3. the same with the name's declared alternatives (ALTERNATIVES) or its legacy alias (LEGACY)
//   4. public/kit/<name>.png              (the old kit: kept as is, never modified)
//   5. a labelled stand-in frame « à capturer : <name> » (a data URI), so a missing capture never stops a render.
// `python scripts/ad2/render_all.py check-assets` lists what is still missing (src/check_assets.mjs).
// ---------------------------------------------------------------------------------------------------------
export type KitLang = "fr" | "en";
let kitLang: KitLang = "fr";
/** Set by FormatFrame at every render: the language of the kit to read. */
export const setKitLang = (lang: KitLang) => {
  kitLang = lang;
};
export const KIT_DIR = "kit2026";
export const OLD_KIT_DIR = "kit";

/** Names of the old kit that the new kit calls differently (the new one is preferred when it exists). */
const LEGACY: Record<string, string> = {
  "session-0-dark": "app-fitness-session-dark",
  "session-1-dark": "app-fitness-session-end-dark",
  "lib-0-dark": "app-fitness-library-dark",
  "ex-0-dark": "app-fitness-exercise-bench-press-dark",
  "nut-0-dark": "app-nutrition-s00-dark",
  "hab-0-dark": "app-planning-habits-dark",
  "plan-0-dark": "app-planning-week-dark",
  "plan-1-dark": "app-planning-week-dark",
};
/** A name that may stand in for another until the real capture exists (same subject, other style or state). */
const ALTERNATIVES: Record<string, string[]> = {
  "scan-chrome-dark": ["scan-frame-dark"],
  "scan-chrome-light": ["scan-frame"],
  "macros-m-minimal": ["macros-m-light"],
  "home-free3": ["home-hero-graphite"],
  "home-profile-athlete": ["home-hero-neon"],
  "home-profile-student": ["home-hero-etudes"],
  "home-profile-minimal": ["home-hero-graphite"],
  "home-complete-aurore": ["home-hero-aurore"],
  "home-complete-espace": ["home-hero-espace"],
  "lock-graphite": ["lock-minuit"],
  "lock-espace": ["lock-minuit"],
  "scan-recap-photo": ["scan-recap"],
  "nutrition-plan": ["profile-targets"],
  "mywidgets": ["editor-v2", "studio-content"],
  "app-nutrition-s00": ["app-nutrition-s00-dark"],
  "app-fitness-progress": ["app-fitness-s03"],
  "nextSet-m-dark": ["nextSet-s-luxury"],
  "calories-m-dark": ["calories-m-aurora"],
  "budgetLeft-m-dark": ["budgetLeft-s-dark"],
};

let staticSet: Set<string> | null = null;
const has = (path: string) => {
  if (!staticSet) {
    try {
      staticSet = new Set(getStaticFiles().map((f) => f.name));
    } catch {
      staticSet = new Set();
    }
  }
  return staticSet.has(path);
};
const otherLang = (l: KitLang): KitLang => (l === "fr" ? "en" : "fr");

/** Which kit serves `name` (for check_assets and the Studio): "new" | "other-lang" | "alt" | "old" | "missing". */
export const kitResolve = (name: string, lang: KitLang = kitLang): { path: string | null; source: "new" | "other-lang" | "alt" | "old" | "missing" } => {
  const names = [name, ...(LEGACY[name] ? [LEGACY[name]] : []), ...(ALTERNATIVES[name] ?? [])];
  // the name itself first, in the new kit then the old, then its alternatives: a real capture beats a stand-in
  for (const [i, n] of names.entries()) {
    const src = i === 0 ? "new" : "alt";
    const a = `${KIT_DIR}/${lang}/${n}.png`;
    if (has(a)) return { path: a, source: src };
    const b = `${KIT_DIR}/${otherLang(lang)}/${n}.png`;
    if (has(b)) return { path: b, source: i === 0 ? "other-lang" : "alt" };
  }
  // The English film never falls back to the old (French) kit: a gap shows as a labelled stand-in and is logged.
  if (lang === "en") {
    console.warn(`[kit-missing-en] ${name}`);
    return { path: null, source: "missing" };
  }
  for (const n of names) {
    const c = `${OLD_KIT_DIR}/${n}.png`;
    if (has(c)) return { path: c, source: n === name ? "old" : "alt" };
  }
  return { path: null, source: "missing" };
};

/** A stand-in frame, its proportions guessed from the name (screens 1206 × 2622, medium widgets 1092 × 510, small 680 × 680…). */
const placeholder = (name: string) => {
  let w = 1206;
  let h = 2622;
  if (/-m-/.test(name)) [w, h] = [1092, 510];
  else if (/-s-/.test(name)) [w, h] = [680, 680];
  else if (/-l-/.test(name)) [w, h] = [1092, 1146];
  else if (/^lock-.*-(rect)/.test(name)) [w, h] = [688, 304];
  else if (/^lock-.*-(circular)/.test(name)) [w, h] = [288, 288];
  else if (/^live-/.test(name)) [w, h] = [1116, 465];
  else if (/^demo-/.test(name)) [w, h] = [1608, 944];
  else if (/^myday-tall/.test(name)) [w, h] = [1206, 5519];
  const f = Math.round(Math.min(w, h) / 14);
  const svg = `<svg xmlns="http://www.w3.org/2000/svg" width="${w}" height="${h}" viewBox="0 0 ${w} ${h}"><defs><linearGradient id="g" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#1B4A7A"/><stop offset="1" stop-color="#07101C"/></linearGradient></defs><rect width="${w}" height="${h}" rx="${Math.round(Math.min(w, h) / 12)}" fill="url(#g)"/><rect x="14" y="14" width="${w - 28}" height="${h - 28}" rx="${Math.round(Math.min(w, h) / 14)}" fill="none" stroke="#68B5F5" stroke-width="6" stroke-dasharray="28 18"/><text x="50%" y="46%" text-anchor="middle" font-family="Inter Ardane, Arial, sans-serif" font-weight="700" font-size="${f}" fill="#D6E9FA">à capturer</text><text x="50%" y="${Math.round(h * 0.46 + f * 1.4)}" text-anchor="middle" font-family="Inter Ardane, Arial, sans-serif" font-size="${Math.round(f * 0.62)}" fill="#A1A1A6">${name.replace(/&/g, "&amp;").replace(/</g, "&lt;")}</text></svg>`;
  return `data:image/svg+xml;charset=utf-8,${encodeURIComponent(svg)}`;
};

/**
 * THE helper: path (for staticFile) of a capture by name, in the film's language, or null when no kit has it (neither
 * kit2026 nor the old kit nor a declared alternative). Names may carry `.png` or the legacy `kit/` prefix.
 */
export const kitSrc = (name: string, lang: KitLang = kitLang): string | null => {
  const bare = name.replace(/^kit\//, "").replace(/\.png$/, "");
  return kitResolve(bare, lang).path;
};
/** URL of a capture for an <img>: the file, or a labelled stand-in « à capturer » so a missing capture never stops a render. */
export const kitUrl = (name: string, lang: KitLang = kitLang): string => {
  const p = kitSrc(name, lang);
  return p ? staticFile(p) : placeholder(name.replace(/^kit\//, "").replace(/\.png$/, ""));
};
/** Any file of public/: `kit/<name>.png` goes through the kit look-up, the rest is a plain static file. */
export const asset = (path: string): string => (path.startsWith("kit/") ? kitUrl(path) : staticFile(path));
/** `demo-bench-press-dark-0012` from ("demo-bench-press-dark", 12). */
export const seqName = (base: string, i: number, digits = 4) => `${base}-${String(Math.max(0, Math.round(i))).padStart(digits, "0")}`;

export const k = (file: string) => `kit/${file}`;
export const heroHome = (u: string) => k(`home-hero-${u}.png`);
export const heroWidget = (u: string, index: number) => k(`setup-hero-${u}-${index}.png`);
export const dockIcon = (u: string, slot: number) => k(`icons-${u}-${slot + 4}.png`);
export const wall = (u: string) => k(UNIVERSES.find((x) => x.id === u)!.wall);

/** Every file of one universe (home, its four widgets, its dock icons, its wallpaper). */
export const universeFiles = (u: string) => [
  heroHome(u),
  wall(u),
  ...HERO_WIDGETS.map((w) => heroWidget(u, w.index)),
  ...DOCK.map((_, i) => dockIcon(u, i)),
];

/** Screen pixel of a world point, for a camera at `position` looking at `target` with a `lens` (mm). */
export const project = (point: THREE.Vector3, position: THREE.Vector3, target: THREE.Vector3, lens: number) => {
  const cam = new THREE.PerspectiveCamera(THREE.MathUtils.radToDeg(2 * Math.atan(18 / lens)), W / H, 40, 5000);
  cam.position.copy(position);
  cam.up.set(0, 1, 0);
  cam.lookAt(target);
  cam.updateMatrixWorld(true);
  cam.updateProjectionMatrix();
  const p = point.clone().project(cam);
  return [((p.x + 1) / 2) * W, ((1 - p.y) / 2) * H] as [number, number];
};
