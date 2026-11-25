import { AbsoluteFill, Easing, Img, interpolate, interpolateColors, staticFile, useCurrentFrame } from "remotion";
import { Grain } from "../components/Grain";
import { Seam } from "../components/Seam";
import { AXIS, C, clamp, ease, H, INTER, W } from "../lib/brand";
import { DOCK, kitUrl, type Rect } from "../lib/kit";
import { appleIcon, IOS, IOS_CAPTURES, IOS_DOCK, iosFill, iosRect } from "../lib/iosHome";
import { Tr } from "../lib/i18n";

/**
 * V4 step 3: the PROCESS of making a Home your own, on the app's real screens (kit, English), never cropped:
 * Store (library) → My widgets (pick one) → editor and Studio (style, colours, background) → Home Screens (compose).
 * One whole screen at a time at 640 px wide (the whole 1206 × 2622 capture), ghosts of its neighbours in depth, the
 * previous screen leaving back-left as the next arrives from the right, a Sapphire blade between two captures of
 * the same screen. Voice: « Pick the widgets that matter. Make them yours. » (≈ 0.3–4 s).
 */
/** Frames of the film. The sequence below is authored on 840 frames (ORIG) and played 1.4x faster, at a constant speed. */
export const PROCESS_FRAMES = 600;
const ORIG = 840;
const SPEED = ORIG / PROCESS_FRAMES;

const CARD_W = 640;
const CARD_H = (CARD_W * 2622) / 1206;
const CY = 1010;
const TR = 32; // frames a screen takes to give way to the next one
const BLADE = 20;
const PUSHF = 30;

type Shot = { at: number; n: string; push?: boolean };
type Scene = { start: number; label: string; shots: Shot[]; ghosts: [string | null, string | null]; compose?: boolean };
const SCENES: Scene[] = [
  {
    start: 0,
    label: "Store",
    shots: [
      { at: 0, n: "store-dark" },
      { at: 48, n: "store-at-0.72", push: true },
      { at: 88, n: "store-at-0.84", push: true },
      { at: 128, n: "store-end", push: true },
    ],
    ghosts: [null, "mywidgets"],
  },
  { start: 172, label: "My widgets", shots: [{ at: 172, n: "mywidgets" }], ghosts: ["store-end", "editor-v2"] },
  {
    start: 250,
    label: "Studio",
    shots: [
      { at: 250, n: "editor-v2" },
      { at: 312, n: "studio-content" },
      { at: 368, n: "studio-style-aurora" },
      { at: 436, n: "studio-style-neon" },
      { at: 504, n: "studio-palette-gold" },
      { at: 564, n: "studio-background" },
    ],
    ghosts: ["mywidgets", "home-crepuscule"],
  },
  { start: 612, label: "Home Screens", shots: [{ at: 612, n: "wall-sunset" }], ghosts: ["studio-background", null], compose: true },
];
const WORDS = [
  { from: 0, to: 172, text: "Pick." },
  { from: 172, to: 612, text: "Style." },
  { from: 612, to: ORIG, text: "Compose." },
];
const PREMIUM = [376, 504];
const PUSH = 340;
/**
 * Where the pieces of home-crepuscule sit. Since 2026-11-11 the capture is recomposed as a real iPhone Home (lib/iosHome.ts,
 * IOS_CAPTURES["home-crepuscule"]): the same widgets on the measured iOS grid, real Apple apps in the free cells and the Dock.
 */
const CREP = IOS_CAPTURES["home-crepuscule"];
const CREP_WIDGETS: Rect[] = CREP.widgets.map((w) => iosRect(w.size, w.c, w.r));
const CREP_FILL = iosFill(CREP_WIDGETS, CREP.widgets.map((w) => w.file));
const CREP_ICONS: { r: Rect; name: string }[] = [
  ...CREP_FILL.map((i) => ({ r: [i.x, i.y, IOS.icon, IOS.icon] as Rect, name: i.name })),
  ...DOCK.map((r, i) => ({ r, name: IOS_DOCK[i] })),
];

/**
 * Nothing is ever cut by the edge of the phone: wherever a capture holds a scroller (chips, carousels, tiles under the
 * sticky footer), a fade to the screen's own background hides the cut. Rectangles are in capture px (1206 × 2622):
 * y0–y1 is the band; l / r fade the left / right edge over that many px; t / b fade the top / bottom of the band.
 * `c0`/`c1` is a plain top → bottom background; without it the screen's left gutter (6 px) is stretched across.
 */
type Fade = { y0: number; y1: number; l?: number; r?: number; t?: number; b?: number; c0?: string; c1?: string; h?: boolean };
const CHIPS = { c0: "#DEE7F0", c1: "#E5ECF4" };
const FOOT = { y0: 2060, y1: 2300, b: 240 };
const FADES: Record<string, Fade[]> = {
  "store-dark": [
    { y0: 700, y1: 850, r: 330 },
    { y0: 1520, y1: 2340, r: 520 },
  ],
  "store-at-0.72": [
    { y0: 540, y1: 1130, r: 400 },
    { y0: 1140, y1: 2080, r: 560 },
  ],
  "store-at-0.84": [{ y0: 100, y1: 2380, r: 440 }],
  "store-end": [
    { y0: 0, y1: 650, r: 380 },
    { y0: 1220, y1: 1960, r: 200 },
  ],
  // the app truncates this title ("Next set + Consistency + Records +..."): the line is covered, the subtitle stays
  mywidgets: [{ y0: 840, y1: 1190, r: 300 }, { y0: 1384, y1: 1452, l: 1206, h: true, c0: "#E9EFF6", c1: "#EBF1F7" }],
  // chips that scroll sideways: whatever the capture cuts at its edges is covered by the row's own background (h = hard edge)
  "editor-v2": [{ y0: 940, y1: 1070, r: 330, h: true, ...CHIPS }, { y0: 1085, y1: 1215, r: 290, h: true, ...CHIPS }],
  "studio-content": [{ y0: 940, y1: 1070, r: 240, h: true, ...CHIPS }, { y0: 1085, y1: 1215, r: 290, h: true, ...CHIPS }],
  "studio-style-aurora": [{ y0: 1078, y1: 1215, l: 178, r: 181, h: true, ...CHIPS }, { y0: 1215, y1: 1360, t: 140 }, FOOT],
  "studio-style-neon": [{ y0: 1078, y1: 1215, l: 178, r: 181, h: true, ...CHIPS }, { y0: 1215, y1: 1360, t: 140 }, FOOT],
  "studio-palette-gold": [{ y0: 1078, y1: 1215, l: 198, r: 46, h: true, ...CHIPS }, { y0: 1215, y1: 1330, t: 115 }, FOOT],
  "studio-background": [{ y0: 1078, y1: 1215, l: 105, r: 105, h: true, ...CHIPS }, FOOT],
};

const blade = Easing.bezier(0.45, 0, 0.2, 1);

/** A capture, with the fades that hide whatever the phone's edge would cut. */
const Layer: React.FC<{ name: string; style?: React.CSSProperties }> = ({ name, style }) => {
  const SCL = CARD_W / 1206;
  const src = kitUrl(name);
  const fill = (f: Fade, ox: number, oy: number, w: number, h: number): React.CSSProperties =>
    f.c0 ? { position: "absolute", left: ox, top: oy, width: w, height: h, background: `linear-gradient(180deg, ${f.c0}, ${f.c1 ?? f.c0})` } : { position: "absolute", left: ox, top: oy, width: w, height: h };
  const pieces: React.ReactNode[] = [];
  (FADES[name] ?? []).forEach((f, i) => {
    const addOver = (key: string, x0: number, y0: number, w: number, h: number, mask: string) => {
      // gutter stretched: the screen's own left 6 px, widened to the whole card (or the plain colours of a row)
      pieces.push(
        <div key={key} style={{ position: "absolute", left: x0 * SCL, top: y0 * SCL, width: w * SCL, height: h * SCL, overflow: "hidden", maskImage: mask, WebkitMaskImage: mask }}>
          {f.c0 ? (
            <div style={fill(f, 0, 0, w * SCL, h * SCL)} />
          ) : (
            <div style={{ position: "absolute", left: 0, top: -y0 * SCL, width: 6 * SCL, height: CARD_H, overflow: "hidden", transformOrigin: "0 0", transform: `scaleX(${w / 6})` }}>
              <Img src={src} style={{ position: "absolute", left: 0, top: 0, width: CARD_W, height: CARD_H }} />
            </div>
          )}
        </div>,
      );
    };
    if (f.r) addOver(`r${i}`, 1206 - f.r, f.y0, f.r, f.y1 - f.y0, `linear-gradient(to right, transparent 0%, black ${f.h ? 12 : 55}%)`);
    if (f.l) addOver(`l${i}`, 0, f.y0, f.l, f.y1 - f.y0, `linear-gradient(to left, transparent 0%, black ${f.h ? 12 : 55}%)`);
    if (f.t) addOver(`t${i}`, 0, f.y0, 1206, f.t, "linear-gradient(to bottom, black 45%, transparent 100%)");
    if (f.b) addOver(`b${i}`, 0, f.y1 - f.b, 1206, f.b, "linear-gradient(to bottom, transparent 0%, black 55%)");
  });
  return (
    <div style={{ position: "absolute", inset: 0, ...style }}>
      <Img src={src} style={{ position: "absolute", inset: 0, width: CARD_W, height: CARD_H }} />
      {pieces}
    </div>
  );
};

const SceneCard: React.FC<{ scene: Scene; index: number; f: number; fadeBlade?: boolean }> = ({ scene, index, f, fadeBlade }) => {
  const nextStart = index < SCENES.length - 1 ? SCENES[index + 1].start : ORIG + 99999;
  const last = index === SCENES.length - 1;
  const lo = scene.start;
  if (f < lo - 1 || f > nextStart + TR) return null;
  const pin = interpolate(f, [lo, lo + TR + 6], [0, 1], { ...clamp, easing: ease.arrival });
  const pout = interpolate(f, [nextStart, nextStart + TR], [0, 1], { ...clamp, easing: Easing.bezier(0.5, 0, 0.75, 0.4) });
  const fadeEnd = last ? interpolate(f, [ORIG - 16, ORIG], [0, 1], clamp) : 0;
  const dir = 1 - pin; // 1 = just arrived from the right
  const x = dir * 190 - pout * 190;
  const ry = -dir * 20 + pout * 22;
  const sc = 0.88 + 0.12 * pin - pout * 0.1;
  const z = -pout * 160 + interpolate(f, [lo, nextStart], [0, 46], clamp);
  const opacity = Math.min(1, pin * 1.8) * (1 - pout) * (1 - fadeEnd);
  const blur = (1 - pin) * 14 + pout * 12;

  // which capture is current, and the blade (or the Store's scroll) over it
  const shots = scene.shots;
  const live = (i: number) => {
    const sh = shots[i];
    return i === 0 || f >= sh.at + (sh.push ? PUSHF : BLADE);
  };
  let baseIdx = 0;
  shots.forEach((_, i) => {
    if (live(i)) baseIdx = i;
  });
  const base = shots[baseIdx];
  const nxt = shots[baseIdx + 1];
  const mode = nxt?.push ? "push" : "blade";
  const wpRaw = nxt ? interpolate(f, [nxt.at, nxt.at + (nxt.push ? PUSHF : BLADE)], [0, 1], { ...clamp, easing: nxt.push ? Easing.bezier(0.5, 0, 0.2, 1) : blade }) : 0;
  const wp = wpRaw;
  const edge = mode === "push" ? Math.sin(Math.PI * wp) * 16 : 0;

  // Compose: the real pieces of one Home (wallpaper, four widgets, dock icons) settle onto the wall, then the app's own capture takes over.
  const SC = CARD_W / 1206;
  const settle = interpolate(f, [lo + 40, lo + 130], [0, 1], { ...clamp, easing: Easing.bezier(0.3, 0, 0.1, 1) });
  const home = scene.compose ? interpolate(f, [lo + 150, lo + 176], [0, 1], { ...clamp, easing: blade }) : 0;
  const pieces: { src: string; r: [number, number, number, number]; i: number; r2?: number }[] = scene.compose
    ? [
        ...CREP_WIDGETS.map((r, i) => ({ src: kitUrl(CREP.widgets[i].file), r, i, r2: 66 * 0.9579 })),
        ...CREP_ICONS.map((ic, i) => ({ src: staticFile(appleIcon(ic.name)), r: ic.r, i: i + 4, r2: 0 })),
      ]
    : [];
  const pieceLayers = pieces.map((p, n) => {
    const d = interpolate(f, [lo + 12 + n * 5, lo + 40 + n * 5], [0, 1], clamp);
    const sp = 1 - settle;
    const side = p.i % 2 ? 1 : -1;
    return (
      <Img
        key={n}
        src={p.src}
        style={{
          position: "absolute",
          left: p.r[0] * SC,
          top: p.r[1] * SC,
          width: p.r[2] * SC,
          height: p.r[3] * SC,
          opacity: Math.min(1, d * 2) * (1 - home) * opacity,
          filter: blur > 0.2 ? `blur(${blur}px)` : undefined,
          transform: `translate3d(${side * sp * 26}px, ${-sp * 40 - (1 - d) * 60}px, ${sp * (70 + (p.i % 4) * 36)}px)`,
          boxShadow: p.r2 ? `0 ${22 * sp + 4}px ${44 * sp + 10}px rgba(0,0,0,0.5)` : undefined,
          borderRadius: p.r2 ? p.r2 * SC : 0,
        }}
      />
    );
  });

  const ghost = (name: string | null, side: -1 | 1) =>
    name ? (
      <Img
        src={kitUrl(name)}
        style={{
          position: "absolute",
          left: CARD_W / 2 + side * 330 - 150,
          top: CARD_H / 2 - 325,
          width: 300,
          height: 650,
          borderRadius: 34,
          opacity: 0.3 * opacity,
          filter: `blur(${5 + blur}px) brightness(0.8)`,
          transform: `translateZ(-260px) rotateY(${-side * 24}deg)`,
        }}
      />
    ) : null;

  return (
    <div
      style={{
        position: "absolute",
        left: AXIS - CARD_W / 2,
        top: CY - CARD_H / 2,
        width: CARD_W,
        height: CARD_H,
        transformStyle: "preserve-3d",
        transform: `translate3d(${x}px, 0, ${z}px) rotateY(${ry}deg) scale(${sc})`,
      }}
    >
      {ghost(scene.ghosts[0], -1)}
      {ghost(scene.ghosts[1], 1)}
      <div
        style={{
          position: "absolute",
          inset: 0,
          borderRadius: 66,
          overflow: "hidden",
          opacity,
          filter: blur > 0.2 ? `blur(${blur}px)` : undefined,
          boxShadow: "0 50px 100px rgba(0,0,0,0.65), 0 0 0 1.5px rgba(214,233,250,0.22)",
          background: "#000",
        }}
      >
        <div
          style={{
            position: "absolute",
            inset: 0,
            maskImage: edge > 0.2 ? `linear-gradient(to bottom, transparent 0%, black ${edge}%, black ${100 - edge}%, transparent 100%)` : undefined,
            WebkitMaskImage: edge > 0.2 ? `linear-gradient(to bottom, transparent 0%, black ${edge}%, black ${100 - edge}%, transparent 100%)` : undefined,
          }}
        >
          <Layer name={base.n} style={mode === "push" && wp > 0 ? { transform: `translateY(${-wp * PUSH}px)`, opacity: 1 - wp * wp } : undefined} />
          {scene.compose && <Img src={kitUrl("home-crepuscule")} style={{ position: "absolute", inset: 0, width: CARD_W, height: CARD_H, opacity: home }} />}
          {scene.compose && home > 0 && home < 1 && <Seam x={CARD_W * home} top={0} height={CARD_H} spread={0.45} intensity={Math.sin(Math.PI * home)} />}
          {nxt && wp > 0 && mode === "blade" && (
            <>
              <Layer name={nxt.n} style={fadeBlade ? { opacity: wp } : { clipPath: `inset(0 ${(1 - wp) * 100}% 0 0)` }} />
              <Seam x={CARD_W * wp} top={0} height={CARD_H} spread={0.45} intensity={Math.sin(Math.PI * wp) * (fadeBlade ? 0.6 : 1)} />
            </>
          )}
          {nxt && wp > 0 && mode === "push" && <Layer name={nxt.n} style={{ transform: `translateY(${(1 - wp) * PUSH}px)`, opacity: Math.min(1, wp * 1.6) }} />}
        </div>
      </div>
      {pieceLayers}
    </div>
  );
};

/** `map`: frame of the film -> frame of the 840-frame authoring (a film can play a part of the process faster); `bare` hides the big word and the eyebrow. */
export const Process: React.FC<{ map?: (f: number) => number; bare?: boolean; fadeBlade?: boolean }> = ({ map, bare = false, fadeBlade = false }) => {
  const raw = useCurrentFrame();
  const f = map ? map(raw) : raw * SPEED;
  const glow = interpolateColors(
    f,
    [0, 300, 376, 436, 504, 564, 612, ORIG],
    ["#2E6BD0", "#2E6BD0", "#2FA79A", "#C23AA0", "#C9A24A", "#4E9BE0", "#2E6BD0", "#2E6BD0"],
  );
  // The Sapphire line passes at every change of screen.
  const changes = [172, 250, 612];
  const seam = changes.reduce((a, c) => Math.max(a, interpolate(f, [c, c + 12, c + TR + 10], [0, 1, 0], clamp)), 0);
  const camYaw = 2.2 * Math.sin(f / 150);
  const camTilt = 1.2 * Math.sin(f / 190 + 1);
  const premium = interpolate(f, [PREMIUM[0], PREMIUM[0] + 14, PREMIUM[1] - 10, PREMIUM[1]], [0, 1, 1, 0], clamp);
  const sceneIdx = SCENES.reduce((a, s, i) => (f >= s.start ? i : a), 0);
  const scene = SCENES[sceneIdx];
  const eyebrowO = interpolate(f, [scene.start, scene.start + 14, scene.start + 90, scene.start + 104], [0, 1, 1, 0.55], clamp);
  return (
    <AbsoluteFill style={{ backgroundColor: C.void }}>
      <AbsoluteFill style={{ background: `radial-gradient(circle 1000px at ${AXIS}px ${CY}px, ${C.lifted}, ${C.void} 72%)` }} />
      <AbsoluteFill style={{ background: `radial-gradient(ellipse 620px 900px at ${AXIS}px ${CY}px, ${glow}40, transparent 72%)` }} />
      <Seam x={AXIS} top={140} height={H - 280} intensity={0.2 + seam * 0.7} />
      <div style={{ position: "absolute", inset: 0, perspective: 1900, perspectiveOrigin: `${AXIS}px ${CY}px` }}>
        <div style={{ position: "absolute", inset: 0, transformStyle: "preserve-3d", transform: `rotateY(${camYaw}deg) rotateX(${camTilt}deg)`, transformOrigin: `${AXIS}px ${CY}px` }}>
          {SCENES.map((s, i) => (
            <SceneCard key={i} scene={s} index={i} f={f} fadeBlade={fadeBlade} />
          ))}
        </div>
      </div>
      <div style={{ display: bare ? "none" : undefined, position: "absolute", left: 0, top: 80, width: W, textAlign: "center", fontFamily: INTER, fontWeight: 600, fontSize: 26, letterSpacing: "0.14em", textTransform: "uppercase", color: C.type2, fontVariationSettings: "'opsz' 14", opacity: eyebrowO }}>
        {scene.label}
      </div>
      {(bare ? [] : WORDS).map((w, i) => {
        const inP = interpolate(f, [w.from + 4, w.from + 26], [0, 1], { ...clamp, easing: ease.split });
        const outP = i === WORDS.length - 1 ? interpolate(f, [ORIG - 30, ORIG - 12], [0, 1], clamp) : interpolate(f, [w.to - 4, w.to + 14], [0, 1], clamp);
        if (f < w.from || outP >= 1) return null;
        return (
          <div
            key={i}
            style={{
              position: "absolute",
              left: 0,
              top: 130,
              width: W,
              textAlign: "center",
              fontFamily: INTER,
              fontWeight: 700,
              fontSize: 118,
              lineHeight: 1,
              letterSpacing: "-0.03em",
              fontVariationSettings: "'opsz' 32",
              opacity: Math.min(1, inP * 2) * (1 - outP),
              transform: `translateY(${(1 - inP) * 50 - outP * 30}px)`,
              filter: `blur(${(1 - inP) * 10 + outP * 8}px)`,
              background: `linear-gradient(180deg, ${C.paleWarm}, ${C.type1} 55%, ${C.pale})`,
              WebkitBackgroundClip: "text",
              color: "transparent",
            }}
          >
            {w.text}
          </div>
        );
      })}
      {premium > 0 && (
        <div style={{ position: "absolute", left: 0, top: 1770, width: W, display: "flex", justifyContent: "center", opacity: premium, transform: `translateY(${(1 - premium) * 16}px)` }}>
          <div style={{ fontFamily: INTER, fontWeight: 600, fontSize: 32, letterSpacing: "0.02em", fontVariationSettings: "'opsz' 20", color: C.pale, padding: "14px 36px", borderRadius: 999, border: "1.5px solid rgba(214,233,250,0.4)", background: "rgba(27,74,122,0.3)" }}>
            <Tr>common.withPremium</Tr>
          </div>
        </div>
      )}
      <Grain />
    </AbsoluteFill>
  );
};
