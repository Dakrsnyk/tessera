// App screens of the « strength workout » journey (2026-11-06), on the 1206 x 2622 grid of the captures:
// build the workout from the library (exercise sheet with its animated demo), log a set, create the medium
// « Today's workout » widget in the Studio and place it on the Home Screen, then the Live Activity on the Lock Screen.
import React from "react";
import { Img, interpolate } from "remotion";
import { cap, clamp, FONT, out } from "../lib";
import { CH, CW, HomeBase, Landing, SLOT_MIDDLE, Tap } from "./Screens";

const seq = (name: string, i: number, n: number) => `${name}-${String(Math.min(n - 1, Math.max(0, i))).padStart(4, "0")}`;
const seq3 = (name: string, i: number, n: number) => `${name}-${String(Math.min(n - 1, Math.max(0, i))).padStart(3, "0")}`;

/** Build: Fitness → Exercises → Bench press (sheet + animated demo) → « Add to my workout ». Frames at 30 fps. */
export const BuildScreen: React.FC<{ f: number }> = ({ f }) => {
  const LIB = 22;
  const SHEET = 50;
  const screen = f < LIB ? "app-fitness-s04" : f < SHEET ? "app-fitness-library" : "app-fitness-exercise-bench-press-end";
  const demoIn = interpolate(f, [SHEET + 2, SHEET + 12], [0, 1], { ...clamp, easing: out });
  return (
    <div style={{ position: "absolute", width: CW, height: CH, overflow: "hidden" }}>
      <Img src={cap(screen)} style={{ position: "absolute", width: CW, height: CH }} />
      {f >= SHEET && (
        // the exercise's own demo (demo-bench-press-*, 240 frames at 60 fps), shown at the top of its sheet
        <div
          style={{
            position: "absolute",
            left: 48,
            top: 300,
            width: 1110,
            height: 652,
            borderRadius: 56,
            overflow: "hidden",
            background: "#000",
            boxShadow: "0 20px 50px rgba(0,0,0,0.25)",
            opacity: demoIn,
            transform: `scale(${0.94 + 0.06 * demoIn})`,
          }}
        >
          <Img src={cap(seq("demo-bench-press", (f - SHEET) * 2 + 40, 240))} style={{ width: 1110, height: 652 }} />
        </div>
      )}
      <Tap f={f} at={16} x={450} y={1921} />
      <Tap f={f} at={42} x={450} y={1288} />
      <Tap f={f} at={SHEET + 70} x={603} y={2268} />
    </div>
  );
};

/** Train: the session screen, « Set done », then the rest starts (real captures session-0 → session-2). */
export const TrainScreen: React.FC<{ f: number }> = ({ f }) => (
  <div style={{ position: "absolute", width: CW, height: CH, overflow: "hidden" }}>
    <Img src={cap(f < 30 ? "session-0" : "session-2")} style={{ position: "absolute", width: CW, height: CH }} />
    <Tap f={f} at={24} x={603} y={1447} />
  </div>
);

/** The workout widget in the Studio: the real editor (header, preview, sizes, tabs) with the real exports of the
 * « Today's workout » widget in four styles; then « Save widget » and the widget lands on the Home Screen. */
const STYLES = [
  { at: 0, w: "todaysWorkout-m-light", name: "Light", tag: "Free" },
  { at: 18, w: "todaysWorkout-m-aurora", name: "Aurora", tag: "Premium" },
  { at: 34, w: "todaysWorkout-m-liquidGlass", name: "Liquid Glass", tag: "Premium" },
  { at: 50, w: "todaysWorkout-m-dark", name: "Dark", tag: "Free" },
];
export const WIDGET_FINAL = "todaysWorkout-m-dark";
export const SAVE_AT = 72;
export const HOME_AT = 82;

const Tile: React.FC<{ w: string; name: string; tag: string; x: number; y: number; on: boolean }> = ({ w, name, tag, x, y, on }) => (
  <div style={{ position: "absolute", left: x, top: y, width: 500 }}>
    <div style={{ width: 500, height: 234, borderRadius: 34, padding: 10, boxSizing: "border-box", border: on ? "6px solid #2A5D93" : "6px solid transparent" }}>
      <Img src={cap(w)} style={{ width: "100%", height: "100%" }} />
    </div>
    <div style={{ textAlign: "center", fontFamily: FONT, fontWeight: on ? 700 : 500, fontSize: 34, color: "#1B2430", marginTop: 8 }}>{name}</div>
    <div style={{ textAlign: "center", fontFamily: FONT, fontWeight: 400, fontSize: 28, color: "#8A94A0" }}>{tag}</div>
  </div>
);

export const WidgetScreen: React.FC<{ f: number; fps: number }> = ({ f, fps }) => {
  if (f >= HOME_AT) return <HomeBase free="middle" filled={<Landing f={f - HOME_AT} fps={fps} widget={WIDGET_FINAL} slot={SLOT_MIDDLE} />} />;
  let k = 0;
  STYLES.forEach((s, i) => {
    if (f >= s.at) k = i;
  });
  const swap = k > 0 ? interpolate(f, [STYLES[k].at, STYLES[k].at + 6], [0, 1], clamp) : 1;
  return (
    <div style={{ position: "absolute", width: CW, height: CH, overflow: "hidden" }}>
      <Img src={cap("studio-style")} style={{ position: "absolute", width: CW, height: CH }} />
      {/* the preview: the macros example of the capture is covered, the workout widget takes its place */}
      <div style={{ position: "absolute", left: 110, top: 432, width: 986, height: 478, borderRadius: 60, background: "rgb(217,225,232)" }} />
      {k > 0 && <Img src={cap(STYLES[k - 1].w)} style={{ position: "absolute", left: 128, top: 448, width: 952, height: 444 }} />}
      <Img src={cap(STYLES[k].w)} style={{ position: "absolute", left: 128, top: 448, width: 952, height: 444, opacity: swap, filter: "drop-shadow(0 12px 24px rgba(0,0,0,0.12))" }} />
      {/* the style choices, with the same widget */}
      <div style={{ position: "absolute", left: 0, top: 1370, width: CW, height: 900, background: "rgb(233,239,245)" }}>
        {STYLES.map((s, i) => (
          <Tile key={s.w} w={s.w} name={s.name} tag={s.tag} x={i % 2 ? 640 : 66} y={i < 2 ? 30 : 450} on={i === k} />
        ))}
      </div>
      <Tap f={f} at={16} x={890} y={1520} />
      <Tap f={f} at={32} x={316} y={1940} />
      <Tap f={f} at={48} x={890} y={1940} />
      <Tap f={f} at={SAVE_AT} x={603} y={2393} />
    </div>
  );
};

/** Lock Screen: the Live Activity of the session (real captures): rest counting down, « Set done » pressed without
 * unlocking, the set is checked and the next rest starts. */
export const LOCK = "lock-minuit";
const LA = { x: 45, y: 1640, w: 1116, h: 465 };
export const LockScreen: React.FC<{ f: number; done?: number }> = ({ f, done = 44 }) => {
  const DONE = done; // frame of the « Set done » touch (synced with the voice by the template)
  const appear = interpolate(f, [0, 10], [0, 1], { ...clamp, easing: out });
  const frame = f < DONE ? seq3("live-rest-real", Math.floor((f * 16) / DONE), 16) : seq3("live-afterset-real", Math.floor((f - DONE) / 3), 11);
  return (
    <div style={{ position: "absolute", width: CW, height: CH, overflow: "hidden" }}>
      <Img src={cap(LOCK)} style={{ position: "absolute", width: CW, height: CH }} />
      <Img
        src={cap(frame)}
        style={{ position: "absolute", left: LA.x, top: LA.y, width: LA.w, height: LA.h, opacity: appear, transform: `translateY(${(1 - appear) * 80}px)` }}
      />
      <Tap f={f} at={DONE - 2} x={LA.x + 925} y={LA.y + 360} />
    </div>
  );
};

export const FitnessHome: React.FC = () => <Img src={cap("app-fitness-s04")} style={{ position: "absolute", width: CW, height: CH }} />;
