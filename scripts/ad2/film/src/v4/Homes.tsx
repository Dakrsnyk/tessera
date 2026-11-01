import { ThreeCanvas } from "@remotion/three";
import * as React from "react";
import { AbsoluteFill, Easing, Img, interpolate, interpolateColors, useCurrentFrame } from "remotion";
import * as THREE from "three";
import { Grain } from "../components/Grain";
import { CameraLook, lensFov, PHONE, Phone3D, StudioEnvironment } from "../components/Phone3D";
import { Seam } from "../components/Seam";
import { AXIS, C, clamp, ease, H, INTER, useFontsReady, W } from "../lib/brand";
import { asset } from "../lib/kit";
import { Tr } from "../lib/i18n";
import { drawBlade, useCanvasTexture } from "../lib/useCanvas";
import { useImages } from "../lib/useImages";
import { back } from "../v3/fx";

/**
 * V4 step 4: four real Home Screens drawn by the app itself (kit `home-*`: wallpaper, widgets, native-app icons and
 * dock are ONE capture, so widget colour and wallpaper always match). 165 frames each, one phone that turns through
 * each change (a blade of light between two captures), a blurred copy of the wallpaper as backdrop.
 */
export const HOMES_FRAMES = 660;
const EACH = 165;

type Rect = [number, number, number, number];
type Piece = { file: string; rect: Rect; label?: string };
type Spec = {
  /** The real wallpaper (kit) the pieces sit on; the whole screen when `capture` is set. */
  wall: string;
  /** A complete Home Screen the app drew itself (nothing to compose). */
  capture?: boolean;
  dark: boolean;
  glow: string;
  widgets: Piece[];
  icons: Piece[];
  dock: string[];
};

const M = (file: string, y: number): Piece => ({ file, rect: [57, y, 1092, 510] });
const S = (file: string, x: number, y: number): Piece => ({ file, rect: [x, y, 510, 510] });
const GRID: Rect[] = [
  [628, 1403, 222, 222],
  [901, 1404, 222, 222],
  [629, 1694, 222, 222],
  [902, 1695, 222, 222],
];
const grid = (set: string, items: [number, string][]): Piece[] => items.map(([n, label], i) => ({ file: `kit/icons-${set}-${n}`, rect: GRID[i], label }));
const dockOf = (set: string) => [4, 5, 6, 7].map((n) => `kit/icons-${set}-${n}`);

/**
 * The four identities, in the film's order: blue + dark, red + dark, pink + violet, white + silver. Each Home is built from
 * the app's real pieces on the grid of its own Home Screens (HERO_WIDGETS / DOCK rectangles): wallpaper, widgets exported
 * by the app with the real palette (id-*), native-app icons, dock. Pink + violet is a Home the app drew entirely.
 */
const HOMES: Spec[] = [
  {
    wall: "kit/wall-midnight",
    dark: true,
    glow: "#2E6BD0",
    widgets: [M("kit/id-blue-macros-m", 204), M("kit/id-blue-habits-m", 813), S("kit/id-blue-budgetLeft-s", 57, 1422)],
    icons: grid("minuit", [[0, "Notes"], [1, "Books"], [2, "Podcasts"], [3, "Settings"]]),
    dock: dockOf("minuit"),
  },
  {
    wall: "kit/wall-wine",
    dark: true,
    glow: "#C23A52",
    widgets: [S("kit/id-red-calories-s", 57, 204), S("kit/id-red-budgetLeft-s", 639, 204), M("kit/id-red-weekView-m", 813), S("kit/id-red-priorities-s", 57, 1422)],
    icons: grid("graphite", [[0, "Phone"], [1, "Clock"], [2, "Notes"], [3, "Settings"]]),
    dock: dockOf("graphite"),
  },
  { wall: "kit/home-crepuscule", capture: true, dark: true, glow: "#B070D0", widgets: [], icons: [], dock: [] },
  {
    wall: "kit/wall-silver",
    dark: false,
    glow: "#C9D3E6",
    widgets: [M("kit/id-silver-weekView-m", 204), M("kit/id-silver-macros-m", 813), S("kit/id-silver-calories-s", 57, 1422)],
    icons: grid("etudes", [[0, "Books"], [1, "Notes"], [2, "Calendar"], [3, "Reminders"]]),
    dock: dockOf("etudes"),
  },
];
const FILES = [...new Set(HOMES.flatMap((h) => [h.wall, ...h.widgets.map((w) => w.file), ...h.icons.map((w) => w.file), ...h.dock]))];
const WIPE = 28;

const INK_DARK = "rgba(255,255,255,0.92)";
const INK_LIGHT = "rgba(22,26,36,0.78)";

/** Draws one Home (1206 × 2622) the way iOS lays it out: status bar, widgets with their caption, icons with their name, search, dock. */
const drawHome = (ctx: CanvasRenderingContext2D, spec: Spec, imgs: Record<string, HTMLImageElement>) => {
  ctx.clearRect(0, 0, 1206, 2622);
  ctx.drawImage(imgs[spec.wall], 0, 0, 1206, 2622);
  if (spec.capture) return;
  const ink = spec.dark ? INK_DARK : INK_LIGHT;
  const font = (w: number, px: number) => `${w} ${px}px "Inter Ardane", -apple-system, Helvetica, Arial, sans-serif`;
  // status bar
  ctx.fillStyle = ink;
  ctx.font = font(600, 58);
  ctx.textAlign = "left";
  ctx.textBaseline = "middle";
  ctx.fillText("9:41", 126, 92);
  ctx.fillStyle = "#000";
  ctx.beginPath();
  ctx.roundRect(420, 40, 364, 96, 48);
  ctx.fill();
  ctx.fillStyle = ink;
  [14, 22, 30, 38].forEach((h, i) => {
    ctx.beginPath();
    ctx.roundRect(884 + i * 21, 106 - h, 12, h, 4);
    ctx.fill();
  });
  ctx.strokeStyle = ink;
  ctx.lineCap = "round";
  ctx.lineWidth = 7;
  [34, 23, 12].forEach((r) => {
    ctx.beginPath();
    ctx.arc(1004, 106, r, -Math.PI * 0.78, -Math.PI * 0.22);
    ctx.stroke();
  });
  ctx.beginPath();
  ctx.arc(1004, 104, 4, 0, Math.PI * 2);
  ctx.fill();
  ctx.globalAlpha = 0.5;
  ctx.lineWidth = 3.5;
  ctx.beginPath();
  ctx.roundRect(1049, 72, 76, 36, 11);
  ctx.stroke();
  ctx.globalAlpha = 1;
  ctx.beginPath();
  ctx.roundRect(1054, 77, 66, 26, 7);
  ctx.fill();
  ctx.globalAlpha = 0.5;
  ctx.fillRect(1129, 83, 6, 14);
  ctx.globalAlpha = 1;
  // widgets + captions
  ctx.textAlign = "center";
  ctx.font = font(500, 34);
  for (const w of spec.widgets) {
    ctx.drawImage(imgs[w.file], ...w.rect);
    ctx.fillStyle = ink;
    ctx.fillText("Ardane", w.rect[0] + w.rect[2] / 2, w.rect[1] + w.rect[3] + 38);
  }
  // icons + names
  for (const ic of spec.icons) {
    ctx.drawImage(imgs[ic.file], ...ic.rect);
    ctx.fillStyle = ink;
    ctx.font = font(500, 34);
    ctx.fillText(ic.label ?? "", ic.rect[0] + ic.rect[2] / 2, ic.rect[1] + ic.rect[3] + 36);
  }
  // search pill and dock plate
  const glass = (x: number, y: number, w: number, h: number, r: number) => {
    ctx.beginPath();
    ctx.roundRect(x, y, w, h, r);
    ctx.fillStyle = spec.dark ? "rgba(255,255,255,0.16)" : "rgba(255,255,255,0.55)";
    ctx.fill();
    ctx.lineWidth = 2;
    ctx.strokeStyle = spec.dark ? "rgba(255,255,255,0.18)" : "rgba(255,255,255,0.8)";
    ctx.stroke();
  };
  glass(464, 2172, 278, 92, 46);
  ctx.fillStyle = ink;
  ctx.textAlign = "left";
  ctx.font = font(500, 38);
  ctx.fillText("Search", 560, 2220);
  ctx.strokeStyle = ink;
  ctx.lineWidth = 5;
  ctx.beginPath();
  ctx.arc(527, 2216, 13, 0, Math.PI * 2);
  ctx.moveTo(537, 2226);
  ctx.lineTo(547, 2236);
  ctx.stroke();
  glass(30, 2312, 1146, 282, 90);
  spec.dock.forEach((f, i) => ctx.drawImage(imgs[f], DOCK_X[i], 2340, 222, 222));
};
const DOCK_X = [64, 349, 635, 920];

/** Which Home the last film frame shows: a Home that Close can continue from (see `HomeFlat`). */
export const HOME_LAST = HOMES.length - 1;

/** One Home as a flat 1206 × 2622 picture (for the end card, or anything that needs the screen without the phone). */
export const HomeFlat: React.FC<{ index?: number; style?: React.CSSProperties }> = ({ index = HOME_LAST, style }) => {
  const imgs = useImages(FILES);
  const ready = useFontsReady();
  const ref = React.useRef<HTMLCanvasElement>(null);
  React.useLayoutEffect(() => {
    if (imgs && ready && ref.current) drawHome(ref.current.getContext("2d")!, HOMES[index], imgs);
  }, [imgs, ready, index]);
  return <canvas ref={ref} width={1206} height={2622} style={{ width: "100%", height: "100%", ...style }} />;
};

export const Homes: React.FC = () => {
  const f = useCurrentFrame();
  const images = useImages(FILES);
  const fonts = useFontsReady();
  const screen = useCanvasTexture();
  // each Home drawn once into its own 1206 × 2622 canvas
  const built = React.useMemo(
    () =>
      images && fonts
        ? HOMES.map((spec) => {
            const c = document.createElement("canvas");
            c.width = 1206;
            c.height = 2622;
            drawHome(c.getContext("2d")!, spec, images);
            return c;
          })
        : null,
    [images, fonts],
  );

  // Which capture, and how far the blade towards the next has gone (centred on each cut).
  let cur = Math.min(3, Math.floor((f + WIPE / 2) / EACH));
  // cut k happens at k*EACH: from k*EACH - WIPE/2 to k*EACH + WIPE/2
  let wipe = 0;
  for (let k = 1; k < 4; k++) {
    const t0 = k * EACH - WIPE / 2;
    if (f >= t0 && f < t0 + WIPE) {
      cur = k - 1;
      wipe = interpolate(f, [t0, t0 + WIPE], [0, 1], { easing: Easing.bezier(0.45, 0, 0.2, 1) });
    }
  }
  const next = Math.min(3, cur + 1);
  if (built) {
    const ctx = screen.ctx;
    ctx.drawImage(built[cur], 0, 0, 1206, 2622);
    if (wipe > 0) {
      ctx.save();
      ctx.beginPath();
      ctx.rect(0, 0, 1206 * wipe, 2622);
      ctx.clip();
      ctx.drawImage(built[next], 0, 0, 1206, 2622);
      ctx.restore();
      drawBlade(ctx, 1206 * wipe, 0, 2622, Math.sin(Math.PI * wipe));
    }
    screen.texture.needsUpdate = true;
  }

  // Backdrop glow: its colour follows the identity on screen.
  const glow = interpolateColors(
    f,
    [0, EACH - WIPE / 2, EACH + WIPE / 2, 2 * EACH - WIPE / 2, 2 * EACH + WIPE / 2, 3 * EACH - WIPE / 2, 3 * EACH + WIPE / 2, HOMES_FRAMES],
    [HOMES[0].glow, HOMES[0].glow, HOMES[1].glow, HOMES[1].glow, HOMES[2].glow, HOMES[2].glow, HOMES[3].glow, HOMES[3].glow],
  );
  const seamFlash = HOMES.reduce((a, _, k) => (k === 0 ? a : Math.max(a, interpolate(f, [k * EACH - WIPE / 2, k * EACH, k * EACH + WIPE], [0, 1, 0], clamp))), 0);

  // The phone: a slow turn (±9°) that passes through frontal exactly on every cut, a slow push-in, a light pitch.
  const yaw = 9 * Math.sin((2 * Math.PI * f) / (2 * EACH));
  const pitch = 2.5 * Math.sin((2 * Math.PI * f) / 400 + 1);
  const fraction = interpolate(f, [0, HOMES_FRAMES], [0.6, 0.665], clamp);
  const enter = interpolate(f, [0, 36], [0, 1], { ...clamp, easing: ease.arrival });
  const exit = interpolate(f, [HOMES_FRAMES - 16, HOMES_FRAMES], [0, 1], clamp);
  const sweep = interpolate(f, [0, 70], [0, 1], clamp) < 1 ? interpolate(f, [8, 70], [0, 1], clamp) : -1;

  const distance = PHONE.h / (2 * Math.tan(THREE.MathUtils.degToRad(lensFov(85)) / 2) * fraction);
  const dots = HOMES.map((h, k) => {
    const on = interpolate(f, [k * EACH - WIPE / 2, k * EACH + WIPE / 2], [0, 1], clamp) - (k < 3 ? interpolate(f, [(k + 1) * EACH - WIPE / 2, (k + 1) * EACH + WIPE / 2], [0, 1], clamp) : 0);
    return k === 0 ? 1 - interpolate(f, [EACH - WIPE / 2, EACH + WIPE / 2], [0, 1], clamp) : on;
  });

  const w1 = interpolate(f, [14, 34], [0, 1], { ...clamp, easing: back });
  const w2 = interpolate(f, [58, 78], [0, 1], { ...clamp, easing: back });
  const titleOut = interpolate(f, [HOMES_FRAMES - 40, HOMES_FRAMES - 16], [0, 1], clamp);
  const word = (p: number, hi: boolean, text: string) => (
    <span
      style={{
        display: "inline-block",
        opacity: Math.min(1, p * 3) * (1 - titleOut),
        transform: `translateY(${(1 - p) * 40}px)`,
        filter: `blur(${(1 - Math.min(1, p)) * 10}px)`,
        ...(hi ? { background: `linear-gradient(180deg, ${C.paleWarm}, ${C.sapphireBright} 75%, ${C.sapphire})`, WebkitBackgroundClip: "text", color: "transparent" } : { textShadow: "0 6px 40px rgba(0,0,0,0.6)" }),
      }}
    >
      {text}
    </span>
  );
  const pillIn = interpolate(f, [30, 54], [0, 1], { ...clamp, easing: ease.arrival }) * (1 - titleOut);

  return (
    <AbsoluteFill style={{ backgroundColor: C.void }}>
      {/* The wallpaper itself, blurred and drifting: the backdrop is always the identity on screen. */}
      {HOMES.map((h, k) => {
        const o = k === cur ? 1 - (k === cur && wipe > 0 ? wipe : 0) : k === next && wipe > 0 ? wipe : 0;
        return o > 0 ? (
          <Img
            key={h.wall}
            src={asset(h.wall)}
            style={{ position: "absolute", left: -260 + Math.sin(f / 140 + k) * 40, top: -200, width: 1600, opacity: 0.4 * o * enter, filter: "blur(70px) saturate(1.1) brightness(0.8)" }}
          />
        ) : null;
      })}
      <AbsoluteFill style={{ background: `radial-gradient(ellipse 760px 1000px at ${AXIS}px ${H / 2}px, ${glow}55, transparent 72%)` }} />
      <AbsoluteFill style={{ background: `radial-gradient(circle 1300px at ${AXIS}px ${H / 2}px, transparent 30%, ${C.void}cc 100%)` }} />
      <Seam x={AXIS} top={150} height={H - 300} intensity={0.22 + seamFlash * 0.6} />
      {built && (
        <AbsoluteFill style={{ opacity: enter * (1 - exit), transform: `scale(${0.94 + 0.06 * enter})`, filter: `blur(${(1 - enter) * 12}px)` }}>
          <ThreeCanvas width={W} height={H}>
            <StudioEnvironment />
            <CameraLook lens={85} position={new THREE.Vector3(0, 0, distance)} target={new THREE.Vector3(0, 0, 0)} />
            <Phone3D yaw={yaw} pitch={pitch} screen={screen.texture} screenOn={1} sweep={sweep} />
          </ThreeCanvas>
        </AbsoluteFill>
      )}
      {/* « Your iPhone. Your way. » */}
      <div style={{ position: "absolute", left: 0, top: 96, width: W, textAlign: "center", fontFamily: INTER, fontWeight: 700, fontSize: 88, letterSpacing: "-0.03em", fontVariationSettings: "'opsz' 32", color: C.type1, lineHeight: 1.05, whiteSpace: "nowrap" }}>
        {word(w1, false, "Your iPhone.")} {word(w2, true, "Your way.")}
      </div>
      {/* One dot per identity. */}
      <div style={{ position: "absolute", left: 0, top: 1690, width: W, display: "flex", justifyContent: "center", gap: 16, opacity: pillIn }}>
        {dots.map((d, k) => (
          <div key={k} style={{ width: 14 + 34 * d, height: 14, borderRadius: 7, background: d > 0.5 ? HOMES[k].glow : "rgba(245,245,247,0.28)", opacity: 0.55 + 0.45 * d, boxShadow: d > 0.5 ? `0 0 18px ${HOMES[k].glow}99` : undefined }} />
        ))}
      </div>
      <div style={{ position: "absolute", left: 0, top: 1752, width: W, display: "flex", justifyContent: "center", opacity: pillIn, transform: `translateY(${(1 - pillIn) * 16}px)` }}>
        <div style={{ fontFamily: INTER, fontWeight: 600, fontSize: 30, letterSpacing: "0.02em", fontVariationSettings: "'opsz' 20", color: C.pale, padding: "14px 34px", borderRadius: 999, border: "1.5px solid rgba(214,233,250,0.4)", background: "rgba(27,74,122,0.28)" }}>
          <Tr>common.withPremium</Tr>
        </div>
      </div>
      <Grain />
    </AbsoluteFill>
  );
};
