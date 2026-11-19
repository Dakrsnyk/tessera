import { INTER } from "./brand";

/**
 * A REAL iPhone Home Screen for every film (demande du PDG du 2026-11-11, docs/memoire/campagne-2026/16-vraies-icones-ios.md):
 * the grid measured on the simulator's capture (iPhone 16 Pro, 1206 x 2622 @3x, same numbers as avantapres/screens.ts) and
 * the real Apple app icons cut from that capture (public/apple-icons/<Name>.png, 188 px, transparent corners).
 * Only these 10 apps exist on the simulator: never another one, never a redrawn one, never twice on a screen (Dock included).
 */
export type Rect = [number, number, number, number];

export const IOS = {
  w: 1206,
  h: 2622,
  left: 81,
  right: 638,
  top: 272,
  /** a pair of rows: a small widget is 2 x 2 cells */
  pair: 602,
  small: 489,
  medium: [1046, 489] as [number, number],
  large: [1046, 1098] as [number, number],
  icon: 188,
  iconLeft: 92.5,
  iconStep: 277.7,
  rowStep: 301,
  dockTop: 2263,
  dockIconTop: 2322,
  /** corner radius of the screen (capture px) */
  radius: 165,
};

/** Page 1 and Dock of the simulator, then (2026-11-19, [ios-home] run 479) its page 2: Fitness, Watch, Contacts, Files, Preview.
 * (The Utilities folder of page 2 is cut too but is see-through: it shows the simulator's wallpaper, never use it.) */
export const APPLE_APPS = ["Calendar", "Photos", "Reminders", "News", "Maps", "Health", "Wallet", "Settings", "Safari", "Messages", "Fitness", "Watch", "Contacts", "Files", "Preview"] as const;
export type AppleApp = (typeof APPLE_APPS)[number];
export const appleIcon = (name: string) => `apple-icons/${name}.png`;
/** The Dock of every film (always the same phone: only the apps of the grid change with the widgets). */
export const IOS_DOCK: AppleApp[] = ["Messages", "Safari", "Photos", "Settings"];
export const dockIconFiles = (dock: string[] = IOS_DOCK) => dock.map(appleIcon);

/** Top-left corner of the icon of cell (c 0..3, r 0..5). */
export const iconXY = (c: number, r: number): [number, number] => [IOS.iconLeft + IOS.iconStep * c, IOS.top + r * IOS.rowStep];
/** x of the i-th of n Dock icons: 4 icons sit on the grid's columns, fewer are centred 264 px apart (measured). */
export const dockX = (i: number, n: number) => (n === 4 ? iconXY(i, 0)[0] : IOS.w / 2 - IOS.icon / 2 + (i - (n - 1) / 2) * 264);

/** Widget rect of the iOS grid: size s / m / l, column 0 or 2, row 0..5 (even rows: a widget starts on a pair). */
export const iosRect = (size: "s" | "m" | "l", c: 0 | 2, r: number): Rect => {
  const x = c === 0 ? IOS.left : IOS.right;
  const y = IOS.top + (r / 2) * IOS.pair;
  if (size === "s") return [x, y, IOS.small, IOS.small];
  if (size === "m") return [IOS.left, y, ...IOS.medium];
  return [IOS.left, y, ...IOS.large];
};

const snap = (v: number, targets: number[], tol: number) => {
  for (const t of targets) if (Math.abs(v - t) <= tol) return t;
  return v;
};
/**
 * The old geometry of the kit (the app's own Home captures: x 57 / 638, rows every 609 from y 204, M 1092 x 510) to the measured
 * iOS grid: x' = 81 + (x - 57) * 0.9579, y' = 272 + (y - 204) * 0.98851, w' = w * 0.9579, h' = h * 0.9579, snapped to the grid.
 */
export const toIOS = ([x, y, w, h]: Rect): Rect => {
  const nx = snap(81 + (x - 57) * 0.9579, [IOS.left, IOS.right], 4);
  const ny = snap(272 + (y - 204) * 0.98851, [0, 1, 2, 3, 4, 5].map((r) => IOS.top + r * IOS.rowStep), 5);
  const nw = snap(w * 0.9579, [IOS.small, IOS.medium[0]], 4);
  const nh = snap(h * 0.9579, [IOS.small, IOS.large[1]], 4);
  return [nx, ny, nw, nh];
};

/** Free icon cells (row by row, top to bottom) of a Home whose widgets sit at `rects` (iOS geometry). */
export const freeCells = (rects: Rect[]): [number, number][] => {
  const out: [number, number][] = [];
  for (let r = 0; r < 6; r++)
    for (let c = 0; c < 4; c++) {
      const [x, y] = iconXY(c, r);
      const s = IOS.icon;
      const hit = rects.some(([rx, ry, rw, rh]) => x < rx + rw - 2 && x + s > rx + 2 && y < ry + rh - 2 && y + s > ry + 2);
      if (!hit) out.push([c, r]);
    }
  return out;
};

/** The apps of the grid, in the order that suits the Home's widgets (sport → Health first, money → Wallet, planning → Calendar). */
export const appsFor = (files: string[]): AppleApp[] => {
  const n = files.join(" ");
  const score = (re: RegExp) => (n.match(re) ?? []).length;
  const themes: [number, AppleApp[]][] = [
    [score(/budget|money|spending|business|expense|currency|sales/gi), ["Wallet", "News", "Calendar", "Reminders", "Maps", "Health", "Files", "Contacts", "Preview", "Watch", "Fitness"]],
    [score(/workout|nextSet|training|rest|volume|steps|activity/gi), ["Health", "Maps", "Calendar", "Reminders", "News", "Wallet", "Fitness", "Watch", "Files", "Contacts", "Preview"]],
    [score(/macros|calories|quickFood|meal|water|nutri/gi), ["Health", "Reminders", "Calendar", "Maps", "News", "Wallet", "Fitness", "Watch", "Files", "Contacts", "Preview"]],
    [score(/timetable|week|upNext|task|priorit|habit|month|countdown|moon|birthday|flight|hotel|trip|localTime|quote/gi), ["Calendar", "Reminders", "Maps", "News", "Health", "Wallet", "Contacts", "Files", "Preview", "Watch", "Fitness"]],
  ];
  themes.sort((a, b) => b[0] - a[0]);
  return themes[0][0] > 0 ? themes[0][1] : ["Calendar", "Reminders", "Health", "Wallet", "Maps", "News", "Contacts", "Files", "Watch", "Preview", "Fitness"];
};

export type IosIcon = { x: number; y: number; name: string };
/**
 * Every free cell gets a real app, never one of the Dock, never twice; when the 6 apps of the grid are used up the last cells
 * stay empty (better a few empty cells at the bottom than a crowded screen). `max` above 6 also uses the 5 apps of page 2 (each
 * theme list keeps its first 6 apps unchanged, so the Homes made before stay identical).
 */
export const iosFill = (rects: Rect[], files: string[], dock: string[] = IOS_DOCK, max = 6): IosIcon[] => {
  const pool = appsFor(files).filter((a) => !dock.includes(a));
  return freeCells(rects)
    .slice(0, Math.min(max, pool.length))
    .map(([c, r], i) => {
      const [x, y] = iconXY(c, r);
      return { x, y, name: pool[i] };
    });
};
export const iconFiles = (icons: IosIcon[]) => icons.map((i) => appleIcon(i.name));

/** Tint of the Dock and the Search pill (iOS: frosted glass, tinted by the wallpaper). */
export const glassTint = (dark: boolean, glass?: boolean) =>
  glass ? { fill: "rgba(255,255,255,0.24)", line: "rgba(255,255,255,0.45)" } : dark ? { fill: "rgba(18,22,30,0.32)", line: "rgba(255,255,255,0.20)" } : { fill: "rgba(255,255,255,0.34)", line: "rgba(255,255,255,0.55)" };

/** Ink of the labels: white with a small shadow (iOS) on a dark wallpaper, dark grey on a very light one (legibility). */
export const labelInk = (dark: boolean) => (dark ? "rgba(255,255,255,0.96)" : "rgba(28,32,40,0.86)");
const font = (w: number, px: number) => `${w} ${px}px "${INTER}", -apple-system, Helvetica, Arial, sans-serif`;

/** Label under an icon or a widget, as iOS draws it. */
const label = (ctx: CanvasRenderingContext2D, text: string, cx: number, top: number, dark: boolean) => {
  ctx.save();
  ctx.font = font(500, 36);
  ctx.textAlign = "center";
  ctx.textBaseline = "top";
  if (dark) {
    ctx.shadowColor = "rgba(0,0,0,0.35)";
    ctx.shadowBlur = 6;
    ctx.shadowOffsetY = 1;
  }
  ctx.fillStyle = labelInk(dark);
  ctx.fillText(text, cx, top);
  ctx.restore();
};

const drawIcon = (ctx: CanvasRenderingContext2D, img: HTMLImageElement | undefined, x: number, y: number) => {
  if (!img) return;
  ctx.save();
  ctx.shadowColor = "rgba(0,0,0,0.18)";
  ctx.shadowBlur = 18;
  ctx.shadowOffsetY = 6;
  ctx.drawImage(img, x, y, IOS.icon, IOS.icon);
  ctx.restore();
};

/** The status bar at 9:41, network, Wi-Fi and battery FULL (Apple's marketing rule). */
export const drawStatusBar = (ctx: CanvasRenderingContext2D, ink: string) => {
  ctx.save();
  ctx.fillStyle = ink;
  ctx.font = font(600, 52);
  ctx.textAlign = "center";
  ctx.textBaseline = "middle";
  ctx.fillText("9:41", 217, 97);
  ctx.fillStyle = "#000";
  ctx.beginPath();
  ctx.roundRect(415, 43, 375, 108, 54);
  ctx.fill();
  const ox = 860;
  const oy = 70;
  ctx.fillStyle = ink;
  [12, 19, 27, 36].forEach((h, i) => {
    ctx.beginPath();
    ctx.roundRect(ox + 5 + i * 16, oy + 45 - h, 10, h, 3);
    ctx.fill();
  });
  ctx.strokeStyle = ink;
  ctx.lineWidth = 6;
  ctx.lineCap = "round";
  [24, 16, 8].forEach((r) => {
    ctx.beginPath();
    ctx.arc(ox + 110, oy + 43, r, -Math.PI * 0.75, -Math.PI * 0.25);
    ctx.stroke();
  });
  ctx.beginPath();
  ctx.arc(ox + 110, oy + 41, 4, 0, Math.PI * 2);
  ctx.fill();
  ctx.globalAlpha = 0.4;
  ctx.lineWidth = 3;
  ctx.beginPath();
  ctx.roundRect(ox + 160, oy + 10, 70, 35, 10);
  ctx.stroke();
  ctx.globalAlpha = 1;
  ctx.beginPath();
  ctx.roundRect(ox + 165, oy + 15, 60, 25, 6.5);
  ctx.fill();
  ctx.globalAlpha = 0.4;
  ctx.beginPath();
  ctx.roundRect(ox + 233, oy + 21, 4.5, 13, 2);
  ctx.fill();
  ctx.restore();
};

/**
 * Everything of a Home Screen that is not the wallpaper nor a widget, on a transparent 1206 x 2622 canvas: grid icons with their
 * names, « Ardane » under each widget (`widgetLabels`), the status bar, the Search pill, the Dock and its icons. `imgs` holds the
 * icons by their file (appleIcon(name)).
 */
export const drawIosChrome = (
  ctx: CanvasRenderingContext2D,
  imgs: Record<string, HTMLImageElement>,
  opt: { dark: boolean; glass?: boolean; icons?: IosIcon[]; dock?: string[]; widgetLabels?: Rect[]; clear?: boolean },
) => {
  if (opt.clear !== false) ctx.clearRect(0, 0, IOS.w, IOS.h);
  const ink = opt.dark ? "#FFFFFF" : "#000000";
  for (const r of opt.widgetLabels ?? []) label(ctx, "Ardane", r[0] + r[2] / 2, r[1] + r[3] + 18, opt.dark);
  for (const ic of opt.icons ?? []) {
    drawIcon(ctx, imgs[appleIcon(ic.name)], ic.x, ic.y);
    label(ctx, ic.name, ic.x + IOS.icon / 2, ic.y + IOS.icon + 10, opt.dark);
  }
  drawStatusBar(ctx, ink);
  const tint = glassTint(opt.dark, opt.glass);
  const plate = (x: number, y: number, w: number, h: number, r: number) => {
    ctx.save();
    ctx.beginPath();
    ctx.roundRect(x, y, w, h, r);
    ctx.fillStyle = tint.fill;
    ctx.fill();
    ctx.lineWidth = 2;
    ctx.strokeStyle = tint.line;
    ctx.stroke();
    ctx.restore();
  };
  // Search pill: magnifier + « Search », centred in the pill (488, 2113, 230 x 84)
  plate(488, 2113, 230, 84, 42);
  ctx.save();
  ctx.font = font(500, 36);
  const tw = ctx.measureText("Search").width;
  const x0 = 488 + (230 - (28 + 14 + tw)) / 2;
  ctx.strokeStyle = labelInk(opt.dark);
  ctx.fillStyle = labelInk(opt.dark);
  ctx.lineWidth = 3.7;
  ctx.lineCap = "round";
  ctx.beginPath();
  ctx.arc(x0 + 11.5, 2155 - 2.5, 9, 0, Math.PI * 2);
  ctx.moveTo(x0 + 18, 2155 + 4);
  ctx.lineTo(x0 + 25.5, 2155 + 11.5);
  ctx.stroke();
  ctx.textAlign = "left";
  ctx.textBaseline = "middle";
  ctx.fillText("Search", x0 + 42, 2156);
  ctx.restore();
  // Dock
  const dock = opt.dock ?? IOS_DOCK;
  plate(52, IOS.dockTop, 1100, 304, 120);
  dock.forEach((name, i) => drawIcon(ctx, imgs[appleIcon(name)], dockX(i, dock.length), IOS.dockIconTop));
};

/**
 * The Home captures of the app (`home-hero-*`, `home-crepuscule`: wallpaper + widgets + the kit's own icons) are never shown as
 * they are: they are recomposed (wallpaper + the same widgets + real icons) by the IosHomeCapture composition
 * (src/ioshome, scripts/ad2/ios_homes.sh) into public/ioshome/<lang>/<name>.png, and kit.ts serves those files under the same name.
 */
type CaptureSpec = { wall: string; dark: boolean; widgets: { file: string; size: "s" | "m" | "l"; c: 0 | 2; r: number }[] };
const hero = (u: string, wall: string, dark = true): CaptureSpec => ({
  wall,
  dark,
  widgets: [
    { file: `setup-hero-${u}-0`, size: "m", c: 0, r: 0 },
    { file: `setup-hero-${u}-1`, size: "m", c: 0, r: 2 },
    { file: `setup-hero-${u}-2`, size: "s", c: 0, r: 4 },
    { file: `setup-hero-${u}-3`, size: "s", c: 2, r: 4 },
  ],
});
export const IOS_CAPTURES: Record<string, CaptureSpec> = {
  "home-hero-aurore": hero("aurore", "wall-aurora"),
  "home-hero-light": hero("light", "wall-paper", false),
  "home-hero-espace": hero("espace", "wall-midnight"),
  "home-hero-neon": hero("neon", "wall-synthwave"),
  "home-hero-crepuscule": hero("crepuscule", "wall-sunset"),
  "home-hero-etudes": hero("etudes", "wall-paper", false),
  "home-hero-graphite": hero("graphite", "wall-graphite"),
  "home-crepuscule": {
    wall: "wall-sunset",
    dark: true,
    widgets: [
      { file: "setup-crepuscule-0", size: "s", c: 0, r: 0 },
      { file: "setup-crepuscule-1", size: "s", c: 2, r: 0 },
      { file: "setup-crepuscule-2", size: "m", c: 0, r: 2 },
      { file: "setup-crepuscule-3", size: "s", c: 0, r: 4 },
    ],
  },
};
/** kit.ts / kit26.ts serve these names from public/ioshome/<lang>/ (no film uses the other home-* captures). */
export const iosCaptureName = (name: string): string | null => (IOS_CAPTURES[name] ? name : null);
