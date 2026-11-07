// App screens of the « strength workout » journey (2026-11-06), on the 1206 x 2622 grid of the captures:
// build the workout from the library (exercise sheet with its animated demo), log a set, create the medium
// « Today's workout » widget in the Studio and place it on the Home Screen, then the Live Activity on the Lock Screen.
import React from "react";
import { Img, interpolate } from "remotion";
import { cap, clamp, FPS, out } from "../lib";
import { CH, CW, GRAPHITE, HomeBase, Landing, Tap } from "./Screens";
import { BuilderFlow, builderEnd, BuilderPlan, PushIn, StudioChoice, StudioStep } from "./Create";

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
            // the light demo, on the light background of the exercise sheet (ex-1: rgb 243,243,245)
            background: "rgb(243,243,245)",
            boxShadow: "0 16px 40px rgba(0,0,0,0.12)",
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

/** The workout widget, with the mechanic of every ad: Create tab → Fitness → the builder (« Today's workout », the widget
 * that follows the exercise) → « Customize widget » → the real Studio with the real exports of that widget in four styles →
 * « Save widget » → it lands on a black and grey Home Screen (colours of Fitness). */
export const FIT_BUILDER: BuilderPlan = { space: "fitness", tapSpace: [420, 1000], tapTile: [258, 2120], tapCustomize: [603, 2390] };
const B_END = builderEnd(FIT_BUILDER);
const STYLES: StudioChoice[] = [
  { at: 0, w: "todaysWorkout-m-light", name: "Light", tag: "Free" },
  { at: 18, w: "todaysWorkout-m-aurora", name: "Aurora", tag: "Premium" },
  { at: 34, w: "todaysWorkout-m-liquidGlass", name: "Liquid Glass", tag: "Premium" },
  { at: 50, w: "todaysWorkout-m-dark", name: "Dark", tag: "Free" },
];
export const WIDGET_FINAL = "todaysWorkout-m-dark";
export const SAVE_AT = 70;
export const HOME_AT = 80;
/** Frames of the whole widget part before the landing settles (builder + Studio + 50 frames on the Home Screen). */
export const WIDGET_FRAMES = B_END + HOME_AT + 50;

export const WidgetScreen: React.FC<{ f: number; fps: number }> = ({ f, fps }) => {
  if (f < B_END) return <BuilderFlow f={f} plan={FIT_BUILDER} />;
  const g = f - B_END;
  if (g >= HOME_AT) return <HomeBase theme={GRAPHITE} filled={<Landing f={g - HOME_AT} fps={fps} widget={WIDGET_FINAL} glow="229,72,77" />} />;
  return (
    <PushIn f={g} under={<BuilderFlow f={B_END - 1} plan={FIT_BUILDER} />}>
      <StudioStep f={g} base="studio-style" choices={STYLES} saveAt={SAVE_AT} />
    </PushIn>
  );
};

/** Lock Screen: the Live Activity of the session (real captures, one per second: 1:00 → 0:45, then 2:00 → 1:50): rest counting down, « Set done » pressed without
 * unlocking, the set is checked and the next rest starts. */
export const LOCK = "lock-minuit";
const LA = { x: 45, y: 1640, w: 1116, h: 465 };
export const LockScreen: React.FC<{ f: number; done?: number }> = ({ f, done = 44 }) => {
  const DONE = done; // frame of the « Set done » touch (synced with the voice by the template)
  const appear = interpolate(f, [0, 10], [0, 1], { ...clamp, easing: out });
  const frame = f < DONE ? seq3("live-rest-real", Math.floor(f / FPS), 16) : seq3("live-afterset-real", Math.floor((f - DONE) / FPS), 11);
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
