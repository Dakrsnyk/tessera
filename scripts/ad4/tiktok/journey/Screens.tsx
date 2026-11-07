// The app screens of the « journey » ad (open Ardane → Nutrition → scan a dish → customize the widget → place it on the
// Home Screen), drawn on the 1206 x 2622 grid of the app's captures. Every screen is a real capture of the English kit;
// the photo scan and its summary are rebuilt on the app's real chrome with the app's real texts (adapted from the campaign's
// scripts/ad2/film/src/v5/short/PhotoScreens.tsx, same figures, from Shared/Domains/FoodDatabase.swift).
import React from "react";
import { Easing, Img, interpolate, spring, staticFile } from "remotion";
import { cap, clamp, FONT } from "../lib";

export const CW = 1206;
export const CH = 2622;

/** THE PHOTO: Tests/Fixtures/FoodPhotos/31-poulet-legumes.jpg (CC0, Daderot, Wikimedia Commons), copied to public/food/. */
export const PHOTO = "food/31-poulet-legumes.jpg";
const FOODS = [
  { name: "Cooked chicken breast", grams: 120, kcal: 198 },
  { name: "Broccoli", grams: 90, kcal: 31 },
  { name: "Bell pepper", grams: 60, kcal: 19 },
];
const TOTAL = { kcal: 247, protein: 40, carbs: 10, fat: 5, left: 1305 };
const GREY = "#7C838E";
const INK = "#10151C";
const BLUE = "#1F5E9E";
const ORANGE = "#F28C28";
const split = Easing.bezier(0.16, 1, 0.3, 1);

// ------------------------------------------------------------------------------------------------ Home Screen
/** The real Home Screen « Jade » (apps, Fitness « Today's workout » M, Consistency S); its top row (Calories S + Macros S)
 * is replaced by the bare wallpaper (wall-jade, same framing: checked pixel by pixel), so the customized widget can land there.
 * The old red Ardane icon of the capture is covered by the current turquoise one. */
export const HOME = "home-jade";
const WALL = "kit/wall-jade.png";
export const SLOT: [number, number, number, number] = [57, 204, 1092, 510];
/** The Fitness « Today's workout » M row of the same Home Screen (freed for the workout ad). */
export const SLOT_MIDDLE: [number, number, number, number] = [57, 813, 1092, 510];
const FREED = { top: { y: 192, h: 606 }, middle: { y: 800, h: 598 } };
export const ICON = { x: 374, y: 1713, s: 186 };

/** A real Home Screen in the colours of a mini-app (rule of 2026-11-06), its top row freed with its own wallpaper (pairs
 * checked pixel by pixel). `icon`: where the Ardane icon is drawn (over an app of the capture, whose label becomes « Ardane »). */
export type HomeTheme = { src: string; wall: string; icon?: { x: number; y: number; s: number }; relabel?: string; label: string };
export const JADE: HomeTheme = { src: HOME, wall: WALL, icon: ICON, label: "#fff" };
/** Nutrition: cream (the Weather app of the capture becomes Ardane). */
export const CREME: HomeTheme = { src: "home-creme", wall: "kit/wall-cream.png", icon: { x: 920, y: 1713, s: 186 }, relabel: "#54402B", label: "#54402B" };
/** Fitness: black and grey. */
export const GRAPHITE: HomeTheme = { src: "home-graphite", wall: "kit/wall-graphite.png", label: "#fff" };
/** Planning: ocean blue / cyan. */
export const OCEAN: HomeTheme = { src: "home-ocean", wall: "kit/wall-ocean.png", label: "#fff" };

export const HomeBase: React.FC<{ filled?: React.ReactNode; free?: "top" | "middle"; theme?: HomeTheme }> = ({ filled, free = "top", theme = JADE }) => {
  const ic = theme.icon;
  return (
    <div style={{ position: "absolute", left: 0, top: 0, width: CW, height: CH, overflow: "hidden" }}>
      <Img src={cap(theme.src)} style={{ position: "absolute", left: 0, top: 0, width: CW, height: CH }} />
      <div style={{ position: "absolute", left: 0, top: FREED[free].y, width: CW, height: FREED[free].h, overflow: "hidden" }}>
        <Img src={staticFile(theme.wall)} style={{ position: "absolute", left: 0, top: -FREED[free].y, width: CW, height: CH }} />
      </div>
      {ic && theme.relabel && (
        // the label of the covered app, replaced by « Ardane » on its own wallpaper
        <div style={{ position: "absolute", left: ic.x - 70, top: ic.y + ic.s + 2, width: ic.s + 140, height: 58, overflow: "hidden" }}>
          <Img src={staticFile(theme.wall)} style={{ position: "absolute", left: -(ic.x - 70), top: -(ic.y + ic.s + 2), width: CW, height: CH }} />
          <div style={{ position: "absolute", left: 0, top: 8, width: ic.s + 140, textAlign: "center", fontFamily: FONT, fontWeight: 500, fontSize: 36, color: theme.relabel }}>Ardane</div>
        </div>
      )}
      {ic && <Img src={staticFile("store/ardane-icon.png")} style={{ position: "absolute", left: ic.x, top: ic.y, width: ic.s, height: ic.s, borderRadius: 44 }} />}
      {filled}
    </div>
  );
};

/** The customized widget flying in and landing on the free row, then its « Ardane » label. */
export const Landing: React.FC<{ f: number; fps: number; widget: string; slot?: [number, number, number, number]; glow?: string; label?: string }> = ({
  f,
  fps,
  widget,
  slot = SLOT,
  glow: glowRgb = "120,230,255",
  label: labelColor = "#fff",
}) => {
  const s = spring({ frame: f - 6, fps, config: { damping: 12, stiffness: 120, mass: 0.8 } });
  const o = interpolate(f, [6, 12], [0, 1], clamp);
  const label = interpolate(f, [26, 34], [0, 1], clamp);
  const glow = interpolate(f, [24, 34, 60], [0, 1, 0], clamp);
  const [x, y, w, h] = slot;
  return (
    <>
      <div
        style={{
          position: "absolute",
          left: x,
          top: y,
          width: w,
          height: h,
          opacity: o,
          transform: `translateY(${(1 - s) * 520}px) scale(${1.25 - 0.25 * s})`,
          filter: `drop-shadow(0 ${30 * (1 - s) + 10}px ${50 * (1 - s) + 20}px rgba(0,0,0,0.45))`,
        }}
      >
        <Img src={cap(widget)} style={{ width: w, height: h }} />
        <div style={{ position: "absolute", inset: -6, borderRadius: 72, boxShadow: `0 0 60px 10px rgba(${glowRgb},${0.55 * glow})` }} />
      </div>
      <div style={{ position: "absolute", left: 0, top: y + h + 22, width: CW, textAlign: "center", fontFamily: FONT, fontWeight: 500, fontSize: 36, color: labelColor, opacity: label, textShadow: labelColor === "#fff" ? "0 1px 6px rgba(0,0,0,0.4)" : "none" }}>
        Ardane
      </div>
    </>
  );
};

// ------------------------------------------------------------------------------------------------ taps
/** A finger tap: a soft white disc that presses, then a ring that spreads. `at` = frame of the touch. */
export const Tap: React.FC<{ f: number; at: number; x: number; y: number }> = ({ f, at, x, y }) => {
  if (f < at - 6 || f > at + 16) return null;
  const inn = interpolate(f, [at - 6, at, at + 8], [0, 1, 0], clamp);
  const ring = interpolate(f, [at, at + 16], [0, 1], clamp);
  return (
    <>
      <div style={{ position: "absolute", left: x - 60, top: y - 60, width: 120, height: 120, borderRadius: 60, background: `rgba(255,255,255,${0.55 * inn})`, boxShadow: `0 0 0 6px rgba(0,0,0,${0.12 * inn})`, transform: `scale(${0.8 + 0.2 * inn})` }} />
      <div style={{ position: "absolute", left: x - 60, top: y - 60, width: 120, height: 120, borderRadius: 60, border: `6px solid rgba(255,255,255,${0.7 * (1 - ring)})`, transform: `scale(${1 + 1.2 * ring})` }} />
    </>
  );
};

// ------------------------------------------------------------------------------------------------ photo scan
const CAM = { y0: 400, y1: 2300 };
const SQ = { x: 78, y: 760, s: 1050 };

const Corner: React.FC<{ x: number; y: number; dx: 1 | -1; dy: 1 | -1; o: number }> = ({ x, y, dx, dy, o }) => (
  <div
    style={{
      position: "absolute",
      left: dx > 0 ? x + o : x - o - 150,
      top: dy > 0 ? y + o : y - o - 150,
      width: 150,
      height: 150,
      borderStyle: "solid",
      borderColor: "#fff",
      borderWidth: 0,
      [dx > 0 ? "borderLeftWidth" : "borderRightWidth"]: 16,
      [dy > 0 ? "borderTopWidth" : "borderBottomWidth"]: 16,
      [dx > 0 ? (dy > 0 ? "borderTopLeftRadius" : "borderBottomLeftRadius") : dy > 0 ? "borderTopRightRadius" : "borderBottomRightRadius"]: 64,
      filter: "drop-shadow(0 0 14px rgba(255,255,255,0.35))",
    }}
  />
);

/** The scan screen, `t` in 60-fps frames: shutter 22–28, frame closes 42–74, sweep 74–132, « Analyzing… » from 88. */
export const PhotoScan: React.FC<{ t: number }> = ({ t }) => {
  const flash = interpolate(t, [26, 29, 46], [0, 0.55, 0], clamp);
  const press = interpolate(t, [22, 28, 40], [1, 0.82, 1], clamp);
  const cornerO = interpolate(t, [42, 74], [190, 0], { ...clamp, easing: split });
  const cornerOp = interpolate(t, [42, 52], [0, 1], clamp);
  const sweep = interpolate(t, [74, 132], [0, 1], { ...clamp, easing: Easing.bezier(0.4, 0, 0.6, 1) });
  const analyze = interpolate(t, [88, 102], [0, 1], { ...clamp, easing: split });
  const spin = (t * 9) % 360;
  return (
    <div style={{ position: "absolute", left: 0, top: 0, width: CW, height: CH, overflow: "hidden", background: "#000" }}>
      <Img src={cap("scan-frame-dark")} style={{ position: "absolute", left: 0, top: 0, width: CW, height: CH }} />
      <div style={{ position: "absolute", left: 0, top: CAM.y0, width: CW, height: CAM.y1 - CAM.y0, background: "#000", overflow: "hidden" }}>
        <Img src={staticFile(PHOTO)} style={{ position: "absolute", left: -380, top: -40, width: 1966, height: 1966, objectFit: "cover", filter: "blur(46px) brightness(0.45)" }} />
      </div>
      <div style={{ position: "absolute", left: SQ.x, top: SQ.y, width: SQ.s, height: SQ.s, borderRadius: 46, overflow: "hidden", boxShadow: "0 30px 80px rgba(0,0,0,0.6)" }}>
        <Img src={staticFile(PHOTO)} style={{ position: "absolute", inset: 0, width: SQ.s, height: SQ.s, objectFit: "cover" }} />
        {sweep > 0 && sweep < 1 && (
          <div
            style={{
              position: "absolute",
              left: 0,
              top: sweep * (SQ.s + 220) - 220,
              width: SQ.s,
              height: 220,
              background: "linear-gradient(to bottom, transparent, rgba(214,233,250,0.28) 55%, rgba(255,255,255,0.8) 98%, rgba(255,255,255,0))",
              boxShadow: "0 0 50px 8px rgba(104,181,245,0.45)",
            }}
          />
        )}
        <div style={{ position: "absolute", inset: 0, background: "#fff", opacity: flash }} />
      </div>
      <div style={{ position: "absolute", inset: 0, opacity: cornerOp }}>
        <Corner x={SQ.x + 30} y={SQ.y + 30} dx={1} dy={1} o={cornerO} />
        <Corner x={SQ.x + SQ.s - 30} y={SQ.y + 30} dx={-1} dy={1} o={cornerO} />
        <Corner x={SQ.x + 30} y={SQ.y + SQ.s - 30} dx={1} dy={-1} o={cornerO} />
        <Corner x={SQ.x + SQ.s - 30} y={SQ.y + SQ.s - 30} dx={-1} dy={-1} o={cornerO} />
      </div>
      <div style={{ position: "absolute", left: 603 - 70, top: 1960, width: 140, height: 140, borderRadius: 70, border: "9px solid #fff", boxSizing: "border-box", opacity: 1 - analyze }}>
        <div style={{ position: "absolute", inset: 12, borderRadius: 60, background: "#fff", transform: `scale(${press})` }} />
      </div>
      <div style={{ position: "absolute", left: 0, top: 2124, width: CW, textAlign: "center", fontFamily: FONT, fontWeight: 600, fontSize: 46, color: "#fff", opacity: 1 - analyze }}>Photograph the meal</div>
      <div
        style={{
          position: "absolute",
          left: 603 - 500,
          top: 1996,
          width: 1000,
          height: 132,
          borderRadius: 66,
          background: "rgba(20,26,34,0.88)",
          border: "3px solid rgba(214,233,250,0.45)",
          boxShadow: "0 0 70px rgba(78,155,224,0.4)",
          display: "flex",
          alignItems: "center",
          justifyContent: "center",
          gap: 30,
          opacity: analyze,
          transform: `translateY(${(1 - analyze) * 30}px)`,
          fontFamily: FONT,
          fontWeight: 600,
          fontSize: 46,
          color: "#fff",
          whiteSpace: "nowrap",
        }}
      >
        <svg width="58" height="58" viewBox="0 0 58 58" style={{ transform: `rotate(${spin}deg)` }}>
          <circle cx="29" cy="29" r="22" fill="none" stroke="rgba(255,255,255,0.25)" strokeWidth="7" />
          <path d="M29 7 A22 22 0 0 1 51 29" fill="none" stroke="#4FD3E8" strokeWidth="7" strokeLinecap="round" />
        </svg>
        Analyzing your meal on your iPhone…
      </div>
    </div>
  );
};

const Card: React.FC<{ y: number; h: number; o: number; children: React.ReactNode }> = ({ y, h, o, children }) => (
  <div style={{ position: "absolute", left: 48, top: y + (1 - o) * 40, width: 1110, height: h, borderRadius: 60, background: "#FFFFFF", boxShadow: "0 8px 30px rgba(40,60,90,0.10)", opacity: o, overflow: "hidden" }}>{children}</div>
);

const Row: React.FC<{ y: number; h?: number; left: React.ReactNode; right: React.ReactNode; sub?: string; dot?: string; line?: boolean }> = ({ y, h = 150, left, right, sub, dot, line = true }) => (
  <div style={{ position: "absolute", left: 0, top: y, width: 1110, height: h }}>
    {dot && <div style={{ position: "absolute", left: 40, top: h / 2 - 11, width: 22, height: 22, borderRadius: 11, background: dot }} />}
    <div style={{ position: "absolute", left: dot ? 86 : 54, top: sub ? 28 : h / 2 - 32, fontFamily: FONT, fontWeight: 500, fontSize: 52, color: INK, whiteSpace: "nowrap" }}>{left}</div>
    {sub && <div style={{ position: "absolute", left: dot ? 86 : 54, top: 90, fontFamily: FONT, fontWeight: 400, fontSize: 38, color: GREY }}>{sub}</div>}
    <div style={{ position: "absolute", right: 54, top: h / 2 - 32, fontFamily: FONT, fontWeight: 400, fontSize: 52, color: GREY, whiteSpace: "nowrap" }}>{right}</div>
    {line && <div style={{ position: "absolute", left: 54, right: 0, bottom: 0, height: 2, background: "rgba(60,70,90,0.12)" }} />}
  </div>
);

/** The Summary screen after the photo, `t` in 60-fps frames: foods 8–40, totals count up 14–60, « Add to log » from 66. */
export const PhotoSummary: React.FC<{ t: number }> = ({ t }) => {
  const o = (a: number) => interpolate(t, [a, a + 16], [0, 1], { ...clamp, easing: split });
  const k = (a: number, b: number) => interpolate(t, [a, b], [0, 1], { ...clamp, easing: Easing.bezier(0.25, 0.1, 0, 1) });
  const sh = (v: number, a: number, b: number, d = 0) => (v * k(a, b)).toFixed(d);
  const kcal = Math.round(TOTAL.kcal * k(14, 60));
  const btn = interpolate(t, [66, 80], [0, 1], clamp);
  const approx = k(14, 60) > 0.98 ? "≈ " : "";
  return (
    <div style={{ position: "absolute", left: 0, top: 0, width: CW, height: CH, overflow: "hidden", background: "linear-gradient(to bottom, #B7C8D8 0%, #D2DEEB 28%, #E9EFF6 55%, #F2F6FA 88%, #F9FBFB 100%)" }}>
      <Img src={cap("scan-recap-photo")} style={{ position: "absolute", left: 0, top: 0, width: CW, height: CH, clipPath: "inset(0 0 2310px 0)" }} />
      <div style={{ position: "absolute", left: 100, top: 372, fontFamily: FONT, fontWeight: 500, fontSize: 44, color: GREY, opacity: o(0) }}>Foods</div>
      <Card y={440} h={620} o={o(0)}>
        {FOODS.map((fd, i) => (
          <div key={fd.name} style={{ opacity: o(8 + i * 8), transform: `translateX(${(1 - o(8 + i * 8)) * 60}px)` }}>
            <Row y={i * 150} left={fd.name} sub={`${fd.grams} g`} right={`≈ ${fd.kcal} kcal`} />
          </div>
        ))}
        <div style={{ position: "absolute", left: 54, top: 470, width: 1002, height: 120, display: "flex", alignItems: "center", gap: 28, fontFamily: FONT, fontWeight: 500, fontSize: 52, color: BLUE }}>
          <div style={{ width: 62, height: 62, borderRadius: 31, background: BLUE, color: "#fff", display: "flex", alignItems: "center", justifyContent: "center", fontSize: 54, lineHeight: 1 }}>+</div>
          Add a food
        </div>
      </Card>
      <div style={{ position: "absolute", left: 100, top: 1082, width: 1000, fontFamily: FONT, fontWeight: 400, fontSize: 38, lineHeight: 1.25, color: GREY, opacity: o(18) }}>
        Estimated from the photo, analyzed on your iPhone and not saved.
      </div>
      <Card y={1190} h={150} o={o(14)}>
        <Row y={0} left="Meals" right={<span style={{ color: BLUE }}>Lunch</span>} line={false} />
      </Card>
      <div style={{ position: "absolute", left: 100, top: 1520, fontFamily: FONT, fontWeight: 500, fontSize: 44, color: GREY, opacity: o(8) }}>Total</div>
      <Card y={1580} h={600} o={o(8)}>
        <Row y={0} left="Calories" right={`${approx}${kcal} kcal`} dot="#FF9500" />
        <Row y={150} left="Protein" right={`${approx}${sh(TOTAL.protein, 14, 60)} g`} dot="#FF3B30" />
        <Row y={300} left="Carbs" right={`${approx}${sh(TOTAL.carbs, 14, 60)} g`} dot="#FFCC00" />
        <Row y={450} left="Fat" right={`${approx}${sh(TOTAL.fat, 14, 60)} g`} dot="#0A84FF" line={false} />
      </Card>
      <div style={{ position: "absolute", left: 100, top: 2196, fontFamily: FONT, fontWeight: 400, fontSize: 38, color: GREY, opacity: o(50) }}>
        After adding, you&apos;ll have {TOTAL.left.toLocaleString("en-US")} kcal left.
      </div>
      <div style={{ position: "absolute", left: 48, top: 2268, width: 1110, height: 124, borderRadius: 62, background: ORANGE, opacity: btn, display: "flex", alignItems: "center", justifyContent: "center", fontFamily: FONT, fontWeight: 600, fontSize: 56, color: "#fff", transform: `scale(${0.96 + 0.04 * btn})` }}>
        Add to log
      </div>
    </div>
  );
};
