import { Audio } from "@remotion/media";
import { AbsoluteFill, Sequence, staticFile, useCurrentFrame } from "remotion";
import { ease } from "../lib/brand";
import { Format } from "../lib/formats";
import { Lang, LangContext, translate } from "../lib/i18n";
import { Cap, Caps, DemoLine, FormatContext, K, Stage, ToneContext, pr, sec } from "./ctx";
import { BalanceCounter, CurveCard, HabitCard, Pills, RingBars, ScanLayer, StackCards, ThreeCards, WeekBlocks } from "./natives";
import { HomeCompose, LockCompose, Phone, homeRect } from "./Phone";
import { EndCard, Flash, GatherShot, Land, LineShot, OutLayer, Out, PhoneShot, S, StyleCycle, scr } from "./shots";

/**
 * The 10 films of the 2026 campaign, from docs/memoire/campagne-2026/0*.md. A film is a list of shots
 * [start (s), length (s), element]; every shot is laid out natively for the format (ctx.layoutOf).
 */
type Shot = [number, number, React.ReactNode];
export type Film26Id = "main" | "nutrition" | "fitness" | "lifestyle" | "widgets" | "finance" | "organisation" | "short1" | "short2" | "short3";
export const FILM26: Record<Film26Id, { comp: string; frames: number; dir: string }> = {
  main: { comp: "FilmMain", frames: 2700, dir: "01_Ad_Main" },
  nutrition: { comp: "FilmNutrition2", frames: 1440, dir: "02_Ad_Nutrition" },
  fitness: { comp: "FilmFitness2", frames: 1440, dir: "03_Ad_Fitness" },
  lifestyle: { comp: "FilmLifestyle", frames: 2520, dir: "04_Ad_Lifestyle" },
  widgets: { comp: "FilmWidgets", frames: 1800, dir: "05_Ad_Widgets" },
  finance: { comp: "FilmFinance", frames: 1140, dir: "06_Ad_Finance" },
  organisation: { comp: "FilmOrganisation", frames: 1440, dir: "07_Ad_Organization" },
  short1: { comp: "FilmShort1", frames: 480, dir: "08_Ad_Short" },
  short2: { comp: "FilmShort2", frames: 480, dir: "08_Ad_Short" },
  short3: { comp: "FilmShort3", frames: 480, dir: "08_Ad_Short" },
};

const c = (k: string, at: number, o: Partial<Cap> = {}): Cap => ({ k, at, ...o });
const prem = (at: number, o: Partial<Cap> = {}): Cap => ({ k: "common.withPremium", at, premium: true, slot: 1, ...o });
const chip = (k: string, at: number, out?: number): Cap => ({ k, at, out, zone: "low", size: "m" });
const pad = (n: number) => String(Math.max(0, Math.floor(n))).padStart(4, "0");
const black = () => <div style={{ position: "absolute", inset: 0, background: "#000" }} />;

/* Gradients of the day (Lifestyle). */
const BG = {
  night: "linear-gradient(180deg,#02060C 0%,#0B1D33 100%)",
  morning: "linear-gradient(180deg,#CFE3F7 0%,#F4F9FE 100%)",
  noon: "linear-gradient(180deg,#FFFFFF 0%,#DCE9F6 100%)",
  evening: "linear-gradient(180deg,#1D1511 0%,#6B3A1C 100%)",
};

/** 6 styled widgets on a complete Home (Aurora wallpaper): the "Gather" ending of the main film, Lifestyle and Widgets. */
const FULL: { name: string; row: number; col: 0 | 1 | "full"; size: "m" | "s" }[] = [
  { name: "macros-m-aurora", row: 0, col: "full", size: "m" },
  { name: "nextSet-s-neon", row: 1, col: 0, size: "s" },
  { name: "habitStreak-s-aurora", row: 1, col: 1, size: "s" },
  { name: "budgetLeft-s-luxury", row: 2, col: 0, size: "s" },
  { name: "priorities-s-paper", row: 2, col: 1, size: "s" },
];
const slotsOf = (list: typeof FULL) => list.map((w) => ({ name: w.name, size: w.size, ...homeRect(w.row, w.col, w.size) }));
const homeOf = (wall: string, list: typeof FULL, dock = "aurore", dark = true) => <HomeCompose wall={wall} widgets={slotsOf(list)} dock={dock} dark={dark} />;
const landOf = (list: typeof FULL, from: number, step: number, fromTop = false): Land[] =>
  slotsOf(list).map((w, i) => ({ name: w.name, x: w.x, y: w.y, w: w.w ?? 510, at: from + i * step, fx: fromTop ? ((i % 3) - 1) * 300 : (i % 2 ? 1 : -1) * (900 + i * 60), fy: fromTop ? -1800 : -700 + i * 420, rot: (i % 2 ? 1 : -1) * (14 + i * 3) }));

/* ---------------------------------------------------------------- shared shots */
const GatherFull: React.FC<{ caps: Cap[]; from?: number; step?: number; landAt: number; turn?: number; turnDur?: number }> = ({ caps, from = 14, step = 30, landAt, turn, turnDur }) => (
  <GatherShot caps={caps} land={landOf(FULL, from, step)} base={<HomeCompose wall="wall-aurora" widgets={[]} dock="aurore" />} home={homeOf("wall-aurora", FULL)} landAt={landAt} turn={turn} turnDur={turnDur} />
);

const WidgetsOut4: React.FC<{ caps: Cap[]; dur: number }> = ({ caps, dur }) => {
  const items: Out[] = [
    { name: "macros-m-dark", x: 0, y: -640, w: 1060, at: 20, label: "common.hlNutrition", z: 80 },
    { name: "nextSet-s-light", x: -300, y: -80, w: 520, at: 80, label: "common.hlFitness", rot: -3, z: 120 },
    { name: "upNext-s-dark", x: 300, y: -80, w: 520, at: 140, label: "common.hlPlanning", rot: 3, z: 120 },
    { name: "budgetLeft-s-dark", x: 0, y: 520, w: 560, at: 200, label: "common.hlFinances", z: 160 },
  ];
  return <PhoneShot screens={[{ node: scr("home-hero-light") }]} dim={0.55} cam0={{ x: -50, rz: -1.5, s: 0.96 }} cam1={{ x: 50, rz: 1.5, s: 1.04 }} camTo={dur} over={(f) => <OutLayer items={items} f={f} collapse={pr(f, dur - 44, dur - 4, ease.easeIn)} />} caps={caps} />;
};

/** Lock screen with the Live Activity strip: the rest countdown, then the strip after the set. */
const lockLive = (lock: string, from: number, afterAt: number) => (f: number) => {
  const strip = f < afterAt ? `live-rest-night-${String(Math.min(15, Math.floor(Math.max(0, f - from) / 10))).padStart(3, "0")}` : `live-afterset-night-${String(Math.min(10, Math.floor((f - afterAt) / 6))).padStart(3, "0")}`;
  return (
    <>
      <S name={lock} />
      {f >= from && <K name={strip} w={1116} style={{ position: "absolute", left: 45, top: 1640, opacity: pr(f, from, from + 12) }} />}
    </>
  );
};

/* ---------------------------------------------------------------- 01 · main */
const main = (): Shot[] => [
  [0, 3, <LineShot key="a" caps={[c("common.wholeLife", 48, { zone: "mid", size: "xl", split: true })]} />],
  [3, 3, <PhoneShot key="b" screens={[{ node: scr("home-hero-light") }]} cam0={{ s: 1.16, ry: -14, y: 60 }} cam1={{ s: 1 }} camTo={150} enter={36} caps={[c("common.onePlace", 14, { size: "xl" })]} />],
  [6, 6.5, <WidgetsOut4 key="c" dur={390} caps={[]} />],
  [12.5, 5, <PhoneShot key="d" screens={[{ node: (f) => <S name="myday-tall" y={-f * 9.5} /> }]} cam0={{ ry: -8, rx: 4 }} cam1={{ ry: 8, rx: 0 }} camTo={300} caps={[c("common.everythingOnePlace", 18, { size: "l" })]} />],
  [
    17.5,
    7.5,
    <StyleCycle
      key="e"
      steps={[
        { name: "macros-m-paper", wall: "wall-graphite", at: 0 },
        { name: "macros-m-light", wall: "wall-cream", at: 75 },
        { name: "macros-m-dark", wall: "wall-midnight", at: 150 },
        { name: "macros-m-aurora", wall: "wall-aurora", at: 225, premium: true },
        { name: "macros-m-neon", wall: "wall-synthwave", at: 300, premium: true },
        { name: "macros-m-space", wall: "wall-midnight", at: 375, premium: true },
      ]}
      caps={[c("main.decide", 8, { out: 205, size: "l" }), c("common.widgetsYourWay", 220, { size: "l" }), prem(228)]}
    />,
  ],
  [
    25,
    7.5,
    <PhoneShot key="f" screens={[{ node: lockLive("lock-neon", 130, 300) }]} cam0={{ s: 1.22, rx: 8 }} cam1={{ s: 1, rx: 0 }} camTo={450} caps={[chip("common.homeScreen", 4, 110), chip("common.lockScreen", 116, 230), c("main.glance", 250, { size: "l" })]} />,
  ],
  [32.5, 6.5, <GatherFull key="g" landAt={300} turn={360} turnDur={390} caps={[c("main.dashboard", 20, { size: "l" }), prem(80)]} />],
  [39, 6, <EndCard key="h" lines={["common.wholeLifeOnePlace", "common.widgetsYourWay"]} />],
];

/* ---------------------------------------------------------------- 02 · nutrition */
const nutrition = (): Shot[] => [
  [0, 3, <PhoneShot key="a" tone="light" screens={[{ node: (f) => <><S name="scan-frame-white" /><ScanLayer f={f} /></> }]} cam0={{ s: 1.25 }} cam1={{ s: 1 }} camTo={120} extra={<Flash at={78} />} caps={[c("nutrition.title", 8, { size: "xl" })]} />],
  [
    3,
    4.5,
    <PhoneShot key="b" tone="light" screens={[{ node: scr("scan-food") }]} cam0={{ y: -120, s: 1.1 }} cam1={{ y: 120, s: 1.1 }} camTo={270} caps={[c("nutrition.scanBarcode", 8, { out: 120, size: "l" }), c("nutrition.orPhoto", 130, { size: "l" }), chip("nutrition.verified", 40, 120), chip("common.estimate", 160)]} />,
  ],
  [7.5, 3, <RingBars key="c" />],
  [10.5, 3.5, <PhoneShot key="d" tone="light" screens={[{ node: scr("nutrition-plan") }]} cam0={{ x: 80, s: 1.05 }} cam1={{ x: -80, s: 1.05 }} camTo={210} caps={[c("nutrition.goal", 8, { size: "l" }), c("nutrition.estimatesNote", 60, { zone: "low", size: "m" })]} />],
  [
    14,
    3.4,
    <PhoneShot key="e" tone="light" screens={[{ node: () => <HomeCompose wall="wall-paper" dark={false} dock="etudes" widgets={[{ name: "macros-m-light", ...homeRect(0, "full", "m") }, { name: "calories-s-light", ...homeRect(1, 0, "s") }]} /> }]} cam0={{ ry: -20 }} cam1={{ ry: 14 }} camTo={204} caps={[c("nutrition.homeLock", 10, { size: "l" })]} />,
  ],
  [
    17.4,
    3.3,
    <PhoneShot key="f" tone="light" screens={[{ node: () => <LockCompose wall="wall-paper" dark={false} widgets={[{ name: "lock-caloriesLeft-circular", x: 80, y: 560, w: 300 }, { name: "lock-caloriesLeft-rect", x: 440, y: 560, w: 688 }]} /> }]} cam0={{ s: 1.2 }} cam1={{ s: 1 }} camTo={198} caps={[c("nutrition.homeLock", 10, { size: "l" })]} />,
  ],
  [20.7, 3.3, <EndCard key="g" lines={["common.wholeLifeOnePlace"]} />],
];

/* ---------------------------------------------------------------- 03 · fitness */
const demoNode = (f: number) => {
  const [ex, i] = f < 90 ? ["bench-press", f] : f < 142 ? ["back-squat", f - 90] : ["deadlift", f - 142];
  const max = ex === "bench-press" ? 239 : ex === "back-squat" ? 233 : 263;
  return <S name={`demo-${ex}-dark-${pad(Math.min(max, i))}`} />;
};
const fitness = (): Shot[] => [
  [0, 3.5, <PhoneShot key="a" screens={[{ node: scr("app-fitness-session-dark") }]} cam0={{ s: 1.18 }} cam1={{ s: 1 }} camTo={90} caps={[c("fitness.title", 6, { size: "xl" }), chip("fitness.setCounter", 60)]} />],
  [
    3.5,
    3.3,
    <PhoneShot
      key="b"
      screens={[
        { node: scr("app-fitness-session-dark") },
        { node: scr("app-fitness-session-end-dark"), at: 36, fade: 6 },
        { node: (f) => <><div style={{ position: "absolute", inset: 0, background: "#05080C" }} /><K name={`live-rest-night-${String(Math.min(15, Math.floor(Math.max(0, f) / 10))).padStart(3, "0")}`} w={1116} style={{ position: "absolute", left: 45, top: 1000 }} /></>, at: 100, fade: 8 },
      ]}
      cam0={{ s: 1.08 }} cam1={{ s: 1.2, y: -60 }} camTo={198}
      caps={[chip("fitness.setDone", 8, 96), c("fitness.rest", 104, { size: "xl" })]}
    />,
  ],
  [6.8, 3.8, <PhoneShot key="c" screens={[{ node: lockLive("wall-midnight", 8, 130) }]} cam0={{ rx: 20, s: 1.15 }} cam1={{ rx: 0, s: 1 }} camTo={150} caps={[c("fitness.fromLock", 6, { size: "l" }), chip("fitness.liveActivity", 70), chip("common.lockScreen", 150)]} />],
  [10.6, 3.2, <PhoneShot key="d" screens={[{ node: demoNode }]} cam0={{ ry: -28 }} cam1={{ ry: 28 }} camTo={192} caps={[c("fitness.exercises", 6, { size: "l" }), prem(40)]} />],
  [13.8, 3, <PhoneShot key="e" screens={[{ node: scr("app-fitness-progress") }]} cam0={{ x: 120, s: 1.05 }} cam1={{ x: -120, s: 1.05 }} camTo={180} caps={[c("fitness.progress", 6, { size: "l" }), prem(40)]} />],
  [
    16.8,
    3.5,
    <PhoneShot key="f" screens={[{ node: () => <HomeCompose wall="wall-midnight" dock="espace" widgets={[{ name: "todaysWorkout-m-dark", ...homeRect(0, "full", "m") }, { name: "nextSet-s-neon", ...homeRect(1, 0, "s") }, { name: "trainingStreak-s-sport", ...homeRect(1, 1, "s") }, { name: "weekView-m-aurora", ...homeRect(2, "full", "m") }]} /> }]} cam0={{ ry: -18 }} cam1={{ ry: 14 }} camTo={210} caps={[c("common.homeScreen", 8, { out: 100, size: "l" }), c("common.lockScreen", 110, { size: "l" })]} />,
  ],
  [20.3, 3.7, <EndCard key="g" lines={["common.wholeLifeOnePlace"]} />],
];

/* ---------------------------------------------------------------- 04 · lifestyle */
const lifestyle = (): Shot[] => [
  [0, 3.2, <PhoneShot key="a" bg={BG.night} screens={[{ node: black }, { node: scr("lock-etudes"), at: 90, fade: 20 }]} cam0={{ s: 1.05, y: 40 }} cam1={{ s: 1.14 }} camTo={192} caps={[c("lifestyle.t0645", 4, { size: "xl", accent: true }), c("lifestyle.title", 44, { slot: 1, size: "l" })]} />],
  [3.2, 3.8, <PhoneShot key="b" tone="light" bg={BG.morning} screens={[{ node: scr("lock-etudes") }]} cam0={{ rx: 22, s: 1.12 }} cam1={{ rx: 0, s: 1 }} camTo={228} caps={[c("lifestyle.wake", 8, { size: "l" })]} />],
  [
    7,
    4.2,
    <PhoneShot key="c" tone="light" bg={BG.morning} screens={[{ node: (f) => <><S name="scan-frame" /><ScanLayer f={f} /></> }, { node: scr("app-nutrition-s00-dark"), at: 170, fade: 10 }]} cam0={{ s: 1.2 }} cam1={{ s: 1.05 }} camTo={252} extra={<Flash at={78} />} caps={[c("lifestyle.t0815", 4, { size: "xl", accent: true }), c("lifestyle.breakfast", 30, { slot: 1, size: "l" })]} />,
  ],
  [11.2, 5.2, <PhoneShot key="d" tone="light" bg={BG.morning} screens={[{ node: (f) => <S name="myday-tall" y={-f * 8.5} /> }]} cam0={{ ry: -10 }} cam1={{ ry: 8 }} camTo={312} caps={[c("lifestyle.morning", 8, { size: "xl" })]} />],
  [16.4, 4.4, <PhoneShot key="e" tone="light" bg={BG.noon} screens={[{ node: scr("home-hero-light") }]} cam0={{ ry: -22 }} cam1={{ ry: 12 }} camTo={264} caps={[c("lifestyle.t1230", 6, { size: "xl", accent: true }), c("lifestyle.left", 30, { slot: 1, size: "l" })]} />],
  [
    20.8,
    7.4,
    <PhoneShot key="f" bg={BG.evening} screens={[{ node: scr("app-fitness-session-dark") }, { node: lockLive("lock-neon", 20, 190), at: 170, fade: 12 }]} cam0={{ ry: 14, s: 1.05 }} cam1={{ ry: -8, s: 1.1 }} camTo={444} caps={[c("lifestyle.t1800", 4, { size: "xl", accent: true }), c("lifestyle.train", 30, { slot: 1, size: "l" })]} />,
  ],
  [28.2, 4.8, <PhoneShot key="g" bg={BG.night} screens={[{ node: scr("app-finances-s00") }, { node: scr("app-planning-habits"), at: 150, fade: 12 }]} cam0={{ x: -60 }} cam1={{ x: 60 }} camTo={288} caps={[c("lifestyle.t2200", 4, { size: "xl", accent: true }), c("lifestyle.bed", 30, { slot: 1, size: "l" })]} />],
  [33, 5, <GatherFull key="h" landAt={230} turn={0} caps={[c("common.wholeLifeOnePlace", 10, { out: 150, size: "l" }), c("common.widgetsYourWay", 156, { size: "l" }), prem(170)]} />],
  [38, 4, <EndCard key="i" lines={["common.wholeLifeOnePlace"]} />],
];

/* ---------------------------------------------------------------- 05 · widgets */
const profile = (wall: string, dock: string, widgets: { name: string; row: number; col: 0 | 1 | "full"; size: "m" | "s" | "l" }[], k: string, dark = true) => (
  <PhoneShot tone={dark ? "dark" : "light"} screens={[{ node: () => <HomeCompose wall={wall} dock={dock} dark={dark} widgets={widgets.map((w) => ({ name: w.name, size: w.size, ...homeRect(w.row, w.col, w.size) }))} /> }]} cam0={{ ry: -16, s: 1.04 }} cam1={{ ry: 10, s: 1.08 }} camTo={92} caps={[c(k, 4, { size: "xl" }), prem(26)]} />
);
const LockFan: React.FC = () => {
  const f = useCurrentFrame();
  const open = pr(f, 0, 46, ease.lift);
  const fan = pr(f, 150, 190, ease.chapter);
  const side = (x: number, ry: number, name: string) => (
    <Phone cam={{ x: x * open * (1 - fan), ry: ry * open * (1 - fan), s: 0.82 + 0.04 * fan, o: 1 - fan * 0.0 }}>
      <S name={name} />
    </Phone>
  );
  return (
    <Stage>
      {side(-720, 22, "lock-neon")}
      {side(720, -22, "lock-minuit")}
      <Phone cam={{ s: 0.96 + 0.1 * fan }}>
        <S name="lock-etudes" />
      </Phone>
      <Caps caps={[c("widgets.lockToo", 10, { size: "l" })]} />
    </Stage>
  );
};
const widgetsFilm = (): Shot[] => [
  [
    0,
    3.2,
    <PhoneShot key="a" screens={[{ node: () => <HomeCompose wall="wall-midnight" dock="espace" widgets={[{ name: "macros-m-dark", ...homeRect(0, "full", "m") }, { name: "nextSet-s-light", ...homeRect(1, 0, "s") }, { name: "budgetLeft-s-dark", ...homeRect(1, 1, "s") }]} /> }]} cam0={{ s: 1.0 }} cam1={{ s: 1.1 }} camTo={192} enter={30} caps={[c("common.widgetsYourWay", 20, { size: "xl" }), c("widgets.threeFree", 80, { slot: 1, size: "m" })]} />,
  ],
  [
    3.2,
    3.4,
    <PhoneShot key="b" screens={[{ node: scr("mywidgets") }]} dim={0.25} cam0={{ x: -60 }} cam1={{ x: 60 }} camTo={204}
      over={(f) => <OutLayer f={f} collapse={pr(f, 170, 204)} items={[{ name: "macros-m-dark", x: 0, y: -640, w: 1000, at: 36, z: 120 }, { name: "nextSet-s-light", x: -300, y: -60, w: 520, at: 80, z: 150, rot: -3 }, { name: "priorities-s-dark", x: 300, y: -60, w: 520, at: 120, z: 150, rot: 3 }]} />}
      caps={[c("widgets.pick", 8, { size: "l" })]} />,
  ],
  [
    6.6,
    4.6,
    <StyleCycle key="c" steps={[{ name: "macros-m-light", wall: "wall-graphite", at: 0 }, { name: "macros-m-dark", wall: "wall-paper", at: 69 }, { name: "macros-m-aurora", wall: "wall-aurora", at: 138, premium: true }, { name: "macros-m-neon", wall: "wall-synthwave", at: 207, premium: true }]} caps={[c("widgets.style", 6, { out: 62, size: "xl" }), c("widgets.colors", 72, { out: 131, size: "xl" }), c("widgets.background", 141, { out: 200, size: "xl" }), c("widgets.font", 210, { size: "xl" }), prem(144)]} />,
  ],
  [11.2, 4.2, <GatherFull key="d" landAt={190} turn={90} turnDur={252} caps={[c("widgets.buildHome", 10, { size: "l" }), prem(60)]} />],
  [15.4, 1.534, profile("wall-synthwave", "neon", [{ name: "todaysWorkout-m-dark", row: 0, col: "full", size: "m" }, { name: "nextSet-s-neon", row: 1, col: 0, size: "s" }, { name: "trainingStreak-s-sport", row: 1, col: 1, size: "s" }, { name: "macros-m-neon", row: 2, col: "full", size: "m" }], "widgets.profileAthlete")],
  [16.934, 1.533, profile("wall-paper", "etudes", [{ name: "timetable-l-light", row: 0, col: "full", size: "l" }, { name: "priorities-s-paper", row: 2, col: 0, size: "s" }, { name: "upNext-s-light", row: 2, col: 1, size: "s" }], "widgets.profileStudent", false)],
  [18.467, 1.533, profile("wall-graphite", "graphite", [{ name: "budgetLeft-s-dark", row: 0, col: 0, size: "s" }, { name: "priorities-s-dark", row: 0, col: 1, size: "s" }, { name: "calories-s-dark", row: 1, col: 0, size: "s" }], "widgets.profileMinimal")],
  [20, 3.2, <LockFan key="g" />],
  [
    23.2,
    2.8,
    <PhoneShot key="h" screens={[{ node: () => homeOf("wall-aurora", FULL) }]} cam0={{ ry: 0 }} cam1={{ ry: 360 }} camTo={168} caps={[c("widgets.dashboard", 6, { size: "l" }), prem(50)]} />,
  ],
  [26, 4, <EndCard key="i" lines={["common.wholeLifeOnePlace", "common.widgetsYourWay"]} />],
];
/* ---------------------------------------------------------------- 06 · finance */
const finance = (): Shot[] => [
  [0, 3.2, <BalanceCounter key="a" caps={[c("finance.title", 10, { size: "l" })]} />],
  [3.2, 3.2, <Pills key="b" caps={[]} />],
  [6.4, 3, <CurveCard key="c" caps={[prem(116)]} />],
  [9.4, 2.8, <StackCards key="d" items={[{ name: "app-finances-categories", k: "finance.categories" }, { name: "app-finances-bills", k: "finance.bills" }, { name: "app-finances-savings", k: "finance.savings" }]} at={[4, 60, 114]} caps={[]} />],
  [
    12.2,
    2.6,
    <PhoneShot key="e" screens={[{ node: () => <HomeCompose wall="wall-aurora" dock="aurore" widgets={[{ name: "budgetLeft-s-dark", ...homeRect(0, 0, "s") }, { name: "quickExpense-s-light", ...homeRect(0, 1, "s") }, { name: "spendingByCategory-m-light", ...homeRect(1, "full", "m") }]} /> }]} cam0={{ ry: -16 }} cam1={{ ry: 12 }} camTo={156} caps={[c("finance.manualNote", 8, { size: "l" }), chip("common.homeScreen", 20), prem(60)]} />,
  ],
  [14.8, 4.2, <EndCard key="f" lines={["common.wholeLifeOnePlace"]} />],
];

/* ---------------------------------------------------------------- 07 · organisation */
const organisation = (): Shot[] => [
  [0, 4, <ThreeCards key="a" caps={[c("organisation.title", 6, { size: "l" })]} />],
  [4, 4.4, <HabitCard key="b" caps={[]} />],
  [8.4, 3.6, <WeekBlocks key="c" caps={[c("organisation.week", 6, { size: "l" })]} />],
  [12, 3.8, <PhoneShot key="d" tone="light" screens={[{ node: scr("app-planning-tasks") }]} cam0={{ rx: 16, s: 1.1 }} cam1={{ rx: 0, s: 1 }} camTo={150} caps={[c("organisation.top3", 8, { size: "l" })]} />],
  [
    15.8,
    4.2,
    <PhoneShot key="e" tone="light" screens={[{ node: () => <HomeCompose wall="wall-paper" dock="etudes" dark={false} widgets={[{ name: "habits-m-light", ...homeRect(0, "full", "m") }, { name: "weekView-m-light", ...homeRect(1, "full", "m") }, { name: "priorities-s-light", ...homeRect(2, 0, "s") }, { name: "habitStreak-s-light", ...homeRect(2, 1, "s") }]} /> }, { node: scr("lock-etudes"), at: 126, fade: 16 }]} cam0={{ ry: -18 }} cam1={{ ry: 10 }} camTo={252} caps={[c("organisation.everywhere", 8, { out: 120, size: "l" }), c("organisation.goalsRow", 134, { size: "l" })]} />,
  ],
  [20, 4, <EndCard key="f" lines={["common.wholeLifeOnePlace"]} />],
];

/* ---------------------------------------------------------------- 08 · shorts */
const short1 = (): Shot[] => {
  const list: typeof FULL = [
    { name: "calories-s-dark", row: 0, col: 0, size: "s" },
    { name: "nextSet-s-light", row: 0, col: 1, size: "s" },
    { name: "weekView-m-light", row: 1, col: "full", size: "m" },
    { name: "budgetLeft-s-dark", row: 2, col: 0, size: "s" },
  ];
  return [
    [0, 1, <LineShot key="a" caps={[]} />],
    [1, 3.4, <GatherShot key="b" land={landOf(list, 6, 26, true)} base={<HomeCompose wall="wall-midnight" widgets={[]} dock="espace" />} home={homeOf("wall-midnight", list, "espace")} landAt={140} push={0.12} turnDur={204} caps={[c("short1.line1", 8, { out: 76, size: "xl" }), c("short1.line2", 80, { size: "xl" }), prem(130)]} />],
    [4.4, 3.6, <EndCard key="c" lines={[]} />],
  ];
};
const short2 = (): Shot[] => [
  [0, 0.8, <LineShot key="a" caps={[]} />],
  [0.8, 2.2, <PhoneShot key="b" screens={[{ node: scr("studio-content") }]} cam0={{ s: 1.0 }} cam1={{ s: 1.14 }} camTo={132} caps={[c("short2.build", 6, { size: "xl" })]} />],
  [3, 2.8, <StyleCycle key="c" steps={[{ name: "macros-m-paper", wall: "wall-graphite", at: 0 }, { name: "macros-m-aurora", wall: "wall-aurora", at: 56, premium: true }, { name: "macros-m-neon", wall: "wall-synthwave", at: 112, premium: true }]} caps={[c("short2.pick", 4, { out: 82, size: "l" }), c("short2.style", 86, { size: "l" }), prem(60)]} />],
  [5.8, 2.2, <EndCard key="d" lines={[]} pill="common.comingSoonShort" />],
];
const short3 = (): Shot[] => [
  [0, 0.8, <LineShot key="a" caps={[]} />],
  [0.8, 1.2, <PhoneShot key="b" screens={[{ node: (f) => <S name="myday-tall" y={-f * 16} /> }]} cam0={{ rx: 6 }} cam1={{ rx: 0 }} camTo={72} caps={[c("short3.life", 4, { size: "xl" })]} />],
  [2, 1.3, <PhoneShot key="c" screens={[{ node: scr("home-hero-espace") }]} cam0={{ ry: -26 }} cam1={{ ry: 26 }} camTo={78} caps={[c("short3.widgets", 4, { size: "xl" }), prem(14)]} />],
  [3.3, 1.3, <PhoneShot key="d" screens={[{ node: scr("lock-minuit") }]} cam0={{ s: 1.25 }} cam1={{ s: 1 }} camTo={78} caps={[c("short3.way", 4, { size: "xl" })]} />],
  [4.6, 3.4, <EndCard key="e" lines={[]} />],
];

const SHOTS: Record<Film26Id, () => Shot[]> = { main, nutrition, fitness, lifestyle, widgets: widgetsFilm, finance, organisation, short1, short2, short3 };

/** A fade over the previous shot (cut on movement, never a hard black). */
const FadeIn: React.FC<{ n: number; children: React.ReactNode }> = ({ n, children }) => {
  const f = useCurrentFrame();
  return <AbsoluteFill style={{ opacity: n ? Math.min(1, f / n) : 1 }}>{children}</AbsoluteFill>;
};

export const audioFile26 = (lang: Lang, film: Film26Id) => `audio/${lang}/mix-${film}.wav`;

export const Film26: React.FC<{ film: Film26Id; format: Format; lang: Lang; audioLang?: Lang; audio?: boolean }> = ({ film, format, lang, audioLang, audio = true }) => {
  const shots = SHOTS[film]();
  const total = FILM26[film].frames;
  const OV = 10;
  const starts = shots.map((s) => sec(s[0]));
  return (
    <FormatContext.Provider value={format}>
      <LangContext.Provider value={lang}>
        <ToneContext.Provider value="dark">
          <AbsoluteFill style={{ background: "#000" }}>
            {shots.map(([, , el], i) => {
              const from = starts[i];
              const end = i + 1 < shots.length ? starts[i + 1] : total;
              const dur = end - from + (i + 1 < shots.length ? OV : 0);
              return (
                <Sequence key={i} from={from} durationInFrames={dur} layout="absolute-fill">
                  <FadeIn n={i === 0 ? 0 : OV}>{el}</FadeIn>
                </Sequence>
              );
            })}
            <Sequence from={0} durationInFrames={starts[starts.length - 1]} layout="absolute-fill">
              <DemoLine />
            </Sequence>
            {audio && <Audio src={staticFile(audioFile26(audioLang ?? lang, film))} />}
          </AbsoluteFill>
        </ToneContext.Provider>
      </LangContext.Provider>
    </FormatContext.Provider>
  );
};

export { DemoLine, Stage, translate };
