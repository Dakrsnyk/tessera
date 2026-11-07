// The widget mechanic that every TikTok ad shows (rule of the user, 2026-11-06): the Create tab, the builder of the
// mini-app's space (its widgets to choose from), the Studio (styles), then the widget lands on a Home Screen in the
// mini-app's colours. Real captures of the English kit: spaces, creator-<space>[-medium] (scripts/ad_screens.txt), the
// real Studio (studio-style / studio-theme) whose preview and choices show the ad's widget (real exports of that widget).
import React from "react";
import { Img, interpolate } from "remotion";
import { cap, clamp, FONT, out } from "../lib";
import { CH, CW, Tap } from "./Screens";

type P = [number, number];

export type BuilderPlan = {
  /** creator-<space> (and creator-<space>-medium when `medium` is given). */
  space: "fitness" | "student" | "nutrition" | "budget";
  /** The card of the space on the Create tab; without it (card further down the list), a tap on the Create tab. */
  tapSpace?: P;
  /** The widget chosen in the grid of the builder. */
  tapTile: P;
  /** The « Medium » size (the builder then shows its medium preview). */
  medium?: P;
  /** « Customize widget ». */
  tapCustomize: P;
};

const SHEET = 14;
const TILE = 27;
const MEDIUM = 38;
export const builderEnd = (p: BuilderPlan) => (p.medium ? 60 : 48);

const Full: React.FC<{ src: string }> = ({ src }) => <Img src={cap(src)} style={{ position: "absolute", left: 0, top: 0, width: CW, height: CH }} />;

/** Create tab → the space's builder (a sheet) → a widget → (Medium) → « Customize widget ». Frames at 30 fps. */
export const BuilderFlow: React.FC<{ f: number; plan: BuilderPlan }> = ({ f, plan }) => {
  const end = builderEnd(plan);
  const sheet = interpolate(f, [SHEET, SHEET + 9], [0, 1], { ...clamp, easing: out });
  const builder = plan.medium && f >= MEDIUM + 3 ? `creator-${plan.space}-medium` : `creator-${plan.space}`;
  return (
    <div style={{ position: "absolute", width: CW, height: CH, overflow: "hidden", background: "#000" }}>
      <Full src="spaces" />
      <Tap f={f} at={7} x={plan.tapSpace?.[0] ?? 471} y={plan.tapSpace?.[1] ?? 2456} />
      {f >= SHEET && (
        <div style={{ position: "absolute", left: 0, top: (1 - sheet) * CH, width: CW, height: CH }}>
          <Full src={builder} />
        </div>
      )}
      <Tap f={f} at={TILE} x={plan.tapTile[0]} y={plan.tapTile[1]} />
      {plan.medium && <Tap f={f} at={MEDIUM} x={plan.medium[0]} y={plan.medium[1]} />}
      <Tap f={f} at={end - 6} x={plan.tapCustomize[0]} y={plan.tapCustomize[1]} />
    </div>
  );
};

/** The Studio is pushed over the builder (from the right) during its first frames. */
export const PushIn: React.FC<{ f: number; under: React.ReactNode; children: React.ReactNode }> = ({ f, under, children }) => {
  const p = interpolate(f, [0, 9], [0, 1], { ...clamp, easing: out });
  if (p >= 1) return <>{children}</>;
  return (
    <div style={{ position: "absolute", width: CW, height: CH, overflow: "hidden", background: "#000" }}>
      <div style={{ position: "absolute", width: CW, height: CH, transform: `translateX(${-0.3 * p * CW}px)`, opacity: 1 - 0.3 * p }}>{under}</div>
      <div style={{ position: "absolute", width: CW, height: CH, transform: `translateX(${(1 - p) * CW}px)`, boxShadow: "-20px 0 40px rgba(0,0,0,0.25)" }}>{children}</div>
    </div>
  );
};

export type StudioChoice = { at: number; w: string; name: string; tag: string };

const Tile: React.FC<{ w: string; name: string; tag: string; x: number; y: number; on: boolean }> = ({ w, name, tag, x, y, on }) => (
  <div style={{ position: "absolute", left: x, top: y, width: 500 }}>
    <div style={{ width: 500, height: 234, borderRadius: 34, padding: 10, boxSizing: "border-box", border: on ? "6px solid #2A5D93" : "6px solid transparent" }}>
      <Img src={cap(w)} style={{ width: "100%", height: "100%" }} />
    </div>
    <div style={{ textAlign: "center", fontFamily: FONT, fontWeight: on ? 700 : 500, fontSize: 34, color: "#1B2430", marginTop: 8 }}>{name}</div>
    <div style={{ textAlign: "center", fontFamily: FONT, fontWeight: 400, fontSize: 28, color: "#8A94A0" }}>{tag}</div>
  </div>
);

const tileXY = (i: number, top: number) => ({ x: i % 2 ? 640 : 66, y: (i < 2 ? 20 : 430) + top });

/** The real Studio (its header, preview, sizes and tabs), whose preview and choices show the ad's widget in each
 * style or theme (real exports of that widget); a tap on each choice, then « Save widget » at `saveAt`. */
export const StudioStep: React.FC<{ f: number; base: "studio-style" | "studio-theme"; choices: StudioChoice[]; saveAt: number }> = ({ f, base, choices, saveAt }) => {
  let k = 0;
  choices.forEach((s, i) => {
    if (f >= s.at) k = i;
  });
  const swap = k > 0 ? interpolate(f, [choices[k].at, choices[k].at + 6], [0, 1], clamp) : 1;
  const top = base === "studio-style" ? 1370 : 1460;
  return (
    <div style={{ position: "absolute", width: CW, height: CH, overflow: "hidden" }}>
      <Full src={base} />
      {/* the preview: the macros example of the capture is covered, the ad's widget takes its place */}
      <div style={{ position: "absolute", left: 110, top: 432, width: 986, height: 478, borderRadius: 60, background: "rgb(218,226,233)" }} />
      {k > 0 && <Img src={cap(choices[k - 1].w)} style={{ position: "absolute", left: 128, top: 448, width: 952, height: 444 }} />}
      <Img src={cap(choices[k].w)} style={{ position: "absolute", left: 128, top: 448, width: 952, height: 444, opacity: swap, filter: "drop-shadow(0 12px 24px rgba(0,0,0,0.12))" }} />
      {/* the choices, with the same widget */}
      <div style={{ position: "absolute", left: 0, top, width: CW, height: 2300 - top, background: "rgb(233,239,245)" }} />
      {choices.map((s, i) => {
        const p = tileXY(i, top);
        return <Tile key={s.w} w={s.w} name={s.name} tag={s.tag} x={p.x} y={p.y} on={i === k} />;
      })}
      {choices.slice(1).map((s, j) => {
        const p = tileXY(j + 1, top);
        return <Tap key={s.w} f={f} at={s.at - 2} x={p.x + 250} y={p.y + 117} />;
      })}
      <Tap f={f} at={saveAt} x={603} y={2393} />
    </div>
  );
};
