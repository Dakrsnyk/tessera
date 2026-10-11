import { AbsoluteFill, Easing, Img, interpolate, staticFile } from "remotion";
import { FilmAudio } from "../components/FilmAudio";
import { Grain } from "../components/Grain";
import { SplitText } from "../components/SplitText";
import { AXIS, C, clamp, ease, H, type, W } from "../lib/brand";
import { heroWidget, k } from "../lib/kit";
import { useFilmFrame } from "../lib/time";

/** Local frame 0 = f2520 of the main film (42.0 s). Money · Week · Habits, one bar each (§5.2 shots 19–21). */
const BUDGET = heroWidget("crepuscule", 2);
const SPENDING = k("spendingByCategory-m-crepuscule.png");
const WEEK = k("plan-0-dark.png");
const NEXT_WEEK = k("plan-1-dark.png");
const HAB_BEFORE = k("hab-0-dark.png");
const HAB_AFTER = k("hab-1-dark.png");
const STREAK = k("habitStreak-s-aurora.png");
/** The week table on the Planning capture (px), and the habit's check circle. */
const TABLE = { x: 30, y: 560, w: 1146, h: 1680 };
const CHECK = { x: 140, y: 970 };

const Hero: React.FC<{ word: string; from: number; to: number; top?: number }> = ({ word, from, to, top = 250 }) => (
  <SplitText from={from} exitAt={to} top={top} height={160}>
    <span style={type.hero}>{word}</span>
  </SplitText>
);

const Money: React.FC<{ f: number }> = ({ f }) => {
  // The seam laid flat: Money's own staging. The budget rises out of it; spending is revealed along it.
  const line = interpolate(f, [0, 10], [0, 1], { ...clamp, easing: ease.split });
  const rise = interpolate(f, [4, 44], [0, 1], { ...clamp, easing: ease.lift });
  const reveal = interpolate(f, [14, 62], [0, 1], { ...clamp, easing: Easing.bezier(0.45, 0, 0.2, 1) });
  const out = interpolate(f, [108, 120], [1, 0], clamp);
  const LINE_Y = 1080;
  const size = 560;
  const spendW = 940;
  const spendH = (940 * 510) / 1092;
  return (
    <AbsoluteFill style={{ opacity: out }}>
      <div
        style={{
          position: "absolute",
          left: 0,
          top: LINE_Y - 1,
          width: W,
          height: 2,
          background: "linear-gradient(to right, transparent, #FFF4EC 15%, #FFFFFF 50%, #FFF4EC 85%, transparent)",
          boxShadow: "0 0 18px 3px rgba(255,224,204,0.55), 0 0 90px 18px rgba(255,122,89,0.18)",
          opacity: line,
          scale: `${line} 1`,
        }}
      />
      {/* Rises from behind the line (masked under it). */}
      <div style={{ position: "absolute", left: 0, top: 0, width: W, height: LINE_Y, overflow: "hidden" }}>
        <Img
          src={staticFile(BUDGET)}
          style={{
            position: "absolute",
            left: AXIS - size / 2,
            top: LINE_Y - 30 - (size + 30) * rise,
            width: size,
            height: size,
            filter: "drop-shadow(0 30px 50px rgba(0,0,0,0.55))",
          }}
        />
      </div>
      <Img
        src={staticFile(SPENDING)}
        style={{
          position: "absolute",
          left: AXIS - spendW / 2,
          top: LINE_Y + 40,
          width: spendW,
          height: spendH,
          clipPath: `inset(0 ${(1 - reveal) * 100}% 0 0)`,
        }}
      />
      {reveal > 0 && reveal < 1 && (
        <div
          style={{
            position: "absolute",
            left: AXIS - spendW / 2 + spendW * reveal - 1,
            top: LINE_Y + 40,
            width: 2,
            height: spendH,
            background: "#FFFFFF",
            boxShadow: "0 0 14px 3px rgba(255,224,204,0.8), 0 0 60px 10px rgba(255,122,89,0.2)",
          }}
        />
      )}
    </AbsoluteFill>
  );
};

const Week: React.FC<{ f: number }> = ({ f }) => {
  // Lying flat under a raking light, tilting to a top-down plan (36 frames), then the page swipe at 45.0 s.
  const tilt = interpolate(f, [0, 36], [62, 0], { ...clamp, easing: ease.arrival });
  const swipe = interpolate(f, [60, 81], [0, 1], { ...clamp, easing: Easing.bezier(0.25, 0.9, 0.3, 1) });
  const inOut = interpolate(f, [0, 10, 108, 120], [0, 1, 1, 0], clamp);
  const s = 900 / TABLE.w;
  const w = 900;
  const h = TABLE.h * s;
  const page = (src: string, dx: number) => (
    <div style={{ position: "absolute", left: dx, top: 0, width: w, height: h, overflow: "hidden", borderRadius: 36 }}>
      <Img src={staticFile(src)} style={{ position: "absolute", left: -TABLE.x * s, top: -TABLE.y * s, width: 1206 * s }} />
    </div>
  );
  return (
    <AbsoluteFill style={{ perspective: 1800, opacity: inOut }}>
      <div
        style={{
          position: "absolute",
          left: AXIS - w / 2,
          top: 470,
          width: w,
          height: h,
          transform: `rotateX(${tilt}deg)`,
          transformOrigin: "50% 60%",
          overflow: "hidden",
          borderRadius: 36,
          boxShadow: "0 40px 90px rgba(0,0,0,0.6)",
        }}
      >
        <div style={{ position: "absolute", inset: 0, translate: `${-w * swipe}px 0px` }}>
          {page(WEEK, 0)}
          {page(NEXT_WEEK, w)}
        </div>
        {/* The page edge, marked by a blade while it crosses. */}
        {swipe > 0 && swipe < 1 && (
          <div
            style={{
              position: "absolute",
              left: w * (1 - swipe) - 1,
              top: 0,
              width: 2,
              height: h,
              background: "#FFF",
              boxShadow: "0 0 14px 3px rgba(255,224,204,0.8)",
            }}
          />
        )}
        {/* Raking light from the upper left. */}
        <div
          style={{
            position: "absolute",
            inset: 0,
            background: "linear-gradient(120deg, rgba(255,244,236,0.10), transparent 45%, rgba(0,0,0,0.25))",
          }}
        />
      </div>
    </AbsoluteFill>
  );
};

const Habits: React.FC<{ f: number }> = ({ f }) => {
  // 135 mm macro on the check circle, pulling back to 85 mm; the check at 46.5 s (f30 here), a radial blade.
  const pull = interpolate(f, [0, 90], [0, 1], { ...clamp, easing: Easing.bezier(0.35, 0, 0.2, 1) });
  const scale = interpolate(pull, [0, 1], [2.6, 0.62]);
  const reveal = interpolate(f, [30, 48], [0, 1], { ...clamp, easing: ease.split });
  const streak = interpolate(f, [56, 92], [0, 1], { ...clamp, easing: ease.arrival });
  const inOut = interpolate(f, [0, 8], [0, 1], clamp);
  // The circle stays put on screen while the capture scales around it, then drifts to its place in the pane.
  const cx = interpolate(pull, [0, 1], [AXIS, AXIS - 603 * 0.62 + CHECK.x * 0.62]);
  const cy = interpolate(pull, [0, 1], [1040, 470 + CHECK.y * 0.62]);
  const left = cx - CHECK.x * scale;
  const top = cy - CHECK.y * scale;
  const img = (src: string, extra?: React.CSSProperties) => (
    <Img src={staticFile(src)} style={{ position: "absolute", left, top, width: 1206 * scale, ...extra }} />
  );
  const radius = reveal * 1400 * scale;
  return (
    <AbsoluteFill style={{ opacity: inOut }}>
      <div
        style={{
          position: "absolute",
          inset: 0,
          maskImage: "radial-gradient(ellipse 900px 1100px at 50% 50%, black 60%, transparent 100%)",
        }}
      >
        {img(HAB_BEFORE)}
        {img(HAB_AFTER, { clipPath: `circle(${radius}px at ${CHECK.x * scale}px ${CHECK.y * scale}px)` })}
      </div>
      {/* The hero word sits on a veil: the UI under it falls back (type never over UI data). */}
      <div
        style={{
          position: "absolute",
          left: 0,
          top: 0,
          width: W,
          height: 620,
          background: "linear-gradient(to bottom, #000 0%, #000 55%, transparent 100%)",
        }}
      />
      {reveal > 0 && reveal < 1 && (
        <div
          style={{
            position: "absolute",
            left: cx - radius,
            top: cy - radius,
            width: radius * 2,
            height: radius * 2,
            borderRadius: "50%",
            border: "2px solid rgba(255,255,255,0.9)",
            boxShadow: "0 0 18px 4px rgba(255,224,204,0.6)",
            opacity: 1 - reveal,
          }}
        />
      )}
      <Img
        src={staticFile(STREAK)}
        style={{
          position: "absolute",
          left: 470 + 700 * (1 - streak),
          top: 1352,
          width: 560,
          height: 560,
          opacity: streak,
          filter: "drop-shadow(0 30px 50px rgba(0,0,0,0.6))",
        }}
      />
    </AbsoluteFill>
  );
};

export const Essentials: React.FC<{ audio?: boolean }> = ({ audio = true }) => {
  const frame = useFilmFrame();
  return (
    <AbsoluteFill style={{ backgroundColor: C.void }}>
      <AbsoluteFill style={{ background: `radial-gradient(circle 900px at ${AXIS}px ${H / 2}px, ${C.lifted}, ${C.void} 70%)` }} />
      {frame < 120 && <Money f={frame} />}
      {frame >= 120 && frame < 240 && <Week f={frame - 120} />}
      {frame >= 240 && <Habits f={frame - 240} />}
      <Hero word="Money." from={0} to={102} />
      <Hero word="Week." from={120} to={222} top={230} />
      <Hero word="Habits." from={240} to={348} top={200} />
      <Grain />
      {audio && <FilmAudio from={2520} />}
    </AbsoluteFill>
  );
};
