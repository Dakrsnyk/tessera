import { createContext, useContext } from "react";
import { interpolate } from "remotion";
import { ArdaneLogo } from "../components/ArdaneLogo";
import { C, clamp, INTER } from "../lib/brand";
import { K, useL } from "./ctx";

/** A phone drawn in CSS 3D. Everything inside is authored in the 1206 × 2622 space of the captures. */
export type Cam = { s: number; x: number; y: number; ry: number; rx: number; rz: number; o: number };
export const CAM0: Cam = { s: 1, x: 0, y: 0, ry: 0, rx: 0, rz: 0, o: 1 };
export const camMix = (a: Partial<Cam>, b: Partial<Cam>, p: number): Cam => {
  const A = { ...CAM0, ...a };
  const B = { ...CAM0, ...b };
  const m = (k: keyof Cam) => A[k] + (B[k] - A[k]) * p;
  return { s: m("s"), x: m("x"), y: m("y"), ry: m("ry"), rx: m("rx"), rz: m("rz"), o: m("o") };
};

const PhoneCtx = createContext(1);
/** Scale of the phone space to output px (for text that must keep a screen size). */
export const usePhoneScale = () => useContext(PhoneCtx);

export const Phone: React.FC<{ cam?: Partial<Cam>; children?: React.ReactNode; over?: React.ReactNode; dim?: number; at?: { cx: number; cy: number } }> = ({ cam, children, over, dim = 0, at }) => {
  const L = useL();
  const c = { ...CAM0, ...cam };
  const bodyH = L.phone.h;
  const screenH = bodyH * 0.974;
  const k = L.k;
  const screenW = 1206 * k;
  const bodyW = screenW + (bodyH - screenH);
  const pad = (bodyH - screenH) / 2;
  const cx = at?.cx ?? L.phone.cx;
  const cy = at?.cy ?? L.phone.cy;
  const back = Math.abs((((c.ry % 360) + 540) % 360) - 180) > 90;
  const radius = bodyW * 0.165;
  const face: React.CSSProperties = { position: "absolute", left: -bodyW / 2, top: -bodyH / 2, width: bodyW, height: bodyH, borderRadius: radius, backfaceVisibility: "hidden", WebkitBackfaceVisibility: "hidden" };
  return (
    <PhoneCtx.Provider value={k}>
      <div style={{ position: "absolute", left: cx, top: cy, width: 0, height: 0, perspective: 2800, opacity: c.o }}>
        <div style={{ position: "absolute", left: 0, top: 0, transformStyle: "preserve-3d", transform: `translate(${c.x * k}px, ${c.y * k}px) rotateX(${c.rx}deg) rotateY(${c.ry}deg) rotateZ(${c.rz}deg) scale(${c.s})` }}>
          {/* Sapphire halo behind the phone. */}
          <div style={{ position: "absolute", left: -bodyW * 0.75, top: -bodyH * 0.55, width: bodyW * 1.5, height: bodyH * 1.1, background: "radial-gradient(ellipse at center, rgba(36,91,143,0.42) 0%, rgba(36,91,143,0) 62%)", transform: "translateZ(-60px)", pointerEvents: "none" }} />
          <div style={{ ...face, background: "linear-gradient(145deg,#39424F 0%,#0C1117 38%,#202A36 100%)", boxShadow: "0 0 0 1.5px rgba(104,181,245,0.35), 0 50px 120px rgba(0,0,0,0.65)" }}>
            <div style={{ position: "absolute", left: pad, top: pad, width: screenW, height: screenH, borderRadius: radius - pad, overflow: "hidden", background: "#000" }}>
              <div style={{ position: "absolute", left: 0, top: 0, width: 1206, height: 2622, transformOrigin: "0 0", transform: `scale(${k})` }}>{children}</div>
              {dim > 0 && <div style={{ position: "absolute", inset: 0, background: `rgba(0,0,0,${dim})` }} />}
              <div style={{ position: "absolute", inset: 0, background: "linear-gradient(115deg, rgba(255,255,255,0.10) 0%, rgba(255,255,255,0) 32%, rgba(104,181,245,0.07) 100%)", pointerEvents: "none" }} />
            </div>
          </div>
          <div style={{ ...face, transform: "rotateY(180deg)", background: "linear-gradient(145deg,#2A3340,#10161E 55%,#1E2833)", boxShadow: "0 0 0 1.5px rgba(104,181,245,0.3)", display: back ? "block" : "none" }}>
            <div style={{ position: "absolute", left: bodyW / 2, top: bodyH * 0.42 }}>
              <ArdaneLogo size={bodyW * 0.3} cx={0} cy={0} glow={0.8} />
            </div>
          </div>
          {over && <div style={{ position: "absolute", left: -screenW / 2, top: -screenH / 2, width: 1206, height: 2622, transformOrigin: "0 0", transform: `scale(${k}) translateZ(40px)`, pointerEvents: "none" }}>{over}</div>}
        </div>
      </div>
    </PhoneCtx.Provider>
  );
};

/* ------------------------------------------------ composed screens (1206 space) */
export type Slot = { name: string; x?: number; y?: number; w?: number; size?: "m" | "s" | "l" };

/** Home rows of the captures: medium widgets at x 57, w 1092; small ones 510 wide at x 57 / 638; rows every 609 from y 204. */
export const homeRect = (row: number, col: 0 | 1 | "full", size: "m" | "s" | "l"): { x: number; y: number; w: number } => {
  const y = 204 + row * 609;
  if (size === "s") return { x: col === 1 ? 638 : 57, y, w: 510 };
  return { x: 57, y, w: 1092 };
};

const StatusBar: React.FC<{ dark?: boolean }> = ({ dark }) => (
  <>
    <div style={{ position: "absolute", left: 420, top: 32, width: 366, height: 108, borderRadius: 54, background: "#000" }} />
    <div style={{ position: "absolute", left: 150, top: 56, fontFamily: INTER, fontWeight: 650, fontSize: 70, color: dark ? "#fff" : "#111" }}>9:41</div>
  </>
);

/** A Home Screen built from a wallpaper, real widget renders and the dock icons: what the 3 profiles and the gathers show. */
export const HomeCompose: React.FC<{ wall: string; widgets: (Slot & { o?: number; dx?: number; dy?: number; sc?: number })[]; dock?: string; dark?: boolean }> = ({ wall, widgets, dock, dark = true }) => (
  <>
    <K name={wall} style={{ position: "absolute", left: 0, top: 0 }} />
    <StatusBar dark={dark} />
    {widgets.map((w, i) => {
      const size = w.size ?? (/-s-/.test(w.name) ? "s" : "m");
      const w0 = w.w ?? (size === "s" ? 510 : 1092);
      const sc = w.sc ?? 1;
      return (
        <div key={i} style={{ position: "absolute", left: (w.x ?? 57) + (w.dx ?? 0), top: (w.y ?? 204) + (w.dy ?? 0), opacity: w.o ?? 1, transform: `scale(${sc})`, transformOrigin: "50% 50%", filter: "drop-shadow(0 6px 14px rgba(0,0,0,0.25))" }}>
          <K name={w.name} w={w0} />
        </div>
      );
    })}
    {dock && [0, 1, 2, 3].map((i) => <K key={i} name={`icons-${dock}-${i + 4}`} w={222} style={{ position: "absolute", left: [64, 349, 635, 920][i], top: 2340 }} />)}
  </>
);

/** A Lock Screen: wallpaper, the clock, real lock widgets (rects / circles) and an optional Live Activity strip. */
export const LockCompose: React.FC<{ wall: string; dark?: boolean; widgets?: { name: string; x: number; y: number; w?: number; o?: number }[]; live?: { name: string; o?: number; y?: number } }> = ({ wall, dark = true, widgets = [], live }) => (
  <>
    <K name={wall} style={{ position: "absolute", left: 0, top: 0 }} />
    <div style={{ position: "absolute", left: 420, top: 32, width: 366, height: 108, borderRadius: 54, background: "#000" }} />
    <div style={{ position: "absolute", left: 0, width: 1206, top: 250, textAlign: "center", fontFamily: INTER, fontWeight: 720, fontSize: 380, letterSpacing: "-0.03em", lineHeight: 1, color: dark ? "#F5F5F7" : "#1F2B45", fontVariationSettings: "'opsz' 32" }}>9:41</div>
    {widgets.map((w, i) => (
      <K key={i} name={w.name} w={w.w} style={{ position: "absolute", left: w.x, top: w.y, opacity: w.o ?? 1 }} />
    ))}
    {live && <K name={live.name} w={1116} style={{ position: "absolute", left: 45, top: live.y ?? 1650, opacity: live.o ?? 1 }} />}
  </>
);

export const lerp = (f: number, a: number, b: number, from: number, to: number, e?: (t: number) => number) => interpolate(f, [a, b], [from, to], { ...clamp, easing: e });
export { C };
