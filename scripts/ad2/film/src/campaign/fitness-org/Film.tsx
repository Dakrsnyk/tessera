import { AbsoluteFill, Freeze, Img, interpolate, OffthreadVideo, staticFile, useCurrentFrame } from "remotion";
import { Grain } from "../../components/Grain";
import { clamp, INTER } from "../../lib/brand";
import { setKitLang } from "../../lib/kit";
import { LangContext } from "../../lib/i18n";
import { TimeRemap } from "../../lib/time";
import { HomeBuilder } from "../../v5/part2/Home";
import type { Config } from "../../v5/part2/configs";
import { FadeIn, OptionalAudio } from "../../pub26/parts";
import { Close } from "../../scenes/Close";
import { Seq, Word } from "../lib";

/**
 * Campaign 2026-11, « fitness » ORGANIC v4 (2026-11-19: gym shot + hook, then an iPhone comes up with the whole Lock Screen; the exercise sheet with the bench press demo opens from the workout list; music fade before the end card; v3 in FilmV3.tsx.txt). v3: v2 opened by the Lock Screen with the workout Live Activity and the hook, then the Home, then the widget 1.25x as big as the frame allows; v2 kept in FilmV2.tsx.txt).
 * v2 (2026-11-19, after the user's review of v1: keep the art direction and the hook, show more
 * of the mini-app, whole screens ~2 s each, the customisation, 30 s at most). v1 is kept in FilmV1.tsx.txt (rendered as
 * ardane-fitness-organique-v1-1080x1920.mp4). 27.5 s, no voice, music only (phonk 620567, drop at 2.0 s), hard cuts on the 120 BPM
 * grid (30 frames a beat). Hook (b3, then the still Home) -> the Carbon widget in close-up, ring on « Set done » -> the whole workout
 * screen before / after (the 4th set) -> the program -> the workout list -> gym shot « Make it yours. » -> Create -> widget picker ->
 * Studio Style (Luxury, cut to Neon) -> five styles of the widget, hard cuts -> the Carbon Home Screen with real Apple apps -> gym
 * shot -> short end card « Available on the App Store ». Parts copied from ../../irl/IrlFitness.tsx, nothing shared is modified.
 * Safe zone (TikTok / Reels): texts in x 60..940, y 220..1540.
 */
export const FPS = 60;
const f = (s: number) => Math.round(s * FPS);
const T = {
  hook: [0, 75], // v4.2: the montage follows the music, played whole from 0.2 s: its drop (first kick) at 1.25 s = the iPhone; beats at 1.25 + 0.5 k
  lock: [75, f(4.75) - 75], // 3.5 s: arrive, « Set done » touched at 1.75 s, the rest timer from 2.25 s (2:00, 1:59, 1:58)
  home: [f(4.75), f(1)],
  widget: [f(5.75), f(3)], // the caption changes 1 s in
  before: [f(8.75), f(0.5)],
  after: [f(9.25), f(2)],
  program: [f(11.25), f(1.5)],
  list: [f(12.75), f(3)], // the exercise sheet of Bench press opens 1 s in (ListToDemo)
  yours: [f(15.75), f(1)],
  create: [f(16.75), f(1)],
  picker: [f(17.75), f(1.5)],
  studio: [f(19.25), f(2)], // Luxury, cut to Neon 1 s in
  styles: [f(21.25), f(2.5)],
  homeEnd: [f(23.75), f(3)], // v4.2: 3.0 s (3.5 before) to pay for the longer Lock Screen
  gym: [f(26.75), f(1.5)], // the music fades out from the bar line at 27.25 s to the beat at 28.25 s, the Ardane signature on top (27.75 and 28.25 s)
  end: [f(28.25), 90],
} as const;
export const ORG_FITNESS_LENGTH = T.end[0] + T.end[1]; // 1785 = 29.75 s (v1 12.5 s, v2 27.5 s, v3 28.5 s, v4 and v4.1 29.5 s)
const RED = "#E5383B";
const clip = (n: string) => staticFile(`irl/fitness/${n}.mp4`);
const kit = (n: string) => staticFile(`campaign/kit/${n}.png`);

/** IrlFitness Footage: contrasted black and white, vignette, slow push-in; `bg`: blurred and dimmed behind a screen. */
const Footage: React.FC<{ name: string; dur: number; zoom?: [number, number]; bg?: boolean }> = ({ name, dur, zoom = [1.03, 1.06], bg = false }) => {
  const fr = useCurrentFrame();
  const z = interpolate(fr, [0, dur], zoom);
  return (
    <AbsoluteFill style={{ overflow: "hidden", background: "#000" }}>
      <OffthreadVideo src={clip(name)} muted style={{ width: "100%", height: "100%", objectFit: "cover", transform: `scale(${bg ? 1.15 : z})`, filter: `grayscale(1) contrast(1.28) brightness(${bg ? 0.45 : 0.95})${bg ? " blur(22px)" : ""}` }} />
      <AbsoluteFill style={{ background: "radial-gradient(ellipse 75% 60% at 50% 48%, rgba(0,0,0,0) 40%, rgba(0,0,0,0.65) 100%)" }} />
    </AbsoluteFill>
  );
};

/** Big left-aligned caption, Inter 800, hard in, hard out. Each line: [text, colour]. */
type Line = [string, string];
const Big: React.FC<{ lines: Line[]; top: number; size: number; lh?: number }> = ({ lines, top, size, lh = Math.round(size * 1.08) }) => (
  <div style={{ position: "absolute", left: 60, top, fontFamily: INTER, fontWeight: 800, fontSize: size, lineHeight: `${lh}px`, letterSpacing: "-0.025em", color: "#fff", whiteSpace: "nowrap", textShadow: "0 4px 28px rgba(0,0,0,0.55)" }}>
    {lines.map(([t, c], i) => (
      <div key={i} style={{ color: c }}>
        {t}
      </div>
    ))}
  </div>
);
const w = (t: string): Line => [t, "#fff"];

/** « Some widgets and styles With Premium », small, in the safe zone (Carbon and Records are Premium styles / widgets). */
const Premium: React.FC<{ top: number; left?: number; size?: number }> = ({ top, left = 60, size = 26 }) => (
  <div style={{ position: "absolute", left, top, fontFamily: INTER, fontWeight: 500, fontSize: size, color: "rgba(255,255,255,0.62)", textShadow: "0 2px 10px rgba(0,0,0,0.6)" }}>Some widgets and styles With Premium</div>
);

// ---------------------------------------------------------------- the Fitness Home Screen of IrlFitness v4 (same config)
const k = (n: string) => `kit/${n}`;
const HOME: Config[] = [
  {
    id: "fitness",
    label: "Fitness",
    wall: "irl/fitness/wall-irl-apps.png",
    dark: true,
    icons: "",
    glow: RED,
    slots: [
      { file: k("irl-nextSet-combo-carbon"), rect: [57, 204, 1092, 510] },
      { file: k("irl-personalRecords-s-carbon"), rect: [57, 813, 510, 510] },
      { file: k("irl-weeklyVolume-m-carbon"), rect: [57, 1422, 1092, 510] },
    ],
  } as Config,
];

/** A ring that beats on each `beats` frame (scale 1.08 -> 1, opacity 1 -> 0.55), `fixedFrom`: steady from that frame on. */
const Ring: React.FC<{ x: number; y: number; w: number; h: number; r: number; color: string; beats: number[]; fixedFrom?: number }> = ({ x, y, w: wd, h, r, color, beats, fixedFrom = 1e9 }) => {
  const fr = useCurrentFrame();
  const last = [...beats].reverse().find((b) => fr >= b) ?? 0;
  const p = fr >= fixedFrom ? 1 : interpolate(fr - last, [0, 22], [0, 1], clamp);
  const s = 1.08 - 0.08 * p;
  const o = fr >= fixedFrom ? 1 : 1 - 0.45 * p;
  return <div style={{ position: "absolute", left: x, top: y, width: wd, height: h, borderRadius: r, border: `4px solid ${color}`, boxSizing: "border-box", opacity: o, transform: `scale(${s})`, boxShadow: `0 0 18px ${color === RED ? "rgba(229,56,59,0.45)" : "rgba(255,255,255,0.35)"}` }} />;
};

/** 2.0 s: the combined Carbon widget alone at its export size (1092 -> 1000 px wide: sharp), on the Home wallpaper; one slow push. */
// v3 (user, on his iPhone): the widget and its mention 1.25x bigger, centred on the widget. 1.25 x 1000 = 1250 px is wider than
// the frame and would cut the widget itself, so it gets the most the frame allows (1064 of 1080, the export is 1092: still sharp,
// never enlarged) and the shot is recentred: caption y 400, widget y 800..1297, mention y 1320, the empty red below is gone.
const WG = { left: 8, top: 800, width: 1064 };
const WS = WG.width / 1092;
const WidgetClose: React.FC<{ dur: number }> = ({ dur }) => {
  const fr = useCurrentFrame();
  const z = interpolate(fr, [0, dur], [1, 1.02]);
  // « Set done » in the export: x 166..503, y 378..467; the ring 10 px wider
  const bx = WG.left + 166 * WS - 10;
  const by = WG.top + 378 * WS - 10;
  return (
    <AbsoluteFill style={{ overflow: "hidden", background: "#000" }}>
      <AbsoluteFill style={{ transform: `scale(${z})`, transformOrigin: `540px ${WG.top + (510 * WS) / 2}px` }}>
        <Img src={staticFile("irl/fitness/wall-irl-apps.png")} style={{ position: "absolute", width: "100%", height: "100%", objectFit: "cover", transform: "scale(1.25)" }} />
        <Img src={kit("irl-nextSet-combo-carbon")} style={{ position: "absolute", left: WG.left, top: WG.top, width: WG.width, height: 510 * WS, filter: "drop-shadow(0 30px 60px rgba(0,0,0,0.6))" }} />
        <Ring x={bx} y={by} w={337 * WS + 20} h={89 * WS + 20} r={46} color="#fff" beats={[0, 30, 60, 90, 120, 150]} />
      </AbsoluteFill>
    </AbsoluteFill>
  );
};


/** A whole real capture as a bare screen (rounded corners, shadow, no drawn case), 600 px wide, its top at y 370 (under a one-line
 * caption and the Premium line), a slow push from its top. Hard cut in and out. Wider, the 4th set of the workout (capture y ~2200)
 * would fall into the bottom 380 px hidden by the TikTok caption. */
const STOP = 370;
const Screen: React.FC<{ dur: number; children: React.ReactNode; SW?: number }> = ({ dur, children, SW = 600 }) => {
  const fr = useCurrentFrame();
  const SC = SW / 1206;
  const z = interpolate(fr, [0, dur], [1, 1.02]);
  return (
    <div style={{ position: "absolute", left: (1080 - SW) / 2, top: STOP, width: SW, height: 2622 * SC, borderRadius: 165 * SC, overflow: "hidden", transform: `scale(${z})`, transformOrigin: "50% 0", boxShadow: "0 50px 140px rgba(0,0,0,0.7), 0 0 0 2px rgba(255,255,255,0.10)", background: "#000" }}>
      <div style={{ position: "absolute", left: 0, top: 0, width: 1206, height: 2622, transform: `scale(${SC})`, transformOrigin: "0 0" }}>{children}</div>
    </div>
  );
};
const Cap: React.FC<{ name: string }> = ({ name }) => <Img src={kit(name)} style={{ position: "absolute", left: 0, top: 0, width: 1206, height: 2622 }} />;
/** A screen shot: gym background (blurred bg-hook), the screen (a capture, or `children` drawn in capture px). */
// `width`: 600 for the workout before / after (its 4th set must stay above the hidden bottom), 700 for the others (seen on the v2 key
// frames: 600 was small to read; 700 ends at y 1892, the bottom of the screen in the hidden zone but inside the frame).
const ScreenShot: React.FC<{ capture?: string; dur: number; children?: React.ReactNode; width?: number }> = ({ capture, dur, children, width = 700 }) => (
  <AbsoluteFill>
    <Footage name="bg-hook" dur={dur} bg />
    <Screen dur={dur} SW={width}>
      {capture && <Cap name={capture} />}
      {children}
    </Screen>
  </AbsoluteFill>
);
/** One-line caption over a screen; `red`: the coloured end. */
const Head: React.FC<{ white: string; red?: string; size?: number }> = ({ white, red, size = 84 }) => (
  <div style={{ position: "absolute", left: 60, top: 230, fontFamily: INTER, fontWeight: 800, fontSize: size, lineHeight: 1, letterSpacing: "-0.025em", color: "#fff", whiteSpace: "nowrap", textShadow: "0 4px 28px rgba(0,0,0,0.55)" }}>
    {white}
    {red && <span style={{ color: RED }}>{red}</span>}
  </div>
);

/** IrlFitness StudioStyle: the Studio on its Style part with the combined widget laid over the capture's preview (measured: x 126..1080,
 * y 450..896 of the capture); the kit cannot open the Studio on a combined widget, the app's code is not changed for the ads. */
const StudioStyle: React.FC<{ capture: string; widget: string }> = ({ capture, widget }) => (
  <>
    <Cap name={capture} />
    <div style={{ position: "absolute", left: 110, top: 434, width: 986, height: 478, background: "rgb(18,31,43)" }} />
    <Img src={kit(widget)} style={{ position: "absolute", left: 126, top: 450, width: 954, height: 446 }} />
  </>
);

/** The five real styles of the combined widget, one per beat, HARD cuts (no widget dissolves into another), the last one Carbon. */
const STYLES = ["light", "luxury", "mars", "neon", "carbon"].map((s) => `irl-nextSet-combo-${s}`);
const StyleCuts: React.FC = () => {
  const fr = useCurrentFrame();
  const n = STYLES[Math.min(STYLES.length - 1, Math.floor(fr / 30))];
  return <Img src={kit(n)} style={{ position: "absolute", left: 70, top: 960 - 220, width: 940, height: (940 * 510) / 1092, filter: "drop-shadow(0 40px 80px rgba(0,0,0,0.6))" }} />;
};

/** v4: the workout Live Activity of the Lock Screen, ISOLATED so the capture can be swapped in one line. Today: live-ready-real
 * (kit run of 2026-10-31, Saphir, « Upper body · Bench press · Set 3/4 · 8 × 60 kg », Ready, back / Skip / Set done; its « Rest day »
 * above « Ready » is the app's text bug « Repos »). Waiting for a Rubis (red) export of the same state: when it comes, change LIVE_SRC
 * and set LIVE_PREMIUM to true (Rubis is a Premium app colour: the Lock Screen shot then carries the Premium line). */
// 2026-11-19: the Rubis export arrived (run 481, « Rest » instead of « Rest day », the text is fixed in the app)
const LIVE_SRC = "campaign/kit/live-ready-ruby.png";
const LIVE_PREMIUM = true;
/** Where iOS lays a Live Activity on the Lock Screen, capture px (as v5/lib/LockLive: SLOT of the real lock captures). */
const SLOT = { x: 45, y: 1790, w: 1116, h: 465 };
/** v4.2: the touch on « Set done » at TAP_AT, then a hard cut on the next beat (REST_AT) to the real after-set state in Rubis
 * (live-afterset-ruby-000..004: « Set 4/4 · 8 × 60 kg », rest 2:00, 1:59, 1:58… one image a second, here on the film's real time). */
const TAP_AT = 75; // v4.3: 2.5 s (two equal halves of 1.75 s: Ready 1.25..3.0, rest timer 3.0..4.75)
const REST_AT = 105; // v4.3: 3.0 s
const LIVE_AFTER = (i: number) => `campaign/kit/live-afterset-ruby-${String(i).padStart(3, "0")}.png`;
const LockActivity: React.FC = () => {
  const fr = useCurrentFrame();
  const src = fr < REST_AT ? LIVE_SRC : LIVE_AFTER(Math.min(4, Math.floor((fr - REST_AT) / FPS)));
  return <Img src={staticFile(src)} style={{ position: "absolute", left: SLOT.x, top: SLOT.y, width: SLOT.w, height: SLOT.h }} />;
};
/** The touch indicator (no hand): a white disc lands on « Set done » (centre measured on the Live Activity: x 905, y 360 of 1116 x 465),
 * small bounce, then a ripple; gone at the cut. */
const Touch: React.FC = () => {
  const fr = useCurrentFrame();
  if (fr < TAP_AT - 8 || fr >= REST_AT) return null;
  const k = fr - (TAP_AT - 8);
  const s = interpolate(k, [0, 8, 13, 18], [1.5, 0.86, 1.04, 1], clamp);
  const o = interpolate(k, [0, 6], [0, 1], clamp);
  const r = interpolate(fr, [TAP_AT, TAP_AT + 22], [0, 1], clamp);
  const cx = SLOT.x + 905;
  const cy = SLOT.y + 360;
  return (
    <>
      {fr >= TAP_AT && <div style={{ position: "absolute", left: cx - 70, top: cy - 70, width: 140, height: 140, borderRadius: 70, border: "6px solid rgba(255,255,255,0.9)", boxSizing: "border-box", opacity: 1 - r, transform: `scale(${1 + 1.4 * r})` }} />}
      <div style={{ position: "absolute", left: cx - 56, top: cy - 56, width: 112, height: 112, borderRadius: 56, background: "rgba(255,255,255,0.55)", border: "4px solid rgba(255,255,255,0.95)", boxSizing: "border-box", boxShadow: "0 6px 24px rgba(0,0,0,0.35)", opacity: o, transform: `scale(${s})` }} />
    </>
  );
};
/** v4.2: the Lock Screen widgets row under the time (real exports of the app, monochrome, not recoloured), laid as the real lock
 * capture lock-minuit shows it (measured: row y 677..893, circular 216 px). Planning (rectangular, « Friday ») on the left, calories
 * (circular); the second circular slot stays empty. The exports are drawn at 4x (circular 288, rectangular 688 x 304): shown at 0.75. */
const LOCK_W = [
  { file: "camp-lock-timetable-rect", x: 99, w: 516, h: 228 },
  { file: "camp-lock-caloriesLeft-circular", x: 645, w: 216, h: 216 },
  // trainingStreak (« 4/3 ») would contradict the widget's 3/3, nextSet-rect (Squat) and upNext-rect (10:41) the rest: left out
];
const LockWidgets: React.FC = () => (
  <>
    {LOCK_W.map((g) => (
      <Img key={g.file} src={staticFile(`campaign/kit/${g.file}.png`)} style={{ position: "absolute", left: g.x, top: 785 - g.h / 2, width: g.w, height: g.h }} />
    ))}
  </>
);

/** A whole iPhone Lock Screen in capture px (1206 x 2622): the red and black wallpaper of the Home (wall-irl-apps), the date and the
 * time at 9:41 drawn like the Lock Screen of the app's own previews (MarketingLockScreen: date semibold, big bold time), the
 * Live Activity in its slot, the flashlight and camera buttons, the home indicator. The real lock captures of the kit could not
 * serve: they are of 2026-10-31 (date « Saturday, October 31 ») with other wallpapers and Lock Screen widgets. */
const LockScreenPage: React.FC = () => (
  <>
    <Img src={staticFile("irl/fitness/wall-irl-apps.png")} style={{ position: "absolute", left: 0, top: 0, width: 1206, height: 2622 }} />
    <div style={{ position: "absolute", left: 0, top: 0, width: 1206, height: 1300, background: "linear-gradient(180deg, rgba(0,0,0,0.3), rgba(0,0,0,0))" }} />
    <div style={{ position: "absolute", left: 415, top: 43, width: 375, height: 108, borderRadius: 54, background: "#000" }} />
    <div style={{ position: "absolute", left: 0, right: 0, top: 236, textAlign: "center", fontFamily: INTER, fontWeight: 600, fontSize: 63, color: "rgba(255,255,255,0.92)" }}>Friday, November 20</div>
    <div style={{ position: "absolute", left: 0, right: 0, top: 300, textAlign: "center", fontFamily: INTER, fontWeight: 700, fontSize: 348, lineHeight: 1, letterSpacing: "-0.035em", color: "rgba(255,255,255,0.96)" }}>9:41</div>
    <LockWidgets />
    <LockActivity />
    <Touch />
    {[
      [132, "M"],
      [924, "C"],
    ].map(([x, k]) => (
      <div key={k as string} style={{ position: "absolute", left: x as number, top: 2346, width: 150, height: 150, borderRadius: 75, background: "rgba(255,255,255,0.16)" }} />
    ))}
    <div style={{ position: "absolute", left: 159, top: 2373, width: 96, height: 96, display: "flex", alignItems: "center", justifyContent: "center" }}>
      <svg width="40" height="66" viewBox="0 0 20 33"><path d="M3 1h14v6l-3 5v19a2 2 0 0 1-2 2H8a2 2 0 0 1-2-2V12L3 7z" fill="#fff" /></svg>
    </div>
    <div style={{ position: "absolute", left: 951, top: 2373, width: 96, height: 96, display: "flex", alignItems: "center", justifyContent: "center" }}>
      <svg width="64" height="50" viewBox="0 0 32 25"><path d="M11 1h10l2 4h6a3 3 0 0 1 3 3v14a3 3 0 0 1-3 3H3a3 3 0 0 1-3-3V8a3 3 0 0 1 3-3h6z" fill="#fff" /><circle cx="16" cy="14" r="6" fill="#555" /></svg>
    </div>
    <div style={{ position: "absolute", left: 381, top: 2562, width: 444, height: 15, borderRadius: 8, background: "rgba(255,255,255,0.92)" }} />
  </>
);

/** 2.0 s: an iPhone (the bare rounded screen of the other shots, 600 px wide, top y 370) comes up from the bottom of the frame and
 * settles with a damped spring (one small overshoot, no zoom), on the blurred gym shot. 600 px: the Live Activity (capture y 1790..2255)
 * then lies at y 1261..1492, above the bottom 380 px hidden by TikTok. */
const PhoneArrive: React.FC<{ dur: number; children: React.ReactNode }> = ({ dur, children }) => {
  const fr = useCurrentFrame();
  // damped spring: x(t) = 1 - e^(-t/τ) cos(ωt), τ 0.16 s, ω 2π / 0.8 s: ~6 % overshoot, settled by ~0.8 s (seen on the key frames: τ 0.11 was up in 0.1 s)
  const t = fr / FPS;
  const p = 1 - Math.exp(-t / 0.12) * Math.cos((2 * Math.PI * t) / 0.7); // v4.2: settled by 0.5 s, before the touch
  const y = (1 - p) * 1700;
  const sw = 600;
  const sc = sw / 1206;
  return (
    <AbsoluteFill>
      <Footage name="bg-hook" dur={dur} bg />
      <div style={{ position: "absolute", left: (1080 - sw) / 2, top: STOP, width: sw, height: 2622 * sc, borderRadius: 165 * sc, overflow: "hidden", transform: `translateY(${y}px)`, boxShadow: "0 50px 140px rgba(0,0,0,0.7), 0 0 0 2px rgba(255,255,255,0.10)", background: "#000" }}>
        <div style={{ position: "absolute", left: 0, top: 0, width: 1206, height: 2622, transform: `scale(${sc})`, transformOrigin: "0 0" }}>{children}</div>
      </div>
    </AbsoluteFill>
  );
};

/** 12.0 s: « Your whole workout. » then, on the same screen, the exercise sheet of Bench press opens, as the app does it.
 * App code (2026-11-19): in the workout (App/Screens/MiniApps/Fitness/FitnessSession.swift, ligne 39 et 108-121) the ⓘ of an exercise
 * sets `info`, which presents `.sheet(item: $info) { ExerciseInfoSheet(exercise:) }`; ExerciseInfoSheet (ExerciseLibraryViews.swift,
 * ligne 286-299) is a NavigationStack with `.presentationDetents([.large])` and a « Close » button. So: the iOS system sheet, no custom
 * animation in the app. The system's values are not in the code; drawn here as iOS 17/18 shows a large sheet: the sheet slides up
 * from the bottom edge (~0.5 s, damped spring without overshoot), the screen under it recedes (scale ~0.92 from the top, rounded,
 * dimmed), the sheet's top edge stops under the status bar. The ring marks the ⓘ of Bench press (capture x 1075, y 1230, measured)
 * just before; no finger.
 * Sheet content: ex-0-dark (campaign kit of 2026-11-19, the real exercise page « Bench press (barbell) »), its demo animated with the
 * real demo-bench-press-dark sequence (kit run of 2026-10-31, 240 images at 60 fps) in its box (x 60..1148, y 367..1074), as
 * src/v4/MiniApp.tsx. CAUTION: ex-0-dark is the page pushed from the library (back arrow, star, tab bar), not the sheet over the
 * workout (« Close »), and it shows « Poussée » untranslated under the demo. */
const OPEN_AT = 60; // the sheet starts on the beat, 1.0 s in
const SHEET_TOP = 180; // capture px: under the status bar
const ListToDemo: React.FC<{ dur: number }> = ({ dur }) => {
  const fr = useCurrentFrame();
  const t = Math.max(0, (fr - OPEN_AT) / FPS);
  const p = fr < OPEN_AT ? 0 : 1 - Math.exp(-t / 0.085) * (1 + t / 0.085); // critically damped, ~0.5 s
  const demoFrame = Math.max(0, fr - OPEN_AT) % 240;
  return (
    <ScreenShot dur={dur} width={700}>
      {/* the workout recedes */}
      <div style={{ position: "absolute", inset: 0, transform: `translateY(${p * 60}px) scale(${1 - 0.08 * p})`, transformOrigin: "50% 0", borderRadius: 60 * p, overflow: "hidden" }}>
        <Cap name="session-list-dark" />
        <div style={{ position: "absolute", inset: 0, background: `rgba(0,0,0,${0.35 * p})` }} />
      </div>
      {fr < OPEN_AT + 6 && (
        <div style={{ position: "absolute", left: 1075 - 48, top: 1230 - 48, width: 96, height: 96, borderRadius: 48, border: "6px solid #fff", boxSizing: "border-box", boxShadow: "0 0 24px rgba(255,255,255,0.45)", opacity: fr < OPEN_AT ? 1 - 0.45 * interpolate(fr % 30, [0, 22], [0, 1], clamp) : 1 - (fr - OPEN_AT) / 6, transform: `scale(${1.1 - 0.1 * interpolate(fr % 30, [0, 22], [0, 1], clamp)})` }} />
      )}
      {p > 0 && (
        <div style={{ position: "absolute", left: 0, top: SHEET_TOP + (1 - p) * (2622 - SHEET_TOP), width: 1206, height: 2622 - SHEET_TOP, borderRadius: "60px 60px 0 0", overflow: "hidden", boxShadow: "0 -20px 60px rgba(0,0,0,0.5)" }}>
          {/* the page under its own status bar (y 0..150 of the capture) */}
          <div style={{ position: "absolute", left: 0, top: -150, width: 1206, height: 2622 }}>
            <Cap name="ex-0-dark" />
            {/* « Poussée » (French, untranslated in the English capture) under the demo, covered with its flat background
                rgb(8,14,20) (measured around it, x 500..710, y 1132..1185), as the main film v4 covers that line */}
            <div style={{ position: "absolute", left: 500, top: 1132, width: 210, height: 53, background: "rgb(8,14,20)" }} />
            <div style={{ position: "absolute", left: 60, top: 367, width: 1088, height: 707, borderRadius: 66, background: "#1A1B1E", overflow: "hidden" }}>
              <Img src={staticFile(`kit2026/en/demo-bench-press-dark-${String(demoFrame).padStart(4, "0")}.png`)} style={{ position: "absolute", left: 0, top: "50%", width: "100%", transform: "translateY(-50%)" }} />
            </div>
          </div>
        </div>
      )}
    </ScreenShot>
  );
};

export const OrgFitness: React.FC<{ silent?: boolean }> = ({ silent = false }) => {
  setKitLang("en");
  const fr = useCurrentFrame();
  return (
    <LangContext.Provider value="en">
      <AbsoluteFill style={{ background: "#000", fontFamily: INTER }}>
        {/* 0.0 s the hook on a real gym shot (b3, no face, as v1); the top gradient covers the neon tube under the text */}
        <Seq t={T.hook}>
          <Footage name="b3" dur={T.hook[1]} zoom={[1.03, 1.08]} />
          <AbsoluteFill style={{ background: "linear-gradient(180deg, rgba(0,0,0,0.75) 0px, rgba(0,0,0,0) 700px)" }} />
          <Big lines={[w("Still opening"), w("an app after"), ["every set?", RED]]} top={230} size={96} lh={104} />
        </Seq>

        {/* 2.0 s on the drop: the iPhone comes up with the whole Lock Screen and the workout Live Activity */}
        <Seq t={T.lock}>
          <PhoneArrive dur={T.lock[1]}>
            <LockScreenPage />
          </PhoneArrive>
          {/* the caption lands on the next beat, once the phone has settled (seen on the key frames: its overshoot reached the caption) */}
          {fr >= T.lock[0] + TAP_AT && (fr < T.lock[0] + REST_AT ? <Head white="Tap " red="Set done." /> : <Head white="Rest timer " red="starts." />)}
          {LIVE_PREMIUM && fr >= T.lock[0] + TAP_AT && <Premium top={326} />}
        </Seq>

        {/* 2.0 s on the drop: the Fitness Home Screen of IrlFitness v4, still, bigger (0.72 instead of 0.62): its top at y 604 */}
        <Seq t={T.home}>
          <AbsoluteFill style={{ background: "#000" }}>
            <AbsoluteFill style={{ transform: "translateY(430px) scale(1.161)", transformOrigin: "50% 0" }}>
              <Freeze frame={60}>
                <HomeBuilder configs={HOME} morphAt={[]} morphLen={[]} installAt={6} swallow={[99998, 99999]} bare install={false} />
              </Freeze>
            </AbsoluteFill>
          </AbsoluteFill>
          <Premium top={552} />
        </Seq>

        {/* 2.0 s on the drop: the widget in close-up, the ring beats on « Set done »; 3.0 s the caption changes */}
        <Seq t={T.widget}>
          <WidgetClose dur={T.widget[1]} />
          {fr < T.widget[0] + f(1) ? <Big lines={[w("Set finished?")]} top={400} size={104} /> : <Big lines={[["One tap.", RED], w("No app to open.")]} top={400} size={104} lh={112} />}
          <Premium top={1320} left={40} size={32} />
        </Seq>

        {/* 5.0 s the whole workout screen, before (3 sets of 4) then 5.5 s after (the 4th set, Bench press ticked), same framing */}
        <Seq t={T.before}>
          <ScreenShot capture="session-1-dark" dur={T.before[1]} width={600} />
        </Seq>
        <Seq t={T.after}>
          {/* the 4th « 60 × 8 » pill of session-2: x 678..852, y 2162..2234 of the capture, measured; the ring 10 px wider */}
          <ScreenShot capture="session-2-dark" dur={T.after[1]} width={600}>
            <Ring x={668} y={2152} w={194} h={92} r={46} color={RED} beats={[0, 30]} fixedFrom={60} />
          </ScreenShot>
          <Head white="Set " red="logged." />
        </Seq>

        {/* 8.0 s the program, 10.0 s the workout list */}
        <Seq t={T.program}>
          <ScreenShot capture="pub26-fitness-dark" dur={T.program[1]} />
          <Head white="Your " red="program." />
        </Seq>
        <Seq t={T.list}>
          <ListToDemo dur={T.list[1]} />
          {fr < T.list[0] + OPEN_AT ? <Head white="Your whole " red="workout." /> : <Head white="Every move, " red="shown." />}
          {fr >= T.list[0] + OPEN_AT && <Premium top={326} />}
        </Seq>

        {/* 12.0 s gym shot (b6, face hidden): the customisation part */}
        <Seq t={T.yours}>
          <Footage name="b6" dur={T.yours[1]} />
          <AbsoluteFill style={{ background: "linear-gradient(180deg, rgba(0,0,0,0.7) 0px, rgba(0,0,0,0) 640px)" }} />
          <Big lines={[w("Make it"), ["yours.", RED]]} top={230} size={104} lh={112} />
        </Seq>
        <Seq t={T.create}>
          <ScreenShot capture="pub26-create-dark" dur={T.create[1]} />
          <Head white="Create a " red="widget." />
        </Seq>
        <Seq t={T.picker}>
          <ScreenShot capture="creator-fitness-medium" dur={T.picker[1]} />
          <Head white="Pick what it " red="shows." />
        </Seq>
        <Seq t={T.studio}>
          <ScreenShot dur={T.studio[1]}>
            {fr < T.studio[0] + f(1) ? <StudioStyle capture="studio-style-luxury-dark" widget="irl-nextSet-combo-luxury" /> : <StudioStyle capture="studio-style-neon-dark" widget="irl-nextSet-combo-neon" />}
          </ScreenShot>
          <Head white="Pick a " red="style." />
          <Premium top={326} />
        </Seq>
        <Seq t={T.styles}>
          <Img src={staticFile("irl/fitness/wall-irl-apps.png")} style={{ position: "absolute", width: "100%", height: "100%", objectFit: "cover", transform: "scale(1.25)" }} />
          <StyleCuts />
          <Head white="Your " red="colors." />
          <Premium top={1200} left={70} />
        </Seq>

        {/* 20.5 s the Carbon Home Screen with real Apple apps (IrlFitness v4: opens out of the line, the widgets land) */}
        <Seq t={T.homeEnd}>
          <AbsoluteFill style={{ background: "#000" }}>
            <AbsoluteFill style={{ transform: "translateY(245px) scale(0.9)", transformOrigin: "50% 0" }}>
              <HomeBuilder configs={HOME} morphAt={[]} morphLen={[]} installAt={6} swallow={[99998, 99999]} bare lineOpen />
            </AbsoluteFill>
          </AbsoluteFill>
          <Head white="On your " red="Home Screen." size={76} />
          <Premium top={326} />
        </Seq>

        {/* 24.5 s gym shot (b9, a silhouette, no readable face) */}
        <Seq t={T.gym}>
          <Footage name="b9" dur={T.gym[1]} />
          <Word text="every set." until={T.gym[1]} size={52} />
        </Seq>

        {/* 26.0 s short end card: the validated Close on its settled state, « Available on the App Store » (user, 2026-11-19: the ads go out once the app is out), no tagline */}
        <Seq t={T.end}>
          <FadeIn n={8}>
            <TimeRemap input={[0, T.end[1]]} output={[196, 216]}>
              <Close audio={false} tagline="" cta="AVAILABLE ON THE APP STORE" ctaScale={1.15} tile />
            </TimeRemap>
          </FadeIn>
        </Seq>
        <Grain amount={0.02} />
        <OptionalAudio file="campaign/fitness-org/mix.wav" silent={silent} />
      </AbsoluteFill>
    </LangContext.Provider>
  );
};
