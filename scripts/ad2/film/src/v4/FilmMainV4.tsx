import { Audio } from "@remotion/media";
import { useEffect, useRef, useState } from "react";
import { AbsoluteFill, continueRender, delayRender, Easing, getStaticFiles, interpolate, Sequence, staticFile, useCurrentFrame } from "remotion";
import { LOGO_GAP } from "../components/ArdaneLogo";
import { Grain } from "../components/Grain";
import { Seam } from "../components/Seam";
import { FormatFrame } from "../films/FormatFrame";
import { FormatProps } from "../films/Formatted";
import { AXIS, C, clamp, INTER, W } from "../lib/brand";
import { useT } from "../lib/i18n";
import { TimeRemap } from "../lib/time";
import { Close, LOGO } from "../scenes/Close";
import { Opening } from "../scenes/Opening";
import { KineticLine } from "../v3/fx";
import { Hook4 } from "./Hook4";
import { HomeFlat, Homes, HOME_LAST } from "./Homes";
import { AppDef, MiniApp } from "./MiniApp";
import { Process } from "./Process";
import T from "./timing.json";

export const V4_LENGTH = T.length;
const AUDIO = "audio/en/mix-v4main.wav";

const wid = (src: string, w: number, top: number) => ({ src: `kit/${src}.png`, w, top });

const NUTRITION: AppDef = {
  title: "v3.nutrition",
  subs: [{ at: 10, key: "v4.sub.nutrition1" }, { at: 160, key: "v4.sub.nutrition2" }],
  accent: "#FF9500",
  length: 330,
  drift: [-46, 34],
  screens: [
    { at: 0, src: "kit/scan-frame-dark.png", scan: { enter: 40, read: 74 } },
    { at: 126, src: "kit/nut-2-dark.png", dip: true, cover: [[1000, 1052, 170, 66, "rgb(19,30,40)"]] },
    { at: 196, src: "kit/nut-3-dark.png" },
  ],
  cam: [
    { at: 0, cx: 603, cy: 1311, z: 1 }, { at: 36, cx: 603, cy: 1311, z: 1 }, { at: 80, cx: 603, cy: 1252, z: 1.2 }, { at: 112, cx: 603, cy: 1252, z: 1.2 }, { at: 128, cx: 603, cy: 1311, z: 1 },
    { at: 144, cx: 603, cy: 1311, z: 1 }, { at: 168, cx: 603, cy: 1850, z: 1.2 }, { at: 188, cx: 603, cy: 1850, z: 1.2 }, { at: 198, cx: 603, cy: 1311, z: 1 },
    { at: 212, cx: 603, cy: 1311, z: 1 }, { at: 222, cx: 230, cy: 880, z: 1.2 }, { at: 232, cx: 230, cy: 880, z: 1.2 }, { at: 244, cx: 603, cy: 1311, z: 1 },
  ],
  hi: [
    { from: 44, to: 118, rect: [235, 885, 735, 735], label: "Scan" },
    { from: 150, to: 192, rect: [40, 1545, 1126, 625], label: "Calories and macros" },
    { from: 210, to: 236, rect: [50, 710, 360, 350], label: "Calories left" },
  ],
  widgets: { at: 238, items: [wid("calories-s-dark", 560, 470), wid("macros-m-dark", 900, 1090)] },
};
const FITNESS: AppDef = {
  title: "v3.fitness",
  subs: [{ at: 10, key: "v4.sub.fitness1" }, { at: 250, key: "v4.sub.fitness2" }],
  accent: "#FF5D5D",
  length: 450,
  drift: [40, -40],
  screens: [
    { at: 0, src: "kit/lib-0-dark.png" },
    { at: 100, src: "kit/ex-0-dark.png", demo: { name: "demo-bench-press-dark", count: 240, box: [60, 367, 1088, 707], fill: "#1A1B1E", from: 126 }, cover: [[30, 1128, 1146, 165, "#0B1118"]] },
    { at: 240, src: "kit/session-0-dark.png" },
    { at: 336, src: "kit/app-fitness-progress-dark.png", cover: [[236, 1590, 600, 44, "rgb(19,30,40)"], [236, 1899, 600, 44, "rgb(19,30,40)"], [236, 2068, 600, 44, "rgb(19,30,40)"], [40, 2262, 1126, 130, "rgb(10,14,18)"]] },
  ],
  cam: [
    { at: 0, cx: 603, cy: 1311, z: 1 }, { at: 30, cx: 603, cy: 1311, z: 1 }, { at: 62, cx: 603, cy: 760, z: 1.2 }, { at: 88, cx: 603, cy: 760, z: 1.2 }, { at: 104, cx: 603, cy: 1311, z: 1 },
    { at: 116, cx: 603, cy: 1311, z: 1 }, { at: 150, cx: 603, cy: 720, z: 1.2 }, { at: 228, cx: 603, cy: 720, z: 1.2 }, { at: 244, cx: 603, cy: 1311, z: 1 },
    { at: 256, cx: 603, cy: 1311, z: 1 }, { at: 284, cx: 603, cy: 1850, z: 1.2 }, { at: 326, cx: 603, cy: 1850, z: 1.2 }, { at: 340, cx: 603, cy: 1311, z: 1 },
    { at: 352, cx: 603, cy: 1311, z: 1 }, { at: 380, cx: 603, cy: 925, z: 1.2 }, { at: 416, cx: 603, cy: 925, z: 1.2 }, { at: 440, cx: 603, cy: 1311, z: 1 },
  ],
  hi: [
    { from: 34, to: 94, rect: [47, 348, 1112, 132], label: "Find any exercise" },
    { from: 130, to: 232, rect: [60, 367, 1088, 707], label: "Every move, animated" },
    { from: 262, to: 296, rect: [109, 1377, 987, 150], label: "Set done" },
    { from: 298, to: 332, rect: [100, 2130, 600, 115], label: "Sets counted" },
    { from: 360, to: 420, rect: [80, 620, 1070, 610], label: "Your progress" },
  ],
};
const HABITS: AppDef = {
  title: "v3.habits",
  subs: [{ at: 10, key: "v4.sub.habits1" }, { at: 130, key: "v4.sub.habits2" }],
  accent: "#8E7CFF",
  length: 270,
  drift: [34, -34],
  screens: [
    { at: 0, src: "kit/hab-0-dark.png" },
    { at: 96, src: "kit/hab-1-dark.png" },
  ],
  cam: [
    { at: 0, cx: 603, cy: 1311, z: 1 }, { at: 22, cx: 603, cy: 1311, z: 1 }, { at: 56, cx: 603, cy: 1380, z: 1.2 }, { at: 150, cx: 603, cy: 1380, z: 1.2 }, { at: 172, cx: 603, cy: 1311, z: 1 },
  ],
  hi: [
    { from: 56, to: 96, rect: [48, 1335, 1110, 130], label: "Check it off" },
    { from: 112, to: 160, rect: [48, 1335, 1110, 130], label: "Streak kept" },
  ],
  widgets: { at: 176, items: [wid("habits-m-dark", 900, 500), wid("habitStreak-s-aurora", 560, 1010)] },
};
const FINANCES: AppDef = {
  title: "v4.finances",
  subs: [{ at: 10, key: "v4.sub.finances1" }, { at: 150, key: "v4.sub.finances2" }],
  accent: "#34C98B",
  length: 300,
  drift: [-36, 36],
  screens: [
    { at: 0, src: "kit/app-finances-s00-dark.png", cover: [[50, 2148, 1106, 204, "linear-gradient(to bottom, rgb(15,18,22), rgb(13,15,18))"]] },
    { at: 86, src: "kit/app-finances-trends.png" },
    { at: 152, src: "kit/app-finances-categories.png" },
  ],
  cam: [
    { at: 0, cx: 603, cy: 1311, z: 1 }, { at: 18, cx: 603, cy: 1311, z: 1 }, { at: 46, cx: 603, cy: 960, z: 1.2 }, { at: 76, cx: 603, cy: 960, z: 1.2 }, { at: 88, cx: 603, cy: 1311, z: 1 },
    { at: 100, cx: 603, cy: 1311, z: 1 }, { at: 120, cx: 603, cy: 930, z: 1.2 }, { at: 144, cx: 603, cy: 930, z: 1.2 }, { at: 154, cx: 603, cy: 1311, z: 1 },
    { at: 166, cx: 603, cy: 1311, z: 1 }, { at: 188, cx: 603, cy: 1060, z: 1.2 }, { at: 210, cx: 603, cy: 1060, z: 1.2 }, { at: 226, cx: 603, cy: 1311, z: 1 },
  ],
  hi: [
    { from: 24, to: 80, rect: [50, 715, 1100, 520], label: "Left this month" },
    { from: 104, to: 148, rect: [58, 600, 1090, 680], label: "Six months at a glance" },
    { from: 170, to: 216, rect: [60, 697, 1086, 754], label: "By category" },
  ],
  widgets: { at: 228, items: [wid("budgetLeft-m-dark", 900, 480), wid("spendingByCategory-m-dark", 900, 1000)] },
};
const PLANNING: AppDef = {
  title: "v4.planning",
  subs: [{ at: 10, key: "v4.sub.planning1" }, { at: 130, key: "v4.sub.planning2" }],
  accent: "#4E9BE0",
  length: 300,
  drift: [36, -36],
  screens: [
    { at: 0, src: "kit/plan-0-dark.png", cover: [[120, 735, 1060, 207, "linear-gradient(to bottom, rgb(21,32,39), rgb(23,29,36))"]] },
    { at: 120, src: "kit/app-planning-month.png" },
  ],
  cam: [
    { at: 0, cx: 603, cy: 1311, z: 1 }, { at: 26, cx: 603, cy: 1311, z: 1 }, { at: 62, cx: 640, cy: 1750, z: 1.2 }, { at: 106, cx: 640, cy: 1750, z: 1.2 }, { at: 122, cx: 603, cy: 1311, z: 1 },
    { at: 132, cx: 603, cy: 1311, z: 1 }, { at: 152, cx: 603, cy: 1000, z: 1.2 }, { at: 176, cx: 603, cy: 1000, z: 1.2 }, { at: 190, cx: 603, cy: 1950, z: 1.2 }, { at: 206, cx: 603, cy: 1950, z: 1.2 }, { at: 220, cx: 603, cy: 1311, z: 1 },
  ],
  hi: [
    { from: 28, to: 60, rect: [94, 480, 1040, 190], label: "This week" },
    { from: 70, to: 112, rect: [150, 1530, 700, 380], label: "Events" },
    { from: 136, to: 178, rect: [62, 565, 1082, 900], label: "Month at a glance" },
    { from: 184, to: 214, rect: [60, 1630, 1086, 740], label: "Tasks and events" },
  ],
  widgets: { at: 224, items: [wid("weekView-m-dark", 900, 480), wid("timetable-m-light", 900, 1000)] },
};

type Seg = { from: number; length: number; El: React.FC<any>; props?: Record<string, unknown>; input?: number[]; output?: number[] }; // eslint-disable-line @typescript-eslint/no-explicit-any

/** Opening: the edge-on phone turns frontal; leaves sliding away while Nutrition takes over (30 frames of link). */
const OpeningLeave: React.FC = () => {
  const f = useCurrentFrame();
  const out = interpolate(f, [196, 226], [0, 1], { ...clamp, easing: Easing.bezier(0.6, 0, 0.9, 0.4) });
  return (
    <AbsoluteFill style={{ transform: `translateX(${-out * 170}px)`, opacity: 1 - out, filter: `blur(${out * 10}px)` }}>
      <TimeRemap input={[0, 100, 226]} output={[0, 250, 359]}>
        <Opening audio={false} lit words={false} wake={20} levitate />
      </TimeRemap>
    </AbsoluteFill>
  );
};

const Breathe: React.FC<{ children: React.ReactNode }> = ({ children }) => {
  const f = useCurrentFrame();
  const calm = interpolate(f, [280, 298], [1, 0], clamp);
  const push = 1 + 0.06 * interpolate(f, [46, 298], [0, 1], { ...clamp, easing: Easing.bezier(0.25, 0.1, 0.25, 1) });
  const top = LOGO.cy - LOGO.size / 2 + LOGO_GAP.top * LOGO.size;
  const h = (LOGO_GAP.bottom - LOGO_GAP.top) * LOGO.size;
  const shimmer = (0.18 + 0.16 * Math.sin(f * 0.11) + 0.1 * Math.sin(f * 0.37)) * calm * interpolate(f, [76, 126], [0, 1], clamp);
  const o = `${LOGO.cx}px ${LOGO.cy + 200}px`;
  return (
    <AbsoluteFill>
      <AbsoluteFill style={{ transform: `scale(${push})`, transformOrigin: o }}>{children}</AbsoluteFill>
      <AbsoluteFill style={{ transform: `scale(${push})`, transformOrigin: o }}>
        <Seam x={AXIS} top={top - 10} height={h + 20} intensity={Math.max(0, shimmer)} spread={0.7} />
      </AbsoluteFill>
    </AbsoluteFill>
  );
};

/** The end card continues from the last Home of the Homes sequence: same drawn screen (HomeFlat), same framing (85 mm, 66.5 %). */
const CloseOnHome: React.FC = () => {
  const host = useRef<HTMLDivElement>(null);
  const [ready, setReady] = useState(false);
  const [handle] = useState(() => delayRender("last Home for the end card"));
  useEffect(() => {
    let n = 0;
    const poll = () => {
      const c = host.current?.querySelector("canvas") ?? null;
      let ok = false;
      if (c) {
        try {
          ok = c.getContext("2d")!.getImageData(603, 1311, 1, 1).data[3] > 0;
        } catch {
          ok = false;
        }
      }
      if (ok || n++ > 400) {
        setReady(true);
        continueRender(handle);
      } else setTimeout(poll, 25);
    };
    poll();
  }, [handle]);
  const f = useCurrentFrame();
  // 16 frames of overlap with the end of Homes (its phone fades there): the end card fades in over them, the turn waits.
  const fade = interpolate(f, [0, 16], [0, 1], clamp);
  return (
    <AbsoluteFill>
      <div ref={host} style={{ position: "absolute", left: -4000, top: 0, width: 1206, height: 2622 }}>
        <HomeFlat index={HOME_LAST} />
      </div>
      {ready && (
        <AbsoluteFill style={{ opacity: fade }}>
          <TimeRemap input={[0, 16, 316]} output={[0, 0, 299]}>
            <Breathe>
              <Close audio={false} tagline="Your whole life. One place." screenCanvas={() => host.current?.querySelector("canvas") ?? null} lens={85} fraction0={0.665} fraction1={0.7} />
            </Breathe>
          </TimeRemap>
        </AbsoluteFill>
      )}
    </AbsoluteFill>
  );
};

const CutFx: React.FC = () => {
  const f = useCurrentFrame() - 2;
  const w = interpolate(f, [0, 5], [0.18, 0], clamp);
  return f >= 0 ? <AbsoluteFill style={{ background: "#fff", opacity: w }} /> : null;
};

const Texts: React.FC = () => {
  const f = useCurrentFrame();
  const t = useT();
  const V = T.voice;
  const veil = interpolate(f, [528, 548, 712, 740], [0, 1, 1, 0], clamp);
  const meetOut = interpolate(f, [V.everything - 16, V.everything - 4], [0, 1], clamp);
  const evOut = interpolate(f, [716, 738], [0, 1], clamp);
  const demo = interpolate(f, [540, 560, 3730, 3750], [0, 0.9, 0.9, 0], clamp);
  return (
    <AbsoluteFill>
      <AbsoluteFill style={{ background: "linear-gradient(to bottom, transparent 54%, rgba(0,0,0,0.78) 70%, rgba(0,0,0,0.9) 100%)", opacity: veil * 0.9 }} />
      {f >= V.meet && f < V.everything && <KineticLine words={[{ t: t("v3.meet"), at: V.meet }]} frame={f} top={1560} size={128} out={meetOut} />}
      {f >= V.everything - 4 && f < 745 && (
        <>
          <KineticLine words={[{ t: t("v3.every"), at: V.everything }]} frame={f} top={1500} size={84} out={evOut} weight={600} />
          <KineticLine words={[{ t: t("v3.one"), at: V.everything + 16, hi: true }]} frame={f} top={1610} size={126} out={evOut} />
        </>
      )}
      <div style={{ position: "absolute", left: 0, top: 1880, width: W, textAlign: "center", fontFamily: INTER, fontWeight: 600, fontSize: 22, letterSpacing: "0.16em", textTransform: "uppercase", color: C.type3, opacity: demo }}>
        {t("v3.demo")}
      </div>
    </AbsoluteFill>
  );
};

const SEGS: Seg[] = [
  { from: 0, length: 524, El: Hook4 },
  { from: 524, length: 226, El: OpeningLeave },
  { from: 720, length: 330, El: MiniApp, props: { app: NUTRITION } },
  { from: 1020, length: 450, El: MiniApp, props: { app: FITNESS } },
  { from: 1440, length: 270, El: MiniApp, props: { app: HABITS } },
  { from: 1680, length: 300, El: MiniApp, props: { app: FINANCES } },
  { from: 1950, length: 300, El: MiniApp, props: { app: PLANNING } },
  { from: 2250, length: 840, El: Process },
  { from: 3090, length: 660, El: Homes },
];

export const FilmMainV4: React.FC<{ silent?: boolean }> = ({ silent = false }) => {
  let hasAudio = false;
  try {
    hasAudio = !silent && getStaticFiles().some((s) => s.name === AUDIO);
  } catch {
    hasAudio = false;
  }
  return (
    <AbsoluteFill style={{ backgroundColor: "#000" }}>
      {SEGS.map(({ from, length, El, props, input, output }) => {
        const inner = <El {...(props ?? {})} />;
        return (
          <Sequence key={from} from={from} durationInFrames={length} layout="absolute-fill">
            {input && output ? <TimeRemap input={input} output={output}>{inner}</TimeRemap> : inner}
          </Sequence>
        );
      })}
      <Sequence from={3734} durationInFrames={316} layout="absolute-fill">
        <CloseOnHome />
      </Sequence>
      {T.cuts.map((c) => (
        <Sequence key={`c${c}`} from={Math.max(0, c - 2)} durationInFrames={12} layout="absolute-fill">
          <CutFx />
        </Sequence>
      ))}
      <Texts />
      <Grain amount={0.012} />
      {hasAudio && <Audio src={staticFile(AUDIO)} />}
    </AbsoluteFill>
  );
};

export const FilmMainV4Format: React.FC<FormatProps & { silent?: boolean }> = ({ format, lang, silent }) => (
  <FormatFrame format={format} lang={lang} text={{ headline: "frame.main", sub: "frame.main.sub", show: 790, hide: 3730 }}>
    <FilmMainV4 silent={silent} />
  </FormatFrame>
);
